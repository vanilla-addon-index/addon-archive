-- ChatMonitor: Keyword Alert System for Turtle WoW (1.12 client)
-- Monitors selected chat channels for keywords and provides visual/audio alerts

-- Saved variables (persisted between sessions)
ChatMonitorDB = ChatMonitorDB or {}

-- Local state
local ChatMonitor = {}
local isMonitoring = false
local keywords = {}
local monitoredChannels = {}
local matchHistory = {}
local MAX_HISTORY = 50

-- GUI frames (will be created later)
local MainFrame, KeywordScrollFrame, HistoryScrollFrame
local keywordButtons = {}
local historyButtons = {}
local channelCheckboxes = {}

-- Forward declarations for GUI functions
local UpdateHistoryList
local CreateMinimapButton
local UpdateMinimapButtonColor

-- Channel name mappings for display
local CHANNEL_NAMES = {
    ["SAY"] = "Say",
    ["YELL"] = "Yell",
    ["PARTY"] = "Party",
    ["RAID"] = "Raid",
    ["GUILD"] = "Guild",
    ["OFFICER"] = "Officer",
    ["WHISPER"] = "Whisper",
    ["CHANNEL"] = "Custom Channels",
    ["WORLD"] = "World",
    ["LFG"] = "LookingForGroup",
}

-- Initialize defaults
local function InitDefaults()
    if not ChatMonitorDB.keywords then
        ChatMonitorDB.keywords = {}
    end
    if not ChatMonitorDB.channels then
        -- Default to monitoring common LFG channels
        ChatMonitorDB.channels = {
            ["CHANNEL"] = true,  -- Custom channels (includes LFG, World, etc.)
            ["YELL"] = false,
            ["SAY"] = false,
        }
    end
    if not ChatMonitorDB.alertSound then
        ChatMonitorDB.alertSound = true
    end
    if not ChatMonitorDB.alertFlash then
        ChatMonitorDB.alertFlash = true
    end
    if not ChatMonitorDB.caseSensitive then
        ChatMonitorDB.caseSensitive = false
    end
    
    keywords = ChatMonitorDB.keywords
    monitoredChannels = ChatMonitorDB.channels
end

-- Sound alert
local function PlayAlertSound()
    if ChatMonitorDB.alertSound then
        PlaySound("LEVELUPSOUND")
    end
end

-- Flash frame variables (created on first use)
local FlashFrame = nil
local FlashTexture = nil
local flashStartTime = 0
local flashDuration = 0.5  -- seconds
local isFlashing = false

-- Create the flash frame on demand
local function EnsureFlashFrame()
    if FlashFrame then return end
    
    -- Create fullscreen frame
    FlashFrame = CreateFrame("Frame", "ChatMonitorFlashFrame", UIParent)
    FlashFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    FlashFrame:SetFrameLevel(100)
    FlashFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    FlashFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    FlashFrame:EnableMouse(false)
    
    -- Create solid green texture
    FlashTexture = FlashFrame:CreateTexture(nil, "BACKGROUND")
    FlashTexture:SetPoint("TOPLEFT", FlashFrame, "TOPLEFT", 0, 0)
    FlashTexture:SetPoint("BOTTOMRIGHT", FlashFrame, "BOTTOMRIGHT", 0, 0)
    -- Use solid color texture
    FlashTexture:SetTexture(0, 1, 0)  -- Solid green
    FlashTexture:SetAlpha(0)
    
    -- Animation via OnUpdate
    FlashFrame:SetScript("OnUpdate", function()
        if not isFlashing then return end
        
        local elapsed = GetTime() - flashStartTime
        if elapsed >= flashDuration then
            isFlashing = false
            FlashTexture:SetAlpha(0)
            FlashFrame:Hide()
        else
            -- Fade from 0.4 to 0 over the duration
            local progress = elapsed / flashDuration
            local alpha = 0.4 * (1 - progress)
            FlashTexture:SetAlpha(alpha)
        end
    end)
    
    FlashFrame:Hide()
end

-- Visual flash alert
local function FlashScreen()
    if ChatMonitorDB.alertFlash then
        -- Show text message
        UIErrorsFrame:AddMessage("|cffFF0000*** KEYWORD MATCH! ***|r", 1.0, 0.0, 0.0, 53, 5)
        
        -- Create frame if needed
        EnsureFlashFrame()
        
        -- Trigger flash
        flashStartTime = GetTime()
        isFlashing = true
        FlashTexture:SetAlpha(0.4)
        FlashFrame:Show()
    end
end

-- Format timestamp
local function GetTimestamp()
    local hour, minute = GetGameTime()
    return string.format("%02d:%02d", hour, minute)
end

-- Check if message contains any keywords
local function CheckForKeywords(message)
    local searchMsg = message
    if not ChatMonitorDB.caseSensitive then
        searchMsg = string.lower(message)
    end
    
    for _, keyword in ipairs(keywords) do
        local searchKeyword = keyword
        if not ChatMonitorDB.caseSensitive then
            searchKeyword = string.lower(keyword)
        end
        
        if string.find(searchMsg, searchKeyword, 1, true) then
            return true, keyword
        end
    end
    return false, nil
