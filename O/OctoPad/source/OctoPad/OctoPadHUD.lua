--[[
OctoPad HUD  -  Console Experience-style layout, two independent crosses:

        [Up]                    [Y]
   [Left][LB][Right]       [X][RB][B]        LB / RB sit in the centre of each cross
       [Down]                  [A]

  * Each cross is its own frame (OctoPadHUDLeft / OctoPadHUDRight): move them
    separately, scale them separately.
  * Every button can have its own offset and size (layout edit mode).
  * The bar shown depends on the held triggers (none / LT / RT / both).
  * While a window is open the buttons show their WINDOW action (Confirm, Back,
    arrows, ...) unless you are carrying a spell / item to drop on a button.

pfUI: each cross registers with pfUI's movable-frame system (UpdateMovable), so
its position is stored in pfUI_config and follows pfUI profiles.
]]

local OP = OctoPad

local groups = {}          -- groups.left / groups.right
local buttons = {}
local radial
local lastPage = -1
local acc = 0
local drv

local BS = 40              -- default button size
local D = 44               -- distance from cross centre to the 4 outer buttons
local CX = 100             -- cross centre offset from screen centre (centred presets)

local FACE_XBOX     = { { 0, -D }, { -D, 0 }, { 0, D }, { D, 0 } }   -- 1 bottom, 2 left, 3 top, 4 right
local FACE_NINTENDO = { { D, 0 }, { 0, D }, { -D, 0 }, { 0, -D } }   -- 1 right, 2 top, 3 left, 4 bottom
local DPAD_POS      = { { 0, -D }, { -D, 0 }, { 0, D }, { D, 0 } }   -- 5 down, 6 left, 7 up, 8 right
local SIDE = { "right", "right", "right", "right", "left", "left", "left", "left", "right", "left" }

local PRESETS = {
  bottom      = { left = { "BOTTOM", "BOTTOM", -CX, 10 },     right = { "BOTTOM", "BOTTOM", CX, 10 } },
  bottomwide  = { left = { "BOTTOM", "BOTTOM", -300, 10 },    right = { "BOTTOM", "BOTTOM", 300, 10 } },
  abovebars   = { left = { "BOTTOM", "BOTTOM", -CX, 110 },    right = { "BOTTOM", "BOTTOM", CX, 110 } },
  bottomleft  = { left = { "BOTTOMLEFT", "BOTTOMLEFT", 20, 10 },
                  right = { "BOTTOMLEFT", "BOTTOMLEFT", 20 + 2 * CX, 10 } },
  bottomright = { right = { "BOTTOMRIGHT", "BOTTOMRIGHT", -20, 10 },
                  left = { "BOTTOMRIGHT", "BOTTOMRIGHT", -20 - 2 * CX, 10 } },
}
OP.PRESET_ORDER = { "auto", "barsides", "bottom", "abovebars", "bottomleft", "bottomright", "custom" }
OP.PRESET_NAMES = {
  auto = "Auto", barsides = "Beside the action bar", bottom = "Bottom center", abovebars = "Above action bars",
  bottomleft = "Bottom left", bottomright = "Bottom right", custom = "Custom (dragged)",
}

local function CurrentPage()
  local p = 0
  if IsShiftKeyDown() then p = p + 1 end
  if IsControlKeyDown() then p = p + 2 end
  return p
end

local function CursorBusy()
  return (CursorHasSpell and CursorHasSpell()) or (CursorHasItem and CursorHasItem()) or (CursorHasMacro and CursorHasMacro())
end

----------------------------------------------------------------------
-- Positions
----------------------------------------------------------------------
-- the main action bar (pfUI's, else Blizzard's): the crosses sit at its left and right ends
local BAR_NAMES = { "pfActionBarMain", "pfBarActionMain", "pfActionBar1", "pfUIActionBarMain", "MainMenuBar" }
local function FindActionBar()
  local i
  for i = 1, table.getn(BAR_NAMES) do
    local f = getglobal(BAR_NAMES[i])
    if f and f.GetWidth and f.IsVisible and f:IsVisible() and f:GetWidth() > 100 and f:GetLeft() then return f end
  end
  return nil
end

