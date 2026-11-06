--Initialization logic for setting up the entire addon
LA.UpdateFrame:RegisterEvent("RAID_ROSTER_UPDATE")
LA.UpdateFrame:RegisterEvent("ADDON_LOADED")
LA.UpdateFrame:SetScript("OnEvent", LA.OnEvent);

function LA.LockAssignmentInit()
	if not LockAssignmentFrame_HasInitialized then
		--LA.print("Prepping init")
		LockAssignmentFrame:SetBackdrop({
			bgFile= "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 32,
			edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 }
		})
		LA.InitLockAssignmentFrameScrollArea()
		LA.RegisterForComms()
		LA.OnAssignmentsOrVersionChanged = function(eventType, payload)
			if eventType == "VersionOutOfDate" then
				LockAssignmentFrame.WarningTextFrame:Show()
				LACommit_Button:Disable()
			elseif eventType == "BroadcastMerged" then
				LA.UpdateAllWarlockFrames()
				local myRow = LA.GetMyAssignment()
				if myRow then
					local a = myRow.assignment
					LA.HaveSSAssignment = a.SSAssignment and a.SSAssignment.Name ~= "None"
					if a.CurseAssignment == "None" and a.BanishAssignment == "None" and (not a.SSAssignment or a.SSAssignment.Name == "None") then
						AssignmentPersonalMonitorFrame:Hide()
					else
						LA.UpdatePersonalMonitorFrame()
						AssignmentPersonalMonitorFrame:Show()
					end
				end
			elseif eventType == "MyAssignmentReceived" and payload then
				if LA.HasMyAssignmentChanged(payload) or LA.DebugMode then
					LA.SetLockAssignmentCheckFrame(payload.CurseAssignment, payload.BanishAssignment, payload.SSAssignment)
				else
					LockAssignmentAssignCheckFrame.activeCurse = payload.CurseAssignment
					LA.SetupAssignmentMacro(LockAssignmentAssignCheckFrame.activeCurse)
					LA.SendAssignmentAcknowledgement("true")
				end
			elseif eventType == "AckReceived" and payload then
				LA.RefreshAssignmentFrame(payload, LA.GetAssignmentFrameById(payload.assignment.AssignmentFrameLocation))
			elseif eventType == "AssignmentReset" then
				LA.UpdateAllWarlockFrames()
			end
		end
		LockAssignmentFrame_HasInitialized = true
		LA.UpdateAllWarlockFrames();
		LA.InitLockAssignmentCheckFrame();
		LA.InitAnnouncerOptionFrame();
		LA.ShowMinimapButton()
		LockAssignmentFrame:Hide()
		tinsert(UISpecialFrames, "LockAssignmentFrame");
	end	
end

function LA.OnEvent()
	if event == "RAID_ROSTER_UPDATE" then
		LA.RosterUpdate()
		LA.LockAssignmentsData = LA.SyncRosterWithAssignments(LA.LockAssignmentsData)
		LA.UpdateAllWarlockFrames()
		LA.UpdatePersonalMonitorFrame()
		LA.RefreshPersonalPortrait()
	elseif event == "ADDON_LOADED" then
		LA.InitPersonalMonitorFrame();
	end
end

function LA.RosterUpdate()
	if not (UnitInRaid("player")) then
		AssignmentPersonalMonitorFrame:Hide()
	end
end

function LA.ShowMinimapButton()
	LockAssignmentMinimapButton:Show();
end

-- Update handler to be used for any animations, is called once per frame, but can be throttled using an update interval.
function LockAssignmentFrame_OnUpdate(self, elapsed)
	if (self.TimeSinceLastClockUpdate == nil) then self.TimeSinceLastClockUpdate = 0; end
	if (self.TimeSinceLastSSCDUpdate == nil) then self.TimeSinceLastSSCDUpdate = 0; end
	if (self.TimeSinceLastSSCDBroadcast == nil) then self.TimeSinceLastSSCDBroadcast = 0; end

	self.TimeSinceLastClockUpdate = self.TimeSinceLastClockUpdate + elapsed; 	
	if (self.TimeSinceLastClockUpdate > LA.LockAssignmentClock_UpdateInterval) then
		self.TimeSinceLastClockUpdate = 0;
		if LA.DebugMode then
			LA.print("Updating the UI");
		end
		LA.UpdateAllLocksAssignmentClock()
	end

	self.TimeSinceLastSSCDUpdate = self.TimeSinceLastSSCDUpdate + elapsed;
	self.TimeSinceLastSSCDBroadcast = self.TimeSinceLastSSCDBroadcast + elapsed;
	if(self.TimeSinceLastSSCDUpdate > LA.LockAssignmentSSCD_UpdateInterval) then
		self.TimeSinceLastSSCDUpdate = 0;
		if LA.DebugMode then
			LA.print("Checking SSCD");
		end
		LA.CheckSSCD(self)
	end
