-- Settings remain usable through /tfb on unmodified 1.12 clients.
TargetFrameBuffDefaults = {
	timers = true, highlight = true, sweeps = false, timerSize = 9, warning = 5,
	maxBuffs = 32, maxDebuffs = 16
};

local function RefreshAuras()
	if (TargetFrameBuff_Update and TargetFrameBuff1) then
		TargetFrameBuff_Update();
	end
end

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100TargetFrameBuff:|r "..message);
end

local function Validate()
	if (type(TargetFrameBuffDB) ~= "table") then TargetFrameBuffDB = {}; end
	for key, value in pairs(TargetFrameBuffDefaults) do
		if (type(TargetFrameBuffDB[key]) ~= type(value)) then TargetFrameBuffDB[key] = value; end
	end
	if (TargetFrameBuffDB.timerSize ~= TargetFrameBuffDB.timerSize or TargetFrameBuffDB.timerSize < 6 or TargetFrameBuffDB.timerSize > 20) then
		TargetFrameBuffDB.timerSize = 9;
	end
	if (TargetFrameBuffDB.warning ~= TargetFrameBuffDB.warning or TargetFrameBuffDB.warning < 0 or TargetFrameBuffDB.warning > 30) then
		TargetFrameBuffDB.warning = 5;
	end
	if (TargetFrameBuffDB.maxBuffs ~= TargetFrameBuffDB.maxBuffs or TargetFrameBuffDB.maxBuffs < 0 or TargetFrameBuffDB.maxBuffs > 32) then
		TargetFrameBuffDB.maxBuffs = 32;
	end
	if (TargetFrameBuffDB.maxDebuffs ~= TargetFrameBuffDB.maxDebuffs or TargetFrameBuffDB.maxDebuffs < 0 or TargetFrameBuffDB.maxDebuffs > 16) then
		TargetFrameBuffDB.maxDebuffs = 16;
	end
end

local panel;
local function CreateOptions()
	if (panel or not InterfaceOptions_AddCategory) then return; end
	panel = CreateFrame("Frame", "TargetFrameBuffOptions", UIParent);
	panel.name = "TargetFrameBuff";
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16);
	title:SetText("TargetFrameBuff");
	local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12);
	note:SetText("ClassicAPI features. Sweeps work best with ClassicAPI 1.17.1 or newer.");
	local checks = {};
	local labels = {"Show countdown text", "Highlight enemy buffs you can remove", "Show cooldown sweeps"};
	local keys = {"timers", "highlight", "sweeps"};
	for i = 1, 3 do
		local check = CreateFrame("CheckButton", "TargetFrameBuffOption"..i, panel, "UICheckButtonTemplate");
		check:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -65 - (i - 1) * 32);
		check.key = keys[i];
		getglobal(check:GetName().."Text"):SetText(labels[i]);
		check:SetScript("OnClick", function()
			TargetFrameBuffDB[this.key] = this:GetChecked() and true or false;
			RefreshAuras();
		end);
		checks[i] = check;
	end
	local sliders = {};
	local sliderKeys = {"timerSize", "warning", "maxBuffs", "maxDebuffs"};
	local sliderLabels = {"Timer font size", "Warning threshold (seconds)", "Max buffs shown", "Max debuffs shown"};
	local sliderMin = {6, 0, 0, 0};
	local sliderMax = {20, 30, 32, 16};
	for i = 1, 4 do
		local slider = CreateFrame("Slider", "TargetFrameBuffSlider"..i, panel, "OptionsSliderTemplate");
		slider:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -190 - (i - 1) * 65);
		slider:SetWidth(240);
		slider:SetMinMaxValues(sliderMin[i], sliderMax[i]);
		slider:SetValueStep(1);
		slider.key = sliderKeys[i];
		slider.label = sliderLabels[i];
		getglobal(slider:GetName().."Low"):SetText(sliderMin[i]);
		getglobal(slider:GetName().."High"):SetText(sliderMax[i]);
		slider:SetScript("OnValueChanged", function()
			local value = math.floor(this:GetValue() + 0.5);
			TargetFrameBuffDB[this.key] = value;
			getglobal(this:GetName().."Text"):SetText(this.label..": "..value);
			RefreshAuras();
		end);
		sliders[i] = slider;
	end
	local testButton = CreateFrame("Button", "TargetFrameBuffTestButton", panel, "UIPanelButtonTemplate");
	testButton:SetWidth(180);
	testButton:SetHeight(22);
	testButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -450);
	testButton:SetText("Toggle test auras");
	testButton:SetScript("OnClick", function()
		TargetFrameBuff_SetTest(not TargetFrameBuff_IsTest());
	end);
	local saved = {};
	local function Sync()
		for i = 1, 3 do checks[i]:SetChecked(TargetFrameBuffDB[checks[i].key]); end
		for i = 1, 4 do
			sliders[i]:SetValue(TargetFrameBuffDB[sliders[i].key]);
			getglobal(sliders[i]:GetName().."Text"):SetText(sliders[i].label..": "..TargetFrameBuffDB[sliders[i].key]);
		end
	end
	panel.refresh = function()
		for key in pairs(TargetFrameBuffDefaults) do saved[key] = TargetFrameBuffDB[key]; end
		Sync();
	end;
	panel.cancel = function()
		for key, value in pairs(saved) do TargetFrameBuffDB[key] = value; end
		Sync();
		RefreshAuras();
	end;
	panel.default = function()
		for key, value in pairs(TargetFrameBuffDefaults) do TargetFrameBuffDB[key] = value; end
		Sync();
		RefreshAuras();
	end;
	InterfaceOptions_AddCategory(panel);
