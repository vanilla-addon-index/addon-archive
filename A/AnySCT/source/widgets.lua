-- AnySCT widgets.lua -- small UI helpers shared by the minimap button and the options panel.

AnySCT_W = {}
local W = AnySCT_W

W.FONT = "Fonts\\FRIZQT__.TTF"

W.COLORS = {
    title = { r = 0.90, g = 0.78, b = 0.49 },
    ink   = { r = 0.79, g = 0.80, b = 0.83 },
    dim   = { r = 0.53, g = 0.55, b = 0.60 },
}

W.PANEL_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

W.SOLID_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- Keep our pixel size; take pfUI's font family when pfUI is loaded.
function W.ApplyFont(fs, size, flags)
    size = size or 10
    if pfUI and pfUI.font_default then
        fs:SetFont(pfUI.font_default, size, flags)
    else
        fs:SetFont(W.FONT, size, flags)
    end
end

function W.ApplyShadow(fs, on)
    if on then
        fs:SetShadowColor(0, 0, 0, 0.9)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowColor(0, 0, 0, 0)
        fs:SetShadowOffset(0, 0)
    end
end

function W.MakeText(parent, name, size, color, layer)
    local fs = parent:CreateFontString(name, layer or "ARTWORK")
    W.ApplyFont(fs, size or 11)
    local c = color or W.COLORS.ink
    fs:SetTextColor(c.r, c.g, c.b)
    return fs
end

-- Tooltip on any frame (title line + wrapped body).
function W.AttachTooltip(frame, title, body)
    frame.asctTitle = title
    frame.asctBody = body
    frame:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.asctTitle or "", 1, 1, 1)
        if this.asctBody then GameTooltip:AddLine(this.asctBody, 0.8, 0.8, 0.8, 1) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end
