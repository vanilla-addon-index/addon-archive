-- BulwarkFrame -- environment guard.
--
-- SuperWoW is a HARD requirement, not a nice-to-have. Two of the three things this addon does
-- have no honest fallback without it:
--
--   * identifying the buffer aura by SPELL ID (GetPlayerBuffID). The alternative is matching
--     on the texture path, which several unrelated auras share -- that produces a readout that
--     is confidently wrong rather than absent, which is worse.
--   * resetting the swing on UNIT_CASTEVENT (arg3 = "MAINHAND"/"OFFHAND"). Without it the only
--     route is parsing localised combat-log strings, which breaks on any client whose locale
--     or strings differ.
--
-- So there is deliberately no bypass switch. An addon that draws a plausible but wrong number
-- is worse than one that says it cannot run.
--
-- SUPERWOW_VERSION is set before any addon loads, so this can be evaluated at module scope --
-- unlike nampower and UnitXP, which are only detectable once in the world. Neither is used
-- here; if that changes, their detection has to move to a later event.

BulwarkFrameEnv = {}
local E = BulwarkFrameEnv

E.MESSAGE = "BulwarkFrame: SuperWoW is required and was not detected -- staying inactive. "
         .. "The buffer pool is read by spell id, which needs SuperWoW."

-- check(superwowVersion) -> ok(boolean), message(string or nil). PURE.
--
-- Presence is a plain nil check, matching what the other addons in this ecosystem do
-- (`SUPERWOW_VERSION ~= nil`). A stricter test would risk rejecting a valid SuperWoW that
-- reports its version in an unexpected shape.
function E.check(superwowVersion)
    if superwowVersion ~= nil then return true, nil end
    return false, E.MESSAGE
end
