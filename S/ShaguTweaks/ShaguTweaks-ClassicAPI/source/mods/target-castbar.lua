local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

-- These legacy wrappers are kept only as a reader for SuperWoW's GUID-keyed
-- libcast cache. Real unit-token cast discovery is ClassicAPI-only below.
local SuperWoWCastingInfo = ShaguTweaks.UnitCastingInfo
local SuperWoWChannelInfo = ShaguTweaks.UnitChannelInfo

local module = ShaguTweaks:register({
  title = T["Enemy Castbars"],
  description = T["Shows an enemy castbar on target unit frame. Hold <Ctrl>, <Shift> and <Alt> to move it; right-click to reset."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = true,
})

local castbar = CreateFrame("StatusBar", "ShaguTargetCastbar", TargetFrame)
castbar:SetPoint("BOTTOM", TargetFrame, "BOTTOM", -12, -4)
castbar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
castbar:SetStatusBarColor(1, .8, 0, 1)
castbar:SetWidth(140)
castbar:SetHeight(10)
castbar:Hide()

castbar.texture = CreateFrame("Frame", nil, castbar)
castbar.texture:SetPoint("RIGHT", castbar, "LEFT", -2, 0)
castbar.texture:SetHeight(20)
castbar.texture:SetWidth(20)

castbar.texture.icon = castbar.texture:CreateTexture(nil, "BACKGROUND")
castbar.texture.icon:SetPoint("CENTER", 0, 0)
castbar.texture.icon:SetWidth(16)
castbar.texture.icon:SetHeight(16)
castbar.texture:SetBackdrop({
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
})

castbar.bg = castbar:CreateTexture(nil, "BACKGROUND")
castbar.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
castbar.bg:SetVertexColor(.1, .1, 0, .8)
castbar.bg:SetAllPoints(true)

castbar.spark = castbar:CreateTexture(nil, "OVERLAY")
castbar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
castbar.spark:SetWidth(20)
castbar.spark:SetHeight(20)
castbar.spark:SetBlendMode("ADD")

castbar.backdrop = CreateFrame("Frame", nil, castbar)
castbar.backdrop:SetFrameStrata("BACKGROUND")
castbar.backdrop:SetPoint("TOPLEFT", castbar, "TOPLEFT", -3, 3)
castbar.backdrop:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", 3, -3)
castbar.backdrop:SetBackdrop({
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
})

castbar.text = castbar:CreateFontString(nil, "HIGH", "GameFontWhite")
castbar.text:SetPoint("CENTER", castbar, "CENTER", 0, 0)
local font, size = castbar.text:GetFont()
castbar.text:SetFont(font, size - 2, "THINOUTLINE")

local function QuerySuperWoW(guid, channelSpellID, hasChannel)
  if not guid then return end

  local cached = ShaguTweaks.libcast.db[guid]
  if not cached then return end

  if cached.channel then
    if not hasChannel or cached.spellID ~= channelSpellID then return end

    local channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill = SuperWoWChannelInfo(guid)
    if channel then
      return channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill, true
    end
    return
  end

  local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill = SuperWoWCastingInfo(guid)
  if cast then
    return cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill, false
  end
end

local function QueryCast(unit)
  if not unit then return end

  -- ClassicAPI is authoritative for real unit tokens and provides exact
  -- engine/server timing. A nil result for an existing unit means that exact
  -- GUID is not casting; never fall back to the legacy name-keyed database.
  local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill = API.GetCastInfo(unit)
  if cast then
    return cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill, false
  end

  local channel, notInterruptible, channelSpellID, hasChannel
  channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill,
    notInterruptible, channelSpellID, hasChannel = API.GetChannelInfo(unit)
  if channel then
    return channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill, true
  end

  -- SuperWoW remains an optional GUID-keyed complement for remote casts.
  -- Channels additionally require ClassicAPI's authoritative live state and
  -- matching spellID, preventing a stale cached channel from becoming a ghost bar.
  if ShaguTweaks.superwow_active and not UnitIsUnit(unit, "player") then
    local guid = API.UnitGUID and API.UnitGUID(unit)
    if guid then
      local a, b, c, d, e, f, g, h = QuerySuperWoW(guid, channelSpellID, hasChannel)
      if a then return a, b, c, d, e, f, g, h end
    end
  end
end

local POSITION_KEY = "TargetCastBarPosition"

-- Offset of the bar from the bottom of the target frame: the saved spot, or
-- the default that moves below the target of target and the buff rows.
local function GetOffsets()
  local pos = ShaguTweaks_config and ShaguTweaks_config[POSITION_KEY]
  if pos and pos[1] and pos[2] then return pos[1], pos[2] end

  local targetOfTarget = TargetofTargetFrame and TargetofTargetFrame:IsShown()
  local debuff11 = TargetFrameDebuff11 and TargetFrameDebuff11:IsShown()
  local debuff7 = TargetFrameDebuff7 and TargetFrameDebuff7:IsShown()
  local buff1 = TargetFrameBuff1 and TargetFrameBuff1:IsShown()

  local y = -4
  if targetOfTarget then
    y = -24
    if debuff11 then
      y = -45
      if buff1 then
        y = -65
      end
    end
  elseif debuff7 then
    y = -24
  end

  return -12, y
end

local function UpdatePosition()
  local x, y = GetOffsets()

  -- Buff/debuff rows usually remain unchanged for the whole cast. Keep checking
  -- their cheap visibility state while animating, but only touch the frame
  -- anchors when the required position actually changes.
  if castbar.positionY == y and castbar.positionX == x then return end
  castbar.positionX = x
  castbar.positionY = y
  castbar:ClearAllPoints()
  castbar:SetPoint("BOTTOM", TargetFrame, "BOTTOM", x, y)
end

local function HideCast()
  if castbar.expiry then castbar.expiry:Cancel(); castbar.expiry = nil end
  if castbar.nativeProgress then castbar:SetMinMaxValues(0, 1) end
  castbar.startTime = nil
  castbar.endTime = nil
  castbar.isChannel = nil
  castbar:Hide()
end

local function ExpireCast()
  castbar.expiry = nil
  HideCast()
end

local function UpdateProgress()
  local startTime = castbar.startTime
  local endTime = castbar.endTime
  if not startTime or not endTime or endTime <= startTime then
    HideCast()
    return
  end

  local now = GetTime()
  local max = endTime - startTime
  if now >= endTime then
    HideCast()
    return
  end

  local cur
  if castbar.isChannel then
    cur = endTime - now
  else
    cur = now - startTime
  end

  cur = cur > max and max or cur
  cur = cur < 0 and 0 or cur

  castbar:SetValue(cur)

  local percent = max > 0 and cur / max or 0
  local x = castbar:GetWidth() * percent
  castbar.spark:ClearAllPoints()
  castbar.spark:SetPoint("CENTER", castbar, "LEFT", x, 0)

  -- The target frame can move its buff/debuff rows while a cast is active.
  UpdatePosition()
end

local function RefreshCast()
  if not UnitExists("target") then
    HideCast()
    return
  end

  local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill, isChannel = QueryCast("target")
  if not cast or not startTime or not endTime or endTime <= startTime then
    HideCast()
    return
  end

  castbar.startTime = startTime / 1000
  castbar.endTime = endTime / 1000
  castbar.isChannel = isChannel
  if castbar.endTime <= GetTime() then HideCast(); return end

  local max = castbar.endTime - castbar.startTime
  castbar:SetMinMaxValues(0, max)
  castbar.text:SetText(cast)

  if texture then
    castbar.texture.icon:SetTexture(texture)
    castbar.texture.icon:Show()
  else
    castbar.texture.icon:Hide()
  end

  UpdatePosition()
  castbar:Show()
  if castbar.nativeProgress then
    if castbar.expiry then castbar.expiry:Cancel() end
    local duration
    duration, castbar.fallbackDuration = API.GetCastDuration("target", isChannel,
      castbar.startTime, castbar.endTime, castbar.fallbackDuration)
    castbar:SetTimerDuration(duration, _G.Enum.StatusBarInterpolation.Immediate,
      isChannel and _G.Enum.StatusBarTimerDirection.RemainingTime or _G.Enum.StatusBarTimerDirection.ElapsedTime)
    castbar.expiry = _G.C_Timer.NewTimer(math.max(0, castbar.endTime - GetTime()), ExpireCast)
  else
    UpdateProgress()
  end
end

-- Hold Ctrl+Shift+Alt to show a marker where the bar goes and drag it; the
-- offset from the target frame is saved, so the bar follows the frame when it
-- is moved. Right-click the marker to go back to the automatic position.
-- The marker lives on UIParent because the bar itself hides with the target frame.
local mover

local function PlaceMover()
  local x, y = GetOffsets()
  mover:SetScale(TargetFrame:GetEffectiveScale() / UIParent:GetEffectiveScale())
  mover:ClearAllPoints()
  mover:SetPoint("BOTTOM", TargetFrame, "BOTTOM", x, y)
end

local function SaveMoverPosition()
  local mx, my = mover:GetCenter()
  local tx, ty = TargetFrame:GetCenter()
  local bottom, targetBottom = mover:GetBottom(), TargetFrame:GetBottom()
  if not (mx and tx and bottom and targetBottom) then return end

  local ms, ts = mover:GetEffectiveScale(), TargetFrame:GetEffectiveScale()
  ShaguTweaks_config = ShaguTweaks_config or {}
  ShaguTweaks_config[POSITION_KEY] = { (mx * ms - tx * ts) / ms, (bottom * ms - targetBottom * ts) / ms }
end

-- Same look as the Swing Timer preview bars: the classic cast bar with its
-- border and spark, full, in the cast bar's gold, with an icon at the left.
local function CreateMover()
  local width, height = castbar:GetWidth(), castbar:GetHeight()
  local f = width / 195 -- the border and spark art is made for the 195 wide player bar

  mover = CreateFrame("StatusBar", "ShaguTweaksTargetCastBarMover", UIParent)
  mover:SetFrameStrata("DIALOG")
  mover:SetWidth(width)
  mover:SetHeight(height)
  mover:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  mover:SetStatusBarColor(1, .8, 0)
  mover:SetMinMaxValues(0, 1)
  mover:SetValue(1)
  mover:SetMovable(true)
  mover:SetClampedToScreen(true)
  mover:EnableMouse(true)
  mover:Hide()

  mover.bg = mover:CreateTexture(nil, "BACKGROUND")
  mover.bg:SetAllPoints(mover)
  mover.bg:SetTexture(0, 0, 0, .5)

  mover.border = mover:CreateTexture(nil, "OVERLAY")
  mover.border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
  mover.border:SetWidth(256 * f)
  mover.border:SetHeight(64 * f)
  mover.border:SetPoint("TOP", mover, "TOP", 0, 28 * f)

  mover.spark = mover:CreateTexture(nil, "OVERLAY")
  mover.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  mover.spark:SetBlendMode("ADD")
  mover.spark:SetWidth(32 * f)
  mover.spark:SetHeight(32 * f)
  mover.spark:SetPoint("CENTER", mover, "RIGHT", 0, 2 * f)

  mover.text = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  mover.text:SetPoint("CENTER", mover, "CENTER", 0, 2)
  local font, size = mover.text:GetFont()
  if font and size then mover.text:SetFont(font, size - 2, "THINOUTLINE") end
  mover.text:SetText(T["Enemy Castbar"])

  mover.icon = CreateFrame("Frame", nil, mover)
  mover.icon:SetPoint("RIGHT", mover, "LEFT", -2, 0)
  mover.icon:SetWidth(20)
  mover.icon:SetHeight(20)
  mover.icon:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
  })
  mover.icon.texture = mover.icon:CreateTexture(nil, "BACKGROUND")
  mover.icon.texture:SetPoint("CENTER", 0, 0)
  mover.icon.texture:SetWidth(16)
  mover.icon.texture:SetHeight(16)
  mover.icon.texture:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowBolt")
  mover.icon.texture:SetTexCoord(.08, .92, .08, .92)

  mover:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then this:StartMoving() end
  end)
  mover:SetScript("OnMouseUp", function()
    this:StopMovingOrSizing()
    if arg1 == "RightButton" then
      if ShaguTweaks_config then ShaguTweaks_config[POSITION_KEY] = nil end
    else
      SaveMoverPosition()
    end
    castbar.positionX = nil
    UpdatePosition()
    PlaceMover()
  end)
