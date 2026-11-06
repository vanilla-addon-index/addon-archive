-- AnySCT parse.lua -- pure functions, no WoW API (only an optional getglobal for live
-- GlobalStrings), so everything here runs offline under Lua 5.0.
--
-- Three entry points:
--   AnySCT_ParseMelee(msg)   chat row of a melee swing    -> result table or nil
--   AnySCT_ParseSpell(msg)   chat row of a special attack -> result table or nil
--   AnySCT_DecodeAutoAttack  nampower AUTO_ATTACK_OTHER numbers -> result table or nil
--
-- Result table: { kind, amount, blocked, absorbed, resisted, attacker, victim, spell, school }
-- kind is one of hit crit glancing crushing miss dodge parry block evade immune deflect absorb resist.

AnySCT_Parse = {}
local P = AnySCT_Parse

-- Live GlobalString if the client has one, else the enUS literal.
local function gs(name, default)
    local v
    if getglobal then v = getglobal(name) end
    if type(v) == "string" then return v end
    return default
end

-- printf-style GlobalString -> Lua 5.0 pattern (no anchors). %s -> (.-), %d -> (%d+); literal text
-- is escaped. Positional placeholders (%1$s) are read in textual order. Second result: the
-- placeholder kinds in order.
function AnySCT_GsToPattern(template)
    local parts = {}
    local kinds = {}
    local i, len = 1, string.len(template)
    while i <= len do
        local c = string.sub(template, i, i)
        if c == "%" then
            local rest = string.sub(template, i)
            local _, e, _, t = string.find(rest, "^%%(%d*)%$?([sdfg])")
            if e then
                if t == "s" then
                    table.insert(parts, "(.-)")
                else
                    table.insert(parts, "(%d+)")
                end
                table.insert(kinds, t)
                i = i + e
            else
                -- literal percent ("%%") or a stray one
                local n = string.sub(template, i + 1, i + 1)
                table.insert(parts, "%%")
                if n == "%" then i = i + 2 else i = i + 1 end
            end
        else
            if string.find(c, "[%(%)%.%+%-%*%?%[%]%^%$]") then
                table.insert(parts, "%" .. c)
            else
                table.insert(parts, c)
            end
            i = i + 1
        end
    end
    return table.concat(parts, ""), kinds
end

-- ---- form tables ----------------------------------------------------------------------------
-- { globalName, enUS literal, kind, field names in placeholder order }. Order matters: the more
-- specific string (CRIT / SCHOOL) must be tried before the plain one.
local F_ATT = { "attacker", "victim", "amount", "school" }
local F_ATN = { "attacker", "victim", "amount" }
local F_AV  = { "attacker", "victim" }
local F_SP  = { "attacker", "spell", "victim", "amount", "school" }
local F_SPN = { "attacker", "spell", "victim", "amount" }
local F_SPV = { "attacker", "spell", "victim" }
local F_A   = { "attacker" }
local F_SPA = { "attacker", "spell" }

local MELEE_DEFS = {
    { "COMBATHITCRITSCHOOLOTHEROTHER", "%s crits %s for %d %s damage.", "crit", F_ATT },
    { "COMBATHITCRITOTHEROTHER", "%s crits %s for %d.", "crit", F_ATN },
    { "COMBATHITSCHOOLOTHEROTHER", "%s hits %s for %d %s damage.", "hit", F_ATT },
    { "COMBATHITOTHEROTHER", "%s hits %s for %d.", "hit", F_ATN },
    { "MISSEDOTHEROTHER", "%s misses %s.", "miss", F_AV },
    { "VSBLOCKOTHEROTHER", "%s attacks. %s blocks.", "block", F_AV },
    { "VSDODGEOTHEROTHER", "%s attacks. %s dodges.", "dodge", F_AV },
    { "VSPARRYOTHEROTHER", "%s attacks. %s parries.", "parry", F_AV },
    { "VSIMMUNEOTHEROTHER", "%s attacks but %s is immune.", "immune", F_AV },
    { "VSEVADEOTHEROTHER", "%s attacks. %s evades.", "evade", F_AV },
    { "VSDEFLECTOTHEROTHER", "%s attacks. %s deflects.", "deflect", F_AV },
    { "VSABSORBOTHEROTHER", "%s attacks. %s absorbs all the damage.", "absorb", F_AV },
    { "VSRESISTOTHEROTHER", "%s attacks. %s resists all the damage.", "resist", F_AV },
    -- attacks on the player: the victim is "you" (set from the 5th entry)
    { "VSDODGEOTHERSELF", "%s attacks. You dodge.", "dodge", F_A, true },
    { "VSPARRYOTHERSELF", "%s attacks. You parry.", "parry", F_A, true },
    { "VSBLOCKOTHERSELF", "%s attacks. You block.", "block", F_A, true },
    { "VSIMMUNEOTHERSELF", "%s attacks but you are immune.", "immune", F_A, true },
    { "VSEVADEOTHERSELF", "%s attacks. You evade.", "evade", F_A, true },
    { "VSDEFLECTOTHERSELF", "%s attacks. You deflect.", "deflect", F_A, true },
    { "VSABSORBOTHERSELF", "%s attacks. You absorb all the damage.", "absorb", F_A, true },
    { "VSRESISTOTHERSELF", "%s attacks. You resist all the damage.", "resist", F_A, true },
}

