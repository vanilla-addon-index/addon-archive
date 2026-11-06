-- VimWowSettings: one Vanilla-sized options window for VimWow and its side
-- addons (VimFinder, VimBag, VimMap). Each addon registers a tab along the
-- bottom of the window: its pages of options and its key bindings, kept in
-- the addon's own SavedVariables table. Moved out of VimWow/settings_ui.lua
-- (0.1.84) so each addon carries its settings without VimWow.
--
--   VimWowSettings:Register({
--       id = "VimBag", name = "Bags", order = 200,
--       db = function() return VimBagDB end,
--       pages = {{name = "General", options = {...}}},
--       bindings = {{action = "VIMBAGOPEN", defaults = {"CTRL-B"}}},
--       onChange = function(key) end,
--   })
-- onChange runs, for every tab, after a checkbox, choice or binding changes
-- and when a key capture starts or stops; a slider only writes db().
--   local first, second = VimWowSettings:BindingKeys("VimBag", action, defaults)
--
-- Option format: {key, label, help} is a checkbox; slider = {low, high,
-- step} (with an optional format) is a slider; checked/unchecked names the
-- checkbox's two values; choices cycle through values. A page without
-- options lists the tab's bindings; a tab with bindings and no such page
-- gets one named Bindings. db().bindings[action] holds {key 1, key 2} and
-- db().disabledBindings[action] marks an action turned off.
-- disabled = function() ... end greys an option out while it returns true.
-- A page with draw = function(content) ... end draws itself: the window
-- gives it an empty frame below the page buttons, hidden with the page,
-- and calls draw each time the page renders (VimAddons' tab, 0.1.4).
--
-- VimWowSettings' own tab, General, keeps the settings every addon reads
-- (VimWowSettingsDB): High contrast, VimWowSettings:HighContrast().
VimWowSettings = VimWowSettings or {}
local UI = VimWowSettings
UI.addons = UI.addons or {}

local function button(parent, label, width, height, x, y, handler)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetWidth(width)
    control:SetHeight(height)
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    control:SetText(label)
    control:SetScript("OnClick", handler)
    return control
end

local function label(parent, value, x, y)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    text:SetText(value)
    return text
end

local function record(id)
    for _, entry in ipairs(UI.addons) do
        if entry.id == id then return entry end
    end
end

local function store(entry)
    local db = entry and entry.spec.db and entry.spec.db()
    return db or {}
end

-- The shown tab's SavedVariables table.
local function db()
    return store(UI.current)
end

-- Every addon hears of a change: a capture blocks all their keys, and a new
-- binding or option may be any addon's.
local function changed(key)
    for _, entry in ipairs(UI.addons) do
        if entry.spec.onChange then entry.spec.onChange(key) end
    end
end

local function sortAddons()
    table.sort(UI.addons, function(a, b)
        local left, right = a.spec.order or 1000, b.spec.order or 1000
        if left ~= right then return left < right end
        return a.id < b.id
    end)
end

function UI:Register(spec)
    if type(spec) ~= "table" or not spec.id or not spec.name
        or type(spec.db) ~= "function" then
        error("VimWowSettings:Register needs id, name and db")
    end
    local entry = record(spec.id)
    if not entry then
        entry = {id = spec.id, page = 1, bindingPage = 1, rowCache = {}}
        table.insert(self.addons, entry)
    end
    entry.spec = spec
    entry.pages = spec.pages or {}
    entry.catalog = spec.bindings or {}
    local listsBindings = false
    for _, page in ipairs(entry.pages) do
        -- if not page.options then listsBindings = true end
        if not page.options and not page.draw then listsBindings = true end
    end
    if table.getn(entry.catalog) > 0 and not listsBindings then
        table.insert(entry.pages, {name = "Bindings"})
    end
    sortAddons()
    -- The window opens on the first tab (VimWow's when it is loaded) until
    -- it is shown.
    if not (self.frame and self.frame:IsVisible()) then self:Use(self.addons[1]) end
    if self.frame then self:BuildAddonTabs() end
    return entry
end

-- An addon's keys for an action: none when turned off, else the keys set
-- in its options, else the defaults.
function UI:BindingKeys(id, action, defaults)
    local saved = store(record(id))
    if saved.disabledBindings and saved.disabledBindings[action] then
        return nil, nil
    end
    local assigned = saved.bindings and saved.bindings[action]
    if assigned and assigned[1] then return assigned[1], assigned[2] end
    defaults = defaults or {}
    return defaults[1], defaults[2]
end

-- Shows `entry`'s tab. pages, tabs, page, bindingPage and rowCache always
-- describe the shown tab.
function UI:Use(entry)
    if not entry then return end
    local old = self.current
    if old then old.page, old.bindingPage = self.page or old.page, self.bindingPage or old.bindingPage end
    self.current = entry
    self.pages = entry.pages
    self.bindings = entry.catalog
    self.page = entry.page or 1
    self.bindingPage = entry.bindingPage or 1
    self.rowCache = entry.rowCache
    self.tabs = entry.pageButtons or {}
end

local function suffix(text)
    return function(value) return tostring(value) .. text end
end
UI.Suffix = suffix

local function settingHandler(option)
    return function()
        if option.disabled and option.disabled() then UI:Render(); return end
        local saved = db()
        if option.choices then
            local position = 0
            for i, candidate in ipairs(option.choices) do
                if candidate == saved[option.key] then
                    position = i; break
                end
            end
            -- saved[option.key] = option.choices[position
            --     % table.getn(option.choices) + 1]
            -- Lua 5.0 has no % operator (ClassicAPI transpiles it); the
            -- position is never negative, so math.mod gives the same.
            saved[option.key] = option.choices[math.mod(position,
                table.getn(option.choices)) + 1]
        -- A two-value checkbox switches between its named values.
        elseif option.checked then
            saved[option.key] = saved[option.key] == option.checked
                and option.unchecked or option.checked
        else
            saved[option.key] = not saved[option.key]
        end
        changed(option.key)
        UI:Render()
    end
end

-- A slider shows its value with the option's format, or as a multiple.
local function sliderText(option, value)
    if option.format then return option.format(value) end
    return value .. "x"
end

-- Sliders store their value rounded to the slider step.
local function sliderHandler(option, slider)
    return function()
        local step = option.slider[3]
        local value = math.floor(slider:GetValue() / step + 0.5) * step
        local saved = db()
        if saved[option.key] == value then return end
        saved[option.key] = value
        if slider.valueText then
            slider.valueText:SetText(sliderText(option, value))
        end
        -- The camera keys read the speed each time one is pressed.
    end
end

local function pageHandler(index)
    return function()
        UI.page = index
        UI:Render()
    end
end

local function addonHandler(index)
    return function()
        UI:Use(UI.addons[index])
        UI:Render()
    end
end

local function bindingHandler(method, spec, slot)
    return function() UI[method](UI, spec, slot) end
end

function UI:Effective(spec)
    return self:BindingKeys(self.current.id, spec.action, spec.defaults)
end

function UI:StopCapture()
    self.captureAction = nil
    self.captureSlot = nil
    self.pendingKey = nil
    VimWowBindingsCapturing = false
    if self.capture then self.capture:EnableKeyboard(false); self.capture:Hide() end
    changed()
end

function UI:StartCapture(spec, slot)
    self.captureAction = spec.action
    self.captureSpec = spec
    self.captureSlot = slot
    self.pendingKey = nil
    VimWowBindingsCapturing = true
    self.captureMessage:SetText("Press a key for "
        .. (getglobal("BINDING_NAME_" .. spec.action) or spec.action)
        .. ". Esc cancels.")
    self.capture:Show()
    self.capture:EnableKeyboard(true)
    changed()
end

local function modifiedKey(key)
    if not key or key == "LSHIFT" or key == "RSHIFT"
        or key == "LCTRL" or key == "RCTRL"
        or key == "LALT" or key == "RALT"
        or key == "SHIFT" or key == "CTRL" or key == "ALT" then return end
    local prefix = ""
    if IsControlKeyDown and IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsAltKeyDown and IsAltKeyDown() then prefix = prefix .. "ALT-" end
    if IsShiftKeyDown and IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    return prefix .. string.upper(key)
end

-- ------------------------------------------------------------ stock keys
-- A client without ClassicAPI.dll has no override bindings. The side
-- addons then take their window's keys through a capture frame, and their
-- open key is a game key binding (their Bindings.xml).

-- A key written as this window writes a pressed one: CTRL-, ALT-, SHIFT-,
-- in that order, whatever order `key` names them in.
function UI.NormalKey(key)
    if type(key) ~= "string" or key == "" then return end
    local held, rest = {}, key
    while true do
        local _, _, modifier, tail = string.find(rest, "^(%u+)%-(.+)$")
        if modifier == "CTRL" or modifier == "ALT" or modifier == "SHIFT" then
            held[modifier] = true
            rest = tail
        else
            break
        end
    end
    local prefix = ""
    if held.CTRL then prefix = prefix .. "CTRL-" end
    if held.ALT then prefix = prefix .. "ALT-" end
    if held.SHIFT then prefix = prefix .. "SHIFT-" end
    return prefix .. string.upper(rest)
end

-- A capture frame: SetKeys({[key] = button}) gives it those keys. While it
-- has any, it takes the whole keyboard (the game's own keys wait until it
-- gives the keyboard back) and a key it has clicks its button.
function UI:NewKeyCapture(name)
    local capture = CreateFrame("Frame", name, UIParent)
    capture:SetFrameStrata("TOOLTIP")
    capture:EnableKeyboard(false)
    capture.keys = {}
    capture:SetScript("OnKeyDown", function(_, raw)
        local key = modifiedKey(raw or arg1)
        local target = key and capture.keys[key]
        if target then target:Click() end
    end)
    function capture:SetKeys(keys)
        local normal, any = {}, false
        for key, target in pairs(keys or {}) do
            local written = UI.NormalKey(key)
            if written and target then
                normal[written] = target
                any = true
            end
        end
        self.keys = normal
        self:EnableKeyboard(any)
    end
    return capture
end

-- Puts an addon's open keys on the game's key bindings, to its Bindings.xml
-- command `action`: a key is taken only while no other binding has it, and
-- a key no longer wanted is given back. `held` (kept in the addon's saved
-- variables) lists the keys bound this way. Call it only once the client's
-- own bindings have loaded (after PLAYER_ENTERING_WORLD).
function UI.ClaimGameKeys(held, action, first, second)
    if type(SetBinding) ~= "function" or type(GetBindingAction) ~= "function" then
        return
    end
    local wanted = {}
    if first then wanted[first] = true end
    if second then wanted[second] = true end
    local changed = false
    for key in pairs(held) do
        if not wanted[key] then
            if GetBindingAction(key) == action then
                SetBinding(key)
                changed = true
            end
            held[key] = nil
        end
    end
    for key in pairs(wanted) do
        local owner = GetBindingAction(key)
        if owner == nil or owner == "" then
            SetBinding(key, action)
            changed = true
            held[key] = true
        elseif owner == action then
            held[key] = true
        end
    end
    if changed and type(SaveBindings) == "function" then
        SaveBindings(type(GetCurrentBindingSet) == "function"
            and GetCurrentBindingSet() or 1)
    end
end

function UI:CaptureKey(raw)
    if raw == "ESCAPE" then self:StopCapture(); self:Render(); return end
    local key = modifiedKey(raw)
    if not key or not self.captureAction then return end
    local owner = GetBindingAction and GetBindingAction(key) or nil
    if owner == "" or owner == "UNKNOWN" then owner = nil end
    if owner and self.pendingKey ~= key then
        self.pendingKey = key
        self.captureMessage:SetText(key .. " is bound to " .. owner
            .. ". Press it again to use it for " .. self.current.spec.name
            .. " while active; the game binding stays intact. Esc cancels.")
        return
    end
    local saved = db()
    saved.bindings = saved.bindings or {}
    -- An action never set starts from the keys it has now, so setting key 2
    -- keeps key 1.
    local pair = saved.bindings[self.captureAction]
        or {self:Effective(self.captureSpec)}
    pair[self.captureSlot] = key
    -- BindingKeys reads a saved pair only when key 1 is set, so a repeated
    -- key and a lone key 2 both end up as key 1.
    if pair[1] == pair[2] then pair[2] = nil end
    if not pair[1] then pair[1], pair[2] = pair[2], nil end
    saved.bindings[self.captureAction] = pair
    if saved.disabledBindings then
        saved.disabledBindings[self.captureAction] = nil
    end
    self:StopCapture()
    self:Render()
end

function UI:ResetBinding(spec)
    local saved = db()
    if saved.bindings then saved.bindings[spec.action] = nil end
    if saved.disabledBindings then saved.disabledBindings[spec.action] = nil end
    changed()
    self:Render()
end

function UI:DisableBinding(spec)
    self:ResetBinding(spec)
    local saved = db()
    saved.disabledBindings = saved.disabledBindings or {}
    saved.disabledBindings[spec.action] = true
    changed()
    self:Render()
end

function UI:ClearRows()
    for _, entry in ipairs(self.addons) do
        for _, row in pairs(entry.rowCache or {}) do row:Hide() end
        for _, tab in ipairs(entry.pageButtons or {}) do tab:Hide() end
    end
end

-- The page buttons along the top of a tab.
function UI:BuildPageButtons(entry)
    if entry.pageButtons then return end
    entry.pageButtons = {}
    for index, page in ipairs(entry.pages) do
        local tab = button(self.frame, page.name, 104, 26,
            23 + (index - 1) * 110, -55, pageHandler(index))
        tab:Hide()
        table.insert(entry.pageButtons, tab)
    end
    if entry == self.current then self.tabs = entry.pageButtons end
end

-- One bottom tab per addon, as on the character window; [ and ] switch
-- them.
function UI:BuildAddonTabs()
    local count = table.getn(self.addons)
    self.addonTabs = self.addonTabs or {}
    for index = 1, count do
        local tab = self.addonTabs[index]
        if not tab then
            tab = CreateFrame("Button", "VimWowSettingsFrameTab" .. index,
                self.frame, "CharacterFrameTabButtonTemplate")
            tab:SetID(index)
            if index == 1 then
                tab:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", 15, 7)
            else
                tab:SetPoint("LEFT", self.addonTabs[index - 1], "RIGHT", -16, 0)
            end
            self.addonTabs[index] = tab
        end
        tab:SetText(self.addons[index].spec.name)
        tab:SetScript("OnClick", addonHandler(index))
        if PanelTemplates_TabResize then PanelTemplates_TabResize(0, tab) end
        tab:Show()
    end
    for index = count + 1, table.getn(self.addonTabs) do
        self.addonTabs[index]:Hide()
    end
    self.frame.numTabs = count
    for _, entry in ipairs(self.addons) do self:BuildPageButtons(entry) end
end

function UI:Render()
    if not self.frame or not self.current then return end
    local entry = self.current
    entry.page, entry.bindingPage = self.page, self.bindingPage
    local spec = entry.spec
    self.statusLabel:SetText(spec.status and spec.status() or "")
    self.credit:SetText(spec.credit or "")
    for index, other in ipairs(self.addons) do
        if other == entry and PanelTemplates_SetTab then
            PanelTemplates_SetTab(self.frame, index)
        end
    end
    self:ClearRows()
    for index, tab in ipairs(self.tabs) do
        tab:Show()
        if index == self.page then tab:LockHighlight()
        else tab:UnlockHighlight() end
    end
    local saved = db()
    local catalog = self.bindings
    local extra = spec.bindingsButton
    -- A page that draws itself gets its own frame.
    local shown = self.pages[self.page]
    if shown.draw then
        self.pageLabel:SetText(shown.name)
        self.prev:Hide(); self.next:Hide(); self.suggestions:Hide()
        local cacheKey = "draw:" .. self.page
        local content = self.rowCache[cacheKey]
        if not content then
            content = CreateFrame("Frame", nil, self.frame)
            content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 24, -91)
            content:SetWidth(654); content:SetHeight(405)
            self.rowCache[cacheKey] = content
        end
        content:Show()
        shown.draw(content)
    -- The page without options is the bindings list.
    -- if not self.pages[self.page].options then
    elseif not shown.options then
        local start = (self.bindingPage - 1) * 8 + 1
        for n = 0, 7 do
            local binding = catalog[start + n]
            if binding then
                local cacheKey = "binding:" .. (start + n)
                local row = self.rowCache[cacheKey]
                if not row then
                    row = CreateFrame("Frame", nil, self.frame)
                    row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 24,
                        -91 - n * 49)
                    row:SetWidth(654); row:SetHeight(45)
                    label(row, getglobal("BINDING_NAME_" .. binding.action)
                        or binding.action, 0, -6)
                    row.first = button(row, "", 112, 22, 318, -2,
                        bindingHandler("StartCapture", binding, 1))
                    row.second = button(row, "", 112, 22, 434, -2,
                        bindingHandler("StartCapture", binding, 2))
                    button(row, "Default", 55, 22, 550, -2,
                        bindingHandler("ResetBinding", binding))
                    button(row, "Off", 42, 22, 608, -2,
                        bindingHandler("DisableBinding", binding))
                    self.rowCache[cacheKey] = row
                end
                local first, second = self:Effective(binding)
                local disabled = saved.disabledBindings
                    and saved.disabledBindings[binding.action]
                row.first:SetText(disabled and "Off" or first or "Set key 1")
                row.second:SetText(disabled and "Off" or second or "Set key 2")
                row:Show()
            end
        end
        self.pageLabel:SetText("Bindings " .. self.bindingPage .. "/"
            .. math.max(1, math.ceil(table.getn(catalog) / 8)))
        self.prev:Show(); self.next:Show()
        if extra then
            self.suggestions:SetText(extra.label)
            self.suggestions:Show()
        else
            self.suggestions:Hide()
        end
    else
        self.pageLabel:SetText(self.pages[self.page].name)
        self.prev:Hide(); self.next:Hide(); self.suggestions:Hide()
        for index, option in ipairs(self.pages[self.page].options) do
            local cacheKey = "setting:" .. self.page .. ":" .. index
            local row = self.rowCache[cacheKey]
            if not row then
                row = CreateFrame("Frame", nil, self.frame)
                -- Seven rows fit above the page label.
                row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 42,
                    -105 - (index - 1) * 56)
                row:SetWidth(610); row:SetHeight(48)
                -- A checkbox sits left of its label, as in the game's options.
                local checkbox = not option.slider and not option.choices
                local textX = checkbox and 34 or 0
                -- label(row, option.label, textX, -4)
                row.label = label(row, option.label, textX, -4)
                local help = row:CreateFontString(nil, "OVERLAY",
                    "GameFontHighlightSmall")
                help:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -24)
                help:SetText(option.help)
                if option.slider then
                    -- local name = "VimWowSettingSlider" .. option.key
                    -- VimWow's slider names stay as they were; other tabs
                    -- add their id.
                    local name = "VimWowSettingSlider"
                        .. (entry.id == "VimWow" and "" or entry.id) .. option.key
                    local slider = CreateFrame("Slider", name, row,
                        "OptionsSliderTemplate")
                    slider:SetWidth(170); slider:SetHeight(17)
                    slider:SetPoint("TOPLEFT", row, "TOPLEFT", 400, -10)
                    slider:SetMinMaxValues(option.slider[1], option.slider[2])
                    slider:SetValueStep(option.slider[3])
                    -- Keyboard steps use the option's step.
                    slider.vimwowStep = option.slider[3]
                    local low = getglobal(name .. "Low")
                    local high = getglobal(name .. "High")
                    if low then low:SetText(sliderText(option, option.slider[1])) end
                    if high then high:SetText(sliderText(option, option.slider[2])) end
                    slider.valueText = getglobal(name .. "Text")
                    slider:SetScript("OnValueChanged",
                        sliderHandler(option, slider))
                    row.slider = slider
                elseif option.choices then
                    row.valueButton = button(row, "", 110, 27, 440, -8,
                        settingHandler(option))
                else
                    local check = CreateFrame("CheckButton",
                        "VimWowSettingCheck" .. (entry.id == "VimWow" and "" or entry.id)
                            .. option.key, row,
                        "OptionsCheckButtonTemplate")
                    check:SetWidth(26); check:SetHeight(26)
                    check:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
                    local toggle = settingHandler(option)
                    check:SetScript("OnClick", function()
                        toggle()
                        if type(PlaySound) == "function" then
                            PlaySound(check:GetChecked()
                                and "igMainMenuOptionCheckBoxOn"
                                or "igMainMenuOptionCheckBoxOff")
                        end
                    end)
                    row.check = check
                end
                self.rowCache[cacheKey] = row
            end
            local value = saved[option.key]
            if row.slider then
                row.slider:SetValue(value)
                if row.slider.valueText then
                    row.slider.valueText:SetText(sliderText(option, value))
                end
            elseif row.check then
                local checked
                if option.checked then checked = value == option.checked
                else checked = value and true or false end
                row.check:SetChecked(checked and 1 or nil)
            else
                local caption
                if option.choices then
                    caption = option.captions and option.captions[value]
                        or option.format and option.format(value)
                        or tostring(value)
                else
                    caption = value and "On" or "Off"
                end
                row.valueButton:SetText(caption)
            end
            -- An option another one decides for greys out.
            local off = option.disabled and option.disabled() and true or false
            local control = row.check or row.valueButton
            if control then
                if off then control:Disable() else control:Enable() end
            end
            if off then row.label:SetTextColor(0.5, 0.5, 0.5)
            else row.label:SetTextColor(1, 0.82, 0) end
            row:Show()
        end
    end
