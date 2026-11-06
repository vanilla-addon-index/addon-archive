-- Deathlog.lua
-- Deathlog for Vanilla WoW
-- Death heatmap overlay for the world map with danger indicator
-- Based on aaronma37/Deathlog (WoW Classic) and DaniilSokolyuk/RipMap

-- SavedVariables (defined in .toc)
Deathlog_Settings = Deathlog_Settings or {}

-- Default settings
local function InitializeSettings()
    if Deathlog_Settings.indicatorVisible == nil then
        Deathlog_Settings.indicatorVisible = true
    end
    if Deathlog_Settings.heatmapVisible == nil then
        Deathlog_Settings.heatmapVisible = true
    end
    if Deathlog_Settings.warningEnabled == nil then
        Deathlog_Settings.warningEnabled = true
    end
end

-- Main addon initialization
local indicatorFrame = nil
local indicatorTexture = nil
local updateTimer = 0
local UPDATE_INTERVAL = 1.0  -- Update every second

-- Function to save indicator position
local function SaveIndicatorPosition()
    if indicatorFrame then
        local point, relativeTo, relativePoint, xOfs, yOfs = indicatorFrame:GetPoint()
        Deathlog_Settings.indicatorPoint = point
        Deathlog_Settings.indicatorRelPoint = relativePoint
        Deathlog_Settings.indicatorX = xOfs
        Deathlog_Settings.indicatorY = yOfs
    end
end

-- Function to restore indicator position
local function RestoreIndicatorPosition()
    if indicatorFrame and Deathlog_Settings.indicatorX then
        indicatorFrame:ClearAllPoints()
        indicatorFrame:SetPoint(
            Deathlog_Settings.indicatorPoint or "TOP",
            UIParent,
            Deathlog_Settings.indicatorRelPoint or "TOP",
            Deathlog_Settings.indicatorX or 0,
            Deathlog_Settings.indicatorY or -30
        )
    end
end

-- Function to create or update the danger indicator
function CreateDangerIndicator()
    if not indicatorFrame then
        -- Create the indicator frame (50x20 pixels, 30px from top)
        indicatorFrame = CreateFrame("Frame", "DeathlogIndicator", UIParent)
        indicatorFrame:SetWidth(50)
        indicatorFrame:SetHeight(20)
        indicatorFrame:SetFrameStrata("HIGH")
        indicatorFrame:SetFrameLevel(100)

        -- Position at top center (30px from top) - default position
        indicatorFrame:SetPoint("TOP", UIParent, "TOP", 0, -30)

        -- Use backdrop for solid color (works better in 1.12)
        indicatorFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        -- Set initial color to bright green
        indicatorFrame:SetBackdropColor(0, 1, 0, 1)
        indicatorFrame:SetBackdropBorderColor(0, 0, 0, 1)

        -- Make frame movable with Shift + Left Mouse
        indicatorFrame:SetMovable(true)
        indicatorFrame:EnableMouse(true)
        indicatorFrame:RegisterForDrag("LeftButton")

        indicatorFrame:SetScript("OnDragStart", function()
            if IsShiftKeyDown() then
                indicatorFrame:StartMoving()
            end
        end)

        indicatorFrame:SetScript("OnDragStop", function()
            indicatorFrame:StopMovingOrSizing()
            -- Save position when dragging stops
            SaveIndicatorPosition()
        end)

        -- Indicator created
    end

    -- Show the frame
    indicatorFrame:Show()
end

-- Track last zone to avoid spam
local lastZoneName = nil
local lastDangerLevel = nil

