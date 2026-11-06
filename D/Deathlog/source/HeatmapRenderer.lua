-- HeatmapRenderer.lua
-- Renders death heatmap overlays on the main map (Deathlog-style 100x100 grid)

-- Zone ID mappings are loaded from Data\zone_ids.lua via .toc file
-- ZoneIDs table is globally available

-- Heatmap rendering state
local heatmapTextures = {}
Deathlog_HeatVisible = true -- Global for access from other files
local currentMapId = nil
local GRID_SIZE = 100 -- 100x100 grid like Deathlog

-- Create the heatmap overlay frame
local overlayFrame = nil
local heatmapInitialized = false

-- Function to initialize heatmap textures (100x100 grid)
function InitializeHeatmap()
    if heatmapInitialized then
        return
    end

    -- Get WorldMapButton for overlay
    if not WorldMapButton then
        return
    end

    -- Create overlay frame
    overlayFrame = CreateFrame("Frame", "DeathlogHeatOverlay", WorldMapButton)
    overlayFrame:SetAllPoints(WorldMapButton)
    overlayFrame:SetFrameLevel(WorldMapButton:GetFrameLevel() + 1)

    -- Create 100x100 grid of textures
    heatmapTextures = {}
    for x = 1, GRID_SIZE do
        heatmapTextures[x] = {}
        for y = 1, GRID_SIZE do
            local texture = overlayFrame:CreateTexture(nil, "OVERLAY")
            texture:SetDrawLayer("OVERLAY", 6)
            -- Use solid color texture
            texture:SetTexture("Interface\\Buttons\\WHITE8X8")
            texture:SetVertexColor(1.0, 0.1, 0.1, 0)
            texture:Hide()

            -- Store intensity for color calculations
            texture.intensity = 0.0
            heatmapTextures[x][y] = texture
        end
    end

    heatmapInitialized = true
end

-- Function to clear heatmap
function ClearHeatTextures()
    if not heatmapTextures then
        return
    end

    for x = 1, GRID_SIZE do
        if heatmapTextures[x] then
            for y = 1, GRID_SIZE do
                if heatmapTextures[x][y] then
                    heatmapTextures[x][y].intensity = 0.0
                    heatmapTextures[x][y]:SetVertexColor(1.0, 0.1, 0.1, 0)
                    heatmapTextures[x][y]:Hide()
                end
            end
        end
    end
end

-- Function to position heatmap textures
function PositionHeatmapTextures()
    if not overlayFrame or not WorldMapButton then
        return
    end

    local buttonWidth = WorldMapButton:GetWidth()
    local buttonHeight = WorldMapButton:GetHeight()

    -- Calculate cell size - use full map area
    local cellWidth = buttonWidth / GRID_SIZE
    local cellHeight = buttonHeight / GRID_SIZE

    -- Texture size - slightly larger than cell to create overlap
    -- 1.15 = 115% of cell size, overlapping edges create grid effect
    local texWidth = cellWidth * 1.15
    local texHeight = cellHeight * 1.15

    for x = 1, GRID_SIZE do
        for y = 1, GRID_SIZE do
            local texture = heatmapTextures[x][y]
            if texture then
                texture:SetWidth(texWidth)
                texture:SetHeight(texHeight)
                -- Position: full map coverage (0-100%)
                local posX = buttonWidth * x / GRID_SIZE
                local posY = buttonHeight * y / GRID_SIZE
                texture:ClearAllPoints()
                texture:SetPoint("CENTER", overlayFrame, "TOPLEFT", posX, -posY)
            end
        end
    end
end

