local PT = PizzaTonno
local ui = PT.ui
PT.almanac = { tabs = {} }

BINDING_NAME_PIZZATONNO_ALMANAC = 'Open the almanac'

local WIDTH, HEIGHT = 760, 500
local BAR_HEIGHT, RAIL_WIDTH = 36, 120
local TAB_HEIGHT, TAB_GAP = 24, 4
local CONTINENTS = { [0] = 'Eastern Kingdoms', [1] = 'Kalimdor' }
-- the strongest lure there is, the Aquadynamic Fish Attractor
local BEST_LURE = 100

local frame = CreateFrame('Frame', 'PizzaTonnoAlmanac', UIParent)
frame:SetWidth(WIDTH)
frame:SetHeight(HEIGHT)
frame:SetFrameStrata('HIGH')
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:Hide()
ui.panel(frame, 0.95)
-- Escape closes it like the game's own windows
table.insert(UISpecialFrames, 'PizzaTonnoAlmanac')

local function anchor()
  local saved = PizzaTonno_character.almanac
  frame:ClearAllPoints()
  if saved then
    frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', saved.x, saved.y)
  else
    frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 40)
  end
end

local bar = CreateFrame('Frame', nil, frame)
bar:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
bar:SetPoint('BOTTOMRIGHT', frame, 'TOPRIGHT', 0, -BAR_HEIGHT)
-- Dragged from anywhere that has no click of its own: the window takes every click that falls
-- through its tabs, cards and texts.
frame:SetScript('OnMouseDown', function ()
  if arg1 == 'LeftButton' then frame:StartMoving() end
end)
frame:SetScript('OnMouseUp', function ()
  if arg1 ~= 'LeftButton' then return ui.sideButton() end
  frame:StopMovingOrSizing()
  PizzaTonno_character.almanac = { x = frame:GetLeft(), y = frame:GetTop() }
  anchor()
end)

local line = ui.solid(frame, 'BORDER', ui.LINE)
line:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, -BAR_HEIGHT)
line:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, -BAR_HEIGHT)
line:SetHeight(1)

local rail = ui.solid(frame, 'BORDER', ui.LINE)
rail:SetPoint('TOPLEFT', frame, 'TOPLEFT', RAIL_WIDTH, -BAR_HEIGHT)
rail:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', RAIL_WIDTH, 0)
rail:SetWidth(1)

local logo = bar:CreateTexture(nil, 'ARTWORK')
logo:SetTexture('Interface\\AddOns\\PizzaTonno\\img\\fish')
logo:SetWidth(18)
logo:SetHeight(18)
logo:SetPoint('LEFT', bar, 'LEFT', 12, 0)

local title = ui.label(bar, 13, 'LEFT', 36, 0, ui.WHITE)
title:SetText(PT.Colors.primary .. 'Pizza' .. PT.Colors.secondary .. 'Tonno')

-- back and forward through what the window showed, like a browser
local arrows = {}
for i, step in ipairs({ -1, 1 }) do
  local arrow = CreateFrame('Button', nil, bar)
  arrow:SetPoint('LEFT', bar, 'LEFT', RAIL_WIDTH + 8 + (i - 1) * 22, 0)
  arrow:SetWidth(20)
  arrow:SetHeight(22)
  arrow.icon = ui.triangle(arrow, 12, step > 0)
  arrow.icon:SetPoint('CENTER', arrow, 'CENTER', 0, 0)
  arrow.step = step
  arrow:SetScript('OnClick', function () PT.almanac.go(this.step) end)
  arrow:SetScript('OnEnter', function ()
    if this.enabled then this.icon:SetVertexColor(ui.WHITE[1], ui.WHITE[2], ui.WHITE[3]) end
  end)
  arrow:SetScript('OnLeave', function () this.paint() end)
  arrow.paint = function ()
    local color = arrow.enabled and ui.GREY or ui.LINE
    arrow.icon:SetVertexColor(color[1], color[2], color[3])
  end
  arrow.paint()
  ui.takeSideButtons(arrow)
  arrows[i] = arrow
end

