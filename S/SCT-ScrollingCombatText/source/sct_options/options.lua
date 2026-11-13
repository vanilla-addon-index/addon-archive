--The Options Page functions

SCT.OptionFrames = { ["SCTOptionsFrame_Misc21"] = "SCTOptions_EventsFrame",
										 ["SCTOptionsFrame_Misc18"] = "SCTOptions_FramesFrame", 
										 ["SCTOptionsFrame_Misc19"] = "SCTOptions_SpellFrame",
										 ["SCTOptionsFrame_Misc16"] = "SCTOptions_AnimationFrame",
										 ["SCTOptionsFrame_Misc10"] = "SCTOptions_SaveLoadFrame"};
										 
SCT.OptionFrameFrames = { ["SCTOptionsFrame_Misc14"] = {frame="SCTOptions_TextFrame", example="SCTaniExampleData1"},
										 			["SCTOptionsFrame_Misc20"] = {frame="SCTOptions_TextFrame", example="SCTaniExampleData2"}, 
										 			["SCTOptionsFrame_Misc15"] = {frame="SCTOptions_MessageFrame", example="SCTMsgExample1"}};

------------------------------
--Copy values from table that are nil in another. 
--Taken from AceDB. Using till AceDB support character to character
local function inheritDefaults(t, defaults)
	for k,v in pairs(defaults) do
		if type(v) == "table" then
			if type(t[k]) ~= "table" then
				t[k] = {}
			end
			inheritDefaults(t[k], v)
		elseif t[k] == nil then
			t[k] = v
		end
	end
	return t
end

------------------------------
--Copy table to table
--Taken from AceDB. Using till AceDB support character to character
local function copyTable(to, from)
	setmetatable(to, nil)
	for k,v in pairs(from) do
		if type(k) == "table" then
			k = copyTable({}, k)
		end
		if type(v) == "table" then
			v = copyTable({}, v)
		end
		to[k] = v
	end
	setmetatable(to, from)
	return to
end

