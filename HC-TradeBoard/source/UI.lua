local TB = TradeBoard

TB.Frames = {}

local MAIN_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = 1,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 10, right = 10, top = 10, bottom = 10 },
}

local PANEL_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = 1,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local GOLD_R = 0.86
local GOLD_G = 0.66
local GOLD_B = 0.24

local CATEGORY_TEXTURES = {
    ["All Items"] = "Interface\\Icons\\INV_Misc_Bag_10",
    Weapons = "Interface\\Icons\\INV_Sword_04",
    Armor = "Interface\\Icons\\INV_Chest_Chain_05",
    Containers = "Interface\\Icons\\INV_Misc_Bag_08",
    Consumables = "Interface\\Icons\\INV_Potion_93",
    ["Trade Goods"] = "Interface\\Icons\\INV_Misc_Gear_01",
    Recipes = "Interface\\Icons\\INV_Scroll_03",
    Projectiles = "Interface\\Icons\\INV_Ammo_Arrow_01",
    Quivers = "Interface\\Icons\\INV_Misc_Quiver_03",
    Miscellaneous = "Interface\\Icons\\INV_Misc_QuestionMark",
}

local function CreatePanel(parent, width, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(width)
    panel:SetHeight(height)
    panel:SetBackdrop(PANEL_BACKDROP)
    panel:SetBackdropColor(0.025, 0.025, 0.025, 0.96)
    panel:SetBackdropBorderColor(0.42, 0.34, 0.18, 1)
    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetTexture(0.018, 0.016, 0.012, 1)
    fill:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    fill:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    return panel
end

local function CreateText(parent, text, font, r, g, b)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetText(text or "")
    if r then
        label:SetTextColor(r, g, b)
    end
    return label
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetBackdrop(PANEL_BACKDROP)
    button:SetBackdropColor(0.18, 0.045, 0.018, 1)
    button:SetBackdropBorderColor(0.62, 0.40, 0.14, 1)

    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetTexture(0.18, 0.045, 0.018, 0.95)
    fill:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    button.fill = fill

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture(0.75, 0.45, 0.12, 0.20)
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)

    local label = CreateText(button, text, "GameFontNormal")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    label:SetTextColor(1.00, 0.82, 0.24)
    button.label = label

    return button
end

local function SetButtonSelected(button, selected)
    if selected then
        button.fill:SetTexture(0.20, 0.08, 0.015, 1)
        button:SetBackdropColor(0.26, 0.10, 0.02, 1)
        button:SetBackdropBorderColor(0.95, 0.66, 0.18, 1)
        button.label:SetTextColor(1.00, 0.84, 0.26)
    else
        button.fill:SetTexture(0.035, 0.030, 0.022, 1)
        button:SetBackdropColor(0.055, 0.055, 0.055, 1)
        button:SetBackdropBorderColor(0.34, 0.28, 0.16, 1)
        button.label:SetTextColor(0.83, 0.74, 0.58)
    end
end

local function CreateCheckButton(parent, text, width, checked, callback, r, g, b)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    button:SetHeight(24)
    button.checked = checked

    local box = button:CreateTexture(nil, "ARTWORK")
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetWidth(24)
    box:SetHeight(24)
    box:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.box = box

    local check = button:CreateTexture(nil, "OVERLAY")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetWidth(24)
    check:SetHeight(24)
    check:SetPoint("CENTER", box, "CENTER", 0, 0)
    button.check = check

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture(1.00, 0.78, 0.20, 0.20)
    highlight:SetWidth(18)
    highlight:SetHeight(18)
    highlight:SetPoint("CENTER", box, "CENTER", 0, 0)

    local label = CreateText(button, text, "GameFontHighlightSmall", r or 0.90, g or 0.86, b or 0.76)
    label:SetPoint("LEFT", box, "RIGHT", 2, 1)
    label:SetJustifyH("LEFT")
    button.label = label

    function button:SetCheckedValue(value)
        self.checked = value
        if value then
            self.check:Show()
        else
            self.check:Hide()
        end
    end

    button:SetCheckedValue(checked)
    button:SetScript("OnClick", function()
        if this.checked then
            this:SetCheckedValue(nil)
        else
            this:SetCheckedValue(1)
        end
        if callback then
            callback(this.checked)
        end
    end)

    return button
end

local function CreateEditBox(parent, width, height, text)
    local edit = CreateFrame("EditBox", nil, parent)
    edit:SetWidth(width)
    edit:SetHeight(height)
    edit:SetAutoFocus(nil)
    edit:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    edit:SetTextColor(0.95, 0.90, 0.78)
    edit:SetJustifyH("LEFT")
    edit:SetBackdrop(PANEL_BACKDROP)
    edit:SetBackdropColor(0.01, 0.01, 0.01, 1)
    edit:SetBackdropBorderColor(0.35, 0.30, 0.20, 1)
    if edit.SetTextInsets then
        edit:SetTextInsets(7, 7, 0, 0)
    end
    edit:SetText(text or "")
    edit:SetScript("OnEscapePressed", function()
        this:ClearFocus()
        TB:Close()
    end)
    return edit
end

local function CreateHeading(parent, text)
    local heading = CreateText(parent, text, "GameFontNormal", 1.00, 0.78, 0.24)
    heading:SetPoint("TOP", parent, "TOP", 0, -9)
    return heading
end

-- Small, self-contained dropdowns keep the AH filters on one line on 1.12.
local function CreateDropdown(parent, width, choices, onSelect)
    local button = CreateButton(parent, "", width, 28)
    button:SetBackdropColor(0.025, 0.025, 0.025, 1)
    button.fill:SetTexture(0.025, 0.025, 0.025, 1)
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", button, "LEFT", 8, 0)
    button.label:SetWidth(width - 30)
    button.label:SetJustifyH("LEFT")
    button.label:SetFontObject(GameFontHighlightSmall)
    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetWidth(22); arrow:SetHeight(22)
    arrow:SetPoint("RIGHT", button, "RIGHT", -3, 0)
    local menu = CreatePanel(button, math.max(width, 138), table.getn(choices) * 25 + 8)
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(button:GetFrameLevel() + 10)
    menu:EnableMouse(1)
    menu:Hide()
    button.menu = menu
    button.options = {}
    function button:SetValue(value)
        self.value = value
        local i
        for i = 1, table.getn(choices) do
            if choices[i].value == value then self.label:SetText(choices[i].label) end
            SetButtonSelected(self.options[i], choices[i].value == value)
        end
    end
    local i
    for i = 1, table.getn(choices) do
        local option = CreateButton(menu, choices[i].label, menu:GetWidth() - 8, 24)
        option:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * 25)
        option.value = choices[i].value
        option:SetScript("OnClick", function()
            button:SetValue(this.value)
            menu:Hide()
            TB.openFilterMenu = nil
            onSelect(this.value)
        end)
        button.options[i] = option
    end
    button:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide(); TB.openFilterMenu = nil
        else
            if TB.openFilterMenu then TB.openFilterMenu:Hide() end
            menu:Show(); TB.openFilterMenu = menu
        end
    end)
    button:SetScript("OnHide", function() menu:Hide() end)
    return button
end

function TB:UpdateWhoButton(button, name, level)
    button.trader = name
    button.sender = name
    local knownLevel = tonumber(level) or 0
    if name then
        local cachedLevel = self:GetKnownTraderInfo(name)
        if (tonumber(cachedLevel) or 0) > knownLevel then knownLevel = cachedLevel end
    end
    if not name or name == "" or knownLevel > 0 then button:Hide(); return end
    local remaining = self:GetWhoCooldownRemaining()
    button.label:SetText(remaining > 0 and tostring(remaining) or "?")
    if remaining > 0 then
        button:Disable(); button.label:SetTextColor(0.62, 0.58, 0.47)
    else
        button:Enable(); button.label:SetTextColor(1.00, 0.82, 0.24)
    end
    button:Show()
end

function TB:RefreshWhoButtons()
    local i, row
    for i = 1, table.getn(self.Frames.resultRows or {}) do
        row = self.Frames.resultRows[i]
        self:UpdateWhoButton(row.whoButton, row.listing and row.listing.trader, row.listing and row.listing.traderLevel)
    end
    for i = 1, table.getn(self.Frames.worldLogRows or {}) do
        row = self.Frames.worldLogRows[i]
        self:UpdateWhoButton(row.whoButton, row.entry and row.entry.sender, row.entry and row.entry.level)
    end
    for i = 1, table.getn(self.Frames.professionRows or {}) do
        row = self.Frames.professionRows[i]
        self:UpdateWhoButton(row.whoButton, row.service and row.service.trader, row.service and row.service.level)
    end
    local chainButton = self.Frames.chainWhoButton
    if chainButton then self:UpdateWhoButton(chainButton, chainButton.trader) end
end

local function CreateClassicScrollbar(parent, height, onOffsetChanged)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(20)
    bar:SetHeight(height)
    bar.offset = 0
    bar.maxOffset = 0

    local up = CreateFrame("Button", nil, bar)
    up:SetWidth(18); up:SetHeight(18); up:SetPoint("TOP", bar, "TOP", 0, 0)
    up:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
    up:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
    up:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Disabled")
    up:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight")
    local down = CreateFrame("Button", nil, bar)
    down:SetWidth(18); down:SetHeight(18); down:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
    down:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    down:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
    down:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Disabled")
    down:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight")
    local track = CreateFrame("Frame", nil, bar)
    track:SetPoint("TOP", up, "BOTTOM", 0, -1); track:SetPoint("BOTTOM", down, "TOP", 0, 1); track:SetWidth(16)
    track:SetBackdrop(PANEL_BACKDROP); track:SetBackdropColor(0.015, 0.012, 0.008, 1); track:SetBackdropBorderColor(0.28, 0.22, 0.12, 1)
    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(14); thumb:SetHeight(30); thumb:SetPoint("TOP", track, "TOP", 0, -1)
    local thumbTexture = thumb:CreateTexture(nil, "ARTWORK")
    thumbTexture:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    thumbTexture:SetAllPoints(thumb)
    thumb:RegisterForDrag("LeftButton")

    function bar:SetRange(offset, maxOffset)
        self.maxOffset = maxOffset or 0
        if self.maxOffset < 0 then self.maxOffset = 0 end
        self.offset = offset or 0
        if self.offset < 0 then self.offset = 0 elseif self.offset > self.maxOffset then self.offset = self.maxOffset end
        local travel = track:GetHeight() - thumb:GetHeight() - 2
        if travel < 0 then travel = 0 end
        local ratio = self.maxOffset > 0 and (self.offset / self.maxOffset) or 0
        thumb:ClearAllPoints(); thumb:SetPoint("TOP", track, "TOP", 0, -1 - (travel * ratio))
        if self.offset <= 0 then up:Disable() else up:Enable() end
        if self.offset >= self.maxOffset then down:Disable() else down:Enable() end
        if self.maxOffset == 0 then thumb:Hide() else thumb:Show() end
    end
    local function Change(delta)
        local value = bar.offset + delta
        if value < 0 then value = 0 elseif value > bar.maxOffset then value = bar.maxOffset end
        if value ~= bar.offset then onOffsetChanged(value) end
    end
    up:SetScript("OnClick", function() Change(-1) end)
    down:SetScript("OnClick", function() Change(1) end)
    thumb:SetScript("OnDragStart", function()
        this.dragging = 1
        this:SetScript("OnUpdate", function()
            if not this.dragging or bar.maxOffset <= 0 then return end
            local scale = track:GetEffectiveScale()
            local x, y = GetCursorPosition(); y = y / scale
            local top = track:GetTop(); local travel = track:GetHeight() - this:GetHeight() - 2
            if top and travel > 0 then
                local ratio = (top - y - (this:GetHeight() / 2)) / travel
                if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
                local value = math.floor((ratio * bar.maxOffset) + 0.5)
                if value ~= bar.offset then onOffsetChanged(value) end
            end
        end)
    end)
    thumb:SetScript("OnDragStop", function() this.dragging = nil; this:SetScript("OnUpdate", nil) end)
    bar:SetRange(0, 0)
    return bar
end

function TB:OnMainFrameHidden()
    if self.openFilterMenu then self.openFilterMenu:Hide(); self.openFilterMenu = nil end
    self.bagPickMode = nil
    if self.Frames.chainEditor then
        self.Frames.chainEditor:Hide()
    end
    if self.Frames.deliveryDesk then self.Frames.deliveryDesk:Hide() end
    if self.Frames.settingsPanel then self.Frames.settingsPanel:Hide() end
    if self.Frames.professionEditor then
        self.Frames.professionEditor:Hide()
    end
    if self.HideBrowseListingTooltips then
        self:HideBrowseListingTooltips()
    else
        GameTooltip:Hide()
    end
end

function TB:Close()
    local frame = self.Frames and self.Frames.main
    if not frame then
        return
    end
    frame:StopMovingOrSizing()
    frame:Hide()
end

function TB:RefreshMemoryLabel()
    if not self.Frames.memoryLabel or not self.Frames.main:IsShown() then return end
    local sample = self:SampleMemoryUsage()
    if self.displayedMemorySample == sample then return end
    self.displayedMemorySample = sample
    if sample.scope == "addon" then
        self.Frames.memoryLabel:SetText(string.format("Addon: %.2f MB", sample.mb))
    elseif sample.scope == "lua" then
        self.Frames.memoryLabel:SetText(string.format("Lua total: %.2f MB", sample.mb))
    else
        self.Frames.memoryLabel:SetText("Memory: unavailable")
    end
end

function TB:CreateMainFrame()
    local frame = CreateFrame("Frame", "TradeBoardFrame", UIParent)
    frame:SetWidth(1180)
    frame:SetHeight(720)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(1)
    if frame.SetClampedToScreen then
        -- Players often keep bags at the right edge; allow TradeBoard to be
        -- parked partly beyond the game viewport instead of forcing overlap.
        frame:SetClampedToScreen(nil)
    end
    frame:EnableMouse(1)
    frame:SetBackdrop(MAIN_BACKDROP)
    frame:SetBackdropColor(0.018, 0.018, 0.018, 0.98)
    frame:SetBackdropBorderColor(0.54, 0.42, 0.18, 1)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(0.020, 0.018, 0.014, 1)
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    frame:SetScript("OnHide", function()
        TB:OnMainFrameHidden()
    end)
    self.Frames.main = frame

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -13)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -13)
    header:SetHeight(36)
    header:EnableMouse(1)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        TradeBoardFrame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        TradeBoardFrame:StopMovingOrSizing()
    end)

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetTexture(0.025, 0.025, 0.025, 1)
    headerBg:SetAllPoints(header)

    local title = CreateText(header, self.COLORED_TITLE, "GameFontNormalLarge", 1.00, 1.00, 1.00)
    title:SetPoint("CENTER", header, "CENTER", 0, 1)

    local version = CreateText(header, "v" .. self.VERSION, "GameFontDisableSmall", 0.55, 0.50, 0.40)
    version:SetPoint("LEFT", header, "LEFT", 8, 0)
    self.Frames.versionLabel = version

    local memory = CreateFrame("Frame", nil, header)
    memory:SetWidth(190); memory:SetHeight(24)
    memory:SetPoint("LEFT", header, "LEFT", 90, 0)
    memory:SetFrameLevel(header:GetFrameLevel() + 1)
    memory:EnableMouse(1)
    local memoryLabel = CreateText(memory, "Memory: --", "GameFontHighlightSmall", 0.65, 0.70, 0.62)
    memoryLabel:SetPoint("LEFT", memory, "LEFT", 0, 0)
    self.Frames.memoryLabel = memoryLabel
    self.Frames.memoryUsage = memory
    memory:SetScript("OnEnter", function()
        TB:RefreshMemoryLabel()
        local sample = TB.memorySample
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
        GameTooltip:SetText("HC TradeBoard memory", 1.00, 0.82, 0.24)
        if sample and sample.scope == "addon" then
            GameTooltip:AddLine("Memory attributed to HC TradeBoard by this client.", 0.90, 0.86, 0.76)
        elseif sample and sample.scope == "lua" then
            GameTooltip:AddLine("This client cannot report memory per addon.", 0.90, 0.86, 0.76)
            GameTooltip:AddLine("Lua total includes Blizzard UI and all addons.", 0.90, 0.86, 0.76)
        else
            GameTooltip:AddLine("This client does not expose memory usage.", 0.90, 0.86, 0.76)
        end
        if sample then
            GameTooltip:AddLine("Sampled " .. math.max(0, math.floor(GetTime() - sample.sampledAt)) .. "s ago.", 0.70, 0.70, 0.65)
        end
        GameTooltip:AddLine("Updates every 30s while TradeBoard is open.", 0.70, 0.70, 0.65)
        GameTooltip:Show()
    end)
    memory:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Keep the emergency close control outside the draggable header so even a
    -- small mouse movement cannot turn the click into a header drag.
    local close = CreateButton(frame, "X", 42, 32)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -15)
    close:SetFrameLevel(header:GetFrameLevel() + 10)
    close:RegisterForClicks("LeftButtonDown")
    close:SetScript("OnClick", function()
        TB:Close()
    end)
    self.Frames.closeButton = close

    local minimize = CreateButton(frame, "-", 36, 32)
    minimize:SetPoint("RIGHT", close, "LEFT", -6, 0)
    minimize:SetFrameLevel(header:GetFrameLevel() + 10)
    minimize:SetScript("OnClick", function() TB:SetMinimized(not TB.isMinimized) end)
    self.Frames.minimizeButton = minimize

    local settings = CreateButton(frame, "", 36, 32)
    settings:SetPoint("RIGHT", minimize, "LEFT", -6, 0)
    settings:SetFrameLevel(header:GetFrameLevel() + 10)
    local settingsIcon = settings:CreateTexture(nil, "ARTWORK")
    settingsIcon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    settingsIcon:SetWidth(19); settingsIcon:SetHeight(19); settingsIcon:SetPoint("CENTER", settings, "CENTER", 0, 0)
    settings:SetScript("OnClick", function() TB:ToggleSettings() end)
    settings:SetScript("OnEnter", function() GameTooltip:SetOwner(this, "ANCHOR_BOTTOM"); GameTooltip:SetText("TradeBoard settings"); GameTooltip:Show() end)
    settings:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.Frames.settingsButton = settings

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -94)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 48)
    self.Frames.content = content

    self:CreateTabs(frame)
    self:CreateBrowsePane(content)
    self:CreateMyListingsPane(content)
    self:CreateWantedPane(content)
    self:CreateTradeChainsPane(content)
    self:CreateProfessionsPane(content)
    self:CreateWorldLogPane(content)
    self:CreateSettingsPanel(frame)

    local statusBar = CreateFrame("Frame", nil, frame)
    statusBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 15)
    statusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 15)
    statusBar:SetHeight(24)
    statusBar:SetBackdrop(PANEL_BACKDROP)
    statusBar:SetBackdropColor(0.025, 0.025, 0.025, 1)
    statusBar:SetBackdropBorderColor(0.30, 0.25, 0.15, 1)
    self.Frames.statusBar = statusBar

    local statusText = CreateText(statusBar, "Ready.", "GameFontHighlightSmall", 0.70, 0.67, 0.58)
    statusText:SetPoint("LEFT", statusBar, "LEFT", 8, 0)
    statusText:SetWidth(510)
    statusText:SetJustifyH("LEFT")
    self.Frames.statusText = statusText

    local networkText = CreateText(statusBar, "Network: offline", "GameFontHighlightSmall", 0.70, 0.35, 0.30)
    networkText:SetPoint("RIGHT", statusBar, "RIGHT", -8, 0)
    networkText:SetWidth(390)
    networkText:SetJustifyH("RIGHT")
    self.Frames.networkText = networkText

    table.insert(UISpecialFrames, "TradeBoardFrame")
