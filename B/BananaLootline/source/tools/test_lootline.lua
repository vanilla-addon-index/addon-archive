-- Der Wegplan beantwortet eine einzige Frage: wohin als naechstes?
--
-- Zwei Dinge standen dem im Weg:
--   1. Haendlerware gilt als sicher und bekommt den vollen Zuwachs
--      angerechnet, ein Dungeondrop nur seinen Anteil nach Dropchance.
--      Ungefiltert stand der Haendler deshalb immer oben.
--   2. Eine Sammelgruppe "kein Fundort" beantwortet die Frage nicht.
string.gmatch = nil; select = nil

BananaLootline = {
  locale = "enUS", clientLocale = "enUS",
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
BLL.SetDB = { loaded = false }

-- Vier Kandidaten auf vier Plaetzen: Haendler, Dungeon, Quest und
-- einer ganz ohne Fundort.
local SOURCES = {
  [10] = { { stype = "V", name = "Haendler Hargunth", zone = "The Barrens" } },
  [20] = { { stype = "U", name = "Boss", zone = "Wailing Caverns", chance = 5 } },
  [30] = { { stype = "Q", name = "Eine Quest", id = 777 } },
  [40] = { },
  -- Beste Quelle ohne Ort, schlechtere mit: der Wegplan muss die
  -- schlechtere nehmen, sonst faellt das Teil aus der Liste. 301
  -- Gegenstaende im Datenbestand sehen so aus.
  [50] = { { stype = "U", name = "Unbekannter Mob", chance = 9 },
           { stype = "U", name = "Bekannter Mob", zone = "Uldaman", chance = 2 } },
  -- Der Fall aus dem Bericht: ein Drop von einem seltenen Elitegegner
  -- und eine Quest im selben Gebiet. Die Gruppe hiess [QUEST], obwohl
  -- der Drop das gewichtigere Teil ist. Hier Desolace statt Barrens,
  -- weil Barrens oben schon die Haendlerzone ist.
  [60] = { { stype = "U", name = "Humar the Pridelord", zone = "Desolace",
             chance = 1.613, level = 23, elite = 2 } },
  [70] = { { stype = "Q", name = "Kul Tiran Provisions", zone = "Desolace",
             id = 888, questLevel = 10 } },
}
BLL.Sources = {
  available = true, items = {}, units = {}, quests = {},
  UnitLevel = function() return nil end,
  GetItemSources = function(self, id) return SOURCES[id] or {} end,
}

local SLOTS = { { key = "HeadSlot" }, { key = "HandsSlot" },
                { key = "FeetSlot" }, { key = "WaistSlot" },
                { key = "BackSlot" }, { key = "WristSlot" },
                { key = "NeckSlot" } }
BLL.Gear = { SLOTS = SLOTS, SlotLabel = function(s, x) return x.key end, equipped = {} }
BLL.ItemDB = { loaded = false, Get = function() return nil end,
               MaskAllows = function() return true end }

-- Die Stammdaten der Instanzen, damit die Kategorie eines Ortes
-- geprueft werden kann: ein Dungeon bleibt ein Dungeon, auch wenn man
-- wegen einer Quest hingeht.
dofile("Data/ZoneData.lua")
dofile("Candidates.lua")
local Cand = BLL.Candidates
BLL.player = { class = "HUNTER", level = 15 }
Cand.skills = { known = {}, dualWield = true }
Cand.skillsDirty = false

BananaLootlineDB.itemcache = {
  [10] = { e = "INVTYPE_HEAD", st = { AGI = 30 }, r = 15, q = 3, n = "Vom Haendler" },
  [20] = { e = "INVTYPE_HAND", st = { AGI = 20 }, r = 15, q = 3, n = "Aus dem Dungeon" },
  [30] = { e = "INVTYPE_FEET", st = { AGI = 20 }, r = 15, q = 3, n = "Aus der Quest" },
  [40] = { e = "INVTYPE_WAIST", st = { AGI = 25 }, r = 15, q = 3, n = "Ohne Fundort" },
  [50] = { e = "INVTYPE_CLOAK", st = { AGI = 22 }, r = 15, q = 3, n = "Ort erst in Quelle zwei" },
  -- Der Drop ist das gewichtigere Teil, die Quest das schwaechere.
  [60] = { e = "INVTYPE_WRIST", st = { AGI = 40 }, r = 15, q = 3, n = "Vom Elitegegner" },
  [70] = { e = "INVTYPE_NECK",  st = { AGI = 5  }, r = 15, q = 3, n = "Aus der Quest" },
}
Cand.pool = { [10] = 15, [20] = 15, [30] = 15, [40] = 15, [50] = 15,
              [60] = 15, [70] = 15 }
Cand.fromImport = { [40] = 1 }

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local function zones()
  local groups = Cand:GetLootline(3)
  local out = {}
  for i = 1, table.getn(groups or {}) do out[groups[i].zone] = groups[i] end
  return out, groups
end

------------------------------------------------------------------
-- 1. Standard: kein Haendler, kein ortloser Eintrag
------------------------------------------------------------------

Cand:SetSourceCat("HAENDLER", false)
local z, groups = zones()

check(z["The Barrens"] == nil, "Haendlerzone erscheint nicht ohne Haken")
check(z["Wailing Caverns"] ~= nil, "der Dungeon erscheint")
check(z["Quests"] ~= nil, "Quests erscheinen als eigene Gruppe")
for k in pairs(z) do
  check(k ~= "No location" and k ~= "Ohne Ortsangabe",
    "Sammelgruppe ohne Fundort erscheint nicht: " .. k)
end

------------------------------------------------------------------
-- 2. Mit Haken erscheint der Haendler
------------------------------------------------------------------

Cand:SetSourceCat("HAENDLER", true)
z = zones()
check(z["The Barrens"] ~= nil, "mit Haken erscheint die Haendlerzone")
check(z["Wailing Caverns"] ~= nil, "der Dungeon bleibt daneben bestehen")

------------------------------------------------------------------
-- 3. Der Haken aendert nichts an der Einzelansicht
--
-- Dort geht es um "was ist fuer diesen Platz besser", nicht um einen
-- Weg. Haendlerware gehoert da weiterhin hin.
------------------------------------------------------------------

Cand:SetSourceCat("HAENDLER", false)
local ups = Cand:GetUpgrades("HeadSlot", 5)
local found = false
for i = 1, table.getn(ups or {}) do if ups[i].id == 10 then found = true end end
check(found, "Haendlerware bleibt in der Einzelansicht sichtbar")

-- Und das Teil ohne Fundort ebenfalls
ups = Cand:GetUpgrades("WaistSlot", 5)
found = false
for i = 1, table.getn(ups or {}) do if ups[i].id == 40 then found = true end end
check(found, "Teil ohne Fundort bleibt in der Einzelansicht sichtbar")

local got = zones()
check(got["Uldaman"] ~= nil,
  "das Teil, dessen Ort erst in der zweiten Quelle steht, landet in Uldaman")
if got["Uldaman"] then
  check(got["Uldaman"].items[1] and got["Uldaman"].items[1].id == 50,
    "und zwar das richtige Teil")
end

------------------------------------------------------------------
-- Beschriftung und Elitekennung
------------------------------------------------------------------

local g2 = zones()
local bar = g2["Desolace"]
check(bar ~= nil, "die Gruppe entsteht")
if bar then
  check(table.getn(bar.items) == 2, "mit beiden Teilen, sind "
    .. table.getn(bar.items))
  -- Der Drop bringt 40 Punkte, die Quest 5. Die Beschriftung folgt dem
  -- gewichtigeren Teil, nicht der Reihenfolge der Ruestungsplaetze.
  check(bar.category == "WELT",
    "die Gruppe heisst nach dem gewichtigeren Teil WELT, heisst " .. tostring(bar.category))
end

-- Der Ort schlaegt die Quellenart. Die Hoehlen des Wehklagens sind ein
-- Dungeon, ob man wegen einer Quest oder wegen eines Drops hingeht.
-- Die Gruppe "The Deadmines" stand als [QUEST] da, weil die
-- Questbelohnung das gewichtigste Teil war.
local wc = g2["Wailing Caverns"]
check(wc ~= nil, "die Dungeongruppe entsteht")
if wc then
  check(wc.category == "DUNGEON",
    "sie heisst DUNGEON, nicht nach ihrer Quellenart, heisst "
    .. tostring(wc.category))
end

if bar then
  local drop
  for i = 1, table.getn(bar.items) do
    if bar.items[i].id == 60 then drop = bar.items[i] end
  end
  check(drop ~= nil, "das Teil vom Elitegegner ist dabei")
  check(drop and drop.elite == 2, "und traegt die Elitekennung")
  check(drop and drop.sourceLevel == 23, "und die Stufe des Gegners")
end

------------------------------------------------------------------
-- Die besten Teile eines Platzes haben keinen Ort
--
-- Gemeldet an einem Stufe-16-Jaeger: beim Guertel lagen "Deviate Scale
-- Belt" (hergestellt), "Dark Leather Belt" und "Mosshide Cinch" (ohne
-- Fundort) vorn. Der Wegplan nahm die drei besten je Platz und warf sie
-- erst danach hinaus - "Belt of Binding" aus Frostmane Hollow (33 %)
-- kam nie in Betracht. turtlelootline.com setzte genau diesen Ort an
-- die Spitze.
------------------------------------------------------------------

