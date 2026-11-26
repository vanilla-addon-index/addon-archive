--[[
OctoPad UI  -  use the open windows with the controller.

While at least one registered window is open (bags, map, character, spellbook,
merchant, quest / gossip, popups, game menu, ...) every button follows its
WINDOW action instead of its GAME action:

  D-pad          move the focus ring between clickable elements
  A (Confirm)    click the focused element          X  right-click
  Y              shift-click                        B  back / close
  RB / LB        next / previous tab                LT+Up/Down  scroll

Special cases
  * pop-up dialogs and drop-down menus are modal: only their buttons are reachable
    (Confirm = accept, Back = cancel)
  * the World Map is handled with the map API: D-pad Left/Right = continent,
    Up/Down = zone, Confirm = zoom to your zone, X = zoom out, Back = zoom out / close
  * the HUD buttons stay reachable, so you can pick a spell up in the spellbook
    and drop it on a HUD button using only the controller

Nothing here calls a protected function directly; clicks are delivered to the
Blizzard widgets' own click handlers.
]]

local OP = OctoPad

local ring
local ringT = 0
local pollT = 0
local lastActive = false
local prevPrio = nil
local splitKb = false

----------------------------------------------------------------------
-- Which windows count
----------------------------------------------------------------------
local WINDOWS = {
  "GameMenuFrame", "WorldMapFrame", "CharacterFrame", "SpellBookFrame", "TalentFrame",
  "QuestLogFrame", "FriendsFrame", "GossipFrame", "QuestFrame", "MerchantFrame",
  "TradeFrame", "BankFrame", "MailFrame", "SendMailFrame", "AuctionFrame", "TaxiFrame",
  "LootFrame", "ClassTrainerFrame", "CraftFrame", "TradeSkillFrame", "InspectFrame",
  "PetStableFrame", "PetitionFrame", "ItemTextFrame", "KeyBindingFrame", "OptionsFrame",
  "SoundOptionsFrame", "UIOptionsFrame", "HelpFrame", "TabardFrame", "ArenaFrame",
  "OctoPadMenu", "OctoPadIconPicker", "pfBag", "pfBank",
  "GroupLootFrame1", "GroupLootFrame2", "GroupLootFrame3", "GroupLootFrame4",   -- Need / Greed / Pass rolls
  "StackSplitFrame",
}
local MODAL_PREFIX = { "StaticPopup", "DropDownList" }

function OP.RegisterWindow(name)
  local cfg = OP.cfg
  local i
  for i = 1, table.getn(cfg.windows) do
    if cfg.windows[i] == name then return end
  end
  table.insert(cfg.windows, name)
end

local function Shown(name)
  local fr = getglobal(name)
  return fr and fr.IsVisible and fr:IsVisible()
end

-- Frames registered for this session only (unnamed frames picked with the mouse)
local sessionWins = {}
-- Frames found by the automatic bag / bank / inventory detector (pfUI bags,
-- Bagshui, Bagnon-style addons, ...). Refreshed every 0.5s by UIInit's driver.
local autoWins = {}
local scanT = 0

local AUTO_PATTERNS = { "bag", "bank", "inventory", "backpack", "keyring" }
local AUTO_EXCLUDE = { "bar", "button", "tooltip", "anchor", "dropdown", "search", "tab", "slot" }

local function HasPattern(name, list)
  local l = string.lower(name)
  local i
  for i = 1, table.getn(list) do
    if string.find(l, list[i], 1, true) then return true end
  end
  return false
end

local function KnownByName(nm)
  local i
  for i = 1, table.getn(WINDOWS) do
    if WINDOWS[i] == nm then return true end
  end
  if string.find(nm, "^ContainerFrame%d+$") then return true end
  local w = OP.cfg.windows
  for i = 1, table.getn(w) do
    if w[i] == nm then return true end
  end
  return false
end

-- Does this frame contain item slots? Buttons made from ContainerFrameItemButtonTemplate
-- have an <name>IconTexture child; otherwise fall back to "item" in the button name.
local function CountItemButtons(f, depth, count)
  if depth > 4 or count >= 3 then return count end
  local kids = { f:GetChildren() }
  local i
  for i = 1, table.getn(kids) do
    local c = kids[i]
    if c:GetObjectType() == "Button" then
      local nm = c:GetName()
      if nm and (getglobal(nm .. "IconTexture") or string.find(string.lower(nm), "item", 1, true)) then
        count = count + 1
        if count >= 3 then return count end
      end
    end
    count = CountItemButtons(c, depth + 1, count)
    if count >= 3 then return count end
  end
  return count
end

-- visible buttons inside a frame (used for addon loot-roll windows)
local function CountVisibleButtons(f, depth, count)
  if depth > 3 or count >= 2 then return count end
  local kids = { f:GetChildren() }
  local i
  for i = 1, table.getn(kids) do
    local c = kids[i]
    if c:IsVisible() then
      if c:GetObjectType() == "Button" and c:GetWidth() >= 8 then count = count + 1 end
      count = CountVisibleButtons(c, depth + 1, count)
      if count >= 2 then return count end
    end
  end
  return count
end

local ROLL_PATTERNS = { "lootroll", "rollframe", "grouploot", "loot_roll" }

local function ScanAuto()
  local found = {}
  local kids = { UIParent:GetChildren() }
  local i
  for i = 1, table.getn(kids) do
    local f = kids[i]
    local nm = f:GetName()
    if nm and f:IsVisible() and not string.find(nm, "^OctoPad") and not KnownByName(nm) then
      if HasPattern(nm, AUTO_PATTERNS) and not HasPattern(nm, AUTO_EXCLUDE) then
        if CountItemButtons(f, 0, 0) >= 3 then table.insert(found, f) end
      elseif HasPattern(nm, ROLL_PATTERNS) then
        -- another addon's loot-roll window (pfUI ...): only while it actually shows buttons
        if CountVisibleButtons(f, 0, 0) >= 2 then table.insert(found, f) end
      end
    end
  end
  autoWins = found
