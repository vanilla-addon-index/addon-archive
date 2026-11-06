-- Phasensperre
--
-- Ein Tester auf Stufe 57 bekam als besten Wegplan Naxxramas, Ahn'Qiraj,
-- den Smaragdgruenen Hain, die Obere Nekropole, den Turm von Karazhan und
-- den Felsen der Verwuestung vorgeschlagen. Alle sechs Orte sind auf
-- OctoWoW noch nicht offen. Gemessen an seinem Kandidatenpool kamen 524
-- von 2385 Dropzeilen aus Inhalt, der auf dem Server nicht existiert.
--
-- Das Addon hat das nicht gemerkt, weil es Erreichbarkeit nur an der
-- Gegnerstufe gemessen hat. Ein Stufe-63-Boss in Naxxramas und ein
-- Stufe-63-Elitegegner in Silithus sahen fuer den Code gleich aus.
--
-- Deshalb diese Datei. Sie fuehrt die Freigabetermine der Phasen und
-- ordnet ihnen Zonen zu. Eine Zone, deren Phase noch nicht offen ist,
-- liefert keine Quellen.
--
-- HERKUNFT DER TERMINE
--
-- https://octowow.st/roadmap, abgerufen am 01.10.2026. Die Seite nennt
-- Tag und Monat ohne Jahr. Phase 1 fiel auf den 1. Oktober, und das war
-- der Tag des Abrufs, also liegen Phase 1 und 2 in 2026 und die
-- restlichen in 2027. Weicht der Server davon ab, laesst sich jede Phase
-- mit "/bll phase <nr> on|off" von Hand umstellen; die eigene Angabe
-- schlaegt das Datum.
--
-- ZUORDNUNG DER ZONEN
--
-- Vier der sieben Phasen nennen ihre Instanz so, wie sie auch im
-- Datenbestand heisst: Blackwing Lair, Emerald Sanctum, Ahn'Qiraj,
-- Naxxramas, Tower of Karazhan. Zwei Zonen tragen eigene Namen und sind
-- ueber ihre Beute zugeordnet, nicht ueber den Namen:
--
--   5148 "The Upper Necropolis" fuehrt Glyph of Deflection und Slayer's
--        Crest auf Itemstufe 90 - beides Naxxramas-Schmuckstuecke des
--        Originals. Also Phase 6.
--   5557 "The Rock of Desolation" fuehrt Itemstufe 96, hoeher als alles
--        in Naxxramas, mit Namen wie Mephistroth's Cunning und
--        Netherwrought Bracers. Also Phase 7, der hoechste Inhalt.
--
-- Beide Zuordnungen sind begruendet, nicht belegt. Wer es besser weiss,
-- stellt die Phase von Hand um.
--
-- TIMBERMAW HOLD IST ABSICHTLICH NICHT GESPERRT
--
-- Phase 5 heisst "Timbermaw Hold". Die beiden Zonen dieses Namens im
-- Datenbestand (1769, 1216) fuehren aber nur neun Questbelohnungen auf
-- Itemstufe 55 bis 58, Queststufe 45 und 50 - das ist der Tunnel, der
-- seit Serverstart offen ist, nicht die Instanz der Phase 5. Wer sie
-- sperrt, nimmt einem Stufe-45-Charakter Beute weg, die er holen kann.
-- Die Instanz der Phase 5 steht noch nicht im Datenbestand; sobald sie
-- auftaucht, kommt ihre Zonennummer hier in Phase 5.

local BLL = BananaLootline
BLL.Phases = {}
local P = BLL.Phases

-- Jahr, Monat, Tag der Freigabe; zones sind Zonennummern aus
-- Data/ZoneNames.lua.
P.PHASES = {
  { phase = 1, y = 2026, m = 10, d =  1, key = "Zul'Gurub",
    zones = { 1977, 19 } },
  { phase = 2, y = 2026, m = 11, d =  5, key = "Blackwing Lair",
    zones = { 2677 } },
  { phase = 3, y = 2027, m =  1, d = 28, key = "Emerald Sanctum",
    zones = { 5097 } },
  { phase = 4, y = 2027, m =  3, d = 18, key = "Ahn'Qiraj",
    zones = { 3428, 3429, 5147, 3478 } },
  { phase = 5, y = 2027, m =  4, d = 29, key = "Timbermaw Hold",
    zones = {} },
  { phase = 6, y = 2027, m =  6, d = 24, key = "Naxxramas",
    zones = { 3456, 5148 } },
  { phase = 7, y = 2027, m =  9, d = 16, key = "Tower of Karazhan",
    zones = { 3457, 5557 } },
}