local function ApplyGroupPosition(side)
  local cfg = OP.cfg
  local g = groups[side]
  local key = cfg.hudpos
  if key == "auto" then key = "barsides" end
  g:ClearAllPoints()
  if key == "barsides" then
    local bar = FindActionBar()
    if bar then
      g.barAnchored = true
      -- spread out from the bar so the crosses clear the nameplates (pfUI "Nostalgia" layout included)
      if side == "left" then g:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -44, 0)
      else g:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 44, 0) end
      return
    end
    g.barAnchored = false
    key = "bottomwide"
  end
  if key == "custom" and cfg.pos and cfg.pos[side] then
    local p = cfg.pos[side]
    g:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    local p = (PRESETS[key] or PRESETS.bottom)[side]
    g:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  end
end

local function SaveAllPos()
  local cfg = OP.cfg
  cfg.pos = {}
  local side
  for _, side in ipairs({ "left", "right" }) do
    local p, _, rp, x, y = groups[side]:GetPoint()
    cfg.pos[side] = { p, rp, x, y }
  end
  cfg.hudpos = "custom"
  if OP.MenuRefresh then OP.MenuRefresh() end
end

function OP.HUDPfMove()
  return groups.left and groups.right and groups.left.pfmove and groups.right.pfmove
end

function OP.ResetHUDPosition()
  local cfg = OP.cfg
  if not groups.left then return end
  cfg.hudpos = "auto"
  cfg.pos = nil
  if OP.HUDPfMove() and pfUI_config and pfUI_config.position then
    pfUI_config.position["OctoPadHUDLeft"] = nil
    pfUI_config.position["OctoPadHUDRight"] = nil
  end
  ApplyGroupPosition("left")
  ApplyGroupPosition("right")
  if OP.HUDPfMove() then
    pcall(pfUI.api.UpdateMovable, groups.left, true)
    pcall(pfUI.api.UpdateMovable, groups.right, true)
  end
  OP.NotifyChanged()
end

function OP.ResetButtonLayout()
  local cfg = OP.cfg
  cfg.btn = {}
  cfg.gscale = { left = 1, right = 1 }
  OP.editSel = nil
  OP.NotifyChanged()
end

----------------------------------------------------------------------
-- Layout of the buttons inside each cross
----------------------------------------------------------------------
local function DefaultPos(i)
  local face = FACE_XBOX
  if OP.Style().pos == "nintendo" then face = FACE_NINTENDO end
  if i <= 4 then return face[i][1], face[i][2] end
  if i <= 8 then return DPAD_POS[i - 4][1], DPAD_POS[i - 4][2] end
  return 0, 0                       -- bumpers: centre of their cross
end

function OP.ButtonSize(i)
  local c = OP.cfg.btn[i]
  return (c and c.size) or BS
end

local function LayoutHUD()
  if not groups.left then return end
  local cfg = OP.cfg
  local br, bg, bb = OP.BorderColor()
  local i
  for i = 1, 10 do
    local b = buttons[i]
    local dx, dy = DefaultPos(i)
    b.defx, b.defy = dx, dy
    local c = cfg.btn[i]
    local size = BS
    if c then
      dx = dx + (c.dx or 0)
      dy = dy + (c.dy or 0)
      size = c.size or BS
    end
    b:SetWidth(size)
    b:SetHeight(size)
    b:ClearAllPoints()
    b:SetPoint("CENTER", b.group, "CENTER", dx, dy)
    local fs = 9
    if size < 30 then fs = 8 end
    b.label:SetFont(OP.Font(), fs, "OUTLINE")
    b.name:SetFont(OP.Font(), fs, "OUTLINE")
    -- border: pfUI colour normally, blue in edit mode, yellow for the selected button
    if OP.edit then
      if OP.editSel == i then OP.BD(b):SetBackdropBorderColor(1, .85, 0, 1) else OP.BD(b):SetBackdropBorderColor(.2, .5, 1, 1) end
    else
      OP.BD(b):SetBackdropBorderColor(br, bg, bb, 1)
    end
  end
  local side
  for _, side in ipairs({ "left", "right" }) do
    groups[side]:SetScale(cfg.scale * (cfg.gscale[side] or 1))
  end
end

