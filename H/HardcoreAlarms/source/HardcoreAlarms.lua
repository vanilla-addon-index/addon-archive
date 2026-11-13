local HardcoreAlarms = LibStub("AceAddon-3.0"):NewAddon("HardcoreAlarms", "AceEvent-3.0", "AceTimer-3.0",
    "AceConsole-3.0", "AceConfig-3.0")

local AceDB = LibStub("AceDB-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local LibDBIcon = LibStub("LibDBIcon-1.0", true)
local LDB = LibStub("LibDataBroker-1.1", true)
local L = LibStub("AceLocale-3.0"):GetLocale("HardcoreAlarms")

-- List of all quest ids that the player will be warned about when the quest shows up in his log. See HardcoreAlarms:AddAllQuestStates()
HardcoreAlarms.QUESTIDS = { 3909, 7843, 1380, 6132, 552, 976, 685, 348, 4971, 1150, 1090, 1126, 4507, 217, 6134, 5781,
    3566, 608, 2359, 2381, 408 } --, 1001 } -- for testing purposes

-- List of all unit ids that the player will be warned about when the player targets it. See HardcoreAlarms:AddAllTargetStates()
HardcoreAlarms.UNITIDS = { 4966 } --, 4191 } -- for testing purposes

-- All possible warn levels that can be configured for a certain warning. Relevant for Options.lua
HardcoreAlarms.WARNLEVEL = {
    TEXT = "text",
    FLASHING_SCREEN = "flashing_screen",
    SOUND_ONCE = "sound_once",
    SOUND_REPEATING = "sound_repeating"
}

-- State priorities (lower number = lower priority)
HardcoreAlarms.STATE = {
    TEST_WARN = 0,
    PET_HP_WARN = 500,
    PLAYER_PVP_WARN = 1000,
    PET_HP_PANIC = 1500,
    TARGET_WARN_ENEMYPVPTARGET = 2000,
    TARGET_WARN_HIGHLVL = 3000,
    TARGET_WARN_ELITE = 4000,
    HP_WARN = 5000,
    BREATH_WARN = 6000,
    TARGET_WARN = 7000,
    QUEST_WARN = 8000,
    HP_PANIC = 9000,
    BREATH_PANIC = 10000
}

-- Corresponding text and title (etc.) for a particular state. Determines how the player is warned. More state warnings
-- are being added in HardcoreAlarms:AddAllQuestStates() and HardcoreAlarms:AddAllTargetStates()
HardcoreAlarms.STATE_WARNINGS = {
    [HardcoreAlarms.STATE.PLAYER_PVP_WARN] = {
        title = L["WARNING"], text = L["PLAYER_PVP_WARN"],
        fontSize = 16, isRepeating = false, isPanic = false,
        GetWarnConfig = function() return HardcoreAlarms.config.selfPvpFlaggedWarnLevel end },
    [HardcoreAlarms.STATE.HP_WARN] = {
        title = L["WARNING"], text = L["HP_WARN"],
        fontSize = 16, isRepeating = false, isPanic = false,
        GetWarnConfig = function() return HardcoreAlarms.config.hpWarnLevel end },
    [HardcoreAlarms.STATE.HP_PANIC] = {
        title = L["PANIC_WARNING"], text = L["HP_PANIC"],
        fontSize = 24, isRepeating = false, isPanic = true,
        GetWarnConfig = function() return HardcoreAlarms.config.hpWarnLevel end },
    [HardcoreAlarms.STATE.PET_HP_WARN] = {
        title = L["WARNING"], text = L["PET_HP_WARN"],
        fontSize = 16, isRepeating = false, isPanic = false,
        GetWarnConfig = function() return HardcoreAlarms.config.petHpWarnLevel end },
    [HardcoreAlarms.STATE.PET_HP_PANIC] = {
        title = L["PANIC_WARNING"], text = L["PET_HP_PANIC"],
        fontSize = 24, isRepeating = false, isPanic = true,
        GetWarnConfig = function() return HardcoreAlarms.config.petHpWarnLevel end },
    [HardcoreAlarms.STATE.BREATH_WARN] = {
        title = L["WARNING"], text = function() return string.format(L["BREATH_WARN_FMT"], HardcoreAlarms.breathTime) end,
        fontSize = 16, isRepeating = false, isPanic = false,
        GetWarnConfig = function() return HardcoreAlarms.config.breathWarnLevel end },
    [HardcoreAlarms.STATE.BREATH_PANIC] = {
        title = L["PANIC_WARNING"], text = function()
          return HardcoreAlarms.breathTime <= 0 and L["OUT_OF_BREATH"] or
                 string.format(L["BREATH_WARN_FMT"], HardcoreAlarms.breathTime)
        end,
        fontSize = 24, isRepeating = false, isPanic = true,
        GetWarnConfig = function() return HardcoreAlarms.config.breathWarnLevel end },
    [HardcoreAlarms.STATE.TARGET_WARN_ELITE] = {
        title = L["TARGET_WARNTITLE"], text = L["TARGET_WARN_ELITE"],
        fontSize = 16, isRepeating = false, isPanic = false,
        GetWarnConfig = function() return HardcoreAlarms.config.dangerousTargetEliteWarnLevel end },
    [HardcoreAlarms.STATE.TARGET_WARN_HIGHLVL] = {
        title = L["TARGET_WARNTITLE"], text = L["TARGET_WARN_HIGHLVL"],
        fontSize = 16, isRepeating = false, isPanic = false,
        GetWarnConfig = function() return HardcoreAlarms.config.dangerousTargetWarnLevel end },
    [HardcoreAlarms.STATE.TARGET_WARN_ENEMYPVPTARGET] = {
        title = L["TARGET_WARNTITLE"], text = L["TARGET_WARN_ENEMYPVPTARGET"],
        fontSize = 16, isRepeating = false, isPanic = false,
        GetWarnConfig = function() return HardcoreAlarms.config.dangerousTargetPvpWarnLevel end },
    [HardcoreAlarms.STATE.TEST_WARN] = {
        title = L["TEST_WARN_TITLE"], text = L["TEST_WARN_TEXT"],
        fontSize = 16, isRepeating = false, isPanic = false,
        GetWarnConfig = function() return HardcoreAlarms.config.testWarnLevel end },
}

-- UI styles config. This determines what the warning frame should look like.
HardcoreAlarms.WARNSTYLES = {
    BORDER_AND_BG = "o1",
    BG_ONLY = "o2",
    NO_BG = "o3",
}

HardcoreAlarms.WARNINGFRAME_MARGIN = 32 -- Margin value used in the warning frame
HardcoreAlarms.WARNINGFRAME_MAXWIDTH = 350 -- Determines max frame width, except when title needs it. Title is always displayed fully
HardcoreAlarms.UNITSCANFRAME_MAXWIDTH = 150 -- Determines max frame width, except when title needs it. Title is always displayed fully
HardcoreAlarms.UNITSCAN_DISMISSTIME = 30 -- For how many seconds a unitscan warning will be forcibly dismissed
HardcoreAlarms.UNITSCAN_INTERVAL = 5 -- Every x seconds the unitscan loop will check for dangerous targets

