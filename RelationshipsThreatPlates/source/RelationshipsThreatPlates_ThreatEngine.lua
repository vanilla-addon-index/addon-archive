----------------------------------------------------------------------
-- RelationshipsThreatPlates_ThreatEngine.lua
-- Accurate threat calculation engine for WoW 1.12 (Vanilla API)
-- Parses combat log events to calculate precise per-1% threat values
-- instead of crude target-based heuristics (20%, 50%, 75%, 100%)
--
-- APPROACH:
--   1. Parse Vanilla 1.12 combat log events using GlobalStrings pattern
--      matching (same technique as KTM/ShaguDPS)
--   2. Track absolute threat values per mob name per player
--   3. Apply class-specific threat modifiers (stance, buffs, talents)
--   4. Calculate precise percentage: playerThreat / topThreat * 100
--   5. Broadcast threat data via CHAT_MSG_ADDON for group sync
--
-- VANILLA 1.12 COMPATIBILITY:
--   - No string.match() -> use string.find()
--   - No select() -> use arg1..arg9
--   - No varargs (...) -> use arg table
--   - No CombatLogGetCurrentEventInfo() -> use GlobalStrings parsing
--   - No UnitGUID -> track by mob name
--   - string.gfind exists in 1.12 (alias for string.gmatch)
----------------------------------------------------------------------
-- CHANGES (multi-mob threat display fix):
--   * Added PARTY damage/heal parsers using OTHEROTHER GlobalStrings
--     (Vanilla 1.12 has no PARTY-specific GlobalStrings; the same
--     OTHEROTHER patterns like SPELLLOGSCHOOLOTHEROTHER appear on
--     party/friendly combat log events per ShaguDPS/KTM conventions)
--   * Events: CHAT_MSG_SPELL_PARTY_DAMAGE, CHAT_MSG_COMBAT_PARTY_HITS,
--     CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE, CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS,
--     CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE, CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE,
--     CHAT_MSG_SPELL_PARTY_BUFF, CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF,
--     CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS, CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS
--   * Now tracks threat per mob per ALL group members, not just player
--   * Added partyThreatModifier estimation for group members
--   * AddThreat() now accepts optional sourceName parameter
--   * GetThreatOnTarget() returns threat for any group member
--   * GetEngagedMobs() includes mobs attacking any group member
----------------------------------------------------------------------

local addon = RelationshipsThreatPlates

addon.ThreatEngine = {}

-- ============================================================
-- Constants
-- ============================================================

-- Threat constants (from KTM/ThreatClassic-1.0)
local THREAT_CONST = {
    healing     = 0.5,    -- healing threat coefficient
    meleeAggro  = 1.1,    -- melee pull aggro at 110%
    rangeAggro  = 1.3,    -- ranged pull aggro at 130%
    rageGain    = 5.0,    -- threat per rage gained
    energyGain  = 5.0,    -- threat per energy gained
    manaGain    = 0.5,    -- threat per mana gained
}

-- Addon communication prefix
local COMM_PREFIX = "TPThreat"
local COMM_VERSION = 1

-- ============================================================
-- State variables
-- ============================================================

-- Player info (cached on load)
local playerName = nil
local playerClass = nil   -- lowercase english class name

-- Threat table: threatData[targetName][sourceName] = absoluteThreatValue
-- This tracks how much threat each player has on each mob
-- KEY CHANGE: sourceName can now be any group member, not just playerName
local threatData = {}

-- Target tracking: what the player's current target is
local currentTargetName = nil

-- Player's threat modifiers (recalculated periodically)
local threatModifier = 1.0

-- Party member class cache: partyMemberName -> classLowercase
-- Used for estimating threat modifiers for group members
local partyClassCache = {}

-- Sunder Armor transaction (KTM-style: assume success, retract on failure)
local pendingSunder = nil
local pendingSunderTime = 0

-- Player combat state
local playerInCombat = false

-- Group combat state: true if any party/raid member is in combat.
-- This is CRITICAL for showing threat bars on mobs attacking group
-- members when the player is NOT in combat themselves.
local groupInCombat = false

-- ============================================================
-- Multi-mob incoming-attack tracking (v2.6.2)
--
-- Vanilla WoW 1.12 exposes NO unit token for a mob that isn't
-- currently targeted / mouseovered / party-targeted. That meant
-- earlier versions only lit the threat bar on the ONE enemy the
-- player had targeted. To show bars for EVERY enemy in combat with
-- the group, we parse the incoming-combat chat events (mob->player
-- and mob->party) and remember which mob names have hit or missed
-- a group member recently. UpdateAllPlates then treats any plate
-- whose mob name is in this table as "in combat" and displays a
-- threat bar even when its health bar hasn't dropped yet and no
-- unit token is available.
-- ============================================================
local mobsAttackingGroup = {}
local mobsAttackingPlayer = {}
local MOB_ATTACK_TTL = 6.0  -- seconds a mob stays flagged as attacking
local INCOMING_PARSERS = {}

-- ============================================================
-- Safe API helpers
-- ============================================================

local function SafeCall1(func, a)
    if not func then return nil end
    local ok, r1 = pcall(func, a)
    if ok then return r1 end
    return nil
end

local function SafeCall2(func, a, b)
    if not func then return nil, nil end
    local ok, r1, r2 = pcall(func, a, b)
    if ok then return r1, r2 end
    return nil, nil
end

-- ============================================================
-- GlobalStrings -> Regex conversion
-- Same technique used by KTM and ShaguDPS:
-- Convert format strings like "Your %s hits %s for %d."
-- into regex patterns like "^Your (.+) hits (.+) for (%d+)%."
-- This works on ALL locales automatically because the client
-- defines these GlobalStrings variables at runtime.
-- ============================================================

local regexCache = {}

