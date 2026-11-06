function RTT_CreateConfigGUI()
  RTT_CreateConfigGUIFrame();
  RTT_Config_CreateDebuffSelections();
  RTT_Config_CreateUseAction();
  RTT_Config_CreateScale();
  RTT_Config_CreateTrackCount();
  RTT_Config_CreateButtons();
end

function RTT_CreateConfigGUIFrame()
  local f = CreateFrame("Frame", "RTT_ConfigFrame", UI_Parent);
	f:SetMovable(true);
  f:SetScale(0.7);
	f:EnableMouse(true)
  f:SetFrameStrata("DIALOG");

	f:SetScript("OnMouseDown", function()
	  if not RTT_ConfigFrame.isMoving then
	     RTT_ConfigFrame:StartMoving();
	   RTT_ConfigFrame.isMoving = true;
	  end
	end)
	RTT_ConfigFrame:SetScript("OnMouseUp", function()
	  if RTT_ConfigFrame.isMoving then
	   RTT_ConfigFrame:StopMovingOrSizing();
	   RTT_ConfigFrame.isMoving = false;
	  end
	end)
	RTT_ConfigFrame:SetScript("OnHide", function()
	  if ( RTT_ConfigFrame.isMoving ) then
	   RTT_ConfigFrame:StopMovingOrSizing();
	   RTT_ConfigFrame.isMoving = false;
	  end
	end)


  f:SetWidth(330);
  f:SetHeight(380);
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	f:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                            tile = true, tileSize = 16, edgeSize = 16,
                            insets = { left = 4, right = 4, top = 4, bottom = 4 }});
  f:SetBackdropColor(0,0,0,1);
    local f = CreateFrame("Frame", "RTT_ConfigTitleFrame", RTT_ConfigFrame);
    f:SetWidth(330);
    f:SetHeight(32);
    f:SetPoint("TOPLEFT", RTT_ConfigFrame, "TOPLEFT", 0, 0);
  	f:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                          edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                              tile = true, tileSize = 16, edgeSize = 16,
                              insets = { left = 4, right = 4, top = 4, bottom = 4 }});
    f:SetBackdropColor(0,0,0,0.6);
  	local label = RTT_ConfigTitleFrame:CreateFontString("RTT_ConfigTitleLabel", "OVERLAY", "GameFontHighlight");
  	label:SetWidth(330);
  	label:SetPoint("TOPLEFT", -12, -6);
    label:SetFont("Fonts\\FRIZQT__.TTF", 18);
  	label:SetTextColor(0.2, 0.51, 0.6);
  	label:SetText("Retherz Target Tracker - Settings");

  	local button = CreateFrame("Button", "RTT_ConfigTitleButton", RTT_ConfigTitleFrame, "UIPanelButtonTemplate");
  	button:SetPoint("TOPRIGHT", -9, -6);
  	button:SetHeight(18);
  	button:SetWidth(18);
  	button:SetText("X");
  	button:SetScript("OnClick", function()
      RTT_ConfigGUIToggle();
  	end)
    RTT_ConfigFrame:Hide();
end

function RTT_Config_CreateDebuffSelections()
  for i=1, 4 do
    	local button = CreateFrame("Button", "RTT_ConfigDropDown" .. i, RTT_ConfigFrame, "UIDropDownMenuTemplate");
      button = getglobal("RTT_ConfigDropDown" .. i);
    	button:SetPoint("TOPLEFT", RTT_ConfigFrame, "TOPLEFT", 120, -200 -30 * i);
      button.textureCount = i;

    	local label = RTT_ConfigFrame:CreateFontString("RTT_ConfigDebuffLabel" .. i, "OVERLAY", "GameFontHighlight");
    	label:SetPoint("TOPLEFT", RTT_ConfigFrame, "TOPLEFT", 10, -208 -30 * i);
      label:SetFont("Fonts\\FRIZQT__.TTF", 12);
    	label:SetTextColor(0.2, 0.51, 0.6);
    	label:SetText("Tracked Debuff " .. i);

      local function OnClick()
         UIDropDownMenu_SetSelectedID(button, this:GetID())
         RTT_TrackedDebuffs[button.textureCount] = UIDropDownMenu_GetText(button);
         RTT_StoreDebuffs();
         RTT_SetTrackedDebuff(button.textureCount, UIDropDownMenu_GetText(button));
      end

      UIDropDownMenu_Initialize(button, function(self, level, menuList)
        local info = {}
        local c = 1;
         for k,v in pairs(RTT_SpellData) do
           v = v["name"];
            info = {}
            info.text = v
            info.value = v
            info.func = OnClick;
            UIDropDownMenu_AddButton(info)
         end
      end)
      UIDropDownMenu_SetWidth(160, button);
    local c = 1;
     for k,v in pairs(RTT_SpellData) do
       v = v["name"];
       if(v == RTT_TrackedDebuffs[i]) then
         break;
       else
         c = c + 1;
       end
     end
    UIDropDownMenu_SetSelectedID(button, c);


  end
