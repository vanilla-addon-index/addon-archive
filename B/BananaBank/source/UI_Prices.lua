-- BananaBank UI: Reiter Preise

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local floor = math.floor

local PRICE_ROWS = 10
local PRICE_ROW_H = 25
UI.priceModule = true

function UI:BuildPrices(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints(parent)
  p:Hide()
  self.pages.prices = p
  self.price = { filter = "all", page = 1 }
  local P = self.price

  -- eine Werkzeugleiste: Filter links, Scan-Stand in der Mitte, Scan und Nachnahme rechts
  local bar = self:Panel(p, 0, 34)
  bar:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  bar:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
  P.bar = bar
  P.info = self:Font(bar, 11, C.text)
  P.info:SetPoint("LEFT", bar, "LEFT", 268, 0)
  P.info:SetWidth(232)
  P.info:SetHeight(14)

  P.cod = self:Check(bar, "OPT_COD", function() return BananaBankDB.cod ~= false end, function(v)
    BananaBankDB.cod = v
    UI:Refresh()
  end)
  P.cod:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
  P.cod:SetWidth(132)
  P.scanBtn = self:Button(bar, 100, 22, "BTN_AH_SCAN", function()
    if BB.scan then BB:StopAHScan() else BB:StartAHScan() end
    UI:RefreshPrices()
  end, "primary")
  P.scanBtn:SetPoint("RIGHT", bar, "RIGHT", -146, 0)

  P.chips = {}
  local defs = { { "FILTER_ALL", "all" }, { "PRICE_WITH", "with" }, { "PRICE_WITHOUT", "without" } }
  local prev
  for i = 1, getn(defs) do
    local key = defs[i][2]
    local chip = self:Chip(p, 80, defs[i][1], function()
      P.filter = key
      local sb = getglobal("BananaBankPriceScrollScrollBar")
      if sb then sb:SetValue(0) end
      UI:RefreshPrices()
    end)
    chip.key = key
    if prev then chip:SetPoint("LEFT", prev, "RIGHT", 4, 0) else chip:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -8) end
    table.insert(P.chips, chip)
    prev = chip
  end

  local list = self:Panel(p)
  list:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -42)
  list:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 22)
  P.list = list
  local sf = CreateFrame("ScrollFrame", "BananaBankPriceScroll", list, "FauxScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -28)
  sf:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -28, 4)
  sf:SetScript("OnVerticalScroll", function() FauxScrollFrame_OnVerticalScroll(PRICE_ROW_H, function() UI:RefreshPrices() end) end)
  sf.offset = 0
  P.sf = sf
  local function wheel()
    local sb = getglobal("BananaBankPriceScrollScrollBar")
    if sb then sb:SetValue(sb:GetValue() - arg1 * PRICE_ROW_H * 2) end
  end
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", wheel)
  -- Preis, Quelle, Datum: rechtsbuendig ueber den Werten (rechte Kante, Breite)
  local cols = { { "COL_ITEM", 14 }, { "COL_BIND", 300 }, { "COL_PRICE", 486, 98 }, { "COL_SOURCE", 578, 74 }, { "COL_DATE", 658, 76 } }
  for i = 1, getn(cols) do
    local h = self:Font(list, 10, C.goldDim)
    if cols[i][3] then
      h:SetWidth(cols[i][3])
      h:SetJustifyH("RIGHT")
      h:SetPoint("TOPLEFT", list, "TOPLEFT", cols[i][2] - cols[i][3], -9)
    else
      h:SetPoint("TOPLEFT", list, "TOPLEFT", cols[i][2], -9)
    end
    self:Loc(h, cols[i][1])
    if cols[i][1] == "COL_BIND" then P.hBind = h end
  end
  -- Spalte "Bank" (nur auf Bank-Chars): auf welchem Char das Item liegt
  P.hBank = self:Font(list, 10, C.goldDim)
  P.hBank:SetPoint("TOPLEFT", list, "TOPLEFT", 316, -9)
  self:Loc(P.hBank, "COL_BANK")
  P.hBank:Hide()
  self:HLine(list, -24, 8, -8, C.brass, 0.8)

  P.rows = {}
  for i = 1, PRICE_ROWS do
    local row = CreateFrame("Frame", nil, list)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -28 - (i - 1) * 25)
    row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -26, -28 - (i - 1) * 25)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", wheel)
    local zebra = row:CreateTexture(nil, "BACKGROUND")
    zebra:SetAllPoints(row)
    zebra:SetTexture(1, 1, 1, (math.mod(i, 2) == 0) and 0.03 or 0)
    row.ic = self:Slot(row, 22)
    row.ic:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.ic:SetScript("OnEnter", function() if this.id then UI:ItemTooltip(this, this.id) end end)
    row.ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.name = self:Font(row, 11, C.text)
    row.name:SetPoint("LEFT", row, "LEFT", 28, 0)
    row.name:SetWidth(258)
    row.name:SetHeight(13)
    row.bind = self:Font(row, 10, C.muted)
    row.bind:SetPoint("LEFT", row, "LEFT", 292, 0)
    row.bind:SetWidth(100)
    row.bank = self:Font(row, 10, C.text)
    row.bank:SetPoint("LEFT", row, "LEFT", 308, 0)
    row.bank:SetWidth(72)
    row.bank:SetHeight(12)
    row.bank:Hide()
    row.price = self:Font(row, 11, C.gold, UI.FONT, "OUTLINE")
    row.price:SetPoint("LEFT", row, "LEFT", 380, 0)
    row.price:SetWidth(98)
    row.price:SetJustifyH("RIGHT")
    row.src = self:Font(row, 10, C.muted)
    row.src:SetPoint("LEFT", row, "LEFT", 496, 0)
    row.src:SetWidth(74)
    row.src:SetJustifyH("RIGHT")
    row.date = self:Font(row, 10, C.muted)
    row.date:SetPoint("LEFT", row, "LEFT", 574, 0)
    row.date:SetWidth(76)
    row.date:SetJustifyH("RIGHT")
    row.edit = self:Button(row, 52, 20, "BTN_PRICE_SET", function(b) UI:ShowPriceDialog(b.row.id) end, "flat")
    row.edit:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.edit.row = row
    table.insert(P.rows, row)
  end
  P.empty = self:Font(list, 12, C.muted)
  P.empty:SetPoint("CENTER", list, "CENTER", 0, 0)
  P.empty:SetJustifyH("CENTER")
  P.empty:SetWidth(420)

  local legend = self:Font(p, 10, C.muted)
  legend:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 8, 4)
  legend:SetWidth(730)
  legend:SetHeight(12)
  self:Loc(legend, "PRICE_LEGEND")

  self:BuildPriceDialog()
