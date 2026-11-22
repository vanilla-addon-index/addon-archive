module 'aux.core.profile'

local aux = require 'aux'
local clock = type(debugprofilestop) == 'function' and debugprofilestop or function() return GetTime() * 1000 end
local labels = {'Auction tooltip', 'Record sort', 'Display sort', 'Post bag rebuild'}
local calls, totals, peaks = {}, {}, {}
local started, memory_before
local active = false
M.stock_bags = false

local function memory()
    if type(UpdateAddOnMemoryUsage) == 'function' and type(GetAddOnMemoryUsage) == 'function' then
        UpdateAddOnMemoryUsage()
        return GetAddOnMemoryUsage('aux-addon')
    end
end

function M.begin()
    if active then return clock() end
end

function M.finish(index, start)
    if start then
        local elapsed = math.max(0, clock() - start)
        calls[index] = calls[index] + 1
        totals[index] = totals[index] + elapsed
        peaks[index] = math.max(peaks[index], elapsed)
    end
end

function M.command(action)
    if action == 'start' or action == 'stock' then
        for i = 1, table.getn(labels) do
            calls[i], totals[i], peaks[i] = 0, 0, 0
        end
        M.stock_bags = action == 'stock'
        memory_before = memory()
        started = GetTime()
        active = true
        aux.print('Profiling started. Post bag path: ' .. (action == 'stock' and 'stock' or 'ClassicAPI when available') .. '.')
    elseif action == 'stop' and active then
        active, M.stock_bags = false, false
        aux.print(string.format('Profile over %.1fs (timings in ms):', GetTime() - started))
        for i, label in ipairs(labels) do
            aux.print(string.format('%s: %d calls, %.2f total, %.2f max', label, calls[i], totals[i], peaks[i]))
        end
        local after = memory()
        if memory_before and after then
            aux.print(string.format('Aux attributed memory: %.1f -> %.1f KiB', memory_before, after))
        end
    else
        aux.print('/aux profile start | stock | stop')
    end
end
