--[[
	The dungeon guides (Guides/Dungeons/, written by
	Tools/build/build_dungeon_guides.py), through the real parser.

	A dungeon guide is picked from the guide list: it picks up the dungeon's
	quests, puts the arrow on the entrance, and hands everything in after.
	This checks that each one is current with its generator, is listed in its
	side's Guides.xml, parses, has a travel step to the entrance the arrow can
	point at, and leaves no loose ends: nothing handed in before it is picked
	up, nothing picked up and never handed in, no objective before its quest.
	Windhorn Canyon, patch 1.18.1's dungeon, has its quests on both sides.

	Run:  lua5.1 Tools/tests/test_dungeonguides.lua
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
local registered = {}
function AegisPathfinder:RegisterGuide(name, nextzone, faction, loader)
	self.guides[name] = loader
	table.insert(self.guidelist, name)
	table.insert(registered, { name = name, nextzone = nextzone, faction = faction, loader = loader })
end

dofile("Parser.lua")
function AegisPathfinder:SmartSkipToStep() end
function AegisPathfinder:WarmCaches() end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local rc = os.execute("python3 Tools/build/build_dungeon_guides.py --check > /dev/null")
check(rc == 0, "Guides/Dungeons/ is out of date: run python3 Tools/build/build_dungeon_guides.py")

local guides = {}          -- name -> { faction, text }
for _, side in ipairs({ "Alliance", "Horde" }) do
	local listed = {}
	for file in string.gfind(io.open("Guides/Dungeons/" .. side .. "/Guides.xml"):read("*a"), '<Script file="([^"]+)"/>') do
		listed[file] = true
	end
	for path in io.popen("ls Guides/Dungeons/" .. side .. "/*.lua"):lines() do
		local _, _, file = string.find(path, "([^/]+)$")
		check(listed[file], "%s is not in %s's Guides.xml", path, side)
		local before = table.getn(registered)
		dofile(path)
		local g = registered[before + 1]
		check(table.getn(registered) == before + 1, "%s registers one guide", path)
		if g then
			check(string.find(g.name, "^Dungeons/.+ %(%d+%-%d+%)$"), "%s: a dungeon guide's name, got %s", path, g.name)
			check(g.faction == side, "%s: registered for %s, got %s", path, side, tostring(g.faction))
			check(g.nextzone == nil, "%s: a dungeon guide leads nowhere after", path)
			guides[g.name .. "@" .. side] = { name = g.name, side = side, text = g.loader() }
		end
	end
end

-- The zones the guides name.
local zones = {}
for _, g in pairs(guides) do
	for zone in string.gfind(g.text, "|Z|([^|]+)|") do zones[zone] = true end
end

local n = 0
for _, g in pairs(guides) do
	n = n + 1
	-- The raw steps, in order.
	local accepted, handed, entrance = {}, {}, false
	local _, _, title = string.find(g.name, "^Dungeons/(.+) %(")
	for line in string.gfind(g.text, "[^\n]+") do
		local _, _, action, rest = string.find(line, "^(%a) (.*)$")
		local _, _, qid = string.find(line, "|QID|(%d+)|")
		local optional = string.find(line, "|O|", 1, true)
		-- Every point in a note goes on the step's own zone's map: another
		-- zone is named, never given a place (the Searing Gorge's way into
		-- Blackrock Mountain was put in the Burning Steppes).
		check(not string.find(line, "also in [^|]*%(%d"), "%s (%s): a point in another zone: %s", g.name, g.side, line)
		local _, _, here = string.find(line, "|Z|([^|]+)|")
		for zone in pairs(zones) do
			if zone ~= here and string.find(line, zone .. " %(%d") then
				check(false, "%s (%s): a point in %s on %s's map: %s", g.name, g.side, zone, tostring(here), line)
			end
		end
		if action == "R" and string.find(line, "|Z|", 1, true) and string.find(line, "%(%d+%.?%d*, %d+%.?%d*%)|") then
			entrance = true
		end
		if qid then
			if action == "A" then
				accepted[qid] = optional and "optional" or "yes"
			elseif action == "C" then
				check(accepted[qid], "%s (%s): objectives of %s before it is picked up", g.name, g.side, qid)
			elseif action == "T" then
				check(accepted[qid] or optional, "%s (%s): %s handed in before it is picked up", g.name, g.side, qid)
				handed[qid] = true
			end
		end
	end
	check(entrance, "%s (%s): no travel step with a zone and a point for the arrow", g.name, g.side)
	for qid, how in pairs(accepted) do
		check(handed[qid] or how == "optional", "%s (%s): %s is picked up and never handed in", g.name, g.side, qid)
	end
	-- Through the parser: every step shows, none dropped for a filter.
	AegisPathfinder.db.char.currentguide = nil
	AegisPathfinder.db.char.PlayStyle = "GROUP"
	AegisPathfinder:LoadGuide(g.name)
	check(AegisPathfinder.quests and table.getn(AegisPathfinder.quests) > 5,
		"%s (%s) parses, got %d steps", g.name, g.side, AegisPathfinder.quests and table.getn(AegisPathfinder.quests) or 0)
end
check(n == 42, "a guide per dungeon and side, Ragefire Chasm the Horde's only and the Stockade the Alliance's: 42, got %d", n)

-- Windhorn Canyon, 1.18.1's dungeon.
local function has(key, qid)
	return guides[key] and string.find(guides[key].text, "|QID|" .. qid .. "|", 1, true) ~= nil
end
local WHC = "Dungeons/Windhorn Canyon (26-30)"
check(has(WHC .. "@Alliance", 41976), "In Search of Tauren Relics, from Ironforge")
for _, qid in ipairs({ 41977, 41978, 41982, 41939 }) do
	check(has(WHC .. "@Horde", qid), "Windhorn Canyon's Horde quest %d", qid)
end
check(guides[WHC .. "@Horde"] and string.find(guides[WHC .. "@Horde"].text,
	"R Windhorn Canyon |N|[^|]*%(64%.6, 45%.9%)| |Z|Thousand Needles|"), "the arrow goes to the Windhorn Caverns in Thousand Needles")
check(guides[WHC .. "@Horde"] and string.find(guides[WHC .. "@Horde"].text,
	"A Vortalus.- Edict |QID|41939|[^\n]*|C|Shaman|"), "Vortalus' Edict is the Shaman's")

-- The bosses ------------------------------------------------------------------------

C_Timer.NewTicker = function() end
GetMapContinents = function() return "Kalimdor", "Eastern Kingdoms" end
GetMapZones = function(c) if c == 1 then return "Durotar" end return "Elwynn Forest" end
dofile("Locale.lua")
AegisPathfinder.Locale = AEGISPATHFINDER_LOCALE
dofile("Theme.lua")
dofile("QuestTracker.lua")

-- Steps ticked by hand: three dwarves dying in any order, a family, an arena.
local BY_HAND = { ["The Lost Dwarves"] = true, ["Harlow Family"] = true, ["Farraki Arena"] = true }
local bosses = 0
for _, g in pairs(guides) do
	local _, _, title = string.find(g.name, "^Dungeons/(.+) %(")
	local inside, first = false, true
	for line in string.gfind(g.text, "[^\n]+") do
		if string.find(line, "^R ") and string.find(line, "|N|", 1, true) and not string.find(line, "|QID|", 1, true)
			and string.find(line, "^R [^|]+ |N|[^|]*%(%d") then
			inside = inside or not string.find(line, "Travel to", 1, true)
		end
		local _, _, boss = string.find(line, "^K ([^|]-) |")
		if boss then
			bosses = bosses + 1
			if first then
				check(inside, "%s (%s): %s comes before the way in", g.name, g.side, boss)
				first = false
			end
			check(string.find(line, "|N|[^|]+|"), "%s (%s): %s has no note", g.name, g.side, boss)
			check(BY_HAND[boss] or string.find(line, "|BOSS|[^|]+|"), "%s (%s): %s has no death to tick it", g.name,
				g.side, boss)
			for tag in string.gfind(line, "|(%u+)|") do
				check(tag ~= "TANKS" and tag ~= "HEALER" and tag ~= "DAMAGE", "%s: a role tag misspelt: %s", boss, tag)
			end
		end
	end
	check(not first, "%s (%s): no boss steps", g.name, g.side)
end
check(bosses > 300, "a step for each boss, both sides: got %d", bosses)

local DM = guides["Dungeons/The Deadmines (17-24)@Alliance"]
check(DM and string.find(DM.text, "\nK Edwin VanCleef |[^\n]*\nC The Defias Brotherhood |QID|166|"),
	"Kill Edwin VanCleef follows his step, on the visit the quest sends you in")
check(DM and string.find(DM.text, "K Miner Johnson |N|Rare: not always here%.[^\n]*|O|"),
	"a rare boss is optional, and says it may not be there")

-- A trip to a town is for whoever its quests are for. Darnassus, for
-- Shadowfang Keep, is one Priest, Mage, Warlock and Druid quest that needs
-- another first: everyone was sent there, from Stormwind, and back.
do
	local SFK = guides["Dungeons/Shadowfang Keep (22-30)@Alliance"]
	local text = SFK and SFK.text or ""
	local sw, dn = string.find(text, "\nR Stormwind City "), string.find(text, "\nR Darnassus ")
	check(sw and dn and sw < dn, "Shadowfang Keep goes to Stormwind first")
	check(string.find(text, "R Darnassus |N|Travel to Darnassus| |Z|Darnassus| |C|Priest/Mage/Warlock/Druid| |O| |PRE|41377|",
		1, true), "and to Darnassus only for its quest's classes, once its first quest is done")
	for line in string.gfind(text, "[^\n]+") do
		if string.find(line, "^R Stormwind City") then
			check(not string.find(line, "|C|", 1, true), "Stormwind is for everyone: %s", line)
		end
	end
end

-- Both sides register under one name; load the Alliance guide.
local function load(name)
	for _, g in ipairs(registered) do
		if g.name == name and g.faction == "Alliance" then AegisPathfinder.guides[name] = g.loader end
	end
	AegisPathfinder.db.char.currentguide = nil
	AegisPathfinder:LoadGuide(name)
end

-- A Warrior's Shadowfang Keep has no trip to Darnassus at all.
load("Dungeons/Shadowfang Keep (22-30)")
do
	local trips = {}
	for i, name in ipairs(AegisPathfinder.quests) do
		if AegisPathfinder.actions[i] == "RUN" then table.insert(trips, (string.gsub(name, "@%d+@$", ""))) end
	end
	check(table.concat(trips, ", ") == "Stormwind City, Shadowfang Keep, Stormwind City",
		"a Warrior's trips: Stormwind, the keep, Stormwind; got %s", table.concat(trips, ", "))
end

-- What the step says for each role.
load("Dungeons/The Deadmines (17-24)")
local smite, cookie
for i, name in ipairs(AegisPathfinder.quests) do
	-- The parser keeps each step's title as "Title@index@".
	name = string.gsub(name, "@%d+@$", "")
	if name == "Mr. Smite" then smite = i elseif name == "Jared Voss" then cookie = i end
end
check(smite, "the Deadmines has Mr. Smite's step")
if smite then
	local function says(role)
		AegisPathfinder.db.char.dungeonrole = role
		local note = AegisPathfinder:GetStepNote(smite) or ""
		return string.find(note, "Tank:|r", 1, true) ~= nil, string.find(note, "Healer:|r", 1, true) ~= nil,
			string.find(note, "Damage:|r", 1, true) ~= nil, note
	end
	local t, h, d, note = says("all")
	check(t and h and d and string.find(note, "^At two%-thirds"), "all roles: the note, then a line each, got %s", note)
	t, h, d = says("tank")
	check(t and not h and not d, "the tank's alone")
	t, h, d = says("heal")
	check(h and not t and not d, "the healer's alone")
	t, h, d = says("dps")
	check(d and not t and not h, "damage dealers' alone")
	AegisPathfinder.db.char.dungeonrole = "all"
end
check(cookie and AegisPathfinder:GetStepNote(cookie) == "Pathfinder has no notes on this fight yet.",
	"a boss with no notes: the note alone")

-- A boss's death ticks its step.
UNITDIESOTHER = "%s dies."
check(AegisPathfinder:DeathName("Mr. Smite dies.") == "Mr. Smite", "who died, from the combat log")
check(AegisPathfinder:DeathName("You have slain Mr. Smite!") == "Mr. Smite", "or your own killing blow")
check(AegisPathfinder:DeathName("Mr. Smite is slain by Thrall!") == "Mr. Smite", "or a party member's")
check(AegisPathfinder:DeathName("Ok'thor the Breaker dies.") == "Ok'thor the Breaker", "a name with an apostrophe")
check(AegisPathfinder:DeathName("You die.") == nil and AegisPathfinder:DeathName("Mr. Smite hits you for 20.") == nil,
	"and nothing from other lines")
local ticked = {}
local realTick = AegisPathfinder.SetTurnedIn
function AegisPathfinder:SetTurnedIn(i) table.insert(ticked, i) end
AegisPathfinder.turnedin = AegisPathfinder.turnedin or {}
AegisPathfinder:CHAT_MSG_COMBAT_HOSTILE_DEATH("Defias Pirate dies.")
check(table.getn(ticked) == 0, "a trash mob's death ticks nothing")
AegisPathfinder:CHAT_MSG_COMBAT_HOSTILE_DEATH("You have slain Mr. Smite!")
check(ticked[1] == smite, "Mr. Smite's death ticks his step, got %s", tostring(ticked[1]))
ticked = {}
load("Dungeons/Blackrock Depths (52-60)")
AegisPathfinder.turnedin = AegisPathfinder.turnedin or {}
local seven
for i, name in ipairs(AegisPathfinder.quests) do
	if string.gsub(name, "@%d+@$", "") == "The Seven" then seven = i end
end
AegisPathfinder:CHAT_MSG_COMBAT_HOSTILE_DEATH("Dope'rel dies.")
check(table.getn(ticked) == 0, "the first of the Seven dying ticks nothing")
AegisPathfinder:CHAT_MSG_COMBAT_HOSTILE_DEATH("Doom'rel dies.")
check(seven and ticked[1] == seven, "Doom'rel, the last, ticks the Seven's step")
AegisPathfinder.SetTurnedIn = realTick

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("Dungeon guides: %d checks", checks))
if table.getn(failures) == 0 then
	print("All dungeon guide checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
