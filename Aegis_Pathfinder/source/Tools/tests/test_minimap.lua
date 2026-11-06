--[[
	Tests for the minimap button.

	That it is drawn from the theme, that each click does what its tooltip
	says, that dragging walks it round the minimap's edge and is remembered,
	and that the setting hides it.

	Run:  lua5.1 Tools/tests/test_minimap.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

AegisPathfinder = {
	db = { char = { showminimapbutton = true }, profile = {} },
}
function AegisPathfinder:ToggleObjectivePanel() self.__guide = (self.__guide or 0) + 1 end
function AegisPathfinder:ToggleConfigPanel() self.__config = (self.__config or 0) + 1 end

dofile("Theme.lua")
dofile("MinimapButton.lua")

local Theme = AegisPathfinder.Theme
local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
local function fire(f, script, a1)
	local h = f:GetScript(script)
	assert(h, "no " .. script .. " script")
	local oldThis, oldArg = this, arg1
	this, arg1 = f, a1
	h()
	this, arg1 = oldThis, oldArg
end

local button = AegisPathfinder.minimapbutton

-- Drawn from the theme ------------------------------------------------------------

check(button:GetParent() == Minimap, "the button lives on the minimap")
check(button.icon:GetTexture() == Theme.texture.minimapLogo,
	"it carries the Aegis: Pathfinder logo, not Blizzard's quest-log book, got %s",
	tostring(button.icon:GetTexture()))
-- 32 filled the stock buttons' whole frame with a solid disc, and was
-- reported as bigger than the other buttons round the minimap.
check(button.icon:GetWidth() == button:GetWidth() and button:GetWidth() == 26,
	"filling a button inside the stock buttons' 30-pixel ring, got %s", tostring(button:GetWidth()))
check(button.icon.__color == nil or (button.icon.__color[1] == 1 and button.icon.__color[2] == 1
	and button.icon.__color[3] == 1), "in its own colours, not tinted")
check(button.ring:GetTexture() == Theme.texture.circleBorder and not button.ring:IsShown(),
	"the logo is its own disc and ring: ours waits for a hover")
check(not button:IsShown(), "and it waits for the saved settings before showing")

-- Placement ------------------------------------------------------------------------

AegisPathfinder:UpdateMinimapButton()
check(button:IsShown(), "shown by default")
local mx, my = Minimap:GetCenter()
local function angleAndRadius()
	local bx, by = button:GetCenter()
	local dx, dy = bx - mx, by - my
	return math.deg(math.atan2(dy, dx)), math.sqrt(dx * dx + dy * dy)
end
local a, r = angleAndRadius()
check(math.abs(r - 80) < 0.01, "it sits on the minimap's edge, %s from its centre", r)
check(math.abs(((a + 360) % 360) - 215) < 0.01, "at the lower left by default, got %s degrees", a)

-- Clicks ----------------------------------------------------------------------------

check(button.__clicks and button.__clicks[1] == "LeftButtonUp" and button.__clicks[2] == "RightButtonUp",
	"it answers both buttons")
fire(button, "OnClick", "LeftButton")
check(AegisPathfinder.__guide == 1 and not AegisPathfinder.__config, "a click toggles the guide")
fire(button, "OnClick", "RightButton")
check(AegisPathfinder.__config == 1 and AegisPathfinder.__guide == 1,
	"a right-click opens the options panel, where the old menu's settings all live")

-- Dragging round the edge -------------------------------------------------------------

check(button.__dragButton == "LeftButton", "it drags with the left button")
check(button:IsMouseEnabled() and button:IsMovable(), "with the mouse and movement switched on outright")
fire(button, "OnDragStart")
local drag = button:GetScript("OnUpdate")
check(drag ~= nil, "dragging follows the cursor")
-- Straight up from the minimap's centre, and a long way off: the button stays
-- on the edge, at the cursor's angle.
stub.cursor = { mx, my + 300 }
drag()
a, r = angleAndRadius()
check(math.abs(a - 90) < 0.01 and math.abs(r - 80) < 0.01,
	"it follows the cursor round the edge, got %s degrees at %s", a, r)
check(math.abs(AegisPathfinder.db.profile.minimapangle - 90) < 0.01, "and the angle is saved")
fire(button, "OnDragStop")
check(button:GetScript("OnUpdate") == nil, "letting go stops it")

AegisPathfinder:UpdateMinimapButton()
a = angleAndRadius()
check(math.abs(a - 90) < 0.01, "and it is put back there next time, got %s", a)

-- The tooltip says what the clicks do -------------------------------------------------------

fire(button, "OnEnter")
local tip = Theme.tip
local lines = {}
for _, fs in ipairs(tip.lines) do
	if fs:IsShown() then table.insert(lines, fs:GetText()) end
end
local said = table.concat(lines, " / ")
check(tip:IsShown() and tip.owner == button, "hovering shows the addon's own tooltip, not GameTooltip")
check(string.find(said, "Click", 1, true) and string.find(said, "Right-click", 1, true)
	and string.find(said, "Drag", 1, true),
	"the tooltip explains click, right-click and drag, got '%s'", said)
check(button.ring:IsShown() and button.ring.__color[2] > 0.7, "and the accent ring comes up on hover")
fire(button, "OnLeave")
check(not button.ring:IsShown(), "and goes again")
check(not tip:IsShown(), "and the tooltip goes")

-- Hiding it --------------------------------------------------------------------------------

AegisPathfinder:ToggleMinimapButton()
check(AegisPathfinder.db.char.showminimapbutton == false and not button:IsShown(),
	"the setting hides it")
AegisPathfinder:ToggleMinimapButton()
check(AegisPathfinder.db.char.showminimapbutton == true and button:IsShown(),
	"and brings it back")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Minimap: %d checks", checks))
if table.getn(failures) == 0 then
	print("All minimap checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
