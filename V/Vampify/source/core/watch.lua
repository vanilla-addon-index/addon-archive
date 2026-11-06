-- Vampify -- the watchdog. Pure Lua, no WoW API, offline-tested.
--
-- WHAT THIS CAN AND CANNOT DO. It finds contradictions in OUR OWN numbers. It cannot prove those
-- numbers are right -- nothing in this file compares against an independent source. A check that
-- held the displayed healing against the source percentages would be CIRCULAR, because the display
-- is computed from those percentages; such a check is always green and therefore worthless. So
-- these are invariants, not plausibility tests. The independent half is the HP reconciliation,
-- which lives elsewhere and is an ALARM, never a measurement (spec 2.1).
--
-- Call this on an interval or when the breakdown opens -- NOT per frame. It walks the breakdown
-- rows, which is cheap but not free, and the findings it produces are meant to be read by a human.

VampifyWatch = {}
local W = VampifyWatch

-- Repeated float addition does not land on the same value twice. The tolerance is relative so it
-- survives a long session, where the absolute drift grows with the total.
local function near(a, b)
    local m = a
    if m < 0 then m = -m end
    if m < 1 then m = 1 end
    local d = a - b
    if d < 0 then d = -d end
    return d <= 1e-6 * m
end

function W.new()
    return {
        -- Entry tables live here, not in the caller's buffer: the buffer is emptied on a clean run
        -- so a stale finding cannot be read back, but the tables themselves are kept and refilled.
        _pool = {},
        -- key -> run number in which the finding last appeared, two levels deep (id, then spell) so
        -- no string key has to be built per check. Bounded by invariant count times spellbook.
        _seen = {},
        run   = 0,
    }
end

local function emit(w, out, n, id, spell, a, b)
    local e = w._pool[n]
    if not e then e = {}; w._pool[n] = e end
    e.id, e.spell, e.a, e.b = id, spell, a, b

    local bucket = w._seen[id]
    if not bucket then bucket = {}; w._seen[id] = bucket end
    local k = spell or 0
    e.isNew = (bucket[k] ~= w.run - 1)
    bucket[k] = w.run

    out[n] = e
    return n
end

