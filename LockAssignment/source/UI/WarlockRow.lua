-- UI/WarlockRow.lua: One warlock assignment row - container, portrait, nameplate, curse/banish/SS menus, cooldown, ack, warning.
-- Depends: UI/Dropdowns (LA.CreateDropDownMenu, LA.CreateSoulstoneDropDownMenu), UI/Graphics (LA.SetAssignmentGraphic, LA.UpdateCurseGraphic, LA.UpdateBanishGraphic), Core (LA.GetSSTargets).

--[[
	A dropdown list of curses to assign.

	A dropdown list of names for SoulStones... or maybe a text box for the name...

	A drop down list of raid markers for banish assignments.

	A dropdown to keep track of SS targets.

	A timer to keep track of SS CDs.

	A status indicator to show if warlock has accepted the assignment.
]]--
function LA.CreateAssignmentFrame(WarlockName, number, scrollframe)
	-- Draws the warlock Component Frame, adds the border, and positions it relative to the number of frames created.
	local AssignmentFrame = LA.CreateAssignmentContainer(scrollframe, number)
	AssignmentFrame.LockFrameID  = "AssignmentFrame_0"..tostring(number)
	AssignmentFrame.WarlockName = WarlockName

	-- Creates a portrait to assist in identifying units.
	AssignmentFrame.Portrait = LA.CreateLockAssignmentPortrait(AssignmentFrame, WarlockName, number)

	-- Draws the name in the frame.
	AssignmentFrame.NamePlate = LA.CreateNamePlate(AssignmentFrame, WarlockName)

	-- Draws the curse dropdown.
	AssignmentFrame.CurseAssignmentMenu = LA.CreateCurseAssignmentMenu(AssignmentFrame)

	-- Draw a BanishAssignment DropDownMenu
	AssignmentFrame.BanishAssignmentMenu = LA.CreateBanishAssignmentMenu(AssignmentFrame)

	-- Draw a SS Assignment Menu.
	AssignmentFrame.SSAssignmentMenu = LA.CreateSSAssignmentMenu(AssignmentFrame)

	-- Draw the SSCooldownTracker
	AssignmentFrame.SSCooldownTracker = LA.CreateSSCooldownTracker(AssignmentFrame.SSAssignmentMenu)

	AssignmentFrame.AssignmentAcknowledgement = LA.CreateAckFrame(AssignmentFrame);

	AssignmentFrame.Warning = LA.CreateWarningFrame(AssignmentFrame);

	return AssignmentFrame
end

-- Creates a textframe to display the SS cooldown.
function LA.CreateSSCooldownTracker(ParentFrame)
	local TextFrame = LA.AddTextToFrame(ParentFrame, "Unknown", 120)
	TextFrame:SetPoint("TOP", ParentFrame, "BOTTOM", 0,0)
	return TextFrame
end

