local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local buttons, bars = {}, {}
local driver, macroRunner, ghost
local dragSource
local nativeGridButtons = {}
local nativeButtonPrefixes = {
  "ActionButton", "BonusActionButton", "MultiBarBottomLeftButton",
  "MultiBarBottomRightButton", "MultiBarLeftButton", "MultiBarRightButton",
}
local item, spell
local buttonSize, spacing = 36, 6
local buttonCount = 12
local events = {
  "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE",
  "ACTIONBAR_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_USABLE",
  "BAG_UPDATE", "BAG_UPDATE_COOLDOWN", "UNIT_INVENTORY_CHANGED",
  "UPDATE_MACROS", "UPDATE_BINDINGS", "GET_ITEM_INFO_RECEIVED",
  "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "CURSOR_CHANGED", "CURSOR_UPDATE",
}

local function UpdateVisibility(button, showGrid)
  local show = showGrid or button.actions[button.index] ~= nil
  if show and not button:IsShown() then button:Show()
  elseif not show and button:IsShown() then button:Hide() end
end

local function ShowGrid()
  local always = _G.ALWAYS_SHOW_MULTIBARS
  if always == 1 or always == "1" or dragSource then return true end
  local kind = GetCursorInfo()
  return kind == "spell" or kind == "item" or kind == "macro"
end

local function UpdateGrid()
  local show = ShowGrid()
  for _, button in ipairs(buttons) do UpdateVisibility(button, show) end
end

local function BindingName(bar, index)
  return "STBAR" .. bar .. "BUTTON" .. index
end

local function GetMacroIndex(action)
  if action.macroSlot and GetMacroInfo(action.macroSlot) == action.id then
    return action.macroSlot
  end
  if _G.GetMacroIndexByName then
    local index = GetMacroIndexByName(action.id)
    if index and index > 0 then return index end
  end
end

local function DisplayAction(action)
  if action.kind ~= "macro" then return action.kind, action.id end
  local index = GetMacroIndex(action)
  if not index then return end
  local _, icon = GetMacroInfo(index)
  local spellID
  if _G.GetMacroSpell then _, _, spellID = GetMacroSpell(index) end
  if spellID and spellID > 0 then return "spell", spellID, icon end
  if _G.GetMacroItem then
    local _, link = GetMacroItem(index)
    if link then return "item", link, icon end
  end
  return "macro", index, icon
end

local function Refresh(button)
  local action = button.actions[button.index]
  local icon, count, start, duration, enable
  local red, green, blue = 1, 1, 1
  if action then
    local kind, id, macroIcon = DisplayAction(action)
    icon = macroIcon
    if kind == "spell" then
      local _, _, spellIcon = GetSpellInfo(id)
      icon = icon or spellIcon
      local usable, noMana = IsUsableSpell(id)
      if noMana then red, green, blue = .5, .5, 1
      elseif not usable then red, green, blue = .4, .4, .4 end
      local cooldown = spell.GetSpellCooldown(id)
      if cooldown then
        start, duration, enable = cooldown.startTime, cooldown.duration, cooldown.isEnabled and 1 or 0
      end
    elseif kind == "item" then
      icon = icon or item.GetItemIconByID(id)
      count = item.GetItemCount(id)
      if count == 0 then red, green, blue = .4, .4, .4 end
      start, duration, enable = GetItemCooldown(id)
    end
    icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
  end
  button.icon:SetTexture(icon)
  if icon then button.icon:Show() else button.icon:Hide() end
  button.icon:SetVertexColor(red, green, blue)
  button.count:SetText(count and count > 1 and count or "")
  local filled = action ~= nil
  if button.filled ~= filled then
    button.filled = filled
    button:SetNormalTexture(filled and "Interface\\Buttons\\UI-Quickslot2" or "Interface\\Buttons\\UI-Quickslot")
    -- Match ActionButton_ShowGrid's translucent empty-slot artwork.
    local normal = button:GetNormalTexture()
    normal:SetVertexColor(1, 1, 1, filled and 1 or .5)
    if ShaguTweaks.StyleActionButton then
      ShaguTweaks.StyleActionButton(button, normal, true)
    end
  end
  start, duration, enable = start or 0, duration or 0, enable or 0
  if button.start ~= start or button.duration ~= duration or button.enable ~= enable then
    button.start, button.duration, button.enable = start, duration, enable
    CooldownFrame_SetTimer(button.cooldown, start, duration, enable)
  end
  UpdateVisibility(button, filled or ShowGrid())