-- Function to update indicator color based on location
function UpdateIndicatorColor()
    if not indicatorFrame then return end

    -- Get zone name and try to find map ID
    local zoneName = GetRealZoneText()
    local mapId = nil

    if zoneName then
        mapId = ZoneIDs[zoneName]
    end

    local playerX, playerY = GetPlayerMapPosition("player")

    -- Track zone changes (no message, just update tracking)
    if zoneName and zoneName ~= lastZoneName then
        lastZoneName = zoneName
        lastDangerLevel = nil  -- Reset danger level on zone change
    end

    if not mapId or not playerX or not playerY or (playerX == 0 and playerY == 0) then
        -- No position data, set to gray
        indicatorFrame:SetBackdropColor(0.5, 0.5, 0.5, 0.8)
        return
    end

    -- Convert to map coordinates (0-1000 range)
    local mapX = playerX * 1000
    local mapY = playerY * 1000

    -- Get death count at this location
    local deathCount = GetDeathCountAt(mapId, mapX, mapY)
    local maxDeaths = GetMaxDeaths(mapId)

    -- Calculate color based on death density
    local ratio = 0
    if maxDeaths > 0 then
        ratio = deathCount / maxDeaths
    end

    -- Determine danger level
    -- Thresholds adjusted to match heatmap coloring (intensity * 4 for color gradient)
    -- Heatmap: intensity 0.05 = yellow, 0.10 = orange, 0.20+ = red
    local dangerLevel = "Safe"
    if ratio <= 0.03 then
        -- Safe (green) - very low death density
        indicatorFrame:SetBackdropColor(0, 1, 0, 0.9)
        dangerLevel = "Safe"
    elseif ratio <= 0.08 then
        -- Caution (yellow) - matches yellow heatmap areas
        indicatorFrame:SetBackdropColor(1, 1, 0, 0.9)
        dangerLevel = "Caution"
    elseif ratio <= 0.18 then
        -- Dangerous (orange) - matches orange heatmap areas
        indicatorFrame:SetBackdropColor(1, 0.5, 0, 0.9)
        dangerLevel = "Dangerous"
    else
        -- Very dangerous (red) - matches red heatmap areas
        indicatorFrame:SetBackdropColor(1, 0, 0, 0.9)
        dangerLevel = "VERY DANGEROUS"
    end

    -- Only warn when entering dangerous areas (orange/red)
    if dangerLevel ~= lastDangerLevel then
        lastDangerLevel = dangerLevel
        -- Only show message for Dangerous and VERY DANGEROUS (if warnings enabled)
        if Deathlog_Settings.warningEnabled then
            if dangerLevel == "Dangerous" then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff8000Deathlog:|r Dangerous area!")
            elseif dangerLevel == "VERY DANGEROUS" then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Deathlog:|r VERY DANGEROUS!")
            end
        end
    end
end

-- Function to handle addon load
function Deathlog_OnLoad()
    -- Initialize default settings
    InitializeSettings()

    -- Create the danger indicator
    CreateDangerIndicator()

    -- Restore saved position
    RestoreIndicatorPosition()

    -- Apply saved visibility settings
    if indicatorFrame then
        if Deathlog_Settings.indicatorVisible then
            indicatorFrame:Show()
        else
            indicatorFrame:Hide()
        end
    end

    -- Apply heatmap visibility (global variable used by HeatmapRenderer)
    Deathlog_HeatVisible = Deathlog_Settings.heatmapVisible

    -- Preload common maps for faster loading
    PreloadCommonMaps()

    -- Print short welcome message
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Deathlog|r for Vanilla WoW loaded. Type |cff00ff00/dl|r for commands.")
end

-- Function to update on each frame
function Deathlog_OnUpdate()
    -- In WoW 1.12, elapsed time is passed via arg1, not as a parameter
    if not arg1 then return end
    updateTimer = updateTimer + arg1

    if updateTimer >= UPDATE_INTERVAL then
        UpdateIndicatorColor()
        updateTimer = 0
    end
end

