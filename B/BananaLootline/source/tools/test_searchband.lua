-- Sucht das Stufenband, die Quellenstufe und den erweiterten Pool ab.
-- Deckt die Punkte ab, die dem Tester auf Stufe 60 keine Vorschlaege
-- geliefert haben.
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
local chat = {}
BLL.Print = function(self, m) table.insert(chat, m) end

dofile("Candidates.lua")
local Cand = BLL.Candidates

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

------------------------------------------------------------------
-- 1. Band: /bll ahead muss die Suche steuern
------------------------------------------------------------------

BLL.player = { class = "ROGUE", level = 60 }

BananaLootlineDB.planAhead = 6
local lo, hi = Cand:Band()
check(lo == 50 and hi == 63,
  "Stufe 60, ahead 6 -> Band 50-63, war " .. lo .. "-" .. hi)

-- Der eigentliche Fehlerbericht: ahead 60 gesetzt, gesucht wurde
-- trotzdem 57-63. Das untere Ende muss jetzt mitgehen, das obere ist
-- durch die hoechste Mobstufe gedeckelt.
BananaLootlineDB.planAhead = 60
lo, hi = Cand:Band()
check(lo == 50 and hi == 63,
  "Stufe 60, ahead 60 -> Band 50-63, war " .. lo .. "-" .. hi)

-- Auf niedriger Stufe wirkt ahead nach oben tatsaechlich. Der Rueckblick
-- ist dort bewusst kurz: drei Stufen bei Stufe 20, nicht zehn - siehe
-- test_poolbounds.lua.
BLL.player = { class = "ROGUE", level = 20 }
BananaLootlineDB.planAhead = 10
lo, hi = Cand:Band()
check(lo == 17 and hi == 30,
  "Stufe 20, ahead 10 -> Band 17-30, war " .. lo .. "-" .. hi)

-- Ein Argument schlaegt die gespeicherte Einstellung fuer diesen Lauf
lo, hi = Cand:Band(2)
check(lo == 17 and hi == 22,
  "Stufe 20, Argument 2 -> Band 17-22, war " .. lo .. "-" .. hi)
check(BananaLootlineDB.planAhead == 10,
  "Argument aendert die gespeicherte Vorausplanung nicht")

------------------------------------------------------------------
-- 2. Quellenstufe: beste Quelle IM BAND statt globalem Minimum
------------------------------------------------------------------

local UNITS = { [1] = { lvl = "40" }, [2] = { lvl = "62" }, [3] = { lvl = "12" } }
BLL.Sources = {
  available = true,
  units  = UNITS,
  quests = {},
  items  = {},
  UnitLevel = function(self, id) local u = UNITS[id]; return u and u.lvl end,
  GetItemSources = function() return {} end,
}

-- Raidteil: faellt von einem 62er, haengt aber auch an einem 40er Mob.
-- Frueher gewann die 40 und das Item fiel aus jedem 60er-Band.
local raidItem = { U = { [1] = 5, [2] = 100 } }
local band = { min = 50, max = 63 }
check(Cand:SourceLevel(900, raidItem, band) == 62,
  "Quelle im Band gewinnt gegen niedrigere ausserhalb")

-- Ohne Band bleibt es beim Minimum, damit andere Aufrufer gleich bleiben
check(Cand:SourceLevel(900, raidItem, nil) == 40,
  "ohne Band weiterhin die niedrigste Quelle")

-- Liegt keine Quelle im Band, faellt es auf das Minimum zurueck und der
-- Aufrufer sortiert das Item wie bisher aus.
local lowItem = { U = { [3] = 50 } }
check(Cand:SourceLevel(901, lowItem, band) == 12,
  "keine Quelle im Band -> niedrigste Quelle")

------------------------------------------------------------------
-- 3. Pool: Items aus dem Import ergaenzen die aus pfQuest
------------------------------------------------------------------

BLL.player = { class = "ROGUE", level = 60 }
BananaLootlineDB.planAhead = 6

-- pfQuest kennt nur Item 10. Der Import kennt zusaetzlich 20 und 21.
BLL.Sources.items = { [10] = { U = { [2] = 50 } } }
BLL.ItemDB = {
  loaded = true,
  data = {
    [10] = { name = "mit Fundort", ilvl = 60, reqlevel = 55, quality = 3, slot = 5 },
    [20] = { name = "ohne Fundort", ilvl = 62, reqlevel = 58, quality = 3, slot = 5 },
    [21] = { name = "zu alt",      ilvl = 20, reqlevel = 18, quality = 3, slot = 5 },
    [22] = { name = "zu hoch",     ilvl = 70, reqlevel = 70, quality = 3, slot = 5 },
    [23] = { name = "grau",        ilvl = 60, reqlevel = 55, quality = 0, slot = 5 },
  },
  Get = function(self, id) return self.data[id] end,
  MaskAllows = function() return true end,
}

-- StartQuery haengt am Itemcache und der Serverabfrage; hier nur
-- feststellen, dass der Pool danach steht.
local queried = false
Cand.StartQuery = function(self) queried = true; self.state = "ready" end

-- Mit Notbremse: eine Zustandsmaschine, die nicht weiterschaltet, soll
-- den Test scheitern lassen und nicht den Testlauf aufhaengen.
local function drain(state)
  local guard = 0
  while Cand.state == state do
    guard = guard + 1
    if guard > 200 then
      check(false, "Zustand " .. state .. " schaltet nicht weiter")
      return false
    end
    if state == "indexing" then Cand:IndexChunk() else Cand:ImportChunk() end
  end
  return true
end

Cand:StartIndex(50, 63)
drain("indexing")
check(Cand.pfqCount == 1, "pfQuest liefert 1 Kandidaten, war " .. tostring(Cand.pfqCount))
check(Cand.state == "indexdb", "danach laeuft der Importdurchlauf")

drain("indexdb")
check(queried, "nach dem Import wird die Abfrage gestartet")

check(Cand.pool[10] ~= nil, "Item mit Fundort ist im Pool")
check(Cand.pool[20] ~= nil, "Item aus dem Import ist im Pool")
check(Cand.pool[21] == nil, "veraltetes Item bleibt draussen")
check(Cand.pool[22] == nil, "zu hohe Stufe bleibt draussen")
check(Cand.pool[23] == nil, "graues Item bleibt draussen")

check(Cand.fromImport[10] == nil, "pfQuest-Item gilt nicht als ohne Fundort")
check(Cand.fromImport[20] == 1,   "Importitem ist als ohne Fundort markiert")
check(Cand.importCount == 1, "genau ein Item ohne Fundort gezaehlt")

-- Die Meldung nennt beide Zahlen
local last = chat[table.getn(chat)]
check(string.find(last, "CAND_FOUND_MIX") ~= nil,
  "Meldung nutzt den kombinierten Text, war: " .. tostring(last))

------------------------------------------------------------------
-- 4. Klassenmaske greift schon beim Poolaufbau
------------------------------------------------------------------

BLL.ItemDB.MaskAllows = function() return false end
Cand:StartIndex(50, 63)
drain("indexing")
drain("indexdb")
check(Cand.pool[20] == nil, "Item fremder Klasse kommt nicht in den Pool")

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
