-- Vampify -- optional floating combat text, via Blizzard's own Blizzard_CombatText.
--
-- One of two SCT engines (the other is gui/sct.lua), selected by VampifyDB.sct.mode ==
-- "blizzard" and dispatched from core/commands.lua. Blizzard's engine owns its own position and
-- timing -- an addon cannot move or slow it down -- but CombatText_AddMessage takes an explicit
-- r,g,b, so the user's chosen SCT color (VampifyDB.sct.color) applies here too. That is the one
-- thing this engine and gui/sct.lua share.
--
-- There is no ambient FCT to hook: Blizzard_CombatText is LoadOnDemand ("## LoadOnDemand: 1") and
-- off by default (SHOW_COMBAT_TEXT is a saved variable, not a CVar), and no SCT/MSBT is installed.
-- So we write into Blizzard's FCT only if it is actually there, and are otherwise silent.
--
-- Signature verified against Blizzard 1.12.1 FrameXML, Blizzard_CombatText.lua:291 --
--   CombatText_AddMessage(message, scrollFunction, r, g, b, displayType, isStaggered)
-- The function does NOT itself honour SHOW_COMBAT_TEXT (that check lives in its event path), so we
-- honour it here. COMBAT_TEXT_SCROLL_FUNCTION is only assigned during that addon's setup and can
-- be nil even when the function exists, hence the fallback.
--
-- Increments of 0 are NOT emitted: the accumulator does not cross an integer on every hit. That is
-- also what keeps the number rate readable without a merge rule -- six sources cannot produce six
-- numbers per hit, because there is only ever one crossing.

VampifyFct = {}
local F = VampifyFct

function F.emit(increment, isCrit)
    if not increment or increment <= 0 then return end
    local cfg = VampifyConfig.get()
    if not cfg or not cfg.sct or not cfg.sct.enabled or cfg.sct.mode ~= "blizzard" then return end
    if not CombatText_AddMessage then return end
    if SHOW_COMBAT_TEXT ~= "1" then return end
    local scroll = COMBAT_TEXT_SCROLL_FUNCTION or CombatText_StandardScroll
    local col = cfg.sct.color or { r = 0.4, g = 0.9, b = 0.4 }
    CombatText_AddMessage("+"..increment, scroll, col.r, col.g, col.b)
end
