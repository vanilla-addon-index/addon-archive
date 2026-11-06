local PT = PizzaTonno
local ui = PT.ui
-- The Journal's full lists behind its tiles: every catch caught, every spot fished, the catch log.
PT.almanac.lists = {}
local lists = PT.almanac.lists

local PADDING, INNER = 14, 610
local ROWS, ROW_HEIGHT = 15, 25
local TITLES = {
  fish = 'Everything you caught',
  spots = 'Every spot you fished',
  log = 'Catch log',
}

local page, title, note, list
local view

local function createRow(row)
  ui.hoverable(row)
  row.time = ui.label(row, 10, 'LEFT', 4, 0, ui.GREY)
  row.icon = row:CreateTexture(nil, 'ARTWORK')
  row.icon:SetWidth(16)
  row.icon:SetHeight(16)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = ui.label(row, 11, 'LEFT', 0, 0, ui.WHITE)
  row.mark = ui.solid(row, 'ARTWORK', ui.ACCENT)
  row.mark:SetPoint('LEFT', row, 'LEFT', 0, 0)
  row.mark:SetWidth(2)
  row.mark:SetHeight(16)
  row.share = ui.label(row, 10, 'RIGHT', -70, 0, ui.GREY)
  row.right = ui.label(row, 11, 'RIGHT', -6, 0, ui.WHITE)
  row.onEnter = function (self)
    if self.entry.id then PT.almanac.fishTooltip(self, self.entry.id) end
  end
  row:SetScript('OnClick', function ()
    local entry = this.entry
    if entry.id then return PT.almanac.clickFish(entry.id) end
    if entry.area then PT.almanac.open('places', entry.area.id) end
  end)
end

-- 'Oct 1, 19:33' on the player's clock
local function when(t)
  return date('%b ', t) .. tonumber(date('%d', t)) .. date(', %H:%M', t)
end

local function fillRow(row, entry)
  row.entry = entry
  local x = view == 'log' and 92 or 4
  row.time:SetText(view == 'log' and when(entry.time) or '')
  row.icon:SetPoint('LEFT', row, 'LEFT', x, 0)
  row.name:SetPoint('LEFT', row, 'LEFT', entry.id and x + 22 or x, 0)
  if entry.id and PizzaTonno_config.watch[entry.id] then row.mark:Show() else row.mark:Hide() end
  if entry.id then
    row.icon:SetTexture(ui.icon(entry.id))
    row.icon:Show()
    row.name:SetText((PT.data.item(entry.id) or 'Item ' .. entry.id) .. (entry.more or ''))
    ui.color(row.name, ui.quality(entry.id))
  else
    row.icon:Hide()
    row.name:SetText(entry.name)
    ui.color(row.name, ui.WHITE)
  end
  row.share:SetText(entry.share or '')
  row.right:SetText(entry.right or '')
  ui.color(row.right, view == 'log' and ui.GREY or ui.WHITE)
end

function lists.build(frame)
  page = CreateFrame('Frame', nil, frame)
  page:SetAllPoints(frame)
  page:Hide()

  local back = ui.link(page, 11, ui.GREY, function () PT.almanac.open('journal', false) end)
  back:setText('Journal')
  back:SetPoint('TOPLEFT', page, 'TOPLEFT', PADDING + 12, -8)
  local arrow = ui.triangle(page, 9)
  arrow:SetPoint('RIGHT', back, 'LEFT', -3, 0)
  arrow:SetVertexColor(ui.GREY[1], ui.GREY[2], ui.GREY[3])

  title = ui.label(page, 15, 'TOPLEFT', PADDING, -30, ui.WHITE)
  note = ui.label(page, 10, 'TOPLEFT', PADDING, -49, ui.GREY)
  list = ui.list(page, INNER, ROW_HEIGHT, ROWS, createRow, fillRow)
  list:SetPoint('TOPLEFT', page, 'TOPLEFT', PADDING, -68)
end

local function byCount(counts, entry)
  local entries, total = {}, 0
  for key, n in pairs(counts) do
    total = total + n
    table.insert(entries, entry(key, n))
  end
  table.sort(entries, function (a, b) return a.n > b.n end)
  return entries, total
end

local function fishEntries(items)
  local entries, total = byCount(items, function (id, n)
    return { id = id, n = n, right = PT.utils.count(n) }
  end)
  for _, entry in ipairs(entries) do entry.share = PT.utils.percent(entry.n / total) end
  return entries, PT.utils.count(table.getn(entries)) .. ' different catches. Share of all you caught on the right.'
end

local function spotEntries(spots)
  local counts = {}
  for _, spot in pairs(spots) do counts[spot] = spot.n end
  local entries = byCount(counts, function (spot, n)
    return { name = spot.subzone == '' and spot.zone or spot.subzone .. ', ' .. spot.zone, n = n,
      area = PT.data.spot(spot.zone, spot.subzone), right = PT.utils.count(n) .. (n == 1 and ' catch' or ' catches') }
  end)
  return entries, 'Open water, FishingBuddy imports included. Click one for its loot.'
end

local function logEntries()
  local log, entries = PizzaTonno_catches.log, {}
  for i = table.getn(log), 1, -1 do
    local catch = log[i]
    local others = table.getn(catch.items) - 1
    table.insert(entries, { time = catch.time, id = catch.items[1], more = others > 0 and ' +' .. others or nil,
      right = (catch.subzone == '' and catch.zone or catch.subzone .. ', ' .. catch.zone)
        .. (catch.pool and ', pool' or '') })
  end
  local first = log[1]
  return entries, first and 'Every catch since ' .. when(first.time) .. ', newest first.'
    or 'Every catch from now on lands here.'
end

function lists.list()
  return list
end

-- `view` 'fish', 'spots' or 'log', or nil to hide the page; `items` and `spots` from the Journal.
function lists.show(newView, items, spots, fresh)
  view = newView
  if not view then return page:Hide() end
  page:Show()
  title:SetText(TITLES[view])
  local entries, text
  if view == 'fish' then entries, text = fishEntries(items) end
  if view == 'spots' then entries, text = spotEntries(spots) end
  if view == 'log' then entries, text = logEntries() end
  note:SetText(text)
  list:setItems(entries, not fresh)
end
