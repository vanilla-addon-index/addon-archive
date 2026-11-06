-- Recommended width: 100+ px / Recommended height: 36-40 px

PTGuiEditBoxSlider = PTGuiComponent:Extend("editbox_slider")
PTGuiEditBoxSlider:ImportComponent("slider", true, "SetMinMaxValues", "SetValue", "SetValueStep")
PTGuiEditBoxSlider:ImportComponent("slider", false, "GetMinMaxValues", "GetValue", "GetValueStep")
PTGuiEditBoxSlider:ImportComponent("editbox", true, "SetText")
PTGuiEditBoxSlider:ImportComponent("editbox", false, "GetText")

function PTGuiEditBoxSlider:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName(), nil)
    obj:SetHandle(frame)
    local slider = PTGuiLib.Get("slider", frame)
    obj:AddComponent("slider", slider)
    local editbox = PTGuiLib.Get("editbox", frame)
    obj:AddComponent("editbox", editbox)
    return obj
end

function PTGuiEditBoxSlider:OnAcquire()
    self.super.OnAcquire(self)

    local slider = self:GetSlider()
    local editbox = self:GetEditbox()
    self:SetPrimary()

    slider:SetPoint("TOPLEFT", self, "TOPLEFT")
    slider:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 20)
    editbox:SetJustifyH("CENTER")
    self:SetEditboxPadding(35)

    slider:GetHandle():SetHitRectInsets(0, 0, 0, 3)

    slider:SetScript("OnValueChanged", function()
        if not editbox.hasFocus then
            editbox:SetText(slider:GetValue())
        end
    end, true)
    editbox:SetText(slider:GetValue())

    editbox:SetScript("OnTextChanged", function()
        slider:SetValue(editbox:GetHandle():GetNumber())
    end, true)

    editbox:SetScript("OnEditFocusGained", function()
        editbox.hasFocus = true
        editbox:GetHandle():HighlightText()
    end, true)

    editbox:SetScript("OnEditFocusLost", function()
        editbox:SetText(slider:GetValue())
        editbox.hasFocus = nil
    end, true)

    editbox:SetScript("OnEnterPressed", function()
        editbox:GetScript("OnTextChanged")()
        editbox:ClearFocus()
    end, true)
end

-- TODO: Handle disposal
function PTGuiEditBoxSlider:OnDispose()
    self.super.OnDispose(self)
end

function PTGuiEditBoxSlider:GetSlider()
    return self:GetComponent("slider")
end

function PTGuiEditBoxSlider:GetEditbox()
    return self:GetComponent("editbox")
end

function PTGuiEditBoxSlider:SetEditboxPadding(padding)
    local editbox = self:GetEditbox()
    editbox:ClearAllPoints()
    editbox:SetPoint("TOPLEFT", self:GetSlider(), "BOTTOMLEFT", padding, 0)
    editbox:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -padding, 0)
end

PTGuiLib.RegisterComponent(PTGuiEditBoxSlider)