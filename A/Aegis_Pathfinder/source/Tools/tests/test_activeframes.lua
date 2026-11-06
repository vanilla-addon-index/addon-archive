--[[
	Tests for the Active Items and Active Targets windows.

	The two small windows RestedXP hangs beside its guide: a button per item
	the guide wants used, and a button per NPC or enemy it wants found, which
	targets them and marks them -- a star for a friend, a skull (then a cross)
	for an enemy.

	What matters most is that each window offers the right things: an item
	you do not carry, or one for a quest you have finished, is a dead button;
	a target taken from the wrong quest sends you after the wrong mob.

	Run:  lua5.1 Tools/tests/test_activeframes.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}

local now = 100
GetTime = function() return now end

-- The world: who is near enough to target, and what the target is.
local world = { near = {}, hostile = {} }
local marks, used, tooltip = {}, {}, {}
local target
TargetByName = function(name, exact)
	world.lastExact = exact
	if world.near[name] then target = name end
end
local mouseover
local function who(unit)
	if unit == "target" then return target elseif unit == "mouseover" then return mouseover end
end
UnitExists = function(unit) return who(unit) ~= nil end
UnitName = function(unit) return who(unit) end
UnitCanAttack = function(_, unit) return who(unit) ~= nil and world.hostile[who(unit)] or false end
GetRaidTargetIndex = function(unit) return who(unit) and marks[who(unit)] or nil end
SetRaidTarget = function(unit, index)
	world.setCount = (world.setCount or 0) + 1
	if who(unit) then marks[who(unit)] = index end
end
UseContainerItem = function(bag, slot) table.insert(used, { bag, slot }) end
-- The quest log (ClassicAPI gives its quest ids).
local party = { raid = 0 }
UnitIsPlayer = function(unit) return world.players and world.players[UnitName(unit)] or false end
UnitIsDead = function(unit) return world.dead and world.dead[UnitName(unit)] or false end
GetNumRaidMembers = function() return party.raid end
local questLog = {}
GetNumQuestLogEntries = function() return table.getn(questLog) end
GetQuestLogTitle = function(i)
	local q = questLog[i]
	return q.title, 1, nil, q.header, nil, q.complete and 1 or nil
end
C_QuestLog = { GetQuestIDForLogIndex = function(i) return questLog[i] and questLog[i].id end }

-- The macro book, as 1.12 keeps it: 18 account slots, then 18 character ones.
local book = { account = {}, character = {} }
local macroEdits, picked = 0, nil
local ICONS = { "Interface\\Icons\\INV_Misc_QuestionMark", "Interface\\Icons\\Spell_Holy_Heal",
	"Interface\\Icons\\Ability_Hunter_SniperShot", "Interface\\Icons\\rod" }
GetNumMacroIcons = function() return table.getn(ICONS) end
GetMacroIconInfo = function(i) return ICONS[i] end
GetNumMacros = function() return table.getn(book.account), table.getn(book.character) end
local function macroAt(i)
	if i <= 18 then return book.account[i] end
	return book.character[i - 18]
end
-- A macro written by ClassicAPI's C_Macro keeps its icon by name, and reads
-- back as Interface\Icons\<name>, as the client has it.
GetMacroInfo = function(i)
	local m = macroAt(i)
	if not m then return end
	if m.iconName then
		local _, _, base = string.find(m.iconName, "([^\\]+)$")
		return m.name, "Interface\\Icons\\" .. base, m.body, nil
	end
	return m.name, ICONS[m.icon], m.body, nil
end
CreateMacro = function(name, icon, body, isLocal, perCharacter)
	local list = perCharacter and book.character or book.account
	table.insert(list, { name = name, icon = icon, body = body })
	return (perCharacter and 18 or 0) + table.getn(list)
end
EditMacro = function(i, name, icon, body)
	macroEdits = macroEdits + 1
	local m = macroAt(i)
	if name then m.name = name end
	if icon then m.icon = icon end
	if body then m.body = body end
	return i
end
PickupMacro = function(i) picked = i end

-- A stock action button with AegisItem in its slot.
local repainted
ActionButton_GetPagedID = function(b) return b.slot end
ActionButton_Update = function() repainted = this end
GetActionText = function(slot) return slot == 7 and "AegisItem" or nil end
GameTooltip.SetOwner = function(_, owner) tooltip.owner = owner end
GameTooltip.SetBagItem = function(_, bag, slot) tooltip.bag, tooltip.slot = bag, slot end
GameTooltip.Hide = function() tooltip.owner = nil end

local printed = {}
local turnedIn = {}
AegisPathfinder = {
	actions = {}, quests = {}, tags = {}, turnedin = {},
	current = 1,
	-- The macros have a section of their own below.
	db = { char = { showmacros = false }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print(msg) table.insert(printed, msg) end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder:GetObjectiveInfo(i)
	i = i or self.current
	return self.actions[i], self.quests[i]
end
-- Which quests are in the log, and which of those are complete.
local log = {}
function AegisPathfinder:GetObjectiveStatus(i)
	local qid = tonumber((self:GetObjectiveTag("QID", i)))
	local q = qid and log[qid]
	return self.turnedin[self.quests[i]], q and q.index, q and q.complete
end
function AegisPathfinder:SetTurnedIn() table.insert(turnedIn, self.current) end

dofile("Theme.lua")
dofile("Parser.lua")
local guide = CreateFrame("Frame", "AegisPathfinderObjectives", UIParent)
guide:SetWidth(396); guide:SetHeight(300)
guide:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -180)
AegisPathfinder.objectiveframe = guide
dofile("ActiveFrames.lua")
local Theme = AegisPathfinder.Theme
local MARK = AegisPathfinder.RAID_MARKS

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
local function lastPrint() return printed[table.getn(printed)] or "" end

local items = AegisPathfinder.activeitemsframe
local targets = AegisPathfinder.activetargetsframe

-- The windows ---------------------------------------------------------------------

check(items ~= nil and getglobal("AegisPathfinderActiveItems") == items, "the Active Items window is built")
check(targets ~= nil and getglobal("AegisPathfinderActiveTargets") == targets, "and the Active Targets one")
AegisPathfinder.Theme:SetWindowScale(1.2)
check(math.abs(items:GetScale() - 1.2) < 1e-6 and math.abs(targets:GetScale() - 1.2) < 1e-6,
	"they follow the window scale with the other windows")
AegisPathfinder.Theme:SetWindowScale(1)
check(not items:IsShown() and not targets:IsShown(), "both start hidden")
check(items.label:GetText() == "ACTIVE ITEMS" and targets.label:GetText() == "ACTIVE TARGETS",
	"titled as RestedXP's are, got '%s' and '%s'", items.label:GetText(), targets.label:GetText())
check(not items.header.wordmark:IsShown(), "a title, not the wordmark, on a window this small")
check(AegisPathfinder.activeEvents.__events["BAG_UPDATE"] and AegisPathfinder.activeEvents.__events["PLAYER_TARGET_CHANGED"],
	"they listen for the bags and the target")

-- Active items ---------------------------------------------------------------------

AegisPathfinder.actions = { "USE", "COMPLETE", "COMPLETE", "COMPLETE", "ACCEPT", "COMPLETE" }
AegisPathfinder.quests = { "Use it@1@", "Kill a@2@", "Kill b@3@", "Kill c@4@", "Take d@5@", "Kill e@6@" }
AegisPathfinder.tags = {
	"|QID|10| |U|5001|",
	"|QID|20| |U|5002|",
	"|QID|30| |U|5003|",     -- in the log, but done
	"|QID|40| |U|5004|",     -- not in the log
	"|QID|50| |U|5005|",     -- an item that starts a quest: only while current
	"|QID|60| |U|9999|",     -- in the log, but the item is not in the bags
}
log = { [10] = { index = 1 }, [20] = { index = 2 }, [30] = { index = 3, complete = true },
	[60] = { index = 4 } }
stub.bags = {
	[0] = { [1] = { id = 5001, name = "Rod", count = 1, texture = "rod" },
	        [4] = { id = 5002, name = "Horn", count = 2, texture = "horn" },
	        [5] = { id = 5003, name = "Totem", count = 1, texture = "totem" },
	        [6] = { id = 5004, name = "Flask", count = 1, texture = "flask" },
	        [7] = { id = 5005, name = "Letter", count = 1, texture = "letter" } },
	[1] = { [2] = { id = 5002, name = "Horn", count = 3, texture = "horn" } },
}

local list = AegisPathfinder:GetActiveItems()
local ids = {}
for _, e in ipairs(list) do table.insert(ids, e.id) end
check(table.concat(ids, ",") == "5001,5002",
	"the current step's item, then any active quest's: expected 5001,5002, got %s", table.concat(ids, ","))
check(list[2].count == 5, "stacks across bags add up: 2 + 3, got %s", tostring(list[2].count))
check(list[1].texture == "rod", "the icon is the bag's")

AegisPathfinder.current = 5
ids = {}
for _, e in ipairs(AegisPathfinder:GetActiveItems()) do table.insert(ids, e.id) end
check(ids[1] == 5005, "a quest-starting item shows while its step is current, got %s", tostring(ids[1]))
AegisPathfinder.turnedin["Kill a@2@"] = true
ids = {}
for _, e in ipairs(AegisPathfinder:GetActiveItems()) do table.insert(ids, e.id) end
check(table.concat(ids, ",") == "5005,5001",
	"a finished step's item goes; the active quest's stays: got %s", table.concat(ids, ","))
AegisPathfinder.turnedin = {}
AegisPathfinder.current = 1

-- One button per item, however many steps want it; six at most.
do
	local a, q, tg, l, b = AegisPathfinder.actions, AegisPathfinder.quests, AegisPathfinder.tags, log, stub.bags
	AegisPathfinder.actions, AegisPathfinder.quests, AegisPathfinder.tags = {}, {}, {}
	log, stub.bags = {}, { [2] = {} }
	for i = 1, 9 do
		AegisPathfinder.actions[i] = "COMPLETE"
		AegisPathfinder.quests[i] = "Q" .. i .. "@" .. i .. "@"
		-- Steps 1 and 2 share an item.
		local id = i == 2 and 7001 or 7000 + i
		AegisPathfinder.tags[i] = "|QID|" .. (700 + i) .. "| |U|" .. id .. "|"
		log[700 + i] = { index = i }
		stub.bags[2][i] = { id = 7000 + i, name = "Thing " .. i, count = 1 }
	end
	local got = AegisPathfinder:GetActiveItems()
	check(table.getn(got) == 6, "six items at most, got %d", table.getn(got))
	check(got[1].id == 7001 and got[2].id == 7003, "an item two steps want is one button, got %s then %s",
		tostring(got[1].id), tostring(got[2].id))
	AegisPathfinder.actions, AegisPathfinder.quests, AegisPathfinder.tags, log, stub.bags = a, q, tg, l, b
end

-- The window: one tile each, sized to fit.
AegisPathfinder:PaintActiveFrames()
check(items:IsShown(), "items to use show the window")
local shown = 0
for _, b in ipairs(items.tiles) do if b:IsShown() then shown = shown + 1 end end
check(shown == 2, "one tile per item, got %d", shown)
check(items:GetWidth() >= 6 * 2 + 32 * 2 + 4, "the window is as wide as its tiles, got %s", items:GetWidth())
check(items.tiles[1].icon:GetTexture() == "rod", "each tile shows its item")
check(items.tiles[2].count:GetText() == "5", "a stack shows its count, got '%s'", items.tiles[2].count:GetText())
check(items.tiles[1].count:GetText() == "", "one of something shows no count")
check(items.tiles[1].icon.__texcoord and items.tiles[1].icon.__texcoord[1] > 0,
	"with the game's bevel cropped off the icon")

-- Hanging under the guide until dragged.
local p, rel, rp = items:GetPoint()
check(p == "TOPRIGHT" and rel == guide and rp == "BOTTOMRIGHT", "Items hangs under the guide, got %s %s", tostring(p), tostring(rp))

-- Using one.
this = items.tiles[2]
items.tiles[2]:GetScript("OnClick")()
check(used[1] and used[1][1] == 0 and used[1][2] == 4, "a click uses the item from the bags")
check(table.getn(turnedIn) == 0, "another quest's item does not tick the current step")
this = items.tiles[1]
items.tiles[1]:GetScript("OnClick")()
check(table.getn(turnedIn) == 1, "the current USE step's own item ticks it")
items.tiles[1]:GetScript("OnEnter")()
check(tooltip.owner == items.tiles[1] and tooltip.bag == 0 and tooltip.slot == 1,
	"hovering shows the item's own tooltip")
items.tiles[1]:GetScript("OnLeave")()

-- Gone from the bags between the paint and the click.
stub.bags[0][1] = nil
used = {}
check(AegisPathfinder:UseActiveItem(1) == false and table.getn(used) == 0,
	"an item that has left the bags is not used")
check(string.find(lastPrint(), "no longer in your bags", 1, true) ~= nil, "and says so, got '%s'", lastPrint())
stub.bags[0][1] = { id = 5001, name = "Rod", count = 1, texture = "rod" }

-- Nothing to use hides it; so does the setting.
AegisPathfinder.db.char.showactiveitems = false
AegisPathfinder:PaintActiveFrames()
check(not items:IsShown(), "switched off in the options, it hides")
AegisPathfinder.db.char.showactiveitems = nil
AegisPathfinder:PaintActiveFrames()
check(items:IsShown(), "and is on unless switched off")
local saved = stub.bags
stub.bags = {}
AegisPathfinder:PaintActiveFrames()
check(not items:IsShown(), "with nothing in the bags to use, it hides")
stub.bags = saved
check(AegisPathfinder:UseActiveItem(1) == false, "and the key binding has nothing to use")

-- Active targets --------------------------------------------------------------------

-- pfQuest's shape: quests by id with start/end/obj lists, units by id with a
-- faction string for the friendly ones, items by id with drop chances.
pfDB = {
	quests = { data = {
		[100] = { start = { U = { 1 } }, ["end"] = { U = { 2 } } },
		[200] = { obj = { U = { 10, 11 }, I = { 900 } } },
		[300] = { obj = { I = { 901 } } },
	} },
	units = {
		loc = { [1] = "Marshal Dughan", [2] = "Deputy Willem", [10] = "Kobold Vermin",
			[11] = "Kobold Worker", [12] = "Kobold Laborer", [13] = "Defias Thug",
			[14] = "Kobold Tunneler", [15] = "Murloc Streamrunner" },
		data = { [1] = { fac = "A" }, [2] = { fac = "AH" }, [10] = {}, [11] = {}, [12] = {}, [13] = {},
			[14] = {}, [15] = {} },
	},
	items = { data = {
		[900] = { U = { [12] = 20.5, [11] = 50, [13] = 60 } },
		[901] = { U = { [15] = 30, [14] = 30 } },
	} },
}

local function names(t)
	local out = {}
	for _, e in ipairs(t) do table.insert(out, e.name) end
	return table.concat(out, ", ")
end

AegisPathfinder.actions = { "ACCEPT", "TURNIN", "COMPLETE", "TRAIN", "RUN", "COMPLETE", "ACCEPT" }
AegisPathfinder.quests = { "A@1@", "T@2@", "C@3@", "Learn@4@", "Run@5@", "C2@6@", "Unknown@7@" }
AegisPathfinder.tags = {
	"|QID|100|", "|QID|100|", "|QID|200| |U|5001|",
	"|NPC|Telina Shadehand;Milla Fairancora|", "|N|Go somewhere|", "|QID|300|", "|QID|99999|",
}

local t = AegisPathfinder:GetActiveTargets(1)
check(names(t) == "Marshal Dughan", "an ACCEPT step's target is who gives the quest, got '%s'", names(t))
check(t[1].kind == "npc" and t[1].mark == MARK.STAR, "a friendly NPC, marked with a star")
t = AegisPathfinder:GetActiveTargets(2)
check(names(t) == "Deputy Willem", "a TURNIN step's is who takes it, got '%s'", names(t))

t = AegisPathfinder:GetActiveTargets(3)
check(names(t) == "Kobold Vermin, Kobold Worker, Defias Thug, Kobold Laborer",
	"a COMPLETE step's are what it wants killed, then what drops what it wants, likeliest first, got '%s'", names(t))
check(t[1].context == "kill" and t[1].mark == MARK.SKULL, "an enemy to kill gets a skull")
check(t[2].mark == MARK.SKULL, "every one of them")
check(t[3].context == "loot" and t[3].mark == MARK.CROSS and t[4].mark == MARK.CROSS,
	"one to loot what the quest wants, a cross")

t = AegisPathfinder:GetActiveTargets(6)
check(names(t) == "Kobold Tunneler, Murloc Streamrunner",
	"equal drop chances are in a steady order, got '%s'", names(t))

--[[ Where they live. Crocolisk Hunting, in Loch Modan, wants Crocolisk Meat
	and Skin -- which drop from every crocolisk in the world, likelier from the
	Wetlands' and Stranglethorn's. By drop chance alone the targets were those,
	and never a Loch Crocolisk. Those in the step's zone come first: the |Z|
	tag's, the guide's, then the one you are in; everyone when none is. ]]
do
	pfDB.zones = { loc = { [38] = "Loch Modan", [11] = "Wetlands", [33] = "Stranglethorn Vale" } }
	local loc, data = pfDB.units.loc, pfDB.units.data
	loc[20], data[20] = "Elder Saltwater Crocolisk", { coords = { { 30, 20, 33, 300 } } }
	loc[21], data[21] = "Wetlands Crocolisk", { coords = { { 40, 30, 11, 300 } } }
	loc[22], data[22] = "Saltwater Crocolisk", { coords = { { 31, 22, 33, 300 } } }
	loc[23], data[23] = "Venture Co. Mechanic", { coords = { { 60, 60, 33, 300 } } }
	loc[24], data[24] = "Loch Crocolisk", { coords = { { 54, 38, 38, 300 }, { 50, 40, 38, 300 } } }
	pfDB.items.data[910] = { U = { [20] = 80, [21] = 60, [22] = 50, [24] = 40 } }   -- Crocolisk Meat
	pfDB.items.data[911] = { U = { [23] = 90, [21] = 55, [24] = 35 } }              -- Crocolisk Skin
	pfDB.quests.data[385] = { obj = { I = { 910, 911 } } }
	AegisPathfinder.actions[8], AegisPathfinder.quests[8] = "COMPLETE", "Crocolisk Hunting@8@"
	AegisPathfinder.tags[8] = "|QID|385| |N|Kill Loch Crocolisk in the lake (54, 38)|"
	local oldZone, oldReal = AegisPathfinder.zonename, GetRealZoneText

	AegisPathfinder.zonename = "Loch Modan"
	t = AegisPathfinder:GetActiveTargets(8)
	check(names(t) == "Loch Crocolisk", "in Loch Modan's guide, the Loch Crocolisk, got '%s'", names(t))
	check(t[1] and t[1].mark == MARK.CROSS, "marked to loot")

	AegisPathfinder.tags[8] = "|QID|385| |Z|Wetlands|"
	t = AegisPathfinder:GetActiveTargets(8)
	check(names(t) == "Wetlands Crocolisk", "a step's |Z| tag comes first, got '%s'", names(t))

	AegisPathfinder.tags[8] = "|QID|385|"
	AegisPathfinder.zonename = "Dun Morogh"                   -- none live there
	GetRealZoneText = function() return "Stranglethorn Vale" end
	t = AegisPathfinder:GetActiveTargets(8)
	check(names(t) == "Elder Saltwater Crocolisk, Saltwater Crocolisk, Venture Co. Mechanic",
		"none in the guide's zone: the ones where you are, got '%s'", names(t))

	GetRealZoneText = function() return "Elwynn Forest" end
	t = AegisPathfinder:GetActiveTargets(8)
	check(names(t) == "Elder Saltwater Crocolisk, Wetlands Crocolisk, Saltwater Crocolisk, Loch Crocolisk",
		"none nearby at all: everyone, likeliest first, got '%s'", names(t))

	AegisPathfinder.actions[8], AegisPathfinder.quests[8], AegisPathfinder.tags[8] = nil, nil, nil
	AegisPathfinder.zonename, GetRealZoneText = oldZone, oldReal
	pfDB.zones = nil
end

t = AegisPathfinder:GetActiveTargets(4)
check(names(t) == "Telina Shadehand, Milla Fairancora", "a profession step's |NPC| names, got '%s'", names(t))
check(t[1].mark == MARK.STAR and t[2].mark == MARK.STAR, "trainers are friends")
check(table.getn(AegisPathfinder:GetActiveTargets(5)) == 0, "a travel step has nobody to target")
check(table.getn(AegisPathfinder:GetActiveTargets(7)) == 0, "nor does a quest pfQuest does not know")

-- Four at most.
pfDB.quests.data[200].obj.U = { 10, 11, 12, 13, 14, 15 }
check(table.getn(AegisPathfinder:GetActiveTargets(3)) == 4, "four targets at most")
pfDB.quests.data[200].obj.U = { 10, 11 }

-- Without pfQuest, only a step that names its NPCs has targets.
local pf = pfDB
pfDB = nil
check(table.getn(AegisPathfinder:GetActiveTargets(1)) == 0, "no pfQuest, no quest giver")
check(table.getn(AegisPathfinder:GetActiveTargets(4)) == 2, "but |NPC| steps still work")
pfDB = pf

-- A Horde character sees Alliance NPCs as enemies.
UnitFactionGroup = function() return "Horde" end
check(AegisPathfinder:GetActiveTargets(1)[1].kind == "enemy", "faction decides who is a friend")
check(AegisPathfinder:GetActiveTargets(2)[1].kind == "npc", "an NPC friendly to both is a friend to both")
UnitFactionGroup = function() return "Alliance" end

-- Targeting and marking --------------------------------------------------------------

AegisPathfinder.current = 3
AegisPathfinder:PaintActiveFrames()
check(targets:IsShown(), "targets show the window")
local tp, trel, trp = targets:GetPoint()
check(tp == "TOPRIGHT" and trel == items and trp == "BOTTOMRIGHT",
	"Targets hangs under Items, got %s %s", tostring(tp), tostring(trp))

local tile = targets.tiles[1]
check(tile.icon:GetTexture() == Theme.actionIcon.K, "an enemy tile shows the kill glyph")
check(tile.mark:IsShown(), "and the mark it will get in its corner")
local tc = tile.mark.__texcoord
check(tc and tc[1] == 0.75 and tc[3] == 0.25, "a skull is the sheet's eighth icon, got %s,%s",
	tostring(tc and tc[1]), tostring(tc and tc[3]))

world.near["Kobold Vermin"], world.hostile["Kobold Vermin"] = true, true
this = tile
tile:GetScript("OnClick")()
check(target == "Kobold Vermin" and world.lastExact == true, "a click targets by exact name")
check(marks["Kobold Vermin"] == MARK.SKULL, "and marks an enemy with a skull")
local sets = world.setCount
tile:GetScript("OnClick")()
check(world.setCount == sets, "an existing mark is left alone rather than toggled off")

-- Relit on the target changing.
event = "PLAYER_TARGET_CHANGED"
this = AegisPathfinder.activeEvents
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(tile.border.tl.__color[1] == Theme.color.accent[1], "the targeted one's tile lights up")
check(targets.tiles[2].border.tl.__color[1] == Theme.color.subtle[1], "and only that one")

-- Out of range.
this = targets.tiles[2]
targets.tiles[2]:GetScript("OnClick")()
check(target == "Kobold Vermin", "someone out of range is not targeted")
check(string.find(lastPrint(), "Kobold Worker isn't close enough", 1, true) ~= nil,
	"and it says so, got '%s'", lastPrint())

-- Someone to talk to gets a star.
AegisPathfinder.current = 1
AegisPathfinder:PaintActiveFrames()
world.near["Marshal Dughan"] = true
marks = {}
AegisPathfinder:TargetActive(AegisPathfinder:GetActiveTargets(1)[1])
check(marks["Marshal Dughan"] == MARK.STAR, "a quest giver gets a star")

-- The client knows better than the database: someone "to kill" who cannot
-- be attacked is someone to interact with.
world.near["Kobold Vermin"], world.hostile["Kobold Vermin"] = true, nil
marks = {}
AegisPathfinder:TargetActive(AegisPathfinder:GetActiveTargets(3)[1])
check(marks["Kobold Vermin"] == MARK.SQUARE, "an unattackable kill target gets a square, got %s",
	tostring(marks["Kobold Vermin"]))
world.hostile["Kobold Vermin"] = true
check(targets.tiles[1].icon:GetTexture() == Theme.actionIcon.A, "a quest giver's tile is the accept glyph")

-- /apg target: the next one after whoever is targeted, round and round.
AegisPathfinder.current = 3
AegisPathfinder:PaintActiveFrames()
world.near = { ["Kobold Vermin"] = true, ["Kobold Laborer"] = true, ["Defias Thug"] = true }
world.hostile = { ["Kobold Vermin"] = true, ["Kobold Laborer"] = true, ["Defias Thug"] = true }
target = "Kobold Vermin"
AegisPathfinder:TargetNextActive()
check(target == "Defias Thug", "it moves on to the next one in range, got %s", tostring(target))
AegisPathfinder:TargetNextActive()
check(target == "Kobold Laborer", "and the next, got %s", tostring(target))
AegisPathfinder:TargetNextActive()
check(target == "Kobold Vermin", "and back round, got %s", tostring(target))
check(marks["Kobold Laborer"] == MARK.CROSS, "a drop source gets a cross")
world.near = {}
target = nil
local before = table.getn(printed)
check(AegisPathfinder:TargetNextActive() == false, "nobody in range is a no")
check(table.getn(printed) == before + 1, "said once, not once per target")
AegisPathfinder.current = 5
AegisPathfinder:PaintActiveFrames()
check(not targets:IsShown(), "a step with nobody to find hides the window")
check(AegisPathfinder:TargetNextActive() == false, "and /apg target has nobody to target")

-- Targets moves up under the guide while Items is empty.
stub.bags = {}
AegisPathfinder.current = 3
AegisPathfinder:PaintActiveFrames()
tp, trel = targets:GetPoint()
check(not items:IsShown() and trel == guide, "with no items, Targets takes Items' place under the guide")
stub.bags = saved

-- Where they go ---------------------------------------------------------------------

-- Dragged, a window stays where it was put.
local header = items.header
this = header
header:GetScript("OnDragStart")()
check(items.moving, "a drag is under way")
-- The client moves it with the cursor, by an anchor of its own choosing.
items:ClearAllPoints()
items:SetPoint("CENTER", UIParent, "CENTER", 10, 10)
AegisPathfinder:PaintActiveFrames()
local dragPoint = items:GetPoint()
check(dragPoint == "CENTER", "a repaint mid-drag does not snap it back under the guide, got %s", tostring(dragPoint))
header:GetScript("OnDragStop")()
check(not items.moving, "and then it is not")
check(AegisPathfinder.db.profile.activeitemspoint == "TOPLEFT", "the drop is saved, got %s",
	tostring(AegisPathfinder.db.profile.activeitemspoint))
AegisPathfinder:PaintActiveFrames()
p, rel = items:GetPoint()
check(p == "TOPLEFT" and rel == UIParent, "and kept on the next paint, got %s", tostring(p))

AegisPathfinder:ResetActiveFrames()
p, rel = items:GetPoint()
check(rel == guide and AegisPathfinder.db.profile.activeitemspoint == nil,
	"Reset Panels puts it back under the guide")

-- Keeping up --------------------------------------------------------------------------

local driver = AegisPathfinder.activeDriver
local function tick()
	this = driver
	if driver:IsShown() then driver:GetScript("OnUpdate")() end
end
stub.bags = {}
AegisPathfinder:PaintActiveFrames()
check(not items:IsShown(), "empty to start")
stub.bags = saved
AegisPathfinder:RefreshActiveFrames()
tick()
check(items:IsShown(), "a step change repaints on the next frame")

-- Bag updates in a burst are one repaint, a moment later.
stub.bags = {}
event = "BAG_UPDATE"
this = AegisPathfinder.activeEvents
for _ = 1, 5 do AegisPathfinder.activeEvents:GetScript("OnEvent")() end
tick()
check(items:IsShown(), "not straight away")
now = now + 1
tick()
check(not items:IsShown(), "but once the burst has passed")
check(not driver:IsShown(), "and then it rests")
stub.bags = saved

-- Quest icons -----------------------------------------------------------------------------

-- A friendly NPC among a quest's objectives is someone to interact with.
pfDB.quests.data[400] = { obj = { U = { 1 } } }
AegisPathfinder.actions[8], AegisPathfinder.quests[8], AegisPathfinder.tags[8] = "COMPLETE", "Speak@8@", "|QID|400|"
local talk = AegisPathfinder:GetActiveTargets(8)[1]
check(talk and talk.context == "interact" and talk.mark == MARK.SQUARE,
	"a friend the objectives involve is marked square to interact, got %s", tostring(talk and talk.context))

-- The mark goes on by itself on mouseover, for the step's targets...
AegisPathfinder.current = 3
AegisPathfinder:PaintActiveFrames()
marks = {}
world.hostile = { ["Kobold Vermin"] = true, ["Defias Thug"] = true, ["Murloc Streamrunner"] = true }
mouseover = "Kobold Vermin"
event = "UPDATE_MOUSEOVER_UNIT"
this = AegisPathfinder.activeEvents
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == MARK.SKULL, "mousing over a kill target puts a skull on it")
mouseover = "Defias Thug"
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Defias Thug"] == MARK.CROSS, "and a cross on a drop source")
mouseover = "Stonetusk Boar"
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Stonetusk Boar"] == nil, "nobody a quest wants is left alone")

-- ...and on targeting.
target = "Kobold Worker"
world.hostile["Kobold Worker"] = true
event = "PLAYER_TARGET_CHANGED"
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Worker"] == MARK.SKULL, "targeting one marks it too")

-- Never over someone else's mark, a player, the dead, or in a raid.
marks = { ["Kobold Vermin"] = 5 }
mouseover = "Kobold Vermin"
event = "UPDATE_MOUSEOVER_UNIT"
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == 5, "an existing mark stays -- a party member's, say")
marks = {}
world.players = { ["Kobold Vermin"] = true }
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == nil, "a player who shares the name is not marked")
world.players, world.dead = nil, { ["Kobold Vermin"] = true }
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == nil, "nor a corpse")
world.dead, party.raid = nil, 10
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == nil, "nor anyone in a raid, where marks are the leaders'")
party.raid = 0
AegisPathfinder.db.char.questicons = false
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == nil, "and nothing at all with quest icons switched off")
AegisPathfinder.db.char.questicons = nil
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == MARK.SKULL, "on by default")

