local HS = OSHS

local panel = CreateFrame("Frame", "OSHSOptions", UIParent)
panel:SetWidth(500); panel:SetHeight(620)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
panel:SetFrameStrata("DIALOG")
panel:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
panel:Hide(); panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() this:StartMoving() end)
panel:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local point, _, _, x, y = this:GetPoint(1)
    HS.db.optionsPoint, HS.db.optionsX, HS.db.optionsY = point or "CENTER", x or 0, y or 0
end)

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", panel, "TOP", 0, -18); title:SetText("OSRS Hit Splashes")
local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -7); subtitle:SetText("/oshs test previews the current style")
local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)

local checks = {}
local function addCheck(label, key, x, y, callback)
    local button = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("LEFT", button, "RIGHT", 2, 0); button.text:SetText(label)
    button.key = key
    button:SetScript("OnClick", function()
        HS.db[key] = this:GetChecked() and true or false
        if callback then callback() end
    end)
    table.insert(checks, button)
end

addCheck("Enable hitsplats", "enabled", 22, -62)
addCheck("Show damage", "showDamage", 178, -62)
addCheck("Show healing", "showHealing", 334, -62)
addCheck("Show misses as 0", "showMisses", 22, -94)
addCheck("Damage-school splats", "colorBySchool", 178, -94)
addCheck("Gold critical numbers", "critColor", 334, -94)
addCheck("Show damage taken", "showDamageTaken", 22, -126)
addCheck("Target-frame fallback", "useTargetFrame", 178, -126)
addCheck("Show interrupt messages", "showInterrupts", 22, -154)
addCheck("Disable floating combat text", "disableFloatingCombatText", 178, -154, function() HS:ApplyNativeTextSetting() end)

local sliders, sliderCount = {}, 0
local function formatValue(value, step)
    if step >= 1 then return tostring(math.floor(value + .5)) end
    return string.format("%.2f", value)
end
local function addSlider(label, key, minValue, maxValue, step, x, y)
    sliderCount = sliderCount + 1
    local slider = CreateFrame("Slider", "OSHSSlider" .. sliderCount, panel, "OptionsSliderTemplate")
    slider:SetWidth(205); slider:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    slider:SetMinMaxValues(minValue, maxValue); slider:SetValueStep(step)
    getglobal(slider:GetName() .. "Low"):SetText(tostring(minValue))
    getglobal(slider:GetName() .. "High"):SetText(tostring(maxValue))
    slider.label = getglobal(slider:GetName() .. "Text")
    slider.key, slider.baseLabel, slider.step = key, label, step
    slider:SetScript("OnValueChanged", function()
        local value = this:GetValue()
        if step >= 1 then value = math.floor(value + .5) else value = math.floor(value * 20 + .5) / 20 end
        HS.db[key] = value
        this.label:SetText(label .. ": " .. formatValue(value, step))
    end)
    table.insert(sliders, slider)
end

addSlider("Overall scale", "scale", .65, 1.5, .05, 25, -199)
addSlider("Text size", "textSize", 12, 34, 1, 270, -199)
addSlider("Hold duration", "duration", .5, 3, .05, 25, -259)
addSlider("Vertical offset", "offsetY", -100, 50, 1, 270, -259)
addSlider("Horizontal offset", "offsetX", -100, 100, 1, 25, -319)
addSlider("Side spacing", "horizontalSpacing", 10, 50, 1, 270, -319)
addSlider("Row spacing", "verticalSpacing", 10, 50, 1, 25, -379)

local statusTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -420)
statusTitle:SetText("Scrolling status effects")
addCheck("Show buff, debuff, and fade messages", "showStatusEffects", 22, -438)
addCheck("Show status icons", "statusShowIcons", 292, -438)
addSlider("Status text size", "statusTextSize", 12, 28, 1, 25, -486)
addSlider("Status duration", "statusDuration", .5, 4, .05, 270, -486)
addSlider("Status rise", "statusRiseDistance", 0, 100, 5, 25, -546)

local preview = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
preview:SetWidth(105); preview:SetHeight(24); preview:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 22, 14); preview:SetText("Hitsplat test")
preview:SetScript("OnClick", function() HS:Preview() end)
local statusPreview = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
statusPreview:SetWidth(105); statusPreview:SetHeight(24); statusPreview:SetPoint("LEFT", preview, "RIGHT", 10, 0); statusPreview:SetText("Status test")
statusPreview:SetScript("OnClick", function()
    HS:ShowStatusEffect("+ Arcane Intellect", .45, 1, .55, "Interface\\Icons\\Spell_Holy_MagicalSentry", "preview:buff")
    HS:ShowStatusEffect("- Poison", 1, .3, .45, "Interface\\Icons\\Spell_Nature_CorrosiveBreath", "preview:debuff")
    HS:ShowStatusEffect("-Blessing faded", .65, .65, .65, nil, "preview:fade")
end)
local anchorButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
anchorButton:SetWidth(130); anchorButton:SetHeight(24); anchorButton:SetPoint("LEFT", statusPreview, "RIGHT", 10, 0)
anchorButton:SetScript("OnClick", function() HS:SetStatusAnchorLocked(not HS.db.statusAnchorLocked) end)
local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reset:SetWidth(85); reset:SetHeight(24); reset:SetPoint("LEFT", anchorButton, "RIGHT", 10, 0); reset:SetText("Reset")
reset:SetScript("OnClick", function() HS:ResetSettings(); HS:RefreshOptions(); HS:Preview() end)

function HS:UpdateStatusAnchorButton()
    anchorButton:SetText(self.db.statusAnchorLocked and "Move anchor" or "Lock anchor")
end

function HS:RefreshOptions()
    local _, check, slider
    for _, check in ipairs(checks) do check:SetChecked(self.db[check.key]) end
    for _, slider in ipairs(sliders) do
        slider:SetValue(self.db[slider.key])
        slider.label:SetText(slider.baseLabel .. ": " .. formatValue(self.db[slider.key], slider.step))
    end
    self:UpdateStatusAnchorButton()
end

panel:SetScript("OnShow", function()
    panel:ClearAllPoints()
    panel:SetPoint(HS.db.optionsPoint or "CENTER", UIParent, HS.db.optionsPoint or "CENTER", HS.db.optionsX or 0, HS.db.optionsY or 0)
    HS:RefreshOptions()
end)

function HS:ToggleOptions()
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

function HS:ApplyPfUISkin()
    if panel.pfUISkinned or not pfUI or not pfUI.api then return end
    local api = pfUI.api
    if not api.CreateBackdrop or not api.SkinButton then return end
    panel:SetBackdrop(nil); api.CreateBackdrop(panel, nil, true, .88)
    if api.CreateBackdropShadow then api.CreateBackdropShadow(panel) end
    if api.SkinCloseButton then api.SkinCloseButton(close, panel.backdrop, -4, -4) end
    local _, widget
    if api.SkinCheckbox then for _, widget in ipairs(checks) do api.SkinCheckbox(widget) end end
    api.SkinButton(preview); api.SkinButton(statusPreview); api.SkinButton(anchorButton); api.SkinButton(reset)
    if api.SkinSlider then for _, widget in ipairs(sliders) do api.SkinSlider(widget) end end
    panel.pfUISkinned = true
end

if pfUI then pcall(function() HS:ApplyPfUISkin() end) end
