-- Vampify -- the Vampirism formula. Pure Lua, no WoW API, offline-tested.
--
-- SERVER-CONFIRMED FORMULA (2026-08-22, TurtleWoW patch_1172 source,
-- UnitAuraProcHandler.cpp:764-785). Every Vampirism source is its OWN aura. For a hit that
-- qualifies at all, EACH source heals independently:
--
--   heal_i(D) = max(1, trunc(pct_i * D / 100))     -- C++ UNSIGNED integer division = truncation
--   heal(D)   = sum_i heal_i(D)                      for D > 1
--             = 0                                    for D <= 1 (the proc does not fire at all)
--
-- No summed percentage, no single global floor, no float carry between hits -- the server computes
-- and applies this exactly, per hit, per source, as an integer, immediately. This SUPERSEDES the
-- v0.1/v0.2 model (heal = max(n, D * P * a), P the SUMMED percentage, one float accumulator with
-- "crossings" as the shown number), which was a plausible reconstruction from AGGREGATE
-- measurements (total percent, source count, in-game HP counter) made before the source was
-- available to read. The two happen to agree at damage values every source's share divides evenly
-- (the source ledger below is a case of exactly that), which is why the old model tracked live
-- percentages as well as it did -- but they diverge as soon as truncation bites unevenly across
-- sources, which is the common case.
--
-- WHY PER-SOURCE, NOT SUMMED-THEN-TRUNCATED: truncation is not linear. 40 damage with two sources
-- at 2% each floors to 1 + 1 = 2 (each source's own share, 0.8, truncates to 0, floors to 1); the
-- SUM first would compute trunc(4% * 40 / 100) = trunc(1.6) = 1, a different (and per the source,
-- wrong) answer. A summed percentage cannot be truncated back into individual per-source integers
-- after the fact -- the source list has to be truncated one at a time, in order, which is exactly
-- what M.healPerSources below does.
--
-- THE AoE FACTOR IS NOT IN THIS SOURCE EXCERPT. The 0.7 damping applied to AoE hits was measured
-- independently, TWICE, in-game (Flame Wave, 2026-08-07..09) -- UnitAuraProcHandler.cpp:764-785
-- says nothing about area damage at all. It is kept here as a configurable extra factor
-- (VampifyConst.FORMULA.aoeFactor, still 0.7 by default): the STRUCTURE (per-source, trunc, floor
-- 1, integer, immediate) is confirmed from the server source; the AoE VALUE is confirmed only from
-- measurement, and where in the pipeline it belongs is an OPEN QUESTION the source is silent on --
-- see M.healPerSources' own comment for exactly where this file puts it, and how a future
-- measurement (a single AoE-classified item-proc hit, where every source has a distinct percent so
-- the two possible orderings give different totals) could refute the assumption.

VampifyModel = {}
local M = VampifyModel

-- Per-source, per-hit integer heal -- the actual server computation, read straight off the source
-- excerpt above. `sources` is a plain array of PERCENT NUMBERS (e.g. {3, 2, 2, 2} for a 3% item
-- plus three 2% sources), NOT fractions and NOT pre-summed -- each entry is truncated
-- INDEPENDENTLY (see the file header for why a summed percentage cannot reproduce this).
--
-- `factor` is the AoE damping multiplier (VampifyConst.FORMULA.aoeFactor for an AoE-classified
-- hit, or nil/1 for a normal one) -- see the file header for the open question of whether this
-- belongs here at all. APPLIED TO DAMAGE, before max(1, trunc(...)): a damped AoE hit still floors
-- each source at 1 as a whole, rather than computing a fractional per-source result (e.g. 0.7) that
-- would need a SECOND rounding step the source excerpt gives no basis for. This is the pragmatic
-- choice, not a measured one -- the alternative (compute each source's un-damped heal_i, THEN
-- multiply by 0.7 and round) would floor every source's contribution to at least 1 point BEFORE
-- damping and could round it back up afterward, systematically healing MORE on AoE than this
-- ordering does. A hit where the two orderings disagree (mixed-percent sources, moderate damage)
-- and its measured healing is the only way to settle which one the server actually does.
-- Fills the REUSABLE buffer `out` with the per-source breakdown of one hit's heal: `out[i].pct`
-- (the source's own percent), `out[i].heal` (its truncated-and-floored integer share), `out[i].
-- floored` (true if its own share truncated to 0 and it therefore paid the floor of 1, not its
-- percentage), plus `out.total` (the summed heal, identical to M.healPerSources' return value) and
-- `out.n` (the source count). THIS is where the truncation loop actually lives now --
-- M.healPerSources and M.floorHeal below are both thin readers of this same computation, so the
-- arithmetic itself exists in exactly one place (see the file header for why a second copy would
-- drift the first time the formula moves).
--
-- Buffer-recycled like every other reused list in this addon (VampifyConst.resetList's own
-- comment): row tables at 1..n are kept and overwritten, not reallocated, and any trailing rows
-- from a longer previous call are nil'd out so a caller never sees stale data from a prior hit --
-- the classic bug this shape invites. `out` may be a fresh {} or a table already used for a
-- previous call; either way this function owns filling and trimming it completely.
function M.healBreakdown(damage, sources, factor, out)
    out = out or {}
    local n = (not damage or damage <= 1) and 0 or (sources and table.getn(sources) or 0)
    -- damage <= 1: the proc does not fire at all -- confirmed in the source; NOT the old model's
    -- "damage <= 0" cutoff, deliberately wider (see M.healPerSources' old comment, now here).
    if n > 0 then
        factor = factor or 1
        local effDamage = damage * factor
        local total = 0
        for i = 1, n do
            local e = out[i]
            if not e then e = {}; out[i] = e end
            local pct = sources[i] or 0
            -- math.floor == C's truncation here because every operand is non-negative (percent,
            -- damage and factor are all >= 0 by construction -- a negative damage value already
            -- zeroed n above, and callers never pass a negative percent or factor).
            local raw = math.floor(pct * effDamage / 100)
            local floored = raw < 1
            if floored then raw = 1 end
            e.pct, e.heal, e.floored = pct, raw, floored
            total = total + raw
        end
        out.total = total
    else
        out.total = 0
    end
    for i = table.getn(out), n + 1, -1 do out[i] = nil end
    table.setn(out, n)
    out.n = n
    return out
end

local _hpsBuf = {}   -- module-local, NOT the caller's buffer: M.healPerSources only ever needs the
                      -- total, so its own per-source rows are an internal scratch pad, reused
                      -- across every call (module scope, never rebuilt) rather than allocated per
                      -- hit -- the hot path (core/commands.lua's onDamage listener) calls this on
                      -- every damage event.
function M.healPerSources(damage, sources, factor)
    return M.healBreakdown(damage, sources, factor, _hpsBuf).total
end

-- How much of M.healPerSources' answer came from the FLOOR rather than from the percentage: the
-- number of sources whose own truncated share is 0, each of which therefore paid exactly 1. Same
-- arguments, same truncation, same AoE ordering as M.healPerSources above -- deliberately in this
-- file and directly beside it, because it is the SAME arithmetic read a second way, and a copy of
-- that truncation anywhere else would drift from it the first time the formula moves.
--
-- Why this number is worth having: the floor is what makes healing non-linear in damage. While a
-- source is on the floor it pays 1 whatever its percentage is, so on small hits MANY SMALL sources
-- beat FEW LARGE ones, and above the floor they are near enough interchangeable. Whether a player
-- is in that regime is not visible from any total -- only from this.
local _floorBuf = {}   -- module-local scratch pad, same reasoning as M.healPerSources' _hpsBuf
                        -- above -- kept SEPARATE from it so the two callers never clobber each
                        -- other's rows if used back-to-back for the same hit.
function M.floorHeal(damage, sources, factor)
    local out = M.healBreakdown(damage, sources, factor, _floorBuf)
    local floored = 0
    for i = 1, out.n do
        if out[i].floored then floored = floored + 1 end
    end
    return floored
end

-- Compatibility shape for a caller that only has the AGGREGATE figures (summed percent, source
-- count) rather than the real per-source list -- e.g. an old fixture, or a display line that only
-- ever wanted "total % from N sources" and never needed the individual percentages. It approximates
-- the source list as N EQUAL shares of sumPercent (pct_i = sumPercent*100/n for every i) and runs
-- the SAME M.healPerSources underneath, so it inherits the real truncation/floor behaviour rather
-- than reviving the old linear formula in parallel.
--
-- NOT EXACT for an uneven real source set (truncation is non-linear -- see the file header), and no
-- production call site uses this anymore: core/commands.lua's onDamage listener calls
-- M.healPerSources directly with the real per-source list (recompute()'s sourcePercents). Kept so
-- this call shape still means something sensible for whatever still uses it.
function M.heal(damage, sumPercent, nSources, isAoE)
    if not nSources or nSources <= 0 then return 0 end
    local factor = 1
    if isAoE then factor = VampifyConst.FORMULA.aoeFactor end
    local pct = (sumPercent or 0) * 100 / nSources
    local sources = {}
    for i = 1, nSources do sources[i] = pct end
    return M.healPerSources(damage, sources, factor)
end

-- ---- running totals -----------------------------------------------------------------------------
--
-- NO LONGER A FRACTIONAL CARRY. The v0.1/v0.2 model needed a float accumulator because its formula
-- produced a continuous (non-integer) heal per hit, and the measured display behaviour (two
-- identical 251-damage hits healing 18 then 17) only made sense as CROSSINGS of that running float,
-- never a per-hit rounding. The server formula above produces an EXACT INTEGER per hit, always --
-- there is no fractional remainder to carry, so there is no crossing to compute and no "shown
-- amount can differ from the raw heal" case anymore: M.add's two return values are now always
-- equal (see below).
--
-- acc.total is KEPT, not removed, but its job changed: it is now a plain running SUM of the exact
-- integers credited so far, not a fractional ledger. Two things still need it in that shape:
--   * core/commands.lua's retroactive AoE correction (a hit reclassified from non-AoE to AoE after
--     a second target proves the burst was area damage) needs to know the OLD credited amount so it
--     can un-credit it and credit the new one -- a running total is the natural place to apply that
--     delta, and VampifyAggregate's fight/session sums stay in lockstep with it by construction
--     (both are fed the identical per-hit integer, never a crossing).
--   * core/watch.lua's I3 invariant (the SCT-shown total must equal what the model actually
--     credited) still catches a real class of bug -- a hit recorded into the total but never
--     emitted, or a correction applied wrong -- even though it can no longer catch the OLD bug
--     class (floor-of-accumulator drifting from a sum of crossings), which cannot happen anymore
--     because there is no floor step left to drift.
function M.newAcc()
    return { total = 0 }
end

-- Returns (inc, heal): the integer to show for THIS hit, and the raw heal it was computed from --
-- the SAME number now, always. Kept as two return values (rather than collapsing to one) purely so
-- core/commands.lua's existing shape ("inc is what the SCT shows, healFloat is what effInc/overheal
-- get computed from") did not have to change, even though nothing can make them differ anymore.
function M.add(acc, damage, sources, isAoE)
    local factor = 1
    if isAoE then factor = VampifyConst.FORMULA.aoeFactor end
    local h = M.healPerSources(damage, sources, factor)
    acc.total = acc.total + h
    return h, h
end

function M.shown(acc)
    return math.floor(acc.total)
end

-- Split the integer shown for one hit into the part that landed and the part that overhealed. The
-- two MUST partition the integer: emitting the full amount and an overheal number beside it makes
-- one hit look like two, which is what happened at full health before this existed.
--
-- Still meaningful with an exact-integer heal: healFloat (this hit's whole heal) and effFloat (the
-- slice of it capped by the health deficit, from M.effective below) can still differ whenever the
-- hit landed at or near full health, so there is still a real split to compute -- it is no longer
-- "proportional because the shown integer is a crossing with no exact per-hit boundary" (there is
-- no crossing left), it is proportional because splitOverheal is not told exactly which of the n
-- per-source integers landed and which overhealed, only the hit's total and its capped total.
function M.splitOverheal(inc, healFloat, effFloat)
    inc = inc or 0
    if inc <= 0 then return 0, 0 end
    if not healFloat or healFloat <= 0 then return inc, 0 end
    local landed = effFloat or 0
    if landed < 0 then landed = 0 end
    if landed > healFloat then landed = healFloat end
    local ohShare = (healFloat - landed) / healFloat
    local oh = math.floor(inc * ohShare + 0.5)
    if oh > inc then oh = inc end
    return inc - oh, oh
end

function M.effective(healFloat, deficit)
    if not deficit or deficit <= 0 then return 0 end
    if healFloat > deficit then return deficit end
    return healFloat
end

-- ---- percentage rounding (shared by core/aggregate.lua and gui/display.lua) ---------------------
--
-- Moved here from gui/display.lua (2026-08-24): both a core/ module (core/aggregate.lua's
-- A.spellSourceBreakdown) and a gui/ module (gui/display.lua's V.buildDetailLines and its mouseover
-- breakdown) need this rounding, and core/ must not depend on gui/ -- core/aggregate.lua was calling
-- VampifyDisplay.shareOfTotal directly, which only worked because the call is resolved at runtime,
-- after the whole addon (including gui/) has loaded; it broke the moment core/ needed to load or be
-- tested without gui/. core/model.lua is the natural home: it already loads before both
-- core/aggregate.lua and gui/display.lua in Vampify.toc, and it takes no dependency of its own on
-- either. gui/display.lua keeps VampifyDisplay.shareOfTotal as a thin alias below, so nothing that
-- calls it by that name (including the offline tests) has to change.
--
-- Each ability's share of the TOTAL Vampirism healing, in percent, one decimal.
--
-- This replaced a column that divided each row's healing by its own damage. That answered "how
-- much does this ability give back" -- useful, but it left the column adding up to nothing, so
-- the table could not answer the question people actually ask it: where does my healing come
-- from. Both figures remain readable side by side anyway, since the row still prints its own
-- Damage and Vamp.
--
-- Largest-remainder rounding, not plain rounding: three equal abilities are 33.333% each, and
-- printing 33.3 three times gives a column that adds to 99.9. A percentage column a reader can
-- add up and land somewhere other than 100 invites exactly the doubt the table exists to remove.
-- The leftover tenths go to the rows with the largest remainders, which -- since the breakdown
-- arrives sorted by healing -- means the biggest contributors absorb them and the relative error
-- stays smallest.
--
-- Rows are read, never written. Returns a pooled buffer, same convention as gui/display.lua's
-- mergeByName: the breakdown repaints on mouseover, and a fresh table per repaint is avoidable
-- churn.
local shareBuf = {}
local floorBuf = {}
local remBuf   = {}
local tookBuf  = {}

function M.shareOfTotal(rows)
    local n = table.getn(rows)
    local i
    for i = table.getn(shareBuf), n + 1, -1 do shareBuf[i] = nil end

    local total = 0
    for i = 1, n do total = total + (rows[i].heal or 0) end
    if total <= 0 then
        for i = 1, n do shareBuf[i] = 0 end
        return shareBuf
    end

    -- Work in tenths of a percent so the whole distribution is integer arithmetic.
    local assigned = 0
    for i = 1, n do
        local raw = (rows[i].heal or 0) / total * 1000
        floorBuf[i] = math.floor(raw)
        remBuf[i]   = raw - floorBuf[i]
        tookBuf[i]  = false
        assigned    = assigned + floorBuf[i]
    end

    -- Hand out the leftover tenths, largest remainder first.
    -- Selection loop rather than table.sort -- a comparator that is not strict for equal values
    -- raises "invalid order function" in Lua 5.0, and equal remainders are the normal case here.
    --
    -- The heal > 0 test below is belt and braces and CANNOT currently fire: every row truncates
    -- away less than one tenth, so leftover is always smaller than the number of rows that had
    -- a fractional part -- and those are exactly the rows with healing. A zero-healing row has
    -- remainder 0 and sorts last, so the loop runs out of leftovers before reaching it. Kept
    -- because a future change to the rounding base would make the reasoning worth re-checking,
    -- not because it is load-bearing today. (Found by mutation: deleting it breaks no test.)
    local leftover = 1000 - assigned
    while leftover > 0 do
        local best, bestRem = nil, -1
        for i = 1, n do
            if not tookBuf[i] and (rows[i].heal or 0) > 0 and remBuf[i] > bestRem then
                best, bestRem = i, remBuf[i]
            end
        end
        if not best then break end          -- nothing eligible left; drop the rest
        floorBuf[best] = floorBuf[best] + 1
        tookBuf[best]  = true
        leftover       = leftover - 1
    end

    for i = 1, n do shareBuf[i] = floorBuf[i] / 10 end
    return shareBuf
end
