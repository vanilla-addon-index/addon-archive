-- TurtleHonorSpyEnhanced: minimap button
-- Standalone minimap button: left-click toggles overlay, right-click opens history.

local MINIMAP_ICON = "Interface\\Icons\\Inv_Misc_Bomb_04"
local minimapButton
local minimapAngle = 200

local GetDB = THSE.GetDB

local function UpdateMinimapButtonPosition()
	if not minimapButton then return end
	local angle = math.rad(minimapAngle)
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER",
		80 * math.cos(angle), 80 * math.sin(angle))
end

local function CreateMinimapButton()
	local hs = GetDB()
	if hs and hs.minimapAngle then minimapAngle = hs.minimapAngle end

	minimapButton = CreateFrame("Button", "HonorSpyMinimapButton", Minimap)
	minimapButton:SetWidth(31)
	minimapButton:SetHeight(31)
	minimapButton:SetFrameStrata("BACKGROUND")
	minimapButton:SetFrameLevel(4)
	minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
	icon:SetTexture(MINIMAP_ICON)
	icon:SetWidth(20)
	icon:SetHeight(20)
	icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	icon:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 7, -5)

	local border = minimapButton:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetWidth(53)
	border:SetHeight(53)
	border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT")

	minimapButton:EnableMouse(true)
	minimapButton:RegisterForDrag("LeftButton")
	minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	minimapButton:SetScript("OnClick", function()
		if arg1 == "RightButton" then
			THSE:HistoryOpen()
		else
			THSE:OverlayToggle()
		end
	end)

	minimapButton:SetScript("OnDragStart", function()
		this:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local s = UIParent:GetEffectiveScale()
			minimapAngle = math.mod(
				math.deg(math.atan2(py / s - my, px / s - mx)), 360)
			local db = GetDB()
			if db then db.minimapAngle = minimapAngle end
			UpdateMinimapButtonPosition()
		end)
	end)

	minimapButton:SetScript("OnDragStop", function()
		this:SetScript("OnUpdate", nil)
	end)

	minimapButton:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:AddLine("TurtleHonorSpyEnhanced", 1, 0.82, 0)
		GameTooltip:AddLine("Left-click: Toggle Overlay", 1, 1, 1)
		GameTooltip:AddLine("Right-click: Honor History", 1, 1, 1)
		GameTooltip:AddLine("Drag: Move button", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)

	minimapButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	UpdateMinimapButtonPosition()
end

-- ===== Show/Hide toggle =====
function THSE:MinimapToggle()
	if not minimapButton then return end
	if minimapButton:IsVisible() then
		minimapButton:Hide()
		local db = GetDB()
		if db then db.minimapHidden = true end
	else
		minimapButton:Show()
		local db = GetDB()
		if db then db.minimapHidden = false end
	end
end

-- ===== Init on world enter =====
local minimapInitFrame = CreateFrame("Frame")
minimapInitFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
minimapInitFrame:SetScript("OnEvent", function()
	if event ~= "PLAYER_ENTERING_WORLD" then return end
	minimapInitFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
	CreateMinimapButton()
	local db = GetDB()
	if db and db.minimapHidden then
		minimapButton:Hide()
	end
end)
