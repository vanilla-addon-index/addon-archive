-- AnySCT minimap.lua -- minimap button.
-- Left click: unlock / lock the text anchor (unlocking also plays the demo).
-- Right click: options. Drag: move around the minimap. Can be disabled in the options.
--
-- pfUI-safe recipe: parent = Minimap, frame name contains "Minimap", strata HIGH, level 9.
-- pfUI may collect the button into its own panel and then owns its position; that is fine.

AnySCT_Minimap = {}
local M = AnySCT_Minimap

local button = nil

local function placeButton(angleDeg)
    if not button then return end
    local radius = (Minimap:GetWidth() / 2) + 5
    local rad = (angleDeg or 0) * math.pi / 180
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

if CreateFrame then
    local function buildButton()
        if button then return end
        local btn = CreateFrame("Button", "AnySCTMinimapButton", Minimap)
        btn:SetWidth(33)
        btn:SetHeight(33)
        btn:SetFrameStrata("HIGH")
        btn:SetFrameLevel(9)

        local icon = btn:CreateTexture("AnySCTMinimapIcon", "ARTWORK")
        icon:SetTexture("Interface\\Icons\\Ability_Warrior_DefensiveStance")
        icon:SetWidth(20)
        icon:SetHeight(20)
        icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local border = btn:CreateTexture("AnySCTMinimapBorder", "OVERLAY")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetWidth(54)
        border:SetHeight(54)
        border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

        btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:RegisterForDrag("LeftButton")

        -- the drag OnUpdate exists only while dragging
        local function dragUpdate()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.atan2(cy - my, cx - mx) * 180 / math.pi
            AnySCT_Core.SetOpt("mmAngle", angle)
            placeButton(angle)
        end
        btn:SetScript("OnDragStart", function() this:SetScript("OnUpdate", dragUpdate) end)
        btn:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)

        btn:SetScript("OnClick", function()
            if arg1 == "RightButton" then
                if AnySCT_Options then AnySCT_Options.toggle() end
            elseif AnySCT_SCT then
                AnySCT_SCT.ToggleMove()
            end
        end)
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_LEFT")
            GameTooltip:SetText("AnySCT", 1, 1, 1)
            local st = AnySCT_Core.state
            local n = table.getn(st.order)
            GameTooltip:AddLine("targetSCTs: " .. ((n > 0) and table.concat(st.order, ", ") or "none"), 0.9, 0.9, 0.9)
            GameTooltip:AddLine("Left click: unlock / lock the text anchor", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Right click: options", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Drag: move around the minimap", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        button = btn
    end

    -- Honours the "Minimap button" option; called on login and after the option changes.
    function M.Update()
        local C = AnySCT_Core
        if not C.Opt("minimap") then
            if button then button:Hide() end
            return
        end
        buildButton()
        placeButton(C.Opt("mmAngle"))
        button:Show()
    end
end
