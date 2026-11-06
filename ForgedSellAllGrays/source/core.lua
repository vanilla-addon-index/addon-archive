ForgedSellAllGrays = ForgedSellAllGrays or {}
local addon = ForgedSellAllGrays

addon.copperAtSellStart = addon.copperAtSellStart or 0
addon.selling = addon.selling or false

function addon.SellGrayQualityItems()
    if addon.selling then
        return
    end

    addon.selling = true
    addon.copperAtSellStart = GetMoney()

    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            if addon.IsGraySellableItem(bag, slot) then
                UseContainerItem(bag, slot)
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("MERCHANT_UPDATE")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("PLAYER_MONEY")

frame:SetScript("OnEvent", function()
    if event == "MERCHANT_SHOW" then
        addon.HandleMerchantShow()
    elseif event == "MERCHANT_CLOSED" then
        addon.HandleMerchantClosed()
    elseif event == "MERCHANT_UPDATE" or event == "BAG_UPDATE" then
        addon.UpdateSellButtonVisibility()
    elseif event == "PLAYER_MONEY" and addon.selling then
        addon.selling = false

        local copperGained = GetMoney() - addon.copperAtSellStart
        addon.PrintSellResult(copperGained)
    end
end)
