-- BananaBank UI Teil 5: Mitglieder-Fenster und Summen-Fenster (aus dem Spendenbuch)

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local floor = math.floor
local WHITE, FONT, FONT_TITLE = UI.WHITE, UI.FONT, UI.FONT_TITLE

UI.summaryModule = true
UI.mw = { mode = "in", view = "list", name = nil }
UI.tw = { mode = "in", sort = "qty", filter = "" }

local ROW_H = 34
local VISIBLE = 10
local COIN = "Interface\\Icons\\INV_Misc_Coin_01"

-- Farben je Art: Spenden gruen, Entnahmen orange, wie in den Spalten des Spendenbuchs
local MODE_COLOR = { ["in"] = C.green, out = C.orange }

-- ------------------------------------------------------------
-- Bausteine
-- ------------------------------------------------------------
local function makeWindow(name, w, h)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetWidth(w)
  f:SetHeight(h)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetBackdrop({
    bgFile = WHITE,
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 1)
  UI:Solid(f, 12, 1)
  f:Hide()
  tinsert(UISpecialFrames, name)
  local head = f:CreateTexture(nil, "BORDER")
  head:SetTexture(WHITE)
  head:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -12)
  head:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -12, -66)
  head:SetGradientAlpha("VERTICAL", C.bg[1], C.bg[2], C.bg[3], 0, C.blue[1], C.blue[2], C.blue[3], 0.75)
  f.heading = UI:Font(f, 22, C.gold, FONT_TITLE)
  f.heading:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -20)
  f.heading:SetWidth(380)
  f.heading:SetHeight(26)
  f.sub = UI:Font(f, 11, C.muted)
  f.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 27, -48)
  f.sub:SetWidth(470)
  f.sub:SetHeight(13)
  UI:GlowLine(f, -66, 20, -20)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
  return f
end

-- Liste mit Scrollleiste. rows: ROW_H hoch, VISIBLE Stueck, werden vom Aufrufer gefuellt.
local function buildScroll(f, lp, sname, onUpdate, makeRow)
  local sf = CreateFrame("ScrollFrame", sname, lp, "FauxScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", lp, "TOPLEFT", 4, -30)
  sf:SetPoint("BOTTOMRIGHT", lp, "BOTTOMRIGHT", -4, 6)
  sf:SetScript("OnVerticalScroll", function() FauxScrollFrame_OnVerticalScroll(ROW_H, onUpdate) end)
  local function wheel()
    local sb = getglobal(sname .. "ScrollBar")
    if sb then sb:SetValue(sb:GetValue() - arg1 * ROW_H * 2) end
  end
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", wheel)
  lp:EnableMouseWheel(true)
  lp:SetScript("OnMouseWheel", wheel)
  local rows = {}
  for i = 1, VISIBLE do
    local row = makeRow(lp, i)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", wheel)
    table.insert(rows, row)
  end
  sf.rows = rows
  return sf
end

local function resetScroll(sf, sname)
  sf.offset = 0
  local sb = getglobal(sname .. "ScrollBar")
  if sb then sb:SetValue(0) end
end

local function scrollOffset(sf, n)
  if FauxScrollFrame_Update then FauxScrollFrame_Update(sf, n, VISIBLE, ROW_H) end
  return (FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(sf)) or sf.offset or 0
end

local function showTip(owner, id, name, quality, extra)
  if extra then
    for i = 1, getn(extra) do extra[i][2] = tostring(extra[i][2] or "") end
  end
  if id and id ~= 0 then
    UI:ItemTooltip(owner, id, extra)
    return
  end
  local qc = BB.QUALITY_COLOR[quality or 1] or BB.QUALITY_COLOR[1]
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(name, qc[1], qc[2], qc[3])
  if extra then
    GameTooltip:AddLine(" ")
    for i = 1, getn(extra) do
      local l = extra[i]
      GameTooltip:AddDoubleLine(l[1], l[2] or "", 0.8, 0.8, 0.8, l[3] or 1, l[4] or 1, l[5] or 1)
    end
  end
  GameTooltip:Show()
end

