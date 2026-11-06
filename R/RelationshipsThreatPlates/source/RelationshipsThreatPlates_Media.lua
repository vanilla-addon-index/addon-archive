----------------------------------------------------------------------
-- RelationshipsThreatPlates_Media.lua
-- Embedded media textures and fonts
-- Self-contained - generates textures procedurally, no external files
----------------------------------------------------------------------

local addon = RelationshipsThreatPlates  -- Created in RelationshipsThreatPlates_Core.lua (loaded first via XML)

addon.Media = {}

-- ==================================================================
-- Procedural status bar texture (solid gradient)
-- Generated at runtime via texture coordinates on Blizzard's shared
-- gradient texture, matching Kui's clean flat bar style
-- ==================================================================

-- Use Blizzard's built-in solid textures as bar fill
-- These are always available and produce the clean flat look
addon.Media.BAR_TEXTURE     = "Interface\\AddOns\\RelationshipsThreatPlates\\Media\\Bar"
addon.Media.BG_TEXTURE      = "Interface\\AddOns\\RelationshipsThreatPlates\\Media\\BarBG"
addon.Media.SOLID_TEXTURE   = "Interface\\Buttons\\WHITE8x8"
addon.Media.GLOW_TEXTURE    = "Interface\\AddOns\\RelationshipsThreatPlates\\Media\\Glow"
addon.Media.SPARK_TEXTURE   = "Interface\\AddOns\\RelationshipsThreatPlates\\Media\\Spark"
addon.Media.SHADOW_TEXTURE  = "Interface\\AddOns\\RelationshipsThreatPlates\\Media\\ShadowBorder"

-- Font paths - use WoW's built-in fonts for zero-dependency
addon.Media.FONT_NORMAL     = "Fonts\\FRIZQT__.TTF"
addon.Media.FONT_OUTLINE    = "Fonts\\FRIZQT__.TTF"

-- Kui-style colour palette
addon.Media.COLOURS = {
    -- Threat gradient: green -> yellow -> orange -> red
    THREAT_LOW    = { r = 0.33, g = 0.80, b = 0.33 },
    THREAT_MEDIUM = { r = 1.00, g = 0.85, b = 0.00 },
    THREAT_HIGH   = { r = 1.00, g = 0.50, b = 0.00 },
    THREAT_AGGRO  = { r = 1.00, g = 0.10, b = 0.10 },

    -- Kui-style background
    BG_DARK       = { r = 0.06, g = 0.06, b = 0.06, a = 0.90 },

    -- Kui-style border glow colours
    GLOW_TARGET   = { r = 0.30, g = 0.70, b = 1.00, a = 0.60 },
    GLOW_THREAT   = { r = 0.90, g = 0.00, b = 0.00, a = 0.60 },
    GLOW_SHADOW   = { r = 0.00, g = 0.00, b = 0.00, a = 0.20 },

    -- Text
    TEXT_WHITE     = { r = 1.00, g = 1.00, b = 1.00 },
    TEXT_SHADOW    = { r = 0.00, g = 0.00, b = 0.00, a = 1.00 },

    -- GUI
    GUI_BG        = { r = 0.10, g = 0.10, b = 0.10, a = 0.95 },
    GUI_BORDER    = { r = 0.30, g = 0.30, b = 0.30, a = 1.00 },
    GUI_HEADER    = { r = 0.15, g = 0.15, b = 0.15, a = 1.00 },
    GUI_ACCENT    = { r = 0.30, g = 0.70, b = 1.00, a = 1.00 },
}

-- ==================================================================
-- Helper: brighten a colour by a factor (Kui-style)
-- ==================================================================
function addon.Media.Brighten(factor, r, g, b, a)
    factor = factor or 0.3
    if type(r) == "table" then
        r, g, b, a = unpack(r)
    end
    a = a or 1
    return math.min(1, r + (1 - r) * factor),
           math.min(1, g + (1 - g) * factor),
           math.min(1, b + (1 - b) * factor),
           a
end

-- ==================================================================
-- Colour presets for the threat gradient (2.6)
-- Each preset defines 4 stops: low (0%), medium (50%), high (80%), aggro (100%)
-- ==================================================================
addon.Media.COLOR_PRESETS = {
    kui = {
        low    = { 0.33, 0.80, 0.33 },
        medium = { 1.00, 0.85, 0.00 },
        high   = { 1.00, 0.50, 0.00 },
        aggro  = { 1.00, 0.10, 0.10 },
    },
    cool = {
        low    = { 0.20, 0.55, 1.00 },
        medium = { 0.55, 0.35, 1.00 },
        high   = { 1.00, 0.35, 0.55 },
        aggro  = { 1.00, 0.10, 0.10 },
    },
    mono = {
        low    = { 0.55, 0.55, 0.55 },
        medium = { 0.80, 0.80, 0.80 },
        high   = { 1.00, 1.00, 1.00 },
        aggro  = { 1.00, 0.20, 0.20 },
    },
    warband = {
        low    = { 0.20, 0.90, 0.90 },
        medium = { 0.60, 0.90, 0.30 },
        high   = { 1.00, 0.80, 0.20 },
        aggro  = { 1.00, 0.10, 0.10 },
    },
}

-- ==================================================================
-- Helper: get smooth interpolated threat colour
-- ==================================================================
function addon.Media.GetThreatColour(pct)
    pct = tonumber(pct) or 0
    pct = math.min(100, math.max(0, pct))

    local presetName = (RelationshipsThreatPlatesDB and RelationshipsThreatPlatesDB.colorPreset) or "kui"
    local p = addon.Media.COLOR_PRESETS[presetName] or addon.Media.COLOR_PRESETS.kui
    local lo, md, hi, ag = p.low, p.medium, p.high, p.aggro
    local r, g, b

    if pct < 50 then
        local t = pct / 50
        r = lo[1] + (md[1] - lo[1]) * t
        g = lo[2] + (md[2] - lo[2]) * t
        b = lo[3] + (md[3] - lo[3]) * t
    elseif pct < 80 then
        local t = (pct - 50) / 30
        r = md[1] + (hi[1] - md[1]) * t
        g = md[2] + (hi[2] - md[2]) * t
        b = md[3] + (hi[3] - md[3]) * t
    else
        local t = (pct - 80) / 20
        if t > 1 then t = 1 end
        if t < 0 then t = 0 end
        r = hi[1] + (ag[1] - hi[1]) * t
        g = hi[2] + (ag[2] - hi[2]) * t
        b = hi[3] + (ag[3] - hi[3]) * t
    end

    return r, g, b
end

-- ==================================================================
-- Generate media textures as file data (using solid fallback)
-- These are created in the Media/ folder by the installer script
-- but we also provide runtime fallback generation
-- ==================================================================
function addon.Media.EnsureTextures()
    -- Ensure the media directory textures exist
    -- For standalone deployment, we use Blizzard built-in textures
    -- with vertex colouring to achieve the Kui look
    --
    -- The bar texture is handled via WHITE8x8 with vertex colour
    -- This gives the same clean flat look as Kui's procedural bar

    addon.Media.BAR_TEXTURE   = addon.Media.SOLID_TEXTURE
    addon.Media.BG_TEXTURE    = addon.Media.SOLID_TEXTURE
    addon.Media.GLOW_TEXTURE  = addon.Media.SOLID_TEXTURE
    addon.Media.SPARK_TEXTURE = addon.Media.SOLID_TEXTURE
end
