if not XiaoMountDB then
    XiaoMountDB = { enabled = true }
end

local UPDATE_INTERVAL = 0.1
local DISMOUNT_DELAY = 0.3

-- Item Slot IDs
local HELM_SLOT = 1
local CHEST_SLOT = 4
local BELT_SLOT = 6
local BOOTS_SLOT = 8
local GLOVES_SLOT = 10
local RING_1_SLOT = 11
local RING_2_SLOT = 12
local TRINKET_1_SLOT = 13
local TRINKET_2_SLOT = 14

-- Item IDs
local S_GNOME_CAR_KEY_ID = "50524"          -- 3% mount speed trinket
local S_GOBLIN_CAR_KEY_ID = "50525"         -- 3% mount speed trinket
local S_CARROT_ITEM_ID = "11122"            -- 3% mount speed trinket
local S_WHIP_OF_ENCOURAGEMENT_ID = "60501"  -- 3% mount speed trinket + 3% attack/cast speed (prio)
local S_AZURE_BELT_ITEM_ID = "7052"         -- 15% swim speed belt
local S_ICE_PEARL_KANEQNUUN_ID = "60470"    -- 15% swim speed trinket
local S_OCEANS_GAZE_ID = "56023"            -- 15% swim speed ring (NOT UNIQUE)
local S_DEEP_STRIDERS_ID = "80720"          -- 15% swim speed boots
local S_RETHRESS_TIDE_CREST_ID = "40061"    -- 15% swim speed trinket
local S_CAPTAINS_OVERCOAT_ID = "83494"      -- 15% swim speed chest
local S_DEEPDIVE_HELM_ITEM_ID = "10506"     -- underwater breathing

-- Enchant IDs
local S_GLOVE_ENCHANT = "930"           -- Enchant Gloves - Riding skill
local S_THORIUM_SPURS_ENCHANT = "3026"  -- 7% mount speed (blacksmithing)
local S_MITHRIL_SPURS_ENCHANT = "464"  -- 6% mount speed (blacksmithing)

local XiaoMount = CreateFrame("Frame")
XiaoMount:RegisterEvent("ADDON_LOADED")
XiaoMount:RegisterEvent('PLAYER_ENTERING_WORLD')
XiaoMount:RegisterEvent('PLAYER_LEAVING_WORLD')
XiaoMount:RegisterEvent("SPELLCAST_START")
XiaoMount:RegisterEvent("SPELLCAST_STOP")
XiaoMount:RegisterEvent("SPELLCAST_FAILED")
XiaoMount:RegisterEvent("SPELLCAST_INTERRUPTED")
XiaoMount:RegisterEvent("SPELLCAST_CHANNEL_START")
XiaoMount:RegisterEvent("SPELLCAST_CHANNEL_STOP")
XiaoMount:RegisterEvent("MIRROR_TIMER_START")      -- Fired when start ticking breath/fatigue

-- Note: vanillatweaks can fire duplicate events
------------------------------------------------
-- INITALIZE XIAOMOUNT                        --
------------------------------------------------
XiaoMount:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if not XiaoMount.loaded then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff8000Xiao|rMount loaded! /xiaomount")
            XiaoMount.loaded = true
            XiaoMount.hasEnteredWorld = false
            XiaoMount.lastUpdate = GetTime()
            this:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LEAVING_WORLD" then
        XiaoMount.hasEnteredWorld = false
    elseif event == "PLAYER_ENTERING_WORLD" then
        XiaoMount.hasEnteredWorld = true
    elseif event == "SPELLCAST_START" or event == "SPELLCAST_CHANNEL_START" then
        XiaoMount.casting = true
    elseif event == "SPELLCAST_STOP" or event == "SPELLCAST_CHANNEL_STOP"
            or event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
        XiaoMount.casting = false
    elseif event == "MIRROR_TIMER_START" then
        if arg1 == "BREATH" and XiaoMountDB.enabled then
            XiaoMount_EquipSwimmingSet()
        end
    end
end)

