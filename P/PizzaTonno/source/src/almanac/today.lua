local PT = PizzaTonno
local ui = PT.ui
local tab = PT.almanac.addTab('today', 'Today')

local PADDING, LEFT_WIDTH, SIDE_WIDTH = 14, 400, 196
local SIDE_X = PADDING + LEFT_WIDTH + PADDING
local ROWS, ROW_HEIGHT = 9, 34
-- the purple watch bar and the icon sit at the same place in the Farm tile and in the list's rows
local MARK_X, ICON_X, SPOT_X = 10, 16, 210
-- the spot's lines stop short of the chance on the right, long names get cut
local SPOT_WIDTH = 130
local WEEK = 7
local SEASONS = { s = 'summer', w = 'winter' }
local SEASON_COLORS = { s = ui.SUMMER, w = ui.WINTER }
local ANY_TIME = {}

local farm, list, empty, seasonCard, eventCard, weekCard, dayCard, collectionCard

local function color(region, c)
  region:SetTextColor(c[1], c[2], c[3])
end

local function wrapped(parent, size, x, y, width, c)
  local text = ui.label(parent, size, 'TOPLEFT', x, y, c)
  text:SetWidth(width)
  text:SetJustifyH('LEFT')
  return text
end

local function card(x, y, width, height, caption, captionColor, parent)
  local box = CreateFrame('Button', nil, parent)
  box:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
  box:SetWidth(width)
  box:SetHeight(height)
  ui.panel(box, 1, ui.CARD)
  box.caption = ui.label(box, 10, 'TOPLEFT', 10, -8, captionColor or ui.GREY)
  box.caption:SetText(caption)
  return box
end

-- A tile that opens another tab: lights up under the mouse, the purple corner says so. `range`
-- picks the Journal chart's range on the way.
local function opens(box, key, target, range)
  ui.hoverable(box)
  ui.corner(box)
  box:SetScript('OnClick', function ()
    if range then PizzaTonno_config.journalRange = range end
    PT.almanac.open(key, target)
  end)
end

-- Seconds until the fish's chance at this spot changes (day and night flip, the season ends), and
-- that in words and colour.
local function windowLeft(spot, itemId)
  local depends = PT.loot.dependencies(spot.area.loot)[itemId] or ANY_TIME
  local left, reason, reasonColor
  if depends.light then
    local hour, minute = PT.clock.zoneTime(spot.area.map)
    left = PT.clock.untilFlip(hour, minute) * 60
    reason = (spot.isDay and 'Day' or 'Night') .. ' there for ' .. PT.utils.duration(left)
    reasonColor = spot.isDay and ui.AMBER or ui.BLUE
  end
  local condition = PT.spots.condition(itemId)
  if depends.season and SEASONS[condition] then
    local _, seasonLeft = PT.clock.event(SEASONS[condition])
    if not left or seasonLeft < left then
      left, reasonColor = seasonLeft, SEASON_COLORS[condition]
      reason = (condition == 'w' and 'Winter' or 'Summer') .. ' for ' .. PT.utils.duration(seasonLeft)
    end
  end
  return left, reason or 'Bites any time', reasonColor or ui.GREY
end

-- Which watched fish to farm now: the one for which now is the best time compared to how good it
-- ever gets, then the one whose window closes first.
local function better(a, b)
  if not b then return true end
  if math.abs(a.score - b.score) > 0.001 then return a.score > b.score end
  -- a fish that bites any time has no window (left is nil)
  return a.left ~= nil and (b.left == nil or a.left < b.left)
end

local function pick(entries)
  local best
  for _, entry in ipairs(entries) do
    if entry.score and better(entry, best) then best = entry end
  end
  return best
end

-- Fish unwatched from this tab since it was opened: they stay in the list, greyed, so a slip of the
-- right mouse button is easy to see and to undo.
local dropped = {}

local function watchEntries()
  local entries, ids = {}, {}
  for id in pairs(PizzaTonno_config.watch) do ids[id] = true end
  for id in pairs(dropped) do ids[id] = true end
  for id in pairs(ids) do
    if PT.data.item(id) then
      local spot = PT.spots.of(id)[1]
      local entry = { id = id, spot = spot, dropped = not PizzaTonno_config.watch[id] }
      if spot and spot.now > 0 and not entry.dropped then
        entry.score = spot.now / PT.spots.peak(id)
        entry.left, entry.reason, entry.reasonColor = windowLeft(spot, id)
      end
      table.insert(entries, entry)
    end
  end
  table.sort(entries, function (a, b)
    local rateA, rateB = a.spot and a.spot.now or 0, b.spot and b.spot.now or 0
    if rateA ~= rateB then return rateA > rateB end
    return PT.data.item(a.id) < PT.data.item(b.id)
  end)
  return entries
