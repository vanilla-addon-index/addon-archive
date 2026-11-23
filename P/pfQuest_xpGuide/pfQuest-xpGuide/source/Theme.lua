-- pfQuest xpGuide: the look. With pfUI loaded, every window takes pfUI's theme the way OctoPad does: pfUI's rounded backdrop
-- in the colours of your pfUI profile (background, border), pfUI's font, a cyan accent (#33ffcc), flat buttons whose
-- border lights up in the accent on mouse-over and that turn accent when selected, small accent headers with a thin
-- line, pfUI's own checkboxes, input boxes and scroll bars, a flat "x" close button, and icons cropped inside a rounded
-- border. Without pfUI (or with "Use pfUI's look" unticked in the settings) nothing here runs and the windows keep
-- their own look.
--
-- How it is used: a window calls ER.Skin.Window(frame, alpha) right after giving the frame its backdrop, and
-- ER.Skin.Tree(frame) once its contents are built. Tree walks the frame and everything in it and skins what it
-- recognises by its textures (Blizzard's panel button, close button and checkbox, Interface\Icons icons, the quest
-- title highlight) and by type (input boxes, scroll frames, font strings). Every step is safe to run twice.

local ER = pfQuest_xpGuide
ER.Skin = ER.Skin or {}
local K = ER.Skin

local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local FLAT = { bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }

-- On when pfUI is there with its backdrop API and you have not turned the look off. Read when a window is built.
function K.On()
  if ER.db and ER.db.pfuiThemeOff then return false end
  return (pfUI and pfUI.api and pfUI.api.CreateBackdrop and pfUI_config and pfUI_config.appearance) and true or false
end

function K.Available()
  return (pfUI and pfUI.api and pfUI.api.CreateBackdrop and pfUI_config and pfUI_config.appearance) and true or false
end

function K.Font()
  return (pfUI and pfUI.font_default) or "Fonts\\FRIZQT__.TTF"
end

local function ParseColor(str, d)
  if type(str) == "string" then
    local _, _, r, g, b, a = string.find(str, "([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,?%s*([%d%.]*)")
    if r then return { tonumber(r), tonumber(g), tonumber(b), tonumber(a) or 1 } end
  end
  return d
end

-- The colours, as OctoPad works them out: pfUI's background and border, a lighter fill for buttons, a darker sidebar.
function K.Theme()
  local t = { bg = { .05, .06, .08, .92 }, bd = { .25, .27, .3, 1 }, ac = { .2, 1, .8, 1 } }
  local ap = pfUI_config and pfUI_config.appearance
  if ap and ap.border then
    t.bg = ParseColor(ap.border.background, t.bg)
    t.bd = ParseColor(ap.border.color, t.bd)
    if t.bg[4] > .95 then t.bg[4] = .95 end
  end
  t.fill = { math.min(1, t.bg[1] + .07), math.min(1, t.bg[2] + .07), math.min(1, t.bg[3] + .07), 1 }
  t.side = { math.max(0, t.bg[1] - .02), math.max(0, t.bg[2] - .02), math.max(0, t.bg[3] - .02), 1 }
  return t
end

K.ACCENT = "|cff33ffcc"

local function Safe(fn, a, b, c, d)
  local ok, r = pcall(fn, a, b, c, d)
  if ok then return r end
  return nil
end

-- The frame that carries the colours: pfUI's backdrop frame when pfUI drew one, else the frame itself.
function K.BD(f)
  if f.erRound and f.backdrop then return f.backdrop end
  return f
end

-- A gold border (the step box, the tips box) means "this one": under the theme that is the accent.
local function Goldish(r, g, b)
  return r and g and b and r > .7 and g > .45 and g < .8 and b < .45
end

