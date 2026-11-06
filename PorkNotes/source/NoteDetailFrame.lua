local COLLAPSED_HEIGHT = 255
local EXPANDED_HEIGHT = 455

local frame = CreateFrame("Frame", "PorkNotes_NoteDetailFrame", UIParent)
frame:SetWidth(380)
frame:SetHeight(COLLAPSED_HEIGHT)
frame:SetFrameStrata("DIALOG")
frame:SetPoint("CENTER", UIParent, "CENTER")
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint()
    PorkNotes.SetSetting("NoteDetailFramePos", point .. "," .. relativePoint .. "," .. math.floor(x) .. "," .. math.floor(y))
end)
frame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
frame:SetBackdropColor(0, 0, 0, 0.8)
frame:Hide()

frame:SetScript("OnShow", function()
    PlaySound("igMainMenuOpen")
end)

tinsert(UISpecialFrames, frame:GetName())

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

-- Title
local titleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleLabel:SetPoint("TOP", 0, -15)
titleLabel:SetTextColor(1, 1, 1)

-- Note text display (view mode)
local noteLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
noteLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
noteLabel:SetWidth(340)
noteLabel:SetJustifyH("LEFT")
noteLabel:SetTextColor(1, 1, 0)

-- Note text editbox (edit mode)
local editBox = CreateFrame("EditBox", nil, frame)
editBox:SetWidth(300)
editBox:SetHeight(30)
editBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -36)
editBox:SetFontObject(GameFontNormal)
editBox:SetMaxLetters(150)
editBox:SetTextInsets(5, 5, 3, 3)
editBox:SetTextColor(1, 1, 1)
editBox:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
editBox:SetBackdropColor(0, 0, 0, 0.5)
editBox:Hide()

-- Character counter
local charCounter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
charCounter:SetPoint("TOPRIGHT", editBox, "BOTTOMRIGHT", 0, -1)
charCounter:SetTextColor(0.6, 0.6, 0.6)
charCounter:Hide()

editBox:SetScript("OnTextChanged", function()
    local current = string.len(editBox:GetText())
    charCounter:SetText(current .. " / 150")
    if current >= 130 then
        charCounter:SetTextColor(1, 0.3, 0.3)
    else
        charCounter:SetTextColor(0.6, 0.6, 0.6)
    end
end)

-- Divider
local divider = frame:CreateTexture(nil, "BACKGROUND")
divider:SetHeight(1)
divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -78)
divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -78)
divider:SetTexture(0.3, 0.3, 0.3, 0.8)

-- Metadata labels
local function CreateMetaLabel(yOffset)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    label:SetWidth(340)
    label:SetJustifyH("LEFT")
    label:SetTextColor(1, 1, 1)
    return label
end

local createdByLabel   = CreateMetaLabel(-90)
local createdDateLabel = CreateMetaLabel(-104)
local createdZoneLabel = CreateMetaLabel(-118)
local updatedByLabel   = CreateMetaLabel(-136)
local updatedDateLabel = CreateMetaLabel(-150)

local function MetaText(label, value)
    return "|cFFD893ED" .. label .. ":|r " .. (value or "unknown")
end

-- History divider
local historyDivider = frame:CreateTexture(nil, "BACKGROUND")
historyDivider:SetHeight(1)
historyDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -168)
historyDivider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -168)
historyDivider:SetTexture(0.3, 0.3, 0.3, 0.8)

-- History toggle button
local historyToggle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
historyToggle:SetWidth(120)
historyToggle:SetHeight(20)
historyToggle:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -175)
historyToggle:SetText("Show history ▼")

-- History scroll container
local historyContainer = CreateFrame("Frame", nil, frame)
historyContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -202)
historyContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -202)
historyContainer:SetHeight(210)
historyContainer:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
historyContainer:SetBackdropColor(0, 0, 0, 0.4)
historyContainer:Hide()

local historyScroll = CreateFrame("ScrollFrame", "PorkNotes_NoteDetailHistory_ScrollFrame", historyContainer, "UIPanelScrollFrameTemplate")
historyScroll:SetPoint("TOPLEFT", historyContainer, 6, -6)
historyScroll:SetPoint("BOTTOMRIGHT", historyContainer, -26, 6)

local historyContent = CreateFrame("Frame", nil, historyScroll)
historyContent:SetWidth(1)
historyScroll:SetScrollChild(historyContent)

