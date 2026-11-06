local PT = PizzaTonno
local ui = PT.ui
local tab = PT.almanac.addTab('fish', 'Fish')

local PADDING, INNER = 14, 610
local LIST_ROWS, LIST_ROW = 16, 26
local SPOT_ROWS, SPOT_ROW = 6, 28
local CARD_GAP = 10
local CARD_WIDTH = (INNER - 2 * CARD_GAP) / 3
local MAX_PLACES = 8
-- a spot needs this many of your catches before it can be "your best spot"
local MIN_CATCHES = 10
-- the Pools and Used in tiles show this many, their full lists the rest
local TILE_LINES = 2
local LINE_ROWS, LINE_ROW = 12, 30

-- selected: the fish on screen; whole: 'pools' or 'recipes' when its full list of those is
local selected, whole
local listView, detail, list, spotList, poolTile, recipeTile, linesView, linesTitle, linesList
local heading, header, cards, watchEye, nameText, tagText, icon, foldAll, watchMark, headerNote, emptyNote

local function color(region, c)
  region:SetTextColor(c[1], c[2], c[3])
end

-- names in lower case, made once: every key typed searches them all again
local lowered = {}

local function contains(text, query)
  if not lowered[text] then lowered[text] = string.lower(text) end
  return string.find(lowered[text], query, 1, true) ~= nil
end

-- The recipe whose name or product matches the search, for "in Lobster Stew".
local function dishMatch(itemId, query)
  for _, recipeId in ipairs(PT.data.recipesWith(itemId)) do
    local recipe = PT.data.recipes[recipeId]
    if contains(recipe.name, query) then return recipe.name end
  end
end

local SECTIONS = {
  { 'fish', 'Fish' },
  { 'clackora', 'Cla\'ckora' },
  { 'gahzranka', 'Gahz\'ranka' },
  { 'materials', 'Materials' },
  { 'consumables', 'Consumables' },
  { 'containers', 'Chests and bags' },
  { 'gear', 'Gear' },
  { 'recipes', 'Recipes' },
  { 'quest', 'Quest items' },
  { 'other', 'Other' },
}

-- the unfolded sections; all start folded after a login or reload
local opened = {}

local function sectionKeys()
  local keys = { 'watched' }
  for _, entry in ipairs(SECTIONS) do table.insert(keys, entry[1]) end
  return keys
end

local function anyOpen()
  for _, key in ipairs(sectionKeys()) do
    if opened[key] then return true end
  end
  return false
end

-- Folds every section shut, or opens them all if they're all shut already.
local function toggleAll()
  local open = not anyOpen()
  for _, key in ipairs(sectionKeys()) do opened[key] = open or nil end
  tab.refresh()
end

-- the list's entry of each fish, kept: the list is redone every minute
local catchEntries = {}

-- Everything you can catch in folding sections (watched fish first), or what the search finds.
local function listItems()
  local query, watch = PT.almanac.query(), PizzaTonno_config.watch
  local searching = query ~= ''
  local groups = { watched = {} }

  for _, id in ipairs(PT.data.catchables()) do
    local note = searching and not contains(PT.data.item(id), query) and dishMatch(id, query)
    if not searching or note or contains(PT.data.item(id), query) then
      local item = note and { kind = 'catch', id = id, note = 'for ' .. note } or catchEntries[id]
      if not item then
        item = { kind = 'catch', id = id }
        catchEntries[id] = item
      end
      local key = watch[id] and 'watched' or PT.data.category(id)
      groups[key] = groups[key] or {}
      table.insert(groups[key], item)
    end
  end

  local items = {}
  local function section(key, name, entries)
    if not entries or table.getn(entries) == 0 then return end
    local shown = searching or opened[key]
    table.insert(items, { kind = 'heading', key = key, text = name, count = table.getn(entries), open = shown,
      folds = not searching })
    if not shown then return end
    for _, entry in ipairs(entries) do table.insert(items, entry) end
  end

  if searching then
    local places = {}
    for _, area in pairs(PT.data.areas) do
      if area.loot and contains(area.name, query) and table.getn(places) < MAX_PLACES then
        table.insert(places, { kind = 'place', area = area })
      end
    end
    table.sort(places, function (a, b) return a.area.name < b.area.name end)
    section('places', 'Places', places)
  end
  section('watched', 'Watched', groups.watched)
  for _, entry in ipairs(SECTIONS) do section(entry[1], entry[2], groups[entry[1]]) end
  return items