local search = CreateFrame('EditBox', 'PizzaTonnoAlmanacSearch', bar)
search:SetPoint('LEFT', bar, 'LEFT', RAIL_WIDTH + 56, 0)
search:SetWidth(240)
search:SetHeight(22)
search:SetAutoFocus(false)
search:EnableMouse(true)
search:SetFont(ui.FONT, 11)
search:SetTextColor(ui.WHITE[1], ui.WHITE[2], ui.WHITE[3])
search:SetTextInsets(8, 24, 0, 0)
ui.panel(search, 1, ui.CARD)

local placeholder = ui.label(search, 11, 'LEFT', 8, 0, ui.GREY)
placeholder:SetText('Search a fish, place or dish')

local function showPlaceholder()
  if search:GetText() == '' and not search.focused then placeholder:Show() else placeholder:Hide() end
end

search:SetScript('OnEditFocusGained', function ()
  this.focused = true
  showPlaceholder()
end)
search:SetScript('OnEditFocusLost', function ()
  this.focused = false
  showPlaceholder()
end)
search:SetScript('OnEscapePressed', function () this:ClearFocus() end)
search:SetScript('OnEnterPressed', function () this:ClearFocus() end)
local clear = ui.link(search, 11, ui.GREY, function ()
  search:SetText('')
  search:ClearFocus()
end)
clear:setText('X')
clear:SetPoint('RIGHT', search, 'RIGHT', -8, 0)
clear:Hide()

search:SetScript('OnTextChanged', function ()
  showPlaceholder()
  if search:GetText() == '' then clear:Hide() else clear:Show() end
  PT.almanac.search()
end)

local close = ui.link(bar, 12, ui.GREY, function () frame:Hide() end)
close:setText('X')
close:SetPoint('RIGHT', bar, 'RIGHT', -14, 0)

-- Both continents' clocks, each over a thin 24 hour strip (night, day, night) with a tick for now.
local clocks = {}
for i, map in ipairs({ 1, 0 }) do
  local clock = CreateFrame('Frame', nil, bar)
  clock:SetHeight(26)
  clock:SetPoint('RIGHT', i == 1 and close or clocks[1], 'LEFT', -18, 0)
  clock:EnableMouse(true)
  clock.text = ui.label(clock, 11, 'TOP', 0, -4, ui.GREY)
  clock.parts = {}
  for j, color in ipairs({ ui.BLUE, ui.AMBER, ui.BLUE }) do
    clock.parts[j] = ui.solid(clock, 'ARTWORK', color, 0.7)
    clock.parts[j]:SetHeight(2)
  end
  clock.now = ui.solid(clock, 'OVERLAY', ui.WHITE)
  clock.now:SetWidth(2)
  clock.now:SetHeight(6)
  clock.map = map
  clock:SetScript('OnEnter', function ()
    local hour, minute = PT.clock.zoneTime(this.map)
    local day = PT.clock.isDay(hour)
    PT.tooltip.open(this, 'below')
    PT.tooltip.title(CONTINENTS[this.map] .. string.format(', %02d:%02d zone time', hour, minute))
    PT.tooltip.line((day and 'Day until 18:00' or 'Night until 06:00') .. ', '
      .. PT.utils.duration(PT.clock.untilFlip(hour, minute) * 60) .. ' left', day and ui.AMBER or ui.BLUE)
    PT.tooltip.line('Day is 06:00 to 18:00 on every continent\'s own clock.', ui.GREY)
    PT.tooltip.show()
  end)
  clock:SetScript('OnLeave', PT.tooltip.hide)
  ui.takeSideButtons(clock)
  clocks[i] = clock
end

