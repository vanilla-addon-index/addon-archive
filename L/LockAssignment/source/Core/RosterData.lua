-- Core: Roster and assignment list (WarlockRow). No frame references.
---@type WarlockRow[]
LA.LockAssignmentsData = LA.LockAssignmentsData or {}

function LA.BuildRosterFromRaid()
	local raidInfo = {}
	for i = 1, 40 do
		local name, rank, _, _, _, fileName, _, _, _, _, _ = GetRaidRosterInfo(i)
		if not (name == nil) then
			if fileName == "WARLOCK" then
				if name == UnitName("player") then
					-- myRaidRank available as rank if needed
				end
				if LA.DebugMode then
					LA.print(name .. "-" .. fileName)
				end
				table.insert(raidInfo, LA.WarlockRow.create(name, "None", "None", i))
			end
		end
	end
	if LA.GetTableLength(raidInfo) == 0 then
		LA.RaidMode = false
		return LA.BuildSoloRoster()
	else
		LA.RaidMode = true
	end
	return raidInfo
end

function LA.BuildSoloRoster()
	local _, englishClass, _ = UnitClass("player")
	local soloData = {}
	if englishClass == "WARLOCK" then
		table.insert(soloData, LA.WarlockRow.create(UnitName("player"), "None", "None", nil))
	end
	return soloData
end

function LA.IsWarlockInList(warlockName, rows)
	for _, row in pairs(rows) do
		if row.warlock.Name == warlockName then
			return true
		end
	end
	return false
end

function LA.SyncRosterWithAssignments(assignmentsTable)
	local newcomers = LA.BuildRosterFromRaid()
	for _, row in pairs(newcomers) do
		if not LA.IsWarlockInList(row.warlock.Name, assignmentsTable) then
			if LA.DebugMode then
				LA.print("Newcomer detected")
			end
			table.insert(assignmentsTable, LA.WarlockRow.create(row.warlock.Name, "None", "None", row.warlock.RaidIndex))
		end
	end
	for _, row in pairs(assignmentsTable) do
		if not LA.IsWarlockInList(row.warlock.Name, newcomers) then
			if LA.DebugMode then
				LA.print("Deserter detected")
			end
			local p = LA.FindAssignmentIndexByName(LA.LockAssignmentsData, row.warlock.Name)
			if p ~= nil then
				table.remove(LA.LockAssignmentsData, p)
			end
		else
			-- Update RaidIndex for existing members (raid order may have changed)
			for _, newRow in pairs(newcomers) do
				if newRow.warlock.Name == row.warlock.Name then
					row.warlock.RaidIndex = newRow.warlock.RaidIndex
					break
				end
			end
		end
	end
	return assignmentsTable
end

--- Merge incoming flat assignment data (e.g. from comms) into our roster rows.
---@param flatAssignments table[] flat tables with Name, CurseAssignment, BanishAssignment, SSAssignment
function LA.ApplyIncomingAssignments(flatAssignments)
	for _, v in pairs(flatAssignments) do
		local row = LA.FindAssignmentByName(v.Name)
		if row ~= nil then
			row.assignment.SSAssignment = v.SSAssignment or LA.SoulstoneTarget.none()
			row.assignment.CurseAssignment = v.CurseAssignment
			row.assignment.BanishAssignment = v.BanishAssignment
		end
	end
end

function LA.ClearAcknowledgements(rows)
	for _, row in pairs(rows) do
		row.assignment.AcceptedAssignments = "nil"
	end
end

---@return WarlockRow|nil
function LA.GetMyAssignment()
	for _, row in pairs(LA.LockAssignmentsData) do
		if row.warlock.Name == UnitName("player") then
			return row
		end
	end
	return nil
end

---@param assignmentDataTable WarlockRow[]
---@return WarlockRow|nil
function LA.FindMyAssignmentInTable(assignmentDataTable)
	for _, row in pairs(assignmentDataTable) do
		if row.warlock.Name == UnitName("player") then
			return row
		end
	end
	return nil
end

---@param name string
---@return WarlockRow|nil
function LA.FindAssignmentByName(name)
	for _, row in pairs(LA.LockAssignmentsData) do
		if row.warlock.Name == name then
			return row
		end
	end
	return nil
end

---@param tbl WarlockRow[]
---@param name string
---@return number|nil
function LA.FindAssignmentIndexByName(tbl, name)
	for key, row in pairs(tbl) do
		if row.warlock.Name == name then
			if LA.DebugMode then
				LA.print(row.warlock.Name .. " is in position " .. tostring(key))
			end
			return key
		end
	end
	if LA.DebugMode then
		LA.print(name .. " is not in the list.")
	end
	return nil
end
