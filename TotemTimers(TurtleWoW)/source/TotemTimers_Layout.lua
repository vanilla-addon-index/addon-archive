local TT = _G.TotemTimersAddon

local function GetButtonSize()
    if TotemTimersDB.compact then
        return 32
    end

    return 42
end

function TT.SaveAnchorPosition(frame)
    local point, _, _, x, y = frame:GetPoint(1)
    TotemTimersDB.anchor.point = point or "CENTER"
    TotemTimersDB.anchor.x = x or 0
    TotemTimersDB.anchor.y = y or 100
end

function TT.ResetAnchorPosition()
    TotemTimersDB.anchor.point = "CENTER"
    TotemTimersDB.anchor.x = 0
    TotemTimersDB.anchor.y = 100

    if TT.ANCHOR then
        TT.ANCHOR:ClearAllPoints()
        TT.ANCHOR:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end
end

function TT.StartMovingAnchor()
    if TT.ANCHOR and not TotemTimersDB.locked then
        TT.ANCHOR:StartMoving()
    end
end

function TT.StopMovingAnchor()
    if TT.ANCHOR then
        TT.ANCHOR:StopMovingOrSizing()
        TT.SaveAnchorPosition(TT.ANCHOR)
    end
end

function TT.UpdateAnchorState()
    local anchor = TT.ANCHOR
    if not anchor then
        return
    end

    anchor:SetScale(TotemTimersDB.scale or 1)

    if TotemTimersDB.locked then
        anchor:SetBackdropColor(0, 0, 0, 0)
        anchor:SetBackdropBorderColor(0, 0, 0, 0)
        anchor.text:Hide()
        anchor:EnableMouse(false)
    else
        anchor:SetBackdropColor(0, 0, 0, 0.45)
        anchor:SetBackdropBorderColor(0.95, 0.82, 0.25, 0.85)
        anchor.text:Show()
        anchor:EnableMouse(true)
    end
end

function TT.CreateAnchor()
    if TT.ANCHOR then
        return
    end

    local anchor = CreateFrame("Frame", "TT_Anchor", UIParent)
    anchor:SetWidth(220)
    anchor:SetHeight(72)
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetClampedToScreen(true)
    anchor:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    anchor:SetBackdropColor(0, 0, 0, 0.45)
    anchor:SetBackdropBorderColor(0.95, 0.82, 0.25, 0.85)

    anchor.text = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    anchor.text:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    anchor.text:SetText("TotemTimers\nDrag while unlocked")
    anchor.text:SetJustifyH("CENTER")

    anchor.twist = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    anchor.twist:SetPoint("TOP", anchor, "BOTTOM", 0, -6)
    anchor.twist:SetTextColor(1, 0.82, 0.36)
    anchor.twist:SetJustifyH("CENTER")

    anchor:SetScript("OnDragStart", function()
        if not TotemTimersDB.locked then
            TT.StartMovingAnchor()
        end
    end)
    anchor:SetScript("OnDragStop", function()
        TT.StopMovingAnchor()
    end)

    anchor:ClearAllPoints()
    anchor:SetPoint(
        TotemTimersDB.anchor.point or "CENTER",
        UIParent,
        TotemTimersDB.anchor.point or "CENTER",
        TotemTimersDB.anchor.x or 0,
        TotemTimersDB.anchor.y or 100
    )

    TT.ANCHOR = anchor
end

