local TT = _G.TotemTimersAddon

function TT.GetGCDRemaining()
    local duration = TT.GCD.duration or 1.5
    local remaining = duration - (GetTime() - TT.GCD.start)
    if remaining > 0 then
        return remaining
    end

    return 0
end

function TT.ApplyAdvancedVisuals(btn, remaining, duration)
    local pct = remaining / duration

    if pct < 0 then pct = 0 end
    if pct > 1 then pct = 1 end

    local red = 1 - pct
    local green = pct

    btn:SetBackdropBorderColor(red, green, 0.1, 1)

    if remaining <= 10 then
        btn.time:SetTextColor(1, 0.25, 0.25)
    elseif remaining <= 30 then
        btn.time:SetTextColor(1, 0.82, 0.2)
    else
        btn.time:SetTextColor(0.92, 0.92, 0.92)
    end

    if pct < 0.2 then
        if not btn.glow then
            btn.glow = btn:CreateTexture(nil, "OVERLAY")
            btn.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            btn.glow:SetBlendMode("ADD")
            btn.glow:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.glow:SetWidth(btn:GetWidth() * 1.9)
            btn.glow:SetHeight(btn:GetHeight() * 1.9)
        else
            btn.glow:SetWidth(btn:GetWidth() * 1.9)
            btn.glow:SetHeight(btn:GetHeight() * 1.9)
        end

        btn.glow:SetVertexColor(1, 0.75, 0.3, 0.85)
        btn.glow:Show()
    elseif btn.glow then
        btn.glow:Hide()
    end
end
