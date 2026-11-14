if not GearRack.enabled then return end

-- GearRack's windows in the ForgeUI Ember look: rounded cards, dark wells,
-- pill buttons and segmented tabs on the existing XML frames, so every
-- position and size stays as it was. Gear keeps its own art: equipment
-- buttons, icons, rarity borders and item-quality colors. The equipment and
-- trinket bars and their flyouts are not restyled.
local _, ns = ...
local UI = ns.UI

-- The event editor covers the gear columns, so its sheet is fully opaque.
local SHEET = { UI.surface[1], UI.surface[2], UI.surface[3], 1 }

-- XML buttons keep their own text; the colors hold in every button state.
local function TextColor(button, role)
    local c = UI[role]
    button:SetTextColor(c[1], c[2], c[3])
    button:SetHighlightTextColor(c[1], c[2], c[3])
    button:SetDisabledTextColor(c[1], c[2], c[3])
end

-- Like UI.Select for pills drawn on XML buttons: selected pills fill with the
-- accent, ghost pills (tabs) stay clear until selected.
function ns.SelectPill(button, selected)
    if button.selected == selected then return end
    button.selected = selected
    UI.Paint(button.fill, selected and UI.selected or (button.ghost and UI.clear or UI.control))
    TextColor(button, (selected or not button.ghost) and "text" or "hint")
end

-- inset shrinks the pill inside the button, as tabs sit inside their track.
local function Pill(button, ghost, inset)
    inset = inset or 0
    local radius = button:GetHeight() / 2 - inset
    button.fill = UI.Rounded(button, "BACKGROUND", radius, UI.clear, -inset)
    UI.Rounded(button, "HIGHLIGHT", radius, UI.hover, -inset)
    button.ghost = ghost
    ns.SelectPill(button, false)
end

-- Segmented tabs: one track behind the row, each tab a ghost pill. The tabs
-- move into the track so they always draw above it.
local function Tabs(name, parent, first, last, tabs)
    local track = CreateFrame("Frame", name, parent)
    track:SetPoint("TOPLEFT", first, "TOPLEFT")
    track:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT")
    UI.Rounded(track, "BACKGROUND", first:GetHeight() / 2, UI.track)
    for _, tab in ipairs(tabs) do
        tab:SetParent(track)
        tab:SetFrameLevel(track:GetFrameLevel() + 1)
        Pill(tab, true, 2)
    end
end

-- A dark rounded well behind a list, a script or the help text.
local function Well(frame)
    UI.Rounded(frame, "BACKGROUND", 8, UI.track)
end

-- A rounded text field. outset grows it past the edit box; insets keep the
-- text clear of its edges.
local function Field(edit, outset, left, right)
    UI.Rounded(edit, "BACKGROUND", 6 + (outset or 0), UI.track, outset)
    edit:SetTextInsets(left or 6, right or 6, 0, 0)
    UI.Color(edit, "text")
end

-- List rows: a hover band and a selection fill. Rows whose names carry item
-- quality colors are outlined instead, so blue and purple names stay readable.
local function Row(row, radius, outlined)
    row.fill = UI.Rounded(row, "BACKGROUND", radius, UI.clear)
    if outlined then row.inner = UI.Rounded(row, "BORDER", radius - 1, UI.clear, -1) end
    UI.Rounded(row, "HIGHLIGHT", radius, UI.hover)
end

function ns.SelectRow(row, selected)
    selected = selected and true or false
    if row.isSelected == selected then return end
    row.isSelected = selected
    if row.inner then
        UI.Paint(row.fill, selected and UI.accent or UI.clear)
        UI.Paint(row.inner, selected and UI.track or UI.clear)
    else
        UI.Paint(row.fill, selected and UI.selected or UI.clear)
    end
end

local function Colors(role, names)
    for _, name in ipairs(names) do UI.Color(_G[name], role) end
end

-- Gear sets ---------------------------------------------------------------

UI.Surface(GearRackUI_SetsFrame, 12)
UI.Color(GearRackUI_Sets_Title, "heading")
Tabs("GearRackUI_Sets_TabTrack", GearRackUI_SetsFrame, GearRackUI_Sets_Tab3, GearRackUI_Sets_Tab1,
    { GearRackUI_Sets_Tab1, GearRackUI_Sets_Tab2, GearRackUI_Sets_Tab3, GearRackUI_Sets_Tab4 })
for _, name in ipairs({ "GearRackUI_Sets_SaveButton", "GearRackUI_Sets_RemoveButton", "GearRackUI_Sets_BindButton",
    "GearRackUI_Sets_CancelButton", "GearRackUI_Events_DeleteButton", "GearRackUI_Events_EditButton",
    "GearRackUI_Events_NewButton", "GearRackUI_EditEvent_Test", "GearRackUI_EditEvent_Save",
    "GearRackUI_EditEvent_Cancel", "GearRackUI_ResetButton", "GearRackUI_ResetEventsButton" }) do
    Pill(_G[name])
