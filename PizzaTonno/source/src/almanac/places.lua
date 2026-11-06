local PT = PizzaTonno
local ui = PT.ui
local tab = PT.almanac.addTab('places', 'Places')

local PADDING, ZONES_WIDTH, GAP = 14, 170, 14
local DETAIL_X = PADDING + ZONES_WIDTH + GAP
local DETAIL_WIDTH = 610 - ZONES_WIDTH - GAP
local ZONE_ROWS, ZONE_ROW = 18, 22
local FISH_ROWS, FISH_ROW = 13, 28
local RATE_COLUMNS = { day = 290, night = 350, all = 420 }
local NAME_WIDTH = 200
local GROUPS = {
  { 'Eastern Kingdoms', function (map) return map == 0 end },
  { 'Kalimdor', function (map) return map == 1 end },
  { 'Dungeons', function (map) return PT.data.instance(map) == 'dungeon' end },
  { 'Raids', function (map) return PT.data.instance(map) == 'raid' end },
  { 'Battlegrounds', function (map) return PT.data.instance(map) == 'battleground' end },
}

-- selected: a zone entry from `allZones`; focus: a subzone to scroll to once
local selected, focus
-- the unfolded groups and tables (by area id); everything starts folded after a login or reload
local opened = {}
local zoneList, fishList, title, summary, foldAll, foldGroups

local color = ui.color

-- Every zone that has fishing, once per name: a zone and its instance can be two areas of the
-- same name (The Deadmines), and they're shown as one. Each { name, map, ids, tables }, the tables
-- being the zone's own and then each subzone that has one.
local zones, zoneOf
local function allZones()
  if zones then return zones end
  local byName = {}
  for id, area in pairs(PT.data.areas) do
    if not area.zone then
      byName[area.name] = byName[area.name] or { name = area.name, map = area.map, ids = {}, tables = {}, subzones = {} }
      table.insert(byName[area.name].ids, id)
      if area.loot then table.insert(byName[area.name].tables, area) end
    end
  end
  for _, area in pairs(PT.data.areas) do
    local parent = area.zone and PT.data.area(area.zone)
    if parent and area.loot then table.insert(byName[parent.name].subzones, area) end
  end
  for _, zone in pairs(byName) do
    table.sort(zone.subzones, function (a, b) return a.name < b.name end)
    for _, area in ipairs(zone.subzones) do table.insert(zone.tables, area) end
  end

  zones, zoneOf = {}, {}
  for _, group in ipairs(GROUPS) do
    local list = {}
    for _, zone in pairs(byName) do
      zone.pools = PT.data.poolsIn(zone.name)
      local fishing = table.getn(zone.tables) > 0 or table.getn(zone.pools) > 0
      if fishing and group[2](zone.map) then table.insert(list, zone) end
    end
    table.sort(list, function (a, b) return a.name < b.name end)
    if table.getn(list) > 0 then table.insert(zones, { heading = group[1] }) end
    for _, zone in ipairs(list) do
      zone.group = group[1]
      table.insert(zones, { zone = zone })
      for _, id in ipairs(zone.ids) do zoneOf[id] = zone end
    end
  end
  return zones
end

local function groupKey(name)
  return 'group:' .. name
end

-- The zone list as shown: every group's heading, the zones of the open ones.
local function visibleZones()
  local shown = {}
  for _, entry in ipairs(allZones()) do
    if entry.heading or opened[groupKey(entry.zone.group)] then table.insert(shown, entry) end
  end
  return shown
end

local function groupsShut()
  for _, group in ipairs(GROUPS) do
    if opened[groupKey(group[1])] then return false end
  end
  return true
end

local function toggleGroups()
  local open = groupsShut()
  for _, group in ipairs(GROUPS) do opened[groupKey(group[1])] = open or nil end
  tab.refresh()
end

-- The table the player is fishing from right now: the subzone's own, or the zone's.
local function locateMe()
  local area = PT.data.spot(PT.player.location())
  if area then
    PT.almanac.open('places', area.id)
  else
    PT:Print('No fishing data for where you are')
  end
end

