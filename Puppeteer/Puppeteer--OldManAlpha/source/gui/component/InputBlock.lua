PTInputBlock = PTGuiComponent:Extend("puppeteer_input_block")

function PTInputBlock:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)
    obj:SetBackground({frameBackdrop = {
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 11,
                tile = true
            }, frameBackdropColor = {0, 0, 0, 0.5}})
    frame:EnableMouse(true)
    return obj
end

function PTInputBlock:SetParent(parent)
    self.super.SetParent(self, parent)
    self:SetPoint("TOPLEFT", parent, "TOPLEFT")
    self:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
end

PTGuiLib.RegisterComponent(PTInputBlock)