----------------------------------------------------------------------
-- Button contents
----------------------------------------------------------------------
-- window control -> retro keycap texture (Glyphs\\key_*.tga)
local ROLE_KEYCAP = {
  UI_CONFIRM = "key_confirm", UI_BACK = "key_back", UI_ALT = "key_alt", UI_SHIFT = "key_shift",
  UI_UP = "key_up", UI_DOWN = "key_down", UI_LEFT = "key_left", UI_RIGHT = "key_right",
  UI_TAB_NEXT = "key_tabnext", UI_TAB_PREV = "key_tabprev",
  UI_SCROLL_UP = "key_scrollup", UI_SCROLL_DOWN = "key_scrolldown", UI_DESTROY = "key_destroy",
}

local function RefreshButton(btn, page, uiActive, cursor)
  local cfg = OP.cfg
  local n = page * 10 + btn.idx
  btn.n = n

  if btn.legend then btn.legend:Hide() end
  -- controller glyph for the selected style (image, not text)
  btn.label:SetText("")
  btn.badge:SetTexture(OP.GlyphFor(btn.idx))
  btn.badge:SetVertexColor(1, 1, 1)
  if btn.idx == 9 or btn.idx == 10 then
    btn.badge:SetWidth(22)
    btn.badge:SetHeight(14)
    btn.badge:SetTexCoord(0, 1, .18, .82)
  else
    btn.badge:SetWidth(14)
    btn.badge:SetHeight(14)
    btn.badge:SetTexCoord(0, 1, 0, 1)
  end

  -- window context: show what the button does to the open window
  local role = uiActive and not cursor and not OP.edit and OP.UIRoleFor(n)
  if role then
    btn.slot = nil
    if not btn.legend then
      btn.legend = btn:CreateTexture(nil, "OVERLAY")
      btn.legend:SetAllPoints(btn.icon)
    end
    if not OP.PaintKeycap(btn.icon, btn.legend, role) then
      btn.legend:Hide()
      btn.icon:SetTexture("Interface\\Buttons\\WHITE8X8")
      btn.icon:SetTexCoord(0, 1, 0, 1)
      btn.icon:SetVertexColor(.1, .25, .5)
    end
    btn.icon:Show()
    btn.name:SetText(OP.UI_ROLE_NAMES[role] or role)
    btn.count:SetText("")
    if btn.cdS then
      CooldownFrame_SetTimer(btn.cd, 0, 0, 0)
      btn.cdS = nil; btn.cdD = nil
    end
    return
  end

  btn.icon:SetTexCoord(.07, .93, .07, .93)
  local proxy = OP.ProxyFor(n)
  if proxy and OP.ACTIONS[proxy] then
    btn.slot = nil
    btn.icon:SetTexture(OP.IconFor(n, proxy))
    btn.icon:SetVertexColor(1, 1, 1)
    btn.icon:Show()
    btn.name:SetText(OP.ACTIONS[proxy].short)
    btn.count:SetText("")
    if btn.cdS then
      CooldownFrame_SetTimer(btn.cd, 0, 0, 0)
      btn.cdS = nil; btn.cdD = nil
    end
    return
  end

  local slot = OP.ActualSlot(n)
  btn.slot = slot
  local tex = GetActionTexture(slot)
  if tex then
    btn.icon:SetTexture(tex)
    btn.icon:Show()
    local usable, nomana = IsUsableAction(slot)
    -- no possible target in range: grayed out (the soft-selected / mouseover unit counts as a possible target)
    local oor = IsActionInRange and IsActionInRange(slot) == 0 and not OP.softToken and not UnitExists("mouseover")
    if oor then
      btn.icon:SetVertexColor(.4, .4, .4)
    elseif usable then
      btn.icon:SetVertexColor(1, 1, 1)
    elseif nomana then
      btn.icon:SetVertexColor(.5, .5, 1)
    else
      btn.icon:SetVertexColor(.45, .45, .45)
    end
    local txt = GetActionText(slot)
    btn.name:SetText(txt or "")
    local c = 0
    if GetActionCount then c = GetActionCount(slot) or 0 end
    if c > 0 then btn.count:SetText(c) else btn.count:SetText("") end
    local s, d, e = GetActionCooldown(slot)
    if s ~= btn.cdS or d ~= btn.cdD then
      CooldownFrame_SetTimer(btn.cd, s, d, e)
      btn.cdS = s; btn.cdD = d
    end
  else
    btn.icon:Hide()
    btn.name:SetText("")
    btn.count:SetText("")
    if btn.cdS then
      CooldownFrame_SetTimer(btn.cd, 0, 0, 0)
      btn.cdS = nil; btn.cdD = nil
    end
  end
