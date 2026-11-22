dofile('libs/package.lua')
local function setup(name, code)
    assert(loadstring("module '" .. name .. "'\n" .. code))()
end
setup('aux', [[
M.huge = 1/0
M.print = function(message) last_message = message end
M.account_data = {}
M.faction_data = {history={}}
M.price_market_key = 'Octo|Horde'
M.handle = setmetatable({}, {__newindex=function(_, key, f)
    handlers[key] = handlers[key] or {}
    table.insert(handlers[key], f)
end})
M.round = function(n) return math.floor(n+.5) end
]])
handlers = {}
function CreateFrame() return {RegisterEvent=function() end, SetScript=function() end} end
function GetChannelName() return 1, 'LFT' end
time, date = os.time, os.date
dofile('core/history.lua')
dofile('core/shared_prices.lua')
local aux = require 'aux'
local history = require 'aux.core.history'
local sharing = require 'aux.core.shared_prices'
local files = {}
function ReadCustomFile(name) return files[name] end
function WriteCustomFile(name, value) files[name] = value end
local day = history.shared_day()
local yesterday = day-86400
local older = yesterday-86400
local first = {['1:0']=day..'#300#120@'..yesterday}
local second = {['1:0']=day..'#200#140@'..yesterday..';180@'..older, ['2:-1']=day..'#500#'}
local function login(records)
    aux.faction_data.history = records
    for _, f in ipairs(handlers.LOAD2) do f() end
end
login(first)
sharing.command('on')
assert(aux.account_data.share_local_prices)
aux.account_data.share_local_prices = false
login(second)
sharing.command('on')
assert(second['1:0']==day..'#200#120@'..yesterday..';180@'..older)
login(first)
assert(first['1:0']==second['1:0'] and first['2:-1']==second['2:-1'])
first['3:0']=day..'#400#'
for _, f in ipairs(handlers.CLOSE) do f() end
login(second)
assert(second['3:0']==first['3:0'])
setup('aux', [[M.price_market_key = 'Octo|Alliance']])
login({})
assert(next(aux.faction_data.history)==nil)
assert(history.merge_shared_record(nil, yesterday..'#9#', day)==day..'##9@'..yesterday)
assert(not history.is_shared_record(day..'##1@2222@333'))
assert(not history.is_shared_record('return error("test")'))
sharing.command('off')
assert(not aux.account_data.share_local_prices)
WriteCustomFile=nil
sharing.command('on')
assert(not aux.account_data.share_local_prices)
print('PASS cross-account merge, rollover, auction-close sync, market isolation, invalid data and missing Nampower')
