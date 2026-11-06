----------------------------------------------------------------
-- EVTCalendar
-- Author: Reed
--
--
----------------------------------------------------------------

previousMobs = {};
killTimes = {};

function M2L_OnLoad()
    this:RegisterEvent("ADDON_LOADED");
	this:RegisterEvent("PLAYER_XP_UPDATE");
    this:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN");
end

function M2L_OnEvent()
	if event == "CHAT_MSG_COMBAT_XP_GAIN" then
		if string.find(arg1, "(.+) dies") then
			local _, _, killedMob, XPGain = string.find(arg1, "(.+) dies, you gain (%d+) experience.");
			if GetXPExhaustion() then
				table.insert(previousMobs, math.floor(XPGain/2));
				table.insert(killTimes,time());
			else
				table.insert(previousMobs, math.floor(XPGain));
				table.insert(killTimes,time());
			end
			if table.getn(previousMobs) > 3 then
				table.remove(previousMobs, 1);
			end
			if table.getn(killTimes) > 10 then
				table.remove(killTimes, 1);
			end
			M2L_Calc(XPGain);
		end
	elseif event == "PLAYER_XP_UPDATE" then
		M2L_Calc();
	end
end

function M2L_Calc(XPGain)
	local restToGo, killsToGo;
	local avgXP = 0;
	
	if not XPGain then
		XPGain = 0;
	end
	
	local restXP = GetXPExhaustion();
	local curXP = UnitXP("player") + XPGain;
	local maxXP = UnitXPMax("player");
	
	if restXP then
		for _,x in pairs(previousMobs) do
			avgXP = avgXP + x;
		end
		avgXP = avgXP / table.getn(previousMobs);
		if restXP > (maxXP - curXP) then
			killsToGo = (maxXP - curXP)/(avgXP*2);
			M2LString:SetText(killsToGo);
		else
			restToGo = (restXP / avgXP);
			killsToGo = (maxXP - curXP - restXP)/(avgXP);
			killsToGo = math.ceil((killsToGo + restToGo));
			M2LString:SetText(killsToGo);
		end
	else
		for _,x in pairs(previousMobs) do
			avgXP = avgXP + x;
		end
		avgXP = avgXP / table.getn(previousMobs);
		killsToGo = math.ceil((maxXP - curXP)/avgXP);
		M2LString:SetText(killsToGo);
	end
	
	local timeStamp = 0;
	local timeDifferences = {};
	for _,x in pairs(killTimes) do
		if (table.getn(killTimes) > _) then
		table.insert(timeDifferences,((killTimes[_+1] - x)));
		end
	end
	for _,x in pairs(timeDifferences) do
		timeStamp = timeStamp + x;
	end
	timeStamp = timeStamp / table.getn(timeDifferences);
	timeStamp = timeStamp * killsToGo;
	M2LTimeString:SetText(tostring(date('%H:%M:%S',timeStamp)));
end

function M2L_print(str, err)
	if err == nil then
		DEFAULT_CHAT_FRAME:AddMessage("|c00FFFF00MobsToLevel: " .. tostring(str) .. "|r");
	else
		DEFAULT_CHAT_FRAME:AddMessage("|c00FFFF00MobsToLevel:|r " .. "|c00FF0000Error|r|c006969FF - " .. tostring(str) .. "|r");
	end
end
