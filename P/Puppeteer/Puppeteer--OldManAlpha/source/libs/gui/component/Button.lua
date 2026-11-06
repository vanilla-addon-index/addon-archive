-- Buttons created by this are modified to not stretch at the corners, making for cleaner looking buttons.
PTGuiButton = PTGuiComponent:Extend("button")
PTGuiButton:Import(true, "SetText", "Enable", "Disable")
PTGuiButton:Import(false, "GetText", "IsEnabled")
local _G = getfenv(0)

function PTGuiButton:New()
    local obj = setmetatable({}, self)
    obj:SetHandle(CreateFrame("Button", self:GenerateName(), nil, "UIPanelButtonTemplate"))
    obj:SetupTextures()
    return obj
end

function PTGuiButton:OnAcquire()
    self.super.OnAcquire(self)
    self:SetClickSound(_G.PlaySound, "GAMESPELLBUTTONMOUSEDOWN")
end

function PTGuiButton:OnDispose()
    self.super.OnDispose(self)
    self:SetText("")
    self:SetEnabled(true)
    self:SetUseDefaultTextures(false)
    -- TODO: Restore default textures to default state
end

function PTGuiButton:SetupTextures()
    local button = self:GetHandle()

    self.NormalTexture = button:GetNormalTexture()
    self.NormalTexture:SetTexture(nil)
    self.PushedTexture = button:GetPushedTexture()
    self.PushedTexture:SetTexture(nil)
    self.DisabledTexture = button:GetDisabledTexture()
    self.DisabledTexture:SetTexture(nil)
    self.HighlightTexture = button:GetHighlightTexture()

    local topLeft = button:CreateTexture(button:GetName().."TopLeft", "BACKGROUND")
    topLeft:SetWidth(7)
    topLeft:SetHeight(7)
    topLeft:SetPoint("TOPLEFT", button, "TOPLEFT")
    topLeft:SetTexCoord(1 / 128, 8 / 128, 1 / 32, 8 / 32)

    local topRight = button:CreateTexture(button:GetName().."TopRight", "BACKGROUND")
    topRight:SetWidth(7)
    topRight:SetHeight(7)
    topRight:SetPoint("TOPRIGHT", button, "TOPRIGHT")
    topRight:SetTexCoord(72 / 128, 79 / 128, 1 / 32, 8 / 32)

    local topMid = button:CreateTexture(button:GetName().."TopMid", "BACKGROUND")
    topMid:SetPoint("TOPLEFT", topLeft, "TOPRIGHT")
    topMid:SetPoint("BOTTOMRIGHT", topRight, "BOTTOMLEFT")
    topMid:SetTexCoord(9 / 128, 70 / 128, 1 / 32, 8 / 32)

    local botLeft = button:CreateTexture(button:GetName().."BotLeft", "BACKGROUND")
    botLeft:SetWidth(7)
    botLeft:SetHeight(7)
    botLeft:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT")
    botLeft:SetTexCoord(1 / 128, 8 / 128, 15 / 32, 22 / 32)

    local botRight = button:CreateTexture(button:GetName().."BotRight", "BACKGROUND")
    botRight:SetWidth(7)
    botRight:SetHeight(7)
    botRight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
    botRight:SetTexCoord(72 / 128, 79 / 128, 15 / 32, 22 / 32)

    local botMid = button:CreateTexture(button:GetName().."BotMid", "BACKGROUND")
    botMid:SetPoint("TOPLEFT", botLeft, "TOPRIGHT")
    botMid:SetPoint("BOTTOMRIGHT", botRight, "BOTTOMLEFT")
    botMid:SetTexCoord(9 / 128, 70 / 128, 15 / 32, 22 / 32)

    local midLeft = button:CreateTexture(button:GetName().."MidLeft", "BACKGROUND")
    midLeft:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT")
    midLeft:SetPoint("BOTTOMRIGHT", botLeft, "TOPRIGHT")
    midLeft:SetTexCoord(1 / 128, 8 / 128, 9 / 32, 13 / 32)

    local midRight = button:CreateTexture(button:GetName().."MidRight", "BACKGROUND")
    midRight:SetPoint("TOPLEFT", topRight, "BOTTOMLEFT")
    midRight:SetPoint("BOTTOMRIGHT", botRight, "TOPRIGHT")
    midRight:SetTexCoord(72 / 128, 79 / 128, 9 / 32, 13 / 32)

    local center = button:CreateTexture(button:GetName().."Center", "BACKGROUND")
    center:SetPoint("TOPLEFT", topLeft, "BOTTOMRIGHT")
    center:SetPoint("BOTTOMRIGHT", botRight, "TOPLEFT")
    center:SetTexCoord(9 / 128, 70 / 128, 9 / 32, 13 / 32)

    button.textures = {topLeft, topMid, topRight, botLeft, botMid, botRight, midLeft, center, midRight}

    button:SetScript("OnMouseDown", function()
        if button:IsEnabled() == 1 then
            self:SetTexture("PUSHED")
        end
    end)

    button:SetScript("OnMouseUp", function()
        if button:IsEnabled() == 1 then
            self:SetTexture("NORMAL")
        end
    end)

    local realEnable = button.Enable
    button.Enable = function(buttonSelf)
        realEnable(buttonSelf)
        self:SetTexture("NORMAL")
    end
    local realDisable = button.Disable
    button.Disable = function(buttonSelf)
        realDisable(buttonSelf)
        self:SetTexture("DISABLED")
    end

    self:SetTexture("NORMAL")
end

local buttonTextures = {["NORMAL"] = "Interface\\Buttons\\UI-Panel-Button-Up",
    ["PUSHED"] = "Interface\\Buttons\\UI-Panel-Button-Down",
    ["DISABLED"] = "Interface\\Buttons\\UI-Panel-Button-Disabled"
}
function PTGuiButton:SetTexture(type) -- "NORMAL", "PUSHED", "DISABLED"
    local texLoc = buttonTextures[type]
    for _, tex in ipairs(self:GetHandle().textures) do
        tex:SetTexture(texLoc)
    end
end

function PTGuiButton:SetUseDefaultTextures(useDefault)
    if not useDefault and self.UsingDefaultTextures then
        local button = self:GetHandle()
        for _, tex in ipairs(button.textures) do
            tex:Show()
        end
        self.NormalTexture:SetTexture(nil)
        self.PushedTexture:SetTexture(nil)
        self.DisabledTexture:SetTexture(nil)
        self.HighlightTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
        self.UsingDefaultTextures = nil
    elseif useDefault then
        local button = self:GetHandle()
        for _, tex in ipairs(button.textures) do
            tex:Hide()
        end
        self.UsingDefaultTextures = true
    end
    return self
end

function PTGuiButton:SetEnabled(enabled)
    (enabled and self.Enable or self.Disable)(self)
    return self
end

function PTGuiButton:SetScript(scriptName, script, noSelf)
    if scriptName ~= "OnClick" then
        return self.super.SetScript(self, scriptName, script, noSelf)
    end
    self:GetHandle():SetScript(scriptName, function()
        self:PlayClickSound()
        if script then
            script(self)
        end
    end)
    return self
end

function PTGuiButton:PlayClickSound()
    self.ClickSoundFunc(self.ClickSoundName)
end

function PTGuiButton:SetClickSound(soundFunc, soundName)
    self.ClickSoundFunc = soundFunc
    self.ClickSoundName = soundName
    return self
end

PTGuiLib.RegisterComponent(PTGuiButton)