---@diagnostic disable: deprecated
setfenv(1, DFRL:GetEnvironment())
d:DebugPrint("BOOTING")

-- templates
function CreateSlider(parent, name, moduleName, key, minVal, maxVal)
    local slider = CreateFrame("Slider", name, parent)
    slider:SetWidth(136)
    slider:SetHeight(24)
    slider:SetOrientation("HORIZONTAL")
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 }
    })

    -- range
    slider:SetMinMaxValues(minVal or 0, maxVal or 5)
    slider:SetValueStep(0.1)

    -- label
    local label = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, -0)
    local displayText = string.gsub(key, "(%l)(%u)", "%1 %2")
    displayText = string.upper(string.sub(displayText, 1, 1)) .. string.sub(displayText, 2)
    label:SetText(displayText)
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    label:SetTextColor(.9,.9,.9)
    slider.label = label

    -- value display
    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueText:SetPoint("LEFT", slider, "RIGHT", 1, -0)
    valueText:SetTextColor(1, 1, 1)
    valueText:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    slider.valueText = valueText

    -- expose module and key for handler
    slider.moduleName = moduleName
    slider.configKey = key

    -- get initial state
    local currentValue = DFRL:GetConfig(moduleName, key)
    slider:SetValue(currentValue)
    valueText:SetText(string.format("%.1f", currentValue))

    -- set handler
    slider:SetScript("OnValueChanged", function()
        local newValue = this:GetValue()
        this.valueText:SetText(string.format("%.1f", newValue))
        DFRL:SetConfig(this.moduleName, this.configKey, newValue)
    end)

    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function()
        local step = 0.1
        local value = this:GetValue()
        local minValue, maxValue = this:GetMinMaxValues()

        if arg1 > 0 then
            value = math.min(value + step, maxValue)
        else
            value = math.max(value - step, minValue)
        end
        this:SetValue(value)
    end)

    return slider
end