------------------------------------------------
-- XIAOMOUNT ONUPDATE                         --
------------------------------------------------
XiaoMount:SetScript("OnUpdate", function()
    local time = GetTime()
    -- limit amount of updates occurring to 10 per second
    if (time - XiaoMount.lastUpdate > UPDATE_INTERVAL) then
        XiaoMount.lastUpdate = time
    else
        return
    end

    -- dont update when player isnt ready to change gear
    if not XiaoMount.hasEnteredWorld
            or not UnitExists("player")
            or not UnitIsConnected("player")
            or UnitAffectingCombat("player")
            or UnitIsDeadOrGhost("player")
            or XiaoMount.casting
            or not XiaoMountDB.enabled then
        return
    end

    local isMounted = XiaoMount_IsMounted()
    if isMounted and not UnitOnTaxi("player") and not XiaoMountDB.mounted then
        -- DEFAULT_CHAT_FRAME:AddMessage("|cffff8000Xiao|rMount mounting detected")
        XiaoMount_EquipRidingSet()
        XiaoMountDB.mounted = true
    end

    if not isMounted and XiaoMountDB.mounted then
        if XiaoMount.lastDismounted == nil then
            XiaoMount.lastDismounted = GetTime()
        elseif time - XiaoMount.lastDismounted > DISMOUNT_DELAY then
            -- DEFAULT_CHAT_FRAME:AddMessage("|cffff8000Xiao|rMount dismounting detected")
            XiaoMount.lastDismounted = GetTime()
            XiaoMount_UnequipRidingSet()
            XiaoMountDB.mounted = false
        end
    end
end)

function XiaoMount_EquipRidingSet()
    XiaoMount_UnequipSwimmingSetNoOverlap()
    local trinket1 = true
    local trinket2 = true
    local boots = true

    bag, slot, bag2, slot2 = XiaoMount_BestRidingTrinket()
    local equippedTrinket1Link = GetInventoryItemLink("player", TRINKET_1_SLOT)
    if equippedTrinket1Link then
        local itemId, _ = XiaoMount_ParseItemLink(equippedTrinket1Link)
        if itemId ~= S_WHIP_OF_ENCOURAGEMENT_ID
                and itemId ~= S_CARROT_ITEM_ID
                and itemId ~= S_GOBLIN_CAR_KEY_ID
                and itemId ~= S_GNOME_CAR_KEY_ID then
            if bag ~= nil then
                XiaoMount_EquipItem(bag, slot, TRINKET_1_SLOT)
                trinket1 = false
                if XiaoMountDB.trinketRestoreLink1 == nil then
                    XiaoMountDB.trinketRestoreLink1 = equippedTrinket1Link
                end
            end
        end
    end

    local equippedTrinket2Link = GetInventoryItemLink("player", TRINKET_2_SLOT)
    if equippedTrinket2Link then
        local itemId, _ = XiaoMount_ParseItemLink(equippedTrinket2Link)
        if itemId ~= S_WHIP_OF_ENCOURAGEMENT_ID
                and itemId ~= S_CARROT_ITEM_ID
                and itemId ~= S_GOBLIN_CAR_KEY_ID
                and itemId ~= S_GNOME_CAR_KEY_ID then
            if bag2 ~= nil then
                XiaoMount_EquipItem(bag2, slot2, TRINKET_2_SLOT)
                trinket2 = false
                if XiaoMountDB.trinketRestoreLink2 == nil then
                    XiaoMountDB.trinketRestoreLink2 = equippedTrinket2Link
                end
            end
        end
    end

    local equippedGlovesLink = GetInventoryItemLink("player", GLOVES_SLOT)
    if equippedGlovesLink then
        local _, enchantId = XiaoMount_ParseItemLink(equippedTrinket2Link)
        if enchantId ~= S_GLOVE_ENCHANT then
            bag, slot = XiaoMount_RidingGloves()
            if bag ~= nil then
                XiaoMount_EquipItem(bag, slot, GLOVES_SLOT)
                if XiaoMountDB.glovesRestoreLink == nil then
                    XiaoMountDB.glovesRestoreLink = equippedGlovesLink
                end
            end
        end
    end

    local equippedBootsLink = GetInventoryItemLink("player", BOOTS_SLOT)
    if equippedBootsLink then
        local _, enchantId = XiaoMount_ParseItemLink(equippedBootsLink)
        if enchantId ~= S_MITHRIL_SPURS_ENCHANT and enchantId ~= S_THORIUM_SPURS_ENCHANT then
            bag, slot = XiaoMount_BestRidingBoots()
            if bag ~= nil then
                XiaoMount_EquipItem(bag, slot, BOOTS_SLOT)
                boots = false
                if XiaoMountDB.bootsRestoreLink == nil then
                    XiaoMountDB.bootsRestoreLink = equippedBootsLink
                end
            end
        else
            boots = false
        end
    end

    XiaoMount_UnequipSwimmingSet(trinket1, trinket2, boots)
