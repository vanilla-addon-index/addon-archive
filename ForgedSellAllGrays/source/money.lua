local addon = ForgedSellAllGrays

function addon.FormatMoneyText(copper)
    local g = floor(copper / 10000)
    local s = floor(mod(copper, 10000) / 100)
    local c = mod(copper, 100)

    local text = ""
    if g > 0 then
        text = text .. g .. " Gold, "
    end
    if s > 0 or g > 0 then
        text = text .. s .. " Silver, "
    end
    text = text .. c .. " Copper"

    return text
end

function addon.PrintSellResult(copperGained)
    if copperGained > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Sold all poor-quality items.")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Received " .. addon.FormatMoneyText(copperGained) .. ".")
    end
end
