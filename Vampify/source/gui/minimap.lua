-- Vampify -- minimap button, ported from DopingControl's features/minimap.lua as closely as
-- possible: that file's shape is in-game verified on 1.12, and its comments below carry facts that
-- must not be changed on the way over.
--
-- Design facts (in-game verified on 1.12, DopingControl):
-- - Hand-rolled, no LibDBIcon on 1.12.
-- - pfUI-safe: parent = Minimap, frame NAME contains "Minimap", SetFrameStrata("HIGH") +
--   SetFrameLevel(9) -- MEDIUM hides under pfUI (the exact failure this addon's own display frame
--   hit at strata MEDIUM, see gui/display.lua).
-- - Border recipe (vanilla FrameXML MiniMapTrackingButton): 54px MiniMap-TrackingBorder anchored
--   TOPLEFT(0,0) on a 33px button. The ring is deliberately off-centre within the texture -- do NOT
--   centre it.
-- - Drag + click coexist: drag flag on OnDragStart/Stop, plain clicks still fire OnClick.
-- - Radius = Minimap:GetWidth()/2 + 5 (follows resized minimaps).
-- - Highlight texture is "UI-Minimap-ZoomButton-Highlight" WITH the hyphen before "Highlight" --
--   confirmed against FrameXML-1.12.1/FrameXML/Minimap.xml. The un-hyphenated spelling does not
--   exist as a file and would render nothing.
--
-- Left click toggles the display frame (same code path as the "Show display" checkbox in
-- gui/options.lua -- one definition of "is it on", the frame's own IsShown()); right click opens
-- the options window.
--
-- Pure-Lua 5.0 dofile-loadable: all WoW wiring behind "if CreateFrame then"; BuildButton/PlaceButton
-- only touch the WoW API when called at runtime.

VampifyMinimap = {}
local M = VampifyMinimap

local button = nil

-- NOTE, measured in-game 2026-08-10 on this client: pfUI COLLECTS addon minimap buttons into its
-- own `pfMinimapButtons` panel -- it reparents the button and owns its anchor from then on. So on a
-- pfUI setup the angle below (and dragging around the ring) has no effect, and that is fine: the
-- collected panel is where a pfUI user expects to find addon buttons. The code stays because it is
-- what places the button correctly WITHOUT pfUI. Do not "fix" the placement by fighting pfUI for
-- the anchor.
--
-- Corollary for anyone debugging position here: never compare GetLeft/GetCenter across frames
-- without converting through GetEffectiveScale first. Once pfUI adopts the button, its effective
-- scale (0.47) differs from the Minimap's (0.71), and raw coordinates look wildly wrong while the
-- button sits exactly where it should.
local function PlaceButton(angleDeg)
    if not button then return end
    local radius = (Minimap:GetWidth() / 2) + 5
    local rad = (angleDeg or 0) * math.pi / 180
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

-- ---- WoW wiring ------------------------------------------------------------------------------

if CreateFrame then

    -- The frame's own IsShown() answers "is it on screen right now", which is what a toggle has to
    -- flip -- but it is NOT where the answer is kept. core/commands.lua re-decides visibility on
    -- every loading screen and every gear scan, so a hide that lived only in the frame lasted until
    -- the next portal. The click therefore records the intent in VampifyDB.shown (the "Show
    -- display" checkbox in gui/options.lua reads that same field, so the two cannot drift) and acts
    -- on the frame afterwards.
    function M.toggleDisplay()
        local f  = getglobal("VampifyDisplayFrame")
        local on = not (f and f:IsShown())
        local cfg = VampifyConfig.get()
        if cfg then cfg.shown = on end
        if on then VampifyDisplay.show() else VampifyDisplay.hide() end
    end

    local function BuildButton()
        if button then return end
        local btn = CreateFrame("Button", "VampifyMinimapButton", Minimap)
        btn:SetWidth(33); btn:SetHeight(33)
        btn:SetFrameStrata("HIGH"); btn:SetFrameLevel(9)

        local icon = btn:CreateTexture("VampifyMinimapIcon", "ARTWORK")
        icon:SetTexture("Interface\\Icons\\Spell_Shadow_LifeDrain02")
        icon:SetWidth(20); icon:SetHeight(20)
        icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- standard action-button crop

        local border = btn:CreateTexture("VampifyMinimapBorder", "OVERLAY")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetWidth(54); border:SetHeight(54)
        border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

        btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:RegisterForDrag("LeftButton")

        btn:SetScript("OnDragStart", function() this.isDragging = true end)
        btn:SetScript("OnDragStop", function() this.isDragging = false end)
        btn:SetScript("OnUpdate", function()
            if not this.isDragging then return end
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            -- atan2, computed by hand rather than trusting math.deg to be present: the
            -- VampifyDB.mmAngle contract downstream (PlaceButton) is degrees, so this returns
            -- degrees too.
            local angle = math.atan2(cy - my, cx - mx) * 180 / math.pi
            local cfg = VampifyConfig.get()
            if cfg then cfg.mmAngle = angle end     -- persist live while dragging
            PlaceButton(angle)
        end)

        -- LEFT = display toggle, RIGHT = options.
        btn:SetScript("OnClick", function()
            if arg1 == "RightButton" then
                VampifyOptions.toggle()
            else
                M.toggleDisplay()
            end
        end)
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_LEFT")
            GameTooltip:SetText("Vampify", 1, 1, 1)
            local fight = VampifyAggregate.fight(VampifyState)
            GameTooltip:AddLine(string.format("%d healed this fight, %.1f%%",
                math.floor(fight.heal or 0), (fight.pct or 0) * 100), 0.9, 0.9, 0.9)
            GameTooltip:AddLine("Left click: show / hide the display", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Right click: options", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Drag: move around the minimap", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        button = btn
        local cfg = VampifyConfig.get()
        PlaceButton((cfg and cfg.mmAngle) or VampifyConfig.DEFAULTS.mmAngle)
    end

    -- Honours the "Minimap button" checkbox (VampifyDB.minimap); gui/options.lua calls this after
    -- toggling the setting.
    function M.update()
        local cfg = VampifyConfig.get()
        if not cfg then return end
        if not cfg.minimap then
            if button then button:Hide() end
            return
        end
        BuildButton()
        PlaceButton(cfg.mmAngle)
        button:Show()
    end

end
