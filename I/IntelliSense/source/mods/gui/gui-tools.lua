SHELL:LOCKED()

function IS.gui.Frame(parent, width, height, alpha, name)
    parent = parent or UIParent
    local f = CreateFrame("Frame", name, parent)
    f:SetWidth(width or 100)
    f:SetHeight(height or 100)
    f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    f:SetBackdropColor(0, 0, 0, alpha or 0.5)
    return f
end

function IS.gui.Scrollframe(parent, width, height)
    local SCROLLBAR_WIDTH = 2
    local THUMB_WIDTH = 4
    local THUMB_HEIGHT = 20
    local SCROLL_STEP = 6

    local scroll = CreateFrame('ScrollFrame', nil, parent or UIParent)
    scroll:SetWidth(width or 200)
    scroll:SetHeight(height or 300)

    local content = CreateFrame('Frame', nil, scroll)
    content:SetWidth(width or 200)
    content:SetHeight(1)
    scroll:SetScrollChild(content)

    local scrollBar = CreateFrame('Slider', nil, scroll)
    scrollBar:SetWidth(SCROLLBAR_WIDTH)
    scrollBar:SetHeight(height or 300)
    scrollBar:SetPoint('TOPRIGHT', scroll, 'TOPRIGHT', 0, 0)
    scrollBar:SetBackdrop({bgFile = 'Interface\\Buttons\\WHITE8X8'})
    scrollBar:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
    scrollBar:SetOrientation('VERTICAL')

    local thumb = scrollBar:CreateTexture(nil, 'OVERLAY')
    thumb:SetTexture('Interface\\Buttons\\WHITE8X8')
    thumb:SetWidth(THUMB_WIDTH)
    thumb:SetHeight(THUMB_HEIGHT)
    scrollBar:SetThumbTexture(thumb)

    scrollBar:SetScript('OnValueChanged', function()
        local value = this:GetValue()
        scroll:SetVerticalScroll(value)
    end)

    local velocity = 0

    scroll:EnableMouseWheel(true)
    scroll:SetScript('OnMouseWheel', function()
        velocity = velocity + (arg1 * -SCROLL_STEP)
        if not scroll:GetScript('OnUpdate') then
            scroll:SetScript('OnUpdate', function()
                if math.abs(velocity) > 0.5 and scroll:IsVisible() then
                    local current = scroll:GetVerticalScroll()
                    local maxScroll = math.max(0, content:GetHeight() - scroll:GetHeight())
                    local newScroll = math.max(0, math.min(maxScroll, current + velocity))
                    scroll:SetVerticalScroll(newScroll)
                    scrollBar:SetMinMaxValues(0, maxScroll)
                    scrollBar:SetValue(newScroll)
                    velocity = velocity * 0.85
                else
                    velocity = 0
                    scroll:SetScript('OnUpdate', nil)
                end
            end)
        end
    end)

    scroll.updateScrollBar = function()
        local maxScroll = math.max(0, content:GetHeight() - scroll:GetHeight())
        if maxScroll <= 0 then
            scrollBar:Hide()
        else
            scrollBar:Show()
            scrollBar:SetMinMaxValues(0, maxScroll)
            scrollBar:SetValue(0)
        end
    end

    scroll.content = content
    scroll.scrollBar = scrollBar
    return scroll
end

function IS.gui.Button(parent, text, width, height, noBackdrop, textColor, noHighlight)
    local btn = CreateFrame("Button", nil, parent or UIParent)
    btn:SetWidth(width or 140)
    btn:SetHeight(height or 30)
    if not noBackdrop then
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        btn:SetBackdropColor(0, 0, 0, .5)
        btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end

    local btnTxt = btn:CreateFontString(nil, 'OVERLAY')
    btnTxt:SetFont('Fonts\\FRIZQT__.TTF', 12, 'OUTLINE')
    btnTxt:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btnTxt:SetText(text)

    if textColor then
        btnTxt:SetTextColor(textColor[1], textColor[2], textColor[3])
    else
        btnTxt:SetTextColor(1, 1, 1)
    end

    btn.text = btnTxt

    local origEnable = btn.Enable
    local origDisable = btn.Disable

    btn.Enable = function(self)
        origEnable(self)
        if textColor then
            btnTxt:SetTextColor(textColor[1], textColor[2], textColor[3])
        else
            btnTxt:SetTextColor(1, 1, 1)
        end
    end

    btn.Disable = function(self)
        origDisable(self)
        btnTxt:SetTextColor(0.5, 0.5, 0.5)
    end

    if not noHighlight then
        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        highlight:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -4)
        highlight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 4)
        highlight:SetBlendMode("ADD")
    end

    return btn