-- Only while a guide is open: not with its window closed, nor with no guide
-- at all. Hidden for combat or an instance, it is still open.
marks = {}
guide:Hide()
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == nil, "nobody is marked with the guide closed")
AegisPathfinder.hiddenForCombat = true
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == MARK.SKULL, "a guide hidden for combat still counts as open")
AegisPathfinder.hiddenForCombat, marks = nil, {}
AegisPathfinder.hiddenForInstance = true
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == MARK.SKULL, "and one hidden in a dungeon")
AegisPathfinder.hiddenForInstance, marks = nil, {}
guide:Show()
AegisPathfinder.HasNoGuide = function() return true end
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == nil, "nobody is marked with no guide loaded")
AegisPathfinder.HasNoGuide = nil
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == MARK.SKULL, "and with a guide open again, they are")

-- Every quest in the log, not just the step's: its objectives while it is
-- under way, whoever takes it once it is complete.
questLog = {
	-- A header is not a quest, whatever id the client hands back for it.
	{ title = "Elwynn Forest", header = true, id = 200 },
	{ title = "The Fargodeep Mine", id = 300 },
	{ title = "A Threat Within", id = 100, complete = true },
}
AegisPathfinder.current = 5           -- a travel step, with no targets of its own
AegisPathfinder:PaintActiveFrames()
marks = {}
mouseover = "Murloc Streamrunner"
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Murloc Streamrunner"] == MARK.CROSS, "a quest in the log marks what drops its items")
mouseover = "Deputy Willem"
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Deputy Willem"] == MARK.STAR, "a complete one marks who takes it")
mouseover = "Marshal Dughan"
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Marshal Dughan"] == nil, "not who gave it -- that is done")
mouseover = "Kobold Vermin"
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == nil, "and a zone header in the log is not read as a quest")

