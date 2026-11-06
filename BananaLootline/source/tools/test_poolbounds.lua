-- Regressionstest zu 0.19.0.
--
-- Fehlerbild: ein Stufe-15-Jaeger bekam "Flintlocke's Hand Cannon"
-- (Itemlevel 65) und "Boots of Flowing Sands" (Itemlevel 65) aus Tanaris
-- vorgeschlagen, dazu 4118 Kandidaten statt gut 600.
--
-- Zwei Ursachen:
--   1. 2275 Eintraege der ItemDB fuehren keine Anforderungsstufe. Die
--      Pruefung "reqlevel <= Obergrenze" ist bei 0 immer wahr.
--   2. Der feste Rueckblick von 10 Stufen riss das Band auf 5-21 auf.
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
-- 1. Das Band muss mit der Stufe skalieren
------------------------------------------------------------------

local function bandFor(level)
  BLL.player = { class = "HUNTER", level = level }
  return Cand:Band()
end

local lo, hi = bandFor(15)
check(lo == 12 and hi == 21,
  "Stufe 15 -> Band 12-21, war " .. lo .. "-" .. hi)

lo, hi = bandFor(30)
check(lo == 25 and hi == 36,
  "Stufe 30 -> Band 25-36, war " .. lo .. "-" .. hi)

lo, hi = bandFor(60)
check(lo == 50 and hi == 63,
  "Stufe 60 -> Band 50-63, war " .. lo .. "-" .. hi)

-- Der Gewinn von 0.19.0 darf dabei nicht verloren gehen: am Stufenende
-- muss der Rueckblick weiterhin zehn Stufen betragen.
check(hi - lo == 13, "Stufe 60 behaelt das breite Band")

------------------------------------------------------------------
-- 2. Items ohne Anforderungsstufe duerfen nicht durchrutschen
------------------------------------------------------------------

BLL.player = { class = "HUNTER", level = 15 }
BananaLootlineDB.planAhead = 6

BLL.Sources = {
  available = true, items = {}, units = {}, quests = {},
  UnitLevel = function() return nil end,
  GetItemSources = function() return {} end,
}

-- Die echten Datensaetze aus der ItemDB, gekuerzt auf das Wesentliche.
BLL.ItemDB = {
  loaded = true,
  data = {
    -- Genau die beiden Teile aus dem Fehlerbericht: Itemlevel 65,
    -- KEINE Anforderungsstufe.
    [61011] = { name = "Flintlocke's Hand Cannon", ilvl = 65, quality = 4, slot = 15 },
    [61005] = { name = "Boots of Flowing Sands",   ilvl = 65, quality = 3, slot = 8  },
    -- Ebenfalls ohne Stufenangabe, aber passend fuer Stufe 15
    [1282]  = { name = "Sparkmetal Coif",          ilvl = 18, quality = 2, slot = 1  },
    -- Mit Stufenangabe, passend
    [300]   = { name = "Passend",                  ilvl = 20, quality = 2, slot = 5, reqlevel = 15 },
    -- Mit Stufenangabe, zu hoch
    [301]   = { name = "Zu hoch",                  ilvl = 40, quality = 3, slot = 5, reqlevel = 35 },
    -- Veraltet
    [302]   = { name = "Veraltet",                 ilvl = 4,  quality = 2, slot = 5, reqlevel = 1  },
  },
  Get = function(self, id) return self.data[id] end,
  MaskAllows = function() return true end,
}

Cand.StartQuery = function(self) self.state = "ready" end

local function buildPool()
  Cand:StartIndex(Cand:Band())
  local guard = 0
  while Cand.state == "indexing" or Cand.state == "indexdb" do
    guard = guard + 1
    if guard > 200 then check(false, "Poolaufbau haengt") return end
    if Cand.state == "indexing" then Cand:IndexChunk() else Cand:ImportChunk() end
  end
end

buildPool()

check(Cand.pool[61011] == nil,
  "Flintlocke's Hand Cannon (Itemlevel 65, keine Stufenangabe) bleibt draussen")
check(Cand.pool[61005] == nil,
  "Boots of Flowing Sands (Itemlevel 65, keine Stufenangabe) bleiben draussen")
check(Cand.pool[1282] ~= nil,
  "Sparkmetal Coif (Itemlevel 18, keine Stufenangabe) kommt rein")
check(Cand.pool[300] ~= nil, "Teil mit passender Stufenangabe kommt rein")
check(Cand.pool[301] == nil, "Teil ab Stufe 35 bleibt draussen")
check(Cand.pool[302] == nil, "veraltetes Teil bleibt draussen")

-- Die Poolstufe eines Teils ohne Angabe ist die geschaetzte
-- Anforderungsstufe, nicht das rohe Itemlevel.
check(Cand.pool[1282] == 13,
  "geschaetzte Stufe 13 statt Itemlevel 18, war " .. tostring(Cand.pool[1282]))

------------------------------------------------------------------
-- 3. Auf Stufe 60 muessen dieselben Teile erlaubt sein
------------------------------------------------------------------

BLL.player = { class = "HUNTER", level = 60 }
buildPool()

check(Cand.pool[61011] ~= nil,
  "auf Stufe 60 ist das Gewehr ein gueltiger Kandidat")
check(Cand.pool[61005] ~= nil,
  "auf Stufe 60 sind die Stiefel ein gueltiger Kandidat")
check(Cand.pool[1282] == nil,
  "auf Stufe 60 ist das Stufe-18-Teil veraltet")

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
