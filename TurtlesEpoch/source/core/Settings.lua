-- TurtlesEpoch: Settings.lua
-- Simple in-game config frame with grouped toggle checkboxes.

local TT = TurtlesEpoch

local BASIC_RACES = {
    "Human", "Dwarf", "Night Elf", "Gnome", "High Elf",
    "Orc", "Troll", "Undead", "Tauren", "Goblin", "Narrator",
}

local CREATURE_TYPES = {
    "Furbolg", "Centaur", "Ogre", "Dragon", "Dryad",
    "Dragonspawn", "Dreadlord", "Imp", "Succubus", "Elemental",
    "Murloc", "Satyr", "Ghoul", "Harpy", "Keeper of the Grove",
    "Treant", "Banshee", "Quilboar", "Naga", "Draenei",
    "Gnoll", "Tuskarr", "Ghost", "Pandaren", "Kobold", "Wisp",
}

local CUSTOM_NPCS = {
    "Thrall",
    "Archmage Ansirem Runeweaver",
    "Tirion Fordring",
    "Varimathras",
    "Chromie",
    "Nathanos Blightcaller",
    "Highlord Bolvar Fordragon",
    "Cairne Bloodhoof",
    "King Magni Bronzebeard",
    "Gazlowe",
    "Vereesa Windrunner",
    "Tyrande Whisperwind",
    "Lady Sylvanas Windrunner",
    "Vol'jin",
    "Rexxar",
    "Lady Jaina Proudmoore",
}

local function EnsureSettingsTables()
    if not TurtlesEpochDB then return end

    TurtlesEpochDB.basicRaceToggles = TurtlesEpochDB.basicRaceToggles or {}
    TurtlesEpochDB.creatureToggles = TurtlesEpochDB.creatureToggles or {}
    TurtlesEpochDB.customNPCToggles = TurtlesEpochDB.customNPCToggles or {}

    local i
    for i = 1, table.getn(BASIC_RACES) do
        local k = BASIC_RACES[i]
        if TurtlesEpochDB.basicRaceToggles[k] == nil then
            TurtlesEpochDB.basicRaceToggles[k] = true
        end
    end
    for i = 1, table.getn(CREATURE_TYPES) do
        local k = CREATURE_TYPES[i]
        if TurtlesEpochDB.creatureToggles[k] == nil then
            TurtlesEpochDB.creatureToggles[k] = true
        end
    end
    for i = 1, table.getn(CUSTOM_NPCS) do
        local k = CUSTOM_NPCS[i]
        if TurtlesEpochDB.customNPCToggles[k] == nil then
            TurtlesEpochDB.customNPCToggles[k] = true
        end
    end
end

local function GetCategoryTable(category)
    if category == "basic" then
        return TurtlesEpochDB.basicRaceToggles
    elseif category == "creature" then
        return TurtlesEpochDB.creatureToggles
    end
    return TurtlesEpochDB.customNPCToggles
end

local function CreateSection(frame, title, yOffset)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, yOffset)
    label:SetText(title)
    return label
end

local function CreateToggle(frame, text, category, key, x, y)
    local safeKey = string.gsub(string.lower(key), "[^%w]", "_")
    local frameName = "TTSettingToggle_" .. category .. "_" .. safeKey
    local cb = CreateFrame("CheckButton", frameName, frame, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    getglobal(frameName .. "Text"):SetText(text)
    cb:SetChecked(GetCategoryTable(category)[key])
    cb:SetScript("OnClick", function()
        GetCategoryTable(category)[key] = this:GetChecked() and true or false
    end)
    return cb
end

function TT:CreateSettingsFrame()
    if self.SettingsFrame then return end

    EnsureSettingsTables()

    local f = CreateFrame("Frame", "TurtlesEpochSettingsFrame", UIParent)
    f:SetWidth(660)
    f:SetHeight(640)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    table.insert(UISpecialFrames, "TurtlesEpochSettingsFrame")
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("Turtle's Epoch Voice Settings")

    -- Global options row
    local muteCB = CreateFrame("CheckButton", "TTSettingToggle_global_mutenpcgreetings", f, "UICheckButtonTemplate")
    muteCB:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -36)
    getglobal("TTSettingToggle_global_mutenpcgreetingsText"):SetText("Mute NPC greeting voicelines when TurtlesEpoch voice plays")
    if TurtlesEpochDB.muteNPCGreetings == nil then
        TurtlesEpochDB.muteNPCGreetings = true
    end
    muteCB:SetChecked(TurtlesEpochDB.muteNPCGreetings)
    muteCB:SetScript("OnClick", function()
        TurtlesEpochDB.muteNPCGreetings = this:GetChecked() and true or false
    end)

    local basicLabel = CreateSection(f, "Base Races + Narrator", -70)
    local creatureLabel = CreateSection(f, "Creature Types", -70)
    creatureLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 240, -70)
    local customLabel = CreateSection(f, "Custom NPCs", -70)
    customLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 460, -70)

    local i
    for i = 1, table.getn(BASIC_RACES) do
        local y = -94 - ((i - 1) * 22)
        CreateToggle(f, BASIC_RACES[i], "basic", BASIC_RACES[i], 14, y)
    end

    for i = 1, table.getn(CREATURE_TYPES) do
        local y = -94 - ((i - 1) * 18)
        CreateToggle(f, CREATURE_TYPES[i], "creature", CREATURE_TYPES[i], 238, y)
    end

    for i = 1, table.getn(CUSTOM_NPCS) do
        local y = -94 - ((i - 1) * 22)
        CreateToggle(f, CUSTOM_NPCS[i], "custom", CUSTOM_NPCS[i], 458, y)
    end

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetWidth(84)
    closeBtn:SetHeight(22)
    closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    self.SettingsFrame = f
end

function TT:ToggleSettingsFrame()
    self:CreateSettingsFrame()
    if not self.SettingsFrame then return end
    if self.SettingsFrame:IsShown() then
        self.SettingsFrame:Hide()
    else
        self.SettingsFrame:Show()
    end
end
