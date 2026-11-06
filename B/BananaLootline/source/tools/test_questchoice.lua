-- Simulation 1.12: Lua-5.1-Features sperren, die 5.0 nicht hat
string.gmatch = nil; select = nil
BananaLootline = { locale = "deDE", L = { QUEST_CHOICE = "Wahl aus" } }
BananaLootlineDB = {}
CreateFrame = function() return { SetScript = function() end } end
local BLL = BananaLootline
BLL.Gear = {
  SLOTS = { {key="HEAD"}, {key="CHEST"}, {key="LEGS"}, {key="FINGER1"}, {key="BACK"} },
  equipped = { HEAD=1, CHEST=1, LEGS=1, FINGER1=1, BACK=1 },
  SlotLabel = function(self, s) return s.key end,
}
dofile("Candidates.lua")
local Cand = BLL.Candidates
Cand.ZoneInfo = function() return nil end
Cand.Category = function() return "X" end
Cand.pool = {}

local function q(id, zone) return { { stype="Q", id=id, zone=zone, name="Q"..id, chance=1 } } end
local function u(zone, ch) return { { stype="U", id=9, zone=zone, name="Mob", chance=ch } } end
-- Quest 100 in Seenhain: vier Wahlbelohnungen ueber drei Slots, beste 30
-- Mobdrops in Seenhain: 5 ; Dungeon: zwei Drops 20 + 15 = 35
local UPS = {
  HEAD    = { {id=1, gain=10, sources=q(100,"Seenhain")}, {id=6, gain=20, sources=u("Dungeon",5)} },
  CHEST   = { {id=2, gain=30, sources=q(100,"Seenhain")} },
  LEGS    = { {id=3, gain=25, sources=q(100,"Seenhain")}, {id=7, gain=15, sources=u("Dungeon",3)} },
  FINGER1 = { {id=4, gain=5,  sources=u("Seenhain",10)}, {id=5, gain=12, sources=q(200,"Seenhain")} },
  BACK    = {},
}
Cand.GetUpgrades = function(self, key) return UPS[key], 100 end

local ll = Cand:GetLootline(3)
local ok = true
local function check(c, msg) if not c then ok = false; print("FEHLER: "..msg) end end
local byZone = {}
for i = 1, table.getn(ll) do byZone[ll[i].zone] = ll[i]; print(ll[i].zone, ll[i].priority) end
-- Drops zaehlen seit 0.22.13 mit der Wurzel ihrer Chance.
-- Seenhain: Quest100 max 30 + Quest200 12 (sicher) + Mob 5 x sqrt(0,10) = 43.581
-- Dungeon: 20 x sqrt(0,05) + 15 x sqrt(0,03) = 7.070
local function near(a, b) return math.abs(a - b) < 0.001 end
check(near(byZone["Seenhain"].priority, 43.5811), "Seenhain erwartet 43.581, ist " .. byZone["Seenhain"].priority)
check(near(byZone["Dungeon"].priority, 7.0702), "Dungeon erwartet 7.070, ist " .. byZone["Dungeon"].priority)
check(ll[1].zone == "Seenhain", "Reihenfolge")
for _, it in ipairs(byZone["Seenhain"].items) do
  print(" ", it.id, it.gain, it.choiceOf, it.choiceBest)
  if it.id == 2 then check(it.choiceOf == 3 and it.choiceBest, "Item 2 beste Wahl aus 3") end
  if it.id == 1 or it.id == 3 then check(it.choiceOf == 3 and not it.choiceBest, "Alternative") end
  if it.id == 5 or it.id == 4 then check(it.choiceOf == nil, "Einzelquest/Mob ohne Wahl") end
end
-- Reihenfolgeunabhaengigkeit: schwaechstes Teil zuletzt vs zuerst
UPS.HEAD[1].gain, UPS.CHEST[1].gain = 30, 10
ll = Cand:GetLootline(3)
for i = 1, table.getn(ll) do if ll[i].zone == "Seenhain" then check(near(ll[i].priority, 43.5811), "Umgestellt erwartet 43.581, ist "..ll[i].priority) end end

-- Rotkammgebirge gegen Westfall wie im Spiel: drei seltene Drops mit
-- grossem Zuwachs gegen einen haeufigen Drop
UPS = {
  HEAD    = { {id=11, gain=60,  sources=u("Rotkamm", 5)} },
  CHEST   = { {id=12, gain=48,  sources=u("Rotkamm", 1)} },
  LEGS    = { {id=13, gain=100, sources=u("Rotkamm", 1)} },
  FINGER1 = { {id=14, gain=1,   sources=u("Rotkamm", 1.1)} },
  BACK    = { {id=15, gain=69,  sources=u("Westfall", 75)} },
}
ll = Cand:GetLootline(3)
print(ll[1].zone, ll[1].priority, ll[2].zone, ll[2].priority)
check(ll[1].zone == "Westfall" and near(ll[1].priority, 59.7558), "Westfall vorn mit 59.756")
check(near(ll[2].priority, 28.3213), "Rotkamm 28.321")
check(Cand:ChanceFactor("V", nil) == 1 and Cand:ChanceFactor("Q", 1) == 1, "Haendler und Quest sicher")
-- Die Wurzel daempft, statt zu multiplizieren: ein Bossdrop mit 33 %
-- zaehlt mehr als die Haelfte, ein 2-%-Drop nur noch ein Siebtel.
check(near(Cand:ChanceFactor("U", 33.33), math.sqrt(0.3333)), "33 % zaehlt 0,58")
check(Cand:ChanceFactor("U", 2) < 0.15, "2 % zaehlt unter 0,15")
check(Cand:ChanceFactor("U", 150) == 1, "ueber 100 % gedeckelt")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
