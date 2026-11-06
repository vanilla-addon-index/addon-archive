-- ============================================================================
-- script-library.lua - Script Library Service
-- ============================================================================
-- PURPOSE: CRUD and execution of custom GM scripts (Lua functions)
--          that can be sent to players for local evaluation.
--
-- METHODS:
--   EreaRpMasterScriptLibrary:GetAllScripts()          - Sorted array
--   EreaRpMasterScriptLibrary:GetScript(name)          - Lookup by name
--   EreaRpMasterScriptLibrary:SaveScript(name, desc, body) - Create/update
--   EreaRpMasterScriptLibrary:DeleteScript(name)       - Remove
--   EreaRpMasterScriptLibrary:GetScriptCount()         - Count
--   EreaRpMasterScriptLibrary:ValidateScript(body)     - Compile check
--   EreaRpMasterScriptLibrary:ExecuteScript(name, ctx) - Sandbox + pcall
--   EreaRpMasterScriptLibrary:RequestExecution(player, scriptName) - Send to player
--
-- DEPENDENCIES:
--   - EreaRpLibraries:Messaging()
--   - EreaRpLibraries:Logging()
--   - EreaRpMasterDB (SavedVariable)
-- ============================================================================

-- ============================================================================
-- IMPORTS
-- ============================================================================
local messaging = EreaRpLibraries:Messaging()
local Log = EreaRpLibraries:Logging("EreaRpMaster")

-- ============================================================================
-- SERVICE TABLE
-- ============================================================================
EreaRpMasterScriptLibrary = {}

-- Pending script requests (requestId -> {playerName, scriptName, timestamp})
EreaRpMasterScriptLibrary._pendingRequests = {}

