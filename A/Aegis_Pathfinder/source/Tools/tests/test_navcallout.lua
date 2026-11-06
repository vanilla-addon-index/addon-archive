--[[
	Tests for the navigation callout.

	The concept's signature element, and the one with the most arithmetic
	behind it: a texture rotated by texcoord, a compass bearing relative to
	where the player is facing, and an ETA. None of that is visible off-client,
	and a callout that points confidently in the wrong direction is worse than
	no callout, so the maths is checked here rather than in the game.

	Run:  lua5.1 Tools/tests/test_navcallout.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

AegisPathfinder = {
	current = 1,
	actions = { "ACCEPT" }, quests = {}, tags = {},
	db = { char = { shownavcallout = true }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder:GetObjectiveInfo(i) return self.actions[i] end
function AegisPathfinder:GetWaypointBearing() return self.__bearing, self.__yards end

dofile("Theme.lua")
dofile("NavCallout.lua")

-- ToggleNavCallout goes through the arrow setting in Navigation.lua, which
-- enumerates the world map as it loads; lift just that block.
do
	local nav = io.open("Navigation.lua"):read("*a")
	local from = string.find(nav, "--[[ Which arrows point", 1, true)
	local to = string.find(nav, "-- Helper to get valid zone data", 1, true)
	assert(from and to, "could not find the arrow block in Navigation.lua")
	assert(loadstring(string.sub(nav, from, to - 1)))()
end
function AegisPathfinder:ClearWaypoint() end
function AegisPathfinder:ForceWaypointUpdate() end

local Theme = AegisPathfinder.Theme
local frame = AegisPathfinder.navcallout

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
local function close(a, b, tol)
	return a and math.abs(a - b) < (tol or 0.0001)
end

-- Construction ---------------------------------------------------------------

check(frame ~= nil, "the callout was not built")
check(frame.arrow:GetTexture() == Theme.texture.navArrow,
	"the arrow should draw the generated gradient texture, got '%s'",
	tostring(frame.arrow:GetTexture()))
check(not frame:IsShown(), "the callout starts hidden until there is a bearing")

--[[ No panel behind it.

	The concept dropped the callout's background and shadow, so it floats on
	the game world. That makes the text shadows load-bearing rather than
	decorative: without them the instruction vanishes over snow. ]]
local backdrops = 0
for _, r in ipairs(frame.__regions) do
	if r.__kind == "Texture" then backdrops = backdrops + 1 end
end
check(backdrops == 0,
	"the callout should draw no background of its own, found %d textures", backdrops)
for _, name in ipairs({ "instruction", "distance", "eta" }) do
	local fs = frame[name]
	check(fs.__shadowColor ~= nil, "%s has no shadow colour set", name)
	check(fs.__shadowOffset ~= nil, "%s has no shadow offset set", name)
end

-- Rotation -------------------------------------------------------------------

--[[ The eight-argument SetTexCoord maps the texture onto a rotated quad.
	At zero the mapping must be the identity, or the arrow is skewed before it
	has turned at all. ]]
local tex = UIParent:CreateTexture(nil, "ARTWORK")
AegisPathfinder.RotateTexture(tex, 0)
local c = tex.__texcoord
check(c ~= nil and table.getn(c) == 8,
	"a rotation should set all eight texture coordinates")
if c and table.getn(c) == 8 then
	check(close(c[1], 0) and close(c[2], 0), "at zero the upper-left corner is (0,0)")
	check(close(c[3], 0) and close(c[4], 1), "at zero the lower-left corner is (0,1)")
	check(close(c[5], 1) and close(c[6], 0), "at zero the upper-right corner is (1,0)")
	check(close(c[7], 1) and close(c[8], 1), "at zero the lower-right corner is (1,1)")
end

-- A quarter turn must map corner onto corner, not scale the quad.
AegisPathfinder.RotateTexture(tex, math.pi / 2)
c = tex.__texcoord
check(close(c[1], 1) and close(c[2], 0),
	"a quarter turn should carry the upper-left corner onto (1,0), got (%.3f, %.3f)",
	c[1], c[2])

-- The rotation must stay a rotation: opposite corners keep their distance.
for _, angle in ipairs({ 0.3, 1.1, 2.7, 5.9 }) do
	AegisPathfinder.RotateTexture(tex, angle)
	c = tex.__texcoord
	local dx, dy = c[7] - c[1], c[8] - c[2]
	check(close(math.sqrt(dx * dx + dy * dy), math.sqrt(2), 0.001),
		"at %.1f rad the diagonal should stay sqrt(2), got %.4f",
		angle, math.sqrt(dx * dx + dy * dy))
end

-- ETA -------------------------------------------------------------------------

check(AegisPathfinder.FormatEta(0) == "0:00", "zero formats as 0:00")
check(AegisPathfinder.FormatEta(9) == "0:09", "seconds are zero-padded, got '%s'",
	AegisPathfinder.FormatEta(9))
check(AegisPathfinder.FormatEta(65) == "1:05", "65s is 1:05, got '%s'",
	AegisPathfinder.FormatEta(65))
check(AegisPathfinder.FormatEta(600) == "10:00", "600s is 10:00, got '%s'",
	AegisPathfinder.FormatEta(600))

-- Rendering -------------------------------------------------------------------

-- No bearing means no callout: an arrow that is confidently wrong is worse
-- than no arrow at all.
AegisPathfinder.__bearing, AegisPathfinder.__yards = nil, nil
AegisPathfinder:UpdateNavCallout()
check(not frame:IsShown(), "with no bearing the callout hides")

AegisPathfinder.__bearing, AegisPathfinder.__yards = 0.5, 140
AegisPathfinder:UpdateNavCallout()
check(frame:IsShown(), "with a bearing the callout shows")
check(frame.instruction:GetText() == "Head to the quest giver",
	"ACCEPT should read 'Head to the quest giver', got '%s'",
	tostring(frame.instruction:GetText()))
check(frame.distance:GetText() == "140 yd",
	"distance renders in yards, got '%s'", tostring(frame.distance:GetText()))
check(frame.eta:GetText() == "0:20",
	"140 yards at 7 yd/s is 20 seconds, got '%s'", tostring(frame.eta:GetText()))

-- The sign is pinned: the callout hands RotateTexture the negated bearing,
-- because rotating the texture coordinates turns the image the other way.
-- Checked against a reference rotation so a stray sign flip cannot slip back.
local ref = UIParent:CreateTexture(nil, "ARTWORK")
AegisPathfinder.RotateTexture(ref, -0.5)
local got = frame.arrow.__texcoord
local same = got ~= nil
for i = 1, 8 do
	if not got or not close(got[i], ref.__texcoord[i]) then same = false end
end
check(same, "a bearing of 0.5 should rotate the texture by -0.5")

-- A provider that gives a heading but no range says nothing about distance.
AegisPathfinder.__yards = nil
AegisPathfinder:UpdateNavCallout()
check(frame:IsShown(), "a bearing with no range still points")
check(frame.distance:GetText() == "",
	"distance stays blank rather than inventing a number, got '%s'",
	tostring(frame.distance:GetText()))
check(frame.eta:GetText() == "", "and so does the ETA")

-- Phrasing follows the action, per the concept's NAV_PHRASES.
AegisPathfinder.__yards = 50
for action, expected in pairs({
	BOAT = "Head to the dock",
	FLY = "Head to the flight master",
	SETHEARTH = "Return to the inn",
	BUY = "Head to the vendor",
	COMPLETE = "Continue to the objective",
}) do
	AegisPathfinder.actions = { action }
	AegisPathfinder:UpdateNavCallout()
	check(frame.instruction:GetText() == expected,
		"%s should read '%s', got '%s'", action, expected,
		tostring(frame.instruction:GetText()))
end

AegisPathfinder.actions = { "SOMETHINGELSE" }
AegisPathfinder:UpdateNavCallout()
check(frame.instruction:GetText() == "Follow the path",
	"an unmapped action falls back, got '%s'", tostring(frame.instruction:GetText()))

-- The driver keeps it pointing as the player moves, and keeps ticking while
-- the callout itself is hidden so it can come back.
AegisPathfinder.actions = { "ACCEPT" }
AegisPathfinder.__bearing, AegisPathfinder.__yards = nil, nil
AegisPathfinder:UpdateNavCallout()
check(not frame:IsShown(), "hidden with no bearing")
AegisPathfinder.__bearing, AegisPathfinder.__yards = 1.0, 30
local tick = frame.driver:GetScript("OnUpdate")
arg1 = 0.05; tick()
check(not frame:IsShown(), "the driver waits out its throttle before redrawing")
arg1 = 0.06; tick()
check(frame:IsShown(), "and then brings the callout back once a bearing appears")
check(frame.distance:GetText() == "30 yd", "with the new range, got '%s'",
	tostring(frame.distance:GetText()))

-- Turned off, it stays off whatever the bearing says.
AegisPathfinder.db.char.shownavcallout = false
AegisPathfinder:UpdateNavCallout()
check(not frame:IsShown(), "the callout hides when switched off")
AegisPathfinder:ToggleNavCallout()
check(AegisPathfinder.db.char.shownavcallout == true, "toggling switches it back on")
check(frame:IsShown(), "and it reappears")
-- Ours was switched off with no arrow setting saved: a character from before
-- the setting, who was following TomTom's arrow. Toggling ours back on
-- leaves TomTom's as it was, so both point.
check(AegisPathfinder:IsArrowOn("pathfinder") and AegisPathfinder:IsArrowOn("tomtom"),
	"toggling ours leaves TomTom's arrow as it was")
AegisPathfinder:ToggleNavCallout()
check(not AegisPathfinder:IsArrowOn("pathfinder") and AegisPathfinder:IsArrowOn("tomtom") and not frame:IsShown(),
	"and toggling ours off again leaves TomTom's alone too")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("NavCallout: %d checks", checks))
if table.getn(failures) == 0 then
	print("All nav callout checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
