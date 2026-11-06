local _G = getfenv(0)

local frame = CreateFrame("Frame", "CaramelNotes_SettingsFrame", UIParent)
frame:SetWidth(380)
frame:SetHeight(300)
frame:SetPoint("CENTER", UIParent)
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetResizable(false)
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
title:SetText("|cFFCA4020Caramel|rNotes - Settings")

-- Makes the window closable by pressing Escape.
tinsert(UISpecialFrames, frame:GetName())

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

local submitButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
submitButton:SetWidth(100)
submitButton:SetHeight(24)
submitButton:SetPoint("BOTTOM", 0, 15)
submitButton:SetText("OK")
submitButton:SetScript("OnClick", function() frame:Hide() end)

frame:SetScript("OnShow", function()
    PlaySound("igQuestListOpen")
end)

frame:SetScript("OnHide", function()
    CaramelNotes.ShowNotesFrame()
    PlaySound("igQuestListClose")
end)

local checkboxes = {}

local function EnableCheckbox(checkbox)
    checkbox:Enable()
    checkbox.textElement:SetTextColor(1, 0.82, 0)
end

local function DisableCheckbox(checkbox)
    checkbox:Disable()
    checkbox.textElement:SetTextColor(0.5, 0.5, 0.5)
end

local function ChangeCheckboxState(checkboxName, isEnabled)
    if isEnabled then
        EnableCheckbox(checkboxes[checkboxName])
    else
        DisableCheckbox(checkboxes[checkboxName])
    end
end

local function OnCheckboxToggle(name, isChecked)
    CaramelNotes.SetSetting(name, isChecked)
    if name == "ShowNotesInChat" then
        ChangeCheckboxState("ChatShowCreatedBy", isChecked)
        ChangeCheckboxState("ChatShowCreatedAtZone", isChecked)
    end
    if name == "ShowNotesInTooltips" then
        ChangeCheckboxState("TooltipsShowCreatedBy", isChecked)
        ChangeCheckboxState("TooltipsShowCreatedAtZone", isChecked)
    end
end

local function CreateCheckbox(name, text, x, y)
    local checkboxName = frame:GetName() .. "_" .. name
    local checkboxTextName = frame:GetName() .. "_" .. name .. "Text"
    local checkbox = CreateFrame("CheckButton", checkboxName, frame, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
    checkbox:SetWidth(20)
    checkbox:SetHeight(20)

    checkbox.textElement = _G[checkboxTextName]
    checkbox.textElement:SetText(" " .. text)
    checkbox.textElement:SetFontObject(GameFontNormal)
    checkbox:SetHitRectInsets(0, -checkbox.textElement:GetStringWidth(), 0, 0)

    checkbox:SetScript("OnClick", function()
        -- GetChecked() returns 1 or nil, not a boolean
        OnCheckboxToggle(name, checkbox:GetChecked() ~= nil)
    end)

    EnableCheckbox(checkbox)
    checkboxes[name] = checkbox
end

y = 40
CreateCheckbox("NotesShowCreatedBy", "Show who created the note in the main window", 20, y); y = y + 25
CreateCheckbox("NotesShowCreatedAtZone", "Show where the note was created in the main window", 20, y); y = y + 35

CreateCheckbox("ShowNotesInChat", "Display player notes in chat", 20, y); y = y + 25
CreateCheckbox("ChatShowCreatedBy", "Show who created the note", 40, y); y = y + 25
CreateCheckbox("ChatShowCreatedAtZone", "Show where the note was created", 40, y); y = y + 35

CreateCheckbox("ShowNotesInTooltips", "Display player notes in tooltips", 20, y); y = y + 25
CreateCheckbox("TooltipsShowCreatedBy", "Show who created the note", 40, y); y = y + 25
CreateCheckbox("TooltipsShowCreatedAtZone", "Show where the note was created", 40, y); y = y + 25

CaramelNotes.ShowSettingsFrame = function ()
    checkboxes.NotesShowCreatedBy:SetChecked(CaramelNotes.GetSetting("NotesShowCreatedBy", false))
    checkboxes.NotesShowCreatedAtZone:SetChecked(CaramelNotes.GetSetting("NotesShowCreatedAtZone", false))

    checkboxes.ShowNotesInChat:SetChecked(CaramelNotes.GetSetting("ShowNotesInChat", true))
    checkboxes.ChatShowCreatedBy:SetChecked(CaramelNotes.GetSetting("ChatShowCreatedBy", false))
    checkboxes.ChatShowCreatedAtZone:SetChecked(CaramelNotes.GetSetting("ChatShowCreatedAtZone", false))
    ChangeCheckboxState("ChatShowCreatedBy", checkboxes.ShowNotesInChat:GetChecked())
    ChangeCheckboxState("ChatShowCreatedAtZone", checkboxes.ShowNotesInChat:GetChecked())

    checkboxes.ShowNotesInTooltips:SetChecked(CaramelNotes.GetSetting("ShowNotesInTooltips", true))
    checkboxes.TooltipsShowCreatedBy:SetChecked(CaramelNotes.GetSetting("TooltipsShowCreatedBy", false))
    checkboxes.TooltipsShowCreatedAtZone:SetChecked(CaramelNotes.GetSetting("TooltipsShowCreatedAtZone", false))
    ChangeCheckboxState("TooltipsShowCreatedBy", checkboxes.ShowNotesInTooltips:GetChecked())
    ChangeCheckboxState("TooltipsShowCreatedAtZone", checkboxes.ShowNotesInTooltips:GetChecked())

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent)
    frame:Show()
end