-- eine Listenzeile mit Item-Feld und vier Spalten
local function makeRow(lp, i, cols)
  local row = CreateFrame("Button", nil, lp)
  row:SetHeight(ROW_H - 2)
  row:SetPoint("TOPLEFT", lp, "TOPLEFT", 8, -32 - (i - 1) * ROW_H)
  row:SetPoint("TOPRIGHT", lp, "TOPRIGHT", -28, -32 - (i - 1) * ROW_H)
  row.stripe = row:CreateTexture(nil, "BACKGROUND")
  row.stripe:SetTexture(WHITE)
  row.stripe:SetAllPoints(row)
  row.stripe:SetVertexColor(1, 1, 1, mod(i, 2) == 0 and 0.045 or 0.0)
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture(WHITE)
  hl:SetAllPoints(row)
  hl:SetVertexColor(1, 0.82, 0.3, 0.10)
  row.slot = UI:Slot(row, 28)
  row.slot:SetPoint("LEFT", row, "LEFT", 2, 0)
  row.slot:EnableMouse(false)
  row.name = UI:Font(row, 12, C.text)
  row.name:SetPoint("LEFT", row, "LEFT", 38, 0)
  row.name:SetWidth(cols.name)
  row.name:SetHeight(14)
  row.c2 = UI:Font(row, 11, C.muted)
  row.c2:SetPoint("LEFT", row, "LEFT", cols.x2, 0)
  row.c2:SetWidth(cols.w2)
  row.c2:SetHeight(13)
  row.c3 = UI:Font(row, 11, C.text)
  row.c3:SetPoint("LEFT", row, "LEFT", cols.x3, 0)
  row.c3:SetWidth(cols.w3)
  row.c3:SetHeight(13)
  row.c4 = UI:Font(row, 11, C.text)
  row.c4:SetPoint("RIGHT", row, "RIGHT", -2, 0)
  row.c4:SetWidth(cols.w4)
  row.c4:SetJustifyH("RIGHT")
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return row
end

local function stackWord(n)
  if n == 1 then return string.format(T("MW_STACK_ONE"), n) end
  return string.format(T("MW_STACK_MANY"), n)
end

-- ------------------------------------------------------------
-- Mitglieder-Fenster
-- ------------------------------------------------------------
local MCOLS = { name = 172, x2 = 212, w2 = 84, x3 = 300, w3 = 104, w4 = 70 }

function UI:BuildMemberWindow()
  if self.mwf then return end
  local M = self.mw
  local f = makeWindow("BananaBankMemberFrame", 560, 548)
  self.mwf = f

  M.chipIn = self:Chip(f, 104, "MW_GIVEN", function() M.mode = "in" UI:MemberReset() end)
  M.chipIn:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -76)
  M.chipOut = self:Chip(f, 104, "MW_TAKEN", function() M.mode = "out" UI:MemberReset() end)
  M.chipOut:SetPoint("LEFT", M.chipIn, "RIGHT", 4, 0)
  M.chipItems = self:Chip(f, 92, "MW_VIEW_ITEMS", function() M.view = "items" UI:MemberReset() end)
  M.chipItems:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -76)
  M.chipList = self:Chip(f, 92, "MW_VIEW_LIST", function() M.view = "list" UI:MemberReset() end)
  M.chipList:SetPoint("RIGHT", M.chipItems, "LEFT", -4, 0)

  local lp = self:Panel(f, 0, 0)
  lp:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -102)
  lp:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 62)
  M.lp = lp
  M.h = {}
  local hx = { 46, 220, 308 }
  for i = 1, 3 do
    local fs = self:Font(lp, 10, C.goldDim)
    fs:SetPoint("TOPLEFT", lp, "TOPLEFT", hx[i], -10)
    table.insert(M.h, fs)
  end
  M.h4 = self:Font(lp, 10, C.goldDim)
  M.h4:SetPoint("TOPRIGHT", lp, "TOPRIGHT", -30, -10)
  M.h4:SetJustifyH("RIGHT")
  self:HLine(lp, -26, 10, -10, C.brass, 0.9)

  M.sf = buildScroll(f, lp, "BananaBankMemberScroll", function() UI:RefreshMember() end, function(parent, i)
    local row = makeRow(parent, i, MCOLS)
    row:SetScript("OnEnter", function() UI:MemberTip(this) end)
    return row
  end)
  M.empty = self:Font(lp, 12, C.muted)
  M.empty:SetPoint("TOP", lp, "TOP", 0, -80)
  M.empty:SetJustifyH("CENTER")
  self:Loc(M.empty, "MW_EMPTY")

  M.foot = self:Font(f, 11, C.text)
  M.foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 26, 28)
  M.foot:SetWidth(280)
  M.foot:SetHeight(14)
  local tot = self:Button(f, 120, 24, "MW_BTN_TOTALS", function() UI:OpenTotalsWindow(M.mode) end, "primary")
  tot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -150, 22)
  local close = self:Button(f, 110, 24, "MW_CLOSE", function() f:Hide() end)
  close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 22)
