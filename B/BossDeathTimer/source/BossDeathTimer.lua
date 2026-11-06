BINDING_HEADER_CROC = "Boss Death Timer";
BINDING_NAME_BOSSDEATHTIMER = "On/Off";
local target = {};
local isCombat = false;
local deadName = false;
local bossName = false;
local MinimumDamageThreshold = 1000;
local AverageIntervals = 40;
local gfind = string.gmatch or string.gfind;
local ALERT_SECONDS_ACTUAL = {};
local ALERT_SECONDS = {};
local ALERT_SECONDS_DEFAULT = {
	20,
	60
};
local ALERT_COLOR = {
	{
		red = 255,
		green = 209,
		blue = 0
	},
	{
		red = 1,
		green = 0.25,
		blue = 0.25
	},
	{
		red = 1,
		green = 0.5,
		blue = 0
	},
	{
		red = 0.25,
		green = 1,
		blue = 0.25
	},
	{
		red = 1,
		green = 0.5,
		blue = 1
	},
	{
		red = 0.67,
		green = 0.67,
		blue = 1
	},
	{
		red = 1,
		green = 1,
		blue = 1
	}
};
local function Print(msg)
	if not DEFAULT_CHAT_FRAME then
		return;
	end;
	DEFAULT_CHAT_FRAME:AddMessage(msg);
end;
local function ResetTextColor()
	DeathTimerText:SetVertexColor(ALERT_COLOR[1].red, ALERT_COLOR[1].green, ALERT_COLOR[1].blue);
end;
local function ResetTargetStats(targetEntry)
	targetEntry.healthLossHistory = {};
	targetEntry.averageHealthLoss = 0;
	targetEntry.lastHealth = UnitHealth("target");
	targetEntry.lastTime = GetTime();
	ResetTextColor();
end;
local function AlertOnSecond(sec)
	local numAlertSeconds = table.getn(ALERT_SECONDS);
	for i, v in ipairs(ALERT_SECONDS) do
		if ALERT_COLOR[numAlertSeconds + 1] then
			if isCombat and sec < v then
				DeathTimerText:SetVertexColor(ALERT_COLOR[i + 1].red, ALERT_COLOR[i + 1].green, ALERT_COLOR[i + 1].blue);
				break;
			end;
		else
			ResetTextColor();
		end;
	end;
	for i, v in ipairs(ALERT_SECONDS) do
		if isCombat and sec < v and ALERT_SECONDS_ACTUAL[i] and ALERT_SECONDS_ACTUAL[i].timeStamp == 0 then
			ALERT_SECONDS_ACTUAL[i].targetValue = v;
			ALERT_SECONDS_ACTUAL[i].timeStamp = GetTime();
			break;
		end;
	end;
end;
local function ToggleDeathTimer()
	if DeathTimerFrame:IsVisible() then
		DeathTimerFrame:Hide();
	else
		DeathTimerText:SetText("1:23:45");
		ResetTextColor();
		DeathTimerFrame:Show();
	end;
end;
local function ChangeFontSize(size)
	DeathTimerText:SetFontObject(GameFontNormalHugeOutline);
	DeathTimerText:SetFont(DeathTimerText:GetFont(), size);
	DeathTimerTargetButton:SetWidth(size * 5);
	DeathTimerTargetButton:SetHeight(size * 1.5);
	DeathTimerFrame:SetWidth(DeathTimerTargetButton:GetWidth());
	DeathTimerFrame:SetHeight(DeathTimerTargetButton:GetHeight());
end;
local function SetupDefault()
	if DCT_FONTSIZE then
		ChangeFontSize(DCT_FONTSIZE);
	else
		ChangeFontSize(25);
		DCT_FONTSIZE = 25;
	end;
	if DCT_MINDMG then
		MinimumDamageThreshold = DCT_MINDMG;
	else
		DCT_MINDMG = 1000;
	end;
	if DCT_INTERVAL then
		AverageIntervals = DCT_INTERVAL;
	else
		DCT_INTERVAL = 40;
	end;
	if DCT_ALERT_SECONDS then
		ALERT_SECONDS = DCT_ALERT_SECONDS;
	else
		ALERT_SECONDS = ALERT_SECONDS_DEFAULT;
		DCT_ALERT_SECONDS = ALERT_SECONDS_DEFAULT;
	end;
