local frame = CreateFrame("Frame", "CaramelNotes_EditNoteFrame", UIParent)
local editingPlayerName = nil

frame:SetWidth(300)
frame:SetHeight(100)
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
label:SetText("Editing note:")

local editBox = CreateFrame("EditBox", nil, frame)
editBox:SetWidth(260)
editBox:SetHeight(30)
editBox:SetPoint("TOP", 0, -30)
editBox:SetAutoFocus(true)
editBox:SetFontObject(GameFontNormal)
editBox:SetTextInsets(5, 5, 3, 3)
editBox:SetTextColor(1, 1, 1)
editBox:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
editBox:SetBackdropColor(0, 0, 0, 0.5)

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
    if editingPlayerName then
        local text = editBox:GetText()
        CaramelNotes.SetPlayerNote(editingPlayerName, text)
        CaramelNotes.UpdateNotesFrame()
    end
    frame:Hide()
end

local function OnEscape()
    frame:Hide()
end

submitButton:SetScript("OnClick", OnSubmit)
editBox:SetScript("OnEnterPressed", OnSubmit)
editBox:SetScript("OnEscapePressed", OnEscape)

CaramelNotes.ShowEditFrame = function (playername)
    local note = CaramelNotes.GetPlayerNote(playername)
    editingPlayerName = playername
    label:SetText("Editing note for " .. playername .. ":")
    if note then
        editBox:SetText(note.text)
    else
        editBox:SetText("")
    end
    frame:Show()
end
