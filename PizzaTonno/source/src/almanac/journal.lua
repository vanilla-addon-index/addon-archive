local PT = PizzaTonno
local ui = PT.ui
local tab = PT.almanac.addTab('journal', 'Journal')

local PADDING, INNER, GAP = 14, 610, 10
local CHART_HEIGHT = 70
local TOP_ROWS = 5
-- each stat tile, and the full list it opens
local STATS = { { 'Catches', 'log' }, { 'Fish collected', 'fish' }, { 'Time fished' }, { 'Spots fished', 'spots' } }
local SEE_ALL = { 'fish', 'spots' }

local stats, hourBars, topFish, topSpots = {}, nil, {}, {}
local hourMax, summary
local view

local function card(parent, x, y, width, height, caption)
  local box = CreateFrame('Button', nil, parent)
  box:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
  box:SetWidth(width)
  box:SetHeight(height)
  ui.panel(box, 1, ui.CARD)
  ui.label(box, 10, 'TOPLEFT', 10, -8, ui.GREY):SetText(caption)
  return box
end

local function hourTooltip(bar)
  local hour = bar.index - 1
  PT.tooltip.title(string.format('%02d:00 to %02d:00 zone time', hour, hour + 1))
  PT.tooltip.line(PT.utils.count(bar.value) .. (bar.value == 1 and ' catch' or ' catches'))
end

-- A tile that opens one of the full lists: lights up under the mouse, the purple corner says so.
local function opens(box, target)
  ui.corner(box)
  ui.hoverable(box)
  box:SetScript('OnClick', function () PT.almanac.open('journal', target) end)
end

local function buildStats(frame)
  local width = (INNER - 3 * GAP) / 4
  for i, stat in ipairs(STATS) do
    local box = card(frame, PADDING + (i - 1) * (width + GAP), -14, width, 56, stat[1])
    box.value = ui.label(box, 16, 'TOPLEFT', 10, -21, ui.WHITE)
    box.sub = ui.label(box, 10, 'TOPLEFT', 10, -40, ui.GREY)
    if stat[2] then opens(box, stat[2]) else box:EnableMouse(false) end
    stats[i] = box
  end
end

local function buildHours(frame)
  local box = card(frame, PADDING, -210, INNER, 120, 'Catches by zone hour, all time')
  hourBars = ui.bars(box, 24, 10, INNER - 20, CHART_HEIGHT, hourTooltip)
  hourBars:layout(24, 3)
  for hour = 0, 23 do
    local sky = PT.clock.isDay(hour) and ui.AMBER or ui.BLUE
    hourBars[hour + 1].fill:SetTexture(sky[1], sky[2], sky[3], 0.7)
    if math.mod(hour, 6) == 0 then
      local label = ui.label(box, 10, 'TOP', 0, 0, ui.GREY)
      label:SetPoint('TOP', hourBars[hour + 1], 'BOTTOM', 0, -4)
      label:SetText(string.format('%02d', hour))
    end
  end
  hourMax = ui.label(box, 10, 'TOPRIGHT', -10, -8, ui.GREY)
end

local function buildTops(frame)
  local width = (INNER - GAP) / 2
  for i, list in ipairs({ topFish, topSpots }) do
    local box = card(frame, PADDING + (i - 1) * (width + GAP), -340, width, 108,
      i == 1 and 'Most caught' or 'Most fished spots')
    opens(box, SEE_ALL[i])
    for row = 1, TOP_ROWS do
      local y = -24 - (row - 1) * 15
      local line = { name = ui.label(box, 11, 'TOPLEFT', 10, y, ui.WHITE),
        count = ui.label(box, 11, 'TOPRIGHT', -10, y, ui.WHITE) }
      line.name:SetWidth(width - 70)
      line.name:SetHeight(13)
      line.name:SetJustifyH('LEFT')
      list[row] = line
    end
  end
end

function tab.build(frame)
  summary = CreateFrame('Frame', nil, frame)
  summary:SetAllPoints(frame)
  buildStats(summary)
  PT.almanac.timeline.build(summary, PADDING, -80, INNER, 120)
  buildHours(summary)
  buildTops(summary)
  PT.almanac.lists.build(frame)
