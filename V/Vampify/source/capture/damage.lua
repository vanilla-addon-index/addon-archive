-- Vampify -- the player's own outgoing damage, via nampower's packet-derived events.
--
-- Argument layouts are for nampower v4.6.2 (the KB documents v2.38, two majors back -- do not
-- take layouts from there). They are confirmed against RECORDED rows, not just documented:
--
--   ev=SPELL_DAMAGE_EVENT_SELF;args=0xF130001B89000CFF~0x0000000000000663~45500~70~0,0,0~0~0~2,64,0,0
--                                   target             caster(player)     spell  amt
--   ev=AUTO_ATTACK_SELF;args=0x0000000000000663~0xF130001B8200154B~323~2~1~1~0~0~0
--                            attacker(player)   target             amt      blk/abs/res
--
-- Note args 5 and 8 of the spell event are COMMA-JOINED STRINGS ("0,0,0"), not numbers -- never
-- assume a scalar. Arg5 (mitigation) IS parsed now, by G.mitigationOf/G.netSpell below (summed
-- blind, field order unverified). Arg8 (effectAura) is still not parsed by anything here.
--
-- The two damage events differ in shape AND in their hitInfo enum:
--
--   SPELL_DAMAGE_EVENT_SELF: 1 targetGuid 2 casterGuid 3 spellId 4 amount 5 mitigation
--                            6 hitInfo (crit 0x02) 7 school 8 effectAura
--   AUTO_ATTACK_SELF:        1 attackerGuid 2 targetGuid 3 totalDamage 4 hitInfo (crit 0x80)
--                            5 victimState 6 subDamageCount 7 blocked 8 absorbed 9 resisted
--   SPELL_GO_SELF:           1 itemId 2 spellId 3 casterGuid 4 targetGuid 5 castFlags
--                            6 numTargetsHit 7 numTargetsMissed 8 corpseOwnerGuid
--
-- DAMAGE_SHIELD_SELF is deliberately NOT registered: damage shields were measured NOT to trigger
-- Vampirism (Thorns 236 triggers, Thorium Shield Spike 27 -- zero healing from either). The
-- *_OTHER family is not registered either: totem and pet damage is believed not to trigger, and
-- those events fire for every foreign unit, which is a raid-load problem for no benefit.

VampifyDamage = {}
local G = VampifyDamage

local function num(v) return tonumber(v) or 0 end

function G.decodeSpell(a1, a2, a3, a4, a5, a6, a7, a8)
    return num(a4), a1, tonumber(a3), a2
end

