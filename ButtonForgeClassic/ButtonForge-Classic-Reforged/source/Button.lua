-- ButtonForge Classic - Vanilla action-slot backed buttons
-- v0.2.7: stable v0.2.5 + conservative stack/count refresh only. No cooldown frames.
local BF = BFClassic

function BF:IsActionSlotAllocated(slot, currentSave)
    self:EnsureDB()
    local i, j
    for i = 1, table.getn(ButtonForgeClassicDB.bars) do
        local barSave = ButtonForgeClassicDB.bars[i]
        if barSave and barSave.buttons then
            for j = 1, table.getn(barSave.buttons) do
                local buttonSave = barSave.buttons[j]
                if buttonSave and buttonSave ~= currentSave and buttonSave.actionSlot == slot then
                    return true
                end
            end
        end
    end
    return false
end


function BF:IsBindingIdAllocated(bindingId, currentSave)
    self:EnsureDB()
    local i, j
    for i = 1, table.getn(ButtonForgeClassicDB.bars) do
        local barSave = ButtonForgeClassicDB.bars[i]
        if barSave and barSave.buttons then
            for j = 1, table.getn(barSave.buttons) do
                local buttonSave = barSave.buttons[j]
                if buttonSave and buttonSave ~= currentSave and buttonSave.bindingId == bindingId then
                    return true
                end
            end
        end
    end
    return false
end

function BF:GetBindingIdForButton(parent, index)
    local save = self:GetButtonSave(parent, index)
    local max = self.MaxBindingButtons or ((self.ActionSlotEnd or 120) - (self.ActionSlotStart or 73) + 1)
    if save.bindingId and save.bindingId >= 1 and save.bindingId <= max then
        return save.bindingId
    end

    local id
    for id = 1, max do
        if not self:IsBindingIdAllocated(id, save) then
            save.bindingId = id
            return id
        end
    end

    self:Print("No free ButtonForge binding id left.")
    return nil
end

function BF:GetActionSlotForButton(parent, index)
    -- Vanilla offers only a limited set of safe backing ActionSlots here
    -- (currently 73-120). Instead of reserving 24 fixed slots per bar, we now
    -- allocate the next free slot globally. This allows more than two bars as
    -- long as the total number of visible ButtonForge buttons stays within the
    -- available slot pool.
    local save = self:GetButtonSave(parent, index)
    if save.actionSlot and save.actionSlot >= (self.ActionSlotStart or 73) and save.actionSlot <= (self.ActionSlotEnd or 120) then
        return save.actionSlot
    end

    local slot
    for slot = (self.ActionSlotStart or 73), (self.ActionSlotEnd or 120) do
        -- Never claim a slot that is already mapped by ButtonForge or already
        -- contains an unmanaged Blizzard action.
        local mapped = self:IsActionSlotAllocated(slot, save)
        local occupied = HasAction and HasAction(slot)
        if not mapped and not occupied then
            save.actionSlot = slot
            return slot
        end
    end

    self:Print("No free Vanilla ActionSlot left. Reduce total buttons or wait for the custom action backend.")
    return nil
end

-- Release stale slot reservations after the world/action bars are available.
-- Empty visual buttons do not need a backing Vanilla ActionSlot. This keeps
-- later bars usable until the actual 48-action limit is reached.
function BF:ReclaimUnusedActionSlots()
    self:EnsureDB()
    if not HasAction then return end

    local seen = {}
    local reclaimed = 0
    local i, j

    for i = 1, table.getn(ButtonForgeClassicDB.bars or {}) do
        local barSave = ButtonForgeClassicDB.bars[i]
        if barSave and barSave.buttons then
            for j = 1, table.getn(barSave.buttons) do
                local buttonSave = barSave.buttons[j]
                local slot = buttonSave and buttonSave.actionSlot
                if slot then
                    local invalid = slot < (self.ActionSlotStart or 73) or slot > (self.ActionSlotEnd or 120)
                    local duplicate = seen[slot] and true or false
                    local empty = not HasAction(slot)

                    if invalid or duplicate or empty then
                        buttonSave.actionSlot = nil
                        reclaimed = reclaimed + 1
                    else
                        seen[slot] = true
                    end
                end
            end
        end
    end

    -- Keep live button objects in sync with their saved mapping.
    if self.Bars then
        for i = 1, table.getn(self.Bars) do
            local bar = self.Bars[i]
            if bar and bar.buttons then
                for j = 1, table.getn(bar.buttons) do
                    local button = bar.buttons[j]
                    if button and button.save then
                        button.actionSlot = button.save.actionSlot
                        self:RefreshButton(button)
                    end
                end
            end
        end
    end

    if reclaimed > 0 then
        self:Print("Released " .. tostring(reclaimed) .. " unused ActionSlot reservation(s).")
    end
end

function BF:RealCursorHasAction()
    -- Check only the cursor state reported by the client. Do not include
    -- InternalCursorActive here: that flag is a fallback for unreliable 1.12
    -- cursor events and must be independently clearable when it becomes stale.
    if GetCursorInfo then
        local cursorType = GetCursorInfo()
        if cursorType == "spell" or cursorType == "item" or cursorType == "macro" then
            return true
        end
    end

    if CursorHasSpell and CursorHasSpell() then return true end
    if CursorHasItem and CursorHasItem() then return true end
    if CursorHasMacro and CursorHasMacro() then return true end
    if CursorHasMoney and CursorHasMoney() then return true end
    return false
end

function BF:ButtonHasCursor()
    if self.InternalCursorActive then return true end
    return self:RealCursorHasAction()
end

