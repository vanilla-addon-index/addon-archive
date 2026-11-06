-- BananaBank Bank-Lotse: kleines Fenster, das durch eine Anfrage fuehrt (Pruefen, Holen, Senden, Fertig).
-- Es oeffnet sich, wenn im grossen Fenster die erste Anfrage geoeffnet wird, und ersetzt das grosse Fenster
-- bei der Arbeit am Bank-Char. Anzeigearten: A normal, B kompakt (eine Zeile), C Liste der Anfragen.

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local floor = math.floor
local WHITE = UI.WHITE

UI.lotseModule = true
UI.L = { cur = nil, mode = "A", open = false }

local W = 232
local HEIGHT = { A = 190, B = 54, C = 190 }
local MODES = { "A", "B", "C" }
local QROWS = 6

-- ------------------------------------------------------------
-- Logik: Rest einer Anfrage, Einordnung nach Bank-Char, Warteschlange
-- ------------------------------------------------------------
local function remaining(r)
  local rem = {}
  for id in pairs(r.items) do
    local left = BB:ReqLeft(r, id) - BB:ProjectedShort(r, id)
    if left > 0 then rem[id] = left end
  end
  return rem
end

-- "here": alles liegt auf diesem Char | "part": ein Teil | "else": nichts davon. Dazu: was hier fehlt.
function BB:LotseClass(r)
  local short, any, miss = {}, false, false
  for id, n in pairs(remaining(r)) do
    local have = self:LocalCount(id)
    if have > 0 then any = true end
    if have < n then
      miss = true
      short[id] = n - have
    end
  end
  if not miss then return "here", short end
  if any then return "part", short end
  return "else", short
end

-- Bank-Chars, auf denen das Fehlende liegt (die Bank mit dem meisten Bestand zuerst)
function BB:LotseElsewhere(short, into)
  for id in pairs(short) do
    local others = self:OtherBankCounts(id)
    if others[1] then into[others[1].bank] = (into[others[1].bank] or 0) + 1 end
  end
end

-- here = Anfragen, die dieser Char (ganz oder teilweise) bedienen kann; away = Rest;
-- hints = { { bank = , n = } } = Banken, auf die gewechselt werden muss
function BB:LotseQueue()
  local here, away, banks = {}, {}, {}
  for _, r in pairs(BananaBankDB.reqs) do
    if self:IsActive(r) then
      local cls, short = self:LotseClass(r)
      local e = { r = r, cls = cls, short = short }
      if cls == "else" then table.insert(away, e) else table.insert(here, e) end
      if cls ~= "here" then
        local per = {}
        self:LotseElsewhere(short, per)
        for bank in pairs(per) do banks[bank] = (banks[bank] or 0) + 1 end
      end
    end
  end
  local function byTime(a, b)
    if (a.r.ts or 0) ~= (b.r.ts or 0) then return (a.r.ts or 0) < (b.r.ts or 0) end
    return a.r.id < b.r.id
  end
  table.sort(here, byTime)
  table.sort(away, byTime)
  local hints = {}
  for bank, n in pairs(banks) do table.insert(hints, { bank = bank, n = n }) end
  table.sort(hints, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return a.bank < b.bank
  end)
  return here, away, hints
end

-- Liegt alles Fehlende schon in den Taschen? Dann braucht "Holen" die Bank nicht.
function BB:BagsCover(r)
  local bags = self:ScanContainers(BB.BAG_LIST)
  for id, n in pairs(remaining(r)) do
    if not bags[id] or bags[id].c < n then return false end
  end
  return true
end

-- 1 Pruefen, 2 Holen, 3 Senden, 4 Fertig, 0 nichts
function UI:LotseStep(r)
  local L = self.L
  if not r then return 0 end
  if r.s == "sent" or L.finished == r.id then return 4 end
  local st = BB:ReqState(r)
  if st == "open" then return 1 end
  if st == "confirmed" then
    if BB.prep and BB.prep.r == r then return 3 end
    return 2
  end
  return 0
end

-- ------------------------------------------------------------
-- Aktionen
-- ------------------------------------------------------------
function UI:LotseSelect(r)
  local L = self.L
  L.cur = r
  L.finished = nil
  L.sawPrep = nil
  L.tried = nil
  if self.bank then self.bank.current = r end
end

-- Zurueck / vor durch alle laufenden Anfragen
function UI:LotseStepRequest(dir)
  local L = self.L
  local here, away = BB:LotseQueue()
  local list = {}
  for i = 1, getn(here) do table.insert(list, here[i].r) end
  for i = 1, getn(away) do table.insert(list, away[i].r) end
  local n = getn(list)
  if n == 0 then return end
  local idx = 0
  for i = 1, n do if L.cur == list[i] then idx = i end end
  idx = idx + dir
  if idx < 1 then idx = n end
  if idx > n then idx = 1 end
  self:LotseSelect(list[idx])
  self:RefreshLotse()
