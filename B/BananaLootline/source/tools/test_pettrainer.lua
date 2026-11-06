-- Tierausbilder und Waffenmeister sind keine Klassenlehrer.
--
-- Ein Jaeger sah im Extras-Menue unter "Klassenlehrer" Knurren, Grosse
-- Ausdauer und Widerstaende: die Liste des Tierausbilders hatte die
-- seines Jaegerlehrers ueberschrieben.
string.gmatch = nil; select = nil
GetLocale = function() return "enUS" end
BananaLootline = {}
dofile("Locale.lua")
local BLL = BananaLootline
BLL.Print = function() end
time = os.time
GetTime = function() return 0 end
GetZoneText = function() return "Stormwind" end
UnitExists = function() return true end
BananaLootlineDB, BananaLootlineChar = {}, {}
BLL.player = { class = "HUNTER", level = 42 }

-- Tooltip-Nachbau: Zeile 2 ist der Titel des NPCs
local npcTitle
local lines = {}
local function fs(k) return { GetText = function() return lines[k] end } end
getglobal = function(name)
  local _, _, k = string.find(name, "TextLeft(%d+)$")
  return k and fs(tonumber(k)) or nil
end
CreateFrame = function(kind)
  return { RegisterEvent = function() end, SetScript = function() end,
           SetOwner = function() end, ClearLines = function() lines = {} end, Hide = function() end,
           SetUnit = function() lines = { "Name", npcTitle and ("<" .. npcTitle .. ">") or "Level 60" } end,
           NumLines = function() return table.getn(lines) end }
end

local services = {}
GetNumTrainerServices = function() return table.getn(services) end
GetTrainerServiceInfo = function(i) return services[i][1], "", "available" end
GetTrainerServiceLevelReq = function(i) return services[i][2] end
GetTrainerServiceCost = function() return 100 end
GetTrainerServiceTypeFilter = function() return true end
IsTradeskillTrainer = function() return false end

dofile("Trainer.lua")
local T = BLL.Trainer
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

-- 1. Jaegerlehrer wird gemerkt
npcTitle = "Hunter Trainer"
services = { { "Arcane Shot", 42 } }
T:Scan()
local c = BananaLootlineChar.trainer.class
check(c and c.list[1].n == "Arcane Shot", "Jaegerlehrer gemerkt")

-- 2. Tierausbilder ueberschreibt ihn nicht
npcTitle = "Pet Trainer"
services = { { "Growl", 42 }, { "Great Stamina", 42 } }
T:Scan()
c = BananaLootlineChar.trainer.class
check(c and c.list[1].n == "Arcane Shot", "Tierausbilder ignoriert, ist " .. tostring(c and c.list[1].n))

-- 3. Waffenmeister ebenso; deutscher Titel mit Umlaut wird erkannt
npcTitle = "Weapon Master"
services = { { "Bows", 1 } }
T:Scan()
check(BananaLootlineChar.trainer.class.list[1].n == "Arcane Shot", "Waffenmeister ignoriert")
check(T:IsOwnClassTrainer("J\195\164gerlehrerin"), "deutscher weiblicher Titel")
check(not T:IsOwnClassTrainer("Tierausbilder"), "deutscher Tierausbilder")
check(T:IsOwnClassTrainer(nil), "ohne Titel wie bisher")

-- 4. Alte falsche Daten werden beim Start aufgeraeumt
BananaLootlineChar.trainer.class = { list = { { n = "Growl" }, { n = "Natural Armor" } }, level = 37 }
BananaLootlineChar.trainer.prof["?"] = { list = {} }
BananaLootlineChar.trainer.prof["First Aid"] = { list = {} }
T:Sanitize()
check(BananaLootlineChar.trainer.class == nil, "Tierausbilder-Liste entfernt")
check(BananaLootlineChar.trainer.prof["?"] == nil and BananaLootlineChar.trainer.prof["First Aid"],
  "Beruf ? entfernt, Erste Hilfe bleibt")

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
