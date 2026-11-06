-- pandaUI :: modules/petbarcustom.lua
--
-- Opt-in modern pet bar, recovered from the pre-df1f652 implementation.
-- modules/petbar.lua owns mode selection and calls this helper only when the
-- saved mode is explicitly "custom". Loading this file alone does nothing.
--
-- The client protects CastPetAction. Do not restore the old silent failing
-- call or attempt to proxy the native click handler. Documented unprotected
-- commands and autocast/drag operations remain available; spell clicks warn.
-- Geometry follows the archived bar. Cooldowns use the current shared radial
-- wipe; cooldown.model_swipe_not_rendered rules out the old Model template.

local U = PandaUI
local M = U.media
local frame, cfg
local buttons = {}
local shown = false
local gridActive = false
local SLOT_COUNT = 10
local ICON_INSET = 2
local api = {}

-- documentation.json / Pet: fixed command and stance slots. Spell slots 4-7
-- have no unprotected casting equivalent.
local COMMANDS = {
  [1] = "PetAttack", [2] = "PetFollow", [3] = "PetWait",
  [8] = "PetAggressiveMode", [9] = "PetDefensiveMode", [10] = "PetPassiveMode",
}

local function Resolve(name)
  if api[name] == nil then
    local fn = U.G(name)
    api[name] = type(fn) == "function" and fn or false
  end
  return api[name] or nil
end

local function Call(name, index)
  local fn = Resolve(name)
  if not fn then return nil end
  local ok, a, b, c = pcall(fn, index)
  if ok then return a, b, c end
end

local function Truth(value)
  return value ~= nil and value ~= false and value ~= 0
end

local function PetInfo(index)
  local fn = Resolve("GetPetActionInfo")
  if not fn then return nil end
  local ok, name, subtext, texture, token, active, castable, autocast = pcall(fn, index)
  if ok then return name, subtext, texture, token, active, castable, autocast end
end

local function HasPetBar()
  if Resolve("PetHasActionBar") then return Truth(Call("PetHasActionBar")) end
  if Resolve("HasPetUI") then return Truth(Call("HasPetUI")) end
  return Truth(Call("UnitExists", "pet"))
end

local function Clamp(value, fallback, minimum, maximum)
  value = tonumber(value) or fallback
  return math.max(minimum, math.min(maximum, math.floor(value + 0.5)))
end

local function ApplyState(button)
  local color = M.color.border
  if button.puiUsable then
    if button.puiPressed or button.puiActive or
       (button.puiAutocast and cfg.showAutocast) then
      color = M.color.accent
    elseif button.puiHover then
      color = M.color.accentDim
    end
  end
  U.SetBorderColor(button, M.Unpack(color))
  U.SetBackgroundColor(button, M.Unpack(button.puiPressed and
                       button.puiUsable and M.color.accentFill or M.color.background))
end

local function RunAction(name, index)
  local fn = Resolve(name)
  local ok = false
  if fn then
    if index then ok = pcall(fn, index) else ok = pcall(fn) end
  end
  if not ok then U.Print(U.L("PETBAR_ACTION_UNAVAILABLE")) end
end

local function CursorHoldsAction()
  return gridActive or Truth(Call("CursorHasItem")) or
         Truth(Call("CursorHasSpell")) or Truth(Call("CursorHasMacro"))
end

local function OnClick(button, a, b)
  if U.IsUnlocked() or not HasPetBar() then return end
  if CursorHoldsAction() then
    RunAction("PickupPetAction", button.puiIndex)
    return
  end
  if not button.puiUsable then return end

  if U.MouseButton(a, b) == "RightButton" then
    if button.puiCastable then RunAction("TogglePetAutocast", button.puiIndex) end
  elseif COMMANDS[button.puiIndex] then
    RunAction(COMMANDS[button.puiIndex])
  else
    U.Print(U.L("PETBAR_CUSTOM_WARNING"))
  end
end

local function OnDrag(button)
  if not U.IsUnlocked() and HasPetBar() then
    RunAction("PickupPetAction", button.puiIndex)
  end
end

local function HideTooltip()
  local tooltip = U.G("GameTooltip")
  if tooltip then pcall(tooltip.Hide, tooltip) end
end