end

function UI:PriceList()
  local P = self.price
  local stock = BB:GetStock()
  local list = {}
  for id, e in pairs(stock) do
    local u, src = BB:GetPrice(id)
    local take = true
    if P.filter == "with" then take = u ~= nil end
    if P.filter == "without" then take = (u == nil) end
    if take then table.insert(list, { id = id, e = e, u = u }) end
  end
  table.sort(list, function(a, b)
    if (a.u or -1) ~= (b.u or -1) then return (a.u or -1) > (b.u or -1) end
    return (a.e.n or "") < (b.e.n or "")
  end)
  return list
end

-- Auf Bank-Chars eine Spalte mehr (Bank-Char des Items): Name und Bindung rutschen zusammen
function UI:PriceLayout(isBank)
  local P = self.price
  if P.layoutBank == isBank then return end
  P.layoutBank = isBank
  for i = 1, getn(P.rows) do
    local row = P.rows[i]
    row.name:SetWidth(isBank and 214 or 258)
    row.bind:ClearAllPoints()
    row.bind:SetPoint("LEFT", row, "LEFT", isBank and 244 or 292, 0)
    row.bind:SetWidth(isBank and 62 or 100)
    if isBank then row.bank:Show() else row.bank:Hide() end
  end
  P.hBind:ClearAllPoints()
  P.hBind:SetPoint("TOPLEFT", P.sf:GetParent(), "TOPLEFT", isBank and 252 or 300, -9)
  if isBank then P.hBank:Show() else P.hBank:Hide() end
end

