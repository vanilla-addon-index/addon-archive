-- Zwei offene Punkte nachmessen:
--   1. Gegenstaende ohne Stufenangabe in der Datenbank
--   2. Reichweite der Rangerkennung: sie liest den Tooltip, aber wie
--      viele Kandidaten werden ueberhaupt ueber den Tooltip geladen?
string.gmatch = nil; select = nil

local LEVEL = tonumber(arg and arg[1]) or 15
local CLASS = (arg and arg[2]) or "HUNTER"

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
BLL.Gear = { SLOTS = {}, SlotLabel = function() return "" end, equipped = {} }

dofile("Candidates.lua")
local Cand = BLL.Candidates
BLL.player = { class = CLASS, level = LEVEL }

Cand.StartQuery = function(self) self.state = "ready" end
Cand:StartIndex(Cand:Band())
local guard = 0
while Cand.state == "indexing" or Cand.state == "indexdb" do
  guard = guard + 1
  if guard > 20000 then break end
  if Cand.state == "indexing" then Cand:IndexChunk() else Cand:ImportChunk() end
end

print("Klasse " .. CLASS .. ", Stufe " .. LEVEL .. ", Pool " .. Cand.poolSize)
print("")

------------------------------------------------------------------
print("== 1. Gegenstaende ohne Stufenangabe ==")
------------------------------------------------------------------

local noReq, noReqHighIlvl = 0, 0
local samples = {}
for id in pairs(Cand.pool) do
  local e = BLL.ItemDB:Get(id)
  if e and (not e.reqlevel or e.reqlevel == 0) then
    noReq = noReq + 1
    local il = e.ilvl or 0
    if il > LEVEL + 12 then
      noReqHighIlvl = noReqHighIlvl + 1
      if table.getn(samples) < 6 then
        table.insert(samples, string.format("id=%-7d %-34s ilvl=%d", id,
          tostring(e.name), il))
      end
    end
  end
end
print("   im Pool ohne Stufenangabe      : " .. noReq)
print("   davon mit Itemlevel > Stufe+12 : " .. noReqHighIlvl)
for i = 1, table.getn(samples) do print("      " .. samples[i]) end
print("")

------------------------------------------------------------------
print("== 2. Reichweite der Rangerkennung ==")
------------------------------------------------------------------

-- PreloadFromItemDB bedient alles, was der Import mit Werten kennt.
-- Nur der Rest geht ueber den Server - und nur dort liest das Addon
-- den Tooltip, also nur dort kann eine Rangbedingung auffallen.
local skipped, needStats = Cand:PreloadFromItemDB()

local fromImport, needsServer, skippedN = 0, 0, 0
for id in pairs(Cand.pool) do
  local c = BananaLootlineDB.itemcache[id]
  if not c then
    needsServer = needsServer + 1
  elseif c.skip then
    skippedN = skippedN + 1
  elseif c.db then
    fromImport = fromImport + 1
  else
    needsServer = needsServer + 1
  end
end

print("   aus dem Import bedient (kein Tooltip) : " .. fromImport)
print("   aussortiert                           : " .. skippedN)
print("   ueber den Server (Tooltip wird gelesen): " .. needsServer)
local total = fromImport + needsServer
if total > 0 then
  print(string.format("   -> Rangerkennung erreicht %.0f%% der verwertbaren Kandidaten",
    needsServer / total * 100))
end
