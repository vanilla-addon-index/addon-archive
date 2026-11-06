local PT = PizzaTonno
PT.catches = {}

-- Stored next to the item ids: how many catches (loot windows) a spot saw, the base for rates.
local CATCH = 0

-- this session's open-water catches, same shape as the saved `areas`
local session = {}
-- goes up with every change to the history, so views can tell when theirs is out of date
local version = 0
-- what `daily` hands out for a day without catches
local NONE = {}

local function bump(store, zone, subzone, id, key)
  store[zone] = store[zone] or {}
  store[zone][subzone] = store[zone][subzone] or {}
  local spot = store[zone][subzone]
  spot[id] = spot[id] or {}
  spot[id][key] = (spot[id][key] or 0) + 1
end

-- The player's own calendar day: days and time fished are kept by local date (UTC before 2026-10-02).
local function today()
  return date('%Y-%m-%d')
end

-- One catch, with every item in its loot window. Counts are keyed by season and zone hour
-- ('s07', 'sw19', '13'), so day/night and season can be told apart later. The log keeps every catch
-- as it happened, for stats nobody has thought of yet.
function PT.catches.add(zone, subzone, itemIds, fromPool)
  local saved = PizzaTonno_catches
  version = version + 1
  local key = PT.clock.season() .. string.format('%02d', (GetGameTime()))
  local day = today()
  saved.days[day] = saved.days[day] or {}
  saved.days[day][CATCH] = (saved.days[day][CATCH] or 0) + 1
  table.insert(saved.log, { time = time(), zone = zone, subzone = subzone, skill = (PT.player.skill()),
    lure = PT.player.lure() and true or nil, pool = fromPool or nil, items = itemIds })

  local function count(store, id)
    bump(store, zone, subzone, id, key)
    -- FishingBuddy records the same catch while both run; its import subtracts these.
    if IsAddOnLoaded('FishingBuddy') then bump(saved.fbOverlap, zone, subzone, id, key) end
  end

  local store = fromPool and saved.pools or saved.areas
  count(store, CATCH)
  if not fromPool then bump(session, zone, subzone, CATCH, key) end
  for _, itemId in ipairs(itemIds) do
    count(store, itemId)
    if not fromPool then bump(session, zone, subzone, itemId, key) end
    saved.days[day][itemId] = (saved.days[day][itemId] or 0) + 1
  end
end

function PT.catches.addTime(seconds)
  version = version + 1
  local fished = PizzaTonno_catches.fished
  fished[today()] = (fished[today()] or 0) + seconds
end

function PT.catches.newSession()
  version = version + 1
  session = {}
end

function PT.catches.version()
  return version
end

-- For changes made from outside, like an import.
function PT.catches.changed()
  version = version + 1
end

-- The hour and the season of a key ('s07' is 7 and 's'), worked out once per key: there are only a
-- few hundred of them.
local hours, seasons = {}, {}

local function parse(key)
  if not seasons[key] then
    hours[key] = tonumber(string.sub(key, -2)) or false
    seasons[key] = string.sub(key, 1, -3)
  end
  return hours[key], seasons[key]
end

local function addCounts(counts, store, zone, subzone, day, season)
  local spot = store[zone] and store[zone][subzone]
  if not spot then return end
  for id, keys in pairs(spot) do
    for key, n in pairs(keys) do
      local hour, keySeason = parse(key)
      local sameLight = day == nil or hour and PT.clock.isDay(hour) == day
      local sameSeason = season == nil or keySeason == season
      if sameLight and sameSeason then
        counts[id] = (counts[id] or 0) + n
      end
    end
  end
end

-- How often the player caught each item in a spot's open water, and out of how many catches, the
-- FishingBuddy import included. `day` narrows it to day (true) or night (false) hours, `season` to
-- catches made in that season ('s', 'w', 'sw' or ''), `thisSession` to the catches since the session
-- began. Imported catches of unknown season ('?07') or hour ('???') drop out of those filters.
function PT.catches.counts(zone, subzone, day, season, thisSession)
  local saved, counts = PizzaTonno_catches, {}
  if thisSession then
    addCounts(counts, session, zone, subzone, day, season)
  else
    addCounts(counts, saved.areas, zone, subzone, day, season)
    addCounts(counts, saved.imported.areas, zone, subzone, day, season)
  end
  return counts, counts[CATCH] or 0
end

-- Every subzone of the zone the player has catches in, own or imported.
function PT.catches.subzones(zone)
  local saved, subzones = PizzaTonno_catches, {}
  for subzone in pairs(saved.areas[zone] or NONE) do subzones[subzone] = true end
  for subzone in pairs(saved.imported.areas[zone] or NONE) do subzones[subzone] = true end
  return subzones
end

-- One local date ('2026-10-01'): catches, how often each item came up, seconds fished. Days before the
-- catch count was stored fall back to the items (one per catch, nearly always).
function PT.catches.daily(day)
  local saved = PizzaTonno_catches
  local items = saved.days[day] or NONE
  local catches = items[CATCH]
  if not catches then
    catches = 0
    for _, n in pairs(items) do catches = catches + n end
  end
  return catches, items, saved.fished[day] or 0
end

-- Calls fn(zone, subzone, itemId, key, n, imported) for every count in the history, open water and
-- pools, own and imported. Item id 0 counts the catches themselves.
function PT.catches.each(fn)
  local saved = PizzaTonno_catches
  local stores = { { saved.areas }, { saved.pools }, { saved.imported.areas, true }, { saved.imported.pools, true } }
  for _, store in ipairs(stores) do
    for zone, subzones in pairs(store[1]) do
      for subzone, items in pairs(subzones) do
        for id, keys in pairs(items) do
          for key, n in pairs(keys) do fn(zone, subzone, id, key, n, store[2]) end
        end
      end
    end
  end
end
