-- 41sCombatAlert
-- World of Warcraft 1.12.1 / Lua 5.0
-- No SuperWoW required.
--
-- Pattern:
--   * = any number of characters
-- Matching is case-insensitive.
-- Special token:
--   currentpet = current pet name
--
-- Example:
--   currentpet * torment * resisted *

FortyOneSCombatAlertDB = FortyOneSCombatAlertDB or {}
FortyOneSCombatAlertDB.alerts = FortyOneSCombatAlertDB.alerts or {}
FortyOneSCombatAlertDB.characterAlerts =
    FortyOneSCombatAlertDB.characterAlerts or {}
local characterAlertDatabase = { alerts = {} }
local currentCharacterStorage = { alerts = {} }

local function CreateAlertId(database)
    database = database or FortyOneSCombatAlertDB
    database.nextAlertId = (database.nextAlertId or 0) + 1
    return database.nextAlertId
end

local ALERT_TIME = 3
local ADDON_SOUND_DIRECTORY = "Interface\\AddOns\\41sCombatAlert\\Sounds\\"
local SOUND_OPTIONS = {
    [1] = { name = "Sound A", path = ADDON_SOUND_DIRECTORY.."SoundA.wav" },
    [2] = { name = "Sound B", path = ADDON_SOUND_DIRECTORY.."SoundB.wav" },
    [3] = { name = "Sound C", path = ADDON_SOUND_DIRECTORY.."SoundC.wav" },
    [4] = { name = "Sound D", path = ADDON_SOUND_DIRECTORY.."SoundD.wav" },
    [5] = { name = "Sound E", path = ADDON_SOUND_DIRECTORY.."SoundE.wav" },
    [6] = { name = "Sound F", path = ADDON_SOUND_DIRECTORY.."SoundF.wav" },
    [7] = { name = "Custom File", customFile = true },
    [8] = { name = "MPQ Path", customMPQ = true }
}

-- Some 1.12-derived clients replace the SavedVariables table after addon Lua
-- has loaded.  Recreate all required account fields at PLAYER_LOGIN as well.
local function EnsureAccountDatabase()
    FortyOneSCombatAlertDB = FortyOneSCombatAlertDB or {}
    FortyOneSCombatAlertDB.alerts = FortyOneSCombatAlertDB.alerts or {}
    FortyOneSCombatAlertDB.characterAlerts =
        FortyOneSCombatAlertDB.characterAlerts or {}
    FortyOneSCombatAlertDB.uiState = FortyOneSCombatAlertDB.uiState or {}
end

local function EnsureAlertOptions(database)
    local i
    local nextAlertId = database.nextAlertId or 0
    for i = 1, table.getn(database.alerts) do
        local alert = database.alerts[i]
        if alert.id then
            if alert.id > nextAlertId then nextAlertId = alert.id end
        else
            nextAlertId = nextAlertId + 1
            alert.id = nextAlertId
        end
        if alert.displayOrder == nil then alert.displayOrder = i end
        if alert.chatParty == nil then alert.chatParty = false end
        if alert.chatRaid == nil then alert.chatRaid = false end
        if alert.chatSay == nil then alert.chatSay = false end
        if alert.chatYell == nil then alert.chatYell = false end
        if alert.chatGuild == nil then alert.chatGuild = false end
        if alert.chatCustomChannel == nil then alert.chatCustomChannel = "" end
        if alert.exceptions == nil then alert.exceptions = "" end
        if alert.soundChoice == nil then alert.soundChoice = 1 end
        if alert.customSoundPath == nil then
            alert.customSoundPath = "Sound\\Interface\\RaidWarning.wav"
        end
        if alert.customFileName == nil then alert.customFileName = "" end
        if alert.soundChoiceVersion == nil or alert.soundChoiceVersion < 2 then
            if alert.soundChoice == 3 then alert.soundChoice = 7 end
            alert.soundChoiceVersion = 2
        end
        if alert.soundChoiceVersion < 3 then
            if alert.soundChoice == 3 then
                alert.customSoundPath = "Sound\\Interface\\RaidWarning.wav"
                alert.soundChoice = 7
            elseif alert.soundChoice == 4 then
                alert.customSoundPath = "Sound\\Interface\\MapPing.wav"
                alert.soundChoice = 7
            elseif alert.soundChoice == 5 then
                alert.customSoundPath = "Sound\\Doodad\\BellTollAlliance.wav"
                alert.soundChoice = 7
            elseif alert.soundChoice == 6 then
                alert.customSoundPath = "Sound\\Doodad\\BellTollHorde.wav"
                alert.soundChoice = 7
            end
            alert.soundChoiceVersion = 3
        end
        if alert.soundChoiceVersion < 4 then
            if alert.soundChoice == 7 then alert.soundChoice = 8 end
            alert.soundChoiceVersion = 4
        end
    end
    database.nextAlertId = nextAlertId
end

local function EnsureDefaults()
    EnsureAccountDatabase()
    if table.getn(FortyOneSCombatAlertDB.alerts) == 0 then
        table.insert(FortyOneSCombatAlertDB.alerts, {
            enabled = true,
            id = CreateAlertId(),
            pattern = "currentpet*torment*resisted*",
            exceptions = "",
            textEnabled = true,
            soundEnabled = true,
            soundChoice = 1,
            soundChoiceVersion = 4,
            customFileName = "",
            customSoundPath = "Sound\\Interface\\RaidWarning.wav",
            chatParty = false,
            chatRaid = false,
            chatSay = false,
            chatYell = false,
            text = "TORMENT RESISTED!"
        })
    end

    if not FortyOneSCombatAlertDB.tauntExampleAdded then
        table.insert(FortyOneSCombatAlertDB.alerts, {
            enabled = true,
            id = CreateAlertId(),
            pattern = "your taunt was resisted*",
            exceptions = "",
            textEnabled = true,
            soundEnabled = true,
            soundChoice = 1,
            soundChoiceVersion = 4,
            customFileName = "",
            customSoundPath = "Sound\\Interface\\RaidWarning.wav",
            chatParty = true,
            chatRaid = false,
            chatSay = false,
            chatYell = false,
            text = "TAUNT RESISTED!"
        })
        FortyOneSCombatAlertDB.tauntExampleAdded = true
    end

    EnsureAlertOptions(FortyOneSCombatAlertDB)
end

local function EnsureCharacterDefaults()
    EnsureAlertOptions(characterAlertDatabase)
end

-- Keep character alerts inside the account SavedVariables file, keyed by
-- character and realm.  This avoids depending on a separate per-character
-- SavedVariables file while still keeping each character's alerts isolated.
local function GetCurrentCharacterKey()
    local characterName = UnitName("player") or "Unknown"
    local realmName = GetRealmName() or "Unknown"
    return realmName .. " - " .. characterName
end