-- ============================================================================
-- GetAllScripts - Return sorted array of all scripts
-- ============================================================================
function EreaRpMasterScriptLibrary:GetAllScripts()
    local scripts = {}
    if not EreaRpMasterDB or not EreaRpMasterDB.scriptLibrary then
        return scripts
    end

    for name, script in pairs(EreaRpMasterDB.scriptLibrary) do
        table.insert(scripts, script)
    end

    table.sort(scripts, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    return scripts
end

-- ============================================================================
-- GetScript - Lookup by name
-- ============================================================================
function EreaRpMasterScriptLibrary:GetScript(name)
    if not EreaRpMasterDB or not EreaRpMasterDB.scriptLibrary then
        return nil
    end
    return EreaRpMasterDB.scriptLibrary[name]
end

-- ============================================================================
-- SaveScript - Create or update a script
-- ============================================================================
function EreaRpMasterScriptLibrary:SaveScript(name, description, body)
    if not EreaRpMasterDB then return false end
    if not name or name == "" then return false end

    EreaRpMasterDB.scriptLibrary = EreaRpMasterDB.scriptLibrary or {}
    EreaRpMasterDB.scriptLibrary[name] = {
        name = name,
        description = description or "",
        body = body or ""
    }

    Log("Script saved: " .. name)
    return true
end

-- ============================================================================
-- DeleteScript - Remove a script by name
-- ============================================================================
function EreaRpMasterScriptLibrary:DeleteScript(name)
    if not EreaRpMasterDB or not EreaRpMasterDB.scriptLibrary then
        return false
    end
    if not EreaRpMasterDB.scriptLibrary[name] then
        return false
    end

    EreaRpMasterDB.scriptLibrary[name] = nil
    Log("Script deleted: " .. name)
    return true
end

-- ============================================================================
-- GetScriptCount - Count scripts
-- ============================================================================
function EreaRpMasterScriptLibrary:GetScriptCount()
    if not EreaRpMasterDB or not EreaRpMasterDB.scriptLibrary then
        return 0
    end

    local count = 0
    for _ in pairs(EreaRpMasterDB.scriptLibrary) do
        count = count + 1
    end
    return count
end

-- ============================================================================
-- ValidateScript - Compile check via loadstring()
-- ============================================================================
-- @param body: Lua source code string
-- @returns: ok (boolean), errorMsg (string or nil)
-- ============================================================================
function EreaRpMasterScriptLibrary:ValidateScript(body)
    if not body or body == "" then
        return false, "Script body is empty"
    end

    local fn, err = loadstring(body)
    if not fn then
        return false, err
    end

    return true, nil
end

-- ============================================================================
-- CreateSandboxEnv - Build sandboxed environment for script execution
-- ============================================================================
-- @param context: Optional table with {item, playerName}
-- @returns: Environment table for setfenv
-- ============================================================================
local function CreateSandboxEnv(context)
    local ctx = context or {}
    return {
        -- Safe builtins
        string = string,
        math = math,
        table = table,
        tostring = tostring,
        tonumber = tonumber,
        type = type,
        pairs = pairs,
        ipairs = ipairs,
        unpack = unpack,

        -- WoW read-only APIs
        UnitName = UnitName,
        UnitClass = UnitClass,
        UnitLevel = UnitLevel,
        UnitRace = UnitRace,
        UnitSex = UnitSex,
        GetTime = GetTime,
        date = date,
        random = math.random,
        GetRealZoneText = GetRealZoneText,
        GetZoneText = GetZoneText,
        GetSubZoneText = GetSubZoneText,
        GetPlayerMapPosition = GetPlayerMapPosition,
        GetNumRaidMembers = GetNumRaidMembers,
        GetNumPartyMembers = GetNumPartyMembers,
        UnitIsConnected = UnitIsConnected,
        UnitIsDeadOrGhost = UnitIsDeadOrGhost,

        -- Player monitoring data (direct reference)
        playerStates = EreaRpMaster_PlayerStates,

        -- Context from caller
        item = ctx.item or {},
        player = ctx.playerName or ""
    }
end

-- ============================================================================
-- ExecuteScript - Compile, sandbox, and execute a script
-- ============================================================================
-- @param name: Script name to look up
-- @param context: Optional context table {item, playerName}
-- @returns: ok (boolean), result (string)
-- ============================================================================
function EreaRpMasterScriptLibrary:ExecuteScript(name, context)
    local script = self:GetScript(name)
    if not script then
        return false, "Script not found: " .. tostring(name)
    end

    return self:ExecuteScriptBody(script.body, context)
end

-- ============================================================================
-- ExecuteScriptBody - Execute raw script body in sandbox
-- ============================================================================
-- @param body: Lua source code string
-- @param context: Optional context table {item, playerName}
-- @returns: ok (boolean), result (string)
-- ============================================================================
function EreaRpMasterScriptLibrary:ExecuteScriptBody(body, context)
    if not body or body == "" then
        return false, "Script body is empty"
    end

    local fn, compileErr = loadstring(body)
    if not fn then
        return false, "Compile error: " .. tostring(compileErr)
    end

    -- Sandbox the function
    local env = CreateSandboxEnv(context)
    setfenv(fn, env)

    -- Execute with pcall
    local ok, result = pcall(fn)
    if not ok then
        return false, "Runtime error: " .. tostring(result)
    end

    return true, tostring(result or "nil")
end

-- ============================================================================
-- RequestExecution - Send script request to a player
-- ============================================================================
-- @param playerName: Target player name
-- @param scriptName: Name of script in library
-- @returns: requestId or nil
-- ============================================================================
function EreaRpMasterScriptLibrary:RequestExecution(playerName, scriptName)
    if not playerName or not scriptName then return nil end

    local script = self:GetScript(scriptName)
    if not script then
        Log("RequestExecution: script not found: " .. scriptName)
        return nil
    end

    -- Generate unique request ID
    local requestId = string.format("%d-%d", time(), math.random(10000, 99999))

    -- Store pending request
    self._pendingRequests[requestId] = {
        playerName = playerName,
        scriptName = scriptName,
        timestamp = time()
    }

    -- Send request
    local success = messaging.SendScriptRequestMessage(playerName, scriptName, requestId)
    if success then
        Log("Script request sent: " .. scriptName .. " -> " .. playerName .. " (reqId: " .. requestId .. ")")
    else
        self._pendingRequests[requestId] = nil
        Log("RequestExecution: failed to send script request")
        return nil
    end

    return requestId
end

-- ============================================================================
-- HandleScriptResult - Process incoming script result
-- ============================================================================
-- @param requestId: Request ID from the response
-- @param result: Result string
-- @param sender: Player who sent the result
-- ============================================================================
function EreaRpMasterScriptLibrary:HandleScriptResult(requestId, result, sender)
    local pending = self._pendingRequests[requestId]
    if not pending then
        Log("SCRIPT_RESULT: unknown requestId " .. tostring(requestId) .. " from " .. tostring(sender))
        return
    end

    Log("SCRIPT_RESULT from " .. sender .. " reqId=" .. requestId .. " script=" .. pending.scriptName .. " result=" .. tostring(result))

    -- Clear pending request
    self._pendingRequests[requestId] = nil
end
