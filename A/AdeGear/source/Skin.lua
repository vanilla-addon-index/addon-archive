-- Colors, font and frame look. Follows pfUI when it is loaded, else uses a plain flat dark look
-- that matches pfUI's defaults. Everything is applied through a registry, so /adeg skin can
-- restyle all windows at once.

local AG = AdeGear
local WHITE = "Interface\\Buttons\\WHITE8X8"
AG.WHITE = WHITE

-- fixed colors
AG.C = {
  text   = { 1, 1, 1 },
  dim    = { 0.62, 0.62, 0.62 },
  gold   = { 1, 0.82, 0 },
  good   = { 0.35, 0.95, 0.35 },
  bad    = { 1, 0.3, 0.3 },
  warn   = { 1, 0.6, 0.2 },
  accent = { 0.2, 1, 0.8 },     -- pfUI's teal
  tank   = { 0.3, 0.55, 0.95 },
  heal   = { 0.3, 0.85, 0.4 },
  dmg    = { 0.9, 0.3, 0.3 },
}

-- item quality colors (0 poor ... 5 legendary)
AG.Q = {
  [0] = { 0.62, 0.62, 0.62 },
  [1] = { 1, 1, 1 },
  [2] = { 0.12, 1, 0 },
  [3] = { 0, 0.44, 0.87 },
  [4] = { 0.64, 0.21, 0.93 },
  [5] = { 1, 0.5, 0 },
}

AG.ClassColor = {
  WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
  ROGUE = { 1, 0.96, 0.41 }, PRIEST = { 1, 1, 1 }, SHAMAN = { 0, 0.44, 0.87 },
  MAGE = { 0.41, 0.8, 0.94 }, WARLOCK = { 0.58, 0.51, 0.79 }, DRUID = { 1, 0.49, 0.04 },
}

----------------------------------------------------------------------
-- Look: "pfui" (flat windows with the colors and font of pfUI; plain dark when pfUI is not loaded) or "blizzard"
-- (the usual vanilla windows). The setting is auto (pfUI when loaded, else vanilla), pfui or blizzard.
----------------------------------------------------------------------

function AG.Look()
  local want = AG.Get("look")
  if want == "blizzard" then return "blizzard" end
  if want == "pfui" or want == "flat" then return "pfui" end
  -- auto: pfUI when it is loaded, else the vanilla windows
  if type(pfUI_config) == "table" then return "pfui" end
  return "blizzard"
end

-- accent color (highlights, values): pfUI's teal, or a soft gold in the vanilla look. Changes the table in place,
-- so anything made afterwards uses it; windows already made keep their colors until /reload.
function AG.ApplyLook()
  local a = AG.C.accent
  if AG.Look() == "blizzard" then a[1], a[2], a[3] = 1, 0.95, 0.55 else a[1], a[2], a[3] = 0.2, 1, 0.8 end
end

function AG.Hex(c)
  return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

----------------------------------------------------------------------
-- pfUI lookups (all optional, every step is checked)
----------------------------------------------------------------------

local function Pf(section, group, key)
  local c = pfUI_config
  if type(c) ~= "table" then return nil end
  local s = c[section]
  if type(s) ~= "table" then return nil end
  if key == nil then return s[group] end
  local g = s[group]
  if type(g) ~= "table" then return nil end
  return g[key]
end

local function ParseColor(str, default)
  if type(str) ~= "string" then return default end
  local t = {}
  for v in string.gfind(str, "[^,]+") do
    table.insert(t, tonumber(v) or 0)
  end
  if table.getn(t) < 3 then return default end
  return { t[1], t[2], t[3], t[4] or 1 }
end

function AG.Colors()
  local c = {}
  c.bg = ParseColor(Pf("appearance", "border", "background"), { 0.08, 0.08, 0.08, 0.96 })
  c.border = ParseColor(Pf("appearance", "border", "color"), { 0.25, 0.25, 0.25, 1 })
  c.inset = { math.min(c.bg[1] + 0.05, 1), math.min(c.bg[2] + 0.05, 1), math.min(c.bg[3] + 0.05, 1), 1 }
  c.field = { math.max(c.bg[1] - 0.04, 0), math.max(c.bg[2] - 0.04, 0), math.max(c.bg[3] - 0.04, 0), 1 }
  return c
end

local FALLBACK_FONT = "Fonts\\ARIALN.TTF"