end

local function RefreshAll(page)
  local cfg = OP.cfg
  local ui = (cfg.uimode and OP.UIActive and OP.UIActive()) and true or false
  local cursor = CursorBusy() and true or false
  local i
  for i = 1, 10 do RefreshButton(buttons[i], page, ui, cursor) end
end

local function ButtonClick(btn)
  if OP.edit then
    OP.editSel = btn.idx
    OP.NotifyChanged()
    return
  end
  if CursorBusy() then
    -- same as Blizzard bars: click with something on the cursor places it
    if btn.slot then
      PlaceAction(btn.slot)
      lastPage = -1
    else
      local proxy = OP.ProxyFor(btn.n)
      OP.Print("Slot " .. btn.n .. " (" .. OP.SlotName(btn.n) .. ") is set to the system action " .. tostring(proxy) .. ". Open the OctoPad menu > Slots and set its Game action to 'Action bar' to place abilities here.")
    end
    return
  end
  OctoPad_Action(btn.n)
end

----------------------------------------------------------------------
-- Build
----------------------------------------------------------------------
local function BuildGroup(side)
  local cfg = OP.cfg
  local name = (side == "left") and "OctoPadHUDLeft" or "OctoPadHUDRight"
  local g = CreateFrame("Frame", name, UIParent)
  g:SetWidth(140)
  g:SetHeight(140)
  g:SetFrameStrata("HIGH")
  g:SetMovable(true)
  g:SetClampedToScreen(true)
  g.side = side
  groups[side] = g
  ApplyGroupPosition(side)

  -- pfUI: register with its movable system so the position is part of the pfUI profile
  g.pfmove = false
  if pfUI and pfUI.api and pfUI.api.UpdateMovable and pfUI.movables then
    local ok = pcall(pfUI.api.UpdateMovable, g)
    if ok then g.pfmove = true end
  end

  -- drag handle (layout edit mode, only when pfUI is not managing the position)
  g.handle = CreateFrame("Button", name .. "Handle", g)
  g.handle:SetWidth(110)
  g.handle:SetHeight(14)
  g.handle:SetPoint("BOTTOM", g, "TOP", 0, -10)
  g.handle:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  g.handle:SetBackdropColor(.2, .5, 1, .85)
  local ht = g.handle:CreateFontString(nil, "OVERLAY")
  ht:SetFont(OP.Font(), 9, "OUTLINE")
  ht:SetPoint("CENTER", g.handle, "CENTER", 0, 0)
  ht:SetText((side == "left" and "D-pad cross" or "Face cross") .. " - drag")
  g.handle:RegisterForDrag("LeftButton")
  g.handle:SetScript("OnDragStart", function() g:StartMoving() end)
  g.handle:SetScript("OnDragStop", function() g:StopMovingOrSizing(); SaveAllPos() end)
  g.handle:Hide()
  return g
end

