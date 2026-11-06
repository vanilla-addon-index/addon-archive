-- Model: Composite row (Warlock + WarlockAssignment) for the assignment list. One row per warlock.
---@class WarlockRow
---@field warlock Warlock
---@field assignment WarlockAssignment

LA = LA or {}
LA.WarlockRow = LA.WarlockRow or {}

---@param name string
---@param curse string
---@param banish string
---@param raidIndex number|nil
---@return WarlockRow
function LA.WarlockRow.create(name, curse, banish, raidIndex)
	local warlock = LA.Warlock.create(name, raidIndex)
	local assignment = LA.WarlockAssignment.create(name, curse, banish, raidIndex)
	return {
		warlock = warlock,
		assignment = assignment,
	}
end

--- Flatten a WarlockRow to a table compatible with existing comm serialization (wire format).
---@param row WarlockRow
---@return table
function LA.WarlockRow.toFlat(row)
	return {
		Name = row.warlock.Name,
		RaidIndex = row.warlock.RaidIndex,
		AddonVersion = row.warlock.AddonVersion,
		CurseAssignment = row.assignment.CurseAssignment,
		BanishAssignment = row.assignment.BanishAssignment,
		SSAssignment = row.assignment.SSAssignment,
		SSCooldown = row.assignment.SSCooldown,
		AcceptedAssignments = row.assignment.AcceptedAssignments,
		AssignmentFrameLocation = row.assignment.AssignmentFrameLocation,
		SSonCD = row.assignment.SSonCD,
		LocalTime = row.assignment.LocalTime,
		MyTime = row.assignment.MyTime,
	}
end

--- Build a WarlockRow from a flat table (e.g. received over comms).
---@param flat table
---@return WarlockRow
function LA.WarlockRow.fromFlat(flat)
	local warlock = {
		Name = flat.Name,
		RaidIndex = flat.RaidIndex,
		AddonVersion = flat.AddonVersion or 0,
	}
	local assignment = {
		warlockName = flat.Name,
		CurseAssignment = flat.CurseAssignment or "None",
		BanishAssignment = flat.BanishAssignment or "None",
		SSAssignment = flat.SSAssignment or LA.SoulstoneTarget.none(),
		SSCooldown = flat.SSCooldown,
		AcceptedAssignments = flat.AcceptedAssignments or "nil",
		AssignmentFrameLocation = flat.AssignmentFrameLocation or "",
		SSonCD = flat.SSonCD or "unknown",
		LocalTime = flat.LocalTime or 0,
		MyTime = flat.MyTime or 0,
	}
	return { warlock = warlock, assignment = assignment }
end