-- Helper function to show status
local function ShowStatus()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Deathlog|r - Current Settings:")

    local indicatorStatus = Deathlog_Settings.indicatorVisible and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    local heatmapStatus = Deathlog_Settings.heatmapVisible and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    local warningStatus = Deathlog_Settings.warningEnabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"

    DEFAULT_CHAT_FRAME:AddMessage("  Indicator: " .. indicatorStatus)
    DEFAULT_CHAT_FRAME:AddMessage("  Heatmap: " .. heatmapStatus)
    DEFAULT_CHAT_FRAME:AddMessage("  Warning: " .. warningStatus)
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("Commands:")
    DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/dl indicator|r - Toggle danger indicator")
    DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/dl heatmap|r - Toggle heatmap overlay")
    DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/dl warning|r - Toggle chat warnings")
    DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/dl reset|r - Reset indicator position")
end

-- Helper function to toggle indicator
local function ToggleIndicator()
    Deathlog_Settings.indicatorVisible = not Deathlog_Settings.indicatorVisible

    if indicatorFrame then
        if Deathlog_Settings.indicatorVisible then
            indicatorFrame:Show()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Deathlog:|r Indicator |cff00ff00enabled|r")
        else
            indicatorFrame:Hide()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Deathlog:|r Indicator |cffff0000disabled|r")
        end
    end
end

-- Helper function to toggle heatmap (updates global and saves setting)
local function ToggleHeatmapSetting()
    Deathlog_Settings.heatmapVisible = not Deathlog_Settings.heatmapVisible
    Deathlog_HeatVisible = Deathlog_Settings.heatmapVisible

    -- Call the HeatmapRenderer toggle function
    if ToggleHeatmap then
        -- Sync the global variable before toggle (ToggleHeatmap will flip it)
        Deathlog_HeatVisible = not Deathlog_Settings.heatmapVisible
        ToggleHeatmap()
    else
        if Deathlog_Settings.heatmapVisible then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Deathlog:|r Heatmap |cff00ff00enabled|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Deathlog:|r Heatmap |cffff0000disabled|r")
        end
    end
end

-- Helper function to toggle warnings
local function ToggleWarning()
    Deathlog_Settings.warningEnabled = not Deathlog_Settings.warningEnabled

    if Deathlog_Settings.warningEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Deathlog:|r Chat warnings |cff00ff00enabled|r")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Deathlog:|r Chat warnings |cffff0000disabled|r")
    end
end

-- Slash command handler
SLASH_DEATHLOG1 = "/deathlog"
SLASH_DEATHLOG2 = "/dl"
SlashCmdList["DEATHLOG"] = function(msg)
    if not msg then msg = "" end
    msg = string.lower(msg)

    if msg == "indicator" then
        ToggleIndicator()
    elseif msg == "heatmap" then
        ToggleHeatmapSetting()
    elseif msg == "warning" then
        ToggleWarning()
    elseif msg == "reset" then
        -- Reset indicator position to default
        if indicatorFrame then
            indicatorFrame:ClearAllPoints()
            indicatorFrame:SetPoint("TOP", UIParent, "TOP", 0, -30)
            SaveIndicatorPosition()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Deathlog:|r Indicator position reset")
    else
        -- Show status/help
        ShowStatus()
    end
end

-- Keep /hm as shortcut for heatmap toggle
SLASH_HEATMAP1 = "/heatmap"
SLASH_HEATMAP2 = "/hm"
SlashCmdList["HEATMAP"] = function(msg)
    ToggleHeatmapSetting()
end

-- Create update frame
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", Deathlog_OnUpdate)

-- Combine all event handlers into one function
-- In WoW 1.12, event handlers use global variables: event, arg1, arg2, etc.
local function OnEvent()
    if event == "ADDON_LOADED" and arg1 == "Deathlog_Vanilla" then
        Deathlog_OnLoad()
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        UpdateIndicatorColor()
        -- Note: Heatmap updates are handled by HeatmapRenderer via WORLD_MAP_UPDATE
    end
end

-- Register events and set handler
updateFrame:RegisterEvent("ADDON_LOADED")
updateFrame:RegisterEvent("ZONE_CHANGED")
updateFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
updateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
updateFrame:SetScript("OnEvent", OnEvent)

-- Create indicator immediately on file load
CreateDangerIndicator()
