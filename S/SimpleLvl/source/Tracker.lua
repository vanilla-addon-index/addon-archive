local SL = SimpleLvl
local Tracker = SL.tracker
Tracker.e = CreateFrame("Frame")
local fn = "SLTracker"
Tracker.track = CreateFrame("Frame", fn, UIParent)
local _G = getfenv(0)

local xpPerKill = 0;
local killsThisSession = 0;
local questsThisSession = 0;
local killsToLvl = 0;
local xpPerQuest = 0;
local questsToLvl = 0;
local killsPerHour = 0
local questsPerHour = 0

local bn = {
    [1] = "Kills",
    [2] = "Quests",
    [3] = "Experience",
    [4] = "Time",
}

local function InitializeTracker()
    local SLMessageFrame = CreateFrame("Frame", "SLMessageFrame", UIParent)
    SLMessageFrame:SetWidth(300)
    SLMessageFrame:SetHeight(50)
    SLMessageFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    SLMessageFrame:Hide()

    local messageText = SLMessageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    messageText:SetPoint("CENTER", SLMessageFrame, "CENTER")
    messageText:SetText("")

    local messageDuration = 0
    local messageTimeElapsed = 0

    function ShowSLMessage(text, duration)
        messageText:SetText(text)
        messageDuration = duration or 3
        messageTimeElapsed = 0
        SLMessageFrame:Show()
    end

    SLMessageFrame:SetScript("OnUpdate", function(self)
        messageTimeElapsed = messageTimeElapsed + arg1
        if messageTimeElapsed >= messageDuration then
            this:Hide()
            messageTimeElapsed = 0
        end
    end)

    Tracker.track:SetWidth(60)
    Tracker.track:SetHeight(130)
    Tracker.track:SetMovable(true)
    Tracker.track:EnableMouse(true)
    Tracker.track:SetClampedToScreen(true)
    Tracker.track:RegisterEvent("PLAYER_ENTERING_WORLD")
    Tracker.track:SetScript("OnEvent", Tracker.OnEvent)

    do
        local pos = SLDatastore.data[SLProfile].Store.trackerPos
        if pos then
            Tracker.track:ClearAllPoints()
            Tracker.track:SetPoint(pos.point, pos.parentName, pos.relativePoint, pos.xOfs, pos.yOfs)
        else
            Tracker.track:SetPoint("TOP", UIParent, "TOP", -300, -100)
        end
    end

    Tracker.track:SetScript("OnShow", function()
        local stored = SLDatastore.data[SLProfile].Store.trackerPos
        if stored then
            this:ClearAllPoints()
            this:SetPoint(stored.point, stored.parentName, stored.relativePoint, stored.xOfs, stored.yOfs)
        end
    end)


    Tracker.track:SetScript("OnHide", function()

    end)

    Tracker.track:SetScript("OnMouseDown", function()
        this:StartMoving()
    end)

    Tracker.track:SetScript("OnMouseUp", function()
        this:StopMovingOrSizing()


        local point, relativeTo, relativePoint, xOfs, yOfs = this:GetPoint()
        local parentName = "UIParent"

        SLDatastore.data[SLProfile].Store.trackerPos = {
            point = point,
            parentName = parentName,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
        }
    end)


    Tracker.track:SetBackdrop({
        bgFile = SL:GetTexture("Background"),
        edgeFile = SL:GetTexture("Frame"),
        tile = true,
        tileSize = 128,
        edgeSize = 32,
        insets = {
            left = 5,
            right = 5,
            top = 22,
            bottom = 5
        },
    })

    local name = Tracker.track:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", 0, -5)
    name:SetWidth(37)
    name:SetHeight(12)
    name:SetJustifyH("CENTER")
    name:SetText("SL")

    Tracker.track.name = name

    local close = CreateFrame("Button", fn .. "CloseButton", Tracker.track, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", Tracker.track, 4, 4)
    close:SetScript("OnClick", function()
        SLDatastore.data[SLProfile].Store.toggle = false
        Tracker.track:Hide()
    end)

    Tracker.track.close = close

    local prevButton


    for i = 1, 4 do
        local button = CreateFrame("Button", fn .. "TrackerButton" .. bn[i], Tracker.track, "UIPanelButtonTemplate")
        button:SetWidth(45)
        button:SetHeight(20)

        if i == 1 then
            button:SetPoint("TOP", Tracker.track, "TOP", 2, -25)
        else
            button:SetPoint("TOP", prevButton, "BOTTOM", 0, -5)
        end

        prevButton = button

        local norm = button:GetNormalTexture()
        local highlight = button:GetHighlightTexture()
        local push = button:GetPushedTexture()

        button.icon = button:CreateTexture(nil, "OVERLAY")

        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.text:SetPoint("CENTER", 10, 0)
        button.text:SetJustifyH("RIGHT")
        button.text:SetText("N/A")


        if i == 1 then
            norm:SetTexture(SL:GetTexture("Button"))
            norm:SetVertexColor(0.4, 0, 0, 1)
            highlight:SetTexture(SL:GetTexture("Button"))
            highlight:SetVertexColor(0.4, 0, 0, 0.5)
            push:SetTexture(SL:GetTexture("Button"))
            push:SetVertexColor(0.3, 0, 0, 1)

            button.icon:SetPoint("LEFT", 1, 0)
            button.icon:SetHeight(15)
            button.icon:SetWidth(15)
            button.icon:SetTexture(SL:GetTexture("Attack"))
            button.icon:SetVertexColor(0.6, 0, 0, 0.8)

            button:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
            button:SetScript("OnEvent", function()
                if event == "CHAT_MSG_COMBAT_XP_GAIN" then
                    if string.find(arg1, "dies, you gain") then
                        local _, _, unitName, gainedStr = string.find(arg1, "^(.-) dies, you gain (%d+) experience")
                        if unitName and gainedStr then
                            local gainedNum = tonumber(gainedStr)
                            if gainedNum then
                                local restedXP = GetXPExhaustion() or 0
                                local gainedRest = 0

                                if restedXP > 0 then
                                    gainedRest = math.min(gainedNum, restedXP)
                                end
                                killsThisSession = killsThisSession + 1
                                xpPerKill = gainedNum + gainedRest
                                Tracker.e:UpdateKillStats(gainedNum)
                                Tracker.e:UpdateKills()
                                Tracker.e:UpdateTimer(xpPerKill)
                                ShowSLMessage(
                                    string.format("%d XP gained, you need to kill %d more %s", gainedNum, killsToLvl,
                                        unitName), 5)

                                button.text:SetText(killsToLvl)
                            end
                        end
                    end
                end
            end)
            --UIErrorsFrame:AddMessage("Hello, World!", 1, 0, 0, 1, 3)

            button:SetScript("OnEnter", function()
                Tracker.e:UpdateTooltip(button)
                GameTooltip:SetText("|cff1a9fc0Kill Stats|r")
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine(SL.util.Colorize("Kills This Session:", 1, 1, 0.5),
                    SL.util.Colorize(killsThisSession, 0.8, 0, 0), 1, 1, 1)
                GameTooltip:AddDoubleLine(SL.util.Colorize("Kills/Hour:", 1, 1, 0.5),
                    SL.util.Colorize(killsPerHour, 0.8, 0, 0), 1, 1, 1)
                GameTooltip:Show()
            end)

            button:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        elseif i == 2 then
            norm:SetTexture(SL:GetTexture("Button"))
            norm:SetVertexColor(0.4, 0, 0.4, 1)
            highlight:SetTexture(SL:GetTexture("Button"))
            highlight:SetVertexColor(0.4, 0, 0.4, 0.5)
            push:SetTexture(SL:GetTexture("Button"))
            push:SetVertexColor(0.3, 0, 0.3, 1)

            button.icon:SetPoint("LEFT", -1, 0)
            button.icon:SetTexture(SL:GetTexture("Quest"))
            button.icon:SetDesaturated(true)
            button.icon:SetVertexColor(0.6, 0, 0, 0.8)
            button.icon:SetHeight(18)
            button.icon:SetWidth(20)

            button:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
            button:SetScript("OnEvent", function()
                if event == "CHAT_MSG_COMBAT_XP_GAIN" then
                    if not string.find(arg1, "dies, you gain") then
                        local startPos, endPos, gainedStr = string.find(arg1, "(%d+) experience")
                        if gainedStr then
                            local gainedNum = tonumber(gainedStr)
                            if gainedNum then
                                questsThisSession = questsThisSession + 1
                                xpPerQuest = gainedNum
                                Tracker.e:UpdateQuestStats()
                                Tracker.e:UpdateQuests()
                                Tracker.e:UpdateTimer(gainedNum)
                                button.text:SetText(questsToLvl)
                            end
                        end
                    else
                        Tracker.e:UpdateQuestStats()
                        Tracker.e:UpdateQuests()
                        button.text:SetText(questsToLvl)
                    end
                end
            end)

            button:SetScript("OnEnter", function()
                Tracker.e:UpdateTooltip(button)
                GameTooltip:SetText("|cff1a9fc0Quest Stats|r")
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine(SL.util.Colorize("Quests This Session:", 1, 1, 0.5),
                    SL.util.Colorize(questsThisSession, 0.8, 0, 0.8), 1, 1, 1)
                GameTooltip:AddDoubleLine(SL.util.Colorize("Quests/Hour:", 1, 1, 0.5),
                    SL.util.Colorize(questsPerHour, 0.8, 0, 0.8), 1, 1, 1)
                GameTooltip:Show()
            end)

            button:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        elseif i == 3 then
            norm:SetTexture(SL:GetTexture("Button"))
            norm:SetVertexColor(0, 0.3, 0.4, 1)
            highlight:SetTexture(SL:GetTexture("Button"))
            highlight:SetVertexColor(0, 0.3, 0.4, 0.5)
            push:SetTexture(SL:GetTexture("Button"))
            push:SetVertexColor(0, 0.1, 0.2, 1)

            button.text:ClearAllPoints()
            button.text:SetPoint("CENTER", 0, 0)

            button:RegisterEvent("PLAYER_ENTERING_WORLD")
            button:RegisterEvent("PLAYER_XP_UPDATE")
            button:SetScript("OnEvent", function()
                local currXP = UnitXP("player")
                local maxXP = UnitXPMax("player")
                local perc = math.floor((currXP / maxXP) * 100)
                button.text:SetText(perc .. "%")
            end)

            button:SetScript("OnEnter", function()
                Tracker.e:UpdateExperience(button)
            end)
            button:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            button.bar = CreateFrame("StatusBar", nil, button)
            button.bar:SetFrameLevel(button:GetFrameLevel() + 1)
            button.bar:SetAllPoints(button)
            button.bar:SetStatusBarTexture(SL:GetTexture("Button"))
            button.bar:SetStatusBarColor(0.6, 0.6, 0.6, 0.5)
            local function UpdateXPBar()
                local currXP = UnitXP("player") or 0
                local maxXP = UnitXPMax("player") or 1 -- Avoid division by zero
                button.bar:SetMinMaxValues(0, maxXP)
                button.bar:SetValue(currXP)
            end
            UpdateXPBar()
            button.bar:RegisterEvent("PLAYER_ENTERING_WORLD")
            button.bar:RegisterEvent("UNIT_XP_UPDATE")
            button.bar:SetScript("OnEvent", function()
                if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_XP_UPDATE" then
                    UpdateXPBar()
                end
            end)
        elseif i == 4 then
            norm:SetTexture(SL:GetTexture("Button"))
            norm:SetVertexColor(0.4, 0.3, 0, 1)
            highlight:SetTexture(SL:GetTexture("Button"))
            highlight:SetVertexColor(0.4, 0.3, 0, 0.5)
            push:SetTexture(SL:GetTexture("Button"))
            push:SetVertexColor(0.2, 0.1, 0, 1)

            button.icon:SetPoint("LEFT", -1, 0)
            button.icon:SetTexture(SL:GetTexture("Time"))
            button.icon:SetHeight(20)
            button.icon:SetWidth(20)

            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            button:SetScript("OnEnter", function()
                Tracker.e:UpdateTooltip(button)
                GameTooltip:SetText("|cff1a9fc0Time to Level Info|r")
                GameTooltip:AddLine(" ")
                local elapsedTime, totalXP, xpPerSecond, xpPerHour, timeToLevel = Tracker.e:GetTimerData()
                local timeToLevelH, timeToLevelM, timeToLevelS = SL.util.SecondsToTime(timeToLevel)
                GameTooltip:AddDoubleLine(SL.util.Colorize("Time to Level:", 1, 1, 0.5),
                    SL.util.Colorize(string.format("%02dh %02dm %02ds", timeToLevelH, timeToLevelM, timeToLevelS), 0.5, 1,
                        0.5), 1, 1, 1)
                GameTooltip:AddDoubleLine(SL.util.Colorize("Total XP:", 1, 1, 0.5), totalXP or "N/A", 1, 1, 1)
                GameTooltip:AddDoubleLine(SL.util.Colorize("XP/Hour:", 1, 1, 0.5), xpPerHour or "N/A", 1, 1, 1)
                GameTooltip:AddDoubleLine(SL.util.Colorize("XP Needed:", 1, 1, 0.5),
                    UnitXPMax("player") - UnitXP("player"), 1, 1, 1)
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine(SL.util.Colorize("Left-Click:", 0, 1, 0.5), SL.util.Colorize("Reset Tracker", 0, 1, 0.5), 1, 1, 1)
                GameTooltip:AddDoubleLine(SL.util.Colorize("Right-Click:", 0, 1, 0.5), SL.util.Colorize("Print Commands", 0, 1, 0.5), 1, 1, 1)
                GameTooltip:Show()
            end)

            button:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            local updateInterval = 1
            local timeSinceLastUpdate = 0

            button:SetScript("OnUpdate", function()
                timeSinceLastUpdate = timeSinceLastUpdate + arg1
                if timeSinceLastUpdate >= updateInterval then
                    timeSinceLastUpdate = 0
                    -- Update button text dynamically with time to level
                    local _, _, _, _, timeToLevel = Tracker.e:GetTimerData()
                    local timeToLevelH, timeToLevelM, timeToLevelS = SL.util.SecondsToTime(timeToLevel)

                    local displayText = ""
                    if timeToLevelH > 0 then
                        displayText = string.format("%dh", timeToLevelH)
                    elseif timeToLevelM > 0 then
                        displayText = string.format("%dm", timeToLevelM)
                    else
                        displayText = string.format("%ds", timeToLevelS)
                    end
                    button.text:SetText(displayText)
                end
            end)

            button:SetScript("OnClick", function()
                if arg1 == "LeftButton" then
                    Tracker.e:ResetTracker()
                    ShowSLMessage("Tracker has been reset")
                elseif arg1 == "RightButton" then
                    SL:Print("/sl |cff1a9fc0lock|r, |cff1a9fc0ttswap|r, |cff1a9fc0scale <number>|r")
                end
            end)
        end
        --[[         button.texture = button:CreateTexture(nil, "BACKGROUND")
        button.texture:SetAllPoints()
        button.texture:SetTexture(SL:GetTexture("Button"))
        button.texture:SetVertexColor(0.5, 0.4, 0, 1) ]]
    end

    local resize = CreateFrame("Button", fn .. "ResizeButton", Tracker.track, "UIPanelButtonTemplate")
    resize:SetWidth(16)
    resize:SetHeight(16)
    resize:GetNormalTexture():SetTexture("Interface\\AddOns\\SimpleUI\\Media\\Textures\\ResizeGrip")
    resize:GetHighlightTexture():SetTexture("Interface\\AddOns\\SimpleUI\\Media\\Textures\\ResizeGrip")
    resize:GetPushedTexture():SetTexture("Interface\\AddOns\\SimpleUI\\Media\\Textures\\ResizeGrip")
    resize:SetPoint("BOTTOMRIGHT", Tracker.track, "BOTTOMRIGHT", 0, -1)

    local savedScale = SLDatastore.data[SLProfile].Store.trackerScale
    if savedScale then
        Tracker.e:ScaleTracker(savedScale)
    end

    resize:SetScript("OnMouseDown", function()
        Tracker.e.isResizing = true
        Tracker.e.startScale = Tracker.track:GetScale()
        Tracker.e.startCursorX, Tracker.e.startCursorY = GetCursorPosition()
    end)

    resize:SetScript("OnMouseUp", function()
        Tracker.e.isResizing = false
    end)

    resize:SetScript("OnUpdate", function()
        if Tracker.e.isResizing then
            local cursorX, cursorY = GetCursorPosition()
            local diffX = cursorX - Tracker.e.startCursorX

            -- Calculate new scale based on mouse movement
            local newScale = math.max(0.5, math.min(3, Tracker.e.startScale + (diffX / 200)))
            Tracker.e:ScaleTracker(newScale)
            ShowSLMessage(string.format("Tracker scaled to %.1f.", newScale), 3)
        end
    end)

    SLASH_SIMPLELVL1 = "/simplelvl"
    SLASH_SIMPLELVL2 = "/sl"
    SlashCmdList["SIMPLELVL"] = Tracker.e.Commands
end

function Tracker.e:UpdateKills()
    local currXP = UnitXP("player")
    local maxXP  = UnitXPMax("player")
    if xpPerKill > 0 then
        killsToLvl = math.ceil((maxXP - currXP) / xpPerKill)
    end
end

function Tracker.e:UpdateQuests()
    local currXP = UnitXP("player")
    local maxXP  = UnitXPMax("player")
    if xpPerQuest > 0 then
        questsToLvl = math.ceil((maxXP - currXP) / xpPerQuest)
    end
end

local timer = {
    start = 0,       -- Session start time (in seconds since login)
    totalXP = 0,     -- Total XP earned during the session
    xpPerSecond = 0, -- XP earned per second
    xpPerHour = 0,   -- XP/hour calculated dynamically
    timeToLevel = 0, -- Estimated time to level (in seconds)
}

function Tracker.e:InitializeTimer()
    timer.start = GetTime() -- Record the start time (seconds since login)
    timer.totalXP = 0       -- Reset total XP for the session
    timer.xpPerSecond = 0   -- Reset XP/second
    timer.xpPerHour = 0     -- Reset XP/hour
    timer.timeToLevel = 0   -- Reset time to level
end

function Tracker.e:UpdateTimer(gainedXP)
    local currTime = GetTime()                 -- Current time (seconds since login)
    local elapsedTime = currTime - timer.start -- Elapsed session time (in seconds)

    timer.totalXP = timer.totalXP + gainedXP

    if elapsedTime > 0 then
        timer.xpPerSecond = timer.totalXP / elapsedTime
        timer.xpPerHour = math.floor(timer.xpPerSecond * 3600)
    end

    local maxXP = UnitXPMax("player")
    local currXP = UnitXP("player")
    if timer.xpPerSecond > 0 then
        timer.timeToLevel = (maxXP - currXP) / timer.xpPerSecond
    else
        timer.timeToLevel = 0
    end
end

function Tracker.e:GetTimerData()
    local elapsedTime = GetTime() - timer.start

    return elapsedTime, timer.totalXP, timer.xpPerSecond, timer.xpPerHour, timer.timeToLevel
end

function Tracker.e:UpdateKillStats(gainedXP)
    local elapsedTime = GetTime() - timer.start
    if elapsedTime > 0 then
        killsPerHour = math.floor((killsThisSession / elapsedTime) * 3600)
    end
end

function Tracker.e:UpdateQuestStats()
    local elapsedTime = GetTime() - timer.start
    if elapsedTime > 0 then
        questsPerHour = math.floor((questsThisSession / elapsedTime) * 3600)
    end
end

function Tracker.e:UpdateExperience(button)
    local currLevel = UnitLevel("player")
    local currXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local needed = math.floor(maxXP - currXP)
    local perc = math.floor((currXP / maxXP) * 100)
    local barsLeft = 20 - math.floor(perc / 5)
    local restedXP = GetXPExhaustion()
    local restedPerc
    if restedXP ~= nil then
        restedPerc = math.floor((restedXP / maxXP) * 100)
    end
    Tracker.e:UpdateTooltip(button)
    GameTooltip:SetText("|cff1a9fc0Experience|r")
    GameTooltip:AddLine(" ")
    if UnitLevel("player") < MAX_PLAYER_LEVEL then
        GameTooltip:AddDoubleLine(SL.util.Colorize("Current", 1, 1, 0.5), currXP, 1, 1, 1)
        GameTooltip:AddDoubleLine(SL.util.Colorize("Needed", 1, 1, 0.5), needed, 1, 1, 1)
        GameTooltip:AddDoubleLine(SL.util.Colorize("Pecent", 1, 1, 0.5), SL.util.Colorize("[" .. perc .. "%]", 0, 0.9, 1),
            1, 1, 1)
        if restedXP ~= nil then
            GameTooltip:AddDoubleLine(SL.util.Colorize("Rested", 1, 1, 0.5),
                SL.util.Colorize(restedXP .. " [" .. restedPerc .. "%]", 0, 0.9, 1), 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(SL.util.Colorize("Bars", 1, 1, 0.5), barsLeft, 1, 1, 1)
    end
    GameTooltip:Show()
end

function Tracker.e:UpdateDrag()
    SLDatastore.data[SLProfile].locked = not SLDatastore.data[SLProfile].locked
    if SLDatastore.data[SLProfile].locked then
        Tracker.track:SetMovable(false)
        Tracker.track:EnableMouse(false)
    else
        Tracker.track:SetMovable(true)
        Tracker.track:EnableMouse(true)
    end
end

function Tracker.e:UpdateTooltip(button)
    if SLDatastore.data[SLProfile].Store.ttswap == true then
        GameTooltip:SetOwner(button, "ANCHOR_LEFT", -5, 0)
    else
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT", 5, 0)
    end
end

function Tracker.e:ScaleTracker(newScale)
    local frame = Tracker.track
    local oldScale = frame:GetScale() or 1
    local frameX = frame:GetLeft() * oldScale
    local frameY = frame:GetTop() * oldScale

    frame:SetScale(newScale)

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", frameX / newScale, frameY / newScale)

    SLDatastore.data[SLProfile].Store.trackerScale = newScale

end

function Tracker.e:ResetTracker()
    xpPerKill = 0
    killsThisSession = 0
    questsThisSession = 0
    killsToLvl = 0
    xpPerQuest = 0
    questsToLvl = 0
    killsPerHour = 0
    questsPerHour = 0

    self:InitializeTimer()


    for i = 1, 4 do
        local button = _G[fn .. "TrackerButton" .. bn[i]]
        if button then
            if i == 1 then
                button.text:SetText("N/A")
            elseif i == 2 then
                button.text:SetText("N/A")
            elseif i == 3 then
                --button.text:SetText("0%")
            elseif i == 4 then
                button.text:SetText("N/A")
            end
        end
    end

    ShowSLMessage("Tracker values reset to defaults.", 3)
end

function Tracker.e:Toggle()
    if SLDatastore.data[SLProfile].Store.toggle == true then
        Tracker.track:Show()
    else
        Tracker.track:Hide()
    end
end

function Tracker.e.Commands(msg)
    msg = string.lower(msg);
    local command, subCommand = SL.util.GetCommand(msg);
    if command == "lock" then
        Tracker.e:UpdateDrag()
    elseif command == "ttswap" then
        SLDatastore.data[SLProfile].Store.ttswap = not SLDatastore.data[SLProfile].Store.ttswap
        ShowSLMessage("Tooltip has been swapped to the opposite side")
    elseif command == "scale" then
        if tonumber(subCommand) then
            Tracker.e:ScaleTracker(tonumber(subCommand))
            ShowSLMessage(string.format("Tracker scaled to %.1f.", tonumber(subCommand), 3))
        else
            SL:Print("Usage: /sl scale <number> (e.g., /sl scale 1.5)")
        end
    elseif command == "toggle" then
        SLDatastore.data[SLProfile].Store.toggle = not SLDatastore.data[SLProfile].Store.toggle
        Tracker.e:Toggle()
    elseif command == "reset" then
        Tracker.e:ResetTracker()
        ShowSLMessage("Tracker has been reset")
    else
        SL:Print("/sl |cff1a9fc0toggle|r, |cff1a9fc0lock|r, |cff1a9fc0ttswap|r, |cff1a9fc0scale <number>|r,")
    end
end

function SLLoadTracker()
    InitializeTracker()
end

Tracker.e:RegisterEvent("PLAYER_ENTERING_WORLD")
Tracker.e:SetScript("OnEvent", function()
    this:InitializeTimer()
end)
--SL.InitTrack = InitializeTracker
