--[[----------------------------------------------------------------------
  BananaLootline - UI.lua

  Bewusst schlicht gehalten und rein in Lua gebaut (kein XML), damit das
  Geruest in einer Datei nachvollziehbar bleibt.

  Layout:
    links   - 17 Ausruestungsslots mit angelegtem Item
    rechts  - Detailbereich: Stats des gewaehlten Items + Quellen aus pfQuest
    unten   - summierte Charakterwerte
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline
BLL.UI = {}
local UI = BLL.UI

local QUALITY_COLOR = {
  [0] = { 0.62, 0.62, 0.62 },   -- grau
  [1] = { 1.00, 1.00, 1.00 },   -- weiss
  [2] = { 0.12, 1.00, 0.00 },   -- gruen
  [3] = { 0.00, 0.44, 0.87 },   -- blau
  [4] = { 0.64, 0.21, 0.93 },   -- lila
  [5] = { 1.00, 0.50, 0.00 },   -- orange
  [6] = { 0.90, 0.80, 0.50 },   -- Artefakt
  [7] = { 0.00, 0.80, 1.00 },   -- Erbstueck
}

-- Farbe einer Qualitaet, nie nil. Der Datenbestand fuehrt acht Teile
-- mit Qualitaet 6 - die Klingen von Azzinoth und fuenf Schmuckstuecke
-- ab Stufe 51. Die Tabelle kannte nur 0 bis 5; jeder Charakter, dem
-- eines davon als Waffe oder Schmuck vorgeschlagen wurde, bekam
-- "UI.lua: attempt to index local 'qc' (a nil value)" und eine leere
-- Liste - gemeldet von drei Testern, bei Waffenhand und Schildhand.
local function QC(q)
  return QUALITY_COLOR[q or 1] or QUALITY_COLOR[1]
end

local ROW_HEIGHT = 18

-- Schriftgroessen an einer Stelle. Die Standardschriften des Spiels sind
-- fuer ein Fenster dieser Groesse zu klein; hier zwei bis drei Punkte
-- mehr, Ueberschriften deutlich groesser.
local FONT = "Fonts\\FRIZQT__.TTF"

local function SetFontSize(fs, size, outline)
  if not fs or not fs.SetFont then return fs end
  fs:SetFont(FONT, size, outline)
  return fs
end

-- Letztes Zeichen entfernen, ohne ein UTF-8-Zeichen zu zerschneiden.
-- Deutsche Zonennamen enthalten Umlaute; ein halbes Zeichen zeigt der
-- Client als Kaestchen an.
local function TrimLastChar(str)
  local i = string.len(str)
  if i == 0 then return str end
  while i > 1 do
    local b = string.byte(str, i)
    if b < 128 or b >= 192 then break end
    i = i - 1
  end
  return string.sub(str, 1, i - 1)
end

-- Text auf eine Zeile zwingen. Zu lange Texte bricht der Client um und
-- die Zeile ragt in die naechste. Gekuerzt wird nur der Kern (Zonen-,
-- Item- oder Verzauberungsname); Etikett, Stufe und Chance bleiben
-- vollstaendig. Gemessen wird an einer unsichtbaren FontString ohne
-- Breitenvorgabe, denn eine begrenzte liefert die umbrochene Breite.
local function FitText(measure, fs, pre, core, post, width, size, outline)
  pre, core, post = pre or "", core or "", post or ""
  SetFontSize(measure, size, outline)
  measure:SetText(pre .. core .. post)
  if measure:GetStringWidth() > width then
    local guard = 0
    while string.len(core) > 0 and guard < 200 do
      core = TrimLastChar(core)
      guard = guard + 1
      measure:SetText(pre .. core .. "..." .. post)
      if measure:GetStringWidth() <= width then break end
    end
    core = core .. "..."
  end
  SetFontSize(fs, size, outline)
  fs:SetText(pre .. core .. post)
end

-- Kurzbezeichnungen fuer die Verzauberungsliste. Die internen
-- Schluessel (RES_FIRE, SPELLPOWER_...) gehoeren nicht in die Anzeige.
local STAT_SHORT = {
  deDE = {
    STR = "Staerke", AGI = "Bew.", STA = "Ausdauer", INT = "Int.", SPI = "Willenskr.",
    ARMOR = "Ruestung", DEFENSE = "Verteidigung", HIT = "Treffer", CRIT = "Krit",
    SPELLHIT = "Zaubertreffer", SPELLCRIT = "Zauberkrit", AP = "Angriffskraft",
    RAP = "Distanz-AK", SPELLPOWER = "Zauberschaden", HEALPOWER = "Heilung",
    SPELLPOWER_ARCANE = "Arkanschaden", SPELLPOWER_FIRE = "Feuerschaden",
    SPELLPOWER_FROST = "Frostschaden", SPELLPOWER_HOLY = "Heiligschaden",
    SPELLPOWER_NATURE = "Naturschaden", SPELLPOWER_SHADOW = "Schattenschaden",
    MP5 = "Mana/5s", HP5 = "Leben/5s", HEALTH = "Leben", MANA = "Mana",
    DODGE = "Ausweichen", PARRY = "Parieren", BLOCK = "Blocken", BLOCKVALUE = "Blockwert",
    RES_FIRE = "Feuerwid.", RES_FROST = "Frostwid.", RES_NATURE = "Naturwid.",
    RES_SHADOW = "Schattenwid.", RES_ARCANE = "Arkanwid.", RES_ALL = "alle Widerstaende",
    WEAPON_MIN = "Min.-Schaden", WEAPON_MAX = "Max.-Schaden",
    WEAPON_SPEED = "Tempo", WEAPON_DPS = "DPS", MELEE_DPS = "Nahkampf-DPS",
  },
  enUS = {
    STR = "Str", AGI = "Agi", STA = "Sta", INT = "Int", SPI = "Spi",
    ARMOR = "Armor", DEFENSE = "Defense", HIT = "Hit", CRIT = "Crit",
    SPELLHIT = "Spell Hit", SPELLCRIT = "Spell Crit", AP = "AP",
    RAP = "Ranged AP", SPELLPOWER = "Spell Power", HEALPOWER = "Healing",
    SPELLPOWER_ARCANE = "Arcane Dmg", SPELLPOWER_FIRE = "Fire Dmg",
    SPELLPOWER_FROST = "Frost Dmg", SPELLPOWER_HOLY = "Holy Dmg",
    SPELLPOWER_NATURE = "Nature Dmg", SPELLPOWER_SHADOW = "Shadow Dmg",
    MP5 = "MP5", HP5 = "HP5", HEALTH = "Health", MANA = "Mana",
    DODGE = "Dodge", PARRY = "Parry", BLOCK = "Block", BLOCKVALUE = "Block Value",
    RES_FIRE = "Fire Res", RES_FROST = "Frost Res", RES_NATURE = "Nature Res",
    RES_SHADOW = "Shadow Res", RES_ARCANE = "Arcane Res", RES_ALL = "all resistances",
    WEAPON_MIN = "Min Dmg", WEAPON_MAX = "Max Dmg",
    WEAPON_SPEED = "Speed", WEAPON_DPS = "DPS", MELEE_DPS = "Melee DPS",
  },
}

local function StatLabel(k)
  local labels = STAT_SHORT[BLL.locale] or STAT_SHORT.enUS
  return labels[k] or k
end
UI.StatLabel = StatLabel

-- Teile nebeneinander setzen, hoechstens maxLines Zeilen. Was nicht
-- passt, faellt weg und wird durch "..." angedeutet. Umbrochen wird nur
-- zwischen Teilen, nie mitten in "+38 Ruestung".
local function JoinFit(measure, parts, width, size, maxLines, gap)
  gap = gap or "   "
  SetFontSize(measure, size)
  local function fits(txt)
    measure:SetText(txt)
    return measure:GetStringWidth() <= width
  end
  local function join(t)
    local out = ""
    for i = 1, table.getn(t) do
      out = (out == "") and t[i] or (out .. gap .. t[i])
    end
    return out
  end

  local lines, cur = {}, {}
  local dropped = false
  for i = 1, table.getn(parts) do
    table.insert(cur, parts[i])
    if not fits(join(cur)) then
      table.remove(cur)
      if table.getn(lines) + 1 < maxLines and table.getn(cur) > 0 then
        table.insert(lines, join(cur))
        cur = { parts[i] }
      else
        dropped = true
        break
      end
    end
  end

  -- "..." braucht selbst Platz: notfalls weitere Teile opfern
  if dropped then
    local more = "|cff666666...|r"
    while table.getn(cur) > 0 and not fits(join(cur) .. gap .. more) do
      table.remove(cur)
    end
    table.insert(cur, more)
  end
  if table.getn(cur) > 0 then table.insert(lines, join(cur)) end
  return table.concat(lines, "\n"), table.getn(lines)
end

local RES_KEYS = { "RES_FIRE", "RES_FROST", "RES_NATURE", "RES_SHADOW", "RES_ARCANE" }

-- Werte einer Verzauberung als lesbare Kurzliste. Fuenf gleiche
-- Widerstaende werden zu einem Eintrag zusammengefasst.
local function EnchantStatText(stats)
  local labels = STAT_SHORT[BLL.locale] or STAT_SHORT.enUS
  local allRes = stats["RES_FIRE"]
  for i = 1, table.getn(RES_KEYS) do
    if stats[RES_KEYS[i]] ~= allRes then allRes = nil; break end
  end

  local parts = {}
  if allRes then table.insert(parts, "+" .. allRes .. " " .. labels.RES_ALL) end
  for j = 1, table.getn(BLL.STATS) do
    local k = BLL.STATS[j]
    local v = stats[k]
    local skip = allRes and string.find(k, "^RES_")
    if v and not skip then
      local shown = (k == "WEAPON_DPS") and string.format("%.1f", v) or v
      table.insert(parts, "+" .. shown .. " " .. (labels[k] or k))
    end
  end
  return table.concat(parts, ", ")
end

-- Hintergrundbilder fuer leere Slots, wie im Charakterfenster
local EMPTY_TEXTURE = {
  HeadSlot          = "Head",          NeckSlot      = "Neck",
  ShoulderSlot      = "Shoulder",      BackSlot      = "Chest",
  ChestSlot         = "Chest",         WristSlot     = "Wrists",
  HandsSlot         = "Hands",         WaistSlot     = "Waist",
  LegsSlot          = "Legs",          FeetSlot      = "Feet",
  Finger0Slot       = "Finger",        Finger1Slot   = "Finger",
  Trinket0Slot      = "Trinket",       Trinket1Slot  = "Trinket",
  MainHandSlot      = "MainHand",      SecondaryHandSlot = "SecondaryHand",
  RangedSlot        = "Ranged",
  ShirtSlot         = "Shirt",         TabardSlot    = "Tabard",
}

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Die Zauberdatenbank liefert keine Iconpfade mit. Statt ueberall ein
-- Fragezeichen zu zeigen, bekommt jede Verzauberung das Bild ihres
-- Berufs - das ordnet die Liste zusaetzlich.
local PROFESSION_ICON = {
  ["Verzauberkunst"]    = "Interface\\Icons\\Trade_Engraving",
  ["Ingenieurskunst"]   = "Interface\\Icons\\Trade_Engineering",
  ["Lederverarbeitung"] = "Interface\\Icons\\INV_Misc_ArmorKit_17",
  ["Schmiedekunst"]     = "Interface\\Icons\\Trade_BlackSmithing",
  ["Schneiderei"]       = "Interface\\Icons\\Trade_Tailoring",
}

-- Etiketten fuer die Herkunft, damit man Dungeon von Weltdrop
-- unterscheidet, ohne die Zone kennen zu muessen.
--
-- Die Schluessel bleiben deutsch, weil sie intern auch in den
-- gespeicherten Einstellungen und in /bll cat stehen. Angezeigt wird,
-- was die Sprachtabelle liefert - vorher standen hier feste deutsche
-- Woerter, die auch im englischen Fenster auftauchten.
local CATEGORY_LABEL = {
  DUNGEON      = { "CAT_DUNGEON",   "ff4a90d9" },
  RAID         = { "CAT_RAID",      "ffa335ee" },
  QUEST        = { "CAT_QUEST",     "ffffd100" },
  HAENDLER     = { "CAT_VENDOR",    "ff40c040" },
  OBJEKT       = { "CAT_OBJECT",    "ff909090" },
  WELTBOSS     = { "CAT_WORLDBOSS", "ffff8000" },
  SCHLACHTFELD = { "CAT_PVP",       "ffc41f3b" },
  WELT         = { "CAT_WORLD",     "ff909090" },
}

local function SlotBackdrop(slotKey)
  local n = EMPTY_TEXTURE[slotKey]
  if not n then return QUESTION_MARK end
  return "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. n
end
local WIDTH, HEIGHT = 780, 700

------------------------------------------------------------------
-- Hilfsfunktion: einfacher Backdrop
------------------------------------------------------------------

local function StyleFrame(f, alpha)
  f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
  })
  f:SetBackdropColor(0, 0, 0, alpha or 1)
end

------------------------------------------------------------------
-- Aufbau
------------------------------------------------------------------