end

local function RefreshBinding(button)
  local key = GetBindingKey(button.binding)
  button.hotkey:SetText(key and GetBindingText(key, "KEY_", 1) or "")
end

local function RefreshTooltip(button)
  local action = button.actions[button.index]
  if not action then return end
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  if action.kind == "spell" then
    GameTooltip:SetSpellByID(action.id, action.pet, true)
  elseif action.kind == "item" then
    GameTooltip:SetItemByID(action.id)
  else
    GameTooltip:SetText(action.id)
  end
  GameTooltip:Show()
end

local function StopDrag()
  dragSource = nil
  if ghost then
    ghost:SetScript("OnUpdate", nil)
    ghost:Hide()
  end
  driver:SetScript("OnUpdate", nil)
  driver:UnregisterEvent("GLOBAL_MOUSE_UP")
  -- Release only the grid references this drag owns.
  for index = table.getn(nativeGridButtons), 1, -1 do
    ActionButton_HideGrid(table.remove(nativeGridButtons, index))
  end
  UpdateGrid()
end

local function MoveAction(button)
  local source = dragSource
  StopDrag()
  if source == button then return end
  source.actions[source.index], button.actions[button.index] =
    button.actions[button.index], source.actions[source.index]
  Refresh(source)
  Refresh(button)
end

local function IsNativeButton(button)
  local name = button and button.GetName and button:GetName()
  if not name then return end
  for _, prefix in ipairs(nativeButtonPrefixes) do
    if string.find(name, "^" .. prefix .. "%d+$") then return true end
  end
end

local function PlaceOnNativeButton(source, target)
  if not target:IsVisible() or not _G.GetActionInfo then return end
  local slot = ActionButton_GetPagedID(target)
  if not slot or slot < 1 or slot > 120 then return end
  if GetCursorInfo() or CursorHasItem() or CursorHasSpell() or SpellIsTargeting() then return end

  local action = source.actions[source.index]
  local id = action.id
  if action.kind == "spell" and _G.FindSpellBookSlotByID then
    local bookSlot, book = FindSpellBookSlotByID(id)
    if bookSlot then PickupSpell(bookSlot, book) end
  elseif action.kind == "item" and item.PickupItem then
    item.PickupItem(id)
  elseif action.kind == "macro" then
    id = GetMacroIndex(action)
    if id then PickupMacro(id) end
  end
  local kind, cursorID, _, spellID = GetCursorInfo()
  if kind ~= action.kind or (spellID or cursorID) ~= id then
    if kind then ClearCursor() end
    return
  end

  local previousKind, previousID = GetActionInfo(slot)
  if previousKind == kind and previousID == id then
    ClearCursor()
    return
  end
  PlaceAction(slot)
  local placedKind, placedID = GetActionInfo(slot)
  if placedKind == kind and placedID == id then
    source.actions[source.index] = nil
    Refresh(source)
  else
    ClearCursor()
  end
end

local function CompleteDrag()
  -- Without a native cursor payload, FrameXML can omit OnReceiveDrag.
  local target = GetMouseFocus()
  if target and target.stExtraActionButton and target:IsVisible() then
    MoveAction(target)
  else
    local source = dragSource
    if IsNativeButton(target) then PlaceOnNativeButton(source, target) end
    StopDrag()
  end
end

local function FinishDrag()
  if not dragSource then return end
  -- Give OnReceiveDrag and OnClick the rest of this mouse dispatch.
  driver:SetScript("OnUpdate", CompleteDrag)
end

local function FollowCursor()
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

