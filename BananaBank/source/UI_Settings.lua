-- BananaBank UI Teil 9: Einstellungen (Zahnrad) und Hauptbank-Anzeige im Fensterkopf

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local WHITE = UI.WHITE

UI.settingsModule = true
UI.set = {}

local GEN_H, GUILD_H, BANK_H = 262, 108, 288
local RULES_H = 246
local DEPOT_H = 436
local KW_H = 404

-- ------------------------------------------------------------
-- Kopf: Zahnrad und "Spenden an: <Hauptbank>"
-- ------------------------------------------------------------
function UI:BuildSettingsButton(parent)
  local b = self:Button(parent, 22, 18, nil, function() UI:ToggleSettings() end, "flat")
  local ic = b:CreateTexture(nil, "OVERLAY")
  ic:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
  ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  ic:SetWidth(14)
  ic:SetHeight(14)
  ic:SetPoint("CENTER", b, "CENTER", 0, 0)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(T("SET_BTN_TIP"), 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

function UI:BuildMainBankLabel(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(240)
  b:SetHeight(16)
  b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -40, -40)
  b.fs = self:Font(b, 12, C.gold)
  b.fs:SetPoint("RIGHT", b, "RIGHT", 0, 0)
  b.fs:SetJustifyH("RIGHT")
  b.fs:SetWidth(240)
  b.fs:SetHeight(14)
  b:SetScript("OnClick", function()
    UI:ChatInsert(BB:MainBank())
  end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(T("MAIN_TIP"), 1, 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.mainLbl = b
  return b
end

function UI:RefreshMainBank()
  if not self.mainLbl then return end
  self.mainLbl.fs:SetText("|cff9a9cb3" .. T("MAIN_DONATE") .. "|r |cffffd100" .. BB:MainBank() .. "|r")
end

-- ------------------------------------------------------------
-- Einstellungsfenster
-- ------------------------------------------------------------
local function group(f, key)
  local g = CreateFrame("Frame", nil, f)
  g:SetWidth(430)
  local fs = UI:Font(g, 12, C.gold)
  fs:SetPoint("TOPLEFT", g, "TOPLEFT", 0, 0)
  UI:Loc(fs, key)
  UI:HLine(g, -16, 0, 0, C.brass, 0.7)
  return g
end

local function check(g, key, x, y, getter, setter, w)
  local c = UI:Check(g, key, getter, setter)
  c:SetPoint("TOPLEFT", g, "TOPLEFT", x, y)
  c:SetWidth(w or 200)
  return c
end

local function btn(g, key, x, y, w, fn)
  local b = UI:Button(g, w, 20, key, fn, "flat")
  b:SetPoint("TOPLEFT", g, "TOPLEFT", x, y)
  return b
end

function UI:BuildSettings()
  if self.setWin then return end
  local S = self.set
  local f = CreateFrame("Frame", "BananaBankSettings", UIParent)
  self.setWin = f
  f:SetWidth(470)
  f:SetHeight(400)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
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
  f:SetScript("OnHide", function() UI:CloseRankPicker() end)
  tinsert(UISpecialFrames, "BananaBankSettings")
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
  local title = self:Font(f, 20, C.gold, UI.FONT_TITLE)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -20)
  self:Loc(title, "SET_TITLE")
  self:GlowLine(f, -50, 20, -20)
  S.tab = "gen"
  S.tabs = {}
  local tdefs = { { "SET_TAB_GEN", "gen" }, { "SET_TAB_RULES", "rules" }, { "SET_TAB_DEPOT", "depots" }, { "SET_TAB_KW", "keywords" } }
  for i = 1, getn(tdefs) do
    local key = tdefs[i][2]
    local chip = self:Chip(f, 100, tdefs[i][1], function()
      UI:CloseRankPicker()
      S.tab = key
      UI:RefreshSettings()
    end)
    chip:SetHeight(22)
    chip:SetPoint("TOPLEFT", f, "TOPLEFT", 26 + (i - 1) * 106, -56)
    chip.key = key
    S.tabs[i] = chip
  end

  -- Allgemein (alle)
  local g = group(f, "SET_SEC_GEN")
  S.gen = g
  g:SetHeight(GEN_H)
  local lang = self:Font(g, 11, C.text)
  lang:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -28)
  self:Loc(lang, "SET_LANG")
  S.langChips = {}
  local ldefs = { { "SET_LANG_AUTO", "auto" }, { "SET_LANG_DE", "deDE" }, { "SET_LANG_EN", "enUS" } }
  for i = 1, getn(ldefs) do
    local code = ldefs[i][2]
    local chip = self:Chip(g, 84, ldefs[i][1], function() UI:SetLanguage(code) end)
    chip.code = code
    chip:SetPoint("TOPLEFT", g, "TOPLEFT", 110 + (i - 1) * 88, -26)
    S.langChips[i] = chip
  end
  S.cMini = check(g, "SET_MINIMAP", 4, -52, function() return not BananaBankDB.minimap.hide end, function(v)
    BananaBankDB.minimap.hide = not v
    if v then UI.minimap:Show() else UI.minimap:Hide() end
  end)
  S.cTrack = check(g, "SET_TRACKER", 230, -52, function() return not BananaBankDB.qtrackerHidden end, function(v)
    if v == (BananaBankDB.qtrackerHidden and true or false) then UI:ToggleQuestTracker() end
  end)
  S.cDebug = check(g, "SET_DEBUG", 4, -74, function() return BananaBankDB.debug and true or false end, function(v)
    BananaBankDB.debug = v and true or nil
  end)
  btn(g, "SET_UNHIDE", 4, -104, 210, function()
    BananaBankDB.hidden = {}
    BB:Print(T("MSG_UNHIDDEN"))
    UI:Refresh()
  end)
  btn(g, "SET_STATUS", 220, -104, 140, function() BB:Status() end)
  btn(g, "SET_SUPPORT", 4, -132, 210, function() UI:ShowThanks() end)
  -- GZ bei Levelups
  S.cGz = check(g, "SET_GZ", 4, -164, function() return BB:GzOn() end, function(v)
    BananaBankDB.gz = BananaBankDB.gz or {}
    BananaBankDB.gz.on = v
  end, 300)
  S.gzChips = {}
  local gdefs = { { "SET_GZ_ALL", "all" }, { "SET_GZ_5", "fives" }, { "SET_GZ_10", "tens" } }
  for i = 1, getn(gdefs) do
    local code = gdefs[i][2]
    local chip = self:Chip(g, 100, gdefs[i][1], function()
      BananaBankDB.gz = BananaBankDB.gz or {}
      BananaBankDB.gz.mode = code
      UI:RefreshSettings()
    end)
    chip.code = code
    chip:SetPoint("TOPLEFT", g, "TOPLEFT", 24 + (i - 1) * 104, -188)
    S.gzChips[i] = chip
  end
  S.cGz60 = check(g, "SET_GZ_60", 4, -214, function() return BB:GzSplash() end, function(v)
    BananaBankDB.gz = BananaBankDB.gz or {}
    BananaBankDB.gz.splash = v
  end, 300)
  btn(g, "SET_GZ_TEXTS", 4, -238, 210, function() UI:OpenGzTexts() end)

  -- Gilde (Verwalter)
  g = group(f, "SET_SEC_GUILD")
  S.guild = g
  g:SetHeight(GUILD_H)
  local ml = self:Font(g, 11, C.text)
  ml:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -28)
  self:Loc(ml, "SET_MAIN")
  S.main = self:EditBox("BananaBankMainBank", g, 150)
  S.main:SetPoint("TOPLEFT", g, "TOPLEFT", 190, -23)
  S.main:SetMaxLetters(24)
  S.main:SetScript("OnEditFocusGained", function() S.mainFocus = true end)
  S.main:SetScript("OnEditFocusLost", function() S.mainFocus = false end)
  S.main:SetScript("OnEnterPressed", function() BB:SetMainBank(this:GetText()) this:ClearFocus() end)
  local save = self:Button(g, 80, 20, "SET_SAVE", function() BB:SetMainBank(S.main:GetText()) S.main:ClearFocus() end, "primary")
  save:SetPoint("TOPLEFT", g, "TOPLEFT", 346, -24)
  local hint = self:Font(g, 10, C.muted)
  hint:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -50)
  hint:SetWidth(420)
  hint:SetHeight(24)
  hint:SetJustifyV("TOP")
  self:Loc(hint, "SET_MAIN_HINT")
  btn(g, "SET_QLOG", 4, -80, 200, function() BB:PrintQuestLog("") end)
  btn(g, "SET_CREDIT", 210, -80, 210, function() BB:CreditQuestDeliveries() end)

  -- Bank-Char
  g = group(f, "SET_SEC_BANK")
  S.bank = g
  g:SetHeight(BANK_H)
  S.cBank = check(g, "SET_BANKMODE", 4, -26, function() return BB:IsBank() end, function(v)
    BB:SetBank(v)
    UI:RefreshSettings()
  end, 420)
  S.cCod = check(g, "SET_COD", 4, -48, function() return BananaBankDB.cod ~= false end, function(v)
    BananaBankDB.cod = v
  end, 420)
  S.cWhisper = check(g, "SET_WHISPER", 4, -70, function() return BananaBankDB.whisper ~= false end, function(v)
    BananaBankDB.whisper = v
  end, 420)
  S.cBatch = check(g, "SET_BATCH", 4, -92, function() return BB:BatchOn() end, function(v)
    BananaBankDB.batch = v
  end, 420)
  btn(g, "SET_SCAN", 4, -120, 100, function() BB:UpdateSnapshot(true) end)
  btn(g, "SET_SYNC", 108, -120, 100, function()
    BB:SendHello()
    BB:Print(T("MSG_SYNC"))
  end)
  btn(g, "SET_AHSCAN", 212, -120, 100, function() BB:StartAHScan() end)
  btn(g, "SET_BOOK", 316, -120, 108, function() UI:OpenBookDialog() end)
  btn(g, "SET_MAILLOG", 4, -146, 200, function() BB:PrintMailLog() end)
  btn(g, "SET_RECON", 210, -146, 214, function() BB:PrintReconcile("") end)
  S.cAuto = check(g, "SET_AUTOBANK", 4, -174, function() return BananaBankDB.autoBank ~= false end, function(v)
    BananaBankDB.autoBank = v
  end, 420)
  local ah = self:Font(g, 10, C.muted)
  ah:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -196)
  ah:SetWidth(420)
  ah:SetHeight(24)
  ah:SetJustifyV("TOP")
  self:Loc(ah, "SET_AUTOBANK_HINT")
  local al = self:Font(g, 11, C.text)
  al:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -230)
  self:Loc(al, "SET_AGE")
  S.age = self:EditBox("BananaBankPriceAge", g, 44)
  S.age:SetPoint("TOPLEFT", g, "TOPLEFT", 290, -225)
  S.age:SetMaxLetters(3)
  S.age:SetNumeric(true)
  local function saveAge()
    local n = tonumber(S.age:GetText())
    if n and n >= 0 and n <= 365 then BananaBankDB.priceMaxAge = math.floor(n) end
    S.ageFocus = false
    S.age:SetText(tostring(BB:PriceMaxAgeDays()))
  end
  S.age:SetScript("OnEditFocusGained", function() S.ageFocus = true end)
  S.age:SetScript("OnEditFocusLost", saveAge)
  S.age:SetScript("OnEnterPressed", function() saveAge() this:ClearFocus() end)
  local ad = self:Font(g, 11, C.muted)
  ad:SetPoint("LEFT", S.age, "RIGHT", 6, 0)
  self:Loc(ad, "SET_AGE_DAYS")
  -- Trash ergibt sich aus dem AH-Scan (nicht im Auktionshaus = Trash), hier nur die Ausnahmen
  S.trashList = btn(g, "", 4, -258, 300, function() if UI.OpenTrashList then UI:OpenTrashList() end end)

  -- Regeln (Rang und Qualitaet)
  g = group(f, "SET_SEC_RULES")
  S.rules = g
  g:SetHeight(RULES_H)
  S.rlStatus = self:Font(g, 10, C.orange)
  S.rlStatus:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -22)
  S.rlStatus:SetWidth(420)
  S.rlStatus:SetHeight(28)
  S.rlStatus:SetJustifyV("TOP")
  S.rlRows = {}
  local rdefs = { { "req", "RL_REQ" }, { "q2", "RL_Q2" }, { "q3", "RL_Q3" }, { "q4", "RL_Q4" } }
  for i = 1, getn(rdefs) do
    local key = rdefs[i][1]
    local lbl = self:Font(g, 11, C.text)
    lbl:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -60 - (i - 1) * 28)
    self:Loc(lbl, rdefs[i][2])
    local b = self:Button(g, 210, 20, "", function(btn) UI:OpenRankPicker(btn, key) end, "flat")
    b:SetPoint("TOPLEFT", g, "TOPLEFT", 214, -56 - (i - 1) * 28)
    S.rlRows[key] = b
  end
  S.rlHint = self:Font(g, 10, C.muted)
  S.rlHint:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -176)
  S.rlHint:SetWidth(420)
  S.rlHint:SetHeight(36)
  S.rlHint:SetJustifyV("TOP")
  S.rlSave = self:Button(g, 150, 22, "RL_SAVE", function()
    if BB:SaveRules(S.edit or {}) then S.editDirty = false end
    UI:RefreshSettings()
  end, "primary")
  S.rlSave:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -216)

  -- Lager: frei benennbare Typen und die Lagerchars dazu
  g = group(f, "SET_SEC_DEPOT")
  S.depot = g
  g:SetHeight(DEPOT_H)
  local th = self:Font(g, 10, C.muted)
  th:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -22)
  th:SetWidth(420)
  th:SetHeight(26)
  th:SetJustifyV("TOP")
  self:Loc(th, "DP_TYPES_HINT")
  S.dpTypes = {}
  for i = 1, BB.DEPOT_TYPE_MAX do
    local idx = i   -- Lua 5.0: Schleifenvariable nicht in Funktionen verwenden
    local row = {}
    local y = -54 - (i - 1) * 24
    row.edit = self:EditBox("BananaBankDepotType" .. i, g, 250)
    row.edit:SetPoint("TOPLEFT", g, "TOPLEFT", 8, y)
    row.edit:SetMaxLetters(24)
    row.edit:SetScript("OnTextChanged", function()
      if S.depotLoading then return end
      local t = S.edit and S.edit.depotTypes and S.edit.depotTypes[idx]
      if t then
        t.name = this:GetText()
        S.editDirty = true
      end
    end)
    row.edit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    row.del = self:Button(g, 24, 20, "x", function()
      local t = S.edit.depotTypes[idx]
      if t then
        -- Lagerchars dieses Typs verlieren die Zuordnung
        for j = getn(S.edit.depots), 1, -1 do
          if S.edit.depots[j].k == t.id then table.remove(S.edit.depots, j) end
        end
      end
      table.remove(S.edit.depotTypes, idx)
      S.editDirty = true
      UI:RefreshSettings()
    end, "flat")
    row.del:SetPoint("TOPLEFT", g, "TOPLEFT", 270, y + 1)
    S.dpTypes[i] = row
  end
  S.dpAddType = self:Button(g, 110, 20, "DP_ADD_TYPE", function()
    S.edit.depotTypes = S.edit.depotTypes or {}
    if getn(S.edit.depotTypes) < BB.DEPOT_TYPE_MAX then
      table.insert(S.edit.depotTypes, { id = nil, name = T("DP_NEW_NAME") })
      S.editDirty = true
      UI:RefreshSettings()
    end
  end, "flat")
  S.dpAddType:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -202)
  local ct = self:Font(g, 11, C.gold)
  ct:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -234)
  self:Loc(ct, "DP_CHARS_TITLE")
  S.rlDepot = {}
  for i = 1, BB.DEPOT_MAX do
    local idx = i
    local row = {}
    local y = -258 - (i - 1) * 26
    -- links der Typ, rechts der Char
    row.kind = self:Button(g, 170, 20, "", function(btn) UI:OpenDepotKindPicker(btn, idx) end, "flat")
    row.kind:SetPoint("TOPLEFT", g, "TOPLEFT", 4, y)
    row.char = self:Button(g, 170, 20, "", function(btn) UI:OpenDepotCharPicker(btn, idx) end, "flat")
    row.char:SetPoint("TOPLEFT", g, "TOPLEFT", 180, y)
    row.del = self:Button(g, 24, 20, "x", function()
      table.remove(S.edit.depots, idx)
      S.editDirty = true
      UI:RefreshSettings()
    end, "flat")
    row.del:SetPoint("TOPLEFT", g, "TOPLEFT", 356, y)
    S.rlDepot[i] = row
  end
  S.rlAdd = self:Button(g, 110, 20, "RL_DEPOT_ADD", function()
    S.edit.depots = S.edit.depots or {}
    local first = S.edit.depotTypes and S.edit.depotTypes[1] and S.edit.depotTypes[1].id
    if getn(S.edit.depots) < BB.DEPOT_MAX then
      table.insert(S.edit.depots, { n = nil, k = first })
      S.editDirty = true
      UI:RefreshSettings()
    end
  end, "flat")
  S.rlAdd:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -366)
  S.dpHint = self:Font(g, 10, C.muted)
  S.dpHint:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -392)
  S.dpHint:SetWidth(420)
  S.dpHint:SetHeight(24)
  S.dpHint:SetJustifyV("TOP")
  S.dpSave = self:Button(g, 150, 22, "RL_SAVE", function()
    if BB:SaveRules(S.edit or {}) then S.editDirty = false end
    UI:RefreshSettings()
  end, "primary")
  S.dpSave:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -418)

  -- Keywords der Offiziersnotiz
  g = group(f, "SET_SEC_KW")
  S.kw = g
  g:SetHeight(KW_H)
  local kh = self:Font(g, 10, C.muted)
  kh:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -22)
  kh:SetWidth(420)
  kh:SetHeight(28)
  kh:SetJustifyV("TOP")
  self:Loc(kh, "KW_HINT")
  S.kwRows = {}
  for i = 1, BB.KW_MAX do
    local idx = i   -- Lua 5.0: Schleifenvariable nicht in Funktionen verwenden
    local row = {}
    local y = -56 - (i - 1) * 26
    row.edit = self:EditBox("BananaBankKeyword" .. i, g, 80)
    row.edit:SetPoint("TOPLEFT", g, "TOPLEFT", 8, y)
    row.edit:SetMaxLetters(6)
    row.edit:SetScript("OnTextChanged", function()
      if S.depotLoading then return end
      local k = S.edit and S.edit.keywords and S.edit.keywords[idx]
      if k then
        k.kw = BB.CleanKeyword(this:GetText())
        S.editDirty = true
      end
    end)
    row.edit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    row.prof = self:Button(g, 210, 20, "", function(btn) UI:OpenKeywordProfPicker(btn, idx) end, "flat")
    row.prof:SetPoint("TOPLEFT", g, "TOPLEFT", 100, y + 1)
    row.del = self:Button(g, 24, 20, "x", function()
      table.remove(S.edit.keywords, idx)
      S.editDirty = true
      UI:RefreshSettings()
    end, "flat")
    row.del:SetPoint("TOPLEFT", g, "TOPLEFT", 320, y + 1)
    S.kwRows[i] = row
  end
  S.kwAdd = self:Button(g, 110, 20, "KW_ADD", function()
    S.edit.keywords = S.edit.keywords or {}
    if getn(S.edit.keywords) < BB.KW_MAX then
      table.insert(S.edit.keywords, { kw = "", prof = "alch" })
      S.editDirty = true
      UI:RefreshSettings()
    end
  end, "flat")
  S.kwAdd:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -318)
  S.kwNote = self:Font(g, 10, C.muted)
  S.kwNote:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -346)
  S.kwNote:SetWidth(420)
  S.kwNote:SetHeight(24)
  S.kwNote:SetJustifyV("TOP")
  S.kwSave = self:Button(g, 150, 22, "RL_SAVE", function()
    if BB:SaveRules(S.edit or {}) then S.editDirty = false end
    UI:RefreshSettings()
  end, "primary")
  S.kwSave:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -374)

  f:SetScript("OnShow", function() UI:RefreshSettings() end)
