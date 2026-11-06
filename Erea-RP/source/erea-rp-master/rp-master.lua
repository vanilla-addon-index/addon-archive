-- ============================================================================
-- rp-master.lua - Main Entry Point for RPMaster Addon
-- ============================================================================
-- PURPOSE: Initialize addon, set up SavedVariables, register commands
--
-- LOAD ORDER: Loaded after views and presenters, before event-handler
-- ============================================================================

-- ============================================================================
-- IMPORTS
-- ============================================================================
local Log = EreaRpLibraries:Logging("EreaRpMaster")
local rpActions = EreaRpLibraries:RPActions()

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local ADDON_NAME = "RPMaster"
local ADDON_VERSION = (RP_VERSION_TAG and RP_VERSION_TAG ~= "0.0.0") and RP_VERSION_TAG or (RP_BUILD_TIME or "unknown")

-- ============================================================================
-- INITIALIZE SAVEDVARIABLES
-- ============================================================================
EreaRpMasterDebugLog = EreaRpMasterDebugLog or {}
Log("rp-master.lua loading...")

-- ============================================================================
-- DEFAULT DATABASE STRUCTURE
-- ============================================================================
local function InitializeDB()
    -- Migrate from old SavedVariable names (V1 used RPMasterDB / RPMasterDebugLog)
    if RPMasterDB and not EreaRpMasterDB then
        EreaRpMasterDB = RPMasterDB
        RPMasterDB = nil
        Log("Migrated RPMasterDB -> EreaRpMasterDB")
    end
    if RPMasterDebugLog and not EreaRpMasterDebugLog then
        EreaRpMasterDebugLog = RPMasterDebugLog
        RPMasterDebugLog = nil
        Log("Migrated RPMasterDebugLog -> EreaRpMasterDebugLog")
    end

    EreaRpMasterDB = EreaRpMasterDB or {
        itemLibrary = {},
        committedDatabase = nil,
        nextItemID = 1,
        databaseName = "",
        databaseId = "",
        preferences = {
            windowPositions = { main = nil },
            windowSize = nil,
            activeTab = "items",
            minimapButton = { angle = math.rad(225) }
        }
    }

    -- Ensure merge library exists (backward compatibility)
    if not EreaRpMasterDB.mergeLibrary then
        EreaRpMasterDB.mergeLibrary = {}
    end

    -- Ensure cinematic library exists (backward compatibility)
    if not EreaRpMasterDB.cinematicLibrary then
        EreaRpMasterDB.cinematicLibrary = {}
    end

    -- Ensure script library exists (backward compatibility)
    if not EreaRpMasterDB.scriptLibrary then
        EreaRpMasterDB.scriptLibrary = {}
    end

    -- Ensure preferences structure exists (backward compatibility)
    if not EreaRpMasterDB.preferences then
        EreaRpMasterDB.preferences = {
            windowPositions = { main = nil },
            windowSize = nil,
            activeTab = "items",
            minimapButton = { angle = math.rad(225) }
        }
    end
    if not EreaRpMasterDB.preferences.windowPositions then
        EreaRpMasterDB.preferences.windowPositions = { main = nil }
    end
    if not EreaRpMasterDB.preferences.minimapButton then
        EreaRpMasterDB.preferences.minimapButton = { angle = math.rad(225) }
    end
    -- Clean up removed V1 fields
    EreaRpMasterDB.preferences.detachedTabs = nil
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================
function EreaRpMaster_ToggleMainFrame()
    if EreaRpMasterMainWindow:IsShown() then
        EreaRpMasterMainWindow:Hide()
    else
        EreaRpMasterMainWindow:Show()
    end
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================
SLASH_RPMASTER1 = "/rpmaster"
SLASH_RPMASTER2 = "/rpm"
SlashCmdList["RPMASTER"] = function(msg)
    if msg == "log" then
        EreaRpLogViewerFrame:ShowLog("EreaRpMaster")
        return
    end

    if msg == "clearlog" then
        EreaRpLogViewerFrame:ClearLog("EreaRpMaster")
        return
    end

    if msg == "reset" then
        -- Reset all RP Master frames
        if EreaRpMasterMainWindow and EreaRpMasterMainWindow.ResetPositions then
            EreaRpMasterMainWindow:ResetPositions()
        end
        if EreaRpMasterIconPickerFrame and EreaRpMasterIconPickerFrame.ResetPositions then
            EreaRpMasterIconPickerFrame:ResetPositions()
        end
        if EreaRpMasterItemEditorFrame and EreaRpMasterItemEditorFrame.ResetPositions then
            EreaRpMasterItemEditorFrame:ResetPositions()
        end
        return
    end

    EreaRpMaster_ToggleMainFrame()
end

-- ============================================================================
-- INITIALIZE FRAMES
-- ============================================================================
-- Initialize main window presenter (adds behavior to XML frame)
EreaRpMasterMainWindow:Initialize()

-- Initialize item list presenter
EreaRpMasterItemListFrame:Initialize()

-- Initialize item editor, action editor, and icon picker presenters
EreaRpMasterItemEditorFrame:Initialize()
EreaRpMasterActionEditorFrame:Initialize()
EreaRpMasterIconPickerFrame:Initialize()

-- Initialize player monitor presenter
EreaRpMasterPlayerMonitorFrame:Initialize()

-- Initialize give item dialog presenter
EreaRpMasterGiveItemFrame:Initialize()

-- Initialize script list presenter
EreaRpMasterScriptListFrame:Initialize()

-- Initialize centralized event handler (addon message routing)
EreaRpMasterEventHandler:Initialize()

-- ============================================================================
-- EVENT HANDLER: VARIABLES_LOADED & PLAYER_ENTERING_WORLD
-- ============================================================================
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("VARIABLES_LOADED")
loadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local variablesLoaded = false

loadFrame:SetScript("OnEvent", function()
    -- Lua 5.0: event is a global variable
    if event == "VARIABLES_LOADED" then
        -- Clear log at session start in production builds (RP_PRODUCTION_BUILD set by build.ps1)
        if RP_PRODUCTION_BUILD then
            _G["EreaRpMasterDebugLog"] = {}
        end
        Log("VARIABLES_LOADED event fired")
        InitializeDB()
        Log("EreaRpMasterDB initialized")

        -- Remove method types that no longer exist in METHOD_REGISTRY
        local sanitizeResult = rpActions.SanitizeItemLibrary(EreaRpMasterDB.itemLibrary)
        if sanitizeResult.methodsRemoved > 0 or sanitizeResult.actionsRemoved > 0 then
            Log("SanitizeItemLibrary: " .. sanitizeResult.methodsRemoved .. " methods, " .. sanitizeResult.actionsRemoved .. " actions removed")
        end

        -- Reload position/size now that SavedVariables are available
        EreaRpMasterMainWindow:LoadPosition()
        EreaRpMasterMainWindow:LoadSize()

        variablesLoaded = true
        loadFrame:UnregisterEvent("VARIABLES_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not variablesLoaded then return end

        Log("PLAYER_ENTERING_WORLD event fired")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[RP Master]|r Version: " .. ADDON_VERSION)
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[RP Master]|r Commands: /rpm, /rpm log")

        -- Restore last active tab
        local startTab = EreaRpMasterDB.preferences.activeTab or "items"
        EreaRpMaster_SwitchTab(startTab)

        loadFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

Log("rp-master.lua loaded")
