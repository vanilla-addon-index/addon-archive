-- Vampify -- the distribution of triggering hits, and what an upgrade would be worth on it.
-- Pure Lua, no WoW API, offline-tested.
--
-- WHY A DISTRIBUTION AND NOT AN AGGREGATE. Every Vampirism source heals max(1, trunc(pct*D/100))
-- independently (core/model.lua), so healing is NOT linear in damage: while pct*D/100 < 1 -- that
-- is, while D < 100/pct -- a source pays its floor of 1 whatever its percentage is. Two runs with
-- identical total damage and identical hit counts therefore return different healing, and would
-- answer "what is one more source worth" differently, purely because their hits were sized
-- differently. No total, no average and no hit count can recover that. The hit-size distribution
-- can, and exactly.
--
-- What that buys the player: below the threshold, EVERY source pays 1, so many small percentages
-- beat few large ones; above it, they are near enough interchangeable (and truncation tips the
-- balance slightly the other way -- see G.compare). Which regime a given player is actually in is
-- invisible from any number the addon showed before this, and it is exactly the question "should I
-- take the +1% enchant or the bigger item" turns on.
--
-- ALLOCATION BUDGET PER RECORDED HIT IS ZERO, like core/aggregate.lua's: AoE grinding produces
-- 30-60 damage events per second, and G.add does one table-index increment and nothing else.

VampifyHistogram = {}
local G = VampifyHistogram

-- Exact bucketing up to and including this damage value; everything above is bundled into a count
-- and a sum. The bound exists because the key space is the damage space -- unbounded in principle,
-- and a table keyed by it would grow for the whole session.
--
-- WHY 1000. Exactness only MATTERS below the floor threshold 100/pct_min: above it every source is
-- paid its percentage, the non-linearity is gone, and a count plus a sum reproduce the healing to
-- within the truncated remainder. The smallest Vampirism source that exists is 1% (the bracer and
-- boot enchants, VampifyConst.SPELL_IDS), so the highest threshold any real source can have is
-- 100/1 = 100 for a normal hit, and 100/(1*0.7) ~= 143 for an AoE one (the damping is applied to
-- the damage, so it moves the threshold up with it). 1000 is seven times that -- the entire
-- floor-sensitive range is counted exactly, with room for a hypothetical source well under 1%, and
-- the exact table still cannot exceed 999 keys per side.
--
-- Above the cap the bundle is represented by its MEAN hit, weighted by the count. That is an
-- approximation, and the size of its error is worth being explicit about: truncation loses between
-- 0 and 1 HP per source per hit, so the bundle's healing can be off by up to (sources x overflow
-- hits) HP in total -- but it is off in the SAME way for the baseline and for every hypothetical
-- compared against it, so the DELTAS G.compare reports stay trustworthy even where the absolute
-- figure drifts. The floor cannot bind inside the bundle at all (every member is above the cap,
-- and so is their mean), which is the property the cap was chosen for.
G.CAP = 1000

function G.new()
    return { n = {}, a = {}, nOverN = 0, nOverSum = 0, aOverN = 0, aOverSum = 0 }
end

-- Empties in place -- never by replacing h.n/h.a with fresh tables. These may be ALIASED to a
-- VampifyCharDB sub-table (core/commands.lua's wireSession, the same wiring the per-spell tables
-- use), and reassigning them would orphan the persisted table instead of clearing it. Same
-- reasoning as VampifyAggregate.resetSpells.
function G.reset(h)
    if not h then return end
    for k in pairs(h.n) do h.n[k] = nil end
    for k in pairs(h.a) do h.a[k] = nil end
    h.nOverN, h.nOverSum, h.aOverN, h.aOverSum = 0, 0, 0, 0
end

-- Records one TRIGGERING hit. The caller owes this function the same filtering the healing path
-- applies (core/commands.lua drops VampifyConst.triggersVampirism == false before it gets here);
-- what this function refuses on its own account is the one condition that is a property of the
-- damage rather than of the spell: damage <= 1, on which the proc does not fire at all
-- (core/model.lua). Floored FIRST, so the key and the value the model is later handed for that key
-- are the same number.
function G.add(h, damage, isAoE)
    if not h or not damage then return end
    damage = math.floor(damage)
    if damage <= 1 then return end
    if damage > G.CAP then
        if isAoE then
            h.aOverN, h.aOverSum = (h.aOverN or 0) + 1, (h.aOverSum or 0) + damage
        else
            h.nOverN, h.nOverSum = (h.nOverN or 0) + 1, (h.nOverSum or 0) + damage
        end
        return
    end
    local t = isAoE and h.a or h.n
    t[damage] = (t[damage] or 0) + 1
end