function G.decodeAuto(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    return num(a3), a2, num(a7), num(a8), num(a9), a1
end

-- Crit extraction. The two events use DIFFERENT bits -- 0x02 on the spell event, 0x80 on the auto
-- attack -- and Lua 5.0 has no bitwise operators, so the bit is pulled out arithmetically.
--
-- Vampirism itself cannot crit. This is carried only so a return CAUSED by a crit can be shown as
-- one, the way Blizzard's combat text distinguishes them.
local function bitSet(v, bitValue)
    local n = tonumber(v)
    if not n then return false end
    return math.mod(math.floor(n / bitValue), 2) == 1
end

function G.isCritSpell(hitInfo) return bitSet(hitInfo, 2) end
function G.isCritMelee(hitInfo) return bitSet(hitInfo, 128) end

function G.netOf(amount, blocked, absorbed, resisted)
    local n = num(amount) - num(blocked) - num(absorbed) - num(resisted)
    if n < 0 then return 0 end
    return n
end

-- The SPELL_DAMAGE_EVENT_SELF mitigation field (arg5) in one place: a comma-joined STRING
-- ("0,0,0"), never scalars -- same wire shape capture/incoming.lua's I.mitigationOf already
-- parses for the OTHER-direction twin of this exact event (SPELL_DAMAGE_EVENT_OTHER). Duplicated
-- here rather than called there: damage.lua loads BEFORE incoming.lua (Vampify.toc), and the two
-- files are deliberately independent (this file's own header -- _SELF vs _OTHER, different
-- concern). The FORMAT is not a second guess, only the parser is a second copy of it -- summed
-- blind, not attributed to blocked/absorbed/resisted, because the field ORDER within the string
-- is unverified (same caveat I.mitigationOf carries); only the total is needed here.
function G.mitigationOf(s)
    if type(s) ~= "string" or s == "0,0,0" or s == "" then return 0 end
    local total, from = 0, 1
    while true do
        local p = string.find(s, ",", from, true)
        if not p then
            total = total + num(string.sub(s, from))
            break
        end
        total = total + num(string.sub(s, from, p - 1))
        from = p + 1
    end
    return total
end

-- Nets a SPELL_DAMAGE_EVENT_SELF amount the same way G.netOf nets an auto attack -- gated on the
-- SAME VampifyConst.FORMULA.damageBase setting (core/const.lua), which SETTLES the net-vs-gross
-- question (spec 4a, 2026-08-10: 7239 own hits during active Vampirism epochs, 9 decisive after
-- discarding full-health windows, 7 of 9 pointing at net) -- it is not a per-path guess, and this
-- function is what makes the SPELL path actually honor that settled answer instead of silently
-- assuming logged == net the way an earlier version of this file did (see the removed comment at
-- the SPELL_DAMAGE_EVENT_SELF branch below, and the report for why that assumption was wrong: it
-- predates spec 4a, which supersedes it for spells the same way it already governed auto attacks).
function G.netSpell(amount, mitigationStr)
    if VampifyConst.FORMULA.damageBase ~= "net" then return num(amount) end
    local n = num(amount) - G.mitigationOf(mitigationStr)
    if n < 0 then return 0 end
    return n
end

-- ---- WoW wiring ------------------------------------------------------------------------------

local listeners = {}
function G.onDamage(fn) table.insert(listeners, fn) end

-- SPELL_GO_SELF PRECEDES the damage events of a cast and carries arg6 (numTargetsHit) -- but that
-- field is NOT "how many distinct targets", it is a HIT COUNT. Measured in-game 2026-08-22: TWoW
-- Stormstrike (dual-wield, hits with both weapons) lands on exactly ONE target and still reports
-- numTargetsHit=2 for that single-target cast. An earlier version of this file trusted arg6>1
-- outright and classified Stormstrike as AoE, applying the 0.7 damping to a hit ground truth says
-- should get the full 1.0 (measured mitigation-adjusted factor: median 0.95-1.0 across n=4,
-- tightly clustered -- not the ~0.7 that classification would have produced). So arg6 is no longer
-- trusted to decide AoE by itself; SPELL_GO_SELF is now used ONLY for goSeen (below) and to note
-- multi-hit casts (see the OnEvent handler), and the actual AoE decision for every spell hit --
-- cast or not -- runs through G.deriveAoE, the distinct-target derivation described next. This
-- means a genuinely-AoE cast that happens to land on only one target this time is credited at 1.0
-- instead of a possible 0.7 -- see G.deriveAoE's own comment for that open question.
local goSeen = false
local damageSeen = false

-- ---- "did the PLAYER cast this, or did it proc?" (per-hit export field `cast`) ----------------
--
-- The same SPELL_GO_SELF that latches goSeen above is also the only observable in the client that
-- separates a CAST spell from a PROCCED one: it precedes the damage events of a cast and never
-- fires for an item/enchant proc (the sentence right above G.deriveAoE says exactly this, and it
-- is why deriveAoE had to exist at all). Hypothesis H2 -- that Vampirism is gated on the TRIGGER
-- PATH ("was this triggered by an aura") rather than on "is this an item proc" -- turns on that
-- distinction for one and the same spell id, so the offline analysis needs it recorded per hit
-- rather than inferred from timing (see core/perhit.lua's formatHitLine comment).
--
-- Keyed by spell id, and deliberately WITHOUT the eviction sweep this project requires of
-- per-GUID tables: the key space here is the player's own castable spell ids, which is bounded by
-- the spellbook and does not grow with time or with mob spawns. That is the exact property the
-- eviction rule exists to protect against, and it does not apply.
local lastGo = {}

-- Pure, so the predicate is testable without firing events: "was there a cast of this spell id
-- within `window` seconds before `now`". Default window 1.5s -- comfortably longer than the gap
-- between SPELL_GO_SELF and the damage events of the same cast (the GO precedes them within the
-- same or the next frame), and short enough that the PREVIOUS cast of the same spell (global
-- cooldown 1.5s at the very fastest) cannot be mistaken for this one.
local CAST_WINDOW = 1.5
G.CAST_WINDOW = CAST_WINDOW

function G.noteCast(spellId, t)
    if spellId then lastGo[spellId] = t end
end

function G.castSeenFor(spellId, now, window)
    if not spellId then return false end
    local t = lastGo[spellId]
    if not t or not now then return false end
    local dt = now - t
    return dt >= 0 and dt <= (window or CAST_WINDOW)
end

-- ---- AoE derivation from distinct targets, cast or not (spec 4.2, extended 2026-08-22) --------
--
-- Originally written as the fallback for weapon/item procs (Force Reactive Disc's damage shield
-- return has no cast, so SPELL_GO_SELF never fires for it -- without this the factor silently
-- stayed 1.0 and the credited healing read about 43% high, 1 / 0.7). It is now the ONLY source of
-- an AoE classification, cast or not -- see the comment above SPELL_GO_SELF's handling for why
-- numTargetsHit stopped being trusted on its own.
--
-- Rule, per spec 4.1: no spell-id list. The SAME spell id landing on TWO OR MORE DISTINCT target
-- GUIDs inside a short window is area damage.
--
-- KNOWN COARSENESS, CONFIRMED (2026-08-24, Sigil of Ancient Accord investigation): a spell whose
-- OWN definition mixes an AoE effect (100 Arcane to target + all within 10y) with a bonus effect
-- aimed only at its primary target (+300 Arcane) is not distinguishable from a plain AoE hit at
-- this module's granularity. A dump of 8.4M real combat events shows the primary
-- target's hit already arrives as ONE combined ~400 amount (two clusters: ~100 splash-only,
-- ~400 primary-combined -- no separate ~300-only cluster exists), matching the server's own
-- per-target damage accumulation (Spell::DoAllEffectOnTarget, Spell.cpp:1253, sums every effect
-- that targets a unit before the single proc/log call at Spell.cpp:1518). So
-- when 2+ distinct targets are hit, THIS module correctly flags the primary's combined hit as AoE
-- too (same spellId, same window) -- there is no server-visible signal here that would let it
-- damp only the spell's 100-portion and not its 300-portion; the two never arrive as separate
-- numbers. This is a genuine data-granularity limit, not a classification bug: whatever the
-- server itself does internally with a spell like this, this module sees exactly what the server
-- sends, one number per target, same as the server's own proc/log call already collapsed it to.
--
-- OPEN QUESTION, DELIBERATELY UNANSWERED: a genuinely multi-target spell that this time only
-- connects with ONE target (miss/resist/out of range on the others, or simply a single-target
-- pull) is now credited at the full 1.0 factor, never 0.7 -- there is no way to distinguish "this
-- spell is AoE but only hit one target" from "this spell was never AoE" from a single hit alone,
-- and guessing wrong in either direction was exactly the Stormstrike bug. Whether the SERVER pays
-- Vampirism at 0.7 or 1.0 in that specific case is UNMEASURED; do not assume either answer without
-- a dedicated single-target-hit-of-a-known-AoE-spell measurement.
--
-- This is necessarily RETROACTIVE: the first hit is already recorded (its non-AoE heal already
-- added to the float accumulator) by the time the second target proves the whole burst was AoE.
-- This module cannot fix that itself -- the accumulator (VampifyState.acc, VampifyState.fHeal/
-- sHeal/spHeal) is owned by core/model.lua + core/commands.lua, both out of bounds for this
-- change. So the qualifying hit instead fires G.onAoECorrection with the FIRST hit's own
-- (amount, targetGuid, spellId, isCrit), and a listener living in commands.lua is the piece that
-- still needs writing: it must redo that hit's heal with isAoE=true (VampifyModel.heal is pure and
-- already exposed, no model.lua change needed) and add the DIFFERENCE to VampifyState.acc.total,
-- .fHeal, .sHeal and .spHeal[spellId] -- see the report for the exact shape.
--
-- Window: 1.0s. A proc's damage to several targets is dispatched from one server-side event and
-- its packets arrive within a fraction of a second of each other -- tighter than a full cast's
-- cast-to-impact time, not looser -- so this is a safe upper bound for either case, cast or proc.
--
-- State is keyed by spellId, one scalar record per id (last target GUID, its amount/crit, and an
-- expiry) -- NOT a per-GUID table, so the eviction-sweep concern for per-GUID/_seen tables does
-- not apply here: this table is bounded by the spellbook plus a handful of item procs, the same
-- bound that already lets spHeal/spDmg/spOver (aggregate.lua) and the coalescing buckets
-- (commands.lua) skip a sweep. No table is created per event -- only key assignment on tables that
-- already exist -- so the zero-allocation-per-event budget holds.
local DERIVE_WINDOW = 1.0
-- Exported because core/commands.lua's correction listener has to decide whether the hit being
-- corrected is one it credited, and "credited within this window" is the same span. Two independent
-- copies of the figure would drift the day one of them is tuned.
G.DERIVE_WINDOW = DERIVE_WINDOW
local deriveGuid, deriveAmount, deriveCrit, deriveExpires, deriveConfirmed = {}, {}, {}, {}, {}

