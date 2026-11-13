-- Loot History: a window with the recent group-loot rolls and who won them.
-- Ported from brues-code/pfUI's loothistory module (MIT, Shagu and
-- contributors), rebuilt with stock 1.12 widgets for the classic look.

local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Loot History"],
  description = T["Adds /loothistory: a window with the need, greed and pass rolls of recent group loot and who won each item. Requires ClassicAPI."],
  expansions = { ["vanilla"] = true },
  category = T["Loot"],
  enabled = true,
})

local WIDTH, HEIGHT = 340, 400
local ROW_H, ROWS = 20, 16
local PLAYER_INDENT = 22

-- rollType from C_LootHistory.GetPlayerInfo: 0 pass, 1 need, 2 greed.
local ROLL_PASS, ROLL_NEED, ROLL_GREED = 0, 1, 2
local ROLL_TEX = {
  [ROLL_NEED] = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
  [ROLL_GREED] = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
  [ROLL_PASS] = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}
local WINMARK = "Interface\\Buttons\\UI-CheckBox-Check"
local QUESTIONMARK = "Interface\\Icons\\INV_Misc_QuestionMark"

local function Supported()
  local lh = _G.C_LootHistory
  return type(lh) == "table" and type(lh.GetNumItems) == "function"
    and type(lh.GetItem) == "function" and type(lh.GetPlayerInfo) == "function"
end

-- name, quality and icon of an item link; nil while it is not cached yet.
local function ItemVisual(link)
  local name, quality, texture, _
  if _G.C_Item and type(_G.C_Item.GetItemInfo) == "function" then
    name, _, quality, _, _, _, _, _, _, texture = _G.C_Item.GetItemInfo(link)
  else
    name, _, quality, _, _, _, _, _, texture = _G.GetItemInfo(link)
  end
  return name, quality, texture
end

local function QualityColor(quality)
  if quality and GetItemQualityColor then
    local r, g, b = GetItemQualityColor(quality)
    if r then return r, g, b end
  end
  local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

local function ClassColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return .8, .8, .8
end

-- While a roll is open everyone is listed. Once decided, only players who
-- rolled and yourself stay, as in the later clients' loot history.
local function ShouldDisplayPlayer(isDone, roll, isMe)
  return isMe or (roll and roll > 0) or not isDone
end

local frame, scroll, rows, empty
local expanded = {} -- keyed on the stable rollID
local list = {}
local pendingItems

local Update

local function ToggleExpanded(rollID)
  if not rollID then return end
  expanded[rollID] = not expanded[rollID]
  Update()
end

local function BuildList()
  local lh = _G.C_LootHistory
  local n = 0

  for i = 1, lh.GetNumItems() do
    local rollID, _, numPlayers, isDone = lh.GetItem(i)
    n = n + 1
    list[n] = list[n] or {}
    list[n].item, list[n].player = i, nil

    if rollID and expanded[rollID] then
      for p = 1, numPlayers or 0 do
        local _, _, _, roll, _, isMe = lh.GetPlayerInfo(i, p)
        if ShouldDisplayPlayer(isDone, roll, isMe) then
          n = n + 1
          list[n] = list[n] or {}
          list[n].item, list[n].player = i, p
        end
      end
    end
  end

  for i = n + 1, table.getn(list) do list[i] = nil end
  return n
end

