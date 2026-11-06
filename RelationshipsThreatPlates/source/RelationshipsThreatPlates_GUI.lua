----------------------------------------------------------------------
-- RelationshipsThreatPlates_GUI.lua
-- Configuration GUI panel with scrolling support
-- Styled after Kui Nameplates config: dark, minimal, clean
-- Standalone - no Ace3 or external config library required
-- Compatible with WoW 1.12 (Vanilla / Turtle WoW / Octo WoW)
----------------------------------------------------------------------

local addon = RelationshipsThreatPlates

addon.GUI = {}

-- GUI frame reference
local guiFrame = nil

-- Kui-style colour constants for GUI
local C = {
    BG           = { 0.10, 0.10, 0.10, 0.95 },
    BORDER       = { 0.30, 0.30, 0.30, 1.00 },
    HEADER_BG    = { 0.15, 0.15, 0.15, 1.00 },
    HEADER_TEXT  = { 0.75, 0.60, 1.00, 1.00 },  -- Kui purple
    ACCENT       = { 0.30, 0.70, 1.00, 1.00 },  -- Kui blue
    TEXT         = { 0.85, 0.85, 0.85, 1.00 },
    TEXT_DIM      = { 0.55, 0.55, 0.55, 1.00 },
    BUTTON_BG    = { 0.20, 0.20, 0.20, 1.00 },
    BUTTON_HOVER = { 0.25, 0.25, 0.30, 1.00 },
    BUTTON_TEXT   = { 0.90, 0.90, 0.90, 1.00 },
    CHECK_ON     = { 0.30, 0.70, 1.00, 0.90 },
    CHECK_OFF    = { 0.30, 0.30, 0.30, 0.80 },
    SLIDER_BG    = { 0.15, 0.15, 0.15, 1.00 },
    SLIDER_FILL  = { 0.30, 0.70, 1.00, 0.80 },
    DIVIDER      = { 0.25, 0.25, 0.25, 0.60 },
    SOLID        = "Interface\\Buttons\\WHITE8x8",
}

-- Layout
local GUI_WIDTH  = 320
local GUI_HEIGHT = 520
local HEADER_H   = 30
local MARGIN     = 14
local FONT_NORMAL = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE   = 10

-- Widget references for refresh
local widgets = {}

-- Only settings that change the visual STRUCTURE of a bar need a full
-- RecreateAll (which tears every bar down and re-attaches on the next
-- scan). Everything else — filters, modes, alpha, colours — just needs
-- a soft UpdateAll, which is far less likely to leave plates without
-- bars while pooled nameplate frames are hidden.
local NEEDS_RECREATE = {
    barHeight    = true,
    barWidthScale= true,
    barOffsetY   = true,
    barOffsetX   = true,
    glowEnabled  = true,
    glowAsShadow = true,
    glowSize     = true,
    showSpark    = true,
    showFillBG   = true,
    showText     = true,
    fontOutline  = true,
    fontSize     = true,
}

local function ApplySettingChange(configKey)
    if NEEDS_RECREATE[configKey] then
        addon.Nameplates:RecreateAll()
    else
        addon.Nameplates:UpdateAll()
    end
end

-- ==================================================================
-- Helper: safely set backdrop on a frame
-- ==================================================================
local function SafeSetBackdrop(frame, backdropTbl)
    if frame.SetBackdrop then
        frame:SetBackdrop(backdropTbl)
        return true
    end
    return false
end

-- ==================================================================
-- Initialize GUI module
-- ==================================================================
function addon.GUI:Initialize()
    -- Defer creation until first toggle
end

