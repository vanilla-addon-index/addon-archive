local PT = PizzaTonno
local ui = PT.ui
local tab = PT.almanac.addTab('calendar', 'Calendar')

local PADDING, INNER, GAP = 14, 610, 10
local DAY = 86400
local MONTHS = { 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' }
local MONTH_DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
-- where the year and day strips start inside their cards, and how wide they are
local YEAR_X, YEAR_WIDTH = 180, 420
local CLOCK_WIDTH = 360
local HOURS_X, HOURS_WIDTH = 150, 196
local SEASON_ROWS = {
  { 's', 'summer', 'Summer', ui.SUMMER },
  { 'w', 'winter', 'Winter', ui.WINTER },
}
local CONTINENT_ROWS = { 0, 1 }

local seasonRows, clockRows, dayFish, nightFish, upcoming = {}, {}, nil, nil, {}
local yearTick

local function color(region, c)
  region:SetTextColor(c[1], c[2], c[3])
end

local function card(parent, x, y, width, height, caption)
  local box = CreateFrame('Frame', nil, parent)
  box:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
  box:SetWidth(width)
  box:SetHeight(height)
  ui.panel(box, 1, ui.CARD)
  ui.label(box, 10, 'TOPLEFT', 10, -8, ui.GREY):SetText(caption)
  return box
end

local function isLeap(year)
  return math.mod(year, 4) == 0 and (math.mod(year, 100) ~= 0 or math.mod(year, 400) == 0)
end

-- This year on the player's clock: its first second and its length in days.
local function thisYear()
  local now = date('*t')
  local start = time() - (now.yday - 1) * DAY - now.hour * 3600 - now.min * 60 - now.sec
  return start, isLeap(now.year) and 366 or 365, now.year
end

-- Pieces of the year the event runs in, as { from, to } fractions of the year.
local function yearParts(event)
  local start, days = thisYear()
  local parts, from = {}, nil
  for day = 0, days do
    local running = day < days and PT.clock.event(event, start + day * DAY + DAY / 2)
    if running and not from then from = day end
    if not running and from then
      table.insert(parts, { from / days, day / days })
      from = nil
    end
  end
  return parts
end

local function names(condition)
  local list, seen = {}, {}
  for _, area in pairs(PT.data.areas) do
    for _, row in ipairs(area.loot or {}) do
      if row[4] == condition and not seen[row[1]] and PT.spots.condition(row[1]) == condition then
        seen[row[1]] = true
        table.insert(list, (PT.data.item(row[1])))
      end
    end
  end
  table.sort(list)
  return table.concat(list, ', ')
end

local function strip(parent, x, y, width, height)
  local track = ui.solid(parent, 'BORDER', ui.TRACK)
  track:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
  track:SetWidth(width)
  track:SetHeight(height)
  return track
end

local function part(parent, track, from, to, c, width, height)
  local piece = ui.solid(parent, 'ARTWORK', c, 0.7)
  piece:SetPoint('LEFT', track, 'LEFT', from * width, 0)
  piece:SetWidth(math.max((to - from) * width, 1))
  piece:SetHeight(height)
  return piece
end

local function buildSeasons(frame)
  local box = card(frame, PADDING, -14, INNER, 132, 'Seasons')

  local _, days, year = thisYear()
  local day = 0
  for i, month in ipairs(MONTHS) do
    local length = MONTH_DAYS[i] + (i == 2 and isLeap(year) and 1 or 0)
    local label = ui.label(box, 10, 'TOP', 0, 0, ui.GREY)
    label:SetPoint('TOP', box, 'TOPLEFT', YEAR_X + (day + length / 2) / days * YEAR_WIDTH, -10)
    label:SetText(month)
    day = day + length
  end

  -- each season: its name, its fish and when it turns, next to its bar
  for i, season in ipairs(SEASON_ROWS) do
    local y = -28 - (i - 1) * 50
    local row = {}
    ui.label(box, 12, 'TOPLEFT', 10, y, season[4]):SetText(season[3])
    ui.label(box, 11, 'TOPLEFT', 10, y - 15, ui.WHITE):SetText(names(season[1]))
    row.when = ui.label(box, 10, 'TOPLEFT', 10, y - 29, ui.GREY)
    row.track = strip(box, YEAR_X, y - 8, YEAR_WIDTH, 18)
    for _, piece in ipairs(yearParts(season[2])) do
      part(box, row.track, piece[1], piece[2], season[4], YEAR_WIDTH, 18)
    end
    row.event = season[2]
    seasonRows[i] = row
  end
  -- today, one tick through both bars
  yearTick = ui.tick(box, 50 + 18 + 10)
end

local function buildClocks(frame)
  local box = card(frame, PADDING, -158, CLOCK_WIDTH, 168, 'Day and night, zone time')
  for i, hour in ipairs({ '00', '06', '12', '18', '24' }) do
    local label = ui.label(box, 10, 'TOP', 0, 0, ui.GREY)
    label:SetPoint('TOP', box, 'TOPLEFT', HOURS_X + (i - 1) / 4 * HOURS_WIDTH, -24)
    label:SetText(hour)
  end

  for i, map in ipairs(CONTINENT_ROWS) do
    local y = -40 - (i - 1) * 36
    local row = { map = map }
    ui.label(box, 12, 'TOPLEFT', 10, y, ui.WHITE):SetText(PT.almanac.continent(map))
    row.time = ui.label(box, 10, 'TOPLEFT', 10, y - 15, ui.GREY)
    row.time:SetWidth(HOURS_X - 20)
    row.time:SetJustifyH('LEFT')
    local track = strip(box, HOURS_X, y - 4, HOURS_WIDTH, 14)
    part(box, track, 0, 0.25, ui.BLUE, HOURS_WIDTH, 14)
    part(box, track, 0.25, 0.75, ui.AMBER, HOURS_WIDTH, 14)
    part(box, track, 0.75, 1, ui.BLUE, HOURS_WIDTH, 14)
    row.track = track
    row.tick = ui.tick(box, 20)
    clockRows[i] = row
  end

  dayFish = ui.label(box, 10, 'TOPLEFT', 10, -116, ui.AMBER)
  nightFish = ui.label(box, 10, 'TOPLEFT', 10, -136, ui.BLUE)
  for _, text in ipairs({ dayFish, nightFish }) do
    text:SetWidth(CLOCK_WIDTH - 20)
    text:SetJustifyH('LEFT')
  end
  dayFish:SetText('By day (06-18): ' .. names('d'))
  nightFish:SetText('At night: ' .. names('n'))
end

local function buildUpcoming(frame)
  local x = PADDING + CLOCK_WIDTH + GAP
  local box = card(frame, x, -158, INNER - CLOCK_WIDTH - GAP, 168, 'Coming up')
  for i = 1, 4 do
    local y = -26 - (i - 1) * 34
    upcoming[i] = {
      name = ui.label(box, 12, 'TOPLEFT', 10, y, ui.WHITE),
      when = ui.label(box, 11, 'TOPRIGHT', -10, y, ui.ACCENT),
      date = ui.label(box, 10, 'TOPLEFT', 10, y - 15, ui.GREY),
    }
  end
end

function tab.build(frame)
  buildSeasons(frame)
  buildClocks(frame)
  buildUpcoming(frame)
end

local function dateText(at)
  return date('%a, %b ', at) .. tonumber(date('%d', at))
end

local function fillUpcoming()
  local events = {}
  local function add(name, seconds, dateLine)
    table.insert(events, { name = name, seconds = seconds, date = dateLine })
  end

  local starts, _, running, seconds = PT.almanac.extravaganza()
  add(running and 'Extravaganza ends' or 'Stranglethorn Extravaganza', seconds,
    dateText(starts) .. ', ' .. PT.almanac.extravaganzaHours())
  for _, season in ipairs(SEASON_ROWS) do
    local on, left = PT.clock.event(season[2])
    add(season[3] .. (on and ' ends' or ' starts'), left, dateText(time() + left))
  end
  table.sort(events, function (a, b) return a.seconds < b.seconds end)

  for i, line in ipairs(upcoming) do
    local event = events[i]
    line.name:SetText(event and event.name or '')
    line.when:SetText(event and 'in ' .. PT.utils.duration(event.seconds) or '')
    line.date:SetText(event and event.date or '')
  end
end

function tab.refresh()
  local yearStart, days = thisYear()
  local now = (time() - yearStart) / (days * DAY)
  yearTick:SetPoint('TOP', seasonRows[1].track, 'TOPLEFT', now * YEAR_WIDTH, 5)
  for _, row in ipairs(seasonRows) do
    local running, seconds = PT.clock.event(row.event)
    row.when:SetText((running and 'Ends ' or 'Starts ') .. PT.almanac.date(seconds) .. ', in '
      .. PT.utils.duration(seconds))
  end

  for _, row in ipairs(clockRows) do
    local hour, minute = PT.clock.zoneTime(row.map)
    local day = PT.clock.isDay(hour)
    row.time:SetText((day and 'Day, night in ' or 'Night, day in ')
      .. PT.utils.duration(PT.clock.untilFlip(hour, minute) * 60))
    color(row.time, day and ui.AMBER or ui.BLUE)
    row.tick:SetPoint('CENTER', row.track, 'LEFT', (hour * 60 + minute) / 1440 * HOURS_WIDTH, 0)
  end

  fillUpcoming()
end
