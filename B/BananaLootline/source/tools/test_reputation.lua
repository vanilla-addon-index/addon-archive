-- Rufbedingungen aus dem echten Tooltip.
--
-- Beobachtet an "Outrider's Bow" beim Quartiermeister in den Barrens:
-- der Tooltip im Spiel zeigt "Warsong Gulch - Revered", der nachgebaute
-- Scan-Tooltip liefert diese Zeile nicht - in keiner von vier
-- Lesearten. Der Datenbankauszug fuehrt das Feld ebenfalls nicht.
--
-- Der Hook auf den echten Tooltip ist damit die einzige Quelle.
string.gmatch = nil; select = nil

------------------------------------------------------------------
-- Attrappe des echten GameTooltip
------------------------------------------------------------------

local lines = {}
local slots = {}
local function fs(name)
  local o = { text = "" }
  o.SetText = function(self, v) self.text = v or "" end
  o.GetText = function(self) return self.text end
  slots[name] = o
  return o
end
for i = 1, 40 do
  fs("GameTooltipTextLeft" .. i)
  fs("GameTooltipTextRight" .. i)
  fs("BananaLootlineScanTooltipTextLeft" .. i)
  fs("BananaLootlineScanTooltipTextRight" .. i)
end
getglobal = function(n) return slots[n] end

local function setLines(t)
  lines = t
  for i = 1, 40 do
    slots["GameTooltipTextLeft" .. i]:SetText(t[i] or "")
  end
end

GameTooltip = {
  GetName   = function() return "GameTooltip" end,
  IsShown   = function() return true end,
  NumLines  = function() return table.getn(lines) end,
  AddLine   = function() end,
  AddDoubleLine = function() end,
  Show      = function() end,
  SetHyperlink = function() end,
  SetBagItem = function() end,
  SetInventoryItem = function() end,
  SetLootItem = function() end,
  SetMerchantItem = function() end,
  SetQuestItem = function() end,
  SetQuestLogItem = function() end,
  SetCraftItem = function() end,
  SetTradeSkillItem = function() end,
  SetAuctionItem = function() end,
  SetAuctionSellItem = function() end,
}
ItemRefTooltip = nil

-- Der Abgriff laeuft absichtlich einen Frame spaeter, damit fremde
-- Addons ihre Zeilen vorher anhaengen koennen. Der Test haelt den
-- OnUpdate-Handler fest und loest den Tick von Hand aus.
local onUpdate = nil
CreateFrame = function()
  return { SetOwner = function() end, ClearLines = function() end,
           Hide = function() end, SetHyperlink = function() end,
           NumLines = function() return 0 end,
           RegisterEvent = function() end,
           SetScript = function(self, script, fn)
             if script == "OnUpdate" then onUpdate = fn end
           end }
end
local function tick() if onUpdate then onUpdate() end end
WorldFrame, UIParent = {}, {}
GetItemInfo = function() return nil end

BananaLootline = {}
GetLocale = function() return "enUS" end
dofile("Locale.lua")
local BLL = BananaLootline
BLL.Print, BLL.Debug = function() end, function() end
dofile("Scanner.lua")

BananaLootlineDB = { tooltipSources = true, itemcache = {} }

-- pfDB-Attrappe, damit Sources sich fuer verfuegbar haelt
pfDB = { items = { data = { [20437] = { V = { [1] = 0 } } }, loc = {} },
         units = { data = {}, loc = {} },
         quests = { data = {}, loc = {} },
         objects = { data = {}, loc = {} },
         zones = {} }

dofile("Sources.lua")

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

------------------------------------------------------------------
-- 1. Die Erkennung selbst
------------------------------------------------------------------

local S = BLL.Scanner
check(S:IsRestrictionLine("Warsong Gulch - Revered"),
  "Rufbedingung wird erkannt")
check(S:IsRestrictionLine("Requires: Argent Dawn - Honored"),
  "andere Schreibweise wird erkannt")
check(S:IsRestrictionLine("Alterac Valley - Exalted"),
  "Ruf ohne Bedingungswort wird erkannt")

-- Was NICHT anschlagen darf
check(not S:IsRestrictionLine("Requires Level 18"),
  "reine Stufenzeile schlaegt nicht an")
