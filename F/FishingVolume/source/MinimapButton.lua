-- MinimapButton.lua
-- Small square button anchored to the corner of the Minimap.
-- Left click: toggle settings panel
-- Shift + Left click: reset stats with confirmation

local ICON = "Interface\\Icons\\Trade_Fishing"

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
    loader:UnregisterEvent("PLAYER_ENTERING_WORLD")

    -- ============================================================
    -- CONFIRM POPUP
    -- ============================================================
    local confirmFrame = CreateFrame("Frame", "FVMinimapConfirm", UIParent)
    confirmFrame:SetWidth(180)
    confirmFrame:SetHeight(56)
    confirmFrame:SetFrameStrata("TOOLTIP")
    confirmFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    confirmFrame:SetBackdropColor(0, 0, 0, 0.95)
    confirmFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    confirmFrame:Hide()

    local confirmLabel = confirmFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    confirmLabel:SetPoint("TOP", confirmFrame, "TOP", 0, -10)
    confirmLabel:SetText("Reset stats. Are you sure?")
    confirmLabel:SetTextColor(1, 1, 1)

    local function SkinBtn(b)
        b:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        b:SetBackdropColor(0, 0, 0, 1)
        b:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        b:GetFontString():SetTextColor(1.0, 0.82, 0)
        b:SetScript("OnEnter", function() this:SetBackdropBorderColor(1.0, 0.82, 0, 1) end)
        b:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.2, 0.2, 0.2, 1) end)
    end

    local yesBtn = CreateFrame("Button", nil, confirmFrame, "UIPanelButtonTemplate")
    yesBtn:SetWidth(70) yesBtn:SetHeight(20)
    yesBtn:SetPoint("BOTTOMLEFT", confirmFrame, "BOTTOMLEFT", 8, 8)
    yesBtn:SetText("Yes")
    SkinBtn(yesBtn)
    yesBtn:SetScript("OnClick", function()
        FishingVolume.SetSetting("totalFish",   0)
        FishingVolume.SetSetting("totalChests", 0)
        FishingVolume.sessionFish   = 0
        FishingVolume.sessionChests = 0
        DEFAULT_CHAT_FRAME:AddMessage("|cff33cc99FishingVolume:|r Stats reset.")
        confirmFrame:Hide()
    end)

    local noBtn = CreateFrame("Button", nil, confirmFrame, "UIPanelButtonTemplate")
    noBtn:SetWidth(70) noBtn:SetHeight(20)
    noBtn:SetPoint("BOTTOMRIGHT", confirmFrame, "BOTTOMRIGHT", -8, 8)
    noBtn:SetText("No")
    SkinBtn(noBtn)
    noBtn:SetScript("OnClick", function() confirmFrame:Hide() end)

    -- ============================================================
    -- BUTTON
    -- ============================================================
    local btn = CreateFrame("Button", "FVMinimapButton", UIParent)
    btn:SetWidth(22) btn:SetHeight(22)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(9)

    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    btn:SetBackdropColor(0, 0, 0, 0.85)
    btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    local ico = btn:CreateTexture(nil, "ARTWORK")
    ico:SetTexture(ICON)
    ico:SetWidth(16) ico:SetHeight(16)
    ico:SetPoint("CENTER", btn, "CENTER", 0, 0)

    -- Stay parented to UIParent (avoids pfUI injecting circle textures),
    -- but anchor position to pfMinimapButtons and mirror its visibility.
    if pfMinimapButtons then
        btn:SetPoint("LEFT", pfMinimapButtons, "LEFT", 2, 0)

        -- Match initial visibility
        if pfMinimapButtons:IsVisible() then
            btn:Show()
        else
            btn:Hide()
        end

        -- Hook Show/Hide on pfMinimapButtons to follow its visibility
        local origShow = pfMinimapButtons.Show
        pfMinimapButtons.Show = function(self)
            origShow(self)
            btn:Show()
        end
        local origHide = pfMinimapButtons.Hide
        pfMinimapButtons.Hide = function(self)
            origHide(self)
            btn:Hide()
        end
    else
        -- Standard mode — orbit the minimap, draggable to reposition
        local function GetAngle()
            return FishingVolumeDB and FishingVolumeDB.minimapAngle or 195
        end
        local function SetAngle(a)
            FishingVolumeDB = FishingVolumeDB or {}
            FishingVolumeDB.minimapAngle = a
        end
        local function UpdatePosition(angle)
            local rad = math.rad(angle)
            btn:ClearAllPoints()
            btn:SetPoint("CENTER", Minimap, "CENTER",
                math.cos(rad) * 77,
                math.sin(rad) * 77)
        end

        UpdatePosition(GetAngle())

        btn:RegisterForDrag("LeftButton")
        btn:SetScript("OnDragStart", function()
            this.isDragging = true
            this:LockHighlight()
        end)
        btn:SetScript("OnDragStop", function()
            this.isDragging = false
            this:UnlockHighlight()
        end)
        btn:SetScript("OnUpdate", function()
            if not this.isDragging then return end
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale  = UIParent:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            SetAngle(angle)
            UpdatePosition(angle)
        end)
    end

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            if IsShiftKeyDown() then
                -- Shift + Left: toggle mini panel
                FishingVolume_ToggleMiniPanel()
            else
                -- Left: toggle main settings panel
                confirmFrame:Hide()
                if FishingVolumeFrame:IsVisible() then
                    FishingVolumeFrame:Hide()
                else
                    FishingVolumeFrame:Show()
                end
            end
        elseif arg1 == "RightButton" then
            if IsShiftKeyDown() then
                -- Shift + Right: reset stats confirm
                confirmFrame:ClearAllPoints()
                confirmFrame:SetPoint("BOTTOM", btn, "TOP", 0, 4)
                if confirmFrame:IsVisible() then
                    confirmFrame:Hide()
                else
                    confirmFrame:Show()
                end
            else
                -- Right: toggle zones browser
                if FishingVolume_ToggleZonesFrame then FishingVolume_ToggleZonesFrame() end
            end
        end
    end)

    btn:SetScript("OnEnter", function()
        this:SetBackdropBorderColor(1.0, 0.82, 0, 1)
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("FishingVolume", 1, 0.82, 0)
        GameTooltip:AddLine("Left click: Open settings", 1, 1, 1)
        GameTooltip:AddLine("Shift + Left click: Mini panel", 1, 1, 1)
        GameTooltip:AddLine("Right click: Zones browser", 1, 1, 1)
        GameTooltip:AddLine("Shift + Right click: Reset stats", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        this:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        GameTooltip:Hide()
    end)

    DEFAULT_CHAT_FRAME:AddMessage("|cff33cc99FishingVolume:|r Minimap button ready.")
end)
