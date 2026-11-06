-- Die Phasensperre.
--
-- Der Anlass: ein Tester auf Stufe 57 bekam als besten Wegplan
-- Naxxramas, Ahn'Qiraj, den Smaragdgruenen Hain, die Obere Nekropole,
-- den Turm von Karazhan und den Felsen der Verwuestung - sechs Orte, die
-- es auf OctoWoW noch nicht gibt. Das Addon hat Erreichbarkeit nur an der
-- Gegnerstufe gemessen, und ein Stufe-63-Boss in Naxxramas sieht genauso
-- aus wie ein Stufe-63-Gegner in Silithus.
--
-- Dieser Test prueft zuerst die Mechanik und danach genau diesen Fall:
-- die sechs Orte muessen weg sein, und der Inhalt, den eine 57 wirklich
-- laufen kann, muss bleiben.
string.gmatch = nil; select = nil

CreateFrame = function()
  return { SetScript = function() end, RegisterEvent = function() end,
           SetOwner = function() end, ClearLines = function() end,
           Hide = function() end, SetHyperlink = function() end,
           NumLines = function() return 0 end }
end
WorldFrame = {}
GetItemInfo = function() return nil end
GameTooltip = { AddLine = function() end, NumLines = function() return 0 end,
                GetName = function() return "GameTooltip" end,
                SetHyperlink = function() end, IsShown = function() return false end }
getglobal = function() return nil end
UnitFactionGroup = function() return "Alliance" end
-- date() ist im Spiel ein Global, in nacktem Lua liegt es in os.
date = os.date

BananaLootline = {}
GetLocale = function() return "enUS" end
dofile("Locale.lua")
local BLL = BananaLootline
BLL.Print, BLL.Debug = function() end, function() end
dofile("Scanner.lua")

BananaLootlineDB = { itemcache = {}, planAhead = 6, minDropChance = 0 }

dofile("Data/ItemData.lua")
dofile("Data/SourceData.lua")
dofile("Data/ZoneNames.lua")
dofile("Data/NpcData.lua")
dofile("Phases.lua")
pfDB = nil
dofile("Sources.lua")
local S, P = BLL.Sources, BLL.Phases
S:Init()

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

------------------------------------------------------------------
-- 1. Die Termine stehen vollstaendig und in der richtigen Reihenfolge
------------------------------------------------------------------

check(table.getn(P.PHASES) == 7, "sieben Phasen, sind " .. table.getn(P.PHASES))

local prev = 0
for i = 1, table.getn(P.PHASES) do
  local ph = P.PHASES[i]
  check(ph.phase == i, "Phase " .. i .. " traegt ihre Nummer")
  local st = P.Stamp(ph)
  check(st > prev, "Phase " .. i .. " liegt nach der vorherigen")
  prev = st
end

-- Die Termine der Roadmap, Tag und Monat. Weicht einer ab, hat jemand die
-- Tabelle angefasst, ohne die Quelle zu pruefen.
local WANT = { {10,1}, {11,5}, {1,28}, {3,18}, {4,29}, {6,24}, {9,16} }
for i = 1, 7 do
  check(P.PHASES[i].m == WANT[i][1] and P.PHASES[i].d == WANT[i][2],
    "Phase " .. i .. " steht auf " .. WANT[i][2] .. "." .. WANT[i][1]
    .. ", steht auf " .. P.PHASES[i].d .. "." .. P.PHASES[i].m)
end

------------------------------------------------------------------
-- 2. Jede Zone gehoert zu genau einer Phase
------------------------------------------------------------------

local seen = {}
for i = 1, table.getn(P.PHASES) do
  local ph = P.PHASES[i]
  for j = 1, table.getn(ph.zones) do
    local z = ph.zones[j]
    check(not seen[z], "Zone " .. z .. " steht in zwei Phasen")
    seen[z] = ph.phase
    check(BananaLootlineZoneNames[z] ~= nil or z == 3478,
      "Zone " .. z .. " kommt im Datenbestand vor")
  end
