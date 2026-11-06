ForgedSellAllGrays = ForgedSellAllGrays or {}
-- Only create the tooltip once and reuse it
local scanTooltip = nil

local function IsItemSoulbound(bag, slot)
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "ForgedSellAllGrays_ScanTooltip", nil, "GameTooltipTemplate")
    end
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    scanTooltip:SetBagItem(bag, slot)
    local tooltipName = scanTooltip:GetName()
    for i = 2, scanTooltip:NumLines() do -- skip first line (item name)
        local textObj = getglobal(tooltipName .. "TextLeft" .. i)
        local tooltipLine = nil
        if type(textObj) == "table" and type(textObj.GetText) == "function" then
            tooltipLine = textObj:GetText()
        elseif type(textObj) == "string" then
            tooltipLine = textObj
        end
        if tooltipLine ~= nil and type(tooltipLine) == "string" then
            if string.find(tooltipLine, "Soulbound") then
                return true
            end
        end
    end
    return false
end
local addon = ForgedSellAllGrays

function addon.GetItemQualityFromLink(itemLink)
    if not itemLink then
        return nil
    end

    local color = strsub(itemLink, 5, 10)
    if color == "9d9d9d" then
        return 0
    elseif color == "ffffff" then
        return 1
    elseif color == "1eff00" then
        return 2
    elseif color == "0070dd" then
        return 3
    elseif color == "a335ee" then
        return 4
    elseif color == "ff8000" then
        return 5
    end

    return nil
end

function addon.IsGraySellableItem(bag, slot)

    local texture, count, locked, quality = GetContainerItemInfo(bag, slot)
    if not texture or locked then
        return false
    end
    if IsItemSoulbound(bag, slot) then
        return false
    end

    local itemLink = GetContainerItemLink(bag, slot)
    local linkQuality = addon.GetItemQualityFromLink(itemLink)
    if linkQuality ~= nil then
        return linkQuality == 0
    end

    if itemLink then
        local itemName, itemLinkValue, itemRarity = GetItemInfo(itemLink)
        if itemRarity ~= nil then
            return itemRarity == 0
        end
    end

    return quality == 0
end

function addon.HasGrayQualityItems()
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            if addon.IsGraySellableItem(bag, slot) then
                return true
            end
        end
    end

    return false
end
