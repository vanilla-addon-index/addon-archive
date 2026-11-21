---
--- Persistence.lua - [Atlas-CFM split] always-loaded settings guard.
---
--- Moved verbatim from CFMAtlas\AtlasOptions.lua so that the account-wide
--- AtlasCFMOptions table and its per-character backup mirror keep working on
--- sessions where the LoadOnDemand part (Atlas-CFM_Core) is never loaded.
--- AtlasOptions.lua (in Atlas-CFM_Core) reads the helpers back from
--- AtlasCFM._Persist. SavedVariables names and table layout are unchanged.
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()
local AtlasCFM = _G.AtlasCFM

-- Atlas.lua sets this too (same value); DEFAULT_OPTIONS below needs it now.
AtlasCFM.Version = AtlasCFM.Version or GetAddOnMetadata(AtlasCFM.Name, "Version")

-- Canonical defaults used both for first-time initialization and migrations.
-- Existing saved values are never overwritten automatically; only missing keys
-- are filled. This prevents a new character's FirstTime flag from resetting
-- the account-wide AtlasCFMOptions table.
local DEFAULT_OPTIONS = {
    AtlasButtonPosition = 305,
    AtlasButtonRadius = 76,
    AtlasButtonShown = true,
    AtlasRightClick = false,
    AtlasType = 1,
    AtlasScale = 1,
    AtlasVersion = AtlasCFM.Version,
    AtlasZone = 1,
    AtlasSortBy = 1,
    AtlasServer = "Auto",
    AtlasAutoSelect = false,
    AtlasLocked = false,
    AtlasAlpha = 1.0,
    AtlasAcronyms = true,
    AtlasClamped = true,
    AtlasCursorCoords = true,
    ShowMapMarkers = true,
    QuestCurrentSide = "Left",
    QuestWithAtlas = true,
    QuestColourCheck = true,
    QuestCheckQuestlog = true,
    QuestAutoQuery = true,
    LootShowSource = true,
    LootEquipCompare = false,
    LootOpaque = true,
    LootShowPanel = true,
    LootFilterMode = 0,
    ReagentRows = 20,
    ReagentProfessions = {
        ["Alchemy"] = true,
        ["Blacksmithing"] = true,
        ["Enchanting"] = true,
        ["Engineering"] = true,
        ["Leatherworking"] = true,
        ["Tailoring"] = true,
        ["Cooking"] = true,
        ["First Aid"] = true,
        ["Jewelcrafting"] = true,
        ["Poisons"] = true,
        ["Mining"] = true,
        ["Survival"] = true,
    },
    TooltipShowID = true,
    TooltipShowIcon = true,
    TooltipShowDropRate = true,
    ProfessionInfo = false,
    TradeSkillShowLevels = true,
    CraftSkillShowLevels = true,
    pfUIEnabled = true,
}

local function CopyOptionValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = CopyOptionValue(child)
    end
    return copy
end

local function FillMissingOptions(target, defaults)
    for key, defaultValue in pairs(defaults) do
        if target[key] == nil then
            target[key] = CopyOptionValue(defaultValue)
        elseif type(defaultValue) == "table" and type(target[key]) == "table" then
            FillMissingOptions(target[key], defaultValue)
        end
    end
end

-- Persistence guard. AtlasCFMOptions is account-wide, while AtlasCFMCharDB is
-- stored in a separate per-character SavedVariables file. Keeping a mirror in
-- the character DB gives us an independent recovery copy if the account-wide
-- table is ever unexpectedly lost or replaced.
local SETTINGS_GUARD_VERSION = 1

