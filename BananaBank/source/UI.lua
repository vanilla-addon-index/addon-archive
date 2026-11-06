-- BananaBank UI Teil 1: Stil, Hauptfenster, Bestand, Export, Danke-Fenster, Minimap

local BB = BananaBank
local T = function(k) return BB.T(k) end
local getn = table.getn
local floor = math.floor

BB.UI = { loc = {}, tabs = {}, pages = {} }
local UI = BB.UI

local MEDIA = "Interface\\AddOns\\BananaBank\\Media\\"
local FONT = "Fonts\\FRIZQT__.TTF"
local FONT_TITLE = "Fonts\\MORPHEUS.TTF"
local WHITE = "Interface\\ChatFrame\\ChatFrameBackground"

UI.MEDIA, UI.FONT, UI.FONT_TITLE, UI.WHITE = MEDIA, FONT, FONT_TITLE, WHITE

-- Farben passend zum Logo: Nachtblau, Messing, Bananengold
UI.C = {
  gold = { 1.00, 0.82, 0.26 },
  goldDim = { 0.78, 0.60, 0.22 },
  brass = { 0.55, 0.40, 0.16 },
  text = { 0.92, 0.90, 0.84 },
  muted = { 0.60, 0.62, 0.70 },
  bg = { 0.03, 0.045, 0.09 },
  panel = { 0.055, 0.08, 0.16 },
  blue = { 0.08, 0.16, 0.36 },
  green = { 0.35, 0.85, 0.35 },
  red = { 0.95, 0.30, 0.25 },
  orange = { 1.00, 0.60, 0.15 },
}
local C = UI.C

UI.STATUS_COLOR = {
  open = { 0.95, 0.75, 0.20 },
  confirmed = { 0.30, 0.65, 1.00 },
  sent = { 0.35, 0.85, 0.35 },
  rejected = { 0.90, 0.30, 0.25 },
  cancelled = { 0.55, 0.55, 0.55 },
  expired = { 0.45, 0.45, 0.50 },
}

-- ------------------------------------------------------------
-- Bausteine
-- ------------------------------------------------------------
function UI:Font(parent, size, color, font, flags)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(font or FONT, size or 12, flags or "")
  color = color or C.text
  fs:SetTextColor(color[1], color[2], color[3])
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)
  fs:SetJustifyH("LEFT")
  return fs
end

function UI:Loc(fs, key)
  fs:SetText(T(key))
  table.insert(self.loc, { fs = fs, key = key })
  return fs
end

function UI:Tex(parent, layer, r, g, b, a)
  local t = parent:CreateTexture(nil, layer or "ARTWORK")
  t:SetTexture(r, g, b, a or 1)
  return t
end

function UI:HLine(parent, y, x1, x2, color, alpha)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetTexture(WHITE)
  color = color or C.goldDim
  t:SetVertexColor(color[1], color[2], color[3], alpha or 0.8)
  t:SetHeight(1)
  t:SetPoint("TOPLEFT", parent, "TOPLEFT", x1, y)
  t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x2, y)
  return t
end

-- Gold-Verlauf: in der Mitte hell, nach aussen transparent
function UI:GlowLine(parent, y, x1, x2)
  local l = parent:CreateTexture(nil, "ARTWORK")
  l:SetTexture(WHITE)
  l:SetHeight(1)
  l:SetPoint("TOPLEFT", parent, "TOPLEFT", x1, y)
  l:SetPoint("TOPRIGHT", parent, "TOP", 0, y)
  l:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0.26, 0, 1, 0.82, 0.26, 0.9)
  local r = parent:CreateTexture(nil, "ARTWORK")
  r:SetTexture(WHITE)
  r:SetHeight(1)
  r:SetPoint("TOPLEFT", parent, "TOP", 0, y)
  r:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x2, y)
  r:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0.26, 0.9, 1, 0.82, 0.26, 0)
end

UI.BACKDROP_PANEL = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- Deckender Untergrund: der Tooltip-Hintergrund ist halbtransparent, darunter schimmern
-- sonst Raster und Texte durch (Menues, Fenster ueber dem Hauptfenster).
function UI:Solid(f, inset, alpha)
  local t = f:CreateTexture(nil, "BACKGROUND")
  t:SetTexture(WHITE)
  t:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
  t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
  t:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], alpha or 1)
  return t
end

function UI:Panel(parent, w, h)
  local p = CreateFrame("Frame", nil, parent)
  if w then p:SetWidth(w) end
  if h then p:SetHeight(h) end
  p:SetBackdrop(self.BACKDROP_PANEL)
  p:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.92)
  p:SetBackdropBorderColor(C.brass[1], C.brass[2], C.brass[3], 0.9)
  -- deckender Untergrund: sonst schimmern Namen und Texte aus der Spielwelt durch und stoeren das Lesen
  local solid = p:CreateTexture(nil, "BACKGROUND")
  solid:SetTexture(WHITE)
  solid:SetPoint("TOPLEFT", p, "TOPLEFT", 3, -3)
  solid:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -3, 3)
  solid:SetVertexColor(C.panel[1], C.panel[2], C.panel[3], 0.985)
  return p
end

-- Knopf im BananaForge-Stil. style: nil | "primary" | "danger" | "ok" | "flat"
function UI:Button(parent, w, h, key, onClick, style)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(w)
  b:SetHeight(h)
  b:SetBackdrop(self.BACKDROP_PANEL)
  local bg = { 0.09, 0.13, 0.27 }
  local tc = C.gold
  if style == "primary" then
    bg = { 0.50, 0.34, 0.05 }
    tc = { 1, 0.95, 0.80 }
  elseif style == "danger" then
    bg = { 0.38, 0.08, 0.06 }
    tc = { 1, 0.85, 0.80 }
  elseif style == "ok" then
    bg = { 0.10, 0.32, 0.12 }
    tc = { 0.85, 1, 0.85 }
  elseif style == "flat" then
    bg = { 0.05, 0.07, 0.14 }
  end
  b.bgColor, b.textColor = bg, tc
  b:SetBackdropColor(bg[1], bg[2], bg[3], 0.95)
  b:SetBackdropBorderColor(C.goldDim[1], C.goldDim[2], C.goldDim[3], 0.9)

  local shine = b:CreateTexture(nil, "BORDER")
  shine:SetTexture(WHITE)
  shine:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  shine:SetPoint("BOTTOMRIGHT", b, "RIGHT", -3, 0)
  shine:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.07)

  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture(WHITE)
  hl:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  hl:SetVertexColor(1, 0.82, 0.3, 0.15)

  local fs = self:Font(b, h >= 26 and 13 or 11, tc)
  fs:SetPoint("CENTER", b, "CENTER", 0, 0)
  fs:SetJustifyH("CENTER")
  b.fs = fs
  if key then
    if BB.L.enUS[key] then self:Loc(fs, key) else fs:SetText(key) end
  end
  b:SetScript("OnClick", function()
    if b.disabled then return end
    PlaySound("igMainMenuOptionCheckBoxOn")
    if onClick then onClick(b, arg1) end
  end)
  b.SetOn = function(self2, on)
    b.disabled = not on
    if on then
      fs:SetTextColor(tc[1], tc[2], tc[3])
      b:SetBackdropColor(bg[1], bg[2], bg[3], 0.95)
      b:SetBackdropBorderColor(C.goldDim[1], C.goldDim[2], C.goldDim[3], 0.9)
    else
      fs:SetTextColor(0.45, 0.45, 0.48)
      b:SetBackdropColor(0.06, 0.06, 0.08, 0.9)
      b:SetBackdropBorderColor(0.3, 0.3, 0.32, 0.8)
    end
  end
  return b