local PIECES = { { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }

-- Both strips as wide as the longer name, each clock's text centred over its own.
local function tickClocks()
  local width = 0
  for _, clock in ipairs(clocks) do
    local hour, minute = PT.clock.zoneTime(clock.map)
    clock.text:SetText(CONTINENTS[clock.map] .. ' ' .. string.format('%02d:%02d', hour, minute))
    ui.color(clock.text, PT.clock.isDay(hour) and ui.AMBER or ui.BLUE)
    width = math.max(width, clock.text:GetStringWidth())
  end
  for _, clock in ipairs(clocks) do
    local hour, minute = PT.clock.zoneTime(clock.map)
    clock:SetWidth(width)
    for j, piece in ipairs(PIECES) do
      clock.parts[j]:SetPoint('TOPLEFT', clock, 'TOPLEFT', piece[1] * width, -20)
      clock.parts[j]:SetWidth((piece[2] - piece[1]) * width)
    end
    clock.now:SetPoint('CENTER', clock, 'TOPLEFT', (hour * 60 + minute) / 1440 * width, -21)
  end
end

local version = ui.label(frame, 9, 'BOTTOMLEFT', 12, 10, ui.GREY)
version:SetAlpha(0.6)
version:SetText('v' .. GetAddOnMetadata('PizzaTonno', 'Version'))

local content = CreateFrame('Frame', nil, frame)
content:SetPoint('TOPLEFT', frame, 'TOPLEFT', RAIL_WIDTH + 1, -BAR_HEIGHT - 1)
content:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -1, 1)

local current
local railButtons = {}

-- What the open tab was drawn for. It shows minutes at the finest, so it's redrawn when a minute
-- turns on the game's clock or the real one, the catch history changed or the player moved on; a
-- catch or a watch redraws it at once.
local drawn = {}

local function outdated()
  local hour, minute = GetGameTime()
  return hour * 60 + minute ~= drawn.clock or math.floor(time() / 60) ~= drawn.minute
    or PT.catches.version() ~= drawn.version or GetRealZoneText() ~= drawn.zone or GetSubZoneText() ~= drawn.subzone
end

local function draw(fresh)
  local hour, minute = GetGameTime()
  drawn.clock, drawn.minute, drawn.version = hour * 60 + minute, math.floor(time() / 60), PT.catches.version()
  drawn.zone, drawn.subzone = GetRealZoneText(), GetSubZoneText()
  PT.almanac.tabs[current].refresh(fresh)
end

local function paintRail()
  for key, button in pairs(railButtons) do
    local color = key == current and ui.WHITE or ui.GREY
    button.text:SetTextColor(color[1], color[2], color[3])
    if key == current then button.tile:Show() else button.tile:Hide() end
  end
end

-- Tab files register themselves in the .toc's order, which is the rail's. `build(frame)` makes the
-- tab once, `refresh(fresh)` fills it again (`fresh` when it was just opened or searched, so lists
-- start at the top), `open(target)` shows one thing in it (a fish, a place; false for the tab's
-- start), `current()` says which, for the history.
local tabCount, firstTab = 0, nil

function PT.almanac.addTab(key, name)
  local tab = { key = key, name = name }
  PT.almanac.tabs[key] = tab
  firstTab = firstTab or key

  local button = CreateFrame('Button', nil, frame)
  button:SetPoint('TOPLEFT', frame, 'TOPLEFT', 8, -BAR_HEIGHT - 12 - tabCount * (TAB_HEIGHT + TAB_GAP))
  button:SetWidth(RAIL_WIDTH - 16)
  button:SetHeight(TAB_HEIGHT)
  button.tile = ui.solid(button, 'BACKGROUND', ui.ACCENT, 0.16)
  button.tile:SetAllPoints()
  button.text = ui.label(button, 12, 'LEFT', 10, 0, ui.GREY)
  button.text:SetText(name)
  button:SetScript('OnEnter', function () this.text:SetTextColor(ui.WHITE[1], ui.WHITE[2], ui.WHITE[3]) end)
  button:SetScript('OnLeave', paintRail)
  button:SetScript('OnClick', function () PT.almanac.select(key) end)
  railButtons[key] = button
  tabCount = tabCount + 1
  return tab
end

-- Where the window has been: { key, target, query, scroll } entries, `at` the one on screen.
local history, at = {}, 0
local MAX_HISTORY = 50
-- going back or forward: what it opens isn't recorded again, and its search text isn't a new search
local navigating = false

