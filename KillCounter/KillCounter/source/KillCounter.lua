KillCounter = KillCounter or {}
KillCounter.L = KillCounter.L or {}
KillCounterExport = KillCounterExport or ""
KillCounterLastExport = KillCounterLastExport or 0

local maxRows = 22

local function GetItemCount(type)
    if (KillCounterCharDB.kills == nil or KillCounterCharDB.kills[type] == nil) then
        return 0
    end
    local i = 0
    for _, _ in pairs(KillCounterCharDB.kills[type]) do
        i = i + 1
    end
    return i
end

local function KillCounter_formatTime(killTime)
    if (killTime == nil) then
        return KillCounter.L["Unknown"]
    end

    local seconds = math.floor(time() - killTime)
    if (seconds < 0) then
        return KillCounter.L["Unknown"]
    end

    if (seconds < 60) then
        if (seconds <= 1) then
            return KillCounter.L["timeFormatSeconds_singular"]
        else
            return string.format(KillCounter.L["timeFormatSeconds_plural"], seconds)
        end
    elseif seconds < 3600 then
        local minutes = math.floor(seconds / 60)
        if (minutes <= 1) then
            return KillCounter.L["timeFormatMinutes_singular"]
        else
            return string.format(KillCounter.L["timeFormatMinutes_plural"], minutes)
        end
    elseif seconds < 86400 then
        local hours = math.floor(seconds / 3600)
        if (hours <= 1) then
            return KillCounter.L["timeFormatHours_singular"]
        else
            return string.format(KillCounter.L["timeFormatHours_plural"], hours)
        end
    else
        local days = math.floor(seconds / 86400)
        if (days <= 1) then
            return KillCounter.L["timeFormatDays_singular"]
        else
            return string.format(KillCounter.L["timeFormatDays_plural"], days)
        end
    end
end

local function escape_json_key(s)
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, "\"", "\\\"")
    return s
end

local function KillCounter_formatDateTime(timestamp)
    if (timestamp == nil) then
        return KillCounter.L["Unknown"]
    end
    return date("%Y-%m-%d %H:%M:%S", timestamp)
end

local function KillCounter_TooltipMenu()
    local tooltipStates = {
        "Hide Kill Info on Tooltip",
        "Show Kills on Tooltip",
        "Show Kills + Last on Tooltip",
    }
    for i, v in pairs(tooltipStates) do
        local info = {}
        info.func = KillCounterListFrameTooltipOption_SetValue
        info.text = v
        info.value = i - 1 -- 0, 1, 2
        UIDropDownMenu_AddButton(info)
    end
end

function KillCounter_OpenTooltip(frame, tooltip)
    GameTooltip:SetOwner(frame, "ANCHOR_TOPRIGHT")
    GameTooltip:SetText(KillCounter.L[tooltip], nil, nil, nil, nil, 1)
end

function KillCounterListFrameTooltipOption_SetValue()
    local value = this.value
    KillCounterCharDB.options.showTooltip = value
    UIDropDownMenu_SetSelectedValue(KillCounterListFrameSortOption, value)

    if value == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: Tooltip info disabled")
    elseif value == 1 then
        DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: Tooltip showing kills only")
    else
        DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: Tooltip showing kills + last seen")
    end
end

local function KillCounter_RecordKill(victimName, isPlayer)
    if not victimName or victimName == "" then
        return
    end

    local type = isPlayer and "player" or "creature"

    if (KillCounterCharDB.kills[type] == nil) then
        KillCounterCharDB.kills[type] = {}
    end

    if (KillCounterCharDB.kills[type][victimName] == nil) then
        KillCounterCharDB.kills[type][victimName] = { name = victimName, kills = 0 }
    end

    KillCounterCharDB.kills[type][victimName].last = time()
    KillCounterCharDB.kills[type][victimName].kills =
        KillCounterCharDB.kills[type][victimName].kills + 1

    KillCounter_Update()
end

local lastTooltipUnit = nil
local tooltipFrame = CreateFrame("Frame")

