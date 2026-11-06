local PL = PizzaLoot
local Sauce = PizzaSauce
PL.row = {}

local PAD = 6
local ICON_SIZE = 22
local ICON_GAP = 5
local ICON_CROP = 0.08
local NAME_LEFT = PAD + ICON_SIZE + ICON_GAP
local QTY_GAP = 6
local STRIP_WIDTH = 3

local ENTER_DISTANCE = 50
local ENTER_TIME = 0.38
local EXIT_DRIFT = 12
local EXIT_TIME = 0.26
local EXIT_FADE = 0.16
local SLIDE_TIME = 0.28
local SHEEN_WIDTH = 45
local SHEEN_TIME = 0.45
local FADE_LEAD = 0.5
local AGED_ALPHA = 0.85

local SHEEN_PEAK = { [0] = 0.10, [1] = 0.10, [2] = 0.12, [3] = 0.20 }
local SHEEN_PEAK_DEFAULT = 0.12

local DRIFT = {
  up   = { 0,  EXIT_DRIFT }, down  = { 0, -EXIT_DRIFT },
  left = { -EXIT_DRIFT, 0 }, right = {  EXIT_DRIFT, 0 },
}

local HOLD = { [0] = 2.0, [1] = 2.0, [2] = 3.0, [3] = 3.0 }
local HOLD_DEFAULT = 3.0

local proto = {}
proto.__index = proto

local built, pool = {}, {}

-- Two frames per row: the stack slides `slot` between positions while the
-- entrance and exit animations move and scale `card`, so neither fights the
-- other. That is also why `card` gets a single anchor point and an explicit
-- size instead of SetAllPoints. It hangs off CENTER so the rare-loot pop grows
-- symmetrically instead of spilling into the row below.
local function build()
  local height = PL.utils.snap(PL.layout.height)

  local slot = CreateFrame('Frame', nil, PL.anchor.frame)
  slot:SetWidth(PL.layout.width)
  slot:SetHeight(height)
  slot:SetFrameStrata('HIGH')
  slot:Hide()

  local card = CreateFrame('Frame', nil, slot)
  card:SetWidth(PL.layout.width)
  card:SetHeight(height)
  card:SetPoint('CENTER', slot, 'CENTER', 0, 0)
  card:Hide()

  local backdrop = card:CreateTexture(nil, 'BACKGROUND')
  backdrop:SetAllPoints()

  PL.utils.border(card)
  local inset = PL.utils.pixel()

  local strip = card:CreateTexture(nil, 'ARTWORK')
  strip:SetWidth(STRIP_WIDTH)
  strip:SetPoint('TOPLEFT', card, 'TOPLEFT', inset, -inset)
  strip:SetPoint('BOTTOMLEFT', card, 'BOTTOMLEFT', inset, inset)

  -- Item icons ship with a dark bevel baked into the corners.
  local icon = card:CreateTexture(nil, 'ARTWORK')
  icon:SetWidth(ICON_SIZE)
  icon:SetHeight(ICON_SIZE)
  icon:SetPoint('CENTER', card, 'LEFT', PAD + ICON_SIZE / 2, 0)
  icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

  local name = card:CreateFontString(nil, 'OVERLAY')
  name:SetFont(STANDARD_TEXT_FONT, 11)
  name:SetShadowColor(0, 0, 0, 1)
  name:SetShadowOffset(1, -1)
  name:SetPoint('LEFT', card, 'LEFT', NAME_LEFT, 0)

  local qty = card:CreateFontString(nil, 'OVERLAY')
  qty:SetFont(STANDARD_TEXT_FONT, 10)
  qty:SetShadowColor(0, 0, 0, 1)
  qty:SetShadowOffset(1, -1)
  qty:SetPoint('RIGHT', card, 'RIGHT', -PAD, 0)
  qty:SetTextColor(0.8, 0.8, 0.8, 1)

  -- A child of `slot`, not `card`: in this client a parent's alpha replaces its
  -- child frames' own alpha instead of multiplying it, so the card's aging dim
  -- snapped the finished, invisible sheen back to full brightness. Anchored to
  -- the card so it still rides the entrance slide.
  local sheen = CreateFrame('Frame', nil, slot)
  sheen:SetWidth(SHEEN_WIDTH)
  sheen:SetHeight(height)
  sheen:SetPoint('LEFT', card, 'LEFT', 0, 0)
  sheen:SetFrameLevel(card:GetFrameLevel() + 2)
  sheen:SetAlpha(0)

  local lead = sheen:CreateTexture(nil, 'OVERLAY')
  lead:SetWidth(SHEEN_WIDTH / 2)
  lead:SetHeight(height)
  lead:SetPoint('LEFT', sheen, 'LEFT', 0, 0)

  local trail = sheen:CreateTexture(nil, 'OVERLAY')
  trail:SetWidth(SHEEN_WIDTH / 2)
  trail:SetHeight(height)
  trail:SetPoint('RIGHT', sheen, 'RIGHT', 0, 0)

  local row = setmetatable({
    slot = slot, card = card, backdrop = backdrop, strip = strip,
    icon = icon, name = name, qty = qty,
    sheen = sheen, lead = lead, trail = trail,
  }, proto)

  table.insert(built, row)
  return row