end

function TB:SetMinimapButtonAngle(angle)
    if not angle then
        angle = -2.52
    end
    self.minimapAngle = angle
    if self.Frames.minimapButton then
        local radius = 84
        self.Frames.minimapButton:ClearAllPoints()
        self.Frames.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end
    if TradeBoardDB then
        TradeBoardDB.minimapAngle = angle
    end
end

function TB:UpdateMinimapButtonFromCursor()
    local scale = Minimap:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    local centerX, centerY = Minimap:GetCenter()
    if not scale or scale == 0 or not centerX or not centerY then
        return
    end
    cursorX = cursorX / scale
    cursorY = cursorY / scale
    self:SetMinimapButtonAngle(math.atan2(cursorY - centerY, cursorX - centerX))
end

function TB:CreateMinimapButton()
    local button = CreateFrame("Button", "TradeBoardMinimapButton", Minimap)
    button:SetWidth(33)
    button:SetHeight(33)
    button:SetPoint("CENTER", Minimap, "CENTER", -70, -50)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetWidth(24)
    background:SetHeight(24)
    background:SetPoint("CENTER", button, "CENTER", 0, 0)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(52)
    border:SetHeight(52)
    border:SetPoint("CENTER", button, "CENTER", 10, -9)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetWidth(32)
    highlight:SetHeight(32)
    highlight:SetPoint("CENTER", button, "CENTER", 0, 0)
    highlight:SetBlendMode("ADD")

    button:SetScript("OnClick", function()
        if this.wasDragged then
            this.wasDragged = nil
            return
        end
        TB:Toggle()
    end)
    button:SetScript("OnDragStart", function()
        if IsControlKeyDown() then
            this.dragging = 1
            this:SetScript("OnUpdate", function()
                TB:UpdateMinimapButtonFromCursor()
            end)
        end
    end)
    button:SetScript("OnDragStop", function()
        if this.dragging then
            TB:UpdateMinimapButtonFromCursor()
            this.dragging = nil
            this.wasDragged = 1
            this:SetScript("OnUpdate", nil)
        end
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText(TB.COLORED_TITLE, 1.00, 1.00, 1.00)
        GameTooltip:AddLine("Left-click to open or close.", 0.88, 0.84, 0.75)
        GameTooltip:AddLine("Ctrl + left-drag to move.", 0.88, 0.84, 0.75)
        GameTooltip:AddLine("You can also type /tb.", 0.65, 0.72, 0.90)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.Frames.minimapButton = button
end

function TB:CreateTabs(parent)
    self.Frames.tabs = {}
    local names = { "Browse", "My Listings", "Wanted", "Trade Chains", "Professions", "World Trade" }
    local widths = { 138, 150, 112, 146, 138, 152 }
    local x = 24
    local i

    for i = 1, table.getn(names) do
        local tabName = names[i]
        local tab = CreateButton(parent, tabName, widths[i], 34)
        tab:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -55)
        tab:SetScript("OnClick", function()
            TB:SetActiveTab(tabName)
        end)
        self.Frames.tabs[tabName] = tab
        x = x + widths[i] + 6
    end
end

function TB:CreateBrowsePane(parent)
    local pane = CreateFrame("Frame", nil, parent)
    pane:SetAllPoints(parent)
    self.Frames.browsePane = pane

    local searchPanel = CreatePanel(pane, 1148, 42)
    searchPanel:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)

    self.Frames.browseFilterBar = searchPanel
    local searchField = CreateEditBox(searchPanel, 230, 28, "")
    searchField:SetPoint("LEFT", searchPanel, "LEFT", 8, 0)
    searchField:SetMaxLetters(60)
    self.Frames.searchField = searchField

    local placeholder = CreateText(searchPanel, "Search items...", "GameFontDisable", 0.50, 0.48, 0.44)
    placeholder:SetPoint("LEFT", searchField, "LEFT", 8, 0)
    self.Frames.searchPlaceholder = placeholder

    searchField:SetScript("OnTextChanged", function()
        if this:GetText() == "" then
            TB.Frames.searchPlaceholder:Show()
        else
            TB.Frames.searchPlaceholder:Hide()
        end
    end)
    searchField:SetScript("OnEnterPressed", function()
        this:ClearFocus()
        TB:UpdateBrowse()
    end)

    self:CreateCategoryPanel(pane)
    self:CreateFilterPanels(pane)
    self:CreateResultsPanel(pane)

    local countText = CreateText(pane, "0 matching listings", "GameFontHighlightSmall", 0.83, 0.77, 0.65)
    countText:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 185, 8)
    self.Frames.resultCount = countText

    local listButton = CreateButton(pane, "List an Item", 126, 34)
    listButton:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    listButton:SetScript("OnClick", function()
        TB:SetActiveTab("My Listings")
        TB:SetStatus("Choose an item from your bags, then set quantity and total price.")
    end)

    local addFriendButton = CreateButton(pane, "Add Friend", 108, 34)
    addFriendButton:SetPoint("RIGHT", listButton, "LEFT", -8, 0)
    addFriendButton:SetScript("OnClick", function()
        local listing = TB.State.selectedListing
        if listing then
            AddFriend(listing.trader)
            TB:SetStatus("Friend request sent for " .. listing.trader .. ".")
        else
            TB:SetStatus("Select a listing before adding its trader.")
        end
    end)

    local whisperButton = CreateButton(pane, "Whisper", 100, 34)
    whisperButton:SetPoint("RIGHT", addFriendButton, "LEFT", -8, 0)
    whisperButton:SetScript("OnClick", function()
        local listing = TB.State.selectedListing
        if listing then
            ChatFrame_OpenChat("/w " .. listing.trader .. " ")
            TB:SetStatus("Whisper opened for " .. listing.trader .. ".")
        else
            TB:SetStatus("Select a listing before whispering its trader.")
        end
    end)
end

function TB:CreateCategoryPanel(parent)
    local panel = CreatePanel(parent, 142, 488)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -50)
    self.Frames.categoryHeading = CreateHeading(panel, "Categories")
    self.Frames.categoryHeading:Hide()
    self.Frames.categoryPanel = panel
    self.Frames.categoryButtons = {}

    local i
    for i = 1, 11 do
        local button = CreateButton(panel, "", 126, 36)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8 - ((i - 1) * 40))
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button, "LEFT", 28, 0)
        button.label:SetWidth(92)
        button.label:SetJustifyH("LEFT")
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(22); icon:SetHeight(22); icon:SetPoint("LEFT", button, "LEFT", 4, 0)
        button.categoryIcon = icon
        button:SetScript("OnClick", function()
            local entry = this.categoryEntry
            if not entry then
                return
            end
            if entry.kind == "back" then
                TB.State.categoryView = "root"
            elseif entry.kind == "parent" then
                TB.State.category = entry.name
                TB.State.subCategory = nil
                TB.State.categoryView = entry.name
            elseif entry.kind == "allParent" then
                TB.State.category = entry.parent
                TB.State.subCategory = nil
            elseif entry.kind == "sub" then
                TB.State.category = entry.parent
                TB.State.subCategory = entry.name
            else
                TB.State.category = entry.name
                TB.State.subCategory = nil
            end
            TB.State.browseOffset = 0
            TB:UpdateBrowse()
        end)
        self.Frames.categoryButtons[i] = button
    end
    self:RefreshCategoryPanel()
end

function TB:RefreshCategoryPanel()
    local state = self.State
    local entries = {}
    local i

    if state.categoryView ~= "root" and self.Subcategories[state.categoryView] then
        local parent = state.categoryView
        self.Frames.categoryHeading:SetText(parent)
        table.insert(entries, { label = "< Categories", kind = "back" })
        table.insert(entries, { label = "All " .. parent, kind = "allParent", parent = parent })
        for i = 1, table.getn(self.Subcategories[parent]) do
            table.insert(entries, { label = self.Subcategories[parent][i], name = self.Subcategories[parent][i], kind = "sub", parent = parent })
        end
    else
        state.categoryView = "root"
        self.Frames.categoryHeading:SetText("Categories")
        for i = 1, table.getn(self.Categories) do
            local category = self.Categories[i]
            if self.Subcategories[category] then
                table.insert(entries, { label = category .. "  >", name = category, kind = "parent" })
            else
                table.insert(entries, { label = category, name = category, kind = "category" })
            end
        end
    end

    for i = 1, table.getn(self.Frames.categoryButtons) do
        local button = self.Frames.categoryButtons[i]
        local entry = entries[i]
        if entry then
            button.categoryEntry = entry
            button.label:SetText(entry.label)
            button.categoryIcon:SetTexture(CATEGORY_TEXTURES[entry.name or entry.parent or state.categoryView or "All Items"] or CATEGORY_TEXTURES["All Items"])
            local selected = nil
            if entry.kind == "category" then
                selected = state.category == entry.name and not state.subCategory
            elseif entry.kind == "parent" then
                selected = state.category == entry.name
            elseif entry.kind == "allParent" then
                selected = state.category == entry.parent and not state.subCategory
            elseif entry.kind == "sub" then
                selected = state.category == entry.parent and state.subCategory == entry.name
            end
            SetButtonSelected(button, selected)
            button:Show()
        else
            button.categoryEntry = nil
            button:Hide()
        end
    end
end

function TB:CreateFilterPanels(parent)
    local bar = self.Frames.browseFilterBar
    local levelLabel = CreateText(bar, "Level:", "GameFontHighlightSmall", GOLD_R, GOLD_G, GOLD_B)
    levelLabel:SetPoint("LEFT", bar, "LEFT", 248, 0)
    local levelType = CreateDropdown(bar, 102, {
        { label = "All", value = "all" },
        { label = "Required", value = "required" },
        { label = "Item level", value = "item" },
        { label = "My range", value = "range" },
    }, function(value)
        TB.State.myLevelRange = value == "range" and 1 or nil
        TB.State.levelType = value == "range" and "all" or value
        TB.State.browseOffset = 0
        TB:UpdateBrowse()
    end)
    levelType:SetPoint("LEFT", bar, "LEFT", 285, 0)
    self.Frames.levelDropdown = levelType

    local minLabel = CreateText(bar, "Min:", "GameFontHighlightSmall", GOLD_R, GOLD_G, GOLD_B)
    minLabel:SetPoint("LEFT", bar, "LEFT", 396, 0)
    local minEdit = CreateEditBox(bar, 42, 28, "")
    minEdit:SetPoint("LEFT", bar, "LEFT", 430, 0)
    minEdit:SetMaxLetters(3)
    minEdit:SetJustifyH("CENTER")
    self.Frames.minLevel = minEdit

    local maxLabel = CreateText(bar, "Max:", "GameFontHighlightSmall", GOLD_R, GOLD_G, GOLD_B)
    maxLabel:SetPoint("LEFT", bar, "LEFT", 480, 0)
    local maxEdit = CreateEditBox(bar, 42, 28, "")
    maxEdit:SetPoint("LEFT", bar, "LEFT", 514, 0)
    maxEdit:SetMaxLetters(3)
    maxEdit:SetJustifyH("CENTER")
    self.Frames.maxLevel = maxEdit

    minEdit:SetScript("OnEnterPressed", function()
        this:ClearFocus()
        TB:UpdateBrowse()
    end)
    maxEdit:SetScript("OnEnterPressed", function()
        this:ClearFocus()
        TB:UpdateBrowse()
    end)

    local rarityLabel = CreateText(bar, "Rarity:", "GameFontHighlightSmall", GOLD_R, GOLD_G, GOLD_B)
    rarityLabel:SetPoint("LEFT", bar, "LEFT", 566, 0)
    local rarityChoices = { { label = "All", value = "ALL" } }
    local quality
    for quality = 1, 5 do
        table.insert(rarityChoices, { label = quality == 2 and "Uncommon" or self.Quality[quality].name, value = quality })
    end
    local rarity = CreateDropdown(bar, 100, rarityChoices, function(value)
        local q
        for q = 1, 5 do TB.State.rarities[q] = (value == "ALL" or q == value) and 1 or nil end
        TB.State.browseOffset = 0
        TB:UpdateBrowse()
    end)
    rarity:SetPoint("LEFT", bar, "LEFT", 610, 0)
    self.Frames.rarityDropdown = rarity

    local listingLabel = CreateText(bar, "Listing Type:", "GameFontHighlightSmall", GOLD_R, GOLD_G, GOLD_B)
    listingLabel:SetPoint("LEFT", bar, "LEFT", 714, 0)
    local listingType = CreateDropdown(bar, 118, {
        { label = "All Listings", value = "ALL" },
        { label = "For Sale", value = "SELL" },
        { label = "Wanted", value = "BUY" },
    }, function(value)
        TB.State.listingType = value
        TB.State.browseOffset = 0
        TB:UpdateBrowse()
    end)
    listingType:SetPoint("LEFT", bar, "LEFT", 796, 0)
    self.Frames.listingTypeDropdown = listingType

    local onlineCheck = CreateCheckButton(bar, "Online", 90, self.State.onlineOnly, function(value)
        TB.State.onlineOnly = value
        TB.State.browseOffset = 0
        TB:UpdateBrowse()
    end)
    onlineCheck:SetPoint("LEFT", bar, "LEFT", 924, 0)
    self.Frames.onlineCheck = onlineCheck

    local clear = CreateButton(bar, "Clear", 108, 28)
    clear:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
    clear:SetScript("OnClick", function()
        if TB.openFilterMenu then TB.openFilterMenu:Hide(); TB.openFilterMenu = nil end
        TB:ResetFilters()
        TB:SyncFilterControls()
        TB:UpdateBrowse()
        TB:SetStatus("All local filters cleared.")
    end)
    self.Frames.clearFilters = clear
end

function TB:TryInsertItemLink(item)
    if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsShown() then
        local link = self:GetListingItemLink(item)
        if link then
            ChatFrameEditBox:Insert(link)
            return 1
        end
    end
    return nil
end

function TB:ShowBrowseListingTooltips(row, listing)
    if not self.Frames.listingSummaryTooltip then
        self.Frames.listingSummaryTooltip = CreateFrame("GameTooltip", "TradeBoardListingSummaryTooltip", UIParent, "GameTooltipTemplate")
    end

    local summary = self.Frames.listingSummaryTooltip
    local info = self.Quality[listing.quality] or self.Quality[1]
    summary:SetOwner(row, "ANCHOR_RIGHT")
    summary:ClearLines()
    summary:SetText(listing.name, info.r, info.g, info.b)
    summary:AddLine(listing.orderType == "BUY" and "Wanted listing" or "For-sale listing", 0.80, 0.75, 0.62)
    summary:AddLine("Required level " .. listing.requiredLevel .. "   Item level " .. listing.itemLevel, 1, 1, 1)
    summary:AddLine("Trader: " .. listing.trader .. " (level " .. listing.traderLevel .. ")", 0.70, 0.85, 1)
    if listing.guild and listing.guild ~= "" then
        summary:AddLine("Guild: " .. listing.guild, 0.82, 0.72, 0.42)
    end
    if not listing.online then
        summary:AddLine("Last seen: " .. self:FormatLastSeen(listing.lastSeenAt) .. " ago", 0.58, 0.58, 0.58)
    end
    if listing.priceKnown and listing.quantity and listing.quantity > 1 then
        summary:AddLine("Per item: " .. self:FormatMoney(math.floor(listing.totalPrice / listing.quantity)), 0.82, 0.78, 0.68)
    end
    if listing.source == "CHAT" then summary:AddLine("Chat offer from " .. (listing.channel or "World") .. " (expires automatically)", 1.00, 0.72, 0.20) end
    summary:AddLine("Shift-click with chat open to link the item.", 0.35, 1.00, 0.35)
    summary:AddLine("Synced through the HC TradeBoard network.", 0.55, 0.55, 0.55)
    summary:Show()

    GameTooltip:SetOwner(row, "ANCHOR_NONE")
    GameTooltip:ClearLines()
    local hyperlink = self:GetListingTooltipHyperlink(listing)
    if hyperlink then
        GameTooltip:SetHyperlink(hyperlink)
    else
        GameTooltip:SetText("Item details unavailable", 0.75, 0.72, 0.64)
    end
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMLEFT", summary, "TOPLEFT", 0, 4)
    GameTooltip:Show()

    local width = summary:GetWidth()
    if GameTooltip:GetWidth() > width then
        width = GameTooltip:GetWidth()
    end
    summary:SetWidth(width)
    GameTooltip:SetWidth(width)
