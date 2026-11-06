--[[

	Range Color: Changes the icon color and/or HotKey text color when the skill is out of range, has no mana or isn't usable etc;
								also it shows the hotkeys for the extra Blizzard Bars.

	Made by: Edswor, adapted for OctoWoW by livians + DeepSeek 4 pro
	Vanilla 1.12.1 compatibility fixes applied.

	Commands: /rangecolor  or  /rc

]]

--------------------------------------------------------------------------------------------------
-- Other variables
--------------------------------------------------------------------------------------------------

local Old_ActionButton_OnUpdate;
local Old_ActionButton_UpdateUsable;
local Old_ActionButton_UpdateHotkeys;
local Old_FlexBarButton_OnUpdate;
local Old_FlexBarButton_UpdateUsable;
local Old_Gypsy_ActionButtonOnUpdate;
local Old_Gypsy_ActionButtonUpdateUsable;
local Old_PopBarButton_OnUpdate;
local Old_PopBarButton_UpdateUsable;
local Old_SideBarButton_OnUpdate;
local Old_SideBarButton_UpdateUsable;
local Old_BottomBarButton_OnUpdate;
local Old_BottomBarButton_UpdateUsable;

--------------------------------------------------------------------------------------------------
-- OnLoad, Initialize
--------------------------------------------------------------------------------------------------

function RangeColor_OnLoad()

	this:RegisterEvent("VARIABLES_LOADED");
	this:RegisterEvent("UPDATE_BINDINGS");
	this:RegisterEvent("ADDON_LOADED");

	SLASH_RANGECOLOR1 = "/rangecolor";
	SLASH_RANGECOLOR2 = "/rc";
	SlashCmdList["RANGECOLOR"] = RangeColor_ShowOptions;

	--Hook the ActionButton_OnUpdate function
	Old_ActionButton_OnUpdate = ActionButton_OnUpdate;
	ActionButton_OnUpdate = RangeColor_ActionButton_OnUpdate;

	--Hook the ActionButton_UpdateUsable function
	Old_ActionButton_UpdateUsable = ActionButton_UpdateUsable;
	ActionButton_UpdateUsable = RangeColor_ActionButton_UpdateUsable;

	--Hook the ActionButton_UpdateHotkeys function
	Old_ActionButton_UpdateHotkeys = ActionButton_UpdateHotkeys;
	ActionButton_UpdateHotkeys = RangeColor_ActionButton_UpdateHotkeys;

	--Hook the FlexBarButton_OnUpdate and FlexBarButton_UpdateUsable function
	if (type(FlexBarButton_OnUpdate) == 'function') then
		Old_FlexBarButton_OnUpdate = FlexBarButton_OnUpdate;
		FlexBarButton_OnUpdate = RangeColor_FlexBarButton_OnUpdate;
	end
	if (type(FlexBarButton_UpdateUsable) == 'function') then
		Old_FlexBarButton_UpdateUsable = FlexBarButton_UpdateUsable;
		FlexBarButton_UpdateUsable = RangeColor_FlexBarButton_UpdateUsable;
	end

	--Hook the Gypsy_ActionButtonOnUpdate and Gypsy_ActionButtonUpdateUsable function
	if (type(Gypsy_ActionButtonOnUpdate) == 'function') then
		Old_Gypsy_ActionButtonOnUpdate = Gypsy_ActionButtonOnUpdate;
		Gypsy_ActionButtonOnUpdate = RangeColor_Gypsy_ActionButtonOnUpdate;
	end
	if (type(Gypsy_ActionButtonUpdateUsable) == 'function') then
		Old_Gypsy_ActionButtonUpdateUsable = Gypsy_ActionButtonUpdateUsable;
		Gypsy_ActionButtonUpdateUsable = RangeColor_Gypsy_ActionButtonUpdateUsable;
	end

	--Hook the PopBarButton_OnUpdate and PopBarButton_UpdateUsable function
	if (type(PopBarButton_OnUpdate) == 'function') then
		Old_PopBarButton_OnUpdate = PopBarButton_OnUpdate;
		PopBarButton_OnUpdate = RangeColor_PopBarButton_OnUpdate;
	end
	if (type(PopBarButton_UpdateUsable) == 'function') then
		Old_PopBarButton_UpdateUsable = PopBarButton_UpdateUsable;
		PopBarButton_UpdateUsable = RangeColor_PopBarButton_UpdateUsable;
	end

	--Hook the SideBarButton_OnUpdate and SideBarButton_UpdateUsable function
	if (type(SideBarButton_OnUpdate) == 'function') then
		Old_SideBarButton_OnUpdate = SideBarButton_OnUpdate;
		SideBarButton_OnUpdate = RangeColor_SideBarButton_OnUpdate;
	end
	if (type(SideBarButton_UpdateUsable) == 'function') then
		Old_SideBarButton_UpdateUsable = SideBarButton_UpdateUsable;
		SideBarButton_UpdateUsable = RangeColor_SideBarButton_UpdateUsable;
	end

	--Hook the BottomBarButton_OnUpdate and BottomBarButton_UpdateUsable function
	if (type(BottomBarButton_OnUpdate) == 'function') then
		Old_BottomBarButton_OnUpdate = BottomBarButton_OnUpdate;
		BottomBarButton_OnUpdate = RangeColor_BottomBarButton_OnUpdate;
	end
	if (type(BottomBarButton_UpdateUsable) == 'function') then
		Old_BottomBarButton_UpdateUsable = BottomBarButton_UpdateUsable;
		BottomBarButton_UpdateUsable = RangeColor_BottomBarButton_UpdateUsable;
	end

	-- Safety net: if VARIABLES_LOADED already fired before this addon loaded
	-- (happens on /reload on some 1.12.1 clients), make sure the save table
	-- exists. Non-destructive, so it's safe to call here.
	RangeColor_Initialize();