end

-- Umschalter mit Haken
function UI:Check(parent, key, getter, setter)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(150)
  b:SetHeight(18)
  local box = CreateFrame("Frame", nil, b)
  box:SetWidth(16)
  box:SetHeight(16)
  box:SetPoint("LEFT", b, "LEFT", 0, 0)
  box:SetBackdrop(self.BACKDROP_PANEL)
  box:SetBackdropColor(0.02, 0.03, 0.06, 1)
  box:SetBackdropBorderColor(C.goldDim[1], C.goldDim[2], C.goldDim[3], 1)
  local chk = box:CreateTexture(nil, "OVERLAY")
  chk:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  chk:SetWidth(22)
  chk:SetHeight(22)
  chk:SetPoint("CENTER", box, "CENTER", 1, 1)
  local fs = self:Font(b, 11, C.text)
  fs:SetPoint("LEFT", box, "RIGHT", 6, 0)
  self:Loc(fs, key)
  b.fs = fs
  b.Update = function()
    if getter() then chk:Show() else chk:Hide() end
  end
  b:SetScript("OnClick", function()
    setter(not getter())
    PlaySound("igMainMenuOptionCheckBoxOn")
    b.Update()
  end)
  b.Update()
  return b
end

-- kleiner Filter-Chip
function UI:Chip(parent, w, key, onClick)
  local b = self:Button(parent, w, 18, key, onClick, "flat")
  b.SetActive = function(self2, on)
    if on then
      b.fs:SetTextColor(1, 0.9, 0.5)
      b:SetBackdropColor(0.35, 0.25, 0.05, 0.95)
    else
      b.fs:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
      b:SetBackdropColor(0.05, 0.07, 0.14, 0.95)
    end
  end
  return b
end

function UI:EditBox(name, parent, w)
  local e = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
  e:SetWidth(w)
  e:SetHeight(20)
  e:SetAutoFocus(false)
  e:SetFontObject("ChatFontNormal")
  e:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  return e
end

-- Item-Feld mit Qualitaetsrahmen
function UI:Slot(parent, size)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(size)
  b:SetHeight(size)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(0, 0, 0, 0.55)
  bg:SetAllPoints(b)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.icon = icon
  b.edges = {}
  local function edge(p1, p2, horiz)
    local t = b:CreateTexture(nil, "OVERLAY")
    t:SetTexture(WHITE)
    t:SetPoint(p1, b, p1, 0, 0)
    t:SetPoint(p2, b, p2, 0, 0)
    if horiz then t:SetHeight(1) else t:SetWidth(1) end
    table.insert(b.edges, t)
  end
  edge("TOPLEFT", "TOPRIGHT", true)
  edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
  edge("TOPLEFT", "BOTTOMLEFT", false)
  edge("TOPRIGHT", "BOTTOMRIGHT", false)
  local glow = b:CreateTexture(nil, "OVERLAY")
  glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  glow:SetBlendMode("ADD")
  glow:SetWidth(size * 1.75)
  glow:SetHeight(size * 1.75)
  glow:SetPoint("CENTER", b, "CENTER", 0, 0)
  glow:SetAlpha(0.55)
  b.glow = glow
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
  hl:SetBlendMode("ADD")
  hl:SetAllPoints(icon)
  b.count = self:Font(b, 12, { 1, 1, 1 }, FONT, "OUTLINE")
  b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  b.count:SetJustifyH("RIGHT")
  b.badge = self:Font(b, 10, C.gold, FONT, "OUTLINE")
  b.badge:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -2)
  b.badge:SetJustifyH("RIGHT")
  b.res = self:Font(b, 9, C.orange, FONT, "OUTLINE")
  b.res:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  b.SetQuality = function(self2, q)
    local c = BB.QUALITY_COLOR[q or 1] or BB.QUALITY_COLOR[1]
    local a = 0.9
    if (q or 1) <= 1 then
      c = { 0.35, 0.33, 0.28 }
      a = 1
    end
    for i = 1, 4 do b.edges[i]:SetVertexColor(c[1], c[2], c[3], a) end
    if (q or 1) >= 2 then
      b.glow:SetVertexColor(c[1], c[2], c[3])
      b.glow:Show()
    else
      b.glow:Hide()
    end
  end
  return b
end

