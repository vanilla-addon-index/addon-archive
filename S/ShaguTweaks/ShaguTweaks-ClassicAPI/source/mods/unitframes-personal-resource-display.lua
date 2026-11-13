local T = ShaguTweaks.T
local API = ShaguTweaks.API
local module = ShaguTweaks:register({
  title = T["Personal Resource Display"],
  description = T["Adds independent copies of your health and power bars without changing the player frame. Hold Ctrl+Shift+Alt to drag a bar or its bottom-right resize grip; right-click a bar with those keys held to reset it."],
  expansions = { ["vanilla"] = true }, category = T["Unit Frames"], enabled = nil,
})
local border = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 12, tile = true, tileSize = 8,
  insets = { left = 3, right = 3, top = 3, bottom = 3 } }
local function Position(state, saved)
  local point = saved or state.default
  state.frame:ClearAllPoints()
  state.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", point.x, point.y)
  state.frame:SetWidth(point.width or state.default.width)
  state.frame:SetHeight(point.height or state.default.height)
end
local function Finish(state)
  if not state.dragging then return end
  state.frame:StopMovingOrSizing()
  state.frame:SetUserPlaced(false)
  state.dragging = nil
  local x, y = state.frame:GetLeft(), state.frame:GetTop()
  if x and y then
    state.positions[state.key] = { x = x, y = y,
      width = state.frame:GetWidth(), height = state.frame:GetHeight() }
    Position(state, state.positions[state.key])
  end
end
local function Begin()
  if not API.AreMoveModifiersDown() then return end
  local state = this.resourceState
  state.dragging = true
  if this == state.grip then state.frame:StartSizing("BOTTOMRIGHT")
  else state.frame:StartMoving() end
end
local function Stop() Finish(this.resourceState) end
local function MouseDown()
  if arg1 ~= "RightButton" or not API.AreMoveModifiersDown() then return end
  local state = this.resourceState
  Finish(state)
  state.positions[state.key] = nil
  Position(state)
