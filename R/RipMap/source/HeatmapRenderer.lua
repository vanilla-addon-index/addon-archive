-- HeatmapRenderer.lua
-- Renders death heatmap overlays on the main map

-- Zone ID mappings are loaded from Data\zone_ids.lua via .toc file
-- ZoneIDs table is globally available

-- Heatmap rendering state
local heatTextures = {}
DiePlease_HeatVisible = true -- Global for access from other files
local currentMapId = nil
local CELL_SIZE = 50         -- Size of each grid cell in map coordinates (0-1000 range)

-- Color gradient definitions
local heatColors = {
    { deaths = 0,  r = 0, g = 0,   b = 0, a = 0 },   -- Transparent
    { deaths = 1,  r = 1, g = 1,   b = 0, a = 0.3 }, -- Yellow
    { deaths = 5,  r = 1, g = 0.5, b = 0, a = 0.5 }, -- Orange
    { deaths = 10, r = 1, g = 0,   b = 0, a = 0.7 }, -- Red
}

-- Function to interpolate color based on death count
function GetHeatColor(deathCount, maxDeaths)
    if maxDeaths <= 0 then
        return heatColors[1] -- Transparent
    end

    local ratio = deathCount / maxDeaths

    -- Find appropriate color based on ratio
    if ratio <= 0.01 then
        return heatColors[1]
    elseif ratio <= 0.25 then
        return heatColors[2]
    elseif ratio <= 0.5 then
        return heatColors[3]
    else
        return heatColors[4]
    end
end

-- Function to clear existing heat textures
function ClearHeatTextures()
    for _, texture in pairs(heatTextures) do
        texture:Hide()
        texture:SetParent(nil)
    end
    heatTextures = {}
end

-- Function to create or update heatmap for current map
function UpdateHeatmap(mapId)
    -- Clear existing textures
    ClearHeatTextures()

    -- Get map data
    local mapData = LoadMapData(mapId)
    if not mapData then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000DiePlease:|r No map data for " .. mapId)
        return
    end

    -- Store current map ID
    currentMapId = mapId

    -- Get WorldMapButton for overlay (not WorldMapFrame!)
    -- WorldMapButton is the actual map display area
    if not WorldMapButton then
        return
    end

    -- Create or get overlay frame
    local overlayFrame = getglobal("DiePleaseHeatOverlay")
    if not overlayFrame then
        overlayFrame = CreateFrame("Frame", "DiePleaseHeatOverlay", WorldMapButton)
        overlayFrame:SetAllPoints(WorldMapButton)
        overlayFrame:SetFrameLevel(WorldMapButton:GetFrameLevel() + 1)
    end

    -- Get button dimensions
    local buttonWidth = WorldMapButton:GetWidth()
    local buttonHeight = WorldMapButton:GetHeight()

    -- Grid uses 0-1000 coordinate system, cells are CELL_SIZE (50) wide
    -- gridX * CELL_SIZE gives position in 0-1000 range
    -- We need to convert to percentage (0-100) then to pixels

    -- Create textures for each grid cell with deaths
    local textureCount = 0
    for gridX, row in pairs(mapData.grid) do
        for gridY, deathCount in pairs(row) do
            if deathCount > 0 then
                textureCount = textureCount + 1
                -- Convert grid coords to percentage (0-100)
                -- gridX * CELL_SIZE / 1000 * 100 = gridX * CELL_SIZE / 10
                local percentX = (gridX * CELL_SIZE) / 10
                local percentY = (gridY * CELL_SIZE) / 10
                local percentWidth = CELL_SIZE / 10
                local percentHeight = CELL_SIZE / 10

                -- Convert percentage to pixels
                local pixelX = percentX / 100 * buttonWidth
                local pixelY = percentY / 100 * buttonHeight
                local pixelWidth = percentWidth / 100 * buttonWidth
                local pixelHeight = percentHeight / 100 * buttonHeight

                -- Create texture
                local texture = overlayFrame:CreateTexture(nil, "ARTWORK")
                texture:SetWidth(pixelWidth)
                texture:SetHeight(pixelHeight)
                texture:SetPoint("TOPLEFT", WorldMapButton, "TOPLEFT", pixelX, -pixelY)

                -- Set color based on death count
                -- In WoW 1.12, use white texture + SetVertexColor for solid colors
                local color = GetHeatColor(deathCount, mapData.maxDeaths)
                texture:SetTexture("Interface\\Buttons\\WHITE8X8")
                texture:SetVertexColor(color.r, color.g, color.b, color.a)

                -- Store texture for cleanup
                table.insert(heatTextures, texture)
            end
        end
    end

    -- Set visibility
    if DiePlease_HeatVisible then
        overlayFrame:Show()
    else
        overlayFrame:Hide()
    end