-- Zone -> Phaseneintrag. Einmal gebaut, danach nur gelesen.
local byZone = nil

local function Index()
  if byZone then return byZone end
  byZone = {}
  for i = 1, table.getn(P.PHASES) do
    local ph = P.PHASES[i]
    for j = 1, table.getn(ph.zones) do
      byZone[ph.zones[j]] = ph
    end
  end
  return byZone
end

-- Heutiges Datum als Zahl JJJJMMTT.
--
-- date() gehoert zum Spiel-Lua und gibt die lokale Zeit des Rechners.
-- Auf die Stunde kommt es hier nicht an: eine Phase, die um 08:00 UTC
-- aufgeht, ist am selben Tag frei, und ein paar Stunden Vorlauf sind
-- harmloser als ein ganzer Tag Sperre nach der Freigabe.
local function Today()
  if type(date) ~= "function" then return nil end
  local ok, s = pcall(date, "%Y%m%d")
  if not ok then return nil end
  local n = tonumber(s)
  if n and n > 19000000 and n < 30000000 then return n end
  return nil
end

P.Today = Today

local function Stamp(ph) return ph.y * 10000 + ph.m * 100 + ph.d end

P.Stamp = Stamp

-- Phaseneintrag einer Zone, oder nil fuer alles, was in keiner Phase
-- steht. Das ist der Normalfall: 89 der 96 Zonen mit Beute im
-- Datenbestand sind seit Serverstart offen.
function P:Of(zoneID)
  if not zoneID then return nil end
  return Index()[zoneID]
end

-- Ist die Phase dieser Nummer offen?
function P:PhaseOpen(num)
  local own = BananaLootlineDB and BananaLootlineDB.phaseOpen
  if own and own[num] ~= nil then
    return own[num] and true or false
  end
  local ph = nil
  for i = 1, table.getn(P.PHASES) do
    if P.PHASES[i].phase == num then ph = P.PHASES[i]; break end
  end
  if not ph then return true end
  local today = Today()
  -- Ohne lesbares Datum nichts versprechen. Lieber eine Instanz zu
  -- wenig im Wegplan als ein Tester, der vier Monate zu frueh nach
  -- Naxxramas laeuft. Mit "/bll phase <nr> on" ist das in einer Zeile
  -- behoben.
  if not today then return false end
  return today >= Stamp(ph)
end

-- Die Frage, die der Rest des Addons stellt.
function P:IsOpen(zoneID)
  local ph = self:Of(zoneID)
  if not ph then return true end
  return self:PhaseOpen(ph.phase)
end

-- Fuer die Anzeige: nil wenn offen, sonst der Phaseneintrag.
function P:Locked(zoneID)
  local ph = self:Of(zoneID)
  if not ph then return nil end
  if self:PhaseOpen(ph.phase) then return nil end
  return ph
end

-- Datum einer Phase als TT.MM.JJJJ, sprachneutral.
function P:DateText(ph)
  return string.format("%02d.%02d.%04d", ph.d, ph.m, ph.y)
end

-- Von Hand setzen oder zuruecknehmen. nil heisst: wieder nach Datum.
function P:Set(num, open)
  if not BananaLootlineDB then return end
  if open == nil then
    if BananaLootlineDB.phaseOpen then
      BananaLootlineDB.phaseOpen[num] = nil
    end
    return
  end
  BananaLootlineDB.phaseOpen = BananaLootlineDB.phaseOpen or {}
  BananaLootlineDB.phaseOpen[num] = open and true or false
end

-- Wieviele Zonen sind gerade gesperrt? Gebraucht fuer /bll info.
function P:LockedZoneCount()
  local n = 0
  for z, ph in pairs(Index()) do
    if not self:PhaseOpen(ph.phase) then n = n + 1 end
  end
  return n
end
