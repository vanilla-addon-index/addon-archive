local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API
local hooksecurefunc = ShaguTweaks.hooksecurefunc
local S = { states = {} }

local Unlocked = ShaguTweaks.API.AreMoveModifiersDown

function S.IsMoved(name)
  return S.positions and S.positions[name] ~= nil
end

local function Apply(state)
  local position = S.positions[state.name]
  if not position then return end
  state.clear(state.frame)
  state.point(state.frame, "TOPLEFT", UIParent, "BOTTOMLEFT", position[1], position[2])
end

local function Layout()
  if _G.UIParent_ManageFramePositions then _G.UIParent_ManageFramePositions() end
  if _G.ReputationWatchBar_Update then _G.ReputationWatchBar_Update() end
end

-- Detect anchor chains as well as parent chains. Pin attached, movable bars
-- before moving their owner so moving one does not drag the others with it.
local function DependsOn(frame, owner, depth)
  if not frame or frame == UIParent or depth > 12 then return false end
  if frame == owner then return true end
  if frame.GetParent and DependsOn(frame:GetParent(), owner, depth + 1) then return true end
  if frame.GetPoint then
    local count = frame.GetNumPoints and frame:GetNumPoints() or 1
    for i = 1, count do
      local point, relative = frame:GetPoint(i)
      if type(relative) == "string" then relative = _G[relative] end
      if point and relative and DependsOn(relative, owner, depth + 1) then return true end
    end
  end
  return false
end

local function PinDependents(owner)
  for _, state in ipairs(S.states) do
    if state ~= owner and not S.positions[state.name] and DependsOn(state.frame, owner.frame, 0) then
      local x, y = state.frame:GetLeft(), state.frame:GetTop()
      if x and y then S.positions[state.name] = { x, y }; Apply(state) end
    end
  end
end

