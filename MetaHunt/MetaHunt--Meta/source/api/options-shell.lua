MetaHuntOptions = nil
local MTH_OPTIONS_SETUP = {}     -- Track which frames have been set up
MTH_OPTIONS_CONST = MTH_OPTIONS_CONST or {}
MTH_OPTIONS_CONST.NAV_DEFAULT_WIDTH = MTH_OPTIONS_CONST.NAV_DEFAULT_WIDTH or 120
MTH_OPTIONS_CONST.WINDOW_PADDING = MTH_OPTIONS_CONST.WINDOW_PADDING or 12
MTH_OPTIONS_CONST.CONTENT_TOP_OFFSET = MTH_OPTIONS_CONST.CONTENT_TOP_OFFSET or -30
MTH_OPTIONS_CONST.CONTENT_HEIGHT = MTH_OPTIONS_CONST.CONTENT_HEIGHT or 600
MTH_OPTIONS_CONST.CLOSE_BTN_SIZE = MTH_OPTIONS_CONST.CLOSE_BTN_SIZE or 22
MTH_OPTIONS_CONST.CLOSE_BTN_OFFSET_X = MTH_OPTIONS_CONST.CLOSE_BTN_OFFSET_X or -8
MTH_OPTIONS_CONST.CLOSE_BTN_OFFSET_Y = MTH_OPTIONS_CONST.CLOSE_BTN_OFFSET_Y or -8
local MTH_OPTIONS_SHELL_READY = MTH_OptionsRequire and MTH_OptionsRequire("options-shell", {
	"MTH_GetFrame",
	"MTH_BuildOptionsTree",
})

local function MTH_OPT_L(key, default)
	if MTH and MTH.GetLocalization then
		return MTH:GetLocalization(key, default)
	end
	return default or key
end

-- Capture our PizzaSauce instance for the options-window open animation (guarded).
local MTH_OPT_Sauce = PizzaSauce
local function MTH_OPT_AnimateOpen(frame)
	if not MTH_OPT_Sauce or not frame then return end
	if type(MTH_FX_IsEnabled) == "function" and not MTH_FX_IsEnabled("ui.options") then return end
	-- Hide alpha this frame so there is no one-frame opaque flash before onStart.
	if type(frame.SetAlpha) == "function" then frame:SetAlpha(0) end
	-- Bigger travel + a springy "outBack" overshoot so the window clearly
	-- pops up into place instead of a subtle nudge.
	MTH_OPT_Sauce:SlideIn(frame, "UP", 110, 0.5, "outBack")
end

-- Fade the active settings panel when switching options tabs, unless disabled.
local function MTH_OPT_AnimateTabContent(tabKey)
	if not MTH_OPT_Sauce then return end
	if type(MTH_FX_IsEnabled) == "function" and not MTH_FX_IsEnabled("ui.optiontabs") then return end
	if type(MTH_OPTIONS_TABS) ~= "table" then return end
	for i = 1, table.getn(MTH_OPTIONS_TABS) do
		if MTH_OPTIONS_TABS[i].key == tabKey then
			local frame = MTH_GetFrame(MTH_OPTIONS_TABS[i].frame)
			if frame then
				if type(frame.SetAlpha) == "function" then frame:SetAlpha(0) end
				-- Slide the panel in from the right while fading so the content
				-- visibly moves, not just brightens.
				MTH_OPT_Sauce:SlideIn(frame, "RIGHT", 55, 0.3, "outCubic")
			end
			return
		end
	end
end

-- Slide the options window down and out before hiding it, unless disabled.
local function MTH_OPT_AnimateClose()
	local frame = MetaHuntOptions
	if not frame then return end
	if not MTH_OPT_Sauce
		or (type(MTH_FX_IsEnabled) == "function" and not MTH_FX_IsEnabled("ui.optionsclose")) then
		frame:SetAlpha(1)
		frame:Hide()
		return
	end
	-- Capture the resting anchor so SlideOut's downward displacement can be
	-- restored once the window is hidden (otherwise the next open is offset).
	local p, rel, rp, x, y = frame:GetPoint(1)
	MTH_OPT_Sauce:SlideOut(frame, "DOWN", 90, 0.26, "inCubic", {
		onFinish = function()
			frame:Hide()
			frame:SetAlpha(1)
			if p then
				frame:ClearAllPoints()
				frame:SetPoint(p, rel, rp, x, y)
			end
		end,
	})
end