local function BindCharacterAlertDatabase()
    EnsureAccountDatabase()
    local characterKey = GetCurrentCharacterKey()
    local savedAlerts = FortyOneSCombatAlertDB.characterAlerts[characterKey]

    if not savedAlerts then
        savedAlerts = { alerts = {} }
        FortyOneSCombatAlertDB.characterAlerts[characterKey] = savedAlerts
    end

    savedAlerts.alerts = savedAlerts.alerts or {}
    currentCharacterStorage = savedAlerts

    local parentKey = savedAlerts.shareParentKey
    local parentDatabase = parentKey and
        FortyOneSCombatAlertDB.characterAlerts[parentKey]
    if parentDatabase and parentKey ~= characterKey and
        not parentDatabase.shareParentKey then
        characterAlertDatabase = parentDatabase
    else
        savedAlerts.shareParentKey = nil
        characterAlertDatabase = savedAlerts
    end
end

local function CopyAlertEntries(sourceDatabase, destinationDatabase)
    if not sourceDatabase or not destinationDatabase then
        return 0
    end
    local sourceAlerts = sourceDatabase.alerts or {}
    local idMap = {}
    local copiedAlerts = {}
    local i

    if sourceDatabase == destinationDatabase or table.getn(sourceAlerts) == 0 then
        return 0
    end

    for i = 1, table.getn(sourceAlerts) do
        local sourceAlert = sourceAlerts[i]
        idMap[sourceAlert.id] = CreateAlertId(destinationDatabase)
    end

    for i = 1, table.getn(sourceAlerts) do
        local sourceAlert = sourceAlerts[i]
        local copiedAlert = {}
        local key, value
        for key, value in pairs(sourceAlert) do
            copiedAlert[key] = value
        end
        copiedAlert.id = idMap[sourceAlert.id]
        if sourceAlert.parentId then
            copiedAlert.parentId = idMap[sourceAlert.parentId]
        end
        table.insert(copiedAlerts, copiedAlert)
    end

    for i = 1, table.getn(copiedAlerts) do
        table.insert(destinationDatabase.alerts, copiedAlerts[i])
    end
    EnsureAlertOptions(destinationDatabase)
    return table.getn(copiedAlerts)
end

-- Case-insensitive wildcard matcher.
-- Only '*' has special meaning; all other characters are literal.
local function WildcardMatch(text, pattern)
    text = string.lower(text or "")
    pattern = string.lower(pattern or "")

    if pattern == "" then
        return false
    end
    if pattern == "*" then
        return true
    end

    local p = 1
    local t = 1
    local plen = string.len(pattern)
    local tlen = string.len(text)
    local lastStar = 0
    local lastMatch = 0

    while t <= tlen do
        if p <= plen then
            local pc = string.sub(pattern, p, p)

            if pc ~= "*" and pc == string.sub(text, t, t) then
                p = p + 1
                t = t + 1
            elseif pc == "*" then
                lastStar = p
                p = p + 1
                lastMatch = t
            elseif lastStar > 0 then
                p = lastStar + 1
                lastMatch = lastMatch + 1
                t = lastMatch
            else
                return false
            end
        elseif lastStar > 0 then
            p = lastStar + 1
            lastMatch = lastMatch + 1
            t = lastMatch
        else
            return false
        end
    end

    while p <= plen and string.sub(pattern, p, p) == "*" do
        p = p + 1
    end

    return p > plen
end

local function ExpandPattern(pattern)
    local petName = UnitName("pet")

    if string.find(string.lower(pattern or ""), "currentpet", 1, true) then
        if not petName or petName == "" then
            return nil
        end
        return string.gsub(pattern, "currentpet", petName)
    end

    return pattern
end

local function Matches(alert, message)
    if not alert.enabled or not alert.pattern or alert.pattern == "" then
        return false
    end

    local pattern = ExpandPattern(alert.pattern)
    if not pattern then
        return false
    end

    if not WildcardMatch(message, pattern) then
        return false
    end

    local exceptions = alert.exceptions or ""
    local exceptionPattern
    for exceptionPattern in string.gfind(exceptions, "[^|]+") do
        exceptionPattern = string.gsub(exceptionPattern, "^%s+", "")
        exceptionPattern = string.gsub(exceptionPattern, "%s+$", "")
        if exceptionPattern ~= "" then
            exceptionPattern = ExpandPattern(exceptionPattern)
            if exceptionPattern and string.find(
                string.lower(message or ""),
                string.lower(exceptionPattern),
                1,
                true) then
                return false
            end
        end
    end

    return true
end

local function IsSpellcastPattern(pattern)
    local lowerPattern = string.lower(pattern or "")
    return string.find(lowerPattern, "spellcast_start", 1, true) == 1
        or string.find(lowerPattern, "spellcast_channel_start", 1, true) == 1
end

-- ============================================================
-- On-screen alert
-- ============================================================

local alertFrame = CreateFrame("Frame", "FortyOneSCombatAlertTextFrame", UIParent)
alertFrame:SetWidth(800)
alertFrame:SetHeight(120)
alertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
alertFrame:Hide()

local alertText = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
alertText:SetPoint("CENTER", alertFrame, "CENTER", 0, 0)
alertText:SetWidth(800)
alertText:SetJustifyH("CENTER")
alertText:SetTextColor(1, 0.2, 0.2)

local alertUntil = 0

alertFrame:SetScript("OnUpdate", function()
    if GetTime() >= alertUntil then
        this:Hide()
    end
end)

local function ShowAlert(text)
    alertText:SetText(text)
    alertUntil = GetTime() + ALERT_TIME
    alertFrame:Show()
end

local function PlayAlertSound(alert)
    local soundChoice = 1
    if alert and alert.soundChoice then
        soundChoice = alert.soundChoice
    end
    local soundOption = SOUND_OPTIONS[soundChoice] or SOUND_OPTIONS[1]
    if soundOption.customFile then
        if alert and alert.customFileName and alert.customFileName ~= "" then
            PlaySoundFile(ADDON_SOUND_DIRECTORY..alert.customFileName)
        end
    elseif soundOption.customMPQ then
        if alert and alert.customSoundPath and alert.customSoundPath ~= "" then
            PlaySoundFile(alert.customSoundPath)
        end
    else
        PlaySoundFile(soundOption.path)
    end
end

-- Message tokens are expanded for both screen text and chat reports.
-- Replace longer tokens first so %tt is not consumed as %t.
local function ExpandAlertText(text)
    local function UnitTokenName(unit, missingText)
        local name = UnitName(unit)
        if name and name ~= "" then return name end
        return missingText
    end

    text = text or ""
    text = string.gsub(text, "%%pet", function()
        return UnitTokenName("pet", "<no pet>")
    end)
    text = string.gsub(text, "%%tt", function()
        return UnitTokenName("targettarget", "<no target's target>")
    end)
    text = string.gsub(text, "%%t", function()
        return UnitTokenName("target", "<no target>")
    end)
    text = string.gsub(text, "%%p", function()
        return UnitTokenName("player", "<no player>")
    end)
    return text