end

function UI:RefreshSettings()
  local f = self.setWin
  if not f then return end
  local S = self.set
  local isMgr = BB:CanManageQuests()
  local isBank = BB:IsBank()
  for i = 1, getn(S.tabs) do S.tabs[i]:SetActive(S.tabs[i].key == S.tab) end
  local y = -88
  if S.tab == "depots" then
    S.kw:Hide()
    S.gen:Hide()
    S.guild:Hide()
    S.bank:Hide()
    S.rules:Hide()
    S.depot:Show()
    S.depot:ClearAllPoints()
    S.depot:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
    y = y - DEPOT_H - 8
    self:RefreshDepotTab()
    f:SetHeight(-y + 22)
    return
  end
  if S.tab == "keywords" then
    S.gen:Hide()
    S.guild:Hide()
    S.bank:Hide()
    S.rules:Hide()
    S.depot:Hide()
    S.kw:Show()
    S.kw:ClearAllPoints()
    S.kw:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
    y = y - KW_H - 8
    self:RefreshKeywordTab()
    f:SetHeight(-y + 22)
    return
  end
  S.kw:Hide()
  S.depot:Hide()
  if S.tab == "rules" then
    S.gen:Hide()
    S.guild:Hide()
    S.bank:Hide()
    S.rules:Show()
    S.rules:ClearAllPoints()
    S.rules:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
    y = y - RULES_H - 8
    self:RefreshRulesTab()
    f:SetHeight(-y + 22)
    return
  end
  S.rules:Hide()
  S.gen:Show()
  S.gen:ClearAllPoints()
  S.gen:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
  y = y - GEN_H - 8
  if isMgr then
    S.guild:Show()
    S.guild:ClearAllPoints()
    S.guild:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
    y = y - GUILD_H - 8
  else
    S.guild:Hide()
  end
  if isBank or BB:MayBeBank(BB:Me()) then
    S.bank:Show()
    S.bank:ClearAllPoints()
    S.bank:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
    y = y - BANK_H - 8
  else
    S.bank:Hide()
  end
  f:SetHeight(-y + 22)
  local lang = BananaBankDB.lang or "auto"
  for i = 1, getn(S.langChips) do S.langChips[i]:SetActive(S.langChips[i].code == lang) end
  S.cMini.Update()
  S.cTrack.Update()
  S.cDebug.Update()
  if S.cGz then
    S.cGz.Update()
    S.cGz60.Update()
    local gm = BB:GzMode()
    for i = 1, getn(S.gzChips) do S.gzChips[i]:SetActive(S.gzChips[i].code == gm) end
  end
  if S.cBank then S.cBank.Update() S.cCod.Update() S.cWhisper.Update() S.cAuto.Update() S.cBatch.Update() end
  if S.age and not S.ageFocus then S.age:SetText(tostring(BB:PriceMaxAgeDays())) end
  if S.trashList and BB.TrashOverrideCount then S.trashList.fs:SetText(string.format(T("SET_TRASH_LIST"), BB:TrashOverrideCount())) end
  if not S.mainFocus then S.main:SetText(BB:MainBank()) end