end

function XiaoMount_EquipSwimmingSet()
    bag, slot, bag2, slot2 = XiaoMount_SwimmingRings()
    local equippedRing1Link = GetInventoryItemLink("player", RING_1_SLOT)
    if equippedRing1Link then
        local itemId, _ = XiaoMount_ParseItemLink(equippedRing1Link)
        if itemId ~= S_OCEANS_GAZE_ID then
            if bag ~= nil then
                XiaoMount_EquipItem(bag, slot, RING_1_SLOT)
                XiaoMountDB.ringRestoreLink1 = equippedRing1Link
            end
        end
    end

    local equippedRing2Link = GetInventoryItemLink("player", RING_2_SLOT)
    if equippedRing2Link then
        local itemId, _ = XiaoMount_ParseItemLink(equippedRing2Link)
        if itemId ~= S_OCEANS_GAZE_ID then
            if bag2 ~= nil then
                XiaoMount_EquipItem(bag2, slot2, RING_2_SLOT)
                XiaoMountDB.ringRestoreLink2 = equippedRing2Link
            end
        end
    end

    local equippedTrinket1Link = GetInventoryItemLink("player", TRINKET_1_SLOT)
    if equippedTrinket1Link then
        local itemId, _ = XiaoMount_ParseItemLink(equippedTrinket1Link)
        if itemId ~= S_ICE_PEARL_KANEQNUUN_ID then
            bag, slot = XiaoMount_FindItem(S_ICE_PEARL_KANEQNUUN_ID)
            if bag ~= nil then
                XiaoMount_EquipItem(bag, slot, TRINKET_1_SLOT)
                XiaoMountDB.trinketRestoreLink1 = equippedTrinket1Link
            end
        end
    end

    local equippedTrinket2Link = GetInventoryItemLink("player", TRINKET_2_SLOT)
    if equippedTrinket2Link then
        local itemId, _ = XiaoMount_ParseItemLink(equippedTrinket2Link)
        if itemId ~= S_RETHRESS_TIDE_CREST_ID then
            bag, slot = XiaoMount_FindItem(S_RETHRESS_TIDE_CREST_ID)
            if bag ~= nil then
                XiaoMount_EquipItem(bag, slot, TRINKET_2_SLOT)
                XiaoMountDB.trinketRestoreLink2 = equippedTrinket2Link
            end
        end
    end

    local equippedBeltLink = GetInventoryItemLink("player", BELT_SLOT)
    if equippedBeltLink then
        local itemId, _ = XiaoMount_ParseItemLink(equippedBeltLink)
        if itemId ~= S_AZURE_BELT_ITEM_ID then
            bag, slot = XiaoMount_FindItem(S_AZURE_BELT_ITEM_ID)
            if bag ~= nil then
                XiaoMount_EquipItem(bag, slot, BELT_SLOT)
                XiaoMountDB.beltRestoreLink = equippedBeltLink
            end
        end
    end

    local equippedChestLink = GetInventoryItemLink("player", CHEST_SLOT)
    if equippedChestLink then
        local itemId, _ = XiaoMount_ParseItemLink(equippedChestLink)
        if itemId ~= S_CAPTAINS_OVERCOAT_ID then
            bag, slot = XiaoMount_FindItem(S_CAPTAINS_OVERCOAT_ID)
            if bag ~= nil then
                XiaoMount_EquipItem(bag, slot, CHEST_SLOT)
                XiaoMountDB.chestRestoreLink = equippedChestLink
            end
        end
    end

    local equippedBootsLink = GetInventoryItemLink("player", BOOTS_SLOT)
    if equippedBootsLink then
        local itemId, _ = XiaoMount_ParseItemLink(equippedBootsLink)
        if itemId ~= S_DEEP_STRIDERS_ID then
            bag, slot = XiaoMount_FindItem(S_DEEP_STRIDERS_ID)
            if bag ~= nil then
                XiaoMount_EquipItem(bag, slot, BOOTS_SLOT)
                XiaoMountDB.bootsRestoreLink = equippedBootsLink
            end
        end
    end

    local equippedHelmLink = GetInventoryItemLink("player", HELM_SLOT)
    if equippedHelmLink then
        local itemId, _ = XiaoMount_ParseItemLink(equippedHelmLink)
        if itemId ~= S_DEEPDIVE_HELM_ITEM_ID then
            bag, slot = XiaoMount_FindItem(S_DEEPDIVE_HELM_ITEM_ID)
            if bag ~= nil then
                XiaoMount_EquipItem(bag, slot, HELM_SLOT)
                XiaoMountDB.helmRestoreLink = equippedHelmLink
            end
        end
    end
