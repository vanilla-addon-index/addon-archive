local PP = PizzaPocket

PP.gold = {}
local gold = PP.gold

local RESET_PATTERN = PP.utils.buildPattern(INSTANCE_RESET_SUCCESS or '%s has been reset.')

local run
local history
local freshLogin
-- GetMoney() has read 0 during loading or logout, so only trust values read in the world.
local money

local function wipe()
  for k in pairs(run) do run[k] = nil end
end

local function now()
  return run.pausedMoney or money, run.pausedAt or time()
end

local function pause()
  if not run.start or run.pausedAt or not money then return end
  run.pausedMoney, run.pausedAt = money, time()
end

local function resume()
  if not run.pausedAt then return end
  run.start = run.start + money - run.pausedMoney
  if run.began then run.began = run.began + time() - run.pausedAt end
  run.pausedMoney, run.pausedAt = nil, nil
end

function gold.describe(net, perHour)
  if not net then return 'nothing yet' end
  local rate = perHour and ', ' .. PP.utils.coins(perHour) .. '/h' or ''
  return PP.utils.coins(net) .. rate
end

local function record()
  if not run.start or not run.began then return end
  local balance, clock = now()
  local net = balance - run.start
  if net == 0 then return end

  local seconds = clock - run.began
  local h = history[run.zone] or { runs = 0, copper = 0, seconds = 0 }
  h.runs = h.runs + 1
  h.copper = h.copper + net
  h.seconds = h.seconds + seconds
  history[run.zone] = h

  local perHour = seconds > 0 and net / seconds * 3600 or nil
  PP:Print('Last run in ' .. run.zone .. ': ' .. gold.describe(net, perHour))
end

local function start(zone)
  record()
  wipe()
  run.zone, run.start, run.began = zone, money, time()
  PP.statsframe.update()
end

local function settle()
  if not freshLogin then return end
  -- Not paused means the client never logged out cleanly, so the run's end is unknown.
  if run.pausedAt then record() end
  wipe()
end

function gold.current()
  if not run or not run.start or not money then return nil end
  local balance, clock = now()
  local net = balance - run.start
  if not run.began then return net end
  local seconds = clock - run.began
  if seconds < 60 then return net end
  return net, net / seconds * 3600
end

function gold.average()
  local h = run and run.zone and history[run.zone]
  if not h then return nil end
  local perHour = h.seconds > 0 and h.copper / h.seconds * 3600 or nil
  return h.copper / h.runs, perHour, h.runs
end

function gold.resetHistory()
  PizzaPocketDB.history = {}
  history = PizzaPocketDB.history
end

function gold.check()
  if not run or freshLogin == nil then return end
  money = GetMoney()
  local inInstance, kind = IsInInstance()
  if not inInstance or (kind ~= 'party' and kind ~= 'raid') then
    pause()
    PP.statsframe.update()
    return
  end
  local zone = GetRealZoneText()
  if run.over or zone ~= run.zone then
    start(zone)
  else
    resume()
  end
end

function gold.load()
  if type(PizzaPocketDB.run) ~= 'table' then PizzaPocketDB.run = {} end
  if type(PizzaPocketDB.history) ~= 'table' then PizzaPocketDB.history = {} end
  run = PizzaPocketDB.run
  history = PizzaPocketDB.history
  if freshLogin ~= nil then settle() end
  gold.check()
end

-- Without ClassicAPI a /reload can't be told apart from a login, so both end the run.
function gold.onEnteringWorld(isInitialLogin)
  if freshLogin == nil then
    freshLogin = isInitialLogin or not CLASSIC_API_VERSION
    if run then settle() end
  end
  gold.check()
end

function gold.onMoney()
  if freshLogin ~= nil then money = GetMoney() end
end

function gold.onLogout()
  if run then pause() end
end

function gold.onSystemMessage(msg)
  if not run or not msg or not string.find(msg, RESET_PATTERN) then return end
  run.over = true
  pause()
end