-- pfUI's rounded backdrop on a frame. The frame's own backdrop goes; later colour calls are sent on to pfUI's backdrop
-- (border colours, with gold turned into the accent) or kept from changing pfUI's background (fill colours).
function K.Window(f, alpha)
  if not f or not K.On() then return false end
  if f.erRound ~= nil then return f.erRound end
  local wasGold
  if f.GetBackdropBorderColor then
    local ok, r, g, b = pcall(f.GetBackdropBorderColor, f)
    wasGold = ok and Goldish(r, g, b)
  end
  local ok = pcall(pfUI.api.CreateBackdrop, f, nil, nil, alpha or .9)
  f.erRound = (ok and f.backdrop) and true or false
  if not f.erRound then return false end
  pcall(f.SetBackdrop, f, nil)
  local t = K.Theme()
  f.SetBackdrop = function() end
  f.SetBackdropColor = function() end
  f.SetBackdropBorderColor = function(self, r, g, b, a)
    if Goldish(r, g, b) then r, g, b, a = t.ac[1], t.ac[2], t.ac[3], 1 end
    if self.backdrop then self.backdrop:SetBackdropBorderColor(r, g, b, a or 1) end
  end
  if wasGold then f.backdrop:SetBackdropBorderColor(t.ac[1], t.ac[2], t.ac[3], 1) end
  return true
end

-- pfUI's font on a font string, keeping its size and outline.
function K.FontOn(fs)
  if not fs or fs.erFont or not fs.GetFont then return end
  local ok, _, size, flags = pcall(fs.GetFont, fs)
  if ok and size and size > 0 then
    pcall(fs.SetFont, fs, K.Font(), size, flags or "")
    fs.erFont = true
  end
end

local function Chain(f, script, after)
  local old = f:GetScript(script)
  f:SetScript(script, function()
    if old then old() end
    after(this)
  end)
end

-- Selected / not selected, as OctoPad's SetSel: accent border, accent-tinted fill and accent text when selected.
function K.Select(b, on)
  local t = K.Theme()
  local g = K.BD(b)
  b.erSel = on
  if on then
    g:SetBackdropColor(t.fill[1] * .5 + t.ac[1] * .12, t.fill[2] * .5 + t.ac[2] * .12, t.fill[3] * .5 + t.ac[3] * .12, 1)
    g:SetBackdropBorderColor(t.ac[1], t.ac[2], t.ac[3], 1)
    if b.erText then b.erText:SetTextColor(t.ac[1], t.ac[2], t.ac[3]) end
  else
    g:SetBackdropColor(t.fill[1], t.fill[2], t.fill[3], 1)
    g:SetBackdropBorderColor(t.bd[1], t.bd[2], t.bd[3], 1)
    if b.erText then b.erText:SetTextColor(.9, .9, .9) end
  end
end

local function ButtonText(b)
  local fs = b.GetFontString and Safe(function() return b:GetFontString() end)
  if not fs and b.GetName and b:GetName() then fs = getglobal(b:GetName() .. "Text") end
  return fs
end

-- OctoPad's flat button: rounded fill, theme border, accent border on mouse-over, accent when locked (selected).
function K.Flat(b)
  if not b or b.erFlat or not K.On() then return end
  b.erFlat = true
  pcall(b.SetNormalTexture, b, "")
  pcall(b.SetPushedTexture, b, "")
  pcall(b.SetHighlightTexture, b, "")
  pcall(b.SetDisabledTexture, b, "")
  if not K.Window(b, 1) then
    b.SetBackdrop = nil
    b:SetBackdrop(FLAT)
  end
  b.erText = ButtonText(b)
  if b.erText then K.FontOn(b.erText) end
  K.Select(b, false)
  Chain(b, "OnEnter", function(self)
    local t = K.Theme()
    K.BD(self):SetBackdropBorderColor(t.ac[1], t.ac[2], t.ac[3], 1)
  end)
  Chain(b, "OnLeave", function(self) K.Select(self, self.erSel) end)
  b.LockHighlight = function(self) K.Select(self, true) end
  b.UnlockHighlight = function(self) K.Select(self, false) end
end

-- The close button: OctoPad's flat "x" in the top right corner.
-- Where a corner or edge anchor sits from a frame's centre, in half widths and heights.
local CENTRE_FROM = { TOPLEFT = { 1, -1 }, TOP = { 0, -1 }, TOPRIGHT = { -1, -1 }, LEFT = { 1, 0 }, CENTER = { 0, 0 },
  RIGHT = { -1, 0 }, BOTTOMLEFT = { 1, 1 }, BOTTOM = { 0, 1 }, BOTTOMRIGHT = { -1, 1 } }

