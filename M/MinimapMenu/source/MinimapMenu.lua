-- MinimapMenu - a small, Vanilla-compatible minimap button collector.
-- The original buttons are reparented into the menu so unusual click, drag,
-- mouse-down, and mouse-up handlers continue to work normally.

local addon = CreateFrame("Frame", "MinimapMenuEventFrame")
local buttons = {}
local known = {}
local rows = {}
local elapsed = 0
local scanElapsed = 0
local ready = false
local conflictReported = false

local ignored = {
    "MinimapMenu", "MinimapBackdrop", "MinimapZoomIn", "MinimapZoomOut",
    "MiniMapTracking", "MiniMapMail", "MiniMapPing", "MiniMapMeetingStone",
    "MiniMapBattlefield", "TimeManagerClock", "GameTimeFrame", "Clock",
    "Timer", "GatherNote", "MiniNotePOI", "QuestieNote", "pfMiniMapPin",
    "RecipeRadarMinimapIcon", "FWGMinimapPOI", "BookOfTracksFrame",
    "MBB_MinimapButtonFrame"
}

local explicit = {
    "DPSMate_MiniMap", "TWMinimapShopFrame", "TWMiniMapBattlefieldFrame",
    "LFT_Minimap"
}

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99MinimapMenu:|r " .. message)
    end
end

local function IsIgnored(name)
    if not name then return true end
    -- Turtle's finder contains the name of Blizzard's protected battlefield
    -- frame, but it is a separate addon button that we explicitly support.
    if name == "TWMiniMapBattlefieldFrame" then return false end
    local i
    for i = 1, table.getn(ignored) do
        if string.find(name, ignored[i], 1, true) then return true end
    end
    return false
end

local function HasMouseAction(frame)
    if not frame or not frame.HasScript then return false end
    return (frame:HasScript("OnClick") and frame:GetScript("OnClick"))
        or (frame:HasScript("OnMouseDown") and frame:GetScript("OnMouseDown"))
        or (frame:HasScript("OnMouseUp") and frame:GetScript("OnMouseUp"))
end

local function FindButton(frame)
    if not frame or IsIgnored(frame:GetName()) then return nil end
    if HasMouseAction(frame) then return frame end

    local children = { frame:GetChildren() }
    local i
    for i = 1, table.getn(children) do
        if children[i]:GetName() and not IsIgnored(children[i]:GetName()) and HasMouseAction(children[i]) then
            return children[i]
        end
    end
    return nil
end

local labelOverrides = {
    DPSMate_MiniMap = "DPSMate",
    TWMinimapShopFrame = "Turtle WoW Shop",
    TWMiniMapBattlefieldFrame = "Battleground Finder",
    LFT_Minimap = "Looking For Turtles"
}

local function MakeLabel(name)
    if labelOverrides[name] then return labelOverrides[name] end
    local text = name
    text = string.gsub(text, "^LibDBIcon10_", "")
    text = string.gsub(text, "^LibDBIcon_", "")
    text = string.gsub(text, "Mini[Mm]ap", "")
    text = string.gsub(text, "[Mm]inimap", "")
    text = string.gsub(text, "Button", "")
    text = string.gsub(text, "Icon", "")
    text = string.gsub(text, "Frame", "")
    text = string.gsub(text, "_", " ")
    text = string.gsub(text, "(%l)(%u)", "%1 %2")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if text == "" then text = name end
    return text
end

local menu = CreateFrame("Frame", "MinimapMenuPopup", UIParent)
menu:SetWidth(220)
menu:SetHeight(48)
menu:SetFrameStrata("DIALOG")
menu:SetFrameLevel(100)
menu:SetClampedToScreen(true)
menu:SetMovable(true)
menu:EnableMouse(true)
menu:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
menu:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
menu:SetBackdropBorderColor(0.65, 0.65, 0.65, 1)
menu:Hide()

local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", menu, "TOPLEFT", 12, -10)
title:SetText("Minimap Menu")