-- The complete config and its default values. All these values will be persisted in the local db.
HardcoreAlarms.config = {
    checkLoopInterval = 0.1,
    playSoundIntervalWarn = 5, -- PLAY SOUND PER SECOND (number of seconds)
    playSoundIntervalPanic = 2, -- PLAY SOUND PER SECOND (number of seconds)
    soundFileWarn = "RaidWarning", -- SOUND PLAYED, REFERENCE https://www.wowhead.com/classic/sounds
    soundFilePanic = "Interface\\AddOns\\HardcoreAlarms\\warning.mp3",
    soundChannel = "Master", -- SOUND CHANNEL USED FOR VOLUME ("MASTER", "SFX", "AMBIENCE", "MUSIC")
    breathWarnThreshold = 20, -- NUMBER OF SECONDS UNTIL SOUND PLAYS (seconds remaining)
    breathPanicThreshold = 8,
    hpWarnThreshold = 0.4,
    hpPanicThreshold = 0.2,
    petHpWarnThreshold = 0.4,
    petHpPanicThreshold = 0.2,
    oneshotWarnDuration = 10,
    leveldiffWarnThreshold = 4,
    leveldiffWarnEliteThreshold = -5,
    leveldiffWarnUnitscanThreshold = -5,
    breathWarnLevel = {
        [HardcoreAlarms.WARNLEVEL.TEXT] = true,
        [HardcoreAlarms.WARNLEVEL.FLASHING_SCREEN] = true,
        [HardcoreAlarms.WARNLEVEL.SOUND_REPEATING] = true },
    hpWarnLevel = {
        [HardcoreAlarms.WARNLEVEL.TEXT] = true,
        [HardcoreAlarms.WARNLEVEL.FLASHING_SCREEN] = true,
        [HardcoreAlarms.WARNLEVEL.SOUND_ONCE] = true },
    petHpWarnLevel = {
        [HardcoreAlarms.WARNLEVEL.TEXT] = true,
        [HardcoreAlarms.WARNLEVEL.FLASHING_SCREEN] = true,
        [HardcoreAlarms.WARNLEVEL.SOUND_ONCE] = true },
    dangerousTargetWarnLevel = {
        [HardcoreAlarms.WARNLEVEL.TEXT] = true,
        [HardcoreAlarms.WARNLEVEL.FLASHING_SCREEN] = true,
        [HardcoreAlarms.WARNLEVEL.SOUND_ONCE] = true },
    dangerousTargetEliteWarnLevel = {
        [HardcoreAlarms.WARNLEVEL.TEXT] = true,
        [HardcoreAlarms.WARNLEVEL.FLASHING_SCREEN] = true,
        [HardcoreAlarms.WARNLEVEL.SOUND_ONCE] = true },
    dangerousTargetPvpWarnLevel = {
        [HardcoreAlarms.WARNLEVEL.TEXT] = true,
        [HardcoreAlarms.WARNLEVEL.FLASHING_SCREEN] = true,
        [HardcoreAlarms.WARNLEVEL.SOUND_ONCE] = true },
    selfPvpFlaggedWarnLevel = {
        [HardcoreAlarms.WARNLEVEL.TEXT] = true,
        [HardcoreAlarms.WARNLEVEL.FLASHING_SCREEN] = true,
        [HardcoreAlarms.WARNLEVEL.SOUND_ONCE] = true },
    questWarnLevel = {
        [HardcoreAlarms.WARNLEVEL.TEXT] = true,
        [HardcoreAlarms.WARNLEVEL.FLASHING_SCREEN] = true,
        [HardcoreAlarms.WARNLEVEL.SOUND_ONCE] = true },
    testWarnLevel = {
        [HardcoreAlarms.WARNLEVEL.TEXT] = false,
        [HardcoreAlarms.WARNLEVEL.FLASHING_SCREEN] = false },
    unitscanWarnLevel = {
        [HardcoreAlarms.WARNLEVEL.TEXT] = true,
        [HardcoreAlarms.WARNLEVEL.FLASHING_SCREEN] = false,
        [HardcoreAlarms.WARNLEVEL.SOUND_ONCE] = true },
    warnStyle = HardcoreAlarms.WARNSTYLES.BORDER_AND_BG,
    blacklistedQuestIds = {},
    blacklistedUnitIds = {},
    blacklistedUnitscanNames = {},
    debugOutput = false,
    unitscanEnabled = true,
    unitscanInCombatEnabled = false,
    minimapIcon = { hide = false },
}

function HardcoreAlarms:OnInitialize()
    self:Print("Initializing...")
    self.db = AceDB:New("HardcoreAlarmsDB", { profile = self:ShallowCopy(self.config) }, true)
    HardcoreAlarmsPfDBHelper:SetPrint(function(msg) self:Print(msg) end)
    HardcoreAlarmsPrioritySet:SetPrint(function(msg) self:Print(msg) end)

    -- Apply saved settings to CONFIG
    self:ApplySettings()

    self:AddAllQuestStates()
    self:AddAllTargetStates()
    self:SetupWarningFrame()
    self:SetupUnitscanFrame()
    self:SetupFlashFrame()

    self:RegisterEvent("MIRROR_TIMER_START")
    self:RegisterEvent("MIRROR_TIMER_STOP")
    self:RegisterEvent("UNIT_HEALTH")  -- Register for health changes
    self:RegisterEvent("PLAYER_FLAGS_CHANGED")  -- Register for PvP status changes
    self:RegisterEvent("UNIT_PVP_UPDATE")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("QUEST_LOG_UPDATE")
    self:RegisterEvent("LOOT_OPENED")
    self:RegisterEvent("LOOT_CLOSED")

    -- Hook the Blizzard InspectFrame if it exists
    if InspectFrame then
        local origShow = InspectFrame.Show
        InspectFrame.Show = function(self)
            HardcoreAlarms.isInspecting = true
            HardcoreAlarms:Print("HardcoreAlarms.isInspecting: true")
            return origShow(self)
        end
        local origHide = InspectFrame.Hide
        InspectFrame.Hide = function(self)
            HardcoreAlarms.isInspecting = false
            HardcoreAlarms:Print("HardcoreAlarms.isInspecting: false")
            return origHide(self)
        end
    end

    self:SetupVars()
    self:StartCheckLoopTimer()
    self:StartUnitscanTimer()

    -- Register options
    self:RegisterOptionsTable("HardcoreAlarms", HardcoreAlarmsBuildOptions(self, LibDBIcon))
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("HardcoreAlarms", "HardcoreAlarms")

    -- LibDBIcon launcher. Shows an icon on the minimap.
    if LibDBIcon and LDB then
        local ldbObj = LDB:NewDataObject("HardcoreAlarms", {
            type = "launcher",
            icon = "Interface\\Icons\\Ability_warrior_rallyingcry",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    self:Print("Minimap icon left-clicked")
                    self:OpenOptions()
                end
            end,
            OnTooltipShow = function(tt)
                if not tt or not tt.AddLine then
                    return
                end
                tt:AddLine("HardcoreAlarms")
            end,
        })
        LibDBIcon:Register("HardcoreAlarms", ldbObj, self.db.profile.minimapIcon)
        if not self.db.profile.minimapIcon.hide then
            LibDBIcon:Show("HardcoreAlarms")
        end
    end

    -- Slash commands
    if self.RegisterChatCommand then
        self:RegisterChatCommand("hardcorealarms", "HandleChatCommand")
        self:RegisterChatCommand("hca", "HandleChatCommand")
    end
