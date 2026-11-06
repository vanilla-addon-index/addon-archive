local PT = PizzaTonno
local ui = PT.ui
-- The Journal's catches over time: per hour for the last day, per day for the last 30, per month for
-- the last year or since the first catch with a date (FishingBuddy's imports have none).
PT.almanac.timeline = {}
local timeline = PT.almanac.timeline

local HOUR, DAY = 3600, 86400
local MAX_BARS = 36
local CHART_HEIGHT = 70
local MONTHS = { 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' }
local RANGES = {
  { 'hours', '24 hours', 'Catches per hour', '24 hours ago', 'now' },
  { 'days', '30 days', 'Catches per day', '30 days ago', 'today' },
  { 'year', '1 year', 'Catches per month', '12 months ago', 'this month' },
  { 'all', 'All time', 'Catches per month', nil, 'this month' },
}

local chart, title, from, to, most, buckets, switchBar
local switches = {}

local function addItems(bucket, items)
  for id, n in pairs(items) do
    if id ~= 0 then bucket.items[id] = (bucket.items[id] or 0) + n end
  end
end

local function bucket(label)
  return { label = label, catches = 0, items = {}, seconds = 0 }
end

-- The last `hours` and `days`, kept until the history changes or another hour or day begins.
local kept = { hours = {}, days = {} }

local function keep(name, stamp, build)
  local entry = kept[name]
  if entry.version ~= PT.catches.version() or entry.stamp ~= stamp then
    entry.version, entry.stamp, entry.buckets = PT.catches.version(), stamp, build()
  end
  return entry.buckets
end

-- The last 24 hours, hour by hour, from the catch log: { label, catches, items, seconds } each.
local function hours()
  local now = time()
  local start = now - math.mod(now, HOUR) - 23 * HOUR
  local list = {}
  for i = 1, 24 do
    local t = start + (i - 1) * HOUR
    list[i] = bucket(date('%H:00', t) .. ' to ' .. date('%H:00', t + HOUR))
  end
  local log = PizzaTonno_catches.log
  for i = table.getn(log), 1, -1 do
    local catch = log[i]
    if catch.time < start then break end
    local entry = list[math.floor((catch.time - start) / HOUR) + 1]
    entry.catches = entry.catches + 1
    for _, id in ipairs(catch.items) do entry.items[id] = (entry.items[id] or 0) + 1 end
  end
  return list
end

function timeline.hours()
  return keep('hours', math.floor(time() / HOUR), hours)
end

local function lastDays()
  local list = {}
  for i = 1, 30 do
    local day = date('%Y-%m-%d', time() - (30 - i) * DAY)
    local catches, items, seconds = PT.catches.daily(day)
    list[i] = bucket(day)
    list[i].catches, list[i].seconds = catches, seconds
    addItems(list[i], items)
  end
  return list
end

-- Months as { year, month }, `count` of them up to this one.
local function lastMonths(count)
  local now = date('*t')
  local list = {}
  for i = count - 1, 0, -1 do
    local index = now.year * 12 + now.month - 1 - i
    table.insert(list, { math.floor(index / 12), math.mod(index, 12) + 1 })
  end
  return list
end

local function months(list)
  local byKey, result = {}, {}
  for i, month in ipairs(list) do
    result[i] = bucket(MONTHS[month[2]] .. ' ' .. month[1])
    byKey[string.format('%d-%02d', month[1], month[2])] = result[i]
  end
  for day in pairs(PizzaTonno_catches.days) do
    local entry = byKey[string.sub(day, 1, 7)]
    if entry then
      local catches, items, seconds = PT.catches.daily(day)
      entry.catches, entry.seconds = entry.catches + catches, entry.seconds + seconds
      addItems(entry, items)
    end
  end
  return result
end

-- Every month since the first one with a catch, at least the last 12, at most the last MAX_BARS.
local function allMonths()
  local first
  for day in pairs(PizzaTonno_catches.days) do
    if not first or day < first then first = day end
  end
  local now = date('*t')
  local count = 1
  if first then
    local year, month = tonumber(string.sub(first, 1, 4)), tonumber(string.sub(first, 6, 7))
    count = (now.year * 12 + now.month) - (year * 12 + month) + 1
  end
  return months(lastMonths(math.min(math.max(count, 12), MAX_BARS))), first
end

local function range()
  for _, entry in ipairs(RANGES) do
    if entry[1] == PizzaTonno_config.journalRange then return entry end
  end
  return RANGES[2]
end

local function tooltip(bar)
  local entry = buckets[bar.index]
  PT.tooltip.title(entry.label)
  PT.tooltip.line(entry.catches .. (entry.catches == 1 and ' catch' or ' catches')
    .. (entry.seconds > 0 and ' in ' .. PT.utils.duration(entry.seconds) or ''))
  local sorted = {}
  for id, n in pairs(entry.items) do table.insert(sorted, { id, n }) end
  table.sort(sorted, function (a, b) return a[2] > b[2] end)
  for i = 1, math.min(table.getn(sorted), 5) do
    PT.tooltip.line(sorted[i][2] .. 'x ' .. (PT.data.item(sorted[i][1]) or sorted[i][1]), ui.quality(sorted[i][1]))
  end
end

local function paintSwitches()
  local chosen = range()[1]
  for _, switch in ipairs(switches) do switch:setColor(switch.key == chosen and ui.ACCENT or ui.GREY) end
end

function timeline.build(parent, x, y, width, height)
  local box = CreateFrame('Frame', nil, parent)
  box:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
  box:SetWidth(width)
  box:SetHeight(height)
  ui.panel(box, 1, ui.CARD)
  title = ui.label(box, 10, 'TOPLEFT', 10, -8, ui.GREY)
  from = ui.label(box, 10, 'BOTTOMLEFT', 10, 6, ui.GREY)
  to = ui.label(box, 10, 'BOTTOMRIGHT', -10, 6, ui.GREY)
  most = ui.label(box, 10, 'TOPRIGHT', -10, -8, ui.GREY)
  chart = ui.bars(box, MAX_BARS, 10, width - 20, CHART_HEIGHT, tooltip)

  -- the range switch: the chosen one purple, the others grey and white under the mouse
  switchBar = CreateFrame('Frame', nil, box)
  switchBar:SetHeight(16)
  local left = 0
  for _, entry in ipairs(RANGES) do
    local key = entry[1]
    local switch = ui.link(switchBar, 10, ui.GREY, function ()
      PizzaTonno_config.journalRange = key
      timeline.refresh()
    end)
    switch.key = key
    switch:setText(entry[2])
    switch:SetPoint('LEFT', switchBar, 'LEFT', left, 0)
    left = left + switch:GetWidth() + 12
    table.insert(switches, switch)
  end
  switchBar:SetWidth(left - 12)
  switchBar:SetPoint('CENTER', box, 'TOP', 0, -13)
end

function timeline.refresh()
  local chosen = range()
  local key, first = chosen[1], nil
  if key == 'hours' then buckets = timeline.hours() end
  if key == 'days' then buckets = keep('days', date('%Y-%m-%d'), lastDays) end
  if key == 'year' then buckets = months(lastMonths(12)) end
  if key == 'all' then buckets, first = allMonths() end

  local count = table.getn(buckets)
  chart:layout(count, count > 24 and 3 or 4)
  local values = {}
  for i, entry in ipairs(buckets) do values[i] = entry.catches end
  local top = chart:set(values)

  title:SetText(chosen[3])
  from:SetText(chosen[4] or (first and buckets[1].label or ''))
  to:SetText(chosen[5])
  most:SetText(top > 0 and 'most: ' .. PT.utils.count(top) or 'no catches yet')
  paintSwitches()
end