end

function TB:HideBrowseListingTooltips()
    GameTooltip:Hide()
    if self.Frames.listingSummaryTooltip then
        self.Frames.listingSummaryTooltip:Hide()
    end
end

function TB:CreateResultsPanel(parent)
    local panel = CreatePanel(parent, 998, 488)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 150, -50)
    panel:EnableMouseWheel(1)
    panel:SetScript("OnMouseWheel", function()
        local filtered = TB:GetFilteredListings()
        local maxOffset = table.getn(filtered) - TB.MAX_VISIBLE_ROWS
        if maxOffset < 0 then
            maxOffset = 0
        end

        if arg1 > 0 then
            TB.State.browseOffset = TB.State.browseOffset - 1
        else
            TB.State.browseOffset = TB.State.browseOffset + 1
        end

        if TB.State.browseOffset < 0 then
            TB.State.browseOffset = 0
        end
        if TB.State.browseOffset > maxOffset then
            TB.State.browseOffset = maxOffset
        end
        TB:UpdateBrowseRows(filtered)
    end)
    self.Frames.resultsPanel = panel
    local scrollbar = CreateClassicScrollbar(panel, 446, function(value)
        TB.State.browseOffset = value
        TB:UpdateBrowseRows(TB:GetFilteredListings())
    end)
    scrollbar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -36)
    self.Frames.browseScrollbar = scrollbar

    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -5)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -28, -5)
    header:SetHeight(28)
    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetTexture(0.14, 0.12, 0.075, 0.95)
    headerBg:SetAllPoints(header)

    local columns = {
        { text = "Item", x = 8, width = 210, sortKey = "name" },
        { text = "Qty", x = 222, width = 34, sortKey = "quantity" },
        { text = "Req", x = 260, width = 34, sortKey = "requiredLevel" },
        { text = "iLvl", x = 298, width = 34, sortKey = "itemLevel" },
        { text = "Total Price", x = 338, width = 86, sortKey = "totalPrice" },
        { text = "Seller", x = 432, width = 90, sortKey = "trader" },
        { text = "Guild", x = 558, width = 112, sortKey = "guild" },
        { text = "Lv", x = 674, width = 30, sortKey = "traderLevel" },
        { text = "Class", x = 708, width = 70, sortKey = "class" },
        { text = "Status", x = 782, width = 88, sortKey = "online" },
        { text = "Source", x = 874, width = 66, sortKey = "source" },
    }

    local dividerIndex
    for dividerIndex = 2, table.getn(columns) do
        local divider = panel:CreateTexture(nil, "OVERLAY")
        divider:SetTexture(0.46, 0.36, 0.17, 0.18)
        divider:SetWidth(1)
        divider:SetPoint("TOPLEFT", panel, "TOPLEFT", columns[dividerIndex].x + 2, -6)
        divider:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", columns[dividerIndex].x + 2, 9)
    end

    self.Frames.sortHeaders = {}
    local i
    for i = 1, table.getn(columns) do
        local column = columns[i]
        local sortKey = column.sortKey
        local headerText = column.text
        local sortButton = CreateFrame("Button", nil, header)
        sortButton:SetPoint("TOPLEFT", header, "TOPLEFT", column.x, 0)
        sortButton:SetWidth(column.width)
        sortButton:SetHeight(28)

        local hover = sortButton:CreateTexture(nil, "HIGHLIGHT")
        hover:SetTexture(0.90, 0.64, 0.18, 0.16)
        hover:SetAllPoints(sortButton)

        local label = CreateText(sortButton, headerText, "GameFontNormalSmall", 0.92, 0.78, 0.45)
        label:SetPoint("LEFT", sortButton, "LEFT", 0, 0)
        label:SetWidth(column.width - 13)
        label:SetJustifyH("LEFT")

        local arrow = sortButton:CreateTexture(nil, "ARTWORK")
        arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
        arrow:SetWidth(9)
        arrow:SetHeight(8)
        arrow:SetPoint("RIGHT", sortButton, "RIGHT", -2, -1)
        arrow:Hide()

        sortButton.label = label
        sortButton.arrow = arrow
        sortButton.sortKey = sortKey
        sortButton:SetScript("OnClick", function()
            TB:SetSort(sortKey)
            TB:UpdateBrowse()
            local direction = TB.State.sortAscending and "ascending" or "descending"
            TB:SetStatus("Sorted by " .. headerText .. " (" .. direction .. ").")
        end)
        sortButton:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:SetText("Sort by " .. headerText, 1.00, 0.82, 0.24)
            GameTooltip:AddLine("Click again to reverse the order.", 0.75, 0.72, 0.64)
            GameTooltip:Show()
        end)
        sortButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        self.Frames.sortHeaders[sortKey] = sortButton
    end

    self.Frames.resultRows = {}
    for i = 1, self.MAX_VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, panel)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -35 - ((i - 1) * 44))
        row:SetWidth(964)
        row:SetHeight(42)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        if math.mod(i, 2) == 0 then
            bg:SetTexture(0.055, 0.055, 0.050, 0.90)
        else
            bg:SetTexture(0.025, 0.025, 0.025, 0.90)
        end
        bg:SetAllPoints(row)

        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetTexture(0.75, 0.48, 0.12, 0.20)
        selected:SetAllPoints(row)
        selected:Hide()
        row.selected = selected

        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture(0.75, 0.48, 0.12, 0.12)
        highlight:SetAllPoints(row)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(27)
        icon:SetHeight(27)
        icon:SetPoint("LEFT", row, "LEFT", 3, 0)
        row.icon = icon

        local name = CreateText(row, "", "GameFontHighlightSmall")
        name:SetPoint("LEFT", row, "LEFT", 34, 0)
        name:SetWidth(182)
        name:SetJustifyH("LEFT")
        row.itemName = name

        local function RowText(x, width, justify)
            local text = CreateText(row, "", "GameFontHighlightSmall", 0.86, 0.82, 0.74)
            text:SetPoint("LEFT", row, "LEFT", x, 0)
            text:SetWidth(width)
            text:SetJustifyH(justify or "LEFT")
            return text
        end

        row.quantity = RowText(222, 34, "CENTER")
        row.required = RowText(260, 34, "CENTER")
        row.itemLevel = RowText(298, 34, "CENTER")
        row.price = RowText(338, 86, "RIGHT")
        row.trader = RowText(432, 88, "LEFT")
        row.guild = RowText(558, 110, "LEFT")
        row.traderLevel = RowText(674, 30, "CENTER")
        row.class = RowText(708, 70, "LEFT")
        row.status = RowText(782, 88, "LEFT")
        row.source = RowText(874, 66, "LEFT")

        local who = CreateButton(row, "?", 28, 26)
        who:SetPoint("LEFT", row, "LEFT", 526, 0)
        who:SetFrameLevel(row:GetFrameLevel() + 3)
        who:SetScript("OnClick", function() if this.trader then TB:RequestManualWho(this.trader) end end)
        who:SetScript("OnEnter", function() GameTooltip:SetOwner(this, "ANCHOR_TOP"); GameTooltip:SetText("Who lookup"); GameTooltip:AddLine("Click to run /who " .. (this.trader or ""), 1, 1, 1); GameTooltip:Show() end)
        who:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.whoButton = who

        row:SetScript("OnClick", function()
            if this.listing then
                if TB:TryInsertItemLink(this.listing) then
                    return
                end
                TB.Frames.searchField:ClearFocus()
                TB.Frames.minLevel:ClearFocus()
                TB.Frames.maxLevel:ClearFocus()
                TB.State.selectedListing = this.listing
                TB:UpdateBrowse()
                TB:SetStatus("Selected " .. this.listing.name .. " from " .. this.listing.trader .. ".")
            end
        end)
        row:SetScript("OnEnter", function()
            if this.listing then
                TB:ShowBrowseListingTooltips(this, this.listing)
            end
        end)
        row:SetScript("OnLeave", function()
            TB:HideBrowseListingTooltips()
        end)

        self.Frames.resultRows[i] = row
    end

    local scrollHint = CreateText(panel, "SCROLL: use mouse wheel over this list", "GameFontNormalSmall", 1.00, 0.72, 0.20)
    scrollHint:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 5)
end

function TB:CreateMyListingsPane(parent)
    local pane = CreateFrame("Frame", nil, parent)
    pane:SetAllPoints(parent)
    pane:Hide()
    self.Frames.myListingsPane = pane

    local title = CreateText(pane, "My Listings", "GameFontNormalLarge", 1.00, 0.78, 0.20)
    title:SetPoint("TOPLEFT", pane, "TOPLEFT", 8, -8)
    local subtitle = CreateText(pane, "Select a real bag item and advertise the total stack price to connected HC TradeBoard peers.", "GameFontHighlightSmall", 0.66, 0.63, 0.56)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

    local editor = CreatePanel(pane, 280, 488)
    editor:SetPoint("TOPLEFT", pane, "TOPLEFT", 8, -58)
    CreateHeading(editor, "Create a Sale Listing")

    local itemSlot = CreateFrame("Button", nil, editor)
    itemSlot:SetWidth(62)
    itemSlot:SetHeight(62)
    itemSlot:SetPoint("TOPLEFT", editor, "TOPLEFT", 18, -45)
    itemSlot:SetBackdrop(PANEL_BACKDROP)
    itemSlot:SetBackdropColor(0.02, 0.02, 0.02, 1)
    itemSlot:SetBackdropBorderColor(0.72, 0.52, 0.16, 1)
    itemSlot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local slotIcon = itemSlot:CreateTexture(nil, "ARTWORK")
    slotIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    slotIcon:SetWidth(48)
    slotIcon:SetHeight(48)
    slotIcon:SetPoint("CENTER", itemSlot, "CENTER", 0, 0)
    itemSlot.icon = slotIcon
    local slotHighlight = itemSlot:CreateTexture(nil, "HIGHLIGHT")
    slotHighlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    slotHighlight:SetBlendMode("ADD")
    slotHighlight:SetAllPoints(itemSlot)
    itemSlot:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            TB:CancelBagPick()
        else
            TB:BeginBagPick()
        end
    end)
    itemSlot:SetScript("OnReceiveDrag", function()
        local candidate = TB.dragListingCandidate
        if CursorHasItem() then
            ClearCursor()
        end
        if candidate then
            TB:ApplyBagListingCandidate(candidate)
        else
            TB:SetStatus("Drag an item from a normal bag slot onto this box.")
        end
    end)
    itemSlot:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sale Item", 1.00, 0.82, 0.24)
        GameTooltip:AddLine("Shift-left-click a bag item or drag it here.", 0.88, 0.84, 0.75)
        GameTooltip:AddLine("Click this box to arm one normal bag click.", 0.65, 0.72, 0.90)
        GameTooltip:Show()
    end)
    itemSlot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.Frames.listingItemSlot = itemSlot

    local itemName = CreateText(editor, "No item selected", "GameFontNormal", 0.72, 0.68, 0.60)
    itemName:SetPoint("TOPLEFT", editor, "TOPLEFT", 92, -51)
    itemName:SetWidth(165)
    itemName:SetJustifyH("LEFT")
    self.Frames.listingItemName = itemName

    local itemHelp = CreateText(editor, "Shift-click a bag item or drag it onto this slot.", "GameFontHighlightSmall", 0.62, 0.60, 0.54)
    itemHelp:SetPoint("TOPLEFT", itemName, "BOTTOMLEFT", 0, -7)
    itemHelp:SetWidth(165)
    itemHelp:SetJustifyH("LEFT")
    self.Frames.listingItemHelp = itemHelp

    local choose = CreateButton(editor, "Pick Bag Item", 142, 30)
    choose:SetPoint("TOPLEFT", editor, "TOPLEFT", 18, -123)
    choose:SetScript("OnClick", function()
        TB:BeginBagPick()
    end)

    local clearItem = CreateButton(editor, "Clear", 78, 30)
    clearItem:SetPoint("LEFT", choose, "RIGHT", 8, 0)
    clearItem:SetScript("OnClick", function()
        TB.PendingListing = nil
        TB.bagPickMode = nil
        TB:UpdateListingEditor()
        TB:SetStatus("Listing item cleared.")
    end)

    local qtyLabel = CreateText(editor, "Quantity", "GameFontNormal", 0.92, 0.78, 0.45)
    qtyLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 18, -176)
    local qtyEdit = CreateEditBox(editor, 82, 30, "")
    qtyEdit:SetPoint("TOPLEFT", editor, "TOPLEFT", 18, -197)
    qtyEdit:SetJustifyH("CENTER")
    qtyEdit:SetMaxLetters(4)
    self.Frames.listingQuantity = qtyEdit
    local qtyMax = CreateText(editor, "", "GameFontHighlightSmall", 0.66, 0.63, 0.56)
    qtyMax:SetPoint("LEFT", qtyEdit, "RIGHT", 8, 0)
    self.Frames.listingQuantityMax = qtyMax

    local priceLabel = CreateText(editor, "Total Price", "GameFontNormal", 0.92, 0.78, 0.45)
    priceLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 18, -251)
    local coinLabels = { "Gold", "Silver", "Copper" }
    local coinX = { 18, 106, 194 }
    self.Frames.listingPriceEdits = {}
    local i
    for i = 1, 3 do
        local coinLabel = CreateText(editor, coinLabels[i], "GameFontHighlightSmall", 0.72, 0.68, 0.60)
        coinLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", coinX[i], -274)
        local coinEdit = CreateEditBox(editor, 68, 30, "")
        coinEdit:SetPoint("TOPLEFT", editor, "TOPLEFT", coinX[i], -294)
        coinEdit:SetJustifyH("CENTER")
        coinEdit:SetMaxLetters(i == 1 and 6 or 2)
        self.Frames.listingPriceEdits[i] = coinEdit
    end

    local post = CreateButton(editor, "Post Sale Listing", 194, 36)
    post:SetPoint("BOTTOM", editor, "BOTTOM", 0, 22)
    post:SetScript("OnClick", function()
        local gold = tonumber(TB.Frames.listingPriceEdits[1]:GetText()) or 0
        local silver = tonumber(TB.Frames.listingPriceEdits[2]:GetText()) or 0
        local copper = tonumber(TB.Frames.listingPriceEdits[3]:GetText()) or 0
        if silver > 99 or copper > 99 then
            TB:SetStatus("Silver and copper must each be between 0 and 99.")
            return
        end
        TB:CreateMyListing(TB.Frames.listingQuantity:GetText(), (gold * 10000) + (silver * 100) + copper)
    end)

    local listPanel = CreatePanel(pane, 852, 488)
    listPanel:SetPoint("TOPLEFT", pane, "TOPLEFT", 296, -58)
    listPanel:EnableMouseWheel(1)
    local function ScrollMyListings()
        local maxOffset = table.getn(TB.MyListings) - TB.MAX_MY_LISTING_ROWS
        if maxOffset < 0 then
            maxOffset = 0
        end
        if arg1 > 0 then
            TB.State.myListingOffset = (TB.State.myListingOffset or 0) - 1
        else
            TB.State.myListingOffset = (TB.State.myListingOffset or 0) + 1
        end
        if TB.State.myListingOffset < 0 then
            TB.State.myListingOffset = 0
        elseif TB.State.myListingOffset > maxOffset then
            TB.State.myListingOffset = maxOffset
        end
        TB:UpdateMyListings()
    end
    listPanel:SetScript("OnMouseWheel", ScrollMyListings)
    CreateHeading(listPanel, "My Active Listings")
    local myHeader = CreateFrame("Frame", nil, listPanel)
    myHeader:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, -31); myHeader:SetWidth(816); myHeader:SetHeight(26)
    local myHeaderBg = myHeader:CreateTexture(nil, "BACKGROUND"); myHeaderBg:SetTexture(0.14, 0.12, 0.075, 0.95); myHeaderBg:SetAllPoints(myHeader)
    local myHeaders = { { "Item", 50, 300 }, { "Qty", 370, 50 }, { "Total Price", 430, 110 }, { "Shared", 570, 90 }, { "Status", 690, 110 } }
    for i = 1, table.getn(myHeaders) do
        local headerLabel = CreateText(myHeader, myHeaders[i][1], "GameFontNormalSmall", 0.92, 0.78, 0.45)
        headerLabel:SetPoint("LEFT", myHeader, "LEFT", myHeaders[i][2], 0); headerLabel:SetWidth(myHeaders[i][3]); headerLabel:SetJustifyH("LEFT")
    end
    local myScrollbar = CreateClassicScrollbar(listPanel, 444, function(value) TB.State.myListingOffset = value; TB:UpdateMyListings() end)
    myScrollbar:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -3, -35)
    self.Frames.myListingScrollbar = myScrollbar
    self.Frames.myListingRows = {}
    for i = 1, self.MAX_MY_LISTING_ROWS do
        local row = CreateFrame("Button", nil, listPanel)
        row:SetWidth(816)
        row:SetHeight(38)
        row:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 10, -60 - ((i - 1) * 41))
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(0.035, 0.035, 0.032, 0.92)
        bg:SetAllPoints(row)
        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetTexture(0.75, 0.48, 0.12, 0.20)
        selected:SetAllPoints(row)
        selected:Hide()
        row.selected = selected
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetTexture(0.72, 0.46, 0.12, 0.12)
        hover:SetAllPoints(row)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(34)
        icon:SetHeight(34)
        icon:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.icon = icon
        local name = CreateText(row, "", "GameFontNormal")
        name:SetPoint("LEFT", row, "LEFT", 50, 0)
        name:SetWidth(310)
        name:SetJustifyH("LEFT")
        row.itemName = name
        local quantity = CreateText(row, "", "GameFontHighlightSmall", 0.76, 0.72, 0.65)
        quantity:SetPoint("LEFT", row, "LEFT", 370, 0); quantity:SetWidth(50); row.quantity = quantity
        local price = CreateText(row, "", "GameFontHighlightSmall", 0.90, 0.82, 0.62)
        price:SetPoint("LEFT", row, "LEFT", 430, 0); price:SetWidth(120); row.price = price
        local shared = CreateText(row, "Peer", "GameFontHighlightSmall", 0.45, 0.80, 1.00)
        shared:SetPoint("LEFT", row, "LEFT", 570, 0); shared:SetWidth(90); row.shared = shared
        local active = CreateText(row, "Broadcasting", "GameFontHighlightSmall", 0.30, 1.00, 0.30)
        active:SetPoint("LEFT", row, "LEFT", 690, 0)
        row.active = active
        row:SetScript("OnClick", function()
            if this.listing and TB:TryInsertItemLink(this.listing) then
                return
            end
            if this.listing then
                TB.State.selectedMyListing = this.listing
                TB:UpdateMyListings()
                TB:SetStatus("Selected your " .. this.listing.name .. " listing.")
            end
        end)
        row:EnableMouseWheel(1)
        row:SetScript("OnMouseWheel", ScrollMyListings)
        self.Frames.myListingRows[i] = row
    end

    local count = CreateText(listPanel, "0 active listings", "GameFontHighlightSmall", 0.72, 0.68, 0.60)
    count:SetPoint("BOTTOMLEFT", listPanel, "BOTTOMLEFT", 14, 14)
    self.Frames.myListingCount = count

    local remove = CreateButton(listPanel, "Remove Selected", 150, 32)
    remove:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -10, 10)
    remove:SetScript("OnClick", function()
        if TB.State.selectedMyListing then
            TB:DeleteMyListing(TB.State.selectedMyListing.id)
        else
            TB:SetStatus("Select one of your listings before removing it.")
        end
    end)

    self:UpdateListingEditor()
    self:UpdateMyListings()