-- The header is a dedicated drag handle so rows and their original addon
-- buttons retain all of their own mouse behavior.
local header = CreateFrame("Button", "MinimapMenuHeader", menu)
header:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -5)
header:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -34, -5)
header:SetHeight(24)
header:SetFrameLevel(menu:GetFrameLevel() + 2)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function() menu:StartMoving() end)
header:SetScript("OnDragStop", function()
    menu:StopMovingOrSizing()
    local x, y = menu:GetCenter()
    if x and y then
        MinimapMenuDB.menuX = x
        MinimapMenuDB.menuY = y
    end
end)

-- Match Questline's compact native close button treatment.
local close = CreateFrame("Button", "MinimapMenuCloseButton", menu)
close:SetWidth(18)
close:SetHeight(18)
close:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -10, -8)
close:SetFrameLevel(menu:GetFrameLevel() + 3)
local closeUp = close:CreateTexture(nil, "ARTWORK")
closeUp:SetAllPoints(close)
closeUp:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
closeUp:SetTexCoord(.2, .75, .25, .75)
local closeDown = close:CreateTexture(nil, "ARTWORK")
closeDown:SetAllPoints(close)
closeDown:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
closeDown:SetTexCoord(.2, .75, .25, .75)
local closeHover = close:CreateTexture(nil, "HIGHLIGHT")
closeHover:SetAllPoints(close)
closeHover:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
closeHover:SetTexCoord(.2, .75, .25, .75)
closeHover:SetBlendMode("ADD")
close:SetNormalTexture(closeUp)
close:SetPushedTexture(closeDown)
close:SetHighlightTexture(closeHover)
close:SetScript("OnClick", function() menu:Hide() end)

local empty = menu:CreateFontString(nil, "OVERLAY", "GameFontDisable")
empty:SetPoint("TOPLEFT", menu, "TOPLEFT", 12, -31)
empty:SetText("No addon buttons found")

local launcher = CreateFrame("Button", "MinimapMenuButton", Minimap)
launcher:SetWidth(32)
launcher:SetHeight(32)
launcher:SetFrameStrata("MEDIUM")
launcher:SetMovable(true)
launcher:EnableMouse(true)
launcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
launcher:RegisterForDrag("LeftButton")

local border = launcher:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(54)
border:SetHeight(54)
border:SetPoint("TOPLEFT", launcher, "TOPLEFT", 0, 0)

-- Draw the menu glyph directly so it stays crisp and has no asset dependency.
local lineOffsets = { 4, 1, -2 }
local i
for i = 1, 3 do
    local line = launcher:CreateTexture(nil, "ARTWORK")
    line:SetTexture(1, 0.82, 0.25, 1)
    line:SetWidth(12)
    line:SetHeight(2)
    line:SetPoint("CENTER", launcher, "CENTER", 0, lineOffsets[i])
end

local highlight = launcher:CreateTexture(nil, "HIGHLIGHT")
highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
highlight:SetBlendMode("ADD")
highlight:SetWidth(32)
highlight:SetHeight(32)
highlight:SetPoint("CENTER", launcher, "CENTER", 0, 0)

local function PositionLauncher()
    launcher:ClearAllPoints()
    local angle = (MinimapMenuDB and MinimapMenuDB.angle) or 225
    local radius = 82
    launcher:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(math.rad(angle)) * radius,
        math.sin(math.rad(angle)) * radius)
end

local function SetMenuAnchor()
    menu:ClearAllPoints()
    if MinimapMenuDB and MinimapMenuDB.menuX and MinimapMenuDB.menuY then
        menu:SetPoint("CENTER", UIParent, "BOTTOMLEFT", MinimapMenuDB.menuX, MinimapMenuDB.menuY)
        return
    end
    local x = launcher:GetCenter()
    local screen = UIParent:GetWidth() / 2
    if x and x < screen then
        menu:SetPoint("TOPLEFT", launcher, "TOPRIGHT", 2, 8)
    else
        menu:SetPoint("TOPRIGHT", launcher, "TOPLEFT", -2, 8)
    end
