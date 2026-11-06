--[[
	Tests for where a guide opens: SmartSkipToStep (Parser.lua) puts you at
	the step your quest log shows work at, or the first step not done.

	A new character, with nothing in the quest log and nothing completed,
	used to open at the end of the guide with every step before it counted
	as done -- the scan kept the last open step rather than the first.

	Run:  lua5.1 Tools/tests/test_smartskip.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

C_Timer = { After = function() end }
local log = {}          -- { title, qid, complete }
C_QuestLog = {
	RequestLoadQuestByID = function() end,
	GetNumQuestObjectives = function() return nil end,
	GetQuestIDForLogIndex = function(i) return log[i] and log[i][2] end,
}
C_Item = { RequestLoadItemDataByID = function() end }
GetNumQuestLogEntries = function() return table.getn(log) end
GetQuestLogTitle = function(i)
	local q = log[i]
	return q[1], 1, nil, nil, nil, q[3] and 1 or nil
end

AegisPathfinder = {
	guides = {}, guidelist = {},
	db = { char = { completion = {}, turnins = {}, Dungeons = {}, completedquests = {}, completedquestsbyid = {} },
		profile = {} },
	Locale = { PART_GSUB = "%s%(Part %d+%)" },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder:IsDebugging() return false end
function AegisPathfinder:IsQuestPossible() return true end
function AegisPathfinder:IsTrainingCompleted() return false end
function AegisPathfinder:GetQuestPrerequisites() return nil end
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
AegisPathfinder.Locale["Skipping to step %d (completed content detected)"] = "Skipping to step %d"

dofile("Parser.lua")
function AegisPathfinder:WarmCaches() end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

AegisPathfinder:RegisterGuide("Test Zone (1-10)", nil, "Alliance", function()
	return [[
N Welcome |N|Start here|
A First Quest |QID|1| |N|Talk to A|
C First Quest |QID|1| |N|Kill things|
T First Quest |QID|1| |N|Talk to A|
A Second Quest |QID|2| |N|Talk to B|
C Second Quest |QID|2| |N|Collect things|
T Second Quest |QID|2| |N|Talk to B|
R Somewhere |N|Walk there|
A Third Quest |QID|3| |N|Talk to C|
T Third Quest |QID|3| |N|Talk to C|
]]
end)

local function open()
	AegisPathfinder.db.char.currentguide = nil
	AegisPathfinder:LoadGuide("Test Zone (1-10)")
	return AegisPathfinder.current
end

-- A new character: nothing in the log, nothing done.
check(open() == 1, "a new character opens at the first step, got %s", tostring(AegisPathfinder.current))

-- Partway: the first quest handed in, the second in progress.
AegisPathfinder.db.char.completedquestsbyid[1] = true
log = { { "Second Quest", 2, false } }
AegisPathfinder.db.char.turnins = {}
check(open() == 6, "a quest in progress: its step, got %s", tostring(AegisPathfinder.current))
check(AegisPathfinder.turnedin[AegisPathfinder.quests[1]],
	"the welcome note before it is ticked: the log shows you are past it, and the status update would go back to it")

-- The second quest ready to hand in.
log = { { "Second Quest", 2, true } }
AegisPathfinder.db.char.turnins = {}
check(open() == 7, "a quest ready to hand in: its hand-in, got %s", tostring(AegisPathfinder.current))

-- Both done, nothing in the log: the first open step after them.
AegisPathfinder.db.char.completedquestsbyid[2] = true
log = {}
AegisPathfinder.db.char.turnins = {}
check(open() == 1, "the welcome note was never ticked, so that is the first open step, got %s",
	tostring(AegisPathfinder.current))
AegisPathfinder.db.char.turnins = {}
AegisPathfinder:LoadGuide("Test Zone (1-10)")
AegisPathfinder.turnedin[AegisPathfinder.quests[1]] = true
AegisPathfinder:SmartSkipToStep()
check(AegisPathfinder.current == 8, "with it ticked, the run after the second quest, got %s",
	tostring(AegisPathfinder.current))

-- Progress is per character: a new character's saved variables start empty.
AegisPathfinder.db.char = { completion = {}, turnins = {}, Dungeons = {}, completedquests = {}, completedquestsbyid = {} }
log = {}
check(open() == 1, "another character starts from the top")

--[[ Filters change which steps a guide has; they do not change a step's key.

	A step's key was its name and its place among the steps the filters kept,
	so turning the dungeons or group mode off renumbered every step after the
	first one that went, and the ticks saved against the old keys landed on
	other steps. It is now its place among all the guide's steps. ]]
AegisPathfinder:RegisterGuide("Filtered Zone (10-20)", nil, "Alliance", function()
	return [[
N Welcome |N|Start here|
A Dungeon Quest |QID|10| |D|DM| |N|For the Deadmines|
A Group Quest |QID|11| |P|GROUP| |N|Needs a group|
A Solo Quest |QID|12| |N|Anyone|
C Solo Quest |QID|12| |N|Kill things|
T Solo Quest |QID|12| |N|Hand it in|
R Somewhere |N|Walk there|
]]
end)
do
	local A = AegisPathfinder
	local keep = A.db.char
	local function fresh()
		A.db.char = { completion = {}, turnins = {}, Dungeons = { DM = true }, PlayStyle = "GROUP",
			completedquests = {}, completedquestsbyid = {} }
	end
	fresh()
	log = {}
	A:LoadGuide("Filtered Zone (10-20)")
	check(table.getn(A.quests) == 7 and A.quests[4] == "Solo Quest@4@", "every step, the Solo Quest's accept at 4")
	A.turnedin[A.quests[1]] = true
	A.turnedin[A.quests[4]] = true                   -- Solo Quest picked up

	A.db.char.Dungeons.DM, A.db.char.PlayStyle = false, "SOLO"
	A:LoadGuide("Filtered Zone (10-20)")
	check(table.getn(A.quests) == 5 and A.actions[2] == "ACCEPT" and A.quests[2] == "Solo Quest@4@",
		"dungeons and group mode off: two steps fewer, and the Solo Quest's accept keeps its key, got %s",
		tostring(A.quests[2]))
	check(A.turnedin[A.quests[1]] and A.turnedin[A.quests[2]], "so its tick is still on it")
	check(not A.turnedin[A.quests[3]], "and not on the step after it")

	-- A guide with nothing filtered keeps the keys it always had.
	A:LoadGuide("Test Zone (1-10)")
	check(A.quests[3] == "First Quest@3@" and A.quests[10] == "Third Quest@10@",
		"nothing filtered: the same keys as before, got %s", tostring(A.quests[3]))

	--[[ Ticks saved the old way move over once: saved with the dungeons and
		group mode off, the accept was the 2nd step kept, the objectives the
		3rd. ]]
	fresh()
	A.db.char.Dungeons.DM, A.db.char.PlayStyle = false, "SOLO"
	A.db.char.turnins["Filtered Zone (10-20)"] = { ["Welcome@1@"] = true, ["Solo Quest@2@"] = true,
		["Solo Quest@3@"] = true }
	A:LoadGuide("Filtered Zone (10-20)")
	local t = A.db.char.turnins["Filtered Zone (10-20)"]
	check(t["Welcome@1@"] and t["Solo Quest@4@"] and t["Solo Quest@5@"] and not t["Solo Quest@2@"]
		and not t["Solo Quest@3@"], "old ticks move to the new keys: the accept, the objectives")
	check(A.db.char.stepkeys["Filtered Zone (10-20)"] == 2, "and the guide is marked done")
	t["Solo Quest@2@"] = true                        -- nothing the second time
	A:LoadGuide("Filtered Zone (10-20)")
	check(A.db.char.turnins["Filtered Zone (10-20)"]["Solo Quest@2@"] and t["Solo Quest@4@"],
		"once only: a second load moves nothing")
	A.db.char = keep
end

-- Early on, with a quest from elsewhere ready to hand in at the end: the run
-- to it is ticked, but not the welcome, nor anything before a quest you have
-- not picked up.
log = { { "Third Quest", 3, true } }
check(open() == 10, "the hand-in the log shows is ready, got %s", tostring(AegisPathfinder.current))
check(AegisPathfinder.turnedin[AegisPathfinder.quests[8]], "the run to it is ticked")
check(not AegisPathfinder.turnedin[AegisPathfinder.quests[1]], "the welcome is not: nothing after it has been reached")

-- Only finding the place ticks nothing.
AegisPathfinder.db.char.turnins = {}
AegisPathfinder:LoadGuide("Test Zone (1-10)")
AegisPathfinder.turnedin[AegisPathfinder.quests[8]] = nil
AegisPathfinder:SmartSkipToStep(true)
check(AegisPathfinder.current == 10 and not AegisPathfinder.turnedin[AegisPathfinder.quests[8]],
	"looking for the place leaves the run as it was")

--[[ Through the status update, on the guide it happened in.

	Loch Modan (17-18) opened at Crocolisk Hunting, step 28, with 27 done.
	The next status update starts from step 1 and stops at the first step
	not done, which was the guide's opening note, never ticked: the guide
	went back to 1 of 58, 0 done. ]]
do
	local A = AegisPathfinder
	local server = {}
	C_Item = { RequestLoadItemDataByID = function() end, GetItemCount = function() return 0 end }
	GetZoneText = function() return "Loch Modan" end
	GetSubZoneText = function() return "" end
	UnitLevel = function() return 17 end
	QuestLog_Update = function() end
	QuestWatch_Update = function() end
	A.manuallyUnchecked, A.icons, A.turninskipwarned = {}, {}, {}
	A.db.char = { completion = {}, turnins = {}, Dungeons = {}, completedquests = {}, completedquestsbyid = {},
		petskills = {} }
	function A:IsQuestCompletedOnServer(q) return server[tonumber(q)] end
	function A:GetUnmetPrerequisites() return {} end
	function A:TrackCurrentQuest() end
	function A:GetQuestDetails(_, _, qid)
		for i, q in ipairs(log) do if q[2] == qid then return i, q[3] end end
	end
	function A:ForceWaypointUpdate() end
	function A:UpdateOHPanel() end
	function A:UpdateNavCallout() end
	function A:RedriveQuestAutomation() end
	function A:LoadNextGuide() return false end
	function A:GetWaypointProvider() return nil end
	function A:FindBagSlot() return nil end
	function A:GetLootRequirement() return nil end
	dofile("GuideEngine.lua")
	local core = io.open("Core.lua"):read("*a")
	local a = string.find(core, "function AegisPathfinder:GetObjectiveInfo(", 1, true)
	local b = string.find(core, "function AegisPathfinder:CompleteQuest(", a, true)
	assert(loadstring(string.sub(core, a, b - 1)))()
	dofile("Guides/Optimized/Alliance/17_18_Loch_Modan.lua")

	-- Handed in so far; in the log, Crocolisk Hunting, 4 of 5 meat.
	for _, q in ipairs({ 307, 436, 297, 257, 258 }) do server[q] = true; A.db.char.completedquestsbyid[q] = true end
	log = { { "Stormpike's Order", 1338 }, { "Excavation Progress Report", 298 }, { "Crocolisk Hunting", 385 },
		{ "Vyrin's Revenge", 271 }, { "Bingles' Missing Supplies", 2038 } }
	A:LoadGuide("Optimized/Loch Modan (17-18)")
	check(A.current == 28 and A.actions[28] == "COMPLETE", "Loch Modan opens at Crocolisk Hunting, got %s",
		tostring(A.current))
	A:UpdateStatusFrame()
	check(A.current == 28, "and the status update keeps it there, not back to the opening note, got %s",
		tostring(A.current))
	A:LoadGuide("Optimized/Loch Modan (17-18)")
	A:UpdateStatusFrame()
	check(A.current == 28, "a reload too, got %s", tostring(A.current))
	check(not A.turnedin[A.quests[29]], "and nothing after it is ticked")
end

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("SmartSkip: %d checks", checks))
if table.getn(failures) == 0 then
	print("All smart skip checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
