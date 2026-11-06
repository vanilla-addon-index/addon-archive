local PT = PizzaTonno
PT.clock = {}

local KALIMDOR = 1

local function offset(map)
  return map == KALIMDOR and 12 or 0
end

-- GetGameTime() is the clock of the zone the player is in (realm time = UTC, Kalimdor +12h), the one
-- the loot conditions use. Outside the known zones fall back to the PC clock.
function PT.clock.utc()
  local zone = PT.data.zone(GetRealZoneText())
  if not zone then
    local now = time()
    return math.floor(math.mod(now, 86400) / 3600), math.floor(math.mod(now, 3600) / 60)
  end

  local hour, minute = GetGameTime()
  return math.mod(hour - offset(zone.map) + 24, 24), minute
end

function PT.clock.zoneTime(map)
  local hour, minute = PT.clock.utc()
  return math.mod(hour + offset(map), 24), minute
end

function PT.clock.isDay(hour)
  return hour >= 6 and hour < 18
end

-- Minutes until day turns to night or back, given a zone's clock.
function PT.clock.untilFlip(hour, minute)
  local flip = PT.clock.isDay(hour) and 18 or 6
  return math.mod((flip - hour) * 60 - minute + 1440, 1440)
end

-- Whether a game event runs now (or at the epoch second `at`), and the seconds until it ends (if
-- running) or next starts.
function PT.clock.event(name, at)
  local event = PT.data.events[name]
  local elapsed = math.mod((at or time()) - event.start, event.period)
  if elapsed < event.length then return true, event.length - elapsed end
  return false, event.period - elapsed
end

-- 's', 'w', 'sw' (they overlap in March) or '' (the gap in September)
function PT.clock.season()
  return (PT.clock.event('summer') and 's' or '') .. (PT.clock.event('winter') and 'w' or '')
end
