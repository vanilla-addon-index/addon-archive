dofile('libs/package.lua')
local function setup(name, code)
    assert(loadstring("module '" .. name .. "'\n" .. code))()
end
setup('aux', [[
M.print = function(message) table.insert(messages, message) end
M.tab = function() return {} end
M.handle = {}
M.account_data = {post_duration = 120}
]])
setup('T', [[
M.temp = setmetatable({}, {__sub=function(_, value) return value end})
M.map = function(...)
    local result = {}
    for i = 1, arg.n, 2 do result[arg[i] ] = arg[i+1] end
    return result
end
]])
messages = {}
local tick = 0
function debugprofilestop() tick = tick + 3; return tick end
function GetTime() return 10 end
function UpdateAddOnMemoryUsage() end
function GetAddOnMemoryUsage(name) assert(name == 'aux-addon'); return 42 end
dofile('core/profile.lua')
local profile = require 'aux.core.profile'
assert(not profile.begin())
profile.command('stock')
assert(profile.stock_bags)
profile.finish(1, profile.begin())
profile.command('stop')
assert(not profile.begin() and not profile.stock_bags)
assert(string.find(messages[3], '1 calls, 3.00 total, 3.00 max', 1, true))
assert(string.find(messages[7], '42.0', 1, true))

dofile('tabs/post/core.lua')
local post = getfenv(require('aux.tabs.post').select_item)
assert(post.read_settings().stack_size == 1)
post.write_settings({})
post.set_bid_selection({})
post.set_buyout_selection({})
assert(post.get_bid_selection() == nil and post.get_buyout_selection() == nil)

function CreateFrame() AuxTooltip = {SetScript=function() end} end
gsub = string.gsub
ITEM_SPELL_CHARGES_P1 = '%d Charges'
DURABILITY_TEMPLATE = 'Durability %d / %d'
dofile('util/info.lua')
local info = require 'aux.util.info'
local env = getfenv(info.container_item)
env.parse_link = function() return 1, 0 end
env.item = function() return {itemstring='item:1'} end
local tooltip_reads = 0
env.tooltip = function() tooltip_reads = tooltip_reads + 1; return {}, 0 end
local stock_reads = 0
function GetContainerItemLink() stock_reads = stock_reads + 1; return 'item:1' end
function GetContainerItemInfo() return 'stock icon', 3 end
local buffer = {}
C_Container = {GetContainerItemInfo=function(bag, slot, buf)
    assert(buf == buffer)
    if slot == 2 then return nil end
    if slot == 3 then return {hyperlink='item:1'} end
    buf.hyperlink, buf.iconFileID, buf.stackCount, buf.hasLoot = 'item:1', 'native icon', 7, false
    return buf
end}
assert(info.container_item(0, 1, buffer).count == 7 and stock_reads == 0)
assert(info.container_item(0, 2, buffer) == nil and tooltip_reads == 1)
assert(info.container_item(0, 3, buffer).count == 3 and stock_reads == 1)
assert(info.container_item(0, 1).count == 3 and stock_reads == 2)
C_Container = nil
assert(info.container_item(0, 1, buffer).count == 3 and stock_reads == 3)
print('PASS profiler, empty Post selection, and native/empty/incomplete/stock bag reads')