-- The Targets window switched off, the step's targets still drive the
-- quest icons and /apg target.
questLog = {}
AegisPathfinder.db.char.showactivetargets = false
AegisPathfinder.current = 3
AegisPathfinder:PaintActiveFrames()
check(not targets:IsShown(), "the window stays hidden")
marks = {}
mouseover = "Kobold Vermin"
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Kobold Vermin"] == MARK.SKULL, "but the quest icons still know the step's targets")
world.near = { ["Kobold Vermin"] = true }
target = nil
check(AegisPathfinder:TargetNextActive() and target == "Kobold Vermin", "and so does /apg target")
AegisPathfinder.db.char.showactivetargets = nil
world.near, target = {}, nil

-- Without ClassicAPI's quest ids, the step alone.
local api = C_QuestLog
C_QuestLog = nil
questLog = { { title = "The Fargodeep Mine", id = 300 } }
AegisPathfinder.current = 5
AegisPathfinder:PaintActiveFrames()
marks = {}
mouseover = "Murloc Streamrunner"
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(marks["Murloc Streamrunner"] == nil, "no quest ids, no quest-log marks")
C_QuestLog = api
questLog, mouseover = {}, nil
AegisPathfinder.actions[8], AegisPathfinder.quests[8], AegisPathfinder.tags[8] = nil, nil, nil