function K.Close(b)
  if not b or b.erFlat or not K.On() then return end
  local parent = b:GetParent()
  -- The button keeps its place: the window put it where it belongs (the step window's sits above the step box, next to the
  -- "Step 3 of 20" tab), so the smaller flat button is centred where the old one's middle was.
  local point, rel, relPoint, x, y = b:GetPoint(1)
  local off = point and CENTRE_FROM[point]
  local w, h = b:GetWidth() or 32, b:GetHeight() or 32
  b:SetWidth(20)
  b:SetHeight(20)
  if off then
    b:ClearAllPoints()
    b:SetPoint("CENTER", rel or parent, relPoint or point, (x or 0) + off[1] * w / 2, (y or 0) + off[2] * h / 2)
  elseif parent then
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
  end
  if not ButtonText(b) then
    local fs = b:CreateFontString(nil, "OVERLAY")
    fs:SetFont(K.Font(), 11)
    fs:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.erCloseText = fs
    b.GetFontString = function() return fs end
  end
  K.Flat(b)
  if b.erText then b.erText:SetText("x") end
end

function K.Check(c)
  if not c or c.erCheck or not K.On() then return end
  c.erCheck = true
  if pfUI.api.SkinCheckbox then pcall(pfUI.api.SkinCheckbox, c, 18) end
  if c.GetName and c:GetName() then K.FontOn(getglobal(c:GetName() .. "Text")) end
end

function K.Input(e)
  if not e or e.erInput or not K.On() then return end
  e.erInput = true
  if pfUI.api.StripTextures then pcall(pfUI.api.StripTextures, e) end
  K.Window(e, 1)
  if e.GetFont then
    local _, size = Safe(function() return e:GetFont() end)
    pcall(e.SetFont, e, K.Font(), size or 12, "")
  end
end

function K.Scroll(sf)
  if not sf or sf.erScroll or not K.On() then return end
  sf.erScroll = true
  local name = sf.GetName and sf:GetName()
  local bar = name and getglobal(name .. "ScrollBar")
  if bar and pfUI.api.SkinScrollbar then pcall(pfUI.api.SkinScrollbar, bar) end
end

-- An icon button (the gear, the book): cropped icon inside a rounded border that lights up on mouse-over.
function K.IconButton(b)
  if not b or b.erIcon or not K.On() then return end
  b.erIcon = true
  local n = b.GetNormalTexture and b:GetNormalTexture()
  if n then
    n:SetTexCoord(.07, .93, .07, .93)
    n:ClearAllPoints()
    n:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    n:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
  end
  pcall(b.SetHighlightTexture, b, "")
  pcall(b.SetPushedTexture, b, "")
  if K.Window(b, 1) then
    local t = K.Theme()
    K.BD(b):SetBackdropBorderColor(t.bd[1], t.bd[2], t.bd[3], 1)
    Chain(b, "OnEnter", function(self) local th = K.Theme() K.BD(self):SetBackdropBorderColor(th.ac[1], th.ac[2], th.ac[3], 1) end)
    Chain(b, "OnLeave", function(self) local th = K.Theme() K.BD(self):SetBackdropBorderColor(th.bd[1], th.bd[2], th.bd[3], 1) end)
  end
end

-- OctoPad's header: small upper-case accent text with a thin accent line under it.
function K.Header(fs, rule)
  if not K.On() then return end
  local t = K.Theme()
  if fs then
    local text = fs:GetText()
    if text then fs:SetText(string.upper(string.gsub(text, "|c%x%x%x%x%x%x%x%x", ""))) end
    pcall(fs.SetFont, fs, K.Font(), 10, "")
    fs:SetTextColor(t.ac[1], t.ac[2], t.ac[3])
    fs.erFont = true
  end
  if rule then
    rule:SetTexture(WHITE8)
    rule:SetVertexColor(t.ac[1], t.ac[2], t.ac[3], .35)
  end
end

