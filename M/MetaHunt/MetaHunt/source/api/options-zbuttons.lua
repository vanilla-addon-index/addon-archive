local MTH_ZBUTTONS_READY = MTH_OptionsRequire and MTH_OptionsRequire("options-zbuttons", {
	"MTH_GetFrame",
	"MTH_CreateSlider",
	"MTH_CreateCheckbox",
	"MTH_ClearContainer",
	"MTH_CreateActionButton",
})

local function MTH_ZB_L(key, default)
	if MTH and MTH.GetLocalization then
		return MTH:GetLocalization(key, default)
	end
	return default or key
end

local function MTH_ZB_RefreshTab(tabName)
	if type(MTH_ResetAndSelectOptionsTab) == "function" then
		MTH_ResetAndSelectOptionsTab(tabName)
	elseif type(MTH_SelectOptionsTab) == "function" then
		MTH_SelectOptionsTab(tabName)
	end
end

local function MTH_ZB_IsChecked(control)
	if not control or type(control.GetChecked) ~= "function" then
		return false
	end
	local checked = control:GetChecked()
	return checked == 1 or checked == true
end

local function MTH_RebuildSpellOrder(buttonName, buttonObj, itemList, maxButtons)
	if not (buttonName and buttonObj and itemList and maxButtons) then return end
	local info = {}
	local visible = ZHunterMod_Saved[buttonName]["visible"] or {}
	local infoIndex = 1
	for i = 1, maxButtons do
		local spellIndex = ZHunterMod_Saved[buttonName]["spells"][i]
		if spellIndex and visible[spellIndex] ~= false then
			-- String-based lists (zCraft) store names directly; numeric lists index into itemList
			local name = (type(spellIndex) == "number") and itemList[spellIndex] or spellIndex
			info[infoIndex] = name
			infoIndex = infoIndex + 1
		end
	end
	if ZSpellButton_SetButtons then
		buttonObj.found = ZSpellButton_SetButtons(buttonObj, info)
	end
end

local function MTH_RefreshButtonLayout(buttonName, buttonObj, itemList, maxButtons)
	local resolvedButtonObj = buttonObj or getglobal(buttonName)
	if not resolvedButtonObj then return end
	MTH_RebuildSpellOrder(buttonName, resolvedButtonObj, itemList, maxButtons)
	local setupFunc = getglobal(buttonName.."_SetupSizeAndPosition")
	if type(setupFunc) == "function" then
		setupFunc()
	end
	if ZSpellButton_UpdateButton then
		ZSpellButton_UpdateButton(resolvedButtonObj)
	end
	if ZSpellButton_UpdateCooldown then
		ZSpellButton_UpdateCooldown(resolvedButtonObj)
	end
	if resolvedButtonObj.count and resolvedButtonObj.name then
		for i = 1, resolvedButtonObj.count do
			local child = getglobal(resolvedButtonObj.name .. i)
			if child and child.id then
				if ZSpellButton_UpdateButton then
					ZSpellButton_UpdateButton(child)
				end
				if ZSpellButton_UpdateCooldown then
					ZSpellButton_UpdateCooldown(child)
				end
			end
		end
	end
end

local function MTH_RefreshButtonGeometry(buttonName, buttonObj)
	local resolvedButtonObj = buttonObj or getglobal(buttonName)
	if not resolvedButtonObj then return end
	local setupFunc = getglobal(buttonName.."_SetupSizeAndPosition")
	if type(setupFunc) == "function" then
		setupFunc()
	end
	if ZSpellButton_UpdateButton then
		ZSpellButton_UpdateButton(resolvedButtonObj)
	end
	if ZSpellButton_UpdateCooldown then
		ZSpellButton_UpdateCooldown(resolvedButtonObj)
	end
	if resolvedButtonObj.count and resolvedButtonObj.name then
		for i = 1, resolvedButtonObj.count do
			local child = getglobal(resolvedButtonObj.name .. i)
			if child and child.id then
				if ZSpellButton_UpdateButton then
					ZSpellButton_UpdateButton(child)
				end
				if ZSpellButton_UpdateCooldown then
					ZSpellButton_UpdateCooldown(child)
				end
			end
		end
	end
end

local function MTH_SetButtonEnabledState(buttonName, buttonObj, enabled)
	if not (buttonName and ZHunterMod_Saved and ZHunterMod_Saved[buttonName]) then return end
	ZHunterMod_Saved[buttonName]["enabled"] = enabled and true or false

	local resolvedButtonObj = buttonObj or getglobal(buttonName)
	if resolvedButtonObj then
		if not enabled then
			if resolvedButtonObj.Hide then resolvedButtonObj:Hide() end
			if resolvedButtonObj.count and resolvedButtonObj.name then
				for i = 1, resolvedButtonObj.count do
					local child = getglobal(resolvedButtonObj.name .. i)
					if child and child.Hide then child:Hide() end
				end
			end
		elseif ZHunterMod_Saved[buttonName]["parent"] and ZHunterMod_Saved[buttonName]["parent"]["hide"] then
			if resolvedButtonObj.Hide then resolvedButtonObj:Hide() end
		else
			if resolvedButtonObj.Show then resolvedButtonObj:Show() end
			MTH_RefreshButtonGeometry(buttonName, resolvedButtonObj)
		end
	end
	-- If zBar is active, re-apply its layout so this button is included/excluded.
	-- When re-enabling a button, also un-exclude it from the bar so it appears
	-- in the bar rather than as a standalone button.
	if type(MTH_ZBar_GetSaved) == "function" then
		local zs = MTH_ZBar_GetSaved()
		if enabled and zs.visible[buttonName] == false then
			zs.visible[buttonName] = true
		end
		if zs.enabled and type(MTH_ZBar_ApplyLayout) == "function" then
			MTH_ZBar_ApplyLayout()
		end
	end
end

local function MTH_GetButtonItemList(buttonName)
	if buttonName == "zButtonPet" then
		return getglobal("ZHunterMod_Pet_Spells")
	elseif buttonName == "zButtonTrack" then
		return getglobal("ZHunterMod_Track_Spells")
	elseif buttonName == "zButtonAspect" then
		return getglobal("ZHunterMod_Aspect_Spells")
	elseif buttonName == "zButtonTrap" then
		return getglobal("ZHunterMod_Trap_Spells")
	elseif buttonName == "zButtonAmmo" then
		local sharedBullets = getglobal("MTH_AMMO_BULLETS")
		local sharedArrows = getglobal("MTH_AMMO_ARROWS")
		if GetInventoryItemLink and GetItemInfo then
			local link = GetInventoryItemLink("player", 18)
			if link then
				local _, _, itemId = string.find(link, "item:(%d+)")
				if itemId then
					local _, _, _, _, _, weaponType = GetItemInfo(itemId)
					if weaponType == MTH_WEAPON_GUNS then
						return sharedBullets or getglobal("ZHunterMod_Ammo_Buttons")
					elseif weaponType == MTH_WEAPON_BOWS or weaponType == MTH_WEAPON_CROSSBOWS then
						return sharedArrows or getglobal("ZHunterMod_Ammo_Buttons")
					end
				end
			end
		end
		return getglobal("ZHunterMod_Ammo_Buttons") or sharedArrows
	elseif buttonName == "zButtonRanged" then
		local rangedList = getglobal("ZHunterMod_Ranged_Weapons")
		if rangedList and table.getn(rangedList) > 0 then
			return rangedList
		end
	elseif buttonName == "zButtonMounts" or buttonName == "zButtonCompanions" or buttonName == "zButtonToys" or buttonName == "zButtonCraft" then
		if ZHunterMod_Saved and ZHunterMod_Saved[buttonName] and ZHunterMod_Saved[buttonName]["spells"] then
			return ZHunterMod_Saved[buttonName]["spells"]
		end
	end
	return nil
end

local MTH_AmmoOptionsWatcher = nil

local function MTH_RefreshAmmoOptionsIfVisible()
	if not MTH_GetFrame then return end
	local container = MTH_GetFrame("MetaHuntOptionsAmmo")
	if not (container and container:IsVisible()) then
		return
	end
	if type(MTH_SetupAmmoOptions) == "function" then
		MTH_SetupAmmoOptions()
	end
end

local function MTH_EnsureAmmoOptionsWatcher()
	if MTH_AmmoOptionsWatcher then
		return
	end
	MTH_AmmoOptionsWatcher = CreateFrame("Frame", "MTH_AmmoOptionsWatcher")
	if not MTH_AmmoOptionsWatcher then
		return
	end
	MTH_AmmoOptionsWatcher:RegisterEvent("UNIT_INVENTORY_CHANGED")
	MTH_AmmoOptionsWatcher:RegisterEvent("BAG_UPDATE")
	MTH_AmmoOptionsWatcher:SetScript("OnEvent", function()
		local eventName = event
		local unit = arg1
		if eventName == "UNIT_INVENTORY_CHANGED" and unit and unit ~= "player" then
			return
		end
		MTH_RefreshAmmoOptionsIfVisible()
	end)
end

local function MTH_ZB_GetDefaultEnabled(buttonName)
	if buttonName == "zButtonMounts" or buttonName == "zButtonCompanions" or buttonName == "zButtonToys" or buttonName == "zButtonCraft" or buttonName == "zButtonRanged" then
		return false
	end
	return true
end

