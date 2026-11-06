local RangeColorOptions_SetColorFunc = {
	[1] = function(x) RangeColorOptions_SetColor(1) end,
	[2] = function(x) RangeColorOptions_SetColor(2) end,
	[3] = function(x) RangeColorOptions_SetColor(3) end,
	[4] = function(x) RangeColorOptions_SetColor(4) end,
	[5] = function(x) RangeColorOptions_SetColor(5) end,
	[6] = function(x) RangeColorOptions_SetColor(6) end,
	[7] = function(x) RangeColorOptions_SetColor(7) end,
	[8] = function(x) RangeColorOptions_SetColor(8) end,
	[9] = function(x) RangeColorOptions_SetColor(9) end,
	[10] = function(x) RangeColorOptions_SetColor(10) end,
	[11] = function(x) RangeColorOptions_SetColor(11) end,
	[12] = function(x) RangeColorOptions_SetColor(12) end,
};

local RangeColorOptions_CancelColorFunc = {
	[1] = function(x) RangeColorOptions_CancelColor(1,x) end,
	[2] = function(x) RangeColorOptions_CancelColor(2,x) end,
	[3] = function(x) RangeColorOptions_CancelColor(3,x) end,
	[4] = function(x) RangeColorOptions_CancelColor(4,x) end,
	[5] = function(x) RangeColorOptions_CancelColor(5,x) end,
	[6] = function(x) RangeColorOptions_CancelColor(6,x) end,
	[7] = function(x) RangeColorOptions_CancelColor(7,x) end,
	[8] = function(x) RangeColorOptions_CancelColor(8,x) end,
	[9] = function(x) RangeColorOptions_CancelColor(9,x) end,
	[10] = function(x) RangeColorOptions_CancelColor(10,x) end,
	[11] = function(x) RangeColorOptions_CancelColor(11,x) end,
	[12] = function(x) RangeColorOptions_CancelColor(12,x) end,
};

RangeColorOptionsFrameColorSwatch = { };
RangeColorOptionsFrameColorSwatch [RANGECOLOROPTIONS_COLORWATCH1.name] = { index = 1, text = RANGECOLOROPTIONS_COLORWATCH1.text, tooltipText = RANGECOLOROPTIONS_COLORWATCH1.tooltipText};
RangeColorOptionsFrameColorSwatch [RANGECOLOROPTIONS_COLORWATCH2.name] = { index = 2, text = RANGECOLOROPTIONS_COLORWATCH2.text, tooltipText = RANGECOLOROPTIONS_COLORWATCH2.tooltipText};
RangeColorOptionsFrameColorSwatch [RANGECOLOROPTIONS_COLORWATCH3.name] = { index = 3, text = RANGECOLOROPTIONS_COLORWATCH3.text, tooltipText = RANGECOLOROPTIONS_COLORWATCH3.tooltipText};
RangeColorOptionsFrameColorSwatch [RANGECOLOROPTIONS_COLORWATCH4.name] = { index = 4, text = RANGECOLOROPTIONS_COLORWATCH4.text, tooltipText = RANGECOLOROPTIONS_COLORWATCH4.tooltipText};
RangeColorOptionsFrameColorSwatch [RANGECOLOROPTIONS_COLORWATCH5.name] = { index = 5, text = RANGECOLOROPTIONS_COLORWATCH5.text, tooltipText = RANGECOLOROPTIONS_COLORWATCH5.tooltipText};
RangeColorOptionsFrameColorSwatch [RANGECOLOROPTIONS_COLORWATCH6.name] = { index = 6, text = RANGECOLOROPTIONS_COLORWATCH6.text, tooltipText = RANGECOLOROPTIONS_COLORWATCH6.tooltipText};
RangeColorOptionsFrameColorSwatch [RANGECOLOROPTIONS_COLORWATCH7.name] = { index = 7, text = RANGECOLOROPTIONS_COLORWATCH7.text, tooltipText = RANGECOLOROPTIONS_COLORWATCH7.tooltipText};
RangeColorOptionsFrameColorSwatch [RANGECOLOROPTIONS_COLORWATCH8.name] = { index = 8, text = RANGECOLOROPTIONS_COLORWATCH8.text, tooltipText = RANGECOLOROPTIONS_COLORWATCH8.tooltipText};
RangeColorOptionsFrameColorSwatch [RANGECOLOROPTIONS_COLORWATCH9.name] = { index = 9, text = RANGECOLOROPTIONS_COLORWATCH9.text, tooltipText = RANGECOLOROPTIONS_COLORWATCH9.tooltipText};
RangeColorOptionsFrameColorSwatch [RANGECOLOROPTIONS_COLORWATCH10.name] = { index = 10, text = RANGECOLOROPTIONS_COLORWATCH10.text, tooltipText = RANGECOLOROPTIONS_COLORWATCH10.tooltipText};
RangeColorOptionsFrameColorSwatch [RANGECOLOROPTIONS_COLORWATCH11.name] = { index = 11, text = RANGECOLOROPTIONS_COLORWATCH11.text, tooltipText = RANGECOLOROPTIONS_COLORWATCH11.tooltipText};
RangeColorOptionsFrameColorSwatch [RANGECOLOROPTIONS_COLORWATCH12.name] = { index = 12, text = RANGECOLOROPTIONS_COLORWATCH12.text, tooltipText = RANGECOLOROPTIONS_COLORWATCH12.tooltipText};

