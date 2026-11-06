-- Binding layer: data-to-UI (refresh frames from LA.LockAssignmentsData) and UI-to-data (read UI into model, commit, announce).
function LA.GetAssignmentFrameById(LockFrameID)
	for key, value in pairs(AssignmentFrame.scrollframe.content.WarlockFrames) do
		if value["LockFrameID"] == LockFrameID then
			return value
		end
	end
end

--- Refreshes the player's portrait texture (e.g. after raid roster update).
function LA.RefreshPersonalPortrait()
	local myRow = LA.GetMyAssignment()
	if not myRow then return end
	local frame = LA.GetAssignmentFrameById(myRow.assignment.AssignmentFrameLocation)
	if not frame or not frame.Portrait or not frame.Portrait.Texture then return end
	SetPortraitTexture(frame.Portrait.Texture, "player")
end

function LA.GetAssignmentFrameByName(WarlockName)
	for key, value in pairs(AssignmentFrame.scrollframe.content.WarlockFrames) do
		if value["WarlockName"] == WarlockName then
			return value
		end
	end
end

---@param row WarlockRow|nil
---@param AssignmentFrame table
function LA.RefreshAssignmentFrame(row, AssignmentFrame)
	if row == nil then
		AssignmentFrame:Hide()
		row = LA.WarlockRow.create("", "None", "None", 0)
	else
		AssignmentFrame:Show()
	end
	local w, a = row.warlock, row.assignment

	CloseDropDownMenus()
	AssignmentFrame.WarlockName = w.Name
	AssignmentFrame.NamePlate.TextFrame:SetText(w.Name)
	UIDropDownMenu_SetSelectedID(AssignmentFrame.CurseAssignmentMenu, LA.GetOptionIndex(LA.CurseOptions, a.CurseAssignment))
	LA.UpdateCurseGraphic(AssignmentFrame.CurseAssignmentMenu, LA.GetCurseValueFromDropDownList(AssignmentFrame.CurseAssignmentMenu))
	UIDropDownMenu_SetText(LA.GetCurseValueFromDropDownList(AssignmentFrame.CurseAssignmentMenu), AssignmentFrame.CurseAssignmentMenu)

	UIDropDownMenu_SetSelectedID(AssignmentFrame.BanishAssignmentMenu, LA.GetOptionIndex(LA.BanishMarkers, a.BanishAssignment))
	LA.UpdateBanishGraphic(AssignmentFrame.BanishAssignmentMenu, LA.GetValueFromDropDownList(AssignmentFrame.BanishAssignmentMenu, LA.BanishMarkers, ""))
	UIDropDownMenu_SetText(LA.GetValueFromDropDownList(AssignmentFrame.BanishAssignmentMenu, LA.BanishMarkers, ""), AssignmentFrame.BanishAssignmentMenu)

	LA.UpdateSoulstoneDropDownMenuWithNewOptions(AssignmentFrame.SSAssignmentMenu, LA.GetSSTargets(), row.assignment)

	local selecedSSTarget = LA.GetSSValueFromDropDownList(AssignmentFrame.SSAssignmentMenu)
	if selecedSSTarget ~= nil then
		UIDropDownMenu_SetText(LA.GetColoredName(selecedSSTarget), AssignmentFrame.SSAssignmentMenu)
	else
		UIDropDownMenu_SetText("None", AssignmentFrame.SSAssignmentMenu)
	end

	if w.Name == "" then
		AssignmentFrame.Portrait:Hide()
	else
		if AssignmentFrame.Portrait.Texture == nil then
			local PortraitGraphic = AssignmentFrame.Portrait:CreateTexture(nil, "OVERLAY")
			PortraitGraphic:SetAllPoints()
			if w.Name == UnitName("player") then
				SetPortraitTexture(PortraitGraphic, "player")
			elseif w.RaidIndex ~= nil then
				SetPortraitTexture(PortraitGraphic, string.format("raid%d", w.RaidIndex))
			else
				SetPortraitTexture(PortraitGraphic, "player")
			end
			AssignmentFrame.Portrait.Texture = PortraitGraphic
		else
			if w.Name == UnitName("player") then
				SetPortraitTexture(AssignmentFrame.Portrait.Texture, "player")
			elseif w.RaidIndex ~= nil then
				SetPortraitTexture(AssignmentFrame.Portrait.Texture, string.format("raid%d", w.RaidIndex))
			else
				SetPortraitTexture(AssignmentFrame.Portrait.Texture, "player")
			end
		end
		AssignmentFrame.Portrait:Show()
	end

	if a.AcceptedAssignments == "true" then
		AssignmentFrame.AssignmentAcknowledgement.value:SetText("Yes")
	elseif a.AcceptedAssignments == "false" then
		AssignmentFrame.AssignmentAcknowledgement.value:SetText("No")
	else
		AssignmentFrame.AssignmentAcknowledgement.value:SetText("Not Received")
	end

	if w.AddonVersion == 0 then
		AssignmentFrame.Warning.value:SetText("Warning: Addon not installed")
		AssignmentFrame.Warning:Show()
	elseif w.AddonVersion < LA.Version then
		AssignmentFrame.Warning.value:SetText("Warning: Addon out of date")
		AssignmentFrame.Warning:Show()
	else
		AssignmentFrame.Warning:Hide()
	end

	return AssignmentFrame.LockFrameID