end

-- Get channel type from event
local function GetChannelType(event)
    if event == "CHAT_MSG_SAY" then
        return "SAY"
    elseif event == "CHAT_MSG_YELL" then
        return "YELL"
    elseif event == "CHAT_MSG_PARTY" then
        return "PARTY"
    elseif event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_RAID_WARNING" then
        return "RAID"
    elseif event == "CHAT_MSG_GUILD" then
        return "GUILD"
    elseif event == "CHAT_MSG_OFFICER" then
        return "OFFICER"
    elseif event == "CHAT_MSG_WHISPER" then
        return "WHISPER"
    elseif event == "CHAT_MSG_CHANNEL" then
        return "CHANNEL"
    end
    return nil
end

-- Log a match to history
local function LogMatch(keyword, sender, message, channel)
    local entry = {
        time = GetTimestamp(),
        keyword = keyword,
        sender = sender,
        message = message,
        channel = channel,
    }
    
    table.insert(matchHistory, 1, entry)
    
    -- Trim history
    while table.getn(matchHistory) > MAX_HISTORY do
        table.remove(matchHistory)
    end
end

-- Main chat event handler
local function OnChatMessage(event, message, sender, language, channelString, target, flags, unknown, channelNumber, channelName)
    if not isMonitoring then return end
    if not message or message == "" then return end
    
    -- Ignore messages from self
    local playerName = UnitName("player")
    if sender and playerName and sender == playerName then return end
    
    local channelType = GetChannelType(event)
    if not channelType then return end
    
    -- Check if this channel type is monitored
    if not monitoredChannels[channelType] then return end
    
    -- Check for keywords
    local found, matchedKeyword = CheckForKeywords(message)
    if found then
        -- Get display channel name
        local displayChannel = channelName or CHANNEL_NAMES[channelType] or channelType
        
        -- Alert!
        PlayAlertSound()
        FlashScreen()
        
        -- Print to chat
        local alertMsg = string.format(
            "|cff00FF00[ChatMonitor]|r Match: |cffFFFF00%s|r in |cff00FFFF[%s]|r from |cffFF8000%s|r: %s",
            matchedKeyword,
            displayChannel,
            sender,
            message
        )
        DEFAULT_CHAT_FRAME:AddMessage(alertMsg)
        
        -- Log it
        LogMatch(matchedKeyword, sender, message, displayChannel)
        
        -- Update GUI if open
        UpdateHistoryList()
    end
end

-- Create the main frame
local frame = CreateFrame("Frame", "ChatMonitorFrame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("CHAT_MSG_SAY")
frame:RegisterEvent("CHAT_MSG_YELL")
frame:RegisterEvent("CHAT_MSG_PARTY")
frame:RegisterEvent("CHAT_MSG_RAID")
frame:RegisterEvent("CHAT_MSG_RAID_LEADER")
frame:RegisterEvent("CHAT_MSG_RAID_WARNING")
frame:RegisterEvent("CHAT_MSG_GUILD")
frame:RegisterEvent("CHAT_MSG_OFFICER")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("CHAT_MSG_CHANNEL")

frame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        InitDefaults()
        CreateMinimapButton()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Loaded! Click the minimap button or type |cffFFFF00/cm show|r to open.")
    else
        OnChatMessage(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    end
end)

-- Slash commands
SLASH_CHATMONITOR1 = "/chatmonitor"
SLASH_CHATMONITOR2 = "/cm"

local function PrintHelp()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor] Commands:|r")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm show|r - Open the GUI")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm start|r - Start monitoring")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm stop|r - Stop monitoring")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm add <keyword>|r - Add a keyword to watch for")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm remove <keyword>|r - Remove a keyword")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm list|r - List all keywords")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm clear|r - Clear all keywords")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm channel <type> on/off|r - Toggle channel monitoring")
    DEFAULT_CHAT_FRAME:AddMessage("    Channel types: say, yell, party, raid, guild, officer, whisper, channel")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm channels|r - Show monitored channels")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm sound on/off|r - Toggle sound alerts")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm flash on/off|r - Toggle screen flash alerts")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm case on/off|r - Toggle case sensitivity")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm history|r - Show recent matches")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFF00/cm status|r - Show current status")
end

local function PrintStatus()
    local statusColor = isMonitoring and "|cff00FF00ACTIVE|r" or "|cffFF0000STOPPED|r"
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor] Status:|r " .. statusColor)
    DEFAULT_CHAT_FRAME:AddMessage("  Keywords: " .. table.getn(keywords))
    DEFAULT_CHAT_FRAME:AddMessage("  Sound: " .. (ChatMonitorDB.alertSound and "ON" or "OFF"))
    DEFAULT_CHAT_FRAME:AddMessage("  Flash: " .. (ChatMonitorDB.alertFlash and "ON" or "OFF"))
    DEFAULT_CHAT_FRAME:AddMessage("  Case Sensitive: " .. (ChatMonitorDB.caseSensitive and "ON" or "OFF"))