end

-- Arbeitskopie der Regeln fuer die Reiter Regeln und Lager
function UI:RefreshRulesData()
  local S = self.set
  if S.editDirty and S.edit then return end
  local rules = BananaBankDB.rules
  S.edit = { depots = BB:DepotList(), depotTypes = BB:DepotTypeListForEdit(), keywords = {} }
  if rules and rules.keywords then
    for i = 1, getn(rules.keywords) do
      table.insert(S.edit.keywords, { kw = rules.keywords[i].kw, prof = rules.keywords[i].prof })
    end
  end
  if rules then
    for i = 1, getn(BB.RULE_KEYS) do
      local sp = rules[BB.RULE_KEYS[i]]
      if sp then S.edit[BB.RULE_KEYS[i]] = { n = sp.n, i = sp.i } end
    end
  end
end

-- Inhalt des Reiters Regeln
function UI:RefreshRulesTab()
  local S = self.set
  local rules = BananaBankDB.rules
  local canEdit = BB:MayBeBank(BB:Me())
  self:RefreshRulesData()
  if rules then
    S.rlStatus:SetText(string.format(T("RL_STATUS_SAVED"), BB.Date(rules.ts), rules.by or "?"))
    S.rlStatus:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
  else
    S.rlStatus:SetText(T("RL_STATUS_NONE"))
    S.rlStatus:SetTextColor(C.orange[1], C.orange[2], C.orange[3])
  end
  for i = 1, getn(BB.RULE_KEYS) do
    local key = BB.RULE_KEYS[i]
    local b = S.rlRows[key]
    local sp = S.edit[key]
    if sp then
      local _, now, found = BB:RuleRank(sp)
      local text = sp.n
      if now and not found then text = sp.n .. " |cffff9a2e> " .. now .. "|r" end
      b.fs:SetText(text)
    else
      b.fs:SetText(T("RL_PICK"))
    end
    b:SetOn(canEdit)
  end
  -- (Lager-Reiter: siehe RefreshDepotTab)
  S.rlHint:SetText(T(canEdit and "RL_HINT" or "RL_READONLY"))
  if canEdit then S.rlSave:Show() else S.rlSave:Hide() end
