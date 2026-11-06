-- Suche ohne pfQuest, mit den echten eingebauten Daten.
--
-- Ein Tester hatte nur Questie-Octo installiert. Die Suche blieb im
-- ersten Schritt stehen, weil sie dort pfQuest erwartete: Pool 0,
-- "nichts Besseres gefunden", obwohl der Import 2227 passende Items
-- fuer seinen Stufe-45-Charakter kannte.
string.gmatch = nil; select = nil
local function stub()
  return setmetatable({}, { __index = function(t, k)
    if k == "NumLines" then return function() return 0 end end
    return function() end
  end })
end
CreateFrame = function() return stub() end
GetItemInfo = function() return nil end
GetLocale = function() return "enUS" end
GetTime = function() return 0 end
UnitFactionGroup = function() return "Alliance" end
UnitLevel = function() return 45 end
GetNumSkillLines = function() return 0 end
GetInventorySlotInfo = function(n) return 1 end
GetNumFactions = function() return 0 end
GetNumTalentTabs = function() return 0 end
GameTooltip = stub()
getglobal = function() return nil end
pfDB = nil

BananaLootline = {}
dofile("Locale.lua")
local BLL = BananaLootline
BLL.Print, BLL.Debug = function() end, function() end
BananaLootlineDB = { itemcache = {}, planAhead = 1, queryRate = 100000 }
BananaLootlineChar = {}
for _, f in ipairs({ "Data/ItemData.lua", "Data/SourceData.lua", "Data/NpcData.lua",
                     "Data/ZoneNames.lua", "ItemDB.lua", "Weights.lua", "Phases.lua",
                     "Scanner.lua", "Sources.lua", "Candidates.lua" }) do
  dofile(f)
end
BLL.ItemDB:Refresh()
BLL.SetDB = { loaded = false }
dofile("Gear.lua")
BLL.Gear.equipped = {}
BLL.player = { class = "PALADIN", level = 45 }
local Cand = BLL.Candidates
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

check(BLL.Sources:Init(), "eingebaute Fundorte reichen")
check(BLL.Sources.items == nil, "pfQuest fehlt wirklich")

Cand:Run()
local n = 0
while Cand.state ~= "ready" and Cand.state ~= "failed" and n < 100000 do
  Cand:Tick(1); n = n + 1
end
check(Cand.state == "ready", "Suche fertig, Zustand " .. tostring(Cand.state)
  .. (Cand.lastError and (" " .. Cand.lastError.msg) or ""))
check((Cand.poolSize or 0) > 500, "Pool gefuellt, " .. tostring(Cand.poolSize))

local ups = Cand:GetUpgrades("ChestSlot", 6)
check(ups and ups[1], "Brust-Upgrades gefunden")
local line = Cand:GetLootline(3)
local rows = 0
for _ in pairs(line or {}) do rows = rows + 1 end
check(rows > 0, "Lootline nicht leer")

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
