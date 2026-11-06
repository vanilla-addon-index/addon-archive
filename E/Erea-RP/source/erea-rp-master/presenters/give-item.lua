-- ============================================================================
-- give-item.lua - EreaRpMasterGiveItemFrame Controller
-- ============================================================================
-- UI Structure: views/give-item.xml
-- Frame: EreaRpMasterGiveItemFrame (defined in XML)
--
-- PURPOSE: Dialog for giving a committed item to a player with optional
--          message, custom text, and counter fields.
--
-- METHODS:
--   EreaRpMasterGiveItemFrame:Initialize()    - Setup refs, handlers
--   EreaRpMasterGiveItemFrame:Open(cItem)     - Open dialog for committed item
--
-- DEPENDENCIES:
--   - EreaRpMasterEventHandler (services/event-handler.lua)
--   - EreaRpMasterItemLibrary (services/item-library.lua)
-- ============================================================================

-- ============================================================================
-- Imports
-- ============================================================================
local Log = EreaRpLibraries:Logging("EreaRpMaster")

-- ============================================================================
-- Local state
-- ============================================================================
local _selectedPlayer = nil
local _currentItem = nil

-- ============================================================================
-- Initialize
-- ============================================================================
function EreaRpMasterGiveItemFrame:Initialize()
    local self = EreaRpMasterGiveItemFrame

    -- Store frame references
    self.titleBar = EreaRpMasterGiveItemFrameTitleBar
    self.closeButton = EreaRpMasterGiveItemFrameCloseButton
    self.iconTexture = EreaRpMasterGiveItemFrameIconFrameIconTexture
    self.itemName = EreaRpMasterGiveItemFrameItemName
    self.messageEditBox = EreaRpMasterGiveItemFrameMessageEditBox
    self.customTextEditBox     = EreaRpMasterGiveItemFrameCustomTextEditBox
    self.additionalTextEditBox = EreaRpMasterGiveItemFrameAdditionalTextEditBox
    self.counterEditBox        = EreaRpMasterGiveItemFrameCounterEditBox
    self.giveButton = EreaRpMasterGiveItemFrameGiveButton
    self.cancelButton = EreaRpMasterGiveItemFrameCancelButton

    -- Create player dropdown (WoW 1.12: UIDropDownMenuTemplate)
    self.playerDropdown = CreateFrame("Frame", "EreaRpMasterGiveItemPlayerDropdown", self, "UIDropDownMenuTemplate")
    self.playerDropdown:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -112)
    UIDropDownMenu_SetWidth(160, self.playerDropdown)  -- Lua 5.0: WoW 1.12 arg order is (width, dropdown)

    -- Title bar dragging
    self.titleBar:SetScript("OnMouseDown", function()
        EreaRpMasterGiveItemFrame:StartMoving()
    end)
    self.titleBar:SetScript("OnMouseUp", function()
        EreaRpMasterGiveItemFrame:StopMovingOrSizing()
    end)

    -- Give button
    self.giveButton:SetScript("OnClick", function()
        EreaRpMasterGiveItemFrame:GiveCurrentItem()
    end)

    -- Cancel button
    self.cancelButton:SetScript("OnClick", function()
        EreaRpMasterGiveItemFrame:Hide()
    end)

    -- Close button hides frame
    self.closeButton:SetScript("OnClick", function()
        EreaRpMasterGiveItemFrame:Hide()
    end)
end

-- ============================================================================
-- Open - Show dialog for a committed item
-- ============================================================================
function EreaRpMasterGiveItemFrame:Open(committedItem)
    local self = EreaRpMasterGiveItemFrame

    _currentItem = committedItem
    _selectedPlayer = nil

    -- Set icon
    if committedItem.icon and committedItem.icon ~= "" then
        self.iconTexture:SetTexture(committedItem.icon)
    else
        self.iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- Set item name
    self.itemName:SetText(committedItem.name or "Unknown Item")

    -- Populate player dropdown
    UIDropDownMenu_Initialize(self.playerDropdown, function()
        local myName = UnitName("player")

        -- Self as first entry
        do
            local info = {}
            info.text = myName .. " (self)"
            info.notCheckable = 1
            local playerName = myName  -- Lua 5.0: capture for closure
            info.func = function()
                _selectedPlayer = playerName
                UIDropDownMenu_SetText(playerName .. " (self)", EreaRpMasterGiveItemPlayerDropdown)
            end
            UIDropDownMenu_AddButton(info)
        end

        -- Raid members (skip self)
        local numRaid = GetNumRaidMembers()
        if numRaid > 0 then
            for i = 1, numRaid do
                local name = GetRaidRosterInfo(i)
                if name and name ~= "" and name ~= myName then
                    do  -- Lua 5.0: do/end block for closure-safe capture
                        local playerName = name
                        local info = {}
                        info.text = playerName
                        info.notCheckable = 1
                        info.func = function()
                            _selectedPlayer = playerName
                            UIDropDownMenu_SetText(playerName, EreaRpMasterGiveItemPlayerDropdown)
                        end
                        UIDropDownMenu_AddButton(info)
                    end
                end
            end
        else
            -- Party members (only when not in raid)
            for i = 1, 4 do
                local name = UnitName("party" .. i)
                if name and name ~= "" then
                    do  -- Lua 5.0: do/end block for closure-safe capture
                        local playerName = name
                        local info = {}
                        info.text = playerName
                        info.notCheckable = 1
                        info.func = function()
                            _selectedPlayer = playerName
                            UIDropDownMenu_SetText(playerName, EreaRpMasterGiveItemPlayerDropdown)
                        end
                        UIDropDownMenu_AddButton(info)
                    end
                end
            end
        end
    end)

    -- Default to current target if it's a player in the group
    local targetName = UnitName("target")
    if targetName and UnitIsPlayer("target") and targetName ~= "" then
        _selectedPlayer = targetName
        UIDropDownMenu_SetText(targetName, self.playerDropdown)
    else
        UIDropDownMenu_SetText("Select player...", self.playerDropdown)
    end

    -- Pre-fill fields from item defaults
    self.messageEditBox:SetText(committedItem.defaultHandoutText or "")
    self.customTextEditBox:SetText("")
    self.additionalTextEditBox:SetText("")
    self.counterEditBox:SetText(tostring(committedItem.initialCounter or 0))

    self:Show()
    self:Raise()
end

-- ============================================================================
-- GiveCurrentItem - Validate and send item
-- ============================================================================
function EreaRpMasterGiveItemFrame:GiveCurrentItem()
    local self = EreaRpMasterGiveItemFrame

    if not _selectedPlayer then
        Log("GiveCurrentItem: no player selected")
        return
    end

    if not _currentItem or not _currentItem.guid then
        Log("GiveCurrentItem: no item selected")
        return
    end

    -- Must be in a group or raid
    if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
        Log("GiveCurrentItem: not in a group or raid")
        return
    end

    local message        = self.messageEditBox:GetText() or ""
    local customText     = self.customTextEditBox:GetText() or ""
    local additionalText = self.additionalTextEditBox:GetText() or ""
    local counter        = tonumber(self.counterEditBox:GetText()) or 0

    EreaRpMasterEventHandler:GiveItem(_selectedPlayer, _currentItem.guid, message, customText, counter, additionalText)

    self:Hide()
end
