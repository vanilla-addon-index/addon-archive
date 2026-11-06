-- DrunkTracker Addon for WoW Vanilla 1.12.1
-- Tracks drunk states and displays color-coded GUI

local DrunkTracker = {}
local frame = nil
local statusFrame = nil

-- Database for saved variables
DrunkTrackerDB = nil

-- Drunk states
local DRUNK_STATES = {
    SOBER = 0,
    TIPSY = 1,
    DRUNK = 2,
    SMASHED = 3
}

-- Current state
local currentState = DRUNK_STATES.SOBER

-- Chat patterns to match drunk messages
local CHAT_PATTERNS = {
    ["You feel tipsy%.  Whee!"] = DRUNK_STATES.TIPSY,
    ["You feel drunk%.  Woah!"] = DRUNK_STATES.DRUNK,
    ["You feel completely smashed%."] = DRUNK_STATES.SMASHED
}

-- Colors for each state
local STATE_COLORS = {
    [DRUNK_STATES.SOBER] = {r = 0.5, g = 0.5, b = 0.5}, -- Gray
    [DRUNK_STATES.TIPSY] = {r = 1.0, g = 0.0, b = 0.0}, -- Red
    [DRUNK_STATES.DRUNK] = {r = 1.0, g = 1.0, b = 0.0}, -- Yellow
    [DRUNK_STATES.SMASHED] = {r = 0.0, g = 1.0, b = 0.0} -- Green
}

-- State names for display
local STATE_NAMES = {
    [DRUNK_STATES.SOBER] = "Sober",
    [DRUNK_STATES.TIPSY] = "Tipsy",
    [DRUNK_STATES.DRUNK] = "Drunk", 
    [DRUNK_STATES.SMASHED] = "SMASHED!"
}

-- Create the main frame
local function CreateMainFrame()
    frame = CreateFrame("Frame", "DrunkTrackerFrame", UIParent)
    frame:SetWidth(105)
    frame:SetHeight(44)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    -- Set initial backdrop color
    frame:SetBackdropColor(0.5, 0.5, 0.5, 1.0) -- Gray for sober state
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() 
        this:StopMovingOrSizing()
        -- Save position
        local point, relativeTo, relativePoint, xOfs, yOfs = this:GetPoint()
        if DrunkTrackerDB then
            DrunkTrackerDB.position = {
                point = point,
                relativePoint = relativePoint,
                xOfs = xOfs,
                yOfs = yOfs
            }
        end
    end)
    
    -- Create text label directly on main frame
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetText("Sober")
    frame.text = text
    
    
    UpdateGUI()
end

-- Update the GUI based on current state
function UpdateGUI()
    if not frame then return end
    
    local color = STATE_COLORS[currentState]
    local name = STATE_NAMES[currentState]
    
    -- Set backdrop color with full opacity
    frame:SetBackdropColor(color.r, color.g, color.b, 1.0)
    frame.text:SetText(name)
    
    -- Set text color for better visibility
    frame.text:SetTextColor(1, 1, 1) -- White text for all states
end

-- Parse chat messages for drunk state changes
local function OnChatMessage(msg)
    for pattern, state in pairs(CHAT_PATTERNS) do
        if string.find(msg, pattern) then
            local previousState = currentState
            currentState = state
            UpdateGUI()
            
            -- Raid warning when losing smashed state
            if previousState == DRUNK_STATES.SMASHED and state ~= DRUNK_STATES.SMASHED then
                UIErrorsFrame:AddMessage("LOST SMASHED STATE!", 1.0, 0.1, 0.1, 1.0, UIERRORS_HOLD_TIME)
            end
            
            return
        end
    end
end

-- Initialize database with default values
local function InitializeDB()
    if not DrunkTrackerDB then
        DrunkTrackerDB = {
            position = {
                point = "CENTER",
                relativePoint = "CENTER", 
                xOfs = 0,
                yOfs = 200
            }
        }
    end
end

-- Restore saved position
local function RestorePosition()
    if DrunkTrackerDB and DrunkTrackerDB.position and frame then
        local pos = DrunkTrackerDB.position
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    end
end

-- Event handler
local function OnEvent()
    if event == "ADDON_LOADED" then
        if arg1 == "DrunkTracker" then
            InitializeDB()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not frame then
            CreateMainFrame()
            RestorePosition()
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        OnChatMessage(arg1)
    end
end

-- Create event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", OnEvent)

-- Slash commands
SLASH_DRUNKTRACKER1 = "/dt"
SlashCmdList["DRUNKTRACKER"] = function(msg)
    if frame then
        if frame:IsVisible() then
            frame:Hide()
        else
            frame:Show()
        end
    end
end