end

function UI:OpenMemberWindow(name, mode)
  if not name then return end
  self:BuildMemberWindow()
  local M = self.mw
  M.name = name
  M.mode = mode or "in"
  self.mwf.heading:SetText(name)
  self.mwf:Show()
  self:MemberReset()
end

function UI:MemberReset()
  local M = self.mw
  resetScroll(M.sf, "BananaBankMemberScroll")
  self:RefreshMember()
end

function UI:RefreshMember()
  local M = self.mw
  local f = self.mwf
  if not f or not f:IsVisible() or M.busy or not M.name then return end
  M.chipIn:SetActive(M.mode == "in")
  M.chipOut:SetActive(M.mode == "out")
  M.chipList:SetActive(M.view == "list")
  M.chipItems:SetActive(M.view == "items")
  local d = BB:MemberData(M.name, M.mode)
  local mc = MODE_COLOR[M.mode]
  if M.mode == "in" then
    f.sub:SetText(string.format(T("MW_SUM_IN"), d.nstacks, d.nitems, BB.Money(d.gold)))
  else
    f.sub:SetText(string.format(T("MW_SUM_OUT"), d.nstacks, d.nitems, BB.Money(d.gold), BB.Money(d.paid)))
  end
  if M.view == "list" then
    M.h[1]:SetText(T("MW_COL_ITEM"))
    M.h[2]:SetText(T("MW_COL_DATE"))
    M.h[3]:SetText(T("MW_COL_SRC"))
    M.h4:SetText(M.mode == "out" and T("MW_COL_PRICE") or "")
  else
    M.h[1]:SetText(T("MW_COL_ITEM"))
    M.h[2]:SetText(T("MW_COL_STACKS"))
    M.h[3]:SetText(T("MW_COL_TOTAL"))
    M.h4:SetText(T("MW_COL_LAST"))
  end

  -- Zeilen vorbereiten
  local data = {}
  if M.view == "list" then
    data = d.rows
  else
    if d.gold > 0 then table.insert(data, { kind = "goldsum", m = d.gold, label = M.mode == "in" and "gold" or "gout" }) end
    if d.paid > 0 then table.insert(data, { kind = "goldsum", m = d.paid, label = "cod" }) end
    for i = 1, getn(d.items) do table.insert(data, { kind = "item", it = d.items[i] }) end
  end
  M.data = data
  local n = getn(data)
  M.busy = true
  local offset = scrollOffset(M.sf, n)
  M.busy = false
  for i = 1, VISIBLE do
    local row = M.sf.rows[i]
    local r = data[offset + i]
    row.data = r
    if r then
      self:MemberFillRow(row, r, mc)
      row:Show()
    else
      row:Hide()
    end
  end
  if n == 0 then M.empty:Show() else M.empty:Hide() end
  if M.mode == "in" then
    M.foot:SetText(string.format(T("MW_FOOT_IN"), d.nitems))
  else
    M.foot:SetText(string.format(T("MW_FOOT_OUT"), d.nitems - d.back, d.back))
  end
end

local function fillItemSlot(slot, id, name, q, count)
  local tex, rid = BB:SummaryIcon(id, name)
  slot.icon:SetTexture(tex)
  slot:SetQuality(q)
  slot.count:SetText((count and count > 1) and tostring(count) or "")
  return rid
end