end

local function createListRow(row)
  ui.hoverable(row)
  row.mark = ui.solid(row, 'ARTWORK', ui.ACCENT)
  row.mark:SetPoint('LEFT', row, 'LEFT', 0, 0)
  row.mark:SetWidth(2)
  row.mark:SetHeight(18)
  row.icon = row:CreateTexture(nil, 'ARTWORK')
  row.icon:SetPoint('LEFT', row, 'LEFT', 6, 0)
  row.icon:SetWidth(18)
  row.icon:SetHeight(18)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = ui.label(row, 12, 'LEFT', 32, 0, ui.WHITE)
  row.tag = ui.label(row, 10, 'LEFT', 270, 0, ui.GREY)
  row.where = ui.label(row, 10, 'RIGHT', -60, 0, ui.GREY)
  row.rate = ui.label(row, 12, 'RIGHT', -4, 0, ui.WHITE)
  row.caret = ui.caret(row, 9)
  row.caret:SetPoint('LEFT', row, 'LEFT', 2, -4)
  -- the best spot's name ends 60 short of the row's right edge, the chance 4
  row.columns = { { INNER - 6 - 200, 'fish' }, { INNER - 6 - 54, 'spot' }, { nil, 'chance' } }
  row.onEnter = function (self)
    if self.item.kind == 'catch' then PT.almanac.fishTooltip(self, self.item.id, self.column) end
  end
  row:SetScript('OnClick', function ()
    local item = this.item
    if item.kind == 'catch' then PT.almanac.clickFish(item.id) end
    if item.kind == 'place' then PT.almanac.open('places', item.area.id) end
    if item.kind == 'heading' then
      opened[item.key] = not item.open or nil
      tab.refresh()
    end
  end)
end

local function fillListRow(row, item)
  row.item = item
  local isHeading = item.kind == 'heading'
  row:EnableMouse(not isHeading or item.folds)
  row.caret:Hide()
  row.mark:Hide()
  row.icon:Hide()
  row.tag:SetText('')
  row.where:SetText('')
  row.rate:SetText('')

  if isHeading then
    row.name:SetText(item.text)
    row.name:SetPoint('LEFT', row, 'LEFT', item.folds and 16 or 0, -4)
    color(row.name, ui.ACCENT)
    row.tag:SetText(item.count)
    color(row.tag, ui.GREY)
    if item.folds then
      row.caret:setOpen(item.open)
      row.caret:SetVertexColor(ui.ACCENT[1], ui.ACCENT[2], ui.ACCENT[3])
      row.caret:Show()
    end
    return
  end

  row.name:SetPoint('LEFT', row, 'LEFT', 32, 0)
  color(row.name, ui.WHITE)

  if item.kind == 'place' then
    row.name:SetText(item.area.name)
    row.where:SetText(PT.almanac.where(item.area))
    row.tag:SetText('Place')
    color(row.tag, ui.GREY)
    return
  end

  local id = item.id
  row.icon:SetTexture(ui.icon(id))
  row.icon:Show()
  if PizzaTonno_config.watch[id] then row.mark:Show() end
  row.name:SetText(PT.data.item(id))
  color(row.name, ui.quality(id))
  local tag, tagColor = PT.almanac.tag(id)
  row.tag:SetText(item.note or tag)
  color(row.tag, item.note and ui.GREY or tagColor)


  local best = PT.spots.of(id)[1]
  if best and best.now > 0 then
    row.rate:SetText(PT.utils.percent(best.now))
    color(row.rate, ui.WHITE)
    row.where:SetText(best.area.name)
    return
  end
  local pool = PT.spots.pools(id)[1]
  if pool then
    row.rate:SetText(PT.utils.percent(pool.chance))
    color(row.rate, ui.GREY)
    row.where:SetText(pool.pool.name)
  elseif best then
    row.rate:SetText('-')
    color(row.rate, ui.GREY)
    row.where:SetText('not biting now')
  end
