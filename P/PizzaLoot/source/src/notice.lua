local PL = PizzaLoot
PL.notice = {}

local white = { 1, 1, 1 }
local missingIcon = 'Interface\\Icons\\INV_Misc_QuestionMark'

local function qualityColor(quality)
  local c = ITEM_QUALITY_COLORS[quality] or ITEM_QUALITY_COLORS[1]
  return { c.r, c.g, c.b }
end

function PL.notice.item(name, quality, count, icon)
  local color = qualityColor(quality)
  return {
    name = name,
    icon = icon or missingIcon,
    count = count,
    quality = quality,
    accent = color,
    label = color,
  }
end

function PL.notice.money(total)
  local color, icon = PL.money.coin(total)
  return {
    name = PL.money.format(total),
    icon = icon,
    accent = color,
    label = white,
  }
end