end

function PL.row.acquire()
  return table.remove(pool) or build()
end

function PL.row.release(row)
  row:reset()
  table.insert(pool, row)
end

function PL.row.setWidth(width)
  PL.layout.width = PL.utils.snap(width)
  PL.anchor.frame:SetWidth(PL.layout.width)
  for _, row in ipairs(built) do
    row.slot:SetWidth(PL.layout.width)
    row.card:SetWidth(PL.layout.width)
  end
end

function proto:fitName(text)
  local available = PL.layout.width - NAME_LEFT - PAD
  local qtyWidth = self.qty:GetStringWidth()
  if qtyWidth > 0 then available = available - qtyWidth - QTY_GAP end

  self.name:SetText(text)
  local length = string.len(text)
  while length > 0 and self.name:GetStringWidth() > available do
    length = length - 1
    self.name:SetText(string.sub(text, 1, length) .. '...')
  end
end

function proto:tintSheen()
  local r, g, b = 1, 1, 1
  if self.quality == PL.quality.RARE then
    r = (self.accent[1] + 1) / 2
    g = (self.accent[2] + 1) / 2
    b = (self.accent[3] + 1) / 2
  end
  self.lead:SetTexture(1, 1, 1, 1)
  self.lead:SetGradientAlpha('HORIZONTAL', r, g, b, 0, r, g, b, 1)
  self.trail:SetTexture(1, 1, 1, 1)
  self.trail:SetGradientAlpha('HORIZONTAL', r, g, b, 1, r, g, b, 0)
end

function proto:setContent(notice)
  self.quality = notice.quality
  self.accent = notice.accent
  PL.utils.tint(self.backdrop, notice.accent)
  self.strip:SetTexture(notice.accent[1], notice.accent[2], notice.accent[3], 1)
  self.name:SetTextColor(notice.label[1], notice.label[2], notice.label[3], 1)
  self.icon:SetTexture(notice.icon)
  self.qty:SetText(notice.count and notice.count > 1 and ('x' .. notice.count) or '')
  self:fitName(notice.name)
  self:tintSheen()
end

function proto:holdTime()
  return (self.quality and HOLD[self.quality]) or HOLD_DEFAULT
end

function proto:placeAt(y)
  self.y = y
  self.slot:ClearAllPoints()
  self.slot:SetPoint('BOTTOMLEFT', PL.anchor.frame, 'BOTTOMLEFT', 0, y)
  self.slot:Show()
end

function proto:slideTo(y, delay)
  if self.y == y then return end
  self.y = y
  Sauce:Stop(self.slot)
  Sauce:MoveTo(self.slot, { 0, y }, SLIDE_TIME, 'outQuint', { delay = delay })
end

-- Stops a band's width short of the right edge: nothing clips children in this
-- client, so sweeping the full width would overhang the card. inOutSine so it
-- crosses the card evenly; an easing that decelerates parks it against the
-- right edge for most of the fade.
local function sheenSweep(row)
  local peak = (row.quality and SHEEN_PEAK[row.quality]) or SHEEN_PEAK_DEFAULT
  local travel = PL.layout.width - SHEEN_WIDTH
  local function clear() row.sheen:SetAlpha(0) end
  return Sauce:Group({
    Sauce:Move(row.sheen, { 0, 0 }, { travel, 0 }, SHEEN_TIME, 'inOutSine'),
    Sauce:Sequence({
      Sauce:FadeTo(row.sheen, peak, SHEEN_TIME * 0.3, 'outQuad'),
      Sauce:FadeTo(row.sheen, 0, SHEEN_TIME * 0.7, 'inQuad'),
    }),
  }, { onFinish = clear, onCancel = clear })
