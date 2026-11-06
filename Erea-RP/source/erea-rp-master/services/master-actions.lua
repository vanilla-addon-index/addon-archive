-- ============================================================================
-- master-actions.lua - GM-side Action Execution Service
-- ============================================================================
-- PURPOSE: Handle GM-side GUI aspects of action execution
--
-- RESPONSIBILITIES:
--   - Handle GM-side notifications and result dispatching
--
-- ARCHITECTURE:
--   - rp-common/rp-actions.lua: Pure business logic (ExecuteAction)
--   - master-actions.lua: GM-side GUI (THIS FILE)
--
-- DEPENDENCIES:
--   - EreaRpLibraries:RPActions()
--   - EreaRpLibraries:Logging()
-- ============================================================================

-- ============================================================================
-- IMPORTS
-- ============================================================================
local Log = EreaRpLibraries:Logging("EreaRpMaster")

-- Lazy-load rpActions to avoid initialization order issues
local rpActions = nil
local function GetRPActions()
    if not rpActions then
        rpActions = EreaRpLibraries:RPActions()
    end
    return rpActions
end

-- ============================================================================
-- SERVICE TABLE
-- ============================================================================
EreaRpMasterActions = {}

-- ============================================================================
-- RESULT HANDLERS (local)
-- ============================================================================

local function HandleSuccess(item, action, result)
end

local function HandleFail(item, action, result)
end

local function HandleError(item, action, result)
end

-- ============================================================================
-- ExecuteAction - Execute action and dispatch result (GM side)
-- ============================================================================
-- @param item: Table - Item object with actions
-- @param action: Table - Action object to execute
-- ============================================================================
function EreaRpMasterActions:ExecuteAction(item, action)
    Log("ExecuteAction - Item: " .. tostring(item.name) .. ", Action: " .. tostring(action.id))

    local playerName = UnitName("player")
    local actions = GetRPActions()
    local result = actions.ExecuteAction(playerName, item, action.id)

    if not result then
        return
    end

    local RESULT_TYPES = actions.RESULT_TYPES

    if result.result == RESULT_TYPES.SUCCESS then
        HandleSuccess(item, action, result)
    elseif result.result == RESULT_TYPES.FAIL then
        HandleFail(item, action, result)
    elseif result.result == RESULT_TYPES.ERROR then
        HandleError(item, action, result)
    else
        Log("Unhandled result type: " .. tostring(result.result))
    end
end
