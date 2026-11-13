local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Equip Compare"],
  description = T["Shows currently equipped items on tooltips while the shift key is pressed."],
  expansions = { ["vanilla"] = true },
  category = T["Tooltip & Items"],
  enabled = true,
})

local function MatchBackground(compare, source)
  if not ShaguTweaks_config or ShaguTweaks_config[T["Darkened UI"]] ~= 1
    or not source.GetBackdropColor or not compare.SetBackdropColor then return end
  local r,g,b,a = source:GetBackdropColor()
  if not r then return end
  local cr,cg,cb,ca = compare:GetBackdropColor()
  if cr ~= r or cg ~= g or cb ~= b or ca ~= a then compare:SetBackdropColor(r,g,b,a) end
end

local function EnableNativeCompare(self)
  if not API.tooltipsetitem or not API.modifierstate or not API.timer
    or not ShoppingTooltip1 or not ShoppingTooltip2
    or type(ShoppingTooltip1.SetHyperlinkCompareItem) ~= "function"
    or type(ShoppingTooltip2.SetHyperlinkCompareItem) ~= "function" then return false end
  local active, activeLink, activeOwner, activeRevision
  local firstShown, secondShown
  local revision, building = 0, false
  local tracked, order = {}, {}
  local function Hide(tooltip)
    if tooltip and tooltip ~= active then return end
    active = nil
    activeLink, activeOwner, activeRevision = nil, nil, nil
    firstShown, secondShown = nil, nil
    ShoppingTooltip1:Hide(); ShoppingTooltip2:Hide()
  end
  local function Restore(tooltip, link, owner)
    if not API.IsShiftKeyDown() or active ~= tooltip or activeLink ~= link
      or activeOwner ~= owner or activeRevision ~= revision then return false end
    -- Hide clears native ownership. Show alone can briefly display the cached
    -- text but leave an unowned tooltip that the client then discards/fades.
    -- Rebind to the actual hovered button (not the source tooltip) and refill
    -- in the same frame only when the native owner/content was lost.
    building = true
    for i = 1, 2 do
      local compare = i == 1 and ShoppingTooltip1 or ShoppingTooltip2
      if (i == 1 and firstShown) or (i == 2 and secondShown) then
        if not compare:IsShown() or compare:GetOwner() ~= (owner or UIParent) then
          local point, relative, relativePoint, x, y = compare:GetPoint()
          compare:SetOwner(owner or UIParent, "ANCHOR_NONE")
          if point then compare:SetPoint(point, relative, relativePoint, x, y) end
          if compare:SetHyperlinkCompareItem(link, i, true, tooltip) then compare:Show() end
        end
        MatchBackground(compare, tooltip)
      end
    end
    building = false
    return true
  end
  local function Show(tooltip)
    if building then return end
    if not tooltip:IsShown() then Hide(tooltip); return end
    if not API.IsShiftKeyDown() then Hide(); return end
    local _, link = tooltip:GetItem()
    if not link then Hide(tooltip); return end
    local owner = tooltip:GetOwner()
    -- Native/tooltips addons can rebuild the hovered item repeatedly. Its
    -- comparison does not change unless the item, owner or equipped data did.
    if Restore(tooltip, link, owner) then return end
    building = true
    Hide()
    local x = GetCursorPosition() / UIParent:GetEffectiveScale()
    local left = x >= GetScreenWidth() / 2
    local point, parent = tooltip:GetPoint()
    if parent == UIParent and point == "TOPRIGHT" then left = true end
    local anchor, relative = left and "TOPRIGHT" or "TOPLEFT", left and "TOPLEFT" or "TOPRIGHT"
    local previous = tooltip
    for i = 1, 2 do
      local compare = i == 1 and ShoppingTooltip1 or ShoppingTooltip2
      compare:SetOwner(owner or UIParent, "ANCHOR_NONE")
      compare:ClearAllPoints()
      compare:SetPoint(anchor, previous, relative, 0, 0)
      -- Preserve the full item link (enchants/random suffixes). Native code
      -- selects filled ring/weapon slots and supplies the equipped header.
      if compare:SetHyperlinkCompareItem(link, i, true, tooltip) then
        compare:Show()
        MatchBackground(compare, tooltip)
        previous = compare
        active = tooltip
      else compare:Hide() end
    end
    if active then
      activeLink, activeOwner, activeRevision = link, owner, revision
      firstShown, secondShown = ShoppingTooltip1:IsShown(), ShoppingTooltip2:IsShown()
    end
    building = false
  end
  local function Schedule(tooltip)
    local state = tracked[tooltip]
    if building or not state or state.pending then return end
    state.pending = true
    API.Defer(state.refresh)
  end
  -- A comparison may be hidden by native/foreign tooltip code independently
  -- of its source. Repair on that event; no recurring polling driver.
  local function ComparisonHidden()
    if active and not building then Schedule(active) end
  end
  ShoppingTooltip1:HookScript("OnHide", ComparisonHidden)
  ShoppingTooltip2:HookScript("OnHide", ComparisonHidden)
  local function SourceUpdated(tooltip)
    if building then return end
    if tooltip:IsShown() then
      local _, link = tooltip:GetItem()
      if link then Restore(tooltip, link, tooltip:GetOwner()) end
    end
    Schedule(tooltip)
  end
  local function Track(tooltip)
    if not tooltip or tracked[tooltip] or type(tooltip.GetItem) ~= "function" then return end
    local state = {}
    tracked[tooltip] = state
    table.insert(order, tooltip)
    state.refresh = function()
      state.pending = nil
      Show(tooltip)
    end
    local updated = function() SourceUpdated(tooltip) end
    local settled = function() Schedule(tooltip) end
    tooltip:HookScript("OnTooltipSetItem", updated)
    -- Clearing is part of a normal item rebuild. Inspect the settled content
    -- next frame instead of hiding a still-valid comparison immediately.
    tooltip:HookScript("OnTooltipCleared", settled)
    tooltip:HookScript("OnHide", settled)
    tooltip:HookScript("OnShow", updated)
  end
  ShoppingTooltip1:SetClampedToScreen(true)
  ShoppingTooltip2:SetClampedToScreen(true)
  Track(GameTooltip)
  Track(ItemRefTooltip)
  ShaguTweaks.HookAddonOrVariable("AtlasLoot", function()
    Track(AtlasLootTooltip); Track(AtlasLootTooltip2)
  end)
  local function VisibleItemTooltip()
    for _, tooltip in ipairs(order) do
      if tooltip:IsShown() then
        local _, link = tooltip:GetItem()
        if link then return tooltip end
      end
    end
  end
  local modifier = CreateFrame("Frame")
  self.nativeModifier = modifier
  modifier:RegisterEvent("MODIFIER_STATE_CHANGED")
  local utils = _G.C_EventUtils
  if utils and utils.IsEventValid and utils.IsEventValid("PLAYER_EQUIPMENT_CHANGED") then
    modifier:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  else modifier:RegisterEvent("UNIT_INVENTORY_CHANGED") end
  if utils and utils.IsEventValid and utils.IsEventValid("GET_ITEM_INFO_RECEIVED") then
    modifier:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  end
  modifier:SetScript("OnEvent", function()
    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED"
      or event == "GET_ITEM_INFO_RECEIVED" then
      if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
      revision = revision + 1
      if not API.IsShiftKeyDown() then return end
      if active then Schedule(active)
      else
        local tooltip = VisibleItemTooltip()
        if tooltip then Schedule(tooltip) end
      end
      return
    end
    if arg1 ~= "LSHIFT" and arg1 ~= "RSHIFT" then return end
    if not API.IsShiftKeyDown() then Hide(); return end
    if active and active:IsShown() then Show(active); return end
    local tooltip = VisibleItemTooltip()
    if tooltip then Show(tooltip) end
  end)
  return true
