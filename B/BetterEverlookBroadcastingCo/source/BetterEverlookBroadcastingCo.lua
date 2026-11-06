local _G = _G or getfenv()

-- ============================================================================
-- Neutralize the built-in EverlookBroadcastingCo addon
-- ============================================================================
-- The original is loaded as part of FrameXML (before user addons), so its
-- XML frames (EBCMain, EBCFrame, EBC_Minimap) already exist and its Lua
-- globals (EBC_CreateFrame, ShowEBCMinimapDropdown, etc.) are already defined.
-- We must hide the original frames and replace its functions IMMEDIATELY
-- (at file-load time) so the original's VARIABLES_LOADED handler is harmless.

-- Save a reference to the original minimap button before we overwrite the global
local EBC_OrigMinimapButton = EBC_Minimap

-- Kill the original's frame-creation function so its VARIABLES_LOADED does nothing
EBC_CreateFrame = function() end

-- Hide the original XML frames
if EBCMain then
	EBCMain:Hide()
	EBCMain:UnregisterAllEvents()
end
if EBCFrame then
	EBCFrame:Hide()
end
if EBC_OrigMinimapButton then
	EBC_OrigMinimapButton:Hide()
	EBC_OrigMinimapButton:EnableMouse(false)
	EBC_OrigMinimapButton:SetScript("OnEnter", nil)
	EBC_OrigMinimapButton:SetScript("OnLeave", nil)
	EBC_OrigMinimapButton:SetScript("OnMouseUp", nil)
	EBC_OrigMinimapButton:SetScript("OnDragStart", nil)
	EBC_OrigMinimapButton:SetScript("OnDragStop", nil)
	EBC_OrigMinimapButton:ClearAllPoints()
	EBC_OrigMinimapButton:SetParent(UIParent)
	EBC_OrigMinimapButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -200, 200)
end

-- ============================================================================
-- SavedVariables defaults
-- ============================================================================

local EBC_DEFAULTS = {
	minimapAngle = 225,
	dropdownX = nil,
	dropdownY = nil,
	selectedStation = 0,
	dropdownOpen = false,
}

local function EBC_InitSavedVars()
	if not BetterEBC_Settings then
		BetterEBC_Settings = {}
	end
	for k, v in EBC_DEFAULTS do
		if BetterEBC_Settings[k] == nil then
			BetterEBC_Settings[k] = v
		end
	end
end

-- ============================================================================
-- Minimap button orbit helpers
-- ============================================================================

local EBC_MINIMAP_RADIUS = 80
local EBC_MinimapDragging = false

local function EBC_UpdateMinimapButtonPosition(button, angle)
	local rad = math.rad(angle)
	local x = math.cos(rad) * EBC_MINIMAP_RADIUS
	local y = math.sin(rad) * EBC_MINIMAP_RADIUS
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- ============================================================================
-- Minimap button (new name to avoid collision with the original)
-- ============================================================================

