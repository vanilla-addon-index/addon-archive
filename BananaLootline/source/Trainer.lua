--[[----------------------------------------------------------------------
  BananaLootline - Trainer.lua

  Erinnerung an neue Zauber beim Klassenlehrer und neue Rezepte beim
  Berufslehrer, dazu das Seitenmenue "Extras" rechts am Hauptfenster.

  Woher die Daten kommen: vom Lehrer selbst. Oeffnet man sein Fenster,
  liefert der Client die komplette Liste - auch was man noch nicht
  lernen kann, mit Stufe, Fertigkeit und Preis. Das wird pro Charakter
  gemerkt. Steigt danach die Stufe oder die Berufsfertigkeit, prueft
  das Addon die Liste und meldet, was jetzt lernbar ist. Die Angaben
  stammen damit direkt von diesem Server, auch fuer eigene Zauber.

  Einmal muss man beim Lehrer gewesen sein. Bis dahin gilt beim
  Klassenlehrer die Faustregel: auf geraden Stufen gibt es in Vanilla
  fast immer etwas Neues.
------------------------------------------------------------------------]]

local BLL = BananaLootline
BLL.Trainer = {}
local T = BLL.Trainer

local function Store()
  BananaLootlineChar = BananaLootlineChar or {}
  BananaLootlineChar.trainer = BananaLootlineChar.trainer or { prof = {} }
  BananaLootlineChar.trainer.prof = BananaLootlineChar.trainer.prof or {}
  return BananaLootlineChar.trainer
end

-- Kupfer als "1g 20s 5c"
function BLL:FormatMoney(c)
  c = math.floor(c or 0)
  local g, si, cu = math.floor(c / 10000), math.mod(math.floor(c / 100), 100), math.mod(c, 100)
  local out = {}
  if g > 0 then table.insert(out, g .. "g") end
  if si > 0 then table.insert(out, si .. "s") end
  if cu > 0 or table.getn(out) == 0 then table.insert(out, cu .. "c") end
  return table.concat(out, " ")
end

local function PlayerLevel()
  return (BLL.player and BLL.player.level) or (UnitLevel and UnitLevel("player")) or 1
end

-- Fertigkeitsstufe eines Berufs aus dem Fertigkeitenfenster
function T:SkillRank(name)
  if not name or not GetNumSkillLines then return nil end
  for i = 1, GetNumSkillLines() do
    local n, isHeader, _, rank = GetSkillLineInfo(i)
    if n == name and not isHeader then return rank end
  end
  return nil
end

------------------------------------------------------------------
-- Beschreibung eines Eintrags im Lehrerfenster
--
-- Erst GetTrainerServiceDescription (dasselbe, was das Lehrerfenster
-- unten anzeigt). Liefert das nichts - bei Rezepten oft -, wird der
-- Tooltip des Eintrags gelesen, ohne Titelzeile.
------------------------------------------------------------------

local scanTip
local function ScanTip()
  if scanTip or not CreateFrame then return scanTip end
  scanTip = CreateFrame("GameTooltip", "BananaLootlineTrainerScan", UIParent, "GameTooltipTemplate")
  return scanTip
end

function T:Describe(i)
  if GetTrainerServiceDescription then
    local ok, d = pcall(GetTrainerServiceDescription, i)
    if ok and d and d ~= "" then return d end
  end
  local tip = ScanTip()
  if not (tip and tip.SetTrainerService and tip.NumLines) then return nil end
  tip:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  if not pcall(tip.SetTrainerService, tip, i) then return nil end
  local lines = {}
  for k = 2, tip:NumLines() do
    local fs = getglobal("BananaLootlineTrainerScanTextLeft" .. k)
    local t = fs and fs:GetText()
    if t and t ~= "" then table.insert(lines, t) end
  end
  tip:Hide()
  if table.getn(lines) == 0 then return nil end
  return table.concat(lines, "\n")
end

------------------------------------------------------------------
-- Welcher Lehrer ist das?
--
-- Tierausbilder und Waffenmeister oeffnen dasselbe Lehrerfenster wie der
-- Klassenlehrer, und IsTradeskillTrainer() ist bei ihnen falsch. Bis
-- 0.24.3 landete deshalb die Liste des Tierausbilders (Knurren, Grosse
-- Ausdauer, Widerstaende) als "Klassenlehrer" im Extras-Menue eines
-- Jaegers. Unterscheiden laesst sich das am Titel des NPCs, etwa
-- "<Hunter Trainer>" gegen "<Pet Trainer>".
------------------------------------------------------------------