-- returns font path and base size (12 = our design size).
-- Taken from the text of the game tooltip, so our windows use exactly the font and size of
-- the interface (pfUI changes the tooltip font, and so do other UI addons).
function AG.FontInfo()
  local path = FALLBACK_FONT
  local size = 12
  local fs = GameTooltipTextLeft2 or GameTooltipTextLeft1
  if fs and fs.GetFont then
    local p, s = fs:GetFont()
    if type(p) == "string" and p ~= "" then path = p end
    if type(s) == "number" and s >= 8 and s <= 24 then size = s end
  end
  return path, size
end

----------------------------------------------------------------------
-- Registry: styled frames and fonts, so that Restyle() can redo them
----------------------------------------------------------------------

AG.styled = {}
AG.fonts = {}

local TIP_BG = "Interface\\Tooltips\\UI-Tooltip-Background"
local TIP_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local BTN_UP = "Interface\\Buttons\\UI-Panel-Button-Up"
local BTN_DOWN = "Interface\\Buttons\\UI-Panel-Button-Down"
local BTN_HI = "Interface\\Buttons\\UI-Panel-Button-Highlight"

-- the vanilla look of one frame kind
local function ApplyBlizzard(f, kind)
  if kind == "window" or kind == "tip" then
    f:SetBackdrop({ bgFile = TIP_BG, edgeFile = TIP_EDGE, tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    f:SetBackdropColor(0.07, 0.07, 0.15, 0.97)
    f:SetBackdropBorderColor(1, 1, 1, 1)
  elseif kind == "inset" then
    f:SetBackdrop({ bgFile = TIP_BG, edgeFile = TIP_EDGE, tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0, 0, 0, 0.45)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  elseif kind == "button" then
    f:SetBackdrop(nil)
    f:SetNormalTexture(BTN_UP)
    f:GetNormalTexture():SetTexCoord(0, 0.625, 0, 0.6875)
    f:SetPushedTexture(BTN_DOWN)
    f:GetPushedTexture():SetTexCoord(0, 0.625, 0, 0.6875)
    f:SetHighlightTexture(BTN_HI, "ADD")
    f:GetHighlightTexture():SetTexCoord(0, 0.625, 0, 0.6875)
  else
    -- fields: edit boxes, check boxes, bars, icon frames
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, tile = false, tileSize = 0, edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    f:SetBackdropColor(0, 0, 0, 0.6)
    f:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
  end
  if f.paint then f.paint(f) end
end

local function ApplyStyle(f, kind)
  if AG.Look() == "blizzard" then
    ApplyBlizzard(f, kind)
    return
  end
  local c = AG.Colors()
  local bg = c.bg
  if kind == "inset" or kind == "button" then bg = c.inset end
  if kind == "field" then bg = c.field end
  f:SetBackdrop({
    bgFile = WHITE, edgeFile = WHITE, tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
  f:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], c.border[4])
  if f.paint then f.paint(f) end
end

function AG.Style(f, kind)
  AG.ApplyLook()
  AG.styled[f] = kind
  ApplyStyle(f, kind)
end

local function ApplyFont(fs, size, flags)
  local path, base = AG.FontInfo()
  local s = math.floor(size * base / 12 + 0.5)
  if flags then fs:SetFont(path, s, flags) else fs:SetFont(path, s) end
  -- a bad font path leaves the string without a font: fall back to the game font
  if not fs:GetFont() then
    if flags then fs:SetFont(FALLBACK_FONT, s, flags) else fs:SetFont(FALLBACK_FONT, s) end
  end
end

function AG.SetFont(fs, size, flags)
  AG.fonts[fs] = { size, flags }
  ApplyFont(fs, size, flags)
end

-- line height that fits the current font size
function AG.LineHeight(size)
  local _, base = AG.FontInfo()
  return math.floor((size or 12) * base / 12 + 0.5) + 3
end

function AG.Restyle()
  for f, kind in pairs(AG.styled) do ApplyStyle(f, kind) end
  for fs, v in pairs(AG.fonts) do ApplyFont(fs, v[1], v[2]) end
end

function AG.OnConfig(key, value)
  if key == "look" then
    AG.ApplyLook()
    AG.Restyle()
    AG.Msg("look changed: /reload applies it everywhere")
  end
  if AG.Options and AG.Options.Sync then AG.Options.Sync() end
end

-- the look can only be told once every addon is loaded (pfUI loads after us)
local lookEv = CreateFrame("Frame")
lookEv:RegisterEvent("PLAYER_ENTERING_WORLD")
lookEv:SetScript("OnEvent", function() AG.ApplyLook() end)
