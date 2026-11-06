-- Erkennung von Effekten, die kein Wertmuster erfasst.
--
-- Das groesste Risiko dieser Heuristik sind Fehlalarme: jede harmlose
-- Zeile, die faelschlich als "unbewerteter Effekt" gilt, laesst das
-- Addon echte Vorschlaege zurueckhalten. Dieser Test prueft deshalb vor
-- allem die Gegenrichtung - was NICHT anschlagen darf.
string.gmatch = nil; select = nil

------------------------------------------------------------------
-- Tooltip-Attrappe: liefert vorgegebene Zeilen
------------------------------------------------------------------

local currentLines = {}
local slots = {}

local function fontString(name)
  local o = { text = "" }
  o.SetText = function(self, v) self.text = v or "" end
  o.GetText = function(self) return self.text end
  slots[name] = o
  return o
end

for i = 1, 40 do
  fontString("BananaLootlineScanTooltipTextLeft" .. i)
  fontString("BananaLootlineScanTooltipTextRight" .. i)
end

getglobal = function(name) return slots[name] end

local tip = {}
tip.SetOwner      = function() end
tip.ClearLines    = function() end
tip.Hide          = function() end
tip.SetHyperlink  = function()
  for i = 1, 40 do
    slots["BananaLootlineScanTooltipTextLeft" .. i]:SetText(currentLines[i] or "")
  end
end
tip.NumLines = function() return table.getn(currentLines) end

CreateFrame = function() return tip end
WorldFrame  = {}
GetItemInfo = function() return nil end

BananaLootline = {}
GetLocale = function() return "enUS" end
dofile("Locale.lua")
local BLL = BananaLootline
BLL.Debug = function() end
BLL.Print = function() end
dofile("Scanner.lua")
local Scanner = BLL.Scanner

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local nextID = 1

-- GetStats liefert die Werte und eine Metatabelle. Die Tests hier
-- interessiert daraus nur .unscored, deshalb wird sie gleich ausgepackt.
local function scan(lines)
  currentLines = lines
  Scanner:ClearCache()
  nextID = nextID + 1
  local stats, meta = Scanner:GetStats(nextID)
  return stats, meta and meta.unscored or nil
end

local function scanUnscored(lines)
  local _, unscored = scan(lines)
  return unscored
end

------------------------------------------------------------------
-- 1. Muss anschlagen: echte Proc-Effekte ohne Werte
------------------------------------------------------------------

local procs = {
  "Equip: 2% chance on being hit to gain 1 extra attack on your current target.",
  "Chance on hit: Blasts a target for 40 Fire damage.",
  "Use: Increases your speed by 40% for 10 sec.",
  "Equip: 1% chance when struck in combat to increase your Strength by 65.",
}
for i = 1, table.getn(procs) do
  local u = scanUnscored({ "Testschmuck", procs[i] })
  check(u ~= nil and table.getn(u) == 1,
    "Proc nicht erkannt: " .. procs[i])
end

------------------------------------------------------------------
-- 2. Darf NICHT anschlagen: Zeilen, aus denen ein Wert kommt
--
-- Diese enthalten teils das Wort "chance", werden aber von einem Muster
-- erfasst. Wer sie trotzdem markiert, unterdrueckt echte Vorschlaege.
------------------------------------------------------------------

local scored = {
  { "Equip: Improves your chance to hit by 1%.",                          "HIT"      },
  { "Equip: Improves your chance to get a critical strike by 1%.",        "CRIT"     },
  { "Equip: Increases your chance to dodge an attack by 1%.",             "DODGE"    },
  { "Equip: Increases your chance to parry an attack by 1%.",             "PARRY"    },
  { "Equip: Increases your chance to block attacks with a shield by 1%.", "BLOCK"    },
  { "Equip: Improves your chance to hit with spells by 1%.",              "SPELLHIT" },
}
for i = 1, table.getn(scored) do
  local line, key = scored[i][1], scored[i][2]
  local stats, u = scan({ "Testteil", line })
  check(stats and stats[key] ~= nil, "Wert nicht gelesen: " .. line)
  check(u == nil, "Fehlalarm bei bewerteter Zeile: " .. line)
end

------------------------------------------------------------------
-- 3. Darf NICHT anschlagen: gewoehnliche Werte und Rahmentext
------------------------------------------------------------------

local harmless = {
  { "Vagabond Leggings" },
  { "Leggings", "+4 Agility", "+5 Stamina", "57 Armor" },
  { "Schwert", "24 - 37 Damage", "Speed 2.40", "(12.7 damage per second)" },
  { "Ring", "+3 Intellect", "Requires Level 40", "Soulbound" },
}
for i = 1, table.getn(harmless) do
  local u = scanUnscored(harmless[i])
  check(u == nil, "Fehlalarm bei harmlosem Item: "
    .. (harmless[i][2] or harmless[i][1] or "?"))
end

------------------------------------------------------------------
-- 4. Gemischtes Item: Werte UND Proc
------------------------------------------------------------------

local stats, u = scan({
  "Hand of Justice",
  "+2 Attack Power",
  "Equip: Increases attack power by 20.",
  "Equip: 2% chance on being hit to gain 1 extra attack on your current target.",
})
check(stats and stats["AP"] ~= nil, "Werte des gemischten Items gelesen")
check(u ~= nil and table.getn(u) == 1,
  "Proc des gemischten Items erkannt, gefunden: " .. table.getn(u or {}))

------------------------------------------------------------------
-- 5. Der Cache muss beide Teile zurueckgeben
------------------------------------------------------------------

currentLines = {
  "Cachetest",
  "Equip: 2% chance on being hit to gain 1 extra attack.",
}
Scanner:ClearCache()
local s1, u1 = Scanner:GetStats(4242)
local s2, u2 = Scanner:GetStats(4242)     -- jetzt aus dem Cache
check(u1 ~= nil and u2 ~= nil, "Cache liefert den Effektvermerk erneut")
check(s1 == s2, "Cache liefert dieselbe Werttabelle")

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