RangeColorOptionsFrameSliders = { };
RangeColorOptionsFrameSliders [RANGECOLOROPTIONS_SLIDER1.name] = { index = 1, RangeColorVar = "Mode", minValue = 1, maxValue = 3, valueStep = 1, minText=RANGECOLOROPTIONS_SLIDER1.minText, maxText=RANGECOLOROPTIONS_SLIDER1.maxText, tooltipText = RANGECOLOROPTIONS_SLIDER1.tooltipText};

RangeColorOptionsFrameEvents = { };
RangeColorOptionsFrameEvents [RANGECOLOROPTIONS_CHECK1.name] = { index = 1, tooltipText = RANGECOLOROPTIONS_CHECK1.tooltipText, RangeColorVar = "Filter"};
RangeColorOptionsFrameEvents [RANGECOLOROPTIONS_CHECK2.name] = { index = 2, tooltipText = RANGECOLOROPTIONS_CHECK2.tooltipText, RangeColorVar = "Dash"};

-- Safety: make sure the save table exists before the options file touches it.
local function RangeColorOptions_EnsureSave()
	if ( RangeColor_Save2 == nil ) then
		RangeColor_Initialize();
	end
end

function RangeColorOptions_OnLoad()
	RangeColorOptions_EnsureSave();
	UIPanelWindows["RangeColorOptionsFrame"] = {area = "center", pushable = 0};
end

function RangeColorOptions_OnShow()
	RangeColorOptions_EnsureSave();

	local button, string, checked;

	for key, value in RangeColorOptionsFrameEvents do
		string = getglobal("RangeColorOptionsFrame_CheckButton"..value.index.."Text");
		button = getglobal("RangeColorOptionsFrame_CheckButton"..value.index);
		if ( button ) then
			checked = nil;
			button.disabled = nil;
			if ( value.RangeColorVar ) then
				if ( RangeColor_Get(value.RangeColorVar) == 1 ) then
					checked = 1;
				else
					checked = 0;
				end
			else
				checked = 0;
			end
			button:Enable();
			button:SetChecked(checked);
			if ( string ) then
				string:SetText(key);
			end
			button.tooltipText = value.tooltipText;
		end
	end

	-- Enable/disable the Dash checkbox based on the Filter checkbox state.
	local cb1 = getglobal("RangeColorOptionsFrame_CheckButton1");
	local cb2 = getglobal("RangeColorOptionsFrame_CheckButton2");
	if ( cb1 and cb2 ) then
		if ( not cb1:GetChecked() ) then
			cb2:Disable();
		else
			cb2:Enable();
		end
	end

	for key, value in RangeColorOptionsFrameColorSwatch do
		string = getglobal("RangeColorSwatchFrame"..value.index.."_ColorSwatchText");
		if ( string ) then
			string:SetText(value.text);
		end

		local frame,swatch,sRed,sGreen,sBlue,sColor;

		frame = getglobal("RangeColorSwatchFrame"..value.index);
		swatch = getglobal("RangeColorSwatchFrame"..value.index.."_ColorSwatchNormalTexture");

		if ( frame and swatch ) then
			frame.tooltipText = value.tooltipText;

			sColor = RangeColor_GetColor(value.index);
			sRed = sColor.r;
			sGreen = sColor.g;
			sBlue = sColor.b;

			frame.r = sRed;
			frame.g = sGreen;
			frame.b = sBlue;
			frame.swatchFunc = RangeColorOptions_SetColorFunc[value.index];
			frame.cancelFunc = RangeColorOptions_CancelColorFunc[value.index];
			swatch:SetVertexColor(sRed,sGreen,sBlue);
		end
	end

	local slider, low, high, getvalue
	for key, value in RangeColorOptionsFrameSliders do
		slider = getglobal("RangeColorOptionsFrame_Slider"..value.index);
		string = getglobal("RangeColorOptionsFrame_Slider"..value.index.."Text");
		low = getglobal("RangeColorOptionsFrame_Slider"..value.index.."Low");
		high = getglobal("RangeColorOptionsFrame_Slider"..value.index.."High");
		if ( slider ) then
			getvalue = RangeColor_Get(value.RangeColorVar);
			if ( getvalue == nil ) then getvalue = value.minValue; end
			-- VANILLA: Sliders have no :Enable(). Use EnableMouse() or nothing.
			slider:EnableMouse(true);
			slider:SetMinMaxValues(value.minValue, value.maxValue);
			slider:SetValueStep(value.valueStep);
			slider:SetValue(getvalue);
			if ( string ) then string:SetText(key); end
			if ( low ) then low:SetText(value.minText); end
			if ( high ) then high:SetText(value.maxText); end
			slider.tooltipText = value.tooltipText;
		end
	end