-- ==================================================================
-- Create the main GUI frame (Kui-style dark panel with scroll)
-- ==================================================================
function addon.GUI:CreateFrame()
    if guiFrame then return end

    -- ==============================================================
    -- Main window frame
    -- ==============================================================
    local f = CreateFrame("Frame", "RelationshipsThreatPlatesGUI", UIParent)
    f:SetWidth(GUI_WIDTH)
    f:SetHeight(GUI_HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    SafeSetBackdrop(f, {
        bgFile   = C.SOLID,
        edgeFile = C.SOLID,
        tile     = false, tileSize = 0,
        edgeSize = 1,
    })
    f:SetBackdropColor(unpack(C.BG))
    f:SetBackdropBorderColor(unpack(C.BORDER))
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local _, _, point, _, _, x, y = this:GetPoint()
        RelationshipsThreatPlatesDB.guiPos = { point = point, relPoint = point, x = x, y = y }
    end)
    f:Hide()

    -- ==============================================================
    -- Header bar (Kui purple accent)
    -- ==============================================================
    local header = CreateFrame("Frame", nil, f)
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    SafeSetBackdrop(header, {
        bgFile   = C.SOLID,
        edgeFile = C.SOLID,
        tile     = false, tileSize = 0,
        edgeSize = 1,
    })
    header:SetBackdropColor(unpack(C.HEADER_BG))
    header:SetBackdropBorderColor(unpack(C.BORDER))
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local _, _, point, _, _, x, y = f:GetPoint()
        RelationshipsThreatPlatesDB.guiPos = { point = point, relPoint = point, x = x, y = y }
    end)

    local headerText = header:CreateFontString(nil, "OVERLAY")
    headerText:SetFont(FONT_NORMAL, 12, "OUTLINE")
    headerText:SetPoint("CENTER", header, "CENTER", 0, 0)
    headerText:SetTextColor(unpack(C.HEADER_TEXT))
    headerText:SetText("RelationshipsThreatPlates")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetWidth(24)
    closeBtn:SetHeight(20)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    closeBtn:SetNormalTexture(C.SOLID)
    closeBtn:GetNormalTexture():SetVertexColor(0.4, 0.4, 0.4, 0.8)
    closeBtn:SetHighlightTexture(C.SOLID)
    closeBtn:GetHighlightTexture():SetVertexColor(0.6, 0.6, 0.6, 0.8)
    closeBtn:SetPushedTexture(C.SOLID)
    closeBtn:GetPushedTexture():SetVertexColor(0.3, 0.3, 0.3, 0.8)

    local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
    closeText:SetFont(FONT_NORMAL, 10, "OUTLINE")
    closeText:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeText:SetTextColor(1, 1, 1, 1)
    closeText:SetText("X")
    closeBtn:SetFontString(closeText)

    closeBtn:SetScript("OnClick", function()
        addon.GUI:Hide()
    end)

    -- ==============================================================
    -- Scroll frame - allows content to scroll when it overflows
    -- ==============================================================
    -- The scroll frame sits below the header and fills the rest of the window
    local scrollFrame = CreateFrame("ScrollFrame", "RelationshipsThreatPlatesScrollFrame", f)
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -HEADER_H)
    scrollFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -HEADER_H)
    scrollFrame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    -- Scroll bar (vertical)
    local scrollBar = CreateFrame("Slider", "RelationshipsThreatPlatesScrollBar", scrollFrame, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -HEADER_H - 8)
    scrollBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 8)
    scrollBar:SetWidth(16)
    scrollBar:SetMinMaxValues(0, 1000)
    scrollBar:SetValueStep(20)
    scrollBar:SetValue(0)

    -- Style the scrollbar thumb and background to Kui look
    local scrollName = scrollBar:GetName()
    local scrollThumb = getglobal(scrollName .. "ThumbTexture")
    if scrollThumb then
        scrollThumb:SetTexture(C.SOLID)
        scrollThumb:SetVertexColor(unpack(C.ACCENT))
    end

    -- Scroll child - the actual content frame that holds all settings
    local scrollChild = CreateFrame("Frame", "RelationshipsThreatPlatesScrollChild", scrollFrame)
    scrollChild:SetWidth(GUI_WIDTH - 30)  -- leave room for scrollbar
    -- Height will be set after building content based on total y offset
    scrollFrame:SetScrollChild(scrollChild)

    -- Connect scrollbar to scrollframe
    scrollBar:SetScript("OnValueChanged", function()
        scrollFrame:SetVerticalScroll(this:GetValue())
    end)

    -- Mouse wheel scrolling on the main frame
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function()
        local delta = arg1
        local current = scrollBar:GetValue()
        local step = 40
        if delta > 0 then
            scrollBar:SetValue(math.max(0, current - step))
        else
            scrollBar:SetValue(math.min(1000, current + step))
        end
    end)

    f.scrollFrame = scrollFrame
    f.scrollBar = scrollBar
    f.scrollChild = scrollChild

    -- Build settings into the scroll child
    widgets = {}
    local totalHeight = self:BuildSettings(scrollChild)

    -- Set the scroll child height to the actual content height
    scrollChild:SetHeight(totalHeight + MARGIN)

    -- Update scrollbar max based on content vs visible area
    local visibleH = GUI_HEIGHT - HEADER_H
    if totalHeight + MARGIN > visibleH then
        scrollBar:SetMinMaxValues(0, totalHeight + MARGIN - visibleH)
    else
        scrollBar:SetMinMaxValues(0, 0)
        scrollBar:Hide()
    end

    -- Restore saved position
    if RelationshipsThreatPlatesDB and RelationshipsThreatPlatesDB.guiPos then
        local pos = RelationshipsThreatPlatesDB.guiPos
        if pos.point and pos.x and pos.y then
            f:ClearAllPoints()
            f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
        end
    end

    guiFrame = f
