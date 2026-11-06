string.gmatch = nil; select = nil
BananaLootline = { locale = "deDE", L = setmetatable({}, { __index = function(t, k) return k end }) }
BananaLootlineDB = { planAhead = 6 }
CreateFrame = function() return { SetScript = function() end, Hide = function() end, Show = function() end } end
local BLL = BananaLootline
BLL.Gear = { equipped = {}, SLOTS = {} }
BLL.Weights = {
  Score = function(self, st) local n = 0; for _, v in pairs(st or {}) do n = n + v end; return n end,
  UseEffectScore = function() return 0 end,
}
dofile("Candidates.lua")
BLL.Sources = { GetItemSources = function() return {} end }
local Cand = BLL.Candidates
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

BananaLootlineDB.itemcache = {
  [1] = { e = "INVTYPE_WEAPON",        r = 10, st = { AGI = 5 }, n = "Einhandaxt" },
  [2] = { e = "INVTYPE_WEAPONOFFHAND", r = 12, st = { AGI = 4 }, n = "Schildhanddolch" },
  [3] = { e = "INVTYPE_SHIELD",        r = 10, st = { STA = 3 }, n = "Schild" },
  [4] = { e = "INVTYPE_WEAPON",        r = 22, st = { AGI = 9 }, n = "Axt ab 22" },
}
Cand.pool = { [1] = 10, [2] = 12, [3] = 10, [4] = 22 }

local function ids(list)
  local t = {}
  for i = 1, table.getn(list or {}) do t[list[i].id] = list[i] end
  return t
end

-- Jaeger Stufe 15, Vorausplanung 6: Waffen in der Schildhand erst ab 20
BLL.player = { class = "HUNTER", level = 15 }
local off = ids(Cand:GetUpgrades("SecondaryHandSlot", 10))
check(off[1] and off[1].locked and off[1].reqLevel == 20 and off[1].dualWield, "Jaeger 15: Axt gesperrt ab 20")
check(off[2] and off[2].reqLevel == 20, "Jaeger 15: Schildhanddolch ab 20")
check(off[4] == nil, "Axt ab 22 liegt ausserhalb 15+6? nein, 21 < 22: ausgeblendet")
local main = ids(Cand:GetUpgrades("MainHandSlot", 10))
check(main[1] and not main[1].locked and not main[1].dualWield, "Haupthand frei")

-- Ohne Vorausplanung verschwinden sie ganz
BananaLootlineDB.planAhead = 0
off = ids(Cand:GetUpgrades("SecondaryHandSlot", 10))
check(off[1] == nil and off[2] == nil, "ohne Vorausplanung keine Schildhandwaffe")
BananaLootlineDB.planAhead = 6

-- Jaeger 20: frei
BLL.player = { class = "HUNTER", level = 20 }
off = ids(Cand:GetUpgrades("SecondaryHandSlot", 10))
check(off[1] and not off[1].locked, "Jaeger 20: frei")
check(off[4] and off[4].reqLevel == 22 and not off[4].dualWield, "eigene Stufe hoeher als 20: bleibt 22")

-- Schurke 15: frei (lernt mit 10)
BLL.player = { class = "ROGUE", level = 15 }
off = ids(Cand:GetUpgrades("SecondaryHandSlot", 10))
check(off[1] and not off[1].locked, "Schurke 15 frei")

-- Paladin: nie Waffe in der Schildhand, Schild schon
BLL.player = { class = "PALADIN", level = 30 }
off = ids(Cand:GetUpgrades("SecondaryHandSlot", 10))
check(off[1] == nil and off[2] == nil, "Paladin ohne Schildhandwaffe")
check(off[3] ~= nil, "Paladin mit Schild")

-- Quellen: Quest und Haendler sind sicher und stehen vorn
BananaLootline.L = setmetatable({}, { __index = function(t, k) return k end })
BLL.Sources = nil
local stub = setmetatable({}, { __index = function() return function() end end })
GameTooltip = stub; ItemRefTooltip = stub
hooksecurefunc = nil
dofile("Sources.lua")
local S = BLL.Sources
S.available = true
S.items = { [100] = { ["U"] = { [1] = 1.5 }, ["Q"] = { [7] = 1 }, ["V"] = { [9] = 0 } } }
S.UnitName = function(self, id) return "Mob" .. id end
S.UnitZone = function() return "Westfall" end
S.UnitLevel = function() return "12" end
S.QuestName = function() return "Die Quest" end
S.ObjectName = function() return "Obj" end
S.RaceAllows = function() return true end
S.quests = { [7] = { lvl = 14 } }
local src = S:GetItemSources(100)
for i = 1, table.getn(src) do print(i, src[i].stype, src[i].chance, src[i].sure) end
check(src[1].sure and src[2].sure and src[3].stype == "U", "sichere Quellen vorn")
local q
for i = 1, 3 do if src[i].stype == "Q" then q = src[i] end end
check(q and q.chance == nil, "Quest ohne falsche 1 %")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
