-- Core: Assignment macro. Depends on spell name/texture from AssignmentOptions.
function LA.SetupAssignmentMacro(CurseAssignment)
	local macroIndex = GetMacroIndexByName(LA.MacroName)
	if (macroIndex == 0) then
		macroIndex = CreateMacro(LA.MacroName, 1, nil, nil, true)
		if LA.DebugMode then
			LA.print("Lock Assignment macro did not exist, creating a new one with ID" .. macroIndex)
		end
	end
	local curseName = LA.GetSpellNameFromDropDownList(CurseAssignment)
	if (curseName == nil) then
		if LA.DebugMode then
			LA.print("No update applied because no curse selected")
		end
	else
		if LA.DebugMode then
			LA.print("Updating macro " .. macroIndex .. " to the new assigment " .. curseName)
		end
		EditMacro(macroIndex, LA.MacroName, LA.GetSpellTextureFromDropDownList(CurseAssignment), LA.BuildMacroText(curseName), 1, 1)
		if LA.DebugMode then
			LA.print("Macro updated")
		end
	end
end

function LA.BuildMacroText(curseName)
	return "/run CastSpellByName(\"" .. curseName .. "\");"
end