function CreateColourSlider(parent, name, moduleName, key)

    local BASIC_COLORS = {
        -- red variants
        {1.0, 0.0, 0.0},      -- red
        {1.0, 0.6, 0.6},      -- light red
        {0.8, 0.0, 0.2},      -- exotic red
        -- white variants
        {1.0, 1.0, 1.0},      -- white
        {0.9, 0.9, 0.9},      -- light white (gray)
        {1.0, 0.95, 0.9},     -- exotic white (ivory)
        -- blue variants
        {0.0, 0.0, 1.0},      -- blue
        {0.6, 0.6, 1.0},      -- light blue
        {0.0, 0.2, 0.8},      -- exotic blue (deep)
        -- yellow variants
        {1.0, 1.0, 0.0},      -- yellow
        {1.0, 1.0, 0.6},      -- light yellow
        {0.8, 0.8, 0.0},      -- exotic yellow (mustard)
        -- magenta variants
        {1.0, 0.0, 1.0},      -- magenta
        {1.0, 0.6, 1.0},      -- light magenta
        {0.7, 0.0, 0.7},      -- exotic magenta (deep pink)
        -- cyan variants
        {0.0, 1.0, 1.0},      -- cyan
        {0.6, 1.0, 1.0},      -- light cyan
        {0.0, 0.7, 0.7},      -- exotic cyan (teal)
        -- orange variants
        {1.0, 0.5, 0.0},      -- orange
        {1.0, 0.75, 0.4},     -- light orange
        {0.8, 0.3, 0.0},      -- exotic orange (burnt)
        -- purple variants
        {0.5, 0.0, 1.0},      -- purple
        {0.8, 0.6, 1.0},      -- light purple
        {0.4, 0.0, 0.6},      -- exotic purple (violet)
        -- teal variants
        {0.0, 0.5, 0.5},      -- teal
        {0.4, 0.8, 0.8},      -- light teal
        {0.0, 0.4, 0.6},      -- exotic teal (deep sea)
        -- gold variants
        {1.0, 0.82, 0.0},     -- gold
        {1.0, 0.9, 0.5},      -- light gold
        {0.8, 0.65, 0.0},     -- exotic gold (bronze)
    }

    local COLOR_COUNT = 30

    local slider = CreateFrame("Slider", name, parent)
    slider:SetWidth(136)
    slider:SetHeight(24)
    slider:SetOrientation("HORIZONTAL")
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 }
    })

    -- range for color index
    slider:SetMinMaxValues(1, COLOR_COUNT)
    slider:SetValueStep(1)

    -- label
    local label = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, -0)
    local displayText = string.gsub(key, "(%l)(%u)", "%1 %2")
    displayText = string.upper(string.sub(displayText, 1, 1)) .. string.sub(displayText, 2)
    label:SetText(displayText)
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    label:SetTextColor(.9,.9,.9)
    slider.label = label

    -- value display
    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueText:SetPoint("LEFT", slider, "RIGHT", 1, -0)
    valueText:SetTextColor(1, 1, 1)
    valueText:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    slider.valueText = valueText

    -- expose module and key for handler
    slider.moduleName = moduleName
    slider.configKey = key

    -- color swatch
    local colorSwatch = parent:CreateTexture(nil, "ARTWORK")
    colorSwatch:SetWidth(20)
    colorSwatch:SetHeight(20)
    colorSwatch:SetPoint("LEFT", valueText, "RIGHT", 5, 0)
    colorSwatch:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")

    -- find closest color index for current value
    local currentValue = DFRL:GetConfig(moduleName, key)
    local initialIndex = 1

    if type(currentValue) == "table" and table.getn(currentValue) >= 3 then
        local r, g, b = currentValue[1], currentValue[2], currentValue[3]

        colorSwatch:SetVertexColor(r, g, b)

        for i=1, COLOR_COUNT do
            if BASIC_COLORS[i][1] == r and BASIC_COLORS[i][2] == g and BASIC_COLORS[i][3] == b then
                initialIndex = i
                break
            end
        end
    else
        colorSwatch:SetVertexColor(BASIC_COLORS[1][1], BASIC_COLORS[1][2], BASIC_COLORS[1][3])
    end

    slider:SetValue(initialIndex)
    valueText:SetText(initialIndex)

    slider:SetScript("OnValueChanged", function()
        local newValue = this:GetValue()
        local index = math.floor(newValue + 0.5)
        if index < 1 then index = 1 end
        if index > COLOR_COUNT then index = COLOR_COUNT end

        valueText:SetText(index)
        colorSwatch:SetVertexColor(BASIC_COLORS[index][1], BASIC_COLORS[index][2], BASIC_COLORS[index][3])
        DFRL:SetConfig(moduleName, key, BASIC_COLORS[index])
    end)

    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function()
        local step = 1
        local value = this:GetValue()
        local minValue, maxValue = this:GetMinMaxValues()

        if arg1 > 0 then
            value = math.min(value + step, maxValue)
        else
            value = math.max(value - step, minValue)
        end
        this:SetValue(value)
    end)
    return slider
end

function CreateShaguCheckbox(parent, name, key)
    d:DebugPrint("Creating checkbox for "..key)
    local checkbox = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    checkbox:SetWidth(20)
    checkbox:SetHeight(20)

    -- label
    local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    label:SetText(key)
    label:SetTextColor(.9,.9,.9)
    checkbox.label = label

    -- get initial state from ShaguTweaks_config
    local initial = (ShaguTweaks_config[key] == 1)
    checkbox:SetChecked(initial)
    d:DebugPrint("Initial state for "..key..": "..tostring(initial))

    -- set handler for ShaguTweaks
    checkbox:SetScript("OnClick", function()
        local checked = checkbox:GetChecked() and true or false
        d:DebugPrint(key.." clicked, checked="..tostring(checked))

        if checked then
            ShaguTweaks_config[key] = 1
            d:DebugPrint("ShaguTweaks_config["..key.."] = 1")
            local mod = ShaguTweaks.mods[key]
            if mod and mod.enable then
                d:DebugPrint("Enabling module "..key)
                mod:enable()
            end
        else
            ShaguTweaks_config[key] = 0
            d:DebugPrint("ShaguTweaks_config["..key.."] = 0")
            local mod = ShaguTweaks.mods[key]
            if mod and mod.disable then
                d:DebugPrint("Disabling module "..key)
                mod:disable()
            end
        end
    end)

    return checkbox
