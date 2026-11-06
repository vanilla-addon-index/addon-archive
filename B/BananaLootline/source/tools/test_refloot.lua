-- Referenz-Loottabellen.
--
-- Ein Gegenstand kann statt an einem Mob an einer geteilten Loottabelle
-- haengen, die wiederum mehreren Mobs zugeordnet ist. Der Code las
-- dafuer entry["L"] - das Feld heisst in allen drei geprueften
-- Datenpaketen aber "R". Der Zweig lief damit immer ins Leere.
--
-- Im OctoWoW-Datenstand betrifft das 706 Gegenstaende, davon 247 ohne
-- jede andere Quelle: die standen in der Vorschlagsliste ohne Fundort
-- und fielen aus dem Wegplan heraus.
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
                SetHyperlink = function() end, Show = function() end }
getglobal = function() return nil end

BananaLootline = {}
GetLocale = function() return "enUS" end
dofile("Locale.lua")
local BLL = BananaLootline
BLL.Print, BLL.Debug = function() end, function() end
dofile("Scanner.lua")

BananaLootlineDB = { tooltipSources = false, itemcache = {}, minDropChance = 0 }

-- Datenbank nachbilden: Gegenstand 500 haengt NUR an einer
-- Referenztabelle, Gegenstand 501 zusaetzlich an einem Mob.
pfDB = {
  items = { data = {
      [500] = { R = { [9001] = 100 } },
      [501] = { U = { [70] = 5 }, R = { [9001] = 50 } },
    }, loc = {} },
  units = { data = {
      [60] = { lvl = "40", coords = {} },
      [61] = { lvl = "42", coords = {} },
      [70] = { lvl = "38", coords = {} },
    }, loc = { [60] = "Grosser Wurm", [61] = "Kleiner Wurm", [70] = "Ein Mob" } },
  quests  = { data = {}, loc = {} },
  objects = { data = {}, loc = {} },
  refloot = { data = { [9001] = { U = { [60] = 20, [61] = 10 } } } },
  zones   = {},
}

dofile("Sources.lua")
local S = BLL.Sources
S:Init()

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

check(S.available, "pfQuest-Daten werden erkannt")
check(S.refloot ~= nil, "Referenztabellen sind geladen")

------------------------------------------------------------------
-- 1. Gegenstand NUR ueber die Referenztabelle
------------------------------------------------------------------

local list = S:GetItemSources(500)
local n = table.getn(list or {})
check(n == 2, "beide Mobs der Referenztabelle gefunden, waren " .. n)

local names = {}
for i = 1, n do names[list[i].name or "?"] = list[i] end
check(names["Grosser Wurm"] ~= nil, "erster Mob aufgeloest")
check(names["Kleiner Wurm"] ~= nil, "zweiter Mob aufgeloest")

-- Die Chance ist das Produkt beider Stufen: 100 % der Tabelle, davon
-- 20 % beim Mob.
if names["Grosser Wurm"] then
  check(names["Grosser Wurm"].chance == 20,
    "Dropchance zusammengerechnet, war " .. tostring(names["Grosser Wurm"].chance))
end
if names["Kleiner Wurm"] then
  check(names["Kleiner Wurm"].chance == 10,
    "zweite Dropchance zusammengerechnet, war " .. tostring(names["Kleiner Wurm"].chance))
end

------------------------------------------------------------------
-- 2. Direkte Quelle und Referenztabelle zusammen
------------------------------------------------------------------

list = S:GetItemSources(501)
n = table.getn(list or {})
check(n == 3, "direkte Quelle plus zwei aus der Tabelle, waren " .. n)

------------------------------------------------------------------
-- 3. Die alte Schreibweise wird weiterhin gelesen
--
-- Falls ein Datenpaket doch ["L"] fuehrt, darf nichts verlorengehen.
------------------------------------------------------------------

pfDB.items.data[502] = { L = { [9001] = 100 } }
list = S:GetItemSources(502)
check(table.getn(list or {}) == 2,
  "Schreibweise L wird weiterhin aufgeloest, waren "
  .. table.getn(list or {}))

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
