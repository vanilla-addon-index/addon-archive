-- Vampify -- shared UI building blocks, ported from DopingControl's ui/widgets.lua.
--
-- Slim port: only what this addon's two windows actually use -- panel backdrop, a solid 1px
-- backdrop, a pfUI-aware font helper, a text factory, a dark gold-trim button, the change-guarded
-- setters that keep an idle window at zero allocation, and a minimal tooltip attach helper. The
-- cell/pill/badge factories and the two-column tooltip helper in the source addon exist for its
-- raid-roster grid, which this addon does not have, so they are not ported.
--
-- Pure Lua 5.0, dofile-loadable: top level only defines tables/functions; CreateFrame and friends
-- are only referenced INSIDE factory functions, which are never called offline.

VampifyWidgets = {}
local W = VampifyWidgets

-- ------------------------------------------------------------------
-- Texture / font constants
-- ------------------------------------------------------------------
W.SOLID_TEX = "Interface\\Buttons\\WHITE8X8"
W.FONT      = "Fonts\\FRIZQT__.TTF"

-- Main window backdrop. Textures shipped in Vampify\textures\ -- copied from DopingControl's own
-- panel_bg/panel_border, NOT referenced through DopingControl's AddOns path: this addon must not
-- depend on DopingControl being installed.
W.PANEL_BACKDROP = {
    bgFile   = "Interface\\AddOns\\Vampify\\textures\\panel_bg",
    edgeFile = "Interface\\AddOns\\Vampify\\textures\\panel_border",
    tile = true, tileSize = 128, edgeSize = 16,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
}