end

function UI:LotseNext()
  local L = self.L
  local here = BB:LotseQueue()
  local nxt
  for i = 1, getn(here) do
    if not (L.cur and here[i].r == L.cur) then
      nxt = here[i].r
      break
    end
  end
  if nxt then self:LotseSelect(nxt) else self:LotseSelect(nil) end
  self:RefreshLotse()
end

function UI:LotsePrimary()
  local L = self.L
  local r = L.cur
  local step = self:LotseStep(r)
  if step == 1 then
    if r.cl and next(r.cl) ~= nil then BB:AcceptCrafter(r) else BB:ConfirmRequest(r) end
  elseif step == 2 then
    BB:FetchFor(r)
  elseif step == 3 then
    BB:SendNextMail()
  elseif step == 4 then
    local here = BB:LotseQueue()
    local more = false
    for i = 1, getn(here) do if here[i].r ~= r then more = true end end
    if more then self:LotseNext() else self:LotseClose() return end
  end
  UI:Refresh()
end

function UI:LotseCycleMode()
  local L = self.L
  local idx = 1
  for i = 1, getn(MODES) do if MODES[i] == L.mode then idx = i end end
  idx = idx + 1
  if idx > getn(MODES) then idx = 1 end
  L.mode = MODES[idx]
  BananaBankDB.lotse = BananaBankDB.lotse or {}
  BananaBankDB.lotse.mode = L.mode
  self:RefreshLotse()
end

function UI:LotseOpen(r)
  if not BB:BankActive() then return false end
  self:BuildLotse()
  local L = self.L
  L.open = true
  local saved = BananaBankDB.lotse
  if saved and saved.mode then L.mode = saved.mode end
  self:LotseSelect(r)
  -- das grosse Fenster macht Platz
  if self.frame and self.frame:IsVisible() then self.frame:Hide() end
  self.lotse:Show()
  self:RefreshLotse()
  return true
end

function UI:LotseClose()
  local L = self.L
  L.open = false
  if self.lotse then self.lotse:Hide() end
  UI:Refresh()
end

-- ------------------------------------------------------------
-- Fenster
-- ------------------------------------------------------------
local function setBtnText(b, text)
  b.fs:SetText(text)
end

