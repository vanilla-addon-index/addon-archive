-- Laufzeit der Vorschlagsberechnung mit echten Daten.
--
-- Der Pool waechst am Stufenende auf mehrere tausend Eintraege, und
-- GetUpgrades laeuft pro Ausruestungsplatz einmal darueber. Auf einem
-- 1.12-Client entscheidet das darueber, ob das Fenster ruckelt.
string.gmatch = nil; select = nil

local LEVEL = tonumber(arg and arg[1]) or 60
local CLASS = (arg and arg[2]) or "WARRIOR"

CreateFrame = function()
  return { SetScript = function() end, RegisterEvent = function() end }
end
GetItemInfo       = function() return nil end
GetNumSkillLines  = function() return 0 end
GetSkillLineInfo  = function() return nil end
ExpandSkillHeader = function() end
UnitLevel         = function() return LEVEL end

BananaLootline = { locale = "enUS", clientLocale = "enUS" }
BananaLootline.L = setmetatable({}, { __index = function(t, k) return k end })
BananaLootlineDB = { planAhead = 6, itemcache = {} }
local BLL = BananaLootline
BLL.Print, BLL.Debug = function() end, function() end

dofile("Data/ItemData.lua")
dofile("ItemDB.lua")
BLL.ItemDB:Refresh()

BLL.Weights = {
  DEFAULT_COOLDOWN = 120,
  Get = function() return { AGI = 1, STA = 1, STR = 1, INT = 1, SPI = 1, ARMOR = 0.05 } end,
  Score = function(self, s, w, e)
    local t = 0
    for _, v in pairs(s or {}) do t = t + v end
    for _, v in pairs(e or {}) do t = t + v end
    return t
  end,
  UseEffectScore = function() return 0, false end,
}
BLL.SetDB = { loaded = false }
BLL.Sources = { available = true, items = {}, units = {}, quests = {},
  UnitLevel = function() return nil end, GetItemSources = function() return {} end }

local SLOTKEYS = {
  "HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot",
  "HandsSlot","WaistSlot","LegsSlot","FeetSlot","Finger0Slot","Finger1Slot",
  "Trinket0Slot","Trinket1Slot","MainHandSlot","SecondaryHandSlot","RangedSlot",
}
local SLOTS = {}
for i = 1, table.getn(SLOTKEYS) do SLOTS[i] = { key = SLOTKEYS[i] } end
BLL.Gear = { SLOTS = SLOTS, SlotLabel = function(s, x) return x.key end, equipped = {} }

dofile("Candidates.lua")
local Cand = BLL.Candidates
BLL.player = { class = CLASS, level = LEVEL }

-- Pool aufbauen und Zeit messen
local t0 = os.clock()
Cand.StartQuery = function(self) self.state = "ready" end
Cand:StartIndex(Cand:Band())
local chunks = 0
while Cand.state == "indexing" or Cand.state == "indexdb" do
  chunks = chunks + 1
  if chunks > 20000 then break end
  if Cand.state == "indexing" then Cand:IndexChunk() else Cand:ImportChunk() end
end
local tPool = os.clock() - t0

t0 = os.clock()
Cand:PreloadFromItemDB()
local tPre = os.clock() - t0

-- Ein kompletter Fensteraufbau: alle Plaetze einmal
t0 = os.clock()
local count = 0
for i = 1, table.getn(SLOTKEYS) do
  local ups = Cand:GetUpgrades(SLOTKEYS[i], 5)
  count = count + table.getn(ups or {})
end
local tSlots = os.clock() - t0

print(string.format("%s Stufe %d", CLASS, LEVEL))
print(string.format("   Pool                 : %d Eintraege in %d Teilstuecken",
  Cand.poolSize, chunks))
print(string.format("   Pool aufbauen        : %6.3f s", tPool))
print(string.format("   Import auswerten     : %6.3f s", tPre))
print(string.format("   17 Plaetze berechnen : %6.3f s  (%d Vorschlaege)", tSlots, count))
print(string.format("   pro Platz            : %6.3f s", tSlots / 17))