local function paintArrows()
  arrows[1].enabled, arrows[2].enabled = at > 1, at < table.getn(history)
  arrows[1].paint()
  arrows[2].paint()
end

local function listsOf(key)
  local tab = PT.almanac.tabs[key]
  return tab.lists and tab.lists() or {}
end

-- The entry on screen keeps how far its lists are scrolled, to come back to the same view.
local function remember()
  local entry = history[at]
  if not (entry and entry.key == current) then return end
  entry.scroll = {}
  for i, list in ipairs(listsOf(current)) do entry.scroll[i] = list.offset end
end

local function record()
  local tab = PT.almanac.tabs[current]
  local entry = { key = current, target = tab.current and tab.current(), query = PT.almanac.query() }
  local last = history[at]
  if last and last.key == entry.key and last.target == entry.target then
    -- typing on in the search box refines the same page
    last.query = entry.query
    return
  end
  for i = table.getn(history), at + 1, -1 do table.remove(history, i) end
  table.insert(history, entry)
  if table.getn(history) > MAX_HISTORY then table.remove(history, 1) end
  at = table.getn(history)
  paintArrows()
end

-- `restoring`: going back or forward, which opens exactly what was there and isn't recorded again.
function PT.almanac.select(key, target, restoring)
  if not restoring then remember() end
  local tab = PT.almanac.tabs[key]
  for _, other in pairs(PT.almanac.tabs) do
    if other.frame and other ~= tab then other.frame:Hide() end
  end
  if not tab.frame then
    tab.frame = CreateFrame('Frame', nil, content)
    tab.frame:SetAllPoints(content)
    tab.build(tab.frame)
  end
  current = key
  tab.frame:Show()
  if tab.open and (target ~= nil or restoring) then tab.open(target) end
  draw(true)
  paintRail()
  if not restoring then record() end
end

-- One step back (-1) or forward (1), to exactly the view that was there.
function PT.almanac.go(step)
  local entry = history[at + step]
  if not entry then return end
  remember()
  at = at + step
  navigating = true
  search:SetText(entry.query or '')
  PT.almanac.select(entry.key, entry.target, true)
  for i, list in ipairs(listsOf(entry.key)) do list:jump(entry.scroll and entry.scroll[i] or 0) end
  navigating = false
  paintArrows()
end

ui.sideButtons = function (button)
  if frame:IsShown() then PT.almanac.go(button == 'Button4' and -1 or 1) end
end

local sinceTick = 0
frame:SetScript('OnUpdate', function ()
  sinceTick = sinceTick + arg1
  if sinceTick < 1 then return end
  sinceTick = 0
  if outdated() then
    tickClocks()
    draw()
  end
end)

-- Redraws the open tab now, for what shouldn't wait for the next minute (a catch).
function PT.almanac.refresh()
  if not frame:IsShown() then return end
  draw()
end

function PT.almanac.open(key, target)
  if not frame:IsShown() then
    anchor()
    frame:Show()
    tickClocks()
  end
  -- the tab it was on this session, Today after a login or reload
  PT.almanac.select(key or current or firstTab, target)
end

function PT.almanac.toggle()
  if frame:IsShown() then frame:Hide() else PT.almanac.open() end
end

function PT.almanac.query()
  return string.lower(search:GetText() or '')
end

-- Typing searches in the Fish tab's list, wherever the window was. Emptying the box stays on the
-- page; on the results that leaves the list of everything.
function PT.almanac.search()
  if navigating or not frame:IsShown() then return end
  local onList = current == 'fish' and PT.almanac.tabs.fish.current() == false
  if onList or PT.almanac.query() ~= '' then PT.almanac.select('fish', false) end
end

function PT.almanac.continent(map)
  return CONTINENTS[map]
end

local INSTANCES = { dungeon = 'Dungeon', raid = 'Raid', battleground = 'Battleground' }

-- The continent, or what kind of instance it is.
local function world(area)
  return CONTINENTS[area.map] or INSTANCES[PT.data.instance(area.map)]
end