-- ctx fields, all optional unless noted:
--   rows, rowCount    the breakdown as built by VampifyAggregate.spellBreakdown
--   sessionHeal       the session total kept SEPARATELY from the rows -- that separateness is the
--                     entire point of I1; taking both from one source would test nothing
--   emitted           integers the SCT has shown; nil when it was not tracking (see I3)
--   accTotal          the float accumulator behind those integers
--   correctedShown    integers the retroactive AoE corrections removed from that accumulator,
--                     counted where they were applied (see I3)
--   fightEpoch        source-set epoch the current fight started in
--   sourceEpoch       source-set epoch now
--   aoeAvailable      whether AoE damping can be applied at all
--   multiTargetSeen   whether damage was dealt to more than one target
function W.check(w, ctx, out)
    w.run = w.run + 1
    local n = 0

    -- I1 -- the rows and the session total are kept by different code paths. If they disagree, one
    -- of them is wrong and there is no way to tell which from here.
    local rows, count = ctx.rows, ctx.rowCount or 0
    if rows and ctx.sessionHeal then
        local sum = 0
        for i = 1, count do sum = sum + (rows[i].heal or 0) end
        if not near(sum, ctx.sessionHeal) then
            n = emit(w, out, n + 1, "I1", nil, sum, ctx.sessionHeal)
        end
    end

    -- I2 -- overheal is a PART of the healing of that row. More than the whole, or less than
    -- nothing, means the split is broken, and a broken split shows one heal as two.
    if rows then
        for i = 1, count do
            local r = rows[i]
            local oh, h = r.overheal or 0, r.heal or 0
            if oh < 0 or (oh > h and not near(oh, h)) then
                n = emit(w, out, n + 1, "I2", r.spell, oh, h)
            end
        end
    end

    -- I3 -- every integer the SCT shows is a crossing of the accumulator, so their sum must BE the
    -- accumulator's integer part. Skipped when emitted is nil: with the SCT off nothing is emitted
    -- and the mismatch would be an artefact of the setting rather than a defect.
    --
    -- `correctedShown` is how many INTEGERS the retroactive AoE corrections took off the
    -- accumulator (the derivation taking back healing credited before a proc was known to be area
    -- damage). Those lower the accumulator AFTER their integers were already shown, so comparing
    -- against the raw total would flag every single proc as a defect. Adding them back compares
    -- like with like: what was shown against what the accumulator held WHEN it was shown.
    --
    -- It must be COUNTED where the correction is applied, not reconstructed here as
    -- floor(accTotal - sum of the float deltas): VampifyModel.add reads floor(acc.total) after the
    -- correction has already landed, so part of every correction is absorbed at an integer
    -- boundary. That reconstruction differed from the sum of the increments actually returned in
    -- roughly a fifth of single-correction sequences, and this comparison is exact equality (unlike
    -- I1/I2, which use near()) -- so it fired on healthy data. Counted, the identity is exact by
    -- construction.
    if ctx.emitted and ctx.accTotal then
        local shown = math.floor(ctx.accTotal) + (ctx.correctedShown or 0)
        if ctx.emitted ~= shown then
            n = emit(w, out, n + 1, "I3", nil, ctx.emitted, shown)
        end
    end

    -- I4 -- a fight that straddles a gear change mixes two different source sums into one figure.
    -- The numbers are not wrong per hit, but the fight's percentage is meaningless.
    if ctx.fightEpoch and ctx.sourceEpoch and ctx.fightEpoch ~= ctx.sourceEpoch then
        n = emit(w, out, n + 1, "I4", nil, ctx.fightEpoch, ctx.sourceEpoch)
    end

    -- I5 -- without AoE damping the total reads HIGH. This is the one direction in which this addon
    -- can overstate its own number, which is why it is called out rather than left to the flag.
    if ctx.multiTargetSeen and ctx.aoeAvailable == false then
        n = emit(w, out, n + 1, "I5", nil, nil, nil)
    end

    for i = n + 1, table.getn(out) do out[i] = nil end
    table.setn(out, n)
    return n
end

