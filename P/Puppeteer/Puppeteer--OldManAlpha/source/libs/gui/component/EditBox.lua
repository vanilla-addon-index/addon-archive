PTGuiEditbox = PTGuiComponent:Extend("editbox")
local _G = getfenv(0)
PTGuiEditbox:Import(true, "SetText", "SetMultiLine", "SetAutoFocus", "SetFocus", "ClearFocus", "SetNumeric", "SetJustifyH", "HighlightText")
PTGuiEditbox:Import(false, "GetText", "IsMultiLine", "IsAutoFocus", "IsNumeric")

function PTGuiEditbox:New()
    local obj = setmetatable({}, self)
    obj:SetHandle(CreateFrame("Editbox", self:GenerateName(), nil, "InputBoxTemplate"))
    obj:SetAutoFocus(false) -- Who actually wants this on by default??

    -- Fix edit box texture starting 5 px to the left nonsense
    local left = _G[obj:GetName().."Left"]
    local a,b,c,d,e = left:GetPoint(1)
    left:ClearAllPoints()
    left:SetPoint(a,b,c,0,e)
    obj:GetHandle():SetTextInsets(4, 4, 0, 0)
    
    return obj
end

function PTGuiEditbox:OnDispose()
    self.super.OnDispose(self)

    self:SetText("")
    self:SetMultiLine(false)
    self:SetAutoFocus(false)
end

PTGuiLib.RegisterComponent(PTGuiEditbox)