end

local function spotTooltip(row)
  PT.almanac.spotTooltip(row, row.spot, selected, 'Click for the place', row.column)
end

local SKILL_X = 330
local RATE_COLUMNS = { day = 420, night = 500, all = 600 }

local function createSpotRow(row)
  ui.hoverable(row)
  row.columns = { { SKILL_X - 40, 'place' }, { SKILL_X + 40, 'skill' }, { 460, 'day' }, { 550, 'night' },
    { nil, 'all' } }
  row.onEnter = spotTooltip
  row.name = ui.label(row, 12, 'TOPLEFT', 4, -2, ui.WHITE)
  row.where = ui.label(row, 10, 'TOPLEFT', 4, -16, ui.GREY)
  row.skill = ui.label(row, 11, 'RIGHT', 0, 0, ui.GREY)
  row.skill:SetPoint('RIGHT', row, 'LEFT', SKILL_X, 0)
  PT.almanac.rateCells(row, RATE_COLUMNS)
  row:SetScript('OnClick', function ()
    if arg1 == 'LeftButton' then PT.almanac.open('places', this.spot.area.id) end
  end)
end

-- The place's line takes the colour of the phase running there now.
local function fillSpotRow(row, spot)
  row.spot = spot
  local out = not PT.almanac.reachable(spot.required)
  row.name:SetText(spot.area.name)
  color(row.name, out and ui.GREY or ui.WHITE)
  row.where:SetText(PT.almanac.where(spot.area))
  color(row.where, spot.isDay and ui.AMBER or ui.BLUE)
  row.skill:SetText(spot.required > 0 and spot.required or '-')
  color(row.skill, out and ui.ICE or ui.GREY)
  PT.almanac.fillRates(row, spot, selected)
end

local function createLineRow(row)
  ui.hoverable(row)
  row.name = ui.label(row, 11, 'TOPLEFT', 0, -2, ui.WHITE)
  row.right = ui.label(row, 11, 'TOPRIGHT', -4, -2, ui.WHITE)
  row.sub = ui.label(row, 10, 'TOPLEFT', 0, -16, ui.GREY)
  row.sub:SetWidth(INNER - 160)
  row.sub:SetHeight(12)
  row.sub:SetJustifyH('LEFT')
end

local function poolLine(row, entry)
  local pool = entry.pool
  row.name:SetText(pool.name)
  row.right:SetText(PT.utils.percent(entry.chance))
  color(row.right, ui.WHITE)
  local zones = {}
  for zone, spawns in pairs(pool.zones) do table.insert(zones, { zone, spawns }) end
  table.sort(zones, function (a, b) return a[2] > b[2] end)
  for i, zone in ipairs(zones) do zones[i] = zone[1] .. ' ' .. zone[2] end
  local extravaganza = pool.event == 'extravaganza'
  row.sub:SetText(extravaganza and 'Stranglethorn Extravaganza, Sundays ' .. PT.almanac.extravaganzaHours()
    or table.concat(zones, ' · '))
  row.onEnter = function ()
    PT.tooltip.open(row)
    PT.tooltip.title(pool.name)
    PT.tooltip.line('Predicted: ' .. PT.utils.percent(entry.chance) .. ' of catches from this pool')
    for _, zone in ipairs(zones) do PT.tooltip.line(zone, ui.GREY) end
    PT.tooltip.line('Numbers are spawn points per zone', ui.GREY)
    PT.tooltip.show()
  end
end

