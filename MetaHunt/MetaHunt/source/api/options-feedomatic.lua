local MTH_FOM_READY = MTH_OptionsRequire and MTH_OptionsRequire("options-feedomatic", {
	"MTH_GetFrame",
	"MTH_ClearContainer",
	"MTH_CreateCheckbox",
})

local MTH_FOM_STATE = {
	enableCheck = nil,
	keepOpenEdit = nil,
	bindStatus = nil,
	bindButton = nil,
	bindClearButton = nil,
	captureFrame = nil,
	ctrl = {},
}

local function MTH_FOM_L(key, default)
	if MTH and MTH.GetLocalization then
		return MTH:GetLocalization(key, default)
	end
	return default or key
end

local function MTH_EnsureFOMConfig()
	if FOM_Config then
		return
	end

	if FOM_Config_Default then
		FOM_Config = {}
		for key, value in pairs(FOM_Config_Default) do
			FOM_Config[key] = value
		end
		return
	end

	FOM_Config = {
		Enabled = false,
		Alert = "emote",
		Level = "content",
		KeepOpenSlots = 8,
		AvoidUsefulFood = true,
		AvoidQuestFood = true,
		AvoidBonusFood = true,
		Fallback = false,
		SaveForCookingLevel = 1,
		PreferHigherQuality = true,
		AudioWarning = true,
		TextWarning = true,
		IconWarning = true,
	}
end

local function MTH_FOM_SetAlert(mode)
	MTH_EnsureFOMConfig()
	if mode == "none" then
		FOM_Config.Alert = nil
	else
		FOM_Config.Alert = mode
	end
end

local function MTH_FOM_SetLevel(level)
	MTH_EnsureFOMConfig()
	if level == "off" then
		FOM_Config.Level = nil
	else
		FOM_Config.Level = level
	end
end

local function MTH_FOM_SetCookingLevel(level)
	MTH_EnsureFOMConfig()
	FOM_Config.SaveForCookingLevel = level
end

local function MTH_FOM_GetBindingDisplayText()
	if not GetBindingKey then
		return MTH_FOM_L("FOM_BIND_UNAVAILABLE", "Unavailable")
	end
	local key1, key2 = GetBindingKey("FEEDOMATIC")
	if not key1 and not key2 then
		return MTH_FOM_L("FOM_BIND_UNBOUND", "Unbound")
	end
	if key1 and key2 then
		return key1 .. " / " .. key2
	end
	return key1 or key2 or MTH_FOM_L("FOM_BIND_UNBOUND", "Unbound")
end

local function MTH_FOM_UpdateBindingStatus()
	local bindStatus = MTH_FOM_STATE.bindStatus
	if not bindStatus or not bindStatus.SetText then
		return
	end
	bindStatus:SetText(string.format(MTH_FOM_L("FOM_BIND_STATUS_VALUE", "Feed key: %s"), MTH_FOM_GetBindingDisplayText()))
end

local function MTH_FOM_StopBindingCapture()
	if MTH_FOM_STATE.captureFrame then
		MTH_FOM_STATE.captureFrame:Hide()
	end
	if MTH_FOM_STATE.bindButton then
		MTH_FOM_STATE.bindButton:SetText(MTH_FOM_L("FOM_BIND_SET_KEY", "Set Key"))
	end
	MTH_FOM_UpdateBindingStatus()
end

local function MTH_FOM_BuildBindingChord(key)
	return string.format("%s%s%s%s",
		(IsAltKeyDown and IsAltKeyDown() and "ALT-" or ""),
		(IsControlKeyDown and IsControlKeyDown() and "CTRL-" or ""),
		(IsShiftKeyDown and IsShiftKeyDown() and "SHIFT-" or ""),
		key)
end

-- Forward declaration: defined below but referenced by the capture-frame
-- closures above it, so it must be an in-scope local upvalue (not a global).
local MTH_FOM_SaveBinding