end

function OP.RegisterSessionWindow(frame)
  table.insert(sessionWins, frame)
end

function OP.IsWindowFrame(f)
  local nm = f.GetName and f:GetName()
  if nm and KnownByName(nm) then return true end
  local i
  for i = 1, table.getn(autoWins) do
    if autoWins[i] == f then return true end
  end
  for i = 1, table.getn(sessionWins) do
    if sessionWins[i] == f then return true end
  end
  return false
end

-- modal frames first (popups, dropdown lists)
local function ModalFrames()
  local list = {}
  local i
  if Shown("StackSplitFrame") then table.insert(list, StackSplitFrame) end
  for i = 1, 4 do
    local fr = getglobal("StaticPopup" .. i)
    if fr and fr:IsVisible() then table.insert(list, fr) end
  end
  for i = 1, 3 do
    local fr = getglobal("DropDownList" .. i)
    if fr and fr:IsVisible() then table.insert(list, fr) end
  end
  return list
end

local function WindowFrames()
  local list = {}
  local i
  for i = 1, table.getn(WINDOWS) do
    if Shown(WINDOWS[i]) then table.insert(list, getglobal(WINDOWS[i])) end
  end
  for i = 1, 13 do
    if Shown("ContainerFrame" .. i) then table.insert(list, getglobal("ContainerFrame" .. i)) end
  end
  local cfg = OP.cfg
  for i = 1, table.getn(cfg.windows) do
    if Shown(cfg.windows[i]) then table.insert(list, getglobal(cfg.windows[i])) end
  end
  for i = 1, table.getn(autoWins) do
    if autoWins[i]:IsVisible() then table.insert(list, autoWins[i]) end
  end
  for i = 1, table.getn(sessionWins) do
    if sessionWins[i]:IsVisible() then table.insert(list, sessionWins[i]) end
  end
  return list
end

-- cheap check used every 0.1-0.15s by the HUD and the binding switcher
function OP.UIActive()
  if not OP.cfg or not OP.cfg.uimode then return false end
  local i
  for i = 1, 4 do
    if Shown("StaticPopup" .. i) then return true end
  end
  for i = 1, 3 do
    if Shown("DropDownList" .. i) then return true end
  end
  for i = 1, table.getn(WINDOWS) do
    if Shown(WINDOWS[i]) then return true end
  end
  for i = 1, 13 do
    if Shown("ContainerFrame" .. i) then return true end
  end
  local w = OP.cfg.windows
  for i = 1, table.getn(w) do
    if Shown(w[i]) then return true end
  end
  for i = 1, table.getn(autoWins) do
    if autoWins[i]:IsVisible() then return true end
  end
  for i = 1, table.getn(sessionWins) do
    if sessionWins[i]:IsVisible() then return true end
  end
  return false
end

----------------------------------------------------------------------
-- Finding clickable widgets
----------------------------------------------------------------------
-- money display buttons (gold / silver / copper coins) are not controls
local function IsMoneyButton(w)
  local nm = w:GetName()
  if nm and (string.find(nm, "GoldButton", 1, true) or string.find(nm, "SilverButton", 1, true)
             or string.find(nm, "CopperButton", 1, true)) then return true end
  -- coin icon textures
  local regs = { w:GetRegions() }
  local i
  for i = 1, table.getn(regs) do
    if regs[i]:GetObjectType() == "Texture" then
      local t = regs[i]:GetTexture()
      if t and (string.find(t, "UI-GoldIcon", 1, true) or string.find(t, "UI-SilverIcon", 1, true)
                or string.find(t, "UI-CopperIcon", 1, true)) then return true end
    end
  end
  -- inside a MoneyFrame (Blizzard sets .moneyType on it)
  local f, depth = w:GetParent(), 0
  while f and depth < 4 do
    if f.moneyType ~= nil then return true end
    local pn = f.GetName and f:GetName()
    if pn and string.find(pn, "MoneyFrame", 1, true) then return true end
    f = f:GetParent()
    depth = depth + 1
  end
  return false
end

local function IsClickable(w)
  if w == ring or not w:IsVisible() then return false end
  if IsMoneyButton(w) then return false end
  local t = w:GetObjectType()
  if t ~= "Button" and t ~= "CheckButton" then return false end
  if w:GetWidth() < 8 or w:GetHeight() < 8 then return false end
  if w.IsEnabled and not w:IsEnabled() then return false end
  if not w:GetScript("OnClick") and not w:GetScript("OnMouseUp") and not w:GetScript("OnMouseDown") then return false end
  return true
end

local function Collect(f, list, depth)
  if depth > 7 or table.getn(list) > 350 then return end
  local kids = { f:GetChildren() }
  local i
  for i = 1, table.getn(kids) do
    local c = kids[i]
    if c ~= ring and c:IsVisible() then
      if IsClickable(c) then table.insert(list, c) end
      Collect(c, list, depth + 1)
    end
  end
end

-- returns windowWidgets, hudWidgets
local function Candidates()
  local win, hud = {}, {}
  local modal = ModalFrames()
  local frames = modal
  if table.getn(modal) == 0 then frames = WindowFrames() end
  local i
  for i = 1, table.getn(frames) do Collect(frames[i], win, 0) end
  -- a window with an `only` list (see OctoPadAdapters.lua): the D-pad reaches just those widgets
  if table.getn(modal) == 0 and OP.ADAPTER_ORDER then
    local a
    for a = 1, table.getn(OP.ADAPTER_ORDER) do
      local nm = OP.ADAPTER_ORDER[a]
      local ad = OP.Adapters[nm]
      if ad and ad.only and Shown(nm) then
        local only = {}
        for i = 1, table.getn(win) do
          if OP.AdapterMatch(ad.only, win[i]:GetName()) then table.insert(only, win[i]) end
        end
        if table.getn(only) > 0 then return only, hud end
      end
    end
  end
  if table.getn(modal) == 0 and OP.cfg.hud then
    for i = 1, 10 do
      local b = getglobal("OctoPadButton" .. i)
      if b and b:IsVisible() then table.insert(hud, b) end
    end
  end
  return win, hud
