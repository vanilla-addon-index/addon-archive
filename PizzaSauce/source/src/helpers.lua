-- Directional offsets for slide animations
local directions = {
  LEFT  = function(d) return { -d, 0 } end,
  RIGHT = function(d) return {  d, 0 } end,
  UP    = function(d) return {  0, d } end,
  DOWN  = function(d) return {  0,-d } end,
}

local function dirOffset(dir, dist)
  local fn = directions[string.upper(dir or "LEFT")]
  return fn and fn(dist) or { 0, 0 }
end

local function getAnchorPos(frame)
  local _, _, _, x, y = frame:GetPoint(1)
  return { x or 0, y or 0 }
end

local EMPTY = {}
local function opts(o)
  if type(o) == "table" then return o end
  return EMPTY
end

-- ============================================================
-- Alpha
-- ============================================================

function lib:FadeTo(target, toAlpha, duration, easing, o)
  o = opts(o)
  return lib:Tween(target, {
    type = "alpha", to = toAlpha,
    duration = duration, easing = easing,
    delay = o.delay, onStart = o.onStart, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer,
  })
end

function lib:FadeIn(target, duration, easing, o)
  o = opts(o)
  return lib:Tween(target, {
    type = "alpha", from = 0, to = 1,
    duration = duration, easing = easing,
    onStart = function()
      target:SetAlpha(0)
      target:Show()
      if o.onStart then o.onStart() end
    end,
    delay = o.delay, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer,
  })
end

function lib:FadeOut(target, duration, easing, o)
  o = opts(o)
  local onFinish = o.onFinish
  return lib:FadeTo(target, 0, duration, easing, {
    delay = o.delay, onCancel = o.onCancel, defer = o.defer,
    onFinish = function() target:Hide(); if onFinish then onFinish() end end,
  })
end

function lib:Flash(target, count, duration, o)
  o = opts(o)
  count = count or 3
  duration = duration or 0.6
  local half = duration / count / 2
  local steps = {}
  for i = 1, count do
    table.insert(steps, lib:Tween(target, { type = "alpha", to = 0, duration = half, easing = "inQuad", defer = true }))
    table.insert(steps, lib:Tween(target, { type = "alpha", to = 1, duration = half, easing = "outQuad", defer = true }))
  end
  return lib:Sequence(steps, { delay = o.delay, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer })
end

function lib:Breathe(target, minAlpha, maxAlpha, duration, o)
  o = opts(o)
  duration = duration or 1.6
  local half = duration / 2
  return lib:Sequence({
    lib:Tween(target, { type = "alpha", from = minAlpha, to = maxAlpha, duration = half, easing = "inOutQuad", defer = true }),
    lib:Tween(target, { type = "alpha", from = maxAlpha, to = minAlpha, duration = half, easing = "inOutQuad", defer = true }),
  }, { loop = 0, delay = o.delay, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer })
end

-- ============================================================
-- Scale
-- ============================================================

function lib:ScaleIn(target, duration, easing, o)
  o = opts(o)
  return lib:Tween(target, {
    type = "scale", from = 0, to = 1,
    duration = duration or 0.3, easing = easing or "outBack",
    onStart = function()
      target:Show()
      if o.onStart then o.onStart() end
    end,
    delay = o.delay, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer,
  })
end

function lib:ScaleOut(target, duration, easing, o)
  o = opts(o)
  local onFinish = o.onFinish
  return lib:Tween(target, {
    type = "scale", from = 1, to = 0,
    duration = duration or 0.3, easing = easing or "inBack",
    onStart = o.onStart,
    onFinish = function() target:Hide(); if onFinish then onFinish() end end,
    onCancel = o.onCancel, delay = o.delay, defer = o.defer,
  })
end

function lib:Pulse(target, scale, duration, o)
  o = opts(o)
  scale = scale or 1.3
  local half = (duration or 0.4) / 2
  local baseW, baseH = target:GetWidth(), target:GetHeight()
  local function set(f, s)
    f:SetWidth(baseW * s)
    f:SetHeight(baseH * s)
  end
  return lib:Sequence({
    lib:Tween(target, { type = "custom", from = 1.0, to = scale, duration = half, easing = "outQuad", setter = set, defer = true }),
    lib:Tween(target, { type = "custom", from = scale, to = 1.0, duration = half, easing = "inQuad", setter = set, defer = true }),
  }, { delay = o.delay, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer })
end