end

-- 'Peak' to 'Poor': the chance now against the best it ever gets.
local function showBest(text, entry)
  if not entry.score then return text:SetText('') end
  local word, c = PT.almanac.rating(entry.score)
  text:SetText(word)
  color(text, c)
end

local function createRow(row)
  ui.hoverable(row)
  row.icon = row:CreateTexture(nil, 'ARTWORK')
  row.icon:SetPoint('LEFT', row, 'LEFT', ICON_X, 0)
  row.icon:SetWidth(20)
  row.icon:SetHeight(20)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.mark = ui.solid(row, 'ARTWORK', ui.ACCENT)
  row.mark:SetPoint('LEFT', row, 'LEFT', MARK_X, 0)
  row.mark:SetWidth(2)
  row.mark:SetHeight(20)
  row.name = ui.label(row, 12, 'TOPLEFT', ICON_X + 28, -4, ui.WHITE)
  row.tag = ui.label(row, 10, 'TOPLEFT', ICON_X + 28, -19, ui.GREY)
  row.spot = ui.label(row, 12, 'TOPLEFT', SPOT_X, -4, ui.WHITE)
  row.where = ui.label(row, 10, 'TOPLEFT', SPOT_X, -19, ui.GREY)
  for _, text in ipairs({ row.spot, row.where }) do
    text:SetWidth(SPOT_WIDTH)
    text:SetHeight(14)
    text:SetJustifyH('LEFT')
  end
  row.rate = ui.label(row, 13, 'TOPRIGHT', -6, -3, ui.WHITE)
  -- how close now is to the fish's best ever, what "Farm this now" picks by
  row.best = ui.label(row, 10, 'TOPRIGHT', -6, -19, ui.GREY)
  row.columns = { { SPOT_X - 8, 'fish' }, { SPOT_X + SPOT_WIDTH + 4, 'spot' }, { nil, 'chance' } }
  row.onEnter = function (self)
    local entry = self.entry
    if not entry.spot then return PT.almanac.fishTooltip(self, entry.id, self.column) end
    PT.almanac.spotTooltip(self, entry.spot, entry.id, nil, self.column)
  end
  row:SetScript('OnClick', function ()
    local id = this.entry.id
    if arg1 == 'RightButton' and PizzaTonno_config.watch[id] then dropped[id] = true end
    PT.almanac.clickFish(id)
  end)
end

local function fillRow(row, entry)
  row.entry = entry
  local spot = entry.spot
  local biting = spot and spot.now > 0
  row.icon:SetTexture(ui.icon(entry.id))
  if PizzaTonno_config.watch[entry.id] then row.mark:Show() else row.mark:Hide() end
  row.name:SetText(PT.data.item(entry.id))
  color(row.name, ui.quality(entry.id))
  row.icon:SetAlpha(biting and 1 or 0.5)
  local tag, tagColor = PT.almanac.tag(entry.id)
  row.tag:SetText(tag)
  color(row.tag, tagColor)

  if biting then
    row.spot:SetText(spot.area.name)
    row.where:SetText(PT.almanac.where(spot.area, true))
    color(row.where, spot.isDay and ui.AMBER or ui.BLUE)
    row.rate:SetText(PT.utils.percent(spot.now))
    showBest(row.best, entry)
  else
    row.spot:SetText(spot and 'Not biting now' or 'Only from pools')
    local seasonal = SEASONS[PT.spots.condition(entry.id)]
    row.where:SetText(not spot and 'see the Fish tab' or seasonal and 'out of season' or 'not at this hour anywhere')
    color(row.where, ui.GREY)
    row.rate:SetText('-')
    row.best:SetText('')
  end
  color(row.spot, biting and ui.WHITE or ui.GREY)
  color(row.rate, biting and ui.WHITE or ui.GREY)

  -- unwatched a moment ago: greyed out, one right-click away from coming back
  if entry.dropped then
    row.icon:SetAlpha(0.35)
    color(row.name, ui.GREY)
    row.tag:SetText('Right-click to undo')
    row.best:SetText('')
    color(row.tag, ui.GREY)
    color(row.spot, ui.GREY)
    color(row.rate, ui.GREY)
  end
end