-- Convert a printf-style format string into a Lua regex pattern
-- Handles both simple (%s, %d) and positional (%1$s, %2$d) formats
local function FormatToRegex(formatStr)
    if not formatStr then return nil end
    if regexCache[formatStr] then return regexCache[formatStr] end

    local regex = formatStr

    -- Escape regex magic characters in the format string
    -- We need to escape: . ( ) % + - * ? [ ^ $
    -- But NOT the %s %d format specifiers
    regex = string.gsub(regex, "([%+%-%*%?%[%]%^%$])", "%%%1")
    regex = string.gsub(regex, "%.", "%%.")

    -- Now replace format specifiers with capture groups
    -- Handle positional format: %1$s, %2$d, etc.
    regex = string.gsub(regex, "%%(%d+)%$([sd])", function(idx, typ)
        if typ == "d" then
            return "(%d+)"
        else
            return "(.+)"
        end
    end)

    -- Handle simple format: %s, %d
    regex = string.gsub(regex, "%%([sd])", function(typ)
        if typ == "d" then
            return "(%d+)"
        else
            return "(.+)"
        end
    end)

    -- Anchor to start of string for faster matching
    regex = "^" .. regex

    regexCache[formatStr] = regex
    return regex
end

-- ============================================================
-- Parser definitions
-- Maps GlobalStrings variable names to parse handlers
-- These are the combat log patterns we need to track for threat
-- ============================================================

-- Each parser entry: { globalVarName, handler }
-- The handler receives the captures from the regex match
-- and returns: sourceName, targetName, value, spellName, isCrit, spellSchool

local SELF_DAMAGE_PARSERS = {}
local SELF_HEAL_PARSERS = {}
local SELF_BUFF_PARSERS = {}
local PERIODIC_PARSERS = {}

-- Party/raid member parsers - same patterns but with player name captures
local PARTY_DAMAGE_PARSERS = {}
local PARTY_HEAL_PARSERS = {}
local PARTY_PERIODIC_PARSERS = {}

-- Build parsers from GlobalStrings at load time
local parsersBuilt = false

-- ============================================================
-- Build parsers from GlobalStrings at runtime
-- This converts GlobalStrings like SPELLLOGSELFOTHER into
-- regex patterns and stores them for fast matching
-- ============================================================

local function BuildParser(t, globalVarName, handler)
    local formatStr = getglobal(globalVarName)
    if not formatStr then return end
    local regex = FormatToRegex(formatStr)
    if not regex then return end
    t[table.getn(t) + 1] = { regex = regex, handler = handler, globalVar = globalVarName }
end

local function BuildAllParsers()
    if parsersBuilt then return end
    parsersBuilt = true

    -- ========================================
    -- CHAT_MSG_COMBAT_SELF_HITS parsers
    -- Auto-attack (white damage) from player
    -- ========================================
    BuildParser(SELF_DAMAGE_PARSERS, "COMBATHITSELFOTHER",
        function(target, damage)
            return playerName, target, tonumber(damage) or 0, nil, false, nil
        end)
    BuildParser(SELF_DAMAGE_PARSERS, "COMBATHITCRITSELFOTHER",
        function(target, damage)
            return playerName, target, tonumber(damage) or 0, nil, true, nil
        end)
    BuildParser(SELF_DAMAGE_PARSERS, "COMBATHITSCHOOLSELFOTHER",
        function(target, damage, school)
            return playerName, target, tonumber(damage) or 0, nil, false, school
        end)
    BuildParser(SELF_DAMAGE_PARSERS, "COMBATHITCRITSCHOOLSELFOTHER",
        function(target, damage, school)
            return playerName, target, tonumber(damage) or 0, nil, true, school
        end)

    -- ========================================
    -- CHAT_MSG_SPELL_SELF_DAMAGE parsers
    -- Spell/ability damage from player
    -- ========================================
    BuildParser(SELF_DAMAGE_PARSERS, "SPELLLOGSCHOOLSELFOTHER",
        function(spell, target, damage, school)
            return playerName, target, tonumber(damage) or 0, spell, false, school
        end)
    BuildParser(SELF_DAMAGE_PARSERS, "SPELLLOGCRITSCHOOLSELFOTHER",
        function(spell, target, damage, school)
            return playerName, target, tonumber(damage) or 0, spell, true, school
        end)
    BuildParser(SELF_DAMAGE_PARSERS, "SPELLLOGSELFOTHER",
        function(spell, target, damage)
            return playerName, target, tonumber(damage) or 0, spell, false, nil
        end)
    BuildParser(SELF_DAMAGE_PARSERS, "SPELLLOGCRITSELFOTHER",
        function(spell, target, damage)
            return playerName, target, tonumber(damage) or 0, spell, true, nil
        end)

    -- Non-damage spell performs (Sunder Armor, etc.)
    BuildParser(SELF_DAMAGE_PARSERS, "SPELLPERFORMGOSELFTARGETTED",
        function(spell, target)
            return playerName, target, 0, spell, false, nil
        end)
    BuildParser(SELF_DAMAGE_PARSERS, "SPELLCASTGOSELFTARGETTED",
        function(spell, target)
            return playerName, target, 0, spell, false, nil
        end)

    -- Spell hitting self (e.g. own spell reflected)
    BuildParser(SELF_DAMAGE_PARSERS, "SPELLLOGSCHOOLSELFSELF",
        function(spell, damage, school)
            return playerName, playerName, tonumber(damage) or 0, spell, false, school
        end)

    -- ========================================
    -- CHAT_MSG_SPELL_SELF_BUFF parsers
    -- Healing from player
    -- ========================================
    BuildParser(SELF_HEAL_PARSERS, "HEALEDSELFOTHER",
        function(spell, target, amount)
            return playerName, target, tonumber(amount) or 0, spell, false, nil
        end)
    BuildParser(SELF_HEAL_PARSERS, "HEALEDCRITSELFOTHER",
        function(spell, target, amount)
            return playerName, target, tonumber(amount) or 0, spell, true, nil
        end)
    BuildParser(SELF_HEAL_PARSERS, "HEALEDSELFSELF",
        function(spell, amount)
            return playerName, playerName, tonumber(amount) or 0, spell, false, nil
        end)
    BuildParser(SELF_HEAL_PARSERS, "HEALEDCRITSELFSELF",
        function(spell, amount)
            return playerName, playerName, tonumber(amount) or 0, spell, true, nil
        end)

    -- ========================================
    -- CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS parsers
    -- HoT ticks and power gains
    -- ========================================
    BuildParser(PERIODIC_PARSERS, "PERIODICAURAHEALSELFSELF",
        function(amount, spell)
            return playerName, playerName, tonumber(amount) or 0, spell, false, nil
        end)
    BuildParser(PERIODIC_PARSERS, "PERIODICAURAHEALSELFOTHER",
        function(target, amount, spell)
            return playerName, target, tonumber(amount) or 0, spell, false, nil
        end)
    -- Power gains (rage, energy, mana)
    BuildParser(PERIODIC_PARSERS, "POWERGAINSELFSELF",
        function(amount, powerType, spell)
            return playerName, nil, tonumber(amount) or 0, spell, false, powerType
        end)

    -- ========================================
    -- CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE parsers
    -- DoT ticks from player on mobs
    -- ========================================
    BuildParser(PERIODIC_PARSERS, "PERIODICAURADAMAGESELFOTHER",
        function(target, damage, school, spell)
            return playerName, target, tonumber(damage) or 0, spell, false, school
        end)

    addon:ui_print("Threat engine: " .. table.getn(SELF_DAMAGE_PARSERS) ..
        " damage, " .. table.getn(SELF_HEAL_PARSERS) ..
        " heal, " .. table.getn(PERIODIC_PARSERS) .. " periodic parsers built")

    -- ========================================
    -- CHAT_MSG_SPELL_PARTY_DAMAGE parsers
    -- CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE parsers
    -- Spell/ability damage from party/raid members
    -- Uses OTHEROTHER GlobalStrings: "%s's %s hits %s for %d."
    -- Vanilla 1.12 has no PARTY-specific GlobalStrings;
    -- the same OTHEROTHER patterns appear on party/friendly events.
    -- ========================================
    BuildParser(PARTY_DAMAGE_PARSERS, "SPELLLOGSCHOOLOTHEROTHER",
        function(source, spell, target, damage, school)
            return source, target, tonumber(damage) or 0, spell, false, school
        end)
    BuildParser(PARTY_DAMAGE_PARSERS, "SPELLLOGCRITSCHOOLOTHEROTHER",
        function(source, spell, target, damage, school)
            return source, target, tonumber(damage) or 0, spell, true, school
        end)
    BuildParser(PARTY_DAMAGE_PARSERS, "SPELLLOGOTHEROTHER",
        function(source, spell, target, damage)
            return source, target, tonumber(damage) or 0, spell, false, nil
        end)
    BuildParser(PARTY_DAMAGE_PARSERS, "SPELLLOGCRITOTHEROTHER",
        function(source, spell, target, damage)
            return source, target, tonumber(damage) or 0, spell, true, nil
        end)

    -- ========================================
    -- CHAT_MSG_COMBAT_PARTY_HITS parsers
    -- Auto-attack (white damage) from party/raid members
    -- Uses OTHEROTHER GlobalStrings: "%s hits %s for %d."
    -- ========================================
    BuildParser(PARTY_DAMAGE_PARSERS, "COMBATHITOTHEROTHER",
        function(source, target, damage)
            return source, target, tonumber(damage) or 0, nil, false, nil
        end)
    BuildParser(PARTY_DAMAGE_PARSERS, "COMBATHITCRITOTHEROTHER",
        function(source, target, damage)
            return source, target, tonumber(damage) or 0, nil, true, nil
        end)
    BuildParser(PARTY_DAMAGE_PARSERS, "COMBATHITSCHOOLOTHEROTHER",
        function(source, target, damage, school)
            return source, target, tonumber(damage) or 0, nil, false, school
        end)
    BuildParser(PARTY_DAMAGE_PARSERS, "COMBATHITCRITSCHOOLOTHEROTHER",
        function(source, target, damage, school)
            return source, target, tonumber(damage) or 0, nil, true, school
        end)

    -- ========================================
    -- CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE parsers
    -- CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE parsers
    -- DoT ticks from party/raid members
    -- Uses OTHEROTHER: "%s suffers %d %s damage from %s's %s."
    -- ========================================
    BuildParser(PARTY_DAMAGE_PARSERS, "PERIODICAURADAMAGEOTHEROTHER",
        function(target, damage, school, source, spell)
            return source, target, tonumber(damage) or 0, spell, false, school
        end)

    -- ========================================
    -- CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF parsers
    -- CHAT_MSG_SPELL_PARTY_BUFF parsers
    -- Healing from party/raid members
    -- Uses OTHEROTHER GlobalStrings: "%s's %s heals %s for %d."
    -- ========================================
    BuildParser(PARTY_HEAL_PARSERS, "HEALEDOTHEROTHER",
        function(source, spell, target, amount)
            return source, target, tonumber(amount) or 0, spell, false, nil
        end)
    BuildParser(PARTY_HEAL_PARSERS, "HEALEDCRITOTHEROTHER",
        function(source, spell, target, amount)
            return source, target, tonumber(amount) or 0, spell, true, nil
        end)
    -- OTHERSELF: "%s's %s heals you for %d." - party member healing the player
    BuildParser(PARTY_HEAL_PARSERS, "HEALEDOTHERSELF",
        function(source, spell, amount)
            return source, playerName, tonumber(amount) or 0, spell, false, nil
        end)
    BuildParser(PARTY_HEAL_PARSERS, "HEALEDCRITOTHERSELF",
        function(source, spell, amount)
            return source, playerName, tonumber(amount) or 0, spell, true, nil
        end)

    -- ========================================
    -- CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS parsers
    -- CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS parsers
    -- HoT ticks from party/raid members
    -- Uses OTHEROTHER: "%s gains %d health from %s's %s."
    -- Note: SELFOTHER is NOT included here to avoid double-counting
    -- with CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS which already tracks
    -- the player's own HoT ticks via the self-event handlers.
    -- ========================================
    BuildParser(PARTY_PERIODIC_PARSERS, "PERIODICAURAHEALOTHEROTHER",
        function(target, amount, source, spell)
            return source, target, tonumber(amount) or 0, spell, false, nil
        end)

    addon:ui_print("Threat engine: " .. table.getn(PARTY_DAMAGE_PARSERS) ..
        " party damage, " .. table.getn(PARTY_HEAL_PARSERS) ..
        " party heal, " .. table.getn(PARTY_PERIODIC_PARSERS) ..
        " party periodic parsers built")

    -- ========================================
    -- INCOMING (mob -> player/party) parsers (v2.6.2)
    -- Used to detect that a specific mob NAME is actively engaged
    -- with the group even though we have no unit token for it.
    -- We only care about the first capture (the mob / source name).
    -- Any OTHERSELF or OTHEROTHER GlobalString whose first %s is the
    -- attacker qualifies. Some of these constants may not exist on
    -- every Turtle/OctoWoW build; missing ones are silently skipped.
    -- ========================================
    local incomingSources = {
        -- Melee mob -> player
        "COMBATHITOTHERSELF", "COMBATHITCRITOTHERSELF",
        "COMBATHITSCHOOLOTHERSELF", "COMBATHITCRITSCHOOLOTHERSELF",
        "MISSEDOTHERSELF",
        "VSDODGEOTHERSELF", "VSPARRYOTHERSELF", "VSBLOCKOTHERSELF",
        "VSABSORBOTHERSELF", "VSIMMUNEOTHERSELF", "VSRESISTOTHERSELF",
        "VSDEFLECTOTHERSELF", "VSEVADEOTHERSELF",
        -- Spell mob -> player
        "SPELLLOGOTHERSELF", "SPELLLOGSCHOOLOTHERSELF",
        "SPELLLOGCRITOTHERSELF", "SPELLLOGCRITSCHOOLOTHERSELF",
        "SPELLMISSOTHERSELF", "SPELLDODGEDOTHERSELF",
        "SPELLPARRIEDOTHERSELF", "SPELLBLOCKEDOTHERSELF",
        "SPELLRESISTOTHERSELF", "SPELLIMMUNEOTHERSELF",
        "SPELLEVADEDOTHERSELF", "SPELLDEFLECTEDOTHERSELF",
        "SPELLREFLECTOTHERSELF",
        -- Periodic (mob DoT ticking on player)
        "PERIODICAURADAMAGEOTHERSELF",
        -- Melee mob -> other (party member)
        "COMBATHITOTHEROTHER", "COMBATHITCRITOTHEROTHER",
        "COMBATHITSCHOOLOTHEROTHER", "COMBATHITCRITSCHOOLOTHEROTHER",
        "MISSEDOTHEROTHER",
        "VSDODGEOTHEROTHER", "VSPARRYOTHEROTHER", "VSBLOCKOTHEROTHER",
        "VSABSORBOTHEROTHER", "VSIMMUNEOTHEROTHER", "VSRESISTOTHEROTHER",
        "VSDEFLECTOTHEROTHER", "VSEVADEOTHEROTHER",
        -- Spell mob -> other (party member)
        "SPELLLOGOTHEROTHER", "SPELLLOGSCHOOLOTHEROTHER",
        "SPELLLOGCRITOTHEROTHER", "SPELLLOGCRITSCHOOLOTHEROTHER",
        "SPELLMISSOTHEROTHER", "SPELLDODGEDOTHEROTHER",
        "SPELLPARRIEDOTHEROTHER", "SPELLBLOCKEDOTHEROTHER",
        "SPELLRESISTOTHEROTHER", "SPELLIMMUNEOTHEROTHER",
        -- Periodic (mob DoT ticking on party member)
        "PERIODICAURADAMAGEOTHEROTHER",
    }
    for i = 1, table.getn(incomingSources) do
        local gname = incomingSources[i]
        local fs = getglobal(gname)
        if fs then
            local r = FormatToRegex(fs)
            if r then
                local toPlayer = false
                if string.find(gname, "OTHERSELF") or string.find(gname, "TOSELF") then
                    toPlayer = true
                end
                INCOMING_PARSERS[table.getn(INCOMING_PARSERS) + 1] =
                    { regex = r, globalVar = gname, toPlayer = toPlayer }
            end
        end
    end
    addon:ui_print("Threat engine: " .. table.getn(INCOMING_PARSERS) ..
        " incoming (mob->group) parsers built")
end

-- ============================================================
-- Parse a combat log message against a set of parsers
-- Returns: sourceName, targetName, value, spellName, isCrit, spellSchool
-- or nil if no match
-- ============================================================

local function ParseMessage(parserSet, msg)
    if not msg then return nil end

    for i = 1, table.getn(parserSet) do
        local entry = parserSet[i]
        local _, _, c1, c2, c3, c4, c5 = string.find(msg, entry.regex)
        if c1 then
            -- Call the handler with whatever captures we got
            local s, t, v, sp, cr, sc = entry.handler(c1, c2, c3, c4, c5)
            if s then
                return s, t, v, sp, cr, sc
            end
        end
    end
    return nil
end

-- ============================================================
-- Special spell threat table
-- Flat threat values for abilities that generate threat without
-- (or in addition to) damage
-- Values from KTM/ThreatClassic-1.0 class modules
-- ============================================================

local SPELL_THREAT = {}

-- Warrior abilities
SPELL_THREAT["sunder"]        = 261   -- Sunder Armor rank 8
SPELL_THREAT["revenge"]       = 355   -- Revenge rank 6
SPELL_THREAT["shieldslam"]    = 250   -- Shield Slam bonus threat
SPELL_THREAT["heroicstrike"]  = 145   -- Heroic Strike rank 8 bonus threat
SPELL_THREAT["shieldbash"]    = 110   -- Shield Bash bonus threat
SPELL_THREAT["hamstring"]     = 145   -- Hamstring bonus threat
SPELL_THREAT["thunderclap"]   = 130   -- Thunder Clap bonus threat
SPELL_THREAT["demoralizingshout"] = 43 -- Demo Shout threat
SPELL_THREAT["battle shout"]  = 69    -- Battle Shout threat per target hit
SPELL_THREAT["disarm"]        = 104   -- Disarm bonus threat

-- Druid abilities
SPELL_THREAT["maul"]          = nil   -- Maul uses multiplier instead
SPELL_THREAT["swipe"]         = nil   -- Swipe uses multiplier
SPELL_THREAT["demoralizingroar"] = 30 -- Demo Roar threat

-- Warlock abilities
SPELL_THREAT["searingpain"]   = nil   -- Searing Pain uses multiplier
SPELL_THREAT["lifetap"]       = 0     -- Life Tap generates no threat
SPELL_THREAT["drainlife"]     = 0     -- Drain Life generates no threat
SPELL_THREAT["siphonlife"]    = 0     -- Siphon Life generates no threat

-- Priest abilities
SPELL_THREAT["holynova"]      = 0     -- Holy Nova generates no threat

-- Rogue abilities
SPELL_THREAT["feint"]         = -150  -- Feint reduces threat (rank 5)
SPELL_THREAT["vanish"]        = -1000000  -- Vanish wipes threat

-- Spell multiplier table (some spells multiply damage for threat)
local SPELL_MULTIPLIER = {}
SPELL_MULTIPLIER["searingpain"]  = 2.0   -- Searing Pain double threat
SPELL_MULTIPLIER["heroicstrike"] = 1.0   -- HS adds flat + bonus on top
SPELL_MULTIPLIER["maul"]         = 1.75  -- Maul multiplier
SPELL_MULTIPLIER["swipe"]        = 1.0   -- Swipe multiplier

-- Unlocalise spell name: map localised name to internal ID
-- We build this at runtime from known localised names
local spellNameToId = {}

local function BuildSpellNameMap()
    -- Warrior spells
    local warriorSpells = {
        "sunder", "revenge", "shieldslam", "heroicstrike",
        "shieldbash", "hamstring", "thunderclap", "demoralizingshout",
        "disarm"
    }

    -- Check if player is the right class and cache localised names
    if playerClass == "warrior" then
        for i = 1, table.getn(warriorSpells) do
            local id = warriorSpells[i]
            -- Try to get localised name from spellbook
            -- This is a best-effort approach; if we can't find it,
            -- we'll fall back to string matching
        end
    end
end

-- Match a localised spell name against known threat spells
-- Uses simple substring matching for common spell patterns
local function MatchSpell(spellName)
    if not spellName then return nil end

    -- Try exact match first (case-insensitive)
    local lowerName = string.lower(spellName)

    -- Common substring patterns for spell identification
    -- This works across locales where the spell name contains
    -- recognizable fragments

    -- Sunder Armor
    if SPELL_THREAT["sunder"] then
        -- Check if this could be sunder by checking known localisations
        -- English: "Sunder Armor", "Sunder"
        if string.find(lowerName, "sunder") then
            return "sunder"
        end
    end

    -- Revenge
    if string.find(lowerName, "revenge") then
        return "revenge"
    end

    -- Shield Slam
    if string.find(lowerName, "shield slam") or string.find(lowerName, "shieldslam") then
        return "shieldslam"
    end

    -- Shield Bash
    if string.find(lowerName, "shield bash") or string.find(lowerName, "shieldbash") then
        return "shieldbash"
    end

    -- Heroic Strike
    if string.find(lowerName, "heroic strike") or string.find(lowerName, "heroicstrike") then
        return "heroicstrike"
    end

    -- Hamstring
    if string.find(lowerName, "hamstring") then
        return "hamstring"
    end

    -- Thunder Clap
    if string.find(lowerName, "thunder clap") or string.find(lowerName, "thunderclap") then
        return "thunderclap"
    end

    -- Demoralizing Shout
    if string.find(lowerName, "demoralizing") or string.find(lowerName, "demoralising") then
        return "demoralizingshout"
    end

    -- Battle Shout
    if string.find(lowerName, "battle shout") then
        return "battle shout"
    end

    -- Disarm
    if string.find(lowerName, "disarm") then
        return "disarm"
    end

    -- Feint
    if string.find(lowerName, "feint") then
        return "feint"
    end

    -- Vanish
    if string.find(lowerName, "vanish") then
        return "vanish"
    end

    -- Searing Pain
    if string.find(lowerName, "searing pain") or string.find(lowerName, "searingpain") then
        return "searingpain"
    end

    -- Maul
    if string.find(lowerName, "maul") then
        return "maul"
    end

    -- Swipe
    if string.find(lowerName, "swipe") then
        return "swipe"
    end

    -- Life Tap (no threat)
    if string.find(lowerName, "life tap") or string.find(lowerName, "lifetap") then
        return "lifetap"
    end

    -- Holy Nova (no threat)
    if string.find(lowerName, "holy nova") or string.find(lowerName, "holynova") then
        return "holynova"
    end

    return nil
end

-- ============================================================
-- Threat modifier calculation
-- Recalculated periodically based on player buffs, stance, etc.
-- ============================================================

local function CalculateThreatModifier()
    threatModifier = 1.0

    -- Blessing of Salvation (-30%)
    for i = 1, 16 do
        local ok, texture = pcall(UnitBuff, "player", i)
        if ok and texture then
            if texture == "Interface\\Icons\\Spell_Holy_SealOfSalvation" or
               texture == "Interface\\Icons\\Spell_Holy_GreaterBlessingofSalvation" then
                threatModifier = threatModifier * 0.7
            end
        end
    end

    -- Tranquil Air Totem (-20%)
    for i = 1, 16 do
        local ok, texture = pcall(UnitBuff, "player", i)
        if ok and texture then
            if texture == "Interface\\Icons\\Spell_Nature_Brilliance" then
                threatModifier = threatModifier * 0.8
            end
        end
    end

    -- Class-specific modifiers
    if playerClass == "warrior" then
        -- Check stance via buff texture detection
        -- In Vanilla 1.12, stances appear as buffs with specific icons
        local stanceIndex = 0
        for i = 1, 16 do
            local ok, texture = pcall(UnitBuff, "player", i)
            if ok and texture then
                -- Defensive Stance icon
                if texture == "Interface\\Icons\\Ability_Warrior_DefensiveStance" then
                    stanceIndex = 2
                -- Battle Stance icon
                elseif texture == "Interface\\Icons\\Ability_Warrior_BattleStance" then
                    stanceIndex = 1
                -- Berserker Stance icon
                elseif texture == "Interface\\Icons\\Ability_Warrior_BerserkerStance" then
                    stanceIndex = 3
                end
            end
        end

        if stanceIndex == 2 then
            -- Defensive Stance: +30% threat modifier (1.3x)
            threatModifier = threatModifier * 1.3
            -- Defiance talent: +5% per rank (5 ranks max = +25%)
            -- We approximate based on talent tree position
            -- For now, use a conservative estimate
        elseif stanceIndex == 1 then
            -- Battle Stance: -20% threat (0.8x)
            threatModifier = threatModifier * 0.8
        elseif stanceIndex == 3 then
            -- Berserker Stance: -20% threat (0.8x)
            threatModifier = threatModifier * 0.8
        end

    elseif playerClass == "druid" then
        -- Check form
        for i = 1, 16 do
            local ok, texture = pcall(UnitBuff, "player", i)
            if ok and texture then
                -- Bear Form / Dire Bear Form
                if texture == "Interface\\Icons\\Ability_Racial_BearForm" or
                   texture == "Interface\\Icons\\Ability_Racial_DireBearForm" then
                    threatModifier = threatModifier * 1.3
                -- Cat Form
                elseif texture == "Interface\\Icons\\Ability_Druid_CatForm" then
                    threatModifier = threatModifier * 0.71
                end
            end
        end

    elseif playerClass == "rogue" then
        -- Rogues have -29% passive threat modifier
        threatModifier = threatModifier * 0.71

    elseif playerClass == "mage" then
        -- Arcanist 8/8 set bonus: -15%
        -- For now, just base modifier
    end

    -- +2% threat enchant on gloves (enchant ID 2613)
    local ok, link = pcall(GetInventoryItemLink, "player", 10)
    if ok and link then
        local _, _, enchant = string.find(link, ".-item:%d+:(%d+).*")
        if enchant == "2613" then
            threatModifier = threatModifier * 1.02
        end
    end

    -- -2% threat enchant on cloak (enchant ID 2621)
    ok, link = pcall(GetInventoryItemLink, "player", 15)
    if ok and link then
        local _, _, enchant = string.find(link, ".-item:%d+:(%d+).*")
        if enchant == "2621" then
            threatModifier = threatModifier * 0.98
        end
    end
end

-- ============================================================
-- Add threat for a player to a specific target
-- sourceName: the player generating threat (defaults to playerName)
-- ============================================================

local function AddThreat(targetName, amount, sourceName)
    if not targetName then return end
    if not amount then return end
    if amount == 0 then return end

    -- Default source to the player
    if not sourceName then sourceName = playerName end

    -- Don't track threat on friendly targets
    -- We'll let the nameplate system handle the filtering

    -- Initialize target table if needed
    if not threatData[targetName] then
        threatData[targetName] = {}
    end

    -- Add to the source player's threat on this target
    local current = threatData[targetName][sourceName] or 0
    threatData[targetName][sourceName] = current + amount

    -- Clamp to 0 minimum
    if threatData[targetName][sourceName] < 0 then
        threatData[targetName][sourceName] = 0
    end
end

-- ============================================================
-- Get estimated threat modifier for a group member
-- We don't have full buff/stance info for other players, so
-- we estimate based on their class. This is better than using
-- the player's own modifier (which was the old behavior).
-- ============================================================

local function EstimateGroupMemberModifier(memberName)
    -- Default modifier: 1.0 (no adjustment)
    local mod = 1.0

    -- Check cached class for this party member
    local class = partyClassCache[memberName]
    if class then
        if class == "rogue" then
            mod = 0.71
        elseif class == "mage" then
            mod = 1.0
        elseif class == "warrior" then
            -- Could be any stance; default to battle stance (0.8)
            -- Defensive would be 1.3, but we can't know remotely
            mod = 0.8
        elseif class == "druid" then
            -- Could be any form; default to 0.71 (cat/humanoid)
            mod = 0.71
        elseif class == "priest" then
            mod = 0.8  -- shadowform not considered
        elseif class == "warlock" then
            mod = 1.0
        elseif class == "hunter" then
            mod = 1.0
        elseif class == "paladin" then
            mod = 1.0  -- Righteous Fury not considered
        elseif class == "shaman" then
            mod = 1.0
        end
    end

    -- Blessing of Salvation / Tranquil Air Totem can't be detected
    -- remotely, so we don't adjust for those.

    return mod
end

-- ============================================================
-- Cache party member classes for modifier estimation
-- ============================================================

local function UpdatePartyClassCache()
    partyClassCache = {}

    -- Player
    if playerClass then
        partyClassCache[playerName] = playerClass
    end

    -- Party members
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            local ok, name = pcall(UnitName, unit)
            if ok and name then
                local ok2, class = pcall(UnitClass, unit)
                if ok2 and class then
                    partyClassCache[name] = string.lower(class)
                end
            end
        end
    end

    -- Raid members
    for i = 1, 40 do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local ok, name = pcall(UnitName, unit)
            if ok and name then
                local ok2, class = pcall(UnitClass, unit)
                if ok2 and class then
                    partyClassCache[name] = string.lower(class)
                end
            end
        end
    end
end

-- ============================================================
-- Process damage event (from combat log parsing)
-- sourceName: who dealt the damage (player or group member)
-- ============================================================

local function ProcessDamage(sourceName, targetName, damage, spellName, isCrit, spellSchool)
    if not sourceName then return end
    if not targetName then return end

    -- Don't track self-damage
    if targetName == sourceName then return end

    -- Determine threat modifier for the source
    local sourceModifier = threatModifier
    if sourceName ~= playerName then
        sourceModifier = EstimateGroupMemberModifier(sourceName)
    end

    local threatAmount = 0

    -- Check if this is a special spell with known threat values
    local spellId = MatchSpell(spellName)

    if spellId and SPELL_THREAT[spellId] ~= nil then
        -- Special spell with flat threat value
        local flatThreat = SPELL_THREAT[spellId]

        if flatThreat == 0 then
            -- No threat from this spell (Life Tap, Holy Nova, etc.)
            return
        elseif flatThreat < 0 then
            -- Negative threat (Feint, Vanish)
            AddThreat(targetName, flatThreat * sourceModifier, sourceName)
            return
        else
            -- Flat threat + damage threat
            threatAmount = damage + flatThreat
        end

    elseif spellId and SPELL_MULTIPLIER[spellId] then
        -- Spell with threat multiplier
        threatAmount = damage * SPELL_MULTIPLIER[spellId]

    else
        -- Normal damage: 1 threat per damage
        threatAmount = damage
    end

    -- Apply source's threat modifier
    threatAmount = threatAmount * sourceModifier

    AddThreat(targetName, threatAmount, sourceName)
end

-- ============================================================
-- Process heal event
-- Healing generates 0.5x threat, split across all mobs in combat
-- ============================================================

local function ProcessHeal(sourceName, targetName, amount, spellName)
    if not sourceName then return end
    if not amount or amount <= 0 then return end

    -- Skip healing on hostile targets
    if targetName then
        local unit = addon.Nameplates and addon.Nameplates:FindUnitByName(targetName)
        if unit then
            local ok, canAttack = pcall(UnitCanAttack, "player", unit)
            if ok and canAttack then return end
        end
    end

    -- Calculate effective heal (minus overheal)
    -- We can check the target's health deficit to estimate overheal
    local effectiveAmount = amount
    if targetName then
        local unit = addon.Nameplates and addon.Nameplates:FindUnitByName(targetName)
        if unit then
            local ok, maxHp = pcall(UnitHealthMax, unit)
            if ok and maxHp then
                local ok2, hp = pcall(UnitHealth, unit)
                if ok2 and hp then
                    local deficit = maxHp - hp
                    if deficit > 0 then
                        effectiveAmount = math.min(amount, deficit)
                    else
                        effectiveAmount = 0
                    end
                end
            end
        end
    end

    if effectiveAmount <= 0 then return end

    -- Determine threat modifier for the source
    local sourceModifier = threatModifier
    if sourceName ~= playerName then
        sourceModifier = EstimateGroupMemberModifier(sourceName)
    end

    -- Healing threat = amount * 0.5 * sourceModifier
    local healThreat = effectiveAmount * THREAT_CONST.healing * sourceModifier

    -- Split healing threat across mobs the player is ACTIVELY in combat with.
    -- We use GetEngagedMobs() which verifies each mob is actually in combat
    -- via UnitAffectingCombat, rather than just having a threatData entry.
    -- This prevents healing threat from being added to idle nearby mobs that
    -- accumulated threat from prior healing splits.
    local engagedMobs, mobCount = addon.ThreatEngine:GetEngagedMobs()

    if mobCount > 0 then
        -- Add healing threat to all engaged mobs (split evenly)
        local splitThreat = healThreat / mobCount
        for i = 1, mobCount do
            AddThreat(engagedMobs[i], splitThreat, sourceName)
        end
    else
        -- Source has no actively engaged mobs yet - add healing threat to current target
        -- For group members, use the player's current target as approximation
        if sourceName == playerName then
            if currentTargetName then
                AddThreat(currentTargetName, healThreat, sourceName)
            end
        end
    end
end

-- ============================================================
-- Process power gain event (rage, energy, mana)
-- ============================================================

local function ProcessPowerGain(sourceName, amount, powerType, spellName)
    if sourceName ~= playerName then return end
    if not amount or amount <= 0 then return end

    -- Prevent "overheal" for power gain
    local ok, maxPower = pcall(UnitManaMax, "player")
    if ok and maxPower then
        local ok2, power = pcall(UnitMana, "player")
        if ok2 and power then
            amount = math.min(amount, maxPower - power)
        end
    end

    local playerPowerType = UnitPowerType("player")
    local gainThreat = 0

    -- Check power type matches player's power type
    -- powerType is localised (e.g. "Mana", "Rage", "Energy")
    if powerType then
        local pt = string.lower(powerType)
        if string.find(pt, "rage") and playerPowerType == 1 then
            gainThreat = amount * THREAT_CONST.rageGain
        elseif string.find(pt, "energy") and playerPowerType == 3 then
            gainThreat = amount * THREAT_CONST.energyGain
        elseif string.find(pt, "mana") and playerPowerType == 0 then
            gainThreat = amount * THREAT_CONST.manaGain
        end
    end

    -- Skip Life Tap (warlock mana gain = no threat)
    if spellName then
        local spellId = MatchSpell(spellName)
        if spellId == "lifetap" then return end
    end

    if gainThreat > 0 then
        -- Add to current target
        if currentTargetName then
            AddThreat(currentTargetName, gainThreat * threatModifier)
        end
    end
end

-- ============================================================
-- Sunder Armor handling (KTM-style transaction)
-- We assume sunder hits when cast, and retract on failure
-- ============================================================

local function SubmitSunderCast()
    if playerClass ~= "warrior" then return end
    if not currentTargetName then return end

    -- Add sunder threat immediately
    local sunderThreat = SPELL_THREAT["sunder"] or 261
    AddThreat(currentTargetName, sunderThreat * threatModifier)
    pendingSunder = currentTargetName
    pendingSunderTime = GetTime()
end

local function RetractSunderCast()
    if not pendingSunder then return end

    -- Remove the sunder threat we added
    local sunderThreat = SPELL_THREAT["sunder"] or 261
    AddThreat(pendingSunder, -(sunderThreat * threatModifier))
    pendingSunder = nil
end

-- ============================================================
-- Addon Communication
-- Broadcast threat data to group members
-- ============================================================

local function BroadcastThreat()
    -- Only broadcast if in a group
    local inParty = GetNumPartyMembers() > 0
    local inRaid = GetNumRaidMembers() > 0
    if not inParty and not inRaid then return end

    -- Build threat data string
    -- Format: "TPv1~target1:player=val~target2:player=val~..."
    -- NOTE: Uses ~ as delimiter instead of | because | is the WoW
    -- chat escape prefix (|c, |H, |T, etc.) and causes "invalid
    -- escape code in chat message" errors if a name starts with
    -- one of those letters after a | delimiter.
    local parts = {}
    local count = 0
    for target, sources in pairs(threatData) do
        for source, value in pairs(sources) do
            if value > 0 then
                count = count + 1
                -- Sanitize: replace any ~ in names with - to avoid
                -- delimiter collision (extremely rare but safe)
                local safeTarget = string.gsub(target, "~", "-")
                local safeSource = string.gsub(source, "~", "-")
                parts[count] = safeTarget .. ":" .. safeSource .. "=" .. string.format("%.0f", value)
                -- Limit broadcast size to avoid chat message length limits
                if count >= 20 then
                    -- Send what we have so far
                    local msg = "TPv1~" .. table.concat(parts, "~")
                    SendAddonMessage(COMM_PREFIX, msg, inRaid and "RAID" or "PARTY")
                    parts = {}
                    count = 0
                end
            end
        end
    end

    if count > 0 then
        local msg = "TPv1~" .. table.concat(parts, "~")
        SendAddonMessage(COMM_PREFIX, msg, inRaid and "RAID" or "PARTY")
    end
end

-- Parse incoming threat data from other players
local function ReceiveThreat(msg)
    if not msg then return end

    -- Check version prefix (now uses ~ as separator)
    local _, _, version = string.find(msg, "^(TPv%d+)~")
    if not version then return end

    -- Remove version prefix
    local data = string.gsub(msg, "^TPv%d+~", "")

    -- Parse entries: target:source=value (delimited by ~)
    for entry in string.gfind(data, "[^~]+") do
        local _, _, target, source, value = string.find(entry, "(.+):(.+)=(%d+)")
        if target and source and value then
            if not threatData[target] then
                threatData[target] = {}
            end
            local numValue = tonumber(value) or 0
            -- Only update if the incoming value is higher (avoid stale data overwriting fresh)
            if not threatData[target][source] or numValue > threatData[target][source] then
                threatData[target][source] = numValue
            end
        end
    end
end

-- ============================================================
-- Taunt handling
-- When you taunt, you gain threat equal to the current top threat
-- ============================================================

local function ProcessTaunt(targetName)
    if not targetName then return end
    if not threatData[targetName] then return end

    -- Find the maximum threat on this target from any player
    local maxThreat = 0
    for source, value in pairs(threatData[targetName]) do
        if value > maxThreat then
            maxThreat = value
        end
    end

    -- Set player's threat to match the top
    local playerThreat = threatData[targetName][playerName] or 0
    if maxThreat > playerThreat then
        AddThreat(targetName, maxThreat - playerThreat)
    end
end

-- ============================================================
-- Event handler for combat log events
-- ============================================================

-- Mark a mob name as actively attacking someone in the group.
-- Filters out anything that is obviously a player (self or a cached
-- party/raid member class). Unknown names are assumed to be mobs.
local function MarkMobAttackingGroup(name)
    if not name or name == "" then return end
    if playerName and name == playerName then return end
    if partyClassCache and partyClassCache[name] then return end
    mobsAttackingGroup[name] = GetTime()
end

-- Same as MarkMobAttackingGroup, but flags the mob as specifically
-- attacking the player. Used to distinguish "attacking me" from
-- "attacking a party member" in the nameplate fallback branches.
local function MarkMobAttackingPlayer(name)
    if not name or name == "" then return end
    if playerName and name == playerName then return end
    if partyClassCache and partyClassCache[name] then return end
    mobsAttackingPlayer[name] = GetTime()
end

-- Parse an incoming combat-log message and, if it matches any known
-- mob->group pattern, flag the first capture (the source mob name).
local function ParseIncomingMessage(msg)
    if not msg or not INCOMING_PARSERS then return end
    for i = 1, table.getn(INCOMING_PARSERS) do
        local p = INCOMING_PARSERS[i]
        local _, _, c1 = string.find(msg, p.regex)
        if c1 then
            MarkMobAttackingGroup(c1)
            if p.toPlayer then
                MarkMobAttackingPlayer(c1)
            end
            return
        end
    end
end

-- Public API: is this mob name currently flagged as attacking the group?
function addon.ThreatEngine:IsMobAttackingGroup(mobName)
    if not mobName then return false end
    local t = mobsAttackingGroup[mobName]
    if not t then return false end
    if GetTime() - t > MOB_ATTACK_TTL then
        mobsAttackingGroup[mobName] = nil
        return false
    end
    return true
end

-- Public API: is this mob name currently flagged as specifically
-- attacking the player (not just any group member)?
function addon.ThreatEngine:IsMobAttackingPlayer(mobName)
    if not mobName then return false end
    local t = mobsAttackingPlayer[mobName]
    if not t then return false end
    if GetTime() - t > MOB_ATTACK_TTL then
        mobsAttackingPlayer[mobName] = nil
        return false
    end
    return true
end

-- Public API: return the raw table (name -> lastSeen). Caller must not
-- mutate it. Used mainly by debug commands.
function addon.ThreatEngine:GetMobsAttackingGroup()
    return mobsAttackingGroup
end

-- Called by the event frame for any CREATURE_VS_* combat log event.
function addon.ThreatEngine:OnIncomingCombat(ev, msg)
    ParseIncomingMessage(msg)
end

function addon.ThreatEngine:OnCombatEvent(ev, msg)
    if not msg then return end
    if not playerName then return end

    -- Strip absorb/resist suffixes (like KTM does)
    -- These can modify the damage string format
    if ABSORB_TRAILER then
        msg = string.gsub(msg, FormatToRegex(ABSORB_TRAILER), "")
    end

    -- Process based on event type
    if ev == "CHAT_MSG_COMBAT_SELF_HITS" then
        local s, t, v, sp, cr, sc = ParseMessage(SELF_DAMAGE_PARSERS, msg)
        if s then
            ProcessDamage(s, t, v, sp, cr, sc)
        end

    elseif ev == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        local s, t, v, sp, cr, sc = ParseMessage(SELF_DAMAGE_PARSERS, msg)
        if s then
            -- Check for Sunder Armor failure (retract pending sunder)
            if sp and string.find(string.lower(sp), "sunder") then
                -- If we had a pending sunder, check if this is a failure message
                if string.find(msg, "fail") or string.find(msg, "fail:") then
                    RetractSunderCast()
                end
            end

            -- Check for taunt
            if sp then
                local lowerSpell = string.lower(sp)
                if string.find(lowerSpell, "taunt") then
                    ProcessTaunt(t)
                end
            end

            ProcessDamage(s, t, v, sp, cr, sc)
        end

    elseif ev == "CHAT_MSG_SPELL_SELF_BUFF" then
        local s, t, v, sp, cr, sc = ParseMessage(SELF_HEAL_PARSERS, msg)
        if s then
            ProcessHeal(s, t, v, sp)
        end
        -- Also check for power gains in this event
        local ps, pt, pv, psp, pcr, psc = ParseMessage(PERIODIC_PARSERS, msg)
        if ps and psc then
            -- psc contains the power type for POWERGAINSELFSELF
            ProcessPowerGain(ps, pv, psc, psp)
        end

    elseif ev == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then
        local s, t, v, sp, cr, sc = ParseMessage(PERIODIC_PARSERS, msg)
        if s then
            if sc and (string.lower(sc) == "mana" or string.lower(sc) == "rage" or string.lower(sc) == "energy") then
                -- This is a power gain, not a heal
                ProcessPowerGain(s, v, sc, sp)
            else
                -- This is a HoT tick
                ProcessHeal(s, t, v, sp)
            end
        end

    elseif ev == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
        local s, t, v, sp, cr, sc = ParseMessage(PERIODIC_PARSERS, msg)
        if s then
            ProcessDamage(s, t, v, sp, cr, sc)
        end

    elseif ev == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" then
        -- Self-inflicted periodic damage (e.g. standing in fire)
        -- Usually no threat implications, skip

    elseif ev == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
        -- A hostile unit died - clear threat on it
        -- Try multiple patterns for robustness across locales
        local deadName = nil
        -- Pattern 1: "X dies." (English)
        _, _, deadName = string.find(msg, "^(.+) dies%.$")
        if not deadName then
            -- Pattern 2: "X dies." without anchor
            _, _, deadName = string.find(msg, "(.+) dies%.")
        end
        if not deadName then
            -- Pattern 3: Try the GlobalStrings pattern for UNITDIESOTHER
            local unitDiesOther = getglobal("UNITDIESOTHER")
            if unitDiesOther then
                local diesRegex = FormatToRegex(unitDiesOther)
                if diesRegex then
                    _, _, deadName = string.find(msg, diesRegex)
                end
            end
        end
        if deadName and threatData[deadName] then
            threatData[deadName] = nil
        end

    elseif ev == "CHAT_MSG_COMBAT_FRIENDLY_DEATH" then
        -- Player died - wipe threat
        if msg == UNITDIESSELF then
            -- "You die."
            threatData = {}
        end

    elseif ev == "CHAT_MSG_SPELL_FAILED_LOCALPLAYER" then
        -- Spell failed - check for sunder failure
        if string.find(string.lower(msg), "sunder") then
            RetractSunderCast()
        end

    elseif ev == "CHAT_MSG_ADDON" then
        -- Addon communication - receive threat data from others
        -- arg1 = prefix, arg2 = message, arg3 = channel, arg4 = sender
        if arg1 == COMM_PREFIX then
            ReceiveThreat(arg2)
        end
    end
end

-- ============================================================
-- Get threat percentage for a specific mob
-- Returns: threatPct (0-100), threatSit (0-3), rawThreat, topThreat,
--          hasGroupData, bestSourceName
--
-- KEY CHANGE: Now returns threat info for ALL group members, not
-- just the player. The bestPct reflects the highest threat from
-- any group member. The caller can use this to show accurate
-- threat bars on mobs attacking any group member.
-- ============================================================

function addon.ThreatEngine:GetThreatOnTarget(mobName)
    if not mobName then return 0, 0, 0, 0, false, nil, 0 end

    -- Check if we have threat data for this mob
    local mobThreat = threatData[mobName]
    if not mobThreat then
        return 0, 0, 0, 0, false, nil, 0
    end

    -- Find player's threat, top threat and second-highest threat
    local playerThreat = mobThreat[playerName] or 0
    local topThreat = 0
    local topPlayer = nil
    local secondThreat = 0
    local sourceCount = 0

    for source, value in pairs(mobThreat) do
        sourceCount = sourceCount + 1
        if value > topThreat then
            secondThreat = topThreat
            topThreat = value
            topPlayer = source
        elseif value > secondThreat then
            secondThreat = value
        end
    end

    if topThreat <= 0 then
        return 0, 0, 0, 0, false, nil, 0
    end

    -- Calculate the player's threat percentage.
    --
    -- Two-mode display so the number matches user intuition:
    --   * If the player IS the current top-threat holder, show how far
    --     ahead they are of the runner-up: pct = playerThreat/second * 100.
    --     A tank comfortably tanking a mob will read something like 120%
    --     or 200% — anything > 100 means "you are above the next player".
    --   * If the player is NOT top, show their share of the top holder's
    --     threat: pct = playerThreat/top * 100. This is 0-100 and answers
    --     "how close am I to pulling aggro off the current top holder".
    --
    -- This lets the plate show > 100% for the actual threat leader
    -- instead of clamping everyone with aggro to a flat 100%.
    local pct
    if topPlayer == playerName then
        if secondThreat > 0 then
            pct = (playerThreat / secondThreat) * 100
        else
            pct = 100
        end
        if pct < 100 then pct = 100 end -- safety: top holder never below 100
    else
        pct = (playerThreat / topThreat) * 100
        if pct > 100 then pct = 100 end -- non-top can't exceed the leader
    end

    -- Determine threat situation based on the player's threat
    local sit = 0
    if topPlayer == playerName then
        -- Player has aggro (or is tied for top)
        sit = 3
    elseif pct >= 60 then
        sit = 2
    elseif pct >= 30 then
        sit = 1
    else
        sit = 0
    end

    -- hasGroupData: true if we have threat data from OTHER players
    -- (via addon communication or party combat log parsing).
    local hasGroupData = (sourceCount > 1)

    return pct, sit, playerThreat, topThreat, hasGroupData, topPlayer, secondThreat
end

-- ============================================================
-- Get threat info for a specific group member on a mob
-- Returns: memberPct (0-100), memberSit (0-3), memberThreat
-- ============================================================

function addon.ThreatEngine:GetMemberThreatOnTarget(mobName, memberName)
    if not mobName or not memberName then return 0, 0, 0 end

    local mobThreat = threatData[mobName]
    if not mobThreat then
        return 0, 0, 0
    end

    local memberThreat = mobThreat[memberName] or 0
    if memberThreat <= 0 then
        return 0, 0, 0
    end

    -- Find top threat on this mob
    local topThreat = 0
    for source, value in pairs(mobThreat) do
        if value > topThreat then
            topThreat = value
        end
    end

    if topThreat <= 0 then
        return 0, 0, 0
    end

    local pct = (memberThreat / topThreat) * 100
    local sit = 0
    if pct >= 100 then
        sit = 3
    elseif pct >= 60 then
        sit = 2
    elseif pct >= 30 then
        sit = 1
    end

    return pct, sit, memberThreat
end

-- ============================================================
-- Get threat data for the player on a specific mob
-- ============================================================

function addon.ThreatEngine:GetPlayerThreat(mobName)
    if not mobName then return 0 end
    if not threatData[mobName] then return 0 end
    return threatData[mobName][playerName] or 0
end

-- ============================================================
-- Get the mob that the player has the most threat on
-- ============================================================

function addon.ThreatEngine:GetTopThreatTarget()
    local maxThreat = 0
    local maxTarget = nil

    for target, sources in pairs(threatData) do
        local playerThreat = sources[playerName] or 0
        if playerThreat > maxThreat then
            maxThreat = playerThreat
            maxTarget = target
        end
    end

    return maxTarget, maxThreat
end

-- ============================================================
-- Get list of mob names the player or group is actively engaged with.
-- A mob is "engaged" if:
--   1. Any group member has threat on it (threatData entry exists)
--   2. The mob can be found via a unit token
--   3. The mob is actually in combat (UnitAffectingCombat)
--
-- KEY CHANGE: Now includes mobs that ANY group member has threat on,
-- not just the player. This ensures healing threat splits across
-- all mobs the group is fighting, and threat bars appear on all
-- engaged mobs.
--
-- Returns: table of mob names (indexed), count
-- ============================================================

function addon.ThreatEngine:GetEngagedMobs()
    local engaged = {}
    local count = 0

    for targetName, sources in pairs(threatData) do
        -- Check if any group member has threat on this mob
        local hasActiveThreat = false
        for source, value in pairs(sources) do
            if value > 0 then
                -- Verify the source is in our group (or is the player)
                if source == playerName or partyClassCache[source] then
                    hasActiveThreat = true
                    break
                end
            end
        end

        if hasActiveThreat then
            -- Verify the mob is actually in combat.
            -- CRITICAL FIX for same-name mobs: Check ALL unit tokens
            -- matching this name. If ANY is in combat, the mob is engaged.
            local anyInCombat = false

            if addon.Nameplates and addon.Nameplates.GetCandidateUnitsByName then
                local candidates = addon.Nameplates:GetCandidateUnitsByName(targetName)
                for i = 1, table.getn(candidates) do
                    if candidates[i].inCombat then
                        anyInCombat = true
                        break
                    end
                end
            else
                -- Fallback: single-token check
                local unit = addon.Nameplates and addon.Nameplates:FindUnitByName(targetName)
                if unit then
                    local ok, inCombat = pcall(UnitAffectingCombat, unit)
                    if ok and inCombat then
                        anyInCombat = true
                    end
                end
            end

            if anyInCombat then
                count = count + 1
                engaged[count] = targetName
            elseif addon.ThreatEngine:IsGroupInCombat() then
                -- Can't find any in-combat unit token for this name.
                -- If anyone in the group is in combat, assume it's still
                -- engaged (mob might be out of unit-token range).
                count = count + 1
                engaged[count] = targetName
            end
        end
    end

    return engaged, count
end

-- ============================================================
-- Update group combat state.
-- Checks all party/raid members to see if any are in combat.
-- This is essential for showing threat on mobs attacking group
-- members when the player is NOT in combat.
-- ============================================================

local function UpdateGroupCombatState()
    groupInCombat = false

    -- Check player
    if UnitAffectingCombat("player") then
        groupInCombat = true
        return
    end

    -- Check party members
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            local ok, inCombat = pcall(UnitAffectingCombat, unit)
            if ok and inCombat then
                groupInCombat = true
                return
            end
        end
    end

    -- Check raid members
    for i = 1, 40 do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local ok, inCombat = pcall(UnitAffectingCombat, unit)
            if ok and inCombat then
                groupInCombat = true
                return
            end
        end
    end
end

-- ============================================================
-- Check if any group member (player or party/raid) is in combat.
-- Returns: true if any group member is in combat, false otherwise.
-- ============================================================

function addon.ThreatEngine:IsGroupInCombat()
    return groupInCombat or playerInCombat
end

-- ============================================================
-- Clear all threat data
-- ============================================================

function addon.ThreatEngine:ClearAll()
    threatData = {}
    mobsAttackingGroup = {}
    mobsAttackingPlayer = {}
end

-- ============================================================
-- Clear only the player's own threat data, preserving group data.
-- Called when the player leaves combat but group members may
-- still be fighting.
-- ============================================================

function addon.ThreatEngine:ClearPlayerThreat()
    for target, sources in pairs(threatData) do
        sources[playerName] = nil
        -- If no sources remain for this target, remove the entry
        local hasAny = false
        for s, v in pairs(sources) do
            if v and v > 0 then
                hasAny = true
                break
            end
        end
        if not hasAny then
            threatData[target] = nil
        end
    end
end

-- ============================================================
-- Clear threat on a specific target
-- ============================================================

function addon.ThreatEngine:ClearTarget(mobName)
    if mobName then
        threatData[mobName] = nil
    end
end

-- ============================================================
-- Decay old threat entries (prevents stale data buildup)
-- ============================================================

function addon.ThreatEngine:DecayOld()
    -- Remove mobs that are no longer in combat or have zero threat.
    -- This prevents stale threat data from causing threat bars to
    -- appear on idle nearby mobs.
    --
    -- CRITICAL FIX for same-name mobs: FindUnitByName only returns the
    -- FIRST unit token matching a name. With multiple same-name mobs
    -- (e.g. 3 "Defias Bandit"), it might find an idle one while a
    -- different one with the same name is still in combat.
    --
    -- Solution: Check ALL unit tokens matching the mob name. Only
    -- remove threat data if NO same-name unit is in combat.
    --
    -- Collect keys first to avoid modifying table during pairs() iteration.
    local toRemove = {}
    local removeCount = 0
    for target, sources in pairs(threatData) do
        local shouldRemove = false

        -- Condition 1: All sources have zero threat
        local hasActiveThreat = false
        for source, value in pairs(sources) do
            if value > 0 then
                hasActiveThreat = true
                break
            end
        end
        if not hasActiveThreat then
            shouldRemove = true
        end

        -- Condition 2: No one in the group is in combat — clear all mob threat.
        if not shouldRemove and not addon.ThreatEngine:IsGroupInCombat() then
            shouldRemove = true
        end

        -- Condition 3: Are ALL same-name mobs out of combat?
        -- This is the critical same-name fix. We must check ALL unit
        -- tokens matching this mob name, not just the first one.
        if not shouldRemove and addon.ThreatEngine:IsGroupInCombat() then
            local anyInCombat = false

            -- Use GetCandidateUnitsByName to find ALL matching units
            if addon.Nameplates and addon.Nameplates.GetCandidateUnitsByName then
                local candidates = addon.Nameplates:GetCandidateUnitsByName(target)
                for i = 1, table.getn(candidates) do
                    if candidates[i].inCombat then
                        anyInCombat = true
                        break
                    end
                end
            else
                -- Fallback: single-token check (less accurate but safe)
                local unit = addon.Nameplates and addon.Nameplates:FindUnitByName(target)
                if unit then
                    local ok, inCombat = pcall(UnitAffectingCombat, unit)
                    if ok and inCombat then
                        anyInCombat = true
                    end
                end
            end

            if not anyInCombat then
                shouldRemove = true
            end
        end

        if shouldRemove then
            removeCount = removeCount + 1
            toRemove[removeCount] = target
        end
    end
    for i = 1, removeCount do
        threatData[toRemove[i]] = nil
    end
end

-- ============================================================
-- Party/raid member damage event handler
-- Parses CHAT_MSG_SPELL_PARTY_DAMAGE, CHAT_MSG_COMBAT_PARTY_HITS,
-- CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE, CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS,
-- CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE, and
-- CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE events
-- ============================================================

function addon.ThreatEngine:OnPartyDamageEvent(ev, msg)
    if not msg then return end
    if not playerName then return end

    -- Only process if in a group
    local inParty = GetNumPartyMembers() > 0
    local inRaid = GetNumRaidMembers() > 0
    if not inParty and not inRaid then return end

    -- Strip absorb/resist suffixes
    if ABSORB_TRAILER then
        msg = string.gsub(msg, FormatToRegex(ABSORB_TRAILER), "")
    end

    -- Try to parse against party damage parsers
    local s, t, v, sp, cr, sc = ParseMessage(PARTY_DAMAGE_PARSERS, msg)
    if s then
        -- Validate: source must be a known party/raid member
        if s ~= playerName and not partyClassCache[s] then
            -- Source is not in our group - might be a naming mismatch
            -- or the parser captured the wrong field. Skip.
            return
        end
        ProcessDamage(s, t, v, sp, cr, sc)
    end
end

-- ============================================================
-- Party/raid member heal event handler
-- Parses CHAT_MSG_SPELL_PARTY_BUFF and
-- CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF events
-- ============================================================

function addon.ThreatEngine:OnPartyHealEvent(ev, msg)
    if not msg then return end
    if not playerName then return end

    local inParty = GetNumPartyMembers() > 0
    local inRaid = GetNumRaidMembers() > 0
    if not inParty and not inRaid then return end

    local s, t, v, sp, cr, sc = ParseMessage(PARTY_HEAL_PARSERS, msg)
    if s then
        if s ~= playerName and not partyClassCache[s] then
            return
        end
        ProcessHeal(s, t, v, sp)
    end
end

-- ============================================================
-- Party/raid member periodic event handler
-- Parses CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS and
-- CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS events
-- ============================================================

function addon.ThreatEngine:OnPartyPeriodicEvent(ev, msg)
    if not msg then return end
    if not playerName then return end

    local inParty = GetNumPartyMembers() > 0
    local inRaid = GetNumRaidMembers() > 0
    if not inParty and not inRaid then return end

    local s, t, v, sp, cr, sc = ParseMessage(PARTY_PERIODIC_PARSERS, msg)
    if s then
        if s ~= playerName and not partyClassCache[s] then
            return
        end
        -- HoT ticks from group members generate healing threat
        ProcessHeal(s, t, v, sp)
    end
end

-- ============================================================
-- Initialize the threat engine
-- ============================================================

function addon.ThreatEngine:Initialize()
    playerName = UnitName("player")
    local _, class = UnitClass("player")
    playerClass = string.lower(class or "")

    -- Build parsers from GlobalStrings
    BuildAllParsers()

    -- Calculate initial threat modifier
    CalculateThreatModifier()

    -- Register for all combat log events we need
    local combatFrame = CreateFrame("Frame", "RelationshipsThreatPlatesCombatFrame")

    -- Damage events
    combatFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")

    -- Heal events
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")

    -- Periodic events (HoTs, DoTs, power gains)
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")

    -- Death events (threat wipes)
    combatFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
    combatFrame:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH")

    -- Spell failure (sunder retraction)
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_FAILED_LOCALPLAYER")

    -- Addon communication
    combatFrame:RegisterEvent("CHAT_MSG_ADDON")

    -- Target tracking
    combatFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

    -- Group changes
    combatFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    combatFrame:RegisterEvent("RAID_ROSTER_UPDATE")

    -- Combat state
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    -- Zone change (threat wipes on zone)
    combatFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Party/raid member combat log events
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_PARTY_DAMAGE")
    combatFrame:RegisterEvent("CHAT_MSG_COMBAT_PARTY_HITS")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE")
    combatFrame:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_PARTY_BUFF")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE")

    -- Incoming combat: mob attacking player / party. Used by v2.6.2
    -- multi-mob threat display to flag mobs that are engaged with
    -- the group but for which we have no unit token.
    combatFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS")
    combatFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
    combatFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS")
    combatFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_MISSES")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_PARTY_MISSES")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_VS_SELF_DAMAGE")
    combatFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_VS_PARTY_DAMAGE")

    combatFrame:SetScript("OnEvent", function()
        -- Vanilla 1.12: event name is in global 'event', args in global arg1..arg9
        -- IMPORTANT: we must NOT shadow 'event' with a local or parameter
        if event == "CHAT_MSG_ADDON" then
            addon.ThreatEngine:OnCombatEvent(event, arg2)
        elseif event == "CHAT_MSG_COMBAT_SELF_HITS"
            or event == "CHAT_MSG_SPELL_SELF_DAMAGE"
            or event == "CHAT_MSG_SPELL_SELF_BUFF"
            or event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS"
            or event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"
            or event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE"
            or event == "CHAT_MSG_COMBAT_HOSTILE_DEATH"
            or event == "CHAT_MSG_COMBAT_FRIENDLY_DEATH"
            or event == "CHAT_MSG_SPELL_FAILED_LOCALPLAYER" then
            addon.ThreatEngine:OnCombatEvent(event, arg1)
        -- Party/raid member combat log events
        elseif event == "CHAT_MSG_SPELL_PARTY_DAMAGE"
            or event == "CHAT_MSG_COMBAT_PARTY_HITS"
            or event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE"
            or event == "CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS"
            or event == "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE"
            or event == "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE" then
            addon.ThreatEngine:OnPartyDamageEvent(event, arg1)
        elseif event == "CHAT_MSG_SPELL_PARTY_BUFF"
            or event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF" then
            addon.ThreatEngine:OnPartyHealEvent(event, arg1)
        elseif event == "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS"
            or event == "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS" then
            addon.ThreatEngine:OnPartyPeriodicEvent(event, arg1)
        -- Incoming combat: mob attacking player / party (v2.6.2)
        elseif event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS"
            or event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES"
            or event == "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS"
            or event == "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES"
            or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE"
            or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_MISSES"
            or event == "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE"
            or event == "CHAT_MSG_SPELL_CREATURE_VS_PARTY_MISSES"
            or event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_VS_SELF_DAMAGE"
            or event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_VS_PARTY_DAMAGE" then
            addon.ThreatEngine:OnIncomingCombat(event, arg1)
        end

        -- Handle non-combat events
        if event == "PLAYER_TARGET_CHANGED" then
            local ok, name = pcall(UnitName, "target")
            if ok and name then
                currentTargetName = name
            else
                currentTargetName = nil
            end

        elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
            UpdatePartyClassCache()

        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Clear threat on zone change
            addon.ThreatEngine:ClearAll()

        elseif event == "PLAYER_REGEN_DISABLED" then
            -- Entered combat
            playerInCombat = true
            groupInCombat = true

        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Left combat - clear the player's own threat data.
            -- IMPORTANT: Do NOT clear all threat data if group members
            -- are still in combat. Their threat data must be preserved
            -- so that threat bars continue to show on mobs attacking them.
            playerInCombat = false
            UpdateGroupCombatState()
            if groupInCombat then
                -- Group members still in combat: only clear player's threat
                addon.ThreatEngine:ClearPlayerThreat()
            else
                -- No one in group is in combat: safe to clear all
                addon.ThreatEngine:ClearAll()
            end
        end
    end)

    self.combatFrame = combatFrame

    -- Register addon communication prefix
    local ok, _ = pcall(RegisterAddonMessagePrefix, COMM_PREFIX)

    -- Set up periodic updates
    self.updateFrame = CreateFrame("Frame", "RelationshipsThreatPlatesEngineUpdateFrame")
    self.updateFrame.elapsed = 0
    self.updateFrame:SetScript("OnUpdate", function()
        -- Vanilla 1.12: OnUpdate receives elapsed time in global arg1
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= 2.0 then
            this.elapsed = 0
            addon.ThreatEngine:OnPeriodicUpdate()
        end
    end)

    -- Hook CastSpellByName for Sunder Armor detection
    if playerClass == "warrior" then
        self:HookSunder()
    end

    addon:ui_print("Threat engine initialized for " .. playerClass)