end

function RTT_Config_CreateUseAction()

      	local label = RTT_ConfigFrame:CreateFontString("RTT_ConfigActionLabel", "OVERLAY", "GameFontHighlight");
      	label:SetPoint("TOPLEFT", RTT_ConfigFrame, "TOPLEFT", 10, -68);
        label:SetFont("Fonts\\FRIZQT__.TTF", 12);
      	label:SetTextColor(0.2, 0.51, 0.6);
      	label:SetText("Use Action on Target");

      	local inputbox = CreateFrame("EditBox", "RTT_ConfigActionInput", RTT_ConfigFrame, "InputBoxTemplate");
      	inputbox:SetWidth(40);
      	inputbox:SetHeight(20);
      	inputbox:SetPoint("TOPLEFT", RTT_ConfigFrame, "TOPLEFT", 220, -68);
      	inputbox:SetAutoFocus(false);
      	inputbox:SetMaxLetters(3);
        inputbox:SetNumeric();
        inputbox.hasBeenSet = false;
      	inputbox:SetScript("OnEnterPressed", function()
      		inputbox:ClearFocus();
      	end);
      	inputbox:SetScript("OnTextChanged", function()
          local n = math.floor(RTT_ConfigActionInput:GetNumber());
          if(not RTT_ConfigActionInput.hasBeenSet) then
            RTT_ConfigActionInput.hasBeenSet = true;
            RTT_ConfigActionInput:SetText(RetherzTargetTracker.UseAction);
            n = RetherzTargetTracker.UseAction;
          end
          if(n > 120) then
            RTT_ConfigActionInput:SetText(120);
          elseif(n == nil) then
            RTT_ConfigActionInput:SetText(RetherzTargetTracker.UseAction);
          end
          RetherzTargetTracker.UseAction = n;
      	end);
end

function RTT_Config_CreateScale()

      	local label = RTT_ConfigFrame:CreateFontString("RTT_ConfigScaleLabel", "OVERLAY", "GameFontHighlight");
      	label:SetPoint("TOPLEFT", RTT_ConfigFrame, "TOPLEFT", 10, -38);
        label:SetFont("Fonts\\FRIZQT__.TTF", 12);
      	label:SetTextColor(0.2, 0.51, 0.6);
      	label:SetText("GUI Scale");

      	local inputbox = CreateFrame("EditBox", "RTT_ConfigScaleInput", RTT_ConfigFrame, "InputBoxTemplate");
      	inputbox:SetWidth(40);
      	inputbox:SetHeight(20);
      	inputbox:SetPoint("TOPLEFT", RTT_ConfigFrame, "TOPLEFT", 220, -38);
      	inputbox:SetAutoFocus(false);
      	inputbox:SetMaxLetters(3);
        inputbox:SetNumeric();
        inputbox.hasBeenSet = false;
      	inputbox:SetScript("OnEnterPressed", function()
      		inputbox:ClearFocus();
      	end);
      	inputbox:SetScript("OnTextChanged", function()
          local n = math.floor(RTT_ConfigScaleInput:GetNumber());
          if(not RTT_ConfigScaleInput.hasBeenSet) then
            RTT_ConfigScaleInput.hasBeenSet = true;
            RTT_ConfigScaleInput:SetText(RetherzTargetTracker.Scale);
            n = RetherzTargetTracker.Scale;
          end
          if(n > 300) then
            RTT_ConfigScaleInput:SetText(300);
          elseif(n == nil) then
            RTT_ConfigScaleInput:SetText(RetherzTargetTracker.Scale);
          end
          RTT_Frame:SetScale(n / 100);
          RetherzTargetTracker.Scale = n;
      	end);
