local function handleCommands(msg, editbox)
  local args = {}
  for word in string.gfind(msg, '%S+') do
    if word ~= "" then
      table.insert(args, word)
    end
  end

  local command = args[1]

	-- this command toggles the percent display
  if command == "percent" then
		MonkeySpeed_TogglePercent()
		DEFAULT_CHAT_FRAME:AddMessage("Toggling percent display")
	-- this command toggles the coloured speed bar display
	elseif command == "bar" then
    MonkeySpeed_ToggleBar()
		DEFAULT_CHAT_FRAME:AddMessage("Toggling bar display")
	-- this command toggles the debug mode
  elseif command == "debug" then
		MonkeySpeed_ToggleDebug()
		DEFAULT_CHAT_FRAME:AddMessage("Toggling debug mode")
	-- this command toggles the lock
  elseif command == "lock" then
		MonkeySpeed_ToggleLock()
		DEFAULT_CHAT_FRAME:AddMessage("Toggling bar lock")
	-- this command recalibrates the speed calculations for this zone
  elseif command == "calibrate" then
		DEFAULT_CHAT_FRAME:AddMessage("Calibrating normal speed")
		MonkeySpeedSlash_CmdCalibrate()
  else
		DEFAULT_CHAT_FRAME:AddMessage("Toggling monkeyspeed display")
		MonkeySpeed_ToggleDisplay()
  end
end

-- OnLoad Function
function MonkeySpeed_OnLoad()

	-- register events
	this:RegisterEvent("VARIABLES_LOADED");
	this:RegisterEvent("UNIT_NAME_UPDATE");			-- this is the event I use to get per character config settings
	this:RegisterEvent("PLAYER_ENTERING_WORLD");	-- this event gives me a good character name in situations where "UNIT_NAME_UPDATE" doesn't even trigger
	this:RegisterEvent("ZONE_CHANGED_NEW_AREA");

	-- register chat slash commands
	SLASH_MONKEYSPEED1 = "/mspeed";
	SlashCmdList["MONKEYSPEED"] = handleCommands

	-- MonkeySpeedFrame:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0);
	MonkeySpeedFrame:SetBackdropBorderColor(1.0, 0.6901960784313725, 0.0, 1.0);

	MonkeySpeedOptions();	
end

-- OnEvent Function
function MonkeySpeed_OnEvent(event)
	
	if (event == "VARIABLES_LOADED") then
		-- this event gets called when the player enters the world
		--  Note: on initial login this event will not give a good player name
		
		MonkeySpeed.m_bVariablesLoaded = true;
		
		-- double check that the mod isn't already loaded
		if (not MonkeySpeed.m_bLoaded) then
			
			MonkeySpeed.m_strPlayer = UnitName("player");
			
			-- if MonkeySpeed.m_strPlayer is "Unknown Entity" get out, need a real name
			if (MonkeySpeed.m_strPlayer ~= nil and MonkeySpeed.m_strPlayer ~= UNKNOWNOBJECT) then
				-- should have a valid player name here
				MonkeySpeed_Init();
			end
		end
		
		-- exit this event
		return;
		
	end -- PLAYER_ENTERING_WORLD
	
	if (event == "UNIT_NAME_UPDATE") then
		-- this event gets called whenever a unit's name changes (supposedly)
		--  Note: Sometimes it gets called when unit's name gets set to
		--  "Unknown Entity"
				
		-- double check that we are getting the player's name update
		if (arg1 == "player" and not MonkeySpeed.m_bLoaded) then
			-- this is the first place I know that reliably gets the player name
			MonkeySpeed.m_strPlayer = UnitName("player");
			
			-- if MonkeySpeed.m_strPlayer is "Unknown Entity" get out, need a real name
			if (MonkeySpeed.m_strPlayer ~= nil and MonkeySpeed.m_strPlayer ~= UNKNOWNOBJECT) then
				-- should have a valid player name here
				MonkeySpeed_Init();
			end
		end
		
		-- exit this event
		return;
		
	end -- UNIT_NAME_UPDATE
	if (event == "PLAYER_ENTERING_WORLD") then
		-- this event gets called when the player enters the world
		--  Note: on initial login this event will not give a good player name
		
		-- double check that the mod isn't already loaded
		if (not MonkeySpeed.m_bLoaded) then
			
			MonkeySpeed.m_strPlayer = UnitName("player");
			
			-- if MonkeySpeed.m_strPlayer is "Unknown Entity" get out, need a real name
			if (MonkeySpeed.m_strPlayer ~= nil and MonkeySpeed.m_strPlayer ~= UNKNOWNOBJECT) then
				-- should have a valid player name here
				MonkeySpeed_Init();
			end
		end
		
		-- exit this event
		return;
		
	end -- PLAYER_ENTERING_WORLD
	
	if (event == "ZONE_CHANGED_NEW_AREA") then
		-- this fixes the speed displaying wrong sometimes when you switch areas (thanks Bhaldie)
		SetMapToCurrentZone();

	end -- ZONE_CHANGED_NEW_AREA