end

local function RowFor(index)
    if rows[index] then return rows[index] end
    local row = CreateFrame("Button", "MinimapMenuRow" .. index, menu)
    row:SetWidth(196)
    row:SetHeight(34)
    row:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -25 - ((index - 1) * 34))
    row:SetFrameLevel(menu:GetFrameLevel() + 1)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints(row)
    row.hover:SetTexture(.08, .3, .5, .65)
    row.hover:Hide()
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetWidth(150)
    row.label:SetHeight(30)
    row.label:SetPoint("LEFT", row, "LEFT", 38, 0)
    row.label:SetJustifyH("LEFT")
    row:SetScript("OnEnter", function() this.hover:Show() end)
    row:SetScript("OnLeave", function() this.hover:Hide() end)
    row:SetScript("OnMouseDown", function()
        local target = this.target
        local handler = target and target:GetScript("OnMouseDown")
        if handler then
            local oldThis, oldArg1 = getglobal("this"), getglobal("arg1")
            setglobal("this", target); setglobal("arg1", arg1)
            pcall(handler)
            setglobal("this", oldThis); setglobal("arg1", oldArg1)
        end
    end)
    row:SetScript("OnMouseUp", function()
        local target = this.target
        local handler = target and target:GetScript("OnMouseUp")
        if handler then
            local oldThis, oldArg1 = getglobal("this"), getglobal("arg1")
            setglobal("this", target); setglobal("arg1", arg1)
            pcall(handler)
            setglobal("this", oldThis); setglobal("arg1", oldArg1)
        end
    end)
    row:SetScript("OnClick", function()
        local target = this.target
        local handler = target and target:GetScript("OnClick")
        -- A Vanilla button's default OnClick registration is left-button only.
        -- Forward the other buttons through their explicit mouse scripts above.
        if arg1 == "LeftButton" then
            if handler then
                local oldThis, oldArg1 = getglobal("this"), getglobal("arg1")
                setglobal("this", target); setglobal("arg1", arg1)
                pcall(handler)
                setglobal("this", oldThis); setglobal("arg1", oldArg1)
            end
            menu:Hide()
        end
    end)
    rows[index] = row
    return row
end

local function IsWithin(frame, ancestor)
    while frame do
        if frame == ancestor then return true end
        if not frame.GetParent then return false end
        frame = frame:GetParent()
    end
    return false
end

local function UpdateHover()
    local focus = GetMouseFocus and GetMouseFocus()
    local i, row
    for i = 1, table.getn(rows) do
        row = rows[i]
        if row:IsShown() and focus and (IsWithin(focus, row) or IsWithin(focus, row.target)) then
            row.hover:Show()
        else
            row.hover:Hide()
        end
    end
end

local function Layout()
    local visible = 0
    local i, frame, row
    for i = 1, table.getn(buttons) do
        frame = buttons[i]
        if frame and frame:IsShown() then
            visible = visible + 1
            row = RowFor(visible)
            row:Show()
            row.target = frame
            row.label:SetText(MakeLabel(frame:GetName()))
            -- Some minimap addons continuously restore their own parent or
            -- position. Reclaim the real button whenever the menu lays out.
            if frame:GetParent() ~= menu then frame:SetParent(menu) end
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", row, "LEFT", 17, 0)
            frame:SetFrameStrata("DIALOG")
            frame:SetFrameLevel(row:GetFrameLevel() + 2)
        end
    end
    for i = visible + 1, table.getn(rows) do
        rows[i].target = nil
        rows[i]:Hide()
    end
    if visible == 0 then empty:Show() else empty:Hide() end
    menu:SetHeight(visible == 0 and 52 or (visible * 34 + 32))
end

menu:SetScript("OnHide", function()
    -- A button that reparents itself while being dragged would otherwise stay
    -- visible at its last menu position after the popup closes.
    local i, frame
    for i = 1, table.getn(buttons) do
        frame = buttons[i]
        if frame then
            if frame:GetParent() ~= menu then frame:SetParent(menu) end
            frame:ClearAllPoints()
        end
    end
end)