local function labelOf(kind)
  if kind == "gold" then return T("MW_GOLD_IN") end
  if kind == "gout" then return T("MW_GOLD_OUT") end
  return T("MW_PAID")
end

function UI:MemberFillRow(row, r, mc)
  local M = self.mw
  row.name:SetTextColor(C.text[1], C.text[2], C.text[3])
  row.c3:SetTextColor(C.text[1], C.text[2], C.text[3])
  row.c4:SetText("")
  if r.kind == "stack" then
    local s = r.s
    local qc = BB.QUALITY_COLOR[s.q or 1] or BB.QUALITY_COLOR[1]
    fillItemSlot(row.slot, s.i, s.n, s.q, s.c)
    row.name:SetText(s.n)
    row.name:SetTextColor(qc[1], qc[2], qc[3])
    row.c2:SetText(BB.Date(s.t))
    row.c3:SetText(BB:StackSource(s, M.mode))
    if M.mode == "out" and s.m > 0 then row.c4:SetText(BB.Money(s.m)) end
  elseif r.kind == "money" then
    row.slot.icon:SetTexture(COIN)
    row.slot:SetQuality(1)
    row.slot.count:SetText("")
    row.name:SetText(labelOf(r.label))
    row.name:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    row.c2:SetText(BB.Date(r.t))
    row.c3:SetText("")
    row.c4:SetText(BB.Money(r.m))
  elseif r.kind == "back" then
    local e = r.e
    fillItemSlot(row.slot, e.i, e.n, e.q, e.c)
    row.name:SetText(e.n)
    row.name:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    row.c2:SetText(BB.Date(r.t))
    row.c3:SetText(T("MW_BACK"))
    row.c3:SetTextColor(C.orange[1], C.orange[2], C.orange[3])
  elseif r.kind == "goldsum" then
    row.slot.icon:SetTexture(COIN)
    row.slot:SetQuality(1)
    row.slot.count:SetText("")
    row.name:SetText(labelOf(r.label))
    row.name:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    row.c2:SetText("")
    row.c3:SetText(T("MW_SUM_TOTAL"))
    row.c4:SetText(BB.Money(r.m))
  else
    local it = r.it
    local qc = BB.QUALITY_COLOR[it.q or 1] or BB.QUALITY_COLOR[1]
    fillItemSlot(row.slot, it.i, it.n, it.q, nil)
    row.name:SetText(it.n)
    row.name:SetTextColor(qc[1], qc[2], qc[3])
    row.c2:SetText(stackWord(it.stacks))
    row.c3:SetText(tostring(it.net))
    row.c3:SetTextColor(mc[1], mc[2], mc[3])
    row.c4:SetText(BB.Date(it.last))
  end
end

function UI:MemberTip(row)
  local r = row.data
  local M = self.mw
  if not r then return end
  if r.kind == "stack" then
    local s = r.s
    local extra = {
      { T("MW_TT_STACK"), s.c, 1, 1, 1 },
      { T("MW_TT_WHEN"), BB.Date(s.t) },
    }
    for i = 1, getn(s.parts) do
      local code = s.parts[i].code
      local q = code ~= "" and BananaBankDB.quests[code]
      if q then table.insert(extra, { string.format(T("MW_TT_QUEST"), s.parts[i].c, q.title), "", 0.9, 0.8, 0.4 }) end
    end
    if s.code ~= "" and M.mode == "out" then
      table.insert(extra, { BB:StackSource(s, "out"), "" })
    end
    if M.mode == "out" and s.m > 0 then table.insert(extra, { T("MW_TT_PRICE"), BB.Money(s.m) }) end
    showTip(row, s.i, s.n, s.q, extra)
  elseif r.kind == "item" then
    local it = r.it
    local extra = {
      { T("MW_TT_TOTAL"), it.net, 1, 1, 1 },
      { T("MW_COL_STACKS"), it.stacks or "" },
      { T("MW_TT_LAST"), BB.Date(it.last) },
    }
    if it.back > 0 then table.insert(extra, { T("MW_BACK"), it.back, 1, 0.6, 0.2 }) end
    showTip(row, it.i, it.n, it.q, extra)
  elseif r.kind == "back" then
    local e = r.e
    showTip(row, e.i, e.n, e.q, { { T("MW_BACK"), e.c }, { T("MW_TT_WHEN"), BB.Date(e.t) } })
  else
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(labelOf(r.label), C.gold[1], C.gold[2], C.gold[3])
    GameTooltip:AddLine(BB.Money(r.m), 1, 1, 1)
    GameTooltip:Show()
  end
