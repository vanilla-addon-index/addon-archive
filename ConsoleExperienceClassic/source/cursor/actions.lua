--[[
    ConsoleExperienceClassic - Actions Module
    
    Defines cursor actions that can be bound to keys
]]

-- ============================================================================
-- Cursor Movement
-- ============================================================================

function CE_MoveCursor(direction)
    local Cursor = ConsoleExperience.cursor
    
    if not Cursor.navigationState.currentButton then
        CE_Debug("MoveCursor: No current button")
        return
    end
    
    if not Cursor.navigationState.closest then
        CE_Debug("MoveCursor: No closest buttons calculated")
        return
    end
    
    local targetButton = nil
    local oppositeDirection = nil
    
    -- Determine opposite direction first (always set it)
    if direction == "UP" then
        oppositeDirection = "down"
        if Cursor.navigationState.closest.up then
            targetButton = Cursor.navigationState.closest.up.button
        end
    elseif direction == "DOWN" then
        oppositeDirection = "up"
        if Cursor.navigationState.closest.down then
            targetButton = Cursor.navigationState.closest.down.button
        end
    elseif direction == "LEFT" then
        oppositeDirection = "right"
        if Cursor.navigationState.closest.left then
            targetButton = Cursor.navigationState.closest.left.button
        end
    elseif direction == "RIGHT" then
        oppositeDirection = "left"
        if Cursor.navigationState.closest.right then
            targetButton = Cursor.navigationState.closest.right.button
        end
    end
    
    -- If no button found in requested direction, wrap to farthest button in opposite direction
    if not targetButton and oppositeDirection then
        CE_Debug("Wrapping: No button in " .. direction .. ", searching for farthest " .. oppositeDirection)
        
        local currentButton = Cursor.navigationState.currentButton
        local currentFrame = Cursor.navigationState.currentFrame
        
        -- Refresh navigation state to ensure allButtons is up to date
        if currentButton and currentFrame then
            Cursor:UpdateNavigationState(currentButton, currentFrame)
        end
        
        local allButtons = Cursor.navigationState.allButtons
        local currentX, currentY = currentButton:GetCenter()
        
        local buttonCount = 0
        if allButtons then
            buttonCount = table.getn(allButtons)
        end
        
        CE_Debug("Total buttons available: " .. buttonCount)
        CE_Debug("Wrapping: No button in " .. direction .. ", searching for farthest " .. oppositeDirection .. " (total buttons: " .. buttonCount .. ")")
        
        if currentX and currentY and allButtons and table.getn(allButtons) > 0 then
            local farthestButton = nil
            local maxAxisDistance = 0
            
            -- Debug: show current button info
            local currentButtonName = currentButton:GetName() or "unnamed"
            CE_Debug("Current button: " .. currentButtonName .. " at (" .. string.format("%.1f", currentX) .. ", " .. string.format("%.1f", currentY) .. ")")
            
            -- Tolerance for considering buttons on the same row/column (in pixels)
            local axisTolerance = 36  -- Allow differences due to UI scaling and button spacing
            
            -- Find farthest button in opposite direction along the same axis
            for _, buttonInfo in ipairs(allButtons) do
                local buttonName = buttonInfo.name or "unnamed"
                local isCurrentButton = (buttonInfo.button == currentButton)
                CE_Debug("Checking button " .. buttonName .. ": isCurrent=" .. tostring(isCurrentButton) .. ", visible=" .. tostring(buttonInfo.button:IsVisible()))
                
                if not isCurrentButton and buttonInfo.button:IsVisible() then
                    local dx = buttonInfo.x - currentX
                    local dy = buttonInfo.y - currentY
                    local angle = math.atan2(dy, dx)
                    local degrees = angle * 180 / math.pi
                    
                    local onSameAxis = false
                    local axisDistance = 0
                    
                    if oppositeDirection == "left" or oppositeDirection == "right" then
                        -- For LEFT/RIGHT wrapping, find buttons on the same row (same Y)
                        local yDiff = math.abs(buttonInfo.y - currentY)
                        CE_Debug("Button " .. buttonName .. ": yDiff=" .. string.format("%.1f", yDiff) .. ", tolerance=" .. axisTolerance)
                        if yDiff <= axisTolerance then
                            onSameAxis = true
                            -- Distance along X axis (positive = right, negative = left)
                            axisDistance = dx
                            
                            -- For LEFT wrapping (oppositeDirection="right"), we want the rightmost button (positive dx)
                            -- For RIGHT wrapping (oppositeDirection="left"), we want the leftmost button (negative dx)
                            if oppositeDirection == "right" then
                                -- Wrapping LEFT - looking for rightmost button (positive dx)
                                CE_Debug("Button " .. buttonName .. ": axisDistance=" .. string.format("%.1f", axisDistance) .. ", maxAxisDistance=" .. string.format("%.1f", maxAxisDistance) .. ", condition=" .. tostring(axisDistance > 0 and axisDistance > maxAxisDistance))
                                if axisDistance > 0 and axisDistance > maxAxisDistance then
                                    maxAxisDistance = axisDistance
                                    farthestButton = buttonInfo.button
                                    CE_Debug("SELECTED as farthest: " .. buttonName .. " (new maxAxisDistance=" .. string.format("%.1f", maxAxisDistance) .. ")")
                                end
                            elseif oppositeDirection == "left" then
                                -- Wrapping RIGHT - looking for leftmost button (negative dx)
                                CE_Debug("Button " .. buttonName .. ": axisDistance=" .. string.format("%.1f", axisDistance) .. ", maxAxisDistance=" .. string.format("%.1f", maxAxisDistance) .. ", condition=" .. tostring(axisDistance < 0 and math.abs(axisDistance) > maxAxisDistance))
                                if axisDistance < 0 and math.abs(axisDistance) > maxAxisDistance then
                                    maxAxisDistance = math.abs(axisDistance)
                                    farthestButton = buttonInfo.button
                                    CE_Debug("SELECTED as farthest: " .. buttonName .. " (new maxAxisDistance=" .. string.format("%.1f", maxAxisDistance) .. ")")
                                end
                            end
                        end
                    elseif oppositeDirection == "up" or oppositeDirection == "down" then
                        -- For UP/DOWN wrapping, find buttons on the same column (same X)
                        local xDiff = math.abs(buttonInfo.x - currentX)
                        CE_Debug("Button " .. buttonName .. ": xDiff=" .. string.format("%.1f", xDiff) .. ", tolerance=" .. axisTolerance)
                        if xDiff <= axisTolerance then
                            onSameAxis = true
                            -- Distance along Y axis (positive = up, negative = down)
                            axisDistance = dy
                            
                            -- For UP wrapping (oppositeDirection="down"), we want the bottommost button (negative dy)
                            -- For DOWN wrapping (oppositeDirection="up"), we want the topmost button (positive dy)
                            if oppositeDirection == "down" then
                                -- Wrapping UP - looking for bottommost button (negative dy)
                                CE_Debug("Button " .. buttonName .. ": axisDistance=" .. string.format("%.1f", axisDistance) .. ", maxAxisDistance=" .. string.format("%.1f", maxAxisDistance) .. ", condition=" .. tostring(axisDistance < 0 and math.abs(axisDistance) > maxAxisDistance))
                                if axisDistance < 0 and math.abs(axisDistance) > maxAxisDistance then
                                    maxAxisDistance = math.abs(axisDistance)
                                    farthestButton = buttonInfo.button
                                    CE_Debug("SELECTED as farthest: " .. buttonName .. " (new maxAxisDistance=" .. string.format("%.1f", maxAxisDistance) .. ")")
                                end
                            elseif oppositeDirection == "up" then
                                -- Wrapping DOWN - looking for topmost button (positive dy)
                                CE_Debug("Button " .. buttonName .. ": axisDistance=" .. string.format("%.1f", axisDistance) .. ", maxAxisDistance=" .. string.format("%.1f", maxAxisDistance) .. ", condition=" .. tostring(axisDistance > 0 and axisDistance > maxAxisDistance))
                                if axisDistance > 0 and axisDistance > maxAxisDistance then
                                    maxAxisDistance = axisDistance
                                    farthestButton = buttonInfo.button
                                    CE_Debug("SELECTED as farthest: " .. buttonName .. " (new maxAxisDistance=" .. string.format("%.1f", maxAxisDistance) .. ")")
                                end
                            end
                        end
                    end
                    
                    if onSameAxis then
                        local buttonName = buttonInfo.name or "unnamed"
                        local axisName = (oppositeDirection == "left" or oppositeDirection == "right") and "row" or "column"
                        CE_Debug("Found button " .. buttonName .. " on same " .. axisName .. ": axisDist=" .. string.format("%.1f", axisDistance))
                        CE_Debug("  Found button " .. buttonName .. " on same axis: axisDist=" .. string.format("%.1f", axisDistance))
                    end
                end
            end
            
            CE_Debug("After loop: farthestButton=" .. tostring(farthestButton ~= nil) .. ", maxAxisDistance=" .. string.format("%.1f", maxAxisDistance))
            
            if farthestButton then
                targetButton = farthestButton
                local axisName = (oppositeDirection == "left" or oppositeDirection == "right") and "row" or "column"
                CE_Debug("Wrapping to farthest " .. oppositeDirection .. " button on same " .. axisName .. " (axis distance: " .. string.format("%.1f", maxAxisDistance) .. ")")
            else
                local axisName = (oppositeDirection == "left" or oppositeDirection == "right") and "row" or "column"
                CE_Debug("No buttons found on same " .. axisName .. " for wrapping (maxAxisDistance=" .. string.format("%.1f", maxAxisDistance) .. ")")
            end
        else
            CE_Debug("Cannot wrap: currentX=" .. tostring(currentX) .. ", currentY=" .. tostring(currentY) .. ", allButtons=" .. tostring(allButtons) .. ", buttonCount=" .. (allButtons and table.getn(allButtons) or 0))
            CE_Debug("Cannot wrap: currentX=" .. tostring(currentX) .. ", currentY=" .. tostring(currentY) .. ", allButtons=" .. tostring(allButtons))
        end
    end
    
    if targetButton then
        CE_Debug("Moving to: " .. (targetButton:GetName() or "unnamed"))
        Cursor:MoveCursorToButton(targetButton)
    else
        CE_Debug("No button in direction: " .. direction .. " (and no opposite direction available)")
    end