function UI:RefreshPrices()
  if not self.price then return end
  local P = self.price
  local db = BananaBankDB
  for i = 1, getn(P.chips) do P.chips[i]:SetActive(P.chips[i].key == P.filter) end

  local isBank = BB:IsBank()
  self:PriceLayout(isBank and true or false)
  if isBank then P.scanBtn:Show() else P.scanBtn:Hide() end
  if isBank then P.cod:Show() else P.cod:Hide() end
  P.cod.Update()
  if BB.scan then
    P.scanBtn.fs:SetText(T("BTN_AH_STOP"))
    P.info:SetText(string.format(T("PRICE_SCANNING"), BB.scan.idx,
      table.getn(BB.scan.ids), BB:ScanItemName()))
  else
    P.scanBtn.fs:SetText(T("BTN_AH_SCAN"))
    local scan = db.priceScan or {}
    if (scan.ts or 0) > 0 then
      local days = floor((time() - scan.ts) / 86400)
      P.info:SetText(string.format(T("PRICE_INFO"), BB.Date(scan.ts), days,
        BB.Count(db.prices)))
    else
      P.info:SetText(T("PRICE_INFO_NONE"))
    end
  end

  local list = self:PriceList()
  local offset = 0
  P.busy = true
  if FauxScrollFrame_Update then FauxScrollFrame_Update(P.sf, getn(list), PRICE_ROWS, PRICE_ROW_H) end
  offset = (FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(P.sf)) or P.sf.offset or 0
  P.busy = false
  for i = 1, PRICE_ROWS do
    local row = P.rows[i]
    local entry = list[offset + i]
    if entry then
      local id = entry.id
      row.id = id
      row.ic.id = id
      row.ic.icon:SetTexture(BB.FullTex(entry.e.t))
      row.ic:SetQuality(entry.e.q)
      local qc = BB.QUALITY_COLOR[entry.e.q or 1] or BB.QUALITY_COLOR[1]
      row.name:SetText(entry.e.n .. "  |cff888888x" .. entry.e.c .. "|r")
      if isBank then
        -- Bank-Char mit dem groessten Bestand, weitere als "+N"
        local best, bestC, n = nil, -1, 0
        for bank, c in pairs(entry.e.per or {}) do
          n = n + 1
          if c > bestC or (c == bestC and bank < best) then best, bestC = bank, c end
        end
        local txt = best or "-"
        if n > 1 then txt = txt .. " |cff888888+" .. (n - 1) .. "|r" end
        row.bank:SetText(txt)
      end
      row.name:SetTextColor(qc[1], qc[2], qc[3])
      if entry.e.k == "recipe" then row.bind:SetText(T("BIND_RECIPE"))
      elseif BB:IsBOE(id) then row.bind:SetText(T("BIND_BOE"))
      elseif BB.ItemIsBag and BB:ItemIsBag(id) then row.bind:SetText(T("BIND_BAG"))
      else row.bind:SetText("-") end
      local u, src, ts, n = BB:GetPrice(id)
      if u then
        row.price:SetText(BB.Money(u))
        if src == "man" then
          row.src:SetText(T("SRC_MANUAL"))
        else
          row.src:SetText(string.format(T("SRC_AH"), n or 0))
        end
        row.date:SetText(BB.Date(ts))
      else
        row.price:SetText("|cffff8000" .. T("PRICE_NONE") .. "|r")
        local raw = BananaBankDB.prices[id]
        if raw and raw.src == "none" then
          row.src:SetText("|cffff8000" .. T("SRC_NOT_FOUND") .. "|r")
          row.date:SetText(BB.Date(raw.ts))
        else
          row.src:SetText(T("SRC_NEVER"))
          row.date:SetText("-")
        end
      end
      if isBank then row.edit:Show() else row.edit:Hide() end
      row:Show()
    else
      row.id = nil
      row:Hide()
    end
  end
  if getn(list) == 0 then
    P.empty:SetText(T("PRICE_EMPTY"))
    P.empty:Show()
  else
    P.empty:Hide()
  end
end