-- Moves one already-recorded hit from the normal side to the AoE side. Exists for exactly one
-- caller: core/commands.lua's retroactive AoE correction, which learns from a SECOND target that a
-- burst already credited as normal damage was area damage after all. The healing is corrected
-- there; without this the histogram would keep saying "normal" about a hit that was paid as AoE,
-- and the baseline computed from it would no longer reproduce what was actually credited -- which
-- is the one property the whole comparison rests on.
--
-- Does nothing if no such hit is on the normal side: inventing one on the AoE side would be worse
-- than leaving the miscount, and the caller's own guards (it corrects only hits it credited) mean
-- the miss is a bug elsewhere, not something to paper over here.
function G.reclassify(h, damage)
    if not h or not damage then return end
    damage = math.floor(damage)
    if damage <= 1 then return end
    if damage > G.CAP then
        if not h.nOverN or h.nOverN <= 0 then return end
        h.nOverN, h.nOverSum = h.nOverN - 1, h.nOverSum - damage
        if h.nOverN <= 0 then h.nOverN, h.nOverSum = 0, 0 end
        h.aOverN, h.aOverSum = (h.aOverN or 0) + 1, (h.aOverSum or 0) + damage
        return
    end
    local c = h.n[damage]
    if not c or c <= 0 then return end
    -- nil, not 0: a zero-count key is a key, and keeping them would defeat the cap's whole point.
    if c <= 1 then h.n[damage] = nil else h.n[damage] = c - 1 end
    h.a[damage] = (h.a[damage] or 0) + 1
end

-- ---- reading the distribution back ---------------------------------------------------------------
--
-- Everything below computes healing through VampifyModel -- never with its own copy of the
-- formula. A second implementation of max(1, trunc(pct*D/100)) would drift from the real one the
-- first time the model moves, and the drift would be invisible: both halves would still look
-- self-consistent.

local function accumulate(t, overN, overSum, sources, factor, r)
    for d, c in pairs(t) do
        r.hits      = r.hits + c
        r.heal      = r.heal + VampifyModel.healPerSources(d, sources, factor) * c
        r.floorHeal = r.floorHeal + VampifyModel.floorHeal(d, sources, factor) * c
    end
    if overN and overN > 0 then
        -- The bundle, as its mean hit repeated overN times -- see G.CAP's comment for what that
        -- approximates and how far off it can be.
        local mean = overSum / overN
        r.hits      = r.hits + overN
        r.heal      = r.heal + VampifyModel.healPerSources(mean, sources, factor) * overN
        r.floorHeal = r.floorHeal + VampifyModel.floorHeal(mean, sources, factor) * overN
    end
end