end

-- ============================================================================
-- Cursor Click
-- ============================================================================

function CE_ClickCursor(mouseButton)
    local Cursor = ConsoleExperience.cursor
    
    if not Cursor.navigationState.currentButton then
        return
    end
    
    local element = Cursor.navigationState.currentButton
    
    -- Hide tooltip before clicking
    if Cursor.tooltip then
        Cursor.tooltip:HideButtonTooltip()
    end
    
    -- Handle binding dropdown buttons - scroll the parent scroll frame to show dropdown
    local buttonName = element:GetName()
    if buttonName and string.find(buttonName, "CEBindingDropdown%d+Button") then
        -- This is a binding dropdown button, scroll to make room for dropdown
        local scrollFrame = getglobal("CEBindingsScrollFrame")
        if scrollFrame then
            local scrollBar = getglobal("CEBindingsScrollFrameScrollBar")
            if scrollBar then
                -- Get the dropdown frame (parent of button)
                local dropdown = element:GetParent()
                if dropdown then
                    -- Calculate the Y position of the dropdown relative to the scroll child
                    local _, dropdownY = dropdown:GetCenter()
                    local scrollChild = scrollFrame:GetScrollChild()
                    if scrollChild and dropdownY then
                        local _, childTop = scrollChild:GetTop(), nil
                        childTop = scrollChild:GetTop()
                        if childTop then
                            -- Calculate offset from top of scroll child
                            local offsetFromTop = childTop - dropdownY
                            -- Scroll so dropdown is near the top of visible area (with small margin)
                            local margin = 30
                            local targetScroll = math.max(0, offsetFromTop - margin)
                            local currentScroll = scrollBar:GetValue()
                            
                            -- Only delay if we need to scroll significantly
                            if math.abs(targetScroll - currentScroll) > 10 then
                                -- Scroll first
                                scrollBar:SetValue(targetScroll)
                                
                                -- Delay the dropdown click until scroll completes
                                -- Create a timer frame if it doesn't exist
                                if not CE_DropdownDelayFrame then
                                    CE_DropdownDelayFrame = CreateFrame("Frame")
                                end
                                
                                CE_DropdownDelayFrame.elapsed = 0
                                CE_DropdownDelayFrame.targetButton = element
                                CE_DropdownDelayFrame:SetScript("OnUpdate", function()
                                    this.elapsed = this.elapsed + arg1
                                    if this.elapsed >= 0.05 then  -- 50ms delay
                                        this:SetScript("OnUpdate", nil)
                                        if this.targetButton and this.targetButton.Click then
                                            this.targetButton:Click(mouseButton or "LeftButton")
                                        end
                                        this.targetButton = nil
                                    end
                                end)
                                
                                -- Return early - the delayed click will happen via OnUpdate
                                return
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Handle placement buttons specially
    local buttonName = element:GetName()
    if buttonName and string.find(buttonName, "CEPlacementButton%d+") then
        local actionSlot = element.actionSlot
        if actionSlot then
            if mouseButton == "LeftButton" then
                -- A button: Pickup if slot has item and cursor is empty, Place if cursor has item
                -- Also check fake cursor for macros (which don't trigger CursorHasItem/CursorHasSpell)
                local hasCursorItem = CursorHasItem() or CursorHasSpell()
                local hasFakeCursorItem = Cursor and Cursor.heldItemTexturePath
                local hasSlotAction = HasAction(actionSlot)
                
                if hasCursorItem or hasFakeCursorItem then
                    -- Cursor has item - place it (will swap if slot has item)
                    -- Get slot texture BEFORE placing (in case we swap)
                    local slotItemTexture = nil
                    if hasSlotAction then
                        slotItemTexture = GetActionTexture(actionSlot)
                    end
                    
                    -- Place item from cursor into slot (will swap if slot has item)
                    PlaceAction(actionSlot)
                    CE_Debug("Placed item in action slot " .. actionSlot)
                    
                    -- Update button display
                    if ConsoleExperience.placement and ConsoleExperience.placement.UpdateButton then
                        ConsoleExperience.placement:UpdateButton(element)
                    end
                    
                    -- Update main action bar
                    if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateAllButtons then
                        ConsoleExperience.actionbars:UpdateAllButtons()
                    end
                    
                    -- Update fake cursor based on result
                    -- For macros, CursorHasItem/CursorHasSpell won't detect a swap
                    -- So we just clear the fake cursor since PlaceAction was called
                    if ConsoleExperience.cursor and ConsoleExperience.cursor.ClearHeldItemTexture then
                        ConsoleExperience.cursor:ClearHeldItemTexture()
                    end
                    CE_Debug("Item placed, fake cursor cleared")
                elseif hasSlotAction then
                    -- Pickup item from slot (only if slot has action and cursor is empty)
                    -- Get texture BEFORE picking up (slot will be empty after PickupAction)
                    local texture = GetActionTexture(actionSlot)
                    if texture then
                        PickupAction(actionSlot)
                        CE_Debug("Picked up item from action slot " .. actionSlot .. " (texture: " .. texture .. ")")
                        
                        -- Update button display
                        if ConsoleExperience.placement and ConsoleExperience.placement.UpdateButton then
                            ConsoleExperience.placement:UpdateButton(element)
                        end
                        
                        -- Show held item on fake cursor (use texture we got before pickup)
                        if ConsoleExperience.cursor and ConsoleExperience.cursor.SetHeldItemTexture then
                            ConsoleExperience.cursor:SetHeldItemTexture(texture)
                        end
                    else
                        CE_Debug("Slot " .. actionSlot .. " has action but no texture - skipping pickup")
                    end
                else
                    CE_Debug("Slot " .. actionSlot .. " is empty and cursor is empty - no action")
                end
            elseif mouseButton == "RightButton" then
                -- B button: Clear slot
                CE_PLACEMENT_CLEAR()
            end
            return
        end
    end
    
    -- Handle different element types
    if element:IsObjectType("EditBox") then
        -- Check if virtual keyboard is enabled
        local config = ConsoleExperience.config
        local keyboardEnabled = config and config:Get("keyboardEnabled")
        
        if keyboardEnabled and ConsoleExperience.keyboard then
            -- Show virtual keyboard for text input
            ConsoleExperience.keyboard:Show(element)
            CE_Debug("Virtual keyboard shown for EditBox")
        else
            -- Keyboard disabled - show info dialog and focus the EditBox
            element:SetFocus()
            CE_Debug("EditBox focused (keyboard disabled)")
            
            -- Show info dialog to let user know how to exit
            if not CE_EditBoxInfoDialog then
                CE_CreateEditBoxInfoDialog()
            end
            if CE_EditBoxInfoDialog then
                CE_EditBoxInfoDialog:Show()
            end
        end
    elseif element:IsObjectType("Slider") then
        -- For sliders, left/right click could adjust value
        if mouseButton == "LeftButton" then
            local min, max = element:GetMinMaxValues()
            local current = element:GetValue()
            local step = element:GetValueStep() or ((max - min) / 10)
            element:SetValue(current + step)
        else
            local min, max = element:GetMinMaxValues()
            local current = element:GetValue()
            local step = element:GetValueStep() or ((max - min) / 10)
            element:SetValue(current - step)
        end
    elseif buttonName and (string.find(buttonName, "ContainerFrame%d+Item%d+") or string.find(buttonName, "pfBag%-?%d+item%d+") or string.find(buttonName, "BagshuiBagsItem%d+") or string.find(buttonName, "BagshuiBankItem%d+") or string.find(buttonName, "BagnonItem%d+") or string.find(buttonName, "BanknonItem%d+")) then
        -- Container items: A button picks up item (or places/swaps if cursor has item)
        -- B button uses the item directly without picking up
        local bagID, slotID = nil, nil
        local isPfUI = string.find(buttonName, "pfBag%-?%d+item%d+")
        local isBagshui = string.find(buttonName, "BagshuiBagsItem%d+") or string.find(buttonName, "BagshuiBankItem%d+")
        local isBagnon = string.find(buttonName, "BagnonItem%d+") or string.find(buttonName, "BanknonItem%d+")
        
        if isBagnon then
            -- Bagnon bag/bank item: Uses same structure as Blizzard - GetID() for slot, GetParent():GetID() for bag
            local parent = element:GetParent()
            if parent then
                bagID = parent:GetID()
                slotID = element:GetID()
            end
            CE_Debug("CE_ClickCursor: Bagnon bag item detected - buttonName=" .. (buttonName or "nil") .. ", bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        elseif isBagshui then
            -- Bagshui bag/bank item: bag and slot info stored in bagshuiData
            if element.bagshuiData and element.bagshuiData.bagNum and element.bagshuiData.slotNum then
                bagID = element.bagshuiData.bagNum
                slotID = element.bagshuiData.slotNum
            end
            CE_Debug("CE_ClickCursor: Bagshui bag item detected - buttonName=" .. (buttonName or "nil") .. ", bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        elseif isPfUI then
            -- pfUI bag item: "pfBag{bag}item{slot}"
            local _, _, bagNum, slotNum = string.find(buttonName, "pfBag(%-?%d+)item(%d+)")
            if bagNum and slotNum then
                bagID = tonumber(bagNum)
                slotID = tonumber(slotNum)
            end
            CE_Debug("CE_ClickCursor: pfUI bag item detected - buttonName=" .. (buttonName or "nil") .. ", bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        else
            -- Blizzard bag item: "ContainerFrame{num}Item{num}"
            local _, _, containerFrameNum = string.find(buttonName, "ContainerFrame(%d+)")
            if containerFrameNum then
                bagID = tonumber(containerFrameNum) - 1
                slotID = element:GetID()
            end
            CE_Debug("CE_ClickCursor: Blizzard container item detected - buttonName=" .. (buttonName or "nil") .. ", ContainerFrame=" .. (containerFrameNum or "nil"))
        end
        
        if mouseButton == "LeftButton" then
            -- Check cursor state before clicking
            local hadCursorItem = CursorHasItem() or CursorHasSpell()
            CE_Debug("CE_ClickCursor: hadCursorItem=" .. tostring(hadCursorItem))
            
            if hadCursorItem then
                -- Cursor has item - check if slot has item (for swapping)
                local slotItemTexture = nil
                
                if not bagID or not slotID then
                    -- Fallback: Try to get from button structure
                    if isBagnon then
                        -- Bagnon: Uses same structure as Blizzard - GetID() for slot, GetParent():GetID() for bag
                        local parentFrame = element:GetParent()
                        if parentFrame then
                            bagID = parentFrame:GetID()
                            slotID = element:GetID()
                        end
                    elseif isBagshui then
                        -- Bagshui: bag and slot info stored in bagshuiData
                        if element.bagshuiData and element.bagshuiData.bagNum and element.bagshuiData.slotNum then
                            bagID = element.bagshuiData.bagNum
                            slotID = element.bagshuiData.slotNum
                        end
                    elseif isPfUI then
                        -- pfUI: bag ID and slot ID already extracted from name
                        -- If extraction failed, try to get from button properties
                        if not bagID then
                            local bagFrame = element:GetParent()
                            if bagFrame and bagFrame.GetID then
                                bagID = bagFrame:GetID()
                            end
                        end
                        if not slotID then
                            slotID = element:GetID()
                        end
                    else
                        -- Blizzard: Use GetParent():GetID() for bag ID, GetID() for slot ID
                        local parentFrame = element:GetParent()
                        bagID = parentFrame and parentFrame:GetID()
                        slotID = element:GetID()
                    end
                end
                
                CE_Debug("CE_ClickCursor: bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
                if bagID and slotID then
                    -- Get slot item texture before clicking (in case we swap)
                    slotItemTexture = GetContainerItemInfo(bagID, slotID)
                    CE_Debug("CE_ClickCursor: slotItemTexture=" .. tostring(slotItemTexture) .. " (nil means slot is empty)")
                end
                
                -- Regular click will place cursor item (and swap if slot has item)
                CE_Debug("CE_ClickCursor: Calling element:Click()")
                if element.Click then
                    element:Click(mouseButton)
                else
                    CE_Debug("CE_ClickCursor: ERROR - element:Click() is nil!")
                end
                
                -- Update fake cursor based on result
                local stillHasCursorItem = CursorHasItem() or CursorHasSpell()
                CE_Debug("CE_ClickCursor: After Click(), cursor still has item? " .. tostring(stillHasCursorItem))
                if stillHasCursorItem then
                    -- Item swap occurred - show the swapped item on fake cursor
                    CE_Debug("CE_ClickCursor: Item swap occurred")
                    if slotItemTexture and Cursor and Cursor.SetHeldItemTexture then
                        Cursor:SetHeldItemTexture(slotItemTexture)
                    end
                else
                    -- Item was placed (slot was empty) - clear fake cursor
                    CE_Debug("CE_ClickCursor: Item was placed, clearing fake cursor")
                    if Cursor and Cursor.ClearHeldItemTexture then
                        Cursor:ClearHeldItemTexture()
                    end
                end
            else
                -- Cursor is empty - use CE_PickupItem to pick up and show on fake cursor
                CE_Debug("CE_ClickCursor: Cursor empty, calling CE_PickupItem()")
                CE_PickupItem()
            end
        elseif mouseButton == "RightButton" then
            -- Right click (B button) should use the item directly without picking up
            -- Use CE_UseItem which uses the item without picking it up
            CE_Debug("CE_ClickCursor: RightButton click, calling CE_UseItem()")
            CE_UseItem()
            return -- Return early to skip the regular refresh/tooltip logic
        end
    elseif buttonName and string.find(buttonName, "Character[A-Za-z0-9]+Slot") then
        -- Character equipment slots: "Select" (A button) should NOT pick up the item
        -- Only "Bind" (X button via CE_PickupItem) should pick it up
        -- So we skip the regular click for equipment slots on left click
        if mouseButton == "LeftButton" then
            -- Just refresh tooltip, don't click (which might pick up the item)
            CE_Debug("Select action on equipment slot - skipping click to prevent pickup")
        elseif mouseButton == "RightButton" then
            -- Right click (B button) should unequip directly without picking up
            -- Use CE_UnequipItem which puts item directly in backpack
            CE_UnequipItem()
            return -- Return early to skip the regular refresh/tooltip logic
        end
    elseif element.Click then
        -- Regular button click
        element:Click(mouseButton)
    end
    
    -- Refresh frame state after click
    Cursor:RefreshFrame()
    
    -- Show tooltip again if element is still visible
    if Cursor.navigationState.currentButton and Cursor.navigationState.currentButton:IsVisible() then
        if Cursor.tooltip then
            Cursor.tooltip:ShowButtonTooltip(Cursor.navigationState.currentButton)
        end
    end
end

-- ============================================================================
-- Specific Actions
-- ============================================================================

function CE_DeleteItem()
    local Cursor = ConsoleExperience.cursor
    local button = Cursor.navigationState.currentButton
    
    if not button then 
        CE_Debug("CE_DeleteItem: No button found")
        return 
    end
    
    local buttonName = button:GetName()
    if not buttonName then 
        CE_Debug("CE_DeleteItem: No button name")
        return 
    end
    
    CE_Debug("CE_DeleteItem: buttonName=" .. buttonName)
    
    -- Check if this is a bag item (Blizzard, pfUI, Bagshui, or Bagnon)
    local isPfUI = string.find(buttonName, "pfBag%-?%d+item%d+")
    local isBagshui = string.find(buttonName, "BagshuiBagsItem%d+") or string.find(buttonName, "BagshuiBankItem%d+")
    local isBagnon = string.find(buttonName, "BagnonItem%d+") or string.find(buttonName, "BanknonItem%d+")
    if string.find(buttonName, "ContainerFrame%d+Item%d+") or isPfUI or isBagshui or isBagnon then
        local bagID, slotID = nil, nil
        
        if isBagnon then
            -- Bagnon bag/bank item: Uses same structure as Blizzard - GetID() for slot, GetParent():GetID() for bag
            local parentFrame = button:GetParent()
            if parentFrame then
                bagID = parentFrame:GetID()
                slotID = button:GetID()
            end
            CE_Debug("CE_DeleteItem: Bagnon bag item - bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        elseif isBagshui then
            -- Bagshui bag/bank item: bag and slot info stored in bagshuiData
            if button.bagshuiData and button.bagshuiData.bagNum and button.bagshuiData.slotNum then
                bagID = button.bagshuiData.bagNum
                slotID = button.bagshuiData.slotNum
            end
            CE_Debug("CE_DeleteItem: Bagshui bag item - bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        elseif isPfUI then
            -- pfUI bag item: extract from name "pfBag{bag}item{slot}"
            local _, _, bagNum, slotNum = string.find(buttonName, "pfBag(%-?%d+)item(%d+)")
            if bagNum and slotNum then
                bagID = tonumber(bagNum)
                slotID = tonumber(slotNum)
            end
            CE_Debug("CE_DeleteItem: pfUI bag item - bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        else
            -- Blizzard bag item: Use GetParent():GetID() for bag ID, GetID() for slot ID
            local parentFrame = button:GetParent()
            bagID = parentFrame and parentFrame:GetID()
            slotID = button:GetID()
            CE_Debug("CE_DeleteItem: Blizzard bag item - parentFrame=" .. (parentFrame and parentFrame:GetName() or "nil") .. ", bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        end
        
        if bagID and slotID then
            -- Check if slot has item before deleting
            local texture, itemCount = GetContainerItemInfo(bagID, slotID)
            CE_Debug("CE_DeleteItem: Slot has item? texture=" .. tostring(texture) .. ", itemCount=" .. tostring(itemCount))
            
            -- Pick up and delete the item
            CE_Debug("CE_DeleteItem: Calling PickupContainerItem(" .. bagID .. ", " .. slotID .. ")")
            PickupContainerItem(bagID, slotID)
            local hasItem = CursorHasItem()
            CE_Debug("CE_DeleteItem: After PickupContainerItem, cursor has item? " .. tostring(hasItem))
            if hasItem then
                CE_Debug("CE_DeleteItem: Calling DeleteCursorItem()")
                DeleteCursorItem()
            else
                CE_Debug("CE_DeleteItem: WARNING - No item on cursor after PickupContainerItem!")
            end
            
            -- Clear cursor state after deletion (item is destroyed, not placed)
            -- This prevents the placement frame from showing
            if CursorHasItem() or CursorHasSpell() then
                ClearCursor()
            end
            
            -- Clear fake cursor texture if it exists
            if Cursor and Cursor.ClearHeldItemTexture then
                Cursor:ClearHeldItemTexture()
            end
            
            -- Ensure placement frame is hidden since item was deleted
            if ConsoleExperience.placement and ConsoleExperience.placement.Hide then
                ConsoleExperience.placement:Hide()
            end
            
            -- Refresh frame state
            if Cursor then
                Cursor:RefreshFrame()
            end
        end
    end
end

function CE_UseItem()
    local Cursor = ConsoleExperience.cursor
    local button = Cursor.navigationState.currentButton
    
    if not button then 
        CE_Debug("CE_UseItem: No button found")
        return 
    end
    
    local buttonName = button:GetName()
    if not buttonName then 
        CE_Debug("CE_UseItem: No button name")
        return 
    end
    
    CE_Debug("CE_UseItem: buttonName=" .. buttonName)
    
    -- Check if this is a container item (Blizzard, pfUI, Bagshui, or Bagnon)
    local isPfUI = string.find(buttonName, "pfBag%-?%d+item%d+")
    local isBagshui = string.find(buttonName, "BagshuiBagsItem%d+") or string.find(buttonName, "BagshuiBankItem%d+")
    local isBagnon = string.find(buttonName, "BagnonItem%d+") or string.find(buttonName, "BanknonItem%d+")
    if string.find(buttonName, "ContainerFrame%d+Item%d+") or isPfUI or isBagshui or isBagnon then
        local bagID, slotID = nil, nil
        
        if isBagnon then
            -- Bagnon bag/bank item: Uses same structure as Blizzard - GetID() for slot, GetParent():GetID() for bag
            local parentFrame = button:GetParent()
            if parentFrame then
                bagID = parentFrame:GetID()
                slotID = button:GetID()
            end
            CE_Debug("CE_UseItem: Bagnon bag item - bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        elseif isBagshui then
            -- Bagshui bag/bank item: bag and slot info stored in bagshuiData
            if button.bagshuiData and button.bagshuiData.bagNum and button.bagshuiData.slotNum then
                bagID = button.bagshuiData.bagNum
                slotID = button.bagshuiData.slotNum
            end
            CE_Debug("CE_UseItem: Bagshui bag item - bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        elseif isPfUI then
            -- pfUI bag item: extract from name "pfBag{bag}item{slot}"
            local _, _, bagNum, slotNum = string.find(buttonName, "pfBag(%-?%d+)item(%d+)")
            if bagNum and slotNum then
                bagID = tonumber(bagNum)
                slotID = tonumber(slotNum)
            end
            CE_Debug("CE_UseItem: pfUI bag item - bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        else
            -- Blizzard bag item: Use GetParent():GetID() for bag ID, GetID() for slot ID
            local parentFrame = button:GetParent()
            bagID = parentFrame and parentFrame:GetID()
            slotID = button:GetID()
            CE_Debug("CE_UseItem: Blizzard bag item - parentFrame=" .. (parentFrame and parentFrame:GetName() or "nil") .. ", bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        end
        
        if bagID and slotID then
            -- Check if slot has item before using
            local texture, itemCount = GetContainerItemInfo(bagID, slotID)
            CE_Debug("CE_UseItem: Slot has item? texture=" .. tostring(texture) .. ", itemCount=" .. tostring(itemCount))
            
            -- Use the item directly without picking it up
            CE_Debug("CE_UseItem: Calling UseContainerItem(" .. bagID .. ", " .. slotID .. ")")
            UseContainerItem(bagID, slotID)
            
            
            -- Refresh frame state
            if Cursor then
                Cursor:RefreshFrame()
            end
        end
    end
end

function CE_UnequipItem()
    local Cursor = ConsoleExperience.cursor
    local button = Cursor.navigationState.currentButton
    
    if not button then return end
    
    local buttonName = button:GetName()
    if not buttonName then return end
    
    -- Check if this is an equipment slot
    if string.find(buttonName, "Character[A-Za-z0-9]+Slot") then
        local slotId = button:GetID()
        if slotId then
            PickupInventoryItem(slotId)
            PutItemInBackpack()
            
            -- Clear cursor state after unequipping (item goes directly to backpack)
            -- This prevents the placement frame from showing
            if CursorHasItem() or CursorHasSpell() then
                ClearCursor()
            end
            
            -- Clear fake cursor texture if it exists
            if Cursor and Cursor.ClearHeldItemTexture then
                Cursor:ClearHeldItemTexture()
            end
            
            -- Ensure placement frame is hidden since item went directly to backpack
            if ConsoleExperience.placement and ConsoleExperience.placement.Hide then
                ConsoleExperience.placement:Hide()
            end
            
            -- Refresh frame state
            if Cursor then
                Cursor:RefreshFrame()
            end
        end
    end
end

function CE_PickupItem()
    local Cursor = ConsoleExperience.cursor
    local button = Cursor.navigationState.currentButton
    
    if not button then 
        CE_Debug("CE_PickupItem: No button found")
        return 
    end
    
    local buttonName = button:GetName()
    if not buttonName then 
        CE_Debug("CE_PickupItem: No button name")
        return 
    end
    CE_Debug("CE_PickupItem: buttonName=" .. buttonName)
    
    local pickedUpTexture = nil
    
    -- Handle different button types
    local isPfUI = string.find(buttonName, "pfBag%-?%d+item%d+")
    local isBagshui = string.find(buttonName, "BagshuiBagsItem%d+") or string.find(buttonName, "BagshuiBankItem%d+")
    local isBagnon = string.find(buttonName, "BagnonItem%d+") or string.find(buttonName, "BanknonItem%d+")
    if string.find(buttonName, "ContainerFrame%d+Item%d+") or isPfUI or isBagshui or isBagnon then
        -- Bag item (Blizzard, pfUI, Bagshui, or Bagnon)
        local bagID, slotID = nil, nil
        
        if isBagnon then
            -- Bagnon bag/bank item: Uses same structure as Blizzard - GetID() for slot, GetParent():GetID() for bag
            local parentFrame = button:GetParent()
            if parentFrame then
                bagID = parentFrame:GetID()
                slotID = button:GetID()
            end
            CE_Debug("CE_PickupItem: Bagnon bag item - bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        elseif isBagshui then
            -- Bagshui bag/bank item: bag and slot info stored in bagshuiData
            if button.bagshuiData and button.bagshuiData.bagNum and button.bagshuiData.slotNum then
                bagID = button.bagshuiData.bagNum
                slotID = button.bagshuiData.slotNum
            end
            CE_Debug("CE_PickupItem: Bagshui bag item - bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        elseif isPfUI then
            -- pfUI bag item: extract from name "pfBag{bag}item{slot}"
            local _, _, bagNum, slotNum = string.find(buttonName, "pfBag(%-?%d+)item(%d+)")
            if bagNum and slotNum then
                bagID = tonumber(bagNum)
                slotID = tonumber(slotNum)
            end
            CE_Debug("CE_PickupItem: pfUI bag item - bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        else
            -- Blizzard bag item: use GetParent():GetID() for bag ID, GetID() for slot ID
            local parentFrame = button:GetParent()
            bagID = parentFrame and parentFrame:GetID()
            slotID = button:GetID()
            CE_Debug("CE_PickupItem: Blizzard bag item - parentFrame=" .. (parentFrame and parentFrame:GetName() or "nil") .. ", bagID=" .. tostring(bagID) .. ", slotID=" .. tostring(slotID))
        end
        
        if bagID and slotID then
            -- Get the item texture before picking up
            pickedUpTexture = GetContainerItemInfo(bagID, slotID)
            CE_Debug("CE_PickupItem: Slot has item? texture=" .. tostring(pickedUpTexture))
            CE_Debug("CE_PickupItem: Calling PickupContainerItem(" .. bagID .. ", " .. slotID .. ")")
            PickupContainerItem(bagID, slotID)
            CE_Debug("CE_PickupItem: After PickupContainerItem, cursor has item? " .. tostring(CursorHasItem() or CursorHasSpell()))
        else
            CE_Debug("CE_PickupItem: ERROR - Could not get bagID or slotID from parent/button")
        end
    elseif string.find(buttonName, "Character[A-Za-z0-9]+Slot") then
        -- Equipment slot
        local slotId = button:GetID()
        if slotId then
            pickedUpTexture = GetInventoryItemTexture("player", slotId)
            PickupInventoryItem(slotId)
        end
    elseif string.find(buttonName, "SpellButton%d+") then
        -- Spellbook spell
        if SpellBookFrame and SpellBookFrame.bookType then
            local id = button:GetID()
            local spellID = id
            if SpellBookFrame.bookType ~= BOOKTYPE_PET then
                spellID = id + SpellBookFrame.selectedSkillLineOffset + 
                    (SPELLS_PER_PAGE * (SPELLBOOK_PAGENUMBERS[SpellBookFrame.selectedSkillLine] - 1))
            end
            -- Get the spell texture before picking up
            pickedUpTexture = GetSpellTexture(spellID, SpellBookFrame.bookType)
            PickupSpell(spellID, SpellBookFrame.bookType)
        end
    elseif string.find(buttonName, "MacroButton%d+") then
        -- Macro button
        CE_Debug("CE_PickupItem: Processing macro button: " .. buttonName)
        
        -- Try multiple methods to get the macro index
        local macroIndex = nil
        
        -- Method 1: Use MacroFrame.selectedMacro if available (set when clicking the button)
        if MacroFrame and MacroFrame.selectedMacro then
            macroIndex = MacroFrame.selectedMacro
            CE_Debug("CE_PickupItem: Using MacroFrame.selectedMacro = " .. tostring(macroIndex))
        end
        
        -- Method 2: Calculate from button ID and macroBase
        if not macroIndex or macroIndex == 0 then
            local macroBase = 0
            if MacroFrame and MacroFrame.macroBase then
                macroBase = MacroFrame.macroBase
            end
            local buttonIndex = button:GetID()
            if buttonIndex and buttonIndex > 0 then
                macroIndex = macroBase + buttonIndex
                CE_Debug("CE_PickupItem: Calculated macroIndex = " .. tostring(macroBase) .. " + " .. tostring(buttonIndex) .. " = " .. tostring(macroIndex))
            end
        end
        
        -- Method 3: Extract from button name as fallback
        if not macroIndex or macroIndex == 0 then
            local _, _, buttonNum = string.find(buttonName, "MacroButton(%d+)")
            if buttonNum then
                macroIndex = tonumber(buttonNum)
                CE_Debug("CE_PickupItem: Using button name number = " .. tostring(macroIndex))
            end
        end
        
        -- Get macro info and texture
        if macroIndex and macroIndex > 0 then
            local macroName, macroTexture, macroBody = GetMacroInfo(macroIndex)
            CE_Debug("CE_PickupItem: GetMacroInfo(" .. macroIndex .. ") = name:" .. tostring(macroName) .. ", texture:" .. tostring(macroTexture))
            
            if macroTexture then
                pickedUpTexture = macroTexture
            else
                -- Fallback: try to get texture from button's icon element
                local iconElement = getglobal(buttonName .. "Icon")
                if iconElement then
                    local tex = iconElement:GetTexture()
                    CE_Debug("CE_PickupItem: Button icon texture = " .. tostring(tex))
                    if tex then
                        pickedUpTexture = tex
                    end
                end
            end
            
            -- Pick up the macro
            CE_Debug("CE_PickupItem: Calling PickupMacro(" .. macroIndex .. ")")
            PickupMacro(macroIndex)
            
            -- Verify pickup worked
            CE_Debug("CE_PickupItem: After PickupMacro, CursorHasItem=" .. tostring(CursorHasItem()) .. ", CursorHasSpell=" .. tostring(CursorHasSpell()))
        else
            CE_Debug("CE_PickupItem: ERROR - Could not determine macro index")
        end
    elseif string.find(buttonName, "CEPlacementButton%d+") then
        -- Placement frame button - use action slot from button
        local actionSlot = button.actionSlot
        if actionSlot then
            pickedUpTexture = GetActionTexture(actionSlot)
            PickupAction(actionSlot)
        end
    elseif string.find(buttonName, "ConsoleActionButton%d+") then
        -- Main action bar button
        local actionSlot = button.actionSlot
        if actionSlot then
            pickedUpTexture = GetActionTexture(actionSlot)
            PickupAction(actionSlot)
        end
    end
    
    -- Update fake cursor to show held item
    if pickedUpTexture and Cursor.SetHeldItemTexture then
        Cursor:SetHeldItemTexture(pickedUpTexture)
    end

    Cursor:RefreshFrame()
end

-- ============================================================================
-- Bind Action (Pickup + Show Placement Frame)
-- ============================================================================

function CE_Bind()
    -- If keyboard is visible, X button should always send text (Confirm)
    if ConsoleExperience.keyboard and ConsoleExperience.keyboard.frame and ConsoleExperience.keyboard.frame:IsVisible() then
        if ConsoleExperience.keyboard.Confirm then
            ConsoleExperience.keyboard:Confirm()
        end
        return
    end
    
    -- Normal bind action - use the same pickup logic as CE_PickupItem
    CE_PickupItem()
    
    -- Show placement frame when binding items to action bars
    -- Check cursor state OR if fake cursor has a held item (for macros which may not trigger CursorHasSpell/CursorHasItem)
    local Cursor = ConsoleExperience.cursor
    local hasHeldItem = Cursor and Cursor.heldItemTexturePath
    if CursorHasSpell() or CursorHasItem() or hasHeldItem then
        if ConsoleExperience.placement then
            ConsoleExperience.placement:Show()
        end
    end
end

-- ============================================================================
-- Close Frame Action
-- ============================================================================

function CE_CloseFrame()
    local Cursor = ConsoleExperience.cursor
    
    -- Find the topmost active frame and close it
    local frameToClose = nil
    
    for frame, _ in pairs(Cursor.navigationState.activeFrames) do
        if frame:IsVisible() then
            frameToClose = frame
            break
        end
    end
    
    if frameToClose then
        local frameName = frameToClose:GetName() or "Unknown"
        CE_Debug("Closing frame: " .. frameName)
        
        -- Use HideUIPanel for standard UI frames, Hide for others
        if frameName == "WorldMapFrame" then
            ToggleWorldMap()
        elseif frameName == "CharacterFrame" then
            ToggleCharacter("PaperDollFrame")
        elseif frameName == "SpellBookFrame" then
            ToggleSpellBook(BOOKTYPE_SPELL)
        elseif frameName == "QuestLogFrame" then
            ToggleQuestLog()
        elseif frameName == "FriendsFrame" then
            ToggleFriendsFrame()
        elseif HideUIPanel then
            HideUIPanel(frameToClose)
        else
            frameToClose:Hide()
        end
    end
end

-- ============================================================================
-- Placement Frame Actions
-- ============================================================================

function CE_PLACEMENT_CLEAR()
    local Cursor = ConsoleExperience.cursor
    local button = Cursor.navigationState.currentButton
    
    if not button then 
        CE_Debug("CE_PLACEMENT_CLEAR: No current button")
        return 
    end
    
    local buttonName = button:GetName()
    if not buttonName or not string.find(buttonName, "CEPlacementButton%d+") then
        CE_Debug("CE_PLACEMENT_CLEAR: Not a placement button: " .. (buttonName or "nil"))
        return
    end
    
    -- Get the action slot from the button
    local actionSlot = button.actionSlot
    if not actionSlot then 
        CE_Debug("CE_PLACEMENT_CLEAR: No action slot")
        return 
    end
    
    -- Check if slot actually has an action
    if not HasAction(actionSlot) then
        CE_Debug("CE_PLACEMENT_CLEAR: Slot " .. actionSlot .. " is already empty")
        return
    end
    
    -- Clear the action slot
    -- Method: Pick up the action, then clear cursor
    -- First ensure cursor is empty (clear any existing cursor item)
    if CursorHasItem() or CursorHasSpell() then
        ClearCursor()
    end
    
    -- Pick up the action from the slot
    PickupAction(actionSlot)
    
    -- Now clear the cursor (this should remove the action from the slot)
    -- Note: ClearCursor() should work for actions in WoW 1.12
    ClearCursor()
    
    CE_Debug("Cleared action slot " .. actionSlot)
    
    -- Update the button display
    if ConsoleExperience.placement and ConsoleExperience.placement.UpdateButton then
        ConsoleExperience.placement:UpdateButton(button)
    end
    
    -- Update main action bar if on current page
    if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateAllButtons then
        ConsoleExperience.actionbars:UpdateAllButtons()
    end
    
    -- Refresh cursor frame to update tooltip
    Cursor:RefreshFrame()
end

-- ============================================================================
-- Radial Menu Show (Shift+Escape)
-- ============================================================================

function CE_ToggleRadialMenu()
    CE_Debug("Radial menu show triggered")
    if ConsoleExperience.radial then
        -- Only show the radial menu (don't toggle)
        -- ESC or close button will close it
        ConsoleExperience.radial:Show()
    else
        CE_Debug("Radial module not found!")
    end
end

-- ============================================================================
-- EditBox Info Dialog (shown when virtual keyboard is disabled)
-- ============================================================================

function CE_CreateEditBoxInfoDialog()
    if CE_EditBoxInfoDialog then return end
    
    -- Create dialog frame
    local dialog = CreateFrame("Frame", "CE_EditBoxInfoDialog", UIParent)
    dialog:SetWidth(350)
    dialog:SetHeight(100)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(200)
    dialog:EnableMouse(true)
    dialog:Hide()
    
    -- Background
    dialog:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    -- Title
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -20)
    title:SetText("Virtual Keyboard Disabled")
    title:SetTextColor(1, 0.82, 0, 1)
    
    -- Info text
    local infoText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOP", title, "BOTTOM", 0, -10)
    infoText:SetWidth(320)
    infoText:SetText("Press ESCAPE to exit the text field and resume controller navigation.")
    infoText:SetTextColor(1, 1, 1, 1)
    
    -- Auto-hide after a few seconds
    dialog:SetScript("OnShow", function()
        this.elapsed = 0
    end)
    
    dialog:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed > 4 then  -- Hide after 4 seconds
            this:Hide()
        end
    end)
    
    -- Also hide when Escape is pressed (EditBox will lose focus)
    dialog:SetScript("OnHide", function()
        this.elapsed = 0
    end)
    
    CE_EditBoxInfoDialog = dialog
end

-- Module loaded silently

