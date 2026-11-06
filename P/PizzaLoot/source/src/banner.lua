local PL = PizzaLoot
local Sauce = PizzaSauce
PL.banner = {}

local WIDTH = 280
local HEIGHT = 48
local PAD = 10
local ICON_SIZE = 34
local ICON_GAP = 8
local QTY_GAP = 6
local OFFSET_Y = 180
local GLOW_TEXTURE = 'Interface\\AddOns\\PizzaLoot\\img\\glow'
local GLOW_EDGE = 12
local ICON_CROP = 0.08
local SHEEN_WIDTH = 70
local SHEEN_TIME = 0.7

Sauce:RegisterType('glow', {
  init = function (target, from)
    return from or 0
  end,
  apply = function (target, from, to, t)
    local color = target.color
    target:SetBackdropBorderColor(color[1], color[2], color[3], from + (to - from) * t)
  end,
})

local frame = CreateFrame('Frame', nil, UIParent)
frame:SetWidth(WIDTH)
frame:SetHeight(HEIGHT)
frame:SetFrameStrata('DIALOG')
frame:Hide()

local backdrop = frame:CreateTexture(nil, 'BACKGROUND')
backdrop:SetAllPoints()

PL.utils.border(frame)
local INSET = PL.utils.pixel()

local glow = CreateFrame('Frame', nil, frame)
glow:SetAllPoints(frame)
glow:SetBackdrop({ edgeFile = GLOW_TEXTURE, edgeSize = GLOW_EDGE })
glow.color = { 1, 1, 1 }
glow:SetBackdropBorderColor(1, 1, 1, 0)

local strip = frame:CreateTexture(nil, 'ARTWORK')
strip:SetWidth(4)
strip:SetPoint('TOPLEFT', frame, 'TOPLEFT', INSET, -INSET)
strip:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', INSET, INSET)

local icon = frame:CreateTexture(nil, 'ARTWORK')
icon:SetWidth(ICON_SIZE)
icon:SetHeight(ICON_SIZE)
icon:SetPoint('LEFT', frame, 'LEFT', PAD, 0)
icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

local name = frame:CreateFontString(nil, 'OVERLAY')
name:SetFont(STANDARD_TEXT_FONT, 15)
name:SetShadowColor(0, 0, 0, 1)
name:SetShadowOffset(1, -1)
name:SetPoint('LEFT', icon, 'RIGHT', ICON_GAP, 0)

local qty = frame:CreateFontString(nil, 'OVERLAY')
qty:SetFont(STANDARD_TEXT_FONT, 12)
qty:SetShadowColor(0, 0, 0, 1)
qty:SetShadowOffset(1, -1)
qty:SetPoint('LEFT', name, 'RIGHT', QTY_GAP, 0)
qty:SetTextColor(0.8, 0.8, 0.8, 1)

local flash = frame:CreateTexture(nil, 'OVERLAY')
flash:SetAllPoints()
flash:SetTexture(1, 1, 1, 1)
flash:SetVertexColor(1, 1, 1, 0)

-- Off the banner for the same reason as the row sheen: the banner's slide,
-- flash and fade would overwrite its alpha.
local sheen = CreateFrame('Frame', nil, UIParent)
sheen:SetFrameStrata('DIALOG')
sheen:SetWidth(SHEEN_WIDTH)
sheen:SetHeight(HEIGHT)
sheen:SetPoint('LEFT', frame, 'LEFT', 0, 0)
sheen:SetFrameLevel(frame:GetFrameLevel() + 3)
sheen:SetAlpha(0)

local sheenLead = sheen:CreateTexture(nil, 'OVERLAY')
sheenLead:SetWidth(SHEEN_WIDTH / 2)
sheenLead:SetHeight(HEIGHT)
sheenLead:SetPoint('LEFT', sheen, 'LEFT', 0, 0)

local sheenTrail = sheen:CreateTexture(nil, 'OVERLAY')
sheenTrail:SetWidth(SHEEN_WIDTH / 2)
sheenTrail:SetHeight(HEIGHT)
sheenTrail:SetPoint('RIGHT', sheen, 'RIGHT', 0, 0)

local function sheenSweep(peak)
  local travel = frame:GetWidth() - SHEEN_WIDTH
  local function clear() sheen:SetAlpha(0) end
  return Sauce:Group({
    Sauce:Move(sheen, { 0, 0 }, { travel, 0 }, SHEEN_TIME, 'inOutSine'),
    Sauce:Sequence({
      Sauce:FadeTo(sheen, peak, SHEEN_TIME * 0.3, 'outQuad'),
      Sauce:FadeTo(sheen, 0, SHEEN_TIME * 0.7, 'inQuad'),
    }),
  }, { onFinish = clear, onCancel = clear })
