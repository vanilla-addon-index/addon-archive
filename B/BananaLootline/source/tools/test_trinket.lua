-- Frage aus dem Test: die Anstecknadel der Argentumdaemmerung hat keine
-- Werte. Muesste dann nicht JEDES Schmuckstueck mit einem einzigen Punkt
-- darauf als Verbesserung gelten?
--
-- Dieser Test spielt genau das durch: leeres Schmuckstueck angelegt,
-- Kandidaten mit Werten im Pool.
string.gmatch = nil; select = nil

BananaLootline = {
  locale = "deDE", clientLocale = "enUS",
  L = setmetatable({}, { __index = function(t, k) return k end }),
}
BananaLootlineDB = { planAhead = 6, itemcache = {} }
CreateFrame = function()
  return { SetScript = function() end, RegisterEvent = function() end }
end

local BLL = BananaLootline
BLL.Print = function() end

dofile("Candidates.lua")
local Cand = BLL.Candidates

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

------------------------------------------------------------------
-- Umgebung: Schurke 60, Anstecknadel im ersten Schmuckplatz
------------------------------------------------------------------

BLL.player = { class = "ROGUE", level = 60 }

-- Werte zaehlen 1:1, damit die Rechnung im Test nachvollziehbar bleibt.
BLL.Weights = {
  Score = function(self, stats, isWeapon, extra)
    local sum = 0
    for _, v in pairs(stats or {}) do sum = sum + v end
    for _, v in pairs(extra or {}) do sum = sum + v end
    return sum
  end,
  UseEffectScore = function() return 0, false end,
}

BLL.Gear = {
  SLOTS = { { key = "Trinket0Slot" } },
  SlotLabel = function() return "Schmuck" end,
  equipped = {
    -- Die Anstecknadel: angelegt, aber ohne einen einzigen Wert.
    ["Trinket0Slot"] = { id = 11832, name = "Anstecknadel", stats = {} },
  },
}

BLL.SetDB  = { loaded = false }
BLL.Sources = {
  available = true, items = {}, units = {}, quests = {},
  UnitLevel = function() return nil end,
  GetItemSources = function() return {} end,
}

-- Waffenfertigkeiten spielen bei Schmuck keine Rolle
Cand.skills = { known = {}, dualWield = true }
Cand.skillsDirty = false

------------------------------------------------------------------
-- Kandidaten: drei Schmuckstuecke, eines davon mit einem einzigen Punkt
------------------------------------------------------------------

BananaLootlineDB.itemcache = {
  -- e = equipLoc, st = Werte, r = benoetigte Stufe, q = Qualitaet
  [11832] = { e = "INVTYPE_TRINKET", st = {},           r = 0,  q = 1, n = "Anstecknadel" },
  [100]   = { e = "INVTYPE_TRINKET", st = { STA = 1 },  r = 50, q = 2, n = "Ein Punkt Ausdauer" },
  [101]   = { e = "INVTYPE_TRINKET", st = { AGI = 20 }, r = 55, q = 3, n = "Zwanzig Beweglichkeit" },
  [102]   = { e = "INVTYPE_TRINKET", st = {},           r = 55, q = 3, n = "Nur Proc, keine Werte" },
}
Cand.pool = { [100] = 50, [101] = 55, [102] = 55 }
Cand.fromImport = { [100] = 1, [101] = 1, [102] = 1 }

local ups, baseScore = Cand:GetUpgrades("Trinket0Slot", 5)

check(baseScore == 0, "die Anstecknadel zaehlt 0 Punkte, war " .. tostring(baseScore))

local found = {}
for i = 1, table.getn(ups or {}) do found[ups[i].id] = ups[i] end

-- Das ist die eigentliche Frage
check(found[100] ~= nil,
  "ein Schmuckstueck mit einem einzigen Punkt gilt als Verbesserung")
check(found[101] ~= nil,
  "ein Schmuckstueck mit 20 Beweglichkeit gilt als Verbesserung")

-- Und die Gegenprobe: ein Teil ohne Werte ist KEINE Verbesserung
check(found[102] == nil,
  "ein Schmuckstueck ohne Werte wird nicht vorgeschlagen")

-- Reihenfolge: das staerkere zuerst
if found[100] and found[101] then
  check(ups[1].id == 101,
    "das staerkere Schmuckstueck steht oben, oben stand " .. tostring(ups[1].id))
  check(found[100].gain == 1, "Zuwachs des schwachen Teils ist 1, war "
    .. tostring(found[100].gain))
end

------------------------------------------------------------------
-- Gegenprobe: traegt der Spieler ein Teil MIT Werten, gilt die Huerde
------------------------------------------------------------------

BLL.Gear.equipped["Trinket0Slot"] = { id = 999, name = "Gutes Teil", stats = { AGI = 15 } }
BananaLootlineDB.itemcache[999] = { e = "INVTYPE_TRINKET", st = { AGI = 15 }, r = 55, q = 3 }

ups, baseScore = Cand:GetUpgrades("Trinket0Slot", 5)
check(baseScore == 15, "angelegtes Teil zaehlt 15 Punkte, war " .. tostring(baseScore))

found = {}
for i = 1, table.getn(ups or {}) do found[ups[i].id] = ups[i] end
check(found[100] == nil, "ein Punkt schlaegt 15 Punkte nicht")
check(found[101] ~= nil, "20 Punkte schlagen 15 Punkte")

------------------------------------------------------------------
-- Der umgekehrte Fall: ein Proc-Schmuckstueck ohne Werte
--
-- Die Hand der Gerechtigkeit zaehlt null Punkte, weil ihr Effekt im
-- Tooltip als Satz steht. Ohne Sicherheitsabstand wuerde das Addon dem
-- Spieler raten, sie gegen ein Teil mit einem Punkt Ausdauer zu
-- tauschen. Genau das darf nicht passieren.
------------------------------------------------------------------

BLL.Gear.equipped["Trinket0Slot"] = {
  id = 11815, name = "Hand der Gerechtigkeit", stats = {},
  unscored = { "Anlegen: 2% Chance bei Treffer, einen zusaetzlichen Angriff auszufuehren." },
}

ups, baseScore = Cand:GetUpgrades("Trinket0Slot", 5)
check(baseScore == 0, "das Proc-Teil zaehlt weiterhin 0 Punkte")

found = {}
for i = 1, table.getn(ups or {}) do found[ups[i].id] = ups[i] end

check(found[100] == nil,
  "ein Punkt Ausdauer wird NICHT gegen ein Proc-Teil empfohlen")
check(found[101] ~= nil,
  "20 Beweglichkeit liegen deutlich genug vorne und werden empfohlen")
if found[101] then
  check(found[101].incomplete == true,
    "der Vorschlag ist als unvollstaendiger Vergleich gekennzeichnet")
end

-- Zum Vergleich: ohne den Vermerk waere das schwache Teil durchgerutscht
BLL.Gear.equipped["Trinket0Slot"].unscored = nil
ups = Cand:GetUpgrades("Trinket0Slot", 5)
found = {}
for i = 1, table.getn(ups or {}) do found[ups[i].id] = ups[i] end
check(found[100] ~= nil,
  "Gegenprobe: ohne Effektvermerk gilt ein Punkt wieder als Verbesserung")
if found[100] then
  check(found[100].incomplete == nil,
    "Gegenprobe: dann auch ohne Kennzeichnung")
end

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
