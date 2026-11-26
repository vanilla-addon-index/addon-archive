--[[
OctoPad Menu  -  settings window + minimap button

Styled after ConsolePort: a dark flat window with a category sidebar, a controller
diagram for editing buttons, and LB / RB to switch categories.

Minimap button:  left-click = settings   right-click = show/hide HUD
                 shift-click = radial menu   drag = move around the minimap
Categories:      Overview / Bindings / Interface / World / HUD / System   (also: /opad)
]]

local OP = OctoPad

local menu, mm
local refreshers = {}
local uid = 0
local CATS = { "Overview", "Bindings", "Interface", "World", "HUD", "System", "Steam setup" }

local FLAT = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function UName(prefix)
  uid = uid + 1
  return "OctoPad" .. prefix .. uid
end

----------------------------------------------------------------------
-- Widgets (flat, dark, cyan accent)
----------------------------------------------------------------------
local function Label(parent, text, x, y, size, r, g, b, w)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(OP.Font(), size or 11)
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetJustifyH("LEFT")
  if w then fs:SetWidth(w) end
  fs:SetTextColor(r or 1, g or 1, b or 1)
  fs:SetText(text or "")
  return fs
end

local function Header(parent, text, x, y, w)
  local t = OP.Theme()
  local fs = Label(parent, string.upper(text), x, y, 10, t.ac[1], t.ac[2], t.ac[3], w or 430)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetTexture("Interface\\Buttons\\WHITE8X8")
  line:SetVertexColor(t.ac[1], t.ac[2], t.ac[3], .35)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 13)
  line:SetWidth(w or 430)
  return fs
end

local flats = {}

local function SetSel(b, on)
  local t = OP.Theme()
  local g = OP.BD(b)                    -- pfUI's rounded backdrop frame when pfUI is present
  b.sel = on
  if on then
    g:SetBackdropColor(t.fill[1] * .5 + t.ac[1] * .12, t.fill[2] * .5 + t.ac[2] * .12, t.fill[3] * .5 + t.ac[3] * .12, 1)
    g:SetBackdropBorderColor(t.ac[1], t.ac[2], t.ac[3], 1)
    if b.text then b.text:SetTextColor(t.ac[1], t.ac[2], t.ac[3]) end
  else
    g:SetBackdropColor(t.fill[1], t.fill[2], t.fill[3], 1)
    g:SetBackdropBorderColor(t.bd[1], t.bd[2], t.bd[3], 1)
    if b.text then b.text:SetTextColor(.9, .9, .9) end
  end
end

local function Flat(parent, text, x, y, w, h, fn, name)
  local b = CreateFrame("Button", name or UName("Btn"), parent)
  b:SetWidth(w)
  b:SetHeight(h or 22)
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  if not OP.Round(b, 1) then b:SetBackdrop(FLAT) end
  b.text = b:CreateFontString(nil, "OVERLAY")
  b.text:SetFont(OP.Font(), 11)
  b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.text:SetText(text or "")
  b.SetLabel = function(self, t) self.text:SetText(t) end
  SetSel(b, false)
  b:SetScript("OnEnter", function()
    local t = OP.Theme()
    OP.BD(this):SetBackdropBorderColor(t.ac[1], t.ac[2], t.ac[3], 1)
  end)
  b:SetScript("OnLeave", function() SetSel(this, this.sel) end)
  b:SetScript("OnClick", fn)
  table.insert(flats, b)
  return b
end

local function Check(parent, text, x, y, get, set)
  local name = UName("Check")
  local c = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
  c:SetWidth(24)
  c:SetHeight(24)
  c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  getglobal(name .. "Text"):SetText(text)
  c:SetScript("OnClick", function()
    set(this:GetChecked() and true or false)
    OP.NotifyChanged()
  end)
  table.insert(refreshers, function()
    if get() then c:SetChecked(1) else c:SetChecked(nil) end
  end)
  return c
end

local function StepList(list, current, dir)
  local n = table.getn(list)
  local idx, i = 1
  for i = 1, n do
    if list[i] == current then idx = i end
  end
  idx = idx + dir
  if idx < 1 then idx = n elseif idx > n then idx = 1 end
  return list[idx]
end

-- "label   [<]  value  [>]"
local function Cycle(parent, label, x, y, getText, step)
  Label(parent, label, x, y - 5, 11, .8, .8, .8, 130)
  Flat(parent, "<", x + 135, y, 22, 22, function() step(-1) end)
  local val = Label(parent, "", x + 160, y - 5, 11, OP.Theme().ac[1], OP.Theme().ac[2], OP.Theme().ac[3], 140)
  val:SetJustifyH("CENTER")
  Flat(parent, ">", x + 302, y, 22, 22, function() step(1) end)
  table.insert(refreshers, function() val:SetText(getText()) end)
  return val
end

local function Slider(parent, text, x, y, minv, maxv, stepv, get, set)
  local name = UName("Slider")
  local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
  s:SetWidth(200)
  s:SetHeight(16)
  s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  s:SetMinMaxValues(minv, maxv)
  s:SetValueStep(stepv)
  getglobal(name .. "Low"):SetText(tostring(minv))
  getglobal(name .. "High"):SetText(tostring(maxv))
  local txt = getglobal(name .. "Text")
  s:SetScript("OnValueChanged", function()
    if menu.refreshing then return end
    local v = math.floor(this:GetValue() * 10 + .5) / 10
    set(v)
    txt:SetText(text .. ": " .. v)
    if OP.HUDRefresh then OP.HUDRefresh() end
  end)
  table.insert(refreshers, function()
    menu.refreshing = true
    s:SetValue(get())
    txt:SetText(text .. ": " .. get())
    menu.refreshing = false
  end)
  return s
end

----------------------------------------------------------------------
-- Status
----------------------------------------------------------------------
local function YesNo(v, good)
  if v then
    if good == false then return "|cffff9900yes|r" end
    return "|cff00ff00yes|r"
  end
  if good == false then return "|cff00ff00no|r" end
  return "|cffaaaaaano|r"
end