-- A window title the OctoPad way: the accent name in pfUI's font, outlined.
function K.Title(fs, size)
  if not fs or not K.On() then return end
  pcall(fs.SetFont, fs, K.Font(), size or 14, "OUTLINE")
  fs.erFont = true
end

local function Lower(s) return type(s) == "string" and string.lower(s) or "" end
local function Has(s, part) return string.find(s, part, 1, true) ~= nil end

local function SkinRegion(r)
  local kind = r.GetObjectType and r:GetObjectType()
  if kind == "FontString" then
    K.FontOn(r)
  elseif kind == "Texture" and not r.erTex then
    local path = Lower(r.GetTexture and r:GetTexture())
    if Has(path, "ui-questtitlehighlight") or Has(path, "buttonhilight-square") then
      -- the row highlight: a soft accent tint, as OctoPad's focus tint
      local t = K.Theme()
      r:SetTexture(WHITE8)
      r:SetVertexColor(t.ac[1], t.ac[2], t.ac[3], .16)
      r.erTex = true
    elseif Has(path, "interface\\icons\\") then
      r:SetTexCoord(.07, .93, .07, .93)
      r.erTex = true
    end
  end
end

local function NormalPath(f)
  local n = f.GetNormalTexture and Safe(function() return f:GetNormalTexture() end)
  return Lower(n and n.GetTexture and n:GetTexture())
end

local function Walk(f, depth)
  if not f or depth > 12 then return end
  local kind = f.GetObjectType and f:GetObjectType()
  if kind == "Button" or kind == "CheckButton" then
    local path = NormalPath(f)
    if Has(path, "ui-panel-minimizebutton") then K.Close(f)
    elseif Has(path, "ui-panel-button") then K.Flat(f)
    elseif Has(path, "ui-checkbox") then K.Check(f)
    elseif Has(path, "interface\\icons\\") then K.IconButton(f) end
  elseif kind == "EditBox" then
    local name = f.GetName and f:GetName()
    if name and getglobal(name .. "Left") then K.Input(f) end
    K.FontOn(f)
  elseif kind == "ScrollFrame" then
    K.Scroll(f)
  end
  if f.GetRegions then
    local regions = { f:GetRegions() }
    for _, r in ipairs(regions) do SkinRegion(r) end
  end
  if f.GetChildren then
    local kids = { f:GetChildren() }
    for _, c in ipairs(kids) do Walk(c, depth + 1) end
  end
end

-- Skins a window and everything in it now.
function K.Tree(f)
  if not f or not K.On() then return end
  pcall(Walk, f, 0)
end