-- External drags (spellbook, bags, macro window, Blizzard bars) must reveal
-- every ButtonForge drop target, not only the currently selected bar. Some
-- Vanilla/Turtle clients do not fire CURSOR_UPDATE/ACTIONBAR_SHOWGRID reliably,
-- so this state is also synchronized by a very light cursor poll below.
function BF:SetExternalCursorGridActive(active)
    active = active and true or false
    if self.ExternalCursorGridActive == active then return end

    self.ExternalCursorGridActive = active

    -- Make every mouseover bar immediately usable as a drop target as well.
    if active and self.Bars then
        local i
        for i = 1, table.getn(self.Bars) do
            local bar = self.Bars[i]
            if bar then
                bar.mouseoverHideAt = nil
                bar.mouseoverCurrentAlpha = 1
                if bar.SetAlpha then bar:SetAlpha(1) end
                if self.SyncBarCooldownAlpha then
                    self:SyncBarCooldownAlpha(bar, 1)
                end
            end
        end
    end

    self:RefreshAllButtons()
end

function BF:SyncExternalCursorGrid()
    -- Internal ButtonForge drags already use the temporary-grid path. Do not
    -- let the native cursor used for those drags create a second state machine.
    if self.InternalDragSource then return end

    self:SetExternalCursorGridActive(self:RealCursorHasAction())
end

function BF:ClearCursorSafe()
    self.InternalCursorActive = false
    self.InternalDragSource = nil
    self.InternalDragStartedAt = nil
    self.NativeActionDrag = false
    self.NativeActionDragSlot = nil
    self.NativeDragFinalizeSource = nil
    self.NativeDragFinalizeAt = nil
    if ClearCursor then ClearCursor() end
end

function BF:ResetInternalDragState(clearCursor)
    self.InternalCursorActive = false
    self.InternalDragSource = nil
    self.InternalDragStartedAt = nil
    self.NativeActionDrag = false
    self.NativeActionDragSlot = nil
    self.NativeDragFinalizeSource = nil
    self.NativeDragFinalizeAt = nil
    self.TempGridUntil = nil
    if self.TempGridFrame then
        self.TempGridFrame:Hide()
    end
    if clearCursor and ClearCursor then
        ClearCursor()
    end
    self:RefreshAllButtons()
end

function BF:SuppressNextClick(button, seconds)
    if not button or not GetTime then return end
    button.bfcSuppressClickUntil = GetTime() + (seconds or 0.08)
end

function BF:IsClickSuppressed(button)
    if not button or not button.bfcSuppressClickUntil or not GetTime then return false end
    if GetTime() <= button.bfcSuppressClickUntil then
        return true
    end
    button.bfcSuppressClickUntil = nil
    return false
end

function BF:GetButtonSave(parent, index)
    if not parent.save.buttons then parent.save.buttons = {} end
    if not parent.save.buttons[index] then parent.save.buttons[index] = {} end
    return parent.save.buttons[index]
end