end

-- Send the alert text to every selected chat channel.
-- Party and raid messages are skipped when the player is not in that type of group.
local function SendChatReport(alert)
    local text = ExpandAlertText(alert.text)
    if text == "" then
        return
    end

    if alert.chatParty and GetNumPartyMembers() > 0 then
        SendChatMessage(text, "PARTY")
    end
    if alert.chatRaid and GetNumRaidMembers() > 0 then
        SendChatMessage(text, "RAID")
    end
    if alert.chatSay then
        SendChatMessage(text, "SAY")
    end
    if alert.chatYell then
        SendChatMessage(text, "YELL")
    end
    if alert.chatGuild and GetGuildInfo("player") then
        SendChatMessage(text, "GUILD")
    end
    if alert.chatCustomChannel and alert.chatCustomChannel ~= "" then
        local channelNumber = GetChannelName(alert.chatCustomChannel)
        if channelNumber and channelNumber > 0 then
            SendChatMessage(text, "CHANNEL", nil, channelNumber)
        end
    end
end

local function TriggerAlert(alert)
    if alert.textEnabled and alert.text ~= "" then
        ShowAlert(ExpandAlertText(alert.text))
    end
    if alert.soundEnabled then
        PlayAlertSound(alert)
    end
    SendChatReport(alert)
end

local function GetChildAlerts(parent, alerts)
    local children = {}
    local i
    for i = 1, table.getn(alerts) do
        local alert = alerts[i]
        if alert.parentId == parent.id and alert.enabled then
            table.insert(children, alert)
        end
    end
    return children
end

local function SelectGroupReaction(parent, alerts)
    local children = GetChildAlerts(parent, alerts)
    if not parent.playMode or table.getn(children) == 0 then
        return parent
    end

    local choices = { parent }
    local i
    for i = 1, table.getn(children) do
        table.insert(choices, children[i])
    end

    if parent.playMode == "random" then
        return choices[math.random(1, table.getn(choices))]
    end

    parent.sequencePosition = (parent.sequencePosition or 0) + 1
    if parent.sequencePosition > table.getn(choices) then
        parent.sequencePosition = 1
    end
    return choices[parent.sequencePosition]
end

local function ProcessAlertList(alerts, message, isSpellcastEvent)
    local i
    for i = 1, table.getn(alerts) do
        local alert = alerts[i]
        if not alert.parentId
            and (not isSpellcastEvent or IsSpellcastPattern(alert.pattern))
            and Matches(alert, message) then
            TriggerAlert(SelectGroupReaction(alert, alerts))
        end
    end
end

-- ============================================================
-- Vanilla 1.12.1 combat/spell events
-- ============================================================

local combatEvents = {
    "CHAT_MSG_COMBAT_SELF_HITS",
    "CHAT_MSG_COMBAT_SELF_MISSES",
    "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS",
    "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES",
    "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS",
    "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES",
    "CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS",
    "CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES",
    "CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS",
    "CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES",
    "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS",
    "CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES",
    "CHAT_MSG_COMBAT_PARTY_HITS",
    "CHAT_MSG_COMBAT_PARTY_MISSES",
    "CHAT_MSG_COMBAT_PET_HITS",
    "CHAT_MSG_COMBAT_PET_MISSES",
    "CHAT_MSG_COMBAT_HOSTILE_DEATH",
    "CHAT_MSG_COMBAT_FRIENDLY_DEATH",

    "CHAT_MSG_SPELL_SELF_DAMAGE",
    "CHAT_MSG_SPELL_SELF_BUFF",
    "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
    "CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF",
    "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF",
    "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE",
    "CHAT_MSG_SPELL_CREATURE_VS_PARTY_BUFF",
    "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF",
    "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF",
    "CHAT_MSG_SPELL_PARTY_DAMAGE",
    "CHAT_MSG_SPELL_PARTY_BUFF",
    "CHAT_MSG_SPELL_PET_DAMAGE",
    "CHAT_MSG_SPELL_PET_BUFF",

    "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS",

    "CHAT_MSG_SPELL_AURA_GONE_SELF",
    "CHAT_MSG_SPELL_AURA_GONE_PARTY",
    "CHAT_MSG_SPELL_AURA_GONE_OTHER",
    "CHAT_MSG_SPELL_BREAK_AURA",
    "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF",
    "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS",
    "CHAT_MSG_SPELL_FAILED_LOCALPLAYER"
}

local eventFrame = CreateFrame("Frame", "FortyOneSCombatAlertEventFrame", UIParent)

local i
for i = 1, table.getn(combatEvents) do
    eventFrame:RegisterEvent(combatEvents[i])
end
eventFrame:RegisterEvent("SPELLCAST_START")
eventFrame:RegisterEvent("SPELLCAST_CHANNEL_START")

eventFrame:SetScript("OnEvent", function()
    local message
    local isSpellcastEvent = false

    if event == "SPELLCAST_START" then
        message = "SPELLCAST_START "..(arg1 or "")
        isSpellcastEvent = true
    elseif event == "SPELLCAST_CHANNEL_START" then
        message = "SPELLCAST_CHANNEL_START "..(arg2 or "")
        isSpellcastEvent = true
    else
        message = arg1
    end

    if not message then
        return
    end

    ProcessAlertList(FortyOneSCombatAlertDB.alerts, message, isSpellcastEvent)
    ProcessAlertList(characterAlertDatabase.alerts, message,
        isSpellcastEvent)
end)

-- ============================================================
-- Configuration GUI
-- ============================================================

local config = CreateFrame("Frame", "FortyOneSCombatAlertConfigFrame", UIParent)
config:SetWidth(765)
config:SetHeight(620)
config:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
config:SetFrameStrata("DIALOG")
config:SetMovable(true)
config:EnableMouse(true)
config:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 11, top = 12, bottom = 11 }
})
config:Hide()

config:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then this:StartMoving() end
end)
config:SetScript("OnMouseUp", function()
    this:StopMovingOrSizing()
end)

local title = config:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", config, "TOP", 0, -20)
title:SetText("41's Combat Alert")

local info = config:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
info:SetPoint("TOPLEFT", config, "TOPLEFT", 25, -48)
info:SetWidth(600)
info:SetJustifyH("LEFT")
info:SetText("Use * as a wildcard. Matching is case-insensitive. currentpet will be replaced by your current pet's name.")

local close = CreateFrame("Button", nil, config, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", config, "TOPRIGHT", -5, -5)
close:SetScript("OnClick", function() config:Hide() end)

local listFrame = CreateFrame("Frame", "FortyOneSCombatAlertListFrame", config)
listFrame:SetPoint("TOPLEFT", config, "TOPLEFT", 20, -70)
listFrame:SetPoint("BOTTOMRIGHT", config, "BOTTOMRIGHT", -20, 62)

local scrollChild = CreateFrame("Frame", "FortyOneSCombatAlertListChild", listFrame)
scrollChild:SetWidth(735)
scrollChild:SetHeight(488)
scrollChild:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, 0)

