PTGuiSlider = PTGuiComponent:Extend("slider")
local _G = getfenv(0)
PTGuiSlider:Import(true, "Enable", "Disable", "SetMinMaxValues", "SetOrientation", "SetValue", "SetValueStep")
PTGuiSlider:Import(false, "GetMinMaxValues", "GetOrientation", "GetValue", "GetValueStep")

function PTGuiSlider:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Slider", self:GenerateName(), nil, "OptionsSliderTemplate")
    obj:SetHandle(frame)
    return obj
end

function PTGuiSlider:OnAcquire()
    self.super.OnAcquire(self)
    self:SetMinMaxValues(1, 10)
    self:SetValueStep(1)
    self:SetValue(1)
end

function PTGuiSlider:OnDispose()
    self.super.OnDispose(self)
    self:SetText("")
    self:SetLowText("Low")
    self:SetHighText("High")
    self:SetFontSize(10)
    self:SetOrientation("HORIZONTAL")
end

function PTGuiSlider:SetText(text)
    _G[self:GetName().."Text"]:SetText(text)
end

function PTGuiSlider:SetLowText(text)
    _G[self:GetName().."Low"]:SetText(text)
end

function PTGuiSlider:SetHighText(text)
    _G[self:GetName().."High"]:SetText(text)
end

function PTGuiSlider:SetNumberedText()
    local min, max = self:GetMinMaxValues()
    self:SetLowText(min)
    self:SetHighText(max)
end

function PTGuiSlider:SetFontSize(fontSize)
    local font, _, flags = _G[self:GetName().."Text"]:GetFont()
    _G[self:GetName().."Text"]:SetFont(font, fontSize, flags)
    local font, _, flags = _G[self:GetName().."Low"]:GetFont()
    _G[self:GetName().."Low"]:SetFont(font, fontSize, flags)
    local font, _, flags = _G[self:GetName().."High"]:GetFont()
    _G[self:GetName().."High"]:SetFont(font, fontSize, flags)
end

PTGuiLib.RegisterComponent(PTGuiSlider)