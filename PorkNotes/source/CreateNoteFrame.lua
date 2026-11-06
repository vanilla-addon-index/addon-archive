local frame = CreateFrame("Frame", "PorkNotes_CreateNoteFrame", UIParent)
local editingPlayerName = nil

frame:SetWidth(300)
frame:SetHeight(175)
frame:SetFrameStrata("DIALOG")
frame:SetPoint("CENTER", UIParent, "CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint()
    PorkNotes.SetSetting("CreateNoteFramePos", point .. "," .. relativePoint .. "," .. math.floor(x) .. "," .. math.floor(y))
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

frame:SetScript("OnHide", function()
    PlaySound("igMainMenuClose")
end)

-- Title
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -15)
title:SetText("|cFFD893EDPork|r|cFFFFBB00Notes|r - New Note")

-- Player name label and editbox
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

-- Player name counter
local playerCounter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
playerCounter:SetPoint("TOPRIGHT", playerEditBox, "BOTTOMRIGHT", 0, -1)
playerCounter:SetText("0 / 12")
playerCounter:SetTextColor(0.6, 0.6, 0.6)

-- Duplicate warning label (shown when player name matches existing note)
-- Position below the counter, in the left area
local duplicateWarning = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
duplicateWarning:SetPoint("TOPLEFT", 22, -65)
duplicateWarning:SetTextColor(1, 0.6, 0)
duplicateWarning:SetText("|cffff9900⚠ Note already exists for this player|r")
duplicateWarning:Hide()

-- Note text editbox (moved up so it's defined before playerEditBox script uses it)
local textEditBox = CreateFrame("EditBox", nil, frame)
textEditBox:SetWidth(260)
textEditBox:SetHeight(30)
textEditBox:SetPoint("TOP", 0, -82)
textEditBox:SetAutoFocus(false)
textEditBox:SetFontObject(GameFontNormal)
textEditBox:SetMaxLetters(150)
textEditBox:SetTextInsets(5, 5, 3, 3)
textEditBox:SetTextColor(1, 1, 1)
textEditBox:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
textEditBox:SetBackdropColor(0, 0, 0, 0.5)

-- Note text counter
local textCounter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
textCounter:SetPoint("TOPRIGHT", textEditBox, "BOTTOMRIGHT", 0, -1)
textCounter:SetText("0 / 150")
textCounter:SetTextColor(0.6, 0.6, 0.6)

textEditBox:SetScript("OnTextChanged", function()
    local current = string.len(textEditBox:GetText())
    textCounter:SetText(current .. " / 150")
    if current >= 130 then
        textCounter:SetTextColor(1, 0.3, 0.3)
    else
        textCounter:SetTextColor(0.6, 0.6, 0.6)
    end
end)


playerEditBox:SetScript("OnTextChanged", function()
    local text = playerEditBox:GetText()
    -- Auto-capitalize and clean
    if text and text ~= "" then
        local firstLetter = string.sub(text, 1, 1)
        local remainingLetters = string.sub(text, 2)
        local capitalized = string.upper(firstLetter) .. string.lower(remainingLetters)
        local cleaned = string.gsub(capitalized, "[^A-Za-z]", "")
        if text ~= cleaned then
            playerEditBox:SetText(cleaned)
            return
        end
    end
    -- Update counter and check for duplicate
    local current = string.len(playerEditBox:GetText())
    playerCounter:SetText(current .. " / 12")
    if current >= 10 then
        playerCounter:SetTextColor(1, 0.3, 0.3)
    else
        playerCounter:SetTextColor(0.6, 0.6, 0.6)
    end
    
    -- Check if note already exists for this player
    if current > 0 then
        local existingNote = PorkNotes.GetPlayerNote(text)
        if existingNote then
            duplicateWarning:Show()
            playerEditBox:SetBackdropColor(0.3, 0.3, 0)  -- Dark yellow tint
            -- Auto-fill the note text with existing note
            textEditBox:SetText(existingNote.text or "")
            local textLen = string.len(textEditBox:GetText())
            textCounter:SetText(textLen .. " / 150")
        else
            duplicateWarning:Hide()
            playerEditBox:SetBackdropColor(0, 0, 0, 0.5)  -- Normal color
        end
    else
        duplicateWarning:Hide()
        playerEditBox:SetBackdropColor(0, 0, 0, 0.5)
    end
end)

-- Buttons
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
    if not playerName or playerName == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r Please enter a character name.")
        return
    end
    
    local text = textEditBox:GetText()
    local existingNote = PorkNotes.GetPlayerNote(playerName)
    
    -- If note exists, show confirmation dialog
    if existingNote then
        local existingText = existingNote.text or "(empty)"
        local dialogText = "Update |cffffcc00" .. playerName .. "|r's note?\n\nCurrent note: |cffffff00" .. existingText .. "|r"
        
        StaticPopupDialogs["PORKNOTES_CONFIRM_OVERWRITE"] = {
            text = dialogText,
            button1 = "Update",
            button2 = "Cancel",
            OnAccept = function()
                PorkNotes.SetPlayerNote(playerName, text)
                PorkNotes.UpdateNotesFrame()
                frame:Hide()
            end,
            OnCancel = function()
                -- Stay in frame
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("PORKNOTES_CONFIRM_OVERWRITE")
    else
        -- New note, create directly
        PorkNotes.SetPlayerNote(playerName, text)
        PorkNotes.UpdateNotesFrame()
        frame:Hide()
    end
end

local function OnEscape()
    frame:Hide()
end

playerEditBox:SetScript("OnEnterPressed", function()
    local playerName = playerEditBox:GetText()
    if playerName and playerName ~= "" then
        textEditBox:SetFocus()
    end
end)
playerEditBox:SetScript("OnEscapePressed", OnEscape)
playerEditBox:SetScript("OnTabPressed", function()
    textEditBox:SetFocus()
end)

textEditBox:SetScript("OnEnterPressed", OnSubmit)
textEditBox:SetScript("OnEscapePressed", OnEscape)
textEditBox:SetScript("OnTabPressed", function()
    playerEditBox:SetFocus()
end)

textEditBox:SetScript("OnEditFocusGained", function()
    local playerName = playerEditBox:GetText()
    local noteText = textEditBox:GetText()
    if playerName and playerName ~= "" and (noteText == nil or noteText == "") then
        local note = PorkNotes.GetPlayerNote(playerName)
        if note then
            textEditBox:SetText(note.text)
        end
    end
end)

submitButton:SetScript("OnClick", OnSubmit)

PorkNotes.ShowCreateFrame = function()
    -- Auto-fill player name if a player is currently targeted
    local targetName = UnitName("target")
    if targetName and UnitIsPlayer("target") then
        playerEditBox:SetText(targetName)
    else
        playerEditBox:SetText("")
    end
    
    textEditBox:SetText("")
    playerCounter:SetText("0 / 12")
    playerCounter:SetTextColor(0.6, 0.6, 0.6)
    duplicateWarning:Hide()
    playerEditBox:SetBackdropColor(0, 0, 0, 0.5)
    textCounter:SetText("0 / 150")
    textCounter:SetTextColor(0.6, 0.6, 0.6)
    frame:ClearAllPoints()
    local saved = PorkNotes.GetSetting("CreateNoteFramePos", nil)
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