function TT.UpdateTwistHelper()
    local anchor = TT.ANCHOR
    if not anchor or not anchor.twist then
        return
    end

    local threshold = TotemTimersDB.twistThreshold or 10
    local message = ""
    local twistPriority = {
        ["Windfury Totem"] = 1,
        ["Grace of Air Totem"] = 2,
        ["Tranquil Air Totem"] = 3,
        ["Searing Totem"] = 4,
        ["Magma Totem"] = 5,
        ["Fire Nova Totem"] = 6,
        ["Flametongue Totem"] = 7,
    }
    local fallbackPriority = { "Air", "Fire" }
    local bestName
    local bestRemaining
    local bestPriority
    local element
    local data
    local remaining
    local index

    for index = 1, table.getn(fallbackPriority) do
        element = fallbackPriority[index]
        data = TT.ACTIVE[element]
        if data then
            remaining = TT.GetRemainingTime(element)
            if remaining and remaining <= threshold then
                local priority = twistPriority[data.name] or (100 + index)
                if not bestPriority or priority < bestPriority or (priority == bestPriority and remaining < bestRemaining) then
                    bestName = data.name
                    bestRemaining = remaining
                    bestPriority = priority
                end
            end
        end
    end

    if bestName and bestRemaining then
        message = string.format("Twist: %s (%ss)", bestName, math.ceil(bestRemaining))
    end

    anchor.twist:SetText(message)
    if message == "" and TotemTimersDB.locked then
        anchor.twist:Hide()
    else
        anchor.twist:Show()
    end
end

function TT.ApplyLayout()
    local last
    local index
    local size = GetButtonSize()
    local spacing = TotemTimersDB.compact and 5 or 7
    local visibleCount = 0
    local anchorWidth
    local anchorHeight
    local recallButton = TT.GetRecallButton()

    for index = 1, table.getn(TT.ELEMENTS) do
        if TT.HasKnownTotems(TT.ELEMENTS[index]) then
            visibleCount = visibleCount + 1
        end
    end

    if TT.IsRecallKnown() then
        visibleCount = visibleCount + 1
    end

    if visibleCount < 1 then
        visibleCount = 1
    end

    anchorWidth = TotemTimersDB.vertical and size + 24 or (size * visibleCount) + (spacing * (visibleCount - 1)) + 24
    anchorHeight = TotemTimersDB.vertical and (size * visibleCount) + (spacing * (visibleCount - 1)) + 24 or size + 30

    if TT.ANCHOR then
        TT.ANCHOR:SetScale(TotemTimersDB.scale or 1)
        TT.ANCHOR:SetWidth(anchorWidth)
        TT.ANCHOR:SetHeight(anchorHeight)
    end

    for index = 1, table.getn(TT.ELEMENTS) do
        local element = TT.ELEMENTS[index]
        local btn = TT.GetButton(element)
        if btn then
            if not TT.HasKnownTotems(element) then
                btn:Hide()
                if btn.menu then
                    btn.menu:Hide()
                end
            else
            btn:SetWidth(size)
            btn:SetHeight(size)
            if TotemTimersDB.compact then
                btn.label:Hide()
            else
                btn.label:Show()
            end

            btn:ClearAllPoints()
            if not last then
                btn:SetPoint("TOPLEFT", TT.ANCHOR, "TOPLEFT", 12, -12)
            elseif TotemTimersDB.vertical then
                btn:SetPoint("TOP", last, "BOTTOM", 0, -spacing)
            else
                btn:SetPoint("LEFT", last, "RIGHT", spacing, 0)
            end

            last = btn
            end
        end
    end

    if recallButton then
        recallButton:SetWidth(size)
        recallButton:SetHeight(size)
        if TotemTimersDB.compact then
            recallButton.label:Hide()
        else
            recallButton.label:Show()
        end

        recallButton:ClearAllPoints()
        if TT.IsRecallKnown() then
            if not last then
                recallButton:SetPoint("TOPLEFT", TT.ANCHOR, "TOPLEFT", 12, -12)
            elseif TotemTimersDB.vertical then
                recallButton:SetPoint("TOP", last, "BOTTOM", 0, -spacing)
            else
                recallButton:SetPoint("LEFT", last, "RIGHT", spacing, 0)
            end

            last = recallButton
        end
    end

    TT.UpdateAnchorState()
    TT.UpdateTwistHelper()
    for index = 1, table.getn(TT.ELEMENTS) do
        TT.UpdateButton(TT.ELEMENTS[index])
    end
    TT.UpdateRecallButton()
end