end

local function glowFade(from, to, duration, easing)
  return Sauce:Tween(glow, { type = 'glow', from = from, to = to, duration = duration, easing = easing })
end

local function fitToContent()
  local qtyWidth = qty:GetStringWidth()
  local extra = qtyWidth > 0 and (QTY_GAP + qtyWidth) or 0
  frame:SetWidth(PAD + ICON_SIZE + ICON_GAP + name:GetStringWidth() + extra + PAD)
end

local function reset()
  PL.confetti.stop()
  Sauce:Stop(frame)
  Sauce:Stop(flash)
  Sauce:Stop(glow)
  glow:SetBackdropBorderColor(glow.color[1], glow.color[2], glow.color[3], 0)

  frame:Hide()
  frame:SetAlpha(1)
  frame:SetWidth(WIDTH)
  frame:SetHeight(HEIGHT)
  frame:ClearAllPoints()
  frame:SetPoint('CENTER', UIParent, 'CENTER', 0, OFFSET_Y)
  flash:SetVertexColor(1, 1, 1, 0)

  Sauce:Stop(sheen)
  sheen:SetAlpha(0)
  sheen:ClearAllPoints()
  sheen:SetPoint('LEFT', frame, 'LEFT', 0, 0)
end

reset()

function PL.banner.show(notice)
  reset()

  local r, g, b = notice.accent[1], notice.accent[2], notice.accent[3]
  local legendary = notice.quality == PL.quality.LEGENDARY

  PL.utils.tint(backdrop, notice.accent)
  strip:SetTexture(r, g, b, 1)
  name:SetTextColor(r, g, b, 1)
  name:SetText(notice.name)
  icon:SetTexture(notice.icon)
  qty:SetText(notice.count and notice.count > 1 and ('x' .. notice.count) or '')
  fitToContent()
  glow.color = notice.accent

  local sr, sg, sb = (r + 1) / 2, (g + 1) / 2, (b + 1) / 2
  sheenLead:SetTexture(1, 1, 1, 1)
  sheenLead:SetGradientAlpha('HORIZONTAL', sr, sg, sb, 0, sr, sg, sb, 1)
  sheenTrail:SetTexture(1, 1, 1, 1)
  sheenTrail:SetGradientAlpha('HORIZONTAL', sr, sg, sb, 1, sr, sg, sb, 0)

  local peak = legendary and 0.9 or 0.7
  local low, high = peak * 0.3, peak * 0.7

  PL.confetti.burst(0, OFFSET_Y, notice.accent, legendary)

  local steps = {
    Sauce:Group({
      Sauce:SlideIn(frame, 'UP', 80, 0.5, 'outBack'),
      Sauce:Sequence({
        Sauce:Color(flash, { r, g, b, 0 }, { 1, 1, 1, 0.7 }, 0.1),
        Sauce:Color(flash, { 1, 1, 1, 0.7 }, { r, g, b, 0 }, 0.5, 'outQuad'),
      }),
      Sauce:Sequence({
        glowFade(0, peak, 0.15),
        glowFade(peak, peak * 0.4, 0.4, 'outQuad'),
      }),
      Sauce:Sequence({
        Sauce:Delay(0.12),
        sheenSweep(legendary and 0.5 or 0.38),
      }),
    }),
    Sauce:Shake(frame, legendary and 8 or 5, 0.35),
  }

  -- A second, slower pass partway through the hold, so the banner keeps moving
  -- while it sits there instead of going static the way the rows never do.
  table.insert(steps, Sauce:Group({
    Sauce:Sequence({ Sauce:Delay(0.5), sheenSweep(legendary and 0.35 or 0.26) }),
    Sauce:Sequence({
      glowFade(low, high, 0.3, 'outQuad'),
      glowFade(high, low, 0.3, 'inQuad'),
    }),
  }))

  for _ = 1, (legendary and 4 or 2) do
    table.insert(steps, Sauce:Sequence({
      glowFade(low, high, 0.25, 'outQuad'),
      glowFade(high, low, 0.25, 'inQuad'),
    }))
  end

  table.insert(steps, Sauce:Delay(legendary and 2.5 or 1.8))
  if legendary then
    table.insert(steps, Sauce:Flash(frame, 3, 0.9))
  end

  table.insert(steps, Sauce:Group({
    glowFade(low, 0, 0.45),
    Sauce:SlideOut(frame, 'UP', 60, 0.45, 'inCubic', { onFinish = reset }),
  }))

  Sauce:Sequence(steps)
end
