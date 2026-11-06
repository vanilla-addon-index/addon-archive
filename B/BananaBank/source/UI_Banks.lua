-- BananaBank UI Teil 6: Banken-Reiter, Rollen-Editor, Bankwahl im Bestand

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local floor = math.floor
local WHITE, FONT, FONT_TITLE = UI.WHITE, UI.FONT, UI.FONT_TITLE

UI.bankUIModule = true
UI.bk = {}

local ROW_H = 38
local VISIBLE = 8
local MENU_ROW = 38
local MENU_MAX = 9

local ON = { 0.35, 0.88, 0.42 }
local OFF = { 0.50, 0.50, 0.56 }

local function dotColor(name)
  if BB:IsOnline(name) then return ON end
  return OFF
end

-- ------------------------------------------------------------
-- Bankwahl im Bestand
-- ------------------------------------------------------------
function UI:RefreshBankButton()
  local S = self.stock
  if not S or not S.bankBtn then return end
  -- Die Bankauswahl als Menue entfaellt: einen einzelnen Bank-Char zeigt Banken > "Inhalt zeigen".
  -- Dann steht in der Werkzeugleiste ein Knopf "Bank: X x", der zurueck auf alle Banken schaltet.
  S.bankBtn:Hide()
  S.role:SetText("")
  self:CloseBankMenu()
  if not BB:IsBank() then
    S.bank = nil
    S.onlyTrash = false
    if S.trashChk then S.trashChk:Hide() end
    if S.bankChip then S.bankChip:Hide() end
    return
  end
  if S.trashChk then S.trashChk:Show() end
  if S.bankChip then
    if S.bank then
      S.bankChip.fs:SetText(string.format(T("SB_CHIP"), S.bank))
      S.bankChip:SetActive(true)
      S.bankChip:Show()
    else
      S.bankChip:Hide()
    end
  end
end

function UI:BuildBankMenu()
  if self.bmenu then return end
  local catch = CreateFrame("Button", nil, UIParent)
  catch:SetAllPoints(UIParent)
  catch:SetFrameStrata("DIALOG")
  catch:Hide()
  catch:SetScript("OnClick", function() UI:CloseBankMenu() end)
  -- voll deckend: eigener Hintergrund aus einfarbiger Flaeche statt des halbtransparenten Tooltip-Hintergrunds
  local m = CreateFrame("Frame", nil, UIParent)
  m:SetWidth(330)
  m:SetHeight(100)
  m:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  m:SetBackdropColor(0.015, 0.025, 0.06, 1)
  m:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1)
  m:SetFrameStrata("FULLSCREEN_DIALOG")
  m:EnableMouse(true)
  m:Hide()
  m.catch = catch
  m.rows = {}
  for i = 1, MENU_MAX do
    local row = CreateFrame("Button", nil, m)
    row:SetHeight(MENU_ROW - 2)
    row:SetPoint("TOPLEFT", m, "TOPLEFT", 6, -6 - (i - 1) * MENU_ROW)
    row:SetPoint("TOPRIGHT", m, "TOPRIGHT", -6, -6 - (i - 1) * MENU_ROW)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetTexture(WHITE)
    row.bg:SetAllPoints(row)
    row.bg:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0.26, 0.38, 1, 0.82, 0.26, 0.05)
    row.sep = row:CreateTexture(nil, "BORDER")
    row.sep:SetTexture(WHITE)
    row.sep:SetHeight(1)
    row.sep:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, -1)
    row.sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, -1)
    row.sep:SetVertexColor(C.brass[1], C.brass[2], C.brass[3], 0.35)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(WHITE)
    hl:SetAllPoints(row)
    hl:SetVertexColor(1, 0.82, 0.3, 0.10)
    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetTexture(WHITE)
    row.dot:SetWidth(8)
    row.dot:SetHeight(8)
    row.dot:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -8)
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetTexture(WHITE)
    row.stripe:SetAllPoints(row)
    row.stripe:SetVertexColor(1, 1, 1, mod(i, 2) == 0 and 0.07 or 0.0)
    row.name = self:Font(row, 12, { 1, 1, 1 })
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 20, -5)
    row.name:SetWidth(170)
    row.name:SetHeight(14)
    row.cnt = self:Font(row, 10, { 0.80, 0.82, 0.90 })
    row.cnt:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -7)
    row.cnt:SetJustifyH("RIGHT")
    row.role = self:Font(row, 10, { 0.98, 0.80, 0.38 })
    row.role:SetPoint("TOPLEFT", row, "TOPLEFT", 20, -20)
    row.role:SetWidth(290)
    row.role:SetHeight(12)
    row.index = i
    row:SetScript("OnClick", function()
      local m2 = UI.bmenu
      local e = m2.entries and m2.entries[this.index]
      if not e then return end
      PlaySound("igMainMenuOptionCheckBoxOn")
      UI.stock.bank = e.bank
      UI.stock.page = 1
      UI:CloseBankMenu()
      UI:RefreshStock()
    end)
    table.insert(m.rows, row)
  end
  self.bmenu = m
