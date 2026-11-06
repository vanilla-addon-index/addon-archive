-- BetterHelp: Enhanced /help command that lists all available slash commands
-- Usage: /help [filter], /? [filter], /slashlist [filter], /sl [filter]

local function GetAllSlashCommands()
    local commands = {}
    
    -- Iterate through SlashCmdList to find all registered commands
    for name, func in pairs(SlashCmdList) do
        local triggers = {}
        
        -- Find all SLASH_NAME1, SLASH_NAME2, etc. for this command
        local i = 1
        while true do
            local slash = getglobal("SLASH_" .. name .. i)
            if not slash then break end
            table.insert(triggers, slash)
            i = i + 1
        end
        
        if getn(triggers) > 0 then
            table.insert(commands, {
                name = name,
                triggers = triggers,
            })
        end
    end
    
    -- Sort alphabetically by first trigger
    table.sort(commands, function(a, b)
        return strlower(a.triggers[1]) < strlower(b.triggers[1])
    end)
    
    return commands
end

local function PrintSlashCommands(filter)
    local commands = GetAllSlashCommands()
    local count = 0
    local filterLower = filter and strlower(filter) or nil
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00=== Slash Commands ===|r")
    
    for _, cmd in ipairs(commands) do
        local triggerStr = table.concat(cmd.triggers, ", ")
        local show = true
        
        -- Apply filter if provided
        if filterLower then
            show = false
            for _, trigger in ipairs(cmd.triggers) do
                if strfind(strlower(trigger), filterLower) then
                    show = true
                    break
                end
            end
            if not show and strfind(strlower(cmd.name), filterLower) then
                show = true
            end
        end
        
        if show then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00" .. triggerStr .. "|r |cff888888(" .. cmd.name .. ")|r")
            count = count + 1
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00=== " .. count .. " commands" .. (filter and (" matching '" .. filter .. "'") or "") .. " ===|r")
end

-- Save the original /help handler before we override it
local OriginalHelpHandler = SlashCmdList["HELP"]

-- Register slash commands
SLASH_BETTERHELP1 = "/slashlist"
SLASH_BETTERHELP2 = "/sl"
SlashCmdList["BETTERHELP"] = function(msg)
    local filter = msg ~= "" and msg or nil
    PrintSlashCommands(filter)
end

-- Override /help to show slash commands AND original help
SLASH_HELP1 = "/help"
SLASH_HELP2 = "/?"
SlashCmdList["HELP"] = function(msg)
    local filter = msg ~= "" and msg or nil
    PrintSlashCommands(filter)
    -- Append original /help output
    if OriginalHelpHandler then
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00=== Original /help ===|r")
        OriginalHelpHandler(msg)
    end
end

-- Startup message
DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BetterHelp|r loaded. Use |cffffff00/help|r or |cffffff00/sl [filter]|r to list all slash commands.")