-- Macros ---------------------------------------------------------------------------------

local mw = AegisPathfinder.macrosframe
check(mw ~= nil and getglobal("AegisPathfinderMacros") == mw, "the Macros window is built")
check(mw.label:GetText() == "MACROS", "and titled, got '%s'", mw.label:GetText())
check(table.getn(book.character) == 0 and not mw:IsShown(),
	"switched off, it makes no macros and shows nothing")

local function macro(name)
	for _, m in ipairs(book.character) do if m.name == name then return m end end
	for _, m in ipairs(book.account) do if m.name == name then return m end end
end

AegisPathfinder.db.char.showmacros = nil
AegisPathfinder.current = 3            -- four enemies to find, and the rod to use
printed = {}
AegisPathfinder:PaintActiveFrames()
local tm, im = macro("AegisTarget"), macro("AegisItem")
check(tm and im, "on, it makes AegisTarget and AegisItem")
check(table.getn(book.character) == 2 and table.getn(book.account) == 0, "as character macros")
check(string.find(printed[1] or "", "Made the character macros AegisTarget and AegisItem", 1, true) ~= nil,
	"and says where to find them, got '%s'", tostring(printed[1]))
check(tm.body == "/apg target",
	"AegisTarget is /apg target, which looks round for the step's targets on each press; got\n%s", tm.body)