end

function UI:CloseBankMenu()
  if not self.bmenu then return end
  self.bmenu:Hide()
  self.bmenu.catch:Hide()
end

function UI:ToggleBankMenu()
  if not BB:IsBank() then return end
  self:BuildBankMenu()
  local m = self.bmenu
  if m:IsVisible() then
    self:CloseBankMenu()
    return
  end
  BB:RequestRoster()
  local S = self.stock
  local names = BB:BankList()
  local entries = { { bank = nil } }
  for i = 1, getn(names) do
    if getn(entries) < MENU_MAX then table.insert(entries, { bank = names[i] }) end
  end
  m.entries = entries
  local total = 0
  for i = 2, getn(entries) do
    local st = BB:BankStats(entries[i].bank)
    if st then total = total + st.items end
  end
  for i = 1, MENU_MAX do
    local row = m.rows[i]
    local e = entries[i]
    if e then
      local sel = (e.bank == S.bank)
      if sel then row.bg:Show() else row.bg:Hide() end
      if e.bank then
        local c = dotColor(e.bank)
        row.dot:SetVertexColor(c[1], c[2], c[3], 1)
        row.name:SetText(e.bank)
        if sel then row.name:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) else row.name:SetTextColor(1, 1, 1) end
        local st = BB:BankStats(e.bank)
        row.cnt:SetText(st and string.format(T("SB_ITEMS"), st.items) or T("SB_NOSCAN"))
        local info = BB:GetBankInfo(e.bank)
        row.role:SetText((info and info.role) or "")
      else
        row.dot:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
        row.name:SetText(T("SB_ALL"))
        if sel then row.name:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) else row.name:SetTextColor(1, 1, 1) end
        row.cnt:SetText(string.format(T("SB_ALL_INFO"), total, getn(entries) - 1))
        row.role:SetText("")
      end
      row:Show()
    else
      row:Hide()
    end
  end
  m:SetHeight(12 + getn(entries) * MENU_ROW)
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", S.bankBtn, "BOTTOMLEFT", 0, -2)
  m.catch:Show()
  m:Show()
end