end

-- ------------------------------------------------------------
-- Summen-Fenster: wie viel von welchem Material, ueber die ganze Gilde
-- ------------------------------------------------------------
local TCOLS = { name = 214, x2 = 256, w2 = 70, x3 = 330, w3 = 84, w4 = 70 }

function UI:BuildTotalsWindow()
  if self.twf then return end
  local W = self.tw
  local f = makeWindow("BananaBankTotalsFrame", 560, 580)
  self.twf = f
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", 40, 0)

  W.chipIn = self:Chip(f, 104, "TW_GIVEN", function() W.mode = "in" UI:TotalsReset() end)
  W.chipIn:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -76)
  W.chipOut = self:Chip(f, 104, "TW_TAKEN", function() W.mode = "out" UI:TotalsReset() end)
  W.chipOut:SetPoint("LEFT", W.chipIn, "RIGHT", 4, 0)
  W.chipName = self:Chip(f, 84, "TW_SORT_NAME", function() W.sort = "name" UI:TotalsReset() end)
  W.chipName:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -76)
  W.chipQty = self:Chip(f, 84, "TW_SORT_QTY", function() W.sort = "qty" UI:TotalsReset() end)
  W.chipQty:SetPoint("RIGHT", W.chipName, "LEFT", -4, 0)

  local sl = self:Font(f, 10, C.goldDim)
  sl:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -108)
  self:Loc(sl, "TW_SEARCH")
  W.search = self:EditBox("BananaBankTotalsSearch", f, 250)
  W.search:SetPoint("TOPLEFT", f, "TOPLEFT", 128, -102)
  W.search:SetMaxLetters(40)
  W.search:SetScript("OnTextChanged", function()
    W.filter = string.lower(this:GetText() or "")
    UI:TotalsReset()
  end)

  local lp = self:Panel(f, 0, 0)
  lp:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -130)
  lp:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 62)
  W.lp = lp
  local hx = { 46, 264, 338 }
  local hk = { "MW_COL_ITEM", "MW_COL_TOTAL", "MW_COL_STACKS" }
  for i = 1, 3 do
    local fs = self:Font(lp, 10, C.goldDim)
    fs:SetPoint("TOPLEFT", lp, "TOPLEFT", hx[i], -10)
    self:Loc(fs, hk[i])
  end
  local h4 = self:Font(lp, 10, C.goldDim)
  h4:SetPoint("TOPRIGHT", lp, "TOPRIGHT", -30, -10)
  h4:SetJustifyH("RIGHT")
  self:Loc(h4, "TW_COL_WHO")
  self:HLine(lp, -26, 10, -10, C.brass, 0.9)

  W.sf = buildScroll(f, lp, "BananaBankTotalsScroll", function() UI:RefreshTotals() end, function(parent, i)
    local row = makeRow(parent, i, TCOLS)
    row:SetScript("OnEnter", function() UI:TotalsTip(this) end)
    return row
  end)
  W.empty = self:Font(lp, 12, C.muted)
  W.empty:SetPoint("TOP", lp, "TOP", 0, -80)
  W.empty:SetJustifyH("CENTER")
  self:Loc(W.empty, "MW_EMPTY")

  W.foot = self:Font(f, 11, C.text)
  W.foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 26, 28)
  W.foot:SetWidth(330)
  W.foot:SetHeight(14)
  local close = self:Button(f, 110, 24, "MW_CLOSE", function() f:Hide() end)
  close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 22)
end

function UI:OpenTotalsWindow(mode)
  self:BuildTotalsWindow()
  local W = self.tw
  W.mode = mode or W.mode or "in"
  self.twf:Show()
  self:TotalsReset()
end

function UI:TotalsReset()
  local W = self.tw
  if not W.sf then return end
  resetScroll(W.sf, "BananaBankTotalsScroll")
  self:RefreshTotals()