local correctionListeners = {}
-- fn(firstHitAmount, firstHitTargetGuid, spellId, firstHitWasCrit) -- fired once per window, on
-- the hit that supplies the SECOND distinct target GUID and thereby proves the first hit was AoE.
function G.onAoECorrection(fn) table.insert(correctionListeners, fn) end

local function emitCorrection(amount, targetGuid, spellId, isCrit)
    for i = 1, table.getn(correctionListeners) do
        correctionListeners[i](amount, targetGuid, spellId, isCrit)
    end
end

-- Pure derivation step for one spell-damage hit. Returns true if THIS hit should be treated as
-- AoE. Exposed as a standalone function (not buried in the OnEvent closure below) so it is
-- reachable from the offline Lua 5.0 test harness without a WoW API stub.
function G.deriveAoE(spellId, targetGuid, amount, isCrit, now)
    if not spellId then return false end   -- auto attacks carry no spell id, nothing to key on
    local expires = deriveExpires[spellId]
    if not expires or now > expires then
        -- No window in flight (or it lapsed): this hit becomes the new, so-far-unconfirmed first
        -- hit. Not AoE yet -- a single target proves nothing.
        deriveGuid[spellId], deriveAmount[spellId], deriveCrit[spellId] = targetGuid, amount, isCrit
        deriveExpires[spellId]   = now + DERIVE_WINDOW
        deriveConfirmed[spellId] = false
        return false
    end
    if deriveConfirmed[spellId] then
        -- Already proven AoE inside this window: every further hit of this spell id is AoE too,
        -- and the correction for the original hit already fired -- do not repeat it.
        deriveExpires[spellId] = now + DERIVE_WINDOW
        return true
    end
    if targetGuid ~= deriveGuid[spellId] then
        -- Second DISTINCT target: this proves both this hit and the remembered first hit were AoE.
        deriveConfirmed[spellId] = true
        deriveExpires[spellId]   = now + DERIVE_WINDOW
        emitCorrection(deriveAmount[spellId], deriveGuid[spellId], spellId, deriveCrit[spellId])
        return true
    end
    -- Same target again inside the window: still no evidence of AoE (could just be two ticks on
    -- one enemy), so only refresh the window and keep waiting.
    deriveExpires[spellId] = now + DERIVE_WINDOW
    return false
