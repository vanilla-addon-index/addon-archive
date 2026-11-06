-- Bootstrap: global LA table, addon ref, constants, state. Core/Utils/UI define the rest.
LA = {}
LA.RaidMode = true
LA.DebugMode = false
LA.Version = 15
LA.UpdateFrame = CreateFrame("Frame", nil, UIParent)
LA.LockAssignmentWarlockFrameWidth = 500
LA.LockAssignmentWarlockFrameHeight = 128
LA.LockAssignmentFrame_HasInitialized = false
LockAssignmentFrame_HasInitialized = false
LA.LockAssignmentData_HasInitialized = false
LA.LockAssignmentData_Timestamp = 0.0
LA.LockAssignmentClock_UpdateInterval = 1.0
LA.LockAssignmentSSCD_UpdateInterval = 5.0
LA.LockAssignmentSSCD_BroadcastInterval = 60.0
LA.HaveSSAssignment = false
if LockAssignment == nil then
	LockAssignment = LibStub("AceAddon-3.0"):NewAddon("LockAssignment", "AceComm-3.0")
end
LA.LockAssignmentAssignCheckFrame = {}
LA.IsMyAddonOutOfDate = false
LA.MacroName = "CurseAssignment"
LockAssignmentData_Timestamp = 0.0
LockAssignmentData_HasInitialized = false

function LA.print(msg)
	if msg == nil then return end
	DEFAULT_CHAT_FRAME:AddMessage(tostring(msg))
end