local function StartDrag()
  if (LOCK_ACTIONBAR == "1" or LOCK_ACTIONBAR == 1) and not API.IsShiftKeyDown() then return end
  local action = this.actions[this.index]
  if dragSource or not action or GetCursorInfo() or CursorHasItem() or SpellIsTargeting() then return end
  if not ghost then
    ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetWidth(buttonSize)
    ghost:SetHeight(buttonSize)
    ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
    ghost.icon:SetAllPoints(ghost)
  end
  dragSource = this
  for _, prefix in ipairs(nativeButtonPrefixes) do
    for index = 1, buttonCount do
      local button = _G[prefix .. index]
      if button then
        ActionButton_ShowGrid(button)
        table.insert(nativeGridButtons, button)
      end
    end
  end
  UpdateGrid()
  GameTooltip:Hide()
  ghost.icon:SetTexture(this.icon:GetTexture())
  FollowCursor()
  ghost:SetScript("OnUpdate", FollowCursor)
  ghost:Show()
  local utils = _G.C_EventUtils
  if utils and utils.IsEventValid("GLOBAL_MOUSE_UP") then driver:RegisterEvent("GLOBAL_MOUSE_UP") end
end

local function Drop(button)
  if dragSource then
    MoveAction(button)
    return true
  end

  local kind, id, book, spellID = GetCursorInfo()
  local action
  if kind == "spell" and spellID and spellID > 0 then
    action = { kind = kind, id = spellID, pet = book == "pet" or nil }
  elseif kind == "item" and id and id > 0 then
    action = { kind = kind, id = id }
  elseif kind == "macro" and id then
    local name = GetMacroInfo(id)
    if name then action = { kind = kind, id = name, macroSlot = id } end
  end
  if action then
    -- ClearCursor returns the dragged object to its native source.
    button.actions[button.index] = action
    ClearCursor()
    Refresh(button)
    UpdateGrid()
    return true
  end
  return kind or CursorHasItem() or CursorHasSpell() or (GetCursorMoney() or 0) > 0
end

local function Activate(button, mouseButton)
  local action = button.actions[button.index]
  if not action then return end
  if action.kind == "spell" then
    CastSpellByID(action.id)
  elseif action.kind == "item" then
    item.UseItemByName(action.id)
  else
    if MacroFrame_SaveMacro then MacroFrame_SaveMacro() end
    local index = GetMacroIndex(action)
    if index then
      macroRunner:SetAttribute("macro", index)
      macroRunner:Click(mouseButton)
    end
  end
end

local function Click()
  this:SetChecked(0)
  if dragSource then return end
  if Drop(this) then return end
  if arg1 == "RightButton" and API.IsShiftKeyDown() then
    this.actions[this.index] = nil
    GameTooltip:Hide()
    Refresh(this)
    return
  end
  Activate(this, arg1)
end

local function ReceiveDrag()
  Drop(this)
end

local function OnEvent()
  if event == "GLOBAL_MOUSE_UP" then
    if arg1 == "LeftButton" then FinishDrag() end
    return
  end
  if event == "ACTIONBAR_SHOWGRID" or event == "ACTIONBAR_HIDEGRID"
    or event == "CURSOR_CHANGED" or event == "CURSOR_UPDATE" then
    UpdateGrid()
    return
  end
  if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
  if event == "PLAYER_ENTERING_WORLD" then UpdateGrid() end
  for _, button in ipairs(buttons) do
    if event == "PLAYER_ENTERING_WORLD" and ShaguTweaks.StyleActionButton then
      ShaguTweaks.StyleActionButton(button, button:GetNormalTexture(), true)
    end
    if event == "UPDATE_BINDINGS" or event == "PLAYER_ENTERING_WORLD" then RefreshBinding(button) end
    if event ~= "UPDATE_BINDINGS" and button.actions[button.index] then Refresh(button) end
  end
end

function ShaguTweaks.ExtraActionButton(bar, index, state)
  local button = bars[bar] and bars[bar][index]
  if not button or not button:IsVisible() then return end
  local onDown = GetCVar("ActionButtonUseKeyDown") == "1"
  if state == "down" then
    button:SetButtonState("PUSHED")
    if onDown then Activate(button, "LeftButton") end
  elseif state == "up" then
    button:SetButtonState("NORMAL")
    if not onDown then Activate(button, "LeftButton") end
  end
