-- BananaBank UI Teil 8: Anleitung als Slideshow (Knopf "?" oben rechts)

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local WHITE = UI.WHITE

UI.helpModule = true

-- Abschnitte: Mitglieder und Bank/Offiziere. Texte stehen in der Locale als HLP_<sec><n>_T/H/B/F,
-- die Ablauf-Kaesten als HLP_<sec><n>_A1.._A4. Spaeter kann je Slide ein echter Screenshot
-- (Media\help_<sec><n>) ueber BB.HELP_IMG[<sec><n>] eingehaengt werden.
local SECTIONS = {
  { key = "M", count = 7, steps = { 4, 4, 4, 4, 3, 4, 3 } },
  { key = "B", count = 5, steps = { 3, 4, 3, 4, 4 } },
}
BB.HELP_IMG = BB.HELP_IMG or {}

local BOX_W, BOX_H = 120, 84

function UI:BuildHelp()
  if self.helpWin then return end
  local f = CreateFrame("Frame", "BananaBankHelp", UIParent)
  self.helpWin = f
  f:SetWidth(640)
  f:SetHeight(450)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:EnableMouseWheel(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetBackdropColor(0.015, 0.025, 0.06, 1)
  f:Hide()
  tinsert(UISpecialFrames, "BananaBankHelp")
  f.sec, f.n = 1, 1

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
  f.title = self:Font(f, 20, C.gold, UI.FONT_TITLE)
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -20)
  self:Loc(f.title, "HLP_TITLE")
  f.chips = {}
  for i = 1, getn(SECTIONS) do
    local idx = i
    local chip = self:Chip(f, 170, "HLP_SEC_" .. SECTIONS[i].key, function()
      f.sec = idx
      f.n = 1
      UI:RefreshHelp()
    end)
    chip:SetHeight(22)
    chip:SetPoint("TOPLEFT", f, "TOPLEFT", 26 + (i - 1) * 176, -50)
    f.chips[i] = chip
  end
  self:GlowLine(f, -80, 20, -20)

  f.step = self:Font(f, 10, C.muted)
  f.step:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -92)
  f.step:SetWidth(580)
  f.step:SetHeight(12)
  f.head = self:Font(f, 20, C.gold, UI.FONT_TITLE)
  f.head:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -108)
  f.head:SetWidth(580)
  f.head:SetHeight(22)

  -- Bildflaeche: Ablauf-Kaesten oder ein Screenshot
  local art = CreateFrame("Frame", nil, f)
  art:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -138)
  art:SetWidth(584)
  art:SetHeight(140)
  art:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  art:SetBackdropColor(0.06, 0.09, 0.19, 1)
  art:SetBackdropBorderColor(C.brass[1], C.brass[2], C.brass[3], 0.9)
  f.art = art
  f.img = art:CreateTexture(nil, "ARTWORK")
  f.img:SetPoint("TOPLEFT", art, "TOPLEFT", 4, -4)
  f.img:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", -4, 4)
  f.img:Hide()
  f.boxes = {}
  f.arrows = {}
  for i = 1, 4 do
    local b = CreateFrame("Frame", nil, art)
    b:SetWidth(BOX_W)
    b:SetHeight(BOX_H)
    b:SetBackdrop({
      bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 10,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    b:SetBackdropColor(0.10, 0.14, 0.30, 1)
    b:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 0.9)
    local badge = b:CreateTexture(nil, "ARTWORK")
    badge:SetTexture(WHITE)
    badge:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
    badge:SetWidth(20)
    badge:SetHeight(20)
    badge:SetPoint("TOP", b, "TOP", 0, -8)
    b.num = self:Font(b, 13, { 0.08, 0.06, 0.02 })
    b.num:SetPoint("CENTER", badge, "CENTER", 0, 0)
    b.num:SetJustifyH("CENTER")
    b.num:SetText(i)
    b.fs = self:Font(b, 12, { 1, 1, 1 })
    b.fs:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -34)
    b.fs:SetWidth(BOX_W - 16)
    b.fs:SetHeight(44)
    b.fs:SetJustifyH("CENTER")
    b.fs:SetJustifyV("TOP")
    f.boxes[i] = b
    local a = self:Font(art, 24, C.gold, UI.FONT_TITLE)
    a:SetText(">")
    f.arrows[i] = a
  end

  f.body = self:Font(f, 13, { 0.88, 0.90, 0.96 })
  f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -290)
  f.body:SetWidth(580)
  f.body:SetHeight(66)
  f.body:SetJustifyV("TOP")
  local strip = f:CreateTexture(nil, "BORDER")
  strip:SetTexture(WHITE)
  strip:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -362)
  strip:SetWidth(584)
  strip:SetHeight(32)
  strip:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0.26, 0.30, 1, 0.82, 0.26, 0.04)
  f.foot = self:Font(f, 11, { 1, 0.9, 0.55 })
  f.foot:SetPoint("LEFT", strip, "LEFT", 10, 0)
  f.foot:SetWidth(566)
  f.foot:SetHeight(28)

  f.prev = self:Button(f, 110, 24, "HLP_PREV", function() UI:HelpGo(-1) end)
  f.prev:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 26, 22)
  f.next = self:Button(f, 110, 24, "HLP_NEXT", function() UI:HelpGo(1) end, "primary")
  f.next:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 22)
  f.dots = {}
  for i = 1, 7 do
    local d = CreateFrame("Button", nil, f)
    d:SetWidth(14)
    d:SetHeight(14)
    d.t = d:CreateTexture(nil, "ARTWORK")
    d.t:SetTexture(WHITE)
    d.t:SetWidth(9)
    d.t:SetHeight(9)
    d.t:SetPoint("CENTER", d, "CENTER", 0, 0)
    d.index = i
    d:SetScript("OnClick", function()
      f.n = this.index
      UI:RefreshHelp()
    end)
    f.dots[i] = d
  end
  f:SetScript("OnMouseWheel", function() UI:HelpGo(-arg1) end)
