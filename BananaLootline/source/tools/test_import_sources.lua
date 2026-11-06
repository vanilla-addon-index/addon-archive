-- Der neue Weg in Sources.lua: der Import gewinnt, pfQuest bleibt
-- Rueckfall und liefert nur noch die Karte.
--
-- Geprueft wird, was sich beim Umbau brechen laesst:
--   1. Import vorhanden -> seine Zahlen erscheinen, pfQuests nicht
--   2. Import kennt den Gegenstand nicht -> pfQuest wird gelesen
--   3. pfQuest fehlt ganz -> der Import traegt allein
--   4. Fraktion: ein Hordenhaendler erscheint bei einem Allianzcharakter
--      nicht
--   5. Der Stufenfilter greift auch auf Importzeilen
string.gmatch = nil; select = nil

CreateFrame = function()
  return { SetScript = function() end, RegisterEvent = function() end,
           SetOwner = function() end, ClearLines = function() end,
           Hide = function() end, SetHyperlink = function() end,
           NumLines = function() return 0 end }
end
WorldFrame = {}
GetItemInfo = function() return nil end
GameTooltip = { AddLine = function() end, NumLines = function() return 0 end,
                GetName = function() return "GameTooltip" end,
                SetHyperlink = function() end, IsShown = function() return false end }
getglobal = function() return nil end

local faction = "Horde"
UnitFactionGroup = function() return faction end

BananaLootline = {}
GetLocale = function() return "enUS" end
dofile("Locale.lua")
local BLL = BananaLootline
BLL.Print, BLL.Debug = function() end, function() end
dofile("Scanner.lua")

BananaLootlineDB = { tooltipSources = false, itemcache = {}, minDropChance = 0,
                     planAhead = 6 }

------------------------------------------------------------------
-- Datenstand
--
-- 5001 steht in beiden Quellen mit verschiedenen Zahlen. Genau der Fall
-- aus dem Bericht zu "Feet of the Lynx": pfQuest nennt einen Gegner
-- jenseits von Stufe 60 mit 1,92 Prozent, der Server kennt nur Mobs im
-- Stufenbereich des Gegenstands mit Bruchteilen eines Prozents.
-- 5002 kennt nur pfQuest.
-- 5003 ist ein Hordenhaendler.
-- 5004 haengt an einem Gegner auf Stufe 61.
------------------------------------------------------------------

BananaLootlineSourceData = {
  [5001] = { d = { { n = 200, l = 23, z = 10, p = 0.0045, e = 2 },
                   { n = 201, l = 24, z = 11, p = 0.0009 } } },
  [5003] = { v = { { n = 300, z = 17, c = 9126, f = 2,
                     t = "Warsong Supply Officer" } } },
  [5004] = { d = { { n = 400, l = 61, z = 10, p = 5 } } },
  [5005] = { q = { { q = 6, t = "Bounty on Garrick Padfoot", l = 2, x = 3,
                     z = 10, g = 200 } } },
}

BananaLootlineNpcNames = {
  [200] = "Aean Swiftriver", [201] = "Bramblethorn Boar",
  [300] = "Kelm Hargunth",   [400] = "Eroded Anubisath Warbringer",
}

BananaLootlineZoneNames = {
  [10] = "Duskwood", [11] = "Wetlands", [17] = "The Barrens",
}

pfDB = {
  items = { data = {
      -- pfQuests Angabe zu 5001: ein Endgame-Gegner mit 1,92 Prozent
      [5001] = { U = { [999] = 1.92 } },
      [5002] = { U = { [201] = 3.5 } },
    }, loc = {} },
  units = { data = {
      [999] = { lvl = "61", coords = { { 50, 50, 10, 0 } } },
      [201] = { lvl = "24", coords = { { 40, 40, 11, 0 } } },
    }, loc = {
      [999] = "Eroded Anubisath Warbringer",
      [201] = "Bramblethorn Boar",
    } },
  quests  = { data = {}, loc = {} },
  objects = { data = {}, loc = {} },
  refloot = { data = {} },
  zones   = { loc = { [10] = "Duskwood", [11] = "Wetlands" } },
}

dofile("Sources.lua")
local S = BLL.Sources
S:Init()
BLL.Candidates = { PlanAhead = function() return 6 end }
BLL.player = { class = "HUNTER", level = 19 }

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local function byName(list)
  local out = {}
  for i = 1, table.getn(list or {}) do out[list[i].name or "?"] = list[i] end
  return out
end

------------------------------------------------------------------
-- 1. Der Import gewinnt
------------------------------------------------------------------