end;
local function CalculateAverageHealthLoss(targetEntry, healthLost, timeElapsed)
	local windowSize = AverageIntervals;
	table.insert(targetEntry.healthLossHistory, {
		loss = healthLost,
		time = timeElapsed
	});
	if table.getn(targetEntry.healthLossHistory) > windowSize then
		table.remove(targetEntry.healthLossHistory, 1);
	end;
	local totalHealthLoss = 0;
	local totalTime = 0;
	for _, entry in ipairs(targetEntry.healthLossHistory) do
		totalHealthLoss = totalHealthLoss + entry.loss;
		totalTime = totalTime + entry.time;
	end;
	targetEntry.averageHealthLoss = totalHealthLoss / totalTime;
end;
local function DisplayEstimatedTime(targetEntry, currentHealth)
	if not targetEntry.averageHealthLoss or targetEntry.averageHealthLoss <= 0 then
		DeathTimerText:SetText(text);
		return;
	end;
	local secondsToLive = math.ceil(currentHealth / targetEntry.averageHealthLoss);
	local hoursToLive = math.floor(secondsToLive / 3600);
	local secondsRemaining = secondsToLive - math.floor(secondsToLive / 3600) * 3600;
	local minutesToLive = math.floor(secondsRemaining / 60);
	local remainingSeconds = secondsRemaining - math.floor(secondsRemaining / 60) * 60;
	local formattedTime = string.format("%02d:%02d:%02d", hoursToLive, minutesToLive, remainingSeconds);
	DeathTimerText:SetText(formattedTime);
	AlertOnSecond(secondsToLive);
end;
function DeathTimer_OnLoad()
	this:RegisterEvent("ADDON_LOADED");
	this:RegisterEvent("VARIABLES_LOADED");
	this:RegisterEvent("PLAYER_LOGIN");
	this:RegisterEvent("UNIT_HEALTH");
	this:RegisterEvent("PLAYER_REGEN_ENABLED");
	this:RegisterEvent("PLAYER_REGEN_DISABLED");
	this:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH");
end;
function DeathTimer_OnEvent(event)
	if event == "ADDON_LOADED" or event == "VARIABLES_LOADED" or event == "PLAYER_LOGIN" then
		Print("Boss Death Timer Loaded.");
		SetupDefault();
	elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
		deadName = string.match(arg1, "^(.-) dies%.$");
		if deadName and bossName and deadName == bossName then
			local deathTime = GetTime();
			Print("<Boss DeathTimer Report: " .. bossName .. " >");
			Print("Estimated Time -- Actual Time");
			for i, v in ipairs(ALERT_SECONDS_ACTUAL) do
				local diffTime = deathTime - v.timeStamp;
				local formattedDiffTime = string.format("%.1f", diffTime);
				Print(v.targetValue .. " -- " .. formattedDiffTime);
			end;
			Print("To accurise the timer, try '/bdt learn'.");
		end;
	elseif event == "PLAYER_REGEN_DISABLED" then
		isCombat = true;
		bossName = false;
		SetupDefault();
		ResetTargetStats(target);
		if ALERT_SECONDS_ACTUAL == nil then
			ALERT_SECONDS_ACTUAL = {};
		end;
		for i, v in ipairs(ALERT_SECONDS) do
			if not ALERT_SECONDS_ACTUAL[i] then
				ALERT_SECONDS_ACTUAL[i] = {
					targetValue = v,
					timeStamp = 0
				};
			end;
		end;
	elseif event == "PLAYER_REGEN_ENABLED" then
		isCombat = false;
		ResetTargetStats(target);
		ALERT_SECONDS_ACTUAL = {};
		ResetTextColor();
		DeathTimerFrame:Hide();
	elseif event == "UNIT_HEALTH" and isCombat then
		local targetExist = UnitExists("target");
		local targetLevel = UnitLevel("target");
		if not targetExist or targetLevel ~= (-1) then
			return;
		end;
		if not DeathTimerFrame:IsVisible() then
			DeathTimerFrame:Show();
		end;
		local targetName = UnitName("target");
		bossName = targetName;
		local currentHealth = UnitHealth("target");
		local healthLost = target.lastHealth - currentHealth;
		if healthLost > MinimumDamageThreshold or healthLost < 0 then
			local currentTime = GetTime();
			local timeElapsed = currentTime - target.lastTime;
			CalculateAverageHealthLoss(target, healthLost, timeElapsed);
			DisplayEstimatedTime(target, currentHealth);
			target.lastHealth = currentHealth;
			target.lastTime = currentTime;
		end;
	end;
