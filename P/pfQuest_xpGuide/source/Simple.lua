-- The tips box and the right-click skip menu.
--
-- The tips box ("pfQuest xpGuide says") sits under the guide window and shows what Adapt.lua has to say: questions with
-- buttons first, then the newest tips.

local ER = pfQuest_xpGuide
local GOLD, GREY, WHITE, GREEN, END = ER.GOLD, ER.GREY, ER.WHITE, ER.GREEN, ER.END

local TP = { list = {}, rows = {} }  -- the tips box
local TIPS_SHOWN = 3
local TIP_BUTTONS = 4   -- buttons one tip can have (they wrap onto a second row when they do not fit)
local TipsFill

local function Say(msg)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99xpGuide:|r " .. msg) end
end

local function Plain(text)
  text = string.gsub(text or "", "|c%x%x%x%x%x%x%x%x", "")
  return (string.gsub(text, "|r", ""))
end

local function Backdrop(f, alpha)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0.03, 0.03, 0.05, alpha or 0.9)
  f:SetBackdropBorderColor(0.55, 0.55, 0.6, 1)
  if ER.Skin then ER.Skin.Window(f, alpha) end
end

local function Credit(parent)
  local credit = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  credit:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 7)
  credit:SetText(GREY .. "pfQuest xpGuide   v" .. ER.VERSION .. END)
  return credit
end

local function Tip(widget, fn)
  widget:SetScript("OnEnter", function()
    local title, body, hint = fn(this)
    if not title then return end
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText(title)
    if body then GameTooltip:AddLine(body, 1, 1, 1, 1) end
    if hint then GameTooltip:AddLine(hint, 0.6, 0.6, 0.6, 1) end
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A quest level's colour against yours, the way the quest log colours it: red, orange, yellow, green, grey.
function ER.LevelColour(level)
  local me = UnitLevel("player") or 1
  if not level or level <= 0 then return WHITE end
  local d = level - me
  if d >= 5 then return "|cffff1a1a" end
  if d >= 3 then return "|cffff8040" end
  if d >= -2 then return "|cffffff00" end
  if level > ER.Steps.GreyLevel(me) then return "|cff40c040" end
  return "|cff808080"
end

------------------------------------------------------------------------------------------------------
-- The right-click menu: skip one quest
------------------------------------------------------------------------------------------------------

local SK = {}
local SK_W = 190

local function SkipBuild()
  local f = CreateFrame("Frame", "pfQuest_xpGuideSkipMenu", UIParent)
  SK.frame = f
  f:SetWidth(SK_W)
  f:SetHeight(70)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  Backdrop(f, 0.97)
  f:Hide()
  table.insert(UISpecialFrames, "pfQuest_xpGuideSkipMenu")
  SK.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  SK.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -9)
  SK.title:SetJustifyH("LEFT")
  SK.note = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  SK.note:SetJustifyH("LEFT")
  if ER.ApplyFont then
    ER.ApplyFont(SK.title, 0)
    ER.ApplyFont(SK.note, -1)
  end
  SK.skip = CreateFrame("Button", "pfQuest_xpGuideSkipMenuSkip", f, "UIPanelButtonTemplate")
  SK.skip:SetWidth(90)
  SK.skip:SetHeight(20)
  SK.skip:SetText("Skip quest")
  SK.skip:SetScript("OnClick", function()
    f:Hide()
    if ER.SkipOneQuest then ER.SkipOneQuest(SK.id, SK.quest) end
  end)
  SK.cancel = CreateFrame("Button", "pfQuest_xpGuideSkipMenuCancel", f, "UIPanelButtonTemplate")
  SK.cancel:SetWidth(70)
  SK.cancel:SetHeight(20)
  SK.cancel:SetText("Cancel")
  SK.cancel:SetScript("OnClick", function() f:Hide() end)
end