local function UpdateStatus()
  if not menu or not menu.sBind then return end
  local cfg = OP.cfg
  local st, count = OP.BindingStatus()
  local txt
  if st == "ok" then
    txt = "|cff00ff00applied (40/40 keys)|r"
  elseif st == "none" then
    txt = "|cffff4040not applied|r - click Apply"
  else
    txt = "|cffffaa00partly overwritten (" .. count .. "/40)|r - click Apply / Repair"
  end
  menu.sBind:SetText("Key bindings: " .. txt)

  if OP.lastSlot then
    local what
    if type(OP.lastSlot) == "number" then
      what = OP.SlotName(OP.lastSlot) .. " (slot " .. OP.lastSlot .. ")"
    else
      what = tostring(OP.lastSlot)
    end
    menu.sInput:SetText("Last input: |cffffffff" .. what .. "|r  " .. string.format("%.1fs ago", GetTime() - OP.lastTime))
  else
    menu.sInput:SetText("Last input: |cffaaaaaanone yet|r")
  end

  menu.sDetect:SetText("pfUI: " .. YesNo(pfUI ~= nil) .. "   SuperWoW: " .. YesNo(SUPERWOW_VERSION ~= nil) ..
    "   Interact.dll: " .. YesNo(InteractNearest ~= nil) ..
    "   ConsoleExperienceClassic: " .. YesNo(OP.CEDetected(), false))

  local blocked, k, v = "", nil, nil
  for k, v in pairs(cfg.blocked) do blocked = blocked .. k .. " x" .. v .. "  " end
  if blocked == "" then
    menu.sBlocked:SetText("Client-blocked functions: |cff00ff00none|r")
  else
    menu.sBlocked:SetText("Client-blocked functions: |cffff9900" .. blocked .. "|r")
  end

  if menu.sPf then
    if OP.HUDPfMove and OP.HUDPfMove() then
      menu.sPf:SetText("|cff33ffccpfUI|r manages the position of both crosses: use |cffffff00/pfui|r > Unlock to move them. Positions are saved in your pfUI profile.")
    elseif pfUI then
      menu.sPf:SetText("pfUI found, but its movable-frame API is not available: use Edit layout and drag the blue handles.")
    else
      menu.sPf:SetText("pfUI not found: use Edit layout and drag the blue handles, or pick a preset.")
    end
  end

  if menu.foot then
    local st = OP.Style()
    menu.foot:SetText(st.bump[2] .. " / " .. st.bump[1] .. "  category        D-pad  move        " ..
      st.face[1] .. "  select        " .. st.face[4] .. "  close")
  end

  if menu.sDiag then
    local keys = cfg.stickkeys or {}
    menu.sDiag:SetText("OctoPad v" .. OP.VERSION ..
      "\nRadial stick keys (up / left / down / right): " .. tostring(keys[1]) .. " " .. tostring(keys[2]) .. " " ..
      tostring(keys[3]) .. " " .. tostring(keys[4]) ..
      "\nSuperWoW: " .. YesNo(SUPERWOW_VERSION ~= nil) .. "   pfUI: " .. YesNo(pfUI ~= nil))
  end
end

local function ApplyTheme()
  local t = OP.Theme()
  if not menu.opRounded then
    menu:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], t.bg[4])
    menu:SetBackdropBorderColor(t.bd[1], t.bd[2], t.bd[3], 1)
  end
  menu.sideTex:SetVertexColor(t.side[1], t.side[2], t.side[3], 1)
  local i
  for i = 1, table.getn(flats) do SetSel(flats[i], flats[i].sel) end
end

function OP.MenuRefresh()
  if not menu or not menu:IsShown() then return end
  ApplyTheme()
  local i
  for i = 1, table.getn(refreshers) do refreshers[i]() end
  UpdateStatus()
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function ShowTab(i)
  local k
  if OctoPadActionPicker and OctoPadActionPicker:IsShown() then OctoPadActionPicker:Hide() end
  for k = 1, table.getn(CATS) do
    local b = menu.tabBtns[k]
    if k == i then
      menu.pages[k]:Show()
      SetSel(b, true)
      b:Disable()
    else
      menu.pages[k]:Hide()
      SetSel(b, false)
      b:Enable()
    end
  end
  menu.tab = i
end

local function GameValue(n)
  local cfg = OP.cfg
  local v = cfg.slots[n]
  if v == "none" then return "none" end
  if v then
    local a = OP.ACTIONS[v]
    return (a and a.short or v)
  end
  local d = OP.PROFILES[cfg.profile][n]
  if d and OP.ACTIONS[d] then return OP.ACTIONS[d].short .. " (default)" end
  return "Action bar"
end

local function WindowValue(n)
  local cfg = OP.cfg
  local v = cfg.ui[n]
  if v == "none" then return "none" end
  if v then return OP.UI_ROLE_NAMES[v] or v end
  local d = OP.UI_DEFAULT[n]
  if d then return OP.UI_ROLE_NAMES[d] .. " (default)" end
  return "none"
end

local function Selected()
  local cfg = OP.cfg
  local i = OP.editSel
  if not i then return nil end
  cfg.btn[i] = cfg.btn[i] or {}
  return cfg.btn[i], i
end

local function Nudge(dx, dy)
  local c = Selected()
  if not c then return end
  c.dx = (c.dx or 0) + dx
  c.dy = (c.dy or 0) + dy
  OP.NotifyChanged()
end

local function CurSlot()
  return (menu.bar - 1) * 10 + menu.sel
end