function UI:BuildLotse()
  if self.lotse then return end
  local f = CreateFrame("Frame", "BananaBankLotse", UIParent)
  self.lotse = f
  f:SetWidth(W)
  f:SetHeight(HEIGHT.A)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(true)
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local x, y = this:GetLeft(), this:GetTop()
    BananaBankDB.lotse = BananaBankDB.lotse or {}
    BananaBankDB.lotse.x, BananaBankDB.lotse.y = x, y
  end)
  f:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0.03, 0.045, 0.11, 0.98)
  f:SetBackdropBorderColor(C.brass[1], C.brass[2], C.brass[3], 1)
  f:Hide()
  local pos = BananaBankDB.lotse
  if pos and pos.x and pos.y then
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
  else
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -190)
  end

  -- Kopf
  local head = f:CreateTexture(nil, "BORDER")
  head:SetTexture(WHITE)
  head:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
  head:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
  head:SetHeight(19)
  head:SetGradientAlpha("VERTICAL", 0.08, 0.10, 0.25, 1, 0.13, 0.17, 0.40, 1)
  f.title = self:Font(f, 12, C.gold, UI.FONT_TITLE)
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
  f.title:SetText("BananaBank")
  f.count = self:Font(f, 10, C.muted)
  f.count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -80, -8)
  f.count:SetJustifyH("RIGHT")
  f.modeBtn = self:Button(f, 54, 15, "", function() UI:LotseCycleMode() end, "flat")
  f.modeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -5)
  f.modeBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(T("LO_MODE_TIP"), 1, 1, 1)
    GameTooltip:Show()
  end)
  f.modeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.prevBtn = self:Button(f, 16, 15, "<", function() UI:LotseStepRequest(-1) end, "flat")
  f.prevBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 78, -5)
  f.nextBtn = self:Button(f, 16, 15, ">", function() UI:LotseStepRequest(1) end, "flat")
  f.nextBtn:SetPoint("LEFT", f.prevBtn, "RIGHT", 2, 0)
  f.closeBtn = self:Button(f, 16, 15, "x", function() UI:LotseClose() end, "danger")
  f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)

  -- Schrittleiste
  f.dots, f.lines, f.caps = {}, {}, {}
  for i = 1, 4 do
    local d = CreateFrame("Frame", nil, f)
    d:SetWidth(16)
    d:SetHeight(16)
    d:SetBackdrop(UI.BACKDROP_PANEL)
    d.fs = self:Font(d, 9, C.muted)
    d.fs:SetPoint("CENTER", d, "CENTER", 0, 0)
    d.fs:SetJustifyH("CENTER")
    d:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + (i - 1) * 63, -29)
    f.dots[i] = d
    local cap = self:Font(f, 9, C.muted)
    cap:SetPoint("TOP", d, "BOTTOM", 0, -1)
    cap:SetJustifyH("CENTER")
    cap:SetText(T("LO_STEP" .. i))
    f.caps[i] = cap
    if i < 4 then
      local ln = f:CreateTexture(nil, "ARTWORK")
      ln:SetTexture(WHITE)
      ln:SetHeight(2)
      ln:SetPoint("LEFT", d, "RIGHT", 2, 0)
      ln:SetWidth(43)
      f.lines[i] = ln
    end
  end

  -- Text
  f.t1 = self:Font(f, 12, { 1, 1, 1 })
  f.t1:SetWidth(W - 20)
  f.t1:SetHeight(14)
  f.t2 = self:Font(f, 10, C.muted)
  f.t2:SetWidth(W - 20)
  f.t2:SetHeight(26)
  f.t2:SetJustifyV("TOP")

  -- Nachnahme-Zeilen
  f.cl1 = self:Font(f, 10, C.muted)
  f.cv1 = self:Font(f, 11, C.gold)
  f.cv1:SetJustifyH("RIGHT")
  f.cl2 = self:Font(f, 10, C.muted)
  f.cv2 = self:Font(f, 11, C.gold)
  f.cv2:SetJustifyH("RIGHT")

  f.bar = self:QBar(f, W - 20, 12)

  f.b1 = self:Button(f, W - 20, 22, "", function() UI:LotseSecondary() end, "ok")
  f.b2 = self:Button(f, W - 20, 22, "", function() UI:LotsePrimary() end, "primary")
  f.b3 = self:Button(f, 60, 22, "BTN_REJECT", function()
    local r = UI.L.cur
    if r then BB:RejectRequest(r) end
    UI:Refresh()
  end, "danger")
  f.b4 = self:Button(f, W - 20, 22, "", function() UI:LotseClose() end)

  f.bAll = self:Button(f, W - 20, 22, "", function()
    BB:ConfirmAll()
    UI:Refresh()
  end, "ok")
  f.bOv = self:Button(f, 72, 18, "LO_OVERVIEW", function() UI:OpenSendOverview() end, "flat")

  f.chk = self:Check(f, "LO_AUTO_MAIL", function() return BananaBankDB.auto end, function(v) BananaBankDB.auto = v end)
  f.chk:SetWidth(W - 20)
  f.chk2 = self:Check(f, "LO_AUTO_FETCH", function() return BananaBankDB.lotseAuto ~= false end, function(v) BananaBankDB.lotseAuto = v end)
  f.chk2:SetWidth(W - 20)
  f.foot = self:Font(f, 10, C.muted)
  f.foot:SetWidth(W - 20)
  f.foot:SetHeight(26)
  f.foot:SetJustifyV("TOP")

  -- Kompakt (B): Punkt mit Schrittnummer, eine Zeile Text, Hauptknopf
  f.mini = self:Font(f, 11, { 1, 1, 1 })
  f.mini:SetWidth(W - 20 - 90 - 6)
  f.mini:SetHeight(14)
  f.miniBtn = self:Button(f, 90, 20, "", function() UI:LotsePrimary() end, "primary")

  -- Liste (C)
  f.qrows = {}
  for i = 1, QROWS do
    local row = CreateFrame("Button", nil, f)
    row:SetHeight(18)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -30 - (i - 1) * 19)
    row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -30 - (i - 1) * 19)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(WHITE)
    hl:SetAllPoints(row)
    hl:SetVertexColor(1, 0.82, 0.3, 0.14)
    row.sel = row:CreateTexture(nil, "BACKGROUND")
    row.sel:SetTexture(WHITE)
    row.sel:SetAllPoints(row)
    row.sel:SetVertexColor(1, 0.82, 0.3, 0.12)
    row.l = self:Font(row, 10, C.text)
    row.l:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.l:SetWidth(128)
    row.l:SetHeight(12)
    row.r = self:Font(row, 10, C.muted)
    row.r:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.r:SetJustifyH("RIGHT")
    local idx = i
    row:SetScript("OnClick", function()
      local e = UI.L.queue and UI.L.queue[idx]
      if e then
        UI:LotseSelect(e.r)
        UI.L.mode = "A"
        UI:RefreshLotse()
      end
    end)
    f.qrows[i] = row
  end
  f.qfoot = self:Font(f, 10, C.orange)
  f.qfoot:SetWidth(W - 20)
  f.qfoot:SetJustifyV("TOP")

  f.acc = 0
  f:SetScript("OnUpdate", function()
    this.acc = this.acc + (arg1 or 0)
    if this.acc < 0.3 then return end
    this.acc = 0
    UI:LotseTick()
  end)