end

-- Non-destructive initializer: fills in missing keys but never wipes an existing save.
function RangeColor_Initialize()

	if ( RangeColor_Save2 == nil ) then
		RangeColor_Save2 = {};
	end

	RangeColor_Save2["Version"] = RANGECOLOR_VERSION;

	if ( RangeColor_Save2["Mode"]   == nil ) then RangeColor_Save2["Mode"]   = 3; end
	if ( RangeColor_Save2["Filter"] == nil ) then RangeColor_Save2["Filter"] = 1; end
	if ( RangeColor_Save2["Dash"]   == nil ) then RangeColor_Save2["Dash"]   = 1; end

	local defaults = {
		[1]  = {r = 1.0, g = 0.0, b = 0.0},
		[2]  = {r = 1.0, g = 1.0, b = 1.0},
		[3]  = {r = 1.0, g = 1.0, b = 1.0},
		[4]  = {r = 0.3, g = 0.3, b = 1.0},
		[5]  = {r = 1.0, g = 1.0, b = 1.0},
		[6]  = {r = 1.0, g = 1.0, b = 1.0},
		[7]  = {r = 0.0, g = 1.0, b = 0.0},
		[8]  = {r = 1.0, g = 1.0, b = 1.0},
		[9]  = {r = 1.0, g = 1.0, b = 1.0},
		[10] = {r = 1.0, g = 1.0, b = 1.0},
		[11] = {r = 1.0, g = 1.0, b = 1.0},
		[12] = {r = 1.0, g = 1.0, b = 1.0},
	};

	if ( RangeColor_Save2["Colors"] == nil ) then
		RangeColor_Save2["Colors"] = {};
	end

	for i = 1, 12 do
		if ( RangeColor_Save2["Colors"][i] == nil ) then
			RangeColor_Save2["Colors"][i] = {
				r = defaults[i].r,
				g = defaults[i].g,
				b = defaults[i].b,
			};
		end
	end