----------------------------------------------------------------------
-- Action picker (like Steam Input's "choose a binding"): click a button on the diagram, then pick what it does
-- from a grid of icons, grouped by category.  Used for both the Game action and the Window action.
----------------------------------------------------------------------
-- Keycap theme chooser: shows the window control's keycap in each theme; the pick applies to every window control
local kcPicker
local WindowInfo
local KC_CHOICES = { { "chevron", "Chevron" }, { "retro", "Retro keyboard" }, { "pfui", "pfUI colours" } }
function OP.OpenKeycapPicker(anchor)
  if not kcPicker then
    kcPicker = CreateFrame("Frame", "OctoPadKeycapPicker", menu)
    kcPicker:SetWidth(330)
    kcPicker:SetHeight(120)
    kcPicker:SetFrameLevel(menu:GetFrameLevel() + 30)
    kcPicker:EnableMouse(true)
    if not OP.Round(kcPicker, 1) then kcPicker:SetBackdrop(FLAT) end
    kcPicker.title = Label(kcPicker, "Window control icons", 12, -10, 11, 1, 1, 1, 220)
    kcPicker.opts = {}
    local i
    for i = 1, 3 do
      local key = KC_CHOICES[i][1]
      local b = Flat(kcPicker, "", 12 + (i - 1) * 104, -34, 98, 74, function()
        OP.cfg.keycaps = this.key
        kcPicker:Hide()
        OP.NotifyChanged()
      end)
      b.key = key
      b.ic = b:CreateTexture(nil, "ARTWORK")
      b.ic:SetWidth(36)
      b.ic:SetHeight(36)
      b.ic:SetPoint("TOP", b, "TOP", 0, -6)
      b.legend = b:CreateTexture(nil, "OVERLAY")
      b.legend:SetAllPoints(b.ic)
      b.text:ClearAllPoints()
      b.text:SetPoint("BOTTOM", b, "BOTTOM", 0, 6)
      b.text:SetText(KC_CHOICES[i][2])
      kcPicker.opts[i] = b
    end
    Flat(kcPicker, "Cancel", 258, -6, 62, 20, function() kcPicker:Hide() end)
  end
  local role = "UI_CONFIRM"
  local wr = WindowInfo and WindowInfo(OP.cfg and CurSlot and CurSlot() or 1)
  if wr then role = wr end
  local cur = OP.KeycapStyle()
  local i
  for i = 1, 3 do
    local b = kcPicker.opts[i]
    OP.PaintKeycap(b.ic, b.legend, role, b.key)
    SetSel(b, b.key == cur)
  end
  kcPicker:ClearAllPoints()
  kcPicker:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
  kcPicker:Show()
end

local ROLE_KEY = {
  UI_CONFIRM = "key_confirm", UI_ALT = "key_alt", UI_SHIFT = "key_shift", UI_BACK = "key_back",
  UI_UP = "key_up", UI_DOWN = "key_down", UI_LEFT = "key_left", UI_RIGHT = "key_right",
  UI_TAB_NEXT = "key_tabnext", UI_TAB_PREV = "key_tabprev", UI_SCROLL_UP = "key_scrollup",
  UI_SCROLL_DOWN = "key_scrolldown", UI_DESTROY = "key_destroy",
}
local ROLE_DIR = "Interface\\AddOns\\OctoPad\\Glyphs\\"
local PICK_TABS = {
  { "Move",   { "JUMP", "INTERACT", "AUTORUN", "SITSTAND", "ZOOM_IN", "ZOOM_OUT" } },
  { "Target", { "TARGET_ENEMY", "TARGET_ENEMY_PREV", "TARGET_FRIEND", "TARGET_FRIEND_PREV", "ASSIST", "TARGET_PET",
                "CLEAR_TARGET", "CYCLE_PARTY" } },
  { "Combat", { "ATTACK", "STOP_ATTACK", "PET_ATTACK", "INSPECT" } },
  { "Menus",  { "MAP", "BAGS", "CHARACTER", "SPELLBOOK", "TALENTS", "QUESTS", "SOCIAL", "CHAT", "GAMEMENU",
                "OCTOPAD", "RADIAL", "BACK" } },
}
local picker

local function PickerTable()
  if picker.kind == "game" then return OP.cfg.slots end
  return OP.cfg.ui
end

local function PickerAssign(key)
  local tbl = PickerTable()
  if key == "default" then tbl[picker.slot] = nil else tbl[picker.slot] = key end
  picker:Hide()
  OP.NotifyChanged()
end

local function PickerShow()
  local cur = PickerTable()[picker.slot]
  if cur == nil then cur = "default" end
  local k, b
  for k, b in pairs(picker.items) do
    local on = (b.kind == picker.kind)
    if on and picker.kind == "game" and b.tab ~= picker.tab and b.key ~= "default" and b.key ~= "none" then on = false end
    if on and (b.key == "default" or b.key == "none") then on = false end
    if on then b:Show() else b:Hide() end
    if b.kind == "ui" and on then OP.PaintKeycap(b.ic, b.legend, b.key) end
    SetSel(b, b.key == cur)
  end
  -- grid placement of the visible items
  local col, row = 0, 0
  for k = 1, table.getn(picker.order) do
    local b = picker.order[k]
    if b:IsShown() and b.kind == picker.kind then
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", picker, "TOPLEFT", 12 + col * 108, -84 - row * 36)
      col = col + 1
      if col >= 4 then col = 0 row = row + 1 end
    end
  end
  SetSel(picker.defBtn, cur == "default")
  SetSel(picker.noneBtn, cur == "none")
  local i
  for i = 1, table.getn(picker.tabBtns) do
    if picker.kind == "game" then
      picker.tabBtns[i]:Show()
      picker.tabBtns[i]:SetOn(i == picker.tab)
    else
      picker.tabBtns[i]:Hide()
    end
  end
  local th = OP.Theme()
  picker.rule:SetVertexColor(th.bd[1], th.bd[2], th.bd[3], .8)
  if picker.kind == "game" then picker.rule:Show() else picker.rule:Hide() end
end

local function BuildPicker()
  if picker then return end
  picker = CreateFrame("Frame", "OctoPadActionPicker", menu)
  picker:SetPoint("TOPLEFT", menu, "TOPLEFT", 140, -48)
  picker:SetWidth(460)
  picker:SetHeight(390)
  picker:SetFrameLevel(menu:GetFrameLevel() + 20)
  picker:EnableMouse(true)
  if not OP.Round(picker, 1) then picker:SetBackdrop(FLAT) end
  picker:Hide()
  picker.items, picker.order, picker.tabBtns = {}, {}, {}
  picker.kind, picker.slot, picker.tab = "game", 1, 1

  picker.title = Label(picker, "", 12, -12, 12, 1, 1, 1, 300)
  picker.hint = Label(picker, "Click an action to assign it. It replaces what the button did before.", 12, -30, 9, .55, .55, .55, 430)
  Flat(picker, "x", 430, -8, 22, 22, function() picker:Hide() end)
  picker.iconBtn = Flat(picker, "Change icon...", 316, -8, 108, 22, function()
    local n = picker.slot
    picker:Hide()
    OP.OpenIconPicker(n)
  end)

  -- tabs: plain text with an underline on the active one (not buttons)
  local rule = picker:CreateTexture(nil, "ARTWORK")
  rule:SetTexture("Interface\\Buttons\\WHITE8X8")
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", picker, "TOPLEFT", 12, -76)
  rule:SetWidth(436)
  picker.rule = rule
  local t
  for t = 1, table.getn(PICK_TABS) do
    local idx = t
    local tb = CreateFrame("Button", UName("PickTab"), picker)
    tb:SetWidth(64)
    tb:SetHeight(24)
    tb:SetPoint("TOPLEFT", picker, "TOPLEFT", 12 + (t - 1) * 68, -52)
    tb.text = tb:CreateFontString(nil, "OVERLAY")
    tb.text:SetFont(OP.Font(), 12)
    tb.text:SetPoint("CENTER", tb, "CENTER", 0, 0)
    tb.text:SetText(PICK_TABS[t][1])
    tb.line = tb:CreateTexture(nil, "OVERLAY")
    tb.line:SetTexture("Interface\\Buttons\\WHITE8X8")
    tb.line:SetHeight(2)
    tb.line:SetPoint("BOTTOMLEFT", tb, "BOTTOMLEFT", 4, -1)
    tb.line:SetPoint("BOTTOMRIGHT", tb, "BOTTOMRIGHT", -4, -1)
    tb.SetOn = function(self, on)
      local th = OP.Theme()
      self.on = on
      if on then
        self.text:SetTextColor(th.ac[1], th.ac[2], th.ac[3])
        self.line:SetVertexColor(th.ac[1], th.ac[2], th.ac[3], 1)
        self.line:Show()
      else
        self.text:SetTextColor(.7, .7, .7)
        self.line:Hide()
      end
    end
    tb:SetScript("OnEnter", function() if not this.on then this.text:SetTextColor(1, 1, 1) end end)
    tb:SetScript("OnLeave", function() this:SetOn(this.on) end)
    tb:SetScript("OnClick", function()
      picker.tab = idx
      PickerShow()
    end)
    picker.tabBtns[t] = tb
  end
  picker.cancelBtn = Flat(picker, "Cancel", 0, 0, 72, 24, function() picker:Hide() end)
  picker.cancelBtn:ClearAllPoints()
  picker.cancelBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -12, 12)
  picker.noneBtn = Flat(picker, "None", 0, 0, 72, 24, function() PickerAssign("none") end)
  picker.noneBtn:ClearAllPoints()
  picker.noneBtn:SetPoint("RIGHT", picker.cancelBtn, "LEFT", -6, 0)
  picker.defBtn = Flat(picker, "Default", 0, 0, 72, 24, function() PickerAssign("default") end)
  picker.defBtn:ClearAllPoints()
  picker.defBtn:SetPoint("RIGHT", picker.noneBtn, "LEFT", -6, 0)

  local function Item(kind, key, label, tex, tab)
    local b = Flat(picker, "", 0, 0, 104, 30, function() PickerAssign(this.key) end)
    b.kind, b.key, b.tab = kind, key, tab
    b.ic = b:CreateTexture(nil, "ARTWORK")
    b.ic:SetWidth(24)
    b.ic:SetHeight(24)
    b.ic:SetPoint("LEFT", b, "LEFT", 4, 0)
    if tex then b.ic:SetTexture(tex) end
    if kind == "ui" then
      b.legend = b:CreateTexture(nil, "OVERLAY")
      b.legend:SetAllPoints(b.ic)
      b.legend:Hide()
    end
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", b, "LEFT", 32, 0)
    b.text:SetWidth(68)
    b.text:SetJustifyH("LEFT")
    b.text:SetText(label)
    b:Hide()
    picker.items[kind .. key] = b
    table.insert(picker.order, b)
  end
  local seen = {}
  for t = 1, table.getn(PICK_TABS) do
    local list = PICK_TABS[t][2]
    local i
    for i = 1, table.getn(list) do
      local id = list[i]
      if OP.ACTIONS[id] then
        seen[id] = true
        Item("game", id, OP.ACTIONS[id].short, OP.IconFor(nil, id), t)
      end
    end
  end
  local a
  for a = 1, table.getn(OP.ACTION_ORDER) do          -- anything not listed above goes to the last tab
    local id = OP.ACTION_ORDER[a]
    if not seen[id] then Item("game", id, OP.ACTIONS[id].short, OP.IconFor(nil, id), table.getn(PICK_TABS)) end
  end
  for a = 1, table.getn(OP.UI_ROLES) do
    local r = OP.UI_ROLES[a]
    Item("ui", r, OP.UI_ROLE_NAMES[r] or r, nil, 1)
  end

  picker:SetScript("OnShow", function()
    if menu.pages[menu.tab] then menu.pages[menu.tab]:Hide() end
  end)
  picker:SetScript("OnHide", function()
    if menu.pages[menu.tab] then menu.pages[menu.tab]:Show() end
  end)
