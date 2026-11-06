-- Personal monitor UI: compact frame showing current player's curse, banish, and SS assignments.
-- Depends: UI/Graphics (LA.UpdateCurseGraphic, LA.UpdateBanishGraphic), UI/WarlockRow or shared (LA.AddTextToFrame),
--          Core/RosterData (LA.GetMyAssignment), Core/AssignmentOptions (LA.GetColoredName).

---@return table CurseAssignment, BanishAssignment, SSAssignment (with .Name)
function LA.GetMyData()
	local myRow = LA.GetMyAssignment()
	if not myRow or not myRow.assignment then
		return {
			CurseAssignment = "None",
			BanishAssignment = "None",
			SSAssignment = LA.EmptySSTarget or LA.SoulstoneTarget.none(),
		}
	end
	return myRow.assignment
end

function LA.InitPersonalMonitorFrame()
	if PersonalFramedXOfs == nil or PersonalFramedYOfs == nil then
		AssignmentPersonalMonitorFrame:SetPoint("TOP", UIParent, "TOP", 0, -25)
	else
		AssignmentPersonalMonitorFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", PersonalFramedXOfs, PersonalFramedYOfs)
	end

	if BackdropTemplateMixin then
		Mixin(AssignmentPersonalMonitorFrame, BackdropTemplateMixin)
	end
	AssignmentPersonalMonitorFrame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 12,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	})

	AssignmentPersonalMonitorFrame.CurseGraphicFrame = CreateFrame("Frame", nil, AssignmentPersonalMonitorFrame)
	AssignmentPersonalMonitorFrame.CurseGraphicFrame:SetWidth(30)
	AssignmentPersonalMonitorFrame.CurseGraphicFrame:SetHeight(30)
	AssignmentPersonalMonitorFrame.CurseGraphicFrame:SetPoint("LEFT", AssignmentPersonalMonitorFrame, "LEFT", 2, 0)

	AssignmentPersonalMonitorFrame.BanishGraphicFrame = CreateFrame("Frame", nil, AssignmentPersonalMonitorFrame)
	AssignmentPersonalMonitorFrame.BanishGraphicFrame:SetWidth(30)
	AssignmentPersonalMonitorFrame.BanishGraphicFrame:SetHeight(30)
	AssignmentPersonalMonitorFrame.BanishGraphicFrame:SetPoint("LEFT", AssignmentPersonalMonitorFrame.CurseGraphicFrame, "RIGHT", 2, 0)

	AssignmentPersonalMonitorFrame.SSAssignmentText = LA.AddTextToFrame(AssignmentPersonalMonitorFrame, "", 75)
	AssignmentPersonalMonitorFrame.SSAssignmentText:SetPoint("LEFT", AssignmentPersonalMonitorFrame.BanishGraphicFrame, "RIGHT", 5, 0)
	AssignmentPersonalMonitorFrame.SSAssignmentText:SetJustifyH("LEFT")

	AssignmentPersonalMonitorFrame.MainLabel = LA.AddTextToFrame(AssignmentPersonalMonitorFrame, "Lock Assigns:", 125)
	AssignmentPersonalMonitorFrame.MainLabel:SetPoint("BOTTOM", AssignmentPersonalMonitorFrame, "TOP")

	AssignmentPersonalMonitorFrame:Hide()
end

function LA.UpdatePersonalSSAssignment(ParentFrame, SSAssignment)
	if not ParentFrame.SSAssignmentText then return end
	if SSAssignment and SSAssignment.Name ~= "None" then
		ParentFrame.SSAssignmentText:SetText(LA.GetColoredName(SSAssignment))
	else
		ParentFrame.SSAssignmentText:SetText("")
	end
end

function LA.UpdatePersonalMonitorFrame()
	if not AssignmentPersonalMonitorFrame.SSAssignmentText then
		LA.InitPersonalMonitorFrame()
	end
	local myData = LA.GetMyData()
	LA.UpdateBanishGraphic(AssignmentPersonalMonitorFrame, myData.BanishAssignment)
	LA.UpdateCurseGraphic(AssignmentPersonalMonitorFrame, myData.CurseAssignment)
	LA.UpdatePersonalSSAssignment(AssignmentPersonalMonitorFrame, myData.SSAssignment)
	AssignmentPersonalMonitorFrame:SetScript("OnClick", function()
		if myData.SSAssignment and myData.SSAssignment.Name ~= "None" then
			TargetUnit(myData.SSAssignment.Name)
		end
	end)

	LA.UpdatePersonalMonitorSize(myData)

	-- Default layout
	AssignmentPersonalMonitorFrame.CurseGraphicFrame:SetPoint("LEFT", AssignmentPersonalMonitorFrame, "LEFT", 2, 0)
	AssignmentPersonalMonitorFrame.BanishGraphicFrame:SetPoint("LEFT", AssignmentPersonalMonitorFrame.CurseGraphicFrame, "RIGHT", 2, 0)
	AssignmentPersonalMonitorFrame.SSAssignmentText:SetPoint("LEFT", AssignmentPersonalMonitorFrame.BanishGraphicFrame, "RIGHT", 5, 0)

	if myData.CurseAssignment == "None" and myData.BanishAssignment ~= "None" then
		AssignmentPersonalMonitorFrame.BanishGraphicFrame:SetPoint("LEFT", AssignmentPersonalMonitorFrame, "LEFT", 2, 0)
		AssignmentPersonalMonitorFrame.SSAssignmentText:SetPoint("LEFT", AssignmentPersonalMonitorFrame.BanishGraphicFrame, "RIGHT", 5, 0)
	end
	if myData.BanishAssignment == "None" and myData.CurseAssignment ~= "None" then
		AssignmentPersonalMonitorFrame.SSAssignmentText:SetPoint("LEFT", AssignmentPersonalMonitorFrame.CurseGraphicFrame, "RIGHT", 5, 0)
	end
	if myData.CurseAssignment == "None" and myData.BanishAssignment == "None" then
		AssignmentPersonalMonitorFrame.SSAssignmentText:SetPoint("LEFT", AssignmentPersonalMonitorFrame, "LEFT", 2, 0)
	end

	LA.HaveSSAssignment = myData.SSAssignment and myData.SSAssignment.Name ~= "None"
	if myData.CurseAssignment ~= "None" or myData.BanishAssignment ~= "None" or (myData.SSAssignment and myData.SSAssignment.Name ~= "None") then
		AssignmentPersonalMonitorFrame:Show()
	else
		AssignmentPersonalMonitorFrame:Hide()
	end
end

function LA.UpdatePersonalMonitorSize(myData)
	local picframesize = 34
	local buffcount = 0
	if myData.CurseAssignment ~= "None" then
		buffcount = buffcount + 1
	end
	if myData.BanishAssignment ~= "None" then
		buffcount = buffcount + 1
	end
	local textLength = 0
	if myData.SSAssignment and myData.SSAssignment.Name ~= "None" then
		textLength = 75
	end
	AssignmentPersonalMonitorFrame:SetWidth((picframesize * buffcount) + textLength)
	AssignmentPersonalMonitorFrame:SetHeight(34)
end
