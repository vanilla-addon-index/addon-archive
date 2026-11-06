local PT = PizzaTonno
PT.spots = {}

-- The almanac shows what a spot gives at full skill: the rows that need 410 count, and their fish's
-- tag says so (`condition` 'k410').
local function chances(loot, day, summer, winter)
  return PT.loot.rolled(loot, day, summer, winter, true)
end

-- What the server needs where this table is rolled: the area's own level unless it's 0, else its zone's.
function PT.spots.required(area)
  if area.skill ~= 0 or not area.zone then return area.skill end
  return PT.data.area(area.zone).skill
end

-- `of` and `at` only change when a season starts or ends, or day turns to night on either
-- continent: their lists are kept until then.
local ofCache, atCache, ofState = {}, {}, nil

local function state(summer, winter)
  return (summer and 1 or 0) + (winter and 2 or 0)
    + (PT.clock.isDay((PT.clock.zoneTime(0))) and 4 or 0) + (PT.clock.isDay((PT.clock.zoneTime(1))) and 8 or 0)
end

-- Every table the item is in, each { area, required, day, night, now } with the day and night chances
-- in the season running now and `now` by that area's own clock, best now first.
function PT.spots.of(itemId)
  local summer, winter = PT.clock.event('summer'), PT.clock.event('winter')
  local now = state(summer, winter)
  if now ~= ofState then ofCache, atCache, ofState = {}, {}, now end
  if ofCache[itemId] then return ofCache[itemId] end
  local spots = {}

  for id in pairs(PT.data.areasWith(itemId)) do
    local area = PT.data.area(id)
    local day = chances(area.loot, true, summer, winter)[itemId] or 0
    local night = chances(area.loot, false, summer, winter)[itemId] or 0
    local isDay = PT.clock.isDay((PT.clock.zoneTime(area.map)))
    table.insert(spots, { area = area, required = PT.spots.required(area), day = day, night = night,
      now = isDay and day or night, isDay = isDay })
  end

  table.sort(spots, function (a, b) return a.now > b.now end)
  ofCache[itemId] = spots
  return spots
end

local SEASON_SETS = { { true, false }, { false, true }, { true, true }, { false, false } }
local SEASON_KEYS = { 's', 'w', 'sw', '' }

local DAYS = { true, false }
-- `peak`, `condition` and `pools` only depend on the loot tables, so each item's answer is kept
local peaks, conditions, poolLists = {}, {}, {}

local function peak(itemId)
  local best, bestArea, bestDay, bestSeason = 0, nil, nil, nil
  for id in pairs(PT.data.areasWith(itemId)) do
    local loot = PT.data.area(id).loot
    for _, day in ipairs(DAYS) do
      for i, set in ipairs(SEASON_SETS) do
        local chance = chances(loot, day, set[1], set[2])[itemId] or 0
        if chance > best then best, bestArea, bestDay, bestSeason = chance, id, day, i end
      end
    end
  end
  if not bestArea then return 0 end

  local loot = PT.data.area(bestArea).loot
  local function at(day, i)
    return chances(loot, day, SEASON_SETS[i][1], SEASON_SETS[i][2])[itemId] or 0
  end
  local light = at(true, bestSeason) ~= at(false, bestSeason) and (bestDay and 'd' or 'n') or nil
  local season
  for i = 1, table.getn(SEASON_SETS) do
    if at(bestDay, i) ~= best then season = SEASON_KEYS[bestSeason] end
  end
  return best, PT.data.area(bestArea), light, season
end

-- The item's best chance anywhere at any hour and in any season: the chance, the area, and when,
-- if it matters there: 'd' or 'n', and the season ('s', 'w', 'sw' for the March overlap, '' for the
-- September gap). Nil for what makes no difference.
function PT.spots.peak(itemId)
  if not peaks[itemId] then peaks[itemId] = { peak(itemId) } end
  local found = peaks[itemId]
  return found[1], found[2], found[3], found[4]
end

local function condition(itemId)
  if next(PT.data.areasWith(itemId)) == nil then
    local pools = PT.spots.pools(itemId)
    for _, found in ipairs(pools) do
      if found.pool.event ~= 'extravaganza' then return end
    end
    return pools[1] and 'e' or nil
  end
  local only
  for id in pairs(PT.data.areasWith(itemId)) do
    for _, row in ipairs(PT.data.area(id).loot) do
      if row[1] == itemId then
        if not row[4] or only and only ~= row[4] then return end
        only = row[4]
      end
    end
  end
  return only
end

-- 'd', 'n', 's', 'w' or 'k410' when the item only ever bites under that condition, 'e' when only
-- the Extravaganza's pools have it, else nil.
function PT.spots.condition(itemId)
  if conditions[itemId] == nil then conditions[itemId] = condition(itemId) or false end
  return conditions[itemId] or nil
end