end

function TB:UpdateListingEditor()
    local pending = self.PendingListing
    if pending then
        local info = self.Quality[pending.quality] or self.Quality[1]
        self.Frames.listingItemSlot.icon:SetTexture(pending.texture)
        self.Frames.listingItemName:SetText(pending.name)
        self.Frames.listingItemName:SetTextColor(info.r, info.g, info.b)
        if self.bagPickMode then
            self.Frames.listingItemHelp:SetText("Choose the replacement item with one normal bag click.")
        else
            self.Frames.listingItemHelp:SetText("Bag " .. pending.bag .. ", slot " .. pending.slot .. " / Shift-click or drag to replace")
        end
        self.Frames.listingQuantityMax:SetText("Available: " .. pending.availableQuantity)
        if self.editorPendingListing ~= pending then
            self.Frames.listingQuantity:SetText(tostring(pending.availableQuantity))
            self.Frames.listingPriceEdits[1]:SetText("")
            self.Frames.listingPriceEdits[2]:SetText("")
            self.Frames.listingPriceEdits[3]:SetText("")
            self.editorPendingListing = pending
        end
    else
        self.Frames.listingItemSlot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        self.Frames.listingItemName:SetText(self.bagPickMode and "Choose a bag item..." or "No item selected")
        self.Frames.listingItemName:SetTextColor(0.72, 0.68, 0.60)
        self.Frames.listingItemHelp:SetText(self.bagPickMode and "Your next normal bag-item click will select it." or "Shift-click a bag item or drag it onto this slot.")
        self.Frames.listingQuantityMax:SetText("")
        self.Frames.listingQuantity:SetText("")
        self.Frames.listingPriceEdits[1]:SetText("")
        self.Frames.listingPriceEdits[2]:SetText("")
        self.Frames.listingPriceEdits[3]:SetText("")
        self.editorPendingListing = nil
    end
end

function TB:UpdateMyListings()
    if not self.Frames.myListingRows then
        return
    end
    local total = table.getn(self.MyListings)
    local visibleRows = table.getn(self.Frames.myListingRows)
    local maxOffset = total - visibleRows
    if maxOffset < 0 then
        maxOffset = 0
    end
    local offset = self.State.myListingOffset or 0
    if offset < 0 then
        offset = 0
    elseif offset > maxOffset then
        offset = maxOffset
    end
    self.State.myListingOffset = offset

    local i
    for i = 1, table.getn(self.Frames.myListingRows) do
        local row = self.Frames.myListingRows[i]
        local listing = self.MyListings[offset + i]
        if listing then
            local info = self.Quality[listing.quality] or self.Quality[1]
            row.listing = listing
            row.icon:SetTexture(listing.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.itemName:SetText(listing.name)
            row.itemName:SetTextColor(info.r, info.g, info.b)
            row.quantity:SetText(tostring(listing.quantity))
            row.price:SetText(self:FormatMoney(listing.totalPrice or 0))
            if self.Network and self.Network.state == "CONNECTED" then
                row.active:SetText("Broadcasting")
                row.active:SetTextColor(0.30, 1.00, 0.30)
            elseif self.Network and (self.Network.state == "PROBING" or self.Network.state == "JOINING") then
                row.active:SetText("Queued")
                row.active:SetTextColor(1.00, 0.78, 0.25)
            elseif self.Network and self.Network.state == "ALONE" then
                row.active:SetText("No peer yet")
                row.active:SetTextColor(1.00, 0.78, 0.25)
            else
                row.active:SetText("Local only")
                row.active:SetTextColor(0.70, 0.45, 0.35)
            end
            if self.State.selectedMyListing == listing then
                row.selected:Show()
            else
                row.selected:Hide()
            end
            row:Show()
        else
            row.listing = nil
            row:Hide()
        end
    end
    local countText = total .. (total == 1 and " active listing" or " active listings")
    if maxOffset > 0 then
        countText = countText .. " - SCROLL WITH MOUSE WHEEL"
    end
    self.Frames.myListingCount:SetText(countText)
    if self.Frames.myListingScrollbar then self.Frames.myListingScrollbar:SetRange(offset, maxOffset) end
end

function TB:CreateTradeChainsPane(parent)
    local pane = CreateFrame("Frame", nil, parent)
    pane:SetAllPoints(parent)
    pane:Hide()
    self.Frames.tradeChainsPane = pane

    local intro = CreateText(pane, "Trade chains bridge goods through legal 5-level handoffs.", "GameFontNormal", 0.90, 0.82, 0.66)
    intro:SetPoint("TOPLEFT", pane, "TOPLEFT", 8, -8)

    local listPanel = CreatePanel(pane, 220, 488)
    listPanel:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -42)
    listPanel:EnableMouseWheel(1)
    listPanel:SetScript("OnMouseWheel", function()
        local maxOffset = table.getn(TB.Chains) - 9
        if maxOffset < 0 then
            maxOffset = 0
        end
        if arg1 > 0 then
            TB.State.chainOffset = TB.State.chainOffset - 1
        else
            TB.State.chainOffset = TB.State.chainOffset + 1
        end
        if TB.State.chainOffset < 0 then
            TB.State.chainOffset = 0
        elseif TB.State.chainOffset > maxOffset then
            TB.State.chainOffset = maxOffset
        end
        TB:UpdateTradeChains()
    end)
    CreateHeading(listPanel, "Listed Chains")

    self.Frames.chainButtons = {}
    local i
    local chainScrollbar = CreateClassicScrollbar(listPanel, 440, function(value) TB.State.chainOffset = value; TB:UpdateTradeChains() end)
    chainScrollbar:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -3, -38)
    self.Frames.chainScrollbar = chainScrollbar
    for i = 1, 9 do
        local button = CreateButton(listPanel, "", 184, 34)
        button:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 11, -40 - ((i - 1) * 39))
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button, "LEFT", 10, 0)
        button.label:SetWidth(164)
        button.label:SetJustifyH("LEFT")
        button:SetScript("OnClick", function()
            if this.chainIndex and TB.Chains[this.chainIndex] then
                TB.State.selectedChain = this.chainIndex
                TB:UpdateTradeChains()
            end
        end)
        self.Frames.chainButtons[i] = button
        button:Hide()
    end

    local deleteChain = CreateButton(listPanel, "Delete My Chain", 184, 30)
    deleteChain:SetPoint("BOTTOMLEFT", listPanel, "BOTTOMLEFT", 11, 10)
    deleteChain:SetScript("OnClick", function()
        TB:DeleteOwnChain()
    end)

    local scrollChains = CreateText(listPanel, "SCROLL: mouse wheel for more chains", "GameFontNormalSmall", 1.00, 0.72, 0.20)
    scrollChains:SetPoint("BOTTOM", deleteChain, "TOP", 0, 5)

    local detail = CreatePanel(pane, 918, 488)
    detail:SetPoint("TOPLEFT", pane, "TOPLEFT", 230, -42)
    self.Frames.chainDetail = detail

    local chainTitle = CreateText(detail, "", "GameFontNormalLarge", 1.00, 0.78, 0.20)
    chainTitle:SetPoint("TOP", detail, "TOP", 0, -15)
    self.Frames.chainTitle = chainTitle
    local chainWho = CreateButton(detail, "?", 28, 26)
    chainWho:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -12, -9)
    chainWho:SetScript("OnClick", function() if this.trader then TB:RequestManualWho(this.trader) end end)
    chainWho:SetScript("OnEnter", function() GameTooltip:SetOwner(this, "ANCHOR_TOP"); GameTooltip:SetText("Who lookup"); GameTooltip:AddLine("Click to run /who " .. (this.trader or ""), 1, 1, 1); GameTooltip:Show() end)
    chainWho:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.Frames.chainWhoButton = chainWho

    local positions = {
        { 20, -70 }, { 240, -70 }, { 460, -70 }, { 680, -70 },
        { 680, -190 }, { 460, -190 }, { 240, -190 }, { 20, -190 },
        { 20, -310 }, { 240, -310 }, { 460, -310 }, { 680, -310 },
    }

    self.Frames.chainNodes = {}
    for i = 1, 12 do
        local node = CreatePanel(detail, 190, 66)
        node:SetPoint("TOPLEFT", detail, "TOPLEFT", positions[i][1], positions[i][2])
        node:SetBackdropColor(0.045, 0.045, 0.042, 1)

        local level = CreateText(node, "", "GameFontNormal", 1.00, 0.78, 0.20)
        level:SetPoint("TOPLEFT", node, "TOPLEFT", 10, -8)
        node.level = level

        local name = CreateText(node, "", "GameFontHighlightSmall", 0.88, 0.84, 0.76)
        name:SetPoint("BOTTOMLEFT", node, "BOTTOMLEFT", 10, 8)
        name:SetWidth(105)
        node.memberName = name
        local memberClass = CreateText(node, "", "GameFontHighlightSmall", 0.55, 0.75, 1.00)
        memberClass:SetPoint("BOTTOMRIGHT", node, "BOTTOMRIGHT", -22, 8)
        memberClass:SetWidth(58); memberClass:SetJustifyH("RIGHT")
        node.memberClass = memberClass

        local dot = node:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(1, 1, 1, 1)
        dot:SetWidth(10)
        dot:SetHeight(10)
        dot:SetPoint("RIGHT", node, "RIGHT", -10, 0)
        node.dot = dot

        self.Frames.chainNodes[i] = node
    end

    local function Line(x, y, width, height)
        local line = detail:CreateTexture(nil, "BACKGROUND")
        line:SetTexture(GOLD_R, GOLD_G, GOLD_B, 0.70)
        line:SetPoint("TOPLEFT", detail, "TOPLEFT", x, y)
        line:SetWidth(width)
        line:SetHeight(height)
    end

    Line(210, -102, 30, 3); Line(430, -102, 30, 3); Line(650, -102, 30, 3)
    Line(774, -136, 3, 54)
    Line(650, -222, 30, 3); Line(430, -222, 30, 3); Line(210, -222, 30, 3)
    Line(114, -256, 3, 54)
    Line(210, -342, 30, 3); Line(430, -342, 30, 3); Line(650, -342, 30, 3)

    local onlinePanel = CreatePanel(pane, 170, 42)
    onlinePanel:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 230, 0)
    local onlineText = CreateText(onlinePanel, "", "GameFontNormal", 0.35, 1.00, 0.35)
    onlineText:SetPoint("CENTER", onlinePanel, "CENTER", 0, 0)
    self.Frames.chainOnline = onlineText

    local fullPanel = CreatePanel(pane, 170, 42)
    fullPanel:SetPoint("LEFT", onlinePanel, "RIGHT", 8, 0)
    local fullText = CreateText(fullPanel, "Full 5-60 chain", "GameFontNormal", 0.95, 0.82, 0.42)
    fullText:SetPoint("CENTER", fullPanel, "CENTER", 0, 0)
    self.Frames.chainFilled = fullText

    local factionPanel = CreatePanel(pane, 170, 42)
    factionPanel:SetPoint("LEFT", fullPanel, "RIGHT", 8, 0)
    local factionText = CreateText(factionPanel, "", "GameFontNormal", 0.95, 0.82, 0.42)
    factionText:SetPoint("CENTER", factionPanel, "CENTER", 0, 0)
    self.Frames.chainFaction = factionText

    local listChain = CreateButton(pane, "List / Edit My Chain", 158, 42)
    listChain:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    listChain:SetScript("OnClick", function()
        TB:OpenChainEditor()
    end)

    local delivery = CreateButton(pane, "Delivery Desk", 138, 42)
    delivery:SetPoint("RIGHT", listChain, "LEFT", -8, 0)
    delivery:SetScript("OnClick", function() TB:OpenDeliveryDesk() end)

    self:CreateChainEditor(pane)
    self:CreateDeliveryDesk(pane)
end

function TB:CreateDeliveryDesk(parent)
    local desk = CreatePanel(parent, 1040, 520)
    desk:SetPoint("CENTER", parent, "CENTER", 0, 0); desk:SetFrameLevel(parent:GetFrameLevel() + 24); desk:EnableMouse(1); desk:Hide()
    desk:EnableMouseWheel(1)
    desk:SetScript("OnMouseWheel", function()
        TB.State.chainOrderOffset = math.max(0, (TB.State.chainOrderOffset or 0) + (arg1 > 0 and -1 or 1))
        TB:UpdateDeliveryDesk()
    end)
    self.Frames.deliveryDesk = desk
    local title = CreateText(desk, "Trade Chain Delivery Desk", "GameFontNormalLarge", 1.00, 0.78, 0.20); title:SetPoint("TOP", desk, "TOP", 0, -14)
    local close = CreateButton(desk, "X", 30, 26); close:SetPoint("TOPRIGHT", desk, "TOPRIGHT", -10, -9); close:SetScript("OnClick", function() desk:Hide() end)
    local help = CreateText(desk, "Peer-shared orders record the item, who hands it off, who receives it, and delivery status.", "GameFontHighlightSmall", 0.72, 0.68, 0.58)
    help:SetPoint("TOP", title, "BOTTOM", 0, -5)
    local labels = { { "Item / link", 18, 340 }, { "Qty", 368, 52 }, { "From", 430, 150 }, { "To", 590, 150 }, { "Note", 750, 190 } }
    self.Frames.orderInputs = {}
    local i
    for i = 1, table.getn(labels) do
        local spec = labels[i]
        local label = CreateText(desk, spec[1], "GameFontNormalSmall", 0.90, 0.74, 0.30); label:SetPoint("TOPLEFT", desk, "TOPLEFT", spec[2], -60)
        local edit = CreateEditBox(desk, spec[3], 28, ""); edit:SetPoint("TOPLEFT", desk, "TOPLEFT", spec[2], -78); edit:SetMaxLetters(i == 5 and 70 or 180)
        self.Frames.orderInputs[i] = edit
    end
    self.Frames.orderInputs[2]:SetNumeric(1)
    local publish = CreateButton(desk, "Publish order", 138, 30); publish:SetPoint("TOPRIGHT", desk, "TOPRIGHT", -18, -112)
    publish:SetScript("OnClick", function()
        local chain = TB.State.selectedChain and TB.Chains[TB.State.selectedChain]
        local order, reason = TB:CreateChainOrder(chain and chain.owner or UnitName("player"), TB.Frames.orderInputs[1]:GetText(), TB.Frames.orderInputs[2]:GetText(),
            TB.Frames.orderInputs[3]:GetText(), TB.Frames.orderInputs[4]:GetText(), TB.Frames.orderInputs[5]:GetText())
        if order then
            TB.Frames.orderInputs[1]:SetText(""); TB.Frames.orderInputs[2]:SetText(""); TB.Frames.orderInputs[5]:SetText("")
            TB:SetStatus("Delivery order published to peers.")
        else TB:SetStatus(reason) end
    end)
    local volunteer = CreateCheckButton(desk, "Advertise me as a chain spot (my level +/-5)", 390, nil, function(value) TB:SetChainVolunteer(value) end)
    volunteer:SetPoint("TOPLEFT", desk, "TOPLEFT", 18, -119); self.Frames.deliveryVolunteer = volunteer
    local volunteerCount = CreateText(desk, "", "GameFontHighlightSmall", 0.55, 0.90, 0.65); volunteerCount:SetPoint("LEFT", volunteer, "RIGHT", 12, 0); self.Frames.deliveryVolunteerCount = volunteerCount
    local header = CreateText(desk, "STATUS          ITEM / QTY                                      FROM  >  TO                         CUSTOMER", "GameFontNormalSmall", 0.90, 0.74, 0.30)
    header:SetPoint("TOPLEFT", desk, "TOPLEFT", 18, -161)
    self.Frames.orderRows = {}
    local orderScrollbar = CreateClassicScrollbar(desk, 300, function(value) TB.State.chainOrderOffset = value; TB:UpdateDeliveryDesk() end)
    orderScrollbar:SetPoint("TOPRIGHT", desk, "TOPRIGHT", -4, -181); self.Frames.orderScrollbar = orderScrollbar
    for i = 1, 7 do
        local row = CreatePanel(desk, 1004, 40); row:SetPoint("TOPLEFT", desk, "TOPLEFT", 18, -181 - ((i - 1) * 44))
        row.status = CreateText(row, "", "GameFontNormalSmall", 0.55, 1.00, 0.55); row.status:SetPoint("LEFT", row, "LEFT", 8, 0); row.status:SetWidth(90); row.status:SetJustifyH("LEFT")
        row.item = CreateText(row, "", "GameFontHighlightSmall", 0.92, 0.90, 0.84); row.item:SetPoint("LEFT", row, "LEFT", 105, 0); row.item:SetWidth(320); row.item:SetJustifyH("LEFT")
        row.route = CreateText(row, "", "GameFontHighlightSmall", 0.80, 0.82, 0.88); row.route:SetPoint("LEFT", row, "LEFT", 435, 0); row.route:SetWidth(260); row.route:SetJustifyH("LEFT")
        row.customer = CreateText(row, "", "GameFontHighlightSmall", 0.84, 0.76, 0.62); row.customer:SetPoint("LEFT", row, "LEFT", 700, 0); row.customer:SetWidth(150); row.customer:SetJustifyH("LEFT")
        row.advance = CreateButton(row, "Advance", 125, 27); row.advance:SetPoint("RIGHT", row, "RIGHT", -7, 0)
        row.advance:SetScript("OnClick", function() if this.order then TB:AdvanceChainOrder(this.order) end end)
        self.Frames.orderRows[i] = row
    end