end

local function Center(w)
  local x, y = w:GetCenter()
  local s = w:GetEffectiveScale()
  return x * s, y * s
end

local function InList(list, w)
  local i
  for i = 1, table.getn(list) do
    if list[i] == w then return true end
  end
  return false
end

local function TopLeftMost(list)
  local best, bestScore
  local i
  for i = 1, table.getn(list) do
    local x, y = Center(list[i])
    local score = x * 0.35 - y
    if not bestScore or score < bestScore then best, bestScore = list[i], score end
  end
  return best
end

local function Pick(cur, list, dir)
  local cx, cy = Center(cur)
  local best, bestScore
  local i
  for i = 1, table.getn(list) do
    local w = list[i]
    if w ~= cur then
      local x, y = Center(w)
      local dx, dy = x - cx, y - cy
      local primary, secondary
      if dir == "RIGHT" then primary = dx; secondary = math.abs(dy)
      elseif dir == "LEFT" then primary = -dx; secondary = math.abs(dy)
      elseif dir == "UP" then primary = dy; secondary = math.abs(dx)
      else primary = -dy; secondary = math.abs(dx) end
      if primary > 2 then
        local score = primary + secondary * 2.5
        if not bestScore or score < bestScore then best, bestScore = w, score end
      end
    end
  end
  return best
end

----------------------------------------------------------------------
-- Focus ring + tooltip
----------------------------------------------------------------------
local function Hover(w, on)
  local fn = w:GetScript(on and "OnEnter" or "OnLeave")
  if fn then
    local ot = this
    this = w
    pcall(fn)
    this = ot
  end
end

local function BuildRing()
  if ring then return end
  ring = CreateFrame("Frame", "OctoPadFocusRing", UIParent)
  ring:SetFrameStrata("TOOLTIP")
  local th = OP.Theme()
  if OP.Round(ring, 0) then
    -- pfUI's rounded border, no fill of its own (the tint below is the fill)
    OP.BD(ring):SetBackdropColor(0, 0, 0, 0)
    OP.BD(ring):SetBackdropBorderColor(th.ac[1], th.ac[2], th.ac[3], 1)
  else
    ring:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 3 })
    ring:SetBackdropBorderColor(th.ac[1], th.ac[2], th.ac[3], 1)
  end
  -- conspicuous: bright border + additive glow around the widget + a light tint over it
  ring.glow = ring:CreateTexture(nil, "OVERLAY")
  ring.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  ring.glow:SetBlendMode("ADD")
  ring.glow:SetVertexColor(th.ac[1], th.ac[2], th.ac[3], 1)
  ring.glow:SetPoint("TOPLEFT", ring, "TOPLEFT", -12, 12)
  ring.glow:SetPoint("BOTTOMRIGHT", ring, "BOTTOMRIGHT", 12, -12)
  ring.tint = ring:CreateTexture(nil, "ARTWORK")
  ring.tint:SetTexture("Interface\\Buttons\\WHITE8X8")
  ring.tint:SetBlendMode("ADD")
  ring.tint:SetVertexColor(th.ac[1], th.ac[2], th.ac[3], .16)
  ring.tint:SetAllPoints(ring)
  ring:EnableMouse(false)
  ring:Hide()
  ring:SetScript("OnUpdate", function()
    ringT = ringT + arg1
    this:SetAlpha(.8 + .2 * math.sin(ringT * 6))
  end)
end

-- Quest reward choices are ranked by value: best = gold, second = silver, the rest = copper.
-- The value is the vendor sell price when an addon provides GetSellValue, otherwise quality and level.
local RANK_COLORS = { { 1, .82, .1 }, { .82, .84, .9 }, { .85, .5, .25 } }
local function ChoiceValue(i)
  local link = GetQuestItemLink and GetQuestItemLink("choice", i)
  if not link then return 0 end
  local _, _, id = string.find(link, "item:(%d+)")
  if GetSellValue and id then
    local ok, v = pcall(GetSellValue, tonumber(id))
    if ok and v and v > 0 then return v end
  end
  local _, _, q, minLevel, _, _, _, equip = GetItemInfo(id and ("item:" .. id) or link)
  return (q or 1) * 1000 + (minLevel or 0) * 10 + ((equip and equip ~= "") and 5 or 0)
end

local function QuestRankColor(w)
  if not w or w.type ~= "choice" or not GetNumQuestChoices then return nil end
  local n = GetNumQuestChoices() or 0
  if n < 2 then return nil end
  local id = w:GetID()
  if not id or id < 1 or id > n then return nil end
  local mine = ChoiceValue(id)
  local better, worse, i = 0, 0, 1
  local seen = {}
  for i = 1, n do
    local v = ChoiceValue(i)
    if v > mine and not seen[v] then seen[v] = true; better = better + 1 end
  end
  local c = RANK_COLORS[better + 1] or RANK_COLORS[3]
  return c[1], c[2], c[3]
end

local function RingColor(w)
  local th = OP.Theme()
  local r, g, b = QuestRankColor(w)
  if not r then r, g, b = th.ac[1], th.ac[2], th.ac[3] end
  if OP.BD and OP.BD(ring) then OP.BD(ring):SetBackdropBorderColor(r, g, b, 1)
  else ring:SetBackdropBorderColor(r, g, b, 1) end
  ring.glow:SetVertexColor(r, g, b, 1)
  ring.tint:SetVertexColor(r, g, b, .16)
end

