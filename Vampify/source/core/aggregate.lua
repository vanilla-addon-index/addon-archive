-- Vampify -- running totals. Pure Lua, no WoW API, offline-tested.
--
-- Allocation budget per recorded event is ZERO: AoE grinding produces 30-60 damage events per
-- second. The result tables are created once and refilled, never rebuilt.

VampifyAggregate = {}
local A = VampifyAggregate

-- Sentinel bucket for auto attacks, which carry no spell id. A number, so the breakdown's sort
-- never has to compare a number against a string.
A.MELEE = -1

-- Human-readable names for WoW 1.12's inventory equipment slot ids 1-19 -- the same numbering
-- GetInventoryItemLink("player", slot) and capture/detect.lua's D.scan use. Confirmed against the
-- cross-verified in-game against pfUI, 2026-08-24, rather than assumed from memory; slot 0 (Ammo)
-- is never scanned by D.scan (its loop starts at 1) so it is deliberately absent here.
local SLOT_NAME = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest", [6] = "Waist",
    [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Finger1", [12] = "Finger2",
    [13] = "Trinket1", [14] = "Trinket2", [15] = "Back", [16] = "Weapon", [17] = "Off Hand",
    [18] = "Ranged", [19] = "Tabard",
}

-- ---- per-spell, per-source healing breakdown -----------------------------------------------------
--
-- core/model.lua's M.healBreakdown keeps a hit's per-source integers instead of collapsing them
-- into one total; these two helpers turn one of those per-source rows into the STABLE identity and
-- the human label the breakdown below is keyed and displayed by.
--
-- IDENTITY CHOICE: SLOT + KIND, not the array index into sourcePercents (core/commands.lua rebuilds
-- that index-based list from scratch on every recompute(), so an EARLIER slot's gear change shifts
-- every LATER index -- the index is not a durable key across a session) and not the item id either
-- (capture/detect.lua's D.scan never reads one; the tooltip text is all it has). A slot is the one
-- thing that survives a gear swap in it, and it is exactly the question a re-gearing player is
-- asking ("is my weapon slot worth a Vampirism source"), not "which literal item". Kind is folded
-- in because a single slot can legitimately carry BOTH an item-text source and an enchant-text one
-- at once (D.scan's own loop does not stop at the first match per slot) -- without kind those two
-- would collide into one row and silently sum away which of the two actually mattered.
function A.sourceKey(slot, kind)
    return tostring(slot) .. ":" .. tostring(kind)
end

function A.sourceLabel(slot, pct)
    local name = SLOT_NAME[slot] or ("Slot " .. tostring(slot))
    return name .. " +" .. tostring(pct) .. "%"
end

function A.new()
    return {
        fHeal = 0, fDmg = 0, fStart = 0, fEnd = 0, fActive = false,
        sHeal = 0, sDmg = 0,
        _fight = {}, _session = {},
        -- Per-spell, per-source-identity breakdown (see A.sourceKey's own comment for the identity
        -- choice). spSrc[spellId][sourceKey] = { heal, floorHits, hits, label, pct } -- one nested
        -- table per spell id, exactly the same "bounded by the spellbook, not by mob GUIDs" shape
        -- spHeal etc. already have, with an extra dimension bounded by physical equipment slots
        -- (see A.recordSourceBreakdown's own comment on lifetime size). lfSrc is the LIFETIME twin,
        -- filled by the SAME call, same reasoning as lfHeal/spHeal below.
        spSrc = {}, lfSrc = {},
        -- Per-spell SESSION totals. Session scope on purpose: the bar's tooltip answers "what did
        -- which ability give me today", so a fight boundary must not wipe it. Keyed by spell id,
        -- therefore bounded by the spellbook rather than by mob GUIDs -- no eviction sweep needed,
        -- unlike a per-GUID table.
        --
        -- core/commands.lua may REPOINT these three fields (and the lf* ones below) at a
        -- SavedVariables sub-table after login/reload, so that every recordSpell call below is
        -- already a persisted write with no separate save step (spec 2026-08-10 sec 3). This file
        -- stays WoW-API-free either way -- it neither knows nor cares whether the table it is
        -- filling happens to be one WoW will write to disk.
        spHeal = {}, spDmg = {}, spOver = {}, _spOut = {},
        -- Per-spell SESSION hit counts, same key (spellId or A.MELEE), filled by the SAME
        -- recordSpell call as spHeal/spDmg/spOver above -- one landed hit, one increment, never a
        -- separate call, so this can never drift from the totals it counts hits for.
        spHits = {},
        -- Per-spell LIFETIME totals: the same shape, but never cleared by a fight or a session
        -- reset -- only by an explicit A.resetLifetime (wired to /vf reset lifetime|both). Filled
        -- by the SAME recordSpell call as the session tables above, so the two can never drift
        -- apart from missed or duplicated events -- there is exactly one place that writes either.
        lfHeal = {}, lfDmg = {}, lfOver = {},
        -- Lifetime twin of spHits, same reasoning as lfHeal/lfDmg/lfOver above.
        lfHits = {},
        -- ST/AoE split (2026-08-24, UI-redesign strand A; REDEFINED 2026-08-24 same day --
        -- see A.recordSpell's header for the two definitions in full). spHeal/spDmg/
        -- spHits above stay the GRAND total per spell, unchanged shape, unchanged meaning -- an
        -- existing SavedVariables character db must keep working without a migration. These four
        -- tables (names kept from the first cut of this feature -- the field names still say "Aoe",
        -- the MEANING no longer does, see below) track ONLY the OTHER-THAN-CURRENT-TARGET portion of
        -- that same total, filled by the SAME A.recordSpell call whenever it is told notOnTarget
        -- (see that function's own comment); the ST (current-target) portion is never stored, it is
        -- read back as spHeal[k] - spHealAoe[k] (A.spellSplit). spSplitSeen[k] is the flag that says
        -- whether ANY split-aware hit has landed for spell k yet -- false/absent means "this row may
        -- hold healing whose ST/other split was never recorded" (either pre-feature Altbestand, or
        -- pre-redefinition data discarded by core/config.lua's v<4 migration), not "confirmed zero
        -- off-target healing".
        spHealAoe = {}, spDmgAoe = {}, spHitsAoe = {}, spSplitSeen = {},
        -- Lifetime twins of the four above, same reasoning, same "filled by the same call" guarantee
        -- as lfHeal/lfDmg/lfHits already have relative to spHeal/spDmg/spHits.
        lfHealAoe = {}, lfDmgAoe = {}, lfHitsAoe = {}, lfSplitSeen = {},
        -- Per-spell "last fight" totals -- the THIRD scope (2026-08-25), prefix "la" matching sp=
        -- session/lf=lifetime. Same shapes, same "filled by the SAME recordSpell/
        -- recordSourceBreakdown call" guarantee as the other two, but a DIFFERENT lifecycle: cleared
        -- by A.startFight (a new fight beginning), NOT by a session/lifetime reset and NOT by a
        -- fight ENDING -- A.endFight only stops the clock, it never clears these, which is exactly
        -- what makes this scope read "the current fight if one is running, else the one that just
        -- ended" (see A.startFight's own comment for the chosen semantics and why). Deliberately
        -- NEVER aliased to a SavedVariables sub-table the way sp*/lf* are (core/commands.lua's
        -- wireSession) -- volatile by design, empty again after every /reload, same reasoning as
        -- the fight scalars (fHeal/fDmg) this scope extends to the per-spell/per-source level.
        laHeal = {}, laDmg = {}, laOver = {}, laHits = {}, laSrc = {},
        laHealAoe = {}, laDmgAoe = {}, laHitsAoe = {}, laSplitSeen = {},
    }
end

-- Overheal is a PART of a row's healing, so 0 <= overheal <= heal is the shape of a valid row --
-- exactly what the watchdog's I2 checks. Enforced here as well as checked there, because these
-- tables may be ALIASED to SavedVariables (see A.new): a broken row is not a transient display
-- artefact, it is written to disk and survives everything short of an explicit lifetime reset.
local function clampRow(heal, over, k)
    if heal[k] < 0 then heal[k] = 0 end
    if over[k] < 0 then over[k] = 0 end
    if over[k] > heal[k] then over[k] = heal[k] end
end

-- notOnTarget (sixth argument, OPTIONAL and nil-safe by construction -- every EXISTING caller and
-- every existing test still calls this with five arguments, and nil behaves exactly as it always
-- has: the grand totals below update, the ST/other split below does not).
--
-- DEFINITION, and its HISTORY, because this changed once already the same day (both 2026-08-24):
--   v1 (superseded): notOnTarget meant "capture/damage.lua's G.deriveAoE classified this hit as
--     area damage" (2+ distinct target GUIDs for the same spell id inside a short window).
--   v2 (THIS version, corrected definition): notOnTarget means "this hit's target was NOT the
--     player's CURRENT target at the moment it landed" -- a completely different axis. In-game
--     redefinition: the ST figure is "what I get from my current target for vampheal" (including
--     an AoE spell's share on that one target); the "AoE" figure is "everything else"; the two must
--     sum to the grand total exactly, with no third category.
-- The rename from "isAoE" to "notOnTarget" is deliberate, not cosmetic: keeping the old name after
-- redefining it would read as area-damage classification to the next person who has to touch this,
-- which is now false. WHERE the true/false actually comes from is core/commands.lua's onDamage
-- listener (see its own comment) -- it reads the CURRENT target's GUID at hit time (via
-- UnitExists("target"), the SAME SuperWoW pattern capture/incoming.lua already uses for the
-- player's own GUID) and compares it against the hit's own targetGuid; no target equipped means
-- notOnTarget=true unconditionally (explicit ruling: with no current target there is no ST
-- bucket for the healing to belong to). deriveAoE's classification (capture/damage.lua) is
-- UNCHANGED and UNRELATED -- it still drives the 0.7 AoE-damping FACTOR in the healing math
-- (VampifyModel/core/commands.lua's onDamage), a real, separate, still-measured server mechanic.
--
-- The retroactive AoE-DAMPING-reclassification correction (core/commands.lua, unrelated to this
-- split) deliberately still passes nothing here, for the same reason A.recordSourceBreakdown
-- already declines to participate in that correction (see its own comment): reversing a per-source
-- or per-split credit correctly would need to know which of the ORIGINAL hit's split it came from,
-- which that call site does not keep around, so guessing would risk crediting or debiting the wrong
-- bucket. Known, documented gap -- not a crash risk, and not silent: see A.spellSplit's own comment
-- on what this means for a hit whose AoE-damping factor was corrected after the fact.
function A.recordSpell(s, spellId, healFloat, damage, overheal, notOnTarget)
    local k = spellId or A.MELEE
    healFloat, damage, overheal = healFloat or 0, damage or 0, overheal or 0
    s.spHeal[k]  = (s.spHeal[k] or 0) + healFloat
    s.spDmg[k]   = (s.spDmg[k] or 0) + damage
    s.spOver[k]  = (s.spOver[k] or 0) + overheal
    s.lfHeal[k]  = (s.lfHeal[k] or 0) + healFloat
    s.lfDmg[k]   = (s.lfDmg[k] or 0) + damage
    s.lfOver[k]  = (s.lfOver[k] or 0) + overheal
    -- "last fight" scope: same call, same guards, third table set (see A.new's own comment on why
    -- this one is cleared on a DIFFERENT event than sp*/lf*).
    s.laHeal[k]  = (s.laHeal[k] or 0) + healFloat
    s.laDmg[k]   = (s.laDmg[k] or 0) + damage
    s.laOver[k]  = (s.laOver[k] or 0) + overheal
    -- A HIT is a landed event, not a retroactive adjustment. The AoE correction below (core/
    -- commands.lua) is routed through this SAME function with a NEGATIVE healFloat and zero damage,
    -- to claw back healing already credited to a hit counted the first time it landed -- it must
    -- not also inflate the hit count for something that was never a fresh landing. Guarded on the
    -- same sign the clamp below already keys off of.
    if healFloat >= 0 then
        s.spHits[k] = (s.spHits[k] or 0) + 1
        s.lfHits[k] = (s.lfHits[k] or 0) + 1
        s.laHits[k] = (s.laHits[k] or 0) + 1
    end
    -- Only a retroactive correction (core/commands.lua's AoE derivation) passes a negative heal,
    -- and only a subtraction can break the shape above -- so the clamp costs the recording path one
    -- comparison per hit and never runs on it. It is a floor under a caller mistake, not a
    -- substitute for the caller getting it right: the correction listener already refuses to touch
    -- a row it did not credit, and this is what keeps the NEXT way of dropping a hit from writing a
    -- broken row to disk in silence.
    if healFloat < 0 then
        clampRow(s.spHeal, s.spOver, k)
        clampRow(s.lfHeal, s.lfOver, k)
        clampRow(s.laHeal, s.laOver, k)
    end

    -- ST/other split: only for a FRESH landed hit (healFloat >= 0, same guard the hit counter above
    -- uses) whose target-relationship is actually known (notOnTarget ~= nil -- see this function's
    -- header comment for why the correction path is excluded). spSplitSeen/lfSplitSeen mark the
    -- spell as split-aware from this point on regardless of which side the hit landed on -- a spell
    -- seen only as ST so far still has a KNOWN (zero) off-target share, which is different from a row
    -- nothing has touched since the upgrade/redefinition (A.spellSplit's hasSplit reads exactly this
    -- flag).
    if notOnTarget ~= nil and healFloat >= 0 then
        s.spSplitSeen[k] = true
        s.lfSplitSeen[k] = true
        s.laSplitSeen[k] = true
        if notOnTarget then
            s.spHealAoe[k] = (s.spHealAoe[k] or 0) + healFloat
            s.spDmgAoe[k]  = (s.spDmgAoe[k]  or 0) + damage
            s.spHitsAoe[k] = (s.spHitsAoe[k] or 0) + 1
            s.lfHealAoe[k] = (s.lfHealAoe[k] or 0) + healFloat
            s.lfDmgAoe[k]  = (s.lfDmgAoe[k]  or 0) + damage
            s.lfHitsAoe[k] = (s.lfHitsAoe[k] or 0) + 1
            s.laHealAoe[k] = (s.laHealAoe[k] or 0) + healFloat
            s.laDmgAoe[k]  = (s.laDmgAoe[k]  or 0) + damage
            s.laHitsAoe[k] = (s.laHitsAoe[k] or 0) + 1
        end
    end
end

-- Accumulates one hit's per-source breakdown (core/model.lua's M.healBreakdown `out`, plus the
-- PARALLEL `meta` array core/commands.lua builds alongside sourcePercents -- meta[i] = { key =
-- A.sourceKey(...), label = A.sourceLabel(...) }, one entry per breakdown row) into both the
-- SESSION and LIFETIME per-spell-per-source tables. Same "one call feeds both sets" shape as
-- A.recordSpell above, for the same reason: the two can never drift apart from a missed or
-- duplicated event because there is exactly one place that writes either.
--
-- Deliberately does NOT participate in the retroactive AoE correction path (core/commands.lua's
-- negative-healFloat call to A.recordSpell): reversing a per-source credit correctly would need to
-- know which of that hit's ORIGINAL per-source integers to claw back, which the correction site
-- does not keep around (see core/commands.lua's own comment on aoeCorrectedShown for why only the
-- aggregate total is retained). Left as a known gap -- a reclassified AoE hit's per-source rows stay
-- at their originally-credited (slightly too high) figures even though the SPELL total is corrected
-- -- rather than risk crediting or debiting the wrong source.
function A.recordSourceBreakdown(s, spellId, breakdown, meta)
    local k = spellId or A.MELEE
    if not s.spSrc[k] then s.spSrc[k] = {} end
    if not s.lfSrc[k] then s.lfSrc[k] = {} end
    if not s.laSrc[k] then s.laSrc[k] = {} end
    local sp, lf, la = s.spSrc[k], s.lfSrc[k], s.laSrc[k]
    for i = 1, breakdown.n do
        local row, m = breakdown[i], meta[i]
        if row and m then
            local key = m.key
            local se = sp[key]
            if not se then se = { heal = 0, floorHits = 0, hits = 0 }; sp[key] = se end
            se.heal      = se.heal + row.heal
            se.hits      = se.hits + 1
            if row.floored then se.floorHits = se.floorHits + 1 end
            se.label, se.pct = m.label, row.pct

            local le = lf[key]
            if not le then le = { heal = 0, floorHits = 0, hits = 0 }; lf[key] = le end
            le.heal      = le.heal + row.heal
            le.hits      = le.hits + 1
            if row.floored then le.floorHits = le.floorHits + 1 end
            le.label, le.pct = m.label, row.pct

            -- "last fight" twin -- same accumulation, cleared by A.startFight instead of a
            -- session/lifetime reset (see A.new's comment).
            local ae = la[key]
            if not ae then ae = { heal = 0, floorHits = 0, hits = 0 }; la[key] = ae end
            ae.heal      = ae.heal + row.heal
            ae.hits      = ae.hits + 1
            if row.floored then ae.floorHits = ae.floorHits + 1 end
            ae.label, ae.pct = m.label, row.pct
        end
    end
end

-- Clears the per-spell SESSION tables in place -- never reassigns s.spHeal etc to a new {}. If
-- these fields alias a SavedVariables sub-table (see A.new's comment), replacing them would
-- silently orphan the persisted table instead of clearing it; nil-ing every key in place clears
-- whichever table is currently aliased, persisted or not, at no extra cost.
function A.resetSpells(s)
    for k in pairs(s.spHeal) do s.spHeal[k] = nil end
    for k in pairs(s.spDmg) do s.spDmg[k] = nil end
    for k in pairs(s.spOver) do s.spOver[k] = nil end
    for k in pairs(s.spHits) do s.spHits[k] = nil end
    for k in pairs(s.spSrc) do s.spSrc[k] = nil end
    -- ST/AoE split twins -- same in-place reasoning, so a reset does not leave a stale AoE-only
    -- figure sitting above a freshly-zeroed grand total (A.spellSplit's stHeal = total - aoe would
    -- go negative otherwise; see its own defensive clamp for the belt-and-braces backstop).
    for k in pairs(s.spHealAoe) do s.spHealAoe[k] = nil end
    for k in pairs(s.spDmgAoe) do s.spDmgAoe[k] = nil end
    for k in pairs(s.spHitsAoe) do s.spHitsAoe[k] = nil end
    for k in pairs(s.spSplitSeen) do s.spSplitSeen[k] = nil end
end

-- The lifetime twin of resetSpells above -- same in-place reasoning, wired to /vf reset
-- lifetime|both rather than to a session boundary.
function A.resetLifetime(s)
    for k in pairs(s.lfHeal) do s.lfHeal[k] = nil end
    for k in pairs(s.lfDmg) do s.lfDmg[k] = nil end
    for k in pairs(s.lfOver) do s.lfOver[k] = nil end
    for k in pairs(s.lfHits) do s.lfHits[k] = nil end
    for k in pairs(s.lfSrc) do s.lfSrc[k] = nil end
    for k in pairs(s.lfHealAoe) do s.lfHealAoe[k] = nil end
    for k in pairs(s.lfDmgAoe) do s.lfDmgAoe[k] = nil end
    for k in pairs(s.lfHitsAoe) do s.lfHitsAoe[k] = nil end
    for k in pairs(s.lfSplitSeen) do s.lfSplitSeen[k] = nil end
end

-- The "last fight" twin of resetSpells/resetLifetime above -- same in-place reasoning. Two callers:
-- A.startFight below (every new fight starting clears the PREVIOUS fight's last-scope breakdown --
-- the normal, automatic path) and A.resetScope("last") (an explicit user-requested clear, e.g. a
-- GUI reset button on the "last" tab -- less obviously useful than the session/lifetime ones since
-- the next fight will overwrite it anyway, but asked for by the brief and cheap to give).
function A.resetLast(s)
    for k in pairs(s.laHeal) do s.laHeal[k] = nil end
    for k in pairs(s.laDmg) do s.laDmg[k] = nil end
    for k in pairs(s.laOver) do s.laOver[k] = nil end
    for k in pairs(s.laHits) do s.laHits[k] = nil end
    for k in pairs(s.laSrc) do s.laSrc[k] = nil end
    for k in pairs(s.laHealAoe) do s.laHealAoe[k] = nil end
    for k in pairs(s.laDmgAoe) do s.laDmgAoe[k] = nil end
    for k in pairs(s.laHitsAoe) do s.laHitsAoe[k] = nil end
    for k in pairs(s.laSplitSeen) do s.laSplitSeen[k] = nil end
end

-- READ/RESET API for the GUI's per-scope reset buttons (2026-08-25 -- "reset button in session and
-- lifetime", plus "last" for symmetry with the other three scope-taking read APIs below). Reads the
-- GLOBAL VampifyState, no `s` parameter -- the same agreed shape A.spellSourceBreakdown/splitTotals/
-- spellSplit already use, since this is a GUI-facing entry point, not an internal helper threaded
-- explicitly like A.resetSpells/resetLifetime/resetLast above (which this dispatches to).
--
-- scope: "lifetime" or "last" reset exactly that one bucket via the matching helper above. Anything
-- else (including "session", nil, or an unrecognised string) resets the SESSION bucket -- the same
-- lenient "session is the safe default" convention core/commands.lua's VampifyResetSession already
-- uses for its own scope argument. "session" here means A.resetTotals (the fHeal/fDmg/sHeal/sDmg
-- scalars A.fight/A.session read) PLUS A.resetSpells (the per-spell session tables) -- exactly what
-- core/commands.lua's VampifyResetSession("session") already clears at the aggregate level; that
-- function now calls THIS one for the aggregate half instead of duplicating the two calls, so this
-- is the single source of truth for what a session reset clears down here (unchanged behaviour, see
-- its own comment for the WATCHDOG-side clearing this function correctly knows nothing about).
--
-- LIFETIME RESET IS DESTRUCTIVE: A.resetLifetime below erases every lfHeal/lfDmg/lfOver/lfHits/
-- lfSrc/lfHealAoe/lfDmgAoe/lfHitsAoe/lfSplitSeen row -- healing totals accumulated across every
-- session since the character existed, with NO undo (this file's tables are the only copy; nothing
-- upstream keeps a backup). This function does not ask for confirmation -- that is a GUI concern by
-- design (see this function's own module header) -- so whatever calls A.resetScope("lifetime") must
-- gate it behind its own confirmation.
function A.resetScope(scope)
    local s = VampifyState
    if not s then return end
    if scope == "lifetime" then
        A.resetLifetime(s)
    elseif scope == "last" then
        A.resetLast(s)
    else
        A.resetTotals(s)
        A.resetSpells(s)
    end
end

-- Clears the FIGHT and overall SESSION totals (fHeal/fDmg and sHeal/sDmg) in place -- the numbers
-- A.fight/A.session read. Split out from the old inline "make a brand new state" reset so /vf
-- reset can clear just this half without recreating VampifyState itself, which would sever any
-- SavedVariables wiring on the per-spell tables (see A.new's comment). Does not touch the per-spell
-- tables at all; pair with A.resetSpells and/or A.resetLifetime for those.
function A.resetTotals(s)
    s.fHeal, s.fDmg, s.fStart, s.fEnd, s.fActive = 0, 0, 0, 0, false
    s.sHeal, s.sDmg = 0, 0
end

local function sumTable(t)
    local sum = 0
    for _, v in pairs(t) do sum = sum + v end
    return sum
end

-- Reseeds the overall session totals (sHeal/sDmg) from whatever is currently in the per-spell
-- SESSION tables. Needed exactly once, right after core/commands.lua wires spHeal/spDmg to a
-- restored SavedVariables table on a reload: sHeal/sDmg themselves are plain numbers, so they
-- cannot be aliased the way the per-spell tables are, and without this call they would read 0
-- against a non-empty breakdown -- which is precisely the mismatch the tooltip's own cross-check
-- (gui/display.lua) exists to catch, so it would raise a false alarm on the very first hover after
-- every reload. A fresh login also calls this safely: summing freshly-cleared tables yields 0,
-- matching the state a brand new VampifyState would have had anyway.
function A.seedSessionTotals(s)
    s.sHeal = sumTable(s.spHeal)
    s.sDmg  = sumTable(s.spDmg)
end

-- Fills `out` with { spell, heal, damage, overheal }, biggest healer first. Reuses the entry
-- tables so an open tooltip refreshing on a timer does not allocate.
--
-- `scope`: falsy or "session" (default) reads the SESSION tables, `true` or "lifetime" reads the
-- LIFETIME ones (the original boolean contract is kept exactly -- every existing caller/test still
-- passes `true`/nil/omitted and gets the same table it always did), and "last" (2026-08-25, third
-- detail tab) reads the current-or-last-fight tables (see A.startFight's own comment for their
-- lifecycle). Three separate reads rather than a merged view, because the scopes answer different
-- questions (spec 2026-08-10 sec 3, extended 2026-08-25) and mixing them would answer none of them.
function A.spellBreakdown(s, out, scope)
    local heal, dmg, over, hits
    if scope == true or scope == "lifetime" then heal, dmg, over, hits = s.lfHeal, s.lfDmg, s.lfOver, s.lfHits
    elseif scope == "last" then heal, dmg, over, hits = s.laHeal, s.laDmg, s.laOver, s.laHits
    else heal, dmg, over, hits = s.spHeal, s.spDmg, s.spOver, s.spHits end
    local n = 0
    for k, h in pairs(heal) do
        n = n + 1
        local e = out[n]
        if not e then e = {}; out[n] = e end
        e.spell    = k
        e.heal     = h
        e.damage   = dmg[k] or 0
        e.overheal = over[k] or 0
        -- 0, not nil, for a row whose hit count is unknown -- e.g. Altbestand: a persisted spHeal/
        -- lfHeal row from before this counter existed has no matching key in spHits/lfHits at all.
        e.hits     = hits[k] or 0
    end
    for i = n + 1, table.getn(out) do out[i] = nil end
    table.setn(out, n)
    -- Insertion sort: n is the number of abilities used, i.e. single digits in practice, and it
    -- avoids handing table.sort a comparator that must stay consistent under equal values.
    for i = 2, n do
        local e, j = out[i], i - 1
        while j >= 1 and out[j].heal < e.heal do
            out[j + 1] = out[j]
            j = j - 1
        end
        out[j + 1] = e
    end
    return out
end

-- Internal scratch buffer for A.spellSourceBreakdown's floorShare pass below -- pooled at module
-- scope like core/model.lua's own shareBuf/floorBuf/remBuf/tookBuf, never rebuilt per call.
local _floorRowBuf = {}

-- READ API for the UI: which source contributed how much to ONE spell's healing, session or
-- lifetime. Deliberately reads the GLOBAL VampifyState rather than taking a state argument -- the
-- agreed shape for this call (unlike every other function above, which threads `s` explicitly) --
-- matching how gui/display.lua already reads VampifyState as a bare global in several places
-- (e.g. its V.format/V.shareOfTotal call sites) rather than receiving it as a parameter.
--
-- scope: "session" (default for anything other than exactly "lifetime" or "last"), "lifetime", or
-- "last" (2026-08-25, third detail tab -- current-or-last-fight, see A.startFight's own comment) --
-- same three-table split as A.spellBreakdown's own `scope` argument, just addressed by name here
-- since this is the public-facing read API rather than an internal one.
--
-- Fills `out` with, per source, descending by heal: { label, pct, heal, floorHits, share,
-- floorShare }, plus out.total/out.n/out.hits for the whole spell. `share` and `floorShare` are
-- largest-remainder-rounded percentages (summing to exactly 100.0 across the rows) computed by
-- core/model.lua's VampifyModel.shareOfTotal. This used to call gui/display.lua's
-- VampifyDisplay.shareOfTotal instead -- a core/ file reaching into gui/, which only worked because
-- the call resolved at runtime, after the whole addon had loaded, and broke the "core/ never
-- depends on gui/" invariant every other function in this file (and core/model.lua) respects.
-- Fixed (2026-08-24) by moving the rounding itself into core/model.lua, which already loads before
-- both this file and gui/display.lua in Vampify.toc; gui/display.lua now keeps
-- VampifyDisplay.shareOfTotal only as an alias for its own callers. The nil-guard below is kept
-- anyway (belt and braces, matching this file's style) for an offline test that might dofile
-- core/aggregate.lua without core/model.lua.
function A.spellSourceBreakdown(spellId, scope, out)
    out = out or {}
    local k = spellId or A.MELEE
    local s = VampifyState
    local bucket
    if s then
        local map
        if scope == "lifetime" then map = s.lfSrc
        elseif scope == "last" then map = s.laSrc
        else map = s.spSrc end
        bucket = map and map[k]
    end

    local n, total, hits = 0, 0, 0
    if bucket then
        for _, e in pairs(bucket) do
            n = n + 1
            local row = out[n]
            if not row then row = {}; out[n] = row end
            row.label     = e.label
            row.pct       = e.pct
            row.heal      = e.heal
            row.floorHits = e.floorHits
            total = total + e.heal
            hits  = hits + e.hits
        end
    end
    for i = n + 1, table.getn(out) do out[i] = nil end
    table.setn(out, n)

    -- Same insertion sort as A.spellBreakdown above, same reasoning (n is single digits in
    -- practice; table.sort needs a strictly-consistent comparator that equal heals would violate).
    for i = 2, n do
        local e, j = out[i], i - 1
        while j >= 1 and out[j].heal < e.heal do
            out[j + 1] = out[j]
            j = j - 1
        end
        out[j + 1] = e
    end

    if n > 0 and VampifyModel and VampifyModel.shareOfTotal then
        local shares = VampifyModel.shareOfTotal(out)
        for i = 1, n do out[i].share = shares[i] end

        for i = table.getn(_floorRowBuf), n + 1, -1 do _floorRowBuf[i] = nil end
        for i = 1, n do
            local fe = _floorRowBuf[i]
            if not fe then fe = {}; _floorRowBuf[i] = fe end
            fe.heal = out[i].floorHits
        end
        table.setn(_floorRowBuf, n)
        local floorShares = VampifyModel.shareOfTotal(_floorRowBuf)
        for i = 1, n do out[i].floorShare = floorShares[i] end
    else
        for i = 1, n do out[i].share, out[i].floorShare = 0, 0 end
    end

    out.total, out.n, out.hits = total, n, hits
    return out
end

-- SEMANTICS OF THE "last" SCOPE (2026-08-25, third detail tab alongside session/lifetime): the
-- per-spell/per-source breakdown a NEW fight starting here also resets (A.resetLast, la* tables in
-- A.new) follows the EXACT lifecycle fHeal/fDmg already have -- cleared HERE (fight start), left
-- alone by A.endFight (fight end just stops the clock). That means "last" shows the RUNNING fight
-- live once combat starts, freezes the instant it ends, and goes back to empty the moment the NEXT
-- fight begins -- chosen over the alternative (freeze the OLD fight until the new one fully ends,
-- so "last" never changes mid-combat) because a live view of the fight actually in progress is the
-- whole reason this tab is more useful than lifetime during a pull; the frozen-old-fight variant
-- would show a stale number for the entire new fight, which is worse than a number that is honestly
-- still moving. The GUI is expected to make this visible (e.g. a "live" indicator while
-- VampifyState.fActive is true) rather than implying a truly static "last completed fight" figure.
function A.startFight(s, now)
    s.fHeal, s.fDmg, s.fStart, s.fEnd, s.fActive = 0, 0, now or 0, now or 0, true
    A.resetLast(s)
end

function A.endFight(s, now)
    s.fEnd, s.fActive = now or s.fEnd, false
end

function A.record(s, increment, healFloat, damage, now)
    healFloat = healFloat or 0
    damage    = damage or 0
    s.fHeal = s.fHeal + healFloat
    s.sHeal = s.sHeal + healFloat
    s.fDmg  = s.fDmg + damage
    s.sDmg  = s.sDmg + damage
    if s.fActive and now then s.fEnd = now end
end

local function fill(out, heal, dmg, secs)
    out.heal    = heal
    out.damage  = dmg
    out.seconds = secs
    if secs and secs > 0 then out.hps = heal / secs else out.hps = 0 end
    if dmg > 0 then out.pct = heal / dmg else out.pct = 0 end
    return out
end

function A.fight(s)
    return fill(s._fight, s.fHeal, s.fDmg, s.fEnd - s.fStart)
end

function A.session(s)
    return fill(s._session, s.sHeal, s.sDmg, nil)
end

-- Sources are summed BEFORE rounding, so there is no per-source integer to attribute. The
-- breakdown is therefore proportional -- a share of the total, not a separately computed heal.
function A.shares(s, sources, out)
    local n, sum = table.getn(sources), 0
    for i = 1, n do sum = sum + (sources[i].percent or 0) end
    for i = 1, n do
        local e = out[i]
        if not e then e = {}; out[i] = e end
        e.percent = sources[i].percent
        if sum > 0 then e.share = sources[i].percent / sum else e.share = 0 end
        e.heal = s.fHeal * e.share
    end
    for i = n + 1, table.getn(out) do out[i] = nil end
    return out
end

-- ---- ST vs AoE ("other") split (2026-08-24, UI-redesign strand A) --------------------------------
--
-- DEFINITION (corrected same day, see A.recordSpell's header for the superseded v1): ST is
-- the Vamp healing that landed on hits against the player's CURRENT TARGET at the moment they
-- landed -- including an AoE spell's own share of a hit on that one target, no different from a
-- single-target spell's hit. AoE/"other" is everything else: hits on any OTHER unit, and (by
-- explicit ruling) the ENTIRE hit when the player has no current target at all, because there is
-- then no current target for a "ST" figure to describe. ST + AoE == the grand total, exactly, with
-- no third category -- this is enforced by construction below (ST is read back as total minus the
-- tracked "other" portion, never stored on its own), not by a separate check.
--
-- Two READ APIs the bar's badges need: the GRAND total's split (A.splitTotals) and a single spell's
-- split (A.spellSplit). Both, like A.spellSourceBreakdown above, deliberately read the GLOBAL
-- VampifyState rather than taking a state argument -- the same agreed shape, for the same reason
-- (matching gui/display.lua's existing bare-global reads of VampifyState).
--
-- Pooled 2-row buffer for VampifyModel.shareOfTotal's largest-remainder rounding, shared by both
-- functions below (never used across a re-entrant call -- Lua is single-threaded and each function
-- reads the returned shares into `out` immediately, before anything else could call in again).
local _shareRows2 = { {}, {} }

local function roundSplit(stAmount, aoeAmount, out)
    if (stAmount + aoeAmount) > 0 and VampifyModel and VampifyModel.shareOfTotal then
        _shareRows2[1].heal, _shareRows2[2].heal = stAmount, aoeAmount
        local shares = VampifyModel.shareOfTotal(_shareRows2)
        out.stPct, out.aoePct = shares[1], shares[2]
    else
        out.stPct, out.aoePct = 0, 0
    end
end

-- The GESAMT split. NOT read from the damage histogram (core/histogram.lua) any more -- that was
-- v1's approach, and it is now the WRONG data source: the histogram's normal/AoE dimension is
-- deriveAoE's area-damage CLASSIFICATION, which is a different axis from "which unit was hit" (see
-- A.recordSpell's header). The histogram still exists and is still correct for what it actually
-- backs (core/histogram.lua's G.totals/G.compare, the upgrade-preview feature, which legitimately
-- needs the AoE-damping classification) -- it is simply not this function's data source any more.
--
-- Instead this FOLDS the per-spell split A.recordSpell already maintains (spHeal/spHealAoe and their
-- lifetime twins) across every spell id, the same total-minus-tracked-other computation
-- A.spellSplit does per spell, just summed. This reuses the SAME bookkeeping recordSpell already
-- keeps (no second running total to keep in sync) and is bounded the same way A.spellBreakdown's own
-- full-table iteration already is -- by the spellbook, not by play history -- so a `pairs` walk here
-- costs nothing this addon does not already pay elsewhere. NOT on the zero-allocation hit path
-- (called from a UI refresh timer, like A.spellSourceBreakdown), so the walk is not a budget concern.
function A.splitTotals(scope, out)
    out = out or {}
    local s = VampifyState
    local heal, healOther
    if s then
        if scope == "lifetime" then heal, healOther = s.lfHeal, s.lfHealAoe
        elseif scope == "last" then heal, healOther = s.laHeal, s.laHealAoe
        else heal, healOther = s.spHeal, s.spHealAoe end
    end

    local total, other = 0, 0
    if heal then
        for k, v in pairs(heal) do
            total = total + v
            other = other + ((healOther and healOther[k]) or 0)
        end
    end
    out.aoeHeal = other
    out.stHeal  = total - other
    -- Same belt-and-braces floor as A.spellSplit's own (see its comment): the retroactive AoE-
    -- DAMPING correction can shrink a spell's grand total without touching its tracked "other"
    -- figure (A.recordSpell's documented gap), which could in principle pull the SUM below what is
    -- tracked as other for that one spell -- an edge case, not the normal path.
    if out.stHeal < 0 then out.stHeal = 0 end
    out.total = total
    roundSplit(out.stHeal, out.aoeHeal, out)
    return out
end

-- The PER-SPELL split. `out.hasSplit` is FALSE (not nil -- an explicit, checkable flag) exactly when
-- spell `spellId` has never been touched by the split-aware A.recordSpell path in this scope: either
-- it has no data at all, or every hit currently in spHeal/lfHeal for it predates split-tracking
-- (Altbestand from before this feature existed at all, OR data collected under the SUPERSEDED v1
-- definition and discarded by core/config.lua's v<4 migration -- see that file) and its true
-- ST/other split was never recorded under the CURRENT definition. The UI MUST NOT read
-- hasSplit==false as "confirmed zero AoE" -- that is exactly the false-blue bug the brief calls out.
--
-- SavedVariables migration, spelled out here because this is the function whose output an upgrading
-- player actually sees: spHeal[k]/lfHeal[k] (the GRAND total) is untouched by this feature and keeps
-- meaning exactly what it always meant. spHealAoe[k]/lfHealAoe[k] (the "other"-only sub-portion)
-- starts at 0/absent for EVERY existing character db (core/config.lua's fillDefaults recurses it in
-- as an empty table, and its v<4 migration step explicitly WIPES any data collected under the
-- superseded v1 definition) and is filled only from the moment a fresh split-aware hit lands for
-- that spell under the CURRENT definition. So a spell with only pre-tracking history reads
-- out.stHeal == the old total, out.aoeHeal == 0, and out.hasSplit == false -- "the old value counts
-- entirely as ST, because that's the only number we have, and it is NOT a measurement of zero
-- off-target healing". Once even one new hit lands for that spell, hasSplit flips true and the split
-- becomes reliable for everything credited from then on (the pre-existing lump, whichever side it
-- truly belonged to, stays folded into ST forever -- a known, documented approximation, same spirit
-- as A.recordSourceBreakdown's own "known gap" comment).
function A.spellSplit(spellId, scope, out)
    out = out or {}
    local k = spellId or A.MELEE
    local s = VampifyState
    local heal, dmg, hits, healAoe, dmgAoe, hitsAoe, seen

    if s then
        if scope == "lifetime" then
            heal, dmg, hits          = s.lfHeal, s.lfDmg, s.lfHits
            healAoe, dmgAoe, hitsAoe = s.lfHealAoe, s.lfDmgAoe, s.lfHitsAoe
            seen                     = s.lfSplitSeen
        elseif scope == "last" then
            heal, dmg, hits          = s.laHeal, s.laDmg, s.laHits
            healAoe, dmgAoe, hitsAoe = s.laHealAoe, s.laDmgAoe, s.laHitsAoe
            seen                     = s.laSplitSeen
        else
            heal, dmg, hits          = s.spHeal, s.spDmg, s.spHits
            healAoe, dmgAoe, hitsAoe = s.spHealAoe, s.spDmgAoe, s.spHitsAoe
            seen                     = s.spSplitSeen
        end
    end

    local totalHeal = (heal and heal[k]) or 0
    local totalDmg  = (dmg  and dmg[k])  or 0
    local totalHits = (hits and hits[k]) or 0

    out.aoeHeal = (healAoe and healAoe[k]) or 0
    out.aoeDmg  = (dmgAoe  and dmgAoe[k])  or 0
    out.aoeHits = (hitsAoe and hitsAoe[k]) or 0

    -- ST is READ BACK as total minus the tracked "other" portion, never stored separately -- see the
    -- function header for why. Clamped at 0 as a belt-and-braces floor only: the retroactive AoE-
    -- DAMPING correction (core/commands.lua) can shrink the grand total via a negative healFloat
    -- without knowing notOnTarget (A.recordSpell's documented gap), which could in principle pull
    -- totalHeal below an "other" figure recorded before the correction landed -- an edge case, not
    -- the normal path.
    out.stHeal = totalHeal - out.aoeHeal
    out.stDmg  = totalDmg  - out.aoeDmg
    out.stHits = totalHits - out.aoeHits
    if out.stHeal < 0 then out.stHeal = 0 end
    if out.stDmg  < 0 then out.stDmg  = 0 end
    if out.stHits < 0 then out.stHits = 0 end

    out.total    = totalHeal
    out.hasSplit = (seen and seen[k]) and true or false

    roundSplit(out.stHeal, out.aoeHeal, out)
    return out
end