-- The top-level windows. Each is skinned the moment it opens and once a second besides, for rows and buttons made after
-- it was built (a window's own OnShow is never touched). Everything already skinned is passed over quickly.
K.windows = {}
function K.Register(f)
  if not f or f.erRegistered then return end
  f.erRegistered = true
  table.insert(K.windows, f)
end

local TOP = { UIParent = true, Minimap = true, QuestLogFrame = true }
local rawWindow = K.Window
K.Window = function(f, alpha)
  local ok = rawWindow(f, alpha)
  if ok then
    -- register the window this frame belongs to: its highest ancestor under UIParent (or Minimap, the quest log)
    local top, depth = f, 0
    while top and depth < 20 do
      local p = top.GetParent and top:GetParent()
      local pn = p and p.GetName and p:GetName()
      if not p or (pn and TOP[pn]) then break end
      top, depth = p, depth + 1
    end
    if top then K.Register(top) end
  end
  return ok
end

local driver = CreateFrame("Frame", "pfQuest_xpGuideThemeDriver")
driver.quick, driver.slow = 0, 0
driver:SetScript("OnUpdate", function()
  this.quick = this.quick + arg1
  this.slow = this.slow + arg1
  if this.quick < 0.1 then return end
  this.quick = 0
  local full = this.slow >= 1
  if full then this.slow = 0 end
  if not K.On() then return end
  for _, f in ipairs(K.windows) do
    local shown = f:IsShown() and true or false
    -- a window that just opened at once; every window, open or not, once a second (so one built hidden is ready before it shows)
    if (shown and not f.erWasShown) or full then pcall(Walk, f, 0) end
    f.erWasShown = shown
  end
end)

-- pfUI keeps the minimap square unless its minimap module is off; OctoPad places its button on the square's edge then.
function K.SquareMinimap()
  if not K.On() then return false end
  return not (pfUI_config and pfUI_config.disabled and pfUI_config.disabled["minimap"] == "1")
end

------------------------------------------------------------------------------------------------------
-- Text: pfQuest's font and size
------------------------------------------------------------------------------------------------------
-- The guide's text uses pfQuest's font (pfUI's when pfUI is there; pfQuest brings its own otherwise) at the size of pfQuest's
-- quest tracker ("Quest Tracker Font Size" in pfQuest's settings), so the guide reads like pfQuest's own lists. The size can be
-- set in Settings instead (Text size, or /xpg font 13); "pfQuest's" goes back to following pfQuest.

ER.fontStrings = setmetatable({}, { __mode = "k" })   -- every font string that follows the size, with its offset from it

function ER.FontFace()
  return (pfUI and pfUI.font_default) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

-- pfQuest's size: its quest tracker's, else pfUI's (or pfQuest's stand-in for it), else 12.
function ER.FontSizePfQuest()
  local n = pfQuest_config and tonumber(pfQuest_config["trackerfontsize"])
  if n and n >= 6 and n <= 40 then return n end
  n = pfUI_config and pfUI_config.global and tonumber(pfUI_config.global.font_size)
  if n and n >= 6 and n <= 40 then return n end
  return 12
end

-- The size in use: the one set in Settings, or pfQuest's.
function ER.FontSize()
  local n = ER.db and tonumber(ER.db.fontSize)
  if n and n >= 6 and n <= 40 then return n end
  return ER.FontSizePfQuest()
end

-- Puts a font string on the guide's font, at the size in use plus delta (the heading a size up, small print a size or two down).
function ER.ApplyFont(fs, delta, flags)
  if not fs or not fs.SetFont then return end
  fs.erDelta, fs.erFlags = delta or 0, flags
  ER.fontStrings[fs] = true
  local size = ER.FontSize() + (delta or 0)
  if size < 8 then size = 8 end
  pcall(fs.SetFont, fs, ER.FontFace(), size, flags or "")
  fs.erFont = true   -- the theme leaves it alone
end

-- Sets the size (a number, or nil for pfQuest's), puts every font string on it and lays the windows out again.
function ER.SetFontSize(n)
  if not ER.db then return end
  ER.db.fontSize = n and tonumber(n) or nil
  for fs in pairs(ER.fontStrings) do ER.ApplyFont(fs, fs.erDelta, fs.erFlags) end
  if ER.FontsChanged then ER.FontsChanged() end
end

-- The words for the size: "pfQuest's (12)" or "14".
function ER.FontSizeLabel()
  if ER.db and tonumber(ER.db.fontSize) then return tostring(ER.FontSize()) end
  return "pfQuest's (" .. ER.FontSizePfQuest() .. ")"
end

-- One size smaller (d = -1) or bigger (d = 1), from the size in use, 8 to 24: the Settings arrows.
ER.FONT_MIN, ER.FONT_MAX = 8, 24
function ER.NudgeFontSize(d)
  local n = ER.FontSize() + (d or 0)
  if n < ER.FONT_MIN then n = ER.FONT_MIN end
  if n > ER.FONT_MAX then n = ER.FONT_MAX end
  ER.SetFontSize(n)
end

-- /xpg theme and the settings tick: pfUI's look on or off. Windows are built once, so the change shows after a /reload.
function ER.ToggleTheme()
  if not ER.db then return end
  ER.db.pfuiThemeOff = not ER.db.pfuiThemeOff
  local msg
  if not K.Available() then
    msg = "pfUI is not loaded, so pfQuest xpGuide keeps its own look."
  elseif ER.db.pfuiThemeOff then
    msg = "pfQuest xpGuide's own look. Type |cffffd100/reload|r to see it."
  else
    msg = "pfUI's look. Type |cffffd100/reload|r to see it."
  end
  if ER.Print then ER.Print(msg) end
end

ER.Loaded("Theme.lua")
