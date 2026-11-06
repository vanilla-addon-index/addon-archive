-- Zugangsbedingungen aus AtlasLoot.
--
-- AtlasLoot fuehrt in AtlasLoot_Data["AtlasLootSources"] zu ueber 7000
-- Gegenstaenden einen Herkunftstext. Von dort stammt die Zeile
-- "Warsong Gulch - Revered" am Tooltip von Gegenstand 20437, die weder
-- im Scan-Tooltip noch in der Serverdatenbank steht.
--
-- Geprueft wird gegen die Konstanten des Clients, damit der Abgleich in
-- jeder Sprache greift.
string.gmatch = nil; select = nil

CreateFrame = function()
  return { SetScript = function() end, RegisterEvent = function() end }
end

-- Die Client-Konstanten, aus denen AtlasLoot seine Texte baut
FACTION_STANDING_LABEL5 = "Friendly"
FACTION_STANDING_LABEL6 = "Honored"
FACTION_STANDING_LABEL7 = "Revered"
FACTION_STANDING_LABEL8 = "Exalted"
RANK = "Rank"

BananaLootline = {
  locale = "enUS", clientLocale = "enUS",
  L = setmetatable({}, { __index = function(t, k) return k end }),
}
BananaLootlineDB = { planAhead = 6, itemcache = {} }
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
BLL.ItemDB = { loaded = false, Get = function() return nil end,
               MaskAllows = function() return true end }
BLL.Scanner = { GetStats = function() return nil, nil end,
                GetItemID = function(_, x) return x end }

dofile("Candidates.lua")
local Cand = BLL.Candidates
BLL.player = { class = "HUNTER", level = 15 }
Cand.skills = { known = { [2] = true, [3] = true }, dualWield = true }
Cand.skillsDirty = false

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

------------------------------------------------------------------
-- 1. Ohne AtlasLoot passiert nichts
------------------------------------------------------------------

AtlasLoot_Data = nil
check(Cand:AtlasRestriction(20437) == nil,
  "ohne AtlasLoot kein Ergebnis, kein Absturz")

------------------------------------------------------------------
-- 2. Die echten Eintraege aus der Datenbank
------------------------------------------------------------------

AtlasLoot_Data = {
  AtlasLootSources = {
    -- so steht es woertlich in TooltipStrings.lua
    [20437] = "Warsong Gulch - Revered",
    [17052] = "Thorium Brotherhood - Revered",
    [17903] = "Stormpike Guard - Exalted",
    [15198] = "PvP Rank 6",
    -- keine Zugangsbedingung, nur eine Fundortangabe
    [10413] = "Wailing Caverns - Lord Pythas (2.3%)",
    [12640] = "Blacksmithing (Skill: 300)",
    [872]   = "The Deadmines - Rhahk'Zor (5%)",
  },
}

check(Cand:AtlasRestriction(20437) == "Warsong Gulch - Revered",
  "Rufbedingung des Bogens erkannt")
check(Cand:AtlasRestriction(17052) ~= nil, "zweite Rufbedingung erkannt")
check(Cand:AtlasRestriction(17903) ~= nil, "Ehrfuerchtig erkannt")
check(Cand:AtlasRestriction(15198) ~= nil, "PvP-Rang erkannt")

-- Gegenprobe: gewoehnliche Fundorte duerfen nicht anschlagen
check(Cand:AtlasRestriction(10413) == nil, "Dungeondrop schlaegt nicht an")
check(Cand:AtlasRestriction(872) == nil,   "zweiter Dungeondrop schlaegt nicht an")
check(Cand:AtlasRestriction(12640) == nil, "Berufsangabe schlaegt nicht an")
check(Cand:AtlasRestriction(99999) == nil, "unbekannte Nummer liefert nichts")

------------------------------------------------------------------
-- 3. Andere Clientsprache
--
-- AtlasLoot baut aus denselben Konstanten, also muss der Abgleich
-- mitgehen, ohne dass wir eine Wortliste pflegen.
------------------------------------------------------------------

FACTION_STANDING_LABEL7 = "Respektvoll"
AtlasLoot_Data.AtlasLootSources[20437] = "Kriegshymnenschlucht - Respektvoll"
check(Cand:AtlasRestriction(20437) == "Kriegshymnenschlucht - Respektvoll",
  "deutscher Client wird genauso erkannt")
FACTION_STANDING_LABEL7 = "Revered"
AtlasLoot_Data.AtlasLootSources[20437] = "Warsong Gulch - Revered"

------------------------------------------------------------------
-- 4. Der Gegenstand verschwindet aus den Vorschlaegen
------------------------------------------------------------------

BananaLootlineDB.itemcache = {
  [20437] = { e = "INVTYPE_RANGED", st = { AGI = 20 }, r = 18, q = 3,
              n = "Outrider's Bow", ic = 2, sc = 2 },
  [2500]  = { e = "INVTYPE_RANGED", st = { AGI = 10 }, r = 16, q = 2,
              n = "Normaler Bogen", ic = 2, sc = 2 },
}
Cand.pool = { [20437] = 18, [2500] = 16 }
Cand.fromImport = {}

local ups = Cand:GetUpgrades("RangedSlot", 5)
local found = {}
for i = 1, table.getn(ups or {}) do found[ups[i].id] = true end

check(found[20437] == nil, "der rufgebundene Bogen wird nicht vorgeschlagen")
check(found[2500] ~= nil, "der frei erhaeltliche Bogen bleibt")

-- Und der Befund steht dauerhaft im Cache
check(BananaLootlineDB.itemcache[20437].lock == "Warsong Gulch - Revered",
  "Bedingung im Cache vermerkt")

-- Mit /bll locked wieder sichtbar
BananaLootlineDB.showLocked = true
ups = Cand:GetUpgrades("RangedSlot", 5)
found = {}
for i = 1, table.getn(ups or {}) do found[ups[i].id] = true end
check(found[20437] ~= nil, "mit /bll locked wieder sichtbar")

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