local function fillFarm(entries)
  local entry = pick(entries)
  farm.entry = entry
  -- nothing to open without a fish
  if entry then farm.corner:Show() else farm.corner:Hide() end
  if entry then farm.mark:Show() else farm.mark:Hide() end
  if not entry then
    farm.icon:Hide()
    farm.name:SetText(table.getn(entries) == 0 and 'Watch a fish to see it here' or 'Nothing you watch bites now')
    color(farm.name, ui.WHITE)
    farm.line:SetText(table.getn(entries) == 0
      and 'Right-click a fish in the HUD or anywhere in here.' or '')
    color(farm.line, ui.GREY)
    farm.reason:SetText('')
    farm.needs:SetText('')
    farm.rate:SetText('')
    farm.best:SetText('')
    return
  end

  local spot = entry.spot
  farm.icon:SetTexture(ui.icon(entry.id))
  farm.icon:Show()
  farm.name:SetText(PT.data.item(entry.id))
  color(farm.name, ui.quality(entry.id))
  farm.line:SetText(PT.almanac.place(spot.area))
  color(farm.line, spot.isDay and ui.AMBER or ui.BLUE)
  farm.reason:SetText(entry.reason)
  color(farm.reason, entry.reasonColor)
  local skill = PT.spots.skill(spot, entry.id)
  farm.needs:SetText(skill > 0 and 'needs ' .. skill or '')
  farm.rate:SetText(PT.utils.percent(spot.now))
  showBest(farm.best, entry)
end

-- Every fish (item id) that only bites in one season, by season.
local seasonal
local function seasonalFish()
  if seasonal then return seasonal end
  seasonal = { s = {}, w = {} }
  local seen = {}
  for _, area in pairs(PT.data.areas) do
    for _, row in ipairs(area.loot or {}) do
      local id = row[1]
      if SEASONS[row[4]] and not seen[id] and PT.spots.condition(id) == row[4] then
        seen[id] = true
        table.insert(seasonal[row[4]], id)
      end
    end
  end
  return seasonal
end

local function fillSeason()
  local summer, summerLeft = PT.clock.event('summer')
  local winter, winterLeft = PT.clock.event('winter')
  local name = summer and winter and 'Summer and winter' or summer and 'Summer' or winter and 'Winter'
    or 'Between seasons'
  local left = winter and winterLeft or summer and summerLeft
  seasonCard.name:SetText(name)
  color(seasonCard.name, winter and ui.WINTER or summer and ui.SUMMER or ui.WHITE)
  seasonCard.left:SetText(left and ', ' .. PT.utils.duration(left) .. ' left' or '')

  local lines = {}
  for condition, names in pairs(seasonalFish()) do
    local running, seconds = PT.clock.event(SEASONS[condition])
    for _, id in ipairs(names) do
      table.insert(lines, { PT.data.item(id), (running and 'until ' or 'back ') .. PT.almanac.date(seconds), condition,
        running, id })
    end
  end
  -- what bites now first
  table.sort(lines, function (a, b)
    if a[4] ~= b[4] then return a[4] end
    return a[1] < b[1]
  end)
  for i, line in ipairs(seasonCard.lines) do
    local entry = lines[i]
    if entry then
      line.name:SetText(entry[1])
      line.when:SetText(entry[2])
      color(line.name, SEASON_COLORS[entry[3]])
      if PizzaTonno_config.watch[entry[5]] then line.mark:Show() else line.mark:Hide() end
    else
      line.name:SetText('')
      line.when:SetText('')
      line.mark:Hide()
    end
  end
end

local function fillEvent()
  local starts, _, running, seconds = PT.almanac.extravaganza()
  if running then
    eventCard.day:SetText('On now')
    color(eventCard.day, ui.ACCENT)
    eventCard.when:SetText('ends in ' .. PT.utils.duration(seconds))
  else
    eventCard.day:SetText(date('%A, %b ', starts) .. tonumber(date('%d', starts)))
    color(eventCard.day, ui.WHITE)
    eventCard.when:SetText('in ' .. PT.utils.duration(seconds))
  end
  eventCard.hours:SetText(PT.almanac.extravaganzaHours())
end

local function fillWeek()
  local catches, watched, seconds = 0, 0, 0
  for daysAgo = 0, WEEK - 1 do
    local n, items, fished = PT.catches.daily(date('%Y-%m-%d', time() - daysAgo * 86400))
    catches, seconds = catches + n, seconds + fished
    for id in pairs(PizzaTonno_config.watch) do watched = watched + (items[id] or 0) end
  end
  weekCard.values[1]:SetText(catches)
  weekCard.values[2]:SetText(watched)
  weekCard.values[3]:SetText(PT.utils.duration(seconds))
