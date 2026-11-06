local function resolveEasing(easing)
  if type(easing) == "function" then return easing end
  return lib._easing[easing] or lib._easing["inOutQuad"]
end

local Tween = {}

function Tween:Play()
  self._elapsed = 0
  self._started = false
  self._done = false
  lib._activate(self)
end

function Tween:Cancel()
  if not self._active then return end
  lib._deactivate(self)
  self._done = true
  if self._onCancel then self:_onCancel() end
end

function Tween:IsPlaying()
  return self._active == true
end

function Tween:_start()
  local handler = lib._types[self._type]
  if handler and handler.init then
    self._from = handler.init(self._target, self._from, self._to, self)
  end
  self._started = true
  if self._onStart then self:_onStart() end
end

function Tween:_tick(dt)
  self._elapsed = self._elapsed + dt

  if self._elapsed < self._delay then return false end

  if not self._started then self:_start() end

  local t = self._duration > 0
    and math.min((self._elapsed - self._delay) / self._duration, 1)
    or 1

  local handler = lib._types[self._type]
  if handler and handler.apply and self._target then
    handler.apply(self._target, self._from, self._to, resolveEasing(self._easing)(t), self)
  end

  if self._onUpdate then self:_onUpdate(t) end

  return t >= 1
end

function Tween:_finish()
  lib._deactivate(self)
  self._done = true

  -- Apply one final time at exactly t=1 -- the last _tick may have landed
  -- slightly before 1.0 depending on frame timing.
  local handler = lib._types[self._type]
  if handler and handler.apply and self._target then
    handler.apply(self._target, self._from, self._to, 1, self)
  end
  if handler and handler.cleanup then
    handler.cleanup(self._target, self)
  end

  if self._onFinish then self:_onFinish() end
end

function Tween:SetFrom(val) self._from = val end
function Tween:SetTo(val) self._to = val end
function Tween:SetDuration(val) self._duration = val end
function Tween:SetDelay(val) self._delay = val end
function Tween:SetTarget(val) self._target = val end

function Tween:_reset()
  self._elapsed = 0
  self._started = false
  self._done = false
end

local TweenMT = { __index = Tween }

local KNOWN_OPTS = {
  type = true, from = true, to = true, duration = true, easing = true,
  delay = true, onStart = true, onUpdate = true, onFinish = true,
  onCancel = true, getter = true, setter = true, defer = true,
}

function lib:Tween(target, opts)
  local tween = setmetatable({
    _target   = target,
    _type     = opts.type or "alpha",
    _from     = opts.from,
    _to       = opts.to,
    _duration = opts.duration or 0.3,
    _easing   = opts.easing or "inOutQuad",
    _delay    = opts.delay or 0,
    _onStart  = opts.onStart,
    _onUpdate = opts.onUpdate,
    _onFinish = opts.onFinish,
    _onCancel = opts.onCancel,
    _getter   = opts.getter,
    _setter   = opts.setter,
  }, TweenMT)

  -- Forward extra opts to the tween for custom type handlers.
  -- Internal fields use underscore prefix, so user params (vx, radius, etc.)
  -- are accessible as tween.vx, tween.radius without collision.
  for k, v in pairs(opts) do
    if not KNOWN_OPTS[k] then
      tween[k] = v
    end
  end

  if not opts.defer then
    lib._schedulePending(tween)
  end

  return tween
end