check(tm.icon == 3, "with a targeting icon from the macro icon list, got %s", tostring(tm.icon))
check(im.body == "/apg useitem", "AegisItem uses the first active item, got '%s'", im.body)
check(im.icon == 4, "wearing that item's icon when the list has it, got %s", tostring(im.icon))

check(mw:IsShown(), "the window shows")
check(mw.targetTile:IsShown() and mw.itemTile:IsShown(), "with a tile for each")
local mp, mrel = mw:GetPoint()
check(mrel == targets, "hanging under Active Targets")
check(mw.targetTile.icon:GetTexture() == ICONS[3], "the targeting tile wears the macro's own icon")
check(mw.itemTile.icon:GetTexture() == "rod", "the item tile the item's")

-- Dragging a tile picks its macro up, to drop on an action bar.
this = mw.targetTile
mw.targetTile:GetScript("OnDragStart")()
check(picked == 19, "dragging the target tile picks up AegisTarget, got %s", tostring(picked))
this = mw.itemTile
mw.itemTile:GetScript("OnDragStart")()
check(picked == 20, "and the item tile AegisItem, got %s", tostring(picked))

-- Clicking does what the macro does: without ClassicAPI's TargetNearest, the
-- first of the step's targets in range by name.
world.near = { ["Kobold Worker"] = true, ["Kobold Laborer"] = true }
world.hostile = { ["Kobold Worker"] = true, ["Kobold Laborer"] = true }
target, marks = nil, {}
this = mw.targetTile
mw.targetTile:GetScript("OnClick")()
check(target == "Kobold Worker", "the click targets the first one in range, got %s", tostring(target))
check(marks["Kobold Worker"] == MARK.SKULL, "and marks it")
used = {}
this = mw.itemTile
mw.itemTile:GetScript("OnClick")()
check(used[1] ~= nil, "the item tile uses the item")

-- A macro saved as /target lines ends by marking whoever they found.
target, marks = "Kobold Laborer", {}
check(AegisPathfinder:MarkTarget() and marks["Kobold Laborer"] == MARK.CROSS, "MarkTarget marks one of the step's")
target = "Stonetusk Boar"
check(not AegisPathfinder:MarkTarget() and marks["Stonetusk Boar"] == nil, "and nobody else")
target = nil

-- Unchanged, nothing is rewritten; a new step keeps AegisTarget's text.
local edits = macroEdits
AegisPathfinder:PaintActiveFrames()
check(macroEdits == edits, "a repaint that changes nothing edits nothing")
AegisPathfinder.current = 1
AegisPathfinder:PaintActiveFrames()
check(macro("AegisTarget").body == "/apg target",
	"a new step, the same text: the targets are looked up as it is pressed, got\n%s", macro("AegisTarget").body)
check(table.getn(book.character) == 2, "rewritten in place, not made again")

-- The item's icon changing repaints the stock action button holding it.
local button = CreateFrame("Button", "ActionButton3", UIParent)
button.slot = 7
AegisPathfinder.current = 3
AegisPathfinder:PaintActiveFrames()
check(macro("AegisItem").icon == 4, "back on the rod's step")
repainted = nil
stub.bags[0][1].texture = "horn"      -- not in the macro icon list
AegisPathfinder:PaintActiveFrames()
check(macro("AegisItem").icon == 1, "an icon the list lacks is the question mark")
check(repainted == button, "and the bar button holding AegisItem repaints at once")
stub.bags[0][1].texture = "rod"

-- Nobody to find: the target tile goes, and the macro says so when pressed.
AegisPathfinder.current = 5
AegisPathfinder:PaintActiveFrames()
check(macro("AegisTarget").body == "/apg target", "with no targets AegisTarget still asks, got '%s'", macro("AegisTarget").body)
check(not mw.targetTile:IsShown(), "and its tile goes")

-- Nothing to do and no macros yet: none are made just to sit there.
local keep = book
book = { account = {}, character = {} }
stub.bags = {}
AegisPathfinder:PaintActiveFrames()
check(table.getn(book.character) == 0 and not AegisPathfinder.macroFull,
	"a step with nothing to do makes no macros")
stub.bags = saved
book = keep

-- Never rewritten under the open macro window.
MacroFrame = CreateFrame("Frame", "MacroFrame", UIParent)
AegisPathfinder.current = 3
edits = macroEdits
AegisPathfinder:PaintActiveFrames()
check(macroEdits == edits, "the macro window open, the macros wait")
check(AegisPathfinder.activeDriver:IsShown(), "and try again in a moment")
MacroFrame:Hide()
now = now + 2
this = AegisPathfinder.activeDriver
AegisPathfinder.activeDriver:GetScript("OnUpdate")()
check(macroEdits > edits and macro("AegisItem").icon == 4,
	"once it closes they catch up")

-- A macro of that name already in the account's book is the one used.
book = { account = { { name = "AegisTarget", icon = 1, body = "/say hi" } }, character = {} }
AegisPathfinder:PaintActiveFrames()
check(table.getn(book.account) == 1 and table.getn(book.character) == 1,
	"an existing AegisTarget is rewritten, not doubled")
check(book.account[1].body == "/apg target", "with its own text, got '%s'", book.account[1].body)

-- No free character slot: nothing is made, and the window says why.
book = { account = {}, character = {} }
for k = 1, 18 do table.insert(book.character, { name = "Mine" .. k, icon = 1, body = "/say " .. k }) end
AegisPathfinder:PaintActiveFrames()
check(table.getn(book.character) == 18 and AegisPathfinder.macroFull, "no free slot, no macro")
this = mw.targetTile
mw.targetTile:GetScript("OnEnter")()
local tipText = {}
for _, fs in ipairs(Theme.tip.lines) do if fs:IsShown() then table.insert(tipText, fs:GetText()) end end
check(string.find(table.concat(tipText, " "), "No free character macro slot", 1, true) ~= nil,
	"and its tooltip says so, got '%s'", table.concat(tipText, " "))