end

function IS.gui.Font(parent, size, text, colour, align)
    local font = parent:CreateFontString(nil, 'OVERLAY')
    font:SetFont('Fonts\\FRIZQT__.TTF', size or 14, 'OUTLINE')
    colour = colour or {1, 1, 1}
    font:SetTextColor(colour[1], colour[2], colour[3])
    font:SetText(text)
    font.align = align or 'CENTER'
    font:SetJustifyH(font.align)
    return font
end

function IS.gui.Checkbox(parent, text, width, height, textColor)
    local checkbox = CreateFrame("CheckButton", nil, parent or UIParent, "UICheckButtonTemplate")
    checkbox:SetWidth(width or 20)
    checkbox:SetHeight(height or 20)

    local label = checkbox:CreateFontString(nil, 'BACKGROUND')
    label:SetFont('Fonts\\FRIZQT__.TTF', 12, 'OUTLINE')
    label:SetPoint("RIGHT", checkbox, "LEFT", -5, 0)
    label:SetText(text or "Checkbox")

    local defaultColor = textColor or {.9, .9, .9}
    label:SetTextColor(defaultColor[1], defaultColor[2], defaultColor[3])
    checkbox.label = label
    checkbox.defaultColor = defaultColor

    checkbox:SetChecked(false)

    local origEnable = checkbox.Enable
    local origDisable = checkbox.Disable

    checkbox.Enable = function(self)
        origEnable(self)
        self.label:SetTextColor(self.defaultColor[1], self.defaultColor[2], self.defaultColor[3])
    end

    checkbox.Disable = function(self)
        origDisable(self)
        self.label:SetTextColor(0.5, 0.5, 0.5)
    end

    return checkbox
end

