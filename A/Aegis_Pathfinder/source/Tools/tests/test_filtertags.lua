--[[
	The filter tags added to the Optimized and zone guides, through the real
	parser.

	The Auction House, Group and Dungeon switches hide steps at parse time.
	These guides carried no tags until the owner's review
	(Tools/data/filter_decisions.json, applied by Tools/build/apply_filter_tags.py);
	this checks the tags landed where the switches can see them: a group quest
	and the quests that follow it hide in Solo mode and show in Group mode, an
	Auction House step hides with Auction House steps off, a dungeon quest
	hides when its dungeon is unticked -- and every tag applied is still there.

	Run:  lua5.1 Tools/tests/test_filtertags.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

C_Timer = { After = function() end }
C_QuestLog = { RequestLoadQuestByID = function() end, GetNumQuestObjectives = function() return nil end }
C_Item = { RequestLoadItemDataByID = function() end }

AegisPathfinder = {
	guides = {}, guidelist = {}, nextzones = {},
	db = { char = { completion = {}, turnins = {}, Dungeons = {} }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder:IsDebugging() return false end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder.split(sep, s)
	local fields = {}
	string.gsub(s, string.format("([^%s]+)", sep), function(c) fields[table.getn(fields) + 1] = c end)
	return fields
end
function AegisPathfinder:RegisterGuide(name, nextzone, faction, loader)
	self.guides[name] = loader
	table.insert(self.guidelist, name)
end

-- A Human Paladin, so the Tome of Divinity steps are on the route at all.
UnitClass = function() return "Paladin", "PALADIN" end
dofile("Parser.lua")
function AegisPathfinder:SmartSkipToStep() end
function AegisPathfinder:WarmCaches() end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

dofile("Guides/Optimized/Alliance/01_10_Elwynn_Forest.lua")
dofile("Guides/Alliance/12_17_Westfall.lua")
dofile("Guides/Alliance/28_29_Duskwood.lua")
dofile("Guides/Optimized/Alliance/10_12_Westfall.lua")
dofile("Guides/Alliance/12_17_Darkshore.lua")

local char = AegisPathfinder.db.char

-- How many of a guide's parsed steps name `text`, under the given settings.
local function count(guide, text, playstyle, ah, dungeons)
	char.PlayStyle, char.UseAH, char.Dungeons = playstyle, ah, dungeons or {}
	char.currentguide = nil
	AegisPathfinder:LoadGuide(guide)
	local n = 0
	for _, q in ipairs(AegisPathfinder.quests) do
		if string.find(q, text, 1, true) then n = n + 1 end
	end
	return n
end

local ELWYNN = "Optimized/Elwynn Forest (1-10)"
check(count(ELWYNN, "Discover Rolf's Fate", "SOLO", false) == 0,
	"a group quest should be hidden in Solo mode")
check(count(ELWYNN, "Discover Rolf's Fate", "GROUP", false) == 2,
	"a group quest should be shown in Group mode -- accept and turn in")
check(count(ELWYNN, "Report to Thomas", "SOLO", false) == 0,
	"the quest after a group quest can't be picked up solo either")
check(count(ELWYNN, "Report to Thomas", "GROUP", false) > 0,
	"the quest after a group quest shows in Group mode")
check(count(ELWYNN, "Shipment to Stormwind", "SOLO", false) > 0,
	"a quest whose id only sat on a tagged travel step is untouched")

-- Answers changed after the review: these can be done without the Auction
-- House, and the travel step is not Hogger's.
check(count("Westfall (12-17)", "The Tome of Divinity (Part 5)", "SOLO", false) == 3,
	"the Tome of Divinity needs only Linen Cloth, which drops -- it stays with Auction House steps off")
check(count("Optimized/Westfall (10-12)", "Stormwind City@", "SOLO", false) > 0,
	"the trip to Stormwind for Shipment to Stormwind stays in Solo mode")

-- The Auction House tag is for the step that sends you there, not for a
-- quest you can do another way: fish, farm the drop, find the vendor.
check(count("Darkshore (12-17)", "The Family and the Fishing Pole", "SOLO", false) == 3,
	"a fishing quest stays with Auction House steps off: you can catch the fish")
check(count("Duskwood (28-29)", "Look To The Stars (Part 1)", "SOLO", false) == 3,
	"a quest whose item drops stays with Auction House steps off")

local DUSKWOOD = "Duskwood (28-29)"
check(count(DUSKWOOD, "[Bronze Tube]", "SOLO", false) == 0,
	"an Auction House buy step should be hidden with Auction House steps off")
check(count(DUSKWOOD, "[Bronze Tube]", "SOLO", true) == 1,
	"an Auction House buy step should show with Auction House steps on")

-- Solo Self-Found: no Auction House whatever its switch says, and no step
-- that needs another player.
char.SelfFound = true
check(count(DUSKWOOD, "[Bronze Tube]", "SOLO", true) == 0,
	"Solo Self-Found hides Auction House steps even with them switched on")
AegisPathfinder:RegisterGuide("Trade Test (1-2)", nil, "Alliance", function()
	return "N Ask a mage for water |N|Trade for it| |TRADE|\nN Drink |N|Sit down|\n"
end)
check(count("Trade Test (1-2)", "Ask a mage", "SOLO", true) == 0, "Solo Self-Found hides a |TRADE| step")
check(count("Trade Test (1-2)", "Drink", "SOLO", true) == 1, "and keeps the rest")
check(count(ELWYNN, "Discover Rolf's Fate", "GROUP", false) == 0,
	"Solo Self-Found is solo: a group quest stays hidden with group mode on")
check(count("Westfall (12-17)", "The Defias Brotherhood (Part 2)", "SOLO", false, { DM = true }) == 0,
	"and runs no dungeons: a Deadmines quest stays hidden with the Deadmines ticked")
char.SelfFound = false
check(count(ELWYNN, "Discover Rolf's Fate", "GROUP", false) == 2
	and count("Westfall (12-17)", "The Defias Brotherhood (Part 2)", "SOLO", false, { DM = true }) > 0,
	"off again, group mode and the Deadmines are as they were")
check(count("Trade Test (1-2)", "Ask a mage", "SOLO", false) == 1, "a |TRADE| step shows otherwise")

-- The Step Display page's skips: setting a hearthstone, discovering a flight path.
AegisPathfinder:RegisterGuide("Skip Test (1-2)", nil, "Alliance", function()
	return "h Goldshire |N|Set your hearthstone at the inn|\nf Sentinel Hill |N|Get the flight path|\nR Westfall |N|Run there|\n"
end)
check(count("Skip Test (1-2)", "Goldshire", "SOLO", false) == 1 and count("Skip Test (1-2)", "Sentinel Hill", "SOLO", false) == 1,
	"hearthstone and flight path steps show to start with")
char.skiphearth = true
check(count("Skip Test (1-2)", "Goldshire", "SOLO", false) == 0 and count("Skip Test (1-2)", "Sentinel Hill", "SOLO", false) == 1,
	"skipping hearthstones leaves out setting one, and nothing else")
char.skiphearth, char.skipflightpaths = nil, true
check(count("Skip Test (1-2)", "Sentinel Hill", "SOLO", false) == 0 and count("Skip Test (1-2)", "Westfall", "SOLO", false) == 1,
	"skipping flight paths leaves out discovering one, and the run stays")
char.skipflightpaths = nil

local WESTFALL = "Westfall (12-17)"
check(count(WESTFALL, "The Defias Brotherhood (Part 2)", "SOLO", false, {}) == 0,
	"a Deadmines quest should be hidden with the Deadmines unticked")
check(count(WESTFALL, "The Defias Brotherhood (Part 2)", "SOLO", false, { DM = true }) > 0,
	"a Deadmines quest should show with the Deadmines ticked")

-- Quests only some races can take, by pfQuest's race bits (pfQuest-turtle's
-- masks: Horde 434 has the Goblin's 256, Alliance 589 the High Elf's 512).
-- A quest not for your race has its steps ticked done, so a Goblin who read
-- every Horde quest that way jumped from step 1 to step 100.
do
	local savedRace, savedDB = UnitRace, pfDB
	pfDB = { quests = { data = {
		[90001] = { race = 434 },  -- every Horde race, Goblins too
		[90002] = { race = 589 },  -- every Alliance race, High Elves too
		[90003] = { race = 130 },  -- Orcs and Trolls
		[90004] = { race = 16 },   -- Undead only
	} } }
	local function possible(token, qid)
		UnitRace = function() return token, token end
		return AegisPathfinder:IsQuestPossible(qid)
	end
	check(possible("Goblin", 90001) and not possible("Goblin", 90002), "a Goblin takes Horde quests, not Alliance ones")
	check(possible("BloodElf", 90002) and not possible("BloodElf", 90001), "a High Elf (BloodElf to the client) takes Alliance quests")
	check(possible("Scourge", 90004) and not possible("Scourge", 90003), "Undead (Scourge to the client) take Undead quests, not Orc and Troll ones")
	check(possible("Orc", 90003) and possible("Troll", 90001) and not possible("Goblin", 90003), "Orcs and Trolls' own quests are theirs")
	check(possible("Human", 90002) and not possible("Human", 90004), "a Human takes Alliance quests, not Undead ones")
	UnitRace, pfDB = savedRace, savedDB
end

-- A Goblin, landed in Durotar from Blackstone Island, is sent to Razor Hill
-- for Conscript of the Horde like an Orc or Troll: the steps were tagged for
-- the three vanilla races alone, and the guide began at the Crossroads.
do
	local savedRace = UnitRace
	UnitRace = function() return "Goblin", "Goblin" end
	dofile("Parser.lua")
	function AegisPathfinder:SmartSkipToStep() end
	function AegisPathfinder:WarmCaches() end
	dofile("Guides/Optimized/Horde/12_15_Barrens.lua")
	check(count("Optimized/The Barrens (12-15)", "Conscript of the Horde", "SOLO", false) == 2,
		"a Goblin is given Conscript of the Horde in the Barrens (12-15)")
	check(count("Optimized/The Barrens (12-15)", "Meats to Orgrimmar", "SOLO", false) == 0,
		"but not the Orc and Troll flight quest")
	UnitRace = savedRace
	dofile("Parser.lua")
	function AegisPathfinder:SmartSkipToStep() end
	function AegisPathfinder:WarmCaches() end
end

-- Every approved tag is still in place.
local rc = os.execute("python3 Tools/build/apply_filter_tags.py --check > /dev/null")
check(rc == 0, "apply_filter_tags.py --check: an approved tag is missing or a reviewed step moved")

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("FilterTags: %d checks", checks))
if table.getn(failures) == 0 then
	print("All filter tag checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