end

function LA.UpdateAllWarlockFrames()
	if LA.DebugMode then
		LA.print("Updating all frames.")
	end
	LA.ClearAllAssignmentFrames()
	LA.ConsolidateFrameLocations()
	for key, value in pairs(LA.LockAssignmentsData) do
		LA.RefreshAssignmentFrame(value, LA.GetAssignmentFrameById(value.assignment.AssignmentFrameLocation))
	end
	if LA.DebugMode then
		LA.print("Frames updated successfully.")
	end
	AssignmentFrame.scrollbar:SetMinMaxValues(1, LA.GetMaxValueForScrollBar(LA.LockAssignmentsData))
end

function LA.ClearAllAssignmentFrames()
	for key, value in pairs(AssignmentFrame.scrollframe.content.WarlockFrames) do
		LA.RefreshAssignmentFrame(nil, value)
	end
end

function LA.ConsolidateFrameLocations()
	for key, value in pairs(LA.LockAssignmentsData) do
		value.assignment.AssignmentFrameLocation = AssignmentFrame.scrollframe.content.WarlockFrames[key].LockFrameID
	end
end

function LA.UpdateAllLocksAssignmentClock()
	for k, row in pairs(LA.LockAssignmentsData) do
		LA.UpdateLockClock(row)
	end
end

function LA.UpdateLockClock(row)
	local w, a = row.warlock, row.assignment
	if LA.DebugMode then
		LA.print(w.Name .. " on cooldown = " .. tostring(a.SSonCD))
	end

	local frame = LA.GetAssignmentFrameById(a.AssignmentFrameLocation)
	if not frame then return end

	if a.SSonCD == "true" and a.SSCooldown ~= nil then
		local CDLength = 30*60
		local timeShift = 0
		if a.MyTime ~= 0 then
			timeShift = a.MyTime - a.LocalTime
		end
		local absCD = a.SSCooldown + timeShift
		local secondsRemaining = math.floor(absCD + CDLength - GetTime())
		local result = SecondsToTime(secondsRemaining)
		if LA.DebugMode then
			LA.print(w.Name .. " my time: " .. tostring(a.MyTime) .. " localtime: " .. tostring(a.LocalTime) .. " timeShift: " .. tostring(timeShift) .. " LocalCD " .. tostring(a.SSCooldown) .. " Abs CD: " .. tostring(absCD) .. " Time Remaining: " .. tostring(secondsRemaining))
		end
		frame.SSCooldownTracker:SetText("CD " .. result)
		if secondsRemaining <= 0 or a.SSCooldown == 0 then
			a.SSonCD = "false"
			frame.SSCooldownTracker:SetText("Available")
		end
	elseif a.SSonCD == "unknown" then
		frame.SSCooldownTracker:SetText("Unknown")
	end
end

function LA.SetDefaultAssignments(rows)
	for k, row in pairs(rows) do
		local a = row.assignment
		if k <= 3 then
			a.CurseAssignment = LA.CurseOptions[k+1]
		else
			a.CurseAssignment = LA.CurseOptions[1]
		end
		if k <= 7 then
			a.BanishAssignment = LA.BanishMarkers[k+1]
		else
			a.BanishAssignment = LA.BanishMarkers[1]
		end
		if k <= 2 then
			a.SSAssignment = LA.GetSSTargets()[k]
		else
			local targets = LA.GetSSTargets()
			a.SSAssignment = targets[LA.GetTableLength(targets)]
		end
	end
	return rows