local rows = {}
local rowHeight = 122
local ROWS_PER_PAGE = 4
local currentPage = 1
local activeAlertDatabase = FortyOneSCombatAlertDB
local accountTab
local characterTab
local pageLabel
local previousPage
local nextPage
local RefreshRows
local characterSourceDropdown
local copyCharacterButton
local shareCharacterButton
local selectedCharacterSourceKey
local UpdateCharacterTransferControls
local SelectAlertTab

local function GetActiveAlerts()
    return activeAlertDatabase.alerts
end

local function GetSavedPage(database)
    EnsureAccountDatabase()
    local uiState = FortyOneSCombatAlertDB.uiState
    if database == FortyOneSCombatAlertDB then
        return uiState.accountPage or 1
    end
    return uiState.characterPage or 1
end

local function SaveCurrentView()
    EnsureAccountDatabase()
    local uiState = FortyOneSCombatAlertDB.uiState
    if activeAlertDatabase == FortyOneSCombatAlertDB then
        uiState.activeTab = "account"
        uiState.accountPage = currentPage
    else
        uiState.activeTab = "character"
        uiState.characterPage = currentPage
    end
end

local function GetCharacterSourceKeys()
    EnsureAccountDatabase()
    local keys = {}
    local key
    for key, value in pairs(FortyOneSCombatAlertDB.characterAlerts) do
        if not value.shareParentKey then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end

local function SetCharacterSource(key)
    selectedCharacterSourceKey = key
    if characterSourceDropdown then
        UIDropDownMenu_SetText(key or "No character entries",
            characterSourceDropdown)
    end
    if UpdateCharacterTransferControls then
        UpdateCharacterTransferControls()
    end
end

characterSourceDropdown = CreateFrame("Frame",
    "FortyOneSCombatAlertCharacterDropdown", config, "UIDropDownMenuTemplate")
characterSourceDropdown:SetPoint("TOPLEFT", config, "TOPLEFT", 18, -38)
UIDropDownMenu_SetWidth(220, characterSourceDropdown)
UIDropDownMenu_Initialize(characterSourceDropdown, function()
    local keys = GetCharacterSourceKeys()
    local i
    for i = 1, table.getn(keys) do
        local key = keys[i]
        local menuInfo = UIDropDownMenu_CreateInfo()
        menuInfo.text = key
        menuInfo.func = function()
            SetCharacterSource(key)
        end
        UIDropDownMenu_AddButton(menuInfo)
    end
end)

copyCharacterButton = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
copyCharacterButton:SetWidth(80)
copyCharacterButton:SetHeight(22)
copyCharacterButton:SetPoint("LEFT", characterSourceDropdown, "RIGHT", -10, 2)
copyCharacterButton:SetText("Copy")

shareCharacterButton = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
shareCharacterButton:SetWidth(80)
shareCharacterButton:SetHeight(22)
shareCharacterButton:SetPoint("LEFT", copyCharacterButton, "RIGHT", 5, 0)
shareCharacterButton:SetText("Share")

UpdateCharacterTransferControls = function()
    local sourceDatabase
    local currentCharacterKey = GetCurrentCharacterKey()

    if currentCharacterStorage.shareParentKey then
        shareCharacterButton:SetText("Stop Share")
        shareCharacterButton:Enable()
        copyCharacterButton:Disable()
        return
    end

    shareCharacterButton:SetText("Share")
    if selectedCharacterSourceKey then
        sourceDatabase =
            FortyOneSCombatAlertDB.characterAlerts[selectedCharacterSourceKey]
    end

    if sourceDatabase and selectedCharacterSourceKey ~= currentCharacterKey and
        not currentCharacterStorage.shareParentKey then
        copyCharacterButton:Enable()
    else
        copyCharacterButton:Disable()
    end

    if sourceDatabase and selectedCharacterSourceKey ~= currentCharacterKey and
        currentCharacterStorage.shareParentKey ~= selectedCharacterSourceKey then
        shareCharacterButton:Enable()
    else
        shareCharacterButton:Disable()
    end
end

copyCharacterButton:SetScript("OnClick", function()
    local sourceDatabase =
        FortyOneSCombatAlertDB.characterAlerts[selectedCharacterSourceKey]
    local copied = CopyAlertEntries(sourceDatabase,
        currentCharacterStorage)
    if copied > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff333341sCombatAlert|r copied "..
            copied.." alert(s) to this character.")
        SelectAlertTab(characterAlertDatabase)
    end
    UpdateCharacterTransferControls()
end)

shareCharacterButton:SetScript("OnClick", function()
    if currentCharacterStorage.shareParentKey then
        currentCharacterStorage.shareParentKey = nil
        characterAlertDatabase = currentCharacterStorage
        SetCharacterSource(GetCurrentCharacterKey())
        DEFAULT_CHAT_FRAME:AddMessage("|cffff333341sCombatAlert|r stopped "..
            "sharing alerts.")
        SelectAlertTab(characterAlertDatabase)
        UpdateCharacterTransferControls()
        return
    end

    local sourceDatabase =
        FortyOneSCombatAlertDB.characterAlerts[selectedCharacterSourceKey]
    local currentCharacterKey = GetCurrentCharacterKey()
    if sourceDatabase and selectedCharacterSourceKey ~= currentCharacterKey then
        currentCharacterStorage.shareParentKey = selectedCharacterSourceKey
        characterAlertDatabase = sourceDatabase
        SetCharacterSource(selectedCharacterSourceKey)
        DEFAULT_CHAT_FRAME:AddMessage("|cffff333341sCombatAlert|r now shares "..
            "alerts with "..selectedCharacterSourceKey..".")
        SelectAlertTab(characterAlertDatabase)
    end
    UpdateCharacterTransferControls()
end)

accountTab = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
accountTab:SetWidth(85)
accountTab:SetHeight(28)
accountTab:SetPoint("BOTTOMRIGHT", config, "BOTTOMRIGHT", -139, 18)
accountTab:SetText("Account")

characterTab = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
characterTab:SetWidth(105)
characterTab:SetHeight(28)
characterTab:SetPoint("LEFT", accountTab, "RIGHT", 5, 0)
characterTab:SetText("Character")

SelectAlertTab = function(database)
    SaveCurrentView()
    activeAlertDatabase = database
    currentPage = GetSavedPage(database)
    if activeAlertDatabase == FortyOneSCombatAlertDB then
        accountTab:Disable()
        characterTab:Enable()
        info:Show()
        characterSourceDropdown:Hide()
        copyCharacterButton:Hide()
        shareCharacterButton:Hide()
    else
        accountTab:Enable()
        characterTab:Disable()
        info:Hide()
        characterSourceDropdown:Show()
        copyCharacterButton:Show()
        shareCharacterButton:Show()
    end
    RefreshRows()
    if UpdateCharacterTransferControls then
        UpdateCharacterTransferControls()
    end