local function MTH_ZB_EnsureButtonOptionDefaults(buttonName)
	if not (ZHunterMod_Saved and buttonName) then
		return nil
	end

	if type(ZHunterMod_Saved[buttonName]) ~= "table" then
		ZHunterMod_Saved[buttonName] = {}
	end

	local saved = ZHunterMod_Saved[buttonName]

	if saved["enabled"] == nil then
		saved["enabled"] = MTH_ZB_GetDefaultEnabled(buttonName)
	end
	saved["enabled"] = saved["enabled"] and true or false

	if saved["tooltip"] == nil then
		saved["tooltip"] = true
	end
	saved["tooltip"] = saved["tooltip"] and true or false

	if type(saved["children"]) ~= "table" then
		saved["children"] = {}
	end
	if saved["children"]["hideonclick"] == nil then
		saved["children"]["hideonclick"] = true
	end
	saved["children"]["hideonclick"] = saved["children"]["hideonclick"] and true or false

	if saved["children"]["expandonhover"] == nil then
		saved["children"]["expandonhover"] = false
	end
	saved["children"]["expandonhover"] = saved["children"]["expandonhover"] and true or false

	if saved["children"]["fadetimer"] == nil then
		saved["children"]["fadetimer"] = 0
	end
	saved["children"]["fadetimer"] = tonumber(saved["children"]["fadetimer"]) or 0

	if type(saved["parent"]) ~= "table" then
		saved["parent"] = {}
	end
	if saved["parent"]["hide"] == nil then
		saved["parent"]["hide"] = false
	end
	saved["parent"]["hide"] = saved["parent"]["hide"] and true or false
	if saved["parent"]["circle"] == nil then
		saved["parent"]["circle"] = true
	end
	saved["parent"]["circle"] = saved["parent"]["circle"] and true or false

	if buttonName == "zButtonAspect" or buttonName == "zButtonTrack" or buttonName == "zButtonPet" then
		if saved["parent"]["smart"] == nil then
			saved["parent"]["smart"] = true
		end
		saved["parent"]["smart"] = saved["parent"]["smart"] and true or false
	end

	if buttonName == "zButtonMounts" or buttonName == "zButtonCompanions" then
		if saved["parent"]["random"] == nil then
			saved["parent"]["random"] = false
		end
		saved["parent"]["random"] = saved["parent"]["random"] and true or false
	end

	if buttonName == "zButtonMounts" then
		if saved["parent"]["aqfilter"] == nil then
			saved["parent"]["aqfilter"] = true
		end
		saved["parent"]["aqfilter"] = saved["parent"]["aqfilter"] and true or false
	end

	if saved["firstbutton"] ~= "LEFT" and saved["firstbutton"] ~= "RIGHT" then
		saved["firstbutton"] = "RIGHT"
	end

	if buttonName == "zButtonAmmo" then
		if saved["showammoname"] == nil then
			saved["showammoname"] = true
		end
		saved["showammoname"] = saved["showammoname"] and true or false
		if saved["showtotalperc"] == nil then
			saved["showtotalperc"] = true
		end
		saved["showtotalperc"] = saved["showtotalperc"] and true or false
		if saved["showtotalgauge"] == nil then
			saved["showtotalgauge"] = false
		end
		saved["showtotalgauge"] = saved["showtotalgauge"] and true or false
		if saved["counttotal"] == nil then
			saved["counttotal"] = false
		end
		saved["counttotal"] = saved["counttotal"] and true or false
		if saved["lowflash"] == nil then
			saved["lowflash"] = true
		end
		saved["lowflash"] = saved["lowflash"] and true or false
		if saved["parenttooltip"] == nil then
			saved["parenttooltip"] = true
		end
		saved["parenttooltip"] = saved["parenttooltip"] and true or false
	end

	if buttonName == "zButtonPet" then
		if saved["unhappyflash"] == nil then
			saved["unhappyflash"] = true
		end
		saved["unhappyflash"] = saved["unhappyflash"] and true or false
	end

	if buttonName == "zButtonTrap" then
		if saved["cooldown"] == nil then
			saved["cooldown"] = true
		end
		saved["cooldown"] = saved["cooldown"] and true or false
	end

	return saved
end

