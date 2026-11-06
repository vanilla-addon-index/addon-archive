PTGuiColorSelect = PTGuiComponent:Extend("color_select")

function PTGuiColorSelect:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)

    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    obj.ColorTexture = texture

    obj.Color = {1, 1, 1}

    texture:SetTexture(obj.Color[1], obj.Color[2], obj.Color[3])

    obj:SetBackground({
        borderBackdrop = {
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 11,
            tileSize = 11,
            tile = true
        },
        borderPadding = 2
    })

    frame:EnableMouse(true)
    frame:SetScript("OnMouseUp", function()
        ColorPickerFrame.func = function()
            obj:SetColorRGB(ColorPickerFrame:GetColorRGB())
            if not obj:IsVisible() then
                return
            end
            if obj.ColorSelectHandler then
                obj.ColorSelectHandler(obj)
            end
        end
        local color = obj:GetColor()
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.opacity = nil
        ColorPickerFrame:SetColorRGB(color[1], color[2], color[3]);
        ColorPickerFrame.previousValues = {r = color[1], g = color[2], b = color[3]};
        ColorPickerFrame.cancelFunc = function()
            local prevColor = ColorPickerFrame.previousValues
            obj:SetColorRGB(prevColor.r, prevColor.g, prevColor.b)
            ColorPickerFrame.func = nil
            ColorPickerFrame.cancelFunc = nil
        end
        ShowUIPanel(ColorPickerFrame)
    end)

    return obj
end

function PTGuiColorSelect:OnDispose()
    self.super.OnDispose(self)
    local color = self.Color
    color[1], color[2], color[3], color[4] = 1, 1, 1, 1
end

function PTGuiColorSelect:GetColor()
    local color = self.Color
    return {color[1], color[2], color[3], color[4]}
end

function PTGuiColorSelect:GetColorRGB()
    return self.Color[1], self.Color[2], self.Color[3], self.Color[4]
end

function PTGuiColorSelect:SetColorRGB(r, g, b, a)
    local color = self.Color
    color[1], color[2], color[3], color[4] = r, g, b, a
    self.ColorTexture:SetTexture(r, g, b, a or 1)
    return self
end

function PTGuiColorSelect:SetColor(rgb)
    self.Color[1], self.Color[2], self.Color[3], self.Color[4] = rgb[1], rgb[2], rgb[3], rgb[4]
    self.ColorTexture:SetTexture(self.Color[1], self.Color[2], self.Color[3], self.Color[4] or 1)
    return self
end

function PTGuiColorSelect:SetColorSelectHandler(handler)
    self.ColorSelectHandler = handler
    return self
end

PTGuiLib.RegisterComponent(PTGuiColorSelect)