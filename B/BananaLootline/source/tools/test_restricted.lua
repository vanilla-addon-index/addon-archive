-- Zugangsbedingungen: Ruf und PvP-Rang.
--
-- Anlass: "Outrider's Bow" beim PvP-Quartiermeister Kelm Hargunth stand
-- bei einem Stufe-15-Jaeger ganz oben in der Lootline. Stufe 18 stimmte,
-- aber ohne Ehrenrang verkauft ihm das niemand.
--
-- Wichtigste Gegenprobe: eine reine Stufenzeile darf NICHT anschlagen,
-- sonst verschwindet die halbe Datenbank aus den Vorschlaegen.
string.gmatch = nil; select = nil

local currentLines = {}
local slots = {}
local function fs(name)
  local o = { text = "" }
  o.SetText = function(self, v) self.text = v or "" end
  o.GetText = function(self) return self.text end
  slots[name] = o
  return o
end
for i = 1, 40 do
  fs("BananaLootlineScanTooltipTextLeft" .. i)
  fs("BananaLootlineScanTooltipTextRight" .. i)
end
getglobal = function(n) return slots[n] end

local tip = {}
tip.SetOwner, tip.ClearLines, tip.Hide = function() end, function() end, function() end
tip.SetHyperlink = function()
  for i = 1, 40 do
    slots["BananaLootlineScanTooltipTextLeft" .. i]:SetText(currentLines[i] or "")
  end
end
tip.NumLines = function() return table.getn(currentLines) end
-- Candidates.lua legt sich einen eigenen Frame an und haengt Skripte
-- daran; derselbe Stummel bedient beides.
tip.SetScript, tip.RegisterEvent = function() end, function() end

CreateFrame = function() return tip end
WorldFrame  = {}
GetItemInfo = function() return nil end

BananaLootline = {}
GetLocale = function() return "enUS" end
dofile("Locale.lua")
local BLL = BananaLootline
BLL.Debug, BLL.Print = function() end, function() end
dofile("Scanner.lua")
local Scanner = BLL.Scanner

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local nextID = 0
local function scan(lines)
  currentLines = lines
  Scanner:ClearCache()
  nextID = nextID + 1
  return Scanner:GetStats(nextID)
end

------------------------------------------------------------------
-- 1. Muss anschlagen
------------------------------------------------------------------

local locked = {
  "Requires: Argent Dawn - Honored",
  "Requires Argent Dawn (Revered)",
  "Requires Thorium Brotherhood - Exalted",
  "Requires: Sergeant",
  "Requires Knight-Lieutenant",
  "Requires Engineering (200)",
}
for i = 1, table.getn(locked) do
  local _, meta = scan({ "Testteil", "+4 Agility", locked[i] })
  check(meta and meta.restricted ~= nil,
    "Bedingung nicht erkannt: " .. locked[i])
end

------------------------------------------------------------------
-- 2. Darf NICHT anschlagen - reine Stufenzeilen
--
-- Die filtert SKIP_PREFIX schon vorher heraus. Wenn hier doch etwas
-- haengen bleibt, verschwinden reihenweise ganz normale Teile.
------------------------------------------------------------------

local fine = {
  { "Ganz normales Teil", "+4 Agility", "Requires Level 18" },
  { "Anderes Teil",       "+7 Stamina", "Requires Level 60" },
  { "Schlichtes Teil",    "+3 Spirit"                        },
  { "Waffe", "24 - 37 Damage", "Speed 2.40", "(12.7 damage per second)" },
}
for i = 1, table.getn(fine) do
  local _, meta = scan(fine[i])
  check(not (meta and meta.restricted),
    "Fehlalarm bei: " .. (fine[i][3] or fine[i][2] or fine[i][1]))
end

------------------------------------------------------------------
-- 3. Werte werden trotz Bedingung weiter gelesen
------------------------------------------------------------------

local stats, meta = scan({
  "Outrider's Bow",
  "+3 Agility",
  "Requires Level 18",
  "Requires: Sergeant",
})
check(stats and stats["AGI"] == 3, "Werte trotz Bedingung gelesen")
check(meta and meta.restricted ~= nil, "Bedingung neben Werten erkannt")

-- Eine Bedingungszeile darf nicht zusaetzlich als unbezifferter Effekt
-- zaehlen, sonst wuerde sie den Sicherheitsabstand ausloesen.
check(not (meta and meta.unscored),
  "Bedingungszeile zaehlt nicht als unbewerteter Effekt")

------------------------------------------------------------------
-- 4. Filterung in den Vorschlaegen
------------------------------------------------------------------