-- Item-Tooltip nur ueber Cache (SetHyperlink auf unbekannte Items kann in 1.12 trennen)
function UI:ItemTooltip(owner, id, extra)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  -- Items, die dieser Client noch nie gesehen hat, kennt er nicht. Den Server danach zu fragen
  -- (SetHyperlink) ist in 1.12 nur mit Umschalt gedrueckt erlaubt, weil ein falsches Item den Client trennen kann.
  local known = GetItemInfo(id)
  if not known and IsShiftKeyDown() and type(id) == "number" and id > 0 and id < 100000 then
    GameTooltip:SetHyperlink("item:" .. id .. ":0:0:0")
    known = true
  elseif known then
    GameTooltip:SetHyperlink("item:" .. id .. ":0:0:0")
  else
    local n, q = BB:ItemInfo(id)
    local c = BB.QUALITY_COLOR[q or 1] or BB.QUALITY_COLOR[1]
    GameTooltip:AddLine(n, c[1], c[2], c[3])
    local e = BB.stockCache and BB.stockCache[id]
    if e and e.k and e.k ~= "other" then
      local cat = BB:CatName(e.k)
      if e.s and BB.T("SUB_" .. string.upper(e.s)) then cat = cat .. ": " .. BB.T("SUB_" .. string.upper(e.s)) end
      GameTooltip:AddLine(cat, 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine(BB.T("TT_UNKNOWN"), 1, 0.65, 0.2)
  end
  if extra then
    GameTooltip:AddLine(" ")
    for i = 1, getn(extra) do
      local l = extra[i]
      GameTooltip:AddDoubleLine(l[1], l[2] or "", 0.8, 0.8, 0.8, l[3] or 1, l[4] or 1, l[5] or 1)
    end
  end
  GameTooltip:Show()
end

-- ------------------------------------------------------------
-- Hauptfenster
-- ------------------------------------------------------------
function UI:Init()
  if self.frame then return end
  local f = CreateFrame("Frame", "BananaBankFrame", UIParent)
  self.frame = f
  f:SetWidth(790)
  f:SetHeight(530)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
  f:SetFrameStrata("HIGH")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.97)
  self:Solid(f, 12, 0.985)
  f:Hide()
  tinsert(UISpecialFrames, "BananaBankFrame")
  f:SetScript("OnShow", function() UI:Refresh() end)

  -- Kopfbereich: blauer Verlauf wie das Banner im Logo
  local head = f:CreateTexture(nil, "BORDER")
  head:SetTexture(WHITE)
  head:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -12)
  head:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -12, -78)
  head:SetGradientAlpha("VERTICAL", C.bg[1], C.bg[2], C.bg[3], 0, C.blue[1], C.blue[2], C.blue[3], 0.75)

  local logoHolder = CreateFrame("Frame", nil, f)
  logoHolder:SetWidth(64)
  logoHolder:SetHeight(64)
  logoHolder:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
  logoHolder:SetFrameLevel(f:GetFrameLevel() + 10)
  local logo = logoHolder:CreateTexture(nil, "OVERLAY")
  logo:SetTexture(MEDIA .. "Logo64")
  logo:SetAllPoints(logoHolder)

  local title = self:Font(f, 26, C.gold, FONT_TITLE)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 84, -16)
  title:SetText("BananaBank")
  local forge = self:Font(f, 10, C.goldDim)
  forge:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 6)
  forge:SetText("by BananaForge  v" .. BB.VERSION)
  self.subtitle = self:Font(f, 11, C.muted)
  self.subtitle:SetPoint("TOPLEFT", f, "TOPLEFT", 86, -50)
  self.subtitle:SetWidth(440)
  self.subtitle:SetHeight(14)

  -- rechts oben: Unterstuetzen, DE/EN, Schliessen
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
  self.enBtn = self:Button(f, 30, 18, "EN", function() UI:SetLanguage("enUS") end, "flat")
  self.enBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -15)
  self.deBtn = self:Button(f, 30, 18, "DE", function() UI:SetLanguage("deDE") end, "flat")
  self.deBtn:SetPoint("RIGHT", self.enBtn, "LEFT", -4, 0)
  self.supportBtn = self:Button(f, 96, 18, "BTN_SUPPORT", function() UI:ShowThanks() end, "flat")
  self.supportBtn:SetPoint("RIGHT", self.deBtn, "LEFT", -8, 0)
  if self.BuildHelpButton then
    self.helpBtn = self:BuildHelpButton(f)
    self.helpBtn:SetPoint("RIGHT", self.supportBtn, "LEFT", -6, 0)
  end
  if self.BuildSettingsButton then
    self.setBtn = self:BuildSettingsButton(f)
    self.setBtn:SetPoint("RIGHT", self.helpBtn or self.supportBtn, "LEFT", -6, 0)
    self:BuildMainBankLabel(f)
    self:RefreshMainBank()
  end

  self:GlowLine(f, -76, 80, -16)

  -- Reiter
  local tabDefs = {
    { key = "TAB_STOCK", page = "stock" },
    { key = "TAB_REQUESTS", page = "requests" },
    { key = "TAB_LEDGER", page = "ledger" },
    { key = "TAB_PRICES", page = "prices" },
    { key = "TAB_QUESTS", page = "quests" },
    { key = "TAB_BANKS", page = "banks" },
  }
  local prev
  for i = 1, getn(tabDefs) do
    local d = tabDefs[i]
    local tb = CreateFrame("Button", nil, f)
    tb:SetWidth(92)
    tb:SetHeight(26)
    if prev then tb:SetPoint("LEFT", prev, "RIGHT", 2, 0) else tb:SetPoint("TOPLEFT", f, "TOPLEFT", 84, -80) end
    local fs = self:Font(tb, 13, C.muted)
    fs:SetPoint("CENTER", tb, "CENTER", 0, 1)
    fs:SetJustifyH("CENTER")
    self:Loc(fs, d.key)
    tb.fs = fs
    local bar = tb:CreateTexture(nil, "OVERLAY")
    bar:SetTexture(WHITE)
    bar:SetHeight(2)
    bar:SetPoint("BOTTOMLEFT", tb, "BOTTOMLEFT", 8, 0)
    bar:SetPoint("BOTTOMRIGHT", tb, "BOTTOMRIGHT", -8, 0)
    bar:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
    tb.bar = bar
    local hl = tb:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(WHITE)
    hl:SetAllPoints(tb)
    hl:SetGradientAlpha("VERTICAL", 1, 0.82, 0.3, 0.12, 1, 0.82, 0.3, 0)
    tb.page = d.page
    tb:SetScript("OnClick", function()
      PlaySound("igCharacterInfoTab")
      UI:ShowPage(this.page)
    end)
    self.tabs[d.page] = tb
    prev = tb
  end

  -- Inhaltsbereich
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -114)
  content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 18)
  self.content = content

  self:BuildStock(content)
  self:BuildRequests(content)
  self:BuildLedger(content)
  if self.BuildPrices then self:BuildPrices(content) end
  if self.BuildQuests then self:BuildQuests(content) end
  if self.BuildBanks then self:BuildBanks(content) end
  self:BuildBank(content)
  self:BuildExport()
  self:BuildThanks()
  self:BuildMailHelper()
  self:BuildGate(f)

  self:OnBankModeChanged()
  self:UpdateLangButtons()
  self:ShowPage("stock")
end

-- Sperrschirm: ohne den Bank-Rang in der Gilde ist das Addon nicht nutzbar
function UI:BuildGate(f)
  local g = CreateFrame("Frame", nil, f)
  g:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -72)
  g:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
  g:SetFrameLevel(f:GetFrameLevel() + 30)
  g:EnableMouse(true)
  local bg = g:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(WHITE)
  bg:SetAllPoints(g)
  bg:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 1)
  g.title = self:Font(g, 18, C.red)
  g.title:SetPoint("TOP", g, "TOP", 0, -120)
  g.text = self:Font(g, 13, C.muted)
  g.text:SetPoint("TOP", g.title, "BOTTOM", 0, -16)
  g.text:SetWidth(520)
  g.text:SetJustifyH("CENTER")
  g:Hide()
  self.gate = g
end

function UI:UpdateGate()
  local g = self.gate
  if not g then return false end
  if BB:Ready() then
    g:Hide()
    return false
  end
  g.title:SetText(T("GATE_TITLE"))
  if not IsInGuild() then
    g.text:SetText(T("GATE_NO_GUILD"))
  elseif not BB.rosterReady then
    g.text:SetText(T("GATE_LOADING"))
  else
    g.text:SetText(T("GATE_NO_RANK"))
  end
  g:Show()
  return true
end

