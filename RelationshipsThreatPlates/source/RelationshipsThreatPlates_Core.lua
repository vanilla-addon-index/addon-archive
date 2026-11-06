----------------------------------------------------------------------
-- RelationshipsThreatPlates_Core.lua
-- Core addon initialization, saved variables, slash commands
-- Compatible with WoW 1.12 (Vanilla / Turtle WoW / Octo WoW)
----------------------------------------------------------------------

-- Create the global addon object
RelationshipsThreatPlates = CreateFrame("Frame")

local addon = RelationshipsThreatPlates
addon.MAJOR = 1
addon.MINOR = 1

-- Version string
TP_VERSION = "2.6.1"
TP_ADDON_NAME = "RelationshipsThreatPlates"

-- ==================================================================
-- Default configuration
-- ==================================================================
local DEFAULT_CONFIG = {
    enabled         = true,
    showText        = true,
    tankMode        = false,
    targetSnap100   = true,
    barHeight       = 6,
    barAlpha        = 0.5,
    barOffsetY      = 24,
    barOffsetX      = -17.8,
    barWidthScale   = 0.8,
    fontSize        = 9,
    fontOutline     = true,
    smoothColors    = true,
    showOnFriendly  = false,
    showOnNeutral   = true,
    showOnHostile   = true,
    showSpark       = false,
    showFillBG      = true,
    fillAlpha       = 0.1,
    glowEnabled     = false,
    glowSize        = 3,
    glowAsShadow    = true,

    -- New in 2.6
    combatOnly       = false,
    hideBelowPct     = 0,
    warningSound     = false,
    warningSoundName = "RaidWarning",
    warningThreshold = 80,
    flashOnAggro     = false,
    flashSpeed       = 4,
    textFormat       = "percent",   -- percent | tank | status | combo
    colorPreset      = "kui",       -- kui | cool | mono | warband
    lockGUI          = false,

    guiPos = {
        point    = "CENTER",
        relPoint = "CENTER",
        x        = 0,
        y        = 0,
    },
}

-- ==================================================================
-- Safe UnitGUID wrapper - UnitGUID does not exist in Vanilla 1.12
-- Returns nil on vanilla clients, falls back to unit name
-- ==================================================================
function addon:SafeGUID(unit)
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, unit)
        if ok and guid then return guid end
    end
    return nil
end

-- ==================================================================
-- Get a unique identifier for a unit (GUID or name)
-- In vanilla 1.12, UnitGUID does not exist, so we use unit name
-- ==================================================================
function addon:GetUnitID(unit)
    if not unit then return nil end
    local guid = addon:SafeGUID(unit)
    if guid then return guid end
    local ok, name = pcall(UnitName, unit)
    if ok and name then return name end
    return nil
end

-- ==================================================================
-- Print helper
-- ==================================================================
function addon:ui_print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffbb99ffRelationshipsThreatPlates|r " .. tostring(msg))
    end
end

-- ==================================================================
-- Deep copy utility
-- ==================================================================
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = DeepCopy(v)
        else
            dst[k] = v
        end
    end
    return dst
end

-- ==================================================================
-- Ensure SavedVariable table exists and has all default keys.
-- Safe to call multiple times.
-- ==================================================================
local function EnsureDB()
    if not RelationshipsThreatPlatesDB then
        RelationshipsThreatPlatesDB = DeepCopy(DEFAULT_CONFIG)
    else
        for k, v in pairs(DEFAULT_CONFIG) do
            if RelationshipsThreatPlatesDB[k] == nil then
                RelationshipsThreatPlatesDB[k] = DeepCopy(v)
            end
        end
    end
end
addon.EnsureDB = EnsureDB

-- In WoW 1.12, SavedVariables are loaded BEFORE the addon's Lua files
-- execute, so it is safe to initialize the DB at file load. Doing this
-- here (in addition to ADDON_LOADED) protects against cases where the
-- installed folder name doesn't match TP_ADDON_NAME exactly
-- (e.g. "RelationshipsThreatPlates-main" from a GitHub zip), which
-- would otherwise cause the ADDON_LOADED arg1 check to fail and leave
-- RelationshipsThreatPlatesDB nil - the root cause of
-- "attempt to index global 'RelationshipsThreatPlatesDB' a nil value"
-- reported at RelationshipsThreatPlates_GUI.lua:320.
EnsureDB()

-- ==================================================================
-- Event handling
-- ==================================================================
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")

local modulesInitialized = false
local function InitializeModules()
    if modulesInitialized then return end
    modulesInitialized = true

    EnsureDB()

    -- Ensure media textures
    addon.Media.EnsureTextures()

    -- Initialize modules
    addon.ThreatEngine:Initialize()
    addon.Threat:Initialize()
    addon.Nameplates:Initialize()
    addon.GUI:Initialize()

    addon:ui_print("v" .. TP_VERSION .. " loaded! Type /tp for options.")
end

addon:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        -- Accept any ADDON_LOADED: this script only runs when our addon
        -- is loaded, so the first ADDON_LOADED we see is safe to act on.
        -- This avoids folder-rename issues where arg1 ~= TP_ADDON_NAME.
        InitializeModules()

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Safety net: if ADDON_LOADED was somehow missed, initialize now.
        InitializeModules()
        if RelationshipsThreatPlatesDB and RelationshipsThreatPlatesDB.enabled then
            addon.Nameplates:UpdateAll()
        end
    end
end)


-- ==================================================================
-- Slash commands
-- ==================================================================
SLASH_THREATPLATES1 = "/threatplates"
SLASH_THREATPLATES2 = "/tp"

SlashCmdList["THREATPLATES"] = function(msg)
    -- Trim whitespace and lowercase (vanilla-safe)
    msg = msg or ""
    msg = string.lower(msg)
    -- Trim leading/trailing spaces
    msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")

    if msg == "reset" then
        RelationshipsThreatPlatesDB = DeepCopy(DEFAULT_CONFIG)
        addon:ui_print("Settings reset to defaults.")
        addon.GUI:Refresh()
    elseif msg == "toggle" then
        RelationshipsThreatPlatesDB.enabled = not RelationshipsThreatPlatesDB.enabled
        local state = RelationshipsThreatPlatesDB.enabled and "|cff33ff99ON|r" or "|cffff3333OFF|r"
        addon:ui_print("Threat bars " .. state)
        addon.Nameplates:UpdateAll()
    elseif msg == "threat" then
        addon.ThreatEngine:DumpThreat()
    elseif msg == "help" then
        addon:ui_print("Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffbb99ff/tp|r - Open GUI")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffbb99ff/tp toggle|r - Toggle threat bars on/off")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffbb99ff/tp reset|r - Reset to defaults")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffbb99ff/tp threat|r - Dump threat table (debug)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffbb99ff/tp help|r - Show this help")
    else
        addon.GUI:Toggle()
    end
end

-- ==================================================================
-- Expose DeepCopy on addon for other modules
-- ==================================================================
addon.DeepCopy = DeepCopy