end

--------------------------------------------------------------------------------------------------
-- ShowOptions, HideOptions, Toggle
--------------------------------------------------------------------------------------------------

function RangeColor_ShowOptions()
	ShowUIPanel(RangeColorOptionsFrame);
end

function RangeColor_HideOptions()
	HideUIPanel(RangeColorOptionsFrame);
end

function RangeColor_Toggle()
	if(RangeColorOptionsFrame:IsVisible()) then
		HideUIPanel(RangeColorOptionsFrame);
	else
		ShowUIPanel(RangeColorOptionsFrame);
	end
end

function RangeColor_ResetOptions()
	RangeColor_Save2 = nil;
	RangeColor_Initialize();
	RangeColor_HideOptions();
end

--------------------------------------------------------------------------------------------------
-- OnEvent
--------------------------------------------------------------------------------------------------

function RangeColor_OnEvent()
	if( event == "VARIABLES_LOADED" ) then
		RangeColor_Initialize();
		if( DEFAULT_CHAT_FRAME ) then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Range Color|r, made by: |cffff3300Edswor|r, Version: |cffffff00"..RANGECOLOR_VERSION.."|r, loaded.");
		end
		return;
	elseif( event == "ADDON_LOADED") then
		if(myAddOnsFrame_Register) then
			RangeColorDetails = {
				name = "RangeColor",
				version = RANGECOLOR_VERSION,
				releaseDate = RANGECOLOR_RELEASE,
				author = "Edswor",
				email = "edsowr@hotmail.com",
				website = "http://edswor.iespana.es",
				category = MYADDONS_CATEGORY_BARS,
				optionsframe = "RangeColorOptionsFrame"
			};
			myAddOnsFrame_Register(RangeColorDetails, RangeColorHelp);
		end
		return;
	elseif( event == "UPDATE_BINDINGS" ) then
		RangeColor_UpdateHotkeys();
		return;
	end
end

--------------------------------------------------------------------------------------------------
-- OnUpdate, UpdateUsable, ActionButton
--------------------------------------------------------------------------------------------------

function RangeColor_ActionButton_OnUpdate(elapsed)

	-- Call the original OnUpdate so Blizzard's rangeTimer logic still runs.
	if ( Old_ActionButton_OnUpdate ) then
		Old_ActionButton_OnUpdate(elapsed);
	end

	RangeColor_ActionButton(elapsed);

end

function RangeColor_ActionButton_UpdateUsable()

	-- Call the original first so the button's usable state is reset correctly,
	-- then apply our tint on top of it.
	if ( Old_ActionButton_UpdateUsable ) then
		Old_ActionButton_UpdateUsable();
	end

	RangeColor_ActionButton(0);

end

