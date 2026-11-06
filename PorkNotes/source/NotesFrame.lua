local frame = CreateFrame("Frame", "PorkNotes_NotesFrame", UIParent)
frame:SetWidth(600)
frame:SetHeight(450)
frame:SetPoint("CENTER", UIParent)
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetResizable(true)
frame:SetMinResize(500, 300)
frame:SetMaxResize(900, 700)
frame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
frame:SetBackdropColor(0, 0, 0, 0.8)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint()
    PorkNotes.SetSetting("NotesFramePos", point .. "," .. relativePoint .. "," .. math.floor(x) .. "," .. math.floor(y))
end)
frame:Hide()

-- Delay timers for context menu close

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -15)
title:SetText("|cFFD893EDPork|r|cFFFFBB00Notes|r")

local resizer = CreateFrame("Button", nil, frame)
resizer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
resizer:SetWidth(16)
resizer:SetHeight(16)
resizer:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
resizer:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

tinsert(UISpecialFrames, frame:GetName())

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

local createNoteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
createNoteButton:SetWidth(100)
createNoteButton:SetHeight(24)
createNoteButton:SetPoint("BOTTOMLEFT", 30, 20)
createNoteButton:SetText("New note")
createNoteButton:SetScript("OnClick", function()
    PorkNotes.ShowCreateFrame()
end)

-- Sync All button
local syncAllButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
syncAllButton:SetWidth(80)
syncAllButton:SetHeight(24)
syncAllButton:SetPoint("BOTTOM", frame, "BOTTOM", -30, 20)
syncAllButton:SetText("Sync All")

local syncAllDropdown = CreateFrame("Frame", "PorkNotes_SyncAllDropdown", UIParent, "UIDropDownMenuTemplate")

syncAllButton:SetScript("OnClick", function()
    UIDropDownMenu_Initialize(syncAllDropdown, function()
        local options = {
            { text = "Party",        func = function() CloseDropDownMenus() PorkNotes.SyncAll("PARTY") end },
            { text = "Raid",         func = function() CloseDropDownMenus() PorkNotes.SyncAll("RAID") end },
            { text = "Guild",        func = function() CloseDropDownMenus() PorkNotes.SyncAll("GUILD") end },
            { text = "Battleground", func = function() CloseDropDownMenus() PorkNotes.SyncAll("BATTLEGROUND") end },
        }
        for _, opt in ipairs(options) do
            local info = {}
            info.text = opt.text
            info.notCheckable = 1
            local f = opt.func
            info.func = f
            UIDropDownMenu_AddButton(info)
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, syncAllDropdown, "cursor", 0, 0)
end)

local settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
settingsButton:SetWidth(100)
settingsButton:SetHeight(24)
settingsButton:SetPoint("BOTTOMRIGHT", -30, 20)
settingsButton:SetText("Settings")
settingsButton:SetScript("OnClick", function()
    frame:Hide()
    PorkNotes.ShowSettingsFrame()
end)

-- Search and sort toolbar
local toolbarContainer = CreateFrame("Frame", nil, frame)
toolbarContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -32)
toolbarContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -32)
toolbarContainer:SetHeight(26)

local searchLabel = toolbarContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
searchLabel:SetPoint("LEFT", 0, 0)
searchLabel:SetText("Search:")
searchLabel:SetTextColor(1, 1, 1)

local searchBox = CreateFrame("EditBox", nil, toolbarContainer)
searchBox:SetWidth(160)
searchBox:SetHeight(22)
searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
searchBox:SetFontObject(GameFontNormalSmall)
searchBox:SetTextInsets(4, 4, 2, 2)
searchBox:SetTextColor(1, 1, 1)
searchBox:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
searchBox:SetBackdropColor(0, 0, 0, 0.5)
searchBox:SetAutoFocus(false)

local clearButton = CreateFrame("Button", nil, toolbarContainer, "UIPanelButtonTemplate")
clearButton:SetWidth(40)
clearButton:SetHeight(20)
clearButton:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)
clearButton:SetText("Clear")

local sortLabel = toolbarContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sortLabel:SetPoint("RIGHT", -130, 0)
sortLabel:SetText("Sort:")
sortLabel:SetTextColor(1, 1, 1)

