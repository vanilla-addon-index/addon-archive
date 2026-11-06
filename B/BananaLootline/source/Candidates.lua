--[[----------------------------------------------------------------------
  BananaLootline - Candidates.lua

  Hier entstehen die eigentlichen Vorschlaege. Drei Schritte:

  1. POOL BAUEN
     Ueber pfDB["items"]["data"] laufen und fuer jedes Item die Stufe seiner
     Quelle bestimmen. Units haben ["lvl"] = "24-25", Quests haben ["lvl"].
     Was von einer Quelle im eigenen Stufenbereich kommt, ist ein Kandidat.
     Das ist der Trick, der uns die Itemdatenbank vorerst erspart: wir
     brauchen keine Itemwerte, um zu entscheiden, WELCHE Items ueberhaupt
     interessant sind.

  2. DATEN HOLEN
     Fuer die Kandidaten Slot, Qualitaet und Werte besorgen. Ist ein Item
     nicht im Clientcache, stoesst der Tooltip-Aufruf eine Serverabfrage an
     und beim naechsten Durchlauf sind die Daten da. Streng gedrosselt -
     zu schnelle Abfragen quittiert der 1.12-Server mit Disconnect.
     Ergebnis landet in BananaLootlineDB.itemcache und ueberlebt Reloads,
     der Aufwand faellt also einmal pro Stufenbereich an.

  3. BEWERTEN
     Kandidaten pro Slot gegen das angelegte Item scoren (Weights.lua) und
     die besseren mit Quelle ausgeben.
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline
BLL.Candidates = {}
local Cand = BLL.Candidates

-- BLL.L bleibt beim Sprachwechsel dieselbe Tabelle, nur ihr Inhalt wird
-- ausgetauscht. Eine lokale Referenz darauf ist deshalb sicher und zeigt
-- nach einem Wechsel auf die neuen Texte.
local L = BLL.L

-- Hochzaehlen, wenn sich aendert, WELCHE Felder ein Cache-Eintrag braucht.
-- Eintraege aelterer Fassungen werden dann beim naechsten Lauf neu
-- aufgebaut, statt stillschweigend mit fehlenden Feldern weiterzulaufen.
-- 3: Scanner liest RAP, Verteidigung und Schulschaden jetzt richtig.
-- 4: Dauerhafte Aussortier-Markierungen werden neu bewertet.
-- 5: Zugangsbedingungen (Ruf, PvP-Rang) werden mitgelesen. Aeltere
--    Eintraege kennen das Feld nicht und wuerden solche Teile weiter
--    vorschlagen, also muessen sie neu eingelesen werden.
-- Aeltere Eintraege werden verworfen und neu eingelesen.
Cand.CACHE_VERSION = 6

Cand.pool     = nil     -- [itemID] = sourceLevel
Cand.poolSize = 0
Cand.state    = "idle"  -- idle | indexing | querying | ready

------------------------------------------------------------------
-- Slotzuordnung
------------------------------------------------------------------

-- INVTYPE aus GetItemInfo -> unsere Slotkeys (Ringe/Schmuck/Waffen
-- passen in mehrere).
Cand.INVTYPE_SLOTS = {
  ["INVTYPE_HEAD"]            = { "HeadSlot" },
  ["INVTYPE_NECK"]            = { "NeckSlot" },
  ["INVTYPE_SHOULDER"]        = { "ShoulderSlot" },
  ["INVTYPE_CLOAK"]           = { "BackSlot" },
  ["INVTYPE_CHEST"]           = { "ChestSlot" },
  ["INVTYPE_ROBE"]            = { "ChestSlot" },
  ["INVTYPE_WRIST"]           = { "WristSlot" },
  ["INVTYPE_HAND"]            = { "HandsSlot" },
  ["INVTYPE_WAIST"]           = { "WaistSlot" },
  ["INVTYPE_LEGS"]            = { "LegsSlot" },
  ["INVTYPE_FEET"]            = { "FeetSlot" },
  ["INVTYPE_FINGER"]          = { "Finger0Slot", "Finger1Slot" },
  ["INVTYPE_TRINKET"]         = { "Trinket0Slot", "Trinket1Slot" },
  ["INVTYPE_WEAPON"]          = { "MainHandSlot", "SecondaryHandSlot" },
  ["INVTYPE_2HWEAPON"]        = { "MainHandSlot" },
  ["INVTYPE_WEAPONMAINHAND"]  = { "MainHandSlot" },
  ["INVTYPE_WEAPONOFFHAND"]   = { "SecondaryHandSlot" },
  ["INVTYPE_SHIELD"]          = { "SecondaryHandSlot" },
  ["INVTYPE_HOLDABLE"]        = { "SecondaryHandSlot" },
  ["INVTYPE_RANGED"]          = { "RangedSlot" },
  ["INVTYPE_RANGEDRIGHT"]     = { "RangedSlot" },
  ["INVTYPE_THROWN"]          = { "RangedSlot" },
  ["INVTYPE_RELIC"]           = { "RangedSlot" },
}

-- Der Wert sagt Weights:Score, ob Nah- oder Fernkampf: Jaeger gewichten
-- die Waffen-DPS der Nahkampfhand viel schwaecher als die des Bogens.
local WEAPON_SLOTS = {
  ["MainHandSlot"] = "melee", ["SecondaryHandSlot"] = "melee", ["RangedSlot"] = "ranged",
}

------------------------------------------------------------------
-- Ruestungsarten
--
-- GetItemInfo liefert den Subtyp lokalisiert, deshalb pro Sprache.
-- Unbekannter Subtyp wird durchgelassen statt verworfen - lieber ein
-- Vorschlag zu viel als ein fehlender.
------------------------------------------------------------------

local ARMOR_NAMES = {
  enUS = { CLOTH = "Cloth", LEATHER = "Leather", MAIL = "Mail", PLATE = "Plate", SHIELD = "Shields" },
  deDE = { CLOTH = "Stoff", LEATHER = "Leder", MAIL = "Schwere R\195\188stung", PLATE = "Plattenpanzer", SHIELD = "Schilde" },
}

local function ArmorKey(subtype)
  if not subtype then return nil end
  -- Clientsprache, nicht Anzeigesprache: GetItemInfo liefert die
  -- Ruestungsart in der Sprache des Clients.
  local map = ARMOR_NAMES[BLL.clientLocale] or ARMOR_NAMES.enUS
  for key, name in pairs(map) do
    if subtype == name then return key end
  end
  return nil
end

-- Ruestungskompetenzen. Kettenruestung gibt es fuer Jaeger und Schamanen
-- erst ab Stufe 40, Platte fuer Krieger und Paladine ebenfalls.
local function AllowedArmor(class, level)
  if class == "WARRIOR" or class == "PALADIN" then
    if level >= 40 then
      return { CLOTH = 1, LEATHER = 1, MAIL = 1, PLATE = 1, SHIELD = 1 }
    end
    return { CLOTH = 1, LEATHER = 1, MAIL = 1, SHIELD = 1 }
  elseif class == "HUNTER" or class == "SHAMAN" then
    local t = { CLOTH = 1, LEATHER = 1 }
    if level >= 40 then t.MAIL = 1 end
    if class == "SHAMAN" then t.SHIELD = 1 end
    return t
  elseif class == "ROGUE" or class == "DRUID" then
    return { CLOTH = 1, LEATHER = 1 }
  end
  return { CLOTH = 1 }   -- Priester, Magier, Hexenmeister
end

-- Die Ruestungsart, die eine Klasse eigentlich traegt: die schwerste,
-- die sie kann. Ein Jaeger darf Stoff tragen, will aber keine Stoffrobe
-- vorgeschlagen bekommen - gemeldet von einem BM-Jaeger auf Stufe 38,
-- dem die "Stormreaver Robe" (Ausdauer, Intelligenz, Zauberschaden) als
-- Brust-Upgrade erschien. Die Ruestungspunkte sind zu schwach gewichtet,
-- als dass der Abstand zu Leder das ausgleicht.
local function PreferredArmor(class, level)
  if class == "WARRIOR" or class == "PALADIN" then
    if level >= 40 then return { PLATE = 1, SHIELD = 1 } end
    return { MAIL = 1, SHIELD = 1 }
  elseif class == "HUNTER" then
    if level >= 40 then return { MAIL = 1 } end
    return { LEATHER = 1 }
  elseif class == "SHAMAN" then
    if level >= 40 then return { MAIL = 1, SHIELD = 1 } end
    return { LEATHER = 1, SHIELD = 1 }
  elseif class == "ROGUE" or class == "DRUID" then
    return { LEATHER = 1 }
  end
  return { CLOTH = 1 }
end

-- Leichtere Ruestung zeigen? Pro Charakter, Standard aus.
function Cand:ShowLighterArmor()
  return BananaLootlineChar and BananaLootlineChar.lighterArmor and true or false
end

function Cand:SetShowLighterArmor(on)
  BananaLootlineChar = BananaLootlineChar or {}
  BananaLootlineChar.lighterArmor = on and true or nil
end

-- Ruestungsarten fuer Vorschlaege: nur die eigene, ausser der Spieler
-- will auch leichtere sehen. Fuer das Vorsortieren der Anfragen bleibt
-- AllowedArmor zustaendig, damit das Umschalten keine neue Suche braucht.
function Cand:SuggestArmor(class, level)
  if self:ShowLighterArmor() then return AllowedArmor(class, level) end
  return PreferredArmor(class, level)
end

------------------------------------------------------------------
-- Waffenkompetenzen
--
-- Der Ruestungsfilter allein reicht nicht: ein Zauberstab landet im
-- Distanzslot und wurde deshalb einem Jaeger vorgeschlagen, obwohl er
-- ihn nie fuehren kann. Dasselbe haette einem Magier eine Streitaxt
-- empfohlen.
--
-- Subklassen der Itemklasse 2, wie im Menue der Datenbank:
--   0 Einhandaxt   1 Zweihandaxt  2 Bogen        3 Schusswaffe
--   4 Einhandkolben 5 Zweihandkolben 6 Stangenwaffe
--   7 Einhandschwert 8 Zweihandschwert 10 Stab
--  13 Faustwaffe   14 Sonstiges   15 Dolch       16 Wurfwaffe
--  18 Armbrust     19 Zauberstab  20 Angelrute
------------------------------------------------------------------

local WEAPON_PROFICIENCY = {
  WARRIOR = { [0]=1,[1]=1,[2]=1,[3]=1,[4]=1,[5]=1,[6]=1,[7]=1,[8]=1,
              [10]=1,[13]=1,[14]=1,[15]=1,[16]=1,[18]=1,[20]=1 },
  PALADIN = { [0]=1,[1]=1,[4]=1,[5]=1,[6]=1,[7]=1,[8]=1,[14]=1,[20]=1 },
  HUNTER  = { [0]=1,[1]=1,[2]=1,[3]=1,[6]=1,[7]=1,[8]=1,[10]=1,
              [13]=1,[14]=1,[15]=1,[16]=1,[18]=1,[20]=1 },
  -- Keine Einhandaexte: Icy Veins nennt fuer Schurken Dolche, Faust-
  -- waffen, Schwerter, Streitkolben sowie Bogen, Armbrust, Schusswaffe
  -- und Wurfwaffe.
  ROGUE   = { [2]=1,[3]=1,[4]=1,[7]=1,[13]=1,[14]=1,[15]=1,
              [16]=1,[18]=1,[20]=1 },
  PRIEST  = { [4]=1,[10]=1,[14]=1,[15]=1,[19]=1,[20]=1 },
  -- Keine Faustwaffen: Wowhead nennt fuer Classic-Schamanen Ein- und
  -- Zweihandaexte und -kolben, Dolche und Staebe. Zweihandaexte und
  -- -kolben (1, 5) gibt es nur ueber ein Verstaerkungstalent - siehe
  -- TALENT_WEAPON.
  SHAMAN  = { [0]=1,[1]=1,[4]=1,[5]=1,[10]=1,[14]=1,[15]=1,[20]=1 },
  MAGE    = { [7]=1,[10]=1,[14]=1,[15]=1,[19]=1,[20]=1 },
  WARLOCK = { [7]=1,[10]=1,[14]=1,[15]=1,[19]=1,[20]=1 },
  DRUID   = { [4]=1,[5]=1,[6]=1,[10]=1,[13]=1,[14]=1,[15]=1,[20]=1 },
}

-- Ab welcher Stufe eine Klasse Beidhaendigkeit beim Klassenlehrer
-- lernen kann. Quelle: Allakhazam-Wiki "Dual Wield (WoW)": Schurken 10,
-- Krieger und Jaeger 20. Gilt nur, solange der Client die Fertigkeit
-- nicht schon meldet - dann zaehlt der tatsaechliche Stand.
local DUAL_WIELD_LEVEL = { ROGUE = 10, WARRIOR = 20, HUNTER = 20 }

-- Ab welcher Stufe der Waffenmeister eine fehlende Fertigkeit lehrt.
-- Quelle: Wowhead "Best Hunter Weapons - WoW Classic": ab 10, Stangen-
-- waffen ab 20. Die Schamanen-Seite nennt ebenfalls Stufe 10.
local LEARN_LEVEL_DEFAULT = 10
local LEARN_LEVEL = { [6] = 20 }

-- Waffenarten, die eine Klasse nur ueber ein Talent bekommt. Fehlt die
-- Fertigkeit, ist das Talent nicht gewaehlt - dann kein Vorschlag, denn
-- ein Waffenmeister hilft hier nicht.
local TALENT_WEAPON = { SHAMAN = { [1] = true, [5] = true } }

-- Fertigkeitsnamen im Client -> Waffensubklasse. Nur die Sprache des
-- Clients zaehlt, nicht die Anzeigesprache. Deutsche Namen sind nicht
-- im Spiel gegengeprueft; passt keiner, faellt das Addon auf die reine
-- Klassentabelle zurueck statt falsch zu sperren.
local SKILL_SUBCLASS = {
  enUS = {
    ["Axes"] = 0, ["Two-Handed Axes"] = 1, ["Bows"] = 2, ["Guns"] = 3,
    ["Maces"] = 4, ["Two-Handed Maces"] = 5, ["Polearms"] = 6,
    ["Swords"] = 7, ["Two-Handed Swords"] = 8, ["Staves"] = 10,
    ["Fist Weapons"] = 13, ["Daggers"] = 15, ["Thrown"] = 16,
    ["Crossbows"] = 18, ["Wands"] = 19,
  },
  deDE = {
    ["\195\132xte"] = 0, ["Zweihand\195\164xte"] = 1, ["Bogen"] = 2,
    ["Schusswaffen"] = 3, ["Streitkolben"] = 4, ["Zweihandstreitkolben"] = 5,
    ["Stangenwaffen"] = 6, ["Schwerter"] = 7, ["Zweihandschwerter"] = 8,
    ["St\195\164be"] = 10, ["Faustwaffen"] = 13, ["Dolche"] = 15,
    ["Wurfwaffen"] = 16, ["Armbr\195\188ste"] = 18, ["Zauberst\195\164be"] = 19,
  },
}
local DUAL_WIELD_SKILL = { enUS = "Dual Wield", deDE = "Beidh\195\164ndigkeit" }

-- Gelernte Waffenfertigkeiten aus dem Fertigkeitenfenster lesen.
-- Eingeklappte Ueberschriften verbergen ihre Zeilen, deshalb wird kurz
-- alles aufgeklappt und danach der alte Zustand wiederhergestellt.
function Cand:ScanWeaponSkills()
  self.skillsDirty = nil
  if not GetNumSkillLines or not GetSkillLineInfo then self.skills = nil; return end

  local loc = BLL.clientLocale or "enUS"
  local names = SKILL_SUBCLASS[loc] or SKILL_SUBCLASS.enUS
  local dwName = DUAL_WIELD_SKILL[loc] or DUAL_WIELD_SKILL.enUS

  local collapsed = {}
  for i = 1, GetNumSkillLines() do
    local name, isHeader, isExpanded = GetSkillLineInfo(i)
    if isHeader and not isExpanded then collapsed[name] = true end
  end
  local anyCollapsed = next(collapsed) ~= nil
  if anyCollapsed and ExpandSkillHeader then pcall(ExpandSkillHeader, 0) end

  local known, any, dw = {}, false, false
  for i = 1, GetNumSkillLines() do
    local name, isHeader = GetSkillLineInfo(i)
    if name and not isHeader then
      local sc = names[name]
      if sc then known[sc] = true; any = true end
      if name == dwName then dw = true end
    end
  end

  if anyCollapsed and CollapseSkillHeader then
    for i = GetNumSkillLines(), 1, -1 do
      local name, isHeader = GetSkillLineInfo(i)
      if isHeader and collapsed[name] then pcall(CollapseSkillHeader, i) end
    end
  end

  -- Keine einzige Waffenfertigkeit erkannt: Sprache unbekannt oder
  -- Namen weichen ab. Dann lieber gar nicht pruefen als alles sperren.
  self.skills = any and { known = known, dualWield = dw } or nil
end

function Cand:WeaponSkills()
  if self.skills == nil or self.skillsDirty then self:ScanWeaponSkills() end
  return self.skills
end

function Cand:DualWieldLevel(class)
  return DUAL_WIELD_LEVEL[class or ""]
end

function Cand:CanUseWeapon(itemclass, subclass, class)
  if itemclass ~= 2 then return true end          -- keine Waffe
  if subclass == nil then return true end          -- unbekannt, durchlassen
  local prof = WEAPON_PROFICIENCY[class or ""]
  if not prof then return true end
  return prof[subclass] == 1
end

------------------------------------------------------------------
-- Quellenstufe bestimmen
------------------------------------------------------------------

-- "24-25" -> 24 ; "60" -> 60
local function ParseLevel(str)
  if not str then return nil end
  if type(str) == "number" then return str end
  local _, _, low = string.find(str, "^(%d+)")
  return tonumber(low)
end

-- Quellenstufe eines Items.
--
-- Frueher wurde immer das globale Minimum ueber alle Quellen genommen,
-- mit der Begruendung, ein Item sei ab der niedrigsten Quelle erreichbar.
-- Das stimmt fuer die Erreichbarkeit, zerstoert aber die Suche: ein
-- Raidteil, das irgendwo auch ein Stufe-40-Mob traegt, bekam die 40 und
-- fiel aus jedem Band eines Stufe-60-Charakters heraus. Am Stufenende
-- blieb dadurch fast nichts uebrig.
--
-- Jetzt gilt: liegt eine Quelle im gesuchten Band, zaehlt die niedrigste
-- davon. Nur wenn keine einzige Quelle im Band liegt, faellt die Funktion
-- auf das globale Minimum zurueck - dann entscheidet der Bandvergleich
-- beim Aufrufer wie gehabt, dass das Item nicht passt.
function Cand:SourceLevel(itemID, entry, band)
  local lowest, inBand = nil, nil
  local S = BLL.Sources

  local function consider(lvl)
    if not lvl then return end
    if not lowest or lvl < lowest then lowest = lvl end
    if band and lvl >= band.min and lvl <= band.max then
      if not inBand or lvl < inBand then inBand = lvl end
    end
  end

  if entry["U"] then
    for unitID in pairs(entry["U"]) do
      consider(ParseLevel(S:UnitLevel(unitID)))
    end
  end

  if entry["Q"] and S.quests then
    for questID in pairs(entry["Q"]) do
      local q = S.quests[questID]
      if type(q) == "table" then
        consider(ParseLevel(q["lvl"]) or ParseLevel(q["min"]))
      end
    end
  end

  return inBand or lowest
end

------------------------------------------------------------------
-- Schritt 1: Pool bauen (gestueckelt, damit das Spiel nicht einfriert)
------------------------------------------------------------------

local CHUNK = 1500        -- Eintraege pro Frame

-- So weit wird nach UNTEN gesucht, abhaengig von der eigenen Stufe.
--
-- Nicht an die Vorausplanung gekoppelt: "ahead" heisst vorausplanen und
-- meint nach oben. Frueher war das Band level-span/2 bis level+span,
-- wodurch ein Stufe-60-Charakter mit dem Standardwert 6 nur 57 bis 63
-- absuchte - ein Streifen, in dem am Stufenende fast nichts liegt.
--
-- Ein fester Wert taugt dafuer aber nicht. Mit 10 Stufen suchte ein
-- Stufe-15-Jaeger ploetzlich ab Stufe 5 und bekam Kram vorgeschlagen,
-- den er laengst hinter sich hatte. Auf niedrigen Stufen wechselt die
-- Ausruestung schnell, am Stufenende kaum noch - also waechst der
-- Rueckblick mit der Stufe: 3 Stufen bei Stufe 15, 10 bei Stufe 60.
local function Lookback(level)
  local n = math.floor((level or 60) / 6)
  if n < 3  then n = 3  end
  if n > 10 then n = 10 end
  return n
end

-- Typischer Abstand zwischen Itemlevel und Anforderungsstufe. Im
-- Datenbestand liegt der Median bei genau 5. Gebraucht wird er fuer die
-- 2275 Eintraege, die gar keine Anforderungsstufe fuehren.
local ILVL_TO_REQ = 5

-- Hoechste Quellenstufe in Vanilla. Darueber gibt es keine Mobs, ein
-- groesseres "ahead" kann das Band nach oben also nicht mehr weiten.
local MAX_SOURCE_LEVEL = 63

-- Vorsprung, den ein Kandidat braucht, wenn das angelegte Teil einen
-- Effekt hat, den der Scanner nicht in Punkte fassen kann.
--
-- Beide Zahlen sind geschaetzt, nicht ausgerechnet. Ein Proc-Effekt in
-- Vanilla liegt bei typischen Gewichten grob zwischen zehn und vierzig
-- Punkten; 12 Punkte plus ein Fuenftel des bekannten Werts filtert die
-- offensichtlich schlechten Ratschlaege heraus, ohne echte Spruenge zu
-- verschlucken. Wenn der Feldtest zeigt, dass zu viel oder zu wenig
-- durchkommt, sind das die beiden Stellschrauben.
local UNSCORED_FLAT  = 12
local UNSCORED_SHARE = 0.20
local indexKey = nil
local indexBand = nil

function Cand:StartIndex(minLvl, maxLvl)
  if not BLL.Sources.available then
    BLL:Print("|cffff0000" .. L["CAND_NO_PFQUEST"] .. "|r")
    return false
  end

  self.pool       = {}
  self.poolSize   = 0
  self.fromImport = {}    -- [itemID] = 1, wenn weder pfQuest noch der Import eine Quelle kennen
  self.pfqCount   = 0
  self.importCount = 0
  self.state    = "indexing"
  self.lastError = nil
  self.startedAt = GetTime and GetTime() or 0
  self.lastTick  = nil
  indexKey  = nil
  indexBand = { min = minLvl, max = maxLvl }

  BLL:Print(string.format(L["CAND_SEARCHING"], minLvl, maxLvl))
  return true
end

function Cand:IndexChunk()
  -- Ohne pfQuest (etwa nur Questie installiert) gibt es hier nichts zu
  -- durchsuchen; weiter mit dem Import. Bis 0.24.1 blieb die Suche an
  -- dieser Stelle stehen: Pool 0, "nichts Besseres gefunden", obwohl
  -- der Import 2227 passende Items kannte.
  local items = BLL.Sources.items
  if not items then
    self.pfqCount = 0
    self:StartImportIndex()
    return
  end

  local processed = 0
  local key, entry = next(items, indexKey)

  while key and processed < CHUNK do
    if type(entry) == "table" then
      local lvl = self:SourceLevel(key, entry, indexBand)
      if lvl and lvl >= indexBand.min and lvl <= indexBand.max then
        self.pool[key] = lvl
        self.poolSize = self.poolSize + 1
      end
    end
    indexKey = key
    key, entry = next(items, indexKey)
    processed = processed + 1
  end

  if not key then
    -- pfQuest ist durch. Was hier im Pool liegt, hat einen Fundort.
    self.pfqCount = self.poolSize
    self:StartImportIndex()
  end
end

------------------------------------------------------------------
-- Schritt 1b: Pool aus dem Import ergaenzen
--
-- pfQuest liefert nur Items, deren Quelle eine brauchbare Stufenangabe
-- hat. Am Stufenende faellt damit fast alles weg: Raid- und Dungeonbosse
-- fuehren oft keine verwertbare Stufe, und ein Item mit einer einzigen
-- niedrigen Nebenquelle rutschte ohnehin aus dem Band.
--
-- Die importierte ItemDB kennt zu 11000 Items Slot, Qualitaet, Stufe und
-- Werte - alles, was fuer einen Vorschlag noetig ist. Nur den Fundort
-- kennt sie nicht. Solche Items kommen deshalb zusaetzlich in den Pool,
-- werden als "ohne Fundort" markiert und hinter den verorteten
-- einsortiert. Ein Vorschlag ohne Weg ist weniger wert als einer mit -
-- aber mehr als gar keiner.
------------------------------------------------------------------

local importKey = nil

local function ImportReq(e)
  local req, ilvl = e.reqlevel or 0, e.ilvl or 0
  if req <= 0 then req = math.max(0, ilvl - ILVL_TO_REQ) end
  return req
end

local function ImportAccepts(e, effReq, maxReq, minIlvl, class)
  return effReq <= maxReq and (e.ilvl or 0) >= minIlvl and (e.quality or 0) >= 1
     and BLL.ItemDB:MaskAllows(e.classmask, class)
end

-- Grenzen fuer den Import, wie ImportChunk sie nutzt.
function Cand:ImportBounds()
  local player = BLL.player or {}
  local level  = player.level or 60
  return level + self:PlanAhead(), math.max(1, level - Lookback(level)), player.class
end

function Cand:StartImportIndex()
  if not BLL.ItemDB or not BLL.ItemDB.loaded or not BLL.ItemDB.data then
    self:AnnouncePool()
    self:StartQuery()
    return
  end
  importKey  = nil
  self.state = "indexdb"
end

function Cand:ImportChunk()
  local data = BLL.ItemDB.data
  if not data then
    self:AnnouncePool()
    self:StartQuery()
    return
  end

  -- Obergrenze ist die Anforderungsstufe: was man nicht anlegen kann und
  -- auch nicht bald anlegen kann, gehoert nicht auf die Liste.
  -- Untergrenze ueber das Itemlevel. Deutlich veraltete Stuecke bleiben
  -- damit draussen.
  local maxReq, minIlvl, class = self:ImportBounds()

  local pfItems = BLL.Sources.items
  local processed = 0
  local key, e = next(data, importKey)

  while key and processed < CHUNK do
    if type(e) == "table" and not self.pool[key] then

      -- 2275 der 11349 Eintraege fuehren keine Anforderungsstufe. Ohne
      -- Ersatzwert rutscht jeder davon durch, weil 0 immer kleiner ist
      -- als jede Obergrenze - so landete "Flintlocke's Hand Cannon"
      -- (Itemlevel 65, keine Stufenangabe) im Pool eines Stufe-15-
      -- Jaegers und verdraengte mit absurden Zuwaechsen alles, was
      -- wirklich erreichbar war. Geschaetzt wird ueber das Itemlevel.
      local effReq = ImportReq(e)

      if ImportAccepts(e, effReq, maxReq, minIlvl, class) then
        -- Als Poolstufe die Anforderungsstufe nehmen, ersatzweise das
        -- Itemlevel. Sie dient nur der Anzeige, gefiltert wurde schon.
        -- Als Poolstufe die geschaetzte Anforderungsstufe, nicht das rohe
        -- Itemlevel: sonst stuende bei einem Teil ohne Stufenangabe die
        -- 65 in der Anzeige, obwohl es ab 60 tragbar ist.
        self.pool[key] = effReq
        self.poolSize  = self.poolSize + 1
        -- Nur wenn weder pfQuest noch der Import das Item als Quelle
        -- fuehren, fehlt der Fundort wirklich. Kennt pfQuest es und lag
        -- nur die Stufe daneben, sind die Quellen weiterhin abrufbar.
        --
        -- Den Import nicht zu fragen war der Grund, warum "Belt of
        -- Binding" im Spiel nie erschien: pfQuest kennt das Teil nicht,
        -- also galt es als "ohne Fundort" und wurde hinter alle Teile
        -- sortiert, die pfQuest kennt - obwohl der Import Hailar the
        -- Frigid in Frostmane Hollow mit 33 % fuehrt und das Teil mit +12
        -- das beste Guertel-Upgrade war. In der Nachstellung ohne pfQuest
        -- fiel das nicht auf, weil dort alle Teile aus dem Import kamen.
        local imported = BLL.Sources and BLL.Sources.imported
        if not (pfItems and pfItems[key]) and not (imported and imported[key]) then
          self.fromImport[key] = 1
          self.importCount = self.importCount + 1
        end
      end
    end
    importKey = key
    key, e = next(data, importKey)
    processed = processed + 1
  end

  if not key then
    self:AnnouncePool()
    self:StartQuery()
  end
end

function Cand:AnnouncePool()
  if (self.importCount or 0) > 0 then
    BLL:Print(string.format(L["CAND_FOUND_MIX"], self.poolSize,
      self.pfqCount or 0, self.importCount))
  else
    BLL:Print(string.format(L["CAND_FOUND"], self.poolSize))
  end
end

------------------------------------------------------------------
-- Schritt 2: Itemdaten besorgen (gedrosselt)
--
-- Wichtig: eine Serverantwort kommt NICHT sofort. Wer anfragt und im
-- selben Moment liest, bekommt nichts und fragt beim naechsten Durchlauf
-- erneut an - doppelte Last ohne Nutzen. Deshalb saubere Trennung:
--
--   requesting -> jedes unbekannte Item GENAU EINMAL anfragen
--   waiting    -> kurz warten, damit die Antworten eintreffen
--   collecting -> nur noch lesen, nie anfragen
--
-- Erst wenn nach dem Einsammeln noch etwas fehlt, gibt es eine zweite
-- Runde. Maximal zwei, danach wird der Rest als nicht auffindbar vermerkt.
------------------------------------------------------------------

local queue       = {}    -- aktuell abzuarbeitende IDs
local queueIndex  = 1
local queryTimer  = 0
local waitTimer   = 0
local resolved    = 0
local round       = 1
local MAX_ROUNDS  = 2
local WAIT_SECONDS = 4

------------------------------------------------------------------
-- Vorbefuellung aus der importierten ItemDB
--
-- Das ist der eigentliche Gewinn des Imports: liegen Slot, Qualitaet und
-- Werte lokal vor, braucht es fuer diese Items KEINE Serverabfrage mehr.
-- Von 658 Kandidaten bleiben so nur die uebrig, die der Import nicht
-- kennt - meist eine Handvoll statt mehrerer hundert.
------------------------------------------------------------------

-- InventoryType des Servers -> INVTYPE-String, wie GetItemInfo ihn liefert
local SLOTNUM_INVTYPE = {
  [1]  = "INVTYPE_HEAD",           [2]  = "INVTYPE_NECK",
  [3]  = "INVTYPE_SHOULDER",       [5]  = "INVTYPE_CHEST",
  [6]  = "INVTYPE_WAIST",          [7]  = "INVTYPE_LEGS",
  [8]  = "INVTYPE_FEET",           [9]  = "INVTYPE_WRIST",
  [10] = "INVTYPE_HAND",           [11] = "INVTYPE_FINGER",
  [12] = "INVTYPE_TRINKET",        [13] = "INVTYPE_WEAPON",
  [14] = "INVTYPE_SHIELD",         [15] = "INVTYPE_RANGED",
  [16] = "INVTYPE_CLOAK",          [17] = "INVTYPE_2HWEAPON",
  [20] = "INVTYPE_ROBE",           [21] = "INVTYPE_WEAPONMAINHAND",
  [22] = "INVTYPE_WEAPONOFFHAND",  [23] = "INVTYPE_HOLDABLE",
  [25] = "INVTYPE_THROWN",         [26] = "INVTYPE_RANGEDRIGHT",
  [28] = "INVTYPE_RELIC",
}

-- Ruestungsart aus der Subklasse des Servers (itemclass 4 = Ruestung)
local SUBCLASS_ARMOR = {
  [1] = "CLOTH", [2] = "LEATHER", [3] = "MAIL", [4] = "PLATE", [6] = "SHIELD",
}

function Cand:PreloadFromItemDB()
  if not BLL.ItemDB or not BLL.ItemDB.loaded then return 0, 0 end

  local cache = BananaLootlineDB.itemcache
  local player = BLL.player or {}
  local level = player.level or 60
  local allowedArmor = AllowedArmor(player.class, level)

  local skipped, needStats = 0, 0

  for itemID in pairs(self.pool) do
    local cached = cache[itemID]
    if cached and cached.cv ~= Cand.CACHE_VERSION and not cached.skip then
      cache[itemID] = nil
      cached = nil
    end
    -- Aussortiert wegen Stufe, Ruestungsart oder Klasse haengt vom
    -- aktuellen Charakter ab: nach einem Aufstieg darf Kette ab 40 oder
    -- ein Teil fuer Stufe 18 wieder rein. Solche Markierungen werden
    -- jedes Mal neu aus dem Import berechnet - das kostet keine
    -- Serveranfrage. Aeltere Markierungen ohne "pre" stammen aus
    -- Fassungen, in denen sie nie wieder verschwanden; sie werden fuer
    -- Items aus dem Import ebenfalls neu bewertet.
    if cached and cached.skip and not cached.fail
       and (cached.pre or cached.cv ~= Cand.CACHE_VERSION)
       and BLL.ItemDB:Get(itemID) then
      cache[itemID] = nil
      cached = nil
    end
    -- "Server liefert nichts" gilt nur fuer Teile, die eine Anfrage
    -- brauchen. Fuehrt der Import Werte, ist die Anfrage ueberfluessig
    -- und die Markierung hinfaellig. Sie stammt aus Fassungen, in denen
    -- der Import noch keine Werte hatte, und ueberlebte jedes Update:
    -- "Belt of Binding" fehlte so bei einem Stufe-16-Jaeger in jeder
    -- Liste, obwohl es sein bestes Guertel-Upgrade war.
    if cached and cached.fail then
      local e = BLL.ItemDB:Get(itemID)
      if e and e.stats and next(e.stats) then
        cache[itemID] = nil
        cached = nil
      end
    end
    if not cached then
      local e = BLL.ItemDB:Get(itemID)
      if e then
        local invtype = SLOTNUM_INVTYPE[e.slot or 0]
        local armor = (e.itemclass == 4) and SUBCLASS_ARMOR[e.subclass or 0] or nil

        -- Aussortieren, was der Charakter ohnehin nicht tragen kann.
        -- Genau das spart die Masse der Serverabfragen.
        local usable = true
        if not invtype then usable = false end
        if armor and not allowedArmor[armor] then usable = false end
        -- Stufe mit Vorausplanung: sonst fehlen genau die Teile, die
        -- die Planung mit "ab 18" zeigen soll.
        if e.reqlevel and e.reqlevel > level + self:PlanAhead() then usable = false end
        if e.classmask and not BLL.ItemDB:MaskAllows(e.classmask, player.class) then
          usable = false
        end
        if not self:CanUseWeapon(e.itemclass, e.subclass, player.class) then
          usable = false
        end

        if not usable then
          cache[itemID] = { skip = 1, pre = 1 }
          skipped = skipped + 1
        else
          local stats = e.stats
          local hasStats = false
          if stats then
            for _ in pairs(stats) do hasStats = true break end
          end

          if hasStats then
            -- Vollstaendig aus dem Import bedienbar, keine Abfrage noetig.
            cache[itemID] = {
              n = e.name or ("Item " .. itemID),
              q = e.quality, r = e.reqlevel, e = invtype, a = armor,
              cm = e.classmask, ic = e.itemclass, sc = e.subclass,
              st = stats, use = e.use, db = 1, cv = Cand.CACHE_VERSION,
            }
          else
            -- Der Export kennt das Item, aber ohne Werte. Wir schreiben
            -- es bewusst NICHT in den Cache: dadurch bleibt es in der
            -- Warteschlange und der Tooltipscan holt die Werte nach.
            -- Wuerden wir es mit leeren Stats eintragen, bekaeme es
            -- fuer immer Score 0 und taeuchte nie als Upgrade auf.
            needStats = needStats + 1
          end
        end
      end
    end
  end

  return skipped, needStats
end

function Cand:StartQuery()
  queue = {}
  queueIndex = 1
  resolved = 0
  round = 1

  BananaLootlineDB.itemcache = BananaLootlineDB.itemcache or {}
  local cache = BananaLootlineDB.itemcache

  -- Erst aus dem Import bedienen, dann erst den Server fragen.
  local skipped, needStats = self:PreloadFromItemDB()
  if skipped > 0 or needStats > 0 then
    BLL:Print(string.format(L["CAND_IMPORT"], skipped))
  end

  for itemID in pairs(self.pool) do
    -- Bereits bekannte Items (auch als nicht auffindbar vermerkte)
    -- ueberspringen. Nach einem Disconnect setzt der naechste Lauf
    -- deshalb dort an, wo der letzte aufgehoert hat.
    if not cache[itemID] then
      table.insert(queue, itemID)
    end
  end

  local total = table.getn(queue)
  if total == 0 then
    self.state = "ready"
    BLL:Print(L["CAND_CACHED"])
    if BLL.UI and BLL.UI.frame and BLL.UI.frame:IsVisible() then BLL.UI:Refresh() end
    return
  end

  self.state = "requesting"
  local rate = (BananaLootlineDB and BananaLootlineDB.queryRate) or 8
  BLL:Print(string.format(L["CAND_REQUEST"], total, math.ceil(total / rate)))
end

-- Daten eines Items uebernehmen. true = erledigt.
function Cand:StoreItem(itemID)
  local name, link, quality, reqLevel, itype, subtype, stack, equipLoc = GetItemInfo(itemID)
  if not name then return false end

  if not equipLoc or equipLoc == "" or not self.INVTYPE_SLOTS[equipLoc] then
    BananaLootlineDB.itemcache[itemID] = { skip = 1 }
    return true
  end

  local stats, meta = BLL.Scanner:GetStats(itemID)

  BananaLootlineDB.itemcache[itemID] = {
    n  = name,
    q  = quality,
    r  = reqLevel,
    e  = equipLoc,
    a  = ArmorKey(subtype),
    st = stats or {},
    -- Zugangsbedingung aus dem Tooltip, etwa ein Ehrenrang beim
    -- PvP-Quartiermeister. Wird mitgespeichert, weil der Clientcache
    -- den Tooltip spaeter wieder vergisst - der Befund hier nicht.
    lock = meta and meta.restricted or nil,
  }
  return true
end

-- Anfragephase: pro Tick ein Item beim Server anfragen.
function Cand:RequestTick(elapsed)
  queryTimer = queryTimer - elapsed
  if queryTimer > 0 then return end

  local rate = (BananaLootlineDB and BananaLootlineDB.queryRate) or 8
  queryTimer = 1 / rate

  local total = table.getn(queue)
  if queueIndex > total then
    self.state = "waiting"
    waitTimer = WAIT_SECONDS
    return
  end

  local itemID = queue[queueIndex]
  queueIndex = queueIndex + 1

  -- Schon im Clientcache? Dann direkt uebernehmen, keine Anfrage noetig.
  if self:StoreItem(itemID) then
    resolved = resolved + 1
  else
    -- Genau eine Anfrage. Die Antwort holen wir uns spaeter ab.
    BLL.Scanner:GetLines(itemID)
  end
end

-- Sammelphase: nur lesen, niemals anfragen.
function Cand:CollectTick()
  local pending = {}

  for i = 1, table.getn(queue) do
    local itemID = queue[i]
    if not BananaLootlineDB.itemcache[itemID] then
      if self:StoreItem(itemID) then
        resolved = resolved + 1
      else
        table.insert(pending, itemID)
      end
    end
  end

  local left = table.getn(pending)

  if left > 0 and round < MAX_ROUNDS then
    round = round + 1
    queue = pending
    queueIndex = 1
    self.state = "requesting"
    BLL:Print(string.format(L["CAND_ROUND2"], left))
    return
  end

  -- Endgueltig nicht auffindbar: vermerken, damit der naechste Lauf sie
  -- nicht erneut beim Server anfragt.
  for i = 1, left do
    BananaLootlineDB.itemcache[pending[i]] = { skip = 1, fail = 1 }
  end

  self.state = "ready"
  BLL:Print(string.format(L["CAND_DONE"], resolved,
    (left > 0) and string.format(L["CAND_MISSING"], left) or ""))
  if BLL.UI and BLL.UI.frame and BLL.UI.frame:IsVisible() then BLL.UI:Refresh() end
end

function Cand:Stop()
  if self.state == "idle" or self.state == "ready" then
    BLL:Print(L["CAND_IDLE"])
    return
  end
  self.state = "ready"
  BLL:Print(string.format(L["CAND_ABORTED"], resolved))
end

-- Es gab hier zwei Definitionen von Progress(). Die zweite ueberschrieb
-- die erste und kannte nur den Zustand "querying", den es nicht gibt -
-- waehrend des Abfragens und Einsammelns zeigte das Fenster deshalb gar
-- keinen Fortschritt an. Geblieben ist die Fassung, die alle vier
-- tatsaechlichen Zustaende abdeckt.
function Cand:Progress()
  if self.state == "failed" then
    return L["PROG_FAILED"]
  elseif self.state == "indexing" or self.state == "indexdb" then
    return L["PROG_INDEX"]
  elseif self.state == "requesting" then
    return string.format(L["PROG_REQUEST"],
      queueIndex - 1, table.getn(queue), round)
  elseif self.state == "waiting" then
    return string.format(L["PROG_WAIT"], waitTimer)
  elseif self.state == "collecting" then
    return L["PROG_COLLECT"]
  end
  return nil
end

------------------------------------------------------------------
-- Schritt 3: Vorschlaege berechnen
------------------------------------------------------------------

-- Wie viele Stufen vorausgeplant wird. Eine Lootline ist ein Wegplan,
-- kein Momentaufnahme-Vergleich: ein Teil, dem zwei Stufen fehlen,
-- gehoert auf die Liste - sonst sieht man das lohnendste Ziel nicht.
-- Solche Items werden im Fenster als gesperrt gekennzeichnet.
-- Voreinstellung 0: nur was man sofort anlegen kann. Bis 0.22.8 waren
-- es 6 Stufen; turtlelootline.com zeigt ebenfalls nur Tragbares, und
-- ein Teil "ab 22" hilft einem Stufe-16-Charakter heute nicht.
Cand.DEFAULT_AHEAD = 0

function Cand:PlanAhead()
  local n = BananaLootlineDB and BananaLootlineDB.planAhead
  if n == nil then return Cand.DEFAULT_AHEAD end
  return n
end

------------------------------------------------------------------
-- Zugangsbedingung aus AtlasLoot
--
-- AtlasLoot fuehrt in AtlasLoot_Data["AtlasLootSources"] zu ueber 7000
-- Gegenstaenden einen Herkunftstext, darunter rund 240 mit Ruf- und 300
-- mit Rangbedingung. Genau von dort stammt die Zeile
-- "Warsong Gulch - Revered", die im Spiel am Tooltip haengt und im
-- nachgebauten Scan-Tooltip fehlt - mit allen Addons ausser diesem
-- abgeschaltet verschwand sie.
--
-- Direkt aus der Tabelle gelesen ist das erheblich verlaesslicher als
-- aus dem Tooltip gefischt: es braucht kein Ueberfahren, keine
-- Ladereihenfolge und keinen Zeitpunkt.
--
-- Erkannt wird ueber die Konstanten des Clients. AtlasLoot baut seine
-- Texte aus FACTION_STANDING_LABEL6 bis 8 und RANK - dieselben Werte
-- stehen in jeder Clientsprache bereit, eine eigene Wortliste waere
-- nur eine zusaetzliche Fehlerquelle.
------------------------------------------------------------------

function Cand:AtlasRestriction(itemID)
  if not itemID or not AtlasLoot_Data then return nil end
  local src = AtlasLoot_Data["AtlasLootSources"]
  if type(src) ~= "table" then return nil end

  local txt = src[itemID]
  if type(txt) ~= "string" or txt == "" then return nil end

  local marks = {
    FACTION_STANDING_LABEL5,   -- freundlich
    FACTION_STANDING_LABEL6,   -- wohlwollend
    FACTION_STANDING_LABEL7,   -- respektvoll
    FACTION_STANDING_LABEL8,   -- ehrfuerchtig
    RANK,                      -- PvP-Rang
  }
  for i = 1, table.getn(marks) do
    local w = marks[i]
    if type(w) == "string" and w ~= "" and string.find(txt, w, 1, true) then
      return txt
    end
  end
  return nil
end

-- Anforderungsstufe eines Kandidaten, aus beiden Quellen abgeglichen.
--
-- Der Itemcache ueberlebt Reloads und kann aus einer Sitzung stammen, in
-- der die Itemdatenbank noch andere Werte fuehrte. Genau so stand
-- "Outrider's Bow" mit "ab 18" bei einem Stufe-15-Jaeger, obwohl Tooltip
-- und Import uebereinstimmend Stufe 60 nennen.
--
-- Bei Uneinigkeit gilt die hoehere Angabe. Ein Teil zu wenig
-- vorzuschlagen kostet den Spieler nichts; ihn quer ueber den Kontinent
-- zu einem Gegenstand zu schicken, den er nicht anlegen kann, schon.
------------------------------------------------------------------
-- Rufvoraussetzung
--
-- Der Import fuehrt sie bei 411 Teilen als "Fraktion - Stufe", etwa
-- "Argent Dawn - Honored". Das Addon las sie nicht: gemeldet von einem
-- Tester, Ruf- und Rangteile standen ohne Hinweis in der Liste. Der
-- Tooltip-Scan erwischte die Zeile nur bei Teilen, die der Client schon
-- kannte.
--
-- Erfuellt ist sie, wenn der eigene Ruf bei dieser Fraktion mindestens
-- die geforderte Stufe hat. Gelesen wird die Rufliste des Clients; eine
-- Fraktion, die dort nicht steht (eingeklappte Gruppe, anderssprachiger
-- Client), gilt als nicht erfuellt - lieber ein Teil zu wenig als eines,
-- das man nicht kaufen kann. /bll locked zeigt sie trotzdem.
------------------------------------------------------------------

local STANDING = { Hated = 1, Hostile = 2, Unfriendly = 3, Neutral = 4,
                   Friendly = 5, Honored = 6, Revered = 7, Exalted = 8 }

function Cand:ReadReputation()
  local rep = {}
  if GetNumFactions and GetFactionInfo then
    for i = 1, GetNumFactions() do
      local name, _, standing, _, _, _, isHeader = GetFactionInfo(i)
      if name and not isHeader and standing then rep[name] = standing end
    end
  end
  self.reputation = rep
  return rep
end

-- Text der nicht erfuellten Rufvoraussetzung, sonst nil.
function Cand:RepLock(itemID)
  local db = itemID and BLL.ItemDB and BLL.ItemDB:Get(itemID)
  local req = db and db.rep
  if not req then return nil end
  local _, _, faction, standing = string.find(req, "^(.-) %- (%a+)$")
  local need = standing and STANDING[standing]
  if not faction or not need then return nil end
  local have = (self.reputation or self:ReadReputation())[faction]
  if have and have >= need then return nil end
  return req
end

------------------------------------------------------------------
-- Itemlevel-Filter (/bll ilvl 60-80)
--
-- Vorschlag eines Testers: damit laesst sich von Hand eingrenzen, aus
-- welchen Teilen das Addon waehlt. Auf Stufe 60 tragen fast alle Teile
-- Anforderungsstufe 60; erst das Itemlevel trennt Questkram von
-- Raidbeute. Teile ohne Itemlevel im Import bleiben drin.
------------------------------------------------------------------

function Cand:IlvlRange()
  local db = BananaLootlineDB
  return db and db.ilvlMin, db and db.ilvlMax
end

function Cand:IlvlAllows(itemID)
  local lo, hi = self:IlvlRange()
  if not lo and not hi then return true end
  local e = BLL.ItemDB and BLL.ItemDB:Get(itemID)
  local ilvl = e and e.ilvl
  if not ilvl then return true end
  if lo and ilvl < lo then return false end
  if hi and ilvl > hi then return false end
  return true
end

function Cand:RequiredLevel(entry, itemID)
  local r = entry.r or 0
  if itemID and BLL.ItemDB and BLL.ItemDB.loaded then
    local db = BLL.ItemDB:Get(itemID)
    if db and db.reqlevel and db.reqlevel > r then
      r = db.reqlevel
      entry.r = r     -- gleich im Cache richtigstellen
    end
  end
  return r
end

function Cand:IsUsable(entry, class, level, allowedArmor, itemID)
  if entry.skip then return false end

  -- Ruf- oder Rangbedingung: das Teil steht zwar bei einem Haendler,
  -- ist aber erst nach entsprechender Vorleistung zu haben. In einem
  -- Wegplan hat es nichts verloren - ein Stufe-15-Charakter kam an den
  -- Bogen des PvP-Quartiermeisters nie heran, er stand trotzdem ganz
  -- oben. Mit /bll locked wieder einblendbar.
  if entry.lock and not (BananaLootlineDB and BananaLootlineDB.showLocked) then
    return false
  end
  if not (BananaLootlineDB and BananaLootlineDB.showLocked) and self:RepLock(itemID) then
    return false
  end

  -- Aeltere Cache-Eintraege stammen aus einer Fassung ohne Waffenpruefung
  -- und fuehren keine Subklasse. Da unbekannte Subklassen durchgelassen
  -- werden, rutschte dadurch weiterhin ein Zauberstab zum Jaeger durch.
  -- Also aus der Itemdatenbank nachtragen, statt den Cache zu verwerfen.
  if entry.sc == nil and itemID and BLL.ItemDB and BLL.ItemDB.loaded then
    local db = BLL.ItemDB:Get(itemID)
    if db then
      entry.ic = db.itemclass
      entry.sc = db.subclass
      if entry.cm == nil then entry.cm = db.classmask end
    end
  end

  if self:RequiredLevel(entry, itemID) > (level + self:PlanAhead()) then
    return false
  end

  -- Ruestungsart pruefen. Schmuck, Ringe, Halsketten und Waffen haben
  -- keinen Ruestungsschluessel und werden durchgelassen. Umhaenge fuehren
  -- "Stoff", sind aber fuer jede Klasse da.
  if entry.a and not allowedArmor[entry.a] and entry.e ~= "INVTYPE_CLOAK" then
    return false
  end

  -- Klassenbeschraenkung aus dem Import. Ein "Arcanist Circlet" ist
  -- magierexklusiv - ohne diese Pruefung wuerde es jedem Stoffträger
  -- vorgeschlagen.
  if entry.cm and entry.cm ~= 0 and entry.cm ~= -1 then
    if BLL.ItemDB and not BLL.ItemDB:MaskAllows(entry.cm, class) then
      return false
    end
  end

  if not self:CanUseWeapon(entry.ic, entry.sc, class) then
    return false
  end

  return true
end

-- accept (optional): wird mit jedem Kandidaten aufgerufen, nachdem
-- seine Quellen aufgeloest sind. Was abgelehnt wird, zaehlt nicht gegen
-- maxResults; dann rueckt der naechste nach. Hoechstens maxScan
-- Kandidaten werden dafuer angesehen, weil die Quellensuche kostet.
function Cand:GetUpgrades(slotKey, maxResults, accept, maxScan)
  if not self.pool then return nil end

  maxResults = maxResults or 5
  local cache = BananaLootlineDB.itemcache or {}
  local player = BLL.player or {}
  local level = player.level or 60
  local class = player.class
  local allowedArmor = self:SuggestArmor(class, level)
  local isWeapon = WEAPON_SLOTS[slotKey]

  ----------------------------------------------------------------
  -- Score des angelegten Items, inklusive seiner eigenen Zusaetze.
  -- Sonst gewaenne jeder Kandidat allein dadurch, dass beim
  -- Vergleichsstueck Setbonus und Use-Effekt unter den Tisch fallen.
  ----------------------------------------------------------------
  local equipped = BLL.Gear.equipped[slotKey]
  local baseScore = 0
  if equipped then
    baseScore = BLL.Weights:Score(equipped.stats, isWeapon)


    local eqEntry = equipped.id and cache[equipped.id]
    if eqEntry and eqEntry.use then
      baseScore = baseScore + BLL.Weights:UseEffectScore(eqEntry.use)
    end

    -- Setbonus des angelegten Teils: es zaehlt als getragen, deshalb
    -- wird es beim Zaehlen NICHT ausgelassen.
    if BLL.SetDB and BLL.SetDB.loaded and equipped.id then
      local setID = BLL.SetDB:GetSetOf(equipped.id)
      if setID then
        local worn = BLL.SetDB:CountEquipped(setID, slotKey)
        local gained = BLL.SetDB:BonusGain(setID, worn)
        if gained then
          baseScore = baseScore + BLL.Weights:Score(nil, isWeapon, gained)
        end
      end
    end
  end

  ----------------------------------------------------------------
  -- Sicherheitsabstand bei unbeziffertem Effekt
  --
  -- Der Scanner liest Werte aus dem Tooltip. Ein Proc-Effekt steht dort
  -- als Satz, nicht als Zahl: "2% Chance bei Treffer, einen
  -- zusaetzlichen Angriff auszufuehren". Fuer die Bewertung ist so ein
  -- Teil deshalb null Punkte wert - obwohl es stark sein kann.
  --
  -- Ohne Gegenmassnahme gewinnt jedes beliebige Teil mit vier Ausdauer
  -- gegen die Hand der Gerechtigkeit, und das Addon raet dem Spieler,
  -- ein gutes Stueck gegen ein schlechtes zu tauschen.
  --
  -- Also: traegt der Spieler so ein Teil, muss ein Kandidat deutlich
  -- vorne liegen statt knapp. Was nicht deutlich vorne liegt, ist keine
  -- gesicherte Verbesserung und wird auch nicht als eine ausgegeben.
  --
  -- Die Anstecknadel der Argentumdaemmerung ist davon NICHT betroffen:
  -- ihr Text nennt keinen Kampfeffekt, sie bleibt bei null Punkten, und
  -- jedes Teil mit einem einzigen Wert schlaegt sie weiterhin.
  ----------------------------------------------------------------
  local unscoredEquip = equipped and equipped.unscored
  local margin = 0
  if unscoredEquip then
    margin = UNSCORED_FLAT + baseScore * UNSCORED_SHARE
  end

  local out = {}

  for itemID, srcLevel in pairs(self.pool) do
    local entry = cache[itemID]
    if entry and not entry.skip
       and not (BLL.Sources.OnlyLockedSources and BLL.Sources:OnlyLockedSources(itemID))
       and self:IlvlAllows(itemID) then
      local slots = self.INVTYPE_SLOTS[entry.e or ""]
      local fits = false
      if slots then
        for i = 1, table.getn(slots) do
          if slots[i] == slotKey then fits = true break end
        end
      end

      -- Waffe in der Schildhand verlangt Beidhaendigkeit. Schilde und
      -- Nebenhandgegenstaende sind davon nicht betroffen.
      -- Abgeglichene Stufe, nicht die rohe aus dem Cache: sonst zeigt
      -- die Liste "ab 18" an einem Teil, das Stufe 60 verlangt.
      local reqEff = self:RequiredLevel(entry, itemID)
      if reqEff == 0 then reqEff = nil end
      local skills = self:WeaponSkills()
      local dualWieldNeeded, learnSkill

      if fits and slotKey == "SecondaryHandSlot"
         and (entry.e == "INVTYPE_WEAPON" or entry.e == "INVTYPE_WEAPONOFFHAND") then
        -- Meldet der Client Beidhaendigkeit, gilt sie ab sofort. Sonst
        -- entscheidet die Stufe, ab der der Klassenlehrer sie anbietet.
        if not (skills and skills.dualWield) then
          local dw = self:DualWieldLevel(class)
          if not dw then
            fits = false
          elseif dw > level then
            -- Noch nicht lernbar: gesperrt bis zur Stufe des Lehrers
            dualWieldNeeded = true
            if dw > (reqEff or 0) then reqEff = dw end
          elseif skills then
            -- Lernbar, laut Client aber nicht gelernt: Hinweis
            learnSkill = true
          end
        end
      end

      -- Waffenfertigkeit: fehlt sie, kann sie der Waffenmeister lehren
      -- (ab 10, Stangenwaffen ab 20). Talentwaffen lehrt er nicht.
      if fits and skills and entry.ic == 2 and entry.sc ~= nil
         and entry.sc ~= 14 and entry.sc ~= 20 and not skills.known[entry.sc] then
        local talent = TALENT_WEAPON[class or ""]
        if talent and talent[entry.sc] then
          fits = false
        else
          learnSkill = true
          local ll = LEARN_LEVEL[entry.sc] or LEARN_LEVEL_DEFAULT
          if ll > (reqEff or 0) then reqEff = ll end
        end
      end

      -- Wie jedes Teil ueber der eigenen Stufe: nur innerhalb der
      -- Vorausplanung zeigen, dann mit Vermerk.
      if fits and reqEff and reqEff > level + self:PlanAhead() then fits = false end

      if fits and self:IsUsable(entry, class, level, allowedArmor, itemID) then
        local statScore = BLL.Weights:Score(entry.st, isWeapon)

        -- Zweihaender kosten die Schildhand. Ohne diese Verrechnung
        -- schlaegt das Addon einem Schutzpaladin einen Zweihaender vor
        -- und verschweigt, dass dabei Schild samt Block, Ruestung und
        -- Ausdauer wegfallen.
        local twoHand, offHandLoss = nil, 0
        if slotKey == "MainHandSlot" and entry.e == "INVTYPE_2HWEAPON" then
          twoHand = true
          local off = BLL.Gear.equipped["SecondaryHandSlot"]
          if off then
            offHandLoss = BLL.Weights:Score(off.stats, "melee")
            local offEntry = off.id and cache[off.id]
            if offEntry and offEntry.use then
              offHandLoss = offHandLoss + BLL.Weights:UseEffectScore(offEntry.use)
            end
          end
        end

        local useScore, estimated = 0, false
        if entry.use then
          useScore, estimated = BLL.Weights:UseEffectScore(entry.use)
        end

        local setInfo, setScore = nil, 0
        if BLL.SetDB and BLL.SetDB.loaded then
          setInfo = BLL.SetDB:EvaluateCandidate(itemID, slotKey)
          if setInfo and setInfo.stats then
            setScore = BLL.Weights:Score(nil, isWeapon, setInfo.stats)
          end
        end

        local score = statScore + useScore + setScore - offHandLoss
        if score > baseScore + margin then
          -- Tatsaechliche Wertaenderung gegenueber dem angelegten Teil.
          -- Der Punktevorsprung allein sagt nicht, WAS sich aendert -
          -- und verschweigt vor allem, was man verliert.
          local diff = {}
          local seen = {}
          local eqStats = (equipped and equipped.stats) or {}
          for k in pairs(eqStats) do seen[k] = true end
          for k in pairs(entry.st or {}) do seen[k] = true end
          for k in pairs(seen) do
            local d = ((entry.st and entry.st[k]) or 0) - (eqStats[k] or 0)
            if d ~= 0 then diff[k] = d end
          end
          table.insert(out, {
            id        = itemID,
            fromImport = self.fromImport and self.fromImport[itemID] or nil,
            -- Der Vergleich lief gegen ein Teil, dessen Wert nicht
            -- vollstaendig bezifferbar war. Die UI weist das aus, damit
            -- der Vorsprung nicht genauer wirkt, als er ist.
            incomplete = unscoredEquip and true or nil,
            locked    = (reqEff and reqEff > level) or nil,
            twoHand   = twoHand,
            offHandLoss = (offHandLoss > 0) and offHandLoss or nil,
            name      = entry.n,
            quality   = entry.q,
            reqLevel  = reqEff,
            dualWield  = dualWieldNeeded or nil,
            learnSkill = learnSkill or nil,
            srcLevel  = srcLevel,
            stats     = entry.st,
            diff      = diff,
            use       = entry.use,
            setInfo   = setInfo,
            statScore = statScore,
            useScore  = useScore,
            setScore  = setScore,
            estimated = estimated,
            score     = score,
            gain      = score - baseScore,
          })
        end
      end
    end
  end

  -- Items mit Fundort zuerst, danach erst die aus dem Import. Ein
  -- Vorschlag, zu dem ein Weg gehoert, ist brauchbarer als einer ohne -
  -- auch wenn der ohne ein paar Punkte mehr braechte. Innerhalb beider
  -- Gruppen entscheidet weiterhin der Zuwachs.
  table.sort(out, function(a, b)
    local ai = a.fromImport and 1 or 0
    local bi = b.fromImport and 1 or 0
    if ai ~= bi then return ai < bi end
    if a.gain == b.gain then return a.id < b.id end
    return a.gain > b.gain
  end)

  -- Nur die besten behalten und erst dafuer die Quellen aufloesen,
  -- weil die Quellensuche pro Item spuerbar kostet.
  -- Zugangsbedingung nachtragen und gesperrte Teile ueberspringen.
  --
  -- Die Bedingung steht im Tooltip, und den liest das Addon nur fuer
  -- Kandidaten, die es beim Server anfragen musste. Alles, was der
  -- Import mit Werten liefert, kommt nie an einem Tooltip vorbei - bei
  -- einem Stufe-15-Jaeger sind das 933 von 955 verwertbaren Kandidaten.
  -- Die Pruefung beim Einlesen erreichte so nur zwei Prozent.
  --
  -- Hier ist die Liste bereits sortiert, es geht also nur noch um eine
  -- Handvoll Teile. Kennt der Client eines davon, liefert der Scan die
  -- Bedingung ohne eine einzige Serveranfrage; kennt er es nicht,
  -- bleibt es drin. Das Ergebnis wandert in den Cache und gilt ab dann.
  --
  -- Gesperrte Teile werden uebersprungen, die naechsten ruecken nach -
  -- sonst bliebe die Liste kuerzer als gewuenscht.
  local showLocked = BananaLootlineDB and BananaLootlineDB.showLocked
  local trimmed = {}
  local taken, i, n = 0, 1, table.getn(out)

  local scanned = 0
  while taken < maxResults and i <= n and (not maxScan or scanned < maxScan) do
    local u = out[i]
    i = i + 1
    scanned = scanned + 1

    local entry = cache[u.id]
    if entry and entry.lock == nil then
      -- Zuerst AtlasLoot: dort steht die Bedingung als Datensatz und
      -- nicht als Text, den erst jemand ueberfahren muss.
      local atlas = self:AtlasRestriction(u.id)
      if atlas then
        entry.lock = atlas
      elseif BLL.Scanner then
        local _, meta = BLL.Scanner:GetStats(u.id)
        if meta and meta.restricted then entry.lock = meta.restricted end
      end
    end

    local lock = (entry and entry.lock) or self:RepLock(u.id)
    if lock and not showLocked then
      -- uebersprungen: nicht frei erhaeltlich
    else
      u.lockedBy = lock
      u.sources = BLL.Sources:GetItemSources(u.id)
      -- Erst jetzt steht fest, ob wirklich kein Fundort da ist: pfQuest
      -- kann ein Item fuehren und trotzdem keine erreichbare Quelle haben.
      if not u.sources or table.getn(u.sources) == 0 then
        u.noSource = true
      end
      if not accept or accept(u) then
        table.insert(trimmed, u)
        taken = taken + 1
      end
    end
  end

  return trimmed, baseScore
end

------------------------------------------------------------------
-- Lootline: nach Fundort gebuendelt
--
-- Die Slotansicht beantwortet "was ist fuer diesen Slot besser".
-- Diese hier beantwortet die praktischere Frage: "wohin soll ich
-- gehen" - alle Verbesserungen nach Ort gebuendelt, Orte nach Ertrag
-- sortiert. Ein Dungeon mit drei Upgrades schlaegt einen mit einem.
--
-- Gruppiert wird nach Zone. Quellen ohne Zone (Haendler, Quests ohne
-- Ortsangabe) landen in einer Sammelgruppe statt unter den Tisch zu
-- fallen.
------------------------------------------------------------------

------------------------------------------------------------------
-- Kategorie eines Fundorts
--
-- pfQuest fuehrt kein Kennzeichen "Instanz". Deshalb eine Liste der
-- bekannten Instanzen; alles andere gilt als Welt. Eigene Instanzen
-- des Servers fehlen darin zwangslaeufig und landen unter "Welt" -
-- lieber ein zu allgemeines Etikett als ein falsches.
------------------------------------------------------------------

-- Vergleich ueber eine normalisierte Form: Kleinschreibung, ohne
-- Leerzeichen und Sonderzeichen. Damit passen "Zul'Farrak",
-- "ZulFarrak" und "zul farrak" auf denselben Eintrag, egal wie
-- pfQuest die Zone schreibt.
local function normZone(name)
  if not name then return nil end
  local n = string.lower(name)
  n = string.gsub(n, "[^a-z0-9]", "")
  return n
end

-- Stammdaten aus Data/ZoneData.lua. Die frueher hier gepflegte Liste
-- ist entfallen: sie hatte zwei falsche Eintraege und kannte keine
-- Stufenbereiche.
BananaLootlineZoneData = BananaLootlineZoneData or {}

function Cand:ZoneInfo(zone)
  local key = normZone(zone)
  if not key then return nil end
  return BananaLootlineZoneData[key]
end

function Cand:Category(zone, stype)
  -- Eigene Zuordnung des Nutzers hat Vorrang. Die Liste unten kann
  -- serverspezifische Orte nicht vollstaendig kennen - mit /bll cat
  -- laesst sich jeder Ort korrigieren, ohne den Code anzufassen.
  local key = normZone(zone)
  if key and BananaLootlineDB and BananaLootlineDB.zoneCategory then
    local own = BananaLootlineDB.zoneCategory[key]
    if own then return own end
  end

  -- Der Ort entscheidet vor der Quellenart. Die Todesminen sind ein
  -- Dungeon, ob man wegen einer Quest oder wegen eines Drops hingeht;
  -- die Gruppe stand als [QUEST] da, weil die Questbelohnung das
  -- gewichtigste Teil war. Die Stufenangabe daneben stammt ohnehin aus
  -- derselben Tabelle.
  if key then
    local info = BananaLootlineZoneData[key]
    if info and info.c then return info.c end
  end

  if stype == "V" then return "HAENDLER" end
  if stype == "Q" then return "QUEST" end

  if stype == "O" or stype == "C" then return "OBJEKT" end
  return "WELT"
end

-- Fuer den Korrekturbefehl
function Cand:SetZoneCategory(zone, cat)
  local key = normZone(zone)
  if not key then return false end
  BananaLootlineDB.zoneCategory = BananaLootlineDB.zoneCategory or {}
  if cat then
    BananaLootlineDB.zoneCategory[key] = cat
  else
    BananaLootlineDB.zoneCategory[key] = nil
  end
  return true
end

-- Wahrscheinlichkeit, das Teil bei einem Besuch der Quelle zu bekommen.
-- Quest und Haendler: sicher. Ohne Angabe: als sicher behandeln statt
-- auf null zu setzen - unbekannt ist nicht unmoeglich, und
-- Unerreichbares filtert Sources bereits heraus.
-- Untergrenze fuer den Wegplan.
--
-- Der Wegplan beantwortet "wohin als naechstes". Ein Drop mit 0,0045 %
-- ist einer von 22000 und damit kein Ziel, zu dem man aufbricht. Genau
-- solche Zeilen standen unter [WORLD] Sumpfland: "Ranger Bow", "Feet of
-- the Lynx" und "Sentry Cloak", alle drei bei denselben drei Gegnern,
-- alle drei mit 0,0045 %. Es sind Weltdrops, die von fast allem fallen.
--
-- Die Grenze liegt bei einem Tausendstel. Unterhalb davon liegen 12,5 %
-- aller Gegnerquellen, oberhalb setzt die Verteilung mit 0,25 % wieder
-- dicht ein - dazwischen ist eine Luecke, und die ist die Grenze.
-- In der Einzelansicht bleiben diese Quellen sichtbar; sie sind nicht
-- falsch, sie taugen nur nicht als Reiseziel.
Cand.MIN_LOOTLINE_CHANCE = 0.1

function Cand:LootlineChanceFloor()
  local db = BananaLootlineDB
  if db and db.minLootlineChance then return db.minLootlineChance end
  return Cand.MIN_LOOTLINE_CHANCE
end

-- Wie stark die Dropchance den Zuwachs eines Teils im Wegplan daempft.
--
-- Bis 0.22.12 zaehlte Zuwachs mal Chance, der erwartete Gewinn pro
-- Besuch. Das bestrafte gute Dungeondrops zu stark: ein Boss mit 33 %
-- zaehlte ein Drittel, waehrend eine Questbelohnung voll zaehlte - und
-- in einem Dungeon erlegt man den Boss ohnehin bei jedem Lauf. So stand
-- Frostmane Hollow mit Belt of Binding (+12, 33 %) fuer einen Stufe-16-
-- Jaeger weit hinten. turtlelootline.com laesst die Chance ganz weg und
-- zaehlt einen 2-%-Drop wie einen sicheren.
--
-- Die Wurzel liegt dazwischen: 33 % zaehlt 0,58, 20 % zaehlt 0,45,
-- 2 % noch 0,14 und 0,1 % nur 0,03. Seltenes bleibt hinten, ein
-- brauchbarer Bossdrop nicht mehr.
function Cand:ChanceFactor(stype, chance)
  if stype == "Q" or stype == "V" then return 1 end
  if not chance then return 1 end
  local p = chance / 100
  if p > 1 then p = 1 end
  if p < 0 then p = 0 end
  return math.sqrt(p)
end

-- Wie viele Kandidaten je Platz der Wegplan hoechstens ansieht, um
-- maxPerSlot mit Fundort zu finden.
Cand.LOOTLINE_SCAN = 40

------------------------------------------------------------------
-- Quellenfilter (Dropdown "Quellen" in Lootline und Pro Item)
--
-- Vorschlag eines Testers: gezielt nur Dungeon-Beute, nur Quests usw.
-- Mehrfachauswahl, weil "Dungeon + Quest" der haeufigste Wunsch ist.
-- Die frueheren Haken "Haendler zeigen" und "Nur mit Fundort" gehen
-- darin auf: HAENDLER und NOSOURCE sind zwei Eintraege der Liste.
--
-- Jede Quelle hat genau eine Kategorie: Questbelohnung ist QUEST,
-- Haendlerware HAENDLER, alles andere die Kategorie seines Ortes. Wer
-- QUEST abwaehlt, verliert damit auch die Todesminen-Questbelohnung,
-- nicht aber die Drops dort.
------------------------------------------------------------------

Cand.SOURCE_CATS = { "DUNGEON", "RAID", "QUEST", "WELT", "SCHLACHTFELD",
                     "WELTBOSS", "HAENDLER", "NOSOURCE" }
Cand.SOURCE_DEFAULT_OFF = { HAENDLER = true, NOSOURCE = true }

function Cand:SourceFilter()
  local db = BananaLootlineDB
  if not db then return {} end
  if not db.sourceFilter then
    local f = {}
    for _, c in ipairs(self.SOURCE_CATS) do f[c] = not self.SOURCE_DEFAULT_OFF[c] end
    -- Alte Haken uebernehmen
    if db.showVendors then f.HAENDLER = true end
    if db.showUnsourced then f.NOSOURCE = true end
    db.sourceFilter = f
  end
  return db.sourceFilter
end

function Cand:SetSourceCat(cat, on)
  self:SourceFilter()[cat] = on and true or false
end

function Cand:RowCategory(src)
  if src.stype == "Q" then return "QUEST" end
  if src.stype == "V" then return "HAENDLER" end
  local c = self:Category(src.zone, src.stype)
  if c == "OBJEKT" or c == "QUEST" or c == "HAENDLER" then return "WELT" end
  return c
end

-- Eine Kategorie, die das Menue nicht kennt (eigene /bll cat-Zuordnung
-- mit unbekanntem Wert), wird nicht weggefiltert.
function Cand:SourceAllowed(src)
  local v = self:SourceFilter()[self:RowCategory(src)]
  if v == nil then return true end
  return v
end

-- Filter fuer "Pro Item": nil heisst alles erlaubt.
function Cand:SlotViewAccept()
  local f = self:SourceFilter()
  local all = true
  for _, c in ipairs(self.SOURCE_CATS) do if not f[c] then all = false end end
  if all then return nil end
  return function(u)
    if not u.sources or table.getn(u.sources) == 0 then return f.NOSOURCE and true or false end
    for i = 1, table.getn(u.sources) do
      if Cand:SourceAllowed(u.sources[i]) then return true end
    end
    return false
  end
end

------------------------------------------------------------------
-- Die Quelle, ueber die ein Teil im Wegplan steht, oder nil.
--
-- Die erste Quelle (nach Chance sortiert), die der Quellenfilter
-- zulaesst, einen Ort hat - oder eine Quest ist, "Quests" ist eine
-- brauchbare Auskunft - und nicht zu unwahrscheinlich ist. Hat die
-- beste Quelle keinen Ort, eine schlechtere aber schon, dann ist die
-- schlechtere hier die brauchbare: ein Ziel mit halber Chance schlaegt
-- eines, zu dem niemand hinfindet. Haendlerware steht standardmaessig
-- nicht im Wegplan: sie zaehlt voll, ein Drop nur nach Chance, und
-- verdraengte sonst jedes Ziel, zu dem man hingehen wuerde.
------------------------------------------------------------------

function Cand:LootlineSource(item)
  if not item.sources then return nil end
  for i = 1, table.getn(item.sources) do
    local s = item.sources[i]
    if self:SourceAllowed(s) and (s.zone or s.stype == "Q") then
      local tooRare = s.stype ~= "Q" and s.stype ~= "V" and s.chance
                      and s.chance < self:LootlineChanceFloor()
      if not tooRare then return s end
    end
  end
  return nil
end

function Cand:GetLootline(maxPerSlot)
  if not self.pool then return nil end
  maxPerSlot = maxPerSlot or 3

  local groups, order = {}, {}
  local seenItem = {}

  -- Bester bisher gezaehlter Zuwachs je Quest. pfQuest trennt feste
  -- Belohnungen nicht von Auswahlbelohnungen. Bei einer Auswahl bekommt
  -- man genau ein Teil - zaehlten alle, stuende eine Quest mit vier
  -- Wahlmoeglichkeiten viermal so hoch wie sie wert ist. Deshalb zaehlt
  -- je Quest nur das beste Teil. Seltene Quests mit mehreren festen
  -- Belohnungen werden damit unterschaetzt; das ist der kleinere Fehler.
  local questBest = {}
  local questItems = {}

  for i = 1, table.getn(BLL.Gear.SLOTS) do
    local slot = BLL.Gear.SLOTS[i]
    -- Nur Kandidaten, zu denen ein Weg fuehrt. Frueher kamen die drei
    -- besten je Platz herein und erst danach flogen die ohne Ort
    -- heraus - beim Guertel eines Stufe-16-Jaegers waren das drei
    -- hergestellte oder unverortete Teile, und "Belt of Binding" aus
    -- Frostmane Hollow (33 %) kam nie in Betracht.
    local ups, baseScore = self:GetUpgrades(slot.key, maxPerSlot,
      function(u) return Cand:LootlineSource(u) ~= nil end, Cand.LOOTLINE_SCAN)

    for u = 1, table.getn(ups or {}) do
      local item = ups[u]

      -- Ein Item kann in zwei Slots passen (Ringe, Schmuck, Waffen).
      -- Nur einmal zaehlen, sonst wird der Ort doppelt gewichtet.
      -- Ein Item, dessen einzige Quelle ein Entwicklereintrag ist,
      -- gehoert nicht in einen Wegplan: man kann es nicht bekommen.
      local best = self:LootlineSource(item)
      local hasSource = best ~= nil
      local zone, sourceName, chance, stype, questLevel, questID
      local elite, sourceLevel
      if best then
        elite = best.elite
        sourceLevel = best.level
        zone = best.zone
        sourceName = best.name
        chance = best.chance
        stype = best.stype
        questLevel = best.questLevel
        if stype == "Q" then questID = best.id end
      end

      if not seenItem[item.id] and hasSource then
        seenItem[item.id] = true

        local key = zone or "Quests"

        if not groups[key] then
          local info = self:ZoneInfo(zone)
          groups[key] = {
            zone     = key,
            category = self:Category(zone, stype),
            catGain  = -1,
            lvlRange = info and info.lvl,
            minLevel = info and info.min,
            acronym  = info and info.acr,
            items = {}, priority = 0,
          }
          table.insert(order, groups[key])
        end

        local g = groups[key]

        -- Die Beschriftung richtet sich nach dem gewichtigsten Teil der
        -- Gruppe, nicht nach dem zuerst eingereihten. Sonst entscheidet
        -- die Reihenfolge der Ruestungsplaetze darueber, ob ein Ort
        -- [QUEST] oder [WORLD] heisst: das Barrens stand als [QUEST] da,
        -- obwohl zwei seiner drei Teile von seltenen Elitegegnern fallen.
        if item.gain and item.gain > (g.catGain or -1) then
          g.catGain  = item.gain
          g.category = self:Category(zone, stype)
        end
        if questID then
          -- Nur den Teil des Zuwachses addieren, der ueber dem bisher
          -- besten Teil derselben Quest liegt. Die Summe je Quest ist
          -- damit unabhaengig von der Slotreihenfolge ihr Maximum.
          -- Questbelohnungen sind sicher: Faktor 1.
          local prev = questBest[questID] or 0
          if item.gain > prev then
            g.priority = g.priority + (item.gain - prev)
            questBest[questID] = item.gain
          end
        else
          -- Erwarteter Zuwachs pro Besuch: Zuwachs mal Dropchance.
          -- Vorher zaehlte der volle Zuwachs, und ein Ort mit drei 1-%-
          -- Drops schlug einen mit einem 75-%-Drop. Haendler sind sicher.
          g.priority = g.priority + item.gain * self:ChanceFactor(stype, chance)
        end
        local row = {
          id       = item.id,
          locked   = item.locked,
          twoHand  = item.twoHand,
          reqLevel = item.reqLevel,
          learnSkill = item.learnSkill,
          name     = item.name,
          quality  = item.quality,
          slot     = slot.key,
          slotName = BLL.Gear:SlotLabel(slot),
          gain     = item.gain,
          stype    = stype,
          questLevel = questLevel,
          -- Prozentualer Zuwachs gegenueber dem angelegten Teil. Eine
          -- absolute Punktzahl sagt nichts, solange man die Skala nicht
          -- kennt; "+750%" ist sofort verstaendlich. Bei leerem Slot
          -- gibt es keinen Bezugswert, dann steht NEU.
          pct      = (baseScore and baseScore > 0)
                     and (item.gain / baseScore * 100) or nil,
          isNew    = (BLL.Gear.equipped[slot.key] == nil),
          source   = sourceName,
          chance   = chance,
          -- Elite und Bosse bedeuten Gruppe, Selten bedeutet warten.
          -- "Forest Leather Gloves" fallen zu 1,6 % von Humar the
          -- Pridelord - einem seltenen Elitegegner auf Stufe 23. Ohne
          -- diese Angabe liest sich die Zeile wie ein normaler Drop,
          -- und ein Stufe-15-Jaeger laeuft allein los.
          elite       = elite,
          sourceLevel = sourceLevel,
          setInfo  = item.setInfo,
          questID  = questID,
        }
        table.insert(g.items, row)
        if questID then
          questItems[questID] = questItems[questID] or {}
          table.insert(questItems[questID], row)
        end
      end
    end
  end

  -- Auswahl kenntlich machen: bei mehreren Teilen aus derselben Quest
  -- erfaehrt jede Zeile, wie viele zur Wahl stehen und ob sie die
  -- beste ist. Die Anzeige braucht das, sonst wirkt der Ort ergiebiger
  -- als seine Prioritaet.
  for qid, rows in pairs(questItems) do
    local n = table.getn(rows)
    if n > 1 then
      for r = 1, n do
        rows[r].choiceOf = n
        rows[r].choiceBest = (rows[r].gain >= questBest[qid])
      end
    end
  end

  -- Innerhalb eines Ortes das Wertvollste zuerst
  for i = 1, table.getn(order) do
    table.sort(order[i].items, function(a, b) return a.gain > b.gain end)
  end

  -- Orte nach Gesamtertrag
  table.sort(order, function(a, b) return a.priority > b.priority end)

  return order
end

------------------------------------------------------------------
-- Bequemer Einstieg
------------------------------------------------------------------

-- Das Stufenband, das die Suche abdeckt. Ohne Argument entscheidet die
-- gespeicherte Vorausplanung - das ist der Punkt, an dem /bll ahead
-- ueberhaupt erst auf die Suche wirkt.
------------------------------------------------------------------
-- Diagnose: warum steht ein Teil (nicht) in der Liste?
--
-- Entstanden, weil "Belt of Binding" im Spiel fehlte, in der
-- Nachstellung mit denselben Daten aber oben stand. Was zwischen
-- beiden liegt - gespeicherter Itemcache, AtlasLoot, pfQuest im
-- Client -, sieht man nur im Spiel. Gibt Zeilen zurueck, keine Texte
-- fuer den Spieler, deshalb ohne Uebersetzung.
------------------------------------------------------------------

function Cand:Explain(itemID)
  local out = {}
  local function add(t) table.insert(out, t) end
  local player = BLL.player or {}
  local level = player.level or 60

  local db = BLL.ItemDB and BLL.ItemDB:Get(itemID)
  if db then
    local n = 0
    for _ in pairs(db.stats or {}) do n = n + 1 end
    add("ItemDB: " .. (db.name or "?") .. " slot=" .. tostring(db.slot)
      .. " req=" .. tostring(db.reqlevel) .. " ilvl=" .. tostring(db.ilvl)
      .. " class=" .. tostring(db.itemclass) .. "/" .. tostring(db.subclass)
      .. " stats=" .. n)
  else
    add("ItemDB: -")
  end

  if not self.pool then
    add("pool: noch keine Suche gelaufen / no search yet")
  else
    add("pool: " .. (self.pool[itemID] and ("ja/yes " .. self.pool[itemID]) or "NEIN/NO")
      .. ((self.fromImport and self.fromImport[itemID]) and " (ohne Fundort/no source, sortiert hinten)" or "")
      .. "  band " .. table.concat({ self:Band() }, "-"))
  end

  local c = BananaLootlineDB.itemcache and BananaLootlineDB.itemcache[itemID]
  if not c then
    add("cache: -")
  else
    local parts = {}
    for _, k in ipairs({ "skip", "pre", "fail", "db", "cv", "r", "e", "a", "ic", "sc", "cm" }) do
      if c[k] ~= nil then table.insert(parts, k .. "=" .. tostring(c[k])) end
    end
    add("cache: " .. table.concat(parts, " "))
    if c.lock then add("cache lock: " .. tostring(c.lock)) end
    local atlas = self:AtlasRestriction(itemID)
    if atlas then add("AtlasLoot: " .. atlas) end
    add("usable: " .. tostring(self:IsUsable(c, player.class, level,
      self:SuggestArmor(player.class, level), itemID))
      .. (self:ShowLighterArmor() and "" or " (armor: own type only)"))
    local slots = self.INVTYPE_SLOTS[c.e or ""]
    if slots and BLL.Weights and BLL.Gear then
      local isWeapon = WEAPON_SLOTS[slots[1]]
      local eq = BLL.Gear.equipped[slots[1]]
      local base = eq and BLL.Weights:Score(eq.stats, isWeapon) or 0
      add(string.format("score %.1f vs %s %.1f", BLL.Weights:Score(c.st, isWeapon),
        slots[1], base))
    end
  end

  local src = BLL.Sources and BLL.Sources:GetItemSources(itemID)
  if not src or table.getn(src) == 0 then
    add("sources: -")
  else
    local s1 = src[1]
    add("sources: " .. table.getn(src) .. ", " .. tostring(s1.name) .. " "
      .. tostring(s1.chance) .. "% " .. tostring(s1.zone))
  end
  return out
end

function Cand:Band(span)
  span = span or self:PlanAhead()
  local level = (BLL.player and BLL.player.level) or 60
  local minLvl = math.max(1, level - Lookback(level))
  local maxLvl = math.min(MAX_SOURCE_LEVEL, level + span)
  if maxLvl < minLvl then maxLvl = minLvl end
  return minLvl, maxLvl
end

-- span setzt die Vorausplanung fuer diesen einen Lauf ausser Kraft,
-- gespeichert wird sie dadurch nicht.
function Cand:Run(span)
  -- Ruf bei jeder Suche frisch lesen: er aendert sich im Spiel.
  self:ReadReputation()
  local minLvl, maxLvl = self:Band(span)
  return self:StartIndex(minLvl, maxLvl)
end

------------------------------------------------------------------
-- Diagnose fuer /bll selftest
--
-- Spielt die beiden Schritte, die den Pool fuellen, einmal am Stueck
-- und geschuetzt durch: wie viele Items pfQuest und der Import fuer das
-- aktuelle Band liefern wuerden, und ob dabei ein Fehler auftritt.
-- Dazu der Zustand der laufenden oder letzten Suche.
------------------------------------------------------------------

function Cand:Diagnose()
  local d = { state = self.state or "idle", lastError = self.lastError }
  local now = GetTime and GetTime() or 0
  local running = d.state == "indexing" or d.state == "indexdb" or d.state == "requesting"
               or d.state == "waiting" or d.state == "collecting"
  if running then
    local last = self.lastTick or self.startedAt or now
    d.idleFor = now - last
    d.stuck = d.idleFor > 5
  end

  local lo, hi = self:Band()
  local band = { min = lo, max = hi }
  local items = BLL.Sources and BLL.Sources.items
  d.pfqTotal, d.pfqBand = 0, 0
  if items then
    local ok, err = pcall(function()
      for key, entry in pairs(items) do
        d.pfqTotal = d.pfqTotal + 1
        if type(entry) == "table" then
          local lvl = self:SourceLevel(key, entry, band)
          if lvl and lvl >= lo and lvl <= hi then d.pfqBand = d.pfqBand + 1 end
        end
      end
    end)
    if not ok then d.pfqError = tostring(err) end
  end

  d.importBand = 0
  local data = BLL.ItemDB and BLL.ItemDB.data
  if data then
    local ok, err = pcall(function()
      local maxReq, minIlvl, class = self:ImportBounds()
      for _, e in pairs(data) do
        if type(e) == "table" and ImportAccepts(e, ImportReq(e), maxReq, minIlvl, class) then
          d.importBand = d.importBand + 1
        end
      end
    end)
    if not ok then d.importError = tostring(err) end
  end
  return d
end

------------------------------------------------------------------
-- Motor
------------------------------------------------------------------

local driver = CreateFrame("Frame", "BananaLootlineCandidateDriver")

-- Neue Waffenfertigkeit gelernt oder Talent gesetzt: beim naechsten
-- Bewerten neu einlesen.
if driver.RegisterEvent then
  driver:RegisterEvent("SKILL_LINES_CHANGED")
  driver:RegisterEvent("CHARACTER_POINTS_CHANGED")
  driver:SetScript("OnEvent", function() Cand.skillsDirty = true end)
end
-- Ein Schritt der Suche. Laeuft geschuetzt: ein Fehler in einem Schritt
-- liess die Suche frueher still sterben. Das Fenster zeigte dann "nichts
-- Besseres gefunden", und weil manche Fehler-Addons das Lua-Popup
-- schlucken, sah niemand den Grund (gemeldet von einem Tester auf Stufe
-- 45: Pool 0, keine Fehlermeldung).
local function Step(elapsed)
  if Cand.state == "indexing" then
    Cand:IndexChunk()

  elseif Cand.state == "indexdb" then
    Cand:ImportChunk()

  elseif Cand.state == "requesting" then
    Cand:RequestTick(elapsed)

  elseif Cand.state == "waiting" then
    waitTimer = waitTimer - elapsed
    if waitTimer <= 0 then
      Cand.state = "collecting"
    end

  elseif Cand.state == "collecting" then
    Cand:CollectTick()
  end
end

-- Fehler festhalten, Suche anhalten und laut melden.
function Cand:Fail(step, err)
  self.state = "failed"
  self.lastError = { step = step, msg = tostring(err) }
  BLL:Print("|cffff3333" .. string.format(L["CAND_ERROR"], step, tostring(err)) .. "|r")
  BLL:Print("|cffff8800" .. L["CAND_ERROR_HINT"] .. "|r")
  if BLL.UI and BLL.UI.frame and BLL.UI.frame:IsVisible() and BLL.UI.Refresh then
    pcall(BLL.UI.Refresh, BLL.UI)
  end
end

function Cand:Tick(elapsed)
  local st = self.state
  if st ~= "indexing" and st ~= "indexdb" and st ~= "requesting"
     and st ~= "waiting" and st ~= "collecting" then
    return
  end
  self.lastTick = GetTime and GetTime() or 0
  local ok, err = pcall(Step, elapsed)
  if not ok then self:Fail(st, err) end
end

driver:SetScript("OnUpdate", function()
  Cand:Tick(arg1 or 0)
end)