-- Titel des offenen Lehrers ohne spitze Klammern, oder nil.
function T:TrainerTitle()
  local tip = ScanTip()
  if not (tip and tip.SetUnit and tip.NumLines) then return nil end
  if UnitExists and not UnitExists("npc") then return nil end
  tip:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  if not pcall(tip.SetUnit, tip, "npc") then return nil end
  local title
  local n = tip:NumLines() or 0
  if n > 3 then n = 3 end
  for k = 2, n do
    local fs = getglobal("BananaLootlineTrainerScanTextLeft" .. k)
    local t = fs and fs:GetText()
    local _, _, inner = string.find(t or "", "^<(.+)>$")
    if inner then title = inner break end
  end
  tip:Hide()
  return title
end

-- Wortstaemme der Klassen im Lehrertitel, englisch und deutsch. Auch
-- weibliche Formen ("Jaegerlehrerin") enthalten den Stamm.
T.CLASS_STEMS = {
  WARRIOR = { "warrior", "krieger" },   PALADIN = { "paladin" },
  HUNTER  = { "hunter", "j\195\164ger" }, ROGUE = { "rogue", "schurke" },
  PRIEST  = { "priest", "priester" },   SHAMAN  = { "shaman", "schamane" },
  MAGE    = { "mage", "magier" },       WARLOCK = { "warlock", "hexenmeister" },
  DRUID   = { "druid", "druide" },
}

-- Ist der Titel der eines Lehrers der eigenen Klasse? Ohne lesbaren
-- Titel wie bisher ja.
function T:IsOwnClassTrainer(title)
  if not title then return true end
  local class = BLL.player and BLL.player.class
  local stems = class and self.CLASS_STEMS[class]
  if not stems then return true end
  local low = string.lower(title)
  for _, stem in ipairs(stems) do
    if string.find(low, stem, 1, true) then return true end
  end
  return false
end

-- Aufraeumen, was frueher faelschlich gespeichert wurde: eine Liste des
-- Tierausbilders als Klassenlehrer und ein Beruf namens "?".
T.PET_SPELLS = {
  ["Growl"] = true, ["Great Stamina"] = true, ["Natural Armor"] = true,
  ["Knurren"] = true, ["Gro\195\159e Ausdauer"] = true, ["Nat\195\188rliche R\195\188stung"] = true,
}

function T:Sanitize()
  local store = Store()
  local c = store.class
  if c and c.list then
    for _, e in ipairs(c.list) do
      if e.n and self.PET_SPELLS[e.n] then
        store.class = nil
        store.seenClass = nil
        break
      end
    end
  end
  if store.prof["?"] then store.prof["?"] = nil end
end

------------------------------------------------------------------
-- Lehrerfenster lesen
------------------------------------------------------------------

-- Liest alle Eintraege des offenen Lehrerfensters. Damit auch die noch
-- nicht lernbaren erscheinen, wird der Filter "nicht verfuegbar" kurz
-- eingeschaltet und danach wiederhergestellt.
function T:Scan()
  if not GetNumTrainerServices then return end
  local oldFilter = GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter("unavailable")
  if SetTrainerServiceTypeFilter and not oldFilter then
    SetTrainerServiceTypeFilter("unavailable", 1)
  end
  if ExpandTrainerSkillLine then pcall(ExpandTrainerSkillLine, 0) end

  local isProf = IsTradeskillTrainer and IsTradeskillTrainer()
  local title = self:TrainerTitle()
  -- Tierausbilder, Waffenmeister und Lehrer anderer Klassen: nichts
  -- merken.
  if not isProf and not self:IsOwnClassTrainer(title) then
    if SetTrainerServiceTypeFilter and not oldFilter then
      SetTrainerServiceTypeFilter("unavailable", 0)
    end
    return
  end
  local entries, skillLine = {}, nil
  for i = 1, GetNumTrainerServices() do
    local name, sub, category = GetTrainerServiceInfo(i)
    if name and category ~= "header" then
      local e = { n = name, r = (sub and sub ~= "") and sub or nil, used = (category == "used") or nil }
      if GetTrainerServiceLevelReq then
        local lvl = GetTrainerServiceLevelReq(i)
        if lvl and lvl > 0 then e.l = lvl end
      end
      if GetTrainerServiceCost then e.c = GetTrainerServiceCost(i) end
      e.d = T:Describe(i)
      if isProf and GetTrainerServiceSkillReq then
        local sname, srank = GetTrainerServiceSkillReq(i)
        if sname and sname ~= "" then skillLine = skillLine or sname end
        if srank and srank > 0 then e.s = srank end
      end
      table.insert(entries, e)
    end
  end

  if SetTrainerServiceTypeFilter and not oldFilter then
    SetTrainerServiceTypeFilter("unavailable", 0)
  end

  local store = Store()
  local where = GetZoneText and GetZoneText() or nil
  if isProf then
    skillLine = skillLine or (GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(1)) or title
    if not skillLine then
      -- Ohne Namen laesst sich der Beruf nicht zuordnen; frueher stand
      -- er dann als "?" im Menue.
      self:Remember()
      if BLL.Extras then BLL.Extras:Refresh() end
      return
    end
    store.prof[skillLine] = { list = entries, level = PlayerLevel(), zone = where, t = time and time() }
  else
    store.class = { list = entries, level = PlayerLevel(), zone = where, t = time and time() }
  end
  self:Remember()
  if BLL.Extras then BLL.Extras:Refresh() end
