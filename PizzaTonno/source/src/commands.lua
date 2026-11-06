local PT = PizzaTonno
local C = PT.Colors

local CONTINENTS = { { 'Eastern Kingdoms', 0 }, { 'Kalimdor', 1 } }

local function phase(hour)
  return PT.clock.isDay(hour) and C.day .. 'day|r' or C.night .. 'night|r'
end

local function eventLine(label, event)
  local active, seconds = PT.clock.event(event)
  if active then return label .. ' ' .. C.green .. 'now|r, ends in ' .. PT.utils.duration(seconds) end
  return label .. ' in ' .. PT.utils.duration(seconds)
end

local function printHere()
  local zoneName, subzoneName = PT.player.location()
  local area, required = PT.data.spot(zoneName, subzoneName)
  if not area then
    PT:Print('No fishing data for ' .. subzoneName .. ', ' .. zoneName)
    return
  end

  local skill, rank, modifier = PT.player.skill()
  local hour = GetGameTime()
  PT:Print(subzoneName .. ', ' .. zoneName .. C.grey .. ' - loot of ' .. area.name .. ', ' .. phase(hour))
  PT:PrintClean(C.grey .. '   skill|r ' .. skill .. C.grey .. ' (' .. rank .. ' +' .. modifier .. '), needs|r ' .. required
    .. C.grey .. ', lands|r ' .. PT.utils.percent(PT.loot.landing(skill, required)))

  local chances, sorted = PT.loot.chances(area.loot, PT.loot.conditions(hour, skill)), {}
  for itemId, p in pairs(chances) do
    if p > 0 then table.insert(sorted, itemId) end
  end
  table.sort(sorted, function (a, b) return chances[a] > chances[b] end)

  for _, itemId in ipairs(sorted) do
    PT:PrintClean('   ' .. PT.utils.percent(chances[itemId]) .. ' ' .. (PT.data.item(itemId) or itemId))
  end
end

local function printTime()
  for _, continent in ipairs(CONTINENTS) do
    local name, map = continent[1], continent[2]
    local hour, minute = PT.clock.zoneTime(map)
    PT:PrintClean(C.primary .. '   ' .. name .. '|r ' .. string.format('%02d:%02d', hour, minute) .. ' ' .. phase(hour)
      .. C.grey .. ', flips in ' .. PT.utils.duration(PT.clock.untilFlip(hour, minute) * 60))
  end
  PT:PrintClean('   ' .. eventLine('Summer', 'summer'))
  PT:PrintClean('   ' .. eventLine(C.winter .. 'Winter|r', 'winter'))
  PT:PrintClean('   ' .. eventLine('Extravaganza', 'extravaganza'))
end

SLASH_PIZZATONNO1, SLASH_PIZZATONNO2 = '/pt', '/tonno'
SLASH_PIZZATONNOFISH1 = '/fish'
SlashCmdList['PIZZATONNOFISH'] = function () PT.almanac.toggle() end

SlashCmdList['PIZZATONNO'] = function (args)
  local cmd = PT.utils.strSplit(args, ' ')
  local command = cmd and string.lower(cmd)

  if command == 'lock' then
    PizzaTonno_character.locked = true
    PT:Print('HUD locked')
    return
  end

  if command == 'unlock' then
    PizzaTonno_character.locked = false
    PT:Print('HUD unlocked. Drag to move.')
    return
  end

  if command == 'reset' then
    PT.hud.resetPosition()
    PT:Print('HUD position reset')
    return
  end

  if command == 'watch' then
    local itemId = PT.utils.itemId(args)
    if not itemId then
      PT:Print('Shift-click an item into the command: ' .. C.primary .. '/pt watch|r [item]')
      return
    end

    local name = PT.data.item(itemId) or 'Item ' .. itemId
    PT:Print(PT:ToggleWatch(itemId) and 'Watching ' .. name or 'No longer watching ' .. name)
    PT.hud.refresh()
    PT.almanac.refresh()
    return
  end

  if command == 'demo' then
    PT.hud.toggleDemo()
    return
  end

  if command == 'import' then
    PT.import.ask()
    return
  end

  if command == 'minimap' then
    PT.minimap.toggle()
    return
  end

  if command == 'almanac' then
    PT.almanac.toggle()
    return
  end

  if command == 'here' then
    printHere()
    return
  end

  if command == 'time' then
    printTime()
    return
  end

  PT:PrintClean(C.primary .. 'Pizza' .. C.secondary .. 'Tonno|r commands:')
  PT:PrintClean(C.primary .. '   /fish|r ' .. C.grey .. '- Open or close the almanac (also /pt almanac)')
  PT:PrintClean(C.primary .. '   /pt|r lock ' .. C.grey .. '- Lock the HUD in place')
  PT:PrintClean(C.primary .. '   /pt|r unlock ' .. C.grey .. '- Unlock the HUD and drag to move')
  PT:PrintClean(C.primary .. '   /pt|r reset ' .. C.grey .. '- Reset the HUD position')
  PT:PrintClean(C.primary .. '   /pt|r watch [item] ' .. C.grey .. '- Watch or unwatch a fish (or right-click it in the HUD)')
  PT:PrintClean(C.primary .. '   /pt|r import ' .. C.grey .. '- Import your FishingBuddy history (again)')
  PT:PrintClean(C.primary .. '   /pt|r minimap ' .. C.grey .. '- Show or hide the minimap button')
  PT:PrintClean(C.primary .. '   /pt|r here ' .. C.grey .. '- Every catch chance where you stand')
  PT:PrintClean(C.primary .. '   /pt|r time ' .. C.grey .. '- Zone clocks, seasons and the Extravaganza')
end
