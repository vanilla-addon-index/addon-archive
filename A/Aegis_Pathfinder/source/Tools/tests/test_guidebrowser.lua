--[[
	Tests for the guide browser: what it lists (GuideBrowser.lua), the
	guides' pictures (GuidePictures.lua) and the window (GuideListFrame.lua).

	Run:  lua5.1 Tools/tests/test_guidebrowser.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
local level = 21
UnitLevel = function() return level end
UnitClass = function() return "Warlock", "WARLOCK" end
local shift = false
IsShiftKeyDown = function() return shift end
local money = 0
GetMoney = function() return money end
local now = 1000
GetTime = function() return now end
local today, week = "2026-10-01", "2026-39"
date = function(fmt) return fmt == "%Y-%m-%d" and today or week end

AegisPathfinder = {
	guides = {}, guidelist = {}, qsplusguides = {},
	db = { char = {
		completion = {}, turnins = {}, favorites = {}, recentguides = {}, leveltime = {}, gold = {},
		browsertab = "home", browsercolour = true, browserticks = true, browserhidedone = false,
		browserstars = false, browserpanels = {}, Dungeons = { DM = true, SFK = true }, tabs = {},
		activetab = 1, currentguide = "Optimized/Redridge (18-20)",
	}, profile = {} },
}
local A = AegisPathfinder
function A:Debug() end
function A:Print() end
function A.GetQuadrant() return "TOPRIGHT", "TOP", "RIGHT" end
function A:IsRoutePackGuide() return false end
function A:GuideZone() return nil end
function A:IsMyClassGuide(name) return string.find(name, "^Class/Warlock") ~= nil end

-- The tabs and route pack, recorded.
local opened, loaded, packs, config = {}, {}, {}, 0
function A:EnsureTabs() return self.db.char.tabs end
function A:OpenGuideTab(name) table.insert(opened, name) end
function A:LoadGuideInTab(name) table.insert(loaded, name) end
function A:SelectRoutePack(name) table.insert(packs, name); self.db.char.routepack = name end
function A:ToggleConfigPanel() config = config + 1 end
function A:ReturnFromBranch() self.db.char.isbranching = false end
-- What fits: stand-ins for the route, the class quests and the custom zones.
function A:GetRouteSuccessor(guide) return guide == "Optimized/Redridge (18-20)" and "Optimized/Darkshore (20-21)" or nil end
local milestonesAsked
function A:GetClassMilestones(lvl, browsing)
	milestonesAsked = browsing
	return lvl >= 20 and { { guide = "Class/Warlock: Succubus (20)", level = 20 } } or {}
end
function A:GetCustomZoneChoices(lvl) return lvl >= 20 and { { guide = "Northwind (28-34)" } } or {} end

-- Core.lua is far too large to load under the stub: lift the guide
-- categories, badges and level ranges out of it.
local core = io.open("Core.lua"):read("*a")
do
	local a = string.find(core, "-- Turtle WoW custom zones for categorization", 1, true)
	local b = string.find(core, "---------------------------------\n--      Route Functions", a or 1, true)
	assert(a and b, "could not find the guide categories in Core.lua")
	assert(loadstring(string.sub(core, a, b - 1)))()
end
A.NO_GUIDE = "No Guide"

local function guide(name, text)
	A.guides[name] = function() return text or "" end
	table.insert(A.guidelist, name)
end
guide("Optimized/Redridge (18-20)")
guide("Optimized/Darkshore (20-21)")
guide("Optimized/Elwynn Forest (1-10)")
guide("RXP/1-6 Coldridge Valley")
guide("RXP/12-14 Loch Modan")
guide("RXP_Hardcore/Durotar (1-12)")
guide("Westfall (12-17)")
guide("Darkshore (12-17)")
guide("Bandit Hideouts (30-32)", "N Go|Z|Stranglethorn Vale|\nC Kill|Z|Stranglethorn Vale|\nC Loot|Z|Duskwood|\n")
guide("Northwind (28-34)")
guide("Thalassian Highlands (1-10)")
guide("Dungeons/The Deadmines (17-24)")
guide("Dungeons/Shadowfang Keep (22-30)")
guide("Dungeons/Scarlet Monastery (34-45)")
guide("Dungeons/Windhorn Canyon (26-30)")
guide("Class/Warlock: Voidwalker (10)")
guide("Class/Warlock: Succubus (20)")
guide("Class/Mage: Level 10 Quest (10)")
guide("Class/Warlock: Enchanted Gold Bloodrobe (31)")
guide("Tailoring (1-300)")
A.qsplusguides["Tailoring (1-300)"] = { category = "Profession", steps = {} }
guide("Fishing (1-300)")
A.qsplusguides["Fishing (1-300)"] = { category = "Profession", template = true, steps = {} }
A.DUNGEON_INFO = { { code = "DM", name = "The Deadmines" }, { code = "SFK", name = "Shadowfang Keep" },
	{ code = "SM", name = "Scarlet Monastery" }, { code = "ULDA", name = "Uldaman" } }
A.TURTLE_DUNGEON_INFO = { { code = "WHC", name = "Windhorn Canyon" } }

A.objectiveframe = CreateFrame("Frame", nil, UIParent)
dofile("Theme.lua")
dofile("GuideBrowser.lua")
dofile("MapOverlays.lua")
dofile("GuidePictures.lua")
dofile("GuideListFrame.lua")

local Browser, Pictures, Theme = A.Browser, A.Pictures, A.Theme

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
-- A script run as the client runs it: `this` the frame, `arg1` the button.
local function fire(f, script, a1)
	this, arg1 = f, a1
	f:GetScript(script)()
end
local function click(f, button) fire(f, "OnClick", button or "LeftButton") end
local function titles(folder)
	local out = {}
	for _, item in ipairs(folder.items) do table.insert(out, item.folder and item.folder.title or item.guide) end
	return table.concat(out, ", ")
end
local function find(folder, title)
	for _, item in ipairs(folder.items) do
		if item.folder and item.folder.title == title then return item.folder end
	end
end

-- Categories and folders ----------------------------------------------------------

local leveling = A:BrowserCategory("leveling")
check(titles(leveling) == "Optimized, RestedXP, RestedXP Hardcore, Zone guides, Custom zones",
	"Leveling's folders, the packs first, got %s", titles(leveling))
check(titles(find(leveling, "Optimized")) == "Optimized/Elwynn Forest (1-10), Optimized/Redridge (18-20), Optimized/Darkshore (20-21)",
	"a pack's guides by level, got %s", titles(find(leveling, "Optimized")))
local zones = find(leveling, "Zone guides")
check(titles(zones) == "Eastern Kingdoms, Kalimdor", "zone guides by continent, got %s", titles(zones))
check(titles(find(zones, "Eastern Kingdoms")) == "Westfall (12-17), Bandit Hideouts (30-32)",
	"Eastern Kingdoms, got %s", titles(find(zones, "Eastern Kingdoms")))
check(titles(find(zones, "Kalimdor")) == "Darkshore (12-17)", "Kalimdor, got %s", titles(find(zones, "Kalimdor")))
check(titles(find(leveling, "Custom zones")) == "Thalassian Highlands (1-10), Northwind (28-34)",
	"the custom zones, got %s", titles(find(leveling, "Custom zones")))

check(A:GuideBrowserZone("RXP/1-6 Coldridge Valley") == "Dun Morogh", "a place in a zone is that zone")
check(A:GuideBrowserZone("Optimized/Elwynn Forest (1-10)") == "Elwynn Forest", "a zone in the title")
check(A:GuideBrowserZone("Bandit Hideouts (30-32)") == "Stranglethorn Vale",
	"no zone in the title: the one most steps are in, got %s", tostring(A:GuideBrowserZone("Bandit Hideouts (30-32)")))
check(A:GuideBrowserZone("Tailoring (1-300)") == nil, "and none for a guide in no zone")

check(titles(A:BrowserCategory("dungeons")) == "Dungeons/The Deadmines (17-24), Dungeons/Shadowfang Keep (22-30), "
	.. "Dungeons/Windhorn Canyon (26-30), Dungeons/Scarlet Monastery (34-45)", "dungeons by level")
check(titles(A:BrowserCategory("class")) == "Class/Warlock: Voidwalker (10), Class/Warlock: Succubus (20), "
	.. "Class/Warlock: Enchanted Gold Bloodrobe (31)", "only your class's quests, got %s", titles(A:BrowserCategory("class")))
check(titles(A:BrowserCategory("professions")) == "Fishing (1-300), Tailoring (1-300)", "professions by name")
check(table.getn(A:BrowserCategory("favorites").items) == 0, "no favourites yet")
check(table.getn(A:BrowserCategory("reputations").items) == 0, "a category coming soon is empty")

-- A pack too long to read is split by level.
for i = 1, 30 do guide(string.format("Optimized/Filler %02d (%d-%d)", i, i * 2, i * 2 + 1)) end
local banded = find(A:BrowserCategory("leveling"), "Optimized")
check(titles(banded) == "Levels 1-20, Levels 20-40, Levels 40-60", "a long folder in bands, got %s", titles(banded))
check(table.getn(find(banded, "Levels 1-20").items) == 11, "a guide in the band it starts in, got %d",
	table.getn(find(banded, "Levels 1-20").items))
for i = 1, 30 do
	local name = string.format("Optimized/Filler %02d (%d-%d)", i, i * 2, i * 2 + 1)
	A.guides[name] = nil
	table.remove(A.guidelist)
end

-- Search, favourites, recent ------------------------------------------------------

local found = A:BrowserSearch("dARK")
check(table.concat(found, ", ") == "Darkshore (12-17), Optimized/Darkshore (20-21)",
	"search any case, sorted by title, got %s", table.concat(found, ", "))
check(table.getn(A:BrowserSearch("")) == 0, "nothing typed, nothing found")
check(table.getn(A:BrowserSearch("Mage")) == 0, "another class's quests are not found")

check(A:ToggleFavoriteGuide("Westfall (12-17)") == true and A:IsFavoriteGuide("Westfall (12-17)"), "star a guide")
check(titles(A:BrowserCategory("favorites")) == "Westfall (12-17)", "it is in Favorites")
check(A:ToggleFavoriteGuide("Westfall (12-17)") == false and not A:IsFavoriteGuide("Westfall (12-17)"), "and unstar it")

A:NoteRecentGuide("Westfall (12-17)")
A:NoteRecentGuide("Dungeons/The Deadmines (17-24)")
A:NoteRecentGuide("Westfall (12-17)")
A:NoteRecentGuide("No Guide")
check(table.concat(A:RecentGuides(), ", ") == "Westfall (12-17), Dungeons/The Deadmines (17-24)",
	"the last opened first, once each, got %s", table.concat(A:RecentGuides(), ", "))
for i = 1, 40 do A:NoteRecentGuide("Gone " .. i) end
check(table.getn(A.db.char.recentguides) == Browser.RECENT_MAX, "kept to %d", Browser.RECENT_MAX)
check(table.getn(A:RecentGuides()) == 0, "and a guide no longer there is not listed")
A.db.char.recentguides = {}
check(string.find(io.open("Parser.lua"):read("*a"), "self:NoteRecentGuide(self.db.char.currentguide)", 1, true) ~= nil,
	"loading a guide notes it")

-- What fits ----------------------------------------------------------------------

local function guides(list)
	local out = {}
	for _, s in ipairs(list) do table.insert(out, s.guide .. " [" .. s.why .. "]") end
	return table.concat(out, "; ")
end
A.db.char.tabs = { { guide = "Optimized/Redridge (18-20)", step = 4 } }
check(guides(A:BrowserSuggestions()) == "Optimized/Darkshore (20-21) [Next on your route]; "
	.. "Class/Warlock: Succubus (20) [A class quest at your level]; "
	.. "Dungeons/The Deadmines (17-24) [A ticked dungeon at your level]; "
	.. "Dungeons/Shadowfang Keep (22-30) [A ticked dungeon at your level]; "
	.. "Northwind (28-34) [A custom zone at your level]", "the suggestions, got %s", guides(A:BrowserSuggestions()))
check(milestonesAsked == true, "class quests already offered are still suggested")
A.db.char.completion["Dungeons/The Deadmines (17-24)"] = 1
check(string.find(guides(A:BrowserSuggestions()), "Deadmines", 1, true) == nil, "not a finished dungeon")
A.db.char.completion["Dungeons/The Deadmines (17-24)"] = nil
A.db.char.SelfFound = true
check(table.getn(A:DungeonGuidesAtLevel(21)) == 0, "no dungeons in Solo Self-Found")
A.db.char.SelfFound = nil
check(table.concat(A:DungeonGuidesAtLevel(16), ", ") == "Dungeons/The Deadmines (17-24)",
	"a dungeon from a level short of it")
check(A:IsSuggestedGuide("Northwind (28-34)") and not A:IsSuggestedGuide("Westfall (12-17)"), "IsSuggestedGuide")

check(A:GuideDifficulty("Westfall (12-17)", 21) == "grey", "outlevelled is grey")
check(A:GuideDifficulty("Optimized/Darkshore (20-21)", 21) == "green", "in range is green")
check(A:GuideDifficulty("Dungeons/Shadowfang Keep (22-30)", 21) == "yellow", "a level short is yellow")
check(A:GuideDifficulty("Northwind (28-34)", 24) == "orange", "four short is orange")
check(A:GuideDifficulty("Northwind (28-34)", 21) == "red", "seven short is red")
check(A:GuideDifficulty("Tailoring (1-300)", 21) == nil, "a profession's range is its skill: no colour")
check(A:IsGuideDoneWith("Westfall (12-17)", 21) and not A:IsGuideDoneWith("Northwind (28-34)", 21),
	"outlevelled is done with")
A.db.char.completion["Northwind (28-34)"] = 1
check(A:IsGuideDoneWith("Northwind (28-34)", 21), "and so is finished")
A.db.char.completion["Northwind (28-34)"] = nil

-- The trackers ----------------------------------------------------------------------

A:TrackerEvent("PLAYER_ENTERING_WORLD")
now = now + 600
local times = A:LevelTimes()
check(times[1].level == 21 and times[1].seconds == 600 and times[1].current, "level 21 counting up: 10 minutes")
now = now + 60
do
	-- The Extras page's level-up announcement asks for the level just left,
	-- before or after the tracker banks it.
	local secs, whole = A:TimeAtLevel(21)
	check(secs == 660 and not whole, "21 so far, before the bank: 11 minutes, not counted from its start")
end
A:TrackerEvent("PLAYER_LEVEL_UP", 22)
level = 22
check(A:TimeAtLevel(21) == 660, "and the same after it")
now = now + 30
times = A:LevelTimes()
check(times[1].level == 22 and times[1].seconds == 30 and times[2].level == 21 and times[2].seconds == 660,
	"a level up banks the last level, got %s/%s", tostring(times[2] and times[2].seconds), tostring(times[1].seconds))
do
	local secs, whole = A:TimeAtLevel(22)
	check(secs == 30 and whole, "22, begun while counting: 30 seconds, all of it")
	check(A:TimeAtLevel(30) == nil, "a level not reached: no time")
end
A:TrackerEvent("PLAYER_LOGOUT")
check(A.db.char.leveltime[22] == 30, "logging out banks the level you are at")
check(Browser.Duration(4320) == "1h 12m" and Browser.Duration(3520) == "58m 40s" and Browser.Duration(40) == "40s",
	"durations, got %s %s %s", Browser.Duration(4320), Browser.Duration(3520), Browser.Duration(40))

money = 50000
A:TrackerEvent("PLAYER_ENTERING_WORLD")
money = 84112
A:TrackerEvent("PLAYER_MONEY")
money = 80000
A:TrackerEvent("PLAYER_MONEY")
local t, w = A:GoldEarned()
check(t == 34112 and w == 34112, "gold earned, spending not taken off: got %d, %d", t, w)
today = "2026-10-02"
check((A:GoldEarned()) == 0, "a new day starts at nothing")
money = 80100
A:TrackerEvent("PLAYER_MONEY")
t, w = A:GoldEarned()
check(t == 100 and w == 34212, "and the week goes on, got %d, %d", t, w)
local coins = Browser.Coins(34112)
check(coins[1][1] == "3" and coins[1][2] == "g" and coins[2][1] == "41" and coins[3][1] == "12", "3g 41s 12c")
check(table.getn(Browser.Coins(99)) == 1 and Browser.Coins(0)[1][1] == "0", "copper only")

-- Pictures ----------------------------------------------------------------------------

local function pic(name) return A:GuidePicture(name) end
check(pic("Optimized/Darkshore (20-21)").kind == "map" and pic("Optimized/Darkshore (20-21)").map == "Darkshore",
	"a zone guide is its map")
check(pic("RXP/1-6 Coldridge Valley").map == "DunMorogh", "by the zone a place is in")
-- A custom zone is Turtle WoW's own map of it, which the addon carries:
-- built from its tiles and pfUI's overlays, they came out wrong in game.
check(pic("Northwind (28-34)").kind == "image" and pic("Northwind (28-34)").texture == A.Theme.zonemap["Northwind"],
	"a custom zone is the map the addon carries")
do
	local _, _, list = string.find(core, "local TURTLE_ZONES = (%b{})")
	local n = 0
	for zone in string.gfind(list or "", '%["([^"]+)"%]%s*=%s*true') do
		n = n + 1
		-- "Gillijims Isle" is only another spelling of a title's.
		check(zone == "Gillijims Isle" or A.Theme.zonemap[zone], "%s has its map", zone)
	end
	check(n >= 14, "every custom zone is checked, got %d", n)
end
check(pic("Dungeons/Scarlet Monastery (34-45)").texture == A.Theme.loadscreen["Scarlet Monastery"]
	and pic("Dungeons/Scarlet Monastery (34-45)").coords == Pictures.ART_COORDS,
	"a dungeon guide is Turtle WoW's loading screen for it, the addon's, shown whole")
check(pic("Dungeons/Windhorn Canyon (26-30)").texture == A.Theme.loadscreen["Windhorn Canyon"],
	"a Turtle WoW dungeon's too")
-- One the addon had no art for would be the client's generic screen, cropped
-- to its art.
do
	local art = A.Theme.loadscreen["Shadowfang Keep"]
	A.Theme.loadscreen["Shadowfang Keep"] = nil
	check(pic("Dungeons/Shadowfang Keep (22-30)").texture == "Interface\\Glues\\LoadingScreens\\LoadScreenDungeon"
		and pic("Dungeons/Shadowfang Keep (22-30)").coords == Pictures.SCREEN_COORDS,
		"one the addon has no art for: the client's generic screen, cropped to its art")
	A.Theme.loadscreen["Shadowfang Keep"] = art
end
-- Every dungeon the setup or the Dungeons page knows has its picture.
do
	local src = io.open("SetupFrame.lua"):read("*a") .. io.open("OptionsFrame.lua"):read("*a")
	local missing, seen = {}, 0
	for name in string.gfind(src, 'code = "[%w]+",%s*name = "([^"]+)"') do
		seen = seen + 1
		-- The Dungeons page says "Deadmines"; its guide, "The Deadmines".
		if name ~= "Deadmines" and not A.Theme.loadscreen[name] then
			table.insert(missing, name)
		end
	end
	check(seen >= 22, "the dungeon lists are read, got %d", seen)
	check(table.getn(missing) == 0, "every dungeon has its loading screen, missing %s", table.concat(missing, ", "))
end
local vw = pic("Class/Warlock: Voidwalker (10)")
check(vw.kind == "class" and vw.class == "WARLOCK" and vw.icon == "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
	"a class quest: the crest and the chain's spell")
check(pic("Class/Warlock: Enchanted Gold Bloodrobe (31)").icon == "Interface\\Icons\\Spell_Shadow_ShadowBolt",
	"or the class's own icon")
check(pic("Tailoring (1-300)").icon == "Interface\\Icons\\Trade_Tailoring", "a profession its icon")
check(pic(nil).kind == "logo" and pic("Nope").kind == "logo", "nothing is the logo")
guide("Optimized/Uldaman (45-46)", "A Go|Z|Ironforge|\n")
check(pic("Optimized/Uldaman (45-46)").texture == A.Theme.loadscreen["Uldaman"],
	"a route leg named for a dungeon is its loading screen, not the city it starts in")
-- And it is listed with the dungeons, not among the route's zones.
check(titles(find(A:BrowserCategory("leveling"), "Optimized")) == "Optimized/Elwynn Forest (1-10), "
	.. "Optimized/Redridge (18-20), Optimized/Darkshore (20-21)", "not in the pack's folder, got %s",
	titles(find(A:BrowserCategory("leveling"), "Optimized")))
local dungeons = A:BrowserCategory("dungeons")
local legs = dungeons.items[1].folder
check(legs and legs.title == Browser.ROUTE_LEGS and legs.items[1].guide == "Optimized/Uldaman (45-46)"
	and legs.items[1].why == "Optimized", "but first under Dungeons, saying whose route it is on")
check(dungeons.items[2].guide == "Dungeons/The Deadmines (17-24)", "before the dungeon guides")
check(A:BrowserCategoryOf("Optimized/Uldaman (45-46)") == "dungeons", "and Recent files it there too")
check(Browser.DungeonIn("RXP/Scholomance Key (A)") == "Scholomance" and Browser.DungeonIn("Westfall (12-17)") == nil,
	"the later dungeons and raids are known by name too")
-- A pack's attunement or key has no level range: it was filed under Levels
-- 1-20. It has a folder of its own under Dungeons, after the route runs.
guide("RXP/Onyxia Attunement (A)", "A Dragonkin Menace|Z|Burning Steppes|\n")
guide("RXP/Scholomance Key (A)", "A Go|Z|Western Plaguelands|\n")
local withAccess = A:BrowserCategory("dungeons")
local access = withAccess.items[2] and withAccess.items[2].folder
check(access and access.title == Browser.ACCESS
	and titles(access) == "RXP/Onyxia Attunement (A), RXP/Scholomance Key (A)"
	and access.items[1].why == "RestedXP", "attunements and keys get their own folder, got %s",
	access and titles(access) or "none")
check(withAccess.items[1].folder.title == Browser.ROUTE_LEGS and withAccess.items[3].guide
	== "Dungeons/The Deadmines (17-24)", "between the route runs and the dungeon guides")
local rxp = find(A:BrowserCategory("leveling"), "RestedXP")
check(not rxp or not string.find(titles(rxp), "Attunement", 1, true), "and are not among RestedXP's levels")
check(A:BrowserCategoryOf("RXP/Onyxia Attunement (A)") == "dungeons", "Recent files them there too")
check(not Browser.AccessChain("Class/Rogue: The Azure Key (50)") or A:BrowserCategoryOf("Class/Rogue: The Azure Key (50)") ~= "dungeons",
	"a class quest named for a key stays with the class quests")
guide("Moonwhisper Coast (52-60)", "A Go|Z|Teldrassil|\n")
local mwc = pic("Moonwhisper Coast (52-60)")
check(mwc.kind == "image" and mwc.texture == A.Theme.zonemap["Moonwhisper Coast"] and mwc.coords == Pictures.ART_COORDS,
	"a custom zone with no map data: the map the addon carries")
-- Without that, it would not borrow the map of the zone its steps are in.
do
	local zone, art = Browser.ZONES["Moonwhisper Coast"], A.Theme.zonemap["Moonwhisper Coast"]
	Browser.ZONES["Moonwhisper Coast"], A.Theme.zonemap["Moonwhisper Coast"] = nil, nil
	Browser.zoneCache = nil
	check(pic("Moonwhisper Coast (52-60)").kind == "logo", "a custom zone without a map does not borrow another's")
	Browser.ZONES["Moonwhisper Coast"], A.Theme.zonemap["Moonwhisper Coast"] = zone, art
	Browser.zoneCache = nil
end
for _, g in ipairs({ "Optimized/Uldaman (45-46)", "Moonwhisper Coast (52-60)" }) do
	A.guides[g] = nil
	table.remove(A.guidelist)
end

-- Every zone's map has its explored areas, but the cities, which have none.
local cities = { Darnassis = true, Ironforge = true, Ogrimmar = true, Stormwind = true, ThunderBluff = true, Undercity = true }
for zone, info in pairs(Browser.ZONES) do
	check(cities[info[1]] or A.MAP_OVERLAYS[info[1]] or A.Theme.zonemap[zone],
		"%s (%s) has map overlay data, or a map of its own", zone, info[1])
end

-- An overlay wider than a tile is cut as the client cuts it.
A.MAP_OVERLAYS.Test = { "WIDE:300:200:10:20" }
local pieces = Pictures.MapPieces("Test")
check(table.getn(pieces) == 14, "12 tiles and two overlay pieces, got %d", table.getn(pieces))
local p1, p2 = pieces[13], pieces[14]
check(p1[1] == "Interface\\WorldMap\\Test\\WIDE1" and p1[2] == 10 and p1[4] == 256 and p1[6] == 1,
	"the first a whole tile")
check(p2[1] == "Interface\\WorldMap\\Test\\WIDE2" and p2[2] == 266 and p2[4] == 44 and p2[6] == 44 / 64
	and p2[5] == 200 and p2[7] == 200 / 256, "the rest as wide as is left, cropped from its 64px file")
check(pieces[4][2] == 768 and pieces[5][3] == 256 and pieces[12][1] == "Interface\\WorldMap\\Test\\Test12",
	"the twelve tiles four across")
local cx, cy, cw, ch = Pictures.Crop("Test", 16 / 9)
check(cw >= 560 and math.abs(cw / ch - 16 / 9) < 0.001 and cx >= 0 and cy >= 0
	and cx + cw <= Pictures.MAP_W and cy + ch <= Pictures.MAP_H, "the crop fits the map at the picture's shape")
check(cx <= 10 and cx + cw >= 310 and cy <= 20 and cy + ch >= 220, "and holds the explored area")
cx, cy, cw, ch = Pictures.Crop("Ironforge", 16 / 9)
check(cx == 0 and cw == Pictures.MAP_W, "a map with no areas is shown whole across")

local frame = Pictures:Create(UIParent, 240, 135)
frame:SetGuide("Optimized/Darkshore (20-21)")
local shown = 0
for _, t in ipairs(frame.tiles) do if t:IsShown() then shown = shown + 1 end end
local over = 0
for _, t in ipairs(frame.overlays) do if t:IsShown() then over = over + 1 end end
check(shown == 12 and over > 5, "Darkshore: its tiles and its areas, got %d and %d", shown, over)
frame:SetGuide("Dungeons/Scarlet Monastery (34-45)")
check(frame.screen:IsShown() and frame.screen:GetTexture() == A.Theme.loadscreen["Scarlet Monastery"]
	and frame.screen.__texcoord[1] == 0 and frame.screen.__texcoord[2] == 1, "a loading screen, whole")
over = 0
for _, t in ipairs(frame.overlays) do if t:IsShown() then over = over + 1 end end
check(over == 0 and not frame.tiles[1]:IsShown(), "and the map put away")
frame:SetGuide("Class/Warlock: Voidwalker (10)")
check(frame.crest:IsShown() and frame.crest.__texcoord[1] == 0.75 and frame.iconFrame:IsShown()
	and frame.icon:GetTexture() == "Interface\\Icons\\Spell_Shadow_SummonVoidWalker", "the crest and the spell")
check(math.abs(frame.strip.__color[1] - Theme.CLASS_COLORS.WARLOCK[1]) < 0.01, "in the class's colour")
frame:SetGuide(nil)
check(frame.logo:IsShown() and not frame.crest:IsShown() and not frame.screen:IsShown(), "the logo")

-- The window ------------------------------------------------------------------------

local list = A.guidelistframe
local ui, view = A.browserui, A.browserview
check(Theme:IsWindow(list), "the browser stacks with the other windows")
check(UISpecialFrames[table.getn(UISpecialFrames)] == "AegisPathfinderGuideList", "Escape closes it")

A:NoteRecentGuide("Optimized/Redridge (18-20)")
A:NoteRecentGuide("Dungeons/The Deadmines (17-24)")
list:Show()
fire(list, "OnShow")
check(ui.home:IsShown() and not ui.list:IsShown() and not ui.pane:IsShown(), "it opens on Home")
check(ui.tabs[1].active and not ui.tabs[2].active, "HOME is lit")
for _, key in ipairs({ "history", "suggested", "levels", "gold" }) do
	check(ui.cards[key]:IsShown(), "the %s panel shows", key)
end
check(ui.cards.history.rows[1].guide == "Dungeons/The Deadmines (17-24)" and ui.cards.history.rows[2].guide
	== "Optimized/Redridge (18-20)" and not ui.cards.history.rows[3]:IsShown(), "the guides opened last")
check(ui.cards.suggested.rows[1].guide == "Optimized/Darkshore (20-21)"
	and ui.cards.suggested.rows[1].why:GetText() == "Next on your route", "what fits, and why")
check(ui.cards.levels.rows[1][1]:GetText() == "Level 22", "the level tracker")
check(string.find(ui.cards.gold.rows[1][2]:GetText(), "1s", 1, true) ~= nil, "the gold tracker, got %s",
	ui.cards.gold.rows[1][2]:GetText())

-- A guide on a Home panel opens as a list's does.
arg1 = "LeftButton"
click(ui.cards.history.rows[1])
check(opened[table.getn(opened)] == "Dungeons/The Deadmines (17-24)", "a panel's guide opens beside the route")

-- Hiding a panel: the rest move up into its place.
click(ui.dots)
check(ui.options:IsShown() and ui.panelSwitches[1]:IsShown() and not ui.listSwitches[1]:IsShown(),
	"Home's ⋮ is which panels show")
click(ui.panelSwitches[1])
check(not ui.cards.history:IsShown() and A.db.char.browserpanels.history, "hide Guides history")
local p = { ui.cards.suggested:GetPoint(1) }
check(p[3] == "TOPLEFT", "Suggested guides takes its corner")
click(ui.panelSwitches[1])
check(ui.cards.history:IsShown(), "and back")
ui.options:Hide()

-- See more: every level's time.
click(ui.cards.levels.more)
check(ui.list:IsShown() and ui.title:GetText() == "Time at each level" and ui.back:IsShown(), "the level page")
check(ui.rows[1].text:GetText() == "Level 22" and ui.rows[2].text:GetText() == "Level 21"
	and ui.rows[2].right:GetText() == "11m 00s", "each level and its time, got %s", tostring(ui.rows[2].right:GetText()))
click(ui.back)
check(ui.home:IsShown(), "back to Home")

-- A category: folders, then guides.
click(ui.categories[1])
check(view.category == "leveling" and ui.list:IsShown() and ui.pane:IsShown(), "Leveling opens")
check(ui.categories[1].bar:IsShown() and not ui.tabs[1].active, "lit in the sidebar, not on the tabs")
check(ui.title:GetText() == "Leveling" and not ui.back:IsShown(), "titled, no way back from the top")
check(ui.rows[1].folder == "Optimized" and ui.rows[1].right:GetText() == "3", "a folder and how many guides")
arg1 = "LeftButton"
click(ui.rows[1])
check(ui.title:GetText() == "Optimized" and ui.crumb:GetText() == "Leveling" and ui.back:IsShown(), "in the folder")
check(ui.rows[1].guide == "Optimized/Elwynn Forest (1-10)" and ui.rows[1].text:GetText() == "Elwynn Forest (1-10)",
	"its guides, without the pack's prefix")
check(math.abs(ui.rows[1].text.__color[1] - Theme.LEVEL_COLORS.grey[1]) < 0.01, "an outlevelled guide in grey")
check(ui.rows[3].guide == "Optimized/Darkshore (20-21)"
	and math.abs(ui.rows[3].text.__color[1] - Theme.LEVEL_COLORS.grey[1]) < 0.01, "at 22, Darkshore (20-21) is grey too")

-- Pointing at a guide shows it on the right.
this = ui.rows[3]
fire(ui.rows[3], "OnEnter")
check(view.selected == "Optimized/Darkshore (20-21)" and ui.name:GetText() == "Darkshore (20-21)", "the pane follows")
check(ui.kind:GetText() == "Optimized route" and ui.needs:GetText() == "Levels 20-21", "what it is and its levels")
check(ui.picture.kind == "map" and ui.rows[3].star:IsShown() and ui.rows[3].load:IsShown(),
	"its map, and the row's star and arrow")
check(ui.rows[3].fill:IsShown() and not ui.rows[1].fill:IsShown(), "the row is marked")
fire(ui.rows[3], "OnLeave")
check(not ui.rows[3].load:IsShown() and ui.rows[3].fill:IsShown(), "it stays marked")
-- What a row says on the right ("Dungeon") makes room for the star and arrow.
ui.rows[3].right:SetText("Dungeon")
fire(ui.rows[3], "OnEnter")
local _, _, _, rightX = ui.rows[3].right:GetPoint(1)
check(rightX == -56, "pointed at, the row's right-hand text moves left of the star and arrow, got %s", tostring(rightX))
fire(ui.rows[3], "OnLeave")
_, _, _, rightX = ui.rows[3].right:GetPoint(1)
check(rightX == -10, "and back when they go, got %s", tostring(rightX))
ui.rows[3].right:SetText("")

-- Clicks.
arg1 = "LeftButton"
this = ui.rows[3]
local openedAt = table.getn(opened)
click(ui.rows[3])
check(table.getn(opened) == openedAt + 1 and opened[table.getn(opened)] == "Optimized/Darkshore (20-21)",
	"a click opens it in a new tab")
arg1 = "RightButton"
click(ui.rows[3], "RightButton")
arg1 = "LeftButton"
check(table.getn(opened) == openedAt + 2 and table.getn(loaded) == 0,
	"a right-click too: nothing loads over the tab you are on")
click(ui.open)
check(table.getn(opened) == openedAt + 3, "and so does Open in a new tab")
check(ui.load == nil and ui.beside == nil, "the Load button, which replaced the guide you were on, is gone")
A.db.char.completion["Optimized/Darkshore (20-21)"] = 1
shift = true
click(ui.rows[3])
shift = false
check(A.db.char.completion["Optimized/Darkshore (20-21)"] == nil, "shift-click resets its progress")

-- The star.
this = ui.rows[3].star
click(ui.rows[3].star)
check(A:IsFavoriteGuide("Optimized/Darkshore (20-21)"), "the star keeps it in Favorites")
check(ui.rows[3].star:IsShown(), "and a favourite's star stays up")
click(ui.categories[5])
check(ui.rows[1].guide == "Optimized/Darkshore (20-21)" and ui.rows[1].badge:IsShown(), "Favorites has it, with its badge")

-- A RestedXP guide opens in a tab of its own and leaves the route pack alone:
-- switching packs loaded the pack's guide over the one you were on.
click(ui.categories[1])
arg1 = "LeftButton"
click(ui.rows[2])
check(ui.title:GetText() == "RestedXP", "into RestedXP")
check(ui.crumb:GetText() == "Leveling", "under Leveling, got %s", ui.crumb:GetText())
local packsBefore, openedBefore = table.getn(packs), table.getn(opened)
click(ui.rows[1])
check(table.getn(packs) == packsBefore, "picking a RestedXP guide does not switch the route pack")
check(table.getn(opened) == openedBefore + 1 and string.find(opened[table.getn(opened)], "^RXP"),
	"it opens in a new tab, got %s", tostring(opened[table.getn(opened)]))
click(ui.back)
check(ui.title:GetText() == "Leveling", "back up to Leveling")

-- The list's ⋮, at level 20.
level = 20
click(ui.dots)
check(ui.listSwitches[1]:IsShown() and not ui.panelSwitches[1]:IsShown(), "a list's ⋮ is its four switches")
click(ui.rows[1])     -- Optimized
click(ui.listSwitches[3])
check(A.db.char.browserhidedone and ui.rows[1].guide == "Optimized/Redridge (18-20)"
	and ui.rows[2].guide == "Optimized/Darkshore (20-21)" and not ui.rows[3]:IsShown(),
	"hiding outlevelled guides, got %s", tostring(ui.rows[1].guide))
A.db.char.completion["Optimized/Redridge (18-20)"] = 1
A:UpdateGuideListPanel()
check(ui.rows[1].guide == "Optimized/Darkshore (20-21)", "and finished ones")
A.db.char.completion["Optimized/Redridge (18-20)"] = nil
click(ui.listSwitches[3])
click(ui.listSwitches[1])
check(not A.db.char.browsercolour and ui.rows[1].text.__color[1] == Theme.color.text[1], "colours off")
click(ui.listSwitches[1])
A.db.char.completion["Optimized/Elwynn Forest (1-10)"] = 1
A:UpdateGuideListPanel()
check(ui.rows[1].mark:GetTexture() == Theme.glyph.tick, "a finished guide ticked")
A.db.char.completion["Optimized/Elwynn Forest (1-10)"] = nil
click(ui.listSwitches[4])
check(ui.rows[3].suggested and ui.rows[3].star:IsShown(), "a suggested guide starred")
click(ui.listSwitches[4])
ui.options:Hide()

-- Search.
ui.search:SetText("shore")
fire(ui.search, "OnTextChanged")
check(ui.title:GetText() == '"shore"' and ui.rows[1].guide == "Darkshore (12-17)" and ui.rows[2].guide
	== "Optimized/Darkshore (20-21)" and not ui.rows[3]:IsShown(), "what is typed, found")
check(not ui.categories[1].bar:IsShown(), "no category lit while searching")
fire(ui.search, "OnEscapePressed")
fire(ui.search, "OnTextChanged")
check(view.search == "" and ui.title:GetText() == "Optimized", "Escape clears it, back where you were, got %s",
	ui.title:GetText())

-- Current and Recent.
A.db.char.tabs = { { guide = "Optimized/Redridge (18-20)" }, { guide = "Dungeons/The Deadmines (17-24)" } }
click(ui.tabs[2])
check(ui.rows[1].guide == "Optimized/Redridge (18-20)" and ui.rows[1].right:GetText() == "Your route"
	and ui.rows[2].right:GetText() == "Beside the route", "Current: the guides open")
A.db.char.recentguides = {}
A:NoteRecentGuide("Westfall (12-17)")
A:NoteRecentGuide("Dungeons/The Deadmines (17-24)")
A:NoteRecentGuide("Optimized/Redridge (18-20)")
click(ui.tabs[3])
check(ui.rows[1].text:GetText() == "LEVELING" and ui.rows[2].guide == "Optimized/Redridge (18-20)"
	and ui.rows[3].guide == "Westfall (12-17)" and ui.rows[4].text:GetText() == "DUNGEONS",
	"Recent: by category, the last first")
check(A.db.char.browsertab == "recent", "where it was left is kept")

-- Branching.
A.db.char.isbranching = true
A:UpdateGuideListPanel()
check(list.returnBtn:IsShown(), "Return to Main while a guide is open beside the route")
click(list.returnBtn)
check(not list.returnBtn:IsShown(), "and gone once back")

-- Scrolling and size.
for i = 1, 40 do guide(string.format("Westfall Extra %02d (%d-%d)", i, 12, 17)) end
click(ui.categories[1])
click(ui.rows[4])     -- Zone guides
click(ui.rows[1])     -- Eastern Kingdoms
check(ui.title:GetText() == "Eastern Kingdoms" and ui.crumb:GetText() == "Leveling / Zone guides",
	"two folders down, the crumb is the way there, got %s", ui.crumb:GetText())
check(ui.slider:IsShown(), "a long list scrolls")
local _, most = ui.slider:GetMinMaxValues()
fire(list, "OnMouseWheel", -1)
check(view.offset == 3 and ui.slider:GetValue() == 3, "the wheel moves it, got %s", tostring(view.offset))
local tall = A:SizeGuideBrowser(5000, 5000, true)
check(tall == 1280 and list:GetHeight() == 860 and A.db.profile.guidelistheight == 860, "kept to its largest")
local count = 0
for _, r in ipairs(ui.rows) do if r:IsShown() then count = count + 1 end end
check(count == math.floor((860 - 30 - 50 - 10) / 26), "and shows as many rows as fit, got %d", count)
A:SizeGuideBrowser(1, 1)
check(list:GetWidth() == 820 and list:GetHeight() == 520, "and its smallest")

-- Reopening where it was left.
A.db.char.browsertab = "class"
view.opened = nil
fire(list, "OnShow")
check(view.category == "class" and ui.title:GetText() == "Class Quests", "it reopens on the category left open")
A:ShowGuideList(true)
fire(list, "OnShow")
check(ui.home:IsShown(), "ShowGuideList(true) opens Home, with what fits your level")

-- The sidebar's Options and coming soon.
check(table.getn(ui.categories) == 5, "five categories to click")
local soon = 0
for _, c in ipairs(Browser.CATEGORIES) do if c.soon then soon = soon + 1 end end
check(soon == 6, "six coming soon")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("GuideBrowser: %d checks", checks))
if table.getn(failures) == 0 then
	print("All guide browser checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
