--[[
	Tests for the options' Automation page: what it does with quests
	(QuestTracker.lua) and at a flight master or a vendor (Automation.lua).

	Each automation has to do what it says when it is on, nothing when it
	is off, and nothing while Shift is held. All quests has to take every
	quest but grey ones, and leave room in the log for the guide's; the
	flight has to be the step's and never a guess; buying has to stop at
	what the step needs and what you can pay for; selling has to take greys
	alone; repairing is your own money or nothing.

	Run:  lua5.1 Tools/tests/test_automation.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

local printed = {}
local steps = {}            -- { action, name, tags }
AegisPathfinder = {
	db = { char = { autoquest = true, allquests = false, autogossip = true, autofly = false, autobuy = true,
		sellbutton = true, autosell = false, autorepair = "off" }, profile = {} },
	current = 1,
}
local A = AegisPathfinder
A.actions = {}
function A:Print(msg) table.insert(printed, msg) end
function A:Say(msg) self:Print(msg) end   -- Extras.lua's, always on here
function A:Debug() end
function A:UpdateStatusFrame() end
function A:GetObjectiveStatus() return false end
function A:GetObjectiveInfo(i)
	local s = steps[i or self.current]
	if s then return s[1], s[2] end
end
function A:GetObjectiveTag(tag, i)
	local s = steps[i or self.current]
	return s and s[3] and s[3][tag]
end
function A:GetLootRequirement(i)
	local l = self:GetObjectiveTag("L", i)
	if not l then return end
	local _, _, id, n = string.find(l, "^(%d+)%s*(%d*)")
	return tonumber(id), tonumber(n) or 1
end
local function step(action, name, tags)
	steps = { { action, name, tags or {} } }
	A.actions = { action }
end
-- GuideEngine.lua's, for these steps.
function A:IsTravelStep(i)
	local s = steps[i or self.current]
	return s ~= nil and s[1] == "RUN"
end
function A:IsWayThere(i)
	return self:IsTravelStep(i) and steps[i or self.current][3].O ~= nil
end
function A:RevealGuideQuests() end
local scans = 0
function A:ScheduleStatusUpdate() scans = scans + 1 end

-- The quest windows and the gossip lists, as the client and ClassicAPI give them.
local shift = false
IsShiftKeyDown = function() return shift end
local level = 20
UnitLevel = function() return level end
local logQuests = 5
GetNumQuestLogEntries = function() return logQuests + 2, logQuests end
local gossip = { available = {}, active = {} }
local picked = {}
C_GossipInfo = {
	GetAvailableQuests = function() return gossip.available end,
	GetActiveQuests = function() return gossip.active end,
	SelectAvailableQuest = function(id) table.insert(picked, "available " .. id) end,
	SelectActiveQuest = function(id) table.insert(picked, "active " .. id) end,
}
local greeting = { available = {}, active = {} }
GetNumAvailableQuests = function() return table.getn(greeting.available) end
GetAvailableTitle = function(i) return greeting.available[i] end
SelectAvailableQuest = function(i) table.insert(picked, "greeting available " .. i) end
GetNumActiveQuests = function() return table.getn(greeting.active) end
GetActiveTitle = function(i) return greeting.active[i] end
SelectActiveQuest = function(i) table.insert(picked, "greeting active " .. i) end
local title, completable, choices = "", false, 0
GetTitleText = function() return title end
local did = {}
AcceptQuest = function() table.insert(did, "accept") end
IsQuestCompletable = function() return completable end
CompleteQuest = function() table.insert(did, "complete") end
GetNumQuestChoices = function() return choices end
GetQuestReward = function(n) table.insert(did, "reward " .. tostring(n)) end
C_QuestLog = { IsOnQuest = function() return false end }
-- No After: Automation's "sold for" line is said at once.
C_Timer = { NewTicker = function() end }
GetMapContinents = function() return "Kalimdor", "Eastern Kingdoms" end
GetMapZones = function(c) if c == 1 then return "Durotar" end return "Elwynn Forest" end

dofile("Locale.lua")
A.Locale = AEGISPATHFINDER_LOCALE        -- as Core.lua hands it on
dofile("Theme.lua")
dofile("QuestTracker.lua")
dofile("Automation.lua")
local Auto = A.Automation

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
local function reset() picked, did, printed = {}, {}, {} end

-- Quests ---------------------------------------------------------------------------

-- The guide's quest, picked from the list and accepted.
step("ACCEPT", "The Fargodeep Mine", { QID = "62" })
gossip.available = { { questID = 40, title = "A Fishy Peril", questLevel = 20 },
	{ questID = 62, title = "The Fargodeep Mine", questLevel = 20 } }
reset(); A:GOSSIP_SHOW()
check(picked[1] == "available 62" and table.getn(picked) == 1, "the guide's quest is picked from the list, got %s",
	tostring(picked[1]))
title = "The Fargodeep Mine"
reset(); A:QUEST_DETAIL()
check(did[1] == "accept", "and accepted")
title = "A Fishy Peril"
reset(); A:QUEST_DETAIL()
check(did[1] == nil, "not another quest, with all quests off")

-- On a travel step (RestedXP's "Travel to Elwynn Forest |O|" before Farmer
-- Furlbrow), talking to Furlbrow means you got there: his quest is the one
-- the windows take.
steps = { { "RUN", "Travel to Elwynn Forest", { O = "" } }, { "ACCEPT", "The Forgotten Heirloom", { QID = "64" } } }
A.actions, A.current = { "RUN", "ACCEPT" }, 1
gossip.available = { { questID = 64, title = "The Forgotten Heirloom", questLevel = 10 } }
reset(); A:GOSSIP_SHOW()
check(picked[1] == "available 64", "past a way there, the next step's quest is picked, got %s", tostring(picked[1]))
title = "The Forgotten Heirloom"
reset(); A:QUEST_DETAIL()
check(did[1] == "accept", "and accepted")
-- Teldrassil (1-12)'s step 87, "Gnarlpine Hold", is a stop, not optional:
-- clicking the Strange Fruited Plant still takes The Glowing Fruit.
steps = { { "RUN", "Gnarlpine Hold", { QID = "930" } }, { "ACCEPT", "The Glowing Fruit", { QID = "930" } } }
title = "The Glowing Fruit"
reset(); A:QUEST_DETAIL()
check(did[1] == "accept", "past a stop as well, the plant's quest is accepted")
-- And the log changing on a travel step rescans: the stop is done once its
-- quest is in the log. Before, nothing looked until something else did.
GetNumQuestLeaderBoards = function() return 0 end
scans = 0
A:QUEST_LOG_UPDATE()
check(scans == 1, "a quest log update on a travel step rescans the guide, got %d", scans)
steps = { { "NOTE", "Read this", {} } }
A.actions = { "NOTE" }
scans = 0
A:QUEST_LOG_UPDATE()
check(scans == 0, "on a note it waits, as before, got %d", scans)
title = "The Fargodeep Mine"
step("ACCEPT", "The Fargodeep Mine", { QID = "62" })
gossip.available = { { questID = 40, title = "A Fishy Peril", questLevel = 20 },
	{ questID = 62, title = "The Fargodeep Mine", questLevel = 20 } }

-- Picking from a list, off: the windows still accept, the list is yours.
A.db.char.autogossip = false
reset(); A:GOSSIP_SHOW()
check(picked[1] == nil, "picking from a list off: nothing picked")
greeting.available = { "The Fargodeep Mine" }
reset(); A:QUEST_GREETING()
check(picked[1] == nil, "on a greeting either")
title = "The Fargodeep Mine"
reset(); A:QUEST_DETAIL()
check(did[1] == "accept", "but the quest you open is still accepted")
A.db.char.autogossip = nil                      -- an older character: on
reset(); A:QUEST_GREETING()
check(picked[1] == "greeting available 1", "a character without the setting picks, got %s", tostring(picked[1]))

-- All quests.
A.db.char.allquests = true
step("RUN", "Goldshire")
gossip.available = { { questID = 7, title = "Grey Old Thing", questLevel = 9 },
	{ questID = 8, title = "Fresh One", questLevel = 19 } }
gossip.active = { { questID = 3, title = "Not Done", isComplete = false }, { questID = 4, title = "Done", isComplete = true } }
reset(); A:GOSSIP_SHOW()
check(picked[1] == "active 4", "all quests: a finished quest to hand in comes first, got %s", tostring(picked[1]))
gossip.active = { { questID = 3, title = "Not Done", isComplete = false } }
reset(); A:GOSSIP_SHOW()
check(picked[1] == "available 8", "then one on offer, not a grey one, got %s", tostring(picked[1]))
gossip.available = { { questID = 7, title = "Grey Old Thing", questLevel = 9 } }
reset(); A:GOSSIP_SHOW()
check(picked[1] == nil, "a grey quest alone: nothing taken")
gossip.available = { { questID = 8, title = "Fresh One", questLevel = 19 } }
logQuests = 18
reset(); A:GOSSIP_SHOW()
check(picked[1] == nil, "a log with two places left: kept for the guide's")
title = "Fresh One"
reset(); A:QUEST_DETAIL()
check(did[1] == nil, "nor accepted from its window")
logQuests = 5
reset(); A:QUEST_DETAIL()
check(did[1] == "accept", "with room, any quest you open is accepted")
completable = true
reset(); A:QUEST_PROGRESS()
check(did[1] == "complete", "and any finished quest handed in")
completable = false
reset(); A:QUEST_PROGRESS()
check(did[1] == nil, "not one that is not finished")
choices = 0
reset(); A:QUEST_COMPLETE()
check(did[1] == "reward 0", "its reward taken when there is no choice")
-- The greeting panel: titles, matched to ClassicAPI's lists for what is done.
greeting.available = { "Grey Old Thing", "Fresh One" }
greeting.active = { "Not Done", "Done" }
gossip.available = { { questID = 7, title = "Grey Old Thing", questLevel = 9 },
	{ questID = 8, title = "Fresh One", questLevel = 19 } }
gossip.active = { { questID = 3, title = "Not Done", isComplete = false }, { questID = 4, title = "Done", isComplete = true } }
reset(); A:QUEST_GREETING()
check(picked[1] == "greeting active 2", "a greeting: the finished one first, got %s", tostring(picked[1]))
greeting.active = { "Not Done" }
reset(); A:QUEST_GREETING()
check(picked[1] == "greeting available 2", "then the one that is not grey, got %s", tostring(picked[1]))
-- Shift, and accepting off, stop all of it.
shift = true
reset(); A:QUEST_GREETING(); A:GOSSIP_SHOW(); A:QUEST_DETAIL()
check(picked[1] == nil and did[1] == nil, "holding Shift: nothing")
shift = false
A.db.char.autoquest = false
reset(); A:GOSSIP_SHOW(); A:QUEST_DETAIL()
check(picked[1] == nil and did[1] == nil, "accepting off: nothing, all quests or not")
A.db.char.autoquest, A.db.char.allquests = true, false
reset(); A:QUEST_GREETING()
check(picked[1] == nil, "all quests off: not a quest the guide does not want")

-- The grey line by level: 20 sees 13 as grey and 14 not, 60 sees 51 as grey
-- and 52 not, and nothing is grey before level 6.
A.db.char.allquests = true
step("RUN", "Goldshire")
greeting.available, greeting.active, gossip.active = {}, {}, {}
for _, case in ipairs({ { 20, 13, false }, { 20, 14, true }, { 45, 35, false }, { 45, 36, true }, { 60, 51, false },
	{ 60, 52, true }, { 4, 1, true } }) do
	level = case[1]
	gossip.available = { { questID = 1, title = "Q", questLevel = case[2] } }
	reset(); A:GOSSIP_SHOW()
	check((picked[1] ~= nil) == case[3], "at %d, a level %d quest is %s", case[1], case[2],
		case[3] and "taken" or "grey")
end
level = 20
A.db.char.allquests = false

-- Travel ---------------------------------------------------------------------------

local nodes = {}
NumTaxiNodes = function() return table.getn(nodes) end
TaxiNodeName = function(i) return nodes[i][1] end
TaxiNodeGetType = function(i) return nodes[i][2] end
local flew
TakeTaxiNode = function(i) flew = i end
local function flight(name) step("FLY", name); flew = nil; printed = {}; return Auto:TakeFlight() end
nodes = { { "Stormwind, Elwynn", "CURRENT" }, { "Ironforge, Dun Morogh", "REACHABLE" },
	{ "Sentinel Hill, Westfall", "REACHABLE" }, { "Lakeshire, Redridge", "REACHABLE" },
	{ "Astranaar, Ashenvale", "REACHABLE" }, { "Forest Song, Ashenvale", "REACHABLE" },
	{ "Menethil Harbor, Wetlands", "NONE" } }
check(flight("Fly to Ironforge") == nil and flew == nil, "flying by itself off: the map is yours")
A.db.char.autofly = true
check(flight("Fly to Ironforge") == "Ironforge, Dun Morogh" and flew == 2, "on: the step's town is flown to")
check(printed[1] == "Flying to Ironforge, Dun Morogh.", "and it says so, got %s", tostring(printed[1]))
check(flight("Fly to Westfall") == "Sentinel Hill, Westfall", "a zone with one flight path: that one")
check(flight("Fly to Redridge Mountains (Part 2)") == "Lakeshire, Redridge", "the map's short zone name, and a part")
check(flight("Fly to Ashenvale") == nil and flew == nil, "a zone with two: never a guess")
check(printed[1] and string.find(printed[1], "pick the one you want", 1, true), "it says to pick, got %s",
	tostring(printed[1]))
check(flight("Fly to Wetlands") == nil, "not a flight path you cannot reach")
check(flight("Fly to Stormwind") == nil, "nor the one you are at")
step("RUN", "Ironforge"); flew = nil; Auto:TakeFlight()
check(flew == nil, "not on a step that does not fly")
shift = true
check(flight("Fly to Ironforge") == nil, "holding Shift: nothing")
shift = false
check(Auto.Match("The Crossroads, The Barrens", Auto.Destination("Fly to Crossroads")) == 2
	and Auto.Match("Crossroads, The Barrens", Auto.Destination("Fly to The Crossroads")) == 2,
	"The Crossroads with or without its The")
A.db.char.autofly = false

-- The vendor -------------------------------------------------------------------------

MerchantFrame = CreateFrame("Frame", "MerchantFrame", UIParent)
MerchantFrame:Show()
local money = 10000
GetMoney = function() return money end
local held = {}
C_Item = { GetItemCount = function(id) return held[id] or 0 end }
local wares = {}
GetMerchantNumItems = function() return table.getn(wares) end
GetMerchantItemLink = function(i) return "|cffffffff|Hitem:" .. wares[i].id .. ":0:0:0|h[" .. wares[i].name .. "]|h|r" end
GetMerchantItemInfo = function(i)
	local w = wares[i]
	return w.name, "icon", w.price, w.per or 1, w.available or -1, 1
end
local bought = {}
BuyMerchantItem = function(i, n) table.insert(bought, { i, n }) end
local bags = {}
GetContainerNumSlots = function(bag) return bags[bag] and table.getn(bags[bag]) or 0 end
GetContainerItemLink = function(bag, slot) return bags[bag] and bags[bag][slot] or nil end
local sold = {}
UseContainerItem = function(bag, slot) table.insert(sold, bag .. ":" .. slot) end
local repairCost, canRepair, repaired = 0, true, false
CanMerchantRepair = function() return canRepair end
GetRepairAllCost = function() return repairCost end
RepairAllItems = function() repaired = true end

-- Buying what the step names.
wares = { { id = 159, name = "Refreshing Spring Water", price = 25 }, { id = 3713, name = "Soothing Spices", price = 50 } }
step("BUY", "Soothing Spices", { L = "3713 3" })
held[3713] = 1
bought, printed = {}, {}
check(Auto:BuyStepItems() == 2 and bought[1][1] == 2 and bought[1][2] == 2, "buys the 2 still needed of the 3")
check(printed[1] == "Bought 2 Soothing Spices for the guide.", "and says so, got %s", tostring(printed[1]))
held[3713] = 3
bought = {}
check(Auto:BuyStepItems() == nil and bought[1] == nil, "none once you have them")
held[3713] = 0
money = 120
bought, printed = {}, {}
check(Auto:BuyStepItems() == 2 and bought[1][2] == 2, "no more than you can pay for")
money = 30
bought, printed = {}, {}
check(Auto:BuyStepItems() == 0 and bought[1] == nil and string.find(printed[1], "Not enough money", 1, true),
	"and none, saying why, when you cannot")
money = 10000
wares[2].available = 1
bought = {}
check(Auto:BuyStepItems() == 1, "no more than the vendor has")
wares[2].available, wares[2].per = nil, 5
bought = {}
check(Auto:BuyStepItems() == 5 and table.getn(bought) == 1 and bought[1][2] == nil,
	"sold five to a bundle: one bundle, bought as the client buys one")
wares[2].per = nil
step("BUY", "Soothing Spices")
bought = {}
check(Auto:BuyStepItems() == nil, "a buy step that names no item: nothing")
step("BUY", "Shiny Thing", { L = "999 1" })
check(Auto:BuyStepItems() == nil, "nor one this vendor does not sell")
step("BUY", "Soothing Spices", { L = "3713 3" })
A.db.char.autobuy = false
check(Auto:BuyStepItems() == nil, "buying off: nothing")
A.db.char.autobuy = true

-- Greys.
bags = { [0] = { "|cff9d9d9d|Hitem:2211:0:0:0|h[Bat Ear]|h|r", "|cffffffff|Hitem:159:0:0:0|h[Water]|h|r" },
	[1] = { "|cff9d9d9d|Hitem:3300:0:0:0|h[Rabbit's Foot]|h|r", nil, "|cff1eff00|Hitem:1:0:0:0|h[Green]|h|r" } }
check(table.getn(Auto.Greys()) == 2, "the greys in the bags, and only the greys")
sold, printed = {}, {}
money = 1000
UseContainerItem = function(bag, slot) table.insert(sold, bag .. ":" .. slot); money = money + 105 end
check(Auto:SellGreys() == 2 and sold[1] == "0:1" and sold[2] == "1:1", "sold, the two greys")
check(printed[1] == "Sold 2 grey items for 2s 10c.", "and it says how many and for how much, got %s", tostring(printed[1]))
MerchantFrame:Hide()
sold = {}
check(Auto:SellGreys() == 0 and sold[1] == nil, "not away from a vendor")
MerchantFrame:Show()

-- The vendor's window opening.
Auto:OnMerchant()
check(Auto.button and Auto.button:IsShown() and Auto.button:GetParent() == MerchantFrame,
	"the Sell greys button, on the vendor window")
check(Auto.button.label:GetText() == "SELL GREYS", "saying what it does")
sold = {}
Auto.button:GetScript("OnClick")()
check(table.getn(sold) == 2, "which sells them")
A.db.char.sellbutton = false
Auto:OnMerchant()
check(not Auto.button:IsShown(), "switched off, no button")
A.db.char.sellbutton = true
sold, bought = {}, {}
Auto:OnMerchant()
check(sold[1] == nil, "greys are not sold by themselves unless asked")
check(bought[1] ~= nil, "but the step's item is bought")
A.db.char.autosell = true
sold = {}
held[3713] = 3
Auto:OnMerchant()
check(table.getn(sold) == 2, "asked, the greys go as the window opens")
A.db.char.autosell = false

-- Repairing.
repairCost, repaired = 5000, false
Auto:OnMerchant()
check(not repaired, "repairing off: nothing")
A.db.char.autorepair = "own"
money = 100000
printed = {}
check(Auto:Repair() == 5000 and repaired, "with your own money: everything")
check(printed[1] == "Repaired for 50s 0c.", "and says for how much, got %s", tostring(printed[1]))
repaired = false
money = 100
printed = {}
check(Auto:Repair() == nil and not repaired and string.find(printed[1], "Not enough money", 1, true),
	"not when you cannot pay, saying so")
money = 100000
canRepair, repaired = false, false
check(Auto:Repair() == nil and not repaired, "nor at a vendor who does not repair")
canRepair, repairCost = true, 0
check(Auto:Repair() == nil, "nor with nothing to repair")
repairCost, repaired = 5000, false
shift = true
sold = {}
A.db.char.autosell = true
Auto:OnMerchant()
check(not repaired and sold[1] == nil and Auto.button:IsShown(), "holding Shift: nothing by itself, the button still there")
shift = false
check(Auto.Money(1234567) == "123g 45s 67c" and Auto.Money(5) == "5c" and Auto.Money(100) == "1s 0c", "money written out")

-- Full bags: what the delete tile offers -------------------------------------------------

UISpecialFrames = {}
local slotsOf = { [0] = 4, [1] = 2, [2] = 2 }
GetContainerNumSlots = function(bag) return slotsOf[bag] or 0 end
local counts = {}
GetContainerItemInfo = function(bag, slot) return "tex" .. bag .. slot, counts[bag .. ":" .. slot] or 1 end
ContainerIDToInventoryID = function(bag) return 19 + bag end
-- Bag 2 is a quiver: its empty slots are no room for anything else.
GetInventoryItemLink = function(_, inv)
	return inv == 21 and "|cffffffff|Hitem:2101:0:0:0|h[Light Quiver]|h|r" or "|cffffffff|Hitem:4500:0:0:0|h[Bag]|h|r"
end
GetItemInfo = function(id)
	if id == 2101 then return "Light Quiver", "item:2101", 1, 1, "Quiver", "Quiver" end
	return "Bag", "item:4500", 1, 1, "Container", "Bag"
end
local GREY_EAR = "|cff9d9d9d|Hitem:2211:0:0:0|h[Bat Ear]|h|r"
local GREY_FOOT = "|cff9d9d9d|Hitem:3300:0:0:0|h[Rabbit's Foot]|h|r"
bags = {
	[0] = { GREY_EAR, "|cffffffff|Hitem:159:0:0:0|h[Water]|h|r", "|cffffffff|Hitem:6948:0:0:0|h[Hearthstone]|h|r",
		"|cffffffff|Hitem:3713:0:0:0|h[Soothing Spices]|h|r" },
	[1] = { "|cffffffff|Hitem:2589:0:0:0|h[Linen Cloth]|h|r", GREY_FOOT },
	[2] = {},
}
A.SELL_PRICES = { [2211] = 4, [3300] = 3, [159] = 1, [3713] = 1, [2589] = 13 }
step("BUY", "Soothing Spices", { L = "3713 3" })
check(Auto.FreeSlots() == 0, "a quiver's empty slots are not room, got %d", Auto.FreeSlots())
local c = Auto:CheapestToDelete()
check(c and c.id == 3300 and c.grey and c.bag == 1 and c.slot == 2, "full: the cheapest grey first, a foot at 3c, got %s",
	tostring(c and c.id))
counts["1:2"] = 2
c = Auto:CheapestToDelete()
check(c and c.id == 2211 and c.value == 4, "by what the whole stack fetches: two feet at 3c lose to an ear at 4c, got %s",
	tostring(c and c.id))
counts["1:2"] = nil
bags[0][1], bags[1][2] = "|cffffffff|Hitem:4604:0:0:0|h[Forest Mushroom]|h|r", "|cffffffff|Hitem:4536:0:0:0|h[Apple]|h|r"
A.SELL_PRICES[4604], A.SELL_PRICES[4536] = 1, 1
c = Auto:CheapestToDelete()
check(c and not c.grey and (c.id == 159 or c.id == 4604 or c.id == 4536), "no greys: the cheapest a vendor buys, got %s",
	tostring(c and c.id))
check(c.id ~= 3713 and c.id ~= 6948, "never the step's item, nor the hearthstone")
A.SELL_PRICES[159], A.SELL_PRICES[4604], A.SELL_PRICES[4536] = nil, nil, nil
c = Auto:CheapestToDelete()
check(c and c.id == 2589, "not what no vendor buys (a quest item, a Turtle item), got %s", tostring(c and c.id))
bags[1][2] = "|cff9d9d9d|Hitem:60001:0:0:0|h[Turtle Junk]|h|r"
c = Auto:CheapestToDelete()
check(c and c.id == 60001 and c.value == nil, "a grey with no price (Turtle's own) is offered, its value unknown")
-- A stack of greys against one cheaper grey (reported: five fangs went
-- before a grey chestpiece worth less than the five). An unknown price no
-- longer counts as nothing, and the server's price is asked first.
do
	local fangs = "|cff9d9d9d|Hitem:60002:0:0:0|h[Worn Fang]|h|r"
	local chest = "|cff9d9d9d|Hitem:60003:0:0:0|h[Tattered Chestpiece]|h|r"
	local before0, before1 = bags[0][1], bags[1][2]
	bags[0][1], bags[1][2] = fangs, chest
	counts["0:1"] = 5
	c = Auto:CheapestToDelete()
	check(c and c.id == 60002 and c.value == nil, "neither priced: one of them, not by a value of 0")
	A.SELL_PRICES[60003] = 40
	c = Auto:CheapestToDelete()
	check(c and c.id == 60003 and c.value == 40, "a priced grey before an unpriced stack, got %s", tostring(c and c.id))
	A.SELL_PRICES[60003] = nil
	local server = { [60002] = 12, [60003] = 40 }
	C_Item = { GetItemSellPriceByID = function(id) return server[id] end }
	c = Auto:CheapestToDelete()
	check(c and c.id == 60003 and c.value == 40, "the server's prices: five fangs at 12c (60c) outweigh the chest at 40c, got %s",
		tostring(c and c.id) .. " " .. tostring(c and c.value))
	server[60002] = 5
	c = Auto:CheapestToDelete()
	check(c and c.id == 60002 and c.value == 25, "and five at 5c (25c) go first, got %s", tostring(c and c.value))
	C_Item = nil
	counts["0:1"] = nil
	bags[0][1], bags[1][2] = before0, before1
end
slotsOf[1] = 3
check(Auto:CheapestToDelete() == nil, "a bag with room: nothing offered")
slotsOf[1] = 2

-- Deleting: a grey at once, anything else after asking.
local cursor, deletedItems = nil, {}
ClearCursor = function() cursor = nil end
PickupContainerItem = function(bag, slot) cursor = bags[bag] and bags[bag][slot] end
CursorHasItem = function() return cursor ~= nil end
DeleteCursorItem = function() table.insert(deletedItems, cursor); cursor = nil end
printed = {}
c = Auto:CheapestToDelete()
check(Auto:DeleteCheapest(c) == true and deletedItems[1] == bags[1][2], "a grey is deleted at once")
check(printed[1] and string.find(printed[1], "to make room", 1, true), "and it says so, got %s", tostring(printed[1]))
bags[1][2] = nil
slotsOf[1] = 1
deletedItems = {}
c = Auto:CheapestToDelete()
check(c and c.id == 2589 and not c.grey, "next, the linen")
check(Auto:DeleteCheapest(c) == false and deletedItems[1] == nil, "not grey: nothing deleted yet")
local dialog = Auto.confirm
check(dialog and dialog:IsShown() and string.find(dialog.text:GetText(), "Linen Cloth", 1, true)
	and string.find(dialog.text:GetText(), "13c", 1, true), "it asks, naming it and what a vendor pays, got %s",
	tostring(dialog and dialog.text:GetText()))
dialog.no:GetScript("OnClick")()
check(not dialog:IsShown() and deletedItems[1] == nil, "Keep it keeps it")
Auto:DeleteCheapest(c)
dialog.yes:GetScript("OnClick")()
check(deletedItems[1] == bags[1][1] and not dialog:IsShown(), "Delete deletes it")
deletedItems = {}
c.link = "|cffffffff|Hitem:1:0:0:0|h[Something Else]|h|r"
printed = {}
check(Auto:DeleteCheapest(c, true) == false and deletedItems[1] == nil, "a slot that holds something else now: nothing deleted")
check(printed[1] == "Your bags changed: nothing was deleted.", "saying so, got %s", tostring(printed[1]))

-- Before the settings exist, the events do nothing.
do
	local saved = A.db
	A.db = nil
	local ok = pcall(function()
		local h = Auto.events:GetScript("OnEvent")
		event = "MERCHANT_SHOW"; h()
		event = "TAXIMAP_OPENED"; h()
	end)
	check(ok, "a vendor before the settings: no error")
	A.db = saved
end

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("Automation: %d checks", checks))
if table.getn(failures) == 0 then
	print("All automation checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
