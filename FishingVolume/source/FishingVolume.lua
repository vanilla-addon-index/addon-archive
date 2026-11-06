-- FishingVolume.lua
-- Core logic for volume adjustment and fishing utility.
FishingVolume = FishingVolume or {}

local CHANNEL_NAME = "Fishing"

local isFishingVolume  = false
local lastCastTime     = nil
local pendingRecast    = false  
local lastFishActivity = 0      
FishingVolume.intentionalSwap = false -- Prevents warnings during gear swaps

-- ================================================================
-- DEFAULTS & SETTINGS
-- ================================================================

FishingVolumeDB = FishingVolumeDB or {}

local defaults = {
    fishingVolume = 1.0,
    soundVolume   = nil,
    muteDelay     = 30,
    muteOnStop    = true,
    autoRecast    = false,
    savedMainHand = nil,
    savedOffHand  = nil,
    totalFish     = 0,
    totalChests   = 0,
}

local function GetSetting(key)
    if FishingVolumeDB[key] ~= nil then return FishingVolumeDB[key] end
    if defaults[key] ~= nil then return defaults[key] end
    if key == "soundVolume" then return tonumber(GetCVar("SoundVolume")) or 0 end
    return nil
end

local function SetSetting(key, value)
    FishingVolumeDB[key] = value
end

local function GetItemName(link)
    if not link then return nil end
    local _, _, name = string.find(link, "%[(.-)%]")
    return name
end

FishingVolume.GetSetting  = GetSetting
FishingVolume.SetSetting  = SetSetting
FishingVolume.GetItemName = GetItemName
FishingVolume.defaults    = defaults

FishingVolume.sessionFish   = 0
FishingVolume.sessionChests = 0

local function RestoreVolume()
    SetCVar("SoundVolume", tostring(GetSetting("soundVolume")))
    isFishingVolume = false
    lastCastTime    = nil
end

-- ================================================================
-- UTILITY — LURES & GEAR
-- ================================================================

-- Persistent wait frame for intentionalSwap reset — reused, never recreated
local swapWaitFrame = CreateFrame("Frame")
swapWaitFrame:SetScript("OnUpdate", nil)

local function StartSwapWait()
    local t = 0
    swapWaitFrame:SetScript("OnUpdate", function()
        t = t + arg1
        if t > 1.5 then
            FishingVolume.intentionalSwap = false
            swapWaitFrame:SetScript("OnUpdate", nil)
        end
    end)
end

local LURE_PRIORITY = {
    "Aquadynamic Fish Attractor",
    "Aquadynamic Fish Lens",
    "Flesh Eating Worm",
    "Bright Baubles",
    "Nightcrawlers",
    "Shiny Baubles",
}

function FishingVolume:ApplyBestLure()
    for _, lureName in ipairs(LURE_PRIORITY) do
        for bag = 0, 4 do
            local slots = GetContainerNumSlots(bag)
            for slot = 1, slots do
                local name = GetItemName(GetContainerItemLink(bag, slot))
                if name and name == lureName then
                    UseContainerItem(bag, slot)
                    PickupInventoryItem(16)
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33cc99FishingVolume:|r Applying: " .. lureName)
                    return
                end
            end
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FishingVolume:|r No lures found.")
end

function FishingVolume:EquipPole()
    local mhLink = GetInventoryItemLink("player", 16)
    local ohLink = GetInventoryItemLink("player", 17)
    local mhName = GetItemName(mhLink)

    if mhName and not string.find(mhName, "Pole") then
        SetSetting("savedMainHand", mhLink)
        SetSetting("savedOffHand",  ohLink)
    end

    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local name = GetItemName(GetContainerItemLink(bag, slot))
            if name and string.find(name, "Pole") then
                UseContainerItem(bag, slot)
                DEFAULT_CHAT_FRAME:AddMessage("|cff33cc99FishingVolume:|r Equipped: " .. name .. ".")
                return
            end
        end
    end
end