function lib:Rubber(target, scale, duration, o)
  o = opts(o)
  return lib:Tween(target, {
    type = "scale", from = scale or 1.3, to = 1.0,
    duration = duration or 0.5, easing = "outElastic",
    delay = o.delay, onStart = o.onStart, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer,
  })
end

function lib:Flip(target, axis, duration, o)
  o = opts(o)
  local quarter = (duration or 0.8) / 4
  local horizontal = axis ~= "y"
  local base = horizontal and target:GetWidth() or target:GetHeight()
  local set = horizontal
    and function(f, v) f:SetWidth(v) end
    or function(f, v) f:SetHeight(v) end

  -- Find child textures to mirror via SetTexCoord
  local textures = {}
  if target.GetTexture then
    table.insert(textures, target)
  else
    local children = { target:GetRegions() }
    for i = 1, table.getn(children) do
      if children[i].GetTexture then table.insert(textures, children[i]) end
    end
  end

  local function mirror()
    for i = 1, table.getn(textures) do
      if horizontal then
        textures[i]:SetTexCoord(1, 0, 0, 1)
      else
        textures[i]:SetTexCoord(0, 1, 1, 0)
      end
    end
  end

  local function unmirror()
    for i = 1, table.getn(textures) do
      textures[i]:SetTexCoord(0, 1, 0, 1)
    end
  end

  local shrink = function(f, v) set(f, v) end
  return lib:Sequence({
    -- 0°→90°: shrink to invisible
    lib:Tween(target, { type = "custom", from = base, to = 0.01, duration = quarter, easing = "inQuad", setter = shrink, defer = true }),
    -- 90°→180°: mirror and expand (showing flipped content)
    lib:Tween(target, { type = "custom", from = 0.01, to = base, duration = quarter, easing = "outQuad", setter = shrink, defer = true,
      onStart = function() mirror() end }),
    -- 180°→270°: shrink again
    lib:Tween(target, { type = "custom", from = base, to = 0.01, duration = quarter, easing = "inQuad", setter = shrink, defer = true }),
    -- 270°→360°: unmirror and expand back to original
    lib:Tween(target, { type = "custom", from = 0.01, to = base, duration = quarter, easing = "outQuad", setter = shrink, defer = true,
      onStart = function() unmirror() end }),
  }, { delay = o.delay, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer })
end

-- ============================================================
-- Position
-- ============================================================

function lib:Move(target, from, to, duration, easing, o)
  o = opts(o)
  return lib:Tween(target, {
    type = "position", from = from, to = to,
    duration = duration or 0.3, easing = easing,
    delay = o.delay, onStart = o.onStart, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer,
  })
end

function lib:MoveTo(target, to, duration, easing, o)
  o = opts(o)
  return lib:Tween(target, {
    type = "position", to = to,
    duration = duration, easing = easing,
    delay = o.delay, onStart = o.onStart, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer,
  })
end

function lib:SlideIn(target, direction, distance, duration, easing, o)
  o = opts(o)
  local dest = getAnchorPos(target)
  local offset = dirOffset(direction, distance or 100)
  local from = { dest[1] - offset[1], dest[2] - offset[2] }
  return lib:Group({
    lib:Tween(target, {
      type = "position", from = from, to = dest, duration = duration or 0.3, easing = easing or "outCubic",
      onStart = function()
        target:SetAlpha(0)
        target:Show()
        if o.onStart then o.onStart() end
      end,
      defer = true,
    }),
    lib:Tween(target, {
      type = "alpha",
      from = 0,
      to = 1,
      duration = (duration or 0.3) * 0.6,
      easing = "outQuad",
      defer = true,
    }),
  }, { delay = o.delay, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer })
end

function lib:SlideOut(target, direction, distance, duration, easing, o)
  o = opts(o)
  local from = getAnchorPos(target)
  local offset = dirOffset(direction, distance or 100)
  local dest = { from[1] + offset[1], from[2] + offset[2] }
  local onFinish = o.onFinish
  return lib:Group({
    lib:Tween(target, { type = "position", from = from, to = dest, duration = duration or 0.3, easing = easing or "inCubic", defer = true }),
    lib:Tween(target, { type = "alpha", to = 0, duration = duration or 0.3, easing = "inQuad", defer = true }),
  }, {
    delay = o.delay, onCancel = o.onCancel, defer = o.defer,
    onFinish = function() target:Hide(); if onFinish then onFinish() end end,
  })
end

