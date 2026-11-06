-- ButtonForge Classic - locale strings
-- Default language: English
local BF = BFClassic

BF.L = BF.L or {}
local L = BF.L

L.ADDON_LOADED = "loaded. Use the minimap button to open the configuration menu."
L.NO_BAR = "No bar found. Use /bf new."
L.SCALE_EXAMPLE = "Example: /bf scale 1.2"
L.SCALED_TO = "scaled to"
L.SLOTS = "slots"
L.SLOT_CLEARED = "Slot cleared."
L.NO_FREE_SLOT = "No free Vanilla action slot left. More bars require extended slot management."
L.PLACEACTION_MISSING = "PlaceAction() is not available on this client."
L.SLOT_OCCUPIED = "occupied"
L.TOGGLE_ALL_BG_HELP = "/bf bg all - toggle all bar backgrounds"

L.ADD_COLUMN = "Add Column"
L.REMOVE_COLUMN = "Remove Column"
L.ADD_ROW = "Add Row"
L.REMOVE_ROW = "Remove Row"
L.SCALE_UP = "Scale Up"
L.SCALE_DOWN = "Scale Down"
L.LOCK_UNLOCK_BAR = "Lock/Unlock Bar"
L.LOCK_BAR = "Lock Bar"
L.UNLOCK_BAR = "Unlock Bar"
L.DELETE_ACTIVE_BAR = "Delete Active Bar"
L.TOGGLE_BACKGROUND = "Toggle Background"
L.SHOW_BACKGROUND = "Show Background"
L.HIDE_BACKGROUND = "Hide Background"
L.SHOW_HIDE_EMPTY = "Show/Hide Empty Slots"
L.SHOW_EMPTY = "Show Empty Slots"
L.HIDE_EMPTY = "Hide Empty Slots"

L.TOGGLE_MOUSEOVER = "Toggle Mouseover Bar"
L.MOUSEOVER_ON = "Mouseover mode enabled."
L.MOUSEOVER_OFF = "Mouseover mode disabled."
L.MOUSEOVER_TIP_ON = "Mouseover: ON, hides after"
L.MOUSEOVER_TIP_OFF = "Mouseover: OFF (always visible)"
L.MOUSEOVER_DELAY_EXAMPLE = "Example: /bf mouseoverdelay 1.5"
L.MOUSEOVER_DELAY_SET = "Mouseover delay set to"

L.CONFIG_MODE_ON = "Configure Mode enabled. Bars can now be moved and configured."
L.CONFIG_MODE_OFF = "Play Mode enabled."

L.KEYBIND_MODE_ON = "Keybind Mode enabled. Bars are highlighted in green. Hover a ButtonForge button and press a key or mouse button."
L.KEYBIND_MODE_OFF = "Keybind Mode disabled."
L.KEYBIND_ASSIGNED = "Key assigned"
L.KEYBIND_CLEARED = "Key cleared."
L.KEYBIND_PRESS_KEY = "Press a key to bind this button."
L.KEYBIND_MOUSE_HINT = "Mouse buttons: click this button while in Keybind Mode."
L.KEYBIND_CLEAR_HINT = "Escape, Delete or Backspace: Clear binding"
L.KEYBIND_EXIT_HINT = "Shift + Left-click the minimap button or type /bf keybind to exit."
L.KEYBIND_NO_TARGET = "Hover a ButtonForge button first."
L.KEYBIND_MODE = "Keybind Mode"

function BF:T(key)
    if self.L and self.L[key] then
        return self.L[key]
    end
    return key
end
