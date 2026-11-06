local Sequence = {}

function Sequence:Play()
  self._index = 1
  self._loopCount = 0
  self._elapsed = 0
  self._done = false
  self:_resetChildren()
  lib._activate(self)
end

function Sequence:Cancel()
  if not self._active then return end
  local child = self._children[self._index]
  if child and child._started and child.Cancel then child:Cancel() end
  lib._deactivate(self)
  self._done = true
  if self._onCancel then self:_onCancel() end
end

function Sequence:IsPlaying()
  return self._active == true
end

function Sequence:_tick(dt)
  self._elapsed = self._elapsed + dt
  if self._elapsed < self._delay then return false end

  local child = self._children[self._index]
  if not child then return true end

  if not child._started then child:_start() end

  if child:_tick(dt) then
    child:_finish()
    self._index = self._index + 1

    if self._index > table.getn(self._children) then
      return self:_handleLoop()
    end
  end

  return false
end

function Sequence:_finish()
  lib._deactivate(self)
  self._done = true
  if self._onFinish then self:_onFinish() end
end

function Sequence:_start()
  self._started = true
end

function Sequence:_reset()
  self._index = 1
  self._loopCount = 0
  self._elapsed = 0
  self._done = false
  self._started = false
  self:_resetChildren()
end

function Sequence:_resetChildren()
  for i = 1, table.getn(self._children) do
    self._children[i]:_reset()
  end
end

function Sequence:_handleLoop()
  self._loopCount = self._loopCount + 1
  if self._loop ~= 0 and self._loopCount >= self._loop then
    return true
  end

  if self._yoyo then
    local c = self._children
    local n = table.getn(c)
    for i = 1, math.floor(n / 2) do
      c[i], c[n - i + 1] = c[n - i + 1], c[i]
    end
  end

  self._index = 1
  self:_resetChildren()
  return false
end

local SequenceMT = { __index = Sequence }

function lib:Sequence(children, opts)
  opts = opts or {}

  for i = 1, table.getn(children) do
    children[i]._autoplay = false
  end

  local seq = setmetatable({
    _children  = children,
    _index     = 1,
    _loop      = opts.loop or 1,
    _yoyo      = opts.yoyo or false,
    _loopCount = 0,
    _delay     = opts.delay or 0,
    _elapsed   = 0,
    _onFinish  = opts.onFinish,
    _onCancel  = opts.onCancel,
    _done      = false,
  }, SequenceMT)

  if not opts.defer then
    lib._schedulePending(seq)
  end

  return seq
end
