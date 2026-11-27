-- AdeLazyBuffs settings window: pfUI look when pfUI is installed, Blizzard look otherwise.
-- Written for the Lua 5.0 client: no '#', no '%', no select(), no string.match.

local A = AdeLazyBuffs
local ROWS, ROW_H = 5, 20
local win

local function UsePf()
  return (pfUI and pfUI.api and pfUI.api.CreateBackdrop) and true or false
end

local function Try(fn, a, b, c, d)
  if type(fn) == "function" then pcall(fn, a, b, c, d) end
end

local function Skin(name, obj, a, b, c)
  if UsePf() then Try(pfUI.api[name], obj, a, b, c) end
end

local function LangName()
  local l = A.DB and A.DB.lang
  if l == "en" then return "English" end
  if l == "ru" then return "Русский" end
  return A.T("Auto")
end

local TRIG = { any = "any button", wheel = "mouse wheel", key = "own key" }
function A.TriggerName()
  return A.T(TRIG[(A.DB and A.DB.trigger) or "any"] or "any button")
end

local function Clock(sec)
  if not sec then return "-" end
  if sec <= 0 then return "0:00" end
  sec = math.floor(sec)
  return string.format("%d:%02d", math.floor(sec / 60), math.mod(sec, 60))
end

---------------------------------------------------------------------------
-- Remembered targets list
---------------------------------------------------------------------------

function A.RefreshList()
  if not win or not win.built then return end
  local names = A.SortedNames()
  local count = table.getn(names)
  FauxScrollFrame_Update(win.scroll, count, ROWS, ROW_H)
  local offset = FauxScrollFrame_GetOffset(win.scroll)
  local map = A.GroupMap()
  local tx, lf, n = A.PlayerBuffs()
  local i
  for i = 1, ROWS do
    local row = win.rows[i]
    local key = names[i + offset]
    if key then
      local e = A.DB.targets[key]
      row.name = key
      row.nameText:SetText(e.name)
      local sp = e.spell
      if e.greater and not string.find(sp, "Greater", 1, true) and not string.find(sp, "Великое", 1, true) then
        sp = sp .. " " .. A.T("(Greater)")
      end
      row.spellText:SetText(sp)
      local rem = A.Remaining(e.name, e, map[e.name], tx, lf, n)
      row.timeText:SetText(Clock(rem))
      row:Show()
    else
      row.name = nil
      row:Hide()
    end
  end
  if count == 0 then win.empty:Show() else win.empty:Hide() end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

-- Background opacity of the window (like AdeAlts): only the background colour changes, never text or buttons.
function A.ApplyWindowAlpha()
  if not win or not win.built then return end
  local o = (A.DB and A.DB.alpha) or 1
  if UsePf() and win.backdrop and win.backdrop.GetBackdropColor then
    if not win.bgBase then
      local r, g, b, a = win.backdrop:GetBackdropColor()
      win.bgBase = { r or 0, g or 0, b or 0, a or 0.85 }        -- pfUI's own alpha counts as 100 %
    end
    win.backdrop:SetBackdropColor(win.bgBase[1], win.bgBase[2], win.bgBase[3], win.bgBase[4] * o)
  elseif not UsePf() then
    win:SetBackdropColor(1, 1, 1, o)
  end
end

function A.RefreshWindow()
  if not win or not win.built then return end
  local DB = A.DB
  A.loading = true
  win.cbEnable:SetChecked(DB.enabled)
  win.cbAuto:SetChecked(DB.auto)
  win.cbSeal:SetChecked(DB.seals)
  win.cbTimer:SetChecked(DB.useTimer)
  win.cbRemind:SetChecked(DB.remind)
  win.cbLock:SetChecked(DB.remindLock)
  win.cbMini:SetChecked(not DB.miniHide)
  if A.cls == "PALADIN" then win.cbSeal:Show(); win.seal:Show() else win.cbSeal:Hide(); win.seal:Hide() end
  win.s2:SetValue(DB.normalAt)
  win.s3:SetValue(DB.greaterAt)
  getglobal("AdeLazyBuffsSlider2Text"):SetText(A.TF("Single-target buffs: rebuff at %s sec left", DB.normalAt))
  getglobal("AdeLazyBuffsSlider3Text"):SetText(A.TF("Group buffs: rebuff at %s sec left", DB.greaterAt))
  win.s4:SetValue(DB.alpha or 1)
  getglobal("AdeLazyBuffsSlider4Text"):SetText(A.TF("Background opacity: %s%%", math.floor((DB.alpha or 1) * 100 + 0.5)))
  A.ApplyWindowAlpha()
  win.s1:SetValue(DB.remindSize or 14)
  getglobal("AdeLazyBuffsSlider1Text"):SetText(A.TF("Reminder text size: %s", DB.remindSize or 14))
  win.font:SetText(A.TF("Font: %s", A.FontName()))
  win.trig:SetText(A.TF("Trigger: %s", A.TriggerName()))
  if A.captureKey then
    win.key:SetText(A.T("Press a key..."))
  else
    win.key:SetText(A.TF("Key: %s", GetBindingKey("ADELAZYBUFFS_NOW") or A.T("none yet")))
  end
  win.lang:SetText(A.TF("Language: %s", LangName()))
  win.seal:SetText(A.TF("Seal: %s", DB.seal or A.T("none yet")))
  A.loading = false
  A.RefreshList()