tooltipFrame:SetScript("OnUpdate", function()
    if GameTooltip:IsVisible() and UnitExists("mouseover") then
        local unitName = UnitName("mouseover")

        if unitName and unitName ~= lastTooltipUnit then
            lastTooltipUnit = unitName

            if KillCounterCharDB and KillCounterCharDB.options.showTooltip > 0 then
                if not UnitIsPlayer("mouseover") then
                    local type = "creature"
                    if (KillCounterCharDB.kills
                        and KillCounterCharDB.kills[type]
                        and KillCounterCharDB.kills[type][unitName]) then

                        GameTooltip:AddLine(
                            KillCounter.L["Kills"] .. ": " ..
                            KillCounterCharDB.kills[type][unitName].kills
                        )

                        if KillCounterCharDB.options.showTooltip == 2 then
                            GameTooltip:AddLine(
                                KillCounter.L["LastKill"] .. " " ..
                                KillCounter_formatTime(KillCounterCharDB.kills[type][unitName].last)
                            )
                        end

                        GameTooltip:Show()
                    end
                end
            end
        end
    else
        lastTooltipUnit = nil
    end
end)

local function KillCounter_GetSortedList(type)
    local list = {}

    if KillCounterCharDB and KillCounterCharDB.kills and KillCounterCharDB.kills[type] then
        for _, v in pairs(KillCounterCharDB.kills[type]) do
            table.insert(list, v)
        end

        table.sort(list, function(a, b)
            local s = KillCounterCharDB.options and KillCounterCharDB.options.sort or 4
            if s == 1 then
                return a.name < b.name
            elseif s == 2 then
                return a.name > b.name
            elseif s == 3 then
                return a.kills < b.kills
            elseif s == 4 then
                return a.kills > b.kills
            elseif s == 5 then
                return (a.last or 0) < (b.last or 0)
            elseif s == 6 then
                return (a.last or 0) > (b.last or 0)
            end
            return a.name < b.name
        end)
    end

    return list
end

