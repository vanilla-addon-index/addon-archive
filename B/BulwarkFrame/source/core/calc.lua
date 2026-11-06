-- BulwarkFrame -- pure calculation core.
--
-- Deliberately free of any WoW API: everything here is arithmetic over three inputs the
-- display layer supplies (max health, the aura's stack count, the talent rank). That keeps
-- the error-prone part testable offline under real Lua 5.0.3, which is where the 1.12 traps
-- (#table, string methods via ':', string.match) actually bite.
--
-- The constants below are not folklore. All three were measured in-game on 2026-07-28:
--   * the pool is encoded as the stack count of aura 58127, capped at 100
--   * a full pool is 20% of max health  => 1 stack = MaxHP/500 (4588 HP -> 9.176 points)
--   * the absorb rate at talent rank 3 is 15.0% (median over 477 hits)
-- The rate is NOT hardcoded here: rank 1/2/3 map to 5/10/15%, and a set bonus can be layered
-- on top, because the T2.5 bonus ("+3% absorption") is not yet understood -- see rateForRank.

BulwarkFrameCalc = {}
local C = BulwarkFrameCalc

local MAX_STACKS = 100    -- the aura caps here; more is not possible

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function round(v) return math.floor(v + 0.5) end

-- ---- points ------------------------------------------------------------------------------

-- maxPool(maxHP): the full buffer in absorb points -- 20% of max health.
-- Written as maxHP/5 rather than maxHP*0.20 so it is a single exact division; the stack scale
-- below is derived FROM it, so the bar and the numbers can never drift apart.
function C.maxPool(maxHP)
    if type(maxHP) ~= "number" or maxHP <= 0 then return 0 end
    return maxHP / 5
end

-- stackPoints(maxHP): what one stack of aura 58127 is worth, in absorb points.
function C.stackPoints(maxHP)
    return C.maxPool(maxHP) / MAX_STACKS
end

-- poolPoints(stacks, maxHP): the current buffer in absorb points.
function C.poolPoints(stacks, maxHP)
    if type(stacks) ~= "number" then return 0 end
    return C.maxPool(maxHP) * (clamp(stacks, 0, MAX_STACKS) / MAX_STACKS)
end

function C.roundPoints(p)
    if type(p) ~= "number" then return 0 end
    return round(p)
end

-- ---- the headline number ------------------------------------------------------------------

-- threshold(points, rate): how large a single incoming hit would have to be for the buffer to
-- swallow `points` of it -- i.e. to be drained by that one hit.
--
-- UNIT NOTE, easy to misread: this is POST-MITIGATION damage. The buffer sits behind armor,
-- block, resist and Stoneskin (all verified 2026-07-28), so the number is directly comparable
-- to the damage figures in the combat log, NOT to a boss's raw swing.
--
-- Returns nil for a missing or zero rate (talent not learned) instead of dividing by zero: an
-- "inf" on screen is worse than an empty frame.
function C.threshold(points, rate)
    if type(rate) ~= "number" or rate <= 0 then return nil end
    if type(points) ~= "number" then return nil end
    return points / rate
end

-- ---- bar fill -----------------------------------------------------------------------------

-- barFraction(stacks): how full the pool bar is, 0..1.
--
-- This is exactly stacks/100 -- not a shortcut but the exact answer. The pair shown on the bar
-- is (pool/rate) over (maxPool/rate); both the rate and max health cancel out, so the fill
-- carries NO rounding error even though the two displayed numbers are rounded.
function C.barFraction(stacks)
    if type(stacks) ~= "number" then return 0 end
    return clamp(stacks, 0, MAX_STACKS) / MAX_STACKS
end

-- timeFraction(timeLeft, duration): how full the expiry bar is, 0..1.
-- A refresh can report slightly more than the nominal duration -> clamped, not trusted.
function C.timeFraction(timeLeft, duration)
    if type(timeLeft) ~= "number" or type(duration) ~= "number" or duration <= 0 then return 0 end
    return clamp(timeLeft / duration, 0, 1)
end

-- ---- colours ------------------------------------------------------------------------------
-- One flat colour for the whole filled area. No gradient inside a bar.

C.POOL_THRESHOLDS = { red = 0.30, yellow = 0.70 }   -- fractions
C.TIME_THRESHOLDS = { red = 2.0,  yellow = 5.0 }    -- seconds remaining

C.COLORS = {
    red    = { 0.80, 0.15, 0.15 },
    yellow = { 0.85, 0.75, 0.20 },
    green  = { 0.25, 0.75, 0.30 },
}

function C.poolColorName(fraction, cfg)
    cfg = cfg or C.POOL_THRESHOLDS
    if type(fraction) ~= "number" then return "red" end
    if fraction <= (cfg.red or 0.30) then return "red" end
    if fraction <= (cfg.yellow or 0.70) then return "yellow" end
    return "green"
end

-- Time buckets run the other way round: MORE seconds left is better.
function C.timeColorName(timeLeft, cfg)
    cfg = cfg or C.TIME_THRESHOLDS
    if type(timeLeft) ~= "number" then return "red" end
    if timeLeft < (cfg.red or 2.0) then return "red" end
    if timeLeft <= (cfg.yellow or 5.0) then return "yellow" end
    return "green"
end

-- colorRGB(name): never returns nil -- an unknown name yields a visible neutral colour rather
-- than a Lua error deep inside a SetStatusBarColor call.
function C.colorRGB(name)
    local c = C.COLORS[name or ""]
    if not c then return 0.7, 0.7, 0.7 end
    return c[1], c[2], c[3]
end

-- ---- formatting ---------------------------------------------------------------------------

-- fmtThresholdPair(curPoints, maxPoints, rate) -> "2820 / 6120"
-- Rounds the RESULT, not the inputs. Rounding the point values first shifts the number by a
-- few points; the two orders are not interchangeable (pinned by a test).
function C.fmtThresholdPair(curPoints, maxPoints, rate)
    local a, b = C.threshold(curPoints, rate), C.threshold(maxPoints, rate)
    if not a or not b then return "--" end
    return round(a) .. " / " .. round(b)
end

-- fmtShieldPair(curPoints, maxPoints) -> "459 / 918"
--
-- The other reading of the same buffer. fmtThresholdPair answers "how large may a single hit be
-- before this is drained"; this one answers "how much damage does it still absorb". They differ by
-- the absorb rate -- at rank 3 by a factor of about seven -- so which one is on screen has to be a
-- deliberate choice, not an accident.
--
-- Note it takes no rate: the shield value is the pool itself. That also makes it the honest
-- fallback when the talent rank is unknown, where fmtThresholdPair can only return "--".
function C.fmtShieldPair(curPoints, maxPoints)
    if type(curPoints) ~= "number" or type(maxPoints) ~= "number" then return "--" end
    return round(curPoints) .. " / " .. round(maxPoints)
end

function C.fmtTime(t)
    if type(t) ~= "number" or t < 0 then t = 0 end
    return string.format("%.1f s", t)
end

-- ---- absorb rate --------------------------------------------------------------------------

C.RANK_RATE = { [0] = 0, [1] = 0.05, [2] = 0.10, [3] = 0.15 }

-- rateForRank(rank, addBonus, multBonus): the active absorb rate.
--
-- An unknown rank yields 0, never a silent 15%: a threshold computed from a guessed rate is
-- worse than no threshold, because it looks authoritative.
--
-- The T2.5 set bonus is documented as "+3% absorption" and it is NOT established whether that
-- means 15 -> 18 (additive) or 15 * 1.03 (multiplicative). Both readings are expressible and
-- neither is assumed; the caller decides once measurement settles it.
function C.rateForRank(rank, addBonus, multBonus)
    local base = C.RANK_RATE[rank or -1]
    -- `<= 0` and not just `not base`: rank 0 maps to a rate of 0, and 0 is truthy in Lua, so a
    -- bare nil check would let an additive set bonus resurrect a rate for a talent the character
    -- has not learned -- exactly the confidently wrong number this guard exists to prevent.
    if not base or base <= 0 then return 0 end
    if type(addBonus) == "number" then base = base + addBonus end
    if type(multBonus) == "number" then base = base * multBonus end
    return base
end