----------------------
--Called when option page loads
function SCT:OptionsFrame_OnShow()
	local option1, option2, option3, option4, option5, string, getvalue;
	--Misc Options
	for key, value in pairs(SCT.OPTIONS.FrameMisc) do
		string = getglobal("SCTOptionsFrame_Misc"..value.index);
		if (string) then
			string:SetText(key);
			if (value.tooltipText) then
				string.tooltipText = value.tooltipText;
			end
		end
	end
	
	local frame, swatch, sColor;
	-- Set Options values
	for key, value in pairs(SCT.OPTIONS.FrameEventFrames) do
		option1 = getglobal("SCTOptionsFrame"..value.index.."_CheckButton");
		option2 = getglobal("SCTOptionsFrame"..value.index.."_CritCheckButton");
		option3 = getglobal("SCTOptionsFrame"..value.index.."_RadioMsgButton");
		option4 = getglobal("SCTOptionsFrame"..value.index.."_RadioFrame1Button");
		option5 = getglobal("SCTOptionsFrame"..value.index.."_RadioFrame2Button");
		string = getglobal("SCTOptionsFrame"..value.index.."_CheckButtonText");
		
		--main check
		option1.SCTVar = value.SCTVar;
		option1:SetChecked(self.db.profile[value.SCTVar]);
		option1.tooltipText = value.tooltipText;
		string:SetText(key);
		
		--crit check
		option2.SCTVar = value.SCTVar;
		option2:SetChecked(self.db.profile[self.CRITS_TABLE][value.SCTVar]);
		option2.tooltipText = SCT.LOCALS.Option_Crit_Tip;
		
		--radios
		option3.tooltipText = SCT.LOCALS.Option_Msg_Tip;
		option4.tooltipText = SCT.LOCALS.Frame1_Tip;
		option5.tooltipText = SCT.LOCALS.Frame2_Tip;
		self:OptionsRadioButtonOnClick(self.db.profile[self.FRAMES_TABLE][value.SCTVar],"SCTOptionsFrame"..value.index)
		--set vars after setting up radios, so no redundant saving.
		option3.SCTVar = value.SCTVar;
		option4.SCTVar = value.SCTVar;
		option5.SCTVar = value.SCTVar;
		
		--Color Swatch		
		frame = getglobal("SCTOptionsFrame"..value.index);
		swatch = getglobal("SCTOptionsFrame"..value.index.."_ColorSwatchNormalTexture");
		sColor = self.db.profile[self.COLORS_TABLE][value.SCTVar];
		frame.r = sColor.r;
		frame.g = sColor.g;
		frame.b = sColor.b;
		local k = value.SCTVar;
		local s = swatch:GetName();
		local f = frame:GetName();
		local t = self.COLORS_TABLE
		frame.swatchFunc = function() self:OptionsFrame_SetColor(f, s, k, t) end;
		frame.cancelFunc = function(x) self:OptionsFrame_CancelColor(f, s, k, t, x) end;
		swatch:SetVertexColor(sColor.r,sColor.g,sColor.b);
	end
	
	-- Set CheckButton states
	for key, value in pairs(SCT.OPTIONS.FrameCheckButtons) do
		option1 = getglobal("SCTOptionsFrame_CheckButton"..value.index);
		string = getglobal("SCTOptionsFrame_CheckButton"..value.index.."Text");
		option1.SCTVar = value.SCTVar;
		option1.SCTTable = value.SCTTable;
		if (option1.SCTTable) then
			option1:SetChecked(self.db.profile[SCT.FRAMES_DATA_TABLE][option1.SCTTable][value.SCTVar]);
		else
			option1:SetChecked(self.db.profile[value.SCTVar]);
		end
		option1.tooltipText = value.tooltipText;
		string:SetText(key);
	end
	
	--Set Sliders
	for key, value in pairs(SCT.OPTIONS.FrameSliders) do
		option1 = getglobal("SCTOptionsFrame_Slider"..value.index.."Slider");
		string = getglobal("SCTOptionsFrame_Slider"..value.index.."SliderText");
		option2 = getglobal("SCTOptionsFrame_Slider"..value.index.."SliderLow");
		option3 = getglobal("SCTOptionsFrame_Slider"..value.index.."SliderHigh");
		option4 = getglobal("SCTOptionsFrame_Slider"..value.index.."EditBox");
		option1.SCTVar = value.SCTVar;
		option1.SCTTable = value.SCTTable;
		if (option1.SCTTable) then
			getvalue = self.db.profile[SCT.FRAMES_DATA_TABLE][option1.SCTTable][value.SCTVar];
		else
			getvalue = self.db.profile[value.SCTVar];
		end
		option1.SCTLabel = key;
		option1:SetMinMaxValues(value.minValue, value.maxValue);
		option1:SetValueStep(value.valueStep);
		option1.tooltipText = value.tooltipText;
		string:SetText(key);
		option4:SetText(getvalue)
		option2:SetText(value.minText);
		option3:SetText(value.maxText);
		--set value based on type
		if (option4:GetObjectType() == "EditBox") then
			self:OptionsEditBoxOnValueChanged(option4)
		else
			option1:SetValue(getvalue);
		end
	end
		
	--Dropdowns
	for key, value in pairs(SCT.OPTIONS.FrameSelections) do
		option1 = getglobal("SCTOptionsFrame_Selection"..value.index);
		option2 = getglobal("SCTOptionsFrame_Selection"..value.index.."Label");
		option1.SCTVar = value.SCTVar;
		option1.SCTTable = value.SCTTable;
		option1.SCTValueSave = value.SCTValueSave;
		--lookup table cause of WoW's crappy dropdown UI.
		option1.lookup = value.table;
		if (option1.SCTTable) then
			getvalue = self.db.profile[SCT.FRAMES_DATA_TABLE][option1.SCTTable][value.SCTVar];
		else
			getvalue = self.db.profile[value.SCTVar];
		end
		if (value.SCTValueSave) then
			UIDropDownMenu_SetSelectedValue(option1, getvalue);
			--not sure why I have to do this, but only way to make it show correctly cause of WoW's crappy dropdown UI.
			UIDropDownMenu_SetText(getvalue, option1);
		else
			UIDropDownMenu_SetSelectedID(option1, getvalue);
			--not sure why I have to do this, but only way to make it show correctly cause of WoW's crappy dropdown UI.
			UIDropDownMenu_SetText(value.table[getvalue], option1);
		end
		option1.tooltipText = value.tooltipText;
		option2:SetText(key);
	end
	
	--Colors
	for key, value in pairs(SCT.OPTIONS.FrameColors) do
		frame = getglobal("SCTOptionsFrame_Color"..value.index);
		string = getglobal("SCTOptionsFrame_Color"..value.index.."_Label");
		swatch = getglobal("SCTOptionsFrame_Color"..value.index.."NormalTexture");
		sColor = self.db.profile[self.SPELL_COLORS_TABLE][value.SCTVar];
		frame.r = sColor.r;
		frame.g = sColor.g;
		frame.b = sColor.b;
		local k = value.SCTVar;
		local s = swatch:GetName();
		local f = frame:GetName();
		local t = self.SPELL_COLORS_TABLE
		frame.swatchFunc = function() self:OptionsFrame_SetColor(f, s, k, t) end;
		frame.cancelFunc = function(x) self:OptionsFrame_CancelColor(f, s, k, t, x) end;
		swatch:SetVertexColor(sColor.r,sColor.g,sColor.b);
		string:SetText(key);
	end
	
	--simulate click on tab1
	self:ToggleTab("SCTOptions_EventsFrame")
	--set sticky mode
	self:ChangeStickyMode(SCT.db.profile["STICKYCRIT"]);
	--Update Profiles	
	self:ScrollBar_Update();	