-- ------------------------------------------------------------
-- Banken-Reiter
-- ------------------------------------------------------------
function UI:BuildBanks(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints(parent)
  p:Hide()
  self.pages.banks = p
  local K = self.bk

  -- Kopfzeile: Summe ueber alle Banken auf einen Blick
  local sum = self:Panel(p, 0, 58)
  sum:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  sum:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
  K.tiles = {}
  local tdefs = { { "BK_T_BANKS", 18 }, { "BK_T_ITEMS", 230 }, { "BK_T_GOLD", 440 } }
  for i = 1, getn(tdefs) do
    local lbl = self:Font(sum, 11, C.goldDim)
    lbl:SetPoint("TOPLEFT", sum, "TOPLEFT", tdefs[i][2], -8)
    self:Loc(lbl, tdefs[i][1])
    local val = self:Font(sum, 24, C.gold, FONT_TITLE)
    val:SetPoint("TOPLEFT", sum, "TOPLEFT", tdefs[i][2], -22)
    val:SetWidth(230)
    val:SetHeight(28)
    K.tiles[i] = val
  end
  K.editBtn = self:Button(sum, 180, 26, "BK_EDIT", function() UI:OpenBankEditor() end, "primary")
  K.editBtn:SetPoint("RIGHT", sum, "RIGHT", -12, 0)

  -- Tabelle: Spaltenkoepfe, eine Zeile je Bank (Name mit Beschreibung darunter), Zebra-Zeilen
  local tbl = self:Panel(p)
  tbl:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -64)
  tbl:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
  K.lp = tbl
  local lp = tbl
  local heads = { { "BK_COL_BANK", 24, 184, "LEFT" }, { "BK_COL_ROLE", 212, 98, "LEFT" }, { "BK_COL_ITEMS", 314, 76, "RIGHT" },
    { "BK_COL_GOLD", 394, 86, "RIGHT" }, { "BK_COL_SCAN", 484, 104, "RIGHT" } }
  for i = 1, getn(heads) do
    local h = self:Font(tbl, 10, C.goldDim)
    h:SetPoint("TOPLEFT", tbl, "TOPLEFT", 8 + heads[i][2], -8)
    h:SetWidth(heads[i][3])
    h:SetJustifyH(heads[i][4])
    self:Loc(h, heads[i][1])
  end
  self:HLine(tbl, -24, 8, -8, C.brass, 0.8)
  local sf = CreateFrame("ScrollFrame", "BananaBankBanksScroll", tbl, "FauxScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", tbl, "TOPLEFT", 4, -28)
  sf:SetPoint("BOTTOMRIGHT", tbl, "BOTTOMRIGHT", -30, 4)
  sf:SetScript("OnVerticalScroll", function() FauxScrollFrame_OnVerticalScroll(ROW_H, function() UI:RefreshBanks() end) end)
  sf.offset = 0
  K.sf = sf
  local function wheel()
    local sb = getglobal("BananaBankBanksScrollScrollBar")
    if sb then sb:SetValue(sb:GetValue() - arg1 * ROW_H) end
  end
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", wheel)

  K.rows = {}
  for i = 1, VISIBLE do
    local card = CreateFrame("Frame", nil, tbl)
    card:SetHeight(ROW_H - 2)
    card:SetPoint("TOPLEFT", tbl, "TOPLEFT", 6, -30 - (i - 1) * ROW_H)
    card:SetPoint("TOPRIGHT", tbl, "TOPRIGHT", -30, -30 - (i - 1) * ROW_H)
    card:EnableMouse(true)
    card:EnableMouseWheel(true)
    card:SetScript("OnMouseWheel", wheel)
    card:SetScript("OnEnter", function() UI:BankCardTooltip(this) end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card.zebra = card:CreateTexture(nil, "BACKGROUND")
    card.zebra:SetTexture(WHITE)
    card.zebra:SetAllPoints(card)
    card.zebra:SetVertexColor(1, 1, 1, mod(i, 2) == 0 and 0.045 or 0)
    card.dot = card:CreateTexture(nil, "ARTWORK")
    card.dot:SetTexture(WHITE)
    card.dot:SetWidth(9)
    card.dot:SetHeight(9)
    card.dot:SetPoint("LEFT", card, "LEFT", 6, 0)
    card.name = self:Font(card, 13, C.gold)
    card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 24, -5)
    card.name:SetWidth(184)
    card.name:SetHeight(16)
    card.tags = self:Font(card, 10, { 0.62, 0.64, 0.72 })
    card.tags:SetPoint("TOPLEFT", card, "TOPLEFT", 24, -21)
    card.tags:SetWidth(184)
    card.tags:SetHeight(12)
    card.role = self:Font(card, 11, C.text)
    card.role:SetPoint("LEFT", card, "LEFT", 212, 0)
    card.role:SetWidth(98)
    card.role:SetHeight(14)
    card.items = self:Font(card, 12, C.gold)
    card.items:SetPoint("LEFT", card, "LEFT", 314, 0)
    card.items:SetWidth(76)
    card.items:SetHeight(14)
    card.items:SetJustifyH("RIGHT")
    card.gold = self:Font(card, 12, C.gold)
    card.gold:SetPoint("LEFT", card, "LEFT", 394, 0)
    card.gold:SetWidth(86)
    card.gold:SetHeight(14)
    card.gold:SetJustifyH("RIGHT")
    card.scan = self:Font(card, 11, C.muted)
    card.scan:SetPoint("LEFT", card, "LEFT", 484, 0)
    card.scan:SetWidth(104)
    card.scan:SetHeight(14)
    card.scan:SetJustifyH("RIGHT")
    card.show = self:Button(card, 92, 20, "BK_SHOW", function(b)
      local name = b:GetParent().bank
      if not name then return end
      local S = UI.stock
      S.bank = name
      S.page = 1
      UI:ShowPage("stock")
    end)
    card.show:SetPoint("RIGHT", card, "RIGHT", -2, 0)
    table.insert(K.rows, card)
  end
  K.empty = self:Font(lp, 12, C.muted)
  K.empty:SetPoint("TOPLEFT", lp, "TOPLEFT", 20, -40)
  K.empty:SetWidth(600)
  K.empty:SetJustifyV("TOP")
  self:Loc(K.empty, "BK_EMPTY")
