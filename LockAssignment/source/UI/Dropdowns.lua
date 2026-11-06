-- UI/Dropdowns.lua: CreateDropDownMenu, UpdateDropDownMenuWithNewOptions, CreateSoulstoneDropDownMenu, BuildClassMap, UpdateSoulstoneDropDownMenuWithNewOptions.
-- Depends: UI/Graphics (LA.UpdateDropDownSideGraphic, LA.GetValueFromDropDownList, LA.GetSSValueFromDropDownList), Core (LA.GetColoredName).

local dropdowncount = 0

-- Creates and adds a dropdown menu with the passed in option list.
-- Adding a dropdown type further allows for the sidebar graphic to update as well, but is not required.
function LA.CreateDropDownMenu(ParentFrame, OptionList, DropDownType)
	dropdowncount = dropdowncount + 1
	local NewDropDownMenu = CreateFrame("Frame", "NL_DropDown0"..dropdowncount, ParentFrame, "UIDropDownMenuTemplate")

	local function OnClick(_)
		UIDropDownMenu_SetSelectedID(NewDropDownMenu, this:GetID())

		local selection = LA.GetValueFromDropDownList(NewDropDownMenu, OptionList, DropDownType)
		if LA.DebugMode then
			LA.print("User changed selection to " .. selection)
		end
		LA.UpdateDropDownSideGraphic(NewDropDownMenu, selection, DropDownType)
	end

	local function initialize()
		local info = {}
		for _,v in pairs(OptionList) do
			info = {}
			if DropDownType == "SSAssignments" then
				info.text = v.Namea

			else
				info.text = v
			end
			info.func = OnClick
			UIDropDownMenu_AddButton(info)
		end
	end

	UIDropDownMenu_Initialize(NewDropDownMenu, initialize)
	UIDropDownMenu_SetWidth(100, NewDropDownMenu);
	UIDropDownMenu_SetButtonWidth(124, NewDropDownMenu)
	UIDropDownMenu_SetSelectedID(NewDropDownMenu, 1)
	UIDropDownMenu_JustifyText("LEFT", NewDropDownMenu)

	return NewDropDownMenu
end

function LA.UpdateDropDownMenuWithNewOptions(DropDownMenu, OptionList, DropDownType)
	local function OnClick(_)
		UIDropDownMenu_SetSelectedID(DropDownMenu, this:GetID())

		local selection = LA.GetValueFromDropDownList(DropDownMenu, OptionList, DropDownType)
		if LA.DebugMode then
			LA.print("User changed selection to " .. selection)
		end
		LA.UpdateDropDownSideGraphic(DropDownMenu, selection, DropDownType)
	end

	local function initialize()
		local info = {}
		for _,v in pairs(OptionList) do
			info = {}

			if DropDownType == "SSAssignments" then
				if v.Color ~= nil then
					info.text = "|c"..v.Color..v.Name
				else
					info.text = v.Name
				end
			else
				info.text = v
			end

			info.func = OnClick
			UIDropDownMenu_AddButton(info)
		end
	end

	UIDropDownMenu_Initialize(DropDownMenu, initialize)
	UIDropDownMenu_SetWidth(100, DropDownMenu);
	UIDropDownMenu_SetButtonWidth(124, DropDownMenu)
	UIDropDownMenu_SetSelectedID(DropDownMenu, 1)
	UIDropDownMenu_JustifyText("LEFT", DropDownMenu)
end

function LA.CreateSoulstoneDropDownMenu(ParentFrame, OptionList, DropDownType)
	dropdowncount = dropdowncount + 1
	local NewDropDownMenu = CreateFrame("Frame", "NL_DropDown0"..dropdowncount, ParentFrame, "UIDropDownMenuTemplate")

	local function OnClick(_)
		UIDropDownMenu_SetSelectedID(NewDropDownMenu, this:GetID())
		UIDropDownMenu_SetSelectedValue(NewDropDownMenu, this.value)

		local selection = LA.GetColoredName(LA.GetSSValueFromDropDownList(NewDropDownMenu))
		if LA.DebugMode then
			LA.print("User changed selection to " .. selection)
		end
		CloseDropDownMenus()
	end

	local classMap = LA.BuildClassMap(OptionList)

	function initialize(level)
		level = level or 1;
		if (level == 1) then
			for key, _ in classMap do
				local info = {};
				info.hasArrow = true;
				info.notCheckable = true;
				info.text = key;
				info.value = {
					["Level1_Key"] = key,
				};
				UIDropDownMenu_AddButton(info, level);
			end
		end

		if (level == 2) then
			local Level1_Key = UIDROPDOWNMENU_MENU_VALUE["Level1_Key"];
			local subarray = classMap[Level1_Key];
			for _, subsubarray in subarray do
				local info = {};
				info.hasArrow = false;
				info.notCheckable = false;
				info.text = LA.GetColoredName(subsubarray);
				info.func = OnClick
				info.value = subsubarray;
				UIDropDownMenu_AddButton(info, level);
			end
		end
	end

	UIDropDownMenu_Initialize(NewDropDownMenu, initialize)
	UIDropDownMenu_SetWidth(100, NewDropDownMenu);
	UIDropDownMenu_SetButtonWidth(100, NewDropDownMenu)
	UIDropDownMenu_JustifyText("LEFT", NewDropDownMenu)

	return NewDropDownMenu
end

function LA.BuildClassMap(array)
	local result = {};
	for _, v in pairs(array) do
		if not result[v.Class] then
			result[v.Class] = {};
		end

		local player = {}
		if v.Color ~= nil then
			player.Name = v.Name
			player.Color = v.Color
		else
			player.Name = v.Name
		end

		table.insert(result[v.Class], player);

	end

	return result;
end

function LA.UpdateSoulstoneDropDownMenuWithNewOptions(DropDownMenu, OptionList, Warlock)
	local function OnClick(_)
		UIDropDownMenu_SetSelectedID(DropDownMenu, this:GetID())
		UIDropDownMenu_SetSelectedValue(DropDownMenu, this.value)

		local selection = LA.GetColoredName(LA.GetSSValueFromDropDownList(DropDownMenu))
		if LA.DebugMode then
			LA.print("User changed selection to " .. selection)
		end
		CloseDropDownMenus()
	end

	local classMap = LA.BuildClassMap(OptionList)

	function initialize(level)
		level = level or 1;
		if (level == 1) then
			for key, _ in classMap do
				local info = {};
				info.hasArrow = true;
				info.notCheckable = false;
				info.text = key;
				info.checked = false
				info.value = {
					["Level1_Key"] = key,
				};
				UIDropDownMenu_AddButton(info, level);
			end
		end

		if (level == 2) then
			local Level1_Key = UIDROPDOWNMENU_MENU_VALUE["Level1_Key"];
			local subarray = classMap[Level1_Key];
			for _, subsubarray in subarray do
				local info = {};
				info.hasArrow = false;
				info.notCheckable = false;
				info.text = LA.GetColoredName(subsubarray);
				info.func = OnClick
				info.value = subsubarray;
				UIDropDownMenu_AddButton(info, level);
			end
		end

		UIDropDownMenu_SetSelectedValue(DropDownMenu, Warlock.SSAssignment)

	end

	UIDropDownMenu_Initialize(DropDownMenu, initialize)
	UIDropDownMenu_SetWidth(100, DropDownMenu);
	UIDropDownMenu_SetButtonWidth(100, DropDownMenu)
	UIDropDownMenu_JustifyText("LEFT", DropDownMenu)
end
