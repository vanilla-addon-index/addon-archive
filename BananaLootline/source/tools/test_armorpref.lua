-- Nur die eigene Ruestungsart vorschlagen.
--
-- Ein BM-Jaeger auf Stufe 38 bekam die "Stormreaver Robe" (Stoff,
-- Ausdauer, Intelligenz, Zauberschaden) als Brust-Upgrade. Jaeger
-- duerfen Stoff tragen, wollen es aber nicht. Leichtere Ruestung gibt
-- es nur noch auf Wunsch; Umhaenge (Stoff) bleiben fuer alle.
string.gmatch = nil; select = nil
BananaLootline = { locale = "enUS", clientLocale = "enUS",
                   L = setmetatable({}, { __index = function(t, k) return k end }) }
BananaLootlineDB = { planAhead = 0, itemcache = {} }
BananaLootlineChar = {}
CreateFrame = function() return { SetScript = function() end, RegisterEvent = function() end } end
local BLL = BananaLootline
BLL.Print = function() end
dofile("Candidates.lua")
local Cand = BLL.Candidates
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local DB = {
  [1] = { name = "Stormreaver Robe", slot = 5, reqlevel = 35, ilvl = 40, quality = 3,
          itemclass = 4, subclass = 1, classmask = -1, stats = { STA = 9, INT = 8 } },
  [2] = { name = "Leather Vest", slot = 5, reqlevel = 34, ilvl = 39, quality = 2,
          itemclass = 4, subclass = 2, classmask = -1, stats = { AGI = 3 } },
  [3] = { name = "Chain Hauberk", slot = 5, reqlevel = 38, ilvl = 43, quality = 2,
          itemclass = 4, subclass = 3, classmask = -1, stats = { AGI = 4 } },
  [4] = { name = "Silk Cloak", slot = 16, reqlevel = 35, ilvl = 40, quality = 2,
          itemclass = 4, subclass = 1, classmask = -1, stats = { AGI = 5 } },
}
BLL.ItemDB = { loaded = true, data = DB, Get = function(self, id) return DB[id] end,
               MaskAllows = function() return true end }
BLL.Sources = { items = {}, imported = { [1] = {}, [2] = {}, [3] = {}, [4] = {} },
                GetItemSources = function() return { { stype = "U", zone = "X", chance = 25 } } end }
BLL.Weights = { Score = function(self, s) local t = 0; for k, v in pairs(s or {}) do t = t + v end return t end,
                UseEffectScore = function() return 0, false end }
BLL.SetDB = { loaded = false }
BLL.Gear = { equipped = {} }
BLL.player = { class = "HUNTER", level = 38 }
Cand.skills = { known = {}, dualWield = true }
Cand.skillsDirty = false

local function ids(slot)
  BananaLootlineDB.itemcache = {}
  Cand.pool = { [1] = 35, [2] = 34, [3] = 38, [4] = 35 }
  Cand.fromImport = {}
  Cand:PreloadFromItemDB()
  local out = {}
  for _, u in ipairs(Cand:GetUpgrades(slot, 10) or {}) do out[u.id] = true end
  return out
end

-- 1. Standard: Jaeger 38 sieht nur Leder
local c = ids("ChestSlot")
check(not c[1], "Stoffrobe darf nicht erscheinen")
check(c[2], "Lederweste erscheint")
check(not c[3], "Kette vor 40 nicht")
check(ids("BackSlot")[4], "Umhang (Stoff) bleibt")

-- 2. Ab 40 Kette statt Leder
BLL.player.level = 40
c = ids("ChestSlot")
check(c[3] and not c[2] and not c[1], "ab 40 nur Kette")

-- 3. Schalter: leichtere Ruestung zeigen
BLL.player.level = 38
Cand:SetShowLighterArmor(true)
c = ids("ChestSlot")
check(c[1] and c[2], "mit Schalter auch Stoff und Leder")
check(BananaLootlineChar.lighterArmor == true, "pro Charakter gespeichert")
Cand:SetShowLighterArmor(false)
check(BananaLootlineChar.lighterArmor == nil, "Schalter aus")

-- 4. Stoffklasse unveraendert
BLL.player = { class = "MAGE", level = 38 }
check(ids("ChestSlot")[1], "Magier sieht die Robe")

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