end

-- ============================================================
-- Periodic update (every 2 seconds)
-- ============================================================

function addon.ThreatEngine:OnPeriodicUpdate()
    -- Recalculate threat modifier
    CalculateThreatModifier()

    -- Update party member class cache
    UpdatePartyClassCache()

    -- Update group combat state
    UpdateGroupCombatState()

    -- Broadcast threat to group
    BroadcastThreat()

    -- Decay old entries
    self:DecayOld()
end

-- ============================================================
-- Hook CastSpellByName and UseAction for Sunder Armor
-- (KTM-style: detect when player casts Sunder and add threat immediately)
-- ============================================================

function addon.ThreatEngine:HookSunder()
    -- Hook CastSpellByName
    if not self.originalCastSpellByName then
        self.originalCastSpellByName = CastSpellByName
        local origCast = self.originalCastSpellByName

        CastSpellByName = function(name, onSelf)
            if name and string.find(string.lower(name), "sunder") then
                SubmitSunderCast()
            end
            origCast(name, onSelf)
        end
    end

    -- Hook UseAction (for action bar buttons)
    if not self.originalUseAction then
        self.originalUseAction = UseAction
        local origUse = self.originalUseAction

        UseAction = function(slot, checkCursor, onSelf)
            -- Check if this is a Sunder Armor action
            local ok, texture = pcall(GetActionTexture, slot)
            if ok and texture == "Interface\\Icons\\Ability_Warrior_Sunder" then
                SubmitSunderCast()
            end
            origUse(slot, checkCursor, onSelf)
        end
    end