end
module.enable = function(self)
  if self.scheduled then return end
  self.scheduled = true
  local function Setup()
    if self.states then return end
    self.states = {}
    ShaguTweaks_config.PersonalResourceDisplay = ShaguTweaks_config.PersonalResourceDisplay or {}
    local positions = ShaguTweaks_config.PersonalResourceDisplay
    local scale = PlayerFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local big = ShaguTweaks_config[T["Unit Frame Big Health for Player"]] == 1
    local width = PlayerFrameHealthBar:GetWidth() + 8
    local healthHeight = PlayerFrameHealthBar:GetHeight() + 6
    local powerHeight = big and healthHeight or PlayerFrameManaBar:GetHeight() + 6
    local x, y = UIParent:GetWidth() / scale / 2 - width / 2,
      UIParent:GetHeight() / scale / 2 - 120
    local function Add(key, source, height, top, attachedTo)
      local frame = CreateFrame("Frame", "ShaguTweaksResource" .. key, UIParent)
      frame:SetScale(scale)
      frame:SetFrameStrata(PlayerFrame:GetFrameStrata())
      frame:SetFrameLevel(PlayerFrame:GetFrameLevel() + 3)
      frame:SetMovable(true); frame:SetResizable(true); frame:SetClampedToScreen(true)
      frame:SetMinResize(64, 18); frame:SetMaxResize(600, 160)
      frame:SetBackdrop(border)
      local color = ShaguTweaks.UIBorder
      frame:SetBackdropBorderColor(color and color.r or 1, color and color.g or 1, color and color.b or 1, 1)
      local state = { frame = frame, key = key, positions = positions,
        default = { x = x, y = top, width = width, height = height } }
      if not attachedTo then table.insert(self.states, state) end
      frame.resourceState = state
      Position(state, positions[key])
      local bar = CreateFrame("StatusBar", nil, frame)
      frame.bar = bar
      bar.unit = "player"
      bar.personalResourceDisplay = true
      bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -3)
      -- Update dimensions explicitly: anchored-child size notifications can
      -- precede resolved geometry while the holder is being resized.
      local function ResizeBar()
        bar:SetWidth(math.max(1, frame:GetWidth() - 8))
        bar:SetHeight(math.max(1, frame:GetHeight() - 6))
      end
      frame:SetScript("OnSizeChanged", ResizeBar)
      ResizeBar()
      local background = bar:CreateTexture(nil, "BACKGROUND")
      background:SetTexture(0, 0, 0, .5); background:SetAllPoints(bar)
      local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      text:SetPoint(key == "Health" and "RIGHT" or "CENTER", bar,
        key == "Health" and "RIGHT" or "CENTER", key == "Health" and -4 or 0, 0)
      local percent
      if key == "Health" then
        percent = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        percent:SetPoint("LEFT", bar, "LEFT", 4, 0)
      end
      local function TextureAppearance()
        local texture = source:GetStatusBarTexture()
        local path = texture and texture:GetTexture() or "Interface\\TargetingFrame\\UI-StatusBar"
        if state.texturePath ~= path then
          state.texturePath = path
          bar:SetStatusBarTexture(path)
        end
      end
      local function ColorAppearance()
        local r, g, b = source:GetStatusBarColor()
        if state.r ~= r or state.g ~= g or state.b ~= b then
          state.r, state.g, state.b = r, g, b
          bar:SetStatusBarColor(r, g, b, 1)
        end
      end
      local function Values()
        local minimum, maximum = source:GetMinMaxValues()
        local value = source:GetValue() or 0
        maximum = maximum or 0
        minimum = minimum or 0
        local rangeChanged = state.minimum ~= minimum or state.maximum ~= maximum
        if rangeChanged then
          state.minimum = minimum
          bar:SetMinMaxValues(minimum, maximum > 0 and maximum or 1)
        end
        if rangeChanged or state.value ~= value then bar:SetValue(value) end
        if value ~= state.value or maximum ~= state.maximum then
          state.value, state.maximum = value, maximum
          text:SetText(ShaguTweaks.Abbreviate(value))
          if percent then percent:SetText((maximum > 0 and math.floor(value / maximum * 100 + .5) or 0) .. "%") end
        end
      end
      ShaguTweaks.hooksecurefunc(source, "SetValue", Values)
      ShaguTweaks.hooksecurefunc(source, "SetMinMaxValues", Values)
      ShaguTweaks.hooksecurefunc(source, "SetStatusBarColor", ColorAppearance)
      ShaguTweaks.hooksecurefunc(source, "SetStatusBarTexture", function()
        TextureAppearance(); ColorAppearance()
      end)
      TextureAppearance(); ColorAppearance(); Values()
      if attachedTo then
        frame:SetParent(attachedTo)
        frame:SetScale(1)
        frame:ClearAllPoints()
        -- Overlap the tooltip rims so the secondary bar joins the power bar.
        frame:SetPoint("TOP", attachedTo, "BOTTOM", 0, 5)
        -- Keep both the secondary rim and its fill behind the main rim.
        frame:SetFrameLevel(math.max(0, attachedTo:GetFrameLevel() - 2))
        bar:SetFrameLevel(frame:GetFrameLevel() + 1)
        local function ResizeAttached()
          frame:SetWidth(attachedTo:GetWidth() * .6)
          ResizeBar()
        end
        ShaguTweaks.HookScript(attachedTo, "OnSizeChanged", ResizeAttached)
        ResizeAttached()
        return frame
      end
      frame:RegisterForDrag("LeftButton")
      frame:SetScript("OnDragStart", Begin); frame:SetScript("OnDragStop", Stop)
      frame:SetScript("OnMouseDown", MouseDown)
      frame:SetScript("OnHide", Stop)
      local grip = CreateFrame("Button", nil, frame)
      state.grip, grip.resourceState = grip, state
      grip:SetWidth(12); grip:SetHeight(12); grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
      grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
      grip:RegisterForDrag("LeftButton")
      grip:SetScript("OnDragStart", Begin); grip:SetScript("OnDragStop", Stop)
      grip:SetScript("OnHide", Stop)
      return frame
    end
    local health = Add("Health", PlayerFrameHealthBar, healthHeight, y)
    local power = Add("Power", PlayerFrameManaBar, powerHeight, y - healthHeight - 2)
    ShaguTweaks.PersonalResourceDisplay = { health = health, power = power }
    local _, class = UnitClass("player")
    local manaSource = PlayerFrameAlternatePowerBar
    if class == "DRUID" and manaSource then
      local mana = Add("Mana", manaSource, 18, 0, power)
      ShaguTweaks.PersonalResourceDisplay.mana = mana
      if ShaguTweaks.RegisterDruidManaTickBar then ShaguTweaks.RegisterDruidManaTickBar(mana.bar, manaSource) end
      local function ManaVisibility()
        if UnitPowerType("player") ~= 0 and manaSource:IsShown() then mana:Show()
        else mana:Hide() end
      end
      ShaguTweaks.hooksecurefunc(manaSource, "Show", ManaVisibility)
      ShaguTweaks.hooksecurefunc(manaSource, "Hide", ManaVisibility)
      ShaguTweaks.hooksecurefunc(manaSource, "SetValue", ManaVisibility)
      ManaVisibility()
    end
    if ShaguTweaks.RegisterResourceTickBar then ShaguTweaks.RegisterResourceTickBar(power.bar) end
    if ShaguTweaks.RegisterHealingPredictionBar then
      ShaguTweaks.RegisterHealingPredictionBar("player", health.bar)
    end
    local function UpdateHandles()
      local unlocked = API.AreMoveModifiersDown()
      for _, state in ipairs(self.states) do
        if not unlocked then Finish(state) end
        state.frame:EnableMouse(unlocked)
        if unlocked then state.grip:Show() else state.grip:Hide() end
      end
    end
    local events = CreateFrame("Frame")
    self.events = events
    if API.modifierstate then
      events:RegisterEvent("MODIFIER_STATE_CHANGED")
      events:SetScript("OnEvent", UpdateHandles)
    else
      events.elapsed = 0
      events:SetScript("OnUpdate", function()
        events.elapsed = events.elapsed + (arg1 or 0)
        if events.elapsed >= .1 then events.elapsed = 0; UpdateHandles() end
      end)
    end
    UpdateHandles()
  end
  API.AfterWorldReady(Setup, true)
end
