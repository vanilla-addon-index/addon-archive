-- Setbonuszeilen im Tooltip ("Set: ..." und "(5) Set: ...").
--
-- Werden uebersprungen: SetDB bewertet Setboni nach getragenen Teilen.
-- Aus dem Tooltip gelesen machten sie das Teil "nicht vollstaendig
-- bewertbar" oder zaehlten doppelt.
string.gmatch = nil; select = nil

local currentLines = {}
local slots = {}
local function fs(name)
  local o = { text = "" }
  o.SetText = function(self, v) self.text = v or "" end
  o.GetText = function(self) return self.text end
  slots[name] = o
  return o
end
for i = 1, 40 do
  fs("BananaLootlineScanTooltipTextLeft" .. i)
  fs("BananaLootlineScanTooltipTextRight" .. i)
end
getglobal = function(n) return slots[n] end

local tip = {}
tip.SetOwner, tip.ClearLines, tip.Hide = function() end, function() end, function() end
tip.SetHyperlink = function()
  for i = 1, 40 do
    slots["BananaLootlineScanTooltipTextLeft" .. i]:SetText(currentLines[i] or "")
  end
end
tip.NumLines = function() return table.getn(currentLines) end
-- Candidates.lua legt sich einen eigenen Frame an und haengt Skripte
-- daran; derselbe Stummel bedient beides.
tip.SetScript, tip.RegisterEvent = function() end, function() end

CreateFrame = function() return tip end
WorldFrame  = {}
GetItemInfo = function() return nil end

BananaLootline = {}
GetLocale = function() return "enUS" end
dofile("Locale.lua")
local BLL = BananaLootline
BLL.Debug, BLL.Print = function() end, function() end
dofile("Scanner.lua")
local Scanner = BLL.Scanner

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local nextID = 0
local function scan(lines)
  currentLines = lines
  Scanner:ClearCache()
  nextID = nextID + 1
  return Scanner:GetStats(nextID)
end

-- Setbonuszeilen: weder Werte noch "unbezifferter Effekt".
--
-- Gemeldet von einem Tester mit Setteilen: Zeilen wie die Abklingzeit
-- von Verschwinden oder Energie-Rueckgewinnung machten das angelegte
-- Teil "nicht vollstaendig bewertbar". Setboni bewertet SetDB.
local st, meta = scan({ "Bloodfang Hood", "Leather", "+19 Agility", "+27 Stamina",
  "Bloodfang Armor (2/8)",
  "Set: Reduces the cooldown of your Vanish ability by 30 sec.",
  "(5) Set: Your melee attacks have a chance to restore 35 energy.",
  "(8) Set: Improves your chance to hit by 2%." })
check(st.AGI == 19 and st.STA == 27, "normale Werte bleiben")
check(not (meta and meta.unscored), "Setzeilen gelten nicht als unbewerteter Effekt")
check(not st.HIT, "Setbonus Treffer zaehlt nicht doppelt")

-- Gegenprobe: ein echter Anlegeeffekt ohne Muster bleibt unbewertet
local _, meta2 = scan({ "Test", "Equip: Chance on hit to restore 35 energy." })
check(meta2 and meta2.unscored, "echter Effekt bleibt unbewertet markiert")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
