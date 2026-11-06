--[[
	The class quest guides (Guides/Class/, written by
	Tools/build/build_class_guides.py), through the real parser, as each
	race of each class sees them.

	A class quest guide is one chain -- the Voidwalker, Bear Form, the
	Charger -- and each race sees its own way through it: an Undead
	warlock's Voidwalker is Carendin Halgar's in the Undercity, an Orc's Gan'rul
	Bloodeye's in Orgrimmar. What the offer knows of each (the level, the
	quests, the last one) comes from the same file.

	Run:  lua5.1 Tools/tests/test_classguides.lua
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
local registered, milestones = {}, {}
function AegisPathfinder:RegisterGuide(name, nextzone, faction, loader)
	self.guides[name] = loader
	table.insert(self.guidelist, name)
	table.insert(registered, { name = name, nextzone = nextzone, faction = faction, loader = loader })
end
function AegisPathfinder:RegisterClassMilestones(side, class, list)
	for _, m in ipairs(list) do
		table.insert(milestones, { side = side, class = class, guide = m.guide, group = m.group, races = m.races })
	end
end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local rc = os.execute("python3 Tools/build/build_class_guides.py --check > /dev/null")
check(rc == 0, "Guides/Class/ is out of date: run python3 Tools/build/build_class_guides.py")

local CLASSES = { Warrior = "WARRIOR", Paladin = "PALADIN", Hunter = "HUNTER", Rogue = "ROGUE", Priest = "PRIEST",
	Shaman = "SHAMAN", Mage = "MAGE", Warlock = "WARLOCK", Druid = "DRUID" }
local guides = {}          -- name@side -> { name, side, class, text }
for _, side in ipairs({ "Alliance", "Horde" }) do
	local listed = {}
	for file in string.gfind(io.open("Guides/Class/" .. side .. "/Guides.xml"):read("*a"), '<Script file="([^"]+)"/>') do
		listed[file] = true
	end
	for path in io.popen("ls Guides/Class/" .. side .. "/*.lua"):lines() do
		local _, _, file, class = string.find(path, "(([^/]+)%.lua)$")
		check(listed[file], "%s is not in %s's Guides.xml", path, side)
		local before, mbefore = table.getn(registered), table.getn(milestones)
		dofile(path)
		check(table.getn(registered) > before, "%s registers its guides", path)
		for i = before + 1, table.getn(registered) do
			local g = registered[i]
			check(string.find(g.name, "^Class/" .. class .. ": .+ %(%d+%)$"), "%s: a class guide's name, got %s", path, g.name)
			check(g.faction == side, "%s: registered for %s, got %s", path, side, tostring(g.faction))
			check(g.nextzone == nil, "%s: a class guide leads nowhere after", path)
			guides[g.name .. "@" .. side] = { name = g.name, side = side, class = class, text = g.loader(), loader = g.loader }
		end
		-- And what the offer needs of each, one each.
		check(table.getn(milestones) - mbefore == table.getn(registered) - before,
			"%s: a milestone for each guide", path)
		for i = mbefore + 1, table.getn(milestones) do
			local m = milestones[i]
			check(m.side == side and m.class == CLASSES[class], "%s: milestones for %s %s, got %s %s",
				path, side, class, tostring(m.side), tostring(m.class))
			check(guides[m.guide .. "@" .. side], "%s: the milestone's guide %s is registered", path, m.guide)
		end
	end
end

-- Each race's view, through the parser: UnitClass and UnitRace are read as
-- Parser.lua loads, so it is loaded again for each.
local function view(g, race)
	UnitClass = function() return g.class, CLASSES[g.class] end
	UnitRace = function() return race, race end
	dofile("Parser.lua")
	function AegisPathfinder:SmartSkipToStep() end
	function AegisPathfinder:WarmCaches() end
	-- Both sides' guides go by one name; the game registers only yours.
	AegisPathfinder.guides[g.name] = g.loader
	AegisPathfinder.db.char.currentguide = nil
	AegisPathfinder.db.char.PlayStyle = "GROUP"
	AegisPathfinder:LoadGuide(g.name)
	local steps = {}
	for i, action in ipairs(AegisPathfinder.actions or {}) do
		local tag = AegisPathfinder.tags[i] or ""
		local _, _, qid = string.find(tag, "|QID|(%d+)|")
		table.insert(steps, { action = action, qid = tonumber(qid), optional = string.find(tag, "|O|", 1, true) ~= nil,
			zone = string.find(tag, "|Z|", 1, true) ~= nil, tag = tag })
	end
	return steps
end

-- Every point in a note goes on the step's own zone's map: another zone is
-- named, never given a place; a way in has one place.
local zones = {}
for _, g in pairs(guides) do
	for zone in string.gfind(g.text, "|Z|([^|]+)|") do zones[zone] = true end
end
for key, g in pairs(guides) do
	for line in string.gfind(g.text, "[^\n]+") do
		check(not string.find(line, "also in [^|]*%(%d"), "%s: a point in another zone: %s", key, line)
		local _, _, here = string.find(line, "|Z|([^|]+)|")
		for zone in pairs(zones) do
			if zone ~= here and string.find(line, zone .. " %(%d") then
				check(false, "%s: a point in %s on %s's map: %s", key, zone, tostring(here), line)
			end
		end
		if string.find(line, "^[RF] ") then
			local _, points = string.gsub(line, "%(%d+%.?%d*, %d+%.?%d*%)", "")
			check(points <= 1, "%s: one place to go, got %d: %s", key, points, line)
		end
	end
end

local n, views = 0, 0
local seen = {}
for _, m in ipairs(milestones) do
	local g = guides[m.guide .. "@" .. m.side]
	seen[m.guide .. "@" .. m.side] = true
	n = n + 1
	for race, r in pairs(m.races) do
		views = views + 1
		local who = string.format("%s (%s %s)", m.guide, m.side, race)
		local steps = g and view(g, race) or {}
		check(r.level >= 4 and r.level <= 60, "%s: a level to offer it at, got %s", who, tostring(r.level))
		local accepted, done, did, qids = {}, {}, {}, {}
		for _, s in ipairs(steps) do
			if s.qid then
				qids[s.qid] = true
				if s.action == "ACCEPT" then
					accepted[s.qid] = s.optional and "optional" or "yes"
				elseif s.action == "COMPLETE" then
					check(accepted[s.qid], "%s: objectives of %d before it is picked up", who, s.qid)
					did[s.qid] = true
				elseif s.action == "TURNIN" then
					check(accepted[s.qid] or s.optional, "%s: %d handed in before it is picked up", who, s.qid)
					done[s.qid] = true
				end
			end
		end
		for qid, how in pairs(accepted) do
			check(done[qid] or how == "optional", "%s: %d is picked up and never handed in", who, qid)
		end
		-- The race's chain, and none of another race's.
		local mine = {}
		for _, qid in ipairs(r.quests) do
			mine[qid] = true
			check(accepted[qid] == "yes", "%s: %d is in its chain and not picked up", who, qid)
		end
		for qid in pairs(qids) do
			check(mine[qid] or accepted[qid] == "optional", "%s: %d is not in its chain", who, qid)
		end
		check(done[r.last], "%s: its last quest, %d, is handed in", who, r.last)
		local last = steps[table.getn(steps)]
		check(last and last.action == "TURNIN" and last.qid == r.last, "%s: the guide ends handing in %d, so it finishes by itself",
			who, r.last)
	end
end
for key in pairs(guides) do
	check(seen[key], "%s has no milestone to offer it", key)
end
check(n > 120, "a guide per milestone and side, got %d", n)

-- Some of them, as they should be.
local function races(guide, side)
	for _, m in ipairs(milestones) do
		if m.guide == guide and m.side == side then return m.races, m end
	end
	return {}
end
local function has(r, race, qid)
	for _, q in ipairs(r[race] and r[race].quests or {}) do
		if q == qid then return true end
	end
	return false
end

local void = races("Class/Warlock: Voidwalker (10)", "Horde")
check(has(void, "Orc", 1501) and has(void, "Orc", 1504) and not has(void, "Orc", 1473),
	"an Orc's Voidwalker is Gan'rul Bloodeye's, in Orgrimmar")
check(has(void, "Undead", 1473) and has(void, "Undead", 1471) and not has(void, "Undead", 1501),
	"an Undead's is Carendin Halgar's, in the Undercity")
check(has(void, "Goblin", 1501) and void.Goblin and void.Goblin.level == 10, "a Goblin's goes to Orgrimmar too")
local goblin = guides["Class/Warlock: Voidwalker (10)@Horde"]
check(goblin and string.find(goblin.text, "A Dabbling In Darkness |QID|41201|[^\n]*|O|[^\n]*|R|Goblin|"),
	"Dabbling In Darkness, from Blackstone Island, is the Goblin's way there, and can be missed")

local charger, cm = races("Class/Paladin: Charger (60)", "Alliance")
check(cm.group and charger.Human and charger.Dwarf and charger["High Elf"] and charger.Human.last == 7647,
	"the Charger: a group chain, for Humans, Dwarves and High Elves, ending with Judgment and Redemption")
local ch = guides["Class/Paladin: Charger (60)@Alliance"]
local feed = ch and string.find(ch.text, "T Manna%-Enriched Horse Feed |QID|7645|")
local spirit = ch and string.find(ch.text, "C Ancient Equine Spirit |QID|7643|")
check(feed and spirit and feed < spirit, "the horse feed is handed in before the spirit is fed")
check(ch and string.find(ch.text, "R Scholomance |N|[^|]*%(69, 72%.7%)| |Z|Western Plaguelands|"),
	"and the arrow goes to Scholomance's door for Darkreaver")

local taming = races("Class/Hunter: Taming the Beast (10)", "Alliance")
check(has(taming, "Dwarf", 6064) and has(taming, "Night Elf", 6063) and has(taming, "Gnome", 80340)
	and has(taming, "High Elf", 41177) and has(taming, "Human", 41131),
	"Taming the Beast: each Alliance race its own, Turtle WoW's included")
local th = guides["Class/Hunter: Taming the Beast (10)@Alliance"]
check(th and string.find(th.text, "C Taming the Beast |QID|6064|[^\n]*|U|15911|"),
	"the Taming Rod is the step's item, to use from the Active Items button")

local racial = races("Class/Priest: Racial Spell (10)", "Alliance")
check(has(racial, "Night Elf", 5627) and has(racial, "Human", 5634) and not racial.Gnome,
	"a priest's racial spell: the Night Elf's Starshards from Darnassus, the Human's Desperate Prayer from Stormwind")

local aquatic = races("Class/Druid: Aquatic Form (16)", "Alliance")
check(has(aquatic, "Night Elf", 26) and not has(aquatic, "Night Elf", 27),
	"A Lesson to Learn from Darnassus is the Night Elf's, though CMaNGOS names the Tauren")

-- Below 20, a quest given in the starting zone and in the city is picked up
-- in the starting zone: a level-10 Human warrior is in Elwynn Forest.
local ds = guides["Class/Warrior: Defensive Stance (10)@Alliance"]
check(ds and string.find(ds.text, "A A Warrior's Training |QID|1638| |N|Lyria Du Lac [^\n]*|Z|Elwynn Forest|")
	and not string.find(ds.text, "Ilsa Corbin", 1, true),
	"A Warrior's Training is picked up from Lyria Du Lac in Goldshire, not Ilsa Corbin in Stormwind")
check(ds and string.find(ds.text, "T A Warrior's Training |QID|1638| |N|Harry Burlguard [^\n]*|Z|Stormwind City|"),
	"and handed in to Harry Burlguard in Stormwind")
local uzzek = guides["Class/Warrior: Defensive Stance (10)@Horde"]
check(uzzek and string.find(uzzek.text, "A Veteran Uzzek |QID|1505| |N|Tarshaw Jaggedscar [^\n]*|Z|Durotar|"),
	"Veteran Uzzek from Razor Hill's trainer, on the way to the Barrens")
-- One NPC on two maps stays on the city's: Elanaria is in Darnassus.
local elura = guides["Class/Warrior: Warrior's Weapon (10)@Alliance"]
check(elura and string.find(elura.text, "A The Shade of Elura |QID|1686| |N|Elanaria [^\n]*|Z|Darnassus|"),
	"Elanaria is named in Darnassus, not on Teldrassil's map")

local _, rhok = races("Class/Hunter: Rhok'delar (60)", "Horde")
check(rhok.group, "Rhok'delar needs a group")

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("Class guides: %d checks, %d guides, %d race views", checks, n, views))
if table.getn(failures) == 0 then
	print("All class guide checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for i, f in ipairs(failures) do
	if i > 60 then print(string.format("  ... and %d more", table.getn(failures) - 60)) break end
	print("  - " .. f)
end
os.exit(1)
