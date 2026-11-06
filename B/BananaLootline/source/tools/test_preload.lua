string.gmatch = nil; select = nil
BananaLootline = { locale = "deDE", clientLocale = "enUS", L = setmetatable({}, { __index = function(t, k) return k end }) }
BananaLootlineDB = { planAhead = 6, itemcache = {} }
CreateFrame = function() return { SetScript = function() end, RegisterEvent = function() end } end
local BLL = BananaLootline
dofile("Candidates.lua")
local Cand = BLL.Candidates
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

-- slot 5 = Brust, itemclass 4 = Ruestung, subclass 3 = Kette, 2 = Leder
local DB = {
  [1] = { name = "Leder 18",  slot = 5, reqlevel = 18, itemclass = 4, subclass = 2, stats = { AGI = 5 } },
  [2] = { name = "Kette 40",  slot = 5, reqlevel = 40, itemclass = 4, subclass = 3, stats = { AGI = 9 } },
  [3] = { name = "Leder 30",  slot = 5, reqlevel = 30, itemclass = 4, subclass = 2, stats = { AGI = 7 } },
}
BLL.ItemDB = { loaded = true, Get = function(self, id) return DB[id] end, MaskAllows = function() return true end }
Cand.pool = { [1] = 18, [2] = 40, [3] = 30 }
local cache = BananaLootlineDB.itemcache

-- Jaeger 15: Stufe 18 liegt in der Vorausplanung (15+6), Stufe 30 nicht
BLL.player = { class = "HUNTER", level = 15 }
Cand:PreloadFromItemDB()
check(cache[1] and not cache[1].skip and cache[1].r == 18, "Stufe 18 mit Werten im Cache (Vorausplanung)")
check(cache[3] and cache[3].skip and cache[3].pre, "Stufe 30 vorlaeufig aussortiert")

-- Aufstieg auf 40: Kette erlaubt, Stufe 30 jetzt passend
BLL.player = { class = "HUNTER", level = 40 }
Cand:PreloadFromItemDB()
check(cache[3] and not cache[3].skip, "nach Aufstieg: Stufe 30 wieder drin")
check(cache[2] and not cache[2].skip and cache[2].a ~= nil, "nach Aufstieg: Kette ab 40 drin")

-- Alte Markierung ohne "pre" aus frueheren Fassungen wird neu bewertet
cache[1] = { skip = 1 }
Cand:PreloadFromItemDB()
check(cache[1] and not cache[1].skip, "alte Dauer-Markierung aufgehoben")

-- Serverfehler bleiben bestehen (kein erneutes Anfragen) - aber nur,
-- wenn der Import keine Werte hat und die Anfrage noetig waere.
DB[4] = { name = "Ohne Werte", slot = 5, reqlevel = 15, itemclass = 4, subclass = 2 }
Cand.pool[4] = 15
cache[4] = { skip = 1, fail = 1 }
Cand:PreloadFromItemDB()
check(cache[4] and cache[4].fail, "fail-Markierung bleibt ohne Importwerte")

-- "Belt of Binding": einmal als Serverfehler markiert, fehlte es in
-- jeder Liste, obwohl der Import alle Werte fuehrt.
cache[1] = { skip = 1, fail = 1 }
Cand:PreloadFromItemDB()
check(cache[1] and not cache[1].skip and cache[1].st,
  "fail-Markierung faellt, wenn der Import Werte hat")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