end

local baserate = 7
-- OnUpdate Function (heavily based off code in Telo's Clock)
function MonkeySpeed_OnUpdate(arg1)

	-- if the speedometer's not loaded yet, just exit
	if (not MonkeySpeed.m_bLoaded) then
		return;
	end
	
	-- how long since the last update?
	MonkeySpeed.m_iDeltaTime = MonkeySpeed.m_iDeltaTime + arg1;
	
	-- update the speed calculation
	MonkeySpeed.m_vCurrPos.x, MonkeySpeed.m_vCurrPos.y = UnitPosition("player")
	MonkeySpeed.m_vCurrPos.x = MonkeySpeed.m_vCurrPos.x + 0.0;
	MonkeySpeed.m_vCurrPos.y = MonkeySpeed.m_vCurrPos.y + 0.0;

	if (MonkeySpeed.m_vCurrPos.x) then
		local dist;

		-- travel speed ignores Z-distance (i.e. you run faster up or down hills)	
		-- x and y coords are not square, had to weight the x by 2.25 to make the readings match the y axis.
		dist = math.sqrt(
				((MonkeySpeed.m_vLastPos.x - MonkeySpeed.m_vCurrPos.x) * (MonkeySpeed.m_vLastPos.x - MonkeySpeed.m_vCurrPos.x)) +
				((MonkeySpeed.m_vLastPos.y - MonkeySpeed.m_vCurrPos.y) * (MonkeySpeed.m_vLastPos.y - MonkeySpeed.m_vCurrPos.y)));
		
		MonkeySpeed.m_fSpeedDist = MonkeySpeed.m_fSpeedDist + dist;
		if (MonkeySpeed.m_iDeltaTime >= .1) then

			-- The map coords seem to be a different scale in different zones. Figure out which zone we're in
			local zonenum;
			local zonename;
			local contnum;


			zonenum = GetCurrentMapZone();
			zonename = GetZoneText();

			if (MonkeySpeed.m_bCalibrate == true) then
				-- recalibrate this zone, the user should know this should be done when running at 100%
				-- MonkeySpeedConfig.m_SpecialZoneBaseline[zonename] = MonkeySpeed.m_fSpeedDist / MonkeySpeed.m_iDeltaTime;
				baserate = (MonkeySpeed.m_fSpeedDist / MonkeySpeed.m_iDeltaTime) / MonkeySpeed.calibrateSpeed; 
				-- done calibrating
				MonkeySpeed.m_bCalibrate = false;
			end

			MonkeySpeed.m_fSpeed = MonkeySpeed_Round(((MonkeySpeed.m_fSpeedDist / MonkeySpeed.m_iDeltaTime) / baserate) * 100);

			MonkeySpeed.m_fSpeedDist = 0.0;
			MonkeySpeed.m_iDeltaTime = 0.0;

			if (MonkeySpeedConfig[MonkeySpeed.m_strPlayer].m_bDisplayPercent) then
				-- Set the text for the speedometer
				MonkeySpeedText:SetText(format("%d%%", MonkeySpeed.m_fSpeed));
			end

			if (MonkeySpeedConfig[MonkeySpeed.m_strPlayer].m_bDisplayBar) then
				-- Set the colour of the bar
				if (MonkeySpeed.m_fSpeed == 0.0) then
					MonkeySpeedBar:SetVertexColor(1, 0, 0);
				elseif (MonkeySpeed.m_fSpeed < 100.0) then
					MonkeySpeedBar:SetVertexColor(1, 0.25, 0);
				elseif (MonkeySpeed.m_fSpeed == 100.0) then
					MonkeySpeedBar:SetVertexColor(1, 0.5, 0);
				elseif ((MonkeySpeed.m_fSpeed > 100.0) and (MonkeySpeed.m_fSpeed < 140.0)) then
					MonkeySpeedBar:SetVertexColor(0, 1, 0);
				elseif ((MonkeySpeed.m_fSpeed >= 140.0) and (MonkeySpeed.m_fSpeed < 200.0)) then
					MonkeySpeedBar:SetVertexColor(1, 0, 1);
				elseif ((MonkeySpeed.m_fSpeed >= 200.0) and (MonkeySpeed.m_fSpeed < 550.0)) then
					MonkeySpeedBar:SetVertexColor(0.5, 0, 1);
				elseif (MonkeySpeed.m_fSpeed >= 550.0) then
					MonkeySpeedBar:SetVertexColor(0, 0, 1);
				end
			end
		end

		MonkeySpeed.m_vLastPos.x = MonkeySpeed.m_vCurrPos.x;
		MonkeySpeed.m_vLastPos.y = MonkeySpeed.m_vCurrPos.y;
		MonkeySpeed.m_vLastPos.z = MonkeySpeed.m_vCurrPos.z;
	end
end

-- when the mouse goes over the main frame, this gets called
function MonkeySpeed_OnEnter()
	-- put the tool tip in the default position
	GameTooltip_SetDefaultAnchor(GameTooltip, this);
	
	-- set the tool tip text
	GameTooltip:SetText(MONKEYSPEED_TITLE_VERSION, MONKEYLIB_TITLE_COLOUR.r, MONKEYLIB_TITLE_COLOUR.g, MONKEYLIB_TITLE_COLOUR.b, 1);
	GameTooltip:AddLine(MONKEYSPEED_DESCRIPTION, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, 1);
	GameTooltip:Show();
end

function MonkeySpeed_OnMouseDown(arg1)
	-- if not loaded yet then get out
	if (MonkeySpeed.m_bLoaded == false) then
		return;
	end
	
	if (arg1 == "LeftButton" and MonkeySpeedConfig[MonkeySpeed.m_strPlayer].m_bLocked == false) then
		MonkeySpeedFrame:StartMoving();
	end
	
	-- right button on the title or frame opens up the MonkeyBuddy, if it's there
	if (arg1 == "RightButton") then
		if (MonkeyBuddyFrame ~= nil and MonkeySpeedConfig[MonkeySpeed.m_strPlayer].m_bAllowRightClick == true) then
			ShowUIPanel(MonkeyBuddyFrame);
			
			-- make MonkeyBuddy show the MonkeySpeed config
			MonkeyBuddySpeedTab_OnClick();
		end
	end
end

function MonkeySpeed_OnMouseUp(arg1)
	-- if not loaded yet then get out
	if (MonkeySpeed.m_bLoaded == false) then
		return;
	end
	
	if (arg1 == "LeftButton") then
		MonkeySpeedFrame:StopMovingOrSizing();
	end
end

function MonkeySpeed_ParsePosition(position)
	local x, y, z;
	local iStart, iEnd;

	iStart, iEnd, x, y = string.find(position, "^(.-), (.-)$");

	if( x ) then
		return x + 0.0, y + 0.0;
	end
	return nil, nil;
end

function MonkeySpeed_Round(x)
	if(x - floor(x) > 0.5) then
		x = x + 0.5;
	end
	return floor(x);
end

function MonkeySpeedOptions()

	if (IsAddOnLoaded("MonkeyBuddy") == nil) then
	
	-- Create main frame for information text
	local MonkeySpeedOptions = CreateFrame("FRAME", "MonkeySpeedOptions")
	MonkeySpeedOptions.name = MONKEYSPEED_TITLE
	--InterfaceOptions_AddCategory(MonkeySpeedOptions)
	
	function MonkeySpeedOptions.default()
		MonkeySpeed_ResetConfig();
	end

	local MonkeySpeedOptionsText1 = MonkeySpeedOptions:CreateFontString(nil, "ARTWORK")
	MonkeySpeedOptionsText1:SetFontObject(GameFontNormalLarge)
	MonkeySpeedOptionsText1:SetJustifyH("LEFT") 
	MonkeySpeedOptionsText1:SetJustifyV("TOP")
	MonkeySpeedOptionsText1:ClearAllPoints()
	MonkeySpeedOptionsText1:SetPoint("TOPLEFT", 16, -16)
	MonkeySpeedOptionsText1:SetText(MONKEYSPEED_TITLE_VERSION)

	local MonkeySpeedOptionsText2 = MonkeySpeedOptions:CreateFontString(nil, "ARTWORK")
	MonkeySpeedOptionsText2:SetFontObject(GameFontNormalSmall)
	MonkeySpeedOptionsText2:SetJustifyH("LEFT") 
	MonkeySpeedOptionsText2:SetJustifyV("TOP")
	MonkeySpeedOptionsText2:SetTextColor(1, 1, 1)
	MonkeySpeedOptionsText2:ClearAllPoints()
	MonkeySpeedOptionsText2:SetPoint("TOPLEFT", MonkeySpeedOptionsText1, "BOTTOMLEFT", 8, -16)
	MonkeySpeedOptionsText2:SetWidth(340)
	MonkeySpeedOptionsText2:SetText(MONKEYSPEED_OPTIONS1)

	local MonkeySpeedOptionsText3 = MonkeySpeedOptions:CreateFontString(nil, "ARTWORK")
	MonkeySpeedOptionsText3:SetFontObject(GameFontNormalLarge)
	MonkeySpeedOptionsText3:SetJustifyH("LEFT") 
	MonkeySpeedOptionsText3:SetJustifyV("TOP")
	MonkeySpeedOptionsText3:SetTextColor(1, 0.65, 0)
	MonkeySpeedOptionsText3:ClearAllPoints()
	MonkeySpeedOptionsText3:SetPoint("TOPLEFT", MonkeySpeedOptionsText2, "BOTTOMLEFT", 0, -16)
	MonkeySpeedOptionsText3:SetWidth(340)
	MonkeySpeedOptionsText3:SetText(MONKEYSPEED_OPTIONS2)
	
	end

end