-- Creates the frame that will act as teh container for the component control.
function LA.CreateAssignmentContainer(ParentFrame, number)
	local AssignmentFrame = CreateFrame("Frame", nil, ParentFrame, BackdropTemplateMixin and "BackdropTemplate")
	AssignmentFrame:SetWidth(LA.LockAssignmentWarlockFrameWidth-67)
	AssignmentFrame:SetHeight(LA.LockAssignmentWarlockFrameHeight)
	-- Set up the border around the warlock frame.
	AssignmentFrame:SetBackdrop({
		bgFile= "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	})
	-- Calculate where to draw the frame on the screen.
	local yVal = (number*(-LA.LockAssignmentWarlockFrameHeight))-10
	AssignmentFrame:SetPoint("TOPLEFT", ParentFrame, "TOPLEFT", 8, yVal)

	return AssignmentFrame
end

-- Creates and assigns the player portrait to the individual raiders in the contrl.
function LA.CreateLockAssignmentPortrait(ParentFrame, WarlockName, number)
	local portrait = CreateFrame("Frame", nil, ParentFrame)
	portrait:SetWidth(80)
	portrait:SetHeight(80)
	portrait:SetPoint("LEFT", 13, -5)
	local texture = portrait:CreateTexture(nil, "BACKGROUND")
	texture:SetAllPoints()
	if WarlockName == UnitName("player") then
		SetPortraitTexture(texture, "player")
	else
		SetPortraitTexture(texture, string.format("raid%d", number))
	end
	portrait.Texture = texture

	return portrait
end

-- Builds and sets the banish Icon assignment menu.
function LA.CreateBanishAssignmentMenu(ParentFrame)
	local BanishAssignmentMenu = LA.CreateDropDownMenu(ParentFrame, LA.BanishMarkers, "BANISH")
	BanishAssignmentMenu:SetPoint("CENTER", -50, -30)
	BanishAssignmentMenu.Label = LA.CreateBanishAssignmentLabel(BanishAssignmentMenu)

	local BanishGraphicFrame = CreateFrame("Frame", nil, ParentFrame)
	BanishGraphicFrame:SetWidth(30)
	BanishGraphicFrame:SetHeight(30)
	BanishGraphicFrame:SetPoint("LEFT", BanishAssignmentMenu, "RIGHT", -12, 8)

	BanishAssignmentMenu.BanishGraphicFrame = BanishGraphicFrame

	return BanishAssignmentMenu
end

-- Creates and sets the Banish Assignment Label as part of the banish assignment control.
function LA.CreateBanishAssignmentLabel(ParentFrame)
	local Label = LA.AddTextToFrame(ParentFrame, "Banish Assignment", 150)
	Label:SetPoint("BOTTOMLEFT", ParentFrame, "TOPLEFT", 0, 0)
	return Label
end

-- Creates and sets the nameplate for the warlock Frame.
function LA.CreateNamePlate(ParentFrame, Text)
	local NameplateFrame = ParentFrame:CreateTexture(nil, "OVERLAY")
	NameplateFrame:SetWidth(205)
	NameplateFrame:SetHeight(50)
	NameplateFrame:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	NameplateFrame:SetPoint("LEFT", ParentFrame, "TOPLEFT", -45, -20)

	local TextFrame = LA.AddTextToFrame(ParentFrame, Text, 90)
	TextFrame:SetPoint("TOPLEFT", 10,-6)

	NameplateFrame.TextFrame = TextFrame

	return NameplateFrame
end

-- Adds text to a frame that is passed in.
-- This text will not be automatically displayed and must be anchored before it will render to the screen.
function LA.AddTextToFrame(ParentFrame, Text, Width)
	local NamePlate = ParentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	NamePlate:SetText(Text)
	NamePlate:SetWidth(Width)
	NamePlate:SetJustifyH("CENTER")
	NamePlate:SetJustifyV("CENTER")
	NamePlate:SetTextColor(1,1,1,1)
	return NamePlate
end

-- Creates the curse assignment menu.
function LA.CreateCurseAssignmentMenu(ParentFrame)
	local CurseAssignmentMenu = LA.CreateDropDownMenu(ParentFrame, LA.CurseOptions, "CURSE")
	CurseAssignmentMenu:SetPoint("CENTER", -50, 20)
	CurseAssignmentMenu.Label = LA.CreateCurseAssignmentLabel(CurseAssignmentMenu)

	local CurseGraphicFrame = CreateFrame("Frame", nil, ParentFrame)
	CurseGraphicFrame:SetWidth(30)
	CurseGraphicFrame:SetHeight(30)
	CurseGraphicFrame:SetPoint("LEFT", CurseAssignmentMenu, "RIGHT", -12, 8)

	CurseAssignmentMenu.CurseGraphicFrame = CurseGraphicFrame

	return CurseAssignmentMenu
end

-- Creates the label for the curse assignment. This may not need to have been encapsulated as such but it made sense to me at the time.
function LA.CreateCurseAssignmentLabel(ParentFrame)
	local Label = LA.AddTextToFrame(ParentFrame, "Curse Assignment", 150)
	Label:SetPoint("BOTTOMLEFT", ParentFrame, "TOPLEFT", 0, 0)
	return Label
end

-- Builds and sets the banish Icon assignment menu.
-- Parent Frame refers to a "AssignmentFrame"
function LA.CreateSSAssignmentMenu(ParentFrame)
	local SSTargets = LA.GetSSTargets();

	local SSAssignmentMenu = LA.CreateSoulstoneDropDownMenu(ParentFrame, SSTargets, "SSAssignments")
	SSAssignmentMenu:SetPoint("CENTER", 140, 20)
	SSAssignmentMenu.Label = LA.CreateSSAssignmentLabel(SSAssignmentMenu)

	return SSAssignmentMenu
end

-- Builds the acknowledgment frame that attaches to the main window to display if assignments have been accepted or not.
function LA.CreateAckFrame(ParentFrame)
	local AckFrame = CreateFrame("Frame", nil, ParentFrame)
	AckFrame:SetWidth(150)
	AckFrame:SetHeight(30)
	AckFrame:SetPoint("CENTER", ParentFrame, "CENTER",80,-25)

	AckFrame.label = LA.AddTextToFrame(AckFrame, "Accepted:", 150)
	AckFrame.label:SetPoint("LEFT", AckFrame, "LEFT", 0, 0)

	AckFrame.value = LA.AddTextToFrame(AckFrame, "Not Recieved", 120)
	AckFrame.value:SetPoint("LEFT", AckFrame, "LEFT", 85, 0)
	return AckFrame;
end

-- Builds a warning fram that shows if the addon is out of date.
function LA.CreateWarningFrame(ParentFrame)
	local NoteFrame = CreateFrame("Frame", nil, ParentFrame)
	NoteFrame:SetWidth(150)
	NoteFrame:SetHeight(30)
	NoteFrame:SetPoint("BOTTOMLEFT", ParentFrame, "BOTTOMLEFT",0,0)
	NoteFrame.value = LA.AddTextToFrame(NoteFrame, "Warning: Addon out of date", 250)
	NoteFrame.value:SetPoint("LEFT", NoteFrame, "LEFT", 0, 0)
	NoteFrame:Hide();
	return NoteFrame;
end

-- Create's the "Soul Stone" Label that appears above the soul stone target drop down menu.
function LA.CreateSSAssignmentLabel(ParentFrame)
	local Label = LA.AddTextToFrame(ParentFrame, "Soul Stone", 130)
	Label:SetPoint("BOTTOMLEFT", ParentFrame, "TOPLEFT", 0, 0)
	return Label
end
