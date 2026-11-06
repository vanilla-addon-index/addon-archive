local TT = _G.TotemTimersAddon
local modFunc = math.mod or mod or function(value, divisor)
    return value - (math.floor(value / divisor) * divisor)
end

function TT.FormatTime(timeLeft)
    if timeLeft >= 60 then
        return string.format("%d:%02d", math.floor(timeLeft / 60), math.floor(modFunc(timeLeft, 60)))
    end

    return tostring(math.ceil(timeLeft))
end

local function CreateBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.88)
    frame:SetBackdropBorderColor(0.42, 0.39, 0.3, 1)
end

local function GetSpellTextureByName(spellName)
    local index = TT.GetSpellbookSlot(spellName)
    if index then
        return GetSpellTexture(index, BOOKTYPE_SPELL)
    end

    return "Interface\\Icons\\Spell_Nature_EarthBindTotem"
end

local function AddTooltipLine(leftText, rightText, r, g, b)
    if not GameTooltip or not leftText then
        return
    end

    if rightText then
        GameTooltip:AddDoubleLine(leftText, rightText, r or 0.85, g or 0.85, b or 0.85, 1, 1, 1)
    else
        GameTooltip:AddLine(leftText, r or 0.85, g or 0.85, b or 0.85)
    end
end

local function ShowTotemTooltip(btn)
    local selectedSpell
    local active = TT.ACTIVE[btn.element]
    local remaining = TT.GetRemainingTime(btn.element)
    local knownCount = table.getn(TT.GetKnownTotems(btn.element))

    if not GameTooltip then
        return
    end

    selectedSpell = TotemTimersDB.selected[btn.element]

    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(btn.element .. " Totem", 1, 0.82, 0.2)

    if selectedSpell then
        AddTooltipLine("Selected", selectedSpell)
    end

    if active and active.name then
        AddTooltipLine("Active", active.name)
        if remaining then
            AddTooltipLine("Remaining", TT.FormatTime(remaining))
        end
    else
        AddTooltipLine("Status", "Inactive")
    end

    if knownCount > 1 then
        AddTooltipLine("Hover", "Choose another totem", 0.72, 0.85, 1)
    end

    AddTooltipLine("Left-click", "Cast selected totem", 0.72, 0.95, 0.72)
    AddTooltipLine("Right-click", "Clear active timer", 1, 0.74, 0.74)

    GameTooltip:Show()
end

local function ShowRecallTooltip(btn)
    if not GameTooltip then
        return
    end

    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(TT.RECALL_SPELL, 0.72, 0.85, 1)
    AddTooltipLine("Effect", "Recall all active totems")
    AddTooltipLine("Left-click", "Cast recall", 0.72, 0.95, 0.72)
    GameTooltip:Show()
end

local function ResetButtonVisuals(btn)
    btn.time:SetText("")
    btn.cooldown:SetHeight(4)
    btn.gcd:Hide()
    btn:SetBackdropBorderColor(0.42, 0.39, 0.3, 1)
    btn.time:SetTextColor(0.92, 0.92, 0.92)

    if btn.glow then
        btn.glow:Hide()
    end
end

local function HideOtherMenus(activeElement)
    local index
    for index = 1, table.getn(TT.ELEMENTS) do
        local element = TT.ELEMENTS[index]
        if element ~= activeElement then
            local btn = TT.GetButton(element)
            if btn and btn.menu then
                btn.menu:Hide()
            end
        end
    end
end

local function IsMouseOverFrame(frame)
    if not frame or not frame:IsShown() then
        return false
    end

    local scale = frame:GetEffectiveScale()
    local left = frame:GetLeft()
    local right = frame:GetRight()
    local top = frame:GetTop()
    local bottom = frame:GetBottom()
    local x, y = GetCursorPosition()

    if not left or not right or not top or not bottom then
        return false
    end

    x = x / scale
    y = y / scale

    return x >= left and x <= right and y >= bottom and y <= top
end

local function ScheduleMenuHide(btn)
    if not btn then
        return
    end

    btn.hideMenuAt = GetTime() + 0.12
    btn:SetScript("OnUpdate", function()
        if not this.hideMenuAt or GetTime() < this.hideMenuAt then
            return
        end

        if IsMouseOverFrame(this) or IsMouseOverFrame(this.menu) then
            this.hideMenuAt = nil
            return
        end

        if this.menu then
            this.menu:Hide()
        end
        this.hideMenuAt = nil
        this:SetScript("OnUpdate", nil)
    end)
end