end

function TB:OpenDeliveryDesk()
    self:InitializeFeatureData()
    local chain = self.State.selectedChain and self.Chains[self.State.selectedChain]
    local player = UnitName("player") or ""
    self.Frames.orderInputs[3]:SetText(player)
    self.Frames.orderInputs[4]:SetText(chain and chain.owner or "")
    if self.Frames.chainEditor then self.Frames.chainEditor:Hide() end
    self:UpdateDeliveryDesk(); self.Frames.deliveryDesk:Show()
end

function TB:UpdateDeliveryDesk()
    if not self.Frames.orderRows then return end
    self:InitializeFeatureData()
    local volunteer = self:GetOwnVolunteer()
    self.Frames.deliveryVolunteer:SetCheckedValue(volunteer and volunteer.enabled)
    local volunteers = 0
    local key, entry
    for key, entry in pairs(self.ChainVolunteers) do if entry.enabled then volunteers = volunteers + 1 end end
    self.Frames.deliveryVolunteerCount:SetText(volunteers .. (volunteers == 1 and " available spot" or " available spots"))
    local selected = self.State.selectedChain and self.Chains[self.State.selectedChain]
    local visible = {}
    local i
    for i = table.getn(self.ChainOrders), 1, -1 do
        local order = self.ChainOrders[i]
        if not selected or string.lower(order.chainOwner or "") == string.lower(selected.owner or "") or string.lower(order.customer or "") == string.lower(UnitName("player") or "") then table.insert(visible, order) end
    end
    local maxOffset = math.max(0, table.getn(visible) - table.getn(self.Frames.orderRows))
    if self.State.chainOrderOffset > maxOffset then self.State.chainOrderOffset = maxOffset end
    for i = 1, table.getn(self.Frames.orderRows) do
        local row, order = self.Frames.orderRows[i], visible[(self.State.chainOrderOffset or 0) + i]
        if order then
            row.status:SetText(order.status or "REQUESTED")
            row.item:SetText((order.item or "Unknown") .. " x" .. tostring(order.quantity or 1))
            row.route:SetText((order.fromName or "?") .. "  >  " .. (order.toName ~= "" and order.toName or order.chainOwner or "?"))
            row.customer:SetText(order.customer or "?"); row.advance.order = order
            row.advance.label:SetText(order.status == "DELIVERED" and "Reopen" or (order.status == "PICKED UP" and "Delivered" or "Pick up"))
            if self:CanAdvanceChainOrder(order) then row.advance:Show() else row.advance:Hide() end
            row:Show()
        else row.advance.order = nil; row:Hide() end
    end
    self.Frames.orderScrollbar:SetRange(self.State.chainOrderOffset, maxOffset)
end

function TB:CreateChainEditor(parent)
    local editor = CreatePanel(parent, 660, 450)
    editor:SetPoint("CENTER", parent, "CENTER", 0, 0)
    editor:SetFrameLevel(parent:GetFrameLevel() + 20)
    editor:EnableMouse(1)
    editor:Hide()
    self.Frames.chainEditor = editor

    local title = CreateText(editor, "List My Trade Chain", "GameFontNormalLarge", 1.00, 0.78, 0.20)
    title:SetPoint("TOP", editor, "TOP", 0, -18)
    local help = CreateText(editor, "Add one character for each five-level handoff. Empty slots are allowed.", "GameFontHighlightSmall", 0.72, 0.68, 0.60)
    help:SetPoint("TOP", title, "BOTTOM", 0, -7)

    local nameLabel = CreateText(editor, "Chain name", "GameFontNormalSmall", 0.92, 0.78, 0.45)
    nameLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 24, -67)
    local nameEdit = CreateEditBox(editor, 510, 28, "")
    nameEdit:SetPoint("TOPLEFT", editor, "TOPLEFT", 120, -61)
    nameEdit:SetMaxLetters(32)
    self.Frames.chainNameEdit = nameEdit
    self.Frames.chainMemberEdits = {}

    local i
    for i = 1, 12 do
        local column = 0
        local row = i - 1
        if i > 6 then
            column = 1
            row = i - 7
        end
        local x = 24 + (column * 316)
        local y = -105 - (row * 48)
        local level = i * 5
        local levelLabel = CreateText(editor, "Lv " .. level, "GameFontNormal", 1.00, 0.78, 0.20)
        levelLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", x, y - 7)
        local memberEdit = CreateEditBox(editor, 232, 30, "")
        memberEdit:SetPoint("TOPLEFT", editor, "TOPLEFT", x + 54, y)
        memberEdit:SetMaxLetters(12)
        self.Frames.chainMemberEdits[i] = memberEdit
    end

    local save = CreateButton(editor, "Save Chain", 130, 34)
    save:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -18, 16)
    save:SetScript("OnClick", function()
        TB:SaveChainEditor()
    end)

    local cancel = CreateButton(editor, "Cancel", 100, 34)
    cancel:SetPoint("RIGHT", save, "LEFT", -8, 0)
    cancel:SetScript("OnClick", function()
        TB.Frames.chainEditor:Hide()
        TB:SetStatus("Chain editing cancelled.")
    end)
end

function TB:OpenChainEditor()
    local saved = TradeBoardDB and TradeBoardDB.myChain
    local playerName = UnitName("player") or "My"
    local i
    self.Frames.chainNameEdit:SetText(saved and saved.name or (playerName .. "'s Chain"))
    for i = 1, 12 do
        local memberName = ""
        if saved and saved.members and saved.members[i] then
            memberName = saved.members[i]
        end
        self.Frames.chainMemberEdits[i]:SetText(memberName)
    end

    if not saved then
        local slot = math.floor((self:GetPlayerLevel() + 2) / 5)
        if slot < 1 then
            slot = 1
        elseif slot > 12 then
            slot = 12
        end
        self.Frames.chainMemberEdits[slot]:SetText(playerName)
    end

    if self.Frames.deliveryDesk then self.Frames.deliveryDesk:Hide() end
    self.Frames.chainEditor:Show()
    self.Frames.chainNameEdit:SetFocus()
    self.Frames.chainNameEdit:HighlightText()
    self:SetStatus("Editing your local trade chain.")
end

function TB:SaveChainEditor()
    local chainName = self.Frames.chainNameEdit:GetText() or ""
    if chainName == "" then
        chainName = "My Trade Chain"
    end

    local savedMembers = {}
    local i
    for i = 1, 12 do
        local memberName = self.Frames.chainMemberEdits[i]:GetText() or ""
        savedMembers[i] = memberName
    end

    self:SaveOwnChain(chainName, savedMembers)
    self.Frames.chainEditor:Hide()
    self:UpdateTradeChains()
    self:SetStatus("Saved and announced " .. chainName .. ".")
end

function TB:CreateProfessionsPane(parent)
    local pane = CreateFrame("Frame", nil, parent)
    pane:SetAllPoints(parent)
    pane:Hide()
    self.Frames.professionsPane = pane

    local filterBar = CreatePanel(pane, 1148, 42)
    filterBar:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    local professionSearch = CreateEditBox(filterBar, 280, 28, self.State.professionSearch)
    professionSearch:SetPoint("LEFT", filterBar, "LEFT", 8, 0)
    professionSearch:SetScript("OnTextChanged", function() TB.State.professionSearch = this:GetText() or ""; TB.State.professionOffset = 0; TB:UpdateProfessions() end)
    professionSearch:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    self.Frames.professionSearch = professionSearch
    local sourceChoices = { { "All Sources", "ALL" }, { "Published", "PUBLISHED" }, { "Chat", "CHAT" } }
    self.Frames.professionSourceButtons = {}
    local sourceIndex
    for sourceIndex = 1, 3 do
        local value = sourceChoices[sourceIndex][2]
        local sourceButton = CreateButton(filterBar, sourceChoices[sourceIndex][1], 90, 27)
        sourceButton:SetPoint("LEFT", filterBar, "LEFT", 304 + ((sourceIndex - 1) * 94), 0)
        sourceButton:SetScript("OnClick", function() TB.State.professionSource = value; TB.State.professionOffset = 0; TB:UpdateProfessions() end)
        self.Frames.professionSourceButtons[value] = sourceButton
    end
    local professionOnline = CreateCheckButton(filterBar, "Online", 90, self.State.professionOnlineOnly, function(value) TB.State.professionOnlineOnly = value; TB.State.professionOffset = 0; TB:UpdateProfessions() end)
    professionOnline:SetPoint("LEFT", filterBar, "LEFT", 590, 0)
    self.Frames.professionOnline = professionOnline
    local clearProfession = CreateButton(filterBar, "Clear", 72, 27)
    clearProfession:SetPoint("RIGHT", filterBar, "RIGHT", -8, 0)
    clearProfession:SetScript("OnClick", function() TB.State.professionSearch = ""; TB.State.professionSource = "ALL"; TB.State.professionOnlineOnly = nil; professionSearch:SetText(""); professionOnline:SetCheckedValue(nil); TB:UpdateProfessions() end)

    local filters = CreatePanel(pane, 142, 530)
    filters:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -50)
    CreateHeading(filters, "Profession")
    self.Frames.professionButtons = {}
    local filterNames = { "All Services" }
    local i
    for i = 1, table.getn(self.ProfessionNames) do
        table.insert(filterNames, self.ProfessionNames[i])
    end
    for i = 1, table.getn(filterNames) do
        local professionName = filterNames[i]
        local button = CreateButton(filters, professionName, 126, 27)
        button:SetPoint("TOPLEFT", filters, "TOPLEFT", 8, -34 - ((i - 1) * 31))
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button, "LEFT", 9, 0)
        button.label:SetJustifyH("LEFT")
        button.professionName = professionName
        button:SetScript("OnClick", function()
            TB.State.profession = this.professionName
            TB.State.professionOffset = 0
            TB:UpdateProfessions()
        end)
        self.Frames.professionButtons[professionName] = button
    end

    local results = CreatePanel(pane, 998, 530)
    results:SetPoint("TOPLEFT", pane, "TOPLEFT", 150, -50)
    results:EnableMouseWheel(1)
    results:SetScript("OnMouseWheel", function()
        local filtered = TB:GetFilteredServices()
        local maxOffset = table.getn(filtered) - TB.MAX_PROFESSION_ROWS
        if maxOffset < 0 then
            maxOffset = 0
        end
        if arg1 > 0 then
            TB.State.professionOffset = TB.State.professionOffset - 1
        else
            TB.State.professionOffset = TB.State.professionOffset + 1
        end
        if TB.State.professionOffset < 0 then
            TB.State.professionOffset = 0
        elseif TB.State.professionOffset > maxOffset then
            TB.State.professionOffset = maxOffset
        end
        TB:UpdateProfessionRows(filtered)
    end)

    self.Frames.guildCards = {}
    local rankColors = {
        { 1.00, 0.78, 0.20 },
        { 0.78, 0.78, 0.82 },
        { 0.78, 0.48, 0.24 },
    }
    for i = 1, 3 do
        local card = CreateFrame("Button", nil, results)
        card:SetWidth(310)
        card:SetHeight(48)
        card:SetPoint("TOPLEFT", results, "TOPLEFT", 6 + ((i - 1) * 318), -6)
        card:SetBackdrop(PANEL_BACKDROP)
        card:SetBackdropColor(0.04, 0.04, 0.035, 0.96)
        card:SetBackdropBorderColor(0.38, 0.31, 0.17, 1)
        local selected = card:CreateTexture(nil, "ARTWORK")
        selected:SetTexture(0.78, 0.50, 0.14, 0.18)
        selected:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
        selected:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -4, 4)
        selected:Hide()
        card.selected = selected
        local hover = card:CreateTexture(nil, "HIGHLIGHT")
        hover:SetTexture(0.78, 0.50, 0.14, 0.14)
        hover:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
        hover:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -4, 4)
        local icon = card:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(42)
        icon:SetHeight(42)
        icon:SetPoint("LEFT", card, "LEFT", 8, 0)
        card.icon = icon
        local rank = CreateText(card, "#" .. i, "GameFontNormalSmall", rankColors[i][1], rankColors[i][2], rankColors[i][3])
        rank:SetPoint("TOPLEFT", card, "TOPLEFT", 5, -4)
        local guildName = CreateText(card, "", "GameFontNormal", 1.00, 0.82, 0.24)
        guildName:SetPoint("TOPLEFT", card, "TOPLEFT", 58, -10)
        guildName:SetWidth(235)
        guildName:SetJustifyH("LEFT")
        card.guildLabel = guildName
        local providerCount = CreateText(card, "", "GameFontHighlightSmall", 0.72, 0.68, 0.60)
        providerCount:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 58, 9)
        card.providerCount = providerCount
        card:SetScript("OnClick", function()
            if this.guildName then
                if TB.State.guildFilter == this.guildName then
                    TB.State.guildFilter = nil
                    TB:SetStatus("Showing profession providers from all guilds.")
                else
                    TB.State.guildFilter = this.guildName
                    TB:SetStatus("Showing profession providers from " .. this.guildName .. ". Click its sigil again to clear.")
                end
                TB.State.professionOffset = 0
                TB:UpdateProfessions()
            end
        end)
        card:SetScript("OnEnter", function()
            if this.guildName then
                GameTooltip:SetOwner(this, "ANCHOR_TOP")
                GameTooltip:SetText(this.guildName, 1.00, 0.82, 0.24)
                GameTooltip:AddLine(this.providerTotal .. (this.providerTotal == 1 and " profession provider" or " profession providers"), 0.86, 0.82, 0.74)
                GameTooltip:AddLine("Click to show only this guild. Click again to clear.", 0.35, 1.00, 0.35, 1)
                GameTooltip:Show()
            end
        end)
        card:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        self.Frames.guildCards[i] = card
    end

    local header = CreateFrame("Frame", nil, results)
    header:SetPoint("TOPLEFT", results, "TOPLEFT", 6, -58)
    header:SetPoint("TOPRIGHT", results, "TOPRIGHT", -28, -58)
    header:SetHeight(28)
    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetTexture(0.14, 0.12, 0.075, 0.95)
    headerBg:SetAllPoints(header)
    local headers = {
        { "Service", 8, 96 }, { "Crafter", 108, 84 }, { "Level", 230, 34 },
        { "Class", 268, 70 }, { "Guild", 342, 110 }, { "Skill", 456, 55 },
        { "Service Note", 515, 235 }, { "Source", 754, 65 }, { "Status", 823, 115 },
    }
    for i = 1, table.getn(headers) do
        local label = CreateText(header, headers[i][1], "GameFontNormalSmall", 0.92, 0.78, 0.45)
        label:SetPoint("LEFT", header, "LEFT", headers[i][2], 0)
        label:SetWidth(headers[i][3])
        label:SetJustifyH("LEFT")
    end

    self.Frames.professionRows = {}
    local professionScrollbar = CreateClassicScrollbar(results, 444, function(value) TB.State.professionOffset = value; TB:UpdateProfessionRows(TB:GetFilteredServices()) end)
    professionScrollbar:SetPoint("TOPRIGHT", results, "TOPRIGHT", -3, -78)
    self.Frames.professionScrollbar = professionScrollbar
    for i = 1, self.MAX_PROFESSION_ROWS do
        local row = CreateFrame("Button", nil, results)
        row:SetPoint("TOPLEFT", results, "TOPLEFT", 6, -89 - ((i - 1) * 38))
        row:SetWidth(964)
        row:SetHeight(35)
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(math.mod(i, 2) == 0 and 0.055 or 0.025, math.mod(i, 2) == 0 and 0.055 or 0.025, 0.025, 0.90)
        bg:SetAllPoints(row)
        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetTexture(0.75, 0.48, 0.12, 0.20)
        selected:SetAllPoints(row)
        selected:Hide()
        row.selected = selected
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetTexture(0.75, 0.48, 0.12, 0.12)
        hover:SetAllPoints(row)

        local function ServiceText(x, width, colorR, colorG, colorB)
            local text = CreateText(row, "", "GameFontHighlightSmall", colorR or 0.86, colorG or 0.82, colorB or 0.74)
            text:SetPoint("LEFT", row, "LEFT", x, 0)
            text:SetWidth(width)
            text:SetJustifyH("LEFT")
            return text
        end
        row.profession = ServiceText(8, 96, 1.00, 0.82, 0.24)
        row.crafter = ServiceText(108, 84)
        row.level = ServiceText(230, 34, 0.82, 0.78, 0.70)
        row.class = ServiceText(268, 70)
        row.guild = ServiceText(342, 110, 0.82, 0.72, 0.42)
        row.skill = ServiceText(456, 55)
        row.note = ServiceText(515, 235, 0.76, 0.72, 0.65)
        row.source = ServiceText(754, 65)
        row.status = ServiceText(823, 115, 0.30, 1.00, 0.30)
        local who = CreateButton(row, "?", 28, 26)
        who:SetPoint("LEFT", row, "LEFT", 196, 0)
        who:SetFrameLevel(row:GetFrameLevel() + 3)
        who:SetScript("OnClick", function() if this.trader then TB:RequestManualWho(this.trader) end end)
        who:SetScript("OnEnter", function() GameTooltip:SetOwner(this, "ANCHOR_TOP"); GameTooltip:SetText("Who lookup"); GameTooltip:AddLine("Click to run /who " .. (this.trader or ""), 1, 1, 1); GameTooltip:Show() end)
        who:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.whoButton = who
        row:SetScript("OnClick", function()
            if this.service then
                TB.State.selectedService = this.service
                TB:UpdateProfessions()
                TB:SetStatus("Selected " .. this.service.profession .. " service from " .. this.service.trader .. ".")
            end
        end)
        row:SetScript("OnEnter", function()
            if this.service then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetText(this.service.profession .. " - " .. this.service.trader, 1.00, 0.82, 0.24)
                if this.service.guild and this.service.guild ~= "" then
                    GameTooltip:AddLine("Guild: " .. this.service.guild, 0.82, 0.72, 0.42)
                end
                GameTooltip:AddLine("Skill " .. this.service.rank .. "/" .. this.service.maxRank, 0.90, 0.86, 0.76)
                GameTooltip:AddLine(this.service.note ~= "" and this.service.note or "Available for profession work.", 0.76, 0.72, 0.65, 1)
                if this.service.online then
                    GameTooltip:AddLine("Online through HC TradeBoard", 0.30, 1.00, 0.30)
                else
                    GameTooltip:AddLine("Last seen: " .. TB:FormatLastSeen(this.service.lastSeenAt) .. " ago", 0.58, 0.58, 0.58)
                end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        self.Frames.professionRows[i] = row
    end

    local count = CreateText(results, "0 services", "GameFontHighlightSmall", 0.72, 0.68, 0.60)
    count:SetPoint("BOTTOMLEFT", results, "BOTTOMLEFT", 12, 15)
    self.Frames.professionCount = count

    local edit = CreateButton(results, "List / Edit Mine", 130, 32)
    edit:SetPoint("BOTTOMRIGHT", results, "BOTTOMRIGHT", -10, 9)
    edit:SetScript("OnClick", function()
        TB:OpenProfessionEditor()
    end)
    local remove = CreateButton(results, "Remove Mine", 108, 32)
    remove:SetPoint("RIGHT", edit, "LEFT", -7, 0)
    remove:SetScript("OnClick", function()
        TB:DeleteOwnServices()
    end)
    local whisper = CreateButton(results, "Whisper", 92, 32)
    whisper:SetPoint("RIGHT", remove, "LEFT", -7, 0)
    whisper:SetScript("OnClick", function()
        if TB.State.selectedService then
            ChatFrame_OpenChat("/w " .. TB.State.selectedService.trader .. " ")
        else
            TB:SetStatus("Select a profession service before whispering its crafter.")
        end
    end)
    self:CreateProfessionEditor(pane)
    self:UpdateProfessions()
end

function TB:CreateProfessionEditor(parent)
    local editor = CreatePanel(parent, 740, 500)
    editor:SetPoint("CENTER", parent, "CENTER", 0, 0)
    editor:SetFrameLevel(parent:GetFrameLevel() + 20)
    editor:EnableMouse(1)
    editor:Hide()
    self.Frames.professionEditor = editor

    local title = CreateText(editor, "List My Profession Services", "GameFontNormalLarge", 1.00, 0.78, 0.20)
    title:SetPoint("TOP", editor, "TOP", 0, -16)
    local help = CreateText(editor, "Only professions learned by this character can be published.", "GameFontHighlightSmall", 0.72, 0.68, 0.60)
    help:SetPoint("TOP", title, "BOTTOM", 0, -6)
    local skillHeader = CreateText(editor, "Skill", "GameFontNormalSmall", 0.92, 0.78, 0.45)
    skillHeader:SetPoint("TOPLEFT", editor, "TOPLEFT", 194, -48)
    local noteHeader = CreateText(editor, "Short service note", "GameFontNormalSmall", 0.92, 0.78, 0.45)
    noteHeader:SetPoint("TOPLEFT", editor, "TOPLEFT", 278, -48)

    self.Frames.professionChecks = {}
    self.Frames.professionRanks = {}
    self.Frames.professionNotes = {}
    local i
    for i = 1, table.getn(self.ProfessionNames) do
        local professionName = self.ProfessionNames[i]
        local y = -61 - ((i - 1) * 34)
        local check = CreateCheckButton(editor, professionName, 168, nil, function(value)
            if value and not TB.KnownProfessions[professionName] then
                this:SetCheckedValue(nil)
                TB:SetStatus(professionName .. " is not learned by this character.")
            end
        end)
        check:SetPoint("TOPLEFT", editor, "TOPLEFT", 18, y)
        self.Frames.professionChecks[professionName] = check
        local rank = CreateText(editor, "", "GameFontHighlightSmall", 0.76, 0.72, 0.65)
        rank:SetPoint("TOPLEFT", editor, "TOPLEFT", 194, y - 5)
        rank:SetWidth(72)
        rank:SetJustifyH("LEFT")
        self.Frames.professionRanks[professionName] = rank
        local note = CreateEditBox(editor, 440, 27, "")
        note:SetPoint("TOPLEFT", editor, "TOPLEFT", 278, y)
        note:SetMaxLetters(60)
        self.Frames.professionNotes[professionName] = note
    end

    local save = CreateButton(editor, "Save Services", 140, 34)
    save:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -18, 15)
    save:SetScript("OnClick", function()
        TB:SaveProfessionEditor()
    end)
    local cancel = CreateButton(editor, "Cancel", 100, 34)
    cancel:SetPoint("RIGHT", save, "LEFT", -8, 0)
    cancel:SetScript("OnClick", function()
        TB.Frames.professionEditor:Hide()
        TB:SetStatus("Profession-service editing cancelled.")
    end)