function lib:Bounce(target, height, count, duration, o)
  o = opts(o)
  height = height or 30
  count = count or 3
  duration = duration or 0.6
  local pos = getAnchorPos(target)
  local steps = {}
  for i = 1, count do
    local h = height * (1 - (i - 1) / count)  -- decay
    table.insert(steps, lib:Tween(target, {
      type = "position", from = pos, to = { pos[1], pos[2] + h },
      duration = duration / count / 2, easing = "outQuad", defer = true,
    }))
    table.insert(steps, lib:Tween(target, {
      type = "position", from = { pos[1], pos[2] + h }, to = pos,
      duration = duration / count / 2, easing = "inQuad", defer = true,
    }))
  end
  return lib:Sequence(steps, { delay = o.delay, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer })
end

function lib:Shake(target, intensity, duration, o)
  o = opts(o)
  intensity = intensity or 5
  duration = duration or 0.3
  local pos = getAnchorPos(target)
  local steps = {}
  local stepDur = 0.03
  local numSteps = math.floor(duration / stepDur)
  for i = 1, numSteps do
    local decay = 1 - (i - 1) / numSteps
    local dx = (math.random() * intensity * 2 - intensity) * decay
    local dy = (math.random() * intensity * 2 - intensity) * decay
    table.insert(steps, lib:Tween(target, {
      type = "position", to = { pos[1] + dx, pos[2] + dy },
      duration = stepDur, easing = "linear", defer = true,
    }))
  end
  -- Snap back to original position
  table.insert(steps, lib:Tween(target, {
    type = "position", to = pos,
    duration = stepDur, easing = "linear", defer = true,
  }))
  return lib:Sequence(steps, { delay = o.delay, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer })
end

function lib:FlyTo(frame, targetFrame, duration, easing, o)
  o = opts(o)
  local toX = targetFrame:GetLeft() + targetFrame:GetWidth() / 2 - UIParent:GetWidth() / 2
  local toY = targetFrame:GetBottom() + targetFrame:GetHeight() / 2 - UIParent:GetHeight() / 2
  return lib:Tween(frame, {
    type = "position", to = { toX, toY },
    duration = duration or 0.5, easing = easing or "inOutQuad",
    delay = o.delay, onStart = o.onStart, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer,
  })
end

-- ============================================================
-- Rotation
-- ============================================================

function lib:Spin(texture, degreesPerSecond, o)
  o = opts(o)
  local dps = degreesPerSecond or 90
  return lib:Sequence({
    lib:Tween(texture, {
      type = "rotation",
      from = 0,
      to = dps > 0 and 360 or -360,
      duration = 360 / math.abs(dps),
      easing = "linear",
      defer = true,
    }),
  }, { loop = 0, delay = o.delay, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer })
end

-- ============================================================
-- Color
-- ============================================================

function lib:Color(target, from, to, duration, easing, o)
  o = opts(o)
  return lib:Tween(target, {
    type = "color", from = from, to = to,
    duration = duration or 0.3, easing = easing,
    delay = o.delay, onStart = o.onStart, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer,
  })
end

function lib:ColorFlash(texture, r, g, b, duration, o)
  o = opts(o)
  duration = duration or 0.4
  local half = duration / 2
  return lib:Sequence({
    lib:Tween(texture, { type = "color", to = { r, g, b, 1 }, duration = half, easing = "outQuad", defer = true }),
    lib:Tween(texture, { type = "color", from = { r, g, b, 1 }, to = { 1, 1, 1, 1 }, duration = half, easing = "inQuad", defer = true }),
  }, { delay = o.delay, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer })
end

-- ============================================================
-- Size
-- ============================================================

function lib:Size(target, from, to, duration, easing, o)
  o = opts(o)
  return lib:Tween(target, {
    type = "size", from = from, to = to,
    duration = duration or 0.3, easing = easing,
    delay = o.delay, onStart = o.onStart, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer,
  })
end

function lib:Morph(target, to, duration, easing, o)
  o = opts(o)
  return lib:Tween(target, {
    type = "size", to = to,
    duration = duration or 0.3, easing = easing,
    delay = o.delay, onStart = o.onStart, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer,
  })
end

-- ============================================================
-- Value
-- ============================================================

function lib:Progress(statusbar, toValue, duration, easing, o)
  o = opts(o)
  return lib:Tween(statusbar, {
    type = "custom",
    to = toValue,
    duration = duration or 0.4,
    easing = easing or "outCubic",
    getter = function(bar) return bar:GetValue() end,
    setter = function(bar, val) bar:SetValue(val) end,
    delay = o.delay, onStart = o.onStart, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer,
  })