-- Capture native neighbour offsets before applying any saved positions.
-- Keeping the entire offset preserves intentional insets as well as gaps
-- (the pet/stance buttons do not start at the main frame's left edge).
local function CaptureSnapOffsets()
  for _, state in ipairs(S.states) do
    state.snapOffsets = {}
    local frame = state.frame
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = frame:GetLeft(), frame:GetTop()
    if x and y then
      x, y = x * scale, y * scale
      for _, other in ipairs(S.states) do
        if other ~= state then
          local target = other.frame
          local targetScale = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
          local tx, ty = target:GetLeft(), target:GetTop()
          if tx and ty then
            local dx, dy = x - tx * targetScale, y - ty * targetScale
            local width = math.max(frame:GetWidth() * scale, target:GetWidth() * targetScale)
            local height = math.max(frame:GetHeight() * scale, target:GetHeight() * targetScale)
            if math.abs(dx) <= width + 20 and math.abs(dy) <= height + 20 then
              table.insert(state.snapOffsets, { target = other, x = dx, y = dy })
            end
          end
        end
      end
    end
  end
end

local function SnapTargetVisible(state)
  local frame = state.frame
  if not frame:IsVisible() then return false end
  local parent = frame
  while parent do
    if parent.GetAlpha and parent:GetAlpha() == 0 then return false end
    parent = parent:GetParent()
  end
  if state.name == "MainMenuExpBar" then
    -- The container can remain shown at the level cap without an XP bar.
    if _G.UnitLevel and UnitLevel("player") >= (_G.MAX_PLAYER_LEVEL or 60) then return false end
  elseif state.name == "ReputationWatchBar" then
    if not _G.GetWatchedFactionInfo or not GetWatchedFactionInfo() then return false end
    local status = _G.ReputationWatchStatusBar
    if not status or not status:IsVisible() or (status.GetAlpha and status:GetAlpha() == 0) then return false end
  end
  return true
end

local function ButtonBounds(state)
  local first, last = _G[state.first or ""], _G[state.last or ""]
  if state.name == "MainMenuBar" and _G.BonusActionBarFrame and BonusActionBarFrame:IsVisible() then
    first, last = _G.BonusActionButton1, _G.BonusActionButton12
  end
  if not first or not last then return end
  local l, t, r, b = first:GetLeft(), first:GetTop(), last:GetRight(), last:GetBottom()
  if not l or not t or not r or not b then return end
  local a = first:GetEffectiveScale() / UIParent:GetEffectiveScale()
  local z = last:GetEffectiveScale() / UIParent:GetEffectiveScale()
  return l * a, t * a, r * z, b * z
end

local function MainActionPair(a, b)
  return not a.progress and not b.progress
    and (a.name == "MainMenuBar" or b.name == "MainMenuBar")
end

local function ExtraActionPair(a, b)
  return (a.extra or b.extra) and a.first and b.first
    and (not a.vertical) == (not b.vertical)
end

function S.Snap(state, x, y)
  local scale = state.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
  local px, py = x * scale, y * scale
  local best, resultX, resultY = 289, x, y
  for _, offset in ipairs(state.snapOffsets) do
    local target = offset.target.frame
    if not MainActionPair(state, offset.target) and not (state.extra or offset.target.extra)
      and SnapTargetVisible(offset.target) then
      local targetScale = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
      local tx, ty = target:GetLeft(), target:GetTop()
      if tx and ty then
        tx, ty = tx * targetScale + offset.x, ty * targetScale + offset.y
        local dx, dy = tx - px, ty - py
        local distance = dx * dx + dy * dy
        if math.abs(dx) <= 12 and math.abs(dy) <= 12 and distance < best then
          best, resultX, resultY = distance, tx / scale, ty / scale
        end
      end
    end
  end
  -- MainMenuBar's native rectangle contains unused artwork. Its old frame
  -- offsets must never determine the visible gap between action-button rows.
  local l, t, r, b = ButtonBounds(state)
  if l then
    local ox = l - state.frame:GetLeft() * scale
    local oy = t - state.frame:GetTop() * scale
    local height = t - b
    local gap = 6 * scale
    if _G.ActionButton1 and _G.ActionButton2 then
      local right, left = ActionButton1:GetRight(), ActionButton2:GetLeft()
      if right and left then
        local measured = left * ActionButton2:GetEffectiveScale() / UIParent:GetEffectiveScale()
          - right * ActionButton1:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if measured >= 0 and measured <= 20 then gap = measured end
      end
    end
    for _, other in ipairs(S.states) do
      local adjacent = ExtraActionPair(state, other)
        or (not (state.extra or other.extra) and MainActionPair(state, other))
      if other ~= state and adjacent and SnapTargetVisible(other) then
        local tl, tt, tr, tb = ButtonBounds(other)
        if tl then
          local width = r - l
          for side = 1, 2 do
            local tx, ty = tl - ox, tt - oy
            if state.extra and state.vertical or other.extra and other.vertical then
              tx = (side == 1 and tl - gap - width or tr + gap) - ox
            else
              ty = (side == 1 and tb - gap or tt + gap + height) - oy
            end
            local dx, dy = tx - px, ty - py
            local distance = dx * dx + dy * dy
            if math.abs(dx) <= 12 and math.abs(dy) <= 12 and distance < best then
              best, resultX, resultY = distance, tx / scale, ty / scale
            end
          end
        end
      end
    end
  end
  return resultX, resultY
end

local function Finish(save)
  local state = S.dragging
  if not state then return end
  S.dragging = nil
  S.outline:StopMovingOrSizing()
  local x, y = S.outline:GetLeft(), S.outline:GetTop()
  S.outline:Hide()
  if save and x and y then
    x, y = S.Snap(state, x - state.dragOffsetX, y - state.dragOffsetY)
    PinDependents(state)
    S.positions[state.name] = { x, y }
    Apply(state)
    -- Positions are stored in addon settings; native bars need not be movable.
    Layout()
  end
end

local function Reset(state)
  Finish(false)
  S.positions[state.name] = nil
  state.clear(state.frame)
  for _, point in ipairs(state.defaults) do state.point(state.frame, unpack(point)) end

  Layout()
end

local function Begin()
  if not Unlocked() then return end
  Finish(true)
  local state = this.state
  local x, y = state.frame:GetLeft(), state.frame:GetTop()
  if not x or not y then return end
  local left, top = x, y
  local width, height = state.frame:GetWidth(), math.max(state.frame:GetHeight(), 14)
  -- Main and pet frames include artwork beyond the visible button row.
  -- Read button edges directly; anchored marker dimensions are not reliable
  -- on every supported client.
  if state.name == "MainMenuBar" or state.name == "PetActionBarFrame" then
    local first, last = _G.ActionButton1, _G.ActionButton12
    if state.name == "PetActionBarFrame" then
      first, last = _G.PetActionButton1, _G.PetActionButton10
    elseif _G.BonusActionBarFrame and BonusActionBarFrame:IsVisible() then
      first, last = _G.BonusActionButton1, _G.BonusActionButton12
    end
    if first and last then
      local scale = first:GetEffectiveScale() / state.frame:GetEffectiveScale()
      local lastScale = last:GetEffectiveScale() / state.frame:GetEffectiveScale()
      local l, t, r, b = first:GetLeft(), first:GetTop(), last:GetRight(), last:GetBottom()
      if l and t and r and b then
        left, top = l * scale - 2, t * scale + 2
        width, height = r * lastScale + 2 - left, top - b * lastScale + 2
      end
    end
  end
  state.dragOffsetX, state.dragOffsetY = left - x, top - y
  S.dragging = state
  local outline = S.outline
  outline:SetScale(state.frame:GetEffectiveScale() / UIParent:GetEffectiveScale())
  outline:SetWidth(width)
  outline:SetHeight(height)
  outline:ClearAllPoints()
  outline:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
  outline:Show()
  outline:StartMoving()
end

local function MarkerClick()
  if Unlocked() and arg1 == "RightButton" then Reset(this.state) end
end

local function UpdateMarkers()
  local unlocked = Unlocked()
  if not unlocked then Finish(true) end
  for _, state in ipairs(S.states) do
    local controller = state.frame.ShaguTweaksMouseoverController
    local visible = state.progress or state.frame:IsVisible() or (controller and controller.enabled)
    if unlocked and visible then
      -- Follow actual button bounds; the main frame also includes gryphons
      -- and XP artwork outside its clickable action-button row.
      local first = state.first and _G[state.first]
      local last = state.last and _G[state.last]
      if state.name == "MainMenuBar" and _G.BonusActionBarFrame and BonusActionBarFrame:IsVisible() then
        first, last = _G.BonusActionButton1, _G.BonusActionButton12
      elseif state.name == "ShapeshiftBarFrame" and type(_G.GetNumShapeshiftForms) == "function" then
        first, last = _G.ShapeshiftButton1, _G["ShapeshiftButton" .. GetNumShapeshiftForms()]
      end
      state.marker:ClearAllPoints()
      if first and last then
        state.marker:SetPoint("TOPLEFT", first, "TOPLEFT", -2, 2)
        state.marker:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 2, -2)
      elseif state.progress then
        local anchor = state.name == "MainMenuExpBar" and "TOPLEFT" or "BOTTOMLEFT"
        state.marker:SetPoint(anchor, state.frame, anchor, 0, 0)
        state.marker:SetWidth(state.frame:GetWidth())
        state.marker:SetHeight(14)
      else
        state.marker:SetAllPoints(state.frame)
      end
      state.marker:Show()
    else
      if S.dragging == state then Finish(true) end
      state.marker:Hide()
    end
  end