function IS.gui.ColorPicker(parent, initialColor, callback)
    local GRID_SIZE = 6
    local SWATCH_SIZE = 20

    local colors = {
        {1, 0, 0}, {0, 1, 0}, {0, 0, 1}, {1, 1, 0}, {1, 0, 1}, {0, 1, 1},
        {1, 0.5, 0}, {0.5, 1, 0}, {0, 0.5, 1}, {1, 0, 0.5}, {0.5, 0, 1}, {0, 1, 0.5},
        {0.8, 0.8, 0.8}, {0.6, 0.6, 0.6}, {0.4, 0.4, 0.4}, {0.2, 0.2, 0.2}, {0, 0, 0}, {1, 1, 1},
        {0.5, 0.25, 0}, {0.25, 0.5, 0}, {0, 0.25, 0.5}, {0.5, 0, 0.25}, {0.25, 0, 0.5}, {0, 0.5, 0.25},
        {1, 0.8, 0.8}, {0.8, 1, 0.8}, {0.8, 0.8, 1}, {1, 1, 0.8}, {1, 0.8, 1}, {0.8, 1, 1},
        {0.6, 0.3, 0.3}, {0.3, 0.6, 0.3}, {0.3, 0.3, 0.6}, {0.6, 0.6, 0.3}, {0.6, 0.3, 0.6}, {0.3, 0.6, 0.6}
    }

    local btn = IS.gui.Button(parent, '', 30, 25, false)
    btn.selectedColor = initialColor or {1, 1, 1}

    local swatch = btn:CreateTexture(nil, 'OVERLAY')
    swatch:SetTexture('Interface\\Buttons\\WHITE8X8')
    swatch:SetPoint('CENTER', btn, 'CENTER', 0, 0)
    swatch:SetWidth(20)
    swatch:SetHeight(15)
    swatch:SetVertexColor(btn.selectedColor[1], btn.selectedColor[2], btn.selectedColor[3])
    btn.swatch = swatch

    local popup = CreateFrame('Frame', nil, UIParent)
    popup:SetWidth(GRID_SIZE * SWATCH_SIZE + 10)
    popup:SetHeight(GRID_SIZE * SWATCH_SIZE + 10)
    popup:SetPoint('TOP', btn, 'BOTTOM', 0, -2)
    popup:SetFrameLevel(btn:GetFrameLevel() + 1)
    popup:SetFrameStrata('DIALOG')
    popup:EnableMouse(true)
    popup:Hide()

    popup:SetBackdrop({bgFile = 'Interface\\Buttons\\WHITE8X8'})
    popup:SetBackdropColor(0, 0, 0, 0.8)

    for i = 1, table.getn(colors) do
        local colorBtn = CreateFrame('Button', nil, popup)
        colorBtn:SetWidth(SWATCH_SIZE)
        colorBtn:SetHeight(SWATCH_SIZE)

        local row = math.floor((i - 1) / GRID_SIZE)
        local col = math.mod(i - 1, GRID_SIZE)
        colorBtn:SetPoint('TOPLEFT', popup, 'TOPLEFT', col * SWATCH_SIZE + 5, -row * SWATCH_SIZE - 5)

        local colorTex = colorBtn:CreateTexture(nil, 'BACKGROUND')
        colorTex:SetTexture('Interface\\Buttons\\WHITE8X8')
        colorTex:SetAllPoints(colorBtn)
        colorTex:SetVertexColor(colors[i][1], colors[i][2], colors[i][3])

        local color = colors[i]
        colorBtn:SetScript('OnClick', function()
            btn.selectedColor = color
            swatch:SetVertexColor(color[1], color[2], color[3])
            popup:Hide()
            if callback then
                callback(color)
            end
        end)
    end

    btn:SetScript('OnClick', function()
        if popup:IsVisible() then
            popup:Hide()
        else
            popup:Show()
        end
    end)

    btn.popup = popup
    return btn
end

function IS.gui.ToggleButton(parent, text, width, height, initialState)
    local btn = IS.gui.Button(parent, text or 'Toggle', width or 100, height or 25, false)
    btn.isToggled = initialState or false

    local function updateAppearance()
        if btn.isToggled then
            btn:SetBackdropColor(0.3, 0.6, 0.3, 0.8)
            btn.text:SetTextColor(1, 1, 1)
        else
            btn:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
            btn.text:SetTextColor(0.9, 0.9, 0.9)
        end
    end

    btn:SetScript('OnClick', function()
        btn.isToggled = not btn.isToggled
        updateAppearance()
        if btn.onToggle then
            btn.onToggle(btn.isToggled)
        end
    end)

    btn.SetToggled = function(self, state)
        self.isToggled = state
        updateAppearance()
    end

    btn.IsToggled = function(self)
        return self.isToggled
    end

    updateAppearance()
    return btn
end

function IS.gui.Confirmbox(message, onAccept, onDecline)
    if IS.gui.activeConfirm then return end
    debugprint('Confirmbox - Init')
    local frame = IS.gui.Frame(UIParent, 200, 100, 0.9, true)
    frame:SetPoint('CENTER', 0, 0)
    frame:SetFrameStrata('DIALOG')
    IS.gui.activeConfirm = frame

    local text = IS.gui.Font(frame, 11, message or 'Confirm?', {1, 1, 1}, 'CENTER')
    text:SetPoint('TOP', frame, 'TOP', 0, -15)
    text:SetWidth(180)

    local acceptBtn = IS.gui.Button(frame, 'Accept', 70, 25)
    acceptBtn:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 15, 10)
    acceptBtn:SetScript('OnClick', function()
        frame:Hide()
        IS.gui.activeConfirm = nil
        if onAccept then onAccept() end
    end)

    local declineBtn = IS.gui.Button(frame, 'Decline', 70, 25)
    declineBtn:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -15, 10)
    declineBtn:SetScript('OnClick', function()
        frame:Hide()
        IS.gui.activeConfirm = nil
        if onDecline then onDecline() end
    end)

    return frame
