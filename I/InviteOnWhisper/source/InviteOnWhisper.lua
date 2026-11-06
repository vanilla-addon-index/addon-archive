IOWConfig = IOWConfig or {}
IOWConfig.guildKeyword = IOWConfig.guildKeyword or ""
IOWConfig.partyKeyword = IOWConfig.partyKeyword or ""
IOWConfig.whisperGuildKeyword = IOWConfig.whisperGuildKeyword or ""
IOWConfig.whisperPartyKeyword = IOWConfig.whisperPartyKeyword or ""
IOWConfig.blacklist = IOWConfig.blacklist or {}

IOWInviteLock = IOWInviteLock or {}

local ADDON_NAME = "InviteOnWhisper"
local NAME_AND_VERSION = ADDON_NAME .. " v1.0"

local IOW = CreateFrame("Frame")

local function trim(s)
    if not s then return "" end
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return s
end

local function lowerName(name)
    name = trim(name or "")
    if name == "" then return "" end
    return string.lower(name)
end

local function countTable(t)
    local c = 0
    if not t then return 0 end
    for _ in pairs(t) do
        c = c + 1
    end
    return c
end

local function ensureConfig()
    if not IOWConfig then IOWConfig = {} end
    if IOWConfig.guildKeyword == nil then IOWConfig.guildKeyword = "" end
    if IOWConfig.partyKeyword == nil then IOWConfig.partyKeyword = "" end
    if IOWConfig.whisperGuildKeyword == nil then IOWConfig.whisperGuildKeyword = "" end
    if IOWConfig.whisperPartyKeyword == nil then IOWConfig.whisperPartyKeyword = "" end
    if IOWConfig.blacklist == nil then IOWConfig.blacklist = {} end
    if not IOWInviteLock then IOWInviteLock = {} end
end

local function isBlacklisted(name)
    local n = lowerName(name)
    if n == "" then return false end
    return IOWConfig.blacklist[n] == true
end

local function canProcessFrom(senderName, lockSeconds)
    local sender = lowerName(senderName)
    if sender == "" then return false end
    if isBlacklisted(sender) then return false end

    if not IOWInviteLock then IOWInviteLock = {} end

    local now = GetTime()
    local last = IOWInviteLock[sender]
    if last and (now - last) < (lockSeconds or 10) then
        return false
    end

    IOWInviteLock[sender] = now
    return true
end

local function inviteGuildTarget(name)
    if GuildInvite then
        GuildInvite(name)
    elseif GuildInviteByName then
        GuildInviteByName(name)
    else
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": no guild invite API found.")
    end
end

local function processInviteRequest(msgRaw, senderRaw)
    ensureConfig()
    if not msgRaw or not senderRaw then return end

    local sender = lowerName(senderRaw)
    if sender == "" then return end
    if isBlacklisted(sender) then return end

    local msg = lowerName(msgRaw)
    if msg == "" then return end

    local whisperGuildKey = lowerName(IOWConfig.whisperGuildKeyword)
    local whisperPartyKey = lowerName(IOWConfig.whisperPartyKeyword)
    local guildKey = lowerName(IOWConfig.guildKeyword)
    local partyKey = lowerName(IOWConfig.partyKeyword)

    if whisperGuildKey ~= "" and msg == whisperGuildKey then
        if not canProcessFrom(sender, 10) then return end
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": guild invite request from " .. sender)
        inviteGuildTarget(sender)
        return
    end

    if whisperPartyKey ~= "" and msg == whisperPartyKey then
        if not canProcessFrom(sender, 10) then return end
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": inviting " .. sender)
        InviteByName(sender)
        return
    end

    if guildKey ~= "" and (msg == guildKey or string.find(msg, guildKey, 1, true)) then
        if not canProcessFrom(sender, 10) then return end
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": guild invite request from " .. sender)
        inviteGuildTarget(sender)
        return
    end

    if partyKey ~= "" and (msg == partyKey or string.find(msg, partyKey, 1, true)) then
        if not canProcessFrom(sender, 10) then return end
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": inviting " .. sender)
        InviteByName(sender)
        return
    end