function BF:CreateEmptyButton(parent, index)
    local name = parent:GetName() .. "Button" .. tostring(index)
    local button = CreateFrame("Button", name, parent)
    button:SetWidth(self.ButtonSize)
    button:SetHeight(self.ButtonSize)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")
    button:RegisterForDrag("LeftButton")
    button:EnableMouse(true)

    button.parentBar = parent
    button.index = index
    button.save = self:GetButtonSave(parent, index)
    -- Empty visual slots do not reserve one of Vanilla's limited backing
    -- ActionSlots. A slot is allocated only when an action is actually dropped.
    button.actionSlot = button.save.actionSlot
    button.bindingId = button.save.bindingId or self:GetBindingIdForButton(parent, index)
    button.save.bindingId = button.bindingId

    -- v0.2.4: Do NOT use native-size quickslot artwork. In some 1.12 clients
    -- texture width/height can behave oddly after SetTexture(), so we anchor the
    -- icon to all four inner corners. This forces the artwork into the slot.
    button.icon = button:CreateTexture(name .. "Icon", "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Cooldown Model frames are allocated lazily from a small shared pool.
    -- Creating a Model/CooldownFrameTemplate for every empty ButtonForge slot
    -- can exhaust or destabilize the Vanilla/Turtle model-frame pool and stop
    -- cooldown spirals in other addons (for example AuraCore).
    button.cooldown = nil

    -- Avoid the Blizzard quickslot border texture for now; it was the likely
    -- source of oversized artwork on Turtle/1.12. Use a simple backdrop instead.
    button:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    button:SetBackdropColor(0, 0, 0, 0.75)

    button.count = button:CreateFontString(name .. "Count", "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)

    button.hotkey = button:CreateFontString(name .. "HotKey", "OVERLAY", "NumberFontNormalSmallGray")
    button.hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    button.hotkey:SetText("")

    -- Vanilla-style macro name text. GetActionText() returns the macro name for
    -- macro actions and nil for normal spells/items, so this adds no polling.
    button.macroName = button:CreateFontString(name .. "MacroName", "OVERLAY", "GameFontHighlightSmall")
    button.macroName:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 3, 3)
    button.macroName:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.macroName:SetHeight(10)
    button.macroName:SetJustifyH("CENTER")
    button.macroName:SetText("")

    button:SetScript("OnReceiveDrag", BF.Button_OnReceiveDrag)
    button:SetScript("OnDragStart", BF.Button_OnDragStart)
    button:SetScript("OnDragStop", BF.Button_OnDragStop)
    button:SetScript("OnClick", BF.Button_OnClick)
    button:SetScript("OnMouseDown", BF.Button_OnMouseDown)
    button:SetScript("OnMouseUp", BF.Button_OnMouseUp)
    button:EnableMouseWheel(true)
    button:SetScript("OnMouseWheel", BF.Button_OnMouseWheel)
    button:SetScript("OnEnter", BF.Button_OnEnter)
    button:SetScript("OnLeave", BF.Button_OnLeave)

    self:RefreshButton(button)
    self:UpdateButtonHotkey(button)
    return button
end

-- Vanilla/Turtle uses Model frames for CooldownFrameTemplate. These frames are
-- a scarce shared UI resource, so ButtonForge keeps a bounded reusable pool
-- instead of creating one for every visual slot. Long cooldowns take priority
-- over temporary GCD spirals if the pool is fully occupied.
BF.CooldownFramePool = BF.CooldownFramePool or {}
BF.CooldownActiveButtons = BF.CooldownActiveButtons or {}
BF.CooldownFrameCount = BF.CooldownFrameCount or 0
BF.MaxCooldownFrames = BF.MaxCooldownFrames or 24

function BF:ReleaseButtonCooldown(button)
    if not button or not button.cooldown then return end
    local frame = button.cooldown
    if CooldownFrame_SetTimer then
        CooldownFrame_SetTimer(frame, 0, 0, 0)
    end
    frame:Hide()
    frame:ClearAllPoints()
    frame.bfcButton = nil
    frame.bfcDuration = nil
    frame:SetParent(UIParent)
    button.cooldown = nil
    self.CooldownActiveButtons[button] = nil
    table.insert(self.CooldownFramePool, frame)
end

function BF:AcquireButtonCooldown(button, duration)
    if not button then return nil end
    if button.cooldown then
        button.cooldown.bfcDuration = duration or 0
        return button.cooldown
    end

    local frame = table.remove(self.CooldownFramePool)

    -- Preserve real cooldowns when all pooled frames are temporarily occupied
    -- by the global cooldown. A GCD-only frame can safely be reassigned.
    if not frame and duration and duration > 2 then
        local other
        for other in pairs(self.CooldownActiveButtons) do
            if other and other.cooldown and (other.cooldown.bfcDuration or 0) <= 2 then
                self:ReleaseButtonCooldown(other)
                frame = table.remove(self.CooldownFramePool)
                break
            end
        end
    end

    if not frame and self.CooldownFrameCount < self.MaxCooldownFrames then
        self.CooldownFrameCount = self.CooldownFrameCount + 1
        local cooldownName = "ButtonForgeClassicCooldownPool" .. tostring(self.CooldownFrameCount)
        frame = CreateFrame("Model", cooldownName, UIParent, "CooldownFrameTemplate")
        if frame and frame.EnableMouse then
            frame:EnableMouse(false)
        end
    end

    if not frame then return nil end

    frame:SetParent(button)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    frame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    frame:SetFrameLevel(button:GetFrameLevel())
    frame.bfcButton = button
    frame.bfcDuration = duration or 0
    button.cooldown = frame
    self.CooldownActiveButtons[button] = true

    local alpha = 1
    if button.parentBar and button.parentBar.GetAlpha then
        alpha = button.parentBar:GetAlpha() or 1
    end
    frame:SetAlpha(alpha)
    if alpha <= 0.01 then
        frame:Hide()
    else
        frame:Show()
    end
    return frame
end

function BF:UpdateButtonCooldown(button)
    if not button or not GetActionCooldown or not CooldownFrame_SetTimer then return end

    if not button.actionSlot or not HasAction or not HasAction(button.actionSlot) then
        self:ReleaseButtonCooldown(button)
        return
    end

    local start, duration, enable = GetActionCooldown(button.actionSlot)
    start = start or 0
    duration = duration or 0
    enable = enable or 0

    if start > 0 and duration > 0 and enable == 1 then
        local frame = self:AcquireButtonCooldown(button, duration)
        if frame then
            CooldownFrame_SetTimer(frame, start, duration, enable)
            local alpha = 1
            if button.parentBar and button.parentBar.GetAlpha then
                alpha = button.parentBar:GetAlpha() or 1
            end
            frame:SetAlpha(alpha)
            if alpha <= 0.01 then
                frame:Hide()
            else
                frame:Show()
            end
        end
    else
        self:ReleaseButtonCooldown(button)
    end
end


function BF:UpdateButtonRange(button)
    if not button or not button.icon then return end

    local slot = button.actionSlot
    if not slot or not HasAction or not HasAction(slot) then
        button.icon:SetVertexColor(1.0, 1.0, 1.0)
        return
    end

    -- Vanilla returns 1 when in range, 0 when out of range and nil when the
    -- action has no range component or cannot currently be evaluated.
    local inRange = nil
    if IsActionInRange then
        inRange = IsActionInRange(slot)
    end

    -- Auto Attack / basic melee actions often return nil from IsActionInRange
    -- on 1.12/Turtle.  Use a conservative melee-distance fallback only for
    -- attack actions.  CheckInteractDistance(..., 3) is the closest reliable
    -- built-in distance check available on this client; it is approximate but
    -- correctly distinguishes clearly out-of-melee targets.
    if inRange == nil and IsAttackAction and IsAttackAction(slot) then
        if UnitExists and UnitExists("target") and not (UnitIsDead and UnitIsDead("target")) then
            if CheckInteractDistance then
                if CheckInteractDistance("target", 3) then
                    inRange = 1
                else
                    inRange = 0
                end
            end
        else
            -- No valid target: do not paint Auto Attack red permanently.
            inRange = 1
        end
    end

    -- Match the Blizzard action-bar coloring order: out-of-range stays red;
    -- otherwise actions that are unusable specifically because of mana/rage/
    -- energy are tinted blue.  Other usable actions remain full color.
    local usable, noMana = nil, nil
    if IsUsableAction then
        usable, noMana = IsUsableAction(slot)
    end

    -- Missing consumables are grayed out. The cached flag is important on
    -- Vanilla/Turtle because IsConsumableAction() may stop reporting reliably
    -- after the last item has been consumed.
    local missingConsumable = false
    if GetActionCount and button.bfcWasConsumable then
        local count = GetActionCount(slot) or 0
        if count <= 0 then
            missingConsumable = true
        end
    end

    if missingConsumable then
        button.icon:SetVertexColor(0.35, 0.35, 0.35)
    elseif inRange == 0 then
        button.icon:SetVertexColor(1.0, 0.15, 0.15)
    elseif (usable == nil or usable == 0) and noMana == 1 then
        button.icon:SetVertexColor(0.35, 0.35, 1.0)
    else
        button.icon:SetVertexColor(1.0, 1.0, 1.0)
    end
end

function BF:RefreshButton(button)
    if not button then return end

    -- A button can still exist after the bar was resized smaller. Keep it hidden
    -- even if its backing Vanilla ActionSlot still contains an action. Without
    -- this guard, old buttons can reappear after ACTIONBAR_SLOT_CHANGED or moving
    -- the bar, creating phantom rows/gaps below the real layout.
    if button.activeInLayout == false then
        button:Hide()
        return
    end

    local slot = button.actionSlot
    local hasAction = slot and HasAction and HasAction(slot)

    if button.SetBackdropBorderColor then
        if self:IsKeybindMode() then
            button:SetBackdropBorderColor(0.0, 1.0, 0.25, 1.0)
        else
            button:SetBackdropBorderColor(0.45, 0.45, 0.55, 1.0)
        end
    end
    local keybindMode = self:IsKeybindMode()
    local showGrid = button.parentBar and button.parentBar.save and button.parentBar.save.showGrid
    local tempGrid = self:IsTemporaryGridActive()
    local menuEditPreview = self.MenuEditPreviewActive and true or false

    -- The open configuration menu IS the edit mode. While it is open, every
    -- active slot on every created bar must be visible, regardless of the saved
    -- per-bar Empty Slots setting. The saved setting is not modified.
    -- Keybind Mode and drag/drop temporary grid also force slots visible.
    if (not hasAction) and (not showGrid) and (not tempGrid) and (not keybindMode) and (not menuEditPreview) then
        button:Hide()
    else
        button:Show()
    end

    button.count:SetText("")
    if button.macroName then
        button.macroName:SetText("")
    end

    -- Keep visuals constrained even after reloads or client-side texture refreshes.
    if button.icon then
        button.icon:ClearAllPoints()
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
        button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    if hasAction then
        local texture = GetActionTexture(slot)
        button.icon:SetTexture(texture or self.QuestionIcon)

        -- Show counts for real stacks and single consumables (for example
        -- Healthstones), but not for non-consumable single items such as the
        -- Hearthstone. Remember the consumable state so the icon can still be
        -- grayed out after the final item has been used.
        if GetActionCount then
            local count = GetActionCount(slot) or 0
            local isConsumable = IsConsumableAction and IsConsumableAction(slot)

            if isConsumable then
                button.bfcWasConsumable = true
            elseif count > 1 then
                button.bfcWasConsumable = true
            elseif button.bfcLastTexture ~= texture then
                button.bfcWasConsumable = nil
            end

            button.bfcLastTexture = texture

            if count >= 1 and (count > 1 or isConsumable or button.bfcWasConsumable) then
                button.count:SetText(tostring(count))
            end
        end

        -- GetActionText() is the native Vanilla API for the text attached to an
        -- action slot. For macro actions this is the macro name; normal spells
        -- and items return nil, so only macros receive a label.
        if button.macroName and GetActionText and ButtonForgeClassicDB and
           ButtonForgeClassicDB.settings and ButtonForgeClassicDB.settings.showMacroNames ~= false then
            local actionText = GetActionText(slot)
            if actionText and actionText ~= "" then
                button.macroName:SetText(actionText)
            end
        end
    else
        button.icon:SetTexture(nil)
    end

    self:UpdateButtonCooldown(button)
    self:UpdateButtonHotkey(button)
    self:UpdateButtonRange(button)
end

function BF:ToggleMacroNames()
    self:EnsureDB()
    ButtonForgeClassicDB.settings.showMacroNames = not ButtonForgeClassicDB.settings.showMacroNames
    self:RefreshAllButtons()
end

function BF:IsTemporaryGridActive()
    -- External cursor drags are global: while a spell/item/macro is being held,
    -- empty slots on ALL ButtonForge bars stay visible until the cursor is clear.
    if self.ExternalCursorGridActive then return true end
    if self.InternalCursorActive then return true end
    if self.TempGridUntil and GetTime and GetTime() < self.TempGridUntil then
        return true
    end
    return false
end

function BF:StartTemporaryGrid(seconds)
    if not GetTime then return end
    self.TempGridUntil = GetTime() + (seconds or 6)
    if self.TempGridFrame then
        self.TempGridFrame:Show()
    end
    self:RefreshAllButtons()
end

function BF:StopTemporaryGrid()
    self.TempGridUntil = nil
    if self.TempGridFrame then
        self.TempGridFrame:Hide()
    end
    self:RefreshAllButtons()
end


function BF:CompleteInternalDragDrop(targetButton)
    local sourceButton = self.InternalDragSource
    if not sourceButton or not targetButton then return false end
    if not sourceButton.actionSlot then return false end

    -- v1.0.10 test: Action drags now use the real Vanilla cursor so an action
    -- can be dropped onto Blizzard's standard action bars. For a ButtonForge
    -- -> ButtonForge drop we first put the picked-up action back into its
    -- original backing slot, then keep using our deterministic reference swap.
    -- This gives native cross-UI drag/drop without reintroducing the old
    -- PickupAction/PlaceAction race for internal ButtonForge swaps.
    if self.NativeActionDrag then
        local nativeSlot = self.NativeActionDragSlot or sourceButton.actionSlot
        if nativeSlot and HasAction and (not HasAction(nativeSlot)) and PlaceAction then
            PlaceAction(nativeSlot)
        end

        -- If the client did not restore the picked-up action, do not remap an
        -- empty backing slot. Keep the native cursor intact and let the player
        -- place it normally instead of risking a lost/duplicated mapping.
        if nativeSlot and HasAction and (not HasAction(nativeSlot)) then
            self.InternalCursorActive = false
            self.InternalDragSource = nil
            self.InternalDragStartedAt = nil
            self.NativeActionDrag = false
            self.NativeActionDragSlot = nil
            self.NativeDragFinalizeSource = nil
            self.NativeDragFinalizeAt = nil
            self:RefreshAllButtons()
            return false
        end
    end

    -- v0.4.15: Internal ButtonForge drags no longer use PickupAction/PlaceAction
    -- for the actual ButtonForge-to-ButtonForge move/swap.
    -- Turtle/Vanilla can race these calls with mouse-up/click events, which made
    -- repeated swaps about 90% reliable but not 100%.  Instead we swap the
    -- backing ActionSlot references used by the two ButtonForge buttons.
    --
    -- This is deterministic:
    --   A -> empty B: B now points at A's old ActionSlot, A points at B's empty slot.
    --   A -> occupied B: the two buttons exchange their ActionSlot references.
    -- The real Blizzard ActionSlots are untouched; only ButtonForge's mapping
    -- changes. That makes repeated internal moves/swaps stable.

    if sourceButton == targetButton then
        self:ResetInternalDragState(true)
        return true
    end

    local sourceSlot = sourceButton.actionSlot
    local targetSlot = targetButton.actionSlot

    if targetSlot then
        -- Occupied target: swap the two backing-slot references.
        sourceButton.actionSlot = targetSlot
        targetButton.actionSlot = sourceSlot
        if sourceButton.save then sourceButton.save.actionSlot = targetSlot end
        if targetButton.save then targetButton.save.actionSlot = sourceSlot end
    else
        -- Empty target: move the existing backing slot instead of allocating
        -- another one. The source becomes a truly unallocated empty button.
        targetButton.actionSlot = sourceSlot
        sourceButton.actionSlot = nil
        if targetButton.save then targetButton.save.actionSlot = sourceSlot end
        if sourceButton.save then sourceButton.save.actionSlot = nil end
    end

    -- Keep keybinds on the physical button position instead of letting them
    -- travel with the swapped spell/item/macro.

    self.InternalCursorActive = false
    self.InternalDragSource = nil
    self.InternalDragStartedAt = nil
    self.NativeActionDrag = false
    self.NativeActionDragSlot = nil
    self.NativeDragFinalizeSource = nil
    self.NativeDragFinalizeAt = nil
    self.LastInternalDropAt = GetTime and GetTime() or 0

    self:SuppressNextClick(sourceButton, 0.08)
    self:SuppressNextClick(targetButton, 0.08)

    if PlaySound then PlaySound("igMainMenuOptionCheckBoxOn") end
    self:ResetInternalDragState(true)
    return true
end

function BF:PlaceCursorOnButton(button)
    if not button then return false end

    -- Action Lock follows Blizzard-style quick-move behaviour: normal drops are
    -- blocked while locked, but holding Shift allows an intentional change.
    if button.parentBar and button.parentBar.save and button.parentBar.save.actionsLocked then
        if not (IsShiftKeyDown and IsShiftKeyDown()) then
            return false
        end
    end

    if not button.actionSlot then
        button.actionSlot = self:GetActionSlotForButton(button.parentBar, button.index)
        if button.save then button.save.actionSlot = button.actionSlot end
    end

    if not button.actionSlot then
        self:Print("No free Vanilla ActionSlot left. ButtonForge supports up to 48 occupied actions.")
        return false
    end

    if button.actionSlot > (self.ActionSlotEnd or 120) then
        self:Print(self:T("NO_FREE_SLOT"))
        return false
    end

    if PlaceAction then
        -- Remember whether the target had an action before placing. If it did,
        -- Vanilla swaps that action onto the cursor. Turtle/1.12 does not always
        -- report that swapped cursor through CursorHasSpell/Item/Macro, so we
        -- track it ourselves. This is the core fix for repeated slot-to-slot
        -- swapping and moving a swapped action into an empty slot.
        local targetHadAction = false
        if HasAction and HasAction(button.actionSlot) then
            targetHadAction = true
        end

        PlaceAction(button.actionSlot)

        if targetHadAction then
            self.InternalCursorActive = true
            self.InternalDragSource = nil
            self:StartTemporaryGrid(6)
        else
            self.InternalCursorActive = false
            self.InternalDragSource = nil
        end

        self:RefreshAllButtons()
        return true
    end

    self:Print(self:T("PLACEACTION_MISSING"))
    return false
end

function BF:ClearButton(button)
    if not button or not button.actionSlot then return end
    if HasAction and HasAction(button.actionSlot) and PickupAction then
        PickupAction(button.actionSlot)
        self:ClearCursorSafe()
    end

    -- The backing slot is empty now, so release the reservation immediately.
    button.actionSlot = nil
    if button.save then button.save.actionSlot = nil end

    self:RefreshButton(button)
    self:Print(self:T("SLOT_CLEARED"))
end

function BF:UseButton(button)
    if not button or not button.actionSlot then return end
    if HasAction and HasAction(button.actionSlot) and UseAction then
        UseAction(button.actionSlot, 0, 0)
    end
    self:RefreshButton(button)
end

function BF.Button_OnReceiveDrag()
    -- Internal ButtonForge button drag: complete a true move/swap and clear the cursor.
    if BF.InternalDragSource then
        if BF:CompleteInternalDragDrop(this) then
            BF:SuppressNextClick(this, 0.08)
        end
        return
    end

    -- External spell/item/macro drag from spellbook, bags or macro frame.
    if BF:PlaceCursorOnButton(this) then
        BF:SuppressNextClick(this, 0.08)
    end
end

function BF.Button_OnDragStart()
    local bar = this.parentBar

    -- Configure Mode: dragging anywhere on a bar, including directly on an
    -- action slot, moves the whole bar. In normal play mode the same drag keeps
    -- its original ButtonForge action move/swap behaviour.
    if BF:IsConfigMode() and bar and bar.save then
        BF:SetActiveBar(bar)
        if bar.save.locked then
            return
        end

        -- MouseDown normally already started moving the parent bar. Keep this
        -- as a fallback for clients that skip the MouseDown path during a drag.
        if not this.bfcMovingParentBar then
            this.bfcMovingParentBar = true
            BF:SuppressNextClick(this, 0.25)
            bar:StartMoving()
        end
        return
    end

    -- Native-style action drag. A real PickupAction() is required so Blizzard's
    -- standard action buttons can accept a drop from ButtonForge. If the bar is
    -- locked, Shift acts as the familiar quick-move override.
    if bar and bar.save and bar.save.actionsLocked then
        if not (IsShiftKeyDown and IsShiftKeyDown()) then
            return
        end
    end

    if this.actionSlot and HasAction and HasAction(this.actionSlot) then
        local sourceSlot = this.actionSlot

        BF.InternalDragSource = this
        BF.InternalDragStartedAt = GetTime and GetTime() or 0
        BF.NativeActionDrag = false
        BF.NativeActionDragSlot = sourceSlot
        BF:SuppressNextClick(this, 0.08)

        if PickupAction then
            PickupAction(sourceSlot)

            -- GetCursorInfo()/CursorHas* is not perfectly reliable on every
            -- Vanilla/Turtle client. The backing slot becoming empty is also a
            -- valid signal that PickupAction succeeded.
            if BF:RealCursorHasAction() or (HasAction and not HasAction(sourceSlot)) then
                BF.NativeActionDrag = true
            end
        end

        -- Fallback: if native pickup is unavailable, retain the old internal
        -- ButtonForge-only drag instead of breaking action movement entirely.
        BF.InternalCursorActive = true
        BF:RefreshAllButtons()
        BF:StartTemporaryGrid(10)
    end
end

function BF:FinishNativeActionDrag(sourceButton)
    if not self.NativeActionDrag or not sourceButton then return end
    if self.InternalDragSource ~= sourceButton then return end

    local sourceSlot = self.NativeActionDragSlot or sourceButton.actionSlot

    -- A drop onto a Blizzard action button is handled by Blizzard itself via
    -- PlaceAction(). The original backing slot is then empty, so release the
    -- ButtonForge mapping. If the destination was occupied, its displaced
    -- action may still be on the real cursor; deliberately leave that cursor
    -- untouched so it can be placed somewhere else exactly like the stock UI.
    if sourceSlot and HasAction and (not HasAction(sourceSlot)) then
        sourceButton.actionSlot = nil
        if sourceButton.save then sourceButton.save.actionSlot = nil end
    end

    self.InternalCursorActive = false
    self.InternalDragSource = nil
    self.InternalDragStartedAt = nil
    self.NativeActionDrag = false
    self.NativeActionDragSlot = nil
    self.NativeDragFinalizeSource = nil
    self.NativeDragFinalizeAt = nil

    self:RefreshAllButtons()

    if self:RealCursorHasAction() then
        self:StartTemporaryGrid(10)
    else
        self:StopTemporaryGrid()
    end
end

function BF.Button_OnDragStop()
    if this.bfcMovingParentBar then
        local bar = this.parentBar
        this.bfcMovingParentBar = nil
        BF:SuppressNextClick(this, 0.15)
        BF:StopMovingBar(bar, true)
        return
    end

    -- If no ButtonForge target consumed the drag, it may have been dropped onto
    -- Blizzard/another native action target. Do not finalize immediately: some
    -- Vanilla clients deliver the target's OnReceiveDrag after the source's
    -- OnDragStop. A short deferred settle window lets ButtonForge targets still
    -- use the deterministic internal swap path.
    if BF.NativeActionDrag and BF.InternalDragSource == this then
        BF.NativeDragFinalizeSource = this
        BF.NativeDragFinalizeAt = (GetTime and GetTime() or 0) + 0.10
        if BF.TempGridFrame then BF.TempGridFrame:Show() end
    end
end

function BF.Button_OnMouseDown()
    -- Menu open = Edit Mode. Make the entire bar surface draggable, including
    -- occupied and empty action slots. Starting the parent move on mouse-down
    -- avoids relying on Vanilla's custom-button OnDragStart behaviour, which
    -- can be inconsistent when the cursor begins over an action button.
    if BF:IsConfigMode() and arg1 == "LeftButton" then
        local bar = this.parentBar
        if bar and bar.save then
            BF:SetActiveBar(bar)
            if not bar.save.locked then
                this.bfcMovingParentBar = true
                BF:SuppressNextClick(this, 0.25)
                bar:StartMoving()
            end
        end
        return
    end

    if BF:IsKeybindMode() then
        -- Never capture primary mouse buttons in Keybind Mode. Left and right
        -- mouse are reserved for camera, targeting, looting and normal UI use.
        -- We ignore them completely so they cannot disturb WoW controls.
        if arg1 == "LeftButton" or arg1 == "RightButton" or
           arg1 == "BUTTON1" or arg1 == "BUTTON2" or
           arg1 == "Button1" or arg1 == "Button2" or
           arg1 == "MouseButton1" or arg1 == "MouseButton2" then
            return
        end

        BF.KeybindTarget = this

        -- If the player is holding an action on the cursor, treat the click as
        -- a drop operation instead of a keybind.
        if BF:ButtonHasCursor() then
            BF:PlaceCursorOnButton(this)
            return
        end

        if arg1 then
            BF:AssignKeyToButton(this, arg1)
        end
        return
    end
end

function BF.Button_OnMouseWheel()
    if BF:IsKeybindMode() then
        BF.KeybindTarget = this
        if arg1 and arg1 > 0 then
            BF:AssignKeyToButton(this, "MOUSEWHEELUP")
        else
            BF:AssignKeyToButton(this, "MOUSEWHEELDOWN")
        end
        return
    end
end

function BF.Button_OnMouseUp()
    if this.bfcMovingParentBar then
        local bar = this.parentBar
        this.bfcMovingParentBar = nil
        BF:SuppressNextClick(this, 0.15)
        BF:StopMovingBar(bar, true)
        return
    end
end

function BF.Button_OnClick()
    if BF:IsClickSuppressed(this) then
        return
    end

    -- Extra guard after an internal drag/drop. Some clients fire a normal click
    -- on the drop target a fraction of a second after OnReceiveDrag/OnClick has
    -- already completed the deterministic swap. Without this, repeated swaps can
    -- occasionally be undone or converted into a normal UseAction().
    if BF.LastInternalDropAt and GetTime and (GetTime() - BF.LastInternalDropAt) < 0.12 then
        return
    end

    if BF:IsKeybindMode() then
        BF.KeybindTarget = this

        -- Cursor action wins over keybind assignment. This fixes spell/item/macro
        -- drops while the green Keybind Mode highlight is active.
        if BF:ButtonHasCursor() then
            BF:PlaceCursorOnButton(this)
            return
        end

        if arg1 == "LeftButton" or arg1 == "RightButton" or
           arg1 == "BUTTON1" or arg1 == "BUTTON2" or
           arg1 == "Button1" or arg1 == "Button2" or
           arg1 == "MouseButton1" or arg1 == "MouseButton2" then
            -- Ignore primary mouse buttons completely in Keybind Mode.
            return
        elseif arg1 == "MiddleButton" or arg1 == "Button4" or arg1 == "Button5" then
            BF:AssignKeyToButton(this, arg1)
        else
            BF:Print(BF:T("KEYBIND_PRESS_KEY"))
        end
        return
    end

    -- After an internal drag starts, some 1.12 clients may fire a stray click
    -- even if the drop handler did not complete yet. While the temporary grid is
    -- active, never treat such a click as UseAction(); only drop/swap handlers
    -- below may consume it. This reduces rare failed swaps caused by mouse-up
    -- race conditions.
    if BF.InternalDragStartedAt and GetTime and (GetTime() - BF.InternalDragStartedAt) < 1.25 then
        if not BF.InternalDragSource and not BF:ButtonHasCursor() then
            return
        end
    end

    if IsShiftKeyDown and IsShiftKeyDown() and arg1 == "RightButton" then
        BF:ClearButton(this)
        return
    end

    -- Mouse-up after an internal drag. Finish a deterministic move/swap here as
    -- well, because some 1.12 clients do not fire OnReceiveDrag reliably between
    -- custom frames.
    if BF.InternalDragSource then
        BF:CompleteInternalDragDrop(this)
        BF:SuppressNextClick(this, 0.08)
        return
    end

    -- Empty slot: try PlaceAction even if Vanilla does not report the cursor.
    if (not this.actionSlot) or (not HasAction) or (not HasAction(this.actionSlot)) then
        BF:PlaceCursorOnButton(this)
        return
    end

    -- Only place when an action is actually on the cursor (including our
    -- internally tracked swapped cursor). Temporary grid alone must not turn a
    -- normal click into Pickup/PlaceAction; that caused unreliable one-time swaps.
    if BF:ButtonHasCursor() then
        BF:PlaceCursorOnButton(this)
    else
        BF:UseButton(this)
    end
end

function BF.Button_OnEnter()
    if BF:IsKeybindMode() then
        BF.KeybindTarget = this
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(BF:T("KEYBIND_MODE"))
        GameTooltip:AddLine(BF:T("KEYBIND_PRESS_KEY"), 1, 1, 1)
        GameTooltip:AddLine(BF:T("KEYBIND_MOUSE_HINT"), 0.8, 1, 0.8)
        GameTooltip:AddLine(BF:T("KEYBIND_CLEAR_HINT"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(BF:T("KEYBIND_EXIT_HINT"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
        return
    end

    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")

    if this.actionSlot and HasAction and HasAction(this.actionSlot) then
        -- Safe Vanilla tooltip path. SetAction exists on 1.12 clients and shows
        -- spells, items and macros from the backing action slot.
        local shown = false
        if GameTooltip.SetAction then
            GameTooltip:SetAction(this.actionSlot)
            shown = true
        end

        if not shown then
            GameTooltip:SetText("ButtonForge Classic")
            GameTooltip:AddLine("ActionSlot " .. tostring(this.actionSlot), 1, 1, 1)
        end
    else
        GameTooltip:SetText("Empty ButtonForge Classic Slot")
        GameTooltip:AddLine("Drag a spell, item or macro here.", 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Shift + Right Click: Clear Slot", 0.8, 0.8, 0.8)
    if this.parentBar and this.parentBar.save and this.parentBar.save.actionsLocked then
        GameTooltip:AddLine("Shift + Drag: Move action", 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine("Drag: Move action", 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

function BF.Button_OnLeave()
    if BF.KeybindTarget == this then
        BF.KeybindTarget = nil
    end
    GameTooltip:Hide()
end


-- v0.2.7: conservative global refresh for count text.
-- This only calls RefreshButton on existing buttons and does not create, hide,
-- replace or reassign action slots.
function BF:RefreshAllButtons()
    if not self.Bars then return end
    local i, j
    for i = 1, table.getn(self.Bars) do
        local bar = self.Bars[i]
        if bar and bar.buttons then
            for j = 1, table.getn(bar.buttons) do
                if bar.buttons[j] then
                    self:RefreshButton(bar.buttons[j])
                end
            end
        end
    end
end

BF.CountFrame = CreateFrame("Frame")
BF.CountFrame.Elapsed = 0
BF.CountFrame:RegisterEvent("BAG_UPDATE")
BF.CountFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
BF.CountFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
BF.CountFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
BF.CountFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
BF.CountFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
BF.CountFrame:SetScript("OnEvent", function()
    BF:RefreshAllButtons()
    BF:RefreshAllHotkeys()
end)


-- Show empty drop targets whenever the cursor carries a spell, item or macro.
-- CURSOR_UPDATE is event-driven and works outside Configure Mode without a
-- permanent OnUpdate loop. This is especially important for macros on
-- Turtle/Vanilla, where CursorHasMacro() is unreliable but GetCursorInfo()
-- reports the cursor type correctly.
BF.CursorWatchFrame = CreateFrame("Frame")
BF.CursorWatchFrame:RegisterEvent("CURSOR_UPDATE")
BF.CursorWatchFrame:RegisterEvent("ACTIONBAR_SHOWGRID")
BF.CursorWatchFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
BF.CursorWatchFrame:SetScript("OnEvent", function()
    if BF:IsConfigMode() or BF:IsKeybindMode() then
        return
    end

    -- Vanilla/Turtle fires ACTIONBAR_SHOWGRID reliably when dragging a spell,
    -- item or macro, even when CURSOR_UPDATE/GetCursorInfo is inconsistent.
    if event == "ACTIONBAR_SHOWGRID" then
        BF:StartTemporaryGrid(10)
        return
    elseif event == "ACTIONBAR_HIDEGRID" then
        -- Do not cancel an active internal ButtonForge drag. For external drags,
        -- however, ACTIONBAR_HIDEGRID is the authoritative end signal. Clear a
        -- stale fallback cursor flag when the client reports no real cursor item.
        if not BF.InternalDragSource and not BF:RealCursorHasAction() then
            BF.InternalCursorActive = false
            BF.InternalDragStartedAt = nil
            BF:StopTemporaryGrid()
        end
        return
    end

    if BF:RealCursorHasAction() or BF.InternalDragSource then
        BF:StartTemporaryGrid(10)
    elseif not BF.InternalDragSource then
        -- CURSOR_UPDATE with an empty real cursor also clears a stale fallback
        -- state left behind by PlaceAction swap timing on Turtle/Vanilla.
        BF.InternalCursorActive = false
        BF.InternalDragStartedAt = nil
        BF:StopTemporaryGrid()
    end
end)

function BF:RefreshAllButtonRanges()
    if not self.Bars then return end
    local i, j
    for i = 1, table.getn(self.Bars) do
        local bar = self.Bars[i]
        if bar and bar.buttons then
            for j = 1, table.getn(bar.buttons) do
                local button = bar.buttons[j]
                if button and button:IsShown() then
                    self:UpdateButtonRange(button)
                end
            end
        end
    end
end

-- Range updates need a light periodic check because distance can change without
-- a dedicated event.  Twenty checks per second makes the range and usability tint react quickly while remaining
-- inexpensive with the full 48-button Vanilla slot pool.
BF.RangeFrame = CreateFrame("Frame")
BF.RangeFrame.Elapsed = 0
BF.RangeFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
BF.RangeFrame:RegisterEvent("UNIT_FACTION")
BF.RangeFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
BF.RangeFrame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
BF.RangeFrame:RegisterEvent("SPELL_UPDATE_USABLE")
BF.RangeFrame:SetScript("OnEvent", function()
    BF:RefreshAllButtonRanges()
end)
BF.RangeFrame:SetScript("OnUpdate", function()
    local elapsed = arg1 or 0
    this.Elapsed = (this.Elapsed or 0) + elapsed
    this.CursorElapsed = (this.CursorElapsed or 0) + elapsed

    -- Poll only the tiny cursor state at 10 Hz. We refresh the buttons only when
    -- the cursor changes between empty and carrying an action, so this does not
    -- add a continuous all-button refresh. This is the fallback for clients that
    -- miss CURSOR_UPDATE/ACTIONBAR_SHOWGRID while dragging from external frames.
    if this.CursorElapsed >= 0.10 then
        this.CursorElapsed = 0
        BF:SyncExternalCursorGrid()
    end

    if this.Elapsed < 0.05 then return end
    this.Elapsed = 0
    BF:RefreshAllButtonRanges()
end)

-- Temporary grid while dragging/swapping actions. This frame is hidden most of
-- the time and only wakes briefly after a drag starts, so it should not cost FPS.
BF.TempGridFrame = CreateFrame("Frame")
BF.TempGridFrame.Elapsed = 0
BF.TempGridFrame:Hide()
BF.TempGridFrame:SetScript("OnUpdate", function()
    this.Elapsed = (this.Elapsed or 0) + arg1
    if this.Elapsed < 0.05 then return end
    this.Elapsed = 0

    -- Deferred native-drag finalization. This runs only while the temporary
    -- drag grid is active, so there is no permanent per-frame cost.
    if BF.NativeDragFinalizeSource and BF.NativeDragFinalizeAt and GetTime and
       GetTime() >= BF.NativeDragFinalizeAt then
        local source = BF.NativeDragFinalizeSource
        if BF.NativeActionDrag and BF.InternalDragSource == source then
            BF:FinishNativeActionDrag(source)
        else
            BF.NativeDragFinalizeSource = nil
            BF.NativeDragFinalizeAt = nil
        end
    end

    -- Never infer the end of an internal drag from IsMouseButtonDown(). That
    -- state is unreliable during custom drags on Vanilla/Turtle and can cancel
    -- a valid swap before the target receives the drop.
    if (not BF.TempGridUntil) or (GetTime and GetTime() >= BF.TempGridUntil) then
        -- Timeout is only a fallback. Never touch a genuine internal drag, but
        -- release stale external-cursor tracking once the real cursor is empty.
        if not BF.InternalDragSource and not BF:RealCursorHasAction() then
            BF.InternalCursorActive = false
            BF.InternalDragStartedAt = nil
        end
        BF:StopTemporaryGrid()
    end
end)

-- Performance hotfix: no global OnUpdate refresh.
-- Turtle/Vanilla clients can stutter when we refresh all buttons repeatedly.
-- Counts now refresh only on events and after direct button changes.
