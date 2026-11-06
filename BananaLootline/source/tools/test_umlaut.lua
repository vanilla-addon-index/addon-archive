-- Deutsche Muster mit Umlaut.
--
-- "St[aä]rke" sieht nach einer Zeichenklasse mit zwei Buchstaben aus,
-- ist aber eine mit drei BYTES: das ae steht in der Datei als UTF-8,
-- also \195\164. Die Klasse passt damit auf genau eines dieser Bytes,
-- ein echtes "ä" im Tooltip besteht aber aus zweien. Das Muster konnte
-- auf keinem Client greifen - weder auf einem mit UTF-8 noch auf einem
-- mit Latin-1.
--
-- "St.-rke" frisst ein Byte oder zwei und deckt damit alle
-- Schreibweisen ab.
string.gmatch = nil; select = nil

BananaLootline = {}
GetLocale = function() return "deDE" end
dofile("Locale.lua")
local BLL = BananaLootline

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

-- Muster zum Statschluessel finden
local function patternFor(key)
  for i = 1, table.getn(BLL.PATTERNS) do
    if BLL.PATTERNS[i][1] == key then return BLL.PATTERNS[i][2] end
  end
end

local STR = patternFor("STR")
local ARM = patternFor("ARMOR")
check(STR ~= nil and ARM ~= nil, "Muster fuer STR und ARMOR vorhanden")

-- Dieselbe Zeile in drei Schreibweisen:
--   UTF-8      \195\164   (was ein Client ueblicherweise liefert)
--   Latin-1    \228       (was ein aelterer Client liefern koennte)
--   ASCII      ae / a     (Ersatzschreibweise)
local strLines = {
  { "UTF-8",   "+10 St\195\164rke" },
  { "Latin-1", "+10 St\228rke"     },
  { "ASCII",   "+10 Starke"        },
}
for i = 1, table.getn(strLines) do
  local tag, line = strLines[i][1], strLines[i][2]
  local _, _, v = string.find(line, STR)
  check(v == "10", "Staerke nicht erkannt (" .. tag .. "): " .. line)
end

local armLines = {
  { "UTF-8",   "115 R\195\188stung" },
  { "Latin-1", "115 R\252stung"     },
  { "ASCII",   "115 Rustung"        },
}
for i = 1, table.getn(armLines) do
  local tag, line = armLines[i][1], armLines[i][2]
  local _, _, v = string.find(line, ARM)
  check(v == "115", "Ruestung nicht erkannt (" .. tag .. "): " .. line)
end

-- Gegenprobe: das Muster darf nicht auf beliebiges zugreifen
local _, _, v = string.find("+10 Beweglichkeit", STR)
check(v == nil, "Staerke-Muster greift faelschlich auf Beweglichkeit")

-- Negative Werte weiterhin erkannt
local neg
for i = 1, table.getn(BLL.PATTERNS) do
  local p = BLL.PATTERNS[i]
  if p[1] == "STR" and p[3] == -1 then neg = p[2] end
end
check(neg ~= nil, "Muster fuer negative Staerke vorhanden")
if neg then
  local _, _, nv = string.find("-5 St\195\164rke", neg)
  check(nv == "5", "negative Staerke nicht erkannt")
end

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