end

-- function IS.gui.Dropdown(parent, text, width, height)
--     local btn = IS.gui.Button(parent, text or "Dropdown", width or 120, height or 25)

--     local popup = CreateFrame("Frame", nil, UIParent)
--     popup:SetWidth(btn:GetWidth())
--     popup:SetHeight(50)
--     popup:SetPoint("TOP", btn, "BOTTOM", 0, -2)
--     popup:SetFrameLevel(btn:GetFrameLevel() + 1)
--     popup:SetFrameStrata("DIALOG")
--     popup:EnableMouse(true)
--     popup:Hide()

--     local bg = popup:CreateTexture(nil, "BACKGROUND")
--     bg:SetTexture("Interface\\Buttons\\WHITE8X8")
--     bg:SetAllPoints(popup)
--     bg:SetVertexColor(0, 0, 0, 0.8)

--     btn.popup = popup
--     btn.selectedValue = nil
--     btn.items = {}

--     btn.Clear = function(self)
--         for i = 1, table.getn(self.items) do
--             self.items[i]:Hide()
--         end
--         self.items = {}
--         popup:SetHeight(10)
--     end

--     btn.AddItem = function(self, itemText, callback)
--         local itemBtn = IS.gui.Button(popup, itemText, popup:GetWidth() - 4, 20, true)
--         itemBtn:SetPoint("TOP", popup, "TOP", 0, -(table.getn(self.items)) * 22 - 5)
--         itemBtn:SetScript("OnClick", callback or function()
--             btn.text:SetText(itemText)
--             btn.selectedValue = itemText
--             popup:Hide()
--         end)
--         table.insert(self.items, itemBtn)
--         popup:SetHeight(table.getn(self.items) * 22 + 10)
--     end

--     btn:SetScript("OnClick", function()
--         if popup:IsVisible() then
--             popup:Hide()
--         else
--             popup:Show()
--         end
--     end)

--     return btn
-- end

function IS.gui.Slider(parent, name, text, minVal, maxVal, step, format, width, height)
    local slider = CreateFrame("Slider", name, parent)
    slider:SetWidth(width or 136)
    slider:SetHeight(height or 24)
    slider:SetOrientation("HORIZONTAL")
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 }
    })

    slider:SetMinMaxValues(minVal or 0, maxVal or 5)
    slider:SetValueStep(step or 0.1)

    local label = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, -0)
    label:SetText(text or "Slider")
    label:SetFont('Fonts\\FRIZQT__.TTF', 12, "OUTLINE")
    label:SetTextColor(0.65, 0.65, 0.65)
    slider.label = label

    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueText:SetPoint("LEFT", slider, "RIGHT", 5, 1)
    valueText:SetTextColor(1, 1, 1)
    valueText:SetFont('Fonts\\FRIZQT__.TTF', 12, "OUTLINE")
    slider.valueText = valueText

    local fmt = format or "%.1f"

    slider:SetValue(minVal or 0)
    valueText:SetText(string.format(fmt, minVal or 0))

    local function updateValueText()
        local newValue = slider:GetValue()
        local roundedValue = math.floor(newValue * 10 + 0.5) / 10
        valueText:SetText(string.format(fmt, roundedValue))
    end

    slider.updateValueText = updateValueText
    slider:SetScript("OnValueChanged", updateValueText)

    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function()
        local wheelStep = step or 0.1
        local value = this:GetValue()
        local minValue, maxValue = this:GetMinMaxValues()

        if arg1 > 0 then
            value = math.min(value + wheelStep, maxValue)
        else
            value = math.max(value - wheelStep, minValue)
        end
        this:SetValue(value)
    end)

    local origEnable = slider.Enable
    local origDisable = slider.Disable

    slider.Enable = function(self)
        origEnable(self)
        self.label:SetTextColor(.9,.9,.9)
        self.valueText:SetTextColor(1, 1, 1)
    end

    slider.Disable = function(self)
        origDisable(self)
        self.label:SetTextColor(0.5, 0.5, 0.5)
        self.valueText:SetTextColor(0.5, 0.5, 0.5)
    end

    return slider
end
