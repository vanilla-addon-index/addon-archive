local frame = CreateFrame("Frame", "CaramelNotes_NotesFrame", UIParent)
frame:SetWidth(600)
frame:SetHeight(450)
frame:SetPoint("CENTER", UIParent)
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetResizable(true)
frame:SetMinResize(400, 300)
frame:SetMaxResize(800, 600)
frame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
frame:SetBackdropColor(0, 0, 0, 0.8)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -15)
title:SetText("|cFFCA4020Caramel|rNotes")

local resizer = CreateFrame("Button", nil, frame)
resizer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 5)
resizer:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Corner")
resizer:SetWidth(16)
resizer:SetHeight(16)
resizer:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
resizer:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

-- Makes the window closable by pressing Escape.
tinsert(UISpecialFrames, frame:GetName())

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

local createNoteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
createNoteButton:SetWidth(100)
createNoteButton:SetHeight(24)
createNoteButton:SetPoint("BOTTOMLEFT", 30, 20)
createNoteButton:SetText("New note")
createNoteButton:SetScript("OnClick", function()
    CaramelNotes.ShowCreateFrame()
end)

local settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
settingsButton:SetWidth(100)
settingsButton:SetHeight(24)
settingsButton:SetPoint("BOTTOMRIGHT", -30, 20)
settingsButton:SetText("Settings")
settingsButton:SetScript("OnClick", function()
    frame:Hide()
    CaramelNotes.ShowSettingsFrame()
end)

local scrollContainer = CreateFrame("Frame", nil, frame)
scrollContainer:SetPoint("TOPLEFT", frame, 30, -30)
scrollContainer:SetPoint("BOTTOMRIGHT", frame, -30, 48)
scrollContainer:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
scrollContainer:SetBackdropColor(0, 0, 0, 0.4)

local scrollFrame = CreateFrame("ScrollFrame", "CaramelNotes_ShowNotes_ScrollFrame", scrollContainer, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", scrollContainer, 10, -10)
scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, -30, 10)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetWidth(1)
scrollFrame:SetScrollChild(content)

local lines = {}

local LINE_HEIGHT = 20

local function ResizeEverything()
    local lineWidth = frame:GetWidth() - 100
    local leftColumnWidth = 70 / 400 * frame:GetWidth()
    local rightColumnWidth = lineWidth - 20 - leftColumnWidth
    for _, line in ipairs(lines) do
        line:SetWidth(lineWidth)
        line.leftLabel:SetWidth(leftColumnWidth)
        line.rightLabel:SetWidth(rightColumnWidth)
        line.rightLabel:SetPoint("TOPLEFT", leftColumnWidth + 20, 0)
        line.bottomLabel:SetWidth(rightColumnWidth)
        line.bottomLabel:SetPoint("TOPLEFT", leftColumnWidth + 20, -LINE_HEIGHT)
    end
end

frame:SetScript("OnSizeChanged", ResizeEverything)

local measureString = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
measureString:Hide()

local function IsTruncated(label)
    measureString:SetText(label:GetText())
    local fullTextWidth = measureString:GetStringWidth()
    local currentWidth = label:GetStringWidth()
    return fullTextWidth > currentWidth
end

local rightClickMenu = CreateFrame("Frame", "CaramelNotes_ShowNotes_RightClickMenu", UIParent)
local currentPlayerName = nil
rightClickMenu:SetFrameStrata("DIALOG")
rightClickMenu:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
rightClickMenu:SetBackdropColor(0, 0, 0, 0.9)
rightClickMenu:SetWidth(140)
rightClickMenu:SetHeight(80)
rightClickMenu:EnableMouse(true)
rightClickMenu:Hide()

rightClickMenu:SetScript("OnShow", function()
    PlaySound("igMainMenuOpen")
end)

rightClickMenu:SetScript("OnLeave", function()
    local frameUnderMouse = GetMouseFocus()
    if frameUnderMouse then
        local parent = frameUnderMouse:GetParent()
        if parent == rightClickMenu then
            return
        end
    end
    rightClickMenu:Hide()
end)

function EditNoteClicked()
    CaramelNotes.ShowEditFrame(currentPlayerName)
    rightClickMenu:Hide()
end

function DeleteNoteClicked()
    CaramelNotes.SetPlayerNote(currentPlayerName, "")
    CaramelNotes.UpdateNotesFrame()
    rightClickMenu:Hide()
    PlaySound("igMainMenuClose")
end

local menuTitle = rightClickMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
menuTitle:SetPoint("TOP", 0, -10)

local menuEditNoteButton = CreateFrame("Button", nil, rightClickMenu)
menuEditNoteButton:SetWidth(120)
menuEditNoteButton:SetHeight(20)
menuEditNoteButton:SetPoint("TOPLEFT", rightClickMenu, "TOPLEFT", 10, -30)
menuEditNoteButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
menuEditNoteButton:SetScript("OnClick", EditNoteClicked)

menuEditNoteButton.text = menuEditNoteButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
menuEditNoteButton.text:SetAllPoints()
menuEditNoteButton.text:SetText("Edit note")
menuEditNoteButton.text:SetJustifyH("LEFT")
menuEditNoteButton.text:SetTextColor(1, 1, 1)

local menuDeleteNoteButton = CreateFrame("Button", nil, rightClickMenu)
menuDeleteNoteButton:SetWidth(120)
menuDeleteNoteButton:SetHeight(20)
menuDeleteNoteButton:SetPoint("TOPLEFT", rightClickMenu, "TOPLEFT", 10, -50)
menuDeleteNoteButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
menuDeleteNoteButton:SetScript("OnClick", DeleteNoteClicked)