end

-- Running mitigation totals. Auto attacks report blocked/absorbed/resisted separately, so the
-- net-vs-gross question (spec 4.3.2) can be settled from a normal play session instead of a new
-- measurement campaign -- but only if the numbers are actually kept. They are cheap scalars, not
-- per-event tables, so this respects the zero-allocation budget.
local mitBlocked, mitAbsorbed, mitResisted, mitGross = 0, 0, 0, 0

-- spellId is passed through so consumers can group the hits of ONE cast (an AoE landing on five
-- targets is five events but one spell). nil for auto attacks, which have no cast to group by.
local function emit(amount, isAoE, targetGuid, spellId, isCrit)
    for i = 1, table.getn(listeners) do
        listeners[i](amount, isAoE, targetGuid, spellId, isCrit)
    end
end

if CreateFrame then
    local f = CreateFrame("Frame", "VampifyDamageFrame")
    f:RegisterEvent("SPELL_DAMAGE_EVENT_SELF")
    f:RegisterEvent("AUTO_ATTACK_SELF")
    f:RegisterEvent("SPELL_GO_SELF")
    f:SetScript("OnEvent", function()
        if event == "SPELL_GO_SELF" then
            -- goSeen is the only lasting effect of this event now -- see the comment above this
            -- section for why numTargetsHit (arg6) is no longer used to classify AoE directly. The
            -- actual decision for every hit of this cast still runs through G.deriveAoE below, the
            -- exact same distinct-target proof a no-cast proc already has to provide.
            goSeen = true
            -- arg2 is the cast's spell id (see the event's field list at the top of this file).
            -- Noting it is what lets a later damage event of the SAME id say "this one was cast",
            -- which is the `cast` field of the per-hit export -- see G.castSeenFor above.
            G.noteCast(arg2, GetTime())
        elseif event == "SPELL_DAMAGE_EVENT_SELF" then
            local amount, tgt, spellId, caster = G.decodeSpell(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
            -- Trust arg2 rather than the _SELF suffix, and never count a hit on ourselves.
            if caster and tgt and caster ~= tgt and amount > 0 then
                damageSeen = true
                local now = GetTime()
                local isCrit = G.isCritSpell(arg6)
                -- Net via G.netSpell (above) -- honors VampifyConst.FORMULA.damageBase = "net"
                -- (spec 4a) the same way the AUTO_ATTACK_SELF branch below already does. A hit
                -- that partially resisted (Arcane school, e.g. Ancient Accord's proc, is a
                -- measured case of this) must not credit its resisted portion as damage the
                -- server paid Vampirism on.
                local d = G.netSpell(amount, arg5)
                -- Distinct-target proof only, cast or not -- see the section comment above. Fed
                -- the NET amount: this is the figure the correction listener re-credits later,
                -- and it must match what emit() below hands the model.
                local isAoE = false
                if spellId then
                    isAoE = G.deriveAoE(spellId, tgt, d, isCrit, now)
                end
                mitGross = mitGross + amount
                emit(d, isAoE, tgt, spellId, isCrit)
            end
        elseif event == "AUTO_ATTACK_SELF" then
            local amount, tgt, blocked, absorbed, resisted, attacker =
                G.decodeAuto(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
            if attacker and tgt and attacker ~= tgt and amount > 0 then
                damageSeen = true
                mitGross    = mitGross + amount
                mitBlocked  = mitBlocked + blocked
                mitAbsorbed = mitAbsorbed + absorbed
                mitResisted = mitResisted + resisted
                local d = amount
                if VampifyConst.FORMULA.damageBase == "net" then
                    d = G.netOf(amount, blocked, absorbed, resisted)
                end
                emit(d, false, tgt, nil, G.isCritMelee(arg4))
            end
        end
    end)
end

-- True once a SPELL_GO_SELF has ever been seen. Until then, AoE damping cannot be applied and
-- the total may read HIGH -- the one direction in which this addon can overstate the number.
function G.aoeAvailable() return goSeen end

-- True once ANY own-damage event has arrived. nampower is a client module, not an addon, so there
-- is nothing to query with IsAddOnLoaded -- its absence can only be observed as silence. Silence
-- while the player is visibly fighting means the addon is inert, and spec 7 requires that it say
-- so rather than display a confident zero.
function G.damageSeen() return damageSeen end

-- Mitigation totals for settling net-vs-gross (spec 4.3.2) offline.
function G.mitigation() return mitGross, mitBlocked, mitAbsorbed, mitResisted end