local SPELL_DEFS = {
    { "SPELLLOGCRITSCHOOLOTHEROTHER", "%s's %s crits %s for %d %s damage.", "crit", F_SP },
    { "SPELLLOGCRITOTHEROTHER", "%s's %s crits %s for %d.", "crit", F_SPN },
    { "SPELLLOGSCHOOLOTHEROTHER", "%s's %s hits %s for %d %s damage.", "hit", F_SP },
    { "SPELLLOGOTHEROTHER", "%s's %s hits %s for %d.", "hit", F_SPN },
    { "SPELLLOGABSORBOTHEROTHER", "%s's %s is absorbed by %s.", "absorb", F_SPV },
    { "SPELLMISSOTHEROTHER", "%s's %s missed %s.", "miss", F_SPV },
    { "SPELLDODGEDOTHEROTHER", "%s's %s was dodged by %s.", "dodge", F_SPV },
    { "SPELLPARRIEDOTHEROTHER", "%s's %s was parried by %s.", "parry", F_SPV },
    { "SPELLBLOCKEDOTHEROTHER", "%s's %s was blocked by %s.", "block", F_SPV },
    { "SPELLRESISTOTHEROTHER", "%s's %s was resisted by %s.", "resist", F_SPV },
    { "SPELLIMMUNEOTHEROTHER", "%s's %s fails. %s is immune.", "immune", F_SPV },
    { "SPELLEVADEDOTHEROTHER", "%s's %s was evaded by %s.", "evade", F_SPV },
    { "SPELLMISSOTHERSELF", "%s's %s misses you.", "miss", F_SPA, true },
    { "SPELLDODGEDOTHERSELF", "%s's %s was dodged.", "dodge", F_SPA, true },
    { "SPELLPARRIEDOTHERSELF", "%s's %s was parried.", "parry", F_SPA, true },
    { "SPELLBLOCKEDOTHERSELF", "%s's %s was blocked.", "block", F_SPA, true },
    { "SPELLRESISTOTHERSELF", "%s's %s was resisted.", "resist", F_SPA, true },
    { "SPELLEVADEDOTHERSELF", "%s's %s was evaded.", "evade", F_SPA, true },
    { "SPELLDEFLECTEDOTHERSELF", "%s's %s was deflected.", "deflect", F_SPA, true },
    { "SPELLIMMUNEOTHERSELF", "%s's %s failed. You are immune.", "immune", F_SPA, true },
    { "SPELLLOGABSORBOTHERSELF", "You absorb %s's %s.", "absorb", F_SPA, true },
}

-- Heal rows (CHAT_MSG_SPELL_*_BUFF and the PERIODIC_*_BUFFS channels). Result: kind "heal", crit,
-- periodic, attacker = healer ("you" for the player), victim, spell, amount.
local F_HEAL  = { "attacker", "spell", "victim", "amount" }
local F_HEALS = { "spell", "victim", "amount" }             -- "Your Spell heals Victim for N."
local F_HOT   = { "victim", "amount", "attacker", "spell" }
local F_HOTS  = { "victim", "amount", "spell" }             -- "Victim gains N health from your Spell."
local HEAL_DEFS = {
    { "HEALEDCRITOTHEROTHER", "%s's %s critically heals %s for %d.", "healcrit", F_HEAL },
    { "HEALEDOTHEROTHER", "%s's %s heals %s for %d.", "heal", F_HEAL },
    { "HEALEDCRITSELFOTHER", "Your %s critically heals %s for %d.", "healcrit", F_HEALS, nil, true },
    { "HEALEDSELFOTHER", "Your %s heals %s for %d.", "heal", F_HEALS, nil, true },
    { "PERIODICAURAHEALOTHEROTHER", "%s gains %d health from %s's %s.", "hot", F_HOT },
    { "PERIODICAURAHEALSELFOTHER", "%s gains %d health from your %s.", "hot", F_HOTS, nil, true },
}

-- trailers appended to the end of a row; the third entry names what they set on the result
local TRAILER_DEFS = {
    { "ABSORB_TRAILER", " (%d absorbed)", "absorbed", {} },
    { "BLOCK_TRAILER", " (%d blocked)", "blocked", {} },
    { "RESIST_TRAILER", " (%d resisted)", "resisted", {} },
    { "GLANCING_TRAILER", " (glancing)", "glancing", {} },
    { "CRUSHING_TRAILER", " (crushing)", "crushing", {} },
}

