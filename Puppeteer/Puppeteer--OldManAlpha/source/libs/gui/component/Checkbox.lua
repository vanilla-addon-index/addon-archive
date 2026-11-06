PTGuiCheckbox = PTGuiComponent:Extend("checkbox")
PTGuiCheckbox:Import(true, "SetChecked", "Enable", "Disable")
PTGuiCheckbox:Import(false, "GetChecked")

-- Texture coords that makes the checkbox larger and more centered
local minX, maxX, minY, maxY = 2 / 32, 29 / 32, 2 / 32, 28 / 32

function PTGuiCheckbox:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("CheckButton", self:GenerateName(), nil, "UICheckButtonTemplate")
    obj:SetHandle(frame)
    frame:GetNormalTexture():SetTexCoord(minX, maxX, minY, maxY)
    frame:GetHighlightTexture():SetTexCoord(minX, maxX, minY, maxY)
    frame:GetPushedTexture():SetTexCoord(minX, maxX, minY, maxY)
    frame:GetCheckedTexture():SetTexCoord(minX, maxX, minY, maxY)
    frame:GetDisabledCheckedTexture():SetTexCoord(minX, maxX, minY, maxY)
    return obj
end

function PTGuiCheckbox:OnDispose()
    self.super.OnDispose(self)

    self:SetChecked(false)
end

function PTGuiCheckbox:SetScript(scriptName, script, noSelf)
    if scriptName ~= "OnClick" then
        return self.super.SetScript(self, scriptName, script, noSelf)
    end
    self:GetHandle():SetScript(scriptName, function()
        if self:GetChecked() then
            PlaySound("igMainMenuOptionCheckBoxOn")
        else
            PlaySound("igMainMenuOptionCheckBoxOff")
        end
        if script then
            script(self)
        end
    end)
    return self
end

PTGuiLib.RegisterComponent(PTGuiCheckbox)