local function MTH_SetupButtonOptions(containerName, buttonName, displayName, maxButtons)
	local container = MTH_GetFrame(containerName)
	if not container then
		if MTH and MTH.Print then
			MTH:Print("[MTH] Container not found: "..containerName, "error")
		end
		return
	end

	MTH_ClearContainer(container)

	if not ZHunterMod_Saved or not ZHunterMod_Saved[buttonName] then
		local errText = container:CreateFontString(containerName.."Error", "ARTWORK", "GameFontNormal")
		errText:SetPoint("CENTER", container, "CENTER", 0, 0)
		errText:SetText(string.format(MTH_ZB_L("ZB_ERR_CONFIG_NOT_LOADED", "Configuration not loaded for %s"), tostring(displayName)))
		errText:SetTextColor(1, 0.5, 0.5)
		if MTH and MTH.Print then
			MTH:Print("[MTH] zhunter saved data missing for "..buttonName, "error")
		end
		return
	end

	local buttonObj = getglobal(buttonName)
	local saved = MTH_ZB_EnsureButtonOptionDefaults(buttonName)
	if not saved then
		return
	end
	local containerWidth = container:GetWidth() or 500
	local leftWidth = 260
	local rightX = leftWidth + 44
	local rightWidth = containerWidth - rightX - 12

	local panel = MTH_Layout.Panel(container)

	local enabledValue = saved["enabled"] and true or false
	local enableLabel = tostring(displayName or "")
	if string.len(enableLabel) > 0 then
		enableLabel = string.lower(string.sub(enableLabel, 1, 1)) .. string.sub(enableLabel, 2)
	end
	panel:TopCheckbox(containerName.."EnableButton", string.format(MTH_ZB_L("ZB_LABEL_ENABLE_FMT", "Enable %s"), enableLabel), {
		checked = enabledValue,
		onClick = function()
			if not this then return end
			MTH_SetButtonEnabledState(buttonName, buttonObj, this:GetChecked() == 1)
		end,
	})

	local parentBox = panel:Box("left", containerName.."ParentSection", MTH_ZB_L("ZB_SECTION_PARENT_BUTTON", "Parent Button"))

	parentBox:Slider(containerName.."MainButtonSize", {
		label = MTH_ZB_L("ZB_LABEL_BUTTON_SIZE", "Button Size"),
		min = 10, max = 100, step = 1, value = saved["parent"]["size"] or 36,
		onChange = function(val)
			if not (ZHunterMod_Saved and ZHunterMod_Saved[buttonName]) then return end
			if not ZHunterMod_Saved[buttonName]["parent"] then
				ZHunterMod_Saved[buttonName]["parent"] = {}
			end
			local size = math.floor((val or 0) + 0.5)
			ZHunterMod_Saved[buttonName]["parent"]["size"] = size
			if buttonObj then
				buttonObj:SetWidth(size)
				buttonObj:SetHeight(size)
			end
			MTH_RefreshButtonGeometry(buttonName, buttonObj)
		end,
	})

	parentBox:Checkbox(containerName.."HideButton", MTH_ZB_L("ZB_LABEL_HIDE_BUTTON", "Hide Button"), {
		checked = saved["parent"]["hide"],
		onClick = function()
			if not this then return end
			local checked = this:GetChecked() == 1
			ZHunterMod_Saved[buttonName]["parent"]["hide"] = checked
			if buttonObj then
				if checked then buttonObj:Hide() else buttonObj:Show() end
			end
		end,
	})

	parentBox:Checkbox(containerName.."UseCircle", MTH_ZB_L("ZB_LABEL_USE_CIRCLE_BUTTON", "Use Circle Button"), {
		checked = saved["parent"]["circle"],
		onClick = function()
			if not this then return end
			local checked = this:GetChecked() == 1
			ZHunterMod_Saved[buttonName]["parent"]["circle"] = checked
			if buttonObj and buttonObj.circle then
				if checked then buttonObj.circle:Show() else buttonObj.circle:Hide() end
			end
		end,
	})

	if buttonName == "zButtonAspect" or buttonName == "zButtonTrack" or buttonName == "zButtonPet" then
		parentBox:Checkbox(containerName.."SmartParent", MTH_ZB_L("ZB_LABEL_SMART_PARENT", "Smart Parent"), {
			checked = saved["parent"]["smart"],
			onClick = function()
				if not this then return end
				local checked = this:GetChecked() == 1
				ZHunterMod_Saved[buttonName]["parent"]["smart"] = checked
				local btn = buttonObj or getglobal(buttonName)
				if btn then
					if not checked then
						local firstChild = getglobal(buttonName .. "1")
						if firstChild and firstChild.id then
							btn.id = firstChild.id
							ZSpellButton_UpdateButton(btn)
							ZSpellButton_UpdateCooldown(btn)
						end
					else
						local setupFunc = getglobal(buttonName .. "_SetupSizeAndPosition")
						if type(setupFunc) == "function" then
							setupFunc()
						end
					end
				end
			end,
		})
		local smartDescText
		if buttonName == "zButtonAspect" then
			smartDescText = "When ON, the parent toggles between your 1st and 2nd aspect. If the 1st is active, the parent shows the 2nd and vice-versa. Useful for quickly swapping between two aspects in combat. When OFF, the parent always shows the 1st aspect."
		elseif buttonName == "zButtonTrack" then
			smartDescText = "When ON, the parent toggles between your 1st and 2nd tracking. If the 1st is active, the parent shows the 2nd and vice-versa. Great for PvP to swap between Track Hidden and Track Humanoids. When OFF, the parent always shows the 1st tracking."
		elseif buttonName == "zButtonPet" then
			smartDescText = "When ON, the parent dynamically changes based on your pet state: Revive if dead, Mend if hurt, Feed if unhappy, or your default spell otherwise. When OFF, the parent always shows the 1st spell."
		else
			smartDescText = "Dynamically swap the parent icon based on context."
		end
		parentBox:Note(containerName.."SmartParentDesc", smartDescText)
	end

	if buttonName == "zButtonMounts" or buttonName == "zButtonCompanions" then
		parentBox:Checkbox(containerName.."RandomParent", MTH_ZB_L("ZB_LABEL_RANDOM_PARENT", "Random Parent"), {
			checked = saved["parent"]["random"],
			onClick = function()
				if not this then return end
				local checked = this:GetChecked() == 1
				ZHunterMod_Saved[buttonName]["parent"]["random"] = checked
			end,
		})
		parentBox:Note(containerName.."RandomParentDesc", MTH_ZB_L("ZB_DESC_RANDOM_PARENT", "Pick a random child as parent on each login and after each use."))
	end

	if buttonName == "zButtonMounts" then
		parentBox:Checkbox(containerName.."AQFilter", MTH_ZB_L("ZB_LABEL_AQ_FILTER", "AQ Mount Filter"), {
			checked = saved["parent"]["aqfilter"],
			onClick = function()
				if not this then return end
				local checked = this:GetChecked() == 1
				ZHunterMod_Saved[buttonName]["parent"]["aqfilter"] = checked
			end,
		})
		parentBox:Note(containerName.."AQFilterDesc", MTH_ZB_L("ZB_DESC_AQ_FILTER", "Hide Qiraji mounts outside AQ40. Show only Qiraji inside."))
	end

	if buttonName == "zButtonPet" then
		parentBox:Checkbox(containerName.."UnhappyFlash", MTH_ZB_L("ZB_LABEL_UNHAPPY_FLASH", "Flash when pet is unhappy"), {
			checked = saved["unhappyflash"],
			onClick = function()
				if not this then return end
				ZHunterMod_Saved[buttonName]["unhappyflash"] = this:GetChecked() == 1
			end,
		})
	end

	if buttonName == "zButtonAmmo" then
		parentBox:Checkbox(containerName.."ShowTotalPercent", MTH_ZB_L("ZB_LABEL_SHOW_TOTAL_PERCENT", "Show total % (center)"), {
			checked = saved["showtotalperc"],
			onClick = function()
				if not this then return end
				local checked = this:GetChecked() == 1
				ZHunterMod_Saved[buttonName]["showtotalperc"] = checked
				if buttonObj and buttonObj.ammoname and not buttonObj.isspell then
					zButtonAmmo_UpdateButton(buttonObj)
				end
			end,
		})
		parentBox:Checkbox(containerName.."ShowTotalGauge", MTH_ZB_L("ZB_LABEL_SHOW_TOTAL_GAUGE", "Show total gauge (side)"), {
			checked = saved["showtotalgauge"],
			onClick = function()
				if not this then return end
				local checked = this:GetChecked() == 1
				ZHunterMod_Saved[buttonName]["showtotalgauge"] = checked
				if buttonObj and buttonObj.ammoname and not buttonObj.isspell then
					zButtonAmmo_UpdateButton(buttonObj)
				end
			end,
		})
		parentBox:Checkbox(containerName.."CounterTotal", MTH_ZB_L("ZB_LABEL_COUNTER_TOTAL", "Counter shows total ammo"), {
			checked = saved["counttotal"],
			onClick = function()
				if not this then return end
				local checked = this:GetChecked() == 1
				ZHunterMod_Saved[buttonName]["counttotal"] = checked
				if buttonObj and buttonObj.ammoname and not buttonObj.isspell then
					zButtonAmmo_UpdateButton(buttonObj)
				end
			end,
		})
		parentBox:Checkbox(containerName.."LowFlash", MTH_ZB_L("ZB_LABEL_LOW_AMMO_FLASH", "Flash when low on ammo"), {
			checked = saved["lowflash"],
			onClick = function()
				if not this then return end
				local checked = this:GetChecked() == 1
				ZHunterMod_Saved[buttonName]["lowflash"] = checked
				if buttonObj and buttonObj.ammoname and not buttonObj.isspell then
					zButtonAmmo_UpdateButton(buttonObj)
				end
			end,
		})
		parentBox:Checkbox(containerName.."ParentTooltip", MTH_ZB_L("ZB_LABEL_SHOW_PARENT_TOOLTIP", "Show parent tooltip (usage report)"), {
			checked = saved["parenttooltip"],
			onClick = function()
				if not this then return end
				local checked = this:GetChecked() == 1
				ZHunterMod_Saved[buttonName]["parenttooltip"] = checked
				if buttonObj then buttonObj.parentTooltip = checked end
			end,
		})
	end

	local childrenBox = panel:Box("left", containerName.."ChildrenSection", MTH_ZB_L("ZB_SECTION_CHILDREN_BUTTONS", "Children Buttons"))
	childrenBox:Slider(containerName.."ButtonSize", {
		label = MTH_ZB_L("ZB_LABEL_BUTTON_SIZE", "Button Size"),
		min = 10, max = 100, step = 1, value = saved["children"]["size"] or 36,
		onChange = function(val)
			if not (ZHunterMod_Saved and ZHunterMod_Saved[buttonName]) then return end
			if not ZHunterMod_Saved[buttonName]["children"] then
				ZHunterMod_Saved[buttonName]["children"] = {}
			end
			ZHunterMod_Saved[buttonName]["children"]["size"] = math.floor((val or 0) + 0.5)
			MTH_RefreshButtonGeometry(buttonName, buttonObj)
		end,
	})

	childrenBox:Slider(containerName.."RowCount", {
		label = MTH_ZB_L("ZB_LABEL_NUMBER_OF_ROWS", "Number of Rows"),
		min = 1, max = maxButtons, step = 1, value = saved["rows"] or 1,
		onChange = function(val)
			if not (ZHunterMod_Saved and ZHunterMod_Saved[buttonName]) then return end
			ZHunterMod_Saved[buttonName]["rows"] = math.floor((val or 1) + 0.5)
			MTH_RefreshButtonGeometry(buttonName, buttonObj)
		end,
	})

	childrenBox:Checkbox(containerName.."ExpandLeft", MTH_ZB_L("ZB_LABEL_EXPAND_LEFT", "Expand Left (opposite side)"), {
		checked = (saved["firstbutton"] == "LEFT"),
		onClick = function()
			if not this then return end
			local checked = this:GetChecked() == 1
			if not (ZHunterMod_Saved and ZHunterMod_Saved[buttonName]) then return end
			ZHunterMod_Saved[buttonName]["firstbutton"] = checked and "LEFT" or "RIGHT"
			ZHunterMod_Saved[buttonName]["horizontal"] = checked and 1 or nil
			ZHunterMod_Saved[buttonName]["vertical"] = checked and 1 or nil
			MTH_RefreshButtonGeometry(buttonName, buttonObj)
		end,
	})

	childrenBox:Checkbox(containerName.."HideOnClick", MTH_ZB_L("ZB_LABEL_HIDE_BUTTONS_ON_CLICK", "Hide Buttons On Click"), {
		checked = saved["children"]["hideonclick"],
		onClick = function()
			if not this then return end
			local checked = this:GetChecked() == 1
			ZHunterMod_Saved[buttonName]["children"]["hideonclick"] = checked
			if buttonObj then buttonObj.hideonclick = checked end
		end,
	})
	if buttonObj then
		buttonObj.hideonclick = saved["children"]["hideonclick"] and true or false
	end

	childrenBox:Checkbox(containerName.."ExpandOnHover", MTH_ZB_L("ZB_LABEL_EXPAND_ON_HOVER", "Expand on Hover"), {
		checked = saved["children"]["expandonhover"],
		onClick = function()
			if not this then return end
			local checked = this:GetChecked() == 1
			if not (ZHunterMod_Saved and ZHunterMod_Saved[buttonName]) then return end
			if not ZHunterMod_Saved[buttonName]["children"] then
				ZHunterMod_Saved[buttonName]["children"] = {}
			end
			ZHunterMod_Saved[buttonName]["children"]["expandonhover"] = checked
			if buttonObj then buttonObj.expandonhover = checked end
		end,
	})

	childrenBox:Slider(containerName.."FadeTimer", {
		label = MTH_ZB_L("ZB_LABEL_AUTO_HIDE_TIMER", "Auto-Hide Timer (seconds)"),
		min = 0, max = 10, step = 1, value = saved["children"]["fadetimer"] or 0,
		onChange = function(val)
			if not (ZHunterMod_Saved and ZHunterMod_Saved[buttonName]) then return end
			if not ZHunterMod_Saved[buttonName]["children"] then
				ZHunterMod_Saved[buttonName]["children"] = {}
			end
			local secs = math.floor((val or 0) + 0.5)
			ZHunterMod_Saved[buttonName]["children"]["fadetimer"] = secs
			if buttonObj then
				buttonObj.fadetimer = secs
				if secs <= 0 then
					ZSpellButton_StopFadeTimer(buttonObj)
				elseif buttonObj.children and buttonObj.children:IsVisible() then
					ZSpellButton_StartFadeTimer(buttonObj)
				end
			end
		end,
	})

	childrenBox:Checkbox(containerName.."ShowTooltip", MTH_ZB_L("ZB_LABEL_SHOW_TOOLTIP", "Show Tooltip"), {
		checked = saved["tooltip"],
		onClick = function()
			if not this then return end
			local checked = this:GetChecked() == 1
			ZHunterMod_Saved[buttonName]["tooltip"] = checked
			if buttonObj then buttonObj.tooltip = checked end
		end,
	})
	if buttonObj then
		buttonObj.tooltip = saved["tooltip"] and true or false
	end

	if buttonName == "zButtonTrap" then
		childrenBox:Checkbox(containerName.."ShowCooldown", MTH_ZB_L("ZB_LABEL_SHOW_TRAP_COOLDOWN", "Show cooldown"), {
			checked = saved["cooldown"] and true or false,
			onClick = function()
				if not this then return end
				local checked = this:GetChecked() == 1
				if not (ZHunterMod_Saved and ZHunterMod_Saved[buttonName]) then return end
				ZHunterMod_Saved[buttonName]["cooldown"] = checked
			end,
		})
	end

	if buttonName == "zButtonAmmo" then
		childrenBox:Checkbox(containerName.."ShowAmmoName", MTH_ZB_L("ZB_LABEL_SHOW_AMMO_NAME", "Show ammo name"), {
			checked = saved["showammoname"],
			onClick = function()
				if not this then return end
				local checked = this:GetChecked() == 1
				ZHunterMod_Saved[buttonName]["showammoname"] = checked
				if buttonObj then
					for i = 1, (buttonObj.count or 0) do
						local child = getglobal(buttonName..i)
						if child and child.ammoname and not child.isspell then
							zButtonAmmo_UpdateButton(child)
						end
					end
					if buttonObj.ammoname and not buttonObj.isspell then
						zButtonAmmo_UpdateButton(buttonObj)
					end
				end
			end,
		})
	end

	MTH_SetButtonEnabledState(buttonName, buttonObj, saved["enabled"] and true or false)

	local advHeader = container:CreateFontString(containerName.."AdvHeader", "ARTWORK", "GameFontHighlight")
	advHeader:SetPoint("TOPLEFT", container, "TOPLEFT", rightX, -10)
	advHeader:SetText(MTH_ZB_L("ZB_HEADER_SPELL_ORDER", "Spell Order"))

	local itemList = MTH_GetButtonItemList(buttonName)

	if not itemList or not ZHunterMod_Saved[buttonName]["spells"] then
		local noData = container:CreateFontString(containerName.."NoData", "ARTWORK", "GameFontNormalSmall")
		noData:SetPoint("TOPRIGHT", container, "TOPRIGHT", -80, -50)
		noData:SetText(MTH_ZB_L("ZB_TEXT_SPELL_DATA_NOT_LOADED", "Spell data not loaded"))
		noData:SetTextColor(1, 0.5, 0.5)
		return
	end

	if not ZHunterMod_Saved[buttonName]["visible"] then
		ZHunterMod_Saved[buttonName]["visible"] = {}
	end
	for i = 1, maxButtons do
		if ZHunterMod_Saved[buttonName]["visible"][i] == nil then
			ZHunterMod_Saved[buttonName]["visible"][i] = 1
		end
	end

	local listY = -35

	for i = 1, maxButtons do
		local spellIndex = ZHunterMod_Saved[buttonName]["spells"][i]
		local spellName = itemList[spellIndex] or itemList[i] or ""
		local controlsOffset = 86
		local labelWidth = rightWidth - controlsOffset
		if labelWidth < 130 then labelWidth = 130 end
		local rowX = rightX
		local downX = rowX + 30
		local upX = downX + 22
		local labelX = upX + 26

		local showToggle = MTH_CreateCheckbox(container, containerName.."ShowToggle"..i, "", 0)
		if showToggle then
			showToggle:ClearAllPoints()
			showToggle:SetPoint("TOPLEFT", container, "TOPLEFT", rowX, listY + 2)
			showToggle.spellIndex = spellIndex or i
			showToggle.buttonName = buttonName
			showToggle.containerName = containerName
			showToggle.buttonObj = buttonObj
			showToggle.itemList = itemList
			showToggle.maxButtons = maxButtons
			local showText = getglobal(containerName.."ShowToggle"..i.."Text")
			if showText then
				showText:SetText("")
			end
			showToggle:SetChecked(ZHunterMod_Saved[buttonName]["visible"][showToggle.spellIndex] ~= false)
			showToggle:SetScript("OnClick", function()
				if not this then return end
				local checked = this:GetChecked() == 1
				local btnName = this.buttonName
				local visibleIndex = this.spellIndex
				if not ZHunterMod_Saved[btnName]["visible"] then
					ZHunterMod_Saved[btnName]["visible"] = {}
				end
				ZHunterMod_Saved[btnName]["visible"][visibleIndex] = checked
				MTH_RefreshButtonLayout(btnName, this.buttonObj, this.itemList, this.maxButtons)
			end)
		end

		local downBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
		downBtn:SetPoint("TOPLEFT", container, "TOPLEFT", downX, listY)
		downBtn:SetWidth(20)
		downBtn:SetHeight(20)
		downBtn:SetText("-")
		downBtn.spellIndex = i
		downBtn.buttonName = buttonName
		downBtn.containerName = containerName
		downBtn.buttonObj = buttonObj
		downBtn.itemList = itemList
		downBtn.maxButtons = maxButtons
		downBtn:SetScript("OnClick", function()
			if not this then return end
			local idx = this.spellIndex
			local btnName = this.buttonName
			local contName = this.containerName
			local maxBtns = this.maxButtons
			if idx < maxBtns then
				local temp = ZHunterMod_Saved[btnName]["spells"][idx+1]
				ZHunterMod_Saved[btnName]["spells"][idx+1] = ZHunterMod_Saved[btnName]["spells"][idx]
				ZHunterMod_Saved[btnName]["spells"][idx] = temp
				MTH_RebuildSpellOrder(btnName, this.buttonObj, this.itemList, this.maxButtons)
				local tabName = gsub(contName, "MetaHuntOptions", "")
				MTH_ZB_RefreshTab(tabName)
			end
		end)

		local upBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
		upBtn:SetPoint("TOPLEFT", container, "TOPLEFT", upX, listY)
		upBtn:SetWidth(20)
		upBtn:SetHeight(20)
		upBtn:SetText("+")
		upBtn.spellIndex = i
		upBtn.buttonName = buttonName
		upBtn.containerName = containerName
		upBtn.buttonObj = buttonObj
		upBtn.itemList = itemList
		upBtn.maxButtons = maxButtons
		upBtn:SetScript("OnClick", function()
			if not this then return end
			local idx = this.spellIndex
			local btnName = this.buttonName
			local contName = this.containerName
			if idx > 1 then
				local temp = ZHunterMod_Saved[btnName]["spells"][idx-1]
				ZHunterMod_Saved[btnName]["spells"][idx-1] = ZHunterMod_Saved[btnName]["spells"][idx]
				ZHunterMod_Saved[btnName]["spells"][idx] = temp
				MTH_RebuildSpellOrder(btnName, this.buttonObj, this.itemList, this.maxButtons)
				local tabName = gsub(contName, "MetaHuntOptions", "")
				MTH_ZB_RefreshTab(tabName)
			end
		end)

		local label = container:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		label:SetPoint("TOPLEFT", container, "TOPLEFT", labelX, listY)
		label:SetText(spellName)
		label:SetWidth(labelWidth)
		label:SetJustifyH("LEFT")

		listY = listY - 25
	end
