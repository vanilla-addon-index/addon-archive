local PT = PizzaTonno
local Sauce = PizzaSauce
PT.ui = {
  PANEL = { 0.05, 0.04, 0.07 },
  CARD = { 0.08, 0.07, 0.11 },
  LINE = { 0.17, 0.16, 0.21 },
  TRACK = { 0.1, 0.1, 0.13 },
  PLAIN = { 0.56, 0.54, 0.64 },
  ACCENT = { 0.63, 0.31, 1 },
  AMBER = { 0.94, 0.69, 0.29 },
  BLUE = { 0.35, 0.58, 0.95 },
  ICE = { 0.62, 0.85, 1 },
  -- summer coral and winter cyan, so neither passes for day's amber or night's blue
  SUMMER = { 1, 0.5, 0.38 },
  WINTER = { 0.4, 0.93, 0.93 },
  EVENT = { 1, 0.45, 0.75 },
  WHITE = { 0.95, 0.94, 0.97 },
  GREY = { 0.61, 0.6, 0.66 },
  -- the game's item quality colours, poor to legendary
  QUALITY = {
    [0] = { 0.62, 0.62, 0.62 },
    { 1, 1, 1 },
    { 0.12, 1, 0 },
    { 0, 0.44, 0.87 },
    { 0.64, 0.21, 0.93 },
    { 1, 0.5, 0 },
  },
  -- shipped with the addon (SIL Open Font License, fonts\OFL.txt), so it looks the same for everyone
  FONT = 'Interface\\AddOns\\PizzaTonno\\fonts\\Onest-Regular.ttf',
}
local ui = PT.ui

local ICONS = 'Interface\\Icons\\'
local SCROLL_TIME = 0.2

function ui.solid(parent, layer, color, alpha)
  local texture = parent:CreateTexture(nil, layer)
  texture:SetTexture(color[1], color[2], color[3], alpha or 1)
  return texture
end

function ui.label(parent, size, point, x, y, color)
  local text = parent:CreateFontString(nil, 'OVERLAY')
  text:SetFont(ui.FONT, size)
  text:SetPoint(point, parent, point, x, y)
  text:SetTextColor(color[1], color[2], color[3])
  return text
end

function ui.color(region, color)
  region:SetTextColor(color[1], color[2], color[3])
end

-- An item's quality colour, white for items the data doesn't know.
function ui.quality(itemId)
  local _, quality = PT.data.item(itemId)
  return ui.QUALITY[quality or 1] or ui.QUALITY[1]
end

-- A white tick with a dark rim, so it stays readable on any bar colour.
function ui.tick(parent, height)
  local mark = CreateFrame('Frame', nil, parent)
  mark:SetWidth(4)
  mark:SetHeight(height)
  ui.solid(mark, 'BACKGROUND', ui.PANEL):SetAllPoints()

  local core = ui.solid(mark, 'ARTWORK', ui.WHITE)
  core:SetPoint('TOPLEFT', mark, 'TOPLEFT', 1, -1)
  core:SetPoint('BOTTOMRIGHT', mark, 'BOTTOMRIGHT', -1, 1)
  return mark
end

-- The dark panel with a 1px border that every PizzaTonno window and card sits on.
function ui.panel(frame, alpha, color)
  ui.solid(frame, 'BACKGROUND', color or ui.PANEL, alpha):SetAllPoints()
  local edges = { { 'TOPLEFT', 'TOPRIGHT' }, { 'BOTTOMLEFT', 'BOTTOMRIGHT' }, { 'TOPLEFT', 'BOTTOMLEFT' },
    { 'TOPRIGHT', 'BOTTOMRIGHT' } }
  for i, edge in ipairs(edges) do
    local line = ui.solid(frame, 'BORDER', ui.LINE)
    line:SetPoint(edge[1], frame, edge[1], 0, 0)
    line:SetPoint(edge[2], frame, edge[2], 0, 0)
    if i <= 2 then line:SetHeight(1) else line:SetWidth(1) end
  end