local sortDropdown = CreateFrame("Frame", "PorkNotes_SortDropdown", toolbarContainer, "UIDropDownMenuTemplate")
sortDropdown:SetPoint("RIGHT", 20, 0)
UIDropDownMenu_SetWidth(100, sortDropdown)

-- Scroll container
local scrollContainer = CreateFrame("Frame", nil, frame)
scrollContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -62)
scrollContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 48)
scrollContainer:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
scrollContainer:SetBackdropColor(0, 0, 0, 0.4)

-- Column headers
local headerContainer = CreateFrame("Frame", nil, scrollContainer)
headerContainer:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 10, -8)
headerContainer:SetPoint("TOPRIGHT", scrollContainer, "TOPRIGHT", -30, -8)
headerContainer:SetHeight(16)

local headerName = headerContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerName:SetPoint("TOPLEFT", 0, 0)
headerName:SetTextColor(0.7, 0.7, 1)
headerName:SetText("Player")

local headerNote = headerContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerNote:SetTextColor(0.7, 0.7, 1)
headerNote:SetText("Note")

local headerAuthor = headerContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerAuthor:SetTextColor(0.7, 0.7, 1)
headerAuthor:SetText("Author")

local headerDate = headerContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerDate:SetTextColor(0.7, 0.7, 1)
headerDate:SetText("Updated")

local headerDivider = scrollContainer:CreateTexture(nil, "BACKGROUND")
headerDivider:SetHeight(1)
headerDivider:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 6, -22)
headerDivider:SetPoint("TOPRIGHT", scrollContainer, "TOPRIGHT", -6, -22)
headerDivider:SetTexture(0.3, 0.3, 0.3, 0.8)

local scrollFrame = CreateFrame("ScrollFrame", "PorkNotes_ShowNotes_ScrollFrame", scrollContainer, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", scrollContainer, 10, -26)
scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, -30, 10)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetWidth(1)
scrollFrame:SetScrollChild(content)

local emptyLabel = scrollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
emptyLabel:SetPoint("CENTER", scrollFrame, "CENTER", 0, 0)
emptyLabel:SetTextColor(0.5, 0.5, 0.5)
emptyLabel:SetText("No notes yet. Right-click a player to get started.")
emptyLabel:Hide()

local lines = {}
local LINE_HEIGHT = 20

local NAME_RATIO = 0.20
local NOTE_RATIO = 0.45
local AUTH_RATIO = 0.18
local DATE_RATIO = 0.17

local function GetColumnWidths()
    local totalWidth = frame:GetWidth() - 100
    local nameW = math.floor(totalWidth * NAME_RATIO)
    local noteW = math.floor(totalWidth * NOTE_RATIO)
    local authW = math.floor(totalWidth * AUTH_RATIO)
    local dateW = totalWidth - nameW - noteW - authW
    return totalWidth, nameW, noteW, authW, dateW
end

local function ResizeEverything()
    local totalWidth, nameW, noteW, authW, dateW = GetColumnWidths()
    headerName:SetWidth(nameW)
    headerNote:SetPoint("TOPLEFT", headerContainer, "TOPLEFT", nameW + 8, 0)
    headerNote:SetWidth(noteW)
    headerAuthor:SetPoint("TOPLEFT", headerContainer, "TOPLEFT", nameW + noteW + 16, 0)
    headerAuthor:SetWidth(authW)
    headerDate:SetPoint("TOPLEFT", headerContainer, "TOPLEFT", nameW + noteW + authW + 24, 0)
    headerDate:SetWidth(dateW)
    for _, line in ipairs(lines) do
        line:SetWidth(totalWidth)
        line.nameLabel:SetWidth(nameW)
        line.noteLabel:SetWidth(noteW)
        line.noteLabel:SetPoint("TOPLEFT", nameW + 8, 0)
        line.authLabel:SetWidth(authW)
        line.authLabel:SetPoint("TOPLEFT", nameW + noteW + 16, 0)
        line.dateLabel:SetWidth(dateW)
        line.dateLabel:SetPoint("TOPLEFT", nameW + noteW + authW + 24, 0)
    end
end

frame:SetScript("OnSizeChanged", ResizeEverything)

local function FormatDate(timestamp)
    if not timestamp then return "" end
    return date("%Y-%m-%d", timestamp)
end