local function EBC_CreateMinimapButton()
	local btn = CreateFrame("Button", "BetterEBC_MinimapButton", Minimap)
	btn:SetWidth(33)
	btn:SetHeight(33)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	-- Icon
	local icon = btn:CreateTexture(nil, "BACKGROUND")
	icon:SetTexture("Interface\\Icons\\INV_Gizmo_GoblinBoomBox_01")
	icon:SetWidth(18)
	icon:SetHeight(18)
	icon:SetPoint("TOPLEFT", 6, -5)

	-- Border
	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetWidth(52)
	border:SetHeight(52)
	border:SetPoint("TOPLEFT", 0, 0)

	-- Position from saved angle
	EBC_UpdateMinimapButtonPosition(btn, BetterEBC_Settings.minimapAngle)

	-- Tooltip
	btn:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(EBC_TITLE)
		GameTooltip:AddLine(EBC_LINE1, 1, 1, 1)
		GameTooltip:AddLine(EBC_LINE2, 1, 1, 1)
		GameTooltip:AddLine(EBC_LINE3, 1, 1, 1)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Ctrl+drag orbit logic
	btn:SetScript("OnMouseDown", function()
		if IsControlKeyDown() and arg1 == "LeftButton" then
			EBC_MinimapDragging = true
			btn:LockHighlight()
		end
	end)

	btn:SetScript("OnUpdate", function()
		if not EBC_MinimapDragging then return end
		local cx, cy = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		cx = cx / scale
		cy = cy / scale
		local mx, my = Minimap:GetCenter()
		local angle = math.deg(math.atan2(cy - my, cx - mx))
		BetterEBC_Settings.minimapAngle = angle
		EBC_UpdateMinimapButtonPosition(btn, angle)
	end)

	btn:SetScript("OnMouseUp", function()
		if EBC_MinimapDragging then
			EBC_MinimapDragging = false
			btn:UnlockHighlight()
			return
		end
		if arg1 == "LeftButton" then
			ShowEBCMinimapDropdown()
		elseif arg1 == "RightButton" then
			if IsControlKeyDown() then
				BetterEBC_Settings.minimapAngle = EBC_DEFAULTS.minimapAngle
				EBC_UpdateMinimapButtonPosition(btn, EBC_DEFAULTS.minimapAngle)
			end
		end
	end)

	return btn
end

-- ============================================================================
-- Radio window toggle (overrides the original global)
-- ============================================================================

function ShowEBCMinimapDropdown()
	if BetterEBC_Dropdown and BetterEBC_Dropdown:IsVisible() then
		BetterEBC_Dropdown:Hide()
	elseif BetterEBC_Dropdown then
		BetterEBC_Dropdown:Show()
	end
end

-- ============================================================================
-- Tune in / out (overrides the original global)
-- ============================================================================

function EBC_TuneIn(station)
	local s1 = BetterEBC_Dropdown.CheckButton1:GetChecked() or false
	local s2 = BetterEBC_Dropdown.CheckButton2:GetChecked() or false

	if not s1 and not s2 then
		EBC_Alert(EBC_STOPPED .. EBC_TITLE .. EBC_FORNOW)
		StopMusic()
		BetterEBC_Settings.selectedStation = 0
		return
	end

	BetterEBC_Dropdown.MuteButton:SetBackdrop({bgFile = "Interface\\Buttons\\UI-GuildButton-MOTD-Up"})
	SetCVar("EnableMusic", 1)
	SendChatMessage(".radio " .. station, "SAY", nil)
	EBC_Alert(EBC_TUNEDINTO .. _G["EBC_STATION" .. station] .. "!")
	BetterEBC_Settings.selectedStation = station
end

function EBC_Alert(txt)
	UIErrorsFrame:AddMessage(txt, 1, 1, 1, 1, 4)
	DEFAULT_CHAT_FRAME:AddMessage(txt)
end

-- ============================================================================
-- Restore saved state (checkboxes only — server remembers the actual stream)
-- ============================================================================

local function EBC_RestoreState()
	local sel = BetterEBC_Settings.selectedStation
	if sel == 1 then
		BetterEBC_Dropdown.CheckButton1:SetChecked(1)
		BetterEBC_Dropdown.CheckButton2:SetChecked(0)
	elseif sel == 2 then
		BetterEBC_Dropdown.CheckButton1:SetChecked(0)
		BetterEBC_Dropdown.CheckButton2:SetChecked(1)
	else
		BetterEBC_Dropdown.CheckButton1:SetChecked(0)
		BetterEBC_Dropdown.CheckButton2:SetChecked(0)
	end

	if BetterEBC_Settings.dropdownOpen then
		BetterEBC_Dropdown:Show()
	end
end

-- ============================================================================
-- Create the radio window (all new frame names to avoid collisions)
-- ============================================================================

