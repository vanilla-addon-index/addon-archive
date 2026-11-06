-- Zonennamen und ihre Platzhalter.
--
-- Im Wegplan stand eine Gruppe, die buchstaeblich "??? (37)" hiess.
-- Die Daten dahinter stimmten - vier Bosse auf Stufe 63 mit Beute auf
-- Itemlevel 92 bis 96 -, nur der Name war ein Platzhalter, den pfQuest
-- fuer unbenannte Zonen einsetzt.
--
-- Die Ursache war die Reihenfolge der Datenpakete: ein Paket fuehrte
-- fuer Zone 5557 "???", ein anderes den echten Namen "The Rock of
-- Desolation". Das spaeter gelesene Paket gewann, und das war das mit
-- dem Platzhalter. Jetzt werden Platzhalter beim Import uebersprungen,
-- und der echte Name setzt sich durch.
--
-- Zusaetzlich faengt das Addon zur Laufzeit ab, was dennoch ohne Namen
-- bleibt: lieber "Zone 5557" als Gruppenname - daran sieht man, was zu
-- benennen ist - als ein Gegenstand, der aus dem Wegplan faellt.
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
UnitFactionGroup = function() return "Alliance" end

BananaLootline = {}
GetLocale = function() return "enUS" end
dofile("Locale.lua")
local BLL = BananaLootline
BLL.Print, BLL.Debug = function() end, function() end
dofile("Scanner.lua")

BananaLootlineDB = { itemcache = {}, planAhead = 6, minDropChance = 0 }

dofile("Data/SourceData.lua")
dofile("Data/ZoneNames.lua")
dofile("Data/NpcData.lua")
pfDB = nil
dofile("Sources.lua")
local S = BLL.Sources
S:Init()

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

------------------------------------------------------------------
-- 1. Kein Platzhalter mehr in den Daten
------------------------------------------------------------------

local bad = {}
for z, n in pairs(BananaLootlineZoneNames) do
  if n == "???" or n == "_" or n == "" then table.insert(bad, z) end
end
check(table.getn(bad) == 0,
  "keine Platzhalter mehr in ZoneNames, sind " .. table.getn(bad))

------------------------------------------------------------------
-- 2. Zone 5557 hat ihren echten Namen
------------------------------------------------------------------

check(BananaLootlineZoneNames[5557] == "The Rock of Desolation",
  "Zone 5557 heisst The Rock of Desolation, heisst "
  .. tostring(BananaLootlineZoneNames[5557]))
check(S:ZoneName(5557) == "The Rock of Desolation",
  "und das Addon liefert ihn auch so aus")

------------------------------------------------------------------
-- 3. Eine unbekannte Zone faellt nicht aus dem Wegplan
--
-- Ohne Rueckfall gaebe ZoneName nil zurueck, und GetLootline wirft
-- jeden Gegenstand ohne Zone aus der Liste.
------------------------------------------------------------------

check(S:ZoneName(999999) == "Zone 999999",
  "eine unbekannte Zone bekommt einen lesbaren Namen mit ihrer Nummer, hat "
  .. tostring(S:ZoneName(999999)))
check(S:ZoneName(nil) == nil, "ohne Nummer gibt es nichts zu benennen")

------------------------------------------------------------------
-- 4. Eigene Benennung schlaegt alles
--
-- Damit laesst sich ein Ort im Spiel benennen, ohne auf ein
-- Datenupdate zu warten.
------------------------------------------------------------------

BananaLootlineDB.zoneNames = { [999999] = "Frostmane Hollow" }
check(S:ZoneName(999999) == "Frostmane Hollow",
  "die eigene Benennung greift")

BananaLootlineDB.zoneNames[5557] = "Eigener Name"
check(S:ZoneName(5557) == "Eigener Name",
  "und sie schlaegt auch einen mitgelieferten Namen")

BananaLootlineDB.zoneNames = nil
check(S:ZoneName(5557) == "The Rock of Desolation",
  "nach dem Zuruecksetzen gilt wieder der mitgelieferte Name")

------------------------------------------------------------------
-- 5. Die Gegenstaende der Zone sind erreichbar
------------------------------------------------------------------

local n = 0
for id, s in pairs(BananaLootlineSourceData) do
  for i = 1, table.getn(s.d or {}) do
    if s.d[i].z == 5557 then n = n + 1 end
  end
end
check(n > 50, "die Zone fuehrt ueber 50 Dropzeilen, sind " .. n)

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