function KillCounter_OnLoad()
    KillCounterRow1:SetNormalTexture("")
    KillCounterRow1:Show()
    KillCounterRow1Text:SetText(KillCounter.L["Name"])
    KillCounterRow1Kills:SetText(KillCounter.L["Kills"])
    KillCounterRow1Level:SetText(KillCounter.L["LastKill"])

    KillCounterListFrameTab1:Hide()
    KillCounterListFrameTab2:Hide()

    UIDropDownMenu_Initialize(KillCounterListFrameSortOption, KillCounter_TooltipMenu)
    UIDropDownMenu_SetWidth(160, KillCounterListFrameSortOption)
    UIDropDownMenu_SetSelectedValue(
        KillCounterListFrameSortOption,
        KillCounterCharDB and KillCounterCharDB.options.showTooltip or 2
    )

    KillCounterRow1:SetScript("OnMouseUp", function()
        local mouseX = GetCursorPosition()
        local btnLeft = this:GetLeft()
        local btnWidth = this:GetWidth()
        local scale = this:GetEffectiveScale()
        local relativeX = (mouseX / scale) - btnLeft

        if relativeX < btnWidth * 0.5 then
            if KillCounterCharDB.options.sort == 1 then
                KillCounterCharDB.options.sort = 2 
            else
                KillCounterCharDB.options.sort = 1 
            end
        elseif relativeX < btnWidth * 0.75 then
            if KillCounterCharDB.options.sort == 3 then
                KillCounterCharDB.options.sort = 4 
            else
                KillCounterCharDB.options.sort = 3
            end
        else
            if KillCounterCharDB.options.sort == 5 then
                KillCounterCharDB.options.sort = 6 
            else
                KillCounterCharDB.options.sort = 5 
            end
        end

        KillCounter_Update()
    end)

    table.insert(UISpecialFrames, "KillCounterListFrame")

    KillCounterListFrame:RegisterEvent('ADDON_LOADED')
    KillCounterListFrame:RegisterEvent('CHAT_MSG_COMBAT_HOSTILE_DEATH')

    KillCounterListFrame:SetScript('OnEvent', function()
        if (event == "ADDON_LOADED" and arg1 == "KillCounter") then
            if (KillCounterCharDB == nil) then
                KillCounterCharDB = {
                    options = {
                        sort = 4,
                        showTooltip = 2, -- 0=off, 1=kills only, 2=kills+last seen
                    },
                    kills = {},
                }
            end

            if KillCounterExport == nil then
                KillCounterExport = ""
            end

            if type(KillCounterCharDB.options.showTooltip) == "boolean" then
                KillCounterCharDB.options.showTooltip =
                    KillCounterCharDB.options.showTooltip and 2 or 0
            elseif KillCounterCharDB.options.showTooltip == nil then
                KillCounterCharDB.options.showTooltip = 2
            end

            KillCounterListFrameTab1:SetText(KillCounter.L["ListFrameTab1"])
            KillCounterListFrameTab2:SetText(KillCounter.L["ListFrameTab2"])
            KillCounterListFrameTitle:SetText(KillCounter.L["Kills"])

            UIDropDownMenu_SetSelectedValue(
                KillCounterListFrameSortOption,
                KillCounterCharDB.options.showTooltip
            )

        elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
            local victim = nil
            if string.find(arg1, "You have slain") then
                victim = string.gsub(arg1, "You have slain ", "")
                victim = string.gsub(victim, "%.", "")
                victim = string.gsub(victim, "!", "")

                KillCounter_RecordKill(victim, false)
            end
        end
    end)

    -- commands
    SlashCmdList["KillCounter"] = function(msg)
        if msg == "export" or msg == "x" or msg == "ex" or msg == "export" then
            if not KillCounterCharDB.kills or not KillCounterCharDB.kills["creature"] then
                DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: No kills to export!")
                return
            end

            local count = 0
            for _ in pairs(KillCounterCharDB.kills["creature"]) do
                count = count + 1
            end
            if count == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: No kills to export!")
                return
            end

            local ordered = KillCounter_GetSortedList("creature")
            local lines = {}
            for _, data in ipairs(ordered) do
                table.insert(lines, ' ["' .. escape_json_key(data.name) .. '"] = ' .. data.kills)
            end
            local json = "{\n" .. table.concat(lines, ",\n") .. "\n}"

            if not KillCounterExportFrame then
                local frame = CreateFrame("Frame", "KillCounterExportFrame", UIParent)
                frame:SetWidth(400)
                frame:SetHeight(300)
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                frame:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                    tile = true,
                    tileSize = 32,
                    edgeSize = 32,
                    insets = { left = 11, right = 12, top = 12, bottom = 11 },
                })
                frame:SetMovable(true)
                frame:EnableMouse(true)
                frame:RegisterForDrag("LeftButton")
                frame:SetScript("OnDragStart", function() this:StartMoving() end)
                frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

                local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                title:SetPoint("TOP", 0, -15)
                frame.title = title

                local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
                closeBtn:SetPoint("TOPRIGHT", -5, -5)

                local scrollFrame = CreateFrame("ScrollFrame", "KillCounterExportScrollFrame", frame, "UIPanelScrollFrameTemplate")
                scrollFrame:SetPoint("TOPLEFT", 20, -40)
                scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

                local editBox = CreateFrame("EditBox", "KillCounterExportEditBox", scrollFrame)
                editBox:SetMultiLine(true)
                editBox:SetAutoFocus(false)
                editBox:SetFontObject("GameFontHighlightSmall")
                editBox:SetWidth(350)
                editBox:SetHeight(200)
                scrollFrame:SetScrollChild(editBox)
                frame.editBox = editBox

                local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                instructions:SetPoint("BOTTOM", 0, 15)
                instructions:SetText("Select all (Ctrl+A) and copy (Ctrl+C)")
            end

            KillCounterExportFrame.title:SetText("Kill Counter Export")
            KillCounterExportFrame.editBox:SetText(json)
            KillCounterExportFrame.editBox:HighlightText()
            KillCounterExportFrame:Show()
            DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: Exported " .. count .. " entries!")

        elseif msg == "deleteall confirm" then
            KillCounterCharDB.kills = {}
            DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: All kills have been cleared!")
            if KillCounterListFrame:IsVisible() then
                KillCounter_Update()
            end

        elseif msg == "deleteall" or msg == "delete all" then
            DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: WARNING!")
            DEFAULT_CHAT_FRAME:AddMessage("This will delete ALL saved kills!")
            DEFAULT_CHAT_FRAME:AddMessage("Type '/kc deleteall confirm' to proceed.")

        elseif msg == "delete" then
            DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: /kc delete <name>")
            DEFAULT_CHAT_FRAME:AddMessage("Example: /kc delete Chasm Orc")

        elseif msg == "tooltip" or msg == "tt" then
            KillCounterCharDB.options.showTooltip = math.mod(KillCounterCharDB.options.showTooltip + 1, 3)
            if KillCounterCharDB.options.showTooltip == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: Tooltip info disabled")
            elseif KillCounterCharDB.options.showTooltip == 1 then
                DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: Tooltip showing kills only")
            else
                DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: Tooltip showing kills + last seen")
            end

        elseif msg == "tooltip 0" or msg == "tt 0" then
            KillCounterCharDB.options.showTooltip = 0
            DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: Tooltip info disabled")

        elseif msg == "tooltip 1" or msg == "tt 1" then
            KillCounterCharDB.options.showTooltip = 1
            DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: Tooltip showing kills only")

        elseif msg == "tooltip 2" or msg == "tt 2" then
            KillCounterCharDB.options.showTooltip = 2
            DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: Tooltip showing kills + last seen")

        elseif msg == "help" or msg == "h" then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Kill Counter Commands]|r")
            DEFAULT_CHAT_FRAME:AddMessage("/kc - Toggle kill counter window")
            DEFAULT_CHAT_FRAME:AddMessage("/kc delete <name> - Delete specific entry")
            DEFAULT_CHAT_FRAME:AddMessage("/kc deleteall - Delete all saved kills (requires confirmation)")
            DEFAULT_CHAT_FRAME:AddMessage("/kc export - Export kills for copy/paste")
            DEFAULT_CHAT_FRAME:AddMessage("/kc tt - Cycle tooltip display settings")
            DEFAULT_CHAT_FRAME:AddMessage("/kc tt 0/1/2 - Change display setting directly")
            DEFAULT_CHAT_FRAME:AddMessage("/kc help - Show this help")

        elseif string.find(msg, "^delete ") then
            local mobName = string.gsub(msg, "^delete ", "")
            if KillCounterCharDB.kills and KillCounterCharDB.kills["creature"] then
                local found = false
                local actualName = nil
                for name, _ in pairs(KillCounterCharDB.kills["creature"]) do
                    if string.lower(name) == string.lower(mobName) then
                        found = true
                        actualName = name
                        break
                    end
                end

                if found then
                    KillCounterCharDB.kills["creature"][actualName] = nil
                    DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: Deleted entry for '" .. actualName .. "'")
                    if KillCounterListFrame:IsVisible() then
                        KillCounter_Update()
                    end
                else
                    DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: No entry found for '" .. mobName .. "'")
                end
            else
                DEFAULT_CHAT_FRAME:AddMessage("Kill Counter: No entry found for '" .. mobName .. "'")
            end

        else
            if (not GameMenuFrame:IsVisible()) then
                if (KillCounterListFrame:IsVisible()) then
                    KillCounterListFrame:Hide()
                else
                    KillCounterListFrame:Show()
                end
            end
        end
    end

    SLASH_KillCounter1 = "/kills"
    SLASH_KillCounter2 = "/kill"
    SLASH_KillCounter3 = "/kc"
    SLASH_KillCounter4 = "/killcounter"
