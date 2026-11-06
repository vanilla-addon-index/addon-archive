-- Statgewichte-Menue: Werte pro Charakter, ohne Umrechnung, Uebernahme
-- alter Account-Gewichte, Vorlagen anderer Talentbaeume.
string.gmatch = nil; select = nil
GetLocale = function() return "deDE" end
BananaLootline = { player = { class = "HUNTER", level = 30 } }
dofile("Locale.lua")
local BLL = BananaLootline
BLL.locale = "deDE"
local chat = {}
BLL.Print = function(self, m) table.insert(chat, m) end
local runs = 0
BLL.Candidates = { Run = function() runs = runs + 1 end }
GetNumTalentTabs = function() return 3 end
GetTalentTabInfo = function(i) return "x", nil, (i == 2) and 15 or 0 end
dofile("Weights.lua")
dofile("WeightsUI.lua")
local W, X = BLL.Weights, BLL.WeightsUI
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

-- 1. Alte Account-Gewichte gehen an den ersten Charakter
BananaLootlineDB = { weights = { AGI = 2 } }
BananaLootlineChar = {}
check(W:Get().AGI == 2, "alte Gewichte gelten")
check(BananaLootlineChar.weights and BananaLootlineDB.weights == nil, "Gewichte wandern zum Charakter")

-- 2. Ein anderer Charakter hat sie nicht
BananaLootlineChar = {}
W:Get()
check(not W.customWeights, "zweiter Charakter nutzt Spec-Gewichte")

-- 3. Arbeitskopie = Spec-Werte, keine Umrechnung
X:Load()
local base = W:BaseFor("HUNTER", 2)
check(X.work.AGI == base.AGI and X.work.RAP == base.RAP, "Arbeitskopie gleich Spec")
check(X:Format(1.5) == "1.5" and X:Format(2) == "2" and X:Format(0.05) == "0.05", "Zahlformat")

-- 4. Unveraendert uebernehmen speichert nichts
X:Apply()
check(BananaLootlineChar.weights == nil, "gleiche Werte speichern nichts")
check(runs == 1, "Suche neu gestartet")

-- 5. Aenderung speichern
X.work.AGI = 9; X.work.HIT = nil
X:Apply()
check(BananaLootlineChar.weights.AGI == 9 and BananaLootlineChar.weights.HIT == nil, "Aenderung gespeichert")
check(W:Get().AGI == 9 and W.customWeights, "eigene Werte gelten")

-- 6. Vorlage anderer Baum laedt nur in die Felder
X:Load(3)
check(X.work.AGI == W:BaseFor("HUNTER", 3).AGI, "Vorlage geladen")
check(BananaLootlineChar.weights.AGI == 9, "Vorlage speichert nicht")

-- 7. Zuruecksetzen
X:Reset()
check(BananaLootlineChar.weights == nil and X.work.AGI == base.AGI, "Zuruecksetzen")

-- 8. Gruppen enthalten nur Stats mit Beschriftung
for _, k in ipairs({ "WT_TITLE", "WT_TIP", "WT_PRESET", "WT_PRESET_NONE", "WT_APPLY", "WT_RESET",
                     "WT_HINT", "WT_SAVED", "WT_SAME" }) do
  check(BLL.L[k] and BLL.L[k] ~= k, "Text fehlt: " .. k)
end
for _, g in ipairs(X.GROUPS) do check(BLL.L[g.key] and BLL.L[g.key] ~= g.key, "Gruppe " .. g.key) end

if ok then print("ALLE TESTS OK") end