local function Capture(frame)
    if not frame or not frame:GetName() or known[frame] then return end
    if frame == launcher or frame == menu or IsIgnored(frame:GetName()) then return end
    known[frame] = true
    table.insert(buttons, frame)
    frame:SetParent(menu)
end

local function ScanParent(parent)
    if not parent then return end
    local children = { parent:GetChildren() }
    local i, candidate
    for i = 1, table.getn(children) do
        candidate = FindButton(children[i])
        if candidate then Capture(candidate) end
    end
end

local function Conflict()
    if IsAddOnLoaded and IsAddOnLoaded("MinimapButtonBag") then
        if not conflictReported then
            Print("MinimapButtonBag is also enabled. Disable it and reload so the two addons do not compete for the same buttons.")
            conflictReported = true
        end
        return true
    end
    return false
end

local function Scan()
    if Conflict() then return end
    ScanParent(Minimap)
    ScanParent(MinimapBackdrop)
    local i
    for i = 1, table.getn(explicit) do
        Capture(FindButton(getglobal(explicit[i])))
    end
    table.sort(buttons, function(a, b) return MakeLabel(a:GetName()) < MakeLabel(b:GetName()) end)
    Layout()
end

local function ToggleMenu()
    if menu:IsShown() then
        menu:Hide()
    else
        Scan()
        SetMenuAnchor()
        Layout()
        menu:Show()
    end
end

launcher:SetScript("OnClick", function()
    if arg1 == "LeftButton" or arg1 == "RightButton" then ToggleMenu() end
end)

launcher:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("MinimapMenu")
    GameTooltip:AddLine("Left- or right-click to open the button menu.", 1, 1, 1)
    GameTooltip:AddLine("Drag to move.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
launcher:SetScript("OnLeave", function() GameTooltip:Hide() end)

launcher:SetScript("OnDragStart", function()
    this:SetScript("OnUpdate", function()
        local mx, my = GetCursorPosition()
        local cx, cy = Minimap:GetCenter()
        local scale = UIParent:GetEffectiveScale()
        mx, my = mx / scale, my / scale
        local angle = math.deg(math.atan2(my - cy, mx - cx))
        MinimapMenuDB.angle = angle
        PositionLauncher()
        if menu:IsShown() then SetMenuAnchor() end
    end)
end)
launcher:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)

addon:RegisterEvent("VARIABLES_LOADED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if not MinimapMenuDB then MinimapMenuDB = {} end
        PositionLauncher()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ready = true
        Scan()
    end
end)

addon:SetScript("OnUpdate", function()
    if not ready then return end
    elapsed = elapsed + arg1
    scanElapsed = scanElapsed + arg1
    if menu:IsShown() and elapsed > 0.2 then
        elapsed = 0
        Layout()
        UpdateHover()
    end
    if scanElapsed > 3 then
        scanElapsed = 0
        Scan()
    end
end)

SLASH_MINIMAPMENU1 = "/minimapmenu"
SLASH_MINIMAPMENU2 = "/mmenu"
SlashCmdList["MINIMAPMENU"] = function(command)
    command = string.lower(command or "")
    if command == "reset" then
        MinimapMenuDB.angle = 225
        MinimapMenuDB.menuX = nil
        MinimapMenuDB.menuY = nil
        PositionLauncher()
        if menu:IsShown() then SetMenuAnchor() end
        Print("position reset.")
    elseif command == "rescan" then
        Scan()
        Print(table.getn(buttons) .. " button(s) collected.")
    elseif command == "list" then
        Print(table.getn(buttons) .. " collected button(s):")
        local i
        for i = 1, table.getn(buttons) do Print("  " .. buttons[i]:GetName()) end
    else
        Print("/mmenu rescan, /mmenu list, /mmenu reset")
    end
end

if UISpecialFrames then table.insert(UISpecialFrames, "MinimapMenuPopup") end
