--[[
Guidelime Vanilla

Author: Grommey

Description:
Equipment Tracker. Track when items are equipped and auto-complete "Equip" steps.
]]--
local _G = _G or getfenv(0)
local GLV = LibStub("GuidelimeVanilla")

local EquipmentTracker = {}
GLV.EquipmentTracker = EquipmentTracker

-- Equipment slot IDs in WoW 1.12
local EQUIPMENT_SLOTS = {
    1,  -- Head
    2,  -- Neck
    3,  -- Shoulder
    4,  -- Shirt
    5,  -- Chest
    6,  -- Waist
    7,  -- Legs
    8,  -- Feet
    9,  -- Wrist
    10, -- Hands
    11, -- Finger 1
    12, -- Finger 2
    13, -- Trinket 1
    14, -- Trinket 2
    15, -- Back
    16, -- Main Hand
    17, -- Off Hand
    18, -- Ranged
    19, -- Tabard
}

-- Initialize equipment tracking
function EquipmentTracker:Init()
    if GLV.Ace then
        GLV.Ace:RegisterEvent("UNIT_INVENTORY_CHANGED", function(unit)
            if unit == "player" then
                self:OnEquipmentChanged()
            end
        end)
    end
end

-- Check if an item is equipped by item ID
function EquipmentTracker:IsItemEquipped(itemId)
    if not itemId then return false end

    local itemIdNum = tonumber(itemId)
    if not itemIdNum then return false end

    for _, slotId in ipairs(EQUIPMENT_SLOTS) do
        local link = GetInventoryItemLink("player", slotId)
        if link then
            -- Extract item ID from link: |cff9d9d9d|Hitem:ITEMID:...|h[Name]|h|r
            local equippedId = tonumber(string.match(link, "item:(%d+)"))
            if equippedId and equippedId == itemIdNum then
                return true
            end
        end
    end

    return false
end

-- Handle equipment changes
function EquipmentTracker:OnEquipmentChanged()
    if not GLV.CurrentDisplaySteps then
        return
    end

    local currentGuideId = GLV.Settings:GetOption({"Guide", "CurrentGuide"}) or "Unknown"
    local currentStep = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "CurrentStep"}) or 0
    local stepState = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "StepState"}) or {}
    local diToOrig = GLV.CurrentDisplayToOriginal or {}

    -- Check if current step or nearby steps have equip requirements
    local stepsToCheck = {}
    for offset = 0, 3 do
        local stepIndex = currentStep + offset
        if stepIndex > 0 and GLV.CurrentDisplaySteps[stepIndex] then
            table.insert(stepsToCheck, stepIndex)
        end
    end

    local stepMarked = false

    for _, stepIndex in ipairs(stepsToCheck) do
        local step = GLV.CurrentDisplaySteps[stepIndex]
        local origIdx = diToOrig[stepIndex]

        if step and origIdx and not stepState[origIdx] then
            -- Check if this step has equip requirement
            local equipItemId = nil

            -- Check step lines for equipItemId
            if step.lines then
                for _, line in ipairs(step.lines) do
                    if line.equipItemId then
                        equipItemId = line.equipItemId
                        break
                    end
                end
            end

            -- Also check direct step property (in case it's not nested in lines)
            if not equipItemId and step.equipItemId then
                equipItemId = step.equipItemId
            end

            if equipItemId and self:IsItemEquipped(equipItemId) then
                stepState[origIdx] = true
                stepMarked = true

                if GLV.Debug then
                    local itemName = GLV:GetItemNameById(equipItemId) or "Unknown"
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[Equipment]|r Auto-completed: Equip " .. itemName)
                end
            end
        end
    end

    if stepMarked then
        GLV.Settings:SetOption(stepState, {"Guide", "Guides", currentGuideId, "StepState"})

        -- Recalculate current step (find first unchecked)
        local newCurrentStep = currentStep
        for i = 1, GLV.CurrentDisplayStepsCount or 0 do
            if GLV.CurrentDisplayHasCheckbox and GLV.CurrentDisplayHasCheckbox[i] then
                local orig = diToOrig[i]
                if orig and not stepState[orig] then
                    newCurrentStep = i
                    break
                end
            end
        end

        if newCurrentStep ~= currentStep then
            GLV.Settings:SetOption(newCurrentStep, {"Guide", "Guides", currentGuideId, "CurrentStep"})
        end

        -- Refresh UI to show updated checkboxes and highlight
        if GLV.RefreshGuide then
            GLV:RefreshGuide()
        end
    end
end