end

accountTab:SetScript("OnClick", function()
    SelectAlertTab(FortyOneSCombatAlertDB)
end)
characterTab:SetScript("OnClick", function()
    SelectAlertTab(characterAlertDatabase)
end)
accountTab:Disable()

-- A self-contained edit box skin.  InputBoxTemplate can render incorrectly
-- in the 1.12 client when several unnamed edit boxes share one parent.
local function CreateInputBox(parent)
    local input = CreateFrame("EditBox", nil, parent)
    input:SetHeight(24)
    input:SetAutoFocus(false)
    input:SetFontObject(GameFontHighlightSmall)
    input:SetTextColor(1, 1, 1)
    input:SetJustifyH("LEFT")
    input:SetTextInsets(6, 6, 0, 0)
    input:SetMaxLetters(255)
    input:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    input:SetBackdropColor(0.03, 0.03, 0.03, 0.9)
    input:SetBackdropBorderColor(0.65, 0.65, 0.65, 1)
    input:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    input:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    return input
end

local function SetSoundDropdownSelection(row, choice)
    local alert = row.alert
    if not alert then return end

    alert.soundChoice = choice
    UIDropDownMenu_SetSelectedID(row.soundDropdown, choice)
    UIDropDownMenu_SetText(SOUND_OPTIONS[choice].name, row.soundDropdown)
end

local function AddSoundDropdownOption(row, choice)
    local info = UIDropDownMenu_CreateInfo()
    info.text = SOUND_OPTIONS[choice].name
    info.func = function()
        SetSoundDropdownSelection(row, choice)
    end
    UIDropDownMenu_AddButton(info)
end

local function BuildDisplayEntries()
    local entries = {}
    local parents = {}
    local parentNumber = 0
    local i
    local j

    local alerts = GetActiveAlerts()
    for i = 1, table.getn(alerts) do
        local parent = alerts[i]
        if not parent.parentId then
            table.insert(parents, { alert = parent, recordIndex = i })
        end
    end
    table.sort(parents, function(left, right)
        return (left.alert.displayOrder or left.recordIndex) <
            (right.alert.displayOrder or right.recordIndex)
    end)

    for i = 1, table.getn(parents) do
        local parentEntry = parents[i]
        local parent = parentEntry.alert
            parentNumber = parentNumber + 1
            table.insert(entries, {
                alert = parent,
                recordIndex = parentEntry.recordIndex,
                isChild = false,
                label = tostring(parentNumber)
            })

            local children = {}
            for j = 1, table.getn(alerts) do
                local child = alerts[j]
                if child.parentId == parent.id then
                    table.insert(children, { alert = child, recordIndex = j })
            end
        end
        table.sort(children, function(left, right)
            return (left.alert.displayOrder or left.recordIndex) <
                (right.alert.displayOrder or right.recordIndex)
        end)

        local childNumber = 0
        for j = 1, table.getn(children) do
            local childEntry = children[j]
            local child = childEntry.alert
                    childNumber = childNumber + 1
                    table.insert(entries, {
                        alert = child,
                        recordIndex = childEntry.recordIndex,
                        parent = parent,
                        isChild = true,
                        label = tostring(parentNumber).."."..childNumber
                    })
                end
            end

    return entries
end

local function MoveAlert(alert, isChild, parent, direction)
    local candidates = {}
    local alerts = GetActiveAlerts()
    local i

    for i = 1, table.getn(alerts) do
        local candidate = alerts[i]
        if (isChild and parent and candidate.parentId == parent.id) or
            (not isChild and not candidate.parentId) then
            table.insert(candidates, candidate)
        end
    end

    table.sort(candidates, function(left, right)
        return (left.displayOrder or 0) < (right.displayOrder or 0)
    end)

    for i = 1, table.getn(candidates) do
        if candidates[i] == alert then
            local targetIndex = i + direction
            if candidates[targetIndex] then
                local originalOrder = alert.displayOrder
                alert.displayOrder = candidates[targetIndex].displayOrder
                candidates[targetIndex].displayOrder = originalOrder
                RefreshRows()
            end
            return
        end
    end
end

local function AddChildAlert(parent, mode)
    parent.playMode = mode
    parent.sequencePosition = 0

    local child = {
        id = CreateAlertId(activeAlertDatabase),
        displayOrder = table.getn(GetActiveAlerts()) + 1,
        parentId = parent.id,
        exceptions = "",
        chatGuild = false,
        chatCustomChannel = "",
        enabled = true,
        textEnabled = true,
        soundEnabled = true,
        soundChoice = 1,
        soundChoiceVersion = 4,
        customFileName = "",
        customSoundPath = "Sound\\Interface\\RaidWarning.wav",
        chatParty = false,
        chatRaid = false,
        chatSay = false,
        chatYell = false,
        text = "ALERT!"
    }
    table.insert(GetActiveAlerts(), child)

    local entries = BuildDisplayEntries()
    local i
    for i = 1, table.getn(entries) do
        if entries[i].alert == child then
            currentPage = math.ceil(i / ROWS_PER_PAGE)
            break
        end
    end
    RefreshRows()
end

local pendingDeleteAlertId

local function DeleteAlertById(alertId)
    local target
    local targetIndex
    local i

    local alerts = GetActiveAlerts()
    for i = 1, table.getn(alerts) do
        if alerts[i].id == alertId then
            target = alerts[i]
            targetIndex = i
            break
        end
    end

    if not target then return end

    if target.parentId then
        table.remove(alerts, targetIndex)
    else
        for i = table.getn(alerts), 1, -1 do
            local alert = alerts[i]
            if alert.id == alertId or alert.parentId == alertId then
                table.remove(alerts, i)
            end
        end
    end
    RefreshRows()
end

