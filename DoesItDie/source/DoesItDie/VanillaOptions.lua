local ns = DoesItDieVanilla
if not ns.ready then return end
local function status()
    local hp, maximum, provider = ns.health("target")
    local version, build, date, interface = GetBuildInfo()
    ns.print("Client " .. tostring(version) .. " build " .. tostring(build) .. " interface " .. tostring(interface or INTERFACE_VERSION or "not reported"))
    ns.print("ClassicAPI: " .. tostring(CLASSIC_API_VERSION) .. "; health: " .. provider)
    ns.print("Target HP: " .. tostring(hp) .. "/" .. tostring(maximum))
    ns.display.skullStatus()
    if UnitXP then
        local ok, info = pcall(UnitXP, "version", "additionalInformation")
        if ok and type(info) == "string" then ns.print("UnitXP provider: " .. info) end
    end
    ns.trace("STATUS ClassicAPI=" .. tostring(CLASSIC_API_VERSION) .. " health=" .. provider
        .. " HP=" .. tostring(hp) .. "/" .. tostring(maximum))
end
local pages = {}
ns.optionPanels = pages

local function text(parent, value, x, y, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(value)
    return label
end

local function update(page)
    for _, control in ipairs(page.controls) do control:SetChecked(control.get()) end
end

local function page(name, parent, title)
    local panel = CreateFrame("Frame", nil, UIParent)
    panel.name, panel.parent = name, parent
    panel.controls = {}
    text(panel, title, 16, -16, "GameFontNormalLarge")
    panel.refresh = function()
        if not panel.saved then
            panel.saved = {}
            for i, control in ipairs(panel.controls) do panel.saved[i] = control.get() end
        end
        update(panel)
    end
    panel.okay = function() panel.saved = nil end
    panel.cancel = function()
        if not panel.saved then return end
        for i, control in ipairs(panel.controls) do control.set(panel.saved[i]) end
        panel.saved = nil
        update(panel); ns.refresh()
    end
    panel.default = function()
        -- Capture before changing defaults even if the host omitted refresh.
        panel.refresh()
        for _, control in ipairs(panel.controls) do control.set(control.default) end
        update(panel); ns.refresh()
    end
    InterfaceOptions_AddCategory(panel)
    table.insert(pages, panel)
    return panel
end

local function check(panel, label, key, y, mode)
    local control = CreateFrame("CheckButton", nil, panel)
    control:SetWidth(24); control:SetHeight(24)
    control:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, y)
    control:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    control:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    control:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    local title = control:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", control, "RIGHT", 5, 0)
    title:SetText(label)
    control.key = key
    if mode then
        control.get = function() return ns.db[key] ~= "off" end
        control.set = function(value) ns.db[key] = value and "markerIcon" or "off" end
        control.default = ns.DEFAULTS[key] ~= "off"
    else
        control.get = function() return ns.db[key] end
        control.set = function(value) ns.db[key] = value and true or false end
        control.default = ns.DEFAULTS[key]
    end
    control:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if not panel.saved then panel.refresh() end
        control.set(checked)
        ns.refresh()
    end)
    table.insert(panel.controls, control)
    return control
end

local function button(panel, label, x, y, action)
    local control = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    control:SetWidth(170); control:SetHeight(24)
    control:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    control:SetText(label)
    control:SetScript("OnClick", action)
end

