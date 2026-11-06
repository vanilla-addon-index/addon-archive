--[[
	Options.lua
		Settings window for Bagnon (/bagnon, or right-click a window title), in the ForgeUI style.
		General: when the windows open by themselves and what the header shows.
		Windows: the layout of the inventory and of the bank window.
		Author: Tuller, McPewPew, Fostercare5988
--]]

if not Bagnon_EngineReady then
	return
end

local addonName, ns = ...
local UI = ns.UI

local WINDOWS = { "Bagnon", "Banknon" }
local selected = "Bagnon"	-- the window the Windows tab edits
local panel, ShowTab
local refresh = {}

local function Window()
	return _G[selected]
end

local function Sets()
	return BagnonSets[selected]
end

--[[ What an option changes in the open windows ]]--

local function RefreshPanel(index)
	if panel and panel:IsShown() then refresh[index]() end
end

-- The header (free space, sort button) and the search box
function BagnonOptions_RefreshHeader()
	for _, frame in ipairs({ Bagnon, Banknon }) do
		if frame:IsShown() then
			BagnonFrame_UpdateFreeSlots(frame)
			BagnonSearch_Update(frame, Bagnon_IsCachedFrame(frame))
		end
	end
	RefreshPanel(1)
end

function BagnonOptions_RefreshItems()
	if Bagnon:IsShown() then BagnonFrame_Generate(Bagnon) end
	if Banknon:IsShown() then BagnonFrame_Generate(Banknon) end
	RefreshPanel(1)
end

-- Rescale a window and keep it where it is on the screen.
local function SetScale(frame, scale)
	local left, top = frame:GetLeft(), frame:GetTop()
	local oldScale = frame:GetScale() or 1
	BagnonSets[frame:GetName()].scale = scale
	frame:SetScale(scale)
	if left and top then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", frame:GetParent() or UIParent, "BOTTOMLEFT", left * oldScale / scale, top * oldScale / scale)
	end
	BagnonFrame_SavePosition(frame)
end

local function SetBackground(frame, r, g, b, a)
	local bg = BagnonSets[frame:GetName()].bg
	bg.r, bg.g, bg.b, bg.a = r, g, b, a
	frame:SetBackdropColor(r, g, b, a)
	frame:SetBackdropBorderColor(1, 1, 1, a)
end

-- The client's colour picker; Cancel puts the old colour back.
local function PickBackground()
	if ColorPickerFrame:IsShown() then
		ColorPickerFrame:Hide()
		return
	end
	local frame = Window()
	local bg = Sets().bg
	ColorPickerFrame.func = function()
		local r, g, b = ColorPickerFrame:GetColorRGB()
		SetBackground(frame, r, g, b, bg.a)
	end
	ColorPickerFrame.hasOpacity = 1
	ColorPickerFrame.opacity = 1 - bg.a
	ColorPickerFrame.opacityFunc = function()
		SetBackground(frame, bg.r, bg.g, bg.b, 1 - OpacitySliderFrame:GetValue())
	end
	ColorPickerFrame.previousValues = { r = bg.r, g = bg.g, b = bg.b, opacity = bg.a }
	ColorPickerFrame.cancelFunc = function()
		local previous = ColorPickerFrame.previousValues
		SetBackground(frame, previous.r, previous.g, previous.b, previous.opacity)
	end
	ColorPickerFrame:SetColorRGB(bg.r, bg.g, bg.b)
	ShowUIPanel(ColorPickerFrame)
	ColorPickerFrame:Raise()
end

--[[ The window ]]--

local function BuildGeneral(page)
	UI.Heading(page, "Open inventory", 28, -98)
	local atBank = UI.Switch("Bagnon_AtBank", page, "At the bank",
		"Open your inventory when you open the bank.", 28, -122, function(value)
			BagnonSets.showBagsAtBank = value and 1 or nil
		end)
	local atAH = UI.Switch("Bagnon_AtAH", page, "At the auction house",
		"Open your inventory when you open the auction house.", 28, -158, function(value)
			BagnonSets.showBagsAtAH = value and 1 or nil
		end)

	UI.Heading(page, "Bank", 28, -204)
	local bankAtBank = UI.Switch("Bagnon_BankAtBank", page, "Use Bagnon's bank window",
		"Show the bank in Bagnon's window instead of the standard bank window.", 28, -228, function(value)
			BagnonSets.showBankAtBank = value and 1 or nil
		end)

	UI.Heading(page, "Show", 28, -274)
	local freeSlots = UI.Switch("Bagnon_FreeSlots", page, "Free bag space",
		"Show the free slots in the window header. Hover it for every bag.", 28, -298, function(value)
			BagnonSets.showFreeSlots = value and 1 or 0
			BagnonOptions_RefreshHeader()
		end)
	local sortButton = UI.Switch("Bagnon_SortButton", page, "Sort button",
		"Show the broom in the window header. /bgn sort and the key binding keep working.", 28, -334, function(value)
			BagnonSets.showSortButton = value and 1 or 0
			BagnonOptions_RefreshHeader()
		end)
	local search = UI.Switch("Bagnon_Search", page, "Search box",
		"Show the search box at the bottom of the window.", 28, -370, function(value)
			BagnonSets.showSearch = value and 1 or 0
			BagnonOptions_RefreshHeader()
		end)
	local enchants = UI.Switch("Bagnon_Enchants", page, "Weapon enchant badges",
		"Show the time or charges left of a poison or oil on weapons in your bags.", 28, -406, function(value)
			BagnonSets.enchantBadges = value and 1 or 0
			BagnonOptions_RefreshItems()
		end)
	UI.Label(page, "Right-click a window title to set up that window.", 28, -450, "GameFontDisableSmall")

	refresh[1] = function()
		UI.Sync(atBank, BagnonSets.showBagsAtBank)
		UI.Sync(atAH, BagnonSets.showBagsAtAH)
		UI.Sync(bankAtBank, BagnonSets.showBankAtBank)
		UI.Sync(freeSlots, BagnonSets.showFreeSlots ~= 0)
		UI.Sync(sortButton, BagnonSets.showSortButton ~= 0)
		UI.Sync(search, BagnonSets.showSearch ~= 0)
		UI.Sync(enchants, BagnonSets.enchantBadges ~= 0)
	end
