pfUI.addonskinner:RegisterSkin("PizzaSlices", function()
    -- Replaces PizzaSlices' glow texture with custom texture based on pfUI's own glow texture.
    -- A potential improvement would be to use pfUI's glow.tga through its API (pfUI.media["img:glow"])
    local glow_texture = "Interface\\AddOns\\pfUI-addonskinner\\media\\img\\glow"

    local font = pfUI_config.global.font_default

    -- Style a slice's frame and text
    local function StyleSlice(slice)
        local frame = slice.frame
        if not frame then return end

        if not frame.pfUI_skinned then
            pfUI.api.CreateBackdrop(frame)
            frame.pfUI_skinned = true
        end

        if frame.cdtext then
            frame.cdtext:SetFont(font, 14, "OUTLINE")
            frame.cdtext:SetTextColor(1, 1, .2, 1)
        end

        if frame.text then
            frame.text:SetFont(font, 12, "OUTLINE")
            frame.text:SetTextColor(1, 1, 1, 1)
        end

        if frame.itemCount then
            frame.itemCount:SetFont(font, 11, "OUTLINE")
            frame.itemCount:SetTextColor(1, 1, .2, 1)
        end

        if frame.tex then frame.tex:SetTexCoord(.08, .92, .08, .92) end
        if frame.iglow then frame.iglow:SetTexture(glow_texture) end
        if frame.borderlow then frame.borderlow:SetAlpha(0) end
        if frame.borderhigh then frame.borderhigh:SetAlpha(0) end

        if frame.backdrop then
            local blackBorders = PizzaSlices_config and PizzaSlices_config.blackBorders
            if not blackBorders and slice.color then
                frame.backdrop:SetBackdropBorderColor(slice.color.r, slice.color.g, slice.color.b, 1)
            else
                frame.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
            end
        end
    end

    -- Helper function to iterate over the active slices
    local function ForEachSlice(func)
        if PizzaSlices and PizzaSlices.ring and PizzaSlices.ring.slices then
            for _, slice in ipairs(PizzaSlices.ring.slices) do
                func(slice)
            end
        end
    end

    -- Hook the open function to apply initial styling
    if PizzaSlices and PizzaSlices.frame then
        local original_open = PizzaSlices.frame.open
        PizzaSlices.frame.open = function(ring)
            original_open(ring)
            ForEachSlice(StyleSlice)
        end

        -- Hook the OnUpdate script to ensure styles are persistent
        local original_OnUpdate = PizzaSlices.frame:GetScript("OnUpdate")
        PizzaSlices.frame:SetScript("OnUpdate", function()
            if original_OnUpdate then original_OnUpdate() end
            ForEachSlice(StyleSlice)
        end)
    end

    pfUI.addonskinner:UnregisterSkin("PizzaSlices")
end)
