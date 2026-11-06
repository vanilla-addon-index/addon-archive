-- Spezialisierung von Hand waehlen.
--
-- Unter 10 Talentpunkten erkennt das Addon keine Spezialisierung und
-- rechnet mit den Klassenwerten. Ein Stufe-15-Jaeger meldete "keine
-- Spez. erkannt", obwohl er Tierherrschaft spielt. Die eigene Wahl
-- liegt pro Charakter in BananaLootlineChar.spec und schlaegt die
-- Erkennung; nil heisst automatisch.
string.gmatch = nil; select = nil
GetLocale = function() return "deDE" end
BananaLootline = { player = { class = "PRIEST", level = 15 } }
dofile("Locale.lua")
local BLL = BananaLootline
BLL.locale = "deDE"
BananaLootlineDB = {}
BananaLootlineChar = {}

local tabs = { { "Disziplin", 0 }, { "Heilig", 0 }, { "Schatten", 3 } }
GetNumTalentTabs = function() return 3 end
GetTalentTabInfo = function(i) return tabs[i][1], nil, tabs[i][2] end

dofile("Weights.lua")
local W = BLL.Weights
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

-- 1. Ohne Wahl und mit 3 Punkten: nichts erkannt, Klassenwerte
local w = W:Get()
check(W.activeSpec == nil, "3 Punkte duerfen keine Spec ergeben")
check(W.specManual == false, "ohne Wahl ist nichts manuell")
local baseShadow = w.SPELLPOWER_SHADOW

-- 2. Von Hand Schatten
W:SetSpec(W:FindSpec("schat"))
w = W:Get()
check(W.activeSpec == "Schatten", "Namensanfang muss Schatten finden")
check(W.specManual == true, "Wahl muss als manuell gelten")
check(w.SPELLPOWER_SHADOW == 1.8, "Schattengewichte muessen gelten")
check(baseShadow ~= w.SPELLPOWER_SHADOW, "Wahl muss die Gewichte aendern")

-- 3. Die Wahl schlaegt die Erkennung
tabs[2][2] = 31
W:SetSpec(3)
W:Get()
check(W.activeSpec == "Schatten", "Wahl muss die erkannte Spec schlagen")

-- 4. auto gibt zurueck an die Erkennung
W:SetSpec(nil)
W:Get()
check(W.activeSpec == "Heilig", "ohne Wahl gilt die Erkennung")
check(W.specManual == false, "Erkennung ist nicht manuell")

-- 5. Nummern, englische Namen, Unsinn
check(W:FindSpec("2") == 2, "Nummer 2")
check(W:FindSpec("4") == nil, "Nummer 4 gibt es nicht")
check(W:FindSpec("shadow") == 3, "englischer Name")
check(W:FindSpec("xyz") == nil, "Unsinn")

-- 6. Eine gespeicherte Wahl einer anderen Klasse gilt nicht
BananaLootlineChar.spec = 7
check(W:ChosenSpec() == nil, "ungueltige Nummer muss ignoriert werden")

-- 7. Englische Anzeige
BLL.locale = "enUS"
W:SetSpec(1)
W:Get()
check(W.activeSpec == "Discipline", "englischer Anzeigename")

-- 7b. Eigene Gewichte: die Spec wird trotzdem erkannt und angezeigt
BLL.locale = "deDE"
BananaLootlineChar.weights = { AGI = 1 }
W:SetSpec(3)
local cw = W:Get()
check(cw.AGI == 1 and cw.SPELLPOWER_SHADOW == nil, "eigene Gewichte gelten")
check(W.activeSpec == "Schatten", "Spec bleibt sichtbar, ist " .. tostring(W.activeSpec))
check(W.customWeights, "eigene Gewichte sind markiert")
BananaLootlineChar.weights = nil
W:Get()
check(not W.customWeights, "ohne eigene Gewichte keine Markierung")

-- 8. Texte vorhanden in beiden Sprachen
for _, k in ipairs({ "SPEC_SET", "SPEC_AUTO", "SPEC_BAD", "SPEC_MANUAL",
                     "SPEC_MENU_AUTO", "SPEC_MENU_TITLE", "SPEC_TIP", "HELP_SPEC_SET",
                     "CUSTOM_WEIGHTS", "CUSTOM_WEIGHTS_NOTE" }) do
  check(BLL.L[k] and BLL.L[k] ~= k, "Text fehlt: " .. k)
end

if ok then print("ALLE TESTS OK") end