local function SetFocus(w, auto)
  BuildRing()
  if OP.focus and OP.focus ~= w then Hover(OP.focus, false) end
  OP.focus = w
  if auto then
    OP.focusAuto = true
    OP.autoUntil = GetTime() + 1.2
  else
    OP.focusAuto = false
  end
  if not w then
    ring:Hide()
    return
  end
  ring:ClearAllPoints()
  ring:SetScale(w:GetEffectiveScale() / UIParent:GetEffectiveScale())
  ring:SetPoint("TOPLEFT", w, "TOPLEFT", -4, 4)
  ring:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", 4, -4)
  -- small things (bag slots, icons) get the intense outer glow plus the tint; larger interface
  -- elements get the border and the tint that covers the whole ring, without the off-sized outer glow
  local big = math.max(w:GetWidth() or 0, w:GetHeight() or 0) > 64
  ring.tint:Show()
  if big then
    ring.glow:Hide()
  else
    ring.glow:Show()
    ring.glow:SetAlpha(1)
  end
  if w then RingColor(w) end
  ring:Show()
  Hover(w, true)
end

local function ClearFocus()
  -- fire OnLeave even when the window is already gone, otherwise addons that track
  -- their own hover state (Bagshui's menu button, ...) keep their tooltip alive
  if OP.focus then Hover(OP.focus, false) end
  OP.focus = nil
  if ring then ring:Hide() end
  GameTooltip:Hide()
  OP.tipHideAt = GetTime() + 0.3      -- once more, in case something re-shows it
end
OP.UIClearFocus = ClearFocus

local function FocusValid(list)
  local w = OP.focus
  return w and w:IsVisible() and InList(list, w)
end

----------------------------------------------------------------------
-- Smart default focus: the most likely input for the window that just opened
----------------------------------------------------------------------
-- Window-specific rules (most likely buttons, lists, what follows a pick) live in OctoPadAdapters.lua.
local function ClickableByName(nm)
  local w = getglobal(nm)
  if w and w.IsVisible and IsClickable(w) then return w end
  return nil
end

-- quest turn-in with several reward choices and none picked yet: pick a reward first
local function QuestChoiceNeeded()
  if not Shown("QuestFrameRewardPanel") then return nil end
  local n = 0
  if GetNumQuestChoices then n = GetNumQuestChoices() or 0 end
  local chosen = 0
  if QuestFrameRewardPanel and QuestFrameRewardPanel.itemChoice then chosen = QuestFrameRewardPanel.itemChoice end
  if n > 1 and chosen == 0 then
    local i
    for i = 1, 10 do
      local b = getglobal("QuestRewardItem" .. i)
      if b and b:IsVisible() and b.type == "choice" and IsClickable(b) then return b end
    end
  end
  return nil
end

-- generic fallback for windows without a named entry: look at button labels
local function TextPreferred(win)
  local prefs = { ACCEPT or "Accept", COMPLETE_QUEST or "Complete Quest", CONTINUE or "Continue", YES or "Yes", OKAY or "Okay" }
  local p, i
  for p = 1, table.getn(prefs) do
    for i = 1, table.getn(win) do
      local w = win[i]
      if w.GetText and w:GetText() == prefs[p] then return w end
    end
  end
  return nil
end

-- Bag windows: land on the Hearthstone (not on the window's own menu button).
local HEARTH_ID = "item:6948"
local function IsHearthstone(w)
  -- 1) container link of the slot
  local par = w:GetParent()
  if par and par.GetID and GetContainerItemLink and w.GetID then
    local bag, slot = par:GetID(), w:GetID()
    if bag and slot and slot > 0 then
      local ok, link = pcall(GetContainerItemLink, bag, slot)
      if ok and link and string.find(link, HEARTH_ID, 1, true) then return true end
    end
  end
  -- 2) the icon texture
  local nm = w:GetName()
  local ic = nm and getglobal(nm .. "IconTexture")
  if ic and ic.GetTexture then
    local t = ic:GetTexture()
    if t and string.find(t, "INV_Misc_Rune_01", 1, true) then return true end
  end
  local regs = { w:GetRegions() }
  local i
  for i = 1, table.getn(regs) do
    if regs[i]:GetObjectType() == "Texture" then
      local t = regs[i]:GetTexture()
      if t and string.find(t, "INV_Misc_Rune_01", 1, true) then return true end
    end
  end
  return false
end

local function HearthstoneIn(win)
  local i
  for i = 1, table.getn(win) do
    if IsHearthstone(win[i]) then return win[i] end
  end
  return nil
end

-- best visible list entry (prefix1 .. prefixN) by score(id); ties keep the first
local function ListButton(prefix, count, score)
  local best, bestS = nil, 0
  local i
  for i = 1, count do
    local b = getglobal(prefix .. i)
    if b and b:IsVisible() and IsClickable(b) and b.GetID then
      local s = score(b:GetID())
      if s and s > bestS then best, bestS = b, s end
    end
  end
  return best
end

-- helpers handed to the window adapters (OctoPadAdapters.lua)
OP.UIH = {
  ClickableByName = ClickableByName, IsClickable = IsClickable, Shown = Shown,
  ListButton = ListButton, QuestChoiceNeeded = QuestChoiceNeeded,
}

-- win = candidate widgets of the open windows (optional; enables the label fallback)
local function Preferred(win)
  local i
  -- pop-up dialogs: the accept button
  for i = 1, 4 do
    if Shown("StaticPopup" .. i) then
      local b = ClickableByName("StaticPopup" .. i .. "Button1")
      if b then return b end
    end
  end
  -- stack split window: land on Okay
  if Shown("StackSplitFrame") then
    local b = ClickableByName("StackSplitOkayButton")
    if b then return b end
  end
  if table.getn(ModalFrames()) > 0 then return nil end
  -- loot roll (Need / Greed / Pass): land on Need, or Greed when Need is not allowed
  for i = 1, 4 do
    if Shown("GroupLootFrame" .. i) then
      local b = ClickableByName("GroupLootFrame" .. i .. "NeedButton") or ClickableByName("GroupLootFrame" .. i .. "GreedButton")
      if b then return b end
    end
  end
  -- windows with an adapter (OctoPadAdapters.lua), in priority order
  local order = OP.ADAPTER_ORDER or {}
  for i = 1, table.getn(order) do
    local nm = order[i]
    local ad = OP.Adapters[nm]
    if ad and Shown(nm) then
      if ad.preferred then
        local p = ad.preferred(OP.UIH)
        if p then return p end
      end
      local list = ad.buttons or {}
      local k
      for k = 1, table.getn(list) do
        local b = ClickableByName(list[k])
        if b then return b end
      end
    end
  end
  if not win then win = Candidates() end
  local h = HearthstoneIn(win)
  if h then return h end
  return TextPreferred(win)