end

local function BuildWindows(page)
	local _, selectWindow = UI.Segmented("Bagnon_Window", page, { "Inventory", "Bank" }, 28, -98, 444, function(index)
		selected = WINDOWS[index]
		refresh[2]()
	end)

	local columns = UI.Slider("Bagnon_Columns", page, "Columns", 28, -148, 208, 1, 32, 1, function(value)
		BagnonFrame_Layout(Window(), value, Window().space)
	end)
	local spacing = UI.Slider("Bagnon_Spacing", page, "Spacing", 264, -148, 208, 0, 32, 1, function(value)
		BagnonFrame_Layout(Window(), Window().cols, value)
	end)
	local scale = UI.Slider("Bagnon_Scale", page, "Scale", 28, -190, 208, 50, 150, 1, function(value)
		SetScale(Window(), value / 100)
	end, function(value) return value .. "%" end)
	local opacity = UI.Slider("Bagnon_Opacity", page, "Opacity", 264, -190, 208, 0, 100, 1, function(value)
		Sets().alpha = value / 100
		Window():SetAlpha(value / 100)
	end, function(value) return value .. "%" end)

	UI.Heading(page, "Layer", 28, -244)
	local selectStrata
	_, selectStrata = UI.Segmented("Bagnon_Strata", page, { "Low", "Medium", "High" }, 28, -266, 208, function(index)
		BagnonFrame_SetStrata(Window(), index)
		selectStrata(index)
	end)
	UI.Heading(page, "Background", 264, -244)
	UI.Button("Bagnon_Background", page, "Background colour", 264, -270, 208, PickBackground)

	UI.Heading(page, "Behavior", 28, -318)
	local lock = UI.Switch("Bagnon_Lock", page, "Lock position",
		"Stop the window from being dragged.", 28, -342, function(value)
			Sets().locked = value and 1 or nil
		end)
	local stay = UI.Switch("Bagnon_StayOnScreen", page, "Keep on screen",
		"Stop the window from being dragged off the screen.", 28, -378, function(value)
			Sets().stayOnScreen = value and 1 or 0
			Window():SetClampedToScreen(value)
		end)
	local reverse = UI.Switch("Bagnon_Reverse", page, "Reverse bag order",
		"List the bags from the last to the first.", 28, -414, function(value)
			Sets().reverse = value and 1 or nil
			BagnonFrame_OrderBags(Window(), value)
			BagnonFrame_Generate(Window())
		end)

	refresh[2] = function()
		local sets, frame = Sets(), Window()
		selectWindow(selected == "Bagnon" and 1 or 2)
		UI.SetSlider(columns, sets.cols)
		UI.SetSlider(spacing, sets.space)
		UI.SetSlider(scale, math.floor(frame:GetScale() * 100 + 0.5))
		UI.SetSlider(opacity, math.floor(sets.alpha * 100 + 0.5))
		selectStrata(sets.strata)
		UI.Sync(lock, sets.locked)
		UI.Sync(stay, sets.stayOnScreen == 1)
		UI.Sync(reverse, sets.reverse)
	end
end

local function Create()
	panel = UI.Window("Bagnon_Options", "Bagnon", 500, 380, GetAddOnMetadata(addonName, "Version"))
	local pages
	pages, ShowTab = UI.Tabs(panel, "Bagnon_", {
		{ label = "General", height = 490 },
		{ label = "Windows", height = 470 },
	}, function(index)
		refresh[index]()
	end)
	BuildGeneral(pages[1])
	BuildWindows(pages[2])
end

-- Open the settings. With a window name (the title was right-clicked), show that window's layout.
function BagnonOptions_Open(windowName)
	if not panel then Create() end
	if windowName then selected = windowName end
	panel:Show()
	ShowTab(windowName and 2 or 1)
end

function BagnonOptions_Toggle()
	if panel and panel:IsShown() then
		panel:Hide()
	else
		BagnonOptions_Open()
	end
end

-- Game Menu > AddOn Options > Bagnon (ClassicAPI).
local entry = CreateFrame("Frame", "BagnonOptionsEntry")
entry.name = "Bagnon"
local entryTitle = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
entryTitle:SetPoint("TOPLEFT", entry, "TOPLEFT", 16, -16)
entryTitle:SetText("Bagnon")
local entryText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
entryText:SetPoint("TOPLEFT", entryTitle, "BOTTOMLEFT", 0, -8)
entryText:SetWidth(380)
entryText:SetJustifyH("LEFT")
entryText:SetText("One bag window for your bags and bank. Type /bagnon to open the settings at any time.")
local entryOpen = CreateFrame("Button", "BagnonOptionsEntryOpen", entry, "UIPanelButtonTemplate")
entryOpen:SetWidth(172); entryOpen:SetHeight(22)
entryOpen:SetPoint("TOPLEFT", entry, "TOPLEFT", 16, -80)
entryOpen:SetText("Open settings")
entryOpen:SetScript("OnClick", function()
    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
    if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
    BagnonOptions_Open()
end)
InterfaceOptions_AddCategory(entry)
