-- TurtlesEpoch: Init.lua
-- Global table, constants, debug utilities

TurtlesEpoch = TurtlesEpoch or {}

-- Addon metadata
TurtlesEpoch.VERSION = "1.0.0"
TurtlesEpoch.ADDON_NAME = "TurtlesEpoch"
TurtlesEpoch.ADDON_PATH = "Interface\\AddOns\\TurtlesEpoch\\"

-- Debug flag (off by default; toggle with /te debug)
TurtlesEpoch.DEBUG = false

-- Color prefix for chat messages
local CHAT_PREFIX = "|cff66bbff[Turtle's Epoch]|r "

---Print a message to the default chat frame.
function TurtlesEpoch:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. tostring(msg))
end

---Print a debug message (only when DEBUG is true).
function TurtlesEpoch:Debug(msg)
    if self.DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. "|cff888888" .. tostring(msg) .. "|r")
    end
end

-- SavedVariables defaults
local DEFAULTS = {
    enabled = true,
    volume = 1.0,
    textSpeed = 2,
    raceToggles = {},
    basicRaceToggles = {},
    creatureToggles = {},
    customNPCToggles = {},
    windowPos = nil,         -- saved by drag: {point, relPoint, x, y}
    minimapAngle = 225,      -- saved by minimap button drag
    muteNPCGreetings = true, -- briefly mute SFX channel on voice start to cut NPC greeting voicelines
}

-- All races that can be toggled (Tier 1 base races + Tier 2 creature types + Narrator)
local TOGGLEABLE_RACES = {
    -- Tier 1: Base races
    "Human", "Dwarf", "Night Elf", "Gnome", "High Elf",
    "Orc", "Troll", "Undead", "Tauren", "Goblin",
    -- Tier 2: Creature types
    "Furbolg", "Centaur", "Ogre", "Dragon", "Dryad",
    "Dragonspawn", "Dreadlord", "Imp", "Succubus", "Elemental",
    "Murloc", "Satyr", "Ghoul", "Harpy", "Keeper of the Grove",
    "Treant", "Banshee", "Quilboar", "Naga", "Draenei",
    "Gnoll", "Tuskarr", "Ghost", "Pandaren", "Kobold", "Wisp",
    -- Tier 4: Narrator
    "Narrator",
}

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

local CUSTOM_NPC_ALIASES = {
    ["Lord Tirion Fordring"] = "Tirion Fordring",
}

---Initialize SavedVariables with defaults for any missing keys.
function TurtlesEpoch:InitDB()
    if not TurtlesEpochDB then
        TurtlesEpochDB = {}
    end

    for k, v in pairs(DEFAULTS) do
        if TurtlesEpochDB[k] == nil then
            TurtlesEpochDB[k] = v
        end
    end

    -- Ensure all races have a toggle entry (default: enabled)
    if not TurtlesEpochDB.raceToggles then
        TurtlesEpochDB.raceToggles = {}
    end
    for _, race in ipairs(TOGGLEABLE_RACES) do
        if TurtlesEpochDB.raceToggles[race] == nil then
            TurtlesEpochDB.raceToggles[race] = true
        end
    end

    if not TurtlesEpochDB.basicRaceToggles then
        TurtlesEpochDB.basicRaceToggles = {}
    end
    for _, race in ipairs(BASIC_RACES) do
        if TurtlesEpochDB.basicRaceToggles[race] == nil then
            TurtlesEpochDB.basicRaceToggles[race] = true
        end
    end

    if not TurtlesEpochDB.creatureToggles then
        TurtlesEpochDB.creatureToggles = {}
    end
    for _, race in ipairs(CREATURE_TYPES) do
        if TurtlesEpochDB.creatureToggles[race] == nil then
            TurtlesEpochDB.creatureToggles[race] = true
        end
    end

    if not TurtlesEpochDB.customNPCToggles then
        TurtlesEpochDB.customNPCToggles = {}
    end
    for _, name in ipairs(CUSTOM_NPCS) do
        if TurtlesEpochDB.customNPCToggles[name] == nil then
            TurtlesEpochDB.customNPCToggles[name] = true
        end
    end
