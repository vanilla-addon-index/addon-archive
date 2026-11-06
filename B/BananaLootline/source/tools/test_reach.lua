-- Quellen weit ueber der eigenen Stufe.
--
-- "Feet of the Lynx" ist ab Stufe 19 tragbar. pfQuest fuehrt als beste
-- Quelle den "Eroded Anubisath Warbringer" mit 1,92 % - einen Gegner
-- jenseits von Stufe 60. Fuer einen Stufe-15-Jaeger stand damit ein
-- Ziel ganz oben im Wegplan, an das er nicht herankommt.
--
-- Die OctoWoW-Datenbank kennt fuer dasselbe Teil 473 Mobs zwischen
-- Stufe 15 und 35, keinen ueber 0,0045 %. Die Quellenangaben stammen
-- aus dem Vanilla-Datenstand und stimmen fuer diesen Server nicht.
-- Dieser Filter behebt nicht die falschen Daten, sondern haelt
-- wenigstens die unerreichbaren Ziele aus dem Wegplan.
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

BananaLootline = {}
GetLocale = function() return "enUS" end
dofile("Locale.lua")
local BLL = BananaLootline
BLL.Print, BLL.Debug = function() end, function() end
dofile("Scanner.lua")

BananaLootlineDB = { tooltipSources = false, itemcache = {}, minDropChance = 0,
                     planAhead = 6 }

-- Genau der Fall aus dem Bericht: ein Endgame-Gegner und zwei Mobs im
-- Stufenbereich des Gegenstands.
pfDB = {
  items = { data = {
      [1121] = { U = { [15810] = 1.92, [200] = 0.0045, [201] = 0.0009 } },
    }, loc = {} },
  units = { data = {
      [15810] = { lvl = "61", coords = {} },
      [200]   = { lvl = "24", coords = {} },
      [201]   = { lvl = "21", coords = {} },
    }, loc = {
      [15810] = "Eroded Anubisath Warbringer",
      [200]   = "Aean Swiftriver",
      [201]   = "Bramblethorn Boar",
    } },
  quests  = { data = {}, loc = {} },
  objects = { data = {}, loc = {} },
  refloot = { data = {} },
  zones   = {},
}

dofile("Sources.lua")
local S = BLL.Sources
S:Init()

-- Die Vorausplanung kommt aus Candidates; hier genuegt eine Attrappe.
BLL.Candidates = { PlanAhead = function() return 6 end }

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local function names(level)
  BLL.player = { class = "HUNTER", level = level }
  local list = S:GetItemSources(1121)
  local out = {}
  for i = 1, table.getn(list or {}) do out[list[i].name or "?"] = list[i] end
  return out, table.getn(list or {})
end

------------------------------------------------------------------
-- 1. Stufe 15: der Endgame-Gegner faellt raus
------------------------------------------------------------------

local got, n = names(15)
check(got["Eroded Anubisath Warbringer"] == nil,
  "Stufe-61-Gegner erscheint nicht bei einem Stufe-15-Charakter")
check(got["Aean Swiftriver"] ~= nil, "erreichbarer Gegner bleibt")
check(got["Bramblethorn Boar"] ~= nil, "zweiter erreichbarer Gegner bleibt")
check(n == 2, "genau zwei Quellen uebrig, waren " .. n)

------------------------------------------------------------------
-- 2. Stufe 60: derselbe Gegner ist jetzt erreichbar
------------------------------------------------------------------

got, n = names(60)
check(got["Eroded Anubisath Warbringer"] ~= nil,
  "auf Stufe 60 ist der Gegner eine gueltige Quelle")
check(n == 3, "alle drei Quellen sichtbar, waren " .. n)

------------------------------------------------------------------
-- 3. Die Grenze ist grosszuegig genug fuer Instanzen
--
-- Ein Stufe-15-Charakter geht in die Todesminen, wo Gegner bis Stufe 21
-- stehen. Mit Vorausplanung 6 und Zuschlag 5 liegt die Grenze bei 26.
------------------------------------------------------------------

pfDB.items.data[1122] = { U = { [300] = 5 } }
pfDB.units.data[300] = { lvl = "21", coords = {} }
pfDB.units.loc[300]  = "Defias Overseer"
S:Init()

BLL.player = { class = "HUNTER", level = 15 }
local list = S:GetItemSources(1122)
check(table.getn(list or {}) == 1,
  "Instanzgegner auf Stufe 21 bleibt fuer einen Stufe-15-Charakter sichtbar")

-- Ohne Vorausplanung wird die Grenze enger, der Gegner bleibt aber drin
BLL.Candidates.PlanAhead = function() return 0 end
list = S:GetItemSources(1122)
check(table.getn(list or {}) == 1,
  "auch ohne Vorausplanung bleibt er sichtbar (15 + 0 + 10 = 25)")

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