end

local function ListKeywords()
    if table.getn(keywords) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r No keywords set. Use |cffFFFF00/cm add <keyword>|r")
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor] Keywords:|r")
    for i, kw in ipairs(keywords) do
        DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ". |cffFFFF00" .. kw .. "|r")
    end
end

local function ListChannels()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor] Monitored Channels:|r")
    for channelType, name in pairs(CHANNEL_NAMES) do
        local status = monitoredChannels[channelType] and "|cff00FF00ON|r" or "|cffFF0000OFF|r"
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: %s", name, status))
    end
end

local function AddKeyword(keyword)
    if not keyword or keyword == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Usage: /cm add <keyword>")
        return
    end
    
    -- Check for duplicates
    local searchKw = string.lower(keyword)
    for _, existing in ipairs(keywords) do
        if string.lower(existing) == searchKw then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Keyword already exists: |cffFFFF00" .. keyword .. "|r")
            return
        end
    end
    
    table.insert(keywords, keyword)
    ChatMonitorDB.keywords = keywords
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Added keyword: |cffFFFF00" .. keyword .. "|r")
end

local function RemoveKeyword(keyword)
    if not keyword or keyword == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Usage: /cm remove <keyword>")
        return
    end
    
    local searchKw = string.lower(keyword)
    for i, existing in ipairs(keywords) do
        if string.lower(existing) == searchKw then
            table.remove(keywords, i)
            ChatMonitorDB.keywords = keywords
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Removed keyword: |cffFFFF00" .. existing .. "|r")
            return
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Keyword not found: |cffFFFF00" .. keyword .. "|r")
end

local function SetChannel(channelType, enabled)
    channelType = string.upper(channelType)
    
    -- Handle common aliases
    if channelType == "CHANNELS" or channelType == "CUSTOM" or channelType == "LFG" or channelType == "WORLD" then
        channelType = "CHANNEL"
    end
    
    if not CHANNEL_NAMES[channelType] then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Unknown channel type. Valid: say, yell, party, raid, guild, officer, whisper, channel")
        return
    end
    
    monitoredChannels[channelType] = enabled
    ChatMonitorDB.channels = monitoredChannels
    
    local status = enabled and "|cff00FF00enabled|r" or "|cffFF0000disabled|r"
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r " .. CHANNEL_NAMES[channelType] .. " monitoring " .. status)
end

local function ShowHistory()
    if table.getn(matchHistory) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r No matches recorded yet.")
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor] Recent Matches:|r")
    local count = math.min(10, table.getn(matchHistory))
    for i = 1, count do
        local entry = matchHistory[i]
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  [%s] |cffFFFF00%s|r in [%s] from %s",
            entry.time, entry.keyword, entry.channel, entry.sender
        ))
    end
end

-- ============================================
-- GUI CREATION
-- ============================================

local function CreateTooltip(frame, title, text)
    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if text then
            GameTooltip:AddLine(text, nil, nil, nil, 1)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function UpdateStatusDisplay()
    if not MainFrame then return end
    
    local statusText = MainFrame.statusText
    if isMonitoring then
        statusText:SetText("|cff00FF00MONITORING|r")
    else
        statusText:SetText("|cffFF0000STOPPED|r")
    end
    
    -- Update toggle button
    if MainFrame.toggleButton then
        if isMonitoring then
            MainFrame.toggleButton:SetText("Stop")
            MainFrame.toggleButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
        else
            MainFrame.toggleButton:SetText("Start")
            MainFrame.toggleButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
        end
    end
end

local function UpdateKeywordList()
    if not KeywordScrollFrame then return end
    
    -- Clear existing buttons
    for _, btn in ipairs(keywordButtons) do
        btn:Hide()
    end
    
    local scrollChild = KeywordScrollFrame.scrollChild
    local yOffset = 0
    
    for i, keyword in ipairs(keywords) do
        local btn = keywordButtons[i]
        if not btn then
            -- Create new button
            btn = CreateFrame("Button", "ChatMonitorKeyword"..i, scrollChild)
            btn:SetHeight(20)
            btn:SetWidth(148)
            
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.text:SetPoint("LEFT", 5, 0)
            btn.text:SetJustifyH("LEFT")
            btn.text:SetWidth(118)
            
            btn.deleteBtn = CreateFrame("Button", nil, btn, "UIPanelCloseButton")
            btn.deleteBtn:SetWidth(20)
            btn.deleteBtn:SetHeight(20)
            btn.deleteBtn:SetPoint("RIGHT", 12, 0)
            btn.deleteBtn:SetScript("OnClick", function()
                local idx = this:GetParent().keywordIndex
                if idx and keywords[idx] then
                    table.remove(keywords, idx)
                    ChatMonitorDB.keywords = keywords
                    UpdateKeywordList()
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Keyword removed.")
                end
            end)
            
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            
            keywordButtons[i] = btn
        end
        
        btn.keywordIndex = i
        btn.text:SetText(keyword)
        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        btn:Show()
        
        yOffset = yOffset + 22
    end
    
    -- Update scroll child height and slider
    local contentHeight = math.max(yOffset, 1)
    scrollChild:SetHeight(contentHeight)
    
    if KeywordScrollFrame.slider then
        -- Use a slight delay to ensure frame is laid out
        local slider = KeywordScrollFrame.slider
        local frame = KeywordScrollFrame
        
        -- Get frame height, default to 140 if not available yet (approx panel height minus header)
        local frameHeight = frame:GetHeight()
        if not frameHeight or frameHeight <= 0 then
            frameHeight = 140
        end
        
        local maxScroll = contentHeight - frameHeight
        if maxScroll <= 0 then
            slider:Hide()
            slider:SetMinMaxValues(0, 1)
            slider:SetValue(0)
        else
            slider:SetMinMaxValues(0, maxScroll)
            slider:Show()
        end
    end