local meleeForms, spellForms, healForms, trailers

local function compile(defs, anchored)
    local out = {}
    for i = 1, table.getn(defs) do
        local d = defs[i]
        local pat = AnySCT_GsToPattern(gs(d[1], d[2]))
        if anchored then pat = "^" .. pat .. "$" else pat = pat .. "$" end
        out[i] = { pat = pat, kind = d[3], key = d[3], fields = d[4], nf = table.getn(d[4]), selfVictim = d[5],
                   selfAttacker = d[6] }
    end
    return out
end

-- Rebuild all compiled patterns (call again if the GlobalStrings change, e.g. in tests).
function AnySCT_Parse_Rebuild()
    meleeForms = compile(MELEE_DEFS, true)
    spellForms = compile(SPELL_DEFS, true)
    healForms = compile(HEAL_DEFS, true)
    trailers = compile(TRAILER_DEFS, false)
end

-- Strip trailers from the end of msg (repeatedly: they can stack). Returns the stripped message
-- and an info table { absorbed=, blocked=, resisted=, glancing=true, crushing=true }.
local info = {}   -- reused: one parse at a time, read before the next call
local caps = {}   -- reused capture buffer

local function stripTrailers(msg)
    if not trailers then AnySCT_Parse_Rebuild() end
    info.absorbed, info.blocked, info.resisted, info.glancing, info.crushing = nil, nil, nil, nil, nil
    local changed = true
    while changed do
        changed = false
        for i = 1, table.getn(trailers) do
            local t = trailers[i]
            local s, _, n = string.find(msg, t.pat)
            if s then
                msg = string.sub(msg, 1, s - 1)
                if n then info[t.key] = (info[t.key] or 0) + tonumber(n) else info[t.key] = true end
                changed = true
            end
        end
    end
    return msg, info
end
AnySCT_StripTrailers = stripTrailers

local function matchForms(forms, msg)
    for i = 1, table.getn(forms) do
        local f = forms[i]
        local s, _, c1, c2, c3, c4, c5 = string.find(msg, f.pat)
        if s then
            caps[1], caps[2], caps[3], caps[4], caps[5] = c1, c2, c3, c4, c5
            local r = { kind = f.kind }
            for j = 1, f.nf do r[f.fields[j]] = caps[j] end
            if r.amount then r.amount = tonumber(r.amount) end
            if f.selfVictim then r.victim = "you" end
            if f.selfAttacker then r.attacker = "you" end
            return r
        end
    end
    return nil
end

-- Fold trailer info into the result. Same precedence as the auto-attack decoder:
-- crit > crushing > glancing > block > hit. A plain "hit" is promoted; a crit stays a crit.
local function applyMods(r, info)
    r.absorbed = (type(info.absorbed) == "number") and info.absorbed or 0
    r.blocked  = (type(info.blocked) == "number") and info.blocked or 0
    r.resisted = (type(info.resisted) == "number") and info.resisted or 0
    if not r.amount then r.amount = 0 end
    if r.kind == "hit" then
        if info.crushing then r.kind = "crushing"
        elseif info.glancing then r.kind = "glancing"
        elseif r.blocked > 0 then r.kind = "block" end
    end
    return r
end

function AnySCT_ParseMelee(msg)
    if type(msg) ~= "string" then return nil end
    if not meleeForms then AnySCT_Parse_Rebuild() end
    local body, info = stripTrailers(msg)
    local r = matchForms(meleeForms, body)
    if not r then return nil end
    -- "Tank's Heroic Strike hits Boss for 5." also fits the melee shape; that is a spell row
    if string.find(r.attacker, "'s ", 1, true) then return nil end
    return applyMods(r, info)
end

function AnySCT_ParseSpell(msg)
    if type(msg) ~= "string" then return nil end
    if not spellForms then AnySCT_Parse_Rebuild() end
    local body, info = stripTrailers(msg)
    local r = matchForms(spellForms, body)
    if not r then return nil end
    return applyMods(r, info)
end

function AnySCT_ParseHeal(msg)
    if type(msg) ~= "string" then return nil end
    if not healForms then AnySCT_Parse_Rebuild() end
    local r = matchForms(healForms, msg)
    if not r then return nil end
    if r.kind == "healcrit" then r.kind = "heal"; r.crit = true
    elseif r.kind == "hot" then r.kind = "heal"; r.periodic = true end
    r.absorbed, r.blocked, r.resisted = 0, 0, 0
    return r
end

