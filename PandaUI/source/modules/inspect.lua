-- pandaUI :: modules/inspect.lua
--
-- Character's theme-specific design applied to the native Inspect window.
-- The client retains ownership of inspect data, model, tabs and item buttons;
-- PandaUI replaces only presentation and layers semantic quality borders.

local U = PandaUI
local M = U.media
local INS = U.RegisterModule("inspect")

local SLOTS = {
  "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
  "ShirtSlot", "TabardSlot", "WristSlot",
  "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
  "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
  "MainHandSlot", "SecondaryHandSlot", "RangedSlot",
}

local PANEL_INSET_LEFT = 10
local PANEL_INSET_RIGHT = 30

local GOLD = M.color.textAccent
local WHITE = M.color.text
local DIM = M.color.textDim

local frame, panel, built, keepNativeChrome, modernMode, modernWowMode

local function G(name)
  return U.G(name)
end

local function SetTextFont(object, size, color)
  U.SetStockFont(object, size or M.fontSize.normal, color or WHITE)
end

local function RefreshClassLine()
  local text = G("InspectLevelText")
  local unit = frame and frame.unit
  local unitClass = G("UnitClass")
  local unitLevel = G("UnitLevel")
  if not text or not unit or type(unitClass) ~= "function" or
     type(unitLevel) ~= "function" then return end

  local classOk, className, classToken = pcall(unitClass, unit)
  local levelOk, level = pcall(unitLevel, unit)
  if not classOk or type(className) ~= "string" or
     not levelOk or not tonumber(level) then return end

  local r, g, b = M.ClassColor(classToken)
  if r then
    className = string.format("|cff%02x%02x%02x%s|r",
      math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
      math.floor(b * 255 + 0.5), className)
  end
  pcall(text.SetText, text,
        U.L("CHARACTER_CLASS_LEVEL", className, tonumber(level)))
end

-- GetInventoryItemQuality is documented for arbitrary unit ids but has not
-- been runtime-verified on this client. UnrealPfUI's working Inspect skin uses
-- GetInventoryItemLink + GetItemInfo instead, so that sequence is the guarded
-- fallback when the direct quality call returns nothing.
local function SlotQuality(unit, inventorySlot)
  local getQuality = G("GetInventoryItemQuality")
  if type(getQuality) == "function" then
    local ok, quality = pcall(getQuality, unit, inventorySlot)
    if ok and tonumber(quality) then return tonumber(quality) end
  end

  local getLink = G("GetInventoryItemLink")
  if type(getLink) ~= "function" then return nil end

  local ok, link = pcall(getLink, unit, inventorySlot)
  if not ok or not link then return nil end

  local infoOk, _, _, quality = pcall(GetItemInfo, U.ItemInfoKey(link))
  return infoOk and tonumber(quality) or nil
end

local function StyleSlot(slotName, nativeChrome)
  local slot = G("Inspect" .. slotName)
  if not slot then return end

  -- Persistent because the Modern WoW quality glow reads the same table after
  -- this refresh. Mutating it also lets hover restore the latest rarity colour
  -- when U.StyleStockButton styled the slot on its first pass.
  local border = slot.puiInspectBorder
  if not border then
    border = { M.Unpack(M.slotBorder.empty) }
    slot.puiInspectBorder = border
  end

  local color = M.slotBorder.empty
  local unit = frame and frame.unit
  local idOk, inventorySlot = false, nil
  if unit and slot.GetID then
    idOk, inventorySlot = pcall(slot.GetID, slot)
  end

  local quality = idOk and SlotQuality(unit, inventorySlot) or nil
  if quality then
    if quality > M.qualityLimit then
      -- Match Character: enhanced blue is scoped to Classic and Modern WoW;
      -- the flat Modern theme retains the client's normal rarity colour.
      local themedColor = nativeChrome or modernWowMode
      color = (themedColor and U.ItemQualityBorderColor(quality) or
               U.ItemQualityColor(quality)) or M.slotBorder.plain
    else
      color = M.slotBorder.plain
    end
  elseif slot.hasItem then
    -- The native update can mark the slot occupied before item info is cached.
    color = M.slotBorder.plain
  end

  border[1], border[2], border[3], border[4] = M.Unpack(color)

  if nativeChrome then
    U.SetGearQualityGlow(slot, border)
  else
    U.StyleStockButton(slot, {
      icon = G("Inspect" .. slotName .. "IconTexture"),
      border = border,
    })
  end
  U.SetBorderColor(slot, M.Unpack(border))