end

-- kind: "game" or "ui";  n: slot 1..40
function OP.OpenActionPicker(kind, n)
  BuildPicker()
  picker.kind, picker.slot = kind, n
  if kind == "game" then
    picker.tab = 1
    local cur = OP.cfg.slots[n] or (OP.PROFILES[OP.cfg.profile] or {})[n]
    local t
    for t = 1, table.getn(PICK_TABS) do
      local list = PICK_TABS[t][2]
      local i
      for i = 1, table.getn(list) do
        if list[i] == cur then picker.tab = t end
      end
    end
  end
  picker.title:SetText((kind == "game" and "Game action" or "Window action") .. "  for  |cffffffff" .. OP.SlotName(n) ..
    "|r  |cff777777(slot " .. n .. ")|r")
  picker.hint:SetText(kind == "game"
    and "Used while playing. 'Default' follows your profile; 'None' leaves the button unused (it casts the ability on the action bar instead where one exists)."
    or "Used while a window (bags, quests, vendor ...) is open and a focus ring is shown.")
  PickerShow()
  local proxy = OP.ProxyFor(n)
  if kind == "game" and proxy and OP.ACTIONS[proxy] then picker.iconBtn:Show() else picker.iconBtn:Hide() end
  picker:Show()
end

----------------------------------------------------------------------
-- Pages
----------------------------------------------------------------------
local function BuildOverview(g)
  local cfg = OP.cfg
  Header(g, "Status", 0, 0)
  menu.sBind = Label(g, "", 0, -22, 11, 1, 1, 1, 430)
  menu.sInput = Label(g, "", 0, -38, 10, 1, 1, 1, 430)
  menu.sDetect = Label(g, "", 0, -54, 10, 1, 1, 1, 430)
  menu.sBlocked = Label(g, "", 0, -70, 10, 1, 1, 1, 430)

  Header(g, "Controller", 0, -98)
  Cycle(g, "Controller", 0, -118,
    function() return OP.STYLES[cfg.style].short end,
    function(d) cfg.style = StepList(OP.STYLE_ORDER, cfg.style, d); OP.NotifyChanged() end)
  Cycle(g, "Profile", 0, -146,
    function() return OP.PROFILE_NAMES[cfg.profile] end,
    function(d) cfg.profile = StepList(OP.PROFILE_ORDER, cfg.profile, d); OP.NotifyChanged() end)

  Header(g, "Key bindings", 0, -184)
  Flat(g, "Apply / Repair", 0, -204, 130, 22, function()
    if OP.CEDetected() then
      OP.Print("ConsoleExperienceClassic is loaded and owns keys 1-0. Disable it first (or type /opad bind force).")
    else
      OP.BindAll()
      OP.Print("Controller keys applied.")
    end
    OP.NotifyChanged()
  end)
  Flat(g, "Remove", 140, -204, 100, 22, function()
    OP.UnbindAll()
    OP.Print("OctoPad keys removed; previous bindings restored where known.")
    OP.NotifyChanged()
  end)
  Check(g, "Auto-repair bindings at login", 0, -234,
    function() return cfg.enforce end, function(v) cfg.enforce = v end)
  Check(g, "Secure mode: Jump / Run / targeting use Blizzard's own keys", 0, -258,
    function() return cfg.native end, function(v) cfg.native = v end)
  Label(g, "Keys 1-0 carry the buttons, Shift / Ctrl are the triggers, Shift+Escape opens the radial. Set this up in Steam Input (see the README).", 0, -296, 9, .6, .6, .6, 430)
end

local function GameInfo(n)
  local cfg = OP.cfg
  local v = cfg.slots[n]
  if v == "none" then return "Interface\\Icons\\INV_Misc_QuestionMark", "None", true end
  local id, def = v, false
  if not id then
    id = (OP.PROFILES[cfg.profile] or {})[n]
    def = true
  end
  if id and OP.ACTIONS[id] then
    return OP.IconFor(n, id), OP.ACTIONS[id].short .. (def and "  |cff777777(default)|r" or ""), false
  end
  local as = OP.ActualSlot(n)
  local tex = GetActionTexture and type(as) == "number" and GetActionTexture(as)
  return tex or "Interface\\Icons\\INV_Misc_QuestionMark", "Action bar  |cff777777(ability)|r", not tex
end

function WindowInfo(n)
  local cfg = OP.cfg
  local v = cfg.ui[n]
  if v == "none" then return nil, "None" end
  local def = false
  if not v then v = OP.UI_DEFAULT[n] def = true end
  if v and OP.UI_ROLE_NAMES[v] then
    return v, OP.UI_ROLE_NAMES[v] .. (def and "  |cff777777(default)|r" or "")
  end
  return nil, "None"
end

