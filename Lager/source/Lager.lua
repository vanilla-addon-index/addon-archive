local combatLogs = {
    "CombatLogRangeParty",
    "CombatLogRangePartyPet",
    "CombatLogRangeFriendlyPlayers",
    "CombatLogRangeFriendlyPlayersPets",
    "CombatLogRangeHostilePlayers",
    "CombatLogRangeHostilePlayersPets",
    "CombatDeathLogRange"
}

-- Initialize the saved variable
if LagerSaved == nil then
    LagerSaved = true
end

local addonEnabled = LagerSaved

local function Print(msg)
    if not DEFAULT_CHAT_FRAME then
        return
    end
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function PrintColor(msg)
	local r, g, b = 0.2, 0.8, 0.2;
	local hexColor = string.format("|cFF%02X%02X%02X", r * 255, g * 255, b * 255);
	Print(hexColor .. msg);
end;

-- Function to initialize saved variables
local function InitializeSavedVariables()
    addonEnabled = LagerSaved
    if addonEnabled then
        LagerMinimapButtonIcon:SetTexture("Interface\\AddOns\\Lager\\EnabledIcon.png") -- Set the enabled icon
    else
        LagerMinimapButtonIcon:SetTexture("Interface\\AddOns\\Lager\\DisabledIcon.png") -- Set the disabled icon
    end
end


-- Function to handle events
local function OnEvent()
    if event == "PLAYER_ENTERING_WORLD" then
        InitializeSavedVariables()
    end
end

-- Create a frame to register events
local frame = CreateFrame("Frame")

-- Register events
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Set the script to call the OnEvent function when events are triggered
frame:SetScript("OnEvent", OnEvent)

-- Function to update the position of the minimap button while dragging
function LagerMinimapButton_DraggingFrame_OnUpdate()
    local xpos, ypos = GetCursorPosition()
    local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()

    xpos = xmin - xpos / UIParent:GetScale() + 70
    ypos = ypos / UIParent:GetScale() - ymin - 70

    LagerMinimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", xpos, ypos)
end

-- Function to print the current log status
local function PrintCurrentLogStatus()
    for _, log in ipairs(combatLogs) do
        local value = GetCVar(log)
        Print(log .. ": " .. value)
    end
end

local function UpdateLogDistance(value)
    if value == 0 then
        Print("**dps meter might not be working.**")
    end
    for _, log in ipairs(combatLogs) do
        SetCVar(log, value)
    end
    PrintCurrentLogStatus()
end

-- Function to toggle the addon state
local function ToggleAddon()
    LagerSaved = not LagerSaved
    addonEnabled = LagerSaved
    if addonEnabled then
        PrintColor("Lager addon is now ENABLED. The combat logs distance has been set to MINIMUM:")
        UpdateLogDistance(0)
        LagerMinimapButtonIcon:SetTexture("Interface\\AddOns\\Lager\\EnabledIcon.png") -- Set the enabled icon        
    else
        PrintColor("Lager addon is now DISABLED. The combat logs distance has been set to Max:")
        UpdateLogDistance(200)
        LagerMinimapButtonIcon:SetTexture("Interface\\AddOns\\Lager\\DisabledIcon.png") -- Set the disabled icon
    end
end

-- Function to handle mouse down events
function LagerMinimapButton_OnMouseDown(self, myButton)
    if myButton == "RightButton" then
        PrintCurrentLogStatus()
    else
        ToggleAddon()
    end
end

SLASH_LAGER1 = "/lager";
SlashCmdList.LAGER = function(msg)
	local commandlist = {};
	for command in gfind(msg, "[^ ]+") do
		table.insert(commandlist, string.lower(command));
	end;
	local action = commandlist[1];
	if action == "on" then
		LagerSaved = false
		ToggleAddon()
	elseif action == "off" then
        LagerSaved = true
		ToggleAddon()		
	elseif action == "show" then
        PrintColor("Currently, the combat logs distance are:")
		PrintCurrentLogStatus()
    elseif action == "about" then
		Print("Lager - Fixing lag by stopping superfluous combat logs.");
        Print("- Author: Croc");
        Print("- Version: 1.0");
        Print("- Website: https://github.com/ZenSociety/Lager");
    else
		PrintColor("Unknown command.");
		Print("Try: /lager on, off, show, about.");
	end;
end;