end

------------------------------------------------------------------
-- Auswertung
------------------------------------------------------------------

-- Klassenlehrer: lernbar jetzt, und die naechsten Stufen
function T:ClassStatus()
  local c = Store().class
  if not c then return nil end
  local lvl = PlayerLevel()
  local now, later, cost = {}, {}, 0
  for _, e in ipairs(c.list) do
    if not e.used then
      if not e.l or e.l <= lvl then
        table.insert(now, e); cost = cost + (e.c or 0)
      else
        later[e.l] = later[e.l] or {}
        table.insert(later[e.l], e)
      end
    end
  end
  return { now = now, later = later, cost = cost, visit = c }
end

-- Berufslehrer: je Beruf lernbar jetzt und die naechsten Rezepte
function T:ProfStatus()
  local out = {}
  for line, p in pairs(Store().prof) do
    local rank = self:SkillRank(line) or 0
    local lvl = PlayerLevel()
    local now, next, cost = {}, {}, 0
    for _, e in ipairs(p.list) do
      if not e.used then
        if (not e.s or e.s <= rank) and (not e.l or e.l <= lvl) then
          table.insert(now, e); cost = cost + (e.c or 0)
        else
          table.insert(next, e)
        end
      end
    end
    table.sort(next, function(a, b) return (a.s or 0) < (b.s or 0) end)
    table.insert(out, { line = line, rank = rank, now = now, next = next, cost = cost, visit = p })
  end
  table.sort(out, function(a, b) return a.line < b.line end)
  return out
end

-- Wie viel ist insgesamt jetzt lernbar? Fuer die Lasche am Fenster.
function T:LearnableCount()
  local n = 0
  local c = self:ClassStatus()
  if c then n = n + table.getn(c.now) end
  for _, p in ipairs(self:ProfStatus()) do n = n + table.getn(p.now) end
  return n
end

------------------------------------------------------------------
-- Meldungen
------------------------------------------------------------------

-- Merkt sich den gemeldeten Stand, damit nur Neues gemeldet wird.
function T:Remember()
  local store = Store()
  local c = self:ClassStatus()
  store.seenClass = c and table.getn(c.now) or 0
  store.seenProf = {}
  for _, p in ipairs(self:ProfStatus()) do store.seenProf[p.line] = table.getn(p.now) end
end

local function Announce(text)
  BLL:Print("|cff00ff00" .. text .. "|r")
  if UIErrorsFrame and UIErrorsFrame.AddMessage then
    UIErrorsFrame:AddMessage(text, 1, 0.82, 0, 1, 5)
  end
end

function T:CheckLevel(newLevel)
  local L = BLL.L
  local store = Store()
  local c = self:ClassStatus()
  if c then
    local n = table.getn(c.now)
    if n > (store.seenClass or 0) then
      Announce(string.format(L["TR_CLASS_NEW"], n, BLL:FormatMoney(c.cost)))
    end
  elseif newLevel and math.mod(newLevel, 2) == 0 then
    -- Noch nie beim Lehrer gewesen: Faustregel
    Announce(L["TR_CLASS_GUESS"])
  end
  self:CheckProfessions(true)
  self:Remember()
  if BLL.Extras then BLL.Extras:Refresh() end
end

