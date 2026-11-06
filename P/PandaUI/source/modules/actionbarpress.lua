-- pandaUI :: modules/actionbarpress.lua
--
-- Action-button feedback, drawn the same way under every theme:
--
--   * Press styles (option pressStyle, toggle pressAnimation):
--     - "modern": the icon dips to 88% and springs back while a ring burst
--       runs round the slot edge (pandaUI's own, timings in M.actionFx).
--     - "pfui": pfUI-octo's Zoom & Fade -- a button-sized icon copy grows to
--       2x and fades (WORKING_112_SOURCE, pfUI modules/actionbar.lua:168).
--   * Retail 12.1 cast animations (toggle castAnimation): the cast/channel
--     fill sweep with its inner glow, the ring burst on completion and the red
--     interrupt sweep (WORKING_SOURCE, RetailFrameXML 12.1.0.69933
--     Blizzard_ActionBar/Shared/ActionButtonComponentTemplate.xml:136-311 and
--     ActionButton.lua:1030-1239). Their masked, animated layers are baked
--     into flipbooks (tools/make_action_fx_flipbooks.py, M.actionFx) because
--     this client has no MaskTexture or AnimationGroup.
--
-- This client's cast events name no button, so a cast is tied to the slot
-- pressed just before it (press.Note). Everything runs on one shared updater
-- registered only while something animates.

local U = PandaUI
local M = U.media
local FX = M.actionFx

local press = {
  active = {},
  updateId = "actionbar.pressanim",
  nativeInstalled = false,
  eventsInstalled = false,
  -- The press a cast start is matched against (seconds of tolerance).
  matchWindow = 0.6,
  pendingWindow = 0.2,
  -- A STOP this far into the cast counts as completed (burst).
  completeAt = 0.85,
  interruptAfterStop = 0.3,
}

local function Now()
  local fn = U.G("GetTime")
  return type(fn) == "function" and tonumber(fn()) or nil
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------
local function Setting(name)
  if type(U.GetActionBarGlobal) ~= "function" then return nil end
  return U.GetActionBarGlobal(name)
end

function U.ActionPressAnimationEnabled()
  return Setting("pressAnimation") ~= false
end

function U.ActionPressStyle()
  if Setting("pressStyle") == "pfui" then return "pfui" end
  return "modern"
end

function U.ActionCastAnimationEnabled()
  return Setting("castAnimation") ~= false
end

-- ---------------------------------------------------------------------------
-- Regions
-- ---------------------------------------------------------------------------
function press.Cell(tex, index, columns)
  local col = math.mod(index, columns)
  local row = math.floor(index / columns)
  local s = 1 / columns
  tex:SetTexCoord(col * s, (col + 1) * s, row * s, (row + 1) * s)
end

function press.Step(p)
  if p < 0 then p = 0 end
  if p > 1 then p = 1 end
  return math.floor(p * (FX.steps - 1) + 0.5)
end

function press.Raise(frame, button, extra)
  local ok, level = pcall(button.GetFrameLevel, button)
  if ok and tonumber(level) then
    -- Above the +10 label/ring layer of this button and its neighbours.
    pcall(frame.SetFrameLevel, frame, level + extra)
  end
end

function press.Layer(frame, path, layer, blend)
  local tex = frame:CreateTexture(nil, layer)
  tex:SetAllPoints(frame)
  tex:SetTexture(path)
  if blend then pcall(tex.SetBlendMode, tex, blend) end
  tex:Hide()
  return tex
end

-- The icon copy used by both press styles; scaled with SetScale about its
-- CENTER anchor (frames.own_scale_resizes_about_anchor_in_parent_space).
function press.Zoom(button)
  local zoom = button.puiPressAnim
  if zoom then return zoom end
  zoom = CreateFrame("Frame", nil, button)
  pcall(zoom.EnableMouse, zoom, false)
  zoom.tex = zoom:CreateTexture(nil, "ARTWORK")
  zoom.tex:SetAllPoints(zoom)
  zoom:Hide()
  button.puiPressAnim = zoom
  return zoom
end

-- The unscaled 64-unit cell holding every flipbook layer.
function press.Fx(button)
  local fx = button.puiSpellFx
  if fx then return fx end
  fx = CreateFrame("Frame", nil, button)
  pcall(fx.EnableMouse, fx, false)
  fx.glow = press.Layer(fx, FX.static, "ARTWORK")
  fx.intBase = press.Layer(fx, FX.static, "ARTWORK")
  fx.fill = press.Layer(fx, FX.cast, "OVERLAY", "ADD")
  fx.burst = press.Layer(fx, FX.burst, "OVERLAY", "ADD")
  fx.ring = press.Layer(fx, FX.burst, "OVERLAY", "ADD")
  fx.intSweep = press.Layer(fx, FX.burst, "OVERLAY", "ADD")
  button.puiSpellFx = fx
  return fx
end

function press.PlaceFx(fx, button)
  local w = tonumber(button:GetWidth()) or 0
  local h = tonumber(button:GetHeight()) or 0
  if w <= 0 or h <= 0 then return false end
  local k = FX.cellUnits / FX.buttonUnits
  fx:ClearAllPoints()
  fx:SetPoint("CENTER", button, "CENTER", 0, 0)
  fx:SetWidth(w * k)
  fx:SetHeight(h * k)
  press.Raise(fx, button, 13)
  fx:Show()
  return true
end

-- The icon's drawn rectangle. Never icon:GetWidth(): a texture can report its
-- image file's size (actionbar.classic_native_icon_width_is_texture_size).
function press.IconSize(button, icon)
  local l, r = icon:GetLeft(), icon:GetRight()
  local t, b = icon:GetTop(), icon:GetBottom()
  if l and r and t and b and r > l and t > b then return r - l, t - b end
  return tonumber(button:GetWidth()) or 0, tonumber(button:GetHeight()) or 0
end

function press.CopyColor(tex, icon)
  local ok, r, g, b = pcall(icon.GetVertexColor, icon)
  if ok and tonumber(r) then tex:SetVertexColor(r, g, b)
  else tex:SetVertexColor(1, 1, 1) end
end

-- ---------------------------------------------------------------------------
-- Press styles
-- ---------------------------------------------------------------------------
function press.StopZoom(zoom)
  zoom.puiStartedAt = nil
  zoom:Hide()
  if zoom.puiHidIcon then
    pcall(zoom.puiHidIcon.SetAlpha, zoom.puiHidIcon, 1)
    zoom.puiHidIcon = nil
  end
end

function press.StartZoom(button, icon, now, kind)
  local zoom = press.Zoom(button)
  if zoom.puiStartedAt then press.StopZoom(zoom) end
  local w, h
  if kind == "pfui" then
    -- pfUI sizes its copy from the button and always uses its own crop.
    w, h = tonumber(button:GetWidth()) or 0, tonumber(button:GetHeight()) or 0
    zoom.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  else
    w, h = press.IconSize(button, icon)
    local ok, a, b, c, d, e, f, g, k = pcall(icon.GetTexCoord, icon)
    if ok and tonumber(k) then zoom.tex:SetTexCoord(a, b, c, d, e, f, g, k)
    else zoom.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  end
  if w <= 0 or h <= 0 then return false end

  zoom:ClearAllPoints()
  zoom:SetPoint("CENTER", button, "CENTER", 0, 0)
  zoom:SetWidth(w)
  zoom:SetHeight(h)
  press.Raise(zoom, button, 12)
  zoom.tex:SetTexture(icon:GetTexture())
  press.CopyColor(zoom.tex, icon)
  zoom.puiKind = kind
  zoom.puiStartedAt = now
  zoom:SetAlpha(1)
  zoom:SetScale(1)
  zoom:Show()
  if kind ~= "pfui" then
    -- The copy stands in for the icon while it dips (pfUI's shrinkreturn
    -- does the same). Nothing else in pandaUI sets an icon's alpha.
    pcall(icon.SetAlpha, icon, 0)
    zoom.puiHidIcon = icon
  end
  return true
end

function press.TickZoom(button, now)
  local zoom = button.puiPressAnim
  if not zoom or not zoom.puiStartedAt then return false end
  local t = now - zoom.puiStartedAt
  if zoom.puiKind == "pfui" then
    local p = t / FX.pfuiDuration
    if p >= 1 then press.StopZoom(zoom) return false end
    zoom:SetAlpha(1 - p)
    zoom:SetScale(1 + p)
    return true
  end
  local u = t / FX.pressDuration
  if u >= 1 then press.StopZoom(zoom) return false end
  local s
  if u < 0.2 then
    s = 1 - FX.pressDip * (u / 0.2)
  else
    -- Damped spring back to 1 with a small overshoot.
    local v = (u - 0.2) / 0.8
    s = 1 - FX.pressDip * math.exp(-5 * v) * math.cos(2.5 * math.pi * v)
  end
  zoom:SetScale(s)
  return true
end

function press.StartRing(button, now)
  local fx = press.Fx(button)
  if not press.PlaceFx(fx, button) then return end
  local color = FX.ringColor[U.GetActiveThemeStyle and U.GetActiveThemeStyle() or ""] or
                FX.ringColor["modern-wow"]
  fx.ring:SetVertexColor(color[1], color[2], color[3])
  press.Cell(fx.ring, 0, FX.columns)
  fx.ring:Show()
  fx.ringAt = now
end

function press.TickRing(button, now)
  local fx = button.puiSpellFx
  if not fx or not fx.ringAt then return false end
  local p = (now - fx.ringAt) / FX.pressRingDuration
  if p >= 1 then
    fx.ringAt = nil
    fx.ring:Hide()
    return false
  end
  press.Cell(fx.ring, press.Step(p), FX.columns)
  return true
end

-- ---------------------------------------------------------------------------
-- Retail cast animations
-- ---------------------------------------------------------------------------
function press.ClearCast(fx)
  fx.castMode, fx.burstAt = nil, nil
  fx.glow:Hide()
  fx.fill:Hide()
  fx.burst:Hide()
end

function press.ClearInterrupt(fx)
  fx.intAt = nil
  fx.intBase:Hide()
  fx.intSweep:Hide()
end

function press.StartCast(button, mode, startedAt, duration)
  local fx = press.Fx(button)
  if not press.PlaceFx(fx, button) then return end
  press.ClearInterrupt(fx)
  fx.castMode, fx.castStart, fx.castDur, fx.burstAt = mode, startedAt, duration, nil
  press.Cell(fx.glow, mode == "channel" and FX.staticChannel or FX.staticCast,
             FX.staticColumns)
  fx.glow:SetAlpha(1)
  fx.glow:Show()
  fx.fill:SetAlpha(1)
  press.Cell(fx.fill, mode == "channel" and FX.channelOffset or 0, FX.columns)
  fx.fill:Show()
  fx.burst:Hide()
  press.castButton = button
  press.Activate(button)
end

-- Retail ActionButtonCastingAnimationFillMixin:OnFinished: the fill stops,
-- the inner glow stays, and the ring bursts.
function press.Burst(fx, now)
  fx.castMode = nil
  fx.fill:Hide()
  fx.glow:SetAlpha(1)
  fx.burstAt = now
  press.Cell(fx.burst, 0, FX.columns)
  fx.burst:Show()
end

function press.TickCast(button, now)
  local fx = button.puiSpellFx
  if not fx then return false end
  if fx.burstAt then
    local p = (now - fx.burstAt) / FX.burstDuration
    if p >= 1 then press.ClearCast(fx) return false end
    press.Cell(fx.burst, press.Step(p), FX.columns)
    return true
  end
  if not fx.castMode then return false end

  local t = now - fx.castStart
  local p = fx.castDur > 0 and t / fx.castDur or 1
  local base = fx.castMode == "channel" and FX.channelOffset or 0
  press.Cell(fx.fill, base + press.Step(p), FX.columns)
  -- No STOP by Retail's end delay: fade out without a burst. SPELLCAST_STOP is
  -- this client's only success signal, so a silent end is not a completion.
  local over = t - fx.castDur - FX.castEndDelay
  if over > 0 then
    local a = 1 - over / FX.glowFade
    if a <= 0 then press.ClearCast(fx) return false end
    fx.fill:SetAlpha(a)
    fx.glow:SetAlpha(a)
  end
  return true
end

function press.Interrupt(button, now)
  local fx = press.Fx(button)
  if not press.PlaceFx(fx, button) then return end
  press.ClearCast(fx)
  fx.intAt = now
  press.Cell(fx.intBase, FX.staticInterrupt, FX.staticColumns)
  fx.intBase:SetAlpha(1)
  fx.intBase:Show()
  press.Cell(fx.intSweep, FX.channelOffset, FX.columns)
  fx.intSweep:Show()
  press.Activate(button)
end

function press.TickInterrupt(button, now)
  local fx = button.puiSpellFx
  if not fx or not fx.intAt then return false end
  local t = now - fx.intAt
  if t < FX.interruptSweep then
    press.Cell(fx.intSweep, FX.channelOffset + press.Step(t / FX.interruptSweep),
               FX.columns)
  else
    fx.intSweep:Hide()
  end
  local fade = t - FX.interruptHold
  if fade >= FX.interruptFade then press.ClearInterrupt(fx) return false end
  if fade > 0 then
    local u = fade / FX.interruptFade
    fx.intBase:SetAlpha(1 - (1 - (1 - u) * (1 - u)))
  end
  return true
end

-- ---------------------------------------------------------------------------
-- Driver
-- ---------------------------------------------------------------------------
function press.StopAll(button)
  if button.puiPressAnim then press.StopZoom(button.puiPressAnim) end
  local fx = button.puiSpellFx
  if fx then
    fx.ringAt = nil
    fx.ring:Hide()
    press.ClearCast(fx)
    press.ClearInterrupt(fx)
  end
  if press.castButton == button then press.castButton = nil end
end

function press.Tick(button, now)
  local alive = press.TickZoom(button, now)
  if press.TickRing(button, now) then alive = true end
  if press.TickCast(button, now) then alive = true end
  if press.TickInterrupt(button, now) then alive = true end
  return alive
end

function press.Update()
  local now = Now()
  local i
  for i = table.getn(press.active), 1, -1 do
    local button = press.active[i]
    local keep = false
    if now and button:IsVisible() then
      keep = press.Tick(button, now)
    else
      press.StopAll(button)
    end
    if not keep then
      button.puiFxActive = nil
      table.remove(press.active, i)
    end
  end
  if table.getn(press.active) == 0 then U.UnregisterUpdate(press.updateId) end
end

function press.Activate(button)
  if button.puiFxActive then return end
  button.puiFxActive = true
  table.insert(press.active, button)
  if table.getn(press.active) == 1 then
    U.RegisterUpdate(press.updateId, 0, press.Update)
  end
end

-- ---------------------------------------------------------------------------
-- Press entry points
-- ---------------------------------------------------------------------------
function press.Note(button)
  press.lastButton = button
  press.lastAt = Now()
  press.ResolvePending()
end

-- Records that `button` was used and plays the press style. `icon` is the
-- slot's icon texture; an empty slot or a hidden button plays nothing.
function U.PlayActionPressAnimation(button, icon)
  if not button then return end
  press.Note(button)
  if not icon or not U.ActionPressAnimationEnabled() then return end
  if not button:IsVisible() or not icon:IsVisible() or not icon:GetTexture() then
    return
  end
  local now = Now()
  if not now then return end

  local style = U.ActionPressStyle()
  local started = press.StartZoom(button, icon, now, style)
  if style == "modern" then
    press.StartRing(button, now)
    started = true
  end
  if started then press.Activate(button) end
end

-- ---------------------------------------------------------------------------
-- Cast events
-- ---------------------------------------------------------------------------
-- A start is matched to a press up to matchWindow before it, or up to
-- pendingWindow after it: a post-hook (native bars) notes the press only after
-- the action ran, and the event may already have fired inside UseAction.
function press.ResolvePending()
  local pending = press.pending
  if not pending then return end
  local now = Now()
  if not now or now - pending.at > press.pendingWindow then
    press.pending = nil
    return
  end
  local button = press.lastButton
  if not button or not press.lastAt or
     math.abs(pending.at - press.lastAt) > press.matchWindow then
    return
  end
  press.pending = nil
  press.lastButton = nil
  if button:IsVisible() then
    press.StartCast(button, pending.mode, pending.at, pending.duration)
  end
end

function press.OnCastStart(mode, ms)
  if not U.ActionCastAnimationEnabled() then return end
  ms = tonumber(ms)
  local now = Now()
  if not ms or ms <= 0 or not now then return end
  if press.castButton and press.castButton.puiSpellFx then
    press.ClearCast(press.castButton.puiSpellFx)
  end
  press.castButton = nil
  press.pending = { mode = mode, at = now, duration = ms / 1000 }
  press.ResolvePending()
end

function press.CastFx()
  local button = press.castButton
  local fx = button and button.puiSpellFx
  if fx and fx.castMode then return button, fx end
  return nil, nil
end

function press.OnEvent(event, a1, a2)
  local now = Now()
  if not now then return end
  if event == "SPELLCAST_START" then
    -- This client sends (name, ms) (castbar.player_events_partial).
    press.OnCastStart("cast", tonumber(a2) or tonumber(a1))
  elseif event == "SPELLCAST_CHANNEL_START" then
    -- (ms, name) per UnrealPfUI libcast.lua:219; unconfirmed here, so take
    -- whichever argument is a number.
    press.OnCastStart("channel", tonumber(a1) or tonumber(a2))
  elseif event == "SPELLCAST_DELAYED" then
    local _, fx = press.CastFx()
    if fx and fx.castMode == "cast" and tonumber(a1) then
      fx.castDur = fx.castDur + tonumber(a1) / 1000
    end
  elseif event == "SPELLCAST_STOP" or event == "SPELLCAST_CHANNEL_STOP" then
    local button, fx = press.CastFx()
    if not fx then return end
    local channel = event == "SPELLCAST_CHANNEL_STOP"
    if channel ~= (fx.castMode == "channel") then return end
    local p = fx.castDur > 0 and (now - fx.castStart) / fx.castDur or 1
    -- Retail bursts on every channel stop and on a succeeded cast.
    if channel or p >= press.completeAt then press.Burst(fx, now)
    else press.ClearCast(fx) end
    press.castButton = nil
    press.stopButton, press.stopAt = button, now
  elseif event == "SPELLCAST_INTERRUPTED" then
    local button = press.CastFx()
    if not button and press.stopAt and
       now - press.stopAt <= press.interruptAfterStop then
      button = press.stopButton
    end
    press.castButton, press.stopButton, press.stopAt = nil, nil, nil
    if button and button:IsVisible() then press.Interrupt(button, now) end
  end
end

-- SPELLCAST_FAILED is not handled: Retail only clears its targeting reticle
-- there, and a cast that really ends without STOP fades out on its own.
function U.InstallActionSpellFx()
  if press.eventsInstalled then return end
  press.eventsInstalled = true
  local events = {
    "SPELLCAST_START", "SPELLCAST_STOP", "SPELLCAST_DELAYED",
    "SPELLCAST_INTERRUPTED", "SPELLCAST_CHANNEL_START", "SPELLCAST_CHANNEL_STOP",
  }
  local i
  for i = 1, table.getn(events) do
    U.RegisterEvent(events[i], press.OnEvent)
  end
end

-- ---------------------------------------------------------------------------
-- Classic WoW stock main bar
-- ---------------------------------------------------------------------------
-- ActionButton1-12 / BonusActionButton1-12 stay native there. Keys fire the
-- action in ActionButtonUp (octo-framexml ActionButton.lua:30); mouse clicks
-- in their XML OnClick (ActionBarFrame.xml:12). Both are wrapped, never
-- replaced, and the press is noted before the original runs so a cast start
-- raised inside UseAction already has its button.
function press.NativeButton(id)
  local bonus = U.G("BonusActionBarFrame")
  local prefix = "ActionButton"
  if bonus and bonus:IsShown() then prefix = "BonusActionButton" end
  return U.G(prefix .. id), U.G(prefix .. id .. "Icon")
end

function press.WrapNativeUp()
  local original = U.G("ActionButtonUp")
  if type(original) ~= "function" then return end
  U.SetG("ActionButtonUp", function(id, onSelf, a3, a4)
    local button, icon = press.NativeButton(id)
    if button then press.Note(button) end
    local r1, r2 = original(id, onSelf, a3, a4)
    if button then U.PlayActionPressAnimation(button, icon) end
    return r1, r2
  end)
end

function press.WrapNativeClick(button, icon)
  local original = button:GetScript("OnClick")
  if type(original) ~= "function" then return end
  button:SetScript("OnClick", function()
    press.Note(button)
    original()
    U.PlayActionPressAnimation(button, icon)
  end)
end

function U.InstallNativeActionPressAnimation()
  if press.nativeInstalled then return end
  press.nativeInstalled = true
  press.WrapNativeUp()

  local prefixes = { "ActionButton", "BonusActionButton" }
  local p, i
  for p = 1, table.getn(prefixes) do
    for i = 1, 12 do
      local button = U.G(prefixes[p] .. i)
      local icon = U.G(prefixes[p] .. i .. "Icon")
      if button and icon and button.GetScript then
        press.WrapNativeClick(button, icon)
      end
    end
  end
end