end

-- ============================================================
-- Text
-- ============================================================

function lib:Typewriter(fontstring, text, duration, o)
  o = opts(o)
  local len = string.len(text)
  return lib:Tween(fontstring, {
    type = "custom",
    from = 0, to = len,
    duration = duration or len * 0.05,
    easing = "linear",
    setter = function(fs, val)
      fs:SetText(string.sub(text, 1, math.floor(val)))
    end,
    delay = o.delay, onStart = o.onStart, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer,
  })
end

-- ============================================================
-- Clipping (Reveal / Conceal)
-- ============================================================

-- Progressively reveal a texture from a direction by re-anchoring
-- to one edge, animating width/height, and shifting tex coords.
local clipAnchors = {
  LEFT  = { "TOPLEFT",     "TOPLEFT"     },
  RIGHT = { "TOPRIGHT",    "TOPRIGHT"    },
  UP    = { "TOPLEFT",     "TOPLEFT"     },
  DOWN  = { "BOTTOMLEFT",  "BOTTOMLEFT"  },
}

local function clipTween(target, direction, duration, easing, from, to, o)
  o = opts(o)
  direction = string.upper(direction or "LEFT")
  duration = duration or 0.3

  local parent = target:GetParent()
  local baseW = target._clipBaseW or parent:GetWidth()
  local baseH = target._clipBaseH or parent:GetHeight()
  target._clipBaseW = baseW
  target._clipBaseH = baseH

  local horizontal = (direction == "LEFT" or direction == "RIGHT")
  local reversed = (direction == "RIGHT" or direction == "UP")
  local anchor = clipAnchors[direction]

  target:ClearAllPoints()
  target:SetPoint(anchor[1], parent, anchor[2], 0, 0)

  return lib:Tween(target, {
    type = "custom", from = from, to = to,
    duration = duration, easing = easing or "outQuad",
    setter = function(tex, t)
      if horizontal then
        tex:SetWidth(math.max(baseW * t, 0.01))
        tex:SetHeight(baseH)
        if reversed then
          tex:SetTexCoord(1 - t, 1, 0, 1)
        else
          tex:SetTexCoord(0, t, 0, 1)
        end
      else
        tex:SetWidth(baseW)
        tex:SetHeight(math.max(baseH * t, 0.01))
        if reversed then
          tex:SetTexCoord(0, 1, 1 - t, 1)
        else
          tex:SetTexCoord(0, 1, 0, t)
        end
      end
    end,
    onFinish = function()
      target:SetTexCoord(0, 1, 0, 1)
      target:ClearAllPoints()
      target:SetAllPoints(parent)
      if o.onFinish then o.onFinish() end
    end,
    onCancel = o.onCancel, delay = o.delay, defer = o.defer,
  })
end

function lib:Reveal(target, direction, duration, easing, o)
  target:Show()
  return clipTween(target, direction, duration, easing, 0, 1, o)
end

function lib:Conceal(target, direction, duration, easing, o)
  o = opts(o)
  local onFinish = o.onFinish
  return clipTween(target, direction, duration, easing, 1, 0, {
    delay = o.delay, onCancel = o.onCancel, defer = o.defer,
    onFinish = function() target:Hide(); if onFinish then onFinish() end end,
  })
end

-- WipeIn/WipeOut: texture slides in from a direction while being clipped.
-- Unlike Reveal/Conceal where the image is stationary and a window opens,
-- here the image physically moves into view (like sliding out from under a cover).
-- WipeIn/WipeOut: the image slides into/out of view while being clipped.
-- The texture stays full-size (no stretching) -- we clip by shrinking the
-- visible region and offsetting tex coords so the revealed portion matches
-- the correct part of the image.
--
-- For "LEFT" (image slides in from the left edge):
--   anchor at TOPLEFT, width = baseW * t, texCoord left = 1-t
--   → at t=0 nothing visible; at t=1 full image
local wipeAnchors = {
  LEFT  = "TOPLEFT",
  RIGHT = "TOPRIGHT",
  UP    = "TOPLEFT",
  DOWN  = "BOTTOMLEFT",
}