end

UpdateHistoryList = function()
    if not HistoryScrollFrame then return end
    
    -- Clear existing
    for _, btn in ipairs(historyButtons) do
        btn:Hide()
    end
    
    local scrollChild = HistoryScrollFrame.scrollChild
    local yOffset = 0
    
    for i, entry in ipairs(matchHistory) do
        if i > 20 then break end -- Limit displayed
        
        local btn = historyButtons[i]
        if not btn then
            btn = CreateFrame("Button", "ChatMonitorHistory"..i, scrollChild)
            btn:SetHeight(36)
            btn:SetWidth(188)
            
            btn.timeText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.timeText:SetPoint("TOPLEFT", 2, -2)
            btn.timeText:SetJustifyH("LEFT")
            btn.timeText:SetWidth(184)
            
            btn.msgText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.msgText:SetPoint("TOPLEFT", 2, -16)
            btn.msgText:SetJustifyH("LEFT")
            btn.msgText:SetWidth(184)
            
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            
            historyButtons[i] = btn
        end
        
        -- Line 1: time, keyword, channel
        btn.timeText:SetText(string.format("|cff888888[%s]|r |cffFFFF00%s|r |cff00FFFF[%s]|r", 
            entry.time, entry.keyword, entry.channel))
        
        -- Line 2: sender name and truncated message
        local truncMsg = entry.message
        if string.len(truncMsg) > 30 then
            truncMsg = string.sub(truncMsg, 1, 27) .. "..."
        end
        btn.msgText:SetText(string.format("|cffFF8000%s|r: %s", entry.sender, truncMsg))
        
        btn.fullEntry = entry
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(this.fullEntry.sender, 1, 0.5, 0)
            GameTooltip:AddLine(this.fullEntry.message, 1, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        btn:Show()
        
        yOffset = yOffset + 38
    end
    
    -- Update scroll child height and slider
    local contentHeight = math.max(yOffset, 1)
    scrollChild:SetHeight(contentHeight)
    
    if HistoryScrollFrame.slider then
        local slider = HistoryScrollFrame.slider
        local frame = HistoryScrollFrame
        
        -- Get frame height, default to 60 if not available yet
        local frameHeight = frame:GetHeight()
        if not frameHeight or frameHeight <= 0 then
            frameHeight = 60
        end
        
        local maxScroll = contentHeight - frameHeight
        if maxScroll <= 0 then
            slider:Hide()
            slider:SetMinMaxValues(0, 1)
            slider:SetValue(0)
        else
            slider:SetMinMaxValues(0, maxScroll)
            slider:Show()
        end
    end
end

local function UpdateChannelCheckboxes()
    for channelType, checkbox in pairs(channelCheckboxes) do
        checkbox:SetChecked(monitoredChannels[channelType])
    end
end

local function CreateMainFrame()
    if MainFrame then 
        MainFrame:Show()
        UpdateStatusDisplay()
        return 
    end
    
    -- Main frame
    MainFrame = CreateFrame("Frame", "ChatMonitorMainFrame", UIParent)
    MainFrame:SetWidth(500)
    MainFrame:SetHeight(415)
    MainFrame:SetPoint("CENTER", 0, 0)
    MainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    MainFrame:SetBackdropColor(0, 0, 0, 1)
    MainFrame:SetMovable(true)
    MainFrame:EnableMouse(true)
    MainFrame:RegisterForDrag("LeftButton")
    MainFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    MainFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    MainFrame:SetFrameStrata("DIALOG")
    
    -- Title
    local title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("|cff00FF00Chat Monitor|r")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    -- Status display
    local statusLabel = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusLabel:SetPoint("TOPLEFT", 25, -45)
    statusLabel:SetText("Status:")
    
    MainFrame.statusText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    MainFrame.statusText:SetPoint("LEFT", statusLabel, "RIGHT", 10, 0)
    
    -- Toggle button
    MainFrame.toggleButton = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    MainFrame.toggleButton:SetWidth(80)
    MainFrame.toggleButton:SetHeight(22)
    MainFrame.toggleButton:SetPoint("LEFT", MainFrame.statusText, "RIGHT", 20, 0)
    MainFrame.toggleButton:SetText("Start")
    MainFrame.toggleButton:SetScript("OnClick", function()
        if isMonitoring then
            isMonitoring = false
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Monitoring |cffFF0000STOPPED|r")
        else
            if table.getn(keywords) == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Add some keywords first!")
                return
            end
            isMonitoring = true
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Monitoring |cff00FF00STARTED|r")
        end
        UpdateStatusDisplay()
        UpdateMinimapButtonColor()
    end)
    
    -- Test button
    local testBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    testBtn:SetWidth(60)
    testBtn:SetHeight(22)
    testBtn:SetPoint("LEFT", MainFrame.toggleButton, "RIGHT", 10, 0)
    testBtn:SetText("Test")
    testBtn:SetScript("OnClick", function()
        PlayAlertSound()
        FlashScreen()
    end)
    CreateTooltip(testBtn, "Test Alert", "Play the alert sound and flash")
    
    -- ============================================
    -- LEFT PANEL: Keywords
    -- ============================================
    
    local keywordPanel = CreateFrame("Frame", nil, MainFrame)
    keywordPanel:SetPoint("TOPLEFT", 20, -75)
    keywordPanel:SetWidth(200)
    keywordPanel:SetHeight(200)
    keywordPanel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    keywordPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    
    local keywordTitle = keywordPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keywordTitle:SetPoint("TOPLEFT", 10, -8)
    keywordTitle:SetText("|cffFFFF00Keywords|r")
    
    -- Add keyword input
    local addBox = CreateFrame("EditBox", "ChatMonitorAddBox", keywordPanel, "InputBoxTemplate")
    addBox:SetWidth(120)
    addBox:SetHeight(20)
    addBox:SetPoint("TOPLEFT", 10, -25)
    addBox:SetAutoFocus(false)
    addBox:SetScript("OnEnterPressed", function()
        local text = this:GetText()
        if text and text ~= "" then
            AddKeyword(text)
            this:SetText("")
            UpdateKeywordList()
        end
    end)
    addBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    
    local addBtn = CreateFrame("Button", nil, keywordPanel, "UIPanelButtonTemplate")
    addBtn:SetWidth(50)
    addBtn:SetHeight(22)
    addBtn:SetPoint("LEFT", addBox, "RIGHT", 5, 0)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function()
        local text = addBox:GetText()
        if text and text ~= "" then
            AddKeyword(text)
            addBox:SetText("")
            UpdateKeywordList()
        end
    end)
    
    -- Keyword scroll frame - using simple ScrollFrame with slider
    local keywordScrollParent = CreateFrame("Frame", nil, keywordPanel)
    keywordScrollParent:SetPoint("TOPLEFT", 8, -50)
    keywordScrollParent:SetPoint("BOTTOMRIGHT", -8, 8)
    
    KeywordScrollFrame = CreateFrame("ScrollFrame", "ChatMonitorKeywordScroll", keywordScrollParent)
    KeywordScrollFrame:SetPoint("TOPLEFT", 0, 0)
    KeywordScrollFrame:SetPoint("BOTTOMRIGHT", -20, 0)
    
    KeywordScrollFrame.scrollChild = CreateFrame("Frame", nil, KeywordScrollFrame)
    KeywordScrollFrame.scrollChild:SetWidth(150)
    KeywordScrollFrame.scrollChild:SetHeight(1)
    KeywordScrollFrame:SetScrollChild(KeywordScrollFrame.scrollChild)
    
    -- Scrollbar slider
    local keywordSlider = CreateFrame("Slider", "ChatMonitorKeywordSlider", keywordScrollParent, "UIPanelScrollBarTemplate")
    keywordSlider:SetPoint("TOPRIGHT", 0, -16)
    keywordSlider:SetPoint("BOTTOMRIGHT", 0, 16)
    keywordSlider:SetMinMaxValues(0, 1)
    keywordSlider:SetValueStep(1)
    keywordSlider:SetWidth(16)
    keywordSlider:SetScript("OnValueChanged", function()
        if KeywordScrollFrame then
            KeywordScrollFrame:SetVerticalScroll(this:GetValue())
        end
    end)
    keywordSlider:SetValue(0)
    keywordSlider:Hide() -- Start hidden until needed
    KeywordScrollFrame.slider = keywordSlider
    
    -- Enable mouse wheel scrolling for keywords
    keywordScrollParent:EnableMouseWheel(true)
    keywordScrollParent:SetScript("OnMouseWheel", function()
        local current = keywordSlider:GetValue()
        local min, max = keywordSlider:GetMinMaxValues()
        local newVal = current - (arg1 * 22)
        if newVal < min then newVal = min end
        if newVal > max then newVal = max end
        keywordSlider:SetValue(newVal)
    end)
    
    -- ============================================
    -- RIGHT PANEL: Channels
    -- ============================================
    
    local channelPanel = CreateFrame("Frame", nil, MainFrame)
    channelPanel:SetPoint("TOPRIGHT", -20, -75)
    channelPanel:SetWidth(240)
    channelPanel:SetHeight(200)
    channelPanel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    channelPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    
    local channelTitle = channelPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelTitle:SetPoint("TOPLEFT", 10, -8)
    channelTitle:SetText("|cffFFFF00Monitored Channels|r")
    
    -- Channel checkboxes
    local channelList = {
        { type = "CHANNEL", name = "Custom Channels (LFG, World, etc.)", important = true },
        { type = "SAY", name = "Say" },
        { type = "YELL", name = "Yell" },
        { type = "PARTY", name = "Party" },
        { type = "RAID", name = "Raid" },
        { type = "GUILD", name = "Guild" },
        { type = "WHISPER", name = "Whisper" },
    }
    
    local yPos = -28
    for _, chan in ipairs(channelList) do
        local cb = CreateFrame("CheckButton", "ChatMonitorChan"..chan.type, channelPanel, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 8, yPos)
        cb:SetWidth(24)
        cb:SetHeight(24)
        cb:SetChecked(monitoredChannels[chan.type])
        cb.channelType = chan.type
        cb:SetScript("OnClick", function()
            monitoredChannels[this.channelType] = this:GetChecked()
            ChatMonitorDB.channels = monitoredChannels
        end)
        
        local label = channelPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        if chan.important then
            label:SetText("|cff00FF00" .. chan.name .. "|r")
        else
            label:SetText(chan.name)
        end
        
        channelCheckboxes[chan.type] = cb
        yPos = yPos - 22
    end
    
    -- ============================================
    -- BOTTOM PANEL: Settings
    -- ============================================
    
    local settingsPanel = CreateFrame("Frame", nil, MainFrame)
    settingsPanel:SetPoint("TOPLEFT", 20, -280)
    settingsPanel:SetWidth(200)
    settingsPanel:SetHeight(105)
    settingsPanel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    settingsPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    
    local settingsTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    settingsTitle:SetPoint("TOPLEFT", 10, -8)
    settingsTitle:SetText("|cffFFFF00Settings|r")
    
    -- Sound checkbox
    local soundCb = CreateFrame("CheckButton", "ChatMonitorSoundCb", settingsPanel, "UICheckButtonTemplate")
    soundCb:SetPoint("TOPLEFT", 8, -28)
    soundCb:SetWidth(24)
    soundCb:SetHeight(24)
    soundCb:SetChecked(ChatMonitorDB.alertSound)
    soundCb:SetScript("OnClick", function()
        ChatMonitorDB.alertSound = this:GetChecked()
    end)
    local soundLabel = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    soundLabel:SetPoint("LEFT", soundCb, "RIGHT", 2, 0)
    soundLabel:SetText("Sound Alert")
    
    -- Flash checkbox
    local flashCb = CreateFrame("CheckButton", "ChatMonitorFlashCb", settingsPanel, "UICheckButtonTemplate")
    flashCb:SetPoint("TOPLEFT", 8, -50)
    flashCb:SetWidth(24)
    flashCb:SetHeight(24)
    flashCb:SetChecked(ChatMonitorDB.alertFlash)
    flashCb:SetScript("OnClick", function()
        ChatMonitorDB.alertFlash = this:GetChecked()
    end)
    local flashLabel = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    flashLabel:SetPoint("LEFT", flashCb, "RIGHT", 2, 0)
    flashLabel:SetText("Screen Flash")
    
    -- Case sensitive checkbox
    local caseCb = CreateFrame("CheckButton", "ChatMonitorCaseCb", settingsPanel, "UICheckButtonTemplate")
    caseCb:SetPoint("TOPLEFT", 8, -72)
    caseCb:SetWidth(24)
    caseCb:SetHeight(24)
    caseCb:SetChecked(ChatMonitorDB.caseSensitive)
    caseCb:SetScript("OnClick", function()
        ChatMonitorDB.caseSensitive = this:GetChecked()
    end)
    local caseLabel = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    caseLabel:SetPoint("LEFT", caseCb, "RIGHT", 2, 0)
    caseLabel:SetText("Case Sensitive")
    
    -- ============================================
    -- BOTTOM RIGHT: History
    -- ============================================
    
    local historyPanel = CreateFrame("Frame", nil, MainFrame)
    historyPanel:SetPoint("TOPRIGHT", -20, -280)
    historyPanel:SetWidth(240)
    historyPanel:SetHeight(105)
    historyPanel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    historyPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    
    local historyTitle = historyPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    historyTitle:SetPoint("TOPLEFT", 10, -8)
    historyTitle:SetText("|cffFFFF00Recent Matches|r")
    
    -- History scroll - using simple ScrollFrame with slider
    local historyScrollParent = CreateFrame("Frame", nil, historyPanel)
    historyScrollParent:SetPoint("TOPLEFT", 8, -25)
    historyScrollParent:SetPoint("BOTTOMRIGHT", -8, 8)
    
    HistoryScrollFrame = CreateFrame("ScrollFrame", "ChatMonitorHistoryScroll", historyScrollParent)
    HistoryScrollFrame:SetPoint("TOPLEFT", 0, 0)
    HistoryScrollFrame:SetPoint("BOTTOMRIGHT", -20, 0)
    
    HistoryScrollFrame.scrollChild = CreateFrame("Frame", nil, HistoryScrollFrame)
    HistoryScrollFrame.scrollChild:SetWidth(190)
    HistoryScrollFrame.scrollChild:SetHeight(1)
    HistoryScrollFrame:SetScrollChild(HistoryScrollFrame.scrollChild)
    
    -- Scrollbar slider
    local historySlider = CreateFrame("Slider", "ChatMonitorHistorySlider", historyScrollParent, "UIPanelScrollBarTemplate")
    historySlider:SetPoint("TOPRIGHT", 0, -16)
    historySlider:SetPoint("BOTTOMRIGHT", 0, 16)
    historySlider:SetMinMaxValues(0, 1)
    historySlider:SetValueStep(1)
    historySlider:SetWidth(16)
    historySlider:SetScript("OnValueChanged", function()
        if HistoryScrollFrame then
            HistoryScrollFrame:SetVerticalScroll(this:GetValue())
        end
    end)
    historySlider:SetValue(0)
    historySlider:Hide() -- Start hidden until needed
    HistoryScrollFrame.slider = historySlider
    
    -- Enable mouse wheel scrolling for history
    historyScrollParent:EnableMouseWheel(true)
    historyScrollParent:SetScript("OnMouseWheel", function()
        local current = historySlider:GetValue()
        local min, max = historySlider:GetMinMaxValues()
        local newVal = current - (arg1 * 38)
        if newVal < min then newVal = min end
        if newVal > max then newVal = max end
        historySlider:SetValue(newVal)
    end)
    
    -- Initial updates
    UpdateStatusDisplay()
    UpdateKeywordList()
    UpdateChannelCheckboxes()
    UpdateHistoryList()
    
    -- Make it closeable with ESC
    tinsert(UISpecialFrames, "ChatMonitorMainFrame")