local list = S:GetItemSources(5001)
local got = byName(list)
check(table.getn(list or {}) == 2, "zwei Importquellen, waren "
  .. table.getn(list or {}))
check(got["Eroded Anubisath Warbringer"] == nil,
  "pfQuests Stufe-61-Gegner erscheint nicht mehr")
check(got["Aean Swiftriver"] ~= nil, "der Gegner aus dem Import erscheint")
check(got["Aean Swiftriver"] and got["Aean Swiftriver"].chance == 0.0045,
  "die Chance kommt aus dem Import, nicht aus pfQuest")
check(got["Aean Swiftriver"] and got["Aean Swiftriver"].zone == "Duskwood",
  "die Zone ist aufgeloest")
check(got["Aean Swiftriver"] and got["Aean Swiftriver"].elite == 2,
  "die Elitekennung kommt mit")
check(got["Aean Swiftriver"] and got["Aean Swiftriver"].imported,
  "die Zeile ist als Import markiert")

-- Sortierung: die bessere Chance steht oben
check(list[1].chance >= list[2].chance, "nach Chance absteigend sortiert")

------------------------------------------------------------------
-- 2. Rueckfall auf pfQuest
------------------------------------------------------------------

list = S:GetItemSources(5002)
check(table.getn(list or {}) == 1, "pfQuest liefert die einzige Quelle")
check(list and list[1] and list[1].imported == nil,
  "die Zeile ist nicht als Import markiert")
check(list and list[1] and list[1].chance == 3.5,
  "pfQuests Chance kommt durch, wenn der Import nichts weiss")

------------------------------------------------------------------
-- 3. Fraktion
------------------------------------------------------------------

list = S:GetItemSources(5003)
check(table.getn(list or {}) == 1, "der Hordenhaendler erscheint fuer Horde")
check(list and list[1] and list[1].cost == 9126, "der Preis kommt mit")
check(list and list[1] and list[1].tag == "Warsong Supply Officer",
  "die Marke des Quartiermeisters kommt mit")
check(list and list[1] and list[1].sure, "ein Haendler ist eine sichere Quelle")

faction = "Alliance"
S.raceMask = nil
list = S:GetItemSources(5003)
check(list == nil, "fuer Allianz erscheint der Hordenhaendler nicht")
faction = "Horde"
S.raceMask = nil

------------------------------------------------------------------
-- 4. Stufenfilter auf Importzeilen
--
-- 5004 haengt an einem Gegner auf Stufe 61 mit guter Chance. Fuer einen
-- Stufe-19-Charakter mit Vorausplanung 6 liegt die Grenze bei 35.
------------------------------------------------------------------

check(S:GetItemSources(5004) == nil,
  "der Stufe-61-Gegner faellt fuer einen Stufe-19-Charakter raus")

BLL.player.level = 60
check(table.getn(S:GetItemSources(5004) or {}) == 1,
  "auf Stufe 60 ist er eine gueltige Quelle")
BLL.player.level = 19

------------------------------------------------------------------
-- 5. Questbelohnung
--
-- pfQuest hat unter ["Q"] keinen einzigen Eintrag. Diese Zeile kann es
-- dort also gar nicht geben.
------------------------------------------------------------------

list = S:GetItemSources(5005)
check(table.getn(list or {}) == 1, "die Questbelohnung erscheint")
check(list and list[1] and list[1].stype == "Q", "als Questquelle")
check(list and list[1] and list[1].name == "Bounty on Garrick Padfoot",
  "mit dem Questtitel")
check(list and list[1] and list[1].choices == 3,
  "als eine von drei Auswahlbelohnungen")
check(list and list[1] and list[1].questLevel == 2, "mit Mindeststufe")
check(list and list[1] and list[1].zone == "Duskwood",
  "und mit dem Ort des Questgebers - sonst faellt sie aus dem Wegplan")
check(list and list[1] and list[1].giver == "Aean Swiftriver",
  "der Questgeber ist benannt")

------------------------------------------------------------------
-- 6. Ohne pfQuest traegt der Import allein
------------------------------------------------------------------

pfDB = nil
S:Init()
check(S.available, "ohne pfQuest bleibt die Quellenanzeige verfuegbar")
list = S:GetItemSources(5001)
check(table.getn(list or {}) == 2, "der Import liefert auch ohne pfQuest")
check(list and list[1] and list[1].name == "Aean Swiftriver",
  "der Name kommt aus NpcData.lua")
check(list and list[1] and list[1].zone == "Duskwood",
  "die Zone kommt aus ZoneNames.lua")
check(S:GetItemSources(5002) == nil,
  "was nur pfQuest kannte, ist ohne pfQuest weg")

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