end

local function MarkerStyle(marker)
  marker:SetFrameStrata("DIALOG")
  marker:SetFrameLevel(100)
  marker:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8,
    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  marker:SetBackdropColor(0, 0, 0, .7)
  local color = ShaguTweaks.UIBorder
  marker:SetBackdropBorderColor(color and color.r or 1, color and color.g or .82, color and color.b or 0, 1)
end

local function Add(definition)
  local frame = _G[definition[1]]
  if not frame then return end
  local state = { name = definition[1], frame = frame, defaults = {}, first = definition[3],
    last = definition[4], progress = definition[5], vertical = definition[6], extra = definition[7],
    point = frame.SetPoint, clear = frame.ClearAllPoints }
  for i = 1, (frame.GetNumPoints and frame:GetNumPoints() or 1) do
    local p, relative, rp, x, y = frame:GetPoint(i)
    if p then table.insert(state.defaults, { p, relative or UIParent, rp or p, x or 0, y or 0 }) end
  end
  -- Guard BOTH operations: ignoring SetPoint alone would let a preceding
  -- ClearAllPoints detach a manually positioned bar during native relayout.
  frame.ClearAllPoints = function(self)
    if S.positions[state.name] then return end
    state.clear(self)
  end
  frame.SetPoint = function(self, a, b, c, d, e)
    if S.positions[state.name] then return end
    state.point(self, a, b, c, d, e)
  end
  local marker = CreateFrame("Button", "ShaguTweaksMover" .. state.name, UIParent)
  MarkerStyle(marker)
  marker:SetScale(frame:GetEffectiveScale() / UIParent:GetEffectiveScale())
  marker:EnableMouse(true)
  marker:RegisterForDrag("LeftButton")
  marker:RegisterForClicks("RightButtonUp")
  marker.state = state
  marker:SetScript("OnDragStart", Begin)
  marker:SetScript("OnDragStop", function() Finish(true) end)
  marker:SetScript("OnClick", MarkerClick)
  marker:SetScript("OnHide", function() if S.dragging == this.state then Finish(true) end end)
  marker.text = marker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  marker.text:SetPoint("CENTER", marker, "CENTER", 0, 0)
  marker.text:SetText(T[definition[2]])
  marker:Hide()
  state.marker = marker
  table.insert(S.states, state)
  ShaguTweaks.HookScript(frame, "OnShow", UpdateMarkers)
  ShaguTweaks.HookScript(frame, "OnHide", UpdateMarkers)