local function ShowTooltip(button)
  local tooltip = U.G("GameTooltip")
  if not tooltip then return end
  local name, _, _, token = PetInfo(button.puiIndex)
  if not name then return end
  pcall(tooltip.SetOwner, tooltip, button, "ANCHOR_RIGHT")
  local ok
  if Truth(token) then
    ok = pcall(tooltip.SetText, tooltip, U.G(name) or name)
  else
    ok = pcall(tooltip.SetPetAction, tooltip, button.puiIndex)
  end
  if ok then pcall(tooltip.Show, tooltip) else HideTooltip() end
end

local function CreateButton(index, size)
  local name = "PandaUIPetBarButton" .. index
  local button = CreateFrame("Button", name, frame)
  button.puiIndex = index
  button:SetWidth(size)
  button:SetHeight(size)
  -- Always the shared flat Modern primitives, even with Classic selected.
  U.CreateBackdrop(button, {})
  pcall(button.EnableMouse, button, true)
  pcall(button.RegisterForClicks, button, "LeftButtonUp", "RightButtonUp")
  pcall(button.RegisterForDrag, button, "LeftButton", "RightButton")

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", ICON_INSET, -ICON_INSET)
  icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
  pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
  button.puiIcon = icon

  local cooldown = CreateFrame("Frame", name .. "Cooldown", button)
  cooldown:SetPoint("TOPLEFT", button, "TOPLEFT", ICON_INSET, -ICON_INSET)
  cooldown:SetWidth(size - 2 * ICON_INSET)
  cooldown:SetHeight(size - 2 * ICON_INSET)
  pcall(cooldown.EnableMouse, cooldown, false)
  local okLevel, level = pcall(button.GetFrameLevel, button)
  if okLevel and tonumber(level) then pcall(cooldown.SetFrameLevel, cooldown, level + 1) end
  button.puiCooldown = cooldown
  button.puiSweep = U.CreateRadialWipe(cooldown)

  button:SetScript("OnClick", function(a, b) OnClick(button, a, b) end)
  button:SetScript("OnDragStart", function() OnDrag(button) end)
  button:SetScript("OnReceiveDrag", function() OnDrag(button) end)
  button:SetScript("OnMouseDown", function()
    button.puiPressed = true
    ApplyState(button)
  end)
  button:SetScript("OnMouseUp", function()
    button.puiPressed = false
    ApplyState(button)
  end)
  button:SetScript("OnEnter", function()
    button.puiHover = true
    ApplyState(button)
    ShowTooltip(button)
  end)
  button:SetScript("OnLeave", function()
    button.puiHover, button.puiPressed = false, false
    ApplyState(button)
    HideTooltip()
  end)
  return button
end

local function RefreshSweep(button)
  local duration = button.puiCdDuration or 0
  local remaining = button.puiCdActive and
                    U.CooldownRemaining(button.puiCdStart, duration)
  if not remaining or remaining <= 0 or duration <= 0 then
    button.puiCdActive = false
    U.HideRadialWipe(button.puiSweep)
  else
    U.SetRadialWipeProgress(button.puiSweep, (duration - remaining) / duration)
  end
end

local function UpdateButton(button, usable)
  local name, _, texture, token, active, castable, autocast = PetInfo(button.puiIndex)
  if Truth(token) and type(texture) == "string" then texture = U.G(texture) end
  local hasTexture = type(texture) == "string" and texture ~= ""
  if hasTexture then
    pcall(button.puiIcon.SetTexture, button.puiIcon, texture)
    button.puiIcon:Show()
  else
    button.puiIcon:Hide()
  end

  button.puiUsable = usable and name ~= nil
  button.puiActive = Truth(active)
  button.puiCastable = Truth(castable)
  button.puiAutocast = Truth(autocast)
  pcall(button.puiIcon.SetDesaturated, button.puiIcon, not button.puiUsable)
  local tint = button.puiUsable and 1 or M.color.textDim[1]
  U.SetColor(button.puiIcon, tint, tint, tint, 1)

  local start, duration, enabled = Call("GetPetActionCooldown", button.puiIndex)
  button.puiCdStart = tonumber(start) or 0
  button.puiCdDuration = tonumber(duration) or 0
  button.puiCdActive = button.puiCdStart > 0 and button.puiCdDuration > 0 and Truth(enabled)
  RefreshSweep(button)
  ApplyState(button)