-- 'Azshara · Kalimdor' for a subzone, 'Rest of zone · Kalimdor' for a zone's own table, 'Dungeon'
-- for an instance's own. Brief leaves out the continent or instance kind of a subzone.
function PT.almanac.where(area, brief)
  if not area.zone and not CONTINENTS[area.map] then return world(area) or '' end
  local place = area.zone and PT.data.area(area.zone).name or 'Rest of zone'
  if brief or not world(area) then return place end
  return place .. ' · ' .. world(area)
end

-- 'Temple of Arkkoran, Azshara · Kalimdor' or 'Gillijim's Isle · Eastern Kingdoms': a place in full.
-- Brief leaves out the continent or instance kind.
function PT.almanac.place(area, brief)
  local place = area.zone and area.name .. ', ' .. PT.data.area(area.zone).name or area.name
  if brief or not world(area) then return place end
  return place .. ' · ' .. world(area)
end

local TAGS = {
  k410 = { 'Needs 410 skill', ui.ICE, 'Needs 410 skill, more than the water around it.' },
  d = { 'Day only', ui.AMBER, 'Bites by day only.' },
  n = { 'Night only', ui.BLUE, 'Bites at night only.' },
  s = { 'Summer only', ui.SUMMER, 'Bites in summer only.' },
  w = { 'Winter only', ui.WINTER, 'Bites in winter only.' },
  e = { 'Extravaganza only', ui.EVENT, 'Only from the pools of the Stranglethorn Extravaganza, on Sundays.' },
}
local ANY_TIME = { 'Any time', ui.GREY, 'Bites any time of day and year.' }

-- How now compares to the best a fish ever gets: the share of its best it has to reach.
local RATINGS = {
  { 0.995, 'Peak', { 0.3, 0.9, 0.45 } },
  { 0.6, 'Good', { 0.65, 0.85, 0.4 } },
  { 0.3, 'Ok', { 1, 0.55, 0.2 } },
  { 0, 'Poor', { 0.95, 0.33, 0.33 } },
}

-- What a fish's chance hangs on, in words and colour: 'Night only', 'Winter only', or 'Any time'.
function PT.almanac.tag(itemId)
  local tag = TAGS[PT.spots.condition(itemId)] or ANY_TIME
  return tag[1], tag[2]
end

-- 'Good' and its colour for a chance at 60% of the fish's best ever (`score` 0.6).
function PT.almanac.rating(score)
  for _, rating in ipairs(RATINGS) do
    if score >= rating[1] then return rating[2], rating[3] end
  end
end

-- The Extravaganza running now or next: its start (epoch seconds) and end, whether it's on, and the
-- seconds until it ends or starts.
function PT.almanac.extravaganza()
  local running, seconds = PT.clock.event('extravaganza')
  local length = PT.data.events.extravaganza.length
  local starts = time() + (running and seconds - length or seconds)
  return starts, starts + length, running, seconds
end

-- '15:00-17:00', the hours of the Extravaganza on the player's clock.
function PT.almanac.extravaganzaHours()
  local starts, ends = PT.almanac.extravaganza()
  return date('%H:%M', starts) .. '-' .. date('%H:%M', ends)
end

-- 'Mar 22' for a moment this many seconds from now.
function PT.almanac.date(seconds)
  return (string.gsub(date('%b %d', time() + seconds), ' 0', ' '))
end

-- Whether the player can land catches where this much skill is needed, with the best lure if need be.
-- A lure already on counts in the skill, so then only that one is assumed.
function PT.almanac.reachable(required)
  return PT.player.skill() + (PT.player.lure() and 0 or BEST_LURE) >= required
end

-- What a click on a fish anywhere in the almanac does: left opens its page, right watches it.
-- The row under the mouse shows the change: its purple watch mark, and its tooltip redone.
function PT.almanac.clickFish(itemId)
  if arg1 == 'RightButton' then
    PT:ToggleWatch(itemId)
    PT.hud.refresh()
    PT.almanac.tabs[current].refresh()
    -- it was just clicked, so the mouse is on it
    if this and this.onEnter then this.onEnter(this) end
    return
  end
  PT.almanac.open('fish', itemId)