end

local function StyleSlots(nativeChrome)
  local i
  for i = 1, table.getn(SLOTS) do StyleSlot(SLOTS[i], nativeChrome) end
end

-- Keep the gear tab available so Turtle's optional Talent page always has a
-- route back to the paper doll. Remote Honor remains outside this interface;
-- Turtle creates and owns its Talent tab after the inspect window first opens.
local function RefreshTabs()
  local gear = G("InspectFrameTab1")
  local honor = G("InspectFrameTab2")
  if gear then pcall(gear.Show, gear) end
  if honor then pcall(honor.Hide, honor) end
end

local function ShownTabs(tabs)
  local shown = {}
  local i
  for i = 1, table.getn(tabs) do
    local tab = tabs[i]
    if tab and tab.IsShown then
      local ok, visible = pcall(tab.IsShown, tab)
      if ok and visible then table.insert(shown, tab) end
    end
  end
  return shown
end

local function LayoutModernTabs()
  if not modernMode or not frame or not panel then return end
  local tabs = {
    G("InspectFrameTab1"), G("InspectFrameTab2"),
    G("InspectFrameTab3"), G("InspectFrameTab4"),
  }
  local shown = ShownTabs(tabs)
  U.ChainStockTabs(shown, 3)
  U.FitStockTabStrip(shown, frame, {
    gap = 3,
    left = PANEL_INSET_LEFT,
    right = PANEL_INSET_RIGHT,
    padding = M.tab.padding,
    minPadding = M.tab.padding,
    anchor = {
      frame = panel,
      point = "TOPLEFT",
      relativePoint = "BOTTOMLEFT",
      x = 0,
      y = 1,
    },
  })
end

local function WireModernTalentTab(tab, tabs)
  if not tab or tab.puiInspectTalentWired then return end
  local nameOk, name = pcall(tab.GetName, tab)
  local request = G("InspectFrameTalentsTab_OnClick")
  if not nameOk or name ~= "InspectFrameTab4" or
     type(request) ~= "function" then return end

  -- Turtle's four-tab Inspect XML routes Tab4 through InspectFrameTab_OnClick,
  -- which only reveals the empty InspectTalentsFrame parent. Its separate
  -- talent handler requests remote data and shows TWTalentFrame when ready.
  tab.puiInspectTalentWired = true
  pcall(tab.SetScript, tab, "OnClick", function()
    local handler = G("InspectFrameTalentsTab_OnClick")
    if type(handler) == "function" then handler() end
  end)
  U.PostHookScript(tab, "OnClick", function()
    local i
    for i = 1, table.getn(tabs) do
      if tabs[i] and tabs[i].SetActive then
        tabs[i].SetActive(i == 4)
      end
    end
    LayoutModernTabs()
  end)
end

local function StyleModernTabs()
  if not modernMode or not frame then return end
  local tabs = {
    G("InspectFrameTab1"), G("InspectFrameTab2"),
    G("InspectFrameTab3"), G("InspectFrameTab4"),
  }
  WireModernTalentTab(tabs[4], tabs)
  local available = 0
  local i
  for i = 1, table.getn(tabs) do
    if tabs[i] then available = available + 1 end
  end
  if available > (frame.puiInspectModernTabCount or 0) then
    frame.puiInspectModernTabCount = available
    local selected = tonumber(frame.selectedTab) or 1
    U.StyleStockTabGroup(tabs, selected)
    for i = 1, table.getn(tabs) do
      if tabs[i] and not tabs[i].puiInspectLayoutHooked then
        tabs[i].puiInspectLayoutHooked = true
        U.PostHookScript(tabs[i], "OnClick", LayoutModernTabs)
      end
    end
  end

  local selected = tonumber(frame.selectedTab) or 1
  for i = 1, table.getn(tabs) do
    if tabs[i] and tabs[i].SetActive then
      tabs[i].SetActive(i == selected)
    end
  end
  LayoutModernTabs()