end

-- ============================================================
-- Get all threat data (for debugging/external use)
-- ============================================================

function addon.ThreatEngine:GetAllThreatData()
    return threatData
end

-- ============================================================
-- Check if ThreatEngine has any data for a mob
-- ============================================================

function addon.ThreatEngine:HasDataForTarget(mobName)
    if not mobName then return false end
    return threatData[mobName] ~= nil
end

-- ============================================================
-- Check if player is in combat (from ThreatEngine's perspective)
-- ============================================================

function addon.ThreatEngine:IsInCombat()
    return playerInCombat
end

-- ============================================================
-- Slash command: /tp threat - show threat table
-- ============================================================

function addon.ThreatEngine:DumpThreat()
    addon:ui_print("=== Threat Table ===")
    local count = 0
    for target, sources in pairs(threatData) do
        for source, value in pairs(sources) do
            if value > 0 then
                local pct, sit, pt, tt, hasGroup = self:GetThreatOnTarget(target)
                local groupTag = hasGroup and " [group]" or " [solo]"
                addon:ui_print(string.format("  %s -> %s: %.0f threat (%.0f%% of %.0f)%s",
                    source, target, value, pct, tt, groupTag))
                count = count + 1
            end
        end
    end
    if count == 0 then
        addon:ui_print("  (no threat data)")
    end
    addon:ui_print(string.format("Threat modifier: %.2f", threatModifier))
end
