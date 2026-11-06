-- Model: Warlock assignment state (curse, banish, SS, cooldowns, acks, etc.). References warlock by name.
---@class WarlockAssignment
---@field warlockName string
---@field CurseAssignment string
---@field BanishAssignment string
---@field SSAssignment SoulstoneTarget
---@field SSCooldown number|nil
---@field AcceptedAssignments string
---@field AssignmentFrameLocation string
---@field SSonCD string
---@field LocalTime number
---@field MyTime number

LA = LA or {}
LA.WarlockAssignment = LA.WarlockAssignment or {}

---@param warlockName string
---@param curse string
---@param banish string
---@param raidIndex number|nil
---@return WarlockAssignment
function LA.WarlockAssignment.create(warlockName, curse, banish, raidIndex)
	local emptySS = LA.EmptySSTarget or LA.SoulstoneTarget.none()
	return {
		warlockName = warlockName,
		CurseAssignment = curse,
		BanishAssignment = banish,
		SSAssignment = emptySS,
		SSCooldown = nil,
		AcceptedAssignments = "nil",
		AssignmentFrameLocation = "",
		SSonCD = "unknown",
		LocalTime = 0,
		MyTime = 0,
	}
end