-- nampower SPELL_HEAL_BY_OTHER: the crit flag is not documented for this client, so heals decode as
-- non-crit unless the caller passes an explicit crit argument (true or 1).
function AnySCT_DecodeHeal(amount, crit)
    local r = { kind = "heal", amount = tonumber(amount) or 0, absorbed = 0, blocked = 0, resisted = 0 }
    if crit == true or crit == 1 then r.crit = true end
    return r
end

-- ---- nampower AUTO_ATTACK_OTHER decoder ---------------------------------------------------------
-- hitInfo flags (server UnitDefines.h): MISS 0x10, ABSORB 0x20, RESIST 0x40, CRITICALHIT 0x80,
-- GLANCING 0x4000, CRUSHING 0x8000. Lua 5.0 has no bit ops, so test a flag with floor and mod.
local function bitset(v, flag)
    return math.mod(math.floor(v / flag), 2) == 1
end
P.bitset = bitset

local F_MISS, F_ABSORB, F_RESIST, F_CRIT, F_GLANCING, F_CRUSHING = 16, 32, 64, 128, 16384, 32768

-- victimState -> kind for the states that mean "no damage dealt"
local STATE_KIND = { [2] = "dodge", [3] = "parry", [6] = "evade", [7] = "immune", [8] = "deflect" }

-- victimState 0 unaffected, 1 normal, 2 dodge, 3 parry, 4 interrupt (ignored -> nil), 5 block
-- (partial: damage goes through), 6 evade, 7 immune, 8 deflect.
-- Precedence for damaging hits: crit > crushing > glancing > block > hit.
function AnySCT_DecodeAutoAttack(damage, hitInfo, victimState, blocked, absorbed, resisted)
    damage = tonumber(damage) or 0
    hitInfo = tonumber(hitInfo) or 0
    victimState = tonumber(victimState) or 1
    blocked = tonumber(blocked) or 0
    absorbed = tonumber(absorbed) or 0
    resisted = tonumber(resisted) or 0
    local r = { kind = "hit", amount = damage, blocked = blocked, absorbed = absorbed, resisted = resisted }

    if victimState == 4 then return nil end
    local sk = STATE_KIND[victimState]
    if sk then
        r.kind = sk
        r.amount = 0
        return r
    end
    if bitset(hitInfo, F_MISS) then
        r.kind = "miss"
        r.amount = 0
        return r
    end
    if damage <= 0 then
        if absorbed > 0 or bitset(hitInfo, F_ABSORB) then r.kind = "absorb"
        elseif resisted > 0 or bitset(hitInfo, F_RESIST) then r.kind = "resist"
        elseif victimState == 5 then r.kind = "block"
        elseif victimState == 0 then r.kind = "miss"
        end
        return r
    end
    if bitset(hitInfo, F_CRIT) then r.kind = "crit"
    elseif bitset(hitInfo, F_CRUSHING) then r.kind = "crushing"
    elseif bitset(hitInfo, F_GLANCING) then r.kind = "glancing"
    elseif victimState == 5 then r.kind = "block"
    end
    return r
end

-- ---- nampower spell events ---------------------------------------------------------------------
-- SPELL_DAMAGE_EVENT_OTHER: amount, mitigation "absorb,block,resist" (comma separated string),
-- hitInfo (SpellHitType, crit = 0x02). Argument layout as documented for nampower; spell hits seen in game with nampower 4.6.2.
function AnySCT_DecodeSpellDamage(amount, mitigation, hitInfo)
    amount = tonumber(amount) or 0
    hitInfo = tonumber(hitInfo) or 0
    local absorbed, blocked, resisted = 0, 0, 0
    if type(mitigation) == "string" then
        local _, _, a, b, r = string.find(mitigation, "^%s*(-?%d*)%s*,%s*(-?%d*)%s*,%s*(-?%d*)%s*$")
        absorbed, blocked, resisted = tonumber(a) or 0, tonumber(b) or 0, tonumber(r) or 0
    end
    local r = { kind = "hit", amount = amount, absorbed = absorbed, blocked = blocked, resisted = resisted }
    if amount <= 0 then
        if absorbed > 0 then r.kind = "absorb"
        elseif resisted > 0 then r.kind = "resist"
        elseif blocked > 0 then r.kind = "block" end
    elseif bitset(hitInfo, 2) then
        r.kind = "crit"
    end
    return r
end

-- SPELL_MISS_OTHER missType: the vanilla SpellMissInfo enum (unverified for this client).
local MISS_KIND = { [1] = "miss", [2] = "resist", [3] = "dodge", [4] = "parry", [5] = "block",
                    [6] = "evade", [7] = "immune", [8] = "immune", [9] = "deflect", [10] = "absorb" }
function AnySCT_DecodeSpellMiss(missType)
    local k = MISS_KIND[tonumber(missType) or 0]
    if not k then return nil end
    return { kind = k, amount = 0, absorbed = 0, blocked = 0, resisted = 0 }
end