end

-- `hint` says what a click does when it isn't the fish's page and watching.
local function clickHint(itemId, hint)
  PT.tooltip.gap()
  PT.tooltip.line(hint or 'Click for its page, right-click to '
    .. (PizzaTonno_config.watch[itemId] and 'stop watching' or 'watch'), ui.GREY)
end

local function tooltipTitle(itemId)
  PT.tooltip.title(PT.data.item(itemId) or 'Item ' .. itemId, ui.quality(itemId))
  if PizzaTonno_config.watch[itemId] then PT.tooltip.watched() end
end

local function lightLine(spot)
  local hour, minute = PT.clock.zoneTime(spot.area.map)
  local flip = PT.utils.duration(PT.clock.untilFlip(hour, minute) * 60)
  return { spot.isDay and 'Day there now, night in ' .. flip .. '.' or 'Night there now, day in ' .. flip .. '.',
    spot.isDay and ui.AMBER or ui.BLUE }
end

local function ratingLine(spot, itemId)
  local score = spot.now / PT.spots.peak(itemId)
  local word, c = PT.almanac.rating(score)
  if score >= RATINGS[1][1] then return { word .. ': as good as it ever gets.', c } end
  return { word .. ': ' .. math.floor(score * 100 + 0.5) .. '% of the best it ever gets (Best of all, below).', c }
end

local function rateLine(spot, itemId, day)
  local n, catches = PT.spots.mine(spot, itemId, day)
  local when = day == nil and '' or day and ' by day' or ' at night'
  if catches == 0 then return { 'Yours, in purple: no catches here' .. when .. ' yet.', ui.ACCENT } end
  return { 'Yours, in purple: ' .. PT.utils.percent(n / catches) .. ' of your ' .. catches
    .. (catches == 1 and ' catch' or ' catches') .. ' here' .. when .. '.', ui.ACCENT }
end

local function predictedLine(spot, itemId, day)
  if spot.unknown then return { 'Not expected here, so no chance to show.', ui.GREY } end
  return { (day and 'By day, ' or 'At night, ') .. PT.utils.percent(day and spot.day or spot.night) .. ' of catches here are '
    .. PT.data.item(itemId) .. '.', day and ui.AMBER or ui.BLUE }
end

