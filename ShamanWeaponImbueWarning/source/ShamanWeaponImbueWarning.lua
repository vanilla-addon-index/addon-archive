local warningFrame = CreateFrame("Frame", "ShamanWeaponImbueWarningFrame", UIParent)
warningFrame:SetWidth(480)
warningFrame:SetHeight(80)
warningFrame:SetPoint("TOP", UIParent, "TOP", 0, -215)
warningFrame:SetFrameStrata("HIGH")
warningFrame:Hide()

local title = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
title:SetFont("Fonts\\FRIZQT__.TTF", 28, "OUTLINE")
title:SetPoint("TOP", warningFrame, "TOP", 0, 0)
title:SetText("|cffff3333MISSING MAIN-HAND IMBUE|r")

local isShaman = false
local pollElapsed = 0
local pulseElapsed = 0
local hasEnchantIDAPI = C_Item and type(C_Item.GetWeaponEnchantInfo) == "function"

local shamanImbueEnchantIDs = {
    -- Rockbiter ranks 1-7
    [29] = true, [6] = true, [1] = true, [503] = true,
    [1663] = true, [683] = true, [1664] = true,
    -- Flametongue ranks 1-6
    [5] = true, [4] = true, [3] = true, [523] = true,
    [1665] = true, [1666] = true,
    -- Frostbrand ranks 1-5
    [2] = true, [12] = true, [524] = true, [1667] = true, [1668] = true,
    -- Windfury ranks 1-4
    [283] = true, [284] = true, [525] = true, [1669] = true,
}

local function UpdateWarning()
    if not isShaman or not hasEnchantIDAPI or not UnitAffectingCombat("player") then
        warningFrame:Hide()
        warningFrame:SetAlpha(1)
        warningFrame:SetScript("OnUpdate", nil)
        pollElapsed = 0
        return
    end

    warningFrame:SetScript("OnUpdate", function()
        local elapsed = arg1 or 0
        pollElapsed = pollElapsed + elapsed
        pulseElapsed = pulseElapsed + elapsed
        warningFrame:SetAlpha(0.6 + 0.4 * math.abs(math.sin(pulseElapsed * 4)))
        if pollElapsed >= 0.5 then
            pollElapsed = 0
            UpdateWarning()
        end
    end)

    local mainHandItem = GetInventoryItemLink("player", 16)
    local hasMainHandEnchant, _, _, enchantID = C_Item.GetWeaponEnchantInfo()
    if mainHandItem and (not hasMainHandEnchant or not shamanImbueEnchantIDs[enchantID]) then
        warningFrame:Show()
    else
        warningFrame:Hide()
        warningFrame:SetAlpha(1)
    end
end

warningFrame:RegisterEvent("PLAYER_LOGIN")
warningFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
warningFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
warningFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
warningFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
warningFrame:RegisterEvent("PLAYER_AURAS_CHANGED")
warningFrame:RegisterEvent("BUFF_UPDATE_DURATION_SELF")

warningFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        local _, classToken = UnitClass("player")
        isShaman = classToken == "SHAMAN"
        if isShaman and not hasEnchantIDAPI then
            DEFAULT_CHAT_FRAME:AddMessage("Shaman Weapon Imbue Warning: ClassicAPI enchant ID support is unavailable.")
        end
    elseif event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
        return
    end

    UpdateWarning()
end)