end

function RTT_Config_CreateTrackCount()

      	local label = RTT_ConfigFrame:CreateFontString("RTT_ConfigTrackLabel", "OVERLAY", "GameFontHighlight");
      	label:SetPoint("TOPLEFT", RTT_ConfigFrame, "TOPLEFT", 10, -98);
        label:SetFont("Fonts\\FRIZQT__.TTF", 12);
      	label:SetTextColor(0.2, 0.51, 0.6);
      	label:SetText("Debuff Track Count");

      	local button = CreateFrame("Button", "RTT_ConfigTrackDropDown", RTT_ConfigFrame, "UIDropDownMenuTemplate");
      	button:SetPoint("TOPLEFT", RTT_ConfigFrame, "TOPLEFT", 195, -98);
        local function RTT_Menu_OnClick(...)
          for k, v in pairs(args) do
        end
        end

        local function OnClick()
           UIDropDownMenu_SetSelectedID(button, this:GetID())
           RetherzTargetTracker.DebuffCount = this:GetID();
        end

        UIDropDownMenu_Initialize(button, function(self, level, menuList)
          local c = 1;
          local info = {}
           for i=1,4 do
              info = {}
              info.text = i
              info.value = i
              info.func = OnClick;
              UIDropDownMenu_AddButton(info)
           end
        end)
      UIDropDownMenu_SetWidth(36, button);
      UIDropDownMenu_SetSelectedID(button, RetherzTargetTracker.DebuffCount);

end

function RTT_Config_CreateButtons()

  local button = CreateFrame("Button", "RTT_ConfigVisibilityButton", RTT_ConfigFrame, "UIPanelButtonTemplate");
  button:SetPoint("TOPLEFT", 27, -135);
  button:SetHeight(32);
  button:SetWidth(128);
  if(RetherzTargetTracker.Visible) then
    button:SetText("Hide");
  else
    button:SetText("Show");
  end
  button:SetScript("OnClick", function()
    RTT_ToggleGUI();
  end)

  local button = CreateFrame("Button", "RTT_ConfigResetButton", RTT_ConfigFrame, "UIPanelButtonTemplate");
  button:SetPoint("TOPLEFT", 175, -135);
  button:SetHeight(32);
  button:SetWidth(128);
  button:SetText("Reset");
  button:SetScript("OnClick", function()
    RetherzTargetTracker.X = math.floor((GetScreenWidth() / 2) / (RetherzTargetTracker.Scale / 100) + RTT_Frame:GetWidth() / 2);
    RetherzTargetTracker.Y = math.floor((GetScreenHeight() / 2) / (RetherzTargetTracker.Scale / 100)  + RTT_Frame:GetHeight() / 2);
    RTT_Frame:ClearAllPoints();
    RTT_Frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", RetherzTargetTracker.X, RetherzTargetTracker.Y);
  end)

end

function RTT_ConfigGUIToggle()
    if(RTT_ConfigFrame:IsVisible()) then
      RTT_ConfigFrame:Hide();
    	RTT_Frame:SetMovable(false);
    	RTT_Frame:EnableMouse(false);
  	 RTT_Frame:SetBackdrop(nil);
        for i=1, 8 do
          local f = getglobal("RTT_Bar" .. i);
          f:Show();
        end
    else
      RTT_ConfigFrame:Show();
    	RTT_Frame:SetMovable(true);
    	RTT_Frame:EnableMouse(true);
  	 RTT_Frame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background"});
        for i=1, 8 do
          local f = getglobal("RTT_Bar" .. i);
          f:Hide();
        end
    end
end

function RTT_ToggleGUI()
  RetherzTargetTracker.Visible = not RetherzTargetTracker.Visible;
  if(RetherzTargetTracker.Visible) then
    RTT_Frame:Show();
    RTT_ConfigVisibilityButton:SetText("Hide");
  else
    RTT_Frame:Hide();
    RTT_ConfigVisibilityButton:SetText("Show");
  end
end
