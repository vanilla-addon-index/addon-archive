-- ============================================================================
-- event-handler.lua - Centralized Addon Message Router (GM side)
-- ============================================================================
-- PURPOSE: Registers CHAT_MSG_ADDON and routes all incoming messages to the
--          appropriate presenter or service handler.
--
-- HANDLED MESSAGE TYPES:
--   GIVE_ACCEPT       -> Chat feedback (green) to GM
--   GIVE_REJECT       -> Chat feedback (red) to GM
--   STATUS_RESPONSE   -> Delegate to PlayerMonitorFrame
--   MERGE_TRIGGER     -> Delegate to EreaRpMergeManager
--   CINEMATIC_TRIGGER -> Look up cinematic, broadcast to group
--
-- OUTBOUND API:
--   GiveItem(targetName, itemGuid, customMessage, customText, customNumber)
--
-- DEPENDENCIES:
--   - EreaRpLibraries:Messaging()
--   - EreaRpLibraries:Encoding()
--   - EreaRpMasterPlayerMonitorFrame (for STATUS_RESPONSE delegation)
-- ============================================================================

-- ============================================================================
-- SERVICE TABLE
-- ============================================================================
EreaRpMasterEventHandler = {}

-- ============================================================================
-- IMPORTS
-- ============================================================================
local messaging = EreaRpLibraries:Messaging()
local Log = EreaRpLibraries:Logging("EreaRpMaster")

-- ============================================================================
-- MESSAGE HANDLERS (local)
-- ============================================================================

-- GIVE_ACCEPT: parts = [type, itemName] — sender from arg4
local function HandleGiveAccept(sender, parts)
    local itemName = parts[2] or "unknown item"

    Log("GIVE_ACCEPT from " .. sender .. " for '" .. itemName .. "'")
end

-- GIVE_REJECT: parts = [type, itemName] — sender from arg4
local function HandleGiveReject(sender, parts)
    local itemName = parts[2] or "unknown item"

    Log("GIVE_REJECT from " .. sender .. " for '" .. itemName .. "'")
end

-- CINEMATIC_TRIGGER: parts = [type, cinematicGuid, customText, additionalText, customNumber] — sender from arg4
local function HandleCinematicTrigger(sender, parts)
    local cinematicGuid  = parts[2] or ""
    local customText     = parts[3] or ""
    local additionalText = parts[4] or ""
    local customNumber   = tonumber(parts[5]) or 0

    Log("CINEMATIC_TRIGGER from " .. sender .. " cinematicGuid=" .. cinematicGuid)

    if cinematicGuid == "" then
        Log("CINEMATIC_TRIGGER: empty cinematicGuid, ignoring")
        return
    end

    -- Look up cinematic from GM's library
    if not EreaRpMasterDB or not EreaRpMasterDB.cinematicLibrary then
        Log("CINEMATIC_TRIGGER: cinematicLibrary not initialized")
        return
    end

    local cinematic = EreaRpMasterDB.cinematicLibrary[cinematicGuid]
    if not cinematic then
        Log("CINEMATIC_TRIGGER: cinematic not found: " .. cinematicGuid)
        return
    end

    -- Resolve scripts specified in scriptReferences field
    local scriptValues = {}
    if cinematic.scriptReferences and cinematic.scriptReferences ~= "" then
        -- Parse comma-separated script names (Lua 5.0 compatible)
        local i = 1
        while i <= string.len(cinematic.scriptReferences) do
            local start_name, end_name = string.find(cinematic.scriptReferences, ",", i, true)
            if start_name then
                local scriptName = string.sub(cinematic.scriptReferences, i, start_name - 1)
                local script = EreaRpMasterDB.scriptLibrary and EreaRpMasterDB.scriptLibrary[scriptName]
                if script then
                    local context = {playerName = sender, customText = customText}
                    local ok, result = EreaRpMasterScriptLibrary:ExecuteScriptBody(script.body, context)
                    table.insert(scriptValues, ok and result or "[error]")
                else
                    table.insert(scriptValues, "[script not found]")
                end
                i = end_name + 1
            else
                -- Last script name
                local scriptName = string.sub(cinematic.scriptReferences, i)
                local script = EreaRpMasterDB.scriptLibrary and EreaRpMasterDB.scriptLibrary[scriptName]
                if script then
                    local context = {playerName = sender, customText = customText}
                    local ok, result = EreaRpMasterScriptLibrary:ExecuteScriptBody(script.body, context)
                    table.insert(scriptValues, ok and result or "[error]")
                else
                    table.insert(scriptValues, "[script not found]")
                end
                break
            end
        end
    end

    -- Broadcast cinematic to all players (speakerName looked up from library on player side)
    messaging.SendCinematicBroadcastMessage(cinematicGuid, sender, customText, additionalText, customNumber, scriptValues)
    Log("CINEMATIC_TRIGGER: broadcast sent for " .. cinematicGuid)