end

-- The last 24 hours, hour by hour like the Journal's chart: a night of fishing doesn't get cut in two
-- at midnight.
local function fillDay()
  local hours, values, items, total = PT.almanac.timeline.hours(), {}, {}, 0
  for i, hour in ipairs(hours) do
    values[i] = hour.catches
    total = total + hour.catches
    for id, n in pairs(hour.items) do items[id] = (items[id] or 0) + n end
  end
  dayCard.bars:set(values)
  dayCard.total:SetText(total == 1 and '1 catch' or total .. ' catches')
  local best, bestCount
  for id, n in pairs(items) do
    if not best or n > bestCount then best, bestCount = id, n end
  end
  dayCard.top:SetText(best and 'Most: ' .. PT.data.item(best) .. ' x' .. bestCount or 'Nothing caught yet')
  color(dayCard.top, best and ui.quality(best) or ui.GREY)
end

-- How many of the fish there are the player has caught at least once (the rest of the catches is
-- stuff nobody collects: potions, greens, junk).
local fish, got, countedAt

local function countCollection()
  if countedAt == PT.catches.version() then return fish, got end
  local caught = {}
  PT.catches.each(function (_, _, id, _, n)
    if id ~= 0 and n > 0 then caught[id] = true end
  end)
  fish, got, countedAt = 0, 0, PT.catches.version()
  for _, id in ipairs(PT.data.catchables()) do
    if PT.data.isFish(id) then
      fish = fish + 1
      if caught[id] then got = got + 1 end
    end
  end
  return fish, got
end

local function fillCollection()
  local fish, got = countCollection()
  collectionCard.value:SetText(got .. ' of ' .. fish)
  collectionCard.fill:SetWidth(math.max((SIDE_WIDTH - 20) * got / fish, 1))
  collectionCard.sub:SetText(got == fish and 'Every fish there is' or fish - got .. ' still to catch')
end

local function buildExtras(frame)
  dayCard = card(SIDE_X, -358, SIDE_WIDTH, 92, 'Last 24 hours', nil, frame)
  opens(dayCard, 'journal', false, 'hours')
  dayCard.total = ui.label(dayCard, 11, 'TOPRIGHT', -22, -7, ui.WHITE)
  dayCard.bars = ui.bars(dayCard, 24, 10, SIDE_WIDTH - 20, 36)
  dayCard.bars:layout(24, 1)
  dayCard.top = ui.label(dayCard, 10, 'BOTTOMLEFT', 10, 7, ui.GREY)

  collectionCard = card(SIDE_X, -186, SIDE_WIDTH, 64, 'Fish collected', nil, frame)
  opens(collectionCard, 'journal', 'fish')
  collectionCard.value = ui.label(collectionCard, 11, 'TOPRIGHT', -22, -7, ui.WHITE)
  local track = ui.solid(collectionCard, 'ARTWORK', ui.TRACK)
  track:SetPoint('TOPLEFT', collectionCard, 'TOPLEFT', 10, -26)
  track:SetWidth(SIDE_WIDTH - 20)
  track:SetHeight(6)
  collectionCard.fill = ui.solid(collectionCard, 'OVERLAY', ui.ACCENT, 0.8)
  collectionCard.fill:SetPoint('LEFT', track, 'LEFT', 0, 0)
  collectionCard.fill:SetHeight(6)
  collectionCard.sub = ui.label(collectionCard, 10, 'TOPLEFT', 10, -40, ui.GREY)
end

