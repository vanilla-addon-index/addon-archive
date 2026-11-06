--[[
  TankSuite - UI toolkit
  Small flat, dark widgets drawn from plain frames + textures (no Blizzard
  templates, so nothing depends on FrameXML details of a given client build).
]]

local TS = TankSuite
local UI = { widgets = {}, texts = {} }
TS.UI = UI

local FONT = "Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"
UI.FONT, UI.WHITE = FONT, WHITE

UI.C = {
  bg      = { 0.050, 0.058, 0.075, 0.97 },
  side    = { 0.035, 0.041, 0.055, 1.00 },
  panel   = { 0.085, 0.095, 0.120, 1.00 },
  input   = { 0.025, 0.030, 0.040, 1.00 },
  btn     = { 0.110, 0.125, 0.155, 1.00 },
  btnHi   = { 0.150, 0.175, 0.220, 1.00 },
  border  = { 0.190, 0.215, 0.265, 1.00 },
  accent  = { 0.200, 0.630, 0.950, 1.00 },
  text    = { 0.920, 0.940, 0.960, 1.00 },
  dim     = { 0.560, 0.610, 0.680, 1.00 },
  good    = { 0.300, 0.900, 0.400, 1.00 },
  bad     = { 1.000, 0.330, 0.330, 1.00 },
  track   = { 0.150, 0.170, 0.210, 1.00 },
}
local C = UI.C

----------------------------------------------------------------------
-- Basics
----------------------------------------------------------------------
function UI.Solid(parent, layer, color)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  t:SetTexture(WHITE)
  t:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  return t
end

