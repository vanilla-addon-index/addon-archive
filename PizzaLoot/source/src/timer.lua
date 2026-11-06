local PL = PizzaLoot
PL.timer = {}

local proto = {}
proto.__index = proto

local function onUpdate()
  local timer = this.timer
  timer.elapsed = timer.elapsed + arg1
  if timer.elapsed < timer.interval then return end

  timer.elapsed = 0
  if not timer.repeating then this:Hide() end
  timer.callback()
end

local function new(interval, callback, repeating)
  local frame = CreateFrame('Frame')
  frame:Hide()
  frame:SetScript('OnUpdate', onUpdate)
  frame.timer = setmetatable({
    frame = frame,
    interval = interval,
    callback = callback,
    repeating = repeating,
    elapsed = 0,
  }, proto)
  return frame.timer
end

function PL.timer.after(interval, callback)
  return new(interval, callback, false)
end

function PL.timer.every(interval, callback)
  return new(interval, callback, true)
end

function proto:isRunning() return self.frame:IsShown() end
function proto:restart() self.elapsed = 0; self.frame:Show() end
function proto:start() if not self:isRunning() then self:restart() end end
function proto:stop() self.frame:Hide() end