end

local lastRoster = 0

function UI:BankCardTooltip(card)
  local info = card.info
  if not card.bank then return end
  local hasDesc = info and info.desc and info.desc ~= ""
  local hasWrong = false
  if not hasDesc then return end
  GameTooltip:SetOwner(card, "ANCHOR_BOTTOMRIGHT")
  GameTooltip:AddLine(card.bank, C.gold[1], C.gold[2], C.gold[3])
  if hasDesc then GameTooltip:AddLine(info.desc, 1, 1, 1, 1) end
  if hasWrong then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T("BK_WRONG_TT"), 1, 0.62, 0.17, 1)
    for i = 1, getn(st.wrongList) do
      GameTooltip:AddDoubleLine(st.wrongList[i].n, st.wrongList[i].c .. "x", 1, 1, 1, 0.9, 0.9, 0.9)
    end
    if st.wrongKinds > getn(st.wrongList) then
      GameTooltip:AddLine("... +" .. (st.wrongKinds - getn(st.wrongList)), 0.7, 0.7, 0.7)
    end
  end
  GameTooltip:Show()
end

function UI:RefreshBanks()
  local K = self.bk
  if not K.rows or K.busy then return end
  if GetTime() - lastRoster > 30 then
    lastRoster = GetTime()
    BB:RequestRoster()
  end
  local me = BB:Me()
  local names = BB:BankList()
  local totalItems, totalGold = 0, 0
  for i = 1, getn(names) do
    local st = BB:BankStats(names[i])
    if st then
      totalItems = totalItems + st.items
      totalGold = totalGold + st.gold
    end
  end
  local online = 0
  for i = 1, getn(names) do if BB:IsOnline(names[i]) then online = online + 1 end end
  K.tiles[1]:SetText(getn(names) .. "  |cff9a9cb3(" .. string.format(T("BK_T_ONLINE"), online) .. ")|r")
  K.tiles[2]:SetText(totalItems)
  K.tiles[3]:SetText(BB.Money(totalGold))
  if BB:IsBank() and BB:MayBeBank(me) then K.editBtn:Show() else K.editBtn:Hide() end

  local n = getn(names)
  K.busy = true
  local offset = 0
  if FauxScrollFrame_Update then FauxScrollFrame_Update(K.sf, n, VISIBLE, ROW_H) end
  offset = (FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(K.sf)) or K.sf.offset or 0
  K.busy = false
  for i = 1, VISIBLE do
    local card = K.rows[i]
    local name = names[offset + i]
    card.bank = name
    if name then
      local info = BB:GetBankInfo(name)
      local st = BB:BankStats(name)
      local c = dotColor(name)
      card.dot:SetVertexColor(c[1], c[2], c[3], 1)
      card.name:SetText(name .. (name == me and ("  " .. T("BK_ME")) or ""))
      if info and info.role ~= "" then
        card.role:SetText(info.role)
        card.role:SetTextColor(C.text[1], C.text[2], C.text[3])
      else
        card.role:SetText(T("BK_NOINFO"))
        card.role:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
      end
      card.info = info
      -- Beschreibung klein unter dem Namen (jede Bank lagert, was sie will)
      local d = (info and info.desc) or ""
      if string.len(d) > 38 then d = string.sub(d, 1, 35) .. "..." end
      card.tags:SetText(d)
      if st then
        card.items:SetText(st.items .. " " .. T("UNIT_ITEMS"))
        card.gold:SetText(BB.Money(st.gold))
        card.scan:SetText(BB.Date(st.ts))
        card.show:SetOn(true)
      else
        card.items:SetText("-")
        card.gold:SetText("")
        card.scan:SetText(T("SB_NOSCAN"))
        card.show:SetOn(false)
      end
      card:Show()
    else
      card:Hide()
    end
  end
  if n == 0 then K.empty:Show() else K.empty:Hide() end
end

