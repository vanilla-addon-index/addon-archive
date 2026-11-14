if not GearRack.enabled then return end

local _, ns = ...
local UI = ns.UI

--[[ TrinketOptions.lua : Options and sort window for GearRackTrinkets ]]

-- Tooltips, Shift-only lists and ready alerts are shared settings in Gear sets.
GearRackTrinkets.CheckOptInfo = {
{"KeepOpen","OFF","Keep list open","Keep the trinket list open."},
{"KeepDocked","ON","Keep list docked","Keep the trinket list beside the trinket buttons."},
{"Locked","OFF","Lock windows","Stop moving, resizing and rotating."},
{"SetColumns","OFF","Set list columns","Choose the trinkets per row. Off: automatic."},
{"ShowHotKeys","ON","Show key labels","Show worn trinkets' keys from Key Bindings."},
{"StopOnSwap","OFF","Stop queue on swap","A trinket you pick turns that slot's order off. Trinkets without a use always do."},
}

GearRackTrinkets.TooltipInfo = {
{"GearRackTrinkets_LockButton","Lock windows","Stop moving, resizing and rotating."},
{"GearRackTrinkets_Trinket0Check","Top trinket queue","Puts on the best ready trinket from the list. A trinket you pick pauses it (Keep manual choices). Tick, or Alt-click the trinket, to resume."},
{"GearRackTrinkets_Trinket1Check","Bottom trinket queue","Puts on the best ready trinket from the list. A trinket you pick pauses it (Keep manual choices). Tick, or Alt-click the trinket, to resume."},
{"GearRackTrinkets_SortPriority","High priority","Put on as soon as it is ready, even over a ready worn trinket. Off: only replaces a trinket on cooldown."},
{"GearRackTrinkets_SortDelay","Swap delay","Seconds to keep it on after use, such as the length of its buff."},
{"GearRackTrinkets_SortKeepEquipped","Pause queue","No automatic swaps while this trinket is worn."},
{"GearRackTrinkets_Profiles","Profiles","Save or load trinket orders."},
{"GearRackTrinkets_Delete","Delete","Remove from the list. Carried trinkets return at the bottom; keep them below the stop line."},
{"GearRackTrinkets_ProfilesDelete","Delete profile","Delete this profile."},
{"GearRackTrinkets_ProfilesLoad","Load profile","Load into the open slot. Double-click does the same."},
{"GearRackTrinkets_ProfilesSave","Save profile","Save the open slot's order. Either slot can load it."},
{"GearRackTrinkets_ProfileName","Profile name","Either slot can load it."},
}

function GearRackTrinkets.InitOptions()
	local item
	for i=1,#GearRackTrinkets.CheckOptInfo do
		item = _G["GearRackTrinkets_Opt"..GearRackTrinkets.CheckOptInfo[i][1].."Text"]
		item:SetText(GearRackTrinkets.CheckOptInfo[i][3])
		UI.Color(item,"text")
	end
	GearRackTrinkets.Tab_OnClick(1)
	GearRack.SetEscapable("GearRackTrinkets_OptFrame",true)
	GearRackTrinkets_Title:SetText("GearRack: Trinkets")

	GearRackTrinkets.QueueInit()
	GearRackTrinkets_OptColumnsSlider:SetValue(GearRackDB.trinketOptions.Columns)
	GearRackTrinkets.ReflectLock()
	GearRackTrinkets.ReflectKeyBindings()
end

function GearRackTrinkets.ToggleFrame(frame)
	if frame:IsVisible() then
		frame:Hide()
	else
		frame:Show()
	end
end

function GearRackTrinkets.OptFrame_OnShow()
	GearRackTrinkets.ValidateChecks()
	if GearRackTrinkets.CurrentlySorting then
		GearRackTrinkets.PopulateSort(GearRackTrinkets.CurrentlySorting)
	end
end

function GearRackTrinkets.ValidateChecks()
	local check,button
	for i=1,#GearRackTrinkets.CheckOptInfo do
		check = GearRackTrinkets.CheckOptInfo[i]
		button = _G["GearRackTrinkets_Opt"..check[1]]
		button:SetChecked(GearRackDB.trinketOptions[check[1]]=="ON")
	end
	GearRackTrinkets_OptColumnsSlider:SetAlpha((GearRackDB.trinketOptions.SetColumns=="ON") and 1 or .5)
	GearRackTrinkets_OptColumnsSlider:EnableMouse((GearRackDB.trinketOptions.SetColumns=="ON") and 1 or 0)
	GearRackTrinkets_OptColumnsSlider:SetValue(GearRackDB.trinketOptions.Columns)
end