local function recipeLine(row, recipeId)
  local recipe = PT.data.recipes[recipeId]
  row.name:SetText(recipe.name)
  row.right:SetText(recipe.profession .. (recipe.skill and ' ' .. recipe.skill or ''))
  color(row.right, ui.GREY)
  -- the fish on screen stands out in purple among the reagents
  local reagents, marked = {}, {}
  for i, reagent in ipairs(recipe.reagents) do
    reagents[i] = reagent[2] .. 'x ' .. (PT.data.item(reagent[1]) or reagent[1])
    marked[i] = reagent[1] == selected and PT.Colors.primary .. reagents[i] .. '|r' or reagents[i]
  end
  row.sub:SetText(table.concat(marked, ', '))
  row.onEnter = function ()
    PT.tooltip.open(row)
    PT.tooltip.title(recipe.name)
    PT.tooltip.line(recipe.profession .. (recipe.skill and ', needs ' .. recipe.skill or ', from a trainer'), ui.GREY)
    for i, reagent in ipairs(reagents) do PT.tooltip.line(reagent, recipe.reagents[i][1] == selected and ui.ACCENT) end
    if recipe.effect then PT.tooltip.line(recipe.effect, ui.ICE) end
    PT.tooltip.show()
  end
end

local LINES = {
  pools = { 'Pools with ', poolLine, PT.spots.pools },
  recipes = { 'Recipes with ', recipeLine, PT.data.recipesWith },
}

-- the full list's rows fill like the tile they came from; kept apart from `whole`, which going back
-- changes before the list's last rows are drawn again
local lineFill

local function fillLineRow(row, item)
  lineFill(row, item)
end

local function card(parent, x, y, width, height, caption, accent)
  local box = CreateFrame('Frame', nil, parent)
  box:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
  box:SetWidth(width)
  box:SetHeight(height)
  ui.panel(box, 1, ui.CARD)
  box.caption = ui.label(box, 10, 'TOPLEFT', 10, -8, accent and ui.ACCENT or ui.GREY)
  box.caption:SetText(caption)
  return box
end

local function statCard(parent, i, caption)
  local box = card(parent, PADDING + (i - 1) * (CARD_WIDTH + CARD_GAP), -76, CARD_WIDTH, 74, caption, i == 1)
  box.value = ui.label(box, 16, 'TOPLEFT', 10, -21, ui.WHITE)
  box.line = ui.label(box, 11, 'TOPLEFT', 10, -40, ui.WHITE)
  box.sub = ui.label(box, 10, 'TOPLEFT', 10, -53, ui.GREY)
  for _, text in ipairs({ box.line, box.sub }) do
    text:SetWidth(CARD_WIDTH - 20)
    text:SetHeight(12)
    text:SetJustifyH('LEFT')
  end
  return box
end

local function setCard(box, value, line, sub, subColor)
  box.value:SetText(value)
  box.line:SetText(line or '')
  box.sub:SetText(sub or '')
  color(box.sub, subColor or ui.GREY)
end

-- Split in parts: Lua 5.0 allows a function only 32 upvalues.
local function buildList(frame)
  listView = CreateFrame('Frame', nil, frame)
  listView:SetAllPoints(frame)
  heading = ui.label(listView, 13, 'TOPLEFT', PADDING, -14, ui.WHITE)
  list = ui.list(listView, INNER, LIST_ROW, LIST_ROWS, createListRow, fillListRow)
  list:SetPoint('TOPLEFT', listView, 'TOPLEFT', PADDING, -34)
  foldAll = ui.link(listView, 10, ui.ACCENT, toggleAll)
  foldAll:SetPoint('LEFT', heading, 'RIGHT', 12, -1)
  -- titles over the rows' columns, which end 60 and 4 px short of the row's right edge
  local rowRight = PADDING + INNER - 6
  for _, column in ipairs({ { 'Best spot right now', 60 }, { 'Chance', 4 } }) do
    local title = ui.label(listView, 10, 'RIGHT', 0, 0, ui.GREY)
    title:SetPoint('RIGHT', listView, 'TOPLEFT', rowRight - column[2], -20)
    title:SetText(column[1])
  end
end

