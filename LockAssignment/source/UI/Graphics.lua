-- UI/Graphics.lua: SetAssignmentGraphic, UpdateCurse/UpdateBanish/UpdateDropDownSideGraphic, Get*FromDropDownList.
-- Depends: Core/AssignmentOptions (GetSpellTextureFromDropDownList, GetAssetLocationFromRaidMarker, LA.CurseOptions, LA.BanishMarkers).

-- Unified helper: set or clear a graphic on a frame. graphicFrame has textureKey (e.g. "CurseTexture" or "BanishTexture"), texturePath is nil to clear.
function LA.SetAssignmentGraphic(graphicFrame, textureKey, texturePath)
	if not graphicFrame then return end
	local tex = graphicFrame[textureKey]
	if not tex then
		tex = graphicFrame:CreateTexture(nil, "OVERLAY")
		tex:SetAllPoints()
		graphicFrame[textureKey] = tex
	end
	if texturePath then
		tex:SetTexture(texturePath)
	else
		tex:SetTexture(0, 0, 0, 0)
	end
end

-- Parent Frame is the drop down control. CurseListValue is the plain text version of the selected curse option.
function LA.UpdateCurseGraphic(ParentFrame, CurseListValue)
	local path = (CurseListValue ~= nil) and LA.GetSpellTextureFromDropDownList(CurseListValue) or nil
	LA.SetAssignmentGraphic(ParentFrame.CurseGraphicFrame, "CurseTexture", path)
end

-- Parent Frame is the drop down control.
function LA.UpdateBanishGraphic(ParentFrame, BanishListValue)
	local path = (BanishListValue ~= nil) and LA.GetAssetLocationFromRaidMarker(BanishListValue) or nil
	LA.SetAssignmentGraphic(ParentFrame.BanishGraphicFrame, "BanishTexture", path)
end

-- Generic function that will get called by any drop down to update the graphic that is displayed next to it.
-- This event is what is fired when a box is changed manually.
-- This event does not fire when the dropdown selection is changed programmatically.
-- This acts as a router to determine which menu was changed, if the menu is not of a certain "DropDownType" then this function does nothing.
function LA.UpdateDropDownSideGraphic(DropDownMenu, SelectedValue, DropDownType)
	if DropDownType == "CURSE" then
		LA.UpdateCurseGraphic(DropDownMenu, SelectedValue)
	elseif DropDownType == "BANISH" then
		LA.UpdateBanishGraphic(DropDownMenu, SelectedValue)
	end
end

-- Gets the selected value of the cures from the drop down list.
-- Use GetValueFromDropDownList instead.
function LA.GetCurseValueFromDropDownList(DropDownMenu)
	local selectedValue = UIDropDownMenu_GetSelectedID(DropDownMenu)
	return LA.CurseOptions[selectedValue]
end

-- Gets the selected value of the banish target from the drop down list.
-- This is arguably an easier way than referencing the getvalue from dropdown list function.
function LA.GetBanishValueFromDropDownList(DropDownMenu)
	local selectedValue = UIDropDownMenu_GetSelectedID(DropDownMenu)
	return LA.BanishMarkers[selectedValue]
end

function LA.GetSSValueFromDropDownList(DropDownMenu)
	return UIDropDownMenu_GetSelectedValue(DropDownMenu)
end

-- Returns the value of the selected option in a drop down menu.
-- This exists because the built in UIDropDownMenu_GetSelectedValue appears to be broken.
-- Of course, it is probable that I am using the drop down menu incorrectly in this case.
function LA.GetValueFromDropDownList(DropDownMenu, OptionList, DropDownType)
	local selectedValue = UIDropDownMenu_GetSelectedID(DropDownMenu)
	if DropDownType == "SSAssignments" then
		if OptionList[selectedValue] == nil then
			return "None"
		else
			return OptionList[selectedValue].Name
		end
	else
		return OptionList[selectedValue]
	end
end
