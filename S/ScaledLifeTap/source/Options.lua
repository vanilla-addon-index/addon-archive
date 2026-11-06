-- ScaledLifeTap 4.2 - options window
--
-- With ClassicAPI, the pages are added to its AddOn Options window (game menu
-- -> AddOn Options -> ScaledLifeTap), following the same conventions as
-- ClassicAPI's own page: changes apply at once, Cancel/Escape restores what
-- the page held when it was opened, Defaults restores the defaults.
--
-- Without ClassicAPI, /slt options shows the same settings page in a small
-- standalone window.
--
-- Lua 5.0 / 1.12 API only: no `...` expressions, no select(), handlers use `this`.

local SLT = ScaledLifeTap
local VERSION = type(GetAddOnMetadata) == "function" and GetAddOnMetadata("ScaledLifeTap", "Version") or "4.2"

local T = {
	ABOUT = "Casts the highest Life Tap rank that fits into your missing mana. Put |cffffffff/slt cast|r in a macro.",
	OVERTAP = "Overtap",
	OVERTAP_TIP = "When no rank fits but your mana isn't full, cast rank 1 anyway. Some mana is wasted, but you get it when you need it.",
	CALIBRATE = "Mana check",
	CALIBRATE_TIP = "Compares the mana each Life Tap actually gives with the prediction and adjusts if your server's numbers differ. Needs Nampower or ClassicAPI.",
	CALIBRATE_RESET = "Reset",
	CALIBRATE_RESET_TIP = "Forget what the mana check has learned.",
	DEBUG = "Show each cast in chat",
	DEBUG_TIP = "Prints the rank, health cost and mana gained every time Life Tap is cast.",
	MACRO_DISPLAY = "Show rank on macro button",
	MACRO_DISPLAY_TIP = "Macros that contain /slt cast show the Life Tap rank that would be cast right now. Needs ClassicAPI.",
	RESERVE = "Health reserve (%)",
	RESERVE_TIP = "Never tap below this percentage of your maximum health. 0 means only the health the tap itself needs.",
	SOURCE = "Spell damage source",
	SOURCE_TIP = "Where your shadow spell damage comes from. Automatic uses ClassicAPI, then Nampower, then the built-in gear scanner.",
	SOURCE_AUTO = "Automatic",
	NOT_RUNNING = " (not running)",
	BONUS = "Extra spell damage",
	BONUS_TIP = "Added on top of the measured spell damage. Only needed with the built-in scanner, for buffs it can't see (elixirs, flasks). ClassicAPI and Nampower already include buffs.",
	RESCAN = "Rescan",
	RESCAN_TIP = "Read your gear, spellbook and talents again.",
	RANKS = "Ranks",
	RANKS_ABOUT = "What each rank would cost and give right now.",
}

local SOURCE_KEYS = { "auto", "classicapi", "nampower", "internal", "bonusscanner" }

-- ---------------------------------------------------------------------------
-- settings over SLT_Config
-- ---------------------------------------------------------------------------
local function ConfigSetting(key, after)
	return {
		get = function() return SLT_Config[key] end,
		set = function(value) SLT_Config[key] = value; if after then after() end end,
		reset = function() SLT_Config[key] = SLT.DEFAULTS[key]; if after then after() end end,
	}
end

-- ---------------------------------------------------------------------------
-- page building (same layout conventions as ClassicAPI's Options/Panel.lua)
-- ---------------------------------------------------------------------------
local numControls = 0
local function NextName()
	numControls = numControls + 1
	return "ScaledLifeTapOptionsControl" .. numControls
end

local function RefreshControls(page)
	page.updating = true
	for _, control in ipairs(page.controls) do control:Update() end
	if page.OnRefresh then page.OnRefresh() end
	page.updating = nil
end

local function NewPage(name, parent, title, subtitle)
	local page = CreateFrame("Frame")
	page.name = name
	page.parent = parent
	page.controls = {}

	local heading = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -16)
	heading:SetText(title)
	page.y = -40
	if subtitle then
		local text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		text:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
		text:SetPoint("RIGHT", page, "RIGHT", -32, 0)
		text:SetJustifyH("LEFT")
		text:SetText(subtitle)
		page.y = -64
	end

	page.refresh = function()
		if not page.saved then
			page.saved = {}
			for i, control in ipairs(page.controls) do
				if control.setting then page.saved[i] = control.setting.get() end
			end
		end
		RefreshControls(page)
	end
	page.okay = function() page.saved = nil end
	page.cancel = function()
		if not page.saved then return end
		for i, control in ipairs(page.controls) do
			if control.setting and control.setting.get() ~= page.saved[i] then
				control.setting.set(page.saved[i])
			end
		end
		page.saved = nil
	end
	page.default = function()
		for _, control in ipairs(page.controls) do
			if control.setting then control.setting.reset() end
		end
		RefreshControls(page)
	end
	page:SetScript("OnShow", function() page.refresh() end)
	return page