local function MTH_FOM_MakeCaptureFrame()
	local f = CreateFrame("Frame", "MTH_FOMBindCapture", UIParent)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetAllPoints(UIParent)
	f:EnableKeyboard(true)
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:Hide()
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(f)
	bg:SetTexture(0, 0, 0, 0.5)
	local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	lbl:SetPoint("CENTER", f, "CENTER", 0, 0)
	lbl:SetText("|cffffff00Press a key, mouse button, or scroll wheel|r\n|cffaaaaaa(ESC to cancel)|r")
	f:SetScript("OnKeyUp", function()
		local key = arg1
		if not key or key == "" then return end
		if key == "ESCAPE" then MTH_FOM_StopBindingCapture() return end
		if key == "UNKNOWN" or key == "PRINTSCREEN" then return end
		if key == "ALT" or key == "CTRL" or key == "SHIFT" then return end
		MTH_FOM_SaveBinding(MTH_FOM_BuildBindingChord(key))
		MTH_FOM_StopBindingCapture()
	end)
	f:SetScript("OnMouseUp", function()
		local btmap = { LeftButton="BUTTON1", RightButton="BUTTON2", MiddleButton="BUTTON3", Button4="BUTTON4", Button5="BUTTON5" }
		local mapped = btmap[arg1]
		if not mapped then return end
		local prefix = string.format("%s%s%s",
			(IsAltKeyDown and IsAltKeyDown() and "ALT-" or ""),
			(IsControlKeyDown and IsControlKeyDown() and "CTRL-" or ""),
			(IsShiftKeyDown and IsShiftKeyDown() and "SHIFT-" or ""))
		if prefix == "" and (mapped == "BUTTON1" or mapped == "BUTTON2") then return end
		MTH_FOM_SaveBinding(prefix .. mapped)
		MTH_FOM_StopBindingCapture()
	end)
	f:SetScript("OnMouseWheel", function()
		local wheelkey = (arg1 == 1 and "MOUSEWHEELUP") or (arg1 == -1 and "MOUSEWHEELDOWN") or nil
		if not wheelkey then return end
		MTH_FOM_SaveBinding(MTH_FOM_BuildBindingChord(wheelkey))
		MTH_FOM_StopBindingCapture()
	end)
	return f
end

local function MTH_FOM_StartBindingCapture()
	if not MTH_FOM_STATE.captureFrame then
		MTH_FOM_STATE.captureFrame = MTH_FOM_MakeCaptureFrame()
	end
	MTH_FOM_STATE.captureFrame:Show()
	if MTH_FOM_STATE.bindButton then
		MTH_FOM_STATE.bindButton:SetText(MTH_FOM_L("FOM_BIND_PRESS_KEY", "Press key..."))
	end
end

function MTH_FOM_SaveBinding(key)
	if not SetBinding or not SaveBindings or not GetBindingKey then
		if MTH and MTH.Print then
			MTH:Print(MTH_FOM_L("FOM_ERROR_KEYBIND_API_UNAVAILABLE", "Keybinding APIs unavailable."))
		end
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		if MTH and MTH.Print then
			MTH:Print(MTH_FOM_L("FOM_ERROR_KEYBIND_COMBAT_LOCKED", "Cannot change keybindings during combat."))
		end
		MTH_FOM_StopBindingCapture()
		return
	end

	local old1, old2 = GetBindingKey("FEEDOMATIC")
	if old1 then SetBinding(old1) end
	if old2 then SetBinding(old2) end

	if key and key ~= "" and key ~= "ESCAPE" then
		SetBinding(key, "FEEDOMATIC")
	end

	local bindingSet = 1
	if GetCurrentBindingSet then
		bindingSet = GetCurrentBindingSet() or 1
	end
	SaveBindings(bindingSet)
	MTH_FOM_StopBindingCapture()
end

