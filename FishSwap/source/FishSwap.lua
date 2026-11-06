-- Namespace
local FishSwap = CreateFrame("Button", "FishSwapButton", UIParent)

-- Configuration
local BUTTON_SIZE = 32
local ICON_TEXTURE = "Interface\\Icons\\Trade_Fishing"
local DEBUG_MODE = false

-- Initialize Saved Variables (Main Hand = 16, Off Hand = 17)
if not FishSwapSavedWeapons then
    FishSwapSavedWeapons = {
        mh = nil,
        oh = nil
    }
end

-- === HARDCODED DATABASE ===
local KNOWN_POLES = {
    -- Standard Vanilla Poles
    [6256] = 0, -- Fishing Pole
    [6365] = 5, -- Strong Fishing Pole
    [6366] = 15, -- Darkwood Fishing Pole
    [6367] = 20, -- Big Iron Fishing Pole
    [12225] = 3, -- Blump Family Fishing Pole
    [19022] = 25, -- Nat Pagle's Extreme Angler FC-5000
    [19970] = 35, -- Arcanite Fishing Pole
    [4598] = 0, -- Goblin Fishing Pole
    [3567] = 0, -- Dwarven Fishing Pole
    [19972] = 25, -- Nat's Lucky Fishing Pole

    -- Turtle WoW Custom Poles
    [7010] = 0, -- Driftwood Fishing Pole
    [84507] = 5 -- Barkskin Fisher
}

-- Logging configuration
local appName = "FishSwap"
local chatFrame = DEFAULT_CHAT_FRAME
local debugColour = "ffaaaaaa"
local infoColour = "ffffd100"
local errorColour = "ffff0000"

local PREFIX_PLAIN = appName .. ": "
local logPrefixes = {
    ["DEBUG"] = "|c" .. debugColour .. appName .. " [DEBUG]:|r ",
    ["INFO"] = "|c" .. infoColour .. appName .. ":|r ",
    ["ERROR"] = "|c" .. errorColour .. appName .. ":|r "
}

local function Log(level, msg)
    if level == "DEBUG" and not DEBUG_MODE then
        return
    end
    local prefix = logPrefixes[level] or PREFIX_PLAIN
    chatFrame:AddMessage(prefix .. msg)
end