end;
SLASH_BOSSDEATHTIMER1 = "/bdt";
SlashCmdList.BOSSDEATHTIMER = function(msg)
	local commandlist = {};
	for command in gfind(msg, "[^ ]+") do
		table.insert(commandlist, string.lower(command));
	end;
	local action = commandlist[1];
	if action == "fontsize" then
		local size = tonumber(commandlist[2]);
		if size then
			ChangeFontSize(size);
			DCT_FONTSIZE = size;
			print("Fontsize is set to: " .. size);
		else
			print("Invalid font size. Please provide a number.");
		end;
	elseif action == "list" then
		Print("Current seconds to alarm are:");
		for i, v in ipairs(ALERT_SECONDS) do
			Print(i .. "-" .. v);
		end;
	elseif action == "add" then
		if isCombat then
			Print("You CANNOT do this action in COMBAT");
			return;
		end;
		local valueToAdd = tonumber(commandlist[2]);
		table.insert(ALERT_SECONDS, valueToAdd);
		table.sort(ALERT_SECONDS, function(a, b)
			return a < b;
		end);
		Print("Value: '" .. valueToAdd .. "' is added. Now:");
		for i, v in ipairs(ALERT_SECONDS) do
			Print(i .. "-" .. v);
		end;
		DCT_ALERT_SECONDS = ALERT_SECONDS;
	elseif action == "delete" then
		if isCombat then
			Print("You CANNOT do this action in COMBAT");
			return;
		end;
		local valueToRemove = tonumber(commandlist[2]);
		local function findIndex(tbl, value)
			for i, v in ipairs(tbl) do
				if v == value then
					return i;
				end;
			end;
			return nil;
		end;
		local index = findIndex(ALERT_SECONDS, valueToRemove);
		if index then
			table.remove(ALERT_SECONDS, index);
			Print("Value: '" .. valueToRemove .. "' is deleted. Now:");
			for i, v in ipairs(ALERT_SECONDS) do
				Print(i .. "-" .. v);
			end;
		else
			Print("Value: '" .. valueToRemove .. "' is not found. T_T");
		end;
		DCT_ALERT_SECONDS = ALERT_SECONDS;
	elseif action == "health" then
		local health = tonumber(commandlist[2]);
		if health then
			MinimumDamageThreshold = health;
			DCT_MINDMG = health;
			print("Minimum damage threshold set to: " .. MinimumDamageThreshold);
		else
			print("Invalid damage threshold. Please provide a number.");
		end;
	elseif action == "average" then
		local average = tonumber(commandlist[2]);
		if average then
			AverageIntervals = average;
			DCT_INTERVAL = average;
			print("Average intervals set to: " .. AverageIntervals);
		else
			print("Invalid average intervals. Please provide a number.");
		end;
	elseif action == "reset" then
		if isCombat then
			Print("You CANNOT do this action in COMBAT");
			return;
		end;
		DCT_FONTSIZE = 25;
		DCT_MINDMG = 1000;
		DCT_INTERVAL = 40;
		DCT_ALERT_SECONDS = ALERT_SECONDS_DEFAULT;
		ALERT_SECONDS = ALERT_SECONDS_DEFAULT;
		ChangeFontSize(DCT_FONTSIZE);
		MinimumDamageThreshold = DCT_MINDMG;
		AverageIntervals = DCT_INTERVAL;
		print("Settings reset to default values.");
		print("Font size: 20");
		print("Minimum damage threshold: 1000");
		print("Average intervals: 40");
	elseif action == "toggle" then
		ToggleDeathTimer();
		print("You can show or hide the addon by '/bdt toggle'.");
	elseif action == "learn" then
		Print("Visit github to learn how this addon works.");
		Print("https://github.com/ZenSociety/BossDeathTimer");
	elseif action == "about" then
		print("Death Timer");
		print("- 1.0 - A simple countdown timer that displays how long the boss will die.");
		print("- Command '/bdt toggle' to make it visible.");
		print("- Author: Croc");
	else
		print("Available commands are:");
		print("/bdt toggle, list, add, delete, fontsize, health, average, reset, learn, about.");
		Print("Current Key Settings:");
		Print("health: " .. MinimumDamageThreshold);
		Print("average: " .. AverageIntervals);
	end;
end;