function RangeColor_ActionButton(elapsed)

	local name = this:GetName();
	if ( not name ) then return; end

	local icon          = getglobal(name.."Icon");
	local normalTexture = getglobal(name.."NormalTexture");
	local hotkey        = getglobal(name.."HotKey");

	if ( not icon or not hotkey ) then return; end

	local actionID = ActionButton_GetPagedID(this);

	local isUsable, notEnoughMana = IsUsableAction(actionID);

	-- On 1.12.1:
	--   IsActionInRange returns 1  -> in range
	--                           0  -> out of range
	--                        nil -> no range check applies (buffs, self-cast, etc.)
	-- Out-of-range is strictly == 0. nil must NOT be treated as out of range,
	-- or every non-targeted action (buffs, self-cast, etc.) gets tinted red.
	local inRange = IsActionInRange(actionID);
	local outOfRange = ( inRange == 0 );

	local mode = RangeColor_Get("Mode");

	if ( (mode == 3) or (mode == 2 and hotkey:GetText() == nil) ) then

		hotkey:SetVertexColor(0.6, 0.6, 0.6);

		if ( this.rangeTimer and this.rangeTimer <= elapsed ) then

			if ( outOfRange ) then
				icon:SetVertexColor(RangeColor_Save2["Colors"][1].r, RangeColor_Save2["Colors"][1].g, RangeColor_Save2["Colors"][1].b);
				if ( normalTexture ) then
					normalTexture:SetVertexColor(RangeColor_Save2["Colors"][2].r, RangeColor_Save2["Colors"][2].g, RangeColor_Save2["Colors"][2].b);
				end
			else
				if ( isUsable ) then
					icon:SetVertexColor(RangeColor_Save2["Colors"][10].r, RangeColor_Save2["Colors"][10].g, RangeColor_Save2["Colors"][10].b);
					if ( normalTexture ) then
						normalTexture:SetVertexColor(RangeColor_Save2["Colors"][11].r, RangeColor_Save2["Colors"][11].g, RangeColor_Save2["Colors"][11].b);
					end
				elseif ( notEnoughMana ) then
					icon:SetVertexColor(RangeColor_Save2["Colors"][4].r, RangeColor_Save2["Colors"][4].g, RangeColor_Save2["Colors"][4].b);
					if ( normalTexture ) then
						normalTexture:SetVertexColor(RangeColor_Save2["Colors"][5].r, RangeColor_Save2["Colors"][5].g, RangeColor_Save2["Colors"][5].b);
					end
				else
					icon:SetVertexColor(RangeColor_Save2["Colors"][7].r, RangeColor_Save2["Colors"][7].g, RangeColor_Save2["Colors"][7].b);
					if ( normalTexture ) then
						normalTexture:SetVertexColor(RangeColor_Save2["Colors"][8].r, RangeColor_Save2["Colors"][8].g, RangeColor_Save2["Colors"][8].b);
					end
				end
			end

		end

	else

		if ( this.rangeTimer and this.rangeTimer <= elapsed ) then
			if ( outOfRange ) then
				icon:SetVertexColor(1.0, 1.0, 1.0);
				if ( normalTexture ) then
					normalTexture:SetVertexColor(1.0, 1.0, 1.0);
				end
			end
		end

		if ( outOfRange ) then
			hotkey:SetVertexColor(RangeColor_Save2["Colors"][3].r, RangeColor_Save2["Colors"][3].g, RangeColor_Save2["Colors"][3].b);
		else
			if ( isUsable ) then
				hotkey:SetVertexColor(RangeColor_Save2["Colors"][12].r, RangeColor_Save2["Colors"][12].g, RangeColor_Save2["Colors"][12].b);
			elseif ( notEnoughMana ) then
				hotkey:SetVertexColor(RangeColor_Save2["Colors"][6].r, RangeColor_Save2["Colors"][6].g, RangeColor_Save2["Colors"][6].b);
			else
				hotkey:SetVertexColor(RangeColor_Save2["Colors"][9].r, RangeColor_Save2["Colors"][9].g, RangeColor_Save2["Colors"][9].b);
			end
		end

	end

end

--------------------------------------------------------------------------------------------------
-- ActionButton_UpdateHotkeys, UpdateHotkeys, UpdateHotkeysBar, TransformText
--------------------------------------------------------------------------------------------------

function RangeColor_ActionButton_UpdateHotkeys(actionButtonType)
	if ( not actionButtonType ) then
		actionButtonType = "ACTIONBUTTON";
	end
	local hotkey = getglobal(this:GetName().."HotKey");
	local action = actionButtonType..this:GetID();
	local text = GetBindingText(GetBindingKey(action), "KEY_");
	if ( string.len(text) == 0 ) then
		hotkey:Hide();
	else
		hotkey:SetText(RangeColor_TransformText(text));
		hotkey:Show();
	end
end