function UI:Init()
  if self.frame then return end

  -- Lootline ist die Standardansicht: sie beantwortet die Frage, mit
  -- der man das Fenster oeffnet ("wohin soll ich gehen"). Die
  -- Slotansicht ist der Sonderfall, den man gezielt anklickt.
  self.viewMode = self.viewMode or "lootline"

  local f = CreateFrame("Frame", "BananaLootlineFrame", UIParent)
  f:SetWidth(WIDTH)
  f:SetHeight(HEIGHT)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
  f:SetFrameStrata("DIALOG")
  StyleFrame(f)
  f:Hide()

  -- ESC schliesst das Fenster
  tinsert(UISpecialFrames, "BananaLootlineFrame")

  ----------------------------------------------------------------
  -- Gildenlogo oben links.
  --
  -- Der 1.12-Client liest kein PNG - nur BLP und unkomprimierte TGA,
  -- mit Kantenlaengen als Zweierpotenz. Die Datei liegt deshalb als
  -- 128x128 TGA in Images/ vor. Der schwarze Hintergrund wurde per
  -- Flutfuellung vom Rand her entfernt, damit das Logo im Fenster
  -- nicht als Kasten sitzt; dunkle Stellen im Logo selbst bleiben.
  ----------------------------------------------------------------
  local logo = f:CreateTexture(nil, "ARTWORK")
  logo:SetWidth(112)
  logo:SetHeight(112)
  logo:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
  logo:SetTexture("Interface\\AddOns\\BananaLootline\\Images\\BananaForge")
  logo:SetAlpha(0.9)
  self.logo = logo

  -- Titel
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -14)
  title:SetText("|cffffcc33Banana|cffffffffLootline|r")
  SetFontSize(title, 20, "OUTLINE")

  local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
  subtitle:SetTextColor(0.6, 0.6, 0.6)
  SetFontSize(subtitle, 13)
  f.subtitle = subtitle

  -- Die Unterzeile ist zugleich die Spec-Auswahl. Erkannt wird weiter
  -- automatisch; der Klick erlaubt, das zu ueberstimmen.
  local specBtn = CreateFrame("Button", nil, f)
  specBtn:SetPoint("TOPLEFT", subtitle, "TOPLEFT", -4, 2)
  specBtn:SetPoint("BOTTOMRIGHT", subtitle, "BOTTOMRIGHT", 4, -2)
  specBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

  local specDD = CreateFrame("Frame", "BananaLootlineSpecDD", f, "UIDropDownMenuTemplate")
  specDD:Hide()
  specDD.initialize = function()
    local L = BLL.L
    local W = BLL.Weights
    local class = BLL.player and BLL.player.class
    local specs = W.SPECS[class or ""] or {}
    local chosen = W:ChosenSpec()

    local head = {}
    head.text = L["SPEC_MENU_TITLE"]
    head.isTitle = 1
    head.notCheckable = 1
    UIDropDownMenu_AddButton(head)

    local detected = W:DetectSpec()
    local auto = {}
    auto.text = L["SPEC_MENU_AUTO"] .. (detected and specs[detected]
      and (" (" .. W:SpecName(specs[detected].name) .. ")")
      or (" (" .. L["NO_SPEC"] .. ")"))
    auto.checked = (chosen == nil)
    auto.func = function() UI:ChooseSpec(nil) end
    UIDropDownMenu_AddButton(auto)

    for i = 1, 3 do
      if specs[i] then
        local info = {}
        info.text = W:SpecName(specs[i].name)
        info.value = i
        info.checked = (chosen == i)
        info.func = function() UI:ChooseSpec(this.value) end
        UIDropDownMenu_AddButton(info)
      end
    end
  end

  specBtn:SetScript("OnClick", function()
    pcall(ToggleDropDownMenu, 1, nil, specDD, specBtn, 0, 0)
  end)
  specBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:SetText(BLL.L["SPEC_MENU_TITLE"])
    GameTooltip:AddLine(BLL.L["SPEC_TIP"], 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
  end)
  specBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.specBtn = specBtn

  -- Schliessen
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

  -- Dankeschoen-Knopf links neben dem Schliessen-Knopf, wie in
  -- BananaRepublik: klein, dezent, oeffnet das Dankesfenster.
  local infoBtn = CreateFrame("Button", nil, f)
  infoBtn:SetWidth(16)
  infoBtn:SetHeight(16)
  infoBtn:SetPoint("RIGHT", close, "LEFT", -2, 0)
  local infoTex = infoBtn:CreateTexture(nil, "ARTWORK")
  infoTex:SetAllPoints(infoBtn)
  infoTex:SetTexture("Interface\\common\\friendship-heart")
  -- Ersatz, falls der Client die Textur nicht kennt
  if not infoTex:GetTexture() then
    infoTex:SetTexture("Interface\\Icons\\INV_ValentinesCard01")
  end
  infoTex:SetVertexColor(1, 0.75, 0.3)
  infoBtn.tex = infoTex
  infoBtn:SetScript("OnEnter", function()
    this.tex:SetVertexColor(1, 1, 1)
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText(BLL.L["ABOUT_TOOLTIP"])
    GameTooltip:Show()
  end)
  infoBtn:SetScript("OnLeave", function()
    this.tex:SetVertexColor(1, 0.75, 0.3)
    GameTooltip:Hide()
  end)
  infoBtn:SetScript("OnClick", function() UI:ShowThanks() end)
  f.infoBtn = infoBtn

  -- Sprachknoepfe DE / EN links vom Herz. Die aktive Sprache leuchtet
  -- gold, die andere ist grau.
  local function LangButton(code, label, anchorTo, xoff)
    local b = CreateFrame("Button", nil, f)
    b:SetWidth(22)
    b:SetHeight(16)
    b:SetPoint("RIGHT", anchorTo, "LEFT", xoff, 0)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints(b)
    fs:SetText(label)
    b.fs = fs
    b.code = code
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_LEFT")
      GameTooltip:SetText(BLL.L["LANG_TOOLTIP"])
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function()
      BananaLootlineDB.language = this.code
      BLL:SetLanguage(this.code)
      UI:ApplyLocale()
      BLL:Print(BLL.L["LANG_SWITCHED"])
    end)
    return b
  end
  f.deBtn = LangButton("deDE", "DE", infoBtn, -4)
  f.enBtn = LangButton("enUS", "EN", f.deBtn, -2)

  -- Neu scannen
  local rescan = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  rescan:SetWidth(90); rescan:SetHeight(20)
  rescan:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
  self.rescanBtn = rescan
  rescan:SetScript("OnClick", function()
    BLL.Scanner:ClearCache()
    BLL.Gear:ScanEquipped()
    UI:Refresh()
  end)

  ----------------------------------------------------------------
  -- Drei Ansichten nebeneinander statt eines Knopfs zum Durchklicken.
  --
  -- Beim Durchklicken sieht man weder, wie viele Ansichten es gibt,
  -- noch in welcher man gerade ist. Nebeneinander beantwortet beides
  -- auf einen Blick, und jede Ansicht ist mit einem Klick erreichbar.
  ----------------------------------------------------------------
  local VIEWS = { { key = "lootline" }, { key = "slot" }, { key = "enchant" } }

  self.viewButtons = {}
  for i = 1, table.getn(VIEWS) do
    local v = VIEWS[i]
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetWidth(110)
    b:SetHeight(21)
    -- Unter den Titel statt daneben: bei -26 ragten sie in die
    -- Ueberschrift hinein.
    b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18 - (table.getn(VIEWS) - i) * 114, -62)
    b.viewKey = v.key
    b:SetScript("OnClick", function()
      UI.viewMode = this.viewKey
      UI:UpdateViewButtons()
      UI:RenderDetail()
    end)
    self.viewButtons[i] = b
  end

  -- Upgrades suchen
  local upgradeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  upgradeBtn:SetWidth(120); upgradeBtn:SetHeight(20)
  upgradeBtn:SetPoint("LEFT", rescan, "RIGHT", 6, 0)
  upgradeBtn:SetScript("OnClick", function()
    BLL.Candidates:Run()
  end)
  self.upgradeBtn = upgradeBtn

  ----------------------------------------------------------------
  -- Vorausplanung
  --
  -- Wie viele Stufen die Suche nach oben reicht. Das gab es bisher nur
  -- als "/bll ahead <n>" im Chat, und zwei Tester haben unabhaengig
  -- voneinander danach gesucht - einer schrieb "I could not adjust the
  -- search range still". Ein Befehl, den niemand findet, ist keine
  -- Einstellung.
  --
  -- Minus und Plus statt eines Eingabefelds: der Wert hat drei
  -- sinnvolle Stellen, und ein Klick ist schneller als tippen.
  ----------------------------------------------------------------

  local MIN_AHEAD, MAX_AHEAD = 0, 20

  local aheadBox = CreateFrame("Frame", nil, f)
  aheadBox:SetWidth(64); aheadBox:SetHeight(20)
  aheadBox:SetPoint("LEFT", upgradeBtn, "RIGHT", 10, 0)

  -- Statt "Voraus" links: rechts daneben in kleiner Schrift, was die
  -- Pfeile tun, und darunter die Stufe, bis zu der gerade gesucht wird.
  local aheadHint = aheadBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  aheadHint:SetPoint("BOTTOMLEFT", aheadBox, "RIGHT", 6, 0)
  aheadHint:SetTextColor(0.8, 0.8, 0.8)
  SetFontSize(aheadHint, 10)
  self.aheadHint = aheadHint

  local aheadNow = aheadBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  aheadNow:SetPoint("TOPLEFT", aheadBox, "RIGHT", 6, -1)
  aheadNow:SetTextColor(0.55, 0.55, 0.55)
  SetFontSize(aheadNow, 10)
  self.aheadNow = aheadNow

  local aheadValue = aheadBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  aheadValue:SetPoint("RIGHT", aheadBox, "RIGHT", -20, 0)
  aheadValue:SetWidth(22)
  aheadValue:SetJustifyH("CENTER")
  self.aheadValue = aheadValue

  local function SetAhead(n)
    if n < MIN_AHEAD then n = MIN_AHEAD end
    if n > MAX_AHEAD then n = MAX_AHEAD end
    BananaLootlineDB.planAhead = n
    UI:UpdateAhead()
  end

  local function CurrentAhead()
    if BLL.Candidates and BLL.Candidates.PlanAhead then
      return BLL.Candidates:PlanAhead()
    end
    return BananaLootlineDB.planAhead or 0
  end

  local aheadMinus = CreateFrame("Button", nil, aheadBox, "UIPanelButtonTemplate")
  aheadMinus:SetWidth(18); aheadMinus:SetHeight(18)
  aheadMinus:SetPoint("RIGHT", aheadValue, "LEFT", -2, 0)
  aheadMinus:SetText("-")
  aheadMinus:SetScript("OnClick", function()
    SetAhead(CurrentAhead() - 1)
  end)

  local aheadPlus = CreateFrame("Button", nil, aheadBox, "UIPanelButtonTemplate")
  aheadPlus:SetWidth(18); aheadPlus:SetHeight(18)
  aheadPlus:SetPoint("LEFT", aheadValue, "RIGHT", 2, 0)
  aheadPlus:SetText("+")
  aheadPlus:SetScript("OnClick", function()
    SetAhead(CurrentAhead() + 1)
  end)

  -- Der Zweck steht im Tooltip, nicht als dritte Zeile im Fenster.
  local function AheadTip()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:SetText(BLL.L["AHEAD_TITLE"])
    GameTooltip:AddLine(BLL.L["AHEAD_TIP"], 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
  end
  local function AheadTipOut() GameTooltip:Hide() end
  for _, b in ipairs({ aheadMinus, aheadPlus }) do
    b:SetScript("OnEnter", AheadTip)
    b:SetScript("OnLeave", AheadTipOut)
  end

  -- Version und Urheber rechts unten. Bei Fehlermeldungen ist die
  -- Version das Erste, was man braucht - hier steht sie, ohne dass
  -- jemand /bll info kennen muss.
  local credit = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  credit:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
  credit:SetJustifyH("RIGHT")
  credit:SetTextColor(0.55, 0.55, 0.55)
  credit:SetText("v" .. ((BLL.Version and BLL:Version()) or "?") .. "  |cffffcc33\194\169 Lumihunt|r")
  self.credit = credit

  self.frame = f
  self:BuildSlotList()
  self:BuildDetailPane()
  self:ApplyLocale()

  return f
end

------------------------------------------------------------------
-- Anzeigesprache anwenden
--
-- Alles, was beim Aufbau einmal beschriftet wird, steht hier. Was bei
-- jedem Zeichnen neu entsteht (Listen, Slotansicht, Statfeld), holt
-- sich die Sprache selbst - dafuer genuegt Refresh.
------------------------------------------------------------------

local VIEW_LABEL = {
  deDE = { lootline = "Lootline", slot = "Pro Item", enchant = "Verzauberung" },
  enUS = { lootline = "Lootline", slot = "Per item", enchant = "Enchant" },
}

-- Zahl und Beschriftung der Vorausplanung auffrischen.
--
-- Der Wert kommt aus Candidates, damit die Vorgabe an einer Stelle
-- steht. Beim Aufbau des Fensters kann Candidates aber noch fehlen -
-- die Ladereihenfolge der TOC stellt das nicht sicher -, deshalb die
-- Pruefung statt eines blinden Aufrufs.
------------------------------------------------------------------
-- Spezialisierung waehlen (nil = automatisch). Die Gewichte aendern
-- die Rangfolge, also wird die Suche gleich neu ausgefuehrt.
------------------------------------------------------------------

function UI:ChooseSpec(tab)
  if CloseDropDownMenus then CloseDropDownMenus() end
  BLL.Weights:SetSpec(tab)
  BLL.Weights:Get()
  if tab then
    BLL:Print(string.format(BLL.L["SPEC_SET"], BLL.Weights.activeSpec or "?"))
  else
    BLL:Print(BLL.L["SPEC_AUTO"])
  end
  if BLL.Weights.customWeights then BLL:Print(BLL.L["CUSTOM_WEIGHTS_NOTE"]) end
  if BLL.WeightsUI then BLL.WeightsUI.work = nil; BLL.WeightsUI:Refresh() end
  if BLL.Candidates and BLL.Candidates.Run then
    BLL.Candidates:Run()
  else
    self:Refresh()
  end
end

-- Beschriftung des Quellen-Knopfs: "Quellen: Alle", "Quellen: Dungeon,
-- Quest" oder "Quellen: 3 von 6", dazu "+ Haendler" / "+ ohne Fundort".
function UI:SourceButtonText(lootline)
  local L = BLL.L
  local C = BLL.Candidates
  if not (C and C.SourceFilter) then return string.format(L["SRC_BUTTON"], L["SRC_ALL"]) end
  local f = C:SourceFilter()
  local main, on = {}, {}
  for _, c in ipairs(C.SOURCE_CATS) do
    if not C.SOURCE_DEFAULT_OFF[c] then
      table.insert(main, c)
      if f[c] then table.insert(on, L["SRC_" .. c]) end
    end
  end
  local txt
  if table.getn(on) == table.getn(main) then
    txt = L["SRC_ALL"]
  elseif table.getn(on) == 0 then
    txt = L["SRC_NONE"]
  elseif table.getn(on) <= 2 then
    txt = table.concat(on, ", ")
  else
    txt = string.format(L["SRC_N"], table.getn(on), table.getn(main))
  end
  if f.HAENDLER then txt = txt .. " +" .. L["SRC_HAENDLER"] end
  if f.NOSOURCE and not lootline then txt = txt .. " +" .. L["SRC_NOSOURCE"] end
  return string.format(L["SRC_BUTTON"], txt)
end

function UI:UpdateAhead()
  if not self.aheadValue then return end
  if not (BLL.Candidates and BLL.Candidates.PlanAhead) then return end
  local n = BLL.Candidates:PlanAhead()
  self.aheadValue:SetText(tostring(n))
  if n == 0 then
    self.aheadValue:SetTextColor(0.6, 0.6, 0.6)
  else
    self.aheadValue:SetTextColor(1, 0.82, 0)
  end
  if self.aheadHint then
    self.aheadHint:SetText(BLL.L["AHEAD_HINT"])
    local lvl = (BLL.player and BLL.player.level) or 0
    self.aheadNow:SetText(string.format(BLL.L["AHEAD_NOW"], math.min(60, lvl + n)))
  end
end

function UI:ApplyLocale()
  local f = self.frame
  if not f then return end
  local de = (BLL.locale == "deDE")

  local labels = VIEW_LABEL[BLL.locale] or VIEW_LABEL.enUS
  for i = 1, table.getn(self.viewButtons or {}) do
    local b = self.viewButtons[i]
    b:SetText(labels[b.viewKey])
  end
  if self.rescanBtn then self.rescanBtn:SetText(de and "Neu scannen" or "Rescan") end
  self:UpdateAhead()
  if self.upgradeBtn then self.upgradeBtn:SetText(de and "Upgrades suchen" or "Find upgrades") end

  local pane = self.detail
  if pane and pane.slotView then
    pane.slotView.secCur.text:SetText(de and "Angelegt" or "Equipped")
    for i = 1, table.getn(pane.rows) do
      pane.rows[i].valueLabel:SetText("|cff888888" .. (de and "Wert" or "score") .. "|r")
    end
  end

  if f.deBtn then
    if de then f.deBtn.fs:SetTextColor(1, 0.82, 0) else f.deBtn.fs:SetTextColor(0.5, 0.5, 0.5) end
    if de then f.enBtn.fs:SetTextColor(0.5, 0.5, 0.5) else f.enBtn.fs:SetTextColor(1, 0.82, 0) end
  end

  local tf = self.thanksFrame
  if tf then
    tf.titleFS:SetText(BLL.L["THANKS_TITLE"])
    tf.bodyFS:SetText(BLL.L["THANKS_BODY"])
    tf.nameLabelFS:SetText(BLL.L["CHARACTER"])
    tf.mailBtn:SetText(BLL.L["FILL_NAME"])
    tf.okBtn:SetText(BLL.L["CLOSE"])
  end

  if f:IsShown() then self:Refresh() end
end

------------------------------------------------------------------
-- Dankesfenster, gleicher Aufbau wie in BananaRepublik
------------------------------------------------------------------

local AUTHOR_CHAR = "Lumihunt"

function UI:ShowThanks()
  local tf = self.thanksFrame

  if not tf then
    tf = CreateFrame("Frame", "BananaLootlineThanksFrame", UIParent)
    tf:SetWidth(340)
    tf:SetHeight(275)
    tf:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    tf:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    tf:SetMovable(true)
    tf:EnableMouse(true)
    tf:RegisterForDrag("LeftButton")
    tf:SetScript("OnDragStart", function() this:StartMoving() end)
    tf:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    tf:SetFrameStrata("FULLSCREEN_DIALOG")
    tinsert(UISpecialFrames, "BananaLootlineThanksFrame")

    local tt = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tt:SetPoint("TOP", tf, "TOP", 0, -18)
    tf.titleFS = tt

    local tclose = CreateFrame("Button", nil, tf, "UIPanelCloseButton")
    tclose:SetPoint("TOPRIGHT", tf, "TOPRIGHT", -6, -6)

    local body = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", tf, "TOPLEFT", 24, -52)
    body:SetWidth(292)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    tf.bodyFS = body

    local nameLabel = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", tf, "TOPLEFT", 24, -158)
    tf.nameLabelFS = nameLabel

    -- Markierbares Feld, damit der Name mit Strg+C kopiert werden kann
    local nameBox = CreateFrame("EditBox", nil, tf, "InputBoxTemplate")
    nameBox:SetWidth(150)
    nameBox:SetHeight(20)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetText(AUTHOR_CHAR)
    -- Wert festhalten: jede Aenderung wird zurueckgesetzt
    nameBox:SetScript("OnTextChanged", function()
      if this:GetText() ~= AUTHOR_CHAR then this:SetText(AUTHOR_CHAR) end
    end)
    nameBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    tf.nameBox = nameBox

    local hint = tf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", tf, "TOPLEFT", 24, -184)
    hint:SetWidth(292)
    hint:SetJustifyH("LEFT")
    tf.hint = hint

    -- Traegt den Empfaenger ein, wenn der Briefkasten offen ist
    local mailBtn = CreateFrame("Button", nil, tf, "UIPanelButtonTemplate")
    mailBtn:SetWidth(150)
    mailBtn:SetHeight(24)
    mailBtn:SetPoint("BOTTOMLEFT", tf, "BOTTOMLEFT", 24, 22)
    mailBtn:SetScript("OnClick", function()
      local L = BLL.L
      if MailFrame and MailFrame:IsVisible() and SendMailNameEditBox then
        if MailFrameTab2 and MailFrameTab_OnClick then
          MailFrameTab_OnClick(2)
        end
        SendMailNameEditBox:SetText(AUTHOR_CHAR)
        if SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() == "" then
          SendMailSubjectEditBox:SetText("BananaLootline")
        end
        BLL:Print(L["RECIPIENT_SET"] .. " |cff00ff00" .. AUTHOR_CHAR .. "|r " .. L["RECIPIENT_THANKS"])
        BananaLootlineThanksFrame:Hide()
      else
        BLL:Print(L["NEED_MAILBOX"] .. " |cffffff00" .. L["MAILBOX"] .. "|r " .. L["NEED_MAILBOX_2"])
      end
    end)
    tf.mailBtn = mailBtn

    local okBtn = CreateFrame("Button", nil, tf, "UIPanelButtonTemplate")
    okBtn:SetWidth(110)
    okBtn:SetHeight(24)
    okBtn:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", -24, 22)
    okBtn:SetScript("OnClick", function() BananaLootlineThanksFrame:Hide() end)
    tf.okBtn = okBtn

    tf:Hide()
    self.thanksFrame = tf
    self:ApplyLocale()
  end

  -- Hinweis und Knopf an die Lage anpassen
  if MailFrame and MailFrame:IsVisible() then
    tf.hint:SetText(BLL.L["MAILBOX_OPEN"])
    tf.mailBtn:Enable()
  else
    tf.hint:SetText(BLL.L["MAILBOX_CLOSED"])
    tf.mailBtn:Disable()
  end
  tf.nameBox:SetText(AUTHOR_CHAR)

  if tf:IsShown() then tf:Hide() else tf:Show() end
end

------------------------------------------------------------------
-- Linke Spalte: Slotliste
------------------------------------------------------------------

--[[----------------------------------------------------------------------
  Linke Seite: Ausruestung als Puppe, wie im Charakterfenster.

  Aufteilung 6 / 6 / 5 statt der originalen 8 / 8 / 3, weil Hemd und
  Wappenrock fehlen - die tragen keine Werte und haetten hier nichts
  zu suchen.

  Jeder Slot ist ein Button mit Icon, Qualitaetsrahmen und Tooltip.
------------------------------------------------------------------------]]

-- Aufteilung wie im Charakterfenster: 8 links, 8 rechts, 3 unten.
-- Hemd und Wappenrock sind reine Anzeigeslots - sie tragen keine Werte,
-- machen die Spalten aber gleich lang.
local PAPERDOLL_LEFT   = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot",
                           "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" }
