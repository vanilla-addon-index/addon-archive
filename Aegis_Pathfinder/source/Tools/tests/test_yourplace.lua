--[[
	Tests for the right-click on the step arrows: back or on to your place in
	the guide (Core.lua's RememberPlace / ReturnToPlace), through the real
	arrows -- SkipToNextObjective, GoToPreviousObjective, SetTurnedIn -- lifted
	from Core.lua, and the real SmartSkipToStep from Parser.lua.

	Run:  lua5.1 Tools/tests/test_yourplace.lua
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

local printed = {}
AegisPathfinder = {
	guides = {}, guidelist = {}, manuallyUnchecked = {},
	db = { char = { completion = {}, turnins = {}, Dungeons = {}, completedquests = {}, completedquestsbyid = {} },
		profile = {} },
	Locale = { PART_GSUB = "%s%(Part %d+%)" },
}
local A = AegisPathfinder
function A:Debug() end
function A:Print(msg) table.insert(printed, msg) end
function A:IsDebugging() return false end
function A:IsQuestPossible() return true end
function A:IsQuestCompletedOnServer() return false end
function A:IsTrainingCompleted() return false end
function A:GetQuestPrerequisites() return nil end
function A:GetQuestDetails(_, _, qid)
	for i, q in ipairs(log) do if q[2] == qid then return i, q[3] end end
end
function A:ForceWaypointUpdate() end
function A:SetStatusText() end
function A:UpdateOHPanel() end
function A:UpdateStatusFrame() end
function A:LoadNextGuide() return false end
function A.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function A.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function A.split(sep, s)
	local fields = {}
	string.gsub(s, string.format("([^%s]+)", sep), function(c) fields[table.getn(fields) + 1] = c end)
	return fields
end
function A:RegisterGuide(name, nextzone, faction, loader)
	self.guides[name] = loader
	table.insert(self.guidelist, name)
end
A.Locale["Skipping to step %d (completed content detected)"] = "Skipping to step %d"

dofile("Parser.lua")
function A:WarmCaches() end

-- The real arrows, lifted from Core.lua, which loads the whole addon.
do
	local core = io.open("Core.lua"):read("*a")
	local function lift(from, to)
		local a = string.find(core, from, 1, true)
		local b = string.find(core, to, a, true)
		assert(a and b, "could not find " .. from .. " in Core.lua")
		assert(loadstring(string.sub(core, a, b - 1)))()
	end
	lift("function AegisPathfinder:GetObjectiveStatus(i)", "function AegisPathfinder:CompleteQuest(")
	lift("function AegisPathfinder:SkipToNextObjective()", "function AegisPathfinder:GoToObjective(")
end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

A:RegisterGuide("Test Zone (1-10)", nil, "Alliance", function()
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

local function marks()
	local out = {}
	for i, q in ipairs(A.quests) do out[i] = A.turnedin[q] and "x" or "." end
	return table.concat(out)
end

-- Partway: the welcome ticked, the first quest handed in, the second in the log.
local db = A.db.char
db.completedquestsbyid[1] = true
db.completedquests["First Quest"] = true
log = { { "Second Quest", 2, false } }
A:LoadGuide("Test Zone (1-10)")
A.turnedin[A.quests[1]] = true
A:SmartSkipToStep()
check(A.current == 6, "the guide opens at the quest in the log, got %s", tostring(A.current))
local before = marks()
check(before == "xxxxx.....", "steps 1-5 done, got %s", before)

-- Looking back: three clicks back, then a right-click on the forward arrow.
for _ = 1, 3 do A:RememberPlace(); A:GoToPreviousObjective() end
check(A.current == 3, "three steps back, got %s", tostring(A.current))
check(marks() ~= before and not db.completedquestsbyid[1], "the back arrow unmarked the steps and the quest")
printed = {}
A:ReturnToPlace(-1)
check(A.current == 3 and printed[1] and string.find(printed[1], "forward arrow", 1, true),
	"right-clicking the back arrow says your place is the other way, got %s", tostring(printed[1]))
A:ReturnToPlace(1)
check(A.current == 6, "right-clicking the forward arrow takes you back to your place, got %s", tostring(A.current))
check(marks() == before, "with every step as it was, got %s", marks())
check(db.completedquestsbyid[1] and db.completedquests["First Quest"], "and the first quest's completion back")
check(A.place == nil, "and the snapshot spent")

-- Looking ahead: two skips on, then a right-click on the back arrow.
A:RememberPlace(); A:SkipToNextObjective()
A:RememberPlace(); A:SkipToNextObjective()
check(A.current == 8, "two steps on, got %s", tostring(A.current))
check(A.turnedin[A.quests[6]] and A.turnedin[A.quests[7]], "the forward arrow marked what it passed")
A:ReturnToPlace(-1)
check(A.current == 6 and marks() == before, "the back arrow's right-click undoes that, got %s at %s",
	marks(), tostring(A.current))

-- Past your place and part way back: everything the arrows touched is put
-- back, not just the steps between where you are and your place.
A:RememberPlace(); A:SkipToNextObjective()
A:RememberPlace(); A:SkipToNextObjective()
A:RememberPlace(); A:GoToPreviousObjective()
check(A.current == 7 and A.manuallyUnchecked[A.quests[8]], "two on and one back leaves step 8 unticked by hand")
A:ReturnToPlace(-1)
check(A.current == 6 and marks() == before and not A.manuallyUnchecked[A.quests[8]],
	"right-clicking back restores step 8 too, got %s", marks())

-- A completion earned while you looked round stays.
A:RememberPlace(); A:GoToPreviousObjective()
db.completedquestsbyid[3] = true
A:ReturnToPlace(1)
check(db.completedquestsbyid[3], "a quest finished meanwhile is still finished")
db.completedquestsbyid[3] = nil

-- At your place already.
printed = {}
A:ReturnToPlace(1)
check(A.current == 6 and printed[1] == "You are at your place in the guide.", "at your place it says so, got %s",
	tostring(printed[1]))

-- Without clicking round: where the guide would open, and no marks changed.
A.current = 2
local was = marks()
A:ReturnToPlace(1)
check(A.current == 6, "with no snapshot, the forward right-click goes to where the guide would open, got %s",
	tostring(A.current))
check(marks() == was, "changing no marks")
log = { { "Second Quest", 2, true } }
A.current = 9
A:ReturnToPlace(-1)
check(A.current == 7, "and back to a hand-in the log says is ready, got %s", tostring(A.current))

-- A hand-in whose quest is not in the log is passed over -- unless the quest
-- is on your quest list under a collapsed header, out of the log's sight.
log = {}
local tSecond
for i, q in ipairs(A.quests) do if A.actions[i] == "TURNIN" and string.find(q, "^Second Quest") then tSecond = i end end
db.completedquestsbyid[2] = nil
A.manuallyUnchecked[A.quests[tSecond]] = nil
local skipped, _, _, flagged = A:GetObjectiveStatus(tSecond)
check(skipped and flagged, "a hand-in for a quest you don't have is passed over")
C_QuestLog.IsOnQuest = function(q) return q == 2 end
skipped, _, _, flagged = A:GetObjectiveStatus(tSecond)
check(not skipped and not flagged, "but not one whose quest is on your list under a collapsed header")
C_QuestLog.IsOnQuest = nil

-- Another guide: the snapshot belongs to the one you leave.
A:RememberPlace()
check(A.place ~= nil, "a snapshot is taken")
A:LoadGuide("Test Zone (1-10)")
check(A.place == nil, "and dropped when a guide loads")

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("YourPlace: %d checks", checks))
if table.getn(failures) == 0 then
	print("All your-place checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