end

local function Setup()
  if driver then return true end
  item, spell = _G.C_Item, _G.C_Spell
  if not item or not item.UseItemByName or not item.GetItemCount or not item.GetItemIconByID
    or not spell or not spell.GetSpellCooldown or not _G.GetCursorInfo or not _G.CastSpellByID
    or not _G.IsUsableSpell or not _G.GetItemCooldown or not _G.GetSpellInfo
    or not GameTooltip.SetSpellByID or not GameTooltip.SetItemByID then
    return
  end
  macroRunner = CreateFrame("Button", nil, UIParent)
  if not macroRunner.SetAttribute then return end
  macroRunner:SetAttribute("type", "macro")
  macroRunner:EnableMouse(false)

  driver = CreateFrame("Frame")
  driver:SetScript("OnEvent", OnEvent)
  local utils = _G.C_EventUtils
  for _, name in ipairs(events) do
    if not utils or utils.IsEventValid(name) then driver:RegisterEvent(name) end
  end
  ShaguTweaks.hooksecurefunc("MultiActionBar_UpdateGridVisibility", UpdateGrid)
  return true
end

local function CreateBar(number)
  if not Setup() then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00ShaguTweaks:|r " .. T["Update ClassicAPI to use the extra action bars."])
    return
  end
  ShaguTweaks_config.ExtraActionBarSlots = ShaguTweaks_config.ExtraActionBarSlots or {}
  local saved = ShaguTweaks_config.ExtraActionBarSlots
  saved[number] = saved[number] or {}
  local frame = CreateFrame("Frame", "ShaguTweaksExtraActionBar" .. number, UIParent)
  local horizontal = number == 6
  local length = buttonCount * (buttonSize + spacing) - spacing
  frame:SetWidth(horizontal and length or buttonSize)
  frame:SetHeight(horizontal and buttonSize or length)
  frame:SetClampedToScreen(true)
  if horizontal then
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 195)
  else
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -104, 0)
  end
  bars[number] = {}
  for index = 1, buttonCount do
    local name = frame:GetName() .. "Button" .. index
    local button = CreateFrame("CheckButton", name, frame, "ActionButtonTemplate")
    button.stExtraActionButton = true
    button.actions, button.index, button.binding = saved[number], index, BindingName(number, index)
    local offset = (index - 1) * (buttonSize + spacing)
    button:SetWidth(buttonSize)
    button:SetHeight(buttonSize)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", horizontal and offset or 0, horizontal and 0 or -offset)

    button.icon = _G[name .. "Icon"]
    button.cooldown = _G[name .. "Cooldown"]
    button.hotkey = _G[name .. "HotKey"]
    button.count = _G[name .. "Count"]

    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnDragStart", StartDrag)
    button:SetScript("OnDragStop", FinishDrag)
    button:SetScript("OnReceiveDrag", ReceiveDrag)
    button:SetScript("OnClick", Click)
    button:SetScript("OnEnter", function() RefreshTooltip(this) end)
    button:SetScript("OnLeave", function()
      if GameTooltip:IsOwned(this) then GameTooltip:Hide() end
    end)
    bars[number][index] = button
    table.insert(buttons, button)
    Refresh(button)
    RefreshBinding(button)
  end
end

for bar = 6, 7 do
  local number = bar
  local title = T["Action Bar " .. number]
  _G["BINDING_HEADER_STBAR" .. number] = title
  for index = 1, buttonCount do
    _G["BINDING_NAME_" .. BindingName(number, index)] = string.format(T["%s Button %d"], title, index)
  end
  local module = ShaguTweaks:register({
    title = title,
    description = number == 6 and T["Adds a horizontal bar with 12 independent action slots."]
      or T["Adds a vertical bar with 12 independent action slots."],
    expansions = { ["vanilla"] = true },
    category = T["Action Bar"],
    enabled = nil,
  })
  module.enable = function() CreateBar(number) end
end
