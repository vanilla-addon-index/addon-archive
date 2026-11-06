local function lerp(a, b, t) return a + (b - a) * t end

local function rotCorner(a)
  local r = math.rad(a)
  return 0.5 + math.cos(r) / 1.4142, 0.5 + math.sin(r) / 1.4142
end

local function applyRotation(texture, angle)
  local a = -angle
  local ULx, ULy = rotCorner(a + 225)
  local LLx, LLy = rotCorner(a + 135)
  local URx, URy = rotCorner(a - 45)
  local LRx, LRy = rotCorner(a + 45)
  texture:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
end

lib:RegisterType("alpha", {
  init = function(target, from)
    return from or target:GetAlpha()
  end,
  apply = function(target, from, to, t)
    target:SetAlpha(lerp(from, to, t))
  end,
})

lib:RegisterType("scale", {
  init = function(target, from, to, tween)
    tween._baseW = target:GetWidth()
    tween._baseH = target:GetHeight()
    return from or 1.0
  end,
  apply = function(target, from, to, t, tween)
    local s = lerp(from, to, t)
    target:SetWidth(tween._baseW * s)
    target:SetHeight(tween._baseH * s)
  end,
})

lib:RegisterType("size", {
  init = function(target, from)
    return from or { target:GetWidth(), target:GetHeight() }
  end,
  apply = function(target, from, to, t)
    target:SetWidth(lerp(from[1], to[1], t))
    target:SetHeight(lerp(from[2], to[2], t))
  end,
})

lib:RegisterType("position", {
  init = function(target, from, to, tween)
    local point, rel, relPoint, x, y = target:GetPoint(1)
    tween._point = point or "CENTER"
    tween._rel = rel
    tween._relPoint = relPoint or "CENTER"
    return from or { x or 0, y or 0 }
  end,
  apply = function(target, from, to, t, tween)
    target:ClearAllPoints()
    target:SetPoint(tween._point, tween._rel, tween._relPoint,
      lerp(from[1], to[1], t), lerp(from[2], to[2], t))
  end,
})

lib:RegisterType("color", {
  init = function(target, from)
    return from or { 1, 1, 1, 1 }
  end,
  apply = function(target, from, to, t)
    target:SetVertexColor(
      lerp(from[1], to[1], t),
      lerp(from[2], to[2], t),
      lerp(from[3], to[3], t),
      lerp(from[4] or 1, to[4] or 1, t))
  end,
})

lib:RegisterType("rotation", {
  init = function(target, from)
    return from or 0
  end,
  apply = function(target, from, to, t)
    applyRotation(target, lerp(from, to, t))
  end,
})

lib:RegisterType("custom", {
  init = function(target, from, to, tween)
    if from ~= nil then return from end
    if tween._getter then return tween._getter(target) end
    return 0
  end,
  apply = function(target, from, to, t, tween)
    if tween._setter then
      tween._setter(target, lerp(from, to, t))
    end
  end,
})
