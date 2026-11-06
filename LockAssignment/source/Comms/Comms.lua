-- Comms: channels, message serialization, OnCommReceived (data only + callback), send helpers.
LA.CommModeWhisper = "WHISPER"
LA.CommTarget = UnitName("player")
LA.CommModeRaid = "RAID"

LA.CommAction = {}
LA.CommAction.SSonCD = "SSonCD"
LA.CommAction.BroadcastTable = "DataRefresh"
LA.CommAction.RequestAssignments = "GetAssignmentData"
LA.CommAction.AssignmentResponse = "AssignmentResponse"
LA.CommAction.AssignmentReset = "AssignmentReset"

LA.OnAssignmentsOrVersionChanged = nil

function LA.SerializeCommMessage(action, data, dataAge)
	local msg = LA.CommMessage.create(action, data, dataAge)
	return LA.CommMessage.serialize(msg)
end

function LA.RegisterForComms()
	LockAssignment:RegisterComm("LAComms")
end

function LockAssignment:OnCommReceived(prefix, message, distribution, sender)
	if LA.DebugMode then
		LA.print("Message Was Recieved by the Router")
	end
	message = table.deserialize(message)
	local row = LA.FindAssignmentByName(message.author)
	if row ~= nil then
		row.warlock.AddonVersion = message.addonVersion
	end
	if message.addonVersion > LA.Version then
		LA.IsMyAddonOutOfDate = true
		if LA.OnAssignmentsOrVersionChanged then
			LA.OnAssignmentsOrVersionChanged("VersionOutOfDate")
		end
	end
	if message.action == LA.CommAction.SSonCD and message.author ~= LA.CommTarget then
		if LA.DebugMode then
			LA.print("SS on CD: " .. tostring(message.data.Name) .. " " .. tostring(message.data.SSCooldown) .. " " .. tostring(message.data.SSonCD) .. " " .. tostring(message.dataAge))
		end
		local row = LA.FindAssignmentByName(message.author)
		if row ~= nil then
			if LA.DebugMode then
				LA.print("Updating SS data for " .. tostring(message.author))
			end
			row.assignment.LocalTime = message.dataAge
			row.assignment.MyTime = GetTime()
			row.assignment.SSonCD = "true"
			row.assignment.SSCooldown = message.data.SSCooldown
		end
	elseif message.action == LA.CommAction.BroadcastTable then
		local myRow = LA.GetMyAssignment()
		if myRow ~= nil then
			for _, assignmentData in pairs(message.data) do
				if assignmentData.Name == UnitName("player") then
					if LA.OnAssignmentsOrVersionChanged then
						LA.OnAssignmentsOrVersionChanged("MyAssignmentReceived", assignmentData)
					end
					break
				end
			end
		end
		if LA.RaidMode then
			if LA.DebugMode then
				LA.print("Received message from " .. tostring(message.author))
			end
			if message.author == LA.CommTarget then
				return
			end
		end
		if LA.DebugMode then
			LA.print("Recieved a broadcast message from " .. tostring(message.author))
		end
		local shouldMerge = LA.GetTableLength(LA.LockAssignmentsData) == 0 or LA.HasIncomingAssignmentChanges(message.data)
		if shouldMerge then
			LA.ApplyIncomingAssignments(message.data)
			LA.LockAssignmentsData = LA.SyncRosterWithAssignments(LA.LockAssignmentsData)
			if LA.OnAssignmentsOrVersionChanged then
				LA.OnAssignmentsOrVersionChanged("BroadcastMerged")
			end
		end
	elseif message.action == LA.CommAction.RequestAssignments then
		if LA.RaidMode then
			if LA.DebugMode then
				LA.print("Received Assignment Request message from " .. tostring(message.author))
			end
			local myRow = LA.GetMyAssignment()
			if myRow ~= nil then
				LA.BroadcastSSCooldown(myRow)
			end
			if message.author == LA.CommTarget then
				if LA.DebugMode then
					LA.print("Message was from self, doing nothing.")
				end
				return
			end
		end
		if LA.DebugMode then
			LA.print("Assignment request recieved, sending out assignments.")
		end
		LA.BroadcastTable(LA.LockAssignmentsData)
	elseif message.action == LA.CommAction.AssignmentResponse then
		if LA.DebugMode then
			LA.print("Recieved an Ack message from " .. tostring(message.author))
		end
		local row = LA.FindAssignmentByName(message.author)
		if row ~= nil then
			row.assignment.AcceptedAssignments = message.data.acknowledged
			if LA.OnAssignmentsOrVersionChanged then
				LA.OnAssignmentsOrVersionChanged("AckReceived", row)
			end
		end
	elseif message.action == LA.CommAction.AssignmentReset then
		if LA.DebugMode then
			LA.print("Recieved assignment reset from " .. tostring(message.author))
		end
		LA.ClearAcknowledgements(LA.LockAssignmentsData)
		if LA.OnAssignmentsOrVersionChanged then
			LA.OnAssignmentsOrVersionChanged("AssignmentReset")
		end
	else
		if LA.DebugMode then
			LA.print("The following message was recieved: " .. tostring(sender) .. " " .. tostring(prefix) .. " " .. tostring(message))
		end
	end
