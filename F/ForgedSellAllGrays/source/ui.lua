local addon = ForgedSellAllGrays

function addon.EnsureSellButton()
    if addon.sellButton then
        return addon.sellButton
    end

    local button = CreateFrame("Button", "ForgedSellAllGrays_SellButton", MerchantFrame, "ItemButtonTemplate")
    button:SetWidth(36)
    button:SetHeight(36)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 1)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    button.IconTexture = icon

    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sell all poor-quality items", 1, 0.82, 0)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", addon.SellGrayQualityItems)

    addon.sellButton = button

    return button
end

function addon.LayoutMerchantButtons()
    MerchantRepairText:Hide()

    MerchantRepairItemButton:ClearAllPoints()
    MerchantRepairItemButton:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 23, 92)

    MerchantRepairAllButton:ClearAllPoints()
    MerchantRepairAllButton:SetPoint("LEFT", MerchantRepairItemButton, "RIGHT", 4, 0)

    addon.sellButton:ClearAllPoints()
    addon.sellButton:SetPoint("LEFT", MerchantRepairAllButton, "RIGHT", 37, 0)
end

function addon.UpdateSellButtonVisibility()
    if not addon.sellButton then
        return
    end

    MerchantRepairText:Hide()

    if addon.HasGrayQualityItems() then
        addon.sellButton:Show()
    else
        addon.sellButton:Hide()
    end
end

function addon.HandleMerchantShow()
    addon.EnsureSellButton()
    addon.LayoutMerchantButtons()
    addon.UpdateSellButtonVisibility()
end

function addon.HandleMerchantClosed()
    if addon.sellButton then
        addon.sellButton:Hide()
    end
end