end

-- ============================================================================
-- Initialize - Create event frame and register CHAT_MSG_ADDON
-- ============================================================================
function EreaRpMasterEventHandler:Initialize()
    Log("EreaRpMasterEventHandler:Initialize()")

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:SetScript("OnEvent", function()
        -- Lua 5.0: event, arg1..arg4 are globals
        if event ~= "CHAT_MSG_ADDON" then return end

        local prefix  = arg1
        local message = arg2
        local sender  = arg4

        if prefix ~= messaging.ADDON_PREFIX then return end

        Log("RECV from " .. tostring(sender) .. ": " .. tostring(message))

        local msgType, parts = messaging.ParseMessage(message)
        if not msgType then return end

        Log("GM event-handler received msgType=" .. tostring(msgType) .. " from " .. tostring(sender))

        -- Route by message type
        if msgType == messaging.MESSAGE_TYPES.GIVE_ACCEPT then
            HandleGiveAccept(sender, parts)

        elseif msgType == messaging.MESSAGE_TYPES.GIVE_REJECT then
            HandleGiveReject(sender, parts)

        elseif msgType == messaging.MESSAGE_TYPES.STATUS_RESPONSE then
            EreaRpMasterPlayerMonitorFrame:HandleStatusResponse(sender, parts)

        elseif msgType == messaging.MESSAGE_TYPES.MERGE_TRIGGER then
            -- Format: MERGE_TRIGGER^mergeGroupId^objectGuid^customNumber
            local mergeGroupId = parts[2] or ""
            local objectGuid   = parts[3] or ""
            local customNumber = tonumber(parts[4]) or 0
            Log("MERGE_TRIGGER from " .. tostring(sender) .. " mergeGroupId=" .. tostring(mergeGroupId))
            if mergeGroupId ~= "" then
                EreaRpMergeManager:RegisterMergeTrigger(mergeGroupId, sender, objectGuid, customNumber)
            end

        elseif msgType == messaging.MESSAGE_TYPES.CINEMATIC_TRIGGER then
            HandleCinematicTrigger(sender, parts)

        elseif msgType == messaging.MESSAGE_TYPES.SCRIPT_RESULT then
            -- Format: SCRIPT_RESULT^requestId^result
            local requestId = parts[2] or ""
            local result    = parts[3] or ""
            Log("SCRIPT_RESULT from " .. tostring(sender) .. " reqId=" .. tostring(requestId))
            EreaRpMasterScriptLibrary:HandleScriptResult(requestId, result, sender)

        elseif msgType == messaging.MESSAGE_TYPES.STATUS_LITE then
            -- Format: STATUS_LITE^zone^coordX^coordY^checksum
            local zone = parts[2] or ""
            local coordX = tonumber(parts[3]) or 0
            local coordY = tonumber(parts[4]) or 0
            local checksum = parts[5] or ""
            if not EreaRpMaster_PlayerStates[sender] then
                EreaRpMaster_PlayerStates[sender] = { hasAddon = true }
            end
            local ps = EreaRpMaster_PlayerStates[sender]
            ps.zone = zone
            ps.coordX = coordX
            ps.coordY = coordY
            ps.hasAddon = true
            if checksum ~= "" then
                ps.syncChecksum = checksum
            end
            -- Refresh player row if monitor is visible
            if EreaRpMasterPlayerMonitorFrame:IsShown() then
                EreaRpMasterPlayerMonitorFrame:RefreshPlayerRow(sender)
            end
        end
    end)

    Log("EreaRpMasterEventHandler initialized - listening for addon messages")
end

-- ============================================================================
-- OUTBOUND API
-- ============================================================================

-- GiveItem - Send a GIVE message to a target player
-- @param targetName: Player name to receive item
-- @param itemGuid: Item GUID from committed database
-- @param customMessage: Optional popup message
-- @param customText: Optional instance-specific text
-- @param customNumber: Optional instance-specific number
-- @param additionalText: Optional second instance-specific text slot
function EreaRpMasterEventHandler:GiveItem(targetName, itemGuid, customMessage, customText, customNumber, additionalText)
    Log("GiveItem - target=" .. tostring(targetName) .. " guid=" .. tostring(itemGuid))

    local success = messaging.SendGiveMessage(targetName, itemGuid, customMessage, customText, customNumber, additionalText)
    if success then
        Log("GiveItem: sent item to " .. targetName)
    else
        Log("GiveItem: failed to send item to " .. tostring(targetName))
    end

    return success
end