end

local QUESTION_MARK = ICONS .. 'INV_Misc_QuestionMark'
-- kept once known; an item the client hasn't seen yet may still get its icon later
local icons = {}

-- An item's icon texture, the question mark for items without one.
function ui.icon(itemId)
  if icons[itemId] then return icons[itemId] end
  local _, _, icon = PT.data.item(itemId)
  if not icon or icon == '' then return QUESTION_MARK end
  icons[itemId] = ICONS .. icon
  return icons[itemId]
end

-- A small white triangle pointing left, or right when flipped.
function ui.triangle(parent, size, right)
  local texture = parent:CreateTexture(nil, 'ARTWORK')
  texture:SetTexture('Interface\\AddOns\\PizzaTonno\\img\\triangle')
  texture:SetWidth(size)
  texture:SetHeight(size)
  if right then texture:SetTexCoord(1, 0, 0, 1) end
  return texture
end

-- The arrow of a section that folds: down while open, right while shut.
function ui.caret(parent, size)
  local texture = parent:CreateTexture(nil, 'ARTWORK')
  texture:SetWidth(size)
  texture:SetHeight(size)
  function texture.setOpen(self, open)
    self:SetTexture('Interface\\AddOns\\PizzaTonno\\img\\' .. (open and 'triangle_down' or 'triangle'))
    if open then self:SetTexCoord(0, 1, 0, 1) else self:SetTexCoord(1, 0, 0, 1) end
  end
  return texture
end

local PEAK_SEASONS = {
  s = 'in summer',
  w = 'in winter',
  sw = 'in March, while summer and winter overlap',
  [''] = 'in September, between the seasons',
}

-- Where and when an item bites best of all: the chance, the place, and when if it matters
-- ('at night, in winter'), or nil.
function ui.peak(itemId)
  local chance, area, light, season = PT.spots.peak(itemId)
  if not area then return end
  local place = area.zone and area.name .. ', ' .. PT.data.area(area.zone).name or area.name
  local parts = {}
  if light then table.insert(parts, light == 'd' and 'by day' or 'at night') end
  if season then table.insert(parts, PEAK_SEASONS[season]) end
  return chance, place, table.getn(parts) > 0 and table.concat(parts, ', ') or nil
end

-- The mark of a tile that opens something when clicked: its top right corner filled purple.
function ui.corner(box)
  local corner = box:CreateTexture(nil, 'ARTWORK')
  corner:SetTexture('Interface\\AddOns\\PizzaTonno\\img\\corner')
  corner:SetWidth(14)
  corner:SetHeight(14)
  -- inside the 1px border
  corner:SetPoint('TOPRIGHT', box, 'TOPRIGHT', -1, -1)
  corner:SetVertexColor(ui.ACCENT[1], ui.ACCENT[2], ui.ACCENT[3])
  return corner
end

-- What the mouse's back and forward buttons do anywhere in a PizzaTonno window (set by the almanac).
ui.sideButtons = nil

function ui.sideButton()
  if ui.sideButtons and (arg1 == 'Button4' or arg1 == 'Button5') then ui.sideButtons(arg1) end
end

function ui.takeSideButtons(frame)
  frame:SetScript('OnMouseUp', ui.sideButton)
end

-- The key of the column under the mouse in a row with `columns`: { right edge, key } from the
-- left, the last one without an edge.
local function columnAt(frame)
  local x = GetCursorPosition() / frame:GetEffectiveScale() - frame:GetLeft()
  for _, column in ipairs(frame.columns) do
    if not column[1] or x < column[1] then return column[2] end
  end
end

local function followColumns()
  local column = columnAt(this)
  if column == this.column then return end
  this.column = column
  this.onEnter(this)
end