StaticPopupDialogs["FORTYONESCOMBATALERT_DELETE_ALERT"] = {
    text = "Are you sure you want to delete %s?",
    button1 = "Delete",
    button2 = "Cancel",
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    OnAccept = function()
        if pendingDeleteAlertId then
            DeleteAlertById(pendingDeleteAlertId)
            pendingDeleteAlertId = nil
        end
    end,
    OnCancel = function()
        pendingDeleteAlertId = nil
    end
}

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetWidth(720)
    row:SetHeight(rowHeight)

    row.number = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.number:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -7)

    row.moveUp = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.moveUp:SetWidth(18)
    row.moveUp:SetHeight(16)
    row.moveUp:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -45)
    row.moveUp:SetText("^")

    row.moveDown = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.moveDown:SetWidth(18)
    row.moveDown:SetHeight(16)
    row.moveDown:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -62)
    row.moveDown:SetText("v")

    row.patternLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.patternLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -8)
    row.patternLabel:SetText("Pattern:")

    row.pattern = CreateInputBox(row)
    row.pattern:SetWidth(270)
    row.pattern:SetHeight(24)
    row.pattern:SetPoint("TOPLEFT", row, "TOPLEFT", 90, -4)
    row.pattern:SetAutoFocus(false)

    row.textLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.textLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -38)
    row.textLabel:SetText("Text:")

    row.text = CreateInputBox(row)
    row.text:SetWidth(450)
    row.text:SetHeight(24)
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 90, -32)
    row.text:SetAutoFocus(false)

    row.enabled = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.enabled:SetPoint("TOPLEFT", row, "TOPLEFT", 550, 0)
    row.enabledLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.enabledLabel:SetPoint("LEFT", row.enabled, "RIGHT", 0, 0)
    row.enabledLabel:SetText("Enable")


    row.textEnabled = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.textEnabled:SetPoint("TOPLEFT", row, "TOPLEFT", 550, -28)
    row.textEnabledLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.textEnabledLabel:SetPoint("LEFT", row.textEnabled, "RIGHT", 0, 0)
    row.textEnabledLabel:SetText("Text")

    row.soundEnabled = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.soundEnabled:SetPoint("TOPLEFT", row, "TOPLEFT", 550, -56)
    row.soundEnabledLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.soundEnabledLabel:SetPoint("LEFT", row.soundEnabled, "RIGHT", 0, 0)
    row.soundEnabledLabel:SetText("Sound")
    
    row.test = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.test:SetWidth(75)
    row.test:SetHeight(22)
    row.test:SetPoint("TOPRIGHT", row, "TOPRIGHT", -5, -31)
    row.test:SetText("Test")

    row.exceptionsLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.exceptionsLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 370, -9)
    row.exceptionsLabel:SetText("Except:")

    row.exceptions = CreateInputBox(row)
    row.exceptions:SetWidth(130)
    row.exceptions:SetHeight(24)
    row.exceptions:SetPoint("TOPLEFT", row, "TOPLEFT", 410, -4)
    row.exceptions:SetAutoFocus(false)
    row.exceptions:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Exception text")
        GameTooltip:AddLine("Separate multiple entries with |", 1, 1, 1)
        GameTooltip:AddLine("Containing an entry prevents this alert.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    row.exceptions:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    row.createChild = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.createChild:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -75)
    row.createChild:SetText("Create Child:")

    row.sequence = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.sequence:SetWidth(75)
    row.sequence:SetHeight(22)
    row.sequence:SetPoint("TOPLEFT", row, "TOPLEFT", 560, -88)
    row.sequence:SetText("Sequence")

    row.random = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.random:SetWidth(75)
    row.random:SetHeight(22)
    row.random:SetPoint("TOPLEFT", row, "TOPLEFT", 640, -88)
    row.random:SetText("Random")

    row.chatLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.chatLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -96)
    row.chatLabel:SetText("Report:")

    row.chatParty = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.chatParty:SetPoint("TOPLEFT", row, "TOPLEFT", 85, -85)
    row.chatPartyLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.chatPartyLabel:SetPoint("LEFT", row.chatParty, "RIGHT", 0, 0)
    row.chatPartyLabel:SetText("Party")

    row.chatRaid = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.chatRaid:SetPoint("TOPLEFT", row, "TOPLEFT", 155, -85)
    row.chatRaidLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.chatRaidLabel:SetPoint("LEFT", row.chatRaid, "RIGHT", 0, 0)
    row.chatRaidLabel:SetText("Raid")

    row.chatSay = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.chatSay:SetPoint("TOPLEFT", row, "TOPLEFT", 225, -85)
    row.chatSayLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.chatSayLabel:SetPoint("LEFT", row.chatSay, "RIGHT", 0, 0)
    row.chatSayLabel:SetText("Say")

    row.chatYell = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.chatYell:SetPoint("TOPLEFT", row, "TOPLEFT", 295, -85)
    row.chatYellLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.chatYellLabel:SetPoint("LEFT", row.chatYell, "RIGHT", 0, 0)
    row.chatYellLabel:SetText("Yell")

    row.chatGuild = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.chatGuild:SetPoint("TOPLEFT", row, "TOPLEFT", 365, -85)
    row.chatGuildLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.chatGuildLabel:SetPoint("LEFT", row.chatGuild, "RIGHT", 0, 0)
    row.chatGuildLabel:SetText("Guild")

    row.chatCustomChannelLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.chatCustomChannelLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 445, -96)
    row.chatCustomChannelLabel:SetText("Ch:")

    row.chatCustomChannel = CreateInputBox(row)
    row.chatCustomChannel:SetWidth(75)
    row.chatCustomChannel:SetHeight(24)
    row.chatCustomChannel:SetPoint("TOPLEFT", row, "TOPLEFT", 465, -88)
    row.chatCustomChannel:SetAutoFocus(false)
    row.chatCustomChannel:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Custom chat channel")
        GameTooltip:AddLine("Enter a channel you have joined.", 1, 1, 1)
        GameTooltip:AddLine("The alert Text is sent to this channel.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    row.chatCustomChannel:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row.soundLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.soundLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -66)
    row.soundLabel:SetText("Sound:")

    row.soundDropdown = CreateFrame("Frame",
        "FortyOneSCombatAlertSoundDropdown"..index, row, "UIDropDownMenuTemplate")
    row.soundDropdown:SetPoint("TOPLEFT", row, "TOPLEFT", 70, -58)
    UIDropDownMenu_SetWidth(90, row.soundDropdown)
    UIDropDownMenu_Initialize(row.soundDropdown, function()
        local choice
        for choice = 1, table.getn(SOUND_OPTIONS) do
            AddSoundDropdownOption(row, choice)
        end
    end)

    row.customFileLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.customFileLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 205, -66)
    row.customFileLabel:SetText("File:")

    row.customFileName = CreateInputBox(row)
    row.customFileName:SetWidth(95)
    row.customFileName:SetHeight(24)
    row.customFileName:SetPoint("TOPLEFT", row, "TOPLEFT", 230, -60)
    row.customFileName:SetAutoFocus(false)
    row.customFileName:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Custom addon sound file")
        GameTooltip:AddLine("Put a WAV file in Interface\\AddOns\\41sCombatAlert\\Sounds\\", 1, 1, 1)
        GameTooltip:AddLine("Enter the filename only, for example: MySound.wav", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    row.customFileName:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row.customSoundLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.customSoundLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 335, -66)
    row.customSoundLabel:SetText("MPQ:")

    row.customSoundPath = CreateInputBox(row)
    row.customSoundPath:SetWidth(170)
    row.customSoundPath:SetHeight(24)
    row.customSoundPath:SetPoint("TOPLEFT", row, "TOPLEFT", 370, -60)
    row.customSoundPath:SetAutoFocus(false)
    row.customSoundPath:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Custom MPQ sound path")
        GameTooltip:AddLine("Enter a WAV path inside WoW's game archives.", 1, 1, 1)
        GameTooltip:AddLine("Example: Sound\\Interface\\RaidWarning.wav", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("This is not a Windows file path.", 1, 0.3, 0.3)
        GameTooltip:Show()
    end)
    row.customSoundPath:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row.delete = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.delete:SetWidth(75)
    row.delete:SetHeight(22)
    row.delete:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", -5, -26)
    row.delete:SetText("Delete")

    row.pattern:SetScript("OnTextChanged", function()
        local r=this.caRow
        if r and r.alert and not r.isChild then
            r.alert.pattern=this:GetText()
        end
    end)

    row.text:SetScript("OnTextChanged", function()
        local r=this.caRow
        if r and r.alert then
            r.alert.text=this:GetText()
        end
    end)

    row.chatCustomChannel:SetScript("OnTextChanged", function()
        local r=this.caRow
        if r and r.alert then
            r.alert.chatCustomChannel=this:GetText()
        end
    end)

    row.exceptions:SetScript("OnTextChanged", function()
        local r=this.caRow
        if r and r.alert then
            r.alert.exceptions=this:GetText()
        end
    end)

    row.enabled:SetScript("OnClick", function()
        local r=this.caRow
        if r and r.alert then
            r.alert.enabled=this:GetChecked()
        end
    end)

    row.chatGuild:SetScript("OnClick", function()
        local r=this.caRow
        if r and r.alert then
            r.alert.chatGuild=this:GetChecked()
        end
    end)

    row.textEnabled:SetScript("OnClick", function()
        local r=this.caRow
        if r and r.alert then
            r.alert.textEnabled=this:GetChecked()
        end
    end)

    row.soundEnabled:SetScript("OnClick", function()
        local r=this.caRow
        if r and r.alert then
            r.alert.soundEnabled=this:GetChecked()
        end
    end)
    
    row.test:SetScript("OnClick", function()
        local r=this.caRow
        if r and r.alert then
            TriggerAlert(r.alert)
        end
    end)

    row.customSoundPath:SetScript("OnTextChanged", function()
        local r=this.caRow
        if r and r.alert then
            r.alert.customSoundPath=this:GetText()
        end
    end)

    row.customFileName:SetScript("OnTextChanged", function()
        local r=this.caRow
        if r and r.alert then
            r.alert.customFileName=this:GetText()
        end
    end)

    row.chatParty:SetScript("OnClick", function()
        local r=this.caRow
        if r and r.alert then
            r.alert.chatParty=this:GetChecked()
        end
    end)

    row.chatRaid:SetScript("OnClick", function()
        local r=this.caRow
        if r and r.alert then
            r.alert.chatRaid=this:GetChecked()
        end
    end)

    row.chatSay:SetScript("OnClick", function()
        local r=this.caRow
        if r and r.alert then
            r.alert.chatSay=this:GetChecked()
        end
    end)

    row.chatYell:SetScript("OnClick", function()
        local r=this.caRow
        if r and r.alert then
            r.alert.chatYell=this:GetChecked()
        end
    end)

    row.delete:SetScript("OnClick", function()
        local r=this.caRow
        if r and r.alert then
            local description = "this alert"
            if r.isChild then
                description = "this child alert"
            else
                description = "this alert and all of its child alerts"
            end
            pendingDeleteAlertId = r.alert.id
            StaticPopup_Show("FORTYONESCOMBATALERT_DELETE_ALERT", description)
        end
    end)

    row.sequence:SetScript("OnClick", function()
        local r = this.caRow
        if r and r.alert and not r.isChild then
            AddChildAlert(r.alert, "sequence")
        end
    end)

    row.random:SetScript("OnClick", function()
        local r = this.caRow
        if r and r.alert and not r.isChild then
            AddChildAlert(r.alert, "random")
        end
    end)

    row.moveUp:SetScript("OnClick", function()
        local r = this.caRow
        if r and r.alert then
            MoveAlert(r.alert, r.isChild, r.parent, -1)
        end
    end)

    row.moveDown:SetScript("OnClick", function()
        local r = this.caRow
        if r and r.alert then
            MoveAlert(r.alert, r.isChild, r.parent, 1)
        end
    end)

    row.pattern.caRow=row
    row.text.caRow=row
    row.chatCustomChannel.caRow=row
    row.exceptions.caRow=row
    row.enabled.caRow=row
    row.chatGuild.caRow=row
    row.textEnabled.caRow=row
    row.soundEnabled.caRow=row
    row.test.caRow=row
    row.customFileName.caRow=row
    row.customSoundPath.caRow=row
    row.chatParty.caRow=row
    row.chatRaid.caRow=row
    row.chatSay.caRow=row
    row.chatYell.caRow=row
    row.delete.caRow=row
    row.sequence.caRow=row
    row.random.caRow=row
    row.moveUp.caRow=row
    row.moveDown.caRow=row
    row.index=index
    return row