end

local function EnsureFocus()
  local win, hud = Candidates()
  local all = {}
  local i
  for i = 1, table.getn(win) do table.insert(all, win[i]) end
  for i = 1, table.getn(hud) do table.insert(all, hud[i]) end
  if FocusValid(all) then return OP.focus, all, true end
  local first = nil
  if OP.cfg.smartfocus then first = Preferred(win) end
  if not first then first = TopLeftMost(win) end
  if not first then first = TopLeftMost(hud) end
  if first then SetFocus(first, true) end
  return first, all, false
end

----------------------------------------------------------------------
-- World map special handling
----------------------------------------------------------------------
local function MapOnly()
  if not Shown("WorldMapFrame") then return false end
  if table.getn(ModalFrames()) > 0 then return false end
  return table.getn(WindowFrames()) == 1
end

local function MapZoomedIn()
  local c = GetCurrentMapContinent and GetCurrentMapContinent() or 0
  return c and c > 0
end

local function MapNav(dir)
  if not GetCurrentMapContinent or not SetMapZoom then return end
  local c = GetCurrentMapContinent()
  local z = GetCurrentMapZone()
  if dir == "LEFT" or dir == "RIGHT" then
    local n = table.getn({ GetMapContinents() })
    if n < 1 then return end
    local nc = c
    if c < 1 then
      if dir == "RIGHT" then nc = 1 else nc = n end
    elseif dir == "RIGHT" then
      nc = c + 1
      if nc > n then nc = 1 end
    else
      nc = c - 1
      if nc < 1 then nc = n end
    end
    SetMapZoom(nc)
  else
    if c < 1 then return end
    local zones = { GetMapZones(c) }
    local n = table.getn(zones)
    if n < 1 then return end
    local nz = z
    if dir == "DOWN" then nz = z + 1 else nz = z - 1 end
    if nz < 1 then nz = n elseif nz > n then nz = 1 end
    SetMapZoom(c, nz)
  end
end

local function MapZoomOut()
  if WorldMapZoomOutButton_OnClick then
    WorldMapZoomOutButton_OnClick()
    return true
  end
  return false
end

----------------------------------------------------------------------
-- Actions
----------------------------------------------------------------------
-- Stack split window: driven directly (no focus ring needed)
local function SplitActive()
  local i
  for i = 1, 4 do
    if Shown("StaticPopup" .. i) then return false end
  end
  return Shown("StackSplitFrame")
end

local function SplitClick(name, times)
  local b = getglobal(name)
  if not b or not b:IsVisible() then return end
  local i
  for i = 1, times do b:Click() end
end

local function Nav(dir)
  if MapOnly() then MapNav(dir) return end
  -- stack split: Left / Right = -1 / +1, Down / Up = -5 / +5
  if SplitActive() then
    if dir == "LEFT" then SplitClick("StackSplitLeftButton", 1)
    elseif dir == "RIGHT" then SplitClick("StackSplitRightButton", 1)
    elseif dir == "DOWN" then SplitClick("StackSplitLeftButton", 5)
    else SplitClick("StackSplitRightButton", 5) end
    return
  end
  local cur, all, was = EnsureFocus()
  if not cur or not was then return end        -- first press only places the focus ring
  OP.focusAuto = false
  local best = Pick(cur, all, dir)
  if best then SetFocus(best) end
end

local function ClickFocus(button, shift)
  local w, _, was = EnsureFocus()
  if not w or not was then return end          -- first press only places the focus ring
  OP.focusAuto = false
  if button == "LeftButton" and not shift then
    local nm = w:GetName()
    -- after picking an entry (quest reward, trainer skill, recipe, auction, mail ...), jump to the button that acts on it
    local adv = OP.AdapterAdvance and OP.AdapterAdvance(nm)
    if adv then
      OP.advanceAt = GetTime() + 0.15
      OP.advanceTo = adv[2]
    end
    w:Click()
    return
  end
  local oldShift = IsShiftKeyDown
  if shift then IsShiftKeyDown = function() return true end end
  local fn = w:GetScript("OnClick")
  if fn then
    local ot, a1, a2 = this, arg1, arg2
    this = w
    arg1 = button
    arg2 = nil
    pcall(fn)
    this, arg1, arg2 = ot, a1, a2
  else
    w:Click()
  end
  IsShiftKeyDown = oldShift
end

local function Confirm()
  if SplitActive() then
    local b = getglobal("StackSplitOkayButton")
    if b and b:IsVisible() then b:Click() end
    return
  end
  if MapOnly() then
    if SetMapToCurrentZone then SetMapToCurrentZone() end
    return
  end
  ClickFocus("LeftButton", false)
end

local function Alt()
  if MapOnly() then MapZoomOut() return end
  ClickFocus("RightButton", false)
end

local function ShiftClick()
  if MapOnly() then return end
  ClickFocus("LeftButton", true)
end

