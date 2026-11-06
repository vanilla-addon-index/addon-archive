local frame = CreateFrame("Frame", "PorkNotes_SettingsFrame", UIParent)
frame:SetWidth(380)
frame:SetHeight(490)  -- Increased from 460 to 490 for sync toggle
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
frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint()
    PorkNotes.SetSetting("SettingsFramePos", point .. "," .. relativePoint .. "," .. math.floor(x) .. "," .. math.floor(y))
end)
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -15)
title:SetText("|cFFD893EDPork|r|cFFFFBB00Notes|r|cFFFFFFFF - Settings")

tinsert(UISpecialFrames, frame:GetName())

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

local submitButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
submitButton:SetWidth(100)
submitButton:SetHeight(24)
submitButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 15)
submitButton:SetText("OK")
submitButton:SetScript("OnClick", function() frame:Hide() end)

local importButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
importButton:SetWidth(160)
importButton:SetHeight(24)
importButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 15)
importButton:SetText("Import from CaramelNotes")
importButton:SetScript("OnClick", function()
    PorkNotes.ImportFromCaramelNotes()
end)

frame:SetScript("OnShow", function()
    PlaySound("igQuestListOpen")
end)

frame:SetScript("OnHide", function()
    PorkNotes.ShowNotesFrame()
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
    PorkNotes.SetSetting(name, isChecked)
    if name == "ShowNotesInChat" then
        ChangeCheckboxState("ChatShowCreatedBy", isChecked)
        ChangeCheckboxState("ChatShowTimestamp", isChecked)
    end
    if name == "ShowMinimapButton" then
        PorkNotes.SetMinimapButtonVisible(isChecked)
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
        OnCheckboxToggle(name, checkbox:GetChecked() ~= nil)
    end)

    EnableCheckbox(checkbox)
    checkboxes[name] = checkbox
end

local y = 40
CreateCheckbox("NotesShowCreatedBy", "Show who created the note in the main window", 20, y); y = y + 25
CreateCheckbox("NotesShowCreatedAtZone", "Show where the note was created in the main window", 20, y); y = y + 35

CreateCheckbox("ShowNotesInChat", "Display player notes in chat", 20, y); y = y + 25
CreateCheckbox("ChatShowCreatedBy", "Show note author in chat alert", 40, y); y = y + 25
CreateCheckbox("ChatShowTimestamp", "Show note creation date in chat alert", 40, y); y = y + 35

CreateCheckbox("ShowNotesInTooltips", "Display player notes in tooltips", 20, y); y = y + 35

CreateCheckbox("ShowMinimapButton", "Show minimap button", 20, y); y = y + 35

CreateCheckbox("SyncEnabled", "Receive synced notes from other players", 20, y); y = y + 35

CreateCheckbox("SyncAutoAccept", "Auto-accept incoming syncs (newer notes only)", 20, y); y = y + 35
CreateCheckbox("SyncAutoPopup", "Auto-open review window on sync receive (out of combat only)", 20, y); y = y + 35

-- World/LFG chat frame dropdown
local dropdownLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dropdownLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -y)
dropdownLabel:SetText("Route World/LFG alerts to:")
dropdownLabel:SetTextColor(1, 0.82, 0)

local dropdown = CreateFrame("Frame", frame:GetName() .. "_WorldChatDropdown", frame, "UIDropDownMenuTemplate")
dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 150, -y)
UIDropDownMenu_SetWidth(100, dropdown)
y = y + 40

local function UpdateDropdown()
    local currentValue = PorkNotes.GetSetting("WorldChatFrame", 3)
    UIDropDownMenu_Initialize(dropdown, function()
        for i = 1, 10 do
            local info = {}
            info.text = "Chat Frame " .. i
            info.value = i
            info.checked = (i == currentValue)
            local frameIndex = i
            info.func = function()
                PorkNotes.SetSetting("WorldChatFrame", frameIndex)
                UIDropDownMenu_SetText("Chat Frame " .. frameIndex, dropdown)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText("Chat Frame " .. currentValue, dropdown)
end

-- History limit dropdown
local historyLimitLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
historyLimitLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -y)
historyLimitLabel:SetText("Note history limit:")
historyLimitLabel:SetTextColor(1, 0.82, 0)

local historyDropdown = CreateFrame("Frame", frame:GetName() .. "_HistoryDropdown", frame, "UIDropDownMenuTemplate")
historyDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 150, -y)
UIDropDownMenu_SetWidth(100, historyDropdown)

local historyOptions = {
    { text = "No history", value = 0  },
    { text = "Last 5",     value = 5  },
    { text = "Last 10",    value = 10 },
    { text = "Last 20",    value = 20 },
    { text = "Last 50",    value = 50 },
    { text = "Unlimited",  value = -1 },
}

local function UpdateHistoryDropdown()
    local current = PorkNotes.GetSetting("HistoryLimit", -1)
    UIDropDownMenu_Initialize(historyDropdown, function()
        for _, opt in ipairs(historyOptions) do
            local info = {}
            info.text    = opt.text
            info.value   = opt.value
            info.checked = (opt.value == current)
            local optValue = opt.value
            local optText  = opt.text
            info.func = function()
                PorkNotes.SetSetting("HistoryLimit", optValue)
                UIDropDownMenu_SetText(optText, historyDropdown)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    local label = "Unlimited"
    for _, opt in ipairs(historyOptions) do
        if opt.value == current then label = opt.text break end
    end
    UIDropDownMenu_SetText(label, historyDropdown)
end

PorkNotes.ShowSettingsFrame = function()
    checkboxes.NotesShowCreatedBy:SetChecked(PorkNotes.GetSetting("NotesShowCreatedBy", false))
    checkboxes.NotesShowCreatedAtZone:SetChecked(PorkNotes.GetSetting("NotesShowCreatedAtZone", false))

    checkboxes.ShowNotesInChat:SetChecked(PorkNotes.GetSetting("ShowNotesInChat", true))
    checkboxes.ChatShowCreatedBy:SetChecked(PorkNotes.GetSetting("ChatShowCreatedBy", false))
    checkboxes.ChatShowTimestamp:SetChecked(PorkNotes.GetSetting("ChatShowTimestamp", false))
    ChangeCheckboxState("ChatShowCreatedBy", checkboxes.ShowNotesInChat:GetChecked())
    ChangeCheckboxState("ChatShowTimestamp", checkboxes.ShowNotesInChat:GetChecked())

    checkboxes.ShowNotesInTooltips:SetChecked(PorkNotes.GetSetting("ShowNotesInTooltips", true))
    checkboxes.ShowMinimapButton:SetChecked(PorkNotes.GetSetting("ShowMinimapButton", true))
    checkboxes.SyncEnabled:SetChecked(PorkNotes.GetSetting("SyncEnabled", true))
    checkboxes.SyncAutoAccept:SetChecked(PorkNotes.GetSetting("SyncAutoAccept", false))
    checkboxes.SyncAutoPopup:SetChecked(PorkNotes.GetSetting("SyncAutoPopup", false))

    UpdateDropdown()
    UpdateHistoryDropdown()

    frame:ClearAllPoints()
    local saved = PorkNotes.GetSetting("SettingsFramePos", nil)
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