mw.targetTile:GetScript("OnLeave")()
picked = nil
mw.targetTile:GetScript("OnDragStart")()
check(picked == nil and string.find(lastPrint(), "no free character macro slot", 1, true),
	"dragging it explains instead, got '%s'", lastPrint())
book = { account = {}, character = {} }

--[[ The macro icon list is the client's, filled lazily: until something asks
	for it, it is empty. Read then, and kept, it left AegisTarget with the
	first place of an empty list -- no icon at all, a blank tile. Now the list
	is read again until it has something in it, and the icon follows. ]]
local fullList = ICONS
ICONS = {}
AegisPathfinder.current = 3
AegisPathfinder:PaintActiveFrames()
check(macro("AegisTarget") and macro("AegisTarget").icon == 1, "made while the icon list is empty: its first place")
edits = macroEdits
AegisPathfinder:PaintActiveFrames()
check(macroEdits == edits, "and not rewritten over and over while the list stays empty")
ICONS = fullList
AegisPathfinder:PaintActiveFrames()
check(macro("AegisTarget").icon == 3, "once the list is there, the targeting icon, got %s",
	tostring(macro("AegisTarget").icon))
book = { account = {}, character = {} }

--[[ With ClassicAPI's C_Macro the icon is written by name: no list is
	involved, and an item gets its own icon, which the list does not have. ]]
C_Macro = {
	CreateMacro = function(name, icon, body, isCharacter)
		local list = isCharacter and book.character or book.account
		table.insert(list, { name = name, iconName = icon, body = body })
		return (isCharacter and 18 or 0) + table.getn(list)
	end,
	EditMacro = function(i, name, icon, body)
		macroEdits = macroEdits + 1
		local m = macroAt(i)
		if name then m.name = name end
		if icon then m.iconName, m.icon = icon, nil end
		if body then m.body = body end
		return i
	end,
}
ICONS = {}                                   -- the list not read yet: no matter now
AegisPathfinder.current = 3
AegisPathfinder:PaintActiveFrames()
tm, im = macro("AegisTarget"), macro("AegisItem")
check(tm and tm.iconName == "Ability_Hunter_SniperShot" and table.getn(book.character) == 2,
	"C_Macro: AegisTarget, a character macro, with the targeting icon by name, got %s", tostring(tm and tm.iconName))
check(im and im.iconName == "rod", "AegisItem with its item's own icon, got %s", tostring(im and im.iconName))
check(mw.targetTile.icon:GetTexture() == "Interface\\Icons\\Ability_Hunter_SniperShot",
	"and the tile shows it, got %s", tostring(mw.targetTile.icon:GetTexture()))
edits = macroEdits
AegisPathfinder:PaintActiveFrames()
check(macroEdits == edits, "a repaint that changes nothing edits nothing")
stub.bags[0][1].texture = "Interface\\Icons\\INV_Misc_Horn_01"   -- an item icon the list never has
AegisPathfinder:PaintActiveFrames()
check(macro("AegisItem").iconName == "Interface\\Icons\\INV_Misc_Horn_01", "an item icon too, got %s",
	tostring(macro("AegisItem").iconName))
stub.bags[0][1].texture = "rod"
-- One already made blank, as in game, gets its icon.
book = { account = {}, character = { { name = "AegisTarget", icon = 99, body = "/apg target" } } }
AegisPathfinder:PaintActiveFrames()
check(macro("AegisTarget").iconName == "Ability_Hunter_SniperShot", "a blank AegisTarget gets its icon")
C_Macro, ICONS = nil, fullList
book = { account = {}, character = {} }

-- Nothing to do: no window.
stub.bags = {}
AegisPathfinder.current = 5
AegisPathfinder:PaintActiveFrames()
check(not mw:IsShown(), "with nothing to target or use, it hides")
stub.bags = saved
AegisPathfinder.current = 1

-- Commands and key bindings -----------------------------------------------------------

check(BINDING_HEADER_AEGISPATHFINDER ~= nil, "the key bindings have a header")
local xml = io.open("Bindings.xml"):read("*a")
local bound = 0
for name, body in string.gfind(xml, '<Binding name="([^"]+)"[^>]*>(.-)</Binding>') do
	bound = bound + 1
	check(_G["BINDING_NAME_" .. name] ~= nil, "binding %s has a label", name)
	local _, _, fn = string.find(body, "AegisPathfinder:(%w+)%(")
	check(fn and type(AegisPathfinder[fn]) == "function", "binding %s calls a real function (%s)", name, tostring(fn))
end
check(bound == 2, "two bindings: use the item, target the target -- got %d", bound)

-- Each press, the next one around you ------------------------------------------------------

--[[ /target took the nearest with the name, but stayed on whoever was
	targeted when they had it already: pressing AegisTarget again never moved
	on from the one Crocolisk. With ClassicAPI's TargetNearest, UnitGUID and
	TargetUnit, a press looks round and takes the next of the step's targets
	out from the one targeted, and round again.

	TargetNearest here is ClassicAPI's: each call the next unit out, nearest
	first, round and round; a target set some other way starts it again from
	the nearest. And like the client, a change of target is an event. ]]
do
	-- Step 3 wants Kobold Vermin, Kobold Workers, Defias Thugs and Kobold
	-- Laborers. Around you: a dead vermin at 3 yards, vermin at 5, 12 and
	-- 40, a boar at 8, a laborer at 15.
	local units = {
		{ guid = "0xDEAD", name = "Kobold Vermin", d = 3, dead = true },
		{ guid = "0xV5", name = "Kobold Vermin", d = 5 },
		{ guid = "0xB8", name = "Stonetusk Boar", d = 8 },
		{ guid = "0xV12", name = "Kobold Vermin", d = 12 },
		{ guid = "0xL15", name = "Kobold Laborer", d = 15 },
		{ guid = "0xV40", name = "Kobold Vermin", d = 40 },
	}
	local byGuid, cur, pos = {}, nil, 0
	local function aim(guid)
		cur = guid
		target = guid and byGuid[guid] and byGuid[guid].name
		event = "PLAYER_TARGET_CHANGED"
		this = AegisPathfinder.activeEvents
		AegisPathfinder.activeEvents:GetScript("OnEvent")()
	end
	local function around(list)
		units, byGuid, pos = list, {}, 0
		for _, u in ipairs(units) do byGuid[u.guid] = u end
	end
	around(units)
	local keepDead = UnitIsDead
	TargetNearest = function()
		if table.getn(units) == 0 then return end
		pos = math.mod(pos, table.getn(units)) + 1
		aim(units[pos].guid)
	end
	TargetUnit = function(guid) pos = 0; aim(guid) end
	ClearTarget = function() pos = 0; aim(nil) end
	UnitGUID = function(unit) if unit == "target" then return cur end end
	UnitDistanceSquared = function(unit)
		local u = unit == "target" and byGuid[cur]
		if u then return u.d * u.d, true end
		return 0, false
	end
	UnitIsDead = function(unit) local u = unit == "target" and byGuid[cur]; return u and u.dead or false end

	AegisPathfinder.current = 3
	AegisPathfinder:PaintActiveFrames()
	world.hostile = { ["Kobold Vermin"] = true, ["Kobold Laborer"] = true, ["Stonetusk Boar"] = true }
	world.near = {}
	aim(nil)
	marks = {}

	local seen = {}
	for k = 1, 5 do
		AegisPathfinder:TargetNextActive()
		seen[k] = cur
	end
	check(seen[1] == "0xV5", "the first press takes the nearest of the step's, not the dead one; got %s", tostring(seen[1]))
	check(seen[2] == "0xV12", "the next press the next one out, got %s", tostring(seen[2]))
	check(seen[3] == "0xL15", "past the boar, which the step does not want, got %s", tostring(seen[3]))
	check(seen[4] == "0xV40", "and the farthest, got %s", tostring(seen[4]))
	check(seen[5] == "0xV5", "then round to the nearest again, got %s", tostring(seen[5]))
	check(marks["Kobold Vermin"] == MARK.SKULL and marks["Kobold Laborer"] == MARK.CROSS,
		"each marked for what the quest wants of it")

	-- Targeting something else, the next press starts from the nearest.
	aim("0xB8")
	AegisPathfinder:TargetNextActive()
	check(cur == "0xV5", "a target the step does not want: the nearest of the step's, got %s", tostring(cur))

	-- The quest icons wait while it looks round: only the one it takes is marked.
	aim(nil)
	marks, world.setCount = {}, 0
	AegisPathfinder:TargetNextActive()
	check(cur == "0xV5" and world.setCount == 1 and marks["Kobold Laborer"] == nil,
		"looking round marks nobody it passes, got %d marks", world.setCount)

	-- A tile: the next one by its name, each click.
	local vermin, laborer
	for _, t in ipairs(AegisPathfinder:GetActiveTargets(3)) do
		if t.name == "Kobold Vermin" then vermin = t elseif t.name == "Kobold Laborer" then laborer = t end
	end
	aim(nil)
	AegisPathfinder:TargetActive(laborer)
	check(cur == "0xL15", "a Kobold Laborer tile takes the laborer, got %s", tostring(cur))
	AegisPathfinder:TargetActive(laborer)
	check(cur == "0xL15", "and stays there, there being only the one, got %s", tostring(cur))
	AegisPathfinder:TargetActive(vermin)
	AegisPathfinder:TargetActive(vermin)
	check(cur == "0xV12", "the Kobold Vermin tile goes vermin by vermin, got %s", tostring(cur))

	-- None of the step's around: the target is put back, and it says so.
	around({ { guid = "0xB8", name = "Stonetusk Boar", d = 8 }, { guid = "0xB9", name = "Stonetusk Boar", d = 9 } })
	aim("0xB9")
	local said = table.getn(printed)
	check(AegisPathfinder:TargetNextActive() == false, "nobody of the step's around is a no")
	check(cur == "0xB9", "with the target as it was, got %s", tostring(cur))
	check(table.getn(printed) == said + 1, "and said once")
	aim(nil)
	AegisPathfinder:TargetNextActive()
	check(cur == nil, "with no target before, none after, got %s", tostring(cur))

	-- Out of its reach but there by name: TargetByName, as before.
	world.near["Kobold Vermin"] = true
	check(AegisPathfinder:TargetNextActive() and target == "Kobold Vermin",
		"one it cannot reach is still found by name, got %s", tostring(target))
	world.near = {}

	-- An error while it looks leaves the quest icons working.
	TargetNearest = function() error("boom") end
	aim(nil)
	check(not pcall(AegisPathfinder.TargetNextActive, AegisPathfinder), "the error comes through")
	marks, mouseover = {}, "Kobold Laborer"
	event = "UPDATE_MOUSEOVER_UNIT"
	AegisPathfinder.activeEvents:GetScript("OnEvent")()
	check(marks["Kobold Laborer"] == MARK.CROSS, "and the quest icons still mark after it")
	target = "Kobold Vermin"
	event = "PLAYER_TARGET_CHANGED"
	AegisPathfinder.activeEvents:GetScript("OnEvent")()
	check(marks["Kobold Vermin"] == MARK.SKULL, "on a new target too")
	mouseover = nil

	TargetNearest, TargetUnit, ClearTarget, UnitGUID, UnitDistanceSquared = nil, nil, nil, nil, nil
	UnitIsDead = keepDead
	target, marks, world.near = nil, {}, {}