function FishingVolume:EquipWeapons()
    local mh = GetSetting("savedMainHand")
    local oh = GetSetting("savedOffHand")

    if not mh then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FishingVolume:|r No saved weapons found.")
        return
    end

    -- SILENCE WARNINGS: Set intentionalSwap to true
    FishingVolume.intentionalSwap = true
    pendingRecast = false

    local function FindAndEquip(link)
        local targetName = GetItemName(link)
        if not targetName then return end
        for bag = 0, 4 do
            local slots = GetContainerNumSlots(bag)
            for slot = 1, slots do
                if GetItemName(GetContainerItemLink(bag, slot)) == targetName then
                    UseContainerItem(bag, slot)
                    return
                end
            end
        end
    end

    FindAndEquip(mh)
    if oh then FindAndEquip(oh) end
    
    if FV_RecastOverlay then FV_RecastOverlay:Hide() end
    lastFishActivity = 0 
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff33cc99FishingVolume:|r Equipped: Weapon.")
    StartSwapWait()
end

function FishingVolume:CastFishing()
    CastSpellByName("Fishing")
end

-- ================================================================
-- RECAST ENGINE
-- ================================================================

local recastOverlay = CreateFrame("Button", "FV_RecastOverlay", UIParent)
recastOverlay:SetWidth(900)
recastOverlay:SetHeight(400)
recastOverlay:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
recastOverlay:Hide()

-- Register for both Left and Right clicks
recastOverlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")

local tint = recastOverlay:CreateTexture(nil, "BACKGROUND")
tint:SetAllPoints(recastOverlay)
tint:SetTexture(0, 0.5, 1, 0.02) 

local fontString = recastOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
fontString:SetPoint("CENTER", recastOverlay, "CENTER", 0, 0)
fontString:SetText("LEFT CLICK: FISH | RIGHT CLICK: HIDE")
fontString:SetTextColor(1, 1, 1, 0.4) 

recastOverlay:SetScript("OnClick", function()
    if arg1 == "RightButton" then
        -- Right click only hides the overlay and stops the pending recast
        this:Hide()
        pendingRecast = false
    else
        -- Left click hides and casts
        this:Hide() 
        FishingVolume:CastFishing() 
    end
end)

local function TriggerRecast()
    if not GetSetting("autoRecast") or FishingVolume.intentionalSwap then return end
    
    local mhLink = GetInventoryItemLink("player", 16)
    local mhName = GetItemName(mhLink)
    if mhName and string.find(mhName, "Pole") then
        lastFishActivity = GetTime()
        recastOverlay:Show()
    end
end

local overlayCheckElapsed = 0
local function UpdateOverlayVisibility(dt)
    if not recastOverlay:IsVisible() then return end
    overlayCheckElapsed = overlayCheckElapsed + dt
    if overlayCheckElapsed < 0.5 then return end
    overlayCheckElapsed = 0

    local mhLink = GetInventoryItemLink("player", 16)
    local mhName = GetItemName(mhLink)
    local hasPole = mhName and string.find(mhName, "Pole")
    if not hasPole or (GetTime() - lastFishActivity > 10) or UnitAffectingCombat("player") then
        recastOverlay:Hide()
    end
end

-- ================================================================
-- EVENTS
-- ================================================================

local f = CreateFrame("Frame")
f:RegisterEvent("SPELLCAST_CHANNEL_START")
f:RegisterEvent("SPELLCAST_CHANNEL_STOP")
f:RegisterEvent("SPELLCAST_STOP") 
f:RegisterEvent("SPELLCAST_INTERRUPTED")
f:RegisterEvent("LOOT_OPENED")
f:RegisterEvent("LOOT_CLOSED")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("CHAT_MSG_LOOT")

f:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" or event == "PLAYER_ENTERING_WORLD" then
        FishingVolumeDB = FishingVolumeDB or {}
        if FishingVolumeDB.soundVolume == nil then
            FishingVolumeDB.soundVolume = tonumber(GetCVar("SoundVolume")) or 0
        end
        FishingVolume.sessionFish, FishingVolume.sessionChests = 0, 0
        if FishingVolume.RefreshZoneSkill then FishingVolume.RefreshZoneSkill() end

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        if FishingVolume.RefreshZoneSkill then FishingVolume.RefreshZoneSkill() end

    elseif event == "SPELLCAST_CHANNEL_START" then
        if arg1 == CHANNEL_NAME or arg2 == CHANNEL_NAME then
            lastFishActivity = GetTime()
            recastOverlay:Hide() 
            lastCastTime = GetTime()
            pendingRecast = false
            if not isFishingVolume then
                SetCVar("SoundVolume", tostring(GetSetting("fishingVolume")))
                isFishingVolume = true
            end
        end

    elseif event == "SPELLCAST_STOP" or event == "SPELLCAST_CHANNEL_STOP" or event == "SPELLCAST_INTERRUPTED" then
        if isFishingVolume and not FishingVolume.intentionalSwap then
            if GetSetting("autoRecast") then
                pendingRecast = true
                if not (LootFrame and LootFrame:IsVisible()) then
                    pendingRecast = false
                    TriggerRecast()
                end
            end
            if GetSetting("muteOnStop") then RestoreVolume() end
        end

    elseif event == "LOOT_OPENED" then
        if isFishingVolume then 
            lastCastTime = GetTime() 
            lastFishActivity = GetTime()
            if GetSetting("autoRecast") then pendingRecast = true end
        end

    elseif event == "LOOT_CLOSED" then
        if pendingRecast and not FishingVolume.intentionalSwap then
            pendingRecast = false
            TriggerRecast()
        end

    elseif event == "CHAT_MSG_LOOT" then
    if not (string.find(arg1, "You receive loot") or string.find(arg1, "You create")) then return end
    lastFishActivity = GetTime()

    local fishNames = {
        "Raw ",
        "Firefin Snapper",
        "Oily Blackmouth",
        "Lightning Eel",
        "Plated Armorfish",
    }

    local isFish = false
    for _, name in ipairs(fishNames) do
        if string.find(arg1, name) then
            isFish = true
            break
        end
    end

    if isFish then
        FishingVolume.sessionFish = FishingVolume.sessionFish + 1
        SetSetting("totalFish", GetSetting("totalFish") + 1)
        if FishingVolume.RefreshZoneSkill then FishingVolume.RefreshZoneSkill() end
    elseif string.find(arg1, "Trunk") or string.find(arg1, "Locked Chest") then
        FishingVolume.sessionChests = FishingVolume.sessionChests + 1
        SetSetting("totalChests", GetSetting("totalChests") + 1)
        if FishingVolume.RefreshZoneSkill then FishingVolume.RefreshZoneSkill() end
    end
end
end)

f:SetScript("OnUpdate", function()
    UpdateOverlayVisibility(arg1)

    -- Timer-based volume restore (for delay-only mode)
    if isFishingVolume and lastCastTime then
        if not GetSetting("muteOnStop") then
            if (GetTime() - lastCastTime) >= GetSetting("muteDelay") then
                RestoreVolume()
            end
        end
    end

    -- Poller for LootFrame close (only runs when a recast is pending)
    if pendingRecast and not FishingVolume.intentionalSwap then
        if not (LootFrame and LootFrame:IsVisible()) then
            pendingRecast = false
            TriggerRecast()
        end
    end
end)

-- ================================================================
-- SLASH COMMAND
-- ================================================================

local resetPending = false
local resetTimer = 0

SLASH_FV1 = "/fv"
SlashCmdList["FV"] = function(msg)
    local cmd = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))

    if cmd == "mini" then
        if FishingVolume_ToggleMiniPanel then FishingVolume_ToggleMiniPanel() end
        return
    elseif cmd == "zones" then
        if FishingVolume_ToggleZonesFrame then FishingVolume_ToggleZonesFrame() end
        return
    elseif cmd == "reset" then
        if resetPending and (GetTime() - resetTimer) < 10 then
            FishingVolumeDB = {}
            FishingVolume.sessionFish, FishingVolume.sessionChests = 0, 0
            FishingVolumeDB.soundVolume = tonumber(GetCVar("SoundVolume")) or 0
            DEFAULT_CHAT_FRAME:AddMessage("|cff33cc99FishingVolume:|r All stats and settings have been RESET.")
            if FishingVolumeFrame and FishingVolumeFrame:IsVisible() then FishingVolume_OnShow(FishingVolumeFrame) end
            resetPending = false 
        else
            resetPending, resetTimer = true, GetTime()
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FishingVolume Warning:|r This will wipe all stats and settings.")
            DEFAULT_CHAT_FRAME:AddMessage("|cffffffffType |cff33cc99/fv reset|r |cffffffffagain within 10 seconds to confirm.")
        end
        return
    end

    if not FishingVolumeFrame then return end
    if FishingVolumeFrame:IsVisible() then FishingVolumeFrame:Hide() else FishingVolumeFrame:Show() end
end
