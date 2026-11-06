local E = lib._easing

local pi = math.pi
local sin = math.sin
local cos = math.cos
local pow = math.pow
local sqrt = math.sqrt

E["linear"] = function(t) return t end
E["swing"] = function(t) return 0.5 - cos(t * pi) / 2 end

-- Quad (power of 2)
E["inQuad"] = function(t) return t * t end
E["outQuad"] = function(t) return t * (2 - t) end
E["inOutQuad"] = function(t)
  if t < 0.5 then return 2 * t * t end
  return -1 + (4 - 2 * t) * t
end

-- Cubic (power of 3)
E["inCubic"] = function(t) return t * t * t end
E["outCubic"] = function(t) local u = t - 1; return u * u * u + 1 end
E["inOutCubic"] = function(t)
  if t < 0.5 then return 4 * t * t * t end
  local u = 2 * t - 2; return (u * u * u + 2) / 2
end

-- Quart (power of 4)
E["inQuart"] = function(t) return t * t * t * t end
E["outQuart"] = function(t) local u = t - 1; return 1 - u * u * u * u end
E["inOutQuart"] = function(t)
  if t < 0.5 then return 8 * t * t * t * t end
  local u = t - 1; return 1 - 8 * u * u * u * u
end

-- Quint (power of 5)
E["inQuint"] = function(t) return t * t * t * t * t end
E["outQuint"] = function(t) local u = t - 1; return 1 + u * u * u * u * u end
E["inOutQuint"] = function(t)
  if t < 0.5 then return 16 * t * t * t * t * t end
  local u = t - 1; return 1 + 16 * u * u * u * u * u
end

-- Sine
E["inSine"] = function(t) return 1 - cos(t * pi / 2) end
E["outSine"] = function(t) return sin(t * pi / 2) end
E["inOutSine"] = function(t) return 0.5 - cos(t * pi) / 2 end

-- Expo
E["inExpo"] = function(t)
  if t == 0 then return 0 end
  return pow(2, 10 * (t - 1))
end
E["outExpo"] = function(t)
  if t == 1 then return 1 end
  return 1 - pow(2, -10 * t)
end
E["inOutExpo"] = function(t)
  if t == 0 or t == 1 then return t end
  if t < 0.5 then return pow(2, 20 * t - 10) / 2 end
  return (2 - pow(2, -20 * t + 10)) / 2
end

-- Circ
E["inCirc"] = function(t) return 1 - sqrt(1 - t * t) end
E["outCirc"] = function(t) local u = t - 1; return sqrt(1 - u * u) end
E["inOutCirc"] = function(t)
  if t < 0.5 then return (1 - sqrt(1 - 4 * t * t)) / 2 end
  local u = 2 * t - 2; return (sqrt(1 - u * u) + 1) / 2
end

-- Elastic
E["inElastic"] = function(t)
  if t == 0 or t == 1 then return t end
  return -pow(2, 10 * t - 10) * sin((t * 10 - 10.75) * (2 * pi) / 3)
end
E["outElastic"] = function(t)
  if t == 0 or t == 1 then return t end
  return pow(2, -10 * t) * sin((t * 10 - 0.75) * (2 * pi) / 3) + 1
end
E["inOutElastic"] = function(t)
  if t == 0 or t == 1 then return t end
  if t < 0.5 then
    return -pow(2, 20 * t - 10) * sin((20 * t - 11.125) * (2 * pi) / 4.5) / 2
  end
  return pow(2, -20 * t + 10) * sin((20 * t - 11.125) * (2 * pi) / 4.5) / 2 + 1
end

-- Back
E["inBack"] = function(t)
  local s = 1.70158
  return t * t * ((s + 1) * t - s)
end
E["outBack"] = function(t)
  local s = 1.70158
  local u = t - 1
  return u * u * ((s + 1) * u + s) + 1
end
E["inOutBack"] = function(t)
  local s = 1.70158 * 1.525
  if t < 0.5 then
    return (2 * t) * (2 * t) * ((s + 1) * (2 * t) - s) / 2
  end
  local u = 2 * t - 2
  return (u * u * ((s + 1) * u + s) + 2) / 2
end

-- Bounce
E["outBounce"] = function(t)
  if t < 1 / 2.75 then
    return 7.5625 * t * t
  elseif t < 2 / 2.75 then
    t = t - 1.5 / 2.75
    return 7.5625 * t * t + 0.75
  elseif t < 2.5 / 2.75 then
    t = t - 2.25 / 2.75
    return 7.5625 * t * t + 0.9375
  else
    t = t - 2.625 / 2.75
    return 7.5625 * t * t + 0.984375
  end
end
E["inBounce"] = function(t) return 1 - E["outBounce"](1 - t) end
E["inOutBounce"] = function(t)
  if t < 0.5 then return (1 - E["outBounce"](1 - 2 * t)) / 2 end
  return (1 + E["outBounce"](2 * t - 1)) / 2
end