table.insert(BLL.Gear.SLOTS, { key = "LegsSlot" })
for id = 80, 82 do
  SOURCES[id] = {}
  BananaLootlineDB.itemcache[id] = { e = "INVTYPE_LEGS", st = { AGI = 60 - id + 80 },
                                     r = 15, q = 3, n = "Ohne Ort " .. id }
  Cand.pool[id] = 15
end
SOURCES[83] = { { stype = "U", name = "Hailar the Frigid", zone = "Frostmane Hollow",
                  chance = 33.33, level = 16, elite = 1 } }
BananaLootlineDB.itemcache[83] = { e = "INVTYPE_LEGS", st = { AGI = 12 }, r = 15, q = 3,
                                   n = "Belt of Binding" }
Cand.pool[83] = 15

local fh = zones()["Frostmane Hollow"]
check(fh ~= nil, "Frostmane Hollow erscheint, obwohl drei bessere Teile keinen Ort haben")
check(fh and fh.items[1] and fh.items[1].id == 83, "mit dem verorteten Teil")
check(fh and fh.category == "DUNGEON", "als Dungeon")

-- Die Einzelansicht zeigt weiterhin die drei besten, Ort hin oder her.
ups = Cand:GetUpgrades("LegsSlot", 3)
check(ups and table.getn(ups) == 3 and ups[1].id == 80,
  "die Einzelansicht bleibt nach Zuwachs sortiert")