local function createZoneRow(row)
  ui.hoverable(row)
  row.tile = ui.solid(row, 'BACKGROUND', ui.ACCENT, 0.16)
  row.tile:SetAllPoints()
  row.caret = ui.caret(row, 9)
  row.caret:SetPoint('LEFT', row, 'LEFT', 0, -3)
  row.caret:SetVertexColor(ui.ACCENT[1], ui.ACCENT[2], ui.ACCENT[3])
  row.name = ui.label(row, 11, 'LEFT', 6, 0, ui.WHITE)
  row:SetScript('OnClick', function ()
    local entry = this.entry
    if entry.zone then return PT.almanac.open('places', entry.zone.ids[1]) end
    local key = groupKey(entry.heading)
    opened[key] = not opened[key] or nil
    tab.refresh()
  end)
end

local function fillZoneRow(row, entry)
  row.entry = entry
  if entry.heading then
    row.tile:Hide()
    row.caret:setOpen(opened[groupKey(entry.heading)])
    row.caret:Show()
    row.name:SetText(entry.heading)
    row.name:SetPoint('LEFT', row, 'LEFT', 14, -3)
    color(row.name, ui.ACCENT)
    return
  end

  row.caret:Hide()
  local zone = entry.zone
  row.name:SetPoint('LEFT', row, 'LEFT', 6, 0)
  row.name:SetText(zone.name)
  local here = zone.name == GetRealZoneText()
  color(row.name, (zone == selected or here) and ui.WHITE or ui.GREY)
  if zone == selected then row.tile:Show() else row.tile:Hide() end
end

local function createFishRow(row)
  ui.hoverable(row)
  row.icon = row:CreateTexture(nil, 'ARTWORK')
  row.icon:SetPoint('LEFT', row, 'LEFT', 6, 0)
  row.icon:SetWidth(16)
  row.icon:SetHeight(16)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.caret = ui.caret(row, 9)
  row.caret:SetPoint('LEFT', row, 'LEFT', 2, -3)
  row.caret:SetVertexColor(ui.ACCENT[1], ui.ACCENT[2], ui.ACCENT[3])
  row.name = ui.label(row, 11, 'LEFT', 26, 0, ui.WHITE)
  row.name:SetHeight(12)
  row.name:SetJustifyH('LEFT')
  -- a table's heading: the skill it needs under the day column, the player's catches at the end
  row.skill = ui.label(row, 10, 'RIGHT', 0, -3, ui.GREY)
  row.skill:SetPoint('RIGHT', row, 'LEFT', RATE_COLUMNS.day, -3)
  row.catches = ui.label(row, 10, 'RIGHT', 0, -3, ui.GREY)
  row.catches:SetPoint('RIGHT', row, 'LEFT', RATE_COLUMNS.all, -3)
  PT.almanac.rateCells(row, RATE_COLUMNS)
  row.columns = { { 245, 'fish' }, { 320, 'day' }, { 385, 'night' }, { nil, 'all' } }
  row.onEnter = function (self)
    local entry = self.entry
    if entry.pool and entry.id then return PT.almanac.fishTooltip(self, entry.id, self.column == 'fish' and 'fish') end
    if entry.id then PT.almanac.spotTooltip(self, entry, entry.id, nil, self.column) end
  end
  row:SetScript('OnClick', function ()
    local entry = this.entry
    if entry.id then return PT.almanac.clickFish(entry.id) end
    opened[entry.key] = not opened[entry.key] or nil
    tab.refresh()
  end)
  -- a fish that needs more than the water does (the 410 rows)
  row.pill = PT.almanac.skillPill(row)
  row.pill:SetPoint('LEFT', row.name, 'LEFT', 0, 0)
  row.mark = ui.solid(row, 'ARTWORK', ui.ACCENT)
  row.mark:SetPoint('LEFT', row, 'LEFT', 0, 0)
  row.mark:SetWidth(2)
  row.mark:SetHeight(16)
end

local function showRates(row, shown)
  for _, cell in pairs(row.rates) do
    if shown then cell.top:Show() cell.own:Show() else cell.top:Hide() cell.own:Hide() end
  end
end