-- Bottom buttons — view mode
local editButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
editButton:SetWidth(70)
editButton:SetHeight(24)
editButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 15)
editButton:SetText("Edit")

local deleteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
deleteButton:SetWidth(70)
deleteButton:SetHeight(24)
deleteButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 98, 15)
deleteButton:SetText("Delete")

-- State - declared early so share menu closures can read it
local currentPlayerName = nil

-- Share dropdown button
local shareButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
shareButton:SetWidth(70)
shareButton:SetHeight(24)
shareButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 176, 15)
shareButton:SetText("Share ▼")

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
closeBtn:SetWidth(70)
closeBtn:SetHeight(24)
closeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 15)
closeBtn:SetText("Close")

-- Bottom buttons — edit mode
local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
saveButton:SetWidth(80)
saveButton:SetHeight(24)
saveButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 15)
saveButton:SetText("Save")
saveButton:Hide()

local cancelEditButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
cancelEditButton:SetWidth(80)
cancelEditButton:SetHeight(24)
cancelEditButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 110, 15)
cancelEditButton:SetText("Cancel")
cancelEditButton:Hide()

-- Bottom buttons — delete confirm mode
local confirmDeleteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
confirmDeleteButton:SetWidth(100)
confirmDeleteButton:SetHeight(24)
confirmDeleteButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 15)
confirmDeleteButton:SetText("Yes, delete")
confirmDeleteButton:Hide()

local cancelDeleteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
cancelDeleteButton:SetWidth(80)
cancelDeleteButton:SetHeight(24)
cancelDeleteButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 130, 15)
cancelDeleteButton:SetText("Cancel")
cancelDeleteButton:Hide()

local deletePromptLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
deletePromptLabel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 22)
deletePromptLabel:SetTextColor(1, 0.3, 0.3)
deletePromptLabel:SetText("Delete this note?")
deletePromptLabel:Hide()

-- Bottom buttons — discard confirm mode
local confirmDiscardButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
confirmDiscardButton:SetWidth(100)
confirmDiscardButton:SetHeight(24)
confirmDiscardButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 15)
confirmDiscardButton:SetText("Discard")
confirmDiscardButton:Hide()

local cancelDiscardButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
cancelDiscardButton:SetWidth(80)
cancelDiscardButton:SetHeight(24)
cancelDiscardButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 130, 15)
cancelDiscardButton:SetText("Keep editing")
cancelDiscardButton:Hide()

local discardPromptLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
discardPromptLabel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 22)
discardPromptLabel:SetTextColor(1, 0.6, 0.2)
discardPromptLabel:SetText("Discard changes?")
discardPromptLabel:Hide()

-- Share dropdown
local shareDropdown = CreateFrame("Frame", "PorkNotes_NoteDetailShareDropdown", UIParent, "UIDropDownMenuTemplate")

local function OpenShareDropdown()
    if not currentPlayerName then return end
    UIDropDownMenu_Initialize(shareDropdown, function()
        local options = {
            { text = "Party",        channel = "PARTY"        },
            { text = "Raid",         channel = "RAID"         },
            { text = "Guild",        channel = "GUILD"        },
            { text = "Battleground", channel = "BATTLEGROUND" },
        }
        for _, opt in ipairs(options) do
            local info = {}
            info.text = opt.text
            info.notCheckable = 1
            local ch = opt.channel
            local name = currentPlayerName
            info.func = function()
                CloseDropDownMenus()
                PorkNotes.SyncNote(name, ch)
            end
            UIDropDownMenu_AddButton(info)
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, shareDropdown, "cursor", 0, 0)
end

shareButton:SetScript("OnClick", function()
    OpenShareDropdown()
end)

shareButton:SetScript("OnClick", function()
    OpenShareDropdown()
end)

-- State
local isEditMode = false
local isHistoryExpanded = false
local historyLines = {}

local function FormatDate(timestamp)
    if not timestamp then return "unknown" end
    return date("%Y-%m-%d", timestamp)
end

local function RefreshMetadata()
    local note = PorkNotes.GetPlayerNote(currentPlayerName)
    if not note then return end
    createdByLabel:SetText(MetaText("Created by", note.createdBy))
    createdDateLabel:SetText(MetaText("Created on", FormatDate(note.created)))
    createdZoneLabel:SetText(MetaText("Created in", note.createdAtZone))
    if note.updatedBy then
        updatedByLabel:SetText(MetaText("Updated by", note.updatedBy))
        updatedDateLabel:SetText(MetaText("Updated on", FormatDate(note.updated)))
    else
        updatedByLabel:SetText("")
        updatedDateLabel:SetText("")
    end
