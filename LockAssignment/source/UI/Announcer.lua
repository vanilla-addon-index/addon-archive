-- UI/Announcer.lua: Chat channel dropdown - InitAnnouncerOptionFrame, SetExtraChats.
-- Depends: UI/Dropdowns (LA.CreateDropDownMenu, LA.UpdateDropDownMenuWithNewOptions), Core (LA.AnnouncerOptions).

function LA.InitAnnouncerOptionFrame()
	LockAssignmentAnnouncerOptionMenu = LA.CreateDropDownMenu(NLAnnouncerContainer, LA.AnnouncerOptions, "CHAT")
	LockAssignmentAnnouncerOptionMenu:SetPoint("CENTER", NLAnnouncerContainer, "CENTER", 0,0);
end

function LA.SetExtraChats()
	LA.AnnouncerOptions ={
		"Addon Only",
		"Raid",
		"Party",
		"Whisper"
	}

	LA.UpdateDropDownMenuWithNewOptions(LockAssignmentAnnouncerOptionMenu, LA.AnnouncerOptions, "CHAT")
end