end

-- Goes through all QUESTIDS and adds the appropriate STATE_WARNINGS. This is just an initialization function so its
-- easier to add new quest ids.
function HardcoreAlarms:AddAllQuestStates()
    self:Print("AddAllQuestStates")
    for i, questId in ipairs(self.QUESTIDS) do
        local priority = self.STATE.QUEST_WARN + i - 1
        local textId = "QUEST_WARN_" .. questId
        local questTitle = HardcoreAlarmsPfDBHelper:GetQuestTitle(questId)
        if questTitle then
            self.STATE_WARNINGS[priority] = {
                    title = L["QUEST_WARNTITLE"] .. questTitle,
                    text = L[textId],
                    fontSize = 14, isRepeating = false, isPanic = false,
                    GetWarnConfig = function() return HardcoreAlarms.config.questWarnLevel end
                }
            self:Print("Priority: " .. tostring(priority) .. " - Watching for questId: '" .. tostring(questId) .. "', questTitle: '" .. questTitle .. "'")
        else
            self:Print("|cffff0000ERROR! AddAllQuestStates() questTitle is nil! questId: |r" .. tostring(questId))
        end
    end
end

-- Goes through all UNITIDS and adds the appropriate STATE_WARNINGS. This is just an initialization function so its
-- easier to add new unit ids.
function HardcoreAlarms:AddAllTargetStates()
    self:Print("AddAllTargetStates")
    for i, unitId in ipairs(self.UNITIDS) do
        local priority = self.STATE.TARGET_WARN + i - 1
        local textId = "TARGET_WARN_" .. unitId
        local unitName = HardcoreAlarmsPfDBHelper:GetUnitName(unitId)
        if unitName then
            self.STATE_WARNINGS[priority] = {
                    title = L["TARGET_WARNTITLE"] .. " - " .. unitName,
                    text = L[textId],
                    fontSize = 14, isRepeating = false, isPanic = false,
                    GetWarnConfig = function() return HardcoreAlarms.config.questWarnLevel end
                }
            self:Print("Priority: " .. tostring(priority) .. " - Watching for unitId: '" .. tostring(unitId) .. "', unitName: '" .. unitName .. "'")
        else
            self:Print("|cffff0000ERROR! AddAllTargetStates() unitName is nil! questId: |r" .. tostring(unitId))
        end
    end
end

function HardcoreAlarms:ShallowCopy(t)
    local t2 = {}
    for k,v in pairs(t) do
        t2[k] = v
    end
    return t2
end

-- Applies all values in db.profile to our runtime variable self.config. Should be run whenever an option has been
-- changed.
function HardcoreAlarms:ApplySettings()
    self:Print("ApplySettings")
    local checkLoopIntervalChanged = self.db.profile.checkLoopInterval ~= self.config.checkLoopInterval

    for k, v in pairs(self.db.profile) do
        self.config[k] = v
    end

    -- If check loop timer exists, restart it with the new interval
    if checkLoopIntervalChanged and self.checkTimer then
        self:CancelTimer(self.checkTimer)
        self.checkTimer = self:ScheduleRepeatingTimer("Check", self.config.checkLoopInterval)
    end
    if not self.config.unitscanEnabled and self.checkUnitscanTimer then
        self:CancelTimer(self.checkUnitscanTimer)
        self.checkUnitscanTimer = nil
    elseif self.config.unitscanEnabled and not self.checkUnitscanTimer then
        self:StartUnitscanTimer()
    end
    self:ApplyWarnStyle(self.warningFrame)
    self:ApplyWarnStyle(self.unitscanFrame)
    self:MakeTestframeMovable()
    if self.state then
        self:HandleStateChange()
    end
end

function HardcoreAlarms:RefreshBuildOptions()
    self:RegisterOptionsTable("HardcoreAlarms", HardcoreAlarmsBuildOptions(self, LibDBIcon))
end

-- This handles the slash command '/hca' or '/hardcorealarms'. Shows options or runs the test mode when '/hca test' is
-- called. Test mode allows to quickly cycle through all available warning frames to test proper functionality.
function HardcoreAlarms:HandleChatCommand(input)
    self:Print("HandleChatCommand: " .. tostring(input))
    local command = self:GetArgs(input, 1)

    if command == "test" then
        self.testEnabled = not self.testEnabled
        self.testState = 0
        if self.testEnabled then
            self.config.testWarnLevel[self.WARNLEVEL.TEXT] = true
            self.testButton:Show()
        else
            self.config.testWarnLevel[self.WARNLEVEL.TEXT] = false
            self.testButton:Hide()
        end
        self:ApplySettings()
    else
        self:OpenOptions()
    end
end

function HardcoreAlarms:OpenOptions()
    if _G["HardcoreAlarmsOptionsFrame"] == nil then
        self:Print("Opening options")
        self.optionsFrame = AceGUI:Create("Frame")
        self.optionsFrame:SetStatusText(L["OPT_INFO"])
        AceConfigDialog:Open("HardcoreAlarms", self.optionsFrame)
        _G["HardcoreAlarmsOptionsFrame"] = self.optionsFrame
        tinsert(UISpecialFrames, "HardcoreAlarmsOptionsFrame")
        self.optionsFrame:SetCallback("OnClose", function()
            HardcoreAlarms:Print("HardcoreAlarmsOptionsFrame OnClose")
            _G["HardcoreAlarmsOptionsFrame"] = nil
        end)
    else
        self:Print("Closing options")
        self.optionsFrame:Hide()
    end
end

-- Init function for our frames.
function HardcoreAlarms:SetupWarningFrame()
    self.warningFrame = CreateFrame("Frame", "HardcoreAlarmsWarning", UIParent)
    self.warningFrame:SetPoint("CENTER", 0, 200)
    self.warningFrame:SetMovable(true)
    self.warningFrame:Hide()

    self.warningTitle = self.warningFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    self.warningTitle:SetPoint("TOP", self.warningFrame, 0, -self.WARNINGFRAME_MARGIN / 2 + 2)
    self.warningTitle:SetTextColor(1, 0.843, 0)
    self.warningTitle:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")

    self.warningText = self.warningFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    self.warningText:SetTextColor(1, 0, 0)

    self.closeButton = CreateFrame("Button", "HardcoreAlarmsWarningCloseButton", self.warningFrame, "UIPanelCloseButton")
    self.closeButton:SetPoint("TOPRIGHT", self.warningFrame, "TOPRIGHT", -4, -4) -- typical offset used on Blizzard frames
    self.closeButton:SetScript("OnClick", function()
        local state = self.currentTextWinner
        local id = self.currentTextWinnerId
        self.state:Remove(state)
        if state >= self.STATE.QUEST_WARN and state < self.STATE.QUEST_WARN + 1000 then
            self.db.profile.blacklistedQuestIds[id] = true
            self:Print("Added QuestId: '" .. tostring(id) .. "' to blacklistedQuestIds")
        elseif state >= self.STATE.TARGET_WARN and state < self.STATE.TARGET_WARN + 1000 then
            self.db.profile.blacklistedUnitIds[id] = true
            self:Print("Added UnitId: '" .. tostring(id) .. "' to blacklistedUnitIds")
        end
        self:ApplySettings()
    end)
    self.testButton = CreateFrame("Button", "HardcoreAlarmsWarningTestButton", self.warningFrame, "UIPanelButtonTemplate")
    self.testButton:SetHeight(20)
    self.testButton:SetWidth(100)
    self.testButton:SetText("Next Test")
    self.testButton:SetPoint("TOP", self.warningFrame, "TOP", 0, 24)
    self.testButton:SetScript("OnClick", function()
        self.testState = self:IncrementTestCounter(self.testState)
        self:Print("new test state: " .. tostring(self.testState))
        self:HandleStateChange()
    end)
    self.testButton:Hide()

    self:ApplyWarnStyle(self.warningFrame)
    self:MakeTestframeMovable()