end

-- ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
-- zBar options
-- ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

function MTH_SetupZBarOptions()
	if not MTH_ZBUTTONS_READY then return end
	local container = MTH_GetFrame("MetaHuntOptionsZBar")
	if not container then return end
	MTH_ClearContainer(container)

	if type(MTH_ZBar_GetSaved) ~= "function" then
		local err = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		err:SetPoint("CENTER", container, "CENTER", 0, 0)
		err:SetText("zBar module not loaded")
		err:SetTextColor(1, 0.5, 0.5)
		return
	end

	local s               = MTH_ZBar_GetSaved()
	local containerWidth  = container:GetWidth() or 500
	local leftWidth       = 260
	local rightX          = leftWidth + 44
	local rightWidth      = containerWidth - rightX - 12

	local panel = MTH_Layout.Panel(container)

	panel:TopCheckbox("MetaHuntOptionsZBarEnable", "Enable zBar", {
		checked = s.enabled,
		onClick = function()
			if type(MTH_ZBar_SetEnabled) == "function" then
				MTH_ZBar_SetEnabled(this:GetChecked() == 1)
			end
		end,
	})
	panel:Note("Group all zButtons into a single draggable bar.", { width = 240 })

	-- ===== Bar Direction box =====
	local dirBox = panel:Box("left", "MetaHuntOptionsZBarDirBox", "Bar Direction")

	dirBox:Checkbox("MetaHuntOptionsZBarHoriz", "Horizontal (side by side)", {
		checked = (s.direction ~= "VERTICAL"),
		onClick = function()
			if this:GetChecked() == 1 then
				local sv = MTH_ZBar_GetSaved()
				sv.direction = "HORIZONTAL"
				-- Auto-correct childexpand to a valid side for a horizontal bar
				if sv.childexpand ~= "TOP" and sv.childexpand ~= "BOTTOM" then
					sv.childexpand = "BOTTOM"
				end
				local v = getglobal("MetaHuntOptionsZBarVert")
				if v then v:SetChecked(false) end
				if sv.enabled and type(MTH_ZBar_ApplyLayout) == "function" then
					MTH_ZBar_ApplyLayout()
				end
				MTH_ResetAndSelectOptionsTab("ZBar")
			else
				this:SetChecked(true)
			end
		end,
	})

	dirBox:Checkbox("MetaHuntOptionsZBarVert", "Vertical (stacked)", {
		checked = (s.direction == "VERTICAL"),
		onClick = function()
			if this:GetChecked() == 1 then
				local sv = MTH_ZBar_GetSaved()
				sv.direction = "VERTICAL"
				-- Auto-correct childexpand to a valid side for a vertical bar
				if sv.childexpand ~= "LEFT" and sv.childexpand ~= "RIGHT" then
					sv.childexpand = "RIGHT"
				end
				local h = getglobal("MetaHuntOptionsZBarHoriz")
				if h then h:SetChecked(false) end
				if sv.enabled and type(MTH_ZBar_ApplyLayout) == "function" then
					MTH_ZBar_ApplyLayout()
				end
				MTH_ResetAndSelectOptionsTab("ZBar")
			else
				this:SetChecked(true)
			end
		end,
	})

	-- ===== Children box =====
	local childBox = panel:Box("left", "MetaHuntOptionsZBarChildBox", "Children")

	local exp1Val, exp2Val, exp1Lbl, exp2Lbl, expNote
	if s.direction == "VERTICAL" then
		exp1Val = "LEFT"  ; exp1Lbl = "Left"
		exp2Val = "RIGHT" ; exp2Lbl = "Right"
		expNote = "Expand side (Vertical bar):"
	else
		exp1Val = "TOP"    ; exp1Lbl = "Top (above)"
		exp2Val = "BOTTOM" ; exp2Lbl = "Bottom (below)"
		expNote = "Expand side (Horizontal bar):"
	end

	childBox:Note("MetaHuntOptionsZBarExpNote", expNote)

	childBox:Checkbox("MetaHuntOptionsZBarExp1", exp1Lbl, {
		checked = (s.childexpand == exp1Val),
		onClick = function()
			if this:GetChecked() == 1 then
				local sv = MTH_ZBar_GetSaved()
				sv.childexpand = exp1Val
				if sv.enabled and type(MTH_ZBar_ApplyLayout) == "function" then MTH_ZBar_ApplyLayout() end
				MTH_ResetAndSelectOptionsTab("ZBar")
			else
				this:SetChecked(true)
			end
		end,
	})

	childBox:Checkbox("MetaHuntOptionsZBarExp2", exp2Lbl, {
		checked = (s.childexpand == exp2Val),
		onClick = function()
			if this:GetChecked() == 1 then
				local sv = MTH_ZBar_GetSaved()
				sv.childexpand = exp2Val
				if sv.enabled and type(MTH_ZBar_ApplyLayout) == "function" then MTH_ZBar_ApplyLayout() end
				MTH_ResetAndSelectOptionsTab("ZBar")
			else
				this:SetChecked(true)
			end
		end,
	})

	childBox:Gap(6)
	childBox:Note("MetaHuntOptionsZBarArrNote", "Layout:")

	childBox:Checkbox("MetaHuntOptionsZBarArrV", "Vertical (stacked column)", {
		checked = ((s.childarrange or "VERTICAL") == "VERTICAL"),
		onClick = function()
			if this:GetChecked() == 1 then
				local sv = MTH_ZBar_GetSaved()
				sv.childarrange = "VERTICAL"
				if sv.enabled and type(MTH_ZBar_ApplyLayout) == "function" then MTH_ZBar_ApplyLayout() end
				MTH_ResetAndSelectOptionsTab("ZBar")
			else
				this:SetChecked(true)
			end
		end,
	})

	childBox:Checkbox("MetaHuntOptionsZBarArrH", "Horizontal (side-by-side row)", {
		checked = ((s.childarrange or "VERTICAL") == "HORIZONTAL"),
		onClick = function()
			if this:GetChecked() == 1 then
				local sv = MTH_ZBar_GetSaved()
				sv.childarrange = "HORIZONTAL"
				if sv.enabled and type(MTH_ZBar_ApplyLayout) == "function" then MTH_ZBar_ApplyLayout() end
				MTH_ResetAndSelectOptionsTab("ZBar")
			else
				this:SetChecked(true)
			end
		end,
	})

	-- ===== Sizing box =====
	local sizeBox = panel:Box("left", "MetaHuntOptionsZBarSizeBox", "Sizing")

	sizeBox:Slider("MetaHuntOptionsZBarSpacing", {
		label = "Spacing (px)",
		min = 0, max = 30, step = 1, value = tonumber(s.spacing) or 4,
		onChange = function(val)
			local sv = MTH_ZBar_GetSaved()
			sv.spacing = math.floor((tonumber(val) or 4) + 0.5)
			if sv.enabled and type(MTH_ZBar_ApplyLayout) == "function" then
				MTH_ZBar_ApplyLayout()
			end
		end,
	})

	sizeBox:Slider("MetaHuntOptionsZBarSize", {
		label = "Button Size",
		min = 10, max = 100, step = 1, value = tonumber(s.size) or 36,
		onChange = function(val)
			if type(MTH_ZBar_SetSize) == "function" then
				MTH_ZBar_SetSize(val)
			end
		end,
	})

	-- ===== Right column: Bar Order =====
	local orderHeader = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	orderHeader:SetPoint("TOPLEFT", container, "TOPLEFT", rightX, -10)
	orderHeader:SetText("Bar Order")

	local LABELS    = MTH_ZBar_GetAllButtonLabels()
	local numBars   = table.getn(s.order)
	local listY     = -35
	local downX     = rightX + 28
	local upX       = downX + 22
	local labelX    = upX + 26
	local labelWidth = rightWidth - (labelX - rightX) - 8
	if labelWidth < 80 then labelWidth = 80 end

	for i = 1, numBars do
		local buttonName  = s.order[i]
		local displayName = (LABELS and LABELS[buttonName]) or buttonName

		-- Include/exclude visibility toggle
		local toggleName = "MetaHuntOptionsZBarToggle" .. i
		local showToggle = CreateFrame("CheckButton", toggleName, container, "UICheckButtonTemplate")
		if showToggle then
			showToggle:ClearAllPoints()
			showToggle:SetPoint("TOPLEFT", container, "TOPLEFT", rightX, listY + 2)
			local tText = getglobal(toggleName .. "Text")
			if tText then tText:SetText("") end
			showToggle:SetChecked(s.visible[buttonName] ~= false)
			showToggle.zbarName = buttonName
			showToggle:SetScript("OnClick", function()
				local sv = MTH_ZBar_GetSaved()
				sv.visible[this.zbarName] = (this:GetChecked() == 1)
				if sv.enabled and type(MTH_ZBar_ApplyLayout) == "function" then
					MTH_ZBar_ApplyLayout()
				end
			end)
		end

		-- Move Down (-)
		local downBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
		downBtn:SetPoint("TOPLEFT", container, "TOPLEFT", downX, listY)
		downBtn:SetWidth(20)
		downBtn:SetHeight(20)
		downBtn:SetText("-")
		downBtn.zbarIndex = i
		downBtn:SetScript("OnClick", function()
			local idx = this.zbarIndex
			local sv  = MTH_ZBar_GetSaved()
			local tot = table.getn(sv.order)
			if idx < tot then
				local tmp      = sv.order[idx + 1]
				sv.order[idx + 1] = sv.order[idx]
				sv.order[idx]     = tmp
				MTH_ResetAndSelectOptionsTab("ZBar")
				if sv.enabled and type(MTH_ZBar_ApplyLayout) == "function" then
					MTH_ZBar_ApplyLayout()
				end
			end
		end)

		-- Move Up (+)
		local upBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
		upBtn:SetPoint("TOPLEFT", container, "TOPLEFT", upX, listY)
		upBtn:SetWidth(20)
		upBtn:SetHeight(20)
		upBtn:SetText("+")
		upBtn.zbarIndex = i
		upBtn:SetScript("OnClick", function()
			local idx = this.zbarIndex
			local sv  = MTH_ZBar_GetSaved()
			if idx > 1 then
				local tmp         = sv.order[idx - 1]
				sv.order[idx - 1] = sv.order[idx]
				sv.order[idx]     = tmp
				MTH_ResetAndSelectOptionsTab("ZBar")
				if sv.enabled and type(MTH_ZBar_ApplyLayout) == "function" then
					MTH_ZBar_ApplyLayout()
				end
			end
		end)

		-- Bar name label
		local lbl = container:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		lbl:SetPoint("TOPLEFT", container, "TOPLEFT", labelX, listY)
		lbl:SetText(displayName)
		lbl:SetWidth(labelWidth)
		lbl:SetJustifyH("LEFT")

		listY = listY - 25
	end