end

function CreateCheckbox(parent, name, moduleName, key)
    local checkbox = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    checkbox:SetWidth(20)
    checkbox:SetHeight(20)

    local label = checkbox:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    local displayText = string.gsub(key, "(%l)(%u)", "%1 %2")
    displayText = string.upper(string.sub(displayText, 1, 1)) .. string.sub(displayText, 2)
    label:SetText(displayText)
    label:SetTextColor(.9,.9,.9)
    checkbox.label = label

    local currentValue = DFRL:GetConfig(moduleName, key)
    checkbox:SetChecked(currentValue)

    checkbox:SetScript("OnClick", function()
        local isChecked = this:GetChecked()
        local newValue = false
        if isChecked then
            newValue = true
        end
        DFRL:SetConfig(moduleName, key, newValue)
    end)

    return checkbox
end

local DROPDOWN_WIDTH = 165
local DROPDOWN_HEIGHT = 27
local OPTION_HEIGHT = 18
local OPTION_PADDING = 2
local LIST_PADDING = 5
local ARROW_WIDTH = 20
local TEXT_PADDING = 15

function CreateConfigDropdown(parent, name, moduleName, key, options)
    d:DebugPrint("Creating custom dropdown: " .. name)

    local currentValue = DFRL:GetConfig(moduleName, key)
    local defaultText = currentValue or "Select Option"

    if not name or not parent or not options then
        d:DebugPrint("ERROR: Missing required parameters for dropdown creation")
        return nil
    end

    d:DebugPrint("Custom dropdown parameters - options count: " .. table.getn(options))

    -- dropdown frame
    local dropdown = CreateFrame("Frame", name, parent)
    dropdown:SetWidth(DROPDOWN_WIDTH)
    dropdown:SetHeight(DROPDOWN_HEIGHT)
    dropdown:SetPoint("CENTER", parent, "CENTER", 0, 0)
    dropdown:SetFrameStrata("TOOLTIP")
    dropdown:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background"})
    dropdown:SetBackdropColor(0, 0, 0, 1)

    d:DebugPrint("Main dropdown frame created: " .. name)

    local currentText = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentText:SetPoint("LEFT", dropdown, "LEFT", TEXT_PADDING, 0)
    currentText:SetPoint("RIGHT", dropdown, "RIGHT", -(ARROW_WIDTH + 5), 0)
    currentText:SetText(defaultText)
    currentText:SetJustifyH("CENTER")

    local arrowButton = CreateFrame("Button", name .. "Arrow", dropdown)
    arrowButton:SetWidth(ARROW_WIDTH)
    arrowButton:SetHeight(ARROW_WIDTH)
    arrowButton:SetPoint("RIGHT", dropdown, "RIGHT", -5, 0)
    local arrowTexture = arrowButton:CreateTexture(nil, "OVERLAY")
    arrowTexture:SetAllPoints(arrowButton)
    arrowTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    d:DebugPrint("Dropdown button and text created")

    -- store state
    dropdown.isOpen = false
    dropdown.optionsList = nil

    d:DebugPrint("Stored " .. table.getn(options) .. " options in custom dropdown")

    local function ToggleDropdown()
        if dropdown.isOpen then
            d:DebugPrint("Closing dropdown list")
            if dropdown.optionsList then
                dropdown.optionsList:Hide()
            end
            dropdown.isOpen = false
            return
        end

        d:DebugPrint("Opening dropdown list")

        -- options list
        if not dropdown.optionsList then
            d:DebugPrint("Creating new options list frame")

            local listHeight = (table.getn(options) * (OPTION_HEIGHT + OPTION_PADDING)) + (LIST_PADDING * 2) - OPTION_PADDING
            local listFrame = CreateFrame("Frame", name .. "List", dropdown)
            listFrame:SetWidth(DROPDOWN_WIDTH)
            listFrame:SetHeight(listHeight)
            listFrame:SetPoint("TOP", dropdown, "BOTTOM", 0, 5)
            listFrame:SetFrameStrata("TOOLTIP")
            listFrame:SetToplevel(true)
            listFrame:SetBackdrop({bgFile = "Interface\\Buttons\\White8X8"})
            listFrame:SetBackdropColor(0, 0, 0, 1)
            listFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            dropdown.optionsList = listFrame

            d:DebugPrint("Options list frame created with height: " .. listFrame:GetHeight())

            for i = 1, table.getn(options) do
                local optionButton = CreateFrame("Button", name .. "Option" .. i, listFrame)
                optionButton:SetWidth(DROPDOWN_WIDTH - (LIST_PADDING * 2) - 22)
                optionButton:SetHeight(OPTION_HEIGHT)
                optionButton:SetPoint("TOP", listFrame, "TOP", 0, -(LIST_PADDING + ((i-1) * (OPTION_HEIGHT + OPTION_PADDING))))

                local buttonText = optionButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                buttonText:SetPoint("LEFT", optionButton, "LEFT", TEXT_PADDING - 10, 0)
                buttonText:SetPoint("RIGHT", optionButton, "RIGHT", -5, 0)
                buttonText:SetText(options[i])
                buttonText:SetJustifyH("CENTER")

                d:DebugPrint("Created option button " .. i .. ": " .. options[i])

                -- Hover effects
                optionButton:SetScript("OnEnter", function()
                    optionButton:SetBackdrop({bgFile = "Interface\\Buttons\\White8X8"})
                    optionButton:SetBackdropColor(0.2, 0.2, 0.8, 1)
                end)
                optionButton:SetScript("OnLeave", function()
                    optionButton:SetBackdrop(nil)
                end)

                optionButton.optionValue = options[i]
                optionButton.optionIndex = i

                -- handler
                optionButton:SetScript("OnClick", function()
                    d:DebugPrint("=== OPTION CLICKED ===")
                    d:DebugPrint("Selected: " .. optionButton.optionValue .. " (index: " .. optionButton.optionIndex .. ")")

                    currentText:SetText(optionButton.optionValue)
                    dropdown.optionsList:Hide()
                    dropdown.isOpen = false

                    d:DebugPrint("Dropdown state updated - selectedIndex: " .. optionButton.optionIndex)

                    -- save config
                    DFRL:SetConfig(moduleName, key, optionButton.optionValue)
                    d:DebugPrint("Dropdown config saved: " .. moduleName .. "." .. key .. " = " .. optionButton.optionValue)
                    d:DebugPrint("=== END OPTION CLICK ===")
                end)
            end
        end

        dropdown.optionsList:Show()
        dropdown.isOpen = true
        d:DebugPrint("Dropdown list shown with " .. table.getn(options) .. " options")
    end

    -- handlers
    dropdown:SetScript("OnMouseDown", function()
        d:DebugPrint("Main dropdown clicked")
        ToggleDropdown()
    end)

    arrowButton:SetScript("OnClick", function()
        d:DebugPrint("Arrow button clicked")
        ToggleDropdown()
    end)

    dropdown:SetScript("OnUpdate", function()
        if dropdown.isOpen then
            if not MouseIsOver(dropdown) and not MouseIsOver(dropdown.optionsList) then
                dropdown.optionsList:Hide()
                dropdown.isOpen = false
            end
        end
    end)

    dropdown:Show()
    d:DebugPrint("Custom dropdown creation complete: " .. name)
    return dropdown
end

function CreateCategoryHeader(parent, categoryName)
    local categoryBg = CreateFrame("Frame", nil, parent)
    categoryBg:SetWidth(180)
    categoryBg:SetHeight(25)
    categoryBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    categoryBg:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
    categoryBg:SetBackdropBorderColor(0.1, 0.1, 0.1, 0.5)

    -- title
    local categoryTitle = categoryBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    categoryTitle:SetPoint("CENTER", categoryBg, "CENTER", 0, 1)
    ---@diagnostic disable-next-line: undefined-field
    local words = string.gfind(categoryName, "%S+")
    local capitalizedWords = {}
    for word in words do
        table.insert(capitalizedWords, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
    end
    categoryTitle:SetText(table.concat(capitalizedWords, " "))
    categoryTitle:SetTextColor(1, 0.82, 0)

    return categoryBg
end