end

local function Refresh()
  if not frame or (U.PerfDisabled and U.PerfDisabled("petbar")) then return end
  local visible = HasPetBar() or U.IsUnlocked()
  if visible then
    frame:Show()
    local usable = not U.IsUnlocked()
    if Resolve("GetPetActionsUsable") then
      usable = usable and Truth(Call("GetPetActionsUsable"))
    end
    local i
    for i = 1, SLOT_COUNT do
      local button = buttons[i]
      button:Show()
      button.puiCooldown:Show()
      U.SetBackdropShown(button, true)
      UpdateButton(button, usable)
    end
  elseif shown then
    HideTooltip()
    local i
    for i = 1, SLOT_COUNT do
      local button = buttons[i]
      button.puiHover, button.puiPressed = false, false
      button.puiIcon:Hide()
      button.puiCdActive = false
      U.HideRadialWipe(button.puiSweep)
      button.puiCooldown:Hide()
      U.SetBackdropShown(button, false)
      button:Hide()
    end
    frame:Hide()
  end
  shown = visible
end

local function RefreshSweeps()
  if not shown or (U.PerfDisabled and U.PerfDisabled("petbar")) then return end
  local i
  for i = 1, SLOT_COUNT do
    if buttons[i].puiCdActive then RefreshSweep(buttons[i]) end
  end
end

local function SuppressNativeBar()
  -- Same scoped list as the archived implementation, plus the two outer-art
  -- regions verified by the 2026-08-30 interface capture. Never registered in
  -- native mode. Reload is required to remove these suppression registrations.
  local names = { "PetActionBarFrame", "SlidingActionBarTexture0", "SlidingActionBarTexture1" }
  local parts = { "Icon", "NormalTexture", "NormalTexture2", "HotKey", "Count",
                  "Border", "Cooldown", "Flash", "Name", "AutoCast", "AutoCastable" }
  local i, j
  for i = 1, SLOT_COUNT do
    local name = "PetActionButton" .. i
    table.insert(names, name)
    for j = 1, table.getn(parts) do table.insert(names, name .. parts[j]) end
  end
  U.SuppressNativeFrame(names, "petbar")
end

function U.EnableCustomPetBar(config)
  if frame then return end
  cfg = config
  local perRow = Clamp(cfg.perRow, 10, 1, SLOT_COUNT)
  local size = Clamp(cfg.size, 24, 15, 60)
  local spacing = Clamp(cfg.spacing, 2, -3, 20)
  local rows = math.ceil(SLOT_COUNT / perRow)

  frame = CreateFrame("Frame", "PandaUIPetBar", UIParent)
  pcall(frame.SetFrameStrata, frame, "LOW")
  frame:SetWidth(perRow * size + (perRow - 1) * spacing)
  frame:SetHeight(rows * size + (rows - 1) * spacing)
  local i
  for i = 1, SLOT_COUNT do
    local button = CreateButton(i, size)
    local row = math.floor((i - 1) / perRow)
    local column = (i - 1) - row * perRow
    button:SetPoint("TOPLEFT", frame, "TOPLEFT",
                    column * (size + spacing), -row * (size + spacing))
    buttons[i] = button
  end
  U.RegisterMover("petbar", frame, {
    label = U.L("MOVER_LABEL_PET_BAR"),
    default = { point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 64 },
  })
  -- Hide all newly created regions on a petless login, not just on transitions.
  shown = true
  Refresh()
  U.RegisterEvent("PLAYER_ENTERING_WORLD", Refresh)
  U.RegisterEvent("UNIT_PET", Refresh)
  U.RegisterEvent("PET_BAR_UPDATE", Refresh)
  U.RegisterEvent("PET_BAR_UPDATE_COOLDOWN", Refresh)
  U.RegisterEvent("PET_BAR_SHOWGRID", function() gridActive = true end)
  U.RegisterEvent("PET_BAR_HIDEGRID", function() gridActive = false end)
  U.RegisterUpdate("petbar.custom", 0.5, Refresh)
  U.RegisterUpdate("petbar.custom.cooldowns", 0.05, RefreshSweeps)
  -- Create the replacement successfully before registering native suppression.
  SuppressNativeBar()
end