end

function KillCounter_Update()
    local type = "creature"

    local nameText = KillCounter.L["Name"]
    local killsText = KillCounter.L["Kills"]
    local lastText = KillCounter.L["LastKill"]

    local greenstar = "|cff00ff00*|r"
    local bluestar = "|cff00aaff*|r"

    if KillCounterCharDB.options.sort == 1 then
        nameText = nameText .. "|cff00aaff (a-z)|r"
    elseif KillCounterCharDB.options.sort == 2 then
        nameText = nameText .. "|cff00ff00 (z-a)|r"
    elseif KillCounterCharDB.options.sort == 3 then
        killsText = killsText .. bluestar
    elseif KillCounterCharDB.options.sort == 4 then
        killsText = killsText .. greenstar
    elseif KillCounterCharDB.options.sort == 5 then
        lastText = lastText .. bluestar
    elseif KillCounterCharDB.options.sort == 6 then
        lastText = lastText .. greenstar
    end

    KillCounterRow1Text:SetText(nameText)
    KillCounterRow1Kills:SetText(killsText)
    KillCounterRow1Level:SetText(lastText)

    FauxScrollFrame_Update(KillCounterListScrollBar, GetItemCount(type) + 1, maxRows, 16)
    local scrollOffset = FauxScrollFrame_GetOffset(KillCounterListScrollBar)

    local list = {}
    local allKills = 0

    if (KillCounterCharDB ~= nil and KillCounterCharDB.kills ~= nil and KillCounterCharDB.kills[type] ~= nil) then
        local tmpTable = {}
        for _, v in pairs(KillCounterCharDB.kills[type]) do
            table.insert(tmpTable, v)
            allKills = allKills + v.kills
        end

        table.sort(tmpTable, function(a, b)
            if (KillCounterCharDB.options.sort == 1) then
                return a.name < b.name
            elseif (KillCounterCharDB.options.sort == 2) then
                return a.name > b.name
            elseif (KillCounterCharDB.options.sort == 3) then
                return a.kills < b.kills
            elseif (KillCounterCharDB.options.sort == 4) then
                return a.kills > b.kills
            elseif (KillCounterCharDB.options.sort == 5) then
                return a.last < b.last
            elseif (KillCounterCharDB.options.sort == 6) then
                return a.last > b.last
            end
            return a.name > b.name
        end)

        local i = 0
        for _, v in pairs(tmpTable) do
            if (i >= scrollOffset) then
                table.insert(list, { first = v.name, second = v.kills, third = v.last })
            end
            if (i == scrollOffset + (maxRows - 1)) then
                break
            end
            i = i + 1
        end
    end

    KillCounterListFrameTitle:SetText("Total Kills: " .. allKills)

    for i = 2, maxRows do
        local btn = getglobal('KillCounterRow' .. i)
        local playername = getglobal('KillCounterRow' .. i .. 'Text')
        local killCount = getglobal('KillCounterRow' .. i .. 'Kills')
        local playerLevel = getglobal('KillCounterRow' .. i .. 'Level')

        btn:SetNormalTexture("")
        playername:SetTextColor(1, 1, 1)
        killCount:SetTextColor(1, 1, 1)
        playerLevel:SetTextColor(1, 1, 1)

        local row = list[i - 1]
        if (row ~= nil) then
            btn:Show()
            playername:SetText(row.first)
            killCount:SetText(row.second)
            playerLevel:SetText(KillCounter_formatTime(row.third))

            btn:SetScript("OnEnter", function()
                if row.third then
                    local mouseX = GetCursorPosition()
                    local btnLeft = this:GetLeft()
                    local btnWidth = this:GetWidth()
                    local scale = this:GetEffectiveScale()

                    if mouseX / scale > btnLeft + (btnWidth * 0.66) then
                        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                        GameTooltip:SetText(KillCounter_formatDateTime(row.third), 1, 1, 1, 1, 1)
                        GameTooltip:Show()
                    end
                end
            end)

            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        else
            btn:Hide()
        end
    end
end