end

function TB:OpenProfessionEditor()
    self:RefreshKnownProfessions()
    local published = {}
    local i
    for i = 1, table.getn(self.MyServices) do
        published[self.MyServices[i].profession] = self.MyServices[i]
    end
    for i = 1, table.getn(self.ProfessionNames) do
        local professionName = self.ProfessionNames[i]
        local known = self.KnownProfessions[professionName]
        local service = published[professionName]
        self.Frames.professionChecks[professionName]:SetCheckedValue(service and 1 or nil)
        self.Frames.professionRanks[professionName]:SetText(known and (known.rank .. "/" .. known.maxRank) or "Not learned")
        self.Frames.professionNotes[professionName]:SetText(service and service.note or "")
        if known then
            self.Frames.professionChecks[professionName].label:SetTextColor(0.90, 0.86, 0.76)
        else
            self.Frames.professionChecks[professionName].label:SetTextColor(0.48, 0.46, 0.42)
        end
    end
    self.Frames.professionEditor:Show()
    self:SetStatus("Choose which learned professions to publish and add optional notes.")
end

function TB:SaveProfessionEditor()
    self:RefreshKnownProfessions()
    local services = {}
    local i
    for i = 1, table.getn(self.ProfessionNames) do
        local professionName = self.ProfessionNames[i]
        local check = self.Frames.professionChecks[professionName]
        local known = self.KnownProfessions[professionName]
        if check.checked and known then
            table.insert(services, {
                profession = professionName,
                rank = known.rank,
                maxRank = known.maxRank,
                note = self.Frames.professionNotes[professionName]:GetText() or "",
            })
        end
    end
    local count = self:SaveOwnServices(services)
    self.Frames.professionEditor:Hide()
    if count == 0 then
        self:SetStatus("No profession services are currently published.")
    else
        self:SetStatus("Published " .. count .. (count == 1 and " profession service." or " profession services."))
    end
end

function TB:GetGuildProviderRankings()
    local byGuild = {}
    local i
    for i = 1, table.getn(self.Services) do
        local service = self.Services[i]
        if service.guild and service.guild ~= "" then
            local guildKey = string.lower(service.guild)
            local entry = byGuild[guildKey]
            if not entry then
                entry = { name = service.guild, providers = {}, count = 0 }
                byGuild[guildKey] = entry
            end
            local ownerKey = string.lower(service.owner or service.trader or "")
            if ownerKey ~= "" and not entry.providers[ownerKey] then
                entry.providers[ownerKey] = 1
                entry.count = entry.count + 1
            end
        end
    end

    local rankings = {}
    local key, entry
    for key, entry in pairs(byGuild) do
        table.insert(rankings, entry)
    end
    table.sort(rankings, function(a, b)
        if a.count == b.count then
            return string.lower(a.name) < string.lower(b.name)
        end
        return a.count > b.count
    end)
    return rankings
end

function TB:UpdateGuildProviderCards()
    if not self.Frames.guildCards then
        return
    end
    local rankings = self:GetGuildProviderRankings()
    local filterFound = nil
    local i
    for i = 1, 3 do
        local card = self.Frames.guildCards[i]
        local guild = rankings[i]
        if guild then
            card.guildName = guild.name
            card.providerTotal = guild.count
            card.icon:SetTexture(self:GetGuildSigilTexture(guild.name))
            card.guildLabel:SetText(guild.name)
            card.providerCount:SetText(guild.count .. (guild.count == 1 and " provider" or " providers"))
            if self.State.guildFilter and string.lower(self.State.guildFilter) == string.lower(guild.name) then
                card.selected:Show()
                card:SetBackdropBorderColor(0.95, 0.66, 0.18, 1)
                filterFound = 1
            else
                card.selected:Hide()
                card:SetBackdropBorderColor(0.38, 0.31, 0.17, 1)
            end
            card:Show()
        else
            card.guildName = nil
            card.providerTotal = 0
            card:Hide()
        end
    end
    if self.State.guildFilter and not filterFound then
        for i = 4, table.getn(rankings) do
            if string.lower(self.State.guildFilter) == string.lower(rankings[i].name) then
                filterFound = 1
                break
            end
        end
    end
    if self.State.guildFilter and not filterFound then
        self.State.guildFilter = nil
    end
end

function TB:GetFilteredServices()
    local filtered = {}
    local needle = string.lower(self.State.professionSearch or "")
    local i
    for i = 1, table.getn(self.Services) do
        local service = self.Services[i]
        local professionMatches = self.State.profession == "All Services" or service.profession == self.State.profession
        local guildMatches = not self.State.guildFilter or string.lower(service.guild or "") == string.lower(self.State.guildFilter)
        local sourceMatches = self.State.professionSource == "ALL" or (self.State.professionSource == "CHAT" and service.source == "CHAT") or (self.State.professionSource == "PUBLISHED" and service.source ~= "CHAT")
        local onlineMatches = not self.State.professionOnlineOnly or service.online
        local searchable = string.lower((service.profession or "") .. " " .. (service.trader or "") .. " " .. (service.guild or "") .. " " .. (service.note or ""))
        local searchMatches = needle == "" or string.find(searchable, needle, 1, 1)
        if professionMatches and guildMatches and sourceMatches and onlineMatches and searchMatches then
            table.insert(filtered, service)
        end
    end
    table.sort(filtered, function(a, b)
        if (a.online and 1 or 0) ~= (b.online and 1 or 0) then
            return a.online and true or false
        end
        if a.profession == b.profession then
            if a.rank == b.rank then
                return string.lower(a.trader or "") < string.lower(b.trader or "")
            end
            return (a.rank or 0) > (b.rank or 0)
        end
        return string.lower(a.profession or "") < string.lower(b.profession or "")
    end)
    return filtered
end

function TB:UpdateProfessionRows(filtered)
    local total = table.getn(filtered)
    local maxOffset = total - self.MAX_PROFESSION_ROWS
    if maxOffset < 0 then
        maxOffset = 0
    end
    if self.State.professionOffset > maxOffset then
        self.State.professionOffset = maxOffset
    elseif self.State.professionOffset < 0 then
        self.State.professionOffset = 0
    end
    local i
    for i = 1, self.MAX_PROFESSION_ROWS do
        local row = self.Frames.professionRows[i]
        local service = filtered[self.State.professionOffset + i]
        if service then
            row.service = service
            row.profession:SetText(service.profession)
            row.crafter:SetText(service.trader)
            self:UpdateWhoButton(row.whoButton, service.trader, service.level)
            row.level:SetText((tonumber(service.level) or 0) > 0 and tostring(service.level) or "?")
            row.class:SetText(service.class and service.class ~= "" and service.class or "-")
            row.guild:SetText(service.guild and service.guild ~= "" and service.guild or "-")
            row.skill:SetText((service.rank or 0) > 0 and ((service.rank or 0) .. "/" .. (service.maxRank or 0)) or "-")
            row.note:SetText(service.note ~= "" and service.note or "Available for work")
            row.source:SetText(service.source == "CHAT" and "Chat" or "Published")
            row.source:SetTextColor(service.source == "CHAT" and 1.00 or 0.45, service.source == "CHAT" and 0.72 or 0.80, service.source == "CHAT" and 0.20 or 1.00)
            if service.online then
                row.status:SetText("Online")
                row.status:SetTextColor(0.30, 1.00, 0.30)
                row:SetAlpha(1.00)
            else
                row.status:SetText("Last seen: " .. self:FormatLastSeen(service.lastSeenAt))
                row.status:SetTextColor(0.55, 0.55, 0.55)
                row:SetAlpha(0.48)
            end
            if self.State.selectedService == service then
                row.selected:Show()
            else
                row.selected:Hide()
            end
            row:Show()
        else
            row.service = nil
            row.whoButton.trader = nil
            row:Hide()
        end
    end
    local countText = total .. (total == 1 and " service" or " services")
    if self.State.guildFilter then
        countText = countText .. " / " .. self.State.guildFilter
    end
    self.Frames.professionCount:SetText(countText)
    if self.Frames.professionScrollbar then self.Frames.professionScrollbar:SetRange(self.State.professionOffset, maxOffset) end
end

function TB:UpdateProfessions()
    if not self.Frames.professionRows then
        return
    end
    local professionName, button
    for professionName, button in pairs(self.Frames.professionButtons) do
        SetButtonSelected(button, professionName == self.State.profession)
    end
    local sourceName, sourceButton
    for sourceName, sourceButton in pairs(self.Frames.professionSourceButtons or {}) do SetButtonSelected(sourceButton, sourceName == self.State.professionSource) end
    self:UpdateGuildProviderCards()
    self:UpdateProfessionRows(self:GetFilteredServices())
end