local function BuildBindings(s)
  local cfg = OP.cfg
  menu.bar = 1
  menu.sel = 1
  menu.cells = {}

  -- "Hold": None | LT | LT + RT | RT.  Layers: 1 none, 2 LT, 3 RT, 4 LT+RT
  Label(s, "Hold", 0, -5, 11, .8, .8, .8, 40)
  menu.layerBtns = {}
  local LAYER_AT = { [1] = 50, [2] = 148, [4] = 246, [3] = 344 }
  local b
  for b = 2, 4 do
    local idx = b
    local lb = Flat(s, "", LAYER_AT[b], 0, 92, 22, function()
      menu.bar = idx
      OP.MenuRefresh()
    end)
    lb.g1 = lb:CreateTexture(nil, "OVERLAY")
    lb.g1:SetHeight(16)
    lb.g1:SetWidth(27)
    lb.g1:SetTexCoord(0, 1, .18, .82)
    lb.g2 = lb:CreateTexture(nil, "OVERLAY")
    lb.g2:SetHeight(16)
    lb.g2:SetWidth(27)
    lb.g2:SetTexCoord(0, 1, .18, .82)
    menu.layerBtns[b] = lb
  end
  menu.layerBtns[1] = Flat(s, "None", LAYER_AT[1], 0, 92, 22, function()
    menu.bar = 1
    OP.MenuRefresh()
  end)
  table.insert(refreshers, function()
    local k
    for k = 1, 4 do
      local lb = menu.layerBtns[k]
      SetSel(lb, k == menu.bar)
      if k > 1 then
        lb.g1:Hide()
        lb.g2:Hide()
        if k == 2 or k == 3 then
          lb.g1:ClearAllPoints()
          lb.g1:SetPoint("CENTER", lb, "CENTER", 0, 0)
          lb.g1:SetTexture(OP.GlyphTrig(k - 1))
          lb.g1:Show()
        else
          lb.g1:ClearAllPoints()
          lb.g1:SetPoint("CENTER", lb, "CENTER", -17, 0)
          lb.g1:SetTexture(OP.GlyphTrig(1))
          lb.g1:Show()
          lb.g2:ClearAllPoints()
          lb.g2:SetPoint("CENTER", lb, "CENTER", 17, 0)
          lb.g2:SetTexture(OP.GlyphTrig(2))
          lb.g2:Show()
          if not lb.plus then
            lb.plus = lb:CreateFontString(nil, "OVERLAY")
            lb.plus:SetFont(OP.Font(), 12)
            lb.plus:SetPoint("CENTER", lb, "CENTER", 0, 0)
            lb.plus:SetText("+")
          end
        end
      end
    end
  end)

  -- controller diagram: d-pad cross (LB in the middle) and face-button cross (RB in the middle),
  -- the same shape as the HUD. Face buttons follow the selected controller style.
  local function Cell(idx)
    local c = Flat(s, "", 0, 0, 40, 40, function()
      local again = (menu.sel == idx)
      menu.sel = idx
      OP.MenuRefresh()
      if again then OP.OpenActionPicker("game", CurSlot()) end     -- click a selected button again to choose its action
    end)
    c.tex = c:CreateTexture(nil, "ARTWORK")
    c.tex:SetPoint("TOPLEFT", c, "TOPLEFT", 3, -3)
    c.tex:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -3, 3)
    c.tex:SetTexCoord(.07, .93, .07, .93)
    c.glyph = c:CreateTexture(nil, "OVERLAY")
    c.glyph:SetWidth(16)
    c.glyph:SetHeight(16)
    c.glyph:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 3, -3)
    c.name = c:CreateFontString(nil, "OVERLAY")
    c.name:SetFont(OP.Font(), 8, "OUTLINE")
    c.name:SetPoint("BOTTOM", c, "BOTTOM", 0, 3)
    c.name:SetWidth(46)
    menu.cells[idx] = c
  end
  local k
  for k = 1, 10 do Cell(k) end

  menu.sStyle = Label(s, "", 175, -84, 11, 1, 1, 1, 110)
  menu.sStyle:SetJustifyH("CENTER")

  local DPX, DPY, FCX, FCY = 70, -84, 330, -84
  local function Put(idx, x, y)
    local c = menu.cells[idx]
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", s, "TOPLEFT", x, y)
  end
  local function Layout()
    -- d-pad: 7 up, 6 left, 8 right, 5 down, 10 (LB) centre
    Put(7, DPX, DPY + 44)
    Put(6, DPX - 44, DPY)
    Put(8, DPX + 44, DPY)
    Put(5, DPX, DPY - 44)
    Put(10, DPX, DPY)
    -- face buttons: Xbox-style positions, or Nintendo positions for the Nintendo layout
    if OP.Style().pos == "nintendo" then
      Put(2, FCX, FCY + 44)        -- top
      Put(3, FCX - 44, FCY)        -- left
      Put(1, FCX + 44, FCY)        -- right
      Put(4, FCX, FCY - 44)        -- bottom
    else
      Put(3, FCX, FCY + 44)        -- top
      Put(2, FCX - 44, FCY)        -- left
      Put(4, FCX + 44, FCY)        -- right
      Put(1, FCX, FCY - 44)        -- bottom
    end
    Put(9, FCX, FCY)               -- RB centre
  end
  Layout()

  -- editor: the selected button and what it does, each with a "Change..." button that opens the picker
  Header(s, "Selected button", 0, -186)
  menu.sSel = Label(s, "", 120, -186, 12, 1, 1, 1, 300)

  -- each row: a button with the action's name (click: pick another action) and its icon to the right
  -- (click: change the icon; for window actions: choose the window icon style)
  local function Row(label, y, kind)
    Label(s, label, 0, y - 12, 11, .8, .8, .8, 90)
    local box = Flat(s, "", 92, y - 6, 210, 28, function() OP.OpenActionPicker(kind, CurSlot()) end)
    box.text:ClearAllPoints()
    box.text:SetPoint("LEFT", box, "LEFT", 10, 0)
    box.text:SetWidth(150)
    box.text:SetJustifyH("LEFT")
    box.arrow = box:CreateFontString(nil, "OVERLAY")
    box.arrow:SetFont(OP.Font(), 9)
    box.arrow:SetPoint("RIGHT", box, "RIGHT", -8, 0)
    box.arrow:SetTextColor(.6, .6, .6)
    box.arrow:SetText("change")
    box.txt = box.text

    local ibtn = CreateFrame("Button", UName("RowIcon"), s)
    ibtn:SetWidth(40)
    ibtn:SetHeight(40)
    ibtn:SetPoint("TOPLEFT", s, "TOPLEFT", 310, y)
    if not OP.Round(ibtn, .6) then
      ibtn:SetBackdrop(FLAT)
      ibtn:SetBackdropColor(0, 0, 0, .6)
      ibtn:SetBackdropBorderColor(.25, .27, .3, 1)
    end
    ibtn.ic = ibtn:CreateTexture(nil, "ARTWORK")
    ibtn.ic:SetPoint("TOPLEFT", ibtn, "TOPLEFT", 3, -3)
    ibtn.ic:SetPoint("BOTTOMRIGHT", ibtn, "BOTTOMRIGHT", -3, 3)
    ibtn.legend = ibtn:CreateTexture(nil, "OVERLAY")
    ibtn.legend:SetAllPoints(ibtn.ic)
    ibtn.legend:Hide()
    ibtn:SetScript("OnClick", function()
      if kind == "game" then OP.OpenIconPicker(CurSlot()) else OP.OpenKeycapPicker(ibtn) end
    end)
    ibtn:SetScript("OnEnter", function()
      local t = OP.Theme()
      OP.BD(this):SetBackdropBorderColor(t.ac[1], t.ac[2], t.ac[3], 1)
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText(kind == "game" and "Click to change this action's icon" or "Click to choose the window icon style")
      GameTooltip:Show()
    end)
    ibtn:SetScript("OnLeave", function()
      local t = OP.Theme()
      OP.BD(this):SetBackdropBorderColor(t.bd[1], t.bd[2], t.bd[3], 1)
      GameTooltip:Hide()
    end)
    box.ic, box.legend = ibtn.ic, ibtn.legend
    return box
  end
  menu.rowGame = Row("Game action", -208, "game")
  menu.rowWin = Row("Window action", -256, "ui")

  -- per-button smart target override
  local SMART_OVER = { "auto", "asis", "self", "soft" }
  local SMART_OVER_NAMES = { auto = "Automatic", asis = "As is (no redirect)", self = "Always on me", soft = "Soft target" }
  Cycle(s, "Smart target", 0, -302, function()
    return SMART_OVER_NAMES[cfg.smartover[CurSlot()] or "auto"]
  end, function(d)
    local n = CurSlot()
    local v = StepList(SMART_OVER, cfg.smartover[n] or "auto", d)
    if v == "auto" then v = nil end
    cfg.smartover[n] = v
    OP.MenuRefresh()
  end)
  Label(s, "Click a button on the diagram, then its Game action (while playing) or Window action (while a window is open) to pick from a list. Smart target: how this button picks its target.", 0, -330, 9, .55, .55, .55, 430)

  table.insert(refreshers, function()
    Layout()
    local st = OP.Style()
    menu.sStyle:SetText(st.short .. "\n|cff888888" .. (OP.PROFILE_NAMES[cfg.profile] or "") .. "|r")
    local n = CurSlot()
    menu.sSel:SetText(OP.SlotName(n) .. "   |cff777777(slot " .. n .. ")|r")
    local gtex, gtxt, gdim = GameInfo(n)
    menu.rowGame.ic:SetTexCoord(.07, .93, .07, .93)
    menu.rowGame.ic:SetTexture(gtex)
    menu.rowGame.ic:SetVertexColor(gdim and .4 or 1, gdim and .4 or 1, gdim and .4 or 1)
    menu.rowGame.txt:SetText(gtxt)
    local wrole, wtxt = WindowInfo(n)
    if wrole then
      OP.PaintKeycap(menu.rowWin.ic, menu.rowWin.legend, wrole)
      menu.rowWin.ic:Show()
    else
      menu.rowWin.ic:Hide()
      menu.rowWin.legend:Hide()
    end
    menu.rowWin.txt:SetText(wtxt)
    local k
    for k = 1, 10 do
      local c = menu.cells[k]
      local slotn = (menu.bar - 1) * 10 + k
      SetSel(c, k == menu.sel)
      c.glyph:SetTexture(OP.GlyphFor(k))
      if k == 9 or k == 10 then
        c.glyph:SetWidth(26)
        c.glyph:SetHeight(16)
        c.glyph:SetTexCoord(0, 1, .18, .82)
      else
        c.glyph:SetWidth(16)
        c.glyph:SetHeight(16)
        c.glyph:SetTexCoord(0, 1, 0, 1)
      end
      local proxy = OP.ProxyFor(slotn)
      local tex
      c.name:SetText((proxy and OP.ACTIONS[proxy]) and OP.ACTIONS[proxy].short or "")
      if proxy and OP.ACTIONS[proxy] then
        tex = OP.IconFor(slotn, proxy)
      else
        local as = OP.ActualSlot(slotn)
        if GetActionTexture and type(as) == "number" then tex = GetActionTexture(as) end
      end
      if tex then
        c.tex:SetTexture(tex)
        c.tex:SetVertexColor(1, 1, 1)
      else
        c.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        c.tex:SetVertexColor(.35, .35, .35)
      end
    end
  end)