end

---Check if voice playback is enabled for a given race.
function TurtlesEpoch:IsRaceEnabled(race)
    if not TurtlesEpochDB or not TurtlesEpochDB.enabled then
        return false
    end
    if not race or not TurtlesEpochDB.raceToggles then
        return false
    end
    -- Unknown races default to enabled
    if TurtlesEpochDB.raceToggles[race] == nil then
        return true
    end
    return TurtlesEpochDB.raceToggles[race]
end

local function IsInList(value, list)
    local i
    for i = 1, table.getn(list) do
        if list[i] == value then
            return true
        end
    end
    return false
end

function TurtlesEpoch:IsVoiceEnabledFor(race, npcName)
    if not TurtlesEpochDB or not TurtlesEpochDB.enabled then
        return false
    end

    local canonicalName = npcName
    if canonicalName and CUSTOM_NPC_ALIASES[canonicalName] then
        canonicalName = CUSTOM_NPC_ALIASES[canonicalName]
    end

    -- Tier 3 named NPCs override race category
    if canonicalName and TurtlesEpochDB.customNPCToggles and TurtlesEpochDB.customNPCToggles[canonicalName] ~= nil then
        return TurtlesEpochDB.customNPCToggles[canonicalName]
    end

    if IsInList(race, BASIC_RACES) then
        if TurtlesEpochDB.basicRaceToggles and TurtlesEpochDB.basicRaceToggles[race] ~= nil then
            return TurtlesEpochDB.basicRaceToggles[race]
        end
        return true
    end

    if IsInList(race, CREATURE_TYPES) then
        if TurtlesEpochDB.creatureToggles and TurtlesEpochDB.creatureToggles[race] ~= nil then
            return TurtlesEpochDB.creatureToggles[race]
        end
        return true
    end

    -- Fallback to legacy race toggles for unknowns
    return self:IsRaceEnabled(race)
end

---Compute first 8 hex chars of a simple hash for a string key.
-- Uses a DJB2-style hash since 1.12 Lua has no native MD5.
function TurtlesEpoch:HashKey(key)
    if not key or key == "" then return "00000000" end
    local hash = 5381
    for i = 1, string.len(key) do
        hash = math.mod(hash * 33 + string.byte(key, i), 4294967296)
    end
    return string.format("%08x", hash)
end

---Normalize an NPC name for use in file paths.
-- Lowercase, spaces to underscores, strip special characters.
function TurtlesEpoch:NormalizeName(name)
    if not name then return "unknown" end
    name = string.lower(name)
    name = string.gsub(name, "%s+", "_")
    name = string.gsub(name, "[^%w_]", "")
    if name == "" then return "unknown" end
    return name
end

---Build the predicted sound file path for a dialog.
-- @param race     Normalized race string (e.g. "Orc", "Narrator")
-- @param npcName  Raw NPC name (will be normalized)
-- @param dialogType  e.g. "quest_detail", "book_p1", "gossip"
-- @param keyStr   The string to hash (quest title, title+pageN, etc.)
-- @return Full path suitable for PlaySoundFile()
function TurtlesEpoch:BuildSoundPath(race, npcName, dialogType, keyStr)
    -- NormalizeName on race converts e.g. "Night Elf" -> "night_elf" to match
    -- the folder structure generated by generate_voice.py.
    local raceNorm = self:NormalizeName(race or "narrator")
    local nameNorm = self:NormalizeName(npcName)
    local hash = self:HashKey(keyStr)
    return self.ADDON_PATH .. "sounds\\" .. raceNorm .. "\\" .. nameNorm .. "\\" .. dialogType .. "_" .. hash .. ".ogg"