end

RefreshRows = function()
    local entries = BuildDisplayEntries()
    local count=table.getn(entries)
    local pageCount=math.max(1,math.ceil(count/ROWS_PER_PAGE))
    local slot

    if currentPage>pageCount then currentPage=pageCount end
    if currentPage<1 then currentPage=1 end
    SaveCurrentView()

    for slot=1,ROWS_PER_PAGE do
        local index=((currentPage-1)*ROWS_PER_PAGE)+slot
        if not rows[slot] then rows[slot]=CreateRow(index) end
        local row=rows[slot]

        if index<=count then
            local entry = entries[index]
            local a = entry.alert
            row.index=entry.recordIndex
            row.recordIndex=entry.recordIndex
            row.alert=a
            row.parent=entry.parent
            row.isChild=entry.isChild
            row:SetPoint("TOPLEFT",scrollChild,"TOPLEFT",0,-((slot-1)*rowHeight))

            row.number:SetText(entry.label)
            if entry.isChild then
                row.patternLabel:SetText("Pattern:")
                row.pattern:SetText(entry.parent.pattern or "")
                row.pattern:SetTextColor(0.7, 0.7, 0.7)
                row.pattern:SetScript("OnEditFocusGained", function()
                    this:ClearFocus()
                end)
                row.sequence:Hide()
                row.random:Hide()
                row.createChild:Hide()
            else
                row.patternLabel:SetText("Pattern:")
                row.pattern:SetScript("OnEditFocusGained", nil)
                row.pattern:SetTextColor(1, 1, 1)
                row.pattern:SetText(a.pattern or "")
                row.sequence:Show()
                row.random:Show()
                row.createChild:Show()
            end
            row.text:SetText(a.text or "")
            row.chatCustomChannel:SetText(a.chatCustomChannel or "")
            row.exceptions:SetText(a.exceptions or "")
            row.enabled:SetChecked(a.enabled)
            row.chatGuild:SetChecked(a.chatGuild)
            row.textEnabled:SetChecked(a.textEnabled)
            row.soundEnabled:SetChecked(a.soundEnabled)
            UIDropDownMenu_SetSelectedID(row.soundDropdown, a.soundChoice or 1)
            UIDropDownMenu_SetText(SOUND_OPTIONS[a.soundChoice or 1].name,
                row.soundDropdown)
            row.customFileName:SetText(a.customFileName or "")
            row.customSoundPath:SetText(a.customSoundPath or "Sound\\Interface\\RaidWarning.wav")
            row.chatParty:SetChecked(a.chatParty)
            row.chatRaid:SetChecked(a.chatRaid)
            row.chatSay:SetChecked(a.chatSay)
            row.chatYell:SetChecked(a.chatYell)
            row:Show()
        else
            row:Hide()
        end
    end

    if pageLabel then pageLabel:SetText("Page "..currentPage.."/"..pageCount) end
    if previousPage then
        if currentPage>1 then previousPage:Enable() else previousPage:Disable() end
    end
    if nextPage then
        if currentPage<pageCount then nextPage:Enable() else nextPage:Disable() end
    end