end

-- der Bank-Teil erscheint nur auf Chars mit Rang Gildenbank (oder Quest-Verwaltern)
function UI:HelpHasBankPart()
  local me = BB:Me()
  return (BB.MayBeBank and BB:MayBeBank(me)) or BB:CanManageQuests() or false
end

function UI:HelpGo(delta)
  local f = self.helpWin
  local sec = SECTIONS[f.sec]
  local n = f.n + delta
  local last = self:HelpHasBankPart() and getn(SECTIONS) or 1
  if n < 1 then
    if f.sec > 1 then f.sec = f.sec - 1 n = SECTIONS[f.sec].count else n = 1 end
  elseif n > sec.count then
    if f.sec < last then f.sec = f.sec + 1 n = 1 else n = sec.count end
  end
  f.n = n
  self:RefreshHelp()
end

function UI:RefreshHelp()
  local f = self.helpWin
  if not f then return end
  local sec = SECTIONS[f.sec]
  local n = f.n
  local hasB = self:HelpHasBankPart()
  if not hasB and f.sec > 1 then f.sec = 1 f.n = 1 sec = SECTIONS[1] n = 1 end
  local pre = "HLP_" .. sec.key .. n
  for i = 1, getn(f.chips) do
    f.chips[i]:SetActive(i == f.sec)
    if hasB then f.chips[i]:Show() else f.chips[i]:Hide() end
  end
  f.step:SetText(string.format(T("HLP_STEP"), n, sec.count) .. "  -  " .. T(pre .. "_T"))
  f.head:SetText(T(pre .. "_H"))
  f.body:SetText(T(pre .. "_B"))
  local foot = T(pre .. "_F")
  if string.find(foot, "%s", 1, true) then foot = string.format(foot, BB:MainBank()) end
  f.foot:SetText(foot)
  local img = BB.HELP_IMG[sec.key .. n]
  local cnt = sec.steps[n]
  if img then
    f.img:SetTexture(img)
    f.img:Show()
    for i = 1, 4 do f.boxes[i]:Hide() f.arrows[i]:Hide() end
  else
    f.img:Hide()
    local gap = 22
    local total = cnt * BOX_W + (cnt - 1) * gap
    local x0 = (584 - total) / 2
    for i = 1, 4 do
      local b = f.boxes[i]
      if i <= cnt then
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f.art, "TOPLEFT", x0 + (i - 1) * (BOX_W + gap), -28)
        b.fs:SetText(T(pre .. "_A" .. i))
        b:Show()
      else
        b:Hide()
      end
      local a = f.arrows[i]
      if i < cnt then
        a:ClearAllPoints()
        a:SetPoint("TOPLEFT", f.art, "TOPLEFT", x0 + i * BOX_W + (i - 1) * gap + 3, -55)
        a:Show()
      else
        a:Hide()
      end
    end
  end
  -- Punkte
  local startX = 320 - (sec.count * 16) / 2
  for i = 1, 7 do
    local d = f.dots[i]
    if i <= sec.count then
      d:ClearAllPoints()
      d:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", startX + (i - 1) * 16, 28)
      if i == n then d.t:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1) else d.t:SetVertexColor(0.30, 0.34, 0.50, 1) end
      d:Show()
    else
      d:Hide()
    end
  end
  if f.sec == 1 and n == 1 then f.prev:Hide() else f.prev:Show() end
  if f.sec == (hasB and getn(SECTIONS) or 1) and n == sec.count then f.next:Hide() else f.next:Show() end
end

function UI:ToggleHelp()
  self:BuildHelp()
  local f = self.helpWin
  if f:IsVisible() then f:Hide() return end
  f:Show()
  self:RefreshHelp()
end

function UI:BuildHelpButton(parent)
  local b = self:Button(parent, 22, 18, "?", function() UI:ToggleHelp() end, "flat")
  b.fs:SetTextColor(1, 0.6, 0.18)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(T("HLP_BTN_TIP"), 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end
