-- Core: Dirty checks and commit logic (data only). Binding layer reads UI and passes current table.
---@param flatIncoming table[] flat assignment tables from comms
---@return boolean
function LA.HasIncomingAssignmentChanges(flatIncoming)
	for _, v in pairs(flatIncoming) do
		local row = LA.FindAssignmentByName(v.Name)
		if row then
			local a = row.assignment
			if a.CurseAssignment ~= v.CurseAssignment or
				a.BanishAssignment ~= v.BanishAssignment or
				a.SSAssignment ~= v.SSAssignment then
				return true
			end
		end
	end
	return false
end

---@param flatAssignment table flat table with CurseAssignment, BanishAssignment, SSAssignment
---@return boolean
function LA.HasMyAssignmentChanged(flatAssignment)
	local myRow = LA.GetMyAssignment()
	if not myRow then return true end
	local a = myRow.assignment
	local mySSName = (a.SSAssignment and a.SSAssignment.Name) or "None"
	local theirSSName = (flatAssignment.SSAssignment and flatAssignment.SSAssignment.Name) or "None"
	if a.CurseAssignment ~= flatAssignment.CurseAssignment or
		a.BanishAssignment ~= flatAssignment.BanishAssignment or
		mySSName ~= theirSSName then
		return true
	end
	return false
end

-- Commit currentTable (flat from UI) into assignmentsTable (rows). Caller passes currentTable from UI.
---@param assignmentsTable WarlockRow[]
---@param currentTable table[] flat tables keyed by index
---@return WarlockRow[]
function LA.ApplyAssignmentsFromTable(assignmentsTable, currentTable)
	for k, row in pairs(assignmentsTable) do
		local uiFlat = currentTable and currentTable[k]
		if uiFlat then
			row.assignment.CurseAssignment = uiFlat.CurseAssignment
			row.assignment.BanishAssignment = uiFlat.BanishAssignment
			row.assignment.SSAssignment = uiFlat.SSAssignment or LA.SoulstoneTarget.none()
			row.assignment.AcceptedAssignments = "nil"
		end
	end
	LockAssignmentData_Timestamp = GetTime()
	return assignmentsTable
end
