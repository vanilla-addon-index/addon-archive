-- Pruefung der erzeugten Daten gegen die Faelle aus den
-- Testerberichten. Laedt die vier Datendateien und stellt Fragen, deren
-- Antwort aus den Berichten bekannt ist.
--
-- Aufruf aus dem Verzeichnis, in dem Data/ liegt.
string.gmatch = nil; select = nil

dofile("Data/ItemData.lua")
dofile("Data/SourceData.lua")
dofile("Data/ZoneNames.lua")
dofile("Data/NpcData.lua")

local I = BananaLootlineItemData
local S = BananaLootlineSourceData
local Z = BananaLootlineZoneNames
local N = BananaLootlineNpcNames

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local function count(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

------------------------------------------------------------------
-- 1. Die Dateien sind da und nicht leer
------------------------------------------------------------------

check(count(I) > 14000, "ItemData hat ueber 14000 Eintraege, hat " .. count(I))
check(count(S) > 11000, "SourceData hat ueber 11000 Eintraege, hat " .. count(S))
check(count(Z) > 100,   "ZoneNames hat ueber 100 Zonen, hat " .. count(Z))
check(count(N) > 5000,  "NpcData hat ueber 5000 Namen, hat " .. count(N))

------------------------------------------------------------------
-- 2. Feet of the Lynx
--
-- Der Bericht: die Octo-Datenbank nennt keinen Gegner mit 1,9 Prozent.
-- pfQuest fuehrt den "Eroded Anubisath Warbringer" auf Stufe 61 mit
-- 1,92 Prozent - fuer einen Stufe-19-Gegenstand. Die Daten hier duerfen
-- keine Quelle jenseits des Stufenbereichs des Gegenstands kennen.
------------------------------------------------------------------

local lynx = I[1121]
check(lynx ~= nil, "Feet of the Lynx ist in ItemData")
check(lynx and lynx.reqlevel == 19, "Feet of the Lynx ab Stufe 19")
check(lynx and lynx.slot == 8, "Feet of the Lynx ist ein Fussteil")

local src = S[1121]
check(src ~= nil and src.d ~= nil, "Feet of the Lynx hat Gegnerquellen")
if src and src.d then
  local worst, best = 0, 0
  for i = 1, table.getn(src.d) do
    local row = src.d[i]
    if (row.l or 0) > worst then worst = row.l end
    if (row.p or 0) > best then best = row.p end
  end
  check(worst <= 30, "kein Gegner ueber Stufe 30, hoechster war " .. worst)
  check(best < 0.1, "keine Quelle ueber 0,1 Prozent, beste war " .. best)
end

------------------------------------------------------------------
-- 3. Outrider's Bow - zwei Gegenstaende mit demselben Namen
--
-- Der Jaeger auf Stufe 15 sieht 20437 (ab Stufe 18). Die Suche nach dem
-- Namen fuehrt auf 19558 (ab Stufe 60). Beide gehoeren demselben
-- Haendler, und keiner verlangt Ruf - der Tooltip des Testers zeigte
-- "Warsong Gulch - Revered", das kam aus AtlasLoot.
------------------------------------------------------------------

check(I[20437] and I[20437].reqlevel == 18, "20437 ab Stufe 18")
check(I[19558] and I[19558].reqlevel == 60, "19558 ab Stufe 60")
check(I[20437] and I[20437].name == I[19558].name,
  "beide heissen gleich - Namenssuche ist nicht eindeutig")
check(I[20437] and I[20437].rep == nil,
  "20437 verlangt keinen Ruf")
check(I[19558] and I[19558].rep == nil,
  "19558 verlangt keinen Ruf")

for _, id in ipairs({ 20437, 19558 }) do
  local s = S[id]
  check(s and s.v and s.v[1], id .. " hat einen Haendler")
  if s and s.v and s.v[1] then
    check(s.v[1].n == 14754, id .. " beim Haendler 14754")
    check(N[14754] == "Kelm Hargunth", "Haendler 14754 heisst Kelm Hargunth")
    check(s.v[1].f == 2, id .. " ist ein Hordenhaendler")
    check(s.v[1].c and s.v[1].c > 0, id .. " hat einen Preis")
    check(s.v[1].z and Z[s.v[1].z], id .. " hat eine benannte Zone")
  end
end

-- Der guenstige Bogen kostet weniger als der teure
check(S[20437].v[1].c < S[19558].v[1].c,
  "der Bogen ab Stufe 18 ist billiger als der ab Stufe 60")

-- 20437 traegt keine Attribute, nur Waffenschaden. Genau deshalb sah der
-- Jaeger nichts Brauchbares - der Gegenstand hat ausser Schaden nichts
-- zu bieten. 19558 dagegen hat Ausdauer und Beweglichkeit.
local function attrs(e)
  local n = 0
  for _, key in ipairs({ "STR", "AGI", "STA", "INT", "SPI" }) do
    if (e.stats or {})[key] then n = n + 1 end
  end
  return n
end
check(I[20437] and attrs(I[20437]) == 0,
  "20437 hat kein einziges Attribut, das ist kein Fehler der Bewertung")
check(I[19558] and attrs(I[19558]) == 2,
  "19558 hat Ausdauer und Beweglichkeit")
check(I[20437] and I[20437].stats.WEAPON_DPS,
  "20437 hat trotzdem Waffenschaden")

------------------------------------------------------------------
-- 4. Punkt 7: Sondereffekte sind gekennzeichnet
--
-- Vorher schaetzte Candidates.lua mit UNSCORED_FLAT und
-- UNSCORED_SHARE, ob ein Gegenstand einen Proc haben koennte. Jetzt
-- steht es in den Daten.
------------------------------------------------------------------

check(I[647] and I[647].proc == 1, "Destiny hat einen Treffereffekt")
check(I[744] and I[744].proc == 2, "Boot Flask hat einen Benutzeffekt")

local procs, rep = 0, 0
for _, e in pairs(I) do
  if e.proc then procs = procs + 1 end
  if e.rep then rep = rep + 1 end
end
check(procs > 500, "ueber 500 Gegenstaende mit Sondereffekt, sind " .. procs)
check(rep > 300, "ueber 300 Gegenstaende mit Rufanforderung, sind " .. rep)

------------------------------------------------------------------
-- 5. Questbelohnungen
--
-- pfQuest hat unter ["Q"] keinen einzigen Eintrag. Der Zweig im Addon
-- war toter Code.
------------------------------------------------------------------

local quests = 0
for _, s in pairs(S) do
  if s.q then quests = quests + 1 end
end
check(quests > 2000, "ueber 2000 Gegenstaende aus Quests, sind " .. quests)
check(S[60] and S[60].q and S[60].q[1].q == 6,
  "Layered Tunic kommt aus Quest 6")
check(S[60].q[1].x == 3,
  "Layered Tunic ist eine von drei Auswahlbelohnungen")

------------------------------------------------------------------
-- 6. Sockelplaetze der Waffen
--
-- Der Export nennt den Platz bei Waffen nur im Text. Die Umrechnung
-- muss die Zahlen liefern, die SLOTNUM_INVTYPE erwartet.
------------------------------------------------------------------

check(I[647]   and I[647].slot   == 17, "Destiny ist eine Zweihandwaffe")
check(I[2098]  and I[2098].slot  == 15, "Schrotflinte ist Distanz")
check(I[4547]  and I[4547].slot  == 26, "Zauberstab ist Distanz rechts")
check(I[12939] and I[12939].slot == 22, "Dal'Rend Guardian ist Schildhand")
check(I[1121]  and I[1121].slot  == 8,  "Feet of the Lynx ist Fuesse")
check(I[12846] and I[12846].slot == 12, "Anstecknadel ist Schmuck")

------------------------------------------------------------------
-- 7. Klassenmasken
--
-- 2047 und 32767 haben jedes Bit gesetzt und bedeuten "alle".
-- Sie muessen zu -1 geworden sein.
------------------------------------------------------------------

local wide = 0
for _, e in pairs(I) do
  if e.classmask == 2047 or e.classmask == 32767 then wide = wide + 1 end
end
check(wide == 0, "keine Maske mit allen Bits mehr uebrig, sind " .. wide)
check(I[20041] and I[20041].classmask == 3,
  "Highlander's Plate Girdle ist fuer Krieger und Paladin")

------------------------------------------------------------------
-- 8. Jede Quelle mit Zone hat einen Namen
------------------------------------------------------------------

local rows, located, nameless = 0, 0, 0
for _, s in pairs(S) do
  for _, key in ipairs({ "d", "v" }) do
    for i = 1, table.getn(s[key] or {}) do
      local row = s[key][i]
      rows = rows + 1
      if row.z then
        located = located + 1
        if not Z[row.z] then nameless = nameless + 1 end
      end
      if row.n and not N[row.n] then nameless = nameless + 1 end
    end
  end
end
check(nameless == 0, "jede Zone und jeder NPC hat einen Namen, offen: " .. nameless)
check(located / rows > 0.85,
  "ueber 85 Prozent der Quellen haben einen Ort, sind "
  .. math.floor(located / rows * 100) .. "%")

print("Quellenzeilen " .. rows .. ", mit Ort " .. located
      .. " (" .. math.floor(located / rows * 100) .. "%)")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