local function fillHeading(row, entry)
  row.pill:Hide()
  row.icon:Hide()
  row.mark:Hide()
  showRates(row, false)
  row.caret:setOpen(entry.open)
  row.caret:Show()
  row.name:SetPoint('LEFT', row, 'LEFT', 16, -3)
  row.name:SetWidth(NAME_WIDTH - 16)
  color(row.name, ui.ACCENT)
  if entry.pool then
    row.name:SetText(entry.pool.name .. ' (pool)')
    row.skill:SetText('')
    row.catches:SetText(entry.spawns .. (entry.spawns == 1 and ' spawn point' or ' spawn points'))
    return
  end
  local area = entry.area
  row.name:SetText(area.zone and area.name or (entry.alone and 'Everywhere in ' or 'Everywhere else in ') .. area.name)
  row.skill:SetText(entry.required > 0 and entry.required .. ' skill' or '')
  row.catches:SetText(entry.catches > 0 and entry.catches .. (entry.catches == 1 and ' catch' or ' catches')
    or 'no catches yet')
end

-- A pool's catch: its chance per pool catch by day and at night. Pool catches aren't kept per
-- pool, so there's no rate of the player's own; a fish no open water has says so.
local function fillPoolRates(row, entry)
  local cells = row.rates
  cells.day.top:SetText(PT.utils.percent(entry.day))
  color(cells.day.top, entry.isDay and ui.AMBER or ui.GREY)
  cells.night.top:SetText(PT.utils.percent(entry.night))
  color(cells.night.top, entry.isDay and ui.GREY or ui.BLUE)
  for _, cell in pairs(cells) do cell.own:SetText('') end
  cells.all.top:SetText('')
  local onlyPools = next(PT.data.areasWith(entry.id)) == nil
  row.pill:set(nil)
  if onlyPools then row.pill:setText('Only in pools') end
end

local function fillFishRow(row, entry)
  row.entry = entry
  if not entry.id then return fillHeading(row, entry) end

  row.caret:Hide()
  row.skill:SetText('')
  row.catches:SetText('')
  showRates(row, true)
  row.icon:SetTexture(ui.icon(entry.id))
  row.icon:Show()
  row.name:SetPoint('LEFT', row, 'LEFT', 26, 0)
  row.name:SetWidth(NAME_WIDTH - 26)
  row.name:SetText(PT.data.item(entry.id))
  color(row.name, ui.quality(entry.id))
  if PizzaTonno_config.watch[entry.id] then row.mark:Show() else row.mark:Hide() end
  row.pill:SetPoint('LEFT', row.name, 'LEFT', row.name:GetStringWidth() + 6, 0)
  if entry.pool then return fillPoolRates(row, entry) end
  local skill = PT.spots.skill(entry, entry.id)
  row.pill:set(skill > entry.required and skill)
  PT.almanac.fillRates(row, entry, entry.id)
end

local function fishEntries(zone)
  local entries, total = {}, 0
  for _, area in ipairs(zone.tables) do
    local _, catches = PT.spots.yours(area)
    total = total + catches
    local open = opened[area.id]
    table.insert(entries, { key = area.id, area = area, required = PT.spots.required(area), catches = catches,
      open = open, alone = table.getn(zone.tables) == 1 })
    if open then
      for _, entry in ipairs(PT.spots.at(area)) do table.insert(entries, entry) end
    end
  end
  for _, found in ipairs(zone.pools) do
    local key = 'pool' .. found.id
    table.insert(entries, { key = key, pool = found.pool, spawns = found.spawns, open = opened[key] })
    if opened[key] then
      for _, entry in ipairs(PT.spots.inPool(found.pool, zone.map)) do table.insert(entries, entry) end
    end
  end
  return entries, total
end

-- What folds in the zone: its tables by area id, its pools as 'pool' .. id.
local function sections()
  local keys = {}
  for _, area in ipairs(selected.tables) do table.insert(keys, area.id) end
  for _, found in ipairs(selected.pools) do table.insert(keys, 'pool' .. found.id) end
  return keys
end

local function allShut()
  for _, key in ipairs(sections()) do
    if opened[key] then return false end
  end
  return true
end

-- Folds everything in the zone shut, or opens it all if it's all shut already.
local function toggleAll()
  local open = allShut()
  for _, key in ipairs(sections()) do opened[key] = open or nil end
  tab.refresh()
end