local function EBC_CreateRadioWindow()
	local dd = CreateFrame("Frame", "BetterEBC_Dropdown", UIParent)
	dd:SetFrameStrata("DIALOG")
	dd:SetWidth(230)
	dd:SetHeight(145)
	dd:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	dd:SetMovable(true)
	dd:SetClampedToScreen(true)
	dd:EnableMouse(true)
	dd:Hide()

	-- Escape to close
	table.insert(UISpecialFrames, "BetterEBC_Dropdown")

	-- Save open/closed state
	dd:SetScript("OnShow", function()
		if BetterEBC_Settings then BetterEBC_Settings.dropdownOpen = true end
	end)
	dd:SetScript("OnHide", function()
		if BetterEBC_Settings then BetterEBC_Settings.dropdownOpen = false end
	end)

	-- ========================================================================
	-- Title bar (drag handle)
	-- ========================================================================
	local titleBar = CreateFrame("Frame", nil, dd)
	titleBar:SetHeight(24)
	titleBar:SetPoint("TOPLEFT", dd, "TOPLEFT", 4, -4)
	titleBar:SetPoint("TOPRIGHT", dd, "TOPRIGHT", -28, -4)
	titleBar:EnableMouse(true)
	titleBar:RegisterForDrag("LeftButton")
	titleBar:SetScript("OnDragStart", function()
		dd:StartMoving()
	end)
	titleBar:SetScript("OnDragStop", function()
		dd:StopMovingOrSizing()
		local x, y = dd:GetCenter()
		BetterEBC_Settings.dropdownX = x
		BetterEBC_Settings.dropdownY = y
	end)

	-- Title text
	local titleText = dd:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titleText:SetPoint("TOPLEFT", dd, "TOPLEFT", 13, -10)
	titleText:SetFont("Fonts\\FRIZQT__.TTF", 14)
	titleText:SetText("|cffffd000" .. EBC_TITLE)

	-- Separator line under title
	local sep = dd:CreateTexture(nil, "ARTWORK")
	sep:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
	sep:SetTexCoord(0.81, 0.94, 0.5, 1)
	sep:SetHeight(2)
	sep:SetPoint("TOPLEFT", dd, "TOPLEFT", 8, -28)
	sep:SetPoint("TOPRIGHT", dd, "TOPRIGHT", -8, -28)
	sep:SetVertexColor(0.6, 0.6, 0.6, 0.8)

	-- Close button
	local closeBtn = CreateFrame("Button", nil, dd, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", dd, "TOPRIGHT", -2, -2)
	closeBtn:SetScript("OnClick", function()
		dd:Hide()
	end)

	-- ========================================================================
	-- Station checkboxes
	-- ========================================================================

	-- Station 1
	dd.CheckButton1 = CreateFrame("CheckButton", "BetterEBC_Check1", dd, "UICheckButtonTemplate")
	dd.CheckButton1:SetPoint("TOPLEFT", dd, "TOPLEFT", 12, -36)
	dd.CheckButton1:SetWidth(24)
	dd.CheckButton1:SetHeight(24)

	dd.CheckButton1:SetScript("OnEnter", function()
		local state = EBC_TUNEIN
		if this:GetChecked() == 1 then state = EBC_TUNEOUT end
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText("|cffffd000" .. state, 1, 1, 1, 1)
	end)
	dd.CheckButton1:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	dd.CheckButton1:SetScript("OnClick", function()
		local state = EBC_TUNEIN
		if this:GetChecked() == 1 then state = EBC_TUNEOUT end
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText("|cffffd000" .. state, 1, 1, 1, 1)
		dd.CheckButton2:SetChecked(0)
		EBC_TuneIn(1)
	end)

	local label1 = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label1:SetFont("Fonts\\FRIZQT__.TTF", 12)
	label1:SetText(EBC_STATION1)
	label1:SetPoint("LEFT", dd.CheckButton1, "RIGHT", 2, 0)

	-- Station 2
	dd.CheckButton2 = CreateFrame("CheckButton", "BetterEBC_Check2", dd, "UICheckButtonTemplate")
	dd.CheckButton2:SetPoint("TOPLEFT", dd.CheckButton1, "BOTTOMLEFT", 0, -4)
	dd.CheckButton2:SetWidth(24)
	dd.CheckButton2:SetHeight(24)

	dd.CheckButton2:SetScript("OnEnter", function()
		local state = EBC_TUNEIN
		if this:GetChecked() == 1 then state = EBC_TUNEOUT end
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText("|cffffd000" .. state, 1, 1, 1, 1)
	end)
	dd.CheckButton2:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	dd.CheckButton2:SetScript("OnClick", function()
		local state = EBC_TUNEIN
		if this:GetChecked() == 1 then state = EBC_TUNEOUT end
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText("|cffffd000" .. state, 1, 1, 1, 1)
		dd.CheckButton1:SetChecked(0)
		EBC_TuneIn(2)
	end)

	local label2 = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label2:SetFont("Fonts\\FRIZQT__.TTF", 12)
	label2:SetText(EBC_STATION2)
	label2:SetPoint("LEFT", dd.CheckButton2, "RIGHT", 2, 0)

	-- ========================================================================
	-- Volume section
	-- ========================================================================

	-- Volume label
	local volLabel = dd:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	volLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
	volLabel:SetText("|cffffd000Volume:")
	volLabel:SetPoint("BOTTOMLEFT", dd, "BOTTOMLEFT", 12, 18)

	-- Slider
	dd.slider = CreateFrame("Slider", "BetterEBC_Slider", dd, "OptionsSliderTemplate")
	dd.slider:SetPoint("LEFT", volLabel, "RIGHT", 8, 0)
	dd.slider:SetWidth(100)
	dd.slider:SetHeight(16)
	dd.slider:SetOrientation("HORIZONTAL")
	dd.slider:SetMinMaxValues(0, 100)
	dd.slider:SetValue(math.floor(GetCVar("MusicVolume") * 100))
	dd.slider:SetValueStep(1)

	-- Hide default slider labels
	getglobal(dd.slider:GetName() .. "Low"):SetText("")
	getglobal(dd.slider:GetName() .. "High"):SetText("")
	getglobal(dd.slider:GetName() .. "Text"):SetText("")

	-- Volume value text
	dd.VolText = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	dd.VolText:SetFont("Fonts\\FRIZQT__.TTF", 11)
	dd.VolText:SetText(dd.slider:GetValue())
	dd.VolText:SetPoint("LEFT", dd.slider, "RIGHT", 6, 0)
	dd.VolText:SetWidth(24)
	dd.VolText:SetJustifyH("RIGHT")

	dd.slider:EnableMouseWheel(true)
	dd.slider:SetScript("OnValueChanged", function()
		SetCVar("MusicVolume", dd.slider:GetValue() / 100)
		dd.VolText:SetText(dd.slider:GetValue())
		PlaySound("igMiniMapZoomIn", "SFX")
	end)
	dd.slider:SetScript("OnMouseWheel", function()
		local val = dd.slider:GetValue()
		if arg1 == 1 then
			val = val + 10
		else
			val = val - 10
		end
		if val < 0 then val = 0 end
		if val > 100 then val = 100 end
		SetCVar("MusicVolume", val / 100)
		dd.slider:SetValue(val)
	end)

	-- Mute button
	dd.MuteButton = CreateFrame("Frame", nil, dd)
	dd.MuteButton:SetWidth(18)
	dd.MuteButton:SetHeight(18)
	dd.MuteButton:SetPoint("LEFT", dd.VolText, "RIGHT", 6, 0)

	if GetCVar("EnableMusic") == "1" then
		dd.MuteButton:SetBackdrop({bgFile = "Interface\\Buttons\\UI-GuildButton-MOTD-Up"})
	else
		dd.MuteButton:SetBackdrop({bgFile = "Interface\\Buttons\\UI-GuildButton-MOTD-Disabled"})
	end

	dd.MuteButton:EnableMouse(true)
	dd.MuteButton:SetScript("OnMouseDown", function()
		if GetCVar("EnableMusic") == "1" then
			dd.MuteButton:SetBackdrop({bgFile = "Interface\\Buttons\\UI-GuildButton-MOTD-Disabled"})
			SetCVar("EnableMusic", 0)
			dd.CheckButton1:SetChecked(0)
			dd.CheckButton2:SetChecked(0)
			StopMusic()
			BetterEBC_Settings.selectedStation = 0
			GameTooltip:SetText("|cffffd000 " .. EBC_UNMUTE, 1, 1, 1, 1)
		else
			dd.MuteButton:SetBackdrop({bgFile = "Interface\\Buttons\\UI-GuildButton-MOTD-Up"})
			GameTooltip:SetText("|cffffd000 " .. EBC_MUTE, 1, 1, 1, 1)
			SetCVar("EnableMusic", 1)
		end
	end)
	dd.MuteButton:SetScript("OnEnter", function()
		local state = EBC_UNMUTE
		if GetCVar("EnableMusic") == "1" then state = EBC_MUTE end
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText("|cffffd000" .. state, 1, 1, 1, 1)
	end)
	dd.MuteButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- ========================================================================
	-- Position the window
	-- ========================================================================
	if BetterEBC_Settings.dropdownX and BetterEBC_Settings.dropdownY then
		dd:ClearAllPoints()
		dd:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
			BetterEBC_Settings.dropdownX, BetterEBC_Settings.dropdownY)
	else
		dd:SetPoint("TOPRIGHT", BetterEBC_MinimapButton, "BOTTOMLEFT", 10, 10)
	end

	return dd
