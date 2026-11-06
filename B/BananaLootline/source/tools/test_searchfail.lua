-- Ein Fehler in einem Suchschritt darf die Suche nicht still beenden,
-- und /bll selftest muss zeigen, was die Suche finden muesste.
-- Anlass: ein Tester auf Stufe 45 bekam "nichts Besseres gefunden",
-- Pool 0, keine Fehlermeldung.
string.gmatch = nil; select = nil
GetLocale = function() return "enUS" end
BananaLootline = { locale = "enUS", clientLocale = "enUS" }
dofile("Locale.lua")
local BLL = BananaLootline
BananaLootlineDB = { planAhead = 1, itemcache = {} }
local chat = {}
BLL.Print = function(self, m) table.insert(chat, m) end
local now = 100
GetTime = function() return now end
CreateFrame = function() return { SetScript = function() end, RegisterEvent = function() end } end
dofile("Candidates.lua")
local Cand = BLL.Candidates
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local DB = {
  [1] = { name = "A", slot = 6, reqlevel = 44, ilvl = 49, quality = 2, classmask = -1 },
  [2] = { name = "B", slot = 6, reqlevel = 20, ilvl = 25, quality = 2, classmask = -1 },
}
BLL.ItemDB = { loaded = true, data = DB, MaskAllows = function() return true end }
BLL.Sources = {
  available = true,
  items = { [10] = { U = { [5] = 50 } }, [11] = { U = { [6] = 50 } } },
  UnitLevel = function(self, id) return (id == 5) and "44" or "10" end,
}
BLL.player = { class = "PALADIN", level = 45 }

-- 1. Diagnose: pfQuest 1 von 2 im Band, Import 1
local d = Cand:Diagnose()
check(d.pfqTotal == 2 and d.pfqBand == 1, "pfQuest-Zaehlung " .. d.pfqBand .. "/" .. d.pfqTotal)
check(d.importBand == 1, "Import-Zaehlung " .. d.importBand)
check(not d.pfqError and not d.importError, "keine Fehler")

-- 2. Fehler im Import-Schritt wird gemeldet und haelt die Suche an
Cand:Run()
Cand:Tick(0.02)                          -- pfQuest-Schritt
check(Cand.state == "indexdb", "nach pfQuest kommt der Import, ist " .. tostring(Cand.state))
BLL.ItemDB.MaskAllows = function() error("kaputt") end
chat = {}
Cand:Tick(0.02)
check(Cand.state == "failed", "Zustand failed, ist " .. tostring(Cand.state))
check(Cand.lastError and string.find(Cand.lastError.msg, "kaputt", 1, true), "Fehlertext gemerkt")
check(chat[1] and string.find(chat[1], "indexdb", 1, true), "Fehler im Chat mit Schritt")
check(Cand:Progress() == BLL.L["PROG_FAILED"], "Fortschritt zeigt den Fehler")
Cand:Tick(0.02)
check(table.getn(chat) == 2, "nach dem Fehler keine weiteren Meldungen")

-- 3. Diagnose meldet den Importfehler
d = Cand:Diagnose()
check(d.importError and d.state == "failed", "Diagnose sieht Fehler")

-- 4. Haengende Suche wird erkannt
BLL.ItemDB.MaskAllows = function() return true end
Cand:Run()
now = now + 20
d = Cand:Diagnose()
check(d.stuck, "haengende Suche erkannt")

-- 5. Neue Suche setzt den Fehler zurueck und laeuft durch
Cand.StartQuery = function(self) self.state = "ready" end
Cand:Run()
check(Cand.lastError == nil, "neuer Lauf ohne alten Fehler")
for i = 1, 5 do Cand:Tick(0.02) end
check(Cand.state == "ready" and Cand.poolSize == 2, "Lauf fertig mit 2 Items, ist " .. tostring(Cand.poolSize))

for _, k in ipairs({ "CAND_ERROR", "CAND_ERROR_HINT", "PROG_FAILED", "ST_DIAG_PFQ", "ST_DIAG_IMPORT",
                     "ST_DIAG_STATE", "ST_DIAG_STUCK", "ST_DIAG_EMPTY", "ST_DIAG_FAIL" }) do
  check(BLL.L[k] and BLL.L[k] ~= k, "Text fehlt: " .. k)
end
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