end

function HardcoreAlarms:SetupUnitscanFrame()
    self.unitscanFrame = CreateFrame("Frame", "HardcoreAlarmsUnitscan", UIParent)
    self.unitscanFrame:SetWidth(240)
    self.unitscanFrame:SetHeight(72)
    self.unitscanFrame:SetPoint("CENTER", UIParent, 300, 0)
    self.unitscanFrame:SetScript("OnMouseDown", function()
            if HardcoreAlarms.currentUnitscanResult then
                TargetByName(HardcoreAlarms.currentUnitscanResult, true)
            end
        end)
    self.unitscanFrame:EnableMouse(true)
    self.unitscanFrame:SetMovable(true)
    self.unitscanFrame:Hide()

    self.unitscanCloseButton = CreateFrame("Button", "HardcoreAlarmsUnitscanCloseButton", self.unitscanFrame, "UIPanelCloseButton")
    self.unitscanCloseButton:SetPoint("TOPRIGHT", self.unitscanFrame, "TOPRIGHT", -4, -4) -- typical offset used on Blizzard frames
    self.unitscanCloseButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(HardcoreAlarms.unitscanCloseButton, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["UNITSCAN_WARNING_CLOSE_TOOLTIP"], 1, 1, 1)
        GameTooltip:AddLine(L["UNITSCAN_WARNING_CLOSE_TOOLTIP_TEXT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    self.unitscanCloseButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.unitscanCloseButton:SetScript("OnClick", function()
        if not self.currentUnitscanResult then return end
        if IsShiftKeyDown() then
            self.db.profile.blacklistedUnitscanNames[self.currentUnitscanResult] = true
            self:Print("Added unitscan name: '" .. tostring(self.currentUnitscanResult) .. "' to blacklistedUnitscanNames")
            self:ApplySettings()
        else
            self.dismissedUnitscanNames[self.currentUnitscanResult] = GetTime()
            self:Print("Dismissed unitscan name: '" .. tostring(self.currentUnitscanResult) .. "'")
        end
        if not self.config.testWarnLevel[self.WARNLEVEL.TEXT] then
            self:HideUnitscanFrame()
        end
    end)

    self.unitscanPortrait = self.unitscanFrame:CreateTexture("HardcoreAlarmsUnitscanPortrait", "ARTWORK")
    self.unitscanPortrait:SetWidth(40)
    self.unitscanPortrait:SetHeight(40)
    self.unitscanPortrait:SetPoint("LEFT", 16, 0)

    self.unitscanText = self.unitscanFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.unitscanText:SetPoint("LEFT", self.unitscanPortrait, "RIGHT", 8, 0)
    self.unitscanText:SetJustifyH("LEFT")
    self.unitscanText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")

    self:ApplyWarnStyle(self.unitscanFrame)
    self:MakeTestframeMovable()
end

-- Given a testCounter it returns the next valid state priority. This way we can iterate through all of them.
function HardcoreAlarms:IncrementTestCounter(testCounter)
    local stateWarnings = {}
    for key, _ in pairs(HardcoreAlarms.STATE_WARNINGS) do
        table.insert(stateWarnings, key)
    end
    -- Sort the state warnings to ensure correct order
    table.sort(stateWarnings)
    for _, statePriority in ipairs(stateWarnings) do
        if statePriority > testCounter then
            return statePriority
        end
    end
    return 0 -- Return 0 if no higher state exists
end

function HardcoreAlarms:SetupFlashFrame()
    local f = CreateFrame("Frame", "HardcoreAlarmsFlash")
    f:Show()
    f:SetAllPoints()
    f:SetAlpha(0)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    local tex = f:CreateTexture()
    tex:SetBlendMode("ADD")
    tex:SetAllPoints()
    tex:SetTexture([[Interface\FullScreenTextures\LowHealth]])
    self.flashFrame = f
end

-- Shows a red flashing screen overlay. Very similar to a 'low hp'-warning effect.
function HardcoreAlarms:PlayFlashAnimation()
    self:Print("PlayFlashAnimation()")
    if not self.flashFrame then return end

    local rampUp = 0.2
    local hold   = 0.4
    local rampDn = 0.4
    local totalPerPulse = rampUp + hold + rampDn
    local pulses = 3
    local tickLimit = 0.02 -- seconds between updates

    local startTime = GetTime()
    local lastTick = startTime

    local function alphaForElapsed(t)
        if t < rampUp then
            return t / rampUp
        elseif t < rampUp + hold then
            return 1.0
        elseif t < totalPerPulse then
            return 1.0 - (t - rampUp - hold) / rampDn
        else
            return 0.0
        end
    end

    -- remove any existing OnUpdate
    self.flashFrame:SetScript("OnUpdate", nil)
    self.flashFrame:SetScript("OnUpdate", function(_, elapsed)
        local now = GetTime()
        -- throttle updates to tickLimit
        if now - lastTick < tickLimit then
            return
        end
        lastTick = now

        local totalElapsed = now - startTime
        local pulseIndex = math.floor(totalElapsed / totalPerPulse) + 1

        if pulseIndex > pulses then
            HardcoreAlarms:StopFlashAnimation()
            return
        end

        local elapsedInPulse = totalElapsed - (pulseIndex - 1) * totalPerPulse
        local a = alphaForElapsed(elapsedInPulse)
        self.flashFrame:SetAlpha(a)
    end)
end

function HardcoreAlarms:StopFlashAnimation()
    self.flashFrame:SetAlpha(0)
    self.flashFrame:SetScript("OnUpdate", nil)
end

-- Depending on which warn style has been selected, this function applies it to the actual warning frame.
function HardcoreAlarms:ApplyWarnStyle(frame)
    if frame == nil then return end

    local backdrop = nil
    if self.config.warnStyle ~= HardcoreAlarms.WARNSTYLES.NO_BG then
        backdrop = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        }
        if self.config.warnStyle == HardcoreAlarms.WARNSTYLES.BORDER_AND_BG then
            backdrop.edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border"
        end
    end
    frame:SetBackdrop(backdrop)
end