-- Age-based color for Updated date
local function GetAgeColor(timestamp)
    if not timestamp or timestamp == 0 then
        return 0.6, 0.6, 0.6
    end
    local age = time() - timestamp
    local day = 86400
    if age < 7 * day then
        return 0.4, 1, 0.4        -- fresh: bright green
    elseif age < 30 * day then
        return 1, 1, 0.4          -- recent: yellow
    elseif age < 90 * day then
        return 1, 0.6, 0.2        -- aging: orange
    else
        return 0.7, 0.3, 0.3      -- old: red-grey
    end
end

-- Right-click menu using native UIDropDownMenu with nested share submenu
local currentPlayerName = nil
local noteLineDropdown = CreateFrame("Frame", "PorkNotes_NoteLineDropdown", UIParent, "UIDropDownMenuTemplate")

local SHARE_CHANNELS = {
    { text = "Party",        channel = "PARTY"        },
    { text = "Raid",         channel = "RAID"         },
    { text = "Guild",        channel = "GUILD"        },
    { text = "Battleground", channel = "BATTLEGROUND" },
}

local function OpenRightClickMenu(playername)
    currentPlayerName = playername
    UIDropDownMenu_Initialize(noteLineDropdown, function()
        local level = UIDROPDOWNMENU_MENU_LEVEL
        local value = UIDROPDOWNMENU_MENU_VALUE

        if level == 1 then
            -- Title
            local title = {}
            title.text = playername
            title.isTitle = 1
            title.notCheckable = 1
            UIDropDownMenu_AddButton(title, level)

            -- Edit note
            local edit = {}
            edit.text = "Edit note"
            edit.notCheckable = 1
            edit.func = function()
                CloseDropDownMenus()
                PorkNotes.ShowNoteDetailFrame(currentPlayerName)
            end
            UIDropDownMenu_AddButton(edit, level)

            -- Share note — opens level 2 submenu
            local share = {}
            share.text = "Share note"
            share.notCheckable = 1
            share.hasArrow = 1
            share.value = "SHARE"
            UIDropDownMenu_AddButton(share, level)

            -- Delete note — opens level 2 confirm submenu
            local del = {}
            del.text = "|cffff4444Delete note|r"
            del.notCheckable = 1
            del.hasArrow = 1
            del.value = "DELETE"
            UIDropDownMenu_AddButton(del, level)

        elseif level == 2 and value == "SHARE" then
            local name = currentPlayerName
            for _, opt in ipairs(SHARE_CHANNELS) do
                local info = {}
                info.text = opt.text
                info.notCheckable = 1
                local ch = opt.channel
                info.func = function()
                    CloseDropDownMenus()
                    if not name then return end
                    PorkNotes.SyncNote(name, ch)
                end
                UIDropDownMenu_AddButton(info, level)
            end

        elseif level == 2 and value == "DELETE" then
            local nameToDelete = currentPlayerName

            local confirmTitle = {}
            confirmTitle.text = "Delete " .. (nameToDelete or "") .. "?"
            confirmTitle.isTitle = 1
            confirmTitle.notCheckable = 1
            UIDropDownMenu_AddButton(confirmTitle, level)

            local yes = {}
            yes.text = "|cffff4444Yes, delete|r"
            yes.notCheckable = 1
            yes.func = function()
                CloseDropDownMenus()
                PorkNotes.SetPlayerNote(nameToDelete, "")
                PorkNotes.UpdateNotesFrame()
            end
            UIDropDownMenu_AddButton(yes, level)

            local no = {}
            no.text = "Cancel"
            no.notCheckable = 1
            no.func = function() CloseDropDownMenus() end
            UIDropDownMenu_AddButton(no, level)
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, noteLineDropdown, "cursor", 0, 0)
end

frame:SetScript("OnShow", function()
    PlaySound("igQuestListOpen")
end)

frame:SetScript("OnHide", function()
    PlaySound("igQuestListClose")
    CloseDropDownMenus()
end)

local function OnLineClick()
    if arg1 == "LeftButton" then
        PorkNotes.ShowNoteDetailFrame(this.nameLabel:GetText())
    else
        OpenRightClickMenu(this.nameLabel:GetText())
    end
end