-- Opens the menu at the mouse for one quest of the step box's list (Tracker.lua) or the quest list. id is nil for a quest only the quest
-- log knows; title is looked up when only the id is known.
function ER.ShowSkipMenu(id, title)
  if not ER.SkipOneQuest then return end
  local Steps = ER.Steps
  if id == 0 then id = nil end
  title = title or (id and Steps.QuestTitle(id))
  if not title then return end
  if not SK.frame then SkipBuild() end
  SK.id, SK.quest = id, title
  local f = SK.frame
  GameTooltip:Hide()
  local y = -9 - ER.FitHeight(SK.title, GOLD .. Plain(title) .. END, SK_W - 20, 12) - 4
  if ER.QuestLogLine and ER.QuestLogLine(title) then
    SK.note:ClearAllPoints()
    SK.note:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
    y = y - ER.FitHeight(SK.note, GREY .. "It also leaves your quest log." .. END, SK_W - 20, 12) - 4
    SK.note:Show()
  else
    SK.note:Hide()
  end
  SK.skip:ClearAllPoints()
  SK.skip:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y - 2)
  SK.cancel:ClearAllPoints()
  SK.cancel:SetPoint("TOPLEFT", f, "TOPLEFT", 104, y - 2)
  f:SetHeight(-y + 32)
  -- The quest lines sit on the right of the screen, so the menu opens to the left of the mouse.
  local x, cy = 0, 0
  if GetCursorPosition then x, cy = GetCursorPosition() end
  local scale = UIParent:GetEffectiveScale() or 1
  if scale <= 0 then scale = 1 end
  f:ClearAllPoints()
  f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x / scale, cy / scale)
  f:Show()
end

------------------------------------------------------------------------------------------------------
-- The tips box
------------------------------------------------------------------------------------------------------

local function TipsBuild()
  local f = CreateFrame("Frame", "pfQuest_xpGuideTips", UIParent)
  TP.frame = f
  TP.width = 300
  f:SetWidth(TP.width)
  f:SetHeight(60)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  Backdrop(f, 0.95)
  f:SetBackdropBorderColor(0.85, 0.65, 0.3, 1)
  f:Hide()
  local head = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  head:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
  head:SetText("pfQuest xpGuide says:")
  local close = CreateFrame("Button", "pfQuest_xpGuideTipsClose", f, "UIPanelCloseButton")
  close:SetWidth(20)
  close:SetHeight(20)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  close:SetScript("OnClick", function()
    TP.list = {}
    TipsFill()
  end)
  for i = 1, TIPS_SHOWN do
    local r = { buttons = {} }
    r.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    r.text:SetJustifyH("LEFT")
    r.text:SetJustifyV("TOP")
    for j = 1, TIP_BUTTONS do
      local b = CreateFrame("Button", "pfQuest_xpGuideTip" .. i .. "Button" .. j, f, "UIPanelButtonTemplate")
      b:SetHeight(18)
      b:SetScript("OnClick", function()
        local tip, fn = this.tip, this.fn
        if tip then ER.RemoveTip(tip.key) end
        if fn then fn() end
      end)
      b:Hide()
      r.buttons[j] = b
    end
    TP.rows[i] = r
  end

  -- Tips with a time limit go when it runs out.
  local ticker = CreateFrame("Frame", "pfQuest_xpGuideTipsTicker")
  ticker.wait = 0
  ticker:SetScript("OnUpdate", function()
    this.wait = this.wait + arg1
    if this.wait < 1 then return end
    this.wait = 0
    local now, changed = GetTime(), false
    for i = table.getn(TP.list), 1, -1 do
      local tip = TP.list[i]
      if tip.life and now - tip.at > tip.life then
        table.remove(TP.list, i)
        changed = true
      end
    end
    if changed then TipsFill() end
  end)
end

-- Questions first (they wait for an answer), then the newest tips.
local function Ordered()
  local out = {}
  for _, tip in ipairs(TP.list) do
    if tip.buttons then table.insert(out, tip) end
  end
  for _, tip in ipairs(TP.list) do
    if not tip.buttons then table.insert(out, tip) end
  end
  return out