end

function MTH_SetupPetOptions()
	if not MTH_ZBUTTONS_READY then return end
	MTH_SetupButtonOptions("MetaHuntOptionsPet", "zButtonPet", "ZPet", 10)
end

function MTH_SetupTrackOptions()
	if not MTH_ZBUTTONS_READY then return end
	MTH_SetupButtonOptions("MetaHuntOptionsTrack", "zButtonTrack", "ZTrack", 11)
end

function MTH_SetupAspectOptions()
	if not MTH_ZBUTTONS_READY then return end
	MTH_SetupButtonOptions("MetaHuntOptionsAspect", "zButtonAspect", "ZAspect", 7)
end

function MTH_SetupTrapOptions()
	if not MTH_ZBUTTONS_READY then return end
	MTH_SetupButtonOptions("MetaHuntOptionsTrap", "zButtonTrap", "ZTrap", 4)
end

function MTH_SetupRangedOptions()
	if not MTH_ZBUTTONS_READY then return end
	local itemList = MTH_GetButtonItemList("zButtonRanged")
	local maxButtons = itemList and table.getn(itemList) or 1
	MTH_SetupButtonOptions("MetaHuntOptionsRanged", "zButtonRanged", "ZRanged", maxButtons)
end

function MTH_SetupAmmoOptions()
	if not MTH_ZBUTTONS_READY then return end
	MTH_EnsureAmmoOptionsWatcher()
	local itemList = MTH_GetButtonItemList("zButtonAmmo")
	local maxButtons = itemList and table.getn(itemList) or 0
	if maxButtons < 1 then
		maxButtons = ZHunterMod_Ammo_Buttons and table.getn(ZHunterMod_Ammo_Buttons) or 11
	end
	MTH_SetupButtonOptions("MetaHuntOptionsAmmo", "zButtonAmmo", "ZAmmo", maxButtons)