function HardcoreAlarms:MakeTestframeMovable()
    if self.warningFrame == nil or self.unitscanFrame == nil then return end

    if self.config.testWarnLevel[self.WARNLEVEL.TEXT] then
        self.warningFrame:EnableMouse(true)
        self.warningFrame:RegisterForDrag("LeftButton")
        self.warningFrame:SetScript("OnDragStart", function() this:StartMoving() end)
        self.warningFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
        self.unitscanFrame:RegisterForDrag("LeftButton")
        self.unitscanFrame:SetScript("OnDragStart", function() this:StartMoving() end)
        self.unitscanFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
        self:ShowUnitscanFrame("Test", "player")
    else
        self.warningFrame:EnableMouse(false) -- make it click-through
        self.warningFrame:RegisterForDrag()
        self.unitscanFrame:RegisterForDrag()
        self:HideUnitscanFrame()
    end
end

-- Initialize runtime variables
function HardcoreAlarms:SetupVars()
    self.breathTime = 60
    self.breathMaxTime = 60
    self.breathChange = 10
    self.pvpToggled = UnitIsPVP("player")
    self.state = HardcoreAlarmsPrioritySet:New()
    self.state:SetOnChanged(function(_) self:HandleStateChange() end)
    self.testEnabled = false
    self.testState = nil
    self.currentTextWinner = nil
    self.currentTextWinnerId = nil
    self.playedOneshotFor = {}
    self.showedFlashFor = {}
    self.oneshot_warning_text = ""
    self.programmaticTargets = {}
    self.dismissedUnitscanNames = {}
    self.unitscanSeenLast = {}
    self.unitscanWarned = {}
end

function HardcoreAlarms:OnEnable()
end

-- Prints a formatted message to the player's chat window. Set 'always' to true if you want to print a non-debug message.
function HardcoreAlarms:Print(msg, always)
    if self.config.debugOutput or always and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffcc[HardcoreAlarms]|r " .. tostring(msg))
    end
end

---------------------------------------------------------------------
-- START - EVENT LISTENERS registered in HardcoreAlarms:OnInitalize()
---------------------------------------------------------------------

-- Event used to track whenever breath rate changes. Meaning when the player is diving or surfacing.
function HardcoreAlarms:MIRROR_TIMER_START(eventName)
    local timer = arg1
    local value = arg2
    local maxvalue = arg3
    local scale = arg4
    --local paused = arg5
    --local label = arg6
    if timer == "BREATH" then
        self:Print("MIRROR_TIMER_START arg1: " .. tostring (timer) .. ", arg2: " .. tostring(value).. ", arg3: " .. tostring(maxvalue).. ", arg4: " .. tostring(scale))
        self.breathTime = value / 1000
        self.breathMaxTime = maxvalue / 1000
        self.breathChange = scale
    end
end

function HardcoreAlarms:MIRROR_TIMER_STOP(eventName)
    local timer = arg1
    if timer == "BREATH" then
        self:Print("MIRROR_TIMER_STOP arg1: " .. tostring (timer) .. ", self.breathMaxTime: "..self.breathMaxTime)
        self.breathTime = self.breathMaxTime
        self.breathChange = 10
    end
end

-- Event used to track whenever player health changes.
function HardcoreAlarms:UNIT_HEALTH(eventName)
    local unit = arg1
    if unit == "player" then
        if UnitIsDeadOrGhost("player") then
            self:Print("UNIT_HEALTH player is dead")
            self.state:Remove(self.STATE.HP_WARN)
            self.state:Remove(self.STATE.HP_PANIC)
        else
            local healthPercentage = UnitHealth("player") / UnitHealthMax("player")
            self:Print("UNIT_HEALTH healthPercentage: " .. healthPercentage)
            if healthPercentage <= self.config.hpWarnThreshold then
                self.state:Add(self.STATE.HP_WARN)
            else
                self.state:Remove(self.STATE.HP_WARN)
            end
            if healthPercentage <= self.config.hpPanicThreshold then
                self.state:Add(self.STATE.HP_PANIC)
            else
                self.state:Remove(self.STATE.HP_PANIC)
            end
        end
    end
    if unit == "pet" then
        local healthPercentage = UnitHealth("pet") / UnitHealthMax("pet")
        self:Print("UNIT_HEALTH pet healthPercentage: " .. healthPercentage)
        if healthPercentage <= 0 then
            self.state:Remove(self.STATE.PET_HP_WARN)
            self.state:Remove(self.STATE.PET_HP_PANIC)
        else
            if healthPercentage <= self.config.petHpWarnThreshold then
                self.state:Add(self.STATE.PET_HP_WARN)
            else
                self.state:Remove(self.STATE.PET_HP_WARN)
            end
            if healthPercentage <= self.config.petHpPanicThreshold then
                self.state:Add(self.STATE.PET_HP_PANIC)
            else
                self.state:Remove(self.STATE.PET_HP_PANIC)
            end
        end
    end
end

-- Event used to track whenever player pvp-flag changes.
function HardcoreAlarms:PLAYER_FLAGS_CHANGED()
    self.pvpToggled = UnitIsPVP("player") ~= nil
end

function HardcoreAlarms:UNIT_PVP_UPDATE(eventName)
    self:Print("UNIT_PVP_UPDATE")
    local unit = arg1
    if unit == "player" then
        self:PLAYER_FLAGS_CHANGED()
    end
end

-- Event used to track whenever the target changes. Used for all target-related warnings.
function HardcoreAlarms:PLAYER_TARGET_CHANGED()
    local targetName = UnitName("target")
    local targetKey = targetName or "__NONE__"
    if self.programmaticTargets[targetKey] and self.programmaticTargets[targetKey] > 0 then
        -- a programmatic target: decrement count, ignore further event processing
        self.programmaticTargets[targetKey] = self.programmaticTargets[targetKey] - 1
        --self:Print("PLAYER_TARGET_CHANGED ignored, targetKey: " .. tostring(targetKey) .. ", ignoreCounter: " .. tostring(self.programmaticTargets[targetKey]))
        return
    end

    local debugString = "PLAYER_TARGET_CHANGED target: '" .. tostring(targetName) .. "'"
    local isPlayer = UnitIsPlayer("target") or UnitPlayerControlled("target")
    local foundWantedUnit = false
    for i, unitId in ipairs(self.UNITIDS) do
        local priority = self.STATE.TARGET_WARN + i - 1
        if not isPlayer and HardcoreAlarmsPfDBHelper:GetUnitName(unitId) and targetName == HardcoreAlarmsPfDBHelper:GetUnitName(unitId) and
            self.config.blacklistedUnitIds[unitId] == nil then
            debugString = debugString .. ", isWanted: true"
            self.state:Add(priority, unitId)
            foundWantedUnit = true
        else
            self.state:Remove(priority)
        end
    end

    local isPvp = false
    local isElite = false
    local isHighLvl = false
    if not foundWantedUnit and not UnitIsDeadOrGhost("target") and UnitIsEnemy("target", "player") then
        debugString = debugString .. ", isDead: false, isEnemy: true"
        local inInstance, _instanceType = IsInInstance()
        if not inInstance then -- when we are in a battleground or arena, we don't want to warn of pvp targets
            isPvp = UnitIsPVP("target")
            debugString = debugString .. ", isPvp: " .. tostring(isPvp)
        end
        if UnitCanAttack("target", "player") then
            debugString = debugString .. ", canAttack: true"
            local lvlDiff = self:CurrentTargetLvlDiff()
            isHighLvl = lvlDiff >= self.config.leveldiffWarnThreshold
            debugString = debugString .. ", isHighLvl: " .. tostring(isHighLvl)
            if not inInstance then
                local classification = UnitClassification("target") -- "elite","rareelite","worldboss",...
                if classification == "elite" or classification == "rareelite" or classification == "worldboss" then
                    isElite = lvlDiff >= self.config.leveldiffWarnEliteThreshold
                    debugString = debugString .. ", isElite: " .. tostring(isElite)
                end
            end
        end
    end
    self:Print(debugString)
    if isElite then
        self.state:Add(self.STATE.TARGET_WARN_ELITE)
    else
        self.state:Remove(self.STATE.TARGET_WARN_ELITE)
    end
    if not isElite and isHighLvl then
        self.state:Add(self.STATE.TARGET_WARN_HIGHLVL)
    else
        self.state:Remove(self.STATE.TARGET_WARN_HIGHLVL)
    end
    if not isElite and not isHighLvl and isPvp then
        self.state:Add(self.STATE.TARGET_WARN_ENEMYPVPTARGET)
    else
        self.state:Remove(self.STATE.TARGET_WARN_ENEMYPVPTARGET)
    end