-- ------------------------------------------------------------
-- Rollen-Editor (jede Bank pflegt nur ihre eigene Rolle)
-- ------------------------------------------------------------
function UI:BuildBankEditor()
  if self.bke then return end
  local f = CreateFrame("Frame", "BananaBankInfoEditor", UIParent)
  self.bke = f
  f:SetWidth(540)
  f:SetHeight(444)
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
  self:Solid(f, 12, 1)
  f:Hide()
  tinsert(UISpecialFrames, "BananaBankInfoEditor")
  local head = f:CreateTexture(nil, "BORDER")
  head:SetTexture(WHITE)
  head:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -12)
  head:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -12, -66)
  head:SetGradientAlpha("VERTICAL", C.bg[1], C.bg[2], C.bg[3], 0, C.blue[1], C.blue[2], C.blue[3], 0.75)
  local h = self:Font(f, 22, C.gold, FONT_TITLE)
  h:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -20)
  self:Loc(h, "BE_TITLE")
  f.who = self:Font(f, 11, C.muted)
  f.who:SetPoint("TOPLEFT", f, "TOPLEFT", 27, -48)
  self:GlowLine(f, -66, 20, -20)

  local function label(key, y)
    local fs = self:Font(f, 10, C.goldDim)
    fs:SetPoint("TOPLEFT", f, "TOPLEFT", 28, y)
    self:Loc(fs, key)
    return fs
  end
  label("BE_ROLE", -78)
  f.role = self:EditBox("BananaBankInfoRole", f, 478)
  f.role:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -92)
  f.role:SetMaxLetters(BB.BANK_ROLE_LEN)

  label("BE_DESC", -120)
  local tp = self:Panel(f, 488, 66)
  tp:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -134)
  f.desc = CreateFrame("EditBox", "BananaBankInfoDesc", tp)
  f.desc:SetMultiLine(true)
  f.desc:SetAutoFocus(false)
  f.desc:SetFontObject("ChatFontNormal")
  f.desc:SetMaxLetters(BB.BANK_DESC_LEN)
  f.desc:SetWidth(466)
  f.desc:SetHeight(54)
  f.desc:SetPoint("TOPLEFT", tp, "TOPLEFT", 10, -7)
  f.desc:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  tp:EnableMouse(true)
  tp:SetScript("OnMouseDown", function() f.desc:SetFocus() end)

  local catLabel = label("BE_CATS", -214)
  catLabel:Hide()
  f.tags = {}
  f.chips = {}
  for i = 1, getn(BB.CATS) do
    local cat = BB.CATS[i]
    local col = floor((i - 1) / 3)
    local rowi = mod(i - 1, 3)
    local chip = self:Chip(f, 156, "CAT_" .. string.upper(cat), function(b)
      f.tags[cat] = (not f.tags[cat]) or nil
      b:SetActive(f.tags[cat] and true or false)
    end)
    chip:SetHeight(22)
    chip:SetPoint("TOPLEFT", f, "TOPLEFT", 28 + rowi * 162, -230 - col * 28)
    f.chips[cat] = chip
    chip:Hide()
  end
  local hint = self:Font(f, 10, { 0.62, 0.64, 0.74 })
  hint:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -346)
  hint:SetWidth(484)
  hint:SetHeight(26)
  hint:SetJustifyV("TOP")
  self:Loc(hint, "BE_HINT")
  hint:Hide()
  f:SetHeight(300)

  f.cancel = self:Button(f, 110, 26, "QE_CANCEL", function() f:Hide() end)
  f.cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -154, 22)
  f.save = self:Button(f, 120, 26, "QE_SAVE", function()
    if BB:SetMyBankInfo(f.role:GetText(), f.desc:GetText(), f.tags) then
      f:Hide()
      UI:RefreshBanks()
    end
  end, "ok")
  f.save:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 22)
end

function UI:OpenBankEditor()
  local me = BB:Me()
  if not (BB:IsBank() and BB:MayBeBank(me)) then
    BB:Print("|cffff4040" .. string.format(T("ERR_BANKINFO_NOBANK"), BB.BANK_RANK_LABEL) .. "|r")
    return
  end
  self:BuildBankEditor()
  local f = self.bke
  local info = BB:GetBankInfo(me)
  f.who:SetText(me)
  f.role:SetText(info and info.role or "")
  f.desc:SetText(info and info.desc or "")
  f.tags = {}
  for cat in pairs(info and info.tags or {}) do f.tags[cat] = true end
  for cat, chip in pairs(f.chips) do chip:SetActive(f.tags[cat] and true or false) end
  f:Show()
  f.role:SetFocus()
end