local function MTH_RegisterEscClose(frameName)
	if not (frameName and UISpecialFrames) then
		return
	end
	for i = 1, table.getn(UISpecialFrames) do
		if UISpecialFrames[i] == frameName then
			return
		end
	end
	table.insert(UISpecialFrames, frameName)
end

local function MTH_EnsureOptionsFrame()
	if MetaHuntOptions then
		return MetaHuntOptions
	end

	MetaHuntOptions = CreateFrame("Frame", "MetaHuntOptions", UIParent, "MetaHuntOptionsTemplate")
	if not MetaHuntOptions then
		if MTH and MTH.Print then
			MTH:Print(MTH_OPT_L("OPT_ERR_CREATE_OPTIONS_FRAME", "[MTH OPTIONS] Failed to create MetaHuntOptions"), "error")
		end
		return nil
	end
	MTH_RegisterEscClose("MetaHuntOptions")

	local nav = MTH_GetFrame("MetaHuntOptionsNav")
	if nav and nav.SetBackdropColor then
		nav:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
		nav:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
	end

	local nav = MTH_GetFrame("MetaHuntOptionsNav")
	local navWidth = nav and nav:GetWidth() or MTH_OPTIONS_CONST.NAV_DEFAULT_WIDTH
	local contentLeft = MTH_OPTIONS_CONST.WINDOW_PADDING + navWidth + MTH_OPTIONS_CONST.WINDOW_PADDING
	local contentWidth = (MetaHuntOptions:GetWidth() or 720) - contentLeft - MTH_OPTIONS_CONST.WINDOW_PADDING
	for i = 1, table.getn(MTH_OPTIONS_TABS) do
		local frame = MTH_GetFrame(MTH_OPTIONS_TABS[i].frame)
		if frame then
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", MetaHuntOptions, "TOPLEFT", contentLeft, MTH_OPTIONS_CONST.CONTENT_TOP_OFFSET)
			frame:SetWidth(contentWidth)
			frame:SetHeight(MTH_OPTIONS_CONST.CONTENT_HEIGHT)
			frame:SetFrameLevel(MetaHuntOptions:GetFrameLevel() + 1)
			frame:EnableMouse(true)
			frame:Hide()
		end
	end

	local closeBtn = MTH_GetFrame("MetaHuntOptionsCloseButton")
	if closeBtn then
		closeBtn:ClearAllPoints()
		closeBtn:SetPoint("TOPRIGHT", MetaHuntOptions, "TOPRIGHT", MTH_OPTIONS_CONST.CLOSE_BTN_OFFSET_X, MTH_OPTIONS_CONST.CLOSE_BTN_OFFSET_Y)
		closeBtn:SetWidth(MTH_OPTIONS_CONST.CLOSE_BTN_SIZE)
		closeBtn:SetHeight(MTH_OPTIONS_CONST.CLOSE_BTN_SIZE)
		closeBtn:SetText(MTH_OPT_L("COMMON_CLOSE_SHORT", "X"))
		closeBtn:SetScript("OnClick", function() MTH_OPT_AnimateClose() end)
	end

	MTH_BuildOptionsTree()
	MTH_SelectOptionsTab("General")

	return MetaHuntOptions
end

