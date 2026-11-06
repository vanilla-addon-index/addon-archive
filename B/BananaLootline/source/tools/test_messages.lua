-- Prueft, dass die Statusmeldungen wirklich an der Sprache haengen.
--
-- Der Fehlerbericht war: Schalter steht auf EN, die Meldungen kommen
-- trotzdem auf Deutsch. Ursache waren fest im Code stehende Texte.
-- Dieser Test deckt drei Dinge ab:
--   1. beide Sprachtabellen fuehren dieselben Schluessel
--   2. ihre Formatplatzhalter passen zueinander (sonst crasht format)
--   3. im Quelltext steht keine Meldung mehr fest verdrahtet
string.gmatch = nil; select = nil

BananaLootline = {}
GetLocale = function() return "deDE" end      -- deutscher Client
dofile("Locale.lua")

local BLL = BananaLootline
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

------------------------------------------------------------------
-- 1. Anzeigesprache laesst sich unabhaengig vom Client umstellen
------------------------------------------------------------------

check(BLL.clientLocale == "deDE", "Clientsprache wird erkannt")

BLL:SetLanguage("deDE")
local de = {}
for k, v in pairs(BLL.L) do de[k] = v end

BLL:SetLanguage("enUS")
local en = {}
for k, v in pairs(BLL.L) do en[k] = v end

check(BLL.locale == "enUS", "Anzeigesprache folgt der Auswahl")
check(BLL.clientLocale == "deDE",
  "Clientsprache bleibt unberuehrt - sonst brechen die Tooltipmuster")

-- Die Tabelle selbst muss dieselbe bleiben: andere Dateien halten sie
-- in einer lokalen Variable fest.
local before = BLL.L
BLL:SetLanguage("deDE")
check(BLL.L == before, "L bleibt dieselbe Tabelle, nur der Inhalt wechselt")
BLL:SetLanguage("enUS")

------------------------------------------------------------------
-- 2. Beide Sprachen fuehren dieselben Schluessel
------------------------------------------------------------------

local missingEN, missingDE = {}, {}
for k in pairs(de) do if en[k] == nil then table.insert(missingEN, k) end end
for k in pairs(en) do if de[k] == nil then table.insert(missingDE, k) end end

check(table.getn(missingEN) == 0,
  "Schluessel fehlen in enUS: " .. table.concat(missingEN, ", "))
check(table.getn(missingDE) == 0,
  "Schluessel fehlen in deDE: " .. table.concat(missingDE, ", "))

-- Ein paar der neu umgestellten Meldungen muessen sich unterscheiden,
-- sonst wurde nur kopiert statt uebersetzt.
local mustDiffer = { "CAND_SEARCHING", "CAND_FOUND", "CAND_DONE", "AHEAD_SET",
                     "RATE_INFO", "CACHE_CLEARED", "HELP_HEADER", "PROG_INDEX" }
for i = 1, table.getn(mustDiffer) do
  local k = mustDiffer[i]
  check(de[k] and en[k] and de[k] ~= en[k],
    k .. " ist in beiden Sprachen gleich oder fehlt")
end

------------------------------------------------------------------
-- 3. Formatplatzhalter muessen zueinander passen
--
-- string.format(L["X"], a, b) laeuft in beide Sprachen. Steht in der
-- einen ein Platzhalter mehr, kracht es genau dann, wenn jemand die
-- Sprache umstellt - also beim Nutzer, nicht beim Entwickler.
------------------------------------------------------------------

local function specs(s)
  local clean = string.gsub(s, "%%%%", "")   -- echtes Prozentzeichen
  local out = {}
  for c in string.gfind(clean, "%%[%-%+ #0]*%d*%.?%d*([diouxXeEfgGqcs])") do
    table.insert(out, c)
  end
  return table.concat(out, ",")
end

for k in pairs(de) do
  if en[k] then
    local a, b = specs(de[k]), specs(en[k])
    check(a == b, k .. ": Platzhalter deDE [" .. a .. "] != enUS [" .. b .. "]")
  end
end

------------------------------------------------------------------
-- 4. Im Quelltext darf keine Meldung mehr fest verdrahtet sein
------------------------------------------------------------------

local function scan(path)
  local f = io.open(path, "r")
  if not f then check(false, path .. " nicht lesbar") return end
  local n, bad = 0, {}
  for line in f:lines() do
    n = n + 1
    -- Aufrufe wie Print("Text ...") ohne Rueckgriff auf L
    if string.find(line, 'Print%(%s*"') and not string.find(line, "L%[") then
      -- Reine Farbcodes und Formatketten sind erlaubt, solange der Text
      -- selbst aus L kommt - die faengt die L-Pruefung oben ab.
      table.insert(bad, path .. ":" .. n .. "  " .. line)
    end
  end
  f:close()
  check(table.getn(bad) == 0,
    "fest verdrahtete Meldung:\n      " .. table.concat(bad, "\n      "))
end

scan("Core.lua")
scan("Candidates.lua")

------------------------------------------------------------------
-- 5. Alle in der Hilfe benutzten Schluessel muessen existieren
------------------------------------------------------------------

local f = io.open("Core.lua", "r")
if f then
  local src = f:read("*a")
  f:close()
  for key in string.gfind(src, '"(HELP_[A-Z_]+)"') do
    check(en[key] ~= nil and de[key] ~= nil,
      "Hilfeschluessel " .. key .. " fehlt in einer Sprache")
  end
end

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