function T:CheckProfessions(silentRemember)
  local L = BLL.L
  local store = Store()
  store.seenProf = store.seenProf or {}
  for _, p in ipairs(self:ProfStatus()) do
    local n = table.getn(p.now)
    if n > (store.seenProf[p.line] or 0) then
      Announce(string.format(L["TR_PROF_NEW"], p.line, n))
    end
  end
  if not silentRemember then
    self:Remember()
    if BLL.Extras then BLL.Extras:Refresh() end
  end
end

------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("TRAINER_SHOW")
ev:RegisterEvent("TRAINER_UPDATE")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("CHAT_MSG_SKILL")
local scanning, lastScan = false, -100
ev:SetScript("OnEvent", function()
  if event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
    -- Der Scan schaltet den Filter um und loest damit selbst
    -- TRAINER_UPDATE aus, oft erst im naechsten Bild. Das darf keinen
    -- weiteren Scan anstossen, sonst schaukelt es sich auf. Nach dem
    -- Lernen eines Zaubers kommt TRAINER_UPDATE spaeter und zaehlt.
    local now = GetTime and GetTime() or 0
    if scanning or (event == "TRAINER_UPDATE" and now - lastScan < 1) then return end
    scanning = true
    pcall(T.Scan, T)
    lastScan = GetTime and GetTime() or 0
    scanning = false
  elseif event == "PLAYER_LEVEL_UP" then
    if BLL.player then BLL.player.level = arg1 or BLL.player.level end
    T:CheckLevel(arg1)
  elseif event == "CHAT_MSG_SKILL" then
    T:CheckProfessions()
  end
end)

------------------------------------------------------------------
-- Seitenmenue "Extras"
--
-- Eine Lasche mit Pfeil am rechten Rand des Hauptfensters klappt ein
-- schmales Menue daneben auf. Platz fuer weitere Zusaetze spaeter.
------------------------------------------------------------------

BLL.Extras = {}
local X = BLL.Extras

local WIDTH = 270
local ROWS, ROW_H = 44, 14
X.MAX_LEVELS = 5