-- Function to update heatmap for current map
function UpdateHeatmap(mapId)
    -- Initialize if needed
    InitializeHeatmap()

    -- Clear existing heatmap
    ClearHeatTextures()

    -- Get map data
    local mapData = LoadMapData(mapId)
    if not mapData then
        -- No map data for this zone (silent)
        return
    end

    -- Check for intensity data (new format)
    if not mapData.intensity then
        -- Map data missing intensity field (silent)
        return
    end

    -- Store current map ID
    currentMapId = mapId

    -- Position textures
    PositionHeatmapTextures()

    -- Load intensity data into textures
    for x, yData in pairs(mapData.intensity) do
        if heatmapTextures[x] then
            for y, intensity in pairs(yData) do
                if heatmapTextures[x][y] then
                    heatmapTextures[x][y].intensity = intensity
                end
            end
        end
    end

    -- Apply colors based on intensity (Deathlog-style coloring)
    for x = 1, GRID_SIZE do
        for y = 1, GRID_SIZE do
            local texture = heatmapTextures[x][y]
            if texture and texture.intensity > 0.01 then
                -- Calculate alpha (capped at 0.6 like Deathlog)
                local alpha = texture.intensity * 4
                if alpha > 0.6 then
                    alpha = 0.6
                end

                -- Only show if intensity > 0.02
                if texture.intensity > 0.02 then
                    -- Deathlog color calculation:
                    -- R = 1.0 (red)
                    -- G = 1.1 - intensity * 4 (yellow to red gradient)
                    -- B = 0.1 (slight orange tint)
                    local r = 1.0
                    local g = 1.1 - texture.intensity * 4
                    if g < 0 then g = 0 end
                    if g > 1 then g = 1 end
                    local b = 0.1

                    texture:SetVertexColor(r, g, b, alpha)

                    if Deathlog_HeatVisible then
                        texture:Show()
                    end
                else
                    texture:SetVertexColor(1.0, 1.0, 0.1, 0)
                    texture:Hide()
                end
            end
        end
    end

    -- Set overlay visibility
    if overlayFrame then
        if Deathlog_HeatVisible then
            overlayFrame:Show()
        else
            overlayFrame:Hide()
        end
    end
end

-- Function to toggle heatmap visibility
function ToggleHeatmap()
    Deathlog_HeatVisible = not Deathlog_HeatVisible

    -- Sync with saved settings
    if Deathlog_Settings then
        Deathlog_Settings.heatmapVisible = Deathlog_HeatVisible
    end

    if overlayFrame then
        if Deathlog_HeatVisible then
            overlayFrame:Show()
            -- Re-show all textures with intensity
            for x = 1, GRID_SIZE do
                for y = 1, GRID_SIZE do
                    if heatmapTextures[x] and heatmapTextures[x][y] then
                        if heatmapTextures[x][y].intensity > 0.02 then
                            heatmapTextures[x][y]:Show()
                        end
                    end
                end
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Deathlog:|r Heatmap |cff00ff00enabled|r")
        else
            overlayFrame:Hide()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Deathlog:|r Heatmap |cffff0000disabled|r")
        end
    else
        if Deathlog_HeatVisible then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Deathlog:|r Heatmap will be shown when map is opened")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Deathlog:|r Heatmap |cffff0000disabled|r")
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
    return zoneName == "Kalimdor" or zoneName == "Azeroth" or zoneName == "Eastern Kingdoms"
end

-- Function to get zone name from map selection
function GetSelectedMapZoneName()
    local continent = GetCurrentMapContinent()
    local zoneIndex = GetCurrentMapZone()

    if not continent or continent == 0 then
        return nil
    end

    if not zoneIndex or zoneIndex == 0 then
        local mapName = GetMapInfo()
        if mapName and mapName ~= "" then
            return mapName
        end
        return nil
    end

    if not zoneNameCache[continent] then
        zoneNameCache[continent] = { GetMapZones(continent) }
    end

    return zoneNameCache[continent][zoneIndex]
end

-- Function to update heatmap on map change
function OnMapChanged()
    local zoneName = GetSelectedMapZoneName()

    -- If we can't determine zone, keep existing heatmap (don't clear)
    if not zoneName then
        return
    end

    -- Only clear for continent views
    if IsContinentZone(zoneName) then
        ClearHeatTextures()
        currentMapId = nil
        return
    end

    local mapId = GetZoneIDByName(zoneName)

    -- Only update if we have a valid map ID and it's different from current
    if mapId and mapId ~= currentMapId then
        UpdateHeatmap(mapId)
    end
    -- If mapId is nil but we had a previous map, keep showing it
    -- (handles subzone changes within the same zone)
end

-- Register for map events
local mapFrame = CreateFrame("Frame")
mapFrame:RegisterEvent("WORLD_MAP_UPDATE")
mapFrame:SetScript("OnEvent", function()
    if event == "WORLD_MAP_UPDATE" then
        OnMapChanged()
    end
end)

-- Export functions to global scope
Deathlog_UpdateHeatmap = UpdateHeatmap
Deathlog_ToggleHeatmap = ToggleHeatmap
Deathlog_OnMapChanged = OnMapChanged
Deathlog_ClearHeatTextures = ClearHeatTextures
Deathlog_InitializeHeatmap = InitializeHeatmap
