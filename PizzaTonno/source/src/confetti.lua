local PT = PizzaTonno
local Sauce = PizzaSauce
PT.confetti = {}

-- A small puff out of both ends of a row, after PizzaLoot's epic confetti but far quieter.
local PER_SIDE = 6
local MIN_SIZE, MAX_SIZE = 2, 4
-- how far a bit flies, shooting out fast and slowing down, and how far it sinks meanwhile
local MIN_DISTANCE, MAX_DISTANCE = 40, 90
local SINK = 12
-- degrees above the horizontal; a little below it too
local MIN_ANGLE, MAX_ANGLE = -10, 50
local MIN_LIFE, MAX_LIFE = 0.7, 1
local FADE = 0.35

local PURPLE = { 0.63, 0.31, 1 }
local PALETTE = { PURPLE, PURPLE, { 0.78, 0.61, 1 }, { 1, 0.6, 0.85 }, { 0.95, 0.94, 0.97 }, { 0.94, 0.69, 0.29 } }

-- Out fast, then slowing down (a quartic ease-out); a light gravity pulls it down a little as the
-- time runs. The tween's value is the share of the lifetime gone.
local function place(bit, t)
  local u = 1 - t
  local flown = 1 - u * u * u * u
  bit:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', bit.x + bit.dx * flown, bit.y + bit.dy * flown - SINK * t * t)
end

-- Built on the first watched catch, each with its flight, replayed on every burst after.
local particles = {}

local function particle(i)
  if particles[i] then return particles[i] end

  local bit = CreateFrame('Frame', nil, UIParent)
  bit:SetFrameStrata('HIGH')
  bit:Hide()
  bit.texture = bit:CreateTexture(nil, 'ARTWORK')
  bit.texture:SetAllPoints()
  bit.path = Sauce:Tween(bit, { type = 'custom', from = 0, to = 1, easing = 'linear', setter = place, defer = true })
  bit.fade = Sauce:FadeTo(bit, 0, FADE, 'inQuad', { defer = true })
  bit.flight = Sauce:Group({ bit.path, bit.fade }, { onFinish = function () bit:Hide() end, defer = true })
  particles[i] = bit
  return bit
end

local function random(low, high)
  return low + math.random() * (high - low)
end

local function fly(bit, x, y, direction)
  local angle = math.rad(random(MIN_ANGLE, MAX_ANGLE))
  local distance, life = random(MIN_DISTANCE, MAX_DISTANCE), random(MIN_LIFE, MAX_LIFE)
  bit.x, bit.y = x, y
  bit.dx, bit.dy = direction * math.cos(angle) * distance, math.sin(angle) * distance

  local size = random(MIN_SIZE, MAX_SIZE)
  local color = PALETTE[math.random(table.getn(PALETTE))]
  bit:SetWidth(size)
  bit:SetHeight(size)
  bit.texture:SetTexture(color[1], color[2], color[3], 1)

  Sauce:Stop(bit)
  place(bit, 0)
  bit:SetAlpha(1)
  bit:Show()
  bit.path:SetDuration(life)
  bit.fade:SetDelay(life - FADE)
  bit.flight:Play()
end

function PT.confetti.burst(row)
  local y = (row:GetTop() + row:GetBottom()) / 2
  for i = 1, PER_SIDE do
    fly(particle(i), row:GetLeft(), y, -1)
    fly(particle(PER_SIDE + i), row:GetRight(), y, 1)
  end
end
