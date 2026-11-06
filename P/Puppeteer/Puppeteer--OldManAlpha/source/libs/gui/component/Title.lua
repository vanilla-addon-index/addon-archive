PTGuiTitle = PTGuiComponent:Extend("title")
PTGuiTitle:ImportComponent("text", true, "SetText", "SetFont", "SetNonSpaceWrap", "SetJustifyH", "SetJustifyV", "SetTextColor")
PTGuiTitle:ImportComponent("text", false, "GetText", "GetFont", "GetStringWidth", "CanNonSpaceWrap", "GetJustifyH", "GetJustifyV", "GetTextColor")

function PTGuiTitle:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName(), nil)
    obj:SetHandle(frame)
    local tex = frame:CreateTexture(nil, "LOW")
    tex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    tex:SetTexCoord(58 / 256, 197 / 256, 0 / 64, 40 / 64)
    tex:SetAllPoints()
    local text = PTGuiLib.Get("text", frame)
    obj:AddComponent("text", text)
    obj:SetPrimary()
    text:SetPoint("CENTER", frame, "CENTER")
    return obj
end

PTGuiLib.RegisterComponent(PTGuiTitle)