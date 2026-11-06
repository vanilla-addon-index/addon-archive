--[[
	Tests for "Where next?" -- offering the custom zones between guides.

	The walk-through the design came from: finish Redridge Mountains (27-28)
	on the route at 28, take Northwind (28-34), finish it at 34, take the
	next custom zone that fits, then go back to the route at the guide for
	the level you are by then -- not the one you left.

	Run:  lua5.1 Tools/tests/test_nextguide.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
local level = 28
UnitLevel = function() return level end

local printed = {}
AegisPathfinder = {
	guides = {}, guidelist = {}, nextzones = {}, qsplusguides = {},
	routes = {}, routepacks = {},
	db = { char = { completion = {}, currentguide = "Optimized/Redridge (27-28)" }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print(msg) table.insert(printed, msg) end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder:UpdateStatusFrame() end
function AegisPathfinder:UpdateGuideListPanel() end
function AegisPathfinder:UpdateObjectiveTabs() end
function AegisPathfinder:UpdateOHPanel() end
function AegisPathfinder:UnloadGuide() end
function AegisPathfinder:GetRouteForRace() return "Human" end
function AegisPathfinder.GetQuadrant() return "TOPRIGHT", "TOP", "RIGHT" end
-- Loading a guide moves currentguide, and, finishing one, records it done.
local loads = {}
function AegisPathfinder:LoadGuide(name, complete)
	local outgoing = self.db.char.currentguide
	if complete and outgoing then self.db.char.completion[outgoing] = 1 end
	self.db.char.currentguide = name
	self.current = 1
	table.insert(loads, name)
end

-- The guides: a stretch of the Optimized route and the custom zones.
local function guide(name, nextzone)
	AegisPathfinder.guides[name] = function() return "" end
	AegisPathfinder.nextzones[name] = nextzone
	table.insert(AegisPathfinder.guidelist, name)
end
guide("Optimized/Redridge (27-28)", "Optimized/Duskwood (28-29)")
guide("Optimized/Duskwood (28-29)", "Optimized/Ashenvale (29-30)")
guide("Optimized/Ashenvale (29-30)", "Optimized/Stranglethorn (33-34)")
guide("Optimized/Stranglethorn (33-34)", "Optimized/Arathi (37-38)")
guide("Optimized/Arathi (37-38)", "Optimized/Dustwallow (38-39)")
guide("Optimized/Dustwallow (38-39)", nil)
guide("Thalassian Highlands (1-10)")
guide("Northwind (28-34)")
guide("Balor (29-34)")
guide("Grim Reaches (33-38)")
guide("Gilneas (39-46)")
guide("Icepoint Rock (44-47)")
guide("Hyjal (58-60)")
guide("Moonwhisper Coast (52-60)")
guide("Westfall (12-17)")
AegisPathfinder.routes.Human = {
	{ levels = "27-28", guide = "Optimized/Redridge (27-28)" },
	{ levels = "28-29", guide = "Optimized/Duskwood (28-29)" },
	{ levels = "29-30", guide = "Optimized/Ashenvale (29-30)" },
	{ levels = "33-34", guide = "Optimized/Stranglethorn (33-34)" },
	{ levels = "37-38", guide = "Optimized/Arathi (37-38)" },
	{ levels = "38-39", guide = "Optimized/Dustwallow (38-39)" },
}

-- Core.lua is far too large to load under the stub; lift the tab, branch,
-- category and next-guide code out of it, as the tab tests do.
local core = io.open("Core.lua"):read("*a")
local function lift(from, to)
	local a = string.find(core, from, 1, true)
	local b = string.find(core, to, a or 1, true)
	assert(a and b, "could not find " .. from .. " in Core.lua")
	assert(loadstring(string.sub(core, a, b - 1)))()
end
lift("AegisPathfinder.NO_GUIDE =", "---------------------------------\n--      Branching Functions")
lift("--[[ Go back to the main route", "-- Turtle WoW custom zones for categorization")
lift("-- Turtle WoW custom zones for categorization", "---------------------------------\n--      Route Functions")
lift("function AegisPathfinder:LoadNextGuide()", "function AegisPathfinder:IsProfessionLearned")
lift("--[[ Guides renamed between versions", "function AegisPathfinder:OnInitialize()")

dofile("Theme.lua")
dofile("NextGuideFrame.lua")

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local function names(list)
	local out = {}
	for _, z in ipairs(list) do table.insert(out, z.guide) end
	return table.concat(out, ", ")
end
local function tabs()
	local out = {}
	for _, t in ipairs(AegisPathfinder.db.char.tabs or {}) do table.insert(out, t.guide) end
	return table.concat(out, " | ")
end

-- Which custom zones fit ------------------------------------------------------------

check(names(AegisPathfinder:GetCustomZoneChoices(28)) == "Northwind (28-34), Balor (29-34)",
	"at 28: Northwind, and Balor one level early; got '%s'", names(AegisPathfinder:GetCustomZoneChoices(28)))
check(names(AegisPathfinder:GetCustomZoneChoices(34)) == "Grim Reaches (33-38)",
	"at 34 Northwind and Balor are done with; got '%s'", names(AegisPathfinder:GetCustomZoneChoices(34)))
check(names(AegisPathfinder:GetCustomZoneChoices(28, "Northwind (28-34)")) == "Balor (29-34)",
	"the zone just finished is not offered again")
AegisPathfinder.db.char.completion["Balor (29-34)"] = 1
check(names(AegisPathfinder:GetCustomZoneChoices(28)) == "Northwind (28-34)", "nor one finished before")
AegisPathfinder.db.char.completion["Balor (29-34)"] = nil
check(table.getn(AegisPathfinder:GetCustomZoneChoices(20)) == 0, "a level with none fitting offers none")
check(names(AegisPathfinder:GetCustomZoneChoices(51)) == "Moonwhisper Coast (52-60)",
	"at 51: Moonwhisper Coast, a level early; got '%s'", names(AegisPathfinder:GetCustomZoneChoices(51)))
check(names(AegisPathfinder:GetCustomZoneChoices(58)) == "Moonwhisper Coast (52-60), Hyjal (58-60)",
	"at 58: Moonwhisper Coast still, and Hyjal; got '%s'", names(AegisPathfinder:GetCustomZoneChoices(58)))
check(table.getn(AegisPathfinder:GetCustomZoneChoices(60)) == 0, "at 60, nothing: it is done with")
-- Icepoint Rock's quests are level 45 to 48, and the boat there needs 40:
-- as "40-50" it was offered at 39, and at 40 for mobs in their mid-forties.
check(names(AegisPathfinder:GetCustomZoneChoices(39)) == "Gilneas (39-46)",
	"at 39: Gilneas, not Icepoint Rock; got '%s'", names(AegisPathfinder:GetCustomZoneChoices(39)))
check(names(AegisPathfinder:GetCustomZoneChoices(42)) == "Gilneas (39-46)",
	"at 42 still not Icepoint Rock; got '%s'", names(AegisPathfinder:GetCustomZoneChoices(42)))
check(names(AegisPathfinder:GetCustomZoneChoices(43)) == "Gilneas (39-46), Icepoint Rock (44-47)",
	"at 43: Icepoint Rock, a level early; got '%s'", names(AegisPathfinder:GetCustomZoneChoices(43)))
check(table.getn(AegisPathfinder:GetCustomZoneChoices(47)) == 0, "at 47, neither")

-- A renamed guide keeps its progress -------------------------------------------------

do
	local saved = AegisPathfinder.db.char
	local old, new = "Icepoint Rock (40-50)", "Icepoint Rock (44-47)"
	check(AegisPathfinder.RENAMED_GUIDES[old] == new, "Icepoint Rock's old name maps to its new one")
	AegisPathfinder.db.char = {
		currentguide = old, branchsavedguide = old,
		tabs = { { guide = "Optimized/Arathi (37-38)", step = 4 }, { guide = old, step = 9 } },
		completion = { [old] = 0.4 }, turnins = { [old] = { [6] = true } },
		favorites = { [old] = true }, recentguides = { new, "Northwind (28-34)", old },
	}
	AegisPathfinder:MigrateGuideNames()
	local c = AegisPathfinder.db.char
	check(c.currentguide == new and c.branchsavedguide == new, "the guide you were on is the renamed one")
	check(c.tabs[1].guide == "Optimized/Arathi (37-38)" and c.tabs[2].guide == new and c.tabs[2].step == 9,
		"its tab keeps its step")
	check(c.completion[new] == 0.4 and c.completion[old] == nil, "and how far through it you were")
	check(c.turnins[new] and c.turnins[new][6] and c.turnins[old] == nil, "and the steps it saw turned in")
	check(c.favorites[new] and c.favorites[old] == nil, "and its star")
	check(table.concat(c.recentguides, " | ") == new .. " | Northwind (28-34)",
		"and its place in the recent list, once; got '%s'", table.concat(c.recentguides, " | "))
	AegisPathfinder:MigrateGuideNames()
	check(c.completion[new] == 0.4, "running it again changes nothing")
	AegisPathfinder.db.char = saved
end

-- What comes next: the route's next leg, before a guide's own next link ---------------

-- A guide's next link names one successor for everyone; on your route, the
-- route decides (RestedXP parts ways by race at 19).
AegisPathfinder.nextzones["Optimized/Redridge (27-28)"] = "Westfall (12-17)"
check(AegisPathfinder:GetRouteSuccessor("Optimized/Redridge (27-28)") == "Optimized/Duskwood (28-29)",
	"on the route, the next leg, got %s", tostring(AegisPathfinder:GetRouteSuccessor("Optimized/Redridge (27-28)")))
check(AegisPathfinder:GetRouteContinuation("Optimized/Redridge (27-28)") == "Optimized/Duskwood (28-29)",
	"and that is where finishing it goes, not its own next link")
check(AegisPathfinder:GetRouteSuccessor("Westfall (12-17)") == nil, "off the route, nothing")
AegisPathfinder.nextzones["Westfall (12-17)"] = "Optimized/Arathi (37-38)"
check(AegisPathfinder:GetRouteContinuation("Westfall (12-17)") == "Optimized/Arathi (37-38)",
	"so a guide picked from the list goes where its own next link says")
check(AegisPathfinder:GetRouteSuccessor("Optimized/Dustwallow (38-39)") == nil, "and the route's last guide has none after it")
AegisPathfinder.routes.NightElf = { { levels = "27-28", guide = "Optimized/Redridge (27-28)" },
	{ levels = "28-29", guide = "Optimized/Ashenvale (29-30)" } }
AegisPathfinder.db.char.currentroute = "NightElf"
check(AegisPathfinder:GetRouteSuccessor("Optimized/Redridge (27-28)") == "Optimized/Ashenvale (29-30)",
	"a route the options chose, not your race's, is the one followed")
AegisPathfinder.db.char.currentroute = nil
AegisPathfinder.routes.NightElf = nil
AegisPathfinder.nextzones["Optimized/Redridge (27-28)"] = "Optimized/Duskwood (28-29)"
AegisPathfinder.nextzones["Westfall (12-17)"] = nil

-- Finishing a route guide ------------------------------------------------------------

AegisPathfinder:EnsureTabs()
check(tabs() == "Optimized/Redridge (27-28)", "the route in its tab, got %s", tabs())

check(AegisPathfinder:OfferNextGuide() == true, "finishing Redridge at 28 asks")
local f = AegisPathfinder.nextguideframe
check(f and f:IsShown(), "in a window")
check(string.find(f.done:GetText(), "Redridge (27-28)", 1, true) ~= nil,
	"naming what was finished, got '%s'", tostring(f.done:GetText()))
check(f.route:IsShown() and f.route:GetText() == "CONTINUE TO DUSKWOOD (28-29)",
	"the route's next guide first, got '%s'", f.route:GetText())
check(f.zones[1]:IsShown() and f.zones[1]:GetText() == "NORTHWIND (28-34)"
	and f.zones[2]:GetText() == "BALOR (29-34)" and not f.zones[3]:IsShown(),
	"then the custom zones that fit")
check(f:GetHeight() > 150, "sized to its rows, got %s", f:GetHeight())
local _, rel = f:GetPoint()
check(rel == nil or rel == AegisPathfinder.objectiveframe or rel == UIParent, "placed")
check(AegisPathfinder:OfferNextGuide() == true and table.getn(loads) == 0,
	"asked again while it is open, it keeps waiting and loads nothing")

-- Take Northwind.
this = f.zones[1]
f.zones[1]:GetScript("OnClick")()
check(not f:IsShown(), "choosing closes the window")
check(AegisPathfinder.db.char.currentguide == "Northwind (28-34)", "Northwind is loaded")
check(tabs() == "Optimized/Duskwood (28-29) | Northwind (28-34)",
	"in a tab beside the route, which waits at its next guide; got %s", tabs())
check(AegisPathfinder.db.char.activetab == 2 and AegisPathfinder.db.char.isbranching, "on the custom zone's tab")
check(AegisPathfinder.db.char.completion["Optimized/Redridge (27-28)"] == 1, "Redridge counts as done")

-- Finishing a custom zone ------------------------------------------------------------

level = 34
check(AegisPathfinder:OfferNextGuide() == true, "finishing Northwind at 34 asks again")
check(f.route:GetText() == "BACK TO STRANGLETHORN (33-34)",
	"back to the route at the guide for level 34, not the one left; got '%s'", f.route:GetText())
check(f.zones[1]:GetText() == "GRIM REACHES (33-38)" and not f.zones[2]:IsShown(),
	"or the next custom zone that fits")

this = f.zones[1]
f.zones[1]:GetScript("OnClick")()
check(tabs() == "Optimized/Duskwood (28-29) | Grim Reaches (33-38)",
	"a custom zone after a custom zone takes its tab; got %s", tabs())
check(AegisPathfinder.db.char.currentguide == "Grim Reaches (33-38)", "and is loaded")
check(AegisPathfinder.db.char.completion["Northwind (28-34)"] == 1, "Northwind counts as done")

-- Finish Grim Reaches at 38 and go back.
level = 38
check(AegisPathfinder:OfferNextGuide() == true, "finishing Grim Reaches asks")
check(f.zones[1]:GetText() == "GILNEAS (39-46)", "offering Gilneas one level early")
this = f.route
f.route:GetScript("OnClick")()
check(tabs() == "Optimized/Arathi (37-38)" and not AegisPathfinder.db.char.isbranching,
	"back on the route, at the guide for 38; got %s", tabs())
check(AegisPathfinder.db.char.currentguide == "Optimized/Arathi (37-38)", "and it is loaded")
check(AegisPathfinder.db.char.completion["Grim Reaches (33-38)"] == 1, "Grim Reaches counts as done")

-- Closing it --------------------------------------------------------------------------

-- Closing without a choice carries on with the route, as it always did.
level = 38
AegisPathfinder.db.char.completion["Gilneas (39-46)"] = nil
check(AegisPathfinder:OfferNextGuide() == true, "finishing Arathi at 38 offers Gilneas")
loads = {}
f:Hide()
this = f
f:GetScript("OnHide")()
check(AegisPathfinder.db.char.currentguide == "Optimized/Dustwallow (38-39)",
	"closing it carries on with the route, got %s", tostring(AegisPathfinder.db.char.currentguide))
check(table.getn(loads) == 1, "once")
check(AegisPathfinder:OfferNextGuide("Optimized/Arathi (37-38)") == false,
	"and a guide is only asked about once")

-- Nothing to ask ----------------------------------------------------------------------

level = 20
AegisPathfinder.db.char.currentguide = "Westfall (12-17)"
check(AegisPathfinder:OfferNextGuide() == false and not f:IsShown(),
	"with no custom zone at your level, nothing is asked")
level = 38
AegisPathfinder.db.char.currentguide = "Optimized/Dustwallow (38-39)"
AegisPathfinder.db.char.offercustomzones = false
check(AegisPathfinder:OfferNextGuide() == false and not f:IsShown(), "switched off, nothing is asked")
AegisPathfinder.db.char.offercustomzones = nil

-- The end of the route: only the custom zones.
check(AegisPathfinder:OfferNextGuide() == true, "the last route guide still offers custom zones")
check(not f.route:IsShown() and not f.routeHeader:IsShown(), "with no route row, having nowhere to continue")
f.chosen = true
f:Hide()

-- Dungeons along the way ------------------------------------------------------------------

-- The dungeons ticked on the options window's Dungeons page, offered when
-- one fits your level: its dungeon guide opens beside the route.
guide("Dungeons/Shadowfang Keep (22-30)")
guide("Dungeons/Blackfathom Deeps (24-32)")
guide("Dungeons/Windhorn Canyon (26-30)")
guide("Dungeons/Uldaman (41-51)")
AegisPathfinder.DUNGEON_INFO = {
	{ code = "SFK", name = "Shadowfang Keep" }, { code = "BFD", name = "Blackfathom Deeps" },
	{ code = "ULDA", name = "Uldaman" },
}
AegisPathfinder.TURTLE_DUNGEON_INFO = { { code = "WHC", name = "Windhorn Canyon" } }
local char = AegisPathfinder.db.char
char.Dungeons = { SFK = true, BFD = false, WHC = true, ULDA = true }
level = 28
check(table.getn(AegisPathfinder:GetDungeonGuideChoices(28)) == 0, "with dungeons along the way off, none")
char.offerdungeons = true
check(names(AegisPathfinder:GetDungeonGuideChoices(28)) == "Dungeons/Shadowfang Keep (22-30), Dungeons/Windhorn Canyon (26-30)",
	"on: the ticked ones at your level, Turtle's own included, not Blackfathom, unticked; got '%s'",
	names(AegisPathfinder:GetDungeonGuideChoices(28)))
check(names(AegisPathfinder:GetDungeonGuideChoices(40)) == "Dungeons/Uldaman (41-51)", "Uldaman a level early")
char.completion["Dungeons/Shadowfang Keep (22-30)"] = 1
check(names(AegisPathfinder:GetDungeonGuideChoices(28)) == "Dungeons/Windhorn Canyon (26-30)", "not one finished")
char.completion["Dungeons/Shadowfang Keep (22-30)"] = nil
char.SelfFound = true
check(table.getn(AegisPathfinder:GetDungeonGuideChoices(28)) == 0, "and none in Solo Self-Found")
char.SelfFound = nil

-- Finishing Redridge at 28, with custom zones off: only the dungeons.
char.currentguide, char.tabs, char.activetab, char.isbranching = "Optimized/Redridge (27-28)", nil, nil, false
AegisPathfinder.offered = {}
char.offercustomzones = false
AegisPathfinder:EnsureTabs()
check(AegisPathfinder:OfferNextGuide() == true, "with custom zones off, the dungeons are still offered")
check(string.find(f.done:GetText(), "run a dungeon", 1, true) ~= nil, "asked as such, got '%s'", f.done:GetText())
check(not f.zoneHeader:IsShown() and not f.zones[1]:IsShown(), "no custom zones")
check(f.dungeonHeader:IsShown() and f.dungeons[1]:GetText() == "SHADOWFANG KEEP (22-30)"
	and f.dungeons[2]:GetText() == "WINDHORN CANYON (26-30)" and not f.dungeons[3]:IsShown(),
	"the dungeons, by the names of their guides")
this = f.dungeons[2]
f.dungeons[2]:GetScript("OnClick")()
check(char.currentguide == "Dungeons/Windhorn Canyon (26-30)", "picking one loads its guide")
check(tabs() == "Optimized/Duskwood (28-29) | Dungeons/Windhorn Canyon (26-30)",
	"beside the route, which waits at its next guide; got %s", tabs())

-- Both on: the zones, then the dungeons.
char.offercustomzones = nil
char.currentguide, char.tabs, char.activetab, char.isbranching = "Optimized/Redridge (27-28)", nil, nil, false
AegisPathfinder.offered = {}
AegisPathfinder:EnsureTabs()
check(AegisPathfinder:OfferNextGuide() == true and f.zones[1]:IsShown() and f.dungeons[1]:IsShown(),
	"custom zones and dungeons together")
check(string.find(f.done:GetText(), "custom zone or a dungeon", 1, true) ~= nil, "and says so")
local _, _, _, _, zoneY = f.zones[1]:GetPoint()
local _, _, _, _, dungeonY = f.dungeonHeader:GetPoint()
check(dungeonY < zoneY, "the dungeons under the custom zones")
f.chosen = true
f:Hide()
char.offerdungeons = nil

-- A dungeon at the middle of its levels ----------------------------------------------------

--[[ The dungeons ticked in the setup, each offered once on reaching the
	middle of its dungeon guide's levels: The Deadmines (17-24) at 21. ]]
guide("Dungeons/The Deadmines (17-24)")
AegisPathfinder.DUNGEON_INFO = {
	{ code = "DM", name = "The Deadmines" }, { code = "SFK", name = "Shadowfang Keep" },
	{ code = "BFD", name = "Blackfathom Deeps" }, { code = "ULDA", name = "Uldaman" },
}
char.Dungeons = { DM = true, SFK = true, BFD = true, ULDA = true, WHC = true }
char.completion = {}
char.currentguide, char.tabs, char.activetab, char.isbranching = "Optimized/Redridge (27-28)", nil, nil, false
AegisPathfinder:EnsureTabs()
local midlevel = AegisPathfinder.DungeonMidLevel
check(midlevel(17, 24) == 21 and midlevel(22, 30) == 26 and midlevel(13, 18) == 16,
	"the middle, a half rounded up: 21, 26, 16")

char.setupdone = nil
check(table.getn(AegisPathfinder:GetMidLevelDungeons(21)) == 0, "nothing before the setup is done")
char.setupdone = true
check(table.getn(AegisPathfinder:GetMidLevelDungeons(20)) == 0, "nothing a level short of the middle")
check(names(AegisPathfinder:GetMidLevelDungeons(21)) == "Dungeons/The Deadmines (17-24)",
	"The Deadmines at 21, got '%s'", names(AegisPathfinder:GetMidLevelDungeons(21)))
check(names(AegisPathfinder:GetMidLevelDungeons(28)) == "Dungeons/Shadowfang Keep (22-30), Dungeons/Blackfathom Deeps (24-32)",
	"at 28 two, lowest middle first; not The Deadmines, outlevelled, nor Windhorn Canyon, Turtle's own; got '%s'",
	names(AegisPathfinder:GetMidLevelDungeons(28)))
char.Dungeons.BFD = false
check(names(AegisPathfinder:GetMidLevelDungeons(28)) == "Dungeons/Shadowfang Keep (22-30)", "not one unticked")
char.Dungeons.BFD = true
char.completion["Dungeons/Shadowfang Keep (22-30)"] = 1
check(names(AegisPathfinder:GetMidLevelDungeons(28)) == "Dungeons/Blackfathom Deeps (24-32)", "not one finished")
char.completion["Dungeons/Shadowfang Keep (22-30)"] = nil
char.SelfFound = true
check(table.getn(AegisPathfinder:GetMidLevelDungeons(28)) == 0, "none in Solo Self-Found")
char.SelfFound = nil
char.middungeons = false
check(table.getn(AegisPathfinder:GetMidLevelDungeons(28)) == 0, "none with the switch off")
char.middungeons = nil

-- Offered: the window, once.
check(AegisPathfinder:OfferMidLevelDungeons(21) == true, "at 21 The Deadmines is offered")
local m = AegisPathfinder.middungeonframe
check(m and m:IsShown(), "in a window")
check(string.find(m.text:GetText(), "level 21", 1, true) and string.find(m.text:GetText(), "The Deadmines (17-24)", 1, true),
	"saying why, got '%s'", m.text:GetText())
check(m.dungeons[1]:GetText() == "OPEN THE DEADMINES (17-24)" and not m.dungeons[2]:IsShown() and m.later:IsShown(),
	"one button to open it, and not now; got '%s'", tostring(m.dungeons[1]:GetText()))
check(char.middungeonsoffered and char.middungeonsoffered.DM, "and it is remembered as offered")
this = m.dungeons[1]
m.dungeons[1]:GetScript("OnClick")()
check(char.currentguide == "Dungeons/The Deadmines (17-24)", "open loads the dungeon guide")
check(tabs() == "Optimized/Redridge (27-28) | Dungeons/The Deadmines (17-24)",
	"in a tab beside the route, got %s", tabs())
check(not m:IsShown(), "and the window goes")
check(AegisPathfinder:OfferMidLevelDungeons(21) == false, "and is not offered again")

-- Two at once: opening one keeps the other; not now closes.
check(AegisPathfinder:OfferMidLevelDungeons(28) == true and m.dungeons[1]:IsShown() and m.dungeons[2]:IsShown(),
	"at 28 both, one button each")
this = m.dungeons[1]
m.dungeons[1]:GetScript("OnClick")()
check(m:IsShown() and m.dungeons[1]:GetText() == "OPEN BLACKFATHOM DEEPS (24-32)" and not m.dungeons[2]:IsShown(),
	"opening one leaves the other, got '%s'", tostring(m.dungeons[1]:GetText()))
this = m.later
m.later:GetScript("OnClick")()
check(not m:IsShown() and char.middungeonsoffered.BFD, "not now closes it, and it has had its offer")

-- One at a time: "Where next?" first.
f:Show()
check(AegisPathfinder:OfferMidLevelDungeons(46) == false and not char.middungeonsoffered.ULDA,
	"with Where next? up, it waits, and has not been offered")
f.chosen = true
f:Hide()

-- The level up: the new level, from the event.
AegisPathfinder.enableDone = true
event, arg1 = "PLAYER_LEVEL_UP", 46
this = AegisPathfinder.midLevelEvents
AegisPathfinder.midLevelEvents:GetScript("OnEvent")()
check(m:IsShown() and m.dungeons[1]:GetText() == "OPEN ULDAMAN (41-51)", "reaching 46 offers Uldaman")
m:Hide()
char.middungeonsoffered, char.setupdone = nil, nil

-- The windows' rows sit in their own window ---------------------------------------------

--[[ Put anchored every row to "Where next?", whichever window it was laying
	out: the dungeon window's buttons hung off a window that was not there,
	or off another one. ]]
char.setupdone, char.middungeonsoffered = true, nil
check(AegisPathfinder:OfferMidLevelDungeons(46) == true, "Uldaman again, for the anchoring")
local _, rel = m.dungeons[1]:GetPoint(1)
local _, relLater = m.later:GetPoint(1)
check(rel == m and relLater == m, "the dungeon window's buttons are anchored to it, not to Where next?")
m:Hide()
char.middungeonsoffered = nil

-- A class quest at its level --------------------------------------------------------------

--[[ Guides/Class/ registers each class's milestones: a warlock's Voidwalker
	at 10, the Felhunter at 30, the Dreadsteed at 60 with a group. The one
	for your class and race is offered on reaching its level, once, when the
	route does not do it already and it is not done. ]]
local VOID, FELHUNTER, DREAD = "Class/Warlock: Voidwalker (10)", "Class/Warlock: Felhunter (30)", "Class/Warlock: Dreadsteed (60)"
guide(VOID) guide(FELHUNTER) guide(DREAD)
AegisPathfinder:RegisterClassMilestones("Horde", "WARLOCK", {
	{ guide = VOID, group = false, races = {
		["Orc"] = { level = 10, last = 1504, quests = { 1501, 1504 } },
		["Undead"] = { level = 10, last = 1471, quests = { 1473, 1471 } },
	} },
	{ guide = FELHUNTER, group = false, races = {
		["Orc"] = { level = 30, last = 1795, quests = { 1801, 1803, 1805, 1795 } },
	} },
	{ guide = DREAD, group = true, races = {
		["Orc"] = { level = 60, last = 7631, quests = { 7562, 7631 } },
	} },
})
AegisPathfinder:RegisterClassMilestones("Alliance", "WARLOCK", {
	{ guide = "Class/Warlock: Voidwalker (10)", group = false, races = {
		["Human"] = { level = 10, last = 1689, quests = { 1688, 1689 } },
	} },
})
local faction, class, race = "Horde", "WARLOCK", "Orc"
UnitFactionGroup = function() return faction end
UnitClass = function() return "Warlock", class end
UnitRace = function() return race == "Undead" and "Undead" or race, race == "Undead" and "Scourge" or race end
local onServer = {}
function AegisPathfinder:IsQuestCompletedOnServer(qid) return onServer[tonumber(qid)] == true end
-- The route: an Orgrimmar stretch that does not take the Voidwalker.
AegisPathfinder.guides["Optimized/Durotar (10-12)"] = function()
	return "A Creature of the Void |QID|1473| |C|Warlock| |R|Undead|\nA Vile Familiars |QID|792|\n"
end
AegisPathfinder.routes.Orc = { { levels = "10-12", guide = "Optimized/Durotar (10-12)" } }
function AegisPathfinder:GetRouteForRace() return faction == "Horde" and "Orc" or "Human" end
char.currentroute, char.classoffered = nil, nil
char.completion = {}
char.currentguide, char.tabs, char.activetab, char.isbranching = "Optimized/Durotar (10-12)", nil, nil, false
AegisPathfinder:EnsureTabs()

check(AegisPathfinder:ClassGuideRace() == "Orc", "an Orc is an Orc")
race = "Undead"
check(AegisPathfinder:ClassGuideRace() == "Undead", "UnitRace's Scourge is the guides' Undead")
race = "Orc"

char.setupdone = nil
check(table.getn(AegisPathfinder:GetClassMilestones(10)) == 0, "nothing before the setup is done")
char.setupdone = true
check(table.getn(AegisPathfinder:GetClassMilestones(9)) == 0, "nothing a level short")
check(names(AegisPathfinder:GetClassMilestones(10)) == VOID, "the Voidwalker at 10, got '%s'",
	names(AegisPathfinder:GetClassMilestones(10)))
check(names(AegisPathfinder:GetClassMilestones(15)) == VOID, "five levels on, still")
check(table.getn(AegisPathfinder:GetClassMilestones(16)) == 0,
	"six on, no: that far past it, it is most likely done")
check(names(AegisPathfinder:GetClassMilestones(30)) == FELHUNTER, "the Felhunter at 30")
check(table.getn(AegisPathfinder:GetClassMilestones(60)) == 0, "the Dreadsteed needs a group")
char.PlayStyle = "GROUP"
check(names(AegisPathfinder:GetClassMilestones(60)) == DREAD, "in a group it is offered")
char.SelfFound = true
check(table.getn(AegisPathfinder:GetClassMilestones(60)) == 0, "Solo Self-Found is solo, whatever group mode says")
char.SelfFound, char.PlayStyle = nil, nil
-- Two at once, lowest first.
AegisPathfinder:RegisterClassMilestones("Horde", "WARLOCK", {
	{ guide = VOID, group = false, races = { ["Orc"] = { level = 10, last = 1504, quests = { 1501, 1504 } } } },
	{ guide = FELHUNTER, group = false, races = { ["Orc"] = { level = 12, last = 1795, quests = { 1795 } } } },
})
check(names(AegisPathfinder:GetClassMilestones(13)) == VOID .. ", " .. FELHUNTER, "two at 13, lowest first")
AegisPathfinder:RegisterClassMilestones("Horde", "WARLOCK", {
	{ guide = VOID, group = false, races = {
		["Orc"] = { level = 10, last = 1504, quests = { 1501, 1504 } },
		["Undead"] = { level = 10, last = 1471, quests = { 1473, 1471 } },
	} },
	{ guide = FELHUNTER, group = false, races = {
		["Orc"] = { level = 30, last = 1795, quests = { 1801, 1803, 1805, 1795 } },
	} },
	{ guide = DREAD, group = true, races = {
		["Orc"] = { level = 60, last = 7631, quests = { 7562, 7631 } },
	} },
})
onServer[1504] = true
check(table.getn(AegisPathfinder:GetClassMilestones(10)) == 0, "not one whose last quest is handed in")
onServer[1504] = nil
char.completion[VOID] = 1
check(table.getn(AegisPathfinder:GetClassMilestones(10)) == 0, "nor one whose guide is finished")
char.completion[VOID] = nil
class = "WARRIOR"
check(table.getn(AegisPathfinder:GetClassMilestones(10)) == 0, "a warrior is offered no warlock's")
class, race = "WARLOCK", "Tauren"
check(table.getn(AegisPathfinder:GetClassMilestones(10)) == 0, "nor a race the milestone has no chain for")
race = "Undead"
check(table.getn(AegisPathfinder:GetClassMilestones(10)) == 0,
	"an Undead's route has Creature of the Void already: not offered")
race, faction = "Human", "Alliance"
check(names(AegisPathfinder:GetClassMilestones(10)) == VOID, "the Alliance's, for a Human")
race, faction = "Orc", "Horde"
AegisPathfinder.guides["Optimized/Orgrimmar (12-13)"] = function()
	return "A Creature of the Void |QID|1501| |C|Mage|\n"
end
table.insert(AegisPathfinder.routes.Orc, { levels = "12-13", guide = "Optimized/Orgrimmar (12-13)" })
check(names(AegisPathfinder:GetClassMilestones(10)) == VOID, "a later leg's step for another class does not count")
AegisPathfinder.guides["Optimized/Barrens (13-15)"] = function()
	return "T The Binding |QID|1504| |C|Warlock| |R|Orc/Troll|\n"
end
table.insert(AegisPathfinder.routes.Orc, { levels = "13-15", guide = "Optimized/Barrens (13-15)" })
check(table.getn(AegisPathfinder:GetClassMilestones(10)) == 0, "one of its quests on a leg to come: the route does it")
table.remove(AegisPathfinder.routes.Orc)
char.classquests = false
check(table.getn(AegisPathfinder:GetClassMilestones(10)) == 0, "none with the switch off")
char.classquests = nil

-- Offered: the window, once; open puts it in a tab beside the route.
check(AegisPathfinder:OfferClassMilestones(10) == true, "at 10 the Voidwalker is offered")
local cw = AegisPathfinder.classquestframe
check(cw and cw:IsShown(), "in a window")
check(string.find(cw.text:GetText(), "level 10", 1, true) and string.find(cw.text:GetText(), "Warlock: Voidwalker (10)", 1, true),
	"saying which, got '%s'", cw.text:GetText())
check(cw.rows[1]:GetText() == "OPEN WARLOCK: VOIDWALKER (10)" and not cw.rows[2]:IsShown() and cw.later:IsShown(),
	"one button to open it, and not now; got '%s'", tostring(cw.rows[1]:GetText()))
local _, rowRel = cw.rows[1]:GetPoint(1)
check(rowRel == cw, "its buttons are anchored to it")
check(char.classoffered and char.classoffered[VOID], "and it is remembered as offered")
this = cw.rows[1]
cw.rows[1]:GetScript("OnClick")()
check(char.currentguide == VOID, "open loads the class guide")
check(tabs() == "Optimized/Durotar (10-12) | " .. VOID, "in a tab beside the route, got %s", tabs())
check(not cw:IsShown(), "and the window goes")
check(AegisPathfinder:OfferClassMilestones(10) == false, "and is not offered again")

-- The dungeon's window first; the class quest's when it closes.
local SUCCUBUS = "Class/Warlock: Succubus (20)"
guide(SUCCUBUS)
AegisPathfinder:RegisterClassMilestones("Horde", "WARLOCK", {
	{ guide = SUCCUBUS, group = false, races = { ["Orc"] = { level = 20, last = 1513, quests = { 1507, 1513 } } } },
})
char.classoffered = nil
char.tabs, char.activetab, char.isbranching = nil, nil, false
char.currentguide = "Optimized/Durotar (10-12)"
AegisPathfinder:EnsureTabs()
char.Dungeons = { DM = true }
char.middungeonsoffered = nil
check(AegisPathfinder:OfferAtLevel(21) == true and m:IsShown() and not cw:IsShown(),
	"at 21 The Deadmines' window first")
this = m.later
m.later:GetScript("OnClick")()
-- The client runs OnHide as the window goes; the stub leaves it to us.
this = m
m:GetScript("OnHide")()
check(not m:IsShown() and cw:IsShown() and cw.rows[1]:GetText() == "OPEN WARLOCK: SUCCUBUS (20)",
	"not now on it brings the class quest's, got '%s'", tostring(cw.rows[1]:GetText()))
cw.later:GetScript("OnClick")()
check(not cw:IsShown() and char.classoffered[SUCCUBUS], "not now closes it, and it has had its offer")
char.middungeonsoffered, char.classoffered, char.setupdone, char.Dungeons = nil, nil, nil, {}

-- Report ----------------------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("NextGuide: %d checks", checks))
if table.getn(failures) == 0 then
	print("All next guide checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