local function CreateMenuButton(parent, index)
    local item = CreateFrame("Button", nil, parent)
    item:SetWidth(38)
    item:SetHeight(38)
    item:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    item:SetBackdropColor(0.04, 0.04, 0.04, 0.98)
    item:SetBackdropBorderColor(0.32, 0.3, 0.26, 1)

    item.icon = item:CreateTexture(nil, "ARTWORK")
    item.icon:SetPoint("TOPLEFT", item, "TOPLEFT", 3, -3)
    item.icon:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -3, 3)

    item.shine = item:CreateTexture(nil, "OVERLAY")
    item.shine:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    item.shine:SetBlendMode("ADD")
    item.shine:SetPoint("CENTER", item, "CENTER", 0, 0)
    item.shine:SetWidth(68)
    item.shine:SetHeight(68)
    item.shine:SetVertexColor(1, 0.82, 0.25, 0.45)
    item.shine:Hide()

    item:SetScript("OnEnter", function()
        if this.spellName then
            this:SetBackdropBorderColor(1, 0.82, 0.25, 1)
            this.shine:Show()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(this.spellName)
            GameTooltip:AddLine("Click to cast and set as default", 0.82, 0.82, 0.82)
            GameTooltip:Show()
        end
    end)
    item:SetScript("OnLeave", function()
        if this.isSelected then
            this:SetBackdropBorderColor(1, 0.82, 0.25, 1)
        else
            this:SetBackdropBorderColor(0.32, 0.3, 0.26, 1)
        end
        this.shine:Hide()
        GameTooltip:Hide()
    end)
    item:SetScript("OnClick", function()
        if not this.spellName then
            return
        end

        TT.SetSelectedSpell(this.element, this.spellName)
        CastSpellByName(this.spellName)
        parent:Hide()
    end)

    if index == 1 then
        item:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
    end

    return item
end

local function CreateSpellMenu(btn)
    local menu = CreateFrame("Frame", nil, btn)
    menu:SetWidth(48)
    menu:SetHeight(48)
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    menu:SetBackdropColor(0.015, 0.015, 0.02, 0.97)
    menu:SetBackdropBorderColor(0.86, 0.72, 0.24, 1)
    menu:SetFrameStrata("DIALOG")
    menu:EnableMouse(true)
    menu:Hide()

    menu.buttons = {}
    menu.owner = btn
    menu:SetScript("OnEnter", function()
        this.owner.hideMenuAt = nil
    end)
    menu:SetScript("OnLeave", function()
        ScheduleMenuHide(this.owner)
    end)

    btn.menu = menu
    return menu
end

function TT.UpdateSpellMenu(element)
    local btn = TT.GetButton(element)
    local spells
    local index
    local item
    local menuWidth
    local menuHeight
    local itemSize = 38
    local itemSpacing = 4
    local padding = 5

    if not btn or not btn.menu then
        return
    end

    spells = TT.GetKnownTotems(element)
    menuWidth = itemSize + (padding * 2)
    menuHeight = (table.getn(spells) * (itemSize + itemSpacing)) - itemSpacing + (padding * 2)
    if table.getn(spells) < 1 then
        menuWidth = itemSize + (padding * 2)
        menuHeight = itemSize + (padding * 2)
    end

    btn.menu:ClearAllPoints()
    btn.menu:SetPoint("BOTTOM", btn, "TOP", 0, 8)
    btn.menu:SetWidth(menuWidth)
    btn.menu:SetHeight(menuHeight)

    for index = 1, table.getn(spells) do
        item = btn.menu.buttons[index]
        if not item then
            item = CreateMenuButton(btn.menu, index)
            btn.menu.buttons[index] = item
        end

        item.element = element
        item.spellName = spells[index]
        item.icon:SetTexture(GetSpellTextureByName(spells[index]))
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", btn.menu, "TOPLEFT", padding, -padding - ((index - 1) * (itemSize + itemSpacing)))

        if TotemTimersDB.selected[element] == spells[index] then
            item.isSelected = true
            item:SetBackdropBorderColor(1, 0.82, 0.25, 1)
            item.shine:Show()
        else
            item.isSelected = false
            item:SetBackdropBorderColor(0.32, 0.3, 0.26, 1)
            item.shine:Hide()
        end

        item:Show()
    end

    for index = table.getn(spells) + 1, table.getn(btn.menu.buttons) do
        btn.menu.buttons[index]:Hide()
    end

    if table.getn(spells) < 2 then
        btn.menu:Hide()
    end
end