end

-- Minimap button (standard implementation compatible with pfUI's button drawer)
local minimapButton = nil

-- Update minimap button color based on monitoring status
UpdateMinimapButtonColor = function()
    if not minimapButton then return end
    
    if isMonitoring then
        -- Green when active
        minimapButton.cmText:SetTextColor(0, 1, 0)
        minimapButton.bgTexture:SetVertexColor(0.1, 0.3, 0.1)
    else
        -- Red when stopped
        minimapButton.cmText:SetTextColor(1, 0, 0)
        minimapButton.bgTexture:SetVertexColor(0.3, 0.1, 0.1)
    end
end

CreateMinimapButton = function()
    if minimapButton then return minimapButton end
    
    -- Create button with standard naming convention that pfUI recognizes
    local btn = CreateFrame("Button", "ChatMonitorMinimapButton", Minimap)
    btn:SetWidth(31)
    btn:SetHeight(31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:EnableMouse(true)
    btn:SetMovable(true)
    
    -- Create a dark circular background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetWidth(25)
    bg:SetHeight(25)
    bg:SetPoint("CENTER", 0, 0)
    bg:SetVertexColor(0.3, 0.1, 0.1) -- Start red (not monitoring)
    btn.bgTexture = bg
    
    -- Create the "CM" text
    local cmText = btn:CreateFontString(nil, "ARTWORK")
    cmText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    cmText:SetPoint("CENTER", 0, 0)
    cmText:SetText("CM")
    cmText:SetTextColor(1, 0, 0) -- Start red (not monitoring)
    btn.cmText = cmText
    
    -- Border overlay (standard minimap button look)
    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetWidth(54)
    overlay:SetHeight(54)
    overlay:SetPoint("TOPLEFT", -1, 1)
    
    -- Highlight texture
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetWidth(25)
    highlight:SetHeight(25)
    highlight:SetPoint("CENTER", 0, 0)
    highlight:SetBlendMode("ADD")
    
    -- Positioning math for circular minimap
    local function UpdatePosition()
        local angle = ChatMonitorDB.minimapPos or 220
        local radius = 80
        local rads = math.rad(angle)
        local x = math.cos(rads) * radius
        local y = math.sin(rads) * radius
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    
    -- Set initial position
    UpdatePosition()
    
    -- Dragging around minimap
    local isDragging = false
    btn:RegisterForDrag("LeftButton")
    
    btn:SetScript("OnDragStart", function()
        isDragging = true
    end)
    
    btn:SetScript("OnDragStop", function()
        isDragging = false
    end)
    
    btn:SetScript("OnUpdate", function()
        if isDragging then
            local xpos, ypos = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = Minimap:GetCenter()
            local x = xpos / scale - cx
            local y = ypos / scale - cy
            local angle = math.deg(math.atan2(y, x))
            ChatMonitorDB.minimapPos = angle
            UpdatePosition()
        end
    end)
    
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    btn:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            -- Left-click opens the GUI
            if MainFrame and MainFrame:IsShown() then
                MainFrame:Hide()
            else
                CreateMainFrame()
            end
        elseif arg1 == "RightButton" then
            -- Right-click toggles monitoring
            if isMonitoring then
                isMonitoring = false
                DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Monitoring |cffFF0000STOPPED|r")
            else
                if table.getn(keywords) == 0 then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r No keywords set! Use |cffFFFF00/cm add <keyword>|r or open the GUI to add keywords.")
                else
                    isMonitoring = true
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Monitoring |cff00FF00STARTED|r - watching for " .. table.getn(keywords) .. " keyword(s)")
                end
            end
            UpdateMinimapButtonColor()
            -- Update GUI if open
            if MainFrame and MainFrame:IsShown() then
                UpdateStatusDisplay()
            end
        end
    end)
    
    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("Chat Monitor")
        GameTooltip:AddLine("Left-click: Open settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Start/Stop monitoring", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move button", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ")
        local statusColor = isMonitoring and "|cff00FF00Active|r" or "|cffFF0000Stopped|r"
        GameTooltip:AddLine("Status: " .. statusColor, 1, 1, 1)
        GameTooltip:AddLine("Keywords: " .. table.getn(keywords), 1, 1, 1)
        GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    btn:Show()
    minimapButton = btn
    
    -- Set initial color
    UpdateMinimapButtonColor()
    
    return btn
end

-- ============================================
-- SLASH COMMANDS
-- ============================================

SlashCmdList["CHATMONITOR"] = function(msg)
    if not msg then msg = "" end
    
    -- Parse command and arguments
    local command, args = string.match(msg, "^(%S+)%s*(.*)$")
    if not command then
        command = msg
        args = ""
    end
    command = string.lower(command)
    
    if command == "" or command == "help" then
        PrintHelp()
    elseif command == "start" or command == "on" then
        if table.getn(keywords) == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r No keywords set! Use |cffFFFF00/cm add <keyword>|r first.")
            return
        end
        isMonitoring = true
        UpdateMinimapButtonColor()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Monitoring |cff00FF00STARTED|r - watching for " .. table.getn(keywords) .. " keyword(s)")
    elseif command == "stop" or command == "off" then
        isMonitoring = false
        UpdateMinimapButtonColor()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Monitoring |cffFF0000STOPPED|r")
    elseif command == "add" then
        AddKeyword(args)
    elseif command == "remove" or command == "delete" or command == "del" then
        RemoveKeyword(args)
    elseif command == "list" or command == "keywords" then
        ListKeywords()
    elseif command == "clear" then
        keywords = {}
        ChatMonitorDB.keywords = {}
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r All keywords cleared.")
    elseif command == "channel" or command == "chan" then
        local chanType, toggle = string.match(args, "^(%S+)%s*(.*)$")
        if not chanType then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Usage: /cm channel <type> on/off")
            return
        end
        toggle = string.lower(toggle or "")
        local enabled = (toggle == "on" or toggle == "1" or toggle == "true" or toggle == "yes" or toggle == "enable")
        if toggle == "" then
            -- Toggle if no on/off specified
            local chanUpper = string.upper(chanType)
            if chanUpper == "LFG" or chanUpper == "WORLD" or chanUpper == "CUSTOM" then
                chanUpper = "CHANNEL"
            end
            enabled = not monitoredChannels[chanUpper]
        end
        SetChannel(chanType, enabled)
    elseif command == "channels" then
        ListChannels()
    elseif command == "sound" then
        local toggle = string.lower(args)
        ChatMonitorDB.alertSound = (toggle == "on" or toggle == "1" or toggle == "true" or toggle == "yes")
        local status = ChatMonitorDB.alertSound and "|cff00FF00ON|r" or "|cffFF0000OFF|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Sound alerts: " .. status)
    elseif command == "flash" then
        local toggle = string.lower(args)
        ChatMonitorDB.alertFlash = (toggle == "on" or toggle == "1" or toggle == "true" or toggle == "yes")
        local status = ChatMonitorDB.alertFlash and "|cff00FF00ON|r" or "|cffFF0000OFF|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Flash alerts: " .. status)
    elseif command == "case" then
        local toggle = string.lower(args)
        ChatMonitorDB.caseSensitive = (toggle == "on" or toggle == "1" or toggle == "true" or toggle == "yes")
        local status = ChatMonitorDB.caseSensitive and "|cff00FF00ON|r" or "|cffFF0000OFF|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Case sensitivity: " .. status)
    elseif command == "history" or command == "matches" then
        ShowHistory()
    elseif command == "status" then
        PrintStatus()
    elseif command == "test" then
        -- Test alert
        PlayAlertSound()
        FlashScreen()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Test alert triggered!")
    elseif command == "show" or command == "gui" or command == "config" or command == "options" then
        CreateMainFrame()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[ChatMonitor]|r Unknown command. Type |cffFFFF00/cm help|r for help.")
    end
end
