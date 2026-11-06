-- DataLoader.lua
-- Handles access to preloaded map death data (Deathlog-style format)

-- Function to get map data (returns from global MapData)
function LoadMapData(mapId)
    if MapData and MapData[mapId] then
        return MapData[mapId]
    end
    return nil
end

-- Function to get intensity at specific coordinates (1-100 range)
function GetIntensityAt(mapId, x, y)
    local mapData = LoadMapData(mapId)
    if not mapData then
        return 0
    end

    if not mapData.intensity then
        return 0
    end

    if mapData.intensity[x] and mapData.intensity[x][y] then
        return mapData.intensity[x][y]
    end

    return 0
end

-- Function to get death count at specific coordinates (for DiePlease.lua compatibility)
-- Converts world coordinates (0-1000) to grid coordinates (1-100)
function GetDeathCountAt(mapId, worldX, worldY)
    -- Convert 0-1000 world coords to 1-100 grid coords
    local gridX = math.floor(worldX / 10) + 1
    local gridY = math.floor(worldY / 10) + 1

    -- Clamp to valid range
    if gridX < 1 then gridX = 1 end
    if gridX > 100 then gridX = 100 end
    if gridY < 1 then gridY = 1 end
    if gridY > 100 then gridY = 100 end

    -- Return intensity scaled to look like death count (0-100)
    local intensity = GetIntensityAt(mapId, gridX, gridY)
    return math.floor(intensity * 100)
end

-- Function to get maximum deaths for a map (for DiePlease.lua compatibility)
function GetMaxDeaths(mapId)
    return 100  -- Intensity is normalized, so max is always 100
end

-- Function to get maximum intensity for a map
function GetMaxIntensity(mapId)
    local mapData = LoadMapData(mapId)
    if not mapData then
        return 0
    end

    return mapData.maxIntensity or 1.0
end

-- Function to get grid size
function GetGridSize(mapId)
    local mapData = LoadMapData(mapId)
    if not mapData then
        return 100
    end

    -- New format uses 100x100 grid
    return 100
end

-- Function to clear cached map data (now no-op since data is preloaded)
function ClearMapCache()
    -- Data is preloaded, no cache to clear
end

-- Function to preload common maps (now no-op since all data is preloaded)
function PreloadCommonMaps()
    -- All data is preloaded
end

-- Export functions to global scope
LoadMapData = LoadMapData
GetIntensityAt = GetIntensityAt
GetMaxIntensity = GetMaxIntensity
GetGridSize = GetGridSize
ClearMapCache = ClearMapCache
PreloadCommonMaps = PreloadCommonMaps
