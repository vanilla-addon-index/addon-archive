-- UI/AssignCheckFrame.lua: Yes/No accept assignment dialog - init, handlers, UpdateSoulStoneAssignment, UpdateAssignedCurseGraphic.
-- Depends: UI/WarlockRow (LA.AddTextToFrame), UI/Graphics (LA.UpdateCurseGraphic, LA.UpdateBanishGraphic, LA.SetAssignmentGraphic), Core (LA.GetColoredName, LA.SetupAssignmentMacro), Comms (LA.SendAssignmentAcknowledgement).

function LA.InitLockAssignmentCheckFrame()
	LockAssignmentAssignCheckFrame =  CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate");

	LockAssignmentAssignCheckFrame:SetWidth(200)
	LockAssignmentAssignCheckFrame:SetHeight(175)
	LockAssignmentAssignCheckFrame:SetPoint("CENTER", UIParent, "CENTER",0,0)
	LockAssignmentAssignCheckFrame:SetBackdrop({
		bgFile= "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
	});

	LockAssignmentAssignCheckFrame:RegisterForDrag("LeftButton");
	LockAssignmentAssignCheckFrame:SetMovable(true);
	LockAssignmentAssignCheckFrame:EnableMouse(true);

	LockAssignmentAssignCheckFrame:SetScript("OnDragStart", LockAssignmentAssignCheckFrame.StartMoving);
	LockAssignmentAssignCheckFrame:SetScript("OnDragStop", LockAssignmentAssignCheckFrame.StopMovingOrSizing);

	AssignmentAssignRejectButton = CreateFrame("Button", nil, LockAssignmentAssignCheckFrame, "GameMenuButtonTemplate");
	AssignmentAssignRejectButton:SetWidth(70);
	AssignmentAssignRejectButton:SetHeight(20);
	AssignmentAssignRejectButton:SetPoint("BOTTOMRIGHT", LockAssignmentAssignCheckFrame, "BOTTOMRIGHT",-15,15)
	AssignmentAssignRejectButton:SetText("No");
	AssignmentAssignRejectButton:SetScript("OnClick", LA.LockAssignmentAssignRejectClick);

	AssignmentAcceptButton = CreateFrame("Button", nil, LockAssignmentAssignCheckFrame, "GameMenuButtonTemplate");
	AssignmentAcceptButton:SetWidth(70);
	AssignmentAcceptButton:SetHeight(20);
	AssignmentAcceptButton:SetPoint("RIGHT", AssignmentAssignRejectButton, "LEFT",-5,0)
	AssignmentAcceptButton:SetText("Yes");
	AssignmentAcceptButton:SetScript("OnClick", LA.LockAssignmentAssignAcceptClick);

	LockAssignmentAssignCheckFrame.AcceptButton = AssignmentAcceptButton;
	LockAssignmentAssignCheckFrame.RejectButton = AssignmentAssignRejectButton;

	LockAssignmentAssignCheckFrame.Label = LA.AddTextToFrame(LockAssignmentAssignCheckFrame, "Your new assignments:", 140)
	LockAssignmentAssignCheckFrame.Label:SetPoint("TOPLEFT", LockAssignmentAssignCheckFrame, "TOPLEFT", 10, -15)

	LockAssignmentAssignCheckFrame.CurseLabel = LA.AddTextToFrame(LockAssignmentAssignCheckFrame, "Curse:", 130)
	LockAssignmentAssignCheckFrame.CurseLabel:SetPoint("TOPLEFT", LockAssignmentAssignCheckFrame, "TOPLEFT", 0, -37)

	local CurseGraphicFrame = CreateFrame("Frame", nil, LockAssignmentAssignCheckFrame)
	CurseGraphicFrame:SetWidth(30)
	CurseGraphicFrame:SetHeight(30)
	CurseGraphicFrame:SetPoint("CENTER", LockAssignmentAssignCheckFrame, "LEFT", 105, 42)

	LockAssignmentAssignCheckFrame.CurseGraphicFrame = CurseGraphicFrame

	LockAssignmentAssignCheckFrame.BanishLabel = LA.AddTextToFrame(LockAssignmentAssignCheckFrame, "Banish:", 130)
	LockAssignmentAssignCheckFrame.BanishLabel:SetPoint("TOPLEFT", LockAssignmentAssignCheckFrame, "TOPLEFT", 0, -67)

	local BanishGraphicFrame = CreateFrame("Frame", nil, LockAssignmentAssignCheckFrame)
	BanishGraphicFrame:SetWidth(30)
	BanishGraphicFrame:SetHeight(30)
	BanishGraphicFrame:SetPoint("CENTER", LockAssignmentAssignCheckFrame, "LEFT", 105, 12)
	LockAssignmentAssignCheckFrame.BanishGraphicFrame = BanishGraphicFrame;

	LockAssignmentAssignCheckFrame.SoulStoneLabel = LA.AddTextToFrame(LockAssignmentAssignCheckFrame, "SoulStone:", 130)
	LockAssignmentAssignCheckFrame.SoulStoneLabel:SetPoint("TOPLEFT", LockAssignmentAssignCheckFrame, "TOPLEFT", -8, -97)

	LockAssignmentAssignCheckFrame.SoulStoneAssignment = LA.AddTextToFrame(LockAssignmentAssignCheckFrame, "", 130)
	LockAssignmentAssignCheckFrame.SoulStoneAssignment:SetPoint("TOPLEFT", LockAssignmentAssignCheckFrame, "TOPLEFT", 65, -97)

	LockAssignmentAssignCheckFrame.Prompt = LA.AddTextToFrame(LockAssignmentAssignCheckFrame, "Do you accept?", 130)
	LockAssignmentAssignCheckFrame.Prompt:SetPoint("TOPLEFT", LockAssignmentAssignCheckFrame, "TOPLEFT", 0, -120)

	LockAssignmentAssignCheckFrame:SetScript("OnShow", LA.LockAssignmentPersonalFrameOnShow);

	LockAssignmentAssignCheckFrame:Hide();