end

-- Not Sauce:SlideOut: that fades with inQuad, which holds the card near full
-- opacity for most of its travel, so the row sliding up to replace it arrives
-- while it is still solid. The alpha here is front-loaded and finishes well
-- before the move does.
local function exitAnimation(row)
  local drift = DRIFT[PizzaLoot_config.slideOut] or DRIFT.left
  return Sauce:Group({
    Sauce:Move(row.card, { 0, 0 }, drift, EXIT_TIME, 'inCubic'),
    Sauce:FadeTo(row.card, 0, EXIT_FADE, 'outQuad'),
  }, {
    onFinish = function ()
      row.card:Hide()
      PL.row.release(row)
    end,
  })
end

local function iconPop(row)
  return Sauce:Sequence({
    Sauce:Delay(0.1),
    Sauce:Pulse(row.icon, 1.15, 0.25),
  })
end

local function stripPulse(row)
  local function set(strip, width) strip:SetWidth(width) end
  return Sauce:Sequence({
    Sauce:Delay(0.12),
    Sauce:Tween(row.strip, { type = 'custom', from = STRIP_WIDTH, to = STRIP_WIDTH + 2,
      duration = 0.12, easing = 'outQuad', setter = set }),
    Sauce:Tween(row.strip, { type = 'custom', from = STRIP_WIDTH + 2, to = STRIP_WIDTH,
      duration = 0.28, easing = 'outQuad', setter = set }),
  })
end

-- Not Sauce:Pulse: that re-reads the base size per call, so a two-leg pop
-- compounds into 1.04 squared on the way back down.
local function cardPop(row)
  local baseW, baseH = row.slot:GetWidth(), row.slot:GetHeight()
  local function set(card, scale)
    card:SetWidth(baseW * scale)
    card:SetHeight(baseH * scale)
  end
  return Sauce:Sequence({
    Sauce:Tween(row.card, { type = 'custom', from = 1, to = 1.04,
      duration = 0.14, easing = 'outQuad', setter = set }),
    Sauce:Tween(row.card, { type = 'custom', from = 1.04, to = 1,
      duration = 0.22, easing = 'inOutQuad', setter = set }),
  })
end

local function plainEntrance(row)
  return {
    Sauce:Group({
      Sauce:SlideIn(row.card, PizzaLoot_config.slideIn, ENTER_DISTANCE, ENTER_TIME, 'outQuint'),
      sheenSweep(row),
      iconPop(row),
    }),
  }
end

local function rareEntrance(row)
  return {
    Sauce:Group({
      Sauce:SlideIn(row.card, PizzaLoot_config.slideIn, ENTER_DISTANCE, ENTER_TIME, 'outQuint'),
      sheenSweep(row),
      iconPop(row),
      stripPulse(row),
    }),
    cardPop(row),
  }
end

-- Hold and exit are steps of the one sequence, not a polled timer, so a row
-- leaves exactly when it is due rather than on the next poll tick.
function proto:enter(onExpire)
  local steps = self.quality == PL.quality.RARE and rareEntrance(self) or plainEntrance(self)
  table.insert(steps, Sauce:Delay(self:holdTime() - FADE_LEAD))
  table.insert(steps, Sauce:FadeTo(self.card, AGED_ALPHA, FADE_LEAD, 'inQuad'))
  table.insert(steps, Sauce:Run(onExpire))
  table.insert(steps, exitAnimation(self))
  Sauce:Sequence(steps)
end

function proto:reset()
  Sauce:Stop(self.slot)
  Sauce:Stop(self.card)
  Sauce:Stop(self.sheen)
  Sauce:Stop(self.icon)
  Sauce:Stop(self.strip)

  self.slot:Hide()
  self.slot:ClearAllPoints()
  self.card:Hide()
  self.card:SetAlpha(1)
  self.card:SetWidth(self.slot:GetWidth())
  self.card:SetHeight(self.slot:GetHeight())
  self.card:ClearAllPoints()
  self.card:SetPoint('CENTER', self.slot, 'CENTER', 0, 0)

  self.sheen:SetAlpha(0)
  self.sheen:ClearAllPoints()
  self.sheen:SetPoint('LEFT', self.card, 'LEFT', 0, 0)

  self.icon:SetWidth(ICON_SIZE)
  self.icon:SetHeight(ICON_SIZE)
  self.strip:SetWidth(STRIP_WIDTH)

  self.y = nil
end