end

-- Event used to track whenever something in the quest log changes. Used to warn about quests.
function HardcoreAlarms:QUEST_LOG_UPDATE()
    self:Print("QUEST_LOG_UPDATE")
    for questIndex = 1, GetNumQuestLogEntries() do
        local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily =
            GetQuestLogTitle(questIndex);

        if not isHeader and questTitle then  -- Ensure it's not a quest header
            --self:Print("Quest in log: " .. questTitle)
            for i, questId in ipairs(self.QUESTIDS) do
                local priority = self.STATE.QUEST_WARN + i - 1
                if questTitle == HardcoreAlarmsPfDBHelper:GetQuestTitle(questId) and
                    self.config.blacklistedQuestIds[questId] == nil then
                    self.state:Add(priority, questId)
                end
            end
        end
    end
end

function HardcoreAlarms:LOOT_OPENED()
    self.isLooting = true
    self:Print("LOOT_OPENED arg1: "..tostring(arg1)..", arg2: "..tostring(arg2)..", arg3: "..tostring(arg3))
end

function HardcoreAlarms:LOOT_CLOSED()
    self.isLooting = false
    self:Print("LOOT_CLOSED arg1: "..tostring(arg1)..", arg2: "..tostring(arg2)..", arg3: "..tostring(arg3))
end

--------------------------------------------------------------------
-- STOP - EVENT LISTENERS
--------------------------------------------------------------------

function HardcoreAlarms:StartUnitscanTimer()
    self:Print("StartUnitscanTimer")
    if self.checkUnitscanTimer then
        self:CancelTimer(self.checkUnitscanTimer)
    end
    self.checkUnitscanTimer = self:ScheduleRepeatingTimer("CheckUnitscan", self.UNITSCAN_INTERVAL)
end

-- Starts the main 'HardcoreAlarms:Check()'-loop. Runs every <'checkLoopInterval'> seconds.
function HardcoreAlarms:StartCheckLoopTimer()
    self:Print("StartCheckLoopTimer")
    self.checkTimer = self:ScheduleRepeatingTimer("Check", self.config.checkLoopInterval)
end

-- This is the main check method that runs all logic that has to be checked periodically. Everything that's not
-- event-based. Also includes stuff that hasn't been working well enough, because events didn't fire reliably. Stuff in
-- this function costs way more compute than event-based calculations. When event-based logic is possible, you should
-- always prefer that instead.
function HardcoreAlarms:Check()
    self:CheckBreath()
    self:CheckPvpState()
    self:CheckTestWarning()
end

-- Helper: whether dismissal suppression is active for name
function HardcoreAlarms:IsDismissSuppressed(name)
    local t = self.dismissedUnitscanNames[name]
    if not t then return false end
    return (GetTime() - t) < self.UNITSCAN_DISMISSTIME
end

function HardcoreAlarms:CurrentTargetLvlDiff()
    local targetLvl = UnitLevel("target")
    if targetLvl == -1 then -- targetLvl is -1 for ?? targets
        targetLvl = 61
    end
    local playerLvl = UnitLevel("player")
    return targetLvl - playerLvl
end

local suppressErrors = false

local origAddMessage = UIErrorsFrame.AddMessage
UIErrorsFrame.AddMessage = function(self, msg, r, g, b, id, holdTime)
    if suppressErrors then return end
    return origAddMessage(self, msg, r, g, b, id, holdTime)
end

local _PlaySound = PlaySound
PlaySound = function(sound)
    if suppressErrors then return end
    -- modify args[1] = "new" etc.
    return _PlaySound(sound)
end