function UI:ShowPage(page)
  if page == "bank" and not BB:IsBank() then page = "stock" end
  if page == "prices" and not self.pages.prices then page = "stock" end
  if page == "quests" and not self.pages.quests then page = "stock" end
  if page == "banks" and (not self.pages.banks or not BB:IsBank()) then page = "stock" end
  self.page = page
  -- die Bankansicht ist kein eigener Reiter, sie liegt ueber den Anfragen
  local hl = page
  if hl == "bank" then hl = "requests" end
  for name, p in pairs(self.pages) do
    if name == page then p:Show() else p:Hide() end
  end
  if self.tabs.prices and not self.pages.prices then self.tabs.prices:Hide() end
  if self.tabs.quests and not self.pages.quests then self.tabs.quests:Hide() end
  if self.tabs.banks and not self.pages.banks then self.tabs.banks:Hide() end
  for name, tb in pairs(self.tabs) do
    if name == hl then
      tb.fs:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
      tb.bar:Show()
    else
      tb.fs:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
      tb.bar:Hide()
    end
  end
  self:Refresh()
end

function UI:OnBankModeChanged()
  if not self.frame then return end
  -- Bank-Reiter und alles zum Bank-Verzeichnis gibt es nur auf Chars im Bank-Modus
  if self.reqBankBtn then
    if BB:IsBank() then self.reqBankBtn:Show() else self.reqBankBtn:Hide() end
  end
  if self.tabs.banks then
    if BB:IsBank() and self.pages.banks then self.tabs.banks:Show() else self.tabs.banks:Hide() end
  end
  if (self.page == "bank" or self.page == "banks") and not BB:IsBank() then self:ShowPage("stock") end
  self:Refresh()
end

function UI:Toggle()
  self:Init()
  if self.frame:IsVisible() then self.frame:Hide() else self.frame:Show() end
end

function UI:SetLanguage(lang)
  BananaBankDB.lang = lang
  BB:ApplyLanguage()
  for i = 1, getn(self.loc) do
    local e = self.loc[i]
    e.fs:SetText(T(e.key))
  end
  self:UpdateLangButtons()
  self:Refresh()
  if self.RefreshHelp then self:RefreshHelp() end
  if self.setWin and self.setWin:IsVisible() then self:RefreshSettings() end
  BB:Print(T("MSG_LANGUAGE"))
end

function UI:UpdateLangButtons()
  if not self.deBtn then return end
  local de = BB.lang == "deDE"
  local on, off = C.gold, { 0.5, 0.5, 0.5 }
  local a, b = on, off
  if not de then a, b = off, on end
  self.deBtn.fs:SetTextColor(a[1], a[2], a[3])
  self.enBtn.fs:SetTextColor(b[1], b[2], b[3])
end

function UI:Refresh()
  if not self.frame then return end
  self:RefreshMailHelper()
  if self.RefreshLotse then self:RefreshLotse() end
  if self.RefreshQuestTracker then self:RefreshQuestTracker() end
  if self.RefreshSummaryWindows then self:RefreshSummaryWindows() end
  if self.RefreshMainBank then self:RefreshMainBank() end
  if self.setWin and self.setWin:IsVisible() then self:RefreshSettings() end
  if not self.frame:IsVisible() then return end
  if self:UpdateGate() then return end
  local snap = BB:NewestSnapshot()
  if snap then
    local stock = BB:GetStock()
    local n = 0
    for _, e in pairs(stock) do n = n + e.c end
    local line = string.format(T("SUBTITLE"), BB.Date(snap.ts), n, BB.Money(BB:TotalGold()))
    local partial = false
    for _, sn in pairs(BananaBankDB.snaps) do
      if sn.partial then partial = true end
    end
    if partial then line = line .. "   |cffff8000" .. T("SUBTITLE_PARTIAL") .. "|r" end
    self.subtitle:SetText(line)
  else
    self.subtitle:SetText(T("SUBTITLE_EMPTY"))
  end
  local p = self.page
  if p == "stock" then self:RefreshStock()
  elseif p == "requests" then self:RefreshRequests()
  elseif p == "ledger" then self:RefreshLedger()
  elseif p == "prices" then
    if self.RefreshPrices then self:RefreshPrices() end
  elseif p == "quests" then
    if self.RefreshQuests then self:RefreshQuests() end
  elseif p == "banks" then
    if self.RefreshBanks then self:RefreshBanks() end
  elseif p == "bank" then self:RefreshBank() end
end

-- ------------------------------------------------------------
-- Reiter Bestand
-- ------------------------------------------------------------
local COLS, ROWS, SIZE, GAP = 10, 7, 40, 5