menuDeleteNoteButton.text = menuDeleteNoteButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
menuDeleteNoteButton.text:SetAllPoints()
menuDeleteNoteButton.text:SetText("Delete note")
menuDeleteNoteButton.text:SetJustifyH("LEFT")
menuDeleteNoteButton.text:SetTextColor(1, 0.2, 0.2)

local function OpenRightClickMenu(playername)
    currentPlayerName = playername
    menuTitle:SetText(playername)

    local x, y = GetCursorPosition()
    x = x - 10
    y = y + 10

    local scale = UIParent:GetEffectiveScale()
    rightClickMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x/scale, y/scale)
    rightClickMenu:Show()
end

frame:SetScript("OnShow", function()
    PlaySound("igQuestListOpen")
end)

frame:SetScript("OnHide", function()
    PlaySound("igQuestListClose")
    rightClickMenu:Hide()
end)

local function OnLineClick()
    if arg1 == "LeftButton" then
        CaramelNotes.ShowEditFrame(this.leftLabel:GetText())
    else
        OpenRightClickMenu(this.leftLabel:GetText())
    end
end

local function OnLineEnter()
    this.bg:SetVertexColor(0.5, 0.5, 0.5, 0.5)
    if IsTruncated(this.leftLabel) or IsTruncated(this.rightLabel) or IsTruncated(this.bottomLabel) then
        GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(this.leftLabel:GetText(), 1, 1, 1)
        GameTooltip:AddLine(this.rightLabel:GetText(), 0.9, 0.9, 0.9)
        if this.bottomLabel:GetText() then
            GameTooltip:AddLine(this.bottomLabel:GetText(), 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end
end

local function OnLineLeave()
    this.bg:SetVertexColor(1, 1, 1, this.bgAlpha)
    GameTooltip:Hide()
end

local math_mod = math.mod or math.fmod

local function CreateLine(leftText, rightText, bottomText, index)
    local lineHeight = LINE_HEIGHT
    if bottomText then
        lineHeight = LINE_HEIGHT * 2
    end

    local position = 0
    if index > 0 then
        local _, _, _, _, offsetY = lines[index]:GetPoint()
        position = -offsetY + lines[index]:GetHeight()
    end

    if lines[index + 1] then
        -- Frame already exists, reuse it.
        lines[index + 1]:SetHeight(lineHeight)
        lines[index + 1]:SetPoint("TOPLEFT", 0, -position)
        lines[index + 1].leftLabel:SetHeight(lineHeight)
        lines[index + 1].leftLabel:SetText(leftText)
        lines[index + 1].rightLabel:SetText(rightText)
        lines[index + 1].bottomLabel:SetText(bottomText)
        if bottomText then
            lines[index + 1].bottomLabel:SetHeight(LINE_HEIGHT)
        else
            lines[index + 1].bottomLabel:SetHeight(0)
        end
        lines[index + 1]:Show()
        return
    end

    local button = CreateFrame("Button", nil, content)
    button:SetHeight(lineHeight)
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

    local leftLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftLabel:SetPoint("TOPLEFT", 0, 0)
    leftLabel:SetHeight(lineHeight)
    leftLabel:SetText(leftText)
    leftLabel:SetJustifyH("LEFT")
    leftLabel:SetTextColor(1, 1, 1)
    button.leftLabel = leftLabel

    local rightLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightLabel:SetPoint("TOPLEFT", 100, 0)
    rightLabel:SetHeight(LINE_HEIGHT)
    rightLabel:SetText(rightText)
    rightLabel:SetJustifyH("LEFT")
    rightLabel:SetTextColor(1, 1, 1)
    button.rightLabel = rightLabel

    local bottomLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bottomLabel:SetPoint("TOPLEFT", 100, -LINE_HEIGHT)
    if bottomText then
        bottomLabel:SetHeight(LINE_HEIGHT)
    else
        bottomLabel:SetHeight(0)
    end
    bottomLabel:SetText(bottomText)
    bottomLabel:SetJustifyH("LEFT")
    bottomLabel:SetTextColor(0.7, 0.7, 0.7)
    button.bottomLabel = bottomLabel

    button:SetScript("OnClick", OnLineClick)
    button:SetScript("OnEnter", OnLineEnter)
    button:SetScript("OnLeave", OnLineLeave)

    lines[index + 1] = button
end

local function RefreshNotes()
    local notes = CaramelNotes.GetAllNotes()
    for _, line in ipairs(lines) do
        line:Hide()
    end

    local sortedNames = {}
    for playername, _ in pairs(notes) do
        table.insert(sortedNames, playername)
    end
    table.sort(sortedNames)

    local count = 0
    for _, playername in ipairs(sortedNames) do
        local note = notes[playername]
        local bottomText = nil

        local showCreatedBy = CaramelNotes.GetSetting("NotesShowCreatedBy", false)
        local showCreatedAtZone = CaramelNotes.GetSetting("NotesShowCreatedAtZone", false)

        if showCreatedBy and showCreatedAtZone and note.createdBy and note.createdAtZone then
            bottomText = "-- " .. note.createdBy .. " (" .. note.createdAtZone .. ")"
        elseif showCreatedBy and note.createdBy then
            bottomText = "-- " .. note.createdBy
        elseif showCreatedAtZone and note.createdAtZone then
            bottomText = "-- " .. note.createdAtZone
        end

        CreateLine(playername, note.text, bottomText, count)
        count = count + 1
    end
    content:SetHeight(count * 14)
    ResizeEverything()
    scrollFrame:UpdateScrollChildRect()
end

CaramelNotes.ShowNotesFrame = function ()
    RefreshNotes()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent)
    frame:Show()
end

CaramelNotes.UpdateNotesFrame = function ()
    if frame:IsShown() then
        RefreshNotes()
    end
end