-- Total healing the recorded hits would return for `sources` (an array of PERCENT NUMBERS, the
-- same shape core/commands.lua's sourcePercents has), and how much of it came from the FLOOR
-- rather than from the percentages. `out` is reused rather than rebuilt, like every other result
-- table in this addon.
function G.totals(h, sources, out)
    out = out or {}
    out.hits, out.heal, out.floorHeal, out.floorShare = 0, 0, 0, 0
    if not h then return out end
    accumulate(h.n, h.nOverN, h.nOverSum, sources, 1, out)
    accumulate(h.a, h.aOverN, h.aOverSum, sources, VampifyConst.FORMULA.aoeFactor, out)
    if out.heal > 0 then out.floorShare = out.floorHeal / out.heal end
    return out
end

-- NOTE (2026-08-24): this file USED to also carry G.splitHeal, an ST/AoE split read over h.n/h.a
-- (deriveAoE's area-damage classification). Removed the same day the UI's ST/AoE split was
-- redefined to be about WHICH UNIT WAS HIT (current target vs. everything else), not about area-damage
-- classification -- see core/aggregate.lua's A.recordSpell and A.splitTotals for the full history.
-- This histogram has no per-target dimension at all (it is keyed by damage VALUE, isAoE-classified
-- normal/AoE only), so it cannot answer the new question and G.splitHeal became dead code; deleted
-- rather than left unused. G.totals/G.compare below are UNCHANGED and still correct -- the
-- upgrade-preview feature they back legitimately needs the AoE-DAMPING classification this histogram
-- already keeps, which is a real, separate, still-measured server mechanic untouched by the split
-- redefinition.

-- Scratch buffers for the hypothetical source lists and their results. Module-level and reused:
-- G.compare runs from a slash command and an options-panel refresh, not from the damage path, but
-- there is no reason for it to allocate four tables every time either.
local addBuf, upBuf, swapBuf = {}, {}, {}
local addOut, upOut, swapOut = {}, {}, {}

local function copyInto(buf, sources)
    VampifyConst.resetList(buf)     -- table.insert's stale `n` would otherwise show through
    local n = sources and table.getn(sources) or 0
    for i = 1, n do table.insert(buf, sources[i]) end
    return buf
end

-- "What would an upgrade be worth?", answered on the hits that actually fell rather than on a
-- model example. Three hypotheticals against the current baseline:
--   (a) ONE MORE source at p percent      -- a spare enchant slot, another Vampirism piece
--   (c) the WEAKEST existing source SWAPPED for one p points stronger
--   (b) the STRONGEST existing source, p points stronger  -- informative bound, not a decision
--
-- (a) VERSUS (c) IS THE REAL DECISION, and it is what the verdict below is computed from. Every
-- Vampirism slot the player owns is already filled; a gear upgrade therefore does not ADD a
-- percentage, it REPLACES one. And the piece a player replaces is the one holding them back --
-- their WEAKEST Vampirism item, not their best. Both choices buy the same nominal point of total
-- percentage, and they are worth wildly different amounts of healing, because a weak source is
-- precisely the one still pinned to the floor: it is the only place where p points can be spent
-- and return nothing at all (1% -> 2% of a 30 damage hit is 0.3 -> 0.6, both truncate to 0, both
-- pay the same floor of 1), while a whole new source pays a full floor of 1 regardless.
--
-- (b) IS KEPT AS A BOUND, not as advice. Raising the STRONGEST source is the most generous thing
-- p points can do -- that source is the likeliest to be clear of the floor, so it converts the
-- points at full value. It answers "what is the very best a point could ever be worth here", which
-- is worth showing, but nobody can buy it: it would mean finding a higher rank of the item you are
-- already best served by. Reporting it as the alternative to (a) -- which this function did before
-- the swap case existed -- overstated what an upgrade is worth exactly when the hits are small,
-- which is the regime this whole feature exists to expose.
--
-- (a) and the raise cases are NOT symmetric even far above the floor, and the asymmetry runs the
-- other way there: trunc(x+y) >= trunc(x) + trunc(y), so folding p into an existing source lets
-- two truncated remainders combine into a whole point that two separate sources each throw away.
-- Hence the reversal the feature is really about -- (a) wins on small hits, the swap on big ones,
-- and far above the floor the two converge to within a rounding error of each other.
--
-- TIES for weakest raise exactly ONE source (strict > below): swapping one piece of gear is the
-- move being priced, and upgrading every tied source at once would price a shopping trip.
function G.compare(h, sources, p, out)
    out = out or {}
    p = p or 1
    G.totals(h, sources, out)      -- fills hits / heal / floorHeal / floorShare
    out.p = p

    copyInto(addBuf, sources)
    table.insert(addBuf, p)
    out.addHeal  = G.totals(h, addBuf, addOut).heal
    out.addDelta = out.addHeal - out.heal
    out.addPct   = 0
    if out.heal > 0 then out.addPct = out.addDelta / out.heal * 100 end

    local n = sources and table.getn(sources) or 0
    local best, bestI, worst, worstI
    for i = 1, n do
        if best  == nil or sources[i] >  best  then best,  bestI  = sources[i], i end
        -- Strict <, so the FIRST of several equally weak sources wins and only that one is
        -- swapped -- see the header. A <= here would keep sliding to the last tied index; still
        -- one source, but it would make which piece is named depend on list order for no reason.
        if worst == nil or sources[i] <  worst then worst, worstI = sources[i], i end
    end

    -- (c) the swap: the weakest source replaced by one p points stronger.
    out.swapIndex, out.swapFrom = worstI, worst
    if worstI then
        out.swapTo = worst + p
        copyInto(swapBuf, sources)
        swapBuf[worstI] = swapBuf[worstI] + p
        out.swapHeal  = G.totals(h, swapBuf, swapOut).heal
        out.swapDelta = out.swapHeal - out.heal
        out.swapPct   = 0
        if out.heal > 0 then out.swapPct = out.swapDelta / out.heal * 100 end
    else
        -- Nothing equipped: there is no piece to replace. Same reasoning as (b) below -- "+0" would
        -- read as a measurement rather than as "the question does not apply".
        out.swapTo, out.swapHeal, out.swapDelta, out.swapPct = nil, out.heal, 0, 0
    end

    out.upIndex, out.upFrom = bestI, best
    if bestI then
        out.upTo = best + p
        copyInto(upBuf, sources)
        upBuf[bestI] = upBuf[bestI] + p
        out.upHeal  = G.totals(h, upBuf, upOut).heal
        out.upDelta = out.upHeal - out.heal
        out.upPct   = 0
        if out.heal > 0 then out.upPct = out.upDelta / out.heal * 100 end
    else
        -- Nothing equipped: there is no source to make stronger, and saying "+0" would read as a
        -- measurement rather than as "the question does not apply".
        out.upTo, out.upHeal, out.upDelta, out.upPct = nil, out.heal, 0, 0
    end

    -- The verdict, decided between (a) and (c) ONLY -- the two things a player can actually go and
    -- do. (b) is deliberately not in the running: it is an upper bound on what a point is worth,
    -- not an option, and letting it win would answer a question nobody asked.
    if out.addDelta > out.swapDelta then
        out.winner, out.winnerBy = "add", out.addDelta - out.swapDelta
    elseif out.swapDelta > out.addDelta then
        out.winner, out.winnerBy = "swap", out.swapDelta - out.addDelta
    else
        out.winner, out.winnerBy = "tie", 0
    end
    return out
end