-- Ab hier darf der Tooltip nichts mehr liefern: GetUpgrades fragt den
-- Scanner fuer jeden angezeigten Kandidaten, und die Attrappe wuerde
-- sonst jedem Teil die zuletzt gesetzten Zeilen unterschieben.
currentLines = {}
Scanner:ClearCache()

BananaLootlineDB = { planAhead = 6, itemcache = {}, showLocked = nil }
BLL.player = { class = "HUNTER", level = 15 }
BLL.Weights = {
  Score = function(self, s) local t = 0; for _, v in pairs(s or {}) do t = t + v end return t end,
  UseEffectScore = function() return 0, false end,
}
BLL.SetDB = { loaded = false }
BLL.Sources = { available = true, items = {}, units = {}, quests = {},
  UnitLevel = function() return nil end, GetItemSources = function() return {} end }
BLL.Gear = { SLOTS = { { key = "RangedSlot" } }, SlotLabel = function() return "R" end,
  equipped = { ["RangedSlot"] = { id = 1, stats = { AGI = 1 } } } }
BLL.ItemDB = { loaded = false, Get = function() return nil end, MaskAllows = function() return true end }
dofile("Candidates.lua")
local Cand = BLL.Candidates
Cand.skills = { known = { [2] = true, [3] = true, [18] = true }, dualWield = true }
Cand.skillsDirty = false

BananaLootlineDB.itemcache = {
  [19558] = { e = "INVTYPE_RANGED", st = { AGI = 20 }, r = 18, q = 3,
              n = "Outrider's Bow", ic = 2, sc = 2, lock = "Requires: Sergeant" },
  [2500]  = { e = "INVTYPE_RANGED", st = { AGI = 10 }, r = 16, q = 2,
              n = "Ganz normaler Bogen", ic = 2, sc = 2 },
}
Cand.pool = { [19558] = 18, [2500] = 16 }
Cand.fromImport = {}

local ups = Cand:GetUpgrades("RangedSlot", 5)
local found = {}
for i = 1, table.getn(ups or {}) do found[ups[i].id] = true end

check(found[19558] == nil, "Teil mit Rangbedingung wird nicht vorgeschlagen")
check(found[2500] ~= nil,  "normaler Bogen wird weiterhin vorgeschlagen")

-- /bll locked blendet sie wieder ein
BananaLootlineDB.showLocked = true
ups = Cand:GetUpgrades("RangedSlot", 5)
found = {}
for i = 1, table.getn(ups or {}) do found[ups[i].id] = true end
check(found[19558] ~= nil, "mit /bll locked wieder sichtbar")

------------------------------------------------------------------
-- 5. Gefiltertes Teil laesst die Liste nicht schrumpfen
--
-- Der beste Kandidat ist gesperrt. Wird er einfach weggelassen, hat die
-- Liste nur zwei statt drei Eintraege - obwohl genug Kandidaten da sind.
-- Die schlechteren muessen nachruecken.
------------------------------------------------------------------

BananaLootlineDB.showLocked = nil
BananaLootlineDB.itemcache = {
  [901] = { e = "INVTYPE_RANGED", st = { AGI = 50 }, r = 16, q = 4,
            n = "Bester, aber gesperrt", ic = 2, sc = 2, lock = "Requires: Sergeant" },
  [902] = { e = "INVTYPE_RANGED", st = { AGI = 40 }, r = 16, q = 3, n = "Zweitbester", ic = 2, sc = 2 },
  [903] = { e = "INVTYPE_RANGED", st = { AGI = 30 }, r = 16, q = 3, n = "Dritter", ic = 2, sc = 2 },
  [904] = { e = "INVTYPE_RANGED", st = { AGI = 20 }, r = 16, q = 2, n = "Vierter", ic = 2, sc = 2 },
  [905] = { e = "INVTYPE_RANGED", st = { AGI = 10 }, r = 16, q = 2, n = "Fuenfter", ic = 2, sc = 2 },
}
Cand.pool = { [901] = 16, [902] = 16, [903] = 16, [904] = 16, [905] = 16 }

ups = Cand:GetUpgrades("RangedSlot", 3)
check(table.getn(ups or {}) == 3,
  "drei Vorschlaege trotz gesperrtem Spitzenreiter, waren "
  .. table.getn(ups or {}))
if table.getn(ups or {}) == 3 then
  check(ups[1].id == 902 and ups[2].id == 903 and ups[3].id == 904,
    "die naechsten ruecken der Reihe nach nach")
end

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