end

-- Stack: lays a page out top to bottom, so adding or moving an option never means re-numbering y offsets.
--   local L = Stack(page)
--   L:Header("Title")  L:Check("Text", get, set)  L:Pair({ "A", getA, setA }, { "B", getB, setB })
--   L:Label("Help text", lines)  L:Button("Do it", width, fn)  L:Slider("Size", min, max, step, get, set)  L:Gap(8)
local function Stack(parent)
  local L = { y = 0 }
  function L:Gap(n) self.y = self.y - (n or 8) end
  function L:Header(text)
    Header(parent, text, 0, self.y)
    self.y = self.y - 20
  end
  function L:Check(text, get, set)
    local c = Check(parent, text, 0, self.y, get, set)
    self.y = self.y - 24
    return c
  end
  function L:Pair(a, b)
    Check(parent, a[1], 0, self.y, a[2], a[3])
    if b then Check(parent, b[1], 215, self.y, b[2], b[3]) end
    self.y = self.y - 24
  end
  function L:Label(text, lines, size)
    local fs = Label(parent, text, 0, self.y - 2, size or 9, .55, .55, .55, 430)
    self.y = self.y - (lines or 1) * 12 - 8
    return fs
  end
  function L:Button(text, w, fn)
    local b = Flat(parent, text, 0, self.y, w or 140, 22, fn)
    self.y = self.y - 30
    return b
  end
  function L:Slider(text, minv, maxv, stepv, get, set)
    local s = Slider(parent, text, 4, self.y - 14, minv, maxv, stepv, get, set)
    self.y = self.y - 40
    return s
  end
  return L
end

local function BuildInterface(p)
  local cfg = OP.cfg
  local L = Stack(p)
  L:Header("Window navigation")
  L:Check("Buttons control open windows (bags, map, quests, menus ...)",
    function() return cfg.uimode end, function(v) cfg.uimode = v end)
  L:Check("Smart default focus (Accept / Complete Quest / Continue ...)",
    function() return cfg.smartfocus end, function(v) cfg.smartfocus = v end)
  L:Check("Button hint bar while a window is open",
    function() return cfg.hints end, function(v) cfg.hints = v end)
  L:Gap(14)

  L:Header("Windows")
  Flat(p, "Add window under mouse (3s)", 0, L.y, 200, 22, function()
    menu:Hide()
    OP.CaptureWindowIn(3)
  end)
  Flat(p, "List recognised windows", 210, L.y, 200, 22, function() OP.ListWindows() end)
  L:Gap(32)
  L:Label("Bag or inventory addon not responding? Click 'Add window under mouse', then hover the open window. Default bags, pfUI and Bagshui are detected automatically.", 2)
  L:Gap(6)

  L:Header("While a window is open")
  Label(p, "Up / Down / Left / Right move the focus ring    Confirm = click    Right-click and Shift-click have their own buttons\nLB / RB switch tabs    Back closes the window", 0, L.y, 10, .75, .75, .75, 430)
end

local function BuildWorld(w)
  local cfg = OP.cfg
  local L = Stack(w)
  L:Header("Soft target")
  L:Check("Slowly pulsing name colour (red / yellow / green) + tooltip for the unit nearest the centre",
    function() return cfg.soft end, function(v) cfg.soft = v end)
  L:Label("The unit nearest the middle of the screen gets a slowly pulsing name colour: red (hostile), yellow (neutral) or green (friendly) and shows the game's mouseover tooltip, with your quest kill counts (for example 'Boar slain: 3/10'). Needs nameplates: V = enemies, Ctrl+V = friendly, or pfUI nameplates. Items and objects cannot be detected.", 4)

  L:Header("Smart target")
  L:Check("Smart target (master switch)",
    function() return cfg.smarttarget end, function(v) cfg.smarttarget = v end)
  L:Pair({ "Spells (damage, debuffs)", function() return cfg.smartcat.spells end, function(v) cfg.smartcat.spells = v end },
         { "Buffs and heals", function() return cfg.smartcat.buffs end, function(v) cfg.smartcat.buffs = v end })
  L:Pair({ "Attacks and weapons", function() return cfg.smartcat.attacks end, function(v) cfg.smartcat.attacks = v end },
         { "Pet actions", function() return cfg.smartcat.pets end, function(v) cfg.smartcat.pets = v end })
  L:Check("Items and all other actions",
    function() return cfg.smartcat.other end, function(v) cfg.smartcat.other = v end)
  L:Label("Buttons act on the soft target / mouseover unit. Heals and buffs fall back to you. Attacks and items may change your real target. Redirected casts need SuperWoW. Per button: Bindings > Smart target.", 2)
  L:Gap(6)

  L:Header("Radial menu")
  L:Check("Select radial entries with the left thumb stick",
    function() return cfg.stickradial end, function(v) cfg.stickradial = v end)
  L:Check("LB+RB chord layer (Steam sends ALT-1 .. ALT-8)",
    function() return cfg.chords end, function(v) OP.SetChords(v) end)
  L:Gap(4)
  L:Button("Open radial menu", 140, function()
    menu:Hide()
    OP.ToggleRadial()
  end)
  L:Label("The stick must send W A S D in Steam Input. Different keys: /opad stick <up> <left> <down> <right>. In combat the D-pad is used instead.", 2)
end