local function wipeTween(target, direction, duration, easing, from, to, o)
  o = opts(o)
  direction = string.upper(direction or "LEFT")
  duration = duration or 0.3

  local parent = target:GetParent()
  local baseW = target._clipBaseW or parent:GetWidth()
  local baseH = target._clipBaseH or parent:GetHeight()
  target._clipBaseW = baseW
  target._clipBaseH = baseH

  local horizontal = (direction == "LEFT" or direction == "RIGHT")
  local anchor = wipeAnchors[direction]

  target:ClearAllPoints()
  target:SetPoint(anchor, parent, anchor, 0, 0)

  return lib:Tween(target, {
    type = "custom", from = from, to = to,
    duration = duration, easing = easing or "outQuad",
    setter = function(tex, t)
      if horizontal then
        tex:SetWidth(math.max(baseW * t, 0.01))
        tex:SetHeight(baseH)
        if direction == "LEFT" then
          tex:SetTexCoord(1 - t, 1, 0, 1)
        else
          tex:SetTexCoord(0, t, 0, 1)
        end
      else
        tex:SetWidth(baseW)
        tex:SetHeight(math.max(baseH * t, 0.01))
        if direction == "DOWN" then
          tex:SetTexCoord(0, 1, 1 - t, 1)
        else
          tex:SetTexCoord(0, 1, 0, t)
        end
      end
    end,
    onFinish = function()
      target:SetTexCoord(0, 1, 0, 1)
      target:ClearAllPoints()
      target:SetAllPoints(parent)
      if o.onFinish then o.onFinish() end
    end,
    onCancel = o.onCancel, delay = o.delay, defer = o.defer,
  })
end

local wipeInFlip = { LEFT="RIGHT", RIGHT="LEFT", UP="DOWN", DOWN="UP" }

function lib:WipeIn(target, direction, duration, easing, o)
  target:Show()
  local dir = wipeInFlip[string.upper(direction or "LEFT")] or direction
  return wipeTween(target, dir, duration, easing, 0, 1, o)
end

function lib:WipeOut(target, direction, duration, easing, o)
  o = opts(o)
  local onFinish = o.onFinish
  return wipeTween(target, direction, duration, easing, 1, 0, {
    delay = o.delay, onCancel = o.onCancel, defer = o.defer,
    onFinish = function() target:Hide(); if onFinish then onFinish() end end,
  })
end

-- ============================================================
-- Meta / Utility
-- ============================================================

function lib:Stagger(targets, animFn, delay, o)
  o = opts(o)
  delay = delay or 0.08
  local children = {}
  for i = 1, table.getn(targets) do
    local anim = animFn(targets[i], i)
    anim._autoplay = false
    if i > 1 then
      table.insert(children, lib:Sequence({ lib:Delay(delay * (i - 1)), anim }, { defer = true }))
    else
      table.insert(children, anim)
    end
  end
  return lib:Group(children, { delay = o.delay, onFinish = o.onFinish, onCancel = o.onCancel, defer = o.defer })
end

function lib:Delay(duration)
  -- A no-op tween that just waits. Uses a dummy target-less approach.
  local dummy = lib._frame
  return lib:Tween(dummy, {
    type = "alpha",
    from = dummy:GetAlpha(),
    to = dummy:GetAlpha(),
    duration = duration or 1,
    defer = true,
  })
end

function lib:Run(fn, o)
  o = opts(o)
  return lib:Tween(nil, {
    type = "custom", from = 0, to = 0, duration = 0,
    onStart = fn, delay = o.delay, defer = o.defer,
  })
end

function lib:Stop(target)
  for anim in pairs(lib._active) do
    if anim._target == target then
      anim:Cancel()
    elseif anim._children then
      lib:_stopInChildren(anim, anim, target)
    end
  end
  -- Also cancel pending (not yet started) animations for this target
  for i = 1, lib._pendingN do
    local anim = lib._pending[i]
    if anim then
      if anim._target == target then
        anim._autoplay = false
      elseif anim._children then
        if lib:_hasTargetInChildren(anim, target) then
          anim._autoplay = false
        end
      end
    end
  end
end

function lib:_hasTargetInChildren(parent, target)
  for i = 1, table.getn(parent._children) do
    local child = parent._children[i]
    if child._target == target then return true end
    if child._children and lib:_hasTargetInChildren(child, target) then return true end
  end
  return false
end

function lib:_stopInChildren(root, parent, target)
  for i = 1, table.getn(parent._children) do
    local child = parent._children[i]
    if child._target == target then
      root:Cancel()
      return
    elseif child._children then
      lib:_stopInChildren(root, child, target)
      if not root._active then return end
    end
  end
end