end

function XiaoMount_UnequipSwimmingSet(trinket1, trinket2, boots)
    if trinket1 then
        if XiaoMountDB.trinketRestoreLink1 then
            bag, slot = XiaoMount_FindItemByLink(XiaoMountDB.trinketRestoreLink1)
            if bag ~= nil then
                XiaoMount_EquipItem(bag, slot, TRINKET_1_SLOT)
                XiaoMountDB.trinketRestoreLink1 = nil
            end
        end
    end

    if trinket2 then
        if XiaoMountDB.trinketRestoreLink2 then
            bag, slot = XiaoMount_FindItemByLink(XiaoMountDB.trinketRestoreLink2)
            if bag ~= nil then
                XiaoMount_EquipItem(bag, slot, TRINKET_2_SLOT)
                XiaoMountDB.trinketRestoreLink2 = nil
            end
        end
    end

    if boots then
        if XiaoMountDB.bootsRestoreLink then
            bag, slot = XiaoMount_FindItemByLink(XiaoMountDB.bootsRestoreLink)
            if bag ~= nil then
                XiaoMount_EquipItem(bag, slot, BOOTS_SLOT)
                XiaoMountDB.bootsRestoreLink = nil
            end
        end
    end
end

function XiaoMount_UnequipSwimmingSetNoOverlap()
    if XiaoMountDB.beltRestoreLink then
        bag, slot = XiaoMount_FindItemByLink(XiaoMountDB.beltRestoreLink)
        if bag ~= nil then
            XiaoMount_EquipItem(bag, slot, BELT_SLOT)
            XiaoMountDB.beltRestoreLink = nil
        end
    end

    if XiaoMountDB.ringRestoreLink1 then
        bag, slot = XiaoMount_FindItemByLink(XiaoMountDB.ringRestoreLink1)
        if bag ~= nil then
            XiaoMount_EquipItem(bag, slot, RING_1_SLOT)
            XiaoMountDB.ringRestoreLink1 = nil
        end
    end

    if XiaoMountDB.ringRestoreLink2 then
        bag, slot = XiaoMount_FindItemByLink(XiaoMountDB.ringRestoreLink2)
        if bag ~= nil then
            XiaoMount_EquipItem(bag, slot, RING_2_SLOT)
            XiaoMountDB.ringRestoreLink2 = nil
        end
    end

    if XiaoMountDB.chestRestoreLink then
        bag, slot = XiaoMount_FindItemByLink(XiaoMountDB.chestRestoreLink)
        if bag ~= nil then
            XiaoMount_EquipItem(bag, slot, CHEST_SLOT)
            XiaoMountDB.chestRestoreLink = nil
        end
    end

    if XiaoMountDB.helmRestoreLink then
        bag, slot = XiaoMount_FindItemByLink(XiaoMountDB.helmRestoreLink)
        if bag ~= nil then
            XiaoMount_EquipItem(bag, slot, HELM_SLOT)
            XiaoMountDB.helmRestoreLink = nil
        end
    end
