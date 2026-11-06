-- EGM main window: a copy of Blizzard's AuctionFrame (1.12): fixed 832x447, six art tiles that change per tab
-- (Browse / Bid / Auction sets), portrait at 12,-8, title at the top, tabs on the bottom edge (15,11, -8 overlap).
-- Tab content frames cover the whole window, so tabs place their parts in AuctionFrame coordinates.
EGM = EGM or {}
EGM.UI = EGM.UI or {}
local UI = EGM.UI

local W, H = 832, 447
local NUM_TABS = 4
local TAB_NAMES = { "Browse", "Create Order", "My Orders", "Statistics" }
local DEFAULT_ART = { "Browse", "Auction", "Bid", "Bid" }
local TILES = { { "TopLeft", 256, 256, 0, 0 }, { "Top", 320, 256, 256, 0 }, { "TopRight", 256, 256, 576, 0 },
                { "BotLeft", 256, 256, 0, -256 }, { "Bot", 320, 256, 256, -256 }, { "BotRight", 256, 256, 576, -256 } }

local frame, tiles, tabs, title, portrait
local defs = {}
local active = 1

local function db() return EGM.DB and EGM.DB.char end

local function setArt(set)
  for i = 1, table.getn(TILES) do
    tiles[i]:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-" .. set .. "-" .. TILES[i][1])
  end
end

local function savePos()
  local c = db(); if not c or not frame then return end
  local x, y = frame:GetLeft(), frame:GetTop()
  if x and y then c.ui = c.ui or {}; c.ui.x = x; c.ui.y = y end
end

local function restorePos()
  local c = db()
  frame:ClearAllPoints()
  if c and c.ui and c.ui.x and c.ui.y then frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", c.ui.x, c.ui.y)
  else frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104) end -- where the AH opens
  frame:SetScale(EGM.Util.getScale())
end

local function build(i)
  local d = defs[i]
  if not d or d.built then return end
  d.frame = d.frame or CreateFrame("Frame", "EGMFrameTab" .. i .. "Content", frame)
  d.frame:SetAllPoints(frame)
  d.frame:Hide()
  d.built = true
  if d.build then d.build(d.frame) end
end

local function selectTab(i)
  active = i
  PanelTemplates_SetTab(frame, i)
  setArt((defs[i] and defs[i].art) or DEFAULT_ART[i])
  for k = 1, NUM_TABS do
    local d = defs[k]
    if d and d.frame then if k == i then d.frame:Show() else d.frame:Hide() end end
  end
  build(i)
  if defs[i] and defs[i].frame then defs[i].frame:Show() end
  if defs[i] and defs[i].refresh then defs[i].refresh() end
  local c = db(); if c then c.ui = c.ui or {}; c.ui.tab = i end
end

local function create()
  if frame then return frame end
  frame = CreateFrame("Frame", "EGMFrame", UIParent)
  frame:SetWidth(W); frame:SetHeight(H)
  frame:SetToplevel(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() this:StopMovingOrSizing(); savePos() end)
  frame:SetScript("OnShow", function() if PlaySound then PlaySound("AuctionWindowOpen") end end)
  frame:SetScript("OnHide", function() if PlaySound then PlaySound("AuctionWindowClose") end end)

  portrait = frame:CreateTexture("EGMFramePortrait", "BACKGROUND")
  portrait:SetWidth(58); portrait:SetHeight(58)
  portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)
  if SetPortraitTexture then SetPortraitTexture(portrait, "player") end

  tiles = {}
  for i = 1, table.getn(TILES) do
    local t = TILES[i]
    local tex = frame:CreateTexture("EGMFrame" .. t[1], "BORDER")
    tex:SetWidth(t[2]); tex:SetHeight(t[3])
    tex:SetPoint("TOPLEFT", frame, "TOPLEFT", t[4], t[5])
    tiles[i] = tex
  end

  title = frame:CreateFontString("EGMFrameTitle", "ARTWORK", "GameFontNormal")
  title:SetPoint("TOP", frame, "TOP", 0, -18)
  title:SetText("|cffd94f2bERROR|r Guild Market")

  local close = CreateFrame("Button", "EGMFrameCloseButton", frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 3, -8)

  tabs = {}
  for i = 1, NUM_TABS do
    local b = CreateFrame("Button", "EGMFrameTab" .. i, frame, "CharacterFrameTabButtonTemplate")
    b:SetID(i)
    b:SetText(TAB_NAMES[i])
    if i == 1 then b:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 15, 11)
    else b:SetPoint("TOPLEFT", tabs[i - 1], "TOPRIGHT", -8, 0) end
    b:SetScript("OnClick", function() selectTab(this:GetID()); if PlaySound then PlaySound("igCharacterInfoTab") end end)
    if PanelTemplates_TabResize then PanelTemplates_TabResize(0, b) end
    tabs[i] = b
  end
  PanelTemplates_SetNumTabs(frame, NUM_TABS)

  tinsert(UISpecialFrames, "EGMFrame")
  restorePos()
  setArt("Browse")
  frame:Hide()
  return frame
