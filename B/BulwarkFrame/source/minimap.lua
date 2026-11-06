-- BulwarkFrame - minimap.lua
-- Hand-rolled minimap button (no LibDBIcon on 1.12). Orbits the minimap at a saved angle,
-- drag-repositions, left-click opens the options panel, right-click toggles demo mode.
-- WoW-API file (parse-checked only).
--
-- pfUI-safe, the same way TotemBar's button is: parent = Minimap, the frame NAME contains
-- "Minimap", strata HIGH with level 9 (MEDIUM ends up underneath pfUI). /bulwark options stays
-- the guaranteed access path if a UI collects or hides the button anyway.

BulwarkFrame = BulwarkFrame or {}
local BF = BulwarkFrame

local button = nil

local function db() return BulwarkFrameDB end

-- Position on the orbit for an angle in degrees. Plain trigonometry rather than a lib: the
-- radius is the minimap's own half-width so it follows a resized minimap.
local function PlaceButton(angleDeg)
    if not button then return end
    local radius = (Minimap:GetWidth() / 2) + 5
    local rad = angleDeg * math.pi / 180
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

local function BuildButton()
    if button then return end

    local btn = CreateFrame("Button", "BulwarkFrameMinimapButton", Minimap)
    btn:SetWidth(33)
    btn:SetHeight(33)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(9)

    -- No custom art yet: a shield-shaped stock icon says "defensive readout" well enough, and a
    -- placeholder texture that fails to load would leave an invisible button.
    local icon = btn:CreateTexture("BulwarkFrameMinimapIcon", "ARTWORK")
    icon:SetTexture("Interface\\Icons\\Spell_Nature_StoneClawTotem")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = btn:CreateTexture("BulwarkFrameMinimapBorder", "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    -- Vanilla recipe (MiniMapTrackingButton): a 54px border anchored TOPLEFT(0,0) on a 33px
    -- button. The ring sits off-centre WITHIN the texture, so this exact anchor is what makes it
    -- concentric with the icon -- centring it pushes the ring off.
    border:SetWidth(54)
    border:SetHeight(54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    btn:SetScript("OnDragStart", function() this.isDragging = true end)
    btn:SetScript("OnDragStop", function() this.isDragging = false end)
    btn:SetScript("OnUpdate", function()
        if not this.isDragging then return end
        -- Follow the cursor around the orbit: angle from the minimap centre to the pointer.
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        db().minimapAngle = angle
        PlaceButton(angle)
    end)

    btn:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            -- Show/hide the readout, the same thing TotemBar's button does. This used to toggle
            -- DEMO mode, which was a trap: the frame hides itself when no buffer is up, so the
            -- obvious reaction is to right-click to make it appear -- and that silently replaced
            -- the live readout with synthetic numbers.
            local shown = BF.ToggleFrame()
            DEFAULT_CHAT_FRAME:AddMessage("BulwarkFrame: " .. (shown and "shown" or "hidden"))
        else
            BF.ToggleOptions()
        end
    end)

    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("BulwarkFrame", 1, 1, 1)
        GameTooltip:AddLine("Left click: options", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right click: show / hide the readout", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: move around the minimap", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    button = btn
    PlaceButton(db().minimapAngle or 215)
end

-- Creates the button on demand and honours the "show minimap button" setting.
function BF.UpdateMinimapButton()
    if not db().showMinimapButton then
        if button then button:Hide() end
        return
    end
    BuildButton()
    PlaceButton(db().minimapAngle or 215)
    button:Show()
end