function MTH_RefreshFeedOMaticOptions()
	if not MTH_FOM_READY then return end
	MTH_EnsureFOMConfig()

	if MTH_FOM_STATE.enableCheck then
		local module = MTH and MTH:GetModule("feedomatic")
		MTH_FOM_STATE.enableCheck:SetChecked(module and module.enabled and true or false)
	end

	if MTH_FOM_STATE.keepOpenEdit then
		MTH_FOM_STATE.keepOpenEdit:SetText(tostring(FOM_Config.KeepOpenSlots or 0))
	end

	MTH_FOM_UpdateBindingStatus()

	if MTH_FOM_STATE.ctrl.AvoidQuestFood then MTH_FOM_STATE.ctrl.AvoidQuestFood:SetChecked(FOM_Config.AvoidQuestFood and 1 or nil) end
	if MTH_FOM_STATE.ctrl.AvoidBonusFood then MTH_FOM_STATE.ctrl.AvoidBonusFood:SetChecked(FOM_Config.AvoidBonusFood and 1 or nil) end
	if MTH_FOM_STATE.ctrl.PreferHigherQuality then MTH_FOM_STATE.ctrl.PreferHigherQuality:SetChecked(FOM_Config.PreferHigherQuality and 1 or nil) end
	if MTH_FOM_STATE.ctrl.Fallback then MTH_FOM_STATE.ctrl.Fallback:SetChecked(FOM_Config.Fallback and 1 or nil) end
	if MTH_FOM_STATE.ctrl.AudioWarning then MTH_FOM_STATE.ctrl.AudioWarning:SetChecked(FOM_Config.AudioWarning and true or false) end
	if MTH_FOM_STATE.ctrl.AudioWarningBell then MTH_FOM_STATE.ctrl.AudioWarningBell:SetChecked(FOM_Config.AudioWarning == "bell" and 1 or nil) end
	if MTH_FOM_STATE.ctrl.TextWarning then MTH_FOM_STATE.ctrl.TextWarning:SetChecked(FOM_Config.TextWarning and 1 or nil) end
	if MTH_FOM_STATE.ctrl.IconWarning then MTH_FOM_STATE.ctrl.IconWarning:SetChecked(FOM_Config.IconWarning and 1 or nil) end

	if MTH_FOM_STATE.ctrl.AlertEmote then MTH_FOM_STATE.ctrl.AlertEmote:SetChecked(FOM_Config.Alert == "emote" and 1 or nil) end
	if MTH_FOM_STATE.ctrl.AlertChat then MTH_FOM_STATE.ctrl.AlertChat:SetChecked(FOM_Config.Alert == "chat" and 1 or nil) end
	if MTH_FOM_STATE.ctrl.AlertNone then MTH_FOM_STATE.ctrl.AlertNone:SetChecked((not FOM_Config.Alert) and 1 or nil) end

	if MTH_FOM_STATE.ctrl.LevelContent then MTH_FOM_STATE.ctrl.LevelContent:SetChecked(FOM_Config.Level == "content" and 1 or nil) end
	if MTH_FOM_STATE.ctrl.LevelUnhappy then MTH_FOM_STATE.ctrl.LevelUnhappy:SetChecked(FOM_Config.Level == "unhappy" and 1 or nil) end
	if MTH_FOM_STATE.ctrl.LevelOff then MTH_FOM_STATE.ctrl.LevelOff:SetChecked((not FOM_Config.Level) and 1 or nil) end

	if MTH_FOM_STATE.ctrl.SaveCookOrange then MTH_FOM_STATE.ctrl.SaveCookOrange:SetChecked(FOM_Config.SaveForCookingLevel == 3 and 1 or nil) end
	if MTH_FOM_STATE.ctrl.SaveCookYellow then MTH_FOM_STATE.ctrl.SaveCookYellow:SetChecked(FOM_Config.SaveForCookingLevel == 2 and 1 or nil) end
	if MTH_FOM_STATE.ctrl.SaveCookGreen then MTH_FOM_STATE.ctrl.SaveCookGreen:SetChecked(FOM_Config.SaveForCookingLevel == 1 and 1 or nil) end
	if MTH_FOM_STATE.ctrl.SaveCookAll then MTH_FOM_STATE.ctrl.SaveCookAll:SetChecked(FOM_Config.SaveForCookingLevel == 0 and 1 or nil) end
	if MTH_FOM_STATE.ctrl.SaveCookNone then MTH_FOM_STATE.ctrl.SaveCookNone:SetChecked(FOM_Config.SaveForCookingLevel and FOM_Config.SaveForCookingLevel >= 4 and 1 or nil) end
end

-- Small label helper: prefer Feed-O-Matic's own button text, else localized.
local function MTH_FOM_Label(key, lkey, fallback)
	return (FOM_OptionsButtonText and FOM_OptionsButtonText[key]) or MTH_FOM_L(lkey, fallback)