-- A faint highlight behind a row or button while the mouse is on it. A row with `columns` knows
-- which one the mouse is on (`column`) and redoes its tooltip when that changes.
function ui.hoverable(frame)
  frame:EnableMouse(true)
  frame.glow = ui.solid(frame, 'BORDER', ui.WHITE, 0.06)
  frame.glow:SetAllPoints()
  frame.glow:Hide()
  frame:SetScript('OnEnter', function ()
    this.glow:Show()
    if this.columns then
      this.column = columnAt(this)
      this:SetScript('OnUpdate', followColumns)
    end
    if this.onEnter then this.onEnter(this) end
  end)
  frame:SetScript('OnLeave', function ()
    this.glow:Hide()
    this:SetScript('OnUpdate', nil)
    PT.tooltip.hide()
  end)
  ui.takeSideButtons(frame)
end

-- Text that turns white under the mouse and runs `onClick`.
function ui.link(parent, size, color, onClick)
  local button = CreateFrame('Button', nil, parent)
  button.text = ui.label(button, size, 'LEFT', 0, 0, color)
  button.color = color
  button:SetHeight(size + 6)
  button:SetScript('OnEnter', function ()
    ui.color(this.text, ui.WHITE)
    if this.tip then
      PT.tooltip.open(this)
      PT.tooltip.title(this.tip)
      PT.tooltip.show()
    end
  end)
  button:SetScript('OnLeave', function ()
    ui.color(this.text, this.color)
    PT.tooltip.hide()
  end)
  button:SetScript('OnClick', onClick)
  ui.takeSideButtons(button)

  function button.setText(self, text)
    self.text:SetText(text)
    self:SetWidth(self.text:GetStringWidth())
  end

  function button.setColor(self, newColor)
    self.color = newColor
    ui.color(self.text, newColor)
  end
  return button
end

-- Up to `count` bars on a common baseline, each a frame so it can take the mouse for its tooltip:
-- `tooltip(bar)` fills it (bar.index, bar.value); without one they're just a picture. `layout(n, gap)` spreads the first n over the width,
-- `set(values)` sizes them against the largest and returns it.
function ui.bars(parent, count, x, width, height, tooltip)
  local chart = {}
  for i = 1, count do
    local bar = CreateFrame('Frame', nil, parent)
    bar:SetHeight(height)
    bar:EnableMouse(tooltip ~= nil)
    bar.fill = ui.solid(bar, 'ARTWORK', ui.ACCENT, 0.7)
    bar.fill:SetPoint('BOTTOMLEFT', bar, 'BOTTOMLEFT', 0, 0)
    bar.fill:SetPoint('BOTTOMRIGHT', bar, 'BOTTOMRIGHT', 0, 0)
    bar.glow = ui.solid(bar, 'BACKGROUND', ui.WHITE, 0.06)
    bar.glow:SetAllPoints()
    bar.glow:Hide()
    bar.index = i
    bar:SetScript('OnEnter', function ()
      this.glow:Show()
      PT.tooltip.open(this)
      tooltip(this)
      PT.tooltip.show()
    end)
    bar:SetScript('OnLeave', function ()
      this.glow:Hide()
      PT.tooltip.hide()
    end)
    ui.takeSideButtons(bar)
    chart[i] = bar
  end

  function chart.layout(self, shown, gap)
    local barWidth = (width - (shown - 1) * gap) / shown
    for i, bar in ipairs(self) do
      bar:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', x + (i - 1) * (barWidth + gap), 22)
      bar:SetWidth(barWidth)
      if i <= shown then bar:Show() else bar:Hide() end
    end
  end

  function chart.set(self, values)
    local most = 0
    for _, value in ipairs(values) do most = math.max(most, value) end
    for i, value in ipairs(values) do
      local bar = self[i]
      bar.value = value
      if value == 0 then
        bar.fill:Hide()
      else
        bar.fill:SetHeight(math.max(value / most * height, 2))
        bar.fill:Show()
      end
    end
    return most
  end
  return chart
end

