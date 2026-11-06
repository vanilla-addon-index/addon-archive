-- Abgleich der Anforderungsstufe zwischen Itemcache und Itemdatenbank.
--
-- Anlass: "Outrider's Bow" (19558) erschien bei einem Stufe-15-Jaeger
-- mit dem Vermerk "ab 18". Tooltip und Import nennen uebereinstimmend
-- Stufe 60. Im gespeicherten Cache stand noch eine 18 aus einer
-- Sitzung, in der die Itemdatenbank andere Werte fuehrte - und ein
-- Cache-Eintrag wird nicht neu bewertet, solange seine Version passt.
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
BLL.Weights = {
  Score = function(self, s) local t = 0; for _, v in pairs(s or {}) do t = t + v end return t end,
  UseEffectScore = function() return 0, false end,
}
BLL.SetDB  = { loaded = false }
BLL.Sources = { available = true, items = {}, units = {}, quests = {},
  UnitLevel = function() return nil end, GetItemSources = function() return {} end }
BLL.Gear = { SLOTS = { { key = "RangedSlot" } }, SlotLabel = function() return "R" end,
  equipped = { ["RangedSlot"] = { id = 1, stats = { AGI = 1 } } } }

-- Die Itemdatenbank kennt die richtige Stufe.
BLL.ItemDB = {
  loaded = true,
  data = {
    [19558] = { name = "Outrider's Bow", ilvl = 71, reqlevel = 60,
                quality = 3, slot = 15, itemclass = 2, subclass = 2 },
    [2500]  = { name = "Normaler Bogen", ilvl = 20, reqlevel = 16,
                quality = 2, slot = 15, itemclass = 2, subclass = 2 },
  },
  Get = function(self, id) return self.data[id] end,
  MaskAllows = function() return true end,
}

dofile("Candidates.lua")
local Cand = BLL.Candidates
Cand.skills = { known = { [2] = true, [3] = true, [18] = true }, dualWield = true }
Cand.skillsDirty = false

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

------------------------------------------------------------------
-- 1. Veralteter Cache-Eintrag wird richtiggestellt
------------------------------------------------------------------

local stale = { e = "INVTYPE_RANGED", st = { AGI = 20 }, r = 18, q = 3,
                n = "Outrider's Bow", ic = 2, sc = 2 }
check(Cand:RequiredLevel(stale, 19558) == 60,
  "Stufe 60 aus der Datenbank schlaegt die 18 aus dem Cache, war "
  .. tostring(Cand:RequiredLevel(stale, 19558)))
check(stale.r == 60, "der Cache-Eintrag wird gleich richtiggestellt")

-- Die umgekehrte Richtung darf NICHT passieren: sagt der Cache eine
-- hoehere Stufe als der Import, bleibt die hoehere stehen.
local higher = { e = "INVTYPE_RANGED", st = {}, r = 40 }
check(Cand:RequiredLevel(higher, 2500) == 40,
  "hoehere Angabe aus dem Cache bleibt erhalten")

-- Unbekanntes Item: keine Datenbank, kein Abgleich, kein Absturz
check(Cand:RequiredLevel({ r = 25 }, 999999) == 25, "unbekanntes Item bleibt unveraendert")
check(Cand:RequiredLevel({}, nil) == 0, "Eintrag ganz ohne Stufe liefert 0")

------------------------------------------------------------------
-- 2. Der Stufe-15-Jaeger bekommt den Bogen nicht mehr
------------------------------------------------------------------

BLL.player = { class = "HUNTER", level = 15 }
BananaLootlineDB.itemcache = {
  [19558] = { e = "INVTYPE_RANGED", st = { AGI = 20 }, r = 18, q = 3,
              n = "Outrider's Bow", ic = 2, sc = 2 },
  [2500]  = { e = "INVTYPE_RANGED", st = { AGI = 10 }, r = 16, q = 2,
              n = "Normaler Bogen", ic = 2, sc = 2 },
}
Cand.pool = { [19558] = 18, [2500] = 16 }
Cand.fromImport = {}

local ups = Cand:GetUpgrades("RangedSlot", 5)
local found = {}
for i = 1, table.getn(ups or {}) do found[ups[i].id] = ups[i] end

check(found[19558] == nil,
  "Stufe-60-Bogen verschwindet aus der Liste des Stufe-15-Jaegers")
check(found[2500] ~= nil, "der passende Bogen bleibt")

------------------------------------------------------------------
-- 3. Auf Stufe 60 ist derselbe Bogen ein gueltiger Vorschlag
------------------------------------------------------------------

BLL.player = { class = "HUNTER", level = 60 }
BananaLootlineDB.itemcache[19558].r = 18   -- wieder veraltet setzen
ups = Cand:GetUpgrades("RangedSlot", 5)
found = {}
for i = 1, table.getn(ups or {}) do found[ups[i].id] = ups[i] end

check(found[19558] ~= nil, "auf Stufe 60 wird der Bogen vorgeschlagen")
if found[19558] then
  check(found[19558].reqLevel == 60,
    "und zwar mit Stufe 60 statt 18, war " .. tostring(found[19558].reqLevel))
  check(found[19558].locked == nil,
    "auf Stufe 60 ist er nicht mehr gesperrt")
end

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