end

-- 'fish', 'spots' or 'log' for one of the full lists, false for the summary.
function tab.open(target)
  view = target or nil
end

function tab.current()
  return view or false
end

function tab.lists()
  return { PT.almanac.lists.list() }
end

-- { key, n } for every count, most first.
local function ranked(counts)
  local sorted = {}
  for key, n in pairs(counts) do table.insert(sorted, { key, n }) end
  table.sort(sorted, function (a, b) return a[2] > b[2] end)
  return sorted
end

-- Fills a top 5 from `ranked` counts. `show(row, key)` names the row.
local function top(sorted, rows, show)
  for i, row in ipairs(rows) do
    local entry = sorted[i]
    if entry then show(row, entry[1]) else row.name:SetText('') end
    row.count:SetText(entry and PT.utils.count(entry[2]) or '')
  end
end

local function showFish(row, id)
  row.name:SetText(PT.data.item(id) or 'Item ' .. id)
  ui.color(row.name, ui.quality(id))
end

local function showSpot(row, spot)
  row.name:SetText(spot.subzone == '' and spot.zone or spot.subzone .. ', ' .. spot.zone)
  ui.color(row.name, ui.WHITE)
end

-- the last `history`, kept until the history changes
local summed, summedAt

-- Own and imported catches add up here: both are the player's own history. Also the fish and the
-- spots ranked for the top 5s.
local function history()
  if summedAt == PT.catches.version() then return unpack(summed) end
  local own, imported, items, spots, hours = 0, 0, {}, {}, {}
  PT.catches.each(function (zone, subzone, id, key, n, fromImport)
    if id == 0 then
      if fromImport then imported = imported + n else own = own + n end
      local spot = zone .. '/' .. subzone
      spots[spot] = spots[spot] or { zone = zone, subzone = subzone, n = 0 }
      spots[spot].n = spots[spot].n + n
      local hour = tonumber(string.sub(key, -2))
      if hour then hours[hour] = (hours[hour] or 0) + n end
    else
      items[id] = (items[id] or 0) + n
    end
  end)
  local spotCounts = {}
  for _, spot in pairs(spots) do spotCounts[spot] = spot.n end
  summed, summedAt = { own, imported, items, spots, hours, ranked(items), ranked(spotCounts) }, PT.catches.version()
  return unpack(summed)
end

local function count(map)
  local n = 0
  for _ in pairs(map) do n = n + 1 end
  return n
end

function tab.refresh(fresh)
  local own, imported, items, spots, hours, topItems, topSpotCounts = history()
  PT.almanac.lists.show(view, items, spots, fresh)
  if view then return summary:Hide() end
  summary:Show()

  local seconds, firstDay = 0, nil
  for day, fished in pairs(PizzaTonno_catches.fished) do
    seconds = seconds + fished
    if not firstDay or day < firstDay then firstDay = day end
  end

  stats[1].value:SetText(PT.utils.count(own + imported))
  stats[1].sub:SetText(imported > 0 and PT.utils.count(imported) .. ' from FishingBuddy' or 'since you started')
  local fish, collected = 0, 0
  for _, id in ipairs(PT.data.catchables()) do
    if PT.data.isFish(id) then
      fish = fish + 1
      if items[id] then collected = collected + 1 end
    end
  end
  stats[2].value:SetText(collected .. ' of ' .. fish)
  stats[2].sub:SetText(collected == fish and 'every fish there is' or fish - collected .. ' still to catch')
  stats[3].value:SetText(PT.utils.duration(seconds))
  stats[3].sub:SetText(firstDay and 'since ' .. firstDay or 'counted from now on')
  stats[4].value:SetText(count(spots))
  stats[4].sub:SetText('subzones and zones')

  PT.almanac.timeline.refresh()

  local values = {}
  for hour = 0, 23 do values[hour + 1] = hours[hour] or 0 end
  local most = hourBars:set(values)
  hourMax:SetText('most: ' .. PT.utils.count(most))

  top(topItems, topFish, showFish)
  top(topSpotCounts, topSpots, showSpot)
end