-- Hidden Tooltip for scanning
local scanTooltip = CreateFrame("GameTooltip", "FishSwapScanner", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Helper: Parse Item Name from Link
local function GetItemNameFromLink(link)
    if not link then
        return nil
    end
    local name = string.gsub(link, "|c%x+|Hitem:%d+:%d+:%d+:%d+|h%[(.-)%]|h|r", "%1")
    return name
end

-- Helper: Parse Item ID from Link
local function GetItemIDFromLink(link)
    if not link then
        return nil
    end
    local _, _, id = string.find(link, "item:(%d+)")
    return tonumber(id)
end

-- Helper: Find item location in bags
local function FindItemInBags(itemName)
    if not itemName then
        return nil, nil
    end
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots > 0 then
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    if GetItemNameFromLink(link) == itemName then
                        return bag, slot
                    end
                end
            end
        end
    end
    return nil, nil
end

-- Helper: Count total free bag slots (IGNORING SPECIALTY BAGS via TOOLTIP SCAN)
local function GetTotalFreeBagSlots()
    local free = 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        local isGeneralBag = true

        -- Bag 0 is always the Backpack (General). 
        -- For Bags 1-4, we scan the tooltip for "Quiver", "Ammo", "Soul Bag", etc.
        if bag > 0 and numSlots > 0 then
            local invID = ContainerIDToInventoryID(bag)

            scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
            scanTooltip:ClearLines()
            local hasItem = scanTooltip:SetInventoryItem("player", invID)

            if hasItem then
                for i = 1, 4 do
                    local left = _G["FishSwapScannerTextLeft" .. i]
                    local right = _G["FishSwapScannerTextRight" .. i]
                    local textL = left and left:GetText() or ""
                    local textR = right and right:GetText() or ""
                    local fullText = textL .. " " .. textR

                    if string.find(fullText, "Quiver") or string.find(fullText, "Ammo Pouch") or
                        string.find(fullText, "Soul Bag") or string.find(fullText, "Herb Bag") or
                        string.find(fullText, "Enchanting Bag") or string.find(fullText, "Engineering Bag") or
                        string.find(fullText, "Mining Sack") then

                        isGeneralBag = false
                        if DEBUG_MODE then
                            Log("DEBUG", "Ignoring specialty bag in slot " .. bag)
                        end
                        break
                    end
                end
            end
        end

        if isGeneralBag and numSlots > 0 then
            for slot = 1, numSlots do
                local texture = GetContainerItemInfo(bag, slot)
                if not texture then
                    free = free + 1
                end
            end
        end
    end
    return free
end

-- Helper: Analyse an item to see if it is a Fishing Pole
local function AnalyseItem(link)
    local id = GetItemIDFromLink(link)
    if id and KNOWN_POLES[id] then
        return true, KNOWN_POLES[id]
    end
    return false, 0
end

-- Helper: Is a fishing pole equipped?
local function IsFishingPoleEquipped()
    local link = GetInventoryItemLink("player", 16)
    if not link then
        return false
    end
    local id = GetItemIDFromLink(link)
    if id and KNOWN_POLES[id] then
        return true
    end
    return false
end

-- ACTION: Swap TO Weapons
local function SwapToWeapons()
    local mhName = FishSwapSavedWeapons.mh
    local ohName = FishSwapSavedWeapons.oh

    if not mhName and not ohName then
        Log("ERROR", "No saved weapons found. Please equip your weapons manually once to initialize.")
        return
    end

    local proceedToOffHand = true

    -- 1. Equip Main Hand
    if mhName then
        local bag, slot = FindItemInBags(mhName)
        if bag and slot then
            Log("INFO", "Equipping Main Hand...")
            PickupContainerItem(bag, slot)
            EquipCursorItem(16)
        else
            Log("ERROR", "Could not find Main Hand: " .. mhName)
            proceedToOffHand = false
        end
    end

    -- 2. Equip Off Hand
    if ohName then
        if proceedToOffHand then
            local bagOH, slotOH = FindItemInBags(ohName)
            if bagOH and slotOH then
                Log("INFO", "Equipping Off Hand...")
                PickupContainerItem(bagOH, slotOH)
                EquipCursorItem(17)
            elseif ohName then
                Log("ERROR", "Could not find Off Hand: " .. ohName)
            end
        else
            Log("ERROR", "Aborting Off-Hand equip because Main Hand is missing.")
        end
    end
end

-- ACTION: Swap TO Pole
local function SwapToPole()
    local hasMH = GetInventoryItemLink("player", 16)
    local hasOH = GetInventoryItemLink("player", 17)
    local freeSlots = GetTotalFreeBagSlots()

    if hasMH and hasOH and freeSlots < 1 then
        Log("ERROR", "Swap aborted. No general bag space detected for Off-Hand.")
        return
    end

    -- Save current gear
    FishSwapSavedWeapons.mh = GetItemNameFromLink(hasMH)
    FishSwapSavedWeapons.oh = GetItemNameFromLink(hasOH)

    -- Find the BEST Fishing Pole
    local bestBag, bestSlot = nil, nil
    local bestBonus = -1

    Log("DEBUG", "Scanning Bags...")

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots > 0 then
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local isPole, bonus = AnalyseItem(link)
                    if isPole then
                        if DEBUG_MODE then
                            local name = GetItemNameFromLink(link)
                            Log("DEBUG", "Found Pole: " .. (name or "Unknown") .. " (+" .. bonus .. ")")
                        end
                        if bonus > bestBonus then
                            bestBonus = bonus
                            bestBag = bag
                            bestSlot = slot
                        end
                    end
                end
            end
        end
    end

    if bestBag and bestSlot then
        local poleLink = GetContainerItemLink(bestBag, bestSlot)
        local poleName = GetItemNameFromLink(poleLink)
        Log("INFO", "Equipping " .. poleName .. " (Bonus: +" .. bestBonus .. ")...")

        PickupContainerItem(bestBag, bestSlot)
        EquipCursorItem(16)
    else
        Log("ERROR", "No Fishing Pole found in bags!")
        if not DEBUG_MODE then
            DEFAULT_CHAT_FRAME:AddMessage("If you have a custom pole, please add its Item ID to FishSwap.lua")
        end
    end
end

-- Core Logic: Decision Maker
local function ToggleFishingGear()
    -- Safety: Clear cursor if something got stuck previously
    if CursorHasItem() then
        ClearCursor()
    end

    local currentMHLink = GetInventoryItemLink("player", 16)
    local currentMHName = GetItemNameFromLink(currentMHLink)
    local savedMHName = FishSwapSavedWeapons.mh

    if savedMHName and currentMHName == savedMHName then
        SwapToPole()
        return
    end

    if IsFishingPoleEquipped() then
        SwapToWeapons()
        return
    end

    SwapToPole()
end

-- Helper: Reset Position
local function ResetPosition()
    FishSwap:ClearAllPoints()
    FishSwap:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    Log("INFO", "Button position reset.")
end

-- Helper: Full Reset
local function FullReset()
    ResetPosition()
    FishSwapSavedWeapons.mh = nil
    FishSwapSavedWeapons.oh = nil
    Log("INFO", "Saved weapon data cleared.")
end

-- UI Construction
FishSwap:SetWidth(BUTTON_SIZE)
FishSwap:SetHeight(BUTTON_SIZE)
FishSwap:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
FishSwap:EnableMouse(true)
FishSwap:SetMovable(true)
FishSwap:RegisterForDrag("LeftButton")
FishSwap:RegisterForClicks("LeftButtonUp", "RightButtonUp")

local tex = FishSwap:CreateTexture(nil, "BACKGROUND")
tex:SetAllPoints()
tex:SetTexture(ICON_TEXTURE)
FishSwap.texture = tex

FishSwap:SetScript("OnDragStart", function()
    if IsShiftKeyDown() and arg1 == "LeftButton" then
        this:StartMoving()
    end
end)
FishSwap:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
end)

FishSwap:SetScript("OnMouseUp", function()
    if arg1 == "LeftButton" then
        ToggleFishingGear()
    elseif arg1 == "RightButton" then
        FullReset()
    end
end)

FishSwap:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("FishSwap")
    GameTooltip:AddLine("Left Click: Toggle best Fishing Pole.", 1, 1, 1)
    GameTooltip:AddLine("Right Click: Reset Position & Clear Data.", 1, 0.5, 0.5)

    if FishSwapSavedWeapons.mh then
        GameTooltip:AddLine("Saved MH: " .. FishSwapSavedWeapons.mh, 0, 1, 0)
    end
    if FishSwapSavedWeapons.oh then
        GameTooltip:AddLine("Saved OH: " .. FishSwapSavedWeapons.oh, 0, 1, 0)
    end
    GameTooltip:AddLine("Shift+Left Drag to move.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
FishSwap:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

SLASH_FISHSWAP1 = "/fishswap"
SlashCmdList["FISHSWAP"] = function(msg)
    if msg == "reset" then
        ResetPosition()
    else
        Log("INFO", "Type |cff00ffff/fishswap reset|r to reset button position.")
    end
end

Log("INFO", "Loaded")