end

-- ============================================================================
-- Slash commands
-- ============================================================================

SLASH_EBC1 = "/radio"
SLASH_EBC2 = "/ebc"
SlashCmdList["EBC"] = function()
	ShowEBCMinimapDropdown()
end

-- ============================================================================
-- Also kill any original dropdown that might get created despite our override.
-- The original's VARIABLES_LOADED handler references a local `EBC_Frame`, so
-- even though we nuked the global EBC_CreateFrame, the local event handler in
-- the built-in's Lua closure might still call the OLD function through its
-- local reference.  Belt-and-suspenders: hide it after everything loads.
-- ============================================================================

local function EBC_NukeOriginalDropdown()
	-- If the original somehow created an EBCMinimapDropdown, hide it
	local origDD = getglobal("EBCMinimapDropdown")
	if origDD and origDD ~= BetterEBC_Dropdown then
		origDD:Hide()
		origDD:EnableMouse(false)
		origDD:ClearAllPoints()
		origDD:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
		origDD:SetScript("OnShow", function() this:Hide() end)
	end

	-- Double-check the original minimap button is still dead
	local origBtn = EBC_OrigMinimapButton
	if origBtn then
		origBtn:Hide()
	end
	-- Also check the global in case something recreated it
	local globalBtn = getglobal("EBC_Minimap")
	if globalBtn and globalBtn ~= BetterEBC_MinimapButton then
		globalBtn:Hide()
		globalBtn:EnableMouse(false)
		globalBtn:ClearAllPoints()
		globalBtn:SetParent(UIParent)
		globalBtn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -200, 200)
	end
end

-- ============================================================================
-- Event handler — bootstrap everything
-- ============================================================================

local EBC_EventFrame = CreateFrame("Frame")
EBC_EventFrame:RegisterEvent("VARIABLES_LOADED")
EBC_EventFrame:RegisterEvent("PLAYER_LOGOUT")

EBC_EventFrame:SetScript("OnEvent", function()
	if event == "VARIABLES_LOADED" then
		StopMusic()
		EBC_InitSavedVars()
		EBC_CreateMinimapButton()
		EBC_CreateRadioWindow()
		EBC_RestoreState()
		-- Delayed cleanup: nuke anything the original managed to create
		EBC_NukeOriginalDropdown()
	elseif event == "PLAYER_LOGOUT" then
		-- dropdownOpen is already tracked via OnShow/OnHide, nothing extra needed
	end
end)