end

function LA.CheckSSCD(self)
	local startTime, _, _ = LA.GetItemCooldown("Major Soulstone")
	local myRow = LA.GetMyAssignment()
	if myRow ~= nil then
		if myRow.assignment.SSCooldown ~= startTime then
			LA.UpdateSSCD(myRow, startTime)
		end
		if startTime ~= nil and startTime > 0 and self.TimeSinceLastSSCDBroadcast > LA.LockAssignmentSSCD_BroadcastInterval then
			self.TimeSinceLastSSCDBroadcast = 0
			LA.BroadcastSSCooldown(myRow)
		end
	else
		if LA.DebugMode then
			LA.print("Something went horribly wrong.")
		end
	end
end

function LA.ReadAssignmentFromFrame(WarlockName)
	local frame = LA.GetAssignmentFrameByName(WarlockName)
	if not frame then return nil end
	local curse = LA.GetCurseValueFromDropDownList(frame.CurseAssignmentMenu)
	local banish = LA.GetValueFromDropDownList(frame.BanishAssignmentMenu, LA.BanishMarkers, "")
	local ssAssignment = LA.GetSSValueFromDropDownList(frame.SSAssignmentMenu)
	if ssAssignment == nil then
		ssAssignment = LA.EmptySSTarget
	end
	return {
		Name = frame.WarlockName,
		CurseAssignment = curse,
		BanishAssignment = banish,
		SSAssignment = ssAssignment,
		AssignmentFrameLocation = frame.LockFrameID,
	}
end

function LA.HasUnsavedAssignmentChanges(rows)
	if not LockAssignmentData_HasInitialized then
		LA.LockAssignmentsData = LA.InitLockAssignmentData()
		LockAssignmentData_HasInitialized = true
		return true
	end
	for k, row in pairs(rows) do
		local uiFlat = LA.ReadAssignmentFromFrame(row.warlock.Name)
		if uiFlat and (row.assignment.CurseAssignment ~= uiFlat.CurseAssignment or
			row.assignment.BanishAssignment ~= uiFlat.BanishAssignment or
			row.assignment.SSAssignment ~= uiFlat.SSAssignment) then
			return true
		end
	end
	return false
end

function LA.CommitUiToAssignments(rows)
	local currentTable = {}
	for k, row in pairs(rows) do
		currentTable[k] = LA.ReadAssignmentFromFrame(row.warlock.Name)
		if LA.DebugMode and currentTable[k] then
			local ui = currentTable[k]
			LA.print("Old: " .. tostring(row.assignment.CurseAssignment) .. " New: " .. tostring(ui.CurseAssignment))
			LA.print("Old: " .. tostring(row.assignment.BanishAssignment) .. " New: " .. tostring(ui.BanishAssignment))
			LA.print("Old " .. tostring(row.assignment.SSAssignment) .. " New: " .. tostring(ui.SSAssignment))
		end
	end
	return LA.ApplyAssignmentsFromTable(rows, currentTable)
end

function LA.AnnounceAssignments()
	local AnnounceOption = LA.GetValueFromDropDownList(LockAssignmentAnnouncerOptionMenu, LA.AnnouncerOptions, "")
	local lines = LA.BuildAnnouncementLines(LA.LockAssignmentsData, AnnounceOption)
	for _, line in ipairs(lines) do
		LA.SendAnnouncementLine(AnnounceOption, line.message, { Name = line.targetName })
	end
end

function LA.SendAnnouncementLine(AnnounceOption, message, v)
	if AnnounceOption == "Addon Only" then
		if LA.DebugMode then
			LA.print(message)
		end
	elseif AnnounceOption == "Raid" then
		SendChatMessage(message, "RAID", nil, nil)
	elseif AnnounceOption == "Party" then
		SendChatMessage(message, "PARTY", nil, nil)
	elseif AnnounceOption == "Whisper" then
		SendChatMessage(message, "WHISPER", nil, v.Name)
	else
		if LA.DebugMode then
			LA.print("Should send the announce here: " .. AnnounceOption)
		end
		local index = GetChannelName(AnnounceOption)
		if index ~= nil then
			SendChatMessage(message, "CHANNEL", nil, index)
		end
	end
end
