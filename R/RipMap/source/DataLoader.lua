-- DataLoader.lua
-- Handles access to preloaded map death data

-- Function to get map data (now just returns from global MapData)
function LoadMapData(mapId)
    if MapData and MapData[mapId] then
        return MapData[mapId]
    end
    return nil
end

-- Function to get death count at specific coordinates
function GetDeathCountAt(mapId, x, y)
    local mapData = LoadMapData(mapId)
    if not mapData then
        return 0
    end

    local gridSize = mapData.gridSize or 50
    local gridX = math.floor(x / gridSize)
    local gridY = math.floor(y / gridSize)

    if mapData.grid[gridX] and mapData.grid[gridX][gridY] then
        return mapData.grid[gridX][gridY]
    end

    return 0
end

-- Function to get maximum deaths for a map
function GetMaxDeaths(mapId)
    local mapData = LoadMapData(mapId)
    if not mapData then
        return 0
    end

    return mapData.maxDeaths or 0
end

-- Function to clear cached map data (now no-op since data is preloaded)
function ClearMapCache()
    -- Data is preloaded, no cache to clear
    -- Keeping function for compatibility
end

-- Function to preload common maps (now no-op since all data is preloaded)
function PreloadCommonMaps()
    -- All data is preloaded, nothing to do
    -- Keeping function for compatibility
end

-- Export functions to global scope
LoadMapData = LoadMapData
GetDeathCountAt = GetDeathCountAt
GetMaxDeaths = GetMaxDeaths
ClearMapCache = ClearMapCache
PreloadCommonMaps = PreloadCommonMaps