end

-- Minimap button
function TurtlesEpoch:CreateMinimapButton()
    if self.MinimapButton then return end

    local btn = CreateFrame("Button", "TurtlesEpochMinimapButton", Minimap)
    btn:SetWidth(32)
    btn:SetHeight(32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)

    -- Icon (slightly nudged to center inside the circular border)
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\AddOns\\TurtlesEpoch\\textures\\tticon")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", btn, "CENTER", 1, 1)

    -- Circular border overlay — anchored TOPLEFT (ring is offset in the texture)
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(53)
    border:SetHeight(53)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

    -- Subtle glow on hover (no dark background)
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetWidth(32)
    highlight:SetHeight(32)
    highlight:SetPoint("CENTER", btn, "CENTER", 0, 0)
    highlight:SetBlendMode("ADD")

    -- Position on minimap edge (angle in degrees, 0 = right, counter-clockwise).
    -- Restored from SavedVariables so it survives reloads.
    local angle = (TurtlesEpochDB and TurtlesEpochDB.minimapAngle) or 225
    local function UpdatePosition()
        local rad = math.rad(angle)
        local x = math.cos(rad) * 80
        local y = math.sin(rad) * 80
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    UpdatePosition()

    -- Drag to reposition around minimap edge
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function()
        this:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            angle = math.deg(math.atan2(cy - my, cx - mx))
            UpdatePosition()
        end)
    end)
    btn:SetScript("OnDragStop", function()
        this:SetScript("OnUpdate", nil)
        if TurtlesEpochDB then
            TurtlesEpochDB.minimapAngle = angle
        end
    end)

    btn:SetScript("OnClick", function()
        TurtlesEpoch:ToggleSettingsFrame()
    end)

    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("Turtle's Epoch")
        GameTooltip:AddLine("Click to open settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.MinimapButton = btn
end

-- Slash commands
SLASH_TURTLESEPOCH1 = "/te"

SlashCmdList["TURTLESEPOCH"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "debug" then
        TurtlesEpoch.DEBUG = not TurtlesEpoch.DEBUG
        TurtlesEpoch:Print("Debug mode: " .. (TurtlesEpoch.DEBUG and "ON" or "OFF"))
    elseif msg == "status" then
        local npcCount = 0
        if TT_NPC_DATA then
            for _ in pairs(TT_NPC_DATA) do npcCount = npcCount + 1 end
        end
        TurtlesEpoch:Print("Version " .. TurtlesEpoch.VERSION)
        TurtlesEpoch:Print("NPC database: " .. npcCount .. " entries")
        TurtlesEpoch:Print("Enabled: " .. (TurtlesEpochDB and TurtlesEpochDB.enabled and "yes" or "no"))
        local qCount = table.getn(TurtlesEpoch.SoundQueue or {})
        TurtlesEpoch:Print("Queue: " .. qCount .. " waiting" .. (TurtlesEpoch.CurrentSound and ", 1 playing" or ""))
    elseif msg == "toggle" then
        if TurtlesEpochDB then
            TurtlesEpochDB.enabled = not TurtlesEpochDB.enabled
            TurtlesEpoch:Print("Voice playback: " .. (TurtlesEpochDB.enabled and "ON" or "OFF"))
        end
    elseif msg == "skip" then
        TurtlesEpoch:SkipCurrentSound()
    elseif msg == "clear" then
        TurtlesEpoch:ClearSoundQueue()
    elseif msg == "show" then
        if TurtlesEpoch.QueueFrame then
            TurtlesEpoch.QueueFrame:Show()
        else
            TurtlesEpoch:Print("Nothing is playing.")
        end
    elseif msg == "config" then
        TurtlesEpoch:ToggleSettingsFrame()
    else
        TurtlesEpoch:Print("Commands: /te debug | /te status | /te toggle | /te skip | /te clear | /te show | /te config")
    end
end