end

-- Inhalt des Reiters Keywords
function UI:RefreshKeywordTab()
  local S = self.set
  local canEdit = BB:MayBeBank(BB:Me())
  self:RefreshRulesData()
  local list = S.edit.keywords or {}
  S.depotLoading = true
  for i = 1, BB.KW_MAX do
    local row = S.kwRows[i]
    local k = list[i]
    if k then
      row.edit:Show()
      row.prof:Show()
      if canEdit then row.del:Show() else row.del:Hide() end
      if row.edit:GetText() ~= (k.kw or "") then row.edit:SetText(k.kw or "") end
      row.edit:EnableMouse(canEdit and true or false)
      row.prof.fs:SetText(BB:KeywordProfLabel(k.prof))
      row.prof:SetOn(canEdit)
    else
      row.edit:Hide()
      row.prof:Hide()
      row.del:Hide()
    end
  end
  S.depotLoading = false
  if canEdit and getn(list) < BB.KW_MAX then S.kwAdd:Show() else S.kwAdd:Hide() end
  S.kwNote:SetText(T(canEdit and "KW_NOTE" or "RL_READONLY"))
  if canEdit then S.kwSave:Show() else S.kwSave:Hide() end
end

function UI:OpenKeywordProfPicker(btn, idx)
  local entries = {}
  for i = 1, getn(BB.KW_PROFS) do
    table.insert(entries, { label = BB:KeywordProfLabel(BB.KW_PROFS[i]), value = BB.KW_PROFS[i] })
  end
  self:OpenPicker(btn, entries, function(prof)
    local k = UI.set.edit.keywords[idx]
    if k then
      k.prof = prof
      UI.set.editDirty = true
      UI:RefreshSettings()
    end
  end)
