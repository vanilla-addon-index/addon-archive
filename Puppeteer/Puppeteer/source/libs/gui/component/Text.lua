PTGuiText = PTGuiComponent:Extend("text")
PTGuiText:Import(true, "SetText", "SetFont", "SetNonSpaceWrap", "SetJustifyH", "SetJustifyV", "SetTextColor")
PTGuiText:Import(false, "GetText", "GetFont", "GetStringWidth", "CanNonSpaceWrap", "GetJustifyH", "GetJustifyV", "GetTextColor")

function PTGuiText:New()
    local obj = setmetatable({}, self)
    local container = PTGuiLib.Get("container")
    obj:AddComponent("container", container)
    obj:SetHandle(container:GetHandle():CreateFontString(nil, "MEDIUM", "GameFontNormal"))
    obj:SetFont("Fonts\\FRIZQT__.TTF", 12)
    container:GetHandle():SetAllPoints(obj:GetHandle())
    return obj
end

function PTGuiText:OnAcquire()
    self.super.OnAcquire(self)
end

function PTGuiText:OnDispose()
    self.super.OnDispose(self)

    self:SetText("")
    self:SetFont("Fonts\\FRIZQT__.TTF", 12)
    self:SetJustifyH("CENTER")
    self:SetJustifyV("MIDDLE")
    self:SetNonSpaceWrap(false)
    self:SetTextColor(1, 0.82, 0)
end

function PTGuiText:GetContainer()
    return self:GetComponent("container")
end

function PTGuiText:SetBackground(params)
    return self:GetContainer():SetBackground(params)
end

function PTGuiText:Show()
    self:GetContainer():Show()
    return self
end

function PTGuiText:Hide()
    self:GetContainer():Hide()
    return self
end

function PTGuiText:SetParent(frame)
    self:GetContainer():SetParent(frame)
    return self
end

function PTGuiText:SetFontSize(size)
    local fontName, _, flags = self:GetFont()
    self:SetFont(fontName, size, flags)
    return self
end

function PTGuiText:SetFontFlags(flags)
    local fontName, size, _ = self:GetFont()
    self:SetFont(fontName, size, flags)
    return self
end

PTGuiLib.RegisterComponent(PTGuiText)