local PAPERDOLL_RIGHT  = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
                           "Finger0Slot", "Finger1Slot",
                           "Trinket0Slot", "Trinket1Slot" }
local PAPERDOLL_BOTTOM = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot" }

local ICON = 40
local GAP  = 6

function UI:CreateSlotButton(parent, slotKey)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(ICON)
  b:SetHeight(ICON)
  b.slotKey = slotKey

  for i = 1, table.getn(BLL.Gear.SLOTS) do
    if BLL.Gear.SLOTS[i].key == slotKey then
      b.slotID = BLL.Gear.SLOTS[i].id
      b.slotLabel = BLL.Gear:SlotLabel(BLL.Gear.SLOTS[i])
    end
  end
  for i = 1, table.getn(BLL.Gear.DISPLAY_ONLY_SLOTS or {}) do
    local d = BLL.Gear.DISPLAY_ONLY_SLOTS[i]
    if d.key == slotKey then
      b.slotID = d.id
      b.slotLabel = BLL.Gear:SlotLabel(d)
      b.displayOnly = true   -- kein Vorschlag, kein Klickziel
    end
  end

  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetAllPoints(b)
  icon:SetTexture(SlotBackdrop(slotKey))
  b.icon = icon

  -- Qualitaetsrahmen. Liegt ueber dem Icon und wird eingefaerbt, statt
  -- fuer jede Qualitaet eine eigene Textur zu laden.
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  border:SetBlendMode("ADD")
  border:SetWidth(ICON * 1.9)
  border:SetHeight(ICON * 1.9)
  border:SetPoint("CENTER", b, "CENTER", 0, 0)
  border:Hide()
  b.border = border

  local sel = b:CreateTexture(nil, "ARTWORK")
  sel:SetAllPoints(b)
  sel:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  sel:SetAlpha(0.5)
  sel:Hide()
  b.sel = sel

  b:SetScript("OnEnter", function()
    local data = BLL.Gear.equipped[this.slotKey]
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    if data and this.slotID then
      GameTooltip:SetInventoryItem("player", this.slotID)
    else
      GameTooltip:SetText(this.slotLabel or "?")
      GameTooltip:AddLine("|cff888888" .. BLL.L["EMPTY"] .. "|r")
    end
    GameTooltip:Show()
  end)

  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  b:SetScript("OnClick", function()
    if this.displayOnly then return end
    UI.selectedSlot = this.slotKey
    UI.viewMode = "slot"
    UI:UpdateViewButtons()
    UI:UpdateSelection()
    UI:ShowDetail(this.slotKey)
  end)

  return b
end