local function Back()
  if CursorHasItem and CursorHasItem() then ClearCursor() return end
  if CursorHasSpell and CursorHasSpell() then ClearCursor() return end
  if CursorHasMacro and CursorHasMacro() then ClearCursor() return end

  local i
  for i = 1, 4 do
    local pop = getglobal("StaticPopup" .. i)
    if pop and pop:IsVisible() then
      local b2 = getglobal("StaticPopup" .. i .. "Button2")
      local b1 = getglobal("StaticPopup" .. i .. "Button1")
      if b2 and b2:IsVisible() then b2:Click() elseif b1 then b1:Click() end
      return
    end
  end
  if SplitActive() then
    local c = getglobal("StackSplitCancelButton")
    if c and c:IsVisible() then c:Click() else StackSplitFrame:Hide() end
    return
  end
  if table.getn(ModalFrames()) > 0 then
    if CloseDropDownMenus then CloseDropDownMenus() end
    return
  end
  if MapOnly() and MapZoomedIn() and MapZoomOut() then return end

  local closed = false
  if CloseSpecialWindows then closed = CloseSpecialWindows() or closed end
  if CloseWindows then closed = CloseWindows() or closed end
  if not closed then
    local wins = WindowFrames()
    for i = 1, table.getn(wins) do wins[i]:Hide() end
  end
  ClearFocus()
end

-- tabs: frames named <Prefix>Tab<N> or <Prefix>TabButton<N>
local function FindTabs(root)
  local groups = {}
  local function walk(f, depth)
    if depth > 6 then return end
    local kids = { f:GetChildren() }
    local i
    for i = 1, table.getn(kids) do
      local c = kids[i]
      if c:IsVisible() then
        local nm = c:GetName()
        if nm then
          local _, _, prefix, num = string.find(nm, "^(.-)Tab(%d+)$")
          if not prefix then _, _, prefix, num = string.find(nm, "^(.-)TabButton(%d+)$") end
          if prefix and c:GetObjectType() == "Button" then
            groups[prefix] = groups[prefix] or {}
            groups[prefix][tonumber(num)] = c
          end
        end
        walk(c, depth + 1)
      end
    end
  end
  walk(root, 0)
  local best, bestN = nil, 1
  local prefix, tabs
  for prefix, tabs in pairs(groups) do
    local n = 0
    local k, v
    for k, v in pairs(tabs) do n = n + 1 end
    if n > bestN then best, bestN = tabs, n end
  end
  if not best then return nil end
  local out = {}
  local idx
  for idx = 1, 12 do
    if best[idx] then table.insert(out, best[idx]) end
  end
  return out
end

local function RootOf(w)
  local f = w
  while f do
    if OP.IsWindowFrame(f) then return f end
    f = f:GetParent()
  end
  return nil
end