end

-- Hauptknopf der oberen Variante (Anspruch akzeptieren)
function UI:LotseSecondary()
  local r = self.L.cur
  if not r then return end
  BB:AcceptCrafter(r)
  UI:Refresh()
end

-- ------------------------------------------------------------
-- Takt: automatisches Holen, Ende eines Versands erkennen, Nachnahme im Sendefenster
-- ------------------------------------------------------------
function UI:LotseTick()
  local L = self.L
  local f = self.lotse
  if not f or not L.open then return end
  if not BB:BankActive() then
    self:LotseClose()
    return
  end
  local r = L.cur
  if r then
    if BB.prep and BB.prep.r == r then L.sawPrep = r.id end
    -- Sammelrunde: die naechste Anfrage ist dran, das Fenster folgt ihr
    if L.sawPrep == r.id and BB.prep and BB.prep.r ~= r then
      self:LotseSelect(BB.prep.r)
      L.sawPrep = BB.prep.r.id
      self:RefreshLotse()
      return
    end
    if L.sawPrep == r.id and not BB.prep and not BB.job then
      L.finished = r.id
      L.sawPrep = nil
      self:RefreshLotse()
    end
    -- automatisch holen: sobald die Bank offen ist (oder alles schon in den Taschen liegt)
    if BananaBankDB.lotseAuto ~= false and self:LotseStep(r) == 2 and not BB.job and not BB.prep then
      local key = r.id .. (BB.bankOpen and "B" or "N")
      if L.tried ~= key and (BB.bankOpen or BB:BagsCover(r)) then
        L.tried = key
        BB:FetchFor(r)
        self:RefreshLotse()
      end
    end
  end
  -- Fortschrittsbalken beim Holen
  if BB.job and f.bar:IsShown() and r then
    local total = BB.Count(remaining(r))
    local n = getn(BB.job.slots)
    f.bar:Set(n, math.max(total, n), "open")
  end
  self:LotseLive()
end

-- Nachnahme im Sendefenster, laufend verglichen
function UI:LotseLive()
  local f = self.lotse
  if not f or not f:IsVisible() then return end
  local p = BB.prep
  if self:LotseStep(self.L.cur) ~= 3 or not p or not p.slots[p.idx] then return end
  local want = BB:LetterCod(p)
  local got = BB:EnteredCod()
  f.cv1:SetText(want > 0 and BB.Money(want) or T("LO_NONE"))
  if got == nil or p.sending then
    f.cv2:SetText("")
    f.mini:SetText(string.format(T("LO_MINI3"), p.idx, getn(p.slots), want > 0 and BB.Money(want) or T("LO_NONE")))
    return
  end
  local txt = got > 0 and BB.Money(got) or T("LO_NONE")
  local tail
  if got == want then tail = "  |cff60e070" .. T("LO_OK") .. "|r" else tail = "  |cffff5040" .. T("LO_BAD") .. "|r" end
  f.cv2:SetText(txt .. tail)
  f.mini:SetText(string.format(T("LO_MINI3"), p.idx, getn(p.slots), want > 0 and BB.Money(want) or T("LO_NONE")) .. tail)
end

-- ------------------------------------------------------------
-- Anzeige
-- ------------------------------------------------------------
local function place(fs, f, y, x)
  fs:ClearAllPoints()
  fs:SetPoint("TOPLEFT", f, "TOPLEFT", x or 10, y)
end

local function showOnly(f, list)
  local all = { f.t1, f.t2, f.cl1, f.cv1, f.cl2, f.cv2, f.bar, f.b1, f.b2, f.b3, f.b4, f.chk, f.chk2, f.foot,
    f.mini, f.miniBtn, f.qfoot, f.bAll, f.bOv }
  for i = 1, getn(all) do all[i]:Hide() end
  for i = 1, getn(list) do list[i]:Show() end
end

local function elseText(hints)
  if getn(hints) == 0 then return nil end
  local parts = {}
  for i = 1, getn(hints) do
    table.insert(parts, string.format(T("LO_ELSE_LINE"), hints[i].bank, hints[i].n))
  end
  return T("LO_ELSE_HEAD") .. " " .. table.concat(parts, "; ")
end

