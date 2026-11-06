-- Der Wegplan eines Stufe-15-Jaegers, nachgestellt an den echten Daten.
--
-- Anlass ist ein Bildschirmfoto: ganz oben stand "[QUEST] Oestliche
-- Pestlaender" mit "Windreaper Quest 57" und "Archlight Talisman
-- Quest 50". Ein Stufe-15-Charakter kann diese Quests nicht einmal
-- annehmen. Darunter stand "[WORLD] Sumpfland" mit drei Teilen zu je
-- 0,0045 % - einer von 22000.
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
-- Der Charakter im Bildschirmfoto ist Allianz: Westfall und das
-- Verlies stehen in seiner Liste.
UnitFactionGroup = function() return "Alliance" end

BananaLootline = {}
GetLocale = function() return "enUS" end
dofile("Locale.lua")
local BLL = BananaLootline
BLL.Print, BLL.Debug = function() end, function() end
dofile("Scanner.lua")

BananaLootlineDB = { tooltipSources = false, itemcache = {}, minDropChance = 0,
                     planAhead = 6 }

dofile("Data/ItemData.lua")
dofile("Data/SourceData.lua")
dofile("Data/ZoneNames.lua")
dofile("Data/NpcData.lua")

pfDB = nil                   -- allein aus dem Import
dofile("Sources.lua")
local S = BLL.Sources
S:Init()
BLL.Candidates = { PlanAhead = function() return 6 end,
                   MIN_LOOTLINE_CHANCE = 0.1 }
BLL.player = { class = "HUNTER", level = 15 }

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local I = BananaLootlineItemData

------------------------------------------------------------------
-- 1. Quests weit ueber der eigenen Stufe verschwinden
------------------------------------------------------------------

check(I[15853] and I[15853].name == "Windreaper", "Windreaper ist 15853")
check(I[15856] and I[15856].name == "Archlight Talisman", "Talisman ist 15856")

check(S:GetItemSources(15853) == nil,
  "Windreaper aus einer Stufe-57-Quest ist fuer Stufe 15 keine Quelle")
check(S:GetItemSources(15856) == nil,
  "Archlight Talisman aus einer Stufe-50-Quest ebenso wenig")

-- Auf Stufe 55 ist die Stufe-50-Quest erreichbar, die Stufe-57-Quest
-- liegt mit Vorausplanung 6 genau an der Grenze.
BLL.player.level = 55
local w = S:GetItemSources(15856)
check(w and table.getn(w) > 0, "auf Stufe 55 ist die Stufe-50-Quest erreichbar")
BLL.player.level = 15

------------------------------------------------------------------
-- 2. Erreichbare Quests bleiben
--
-- "Tunic of Westfall" kommt aus Quest 166 "The Defias Brotherhood",
-- Mindeststufe 14. Die stand zu Recht in der Liste.
------------------------------------------------------------------

local t = S:GetItemSources(2041)
check(t and table.getn(t) > 0, "Tunic of Westfall bleibt erreichbar")
if t then
  check(t[1].stype == "Q", "und zwar als Questbelohnung")
  check(t[1].questLevel == 14, "mit Mindeststufe 14")
  -- Der Ort ist die Zone der Quest, nicht der Standort ihres Gebers.
  -- Die Kette faengt in Westfall an und endet in den Todesminen - und
  -- dahin muss man fuer das Teil.
  check(t[1].zone == "The Deadmines",
    "mit den Todesminen als Ort, hat " .. tostring(t[1].zone))
end

-- Fraktion: die Zuordnung ist an den Startgebieten geprueft. Im Wald
-- von Elwynn tragen 25 Quests side 1 und keine side 2, in Durotar
-- 30 Quests side 2 und keine side 1. 1 ist Allianz, 2 Horde, 3 beide.
local horde = 0
for _, s2 in pairs(BananaLootlineSourceData) do
  for i = 1, table.getn(s2.q or {}) do
    if s2.q[i].f == 2 then horde = horde + 1 end
  end
end
check(horde > 400, "Hordenquests sind gekennzeichnet, sind " .. horde)

------------------------------------------------------------------
-- 3. Entwicklereintraege sind aus den Daten raus
--
-- An "Windreaper" und "Archlight Talisman" hing "[UNUSED] Henria Derth"
-- als zweite Quelle.
------------------------------------------------------------------

local N = BananaLootlineNpcNames
local unusedRows = 0
for _, s in pairs(BananaLootlineSourceData) do
  for _, key in ipairs({ "d", "v" }) do
    for i = 1, table.getn(s[key] or {}) do
      local nm = N[s[key][i].n] or ""
      if string.find(nm, "%[UNUSED%]") then unusedRows = unusedRows + 1 end
    end
  end
end
check(unusedRows == 0, "keine [UNUSED]-Quelle mehr in den Daten, sind " .. unusedRows)

------------------------------------------------------------------
-- 4. Winzige Dropchancen: sichtbar, aber kein Reiseziel
--
-- "Feet of the Lynx", "Ranger Bow" und "Sentry Cloak" haengen an
-- denselben drei Gegnern mit je 0,0045 %. In der Einzelansicht gehoeren
-- sie hin, im Wegplan nicht.
------------------------------------------------------------------

