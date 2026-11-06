--[[
	Tests for the Gear Advisor (GearAdvisor.lua): upgrades found in your bags
	and offered or equipped, the best quest reward marked and picked, and
	upgrades bordered in the bags -- through the real item score.

	Run:  lua5.1 Tools/tests/test_gearadvisor.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
local now = 100
GetTime = function() return now end
local printed = {}
AegisPathfinder = { db = { char = {}, profile = {} } }
function AegisPathfinder:Print(msg) table.insert(printed, msg) end
function AegisPathfinder:Say(msg) self:Print(msg) end   -- Extras.lua's, always on here
function AegisPathfinder.FormatCopper(c) return c .. "c" end

UnitClass = function() return "Warrior", "WARRIOR" end
local level = 30
UnitLevel = function() return level end
GetTalentTabInfo = function(tab) return "Arms", "icon", tab == 1 and 11 or 0 end
GetSpellName = function() return nil end
GetItemQualityColor = function() return 1, 1, 1, "|cff1eff00" end
local fighting = false
UnitAffectingCombat = function() return fighting end

-- Items: id -> { loc, lines }. Only items listed are "cached".
local ITEMS = {}
local function item(id, loc, str, extra)
	local lines = { "Item " .. id, "+" .. str .. " Strength" }
	if extra then table.insert(lines, extra) end
	ITEMS[id] = { loc = loc, lines = lines }
end
GetItemInfo = function(it)
	local _, _, id = string.find(it, "item:(%d+)")
	local def = ITEMS[tonumber(id)]
	if not def then return nil end
	return "Item " .. id, it, 2, 20, "Armor", "Plate", 1, def.loc, "icon"
end
local function link(id) return "|cff1eff00|Hitem:" .. id .. ":0:0:0|h[Item " .. id .. "]|h|r" end

-- What you wear, and your bags.
local worn, bags = {}, { [0] = {}, {}, {}, {}, {} }
GetInventoryItemLink = function(unit, slot) return worn[slot] and link(worn[slot]) end
GetContainerNumSlots = function(bag) return bags[bag] and 16 or 0 end
GetContainerItemLink = function(bag, slot) return bags[bag] and bags[bag][slot] and link(bags[bag][slot]) end
GetContainerItemInfo = function(bag, slot) return "tex" .. tostring(bags[bag][slot]) end
-- Equipping moves the item into the slot and what was there into the bag,
-- as the client does.
local calls, held = {}, nil
PickupContainerItem = function(bag, slot)
	table.insert(calls, "pickup " .. bag .. ":" .. slot)
	held = { bag = bag, slot = slot }
end
EquipCursorItem = function(slot)
	table.insert(calls, "equip " .. slot)
	if held then
		local id = bags[held.bag][held.slot]
		bags[held.bag][held.slot] = worn[slot]
		worn[slot] = id
		held = nil
	end
end
CursorHasItem = function() return false end

dofile("Theme.lua")
dofile("ItemScoreData.lua")
dofile("ItemScore.lua")
dofile("GearData.lua")
dofile("GearAdvisor.lua")
local A, IS, GA = AegisPathfinder, AegisPathfinder.ItemScore, AegisPathfinder.GearAdvisor
function IS:ReadLines(it)
	local _, _, id = string.find(it, "item:(%d+)")
	local out = {}
	for _, l in ipairs(ITEMS[tonumber(id)].lines) do
		if type(l) == "string" then l = { l } end
		table.insert(out, { left = l[1], right = l[2], leftRed = l[3], rightRed = l[4] })
	end
	return out
end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
local function run(f, script)
	local h = f:GetScript(script)
	assert(h, "no " .. script .. " script")
	local old = this
	this = f
	h()
	this = old
end
local function fire(ev, a1)
	local oldE, oldA = event, arg1
	event, arg1 = ev, a1
	run(GA.events, "OnEvent")
	event, arg1 = oldE, oldA
end
local function tick(seconds)
	now = now + (seconds or 1)
	run(GA.events, "OnUpdate")
end

-- Upgrades in your bags ----------------------------------------------------------

item(1, "INVTYPE_HEAD", 10)       -- worn helm
item(2, "INVTYPE_HEAD", 14)       -- better helm
item(3, "INVTYPE_HEAD", 6)        -- worse helm
ITEMS[4] = { loc = "INVTYPE_HEAD", lines = { "Cloth", { "Head", "Cloth", false, true }, "+30 Strength" } }
item(5, "INVTYPE_CHEST", 12)      -- chest, nothing worn there
worn[1] = 1
bags[0][1], bags[0][2], bags[1][3], bags[1][4] = 2, 3, 4, 5

GA:Scan()
local f = GA:Found()
check(f["0:1"] and f["0:1"].compare.slot == 1, "a better helm in your bags is found")
check(not f["0:2"], "a worse one is not")
check(not f["1:3"], "nor one you cannot wear")
check(f["1:4"] and f["1:4"].compare.emptySlot, "something for a slot you have nothing in is")

-- Offered, biggest gain first, once.
GA:Process()
local popup = GA.popup
check(popup and popup:IsShown(), "an upgrade opens the window")
check(popup.rec.bag == 1 and popup.rec.slot == 4, "the biggest gain first (the empty chest slot)")
check(popup.gain:GetText() == "for an empty slot for Arms", "and says what it gains, got %s", popup.gain:GetText())
check(string.find(popup.detail:GetText(), "1 more after this", 1, true), "and that more are waiting")
run(popup.equip, "OnClick")
check(calls[1] == "pickup 1:4" and calls[2] == "equip 5", "Equip puts it on, in its slot: %s, %s",
	tostring(calls[1]), tostring(calls[2]))
check(popup:IsShown() and popup.rec.bag == 0, "then the next one is shown")
check(popup.gain:GetText() == "+40% for Arms", "a helm 14 against 10: +40%%, got %s", popup.gain:GetText())
check(string.find(popup.detail:GetText(), "Replaces Item 1", 1, true), "naming what it replaces")

-- Declining.
run(popup.decline, "OnClick")
check(GA.Settings().declined["item:2:0:0:0"], "Decline remembers the item")
check(not popup:IsShown(), "and with nothing left the window closes")
GA:Process()
check(not popup:IsShown(), "a declined item is not offered again")
GA:ResetSession()
GA:Process()
check(not popup:IsShown(), "not even after a reload")
GA:ClearDeclined()
GA:Process()
check(popup:IsShown() and popup.rec.bag == 0, "until the declined list is cleared")
run(popup.decline, "OnClick")

-- The window waits for a scan after a burst of bag events, and shows an
-- item once a session even if you close it without answering.
calls = {}
item(10, "INVTYPE_SHOULDER", 5)
bags[2][1] = 10
fire("BAG_UPDATE")
tick(0.1)
check(not popup:IsShown(), "a bag event is not scanned at once")
tick(1)
check(popup:IsShown() and popup.rec.item == "item:10:0:0:0", "but a moment later")
popup:Hide()
fire("BAG_UPDATE")
tick(1)
check(not popup:IsShown(), "and an item already offered this session is not offered twice")

-- In combat it waits.
item(6, "INVTYPE_LEGS", 9)
bags[2][2] = 6
fighting = true
GA:Process()
run(popup.equip, "OnClick")
check(table.getn(calls) == 0, "no equipping mid-fight")
check(string.find(printed[table.getn(printed)], "fight is over", 1, true), "it says it will wait")
fighting = false
fire("PLAYER_REGEN_ENABLED")
check(calls[1] == "pickup 2:2" and calls[2] == "equip 7", "and does it when the fight ends")

-- An item that moved is found where it went.
calls = {}
item(7, "INVTYPE_FEET", 5)
bags[3][1] = 7
GA:Scan()
local rec = GA:Found()["3:1"]
bags[3][1], bags[4][9] = nil, 7
GA:Equip(rec)
check(calls[1] == "pickup 4:9", "an upgrade that moved in your bags is equipped from where it is")

-- Equipping for you: never something that would bind.
calls = {}
GA.Settings().autoequip = true
item(8, "INVTYPE_WRIST", 5)
item(9, "INVTYPE_HAND", 5, "Binds when equipped")
bags[4][1], bags[4][2] = 8, 9
GA:Process()
check(calls[1] == "pickup 4:1" and calls[2] == "equip 9", "with equip-for-me on, an upgrade goes on by itself")
check(string.find(printed[table.getn(printed)], "Equipped", 1, true), "and says so")
check(popup:IsShown() and popup.rec.bag == 4 and popup.rec.slot == 2, "one that binds on equip still asks")
run(popup.decline, "OnClick")
GA.Settings().autoequip = false

-- Off at level 60, when asked.
GA.Settings().maxlevel = true
level = 60
check(next(GA:Scan()) == nil, "off at level 60 when you ask it to be")
level = 30
GA.Settings().maxlevel = false
GA.Settings().enabled = false
check(next(GA:Scan()) == nil, "and off when switched off")
GA.Settings().enabled = true

-- Quest rewards -----------------------------------------------------------------------

local choices = {}
GetNumQuestChoices = function() return table.getn(choices) end
GetQuestItemLink = function(kind, i) return choices[i] and link(choices[i].id) end
GetQuestItemInfo = function(kind, i) return "Item", "tex", choices[i].count or 1 end
local taken
GetQuestReward = function(i) taken = i end
QuestFrameRewardPanel = CreateFrame("Frame", "QuestFrameRewardPanel", UIParent)
QuestFrameRewardPanel:Show()
for i = 1, 6 do CreateFrame("Button", "QuestRewardItem" .. i, QuestFrameRewardPanel) end

worn[1], worn[5], worn[7] = 1, 5, 6
item(20, "INVTYPE_HEAD", 11)   -- a small upgrade
item(21, "INVTYPE_HEAD", 16)   -- a bigger one
item(22, "INVTYPE_LEGS", 2)    -- a downgrade
choices = { { id = 21 }, { id = 20 }, { id = 22 } }
local index, why, c = GA:RecommendReward()
check(index == 1 and why == "upgrade", "the biggest upgrade is recommended, got %s %s", tostring(index), tostring(why))

-- No upgrade: the one a vendor pays most for.
AegisPathfinder.GearData.sell[22] = 50
AegisPathfinder.GearData.sell[23] = 80
item(23, "INVTYPE_LEGS", 1)
choices = { { id = 22, count = 1 }, { id = 23, count = 1 } }
index, why, c = GA:RecommendReward()
check(index == 2 and why == "sell" and c == 80, "else the best sell price, got %s %s %s", tostring(index), tostring(why), tostring(c))
choices[1].count = 2
index = GA:RecommendReward()
check(index == 1, "counting how many you get (2 x 50 beats 80)")

-- Items still loading: wait, then decide.
choices = { { id = 20 }, { id = 30 } }
index, why = GA:RecommendReward()
check(index == nil and why == "wait", "an item not loaded yet means wait")
item(30, "INVTYPE_HEAD", 20)
index = GA:RecommendReward()
check(index == 2, "and once it has, the choice is made")

-- Marking it, and taking it.
choices = { { id = 22 }, { id = 21 } }
taken = nil
fire("QUEST_COMPLETE")
check(QuestRewardItem2.__aegisMark and QuestRewardItem2.__aegisMark:IsShown(), "the best reward is marked")
check(QuestRewardItem2.__aegisMark.label:GetText() == "Upgrade +60%", "with why, got %s",
	tostring(QuestRewardItem2.__aegisMark.label:GetText()))
check(not (QuestRewardItem1.__aegisMark and QuestRewardItem1.__aegisMark:IsShown()), "and only it")
check(taken == nil, "it is not taken unless you ask")
GA:MarkReward(true)
check(taken == nil, "not even when the quest turns in by itself, with pick-for-me off")
GA.Settings().questpick = true
GA:MarkReward(true)
check(taken == 2, "with pick-for-me on, it is taken")
fire("QUEST_FINISHED")
check(not QuestRewardItem2.__aegisMark:IsShown(), "the mark goes when the window does")

-- Pick-for-me waits for items to load too.
taken = nil
choices = { { id = 20 }, { id = 31 } }
GA:MarkReward(true)
check(taken == nil, "nothing taken while an item loads")
item(31, "INVTYPE_HEAD", 30)
tick(0.5)
check(taken == 2, "and the best is taken once it has, got %s", tostring(taken))
GA.Settings().questpick = false

-- Your bags ------------------------------------------------------------------------------

local bagFrame = CreateFrame("Frame", "ContainerFrame1", UIParent)
bagFrame:SetID(0)
bagFrame.size = 2
bagFrame:Show()
for j = 1, 2 do
	local b = CreateFrame("Button", "ContainerFrame1Item" .. j, bagFrame)
	b:SetID(j)
end
local painted = 0
ContainerFrame_Update = function() painted = painted + 1 end
GA:Initialize()
bags = { [0] = { 2, 3 }, {}, {}, {}, {} }
worn[1] = 1
GA:Scan()
ContainerFrame_Update(bagFrame)
check(painted == 1, "the bags still paint as they did")
check(ContainerFrame1Item1.__aegisMark and ContainerFrame1Item1.__aegisMark:IsShown(), "an upgrade is bordered")
check(not (ContainerFrame1Item2.__aegisMark and ContainerFrame1Item2.__aegisMark:IsShown()), "a non-upgrade is not")
GA.Settings().bagmark = false
ContainerFrame_Update(bagFrame)
check(not ContainerFrame1Item1.__aegisMark:IsShown(), "switched off, no borders")

-- Upgrades for another spec are named in the chat ------------------------------------------

--[[ An Arms warrior with Protection switched on: a new shield-hand item that
	beats the best Protection has had is named once, in the chat. What was
	in the bags at the first look is not new. ]]
do
	ITEMS[500] = { loc = "INVTYPE_SHIELD", lines = { "Old Shield", "Off Hand", "+4 Stamina", "12 Block" } }
	ITEMS[501] = { loc = "INVTYPE_SHIELD", lines = { "Tower Shield", "Off Hand", "+14 Stamina", "40 Block" } }
	ITEMS[502] = { loc = "INVTYPE_SHIELD", lines = { "Kite Shield", "Off Hand", "+10 Stamina", "30 Block" } }
	for bag = 0, 4 do bags[bag] = {} end
	worn = { [17] = 500 }
	IS:SetSpecActive("Protection", true)
	GA:ResetSession()
	bags[0][1] = 502                        -- already in the bags
	local before = table.getn(printed)
	GA:NotifySpecs()
	check(table.getn(printed) == before, "the first look takes stock without a word")
	bags[0][2] = 501                        -- looted
	GA:NotifySpecs()
	local said = printed[table.getn(printed)] or ""
	check(table.getn(printed) == before + 1 and string.find(said, "Item 501", 1, true)
		and string.find(said, "upgrade for your Protection gear", 1, true), "a new Protection upgrade is named: %s", said)
	GA:NotifySpecs()
	check(table.getn(printed) == before + 1, "once")
	IS.Settings().notify = false
	bags[0][3] = 501
	bags[1][1] = 502
	ITEMS[503] = { loc = "INVTYPE_SHIELD", lines = { "Wall", "Off Hand", "+30 Stamina" } }
	bags[1][2] = 503
	GA:NotifySpecs()
	check(table.getn(printed) == before + 1, "and not at all with the notice off")
	IS.Settings().notify = true
	IS:SetSpecActive("Protection", false)
end

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("GearAdvisor: %d checks", checks))
if table.getn(failures) == 0 then
	print("All gear advisor checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, fl in ipairs(failures) do print("  - " .. fl) end
os.exit(1)