function UI:BuildStock(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints(parent)
  self.pages.stock = p
  self.stock = { page = 1, filter = 0, onlyAvail = false, search = "", type = "all", view = "list" }
  local S = self.stock

  local search = self:EditBox("BananaBankSearch", p, 110)
  search:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -2)
  local ph = self:Font(search, 11, C.muted)
  ph:SetPoint("LEFT", search, "LEFT", 2, 0)
  self:Loc(ph, "SEARCH")
  search:SetScript("OnTextChanged", function()
    local txt = this:GetText() or ""
    if txt == "" then ph:Show() else ph:Hide() end
    S.search = string.lower(txt)
    S.page = 1
    UI:RefreshStock()
  end)
  search:SetScript("OnEnterPressed", function() this:ClearFocus() end)

  S.chips = {}
  local chipDefs = { { "FILTER_ALL", 0 }, { "FILTER_GREEN", 2 }, { "FILTER_BLUE", 3 }, { "FILTER_EPIC", 4 } }
  local prev = search
  for i = 1, getn(chipDefs) do
    local q = chipDefs[i][2]
    local chip = self:Chip(p, 42, chipDefs[i][1], function()
      S.filter = q
      S.page = 1
      UI:RefreshStock()
    end)
    chip.q = q
    chip:SetPoint("LEFT", prev, "RIGHT", i == 1 and 12 or 4, 0)
    table.insert(S.chips, chip)
    prev = chip
  end
  -- Schalter rechtsbuendig mit der Ergebnisliste (die endet 238 vor dem rechten Rand), gleiche Zeile wie die Qualitaetsknoepfe
  S.availChip = self:Chip(p, 84, "ONLY_AVAILABLE", function()
    S.onlyAvail = not S.onlyAvail
    S.page = 1
    UI:RefreshStock()
  end)
  S.availChip:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(244 + 64 + 4), -2)
  -- nur auf Bank-Chars: nur Trash zeigen (Haendlerwert unter der Grenze)
  S.onlyTrash = false
  S.trashChk = self:Chip(p, 64, "TRASH_ONLY", function()
    S.onlyTrash = not S.onlyTrash
    S.page = 1
    UI:RefreshStock()
  end)
  S.trashChk:SetPoint("TOPRIGHT", p, "TOPRIGHT", -244, -2)
  S.bank = nil
  -- Einzelansicht einer Bank (aus Banken > Inhalt zeigen): Knopf zum Zuruecksetzen
  S.bankChip = self:Chip(p, 170, "", function()
    S.bank = nil
    S.page = 1
    UI:RefreshStock()
  end)
  S.bankChip:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -244, 4)
  S.bankChip:Hide()
  -- altes Auswahlmenue bleibt als Code erhalten, der Knopf ist aber nie sichtbar
  S.bankBtn = self:Button(p, 140, 18, "", function() UI:ToggleBankMenu() end, "flat")
  S.bankBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 126, -27)
  S.bankBtn:Hide()
  S.role = self:Font(p, 10, C.goldDim)
  S.role:SetPoint("LEFT", S.bankBtn, "RIGHT", 8, 0)
  S.role:SetWidth(180)
  S.role:SetHeight(12)
  S.role:Hide()

  -- Ansicht (Symbole/Liste), Kategorienbaum und Ergebnisliste im AH-Stil: UI_Filter.lua
  self:BuildStockView(p)
  S.info = self:Font(p, 11, C.muted)
  S.info:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 8, 6)
  S.info:SetWidth(300)

  -- Warenkorb rechts
  local cart = self:Panel(p, 232, 0)
  cart:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -30)
  cart:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 26)
  local ct = self:Font(cart, 15, C.gold, FONT_TITLE)
  ct:SetPoint("TOPLEFT", cart, "TOPLEFT", 12, -10)
  self:Loc(ct, "CART_TITLE")
  self:HLine(cart, -32, 10, -10, C.brass, 0.9)
  -- ohne Code-Knopf unten ist unten mehr Platz
  local bo = BB.USE_CODE and 0 or 24
  S.cartRows = {}
  for i = 1, 4 do
    local row = CreateFrame("Frame", nil, cart)
    row:SetWidth(212)
    row:SetHeight(28)
    row:SetPoint("TOPLEFT", cart, "TOPLEFT", 10, -38 - (i - 1) * 30)
    local ic = self:Slot(row, 26)
    ic:SetPoint("LEFT", row, "LEFT", 0, 0)
    ic:SetScript("OnEnter", function() if this.id then UI:ItemTooltip(this, this.id) end end)
    ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.ic = ic
    row.name = self:Font(row, 11, C.text)
    row.name:SetPoint("LEFT", ic, "RIGHT", 6, 0)
    row.name:SetWidth(88)
    row.name:SetHeight(13)
    row.cnt = self:Font(row, 12, C.gold)
    row.cnt:SetPoint("RIGHT", row, "RIGHT", -46, 0)
    row.cnt:SetJustifyH("RIGHT")
    -- Gildencrafter: Rezept kostenlos anfragen (nur sichtbar, wenn das Keyword zum Beruf des Rezepts passt)
    row.claim = self:Button(row, 22, 20, "G", function()
      BB:ToggleClaim(row.id)
      UI:RefreshStock()
    end, "flat")
    row.claim:SetPoint("LEFT", row, "LEFT", 124, 0)
    row.claim:SetScript("OnEnter", function()
      if not row.id then return end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(T("CR_BTN_TIP"), 1, 0.82, 0.2)
      local why = BB:CraftText(row.id)
      if why then GameTooltip:AddLine(why, 1, 0.5, 0.25, 1) else GameTooltip:AddLine(T("CR_BTN_OK"), 0.6, 1, 0.6, 1) end
      GameTooltip:Show()
    end)
    row.claim:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.claim:Hide()
    local minus = self:Button(row, 20, 20, "-", function() UI:CartAdd(row.id, -1) end, "flat")
    minus:SetPoint("RIGHT", row, "RIGHT", -22, 0)
    local plus = self:Button(row, 20, 20, "+", function() UI:CartAdd(row.id, 1) end, "flat")
    plus:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    table.insert(S.cartRows, row)
  end
  S.cartEmpty = self:Font(cart, 11, C.muted)
  S.cartEmpty:SetPoint("TOPLEFT", cart, "TOPLEFT", 14, -46)
  S.cartEmpty:SetWidth(208)
  self:Loc(S.cartEmpty, "CART_EMPTY")
  S.cartSum = self:Font(cart, 11, C.muted)
  S.cartSum:SetPoint("BOTTOMLEFT", cart, "BOTTOMLEFT", 12, 76 - bo)
  S.cartSum:SetWidth(208)
  S.cartPrice = self:Font(cart, 11, C.gold)
  S.cartPrice:SetPoint("BOTTOMLEFT", cart, "BOTTOMLEFT", 12, 90 - bo)
  S.cartPrice:SetWidth(208)
  S.cartLock = self:Font(cart, 10, C.orange)
  S.cartLock:SetPoint("BOTTOMLEFT", cart, "BOTTOMLEFT", 12, 112 - bo)
  S.cartLock:SetWidth(208)
  S.cartLock:SetHeight(26)
  S.cartLock:SetJustifyV("BOTTOM")
  local hint = self:Font(cart, 9, C.muted)
  hint:SetPoint("BOTTOMLEFT", cart, "BOTTOMLEFT", 12, 62 - bo)
  hint:SetWidth(208)
  self:Loc(hint, "CART_HINT")
  local clear = self:Button(cart, 66, 22, "BTN_CLEAR", function()
    BananaBankDB.basket = {}
    UI:RefreshStock()
  end, "flat")
  clear:SetPoint("BOTTOMLEFT", cart, "BOTTOMLEFT", 10, 32 - bo)
  S.makeBtn = self:Button(cart, 134, 22, "BTN_MAKE_CODE", function() UI:MakeCode() end, "primary")
  S.makeBtn:SetPoint("LEFT", clear, "RIGHT", 6, 0)
  S.lastCodeBtn = self:Button(cart, 212, 20, "BTN_LAST_CODE", function()
    if UI.lastReq then UI:ShowExport(UI.lastReq) end
  end, "flat")
  S.lastCodeBtn:SetPoint("BOTTOMLEFT", cart, "BOTTOMLEFT", 10, 8)
end

function UI:StockList()
  local S = self.stock
  local stock = BB:GetStock()
  local res = BB:GetReserved()
  -- Einzelansicht: nur der Bestand dieser Bank, ohne Reservierungen
  if S.bank and not BB:IsBank() then S.bank = nil end
  if S.bank then
    if BB:MayBeBank(S.bank) then
      local one = {}
      local snap = BananaBankDB.snaps[S.bank]
      -- eine Bank ohne Scan zeigt eine leere Liste mit Hinweis, springt nicht zurueck
      for id, it in pairs(snap and snap.items or {}) do
        if not BananaBankDB.hidden[id] then
          one[id] = { c = it.c, q = it.q, t = it.t, n = it.n, k = it.k, s = it.s, cr = it.cr, per = { [S.bank] = it.c } }
        end
      end
      stock, res = one, {}
    else
      S.bank = nil
    end
  end
  local list = {}
  local typeSpec = S.type and BB:FindTypeFilter(S.type) or nil
  -- Lager (Willkommenspakete, Raid Stuff): eigener Bestand, nur zum Ansehen
  S.depotStock = nil
  if S.type and string.sub(S.type, 1, 6) == "depot:" then
    stock, res = BB:DepotStock(string.sub(S.type, 7)), {}
    S.depotStock = stock
    typeSpec = nil
  end
  for id, e in pairs(stock) do
    local avail = e.c - (res[id] or 0)
    if avail < 0 then avail = 0 end
    local ok = (e.q or 1) >= S.filter
    if ok and S.search ~= "" and not string.find(string.lower(e.n or ""), S.search, 1, true) then ok = false end
    if ok and S.onlyAvail and avail <= 0 then ok = false end
    if ok and S.onlyTrash and not BB:IsTrash(id) then ok = false end
    local rk, rs
    if ok then rk, rs = BB:ResolveCategory(id, e) end
    if ok and typeSpec and not BB:MatchTypeFilter(typeSpec, { k = rk, s = rs }) then ok = false end
    if ok then table.insert(list, { id = id, e = e, k = rk, s = rs, res = res[id] or 0, avail = avail }) end
  end
  table.sort(list, function(a, b)
    if (a.e.q or 1) ~= (b.e.q or 1) then return (a.e.q or 1) > (b.e.q or 1) end
    return (a.e.n or "") < (b.e.n or "")
  end)
  return list, stock, res