check(not S:IsRestrictionLine("Binds when picked up"),
  "Bindungszeile schlaegt nicht an")
check(not S:IsRestrictionLine("19 - 37 Damage"),
  "Schadenszeile schlaegt nicht an")
check(not S:IsRestrictionLine("(11.7 damage per second)"),
  "DPS-Zeile schlaegt nicht an")
check(not S:IsRestrictionLine("+5 Agility"),
  "Wertzeile schlaegt nicht an")
check(not S:IsRestrictionLine(""), "leere Zeile schlaegt nicht an")
check(not S:IsRestrictionLine(nil), "nil schlaegt nicht an")

------------------------------------------------------------------
-- 2. Der Abgriff aus dem echten Tooltip
--
-- Genau die Zeilenfolge aus dem Spiel.
------------------------------------------------------------------

BananaLootlineDB.itemcache[20437] = {
  n = "Outrider's Bow", q = 3, r = 18, e = "INVTYPE_RANGED",
  st = { WEAPON_DPS = 11.7 },
}

setLines({
  "Outrider's Bow",
  "Warsong Gulch - Revered",
  "Binds when picked up",
  "Ranged",
  "19 - 37 Damage",
  "Speed 2.40",
  "(11.7 damage per second)",
  "Requires Level 18",
})

GameTooltip:SetHyperlink("|Hitem:20437:0:0:0|h[Outrider's Bow]|h")
tick()

local e = BananaLootlineDB.itemcache[20437]
check(e.lock == "Warsong Gulch - Revered",
  "Bedingung aus dem Tooltip uebernommen, war: " .. tostring(e.lock))

------------------------------------------------------------------
-- 3. Ein Gegenstand ohne Bedingung bleibt unberuehrt
------------------------------------------------------------------

BananaLootlineDB.itemcache[2500] = {
  n = "Normaler Bogen", q = 2, r = 16, e = "INVTYPE_RANGED", st = {},
}
setLines({
  "Normaler Bogen",
  "Binds when equipped",
  "Ranged",
  "12 - 22 Damage",
  "Requires Level 16",
})
GameTooltip:SetHyperlink("|Hitem:2500:0:0:0|h[Normaler Bogen]|h")
tick()
check(BananaLootlineDB.itemcache[2500].lock == nil,
  "Gegenstand ohne Bedingung bekommt keine Markierung")

------------------------------------------------------------------
-- 4. Die eigenen Zusatzzeilen werden nicht ausgewertet
------------------------------------------------------------------

BananaLootlineDB.itemcache[3000] = {
  n = "Testteil", q = 2, r = 16, e = "INVTYPE_RANGED", st = {},
}
setLines({
  "Testteil",
  "Binds when equipped",
  "Requires Level 16",
  "|cffffcc33Banana|cffffffffLootline|r",
  "Vendor: Somebody - Revered Lands",   -- steht NACH dem eigenen Block
})
GameTooltip:SetHyperlink("|Hitem:3000:0:0:0|h[Testteil]|h")
tick()
check(BananaLootlineDB.itemcache[3000].lock == nil,
  "eigene Zusatzzeilen loesen keine Markierung aus")

------------------------------------------------------------------
-- 5. Zeigt der Tooltip inzwischen etwas anderes, wird nichts vertauscht
--
-- Die Pruefung laeuft einen Frame spaeter. Faehrt der Zeiger in der
-- Zwischenzeit weiter, darf die Bedingung nicht dem falschen
-- Gegenstand angehaengt werden.
------------------------------------------------------------------

BananaLootlineDB.itemcache[4000] = {
  n = "Erster Gegenstand", q = 2, r = 16, e = "INVTYPE_RANGED", st = {},
}
setLines({ "Erster Gegenstand", "Binds when equipped" })
GameTooltip:SetHyperlink("|Hitem:4000:0:0:0|h[Erster Gegenstand]|h")
-- Vor dem Tick wechselt der Tooltip auf einen anderen Gegenstand
setLines({ "Ganz anderer Gegenstand", "Warsong Gulch - Revered" })
tick()
check(BananaLootlineDB.itemcache[4000].lock == nil,
  "Bedingung landet nicht beim falschen Gegenstand")

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
