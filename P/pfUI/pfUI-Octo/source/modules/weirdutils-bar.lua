pfUI:RegisterModule("weirdutils-bar", "vanilla", function ()
  -- pfUI Octo :: a small on-screen bar for WeirdUtils' world markers
  -- (29 Oct 2026; user: "a small UI for the marks that you can move and lock
  -- ... clickable marks that you can place on yourself or on your cursor").
  -- Left-click a mark = on you; right-click = armed, your next left-click on
  -- the ground puts it there; Shift-click = remove that mark. Off by default:
  -- C.weirdutils.bar, lock in C.weirdutils.lock (WeirdUtils page).
  -- WeirdUtils functions are called directly, never through pcall (that
  -- crashed the client, see weirdutils-options.lua).
  C.weirdutils = C.weirdutils or {}
  local S = C.weirdutils
  if S.bar == nil then S.bar = "0" end
  if S.lock == nil then S.lock = "0" end

  local MB = {}
  pfUI.markbar = MB
  -- WorldMarker index -> raid icon cell (UI-RaidTargetingIcons, 4 x 4) and colour
  MB.MARKS = {
    { "Blue square", 6, 0, .44, 1 },
    { "Green triangle", 4, .2, 1, .2 },
    { "Purple diamond", 3, .8, .3, 1 },
    { "Red cross", 7, 1, .2, .2 },
    { "Yellow star", 1, 1, .9, .1 },
  }

  function MB.Available()
    return type(_G.WorldMarkers) == "table" and type(_G.WorldMarkers.UI_WorldMarker) == "function"
  end
  function MB.Place(i, unit) if MB.Available() then _G.WorldMarkers.UI_WorldMarker(i, unit) end end
  function MB.Clear(i)
    if type(_G.WorldMarkers) == "table" and _G.WorldMarkers.UI_ClearWorldMarker then _G.WorldMarkers.UI_ClearWorldMarker(i) end
  end

  local SIZE, GAP = 24, 3
  local f = CreateFrame("Frame", "pfWorldMarkerBar", UIParent)
  MB.frame = f
  f:SetFrameStrata("MEDIUM")
  f:SetWidth(6 * SIZE + 5 * GAP + 8)
  f:SetHeight(SIZE + 8)
  f:SetPoint("TOP", UIParent, "TOP", 0, -120)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  CreateBackdrop(f, nil, true)
  f:Hide()

  local function DragStart(frame)
    if S.lock == "1" then return end
    frame:SetMovable(true)
    pfUI.api.DragStart(frame)
    frame.moving = true
  end
  local function DragStop(frame)
    if not frame.moving then return end
    pfUI.api.DragStop(frame)
    frame.moving = nil
    SaveMovable(frame)
  end
  f:SetScript("OnDragStart", function() DragStart(this) end)
  f:SetScript("OnDragStop", function() DragStop(this) end)

  -- the mark waiting for a click on the ground
  MB.armed = nil
  local function Paint()
    for i, b in ipairs(MB.buttons) do
      if MB.armed == i then b.glow:Show() else b.glow:Hide() end
    end
  end
  function MB.Arm(i)
    if MB.armed == i then MB.armed = nil else MB.armed = i end
    Paint()
  end

  MB.buttons = {}
  local function Button(i, x)
    local b = CreateFrame("Button", nil, f)
    b:SetWidth(SIZE)
    b:SetHeight(SIZE)
    b:SetPoint("LEFT", f, "LEFT", x, 0)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function() DragStart(f) end)
    b:SetScript("OnDragStop", function() DragStop(f) end)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.glow = b:CreateTexture(nil, "OVERLAY")
    b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.glow:SetBlendMode("ADD")
    b.glow:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.glow:SetWidth(SIZE * 1.8)
    b.glow:SetHeight(SIZE * 1.8)
    b.glow:Hide()
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(b)
    return b
  end

  for i, m in ipairs(MB.MARKS) do
    local b = Button(i, 4 + (i - 1) * (SIZE + GAP))
    local cell = m[2] - 1
    local cx, cy = math.mod(cell, 4) * .25, math.floor(cell / 4) * .25
    b.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    b.icon:SetTexCoord(cx, cx + .25, cy, cy + .25)
    b.glow:SetVertexColor(m[3], m[4], m[5])
    b.id = i
    b:SetScript("OnClick", function()
      if IsShiftKeyDown() then MB.Clear(this.id) MB.armed = nil Paint()
      elseif arg1 == "RightButton" then MB.Arm(this.id)
      else MB.armed = nil Paint() MB.Place(this.id, "player") end
    end)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
      local mm = MB.MARKS[this.id]
      GameTooltip:AddLine(mm[1], mm[3], mm[4], mm[5])
      GameTooltip:AddLine("Left-click: on you", 1, 1, 1)
      GameTooltip:AddLine("Right-click: then click the ground to put it there", 1, 1, 1)
      GameTooltip:AddLine("Shift-click: remove it", 1, 1, 1)
      if S.lock ~= "1" then GameTooltip:AddLine("Drag: move the bar", .6, .6, .6) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    MB.buttons[i] = b
  end

  local clear = Button(6, 4 + 5 * (SIZE + GAP))
  clear.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
  clear:SetScript("OnClick", function() MB.armed = nil Paint() MB.Clear() end)
  clear:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Remove all markers")
    GameTooltip:Show()
  end)
  clear:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- an armed mark goes where the next left-click on the world lands: the
  -- world frame's own mouse-down script, chained
  local oldDown = WorldFrame:GetScript("OnMouseDown")
  WorldFrame:SetScript("OnMouseDown", function()
    if MB.armed and arg1 == "LeftButton" then
      local i = MB.armed
      MB.armed = nil
      Paint()
      MB.Place(i)
    end
    if oldDown then oldDown() end
  end)

  function MB.Apply()
    if S.bar == "1" and MB.Available() then f:Show() else f:Hide() MB.armed = nil Paint() end
  end

  UpdateMovable(f)
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", function() MB.Apply() end)
  MB.Apply()
end)