end

-- Inhalt des Reiters Lager
function UI:RefreshDepotTab()
  local S = self.set
  local canEdit = BB:MayBeBank(BB:Me())
  if not S.editDirty or not S.edit then self:RefreshRulesData() end
  local types = S.edit.depotTypes or {}
  S.depotLoading = true
  for i = 1, BB.DEPOT_TYPE_MAX do
    local row = S.dpTypes[i]
    local t = types[i]
    if t then
      row.edit:Show()
      if canEdit then row.del:Show() else row.del:Hide() end
      if row.edit:GetText() ~= (t.name or "") then row.edit:SetText(t.name or "") end
      row.edit:EnableMouse(canEdit and true or false)
    else
      row.edit:Hide()
      row.del:Hide()
    end
  end
  S.depotLoading = false
  if canEdit and getn(types) < BB.DEPOT_TYPE_MAX then S.dpAddType:Show() else S.dpAddType:Hide() end
  local dl = S.edit.depots or {}
  for i = 1, BB.DEPOT_MAX do
    local row = S.rlDepot[i]
    local d = dl[i]
    if d then
      row.char:Show()
      row.kind:Show()
      if canEdit then row.del:Show() else row.del:Hide() end
      row.char.fs:SetText(d.n or T("RL_PICK"))
      local tname = T("RL_PICK")
      for j = 1, getn(types) do
        if types[j].id == d.k then tname = types[j].name end
      end
      row.kind.fs:SetText(tname)
      row.char:SetOn(canEdit)
      row.kind:SetOn(canEdit)
    else
      row.char:Hide()
      row.kind:Hide()
      row.del:Hide()
    end
  end
  if canEdit and getn(dl) < BB.DEPOT_MAX and getn(types) > 0 then S.rlAdd:Show() else S.rlAdd:Hide() end
  S.dpHint:SetText(T(canEdit and "DP_HINT" or "RL_READONLY"))
  if canEdit then S.dpSave:Show() else S.dpSave:Hide() end