function UI:RefreshLotse()
  local L = self.L
  local f = self.lotse
  if not f or not L.open then return end
  if not BB:BankActive() then
    f:Hide()
    return
  end
  f:Show()
  local here, away, hints = BB:LotseQueue()
  L.queue = nil
  local r = L.cur
  -- verschwundene oder erledigte Anfrage: aus dem Blick nehmen, solange sie nicht gerade fertig gemeldet wird
  if r and not BB:IsActive(r) and r.s ~= "sent" then
    L.cur = nil
    r = nil
  end
  local step = self:LotseStep(r)
  local nOpen = getn(here) + getn(away)
  f.count:SetText(string.format(T("LO_COUNT"), nOpen))
  f.modeBtn.fs:SetText(T("LO_MODE_" .. L.mode))

  -- Schrittleiste
  for i = 1, 4 do
    local d = f.dots[i]
    local col, border, tcol
    if step > i then
      col, border, tcol = { 0.11, 0.38, 0.15 }, { 0.18, 0.88, 0.29 }, { 1, 1, 1 }
      d.fs:SetText("v")
    elseif step == i then
      col, border, tcol = { 0.10, 0.10, 0.18 }, { 1, 0.82, 0.2 }, { 1, 0.82, 0.2 }
      d.fs:SetText(i)
    else
      col, border, tcol = { 0.06, 0.06, 0.10 }, { 0.30, 0.26, 0.12 }, { 0.5, 0.5, 0.5 }
      d.fs:SetText(i)
    end
    d:SetBackdropColor(col[1], col[2], col[3], 1)
    d:SetBackdropBorderColor(border[1], border[2], border[3], 1)
    d.fs:SetTextColor(tcol[1], tcol[2], tcol[3])
    f.caps[i]:SetTextColor(step == i and 1 or 0.55, step == i and 0.82 or 0.55, step == i and 0.2 or 0.55)
    if f.lines[i] then
      if step > i then f.lines[i]:SetVertexColor(0.18, 0.88, 0.29, 1) else f.lines[i]:SetVertexColor(0.23, 0.20, 0.09, 1) end
    end
  end

  if L.mode == "B" then
    f:SetHeight(HEIGHT.B)
    for i = 1, 4 do
      f.dots[i]:Hide()
      f.caps[i]:Hide()
      if f.lines[i] then f.lines[i]:Hide() end
    end
    for i = 1, QROWS do f.qrows[i]:Hide() end
    showOnly(f, { f.mini, f.miniBtn })
    f.mini:ClearAllPoints()
    f.mini:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -32)
    f.miniBtn:ClearAllPoints()
    f.miniBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -28)
    self:LotseFillMini(r, step, here)
    return
  end

  for i = 1, 4 do
    f.dots[i]:Show()
    f.caps[i]:Show()
    if f.lines[i] then f.lines[i]:Show() end
  end

  if L.mode == "C" then
    f:SetHeight(HEIGHT.C)
    for i = 1, 4 do
      f.dots[i]:Hide()
      f.caps[i]:Hide()
      if f.lines[i] then f.lines[i]:Hide() end
    end
    showOnly(f, { f.qfoot })
    local list = {}
    for i = 1, getn(here) do table.insert(list, here[i]) end
    for i = 1, getn(away) do table.insert(list, away[i]) end
    L.queue = list
    for i = 1, QROWS do
      local row = f.qrows[i]
      local e = list[i]
      if e then
        local who = e.r.id .. " " .. e.r.p
        row.l:SetText(who)
        row.r:SetText(T("LO_CLS_" .. e.cls))
        if e.cls == "here" then row.r:SetTextColor(0.35, 0.88, 0.42)
        elseif e.cls == "part" then row.r:SetTextColor(1, 0.7, 0.2)
        else row.r:SetTextColor(0.6, 0.6, 0.66) end
        if L.cur == e.r then row.sel:Show() else row.sel:Hide() end
        row:Show()
      else
        row:Hide()
      end
    end
    f.qfoot:ClearAllPoints()
    f.qfoot:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30 - QROWS * 19 - 6)
    f.qfoot:SetHeight(40)
    local et = elseText(hints)
    f.qfoot:SetText(et or (nOpen == 0 and T("LO_IDLE") or ""))
    f.qfoot:Show()
    return
  end

  -- A: normale Ansicht
  f:SetHeight(HEIGHT.A)
  for i = 1, QROWS do f.qrows[i]:Hide() end
  local et = elseText(hints)
  f.t1:SetTextColor(1, 1, 1)
  f.foot:SetTextColor(1, 0.65, 0.2)

  if not r then
    showOnly(f, { f.t1, f.t2, f.b4 })
    place(f.t1, f, -64)
    f.t1:SetText(nOpen == 0 and T("LO_IDLE") or T("LO_PICK"))
    place(f.t2, f, -82)
    f.t2:SetText(et or "")
    f.t2:SetHeight(50)
    f.b4:ClearAllPoints()
    f.b4:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    setBtnText(f.b4, T("LO_CLOSE"))
    return
  end
  f.t2:SetHeight(26)

  if step == 1 then
    showOnly(f, { f.t1, f.t2, f.cl1, f.cv1, f.b2, f.b3 })
    place(f.t1, f, -64)
    f.t1:SetText(string.format(T("LO_REQ"), r.id, r.p))
    local ncl = 0
    if r.cl then for _ in pairs(r.cl) do ncl = ncl + 1 end end
    local line = string.format(T("LO_ITEMS"), BB.Count(r.items))
    if ncl > 0 then line = line .. " - " .. string.format(T("LO_CLAIMS"), ncl) end
    local cls, short = BB:LotseClass(r)
    if cls ~= "here" then
      local per = {}
      BB:LotseElsewhere(short, per)
      local names = {}
      for bank in pairs(per) do table.insert(names, bank) end
      table.sort(names)
      if getn(names) > 0 then line = line .. "\n" .. string.format(T("LO_REST"), table.concat(names, ", ")) end
    end
    place(f.t2, f, -80)
    f.t2:SetText(line)
    local now, after = BB:RequestCodTotals(r)
    local codTxt = now > 0 and BB.Money(now) or T("LO_NONE")
    if ncl > 0 and now ~= after then codTxt = codTxt .. " > " .. BB.Money(after) end
    place(f.cl1, f, -110)
    f.cl1:SetText(T("LO_COD"))
    f.cv1:ClearAllPoints()
    f.cv1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -109)
    f.cv1:SetText(codTxt)
    if ncl > 0 then
      f.b1:Show()
      f.b1:ClearAllPoints()
      f.b1:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -126)
      setBtnText(f.b1, T("CR_B_BTN"))
      f.b1:SetOn(true)
      f.b2:ClearAllPoints()
      f.b2:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -152)
      f.b2:SetWidth(W - 20 - 66)
      setBtnText(f.b2, T("CR_B_NORMAL"))
    else
      f.b1:Hide()
      f.b2:ClearAllPoints()
      f.b2:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -134)
      f.b2:SetWidth(W - 20 - 66)
      setBtnText(f.b2, T("BTN_CONFIRM"))
    end
    f.b2:SetOn(BB:ReqState(r) == "open")
    f.b3:ClearAllPoints()
    f.b3:SetPoint("LEFT", f.b2, "RIGHT", 6, 0)
    f.b3:SetOn(true)
    -- alle offenen Anfragen mit einem Klick
    local nOpenAll = BB:OpenRequestCount()
    if nOpenAll >= 2 then
      f:SetHeight(HEIGHT.A + 28)
      f.bAll:Show()
      f.bAll:ClearAllPoints()
      f.bAll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, (ncl > 0 and -180 or -162))
      setBtnText(f.bAll, string.format(T("LO_CONFIRM_ALL"), nOpenAll))
      f.bAll:SetOn(true)
    else
      f.bAll:Hide()
    end
    -- der Hauptknopf bei Anspruch ist "Als Crafter akzeptieren" (b1), dessen Klick LotseSecondary macht
    if ncl > 0 then f.b1:Show() end
    return
  end

  if step == 2 then
    showOnly(f, { f.t1, f.t2, f.bar, f.cl1, f.cv1, f.b2, f.chk2 })
    place(f.t1, f, -64)
    f.t1:SetText(T("LO_FETCH_T"))
    place(f.t2, f, -80)
    local state = string.format(T("LO_BANKMAIL"), BB.bankOpen and T("YES") or T("NO"), BB.mailOpen and T("YES") or T("NO"))
    if not BB.bankOpen and not BB:BagsCover(r) then state = state .. "\n" .. T("LO_HINT_BANK") end
    f.t2:SetText(state)
    -- Fortschritt: Stapel, die schon in den Taschen sind
    local slots, total = 0, 0
    if BB.job then slots = getn(BB.job.slots) end
    total = BB.Count(remaining(r))
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -110)
    if BB.job then f.bar:Set(slots, math.max(total, slots), "open") else f.bar:SetValue(0, { 1, 0.7, 0.2 }, T("LO_NOTYET")) end
    local now = BB:RequestCodTotals(r)
    place(f.cl1, f, -126)
    f.cl1:SetText(T("LO_COD"))
    f.cv1:ClearAllPoints()
    f.cv1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -125)
    f.cv1:SetText(now > 0 and BB.Money(now) or T("LO_NONE"))
    f.b2:ClearAllPoints()
    f.b2:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -142)
    f.b2:SetWidth(W - 20)
    setBtnText(f.b2, T("LO_FETCH"))
    f.b2:SetOn(not BB.job)
    f.chk2:ClearAllPoints()
    f.chk2:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -168)
    f.chk2.Update()
    return
  end

  if step == 3 then
    local p = BB.prep
    showOnly(f, { f.t1, f.t2, f.cl1, f.cv1, f.cl2, f.cv2, f.b2, f.chk })
    place(f.t1, f, -64)
    local e = p and p.slots[p.idx]
    if p and e then
      local qn = BB.queue and getn(BB.queue) or 0
      f.t1:SetText(string.format(T("LO_MAIL_T"), p.idx, getn(p.slots), p.r.p) .. (qn > 0 and string.format(T("LO_QUEUE"), qn) or ""))
      f.t2:SetText(BB:ColoredName(e.id) .. " x" .. e.c .. (BB.mailOpen and "" or ("\n" .. T("LO_OPEN_MAIL"))))
    else
      f.t1:SetText(T("LO_DONE"))
      f.t2:SetText("")
    end
    place(f.t2, f, -80)
    place(f.cl1, f, -110)
    f.cl1:SetText(T("LO_COD_WANT"))
    f.cv1:ClearAllPoints()
    f.cv1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -109)
    place(f.cl2, f, -125)
    f.cl2:SetText(T("LO_COD_WIN"))
    f.cv2:ClearAllPoints()
    f.cv2:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -124)
    f.cv2:SetText("")
    f.b2:ClearAllPoints()
    f.b2:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -142)
    f.b2:SetWidth(W - 20)
    if p and e then setBtnText(f.b2, string.format(T("BTN_SEND_N"), p.idx, getn(p.slots))) else setBtnText(f.b2, T("BTN_SEND")) end
    f.b2:SetOn(p ~= nil and e ~= nil and not p.sending and BB.mailOpen and true or false)
    f.chk:ClearAllPoints()
    f.chk:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -168)
    f.chk:SetWidth(W - 100)
    f.chk.Update()
    f.bOv:Show()
    f.bOv:ClearAllPoints()
    f.bOv:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -168)
    self:LotseLive()
    return
  end

  -- Schritt 4: fertig
  showOnly(f, { f.t1, f.t2, f.foot, f.b2, f.b4 })
  place(f.t1, f, -64)
  local complete = BB:RequestComplete(r)
  f.t1:SetText(complete and T("LO_DONE") or T("LO_DONE_PART"))
  f.t1:SetTextColor(0.35, 0.88, 0.42)
  place(f.t2, f, -80)
  f.t2:SetText(string.format(T("LO_WHISPERED"), r.p))
  local nextCount = 0
  for i = 1, getn(here) do if here[i].r ~= r then nextCount = nextCount + 1 end end
  place(f.foot, f, -108)
  f.foot:SetHeight(46)
  local footTxt = ""
  if not complete then
    local cls, short = BB:LotseClass(r)
    local per = {}
    BB:LotseElsewhere(short, per)
    local names = {}
    for bank in pairs(per) do table.insert(names, bank) end
    table.sort(names)
    if getn(names) > 0 then footTxt = string.format(T("LO_REST"), table.concat(names, ", ")) end
  end
  if nextCount == 0 and et then footTxt = footTxt .. (footTxt ~= "" and "\n" or "") .. et end
  f.foot:SetText(footTxt)
  f.foot:SetTextColor(1, 0.65, 0.2)
  f.b2:ClearAllPoints()
  f.b2:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 36)
  f.b2:SetWidth(W - 20)
  if nextCount > 0 then
    setBtnText(f.b2, string.format(T("LO_NEXT"), nextCount))
    f.b2:SetOn(true)
  else
    setBtnText(f.b2, T("LO_NEXT0"))
    f.b2:SetOn(false)
  end
  f.b4:ClearAllPoints()
  f.b4:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
  setBtnText(f.b4, T("LO_CLOSE"))