function TB:CreateWorldLogPane(parent)
    local pane = CreateFrame("Frame", nil, parent)
    pane:SetAllPoints(parent)
    pane:Hide()
    self.Frames.worldLogPane = pane

    local title = CreateText(pane, "World & Trade WTS / WTB / LFW", "GameFontNormalLarge", 1.00, 0.78, 0.20)
    title:SetPoint("TOPLEFT", pane, "TOPLEFT", 8, -8)
    local subtitle = CreateText(pane, "Four-hour local and peer-shared archive. Duplicates are removed. Idea credit: Svenne :)", "GameFontHighlightSmall", 0.70, 0.67, 0.58)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)

    local search = CreateEditBox(pane, 300, 28, self.State.worldSearch)
    search:SetPoint("TOPLEFT", pane, "TOPLEFT", 8, -50)
    search:SetScript("OnTextChanged", function()
        TB.State.worldSearch = this:GetText() or ""
        TB.State.worldOffset = 0
        TB:UpdateWorldLog()
    end)
    search:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    self.Frames.worldSearch = search

    self.Frames.worldChannelButtons = {}
    local channels = { { "All Channels", "ALL" }, { "World", "World" }, { "Trade", "Trade" } }
    local channelPrevious = nil
    local channelIndex
    for channelIndex = 1, 3 do
        local value = channels[channelIndex][2]
        local channelButton = CreateButton(pane, channels[channelIndex][1], channelIndex == 1 and 100 or 70, 27)
        if channelPrevious then channelButton:SetPoint("LEFT", channelPrevious, "RIGHT", 6, 0) else channelButton:SetPoint("LEFT", search, "RIGHT", 10, 0) end
        channelButton:SetScript("OnClick", function() TB.State.worldChannel = value; TB.State.worldOffset = 0; TB:UpdateWorldLog() end)
        self.Frames.worldChannelButtons[value] = channelButton
        channelPrevious = channelButton
    end

    self.Frames.worldTypeButtons = {}
    local types = { { "All", "ALL" }, { "WTS", "WTS" }, { "WTB", "WTB" }, { "LFW", "LFW" } }
    local previous = nil
    local i
    for i = 1, table.getn(types) do
        local value = types[i][2]
        local button = CreateButton(pane, types[i][1], 64, 27)
        if previous then button:SetPoint("LEFT", previous, "RIGHT", 6, 0) else button:SetPoint("LEFT", channelPrevious, "RIGHT", 18, 0) end
        button:SetScript("OnClick", function()
            TB.State.worldType = value
            TB.State.worldOffset = 0
            TB:UpdateWorldLog()
        end)
        self.Frames.worldTypeButtons[value] = button
        previous = button
    end

    local panel = CreatePanel(pane, 1132, 452)
    panel:SetPoint("TOPLEFT", pane, "TOPLEFT", 8, -87)
    panel:EnableMouseWheel(1)
    panel:SetScript("OnMouseWheel", function()
        local filtered = TB:GetFilteredWorldLog()
        local maxOffset = table.getn(filtered) - TB.MAX_WORLD_ROWS
        if maxOffset < 0 then maxOffset = 0 end
        if arg1 > 0 then TB.State.worldOffset = TB.State.worldOffset - 1 else TB.State.worldOffset = TB.State.worldOffset + 1 end
        if TB.State.worldOffset < 0 then TB.State.worldOffset = 0 end
        if TB.State.worldOffset > maxOffset then TB.State.worldOffset = maxOffset end
        TB:UpdateWorldLog()
    end)
    local worldScrollbar = CreateClassicScrollbar(panel, 438, function(value) TB.State.worldOffset = value; TB:UpdateWorldLog() end)
    worldScrollbar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -7)
    self.Frames.worldScrollbar = worldScrollbar
    self.Frames.worldLogRows = {}

    for i = 1, self.MAX_WORLD_ROWS do
        local row = CreateFrame("Frame", nil, panel)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8 - ((i - 1) * 43))
        row:SetWidth(1096)
        row:SetHeight(40)
        row:SetBackdrop(PANEL_BACKDROP)
        row:SetBackdropColor(math.mod(i, 2) == 0 and 0.050 or 0.025, 0.025, 0.020, 0.90)
        row:SetBackdropBorderColor(0.25, 0.22, 0.16, 1)

        row.metaPrefix = CreateText(row, "", "GameFontNormalSmall", 1.00, 0.74, 0.22)
        row.metaPrefix:SetPoint("TOPLEFT", row, "TOPLEFT", 7, -5)
        row.metaPrefix:SetJustifyH("LEFT")

        row.senderButton = CreateFrame("Button", nil, row)
        row.senderButton:SetHeight(16)
        row.senderButton.text = CreateText(row.senderButton, "", "GameFontNormalSmall", 1.00, 0.74, 0.22)
        row.senderButton.text:SetAllPoints(row.senderButton)
        row.senderButton.text:SetJustifyH("LEFT")
        row.senderButton:SetScript("OnEnter", function()
            this.text:SetTextColor(1.00, 0.95, 0.55)
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:SetText("Click to whisper " .. (this.sender or ""))
            GameTooltip:Show()
        end)
        row.senderButton:SetScript("OnLeave", function()
            this.text:SetTextColor(1.00, 0.74, 0.22)
            GameTooltip:Hide()
        end)
        row.senderButton:SetScript("OnClick", function() TB:OpenWorldWhisper(this.sender) end)

        row.whoButton = CreateButton(row, "?", 26, 22)
        row.whoButton:SetScript("OnClick", function() if this.sender then TB:RequestManualWho(this.sender) end end)
        row.whoButton:SetScript("OnEnter", function() GameTooltip:SetOwner(this, "ANCHOR_TOP"); GameTooltip:SetText("Who lookup"); GameTooltip:AddLine("Click to run /who " .. (this.sender or ""), 1, 1, 1); GameTooltip:Show() end)
        row.whoButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row.level = CreateText(row, "", "GameFontNormalSmall", 1.00, 0.74, 0.22)
        row.level:SetJustifyH("LEFT")
        row.class = CreateText(row, "", "GameFontNormalSmall", 0.72, 0.82, 1.00)
        row.class:SetJustifyH("LEFT")

        row.guildButton = CreateFrame("Button", nil, row)
        row.guildButton:SetHeight(16)
        row.guildButton.text = CreateText(row.guildButton, "", "GameFontNormalSmall", 1.00, 0.74, 0.22)
        row.guildButton.text:SetAllPoints(row.guildButton)
        row.guildButton.text:SetJustifyH("LEFT")
        row.guildButton:SetScript("OnEnter", function()
            this.text:SetTextColor(1.00, 0.95, 0.55)
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:SetText("Guild: <" .. (this.guildName or "") .. ">")
            GameTooltip:Show()
        end)
        row.guildButton:SetScript("OnLeave", function()
            this.text:SetTextColor(1.00, 0.74, 0.22)
            GameTooltip:Hide()
        end)
        row.guildButton:SetScript("OnClick", function() end)

        row.source = CreateText(row, "", "GameFontNormalSmall", 0.45, 0.80, 1.00)
        row.source:SetPoint("TOPRIGHT", row, "TOPRIGHT", -7, -5)
        row.source:SetJustifyH("RIGHT")

        row.messageParts = {}
        local partIndex
        for partIndex = 1, 12 do
            local part = CreateFrame("Button", nil, row)
            -- Keep the message line and its clickable links inside the 40px row.
            part:SetHeight(14)
            part.text = CreateText(part, "", "GameFontHighlightSmall", 0.92, 0.90, 0.84)
            part.text:SetAllPoints(part)
            part.text:SetJustifyH("LEFT")
            part.text:SetJustifyV("MIDDLE")
            part:SetScript("OnEnter", function()
                if this.itemLink then
                    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                    local hyperlink = TB:GetListingTooltipHyperlink({ itemLink = this.itemLink })
                    if hyperlink then GameTooltip:SetHyperlink(hyperlink) end
                    GameTooltip:Show()
                end
            end)
            part:SetScript("OnLeave", function() GameTooltip:Hide() end)
            part:SetScript("OnClick", function()
                if not this.itemLink then return end
                if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsShown() then
                    ChatFrameEditBox:Insert(this.itemLink)
                elseif SetItemRef then
                    local hyperlink = TB:GetListingTooltipHyperlink({ itemLink = this.itemLink })
                    if hyperlink then SetItemRef(hyperlink, this.itemLink, "LeftButton") end
                end
            end)
            row.messageParts[partIndex] = part
        end
        self.Frames.worldLogRows[i] = row
    end

    local count = CreateText(pane, "0 captured messages", "GameFontHighlightSmall", 0.80, 0.75, 0.64)
    count:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 10, 2)
    self.Frames.worldLogCount = count
    local scroll = CreateText(pane, "SCROLL: use mouse wheel over the message list", "GameFontNormalSmall", 1.00, 0.72, 0.20)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -10, 2)
end

function TB:UpdateWorldLog()
    if not self.Frames.worldLogRows then return end
    local filtered = self:GetFilteredWorldLog()
    local total = table.getn(filtered)
    local maxOffset = total - self.MAX_WORLD_ROWS
    if maxOffset < 0 then maxOffset = 0 end
    if self.State.worldOffset > maxOffset then self.State.worldOffset = maxOffset end
    if self.State.worldOffset < 0 then self.State.worldOffset = 0 end
    local typeName, button
    for typeName, button in pairs(self.Frames.worldTypeButtons) do SetButtonSelected(button, typeName == self.State.worldType) end
    local channelName, channelButton
    for channelName, channelButton in pairs(self.Frames.worldChannelButtons) do SetButtonSelected(channelButton, channelName == self.State.worldChannel) end
    local i
    for i = 1, self.MAX_WORLD_ROWS do
        local entry = filtered[total - self.State.worldOffset - i + 1]
        local row = self.Frames.worldLogRows[i]
        if entry then
            row.entry = entry
            local stamp = date and date("%m-%d %H:%M", entry.timestamp) or tostring(entry.timestamp)
            local level = (tonumber(entry.level) or 0) > 0 and (" L" .. entry.level) or " L?"
            local typeColor = entry.type == "WTS" and "66ff66" or (entry.type == "WTB" and "ffcc55" or "66ccff")
            row.metaPrefix:SetText(stamp .. "  |cff" .. typeColor .. entry.type .. "|r  " .. (entry.channel or "World") .. "  ")
            row.metaPrefix:SetWidth(row.metaPrefix:GetStringWidth() + 2)
            row.senderButton:ClearAllPoints()
            row.senderButton:SetPoint("LEFT", row.metaPrefix, "RIGHT", 0, 0)
            row.senderButton.sender = entry.sender
            row.senderButton.text:SetText(entry.sender or "Unknown")
            row.senderButton:SetWidth(row.senderButton.text:GetStringWidth() + 2)
            row.whoButton:ClearAllPoints()
            row.whoButton:SetPoint("LEFT", row.senderButton, "RIGHT", 3, 0)
            self:UpdateWhoButton(row.whoButton, entry.sender, entry.level)
            row.level:ClearAllPoints()
            row.level:SetPoint("LEFT", row.whoButton:IsShown() and row.whoButton or row.senderButton, "RIGHT", 4, 0)
            row.level:SetText(level)
            row.level:SetWidth(row.level:GetStringWidth() + 4)
            row.class:ClearAllPoints()
            row.class:SetPoint("LEFT", row.level, "RIGHT", 0, 0)
            row.class:SetText(entry.class and entry.class ~= "" and (entry.class .. "  ") or "")
            row.class:SetWidth(row.class:GetStringWidth() + 2)
            row.guildButton:ClearAllPoints()
            row.guildButton:SetPoint("LEFT", row.class, "RIGHT", 0, 0)
            if entry.guild and entry.guild ~= "" then
                row.guildButton.guildName = entry.guild
                row.guildButton.text:SetText("<" .. entry.guild .. ">")
                row.guildButton:SetWidth(row.guildButton.text:GetStringWidth() + 2)
                row.guildButton:Show()
            else
                row.guildButton.guildName = nil
                row.guildButton:Hide()
            end
            row.source:SetText(entry.source == "PEER" and "Peer" or "Local")
            row.source:SetTextColor(entry.source == "PEER" and 0.35 or 0.45, entry.source == "PEER" and 0.65 or 1.00, 1.00)

            local segments = self:GetWorldMessageSegments(entry.message)
            local usedWidth = 0
            local previousPart = nil
            local partIndex
            for partIndex = 1, 12 do
                local part = row.messageParts[partIndex]
                local segment = segments[partIndex]
                part:ClearAllPoints()
                if previousPart then
                    part:SetPoint("LEFT", previousPart, "RIGHT", 0, 0)
                else
                    part:SetPoint("TOPLEFT", row, "TOPLEFT", 7, -22)
                end
                if segment and usedWidth < 1082 then
                    part.itemLink = segment.itemLink
                    part.text:SetText(segment.text)
                    local width = part.text:GetStringWidth() + 1
                    if width > 1082 - usedWidth then width = 1082 - usedWidth end
                    if width < 1 then width = 1 end
                    part:SetWidth(width)
                    usedWidth = usedWidth + width
                    part:Show()
                    previousPart = part
                else
                    part.itemLink = nil
                    part:Hide()
                end
            end
            row:Show()
        else
            row.entry = nil
            row.whoButton.sender = nil
            row:Hide()
        end
    end
    self.Frames.worldLogCount:SetText(total .. (total == 1 and " shared message" or " shared messages") .. " / expires after 12 hours")
    if self.Frames.worldScrollbar then self.Frames.worldScrollbar:SetRange(self.State.worldOffset, maxOffset) end
end

function TB:SetMinimized(minimized)
    self.isMinimized = minimized and 1 or nil
    local frame = self.Frames.main
    local name, tab
    if self.isMinimized then
        self.Frames.content:Hide()
        self.Frames.versionLabel:Hide(); self.Frames.memoryUsage:Hide()
        if self.Frames.statusBar then self.Frames.statusBar:Hide() end
        for name, tab in pairs(self.Frames.tabs or {}) do tab:Hide() end
        if self.Frames.settingsPanel then self.Frames.settingsPanel:Hide() end
        frame:SetWidth(420); frame:SetHeight(64)
        self.Frames.minimizeButton.label:SetText("+")
    else
        frame:SetWidth(1180); frame:SetHeight(720)
        self.Frames.content:Show()
        self.Frames.versionLabel:Show(); self.Frames.memoryUsage:Show()
        if self.Frames.statusBar then self.Frames.statusBar:Show() end
        for name, tab in pairs(self.Frames.tabs or {}) do tab:Show() end
        self.Frames.minimizeButton.label:SetText("-")
        self:SetActiveTab(self.State.activeTab)
    end
    TradeBoardDB = TradeBoardDB or {}
    TradeBoardDB.minimized = self.isMinimized
end

function TB:CreateWantedPane(parent)
    local pane = CreateFrame("Frame", nil, parent)
    pane:SetAllPoints(parent); pane:Hide()
    self.Frames.wantedPane = pane
    local title = CreateText(pane, "Wanted subscriptions", "GameFontNormalLarge", 1.00, 0.78, 0.20)
    title:SetPoint("TOPLEFT", pane, "TOPLEFT", 8, -8)
    local help = CreateText(pane, "Add an item name or link. Matching WTS posts seen locally or through peers open the loot-style alert.", "GameFontHighlightSmall", 0.72, 0.68, 0.58)
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    local input = CreateEditBox(pane, 560, 30, "")
    input:SetPoint("TOPLEFT", pane, "TOPLEFT", 8, -54); input:SetMaxLetters(180)
    self.Frames.wantedInput = input
    local add = CreateButton(pane, "Add subscription", 150, 30)
    add:SetPoint("LEFT", input, "RIGHT", 8, 0)
    add:SetScript("OnClick", function()
        local wanted, reason = TB:AddWanted(TB.Frames.wantedInput:GetText())
        if wanted then TB.Frames.wantedInput:SetText(""); TB:SetStatus("Subscribed to " .. wanted.name .. ".") else TB:SetStatus(reason) end
    end)
    input:SetScript("OnEnterPressed", function() local wanted, reason = TB:AddWanted(this:GetText()); if wanted then this:SetText(""); TB:SetStatus("Subscribed to " .. wanted.name .. ".") else TB:SetStatus(reason) end; this:ClearFocus() end)
    local fromBrowse = CreateButton(pane, "Use selected Browse item", 190, 30)
    fromBrowse:SetPoint("LEFT", add, "RIGHT", 8, 0)
    fromBrowse:SetScript("OnClick", function()
        local listing = TB.State.selectedListing
        if not listing then TB:SetStatus("Select an item in Browse first."); return end
        local wanted, reason = TB:AddWanted(TB:GetListingItemLink(listing) or listing.name)
        TB:SetStatus(wanted and ("Subscribed to " .. wanted.name .. ".") or reason)
    end)
    local panel = CreatePanel(pane, 1138, 434)
    panel:SetPoint("TOPLEFT", pane, "TOPLEFT", 8, -100)
    panel:EnableMouseWheel(1)
    panel:SetScript("OnMouseWheel", function()
        local maxOffset = math.max(0, table.getn(TB.Wanted or {}) - 10)
        TB.State.wantedOffset = TB.State.wantedOffset + (arg1 > 0 and -1 or 1)
        if TB.State.wantedOffset < 0 then TB.State.wantedOffset = 0 elseif TB.State.wantedOffset > maxOffset then TB.State.wantedOffset = maxOffset end
        TB:UpdateWanted()
    end)
    local heading = CreateText(panel, "ON     ITEM / SEARCH TERM", "GameFontNormal", 0.90, 0.74, 0.30)
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
    self.Frames.wantedRows = {}
    local wantedScrollbar = CreateClassicScrollbar(panel, 390, function(value) TB.State.wantedOffset = value; TB:UpdateWanted() end)
    wantedScrollbar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -35); self.Frames.wantedScrollbar = wantedScrollbar
    local i
    for i = 1, 10 do
        local row = CreatePanel(panel, 1104, 34)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -37 - ((i - 1) * 38))
        row.toggle = CreateButton(row, "ON", 54, 24); row.toggle:SetPoint("LEFT", row, "LEFT", 7, 0)
        row.toggle:SetScript("OnClick", function() if this.wantedID then TB:ToggleWanted(this.wantedID) end end)
        row.name = CreateText(row, "", "GameFontHighlight", 0.90, 0.88, 0.80); row.name:SetPoint("LEFT", row, "LEFT", 76, 0); row.name:SetWidth(850); row.name:SetJustifyH("LEFT")
        row.remove = CreateButton(row, "Remove", 105, 24); row.remove:SetPoint("RIGHT", row, "RIGHT", -7, 0)
        row.remove:SetScript("OnClick", function() if this.wantedID then TB:RemoveWanted(this.wantedID) end end)
        self.Frames.wantedRows[i] = row
    end
    local count = CreateText(pane, "0 subscriptions", "GameFontHighlightSmall", 0.80, 0.75, 0.64)
    count:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 10, 2); self.Frames.wantedCount = count
end

function TB:UpdateWanted()
    if not self.Frames.wantedRows then return end
    self:InitializeFeatureData()
    local maxOffset = math.max(0, table.getn(self.Wanted) - table.getn(self.Frames.wantedRows))
    if self.State.wantedOffset > maxOffset then self.State.wantedOffset = maxOffset end
    local i
    for i = 1, table.getn(self.Frames.wantedRows) do
        local row, wanted = self.Frames.wantedRows[i], self.Wanted[(self.State.wantedOffset or 0) + i]
        if wanted then
            row.toggle.wantedID = wanted.id; row.remove.wantedID = wanted.id
            row.toggle.label:SetText(wanted.enabled and "ON" or "OFF")
            SetButtonSelected(row.toggle, wanted.enabled)
            row.name:SetText(wanted.itemLink or wanted.name); row:Show()
        else row.toggle.wantedID = nil; row.remove.wantedID = nil; row:Hide() end
    end
    self.Frames.wantedCount:SetText(table.getn(self.Wanted) .. " / " .. self.MAX_WANTED .. " subscriptions")
    self.Frames.wantedScrollbar:SetRange(self.State.wantedOffset, maxOffset)
end