end

local function RefreshHistory()
    for _, line in ipairs(historyLines) do
        line:Hide()
    end
    historyLines = {}

    local note = PorkNotes.GetPlayerNote(currentPlayerName)
    if not note or not note.history or table.getn(note.history) == 0 then
        local emptyLabel = historyContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        emptyLabel:SetPoint("TOPLEFT", 4, -4)
        emptyLabel:SetTextColor(0.6, 0.6, 0.6)
        emptyLabel:SetText("No history yet.")
        table.insert(historyLines, emptyLabel)
        historyContent:SetHeight(20)
        historyScroll:UpdateScrollChildRect()
        return
    end

    local totalHeight = 0
    local count = table.getn(note.history)
    for i = count, 1, -1 do
        local entry = note.history[i]
        local yPos = -totalHeight - 4

        local dateLine = historyContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dateLine:SetPoint("TOPLEFT", 4, yPos)
        dateLine:SetWidth(300)
        dateLine:SetJustifyH("LEFT")
        if entry.source == "sync" then
            dateLine:SetTextColor(0.4, 0.8, 1)
            dateLine:SetText("Synced from " .. (entry.editedBy or "unknown") .. " — " .. FormatDate(entry.authorAt or entry.editedAt))
        else
            dateLine:SetTextColor(0.7, 0.7, 1)
            dateLine:SetText("Written by " .. (entry.authorBy or entry.editedBy or "unknown") .. " — " .. FormatDate(entry.authorAt or entry.editedAt))
        end
        table.insert(historyLines, dateLine)
        totalHeight = totalHeight + 14

        local textLine = historyContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        textLine:SetPoint("TOPLEFT", 4, -totalHeight - 4)
        textLine:SetWidth(300)
        textLine:SetJustifyH("LEFT")
        textLine:SetTextColor(0.9, 0.9, 0.9)
        textLine:SetText(entry.text or "")
        table.insert(historyLines, textLine)
        totalHeight = totalHeight + 18

        if i > 1 then
            local sep = historyContent:CreateTexture(nil, "BACKGROUND")
            sep:SetHeight(1)
            sep:SetPoint("TOPLEFT", 0, -totalHeight - 4)
            sep:SetPoint("TOPRIGHT", historyContent, "TOPRIGHT", 0, -totalHeight - 4)
            sep:SetTexture(0.2, 0.2, 0.2, 0.8)
            table.insert(historyLines, sep)
            totalHeight = totalHeight + 8
        end
    end

    historyContent:SetHeight(totalHeight + 8)
    historyScroll:UpdateScrollChildRect()
end

local function CollapseHistory()
    isHistoryExpanded = false
    historyContainer:Hide()
    frame:SetHeight(COLLAPSED_HEIGHT)
    historyToggle:SetText("Show history ▼")
end

local function ExpandHistory()
    isHistoryExpanded = true
    RefreshHistory()
    historyContainer:Show()
    frame:SetHeight(EXPANDED_HEIGHT)
    historyToggle:SetText("Hide history ▲")
end

historyToggle:SetScript("OnClick", function()
    if isHistoryExpanded then CollapseHistory() else ExpandHistory() end
end)

local function HasUnsavedChanges()
    local note = PorkNotes.GetPlayerNote(currentPlayerName)
    local savedText = note and note.text or ""
    return editBox:GetText() ~= savedText
end

local function SetEmptyState()
    -- Display empty state when there's no note for this player
    isEditMode = false
    noteLabel:SetText("|cffaaaaaa(No note yet for " .. currentPlayerName .. "). Click Edit to create one.|r")
    noteLabel:Show()
    editBox:Hide()
    charCounter:Hide()
    editButton:Show()
    deleteButton:Hide()
    shareButton:Hide()
    saveButton:Hide()
    cancelEditButton:Hide()
    confirmDeleteButton:Hide()
    cancelDeleteButton:Hide()
    deletePromptLabel:Hide()
    confirmDiscardButton:Hide()
    cancelDiscardButton:Hide()
    discardPromptLabel:Hide()
    closeBtn:Show()
end