-- A list that scrolls with the mouse wheel, gliding from row to row: `count` rows made by
-- `create(row)`, filled from the items by `fill(row, item)`. A thin thumb on the right shows where
-- the view is. One row more than fits waits below, and the scroll frame clips what sticks out.
function ui.list(parent, width, rowHeight, count, create, fill)
  local list = CreateFrame('ScrollFrame', nil, parent)
  list:SetWidth(width)
  list:SetHeight(rowHeight * count)
  local body = CreateFrame('Frame', nil, list)
  body:SetWidth(width)
  body:SetHeight(rowHeight * (count + 1))
  list:SetScrollChild(body)
  list:UpdateScrollChildRect()
  -- offset: the first row scrolled to; position: where the view is on its way there
  list.items, list.offset, list.position, list.rows = {}, 0, 0, {}

  local thumb = ui.solid(list, 'OVERLAY', ui.LINE)
  thumb:SetWidth(3)

  -- `gliding`: on the way from row to row, where the rows only need filling again when another item
  -- comes to the top
  local function draw(position, gliding)
    list.position = position
    local first = math.floor(position)
    list:SetVerticalScroll((position - first) * rowHeight)
    if not gliding or first ~= list.first then
      list.first = first
      for i, row in ipairs(list.rows) do
        local item = list.items[first + i]
        if item then
          fill(row, item)
          row:Show()
        else
          row:Hide()
        end
      end
    end

    local total = table.getn(list.items)
    if total <= count then
      thumb:Hide()
      return
    end
    local height = rowHeight * count * count / total
    thumb:SetHeight(height)
    thumb:SetPoint('TOPRIGHT', list, 'TOPRIGHT', 0, -(rowHeight * count - height) * position / (total - count))
    thumb:Show()
  end

  local function clamp()
    list.offset = math.max(math.min(list.offset, table.getn(list.items) - count), 0)
  end

  local function step(_, position)
    draw(position, true)
  end

  -- every notch of the wheel glides, so the list keeps one glide and replays it
  local glider = Sauce:Tween(list, { type = 'custom', duration = SCROLL_TIME, easing = 'outCubic', setter = step,
    defer = true })

  local function glide()
    clamp()
    Sauce:Stop(list)
    if list.offset == list.position then return draw(list.offset) end
    glider:SetFrom(list.position)
    glider:SetTo(list.offset)
    glider:Play()
  end

  local function scroll()
    list.offset = list.offset - arg1 * 3
    glide()
  end

  list:EnableMouseWheel(true)
  list:SetScript('OnMouseWheel', scroll)
  for i = 1, count + 1 do
    local row = CreateFrame('Button', nil, body)
    row:SetPoint('TOPLEFT', body, 'TOPLEFT', 0, -(i - 1) * rowHeight)
    row:SetWidth(width - 6)
    row:SetHeight(rowHeight)
    row:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    -- rows take the mouse for their tooltips, so they pass the wheel on
    row:EnableMouseWheel(true)
    row:SetScript('OnMouseWheel', scroll)
    create(row)
    list.rows[i] = row
  end

  function list.setItems(self, items, keepOffset)
    self.items = items
    Sauce:Stop(self)
    if not keepOffset then self.offset = 0 end
    clamp()
    draw(self.offset)
  end

  -- Straight to a row, without gliding (coming back to a view).
  function list.jump(self, offset)
    Sauce:Stop(self)
    self.offset = offset
    clamp()
    draw(self.offset)
  end

  -- Scrolls only as far as needed to leave two rows of room above and below the item.
  function list.reveal(self, index)
    local margin = 2
    if index - margin <= self.offset then
      self.offset = index - margin - 1
    elseif index + margin > self.offset + count then
      self.offset = index + margin - count
    end
    glide()
  end

  -- Scrolls the item to the top.
  function list.scrollTo(self, index)
    self.offset = index - 1
    glide()
  end

  list.redraw = function () draw(list.position) end
  return list
end
