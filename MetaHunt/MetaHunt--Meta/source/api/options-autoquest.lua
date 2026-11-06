local MTH_AQ_READY = MTH_OptionsRequire and MTH_OptionsRequire("options-autoquest", {
	"MTH_GetFrame",
	"MTH_ClearContainer",
	"MTH_CreateCheckbox",
})

local function MTH_AQ_IsChecked(control)
	if not control or type(control.GetChecked) ~= "function" then
		return false
	end
	local checked = control:GetChecked()
	return checked == 1 or checked == true
end

local function MTH_AQ_EnsureStore()
	if type(MTH_CharSavedVariables) ~= "table" then
		MTH_CharSavedVariables = {}
	end
	local store = nil
	if MTH and MTH.GetModuleCharSavedVariables then
		store = MTH:GetModuleCharSavedVariables("autoquest")
	end
	if type(store) ~= "table" then
		if type(MTH_CharSavedVariables.modules) ~= "table" then
			MTH_CharSavedVariables.modules = {}
		end
		if type(MTH_CharSavedVariables.modules.autoquest) ~= "table" then
			MTH_CharSavedVariables.modules.autoquest = {}
		end
		store = MTH_CharSavedVariables.modules.autoquest
	end
	if type(store.settings) ~= "table" then
		store.settings = {}
	end
	local settings = store.settings
	if settings.scorpokDrazial == nil then
		settings.scorpokDrazial = false
	end
	if settings.arrowsForSissies == nil then
		settings.arrowsForSissies = false
	end
	return settings
end

function MTH_SetupAutoQuestOptions()
	if not MTH_AQ_READY then return end

	local container = MTH_GetFrame("MetaHuntOptionsAutoQuest")
	if not container then return end

	local store = MTH_AQ_EnsureStore()
	if store.scorpokTooltip == nil then
		store.scorpokTooltip = false
	end

	local moduleEnabled = true
	if MTH and MTH.GetModule then
		local module = MTH:GetModule("autoquest")
		if type(module) == "table" and module.enabled ~= nil then
			moduleEnabled = module.enabled and true or false
		elseif MTH and MTH.IsModuleEnabled then
			moduleEnabled = MTH:IsModuleEnabled("autoquest", false) and true or false
		end
	elseif MTH and MTH.IsModuleEnabled then
		moduleEnabled = MTH:IsModuleEnabled("autoquest", false) and true or false
	end

	local panel = MTH_Layout.Panel(container)
	panel:Title("Auto Quest")
	panel:Note("Automation for specific quest interactions.")

	panel:TopCheckbox("MetaHuntOptionsAutoQuestModuleToggle", "Enable Auto Quest module", {
		checked = moduleEnabled,
		onClick = function()
			if not this then return end
			local enabled = MTH_AQ_IsChecked(this)
			if MTH and MTH.SetModuleEnabled then
				local ok, err = MTH:SetModuleEnabled("autoquest", enabled)
				if not ok and MTH and MTH.Print then
					MTH:Print("Failed to change Auto Quest module state: " .. tostring(err), "error")
				end
			end
			local module = MTH and MTH.GetModule and MTH:GetModule("autoquest") or nil
			local actual = (type(module) == "table" and module.enabled ~= nil) and (module.enabled and true or false) or enabled
			this:SetChecked(actual and true or false)
		end,
	})

	-- Salt of the Scorpok (left column)
	local scorpok = panel:Box("left", "MetaHuntAutoQuestScorpokBox", "Salt of the Scorpok")
	scorpok:Checkbox("MetaHuntOptionsAutoQuestScorpokToggle",
		"Enable SHIFT-rightclick for Bloodmage Drazial", {
		checked = store.scorpokDrazial and true or false,
		onClick = function()
			local enabled = MTH_AQ_IsChecked(this)
			store.scorpokDrazial = enabled and true or false
			if MTH and MTH.GetModuleCharSavedVariables then
				local moduleStore = MTH:GetModuleCharSavedVariables("autoquest")
				if type(moduleStore) == "table" then
					moduleStore.scorpokDrazial = store.scorpokDrazial and true or false
				end
			end
			local module = MTH and MTH.GetModule and MTH:GetModule("autoquest")
			if module and module.SetScorpokDrazialEnabled then
				module:SetScorpokDrazialEnabled(enabled)
			end
		end,
	})
	scorpok:Checkbox("MetaHuntOptionsAutoQuestScorpokTooltipToggle",
		"Enhance Tooltip on Drazial and related beasts (requires Tooltips module enabled)", {
		checked = store.scorpokTooltip and true or false,
		onClick = function()
			local enabled = MTH_AQ_IsChecked(this)
			store.scorpokTooltip = enabled and true or false
			if MTH and MTH.GetModuleCharSavedVariables then
				local moduleStore = MTH:GetModuleCharSavedVariables("autoquest")
				if type(moduleStore) == "table" then
					moduleStore.scorpokTooltip = store.scorpokTooltip and true or false
				end
			end
		end,
	})

	-- Arrows Are For Sissies (right column)
	local sissies = panel:Box("right", "MetaHuntAutoQuestSissiesBox", "Arrows Are For Sissies")
	sissies:Note("MetaHuntOptionsAutoQuestSissiesNote",
		"Note that you should not activate this if you are using LazyPig", { lines = 2 })
	sissies:Checkbox("MetaHuntOptionsAutoQuestSissiesToggle",
		"Enable SHIFT-rightclick for Artilleryman Sheldonore", {
		checked = store.arrowsForSissies and true or false,
		onClick = function()
			local enabled = MTH_AQ_IsChecked(this)
			store.arrowsForSissies = enabled and true or false
			if MTH and MTH.GetModuleCharSavedVariables then
				local moduleStore = MTH:GetModuleCharSavedVariables("autoquest")
				if type(moduleStore) == "table" then
					moduleStore.arrowsForSissies = store.arrowsForSissies and true or false
				end
			end
			local module = MTH and MTH.GetModule and MTH:GetModule("autoquest")
			if module and module.SetArrowsForSissiesEnabled then
				module:SetArrowsForSissiesEnabled(enabled)
			end
		end,
	})

	panel:Finish()
end