end

module.enable = function(self)
  if self.installed then return end
  if EnableNativeCompare(self) then self.installed = true; return end
  if not API.tooltipsetitem or not API.modifierstate or not API.timer
    or not API.iteminventorytype or not API.iteminventoryslotkey then
    return
  end
  self.installed = true

  local sides = { "Left", "Right" }

  local function AddHeader(tooltip)
    local name = tooltip:GetName()

    for i=tooltip:NumLines(), 1, -1 do
      for _, side in pairs(sides) do
        local current = _G[name.."Text"..side..i]
        local below = _G[name.."Text"..side..i+1]

        if current and current:IsShown() then
          local text = current:GetText()
          local r, g, b = current:GetTextColor()

          if text and text ~= "" then
            if tooltip:NumLines() < i+1 then
              tooltip:AddLine(text, r, g, b, true)
            else
              below:SetText(text)
              below:SetTextColor(r, g, b)
              below:Show()
              current:Hide()
            end
          end
        end
      end
    end

    _G[name.."TextLeft1"]:SetTextColor(.5, .5, .5, 1)
    _G[name.."TextLeft1"]:SetText(CURRENTLY_EQUIPPED)
    _G[name.."TextLeft1"]:Show()
    tooltip:Show()
  end

  local slots = {
    ["INVTYPE_2HWEAPON"] = { "MainHandSlot" },
    ["INVTYPE_BODY"] = { "ShirtSlot" },
    ["INVTYPE_CHEST"] = { "ChestSlot" },
    ["INVTYPE_CLOAK"] = { "BackSlot" },
    ["INVTYPE_FEET"] = { "FeetSlot" },
    ["INVTYPE_FINGER"] = { "Finger0Slot", "Finger1Slot" },
    ["INVTYPE_HAND"] = { "HandsSlot" },
    ["INVTYPE_HEAD"] = { "HeadSlot" },
    ["INVTYPE_HOLDABLE"] = { "SecondaryHandSlot" },
    ["INVTYPE_LEGS"] = { "LegsSlot" },
    ["INVTYPE_NECK"] = { "NeckSlot" },
    ["INVTYPE_RANGED"] = { "RangedSlot" },
    ["INVTYPE_RANGEDRIGHT"] = { "RangedSlot" },
    ["INVTYPE_RELIC"] = { "RangedSlot" },
    ["INVTYPE_ROBE"] = { "ChestSlot" },
    ["INVTYPE_SHIELD"] = { "SecondaryHandSlot" },
    ["INVTYPE_SHOULDER"] = { "ShoulderSlot" },
    ["INVTYPE_TABARD"] = { "TabardSlot" },
    ["INVTYPE_TRINKET"] = { "Trinket0Slot", "Trinket1Slot" },
    ["INVTYPE_WAIST"] = { "WaistSlot" },
    ["INVTYPE_WEAPON"] = { "MainHandSlot", "SecondaryHandSlot" },
    ["INVTYPE_WEAPONMAINHAND"] = { "MainHandSlot" },
    ["INVTYPE_WEAPONOFFHAND"] = { "SecondaryHandSlot" },
    ["INVTYPE_WRIST"] = { "WristSlot" },
    ["INVTYPE_AMMO"] = { "AmmoSlot" },
    ["INVTYPE_THROWN"] = { "RangedSlot" },
  }

  ShoppingTooltip1:SetClampedToScreen(true)
  ShoppingTooltip2:SetClampedToScreen(true)

  local function GetSlotNames(tooltip)
    local itemID = API.GetTooltipItemID(tooltip)
    if not itemID then return end

    local inventoryType = API.GetItemInventoryTypeByID(itemID)
    if inventoryType == nil then return end

    local slotKey = API.GetItemInventorySlotKey(inventoryType)
    return slotKey and slots[slotKey]
  end

  local activeTooltip

  local function HideCompare(tooltip)
    if tooltip and activeTooltip ~= tooltip then return end
    ShoppingTooltip1:Hide()
    ShoppingTooltip2:Hide()
    activeTooltip = nil
  end

  local function ShowCompare(tooltip)
    if not tooltip then return end

    HideCompare()

    if not API.IsShiftKeyDown() then return end

    local slotNames = GetSlotNames(tooltip)
    if not slotNames or not slotNames[1] then return end

    local x = GetCursorPosition() / UIParent:GetEffectiveScale()
    local anchor = x < GetScreenWidth() / 2 and "TOPLEFT" or "TOPRIGHT"
    local relative = x < GetScreenWidth() / 2 and "TOPRIGHT" or "TOPLEFT"

    local pos, parent = tooltip:GetPoint()
    if parent and parent == UIParent and pos == "TOPRIGHT" then
      anchor = "TOPRIGHT"
      relative = "TOPLEFT"
    end

    local slotID = GetInventorySlotInfo(slotNames[1])
    ShoppingTooltip1:SetOwner(tooltip, "ANCHOR_NONE")
    ShoppingTooltip1:ClearAllPoints()
    ShoppingTooltip1:SetPoint(anchor, tooltip, relative, 0, 0)
    ShoppingTooltip1:SetInventoryItem("player", slotID)
    ShoppingTooltip1:Show()
    AddHeader(ShoppingTooltip1)
    MatchBackground(ShoppingTooltip1, tooltip)

    if slotNames[2] then
      local secondSlotID = GetInventorySlotInfo(slotNames[2])
      ShoppingTooltip2:SetOwner(tooltip, "ANCHOR_NONE")
      ShoppingTooltip2:ClearAllPoints()
      if ShoppingTooltip1:IsShown() then
        ShoppingTooltip2:SetPoint(anchor, ShoppingTooltip1, relative, 0, 0)
      else
        ShoppingTooltip2:SetPoint(anchor, tooltip, relative, 0, 0)
      end
      ShoppingTooltip2:SetInventoryItem("player", secondSlotID)
      ShoppingTooltip2:Show()
      AddHeader(ShoppingTooltip2)
      MatchBackground(ShoppingTooltip2, tooltip)
    end

    activeTooltip = tooltip
  end

  local trackedTooltips = {}
  local pending = {}

  local function ScheduleCompare(tooltip)
    if not tooltip or pending[tooltip] then return end
    pending[tooltip] = true

    API.Defer(function()
      pending[tooltip] = nil
      if tooltip:IsShown() then
        ShowCompare(tooltip)
      end
    end)
  end

  local function TrackTooltip(tooltip)
    if not tooltip or trackedTooltips[tooltip] then return end
    trackedTooltips[tooltip] = true

    tooltip:HookScript("OnTooltipSetItem", function()
      ScheduleCompare(tooltip)
    end)

    tooltip:HookScript("OnTooltipCleared", function()
      HideCompare(tooltip)
    end)
  end

  TrackTooltip(GameTooltip)

  local modifier = CreateFrame("Frame")
  modifier:RegisterEvent("MODIFIER_STATE_CHANGED")
  modifier:SetScript("OnEvent", function()
    if arg1 ~= "LSHIFT" and arg1 ~= "RSHIFT" then return end

    for tooltip in pairs(trackedTooltips) do
      if tooltip:IsShown() and API.GetTooltipItemID(tooltip) then
        ShowCompare(tooltip)
      end
    end
  end)

  ShaguTweaks.HookAddonOrVariable("AtlasLoot", function()
    TrackTooltip(AtlasLootTooltip)
    TrackTooltip(AtlasLootTooltip2)
  end)
end