function UI:BuildSlotList()
  local f = self.frame

  local doll = CreateFrame("Frame", nil, f)
  doll:SetWidth(330)
  -- Senkrecht mittig zwischen Logo (endet bei -122) und Knopfleiste
  -- (beginnt bei -666): 544 Pixel Platz, der Block vom Kopf bis zur
  -- Waffenreihe ist 394 hoch, also 75 Pixel Abstand oben und unten.
  doll:SetHeight(394)
  doll:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -197)
  self.doll = doll

  self.slotButtons = {}

  local function place(list, anchorX, anchorY, horizontal)
    for i = 1, table.getn(list) do
      local key = list[i]
      local b = self:CreateSlotButton(doll, key)
      if horizontal then
        b:SetPoint("TOPLEFT", doll, "TOPLEFT",
                   anchorX + (i - 1) * (ICON + GAP), anchorY)
      else
        b:SetPoint("TOPLEFT", doll, "TOPLEFT",
                   anchorX, anchorY - (i - 1) * (ICON + GAP))
      end
      self.slotButtons[key] = b
    end
  end

  place(PAPERDOLL_LEFT,  0,   0,   false)
  place(PAPERDOLL_RIGHT, 290, 0,   false)
  -- Waffen mittig unter die Puppe
  place(PAPERDOLL_BOTTOM, 99, -354, true)

  ----------------------------------------------------------------
  -- Charaktermodell in die Luecke zwischen den Spalten.
  --
  -- PlayerModel ist derselbe Frametyp, den das Charakterfenster
  -- verwendet. In 1.12 bleibt das Modell gelegentlich leer, wenn
  -- SetUnit vor dem Anzeigen aufgerufen wird - deshalb passiert das
  -- zusaetzlich bei jedem Oeffnen (siehe RefreshModel).
  ----------------------------------------------------------------
  local model = CreateFrame("PlayerModel", "BananaLootlineModel", doll)
  model:SetWidth(190)
  model:SetHeight(360)
  -- Der Client rendert die Figur im unteren Teil des Rahmens; oben
  -- bleiben rund 80 Pixel leer. Der Rahmen ragt deshalb ueber die
  -- Slotspalten hinaus, damit der Kopf auf Hoehe des obersten Slots
  -- sitzt. Der leere Teil ueberdeckt nichts Sichtbares.
  model:SetPoint("TOPLEFT", doll, "TOPLEFT", 70, 72)
  model:EnableMouse(true)

  -- Ziehen dreht die Figur, wie im Charakterfenster
  model:SetScript("OnMouseDown", function()
    this.rotating = true
    this.lastX = nil
  end)
  model:SetScript("OnMouseUp", function()
    this.rotating = false
  end)
  model:SetScript("OnUpdate", function()
    if not this.rotating then return end
    local x = GetCursorPosition()
    if this.lastX then
      this.facing = (this.facing or 0) + (x - this.lastX) * 0.02
      this:SetRotation(this.facing)
    end
    this.lastX = x
  end)

  self.model = model

  -- Slotname unter das Modell, sonst ueberdeckt es ihn
  local hint = doll:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  hint:SetPoint("TOP", doll, "TOPLEFT", 165, -338)
  hint:SetWidth(170)
  self.dollHint = hint

  self.slotList = doll
  self:BuildStatsPanel(doll)
end

--[[----------------------------------------------------------------------
  Statfeld unter der Puppe, wie im Charakterfenster.

  Die Werte kommen aus den Spiel-APIs, NICHT aus unserem Tooltipscan:
  UnitStat und UnitArmor kennen auch Buffs, Talente und Verzauberungen.
  Der Scan sieht nur, was auf den Items steht - beides nebeneinander
  waere widerspruechlich, und hier ist der Charakterwert der richtige.
------------------------------------------------------------------------]]

--[[----------------------------------------------------------------------
  Statfeld wie im Charakterfenster des Servers: zwei Kaesten neben-
  einander, jeder mit Auswahlkopf (Grundwerte, Nahkampf, Distanz,
  Zauber, Verteidigung), darunter sechs Zeilen - Bezeichnung gold,
  Wert rechtsbuendig. Gewinne gruen, Abzuege rot.

  Die Werte kommen aus den Spiel-APIs, nicht aus dem Tooltipscan:
  nur die kennen Buffs, Talente und Verzauberungen. Wo der 1.12-Client
  keine API hat (Zauberschaden, Treffer), springt die Summe der
  gescannten Ausruestung ein.
------------------------------------------------------------------------]]

local STAT_CATS = { "BASE", "MELEE", "RANGED", "SPELL", "DEFENSE" }

local STAT_TEXT = {
  deDE = {
    BASE = "Grundwerte", MELEE = "Nahkampf", RANGED = "Distanz", SPELL = "Zauber", DEFENSE = "Verteidigung",
    STR = "Staerke:", AGI = "Beweglichkeit:", STA = "Ausdauer:", INT = "Intelligenz:", SPI = "Willenskraft:",
    ARMOR = "Ruestung:", SKILL = "Fertigkeit:", DAMAGE = "Schaden:", SPEED = "Tempo:", POWER = "Kraft:",
    HIT = "Trefferwertung:", CRIT = "Krit-Chance:", SPELLDMG = "Zauberschaden:", HEAL = "Heilung:",
    MP5 = "Mana/5s:", MANA = "Mana:", DEFENSE_V = "Verteidigung:", DODGE = "Ausweichen:",
    PARRY = "Parieren:", BLOCK = "Blocken:", HEALTH = "Leben:",
  },
  enUS = {
    BASE = "Base Stats", MELEE = "Melee", RANGED = "Ranged", SPELL = "Spell", DEFENSE = "Defense",
    STR = "Strength:", AGI = "Agility:", STA = "Stamina:", INT = "Intellect:", SPI = "Spirit:",
    ARMOR = "Armor:", SKILL = "Skill:", DAMAGE = "Damage:", SPEED = "Speed:", POWER = "Power:",
    HIT = "Hit Rating:", CRIT = "Crit Chance:", SPELLDMG = "Spell Damage:", HEAL = "Healing:",
    MP5 = "Mana/5s:", MANA = "Mana:", DEFENSE_V = "Defense:", DODGE = "Dodge:",
    PARRY = "Parry:", BLOCK = "Block:", HEALTH = "Health:",
  },
}

local function StatText(key)
  local t = STAT_TEXT[BLL.locale] or STAT_TEXT.enUS
  return t[key] or key
end

-- Farbe nach Modifikator, wie im Charakterfenster
local function ModColour(pos, neg)
  if neg and neg < 0 then return "|cffff5555" end
  if pos and pos > 0 then return "|cff44ff44" end
  return "|cffffffff"
end

local function Pct(v) return string.format("%.2f%%", v or 0) end

local function GearSum(k)
  local t = BLL.Gear and BLL.Gear.totals
  return (t and t[k]) or 0
end

-- Zeilen einer Kategorie: Liste aus { Bezeichnung, Wert }
local function StatRows(cat)
  local rows = {}
  local function add(key, val) table.insert(rows, { StatText(key), val }) end

  if cat == "BASE" then
    local keys = { "STR", "AGI", "STA", "INT", "SPI" }
    for i = 1, 5 do
      local base, stat, pos, neg = UnitStat("player", i)
      add(keys[i], ModColour(pos, neg) .. (stat or base or 0) .. "|r")
    end
    local base, eff, _, pos, neg = UnitArmor("player")
    add("ARMOR", ModColour(pos, neg) .. (eff or base or 0) .. "|r")

  elseif cat == "MELEE" then
    if UnitAttackBothHands then
      local b, m = UnitAttackBothHands("player")
      add("SKILL", ModColour(m, m) .. ((b or 0) + (m or 0)) .. "|r")
    end
    if UnitDamage then
      local lo, hi = UnitDamage("player")
      add("DAMAGE", "|cffffffff" .. math.floor(lo or 0) .. " - " .. math.ceil(hi or 0) .. "|r")
    end
    if UnitAttackSpeed then
      add("SPEED", "|cffffffff" .. string.format("%.2f", UnitAttackSpeed("player") or 0) .. "|r")
    end
    if UnitAttackPower then
      local b, pos, neg = UnitAttackPower("player")
      add("POWER", ModColour(pos, neg) .. ((b or 0) + (pos or 0) + (neg or 0)) .. "|r")
    end
    local hit = (type(GetHitModifier) == "function" and GetHitModifier()) or GearSum("HIT")
    add("HIT", "|cffffffff" .. (hit or 0) .. "%|r")
    if type(GetCritChance) == "function" then
      add("CRIT", "|cffffffff" .. Pct(GetCritChance()) .. "|r")
    end

  elseif cat == "RANGED" then
    if UnitRangedAttack then
      local b, m = UnitRangedAttack("player")
      add("SKILL", ModColour(m, m) .. ((b or 0) + (m or 0)) .. "|r")
    end
    if UnitRangedDamage then
      local speed, lo, hi = UnitRangedDamage("player")
      add("DAMAGE", "|cffffffff" .. math.floor(lo or 0) .. " - " .. math.ceil(hi or 0) .. "|r")
      add("SPEED", "|cffffffff" .. string.format("%.2f", speed or 0) .. "|r")
    end
    if UnitRangedAttackPower then
      local b, pos, neg = UnitRangedAttackPower("player")
      add("POWER", ModColour(pos, neg) .. ((b or 0) + (pos or 0) + (neg or 0)) .. "|r")
    end
    local hit = (type(GetHitModifier) == "function" and GetHitModifier()) or GearSum("HIT")
    add("HIT", "|cffffffff" .. (hit or 0) .. "%|r")
    local crit = (type(GetRangedCritChance) == "function" and GetRangedCritChance())
      or (type(GetCritChance) == "function" and GetCritChance()) or nil
    if crit then add("CRIT", "|cffffffff" .. Pct(crit) .. "|r") end

  elseif cat == "SPELL" then
    local dmg = (type(GetSpellBonusDamage) == "function" and GetSpellBonusDamage(2)) or GearSum("SPELLPOWER")
    add("SPELLDMG", "|cffffffff" .. (dmg or 0) .. "|r")
    local heal = (type(GetSpellBonusHealing) == "function" and GetSpellBonusHealing())
      or (GearSum("SPELLPOWER") + GearSum("HEALPOWER"))
    add("HEAL", "|cffffffff" .. (heal or 0) .. "|r")
    add("HIT", "|cffffffff" .. GearSum("SPELLHIT") .. "%|r")
    local crit = (type(GetSpellCritChance) == "function" and GetSpellCritChance(2)) or GearSum("SPELLCRIT")
    add("CRIT", "|cffffffff" .. Pct(crit) .. "|r")
    add("MP5", "|cffffffff" .. GearSum("MP5") .. "|r")
    add("MANA", "|cffffffff" .. (UnitManaMax("player") or 0) .. "|r")

  elseif cat == "DEFENSE" then
    local base, eff, _, pos, neg = UnitArmor("player")
    add("ARMOR", ModColour(pos, neg) .. (eff or base or 0) .. "|r")
    if UnitDefense then
      local b, m = UnitDefense("player")
      add("DEFENSE_V", ModColour(m, m) .. ((b or 0) + (m or 0)) .. "|r")
    end
    if type(GetDodgeChance) == "function" then add("DODGE", "|cffffffff" .. Pct(GetDodgeChance()) .. "|r") end
    if type(GetParryChance) == "function" then add("PARRY", "|cffffffff" .. Pct(GetParryChance()) .. "|r") end
    if type(GetBlockChance) == "function" then add("BLOCK", "|cffffffff" .. Pct(GetBlockChance()) .. "|r") end
    add("HEALTH", "|cffffffff" .. (UnitHealthMax("player") or 0) .. "|r")
  end

  return rows
end

-- Masse: passt genau zwischen die beiden Slotspalten (x 46 bis 284)
local SB_W, SB_GAP = 116, 6
local SB_HEAD = 20
local SB_ROW = 12
local SB_H = SB_HEAD + 6 * SB_ROW + 12

local ddCounter = 0

-- Duenner grauer Rahmen wie im Charakterfenster
local function StatBackdrop(f)
  f:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
  f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
end

function UI:BuildStatBox(parent, x, side, default)
  local box = CreateFrame("Frame", nil, parent)
  box:SetWidth(SB_W)
  box:SetHeight(SB_H)
  box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, 0)
  box.side = side
  box.default = default

  -- Kopf: dunkle Leiste, Titel mittig, Pfeilknopf rechts
  local head = CreateFrame("Button", nil, box)
  head:SetWidth(SB_W); head:SetHeight(SB_HEAD)
  head:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
  StatBackdrop(head)
  local ht = head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ht:SetPoint("CENTER", head, "CENTER", -8, 0)
  SetFontSize(ht, 11)
  ht:SetTextColor(1, 0.82, 0)
  head.text = ht

  local arrow = CreateFrame("Button", nil, head)
  arrow:SetWidth(18); arrow:SetHeight(18)
  arrow:SetPoint("RIGHT", head, "RIGHT", -1, 0)
  arrow:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
  arrow:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
  arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
  box.arrow = arrow

  -- Auswahlmenue ueber das Standard-Dropdown des Clients
  ddCounter = ddCounter + 1
  local dd = CreateFrame("Frame", "BananaLootlineStatDD" .. ddCounter, box, "UIDropDownMenuTemplate")
  dd:Hide()
  dd.initialize = function()
    for i = 1, table.getn(STAT_CATS) do
      local cat = STAT_CATS[i]
      local info = {}
      info.text = StatText(cat)
      info.value = cat
      info.checked = (UI:StatBoxCat(box) == cat)
      info.func = function()
        UI:SetStatBoxCat(box, this.value)
        if CloseDropDownMenus then CloseDropDownMenus() end
      end
      UIDropDownMenu_AddButton(info)
    end
  end
  box.dd = dd

  local function Open()
    -- Faellt das Menue auf einem Client aus, blaettert der Klick
    -- stattdessen zur naechsten Kategorie.
    local ok = pcall(ToggleDropDownMenu, 1, nil, dd, head, 0, 0)
    if not ok then
      local cur = UI:StatBoxCat(box)
      local nxt = STAT_CATS[1]
      for i = 1, table.getn(STAT_CATS) do
        if STAT_CATS[i] == cur then nxt = STAT_CATS[math.mod(i, table.getn(STAT_CATS)) + 1] end
      end
      UI:SetStatBoxCat(box, nxt)
    end
  end
  head:SetScript("OnClick", Open)
  arrow:SetScript("OnClick", Open)

  -- Rumpf mit sechs Zeilen
  local body = CreateFrame("Frame", nil, box)
  body:SetWidth(SB_W); body:SetHeight(SB_H - SB_HEAD - 2)
  body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
  StatBackdrop(body)

  box.cells = {}
  for i = 1, 6 do
    local y = -6 - (i - 1) * SB_ROW
    local lbl = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", body, "TOPLEFT", 5, y)
    lbl:SetWidth(SB_W - 10)
    lbl:SetJustifyH("LEFT")
    SetFontSize(lbl, 10)
    lbl:SetTextColor(1, 0.82, 0)
    local val = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    val:SetPoint("TOPLEFT", body, "TOPLEFT", 5, y)
    val:SetWidth(SB_W - 10)
    val:SetJustifyH("RIGHT")
    SetFontSize(val, 10)
    box.cells[i] = { label = lbl, value = val }
  end

  box.head = head
  return box
