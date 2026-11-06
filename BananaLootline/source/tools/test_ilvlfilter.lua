-- Itemlevel-Filter (/bll ilvl), Vorschlag eines Testers.
string.gmatch = nil; select = nil
BananaLootline = { locale = "enUS", clientLocale = "enUS",
                   L = setmetatable({}, { __index = function(t, k) return k end }) }
BananaLootlineDB = { itemcache = {} }
CreateFrame = function() return { SetScript = function() end, RegisterEvent = function() end } end
local BLL = BananaLootline
BLL.Print = function() end
dofile("Candidates.lua")
local Cand = BLL.Candidates
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end
local DB = { [1] = { ilvl = 58 }, [2] = { ilvl = 70 }, [3] = { ilvl = 88 }, [4] = {} }
BLL.ItemDB = { Get = function(self, id) return DB[id] end }

check(Cand:IlvlAllows(1) and Cand:IlvlAllows(3), "ohne Filter alles erlaubt")
BananaLootlineDB.ilvlMin, BananaLootlineDB.ilvlMax = 60, 80
check(not Cand:IlvlAllows(1), "58 unter der Grenze")
check(Cand:IlvlAllows(2), "70 im Bereich")
check(not Cand:IlvlAllows(3), "88 ueber der Grenze")
check(Cand:IlvlAllows(4), "ohne Itemlevel bleibt drin")
BananaLootlineDB.ilvlMax = nil
check(Cand:IlvlAllows(3), "nur Untergrenze: 88 erlaubt")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
