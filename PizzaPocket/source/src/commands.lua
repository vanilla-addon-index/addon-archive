local PP = PizzaPocket

local HELP = {
  { '/pick', '', 'Pick Pocket the nearest unpicked enemy' },
  { '/pick', 'reset', 'Clear history' },
  { '/pick', 'count', 'Show count' },
  { '/pick', 'status', 'Show count and which targeting path is in use' },
  { '/pick', 'debug', 'Toggle debug output' },
  { '/pick', 'throttle N', 'Seconds between attempts (without ClassicAPI)' },
  { '/pick', 'cycles N', 'Enemies cycled per attempt (without ClassicAPI)' },
  { '/pick', 'stats', 'Toggle the fail rate frame (show, hide)' },
  { '/pick', 'stats auto', 'Toggle showing it in dungeons when solo or duo' },
  { '/pick', 'stats report', 'Full breakdown in chat' },
  { '/pick', 'stats reset [all]', 'Wipe session, or all-time stats' },
  { '/pick', 'gold', 'Gold made this run, and the average for this dungeon' },
  { '/pick', 'gold reset', 'Forget all finished runs' },
  { '/unlock', '', 'Pick Lock next locked junkbox in bags' },
}

local function printHelp()
  local c = PP.Colors
  PP:PrintClean(c.primary .. 'Pizza' .. c.secondary .. 'Pocket|r commands:')
  for i = 1, table.getn(HELP) do
    local cmd, args, desc = HELP[i][1], HELP[i][2], HELP[i][3]
    if args ~= '' then args = args .. ' ' end
    PP:PrintClean(c.primary .. '   ' .. cmd .. '|r ' .. args .. c.grey .. '- ' .. desc)
  end
end

local function pickedCount()
  local n = 0
  for _ in pairs(PP.picked) do n = n + 1 end
  return n
end

local function pathName()
  local backend = PP.finder.active()
  return backend and backend.name or 'none (missing dependencies)'
end

local function legacyOnly()
  if PP.finder.active() == PP.finder.classic then
    PP:Print('Only used without ClassicAPI, which is loaded')
  end
end

local function handleStats(sub, arg)
  local sf = PP.statsframe

  if sub == 'report' then
    PP.stats.report('Session', PP.stats.session)
    PP.stats.report('All-time', PP.stats.alltime)
    return
  end

  if sub == 'reset' then
    if arg == 'all' then
      PP.stats.alltime = PP.stats.new()
      PizzaPocketDB.alltime = PP.stats.alltime
      PP:Print('All-time stats wiped')
    else
      PP.stats.session = PP.stats.new()
      PP:Print('Session stats wiped')
    end
    sf.update()
    return
  end

  if sub == 'auto' then
    PizzaPocketDB.autoStats = not PizzaPocketDB.autoStats
    if PizzaPocketDB.autoStats then
      PP:Print('Auto show on: dungeons, solo or duo only')
      sf.updateAuto()
    else
      PP:Print('Auto show off')
    end
    return
  end

  sf.stopAuto()
  if sub == 'show' then
    sf.show(true)
  elseif sub == 'hide' then
    sf.show(false)
  else
    sf.toggle()
  end
end

SLASH_PIZZAPOCKET1 = '/pick'
SLASH_PIZZAPOCKET2 = '/pizzapocket'

SlashCmdList['PIZZAPOCKET'] = function (args)
  args = string.lower(args or '')
  local command, sub, arg = PP.utils.strSplit(args, ' ')
  local legacy = PP.finder.legacy

  if command == 'reset' or command == 'clear' then
    PP.picked = {}
    PP:Print('History cleared')
    return
  end

  if command == 'count' then
    PP:Print('Picked ' .. pickedCount() .. ' mobs this run')
    return
  end

  if command == 'status' then
    PP:Print('Picked ' .. pickedCount() .. ' mobs this run')
    PP:Print('Path: ' .. pathName())
    return
  end

  if command == 'debug' then
    PP.debug = not PP.debug
    PP:Print('Debug mode: ' .. (PP.debug and 'ON' or 'OFF'))
    if PP.debug then PP:Print('Path: ' .. pathName()) end
    return
  end

  if command == 'throttle' then
    local _, _, value = string.find(args, '([%d%.]+)')
    local n = tonumber(value)
    if n then legacy.throttle = math.min(math.max(n, 0.05), 2) end
    PP:Print(string.format('Throttle: %.2fs between attempts', legacy.throttle))
    legacyOnly()
    return
  end

  if command == 'cycles' then
    local _, _, value = string.find(args, '(%d+)')
    local n = tonumber(value)
    if n then legacy.maxCycle = math.min(math.max(n, 1), 40) end
    PP:Print('Cycles: up to ' .. legacy.maxCycle .. ' enemies per attempt')
    legacyOnly()
    return
  end

  if command == 'stats' then
    handleStats(sub, arg)
    return
  end

  if command == 'gold' then
    if sub == 'reset' then
      PP.gold.resetHistory()
      PP.statsframe.update()
      PP:Print('Run history wiped')
      return
    end
    PP:Print('This run: ' .. PP.gold.describe(PP.gold.current()))
    local avg, perHour, runs = PP.gold.average()
    PP:Print('Average: ' .. PP.gold.describe(avg, perHour) .. (runs and ' over ' .. runs .. ' runs' or ''))
    return
  end

  if command == 'help' then
    printHelp()
    return
  end

  PP.finder.pick()
end

SLASH_PPUNLOCK1 = '/unlock'

SlashCmdList['PPUNLOCK'] = function ()
  PP.junkbox.unlock()
end