local function ShowItemRow(row, index)
  local lh = _G.C_LootHistory
  local rollID, link, numPlayers, isDone, winner = lh.GetItem(index)

  row.rollID, row.link = rollID, link
  row.player:Hide()
  row.itemrow:Show()

  local r = row.itemrow
  if numPlayers and numPlayers > 0 then
    if expanded[rollID] then
      r.toggle:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
      r.toggle:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
    else
      r.toggle:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
      r.toggle:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
    end
    r.toggle:Show()
  else
    r.toggle:Hide()
  end

  local name, quality, texture
  if link then name, quality, texture = ItemVisual(link) end
  if name then
    r.icon:SetTexture(texture or QUESTIONMARK)
    r.name:SetText(name)
    r.name:SetTextColor(QualityColor(quality))
  else
    pendingItems = true
    r.icon:SetTexture(QUESTIONMARK)
    r.name:SetText(T["Retrieving item information..."])
    r.name:SetTextColor(1, .3, .3)
  end

  -- winner summary on a decided, collapsed row
  if isDone and not expanded[rollID] then
    if winner then
      local wname, wclass, wtype, wroll = lh.GetPlayerInfo(index, winner)
      r.winicon:SetTexture(ROLL_TEX[wtype] or ROLL_TEX[ROLL_NEED])
      r.winroll:SetText(wroll and wroll > 0 and tostring(wroll) or "")
      r.winname:SetText(wname or UNKNOWN)
      r.winname:SetTextColor(ClassColor(wclass))
    else
      r.winicon:SetTexture(ROLL_TEX[ROLL_PASS])
      r.winroll:SetText("")
      r.winname:SetText(T["All players passed"])
      r.winname:SetTextColor(1, .4, .4)
    end
    r.winicon:Show()
    r.winroll:Show()
    r.winname:Show()
  else
    r.winicon:Hide()
    r.winroll:Hide()
    r.winname:Hide()
  end
end

local function ShowPlayerRow(row, index, player)
  local name, class, rollType, roll, isWinner = _G.C_LootHistory.GetPlayerInfo(index, player)

  row.rollID, row.link = nil, nil
  row.itemrow:Hide()
  row.player:Show()

  local p = row.player
  p.name:SetText(name or UNKNOWN)
  p.name:SetTextColor(ClassColor(class))

  if rollType and ROLL_TEX[rollType] then
    p.rollicon:SetTexture(ROLL_TEX[rollType])
    p.rollicon:Show()
  else
    -- not voted yet
    p.rollicon:Hide()
  end
  p.rolltext:SetText(roll and roll > 0 and tostring(roll) or "")

  if isWinner then p.winmark:Show() else p.winmark:Hide() end
end

Update = function()
  if not frame or not frame:IsShown() then return end

  pendingItems = nil
  local total = BuildList()
  FauxScrollFrame_Update(scroll, total, ROWS, ROW_H)
  local offset = FauxScrollFrame_GetOffset(scroll) or 0

  for i = 1, ROWS do
    local row = rows[i]
    local entry = list[i + offset]
    if entry then
      if entry.player then
        ShowPlayerRow(row, entry.item, entry.player)
      else
        ShowItemRow(row, entry.item)
      end
      row:Show()
    else
      row.rollID, row.link = nil, nil
      row:Hide()
    end
  end

  if total == 0 then empty:Show() else empty:Hide() end
end

local function CreateRow(parent, i)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(ROW_H)
  row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(i - 1) * ROW_H)
  row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)

  local highlight = row:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  highlight:SetBlendMode("ADD")
  highlight:SetAllPoints(row)
  highlight:SetAlpha(.5)

  -- item row parts
  local r = CreateFrame("Frame", nil, row)
  r:SetAllPoints(row)
  row.itemrow = r

  r.toggle = CreateFrame("Button", nil, r)
  r.toggle:SetWidth(14)
  r.toggle:SetHeight(14)
  r.toggle:SetPoint("LEFT", 2, 0)
  r.toggle:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
  r.toggle:SetScript("OnClick", function() ToggleExpanded(row.rollID) end)

  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetWidth(16)
  r.icon:SetHeight(16)
  r.icon:SetPoint("LEFT", 20, 0)
  r.icon:SetTexCoord(.08, .92, .08, .92)

  r.winicon = r:CreateTexture(nil, "OVERLAY")
  r.winicon:SetWidth(16)
  r.winicon:SetHeight(16)
  r.winicon:SetPoint("RIGHT", r, "RIGHT", -2, 0)

  r.winroll = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.winroll:SetPoint("RIGHT", r.winicon, "LEFT", -2, 0)

  r.winname = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.winname:SetPoint("RIGHT", r.winroll, "LEFT", -4, 0)
  r.winname:SetWidth(90)
  r.winname:SetJustifyH("RIGHT")

  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
  r.name:SetPoint("RIGHT", r, "RIGHT", -120, 0)
  r.name:SetHeight(ROW_H)
  r.name:SetJustifyH("LEFT")

  -- player row parts
  local p = CreateFrame("Frame", nil, row)
  p:SetAllPoints(row)
  row.player = p

  p.winmark = p:CreateTexture(nil, "OVERLAY")
  p.winmark:SetWidth(16)
  p.winmark:SetHeight(16)
  p.winmark:SetTexture(WINMARK)
  p.winmark:SetPoint("LEFT", PLAYER_INDENT, 0)

  p.name = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  p.name:SetPoint("LEFT", PLAYER_INDENT + 18, 0)
  p.name:SetJustifyH("LEFT")

  p.rollicon = p:CreateTexture(nil, "OVERLAY")
  p.rollicon:SetWidth(16)
  p.rollicon:SetHeight(16)
  p.rollicon:SetPoint("RIGHT", p, "RIGHT", -2, 0)

  p.rolltext = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  p.rolltext:SetPoint("RIGHT", p.rollicon, "LEFT", -3, 0)

  row:SetScript("OnClick", function() ToggleExpanded(this.rollID) end)
  row:SetScript("OnEnter", function()
    if this.link then
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(this.link)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)

  return row