end

-- Kompakte Zeile (B)
function UI:LotseFillMini(r, step, here)
  local f = self.lotse
  f.t1:SetTextColor(1, 1, 1)
  if not r then
    f.mini:SetText(T("LO_IDLE"))
    f.miniBtn:SetOn(false)
    setBtnText(f.miniBtn, T("LO_CLOSE"))
    return
  end
  if step == 1 then
    local now = BB:RequestCodTotals(r)
    f.mini:SetText(r.id .. " - " .. (now > 0 and BB.Money(now) or T("LO_NONE")))
    setBtnText(f.miniBtn, (r.cl and next(r.cl) ~= nil) and T("LO_MINI_ACCEPT") or T("BTN_CONFIRM"))
    f.miniBtn:SetOn(BB:ReqState(r) == "open")
  elseif step == 2 then
    f.mini:SetText("2/4 " .. (BB.bankOpen and T("LO_MINI_READY") or T("LO_HINT_BANK_SHORT")))
    setBtnText(f.miniBtn, T("LO_FETCH"))
    f.miniBtn:SetOn(not BB.job)
  elseif step == 3 then
    local p = BB.prep
    f.mini:SetText("")
    setBtnText(f.miniBtn, T("LO_SEND_SHORT"))
    f.miniBtn:SetOn(p ~= nil and p.slots[p.idx] ~= nil and not p.sending and BB.mailOpen and true or false)
    self:LotseLive()
  else
    local n = 0
    for i = 1, getn(here) do if here[i].r ~= r then n = n + 1 end end
    f.mini:SetText(T("LO_DONE"))
    setBtnText(f.miniBtn, n > 0 and T("LO_NEXT_SHORT") or T("LO_CLOSE"))
    f.miniBtn:SetOn(true)
  end