function tab.build(frame)
  -- as tall as the Season tile beside it
  farm = card(PADDING, -14, LEFT_WIDTH, 86, 'Farm this now', ui.ACCENT, frame)
  farm.icon = farm:CreateTexture(nil, 'ARTWORK')
  farm.icon:SetPoint('TOPLEFT', farm, 'TOPLEFT', ICON_X, -30)
  farm.icon:SetWidth(28)
  farm.icon:SetHeight(28)
  farm.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  farm.mark = ui.solid(farm, 'ARTWORK', ui.ACCENT)
  farm.mark:SetPoint('TOPLEFT', farm, 'TOPLEFT', MARK_X, -30)
  farm.mark:SetWidth(2)
  farm.mark:SetHeight(28)
  farm.name = ui.label(farm, 15, 'TOPLEFT', ICON_X + 36, -29, ui.WHITE)
  farm.line = wrapped(farm, 10, ICON_X + 36, -48, LEFT_WIDTH - 140, ui.GREY)
  farm.reason = ui.label(farm, 10, 'TOPLEFT', ICON_X + 36, -62, ui.GREY)
  farm.rate = ui.label(farm, 18, 'TOPRIGHT', -12, -30, ui.WHITE)
  farm.best = ui.label(farm, 10, 'TOPRIGHT', -12, -52, ui.ACCENT)
  farm.needs = ui.label(farm, 10, 'TOPRIGHT', -12, -64, ui.GREY)
  ui.hoverable(farm)
  farm.corner = ui.corner(farm)
  farm.onEnter = function (self)
    if not self.entry then return end
    PT.almanac.spotTooltip(self, self.entry.spot, self.entry.id, nil, 'farm')
  end
  farm:SetScript('OnClick', function ()
    if this.entry then PT.almanac.open('fish', this.entry.id) end
  end)

  ui.label(frame, 13, 'TOPLEFT', PADDING, -112, ui.WHITE):SetText('Watchlist right now')
  -- titles over the rows' spot (200 in) and chance (6 short of the row's right edge)
  ui.label(frame, 10, 'TOPLEFT', PADDING + SPOT_X, -115, ui.GREY):SetText('Best spot right now')
  local chance = ui.label(frame, 10, 'RIGHT', 0, 0, ui.GREY)
  chance:SetPoint('RIGHT', frame, 'TOPLEFT', PADDING + LEFT_WIDTH - 12, -120)
  chance:SetText('Chance')
  list = ui.list(frame, LEFT_WIDTH, ROW_HEIGHT, ROWS, createRow, fillRow)
  list:SetPoint('TOPLEFT', frame, 'TOPLEFT', PADDING, -132)
  empty = ui.label(frame, 11, 'TOPLEFT', PADDING, -138, ui.GREY)

  seasonCard = card(SIDE_X, -14, SIDE_WIDTH, 86, 'Season', nil, frame)
  seasonCard.name = ui.label(seasonCard, 13, 'TOPLEFT', 10, -24, ui.WHITE)
  seasonCard.left = ui.label(seasonCard, 13, 'LEFT', 0, 0, ui.WHITE)
  seasonCard.left:SetPoint('LEFT', seasonCard.name, 'RIGHT', 0, 0)
  seasonCard.lines = {}
  for i = 1, 2 do
    -- plain text: the tile is the one thing to click
    local line = {
      name = ui.label(seasonCard, 11, 'TOPLEFT', 14, -30 - i * 16, ui.WHITE),
      when = ui.label(seasonCard, 11, 'TOPRIGHT', -10, -30 - i * 16, ui.GREY),
      mark = ui.solid(seasonCard, 'ARTWORK', ui.ACCENT),
    }
    line.mark:SetPoint('TOPLEFT', seasonCard, 'TOPLEFT', MARK_X, -30 - i * 16)
    line.mark:SetWidth(2)
    line.mark:SetHeight(13)
    seasonCard.lines[i] = line
  end

  opens(seasonCard, 'calendar')

  eventCard = card(SIDE_X, -112, SIDE_WIDTH, 62, 'Next Extravaganza', nil, frame)
  opens(eventCard, 'calendar')
  eventCard.day = ui.label(eventCard, 12, 'TOPLEFT', 10, -24, ui.WHITE)
  eventCard.when = ui.label(eventCard, 11, 'TOPRIGHT', -10, -25, ui.ACCENT)
  eventCard.hours = ui.label(eventCard, 11, 'TOPLEFT', 10, -41, ui.GREY)

  weekCard = card(SIDE_X, -262, SIDE_WIDTH, 84, 'Last 7 days', nil, frame)
  opens(weekCard, 'journal', false)
  weekCard.values = {}
  for i, name in ipairs({ 'Catches', 'Watched fish', 'Time fishing' }) do
    ui.label(weekCard, 11, 'TOPLEFT', 10, -8 - i * 18, ui.WHITE):SetText(name)
    weekCard.values[i] = ui.label(weekCard, 11, 'TOPRIGHT', -10, -8 - i * 18, ui.WHITE)
  end
  buildExtras(frame)
end

function tab.lists()
  return { list }
end

function tab.refresh(fresh)
  if fresh then dropped = {} end
  local entries = watchEntries()
  fillFarm(entries)
  list:setItems(entries, not fresh)
  empty:SetText(table.getn(entries) == 0 and 'No watched fish yet.' or '')
  fillSeason()
  fillEvent()
  fillWeek()
  fillDay()
  fillCollection()
end
