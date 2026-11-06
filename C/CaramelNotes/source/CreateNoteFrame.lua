local frame = CreateFrame("Frame", "CaramelNotes_CreateNoteFrame", UIParent)
local editingPlayerName = nil

frame:SetWidth(300)
frame:SetHeight(140)
frame:SetFrameStrata("DIALOG")
frame:SetPoint("CENTER", UIParent, "CENTER")
frame:EnableMouse(true)
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

frame:SetScript("OnHide", function()
    PlaySound("igMainMenuClose")
end)

local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
label:SetPoint("TOP", 0, -15)
label:SetText("Creating new note")

local playerLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
playerLabel:SetPoint("TOPLEFT", 22, -43)
playerLabel:SetText("Character name:")

local playerEditBox = CreateFrame("EditBox", nil, frame)
playerEditBox:SetWidth(155)
playerEditBox:SetHeight(30)
playerEditBox:SetPoint("TOPRIGHT", -20, -35)
playerEditBox:SetAutoFocus(true)
playerEditBox:SetFontObject(GameFontNormal)
playerEditBox:SetMaxLetters(12)
playerEditBox:SetTextInsets(5, 5, 3, 3)
playerEditBox:SetTextColor(1, 1, 1)
playerEditBox:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
playerEditBox:SetBackdropColor(0, 0, 0, 0.5)

local textEditBox = CreateFrame("EditBox", nil, frame)
textEditBox:SetWidth(260)
textEditBox:SetHeight(30)
textEditBox:SetPoint("TOP", 0, -65)
textEditBox:SetAutoFocus(true)
textEditBox:SetFontObject(GameFontNormal)
textEditBox:SetTextInsets(5, 5, 3, 3)
textEditBox:SetTextColor(1, 1, 1)
textEditBox:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
textEditBox:SetBackdropColor(0, 0, 0, 0.5)

local submitButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
submitButton:SetWidth(100)
submitButton:SetHeight(24)
submitButton:SetPoint("BOTTOM", -50, 15)
submitButton:SetText("OK")

local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
cancelButton:SetWidth(100)
cancelButton:SetHeight(24)
cancelButton:SetPoint("BOTTOM", 50, 15)
cancelButton:SetText("Cancel")
cancelButton:SetScript("OnClick", function()
    frame:Hide()
end)

local function OnSubmit()
    local playerName = playerEditBox:GetText()
    if playerName and playerName ~= "" then
        local text = textEditBox:GetText()
        CaramelNotes.SetPlayerNote(playerName, text)
        CaramelNotes.UpdateNotesFrame()
    end
    frame:Hide()
end

local function OnEscape()
    frame:Hide()
end

playerEditBox:SetScript("OnEnterPressed", function ()
    local playerName = playerEditBox:GetText()
    if playerName and playerName ~= "" then
        textEditBox:SetFocus()
    end
end)
playerEditBox:SetScript("OnEscapePressed", OnEscape)
playerEditBox:SetScript("OnTabPressed", function ()
    textEditBox:SetFocus()
end)
playerEditBox:SetScript("OnTextChanged", function ()
    local text = playerEditBox:GetText()
    if text and text ~= "" then
        local firstLetter = string.sub(text, 1, 1)
        local remainingLetters = string.sub(text, 2)
        local capitalized = string.upper(firstLetter) .. string.lower(remainingLetters)
        local cleaned = string.gsub(capitalized, "[^A-Za-z]", "")
        if text ~= cleaned then
            playerEditBox:SetText(cleaned)
        end
    end
end)

textEditBox:SetScript("OnEnterPressed", OnSubmit)
textEditBox:SetScript("OnEscapePressed", OnEscape)
textEditBox:SetScript("OnTabPressed", function ()
    playerEditBox:SetFocus()
end)

textEditBox:SetScript("OnEditFocusGained", function ()
    local playerName = playerEditBox:GetText()
    local noteText = textEditBox:GetText()
    if playerName and playerName ~= "" and (noteText == nil or noteText == "") then
        local note = CaramelNotes.GetPlayerNote(playerName)
        if note then
            textEditBox:SetText(note.text)
        end
    end
end)

submitButton:SetScript("OnClick", OnSubmit)

CaramelNotes.ShowCreateFrame = function ()
    playerEditBox:SetText("")
    textEditBox:SetText("")
    frame:Show()
end