function HardcoreAlarms:CheckUnitscan()
    --self:Print("CheckUnitscan")
    if self.isLooting or self.isInspecting then return end
    local inInstance, _instanceType = IsInInstance()
    if inInstance then return end
    if not self.config.unitscanInCombatEnabled and UnitAffectingCombat("player") then return end

    self.programmaticTargets = {}
    local zone = GetZoneText() or ""
    local zoneId = HardcoreAlarmsPfDBHelper:GetZoneId(zone)
    --self:Print("CheckUnitscan - zone: " .. zone .. ", id: " .. zoneId)
    local tbl = HardcoreAlarmsUnitscanTargets[zoneId] or {}
    local allFoundTargets = {}
    local hasShownWarning = false
    for _, unitId in pairs(tbl) do
        local name = HardcoreAlarmsPfDBHelper:GetUnitName(unitId)
        if name then
            --self:Print("CheckUnitscan - name: " .. name .. ", id: " .. unitId)
            local prevTarget = UnitName("target")
            if name ~= prevTarget then -- don't need to target when we already are
                local targetKey = name or "__NONE__"
                self.programmaticTargets[targetKey] = (self.programmaticTargets[targetKey] or 0) + 1
                --self:Print("CheckUnitscan, targetKey: " .. tostring(name) .. ", value: " .. tostring(self.programmaticTargets[name]))
                suppressErrors = true
                TargetByName(name, true)
                suppressErrors = false
            end
            local foundTarget = UnitName("target")
            if foundTarget == name and UnitIsEnemy("target", "player") then
                local showWarning = false
                if not self.unitscanSeenLast[name] then
                    -- If there's a dismissal timestamp older than suppress window, clear it so warning/frame can show
                    if not self:IsDismissSuppressed(name) and self.dismissedUnitscanNames[name] then
                        self.dismissedUnitscanNames[name] = nil
                        self:Print("CheckUnitscan dismissedUnitscanNames reset for: " .. name)
                    else
                        --self:Print("CheckUnitscan dismissedUnitscanNames NOT reset for: " .. name)
                    end
                    -- Only show warning if we haven't warned for this continuous presence yet
                    if not self.unitscanWarned[name] and not self.dismissedUnitscanNames[name] then
                        showWarning = true
                        --self:Print("CheckUnitscan warning, since we haven't warned before")
                    end
                else
                    -- was present last check: do nothing (only warn once per continuous presence)
                    -- However, if dismissed and suppression expired while still present, we should show again only if warn wasn't set (edge case)
                    if not self.unitscanWarned[name] and not self:IsDismissSuppressed(name) then
                        showWarning = true
                        self:Print("CheckUnitscan warning, since dismissed and suppression expired while still present")
                    end
                end
                if showWarning and
                        not hasShownWarning and
                        not UnitIsDead("target") and
                        not self.config.blacklistedUnitscanNames[name] and
                        not self.config.testWarnLevel[self.WARNLEVEL.TEXT] then
                    if self:CurrentTargetLvlDiff() >= self.config.leveldiffWarnUnitscanThreshold then
                        --self:Print("|cffff0000" .. L["UNITSCAN_CHAT_MESSAGE"] .. "|r " .. tostring(foundTarget), true)
                        self:ShowUnitscanFrame(name, "target")
                        self.unitscanWarned[name] = true
                        hasShownWarning = true
                    else
                        self:Print("CheckUnitscan Not showing unitscan target. Level too low!")
                    end
                end
                allFoundTargets[foundTarget] = true
            end
            if foundTarget ~= prevTarget then
                local targetKey = prevTarget or "__NONE__"
                self.programmaticTargets[targetKey] = (self.programmaticTargets[targetKey] or 0) + 1
                --self:Print("CheckUnitscan TargetLastTarget, targetKey: " .. tostring(targetKey) .. ", value: " .. tostring(self.programmaticTargets[targetKey]))
                suppressErrors = true
                TargetLastTarget()
                suppressErrors = false
                if prevTarget then
                    AssistUnit("player")
                end
            end
        else
            self:Print("|cffff0000ERROR! CheckUnitscan() name is nil! unitId: |r" .. tostring(unitId))
        end
    end
    -- Clear or keep entries based on current findings.
    -- 1) For names we marked as seen last check: if still found, keep seen; otherwise clear both seen and warned.
    for name, _ in pairs(self.unitscanSeenLast) do
        if allFoundTargets[name] then
            -- still present: keep marker
            self.unitscanSeenLast[name] = true
        else
            -- gone: reset both so future appearances will warn again
            self.unitscanSeenLast[name] = nil
            self.unitscanWarned[name] = nil
        end
    end
    -- 2) For names that were warned previously but not present in seen-last (or new warned entries): if not currently found, clear warned.
    for name, _ in pairs(self.unitscanWarned) do
        if not allFoundTargets[name] then
            self.unitscanWarned[name] = nil
        end
    end
    if self:TableLength(allFoundTargets) == 0 and not self.config.testWarnLevel[self.WARNLEVEL.TEXT] then
        self:HideUnitscanFrame() -- haven't found any targets, so we hide the frame
    end
end

function HardcoreAlarms:TableLength(tbl)
    local count = 0
    for k, v in pairs(tbl) do
        count = count + 1
    end
    return count
end

function HardcoreAlarms:CheckTestWarning()
    if self.config.testWarnLevel[self.WARNLEVEL.TEXT] then
        self.state:Add(self.STATE.TEST_WARN)
    else
        self.state:Remove(self.STATE.TEST_WARN)
    end
end

function HardcoreAlarms:CheckBreath()
    --self:Print("CheckBreath")
    if self.breathChange < 0 then
        self.breathTime = self.breathTime + self.config.checkLoopInterval * self.breathChange -- Decrement breath time
        --self:Print("breathTime: " .. self.breathTime)
        if self.breathTime <= self.config.breathWarnThreshold then
            if self.breathTime >= self.config.breathPanicThreshold then
                self.state:Add(self.STATE.BREATH_WARN)
            else
                self.state:Add(self.STATE.BREATH_PANIC)
            end
        end
    else
        self.state:Remove(self.STATE.BREATH_PANIC)
        self.state:Remove(self.STATE.BREATH_WARN)
    end
end

-- Manual check function, because event doesn't reliably trigger when leaving pvp state.
function HardcoreAlarms:CheckPvpState()
    if self.pvpToggled then
        self.pvpToggled = UnitIsPVP("player") ~= nil
    end
    if self.pvpToggled then
        self.state:Add(self.STATE.PLAYER_PVP_WARN)
    else
        self.state:Remove(self.STATE.PLAYER_PVP_WARN)
    end
end

-- Handles all logic whenever a new state needs to be displayed to the user. Sets a new title and text in the warning
-- frame. Plays a warning sound. Shows the screen flashing animation.
function HardcoreAlarms:HandleStateChange()
    --self:Print("HandleStateChange()")
    local textWinner, textWinnerId, repeatingSoundWinner
    local playFlash = false
    local oneshots = {}
    if self.testEnabled and self.testState ~= self.lastTestState then
        self:Print("Showing test state: " .. tostring(self.testState))
        textWinner = self.testState
        self.lastTestState = self.testState
    else
        local active = self.state:GetAllActiveStates()
        -- find winners
        local allActiveDebugString = ""
        for _, state in ipairs(active) do
            allActiveDebugString = allActiveDebugString .. tostring(state.state) .. " | "
            local st = state.state
            local id = state.id
            local warnLevel = self.STATE_WARNINGS[st].GetWarnConfig()
            if not textWinner and warnLevel[self.WARNLEVEL.TEXT] then textWinner = st; textWinnerId = id end
            if not repeatingSoundWinner and warnLevel[self.WARNLEVEL.SOUND_REPEATING] then repeatingSoundWinner = st end
            if warnLevel[self.WARNLEVEL.FLASHING_SCREEN] and not self.showedFlashFor[st] then
                playFlash = true
                self.showedFlashFor[st] = true
            end
            if warnLevel[self.WARNLEVEL.SOUND_ONCE] and not self.playedOneshotFor[st] then
                table.insert(oneshots, st)
                self.playedOneshotFor[st] = true
            end
        end
        self:Print("HandleStateChange() all active states: " .. allActiveDebugString)
    end
    -- cleanup playedOneshotFor for states no longer active
    for st, _ in pairs(self.playedOneshotFor) do if not self.state:Contains(st) then self.playedOneshotFor[st] = nil end end
    -- cleanup showedFlashFor for states no longer active
    for st, _ in pairs(self.showedFlashFor) do if not self.state:Contains(st) then self.showedFlashFor[st] = nil end end

    if textWinner ~= self.currentTextWinner then
        if not textWinner then
            self.warningFrame:Hide()
            self:StopUpdateWarningTextTimer()
        else
            if textWinner == self.STATE.BREATH_WARN or textWinner == self.STATE.BREATH_PANIC then
                self:StartUpdateWarningTextTimer()
            else
                self:StopUpdateWarningTextTimer()
            end
            local warningInfo = self.STATE_WARNINGS[textWinner]
            self.warningText:SetFont("Fonts\\FRIZQT__.TTF", warningInfo.fontSize, "OUTLINE")
            self.warningTitle:SetText(type(warningInfo.title) == "function" and warningInfo.title() or warningInfo.title)
            self.warningText:SetText(type(warningInfo.text) == "function" and warningInfo.text() or warningInfo.text)
            local contentWidth = math.min(self.warningText:GetStringWidth(), self.WARNINGFRAME_MAXWIDTH)
            contentWidth = math.max(self.warningTitle:GetStringWidth(), contentWidth)
            self.warningText:SetWidth(contentWidth)
            self.warningFrame:SetWidth(contentWidth + self.WARNINGFRAME_MARGIN)
            self.warningFrame:SetHeight(self.warningText:GetHeight() + self.warningTitle:GetHeight() +
                self.WARNINGFRAME_MARGIN)
            self.warningText:SetPoint("TOP", self.warningFrame, 0, -self.WARNINGFRAME_MARGIN)
            self.warningFrame:Show()
            if textWinner >= self.STATE.QUEST_WARN and textWinner < self.STATE.QUEST_WARN + 1000 or
                    textWinner >= self.STATE.TARGET_WARN and textWinner < self.STATE.TARGET_WARN + 1000 then -- when warning of dangerous quest/npc
                contentWidth = math.max(self.warningTitle:GetStringWidth() + 32, contentWidth)
                self.warningText:SetWidth(contentWidth)
                self.warningFrame:SetWidth(contentWidth + self.WARNINGFRAME_MARGIN)
                self.closeButton:Show()
                self:Print("|cffffd700" .. self.warningTitle:GetText() .. "|r", true)
                self:Print("|cffff0000" .. self.warningText:GetText() .. "|r", true)
            else
                self.closeButton:Hide()
            end
        end
        self.currentTextWinner = textWinner
        self.currentTextWinnerId = textWinnerId
    end

    -- Repeating sound handling
    if repeatingSoundWinner ~= self.lastRepeatingSoundState then
        self:StopWarnSoundTimer()
        self:StopPanicSoundTimer()
        if repeatingSoundWinner then
            local info = self.STATE_WARNINGS[repeatingSoundWinner]
            if info and info.isPanic then self:StartPanicSoundTimer() else self:StartWarnSoundTimer() end
        end
        self.lastRepeatingSoundState = repeatingSoundWinner
    end

    -- Flashing screen
    if playFlash then
        self:PlayFlashAnimation()
    else
        self:StopFlashAnimation()
    end

    -- One-shot sounds: play all newly activated once-sounds
    for _, st in ipairs(oneshots) do
        local info = self.STATE_WARNINGS[st]
        if info and info.isPanic then self:PanicSound() else self:WarnSound() end
    end
