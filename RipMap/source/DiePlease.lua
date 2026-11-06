-- DiePlease.lua
-- Death heatmap addon for TurtleWoW
-- Shows death density on maps with danger indicator

DEFAULT_CHAT_FRAME:AddMessage("DiePlease: Loading...")

-- Main addon initialization
local indicatorFrame = nil
local indicatorTexture = nil
local updateTimer = 0
local UPDATE_INTERVAL = 1.0  -- Update every second

-- Function to create or update the danger indicator
function CreateDangerIndicator()
    if not indicatorFrame then
        -- Create the indicator frame (50x20 pixels, 30px from top)
        indicatorFrame = CreateFrame("Frame", "DiePleaseIndicator", UIParent)
        indicatorFrame:SetWidth(50)
        indicatorFrame:SetHeight(20)
        indicatorFrame:SetFrameStrata("HIGH")
        indicatorFrame:SetFrameLevel(100)

        -- Position at top center (30px from top)
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

        DEFAULT_CHAT_FRAME:AddMessage("DiePlease: Indicator created with backdrop!")
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

    -- Debug: print zone change
    if zoneName and zoneName ~= lastZoneName then
        lastZoneName = zoneName
        if mapId then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DiePlease:|r Zone: " .. zoneName .. " (ID: " .. mapId .. ")")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000DiePlease:|r Zone: " .. zoneName .. " - NO DATA")
        end
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
    local dangerLevel = "Safe"
    if ratio <= 0.01 then
        -- Safe (green)
        indicatorFrame:SetBackdropColor(0, 1, 0, 0.9)
        dangerLevel = "Safe"
    elseif ratio <= 0.25 then
        -- Caution (yellow)
        indicatorFrame:SetBackdropColor(1, 1, 0, 0.9)
        dangerLevel = "Caution"
    elseif ratio <= 0.5 then
        -- Dangerous (orange)
        indicatorFrame:SetBackdropColor(1, 0.5, 0, 0.9)
        dangerLevel = "Dangerous"
    else
        -- Very dangerous (red)
        indicatorFrame:SetBackdropColor(1, 0, 0, 0.9)
        dangerLevel = "VERY DANGEROUS"
    end

    -- Print danger level if changed significantly
    if dangerLevel ~= lastDangerLevel then
        lastDangerLevel = dangerLevel
        local color = "|cff00ff00"
        if dangerLevel == "Caution" then color = "|cffffff00"
        elseif dangerLevel == "Dangerous" then color = "|cffff8000"
        elseif dangerLevel == "VERY DANGEROUS" then color = "|cffff0000"
        end
        DEFAULT_CHAT_FRAME:AddMessage(color .. "DiePlease:|r " .. dangerLevel .. " (deaths here: " .. deathCount .. ")")
    end
end

-- Function to handle addon load
function DiePlease_OnLoad()
    -- Create the danger indicator
    CreateDangerIndicator()

    -- Preload common maps for faster loading
    PreloadCommonMaps()

        -- Print welcome message
    DEFAULT_CHAT_FRAME:AddMessage("DiePlease v2.0 loaded - Death heatmap and danger indicator enabled by default")
    DEFAULT_CHAT_FRAME:AddMessage("Commands:")
    DEFAULT_CHAT_FRAME:AddMessage("/dieplease or /dp - Toggle danger indicator")
    DEFAULT_CHAT_FRAME:AddMessage("/heatmap or /hm - Toggle death heatmap")
    DEFAULT_CHAT_FRAME:AddMessage("Shows death heatmap for any zone when map is open")
end

-- Function to update on each frame
function DiePlease_OnUpdate()
    -- In WoW 1.12, elapsed time is passed via arg1, not as a parameter
    if not arg1 then return end
    updateTimer = updateTimer + arg1

    if updateTimer >= UPDATE_INTERVAL then
        UpdateIndicatorColor()
        updateTimer = 0
    end
end

-- Slash command handler
SLASH_DIEPLEASE1 = "/dieplease"
SLASH_DIEPLEASE2 = "/dp"
SlashCmdList["DIEPLEASE"] = function(msg)
    if not msg then msg = "" end

    msg = string.lower(msg)

    if msg == "off" or msg == "hide" then
        if indicatorFrame then
            indicatorFrame:Hide()
        end
        DEFAULT_CHAT_FRAME:AddMessage("DiePlease: Danger indicator hidden")
    elseif msg == "on" or msg == "show" then
        if indicatorFrame then
            indicatorFrame:Show()
        end
        DEFAULT_CHAT_FRAME:AddMessage("DiePlease: Danger indicator shown")
    else
        -- Toggle visibility
        if indicatorFrame and indicatorFrame:IsShown() then
            indicatorFrame:Hide()
            DEFAULT_CHAT_FRAME:AddMessage("DiePlease: Danger indicator hidden")
        else
            if indicatorFrame then
                indicatorFrame:Show()
            end
            DEFAULT_CHAT_FRAME:AddMessage("DiePlease: Danger indicator shown")
        end
    end
end

-- Heatmap toggle command
SLASH_HEATMAP1 = "/heatmap"
SLASH_HEATMAP2 = "/hm"
SlashCmdList["HEATMAP"] = function(msg)
    ToggleHeatmap()
end

-- Map selector toggle command (placeholder - feature not yet implemented)
SLASH_MAPSELECTOR1 = "/mapselect"
SLASH_MAPSELECTOR2 = "/browse"
SlashCmdList["MAPSELECTOR"] = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage("DiePlease: Map selector not yet implemented")
end

-- Create update frame
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", DiePlease_OnUpdate)

-- Combine all event handlers into one function
-- In WoW 1.12, event handlers use global variables: event, arg1, arg2, etc.
local function OnEvent()
    if event == "ADDON_LOADED" and arg1 == "DiePlease" then
        DiePlease_OnLoad()
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        UpdateIndicatorColor()
        -- Auto-show heatmap for current zone if not already showing
        if DiePlease_HeatVisible and WorldMapFrame and WorldMapFrame:IsShown() then
            UpdateHeatmap(GetCurrentMapZone())
        end
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
DEFAULT_CHAT_FRAME:AddMessage("DiePlease: File loaded, indicator created!")