end

-- Gewaehlte Kategorie, pro Charakter gespeichert
function UI:StatBoxCat(box)
  local c = BananaLootlineChar and BananaLootlineChar.statBoxes
  return (c and c[box.side]) or box.default
end

function UI:SetStatBoxCat(box, cat)
  BananaLootlineChar = BananaLootlineChar or {}
  BananaLootlineChar.statBoxes = BananaLootlineChar.statBoxes or {}
  BananaLootlineChar.statBoxes[box.side] = cat
  self:UpdateStatsPanel()
end

function UI:BuildStatsPanel(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetWidth(SB_W * 2 + SB_GAP)
  p:SetHeight(SB_H)
  p:SetPoint("TOPLEFT", parent, "TOPLEFT", 46, -228)
  -- Ueber dem Modell zeichnen, das Modell reicht bis hierher
  if self.model then p:SetFrameLevel(self.model:GetFrameLevel() + 2) end

  p.boxes = {
    self:BuildStatBox(p, 0, "left", "BASE"),
    self:BuildStatBox(p, SB_W + SB_GAP, "right", "MELEE"),
  }
  self.statsPanel = p
end

function UI:UpdateStatsPanel()
  local p = self.statsPanel
  if not p then return end
  for b = 1, 2 do
    local box = p.boxes[b]
    local cat = self:StatBoxCat(box)
    box.head.text:SetText(StatText(cat))
    local rows = StatRows(cat)
    for i = 1, 6 do
      local c = box.cells[i]
      local r = rows[i]
      c.label:SetText(r and r[1] or "")
      c.value:SetText(r and r[2] or "")
    end
  end
end

-- Modell neu aufbauen. Ein einmaliges SetUnit reicht in 1.12 nicht
-- zuverlaessig: nach einem Reload oder wenn das Fenster beim Login
-- versteckt war, bleibt die Flaeche sonst leer.
function UI:RefreshModel()
  if not self.model then return end
  local ok = pcall(function()
    self.model:SetUnit("player")
    self.model:SetRotation(self.model.facing or 0.4)
  end)
  if not ok then
    -- Manche Clients kennen PlayerModel nicht oder scheitern daran.
    -- Dann lieber ausblenden als eine schwarze Flaeche zeigen.
    self.model:Hide()
    self.model = nil
  end
end

-- Die aktive Ansicht wird abgedunkelt und nicht anklickbar. Ohne diese
-- Rueckmeldung weiss man nicht, welche Ansicht gerade laeuft.
function UI:UpdateViewButtons()
  if not self.viewButtons then return end
  for i = 1, table.getn(self.viewButtons) do
    local b = self.viewButtons[i]
    -- Abgesichert: sollte ein Client die Vorlage anders umsetzen,
    -- faellt nur die Hervorhebung aus, nicht das ganze Fenster.
    if b.viewKey == self.viewMode then
      if b.Disable then b:Disable() end
    else
      if b.Enable then b:Enable() end
    end
  end
end

function UI:UpdateSelection()
  if not self.slotButtons then return end
  for key, b in pairs(self.slotButtons) do
    if key == self.selectedSlot then b.sel:Show() else b.sel:Hide() end
  end
  if self.dollHint then
    local label = ""
    if self.selectedSlot and self.slotButtons[self.selectedSlot] then
      label = self.slotButtons[self.selectedSlot].slotLabel or ""
    end
    self.dollHint:SetText("|cffffffff" .. label .. "|r")
  end
end

------------------------------------------------------------------
-- Rechte Spalte: Detailbereich
------------------------------------------------------------------

function UI:BuildDetailPane()
  local f = self.frame

  local pane = CreateFrame("Frame", nil, f)
  pane:SetWidth(400)
  pane:SetHeight(HEIGHT - 150)
  pane:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -90)
  StyleFrame(pane, 0.4)

  local header = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOPLEFT", pane, "TOPLEFT", 12, -12)
  -- Rechts daneben sitzt der Quellen-Knopf (150 breit). Laengere
  -- Meldungen ("Noch kein Weg ...") brechen deshalb vor ihm um, statt
  -- unter ihm durchzulaufen.
  header:SetWidth(220)
  header:SetJustifyH("LEFT")
  SetFontSize(header, 17, "OUTLINE")
  pane.header = header

  ----------------------------------------------------------------
  -- Quellen-Dropdown, rechts oben in beiden Ansichten.
  --
  -- Ersetzt die Haken "Haendler zeigen" (Wegplan) und "Nur mit
  -- Fundort" (Pro Item). Mehrfachauswahl: das Menue bleibt beim Klick
  -- offen, jeder Klick zeichnet die Liste neu. Die Auswahl gilt fuer
  -- beide Ansichten. Logik in Candidates.lua (Cand:SourceFilter).
  ----------------------------------------------------------------
  local srcBtn = CreateFrame("Button", "BananaLootlineSourceButton", pane, "UIPanelButtonTemplate")
  srcBtn:SetHeight(20); srcBtn:SetWidth(150)
  srcBtn:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -10, -8)
  srcBtn:Hide()

  local srcDD = CreateFrame("Frame", "BananaLootlineSourceDD", pane, "UIDropDownMenuTemplate")
  srcDD:Hide()
  srcDD.initialize = function()
    local L = BLL.L
    local C = BLL.Candidates
    local f = C:SourceFilter()
    local head = {}
    head.text = L["SRC_TITLE"]; head.isTitle = 1; head.notCheckable = 1
    UIDropDownMenu_AddButton(head)
    for _, cat in ipairs(C.SOURCE_CATS) do
      -- "Ohne Fundort" gibt es nur in "Pro Item"; der Wegplan braucht
      -- immer einen Ort.
      if cat ~= "NOSOURCE" or pane.listView ~= "lootline" then
        local info = {}
        info.text = L["SRC_" .. cat]
        info.value = cat
        info.checked = f[cat] and 1 or nil
        info.keepShownOnClick = 1
        info.func = function()
          C:SetSourceCat(this.value, not C:SourceFilter()[this.value])
          BLL.UI:Refresh()
        end
        UIDropDownMenu_AddButton(info)
      end
    end
    -- Leichtere Ruestung: kein Fundort, gehoert aber zur Frage "was
    -- wird mir vorgeschlagen" und gilt fuer beide Ansichten.
    local arm = {}
    arm.text = L["SRC_LIGHTER_ARMOR"]
    arm.checked = C:ShowLighterArmor() and 1 or nil
    arm.keepShownOnClick = 1
    arm.func = function()
      C:SetShowLighterArmor(not C:ShowLighterArmor())
      BLL.UI:Refresh()
    end
    UIDropDownMenu_AddButton(arm)
  end

  srcBtn:SetScript("OnClick", function()
    pcall(ToggleDropDownMenu, 1, nil, srcDD, srcBtn, 0, 0)
  end)
  srcBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText(BLL.L["SRC_TITLE"])
    GameTooltip:AddLine(BLL.L["SRC_TIP"], 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
  end)
  srcBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  pane.sourceBtn = srcBtn

  ----------------------------------------------------------------
  -- Slotansicht: drei Bereiche untereinander
  --   [Angelegt]   Icon, Name gross, Werte klein
  --   [Upgrades]   je Vorschlag: Icon, Name gross, Wertaenderung und
  --                Fundort mit Dropchance klein darunter
  -- Alles haengt an einem eigenen Rahmen, damit die Listenansichten
  -- ihn mit einem Aufruf ausblenden koennen.
  ----------------------------------------------------------------
  local sv = CreateFrame("Frame", nil, pane)
  sv:SetAllPoints(pane)
  sv:Hide()
  pane.slotView = sv
  -- Der Quellen-Knopf entstand vorher und laege sonst unter dieser Ebene.
  if pane.sourceBtn and sv:GetFrameLevel() then
    pane.sourceBtn:SetFrameLevel(sv:GetFrameLevel() + 10)
  end

  local function SectionBar(y)
    local bar = CreateFrame("Frame", nil, sv)
    bar:SetWidth(366); bar:SetHeight(22)
    bar:SetPoint("TOPLEFT", sv, "TOPLEFT", 10, y)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetAllPoints(bar)
    bg:SetVertexColor(0.25, 0.20, 0.06, 0.55)
    local line = bar:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    line:SetVertexColor(0.5, 0.42, 0.15, 0.9)
    local t = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("LEFT", bar, "LEFT", 8, 0)
    t:SetJustifyH("LEFT")
    SetFontSize(t, 14, "OUTLINE")
    t:SetTextColor(1, 0.82, 0)
    bar.text = t
    local r = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    r:SetJustifyH("RIGHT")
    SetFontSize(r, 12)
    bar.right = r
    return bar
  end

  local function QualityIcon(parent, size)
    local ic = parent:CreateTexture(nil, "ARTWORK")
    ic:SetWidth(size); ic:SetHeight(size)
    local bd = parent:CreateTexture(nil, "OVERLAY")
    bd:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    bd:SetBlendMode("ADD")
    bd:SetWidth(size * 1.8); bd:SetHeight(size * 1.8)
    bd:SetPoint("CENTER", ic, "CENTER", 0, 0)
    bd:Hide()
    return ic, bd
  end

  local function Highlight(btn)
    local hl = btn:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints(btn)
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetAlpha(0.3)
    hl:Hide()
    btn.hl = hl
  end

  -- Bereich 1: angelegtes Teil. Alles beginnt 26 Pixel tiefer als
  -- frueher: darueber sitzt rechts der Quellen-Knopf, den die Zeile
  -- "Angelegt" sonst verdeckte.
  local TOP = -26
  sv.secCur = SectionBar(TOP - 10)
  sv.secCur.text:SetText(BLL.locale == "deDE" and "Angelegt" or "Equipped")

  local cur = CreateFrame("Button", nil, sv)
  cur:SetWidth(366); cur:SetHeight(56)
  cur:SetPoint("TOPLEFT", sv, "TOPLEFT", 10, TOP - 36)
  Highlight(cur)
  cur.icon, cur.border = QualityIcon(cur, 40)
  cur.icon:SetPoint("TOPLEFT", cur, "TOPLEFT", 4, -6)
  cur.name = cur:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  cur.name:SetPoint("TOPLEFT", cur, "TOPLEFT", 54, -5)
  cur.name:SetWidth(308)
  cur.name:SetJustifyH("LEFT")
  cur.stats = cur:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  cur.stats:SetPoint("TOPLEFT", cur.name, "BOTTOMLEFT", 0, -4)
  cur.stats:SetWidth(308)
  cur.stats:SetJustifyH("LEFT")
  cur.stats:SetSpacing(2)
  SetFontSize(cur.stats, 12)
  cur:SetScript("OnEnter", function()
    if not this.slotID or not this.hasItem then return end
    this.hl:Show()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetInventoryItem("player", this.slotID)
    GameTooltip:Show()
  end)
  cur:SetScript("OnLeave", function() this.hl:Hide(); GameTooltip:Hide() end)
  sv.cur = cur

  -- Bereich 2: Upgrades
  sv.secUp = SectionBar(TOP - 102)
  sv.secUp.text:SetText("Upgrades")

  local status = sv:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  status:SetPoint("TOPLEFT", sv, "TOPLEFT", 18, TOP - 134)
  status:SetWidth(350)
  status:SetJustifyH("LEFT")
  SetFontSize(status, 13)
  sv.status = status

  local UPGRADE_ROWS = 6
  local UP_TOP, UP_STEP = TOP - 130, 64
  pane.rows = {}
  for i = 1, UPGRADE_ROWS do
    local row = CreateFrame("Button", nil, sv)
    row:SetWidth(366)
    row:SetHeight(60)
    row:SetPoint("TOPLEFT", sv, "TOPLEFT", 10, UP_TOP - (i - 1) * UP_STEP)
    Highlight(row)

    row.icon, row.border = QualityIcon(row, 36)
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -6)

    -- Zeile 1: Name gross, Wert rechts
    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", row, "TOPLEFT", 50, -4)
    name:SetWidth(246)
    name:SetJustifyH("LEFT")
    row.name = name

    local val = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    val:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -4)
    val:SetWidth(64)
    val:SetJustifyH("RIGHT")
    SetFontSize(val, 15, "OUTLINE")
    row.value = val

    -- "Wert" unter der Zahl, sonst liest man +1.9 als Statwert
    local valLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valLbl:SetPoint("TOPRIGHT", val, "BOTTOMRIGHT", 0, -1)
    valLbl:SetJustifyH("RIGHT")
    SetFontSize(valLbl, 10)
    valLbl:SetText("|cff888888" .. (BLL.locale == "deDE" and "Wert" or "score") .. "|r")
    row.valueLabel = valLbl

    -- Zeile 2: Wertaenderung, Zeile 3: Fundort mit Dropchance
    local diff = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    diff:SetPoint("TOPLEFT", row, "TOPLEFT", 50, -24)
    diff:SetWidth(312)
    diff:SetJustifyH("LEFT")
    SetFontSize(diff, 12)
    row.diffText = diff

    local src = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    src:SetPoint("TOPLEFT", row, "TOPLEFT", 50, -40)
    src:SetWidth(312)
    src:SetJustifyH("LEFT")
    SetFontSize(src, 12)
    row.srcText = src

    -- Trennlinie unter jedem Vorschlag
    local sep = row:CreateTexture(nil, "BACKGROUND")
    sep:SetTexture("Interface\\Buttons\\WHITE8X8")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, -2)
    sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, -2)
    sep:SetVertexColor(0.4, 0.4, 0.4, 0.35)
    row.sep = sep

    row:SetScript("OnEnter", function()
      if not this.itemID then return end
      this.hl:Show()
      GameTooltip:SetOwner(this, "ANCHOR_LEFT")
      GameTooltip:SetHyperlink("item:" .. this.itemID .. ":0:0:0")
      -- Items nur aus dem Import kennt der Client noch nicht; dann
      -- zeigen wir, was wir selbst wissen.
      if GameTooltip:NumLines() < 2 then
        GameTooltip:ClearLines()
        BLL.UI:FallbackTooltip(GameTooltip, this.itemID)
      end
      if this.questID then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(BLL.L["QI_CLICK"], 1, 0.82, 0)
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() this.hl:Hide(); GameTooltip:Hide() end)

    -- Shift-Klick haengt den Itemlink ins Chatfenster
    row:SetScript("OnClick", function()
      if not this.itemID then return end
      if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
        local _, link = GetItemInfo(this.itemID)
        if link then ChatFrameEditBox:Insert(link) end
      elseif this.questID and BLL.QuestInfo then
        GameTooltip:Hide()
        BLL.QuestInfo:Show(this.questID, this.itemID)
      end
    end)

    row:Hide()
    pane.rows[i] = row
  end

  ----------------------------------------------------------------
  -- Zeilen fuer die Lootline-Ansicht. Flacher als die Slotzeilen,
  -- dafuer mehr davon: hier zaehlt die Uebersicht ueber viele Orte,
  -- nicht die Aufschluesselung eines einzelnen Vorschlags.
  ----------------------------------------------------------------
  -- Die Zeilen werden nicht mehr fest positioniert. RenderList legt sie
  -- bei jedem Zeichnen neu an, weil Ueberschriften, Itemzeilen und
  -- zweizeilige Verzauberungen unterschiedlich hoch sind. 22 Rahmen
  -- reichen fuer den hoechstmoeglichen sichtbaren Ausschnitt.
  local LL_ROWS = 22
  pane.llRows = {}
  pane.offset = 1
  pane.list = {}

  -- Unsichtbare Messschrift fuer FitText
  local measure = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  measure:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 0)
  measure:SetAlpha(0)
  pane.measure = measure

  local function Wheel()
    -- Ohne aktive Listenansicht gibt es nichts zu scrollen. Fehlte diese
    -- Pruefung, zeichnete das Mausrad in der Einzelansicht die zuletzt
    -- aufgebaute Lootline wieder ueber das Fenster - die Zeilen waren
    -- nur versteckt, ihre Daten standen noch in pane.list.
    if not pane.listView then return end
    local d = arg1 or 0
    pane.offset = (pane.offset or 1) - d * 2
    BLL.UI:RenderList()
  end

  for i = 1, LL_ROWS do
    local row = CreateFrame("Button", nil, pane)
    row:SetWidth(366)
    row:SetHeight(26)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", Wheel)

    local hl = row:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints(row)
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetAlpha(0.3)
    hl:Hide()
    row.hl = hl

    local ic = row:CreateTexture(nil, "ARTWORK")
    ic:SetWidth(22); ic:SetHeight(22)
    ic:SetPoint("LEFT", row, "LEFT", 14, 0)
    ic:Hide()
    row.icon = ic

    local left = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    left:SetJustifyH("LEFT")
    SetFontSize(left, 13)
    row.leftText = left

    -- Zweite Zeile, nur bei Verzauberungen: die Werte. Vorher standen
    -- sie hinter dem Namen und brachen in die naechste Zeile um.
    local sub = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetJustifyH("LEFT")
    SetFontSize(sub, 12)
    sub:Hide()
    row.subText = sub

    local right = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    right:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    right:SetWidth(86)
    right:SetJustifyH("RIGHT")
    SetFontSize(right, 13)
    row.rightText = right

    -- Trennlinie ueber der Zeile. Nur bei Gruppenkoepfen sichtbar.
    local sep = row:CreateTexture(nil, "BACKGROUND")
    sep:SetTexture("Interface\\Buttons\\WHITE8X8")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 2)
    sep:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 2)
    sep:SetVertexColor(0.5, 0.42, 0.15, 0.8)
    sep:Hide()
    row.sep = sep

    -- Hinterlegung fuer Gruppenkoepfe
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetAllPoints(row)
    bg:SetVertexColor(0.25, 0.20, 0.06, 0.55)
    bg:Hide()
    row.bg = bg

    row:SetScript("OnEnter", function()
      if this.itemID then
        this.hl:Show()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink("item:" .. this.itemID .. ":0:0:0")
        if GameTooltip:NumLines() < 2 then
          GameTooltip:ClearLines()
          BLL.UI:FallbackTooltip(GameTooltip, this.itemID)
        end
        if this.questID then
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine(BLL.L["QI_CLICK"], 1, 0.82, 0)
        end
        GameTooltip:Show()

      elseif this.enchant then
        this.hl:Show()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")

        -- Verzauberungen sind Zauber, keine Items. Der Client kennt
        -- dafuer "enchant:"-Verweise - falls das im jeweiligen Client
        -- nicht greift, bauen wir den Tooltip selbst.
        local ok = false
        if this.enchant.id then
          ok = pcall(function()
            GameTooltip:SetHyperlink("enchant:" .. this.enchant.id)
          end)
        end
        if not ok or GameTooltip:NumLines() < 2 then
          GameTooltip:ClearLines()
          BLL.UI:EnchantTooltip(GameTooltip, this.enchant)
        end
        if BLL.UI:PartnerAvailable() then
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine(BLL.locale == "deDE"
            and "Klick: Crafter in BananaRepublik anzeigen"
            or  "Click: show crafters in BananaRepublik", 0.4, 0.8, 1)
        end
        GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function()
      this.hl:Hide()
      GameTooltip:Hide()
    end)

    -- Verzauberung anklicken oeffnet BananaRepublik Partnerguild mit
    -- den Craftern aus Gilde und Partnergilde.
    row:SetScript("OnClick", function()
      if this.enchant then
        GameTooltip:Hide()
        BLL.UI:OpenCrafters(this.enchant)
      elseif this.itemID and IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
        local _, link = GetItemInfo(this.itemID)
        if link then ChatFrameEditBox:Insert(link) end
      elseif this.questID and BLL.QuestInfo then
        GameTooltip:Hide()
        BLL.QuestInfo:Show(this.questID, this.itemID)
      end
    end)

    row:Hide()
    pane.llRows[i] = row
  end


  -- Bildlaufleiste. Erscheint nur, wenn die Liste laenger als der
  -- sichtbare Bereich ist.
  local sb = CreateFrame("Slider", nil, pane)
  sb:SetOrientation("VERTICAL")
  sb:SetWidth(12)
  sb:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -6, -36)
  sb:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -6, 10)
  sb:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
  sb:SetMinMaxValues(1, 1)
  sb:SetValueStep(1)
  sb:SetValue(1)
  local track = sb:CreateTexture(nil, "BACKGROUND")
  track:SetTexture("Interface\\Buttons\\WHITE8X8")
  track:SetAllPoints(sb)
  track:SetVertexColor(0, 0, 0, 0.4)
  sb:SetScript("OnValueChanged", function()
    if pane.scrollLock then return end
    pane.offset = math.floor(this:GetValue() + 0.5)
    BLL.UI:RenderList()
  end)
  sb:EnableMouseWheel(true)
  sb:SetScript("OnMouseWheel", Wheel)
  sb:Hide()
  pane.scroll = sb

  pane:EnableMouseWheel(true)
  pane:SetScript("OnMouseWheel", Wheel)

  self.detail = pane

  local hint = (BLL.locale == "deDE")
    and "Slot links anklicken fuer Details."
    or  "Click a slot on the left for details."
  header:SetText("|cffffffff" .. hint .. "|r")