end

-- Update handler to be used for any animations, is called once per frame, but can be throttled using an update interval.
function LockAssignmentPersonalFrame_OnUpdate(self, elapsed)
	if (not LA.HaveSSAssignment) or LockAssignmentFrame:IsVisible() then
		return
	end
	if (self.TimeSinceLastSSCDUpdate == nil) then self.TimeSinceLastSSCDUpdate = 0; end
	if (self.TimeSinceLastSSCDBroadcast == nil) then self.TimeSinceLastSSCDBroadcast = 0; end

	self.TimeSinceLastSSCDUpdate = self.TimeSinceLastSSCDUpdate + elapsed;
	self.TimeSinceLastSSCDBroadcast = self.TimeSinceLastSSCDBroadcast + elapsed;
	if(self.TimeSinceLastSSCDUpdate > LA.LockAssignmentSSCD_UpdateInterval) then
		self.TimeSinceLastSSCDUpdate = 0;
		if LA.DebugMode then
			LA.print("Checking SSCD");
		end
		LA.CheckSSCD(self)
	end
end

function LA.InitLockAssignmentData()
	if LA.RaidMode then
		if LA.DebugMode then
			LA.print("Initializing Warlock Data")
		end
		return LA.BuildRosterFromRaid()
	else
		return LA.LockAssignmentsData
	end
end

--This is wired to a button click at present.
function LA.LockAssignment_HideFrame()
	if LA.HasUnsavedAssignmentChanges(LA.LockAssignmentsData) then
		LA.print("Changes were not saved.")
		--PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
		LockAssignmentFrame:Hide()
	else
		--PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
		LockAssignmentFrame:Hide()
	end
end

function LA.LockAssignment_Commit()
	if LA.FindMyRaidRank() < 1 then
		LACommit_Button:Disable();
	else
		LA.LockAssignmentsData = LA.CommitUiToAssignments(LA.LockAssignmentsData)
		LA.UpdateAllWarlockFrames();
		LA.SendAssignmentReset();
		LA.BroadcastTable(LA.LockAssignmentsData)

		LA.AnnounceAssignments();
		--PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
		--LockAssignmentFrame:Hide()
	end
end

-- Returns my rank to determine whether we should disable commit button
function LA.FindMyRaidRank()
	for i=1, 40 do
		local name, rank, _, _, _, fileName, _, _, _, _, _ = GetRaidRosterInfo(i);
		if not (name == nil) then
			if fileName == "WARLOCK" and name == UnitName("player") then
				return rank
			end
		end
	end
	return 0
end

-- Event for handling the frame showing.
function LA.LockAssignment_OnShowFrame()
	if not LockAssignmentData_HasInitialized then
		LA.LockAssignmentsData = LA.InitLockAssignmentData()
		
		--LockAssignmentData_Timestamp = 0
		LockAssignmentData_HasInitialized = true
		if LA.DebugMode then
			LA.print("Initialization complete");
			
			LA.print("Found " .. LA.GetTableLength(LA.LockAssignmentsData) .. " Warlocks in raid." );
		end		
	end

	if LA.DebugMode then
		LA.print("Frame should be showing now.")
	end
	
	--PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
	--LA.print("Updating SS targets")
	LA.UpdateSSTargets()
	LA.LockAssignmentsData = LA.SyncRosterWithAssignments(LA.LockAssignmentsData);
	LA.UpdateAllWarlockFrames();
	LA.UpdatePersonalMonitorFrame()
	LA.RequestAssignments()
	if LA.DebugMode then
		LA.print("Found " .. LA.GetTableLength(LA.LockAssignmentsData) .. " Warlocks in raid." );
	end	
	if LA.GetTableLength(LA.LockAssignmentsData) == 0 then
		LA.RaidMode = false;
		LA.LockAssignmentsData = LA.BuildSoloRoster();
	end
	LA.SetExtraChats();
	if LA.FindMyRaidRank() >= 1 then
		LACommit_Button:Enable()
	else
		LACommit_Button:Disable()
	end
end

-- /command for opening the ui.
SLASH_LA1 = "/la"
SLASH_LA2 = "/lockassignment"
SlashCmdList["LA"] = function(msg)

	if msg == "debug" then
		if(LA.DebugMode) then
			LA.DebugMode = false
			LA.print("Lock Assignment Debug Mode OFF")
		else
			LA.DebugMode = true
			LA.print("Lock Assignment Debug Mode ON")
		end		
	elseif msg == "test" then
		LockAssignmentAssignCheckFrame:Show();
	else
		LockAssignmentFrame:Show()
	end	
end

--Short hand /command for reloading the ui.
SLASH_RL1 = "/rl"
SlashCmdList["RL"]= function(_)
	ReloadUI();
end