function UI.Box(f, bg, border)
  f:SetBackdrop({
    bgFile = WHITE, edgeFile = WHITE, tile = false, tileSize = 8, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  f:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

function UI.Text(parent, text, size, color)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(FONT, size or 11)
  color = color or C.text
  fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  fs:SetJustifyH("LEFT")
  fs:SetText(text or "")
  return fs
end

-- text that follows the language setting
function UI.LText(parent, key, size, color)
  local fs = UI.Text(parent, TS.L(key), size, color)
  table.insert(UI.texts, { fs, key })
  return fs
end

function UI.Relocalize()
  for i = 1, table.getn(UI.texts) do
    local t = UI.texts[i]
    t[1]:SetText(TS.L(t[2]))
  end
end

function UI.RefreshAll()
  UI.Relocalize()
  for i = 1, table.getn(UI.widgets) do
    local w = UI.widgets[i]
    if w.Refresh then w.Refresh() end
  end
end

local function Track(w)
  table.insert(UI.widgets, w)
  return w
end

local function Tip(frame, key)
  TS.HookScript(frame, "OnEnter", function()
    if not key then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(TS.L(key), 1, 1, 1, 1, 1)
    GameTooltip:Show()
  end)
  TS.HookScript(frame, "OnLeave", function() GameTooltip:Hide() end)
end
UI.Tip = Tip

local function Click()
  PlaySound("igMainMenuOption")
end

----------------------------------------------------------------------
-- Section header
----------------------------------------------------------------------
function UI.Section(parent, key, width)
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(width or 480)
  f:SetHeight(22)
  local fs = UI.LText(f, key, 12, C.accent)
  fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -2)
  local line = UI.Solid(f, "ARTWORK", C.border)
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  return f
end

----------------------------------------------------------------------
-- Button
----------------------------------------------------------------------
function UI.Button(parent, key, width, height, onclick)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(width)
  b:SetHeight(height or 24)
  UI.Box(b, C.btn, C.border)
  b.label = UI.LText(b, key, 11, C.text)
  b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.label:SetJustifyH("CENTER")
  b:SetScript("OnEnter", function()
    this:SetBackdropColor(C.btnHi[1], C.btnHi[2], C.btnHi[3], 1)
    this:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
  end)
  b:SetScript("OnLeave", function()
    this:SetBackdropColor(C.btn[1], C.btn[2], C.btn[3], 1)
    this:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
  end)
  b:SetScript("OnClick", function()
    Click()
    if onclick then onclick() end
  end)
  return b
end

----------------------------------------------------------------------
-- Checkbox
----------------------------------------------------------------------
function UI.Checkbox(parent, key, get, set, tipKey, width)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(width or 230)
  b:SetHeight(22)
  local box = CreateFrame("Frame", nil, b)
  box:SetWidth(16)
  box:SetHeight(16)
  box:SetPoint("LEFT", b, "LEFT", 0, 0)
  UI.Box(box, C.input, C.border)
  local fill = UI.Solid(box, "ARTWORK", C.accent)
  fill:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
  fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
  local label = UI.LText(b, key, 11, C.text)
  label:SetPoint("LEFT", box, "RIGHT", 8, 0)

  b.Refresh = function()
    if get() then fill:Show() else fill:Hide() end
  end
  b:SetScript("OnClick", function()
    set(not get())
    b.Refresh()
    Click()
  end)
  b:SetScript("OnEnter", function()
    box:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
  end)
  b:SetScript("OnLeave", function()
    box:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
  end)
  Tip(b, tipKey)
  b.Refresh()
  return Track(b)
end

----------------------------------------------------------------------
-- Cycle: click = next value, right click = previous
-- options = { { value, langKey }, ... }   (a third entry is used as literal text)
----------------------------------------------------------------------
function UI.Cycle(parent, key, options, get, set, tipKey)
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(480)
  f:SetHeight(24)
  local label = UI.LText(f, key, 11, C.text)
  label:SetPoint("LEFT", f, "LEFT", 0, 0)

  local b = CreateFrame("Button", nil, f)
  b:SetWidth(190)
  b:SetHeight(22)
  b:SetPoint("LEFT", f, "LEFT", 200, 0)
  UI.Box(b, C.btn, C.border)
  local txt = UI.Text(b, "", 11, C.text)
  txt:SetPoint("CENTER", b, "CENTER", 0, 0)
  txt:SetJustifyH("CENTER")
  local l = UI.Text(b, "<", 12, C.accent)
  l:SetPoint("LEFT", b, "LEFT", 8, 0)
  local r = UI.Text(b, ">", 12, C.accent)
  r:SetPoint("RIGHT", b, "RIGHT", -8, 0)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  local function index()
    local v = get()
    for i = 1, table.getn(options) do
      if options[i][1] == v then return i end
    end
    return 1
  end
  f.Refresh = function()
    local o = options[index()]
    txt:SetText(o[3] or TS.L(o[2]))
  end
  b:SetScript("OnClick", function()
    local i = index()
    if arg1 == "RightButton" then i = i - 1 else i = i + 1 end
    if i < 1 then i = table.getn(options) end
    if i > table.getn(options) then i = 1 end
    set(options[i][1])
    f.Refresh()
    Click()
  end)
  b:SetScript("OnEnter", function()
    this:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
  end)
  b:SetScript("OnLeave", function()
    this:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
  end)
  Tip(b, tipKey)
  f.Refresh()
  return Track(f)
end

----------------------------------------------------------------------
-- Slider
----------------------------------------------------------------------
function UI.Slider(parent, key, minV, maxV, step, get, set, tipKey)
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(480)
  f:SetHeight(24)
  local label = UI.LText(f, key, 11, C.text)
  label:SetPoint("LEFT", f, "LEFT", 0, 0)

  local s = CreateFrame("Slider", nil, f)
  s:SetWidth(170)
  s:SetHeight(16)
  s:SetPoint("LEFT", f, "LEFT", 200, 0)
  s:SetOrientation("HORIZONTAL")
  local track = UI.Solid(s, "BACKGROUND", C.track)
  track:SetHeight(4)
  track:SetPoint("LEFT", s, "LEFT", 0, 0)
  track:SetPoint("RIGHT", s, "RIGHT", 0, 0)
  s:SetThumbTexture(WHITE)
  local thumb = s:GetThumbTexture()
  thumb:SetWidth(10)
  thumb:SetHeight(16)
  thumb:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  local val = UI.Text(f, "", 11, C.accent)
  val:SetPoint("LEFT", s, "RIGHT", 12, 0)

  s:SetScript("OnValueChanged", function()
    if f.updating then return end
    local v = math.floor(this:GetValue() / step + 0.5) * step
    val:SetText(tostring(v))
    set(v)
  end)
  f.Refresh = function()
    f.updating = true
    local v = get()
    s:SetValue(v)
    val:SetText(tostring(v))
    f.updating = false
  end
  Tip(s, tipKey)
  f.Refresh()
  return Track(f)
end

----------------------------------------------------------------------
-- Edit boxes
----------------------------------------------------------------------
local function MakeEditBox(parent, width, get, set, maxLetters)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetWidth(width)
  e:SetHeight(22)
  UI.Box(e, C.input, C.border)
  e:SetFont(FONT, 11)
  e:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
  if e.SetTextInsets then e:SetTextInsets(6, 6, 0, 0) end
  e:SetAutoFocus(false)
  e:SetMaxLetters(maxLetters or 200)
  e:SetScript("OnEnterPressed", function()
    set(this:GetText())
    this:ClearFocus()
  end)
  e:SetScript("OnEscapePressed", function()
    this.cancel = true
    this:ClearFocus()
  end)
  e:SetScript("OnEditFocusGained", function()
    this:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
  end)
  e:SetScript("OnEditFocusLost", function()
    this:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    if this.cancel then
      this.cancel = false
      this:SetText(get() or "")
    else
      set(this:GetText())
    end
  end)
  return e
end

-- label on the left, box on the right
function UI.EditRow(parent, key, get, set, tipKey)
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(480)
  f:SetHeight(24)
  local label = UI.LText(f, key, 11, C.text)
  label:SetPoint("LEFT", f, "LEFT", 0, 0)
  local e = MakeEditBox(f, 190, get, set, 40)
  e:SetPoint("LEFT", f, "LEFT", 200, 0)
  f.Refresh = function() e:SetText(get() or "") end
  Tip(e, tipKey)
  f.Refresh()
  return Track(f)
end

-- label above, full-width box below
function UI.Edit(parent, key, width, get, set)
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(width)
  f:SetHeight(44)
  local label = UI.LText(f, key, 11, C.dim)
  label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  local e = MakeEditBox(f, width, get, set, 240)
  e:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -17)
  f.box = e
  f.Refresh = function() e:SetText(get() or "") end
  f.Refresh()
  return Track(f)
