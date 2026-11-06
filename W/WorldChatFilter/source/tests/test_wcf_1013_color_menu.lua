-- Regression: Dusty Gold default and left-opening Color Presets (Vanilla UI).
-- Run from the repository root: lua tests/test_wcf_1013_color_menu.lua
table.getn = table.getn or function(t) return #t end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {AddMessage = function() end}
function CreateFrame(kind, name)
  local f = {name = name, scripts = {}}
  function f:GetName() return self.name end
  function f:RegisterEvent() end
  function f:SetScript(k, fn) self.scripts[k] = fn end
  function f:GetScript(k) return self.scripts[k] end
  function f:SetWidth() end
  function f:SetHeight() end
  function f:SetPoint(a, b, c, d, e)
    self.lastPoint = {a, b, c, d, e}
  end
  -- Vanilla CreateFrame exposes a globally named frame via _G[name].
  if name then _G[name] = f end
  return f
end
function getglobal(name) return _G[name] end
local list2 = CreateFrame("Frame", "DropDownList2")
_G.DropDownList2 = list2
local list3 = CreateFrame("Frame", "DropDownList3")
_G.DropDownList3 = list3
function list3:IsShown() return self.visible end
function list3:ClearAllPoints() self.lastPoint = nil end
function list3:GetBottom() return 120 end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info, level)
  local list = level == 2 and list2
  if not list then return end
  list.numButtons = (list.numButtons or 0) + 1
  local name = "DropDownList2Button" .. list.numButtons
  local btn = _G[name] or CreateFrame("Button", name)
  _G[name] = btn
  btn.value = info.value
  btn.hasArrow = info.hasArrow
  if not btn:GetScript("OnEnter") then
    btn:SetScript("OnEnter", function()
      if btn.hasArrow then list3.visible = true end
    end)
  end
  if info.hasArrow and not _G[name .. "ExpandArrow"] then
    local arrow = CreateFrame("Button", name .. "ExpandArrow")
    arrow:SetScript("OnEnter", function() list3.visible = true end)
    arrow:SetScript("OnClick", function() list3.visible = true end)
    _G[name .. "ExpandArrow"] = arrow
  end
end
function UIDropDownMenu_Initialize(frame, callback)
  frame.initialize = callback
end
function UIDropDownMenu_SetAnchor() end
WorldChatFilterDB = nil
dofile("Core.lua")
dofile("Color.lua")
dofile("UI.lua")
local WCF = WorldChatFilter
WCF.Initialize()
assert(WCF.db.worldColorPreset == "gold", "new characters should default to Dusty Gold")
assert(WCF.GetWorldColorPreset() == "gold", "color preset mismatch")
assert(WCF.GetWorldColorHex() == "#D1B77F", "wrong default gold RGB")
WCF.db.worldColorPreset = "sage"
WCF.Initialize()
assert(WCF.db.worldColorPreset == "sage", "existing user choice must survive init")
WCF.ResetWorldColorSelection()
assert(WCF.db.worldColorPreset == "gold", "reset should select Dusty Gold")
WCF.BuildUI()
local top = WorldChatFilterSettingsDropdown
assert(top and top.initialize, "UI menu not created")
UIDROPDOWNMENU_OPEN_MENU = top:GetName()
UIDROPDOWNMENU_MENU_VALUE = "worldColor"
list2.numButtons = 0
top.initialize(top, 2)
local presetButton = _G.DropDownList2Button3
assert(presetButton and presetButton.value == "colorPresets", "preset item not hooked")
presetButton:GetScript("OnEnter")()
assert(list3.lastPoint and list3.lastPoint[1] == "TOPRIGHT" and
       list3.lastPoint[2] == presetButton and list3.lastPoint[3] == "TOPLEFT",
       "submenu must open to the left")
list3.visible = false
_G.DropDownList2Button3ExpandArrow:GetScript("OnEnter")()
assert(list3.lastPoint and list3.lastPoint[1] == "TOPRIGHT", "arrow submenu must open left")
-- When reused by a different submenu, our hook must not interfere.
presetButton.value = "filters"
list3.lastPoint = nil
presetButton:GetScript("OnEnter")()
assert(list3.lastPoint == nil, "other dropdowns should be unaffected")
print("PASS Dusty Gold defaults, preserved settings, reset, left-open submenu and arrow")
