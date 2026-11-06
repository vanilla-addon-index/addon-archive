--[[
	Tests for what the profession guides tell you about training, and how
	their steps complete.

	Four things the guides did not do, checked here against the generated
	guides run through the real parser and the real engine:

	  - a primary craft's rank waits for the character level it needs
	    (Apprentice 5, Journeyman 10, Expert 20, Artisan 35), and says so;
	  - each training step names the player's own faction's trainers, its
	    cost, and the cap it completes on;
	  - Cooking and First Aid read their Expert tome and earn Artisan by
	    quest, at the point in the route -- skill 225 -- the quest needs;
	  - steps complete on the skill and cap the client reports, so a guide
	    opened by someone already past a step moves on, and a gathering step
	    waits for its skill rather than counting as done on arrival.

	Run:  lua5.1 Tools/tests/test_professionsteps.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

GameTooltip_Hide = function() end
C_Timer = { After = function() end, NewTicker = function() end }
C_Item = { GetItemCount = function() return 0 end, GetItemIconByID = function() return nil end }
QuestLog_Update = function() end
QuestWatch_Update = function() end
UnitAffectingCombat = function() return false end
GetZoneText = function() return "Elwynn Forest" end
GetSubZoneText = function() return "" end
GetNumQuestLeaderBoards = function() return 0 end

local level = 1
UnitLevel = function() return level end

-- The character's professions, as GetSkillLineInfo reports them:
-- name, header, expanded, rank, temp, modifier, cap.
local skills = {}
GetNumSkillLines = function() return table.getn(skills) end
GetSkillLineInfo = function(i)
	local s = skills[i]
	return s.name, false, nil, s.rank, 0, 0, s.cap
end
local function setSkill(name, rank, cap)
	for _, s in ipairs(skills) do
		if s.name == name then s.rank, s.cap = rank, cap return end
	end
	table.insert(skills, { name = name, rank = rank, cap = cap })
end

AegisPathfinder = {
	guides = {}, guidelist = {}, nextzones = {}, qsplusguides = {},
	actions = {}, quests = {}, tags = {}, turnedin = {},
	current = 1, myfaction = "Alliance", icons = {},
	db = { char = { completedquests = {}, completedquestsbyid = {}, petskills = {} }, profile = {} },
	Locale = { PART_GSUB = "%s%(Part %d+%)", PART_FIND = "(.+)%s%(Part %d+%)" },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder:RegisterGuide(name, nextzone, faction, loader)
	self.guides[name] = loader
	table.insert(self.guidelist, name)
end
function AegisPathfinder:RegisterEvent() end
function AegisPathfinder:GetObjectiveInfo(i) return self.actions[i], self.quests[i], self.quests[i] end
function AegisPathfinder:GetObjectiveStatus(i) return self.turnedin[self.quests[i]] end
function AegisPathfinder:GetLootRequirement() return nil end
function AegisPathfinder:FindBagSlot() return nil end
function AegisPathfinder:IsQuestCompletedOnServer() return false end
function AegisPathfinder:IsTrainingCompleted() return false end
function AegisPathfinder:LoadNextGuide() return false end
function AegisPathfinder:GetWaypointProvider() return nil end
function AegisPathfinder:UpdateOHPanel() end
function AegisPathfinder:UpdateNavCallout() end
function AegisPathfinder:RedriveQuestAutomation() end
function AegisPathfinder:TrackCurrentQuest() end
function AegisPathfinder:IsEventRegistered() return false end
function AegisPathfinder:UnregisterEvent() end
-- Core's, as far as the engine relies on it: mark done, look again.
function AegisPathfinder:SetTurnedIn(i, value)
	self.turnedin[self.quests[i]] = value and true or nil
	self:UpdateStatusFrame()
end

dofile("Theme.lua")
dofile("Parser.lua")
dofile("QuestShellPlusParser.lua")
dofile("Professions.lua")
dofile("GuideEngine.lua")

for _, name in ipairs({ "Alchemy", "Blacksmithing", "Enchanting", "Jewelcrafting", "Leatherworking",
	"Tailoring", "Mining", "Cooking", "First_Aid", "Survival" }) do
	dofile("Guides/Professions/" .. name .. ".lua")
end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local P = AegisPathfinder
local function load(guide, faction)
	P.myfaction = faction or "Alliance"
	P.actions, P.quests, P.tags = P:ParseQuestShellPlus(P.qsplusguides[guide])
	P.turnedin, P.current = {}, 1
end
local function find(pattern, from)
	for i = from or 1, table.getn(P.actions) do
		if string.find(P.quests[i], pattern) then return i end
	end
end
local function tag(t, i) return P:GetObjectiveTag(t, i) end
-- The guide opens with notes the player reads and ticks.
local function readIntro()
	local i = 1
	while P.actions[i] == "NOTE" do P.turnedin[P.quests[i]] = true; i = i + 1 end
end

-- The path the addon actually loads -------------------------------------------------

--[[ Everything below reads the guides through ParseQuestShellPlus. The addon
	loads them through RegisterQuestShellPlusGuide's text loader instead, so
	check the two agree: the same steps, carrying the same tags. ]]
for _, faction in ipairs({ "Alliance", "Horde" }) do
	for _, g in ipairs({ "Alchemy", "Cooking", "First Aid", "Mining" }) do
		load(g .. " (1-300)", faction)
		local text = P.guides[g .. " (1-300)"]()
		local n, same = 0, true
		for line in string.gfind(text, "[^\n]+") do
			n = n + 1
			local _, _, tags = string.find(line, "^%a [^|]*(.*)$")
			if tags ~= P.tags[n] then same = false end
		end
		check(same and n == table.getn(P.actions),
			"%s %s: the loader carries the same %d steps and tags (got %d)", faction, g,
			table.getn(P.actions), n)
	end
end

-- Level gates ----------------------------------------------------------------------

local LEVELS = { Apprentice = 5, Journeyman = 10, Expert = 20, Artisan = 35 }
local GATED = { "Alchemy", "Blacksmithing", "Enchanting", "Jewelcrafting", "Leatherworking", "Tailoring" }

for _, faction in ipairs({ "Alliance", "Horde" }) do
	for _, prof in ipairs(GATED) do
		load(prof .. " (1-300)", faction)
		for rank, lvl in pairs(LEVELS) do
			local t = find("^" .. (rank == "Apprentice" and "Learn " or "Train " .. rank .. " ") .. prof)
			check(t ~= nil, "%s %s: the %s training step is there", faction, prof, rank)
			if t then
				check(P.actions[t - 1] == "GRIND" and tonumber(tag("LV", t - 1)) == lvl,
					"%s %s: %s waits for level %d first, got %s LV %s", faction, prof, rank, lvl,
					tostring(P.actions[t - 1]), tostring(tag("LV", t - 1)))
				check(string.find(tag("N", t), "level " .. lvl, 1, true) ~= nil,
					"%s %s: and the %s step says so", faction, prof, rank)
			end
		end
	end
end

-- Gathering, Cooking, First Aid and Survival have no rank levels.
for _, prof in ipairs({ "Mining", "Cooking", "First Aid", "Survival" }) do
	load(prof .. " (1-300)")
	local gates = {}
	for i = 1, table.getn(P.actions) do
		local lv = tonumber(tag("LV", i))
		if lv then table.insert(gates, lv) end
	end
	local ok = true
	for _, lv in ipairs(gates) do if lv ~= 40 then ok = false end end
	check(ok, "%s has no rank level gates (the Artisan quest's 40 aside), got %s",
		prof, table.concat(gates, ","))
end

-- Who, where, and what it costs ---------------------------------------------------------

load("Alchemy (1-300)", "Alliance")
local expert = find("^Train Expert Alchemy")
check(expert and tag("N", expert) == "Needs skill 125 and level 20; costs 50 silver. Trainers: "
	.. "Kylanna Windwhisper (Feralas), Ainethil (Darnassus), Sylvanna Forestmoon (Darnassus).",
	"the step names the rank's needs, its cost and your faction's trainers, got '%s'",
	tostring(expert and tag("N", expert)))
local names = expert and tag("NPC", expert)
check(names and names[2] == "Ainethil" and table.getn(names) == 3,
	"and carries their names for the waypoint")
local prof, cap = tag("RANK", expert)
check(prof == "Alchemy" and cap == 225, "and the cap it completes on, got %s %s", tostring(prof), tostring(cap))
check(find("Doctor Herbert Halsey") == nil and find("^Train Expert Alchemy", expert + 1) == nil,
	"only one Expert step, and no Horde trainers for an Alliance character")

load("Alchemy (1-300)", "Horde")
expert = find("^Train Expert Alchemy")
check(expert and string.find(tag("N", expert), "Doctor Herbert Halsey (Undercity)", 1, true),
	"a Horde character gets the Horde trainers")

-- The reference document lists no Alliance Expert blacksmith; the FAQ does.
load("Blacksmithing (1-300)", "Alliance")
expert = find("^Train Expert Blacksmithing")
check(expert and tag("NPC", expert) and tag("NPC", expert)[1] == "Bengus Deepforge",
	"the Alliance Expert blacksmith comes from the FAQ, got %s",
	tostring(expert and tag("NPC", expert) and tag("NPC", expert)[1]))

-- Every training step, in every guide, for both factions, has somewhere to go.
for _, faction in ipairs({ "Alliance", "Horde" }) do
	for _, g in ipairs({ "Alchemy", "Blacksmithing", "Enchanting", "Jewelcrafting", "Leatherworking",
		"Tailoring", "Mining", "Cooking", "First Aid", "Survival" }) do
		load(g .. " (1-300)", faction)
		for i = 1, table.getn(P.actions) do
			if P.actions[i] == "TRAIN" then
				check(tag("RANK", i) ~= nil and tag("NPC", i) ~= nil,
					"%s %s step %d names trainers and a cap", faction, g, i)
			end
		end
	end
end

-- Secondary professions: a tome, then a quest ------------------------------------------------

load("Cooking (1-300)", "Alliance")
check(find("^Train Expert Cooking") == nil and find("^Train Artisan Cooking") == nil,
	"Cooking does not train Expert or Artisan at a trainer")
local book = find("^Buy Expert Cookbook")
check(book and P.actions[book] == "BUY" and tag("NPC", book)[1] == "Shandrina",
	"Expert is a tome from Shandrina for the Alliance")
check(book and select(2, tag("RANK", book)) == 225, "and it completes when the cap reaches 225")
load("Cooking (1-300)", "Horde")
book = find("^Buy Expert Cookbook")
check(book and tag("NPC", book)[1] == "Wulan", "Wulan sells it to the Horde")

-- The Artisan quest sits at 225: it needs 225, and nothing past 225 is
-- reachable without it. The step crossing 225 is split there.
load("Cooking (1-300)", "Alliance")
local gate = find("^Reach level 40")
check(gate and tonumber(tag("LV", gate)) == 40, "the Artisan quest waits for level 40")
local _, _, before = tag("SKILL", gate - 1)
local _, after = tag("SKILL", find("Mithril Head Trout", gate))
check(before == 225 and after == 225,
	"between the halves of the step that crosses 225, got up to %s and from %s",
	tostring(before), tostring(after))
check(find("^Start the Artisan Cooking quest") and tag("NPC", find("^Start the Artisan Cooking quest"))[1]
	== "Daryl Riknussun", "Daryl Riknussun starts it for the Alliance")
local gather = find("^Gather for Dirge Quikcleave")
check(gather and string.find(tag("MATS", gather), "12x Giant Egg", 1, true),
	"and what Dirge wants is on the materials list")
local hand = find("^Hand in to Dirge Quikcleave")
check(hand and select(2, tag("RANK", hand)) == 300, "handing in completes at the Artisan cap")

load("First Aid (1-300)", "Horde")
hand = find("^Hand in to Doctor Gregory Victor")
check(hand ~= nil, "First Aid's Horde Artisan quest ends with Doctor Gregory Victor")
check(find("Doctor Gustaf VanHowzen") == nil, "not the Alliance doctor")

-- Completing on the numbers ---------------------------------------------------------------

--[[ A level-1 character with no professions: the guide stops at the first
	level gate and waits there. ]]
skills, level = {}, 1
load("Alchemy (1-300)", "Alliance")
readIntro()
P:UpdateStatusFrame()
check(P.actions[P.current] == "GRIND" and tonumber(tag("LV", P.current)) == 5,
	"a level-1 character waits at 'Reach level 5', got step %d %s", P.current, tostring(P.quests[P.current]))

level = 12
P:UpdateStatusFrame()
check(string.find(P.quests[P.current], "^Learn Alchemy"), "at 12 it moves on to learning Alchemy, got %s",
	tostring(P.quests[P.current]))

-- Learning Apprentice (cap 75) completes the step; so does the skill.
setSkill("Alchemy", 1, 75)
P:UpdateStatusFrame()
check(string.find(P.quests[P.current], "^Craft"), "learning it completes the step, got %s",
	tostring(P.quests[P.current]))

-- A character who comes to the guide already at 140 with Journeyman goes
-- straight past everything they have done, to the Expert rank's gate.
load("Alchemy (1-300)", "Alliance")
readIntro()
setSkill("Alchemy", 140, 150)
level = 15
P:UpdateStatusFrame()
check(P.actions[P.current] == "GRIND" and tonumber(tag("LV", P.current)) == 20,
	"at skill 140, level 15 the guide is waiting for level 20, got %s", tostring(P.quests[P.current]))
level = 25
P:UpdateStatusFrame()
check(string.find(P.quests[P.current], "^Train Expert Alchemy"), "and at 25, on Expert training, got %s",
	tostring(P.quests[P.current]))
setSkill("Alchemy", 140, 225)
P:UpdateStatusFrame()
check(string.find(P.quests[P.current], "^Craft"), "training Expert (cap 225) completes it, got %s",
	tostring(P.quests[P.current]))

-- A gathering step waits for its skill; it used to count as done on arrival.
-- (At 140 with a 150 cap the guide stops at Expert training first, which
-- comes before the node mining; this miner has trained it.)
load("Mining (1-300)", "Alliance")
readIntro()
setSkill("Mining", 140, 225)
level = 60
P:UpdateStatusFrame()
check(P.actions[P.current] == "GRIND" and tag("SKILL", P.current),
	"Mining at 140 stops at the node-mining step, got %s", tostring(P.quests[P.current]))
setSkill("Mining", 155, 225)
P:UpdateStatusFrame()
check(P.actions[P.current] ~= "GRIND" or select(3, tag("SKILL", P.current)) ~= 155,
	"and moves on once the skill reaches its target")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("ProfessionSteps: %d checks", checks))
if table.getn(failures) == 0 then
	print("All profession step checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
