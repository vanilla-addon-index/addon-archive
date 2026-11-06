--[[
	Tests for the waypoint providers and the arrow switches.

	The fake TomTom below behaves as TomTom-TWOW (github.com/laytya/TomTom-TWOW)
	does where it matters here:

	  - AddMFWaypoint fills a nil `crazy` from its own "autoqueue" setting,
	    which defaults on, so leaving it out aims TomTom's arrow anyway;
	  - LoadWayPoint only uses its default callbacks -- the ones behind the
	    map and minimap pins' tooltips and click menu -- when the waypoint
	    brings none of its own;
	  - RemoveWaypoint clears the arrow if it was pointing at that waypoint.

	Run:  lua5.1 Tools/tests/test_navigation.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

GetLocale = function() return "enUS" end
GetMapContinents = function() return "Eastern Kingdoms" end
GetMapZones = function() return "Dun Morogh", "Elwynn Forest", "Redridge Mountains", "Tirisfal Glades", "Stranglethorn Vale" end
IsAddOnLoaded = function() return false end
WorldMapFrame = CreateFrame("Frame", nil, UIParent)
WorldMapFrame:Hide()

AegisPathfinder = { db = { char = { waypointprovider = "auto" }, profile = {} } }
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder:SetTurnedIn() end
function AegisPathfinder:GetObjectiveInfo() return nil end
function AegisPathfinder:UpdateNavCallout() end

dofile("Locale.lua")
AegisPathfinder.Locale = AEGISPATHFINDER_LOCALE
dofile("Navigation.lua")
-- The real one, for the tests that follow a step to its waypoint; the arrow
-- tests below stand in for it.
local ForceWaypointUpdate = AegisPathfinder.ForceWaypointUpdate

-- TomTom-TWOW, as far as these tests reach into it.
local DEFAULT_CALLBACKS = { minimap = { tooltip_show = "pin tooltip" }, world = { tooltip_show = "map tooltip" } }
TomTom = { waypoints = {}, waypointprofile = {}, autoqueue = true }
function TomTom:DefaultCallbacks()
	return { minimap = DEFAULT_CALLBACKS.minimap, world = DEFAULT_CALLBACKS.world }
end
function TomTom:AddMFWaypoint(c, z, x, y, opts)
	if opts.crazy == nil then opts.crazy = self.autoqueue end
	local uid = { continent = c, zone = z, x = x, y = y, title = opts.title,
		crazy = opts.crazy, callbacks = opts.callbacks }
	table.insert(self.waypoints, uid)
	if uid.crazy then self.active_waypoint = uid end
	if not uid.callbacks then uid.callbacks = self:DefaultCallbacks() end
	return uid
end
function TomTom:RemoveWaypoint(uid)
	for k, w in ipairs(self.waypoints) do
		if w == uid then table.remove(self.waypoints, k) break end
	end
	if self.active_waypoint == uid then self.active_waypoint = nil end
end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local db = AegisPathfinder.db.char
local function travel()
	-- A RUN step with coordinates in its note: a waypoint, and an arrival
	-- callback that completes the step.
	AegisPathfinder:ParseAndMapCoords(nil, "RUN", "Head for Goldshire (42.1, 65.3)",
		"Goldshire", "Elwynn Forest")
	return TomTom.waypoints[table.getn(TomTom.waypoints)]
end

-- Pathfinder's arrow alone, the default -------------------------------------------

check(AegisPathfinder:IsArrowOn("pathfinder") and not AegisPathfinder:IsArrowOn("tomtom"),
	"ours alone by default")
local wp = travel()
check(wp ~= nil, "the step's waypoint still goes to TomTom")
check(wp and wp.crazy == false,
	"but TomTom's arrow is told no outright -- left nil, its autoqueue would aim it anyway")
check(TomTom.active_waypoint == nil, "so TomTom's arrow is not pointing at it")
check(AegisPathfinder.waypointtarget and AegisPathfinder.waypointtarget.x == 42.1,
	"while ours still has the waypoint to point at")
check(wp and wp.title == "Pathfinder: Goldshire",
	"titled for this addon, got '%s'", tostring(wp and wp.title))

-- The pins keep TomTom's own tooltips and menus.
check(wp and wp.callbacks.minimap == DEFAULT_CALLBACKS.minimap
	and wp.callbacks.world == DEFAULT_CALLBACKS.world,
	"a travel step's pins keep TomTom's tooltip and click menu")
check(wp and wp.callbacks.distance and wp.callbacks.distance[15],
	"and add the arrival callback that completes the step")

-- Ours and TomTom's -----------------------------------------------------------------

-- SetArrow re-sends the current step; stand in for the engine.
function AegisPathfinder:ForceWaypointUpdate() travel() end
AegisPathfinder:SetArrow("tomtom", true)
wp = TomTom.waypoints[table.getn(TomTom.waypoints)]
check(table.getn(TomTom.waypoints) == 1, "changing the setting replaces the waypoint rather than adding one")
check(TomTom.active_waypoint == wp and wp.crazy == true, "TomTom's switch aims its arrow at it")
check(AegisPathfinder:IsArrowOn("pathfinder"), "and ours stays on")

-- And back: TomTom lets it go.
AegisPathfinder:SetArrow("tomtom", false)
check(TomTom.active_waypoint == nil, "switching it off takes TomTom's arrow off our waypoint")

-- pfQuest ----------------------------------------------------------------------------

local nodes, target = {}, nil
pfMap = {
	AddNode = function(_, meta) table.insert(nodes, meta) end,
	DeleteNode = function() nodes = {} end,
	GetMapIDByName = function() return 12 end,
}
pfQuest = { route = {
	SetTarget = function(t) target = t end,
	IsTarget = function(t) return target and t and target.title == t.title end,
} }
local pfArrow = CreateFrame("Frame", nil, UIParent)
pfQuest.route.arrow = pfArrow
pfQuest_config = { arrow = "0" }                 -- pfQuest's own arrow off
db.waypointprovider = "pfquest"
AegisPathfinder:SetArrow("tomtom", false)
check(table.getn(nodes) == 1 and nodes[1].arrow == false,
	"pfQuest gets the pin without its arrow flag")
check(target == nil, "and its arrow is not aimed at it")
AegisPathfinder:SetArrow("pfquest", true)
check(pfQuest_config.arrow == "1", "pfQuest's switch turns pfQuest's own arrow on")
check(nodes[table.getn(nodes)].arrow == true and target ~= nil, "and aims it at the step")
AegisPathfinder:SetArrow("pathfinder", false)
check(db.shownavcallout == false and target ~= nil, "ours can go off and pfQuest's stay")
AegisPathfinder:SetArrow("pfquest", false)
check(pfQuest_config.arrow == "0" and not pfArrow:IsShown(), "off, pfQuest's arrow is off in pfQuest, and hidden")
check(target == nil, "and no longer aimed at the step")
AegisPathfinder:SetArrow("pathfinder", true)

--[[ Several arrows at once, whichever addon takes the waypoints: TomTom
	takes them, and pfQuest's arrow, switched on, is sent the waypoint as
	well so it can point at it. ]]
db.waypointprovider = "tomtom"
AegisPathfinder:SetArrow("tomtom", true)
AegisPathfinder:SetArrow("pfquest", true)
wp = TomTom.waypoints[table.getn(TomTom.waypoints)]
check(wp and wp.crazy == true and TomTom.active_waypoint == wp, "TomTom's arrow points at the step")
check(table.getn(nodes) == 1 and nodes[1].arrow == true and target ~= nil,
	"and so does pfQuest's, though TomTom takes the waypoints")
check(AegisPathfinder:IsArrowOn("pathfinder"), "with ours: three arrows")
check(AegisPathfinder:DescribeArrows() == "Pathfinder, TomTom, pfQuest", "diagnav names them, got %s",
	AegisPathfinder:DescribeArrows())
AegisPathfinder:SetArrow("pfquest", false)
check(table.getn(nodes) == 0, "pfQuest's off: it is sent nothing it did not ask for")
AegisPathfinder:SetArrow("tomtom", false)
pfQuest_config = nil

-- Pointing -------------------------------------------------------------------

--[[ Our arrow's bearing. What went wrong in game: TomTom's Astrolabe, when it
	cannot place the player in a zone, leaves the hidden world map on the
	continent view. The map then reports a position but zone 0, and our
	same-zone code read that as "the waypoint is in another zone" and hid,
	while TomTom's arrow -- through Astrolabe -- kept pointing. ]]
db.waypointprovider = "tomtom"
AegisPathfinder:SetArrow("pathfinder", true)
check(AegisPathfinder.waypointtarget ~= nil, "the step has a waypoint to point at")

GetPlayerFacing = function() return 0 end        -- facing north
local mapZone, mapReset = 0, false               -- left on the continent view
GetCurrentMapContinent = function() return 1 end
GetCurrentMapZone = function() return mapZone end
GetPlayerMapPosition = function() return 0.4, 0.4 end
SetMapToCurrentZone = function() mapZone, mapReset = 2, true end

-- TomTom-TWOW's Astrolabe: the player in another zone of the continent, the
-- waypoint 300 yd east and 400 yd north of them.
Astrolabe = {
	GetCurrentPlayerPosition = function() return 1, 1, 0.9, 0.9 end,
	ComputeDistance = function() return 500, 300, -400 end,
}
local bearing, yards, why = AegisPathfinder:GetWaypointBearing()
check(bearing ~= nil, "with the map on the continent view it still points (%s)", tostring(why))
check(bearing and math.abs(bearing - math.atan2(300, 400)) < 1e-6,
	"towards the waypoint, got %s", tostring(bearing))
check(yards == 500, "measured in yards by Astrolabe, got %s", tostring(yards))
check(not mapReset, "and without yanking the player's map about")

-- A zone Astrolabe has no dimensions for comes back 0, 0, 0: unknown, not
-- "standing on it". Fall back rather than point straight ahead at 0 yd.
Astrolabe.ComputeDistance = function() return 0, 0, 0 end
mapZone, mapReset = 0, false
bearing, yards, why = AegisPathfinder:GetWaypointBearing()
check(mapReset, "an unknown zone falls back to the map, re-centring it off the continent view")
check(bearing ~= nil and yards == nil,
	"which points in the same zone without claiming a distance (%s)", tostring(why))

-- Without Astrolabe: same zone only, and a continent-view map is re-centred
-- rather than read as another zone.
Astrolabe = nil
mapZone, mapReset = 0, false
bearing, yards, why = AegisPathfinder:GetWaypointBearing()
check(mapReset and bearing ~= nil, "without Astrolabe it re-centres the map and points (%s)", tostring(why))
SetMapToCurrentZone = function() mapZone = 1 end     -- the player really is elsewhere
mapZone = 0
bearing, yards, why = AegisPathfinder:GetWaypointBearing()
check(bearing == nil and string.find(why or "", "another zone", 1, true),
	"and in another zone it hides, saying why, got '%s'", tostring(why))

-- The waypoint addon's arrow ------------------------------------------------------------

--[[ crazy = false keeps TomTom's arrow off our waypoint when it is added, but
	TomTom-TWOW's GoToNextWayPoint -- when its arrow's target is reached or
	cleared, or on resurrection -- hands the arrow to the last waypoint in its
	list, ours included. The Arrow setting takes it back. ]]
function TomTom:ClearCrazyArrow() self.active_waypoint = nil end
local ours = TomTom.waypoints[table.getn(TomTom.waypoints)]
TomTom.active_waypoint = ours                     -- GoToNextWayPoint's doing
AegisPathfinder:EnforceArrowMode()
check(TomTom.active_waypoint == nil, "TomTom's switch off, its arrow is taken off our waypoint")

local theirs = { title = "The player's own waypoint" }
TomTom.active_waypoint = theirs
AegisPathfinder:EnforceArrowMode()
check(TomTom.active_waypoint == theirs, "but never off a waypoint the player made themselves")

AegisPathfinder:SetArrow("tomtom", true)
TomTom.active_waypoint = ours
AegisPathfinder:EnforceArrowMode()
check(TomTom.active_waypoint == ours, "and with TomTom's switch on it is left pointing")

-- Trainers by name, from pfQuest ---------------------------------------------------

--[[ Profession steps name who to go to but carry no coordinates; the names
	are looked up in pfQuest's unit database. Here: two Expert enchanting
	trainers, one inside a dungeon the world map cannot show. ]]
pfDB = {
	zones = { loc = { [12] = "Elwynn Forest", [1] = "Dun Morogh", [1337] = "Uldaman" } },
	units = {
		loc = { [11072] = "Kitta Firewind", [7406] = "Annora", [5] = "Tomas", [6] = "Cook Ghilm" },
		data = {
			[11072] = { coords = { { 64.5, 69.5, 12, 0 } } },
			[7406]  = { coords = { { 38.0, 70.0, 1337, 0 } } },
			[5]     = { coords = { { 44.0, 66.0, 12, 0 } } },
			[6]     = { coords = { { 68.0, 54.0, 1, 0 } } },
		},
	},
}
db.waypointprovider = "tomtom"
AegisPathfinder:ClearWaypoint()
check(AegisPathfinder:MapNearestNPC({ "Annora", "Kitta Firewind" }, "Train Expert Enchanting"),
	"a trainer is found by name")
local wpt = AegisPathfinder.waypointtarget
check(wpt and wpt.zoneindex == 2 and wpt.x == 64.5,
	"the one the map can show -- Kitta in Elwynn, not Annora inside Uldaman")
check(TomTom.waypoints[table.getn(TomTom.waypoints)].title
	== "Pathfinder: Train Expert Enchanting (Kitta Firewind)",
	"and the waypoint says who, got '%s'", tostring(TomTom.waypoints[table.getn(TomTom.waypoints)].title))

-- The nearest of several, measured by Astrolabe.
Astrolabe = {
	GetCurrentPlayerPosition = function() return 1, 1, 0.5, 0.5 end,      -- in Dun Morogh
	ComputeDistance = function(_, c1, z1, x1, y1, c2, z2) return z2 == 1 and 300 or 2000, 1, 1 end,
}
AegisPathfinder:ClearWaypoint()
AegisPathfinder:MapNearestNPC({ "Tomas", "Cook Ghilm" }, "Learn Cooking")
check(AegisPathfinder.waypointtarget and AegisPathfinder.waypointtarget.zoneindex == 1,
	"the nearest trainer is chosen -- Cook Ghilm in Dun Morogh, 300 yd, over Tomas")

check(not AegisPathfinder:MapNearestNPC({ "Nobody Atall" }, "Train"),
	"a name pfQuest does not know sends nothing")

-- A step's NPCs are mapped when its note has no coordinates.
AegisPathfinder:ClearWaypoint()
AegisPathfinder:ParseAndMapCoords(nil, "TRAIN", "Needs skill 125.", "Train Expert Enchanting",
	nil, { "Kitta Firewind" })
check(AegisPathfinder.waypointtarget and AegisPathfinder.waypointtarget.x == 64.5,
	"a training step with no coordinates gets its trainer's")

-- pfQuest's forks ------------------------------------------------------------

--[[ Not every fork of pfQuest carries every table and function this uses.
	One without them is left alone: no pfQuest waypoints from a fork missing
	part of the map API, and a quest-giver lookup that finds nothing where a
	table is missing, rather than an error. ]]
do
	local keepMap, keepDB = pfMap.GetMapIDByName, pfDB
	pfMap.GetMapIDByName = nil
	db.waypointprovider = "pfquest"
	local ok, err = pcall(travel)
	check(ok, "a fork without GetMapIDByName: no error, got %s", tostring(err))
	check(AegisPathfinder:GetWaypointProvider() ~= nil and AegisPathfinder:GetWaypointProvider().label ~= "pfQuest",
		"and pfQuest is passed over for the waypoints")
	pfMap.GetMapIDByName = keepMap

	db.mapquestgivers = true
	pfDB = { quests = { data = { [7] = { start = { U = { 5 } } } } } }   -- no loc, no units
	local found
	ok, found = pcall(AegisPathfinder.MapPfQuestNPC, AegisPathfinder, 7, "ACCEPT")
	check(ok and found == false, "a quest-giver lookup with tables missing finds nothing, got %s", tostring(found))
	pfDB = { quests = { data = { [7] = { start = { U = { 5 } } } } },
		units = { data = { [5] = { coords = { { 42, 65, 12, 0 } } } } } }            -- no names, no zones
	ok, err = pcall(AegisPathfinder.MapPfQuestNPC, AegisPathfinder, 7, "ACCEPT")
	check(ok, "or with names and zones missing, got %s", tostring(err))
	db.mapquestgivers, pfDB = nil, keepDB
	db.waypointprovider = "tomtom"
end

-- The zone a step is in ------------------------------------------------------

--[[ A step without a |Z| tag is in the guide's zone, from its title, and the
	Optimized titles shorten it: "Optimized/Redridge (18-20)". The map has no
	"Redridge", so each such step's waypoint went to the zone you stood in,
	and chat said "Cannot find zone "Redridge", using current zone." on every
	step. The shortened names -- in titles and in |Z| tags -- are the map's
	names now; a point on a continent's map is put on that map, never on
	whatever zone you are in. ]]
do
	AegisPathfinder.select = select
	dofile("Parser.lua")
	local A = AegisPathfinder
	local said = {}
	local keepPrint, keepInfo = A.Print, A.GetObjectiveInfo
	A.Print = function(_, msg) table.insert(said, msg) end
	A.GetObjectiveInfo = function() return "RUN", "Three Corners" end
	db.waypointprovider = "tomtom"

	local function step(tags, guide)
		A.zonename = A:GuideZone(guide or "Optimized/Redridge (18-20)")
		A.tags, A.current = { tags }, 1
		TomTom.waypoints = {}
		said = {}
		ForceWaypointUpdate(A)
		return TomTom.waypoints[1]
	end

	check(A:GuideZone("Optimized/Redridge (18-20)") == "Redridge Mountains",
		"Optimized/Redridge is in Redridge Mountains, got %s", tostring(A:GuideZone("Optimized/Redridge (18-20)")))
	check(A:GuideZone("Stranglethorn (36-37)") == "Stranglethorn Vale" and A:GuideZone("Un'goro (51-52)") == "Un'Goro Crater",
		"and the zone guides' shortened titles too")
	check(A:GuideZone("Elwynn Forest (1-12)") == "Elwynn Forest", "a title with the map's name keeps it")
	check(A:GuideZone("RXP/52-52 Felwood") == nil, "a title with no level range in brackets has no zone")

	local wp = step("|QID|244| |N|Guard Parker in Three Corners (15.32, 71.42)|")
	check(wp and wp.zone == 3, "a Redridge step's waypoint is on Redridge Mountains' map, got zone %s", tostring(wp and wp.zone))
	check(table.getn(said) == 0, "and nothing is said in chat, got %q", tostring(said[1]))

	wp = step("|N|Travel to Brill (59.50, 52.22)| |Z|Tirisfal|", "Silverpine Forest (12-20)")
	check(wp and wp.zone == 4 and table.getn(said) == 0, "|Z|Tirisfal| is Tirisfal Glades, quietly")

	wp = step("|N|Travel to Booty Bay (28.08, 76.19)| |Z||", "Stranglethorn (39-40)")
	check(wp and wp.zone == 5 and table.getn(said) == 0, "an empty |Z| is the guide's zone")

	--[[ RestedXP's "Travel to Eastern Kingdoms" steps give a point on the
		continent's map. TomTom-TWOW takes it as zone 0 of the continent, as
		Astrolabe numbers it, and points across the continent. ]]
	local continentstep = "|N|Travel to Eastern Kingdoms (48.1, 62.4)| |O| |Z|Eastern Kingdoms|"
	wp = step(continentstep, "RXP/Onyxia Attunement (A)")
	check(wp and wp.continent == 1 and wp.zone == 0 and math.abs(wp.x - 0.481) < 1e-9,
		"a point on a continent's map goes to TomTom on that map, zone 0, got %s/%s",
		tostring(wp and wp.continent), tostring(wp and wp.zone))
	check(table.getn(said) == 0, "and nothing is said in chat, got %q", tostring(said[1]))
	check(wp and wp.callbacks.distance and wp.callbacks.distance[30] and not wp.callbacks.distance[15],
		"arriving within 30 yd, as the point is only written to a tenth of a percent of the continent")
	check(A.waypointtarget and A.waypointtarget.zoneindex == 0, "our arrow has it to point at")
	local bearing, yards, why = A:GetWaypointBearing()
	check(bearing ~= nil and yards == 2000, "and points, measured by Astrolabe (%s)", tostring(why))
	local keepAstrolabe = Astrolabe
	Astrolabe = nil
	bearing, yards, why = A:GetWaypointBearing()
	check(bearing == nil and string.find(why or "", "continent", 1, true),
		"without Astrolabe it hides, saying why, got '%s'", tostring(why))
	Astrolabe = keepAstrolabe

	-- The others place notes in a zone: they decline it, rather than put the
	-- point in the zone you are standing in.
	db.providerarrow = false
	db.waypointprovider = "pfquest"
	nodes = {}
	wp = step(continentstep, "RXP/Onyxia Attunement (A)")
	check(table.getn(nodes) == 0 and A.waypointtarget == nil and table.getn(said) == 0,
		"pfQuest declines it, quietly")
	local keepLoaded, metanotes = IsAddOnLoaded, {}
	IsAddOnLoaded = function(name) return name == "MetaMap" end
	MetaMap_NameToZoneID = function() return nil end
	MetaMap_GetCurrentMapInfo = function() return 99 end
	MetaMapNotes_AddNewNote = function(note) table.insert(metanotes, note) end
	MetaMapNotes_DeleteNote = function() end
	db.waypointprovider = "metamap"
	step(continentstep, "RXP/Onyxia Attunement (A)")
	check(table.getn(metanotes) == 0, "and so does MetaMap, whose fallback is the zone you are in")
	IsAddOnLoaded, MetaMap_NameToZoneID, MetaMap_GetCurrentMapInfo = keepLoaded, nil, nil
	MetaMapNotes_AddNewNote, MetaMapNotes_DeleteNote = nil, nil
	db.waypointprovider, db.providerarrow = "tomtom", true

	wp = step("|N|Somewhere (10, 10)| |Z|Nowhere Land|")
	check(wp ~= nil and said[1] and string.find(said[1], "Nowhere Land", 1, true),
		"a zone the map really has not got is still reported, and falls back to where you are")

	A.Print, A.GetObjectiveInfo = keepPrint, keepInfo
end

--[[ A TomTom that did not start. TomTom-TWOW puts its arrow back where it
	was saved before it makes its waypoint lists; a saved place the client
	will not take stops it there, and picking a guide then failed in
	TomTom's RemoveWaypoint, on a list it never made. Such a TomTom is
	absent as far as the waypoints go. ]]
do
	local lists, profile = TomTom.waypoints, TomTom.waypointprofile
	TomTom.waypoints, TomTom.waypointprofile = nil, nil
	local ok, err = pcall(function()
		AegisPathfinder:ParseAndMapCoords(nil, "RUN", "Head for Goldshire (42.1, 65.3)", "Goldshire", "Elwynn Forest")
		AegisPathfinder:ClearWaypoint()
	end)
	check(ok, "a TomTom that did not start takes no waypoints and throws nothing: %s", tostring(err))
	TomTom.waypoints, TomTom.waypointprofile = lists, profile
	local wp2 = travel()
	check(wp2 ~= nil, "and once it has started, it takes them again")
end

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Navigation: %d checks", checks))
if table.getn(failures) == 0 then
	print("All navigation checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
