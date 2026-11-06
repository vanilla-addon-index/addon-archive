-- Vanilla 1.12 guild membership and recently observed EGM peers.
EGM = EGM or {}
EGM.Roster = EGM.Roster or {}
local R = EGM.Roster
local members, online, seen, classes = {}, {}, {}, {}
local elapsed = 0
local function now() return GetTime() end
local function fire()
    if EGM.Fire then EGM.Fire("ROSTER") end
end
function R.refresh()
    if EGM.DB and EGM.DB.switch then EGM.DB.switch() end
    local m, o = {}, {}
    local count = GetNumGuildMembers(true) or 0
    local i
    for i = 1, count do
        local name, rank, rankIndex, level, class, zone, note, officer, connected = GetGuildRosterInfo(i)
        if name then
            m[name] = true
            if class then classes[name] = class end
            if connected and connected ~= 0 then o[name] = true end
        end
    end
    local changed = false
    local name
    for name in pairs(members) do if not m[name] or online[name] ~= o[name] then changed = true end end
    for name in pairs(m) do if not members[name] then changed = true end end
    members, online = m, o
    if changed then fire() end
end
-- class colors (1.12 has no RAID_CLASS_COLORS); keys are the English class names the guild roster returns
local CLASS_HEX = { Warrior = "c79c6e", Paladin = "f58cba", Hunter = "abd473", Rogue = "fff569", Priest = "ffffff",
    Shaman = "0070de", Mage = "69ccf0", Warlock = "9482c9", Druid = "ff7d0a" }
local CLASS_RGB = {}
for k, h in pairs(CLASS_HEX) do
    CLASS_RGB[k] = { tonumber(string.sub(h, 1, 2), 16) / 255, tonumber(string.sub(h, 3, 4), 16) / 255, tonumber(string.sub(h, 5, 6), 16) / 255 }
end
function R.class(name) return classes[name] end
-- "|cffRRGGBB" for the member's class, grey when unknown
function R.classHex(name) return "|cff" .. (CLASS_HEX[classes[name] or ""] or "b0b0b0") end
function R.classRGB(name) local c = CLASS_RGB[classes[name] or ""]; if c then return c[1], c[2], c[3] end; return 0.7, 0.7, 0.7 end
function R.isMember(name) return members[name] and true or false end
-- true once the roster has been read
function R.known() return next(members) ~= nil end
-- may this char take part in the guild market? (everybody while the roster is still unknown)
function R.counts(name) if not R.known() then return true end; return members[name] and true or false end
function R.isOnline(name) return online[name] and true or false end
function R.notePeer(name)
    if type(name) ~= "string" or name == "" then return end
    local fresh = not seen[name] or now() - seen[name] > 180
    seen[name] = now()
    if members[name] and not online[name] then online[name] = true; fresh = true end
    if fresh then fire() end
end
function R.peers()
    local result, name, at = {}, nil, nil
    for name, at in pairs(seen) do
        if now() - at <= 180 then table.insert(result, name) end
    end
    table.sort(result)
    return result
end
-- "X has come online." / "X has gone offline." (ERR_FRIEND_ONLINE_SS / ERR_FRIEND_OFFLINE_S, also sent for guild members):
-- set the status at once instead of waiting for the next roster poll (2026-11-05: online status only updated late)
local function toPattern(fmt)
    local p = string.gsub(fmt, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    p = string.gsub(p, "%%s", "(.-)")
    return "^" .. p .. "$"
end
local ONLINE_P = toPattern(ERR_FRIEND_ONLINE_SS or "|Hplayer:%s|h[%s]|h has come online.")
local OFFLINE_P = toPattern(ERR_FRIEND_OFFLINE_S or "%s has gone offline.")
function R.system(msg)
    if type(msg) ~= "string" then return end
    local _, _, a, b = string.find(msg, ONLINE_P)
    local name, state = b or a, true
    if not name then _, _, name = string.find(msg, OFFLINE_P); state = nil end
    if not name or not members[name] then return end
    if online[name] ~= state then online[name] = state; fire() end
    if GuildRoster then GuildRoster() end
end
function R.init()
    if GuildRoster and (not IsInGuild or IsInGuild()) then GuildRoster() end
    if EGM.DB and EGM.DB.switch then EGM.DB.switch() end
    R.refresh()
end
local frame = CreateFrame("Frame", "EGMFrameRoster")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:SetScript("OnEvent", function()
    if event == "GUILD_ROSTER_UPDATE" then R.refresh()
    elseif event == "CHAT_MSG_SYSTEM" then R.system(arg1)
    else R.init() end
end)
frame:SetScript("OnUpdate", function()
    elapsed = elapsed + (arg1 or 0)
    if elapsed < 20 then return end -- the server throttles GuildRoster() to about one answer per 10-15 s
    elapsed = 0
    R.init()
    local name, at, changed
    for name, at in pairs(seen) do
        if now() - at > 180 then seen[name] = nil; changed = true end
    end
    if changed then fire() end
end)