end

local function StyleArenaTeam(team)
  if not team then return end
  if not team.puiInspectModern then
    team.puiInspectModern = true
    U.StripStockTextures(team)
    U.CreateBackdrop(team, {
      background = { 0.02, 0.02, 0.02, 0.86 },
      border = M.color.border,
    })

    local nameOk, name = pcall(team.GetName, team)
    if nameOk and type(name) == "string" then
      local details = G(name .. "Details")
      U.StripStockTextures(details)
      SetTextFont(G(name .. "Text"), M.fontSize.large, DIM)
      if details then
        U.ForceStockTextWhite(details, WHITE, M.fontSize.small)
        SetTextFont(G(name .. "DetailsName"), M.fontSize.small, GOLD)
      end
    end
  end
end

local function StyleModernArena()
  if not modernMode then return end
  local arena = G("InspectArenaFrame")
  if not arena then return end
  if not arena.puiInspectModern then
    arena.puiInspectModern = true
    U.StripStockTextures(arena)
    U.PostHookScript(arena, "OnShow", StyleModernArena)
  end

  local i
  for i = 1, 3 do StyleArenaTeam(G("InspectArenaFrameTeam" .. i)) end
end

local function LayoutModernTalentTabs()
  local talent = G("TWTalentFrame")
  if not modernMode or not talent then return end
  local tabs = {
    G("TWTalentFrameTab1"), G("TWTalentFrameTab2"), G("TWTalentFrameTab3"),
  }
  U.ChainStockTabs(tabs, 3)
  U.FitStockTabStrip(tabs, talent, {
    gap = 3,
    left = 23,
    right = 41,
    padding = M.tab.padding,
    minPadding = 4,
    anchor = {
      frame = talent,
      point = "TOPLEFT",
      relativePoint = "TOPLEFT",
      x = 23,
      y = -3,
    },
  })
end

local function RefreshModernTalentButtons()
  local i
  for i = 1, 20 do
    local name = "TWTalentFrameTalent" .. i
    local button = G(name)
    if button then
      U.StyleStockButton(button, { icon = G(name .. "IconTexture") })
      U.HideRegion(G(name .. "Slot"))
      U.HideRegion(G(name .. "RankBorder"))
    end
  end
end

local function RefreshModernTalentChrome()
  RefreshModernTalentButtons()
  LayoutModernTalentTabs()
end

local function InsetTalentSurface(talent)
  if not talent or not talent.puiFill or not talent.puiEdges then return end
  local fill = talent.puiFill
  pcall(function()
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", talent, "TOPLEFT", 10, 0)
    fill:SetPoint("BOTTOMRIGHT", talent, "BOTTOMRIGHT", -30, 9)

    talent.puiEdges[1]:ClearAllPoints()
    talent.puiEdges[1]:SetPoint("TOPLEFT", talent, "TOPLEFT", 10, 0)
    talent.puiEdges[1]:SetPoint("TOPRIGHT", talent, "TOPRIGHT", -30, 0)
    talent.puiEdges[2]:ClearAllPoints()
    talent.puiEdges[2]:SetPoint("BOTTOMLEFT", talent, "BOTTOMLEFT", 10, 9)
    talent.puiEdges[2]:SetPoint("BOTTOMRIGHT", talent, "BOTTOMRIGHT", -30, 9)
    talent.puiEdges[3]:ClearAllPoints()
    talent.puiEdges[3]:SetPoint("TOPLEFT", talent, "TOPLEFT", 10, 0)
    talent.puiEdges[3]:SetPoint("BOTTOMLEFT", talent, "BOTTOMLEFT", 10, 9)
    talent.puiEdges[4]:ClearAllPoints()
    talent.puiEdges[4]:SetPoint("TOPRIGHT", talent, "TOPRIGHT", -30, 0)
    talent.puiEdges[4]:SetPoint("BOTTOMRIGHT", talent, "BOTTOMRIGHT", -30, 9)
  end)