end

function UI:RefreshStock()
  if not self.stock then return end
  local S = self.stock
  if self.RefreshBankButton then self:RefreshBankButton() end
  if self.RefreshTypeButton then self:RefreshTypeButton() end
  for i = 1, getn(S.chips) do S.chips[i]:SetActive(S.chips[i].q == S.filter) end
  if S.availChip then S.availChip:SetActive(S.onlyAvail) end
  if S.trashChk then S.trashChk:SetActive(S.onlyTrash) end
  local list, stock, res = self:StockList()
  self:RefreshStockView(list)
  if getn(list) == 0 then
    if S.depotStock and not BB:DepotHas(string.sub(S.type, 7)) then
      S.empty:SetText(T("RB_DEPOT_NONE"))
    elseif S.depotStock and BB.Count(S.depotStock) == 0 then
      S.empty:SetText(T("RB_DEPOT_EMPTY"))
    elseif S.bank and not BananaBankDB.snaps[S.bank] then
      S.empty:SetText(string.format(T("STOCK_BANK_NOSCAN"), S.bank))
    elseif S.bank and BB.Count(stock) == 0 then
      S.empty:SetText(string.format(T("STOCK_BANK_EMPTY"), S.bank))
    elseif BB:NewestSnapshot() then
      S.empty:SetText(T("STOCK_NO_MATCH"))
    elseif BB:IsBank() then
      S.empty:SetText(T("STOCK_EMPTY_BANK"))
    else
      S.empty:SetText(T("STOCK_EMPTY"))
    end
    S.empty:Show()
  else
    S.empty:Hide()
  end
  local total, reserved = 0, 0
  for id, e in pairs(stock) do total = total + 1 end
  for id, n in pairs(res) do reserved = reserved + n end
  if S.bank then
    local snap = BananaBankDB.snaps[S.bank]
    S.info:SetText(string.format(T("STOCK_INFO_BANK"), S.bank, total, snap and BB.Date(snap.ts) or "-"))
  else
    S.info:SetText(string.format(T("STOCK_INFO"), total, reserved))
  end
  self:RefreshCart()
end

function UI:CartAdd(id, delta, absolute)
  if not id then return end
  local basket = BananaBankDB.basket
  -- Regelsatz: wer nicht anfragen darf oder diese Qualitaet nicht, legt nichts in den Korb
  if delta > 0 and ((self.stock.type and string.sub(self.stock.type, 1, 6) == "depot:") or (self.stock.bank and BB:DepotOf(self.stock.bank))) then
    BB:Print("|cffff4040" .. T("RB_DEPOT") .. "|r")
    return
  end
  if delta > 0 then
    local why = BB:ItemBlockText(BB:Me(), id)
    if why then
      BB:Print("|cffff4040" .. why .. "|r")
      return
    end
  end
  local avail = BB:GetAvailable(id)
  local n = (basket[id] or 0) + delta
  if absolute then n = delta end
  -- ein Rezept nur einmal (ausser fuer Bank-Raenge)
  if n > 1 and not BB:MayBeBank(BB:Me()) then
    local e = BB.stockCache and BB.stockCache[id]
    if e and (BB:ResolveCategory(id, e)) == "recipe" then
      n = 1
      if delta > 0 then BB:Print("|cffff4040" .. T("RB_RECIPE_ONE") .. "|r") end
    end
  end
  if n > avail then
    n = avail
    if delta > 0 and not absolute then BB:Print(T("MSG_NOT_MORE")) end
  end
  if n <= 0 then basket[id] = nil else basket[id] = n end
  self:RefreshStock()
end

function UI:OnSlotClick(slot, button)
  local id = slot.id
  if not id then return end
  if IsControlKeyDown() and self.qe and self.qe:IsVisible() then
    self:QuestAddItem(id)
    return
  end
  if button == "MiddleButton" then
    -- Mausrad druecken: Trash umschalten (nur Bank-Chars)
    if BB:IsBank() and self.TrashMiddle then self:TrashMiddle(id) end
  elseif button == "RightButton" then
    self:CartAdd(id, -1)
  elseif IsAltKeyDown() and BB:IsBank() then
    BananaBankDB.hidden[id] = true
    BB:Print(string.format(T("MSG_HIDDEN"), BB:ColoredName(id)))
    self:RefreshStock()
  elseif IsShiftKeyDown() then
    self:CartAdd(id, BB:GetAvailable(id), true)
  else
    self:CartAdd(id, 1)
  end
end

