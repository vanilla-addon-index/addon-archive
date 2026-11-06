-- ButtonForge Classic - mouseover bars
-- Fade in while hovered, fade out after a per-bar delay.
-- Reuses the existing OnEnter/OnLeave hover tracking on the bar frame itself
-- (bar.mouseoverHovered) instead of polling MouseIsOver(), since child button
-- hover does not interrupt the parent bar's own OnEnter/OnLeave state.
local BF = BFClassic

BF.MouseoverFadeInSeconds = 0.2
BF.MouseoverFadeOutSeconds = 0.3

function BF:SyncBarCooldownAlpha(bar, alpha)
    if not bar or not bar.buttons then return end
    local value = alpha
    if value == nil and bar.GetAlpha then value = bar:GetAlpha() end
    if value == nil then value = 1 end

    local i
    for i = 1, table.getn(bar.buttons) do
        local button = bar.buttons[i]
        if button and button.cooldown then
            button.cooldown:SetAlpha(value)
            if value <= 0.01 then
                button.cooldown:Hide()
            else
                button.cooldown:Show()
            end
        end
    end
end

function BF:ToggleBarMouseover(bar)
    if not bar then return end
    bar.save.mouseover = not bar.save.mouseover
    if not bar.save.mouseover then
        bar.mouseoverCurrentAlpha = 1
        bar.mouseoverHideAt = nil
        bar:SetAlpha(1)
    end
    self:UpdateControlButtonVisuals(bar)
    self:RefreshMouseoverTicker()
    if bar.save.mouseover then
        self:Print(bar.save.name .. ": " .. self:T("MOUSEOVER_ON"))
    else
        self:Print(bar.save.name .. ": " .. self:T("MOUSEOVER_OFF"))
    end
end

function BF:ToggleActiveBarMouseover()
    local bar = self:GetActiveBar()
    if not bar then
        self:Print(self:T("NO_BAR"))
        return
    end
    self:ToggleBarMouseover(bar)
end

function BF:SetBarMouseoverDelay(bar, seconds)
    if not bar then return end
    seconds = tonumber(seconds)
    if not seconds then
        self:Print(self:T("MOUSEOVER_DELAY_EXAMPLE"))
        return
    end
    if seconds < (self.MinMouseoverDelay or 0) then seconds = self.MinMouseoverDelay or 0 end
    if seconds > (self.MaxMouseoverDelay or 5) then seconds = self.MaxMouseoverDelay or 5 end
    bar.save.mouseoverDelay = seconds
    self:UpdateControlButtonVisuals(bar)
    self:Print(bar.save.name .. ": " .. self:T("MOUSEOVER_DELAY_SET") .. " " .. tostring(seconds) .. "s.")
end

function BF:SetActiveBarMouseoverDelay(seconds)
    local bar = self:GetActiveBar()
    if not bar then
        self:Print(self:T("NO_BAR"))
        return
    end
    self:SetBarMouseoverDelay(bar, seconds)
end

-- A bar is temporarily forced fully visible while it cannot be safely hidden:
-- editing/keybinding it, or while any drag/drop swap grid is active.
-- IsTemporaryGridActive() is intentionally global (not scoped to this bar):
-- it already makes empty slots visible on every bar during a drag so the
-- player can drop the held action onto any bar, not just the one they
-- started dragging from. Mouseover bars must follow that same global scope,
-- otherwise a hidden bar could not be used as a drop target mid-drag.
function BF:IsMouseoverExempt()
    return self:IsConfigMode() or self:IsKeybindMode() or self:IsTemporaryGridActive()
end

function BF:UpdateBarMouseoverAlpha(bar, elapsed)
    if not bar or not bar.save then return end

    if not bar.save.mouseover then
        if bar.mouseoverCurrentAlpha ~= nil and bar.mouseoverCurrentAlpha < 1 then
            bar.mouseoverCurrentAlpha = 1
            bar:SetAlpha(1)
            self:SyncBarCooldownAlpha(bar, 1)
        end
        return
    end

    local target = 1
    if self:IsMouseoverExempt() or bar.mouseoverHovered then
        bar.mouseoverHideAt = nil
    else
        local delay = bar.save.mouseoverDelay or 1
        if not bar.mouseoverHideAt then
            bar.mouseoverHideAt = (GetTime and GetTime() or 0) + delay
        elseif (GetTime and GetTime() or 0) >= bar.mouseoverHideAt then
            target = 0
        end
    end

    local current = bar.mouseoverCurrentAlpha or 1
    if current == target then
        bar.mouseoverCurrentAlpha = target
        self:SyncBarCooldownAlpha(bar, target)
        return
    end

    local duration = self.MouseoverFadeOutSeconds or 0.3
    if target > current then
        duration = self.MouseoverFadeInSeconds or 0.2
    end
    local step = (elapsed or 0) / duration

    if target > current then
        current = current + step
        if current > target then current = target end
    else
        current = current - step
        if current < target then current = target end
    end

    bar.mouseoverCurrentAlpha = current
    bar:SetAlpha(current)
    self:SyncBarCooldownAlpha(bar, current)
end

function BF:AnyBarHasMouseover()
    if not self.Bars then return false end
    local i
    for i = 1, table.getn(self.Bars) do
        if self.Bars[i] and self.Bars[i].save and self.Bars[i].save.mouseover then
            return true
        end
    end
    return false
end

function BF:RefreshMouseoverTicker()
    if not self.MouseoverFadeFrame then return end
    if self:AnyBarHasMouseover() then
        self.MouseoverFadeFrame:Show()
    else
        self.MouseoverFadeFrame:Hide()
    end
end

-- Idle by default: the ticker only runs while at least one bar has
-- mouseover enabled, so bars without the feature pay no OnUpdate cost.
BF.MouseoverFadeFrame = CreateFrame("Frame")
BF.MouseoverFadeFrame.Elapsed = 0
BF.MouseoverFadeFrame:Hide()
BF.MouseoverFadeFrame:SetScript("OnUpdate", function()
    this.Elapsed = (this.Elapsed or 0) + arg1
    if this.Elapsed < 0.03 then return end
    local dt = this.Elapsed
    this.Elapsed = 0
    if not BF.Bars then return end
    local i
    for i = 1, table.getn(BF.Bars) do
        if BF.Bars[i] then
            BF:UpdateBarMouseoverAlpha(BF.Bars[i], dt)
        end
    end
end)
