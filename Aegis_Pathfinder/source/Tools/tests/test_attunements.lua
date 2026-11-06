--[[
	Tests for the attunement guides (Guides/Attunements/, written by
	Tools/build/build_attunement_guides.py): what each side gets, that each
	guide's steps hold together, and how the guide browser files them, says
	when you are attuned, pictures them and suggests them.

	Run:  lua5.1 Tools/tests/test_attunements.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
local level = 58
UnitLevel = function() return level end
UnitClass = function() return "Warrior", "WARRIOR" end
GetTime = function() return 1000 end
GetMoney = function() return 0 end
date = function() return "2026-10-03" end

AegisPathfinder = {
	guides = {}, guidelist = {}, qsplusguides = {}, myfaction = "Alliance",
	db = { char = {
		completion = {}, completedquestsbyid = {}, favorites = {}, recentguides = {}, leveltime = {}, gold = {},
		Dungeons = {}, tabs = {}, activetab = 1,
	}, profile = {} },
}
local A = AegisPathfinder
function A:Debug() end
function A:Print() end
function A:IsRoutePackGuide() return false end
function A:GuideZone() return nil end
function A:IsQuestCompletedOnServer(q) return self.db.char.completedquestsbyid[tonumber(q)] == true end

-- Core.lua is far too large to load under the stub: lift the guide
-- categories and badges out of it.
local core = io.open("Core.lua"):read("*a")
do
	local a = string.find(core, "-- Turtle WoW custom zones for categorization", 1, true)
	local b = string.find(core, "---------------------------------\n--      Route Functions", a or 1, true)
	assert(a and b, "could not find the guide categories in Core.lua")
	assert(loadstring(string.sub(core, a, b - 1)))()
end

A.objectiveframe = CreateFrame("Frame", nil, UIParent)
dofile("Theme.lua")
dofile("GuideBrowser.lua")
dofile("MapOverlays.lua")
dofile("GuidePictures.lua")
local Browser = A.Browser

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local rc = os.execute("python3 Tools/build/build_attunement_guides.py --check > /dev/null")
check(rc == 0, "Guides/Attunements/ is out of date: run python3 Tools/build/build_attunement_guides.py")

-- Each side's file, read as the client would: only that side's guides kept.
local texts = {}
local function load_side(side)
	A.myfaction = side
	A.guides, A.guidelist = {}, {}
	function A:RegisterGuide(name, _, faction, fn)
		if faction ~= "Both" and faction ~= self.myfaction then return end
		self.guides[name] = fn
		table.insert(self.guidelist, name)
		texts[side .. "@" .. name] = fn()
	end
	dofile("Guides/Attunements/" .. side .. "/Attunements.lua")
end

local WANT = {
	Alliance = { "Molten Core", "Onyxia's Lair", "Blackwing Lair", "Naxxramas", "Emerald Sanctum",
		"Lower Karazhan Halls", "Tower of Karazhan", "Upper Blackrock Spire", "Scholomance",
		"Blackrock Depths", "Karazhan Crypts" },
}
WANT.Horde = WANT.Alliance

for _, side in ipairs({ "Alliance", "Horde" }) do
	load_side(side)
	local list = Browser.ATTUNEMENTS[side] or {}
	check(table.getn(list) == 11, "%s: eleven attunements, got %d", side, table.getn(list))
	local opens = {}
	for _, a in ipairs(list) do
		opens[a.instance] = a
		local name = a.guide
		check(A.guides[name] ~= nil, "%s: %s is a guide", side, name)
		check(A:GetGuideCategory(name) == "attunement", "%s: %s is an attunement", side, name)
		check(a.kind == "raid" or a.kind == "dungeon", "%s: %s is a raid or a dungeon", side, name)
		local lo = A:ParseGuideLevelRange(name)
		check(lo == a.level, "%s: %s's name carries its level, %s", side, name, tostring(lo))
		-- Every attuning quest is handed in on the guide; each quest is
		-- picked up before it is handed in.
		local text = texts[side .. "@" .. name] or ""
		local accepted, handed = {}, {}
		for line in string.gfind(text, "[^\n]+") do
			local _, _, act, qid = string.find(line, "^([ACT]) .-|QID|(%d+)|")
			if act == "A" then accepted[qid] = true end
			if act == "T" then
				check(accepted[qid], "%s: %s hands in %s before picking it up", side, name, qid)
				handed[qid] = true
			end
		end
		check(handed[tostring(a.attuned[1])], "%s: %s hands in %d, its last quest", side, name, a.attuned[1])
		check(string.find(text, "^%s*N [^\n]-|N|Opens " .. a.instance) ~= nil, "%s: %s says what it opens first", side, name)
	end
	for _, instance in ipairs(WANT[side]) do
		check(opens[instance] ~= nil, "%s: a guide for %s", side, instance)
	end
end

-- Each side's own chain where they differ.
check(texts["Alliance@Attunement/Onyxia's Lair: Drakefire Amulet (48)"]
	and string.find(texts["Alliance@Attunement/Onyxia's Lair: Drakefire Amulet (48)"], "Highlord Bolvar Fordragon (78.2, 18)| |Z|Stormwind City|", 1, true),
	"Bolvar is in Stormwind Keep, not on Northwind's map")
local hkey = texts["Horde@Attunement/Lower Karazhan Halls: The Key to Karazhan (58)"] or ""
local akey = texts["Alliance@Attunement/Lower Karazhan Halls: The Key to Karazhan (58)"] or ""
check(string.find(hkey, "|QID|40822|", 1, true) and not string.find(hkey, "|QID|40819|", 1, true),
	"the Horde's Key to Karazhan takes its own part III")
check(string.find(akey, "|QID|41136|", 1, true) and not string.find(akey, "|QID|40820|", 1, true),
	"the Alliance's takes the parts IV and V someone still gives")
local schol = texts["Alliance@Attunement/Scholomance: The Key to Scholomance (50)"] or ""
local calls = 0
for _ in string.gfind(schol, "A A Call to Arms: The Plaguelands![^\n]*") do calls = calls + 1 end
check(calls == 1, "one A Call to Arms, not one from each city, got %d", calls)
check(string.find(texts["Horde@Attunement/Onyxia's Lair: Blood of the Black Dragon Champion (55)"] or "",
	"|QID|6584|", 1, true), "the Horde's Onyxia takes all three Tests of Skulls")
check(string.find(texts["Alliance@Attunement/Emerald Sanctum: Into the Dream (58)"] or "", "Ralathius", 1, true),
	"Into the Dream starts with Ralathius")

-- The browser ---------------------------------------------------------------

load_side("Alliance")
local mc = "Attunement/Molten Core: Attunement to the Core (55)"
local ony = "Attunement/Onyxia's Lair: Drakefire Amulet (48)"
local brd = "Attunement/Blackrock Depths: Shadowforge Key (48)"
check(A:GuideBadge(mc) == "at" and select(2, A:GuideBadge(mc)) == "AT", "an attunement's badge is AT")
check(A:BrowserCategoryOf(mc) == "dungeons", "it is filed under Dungeons")

local folder
for _, item in ipairs(A:BrowserCategory("dungeons").items) do
	if item.folder and item.folder.title == Browser.ACCESS then folder = item.folder end
end
check(folder ~= nil, "Dungeons has the Attunements and keys folder")
local order, why = {}, {}
for _, item in ipairs(folder and folder.items or {}) do
	table.insert(order, item.guide)
	why[item.guide] = item.why
end
check(order[1] == ony and why[ony] == "Raid", "raids first, by level: Onyxia's Lair from 48, got %s", tostring(order[1]))
check(why[brd] == "Dungeon", "a dungeon's key says so")
local lastRaid, firstDungeon = 0, 99
for i, g in ipairs(order) do
	local a = A:AttunementInfo(g)
	if a and a.kind == "raid" then lastRaid = i end
	if a and a.kind == "dungeon" and i < firstDungeon then firstDungeon = i end
end
check(lastRaid < firstDungeon, "every raid before every dungeon")

-- Attuned once the last quest is handed in; Naxxramas by any of its three.
check(not A:IsAttuned(mc), "not attuned to start with")
A.db.char.completedquestsbyid[7848] = true
check(A:IsAttuned(mc), "attuned once Attunement to the Core is handed in")
local naxx = "Attunement/Naxxramas: The Dread Citadel (60)"
A.db.char.completedquestsbyid[9123] = true
check(A:IsAttuned(naxx), "Naxxramas: the Exalted version counts too")
for _, item in ipairs(A:BrowserCategory("dungeons").items) do
	if item.folder and item.folder.title == Browser.ACCESS then
		for _, g in ipairs(item.folder.items) do why[g.guide] = g.why end
	end
end
check(why[mc] == "Attuned", "and the folder says Attuned, got %s", tostring(why[mc]))

-- The picture is what it opens.
local p = A:GuidePicture(brd)
check(p.kind == "screen" and p.texture == A.Theme.loadscreen["Blackrock Depths"],
	"Shadowforge Key shows Blackrock Depths' loading screen")
check(A:GuidePicture(mc).kind == "screen", "a raid without a loading screen yet shows the default one")

-- Suggestions: one you started, and the first you can start.
A.db.char.completion[ony] = 0.3
local todo = A:AttunementsToDo(58)
check(todo[1] and todo[1].guide == ony and string.find(todo[1].why, "started", 1, true),
	"one you started comes first, got %s", todo[1] and todo[1].guide or "none")
check(todo[2] and todo[2].guide == brd, "then the lowest one you can start, got %s", todo[2] and todo[2].guide or "none")
check(table.getn(todo) == 2, "and no more, got %d", table.getn(todo))
check(table.getn(A:AttunementsToDo(40)) == 0, "nothing below every attunement's level")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Attunements: %d checks", checks))
if table.getn(failures) == 0 then
	print("All attunement checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
