--[[
	MinimapButton.lua -- the button on the minimap's edge.

	The Aegis: Pathfinder logo, in its own colours -- a dark disc with a red
	and gold rune ring, so it needs no border of ours. Hovering puts the
	accent ring round it.

	Click shows or hides the guide, right-click opens the options panel, and
	dragging walks it round the minimap's edge. The options panel's Appearance
	page (or /apg minimapbutton) hides it.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

-- A stock minimap button is a 30-pixel gold ring round a 20-pixel icon; the
-- logo is a solid disc, so at 32 it stood out as bigger than the rest.
local SIZE = 26
local RADIUS = 80           -- from the minimap's centre, where its buttons sit
local DEFAULT_ANGLE = 215   -- degrees anticlockwise from east: lower left

local button = CreateFrame("Button", "AegisPathfinderMinimapButton", Minimap)
AegisPathfinder.minimapbutton = button
button:SetWidth(SIZE)
button:SetHeight(SIZE)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
-- Mouse and movement switched on outright, as pfQuest's button does, rather
-- than left to the client's defaults: the button was reported as not
-- dragging round the minimap.
button:EnableMouse(true)
button:SetMovable(true)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:Hide()

-- The logo in its own colours: never tinted, whatever the theme.
local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetTexture(Theme.texture.minimapLogo)
icon:SetWidth(SIZE)
icon:SetHeight(SIZE)
icon:SetPoint("CENTER", button, "CENTER", 0, 0)

-- On hover, a ring in the theme's accent just outside the logo's own.
local ring = button:CreateTexture(nil, "OVERLAY")
ring:SetTexture(Theme.texture.circleBorder)
ring:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
ring:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
Theme:Tint(ring, "accent")
ring:Hide()

button.ring, button.icon = ring, icon

--- Put the button at `angle` degrees round the minimap's edge.
local function Place(angle)
	local r = math.rad(angle)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(r) * RADIUS, math.sin(r) * RADIUS)
end

-- While dragging: the angle from the minimap's centre to the cursor.
local function Dragging()
	local mx, my = Minimap:GetCenter()
	if not mx then return end
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
	AegisPathfinder.db.profile.minimapangle = angle
	Place(angle)
end

button:SetScript("OnDragStart", function()
	Theme:HideTip(this)
	this:SetScript("OnUpdate", Dragging)
end)
button:SetScript("OnDragStop", function()
	this:SetScript("OnUpdate", nil)
end)

button:SetScript("OnClick", function()
	if arg1 == "RightButton" then
		AegisPathfinder:ToggleConfigPanel()
	else
		AegisPathfinder:ToggleObjectivePanel()
	end
end)

-- Pressed: the logo sinks a pixel, as a button face would.
button:SetScript("OnMouseDown", function() icon:SetPoint("CENTER", button, "CENTER", 1, -1) end)
button:SetScript("OnMouseUp", function() icon:SetPoint("CENTER", button, "CENTER", 0, 0) end)

button:SetScript("OnEnter", function()
	ring:Show()
	Theme:ShowTip(this, "LEFT", "Aegis: Pathfinder v" .. (AegisPathfinder.version or "?"), {
		"Click to show or hide the guide",
		"Right-click for settings",
		"Drag to move this button",
	})
end)
button:SetScript("OnLeave", function()
	ring:Hide()
	Theme:HideTip(this)
end)

--- Show or hide the button to match the setting, where it was left.
function AegisPathfinder:UpdateMinimapButton()
	Place(self.db.profile.minimapangle or DEFAULT_ANGLE)
	if self.db.char.showminimapbutton == false then
		button:Hide()
	else
		button:Show()
	end
end

function AegisPathfinder:ToggleMinimapButton()
	self.db.char.showminimapbutton = self.db.char.showminimapbutton == false
	self:UpdateMinimapButton()
	if self.RefreshConfigPanel and self.optionsframe then self:RefreshConfigPanel() end
end
