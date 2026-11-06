--[[
	Tests for the first-time setup (SetupFrame.lua).

	Three steps in the manner of RestedXP's: which guide, which features,
	which dungeons. What matters is that it only ever writes the settings the
	options panel already has, starts from what the character already has,
	and changes nothing when nothing is changed.

	Run:  lua5.1 Tools/tests/test_setup.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
local level, faction, race, class = 1, "Alliance", "Human", "MAGE"
UnitLevel = function() return level end
UnitFactionGroup = function() return faction, faction end
UnitClass = function() return class, class end

local printed, packCalls, loads = {}, {}, 0
AegisPathfinder = {
	guides = {}, routepacks = {}, routes = {},
	db = { char = { currentguide = "Elwynn Forest (1-12)", Dungeons = {} }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print(msg) table.insert(printed, msg) end
function AegisPathfinder:GetRouteForRace() return race end
function AegisPathfinder:HasNoGuide() return false end
function AegisPathfinder:LoadGuide() loads = loads + 1 end
function AegisPathfinder:UpdateStatusFrame() end
function AegisPathfinder:GetAvailableRoutePacks()
	local out = {}
	for _, pack in pairs(self.routepacks) do
		if (not pack.factionRestriction or pack.factionRestriction == faction)
			and (not pack.classRestriction or pack.classRestriction == class) then
			table.insert(out, pack)
		end
	end
	return out
end
-- As Core.lua's: the pack's own starting features.
function AegisPathfinder:SelectRoutePack(name)
	table.insert(packCalls, name)
	self.db.char.routepack = name
	local rxp = name == "RestedXP"
	self.db.char.PlayStyle = rxp and "GROUP" or "SOLO"
	self.db.char.UseAH = rxp
end

-- The packs and their guides: the Optimized ones mark nothing; RestedXP's
-- mark all three kinds.
local function guide(name, text) AegisPathfinder.guides[name] = function() return text end end
guide("Optimized/Elwynn (1-10)", "A Wolves |QID|33|\nC Wolves |QID|33|")
guide("Optimized/Westfall (10-20)", "A Defias |QID|12|")
guide("RXP/Northshire (1-6)", "B Linen |N|buy|  |AH|\nA Hogger |QID|176| |P|GROUP|\nA Deadmines |QID|166| |D|DM|\nA Other |QID|167| |D|!DM|")
guide("RXP/Westfall (10-20)", "A Deadmines 2 |QID|168| |D|DM/WC|")
guide("HC/Elwynn (1-10)", "A Wolves |QID|33|")
AegisPathfinder.routepacks = {
	VanillaGuide = { name = "VanillaGuide", displayName = "Optimized", description = "Quest-optimized",
		routes = { Human = { { guide = "Optimized/Elwynn (1-10)" }, { guide = "Optimized/Westfall (10-20)" } },
			HighElf = { { guide = "Optimized/Elwynn (1-10)" } }, Orc = { { guide = "Optimized/Elwynn (1-10)" } } } },
	RestedXP = { name = "RestedXP", displayName = "RestedXP", description = "Speedrun",
		routes = { Human = { { guide = "RXP/Northshire (1-6)" }, { guide = "RXP/Westfall (10-20)" } },
			Orc = { { guide = "RXP/Northshire (1-6)" } } } },
	["RXP Hardcore"] = { name = "RXP Hardcore", displayName = "RXP Hardcore", description = "Survival",
		routes = { Human = { { guide = "HC/Elwynn (1-10)" } } } },
	["Warrior Pack"] = { name = "Warrior Pack", displayName = "Speedrun Pack", description = "Warrior",
		factionRestriction = "Horde", classRestriction = "WARRIOR", routes = { Orc = { { guide = "RXP/Northshire (1-6)" } } } },
}

-- What each pack's route takes you through, as DungeonQuests.lua says:
-- five Deadmines quests and six in Blackrock Depths for the RestedXP Human,
-- two in Wailing Caverns; the Stockade's, one alone and four more that run
-- through the Deadmines. None at all for the Optimized guides.
AegisPathfinder.DUNGEON_QUESTS = {
	RestedXP = {
		Human = { DM = { 166, 168, 214, 373, 389 }, WC = { 959, 1486 },
			STOCKADES = { 386, { 391, "DM" }, { 392, "DM" }, { 393, "DM" }, { 350, "DM" } },
			BRD = { 4081, 4082, 4083, 4122, 4123, 4126 } },
		Orc = { RFC = { 5722, 5723, 5724, 5725, 5726 }, BFD = { 6562, 6563, 6564, 6565, 6921 }, DM = { 103 } },
	},
}
AegisPathfinder.DUNGEON_RECOMMEND = 5

dofile("Theme.lua")
dofile("SetupFrame.lua")
local Theme = AegisPathfinder.Theme

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local function shown(list)
	local out = {}
	for _, b in ipairs(list) do if b:IsShown() then table.insert(out, b) end end
	return out
end
local function titles()
	local out = {}
	for _, c in ipairs(shown(AegisPathfinder.setupframe.cards)) do table.insert(out, c.title:GetText()) end
	return table.concat(out, ", ")
end
local function click(b) this = b; b:GetScript("OnClick")() end

-- Only the first time -----------------------------------------------------------

check(AegisPathfinder:MaybeShowSetup() == true, "a character that has not been set up is asked")
local f = AegisPathfinder.setupframe
check(f and f:IsShown(), "in a window")
-- A character with no dungeons ticked has two steps; turning dungeons on
-- adds the third.
check(f.stepText:GetText() == "STEP 1 OF 2", "on step 1 of 2, got %s", tostring(f.stepText:GetText()))
f:Hide(); f:GetScript("OnHide")()
check(AegisPathfinder.db.char.setupdone == true, "closing it counts as done")
check(AegisPathfinder:MaybeShowSetup() == false and not f:IsShown(), "so it is not asked again")
check(table.getn(packCalls) == 0 and AegisPathfinder.db.char.routepack == nil, "and closing changed nothing")

-- Step 1: the guide ----------------------------------------------------------------------

AegisPathfinder:ShowSetup()
check(titles() == "Optimized, RestedXP Speedrun, Hardcore Survival",
	"a Human mage is offered three guides, got %s", titles())
check(shown(f.cards)[1].selected, "the one in use, Optimized by default, starts selected")
check(not f.back:IsShown() and f.next:GetText() == "CONTINUE", "no Back on step 1")

race = "HighElf"
AegisPathfinder:ShowSetup()
check(titles() == "Optimized", "a High Elf only gets guides with a High Elf route, got %s", titles())
race, faction, class = "Orc", "Horde", "WARRIOR"
AegisPathfinder:ShowSetup()
check(titles() == "Optimized, RestedXP Speedrun, Speedrun Pack",
	"a Horde warrior also sees a Horde Warrior pack, by its own name, got %s", titles())
race, faction, class = "Human", "Alliance", "MAGE"
AegisPathfinder:ShowSetup()

-- Pick RestedXP: its features come with it.
click(shown(f.cards)[2])
check(shown(f.cards)[2].selected and not shown(f.cards)[1].selected, "picking a card selects it")
click(f.next)
check(f.stepText:GetText() == "STEP 2 OF 2", "on to step 2, got %s", tostring(f.stepText:GetText()))
check(f.features.ah:IsOn() and f.features.group:IsOn(),
	"RestedXP starts with the Auction House and group quests on, as its pack does")
check(not f.featureNote:IsShown(), "and its guides mark all three, so there is nothing to warn about")

-- Back, and pick Optimized: its guides mark none of them, and it says so.
click(f.back)
click(shown(f.cards)[1])
click(f.next)
check(not f.features.ah:IsOn() and not f.features.group:IsOn(), "Optimized starts with them off")
check(f.featureNote:IsShown() and string.find(f.featureNote:GetText(), "auction house, group, dungeon", 1, true),
	"and says its guides do not mark those steps yet, got '%s'", tostring(f.featureNote:GetText()))

-- Dungeons off: two steps, and Continue becomes Finish.
local function toggleDungeons() click(f.features.dungeons) end
if not f.features.dungeons:IsOn() then toggleDungeons() end
check(f.stepText:GetText() == "STEP 2 OF 3" and f.next:GetText() == "CONTINUE", "with dungeons on, three steps")
toggleDungeons()
check(f.stepText:GetText() == "STEP 2 OF 2" and f.next:GetText() == "FINISH",
	"with dungeons off, two, got %s / %s", tostring(f.stepText:GetText()), f.next:GetText())
toggleDungeons()

-- Solo Self-Found holds the Auction House, group quests and dungeons off, and
-- gives them back as they were.
click(f.features.group)
click(f.features.ssf)
check(f.features.ssf:IsOn(), "Solo Self-Found switches on")
for _, key in ipairs({ "ah", "group", "dungeons" }) do
	check(not f.features[key]:IsOn() and not f.features[key]:IsEnabled(), "and holds %s off", key)
end
check(f.stepText:GetText() == "STEP 2 OF 2" and f.next:GetText() == "FINISH", "with no dungeons step")
click(f.features.ssf)
check(f.features.group:IsOn() and f.features.group:IsEnabled() and f.features.dungeons:IsOn()
	and f.features.dungeons:IsEnabled(), "off again, group quests and dungeons are back as they were")
check(f.stepText:GetText() == "STEP 2 OF 3", "and so is the dungeons step")
click(f.features.group)

-- Step 3: the dungeons -------------------------------------------------------------------

click(f.back); click(shown(f.cards)[2]); click(f.next)   -- RestedXP again
click(f.next)
check(f.stepText:GetText() == "STEP 3 OF 3", "on to the dungeons")
local rows = shown(f.rows)
local names = {}
for _, r in ipairs(rows) do names[r.code] = r end
check(names.STOCKADES and not names.RFC, "Alliance gets the Stockade and not Ragefire Chasm")
check(table.getn(rows) == 14, "14 dungeons for the Alliance, got %d", table.getn(rows))
check(names.DM.steps:GetText() == "5 quests", "a dungeon says how many quests it adds, got %s", names.DM.steps:GetText())
check(names.WC.steps:GetText() == "2 quests", "counted for this pack and race, got %s", names.WC.steps:GetText())
check(names.SM.steps:GetText() == "none in this route", "and says so when it adds none, got %s", names.SM.steps:GetText())
check(names.DM.check:GetChecked() and names.BRD.check:GetChecked() and not names.WC.check:GetChecked()
	and not names.SFK.check:GetChecked(),
	"with none picked, it starts from the recommended ones: five quests or more")
check(names.STOCKADES.check:GetChecked(),
	"a dungeon whose quests run through a recommended one counts them too: the Stockade, with the Deadmines")
check(names.STOCKADES.steps:GetText() == "5 quests", "all five, with the Deadmines ticked, got %s", names.STOCKADES.steps:GetText())
check(names.DM.steps.__color[1] == Theme.color.accent[1] and names.WC.steps.__color[1] == Theme.color.textDim[1],
	"the recommended say so in the accent colour")

click(f.quick[2])   -- All
local all = true
for _, r in ipairs(shown(f.rows)) do if not r.check:GetChecked() then all = false end end
check(all, "All picks every one")
click(f.quick[3])   -- None
check(not names.DM.check:GetChecked(), "None clears them")
check(names.STOCKADES.steps:GetText() == "1 quest (+4 with Deadmines)",
	"with the Deadmines not ticked, the Stockade counts what it adds alone, got %s", names.STOCKADES.steps:GetText())
click(names.DM)
check(names.STOCKADES.steps:GetText() == "5 quests", "and the rest once it is, got %s", names.STOCKADES.steps:GetText())
click(names.DM)
click(names.WC)
check(names.WC.check:GetChecked(), "a row toggles its dungeon")
click(names.SFK); click(names.SFK)
check(not names.SFK.check:GetChecked(), "and toggles it back")

-- Level colours: green at your level, gold ahead, dim once past.
local accent, gold, dim = Theme.color.accent, Theme.color.gold, Theme.color.textDim
level = 20
AegisPathfinder:PaintSetup()
check(names.WC.range.__color[1] == accent[1], "18-25 at 20 is your level")
check(names.BRD.range.__color[1] == gold[1], "52-60 at 20 is ahead")
level = 30
AegisPathfinder:PaintSetup()
check(names.WC.range.__color[1] == dim[1], "18-25 at 30 is behind you")
level = 1

-- Finish -----------------------------------------------------------------------------------

check(f.next:GetText() == "FINISH", "the last step finishes")
packCalls, loads, printed = {}, 0, {}
click(f.next)
local db = AegisPathfinder.db.char
check(not f:IsShown(), "Finish closes it")
check(packCalls[1] == "RestedXP" and table.getn(packCalls) == 1, "switches to the chosen guide once")
check(db.UseAH == true and db.PlayStyle == "GROUP", "with the Auction House and group quests on")
check(db.Dungeons.WC == true and db.Dungeons.DM == false and db.Dungeons.RFC == false,
	"and only the dungeons picked")
check(db.setupdone == true, "done")
check(loads == 1, "the guide on screen is re-read with the new filters")
check(string.find(printed[table.getn(printed)] or "", "RestedXP Speedrun, group quests, Auction House steps on, 1 dungeon", 1, true),
	"and says what was set up, got '%s'", tostring(printed[table.getn(printed)]))

-- Again, changing nothing, changes nothing -----------------------------------------------------

packCalls, loads = {}, 0
AegisPathfinder:ShowSetup()
check(shown(f.cards)[2].selected, "it opens on what the character has now")
click(f.next)
check(f.features.ah:IsOn() and f.features.group:IsOn() and f.features.dungeons:IsOn(), "features too")
click(f.next)
check(names.WC.check:GetChecked() and not names.DM.check:GetChecked(), "and the dungeons")
click(f.next)
check(table.getn(packCalls) == 0, "the same guide is not switched to again, which would lose your place")
check(db.Dungeons.WC == true and db.Dungeons.DM == false and db.UseAH == true, "and nothing else moved")

-- Turning dungeons off turns them all off.
AegisPathfinder:ShowSetup()
click(f.next)
toggleDungeons()
check(not f.features.dungeons:IsOn(), "dungeons can be switched off")
click(f.next)
check(db.Dungeons.WC == false, "dungeons off leaves none ticked")

-- Finishing with Self-Found on keeps the choices underneath, and says so.
AegisPathfinder:ShowSetup()
click(f.next)
click(f.features.ssf)
printed = {}
click(f.next)
check(db.SelfFound == true and db.UseAH == true and db.PlayStyle == "GROUP",
	"Self-Found is saved, and the choices it holds off are kept")
check(string.find(printed[table.getn(printed)] or "", "Solo Self-Found (no group quests, dungeons, trading or Auction House)", 1, true),
	"and it says what that means, got '%s'", tostring(printed[table.getn(printed)]))
AegisPathfinder:ShowSetup()
click(f.next)
click(f.features.ssf)
click(f.next)
check(db.SelfFound == false, "and it can be switched off again")

-- Horde's list.
faction, race = "Horde", "Orc"
AegisPathfinder:ShowSetup()
click(f.next)
if not f.features.dungeons:IsOn() then toggleDungeons() end
click(f.next)
names = {}
for _, r in ipairs(shown(f.rows)) do names[r.code] = r end
check(names.RFC and not names.STOCKADES, "the Horde gets Ragefire Chasm and not the Stockade")
check(names.RFC.check:GetChecked() and names.BFD.check:GetChecked() and not names.DM.check:GetChecked(),
	"and its own recommended ones")
check(names.DM.steps:GetText() == "1 quest", "and its own counts, got %s", names.DM.steps:GetText())
check(not f.dungeonNote:IsShown(), "with quests to count, no note")

-- A pack whose guides take you through no dungeon's quests says so, and
-- recommends none.
click(f.back); click(f.back)
click(shown(f.cards)[1])                                  -- Optimized
click(f.next)
if not f.features.dungeons:IsOn() then toggleDungeons() end
click(f.next)
AegisPathfinder:PickSetupDungeons("recommended")
local none = true
for _, r in ipairs(shown(f.rows)) do
	if r.check:GetChecked() then none = false end
	if r.steps:GetText() ~= "none in this route" then none = false end
end
check(none, "the Optimized guides here have no dungeon quests: none recommended, none counted")
check(f.dungeonNote:IsShown() and string.find(f.dungeonNote:GetText(), "no dungeon's quests", 1, true),
	"and a note says why, got '%s'", tostring(f.dungeonNote:GetText()))
f:Hide()

-- Report --------------------------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Setup: %d checks", checks))
if table.getn(failures) == 0 then
	print("All setup checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, x in ipairs(failures) do print("  - " .. x) end
os.exit(1)