local function OnLineEnter()
    this.bg:SetVertexColor(0.5, 0.5, 0.5, 0.5)
    local note = PorkNotes.GetPlayerNote(this.nameLabel:GetText())
    if not note then return end
    if not note.createdAtZone and not note.created then return end
    GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    if note.createdAtZone then
        GameTooltip:AddLine("Created in: " .. note.createdAtZone, 0.6, 0.6, 0.6)
    end
    if note.created then
        GameTooltip:AddLine("Created on: " .. date("%Y-%m-%d", note.created), 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function OnLineLeave()
    this.bg:SetVertexColor(1, 1, 1, this.bgAlpha)
    GameTooltip:Hide()
end

local math_mod = math.mod or math.fmod

local function CreateLine(nameText, noteText, authText, dateText, ageTimestamp, index)
    local totalWidth, nameW, noteW, authW, dateW = GetColumnWidths()

    local position = 0
    if index > 0 then
        local _, _, _, _, offsetY = lines[index]:GetPoint()
        position = -offsetY + lines[index]:GetHeight()
    end

    if lines[index + 1] then
        local line = lines[index + 1]
        line:SetPoint("TOPLEFT", 0, -position)
        line.nameLabel:SetText(nameText)
        line.noteLabel:SetText(noteText)
        line.authLabel:SetText(authText)
        line.dateLabel:SetText(dateText)
        local r, g, b = GetAgeColor(ageTimestamp)
        line.dateLabel:SetTextColor(r, g, b)
        line:Show()
        return
    end

    local button = CreateFrame("Button", nil, content)
    button:SetHeight(LINE_HEIGHT)
    button:SetWidth(totalWidth)
    button:SetPoint("TOPLEFT", 0, -position)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(1, 1, 1, 1)
    button.bg = bg
    if math_mod(index, 2) == 0 then
        button.bgAlpha = 0
    else
        button.bgAlpha = 0.04
    end
    bg:SetVertexColor(1, 1, 1, button.bgAlpha)

    local nameLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 0, 0)
    nameLabel:SetHeight(LINE_HEIGHT)
    nameLabel:SetWidth(nameW)
    nameLabel:SetText(nameText)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetTextColor(0.847, 0.576, 0.929)
    button.nameLabel = nameLabel

    local noteLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteLabel:SetPoint("TOPLEFT", nameW + 8, 0)
    noteLabel:SetHeight(LINE_HEIGHT)
    noteLabel:SetWidth(noteW)
    noteLabel:SetText(noteText)
    noteLabel:SetJustifyH("LEFT")
    noteLabel:SetTextColor(1, 1, 1)
    button.noteLabel = noteLabel

    local authLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    authLabel:SetPoint("TOPLEFT", nameW + noteW + 16, 0)
    authLabel:SetHeight(LINE_HEIGHT)
    authLabel:SetWidth(authW)
    authLabel:SetText(authText)
    authLabel:SetJustifyH("LEFT")
    authLabel:SetTextColor(0.7, 0.9, 0.7)
    button.authLabel = authLabel

    local dateLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dateLabel:SetPoint("TOPLEFT", nameW + noteW + authW + 24, 0)
    dateLabel:SetHeight(LINE_HEIGHT)
    dateLabel:SetWidth(dateW)
    dateLabel:SetText(dateText)
    dateLabel:SetJustifyH("LEFT")
    local r, g, b = GetAgeColor(ageTimestamp)
    dateLabel:SetTextColor(r, g, b)
    button.dateLabel = dateLabel

    button:SetScript("OnClick", OnLineClick)
    button:SetScript("OnEnter", OnLineEnter)
    button:SetScript("OnLeave", OnLineLeave)

    lines[index + 1] = button
end

local SORT_NAME    = "name"
local SORT_UPDATED = "updated"
local SORT_AUTHOR  = "author"
local currentSort  = SORT_NAME
local currentFilter = ""