function UI:OnSlotEnter(slot)
  local id = slot.id
  if not id then return end
  local depot = self.stock and self.stock.depotStock and self.stock.depotStock[id]
  if depot then
    local lines = { { T("TT_STOCK"), depot.c, 1, 1, 1 } }
    for name, c in pairs(depot.per) do table.insert(lines, { string.format(T("TT_DEPOT"), name), c, 0.6, 0.75, 1 }) end
    table.insert(lines, { T("RB_DEPOT"), "", 1, 0.5, 0.25 })
    self:ItemTooltip(slot, id, lines)
    return
  end
  local avail, stock, res = BB:GetAvailable(id)
  local G, O, W = C.green, C.orange, C.text
  local lines = {
    { T("TT_STOCK"), stock, W[1], W[2], W[3] },
    { T("TT_RESERVED"), res, O[1], O[2], O[3] },
    { T("TT_AVAILABLE"), avail, G[1], G[2], G[3] },
  }
  local e = BB.stockCache and BB.stockCache[id]
  if e and BB.Count(e.per) > 1 then
    for bank, c in pairs(e.per) do table.insert(lines, { "  " .. bank, c }) end
  end
  local hint = BB:IsBank() and BB:BankHintLines(e)
  if hint then
    for i = 1, getn(hint) do table.insert(lines, hint[i]) end
  end
  local u, src, pts, samples = BB:GetPrice(id)
  if u then
    local label = T("TT_PRICE")
    if src == "man" then label = label .. " " .. T("TT_PRICE_MAN") end
    table.insert(lines, { label, BB.Money(u), C.gold[1], C.gold[2], C.gold[3] })
  elseif BB:AHAbsent(id) then
    table.insert(lines, { T("TT_PRICE"), T("TT_PRICE_ABSENT"), 1, 0.5, 0.25 })
  else
    table.insert(lines, { T("TT_PRICE"), T("TT_PRICE_NONE"), 0.8, 0.8, 0.8 })
  end
  local block = BB:ItemBlockText(BB:Me(), id)
  if block then table.insert(lines, { block, "", 1, 0.5, 0.25 }) end
  if e and e.cr and e.cr ~= "" and BB.ClassLabels then
    table.insert(lines, { string.format(T("TT_CLASS"), BB:ClassLabels(e.cr)), "", 0.8, 0.8, 0.5 })
  end
  if BB:IsBank() then
    local ov, o = BB:TrashOverride(id)
    if BB:IsTrash(id) then
      local v = BB:VendorValue(id) or 0
      table.insert(lines, { T("TRASH_TT"), v > 0 and BB.Money(v) or "", 1, 0.42, 0.33 })
    end
    if ov then
      table.insert(lines, { string.format(T("TRASH_MANUAL"), ov == "t" and T("TRASH_STATE_T") or T("TRASH_STATE_N"), o.by or "?"), "", 0.7, 0.85, 1 })
    end
    if BB:IsTrash(id) or ov then table.insert(lines, { T("TRASH_MID_HINT"), "", 0.6, 0.6, 0.6 }) end
  end
  table.insert(lines, { T("TT_HINT"), "", 0.5, 0.5, 0.5 })
  self:ItemTooltip(slot, id, lines)
end

function UI:RefreshCart()
  local S = self.stock
  local basket = BananaBankDB.basket
  local ids = {}
  for id in pairs(basket) do table.insert(ids, id) end
  table.sort(ids, function(a, b) return (BB:ItemInfo(a)) < (BB:ItemInfo(b)) end)
  local items = 0
  for i = 1, getn(S.cartRows) do
    local row = S.cartRows[i]
    local id = ids[i]
    if id then
      local n, q, t = BB:ItemInfo(id)
      row.id = id
      row.ic.id = id
      row.ic.icon:SetTexture(BB.FullTex(t))
      row.ic:SetQuality(q)
      local c = BB.QUALITY_COLOR[q or 1] or BB.QUALITY_COLOR[1]
      row.name:SetText(n)
      row.name:SetTextColor(c[1], c[2], c[3])
      row.cnt:SetText(basket[id] .. "x")
      -- Gildencrafter-Haken
      local ok, why = false, nil
      if BB.CraftEligible then ok, why = BB:CraftEligible(id) end
      if ok or (why and why ~= "NOTRECIPE" and why ~= "NOKEYWORD") then
        row.claim:Show()
        local on = ok and BB:ClaimOn(id)
        row.claim:SetOn(ok)
        if on then
          row.claim.fs:SetTextColor(0.5, 1, 0.5)
          row.claim:SetBackdropColor(0.10, 0.32, 0.12, 0.98)
        else
          row.claim.fs:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
          row.claim:SetBackdropColor(0.09, 0.13, 0.27, 0.95)
        end
      else
        row.claim:Hide()
      end
      row:Show()
    else
      row.id = nil
      row:Hide()
    end
  end
  for _, n in pairs(basket) do items = items + n end
  local positions = getn(ids)
  if positions == 0 then S.cartEmpty:Show() else S.cartEmpty:Hide() end
  local extra = ""
  if positions > getn(S.cartRows) then extra = string.format(T("CART_MORE"), positions - getn(S.cartRows)) end
  S.cartSum:SetText(string.format(T("CART_SUM"), positions, items) .. extra)
  -- Rezepte mit gueltigem Gildencrafter-Anspruch sind kostenlos (die Bank bestaetigt das noch)
  local paid = {}
  local claims = BB:ValidClaims(basket)
  local nclaims = 0
  for id, n in pairs(basket) do
    if claims[id] then
      nclaims = nclaims + 1
      if n > 1 then paid[id] = n - 1 end   -- nur ein Exemplar ist frei
    else
      paid[id] = n
    end
  end
  local sum, missing = BB:PriceTotal(paid)
  if nclaims > 0 then
    S.cartPrice:SetText(string.format(T("CR_CART_PRICE"), BB.Money(sum), nclaims))
  elseif sum > 0 then
    S.cartPrice:SetText(string.format(T("CART_PRICE"), BB.Money(sum)))
  elseif missing > 0 then
    S.cartPrice:SetText(T("CART_PRICE_OPEN"))
  else
    S.cartPrice:SetText("")
  end
  local lock = BB:BlockText(BB:Me(), nil)
  S.cartLock:SetText(lock or "")
  S.makeBtn:SetOn(positions > 0 and not lock)
  if BB.USE_CODE then
    S.lastCodeBtn:Show()
    S.lastCodeBtn:SetOn(self.lastReq ~= nil)
  else
    S.lastCodeBtn:Hide()
  end
end

function UI:MakeCode()
  if not BB:Ready() then return end
  local basket = BananaBankDB.basket
  -- Verfuegbarkeit erneut pruefen (Reservierungen anderer koennen inzwischen da sein)
  local items = {}
  local stock = BB:GetStock()
  local res = BB:GetReserved()
  for id, n in pairs(basket) do
    local a = BB:GetAvailable(id, stock, res)
    if n > a then n = a end
    if n > 0 then items[id] = n end
  end
  if BB.Count(items) == 0 then
    BB:Print(T("MSG_CART_UNAVAILABLE"))
    return
  end
  local r = BB:CreateRequest(items, BB:ValidClaims(items))
  if not r then return end
  BananaBankDB.basket = {}
  BananaBankDB.claims = {}
  self.lastReq = r
  if BB.USE_CODE then
    self:ShowExport(r)
  else
    BB:Print(string.format(T("MSG_REQUEST_SENT"), r.id))
  end
  self:Refresh()
end

-- ------------------------------------------------------------
-- Export-Fenster (Discord)
-- ------------------------------------------------------------
function UI:DiscordText(r)
  local parts = {}
  local ids = {}
  for id in pairs(r.items) do table.insert(ids, id) end
  table.sort(ids)
  for i = 1, getn(ids) do
    table.insert(parts, r.items[ids[i]] .. "x " .. (BB:ItemInfo(ids[i])))
  end
  local msg = string.format(T("DISCORD_MSG"), r.p, table.concat(parts, ", "), r.code)
  local sum = BB:PriceTotal(r.items)
  if sum > 0 then msg = msg .. " " .. string.format(T("DISCORD_COD"), BB.Money(sum)) end
  return msg
end

local function readonlyBox(box)
  box:SetScript("OnTextChanged", function()
    if this.fixed and this:GetText() ~= this.fixed then
      this:SetText(this.fixed)
      this:HighlightText()
    end
  end)
  box:SetScript("OnEditFocusGained", function() this:HighlightText() end)
  box:SetScript("OnEnterPressed", function() this:ClearFocus() end)