end

-- Eine Zone ausserhalb der Liste ist offen. Das ist der Normalfall.
check(P:IsOpen(1584), "Blackrock Depths ist offen")
check(P:IsOpen(2717), "Molten Core ist offen")
check(P:IsOpen(5086), "Karazhan Crypt ist offen")
check(P:IsOpen(nil), "ohne Zonennummer wird nicht gesperrt")

------------------------------------------------------------------
-- 3. Timbermaw Hold bleibt absichtlich offen
--
-- Phase 5 heisst so, aber die beiden Zonen dieses Namens im
-- Datenbestand fuehren nur Questbelohnungen auf Queststufe 45 und 50 -
-- den Tunnel, der seit Serverstart offen ist. Wer die sperrt, nimmt
-- einem Stufe-45-Charakter Beute weg, die er holen kann.
------------------------------------------------------------------

check(P:IsOpen(1769), "Timbermaw Hold 1769 bleibt offen")
check(P:IsOpen(1216), "Timbermaw Hold 1216 bleibt offen")
check(table.getn(P.PHASES[5].zones) == 0,
  "Phase 5 fuehrt keine Zone, bis die Instanz im Datenbestand auftaucht")

------------------------------------------------------------------
-- 4. Das Datum entscheidet
------------------------------------------------------------------

local today = P.Today()
check(today ~= nil, "das Datum ist lesbar")
if today then
  check(today > 20200000, "und plausibel, ist " .. today)
  -- Phase 1 liegt am 01.10.2026. Alles ab diesem Tag muss sie offen sehen.
  if today >= 20261001 then
    check(P:PhaseOpen(1), "Phase 1 ist offen")
    check(P:IsOpen(1977), "Zul'Gurub ist offen")
  end
  -- Und eine Phase, deren Termin noch nicht erreicht ist, bleibt zu.
  for i = 1, 7 do
    local ph = P.PHASES[i]
    if P.Stamp(ph) > today then
      check(not P:PhaseOpen(ph.phase),
        "Phase " .. ph.phase .. " ist noch zu")
    end
  end
end

------------------------------------------------------------------
-- 4b. Ohne lesbares Datum gilt alles als gesperrt
--
-- Lieber eine Instanz zu wenig im Wegplan als ein Tester, der vier
-- Monate zu frueh nach Naxxramas laeuft. Mit /bll phase <Nr> on ist das
-- in einer Zeile behoben.
------------------------------------------------------------------

local realDate = date
date = nil
check(P.Today() == nil, "ohne date() gibt es kein Datum")
check(not P:PhaseOpen(1), "und dann ist auch Phase 1 zu")
check(not P:IsOpen(1977), "Zul'Gurub faellt raus")
check(P:IsOpen(1584), "eine Zone ausserhalb der Liste bleibt trotzdem offen")
-- Die eigene Angabe greift auch ohne Datum.
P:Set(1, true)
check(P:PhaseOpen(1), "von Hand geht es weiter")
P:Set(1, nil)
date = realDate
check(P.Today() ~= nil, "mit date() wieder lesbar")

------------------------------------------------------------------
-- 5. Die eigene Angabe schlaegt den Termin, in beide Richtungen
------------------------------------------------------------------

P:Set(6, true)
check(P:PhaseOpen(6), "Phase 6 von Hand geoeffnet")
check(P:IsOpen(3456), "und Naxxramas ist erreichbar")

P:Set(6, false)
check(not P:PhaseOpen(6), "Phase 6 von Hand geschlossen")

P:Set(1, false)
check(not P:PhaseOpen(1), "auch eine offene Phase laesst sich schliessen")
check(not P:IsOpen(1977), "und Zul'Gurub faellt damit raus")

P:Set(1, nil)
P:Set(6, nil)
check(P:PhaseOpen(1) == (today ~= nil and today >= 20261001),
  "nach dem Zuruecksetzen gilt wieder der Termin")