end

-- public API ------------------------------------------------------------------------------------------
-- art: "Browse" | "Bid" | "Auction" (the AH texture set the tab is laid out on); default per index
function UI.registerTab(index, buildFn, refreshFn, art)
  if type(index) ~= "number" or index < 1 or index > NUM_TABS then return end
  local old = defs[index]
  defs[index] = { build = buildFn, refresh = refreshFn, art = art or DEFAULT_ART[index], built = false, frame = old and old.frame }
  if frame and frame:IsShown() and active == index then selectTab(index) end
end

-- fromMailbox: opened by clicking the mailbox; such a window closes again with the mailbox (UI.closeFromMailbox)
local openedByMailbox = false
function UI.show(i, fromMailbox)
  create()
  if not frame:IsShown() then openedByMailbox = fromMailbox and true or false end
  local c = db()
  i = tonumber(i) or (c and c.ui and c.ui.tab) or active or 1
  if i < 1 or i > NUM_TABS then i = 1 end
  frame:Show()
  selectTab(i)
end

function UI.hide() if frame then frame:Hide() end end
-- the mailbox closed (walked away or closed it): close the window only if the mailbox opened it
function UI.closeFromMailbox()
  if openedByMailbox and frame and frame:IsShown() then frame:Hide() end
  openedByMailbox = false
end
function UI.toggle() if frame and frame:IsShown() then frame:Hide() else UI.show() end end
-- puts the main window back to its default place and the scale to 1.0 (forgets the saved position); also centers the options window
function UI.resetWindow()
  local c = db()
  if c and c.ui then c.ui.x = nil; c.ui.y = nil; c.ui.scale = nil end
  if frame then restorePos() end
  if EGM.Options and EGM.Options.applyScale then EGM.Options.applyScale() end
  if EGM.Options and EGM.Options.center then EGM.Options.center() end
end
function UI.isShown() return frame and frame:IsShown() end
function UI.active() return active end
-- save the scale and apply it live; the window keeps its top-left corner on screen
function UI.setScale(s)
  s = EGM.Util.saveScale(s)
  if frame then
    local old = frame:GetScale() or 1
    local x, y = frame:GetLeft(), frame:GetTop()
    frame:SetScale(s)
    if x and y and old > 0 then
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x * old / s, y * old / s)
      savePos()
    end
  end
  if EGM.Options and EGM.Options.applyScale then EGM.Options.applyScale() end
  return s
end

local function refresh()
  if frame and frame:IsShown() and defs[active] and defs[active].refresh then defs[active].refresh() end
end
EGM.On("STATE", refresh); EGM.On("ROSTER", refresh); EGM.On("BAGS", refresh); EGM.On("INBOX", refresh); EGM.On("SEND", refresh)
EGM.On("MAIL_SHOW", refresh); EGM.On("MAIL_CLOSED", refresh)

-- tabs that loaded before this file
if EGM.PendingTabs then
  for _, p in ipairs(EGM.PendingTabs) do UI.registerTab(p.index, p.build, p.refresh, p.art) end
  EGM.PendingTabs = {}
end