end

local function StyleModernTalents()
  if not modernMode then return end
  local page = G("InspectTalentsFrame")
  local talent = G("TWTalentFrame")
  if not page or not talent then return end

  if not page.puiInspectModern then
    page.puiInspectModern = true
    U.StripStockTextures(page)
  end
  local tabs = {
    G("TWTalentFrameTab1"), G("TWTalentFrameTab2"),
    G("TWTalentFrameTab3"),
  }
  if not talent.puiInspectModern then
    talent.puiInspectModern = true
    U.CreateBackdrop(talent, {
      background = { 0.01, 0.01, 0.01, 0.72 },
      border = M.color.border,
      textureFill = true,
    })
    InsetTalentSurface(talent)
    U.StripStockTextures(G("TWTalentFrameScrollFrame"))
    U.StyleStockScrollbar(G("TWTalentFrameScrollFrameScrollBar"))

    U.StyleStockTabGroup(tabs, tonumber(talent.selectedTab) or 1)
    local i
    for i = 1, table.getn(tabs) do
      if tabs[i] then
        U.PostHookScript(tabs[i], "OnClick", LayoutModernTalentTabs)
      end
    end
    U.PostHookScript(talent, "OnShow", StyleModernTalents)
    U.PostHookGlobal("TWTalentFrame_Update", RefreshModernTalentChrome)
  end

  local selected = tonumber(talent.selectedTab) or 1
  local i
  for i = 1, table.getn(tabs) do
    if tabs[i] and tabs[i].SetActive then
      tabs[i].SetActive(i == selected)
    end
  end
  RefreshModernTalentChrome()
end

local function StyleModernInspect()
  if not modernMode then return end
  StyleModernTabs()
  StyleModernArena()
  StyleModernTalents()
end

local function StyleModel()
  U.EnableStockModelDrag(G("InspectModelFrame"), {
    name = "PandaUIInspectModelRotateCatcher",
    ticker = "inspect.model-rotate",
    leftButton = G("InspectModelRotateLeftButton"),
    rightButton = G("InspectModelRotateRightButton"),
  })
end

local function InspectDragControls()
  local controls = {}
  local close = G("InspectFrameCloseButton")
  if close then table.insert(controls, close) end

  local i
  for i = 1, table.getn(SLOTS) do
    local slot = G("Inspect" .. SLOTS[i])
    if slot then table.insert(controls, slot) end
  end
  return controls
end

local function Reapply()
  if not frame then return end
  if not keepNativeChrome then
    U.StripStockTextures(frame)
    U.StripStockTextures(G("InspectPaperDollFrame"))
    if panel then pcall(panel.Show, panel) end
    SetTextFont(G("InspectNameText"), M.fontSize.large, GOLD)
    SetTextFont(G("InspectLevelText"), M.fontSize.small, WHITE)
    SetTextFont(G("InspectGuildText"), M.fontSize.small, DIM)
  end
  RefreshTabs()
  RefreshClassLine()
  StyleSlots(keepNativeChrome)
  if modernMode then
    -- Turtle completes the optional Arena and Talent pages after OnShow.
    U.DeferOnce("inspect.modern-show", StyleModernInspect)
  end
  if modernWowMode and type(U.ModernWowDressInspect) == "function" then
    -- Turtle creates its Talent tab after the native InspectFrame OnShow
    -- returns, so dress the final tab group on the next frame.
    U.DeferOnce("inspect.modernwow-show", U.ModernWowDressInspect)
  end
end

