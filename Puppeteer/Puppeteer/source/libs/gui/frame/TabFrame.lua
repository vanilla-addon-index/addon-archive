PTGuiTabFrame = PTGuiTabComponent:Extend("tab_frame")
PTGuiTabFrame:SetTabPosition("BOTTOM", 0, -5)

function PTGuiTabFrame:New()
    local obj = self.super.New(self)
    local frame = obj:GetHandle()
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetScript("OnMouseDown", function()
        local button = arg1

        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function()
        local button = arg1

        if button == "LeftButton" then
            frame:StopMovingOrSizing()
        end
    end)
    return obj
end

-- Allows frame to the closed with escape
function PTGuiTabFrame:SetSpecial()
    table.insert(UISpecialFrames, self:GetName())
    return self
end

PTGuiLib.RegisterComponent(PTGuiTabFrame)