end

function UI:BuildExport()
  local e = CreateFrame("Frame", "BananaBankExport", UIParent)
  self.export = e
  e:SetWidth(580)
  e:SetHeight(210)
  e:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  e:SetFrameStrata("DIALOG")
  e:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  e:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.98)
  e:EnableMouse(true)
  e:SetMovable(true)
  e:RegisterForDrag("LeftButton")
  e:SetScript("OnDragStart", function() this:StartMoving() end)
  e:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  e:Hide()
  tinsert(UISpecialFrames, "BananaBankExport")
  local logo = e:CreateTexture(nil, "OVERLAY")
  logo:SetTexture(MEDIA .. "Logo64")
  logo:SetWidth(64)
  logo:SetHeight(64)
  logo:SetPoint("TOPLEFT", e, "TOPLEFT", 14, -14)
  local t = self:Font(e, 20, C.gold, FONT_TITLE)
  t:SetPoint("TOPLEFT", e, "TOPLEFT", 92, -20)
  self:Loc(t, "EXPORT_TITLE")
  e.sub = self:Font(e, 11, C.muted)
  e.sub:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
  e.sub:SetWidth(460)
  local l1 = self:Font(e, 11, C.text)
  l1:SetPoint("TOPLEFT", e, "TOPLEFT", 24, -88)
  self:Loc(l1, "EXPORT_MSG_LABEL")
  e.msg = self:EditBox("BananaBankExportMsg", e, 526)
  e.msg:SetMaxLetters(0)
  e.msg:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 4, -4)
  readonlyBox(e.msg)
  local l2 = self:Font(e, 11, C.text)
  l2:SetPoint("TOPLEFT", e.msg, "BOTTOMLEFT", -4, -10)
  self:Loc(l2, "EXPORT_CODE_LABEL")
  e.code = self:EditBox("BananaBankExportCode", e, 340)
  e.code:SetMaxLetters(0)
  e.code:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 4, -4)
  readonlyBox(e.code)
  local ok = self:Button(e, 120, 24, "BTN_DONE", function() e:Hide() end, "primary")
  ok:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -20, 18)
end

function UI:ShowExport(r)
  local e = self.export
  e.sub:SetText(string.format(T("EXPORT_SUB"), r.id))
  e.msg.fixed = nil
  e.code.fixed = nil
  local msg = self:DiscordText(r)
  e.msg:SetText(msg)
  e.code:SetText(r.code)
  e.msg.fixed = msg
  e.code.fixed = r.code
  e:Show()
  e.msg:SetFocus()
  e.msg:HighlightText()
end

-- ------------------------------------------------------------
-- Danke-/Spendenfenster (wie in den anderen BananaForge-Addons)
-- ------------------------------------------------------------
function UI:BuildThanks()
  local tf = CreateFrame("Frame", "BananaBankThanks", UIParent)
  self.thanks = tf
  tf:SetWidth(380)
  tf:SetHeight(250)
  tf:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  tf:SetFrameStrata("DIALOG")
  tf:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  tf:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.98)
  tf:EnableMouse(true)
  tf:Hide()
  tinsert(UISpecialFrames, "BananaBankThanks")
  local logo = tf:CreateTexture(nil, "OVERLAY")
  logo:SetTexture(MEDIA .. "Logo64")
  logo:SetWidth(64)
  logo:SetHeight(64)
  logo:SetPoint("TOP", tf, "TOP", 0, 24)
  local title = self:Font(tf, 17, C.gold, FONT_TITLE)
  title:SetPoint("TOP", tf, "TOP", 0, -52)
  title:SetJustifyH("CENTER")
  self:Loc(title, "THANKS_TITLE")
  tf.titleFS = title
  local txt = self:Font(tf, 11, C.text)
  txt:SetPoint("TOP", title, "BOTTOM", 0, -10)
  txt:SetWidth(320)
  txt:SetJustifyH("CENTER")
  self:Loc(txt, "THANKS_TEXT")
  local nb = self:EditBox("BananaBankThanksName", tf, 140)
  nb:SetPoint("TOP", txt, "BOTTOM", 0, -12)
  nb:SetText(BB.DONATE_NAME)
  nb.fixed = BB.DONATE_NAME
  readonlyBox(nb)
  tf.nameBox = nb
  local mail = self:Button(tf, 130, 24, "BTN_MAILBOX", function()
    if MailFrame and MailFrame:IsVisible() and SendMailNameEditBox then
      if MailFrameTab_OnClick then MailFrameTab_OnClick(2) end
      SendMailNameEditBox:SetText(BB.DONATE_NAME)
      SendMailSubjectEditBox:SetText("BananaForge")
      tf:Hide()
    else
      BB:Print(T("MSG_OPEN_MAILBOX"))
    end
  end, "primary")
  mail:SetPoint("BOTTOMRIGHT", tf, "BOTTOM", -4, 18)
  tf.mailBtn = mail
  local ok = self:Button(tf, 130, 24, "BTN_CLOSE", function() tf:Hide() end)
  ok:SetPoint("BOTTOMLEFT", tf, "BOTTOM", 4, 18)
  tf.okBtn = ok
end

function UI:ShowThanks()
  self:Init()
  self.thanks:Show()
end

-- ------------------------------------------------------------
-- Minimap-Knopf
-- ------------------------------------------------------------
function UI:BuildMinimap()
  if self.minimap then return end
  local b = CreateFrame("Button", "BananaBankMinimapButton", Minimap)
  self.minimap = b
  b:SetWidth(31)
  b:SetHeight(31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture(MEDIA .. "Minimap")
  icon:SetWidth(21)
  icon:SetHeight(21)
  icon:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -5)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(53)
  border:SetHeight(53)
  border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:SetScript("OnClick", function()
    if arg1 == "RightButton" then UI:ShowThanks() else UI:Toggle() end
  end)
  b:SetScript("OnDragStart", function()
    this:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      cx, cy = cx / s, cy / s
      local a = math.deg(math.atan2(cy - my, cx - mx))
      BananaBankDB.minimap.angle = a
      UI:PlaceMinimap()
    end)
  end)
  b:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("BananaBank", C.gold[1], C.gold[2], C.gold[3])
    local snap = BB:NewestSnapshot()
    if snap then GameTooltip:AddLine(string.format(T("TT_MINIMAP_STAND"), BB.Date(snap.ts)), 0.8, 0.8, 0.8) end
    GameTooltip:AddLine(T("TT_MINIMAP_HINT"), 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self:PlaceMinimap()
  if BananaBankDB.minimap.hide then b:Hide() end
end

function UI:PlaceMinimap()
  local a = math.rad(BananaBankDB.minimap.angle or 200)
  local x = math.cos(a) * 80
  local y = math.sin(a) * 80
  self.minimap:ClearAllPoints()
  self.minimap:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