-- I6 -- checked at record time rather than over the breakdown, because by the time a hit is a row
-- the zero has already been averaged away. Per source the floor is 1, so a hit that dealt damage
-- with sources equipped CANNOT return zero -- UNLESS damage <= 1, where the server's proc does not
-- fire at all (core/model.lua's header, confirmed from source 2026-08-22). The threshold here has
-- to match that exactly, or a legitimate damage=1 zero-heal reads as "the formula was bypassed".
function W.checkHit(damage, nSources, healFloat)
    if not damage or damage <= 1 then return false end
    if not nSources or nSources <= 0 then return false end
    return (healFloat or 0) <= 0
end

-- ---- stage 2: the HP reconciliation ------------------------------------------------------------
--
-- The only independent evidence available: healing that Vampirism emits no event for still moves
-- the health bar. Per window,
--
--     implied = ΔHP + incoming damage − logged healing
--
-- and implied is compared against what we CREDITED for that window. This is systematically biased
-- -- see the rejection rules below for what is excluded, and note that overheal and any healing we
-- fail to observe both survive the filters. It is therefore an ALARM, never a measurement, and it
-- is never shown as a number (spec 2.1, 2.3).

-- Health this close to the maximum makes overheal invisible: the bar cannot rise, so a window there
-- reports "no healing arrived" no matter what happened.
local CAP_FRACTION = 0.98
-- Beyond this a window is not a window but an idle gap, and whatever drifted in during it has
-- nothing to do with the hit that opened it. The figure matches the one used when this balance was
-- run offline against recorded sessions.
local MAX_SECONDS = 3

function W.newBalance()
    return {
        sumImplied = 0, sumExpected = 0, n = 0,
        -- BUILT-IN CONTROL. Windows in which no damage came in need no incoming figure at all, so
        -- their balance holds regardless of whether the event's amount is gross or net -- a question
        -- we have NOT measured for the incoming direction. Windows that did take damage depend on
        -- that interpretation. Kept apart, the two branches check each other: if they disagree, the
        -- interpretation is wrong, not the addon's healing. An analysis without a control on a known
        -- case is worthless, and this project has already paid for that lesson twice.
        zeroImplied = 0, zeroExpected = 0, zeroN = 0,
        -- Counted, not just discarded: a run that rejects nearly everything has not measured
        -- anything, and the counts are what makes that visible instead of silently producing a
        -- confident verdict from four windows.
        rejected = { cap = 0, group = 0, idle = 0, noExpect = 0 },
    }
end

function W.resetBalance(b)
    b.sumImplied, b.sumExpected, b.n = 0, 0, 0
    b.zeroImplied, b.zeroExpected, b.zeroN = 0, 0, 0
    local r = b.rejected
    r.cap, r.group, r.idle, r.noExpect = 0, 0, 0, 0
end

function W.addWindow(b, hpPrev, hpNow, hpMax, incoming, logged, expected, seconds, inGroup)
    local r = b.rejected
    -- Group first: in a raid the foreign-healing error was measured at +29..49 %, which swamps
    -- everything else this could find.
    if inGroup then r.group = r.group + 1; return false end
    if hpMax and hpMax > 0 and hpPrev >= hpMax * CAP_FRACTION then r.cap = r.cap + 1; return false end
    if seconds and seconds > MAX_SECONDS then r.idle = r.idle + 1; return false end
    if not expected or expected <= 0 then r.noExpect = r.noExpect + 1; return false end

    -- Negative implied values are KEPT. Discarding them would bias the sum upward and hide exactly
    -- the defect this exists to catch.
    local inc = incoming or 0
    local implied = (hpNow - hpPrev) + inc - (logged or 0)
    b.sumImplied  = b.sumImplied + implied
    b.sumExpected = b.sumExpected + expected
    b.n = b.n + 1
    if inc == 0 then
        b.zeroImplied  = b.zeroImplied + implied
        b.zeroExpected = b.zeroExpected + expected
        b.zeroN = b.zeroN + 1
    end
    return true
end

-- The control. Both branches measure the same thing; only the damaged one depends on reading the
-- incoming amount correctly. A gap between them therefore indicts the READING, not the healing --
-- and it must be ruled out before any H1/H2 verdict is believed.
function W.crossCheck(b, minWindows, tol)
    local m = minWindows or 30
    local damagedN = b.n - b.zeroN
    if b.zeroN < m or damagedN < m then return nil end
    if b.zeroExpected <= 0 then return nil end
    local damagedExpected = b.sumExpected - b.zeroExpected
    if damagedExpected <= 0 then return nil end
    local rz = b.zeroImplied / b.zeroExpected
    local rd = (b.sumImplied - b.zeroImplied) / damagedExpected
    local d = rz - rd
    if d < 0 then d = -d end
    if d > (tol or 0.25) then
        return { id = "H3", ratioZero = rz, ratioDamaged = rd, windows = b.n }
    end
    return nil
end

-- Returns a finding or nil. Two directions, because they mean opposite things:
--   H1  we credit healing that never arrives -- a spell in the breakdown that does not trigger
--   H2  more arrives than we account for    -- a trigger we are not capturing at all
function W.alarm(b, minWindows, threshold)
    if b.n < (minWindows or 30) then return nil end
    if b.sumExpected <= 0 then return nil end
    local ratio = b.sumImplied / b.sumExpected
    local t = threshold or 0.25
    if ratio < 1 - t then
        return { id = "H1", ratio = ratio, windows = b.n }
    elseif ratio > 1 + t then
        return { id = "H2", ratio = ratio, windows = b.n }
    end
    return nil
end