-- The top of a tooltip: what the mouse is on (the row's `column`, or a tile) in words. Each gets
-- the spot the tooltip is about (for a fish alone: its best spot now, if any) and the fish.
local FOCUS = {
  fish = function (_, itemId)
    return { { (TAGS[PT.spots.condition(itemId)] or ANY_TIME)[3] } }
  end,
  spot = function (spot)
    if not spot or spot.now == 0 then return end
    return { { 'Its best spot right now.' }, lightLine(spot) }
  end,
  chance = function (spot, itemId)
    if not spot or spot.now == 0 then return end
    return { { PT.utils.percent(spot.now) .. ' of catches there are ' .. PT.data.item(itemId)
      .. ', its best chance anywhere right now.' }, ratingLine(spot, itemId) }
  end,
  farm = function (spot, itemId)
    return { ratingLine(spot, itemId), { 'Of the fish you watch, the one closest to its best right now.' } }
  end,
  place = function (spot)
    return { lightLine(spot) }
  end,
  skill = function (spot, itemId)
    local skill, required = PT.player.skill(), PT.spots.skill(spot, itemId)
    if required == 0 then return { { 'Needs no skill: any catch lands here.' } } end
    local landing = PT.loot.landing(skill, required)
    if landing == 1 then return { { 'Needs ' .. required .. ' skill. With your ' .. skill .. ' every catch lands.' } } end
    if skill >= required then
      return { { 'Needs ' .. required .. ' skill. With your ' .. skill .. ' you land '
        .. string.format('%.0f%%', landing * 100) .. ' of what bites, the rest get away.' } }
    end
    return { { 'Needs ' .. required .. ' skill. Your ' .. skill
      .. (PT.almanac.reachable(required) and ' needs a lure for it.' or ' is too low for it, even with a lure.'),
      ui.ICE } }
  end,
  day = function (spot, itemId)
    return { predictedLine(spot, itemId, true), rateLine(spot, itemId, true) }
  end,
  night = function (spot, itemId)
    return { predictedLine(spot, itemId, false), rateLine(spot, itemId, false) }
  end,
  all = function (spot, itemId)
    return { rateLine(spot, itemId) }
  end,
}

local function startTooltip(owner, itemId, spot, column)
  PT.tooltip.open(owner, 'right', true)
  tooltipTitle(itemId)
  local lines = column and FOCUS[column] and FOCUS[column](spot, itemId)
  if lines then PT.tooltip.focus(lines) end
end

-- Every line holds one number, right-aligned: predicted first, then the player's own in purple.
local function yours(spot, itemId, day, label)
  local n, catches = PT.spots.mine(spot, itemId, day)
  if catches == 0 then return PT.tooltip.pair(label, 'no catches yet', ui.ACCENT, ui.GREY) end
  PT.tooltip.pair(label, PT.utils.percent(n / catches) .. ' of ' .. catches .. (catches == 1 and ' catch' or ' catches'),
    ui.ACCENT, ui.ACCENT)
end

-- The tooltip of a fish at a spot (from `spots.of` or `spots.at`): what `column` is (see FOCUS),
-- then where, the chance by day and at night, the player's own, the skill it takes, and where it's
-- best of all. `hint` says what a click does when it's not the fish's page.
function PT.almanac.spotTooltip(owner, spot, itemId, hint, column)
  startTooltip(owner, itemId, spot, column)
  PT.tooltip.line(PT.almanac.place(spot.area, true), spot.isDay and ui.AMBER or ui.BLUE)

  PT.tooltip.gap()
  if spot.day == spot.night then
    PT.tooltip.pair('Predicted, day and night', PT.utils.percent(spot.day))
  else
    PT.tooltip.pair('Predicted by day', PT.utils.percent(spot.day), ui.AMBER)
    PT.tooltip.pair('Predicted at night', PT.utils.percent(spot.night), ui.BLUE)
  end
  yours(spot, itemId, true, 'Yours by day')
  yours(spot, itemId, false, 'Yours at night')

  PT.tooltip.gap()
  local skill, required = PT.player.skill(), PT.spots.skill(spot, itemId)
  PT.tooltip.pair('Skill needed', required > 0 and required or 'none')
  PT.tooltip.pair('Your skill', skill >= required
    and skill .. ', lands ' .. string.format('%.0f%%', PT.loot.landing(skill, required) * 100)
    or skill .. (PT.almanac.reachable(required) and ', needs a lure' or ', out of reach'),
    nil, skill >= required and ui.WHITE or ui.ICE)
  PT.tooltip.best(itemId)
  clickHint(itemId, hint)
  PT.tooltip.show()
end

-- A fish's tooltip where no spot is in view: what `column` is, what the fish hangs on, its best
-- spot now, its best of all.
function PT.almanac.fishTooltip(owner, itemId, column)
  local best = PT.spots.of(itemId)[1]
  startTooltip(owner, itemId, best, column)
  local tag, tagColor = PT.almanac.tag(itemId)
  PT.tooltip.line(tag, tagColor)
  if best and best.now > 0 then
    PT.tooltip.gap()
    PT.tooltip.pair('Best right now', PT.utils.percent(best.now))
    PT.tooltip.line(PT.almanac.place(best.area, true), best.isDay and ui.AMBER or ui.BLUE)
  end
  PT.tooltip.best(itemId)
  clickHint(itemId)
  PT.tooltip.show()
end

-- A small pill with the skill a fish needs ('Skill 330'), hidden when it needs none, or any short note.
function PT.almanac.skillPill(parent)
  local pill = CreateFrame('Frame', nil, parent)
  pill:SetHeight(13)
  -- a capsule in three slices, so the round ends keep their shape however wide it gets
  local slices = { { 'LEFT', 0, 0.25 }, { 'CENTER', 0.25, 0.75 }, { 'RIGHT', 0.75, 1 } }
  for _, slice in ipairs(slices) do
    local piece = pill:CreateTexture(nil, 'BACKGROUND')
    piece:SetTexture('Interface\\AddOns\\PizzaTonno\\img\\pill')
    piece:SetTexCoord(slice[2], slice[3], 0, 1)
    piece:SetVertexColor(ui.LINE[1], ui.LINE[2], ui.LINE[3])
    pill[slice[1]] = piece
  end
  pill.LEFT:SetPoint('TOPLEFT', pill, 'TOPLEFT', 0, 0)
  pill.LEFT:SetPoint('BOTTOMLEFT', pill, 'BOTTOMLEFT', 0, 0)
  pill.LEFT:SetWidth(7)
  pill.RIGHT:SetPoint('TOPRIGHT', pill, 'TOPRIGHT', 0, 0)
  pill.RIGHT:SetPoint('BOTTOMRIGHT', pill, 'BOTTOMRIGHT', 0, 0)
  pill.RIGHT:SetWidth(7)
  pill.CENTER:SetPoint('TOPLEFT', pill.LEFT, 'TOPRIGHT', 0, 0)
  pill.CENTER:SetPoint('BOTTOMRIGHT', pill.RIGHT, 'BOTTOMLEFT', 0, 0)
  pill.text = ui.label(pill, 9, 'CENTER', 0, 0, ui.GREY)
  function pill.setText(self, text)
    self.text:SetText(text)
    self:SetWidth(self.text:GetStringWidth() + 14)
    self:Show()
  end
  function pill.set(self, skill)
    if not skill or skill <= 0 then return self:Hide() end
    self:setText('Skill ' .. skill)
  end
  return pill
end

-- Day, night and yours cells. Predicted on top, the phase running there now in its colour and the
-- other grey; the player's own rate by day and at night below in purple. Yours is the player's rate
-- at any hour.
function PT.almanac.rateCells(row, columns)
  row.rates = {}
  for key, x in pairs(columns) do
    local cell = { top = ui.label(row, 11, 'RIGHT', 0, 0, ui.WHITE), own = ui.label(row, 10, 'RIGHT', 0, 0, ui.ACCENT) }
    cell.top:SetPoint('RIGHT', row, 'LEFT', x, key == 'all' and 0 or 6)
    cell.own:SetPoint('RIGHT', row, 'LEFT', x, -7)
    row.rates[key] = cell
  end
end

local function ownRate(spot, itemId, day)
  local n, catches = PT.spots.mine(spot, itemId, day)
  return catches > 0 and PT.utils.percent(n / catches) or '-', catches > 0
end

function PT.almanac.fillRates(row, spot, itemId)
  local cells = row.rates
  cells.day.top:SetText(spot.unknown and '-' or PT.utils.percent(spot.day))
  ui.color(cells.day.top, spot.isDay and not spot.unknown and ui.AMBER or ui.GREY)
  cells.night.top:SetText(spot.unknown and '-' or PT.utils.percent(spot.night))
  ui.color(cells.night.top, (spot.isDay or spot.unknown) and ui.GREY or ui.BLUE)
  for key, day in pairs({ day = true, night = false }) do
    local text, known = ownRate(spot, itemId, day)
    cells[key].own:SetText(text)
    ui.color(cells[key].own, known and ui.ACCENT or ui.GREY)
  end

  local all, known = ownRate(spot, itemId)
  cells.all.top:SetText(all)
  ui.color(cells.all.top, known and ui.ACCENT or ui.GREY)
  cells.all.own:SetText('')
end

-- The column titles over rate cells, each in its colour.
function PT.almanac.rateHeader(header, columns)
  local titles = { day = { 'Day', ui.AMBER }, night = { 'Night', ui.BLUE }, all = { 'Yours', ui.ACCENT } }
  for key, x in pairs(columns) do
    local text = ui.label(header, 10, 'RIGHT', 0, 0, titles[key][2])
    text:SetPoint('RIGHT', header, 'LEFT', x, 0)
    text:SetText(titles[key][1])
  end
end