local function BuildHUD(h)
  local cfg = OP.cfg
  Check(h, "Show HUD", 0, 0, function() return cfg.hud end, function(v) cfg.hud = v end)
  Check(h, "Controller-style icons for system actions", 150, 0,
    function() return cfg.sysicons ~= false end, function(v) cfg.sysicons = v end)
  Slider(h, "Overall scale", 4, -44, 0.5, 2, 0.1, function() return cfg.scale end, function(v) cfg.scale = v end)
  Slider(h, "D-pad cross scale", 4, -80, 0.5, 2, 0.1,
    function() return cfg.gscale.left or 1 end, function(v) cfg.gscale.left = v end)
  Slider(h, "Face cross scale", 4, -116, 0.5, 2, 0.1,
    function() return cfg.gscale.right or 1 end, function(v) cfg.gscale.right = v end)

  Cycle(h, "Position", 0, -138,
    function()
      if OP.HUDPfMove and OP.HUDPfMove() then return "managed by pfUI" end
      return OP.PRESET_NAMES[cfg.hudpos] or cfg.hudpos
    end,
    function(d)
      if OP.HUDPfMove and OP.HUDPfMove() then return end
      local list = {}
      local i
      for i = 1, table.getn(OP.PRESET_ORDER) do
        if OP.PRESET_ORDER[i] ~= "custom" or cfg.pos then table.insert(list, OP.PRESET_ORDER[i]) end
      end
      cfg.hudpos = StepList(list, cfg.hudpos, d)
      OP.NotifyChanged()
    end)
  Flat(h, "Reset position", 0, -168, 130, 22, function() OP.ResetHUDPosition() end)
  local editBtn = Flat(h, "Edit layout", 140, -168, 130, 22, function() OP.SetEdit(not OP.edit) end)
  table.insert(refreshers, function()
    if OP.edit then editBtn:SetLabel("Done editing") else editBtn:SetLabel("Edit layout") end
    SetSel(editBtn, OP.edit and true or false)
  end)
  menu.sPf = Label(h, "", 0, -198, 9, .55, .55, .55, 430)

  Header(h, "Selected button (Edit layout)", 0, -232)
  menu.sSelHud = Label(h, "", 0, -252, 10, 1, 1, 1, 430)
  table.insert(refreshers, function()
    local i = OP.editSel
    if i then
      menu.sSelHud:SetText("|cffffffff" .. OP.LabelFor(i) .. "|r  (offset " ..
        ((OP.cfg.btn[i] and OP.cfg.btn[i].dx) or 0) .. ", " .. ((OP.cfg.btn[i] and OP.cfg.btn[i].dy) or 0) .. ")")
    else
      menu.sSelHud:SetText("|cffaaaaaanone|r  - turn on Edit layout, then click a HUD button. Drag to move, mouse wheel to resize.")
    end
  end)
  Slider(h, "Size", 4, -282, 24, 96, 2,
    function()
      local i = OP.editSel
      if i then return OP.ButtonSize(i) end
      return 40
    end,
    function(v)
      local c = Selected()
      if c then c.size = math.floor(v + .5) end
    end)
  Flat(h, "Left", 0, -296, 56, 22, function() Nudge(-1, 0) end)
  Flat(h, "Right", 62, -296, 56, 22, function() Nudge(1, 0) end)
  Flat(h, "Up", 124, -296, 56, 22, function() Nudge(0, 1) end)
  Flat(h, "Down", 186, -296, 56, 22, function() Nudge(0, -1) end)
  Flat(h, "Reset button", 0, -326, 120, 22, function()
    local c, i = Selected()
    if c then OP.cfg.btn[i] = nil end
    OP.NotifyChanged()
  end)
  Flat(h, "Reset layout", 130, -326, 120, 22, function() OP.ResetButtonLayout() end)
end

-- Steam Input, set up by hand (when Steam offers no controller template for the game)
local function BuildSteam(s)
  Header(s, "Steam Input: manual setup", 0, 0)
  Label(s, "For when Steam offers no controller template for WoW. Menu names can differ slightly between Steam versions.", 0, -20, 9, .55, .55, .55, 430)
  Label(s,
    "|cff33ffcc1|r  Steam: Games > Add a Non-Steam Game > WoW.exe. Start WoW from Steam.\n" ..
    "|cff33ffcc2|r  Right-click it > Properties > Controller: Enable Steam Input.\n" ..
    "|cff33ffcc3|r  In game: Steam / Guide button > Controller Layout > Edit Layout.\n" ..
    "     No template? Templates > Keyboard (WASD) and Mouse.\n" ..
    "|cff33ffcc4|r  Face buttons, bumpers, D-pad: keys in the table (by position).\n" ..
    "|cff33ffcc5|r  Triggers: Full Pull = Left Shift / Left Ctrl (held).\n" ..
    "|cff33ffcc6|r  Start: Left Shift + Escape (Add extra command). View: M.\n" ..
    "|cff33ffcc7|r  Left stick: Directional Pad W A S D, click = Num Lock.\n" ..
    "     Right stick: Joystick Mouse, ` held on outer ring. No right click.\n" ..
    "|cff33ffcc8|r  Nintendo Button Layout on in Steam: pick that style on Overview.\n" ..
    "|cff33ffcc9|r  Export Layout (personal), then Apply on Overview.\n",
    0, -40, 10, .85, .85, .85, 440)
  Header(s, "Keys to send", 0, -214)
  local st = OP.Style()
  local left = "Bottom face button   |cffffffff1|r\nLeft face button   |cffffffff2|r\nTop face button   |cffffffff3|r\nRight face button   |cffffffff4|r\n" ..
               "D-pad Dn / L / Up / R   |cffffffff5 6 7 8|r\nRB   |cffffffff9|r\nLB   |cffffffff0|r"
  local right = "LT (hold)   |cffffffffLeft Shift|r\nRT (hold)   |cffffffffLeft Ctrl|r\nStart   |cffffffffShift + Escape|r\nView / Select   |cffffffffM|r\n" ..
                "Left stick   |cffffffffW A S D|r\nLeft stick click   |cffffffffNum Lock|r\nRight stick   |cffffffffMouse + ` held|r"
  Label(s, left, 0, -234, 10, .7, .7, .7, 210)
  Label(s, right, 220, -234, 10, .7, .7, .7, 220)
  Label(s, "Camera key: /opad camerakey <KEY> to change it (default `). Never F12: that is Steam's screenshot key.", 0, -338, 9, .55, .55, .55, 430)
end

