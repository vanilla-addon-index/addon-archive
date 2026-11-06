-- UI/ScrollArea.lua: Main list scroll area, scrollbar, content, 40 warlock slots, global warning text; modf, GetMaxValueForScrollBar.
-- Depends: UI/WarlockRow (LA.CreateAssignmentFrame, LA.AddTextToFrame), LA.LockAssignmentWarlockFrameWidth, LA.LockAssignmentWarlockFrameHeight, LA.GetTableLength.

-- Creates a scroll area to hold the warlock frames.
function LA.InitLockAssignmentFrameScrollArea() --parent frame
	AssignmentFrame = CreateFrame("Frame", nil, LockAssignmentFrame)
	AssignmentFrame:SetWidth(LA.LockAssignmentWarlockFrameWidth-52)
	AssignmentFrame:SetHeight(500)
	AssignmentFrame:SetPoint("CENTER", LockAssignmentFrame, "CENTER", -9, 6)

	--scrollframe
	local scrollframe = CreateFrame("ScrollFrame", "LockAssignmentScroller_ScrollFrame", AssignmentFrame)
	scrollframe:SetPoint("TOPLEFT", 2, -2)
	scrollframe:SetPoint("BOTTOMRIGHT", -2, 2)

	AssignmentFrame.scrollframe = scrollframe

	--scrollbar
	local scrollbar = CreateFrame("Slider", nil, scrollframe, "UIPanelScrollBarTemplate")
	scrollbar:SetPoint("TOPLEFT", AssignmentFrame, "TOPRIGHT", 4, -16)
	scrollbar:SetPoint("BOTTOMLEFT", AssignmentFrame, "BOTTOMRIGHT", 4, 16)
	scrollbar:SetMinMaxValues(1, 200)
	scrollbar:SetValueStep(1)
	scrollbar.scrollStep = 1
	scrollbar:SetValue(0)
	scrollbar:SetWidth(16)
	scrollbar:SetScript("OnValueChanged",
		function()
			scrollbar:GetParent():SetVerticalScroll(this:GetValue())
		end)
	local scrollbg = scrollbar:CreateTexture(nil, "BACKGROUND")
	scrollbg:SetAllPoints(scrollbar)
	scrollbg:SetTexture(0, 0, 0, 0.8)
	AssignmentFrame.scrollbar = scrollbar

	--content frame
	local content = CreateFrame("Frame", nil, scrollframe)
	content:SetWidth(LA.LockAssignmentWarlockFrameWidth-77)
	content:SetHeight(500)

	content.WarlockFrames = {}

	--This is poorly optimized, but it is what it is.
	for i=0, 39 do
		table.insert(content.WarlockFrames, LA.CreateAssignmentFrame("John Doe", i, content, i + 1))
	end

	scrollframe.content = content
	-- 290 is perfect for housing 6 warlock frames.
	-- 410 is perfect for housing 7
	-- 530 is perfect for housing 8
	scrollbar:SetMinMaxValues(1, LA.GetMaxValueForScrollBar(content.WarlockFrames))
	scrollframe:SetScrollChild(content)

	LockAssignmentFrame.WarningTextFrame = CreateFrame("Frame", nil, LockAssignmentFrame);
	LockAssignmentFrame.WarningTextFrame:SetWidth(250);
	LockAssignmentFrame.WarningTextFrame:SetHeight(30);
	LockAssignmentFrame.WarningTextFrame:SetPoint("BOTTOMLEFT", LockAssignmentFrame, "BOTTOMLEFT", 0, 0)

	LockAssignmentFrame.WarningTextFrame.value = LA.AddTextToFrame(LockAssignmentFrame.WarningTextFrame, "Warning your addon is out of date!", 240)
	LockAssignmentFrame.WarningTextFrame.value:SetPoint("LEFT", LockAssignmentFrame.WarningTextFrame, "LEFT", 0, 0);
	LockAssignmentFrame.WarningTextFrame:Hide();
end

function LA.modf(f)
	if math.modf then return math.modf(f) end
	if f > 0 then
		return math.floor(f), math.mod(f,1)
	end
	return math.ceil(f), math.mod(f,1)
end

-- Will take in a table object and return a number of pixels
function LA.GetMaxValueForScrollBar(AssignmentFrame)
	local numberOfFrames = LA.GetTableLength(AssignmentFrame)
	--total frame height is 500 we can probably survive with hardcoding this.
	local _, mod = LA.modf(500/LA.LockAssignmentWarlockFrameHeight)
	local shiftFactor = ((1-mod)*LA.LockAssignmentWarlockFrameHeight) + 13 --There is roughly a 13 pixel spacer somewhere but I am having a hard time nailing it down.
	local FrameSupports = math.floor(500/LA.LockAssignmentWarlockFrameHeight)
	local FirstClippedFrame = math.ceil(500/LA.LockAssignmentWarlockFrameHeight)

	if numberOfFrames <= FrameSupports then
		return 1
	elseif numberOfFrames == FirstClippedFrame then --this is like a partial frame that wont render all the way.
		return shiftFactor
	elseif numberOfFrames > FirstClippedFrame then
		return (numberOfFrames-FirstClippedFrame)*LA.LockAssignmentWarlockFrameHeight + shiftFactor
	end
end