end

function MTH_SetupMountsOptions()
	if not MTH_ZBUTTONS_READY then return end
	local itemList = MTH_GetButtonItemList("zButtonMounts")
	local maxButtons = itemList and table.getn(itemList) or 1
	MTH_SetupButtonOptions("MetaHuntOptionsMounts", "zButtonMounts", "ZMounts", maxButtons)
end

function MTH_SetupCompanionsOptions()
	if not MTH_ZBUTTONS_READY then return end
	local itemList = MTH_GetButtonItemList("zButtonCompanions")
	local maxButtons = itemList and table.getn(itemList) or 1
	MTH_SetupButtonOptions("MetaHuntOptionsCompanions", "zButtonCompanions", "ZCompanions", maxButtons)
end

function MTH_SetupToysOptions()
	if not MTH_ZBUTTONS_READY then return end
	local itemList = MTH_GetButtonItemList("zButtonToys")
	local maxButtons = itemList and table.getn(itemList) or 1
	MTH_SetupButtonOptions("MetaHuntOptionsToys", "zButtonToys", "ZToys", maxButtons)
end

function MTH_SetupCraftOptions()
	if not MTH_ZBUTTONS_READY then return end
	local itemList = MTH_GetButtonItemList("zButtonCraft")
	local maxButtons = itemList and table.getn(itemList) or 1
	MTH_SetupButtonOptions("MetaHuntOptionsCraft", "zButtonCraft", "ZCraft", maxButtons)
end

function MTH_SetupSmartAmmoOptions()
	if not MTH_ZBUTTONS_READY then return end
	local container = MTH_GetFrame("MetaHuntOptionsSmartAmmo")
	if not container then return end

	MTH_ClearContainer(container)

	local title = container:CreateFontString("MetaHuntOptionsSmartAmmoTitle", "ARTWORK", "GameFontHighlight")
	title:SetPoint("TOPLEFT", container, "TOPLEFT", 20, -10)
	title:SetText("Smart Ammo")

	local body = container:CreateFontString("MetaHuntOptionsSmartAmmoBody", "ARTWORK", "GameFontNormalSmall")
	body:SetPoint("TOPLEFT", container, "TOPLEFT", 20, -38)
	body:SetWidth(390)
	body:SetJustifyH("LEFT")
	body:SetText("Configure Smart Ammo directly from MetaHunt.")

	local moduleToggle = MTH_CreateCheckbox(container, "MetaHuntOptionsSmartAmmoModule", "Enable SmartAmmo Module", -68)
	local moduleEnabled = true
	if MTH and MTH.IsModuleEnabled then
		moduleEnabled = MTH:IsModuleEnabled("smartammo", true) and true or false
	end
	if moduleToggle then
		moduleToggle:SetChecked(moduleEnabled)
		moduleToggle:SetScript("OnClick", function()
			if not this then return end
			if MTH and MTH.SetModuleEnabled then
				MTH:SetModuleEnabled("smartammo", MTH_ZB_IsChecked(this))
			end
			MTH_SetupSmartAmmoOptions()
		end)
	end

	local smartToggle = MTH_CreateCheckbox(container, "MetaHuntOptionsSmartAmmoEnabled", "Enable Junk Shot Swaps", -94)
	if smartToggle then
		local enabled = type(MTHSmartAmmo_GetSmartEnabled) == "function" and MTHSmartAmmo_GetSmartEnabled() and true or false
		smartToggle:SetChecked(enabled)
		if not moduleEnabled then
			smartToggle:Disable()
		end
		smartToggle:SetScript("OnClick", function()
			if not this then return end
			if type(MTHSmartAmmo_SetSmartEnabled) == "function" then
				MTHSmartAmmo_SetSmartEnabled(MTH_ZB_IsChecked(this) and 1 or nil)
			end
		end)
	end

	local reloadToggle = MTH_CreateCheckbox(container, "MetaHuntOptionsSmartAmmoReload", "Enable Auto-Fallback", -120)
	if reloadToggle then
		local reloadEnabled = true
		if type(MTHSmartAmmo_GetReloadEnabled) == "function" then
			reloadEnabled = MTHSmartAmmo_GetReloadEnabled() and true or false
		end
		reloadToggle:SetChecked(reloadEnabled)
		if not moduleEnabled then
			reloadToggle:Disable()
		end
		reloadToggle:SetScript("OnClick", function()
			if not this then return end
			if type(MTHSmartAmmo_SetReloadEnabled) == "function" then
				MTHSmartAmmo_SetReloadEnabled(MTH_ZB_IsChecked(this) and 1 or nil)
			end
		end)
	end
end

function MTH_SetupMessagesOptions()
	if not MTH_ZBUTTONS_READY then return end
	local container = MTH_GetFrame("MetaHuntOptionsMessages")
	if not container then return end

	MTH_ClearContainer(container)

	local section = CreateFrame("Frame", "MetaHuntMessagesSection", container, "OptionFrameBoxTemplate")
	if not section then return end
	section:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -8)
	section:SetPoint("TOPRIGHT", container, "TOPRIGHT", -8, -8)
	section:SetHeight(380)

	local titleFrame = getglobal("MetaHuntMessagesSectionTitle")
	if titleFrame then
		titleFrame:SetText("Messages")
	end

	local help = section:CreateFontString("MetaHuntMessagesHelp", "ARTWORK")
	help:SetFont("Fonts\\FRIZQT__.TTF", 10)
	help:SetJustifyH("LEFT")
	help:SetPoint("TOPLEFT", section, "TOPLEFT", 14, -12)
	help:SetPoint("TOPRIGHT", section, "TOPRIGHT", -14, -12)
	help:SetText("Enable or Disable Metahunt chat messages")

	local msgSettings = (MTH and MTH.GetMessageSettings and MTH:GetMessageSettings()) or {}

	local initModulesToggle = MTH_CreateCheckbox(section, "MetaHuntMessagesInitModules", "Init : modules loaded", -36)
	if initModulesToggle then
		initModulesToggle:SetChecked(msgSettings.initModulesLoaded and true or false)
		initModulesToggle:SetScript("OnClick", function()
			if not this then return end
			if MTH and MTH.SetMessageEnabled then
				MTH:SetMessageEnabled("initModulesLoaded", MTH_ZB_IsChecked(this))
			end
		end)
	end

	local initWelcomeToggle = MTH_CreateCheckbox(section, "MetaHuntMessagesInitWelcome", "Init : Sarcastic welcome message", -64)
	if initWelcomeToggle then
		initWelcomeToggle:SetChecked(msgSettings.initSarcasticWelcome ~= false)
		initWelcomeToggle:SetScript("OnClick", function()
			if not this then return end
			if MTH and MTH.SetMessageEnabled then
				MTH:SetMessageEnabled("initSarcasticWelcome", MTH_ZB_IsChecked(this))
			end
		end)
	end

	local petHungryToggle = MTH_CreateCheckbox(section, "MetaHuntMessagesPetHungry", "Pet is hungry (spam)", -92)
	if petHungryToggle then
		petHungryToggle:SetChecked(msgSettings.petHungry and true or false)
		petHungryToggle:SetScript("OnClick", function()
			if not this then return end
			if MTH and MTH.SetMessageEnabled then
				MTH:SetMessageEnabled("petHungry", MTH_ZB_IsChecked(this))
			end
		end)
	end

	local beastTrainingScanToggle = MTH_CreateCheckbox(section, "MetaHuntMessagesBeastTrainingScan", "Beasttraining scan", -120)
	if beastTrainingScanToggle then
		beastTrainingScanToggle:SetChecked(msgSettings.beastTrainingScan ~= false)
		beastTrainingScanToggle:SetScript("OnClick", function()
			if not this then return end
			if MTH and MTH.SetMessageEnabled then
				MTH:SetMessageEnabled("beastTrainingScan", MTH_ZB_IsChecked(this))
			end
		end)
	end

	local spellbookScanToggle = MTH_CreateCheckbox(section, "MetaHuntMessagesSpellbookScan", "Spellbook scan", -148)
	if spellbookScanToggle then
		spellbookScanToggle:SetChecked(msgSettings.spellbookScan and true or false)
		spellbookScanToggle:SetScript("OnClick", function()
			if not this then return end
			if MTH and MTH.SetMessageEnabled then
				MTH:SetMessageEnabled("spellbookScan", MTH_ZB_IsChecked(this))
			end
		end)
	end

	local trainerScanToggle = MTH_CreateCheckbox(section, "MetaHuntMessagesTrainerScan", "Trainer scan", -176)
	if trainerScanToggle then
		trainerScanToggle:SetChecked(msgSettings.trainerScan ~= false)
		trainerScanToggle:SetScript("OnClick", function()
			if not this then return end
			if MTH and MTH.SetMessageEnabled then
				MTH:SetMessageEnabled("trainerScan", MTH_ZB_IsChecked(this))
			end
		end)
	end

	local petRanAwayToggle = MTH_CreateCheckbox(section, "MetaHuntMessagesPetRanAway", "Pet ran away", -204)
	if petRanAwayToggle then
		petRanAwayToggle:SetChecked(msgSettings.petRanAway ~= false)
		petRanAwayToggle:SetScript("OnClick", function()
			if not this then return end
			if MTH and MTH.SetMessageEnabled then
				MTH:SetMessageEnabled("petRanAway", MTH_ZB_IsChecked(this))
			end
		end)
	end

	local mapMarkersToggle = MTH_CreateCheckbox(section, "MetaHuntMessagesMapMarkers", "Map markers", -232)
	if mapMarkersToggle then
		mapMarkersToggle:SetChecked(msgSettings.mapMarkers ~= false)
		mapMarkersToggle:SetScript("OnClick", function()
			if not this then return end
			if MTH and MTH.SetMessageEnabled then
				MTH:SetMessageEnabled("mapMarkers", MTH_ZB_IsChecked(this))
			end
		end)
	end

	local hunterLevelToggle = MTH_CreateCheckbox(section, "MetaHuntMessagesHunterLevel", "Hunter level training summary", -260)
	if hunterLevelToggle then
		hunterLevelToggle:SetChecked(msgSettings.hunterLevelUp ~= false)
		hunterLevelToggle:SetScript("OnClick", function()
			if MTH and MTH.SetMessageEnabled then MTH:SetMessageEnabled("hunterLevelUp", MTH_ZB_IsChecked(this)) end
		end)
	end

	local hunterQuietLevelToggle = MTH_CreateCheckbox(section, "MetaHuntMessagesHunterQuietLevel", "Hunter quiet-level message", -288)
	if hunterQuietLevelToggle then
		hunterQuietLevelToggle:SetChecked(msgSettings.hunterLevelQuiet and true or false)
		hunterQuietLevelToggle:SetScript("OnClick", function()
			if MTH and MTH.SetMessageEnabled then MTH:SetMessageEnabled("hunterLevelQuiet", MTH_ZB_IsChecked(this)) end
		end)
	end

	local petLevelToggle = MTH_CreateCheckbox(section, "MetaHuntMessagesPetLevel", "Pet level training summary", -316)
	if petLevelToggle then
		petLevelToggle:SetChecked(msgSettings.petLevelUp ~= false)
		petLevelToggle:SetScript("OnClick", function()
			if MTH and MTH.SetMessageEnabled then MTH:SetMessageEnabled("petLevelUp", MTH_ZB_IsChecked(this)) end
		end)
	end

	local petLoyaltyToggle = MTH_CreateCheckbox(section, "MetaHuntMessagesPetLoyalty", "Pet loyalty gain", -344)
	if petLoyaltyToggle then
		petLoyaltyToggle:SetChecked(msgSettings.petLoyaltyUp ~= false)
		petLoyaltyToggle:SetScript("OnClick", function()
			if MTH and MTH.SetMessageEnabled then MTH:SetMessageEnabled("petLoyaltyUp", MTH_ZB_IsChecked(this)) end
		end)
	end