------------------------------------------------------------------
-- 6. Der gemeldete Fall
--
-- Die sechs Orte aus dem Fehlerbericht duerfen fuer eine Stufe 57 keine
-- einzige Quelle mehr liefern. Gemessen wird ueber IsReachable, also
-- ueber denselben Weg, den der Wegplan nimmt.
------------------------------------------------------------------

BLL.player = { level = 57, class = "PALADIN", race = "Human", faction = "Alliance" }

local REPORTED = { 3456, 5148, 3457, 5557, 3428, 5147, 5097, 3429, 2677 }
for i = 1, table.getn(REPORTED) do
  local z = REPORTED[i]
  check(not S:IsReachable({ stype = "U", name = "Boss", chance = 10,
                            level = 63, zoneID = z }),
    (BananaLootlineZoneNames[z] or z) .. " liefert keine Quelle mehr")
end

-- Und der Inhalt, den eine 57 laufen kann, bleibt. Blackrock Depths,
-- Hateforge Quarry und Dire Maul sind genau die Orte, die die
-- Vergleichsseite fuer denselben Charakter oben hat.
local KEEP = {}
for z, n in pairs(BananaLootlineZoneNames) do
  if n == "Blackrock Depths" or n == "Hateforge Quarry"
     or n == "Dire Maul" or n == "Scholomance" then
    table.insert(KEEP, z)
  end
end
check(table.getn(KEEP) >= 4, "die vier Vergleichsorte stehen im Datenbestand")
for i = 1, table.getn(KEEP) do
  check(S:IsReachable({ stype = "U", name = "Boss", chance = 10,
                        level = 58, zoneID = KEEP[i] }),
    (BananaLootlineZoneNames[KEEP[i]]) .. " bleibt erreichbar")
end

------------------------------------------------------------------
-- 7. Wieviel faellt tatsaechlich weg?
--
-- Nicht als Grenzwert, sondern als Zahl im Protokoll: wenn eine spaetere
-- Aenderung sie verschiebt, sieht man es hier.
------------------------------------------------------------------

local locked, total = 0, 0
for id, s in pairs(BananaLootlineSourceData) do
  for k, v in pairs(s) do
    for i = 1, table.getn(v) do
      local d = v[i]
      if d.z then
        total = total + 1
        if not P:IsOpen(d.z) then locked = locked + 1 end
      end
    end
  end
end
check(locked > 500, "ueber 500 Quellenzeilen sind gesperrt, sind " .. locked)
check(locked < total / 2, "aber nicht die Haelfte des Bestands")
print("   gesperrt: " .. locked .. " von " .. total .. " Quellenzeilen mit Ort")
print("   gesperrte Zonen: " .. P:LockedZoneCount())

------------------------------------------------------------------
-- 8. Die Version kommt aus einer Quelle
--
-- Bis 0.22.5 sagte die TOC 0.22.5 und der Selbsttest 0.21.1, weil die
-- Nummer an zwei Stellen stand.
------------------------------------------------------------------

local f = io.open("BananaLootline.toc", "r")
local tocVersion = nil
if f then
  for line in f:lines() do
    local _, _, v = string.find(line, "^##%s*Version:%s*(.+)$")
    if v then tocVersion = v end
  end
  f:close()
end
check(tocVersion ~= nil, "die TOC fuehrt eine Version")

local src = io.open("Core.lua", "r")
if src then
  local text = src:read("*a")
  src:close()
  check(not string.find(text, 'BLL%.VERSION%s*='),
    "BLL.VERSION steht nicht mehr fest im Code")
  local _, _, fb = string.find(text, 'BLL%.VERSION_FALLBACK%s*=%s*"([^"]+)"')
  check(fb == tocVersion,
    "der Rueckfallwert passt zur TOC: " .. tostring(fb)
    .. " gegen " .. tostring(tocVersion))
end

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