function TB:CreateSettingsPanel(parent)
    local panel = CreatePanel(parent, 620, 490)
    panel:SetPoint("CENTER", parent, "CENTER", 0, 0); panel:SetFrameLevel(parent:GetFrameLevel() + 30); panel:EnableMouse(1); panel:Hide()
    self.Frames.settingsPanel = panel
    local title = CreateText(panel, "HC TradeBoard Settings", "GameFontNormalLarge", 1.00, 0.78, 0.20); title:SetPoint("TOP", panel, "TOP", 0, -18)
    local close = CreateButton(panel, "X", 30, 26); close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -10); close:SetScript("OnClick", function() panel:Hide() end)
    local function MuteRow(y, label, channel)
        local caption = CreateText(panel, label, "GameFontNormal", 0.92, 0.85, 0.68); caption:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, y)
        local status = CreateText(panel, "", "GameFontHighlightSmall", 0.55, 1.00, 0.55); status:SetPoint("LEFT", caption, "RIGHT", 12, 0)
        local choices = { { "5m", 300 }, { "10m", 600 }, { "60m", 3600 }, { "2h", 7200 }, { "Until enabled", -1 }, { "Enable", 0 } }
        local previous, i
        for i = 1, table.getn(choices) do
            local button = CreateButton(panel, choices[i][1], i == 5 and 112 or 68, 28)
            if previous then button:SetPoint("LEFT", previous, "RIGHT", 7, 0) else button:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, y - 29) end
            local seconds = choices[i][2]
            button:SetScript("OnClick", function() TB:SetLootMute(channel, seconds) end)
            previous = button
        end
        return status
    end
    self.Frames.guildMuteStatus = MuteRow(-62, "Guild item popups", "Guild")
    self.Frames.publicMuteStatus = MuteRow(-132, "World / Trade item popups", "Public")
    local wanted = CreateCheckButton(panel, "Notify me when a Wanted subscription matches", 420, 1, function(value)
        TB:InitializeFeatureData(); TradeBoardDB.settings.wantedNotifications = value and 1 or nil
    end)
    wanted:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -212); self.Frames.wantedNotificationsCheck = wanted
    local volunteer = CreateCheckButton(panel, "I want to earn a bit by being a trade-chain spot", 470, nil, function(value) TB:SetChainVolunteer(value) end)
    volunteer:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -246); self.Frames.volunteerCheck = volunteer
    local volunteerHint = CreateText(panel, "Advertises this character at current level +/-5; no automatic whispers or trades.", "GameFontHighlightSmall", 0.70, 0.67, 0.58)
    volunteerHint:SetPoint("TOPLEFT", panel, "TOPLEFT", 50, -275)
    local networkTitle = CreateText(panel, "Peer network: Conservative", "GameFontNormal", 0.90, 0.78, 0.35); networkTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -318)
    local networkHelp = CreateText(panel, "At most 8 hidden-channel messages/minute, 5s spacing, 15s pause after your chat,\nand smaller sync snapshots. World/Trade discovery stays local and peer-shared.", "GameFontHighlightSmall", 0.72, 0.68, 0.58)
    networkHelp:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -343); networkHelp:SetWidth(560); networkHelp:SetJustifyH("LEFT")
    local reset = CreateButton(panel, "Reset window to center", 200, 30); reset:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 24, 20)
    reset:SetScript("OnClick", function() TB.Frames.main:ClearAllPoints(); TB.Frames.main:SetPoint("CENTER", UIParent, "CENTER", 0, 0); TB:SetMinimized(nil); panel:Show() end)
end

function TB:ToggleSettings()
    if self.Frames.settingsPanel:IsShown() then self.Frames.settingsPanel:Hide()
    else
        if self.isMinimized then self:SetMinimized(nil) end
        self:UpdateSettings(); self.Frames.settingsPanel:Show()
    end
end

function TB:UpdateSettings()
    self:InitializeFeatureData()
    self.Frames.guildMuteStatus:SetText(self:GetLootMuteLabel("Guild"))
    self.Frames.publicMuteStatus:SetText(self:GetLootMuteLabel("Public"))
    self.Frames.wantedNotificationsCheck:SetCheckedValue(TradeBoardDB.settings.wantedNotifications)
    local volunteer = self:GetOwnVolunteer()
    self.Frames.volunteerCheck:SetCheckedValue(volunteer and volunteer.enabled)
end

function TB:SetActiveTab(tabName)
    if self.openFilterMenu then self.openFilterMenu:Hide(); self.openFilterMenu = nil end
    self.State.activeTab = tabName
    if tabName ~= "My Listings" then
        self.bagPickMode = nil
    end
    self.Frames.browsePane:Hide()
    self.Frames.myListingsPane:Hide()
    self.Frames.wantedPane:Hide()
    self.Frames.tradeChainsPane:Hide()
    self.Frames.professionsPane:Hide()
    self.Frames.worldLogPane:Hide()

    if tabName == "Browse" then
        self.Frames.browsePane:Show()
        self:UpdateBrowse()
    elseif tabName == "My Listings" then
        self.Frames.myListingsPane:Show()
        self:UpdateListingEditor()
        self:UpdateMyListings()
    elseif tabName == "Wanted" then
        self.Frames.wantedPane:Show()
        self:UpdateWanted()
    elseif tabName == "Trade Chains" then
        self.Frames.tradeChainsPane:Show()
        self:UpdateTradeChains()
    elseif tabName == "Professions" then
        self.Frames.professionsPane:Show()
        self:UpdateProfessions()
    else
        self.Frames.worldLogPane:Show()
        self:UpdateWorldLog()
    end

    local name, tab
    for name, tab in pairs(self.Frames.tabs) do
        SetButtonSelected(tab, name == tabName)
    end
end

function TB:SyncFilterControls()
    local state = self.State
    self.Frames.searchField:SetText(state.search or "")
    self.Frames.onlineCheck:SetCheckedValue(state.onlineOnly)

    if state.minLevel and state.minLevel > 0 then
        self.Frames.minLevel:SetText(tostring(state.minLevel))
    else
        self.Frames.minLevel:SetText("")
    end
    if state.maxLevel and state.maxLevel > 0 then
        self.Frames.maxLevel:SetText(tostring(state.maxLevel))
    else
        self.Frames.maxLevel:SetText("")
    end

    self:SyncFilterDropdowns()
end

function TB:SyncFilterDropdowns()
    local state = self.State
    self.Frames.levelDropdown:SetValue(state.myLevelRange and "range" or state.levelType)
    self.Frames.listingTypeDropdown:SetValue(state.listingType)
    local quality, selected, count
    count = 0
    for quality = 1, 5 do
        if state.rarities[quality] then selected = quality; count = count + 1 end
    end
    self.Frames.rarityDropdown:SetValue(count == 1 and selected or "ALL")
    local acceptsBounds = not state.myLevelRange and state.levelType ~= "all"
    self.Frames.minLevel:EnableKeyboard(acceptsBounds and 1 or nil)
    self.Frames.maxLevel:EnableKeyboard(acceptsBounds and 1 or nil)
    self.Frames.minLevel:EnableMouse(acceptsBounds and 1 or nil)
    self.Frames.maxLevel:EnableMouse(acceptsBounds and 1 or nil)
    self.Frames.minLevel:SetAlpha(acceptsBounds and 1 or 0.45)
    self.Frames.maxLevel:SetAlpha(acceptsBounds and 1 or 0.45)
end

function TB:UpdateBrowse()
    local state = self.State
    state.search = self.Frames.searchField:GetText() or ""
    state.minLevel = tonumber(self.Frames.minLevel:GetText()) or 0
    state.maxLevel = tonumber(self.Frames.maxLevel:GetText()) or 0

    self:SyncFilterDropdowns()

    self:RefreshCategoryPanel()

    local sortKey, sortHeader
    for sortKey, sortHeader in pairs(self.Frames.sortHeaders) do
        if sortKey == state.sortKey then
            sortHeader.arrow:Show()
            sortHeader.label:SetTextColor(1.00, 0.86, 0.32)
            if state.sortAscending then
                sortHeader.arrow:SetTexCoord(0, 0.5625, 1.0, 0)
            else
                sortHeader.arrow:SetTexCoord(0, 0.5625, 0, 1.0)
            end
        else
            sortHeader.arrow:Hide()
            sortHeader.label:SetTextColor(0.92, 0.78, 0.45)
        end
    end

    local filtered = self:GetFilteredListings()
    local maxOffset = table.getn(filtered) - self.MAX_VISIBLE_ROWS
    if maxOffset < 0 then
        maxOffset = 0
    end
    if state.browseOffset > maxOffset then
        state.browseOffset = maxOffset
    end
    if state.browseOffset < 0 then
        state.browseOffset = 0
    end

    self:UpdateBrowseRows(filtered)
end

function TB:UpdateBrowseRows(filtered)
    local total = table.getn(filtered)
    local offset = self.State.browseOffset
    local i

    for i = 1, self.MAX_VISIBLE_ROWS do
        local row = self.Frames.resultRows[i]
        local listing = filtered[offset + i]
        if listing then
            local info = self.Quality[listing.quality] or self.Quality[1]
            row.listing = listing
            row.icon:SetTexture(listing.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            if listing.orderType == "BUY" then
                row.itemName:SetText("WTB: " .. listing.name)
            else
                row.itemName:SetText(listing.name)
            end
            row.itemName:SetTextColor(info.r, info.g, info.b)
            row.quantity:SetText(tostring(listing.quantity))
            row.required:SetText((tonumber(listing.requiredLevel) or 0) > 0 and tostring(listing.requiredLevel) or "-")
            row.itemLevel:SetText((tonumber(listing.itemLevel) or 0) > 0 and tostring(listing.itemLevel) or "-")
            row.price:SetText(listing.priceKnown == nil and listing.source == "CHAT" and "Ask" or self:FormatMoney(listing.totalPrice or 0))
            row.trader:SetText(listing.trader)
            self:UpdateWhoButton(row.whoButton, listing.trader, listing.traderLevel)
            row.guild:SetText(listing.guild and listing.guild ~= "" and listing.guild or "-")
            row.traderLevel:SetText((tonumber(listing.traderLevel) or 0) > 0 and tostring(listing.traderLevel) or "?")
            row.class:SetText(listing.class and listing.class ~= "" and listing.class or "-")
            row.source:SetText(listing.source == "CHAT" and "Chat" or "Listed")
            row.source:SetTextColor(listing.source == "CHAT" and 1.00 or 0.45, listing.source == "CHAT" and 0.72 or 0.80, listing.source == "CHAT" and 0.20 or 1.00)
            if listing.online then
                row.status:SetText("Online")
                row.status:SetTextColor(0.20, 1.00, 0.20)
                row:SetAlpha(1.00)
            else
                row.status:SetText("Seen " .. self:FormatLastSeen(listing.lastSeenAt))
                row.status:SetTextColor(0.55, 0.55, 0.55)
                row:SetAlpha(0.48)
            end
            if self.State.selectedListing == listing then
                row.selected:Show()
            else
                row.selected:Hide()
            end
            row:Show()
        else
            row.listing = nil
            row.whoButton.trader = nil
            row:Hide()
        end
    end

    local maxOffset = total - self.MAX_VISIBLE_ROWS
    if maxOffset < 0 then maxOffset = 0 end
    self.Frames.browseScrollbar:SetRange(offset, maxOffset)

    local activeTotal = filtered.totalUnique or table.getn(self.Listings)
    local hidden = activeTotal - total
    if hidden > 0 then
        self.Frames.resultCount:SetText(total .. " matching / " .. activeTotal .. " active (filters hide " .. hidden .. ")")
    elseif total == 1 then
        self.Frames.resultCount:SetText("1 matching listing")
    else
        self.Frames.resultCount:SetText(total .. " matching listings")
    end
end

function TB:UpdateTradeChains()
    local index = self.State.selectedChain
    local chain = index and self.Chains[index]
    if not chain then
        if table.getn(self.Chains) > 0 then
            index = 1
            self.State.selectedChain = 1
            chain = self.Chains[1]
        else
            self.State.selectedChain = nil
        end
    end

    local i
    local maxOffset = table.getn(self.Chains) - 9
    if maxOffset < 0 then
        maxOffset = 0
    end
    if self.State.chainOffset > maxOffset then
        self.State.chainOffset = maxOffset
    end
    if index and index <= self.State.chainOffset then
        self.State.chainOffset = index - 1
    elseif index and index > self.State.chainOffset + 9 then
        self.State.chainOffset = index - 9
    end
    for i = 1, 9 do
        local chainButton = self.Frames.chainButtons[i]
        local chainIndex = self.State.chainOffset + i
        if self.Chains[chainIndex] then
            chainButton.chainIndex = chainIndex
            chainButton.label:SetText(self.Chains[chainIndex].name .. (self.Chains[chainIndex].owner and (" - " .. self.Chains[chainIndex].owner) or ""))
            SetButtonSelected(chainButton, chainIndex == index)
            chainButton:Show()
        else
            chainButton.chainIndex = nil
            chainButton:Hide()
        end
    end
    if self.Frames.chainScrollbar then self.Frames.chainScrollbar:SetRange(self.State.chainOffset, maxOffset) end

    if not chain then
        self.Frames.chainTitle:SetText("No trade chains listed yet")
        for i = 1, 12 do
            local emptyNode = self.Frames.chainNodes[i]
            emptyNode.level:SetText("Lv " .. (i * 5))
            emptyNode.memberName:SetText("Waiting...")
            emptyNode.memberClass:SetText("")
            emptyNode.dot:SetVertexColor(0.38, 0.38, 0.38)
            emptyNode:SetBackdropBorderColor(0.30, 0.28, 0.22, 1)
        end
        self.Frames.chainOnline:SetText("0/12 available")
        self.Frames.chainFilled:SetText("0/12 slots filled")
        self.Frames.chainFaction:SetText("Peer-synced")
        self.Frames.chainWhoButton.trader = nil
        self.Frames.chainWhoButton:Hide()
        return
    end

    self.Frames.chainTitle:SetText(chain.name .. (chain.owner and (" - " .. chain.owner) or ""))
    self:UpdateWhoButton(self.Frames.chainWhoButton, chain.owner)
    local onlineCount = 0
    local filledCount = 0
    for i = 1, 12 do
        local member = chain.members[i]
        local node = self.Frames.chainNodes[i]
        node.level:SetText("Lv " .. member.level)
        node.memberName:SetText(member.name)
        local person = TradeBoardDB and TradeBoardDB.worldPeople and TradeBoardDB.worldPeople[string.lower(member.name or "")]
        node.memberClass:SetText(person and person.class or "")
        if member.filled then
            filledCount = filledCount + 1
        end
        local memberOnline = member.online
        if not memberOnline and self.Network and self.Network.peers[string.lower(member.name or "")] then
            local peer = self.Network.peers[string.lower(member.name or "")]
            if GetTime() - peer.lastSeen < self.REMOTE_TTL then
                memberOnline = 1
            end
        end
        if memberOnline then
            onlineCount = onlineCount + 1
            node.dot:SetVertexColor(0.20, 1.00, 0.20)
            node:SetBackdropBorderColor(0.45, 0.55, 0.22, 1)
        else
            node.dot:SetVertexColor(0.38, 0.38, 0.38)
            node:SetBackdropBorderColor(0.30, 0.28, 0.22, 1)
        end
    end

    self.Frames.chainOnline:SetText(onlineCount .. "/12 available")
    if filledCount == 12 then
        self.Frames.chainFilled:SetText("Full 5-60 chain")
    else
        self.Frames.chainFilled:SetText(filledCount .. "/12 slots filled")
    end
    if chain.crossFaction then
        self.Frames.chainFaction:SetText("Cross-faction")
    else
        self.Frames.chainFaction:SetText("Same faction")
    end
end

function TB:Toggle()
    if self.Frames.main:IsShown() then
        self:Close()
    else
        self.Frames.main:Show()
        self:SetActiveTab(self.State.activeTab)
        self:ProbeAndSync()
        self.Network.nextOpenSync = GetTime() + self.AUTO_SYNC_INTERVAL
        self:SetStatus("Peer sync requested. Lightweight refresh runs at most every 10 minutes while open.")
    end
end

function TB:Initialize()
    self:CreateMainFrame()
    self:CreateMinimapButton()
    self:SyncFilterControls()
    self:SetActiveTab("Browse")
    self.Frames.main:Hide()
    self:InitializeNetwork()

    SLASH_TRADEBOARD1 = "/tradeboard"
    SLASH_TRADEBOARD2 = "/tb"
    SlashCmdList["TRADEBOARD"] = function(message)
        local command = string.lower(message or "")
        if (command == "loot" or command == "guildloot") and TB.ShowGuildLootPopup then
            TB:ShowGuildLootPopup()
        elseif (command == "loot on" or command == "loot off" or command == "guildloot on" or command == "guildloot off") and TB.SetGuildLootEnabled then
            local enabled = command == "loot on" or command == "guildloot on"
            TB:SetGuildLootEnabled(enabled)
            DEFAULT_CHAT_FRAME:AddMessage(TB.COLORED_TITLE .. ": loot notifications " .. (enabled and "enabled." or "disabled."))
        elseif command == "probe" or command == "sync" then
            TB:ProbeAndSync()
            TB:SetStatus("Peer probe and listing sync requested.")
        elseif command == "settings" then
            if not TB.Frames.main:IsShown() then TB.Frames.main:Show() end
            TB:SetMinimized(nil)
            TB:ToggleSettings()
        elseif command == "reset" then
            TB.Frames.main:ClearAllPoints()
            TB.Frames.main:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            TB:SetMinimized(nil)
            TB.Frames.main:Show()
        else
            TB:Toggle()
        end
    end

    local events = CreateFrame("Frame", nil, UIParent)
    -- Update only small button labels, once per second while the board is visible.
    self.Frames.main:SetScript("OnUpdate", function()
        TB:RefreshMemoryLabel()
        local remaining = TB:GetWhoCooldownRemaining()
        if remaining ~= TB.displayedWhoCooldown then
            TB.displayedWhoCooldown = remaining
            TB:RefreshWhoButtons()
        end
    end)
    events:RegisterEvent("VARIABLES_LOADED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:SetScript("OnEvent", function()
        if event == "VARIABLES_LOADED" then
            if not TradeBoardDB then
                TradeBoardDB = {}
            end
            TB:SetMinimapButtonAngle(TradeBoardDB.minimapAngle or -2.52)
            TB:SetMinimized(TradeBoardDB.minimized)
            TB:UpdateBrowse()
        elseif event == "PLAYER_ENTERING_WORLD" then
            TB:UpdateBrowse()
            if not TB.hasEnteredWorld then
                TB.hasEnteredWorld = 1
                DEFAULT_CHAT_FRAME:AddMessage(TB.COLORED_TITLE .. " loaded. Type |cffffffff/tb|r to open or |cffffffff/tb probe|r to resync.")
            end
        elseif event == "PLAYER_LEVEL_UP" then
            TB:RefreshOwnListingLevels(arg1)
            local volunteer = TB.GetOwnVolunteer and TB:GetOwnVolunteer()
            if volunteer and volunteer.enabled then TB:SetChainVolunteer(1) end
            TB:QueueOwnData(0)
            TB:UpdateBrowse()
        end
    end)
end

TB:Initialize()
