-- RelationshipsAttune: Minimap.lua
-- A standalone, freely-movable, hideable button (parented to UIParent so it
-- can be dragged anywhere on the screen, not just around the minimap ring).
-- Pure Lua 5.0 / WoW 1.12 safe (Turtle/Octo compatible).
--
-- Options are stored in RelationshipsAttuneDB.options:
--   minimapX     : number  (x offset from UIParent CENTER, in UI pixels)
--   minimapY     : number  (y offset from UIParent CENTER, in UI pixels)
--   minimapHide  : boolean (true = hidden)
-- Legacy angle/radius fields are migrated to X/Y on first load.

RelationshipsAttune = RelationshipsAttune or {}
local RA = RelationshipsAttune
RA.Minimap = {}
local MM = RA.Minimap

local BTN_NAME = "RelationshipsAttuneMinimapButton"
local ICON     = "Interface\\Icons\\INV_Misc_Book_09"

local function opts()
    if not RelationshipsAttuneDB then RelationshipsAttuneDB = {} end
    if not RelationshipsAttuneDB.options then RelationshipsAttuneDB.options = {} end
    local o = RelationshipsAttuneDB.options

    -- Migrate legacy angle/radius (around the minimap) into free X/Y.
    if type(o.minimapX) ~= "number" or type(o.minimapY) ~= "number" then
        local ang = (type(o.minimapAngle)  == "number") and o.minimapAngle  or 200
        local rad = (type(o.minimapRadius) == "number") and o.minimapRadius or 80
        local r   = ang * math.pi / 180
        local mx, my = 0, 0
        if Minimap and Minimap.GetCenter then
            local cx, cy = Minimap:GetCenter()
            if cx then mx, my = cx, cy end
        end
        local ux, uy = 0, 0
        if UIParent and UIParent.GetCenter then
            local ucx, ucy = UIParent:GetCenter()
            if ucx then ux, uy = ucx, ucy end
        end
        o.minimapX = (mx - ux) + math.cos(r) * rad
        o.minimapY = (my - uy) + math.sin(r) * rad
    end
    if o.minimapHide == nil then o.minimapHide = false end
    return o
end

local function applyPosition(btn)
    local o = opts()
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", UIParent, "CENTER", o.minimapX, o.minimapY)
end
MM._updatePosition = applyPosition

local function onDragUpdate()
    -- Do all math in the button's own effective scale. The button is
    -- parented to Minimap, whose effective scale can differ from
    -- UIParent's; mixing scales makes the icon drift away from the cursor.
    local btn = this
    local bscale = btn:GetEffectiveScale() or 1
    local uscale = UIParent:GetEffectiveScale() or 1
    local mx, my = GetCursorPosition()
    mx = mx / bscale
    my = my / bscale
    local ucx, ucy = UIParent:GetCenter()
    if not ucx then return end
    -- Convert UIParent center from UIParent scale into btn scale.
    ucx = ucx * uscale / bscale
    ucy = ucy * uscale / bscale
    local o = opts()
    o.minimapX = mx - ucx
    o.minimapY = my - ucy
    applyPosition(btn)
end

function MM:Create()
    if getglobal(BTN_NAME) then return getglobal(BTN_NAME) end

    -- Parent to Minimap so button-collector addons (MinimapButtonBag /
    -- MBB, and similar) can discover and manage this button the same way
    -- they discover Blizzard's built-in minimap buttons. SetPoint still
    -- anchors to UIParent CENTER so the button can be dragged anywhere
    -- on screen -- the anchor frame is independent of the parent frame.
    local btn = CreateFrame("Button", BTN_NAME, Minimap)
    btn:SetWidth(31); btn:SetHeight(31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton", "RightButton")
    btn:SetMovable(true)
    -- Allow the button to sit off-screen (via /attune pos or /attune offscreen)
    -- while remaining discoverable by MinimapButtonBag.
    if btn.SetClampedToScreen then btn:SetClampedToScreen(false) end
    -- MBB-friendly highlight so the button visually matches other
    -- minimap buttons once it has been swept into the bag.
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Round border ring (standard minimap-button look)
    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetWidth(53); overlay:SetHeight(53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20); icon:SetHeight(20)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -6)
    btn.icon = icon


    btn:SetScript("OnClick", function()
        if RA.UI and RA.UI.Toggle then RA.UI:Toggle() end
    end)

    btn:SetScript("OnDragStart", function()
        this:LockHighlight()
        this:SetScript("OnUpdate", onDragUpdate)
    end)
    btn:SetScript("OnDragStop", function()
        this:UnlockHighlight()
        this:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("Relationships Attune", 1, 0.82, 0)
        GameTooltip:AddLine("Left-click: open / close window", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Drag: move anywhere on screen", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("/attune offscreen - park off-screen (MBB safe)", 0.6, 0.8, 1)
        GameTooltip:AddLine("/attune hide      - hide this button", 0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    applyPosition(btn)
    self.btn = btn
    return btn
end

function MM:Show()
    local o = opts()
    o.minimapHide = false
    local btn = self:Create()
    btn:Show()
end

function MM:Hide()
    local o = opts()
    o.minimapHide = true
    if self.btn then self.btn:Hide() end
end

function MM:Toggle()
    local o = opts()
    if o.minimapHide then self:Show() else self:Hide() end
end

function MM:Refresh()
    local o = opts()
    local btn = self:Create()
    if o.minimapHide then btn:Hide() else btn:Show() end
    applyPosition(btn)
end

function MM:Init()
    self:Refresh()
end
