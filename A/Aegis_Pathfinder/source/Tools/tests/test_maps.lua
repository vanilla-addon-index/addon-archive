--[[
	Tests for the options' Maps page: what Maps.lua draws on the world map and
	the minimap.

	The reveal has to draw only the overlays the client does not, and stand
	down for pfUI, Cartographer and MetaMap; the step's places have to come
	from pfQuest and the step's note, on the zone shown and nowhere else; the
	trail has to run from you to the waypoint, dots or dashes, only on its
	zone; the rares have to be the ones near your level, sized and see-through
	as set; and the minimap's trail has to stay inside what the minimap shows.
	Each draws nothing when it is switched off.

	Run:  lua5.1 Tools/tests/test_maps.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

AegisPathfinder = { db = { char = {}, profile = {} }, current = 1 }
local A = AegisPathfinder
function A.select(index, ...)
	local t = { ... }
	return t[index]
end
local steps = {}            -- { action, name, tags }
function A:GetObjectiveTag(tag, i)
	local s = steps[i or self.current]
	return s and s[3] and s[3][tag]
end
local function step(action, name, tags)
	steps = { { action, name, tags or {} } }
	A.actions, A.quests = { action }, { name }
	A.current = 1
	A.db.char.currentguide = name
end

-- The world map, as the client has it: 1002 by 668, Westfall shown.
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame:Hide()
WorldMapDetailFrame = CreateFrame("Frame", "WorldMapDetailFrame", WorldMapFrame)
WorldMapDetailFrame:SetWidth(1002); WorldMapDetailFrame:SetHeight(668)
WorldMapButton = CreateFrame("Button", "WorldMapButton", WorldMapDetailFrame)
WorldMapButton:SetWidth(1002); WorldMapButton:SetHeight(668)
local map = { c = 2, z = 2, file = "Westfall", known = {} }
GetCurrentMapContinent = function() return map.c end
GetCurrentMapZone = function() return map.z end
GetMapZones = function(c)
	if c == 2 then return "Elwynn Forest", "Westfall", "Duskwood" end
	return "Durotar"
end
GetMapInfo = function() return map.file end
GetNumMapOverlays = function() return table.getn(map.known) end
GetMapOverlayInfo = function(i) return map.known[i], 256, 256, 0, 0 end
local player = { 0.2, 0.5 }
GetPlayerMapPosition = function() return player[1], player[2] end
local loaded = {}
IsAddOnLoaded = function(name) return loaded[name] or false end
local level = 18
UnitLevel = function() return level end
local zoom = 0
Minimap.GetZoom = function() return zoom end

-- The client's own drawing of the map, to see ours follows it.
local clientDrew = 0
function WorldMapFrame_Update() clientDrew = clientDrew + 1 end

dofile("Locale.lua")
A.Locale = AEGISPATHFINDER_LOCALE        -- as Core.lua hands it on
dofile("Theme.lua")
A.MAP_OVERLAYS = {
	Westfall = { "Moonbrook:256:256:300:300", "SentinelHill:300:200:500:200", "TheDustPlains:512:300:100:368" },
}
A.RARES = {
	Westfall = {
		{ "Foe Reaper 4000", 20, 20, "rare", { 40, 50, 45, 55 } },
		{ "Brack", 30, 32, "elite", { 10, 10 } },
		{ "Sergeant Brashclaw", 10, 11, "rare", { 5, 5 } },
	},
}
dofile("Maps.lua")
local Maps, Theme = A.Maps, A.Theme

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
local function shown(pool)
	local n = 0
	for _, p in ipairs(pool or {}) do if p:IsShown() then n = n + 1 end end
	return n
end
local function centre(p)
	local pt = p.__points[1]
	return pt[4], pt[5]
end
local profile = A.db.profile

-- Revealing the map ------------------------------------------------------------------

map.known = { "Interface\\WorldMap\\Westfall\\SentinelHill" }
local used = Maps:Reveal()
-- Moonbrook is one tile; The Dust Plains two across and two down.
check(used == 5, "the two areas not explored are drawn, in five tiles, got %d", used)
local first = Maps.tiles[1]
check(first:GetTexture() == "Interface\\WorldMap\\Westfall\\Moonbrook1", "Moonbrook's own art, got %s",
	tostring(first:GetTexture()))
do
	local r, g, b = first:GetVertexColor()
	check(r < 1 and r == g and g == b, "drawn a little dimmer than the explored, got %s", tostring(r))
	local pt = first.__points[1]
	check(pt[4] == 300 and pt[5] == -300, "where the client would draw it, got %s, %s", tostring(pt[4]), tostring(pt[5]))
end
do
	-- The Dust Plains: 512 by 300 is two tiles of 256 across; the bottom row
	-- is 44 high, in a 64-pixel file.
	local bottom = Maps.tiles[4]
	check(bottom:GetTexture() == "Interface\\WorldMap\\Westfall\\TheDustPlains3", "the bottom row's first tile, got %s",
		tostring(bottom:GetTexture()))
	check(bottom:GetHeight() == 44 and math.abs(bottom.__texcoord[4] - 44 / 64) < 1e-6,
		"cut to the 44 pixels left, of a 64-pixel file")
	local pt = bottom.__points[1]
	check(pt[4] == 100 and pt[5] == -(368 + 256), "under the first row, got %s, %s", tostring(pt[4]), tostring(pt[5]))
end
for _, name in ipairs({ "SentinelHill" }) do
	for _, t in ipairs(Maps.tiles) do
		check(not string.find(t:GetTexture() or "", name), "the explored %s is the client's to draw", name)
	end
end
map.known = {}
check(Maps:Reveal() == 7, "with nothing explored, all three: seven tiles")
profile.mapreveal = false
check(Maps:Reveal() == 0 and shown(Maps.tiles) == 0, "switched off: nothing, and the tiles drawn before hidden")
profile.mapreveal = nil
pfUI, pfUI_config = { mapreveal = {} }, { appearance = { worldmap = { mapreveal = "1" } } }
check(Maps:Reveal() == 0, "left to pfUI while its own reveal is on")
pfUI_config.appearance.worldmap.mapreveal = "0"
check(Maps:Reveal() == 7, "and drawn when it is off")
pfUI, pfUI_config = nil, nil
Cartographer = {}
check(Maps:Reveal() == 0, "left to Cartographer")
Cartographer = nil
loaded.MetaMapFWM = true
check(Maps:Reveal() == 0, "left to MetaMap's fog of war")
loaded.MetaMapFWM = nil
map.file = "Azeroth"
check(Maps:Reveal() == 0 and shown(Maps.tiles) == 0, "a map with no reveal data: nothing")
map.file = "Westfall"

-- The step on the map ----------------------------------------------------------------

pfDB = {
	zones = { loc = { [40] = "Westfall", [12] = "Elwynn Forest" } },
	units = { loc = { [1] = "Gryan Stoutmantle", [2] = "Marshal Dughan", [3] = "Defias Trapper", [4] = "Harvest Golem" },
		data = { [1] = { coords = { { 56.3, 47.5, 40, 0 } } }, [2] = { coords = { { 42.1, 65.9, 12, 0 } } },
			[3] = { coords = {} }, [4] = { coords = { { 48, 30, 40, 0 } } } } },
	quests = { data = { [100] = { start = { U = { 1 } }, ["end"] = { U = { 2 } }, obj = { U = { 3 }, I = { 500 } } } } },
	items = { data = { [500] = { U = { [4] = 50 } } } },
}
for k = 1, 30 do table.insert(pfDB.units.data[3].coords, { 30 + k * 0.5, 70, 40, 300 }) end

step("ACCEPT", "Westfall Stew", { QID = "100" })
check(Maps:DrawMarkers() == 1, "a quest to take: its giver, on Westfall")
local pin = Maps.pins[1]
check(pin.tex:GetTexture() == Theme.actionIcon.A and pin.title == "Gryan Stoutmantle", "with the take icon and the giver's name")
do
	local x, y = centre(pin)
	check(math.abs(x - 0.563 * 1002) < 1e-6 and math.abs(y + 0.475 * 668) < 1e-6, "where pfQuest has him, got %s, %s",
		tostring(x), tostring(y))
end
check(Maps:StepMarkers() == Maps:StepMarkers(), "worked out once for the step")

step("TURNIN", "Westfall Stew", { QID = "100", N = "Back to Dughan (42.1, 65.9)", Z = "Elwynn Forest" })
check(Maps:DrawMarkers() == 0 and shown(Maps.pins) == 0, "a hand-in in Elwynn Forest: nothing on Westfall")
map.z = 1
check(Maps:DrawMarkers() == 2, "on Elwynn Forest: the hand-in, and the note's place")
check(Maps.pins[1].tex:GetTexture() == Theme.actionIcon.T and Maps.pins[2].tex:GetTexture() == Theme.actionIcon.N,
	"the hand-in icon, then the note's")
check(Maps.pins[2].title == "Westfall Stew", "the note's place is named for the step")
map.z = 2

step("COMPLETE", "Westfall Stew", { QID = "100" })
local drawn = Maps:DrawMarkers()
check(drawn == 26, "kill areas, at most 25, and what drops the item: got %d", drawn)
check(Maps.pins[1]:GetWidth() < 14, "kill areas are spots, smaller than the quest givers")
check(Maps.pins[26].title == "Harvest Golem", "the item's dropper, by name")
profile.mapmarkers = false
check(Maps:DrawMarkers() == 0 and shown(Maps.pins) == 0, "switched off: nothing")
profile.mapmarkers = nil
local savedDB = pfDB
pfDB = nil
step("ACCEPT", "The Forgotten Heirloom", { QID = "100", N = "At the farm (51.5, 21.2)" })
A.zonename = "Westfall"
check(Maps:DrawMarkers() == 1 and Maps.pins[1].tex:GetTexture() == Theme.actionIcon.N,
	"without pfQuest, only the note's place, in the guide's zone")
pfDB = savedDB
map.c, map.z = 0, 0
check(Maps:DrawMarkers() == 0, "nothing on a continent's map or the world's")
map.c, map.z = 2, 2

-- The ant trail ----------------------------------------------------------------------

A.waypointtarget = { continent = 2, zoneindex = 2, x = 50, y = 50 }
-- From 20% across to 50%: 300.6 pixels, a dot every 14.
check(Maps:DrawTrail(0) == 20, "dots every 14 pixels to the waypoint, got %d", shown(Maps.trail))
do
	local x1 = centre(Maps.trail[1])
	check(math.abs(x1 - (0.2 * 1002 + 14)) < 1e-6, "the first a gap from you, got %s", tostring(x1))
	Maps:DrawTrail(0.6)
	local x2 = centre(Maps.trail[1])
	check(math.abs(x2 - x1 - 7) < 1e-6, "and they march on toward it, half a gap in 0.6 seconds, got %s", tostring(x2 - x1))
	local last = centre(Maps.trail[20])
	check(last < 0.5 * 1002, "none past the waypoint")
end
profile.antstyle = "dashes"
-- Every 4 pixels, 74 places, three on and three off: 38.
check(Maps:DrawTrail(0) == 38, "dashes: dots every 4 pixels, three on, three off; got %d", shown(Maps.trail))
check(Maps.trail[1]:GetWidth() == 4, "smaller dots, to read as dashes")
profile.antstyle = nil
map.z = 3
check(Maps:DrawTrail(0) == 0 and shown(Maps.trail) == 0, "on another zone's map: no trail")
map.z = 2
player = { 0, 0 }
check(Maps:DrawTrail(0) == 0, "nowhere to start from (in an instance): no trail")
player = { 0.2, 0.5 }
profile.anttrail = false
check(Maps:DrawTrail(0) == 0 and shown(Maps.trail) == 0, "switched off: no trail")
profile.anttrail = nil
A.waypointtarget = nil
check(Maps:DrawTrail(0) == 0, "no waypoint: no trail")
A.waypointtarget = { continent = 2, zoneindex = 2, x = 50, y = 50 }

-- Points of interest: the rares ------------------------------------------------------

check(Maps:DrawRares() == 0, "the rares are off to start with")
profile.maprares = true
check(Maps:DrawRares() == 2, "at 18, the level 20 rare, at both its places; got %d", shown(Maps.rarePins))
local rare = Maps.rarePins[1]
check(rare.title == "Foe Reaper 4000" and rare.lines[1] == "Level 20 rare", "named, with its level")
check(rare:GetWidth() == 16 and rare:GetAlpha() == 1, "16 across, solid, to start with")
profile.raresize, profile.raresseethru = 1.5, true
Maps:DrawRares()
check(rare:GetWidth() == 24 and rare:GetAlpha() == 0.5, "bigger, and see-through, as set")
profile.raresize, profile.raresseethru = nil, nil
level = 28
check(Maps:DrawRares() == 1 and Maps.rarePins[1].lines[1] == "Level 30-32 rare elite",
	"at 28: the 30-32 rare elite, and the rare left behind")
do
	local r = Maps.rarePins[1].tex:GetVertexColor()
	check(math.abs(r - Theme.color.danger[1]) < 1e-6, "a rare elite in the danger colour")
end
level = 18
map.z = 1
check(Maps:DrawRares() == 0 and shown(Maps.rarePins) == 0, "none on a zone with no rares listed")
map.z = 2
profile.maprares = nil
check(Maps:DrawRares() == 0 and shown(Maps.rarePins) == 0, "switched off: none")

-- The trail on the minimap -----------------------------------------------------------

local placed, removed = {}, 0
local dist = 1000
Astrolabe = {
	minimapOutside = true,
	GetCurrentPlayerPosition = function() return 2, 2, 0.2, 0.5 end,
	ComputeDistance = function() return dist end,
	PlaceIconOnMinimap = function(_, icon, c, z, x, y) table.insert(placed, { icon = icon, x = x, y = y }) end,
	RemoveIconFromMinimap = function() removed = removed + 1 end,
}
check(Maps:DrawMiniTrail() == 8, "eight dots toward the waypoint")
do
	-- Outdoors at the widest zoom the minimap is 466 yards across: the dots
	-- reach 85% of the way to its edge, 198 yards, not the 1000 to the waypoint.
	local farthest = (placed[8].x - 0.2) / 0.3 * dist
	check(farthest < 466.67 / 2 and farthest > 150, "the last within the minimap, got %s yards", tostring(farthest))
	check(placed[1].x > 0.2 and placed[1].x < placed[8].x and placed[8].y == 0.5, "in a line from you toward it")
end
placed = {}
dist = 90
Maps:DrawMiniTrail()
check(placed[8].x < 0.5 and math.abs((placed[8].x - 0.2) / 0.3 - 8 / 9) < 1e-6, "a waypoint nearer than that: up to it, not past")
placed = {}
dist = 1000
Astrolabe.minimapOutside = false
Maps:DrawMiniTrail()
check((placed[8].x - 0.2) / 0.3 * dist < 300 / 2, "indoors the minimap shows less, and the dots stop sooner")
Astrolabe.minimapOutside = true
removed = 0
A.waypointtarget = { continent = 2, zoneindex = 1, x = 50, y = 50 }
check(Maps:DrawMiniTrail() == 0 and removed == 8 and shown(Maps.mini) == 0, "a waypoint in another zone: the dots taken off")
A.waypointtarget = { continent = 2, zoneindex = 2, x = 50, y = 50 }
WorldMapFrame:Show()
check(Maps:DrawMiniTrail() == 0, "none while the world map is open")
WorldMapFrame:Hide()
profile.anttrail = false
check(Maps:DrawMiniTrail() == 0, "switched off: none")
profile.anttrail = nil
Astrolabe = nil
check(Maps:DrawMiniTrail() == 0 and shown(Maps.mini) == 0, "without Astrolabe: none")

-- Keeping up ---------------------------------------------------------------------------

profile.maprares = true
WorldMapFrame:Show()
WorldMapFrame_Update()
check(clientDrew == 1, "the client draws its map first")
check(shown(Maps.tiles) == 7 and shown(Maps.trail) == 20 and shown(Maps.rarePins) == 2,
	"then ours: the reveal, the trail and the rares")
profile.mapreveal = false
Maps:Refresh()
check(shown(Maps.tiles) == 0, "a setting changed on the page shows at once")
profile.mapreveal, profile.maprares = nil, nil
do
	local tick = Maps.ticker:GetScript("OnUpdate")
	local ok = pcall(function()
		this, arg1 = Maps.ticker, 0.2
		tick()
	end)
	check(ok and shown(Maps.trail) == 20, "the trail keeps up while the map is open")
	local saved = A.db
	A.db = nil
	ok = pcall(function()
		this, arg1 = Maps.ticker, 0.2
		tick()
		this, arg1 = Maps.miniTicker, 1
		Maps.miniTicker:GetScript("OnUpdate")()
		WorldMapFrame_Update()
	end)
	check(ok, "before the settings are read: no error")
	A.db = saved
end
WorldMapFrame:Hide()

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("Maps: %d checks", checks))
if table.getn(failures) == 0 then
	print("All maps checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
