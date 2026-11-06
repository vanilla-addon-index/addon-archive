-- Rufvoraussetzung aus dem Import.
--
-- Gemeldet: Ruf- und Rangteile standen ohne Hinweis in der Liste. Der
-- Import fuehrt die Bedingung bei 411 Teilen, das Addon las sie nicht.
string.gmatch = nil; select = nil
BananaLootline = { locale = "enUS", clientLocale = "enUS",
                   L = setmetatable({}, { __index = function(t, k) return k end }) }
BananaLootlineDB = { planAhead = 0, itemcache = {} }
CreateFrame = function() return { SetScript = function() end, RegisterEvent = function() end } end
local BLL = BananaLootline
BLL.Print = function() end
dofile("Candidates.lua")
local Cand = BLL.Candidates
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local DB = {
  [1] = { name = "Argent Ring", rep = "Argent Dawn - Honored" },
  [2] = { name = "Plain Ring" },
  [3] = { name = "Odd", rep = "Unknown Faction - Revered" },
}
BLL.ItemDB = { loaded = true, Get = function(self, id) return DB[id] end,
               MaskAllows = function() return true end }

local factions = { { "Argent Dawn", 5 } }   -- Friendly
GetNumFactions = function() return table.getn(factions) end
GetFactionInfo = function(i) return factions[i][1], "", factions[i][2], 0, nil, nil, nil end

Cand:ReadReputation()
check(Cand:RepLock(1) == "Argent Dawn - Honored", "Freundlich reicht nicht fuer Wohlwollend")
check(Cand:RepLock(2) == nil, "ohne Bedingung frei")
check(Cand:RepLock(3) ~= nil, "unbekannte Fraktion gilt als nicht erfuellt")

factions[1][2] = 6   -- Honored
Cand:ReadReputation()
check(Cand:RepLock(1) == nil, "Wohlwollend erfuellt die Bedingung")
factions[1][2] = 8
Cand:ReadReputation()
check(Cand:RepLock(1) == nil, "Ehrfuerchtig erst recht")

-- IsUsable lehnt gesperrte Teile ab, ausser mit /bll locked
factions[1][2] = 4
Cand:ReadReputation()
local entry = { r = 10, e = "INVTYPE_FINGER" }
check(not Cand:IsUsable(entry, "ROGUE", 60, {}, 1), "Ring mit fehlendem Ruf ist nicht verwendbar")
check(Cand:IsUsable(entry, "ROGUE", 60, {}, 2), "Ring ohne Bedingung schon")
BananaLootlineDB.showLocked = true
check(Cand:IsUsable(entry, "ROGUE", 60, {}, 1), "/bll locked zeigt ihn trotzdem")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
