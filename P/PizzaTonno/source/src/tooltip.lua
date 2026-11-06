local PT = PizzaTonno
local ui = PT.ui
PT.tooltip = {}
local tooltip = PT.tooltip

-- The addon's own tooltip rather than the game's: the game's grows with its longest line, this one
-- can keep one width and wrap, and set off its top part.
local WIDTH, PADDING, SPACING, GAP = 250, 10, 3, 7
-- the band behind the focus lines reaches this far past them, and keeps as much again to its neighbours
local BAND = 5
local TITLE_SIZE, SIZE, EYE_SIZE = 13, 11, 14
local SIDES = {
  right = { 'BOTTOMLEFT', 'TOPRIGHT' },
  left = { 'BOTTOMRIGHT', 'TOPLEFT' },
  below = { 'TOP', 'BOTTOM' },
}

local frame = CreateFrame('Frame', nil, UIParent)
frame:SetFrameStrata('TOOLTIP')
frame:SetClampedToScreen(true)
frame:Hide()
ui.panel(frame, 0.96)
local band = ui.solid(frame, 'BORDER', ui.ACCENT, 0.16)
local eye = frame:CreateTexture(nil, 'ARTWORK')
eye:SetTexture('Interface\\AddOns\\PizzaTonno\\img\\eye')
eye:SetVertexColor(ui.ACCENT[1], ui.ACCENT[2], ui.ACCENT[3])
eye:SetWidth(EYE_SIZE)
eye:SetHeight(EYE_SIZE)
eye:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -PADDING + 1, -PADDING + 1)

-- the first `count` of them, each { text, color, size, right, rightColor } or { gap = true }; kept
-- and refilled, since every move of the mouse along a row redoes the tooltip
local entries, count, fixed, watched, focusFrom, focusTo = {}, 0
local lefts, rights = {}, {}

local function add(text, color, size, right, rightColor, gap)
  count = count + 1
  local entry = entries[count] or {}
  entries[count] = entry
  entry.text, entry.color, entry.size, entry.right, entry.rightColor, entry.gap = text, color, size, right, rightColor, gap
end

local function text(pool, i, justify)
  if not pool[i] then
    pool[i] = frame:CreateFontString(nil, 'OVERLAY')
    pool[i]:SetJustifyH(justify)
  end
  return pool[i]
end

-- `fixed`: always the full width, for tooltips that change while the mouse moves along a row.
function tooltip.open(owner, side, isFixed)
  local points = SIDES[side or 'right']
  frame:ClearAllPoints()
  frame:SetPoint(points[1], owner, points[2], 0, 0)
  count, fixed, watched, focusFrom, focusTo = 0, isFixed, false, nil, nil
end

function tooltip.title(text, color)
  add(text, color or ui.WHITE, TITLE_SIZE)
end

-- The purple eye at the title's right.
function tooltip.watched()
  watched = true
end

function tooltip.line(text, color)
  add(text, color or ui.WHITE)
end

-- A label on the left, a value on the right.
function tooltip.pair(left, right, leftColor, rightColor)
  add(left, leftColor or ui.GREY, nil, right, rightColor or ui.WHITE)
end

function tooltip.gap()
  add(nil, nil, nil, nil, nil, true)
end

-- Lines ({ text, color }) on a faint purple band: what the mouse is on, said first.
function tooltip.focus(lines)
  focusFrom = count + 1
  for _, line in ipairs(lines) do tooltip.line(line[1], line[2]) end
  focusTo = count
end

function tooltip.hide()
  frame:Hide()
end

local function fill(i, entry)
  local left, right = text(lefts, i, 'LEFT'), text(rights, i, 'RIGHT')
  left:SetFont(ui.FONT, entry.size or SIZE)
  left:SetText(entry.text)
  ui.color(left, entry.color)
  right:SetFont(ui.FONT, SIZE)
  right:SetText(entry.right or '')
  if entry.right then ui.color(right, entry.rightColor) end
  -- what the line needs besides its own text: the value on its right, or the eye beside the title
  local beside = entry.right and right:GetStringWidth() + 12 or i == 1 and watched and EYE_SIZE + 6 or 0
  return left, right, beside
end

local function naturalWidth()
  local width = 0
  for i = 1, count do
    local entry = entries[i]
    if not entry.gap then
      local left, _, beside = fill(i, entry)
      width = math.max(width, left:GetStringWidth() + beside)
    end
  end
  return math.min(math.ceil(width), WIDTH)
end

function tooltip.show()
  local width = fixed and WIDTH or naturalWidth()
  local y, bandTop = PADDING, nil
  for i = 1, count do
    local entry = entries[i]
    local left, right = text(lefts, i, 'LEFT'), text(rights, i, 'RIGHT')
    if entry.gap then
      left:Hide()
      right:Hide()
      y = y + GAP
    else
      if i == focusFrom then
        y = y + 2 * BAND - SPACING
        bandTop = y - BAND
      end
      local _, _, beside = fill(i, entry)
      left:SetWidth(width - beside)
      left:ClearAllPoints()
      left:SetPoint('TOPLEFT', frame, 'TOPLEFT', PADDING, -y)
      right:ClearAllPoints()
      right:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -PADDING, -y)
      left:Show()
      right:Show()
      -- wrapped text is as tall as its lines
      y = y + left:GetHeight() + SPACING
      if i == focusTo then
        band:SetPoint('TOPLEFT', frame, 'TOPLEFT', 1, -bandTop)
        band:SetPoint('BOTTOMRIGHT', frame, 'TOPRIGHT', -1, -(y - SPACING + BAND))
        y = y + 2 * BAND - SPACING
      end
    end
  end
  for i = count + 1, table.getn(lefts) do
    lefts[i]:Hide()
    rights[i]:Hide()
  end
  if focusFrom then band:Show() else band:Hide() end
  if watched then eye:Show() else eye:Hide() end
  frame:SetWidth(width + 2 * PADDING)
  frame:SetHeight(y - SPACING + PADDING)
  frame:Show()
end

-- The block every fish tooltip ends with: where and when it bites best of all.
function tooltip.best(itemId)
  local chance, place, when = ui.peak(itemId)
  if not chance then return end
  tooltip.gap()
  tooltip.pair('Best of all', PT.utils.percent(chance))
  tooltip.line(place .. (when and ', ' .. when or ''), ui.GREY)
end