local function BuildSystem(y)
  local cfg = OP.cfg
  Header(y, "Minimap button", 0, 0)
  Check(y, "Show minimap button", 0, -20,
    function() return cfg.mmshow end,
    function(v) cfg.mmshow = v; OP.MinimapRefresh() end)
  Cycle(y, "Button shape", 0, -48,
    function() return cfg.mmshape end,
    function(d)
      cfg.mmshape = StepList({ "auto", "round", "square" }, cfg.mmshape, d)
      OP.MinimapRefresh()
      OP.NotifyChanged()
    end)

  Header(y, "Maintenance", 0, -90)
  Flat(y, "Reset button mappings", 0, -110, 170, 22, function()
    cfg.slots = {}
    cfg.ui = {}
    cfg.icons = {}
    cfg.aicons = {}
    OP.Print("Button mappings and icons reset to the profile defaults.")
    OP.NotifyChanged()
  end)
  Flat(y, "Clear blocked-function log", 180, -110, 190, 22, function()
    cfg.blocked = {}
    OP.NotifyChanged()
  end)

  Header(y, "Diagnostics", 0, -150)
  menu.sDiag = Label(y, "", 0, -170, 10, .8, .8, .8, 430)
  Label(y, "Slash commands: /opad  (menu)   /opad help  (everything else)   /opad debug", 0, -250, 9, .55, .55, .55, 430)
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
local function BuildMenu()
  if menu then return end

  menu = CreateFrame("Frame", "OctoPadMenu", UIParent)
  menu:SetWidth(610)
  menu:SetHeight(450)
  menu:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  menu:SetFrameStrata("DIALOG")
  menu:SetMovable(true)
  menu:EnableMouse(true)
  menu:SetClampedToScreen(true)
  menu:RegisterForDrag("LeftButton")
  menu:SetScript("OnDragStart", function() this:StartMoving() end)
  menu:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  if not OP.Round(menu, .95) then menu:SetBackdrop(FLAT) end
  menu:Hide()
  tinsert(UISpecialFrames, "OctoPadMenu")

  local title = menu:CreateFontString(nil, "OVERLAY")
  title:SetFont(OP.Font(), 14, "OUTLINE")
  title:SetPoint("TOPLEFT", menu, "TOPLEFT", 16, -14)
  title:SetText("|cff33ffccOctoPad|r")
  menu.title = title
  local ver = menu:CreateFontString(nil, "OVERLAY")
  ver:SetFont(OP.Font(), 10)
  ver:SetPoint("LEFT", title, "RIGHT", 8, -1)
  ver:SetTextColor(.5, .5, .5)
  ver:SetText("controller  v" .. OP.VERSION)

  Flat(menu, "x", 580, -8, 22, 22, function() menu:Hide() end, "OctoPadMenuClose")

  -- sidebar: OctoPadMenuTab1..N so LB / RB (tab navigation) work
  local side = menu:CreateTexture(nil, "BACKGROUND")
  menu.sideTex = side
  side:SetTexture("Interface\\Buttons\\WHITE8X8")
  side:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -40)
  side:SetWidth(128)
  side:SetHeight(380)

  menu.pages = {}
  menu.tabBtns = {}
  local t
  for t = 1, table.getn(CATS) do
    local idx = t
    menu.tabBtns[t] = Flat(menu, CATS[t], 8, -50 - (t - 1) * 34, 112, 28,
      function() ShowTab(idx) OP.MenuRefresh() end, "OctoPadMenuTab" .. t)
    local page = CreateFrame("Frame", UName("Page"), menu)
    page:SetPoint("TOPLEFT", menu, "TOPLEFT", 148, -56)
    page:SetWidth(440)
    page:SetHeight(360)
    menu.pages[t] = page
  end

  BuildOverview(menu.pages[1])
  BuildBindings(menu.pages[2])
  BuildInterface(menu.pages[3])
  BuildWorld(menu.pages[4])
  BuildHUD(menu.pages[5])
  BuildSystem(menu.pages[6])
  BuildSteam(menu.pages[7])

  -- LB / RB (tab navigation) switch categories even without a focus ring
  menu.opTabFn = function(dir)
    local n = menu.tab + dir
    if n < 1 then n = table.getn(CATS) elseif n > table.getn(CATS) then n = 1 end
    ShowTab(n)
    OP.MenuRefresh()
  end

  local foot = menu:CreateFontString(nil, "OVERLAY")
  menu.foot = foot
  foot:SetFont(OP.Font(), 9)
  foot:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 16, 10)
  foot:SetTextColor(.5, .5, .5)

  menu:SetScript("OnShow", function() OP.MenuRefresh() end)
  local acc = 0
  menu:SetScript("OnUpdate", function()
    acc = acc + arg1
    if acc >= 0.4 then
      acc = 0
      UpdateStatus()
    end
  end)

  ShowTab(1)
end

function OP.ToggleMenu()
  BuildMenu()
  if menu:IsShown() then
    menu:Hide()
  else
    menu:Show()
  end
end

----------------------------------------------------------------------
-- Minimap button
----------------------------------------------------------------------
local function MinimapSquare()
  local shape = OP.cfg.mmshape
  if shape == "square" then return true end
  if shape == "round" then return false end
  if pfUI and not (pfUI_config and pfUI_config.disabled and pfUI_config.disabled["minimap"] == "1") then
    return true
  end
  return false
end

local function PositionMinimap()
  if not mm then return end
  local a = math.rad(OP.cfg.mmangle or 225)
  local cs, sn = math.cos(a), math.sin(a)
  local hw = Minimap:GetWidth() / 2
  local hh = Minimap:GetHeight() / 2
  local x, y
  if MinimapSquare() then
    local t1, t2 = 99999, 99999
    if math.abs(cs) > 0.0001 then t1 = hw / math.abs(cs) end
    if math.abs(sn) > 0.0001 then t2 = hh / math.abs(sn) end
    local t = math.min(t1, t2) + 4
    x, y = cs * t, sn * t
  else
    local r = hw + 10
    x, y = cs * r, sn * r
  end
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function OP.MinimapRefresh()
  if mm and mm.icon and OP.cfg then
    local st = OP.cfg.style or "xbox"
    local th = (st == "ps") and "ps" or ((st == "switch" or st == "switchn") and "switch" or "xbox")
    mm.icon:SetTexture("Interface\\AddOns\\OctoPad\\Icons\\" .. th .. "_MINIMAP")
  end
  if not mm then return end
  if OP.cfg.mmshow then mm:Show() else mm:Hide() end
  PositionMinimap()
end

function OP.BuildMinimap()
  if mm then return end
  mm = CreateFrame("Button", "OctoPadMinimapButton", Minimap)
  mm:SetFrameStrata("MEDIUM")
  mm:SetFrameLevel(8)
  mm:SetWidth(31)
  mm:SetHeight(31)
  mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  mm:RegisterForDrag("LeftButton")
  mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = mm:CreateTexture(nil, "BACKGROUND")
  icon:SetWidth(20)
  icon:SetHeight(20)
  icon:SetTexture("Interface\\AddOns\\OctoPad\\Icons\\xbox_MINIMAP")
  icon:SetTexCoord(0, 1, 0, 1)
  mm.icon = icon
  icon:SetPoint("TOPLEFT", mm, "TOPLEFT", 6, -5)

  local border = mm:CreateTexture(nil, "OVERLAY")
  border:SetWidth(53)
  border:SetHeight(53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT", mm, "TOPLEFT", 0, 0)

  mm:SetScript("OnClick", function()
    if arg1 == "RightButton" then
      OP.cfg.hud = not OP.cfg.hud
      OP.NotifyChanged()
    elseif IsShiftKeyDown() then
      OP.ToggleRadial()
    else
      OP.ToggleMenu()
    end
  end)

  mm:SetScript("OnDragStart", function() this.dragging = true end)
  mm:SetScript("OnDragStop", function() this.dragging = nil end)
  mm:SetScript("OnUpdate", function()
    if not this.dragging then return end
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local sc = Minimap:GetEffectiveScale()
    cx, cy = cx / sc, cy / sc
    OP.cfg.mmangle = math.deg(math.atan2(cy - my, cx - mx))
    PositionMinimap()
  end)

  mm:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("OctoPad")
    local st = OP.BindingStatus()
    if st == "ok" then
      GameTooltip:AddLine("Key bindings: applied", 0, 1, 0)
    else
      GameTooltip:AddLine("Key bindings: " .. st .. " - open the menu", 1, .3, .3)
    end
    GameTooltip:AddLine("Left-click: options", 1, 1, 1)
    GameTooltip:AddLine("Right-click: show / hide HUD", 1, 1, 1)
    GameTooltip:AddLine("Shift-click: radial menu", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", .7, .7, .7)
    GameTooltip:Show()
  end)
  mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

  OP.MinimapRefresh()
end
