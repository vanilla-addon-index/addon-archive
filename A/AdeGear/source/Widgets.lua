-- pfUI-style widgets: text, button, checkbox, slider, edit box, window.

local AG = AdeGear
local W = {}
AG.W = W

local function Accent() return AG.C.accent end

function W.Text(parent, size, color, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  AG.SetFont(fs, size or 12)
  color = color or AG.C.text
  fs:SetTextColor(color[1], color[2], color[3])
  fs:SetJustifyH(justify or "LEFT")
  return fs
end

-- thin line / flat colored rectangle
function W.Box(parent, r, g, b, a, layer)
  local t = parent:CreateTexture(nil, layer or "ARTWORK")
  t:SetTexture(AG.WHITE)
  t:SetVertexColor(r, g, b, a or 1)
  return t
end

----------------------------------------------------------------------
-- Button. b.active highlights it (used for tabs and choices).
----------------------------------------------------------------------

local function PaintButton(b)
  if AG.Look() == "blizzard" then
    -- chosen tabs and choices look pressed
    if b.active then b:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Down") else b:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up") end
    b:GetNormalTexture():SetTexCoord(0, 0.625, 0, 0.6875)
    if b.text then
      local tc = b.active and AG.C.accent or AG.C.gold
      b.text:SetTextColor(tc[1], tc[2], tc[3])
    end
    return
  end
  local c = AG.Colors()
  local lit = b.active or b.hover
  local bd = lit and AG.C.accent or c.border
  b:SetBackdropBorderColor(bd[1], bd[2], bd[3], 1)
  if b.text then
    local tc = b.active and AG.C.accent or AG.C.text
    b.text:SetTextColor(tc[1], tc[2], tc[3])
  end
end

function W.Button(parent, label, width, height, onclick)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(width)
  b:SetHeight(height or 20)
  b.paint = PaintButton
  AG.Style(b, "button")
  b.text = W.Text(b, 12, AG.C.text, "CENTER")
  b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.text:SetText(label or "")
  b.onclick = onclick
  b.SetActive = function(self, on)
    self.active = on
    PaintButton(self)
  end
  b:SetScript("OnEnter", function() this.hover = true; PaintButton(this) end)
  b:SetScript("OnLeave", function() this.hover = false; PaintButton(this) end)
  b:SetScript("OnClick", function() if this.onclick then this.onclick() end end)
  PaintButton(b)
  return b
end

----------------------------------------------------------------------
-- Checkbox bound to a config key
----------------------------------------------------------------------

function W.Check(parent, label, key, width)
  local row = CreateFrame("Button", nil, parent)
  row:SetWidth(width or 300)
  row:SetHeight(18)

  local box = CreateFrame("Frame", nil, row)
  box:SetWidth(14)
  box:SetHeight(14)
  box:SetPoint("LEFT", row, "LEFT", 0, 0)
  AG.Style(box, "field")
  local mark = W.Box(box, AG.C.accent[1], AG.C.accent[2], AG.C.accent[3], 1, "OVERLAY")
  mark:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
  mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)

  local text = W.Text(row, 12)
  text:SetPoint("LEFT", box, "RIGHT", 7, 0)
  text:SetText(label)

  row.key = key
  row.Sync = function(self)
    if AG.Get(self.key) then mark:Show() else mark:Hide() end
  end
  row:SetScript("OnClick", function() AG.Set(this.key, not AG.Get(this.key)); this:Sync() end)
  row:SetScript("OnEnter", function() box:SetBackdropBorderColor(AG.C.accent[1], AG.C.accent[2], AG.C.accent[3], 1) end)
  row:SetScript("OnLeave", function()
    if AG.Look() == "blizzard" then box:SetBackdropBorderColor(0.55, 0.55, 0.55, 1) return end
    local c = AG.Colors()
    box:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 1)
  end)
  row:Sync()
  return row
end

----------------------------------------------------------------------
-- Slider bound to a config key, with a label and a value on the right
----------------------------------------------------------------------

function W.Slider(parent, label, key, min, max, step, width, suffix)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetWidth(width)
  holder:SetHeight(34)

  local text = W.Text(holder, 12)
  text:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
  text:SetText(label)
  local value = W.Text(holder, 12, AG.C.accent, "RIGHT")
  value:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)

  local s = CreateFrame("Slider", nil, holder)
  s:SetOrientation("HORIZONTAL")
  s:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -20)
  s:SetWidth(width)
  s:SetHeight(8)
  AG.Style(s, "field")
  local thumb
  if AG.Look() == "blizzard" then
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    thumb = s:GetThumbTexture()
    thumb:SetWidth(18)
    thumb:SetHeight(18)
  else
    s:SetThumbTexture(AG.WHITE)
    thumb = s:GetThumbTexture()
    thumb:SetVertexColor(AG.C.accent[1], AG.C.accent[2], AG.C.accent[3], 1)
    thumb:SetWidth(8)
    thumb:SetHeight(14)
  end
  s:SetMinMaxValues(min, max)
  s:SetValueStep(step)
  s.key = key
  s.suffix = suffix or ""
  s.valueText = value

  s:SetScript("OnValueChanged", function()
    local v = this:GetValue()
    this.valueText:SetText(v .. this.suffix)
    if not this.syncing then AG.Set(this.key, v) end
  end)
  holder.slider = s
  holder.Sync = function(self)
    self.slider.syncing = true
    self.slider:SetValue(AG.Get(self.slider.key))
    self.slider.valueText:SetText(AG.Get(self.slider.key) .. self.slider.suffix)
    self.slider.syncing = false
  end
  holder:Sync()
  return holder
end

----------------------------------------------------------------------
-- Edit box
----------------------------------------------------------------------

function W.Edit(parent, width, height)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetWidth(width)
  e:SetHeight(height or 20)
  e:SetAutoFocus(false)
  e:SetTextInsets(5, 5, 0, 0)
  AG.SetFont(e, 12)
  AG.Style(e, "field")
  e:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  e:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  e:SetScript("OnEditFocusGained", function() this:SetBackdropBorderColor(AG.C.accent[1], AG.C.accent[2], AG.C.accent[3], 1) end)
  e:SetScript("OnEditFocusLost", function()
    if AG.Look() == "blizzard" then this:SetBackdropBorderColor(0.55, 0.55, 0.55, 1) return end
    local c = AG.Colors()
    this:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 1)
  end)
  return e
end

----------------------------------------------------------------------
-- Window with title, close button, drag and saved position
----------------------------------------------------------------------

function W.Window(name, title, width, height, strata)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetWidth(width)
  f:SetHeight(height)
  f:SetFrameStrata(strata or "DIALOG")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing(); AG.SavePos(this) end)
  AG.Style(f, "window")

  f.title = W.Text(f, 13, AG.Look() == "blizzard" and AG.C.gold or AG.C.text, "LEFT")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
  f.title:SetText(title)

  local line = W.Box(f, 0.25, 0.25, 0.25, 1)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -28)
  line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -28)
  f.titleLine = line

  f.close = W.Button(f, "x", 18, 18, function() f:Hide() end)
  f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)

  if name then table.insert(UISpecialFrames, name) end
  f:Hide()
  return f
end