end

-- Auswahlmenue: entries = { { label = Text, value = beliebig } }, onPick(value)
function UI:OpenPicker(btn, entries, onPick, anyone)
  if not anyone and not BB:MayBeBank(BB:Me()) then return end
  local m = self.rankMenu
  if not m then
    local catch = CreateFrame("Button", nil, UIParent)
    catch:SetAllPoints(UIParent)
    catch:SetFrameStrata("FULLSCREEN_DIALOG")
    catch:SetFrameLevel(60)
    catch:Hide()
    catch:SetScript("OnClick", function() UI:CloseRankPicker() end)
    m = CreateFrame("Frame", nil, UIParent)
    m:SetWidth(210)
    m:SetBackdrop({
      bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    m:SetBackdropColor(0.015, 0.025, 0.06, 1)
    m:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1)
    m:SetFrameStrata("TOOLTIP")
    m:EnableMouse(true)
    m:Hide()
    m.catch = catch
    m.rows = {}
    for i = 1, 14 do
      local row = CreateFrame("Button", nil, m)
      row:SetHeight(18)
      row:SetPoint("TOPLEFT", m, "TOPLEFT", 6, -6 - (i - 1) * 19)
      row:SetPoint("TOPRIGHT", m, "TOPRIGHT", -6, -6 - (i - 1) * 19)
      local hl = row:CreateTexture(nil, "HIGHLIGHT")
      hl:SetTexture(WHITE)
      hl:SetAllPoints(row)
      hl:SetVertexColor(1, 0.82, 0.3, 0.16)
      row.fs = self:Font(row, 11, { 1, 1, 1 })
      row.fs:SetPoint("LEFT", row, "LEFT", 4, 0)
      row.fs:SetWidth(190)
      row.fs:SetHeight(14)
      row:SetScript("OnClick", function()
        local e = this.entry
        local cb = UI.rankMenu.onPick
        UI:CloseRankPicker()
        if e and cb then cb(e.value) end
      end)
      m.rows[i] = row
    end
    self.rankMenu = m
  end
  m.onPick = onPick
  for i = 1, 14 do
    local row = m.rows[i]
    local e = entries[i]
    row.entry = e
    if e then
      row.fs:SetText(e.label)
      row:Show()
    else
      row:Hide()
    end
  end
  local n = math.min(getn(entries), 14)
  m:SetHeight(12 + n * 19)
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
  m.catch:Show()
  m:Show()
end

function UI:OpenRankPicker(btn, key)
  local entries = {}
  local list = BB:RankList()
  for i = 1, getn(list) do table.insert(entries, { label = list[i].n, value = list[i] }) end
  self:OpenPicker(btn, entries, function(rank)
    UI.set.edit = UI.set.edit or {}
    UI.set.edit[key] = { n = rank.n, i = rank.i }
    UI.set.editDirty = true
    UI:RefreshSettings()
  end)
end

-- Lagerchar waehlen: alle Bank-Chars, die das Addon kennt (diese Konten und die Gilde)
function UI:OpenDepotCharPicker(btn, idx)
  local entries = {}
  local names = BB:BankList()
  for i = 1, getn(names) do table.insert(entries, { label = names[i], value = names[i] }) end
  self:OpenPicker(btn, entries, function(name)
    local d = UI.set.edit.depots[idx]
    if d then
      d.n = name
      UI.set.editDirty = true
      UI:RefreshSettings()
    end
  end)
end

function UI:OpenDepotKindPicker(btn, idx)
  local entries = {}
  local types = UI.set.edit.depotTypes or {}
  for i = 1, getn(types) do
    if types[i].id then table.insert(entries, { label = types[i].name, value = types[i].id }) end
  end
  self:OpenPicker(btn, entries, function(kind)
    local d = UI.set.edit.depots[idx]
    if d then
      d.k = kind
      UI.set.editDirty = true
      UI:RefreshSettings()
    end
  end)
end

function UI:CloseRankPicker()
  if not self.rankMenu then return end
  self.rankMenu:Hide()
  self.rankMenu.catch:Hide()
end

function UI:ToggleSettings()
  self:BuildSettings()
  local f = self.setWin
  if f:IsVisible() then f:Hide() else f:Show() end
end

-- ------------------------------------------------------------
-- Von Hand buchen
-- ------------------------------------------------------------
function UI:OpenBookDialog()
  local d = self.bookDlg
  if not d then
    d = CreateFrame("Frame", "BananaBankBookDlg", UIParent)
    d:SetWidth(340)
    d:SetHeight(190)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    d:SetFrameStrata("TOOLTIP")
    d:EnableMouse(true)
    d:SetBackdrop({
      bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    d:SetBackdropColor(0.015, 0.025, 0.06, 1)
    d:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1)
    d:Hide()
    tinsert(UISpecialFrames, "BananaBankBookDlg")
    local t = self:Font(d, 13, C.gold)
    t:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -12)
    self:Loc(t, "SET_BOOK_TITLE")
    local function row(key, y, w, name)
      local l = self:Font(d, 11, C.text)
      l:SetPoint("TOPLEFT", d, "TOPLEFT", 14, y)
      self:Loc(l, key)
      local e = self:EditBox(name, d, w)
      e:SetPoint("TOPLEFT", d, "TOPLEFT", 120, y + 5)
      return e
    end
    d.player = row("SET_BOOK_PLAYER", -42, 180, "BananaBankBookPlayer")
    d.count = row("SET_BOOK_COUNT", -70, 70, "BananaBankBookCount")
    d.count:SetNumeric(true)
    d.item = row("SET_BOOK_ITEM", -98, 190, "BananaBankBookItem")
    d.ok = self:Button(d, 110, 22, "SET_BOOK_GO", function()
      BB:ManualBook(d.player:GetText(), d.count:GetText(), d.item:GetText())
      d:Hide()
      UI:Refresh()
    end, "ok")
    d.ok:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 14)
    d.no = self:Button(d, 90, 22, "PAY_CANCEL", function() d:Hide() end)
    d.no:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 14)
    self.bookDlg = d
  end
  d.player:SetText("")
  d.count:SetText("")
  d.item:SetText("")
  d:Show()
  d.player:SetFocus()
end