for _, id in ipairs({ 1121, 3021, 2059 }) do
  local list = S:GetItemSources(id)
  check(list and table.getn(list) > 0,
    (I[id] and I[id].name or id) .. " behaelt seine Quellen in der Einzelansicht")
  if list then
    check((list[1].chance or 0) < BLL.Candidates.MIN_LOOTLINE_CHANCE,
      (I[id] and I[id].name or id) .. " liegt unter der Wegplanschwelle")
  end
end

-- Gegenprobe: "Prison Shank" faellt mit 33 % vom Stockade-Boss und
-- gehoert sehr wohl in den Wegplan.
local ps = S:GetItemSources(2941)
check(ps and ps[1] and (ps[1].chance or 0) >= BLL.Candidates.MIN_LOOTLINE_CHANCE,
  "Prison Shank mit 33 Prozent bleibt ein Ziel")

------------------------------------------------------------------
-- 5. Die Hoehlen des Wehklagens stimmten
------------------------------------------------------------------

local fang
for id, e in pairs(I) do
  if e.name == "Leggings of the Fang" then fang = id end
end
check(fang ~= nil, "Leggings of the Fang sind in den Daten")
if fang then
  local list = S:GetItemSources(fang)
  check(list and list[1] and list[1].zone == "Wailing Caverns",
    "sie fallen in den Hoehlen des Wehklagens")
  check(list and list[1] and (list[1].chance or 0) > 10,
    "mit einer brauchbaren Chance")
end

------------------------------------------------------------------
-- 5b. Frostmane Hollow
--
-- turtlelootline.com setzte fuer denselben Jaeger "Frostmane Hollow"
-- an die Spitze: Belt of Binding und Tribal War Gauntlets zu je 33 %.
-- Beide standen im Addon ohne Ort, weil pfQuest Hailar the Frigid und
-- Battlemaster Ubukaz nicht kennt, und fielen aus dem Wegplan.
------------------------------------------------------------------

for _, id in ipairs({ 116, 150 }) do
  local list = S:GetItemSources(id)
  local nm = I[id] and I[id].name or id
  check(list and list[1], nm .. " hat eine Quelle")
  if list and list[1] then
    check(list[1].zone == "Frostmane Hollow",
      nm .. " faellt in Frostmane Hollow, hat " .. tostring(list[1].zone))
    check((list[1].chance or 0) > 30, nm .. " mit 33 Prozent")
  end
end

------------------------------------------------------------------
-- 6. Seltene Elitegegner sind als solche erkennbar
--
-- "Forest Leather Gloves" und "Forest Leather Bracers" fallen zu je
-- 1,6 % im Steinkrallengebirge - aber von Humar the Pridelord, einem
-- seltenen Elitegegner auf Stufe 23, und zwei weiteren Seltenen. Als
-- blosse Prozentzahl liest sich das wie ein gewoehnlicher Drop.
------------------------------------------------------------------

for _, id in ipairs({ 3058, 3202 }) do
  local list = S:GetItemSources(id)
  check(list and list[1], (I[id] and I[id].name or id) .. " hat eine Quelle")
  if list and list[1] then
    check(list[1].elite ~= nil,
      (I[id] and I[id].name or id) .. " nennt die Elitekennung")
    check(BLL:EliteLabel(list[1].elite) ~= nil,
      "und die laesst sich beschriften: " .. tostring(BLL:EliteLabel(list[1].elite)))
    check((list[1].level or 0) > BLL.player.level,
      "der Gegner steht ueber der eigenen Stufe")
  end
end

check(BLL:EliteLabel(1) == "Elite", "1 heisst Elite")
check(BLL:EliteLabel(2) == "Rare Elite", "2 heisst Selten-Elite")
check(BLL:EliteLabel(3) == "Boss", "3 heisst Boss")
check(BLL:EliteLabel(4) == "Rare", "4 heisst Selten")
check(BLL:EliteLabel(nil) == nil, "ohne Kennung kein Text")

------------------------------------------------------------------
-- 7. Symbole
--
-- GetItemInfo liefert die Textur nur fuer Gegenstaende, die der Client
-- schon einmal gesehen hat. Im Fenster standen deshalb Fragezeichen -
-- ausgerechnet bei den Teilen, die man noch nicht hat.
------------------------------------------------------------------

dofile("ItemDB.lua")
local DB = BLL.ItemDB
DB:Refresh()

check(DB:IconPath(1121) == "Interface\\Icons\\INV_Boots_Wolf",
  "Feet of the Lynx hat ein Symbol, hat " .. tostring(DB:IconPath(1121)))
check(DB:IconPath(647) ~= nil, "Destiny hat ein Symbol")
check(DB:IconPath(99999999) == nil, "unbekannte ID gibt nichts zurueck")

local withIcon, total = 0, 0
for id, e in pairs(I) do
  total = total + 1
  if e.icon then
    withIcon = withIcon + 1
    check(string.find(e.icon, "\\") == nil and string.find(e.icon, "/") == nil,
      "das Symbol ist ein reiner Name ohne Pfad: " .. e.icon)
  end
end
check(withIcon / total > 0.98,
  "ueber 98 Prozent haben ein Symbol, sind "
  .. math.floor(withIcon / total * 100) .. "%")
print("Symbole: " .. withIcon .. " von " .. total)

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
