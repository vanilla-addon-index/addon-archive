-- Jaeger: Waffen-DPS zaehlt am Bogen voll, an der Nahkampfwaffe kaum.
--
-- "Rockslicer" (Zweihandaxt, 18,2 DPS) gegen den angelegten Dolch
-- (2,5 DPS) brachte mit vollem Gewicht rund 47 Punkte und zog die
-- Todesminen im Wegplan eines Stufe-16-Jaegers ueber jeden Ort mit
-- Ruestungsupgrades. Geschossen wird mit dem Bogen.
string.gmatch = nil; select = nil
GetLocale = function() return "deDE" end
BananaLootline = { player = { class = "HUNTER", level = 16 } }
dofile("Locale.lua")
local BLL = BananaLootline
BananaLootlineDB, BananaLootlineChar = {}, {}
GetNumTalentTabs = function() return 3 end
GetTalentTabInfo = function() return "x", nil, 0 end
dofile("Weights.lua")
local W = BLL.Weights
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local axe = { STR = 7, WEAPON_DPS = 18.2 }
local melee  = W:Score(axe, "melee")
local ranged = W:Score(axe, "ranged")
local legacy = W:Score(axe, true)
check(ranged > melee * 3, "Bogen-DPS zaehlt weit mehr als Nahkampf-DPS")
check(math.abs(legacy - ranged) < 0.001, "true verhaelt sich wie bisher (volles Gewicht)")
check(math.abs(melee - (7 * 0.1 + 18.2 * 0.5)) < 0.001, "Nahkampf mit MELEE_DPS 0,5")
check(math.abs(W:Score(axe, nil) - 0.7) < 0.001, "ausserhalb der Waffenplaetze zaehlt DPS gar nicht")

-- Andere Klassen ohne MELEE_DPS: unveraendert
BLL.player.class = "WARRIOR"
check(W:Score({ WEAPON_DPS = 10 }, "melee") == W:Score({ WEAPON_DPS = 10 }, true),
  "Krieger: Nahkampf-DPS volles Gewicht")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