end

function UI:RefreshTotals()
  local W = self.tw
  local f = self.twf
  if not f or not f:IsVisible() or W.busy then return end
  W.chipIn:SetActive(W.mode == "in")
  W.chipOut:SetActive(W.mode == "out")
  W.chipQty:SetActive(W.sort == "qty")
  W.chipName:SetActive(W.sort == "name")
  f.heading:SetText(T(W.mode == "in" and "TW_TITLE_IN" or "TW_TITLE_OUT"))
  local g = BB:GuildTotals(W.mode)
  f.sub:SetText(string.format(T("TW_SUB"), getn(g.items), g.nstacks, g.nitems, g.nplayers))
  local list = {}
  -- Spendername (Anfang des Namens): alle Items dieser Person, einzeln aufgefuehrt statt zusammengefasst
  local donorMode = false
  if W.filter ~= "" then
    for i = 1, getn(g.items) do
      for who, c in pairs(g.items[i].who) do
        if c > 0 and string.find(string.lower(who), W.filter, 1, true) == 1 then donorMode = true break end
      end
      if donorMode then break end
    end
  end
  for i = 1, getn(g.items) do
    local it = g.items[i]
    if donorMode then
      local sum, names = 0, nil
      for who, c in pairs(it.who) do
        if c > 0 and string.find(string.lower(who), W.filter, 1, true) == 1 then
          sum = sum + c
          names = names and (names .. ", " .. who) or who
        end
      end
      if sum > 0 then
        table.insert(list, { i = it.i, n = it.n, q = it.q, net = sum, last = it.last, who = it.who, donor = names })
      end
    elseif W.filter == "" or string.find(string.lower(it.n), W.filter, 1, true) then
      table.insert(list, it)
    end
  end
  if W.sort == "name" then
    table.sort(list, function(a, b) return a.n < b.n end)
  end
  W.list = list
  local n = getn(list)
  W.busy = true
  local offset = scrollOffset(W.sf, n)
  W.busy = false
  local mc = MODE_COLOR[W.mode]
  for i = 1, VISIBLE do
    local row = W.sf.rows[i]
    local it = list[offset + i]
    row.it = it
    if it then
      local qc = BB.QUALITY_COLOR[it.q or 1] or BB.QUALITY_COLOR[1]
      fillItemSlot(row.slot, it.i, it.n, it.q, nil)
      row.name:SetText(it.n)
      row.name:SetTextColor(qc[1], qc[2], qc[3])
      row.c2:SetText(tostring(it.net))
      row.c2:SetTextColor(mc[1], mc[2], mc[3])
      row.c3:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
      if it.donor then
        row.c3:SetText("")
        row.c4:SetText(it.donor)
      else
        row.c3:SetText(stackWord(it.stacks))
        local who = 0
        for _ in pairs(it.who) do who = who + 1 end
        row.c4:SetText(string.format(T("TW_WHO"), who))
      end
      row:Show()
    else
      row:Hide()
    end
  end
  if n == 0 then W.empty:Show() else W.empty:Hide() end
  W.foot:SetText(string.format(T("TW_FOOT"), BB.Money(g.gold)))
end

function UI:TotalsTip(row)
  local it = row.it
  if not it then return end
  local extra = {
    { T("TW_TT_TOTAL"), it.net, 1, 1, 1 },
    { T("MW_COL_STACKS"), it.stacks or "" },
    { T("MW_TT_LAST"), BB.Date(it.last) },
    { " ", "" },
    { T("TW_TT_TOP"), "", C.gold[1], C.gold[2], C.gold[3] },
  }
  local donors = BB:ItemDonors(it)
  for i = 1, math.min(getn(donors), 6) do
    table.insert(extra, { donors[i].p, donors[i].c, 1, 1, 1 })
  end
  showTip(row, it.i, it.n, it.q, extra)
end

-- Fenster aktuell halten, wenn sich das Spendenbuch aendert
function UI:RefreshSummaryWindows()
  if self.mwf and self.mwf:IsVisible() then self:RefreshMember() end
  if self.twf and self.twf:IsVisible() then self:RefreshTotals() end
end