end

-- ------------------------------------------------------------
-- Versandübersicht: alle vorbereiteten Anfragen mit Items, Preisen und Hinweisen untereinander
-- ------------------------------------------------------------
local OV_ROWS, OV_ROW_H = 14, 20

function UI:BuildSendOverview()
  if self.ovWin then return end
  local f = CreateFrame("Frame", "BananaBankSendOverview", UIParent)
  self.ovWin = f
  f:SetWidth(480)
  f:SetHeight(130 + OV_ROWS * OV_ROW_H + 40)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetBackdropColor(0.015, 0.025, 0.06, 1)
  self:Solid(f, 12, 1)
  f:Hide()
  tinsert(UISpecialFrames, "BananaBankSendOverview")
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
  local title = self:Font(f, 20, UI.C.gold, UI.FONT_TITLE)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -20)
  self:Loc(title, "OV_TITLE")
  self:GlowLine(f, -50, 20, -20)
  f.sum = self:Font(f, 11, UI.C.text)
  f.sum:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -58)
  f.sum:SetWidth(430)
  f.sum:SetHeight(14)
  f.hint = self:Font(f, 10, UI.C.muted)
  f.hint:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -76)
  f.hint:SetWidth(430)
  f.hint:SetHeight(14)

  local sf = CreateFrame("ScrollFrame", "BananaBankOverviewScroll", f, "FauxScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -98)
  sf:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -46, -98 - OV_ROWS * OV_ROW_H)
  sf:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(OV_ROW_H, function() UI:RefreshSendOverview() end)
  end)
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function()
    local sb = getglobal("BananaBankOverviewScrollScrollBar")
    if sb then sb:SetValue(sb:GetValue() - arg1 * OV_ROW_H) end
  end)
  f.sf = sf
  f.rows = {}
  for i = 1, OV_ROWS do
    local row = CreateFrame("Frame", nil, f)
    row:SetHeight(OV_ROW_H - 2)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -98 - (i - 1) * OV_ROW_H)
    row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -54, -98 - (i - 1) * OV_ROW_H)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetTexture(WHITE)
    row.bg:SetAllPoints(row)
    row.l = self:Font(row, 11, UI.C.text)
    row.l:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.l:SetWidth(300)
    row.l:SetHeight(14)
    row.sub = self:Font(row, 10, UI.C.muted)
    row.sub:SetPoint("RIGHT", row, "RIGHT", -120, 0)
    row.sub:SetJustifyH("RIGHT")
    row.r = self:Font(row, 11, UI.C.gold)
    row.r:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.r:SetWidth(110)
    row.r:SetJustifyH("RIGHT")
    f.rows[i] = row
  end
  local go = self:Button(f, 160, 22, "OV_GO", function()
    f:Hide()
    if BB.mailOpen then BB:SendNextMail() end
    UI:Refresh()
  end, "primary")
  go:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 26, 22)
  f.go = go
  local done = self:Button(f, 120, 22, "OV_CLOSE", function() f:Hide() end)
  done:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 22)
