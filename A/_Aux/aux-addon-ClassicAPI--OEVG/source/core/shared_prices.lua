module 'aux.core.shared_prices'

local aux = require 'aux'
local history = require 'aux.core.history'
local MAX_BYTES = 32 * 1024 * 1024
local HEADER = 'AuxPrices1\n'

local function available()
    return type(ReadCustomFile) == 'function' and type(WriteCustomFile) == 'function'
end

local function filename(market)
    -- Encode the entire key to avoid collisions between realm names or factions.
    local encoded = string.gsub(market, '.', function(c)
        return string.format('%02x', string.byte(c))
    end)
    return 'AuxPrices1_' .. encoded .. '.txt'
end

local function sync()
    if not available() then return nil, 'Nampower file support is unavailable.' end
    if not aux.price_market_key then return nil, 'Auction price history is not ready.' end
    local file = filename(aux.price_market_key)
    local ok, contents = pcall(ReadCustomFile, file)
    if not ok then return nil, 'Could not read the shared price file.' end

    local records = {}
    if contents then
        if string.len(contents) > MAX_BYTES or not string.find(contents, '^AuxPrices1\r?\n') then
            return nil, 'The shared price file has an invalid header or size.'
        end
        for key, record in string.gfind(contents, '\n(%d+:%-?%d+)\t([^\r\n]+)') do
            if history.is_shared_record(record) then records[key] = record end
        end
    end

    local imported, changed = 0, false
    local day = history.shared_day()
    local local_records = aux.faction_data.history
    for key, record in pairs(records) do
        local current = local_records[key]
        if current ~= record then
            local merged = history.merge_shared_record(current, record, day)
            if merged and merged ~= current then
                history.set_shared_record(key, merged)
                imported = imported + 1
            end
        end
    end

    for key, record in pairs(local_records) do
        if not records[key] or records[key] ~= record then
            if string.find(key, '^%d+:%-?%d+$') and history.is_shared_record(record) then
                records[key] = record
                changed = true
            end
        end
    end

    if changed then
        local lines = {HEADER}
        for key, record in pairs(records) do
            table.insert(lines, key .. '\t' .. record .. '\n')
        end
        local output = table.concat(lines)
        if string.len(output) > MAX_BYTES then return nil, 'The shared price file is too large to save.' end
        if not pcall(WriteCustomFile, file, output, 'w') then
            return nil, 'Could not save the shared price file.'
        end
    end
    return imported
end

local function auto_sync()
    if aux.account_data.share_local_prices and available() then
        local count, message = sync()
        if not count then aux.print('Shared prices: ' .. message) end
    end
end

function aux.handle.LOAD2()
    auto_sync()
end

function aux.handle.CLOSE()
    auto_sync()
end

function M.command(action)
    if action == 'off' then
        aux.account_data.share_local_prices = false
        aux.print('Local auction price sharing off.')
        return
    end
    if action == 'on' or action == 'sync' then
        local count, message = sync()
        if not count then
            aux.print('Shared prices: ' .. message)
            return
        end
        if action == 'on' then aux.account_data.share_local_prices = true end
        aux.print('Shared prices synced. Imported or updated ' .. count .. ' item records.')
    else
        aux.print('/aux prices on | off | sync')
    end
end