end

TipsFill = function()
  local f = TP.frame
  if not f then return end
  if (ER.db and ER.db.tipsOff) or table.getn(TP.list) == 0 then
    f:Hide()
    return
  end
  local w = TP.width
  local y = -24
  local list = Ordered()
  for i = 1, TIPS_SHOWN do
    local r, tip = TP.rows[i], list[i]
    if tip then
      r.text:ClearAllPoints()
      r.text:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
      local h = ER.FitHeight(r.text, tip.text, w - 20, 14) + 2
      r.text:Show()
      y = y - h - 2
      local x, any = 10, false
      for j = 1, TIP_BUTTONS do
        local b, bt = r.buttons[j], tip.buttons and tip.buttons[j]
        if bt then
          b:SetText(bt.label)
          local tw = b.GetTextWidth and b:GetTextWidth() or 0
          local bw = (tw > 0 and tw or string.len(bt.label) * 6) + 22
          if x + bw > w - 10 and x > 10 then
            y = y - 22
            x = 10
          end
          b:SetWidth(bw)
          b:ClearAllPoints()
          b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
          b.tip, b.fn = tip, bt.fn
          b:Show()
          x = x + bw + 4
          any = true
        else
          b.tip, b.fn = nil, nil
          b:Hide()
        end
      end
      if any then y = y - 22 end
      y = y - 4
    else
      r.text:Hide()
      for j = 1, TIP_BUTTONS do r.buttons[j]:Hide() end
    end
  end
  f:SetHeight(-y + 8)
  f:Show()
end

-- Puts the tips box under the quest list in simple mode, under the step window otherwise, or on its own at the
-- right of the screen when neither is up.
function ER.PlaceTips()
  local f = TP.frame
  if not f then return end
  f:ClearAllPoints()
  local under = ER.TrackerBottom and ER.TrackerBottom()
  if under then
    TP.width = math.max(220, math.floor(under:GetWidth() + 0.5))
    f:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, -2)
  else
    TP.width = 300
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -560)
  end
  f:SetWidth(TP.width)
  TipsFill()
end

-- A tip: key (a newer tip with the same key replaces it), text, buttons ({ { label, fn }, ... }, up to four; a tip
-- with buttons waits for an answer), life (seconds before it goes by itself; nil = until answered or closed).
function ER.AddTip(key, text, buttons, life)
  if not key or not text then return end
  for i = table.getn(TP.list), 1, -1 do
    if TP.list[i].key == key then table.remove(TP.list, i) end
  end
  table.insert(TP.list, 1, { key = key, text = text, buttons = buttons, life = life, at = GetTime() })
  while table.getn(TP.list) > 8 do table.remove(TP.list) end
  if not TP.frame then TipsBuild() end
  ER.PlaceTips()
end

function ER.RemoveTip(key)
  local changed = false
  for i = table.getn(TP.list), 1, -1 do
    if TP.list[i].key == key then
      table.remove(TP.list, i)
      changed = true
    end
  end
  if changed then TipsFill() end
end

-- Removes every tip whose key starts with this (the guide's warnings for a step that is behind you).
function ER.RemoveTips(prefix)
  local changed = false
  for i = table.getn(TP.list), 1, -1 do
    if string.sub(TP.list[i].key, 1, string.len(prefix)) == prefix then
      table.remove(TP.list, i)
      changed = true
    end
  end
  if changed then TipsFill() end
end

function ER.HasTip(key)
  for _, tip in ipairs(TP.list) do
    if tip.key == key then return true end
  end
  return false
end

function ER.TipsList() return TP.list end

function ER.ToggleTips()
  if not ER.db then return end
  ER.db.tipsOff = not ER.db.tipsOff
  Say("tips " .. (ER.db.tipsOff and "hidden. " .. GOLD .. "/xpg tips" .. END .. " shows them again." or "shown."))
  if TP.frame then TipsFill() end
end

ER.Loaded("Simple.lua")