local function InitSortDropdown()
    UIDropDownMenu_Initialize(sortDropdown, function()
        local options = {
            { text = "Name (A-Z)",   value = SORT_NAME },
            { text = "Last Updated", value = SORT_UPDATED },
            { text = "Author",       value = SORT_AUTHOR },
        }
        for _, opt in ipairs(options) do
            local info = {}
            info.text    = opt.text
            info.value   = opt.value
            info.checked = (opt.value == currentSort)
            local optValue = opt.value
            local optText  = opt.text
            info.func = function()
                currentSort = optValue
                UIDropDownMenu_SetText(optText, sortDropdown)
                CloseDropDownMenus()
                PorkNotes.UpdateNotesFrame()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText("Name (A-Z)", sortDropdown)
end

local function RefreshNotes()
    local notes = PorkNotes.GetAllNotes()
    for _, line in ipairs(lines) do
        line:Hide()
    end

    if not notes then
        emptyLabel:SetText("No notes yet. Right-click a player to get started.")
        emptyLabel:Show()
        title:SetText("|cFFD893EDPork|r|cFFFFBB00Notes|r")
        content:SetHeight(60)
        scrollFrame:UpdateScrollChildRect()
        return
    end

    -- Build filtered list
    local filtered = {}
    local filter = string.lower(currentFilter)
    for playername, note in pairs(notes) do
        local match = true
        if filter ~= "" then
            local nameMatch = string.find(string.lower(playername), filter, 1, true)
            local noteMatch = note.text and string.find(string.lower(note.text), filter, 1, true)
            local authMatch = note.updatedBy and string.find(string.lower(note.updatedBy), filter, 1, true)
            match = nameMatch or noteMatch or authMatch
        end
        if match then
            table.insert(filtered, playername)
        end
    end

    local totalCount = 0
    for _ in pairs(notes) do totalCount = totalCount + 1 end

    if table.getn(filtered) == 0 then
        emptyLabel:SetText(currentFilter ~= "" and "No notes match your search." or "No notes yet. Right-click a player to get started.")
        emptyLabel:Show()
        title:SetText("|cFFD893EDPork|r|cFFFFBB00Notes|r |cFFAAAAAA(0)|r")
        content:SetHeight(60)
        scrollFrame:UpdateScrollChildRect()
        return
    end

    emptyLabel:Hide()

    -- Sort
    if currentSort == SORT_NAME then
        table.sort(filtered)
    elseif currentSort == SORT_UPDATED then
        table.sort(filtered, function(a, b)
            local aTime = notes[a].updated or notes[a].created or 0
            local bTime = notes[b].updated or notes[b].created or 0
            return aTime > bTime
        end)
    elseif currentSort == SORT_AUTHOR then
        table.sort(filtered, function(a, b)
            local aAuth = string.lower(notes[a].updatedBy or notes[a].createdBy or "")
            local bAuth = string.lower(notes[b].updatedBy or notes[b].createdBy or "")
            return aAuth < bAuth
        end)
    end

    -- Update title with count
    local displayCount = table.getn(filtered)
    if displayCount < totalCount then
        title:SetText("|cFFD893EDPork|r|cFFFFBB00Notes|r |cFFAAAAAA(" .. displayCount .. "/" .. totalCount .. ")|r")
    else
        title:SetText("|cFFD893EDPork|r|cFFFFBB00Notes|r |cFFAAAAAA(" .. totalCount .. ")|r")
    end

    local count = 0
    for _, playername in ipairs(filtered) do
        local note = notes[playername]
        local authText = note.updatedBy or note.createdBy or ""
        local ageTimestamp = note.updated or note.created
        local dateText = FormatDate(ageTimestamp)
        CreateLine(playername, note.text or "", authText, dateText, ageTimestamp, count)
        count = count + 1
    end

    content:SetHeight(count * LINE_HEIGHT + 4)
    ResizeEverything()
    scrollFrame:UpdateScrollChildRect()
end

-- Wire up search
searchBox:SetScript("OnTextChanged", function()
    currentFilter = searchBox:GetText()
    RefreshNotes()
end)
searchBox:SetScript("OnEscapePressed", function()
    searchBox:SetText("")
    currentFilter = ""
    RefreshNotes()
end)
clearButton:SetScript("OnClick", function()
    searchBox:SetText("")
    currentFilter = ""
    RefreshNotes()
end)

PorkNotes.ShowNotesFrame = function()
    InitSortDropdown()
    RefreshNotes()
    frame:ClearAllPoints()
    local saved = PorkNotes.GetSetting("NotesFramePos", nil)
    if saved then
        local _, _, point, relativePoint, x, y = string.find(saved, "([^,]+),([^,]+),(-?%d+),(-?%d+)")
        if point then
            frame:SetPoint(point, UIParent, relativePoint, tonumber(x), tonumber(y))
        else
            frame:SetPoint("CENTER", UIParent)
        end
    else
        frame:SetPoint("CENTER", UIParent)
    end
    frame:Show()
end

PorkNotes.UpdateNotesFrame = function()
    if frame:IsShown() then
        RefreshNotes()
    end
end
