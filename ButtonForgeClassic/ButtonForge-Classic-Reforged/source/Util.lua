-- ButtonForge Classic - utility helpers
local BF = BFClassic

function BF:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ButtonForge Classic|r " .. tostring(msg))
    end
end

function BF:Round(num)
    if not num then return 0 end
    if num >= 0 then
        return math.floor(num + 0.5)
    else
        return math.ceil(num - 0.5)
    end
end

function BF:GetProfileKey()
    local name = "Unknown"
    local realm = "UnknownRealm"

    if UnitName then
        name = UnitName("player") or name
    end
    if GetRealmName then
        realm = GetRealmName() or realm
    end

    return name .. " - " .. realm
end

function BF:EnsureDB()
    -- Account DB is kept only for one-time migration/metadata now.
    if not ButtonForgeClassicDB then
        ButtonForgeClassicDB = {}
    end

    local profileKey = self:GetProfileKey()

    -- v0.4.19+: real per-character SavedVariables.
    -- This prevents bars/settings/keybinds from being shared between chars.
    if not ButtonForgeClassicCharDB then
        local migrated = false

        -- One-time migration: the first character that loads this version gets
        -- the old account-wide data. Other characters start clean afterwards.
        if not ButtonForgeClassicDB.perCharacterMigrationDone then
            local oldBars = ButtonForgeClassicDB.bars
            local oldSettings = ButtonForgeClassicDB.settings
            local oldKeybinds = ButtonForgeClassicDB.keybinds
            local oldNextBarId = ButtonForgeClassicDB.nextBarId

            if ButtonForgeClassicDB.profiles then
                local oldProfile = ButtonForgeClassicDB.profiles[profileKey]
                if oldProfile then
                    oldBars = oldProfile.bars or oldBars
                    oldSettings = oldProfile.settings or oldSettings
                    oldKeybinds = oldProfile.keybinds or oldKeybinds
                    oldNextBarId = oldProfile.nextBarId or oldNextBarId
                end
            end

            ButtonForgeClassicCharDB = {
                bars = oldBars or {},
                settings = oldSettings or {},
                keybinds = oldKeybinds or {},
                nextBarId = oldNextBarId or 1,
            }
            ButtonForgeClassicDB.perCharacterMigrationDone = true
            migrated = true
        end

        if not migrated then
            ButtonForgeClassicCharDB = {
                bars = {},
                settings = {},
                keybinds = {},
                nextBarId = 1,
            }
        end
    end

    if not ButtonForgeClassicCharDB.bars then
        ButtonForgeClassicCharDB.bars = {}
    end
    if not ButtonForgeClassicCharDB.settings then
        ButtonForgeClassicCharDB.settings = {}
    end
    if not ButtonForgeClassicCharDB.keybinds then
        ButtonForgeClassicCharDB.keybinds = {}
    end
    if not ButtonForgeClassicCharDB.nextBarId then
        ButtonForgeClassicCharDB.nextBarId = 1
    end

    -- Compatibility aliases for the rest of the addon.
    ButtonForgeClassicDB.profileKey = profileKey
    ButtonForgeClassicDB.profile = ButtonForgeClassicCharDB
    ButtonForgeClassicDB.bars = ButtonForgeClassicCharDB.bars
    ButtonForgeClassicDB.settings = ButtonForgeClassicCharDB.settings
    ButtonForgeClassicDB.keybinds = ButtonForgeClassicCharDB.keybinds
    ButtonForgeClassicDB.nextBarId = ButtonForgeClassicCharDB.nextBarId

    if ButtonForgeClassicDB.settings.configMode == nil then
        ButtonForgeClassicDB.settings.configMode = true
    end
    if ButtonForgeClassicDB.settings.hideBarBackground == nil then
        ButtonForgeClassicDB.settings.hideBarBackground = false
    end
    if ButtonForgeClassicDB.settings.showGrid == nil then
        ButtonForgeClassicDB.settings.showGrid = false
    end
    if ButtonForgeClassicDB.settings.keybindMode == nil then
        ButtonForgeClassicDB.settings.keybindMode = false
    end
    if ButtonForgeClassicDB.settings.showMacroNames == nil then
        ButtonForgeClassicDB.settings.showMacroNames = true
    end
end
function BF:IsBarIdUsed(id)
    self:EnsureDB()
    local i
    for i = 1, table.getn(ButtonForgeClassicDB.bars) do
        if ButtonForgeClassicDB.bars[i] and ButtonForgeClassicDB.bars[i].id == id then
            return true
        end
    end
    return false
end

function BF:GetNextFreeBarId()
    local maxBars = self.MaxBars or 8
    local id
    for id = 1, maxBars do
        if not self:IsBarIdUsed(id) then
            return id
        end
    end
    return nil
end

function BF:GetDefaultBarSave()
    local id = self:GetNextFreeBarId()
    if not id then
        self:Print("Maximum " .. tostring(self.MaxBars or 8) .. " bars in this alpha. Note: 48 Vanilla ActionSlots are currently available in total.")
        return nil
    end

    return {
        id = id,
        name = "Bar " .. id,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        cols = BF.DefaultCols,
        rows = BF.DefaultRows,
        scale = 1,
        buttons = {},
        locked = false,
        actionsLocked = false,
        hideBackground = false,
        showGrid = false,
        mouseover = false,
        mouseoverDelay = 1,
    }
end

function BF:RemoveBarSaveById(id)
    self:EnsureDB()
    local i
    for i = table.getn(ButtonForgeClassicDB.bars), 1, -1 do
        if ButtonForgeClassicDB.bars[i] and ButtonForgeClassicDB.bars[i].id == id then
            table.remove(ButtonForgeClassicDB.bars, i)
            return true
        end
    end
    return false
end
