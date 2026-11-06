-- ButtonForge Classic - bars for Vanilla 1.12
local BF = BFClassic

-- Finish a bar move and persist its current anchor. This helper is also used
-- when a drag starts on one of the action buttons while Configure Mode is active.
function BF:StopMovingBar(bar, printSaved)
    if not bar or not bar.save then return end
    bar:StopMovingOrSizing()
    local point, relativeTo, relativePoint, xOfs, yOfs = bar:GetPoint()
    if point then bar.save.point = point end
    if relativePoint then bar.save.relativePoint = relativePoint end
    if xOfs then bar.save.x = self:Round(xOfs) end
    if yOfs then bar.save.y = self:Round(yOfs) end
    if printSaved then
        self:Print(bar.save.name .. " saved.")
    end
end

function BF:CreateBar(save)
    self:EnsureDB()

    if not save then
        save = self:GetDefaultBarSave()
        if not save then return nil end

        -- New bars should be immediately understandable and visible.
        -- Keep empty slots enabled by default for every freshly created bar.
        save.showGrid = true

        table.insert(ButtonForgeClassicDB.bars, save)
    end

    -- v1.0.10: split bar-position locking from action locking. Existing saved
    -- bars inherit their old Lock state for actions once, preserving behaviour.
    if save.actionsLocked == nil then
        save.actionsLocked = save.locked and true or false
    end

    local frameName = "BFCBar" .. tostring(save.id)
    local bar = CreateFrame("Frame", frameName, UIParent)
    bar:SetWidth((save.cols * self.ButtonSize) + ((save.cols - 1) * self.ButtonGap) + 12)
    bar:SetHeight((save.rows * self.ButtonSize) + ((save.rows - 1) * self.ButtonGap) + 12)
    bar:SetScale(save.scale or 1)
    bar:SetFrameStrata("LOW")
    bar:ClearAllPoints()
    bar:SetPoint(save.point or "CENTER", UIParent, save.relativePoint or "CENTER", save.x or 0, save.y or 0)

    bar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    BF:ApplyBarBackground(bar, save)

    bar:EnableMouse(true)
    bar:SetMovable(true)
    bar:RegisterForDrag("LeftButton")
    bar.save = save
    bar.buttons = {}

    bar:SetScript("OnDragStart", function()
        BF:SetActiveBar(this)
        if this.save and this.save.locked then
            return
        end
        this:StartMoving()
    end)

    bar:SetScript("OnDragStop", function()
        BF:StopMovingBar(this, true)
    end)

    bar:SetScript("OnMouseDown", function()
        BF:SetActiveBar(this)
        -- Right-click menu is disabled for now because it caused stuck menu frames on some 1.12 clients.
        -- Editing is handled through the minimap menu and slash commands.
    end)

    bar:SetScript("OnEnter", function()
        BF:SetActiveBar(this)
        BF:SetBarHover(this, true)
        this.mouseoverHovered = true
        this.mouseoverHideAt = nil
        -- In play mode, do not show empty slots just because the mouse hovers
        -- over a bar. Empty slots should only appear while the player is
        -- actively dragging/swapping something.
        if (not BF:IsConfigMode()) and (not BF:IsKeybindMode()) and BF:ButtonHasCursor() then
            BF:StartTemporaryGrid(4)
        end
        if BF:IsConfigMode() then
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:SetText(this.save.name)
            if this.save.locked then
                GameTooltip:AddLine("Locked. Use the minimap menu to unlock.", 1, 0.8, 0.2)
            else
                GameTooltip:AddLine("Left-drag: Move bar", 1, 1, 1)
            end
            GameTooltip:AddLine("/bf config: Toggle edit mode", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("/bf bg: Toggle background", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end
    end)

    bar:SetScript("OnLeave", function()
        BF:SetBarHover(this, false)
        this.mouseoverHovered = false
        GameTooltip:Hide()
    end)

    self:CreateButtonsForBar(bar)
    self:CreateControlsForBar(bar)
    table.insert(self.Bars, bar)
    self:SetActiveBar(bar)
    return bar
end

function BF:CreateButtonsForBar(bar)
    local save = bar.save
    local index = 1

    for row = 1, save.rows do
        for col = 1, save.cols do
            local button = self:CreateEmptyButton(bar, index)
            button.activeInLayout = true
            button:SetPoint("TOPLEFT", bar, "TOPLEFT", 6 + ((col - 1) * (self.ButtonSize + self.ButtonGap)), -6 - ((row - 1) * (self.ButtonSize + self.ButtonGap)))
            bar.buttons[index] = button
            index = index + 1
        end
    end
end

function BF:RefreshBarButtons(bar)
    if not bar or not bar.buttons then return end
    local i
    for i = 1, table.getn(bar.buttons) do
        if bar.buttons[i] then
            self:RefreshButton(bar.buttons[i])
        end
    end
end

function BF:LoadBars()
    self.Bars = {}

    if not ButtonForgeClassicDB.bars or table.getn(ButtonForgeClassicDB.bars) == 0 then
        return
    end

    local i
    for i = 1, table.getn(ButtonForgeClassicDB.bars) do
        self:CreateBar(ButtonForgeClassicDB.bars[i])
    end
    self:RefreshMouseoverTicker()
end

function BF:ListBars()
    self:EnsureDB()
    local count = table.getn(ButtonForgeClassicDB.bars)
    if count == 0 then
        self:Print("No bars found. Use /bf new.")
        return
    end

    self:Print(count .. " Bar(s):")
    local i
    for i = 1, count do
        local b = ButtonForgeClassicDB.bars[i]
        self:Print("- " .. (b.name or ("Bar " .. i)))
    end
end

-- v0.2.8: safe bar editing. This does not change the backing action-slot logic.
function BF:GetActiveBar()
    if self.ActiveBar then return self.ActiveBar end
    if self.Bars and table.getn(self.Bars) > 0 then
        return self.Bars[table.getn(self.Bars)]
    end
    return nil
end

function BF:SetActiveBar(bar)
    if not bar then return end
    if self.ActiveBar == bar then return end

    if self.ActiveBar and self.ActiveBar ~= bar and self.UpdateBarActiveVisual then
        self:UpdateBarActiveVisual(self.ActiveBar, false)
    end

    self.ActiveBar = bar

    if self.UpdateBarActiveVisual then
        self:UpdateBarActiveVisual(bar, true)
    end
end

function BF:IsConfigMode()
    self:EnsureDB()
    return ButtonForgeClassicDB.settings and ButtonForgeClassicDB.settings.configMode
end

function BF:ApplyBarBackground(bar, save)
    if not bar then return end
    save = save or bar.save or {}

    if self:IsKeybindMode() then
        bar:SetBackdropColor(0.0, 0.18, 0.04, 0.35)
        if bar.SetBackdropBorderColor then
            bar:SetBackdropBorderColor(0.0, 1.0, 0.25, 1.0)
        end
        return
    end

    -- While the central menu is open, ButtonForge acts as a temporary edit
    -- preview: every created bar gets a visible black background regardless of
    -- its saved Background setting. The saved setting itself is never changed.
    local hide = save.hideBackground and true or false
    if self.MenuEditPreviewActive then
        hide = false
    end
    if hide then
        bar:SetBackdropColor(0, 0, 0, 0)
        if bar.SetBackdropBorderColor then
            bar:SetBackdropBorderColor(0, 0, 0, 0)
        end
    else
        -- Pure black bar background. Keep a subtle neutral border so the
        -- bar remains readable without the previous blue tint.
        bar:SetBackdropColor(0, 0, 0, 0.85)
        if bar.SetBackdropBorderColor then
            bar:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
        end
    end
end

function BF:SetBarHover(bar, active)
    if not bar or not bar.SetBackdropBorderColor then return end
    if not self:IsConfigMode() then
        self:ApplyBarBackground(bar, bar.save)
        return
    end
    if active then
        bar:SetBackdropBorderColor(1, 0.82, 0.15, 1)
    else
        self:ApplyBarBackground(bar, bar.save)
    end
end

function BF:UpdateBarActiveVisual(bar, active)
    -- No persistent highlight anymore: it cost performance and cluttered play mode.
    -- Hover highlighting is handled by SetBarHover().
    if not bar then return end
    self:ApplyBarBackground(bar, bar.save)
end

function BF:GetBarUsedButtonCount(bar)
    if not bar or not bar.save then return 0 end
    return (bar.save.cols or 1) * (bar.save.rows or 1)
end

function BF:UpdateBarDimensions(bar)
    if not bar or not bar.save then return end
    local save = bar.save
    bar:SetWidth((save.cols * self.ButtonSize) + ((save.cols - 1) * self.ButtonGap) + 12)
    bar:SetHeight((save.rows * self.ButtonSize) + ((save.rows - 1) * self.ButtonGap) + 12)
    if self.LayoutControlsForBar then
        self:LayoutControlsForBar(bar)
    end
end

function BF:LayoutButtonsForBar(bar)
    if not bar or not bar.save then return end
    local save = bar.save
    local index = 1

    self:UpdateBarDimensions(bar)

    for row = 1, save.rows do
        for col = 1, save.cols do
            if not bar.buttons[index] then
                bar.buttons[index] = self:CreateEmptyButton(bar, index)
            end
            local button = bar.buttons[index]
            button.activeInLayout = true
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", bar, "TOPLEFT", 6 + ((col - 1) * (self.ButtonSize + self.ButtonGap)), -6 - ((row - 1) * (self.ButtonSize + self.ButtonGap)))
            self:RefreshButton(button)
            index = index + 1
        end
    end

    -- Hide unused buttons when the bar is made smaller. We do not clear their
    -- ActionSlots automatically, so the user does not lose actions by accident.
    local i
    for i = index, table.getn(bar.buttons) do
        if bar.buttons[i] then
            bar.buttons[i].activeInLayout = false
            bar.buttons[i]:Hide()
        end
    end
end

function BF:ValidateBarSize(cols, rows)
    cols = tonumber(cols)
    rows = tonumber(rows)
    if not cols or cols < 1 then cols = 1 end
    if not rows or rows < 1 then rows = 1 end
    cols = math.floor(cols)
    rows = math.floor(rows)

    if cols > 12 then cols = 12 end
    if rows > 12 then rows = 12 end

    if cols * rows > (self.MaxButtonsPerBar or 12) then
        self:Print("Maximum " .. tostring(self.MaxButtonsPerBar or 12) .. " buttons per bar in this alpha.")
        return nil, nil
    end

    return cols, rows
end

function BF:SetActiveBarSize(cols, rows)
    local bar = self:GetActiveBar()
    if not bar then
        self:Print(self:T("NO_BAR"))
        return
    end

    cols, rows = self:ValidateBarSize(cols, rows)
    if not cols then return end

    bar.save.cols = cols
    bar.save.rows = rows
    self:LayoutButtonsForBar(bar)
    self:Print(bar.save.name .. ": " .. tostring(cols) .. "x" .. tostring(rows) .. " " .. self:T("SLOTS") .. ".")
end

function BF:SetActiveBarCols(cols)
    local bar = self:GetActiveBar()
    if not bar then
        self:Print(self:T("NO_BAR"))
        return
    end
    self:SetActiveBarSize(cols, bar.save.rows or 1)
end

function BF:SetActiveBarRows(rows)
    local bar = self:GetActiveBar()
    if not bar then
        self:Print(self:T("NO_BAR"))
        return
    end
    self:SetActiveBarSize(bar.save.cols or 1, rows)
end

function BF:SetActiveBarScale(scale)
    local bar = self:GetActiveBar()
    if not bar then
        self:Print(self:T("NO_BAR"))
        return
    end
    scale = tonumber(scale)
    if not scale then
        self:Print(self:T("SCALE_EXAMPLE"))
        return
    end
    if scale < (self.MinScale or 0.5) then scale = self.MinScale or 0.5 end
    if scale > (self.MaxScale or 2.0) then scale = self.MaxScale or 2.0 end

    -- SetScale() also scales a frame's anchor offsets in Vanilla WoW.
    -- If a moved bar is anchored to UIParent, changing its scale can therefore
    -- make the whole bar jump across the screen. Preserve the visual TOPLEFT
    -- position before scaling and re-anchor it afterwards using scale-adjusted
    -- coordinates. This keeps the bar stationary while it grows/shrinks.
    local oldScale = bar:GetScale() or 1
    local left = bar:GetLeft()
    local top = bar:GetTop()

    if left and top and oldScale > 0 and scale > 0 then
        local screenLeft = left * oldScale
        local screenTop = top * oldScale

        bar:SetScale(scale)
        bar:ClearAllPoints()

        local x = screenLeft / scale
        local y = screenTop / scale
        bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)

        -- Store the normalized anchor as well, so the bar reloads at the same
        -- place and future scale changes do not accumulate anchor drift.
        bar.save.point = "TOPLEFT"
        bar.save.relativePoint = "BOTTOMLEFT"
        bar.save.x = x
        bar.save.y = y
    else
        -- Safe fallback for the unlikely case that the frame has no resolved
        -- screen coordinates yet.
        bar:SetScale(scale)
    end

    bar.save.scale = scale
    self:Print(bar.save.name .. " " .. self:T("SCALED_TO") .. " " .. tostring(scale) .. ".")
end


-- v0.3.2: small original-style control buttons on each bar.
function BF:CreateControlButton(parent, text, tip, onClick, texture)
    local index = table.getn(parent.controls or {}) + 1
    local name = parent:GetName() .. "Ctl" .. tostring(index)
    local b = CreateFrame("Button", name, parent)
    b:SetWidth(self.ControlButtonSize or 18)
    b:SetHeight(self.ControlButtonSize or 18)
    b:SetFrameStrata("MEDIUM")
    b:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    b:SetBackdropColor(0, 0, 0, 0.85)

    b.icon = b:CreateTexture(name .. "Icon", "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    if texture then
        b.icon:SetTexture(texture)
    else
        b.icon:SetTexture(nil)
    end

    -- Keep a tiny text marker for paired controls (+/-). The icon gives the
    -- ButtonForge look, the marker keeps the alpha easy to understand.
    b.text = b:CreateFontString(name .. "Text", "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(text or "")

    b.tip = tip
    b.parentBar = parent
    b.controlIndex = index
    b._onclick = onClick
    b:SetScript("OnMouseUp", function()
        if this._onclick then
            this._onclick(this)
        end
    end)
    b:SetScript("OnEnter", function()
        BF:SetActiveBar(this.parentBar)
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText(this.tip or "ButtonForge Classic")
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return b
end

function BF:UpdateControlButtonVisuals(bar)
    if not bar or not bar.controls then return end
    local locked = bar.save and bar.save.locked
    local lockButton = bar.controls[7]
    if lockButton and lockButton.icon then
        if locked then
            lockButton.icon:SetTexture((self.ImagesDir or "") .. "ButtonsLocked.tga")
            if lockButton.text then lockButton.text:SetText("") end
            lockButton.tip = self:T("UNLOCK_BAR")
        else
            lockButton.icon:SetTexture((self.ImagesDir or "") .. "ButtonsUnlocked.tga")
            if lockButton.text then lockButton.text:SetText("") end
            lockButton.tip = self:T("LOCK_BAR")
        end
    end

    local bgButton = bar.controls[9]
    if bgButton then
        if bar.save and bar.save.hideBackground then
            bgButton.tip = self:T("SHOW_BACKGROUND")
        else
            bgButton.tip = self:T("HIDE_BACKGROUND")
        end
    end

    local gridButton = bar.controls[10]
    if gridButton and gridButton.icon then
        if bar.save and bar.save.showGrid then
            gridButton.icon:SetTexture((self.ImagesDir or "") .. "GridOn.tga")
            gridButton.tip = self:T("HIDE_EMPTY")
        else
            gridButton.icon:SetTexture((self.ImagesDir or "") .. "GridOff.tga")
            gridButton.tip = self:T("SHOW_EMPTY")
        end
    end

    local moButton = bar.controls[11]
    if moButton then
        if bar.save and bar.save.mouseover then
            moButton.tip = self:T("MOUSEOVER_TIP_ON") .. " " .. tostring(bar.save.mouseoverDelay or 1) .. "s"
        else
            moButton.tip = self:T("MOUSEOVER_TIP_OFF")
        end
    end
end

function BF:CreateControlsForBar(bar)
    bar.controls = {}
    local img = self.ImagesDir or "Interface\\AddOns\\ButtonForgeClassic\\Images\\"

    table.insert(bar.controls, self:CreateControlButton(bar, "+", self:T("ADD_COLUMN"), function()
        BF:SetActiveBar(this.parentBar)
        BF:SetActiveBarCols((this.parentBar.save.cols or 1) + 1)
    end, img .. "DragCols.tga"))
    table.insert(bar.controls, self:CreateControlButton(bar, "-", self:T("REMOVE_COLUMN"), function()
        BF:SetActiveBar(this.parentBar)
        BF:SetActiveBarCols((this.parentBar.save.cols or 1) - 1)
    end, img .. "DragCols.tga"))
    table.insert(bar.controls, self:CreateControlButton(bar, "+", self:T("ADD_ROW"), function()
        BF:SetActiveBar(this.parentBar)
        BF:SetActiveBarRows((this.parentBar.save.rows or 1) + 1)
    end, img .. "DragRows.tga"))
    table.insert(bar.controls, self:CreateControlButton(bar, "-", self:T("REMOVE_ROW"), function()
        BF:SetActiveBar(this.parentBar)
        BF:SetActiveBarRows((this.parentBar.save.rows or 1) - 1)
    end, img .. "DragRows.tga"))
    table.insert(bar.controls, self:CreateControlButton(bar, "+", self:T("SCALE_UP"), function()
        BF:SetActiveBar(this.parentBar)
        BF:SetActiveBarScale((this.parentBar.save.scale or 1) + 0.1)
    end, img .. "DragScale.tga"))
    table.insert(bar.controls, self:CreateControlButton(bar, "-", self:T("SCALE_DOWN"), function()
        BF:SetActiveBar(this.parentBar)
        BF:SetActiveBarScale((this.parentBar.save.scale or 1) - 0.1)
    end, img .. "DragScale.tga"))
    table.insert(bar.controls, self:CreateControlButton(bar, "", self:T("LOCK_UNLOCK_BAR"), function()
        BF:SetActiveBar(this.parentBar)
        BF:SetActiveBarLocked(not this.parentBar.save.locked)
    end, img .. "ButtonsUnlocked.tga"))
    table.insert(bar.controls, self:CreateControlButton(bar, "", self:T("DELETE_ACTIVE_BAR"), function()
        BF:SetActiveBar(this.parentBar)
        BF:DeleteActiveBar()
    end, img .. "DestroyBar.tga"))
    table.insert(bar.controls, self:CreateControlButton(bar, "", self:T("TOGGLE_BACKGROUND"), function()
        BF:SetActiveBar(this.parentBar)
        BF:ToggleBarBackground(this.parentBar)
    end, img .. "BarBackdrop.tga"))
    table.insert(bar.controls, self:CreateControlButton(bar, "", self:T("SHOW_HIDE_EMPTY"), function()
        BF:SetActiveBar(this.parentBar)
        BF:ToggleBarGrid(this.parentBar)
    end, img .. "GridOff.tga"))
    table.insert(bar.controls, self:CreateControlButton(bar, "M", self:T("TOGGLE_MOUSEOVER"), function()
        BF:SetActiveBar(this.parentBar)
        BF:ToggleBarMouseover(this.parentBar)
    end))

    self:UpdateControlButtonVisuals(bar)
    self:LayoutControlsForBar(bar)
end

function BF:LayoutControlsForBar(bar)
    if not bar or not bar.controls then return end
    self:UpdateControlButtonVisuals(bar)

    -- The old row of tiny edit icons was hard to read and easy to misclick.
    -- Keep the frames for backwards compatibility, but hide them permanently.
    -- Bar configuration now lives in the central minimap menu.
    local i
    for i = 1, table.getn(bar.controls) do
        if bar.controls[i] then
            bar.controls[i]:Hide()
        end
    end
end

function BF:SetActiveBarLocked(value)
    local bar = self:GetActiveBar()
    if not bar then
        self:Print(self:T("NO_BAR"))
        return
    end
    bar.save.locked = value
    self:LayoutControlsForBar(bar)
    if value then
        self:Print(bar.save.name .. " position locked.")
    else
        self:Print(bar.save.name .. " position unlocked.")
    end
end

function BF:SetActiveBarActionsLocked(value)
    local bar = self:GetActiveBar()
    if not bar then
        self:Print(self:T("NO_BAR"))
        return
    end

    bar.save.actionsLocked = value and true or false
    if bar.save.actionsLocked then
        self:Print(bar.save.name .. " actions locked. Use Shift + Drag to move an action.")
    else
        self:Print(bar.save.name .. " actions unlocked.")
    end
end

function BF:ClearBarActionSlots(bar)
    if not bar or not bar.buttons then return end
    local i
    for i = 1, table.getn(bar.buttons) do
        local btn = bar.buttons[i]
        if btn and btn.actionSlot and HasAction and HasAction(btn.actionSlot) and PickupAction then
            PickupAction(btn.actionSlot)
            if ClearCursor then ClearCursor() end
        end
    end
end

function BF:DeleteActiveBar()
    local bar = self:GetActiveBar()
    if not bar then
        self:Print("No active bar found.")
        return
    end

    local name = bar.save and bar.save.name or "Bar"
    self:ClearBarActionSlots(bar)
    if bar.save then
        self:RemoveBarSaveById(bar.save.id)
    end

    local i
    for i = table.getn(self.Bars), 1, -1 do
        if self.Bars[i] == bar then
            table.remove(self.Bars, i)
        end
    end

    bar:Hide()
    self.ActiveBar = nil
    if self.Bars and table.getn(self.Bars) > 0 then
        self:SetActiveBar(self.Bars[table.getn(self.Bars)])
    end
    self:RefreshMouseoverTicker()
    self:Print(name .. " deleted.")
end


-- v0.3.5: Edit/play mode and transparent bar background.
function BF:ApplyConfigModeToAllBars()
    if not self.Bars then return end
    local i
    for i = 1, table.getn(self.Bars) do
        if self.Bars[i] then
            self:ApplyBarBackground(self.Bars[i], self.Bars[i].save)
            self:LayoutControlsForBar(self.Bars[i])
            self:RefreshBarButtons(self.Bars[i])
        end
    end
end

function BF:ToggleConfigMode()
    self:EnsureDB()
    ButtonForgeClassicDB.settings.configMode = not ButtonForgeClassicDB.settings.configMode
    self:ApplyConfigModeToAllBars()
    if ButtonForgeClassicDB.settings.configMode then
        self:Print(self:T("CONFIG_MODE_ON"))
    else
        self:Print(self:T("CONFIG_MODE_OFF"))
    end
end

function BF:ToggleBarBackground(bar)
    if not bar then return end
    bar.save.hideBackground = not bar.save.hideBackground
    self:ApplyBarBackground(bar, bar.save)
    self:UpdateControlButtonVisuals(bar)
    if bar.save.hideBackground then
        self:Print(bar.save.name .. ": background hidden.")
    else
        self:Print(bar.save.name .. ": background shown.")
    end
end

function BF:ToggleBarGrid(bar)
    if not bar then return end
    bar.save.showGrid = not bar.save.showGrid
    self:UpdateControlButtonVisuals(bar)
    self:RefreshBarButtons(bar)
    if bar.save.showGrid then
        self:Print(bar.save.name .. ": empty slots visible.")
    else
        self:Print(bar.save.name .. ": empty slots hidden.")
    end
end

function BF:ToggleActiveBarBackground()
    local bar = self:GetActiveBar()
    if not bar then
        self:Print(self:T("NO_BAR"))
        return
    end
    self:ToggleBarBackground(bar)
end

function BF:ToggleAllBarBackgrounds()
    self:EnsureDB()
    ButtonForgeClassicDB.settings.hideBarBackground = not ButtonForgeClassicDB.settings.hideBarBackground
    local i
    if ButtonForgeClassicDB.bars then
        for i = 1, table.getn(ButtonForgeClassicDB.bars) do
            if ButtonForgeClassicDB.bars[i] then
                ButtonForgeClassicDB.bars[i].hideBackground = ButtonForgeClassicDB.settings.hideBarBackground
            end
        end
    end
    self:ApplyConfigModeToAllBars()
    if ButtonForgeClassicDB.settings.hideBarBackground then
        self:Print("Backgrounds hidden for all bars.")
    else
        self:Print("Backgrounds shown for all bars.")
    end
end

-- Right-click menu intentionally disabled in v0.3.13.
-- Mouseover bar logic (fade in/out, ticker) lives in Mouseover.lua.