end

-- command -> saved key, minimum, maximum
local NUMBER_OPTIONS = {
	size = {"timerSize", 6, 20}, warning = {"warning", 0, 30},
	buffs = {"maxBuffs", 0, 32}, debuffs = {"maxDebuffs", 0, 16}
};

SLASH_TARGETFRAMEBUFF1 = "/tfb";
SlashCmdList["TARGETFRAMEBUFF"] = function(message)
	Validate();
	local _, _, command, value = string.find(string.lower(message or ""), "^%s*(%S*)%s*(.-)%s*$");
	if (command == "timers" or command == "highlight" or command == "sweeps") then
		if (value == "on") then TargetFrameBuffDB[command] = true;
		elseif (value == "off") then TargetFrameBuffDB[command] = false;
		elseif (value == "") then TargetFrameBuffDB[command] = not TargetFrameBuffDB[command];
		else Print("Use on or off."); return; end
		Print(command..": "..(TargetFrameBuffDB[command] and "on" or "off"));
	elseif (NUMBER_OPTIONS[command]) then
		local number = tonumber(value);
		local key, min, max = NUMBER_OPTIONS[command][1], NUMBER_OPTIONS[command][2], NUMBER_OPTIONS[command][3];
		if (not number or number < min or number > max) then
			Print("Choose a number from "..min.." to "..max.."."); return;
		end
		TargetFrameBuffDB[key] = math.floor(number + 0.5);
		Print(command..": "..TargetFrameBuffDB[key]);
	elseif (command == "test") then
		local _, _, buffs, debuffs = string.find(value, "^(%d+)%s*(%d*)$");
		local on;
		if (value == "off") then on = false;
		elseif (value == "" ) then on = not TargetFrameBuff_IsTest();
		elseif (value == "on" or buffs) then on = true;
		else Print("Use /tfb test [on or off] or /tfb test <buffs> <debuffs>."); return; end
		local _, nb, nd = TargetFrameBuff_SetTest(on, tonumber(buffs), tonumber(debuffs));
		Print("test auras: "..(on and ("on ("..nb.." buffs, "..nd.." debuffs). Needs a target; /tfb test turns it off.") or "off"));
	elseif (command == "reset") then
		TargetFrameBuffDB = nil;
		Validate();
	elseif (command == "" and InterfaceOptionsFrame_OpenToCategory) then
		CreateOptions();
		InterfaceOptionsFrame_OpenToCategory(panel);
	else
		Print("/tfb timers, highlight or sweeps [on or off], /tfb size 6-20, /tfb warning 0-30, /tfb buffs 0-32, /tfb debuffs 0-16, /tfb test [buffs debuffs], /tfb reset");
		return;
	end
	RefreshAuras();
end;

local loader = CreateFrame("Frame");
loader:RegisterEvent("ADDON_LOADED");
loader:SetScript("OnEvent", function()
	if (arg1 == "TargetFrameBuff") then
		Validate();
		CreateOptions();
		RefreshAuras();
		this:UnregisterEvent("ADDON_LOADED");
	end
end);