end

function XiaoMount_UnequipRidingSet()
    if XiaoMountDB.trinketRestoreLink1 then
        bag, slot = XiaoMount_FindItemByLink(XiaoMountDB.trinketRestoreLink1)
        if bag ~= nil then
            XiaoMount_EquipItem(bag, slot, TRINKET_1_SLOT)
            XiaoMountDB.trinketRestoreLink1 = nil
        end
    end

    if XiaoMountDB.trinketRestoreLink2 then
        bag, slot = XiaoMount_FindItemByLink(XiaoMountDB.trinketRestoreLink2)
        if bag ~= nil then
            XiaoMount_EquipItem(bag, slot, TRINKET_2_SLOT)
            XiaoMountDB.trinketRestoreLink2 = nil
        end
    end

    if XiaoMountDB.glovesRestoreLink then
        bag, slot = XiaoMount_FindItemByLink(XiaoMountDB.glovesRestoreLink)
        if bag ~= nil then
            XiaoMount_EquipItem(bag, slot, GLOVES_SLOT)
            XiaoMountDB.glovesRestoreLink = nil
        end
    end

    if XiaoMountDB.bootsRestoreLink then
        bag, slot = XiaoMount_FindItemByLink(XiaoMountDB.bootsRestoreLink)
        if bag ~= nil then
            XiaoMount_EquipItem(bag, slot, BOOTS_SLOT)
            XiaoMountDB.bootsRestoreLink = nil
        end
    end
end

-- return the bag position of a item link
function XiaoMount_FindItemByLink(itemLink)
    -- First pass: Try exact link match
    for bag = 0, 4 do
        for slot = 0, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if itemLink == link then
                return bag, slot
            end
        end
    end

    -- Second pass: Try matching by Item ID (Fallback)
    local targetId, _ = XiaoMount_ParseItemLink(itemLink)
    if targetId then
        for bag = 0, 4 do
            for slot = 0, GetContainerNumSlots(bag) do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local itemId, _ = XiaoMount_ParseItemLink(link)
                    if itemId == targetId then
                        return bag, slot
                    end
                end
            end
        end
    end

    return nil, nil
end

-- returns the positions of the best available trinkets for riding speed
function XiaoMount_BestRidingTrinket()
    local trinketBag = nil
    local trinketSlot = nil
    local trinket2Bag = nil
    local trinket2Slot = nil
    for bag = 0, 4 do
        for slot = 0, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local itemId, _ = XiaoMount_ParseItemLink(itemLink)
                if itemId == S_WHIP_OF_ENCOURAGEMENT_ID then
                    if trinketBag ~= nil then
                        trinket2Bag = trinketBag
                        trinket2Slot = trinketSlot
                    end
                    trinketBag = bag
                    trinketSlot = slot
                elseif itemId == S_CARROT_ITEM_ID or itemId == S_GOBLIN_CAR_KEY_ID or itemId == S_GNOME_CAR_KEY_ID then
                    if trinketBag == nil then
                        trinketBag = bag
                        trinketSlot = slot
                    else
                        trinket2Bag = bag
                        trinket2Slot = slot
                    end
                end
            end
        end
    end
    return trinketBag, trinketSlot, trinket2Bag, trinket2Slot
end

function XiaoMount_SwimmingRings()
    local ringBag = nil
    local ringSlot = nil
    local ring2Bag = nil
    local ring2Slot = nil
    for bag = 0, 4 do
        for slot = 0, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local itemId, _ = XiaoMount_ParseItemLink(itemLink)
                if itemId == S_OCEANS_GAZE_ID then
                    if ringBag ~= nil then
                        ring2Bag = bag
                        ring2Slot = slot
                    else
                        ringBag = bag
                        ringSlot = slot
                    end
                end
            end
        end
    end
    return ringBag, ringSlot, ring2Bag, ring2Slot
end

function XiaoMount_RidingGloves()
    for bag = 0, 4 do
        for slot = 0, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local _, enchantId = XiaoMount_ParseItemLink(itemLink)
                if enchantId == S_GLOVE_ENCHANT then
                    return bag, slot
                end
            end
        end
    end
    return nil, nil
