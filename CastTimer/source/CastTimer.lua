-------------------------------------------------------------------------------------
-- Title: CastTimer
-------------------------------------------------------------------------------------

-- Create "namespace."
CastTimer = {};

-------------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------------

-- Holds the events the helper is interested in receiving.
local listenEvents = {};

-- Used for debugging cast times
local firstCastTime = 0;
local totalCasts = 0;
local duration = 0;
local castStartTime = 0;
local averageClientCastTime = 0;
local numCastsInClientAverage = 0;

-------------------------------------------------------------------------------------
-- Core event handlers.
-------------------------------------------------------------------------------------

-- **********************************************************************************
-- Registers all of the events the helper is interested in.
-- **********************************************************************************
function CastTimer.RegisterEvents()
	-- Register the events we are interested in receiving.
	for k, v in listenEvents do
		CastTimerEventFrame:RegisterEvent(v);
	end
end

-- **********************************************************************************
-- Called when the helper's event frame is loaded.
-- **********************************************************************************
function CastTimer.OnLoad()
	table.insert(listenEvents, "SPELLCAST_INTERRUPTED");      -- Failed  casting
	table.insert(listenEvents, "CHAT_MSG_SPELL_SELF_DAMAGE");
	table.insert(listenEvents, "CHAT_MSG_SPELL_SELF_BUFF");

	-- Register for the ADDON_LOADED event.
	CastTimerEventFrame:RegisterEvent("ADDON_LOADED");
end

function clearStats()
	if (firstCastTime > 0) then
		local avg = duration / totalCasts
		CastTimer.Print(
				"[CastTimer]  Total casts since end of 1st cast: " ..
						totalCasts ..
						" Total duration: " .. string.format("%.3f", duration) .. " Average: " .. string.format("%.3f", avg), 1, 1,
				1)
	end

	CastTimer.Print("Clearing stats")
	castStartTime = 0;
	averageClientCastTime = 0;
	numCastsInClientAverage = 0;
	firstCastTime = 0;
	totalCasts = 0;
end

-------------------------------------------------------------------------------------
-- Printing functions.
-------------------------------------------------------------------------------------

-- **********************************************************************************
-- Prints out the passed message to the default chat frame.
-- **********************************************************************************
function CastTimer.Print(msg, r, g, b)
	-- Add the message to the default chat frame.
	DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b);
end

-- **********************************************************************************
-- Called when the events the helper registered for occur.
-- **********************************************************************************
function CastTimer.OnEvent()
	-- When an addon is loaded.
	if (event == "ADDON_LOADED") then
		-- Make sure it's the right addon.
		if (arg1 == "CastTimer") then
			-- Don't get notification for other addons being loaded.
			this:UnregisterEvent("ADDON_LOADED");

			-- Register for the events the helper is interested in receiving.
			CastTimer.RegisterEvents();

			-- Initialize the helper object.
			CastTimer.Init();
		end
	elseif (event == "CHAT_MSG_SPELL_SELF_DAMAGE" or event == "CHAT_MSG_SPELL_SELF_BUFF") then
		-- only track healing buffs
		if (event == "CHAT_MSG_SPELL_SELF_BUFF" and not string.find(arg1, " heals you ")) then
			return
		end

		local currentTime = GetTime(); -- get current time
		-- if more than 10 seconds have passed since last cast, reset average cast time
		if (currentTime - castStartTime > 10) then
			clearStats()
			firstCastTime = currentTime
			castStartTime = currentTime; -- track start time		castStartTime = currentTime; -- track start time
		elseif (castStartTime > 0) then
			totalCasts = totalCasts + 1
			duration = currentTime - firstCastTime
			local castTime = currentTime - castStartTime;          -- calculate client cast time

			if castTime > 0.5 then
				averageClientCastTime = (averageClientCastTime * numCastsInClientAverage + castTime) /
						(numCastsInClientAverage + 1);                     -- calculate average cast time
				numCastsInClientAverage = numCastsInClientAverage + 1; -- increment number of casts in average
				CastTimer.Print(
						"Client cast time: " ..
								string.format("%.3f", castTime) .. " Average: " .. string.format("%.3f", averageClientCastTime), 1, 1, 1)
				castStartTime = currentTime; -- track start time		castStartTime = currentTime; -- track start time
			else
				CastTimer.Print("Ignoring too short cast time: " ..
						string.format("%.3f", castTime), 1, 1, 1)
				castStartTime = 0; -- track start time
			end
		end
	elseif (event == "SPELLCAST_INTERRUPTED") then
		clearStats()
		CastTimer.Print("Cast interrupted", 1, 1, 1)
	end
end

-- **********************************************************************************
-- Called when the helper is fully loaded.
-- **********************************************************************************
function CastTimer.Init()
	-- Get the name of the player and the player's class.
	playerName = UnitName("player");
	_, playerClass = UnitClass("player");
end