function MTH_SelectOptionsTab(tabKey)
	if not MTH_OPTIONS_SHELL_READY then return end
	local optionsFrame = MTH_EnsureOptionsFrame()
	if not optionsFrame then
		return
	end
	MTH_OPTIONS_STATE = MTH_OPTIONS_STATE or {}
	MTH_OPTIONS_STATE.activeTab = tabKey
	MTH_OPTIONS_ACTIVE_TAB = tabKey

	for i = 1, table.getn(MTH_OPTIONS_TABS) do
		local frame = MTH_GetFrame(MTH_OPTIONS_TABS[i].frame)
		if frame then
			frame:Hide()
		end
	end

	for i = 1, table.getn(MTH_OPTIONS_TABS) do
		if MTH_OPTIONS_TABS[i].key == tabKey then
			local frame = MTH_GetFrame(MTH_OPTIONS_TABS[i].frame)
			if frame then
				frame:Show()
			end
		end
	end
	MTH_BuildOptionsTree()

	if tabKey == "General" then
		if MTH_SetupGeneralOptions then
			MTH_SetupGeneralOptions()
			MTH_OPTIONS_SETUP["General"] = true
		end
	elseif tabKey == "Profiles" then
		if type(MTH_SetupProfilesOptions) == "function" then
			MTH_SetupProfilesOptions()
			MTH_OPTIONS_SETUP["Profiles"] = true
		end
	elseif tabKey == "Messages" then
		if not MTH_OPTIONS_SETUP["Messages"] then
			if type(MTH_SetupMessagesOptions) == "function" then
				MTH_SetupMessagesOptions()
				MTH_OPTIONS_SETUP["Messages"] = true
			end
		else
			if type(MTH_SetupMessagesOptions) == "function" then
				MTH_SetupMessagesOptions()
			end
		end
	elseif tabKey == "ZBar" then
		if type(MTH_SetupZBarOptions) == "function" then
			MTH_SetupZBarOptions()
			MTH_OPTIONS_SETUP["ZBar"] = true
		end
	elseif tabKey == "Pet" then
		if not MTH_OPTIONS_SETUP["Pet"] then
			MTH_SetupPetOptions()
			MTH_OPTIONS_SETUP["Pet"] = true
		end
	elseif tabKey == "Track" then
		if not MTH_OPTIONS_SETUP["Track"] then
			MTH_SetupTrackOptions()
			MTH_OPTIONS_SETUP["Track"] = true
		end
	elseif tabKey == "Aspect" then
		if not MTH_OPTIONS_SETUP["Aspect"] then
			MTH_SetupAspectOptions()
			MTH_OPTIONS_SETUP["Aspect"] = true
		end
	elseif tabKey == "Trap" then
		if not MTH_OPTIONS_SETUP["Trap"] then
			MTH_SetupTrapOptions()
			MTH_OPTIONS_SETUP["Trap"] = true
		end
	elseif tabKey == "Ranged" then
		if not MTH_OPTIONS_SETUP["Ranged"] then
			MTH_SetupRangedOptions()
			MTH_OPTIONS_SETUP["Ranged"] = true
		else
			MTH_SetupRangedOptions()
		end
	elseif tabKey == "Ammo" then
		if not MTH_OPTIONS_SETUP["Ammo"] then
			MTH_SetupAmmoOptions()
			MTH_OPTIONS_SETUP["Ammo"] = true
		else
			MTH_SetupAmmoOptions()
		end
	elseif tabKey == "Mounts" then
		if not MTH_OPTIONS_SETUP["Mounts"] then
			MTH_SetupMountsOptions()
			MTH_OPTIONS_SETUP["Mounts"] = true
		end
	elseif tabKey == "Companions" then
		if not MTH_OPTIONS_SETUP["Companions"] then
			MTH_SetupCompanionsOptions()
			MTH_OPTIONS_SETUP["Companions"] = true
		end
	elseif tabKey == "Toys" then
		if not MTH_OPTIONS_SETUP["Toys"] then
			MTH_SetupToysOptions()
			MTH_OPTIONS_SETUP["Toys"] = true
		end
	elseif tabKey == "Craft" then
		if not MTH_OPTIONS_SETUP["Craft"] then
			MTH_SetupCraftOptions()
			MTH_OPTIONS_SETUP["Craft"] = true
		end
	elseif tabKey == "SmartAmmo" then
		if not MTH_OPTIONS_SETUP["SmartAmmo"] then
			MTH_SetupSmartAmmoOptions()
			MTH_OPTIONS_SETUP["SmartAmmo"] = true
		end
	elseif tabKey == "FeedOMatic" then
		if not MTH_OPTIONS_SETUP["FeedOMatic"] then
			MTH_SetupFeedOMaticOptions()
			MTH_OPTIONS_SETUP["FeedOMatic"] = true
		end
		MTH_RefreshFeedOMaticOptions()
	elseif tabKey == "AutoBuy" then
		if not MTH_OPTIONS_SETUP["AutoBuy"] then
			MTH_SetupAutoBuyOptions()
			MTH_OPTIONS_SETUP["AutoBuy"] = true
		else
			MTH_SetupAutoBuyOptions()
		end
	elseif tabKey == "AutoQuest" then
		if type(MTH_SetupAutoQuestOptions) == "function" then
			MTH_SetupAutoQuestOptions()
			MTH_OPTIONS_SETUP["AutoQuest"] = true
		end
	elseif tabKey == "ExpAmmo" then
		if not MTH_OPTIONS_SETUP["ExpAmmo"] then
			if type(MTH_SetupExpAmmoOptions) == "function" then
				MTH_SetupExpAmmoOptions()
				MTH_OPTIONS_SETUP["ExpAmmo"] = true
			end
		end
	elseif tabKey == "ICU" then
		if type(MTH_SetupICUOptions) == "function" then
			MTH_SetupICUOptions()
			MTH_OPTIONS_SETUP["ICU"] = true
			if type(MTH_RefreshICUOptions) == "function" then
				MTH_RefreshICUOptions()
			end
		elseif MTH and MTH.Print then
			MTH:Print("ICU options setup function is not loaded", "error")
		end
	elseif tabKey == "Animations" then
		if not MTH_OPTIONS_SETUP["Animations"] then
			if type(MTH_SetupAnimationsOptions) == "function" then
				MTH_SetupAnimationsOptions()
				MTH_OPTIONS_SETUP["Animations"] = true
			end
		end
	elseif tabKey == "Credits" then
		local setupCredits = _G and _G["MTH_SetupCreditsOptions"]
		if type(setupCredits) == "function" then
			setupCredits()
		end
		MTH_OPTIONS_SETUP["Credits"] = true
	elseif string.sub(tabKey or "", 1, 11) == "Chronometer" then
		if not MTH_OPTIONS_SETUP[tabKey] then
			if _G then
				_G.MTH_CHRON_OPTIONS_SECTION = tabKey
			end
			if type(MTH_SetupChronometerOptions) == "function" then
				MTH_SetupChronometerOptions()
				MTH_OPTIONS_SETUP[tabKey] = true
			elseif MTH and MTH.Print then
				MTH:Print(MTH_OPT_L("OPT_ERR_CHRON_NOT_LOADED", "Chronometer options module not loaded"), "error")
			end
		else
			if _G then
				_G.MTH_CHRON_OPTIONS_SECTION = tabKey
			end
			if type(MTH_RefreshChronometerOptions) == "function" then
				MTH_RefreshChronometerOptions()
			elseif type(MTH_SetupChronometerOptions) == "function" then
				MTH_SetupChronometerOptions()
			end
		end
	end
	MTH_OPT_AnimateTabContent(tabKey)