end

function RangeColorOptions_CheckButtonOnClick()
	RangeColorOptions_EnsureSave();
	local button;
	for key, value in RangeColorOptionsFrameEvents do
		if (this:GetName() == "RangeColorOptionsFrame_CheckButton"..value.index) then
			local enable = nil;
			button = getglobal("RangeColorOptionsFrame_CheckButton"..value.index);
			if ( button and button:GetChecked() ) then
				enable = 1;
			else
				enable = 0;
			end
			if ( value.RangeColorVar ) then
				RangeColor_Set(value.RangeColorVar, enable);
			end
		end
	end
	local cb1 = getglobal("RangeColorOptionsFrame_CheckButton1");
	local cb2 = getglobal("RangeColorOptionsFrame_CheckButton2");
	if ( cb1 and cb2 ) then
		if ( not cb1:GetChecked() ) then
			cb2:Disable();
		else
			cb2:Enable();
		end
	end
end

function RangeColorOptions_SliderOnValueChanged()
	RangeColorOptions_EnsureSave();
	local slider;
	for key, value in RangeColorOptionsFrameSliders do
		if (this:GetName() == "RangeColorOptionsFrame_Slider"..value.index) then
			if ( value.RangeColorVar ) then
				RangeColor_Set(value.RangeColorVar,this:GetValue());
			end
		end
	end
end

function RangeColorOptions_SetColor(key)
	RangeColorOptions_EnsureSave();
	local r,g,b = ColorPickerFrame:GetColorRGB();
	local swatch,frame;
	swatch = getglobal("RangeColorSwatchFrame"..key.."_ColorSwatchNormalTexture");
	frame = getglobal("RangeColorSwatchFrame"..key);
	swatch:SetVertexColor(r,g,b);
	frame.r = r;
	frame.g = g;
	frame.b = b;
	RangeColor_SetColor(key, r, g, b)
end

function RangeColorOptions_CancelColor(key, prev)
	RangeColorOptions_EnsureSave();
	local r = prev.r;
	local g = prev.g;
	local b = prev.b;
	local swatch, frame;
	swatch = getglobal("RangeColorSwatchFrame"..key.."_ColorSwatchNormalTexture");
	frame = getglobal("RangeColorSwatchFrame"..key);
	swatch:SetVertexColor(r, g, b);
	frame.r = r;
	frame.g = g;
	frame.b = b;
	RangeColor_SetColor(key, r, g, b)
end

-- VANILLA: OpenColorPicker must set ColorPickerFrame.func/cancelFunc explicitly,
-- and also set ColorPickerFrame.previousValues for the Cancel path.
function RangeColorOptions_OpenColorPicker(button)
	RangeColorOptions_EnsureSave();
	CloseMenus();
	if ( not button ) then
		button = this;
	end
	ColorPickerFrame.func = button.swatchFunc;
	ColorPickerFrame.cancelFunc = button.cancelFunc;
	ColorPickerFrame:SetColorRGB(button.r, button.g, button.b);
	ColorPickerFrame.previousValues = {r = button.r, g = button.g, b = button.b, opacity = 1.0};
	ColorPickerFrame:Show();
end