local function SetViewMode()
    isEditMode = false
    local note = PorkNotes.GetPlayerNote(currentPlayerName)
    
    -- Check if note is empty and show empty state
    if not note or not note.text or note.text == "" then
        SetEmptyState()
        return
    end
    
    noteLabel:SetText(note.text)
    noteLabel:Show()
    editBox:Hide()
    charCounter:Hide()
    editButton:Show()
    deleteButton:Show()
    shareButton:Show()
    saveButton:Hide()
    cancelEditButton:Hide()
    confirmDeleteButton:Hide()
    cancelDeleteButton:Hide()
    deletePromptLabel:Hide()
    confirmDiscardButton:Hide()
    cancelDiscardButton:Hide()
    discardPromptLabel:Hide()
    closeBtn:Show()
end

local function SetEditMode()
    isEditMode = true
    local note = PorkNotes.GetPlayerNote(currentPlayerName)
    editBox:SetText(note and note.text or "")
    editBox:SetFocus()
    local current = string.len(editBox:GetText())
    charCounter:SetText(current .. " / 150")
    noteLabel:Hide()
    editBox:Show()
    charCounter:Show()
    editButton:Hide()
    deleteButton:Hide()
    shareButton:Hide()
    saveButton:Show()
    cancelEditButton:Show()
    confirmDeleteButton:Hide()
    cancelDeleteButton:Hide()
    deletePromptLabel:Hide()
    confirmDiscardButton:Hide()
    cancelDiscardButton:Hide()
    discardPromptLabel:Hide()
    closeBtn:Hide()
end

local function SetDeleteConfirmMode()
    editButton:Hide()
    deleteButton:Hide()
    shareButton:Hide()
    saveButton:Hide()
    cancelEditButton:Hide()
    confirmDeleteButton:Show()
    cancelDeleteButton:Show()
    deletePromptLabel:Show()
    confirmDiscardButton:Hide()
    cancelDiscardButton:Hide()
    discardPromptLabel:Hide()
    closeBtn:Hide()
end

local function SetDiscardConfirmMode()
    editButton:Hide()
    deleteButton:Hide()
    shareButton:Hide()
    saveButton:Hide()
    cancelEditButton:Hide()
    confirmDeleteButton:Hide()
    cancelDeleteButton:Hide()
    deletePromptLabel:Hide()
    confirmDiscardButton:Show()
    cancelDiscardButton:Show()
    discardPromptLabel:Show()
    closeBtn:Hide()
end

local function SaveAndReturn()
    PorkNotes.SetPlayerNote(currentPlayerName, editBox:GetText())
    PorkNotes.UpdateNotesFrame()
    SetViewMode()
    RefreshMetadata()
    if isHistoryExpanded then RefreshHistory() end
end

editButton:SetScript("OnClick", SetEditMode)

cancelEditButton:SetScript("OnClick", function()
    if HasUnsavedChanges() then SetDiscardConfirmMode() else SetViewMode() end
end)

editBox:SetScript("OnEscapePressed", function()
    if HasUnsavedChanges() then SetDiscardConfirmMode() else SetViewMode() end
end)

saveButton:SetScript("OnClick", SaveAndReturn)
editBox:SetScript("OnEnterPressed", SaveAndReturn)

deleteButton:SetScript("OnClick", SetDeleteConfirmMode)
cancelDeleteButton:SetScript("OnClick", SetViewMode)

confirmDeleteButton:SetScript("OnClick", function()
    PorkNotes.SetPlayerNote(currentPlayerName, "")
    PorkNotes.UpdateNotesFrame()
    frame:Hide()
end)

confirmDiscardButton:SetScript("OnClick", SetViewMode)
cancelDiscardButton:SetScript("OnClick", function()
    SetEditMode()
end)

closeBtn:SetScript("OnClick", function()
    frame:Hide()
end)

closeButton:SetScript("OnClick", function()
    if isEditMode and HasUnsavedChanges() then
        SetDiscardConfirmMode()
    else
        frame:Hide()
    end
end)

frame:SetScript("OnHide", function()
    PlaySound("igMainMenuClose")
    CloseDropDownMenus()
end)

-- Public API
PorkNotes.ShowNoteDetailFrame = function(playername)
    currentPlayerName = playername
    titleLabel:SetText("|cFFD893EDPork|r|cFFFFBB00Notes|r - " .. playername)
    CollapseHistory()
    SetViewMode()
    RefreshMetadata()
    frame:ClearAllPoints()
    local saved = PorkNotes.GetSetting("NoteDetailFramePos", nil)
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