end

function LA.SetLockAssignmentCheckFrame(curse, banish, sstarget)
	if LA.DebugMode then
		LA.print(curse .. " " .. banish .. " " .. (sstarget and LA.GetColoredName(sstarget) or "nil"));
	end
	LA.UpdateCurseGraphic(LockAssignmentAssignCheckFrame, curse)
	LockAssignmentAssignCheckFrame.pendingCurse = curse;
	LA.UpdateBanishGraphic(LockAssignmentAssignCheckFrame, banish)
	LA.UpdateSoulStoneAssignment(sstarget)
	LockAssignmentAssignCheckFrame:Show();
end

function LA.LockAssignmentPersonalFrameOnShow()
	if LA.DebugMode then
		LA.print("Assignment ready check recieved. Assignment check frame should be showing now.");
	end
end

function LA.LockAssignmentAssignAcceptClick()
	LockAssignmentAssignCheckFrame:Hide()

	if LA.DebugMode then
		LA.print("You clicked Yes.")
	end
	LockAssignmentAssignCheckFrame.activeCurse = LockAssignmentAssignCheckFrame.pendingCurse;
	if LA.DebugMode then
		LA.print("Attempting to create macro for curse: ".. LockAssignmentAssignCheckFrame.activeCurse);
	end

	LA.SetupAssignmentMacro(LockAssignmentAssignCheckFrame.activeCurse);
	LA.SendAssignmentAcknowledgement("true");
	LA.UpdatePersonalMonitorFrame();
end

function LA.LockAssignmentAssignRejectClick()
	LockAssignmentAssignCheckFrame:Hide()
	if LA.DebugMode then
		LA.print("You clicked No.")
	end
	LA.SendAssignmentAcknowledgement("false");
end

function LA.UpdateSoulStoneAssignment(Assignment)
	LockAssignmentAssignCheckFrame.SoulStoneAssignment:SetText(LA.GetColoredName(Assignment));
end

-- Uses LA.SetAssignmentGraphic for consistency with dropdown graphic updates.
function LA.UpdateAssignedCurseGraphic(CurseGraphicFrame, CurseListValue)
	local path = (CurseListValue ~= nil) and LA.GetSpellTextureFromDropDownList(CurseListValue) or nil
	LA.SetAssignmentGraphic(CurseGraphicFrame, "CurseTexture", path)
end