end

local function CreateWindow()
  frame = CreateFrame("Frame", "ShaguTweaksLootHistory", UIParent)
  frame:SetFrameStrata("DIALOG")
  frame:SetWidth(WIDTH)
  frame:SetHeight(HEIGHT)
  frame:SetPoint("CENTER", 0, 0)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  frame:Hide()
  table.insert(UISpecialFrames, "ShaguTweaksLootHistory")

  local header = frame:CreateTexture(nil, "ARTWORK")
  header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
  header:SetWidth(256)
  header:SetHeight(64)
  header:SetPoint("TOP", 0, 12)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", header, "TOP", 0, -14)
  title:SetText(T["Loot History"])

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -5, -5)

  local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  clear:SetWidth(80)
  clear:SetHeight(22)
  clear:SetPoint("BOTTOMRIGHT", -16, 14)
  clear:SetText(T["Clear"])
  clear:SetScript("OnClick", function()
    if type(_G.C_LootHistory.Clear) == "function" then
      _G.C_LootHistory.Clear()
    end
    Update()
  end)
  if type(_G.C_LootHistory.Clear) ~= "function" then clear:Hide() end

  scroll = CreateFrame("ScrollFrame", "ShaguTweaksLootHistoryScroll", frame, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 18, -32)
  scroll:SetPoint("BOTTOMRIGHT", -40, 44)
  scroll:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(ROW_H, Update)
  end)

  rows = {}
  for i = 1, ROWS do rows[i] = CreateRow(frame, i) end

  empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  empty:SetPoint("CENTER", 0, 0)
  empty:SetText(T["No loot rolls yet."])

  frame:SetScript("OnShow", Update)

  -- Only redraw while the window is open; the history itself is kept by
  -- ClassicAPI (last 128 items, through /reload, cleared at logout).
  frame:RegisterEvent("LOOT_HISTORY_FULL_UPDATE")
  frame:RegisterEvent("LOOT_HISTORY_ROLL_COMPLETE")
  frame:RegisterEvent("LOOT_HISTORY_ROLL_CHANGED")
  frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  frame:SetScript("OnEvent", function()
    if event == "GET_ITEM_INFO_RECEIVED" and not pendingItems then return end
    Update()
  end)
end

local function Toggle()
  if not Supported() then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00ShaguTweaks:|r " .. T["Loot History requires ClassicAPI."])
    return
  end
  if not frame then CreateWindow() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end

module.enable = function(self)
  -- pfUI ships the same command; leave it alone when pfUI already owns it.
  if SlashCmdList["PFLOOTHISTORY"] then return end

  SLASH_SHAGULOOTHISTORY1 = "/loothistory"
  SlashCmdList["SHAGULOOTHISTORY"] = Toggle
  ShaguTweaks.ToggleLootHistory = Toggle
end