local function buildHeader()
  local back = ui.link(detail, 11, ui.GREY, function () PT.almanac.open('fish', false) end)
  back:setText('All catches')
  back:SetPoint('TOPLEFT', detail, 'TOPLEFT', PADDING + 12, -8)
  local arrow = ui.triangle(detail, 9)
  arrow:SetPoint('RIGHT', back, 'LEFT', -3, 0)
  arrow:SetVertexColor(ui.GREY[1], ui.GREY[2], ui.GREY[3])

  watchMark = ui.solid(detail, 'ARTWORK', ui.ACCENT)
  watchMark:SetPoint('TOPLEFT', detail, 'TOPLEFT', PADDING - 6, -32)
  watchMark:SetWidth(2)
  watchMark:SetHeight(32)
  icon = detail:CreateTexture(nil, 'ARTWORK')
  icon:SetPoint('TOPLEFT', detail, 'TOPLEFT', PADDING, -32)
  icon:SetWidth(32)
  icon:SetHeight(32)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  nameText = ui.label(detail, 16, 'TOPLEFT', PADDING + 42, -32, ui.WHITE)
  tagText = ui.label(detail, 11, 'TOPLEFT', PADDING + 42, -52, ui.GREY)

  watchEye = CreateFrame('Button', nil, detail)
  -- a click area well past the 20 px eye
  watchEye:SetWidth(36)
  watchEye:SetHeight(36)
  watchEye:SetPoint('CENTER', detail, 'TOPRIGHT', -PADDING - 10, -46)
  watchEye.icon = watchEye:CreateTexture(nil, 'ARTWORK')
  watchEye.icon:SetTexture('Interface\\AddOns\\PizzaTonno\\img\\eye')
  watchEye.icon:SetWidth(20)
  watchEye.icon:SetHeight(20)
  watchEye.icon:SetPoint('CENTER', watchEye, 'CENTER', 0, 0)
  watchEye:SetScript('OnEnter', function ()
    this.icon:SetVertexColor(ui.WHITE[1], ui.WHITE[2], ui.WHITE[3])
    PT.tooltip.open(this)
    PT.tooltip.title(PizzaTonno_config.watch[selected] and 'Stop watching' or 'Watch')
    PT.tooltip.line('Watched fish go to the top of the HUD and of the Today tab', ui.GREY)
    PT.tooltip.show()
  end)
  watchEye:SetScript('OnLeave', function ()
    this:paint()
    PT.tooltip.hide()
  end)
  watchEye:SetScript('OnClick', function ()
    PT:ToggleWatch(selected)
    PT.hud.refresh()
    tab.refresh()
    this:GetScript('OnEnter')()
  end)
  function watchEye.paint(self)
    local c = PizzaTonno_config.watch[selected] and ui.ACCENT or ui.GREY
    self.icon:SetVertexColor(c[1], c[2], c[3])
  end
  ui.takeSideButtons(watchEye)

  cards = { statCard(detail, 1, 'Best right now'), statCard(detail, 2, 'Your best spot'),
    statCard(detail, 3, 'Best of all') }
end

local function buildTable()
  header = CreateFrame('Frame', nil, detail)
  header:SetPoint('TOPLEFT', detail, 'TOPLEFT', PADDING, -160)
  header:SetWidth(INNER)
  header:SetHeight(16)
  -- sits on the header's baseline, so a second line grows upwards into the gap under the tiles
  headerNote = ui.label(header, 10, 'BOTTOMLEFT', 4, 2, ui.GREY)
  headerNote:SetJustifyH('LEFT')
  emptyNote = ui.label(detail, 11, 'TOP', 0, -240, ui.ACCENT)
  local skill = ui.label(header, 10, 'RIGHT', 0, 0, ui.GREY)
  skill:SetPoint('RIGHT', header, 'LEFT', SKILL_X, 0)
  skill:SetText('Skill')
  PT.almanac.rateHeader(header, RATE_COLUMNS)
  spotList = ui.list(detail, INNER, SPOT_ROW, SPOT_ROWS, createSpotRow, fillSpotRow)
  spotList:SetPoint('TOPLEFT', detail, 'TOPLEFT', PADDING, -178)