end

function LA.BroadcastTable(AssignmentsTable)
	if LA.IsMyAddonOutOfDate then
		return
	end
	if LA.DebugMode then
		LA.print("Sending out the assignment table")
	end
	local flatList = {}
	for _, row in pairs(AssignmentsTable) do
		table.insert(flatList, LA.WarlockRow.toFlat(row))
	end
	local serializedTable = LA.SerializeCommMessage(LA.CommAction.BroadcastTable, flatList, LockAssignmentData_Timestamp)
	if LA.RaidMode then
		LockAssignment:SendCommMessage("LAComms", serializedTable, LA.CommModeRaid)
	else
		LockAssignment:SendCommMessage("LAComms", serializedTable, LA.CommModeRaid, LA.CommTarget)
	end
end

function LA.BroadcastSSCooldown(myRow)
	LA.ForceUpdateSSCD()
	local flat = LA.WarlockRow.toFlat(myRow)
	local serializedTable = LA.SerializeCommMessage(LA.CommAction.SSonCD, flat, GetTime())
	if LA.RaidMode then
		LockAssignment:SendCommMessage("LAComms", serializedTable, LA.CommModeRaid)
	else
		LockAssignment:SendCommMessage("LAComms", serializedTable, LA.CommModeRaid, LA.CommTarget)
	end
end

function LA.RequestAssignments()
	if LA.DebugMode then
		LA.print("Requesting Updated Assignment Table")
	end
	local message = LA.SerializeCommMessage(LA.CommAction.RequestAssignments, {}, GetTime())
	if LA.RaidMode then
		LockAssignment:SendCommMessage("LAComms", message, LA.CommModeRaid)
	else
		LockAssignment:SendCommMessage("LAComms", message, LA.CommModeRaid, LA.CommTarget)
	end
end

function LA.SendAssignmentAcknowledgement(answer)
	if LA.DebugMode then
		LA.print("Sending assignment acknowledgement: " .. tostring(answer))
	end
	if answer == "true" then
		LA.UpdatePersonalMonitorFrame()
	end
	local message = LA.SerializeCommMessage(LA.CommAction.AssignmentResponse, { acknowledged = answer }, GetTime())
	if LA.RaidMode then
		LockAssignment:SendCommMessage("LAComms", message, LA.CommModeRaid)
	else
		LockAssignment:SendCommMessage("LAComms", message, LA.CommModeRaid, LA.CommTarget)
	end
end

function LA.SendAssignmentReset()
	if LA.DebugMode then
		LA.print("Sending assignment reset command")
	end
	local message = LA.SerializeCommMessage(LA.CommAction.AssignmentReset, {}, GetTime())
	if LA.RaidMode then
		LockAssignment:SendCommMessage("LAComms", message, LA.CommModeRaid)
	else
		LockAssignment:SendCommMessage("LAComms", message, LA.CommModeRaid, LA.CommTarget)
	end
end

function LA.CheckInstallVersion()
end