local function Tab(dir)
  local w = OP.focus
  local root = w and RootOf(w)
  if not root then
    local wins = WindowFrames()
    root = wins[1]
  end
  if not root then return end
  if root.opTabFn then          -- a window that switches its own pages (OctoPad's menu)
    root.opTabFn(dir)
    return
  end
  local tabs = FindTabs(root)
  if not tabs or table.getn(tabs) < 2 then return end
  local cur, i = 1
  for i = 1, table.getn(tabs) do
    if not tabs[i]:IsEnabled() then cur = i end     -- the selected tab is disabled
  end
  cur = cur + dir
  if cur < 1 then cur = table.getn(tabs) elseif cur > table.getn(tabs) then cur = 1 end
  tabs[cur]:Click()
  ClearFocus()
end

local function FindScroll(w)
  local f = w
  while f do
    if f.GetObjectType and f:GetObjectType() == "ScrollFrame" then return f end
    if f.GetScript and f:GetScript("OnMouseWheel") then return f end
    f = f:GetParent()
  end
  return nil
end

local function DescendScroll(root, depth)
  if depth > 6 then return nil end
  local kids = { root:GetChildren() }
  local i
  for i = 1, table.getn(kids) do
    local c = kids[i]
    if c:IsVisible() then
      if c:GetObjectType() == "ScrollFrame" then return c end
      local r = DescendScroll(c, depth + 1)
      if r then return r end
    end
  end
  return nil
end

local function DescendAll(root, list, depth)
  if depth > 7 then return end
  local kids = { root:GetChildren() }
  local i
  for i = 1, table.getn(kids) do
    local c = kids[i]
    if c:IsVisible() then
      if c:GetObjectType() == "ScrollFrame" then table.insert(list, c) end
      DescendAll(c, list, depth + 1)
    end
  end
end

-- the scroll frame to move: one that really has something to scroll, in the focused window first
local function ScrollTarget()
  local f = OP.focus and FindScroll(OP.focus)
  if f and f.GetVerticalScrollRange and (f:GetVerticalScrollRange() or 0) > 0 then return f end
  local frames = {}
  local root = OP.focus and RootOf(OP.focus)
  if root then table.insert(frames, root) end
  local wins = WindowFrames()
  local i
  for i = 1, table.getn(wins) do
    if wins[i] ~= root then table.insert(frames, wins[i]) end
  end
  local fallback
  for i = 1, table.getn(frames) do
    local list = {}
    DescendAll(frames[i], list, 0)
    local j
    for j = 1, table.getn(list) do
      if not fallback then fallback = list[j] end
      if list[j].GetVerticalScrollRange and (list[j]:GetVerticalScrollRange() or 0) > 0 then return list[j] end
    end
  end
  return fallback
end

local function Scroll(dir)
  local sf = ScrollTarget()
  if not sf then return end
  local nm = sf:GetName()
  local sb = nm and getglobal(nm .. "ScrollBar")
  local step = math.max(30, (sf:GetHeight() or 100) * 0.5)
  if sb and sb.GetValue and sb.SetValue then
    local mn, mx = sb:GetMinMaxValues()
    local v = sb:GetValue() - dir * step
    if v < mn then v = mn elseif v > mx then v = mx end
    sb:SetValue(v)
  elseif sf.GetVerticalScroll then
    local cur = sf:GetVerticalScroll()
    local max = sf:GetVerticalScrollRange()
    local nv = cur - dir * step
    if nv < 0 then nv = 0 elseif nv > max then nv = max end
    sf:SetVerticalScroll(nv)
  else
    local fn = sf:GetScript("OnMouseWheel")
    if fn then
      local ot, a1 = this, arg1
      this = sf
      arg1 = dir
      pcall(fn)
      this, arg1 = ot, a1
    end
  end
end

----------------------------------------------------------------------
-- Destroy the focused bag item (pick up, confirm, delete)
----------------------------------------------------------------------
StaticPopupDialogs["OCTOPAD_DESTROY"] = {
  text = "Destroy %s?\nThis cannot be undone.",
  button1 = "Destroy",
  button2 = "Cancel",
  OnAccept = function()
    if CursorHasItem and CursorHasItem() then DeleteCursorItem() end
  end,
  OnCancel = function()
    if ClearCursor then ClearCursor() end
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  showAlert = 1,
}


local BAGISH = { "bag", "bank", "inventory", "backpack", "container", "keyring" }
-- bag / slot / link of a Blizzard-style item button (nil when it is not one)
local function BagSlotOf(w)
  -- only inside a bag-like window: any other button with a small parent / own ID (the game menu, ...)
  -- would otherwise be read as backpack slot N
  local root = RootOf(w)
  local rn = root and root.GetName and root:GetName()
  if not rn or not HasPattern(rn, BAGISH) then return nil end
  local par = w:GetParent()
  if par and par.GetID and GetContainerItemLink and w.GetID then
    local bag, slot = par:GetID(), w:GetID()
    if bag and slot and slot > 0 then
      local ok, link = pcall(GetContainerItemLink, bag, slot)
      if ok and link then return bag, slot, link end
    end
  end
  return nil
end

-- Is this widget an item slot in a bag / bank window?
local function ItemFocus(w)
  if not w or not w:IsVisible() then return false end
  if BagSlotOf(w) then return true end
  local root = RootOf(w)
  local rn = root and root.GetName and root:GetName()
  if not rn or not HasPattern(rn, BAGISH) then return false end
  local nm = w:GetName()
  if nm and getglobal(nm .. "IconTexture") then return true end
  local regs = { w:GetRegions() }
  local i
  for i = 1, table.getn(regs) do
    if regs[i]:GetObjectType() == "Texture" then
      local t = regs[i]:GetTexture()
      if t and string.find(t, "Interface\\Icons\\", 1, true) then return true end
    end
  end
  return false
end

local function Destroy()
  if CursorHasItem and CursorHasItem() then
    -- already holding an item: ask
    StaticPopup_Show("OCTOPAD_DESTROY", OP.destroyName or "this item")
    return
  end
  local w = OP.focus
  if not w or not ItemFocus(w) then
    OP.Print("Move the focus onto an item in a bag first, then press Destroy.")
    return
  end
  OP.destroyName = "this item"
  local bag, slot, link = BagSlotOf(w)
  if link then
    -- pick it up through the API: LT is the Shift key, and Shift-click would split / link instead
    local _, _, nm = string.find(link, "%[(.-)%]")
    if nm then OP.destroyName = nm end
    PickupContainerItem(bag, slot)
  else
    if GameTooltip:IsVisible() and GameTooltipTextLeft1 then
      local t = GameTooltipTextLeft1:GetText()
      if t and t ~= "" then OP.destroyName = t end
    end
    -- other bag addons: click with the modifier keys reported as released
    local os, oc, oa = IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown
    IsShiftKeyDown = function() return nil end
    IsControlKeyDown = function() return nil end
    IsAltKeyDown = function() return nil end
    local fn = w:GetScript("OnClick")
    if fn then
      local ot, a1 = this, arg1
      this = w
      arg1 = "LeftButton"
      pcall(fn)
      this, arg1 = ot, a1
    else
      w:Click()
    end
    IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown = os, oc, oa
  end
  OP.destroyAt = GetTime() + 0.2
end

local ROLE_FN = {
  UI_DESTROY = Destroy,
  UI_CONFIRM = Confirm,
  UI_ALT = Alt,
  UI_SHIFT = ShiftClick,
  UI_BACK = Back,
  UI_UP = function() Nav("UP") end,
  UI_DOWN = function() Nav("DOWN") end,
  UI_LEFT = function() Nav("LEFT") end,
  UI_RIGHT = function() Nav("RIGHT") end,
  UI_TAB_NEXT = function() Tab(1) end,
  UI_TAB_PREV = function() Tab(-1) end,
  UI_SCROLL_UP = function() Scroll(1) end,
  UI_SCROLL_DOWN = function() Scroll(-1) end,
}

function OP.UIRun(role)
  local fn = ROLE_FN[role]
  if fn then fn() end
end

----------------------------------------------------------------------
-- Keep the focus ring in sync with the open windows
----------------------------------------------------------------------
local markT = 0
function OP.UIInit()
  local drv = CreateFrame("Frame", "OctoPadUIDriver", UIParent)
  ScanAuto()
  drv:SetScript("OnUpdate", function()
    scanT = scanT + arg1
    if scanT >= 0.5 then
      scanT = 0
      ScanAuto()
    end
    if OP.captureAt and GetTime() >= OP.captureAt then
      OP.captureAt = nil
      OP.RegisterWindowUnderMouse()
    end
    if OP.destroyAt and GetTime() >= OP.destroyAt then
      OP.destroyAt = nil
      if CursorHasItem and CursorHasItem() then
        StaticPopup_Show("OCTOPAD_DESTROY", OP.destroyName or "this item")
      else
        OP.Print("Nothing was picked up (the slot is empty or the item is locked).")
      end
    end
    markT = markT + arg1
    if markT >= 0.3 then
      markT = 0
      local i
      for i = 1, 10 do
        local b = getglobal("QuestRewardItem" .. i)
        if b then
          local r, g, bl
          if b:IsVisible() then r, g, bl = QuestRankColor(b) end
          if r then
            if not b.opMark then
              b.opMark = CreateFrame("Frame", nil, b)
              b.opMark:SetAllPoints(b)
              b.opMark:SetFrameLevel(b:GetFrameLevel() + 3)
              b.opMark:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
              b.opMark:EnableMouse(false)
            end
            b.opMark:SetBackdropBorderColor(r, g, bl, .9)
            b.opMark:Show()
          elseif b.opMark then
            b.opMark:Hide()
          end
        end
      end
    end
    if OP.tipHideAt and GetTime() >= OP.tipHideAt then
      OP.tipHideAt = nil
      if not OP.UIActive() and not OP.focus then GameTooltip:Hide() end
    end
    pollT = pollT + arg1
    if pollT < 0.12 then return end
    pollT = 0
    local active = OP.UIActive()
    -- a quest / gossip / trade ... window that opens while another window (a bag) already has the
    -- focus: move the focus to its most likely button
    local prio = {}
    local pi
    local order = OP.ADAPTER_ORDER or {}
    for pi = 1, table.getn(order) do
      if Shown(order[pi]) then prio[order[pi]] = true end
    end
    for pi = 1, 4 do
      if Shown("GroupLootFrame" .. pi) then prio["GroupLootFrame" .. pi] = true end
    end
    local opened = false
    local pk
    for pk in pairs(prio) do
      if not (prevPrio and prevPrio[pk]) then opened = true end
    end
    prevPrio = prio
    if opened and active and OP.cfg.smartfocus then
      local p = Preferred()
      if p then SetFocus(p, true) end
    end
    -- the split window grabs the keyboard (digits = amount): free it so the pad keys 1-0 reach OctoPad
    if StackSplitFrame and StackSplitFrame.EnableKeyboard then
      if Shown("StackSplitFrame") and active then
        if not splitKb then
          pcall(StackSplitFrame.EnableKeyboard, StackSplitFrame, false)
          splitKb = true
        end
      elseif splitKb then
        pcall(StackSplitFrame.EnableKeyboard, StackSplitFrame, true)
        splitKb = false
      end
    end
    if OP.advanceAt and GetTime() >= OP.advanceAt then
      OP.advanceAt = nil
      local targets = OP.advanceTo
      OP.advanceTo = nil
      if OP.cfg.smartfocus then
        local p
        if targets then
          local k
          for k = 1, table.getn(targets) do
            p = ClickableByName(targets[k])
            if p then break end
          end
        else
          p = Preferred()
        end
        if p then SetFocus(p, true) end              -- nothing usable (e.g. a skill you can't learn yet): stay put
      end
    end
    if active then
      if not (OP.focus and OP.focus:IsVisible()) then
        if not MapOnly() then EnsureFocus() end
      elseif OP.cfg.smartfocus and OP.focusAuto and GetTime() < (OP.autoUntil or 0) and not MapOnly() then
        -- the window may still be building its panels: keep tracking the best default
        local p = Preferred()
        if p and p ~= OP.focus then SetFocus(p, true) end
      end
    elseif lastActive or OP.focus then
      ClearFocus()
    end
    if MapOnly() and OP.focus then ClearFocus() end
    lastActive = active
  end)
end

----------------------------------------------------------------------
-- Registering windows that were not detected (custom bag / inventory addons)
----------------------------------------------------------------------
function OP.RegisterWindowUnderMouse()
  local f = GetMouseFocus and GetMouseFocus()
  if not f then
    OP.Print("No frame under the mouse.")
    return
  end
  while f:GetParent() and f:GetParent() ~= UIParent do f = f:GetParent() end
  if f == UIParent or f == WorldFrame then
    OP.Print("Hover the window you want to add (not the bare screen), then try again.")
    return
  end
  local nm = f:GetName()
  if nm then
    OP.RegisterWindow(nm)
    OP.Print("Added '" .. nm .. "' to the navigable windows (saved).")
  else
    OP.RegisterSessionWindow(f)
    OP.Print("That window has no global name, so it is registered for this session only.")
  end
end

function OP.CaptureWindowIn(sec)
  OP.captureAt = GetTime() + sec
  OP.Print("Hover the bag / window you want to add - capturing in " .. sec .. " seconds ...")
end

-- diagnostic: which windows does OctoPad currently recognise?
function OP.ListWindows()
  local modal = ModalFrames()
  local wins = WindowFrames()
  if table.getn(modal) + table.getn(wins) == 0 then
    OP.Print("No navigable window is open. Open your bag, then run /opad windows again.")
    OP.Print("If it still shows nothing, hover the bag and use /opad window mouse.")
    return
  end
  local i
  for i = 1, table.getn(modal) do
    local l = {}
    Collect(modal[i], l, 0)
    OP.Print("modal: " .. tostring(modal[i]:GetName()) .. "  (" .. table.getn(l) .. " clickable)")
  end
  for i = 1, table.getn(wins) do
    local l = {}
    Collect(wins[i], l, 0)
    local how = "built-in"
    if not KnownByName(wins[i]:GetName() or "") then how = "auto-detected" end
    OP.Print("window: " .. tostring(wins[i]:GetName()) .. "  (" .. table.getn(l) .. " clickable, " .. how .. ")")
  end
end

-- for the hint bar: label for the Confirm button and whether the focused window has tabs
function OP.UIFocusInfo()
  local label = "Select"
  local isItem = ItemFocus(OP.focus) and true or false
  local w = OP.focus
  if w and w:IsVisible() and w.GetText then
    local t = w:GetText()
    if type(t) == "string" and t ~= "" and string.len(t) <= 22 then label = t end
  end
  local root = w and RootOf(w)
  if not root then
    local wins = WindowFrames()
    root = wins[1]
  end
  local tabs = root and FindTabs(root)
  if root and root.opTabFn then return label, true, isItem end
  return label, (tabs and table.getn(tabs) >= 2) and true or false, isItem
end