function RangeColor_UpdateHotkeys()
	RangeColor_UpdateHotkeysBar("MultiBarBottomLeft", 1);
	RangeColor_UpdateHotkeysBar("MultiBarBottomRight", 2);
	RangeColor_UpdateHotkeysBar("MultiBarRight", 3);
	RangeColor_UpdateHotkeysBar("MultiBarLeft", 4);
end

function RangeColor_UpdateHotkeysBar(bar, id)
	local hotkey, action, text;
	for i = 1, 12 do
		hotkey = getglobal(bar.."Button"..i.."HotKey");
		action = "MULTIACTIONBAR"..id.."BUTTON"..i;
		text = GetBindingText(GetBindingKey(action), "KEY_");
		if ( string.len(text) == 0 ) then
			hotkey:Hide();
		else
			hotkey:SetText(RangeColor_TransformText(text));
			hotkey:Show();
		end
	end
end

function RangeColor_TransformText(text)

	if ( RangeColor_Save2 ~= nil ) then
		if( RangeColor_Get("Filter") == 1 ) then
			text = string.gsub(text, "CTRL", "C");
			text = string.gsub(text, "ALT", "A");
			text = string.gsub(text, "SHIFT", "S");
			text = string.gsub(text, "Spacebar", "Sp");
			text = string.gsub(text, "Insert", "In");
			text = string.gsub(text, "Delete", "De");
			text = string.gsub(text, "Num Pad", "NP");
			text = string.gsub(text, "Num Lock", "NL");
			text = string.gsub(text, "Backspace", "Ba");
			text = string.gsub(text, " Arrow", "");
			if( RangeColor_Get("Dash") == 1 ) then
				text = string.gsub(text, "-", "");
			end
			text = string.gsub(text, "Wheel ", "W-");
			text = string.gsub(text, "Page ", "P-");
		end
	else
		text = string.gsub(text, "CTRL", "C");
		text = string.gsub(text, "ALT", "A");
		text = string.gsub(text, "SHIFT", "S");
		text = string.gsub(text, "Spacebar", "Sp");
		text = string.gsub(text, "Insert", "In");
		text = string.gsub(text, "Delete", "De");
		text = string.gsub(text, "Num Pad", "NP");
		text = string.gsub(text, "Num Lock", "NL");
		text = string.gsub(text, "Backspace", "Ba");
		text = string.gsub(text, " Arrow", "");
		text = string.gsub(text, "-", "");
		text = string.gsub(text, "Wheel ", "W-");
		text = string.gsub(text, "Page ", "P-");
	end

	return text;
end

--------------------------------------------------------------------------------------------------
-- Set, Get, GetColor, SetColor
--------------------------------------------------------------------------------------------------

function RangeColor_Get(option)
	if ( RangeColor_Save2 ~= nil and RangeColor_Save2[option] ~= nil ) then
		return RangeColor_Save2[option];
	end
	return nil;
end

function RangeColor_Set(option, val)
	if ( RangeColor_Save2 ~= nil ) then
		if ( option ) then
			RangeColor_Save2[option] = val;
		end
	end
end

function RangeColor_GetColor(key)
	local color = {r = 1.0, g = 1.0, b = 1.0};

	if ( RangeColor_Save2 ~= nil and RangeColor_Save2["Colors"] ~= nil
	     and RangeColor_Save2["Colors"][key] ~= nil ) then
		color.r = RangeColor_Save2["Colors"][key].r;
		color.g = RangeColor_Save2["Colors"][key].g;
		color.b = RangeColor_Save2["Colors"][key].b;
	end
	return color;
end

function RangeColor_SetColor(key, r, g, b)
	if ( RangeColor_Save2 ~= nil and RangeColor_Save2["Colors"] ~= nil
	     and RangeColor_Save2["Colors"][key] ~= nil ) then
		RangeColor_Save2["Colors"][key].r = r;
		RangeColor_Save2["Colors"][key].g = g;
		RangeColor_Save2["Colors"][key].b = b;
	end
end