end

----------------------
--Sets the colors of the config from a color swatch
function SCT:OptionsFrame_SetColor(f,s,k,t)
	local r,g,b = ColorPickerFrame:GetColorRGB();
	local color={};
	local swatch = getglobal(s);
	local frame = getglobal(f);
	swatch:SetVertexColor(r,g,b);
	frame.r, frame.g, frame.b = r,g,b;
	color.r, color.g, color.b = r,g,b;
	--update back to config
	self.db.profile[t][k] = color;
end

----------------------
-- Cancels the color selection
function SCT:OptionsFrame_CancelColor(f,s,k,t,prev)
	local r,g,b = prev.r, prev.g, prev.b;
	local color={};
	local swatch = getglobal(s);
	local frame = getglobal(f);
	swatch:SetVertexColor(r, g, b);
	frame.r, frame.g, frame.b = r,g,b;
	color.r, color.g, color.b = r,g,b;
	-- Update back to config
	self.db.profile[t][k] = color;
end

----------------------
--Sets the silder values in the config
function SCT:OptionsSliderOnValueChanged()
	local string, editbox;
	string = getglobal(this:GetName().."Text");
	editbox = getglobal(this:GetParent():GetName().."EditBox");
	string:SetText(this.SCTLabel);
	editbox:SetText(this:GetValue())
	if (this.SCTTable) then
		self.db.profile[SCT.FRAMES_DATA_TABLE][this.SCTTable][this.SCTVar] = this:GetValue();
	else
		self.db.profile[this.SCTVar] = this:GetValue();
	end
	--update Example
	self:ShowExample();
end

----------------------
--Sets the silder values in the config
function SCT:OptionsEditBoxOnValueChanged(obj)
	local slider = getglobal(obj:GetParent():GetName().."Slider");
	local getvalue = tonumber(obj:GetText());
	if (slider.SCTTable) then
		self.db.profile[SCT.FRAMES_DATA_TABLE][slider.SCTTable][slider.SCTVar] = getvalue;
	else
		self.db.profile[slider.SCTVar] = getvalue;
	end
	-- disable update change,set slider,setonchance back
	slider:SetScript("OnValueChanged", nil);
	slider:SetValue(getvalue);
	slider:SetScript("OnValueChanged", function() SCT:OptionsSliderOnValueChanged() end);
	--update Example
	self:ShowExample();