end

-- box + button on one line (used for "add tank by name")
function UI.EditInline(parent, width)
  return MakeEditBox(parent, width, function() return "" end, function() end, 24)
end

----------------------------------------------------------------------
-- Colour swatch
----------------------------------------------------------------------
function UI.OpenColorPicker(color, onChange)
  local r, g, b = color[1], color[2], color[3]
  if not (ColorPickerFrame and ColorPickerFrame.SetColorRGB) then return end
  ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  ColorPickerFrame.hasOpacity = nil
  ColorPickerFrame.opacityFunc = nil
  ColorPickerFrame.previousValues = { r, g, b }
  ColorPickerFrame.func = function()
    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
    onChange(nr, ng, nb)
  end
  ColorPickerFrame.cancelFunc = function(prev)
    prev = prev or { r, g, b }
    onChange(prev[1], prev[2], prev[3])
  end
  ColorPickerFrame:SetColorRGB(r, g, b)
  ColorPickerFrame:Hide()
  ColorPickerFrame:Show()
end

-- a bare swatch button; getColor() must return { r, g, b, a }
function UI.SwatchButton(parent, getColor, onChange, width, height)
  local s = CreateFrame("Button", nil, parent)
  s:SetWidth(width or 44)
  s:SetHeight(height or 18)
  UI.Box(s, C.input, C.border)
  local tex = UI.Solid(s, "ARTWORK", { 1, 1, 1, 1 })
  tex:SetPoint("TOPLEFT", s, "TOPLEFT", 2, -2)
  tex:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -2, 2)
  s.Refresh = function()
    local c = getColor()
    tex:SetVertexColor(c[1], c[2], c[3], 1)
  end
  s:SetScript("OnClick", function()
    Click()
    UI.OpenColorPicker(getColor(), function(r, g, b)
      onChange(r, g, b)
      s.Refresh()
      if UI.OnColorChanged then UI.OnColorChanged() end
    end)
  end)
  s:SetScript("OnEnter", function()
    this:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
  end)
  s:SetScript("OnLeave", function()
    this:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
  end)
  s.Refresh()
  return s
end

function UI.Swatch(parent, key, getColor, onChange, tipKey)
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(480)
  f:SetHeight(24)
  local label = UI.LText(f, key, 11, C.text)
  label:SetPoint("LEFT", f, "LEFT", 0, 0)
  local s = UI.SwatchButton(f, getColor, onChange, 60, 18)
  s:SetPoint("LEFT", f, "LEFT", 200, 0)
  f.Refresh = function() s.Refresh() end
  Tip(s, tipKey)
  return Track(f)
end

----------------------------------------------------------------------
-- Layout helper: absolute placement inside a parent
----------------------------------------------------------------------
function UI.Place(w, x, y)
  w:ClearAllPoints()
  w:SetPoint("TOPLEFT", w:GetParent(), "TOPLEFT", x, -y)
end