local function OptionsDeepEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end

    for key, value in pairs(a) do
        if not OptionsDeepEqual(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

local function BackupIsValid()
    return type(AtlasCFMCharDB) == "table"
        and AtlasCFMCharDB.OptionsBackupGuard == SETTINGS_GUARD_VERSION
        and type(AtlasCFMCharDB.OptionsBackup) == "table"
end

local function StoreOptionsBackup(serial)
    if type(AtlasCFMCharDB) ~= "table" or type(AtlasCFMOptions) ~= "table" then return end
    AtlasCFMOptions._PersistenceGuard = SETTINGS_GUARD_VERSION
    AtlasCFMOptions._PersistenceSerial = serial or AtlasCFMOptions._PersistenceSerial or 1
    AtlasCFMCharDB.OptionsBackupGuard = SETTINGS_GUARD_VERSION
    AtlasCFMCharDB.OptionsBackupSerial = AtlasCFMOptions._PersistenceSerial
    AtlasCFMCharDB.OptionsBackup = CopyOptionValue(AtlasCFMOptions)
end

function AtlasCFM.SyncOptionsBackup()
    if not AtlasCFM._savedOptionsReady then return end
    if type(AtlasCFMCharDB) ~= "table" then return end

    -- If the whole account-wide table was replaced during the session, recover
    -- the last known-good character mirror rather than accepting fresh defaults.
    if (type(AtlasCFMOptions) ~= "table" or AtlasCFMOptions._PersistenceGuard ~= SETTINGS_GUARD_VERSION) and BackupIsValid() then
        AtlasCFMOptions = CopyOptionValue(AtlasCFMCharDB.OptionsBackup)
        AtlasCFMCharDB.SettingsGuardLastReason = "runtime account-wide options table was replaced"
        AtlasCFMCharDB.SettingsGuardRecovered = true
        return
    end
    if type(AtlasCFMOptions) ~= "table" then return end

    AtlasCFMOptions._PersistenceGuard = SETTINGS_GUARD_VERSION
    local currentSerial = tonumber(AtlasCFMOptions._PersistenceSerial) or 1

    if not BackupIsValid() or not OptionsDeepEqual(AtlasCFMOptions, AtlasCFMCharDB.OptionsBackup) then
        local backupSerial = tonumber(AtlasCFMCharDB.OptionsBackupSerial) or 0
        local newSerial = currentSerial
        if newSerial <= backupSerial then newSerial = backupSerial + 1 end
        AtlasCFMOptions._PersistenceSerial = newSerial
        StoreOptionsBackup(newSerial)
    end
end

--- Safely initializes/migrates saved variables without resetting user choices.
--- It also restores the per-character mirror if the account-wide table is
--- missing, older than the mirror, or unexpectedly differs at the same serial.
function AtlasCFM.EnsureSavedOptions()
    if type(AtlasCFMCharDB) ~= "table" then
        AtlasCFMCharDB = {}
    end

    local backupValid = BackupIsValid()
    local backupSerial = tonumber(AtlasCFMCharDB.OptionsBackupSerial) or 0
    local optionsValid = type(AtlasCFMOptions) == "table"
        and AtlasCFMOptions._PersistenceGuard == SETTINGS_GUARD_VERSION
    local optionsSerial = optionsValid and (tonumber(AtlasCFMOptions._PersistenceSerial) or 0) or 0
    local recoverReason = nil

    if backupValid then
        if not optionsValid then
            recoverReason = "account-wide options were missing or replaced"
        elseif optionsSerial < backupSerial then
            recoverReason = "account-wide options were older than the character backup"
        elseif optionsSerial == backupSerial and not OptionsDeepEqual(AtlasCFMOptions, AtlasCFMCharDB.OptionsBackup) then
            recoverReason = "account-wide options did not match the last known-good backup"
        end
    end

    if recoverReason then
        AtlasCFMOptions = CopyOptionValue(AtlasCFMCharDB.OptionsBackup)
        AtlasCFMCharDB.SettingsGuardLastReason = recoverReason
        AtlasCFMCharDB.SettingsGuardRecovered = true
    elseif type(AtlasCFMOptions) ~= "table" then
        AtlasCFMOptions = {}
    end

    FillMissingOptions(AtlasCFMOptions, DEFAULT_OPTIONS)
    AtlasCFMOptions.AtlasVersion = AtlasCFM.Version
    AtlasCFMOptions._PersistenceGuard = SETTINGS_GUARD_VERSION
    if tonumber(AtlasCFMOptions._PersistenceSerial) == nil then
        AtlasCFMOptions._PersistenceSerial = backupSerial > 0 and backupSerial or 1
    end

    -- FirstTime is per-character and controls only the one-time setup prompt.
    -- It must never be used as a reason to reset account-wide settings.
    if AtlasCFMCharDB.FirstTime == nil then
        AtlasCFMCharDB.FirstTime = true
    end

    AtlasCFM._savedOptionsReady = true
    StoreOptionsBackup(AtlasCFMOptions._PersistenceSerial)
end

AtlasCFM._Persist = {
    DEFAULT_OPTIONS = DEFAULT_OPTIONS,
    CopyOptionValue = CopyOptionValue,
    SETTINGS_GUARD_VERSION = SETTINGS_GUARD_VERSION,
    StoreOptionsBackup = StoreOptionsBackup,
}

-- Keep the mirror current on a normal logout or /reload. AtlasCFMOptions and
-- AtlasCFMCharDB are persisted to separate SavedVariables files by the client.
local AtlasCFMSettingsGuardFrame = CreateFrame("Frame")
AtlasCFMSettingsGuardFrame:RegisterEvent("PLAYER_LOGOUT")
AtlasCFMSettingsGuardFrame:SetScript("OnEvent", function()
    if AtlasCFM.SyncOptionsBackup then AtlasCFM.SyncOptionsBackup() end
end)
