-- PizzaSauce: Smooth, declarative animation library for WoW 1.12

local _G = getfenv(0)

local lib = {}
lib.version = "0.1.1"
_G["PizzaSauce"] = lib

lib._types = {}
lib._easing = {}
lib._active = {}
lib._pending = {}
lib._pendingN = 0
lib._count = 0
lib._finBuf = {}

lib._frame = CreateFrame("Frame", nil, UIParent)
lib._frame:Hide()

local lastTime = GetTime()

local function activate(anim)
  if anim._active then return end
  anim._active = true
  lib._count = lib._count + 1
  lib._active[anim] = true
  if lib._count == 1 then
    lastTime = GetTime()
    lib._frame:Show()
  end
end

local function deactivate(anim)
  if not anim._active then return end
  anim._active = false
  lib._count = lib._count - 1
  lib._active[anim] = nil
  if lib._count <= 0 then
    lib._count = 0
    if lib._pendingN == 0 then lib._frame:Hide() end
  end
end

lib._frame:SetScript("OnUpdate", function()
  local now = GetTime()
  local dt = now - lastTime
  lastTime = now
  if dt <= 0 then return end

  -- Process pending auto-play animations
  local pendingN = lib._pendingN
  if pendingN > 0 then
    lib._pendingN = 0
    for i = 1, pendingN do
      local anim = lib._pending[i]
      lib._pending[i] = nil
      if anim._autoplay then anim:Play() end
    end
  end

  -- Hide driver if nothing to do
  if lib._count == 0 then
    lib._frame:Hide()
    return
  end

  -- Tick all active, collect finished into scratch buffer.
  -- Can't finish inline because _finish() callbacks may create new animations,
  -- which would modify _active while we're iterating it.
  local finN = 0
  for anim in pairs(lib._active) do
    if anim:_tick(dt, now) then
      finN = finN + 1
      lib._finBuf[finN] = anim
    end
  end

  for i = 1, finN do
    lib._finBuf[i]:_finish()
    lib._finBuf[i] = nil
  end
end)

lib._activate = activate
lib._deactivate = deactivate

function lib._schedulePending(anim)
  anim._autoplay = true
  lib._pendingN = lib._pendingN + 1
  lib._pending[lib._pendingN] = anim
  lastTime = GetTime()
  lib._frame:Show()
end

function lib:RegisterType(name, handlers)
  lib._types[name] = handlers
end

function lib:RegisterEasing(name, fn)
  lib._easing[name] = fn
end

function lib:RegisterHelper(name, fn)
  if lib[name] then
    DEFAULT_CHAT_FRAME:AddMessage(
      "PizzaSauce: RegisterHelper('" .. name .. "') would overwrite an existing method")
    return
  end
  lib[name] = fn
end