function TT.CreateButton(element)
    local btn = CreateFrame("Button", "TotemTimers_" .. element, TT.ANCHOR or UIParent)
    btn.element = element
    btn:RegisterForDrag("LeftButton")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)

    btn.cooldown = btn:CreateTexture(nil, "OVERLAY")
    btn.cooldown:SetTexture(0, 0, 0, 0.58)
    btn.cooldown:SetPoint("BOTTOMLEFT", btn.icon, "BOTTOMLEFT")
    btn.cooldown:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT")
    btn.cooldown:SetHeight(4)

    btn.gcd = btn:CreateTexture(nil, "OVERLAY")
    btn.gcd:SetTexture(1, 1, 1, 0.18)
    btn.gcd:SetAllPoints(btn.icon)
    btn.gcd:Hide()

    btn.time = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.time:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.time:SetJustifyH("CENTER")
    btn.time:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.label:SetPoint("BOTTOM", btn, "TOP", 0, 3)
    btn.label:SetText(element)
    btn.label:SetTextColor(0.9, 0.84, 0.58)

    CreateBackdrop(btn)
    CreateSpellMenu(btn)
    ResetButtonVisuals(btn)

    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnDragStart", function()
        TT.StartMovingAnchor()
    end)
    btn:SetScript("OnDragStop", function()
        TT.StopMovingAnchor()
    end)
    btn:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            TT.StopTotem(element)
        else
            TT.CastSelectedSpell(element)
        end
    end)
    btn:SetScript("OnEnter", function()
        this.hideMenuAt = nil
        HideOtherMenus(element)
        TT.UpdateSpellMenu(element)
        ShowTotemTooltip(this)
        if table.getn(TT.GetKnownTotems(element)) > 1 then
            this.menu:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
        ScheduleMenuHide(this)
    end)

    TT.UpdateSpellMenu(element)
    return btn
end

function TT.CreateRecallButton()
    local btn = CreateFrame("Button", "TotemTimers_Recall", TT.ANCHOR or UIParent)
    btn:SetFrameStrata("MEDIUM")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.label:SetPoint("BOTTOM", btn, "TOP", 0, 3)
    btn.label:SetText("Recall")
    btn.label:SetTextColor(0.72, 0.85, 1)

    CreateBackdrop(btn)
    btn.icon:SetTexture(GetSpellTextureByName(TT.RECALL_SPELL))
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function()
        TT.CastRecall()
    end)
    btn:SetScript("OnEnter", function()
        ShowRecallTooltip(this)
    end)
    btn:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    btn:Hide()

    return btn
end

function TT.UpdateRecallButton()
    local btn = TT.GetRecallButton()

    if not btn then
        return
    end

    if TT.IsRecallKnown() then
        btn.icon:SetTexture(GetSpellTextureByName(TT.RECALL_SPELL))
        btn:Show()
    else
        btn:Hide()
    end
end

local function UpdateTimerVisual(btn, remaining, duration)
    local pct = remaining / duration
    local minHeight = 4
    local maxHeight = math.max(minHeight, math.floor(btn.icon:GetHeight() * 0.22))

    if pct < 0 then pct = 0 end
    if pct > 1 then pct = 1 end

    btn.time:SetText(TT.FormatTime(remaining))
    btn.cooldown:SetHeight(minHeight + ((maxHeight - minHeight) * pct))
end

local function UpdateGCDOverlay(btn)
    local remaining = TT.GetGCDRemaining()
    if remaining > 0 then
        local alpha = 0.08 + (remaining / TT.GCD.duration) * 0.25
        btn.gcd:SetTexture(1, 1, 1, alpha)
        btn.gcd:Show()
    else
        btn.gcd:Hide()
    end
end

function TT.UpdateButton(element, timeLeft, name)
    local btn = TT.GetButton(element)
    local spellName
    local texture

    if not btn then
        return
    end

    if not TT.HasKnownTotems(element) then
        btn:Hide()
        if btn.menu then
            btn.menu:Hide()
        end
        return
    end

    btn:Show()
    spellName = name or TT.GetSelectedSpell(element)
    texture = spellName and GetSpellTextureByName(spellName) or "Interface\\Icons\\INV_Misc_QuestionMark"
    btn.icon:SetTexture(texture)

    local data = TT.ACTIVE[element]
    if timeLeft and timeLeft > 0 and data then
        UpdateTimerVisual(btn, timeLeft, data.duration)
        UpdateGCDOverlay(btn)

        if TT.ApplyAdvancedVisuals then
            TT.ApplyAdvancedVisuals(btn, timeLeft, data.duration, element)
        end
    else
        ResetButtonVisuals(btn)
    end

    TT.UpdateSpellMenu(element)
end
