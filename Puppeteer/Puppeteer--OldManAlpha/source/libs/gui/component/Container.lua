PTGuiContainer = PTGuiComponent:Extend("container")

function PTGuiContainer:New(name, parent)
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", name or self:GenerateName(), parent)
    obj:SetHandle(frame)
    return obj
end

PTGuiLib.RegisterComponent(PTGuiContainer)