end

function MTH_SetupGeneralOptions()
	if not MTH_ZBUTTONS_READY then return end
	local parentFrame = MTH_GetFrame("MetaHuntOptionsGeneral")
	if not parentFrame then
		return
	end

	local stripSaved = AutoStrip_GetSaved and AutoStrip_GetSaved() or {}

	local panel = MTH_Layout.Panel(parentFrame)

	-- ===== LEFT: Smart Ammo =====
	local smartBox = panel:Box("left", "MetaHuntGeneralSmartAmmoBox", "Smart Ammo")
	local smartModuleEnabled = MTH and MTH.IsModuleEnabled and MTH:IsModuleEnabled("smartammo", true)
	smartBox:Checkbox("MetaHuntGeneralSmartAmmoModuleToggle", "Enable module", {
		checked = smartModuleEnabled,
		onClick = function()
			local enabled = this:GetChecked() == 1
			if MTH and MTH.SetModuleEnabled then
				local ok = MTH:SetModuleEnabled("smartammo", enabled)
				if not ok then
					this:SetChecked(smartModuleEnabled and true or false)
					return
				end
				smartModuleEnabled = enabled
			end
			MTH_SetupGeneralOptions()
		end,
	})

	local smartEnabled = true
	if type(MTHSmartAmmo_GetSmartEnabled) == "function" then
		smartEnabled = MTHSmartAmmo_GetSmartEnabled() and true or false
	end
	local smartToggle = smartBox:Checkbox("MetaHuntGeneralSmartAmmoEnabledToggle", "Enable Junk Shot Swaps", {
		checked = smartEnabled,
		onClick = function()
			if type(MTHSmartAmmo_SetSmartEnabled) == "function" then
				MTHSmartAmmo_SetSmartEnabled(this:GetChecked() == 1 and 1 or nil)
			end
		end,
	})
	if not smartModuleEnabled and smartToggle and smartToggle.Disable then smartToggle:Disable() end
	smartBox:Note("MetaHuntGeneralSmartAmmoEnabledHelp", "Swaps to low-tier ammo for shots that don't scale on weapon damage, then swaps back to your previous ammo.")

	local reloadEnabled = type(MTHSmartAmmo_GetReloadEnabled) == "function" and MTHSmartAmmo_GetReloadEnabled() and true or false
	local reloadToggle = smartBox:Checkbox("MetaHuntGeneralSmartAmmoReloadToggle", "Enable Auto-Fallback", {
		checked = reloadEnabled,
		onClick = function()
			if type(MTHSmartAmmo_SetReloadEnabled) == "function" then
				MTHSmartAmmo_SetReloadEnabled(this:GetChecked() == 1 and 1 or nil)
			end
		end,
	})
	if not smartModuleEnabled and reloadToggle and reloadToggle.Disable then reloadToggle:Disable() end
	smartBox:Note("MetaHuntGeneralSmartAmmoReloadHelp", "Falls back to any available ammo when equipped ammo is out of stock.")

	local weaponSwapEnabled = type(MTHSmartAmmo_GetWeaponSwapEnabled) == "function" and MTHSmartAmmo_GetWeaponSwapEnabled() and true or false
	local weaponSwapToggle = smartBox:Checkbox("MetaHuntGeneralSmartAmmoWeaponSwapToggle", "Enable Weapon-Swap Auto Ammo", {
		checked = weaponSwapEnabled,
		onClick = function()
			if type(MTHSmartAmmo_SetWeaponSwapEnabled) == "function" then
				MTHSmartAmmo_SetWeaponSwapEnabled(this:GetChecked() == 1 and 1 or nil)
			end
		end,
	})
	if not smartModuleEnabled and weaponSwapToggle and weaponSwapToggle.Disable then weaponSwapToggle:Disable() end
	smartBox:Note("MetaHuntGeneralSmartAmmoWeaponSwapHelp", "When you swap between gun and bow/crossbow, instantly equips the best matching ammo from your bags.")

	local lowAmmoWarningEnabled = type(MTHSmartAmmo_GetLowAmmoWarningEnabled) == "function" and MTHSmartAmmo_GetLowAmmoWarningEnabled() and true or false
	local lowAmmoWarningToggle = smartBox:Checkbox("MetaHuntGeneralSmartAmmoLowWarningToggle", "Enable low-ammo warnings", {
		checked = lowAmmoWarningEnabled,
		onClick = function()
			if type(MTHSmartAmmo_SetLowAmmoWarningEnabled) == "function" then
				MTHSmartAmmo_SetLowAmmoWarningEnabled(this:GetChecked() == 1 and 1 or nil)
			end
		end,
	})
	if not smartModuleEnabled and lowAmmoWarningToggle and lowAmmoWarningToggle.Disable then lowAmmoWarningToggle:Disable() end

	local lowAmmoThreshold = type(MTHSmartAmmo_GetLowAmmoThreshold) == "function" and MTHSmartAmmo_GetLowAmmoThreshold() or 200
	local lowAmmoInput = smartBox:EditRow("MetaHuntGeneralSmartAmmoLowThresholdLabel", "Low-ammo threshold:", "MetaHuntGeneralSmartAmmoLowThreshold", 48, {
		numeric = true,
		onChange = function()
			if type(MTHSmartAmmo_SetLowAmmoThreshold) == "function" then
				MTHSmartAmmo_SetLowAmmoThreshold(this:GetText())
			end
		end,
	})
	if lowAmmoInput then
		lowAmmoInput:SetText(tostring(lowAmmoThreshold))
		if not smartModuleEnabled and lowAmmoInput.Disable then lowAmmoInput:Disable() end
	end
	smartBox:Note("MetaHuntGeneralSmartAmmoLowThresholdHelp", "Warns once when your total arrows or bullets reach this amount. Default: 200.")

	-- ===== LEFT: Auto-Strip =====
	local stripBox = panel:Box("left", "MetaHuntGeneralAutoStripBox", "Auto-Strip")
	stripBox:Checkbox("MetaHuntGeneralAutoStripToggle", "Enable Auto-Strip on Combat Exit", {
		checked = stripSaved["autostrip"] and true or false,
		onClick = function()
			if type(AutoStrip_SetAutoStripToggle) == "function" then
				AutoStrip_SetAutoStripToggle(this:GetChecked() == 1)
			end
		end,
	})
	stripBox:Checkbox("MetaHuntGeneralAutoStripDisplay", "Show Strip Button", {
		checked = stripSaved["display"] and true or false,
		onClick = function()
			if type(AutoStrip_SetDisplayToggle) == "function" then
				AutoStrip_SetDisplayToggle(this:GetChecked() == 1)
			end
		end,
	})
	stripBox:Note("MetaHuntGeneralAutoStripHelp", "Auto-strip unequips items when combat ends. Requires at least one empty bag slot.")

	-- ===== LEFT: Anti-Daze =====
	local antiBox = panel:Box("left", "MetaHuntGeneralAntiDazeBox", "Anti-Daze")
	local antiDazeEnabled = (AntiDaze_GetEnabled and AntiDaze_GetEnabled()) or false
	antiBox:Checkbox("MetaHuntGeneralAntiDazeToggle", "Enable Anti-Daze", {
		checked = antiDazeEnabled,
		onClick = function()
			local enabled = this:GetChecked() == 1
			if type(AntiDaze_SetEnabled) == "function" then
				AntiDaze_SetEnabled(enabled, 1)
			end
			if MTH and MTH.Print then
				MTH:Print("AntiDaze " .. (enabled and "Enabled." or "Disabled."))
			elseif DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage("AntiDaze " .. (enabled and "Enabled." or "Disabled."))
			end
		end,
	})
	antiBox:Note("MetaHuntGeneralAntiDazeHelp", "Cancels Cheetah/Pack when dazed.")

	-- ===== RIGHT: Tooltips =====
	local tooltipsBox = panel:Box("right", "MetaHuntGeneralTooltipsBox", "Tooltips")
	local tooltipsStore = MTH and MTH.GetModuleCharSavedVariables and MTH:GetModuleCharSavedVariables("tooltips")
	if type(tooltipsStore) ~= "table" then
		tooltipsStore = {}
	end
	if MTH and MTH.GetModuleSavedVariables and next(tooltipsStore) == nil then
		local accountStore = MTH:GetModuleSavedVariables("tooltips")
		if type(accountStore) == "table" and next(accountStore) ~= nil then
			for key, value in pairs(accountStore) do
				if type(value) == "table" then
					local copied = {}
					for subKey, subValue in pairs(value) do
						copied[subKey] = subValue
					end
					tooltipsStore[key] = copied
				else
					tooltipsStore[key] = value
				end
			end
		end
	end
	if tooltipsStore.beastTooltips == nil then
		tooltipsStore.beastTooltips = true
	end
	if tooltipsStore.ammoVendorTooltips == nil then
		tooltipsStore.ammoVendorTooltips = true
	end
	if tooltipsStore.foodItemTooltips == nil then
		if type(FOM_Config) == "table" and FOM_Config.Tooltip ~= nil then
			tooltipsStore.foodItemTooltips = FOM_Config.Tooltip and true or false
		else
			tooltipsStore.foodItemTooltips = true
		end
	end
	if tooltipsStore.ownPetTooltips == nil then
		tooltipsStore.ownPetTooltips = false
	end

	local tooltipsModuleEnabled = MTH and MTH.IsModuleEnabled and MTH:IsModuleEnabled("tooltips", true)
	local foodLabel = (MTH and MTH.GetLocalization and MTH:GetLocalization("TOOLTIPS_OPTION_FOOD", "Activate on food")) or "Activate on food"
	local foodHelp = (MTH and MTH.GetLocalization and MTH:GetLocalization("TOOLTIPS_OPTION_FOOD_HELP", "Show your current pet's food preference directly in item tooltips.")) or "Show your current pet's food preference directly in item tooltips."
	local ownPetLabel = (MTH and MTH.GetLocalization and MTH:GetLocalization("TOOLTIPS_OPTION_OWNPET", "Activate on my pet")) or "Activate on my pet"
	local ownPetHelp = (MTH and MTH.GetLocalization and MTH:GetLocalization("TOOLTIPS_OPTION_OWNPET_HELP", "Show your own pet status details in tooltip when hovering your pet context.")) or "Show your own pet status details in tooltip when hovering your pet context."

	tooltipsBox:Checkbox("MetaHuntGeneralTooltipsModuleToggle", "Enable module", {
		checked = tooltipsModuleEnabled,
		onClick = function()
			local enabled = this:GetChecked() == 1
			if MTH and MTH.SetModuleEnabled then
				local ok = MTH:SetModuleEnabled("tooltips", enabled)
				if not ok then
					this:SetChecked(tooltipsModuleEnabled and true or false)
					return
				end
				tooltipsModuleEnabled = enabled
			end
		end,
	})
	tooltipsBox:Note("MetaHuntGeneralTooltipsModuleHelp", "This module allows to enhance NPC tooltips with additional information useful for hunters.")

	tooltipsBox:Checkbox("MetaHuntGeneralTooltipsBeastToggle", "Activate on Beasts", {
		checked = tooltipsStore.beastTooltips and true or false,
		onClick = function()
			local enabled = this:GetChecked() == 1
			tooltipsStore.beastTooltips = enabled
			local tooltipsModule = MTH and MTH.GetModule and MTH:GetModule("tooltips")
			if tooltipsModule and tooltipsModule.SetBeastTooltipsEnabled then
				tooltipsModule:SetBeastTooltipsEnabled(enabled)
			end
		end,
	})
	tooltipsBox:Note("MetaHuntGeneralTooltipsBeastHelp", "When mouseover on a Beast, its tooltip will show if it can learn you any pet abilities. They appear Green if you already know them, and Red if you don't know them yet.")

	tooltipsBox:Checkbox("MetaHuntGeneralTooltipsOwnPetToggle", ownPetLabel, {
		checked = tooltipsStore.ownPetTooltips and true or false,
		onClick = function()
			local enabled = this:GetChecked() == 1
			tooltipsStore.ownPetTooltips = enabled
			local tooltipsModule = MTH and MTH.GetModule and MTH:GetModule("tooltips")
			if tooltipsModule and tooltipsModule.SetOwnPetTooltipsEnabled then
				tooltipsModule:SetOwnPetTooltipsEnabled(enabled)
			end
		end,
	})
	tooltipsBox:Note("MetaHuntGeneralTooltipsOwnPetHelp", ownPetHelp)

	tooltipsBox:Checkbox("MetaHuntGeneralTooltipsAmmoVendorToggle", "Activate on Vendors", {
		checked = tooltipsStore.ammoVendorTooltips and true or false,
		onClick = function()
			local enabled = this:GetChecked() == 1
			tooltipsStore.ammoVendorTooltips = enabled
			local tooltipsModule = MTH and MTH.GetModule and MTH:GetModule("tooltips")
			if tooltipsModule and tooltipsModule.SetAmmoVendorTooltipsEnabled then
				tooltipsModule:SetAmmoVendorTooltipsEnabled(enabled)
			end
		end,
	})
	tooltipsBox:Note("MetaHuntGeneralTooltipsVendorHelp", "When mouseover on a vendor, its tooltip will tell if it sells Arrows and/or Bullets.")

	tooltipsBox:Checkbox("MetaHuntGeneralTooltipsFoodToggle", foodLabel, {
		checked = tooltipsStore.foodItemTooltips and true or false,
		onClick = function()
			local enabled = this:GetChecked() == 1
			tooltipsStore.foodItemTooltips = enabled
			local tooltipsModule = MTH and MTH.GetModule and MTH:GetModule("tooltips")
			if tooltipsModule and tooltipsModule.SetFoodItemTooltipsEnabled then
				tooltipsModule:SetFoodItemTooltipsEnabled(enabled)
			end
		end,
	})
	tooltipsBox:Note("MetaHuntGeneralTooltipsFoodHelp", foodHelp)

	-- ===== RIGHT: Bag Ammo Labels =====
	local bagsBox = panel:Box("right", "MetaHuntGeneralBagsBox", "Bag Ammo Labels")
	bagsBox:Checkbox("MetaHuntGeneralBagLabelsToggle", "Add text to ammunitions in bags", {
		checked = MTH_BagAmmoLabels_GetEnabled and MTH_BagAmmoLabels_GetEnabled() or false,
		onClick = function()
			if MTH_BagAmmoLabels_SetEnabled then MTH_BagAmmoLabels_SetEnabled(this:GetChecked() == 1) end
		end,
	})
	bagsBox:Checkbox("MetaHuntGeneralBankLabelsToggle", "Add text to ammunitions in bank", {
		checked = MTH_BankAmmoLabels_GetEnabled and MTH_BankAmmoLabels_GetEnabled() or false,
		onClick = function()
			if MTH_BankAmmoLabels_SetEnabled then MTH_BankAmmoLabels_SetEnabled(this:GetChecked() == 1) end
		end,
	})
	bagsBox:Checkbox("MetaHuntGeneralBagDmgToggle", "Show ammo damage (heat-coloured)", {
		checked = MTH_BagAmmoDamage_GetEnabled and MTH_BagAmmoDamage_GetEnabled() or false,
		onClick = function()
			if MTH_BagAmmoDamage_SetEnabled then MTH_BagAmmoDamage_SetEnabled(this:GetChecked() == 1) end
		end,
	})
	bagsBox:Note("MetaHuntGeneralBagDmgHelp", "Damage is heat-coloured from red (7.5) to green (20.5).")

	-- ===== RIGHT: Pet Auto-Teach =====
	local petTeachBox = panel:Box("right", "MetaHuntGeneralPetTeachBox", "Pet Auto-Teach")
	local growlEnabled = (type(MTH_Growl_IsEnabled) == "function" and MTH_Growl_IsEnabled()) or false
	petTeachBox:Checkbox("MetaHuntGeneralPetTeachGrowlToggle", "Activate Auto-Teach of Growl (Max rank)", {
		checked = growlEnabled,
		onClick = function()
			if type(MTH_Growl_SetEnabled) == "function" then
				MTH_Growl_SetEnabled(this:GetChecked() == 1)
			end
		end,
	})
	petTeachBox:Note("MetaHuntGeneralPetTeachGrowlHelp", "When you tame a beast, offers to teach it the best Growl rank for its level.")

	panel:Finish()
end
