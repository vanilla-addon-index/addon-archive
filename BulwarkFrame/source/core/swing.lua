-- BulwarkFrame -- swing-timer arithmetic (pure).
--
-- Why we build this instead of taking a dependency: the only Turtle-tested swing timer in
-- circulation (SP_SwingTimer) resets on LOCALISED combat-log strings, which is fragile, and it
-- has no extension points for the shaman specifics we care about -- Windfury extra attacks and
-- Flurry haste. Both of those break a generic timer, so a small own module is easier to keep
-- honest than a foreign addon to patch.
--
-- Two building blocks, both confirmed:
--   * swing DURATION  -- UnitAttackSpeed("player") returns (mainhand, offhand) in seconds.
--     Present in 1.12: Blizzard's own PaperDollFrame.lua:285 uses it.
--   * swing RESET     -- SuperWoW's UNIT_CASTEVENT with arg3 = "MAINHAND"/"OFFHAND". Language
--     independent and fires on misses too, unlike string parsing.
-- Neither is touched here; this file is arithmetic only, so it runs under plain Lua 5.0.3.

BulwarkFrameSwing = {}
local S = BulwarkFrameSwing

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- hasSwung(lastSwingAt): is there a swing to draw at all?
-- 0 doubles as the "never swung" sentinel, matching how the runtime layer will initialise it.
function S.hasSwung(lastSwingAt)
    return type(lastSwingAt) == "number" and lastSwingAt > 0
end

-- progress(lastSwingAt, now, speed) -> 0..1 through the current swing.
--
-- Saturates at 1 rather than wrapping: between swings (target dead, out of range, moving) the
-- marker should sit still at the end, not sweep round again as if an attack were imminent.
--
-- NOTE ON HASTE -- deliberately not decided here. When Flurry changes attack speed mid-swing it
-- is unverified whether the running swing rescales or the new speed only applies to the next
-- one. `speed` is therefore an argument: pass the value captured at swing start for the
-- "next swing only" reading, or the live value for the "rescales" reading.
-- LATENCY -- why it is an argument and not a constant.
--
-- The swing happens on the SERVER at T. The client only learns about it when the event
-- arrives, so the timestamp we record is already T + downstream. Everything derived from it is
-- therefore late by that much, and the two plausible corrections are NOT the same number:
--
--   * "show the true state"    -> shift by the downstream leg alone (~rtt/2)
--   * "show the action point"  -> shift by the FULL rtt, because a keypress still needs the
--                                 upstream leg to reach the server. The two legs ADD; they do
--                                 not cancel.
--
-- Which one is wanted is a display decision, so this module takes a plain `offset` in seconds
-- and applies it, rather than picking a model. Measured on this character: mean rtt 78 ms,
-- p90 82 ms, spikes to 253 ms -- i.e. 3% of a 2.6 s swing normally and 10% on a spike. Worth
-- offering, not worth hardcoding. (GetNetStats() supplies the rtt in ms, but only refreshes
-- every ~30 s in 1.12, so it tracks the baseline and not a spike.)
function S.progress(lastSwingAt, now, speed, offset)
    if type(lastSwingAt) ~= "number" or type(now) ~= "number" then return 0 end
    if type(speed) ~= "number" or speed <= 0 then return 0 end
    if type(offset) ~= "number" then offset = 0 end
    return clamp((now - lastSwingAt + offset) / speed, 0, 1)
end

-- remaining(lastSwingAt, now, speed, offset) -> seconds until the next swing, floored at 0.
function S.remaining(lastSwingAt, now, speed, offset)
    if type(lastSwingAt) ~= "number" or type(now) ~= "number" then return 0 end
    if type(speed) ~= "number" or speed <= 0 then return 0 end
    if type(offset) ~= "number" then offset = 0 end
    return clamp(speed - (now - lastSwingAt + offset), 0, speed)
end

-- latencySeconds(ms, share): turn GetNetStats' round-trip milliseconds into the offset above.
-- `share` selects the model: 0.5 for the downstream leg ("true state"), 1.0 for the full round
-- trip ("action point"). Defaults to 1.0 -- if a timer is used to decide WHEN TO PRESS, the
-- full trip is the honest number, and erring toward "press slightly early" is the harmless
-- direction: an ability queued a touch too soon still lands, one queued late misses the window.
function S.latencySeconds(ms, share)
    if type(ms) ~= "number" or ms <= 0 then return 0 end
    if type(share) ~= "number" then share = 1.0 end
    return (ms / 1000) * share
end