local function BuildButton(i)
  local cfg = OP.cfg
  local g = groups[SIDE[i]]
  local b = CreateFrame("Button", "OctoPadButton" .. i, g)
  b.idx = i
  b.group = g
  b:SetWidth(BS)
  b:SetHeight(BS)
  b:SetMovable(true)
  if not OP.Round(b, .6) then
    b:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    b:SetBackdropColor(0, 0, 0, 0.6)
  end

  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(.07, .93, .07, .93)

  b.cd = CreateFrame("Model", "OctoPadButton" .. i .. "Cooldown", b, "CooldownFrameTemplate")
  b.cd:SetAllPoints(b)

  b.hi = b:CreateTexture(nil, "OVERLAY")
  b.hi:SetAllPoints(b)
  b.hi:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
  b.hi:SetBlendMode("ADD")
  b.hi:SetAlpha(0)

  b.name = b:CreateFontString(nil, "OVERLAY")
  b.name:SetFont(OP.Font(), 9, "OUTLINE")
  b.name:SetPoint("BOTTOM", b, "BOTTOM", 0, 2)
  b.count = b:CreateFontString(nil, "OVERLAY")
  b.count:SetFont(OP.Font(), 11, "OUTLINE")
  b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)

  -- controller glyph badge (inside the top-left corner)
  b.badge = b:CreateTexture(nil, "OVERLAY")
  b.badge:SetTexture("Interface\\Buttons\\WHITE8X8")
  b.badge:SetHeight(13)
  b.badge:SetWidth(16)
  b.badge:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
  b.label = b:CreateFontString(nil, "OVERLAY")
  b.label:SetFont(OP.Font(), 9, "OUTLINE")
  b.label:SetPoint("CENTER", b.badge, "CENTER", 0, 0)

  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("LeftButton")
  b:EnableMouseWheel(true)

  b:SetScript("OnClick", function() ButtonClick(this) end)

  b:SetScript("OnDragStart", function()
    if OP.edit then
      this:StartMoving()
      this.moving = true
      return
    end
    if this.slot and (LOCK_ACTIONBAR ~= "1" or IsShiftKeyDown()) then
      PickupAction(this.slot)
      lastPage = -1
    end
  end)
  b:SetScript("OnDragStop", function()
    if this.moving then
      this:StopMovingOrSizing()
      this.moving = nil
      local bx, by = this:GetCenter()
      local gx, gy = this.group:GetCenter()
      local c = cfg.btn[this.idx] or {}
      c.dx = math.floor(bx - gx - this.defx + .5)
      c.dy = math.floor(by - gy - this.defy + .5)
      cfg.btn[this.idx] = c
      OP.editSel = this.idx
      OP.NotifyChanged()
    end
  end)
  b:SetScript("OnReceiveDrag", function()
    if not OP.edit and this.slot then
      PlaceAction(this.slot)
      lastPage = -1
    end
  end)
  b:SetScript("OnMouseWheel", function()
    if not OP.edit then return end
    local c = cfg.btn[this.idx] or {}
    local s = (c.size or BS) + arg1 * 2
    if s < 24 then s = 24 elseif s > 96 then s = 96 end
    c.size = s
    cfg.btn[this.idx] = c
    OP.editSel = this.idx
    OP.NotifyChanged()
  end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:SetText(OP.SlotName(this.n) .. "  (slot " .. this.n .. ")")
    if OP.edit then
      GameTooltip:AddLine("Edit mode: drag to move, mouse wheel to resize, click to select", .7, .9, 1)
    else
      local proxy = OP.ProxyFor(this.n)
      if proxy then
        GameTooltip:AddLine("Game: system action " .. proxy, 1, 1, 1)
      elseif this.slot then
        GameTooltip:AddLine("Game: action bar slot " .. this.slot .. " (drag an ability here)", .8, .8, .8)
      end
      local role = OP.UIRoleFor(this.n)
      if role then GameTooltip:AddLine("Window: " .. (OP.UI_ROLE_NAMES[role] or role), .6, .8, 1) end
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  buttons[i] = b
end

function OP.BuildHUD()
  if groups.left then return end
  local cfg = OP.cfg
  BuildGroup("left")
  BuildGroup("right")
  local i
  for i = 1, 10 do BuildButton(i) end

  drv = CreateFrame("Frame", "OctoPadHUDDriver", UIParent)
  local barTry, barAcc = 0, 0
  drv:SetScript("OnUpdate", function()
    if not cfg.hud then return end
    local now = GetTime()
    -- the action bar may be created after OctoPad: keep trying for a while
    barAcc = barAcc + arg1
    if barAcc >= 1 and barTry < 30 then
      barAcc = 0
      barTry = barTry + 1
      if (cfg.hudpos == "auto" or cfg.hudpos == "barsides") and not groups.left.barAnchored and not OP.edit then
        local s
        for _, s in ipairs({ "left", "right" }) do
          local g = groups[s]
          local saved = g.pfmove and pfUI_config and pfUI_config.position and pfUI_config.position[g:GetName()]
          if not saved then ApplyGroupPosition(s) end
        end
      end
    end
    local page = CurrentPage()
    acc = acc + arg1
    if page ~= lastPage or acc >= 0.1 then
      acc = 0
      lastPage = page
      RefreshAll(page)
    end
    local k
    for k = 1, 10 do
      local bt = buttons[k]
      if bt.flash and bt.flash > now then bt.hi:SetAlpha(.6) else bt.hi:SetAlpha(0) end
    end
  end)

  OP.HUDRefresh()
end

function OP.HUDRefresh()
  if not groups.left then return end
  local cfg = OP.cfg
  local side
  for _, side in ipairs({ "left", "right" }) do
    local g = groups[side]
    if cfg.hud then g:Show() else g:Hide() end
    if OP.edit and not g.pfmove then g.handle:Show() else g.handle:Hide() end
    if not g.pfmove then ApplyGroupPosition(side) end
  end
  LayoutHUD()
  lastPage = -1
  RefreshAll(CurrentPage())
  if OP.RadialRefresh then OP.RadialRefresh() end
end

function OP.SetEdit(on)
  OP.edit = on and true or false
  if OP.edit then
    OP.cfg.hud = true
  else
    OP.editSel = nil
  end
  OP.HUDRefresh()
  if OP.MenuRefresh then OP.MenuRefresh() end
end

-- brief highlight of the HUD button when its controller key arrives
function OP.Flash(n)
  if not groups.left then return end
  local page = math.floor((n - 1) / 10)
  local idx = math.mod(n - 1, 10) + 1
  if page == lastPage and buttons[idx] then buttons[idx].flash = GetTime() + 0.15 end
end

----------------------------------------------------------------------
-- Radial menu
----------------------------------------------------------------------
local RADIAL_ITEMS = { "CHARACTER", "SPELLBOOK", "TALENTS", "BAGS", "QUESTS", "MAP", "OCTOPAD", "GAMEMENU" }
local radialSel = nil
local STICK_NAMES = { "UP", "LEFT", "DOWN", "RIGHT" }       -- order of cfg.stickkeys
local stickSaved = {}
local stickHeld = { UP = false, LEFT = false, DOWN = false, RIGHT = false }

local function CenterText()
  local st = OP.Style()
  local a = radialSel and OP.ACTIONS[RADIAL_ITEMS[radialSel]]
  local hint
  if OP.stickActive then
    hint = "Left stick: select   " .. st.face[1] .. ": confirm   " .. st.face[4] .. ": close"
  else
    hint = "D-pad: select   " .. st.face[1] .. ": confirm   " .. st.face[4] .. ": close"
  end
  if a then
    radial.center:SetText("|cff33ffcc" .. a.short .. "|r\n|cffaaaaaa" .. hint .. "|r")
  else
    local first = OP.stickActive and "Move the left stick" or "Use the D-pad"
    radial.center:SetText(first .. "\n|cffaaaaaa" .. st.face[1] .. ": confirm   " .. st.face[4] .. ": close|r")
  end
end

local function SelectRadial(i)
  if i then
    if i < 1 then i = 8 elseif i > 8 then i = 1 end
  end
  radialSel = i
  local k
  for k = 1, 8 do
    if k == i then radial.btns[k].hl:Show() else radial.btns[k].hl:Hide() end
  end
  CenterText()
end

local function ConfirmRadial(i)
  if not i then return end
  local a = OP.ACTIONS[RADIAL_ITEMS[i]]
  radial:Hide()
  if a then a.fn() end
end

-- While the radial is open the left stick's keys (default W A S D) are pointed at
-- OctoPad so the stick picks a sector; the movement bindings come back when it closes.
function OP.BeginStick()
  OP.stickActive = false
  local cfg = OP.cfg
  if not cfg.stickradial then return end
  if InCombatLockdown and InCombatLockdown() then return end
  local keys = cfg.stickkeys
  local i
  for i = 1, 4 do
    local k = keys[i]
    if k and k ~= "" then
      local cur = GetBindingAction(k)
      if cur and string.find(cur, "^OCTOPAD_STICK") then cur = stickSaved[k] end
      stickSaved[k] = cur
      SetBinding(k, "OCTOPAD_STICK_" .. STICK_NAMES[i])
    end
  end
  stickHeld.UP, stickHeld.LEFT, stickHeld.DOWN, stickHeld.RIGHT = false, false, false, false
  OP.stickActive = true
end

function OP.EndStick()
  local k, cmd
  for k, cmd in pairs(stickSaved) do
    if cmd and cmd ~= "" then SetBinding(k, cmd) else SetBinding(k) end
  end
  stickSaved = {}
  stickHeld.UP, stickHeld.LEFT, stickHeld.DOWN, stickHeld.RIGHT = false, false, false, false
  OP.stickActive = false
end

-- called for every key down / up of the four stick keys
function OP.StickKey(dir, state)
  if stickHeld[dir] == nil then return end
  stickHeld[dir] = (state == "down")
  if not (radial and radial:IsShown()) then return end
  local x, y = 0, 0
  if stickHeld.RIGHT then x = x + 1 end
  if stickHeld.LEFT then x = x - 1 end
  if stickHeld.UP then y = y + 1 end
  if stickHeld.DOWN then y = y - 1 end
  if x == 0 and y == 0 then return end              -- stick released: keep the selection
  local ang = math.deg(math.atan2(x, y))            -- 0 = up, clockwise
  if ang < 0 then ang = ang + 360 end
  local sector = math.floor((ang + 22.5) / 45) + 1
  if sector > 8 then sector = 1 end
  if sector ~= radialSel then SelectRadial(sector) end
end

local function BuildRadial()
  if radial then return end
  radial = CreateFrame("Frame", "OctoPadRadial", UIParent)
  radial:SetWidth(330)
  radial:SetHeight(330)
  radial:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
  radial:SetFrameStrata("DIALOG")
  if not OP.Round(radial, .9) then
    radial:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    local th = OP.Theme()
    radial:SetBackdropColor(th.bg[1], th.bg[2], th.bg[3], th.bg[4])
    radial:SetBackdropBorderColor(th.ac[1], th.ac[2], th.ac[3], .6)
  end
  radial:Hide()
  radial.btns = {}

  radial.center = radial:CreateFontString(nil, "OVERLAY")
  radial.center:SetFont(OP.Font(), 13, "OUTLINE")
  radial.center:SetPoint("CENTER", radial, "CENTER", 0, 0)
  radial.center:SetWidth(150)

  local i
  for i = 1, 8 do
    local b = CreateFrame("Button", "OctoPadRadial" .. i, radial)
    b.idx = i
    b:SetWidth(56)
    b:SetHeight(56)
    local ang = math.rad((i - 1) * 45)
    b:SetPoint("CENTER", radial, "CENTER", 118 * math.sin(ang), 118 * math.cos(ang))
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.icon:SetTexture(OP.cfg.aicons[RADIAL_ITEMS[i]] or OP.ACTIONS[RADIAL_ITEMS[i]].icon)
    b.icon:SetTexCoord(.07, .93, .07, .93)
    b.hl = b:CreateTexture(nil, "OVERLAY")
    b.hl:SetAllPoints(b)
    b.hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    b.hl:SetBlendMode("ADD")
    b.hl:Hide()
    b:SetScript("OnEnter", function() SelectRadial(this.idx) end)
    b:SetScript("OnClick", function() ConfirmRadial(this.idx) end)
    radial.btns[i] = b
  end
  tinsert(UISpecialFrames, "OctoPadRadial")
  radial:SetScript("OnShow", function()
    OP.BeginStick()
    SelectRadial(nil)
  end)
  radial:SetScript("OnHide", function() OP.EndStick() end)
end

function OP.ToggleRadial()
  BuildRadial()
  if radial:IsShown() then radial:Hide() else radial:Show() end
end

function OP.CloseRadial()
  if radial then radial:Hide() end
end

function OP.RadialShown()
  return radial and radial:IsShown()
end

function OP.RadialRefresh()
  if not radial then return end
  local i
  for i = 1, 8 do
    radial.btns[i].icon:SetTexture(OP.cfg.aicons[RADIAL_ITEMS[i]] or OP.ACTIONS[RADIAL_ITEMS[i]].icon)
  end
end

-- face keys while the radial is open (key positions: 1 = bottom face, 4 = right face)
-- The D-pad only selects when the stick keys could not be taken over (combat, or the option is off).
function OP.RadialKey(idx)
  if idx == 1 then ConfirmRadial(radialSel)
  elseif idx == 4 then OP.CloseRadial()
  elseif not OP.stickActive then
    local cur = radialSel or 0
    if idx == 6 or idx == 7 then SelectRadial(cur - 1)
    elseif idx == 8 or idx == 5 then SelectRadial(cur + 1) end
  end
end