end

function UI:Initialize()
    if self.frame then return end
    local frame = CreateFrame("Frame", "VimWowSettingsFrame", UIParent)
    frame:SetWidth(700); frame:SetHeight(555)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}})
    label(frame, "VimWow Options", 24, -20)
    local credit = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    credit:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -38)
    self.credit = credit
    -- A close cross like other panels; keyboard navigation skips it, since
    -- Esc closes the window.
    local close = CreateFrame("Button", "VimWowSettingsFrameCloseButton", frame,
        "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() self:Hide() end)
    self.frame = frame
    self.statusLabel = label(frame, "", 33, -530)
    self.pageLabel = label(frame, "", 33, -512)
    self.prev = button(frame, "Previous", 80, 24, 490, -503,
        function() self.bindingPage = math.max(1, self.bindingPage - 1)
            self:Render() end)
    self.next = button(frame, "Next", 80, 24, 582, -503,
        function()
            self.bindingPage = math.min(math.max(1,
                math.ceil(table.getn(self.bindings) / 8)), self.bindingPage + 1)
            self:Render()
        end)
    -- A tab's own button on its bindings page (VimWow: the game keys its
    -- keys cover). Options closes first, so a popup is not hidden behind it.
    self.suggestions = button(frame, "", 150, 24, 330, -503,
        function()
            local extra = self.current and self.current.spec.bindingsButton
            self:Hide()
            if extra and extra.onClick then extra.onClick() end
        end)
    local capture = CreateFrame("Frame", "VimWowBindingCapture", UIParent)
    capture:SetAllPoints(UIParent)
    capture:SetFrameStrata("FULLSCREEN_DIALOG")
    capture:EnableMouse(true)
    capture:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background"})
    capture:SetBackdropColor(0, 0, 0, 0.8)
    self.captureMessage = label(capture, "", 100, -200)
    capture:SetScript("OnKeyDown", function(_, key)
        self:CaptureKey(key or arg1)
    end)
    capture:EnableKeyboard(false)
    capture:Hide()
    self.capture = capture
    frame:SetScript("OnHide", function() self:StopCapture() end)
    frame:Hide()
    self:BuildAddonTabs()
    if self.current then self.tabs = self.current.pageButtons end
    UISpecialFrames = UISpecialFrames or {}
    table.insert(UISpecialFrames, "VimWowSettingsFrame")