------------------------------------------------------------------
-- Quellenfilter (Dropdown): Vorschlag eines Testers
------------------------------------------------------------------

-- Nur Dungeon: Quest- und Weltgruppen verschwinden, Dungeons bleiben
for _, c in ipairs(Cand.SOURCE_CATS) do Cand:SetSourceCat(c, c == "DUNGEON") end
local zf = zones()
check(zf["Wailing Caverns"] ~= nil, "Dungeon bleibt bei Filter Dungeon")
check(zf["Quests"] == nil, "Questgruppe verschwindet bei Filter Dungeon")
check(zf["Desolace"] == nil, "Weltgebiet verschwindet bei Filter Dungeon")

-- Nur Quest
for _, c in ipairs(Cand.SOURCE_CATS) do Cand:SetSourceCat(c, c == "QUEST") end
zf = zones()
check(zf["Wailing Caverns"] == nil, "Dungeon verschwindet bei Filter Quest")
check(zf["Quests"] ~= nil, "Quests bleiben bei Filter Quest")

-- Kategorie einer Quelle
check(Cand:RowCategory({ stype = "Q", zone = "Wailing Caverns" }) == "QUEST", "Questbelohnung ist QUEST, auch im Dungeon")
check(Cand:RowCategory({ stype = "V", zone = "The Barrens" }) == "HAENDLER", "Haendler ist HAENDLER")
check(Cand:RowCategory({ stype = "U", zone = "Wailing Caverns" }) == "DUNGEON", "Drop im Dungeon ist DUNGEON")
check(Cand:RowCategory({ stype = "U", zone = "Alterac Valley" }) == "SCHLACHTFELD", "Alteractal ist SCHLACHTFELD")
check(Cand:RowCategory({ stype = "U", zone = "Westfall" }) == "WELT", "Westfall ist WELT")

-- Pro Item: Teile ohne Quelle nur mit NOSOURCE
for _, c in ipairs(Cand.SOURCE_CATS) do Cand:SetSourceCat(c, not Cand.SOURCE_DEFAULT_OFF[c]) end
local acc = Cand:SlotViewAccept()
check(acc and not acc({ sources = {} }), "ohne NOSOURCE fallen Teile ohne Quelle heraus")
check(acc({ sources = { { stype = "U", zone = "Westfall" } } }), "Weltdrop bleibt")
check(not acc({ sources = { { stype = "V", zone = "The Barrens" } } }), "Haendlerware faellt standardmaessig heraus")
for _, c in ipairs(Cand.SOURCE_CATS) do Cand:SetSourceCat(c, true) end
check(Cand:SlotViewAccept() == nil, "alles an: kein Filter")

-- Alte Haken werden uebernommen
BananaLootlineDB.sourceFilter = nil
BananaLootlineDB.showVendors, BananaLootlineDB.showUnsourced = true, nil
check(Cand:SourceFilter().HAENDLER and not Cand:SourceFilter().NOSOURCE, "Haken Haendler zeigen wird uebernommen")

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
