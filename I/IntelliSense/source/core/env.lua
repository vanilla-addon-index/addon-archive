---@type function
-- debugprint = debugprint
debugprint = function() end
debugprint('boot')

-- addon name
local NAME = 'IntelliSense'

-- locals
local SLASH = {}
local _G = getfenv()

-- SHELL interface
local SHELL = setmetatable({}, {
    __index = function(t, k)
        local stack = debugstack(2)
        if not string.find(stack, NAME) then
            error('SHELL:' .. k .. ' - Access denied: Not a ' .. NAME .. ' file')
            return
        end
        return rawget(t, k)
    end
})

-- environment setup and addoninfo
local ENV = setmetatable({}, {__index = getfenv()})
ENV.info = {
    TOCversion = GetAddOnMetadata(NAME, 'Version'),
    DBversion = GetAddOnMetadata(NAME, 'X-DBVersion'),
    author = GetAddOnMetadata(NAME, 'Author'),
    name = NAME,
}

-- SHELL methods
function SHELL:LOCKED()
    local _, _, filename = string.find(debugstack(2), '\\([^\\]+%.lua)')
    local oldEnv = getfenv(2)
    ENV._G = _G
    setfenv(2, ENV)
    debugprint('SHELL:LOCKED - FILE: ' .. (filename or 'unknown') .. ' - ENV: ' .. tostring(oldEnv) .. ' -> ' .. tostring(ENV))
end

function SHELL:SLASH(cmd, func)
    SLASH[cmd or ''] = func
    debugprint('SHELL:SLASH - Registering command: ' .. cmd .. ' -> ' .. tostring(func))
end

-- ENV utility (direct access as 'func()' inside SHELL)
function ENV.copy(t, seen)
    debugprint('ENV.copy - Copying table: ' .. tostring(t))
    seen = seen or {}
    if seen[t] then
        debugprint('ENV.copy - Already copied table: ' .. tostring(t) .. ' -> ' .. tostring(seen[t]))
        return seen[t]
    end
    local copy = {}
    seen[t] = copy
    for k, v in pairs(t) do
        debugprint('ENV.copy - Copying key: ' .. tostring(k) .. ' -> ' .. tostring(v))
        copy[k] = type(v) == 'table' and ENV.copy(v, seen) or v
    end
    debugprint('ENV.copy - Finished copying table: ' .. tostring(t) .. ' -> ' .. tostring(copy))
    return copy
end

function ENV.print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFEEEEEEIntelli|cFF00AAFFSense|r: " .. tostring(msg))
end

-- slash register
SLASH_INT1 = '/int'
SlashCmdList['INT'] = function(msg)
    if SLASH[msg] then
        SLASH[msg]()
    elseif SLASH[''] then
        debugprint'SHELL:SLASH - No command found'
    end
end

-- expose
_G.SHELL = SHELL