end

------------------------------------------------------------------
-- Listenansichten (Lootline, Verzauberung): gemeinsames Zeilenmodell
------------------------------------------------------------------

-- Masse der Listenzeilen. h = Rahmenhoehe, step = Abstand zur naechsten.
local LIST_TOP = 34
local H_HEAD, S_HEAD   = 26, 30
local H_ITEM, S_ITEM   = 26, 27
local H_ENCH, S_ENCH   = 38, 42

-- Listenansicht leeren. view merkt sich, welche Ansicht die Liste
-- fuellt: beim Wechsel beginnt sie wieder oben, bei einer
-- Aktualisierung derselben Ansicht bleibt die Position erhalten.
function UI:ResetList(view)
  local pane = self.detail
  pane.slotView:Hide()
  if pane.listView ~= view then pane.offset = 1 end
  pane.listView = view
  pane.list = {}

  -- Quellen-Dropdown im Wegplan; in "Pro Item" setzt ShowDetail ihn,
  -- bei den Verzauberungen hat er nichts zu filtern.
  if pane.sourceBtn then
    if view == "lootline" then
      pane.sourceBtn:SetText(self:SourceButtonText(true))
      pane.sourceBtn:Show()
    else
      pane.sourceBtn:Hide()
    end
  end
end

-- Eine Zeile aus ihrem Listeneintrag befuellen
function UI:FillRow(row, e)
  local pane = self.detail
  row.itemID = e.itemID
  row.questID = e.questID
  row.enchant = e.enchant
  row:SetHeight(e.h)

  if e.head then row.bg:Show() else row.bg:Hide() end
  if e.sep then row.sep:Show() else row.sep:Hide() end

  -- Icon: bei Items spaeter nachladen, sobald der Client es kennt
  local tex = e.icon
  if e.itemID and not tex then
    local _, _, _, _, _, _, _, _, t = GetItemInfo(e.itemID)
    tex = t
    if not tex then
      -- Der Client kennt die Textur nur fuer Gegenstaende, die er schon
      -- einmal gesehen hat. Gerade die, die man noch nicht hat, standen
      -- deshalb als Fragezeichen da. Der Import kennt sie.
      tex = BLL.ItemDB and BLL.ItemDB:IconPath(e.itemID)
    end
    if not tex then BLL.Scanner:GetLines(e.itemID) end
  end
  if tex then
    row.icon:SetTexture(tex)
    row.icon:Show()
  else
    row.icon:Hide()
  end

  local lx = e.head and 8 or 40
  local lw = e.head and 290 or 262
  local size = e.head and 15 or 13
  local outline = e.head and "OUTLINE" or nil

  row.leftText:ClearAllPoints()
  row.leftText:SetWidth(lw)
  if e.sub then
    row.leftText:SetPoint("TOPLEFT", row, "TOPLEFT", lx, -4)
    row.subText:ClearAllPoints()
    row.subText:SetPoint("TOPLEFT", row.leftText, "BOTTOMLEFT", 0, -3)
    row.subText:SetWidth(lw)
    FitText(pane.measure, row.subText, "|cff888888", e.sub, e.subPost or "|r", lw, 12)
    row.subText:Show()
  else
    row.leftText:SetPoint("LEFT", row, "LEFT", lx, 0)
    row.subText:SetText("")
    row.subText:Hide()
  end
  FitText(pane.measure, row.leftText, e.pre, e.core, e.post, lw, size, outline)

  SetFontSize(row.rightText, size, outline)
  row.rightText:SetText(e.right or "")
  row:Show()
end

-- Sichtbaren Ausschnitt der Liste zeichnen
function UI:RenderList()
  local pane = self.detail
  if not pane then return end
  local list = pane.list or {}
  local n = table.getn(list)
  local total = table.getn(pane.llRows)
  local avail = pane:GetHeight() - LIST_TOP - 10

  for i = 1, total do
    local row = pane.llRows[i]
    row:Hide()
    row.itemID = nil
    row.questID = nil
    row.enchant = nil
  end

  -- Groesster Startindex, bei dem das Listenende noch ganz sichtbar ist
  local maxOff, used = 1, 0
  local i = n
  while i >= 1 do
    if used + list[i].h > avail then break end
    used = used + list[i].step
    maxOff = i
    i = i - 1
  end
  if n == 0 then maxOff = 1 end

  local off = math.floor(pane.offset or 1)
  if off < 1 then off = 1 end
  if off > maxOff then off = maxOff end
  pane.offset = off

  local y, r = 0, 1
  for idx = off, n do
    local e = list[idx]
    if r > total or y + e.h > avail then break end
    local row = pane.llRows[r]
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", pane, "TOPLEFT", 10, -(LIST_TOP + y))
    self:FillRow(row, e)
    y = y + e.step
    r = r + 1
  end

  local sb = pane.scroll
  if maxOff > 1 then
    pane.scrollLock = true
    sb:SetMinMaxValues(1, maxOff)
    sb:SetValue(off)
    pane.scrollLock = nil
    sb:Show()
  else
    sb:Hide()
  end
end

------------------------------------------------------------------
-- Lootline: alle Verbesserungen nach Fundort
------------------------------------------------------------------