ns.registerOptions = function()
    if #pages > 0 then return true end
    if not InterfaceOptions_AddCategory then return false end
    local root = page("DoesItDie", nil, "DoesItDie - Target frame")
    check(root, "Enable target frame display", "targetEnabled", -55)
    check(root, "Show DoTs label above the mob name", "showLabel", -88)
    check(root, "Show lethal skull on the portrait", "showSkull", -121)
    check(root, "Shade remaining DoT damage", "showMarkers", -154)
    text(root, "Changes preview immediately. Okay saves; Cancel restores.", 20, -205, "GameFontHighlightSmall")
    text(root, "Unknown enemy HP disables skulls and shading.", 20, -225, "GameFontHighlightSmall")
    button(root, "Preview skull (5 sec)", 20, -260, function() ns.display.testSkull(5) end)
    button(root, "Print diagnostics", 200, -260, status)
    check(root, "Disable all displays while in a party", "disableInParty", -300)
    check(root, "Disable all displays while in a raid", "disableInRaid", -333)

    local plate = page("Nameplates", "DoesItDie", "DoesItDie - Nameplates")
    check(plate, "Enable nameplate display", "nameplateMode", -55, true)
    check(plate, "Show DoTs label below the border", "plateShowLabel", -88)
    check(plate, "Show lethal skull beside the bar", "plateShowSkull", -121)
    check(plate, "Shade remaining DoT damage", "plateShowMarkers", -154)
    text(plate, "Nameplate settings are independent of the target frame.", 20, -205, "GameFontHighlightSmall")

    local focus = page("Focus frame", "DoesItDie", "DoesItDie - Focus frame")
    check(focus, "Enable focus display", "focusMode", -55, true)
    check(focus, "Show DoTs label", "focusShowLabel", -88)
    check(focus, "Show lethal skull", "focusShowSkull", -121)
    check(focus, "Shade remaining DoT damage", "focusShowMarkers", -154)
    text(focus, "Requires a focus health bar provided by your UI.", 20, -205, "GameFontHighlightSmall")

    local tracking = page("Tracking", "DoesItDie", "DoesItDie - Tracking")
    check(tracking, "Estimate damage while casting", "estimateDuringCast", -55)
    check(tracking, "Echo debug traces to chat", "debug", -88)
    text(tracking, "Wait for the first observed tick:", 20, -135)
    for i, item in ipairs({{"off", "Never (estimate immediately)"},
        {"unsure", "Only when the estimate is uncertain"}, {"always", "Always"}}) do
        local value = item[1]
        local control = check(tracking, item[2], "waitFirstTick", -150-i*30)
        control.get = function() return ns.db.waitFirstTick == value end
        control.set = function(checked) if checked then ns.db.waitFirstTick = value end end
        control.default = ns.DEFAULTS.waitFirstTick == value
        control:SetScript("OnClick", function()
            if not tracking.saved then tracking.refresh() end
            ns.db.waitFirstTick = value
            update(tracking); ns.refresh()
        end)
    end
    button(tracking, "List learned tick sizes", 20, -295, function() ns.toggleTickViewer() end)
    button(tracking, "Forget learned ticks", 200, -295, function() ns.resetLearnedTicks() end)
    text(tracking, "Forgetting learned ticks takes effect immediately and cannot be undone.", 20, -335, "GameFontHighlightSmall")
    return true
end

ns.toggleTickViewer = function()
    local list = ns.learnedTickList()
    if #list == 0 then ns.print("No learned ticks yet.") end
    for _, entry in ipairs(list) do
        ns.print((entry.name or tostring(entry.spellID)) .. ": " .. tostring(entry.perTick)
            .. " per tick" .. (entry.comboPoints and (" at " .. entry.comboPoints .. " CP") or ""))
    end
end
ns.openOptions = function()
    if ns.registerOptions() and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(pages[1])
    else
        ns.print("ClassicAPI's addon options UI is unavailable; check that its embedded addon loaded.")
    end
end

local original = SlashCmdList.DOESITDIE
SlashCmdList.DOESITDIE = function(message)
    local cmd, value = string.match(strtrim(message or ""), "^(%S+)%s*(.-)$")
    cmd = strlower(cmd or "")
    if cmd == "status" then return status() end
    if cmd == "siphon" then return ns.probeSiphon() end
    if cmd == "bar" then
        ns.db.customHealthBar = value or ""
        ns.display.attach(); ns.refresh()
        return ns.print("Target bar: " .. (value ~= "" and value or "Blizzard default"))
    end
    if cmd == "wait" then
        if value ~= "always" and value ~= "off" and value ~= "unsure" then
            return ns.print("Usage: /did wait always|off|unsure")
        end
        ns.db.waitFirstTick = value
        return ns.print("Wait for first tick: " .. value)
    end
    if cmd == "help" then
        ns.print("/did status; /did bar Global.Frame.path; /did bar (restore default); /did wait always|off|unsure")
    end
    original(message)
end
