--[[
	The Moonwhisper Coast guides, through the real parser.

	They are written by Tools/build/build_zone_guide.py from pfQuest-turtle's data,
	not by hand, so this checks what the writer promises: each side gets its
	own quests and not the other's; every quest step has a quest id, a zone
	and somewhere to go; a quest is picked up before its objectives and its
	objectives done before it is handed in; a quest that follows another comes
	after the other's hand-in -- the Moro'gai story, the Horde's trips to
	Azshara and Mulgore and back; the quest log never runs past its 20; the
	quests you may not have are optional; group quests and what follows them
	are in Group mode only, and so is a trip made for them alone; and the zone
	is a custom zone, so
	the guide list files it under Custom and Where next? offers it.

	Run:  lua5.1 Tools/tests/test_zoneguide.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

C_Timer = { After = function() end }
C_QuestLog = { RequestLoadQuestByID = function() end, GetNumQuestObjectives = function() return nil end }
C_Item = { RequestLoadItemDataByID = function() end }

AegisPathfinder = {
	guides = {}, guidelist = {}, nextzones = {}, factions = {},
	db = { char = { completion = {}, turnins = {}, Dungeons = {}, PlayStyle = "GROUP", UseAH = true },
		profile = {} },
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
local registered = {}
function AegisPathfinder:RegisterGuide(name, nextzone, faction, loader)
	registered[table.getn(registered) + 1] = { name = name, nextzone = nextzone, faction = faction }
	self.guides[faction .. "/" .. name] = loader
	table.insert(self.guidelist, faction .. "/" .. name)
end

dofile("Parser.lua")
function AegisPathfinder:SmartSkipToStep() end
function AegisPathfinder:WarmCaches() end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, unpack(arg))) end
end

local COORD = "%(([%d.]+),%s?([%d.]+)%)"
local NAME = "Moonwhisper Coast (52-60)"

dofile("Guides/Alliance/52_60_Moonwhisper_Coast.lua")
dofile("Guides/Horde/52_60_Moonwhisper_Coast.lua")

-- Registered once a side, and in each side's list of guides.
check(table.getn(registered) == 2, "two guides, got %d", table.getn(registered))
for _, r in ipairs(registered) do
	check(r.name == NAME, "named %s, got %s", NAME, r.name)
	check(r.nextzone == "Winterspring (59-60)", "then Winterspring, got %s", tostring(r.nextzone))
end
for _, side in ipairs({ "Alliance", "Horde" }) do
	local xml = io.open("Guides/" .. side .. "/Guides.xml"):read("*a")
	check(string.find(xml, '<Script file="52_60_Moonwhisper_Coast.lua"/>', 1, true),
		"%s's Guides.xml loads it", side)
end

-- A custom zone: Core.lua's list names it, so the guide list files it under
-- Custom and Where next? (NextGuideFrame.lua) offers it at 51 to 59.
do
	local src = io.open("Core.lua"):read("*a")
	local _, _, block = string.find(src, "local TURTLE_ZONES = (%b{})")
	check(block and string.find(block, '["Moonwhisper Coast"] = true', 1, true), "Moonwhisper Coast is a custom zone")
end

-- Each side, parsed, in Group mode unless it says Solo.
local function load(side, style)
	local char = AegisPathfinder.db.char
	char.currentguide, char.PlayStyle = nil, style or "GROUP"
	AegisPathfinder:LoadGuide(side .. "/" .. NAME)
	local steps = {}
	for i, action in ipairs(AegisPathfinder.actions) do
		local tag = function(t) return AegisPathfinder:GetObjectiveTag(t, i) end
		steps[i] = {
			action = action, name = (string.gsub(AegisPathfinder.quests[i], "@.*@", "")), qid = tonumber((tag("QID"))),
			note = tag("N"), zone = tag("Z"), optional = tag("O") and true or false, race = tag("R"),
		}
	end
	return steps
end

local function first(steps, action, qid)
	for i, s in ipairs(steps) do
		if s.action == action and s.qid == qid then return i end
	end
end

local sides = {}
sides.Alliance = load("Alliance")
sides.Horde = load("Horde")
local solo = {}
solo.Alliance = load("Alliance", "SOLO")
solo.Horde = load("Horde", "SOLO")

-- Group or solo, the same holds.
local all = {}
for side, steps in pairs(sides) do all[side] = steps end
for side, steps in pairs(solo) do all[side .. " solo"] = steps end
for side, steps in pairs(all) do
	check(table.getn(steps) > 100, "%s: a whole zone's steps, got %d", side, table.getn(steps))

	-- Every quest step has an id, a zone and somewhere to go.
	local quests, log, most = {}, {}, 0
	for i, s in ipairs(steps) do
		if s.action == "ACCEPT" or s.action == "COMPLETE" or s.action == "TURNIN" then
			check(s.qid, "%s step %d (%s) has a quest id", side, i, s.name)
			check(s.zone and s.zone ~= "", "%s step %d (%s) names its zone", side, i, s.name)
			check(s.note and string.find(s.note, COORD), "%s step %d (%s) has somewhere to go", side, i, s.name)
			if s.qid then quests[s.qid] = true end
		end
		-- The log, counting the quests everyone has: never past its 20.
		if s.qid and not s.optional then
			if s.action == "ACCEPT" then log[s.qid] = true end
			if s.action == "TURNIN" then log[s.qid] = nil end
			local n = 0
			for _ in pairs(log) do n = n + 1 end
			if n > most then most = n end
		end
	end
	check(most <= 20, "%s: the quest log holds %d at most, got %d", side, 20, most)

	-- Picked up, done, handed in -- in that order.
	for qid in pairs(quests) do
		local a, c, t = first(steps, "ACCEPT", qid), first(steps, "COMPLETE", qid), first(steps, "TURNIN", qid)
		check(a, "%s: quest %d is picked up", side, qid)
		check(t, "%s: quest %d is handed in", side, qid)
		if a and c then check(a < c, "%s: quest %d picked up before its objectives", side, qid) end
		if c and t then check(c < t, "%s: quest %d's objectives before its hand-in", side, qid) end
		if a and t then check(a < t, "%s: quest %d picked up before it is handed in", side, qid) end
	end
end

-- Which side's quests: Sunsworn Camp and Narvalis Point are the Alliance's,
-- Moonhoof Village and Moonhoof Retreat the Horde's, Moro'gai Village both.
local A, H = sides.Alliance, sides.Horde
check(first(A, "ACCEPT", 42064) and not first(H, "ACCEPT", 42064), "Blackroot Hold (Sunsworn Camp) is the Alliance's")
check(first(A, "ACCEPT", 42088) and not first(H, "ACCEPT", 42088), "An'she's Respite (Narvalis Point) is the Alliance's")
check(first(H, "ACCEPT", 41993) and not first(A, "ACCEPT", 41993), "Hiding in the Shade (Moonhoof Village) is the Horde's")
check(first(H, "ACCEPT", 42081) and not first(A, "ACCEPT", 42081), "An Opportune Arrival (Moonhoof Retreat) is the Horde's")
check(first(A, "ACCEPT", 41920) and first(H, "ACCEPT", 41920), "Fallen One Cargo (Moro'gai Village) is both sides'")

-- A quest that follows another comes after the other's hand-in.
local function after(steps, side, pre, qid)
	local t, a = first(steps, "TURNIN", pre), first(steps, "ACCEPT", qid)
	check(t and a and t < a, "%s: %d is picked up after %d is handed in", side, qid, pre)
end
for side, steps in pairs(sides) do
	for qid = 41911, 41917 do after(steps, side, qid - 1, qid) end   -- the Moro'gai story
	after(steps, side, 41898, 41899)
end
after(A, "Alliance", 42088, 42089)
after(A, "Alliance", 42089, 42090)
after(A, "Alliance", 42095, 42096)
after(H, "Horde", 42049, 42050)                 -- to Duke Hydraxis in Azshara and back
after(H, "Horde", 42070, 42071)                 -- to Mulgore
after(H, "Horde", 42071, 42072)
after(H, "Horde", 42074, 42080)
after(H, "Horde", 42080, 42075)
after(H, "Horde", 42076, 42077)

-- The Horde's trips: Azshara and back, Mulgore and back, each a RUN there and
-- one home, the quests' hand-ins in that zone between.
local function trip(steps, zone)
	local out, back
	for i, s in ipairs(steps) do
		if s.action == "RUN" and s.name == zone then out = i end
		if out and not back and i > out and s.action == "RUN" and s.name == "Moonwhisper Coast" then back = i end
	end
	return out, back
end
local out, back = trip(H, "Azshara")
check(out and back and out < first(H, "TURNIN", 42049) and first(H, "ACCEPT", 42050) < back,
	"Horde: to Azshara for Duke Hydraxis and back")
out, back = trip(H, "Mulgore")
check(out and back and out < first(H, "TURNIN", 42070) and first(H, "ACCEPT", 42072) < back,
	"Horde: to Mulgore for Baine and Cairne Bloodhoof and back")
check(H[first(H, "TURNIN", 42071)].zone == "Mulgore", "Cairne's hand-in is in Mulgore")
check(first(H, "TURNIN", 42020) > out and first(H, "TURNIN", 42020) < back,
	"Brother's Duty, handed in in Mulgore, goes with that trip rather than one of its own")

-- Group quests -- the ones the owner chose, and everything that follows from
-- them -- are not in the solo guide; the rest is.
local GROUP = {
	Alliance = { 42090, 42091, 42097, 42092, 41953 },
	Horde = { 41994, 41995, 42070, 42072, 42075, 42076, 42077, 42078, 41953 },
}
for side, qids in pairs(GROUP) do
	for _, qid in ipairs(qids) do
		check(first(sides[side], "ACCEPT", qid), "%s: quest %d is in the group guide", side, qid)
		check(not first(solo[side], "ACCEPT", qid) and not first(solo[side], "TURNIN", qid),
			"%s: quest %d is not in the solo guide", side, qid)
	end
end
check(first(solo.Alliance, "ACCEPT", 42088) and first(solo.Alliance, "ACCEPT", 42089),
	"Alliance solo: An'she's Respite and Scales of the Tideblade, before Serpents Without Heads, stay")
check(first(solo.Horde, "ACCEPT", 41993), "Horde solo: Hiding in the Shade, before Shade Mother, stays")
local function has(steps, zone)
	for _, s in ipairs(steps) do
		if s.action == "RUN" and s.name == zone then return true end
	end
end
check(has(sides.Alliance, "Teldrassil") and not has(solo.Alliance, "Teldrassil"),
	"Alliance: the trip to Teldrassil is for Word to the High Priestess alone, so not solo")
check(has(solo.Horde, "Mulgore") and first(solo.Horde, "TURNIN", 42020),
	"Horde solo: the Mulgore trip stays, for Brother's Duty")

-- Quests you may not have are optional: picked up on the way here, or with no
-- one on record as giving them. The ones everyone gets are not.
check(A[first(A, "ACCEPT", 42061)].optional, "Sunsworn Expedition, from Alah'Thalas, is optional")
check(A[first(A, "TURNIN", 42061)].optional, "and so is its hand-in")
check(H[first(H, "ACCEPT", 41973)].optional, "Contracts in Moonwhisper Coast, from Tel'Abim, is optional")
check(H[first(H, "ACCEPT", 41974)].optional, "and so is what follows only from it")
check(A[first(A, "ACCEPT", 41918)].optional, "Silken Song, which no one gives, is optional")
check(not A[first(A, "ACCEPT", 41920)].optional, "Fallen One Cargo is not")

-- A quest for one race: shown to that race only.
-- The parser reads your race as it loads, so it loads again for each.
local function as(race)
	UnitRace = function() return race, race end
	dofile("Parser.lua")
	function AegisPathfinder:SmartSkipToStep() end
	function AegisPathfinder:WarmCaches() end
	return load("Horde")
end
local tauren, orc = as("Tauren"), as("Orc")
check(first(tauren, "ACCEPT", 42079), "Secrets of Moonwhisper is shown to a Tauren")
check(not first(orc, "ACCEPT", 42079), "and not to an Orc")

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("ZoneGuide: %d checks", checks))
if table.getn(failures) == 0 then
	print("All zone guide checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