end

-- A tile with the first few pools or recipes, opening the full list. Like every tile it reacts only
-- as a whole: its lines are plain text.
local function lineTile(x, width, caption, key)
  local box = CreateFrame('Button', nil, detail)
  box:SetPoint('TOPLEFT', detail, 'TOPLEFT', x, -352)
  box:SetWidth(width)
  box:SetHeight(98)
  ui.panel(box, 1, ui.CARD)
  ui.label(box, 10, 'TOPLEFT', 10, -8, ui.GREY):SetText(caption)
  box.more = ui.label(box, 10, 'TOPRIGHT', -20, -8, ui.GREY)
  box.empty = ui.label(box, 11, 'TOPLEFT', 10, -24, ui.GREY)
  box.lines = {}
  for i = 1, TILE_LINES do
    local y = -22 - (i - 1) * 30
    local line = { name = ui.label(box, 11, 'TOPLEFT', 10, y - 2, ui.WHITE),
      right = ui.label(box, 11, 'TOPRIGHT', -10, y - 2, ui.WHITE), sub = ui.label(box, 10, 'TOPLEFT', 10, y - 16, ui.GREY) }
    line.sub:SetWidth(width - 20)
    line.sub:SetHeight(12)
    line.sub:SetJustifyH('LEFT')
    box.lines[i] = line
  end
  ui.hoverable(box)
  box.corner = ui.corner(box)
  box:SetScript('OnClick', function () PT.almanac.open('fish', { selected, key }) end)
  return box
end

local function buildBoxes()
  local half = (INNER - CARD_GAP) / 2
  poolTile = lineTile(PADDING, half, 'Pools', 'pools')
  recipeTile = lineTile(PADDING + half + CARD_GAP, half, 'Used in', 'recipes')
end

local function buildLines(frame)
  linesView = CreateFrame('Frame', nil, frame)
  linesView:SetAllPoints(frame)
  local back = ui.link(linesView, 11, ui.GREY, function () PT.almanac.open('fish', selected) end)
  linesView.back = back
  back:SetPoint('TOPLEFT', linesView, 'TOPLEFT', PADDING + 12, -8)
  local arrow = ui.triangle(linesView, 9)
  arrow:SetPoint('RIGHT', back, 'LEFT', -3, 0)
  arrow:SetVertexColor(ui.GREY[1], ui.GREY[2], ui.GREY[3])
  linesTitle = ui.label(linesView, 15, 'TOPLEFT', PADDING, -30, ui.WHITE)
  linesList = ui.list(linesView, INNER, LINE_ROW, LINE_ROWS, createLineRow, fillLineRow)
  linesList:SetPoint('TOPLEFT', linesView, 'TOPLEFT', PADDING, -56)
end

function tab.build(frame)
  buildList(frame)
  detail = CreateFrame('Frame', nil, frame)
  detail:SetAllPoints(frame)
  buildHeader()
  buildTable()
  buildBoxes()
  buildLines(frame)
end

-- A fish, { fish, 'pools' or 'recipes' } for its full list of those, or false for the list of everything.
function tab.open(target)
  if type(target) == 'table' then
    selected, whole = target[1], target[2]
  else
    selected, whole = target or nil, nil
  end
end

function tab.current()
  if whole then return { selected, whole } end
  return selected or false
end

local function fillList(fresh)
  local query = PT.almanac.query()
  heading:SetText(query == '' and 'Everything you can catch' or 'Searching for "' .. query .. '"')
  foldAll:setText(anyOpen() and 'Fold all' or 'Open all')
  if query == '' then foldAll:Show() else foldAll:Hide() end
  list:setItems(listItems(), not fresh)
end