end
for _, frame in ipairs({ GearRackUI_Sets_Icons, GearRackUI_Sets_OptList, GearRackUI_Sets_EventsView,
    GearRackUI_Sets_Saved, GearRackUI_Sets_SubFrame3, GearRackUI_ScriptEditFrame }) do
    Well(frame)
end
UI.Rounded(GearRackUI_EditEvent, "BACKGROUND", 12, SHEET)
-- The set name field also holds the dropdown button at its right end.
Field(GearRackUI_Sets_Name, 2, 4, 24)
-- The edit box spans the button; keep its clicks off the button so the whole
-- arrow opens the set list.
GearRackUI_Sets_Name:SetHitRectInsets(0, 24, 0, 0)
GearRackUI_Sets_DropDownButton:SetFrameLevel(GearRackUI_Sets_Name:GetFrameLevel() + 1)
Field(GearRackUI_EventName)
Field(GearRackUI_EventTrigger)
Field(GearRackUI_EventDelay)
Colors("heading", { "GearRackUI_Sets_NameLabel", "GearRackUI_Sets_SetSelectLabel", "GearRackUI_KeyBindFrame_MessageTitle" })
Colors("text", { "GearRackUI_EditEventNameLabel", "GearRackUI_EditEventTriggerLabel", "GearRackUI_EditEventDelayLabel",
    "GearRackUI_EditEventSecondsLabel", "GearRackUI_KeyBindFrame_MessageHint", "GearRackUI_Help_EditBox",
    "GearRackUI_EventScript" })
for i = 1, 7 do
    Row(_G["GearRackUI_Event" .. i], 7)
    UI.Color(_G["GearRackUI_Event" .. i .. "Name"], "text")
end
for i = 1, 8 do UI.Rounded(_G["GearRackUI_Sets_Saved" .. i], "HIGHLIGHT", 7, UI.hover) end
for i = 1, 11 do UI.Rounded(_G["GearRackUI_Sets_Compact" .. i], "HIGHLIGHT", 6, UI.hover) end

-- Trinkets ----------------------------------------------------------------

UI.Surface(GearRackTrinkets_OptFrame, 12)
UI.Color(GearRackTrinkets_Title, "heading")
Tabs("GearRackTrinkets_TabTrack", GearRackTrinkets_OptFrame, GearRackTrinkets_Tab3, GearRackTrinkets_Tab1,
    { GearRackTrinkets_Tab1, GearRackTrinkets_Tab2, GearRackTrinkets_Tab3 })
-- Each queue checkbox sits on its slot's tab.
for check, tab in pairs({ [GearRackTrinkets_Trinket0Check] = GearRackTrinkets_Tab3,
    [GearRackTrinkets_Trinket1Check] = GearRackTrinkets_Tab2 }) do
    check:SetParent(tab)
    check:SetFrameLevel(tab:GetFrameLevel() + 1)
end
for _, name in ipairs({ "GearRackTrinkets_ProfilesDelete", "GearRackTrinkets_ProfilesLoad",
    "GearRackTrinkets_ProfilesSave", "GearRackTrinkets_ProfilesCancel" }) do
    Pill(_G[name])
end
Well(GearRackTrinkets_SortListFrame)
Well(GearRackTrinkets_ProfilesListFrame)
Field(GearRackTrinkets_SortDelay, 0, 4, 4)
Field(GearRackTrinkets_ProfileName)
Colors("text", { "GearRackTrinkets_SortDelayLabel", "GearRackTrinkets_SortDelayUnit",
    "GearRackTrinkets_ProfileNameLabel", "GearRackTrinkets_OptColumnsSliderText" })
for i = 1, 9 do Row(_G["GearRackTrinkets_Sort" .. i], 8, true) end
for i = 1, 7 do
    Row(_G["GearRackTrinkets_Profile" .. i], 7)
    UI.Color(_G["GearRackTrinkets_Profile" .. i .. "Name"], "text")
end

-- The columns slider as a UI.Slider: a thin rounded track and an accent knob.
local slider = GearRackTrinkets_OptColumnsSlider
UI.Rounded(slider, "BACKGROUND", 3, UI.control, -5)
local thumb = slider:CreateTexture(nil, "ARTWORK")
thumb:SetTexture(UI.disc)
thumb:SetWidth(14); thumb:SetHeight(14)
UI.Tint(thumb, UI.accent)
slider:SetThumbTexture(thumb)