end

local add=CreateFrame("Button",nil,config,"UIPanelButtonTemplate")
add:SetWidth(120)
add:SetHeight(28)
add:SetPoint("BOTTOMLEFT",config,"BOTTOMLEFT",25,18)
add:SetText("Add Alert")
add:SetScript("OnClick",function()
    table.insert(GetActiveAlerts(),{
        id=CreateAlertId(activeAlertDatabase), displayOrder=table.getn(GetActiveAlerts()) + 1, enabled=true, pattern="", exceptions="", chatGuild=false, chatCustomChannel="", textEnabled=true,
        soundEnabled=true, soundChoice=1, soundChoiceVersion=4,
        customFileName="",
        customSoundPath="Sound\\Interface\\RaidWarning.wav",
        chatParty=false, chatRaid=false,
        chatSay=false, chatYell=false, text="ALERT!"
    })
    currentPage=math.ceil(table.getn(BuildDisplayEntries())/ROWS_PER_PAGE)
    RefreshRows()
end)

previousPage=CreateFrame("Button",nil,config,"UIPanelButtonTemplate")
previousPage:SetWidth(80)
previousPage:SetHeight(28)
previousPage:SetPoint("BOTTOMLEFT",config,"BOTTOMLEFT",145,18)
previousPage:SetText("Previous")
previousPage:SetScript("OnClick",function()
    if currentPage>1 then
        currentPage=currentPage-1
        RefreshRows()
    end
end)

pageLabel=config:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
pageLabel:SetWidth(80)
pageLabel:SetPoint("LEFT",previousPage,"RIGHT",5,0)
pageLabel:SetJustifyH("CENTER")

nextPage=CreateFrame("Button",nil,config,"UIPanelButtonTemplate")
nextPage:SetWidth(80)
nextPage:SetHeight(28)
nextPage:SetPoint("LEFT",pageLabel,"RIGHT",5,0)
nextPage:SetText("Next")
nextPage:SetScript("OnClick",function()
    local pageCount=math.max(1,math.ceil(table.getn(BuildDisplayEntries())/ROWS_PER_PAGE))
    if currentPage<pageCount then
        currentPage=currentPage+1
        RefreshRows()
    end
end)

local function ShowConfig()
    SelectAlertTab(activeAlertDatabase)
    config:Show()
end

-- ============================================================
-- Minimap button
-- ============================================================

local minimapButton = CreateFrame("Button", "FortyOneSCombatAlertMinimapButton", Minimap)
minimapButton:SetWidth(32)
minimapButton:SetHeight(32)
minimapButton:SetFrameStrata("HIGH")
minimapButton:SetPoint("CENTER", UIParent, "CENTER")

local minimapIcon = minimapButton:CreateTexture(nil, "BORDER")
minimapIcon:SetTexture("Interface\\Icons\\Ability_Warrior_RallyingCry")
minimapIcon:SetWidth(20)
minimapIcon:SetHeight(20)
minimapIcon:SetPoint("CENTER", minimapButton, "CENTER")

local minimapBorder = minimapButton:CreateTexture(nil, "OVERLAY")
minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapBorder:SetWidth(52)
minimapBorder:SetHeight(52)
minimapBorder:SetPoint("TOPLEFT", minimapButton, "TOPLEFT")

local function UpdateMinimapButtonPosition(angle)
    local defaultAngle = math.rad(280)
    local x = math.cos(angle or defaultAngle) * 80
    local y = math.sin(angle or defaultAngle) * 80
    -- angle = angle or FortyOneSCombatAlertDB.minimapAngle or (math.pi * 0.75)

    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    FortyOneSCombatAlertDB.minimapAngle = angle
end

minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetMovable(true)
minimapButton:SetScript("OnDragStart", function()
    this:SetScript("OnUpdate", function()
        local cursorX, cursorY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local centerX, centerY = Minimap:GetCenter()
        UpdateMinimapButtonPosition(math.atan2((cursorY / scale) - centerY,
            (cursorX / scale) - centerX))
    end)
end)
minimapButton:SetScript("OnDragStop", function()
    this:SetScript("OnUpdate", nil)
end)
minimapButton:SetScript("OnClick", function()
    if config:IsShown() then
        config:Hide()
    else
        ShowConfig()
    end
end)
minimapButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("41's Combat Alert")
    GameTooltip:AddLine("Click to open settings.", 1, 1, 1)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

SLASH_FORTYONESCOMBATALERT1="/foca"

SlashCmdList["FORTYONESCOMBATALERT"]=function(msg)
    msg=string.lower(msg or "")
    if msg=="" or msg=="show" or msg=="config" then
        ShowConfig()
    elseif msg=="test" then
        ShowAlert("TEST ALERT")
        PlayAlertSound()
    elseif msg=="hide" then
        alertFrame:Hide()
    else
        DEFAULT_CHAT_FRAME:AddMessage("41sCombatAlert: /foca - open configuration")
        DEFAULT_CHAT_FRAME:AddMessage("41sCombatAlert: /foca test - test alert")
        DEFAULT_CHAT_FRAME:AddMessage("41sCombatAlert: /foca hide - hide alert")
    end
end

-- Startup
local startup=CreateFrame("Frame","FortyOneSCombatAlertStartupFrame",UIParent)
startup:RegisterEvent("PLAYER_LOGIN")
startup:SetScript("OnEvent",function()
    EnsureDefaults()
    BindCharacterAlertDatabase()
    EnsureCharacterDefaults()
    SetCharacterSource(currentCharacterStorage.shareParentKey or
        GetCurrentCharacterKey())
    UpdateMinimapButtonPosition()
    if FortyOneSCombatAlertDB.uiState.activeTab == "character" then
        SelectAlertTab(characterAlertDatabase)
    else
        SelectAlertTab(FortyOneSCombatAlertDB)
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffff333341sCombatAlert|r loaded. Type |cff66ccff/foca|r.")
end)