local function BuildFrame()
  if built then return true end

  frame = G("InspectFrame")
  local update = G("InspectPaperDollItemSlotButton_Update")
  if not frame or type(update) ~= "function" or not G("InspectHeadSlot") then
    return false
  end

  keepNativeChrome = U.ThemeStyleUsesNativeChrome() and not modernWowMode

  if not keepNativeChrome then
    U.StripStockTextures(frame)
    panel = U.CreatePanel(frame, {
      name = "PandaUIInspectPanel",
      width = 100,
      height = 100,
      background = { 0.01, 0.01, 0.01, 0.78 },
    })
    panel:SetPoint("TOPLEFT", frame, "TOPLEFT", PANEL_INSET_LEFT, -10)
    panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PANEL_INSET_RIGHT, 72)
    pcall(panel.EnableMouse, panel, false)
    pcall(frame.SetHitRectInsets, frame, 10, 30, 10, 72)

    local levelOk, level = pcall(frame.GetFrameLevel, frame)
    if levelOk and tonumber(level) then pcall(panel.SetFrameLevel, panel, level) end

    local name = G("InspectNameText")
    if name then
      pcall(function()
        name:ClearAllPoints()
        name:SetPoint("TOP", panel, "TOP", 0, -10)
      end)
    end
    local levelText = G("InspectLevelText")
    local guildText = G("InspectGuildText")
    if levelText and guildText then
      pcall(function()
        guildText:ClearAllPoints()
        guildText:SetPoint("TOP", levelText, "BOTTOM", 0, -1)
      end)
    end

    U.StyleStockCloseButton(G("InspectFrameCloseButton"), panel, -6, -6)
    StyleModel()
    U.StripStockTextures(G("InspectPaperDollFrame"))
  end

  RefreshTabs()
  StyleSlots(keepNativeChrome)
  U.MakeWindowDraggable("inspect", frame, {
    headerHeight = keepNativeChrome and 40 or 76,
    headerInset = keepNativeChrome and 40 or 54,
    headerLevelOffset = 100,
    interactiveFrames = InspectDragControls(),
  })

  U.PostHookScript(frame, "OnShow", Reapply)
  U.PostHookScript(frame, "OnHide", function()
    if panel then pcall(panel.Hide, panel) end
  end)

  -- WORKING_SOURCE: UnrealPfUI hooks this fixed-argument updater and receives
  -- the refreshed slot button. Refresh the matching named slot so the shared
  -- border table is ready before Modern WoW repaints its quality glow.
  U.PostHookGlobal("InspectPaperDollItemSlotButton_Update", function(button)
    if not button or not button.GetName then return end
    local ok, name = pcall(button.GetName, button)
    if not ok or type(name) ~= "string" then return end
    local prefix = "Inspect"
    if string.sub(name, 1, string.len(prefix)) ~= prefix then return end
    StyleSlot(string.sub(name, string.len(prefix) + 1), keepNativeChrome)
    U.DeferOnce("inspect.class-line", RefreshClassLine)
    if modernWowMode and type(U.ModernWowDressInspect) == "function" then
      U.DeferOnce("inspect.modernwow-unit", U.ModernWowDressInspect)
    end
  end)

  built = true
  local shown = false
  if frame.IsShown then
    local shownOk, value = pcall(frame.IsShown, frame)
    shown = shownOk and value and true or false
  end
  if shown then
    Reapply()
  elseif panel then
    pcall(panel.Hide, panel)
  end
  if modernWowMode and type(U.ModernWowDressInspect) == "function" then
    U.ModernWowDressInspect()
  end
  if modernMode then StyleModernInspect() end
  return true
end

local function TryBuild()
  if BuildFrame() then U.UnregisterEvent("ADDON_LOADED", TryBuild) end
end

function INS:OnEnable()
  modernMode = U.GetActiveThemeStyle() == "modern"
  modernWowMode = type(U.ModernWowSurfaceEnabled) == "function" and
                  U.ModernWowSurfaceEnabled("character")
  if BuildFrame() then return end

  -- Blizzard_InspectUI may create the window after pandaUI's module phase.
  U.RegisterEvent("ADDON_LOADED", TryBuild)
end