end

local function SetPreview(on)
  if (mover and mover:IsShown() and true or false) == on then return end
  if on then
    if not mover then CreateMover() end
    local tint, edge = ShaguTweaks.UITint, ShaguTweaks.UIBorder
    mover.border:SetVertexColor(tint and tint.r or 1, tint and tint.g or 1,
      tint and tint.b or 1, tint and tint.a or 1)
    mover.icon:SetBackdropBorderColor(edge and edge.r or 1, edge and edge.g or 1,
      edge and edge.b or 1, edge and edge.a or 1)
    PlaceMover()
    mover:Show()
  elseif mover then
    mover:StopMovingOrSizing()
    mover:Hide()
  end
end

local ModifiersDown = ShaguTweaks.API.AreMoveModifiersDown

module.enable = function(self)
  local castEvents = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
  }

  -- ClassicAPI is a required dependency of this fork. Do not restore the old
  -- permanent 20 Hz discovery poller when its cast/event surface is missing.
  if not API or not API.casts or not API.eventutils
    or not _G.C_EventUtils
    or type(_G.C_EventUtils.IsEventValid) ~= "function" then
    return
  end

  for index = 1, table.getn(castEvents) do
    if not _G.C_EventUtils.IsEventValid(castEvents[index]) then
      return
    end
  end

  castbar.nativeProgress = API.durationtimers and type(API.GetCastDuration) == "function"
    and type(castbar.SetTimerDuration) == "function"
    and _G.Enum.StatusBarTimerDirection.RemainingTime ~= nil
  if castbar.nativeProgress then
    castbar.spark:ClearAllPoints()
    castbar.spark:SetPoint("CENTER", castbar:GetStatusBarTexture(), "RIGHT", 0, 0)
  else
    -- Older ClassicAPI builds retain the animation-only fallback.
    castbar:SetScript("OnUpdate", UpdateProgress)
  end

  local listener = CreateFrame("Frame")
  listener:RegisterEvent("PLAYER_TARGET_CHANGED")
  listener:RegisterEvent("MODIFIER_STATE_CHANGED")

  for index = 1, table.getn(castEvents) do
    API.RegisterUnitEvent(listener, castEvents[index], "target", "player")
  end

  -- Layout changes are event-driven on the native animation path. Defer the
  -- aura pass so native/third-party buff rows finish laying themselves out.
  local positionQueued
  local function RunPositionUpdate() positionQueued = nil; UpdatePosition() end
  local function QueuePositionUpdate()
    if positionQueued or not castbar:IsShown() then return end
    positionQueued = true
    if API.timer then API.Defer(RunPositionUpdate)
    else ShaguTweaks.QueueFunction(RunPositionUpdate) end
  end
  if castbar.nativeProgress then
    API.RegisterUnitEvent(listener, "UNIT_AURA", "target")
    if TargetofTargetFrame then
      ShaguTweaks.HookScript(TargetofTargetFrame, "OnShow", QueuePositionUpdate)
      ShaguTweaks.HookScript(TargetofTargetFrame, "OnHide", QueuePositionUpdate)
    end
  end

  listener:SetScript("OnEvent", function()
    if event == "MODIFIER_STATE_CHANGED" then
      SetPreview(ModifiersDown())
      return
    end

    if event == "PLAYER_TARGET_CHANGED" then
      RefreshCast()
      return
    end
    if event == "UNIT_AURA" then QueuePositionUpdate(); return end

    -- ClassicAPI fans remote cast events out to every unit token currently
    -- resolving to the caster, including "target" when appropriate.
    if arg1 == "target" or (arg1 == "player" and UnitIsUnit("target", "player")) then
      RefreshCast()
    end
  end)

  ShaguTweaks.libcast.OnRemoteChanged = function(guid)
    if guid == API.UnitGUID("target") then RefreshCast() end
  end
  RefreshCast()
end
