-- Core: Build announcement lines (no SendChatMessage). Comms/Binding sends them.
---@param assignmentsTable WarlockRow[]
---@param announceOption string
---@return AnnouncementLine[]
function LA.BuildAnnouncementLines(assignmentsTable, announceOption)
	local lines = {}
	for _, row in pairs(assignmentsTable) do
		local name = row.warlock.Name
		local a = row.assignment
		if a.CurseAssignment ~= "None" then
			local message = name .. ": " .. "Curse -> " .. a.CurseAssignment .. " "
			table.insert(lines, LA.AnnouncementLine.create(message, name))
		end
		if a.BanishAssignment ~= "None" then
			local message = name .. ": " .. "Banish -> {" .. a.BanishAssignment .. "} "
			table.insert(lines, LA.AnnouncementLine.create(message, name))
		end
		if a.SSAssignment and a.SSAssignment.Name ~= "None" then
			local message = name .. ": " .. "SS -> " .. LA.GetColoredName(a.SSAssignment) .. " "
			table.insert(lines, LA.AnnouncementLine.create(message, name))
		end
	end
	return lines
end