function tab.build(frame)
  zoneList = ui.list(frame, ZONES_WIDTH, ZONE_ROW, ZONE_ROWS, createZoneRow, fillZoneRow)
  zoneList:SetPoint('TOPLEFT', frame, 'TOPLEFT', PADDING, -36)

  foldGroups = ui.link(frame, 10, ui.ACCENT, toggleGroups)
  foldGroups:SetPoint('TOPLEFT', frame, 'TOPLEFT', PADDING, -13)
  -- jumps to where the player stands, like a map app's locate button
  local locate = CreateFrame('Button', nil, frame)
  locate:SetWidth(18)
  locate:SetHeight(18)
  locate:SetPoint('TOPRIGHT', frame, 'TOPLEFT', PADDING + ZONES_WIDTH - 6, -10)
  locate.icon = locate:CreateTexture(nil, 'ARTWORK')
  locate.icon:SetTexture('Interface\\AddOns\\PizzaTonno\\img\\locate')
  locate.icon:SetAllPoints()
  locate.icon:SetVertexColor(ui.GREY[1], ui.GREY[2], ui.GREY[3])
  locate:SetScript('OnEnter', function ()
    this.icon:SetVertexColor(ui.WHITE[1], ui.WHITE[2], ui.WHITE[3])
    PT.tooltip.open(this)
    PT.tooltip.title('Where you are')
    PT.tooltip.show()
  end)
  locate:SetScript('OnLeave', function ()
    this.icon:SetVertexColor(ui.GREY[1], ui.GREY[2], ui.GREY[3])
    PT.tooltip.hide()
  end)
  locate:SetScript('OnClick', locateMe)
  ui.takeSideButtons(locate)

  local divider = ui.solid(frame, 'BORDER', ui.LINE)
  divider:SetPoint('TOPLEFT', frame, 'TOPLEFT', DETAIL_X - GAP / 2, -14)
  divider:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', DETAIL_X - GAP / 2, 14)
  divider:SetWidth(1)

  title = ui.label(frame, 15, 'TOPLEFT', DETAIL_X, -14, ui.WHITE)
  summary = ui.label(frame, 10, 'TOPLEFT', DETAIL_X, -33, ui.GREY)
  foldAll = ui.link(frame, 10, ui.ACCENT, toggleAll)
  foldAll:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -PADDING - 6, -14)

  local header = CreateFrame('Frame', nil, frame)
  header:SetPoint('TOPLEFT', frame, 'TOPLEFT', DETAIL_X, -50)
  header:SetWidth(DETAIL_WIDTH)
  header:SetHeight(14)
  PT.almanac.rateHeader(header, RATE_COLUMNS)

  fishList = ui.list(frame, DETAIL_WIDTH, FISH_ROW, FISH_ROWS, createFishRow, fillFishRow)
  fishList:SetPoint('TOPLEFT', frame, 'TOPLEFT', DETAIL_X, -66)
end

-- An area to show: a zone, or a subzone (opens its zone, scrolled to the subzone).
function tab.open(areaId)
  local area = areaId and PT.data.area(areaId)
  if not area then return end
  allZones()
  selected = zoneOf[area.zone or area.id] or selected
  focus = area.zone and area
  -- a zone opened from elsewhere shows in the list, its group unfolded
  if selected then opened[groupKey(selected.group)] = true end
end

function tab.current()
  return selected and selected.ids[1]
end

function tab.lists()
  return { zoneList, fishList }
end

function tab.refresh(fresh)
  allZones()
  if not selected then
    local here = PT.data.zone(GetRealZoneText())
    selected = here and zoneOf[here.id] or zones[2].zone
  end

  foldGroups:setText(groupsShut() and 'Open all' or 'Fold all')
  local shown = visibleZones()
  zoneList:setItems(shown, true)
  if fresh then
    for i, entry in ipairs(shown) do
      if entry.zone == selected then zoneList:reveal(i) end
    end
  end

  if focus then opened[focus.id] = true end
  local entries, total = fishEntries(selected)
  title:SetText(selected.name)
  local count, pools = table.getn(selected.tables), table.getn(selected.pools)
  summary:SetText(count .. (count == 1 and ' loot table, ' or ' loot tables, ')
    .. (pools > 0 and pools .. (pools == 1 and ' pool, ' or ' pools, ') or '')
    .. (total == 1 and '1 catch' or total .. ' catches') .. '. Predicted chance on top, yours in purple.')
  foldAll:setText(allShut() and 'Open all' or 'Fold all')
  if table.getn(sections()) > 1 then foldAll:Show() else foldAll:Hide() end

  fishList:setItems(entries, not fresh)
  for i, entry in ipairs(entries) do
    if focus and entry.area == focus and not entry.id then fishList:scrollTo(i) end
  end
  focus = nil
end