end

function UI:RefreshSendOverview()
  local f = self.ovWin
  if not f then return end
  local lines, nReq, nLetters, total = BB:SendOverview()
  f.lines = lines
  f.sum:SetText(string.format(T("OV_SUMMARY"), nReq, nLetters, total > 0 and BB.Money(total) or T("OV_FREE")))
  f.hint:SetText(BB.mailOpen and "" or T("OV_OPEN_MAIL"))
  FauxScrollFrame_Update(f.sf, getn(lines), OV_ROWS, OV_ROW_H)
  local offset = FauxScrollFrame_GetOffset(f.sf)
  if type(offset) ~= "number" then offset = 0 end
  for i = 1, OV_ROWS do
    local row = f.rows[i]
    local e = lines[offset + i]
    if e then
      row:Show()
      row.sub:SetText("")
      row.r:SetText(e.r or "")
      row.l:SetText(e.l or "")
      if e.kind == "head" then
        row.bg:SetVertexColor(1, 0.82, 0.3, 0.14)
        row.l:SetTextColor(UI.C.gold[1], UI.C.gold[2], UI.C.gold[3])
        row.sub:SetText(e.sub or "")
      elseif e.kind == "warn" then
        row.bg:SetVertexColor(0, 0, 0, 0)
        row.l:SetTextColor(1, 0.65, 0.2)
      else
        row.bg:SetVertexColor(0, 0, 0, 0)
        row.l:SetTextColor(UI.C.text[1], UI.C.text[2], UI.C.text[3])
      end
    else
      row:Hide()
    end
  end
  f.go:SetOn(nReq > 0)
end

function UI:OpenSendOverview()
  self:BuildSendOverview()
  self.ovWin:Show()
  self:RefreshSendOverview()
end
