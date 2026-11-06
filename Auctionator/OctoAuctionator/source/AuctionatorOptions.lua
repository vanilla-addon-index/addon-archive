-- AuctionatorOptions.lua: the 3.x options panels lived in the Interface Options window, which 1.12 does not have.
-- The panels themselves (AuctionatorConfig.xml) are reused; this file hosts them in one standalone window.

local TAB_ORDER = { "Atr_BasicOptionsFrame", "Atr_TooltipsOptionsFrame", "Atr_UCConfigFrame",
	"Atr_StackingOptionsFrame", "Atr_ScanningOptionsFrame", "AuctionatorDescriptionFrame" }

local tabButtons = {}
local selected = 1

local function SelectTab(index)

	selected = index

	for i = 1, getn(TAB_ORDER) do
		local panel = getglobal(TAB_ORDER[i])
		if panel then
			if i == index then panel:Show() else panel:Hide() end
		end
		local b = tabButtons[i]
		if b then
			if i == index then b:Disable() else b:Enable() end
		end
	end

	if Atr_MemorizeFrame then Atr_MemorizeFrame:Hide() end
end

local function SaveAll()

	for i = 1, getn(TAB_ORDER) do
		local panel = getglobal(TAB_ORDER[i])
		if panel and type(panel.okay) == "function" then
			panel.okay()
		end
	end

	Atr_OptionsWindow:Hide()
end

local function Build()

	if Atr_OptionsWindow then return end

	local f = CreateFrame("Frame", "Atr_OptionsWindow", UIParent)
	f:SetWidth(480)
	f:SetHeight(470)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() this:StartMoving() end)
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 } })
	f:Hide()
	tinsert(UISpecialFrames, "Atr_OptionsWindow")

	local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOP", f, "TOP", 0, -18)
	title:SetText("OctoAuctionator")

	local labels = { "Basic", "Tooltips", "Undercut", "Selling", "Scanning", "About" }
	local x = 20
	for i = 1, getn(TAB_ORDER) do
		local b = CreateFrame("Button", "Atr_OptionsTab" .. i, f, "UIPanelButtonTemplate")
		b:SetWidth(70)
		b:SetHeight(20)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", x, -44)
		b:SetText(labels[i])
		local idx = i
		b:SetScript("OnClick", function() SelectTab(idx) end)
		tabButtons[i] = b
		x = x + 72
	end

	for i = 1, getn(TAB_ORDER) do
		local panel = getglobal(TAB_ORDER[i])
		if panel then
			panel:SetParent(f)
			panel:ClearAllPoints()
			panel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -70)
			panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 50)
			panel:SetFrameLevel(f:GetFrameLevel() + 2)
		end
	end

	local okay = CreateFrame("Button", "Atr_OptionsOkay", f, "UIPanelButtonTemplate")
	okay:SetWidth(90)
	okay:SetHeight(22)
	okay:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -108, 18)
	okay:SetText("Okay")
	okay:SetScript("OnClick", SaveAll)

	local cancel = CreateFrame("Button", "Atr_OptionsCancel", f, "UIPanelButtonTemplate")
	cancel:SetWidth(90)
	cancel:SetHeight(22)
	cancel:SetPoint("LEFT", okay, "RIGHT", 4, 0)
	cancel:SetText("Cancel")
	cancel:SetScript("OnClick", function()
		if Atr_Options_Cancel then Atr_Options_Cancel() end
		f:Hide()
	end)
end

function Atr_ShowOptions()

	if AUCTIONATOR_SAVEDVARS == nil then Atr_ResetSavedVars() end

	Build()

	if Atr_InitOptionsPanels then Atr_InitOptionsPanels() end

	SelectTab(selected)
	Atr_OptionsWindow:Show()
end
