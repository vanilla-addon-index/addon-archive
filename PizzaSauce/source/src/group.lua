local Group = {}

function Group:Play()
  self._loopCount = 0
  self._elapsed = 0
  self._done = false
  self:_resetChildren()
  lib._activate(self)
end

function Group:Cancel()
  if not self._active then return end
  for i = 1, table.getn(self._children) do
    local child = self._children[i]
    if child._active or child._started then
      if child.Cancel then child:Cancel() end
    end
  end
  lib._deactivate(self)
  self._done = true
  if self._onCancel then self:_onCancel() end
end

function Group:IsPlaying()
  return self._active == true
end

function Group:_tick(dt)
  self._elapsed = self._elapsed + dt
  if self._elapsed < self._delay then return false end

  local allDone = true

  for i = 1, table.getn(self._children) do
    local child = self._children[i]
    if not child._done then
      if not child._started then child:_start() end
      if child:_tick(dt) then
        child:_finish()
      else
        allDone = false
      end
    end
  end

  if allDone then
    return self:_handleLoop()
  end
  return false
end

function Group:_handleLoop()
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

  self:_resetChildren()
  return false
end

function Group:_finish()
  lib._deactivate(self)
  self._done = true
  if self._onFinish then self:_onFinish() end
end

function Group:_start()
  self._started = true
end

function Group:_reset()
  self._loopCount = 0
  self._elapsed = 0
  self._done = false
  self._started = false
  self:_resetChildren()
end

function Group:_resetChildren()
  for i = 1, table.getn(self._children) do
    self._children[i]:_reset()
  end
end

local GroupMT = { __index = Group }

function lib:Group(children, opts)
  opts = opts or {}

  for i = 1, table.getn(children) do
    children[i]._autoplay = false
  end

  local grp = setmetatable({
    _children  = children,
    _loop      = opts.loop or 1,
    _yoyo      = opts.yoyo or false,
    _loopCount = 0,
    _delay     = opts.delay or 0,
    _elapsed   = 0,
    _onFinish  = opts.onFinish,
    _onCancel  = opts.onCancel,
    _done      = false,
  }, GroupMT)

  if not opts.defer then
    lib._schedulePending(grp)
  end

  return grp
end
