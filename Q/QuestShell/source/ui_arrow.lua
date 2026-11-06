-- =========================
-- ui_arrow.lua — TomTom Direct (fixed)
-- Uses TomTom Crazy Arrow & waypoints; no bridge, no custom arrow.
-- Lua 5.0 / Vanilla/Turtle safe
-- =========================
QuestShellUI = QuestShellUI or {}

local activeUID = nil

local function warn(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[QuestShell]|r "..tostring(msg))
    end
end

local function TomTomOK()
    return TomTom and Astrolabe and type(TomTom.AddMFWaypoint) == "function"
end

local function CleanZoneName(s)
    if TomTom and TomTom.CleanZoneName then
        return TomTom:CleanZoneName(s or "")
    end
    s = string.lower(s or "")
    s = string.gsub(s, "[^%a%d]", "")
    return s
end

-- Resolve (continent, zone) indices for a map name, else fall back to player's current
local function ResolveContZone(mapName)
    -- Prefer explicit map name via TomTom’s resolver
    if TomTom and TomTom.GetZoneInfo and mapName and mapName ~= "" then
        local cont, zone = TomTom:GetZoneInfo(CleanZoneName(mapName))
        if cont and zone then return cont, zone end
    end
    -- Fallback: Astrolabe current player position
    if Astrolabe and Astrolabe.GetCurrentPlayerPosition then
        local c, z = Astrolabe:GetCurrentPlayerPosition()
        if c and z then return c, z end
    end
    return nil, nil
end

-- -------- Public API --------
function QuestShellUI.ArrowSet(mapName, x, y, title)
    if not TomTomOK() then
        warn("TomTom/Astrolabe not found; arrow disabled.")
        return
    end

    -- Clear previous
    if activeUID and TomTom.RemoveWaypoint then
        TomTom:RemoveWaypoint(activeUID, true)
        activeUID = nil
    end
    if TomTom.ClearCrazyArrow then TomTom:ClearCrazyArrow() end

    local cont, zone = ResolveContZone(mapName)
    if not cont or not zone then
        warn("Could not resolve map '"..tostring(mapName or "").."'; using current zone failed.")
        return
    end

    local fx = tonumber(x) and (x / 100.0) or nil
    local fy = tonumber(y) and (y / 100.0) or nil
    if not fx or not fy then
        warn("Invalid coordinates for TomTom.")
        return
    end
    if fx < 0 then fx = 0 elseif fx > 1 then fx = 1 end
    if fy < 0 then fy = 0 elseif fy > 1 then fy = 1 end

    local uid = TomTom:AddMFWaypoint(cont, zone, fx, fy, {
        title = title or "QuestShell waypoint",
        crazy = true,
        persistent = false,
        silent = true,
    })
    if uid then
        activeUID = uid
        if TomTom.SetArrowWaypoint then TomTom:SetArrowWaypoint(uid) end
    else
        warn("TomTom:AddMFWaypoint failed.")
    end
end

function QuestShellUI.ArrowClear()
    if TomTom and TomTom.ClearCrazyArrow then TomTom:ClearCrazyArrow() end
    if activeUID and TomTom and TomTom.RemoveWaypoint then
        TomTom:RemoveWaypoint(activeUID, true)
        activeUID = nil
    end
end
