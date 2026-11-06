-- Questreihe zu einer Questbelohnung, an den echten Daten.
--
-- "Tunic of Westfall" ist eine Belohnung von "The Defias Brotherhood"
-- (166), dem Ende einer Reihe, die in Westfall bei Gryan Stoutmantle
-- anfaengt. Ein Klick auf das Teil soll die Reihe von vorn zeigen.
string.gmatch = nil; select = nil
CreateFrame = function() return { SetScript = function() end, RegisterEvent = function() end } end
GetLocale = function() return "deDE" end
BananaLootline = {}
dofile("Locale.lua")
local BLL = BananaLootline
BLL.locale = "deDE"
BLL.Print = function() end; BLL.Debug = function() end
BananaLootlineDB = {}
dofile("Data/ItemData.lua"); dofile("Data/SourceData.lua"); dofile("Data/ZoneNames.lua")
dofile("Data/NpcData.lua"); dofile("Data/QuestData.lua")
dofile("ItemDB.lua"); BLL.ItemDB:Refresh()
GameTooltip = { AddLine=function() end, NumLines=function() return 0 end, GetName=function() return "GameTooltip" end, SetHyperlink=function() end, Show=function() end }; WorldFrame = {}; getglobal = function() return nil end
pfDB = nil
dofile("Sources.lua"); BLL.Sources:Init()
UnitFactionGroup = function() return "Alliance" end
UnitRace = function() return "Human", "Human" end
BLL.player = { class = "HUNTER", level = 16 }
dofile("QuestInfo.lua")
local QI = BLL.QuestInfo
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local chain = QI:Chain(166, 2041)
check(table.getn(chain) >= 3, "Reihe hat mehrere Schritte, sind " .. table.getn(chain))
check(chain[table.getn(chain)].id == 166, "die Belohnungsquest steht zuletzt")
check(chain[table.getn(chain)].title == "The Defias Brotherhood", "mit ihrem Namen")
local giver = QI:Npc(chain[table.getn(chain)].giver)
check(giver and giver.name == "Gryan Stoutmantle", "Questgeber Gryan Stoutmantle, ist "
  .. tostring(giver and giver.name))
check(giver and giver.zone == "Westfall", "in Westfall, ist " .. tostring(giver and giver.zone))
check(giver and giver.x and giver.y, "mit Koordinaten")
for i = 2, table.getn(chain) do
  local pre = chain[i].pre or {}
  local found = false
  for _, p in ipairs(pre) do if p == chain[i - 1].id then found = true end end
  check(found, "Schritt " .. i .. " setzt Schritt " .. (i - 1) .. " voraus")
end

-- Auswahlbelohnung: Tunic of Westfall ist eine von mehreren
local rw = QI:Rewards(166)
check(table.getn(rw) >= 2, "Auswahl mit mehreren Teilen")

local text, n = QI:Text(166, 2041)
check(n == table.getn(chain), "Text zeigt alle Schritte")
check(string.find(text, "Annehmen:", 1, true), "Text nennt den Questgeber")
check(string.find(text, "Gryan Stoutmantle", 1, true), "mit Namen")
check(string.find(text, "Belohnung", 1, true), "und markiert die Belohnungsquest")
check(not string.find(text, "Unit #", 1, true), "alle NPCs mit Namen, nicht als Nummer")
print(text)

-- Unbekannte Quest: kein Absturz
local t2 = QI:Text(99999999)
check(t2 and string.find(t2, "keine Einzelheiten", 1, true), "unbekannte Quest wird gemeldet")
-- Klassenquests: Darkmantle-Teile (Schurken-Set) aus "An Earnest
-- Proposition" gehoeren nur Schurken. Gemeldet: Belohnungen aus
-- Klassenquests standen bei allen Klassen.
BLL.player = { class = "ROGUE", level = 60 }
local r1 = BLL.Sources:GetItemSources(22004)
check(r1 and r1[1] and r1[1].stype == "Q", "Schurke bekommt die Schurkenquest")
BLL.player = { class = "HUNTER", level = 60 }
local r2 = BLL.Sources:GetItemSources(22004)
check(not r2 or table.getn(r2) == 0, "Jaeger bekommt sie nicht")
BLL.player = { class = "HUNTER", level = 16 }

-- Lage: links neben dem Hauptfenster, sonst rechts, ohne Hauptfenster mittig
local function fr(left, visible)
  return { pts = nil, ClearAllPoints = function(self) self.pts = nil end,
           SetPoint = function(self, a, rel, b) self.pts = { a, rel, b } end,
           GetLeft = function() return left end, IsVisible = function() return visible end,
           GetEffectiveScale = function() return 1 end, GetWidth = function() return 420 end }
end
local qf = fr(0, true)
BananaLootlineFrame = fr(600, true)
QI:Place(qf)
check(qf.pts[1] == "TOPRIGHT" and qf.pts[2] == BananaLootlineFrame and qf.pts[3] == "TOPLEFT",
  "links neben dem Hauptfenster")
BananaLootlineFrame = fr(100, true)
QI:Place(qf)
check(qf.pts[1] == "TOPLEFT" and qf.pts[3] == "TOPRIGHT", "rechts, wenn links kein Platz ist")
BananaLootlineFrame = fr(600, false)
QI:Place(qf)
check(qf.pts[1] == "CENTER", "mittig ohne Hauptfenster")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