-- Solid 1px-border backdrop (WHITE8X8 recipe): bg + border colored via SetBackdropColor /
-- SetBackdropBorderColor on the frame that uses it.
W.SOLID_BACKDROP = {
    bgFile   = W.SOLID_TEX,
    edgeFile = W.SOLID_TEX,
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- ------------------------------------------------------------------
-- Color palette. Only the entries this addon's two windows use: the gold family for the title and
-- button text, the panel/line neutrals for button states, and green/red for the two warning lines
-- that need to say something is wrong.
-- ------------------------------------------------------------------
local function hexrgb(hex)
    return {
        r = tonumber(string.sub(hex, 1, 2), 16) / 255,
        g = tonumber(string.sub(hex, 3, 4), 16) / 255,
        b = tonumber(string.sub(hex, 5, 6), 16) / 255,
    }
end

W.COLORS = {
    goldHi   = hexrgb("e6c87e"),  -- title / highlight gold
    gold     = hexrgb("8f7440"),  -- hover border gold
    goldSoft = hexrgb("54462a"),  -- resting border gold
    panel2   = hexrgb("171b23"),  -- resting button bg
    panel3   = hexrgb("1d222c"),  -- hover button bg
    line     = hexrgb("262c37"),  -- standard borders / dividers
    ink      = hexrgb("c9cdd4"),  -- body text
    dim      = hexrgb("868d99"),  -- secondary text
    faint    = hexrgb("5b6270"),  -- tertiary / hints
    warn     = hexrgb("e0c98a"),  -- accuracy-hint yellow
    bad      = hexrgb("d05252"),  -- no-data red
    -- Added for the compact-bar/breakdown-panel mockup redesign (2026-08-24): Single-Target vs.
    -- AoE get their own hue everywhere the two are told apart (the bar's badge group, the panel's
    -- split row, each ability row's two-color fill), HPS gets its own accent on the bar, badgeBg
    -- backs the bar's badge-group pill so it reads as its own grouped control rather than more
    -- bar text.
    stBlue    = hexrgb("5b8fd9"),  -- Single-Target bare color chips (the compact-bar pill segment)
    aoeOrange = hexrgb("d98a3d"),  -- AoE bare color chips (the compact-bar pill segment)
    hpsGreen  = hexrgb("7cc576"),  -- compact-bar HPS segment
    badgeBg   = hexrgb("11151c"),  -- compact-bar badge-group background (legacy, panel row bg reuse)

    -- CANONICAL red/blue pair (in-game correction, reported verbatim: "same color coding as in the
    -- bar (red/blue)") -- unify the breakdown panel onto the SAME two colors the compact bar's
    -- own pill already uses, from this ONE shared source, not defined twice). RED = Vamp healing
    -- landed on the player's CURRENT TARGET, BLUE = everything else -- the same semantics
    -- everywhere these are used (the compact pill, the panel's split row, each ability row's
    -- two-color fill). Values verbatim from what used to be gui/display.lua's own local PILL_RED/
    -- PILL_BLUE (196/255,62/255,58/255 and 53/255,96/255,161/255) -- moved here so both call sites
    -- read the identical table and can never drift apart again. Also passes this file's own 4.5:1
    -- bar-text floor with real headroom (verified via an offline contrast-check render script:
    -- ink-on-red 10.88:1, ink-on-blue 11.91:1 -- stronger than the retired stBlueFill/aoeOrangeFill
    -- pair's own 6.01:1/5.15:1), so no separate "under text" darkened variant is needed the way the
    -- old blue/orange pair required.
    targetRed = hexrgb("C43E3A"),
    restBlue  = hexrgb("3560A1"),
    -- Neutral grey bar fill for the breakdown panel's collapsed "Other (N)" row (Befund 4) -- a
    -- deliberately different hue from targetRed/restBlue/goldSoft so a mixed ST+AoE summary
    -- row never reads as a real, classified ability. White-on-otherGrey measures 7.96:1.
    otherGrey = hexrgb("4a5160"),
    -- Near-white text drawn directly on top of a bar fill (split row, ability rows) -- paired with
    -- the OUTLINE font flag (W.ApplyFont's third argument) at those call sites for the "1px dark
    -- outline" kept in addition to the contrast fix itself.
    barText = { r = 0.97, g = 0.96, b = 0.94 },
}

-- ------------------------------------------------------------------
-- Font helper. Keeps OUR pixel size -- this addon's layout is hand-fitted to it -- and only takes
-- pfUI's font FAMILY when pfUI is present, so text reads consistently with the rest of the client
-- without pfUI's global size setting reflowing this window.
-- ------------------------------------------------------------------
-- `flags` is SetFont's third argument: nil, "OUTLINE" or "THICKOUTLINE" (also "MONOCHROME", which
-- we do not use). An outline is what makes light text survive a light background -- green numbers
-- over grass being the case that prompted it.
function W.ApplyFont(fs, size, flags)
    size = size or 10
    if pfUI and pfUI.font_default then
        fs:SetFont(pfUI.font_default, size, flags)
    else
        fs:SetFont(W.FONT, size, flags)
    end
end

-- A soft drop shadow on a whole BACKDROP frame (the compact bar, the breakdown panel) -- pfUI's
-- own pfUI.api.CreateBackdropShadow(f), confirmed live-used at pfUI/modules/gui.lua:495-family
-- call sites and real in this client (not a Retail-only API). No-op when pfUI is not loaded --
-- this is pure cosmetic polish for the mockup redesign (2026-08-24), never a load-bearing part of
-- the layout, so a client without pfUI must render exactly as before (flat 1px SOLID_BACKDROP
-- border, no shadow) rather than error or leave a gap where the shadow would have been.
function W.ApplyBackdropShadow(f)
    if pfUI and pfUI.api and pfUI.api.CreateBackdropShadow then
        pfUI.api.CreateBackdropShadow(f)
    end
end

-- A drop shadow on top of the outline. The two solve different halves of the same problem: the
-- outline separates the glyph from the background, the shadow gives it depth against a background
-- of the SAME brightness, where an outline of the wrong colour would disappear too.
function W.ApplyShadow(fs, on)
    if on then
        fs:SetShadowColor(0, 0, 0, 0.9)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
        fs:SetShadowColor(0, 0, 0, 0)
    end
end

-- ------------------------------------------------------------------
-- Change-guarded setters. Convention: cache the last-applied value on the region as vfLast*; only
-- call the real setter when the value changed. This is what lets the options window's throttled
-- info panel repaint every 0.5s without a SetText call (and the redraw it costs) on every tick.
-- ------------------------------------------------------------------
function W.SetTextG(fs, text)
    if fs.vfLastText ~= text then
        fs.vfLastText = text
        fs:SetText(text)
    end
end

function W.SetTextColorG(fs, c)
    if fs.vfLastColor ~= c then
        fs.vfLastColor = c
        fs:SetTextColor(c.r, c.g, c.b)
    end
end

function W.SetBackdropG(f, bg, border)
    if f.vfLastBg ~= bg then
        f.vfLastBg = bg
        f:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 1)
    end
    if f.vfLastBorder ~= border then
        f.vfLastBorder = border
        f:SetBackdropBorderColor(border.r, border.g, border.b, 1)
    end
end

-- ------------------------------------------------------------------
-- FontString factory.
-- ------------------------------------------------------------------
function W.MakeText(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    W.ApplyFont(fs, size)
    if color then
        W.SetTextColorG(fs, color)
    end
    return fs
end

-- ------------------------------------------------------------------
-- Dark gold-trim button, the addon's one button style.
-- ------------------------------------------------------------------
function W.MakeButton(parent, name, label, width, height)
    local C = W.COLORS
    local b = CreateFrame("Button", name, parent)
    b:SetWidth(width or 100)
    b:SetHeight(height or 22)
    b:SetBackdrop(W.SOLID_BACKDROP)
    W.SetBackdropG(b, C.panel2, C.goldSoft)
    b.text = b:CreateFontString(nil, "OVERLAY")
    W.ApplyFont(b.text, 10)
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    W.SetTextColorG(b.text, C.goldHi)
    b.text:SetText(label)
    b:SetScript("OnEnter", function()
        if this.vfDisabled then return end
        W.SetBackdropG(this, C.panel3, C.gold)
    end)
    b:SetScript("OnLeave", function()
        if this.vfDisabled then return end
        W.SetBackdropG(this, C.panel2, C.goldSoft)
    end)
    return b
end

-- ------------------------------------------------------------------
-- Enable/disable for MakeButton buttons. A hand-drawn button (SOLID_BACKDROP + its own text, no
-- Blizzard disabled-texture) needs its dimming done by hand: native Button:Disable() stops OnClick
-- from firing, but the resting/hover backdrop colors and the gold text would otherwise still read
-- as "clickable". b.vfDisabled additionally guards MakeButton's own OnEnter/OnLeave above so a
-- disabled button does not light up on hover.
-- ------------------------------------------------------------------
-- Sliders in 1.12 have NO Enable()/Disable() -- those are Button methods, and calling them on a
-- Slider throws "attempt to call method `Enable' (a nil value)" (caught in-game 2026-08-10).
-- Blizzard's own way, from FrameXML/OptionsFrame.lua:481-493, is to hide the thumb and grey the
-- three label font strings; EnableMouse(false) is added here so the track ignores clicks too.
function W.SetSliderEnabled(sl, enabled)
    if not sl then return end
    local C = W.COLORS
    local name = sl:GetName()
    local thumb = getglobal(name .. "Thumb")
    local txt, lo, hi = getglobal(name .. "Text"), getglobal(name .. "Low"), getglobal(name .. "High")
    local col = enabled and C.ink or C.faint
    sl:EnableMouse(enabled and true or false)
    if thumb then if enabled then thumb:Show() else thumb:Hide() end end
    if txt then txt:SetTextColor(col.r, col.g, col.b) end
    if lo then lo:SetTextColor(col.r, col.g, col.b) end
    if hi then hi:SetTextColor(col.r, col.g, col.b) end
end

function W.SetButtonEnabled(b, enabled)
    local C = W.COLORS
    if enabled then
        b.vfDisabled = nil
        b:Enable()
        W.SetBackdropG(b, C.panel2, C.goldSoft)
        W.SetTextColorG(b.text, C.goldHi)
    else
        b.vfDisabled = true
        b:Disable()
        W.SetBackdropG(b, C.panel2, C.line)
        W.SetTextColorG(b.text, C.faint)
    end
end

-- ------------------------------------------------------------------
-- Minimal tooltip attach: chains any existing OnEnter/OnLeave (no HookScript on 1.12), shows a
-- single-line tooltip. The convention matches DopingControl's AddTooltip/TipLine pair, trimmed to
-- the one line shape this addon needs.
-- ------------------------------------------------------------------
function W.TipLine(text, c)
    if not GameTooltip then return end
    local r, g, b = 1, 1, 1
    if c then r, g, b = c.r, c.g, c.b end
    GameTooltip:AddLine(text, r, g, b, 1)
end

function W.AttachTooltip(frame, text)
    local oldEnter = frame:GetScript("OnEnter")
    local oldLeave = frame:GetScript("OnLeave")
    frame.vfTip = text
    frame:SetScript("OnEnter", function()
        if oldEnter then oldEnter() end
        if GameTooltip and this.vfTip then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(this.vfTip, 1, 1, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function()
        if oldLeave then oldLeave() end
        if GameTooltip then GameTooltip:Hide() end
    end)
end
