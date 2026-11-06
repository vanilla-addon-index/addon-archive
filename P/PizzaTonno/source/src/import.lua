local PT = PizzaTonno
PT.import = {}

local CATCH = 0
-- FishingBuddy knows the zone hour but not the season ('?07'), or neither for its older catches
local UNKNOWN_SEASON, UNKNOWN_HOUR = '?', '???'

local function add(store, zone, subzone, id, key, n)
  store[zone] = store[zone] or {}
  store[zone][subzone] = store[zone][subzone] or {}
  local spot = store[zone][subzone]
  spot[id] = spot[id] or {}
  spot[id][key] = (spot[id][key] or 0) + n
end

-- Catches of an item PizzaTonno already recorded while FishingBuddy ran, at this zone hour.
local function overlap(zone, subzone, itemId, hour)
  local saved = PizzaTonno_catches.fbOverlap
  local keys = saved[zone] and saved[zone][subzone] and saved[zone][subzone][itemId] or {}
  local n = 0
  for key, count in pairs(keys) do
    if tonumber(string.sub(key, -2)) == hour then n = n + count end
  end
  return n
end

-- Something this water can't drop but a pool of the zone can: FishingBuddy mixed pool catches in.
local function fromPool(zone, area, itemId)
  return area and not PT.data.areasWith(itemId)[area.id] and PT.data.poolDrops(zone, itemId)
end

-- FishingBuddy's history minus what PizzaTonno already has, in the shape of `PizzaTonno_catches.areas`.
-- FishingBuddy counts items, never catches; one fish is one catch, so the items make the catch count.
-- Returns the result, the catches it holds and the ones left out as already recorded.
local function build(fb)
  local result, catches, skipped = { areas = {}, pools = {} }, 0, 0

  for zoneIndex, subzones in pairs(fb.FishingHoles) do
    local zone = fb.ZoneIndex[zoneIndex]
    for subzoneIndex, totals in pairs(subzones) do
      local subzone = fb.SubZones[zoneIndex][subzoneIndex]
      -- FishingBuddy files a spot without a subzone under the zone's name
      if subzone == zone then subzone = '' end
      local area = PT.data.spot(zone, subzone)
      local hours = fb.FishingTimes[zoneIndex] and fb.FishingTimes[zoneIndex][subzoneIndex] or {}

      for itemId, total in pairs(totals) do
        local store = fromPool(zone, area, itemId) and result.pools or result.areas
        local function keep(key, n)
          if n <= 0 then return end
          add(store, zone, subzone, itemId, key, n)
          add(store, zone, subzone, CATCH, key, n)
          catches = catches + n
        end

        local timed = 0
        for hour, items in pairs(hours) do
          local n = items[itemId] or 0
          local both = math.min(overlap(zone, subzone, itemId, hour), n)
          timed, skipped = timed + n, skipped + both
          keep(UNKNOWN_SEASON .. string.format('%02d', hour), n - both)
        end
        keep(UNKNOWN_HOUR, total - timed)
      end
    end
  end
  return result, catches, skipped
end

local pending

StaticPopupDialogs['PIZZATONNO_IMPORT'] = {
  text = 'Import your FishingBuddy history into PizzaTonno?\n\n%s',
  button1 = 'Import',
  button2 = 'No',
  timeout = 0,
  whileDead = 1,
  OnAccept = function ()
    PizzaTonno_catches.imported = pending.result
    PT.catches.changed()
    PizzaTonno_config.fbImport = 'yes'
    PT:Print('Imported ' .. pending.catches .. ' catches from FishingBuddy.')
    PT.hud.refresh()
    PT.almanac.refresh()
  end,
  OnCancel = function ()
    PizzaTonno_config.fbImport = PizzaTonno_config.fbImport or 'no'
  end,
}

-- Asks with the numbers first. Importing again replaces the earlier import, so nothing doubles.
function PT.import.ask()
  if not FishingBuddy_Info then
    PT:Print('FishingBuddy isn\'t loaded. Enable it for one session to import its history.')
    return
  end

  local result, catches, skipped = build(FishingBuddy_Info)
  pending = { result = result, catches = catches }
  local details = 'FishingBuddy has ' .. catches + skipped .. ' catches.'
  if skipped > 0 then
    details = details .. ' PizzaTonno already counted ' .. skipped .. ' of them while both addons were on, so '
      .. catches .. ' will be added.'
  end
  StaticPopup_Show('PIZZATONNO_IMPORT', details)
end

local frame = CreateFrame('Frame')
frame:RegisterEvent('PLAYER_LOGIN')
frame:SetScript('OnEvent', function ()
  if FishingBuddy_Info and not PizzaTonno_config.fbImport then PT.import.ask() end
end)