end

-- Function to toggle heatmap visibility
function ToggleHeatmap()
    DiePlease_HeatVisible = not DiePlease_HeatVisible

    local overlayFrame = getglobal("DiePleaseHeatOverlay")
    if overlayFrame then
        if DiePlease_HeatVisible then
            overlayFrame:Show()
            DEFAULT_CHAT_FRAME:AddMessage("DiePlease: Heatmap enabled")
        else
            overlayFrame:Hide()
            DEFAULT_CHAT_FRAME:AddMessage("DiePlease: Heatmap disabled")
        end
    else
        -- If overlay doesn't exist yet, just show message
        if DiePlease_HeatVisible then
            DEFAULT_CHAT_FRAME:AddMessage("DiePlease: Heatmap will be shown when map is opened")
        else
            DEFAULT_CHAT_FRAME:AddMessage("DiePlease: Heatmap disabled")
        end
    end
end

-- Cache for zone names
local zoneNameCache = {}

-- Function to check if zone is a continent
function IsContinentZone(zoneName)
    if not zoneName then
        return false
    end

    local isContinent = zoneName == "Kalimdor" or zoneName == "Azeroth" or zoneName == "Eastern Kingdoms"
    return isContinent
end

-- Function to get zone name from map selection
function GetSelectedMapZoneName()
    local continent = GetCurrentMapContinent()
    local zoneIndex = GetCurrentMapZone()

    -- Special handling for continent-level views
    -- When viewing a continent, zoneIndex might be 0 or -1
    if not continent or continent == 0 then
        return nil
    end

    -- If zoneIndex is 0 or nil, we're viewing a continent map
    if not zoneIndex or zoneIndex == 0 then
        -- Method 1: Try GetMapInfo() first
        local mapName = GetMapInfo()
        if mapName and mapName ~= "" then
            return mapName
        end

        return nil
    end

    -- Regular zone handling (existing logic)
    if not zoneNameCache[continent] then
        zoneNameCache[continent] = { GetMapZones(continent) }
    end

    local zoneName = zoneNameCache[continent][zoneIndex]
    return zoneName
end

-- Function to update heatmap on map change
function OnMapChanged()
    -- Get zone name from currently selected map
    local zoneName = GetSelectedMapZoneName()

    if not zoneName then
        return
    end

    -- Check if this is a continent - always clear heatmaps for continents
    if IsContinentZone(zoneName) then
        ClearHeatTextures()
        currentMapId = nil
        return
    end

    -- Existing logic for regular zones
    local mapId = GetZoneIDByName(zoneName)
    if mapId and mapId ~= currentMapId then
        UpdateHeatmap(mapId)
    elseif not mapId then
        ClearHeatTextures()
        currentMapId = nil
    end
end

-- Register for map events
local mapFrame = CreateFrame("Frame")
mapFrame:RegisterEvent("WORLD_MAP_UPDATE")
mapFrame:SetScript("OnEvent", function()
    if event == "WORLD_MAP_UPDATE" then
        OnMapChanged()
    end
end)

-- Store: current selected map for external access
DiePlease_CurrentSelectedMap = nil

-- Export functions to global scope
DiePlease_UpdateHeatmap = UpdateHeatmap
DiePlease_ToggleHeatmap = ToggleHeatmap
DiePlease_OnMapChanged = OnMapChanged
DiePlease_ClearHeatTextures = ClearHeatTextures
DiePlease_SetupMapHooks = SetupMapHooks
DiePlease_Initialize = Initialize

-- Update global references for compatibility
UpdateHeatmap = DiePlease_UpdateHeatmap
ToggleHeatmap = DiePlease_ToggleHeatmap
OnMapChanged = DiePlease_OnMapChanged
ClearHeatTextures = DiePlease_ClearHeatTextures
SetupMapHooks = DiePlease_SetupMapHooks
Initialize = DiePlease_Initialize