-- The pools that drop the item, each { pool, chance }, best first.
function PT.spots.pools(itemId)
  if poolLists[itemId] then return poolLists[itemId] end
  local found = {}
  for id, pool in pairs(PT.data.pools) do
    local chance = chances(pool.loot, true, false, false)[itemId]
    if chance and chance > 0 then table.insert(found, { pool = pool, chance = chance }) end
  end
  table.sort(found, function (a, b) return a.chance > b.chance end)
  poolLists[itemId] = found
  return found
end

-- `yours` for any season, by area and then by day (1), night (2) or any hour (3), kept until the
-- history changes
local yoursCache, yoursAt = {}, nil

local function yours(area, day, season)
  if area.zone then
    return PT.catches.counts(PT.data.area(area.zone).name, area.name, day, season)
  end

  local total, catches = {}, 0
  for subzone in pairs(PT.catches.subzones(area.name)) do
    if PT.data.spot(area.name, subzone) == area then
      local counts, n = PT.catches.counts(area.name, subzone, day, season)
      for id, count in pairs(counts) do total[id] = (total[id] or 0) + count end
      catches = catches + n
    end
  end
  return total, catches
end

-- The player's catches under an area's table, like `catches.counts`. A zone's table is also the one
-- rolled in every subzone of it without a table of its own, so their catches count for the zone.
function PT.spots.yours(area, day, season)
  if season then return yours(area, day, season) end
  if yoursAt ~= PT.catches.version() then yoursCache, yoursAt = {}, PT.catches.version() end
  local key = day == nil and 3 or day and 1 or 2
  if not yoursCache[area] then yoursCache[area] = {} end
  local found = yoursCache[area][key]
  if not found then
    found = { yours(area, day) }
    yoursCache[area][key] = found
  end
  return found[1], found[2]
end

-- Every item a pool gives, like `at` but per catch from the pool, by the clock of the zone it's in.
function PT.spots.inPool(pool, map)
  local summer, winter = PT.clock.event('summer'), PT.clock.event('winter')
  local day = chances(pool.loot, true, summer, winter)
  local night = chances(pool.loot, false, summer, winter)
  local isDay = PT.clock.isDay((PT.clock.zoneTime(map)))
  local items = {}
  for id in pairs(day) do
    local dayChance, nightChance = day[id] or 0, night[id] or 0
    if dayChance > 0 or nightChance > 0 then
      table.insert(items, { id = id, pool = pool, day = dayChance, night = nightChance,
        now = isDay and dayChance or nightChance, isDay = isDay })
    end
  end
  table.sort(items, function (a, b) return a.now > b.now end)
  return items
end

-- Every item an area's table gives, each { id, area, required, day, night, now, isDay } like `of`,
-- best now first.
function PT.spots.at(area)
  local summer, winter = PT.clock.event('summer'), PT.clock.event('winter')
  local now = state(summer, winter)
  if now ~= ofState then ofCache, atCache, ofState = {}, {}, now end
  if atCache[area] then return atCache[area] end
  local day = chances(area.loot, true, summer, winter)
  local night = chances(area.loot, false, summer, winter)
  local isDay = PT.clock.isDay((PT.clock.zoneTime(area.map)))
  local required = PT.spots.required(area)
  local items, seen = {}, {}
  for _, row in ipairs(area.loot) do
    local id = row[1]
    if not seen[id] and ((day[id] or 0) > 0 or (night[id] or 0) > 0) then
      seen[id] = true
      local dayChance, nightChance = day[id] or 0, night[id] or 0
      table.insert(items, { id = id, area = area, required = required, day = dayChance, night = nightChance,
        now = isDay and dayChance or nightChance, isDay = isDay })
    end
  end
  table.sort(items, function (a, b) return a.now > b.now end)
  atCache[area] = items
  return items
end

-- For an item no table has: the tables of every place the player caught it, as spots without a
-- chance (`unknown`), for the player's own rates.
function PT.spots.caughtAt(itemId)
  local seen, spots = {}, {}
  PT.catches.each(function (zone, subzone, id, _, n)
    local area = id == itemId and n > 0 and PT.data.spot(zone, subzone)
    if area and not seen[area] then
      seen[area] = true
      table.insert(spots, { area = area, required = PT.spots.required(area), day = 0, night = 0, now = 0,
        isDay = PT.clock.isDay((PT.clock.zoneTime(area.map))), unknown = true })
    end
  end)
  table.sort(spots, function (a, b) return a.area.name < b.area.name end)
  return spots
end

-- How often the player caught the item under a spot's table (from `of` or `at`): by day (`day`
-- true), at night (false) or at any hour (nil), in any season, FishingBuddy's imports included.
-- Returns hits, catches.
function PT.spots.mine(spot, itemId, day)
  local counts, catches = PT.spots.yours(spot.area, day)
  return counts[itemId] or 0, catches
end

-- The skill it takes to catch the item at a spot: the water's own level, or 410 for a row that needs it.
function PT.spots.skill(spot, itemId)
  for _, row in ipairs(spot.area.loot) do
    if row[1] == itemId and row[4] == 'k410' then return math.max(spot.required, PT.loot.ELITE_SKILL) end
  end
  return spot.required
end