end

-- Opens the window, on addon `id`'s tab when given.
function UI:Show(id)
    self:Initialize()
    if id and record(id) then self:Use(record(id)) end
    self.frame:Show()
    self:Render()
end

function UI:Hide()
    if self.frame then self.frame:Hide() end
end

-- ------------------------------------------------------------ shared

-- Settings every Vim addon reads, on VimWowSettings' own tab (the user,
-- 2026-10-14). High contrast: the 1.12 client has no accessibility or
-- contrast setting to follow, so this is the one; VimQuest's quest areas
-- turn blue with it.
function UI:HighContrast()
    return VimWowSettingsDB ~= nil and VimWowSettingsDB.highContrast == true
end

UI:Register({
    id = "VimWowSettings", name = "General", order = 10000,
    db = function()
        VimWowSettingsDB = VimWowSettingsDB or {}
        return VimWowSettingsDB
    end,
    pages = {{name = "Accessibility", options = {
        {key = "highContrast", label = "High contrast",
            help = "Colours that stand out more on the map's parchment: VimQuest's quest areas turn blue."},
    }}},
})

local menuInstaller = CreateFrame("Frame", "VimWowMenuInstaller", UIParent)
menuInstaller:RegisterEvent("PLAYER_LOGIN")
menuInstaller:SetScript("OnEvent", function()
    UI.menuReadyAt = GetTime() + 0.3
end)
menuInstaller:SetScript("OnUpdate", function()
    if UI.menuInstalled or not UI.menuReadyAt
        or GetTime() < UI.menuReadyAt then return end
    if QuestieOcto and QuestieOcto.GameMenu
        and not QuestieOcto.GameMenu.installed then return end
    if not GameMenuFrame or not GameMenuButtonUIOptions
        or not GameMenuButtonKeybindings then return end
    local anchor = GameMenuButtonQuestieOctoOptions
        or GameMenuButtonAdvancedOptions or GameMenuButtonUIOptions
    local item = CreateFrame("Button", "GameMenuButtonVimWowOptions",
        GameMenuFrame, "GameMenuButtonTemplate")
    item:SetText("VimWow Options")
    item:SetPoint("TOP", anchor, "BOTTOM", 0, -1)
    item:SetScript("OnClick", function()
        if HideUIPanel then HideUIPanel(GameMenuFrame)
        else GameMenuFrame:Hide() end
        UI:Show()
    end)
    GameMenuButtonKeybindings:ClearAllPoints()
    GameMenuButtonKeybindings:SetPoint("TOP", item, "BOTTOM", 0, -1)
    GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + 32)
    UI.menuInstalled = true
    menuInstaller:SetScript("OnUpdate", nil)
end)