end

function HardcoreAlarms:ShowUnitscanFrame(name, unit)
    self:Print("ShowUnitscanFrame")
    if not name then return end

    self.currentUnitscanResult = name
    if self.config.unitscanWarnLevel[self.WARNLEVEL.TEXT] then
        self.unitscanText:SetText("|cffffd700" .. L["UNITSCAN_WARNTITLE"] .. "|r\n|cffff0000" .. name .. "|r")
        local contentWidth = math.max(self.unitscanText:GetStringWidth() + 32 + 36, self.UNITSCANFRAME_MAXWIDTH)
        self.unitscanText:SetWidth(contentWidth)
        self.unitscanFrame:SetWidth(contentWidth + self.WARNINGFRAME_MARGIN)
        SetPortraitTexture(self.unitscanPortrait, unit)
        self.unitscanFrame:Show()
    end
    if self.config.unitscanWarnLevel[self.WARNLEVEL.FLASHING_SCREEN] then
        self:PlayFlashAnimation()
    end
    if self.config.unitscanWarnLevel[self.WARNLEVEL.SOUND_ONCE] then
        self:WarnSound()
    end
end

function HardcoreAlarms:HideUnitscanFrame()
    --self:Print("HideUnitscanFrame")
    self.unitscanFrame:Hide()
end

-- Starts a repeating timer for HardcoreAlarms:UpdateWarningText()
function HardcoreAlarms:StartUpdateWarningTextTimer()
    self:Print("StartUpdateWarningTextTimer")
    self:StopUpdateWarningTextTimer()
    if self.updateWarningTextTimer == nil then
        self.updateWarningTextTimer = self:ScheduleRepeatingTimer("UpdateWarningText", 1)
    end
end

-- This repeating update function is necessary to show the current amount (in seconds) of breath left to the player.
-- Normally we only need to update the warning text straight after the state changes. The breath warning is the
-- exception here, being the only warning we want to update continuously.
function HardcoreAlarms:UpdateWarningText()
    local warningInfo = self.STATE_WARNINGS[self.currentTextWinner]
    self.warningText:SetText(type(warningInfo.text) == "function" and warningInfo.text() or warningInfo.text)
end

-- Stops a repeating timer for HardcoreAlarms:UpdateWarningText()
function HardcoreAlarms:StopUpdateWarningTextTimer()
    --self:Print("StopUpdateWarningTextTimer")
    if self.updateWarningTextTimer ~= nil then
        self:CancelTimer(self.updateWarningTextTimer)
        self.updateWarningTextTimer = nil
        self:Print("self:CancelTimer(self.updateWarningTextTimer)")
    end
end

-- Starts a repeating timer for HardcoreAlarms:WarnSound()
function HardcoreAlarms:StartWarnSoundTimer()
    self:Print("StartWarnSoundTimer")
    self:StopPanicSoundTimer()
    if self.warnSoundTimer == nil then
        self.warnSoundTimer = self:ScheduleRepeatingTimer("WarnSound", self.config.playSoundIntervalWarn)
        self:WarnSound()
    end
end

-- Plays a simple warning sound
function HardcoreAlarms:WarnSound()
    self:Print("WarnSound")
    PlaySound(self.config.soundFileWarn)
end

-- Stops a repeating timer for HardcoreAlarms:WarnSound()
function HardcoreAlarms:StopWarnSoundTimer()
    --self:Print("StopWarnSoundTimer")
    if self.warnSoundTimer ~= nil then
        self:CancelTimer(self.warnSoundTimer)
        self.warnSoundTimer = nil
        self:Print("self:CancelTimer(self.warnSoundTimer)")
    end
end

-- Starts a repeating timer for HardcoreAlarms:PanicSound()
function HardcoreAlarms:StartPanicSoundTimer()
    self:Print("StartPanicSoundTimer")
    self:StopWarnSoundTimer()
    if self.panicSoundTimer == nil then
        self.panicSoundTimer = self:ScheduleRepeatingTimer("PanicSound", self.config.playSoundIntervalPanic)
        self:PanicSound()
    end
end

-- Plays a simple panic sound
function HardcoreAlarms:PanicSound()
    self:Print("PanicSound")
    PlaySoundFile(self.config.soundFilePanic)
end

-- Stops a repeating timer for HardcoreAlarms:PanicSound()
function HardcoreAlarms:StopPanicSoundTimer()
    --self:Print("StopPanicSoundTimer")
    if self.panicSoundTimer ~= nil then
        self:CancelTimer(self.panicSoundTimer)
        self.panicSoundTimer = nil
        self:Print("self:CancelTimer(self.panicSoundTimer)")
    end
end