end

local function MakeCheck(f, name, y, key, setter)
  local cb = CreateFrame("CheckButton", name, f, "OptionsCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", f, "TOPLEFT", 16, y)
  A.SetT(getglobal(name .. "Text"), key)
  cb:SetScript("OnClick", function()
    if this:GetChecked() then setter(true) else setter(false) end
  end)
  Skin("SkinCheckbox", cb)
  return cb
end

local function MakeSlider(f, name, y, minv, maxv, step, field)
  local s = CreateFrame("Slider", name, f, "OptionsSliderTemplate")
  s:SetPoint("TOPLEFT", f, "TOPLEFT", 24, y)
  s:SetWidth(330)
  s:SetMinMaxValues(minv, maxv)
  s:SetValueStep(step)
  getglobal(name .. "Low"):SetText(minv)
  getglobal(name .. "High"):SetText(maxv)
  s:SetScript("OnValueChanged", function()
    if A.loading then return end
    A.DB[field] = this:GetValue()
    A.RefreshWindow()
  end)
  Skin("SkinSlider", s)
  return s
end

local function MakeButton(f, text, w)
  local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  b:SetWidth(w)
  b:SetHeight(22)
  b:SetText(text)
  Skin("SkinButton", b)
  return b
end

local function Build()
  A.loading = true          -- creating the sliders must not overwrite the saved values
  local f = CreateFrame("Frame", "AdeLazyBuffsWindow", UIParent)
  win = f
  f:SetWidth(390)
  f:SetHeight(675)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

  if UsePf() then
    Try(pfUI.api.CreateBackdrop, f)
    Try(pfUI.api.CreateBackdropShadow, f)
  else
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
  end

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -16)
  title:SetText("AdeLazyBuffs " .. A.VERSION)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
  if UsePf() then Try(pfUI.api.SkinCloseButton, close, f, -8, -8) end

  f.cbEnable = MakeCheck(f, "AdeLazyBuffsCbEnable", -42, "Enable AdeLazyBuffs", function(v) A.DB.enabled = v end)
  f.cbAuto   = MakeCheck(f, "AdeLazyBuffsCbAuto",   -68, "Cast on my input (out of combat, not in rested areas)", function(v) A.DB.auto = v end)
  f.cbSeal   = MakeCheck(f, "AdeLazyBuffsCbSeal",   -94, "Keep my Seal up (also in combat)", function(v) A.DB.seals = v end)
  f.cbTimer  = MakeCheck(f, "AdeLazyBuffsCbTimer",  -120, "Rebuff by timer (off: only when the buff is gone)", function(v) A.DB.useTimer = v end)
  f.cbRemind = MakeCheck(f, "AdeLazyBuffsCbRemind", -146, "Show reminder window when a rebuff is due", function(v) A.DB.remind = v; A.RefreshReminder() end)
  f.cbLock   = MakeCheck(f, "AdeLazyBuffsCbLock",   -172, "Lock reminder window", function(v) A.DB.remindLock = v end)
  f.cbMini   = MakeCheck(f, "AdeLazyBuffsCbMini",   -198, "Show minimap button", function(v) A.DB.miniHide = not v; A.RefreshMinimap() end)

  f.s2 = MakeSlider(f, "AdeLazyBuffsSlider2", -246, 30, 480, 15, "normalAt")
  f.s3 = MakeSlider(f, "AdeLazyBuffsSlider3", -294, 60, 900, 30, "greaterAt")
  f.s1 = MakeSlider(f, "AdeLazyBuffsSlider1", -342, 8, 64, 1, "remindSize")
  f.s1:SetScript("OnValueChanged", function()
    if A.loading then return end
    A.DB.remindSize = math.floor(this:GetValue() + 0.5)
    A.RefreshReminder()
    A.RefreshWindow()
  end)

  f.s4 = MakeSlider(f, "AdeLazyBuffsSlider4", -390, 0.1, 1, 0.05, "alpha")
  getglobal("AdeLazyBuffsSlider4Low"):SetText("10%")
  getglobal("AdeLazyBuffsSlider4High"):SetText("100%")
  f.s4:SetScript("OnValueChanged", function()
    if A.loading then return end
    A.DB.alpha = math.floor(this:GetValue() * 20 + 0.5) / 20
    A.RefreshWindow()
  end)

  f.trig = MakeButton(f, "", 170)
  f.trig:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -426)
  f.trig:SetScript("OnClick", function()
    local m = A.DB.trigger
    if m == "any" or m == nil then A.DB.trigger = "wheel" elseif m == "wheel" then A.DB.trigger = "key" else A.DB.trigger = "any" end
    A.RefreshWindow()
  end)

  f.key = MakeButton(f, "", 170)
  f.key:SetPoint("LEFT", f.trig, "RIGHT", 14, 0)
  f.key:SetScript("OnClick", function()
    A.captureKey = true
    win:EnableKeyboard(true)
    A.RefreshWindow()
  end)
  f:SetScript("OnKeyDown", function()
    if not A.captureKey then return end
    local k = arg1
    if k == "LSHIFT" or k == "RSHIFT" or k == "LCTRL" or k == "RCTRL" or k == "LALT" or k == "RALT" then return end
    A.captureKey = false
    this:EnableKeyboard(false)
    if k ~= "ESCAPE" then
      local old = GetBindingKey("ADELAZYBUFFS_NOW")
      if old then SetBinding(old) end
      if IsAltKeyDown() then k = "ALT-" .. k end
      if IsControlKeyDown() then k = "CTRL-" .. k end
      if IsShiftKeyDown() then k = "SHIFT-" .. k end
      SetBinding(k, "ADELAZYBUFFS_NOW")
      if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
    end
    A.RefreshWindow()
  end)

  f.font = MakeButton(f, "", 170)
  f.font:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -456)
  f.font:SetScript("OnClick", function()
    local i = (A.DB.remindFont or 1) + 1
    if i > table.getn(A.FONTS) then i = 1 end
    A.DB.remindFont = i
    A.RefreshReminder()
    A.RefreshWindow()
  end)

  f.lang = MakeButton(f, "", 170)
  f.lang:SetPoint("LEFT", f.font, "RIGHT", 14, 0)
  f.lang:SetScript("OnClick", function()
    local l = A.DB.lang
    if l == nil then A.DB.lang = "en" elseif l == "en" then A.DB.lang = "ru" else A.DB.lang = nil end
    A.Relabel()
  end)

  f.seal = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.seal:SetPoint("TOPLEFT", f, "TOPLEFT", 190, -494)
  f.seal:SetWidth(180)
  f.seal:SetHeight(12)
  f.seal:SetJustifyH("LEFT")

  local hdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -492)
  A.SetT(hdr, "Remembered targets")

  f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -520)
  f.empty:SetWidth(320)
  f.empty:SetHeight(40)
  f.empty:SetJustifyH("LEFT")
  A.SetT(f.empty, "Nothing remembered yet. Cast a buff once and it is learned.")

  local scroll = CreateFrame("ScrollFrame", "AdeLazyBuffsScroll", f, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -514)
  scroll:SetWidth(320)
  scroll:SetHeight(ROWS * ROW_H)
  scroll:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(ROW_H, A.RefreshList)
  end)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function()
    local sb = getglobal("AdeLazyBuffsScrollScrollBar")
    if sb then sb:SetValue(sb:GetValue() - arg1 * ROW_H * 2) end
  end)
  f.scroll = scroll
  Skin("SkinScrollbar", getglobal("AdeLazyBuffsScrollScrollBar"))

  f.rows = {}
  local i
  for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, f)
    row:SetWidth(320)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -514 - (i - 1) * ROW_H)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.nameText:SetWidth(90)
    row.nameText:SetHeight(12)
    row.nameText:SetJustifyH("LEFT")

    row.spellText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.spellText:SetPoint("LEFT", row, "LEFT", 94, 0)
    row.spellText:SetWidth(150)
    row.spellText:SetHeight(12)
    row.spellText:SetJustifyH("LEFT")

    row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.timeText:SetPoint("LEFT", row, "LEFT", 248, 0)
    row.timeText:SetWidth(36)
    row.timeText:SetHeight(12)
    row.timeText:SetJustifyH("RIGHT")

    local del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    del:SetWidth(20)
    del:SetHeight(18)
    del:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    del:SetText("x")
    Skin("SkinButton", del)
    del:SetScript("OnClick", function()
      local r = this:GetParent()
      if r.name then
        A.Forget(r.name)
        A.RefreshList()
      end
    end)
    row.del = del
    f.rows[i] = row
  end

  local forget = MakeButton(f, "", 120)
  forget:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 18)
  A.SetT(forget, "Forget all")
  forget:SetScript("OnClick", function()
    A.Forget(nil)
    A.RefreshList()
  end)

  local done = MakeButton(f, "", 120)
  done:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 18)
  A.SetT(done, "Close")
  done:SetScript("OnClick", function() this:GetParent():Hide() end)

  -- the time column ticks once per second while the window is open
  local acc = 0
  f:SetScript("OnUpdate", function()
    acc = acc + arg1
    if acc >= 1 then
      acc = 0
      A.RefreshList()
    end
  end)
  f:SetScript("OnShow", function() A.RefreshWindow(); A.RefreshReminder() end)
  f:SetScript("OnHide", function() A.captureKey = false; this:EnableKeyboard(false); A.RefreshReminder() end)

  if UISpecialFrames then table.insert(UISpecialFrames, "AdeLazyBuffsWindow") end
  f.built = true
  A.loading = false
  f:Hide()
  return f
end

function A.ToggleWindow()
  if not A.DB then return end
  local f = win or Build()
  if f:IsVisible() then f:Hide() else f:Show() end
end