function GearRackTrinkets.OptColumnsSlider_OnValueChanged()
	if GearRackDB.trinketOptions then
		GearRackDB.trinketOptions.Columns = this:GetValue()
		GearRackTrinkets_OptColumnsSliderText:SetText(GearRackDB.trinketOptions.Columns.." trinkets")
		if GearRackTrinkets_MenuFrame:IsVisible() then
			GearRackTrinkets.BuildMenu()
		end
	end
end

function GearRackTrinkets.CheckButton_OnClick()
	local _,_,var = string.find(this:GetName(),"GearRackTrinkets_Opt(.+)")
	if GearRackDB.trinketOptions[var] then
		GearRackDB.trinketOptions[var] = this:GetChecked() and "ON" or "OFF"
		PlaySound(this:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
		GearRackTrinkets.ValidateChecks()
	end

	if this==GearRackTrinkets_OptLocked then
		GearRackTrinkets.DockWindows()
		GearRackTrinkets.ReflectLock()
	elseif this==GearRackTrinkets_OptKeepOpen or this==GearRackTrinkets_OptSetColumns then
		if GearRackDB.trinketOptions.KeepOpen=="ON" then
			GearRackTrinkets.BuildMenu()
		end
	elseif this==GearRackTrinkets_OptKeepDocked then
		GearRackTrinkets.DockWindows()
	elseif this==GearRackTrinkets_OptShowHotKeys then
		GearRackTrinkets.ReflectKeyBindings()
	end
end

function GearRackTrinkets.ReflectLock()
	local c = GearRackDB.trinketOptions.Locked=="ON" and 0 or .5
	if c==0 then
		GearRackTrinkets_MainFrame:StopMovingOrSizing()
		GearRackTrinkets_MenuFrame:StopMovingOrSizing()
		GearRackTrinkets_OptFrame:StopMovingOrSizing()
		GearRackTrinkets.StopTimer("DockingMenu")
		GearRackTrinkets.StopScalingFrame(GearRackTrinkets.FrameToScale)
		GearRackTrinkets.ClearDocking()
	end
	GearRackTrinkets_MainFrame:SetBackdropColor(c,c,c,c)
	GearRackTrinkets_MainFrame:SetBackdropBorderColor(c,c,c,c*2)
	GearRackTrinkets_MenuFrame:SetBackdropColor(c,c,c,c)
	GearRackTrinkets_MenuFrame:SetBackdropBorderColor(c,c,c,c*2)
	GearRackTrinkets_MenuFrame:EnableMouse(c*2)
	GearRackTrinkets_OptLocked:SetChecked(1-c*2)
	local normalTexture = GearRackTrinkets_LockButton:GetNormalTexture()
	local pushedTexture = GearRackTrinkets_LockButton:GetPushedTexture()
	if c==0 then
		GearRackTrinkets_MainResizeButton:Hide()
		GearRackTrinkets_MenuResizeButton:Hide()
		normalTexture:SetTexCoord(.875,1,.125,.25)
		pushedTexture:SetTexCoord(.75,.875,.125,.25)
	else
		GearRackTrinkets_MainResizeButton:Show()
		GearRackTrinkets_MenuResizeButton:Show()
		normalTexture:SetTexCoord(.75,.875,.125,.25)
		pushedTexture:SetTexCoord(.875,1,.125,.25)
	end
end


--[[ Titlebar buttons ]]

function GearRackTrinkets.SmallButton_OnClick()
	PlaySound("igMainMenuOptionCheckBoxOn")
	if this==GearRackTrinkets_CloseButton then
		GearRack.CloseMenus()
	elseif this==GearRackTrinkets_LockButton then
		GearRackDB.trinketOptions.Locked = (GearRackDB.trinketOptions.Locked=="ON") and "OFF" or "ON"
		GearRackTrinkets.DockWindows()
		GearRackTrinkets.ReflectLock()
	end
end

--[[ Tabs ]]

function GearRackTrinkets.Tab_OnClick(override)
	PlaySound("GAMEGENERICBUTTONPRESS")
	local id = override or this:GetID()
	GearRackTrinkets.SelectedTab=id
	GearRackTrinkets_ProfilesFrame:Hide()
	for i=1,3 do
		ns.SelectPill(_G["GearRackTrinkets_Tab"..i],i==id)
	end
	if id==1 then
		GearRackTrinkets_SubOptFrame:Show()
		GearRackTrinkets_SubQueueFrame:Hide()
	else
		GearRackTrinkets_SubOptFrame:Hide()
		GearRackTrinkets_SubQueueFrame:Show()
		GearRackTrinkets.OpenSort(3-id)
	end
end