end

-- ==================================================================
-- Build all settings controls
-- Returns the total content height for scroll setup
-- ==================================================================
function addon.GUI:BuildSettings(parent)
    local y = 0
    local W = GUI_WIDTH - 30  -- account for scrollbar width

    -- ==============================================================
    -- Helper: Section label (Kui-style blue heading)
    -- ==============================================================
    local function SectionLabel(text)
        local label = parent:CreateFontString(nil, "OVERLAY")
        label:SetFont(FONT_NORMAL, FONT_SIZE + 1, "OUTLINE")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, -y)
        label:SetTextColor(unpack(C.ACCENT))
        label:SetText(text)
        y = y + 20

        -- Divider line
        local divider = parent:CreateTexture(nil, "ARTWORK")
        divider:SetTexture(C.SOLID)
        divider:SetVertexColor(unpack(C.DIVIDER))
        divider:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, -y + 8)
        divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -MARGIN, -y + 8)
        divider:SetHeight(1)
        y = y + 4
    end

    -- ==============================================================
    -- Helper: Checkbox (custom frame-based)
    -- ==============================================================
    local function CheckBox(labelText, configKey, description)
        local btn = CreateFrame("Frame", nil, parent)
        btn:SetWidth(18)
        btn:SetHeight(18)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, -y)
        btn:EnableMouse(true)

        SafeSetBackdrop(btn, {
            bgFile   = C.SOLID,
            edgeFile = C.SOLID,
            tile     = false, tileSize = 0,
            edgeSize = 1,
        })
        btn:SetBackdropColor(unpack(C.CHECK_OFF))
        btn:SetBackdropBorderColor(unpack(C.BORDER))

        local check = btn:CreateTexture(nil, "ARTWORK")
        check:SetTexture(C.SOLID)
        check:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
        check:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
        check:SetVertexColor(unpack(C.CHECK_ON))
        check:Hide()
        btn.checkMark = check

        btn.checked = false
        if RelationshipsThreatPlatesDB[configKey] then
            btn.checked = true
            check:Show()
        end

        btn:SetScript("OnMouseDown", function()
            this.checked = not this.checked
            RelationshipsThreatPlatesDB[configKey] = this.checked
            if this.checked then
                this.checkMark:Show()
            else
                this.checkMark:Hide()
            end
            ApplySettingChange(configKey)
        end)

        local label = parent:CreateFontString(nil, "OVERLAY")
        label:SetFont(FONT_NORMAL, FONT_SIZE)
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN + 24, -y + 1)
        label:SetTextColor(unpack(C.TEXT))
        label:SetText(labelText)

        y = y + 18

        if description then
            local desc = parent:CreateFontString(nil, "OVERLAY")
            desc:SetFont(FONT_NORMAL, FONT_SIZE - 2)
            desc:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN + 24, -y + 3)
            desc:SetTextColor(unpack(C.TEXT_DIM))
            desc:SetText(description)
            y = y + 14
        end

        y = y + 4
        widgets[configKey] = btn
    end

    -- ==============================================================
    -- Helper: Slider (Kui-style flat slider)
    -- ==============================================================
    local function Slider(labelText, configKey, minVal, maxVal, step, suffix)
        suffix = suffix or ""

        local label = parent:CreateFontString(nil, "OVERLAY")
        label:SetFont(FONT_NORMAL, FONT_SIZE)
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, -y)
        label:SetTextColor(unpack(C.TEXT))
        label:SetText(labelText)
        y = y + 16

        local slider = CreateFrame("Slider", "RelationshipsThreatPlatesSlider_" .. configKey, parent, "OptionsSliderTemplate")
        slider:SetWidth(W - 60)
        slider:SetHeight(10)
        slider:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, -y)
        slider:SetOrientation("HORIZONTAL")
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetValue(RelationshipsThreatPlatesDB[configKey] or minVal)

        local sliderName = slider:GetName()
        local bgTexture = getglobal(sliderName .. "BG")
        local fillTexture = getglobal(sliderName .. "Fill")
        local thumbTexture = getglobal(sliderName .. "Thumb")

        if bgTexture then
            bgTexture:SetTexture(C.SOLID)
            bgTexture:SetVertexColor(unpack(C.SLIDER_BG))
        end
        if fillTexture then
            fillTexture:SetTexture(C.SOLID)
            fillTexture:SetVertexColor(unpack(C.SLIDER_FILL))
        end
        if thumbTexture then
            thumbTexture:SetTexture(C.SOLID)
            thumbTexture:SetVertexColor(unpack(C.ACCENT))
            thumbTexture:SetWidth(8)
            thumbTexture:SetHeight(14)
        end

        local lowText = getglobal(sliderName .. "Low")
        local highText = getglobal(sliderName .. "High")
        if lowText then lowText:SetText("") end
        if highText then highText:SetText("") end

        local valText = parent:CreateFontString(nil, "OVERLAY")
        valText:SetFont(FONT_NORMAL, FONT_SIZE - 1)
        valText:SetPoint("LEFT", slider, "RIGHT", 6, 0)
        valText:SetTextColor(unpack(C.ACCENT))
        local curVal = RelationshipsThreatPlatesDB[configKey] or minVal
        if step < 1 then
            valText:SetText(string.format("%.1f", curVal) .. suffix)
        else
            valText:SetText(math.floor(curVal + 0.5) .. suffix)
        end

        slider:SetScript("OnValueChanged", function()
            local val = this:GetValue()
            val = math.floor(val / step + 0.5) * step
            RelationshipsThreatPlatesDB[configKey] = val
            if step < 1 then
                valText:SetText(string.format("%.1f", val) .. suffix)
            else
                valText:SetText(math.floor(val + 0.5) .. suffix)
            end
            ApplySettingChange(configKey)
        end)

        y = y + 24
        widgets[configKey] = slider
    end

    -- ==============================================================
    -- Helper: Dropdown (uses Blizzard's UIDropDownMenuTemplate)
    -- ==============================================================
    local function Dropdown(labelText, configKey, options)
        local label = parent:CreateFontString(nil, "OVERLAY")
        label:SetFont(FONT_NORMAL, FONT_SIZE)
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, -y)
        label:SetTextColor(unpack(C.TEXT))
        label:SetText(labelText)
        y = y + 16

        local dd = CreateFrame("Frame", "RelationshipsThreatPlatesDD_" .. configKey, parent, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN - 14, -y)
        UIDropDownMenu_SetWidth(160, dd)

        local function GetLabelFor(val)
            for i = 1, table.getn(options) do
                if options[i].value == val then return options[i].label end
            end
            return tostring(val)
        end

        UIDropDownMenu_Initialize(dd, function()
            for i = 1, table.getn(options) do
                local opt = options[i]
                local info = {}
                info.text = opt.label
                info.value = opt.value
                info.func = function()
                    RelationshipsThreatPlatesDB[configKey] = this.value
                    UIDropDownMenu_SetSelectedValue(dd, this.value)
                    UIDropDownMenu_SetText(GetLabelFor(this.value), dd)
                    ApplySettingChange(configKey)
                end
                info.checked = (RelationshipsThreatPlatesDB[configKey] == opt.value)
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedValue(dd, RelationshipsThreatPlatesDB[configKey])
        UIDropDownMenu_SetText(GetLabelFor(RelationshipsThreatPlatesDB[configKey]), dd)

        y = y + 34
        widgets[configKey] = dd
    end

    -- ==============================================================
    -- Helper: small action button
    -- ==============================================================
    local function ActionButton(labelText, onClick)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetWidth(W - MARGIN * 2)
        btn:SetHeight(20)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, -y)
        SafeSetBackdrop(btn, {
            bgFile   = C.SOLID,
            edgeFile = C.SOLID,
            tile     = false, tileSize = 0,
            edgeSize = 1,
        })
        btn:SetBackdropColor(unpack(C.BUTTON_BG))
        btn:SetBackdropBorderColor(unpack(C.BORDER))
        local t = btn:CreateFontString(nil, "OVERLAY")
        t:SetFont(FONT_NORMAL, FONT_SIZE, "OUTLINE")
        t:SetPoint("CENTER", btn, "CENTER", 0, 0)
        t:SetTextColor(unpack(C.BUTTON_TEXT))
        t:SetText(labelText)
        btn:SetFontString(t)
        btn:SetScript("OnEnter", function() this:SetBackdropColor(unpack(C.BUTTON_HOVER)) end)
        btn:SetScript("OnLeave", function() this:SetBackdropColor(unpack(C.BUTTON_BG)) end)
        btn:SetScript("OnClick", onClick)
        y = y + 24
        return btn
    end

    -- ==============================================================
    -- GENERAL SECTION
    -- ==============================================================
    SectionLabel("General")
    CheckBox("Enable Threat Plates", "enabled", "Show threat bars above nameplates")
    CheckBox("Show Threat Text", "showText", "Display value in the bar")
    CheckBox("Tank Mode", "tankMode", "Show raw threat lead over 2nd place instead of %")
    CheckBox("Snap to 100% when Targeted", "targetSnap100", "Force 100% while a mob is focused on you")
    CheckBox("Smooth Colours", "smoothColors", "Gradient colour transition")

    -- ==============================================================
    -- APPEARANCE SECTION
    -- ==============================================================
    SectionLabel("Appearance")
    Slider("Bar Height", "barHeight", 2, 20, 1, "px")
    Slider("Bar Width Scale", "barWidthScale", 0.3, 1.0, 0.05, "")
    Slider("Bar Offset Y", "barOffsetY", 0, 50, 1, "px")
    Slider("Bar Offset X", "barOffsetX", -50, 50, 0.1, "px")
    Slider("Bar Alpha", "barAlpha", 0.1, 1.0, 0.1, "")
    Slider("Font Size", "fontSize", 6, 16, 1, "pt")
    CheckBox("Font Outline", "fontOutline", "Outlined text for readability")

    -- ==============================================================
    -- KUI STYLE SECTION
    -- ==============================================================
    SectionLabel("Kui Style Effects")
    CheckBox("Show Spark", "showSpark", "Bright edge on the bar's leading edge")
    CheckBox("Show Fill Background", "showFillBG", "Dim ghost of bar colour behind the bar")
    Slider("Fill Alpha", "fillAlpha", 0.05, 0.50, 0.05, "")
    CheckBox("Enable Glow", "glowEnabled", "Border glow based on threat level")
    CheckBox("Glow as Shadow", "glowAsShadow", "Subtle shadow instead of bright glow")
    Slider("Glow Size", "glowSize", 1, 8, 1, "px")

    -- ==============================================================
    -- FILTER SECTION
    -- ==============================================================
    SectionLabel("Display Filters")
    CheckBox("Show on Hostile", "showOnHostile", "Show threat bars on hostile units")
    CheckBox("Show on Neutral", "showOnNeutral", "Show threat bars on neutral units")
    CheckBox("Show on Friendly", "showOnFriendly", "Show threat bars on friendly units")

    -- ==============================================================
    -- BEHAVIOR SECTION (2.6)
    -- ==============================================================
    SectionLabel("Behavior")
    CheckBox("Combat Only", "combatOnly", "Only show bars while you are in combat")
    Slider("Hide Below %", "hideBelowPct", 0, 90, 5, "%")
    Dropdown("Text Format", "textFormat", {
        { label = "Percent (85%)",         value = "percent" },
        { label = "Tank Lead (+123)",      value = "tank"    },
        { label = "Status (SAFE/PULL!)",   value = "status"  },
        { label = "Combo (85% +123)",      value = "combo"   },
    })
    Dropdown("Colour Preset", "colorPreset", {
        { label = "Kui (green -> red)",    value = "kui"     },
        { label = "Cool (blue -> red)",    value = "cool"    },
        { label = "Mono (grey -> red)",    value = "mono"    },
        { label = "Warband (cyan -> red)", value = "warband" },
    })

    -- ==============================================================
    -- WARNINGS SECTION (2.6)
    -- ==============================================================
    SectionLabel("Warnings")
    CheckBox("Flash Bar on Aggro", "flashOnAggro", "Pulse the bar when you have 100% aggro")
    Slider("Flash Speed", "flashSpeed", 1, 10, 1, "")
    CheckBox("Play Warning Sound", "warningSound", "Sound when threat crosses the threshold")
    Slider("Warning Threshold", "warningThreshold", 40, 100, 5, "%")
    Dropdown("Warning Sound", "warningSoundName", {
        { label = "Raid Warning",       value = "RaidWarning"      },
        { label = "Tell Message",       value = "TellMessage"      },
        { label = "Murloc Aggro",       value = "MurlocAggroLocal" },
        { label = "Auction Open",       value = "AuctionWindowOpen"},
        { label = "Level Up",           value = "LEVELUP"          },
    })
    ActionButton("Test Warning Sound", function()
        local snd = RelationshipsThreatPlatesDB.warningSoundName or "RaidWarning"
        pcall(PlaySound, snd)
    end)

    -- ==============================================================
    -- WINDOW SECTION (2.6)
    -- ==============================================================
    SectionLabel("Config Window")
    ActionButton("Reset Config Window Position", function()
        RelationshipsThreatPlatesDB.guiPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
        if RelationshipsThreatPlatesGUI then
            RelationshipsThreatPlatesGUI:ClearAllPoints()
            RelationshipsThreatPlatesGUI:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end)

    -- ==============================================================
    -- Reset button at bottom
    -- ==============================================================
    y = y + 10
    local resetBtn = CreateFrame("Button", nil, parent)
    resetBtn:SetWidth(W - MARGIN * 2)
    resetBtn:SetHeight(22)
    resetBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, -y)
    SafeSetBackdrop(resetBtn, {
        bgFile   = C.SOLID,
        edgeFile = C.SOLID,
        tile     = false, tileSize = 0,
        edgeSize = 1,
    })
    resetBtn:SetBackdropColor(unpack(C.BUTTON_BG))
    resetBtn:SetBackdropBorderColor(unpack(C.BORDER))

    local resetText = resetBtn:CreateFontString(nil, "OVERLAY")
    resetText:SetFont(FONT_NORMAL, FONT_SIZE, "OUTLINE")
    resetText:SetPoint("CENTER", resetBtn, "CENTER", 0, 0)
    resetText:SetTextColor(unpack(C.BUTTON_TEXT))
    resetText:SetText("Reset to Defaults")
    resetBtn:SetFontString(resetText)

    resetBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(unpack(C.BUTTON_HOVER))
    end)
    resetBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(unpack(C.BUTTON_BG))
    end)
    resetBtn:SetScript("OnClick", function()
        SlashCmdList["THREATPLATES"]("reset")
        if addon.Nameplates and addon.Nameplates.RecreateAll then
            addon.Nameplates:RecreateAll()
        end
    end)
    y = y + 22 + 8

    -- Return total content height for scroll setup
    return y
end

-- ==================================================================
-- Toggle GUI visibility
-- ==================================================================
function addon.GUI:Toggle()
    if not guiFrame then
        self:CreateFrame()
    end

    if guiFrame:IsVisible() then
        self:Hide()
    else
        self:Show()
    end
end

-- ==================================================================
-- Show the GUI
-- ==================================================================
function addon.GUI:Show()
    if not guiFrame then
        self:CreateFrame()
    end
    guiFrame:Show()
end

-- ==================================================================
-- Hide the GUI
-- ==================================================================
function addon.GUI:Hide()
    if guiFrame then
        guiFrame:Hide()
    end
end

-- ==================================================================
-- Refresh all GUI values from saved vars
-- ==================================================================
function addon.GUI:Refresh()
    if not guiFrame then return end

    for key, widget in pairs(widgets) do
        -- Our custom checkbox (Frame with .checked field)
        if widget.checked ~= nil then
            local val = RelationshipsThreatPlatesDB[key]
            widget.checked = val
            if val then
                widget.checkMark:Show()
            else
                widget.checkMark:Hide()
            end
        -- Slider
        elseif widget.SetValue then
            widget:SetValue(RelationshipsThreatPlatesDB[key])
        end
    end
end