local function fillTile(box, items, fill, emptyText)
  local count = table.getn(items)
  for i, line in ipairs(box.lines) do
    if items[i] then
      fill(line, items[i])
    else
      line.name:SetText('')
      line.right:SetText('')
      line.sub:SetText('')
    end
  end
  box.empty:SetText(count == 0 and emptyText or '')
  box.more:SetText(count > TILE_LINES and count - TILE_LINES .. ' more' or '')
  -- nothing to open without a line
  box:EnableMouse(count > 0)
  if count > 0 then box.corner:Show() else box.corner:Hide() end
end

local function yourBest(spots, itemId)
  local best, bestRate, bestCatches
  for _, spot in ipairs(spots) do
    local n, catches = PT.spots.mine(spot, itemId)
    if catches >= MIN_CATCHES and (not best or n / catches > bestRate) then
      best, bestRate, bestCatches = spot, n / catches, catches
    end
  end
  return best, bestRate, bestCatches
end

local function fillDetail(fresh)
  local id = selected
  icon:SetTexture(ui.icon(id))
  nameText:SetText(PT.data.item(id) or 'Item ' .. id)
  color(nameText, ui.quality(id))
  local tag, tagColor = PT.almanac.tag(id)
  tagText:SetText(tag)
  color(tagText, tagColor)

  local watched = PizzaTonno_config.watch[id]
  watchEye:paint()
  if watched then watchMark:Show() else watchMark:Hide() end

  -- an item no table has (the live server drops a few more things): where the player caught it
  local spots, known = PT.spots.of(id), true
  if table.getn(spots) == 0 then spots, known = PT.spots.caughtAt(id), false end
  local pools = PT.spots.pools(id)
  local nowhere = table.getn(pools) > 0 and 'Only from pools' or 'No predicted chance'
  headerNote:SetText(known and 'Where. Predicted chance on top, yours in purple'
    or 'No predicted chances for this one.\nThese are the places you caught it.')
  color(headerNote, known and ui.GREY or ui.ACCENT)
  emptyNote:SetText(table.getn(spots) == 0 and table.getn(pools) == 0
    and 'No predicted chances for this one, and you haven\'t caught it yet.' or '')

  local best = known and spots[1]
  if best then
    setCard(cards[1], PT.utils.percent(best.now), best.area.name, PT.almanac.where(best.area),
      best.isDay and ui.AMBER or ui.BLUE)
  else
    setCard(cards[1], '-', nowhere)
  end

  local mine, rate, catches = yourBest(spots, id)
  if mine then
    setCard(cards[2], PT.utils.percent(rate), mine.area.name,
      catches .. ' catches' .. (known and ', predicted ' .. PT.utils.percent(mine.now) or ''))
  else
    setCard(cards[2], '-', 'Not enough catches yet', 'Shows up after ' .. MIN_CATCHES .. ' catches in one spot')
  end

  local peak, place, when = ui.peak(id)
  if peak then
    local condition = PT.spots.condition(id)
    local whenColor = condition == 'w' and ui.WINTER or condition == 's' and ui.SUMMER
      or condition == 'd' and ui.AMBER or condition == 'n' and ui.BLUE or ui.GREY
    setCard(cards[3], PT.utils.percent(peak), place, when or 'any time of day and year', whenColor)
  else
    setCard(cards[3], '-', nowhere)
  end

  spotList:setItems(spots, not fresh)
  fillTile(poolTile, pools, poolLine, 'No pool has it')
  fillTile(recipeTile, PT.data.recipesWith(selected), recipeLine, 'No recipe uses it')
end

local function fillLines(fresh)
  local name = PT.data.item(selected) or 'Item ' .. selected
  linesView.back:setText(name)
  linesTitle:SetText(LINES[whole][1] .. name)
  lineFill = LINES[whole][2]
  linesList:setItems(LINES[whole][3](selected), not fresh)
end

function tab.lists()
  return { list, spotList, linesList }
end

function tab.refresh(fresh)
  local view = whole and linesView or selected and detail or listView
  for _, other in ipairs({ listView, detail, linesView }) do
    if other ~= view then other:Hide() end
  end
  view:Show()
  if whole then return fillLines(fresh) end
  if selected then return fillDetail(fresh) end
  fillList(fresh)
end