end

function MTH_ResetAndSelectOptionsTab(tabKey)
	if not MTH_OPTIONS_SHELL_READY then return end
	if not tabKey then
		return
	end
	MTH_OPTIONS_SETUP[tabKey] = nil
	MTH_SelectOptionsTab(tabKey)
end

-- On a blocked realm the options window must be inert too. Instead of drawing any tabs we
-- drop an opaque "DISABLED." panel over the whole window (with its own close button so it can
-- still be dismissed). Returns true when the realm gate is active.
local function MTH_OPTIONS_UpdateRealmGateOverlay(frame)
	if not frame then return false end
	local blocked = (MTH and MTH.IsRealmGateBlocked and MTH:IsRealmGateBlocked()) and true or false

	local overlay = frame.realmGateOverlay
	if not overlay then
		if not blocked then return false end

		overlay = CreateFrame("Frame", "MetaHuntOptionsRealmGateOverlay", frame)
		overlay:SetAllPoints(frame)
		overlay:EnableMouse(true)
		overlay:EnableMouseWheel(true)
		overlay:SetFrameStrata("FULLSCREEN_DIALOG")
		if overlay.SetFrameLevel and frame.GetFrameLevel then
			overlay:SetFrameLevel(frame:GetFrameLevel() + 50)
		end

		local bg = overlay:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(overlay)
		bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		if bg.SetVertexColor then bg:SetVertexColor(0, 0, 0, 1) end

		local label = overlay:CreateFontString(nil, "OVERLAY")
		label:SetPoint("CENTER", overlay, "CENTER", 0, 0)
		if label.SetFont then label:SetFont("Fonts\\FRIZQT__.TTF", 48, "OUTLINE") end
		label:SetText("DISABLED.")
		label:SetTextColor(1.0, 0.1, 0.1)

		local close = CreateFrame("Button", nil, overlay, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -4, -4)
		close:SetScript("OnClick", function() frame:Hide() end)

		frame.realmGateOverlay = overlay
	end

	if blocked then
		overlay:Show()
	else
		overlay:Hide()
	end
	return blocked
end

function MTH_OpenOptions(tabKey)
	if not MTH_OPTIONS_SHELL_READY then return end
	local optionsFrame = MTH_EnsureOptionsFrame()
	if not optionsFrame then
		return
	end
	optionsFrame:Show()
	MTH_OPT_AnimateOpen(optionsFrame)
	if MTH_OPTIONS_UpdateRealmGateOverlay(optionsFrame) then return end
	MTH_SelectOptionsTab(tabKey or "General")
end