function UI:ShowLootline()
  local pane = self.detail
  self:ResetList("lootline")

  local progress = BLL.Candidates:Progress()
  if progress then
    pane.header:SetText("|cffffcc00" .. progress .. "|r")
    self:RenderList()
    return
  end

  if not BLL.Candidates.pool then
    pane.header:SetText(BLL.L["NO_ROUTE"])
    pane.header:SetTextColor(0.6, 0.6, 0.6)
    self:RenderList()
    return
  end

  local groups = BLL.Candidates:GetLootline(3)
  if not groups or table.getn(groups) == 0 then
    pane.header:SetText(BLL.locale == "deDE"
      and "Nichts Besseres gefunden" or "Nothing better found")
    pane.header:SetTextColor(0.6, 0.6, 0.6)
    self:RenderList()
    return
  end

  pane.header:SetText(BLL.locale == "deDE" and "Wohin es sich lohnt" or "Where to go")
  pane.header:SetTextColor(0.2, 0.8, 1)

  local list = pane.list
  for g = 1, table.getn(groups) do
    local grp = groups[g]
    local cat = CATEGORY_LABEL[grp.category or "WELT"] or CATEGORY_LABEL.WELT

    -- Stufenbereich der Instanz mit anzeigen. Orange, solange die
    -- Mindeststufe nicht erreicht ist.
    local lvl = ""
    if grp.lvlRange then
      local col = "|cff888888"
      local mn = tonumber(grp.minLevel)
      if mn and (BLL.player.level or 1) < mn then col = "|cffff8800" end
      lvl = "  " .. col .. grp.lvlRange .. "|r"
    end

    -- Kopf in einer Zeile: Etikett, Zone, Stufenbereich, Anzahl in
    -- Klammern. Reicht der Platz nicht, wird nur der Zonenname gekuerzt.
    table.insert(list, {
      head = true, sep = (g > 1), h = H_HEAD, step = S_HEAD,
      pre  = "|c" .. cat[2] .. "[" .. BLL.L[cat[1]] .. "]|r |cffffffff",
      core = grp.zone,
      post = "|r" .. lvl .. "  |cff888888(" .. table.getn(grp.items) .. ")|r",
      -- Erwarteter Zuwachs pro Besuch; kleine Werte mit Nachkommastelle,
      -- sonst stuende bei seltenen Drops ueberall 0.
      right = "|cff00ff00" .. string.format((grp.priority < 10) and "%.1f" or "%.0f", grp.priority) .. "|r",
    })

    for i = 1, table.getn(grp.items) do
      local it = grp.items[i]
      local qc = QC(it.quality)
      local hex = string.format("|cff%02x%02x%02x", qc[1] * 255, qc[2] * 255, qc[3] * 255)

      local tag = ""
      if it.locked then
        tag = "|cffff8800ab " .. (it.reqLevel or "?") .. "|r  "
      end
      if it.learnSkill then
        tag = tag .. "|cffff8800" .. (BLL.locale == "deDE" and "lernen" or "train") .. "|r  "
      end

      -- Questbelohnungen kenntlich machen. Eine Dropchance waere dort
      -- irrefuehrend: die Belohnung ist sicher.
      local chance
      if it.stype == "Q" then
        chance = "  |cffffd100"
          .. (it.questLevel and string.format(BLL.L["QUEST_LEVEL"], it.questLevel)
              or BLL.L["QUEST"]) .. "|r"
        if it.choiceOf then
          local c = it.choiceBest and "|cffffd100" or "|cff888888"
          chance = chance .. c .. " (" .. string.format(BLL.L["QUEST_ONE_OF"], it.choiceOf) .. ")|r"
        end
      elseif it.chance then
        chance = " |cff888888" .. (BLL:FormatChance(it.chance)
          or "") .. "|r"
      else
        chance = ""
      end

      -- Elite, Boss und seltene Gegner kenntlich machen. "Forest
      -- Leather Gloves" fallen zu 1,6 % von Humar the Pridelord, einem
      -- seltenen Elitegegner auf Stufe 23. Als blosse Prozentzahl liest
      -- sich das wie ein gewoehnlicher Drop, und ein Stufe-15-Jaeger
      -- laeuft allein los.
      local mark = it.elite and BLL:EliteLabel(it.elite)
      if mark then
        chance = chance .. " |cffff8800" .. mark .. "|r"
      end

      local right
      if it.pct then
        local p = it.pct
        local txt = (p >= 1000) and (">999%") or string.format("+%.0f%%", p)
        right = "|cff00ff00" .. txt .. "|r"
      else
        right = "|cff44ff44" .. BLL.L["NEW_SLOT"] .. "|r"
      end

      table.insert(list, {
        itemID = it.id, h = H_ITEM, step = S_ITEM,
        questID = it.questID,
        pre  = "|cff888888" .. it.slotName .. "|r  " .. tag .. hex,
        core = it.name or "?",
        post = "|r" .. chance,
        right = right,
      })
    end
  end

  self:RenderList()
end

------------------------------------------------------------------
-- Verzauberungen
------------------------------------------------------------------

------------------------------------------------------------------
-- Bruecke zu BananaRepublik Partnerguild
--
-- Das Partner-Addon stellt BRPP_API bereit (ab 2.1.0). Fehlt es,
-- zeigt die Liste keine Crafter und der Klick meldet das im Chat.
-- Die Zuordnung laeuft ueber den Rezeptnamen: Verzauberungen haben
-- dort keine Item- oder Spell-ID.
------------------------------------------------------------------

function UI:PartnerAvailable()
  return type(BRPP_API) == "table" and type(BRPP_API.ShowRecipe) == "function"
end

-- Anzahl Crafter und davon online, oder nil ohne Partner-Addon
function UI:CrafterCount(name)
  if not self:PartnerAvailable() or not BRPP_API.GetCrafters then return nil end
  local ok, total, online = pcall(BRPP_API.GetCrafters, name)
  if not ok then return nil end
  return total or 0, online or 0
end

function UI:OpenCrafters(e)
  local de = (BLL.locale == "deDE")
  if not self:PartnerAvailable() then
    BLL:Print(de and "BananaRepublik Partnerguild ist nicht installiert oder zu alt (ab 2.1.0)."
                  or "BananaRepublik Partnerguild is not installed or too old (2.1.0+).")
    return
  end
  local ok, found = pcall(BRPP_API.ShowRecipe, e.name)
  if not ok then
    BLL:Print(de and "BananaRepublik meldet einen Fehler." or "BananaRepublik reported an error.")
  elseif not found then
    BLL:Print((de and "Niemand in Gilde oder Partnergilde kann " or "Nobody in guild or partner guild knows ")
      .. "|cffffffff" .. (e.name or "?") .. "|r.")
  end
end

function UI:ShowEnchants()
  local pane = self.detail
  self:ResetList("enchant")

  if not BLL.EnchantDB or not BLL.EnchantDB.loaded then
    pane.header:SetText(BLL.locale == "deDE"
      and "Keine Verzauberungsdaten" or "No enchant data")
    pane.header:SetTextColor(0.6, 0.6, 0.6)
    self:RenderList()
    return
  end

  pane.header:SetText(BLL.locale == "deDE"
    and "Sinnvolle Verzauberungen" or "Useful enchants")
  pane.header:SetTextColor(0.2, 0.8, 1)

  local list = pane.list
  local groups = BLL.EnchantDB:GetAll(3)

  for g = 1, table.getn(groups or {}) do
    local grp = groups[g]
    table.insert(list, {
      head = true, sep = (g > 1), h = H_HEAD, step = S_HEAD,
      pre  = "|cffffd100",
      core = grp.slotName,
      post = "|r" .. (grp.empty and ("  |cff888888("
          .. (BLL.locale == "deDE" and "Slot leer" or "empty") .. ")|r") or ""),
      right = "",
    })

    for i = 1, table.getn(grp.items) do
      local e = grp.items[i]
      local lock = e.locked and ("|cffff8800ab " .. e.req .. "|r  ") or ""

      -- Wer kann das verzaubern? Nur mit BananaRepublik Partnerguild.
      -- Die Anzahl steht hinter den Werten und wird nie gekuerzt.
      local subPost = "|r"
      local total, online = self:CrafterCount(e.name)
      if total then
        if total > 0 then
          subPost = "|r  |cff66ccff" .. total .. " Crafter|r"
            .. (online > 0 and ("|cff00ff00 (" .. online .. " online)|r") or "")
        else
          subPost = "|r  |cff666666" .. (BLL.locale == "deDE" and "kein Crafter" or "no crafter") .. "|r"
        end
      end

      table.insert(list, {
        enchant = e, h = H_ENCH, step = S_ENCH,
        icon = PROFESSION_ICON[e.src or ""] or QUESTION_MARK,
        pre  = lock .. "|cffffffff",
        core = e.name,
        post = "|r",
        sub  = EnchantStatText(e.stats or {}),
        subPost = subPost,
        right = "|cff00ff00" .. string.format("%.1f", e.score) .. "|r",
      })
    end
  end

  if table.getn(list) == 0 then
    pane.header:SetText(BLL.locale == "deDE"
      and "Nichts Sinnvolles gefunden" or "Nothing useful found")
  end

  self:RenderList()
end

function UI:RenderDetail()
  if self.viewMode == "lootline" then
    self:ShowLootline()
  elseif self.viewMode == "enchant" then
    self:ShowEnchants()
  else
    self:ShowDetail(self.selectedSlot or "HeadSlot")
  end
end