end

-- The Action Buttons page -------------------------------------------------------------------

do
	local keepTargets, keepItems = AegisPathfinder.GetActiveTargets, AegisPathfinder.GetActiveItems
	local tlist = {
		{ name = "Marshal Dughan", kind = "npc", context = "talk", mark = MARK.STAR, action = "ACCEPT" },
		{ name = "Kobold Vermin", kind = "enemy", context = "kill", mark = MARK.SKULL, action = "COMPLETE" },
		{ name = "Kobold Laborer", kind = "enemy", context = "loot", mark = MARK.CROSS, action = "COMPLETE" },
	}
	local ilist = { { id = 5001, step = 1, bag = 0, slot = 1, count = 1, texture = "rod" },
		{ id = 5002, step = 2, bag = 0, slot = 4, count = 5, texture = "horn" } }
	AegisPathfinder.GetActiveTargets = function() return tlist end
	AegisPathfinder.GetActiveItems = function() return ilist end
	local char, profile = AegisPathfinder.db.char, AegisPathfinder.db.profile
	char.showactiveitems, char.showactivetargets = true, true
	local function at(b) local p, rel, rp, x, y = b:GetPoint(); return p, x, y, rel, rp end

	-- Which way each window grows.
	AegisPathfinder:PaintActiveFrames()
	local p1, x1 = at(items.tiles[1])
	local p2, x2 = at(items.tiles[2])
	check(p1 == "TOPLEFT" and p2 == "TOPLEFT" and x2 > x1, "to start with the tiles run right, the first at the left")
	char.itemsgrow = "left"
	AegisPathfinder:PaintActiveFrames()
	p1, x1 = at(items.tiles[1])
	p2, x2 = at(items.tiles[2])
	check(p1 == "TOPRIGHT" and x1 == -6 and x2 == -(6 + 36), "left: the first at the right, the next to its left, got %s %s %s",
		tostring(p1), tostring(x1), tostring(x2))
	char.itemsgrow = "down"
	AegisPathfinder:PaintActiveFrames()
	local _, _, y1 = at(items.tiles[1])
	local p, _, y2 = at(items.tiles[2])
	check(p == "TOP" and y1 == -(18 + 6) and y2 == -(18 + 6 + 36), "down: a column from the top, got %s %s", tostring(y1), tostring(y2))
	check(items:GetHeight() == 18 + 6 * 2 + 2 * 32 + 4, "as tall as its column, got %s", tostring(items:GetHeight()))
	char.itemsgrow = "up"
	AegisPathfinder:PaintActiveFrames()
	_, _, y1 = at(items.tiles[1])
	p, _, y2 = at(items.tiles[2])
	check(p == "BOTTOM" and y1 == 6 and y2 == 6 + 36, "up: a column from the bottom, got %s %s", tostring(y1), tostring(y2))
	char.targetsgrow = "left"
	AegisPathfinder:PaintActiveFrames()
	check(at(targets.tiles[1]) == "TOPRIGHT", "Active Targets grows its own way")

	-- A dragged window keeps the corner it grows from.
	profile.activeitemspoint, profile.activeitemsrel, profile.activeitemsx, profile.activeitemsy = "TOPLEFT", "BOTTOMLEFT", 100, 500
	char.itemsgrow = "right"
	AegisPathfinder:PaintActiveFrames()
	local width = items:GetWidth()
	AegisPathfinder:SetActiveGrowth("items", "left")
	check(char.itemsgrow == "left" and profile.activeitemspoint == "TOPRIGHT" and math.abs(profile.activeitemsx - (100 + width)) < 0.01,
		"turned to grow left, it is pinned by its right edge where it is, got %s %s", tostring(profile.activeitemspoint),
		tostring(profile.activeitemsx))
	AegisPathfinder:SetActiveGrowth("items", "up")
	check(profile.activeitemspoint == "BOTTOMLEFT", "and up, by its bottom, got %s", tostring(profile.activeitemspoint))
	char.itemsgrow = "left"
	items.header:GetScript("OnDragStart")()
	items.header:GetScript("OnDragStop")()
	check(profile.activeitemspoint == "TOPRIGHT", "dragging it saves the corner it grows from, got %s", tostring(profile.activeitemspoint))
	profile.activeitemspoint, profile.activeitemsrel, profile.activeitemsx, profile.activeitemsy = nil, nil, nil, nil
	char.itemsgrow, char.targetsgrow = "right", "right"

	-- Button size, on top of the window scale.
	char.buttonscale = 1.25
	AegisPathfinder:ApplyButtonScale()
	check(math.abs(items:GetScale() - 1.25) < 1e-6 and math.abs(targets:GetScale() - 1.25) < 1e-6,
		"the button size sizes the windows, got %s", tostring(items:GetScale()))
	AegisPathfinder.Theme:SetWindowScale(1.2)
	check(math.abs(items:GetScale() - 1.5) < 1e-6, "on top of the window scale, got %s", tostring(items:GetScale()))
	AegisPathfinder.Theme:SetWindowScale(1)
	char.buttonscale = 1
	AegisPathfinder:ApplyButtonScale()

	-- Which buttons show. The macros and the key bindings keep them all.
	char.btnitems = false
	AegisPathfinder:PaintActiveFrames()
	check(not items:IsShown(), "quest items off: no item buttons")
	used = {}
	check(AegisPathfinder:UseActiveItem(1), "but the key binding still uses the step's item")
	char.btnitems = nil
	char.btntalk = false
	AegisPathfinder:PaintActiveFrames()
	local n = 0
	for _, b in ipairs(targets.tiles) do if b:IsShown() then n = n + 1 end end
	check(n == 2, "talk to NPC off: the enemies alone, got %d", n)
	world.near = { ["Kobold Vermin"] = true, ["Marshal Dughan"] = true }
	world.hostile = { ["Kobold Vermin"] = true }
	target, marks = nil, {}
	this = targets.tiles[1]
	targets.tiles[1]:GetScript("OnClick")()
	check(target == "Kobold Vermin", "the first button is the first enemy, got %s", tostring(target))
	char.btntalk, char.btnkill = nil, false
	AegisPathfinder:PaintActiveFrames()
	n = 0
	for _, b in ipairs(targets.tiles) do if b:IsShown() then n = n + 1 end end
	check(n == 1, "kill enemy off: whom to talk to alone (looting goes with killing), got %d", n)
	char.btntalk = false
	AegisPathfinder:PaintActiveFrames()
	check(not targets:IsShown(), "both off: no target buttons")
	target = nil
	check(AegisPathfinder:TargetNextActive() and target ~= nil, "but the macro still targets the step's")
	char.btntalk, char.btnkill = nil, nil

	-- The raid marker switch: the buttons only target; quest icons still mark.
	char.raidmark = false
	AegisPathfinder:PaintActiveFrames()
	target, marks = nil, {}
	check(AegisPathfinder:TargetActive(tlist[2]) and target == "Kobold Vermin", "marking off: still targets")
	check(marks["Kobold Vermin"] == nil, "but leaves no mark")
	mouseover = "Kobold Laborer"
	local keepIcons, keepRaid = char.questicons, party.raid
	char.questicons, party.raid = true, 0
	world.hostile["Kobold Laborer"] = true
	check(AegisPathfinder:AutoMark("mouseover") and marks["Kobold Laborer"] == MARK.CROSS,
		"quest icons mark by themselves either way, got %s", tostring(marks["Kobold Laborer"]))
	char.questicons, party.raid = keepIcons, keepRaid
	mouseover = nil
	char.raidmark = nil
	marks = {}
	AegisPathfinder:TargetActive(tlist[2])
	check(marks["Kobold Vermin"] == MARK.SKULL, "on again, the button marks")

	-- Delete cheapest item: a tile after the items when the bags are full.
	local cheap, deleted = nil, nil
	local keepAuto = AegisPathfinder.Automation
	AegisPathfinder.Automation = {
		CheapestToDelete = function() return cheap end,
		DeleteCheapest = function(_, e) deleted = e end,
		Money = function(c) return c .. "c" end,
	}
	AegisPathfinder:PaintActiveFrames()
	check(not items.deleteTile:IsShown(), "room in the bags: no delete tile")
	cheap = { bag = 1, slot = 3, id = 2211, link = "[Bat Ear]", texture = "ear", count = 3, value = 0, grey = true }
	AegisPathfinder:PaintActiveFrames()
	local d = items.deleteTile
	check(d:IsShown() and d.icon:GetTexture() == "ear" and d.count:GetText() == "3", "full: the cheapest thing, after the items")
	local _, dx = at(d)
	check(dx == 6 + 2 * 36, "in the third place, got %s", tostring(dx))
	this = d
	d:GetScript("OnClick")()
	check(deleted == cheap, "a click deletes it (Automation asks first when it is not grey)")
	d:GetScript("OnEnter")()
	check(tooltip.bag == 1 and tooltip.slot == 3, "hovering it shows the item")
	d:GetScript("OnLeave")()
	char.btnitems = false
	AegisPathfinder:PaintActiveFrames()
	check(items:IsShown() and d:IsShown() and not items.tiles[1]:IsShown(), "quest items off, full bags: the delete tile alone")
	char.btnitems, char.btndelete = nil, false
	AegisPathfinder:PaintActiveFrames()
	check(not d:IsShown(), "delete cheapest item off: no tile")
	char.btndelete, cheap = nil, nil
	AegisPathfinder:PaintActiveFrames()
	check(not d:IsShown(), "room again: gone")
	AegisPathfinder.Automation = keepAuto

	AegisPathfinder.GetActiveTargets, AegisPathfinder.GetActiveItems = keepTargets, keepItems
	target, marks, world.near, world.hostile = nil, {}, {}, {}