-- ------------------------------------------------------------
-- Preis von Hand setzen
-- ------------------------------------------------------------
function UI:BuildPriceDialog()
  local d = CreateFrame("Frame", "BananaBankPriceDialog", UIParent)
  self.priceDialog = d
  d:SetWidth(380)
  d:SetHeight(180)
  d:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  d:SetFrameStrata("DIALOG")
  d:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  d:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.98)
  d:EnableMouse(true)
  d:Hide()
  tinsert(UISpecialFrames, "BananaBankPriceDialog")
  local t = self:Font(d, 17, C.gold, UI.FONT_TITLE)
  t:SetPoint("TOP", d, "TOP", 0, -18)
  t:SetJustifyH("CENTER")
  self:Loc(t, "PRICE_DIALOG_TITLE")
  d.item = self:Font(d, 12, C.text)
  d.item:SetPoint("TOP", t, "BOTTOM", 0, -8)
  d.item:SetWidth(330)
  d.item:SetJustifyH("CENTER")
  local hint = self:Font(d, 10, C.muted)
  hint:SetPoint("TOP", d.item, "BOTTOM", 0, -6)
  hint:SetWidth(330)
  hint:SetJustifyH("CENTER")
  self:Loc(hint, "PRICE_DIALOG_HINT")
  -- Gold, Silber, Kupfer einzeln. Ein Dezimalfeld verrechnet sich zu leicht.
  local holder = CreateFrame("Frame", nil, d)
  holder:SetWidth(240)
  holder:SetHeight(24)
  holder:SetPoint("TOP", hint, "BOTTOM", 0, -10)
  d.coins = {}
  local defs = { { "g", "g", 6 }, { "s", "s", 2 }, { "c", "c", 2 } }
  local prev
  for i = 1, getn(defs) do
    local key, letter, maxLen = defs[i][1], defs[i][2], defs[i][3]
    local box = self:EditBox("BananaBankPrice" .. string.upper(key), holder, 54)
    box:SetMaxLetters(maxLen)
    box:SetNumeric(true)
    if prev then
      box:SetPoint("LEFT", prev, "RIGHT", 26, 0)
    else
      box:SetPoint("LEFT", holder, "LEFT", 6, 0)
    end
    local lbl = self:Font(holder, 13, C.text, UI.FONT, "OUTLINE")
    lbl:SetPoint("LEFT", box, "RIGHT", 4, 0)
    lbl:SetText("|cff" .. BB.COIN_COLOR[key] .. letter .. "|r")
    box:SetScript("OnEnterPressed", function()
      UI:ApplyPriceDialog()
      this:ClearFocus()
    end)
    d.coins[key] = box
    prev = box
  end
  -- Tab springt weiter
  d.coins.g:SetScript("OnTabPressed", function() d.coins.s:SetFocus() end)
  d.coins.s:SetScript("OnTabPressed", function() d.coins.c:SetFocus() end)
  d.coins.c:SetScript("OnTabPressed", function() d.coins.g:SetFocus() end)
  local ok = self:Button(d, 110, 24, "BTN_SAVE", function() UI:ApplyPriceDialog() end, "primary")
  ok:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -4, 18)
  local cancel = self:Button(d, 110, 24, "BTN_CLOSE", function() d:Hide() end)
  cancel:SetPoint("BOTTOMLEFT", d, "BOTTOM", 4, 18)
  d.reset = self:Button(d, 224, 20, "BTN_PRICE_RESET", function()
    if d.id then
      BB:ResetPrice(d.id)
      BB:Print(T("MSG_PRICE_RESET"))
    end
    d:Hide()
    UI:Refresh()
  end, "flat")
  d.reset:SetPoint("BOTTOM", d, "BOTTOM", 0, 44)
end

function UI:ShowPriceDialog(id)
  if not id then return end
  local d = self.priceDialog
  d.id = id
  d.item:SetText(BB:ColoredName(id))
  local u, src = BB:GetPrice(id)
  local g, si, c = BB.SplitMoney(u or 0)
  d.coins.g:SetText(u and g or "")
  d.coins.s:SetText(u and si or "")
  d.coins.c:SetText(u and c or "")
  if src == "man" then d.reset:Show() else d.reset:Hide() end
  d:Show()
  d.coins.g:SetFocus()
  d.coins.g:HighlightText()
end

function UI:ApplyPriceDialog()
  local d = self.priceDialog
  if not d.id then return end
  local function val(key)
    local t = d.coins[key]:GetText() or ""
    if t == "" then return 0 end
    local n = tonumber(t)
    if not n or n < 0 then return nil end
    return floor(n)
  end
  local g, s, c = val("g"), val("s"), val("c")
  if not g or not s or not c then
    BB:Print(T("ERR_PRICE_INPUT"))
    return
  end
  local total = g * 10000 + s * 100 + c
  BB:SetPrice(d.id, total, "man")
  BB:Print(string.format(T("MSG_PRICE_SET"), BB:ColoredName(d.id), BB.Money(total)))
  d:Hide()
  self:Refresh()
end