function UI:ShowDetail(slotKey)
  local pane = self.detail
  local sv = pane.slotView
  for i = 1, table.getn(pane.llRows or {}) do
    pane.llRows[i]:Hide()
  end
  if pane.scroll then pane.scroll:Hide() end
  pane.listView = nil
  if pane.sourceBtn then
    pane.sourceBtn:SetText(self:SourceButtonText(false))
    pane.sourceBtn:Show()
  end
  -- Auch die Daten wegraeumen, nicht nur die Zeilen verstecken. Sonst
  -- kann jeder spaetere RenderList-Aufruf die alte Liste wieder
  -- hervorholen.
  pane.list = {}
  pane.header:SetText("")
  sv:Show()

  local measure = pane.measure
  local data = BLL.Gear.equipped[slotKey]

  ----------------------------------------------------------------
  -- Bereich 1: angelegtes Teil
  ----------------------------------------------------------------
  local cur = sv.cur
  cur.slotID = GetInventorySlotInfo(slotKey)
  cur.hasItem = (data ~= nil)

  if data then
    local c = QC(data.quality)
    local hex = string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
    FitText(measure, cur.name, hex, data.name or "?", "|r", 308, 16, "OUTLINE")

    local tex = cur.slotID and GetInventoryItemTexture("player", cur.slotID)
    cur.icon:SetTexture(tex or QUESTION_MARK)
    if (data.quality or 1) > 1 then
      cur.border:SetVertexColor(c[1], c[2], c[3])
      cur.border:Show()
    else
      cur.border:Hide()
    end

    local parts = {}
    for i = 1, table.getn(BLL.STATS) do
      local k = BLL.STATS[i]
      local v = data.stats[k]
      if v and k ~= "WEAPON_MIN" and k ~= "WEAPON_MAX" then
        local shown = (k == "WEAPON_SPEED" or k == "WEAPON_DPS") and string.format("%.1f", v) or v
        local sign = (v < 0) and "" or "+"
        if k == "WEAPON_SPEED" then sign = "" end
        table.insert(parts, "|cff00ff00" .. sign .. shown .. "|r |cffaaaaaa" .. StatLabel(k) .. "|r")
      end
    end
    local statLine
    if table.getn(parts) == 0 then
      statLine = "|cff888888"
        .. (BLL.locale == "deDE" and "keine Werte" or "no stats") .. "|r"
    else
      statLine = (JoinFit(measure, parts, 308, 12, 2))
    end
    -- Ein Teil kann stark sein, ohne dass ein Wert im Tooltip steht.
    -- Genau dann gehoert der Vermerk hierhin, damit "keine Werte" nicht
    -- als "wertlos" gelesen wird.
    if data.unscored then
      statLine = statLine .. "  |cffff8800(" .. BLL.L["UNSCORED_EQUIPPED"] .. ")|r"
    end
    cur.stats:SetText(statLine)
  else
    cur.icon:SetTexture(SlotBackdrop(slotKey))
    cur.border:Hide()
    FitText(measure, cur.name, "|cff888888", BLL.L["EMPTY"], "|r", 308, 16, "OUTLINE")
    cur.stats:SetText("")
  end

  ----------------------------------------------------------------
  -- Bereich 2: Upgrades
  ----------------------------------------------------------------
  for i = 1, table.getn(pane.rows) do
    pane.rows[i]:Hide()
    pane.rows[i].itemID = nil
    pane.rows[i].questID = nil
  end
  sv.status:SetText("")
  sv.secUp.right:SetText("")

  local progress = BLL.Candidates:Progress()
  if progress then
    sv.status:SetText("|cffffcc00" .. progress .. "|r")
    return
  end

  if not BLL.Candidates.pool then
    sv.status:SetText("|cff888888"
      .. (BLL.locale == "deDE"
          and "Noch keine Kandidaten.\nUnten auf \"Upgrades suchen\" klicken."
          or  "No candidates yet.\nClick \"Find upgrades\" below.") .. "|r")
    return
  end

  -- Standard: nur Teile, zu denen eine erreichbare Quelle bekannt ist.
  -- Ohne Haken auch die ohne Fundort (Altlasten der Datenbank, Teile
  -- ausser Reichweite).
  local accept = BLL.Candidates.SlotViewAccept and BLL.Candidates:SlotViewAccept() or nil
  local scan = accept and BLL.Candidates.LOOTLINE_SCAN or nil
  local ups = BLL.Candidates:GetUpgrades(slotKey, table.getn(pane.rows), accept, scan)
  local n = table.getn(ups or {})
  if n == 0 then
    local nothing = "|cff888888"
      .. (BLL.locale == "deDE" and "Nichts Besseres in deinem Stufenbereich."
                               or  "Nothing better in your level range.") .. "|r"
    -- Liegt es am unbezifferbaren Effekt des angelegten Teils, dann sagen
    -- wir das. "Nichts Besseres" allein waere hier irrefuehrend: es gab
    -- Kandidaten, sie waren nur nicht deutlich genug vorne.
    if data and data.unscored then
      nothing = nothing .. "\n|cffff8800" .. BLL.L["UNSCORED_HINT"] .. "|r"
    end
    sv.status:SetText(nothing)
    return
  end
  sv.secUp.right:SetText("|cff888888" .. n
    .. (BLL.locale == "deDE" and " gefunden" or " found") .. "|r")

  local SKIP_DIFF = { WEAPON_MIN = true, WEAPON_MAX = true }
  local weights = BLL.Weights:Get()
  local de = (BLL.locale == "deDE")

  for i = 1, n do
    local u = ups[i]
    local row = pane.rows[i]
    row.itemID = u.id
    -- Questbelohnung: Klick zeigt die Questreihe
    local s1 = u.sources and u.sources[1]
    row.questID = (s1 and s1.stype == "Q") and s1.id or nil

    local qc = QC(u.quality)
    local hex = string.format("|cff%02x%02x%02x", qc[1] * 255, qc[2] * 255, qc[3] * 255)

    -- Zeile 1: Name und Wert. Unter 10 mit Nachkommastelle, sonst
    -- erscheint 1,9 als 2.
    FitText(measure, row.name, hex, u.name or ("Item " .. u.id), "|r", 246, 15)
    local gainTxt = (u.gain < 10) and string.format("%.1f", u.gain)
                                   or string.format("%.0f", u.gain)
    row.value:SetText("|cff00ff00+" .. gainTxt .. "|r")

    -- Zeile 2: die wichtigsten Wertaenderungen nach Gewicht, dazu Set-
    -- und Use-Anteil. Minimum und Maximum einer Waffe sagt DPS besser.
    local ranked = {}
    if u.diff then
      for k, d in pairs(u.diff) do
        if not SKIP_DIFF[k] then
          table.insert(ranked, { k = k, d = d, w = math.abs(d * (weights[k] or 0)) })
        end
      end
    end
    table.sort(ranked, function(x, y) return x.w > y.w end)

    local parts = {}
    if u.twoHand then table.insert(parts, "|cffff8800[2H]|r") end
    for j = 1, table.getn(ranked) do
      local e = ranked[j]
      local shown = e.d
      if e.k == "WEAPON_SPEED" or e.k == "WEAPON_DPS" then
        shown = string.format("%.1f", e.d)
      end
      if e.d > 0 then
        table.insert(parts, "|cff44ff44+" .. shown .. " " .. StatLabel(e.k) .. "|r")
      else
        table.insert(parts, "|cffff5555" .. shown .. " " .. StatLabel(e.k) .. "|r")
      end
    end
    if u.setScore and u.setScore > 0 and u.setInfo then
      table.insert(parts, "|cffffcc00Set " .. u.setInfo.pieces .. "er +"
        .. string.format("%.0f", u.setScore) .. "|r")
    end
    if u.useScore and u.useScore > 0 then
      table.insert(parts, "|cff88ccffUse +" .. string.format("%.0f", u.useScore)
        .. (u.estimated and (de and " gesch." or " est.") or "") .. "|r")
    end
    row.diffText:SetText((JoinFit(measure, parts, 312, 12, 1, "  ")))

    -- Zeile 3: Fundort. Gekuerzt wird nur der Name der Quelle, Chance
    -- und Zone bleiben stehen.
    local lock = u.locked
      and ("|cffff8800" .. (de and "ab " or "lvl ") .. (u.reqLevel or "?")
           .. (u.dualWield and (de and " Beidhaendig" or " dual wield") or "") .. "|r  ") or ""
    -- Fehlende Waffenfertigkeit: beim Waffenmeister lernbar
    if u.learnSkill then
      lock = lock .. "|cffff8800" .. (de and "Waffenmeister" or "weapon master") .. "|r  "
    end
    -- Verglichen wurde gegen ein Teil mit unbeziffertem Effekt. Der
    -- Vorsprung ist echt, aber nicht der ganze Vergleich.
    if u.incomplete then
      lock = lock .. "|cffff8800" .. BLL.L["UNSCORED_SHORT"] .. "|r  "
    end
    -- Nur sichtbar, solange /bll locked eingeschaltet ist: sonst stehen
    -- diese Teile gar nicht in der Liste.
    if u.lockedBy then
      lock = lock .. "|cffff0000" .. BLL.L["LOCKED_ITEM"] .. "|r  "
    end
    if u.sources and table.getn(u.sources) > 0 then
      local src = u.sources[1]
      local pre, post = lock .. "|cffcccccc", "|r"
      if src.stype == "Q" then
        pre = lock .. "|cffffd100Quest:|r |cffcccccc"
        if src.questLevel then post = post .. "  |cff888888" .. (de and "Stufe " or "level ") .. src.questLevel .. "|r" end
      elseif src.stype == "V" then
        pre = lock .. "|cff40c040" .. (de and "Haendler:" or "Vendor:") .. "|r |cffcccccc"
      elseif src.chance then
        post = post .. "  |cffffffff"
          .. (BLL:FormatChance(src.chance) or "") .. "|r"
      end
      -- Elite und Boss bedeuten Gruppe. Das gehoert an die Quelle, sonst
      -- laeuft man allein zu einem Gegner, den man nicht umbringt.
      local elite = src.elite and BLL:EliteLabel(src.elite)
      if elite then post = post .. "  |cffff8800" .. elite .. "|r" end
      if src.zone then post = post .. "  |cff888888" .. src.zone .. "|r" end
      FitText(measure, row.srcText, pre, src.name or "?", post, 312, 12)
    else
      -- Zwei verschiedene Faelle: ein Item aus dem Import hat noch nie
      -- einen Fundort gehabt, bei einem pfQuest-Item fehlen die Daten.
      row.srcText:SetText(lock .. "|cff666666"
        .. (u.fromImport and BLL.L["NO_LOCATION_YET"] or BLL.L["NO_SOURCE"]) .. "|r")
    end

    local _, _, _, _, _, _, _, _, tex = GetItemInfo(u.id)
    if not tex then tex = BLL.ItemDB and BLL.ItemDB:IconPath(u.id) end
    if tex then
      row.icon:SetTexture(tex)
      if u.quality and u.quality > 1 then
        row.border:SetVertexColor(qc[1], qc[2], qc[3])
        row.border:Show()
      else
        row.border:Hide()
      end
    else
      row.icon:SetTexture(QUESTION_MARK)
      row.border:Hide()
      -- Serverabfrage anstossen, damit Icon und Tooltip bereitstehen
      BLL.Scanner:GetLines(u.id)
    end

    if i == n then row.sep:Hide() else row.sep:Show() end
    row:Show()
  end
end

------------------------------------------------------------------
-- Tooltip fuer eine Verzauberung
------------------------------------------------------------------

function UI:EnchantTooltip(tip, e)
  tip:AddLine(e.name or "?", 1, 1, 1)

  if e.src then
    tip:AddLine("|cff888888" .. e.src .. "|r")
  end
  if e.req then
    tip:AddLine("|cff888888"
      .. ((BLL.locale == "deDE") and "Benoetigt Itemstufe " or "Requires item level ")
      .. e.req .. "|r")
  end

  tip:AddLine(" ")
  for i = 1, table.getn(BLL.STATS) do
    local k = BLL.STATS[i]
    local v = e.stats and e.stats[k]
    if v then
      local shown = (k == "WEAPON_DPS") and string.format("%.1f", v) or v
      tip:AddLine("+" .. shown .. " " .. k, 0.1, 1, 0.1)
    end
  end

  if e.rawDmg then
    tip:AddLine("|cff888888"
      .. ((BLL.locale == "deDE") and "Grundlage: +" or "Based on: +")
      .. e.rawDmg .. " "
      .. ((BLL.locale == "deDE") and "Schaden, umgerechnet ueber das Waffentempo"
                                  or "damage, converted via weapon speed") .. "|r")
  end

  tip:AddLine("|cff666666" .. string.format("%.1f", e.score or 0) .. " "
    .. ((BLL.locale == "deDE") and "Punkte fuer deine Werte" or "points for your weights") .. "|r")
end

------------------------------------------------------------------
-- Ersatztooltip aus den importierten Daten
--
-- Greift, solange der Server das Item noch nicht geliefert hat. Der
-- Aufruf oben stoesst die Abfrage an, beim naechsten Anfahren steht
-- dann der echte Tooltip.
------------------------------------------------------------------

function UI:FallbackTooltip(tip, itemID)
  local e = BLL.ItemDB and BLL.ItemDB:Get(itemID)
  if not e then
    tip:AddLine("Item " .. itemID)
    tip:AddLine("|cff888888Daten werden geladen ...|r")
    return
  end

  local qc = QC(e.quality)
  tip:AddLine(e.name or ("Item " .. itemID), qc[1], qc[2], qc[3])

  if e.ilvl then
    tip:AddLine("|cff888888Itemlevel " .. e.ilvl .. "|r")
  end
  if e.reqlevel then
    tip:AddLine("|cff888888" .. string.format(BLL.L["REQ_LEVEL"], e.reqlevel) .. "|r")
  end

  if e.stats then
    for i = 1, table.getn(BLL.STATS) do
      local k = BLL.STATS[i]
      local v = e.stats[k]
      if v then
        local sign = (v < 0) and "" or "+"
        tip:AddLine(sign .. v .. " " .. k, 0.1, 1, 0.1)
      end
    end
  end

  if e.use then
    for i = 1, table.getn(e.use) do
      tip:AddLine("Anlegen/Benutzen: " .. (e.use[i].t or ""), 0.1, 1, 0.1)
    end
  end

  local setID, set = BLL.SetDB and BLL.SetDB:GetSetOf(itemID)
  if set then
    tip:AddLine(" ")
    tip:AddLine(set.name, 1, 0.82, 0)
    local worn = BLL.SetDB:CountEquipped(setID)
    for i = 1, table.getn(set.bonuses) do
      local b = set.bonuses[i]
      if worn >= b.p then
        tip:AddLine("(" .. b.p .. ") " .. (b.t or ""), 0.1, 1, 0.1)
      else
        tip:AddLine("(" .. b.p .. ") " .. (b.t or ""), 0.5, 0.5, 0.5)
      end
    end
  end

  tip:AddLine("|cff666666aus der BananaLootline-Datenbank|r")
end

------------------------------------------------------------------
-- Die frueher hier stehende Summenzeile ist entfallen. Sie zeigte die
-- aus den Tooltips gelesenen Itemwerte, das Statfeld unter der Puppe
-- zeigt die echten Charakterwerte - zwei verschiedene Zahlen fuer
-- dieselbe Sache nebeneinander stiften nur Verwirrung.
------------------------------------------------------------------

------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------

function UI:Refresh()
  if not self.frame then return end

  for key, b in pairs(self.slotButtons or {}) do
    local data = BLL.Gear.equipped[key]
    local tex = b.slotID and GetInventoryItemTexture("player", b.slotID)

    if tex then
      b.icon:SetTexture(tex)
      b.icon:SetAlpha(1)
      local q = data and data.quality
      if q and q > 1 then
        local c = QC(q)
        b.border:SetVertexColor(c[1], c[2], c[3])
        b.border:Show()
      else
        b.border:Hide()
      end
    else
      -- Leerer Slot: Platzhalterbild wie im Charakterfenster, gedimmt
      b.icon:SetTexture(SlotBackdrop(key))
      b.icon:SetAlpha(0.45)
      b.border:Hide()
    end
  end

  local p = BLL.player or {}
  -- Gewichte einmal abrufen, damit die Spezialisierung frisch erkannt ist
  BLL.Weights:Get()
  local spec = BLL.Weights.activeSpec

  self.frame.subtitle:SetText(
    (p.name or "?") .. "  -  " .. (BLL.locale == "deDE" and "Stufe " or "Level ")
    .. (p.level or 0) .. " " .. (p.class or "?")
    .. (spec and ("  |cffffcc00" .. spec .. "|r"
          .. (BLL.Weights.specManual and ("|cff888888 (" .. BLL.L["SPEC_MANUAL"] .. ")|r") or "")
          .. (BLL.Weights.customWeights and ("|cffff8800 (" .. BLL.L["CUSTOM_WEIGHTS"] .. ")|r") or "")) or
        ("  |cff888888(" .. BLL.L["NO_SPEC"] .. ")|r"))
    .. (BLL.Sources.available and "" or ("   |cffff8800(" .. BLL.L["NO_PFQUEST_SHORT"] .. ")|r"))
  )

  self:UpdateSelection()
  self:UpdateViewButtons()
  self:UpdateAhead()
  if BLL.Extras then BLL.Extras:Refresh() end
  self:UpdateStatsPanel()
  self:RefreshModel()

  self:RenderDetail()
end

------------------------------------------------------------------
-- Toggle
------------------------------------------------------------------

function UI:Toggle()
  if not self.frame then self:Init() end
  if self.frame:IsVisible() then
    self.frame:Hide()
  else
    BLL.Gear:ScanEquipped()
    self.frame:Show()
    -- Erst zeigen, dann Refresh: das Modell wird sonst nicht gezeichnet.
    self:Refresh()
  end
end
