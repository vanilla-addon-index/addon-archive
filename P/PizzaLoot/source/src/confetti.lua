local PL = PizzaLoot
local Sauce = PizzaSauce
PL.confetti = {}

local COUNT_EPIC = 90
local COUNT_LEGENDARY = 150
local MIN_SIZE, MAX_SIZE = 2, 6
local GRAVITY = 420
local MIN_SPEED, MAX_SPEED = 90, 240
local MIN_LIFE, MAX_LIFE = 0.8, 1.2
local FADE = 0.35
local MIN_ANGLE, ANGLE_SPREAD = 20, 140
local ACCENT_SHARE = 3

local palette = {
  { 1, 0.85, 0.2 }, { 1, 0.4, 0.1 }, { 0.2, 0.8, 1 }, { 0.4, 1, 0.4 },
  { 1, 0.3, 0.5 }, { 0.6, 0.4, 1 }, { 1, 1, 0.3 }, { 1, 0.6, 0.8 },
}

-- Built on the first epic rather than at load: most sessions never see one, and
-- this is a hundred and fifty frames.
local pool = {}

local function ensure(count)
  for i = table.getn(pool) + 1, count do
    local particle = CreateFrame('Frame', nil, UIParent)
    particle:SetFrameStrata('DIALOG')
    particle:Hide()

    local texture = particle:CreateTexture(nil, 'ARTWORK')
    texture:SetAllPoints()

    pool[i] = { frame = particle, texture = texture }
  end
end

-- Kinematics rather than an easing curve: x = vx*t, y = vy*t - g*t^2/2. Driven
-- by a custom tween whose value is elapsed time, so the arc stays real.
local function arc(particle, x, y, vx, vy, life)
  local function set(frame, elapsed)
    frame:ClearAllPoints()
    frame:SetPoint('CENTER', UIParent, 'CENTER',
      x + vx * elapsed, y + vy * elapsed - 0.5 * GRAVITY * elapsed * elapsed)
  end

  return Sauce:Tween(particle, {
    type = 'custom', from = 0, to = life, duration = life, easing = 'linear', setter = set,
    onStart = function ()
      set(particle, 0)
      particle:SetAlpha(1)
      particle:Show()
    end,
  })
end

local function scatter(entry, x, y, accent)
  local particle, texture = entry.frame, entry.texture

  local size = MIN_SIZE + math.random() * (MAX_SIZE - MIN_SIZE)
  particle:SetWidth(size)
  particle:SetHeight(size)

  local colour = palette[math.random(table.getn(palette))]
  if math.random(ACCENT_SHARE) == 1 then colour = accent end
  texture:SetTexture(colour[1], colour[2], colour[3], 1)

  -- Fanned upward rather than a full circle, so it arcs and falls back like a
  -- confetti cannon instead of half the burst diving off the bottom.
  local angle = math.rad(MIN_ANGLE + math.random() * ANGLE_SPREAD)
  local speed = MIN_SPEED + math.random() * (MAX_SPEED - MIN_SPEED)
  local life = MIN_LIFE + math.random() * (MAX_LIFE - MIN_LIFE)

  return Sauce:Group({
    arc(particle, x, y, math.cos(angle) * speed, math.sin(angle) * speed, life),
    Sauce:FadeTo(particle, 0, FADE, 'inQuad', { delay = life - FADE }),
  }, {
    onFinish = function () particle:Hide(); particle:SetAlpha(1) end,
    onCancel = function () particle:Hide(); particle:SetAlpha(1) end,
  })
end

function PL.confetti.burst(x, y, accent, legendary)
  if not PizzaLoot_config.confetti then return end

  local count = legendary and COUNT_LEGENDARY or COUNT_EPIC
  ensure(count)

  local bursts = {}
  for i = 1, count do
    table.insert(bursts, scatter(pool[i], x, y, accent))
  end
  Sauce:Group(bursts)
end

function PL.confetti.stop()
  for _, entry in ipairs(pool) do
    Sauce:Stop(entry.frame)
    entry.frame:Hide()
    entry.frame:SetAlpha(1)
  end
end