end

----------------------
--Sets the checkbox values in the config
function SCT:OptionsCheckButtonOnClick()
	if (string.find(this:GetName(), "_CritCheckButton")) then 
		self.db.profile[self.CRITS_TABLE][this.SCTVar] = this:GetChecked() or false;
	else
		if (this.SCTTable) then
			self.db.profile[SCT.FRAMES_DATA_TABLE][this.SCTTable][this.SCTVar] = this:GetChecked() or false;
		else
			self.db.profile[this.SCTVar] = this:GetChecked() or false;
		end
	end
	--update Example
	self:ShowExample();
end

----------------------
--Sets the checkbox values in the config
function SCT:OptionsRadioButtonOnClick(id,parent)
	local frame1 = getglobal(parent.."_RadioFrame1Button");
	local frame2 = getglobal(parent.."_RadioFrame2Button");
	local msg = getglobal(parent.."_RadioMsgButton");
	--set radio button options based on what was clicked.
	if (id==SCT.FRAME1) then
		frame1:SetButtonState("NORMAL", true);
		frame1:SetChecked(true);
		frame2:SetChecked(nil);
		frame2:SetButtonState("NORMAL", false);
		msg:SetChecked(nil);
		msg:SetButtonState("NORMAL", false);
	elseif (id==SCT.FRAME2) then 
		frame2:SetButtonState("NORMAL", true);
		frame2:SetChecked(true);
		frame1:SetChecked(nil);
		frame1:SetButtonState("NORMAL", false);
		msg:SetChecked(nil);
		msg:SetButtonState("NORMAL", false);
	elseif (id==SCT.MSG ) then 
		msg:SetButtonState("NORMAL", true);
		msg:SetChecked(true);
		frame1:SetChecked(nil);
		frame1:SetButtonState("NORMAL", false);
		frame2:SetChecked(nil);
		frame2:SetButtonState("NORMAL", false);
	end
	--if it has a var, save it (some don't)
	if (this.SCTVar) then
		self.db.profile[self.FRAMES_TABLE][this.SCTVar] = id;
	end
	--update Example
	self:ShowExample();
end

---------------------
--Init a Dropdown
function SCT:DropDown_Initialize()
	local info, index, value, key;
	for index, value in pairs(SCT.OPTIONS.FrameSelections) do
		if (this:GetName() == "SCTOptionsFrame_Selection"..value.index.."Button") then
           for key=1, table.getn(value.table) do
				info = UIDropDownMenu_CreateInfo();
				info.text = value.table[key];
				info.func = function(x) self:DropDown_OnClick(x) end;
				info.arg1 = value.index;
				UIDropDownMenu_AddButton(info);
			end
			break;
		end
	end
end

---------------------
-- Dropdown Onclick
function SCT:DropDown_OnClick(list)
	local ddl = getglobal("SCTOptionsFrame_Selection"..list);
	local save = this:GetID()
	UIDropDownMenu_SetSelectedID(ddl, this:GetID());
	if (ddl.SCTValueSave) then save = this:GetText() end
	if (ddl.SCTTable) then
		self.db.profile[SCT.FRAMES_DATA_TABLE][ddl.SCTTable][ddl.SCTVar] = save;
	else
		self.db.profile[ddl.SCTVar] = save;
	end
	--update Example
	self:ShowExample();
end

----------------------
--Open the color selector using show/hide
function SCT:SaveList_OnClick()
	local text = getglobal(this:GetName().."_Name"):GetText();
	if (text ~= nil) then
		getglobal("SCTOptionsProfileEditBox"):SetText(text);
	end
end

----------------------
--Open the color selector using show/hide
function SCT:ProfileList_OnClick()
	local text = getglobal(this:GetName().."_Name"):GetText();
	if (text ~= nil) then
		getglobal("SCTOptionsProfileEditBox"):SetText(text);
	end
end

------------------------------
--Copy one profile to another, any type
function SCT:CopyProfile(to, from)
	copyTable(to,inheritDefaults(copyTable({}, from), SCT:GetDefaultConfig()));
	-- self:CheckFonts(); FIXME
	self:HideMenu();
	self:ShowMenu();
end

-----------------------
--Load a profile
function SCT:LoadProfile()
	local editbox = getglobal("SCTOptionsProfileEditBox");
	local profile = editbox:GetText();
	if (profile ~= ""	) then
		self:CopyProfile(self.db.profile, self.db.raw.profiles[profile]);
		editbox:SetText("");
		self:Print(SCT.LOCALS.PROFILE..profile);
	end
end

-----------------------
--Delete a profile
function SCT:DeleteProfile()
	local editbox = getglobal("SCTOptionsProfileEditBox");
	local profile = editbox:GetText();
	
	if (profile ~= "") then
		if (profile == AceLibrary("AceDB-2.0").CHAR_ID) then
			SCT:Reset();
		else
			self.db.raw.profiles[profile] = nil;
			self:Print(SCT.LOCALS.PROFILE_DELETE..profile);
		end
		editbox:SetText("");
		self:ScrollBar_Update()
		self:HideMenu();
		self:ShowMenu();
	end
end

----------------------
--Open the color selector using show/hide
function SCT:OpenColorPicker(button)
	CloseMenus();
	if ( not button ) then
		button = this;
	end
	ColorPickerFrame.func = button.swatchFunc;
	ColorPickerFrame:SetColorRGB(button.r, button.g, button.b);
	ColorPickerFrame.previousValues = {r = button.r, g = button.g, b = button.b, opacity = button.opacity};
	ColorPickerFrame.cancelFunc = button.cancelFunc;
	ColorPickerFrame:Show();
end

----------------------
-- display ddl or chxbox based on type
function SCT:UpdateAnimationOptions()
	--get scroll down checkbox
	local chkbox = getglobal("SCTOptionsFrame_CheckButton4");
	--get anime type dropdown
	local ddl1 = getglobal("SCTOptionsFrame_Selection1");
	--get animside type dropdown
	local ddl2 = getglobal("SCTOptionsFrame_Selection2");
	--get gap distance silder
	local slide = getglobal("SCTOptionsFrame_Slider15");
	--get subframe
	local subframe = getglobal("SCTAnimationSubFrame");
	--get item
	local id = UIDropDownMenu_GetSelectedID(ddl1)
	chkbox:ClearAllPoints();
	chkbox:SetPoint("TOPLEFT", "SCTOptionsFrame_Selection1", "BOTTOMLEFT", 15, 0);
	if (id == 1 or id == 6) then
		chkbox:Show();
		ddl2:Hide();
		slide:Hide();
		subframe:SetHeight(80);
	elseif (id == 7 or id == 8) then
		chkbox:ClearAllPoints();
		chkbox:SetPoint("TOPLEFT", "SCTOptionsFrame_Selection1", "BOTTOMLEFT", 15, -40);
		chkbox:Show();
		ddl2:Show();
		slide:Show();
		subframe:SetHeight(165);
	else
		chkbox:Hide();
		ddl2:Show();
		slide:Hide();
		subframe:SetHeight(90);
	end
end

----------------------
-- update scroll bar settings
function SCT:ScrollBar_Update()
	local i, idx, item, key, value
	local offset = FauxScrollFrame_GetOffset(SCTScrollBar)
	--get table size, getn doesn't work cause not an array
	local size = 0;
	local profiles = {}
	for key, value in SCT:PairsByKeys(SCT.db.raw.profiles) do
		tinsert(profiles, key);
	end
	for key, _ in pairs(profiles) do
			size = size + 1;
	end
	--get update
	FauxScrollFrame_Update(SCTScrollBar, size, 10, 20)
	--loop thru each display item
	for i=1,10 do
		item = getglobal("SCTList"..i.."_Name")
		idx = offset+i
		if idx<=size then
			key, value = next(profiles)
			for j=2,idx do
				key, value = next(profiles, key)
			end
			item:SetText(value);
			item:Show()
		else
			item:Hide()
		end
	end  
end

----------------------
--change tabs
function SCT:OptionTabClick()
	self:ToggleTab(self.OptionFrames[this:GetName()]);
	PlaySound("igCharacterInfoTab");
end

----------------------
--change tabs
function SCT:ToggleTab(frameName)
	local key, value
	for key, value in pairs(self.OptionFrames) do
		if ( value == frameName ) then
			getglobal(value):Show();
			PanelTemplates_SelectTab(getglobal(key));
			getglobal(key):LockHighlight();
		else
			getglobal(value):Hide();
			PanelTemplates_DeselectTab(getglobal(key));
			getglobal(key):UnlockHighlight();
		end	
	end
	SCT_EXAMPLETEXT:Hide();
end

----------------------
--change frame tabs
function SCT:OptionFrameTabClick()
	self:ToggleFrameTab(this:GetName(),self.OptionFrameFrames[this:GetName()].frame);
	PlaySound("igCharacterInfoTab");
end

----------------------
--change frame tabs
function SCT:ToggleFrameTab(tab, frameName)
	local key, value
	for key, value in pairs(self.OptionFrameFrames) do
		if ( key == tab and value.frame == frameName ) then
			getglobal(value.frame):Show();
			getglobal(value.example):SetTextColor(1, 1, 0);
			getglobal(key):LockHighlight();
		else
			getglobal(value.frame):Hide();
			getglobal(value.example):SetTextColor(1, 1, 1);
			getglobal(key):UnlockHighlight();
		end	
	end 
end

----------------------
--change which frame is being used
function SCT:ChangeFrameTab(frame)
	local tab = self.db.profile[SCT.FRAMES_DATA_TABLE][frame];
	--set all tables to selected frame
	SCTOptionsFrame_CheckButton4.SCTTable = frame;
	SCTOptionsFrame_Slider2Slider.SCTTable = frame;
	SCTOptionsFrame_Slider5Slider.SCTTable = frame;
	SCTOptionsFrame_Slider7Slider.SCTTable = frame;
	SCTOptionsFrame_Slider8Slider.SCTTable = frame;
	SCTOptionsFrame_Slider15Slider.SCTTable = frame;
	SCTOptionsFrame_Selection1.SCTTable = frame;
	SCTOptionsFrame_Selection2.SCTTable = frame;
	SCTOptionsFrame_Selection3.SCTTable = frame;
	SCTOptionsFrame_Selection4.SCTTable = frame;
	SCTOptionsFrame_Selection7.SCTTable = frame;
	SCTOptionsFrame_Selection9.SCTTable = frame;
	--update all frame options
	SCTOptionsFrame_CheckButton4:SetChecked(tab[SCTOptionsFrame_CheckButton4.SCTVar]);
	--text slider
	SCTOptionsFrame_Slider2SliderText:SetText(SCTOptionsFrame_Slider2Slider.SCTLabel);
	SCTOptionsFrame_Slider2EditBox:SetText(tab[SCTOptionsFrame_Slider2Slider.SCTVar]);
	SCTOptionsFrame_Slider2Slider:SetValue(tab[SCTOptionsFrame_Slider2Slider.SCTVar]);
	--alpha slider
	SCTOptionsFrame_Slider5SliderText:SetText(SCTOptionsFrame_Slider5Slider.SCTLabel);
	SCTOptionsFrame_Slider5EditBox:SetText(tab[SCTOptionsFrame_Slider5Slider.SCTVar]);
	SCTOptionsFrame_Slider5Slider:SetValue(tab[SCTOptionsFrame_Slider5Slider.SCTVar]);
	--x slider
	SCTOptionsFrame_Slider7SliderText:SetText(SCTOptionsFrame_Slider7Slider.SCTLabel);
	SCTOptionsFrame_Slider7EditBox:SetText(tab[SCTOptionsFrame_Slider7Slider.SCTVar]);
	SCTOptionsFrame_Slider7Slider:SetScript("OnValueChanged", nil);
	SCTOptionsFrame_Slider7Slider:SetValue(tab[SCTOptionsFrame_Slider7Slider.SCTVar]);
	SCTOptionsFrame_Slider7Slider:SetScript("OnValueChanged", function() SCT:OptionsSliderOnValueChanged() end);
	--y slider
	SCTOptionsFrame_Slider8SliderText:SetText(SCTOptionsFrame_Slider8Slider.SCTLabel);
	SCTOptionsFrame_Slider8EditBox:SetText(tab[SCTOptionsFrame_Slider8Slider.SCTVar]);
	SCTOptionsFrame_Slider8Slider:SetScript("OnValueChanged", nil);
	SCTOptionsFrame_Slider8Slider:SetValue(tab[SCTOptionsFrame_Slider8Slider.SCTVar]);
	SCTOptionsFrame_Slider8Slider:SetScript("OnValueChanged", function() SCT:OptionsSliderOnValueChanged() end);
	--gap slider
	SCTOptionsFrame_Slider15SliderText:SetText(SCTOptionsFrame_Slider15Slider.SCTLabel);
	SCTOptionsFrame_Slider15EditBox:SetText(tab[SCTOptionsFrame_Slider15Slider.SCTVar]);
	SCTOptionsFrame_Slider15Slider:SetScript("OnValueChanged", nil);
	SCTOptionsFrame_Slider15Slider:SetValue(tab[SCTOptionsFrame_Slider15Slider.SCTVar]);
	SCTOptionsFrame_Slider15Slider:SetScript("OnValueChanged", function() SCT:OptionsSliderOnValueChanged() end);
	--Selection
	UIDropDownMenu_SetSelectedID(SCTOptionsFrame_Selection1, tab[SCTOptionsFrame_Selection1.SCTVar]);
	UIDropDownMenu_SetText(SCTOptionsFrame_Selection1.lookup[tab[SCTOptionsFrame_Selection1.SCTVar]], SCTOptionsFrame_Selection1);
	UIDropDownMenu_SetSelectedID(SCTOptionsFrame_Selection2, tab[SCTOptionsFrame_Selection2.SCTVar]);
	UIDropDownMenu_SetText(SCTOptionsFrame_Selection2.lookup[tab[SCTOptionsFrame_Selection2.SCTVar]], SCTOptionsFrame_Selection2);
	UIDropDownMenu_SetSelectedValue(SCTOptionsFrame_Selection3, tab[SCTOptionsFrame_Selection3.SCTVar]);
	UIDropDownMenu_SetText(tab[SCTOptionsFrame_Selection3.SCTVar], SCTOptionsFrame_Selection3);
	UIDropDownMenu_SetSelectedID(SCTOptionsFrame_Selection4, tab[SCTOptionsFrame_Selection4.SCTVar]);
	UIDropDownMenu_SetText(SCTOptionsFrame_Selection4.lookup[tab[SCTOptionsFrame_Selection4.SCTVar]], SCTOptionsFrame_Selection4);
	UIDropDownMenu_SetSelectedID(SCTOptionsFrame_Selection7, tab[SCTOptionsFrame_Selection7.SCTVar]);
	UIDropDownMenu_SetText(SCTOptionsFrame_Selection7.lookup[tab[SCTOptionsFrame_Selection7.SCTVar]], SCTOptionsFrame_Selection7);
	UIDropDownMenu_SetSelectedID(SCTOptionsFrame_Selection9, tab[SCTOptionsFrame_Selection9.SCTVar]);
	UIDropDownMenu_SetText(SCTOptionsFrame_Selection9.lookup[tab[SCTOptionsFrame_Selection9.SCTVar]], SCTOptionsFrame_Selection9);
	--update what is visible
	self:UpdateAnimationOptions();
end

----------------------
--change Sticky Mode
function SCT:ChangeStickyMode(stickyOn)
	if (stickyOn) then
		OptionsFrame_EnableCheckBox(SCTOptionsFrame_CheckButton15);
	else
		OptionsFrame_DisableCheckBox(SCTOptionsFrame_CheckButton15);
	end
end

---------------------
--Show SCT Example
function SCT:ShowExample()
	local example;
	SCT:AniInit();
	
	--animated example for options that may need it
	local option = this.SCTVar;
	if (option) and (string.find(option,"SHOW") == 1) then
		SCT:Display_Event(option, SCT.LOCALS.EXAMPLE);
	end
	
	--show example FRAME1
	--get object
	example = getglobal("SCTaniExampleData1");
	--set text size
	SCT:SetFontSize(example,
									SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.FRAME1]["FONT"],
									SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.FRAME1]["TEXTSIZE"],
									SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.FRAME1]["FONTSHADOW"]);

	--set alpha
	example:SetAlpha(SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.FRAME1]["ALPHA"]/100);
	--Position
	example:SetPoint("CENTER", "UIParent", "CENTER", 
									 SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.FRAME1]["XOFFSET"], 
									 SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.FRAME1]["YOFFSET"]);
	--Set the text to display
	example:SetText(SCT.LOCALS.EXAMPLE);
	
	
	--show example FRAME2
	--get object
	example = getglobal("SCTaniExampleData2");
	--set text size
	SCT:SetFontSize(example,
									SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.FRAME2]["FONT"],
									SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.FRAME2]["TEXTSIZE"],
									SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.FRAME2]["FONTSHADOW"]);

	--set alpha
	example:SetAlpha(SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.FRAME2]["ALPHA"]/100);
	--Position
	example:SetPoint("CENTER", "UIParent", "CENTER", 
									 SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.FRAME2]["XOFFSET"], 
									 SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.FRAME2]["YOFFSET"]);
	--Set the text to display
	example:SetText(SCT.LOCALS.EXAMPLE2);
	
	--get object
	example = getglobal("SCTMsgExample1");
	--set text size
	SCT:SetMsgFont(example);
	--set alpha
	example:SetAlpha(1);
	--Position
	example:SetPoint("CENTER", "UIParent", "CENTER", 
	                 SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.MSG]["MSGXOFFSET"],
	                 SCT.db.profile[SCT.FRAMES_DATA_TABLE][SCT.MSG]["MSGYOFFSET"]-30);
	--Set the text to display
	example:SetText(SCT.LOCALS.MSG_EXAMPLE);
	
	--update animation options
	SCT:UpdateAnimationOptions()
end

---------------------
--Show SCT Test
function SCT:ShowTest()
	local color = {r=1,g=1,b=1}
	SCT:DisplayText(SCT.LOCALS.EXAMPLE, color, nil, "damage", SCT.FRAME1, nil, nil, "Interface\\Icons\\INV_Misc_QuestionMark");
	SCT:DisplayText(SCT.LOCALS.EXAMPLE2, color, nil, "damage", SCT.FRAME2, nil, nil, "Interface\\Icons\\INV_Misc_QuestionMark");
	SCT:DisplayText(SCT.LOCALS.EXAMPLE, color, nil, "event", SCT.FRAME1, nil, nil, "Interface\\Icons\\INV_Misc_QuestionMark");
	SCT:DisplayText(SCT.LOCALS.EXAMPLE2, color, nil, "event", SCT.FRAME2, nil, nil, "Interface\\Icons\\INV_Misc_QuestionMark");
	SCT:DisplayMessage( SCT.LOCALS.MSG_EXAMPLE, color );
end