end

local function showValue(v)
    if v and v ~= "" then
        return v
    end
    return "<text>"
end

local function printInfo()
    ensureConfig()
    DEFAULT_CHAT_FRAME:AddMessage(NAME_AND_VERSION)
    DEFAULT_CHAT_FRAME:AddMessage("Set keywords first with /iow commands.")
    DEFAULT_CHAT_FRAME:AddMessage("/iow whisperguild " .. showValue(IOWConfig.whisperGuildKeyword))
    DEFAULT_CHAT_FRAME:AddMessage("/iow whisperparty " .. showValue(IOWConfig.whisperPartyKeyword))
    DEFAULT_CHAT_FRAME:AddMessage("/iow guildkeyword " .. showValue(IOWConfig.guildKeyword))
    DEFAULT_CHAT_FRAME:AddMessage("/iow partykeyword " .. showValue(IOWConfig.partyKeyword))
    DEFAULT_CHAT_FRAME:AddMessage("/iow blacklist <name>")
    DEFAULT_CHAT_FRAME:AddMessage("/iow unblacklist <name>")
    DEFAULT_CHAT_FRAME:AddMessage("/iow bl")
end

IOW:RegisterEvent("VARIABLES_LOADED")
IOW:RegisterEvent("CHAT_MSG_WHISPER")
IOW:RegisterEvent("CHAT_MSG_CHANNEL")

IOW:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        ensureConfig()
        DEFAULT_CHAT_FRAME:AddMessage("Loaded " .. NAME_AND_VERSION .. "; type '/iow info' for setup.")
        return
    end

    if event == "CHAT_MSG_WHISPER" then
        processInviteRequest(arg1, arg2)
        return
    end

    if event == "CHAT_MSG_CHANNEL" then
        processInviteRequest(arg1, arg2)
        return
    end
end)

SLASH_IOW1 = "/iow"
SlashCmdList["IOW"] = function(msg)
    ensureConfig()

    msg = trim(msg or "")
    local sep = string.find(msg, " ", 1, true)
    local cmd = ""
    local rest = ""

    if sep then
        cmd = string.lower(trim(string.sub(msg, 1, sep - 1)))
        rest = trim(string.sub(msg, sep + 1))
    else
        cmd = string.lower(msg)
        rest = ""
    end

    if cmd == "" or cmd == "info" then
        printInfo()
        return
    end

    if cmd == "whisperguild" then
        IOWConfig.whisperGuildKeyword = rest
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": whisper guild keyword set to '" .. rest .. "'")
        return
    end

    if cmd == "whisperparty" then
        IOWConfig.whisperPartyKeyword = rest
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": whisper party keyword set to '" .. rest .. "'")
        return
    end

    if cmd == "guildkeyword" then
        IOWConfig.guildKeyword = rest
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": guild keyword set to '" .. rest .. "'")
        return
    end

    if cmd == "partykeyword" then
        IOWConfig.partyKeyword = rest
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": party keyword set to '" .. rest .. "'")
        return
    end

    if cmd == "blacklist" then
        if rest ~= "" then
            local n = lowerName(rest)
            if n ~= "" then
                IOWConfig.blacklist[n] = true
            end
            DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": blacklisted '" .. rest .. "'")
        else
            DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": usage /iow blacklist <name>")
        end
        return
    end

    if cmd == "unblacklist" then
        if rest ~= "" then
            local n = lowerName(rest)
            if n ~= "" then
                IOWConfig.blacklist[n] = nil
            end
            DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": removed '" .. rest .. "' from blacklist")
        else
            DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": usage /iow unblacklist <name>")
        end
        return
    end

    if cmd == "bl" then
        local names = {}
        for n in pairs(IOWConfig.blacklist) do
            names[countTable(names) + 1] = n
        end
        if countTable(names) == 0 then
            DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": blacklist is empty.")
        else
            table.sort(names)
            DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": blacklist: " .. table.concat(names, ", "))
        end
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": unknown command. Type '/iow info'.")
end