end

-- The buttons go with the guide ------------------------------------------------------

--[[ Closing the guide takes the action buttons with it; a guide hidden by
	itself for combat or an instance has not been closed, and the
	Appearance page's switches say what the buttons do then. ]]
do
	local macrosWin = AegisPathfinder.macrosframe
	AegisPathfinder:PaintActiveFrames()
	check(items:IsShown() and targets:IsShown() and macrosWin:IsShown(), "with the guide open, the buttons show")
	guide:Hide()
	AegisPathfinder:PaintActiveFrames()
	check(not items:IsShown() and not targets:IsShown() and not macrosWin:IsShown(), "closing the guide hides them")
	AegisPathfinder.hiddenForCombat = true
	AegisPathfinder:PaintActiveFrames()
	check(items:IsShown() and targets:IsShown(), "a guide hidden for combat keeps them")
	AegisPathfinder.hiddenForCombat = nil
	AegisPathfinder.hiddenForInstance = true
	AegisPathfinder:PaintActiveFrames()
	check(items:IsShown() and targets:IsShown(), "and so does one hidden in a dungeon")
	AegisPathfinder.hiddenForInstance = nil
	guide:Show()
	AegisPathfinder:PaintActiveFrames()
	check(items:IsShown() and targets:IsShown(), "opening the guide brings them back")
end

-- Snapping ---------------------------------------------------------------------------

--[[ Let go of a window near another, or near the guide, and it sits flush
	against it, lining up with the edge they share when that is near too. ]]
do
	local snap = AegisPathfinder.SnapActiveFrame
	local macrosWin = AegisPathfinder.macrosframe
	macrosWin:Hide()
	local function At(f, x, top, w, h)
		f:ClearAllPoints()
		f:SetWidth(w); f:SetHeight(h)
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
	end
	At(items, 200, 500, 120, 56)
	-- Dropped 9 under Items and 6 to the right: flush under it, left edges lined up.
	At(targets, 206, 500 - 56 - 9, 80, 56)
	check(snap(targets) and targets:GetLeft() == 200 and targets:GetTop() == 500 - 56 - 2,
		"dropped just under Items, it snaps flush under it, lined up; got %s, %s",
		tostring(targets:GetLeft()), tostring(targets:GetTop()))
	-- Dropped 10 to the right of Items, 5 lower: flush beside it, tops lined up.
	At(targets, 200 + 120 + 10, 495, 80, 56)
	check(snap(targets) and targets:GetLeft() == 322 and targets:GetTop() == 500,
		"dropped beside Items, it snaps flush beside it; got %s, %s", tostring(targets:GetLeft()),
		tostring(targets:GetTop()))
	-- Far from everything: left where it is.
	At(targets, 700, 200, 80, 56)
	check(not snap(targets) and targets:GetLeft() == 700, "dropped far from the others, it stays put")
	-- Under the guide too.
	At(guide, 400, 800, 396, 300)
	At(targets, 410, 800 - 300 - 8, 80, 56)
	check(snap(targets) and targets:GetTop() == 800 - 300 - 2 and targets:GetLeft() == 400,
		"and it snaps to the guide; got %s, %s", tostring(targets:GetLeft()), tostring(targets:GetTop()))
	-- A real drop: snapped, pinned by its corner, and saved there.
	At(targets, 206, 500 - 56 - 9, 80, 56)
	this = targets.header
	targets.header:GetScript("OnDragStart")()
	targets.header:GetScript("OnDragStop")()
	check(targets:GetLeft() == 200 and targets:GetTop() == 500 - 56 - 2
		and AegisPathfinder.db.profile.activetargetspoint == "TOPLEFT",
		"a drop snaps, and is saved where it snapped; got %s, %s", tostring(targets:GetLeft()), tostring(targets:GetTop()))
end

-- Report ---------------------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("ActiveFrames: %d checks", checks))
if table.getn(failures) == 0 then
	print("All active frame checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