end

function MTH_SetupFeedOMaticOptions()
	if not MTH_FOM_READY then return end
	local container = MTH_GetFrame("MetaHuntOptionsFeedOMatic")
	if not container then return end

	MTH_FOM_STATE.ctrl = {}

	local panel = MTH_Layout.Panel(container)
	panel:Title(MTH_FOM_L("FOM_TITLE", "Feed-O-Matic"))
	panel:Note(MTH_FOM_L("FOM_STATUS_NOTICE", "Feed-O-Matic, created by the great Fizzwidget, is not yet entirely ready for Twow because I am missing \na reliable list of all foods, mostly impossible to fetch from the DB.\n It still works much better in this version, but all stuff related to Food buff and Cooking isnt fully functional."), { lines = 4 })

	MTH_FOM_STATE.enableCheck = panel:TopCheckbox("MetaHuntOptionsFeedOMaticEnabled",
		MTH_FOM_L("FOM_ENABLE_MODULE", "Enable FeedOMatic module"), {
		onClick = function()
			if not this then return end
			local enabled = this:GetChecked() == 1
			if MTH and MTH.SetModuleEnabled then
				local ok, err = MTH:SetModuleEnabled("feedomatic", enabled)
				if not ok and MTH and MTH.Print then
					MTH:Print(string.format(MTH_FOM_L("FOM_ERROR_TOGGLE_FAILED", "Failed to change FeedOMatic state: %s"), tostring(err)))
				end
			end
			MTH_RefreshFeedOMaticOptions()
		end,
	})

	-- ===== General (left column) =====
	local general = panel:Box("left", "MetaHuntOptionsFOMGeneralBox", MTH_FOM_L("FOM_HEADER_GENERAL", "General"))

	MTH_FOM_STATE.bindStatus = general:Text("MetaHuntOptionsFOMBindStatus",
		string.format(MTH_FOM_L("FOM_BIND_STATUS_VALUE", "Feed key: %s"), MTH_FOM_GetBindingDisplayText()))

	local bindButtons = general:Buttons({
		{ name = "MetaHuntOptionsFOMBindButton", label = MTH_FOM_L("FOM_BIND_SET_KEY", "Set Key"), width = 90,
			onClick = function()
				if MTH_FOM_STATE.captureFrame and MTH_FOM_STATE.captureFrame:IsShown() then
					MTH_FOM_StopBindingCapture()
				else
					MTH_FOM_StartBindingCapture()
				end
			end },
		{ name = "MetaHuntOptionsFOMBindClearButton", label = MTH_FOM_L("FOM_BIND_CLEAR", "Clear"), width = 70,
			onClick = function() MTH_FOM_SaveBinding(nil) end },
	})
	MTH_FOM_STATE.bindButton = bindButtons[1]
	MTH_FOM_STATE.bindClearButton = bindButtons[2]

	general:Note("MetaHuntOptionsFOMBindHint",
		MTH_FOM_L("FOM_BIND_HINT", "You should assign a key bind for feed-o-matic,\nin order to feed your pet automatically.\nThe key \"P\" is an excellent candidate !"), { lines = 3 })

	MTH_FOM_STATE.ctrl.AvoidQuestFood = general:Checkbox("MetaHuntOptionsFOMAvoidQuest",
		MTH_FOM_Label("AvoidQuestFood", "FOM_LABEL_AVOID_QUEST_FOODS", "Avoid quest foods"),
		{ onClick = function() if not this then return end FOM_Config.AvoidQuestFood = this:GetChecked() == 1 end })
	MTH_FOM_STATE.ctrl.AvoidBonusFood = general:Checkbox("MetaHuntOptionsFOMAvoidBonus",
		MTH_FOM_Label("AvoidBonusFood", "FOM_LABEL_AVOID_BONUS_FOODS", "Avoid bonus foods"),
		{ onClick = function() if not this then return end FOM_Config.AvoidBonusFood = this:GetChecked() == 1 end })
	MTH_FOM_STATE.ctrl.PreferHigherQuality = general:Checkbox("MetaHuntOptionsFOMPreferQuality",
		MTH_FOM_Label("PreferHigherQuality", "FOM_LABEL_PREFER_HIGHER_QUALITY_FOOD", "Prefer higher quality food"),
		{ onClick = function() if not this then return end FOM_Config.PreferHigherQuality = this:GetChecked() == 1 end })
	MTH_FOM_STATE.ctrl.Fallback = general:Checkbox("MetaHuntOptionsFOMFallback",
		MTH_FOM_Label("Fallback", "FOM_LABEL_FALLBACK_TO_AVOIDED_FOODS", "Fallback to avoided foods"),
		{ onClick = function() if not this then return end FOM_Config.Fallback = this:GetChecked() == 1 end })

	MTH_FOM_STATE.keepOpenEdit = general:EditRow("MetaHuntOptionsFOMKeepOpenLabel",
		MTH_FOM_L("FOM_KEEP_OPEN_BAG_SLOTS", "Keep open bag slots:"),
		"MetaHuntOptionsFOMKeepOpen", 40, {
		numeric = true,
		onChange = function()
			if not this then return end
			FOM_Config.KeepOpenSlots = tonumber(this:GetText()) or 0
		end,
	})

	-- ===== Notify when feeding (left column) =====
	local notify = panel:Box("left", "MetaHuntOptionsFOMNotifyBox", MTH_FOM_L("FOM_HEADER_NOTIFY_WHEN_FEEDING", "Notify when feeding"))
	MTH_FOM_STATE.ctrl.AlertEmote = notify:Checkbox("MetaHuntOptionsFOMAlertEmote",
		MTH_FOM_Label("AlertEmote", "FOM_LABEL_NOTIFY_VIA_EMOTE", "Via emote"),
		{ onClick = function() MTH_FOM_SetAlert("emote"); MTH_RefreshFeedOMaticOptions() end })
	MTH_FOM_STATE.ctrl.AlertChat = notify:Checkbox("MetaHuntOptionsFOMAlertChat",
		MTH_FOM_Label("AlertChat", "FOM_LABEL_NOTIFY_IN_CHAT", "In chat"),
		{ onClick = function() MTH_FOM_SetAlert("chat"); MTH_RefreshFeedOMaticOptions() end })
	MTH_FOM_STATE.ctrl.AlertNone = notify:Checkbox("MetaHuntOptionsFOMAlertNone",
		MTH_FOM_Label("AlertNone", "FOM_LABEL_NOTIFY_NONE", "Don't notify"),
		{ onClick = function() MTH_FOM_SetAlert("none"); MTH_RefreshFeedOMaticOptions() end })

	-- ===== Avoid foods used in cooking (right column) =====
	local avoid = panel:Box("right", "MetaHuntOptionsFOMAvoidBox", MTH_FOM_L("FOM_HEADER_AVOID_FOODS_USED_IN_COOKING", "Avoid foods used in cooking"))
	MTH_FOM_STATE.ctrl.SaveCookOrange = avoid:Checkbox("MetaHuntOptionsFOMSaveCookOrange",
		MTH_FOM_Label("SaveForCook_Orange", "FOM_LABEL_ONLY_DIFFICULT_RECIPES", "Only difficult recipes"),
		{ onClick = function() MTH_FOM_SetCookingLevel(3); MTH_RefreshFeedOMaticOptions() end })
	MTH_FOM_STATE.ctrl.SaveCookYellow = avoid:Checkbox("MetaHuntOptionsFOMSaveCookYellow",
		MTH_FOM_Label("SaveForCook_Yellow", "FOM_LABEL_MEDIUM_OR_BETTER", "Medium or better"),
		{ onClick = function() MTH_FOM_SetCookingLevel(2); MTH_RefreshFeedOMaticOptions() end })
	MTH_FOM_STATE.ctrl.SaveCookGreen = avoid:Checkbox("MetaHuntOptionsFOMSaveCookGreen",
		MTH_FOM_Label("SaveForCook_Green", "FOM_LABEL_EASY_OR_BETTER", "Easy or better"),
		{ onClick = function() MTH_FOM_SetCookingLevel(1); MTH_RefreshFeedOMaticOptions() end })
	MTH_FOM_STATE.ctrl.SaveCookAll = avoid:Checkbox("MetaHuntOptionsFOMSaveCookAll",
		MTH_FOM_Label("SaveForCook_All", "FOM_LABEL_ALL_FOODS", "All foods"),
		{ onClick = function() MTH_FOM_SetCookingLevel(0); MTH_RefreshFeedOMaticOptions() end })
	MTH_FOM_STATE.ctrl.SaveCookNone = avoid:Checkbox("MetaHuntOptionsFOMSaveCookNone",
		MTH_FOM_Label("SaveForCook_None", "FOM_LABEL_DO_NOT_SAVE_COOKING_FOODS", "Do not save cooking foods"),
		{ onClick = function() MTH_FOM_SetCookingLevel(4); MTH_RefreshFeedOMaticOptions() end })

	-- ===== Warn when pet needs feeding (right column) =====
	local warn = panel:Box("right", "MetaHuntOptionsFOMWarnBox", MTH_FOM_L("FOM_HEADER_WARN_WHEN_PET_NEEDS_FEEDING", "Warn when pet needs feeding"))
	MTH_FOM_STATE.ctrl.LevelContent = warn:Checkbox("MetaHuntOptionsFOMLevelContent",
		MTH_FOM_Label("LevelContent", "FOM_LABEL_WARN_WHEN_CONTENT", "When content"),
		{ onClick = function() MTH_FOM_SetLevel("content"); MTH_RefreshFeedOMaticOptions() end })
	MTH_FOM_STATE.ctrl.LevelUnhappy = warn:Checkbox("MetaHuntOptionsFOMLevelUnhappy",
		MTH_FOM_Label("LevelUnhappy", "FOM_LABEL_WARN_WHEN_UNHAPPY", "When unhappy"),
		{ onClick = function() MTH_FOM_SetLevel("unhappy"); MTH_RefreshFeedOMaticOptions() end })
	MTH_FOM_STATE.ctrl.LevelOff = warn:Checkbox("MetaHuntOptionsFOMLevelOff",
		MTH_FOM_Label("LevelOff", "FOM_LABEL_DONT_WARN", "Don't warn"),
		{ onClick = function() MTH_FOM_SetLevel("off"); MTH_RefreshFeedOMaticOptions() end })

	warn:Gap(6)

	MTH_FOM_STATE.ctrl.AudioWarning = warn:Checkbox("MetaHuntOptionsFOMAudioWarning",
		MTH_FOM_Label("AudioWarning", "FOM_LABEL_PLAY_SOUND", "Play sound"),
		{ onClick = function() if not this then return end if this:GetChecked() == 1 then if FOM_Config.AudioWarning ~= "bell" then FOM_Config.AudioWarning = true end else FOM_Config.AudioWarning = nil end MTH_RefreshFeedOMaticOptions() end })
	MTH_FOM_STATE.ctrl.AudioWarningBell = warn:Checkbox("MetaHuntOptionsFOMAudioWarningBell",
		MTH_FOM_Label("AudioWarningBell", "FOM_LABEL_USE_BELL_SOUND", "Use bell sound"),
		{ onClick = function() if not this then return end if this:GetChecked() == 1 then FOM_Config.AudioWarning = "bell" else FOM_Config.AudioWarning = true end MTH_RefreshFeedOMaticOptions() end })
	MTH_FOM_STATE.ctrl.TextWarning = warn:Checkbox("MetaHuntOptionsFOMTextWarning",
		MTH_FOM_Label("TextWarning", "FOM_LABEL_SHOW_TEXT", "Show text"),
		{ onClick = function() if not this then return end FOM_Config.TextWarning = this:GetChecked() == 1 end })
	MTH_FOM_STATE.ctrl.IconWarning = warn:Checkbox("MetaHuntOptionsFOMIconWarning",
		MTH_FOM_Label("IconWarning", "FOM_LABEL_FLASH_ICON", "Flash icon"),
		{ onClick = function() if not this then return end FOM_Config.IconWarning = this:GetChecked() == 1 end })

	panel:Finish()
	MTH_RefreshFeedOMaticOptions()
end