end

-- returns bag position of best available riding boots
function XiaoMount_BestRidingBoots()
    local bootsBag = nil
    local bootsSlot = nil
    for bag = 0, 4 do
        for slot = 0, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local _, enchantId = XiaoMount_ParseItemLink(itemLink)
                if enchantId == S_THORIUM_SPURS_ENCHANT then
                    return bag, slot
                elseif enchantId == S_MITHRIL_SPURS_ENCHANT then
                    bootsBag = bag
                    bootsSlot = slot
                end
            end
        end
    end
    return bootsBag, bootsSlot
end

function XiaoMount_FindItem(item)
    for bag = 0, 4 do
        for slot = 0, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local itemId, _ = XiaoMount_ParseItemLink(itemLink)
                if item == itemId then
                    return bag, slot
                end
            end
        end
    end
    return nil, nil
end

function XiaoMount_EquipItem(bag, slot, inventorySlot)
    ClearCursor();
    PickupContainerItem(bag, slot)
    PickupInventoryItem(inventorySlot)
end

function XiaoMount_ParseItemLink(link)
    if not link then
        return nil, nil
    end

    local firstColon = string.find(link, ":", 1, true)
    if not firstColon then
        return nil, nil
    end
    local secondColon = string.find(link, ":", firstColon + 1, true)
    if not secondColon then
        return nil, nil
    end
    local thirdColon = string.find(link, ":", secondColon + 1, true)
    thirdColon = thirdColon or (string.len(link) + 1)

    local itemId = string.sub(link, firstColon + 1, secondColon - 1)
    local enchantId = string.sub(link, secondColon + 1, thirdColon - 1)

    return itemId, enchantId
end

-- Create a hidden tooltip for scanning buff names
local buffTooltip = CreateFrame("GameTooltip", "BuffScanTooltip", nil, "GameTooltipTemplate")
buffTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- check player buffs to determine if they are mounted or not
function XiaoMount_IsMounted()
    for i = 0, 15 do
        local buffIndex = GetPlayerBuff(i)
        if buffIndex >= 0 then
            -- -1 means no buff in slot
            buffTooltip:ClearLines()
            buffTooltip:SetPlayerBuff(buffIndex)
            local buffDescription = BuffScanTooltipTextLeft2:GetText()
            if buffDescription then
                if string.find(buffDescription, "Riding")
                        or string.find(buffDescription, "Slow and steady...")
                        or string.find(buffDescription, "Augmente la vitesse")
                        or string.find(buffDescription, "Erh\195\182ht Tempo um")
                        or string.find(buffDescription, "이동 속도 (%d+)%%만큼 증가") then
                    return true
                end
            end
        end
    end
    return false
end

SLASH_XIAOMOUNT1 = "/xiaomount"
SLASH_XIAOMOUNT2 = "/xm"
SlashCmdList["XIAOMOUNT"] = function(msg, editbox)
    -- parse command arguments
    local args = {}
    local i = 1
    for arg in string.gfind(msg, '%S+') do
        args[i] = arg
        i = i + 1
    end

    if not args[1] then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8000Xiao|rMount:")
        DEFAULT_CHAT_FRAME:AddMessage(" /xiaomount enabled")
    elseif args[1] == "enabled" then
        if not args[2] then
            if XiaoMountDB.enabled then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff8000Xiao|rMount is currently |cff00ff00enabled")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffff8000Xiao|rMount is currently |cffff0000disabled")
            end
        else
            if args[2] == "1" then
                XiaoMountDB.enabled = true
                DEFAULT_CHAT_FRAME:AddMessage("|cffff8000Xiao|rMount has been |cff00ff00enabled")
            elseif args[2] == "0" then
                XiaoMountDB.enabled = false
                DEFAULT_CHAT_FRAME:AddMessage("|cffff8000Xiao|rMount has been |cffff0000disabled")
            end
        end
    elseif args[1] == "mountcheck" then
        if XiaoMount_IsMounted() then
            DEFAULT_CHAT_FRAME:AddMessage("mounted")
        else
            DEFAULT_CHAT_FRAME:AddMessage("dismounted")
        end
    end
end