end

local function Setup()
  if S.installed then return end
  S.installed = true
  ShaguTweaks_config.ActionBarPositions = ShaguTweaks_config.ActionBarPositions or {}
  S.positions = ShaguTweaks_config.ActionBarPositions
  ShaguTweaks.ActionBarMovers = S
  S.outline = CreateFrame("Frame", "ShaguTweaksActionBarDragOutline", UIParent)
  MarkerStyle(S.outline)
  S.outline:SetMovable(true)
  S.outline:SetClampedToScreen(true)
  S.outline:SetScript("OnHide", function() if S.dragging then Finish(true) end end)
  S.outline:Hide()
  if S.actions then
    local definitions = {
      { "MainMenuBar", "Main Action Bar", "ActionButton1", "ActionButton12" },
      { "MultiBarBottomLeft", "Bottom Left Bar", "MultiBarBottomLeftButton1", "MultiBarBottomLeftButton12" },
      { "MultiBarBottomRight", "Bottom Right Bar", "MultiBarBottomRightButton1", "MultiBarBottomRightButton12" },
      { "MultiBarRight", "Right Bar", "MultiBarRightButton1", "MultiBarRightButton12", nil, true },
      { "MultiBarLeft", "Right Bar 2", "MultiBarLeftButton1", "MultiBarLeftButton12", nil, true },
      { "PetActionBarFrame", "Pet Action Bar", "PetActionButton1", "PetActionButton10" },
      { "ShapeshiftBarFrame", "Stance Bar" },
      { "ShaguTweaksExtraActionBar6", "Action Bar 6", "ShaguTweaksExtraActionBar6Button1", "ShaguTweaksExtraActionBar6Button12", nil, false, true },
      { "ShaguTweaksExtraActionBar7", "Action Bar 7", "ShaguTweaksExtraActionBar7Button1", "ShaguTweaksExtraActionBar7Button12", nil, true, true },
    }
    for _, definition in ipairs(definitions) do Add(definition) end
  end
  if S.progress then
    Add({ "MainMenuExpBar", "Experience Bar", nil, nil, true })
    Add({ "ReputationWatchBar", "Reputation Bar", nil, nil, true })
  end
  CaptureSnapOffsets()
  for _, state in ipairs(S.states) do Apply(state) end
  S.events = CreateFrame("Frame")
  S.events:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
      for _, state in ipairs(S.states) do Apply(state) end
    end
    UpdateMarkers()
  end)
  S.events:RegisterEvent("PLAYER_ENTERING_WORLD")
  if API.modifierstate then
    S.events:RegisterEvent("MODIFIER_STATE_CHANGED")
  else
    S.events.elapsed = 0
    S.events:SetScript("OnUpdate", function()
      this.elapsed = this.elapsed + (arg1 or 0)
      if this.elapsed < .1 then return end
      this.elapsed = 0
      UpdateMarkers()
    end)
  end
  UpdateMarkers()
end

local function Schedule()
  if S.scheduled then return end
  S.scheduled = true
  API.AfterWorldReady(Setup)
end

local function ReducedEnabled()
  local enabled = ShaguTweaks_config[T["Reduced Actionbar Size"]]
  if enabled == nil then
    local reduced = ShaguTweaks.mods[T["Reduced Actionbar Size"]]
    enabled = reduced and reduced.enabled and 1 or 0
  end
  return enabled == 1
end

ShaguTweaks.EnableActionBarMovers = function()
  if not ReducedEnabled() then return end
  S.actions = true
  S.progress = true
  Schedule()
end
