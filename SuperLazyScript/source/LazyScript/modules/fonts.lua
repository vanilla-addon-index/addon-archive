local _G = getfenv(0)

-- Import theme from themes.lua
-- ---
local theme = lazyScript.theme.themes[lazyScript.theme.active]
local FONT_FILES = theme.fonts
local SIZES = theme.fontSizes
local COLORS = theme.textRGB

-- Font object factory
-- ---
-- Creates font object, sets shadow, font and font flags.
local function CreateLSFont(name, base, path, size, flags)
    local f = CreateFont(name)
    f:SetFontObject(base)
    f:SetShadowColor(0, 0, 0, 0)
    f:SetFont(path, size, flags)
    return f
end

-- --------------------------------------------------------------------
-- Font objects
-- ---
CreateLSFont("LS_Font_Header", GameFontHighlightLarge, FONT_FILES.PTSans, SIZES.h2, "OUTLINE")
CreateLSFont("LS_Font_Body",   GameFontHighlightLarge, FONT_FILES.PTSans, SIZES.p,  "THICK")
CreateLSFont("LS_Font_Code",   GameFontHighlightLarge, FONT_FILES.envyCode, SIZES.h3, "THICK")

-- --------------------------------------------------------------------
-- Font object applicator
-- ---
-- Applies fonts to frames
local function ApplyFontObject(frame, fontObject)
    if not frame then return end
    local font = _G[fontObject]

    -- Case 1: FontString
    if frame.SetFontObject then
        frame:SetFontObject(font)
        return
    end

    -- Case 2: Button / TabButton
    if frame.SetNormalFontObject then
        frame:SetNormalFontObject(font)
        frame:SetHighlightFontObject(font)
        frame:SetDisabledFontObject(font)
        return
    end

    -- Case 3: EditBox
    if frame.SetFont then
        local p, s, f = font:GetFont()
        frame:SetFont(p, s, f)
    end
end

-- --------------------------------------------------------------------
-- Font map
-- ---
local FONT_MAP = {
    LS_Font_Header = {
        "LazyScriptFormEditFrameTitle",
        "LazyScriptFormHelpTitle",
    },

    LS_Font_Body = {
        "LazyScriptFormEditFrameFormName",
        "LazyScriptFormEditFrameFormNameDescr",
        "LazyScriptFormEditFrameHelpButton",
        "LazyScriptFormEditFrameCancelButton",
        "LazyScriptFormEditFrameOkayButton",
        "LazyScriptFormEditFrameTestButton",
        "LazyScriptMinionText",
        "LazyScriptDeathstimatorText",
    },

    LS_Font_Code = {
        "LazyScriptFormEditFrameForm",
    },
}

-- #### font mapping
-- Map font object to tab text
local TAB_PATTERNS = {
    { "LazyScriptFormHelpTab", 5 },
    { "LazyScriptAboutFrameTab", 5 },
}

-- --------------------------------------------------------------------
-- simplehtml font applicator
-- ---
local function SetupHTMLFonts()
    local html = _G.LazyScriptFormHelpScrollFrameScrollChildText
    if not html then return end
    html:SetShadowColor(0, 0, 0, 0) -- otherwise p inherits a shadow 

    -- H1
    html:SetFont("H1", FONT_FILES.PTSans,   SIZES.h1, "")
    html:SetTextColor("H1", unpack(COLORS.emphasis))
    -- H2
    html:SetFont("H2", FONT_FILES.PTSans,   SIZES.h2, "")
    html:SetTextColor("H2", unpack(COLORS.secondary))
    -- H3
    html:SetFont("H3", FONT_FILES.envyCode, SIZES.h3, "")
    html:SetTextColor("H3", unpack(COLORS.warning))
    -- P
    html:SetFont("P",  FONT_FILES.PTSans,   SIZES.p, "")
    html:SetTextColor("P",  unpack(COLORS.primary))
end

-- --------------------------------------------------------------------
-- Public font init. function
-- ---
function lazyScript.LoadFonts()
    -- Apply static mappings
    for fontObject, frames in pairs(FONT_MAP) do
        for i = 1, table.getn(frames) do
            ApplyFontObject(_G[frames[i]], fontObject)
        end
    end

    -- Apply tab patterns
    for i = 1, table.getn(TAB_PATTERNS) do
        local prefix, count = TAB_PATTERNS[i][1], TAB_PATTERNS[i][2]
        for n = 1, count do
            ApplyFontObject(_G[prefix .. n], "LS_Font_Body")
        end
    end

    SetupHTMLFonts()
end
-- --------------------------------------------------------------------
-- Run
-- ---
lazyScript.LoadFonts()