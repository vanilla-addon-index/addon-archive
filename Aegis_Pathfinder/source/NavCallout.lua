--[[ NavCallout.lua -- the concept's signature navigation arrow.

	An arrow pointing at the current objective, the instruction under it, and
	the distance and ETA under that. It has no panel behind it: the concept
	dropped the `background` and `box-shadow` this block used to carry, so it
	floats directly on the game world.

	That is why everything here is shadowed. Over snow, over Un'Goro grass, over
	a lit doorway, unshadowed text at these weights simply disappears; the
	concept's `text-shadow: 0 1px 3px rgba(0,0,0,.9), 0 1px 8px rgba(0,0,0,.7)`
	is what makes it readable, and a 1.12 font string's SetShadowOffset /
	SetShadowColor is the closest equivalent. It is a single offset copy rather
	than a blur, so it is drawn at full opacity to carry the same weight.

	Drag it anywhere; the concept made the whole block a grab handle.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

local ARROW = 36        -- .glyph-wrap is 36x36
local WIDTH = 180       -- .nav-callout min-width


local frame = CreateFrame("Frame", "AegisPathfinderNavCallout", UIParent)
AegisPathfinder.navcallout = frame
frame:SetFrameStrata("LOW")
frame:SetWidth(WIDTH)
frame:SetHeight(ARROW + 46)
frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
frame:Hide()

--[[ The arrow.

	Its own frame so the texture can be rotated about the centre of a fixed
	box. The texture is drawn oversized inside that box: rotating a quad by
	SetTexCoord samples outside the 0..1 range at the corners, and at 45 degrees
	the corners of the source reach sqrt(2)/2 beyond the edge. Leaving that
	headroom is what stops the arrow's tips being clipped as it turns.
]]
local arrowBox = CreateFrame("Frame", nil, frame)
arrowBox:SetWidth(ARROW)
arrowBox:SetHeight(ARROW)
arrowBox:SetPoint("TOP", frame, "TOP", 0, 0)

local arrow = arrowBox:CreateTexture(nil, "ARTWORK")
Theme:Skin(arrow, "navArrow")      -- the theme's colour (Theme.lua)
arrow:SetAllPoints(arrowBox)

local instruction = frame:CreateFontString(nil, "OVERLAY")
Theme:SetFont(instruction, "body2", 14)
instruction:SetPoint("TOP", arrowBox, "BOTTOM", 0, -7)
instruction:SetJustifyH("CENTER")
instruction:SetTextColor(0.96, 0.95, 0.91)      -- #f6f2e8

local distance = frame:CreateFontString(nil, "OVERLAY")
Theme:SetFont(distance, "body2", 13)
distance:SetPoint("TOPRIGHT", instruction, "BOTTOM", -5, -6)
distance:SetJustifyH("RIGHT")
distance:SetTextColor(0.91, 0.60, 0.32)         -- #e79a52

local eta = frame:CreateFontString(nil, "OVERLAY")
Theme:SetFont(eta, "body2", 13)
eta:SetPoint("TOPLEFT", instruction, "BOTTOM", 5, -6)
eta:SetJustifyH("LEFT")
eta:SetTextColor(0.93, 0.90, 0.85)              -- #ece6d8

-- The concept's two-layer text-shadow, as the one offset shadow 1.12 offers.
for _, fs in ipairs({ instruction, distance, eta }) do
	fs:SetShadowOffset(0, -1)
	fs:SetShadowColor(0, 0, 0, 1)
end

frame.arrow, frame.arrowBox = arrow, arrowBox
frame.instruction, frame.distance, frame.eta = instruction, distance, eta


--[[ Rotate the arrow to a bearing, in radians, clockwise from north.

	1.12 has no SetRotation. The eight-argument form of SetTexCoord maps the
	texture onto an arbitrary quad, which is how vanilla addons turned minimap
	arrows, so the four corners are rotated about (0.5, 0.5) and handed over in
	the order the call wants: upper-left, lower-left, upper-right, lower-right.
]]
local function RotateTexture(tex, angle)
	local c, s = math.cos(angle), math.sin(angle)
	local function corner(x, y)
		x, y = x - 0.5, y - 0.5
		return 0.5 + x * c - y * s, 0.5 + x * s + y * c
	end
	local ulx, uly = corner(0, 0)
	local llx, lly = corner(0, 1)
	local urx, ury = corner(1, 0)
	local lrx, lry = corner(1, 1)
	tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end
AegisPathfinder.RotateTexture = RotateTexture

--[[ What the arrow says for each kind of step.

	Taken from the concept's NAV_PHRASES. An unmapped action falls through to
	"Follow the path", which is true of every step that has a waypoint at all.
]]
local PHRASES = {
	ACCEPT = "Head to the quest giver",
	TURNIN = "Head to the quest giver",
	COMPLETE = "Continue to the objective",
	KILL = "Continue to the objective",
	GRIND = "Continue to the objective",
	NOTE = "Follow the path",
	RUN = "Follow the path ahead",
	HEARTH = "Return to the inn",
	SETHEARTH = "Return to the inn",
	FLY = "Head to the flight master",
	GETFLIGHTPOINT = "Head to the flight master",
	BOAT = "Head to the dock",
	BUY = "Head to the vendor",
	USE = "Head to the vendor",
	TRAIN = "Head to the trainer",
}

--- Walking pace in yards per second, for the ETA. Base run speed in 1.12 is
--- 7 yd/s; a mount changes that, but the addon cannot see mount speed, so this
--- deliberately reads as an on-foot estimate rather than a promise.
local YARDS_PER_SECOND = 7

local function FormatEta(seconds)
	local m = math.floor(seconds / 60)
	local s = math.mod(math.floor(seconds), 60)
	return string.format("%d:%02d", m, s)
end
AegisPathfinder.FormatEta = FormatEta


--[[ Point the arrow at the current step.

	Everything shown here comes from the waypoint provider. With no provider,
	or no waypoint for this step, there is no bearing and no distance, so the
	callout hides rather than pointing somewhere arbitrary -- an arrow that is
	confidently wrong is worse than no arrow.
]]
function AegisPathfinder:UpdateNavCallout()
	if not self.db or not self.db.char.shownavcallout then
		frame:Hide()
		return
	end

	local action = self:GetObjectiveInfo(self.current)
	local bearing, yards = self:GetWaypointBearing()

	if not bearing then
		frame:Hide()
		return
	end

	--[[ Negated on purpose. `bearing` is clockwise from where the player faces,
		but RotateTexture turns the texture *coordinates*: sampling a quad
		rotated clockwise makes the image appear rotated counter-clockwise. So
		the arrow points clockwise by `bearing` when it is handed -bearing. ]]
	RotateTexture(arrow, -bearing)
	instruction:SetText(PHRASES[action] or "Follow the path")

	if yards then
		distance:SetText(string.format("%d yd", math.floor(yards + 0.5)))
		eta:SetText(FormatEta(math.max(1, yards / YARDS_PER_SECOND)))
	else
		-- A provider that gives a heading but no range: say the direction and
		-- stay quiet about how far, rather than inventing a number.
		distance:SetText("")
		eta:SetText("")
	end

	frame:Show()
end

--- Turn our arrow on or off, remembering the choice, and leaving the
--- waypoint addons' as they are.
function AegisPathfinder:ToggleNavCallout()
	self:SetArrow("pathfinder", not self:IsArrowOn("pathfinder"))
end


--[[ Keep it pointing while the player moves.

	The callout is refreshed when the step changes, but bearing and range
	change every time the player walks or turns. A separate driver frame does
	the ticking: the callout hides itself when there is no bearing, and a
	hidden frame gets no OnUpdate, so it could never notice one come back.
]]
local TICK = 0.1
local driver = CreateFrame("Frame")
local sinceTick = 0
driver:SetScript("OnUpdate", function()
	sinceTick = sinceTick + (arg1 or 0)
	if sinceTick < TICK then return end
	sinceTick = 0
	local self = AegisPathfinder
	if not self.db then return end
	-- Whatever the waypoint addon did with its arrow since the last tick,
	-- the Arrow setting stands -- including when ours is off.
	if self.EnforceArrowMode then self:EnforceArrowMode() end
	if self.db.char.shownavcallout and self.current then
		self:UpdateNavCallout()
	end
end)
frame.driver = driver

-- Drag: the concept makes the whole block the handle.
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function()
	this:StopMovingOrSizing()
	Theme:PositionSaver("navcallout")(this)
end)

frame:SetScript("OnShow", function()
	Theme:RestorePosition(this, "navcallout")
end)