function X:Init()
  local main = BananaLootlineFrame
  if self.panel or not main then return end
  pcall(T.Sanitize, T)
  local L = BLL.L

  -- Die Lasche sitzt genau im Zwischenrand zwischen rechter Liste und
  -- Fensterkante, senkrecht mittig zur Liste. Der Pfeil steht mittig
  -- in der Lasche, die Zahl lernbarer Eintraege darueber.
  local pane = BLL.UI and BLL.UI.detail
  local tab = CreateFrame("Button", "BananaLootlineExtrasTab", main)
  tab:SetWidth(12); tab:SetHeight(56)
  if pane then
    tab:SetPoint("LEFT", pane, "RIGHT", 1, 0)
  else
    tab:SetPoint("RIGHT", main, "RIGHT", -3, 0)
  end
  tab:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  tab:SetBackdropColor(0.45, 0.05, 0.05, 1)
  tab:SetBackdropBorderColor(0.78, 0.63, 0.24, 1)
  tab:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
  local arrow = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  arrow:SetPoint("CENTER", tab, "CENTER", 1, 0)
  tab.arrow = arrow
  local count = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  count:SetPoint("BOTTOM", tab, "TOP", 0, 2)
  tab.count = count
  tab:SetScript("OnClick", function() X:Toggle() end)
  tab:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(BLL.L["EX_TITLE"])
    GameTooltip:AddLine(BLL.L["EX_TIP"], 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.tab = tab

  local p = CreateFrame("Frame", "BananaLootlineExtras", main)
  p:SetWidth(WIDTH); p:SetHeight(main:GetHeight() - 40)
  p:SetPoint("TOPLEFT", main, "TOPRIGHT", 2, -20)
  p:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
  })
  p:SetBackdropColor(0, 0, 0, 1)
  p:Hide()

  local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -14)
  title:SetTextColor(1, 0.82, 0)
  p.title = title

  -- Zeilen statt eines Textblocks: Kopfzeilen muessen anklickbar sein.
  -- Passt nicht alles hinein, scrollt das Mausrad.
  p.rows = {}
  for i = 1, ROWS do
    local r = CreateFrame("Button", nil, p)
    r:SetWidth(WIDTH - 24); r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -40 - (i - 1) * ROW_H)
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetAllPoints(r)
    bg:SetVertexColor(0.25, 0.20, 0.06, 0.6)
    r.bg = bg
    local sign = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sign:SetPoint("LEFT", r, "LEFT", 2, 0)
    sign:SetWidth(12)
    r.sign = sign
    local t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", r, "LEFT", 16, 0)
    t:SetPoint("RIGHT", r, "RIGHT", -70, 0)
    t:SetJustifyH("LEFT")
    r.text = t
    local rt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rt:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    rt:SetJustifyH("RIGHT")
    r.right = rt
    r:SetScript("OnClick", function()
      if this.key then X:ToggleKey(this.key) end
    end)
    r:SetScript("OnEnter", function()
      if this.spell then X:ShowTip(this, this.spell) end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:Hide()
    p.rows[i] = r
  end
  p:EnableMouseWheel(true)
  p:SetScript("OnMouseWheel", function()
    X.offset = math.max(0, (X.offset or 0) - (arg1 or 0) * 3)
    X:Refresh()
  end)

  self.panel = p
  if BananaLootlineDB and BananaLootlineDB.extrasOpen then p:Show() end
  self:Refresh()
end

function X:Toggle()
  if not self.panel then return end
  if self.panel:IsVisible() then self.panel:Hide() else self.panel:Show() end
  BananaLootlineDB.extrasOpen = self.panel:IsVisible() and true or nil
  self:Refresh()
end

------------------------------------------------------------------
-- Aufklappbare Abschnitte
--
-- Jede Stufe beim Klassenlehrer, "jetzt lernbar" und jeder Beruf ist
-- eine Kopfzeile mit [+]/[-]. Was offen ist, bleibt gespeichert.
-- Voreinstellung: offen ist, was jetzt lernbar ist; Stufen und Berufe
-- ohne Lernbares sind zu.
------------------------------------------------------------------

function X:IsOpen(key, default)
  local o = BananaLootlineDB and BananaLootlineDB.extrasKeys
  if o and o[key] ~= nil then return o[key] end
  return default
end

function X:ToggleKey(key)
  BananaLootlineDB.extrasKeys = BananaLootlineDB.extrasKeys or {}
  local cur = self.lastOpen and self.lastOpen[key]
  BananaLootlineDB.extrasKeys[key] = not cur
  self:Refresh()
end

-- Liste der Zeilen: { kind = "title"|"head"|"line"|"gap", text, right,
-- key, open }
function X:Entries()
  local L = BLL.L
  local out = {}
  self.lastOpen = {}
  local function add(e) table.insert(out, e) end
  local function head(key, text, right, default)
    local open = self:IsOpen(key, default)
    self.lastOpen[key] = open
    add({ kind = "head", key = key, text = text, right = right, open = open })
    return open
  end
  local function spell(e, dim)
    add({ kind = "line", spell = e, text = (dim and "|cffaaaaaa" or "|cffffffff") .. e.n .. "|r"
      .. (e.r and (" |cff777777" .. e.r .. "|r") or "") })
  end

  add({ kind = "title", text = "|cffffd100" .. L["TR_CLASS"] .. "|r" })
  local c = T:ClassStatus()
  if not c then
    add({ kind = "line", text = "|cff888888" .. L["TR_NOVISIT"] .. "|r" })
  else
    local n = table.getn(c.now)
    if n > 0 then
      if head("c:now", "|cff44ff44" .. string.format(L["TR_NOW"], n, BLL:FormatMoney(c.cost)) .. "|r", nil, true) then
        for _, e in ipairs(c.now) do spell(e) end
      end
    else
      add({ kind = "line", text = "|cff888888" .. L["TR_NOTHING"] .. "|r" })
    end
    local lv = {}
    for l in pairs(c.later) do table.insert(lv, l) end
    table.sort(lv)
    -- Nur die naechsten Lehrerstufen; alle bis 60 waren zu viel.
    for i = 1, math.min(X.MAX_LEVELS, table.getn(lv)) do
      local l = lv[i]
      if head("c:" .. l, "|cffffd100" .. string.format(L["TR_LEVEL"], l) .. "|r",
              "|cff888888" .. table.getn(c.later[l]) .. "|r", false) then
        for _, e in ipairs(c.later[l]) do spell(e, true) end
      end
    end
    add({ kind = "line", text = "|cff888888" .. string.format(L["TR_VISIT"], c.visit.level or 0, c.visit.zone or "?") .. "|r" })
  end

  add({ kind = "gap" })
  add({ kind = "title", text = "|cffffd100" .. L["TR_PROF"] .. "|r" })
  local profs = T:ProfStatus()
  if table.getn(profs) == 0 then
    add({ kind = "line", text = "|cff888888" .. L["TR_PROF_NOVISIT"] .. "|r" })
  end
  for _, p in ipairs(profs) do
    local n = table.getn(p.now)
    local right = (n > 0) and ("|cff44ff44" .. string.format(L["TR_LEARNABLE"], n) .. "|r") or nil
    if head("p:" .. p.line, "|cffffffff" .. p.line .. "|r |cff888888(" .. p.rank .. ")|r", right, false) then
      if n > 0 then
        add({ kind = "line", text = "|cff44ff44" .. string.format(L["TR_NOW"], n, BLL:FormatMoney(p.cost)) .. "|r" })
        for _, e in ipairs(p.now) do spell(e) end
      end
      for _, e in ipairs(p.next) do
        add({ kind = "line", spell = e, text = "|cffaaaaaa" .. e.n .. "|r |cff777777"
          .. (e.s and string.format(L["TR_SKILL"], e.s) or "")
          .. (e.l and (" " .. string.format(L["TR_LEVEL"], e.l)) or "") .. "|r" })
      end
    end
  end
  return out
end

-- Reiner Text, fuer Tests und Chatausgabe
function X:Text()
  local t = {}
  for _, e in ipairs(self:Entries()) do
    if e.kind ~= "gap" then
      table.insert(t, (e.kind == "head" and (e.open and "[-] " or "[+] ") or "") .. (e.text or "")
        .. (e.right and ("  " .. e.right) or ""))
    end
  end
  return table.concat(t, "\n")
end

-- Tooltip eines Zaubers oder Rezepts: Name, Rang, Bedingung, Preis,
-- Beschreibung. Die Beschreibung stammt vom letzten Lehrerbesuch.
function X:TipLines(e)
  local L = BLL.L
  local out = {}
  table.insert(out, { e.n .. (e.r and (" (" .. e.r .. ")") or ""), 1, 1, 1 })
  if e.l then table.insert(out, { string.format(L["TR_TIP_LEVEL"], e.l), 0.8, 0.8, 0.8 }) end
  if e.s then table.insert(out, { string.format(L["TR_TIP_SKILL"], e.s), 0.8, 0.8, 0.8 }) end
  if e.c and e.c > 0 then table.insert(out, { string.format(L["TR_TIP_COST"], BLL:FormatMoney(e.c)), 0.8, 0.8, 0.8 }) end
  if e.d then
    table.insert(out, { e.d, 1, 0.82, 0, true })
  else
    table.insert(out, { L["TR_TIP_NODESC"], 0.5, 0.5, 0.5, true })
  end
  return out
end

function X:ShowTip(owner, e)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local lines = self:TipLines(e)
  GameTooltip:SetText(lines[1][1], lines[1][2], lines[1][3], lines[1][4])
  for i = 2, table.getn(lines) do
    local l = lines[i]
    GameTooltip:AddLine(l[1], l[2], l[3], l[4], l[5] and 1 or nil)
  end
  GameTooltip:Show()
end

function X:Refresh()
  if not self.tab then return end
  local n = T:LearnableCount()
  local open = self.panel and self.panel:IsVisible()
  self.tab.arrow:SetText(open and "<" or ">")
  self.tab.count:SetText(n > 0 and ("|cff44ff44" .. n .. "|r") or "")
  if open then
    local p = self.panel
    p.title:SetText(BLL.L["EX_TITLE"])
    local list = self:Entries()
    local maxOff = math.max(0, table.getn(list) - ROWS)
    if (self.offset or 0) > maxOff then self.offset = maxOff end
    local off = self.offset or 0
    for i = 1, ROWS do
      local r, e = p.rows[i], list[i + off]
      if e then
        r.key = (e.kind == "head") and e.key or nil
        r.spell = e.spell
        r.text:SetText(e.text or "")
        r.right:SetText(e.right or "")
        if e.kind == "head" then
          r.sign:SetText(e.open and "|cffffd100-|r" or "|cffffd100+|r")
          r.bg:Show()
          r.text:SetPoint("LEFT", r, "LEFT", 16, 0)
        else
          r.sign:SetText("")
          r.bg:Hide()
          r.text:SetPoint("LEFT", r, "LEFT", (e.kind == "line") and 16 or 2, 0)
        end
        r:Show()
      else
        r.key = nil
        r.spell = nil
        r:Hide()
      end
    end
  end
end