end

local function AddControl(page, control, setting, height)
	control.setting = setting
	table.insert(page.controls, control)
	page.y = page.y - height
end

local function SetTooltip(frame, text)
	frame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, nil, nil, nil, nil, 1)
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- `enabledIf`, when given, greys the checkbox out while it returns false.
local function AddCheckbox(page, label, tooltip, setting, enabledIf)
	local check = CreateFrame("CheckButton", NextName(), page, "OptionsCheckButtonTemplate")
	check:SetPoint("TOPLEFT", page, "TOPLEFT", 16, page.y)
	local text = getglobal(check:GetName() .. "Text")
	if text then text:SetText(label) end
	check.tooltipText = tooltip
	check:SetScript("OnClick", function()
		this.setting.set(this:GetChecked() and true or false)
		RefreshControls(page)
	end)
	check.Update = function(self)
		self:SetChecked(self.setting.get() and 1 or nil)
		local on = not enabledIf or enabledIf()
		if on then self:Enable() else self:Disable() end
		if text then
			local c = on and NORMAL_FONT_COLOR or GRAY_FONT_COLOR
			text:SetTextColor(c.r, c.g, c.b)
		end
	end
	AddControl(page, check, setting, 30)
	return check
end

local function AddSlider(page, label, tooltip, setting, minValue, maxValue, step, enabledIf)
	local slider = CreateFrame("Slider", NextName(), page, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", page, "TOPLEFT", 24, page.y - 20)
	slider:SetWidth(200)
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(step)
	slider.tooltipText = tooltip
	local title = getglobal(slider:GetName() .. "Text")
	if title then title:SetText(label) end
	local low, high = getglobal(slider:GetName() .. "Low"), getglobal(slider:GetName() .. "High")
	if low then low:SetText(minValue) end
	if high then high:SetText(maxValue) end

	local value = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	value:SetPoint("LEFT", slider, "RIGHT", 8, 0)

	slider:SetScript("OnValueChanged", function()
		local v = math.floor(this:GetValue() / step + 0.5) * step
		value:SetText(v)
		if not page.updating and v ~= this.setting.get() then
			this.setting.set(v)
			if page.OnRefresh then page.OnRefresh() end
		end
	end)
	slider.Update = function(self)
		local v = self.setting.get() or 0
		self:SetValue(v)
		value:SetText(v)
		if title then
			local c = (not enabledIf or enabledIf()) and NORMAL_FONT_COLOR or GRAY_FONT_COLOR
			title:SetTextColor(c.r, c.g, c.b)
		end
	end
	AddControl(page, slider, setting, 56)
	return slider
end

-- `options()` returns the entries as { value = ..., text = ... }.
local function AddDropDown(page, label, tooltip, setting, options)
	local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	title:SetPoint("TOPLEFT", page, "TOPLEFT", 20, page.y - 6)
	title:SetText(label)

	local dropdown = CreateFrame("Frame", NextName(), page, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y - 20)
	UIDropDownMenu_SetWidth(180, dropdown)
	dropdown:EnableMouse(true)
	SetTooltip(dropdown, tooltip)

	local function Initialize()
		local selected = setting.get()
		for _, option in ipairs(options()) do
			local info = {}
			info.text = option.text
			info.value = option.value
			info.checked = option.value == selected and 1 or nil
			info.func = function()
				UIDropDownMenu_SetSelectedValue(dropdown, this.value)
				setting.set(this.value)
				RefreshControls(page)
			end
			UIDropDownMenu_AddButton(info)
		end
	end
	dropdown.Update = function(self)
		UIDropDownMenu_Initialize(self, Initialize)
		UIDropDownMenu_SetSelectedValue(self, setting.get())
	end
	AddControl(page, dropdown, setting, 56)
	return dropdown
end

local function AddButton(page, label, tooltip, onClick, x, y, width)
	local button = CreateFrame("Button", NextName(), page, "UIPanelButtonTemplate")
	button:SetWidth(width or 96)
	button:SetHeight(22)
	button:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	button:SetText(label)
	button:SetScript("OnClick", onClick)
	SetTooltip(button, tooltip)
	return button
end

-- A block of left-aligned text lines that the page fills on refresh.
local function AddText(page, numLines)
	local text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	text:SetPoint("TOPLEFT", page, "TOPLEFT", 20, page.y - 8)
	text:SetPoint("RIGHT", page, "RIGHT", -20, 0)
	text:SetJustifyH("LEFT")
	page.y = page.y - 8 - 14 * numLines
	return text
end

local function JoinLines(lines)
	return table.concat(lines, "\n")
end

-- ---------------------------------------------------------------------------
-- main page
-- ---------------------------------------------------------------------------
local main = NewPage("ScaledLifeTap", nil, "ScaledLifeTap " .. VERSION, T.ABOUT)

AddCheckbox(main, T.OVERTAP, T.OVERTAP_TIP, ConfigSetting("overtap"))
local calibrate = AddCheckbox(main, T.CALIBRATE, T.CALIBRATE_TIP, ConfigSetting("calibrate"), SLT.CanCalibrate)
AddButton(main, T.CALIBRATE_RESET, T.CALIBRATE_RESET_TIP, function()
	SLT.ResetCalibration()
	RefreshControls(main)
end, 220, main.y + 30 - 4, 80)
AddCheckbox(main, T.MACRO_DISPLAY, T.MACRO_DISPLAY_TIP, ConfigSetting("macroDisplay", SLT.RefreshMacroDisplay), SLT.CanMacroDisplay)
AddCheckbox(main, T.DEBUG, T.DEBUG_TIP, ConfigSetting("debug"))
AddSlider(main, T.RESERVE, T.RESERVE_TIP, ConfigSetting("reserve"), 0, 90, 5)
AddDropDown(main, T.SOURCE, T.SOURCE_TIP, ConfigSetting("source", SLT.Rescan), function()
	local list = {}
	for _, key in ipairs(SOURCE_KEYS) do
		local text = key == "auto" and T.SOURCE_AUTO or SLT.SourceNames[key]
		if not SLT.IsSourceAvailable(key) then text = text .. T.NOT_RUNNING end
		table.insert(list, { value = key, text = text })
	end
	return list
end)
AddSlider(main, T.BONUS, T.BONUS_TIP, ConfigSetting("bonus"), 0, 300, 5,
	function() return not SLT.IsLiveSource() end)

local summary = AddText(main, 3)
AddButton(main, T.RESCAN, T.RESCAN_TIP, function()
	SLT.Rescan()
	RefreshControls(main)
end, 16, main.y - 6)

main.OnRefresh = function()
	local lines = SLT.StatusLines()
	summary:SetText(JoinLines(lines))
end

-- ---------------------------------------------------------------------------
-- ranks page (ClassicAPI window only)
-- ---------------------------------------------------------------------------
local ranksPage = NewPage(T.RANKS, main.name, T.RANKS, T.RANKS_ABOUT)
local ranksText = AddText(ranksPage, 8)
AddButton(ranksPage, T.RESCAN, T.RESCAN_TIP, function()
	SLT.Rescan()
	RefreshControls(ranksPage)
end, 16, ranksPage.y - 6)
ranksPage.OnRefresh = function()
	local _, ranks = SLT.StatusLines()
	ranksText:SetText(JoinLines(ranks))
end

-- ---------------------------------------------------------------------------
-- registration
-- ---------------------------------------------------------------------------
local standalone

local function ShowStandalone()
	if not standalone then
		standalone = CreateFrame("Frame", "ScaledLifeTapOptionsWindow", UIParent)
		standalone:SetWidth(420)
		standalone:SetHeight(500)
		standalone:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		standalone:SetFrameStrata("DIALOG")
		standalone:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
		standalone:EnableMouse(true)
		standalone:SetMovable(true)
		standalone:RegisterForDrag("LeftButton")
		standalone:SetScript("OnDragStart", function() this:StartMoving() end)
		standalone:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
		local close = CreateFrame("Button", "ScaledLifeTapOptionsWindowClose", standalone, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", standalone, "TOPRIGHT", -6, -6)
		table.insert(UISpecialFrames, "ScaledLifeTapOptionsWindow")   -- Escape closes it
		main:SetParent(standalone)
		main:ClearAllPoints()
		main:SetPoint("TOPLEFT", standalone, "TOPLEFT", 8, -8)
		main:SetPoint("BOTTOMRIGHT", standalone, "BOTTOMRIGHT", -8, 8)
		standalone:Hide()
	end
	if standalone:IsShown() then
		standalone:Hide()
	else
		standalone:Show()
		main:Show()
		main.saved = nil
		main.refresh()
	end
end

if type(InterfaceOptions_AddCategory) == "function" then
	InterfaceOptions_AddCategory(main)
	InterfaceOptions_AddCategory(ranksPage)
	SLT.OpenOptions = function() InterfaceOptionsFrame_OpenToCategory(main) end
else
	main:Hide()
	ranksPage:Hide()
	SLT.OpenOptions = ShowStandalone
end
SLT.OptionsPage = main
SLT.RanksPage = ranksPage
