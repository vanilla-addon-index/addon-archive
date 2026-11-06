-- Freewood-OctoWoW-Core: Chatverlauf (Kanaele, Gilde, Gruppe, Fluestern) bis 7 Tage, Klasse/Level-Merker, /who-Abfrage.
-- ALLES UNGEPRUEFT im Spiel. Alle Spielaufrufe sind geschuetzt.

local ADDON, FW = ...

local G = _G
local CL = {}
FW.ChatLog = CL

CL.version = 0
CL.unread = {}
CL.guild = {}          -- online Gildenmitglieder { {name,level,class,zone} }
CL.viewKey = nil       -- vom Reiter gesetzt: aktuell angezeigter Chat
CL.viewVisible = false

local KEEP = 7 * 86400
local CAP_CH, CAP_OTHER = 300, 1000
local PLAYER_KEEP = 30 * 86400
local PLAYER_MAX = 3000

local function Now() return (G.time and G.time()) or 0 end

local function DB()
    local d = FW.chardb
    if type(d) ~= "table" then return nil end
    if type(d.chat) ~= "table" then d.chat = {} end
    local c = d.chat
    if type(c.lines) ~= "table" then c.lines = {} end
    if type(c.open) ~= "table" then c.open = {} end
    return c
end

local function PDB()
    local d = G.FreewoodDB
    if type(d) ~= "table" then return nil end
    if type(d.chatPlayers) ~= "table" then d.chatPlayers = {} end
    return d.chatPlayers
end

------------------------------------------------------------------------
-- Klassen
------------------------------------------------------------------------

local TOKENS = {
    warrior = "WARRIOR", krieger = "WARRIOR", kriegerin = "WARRIOR",
    mage = "MAGE", magier = "MAGE", magierin = "MAGE",
    rogue = "ROGUE", schurke = "ROGUE", schurkin = "ROGUE",
    druid = "DRUID", druide = "DRUID", druidin = "DRUID",
    hunter = "HUNTER", ["jäger"] = "HUNTER", ["jägerin"] = "HUNTER", jaeger = "HUNTER",
    shaman = "SHAMAN", schamane = "SHAMAN", schamanin = "SHAMAN",
    priest = "PRIEST", priester = "PRIEST", priesterin = "PRIEST",
    warlock = "WARLOCK", hexenmeister = "WARLOCK", hexenmeisterin = "WARLOCK",
    paladin = "PALADIN",
}

function CL.ClassToken(c)
    if type(c) ~= "string" or c == "" then return nil end
    return TOKENS[string.lower(c)]
end

CL.ICON_COORDS = {
    WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.5, 0, 0.25 },
    ROGUE = { 0.5, 0.75, 0, 0.25 }, DRUID = { 0.75, 1, 0, 0.25 },
    HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.5, 0.25, 0.5 },
    PRIEST = { 0.5, 0.75, 0.25, 0.5 }, WARLOCK = { 0.75, 1, 0.25, 0.5 },
    PALADIN = { 0, 0.25, 0.5, 0.75 },
}
CL.ICON_FILE = "Interface\\WorldStateFrame\\Icons-Classes"

local FALLBACK_COLORS = {
    WARRIOR = { 0.78, 0.61, 0.43 }, MAGE = { 0.41, 0.8, 0.94 }, ROGUE = { 1, 0.96, 0.41 },
    DRUID = { 1, 0.49, 0.04 }, HUNTER = { 0.67, 0.83, 0.45 }, SHAMAN = { 0, 0.44, 0.87 },
    PRIEST = { 1, 1, 1 }, WARLOCK = { 0.58, 0.51, 0.79 }, PALADIN = { 0.96, 0.55, 0.73 },
}

function CL.ClassColor(token)
    local c = token and G.RAID_CLASS_COLORS and G.RAID_CLASS_COLORS[token]
    if c and c.r then return c.r, c.g, c.b end
    local f = token and FALLBACK_COLORS[token]
    if f then return f[1], f[2], f[3] end
    return 0.9, 0.89, 0.84
end

------------------------------------------------------------------------
-- Spielerdaten (Klasse, Level) merken
------------------------------------------------------------------------

function CL.Note(name, class, level, extra)
    if type(name) ~= "string" or name == "" then return end
    local tok = CL.ClassToken(class) or (type(class) == "string" and FALLBACK_COLORS[class] and class) or nil
    local lv = tonumber(level)
    if not tok and not lv then return end
    local db = PDB()
    if not db then return end
    local r = db[name]
    if not r then r = {}; db[name] = r end
    local changed = false
    if tok and r.c ~= tok then r.c = tok; changed = true end
    if lv and lv > 0 and r.l ~= lv then r.l = lv; changed = true end
    if type(extra) == "table" then
        if extra.race and extra.race ~= "" and r.r ~= extra.race then r.r = extra.race; changed = true end
        if extra.guild and r.g ~= extra.guild then r.g = extra.guild; changed = true end
        if extra.cn and extra.cn ~= "" and r.cn ~= extra.cn then r.cn = extra.cn; changed = true end
    end
    r.t = Now()
    if changed then CL.version = CL.version + 1 end
end

-- ganzer Merker-Eintrag (c, l, r, g, cn) oder nil
function CL.Detail(name)
    local db = PDB()
    return db and db[name] or nil
end

function CL.Info(name)
    local db = PDB()
    local r = db and db[name]
    if r then return r.c, r.l end
    return nil, nil
end

local function NoteUnit(unit)
    if not (G.UnitExists and G.UnitExists(unit) and G.UnitIsPlayer and G.UnitIsPlayer(unit)) then return end
    local name = G.UnitName(unit)
    local cn, tok = G.UnitClass(unit)
    local guild = G.GetGuildInfo and G.GetGuildInfo(unit) or nil
    local race = G.UnitRace and G.UnitRace(unit) or nil
    CL.Note(name, tok, G.UnitLevel(unit), { race = race, guild = guild, cn = cn })
end

function CL.ScanGroup()
    local out = {}
    local function Add(unit)
        if G.UnitExists and G.UnitExists(unit) then
            local name = G.UnitName(unit)
            local _, tok = G.UnitClass(unit)
            local lv = G.UnitLevel(unit)
            CL.Note(name, tok, lv)
            out[table.getn(out) + 1] = { name = name, class = tok, level = lv }
        end
    end
    local raid = (G.GetNumRaidMembers and G.GetNumRaidMembers()) or 0
    if raid > 0 then
        local i = 1
        while i <= raid do Add("raid" .. i); i = i + 1 end
    else
        Add("player")
        local i = 1
        while i <= 4 do Add("party" .. i); i = i + 1 end
    end
    return out
end

------------------------------------------------------------------------
-- Gilde
------------------------------------------------------------------------

local lastGuildReq = 0
function CL.RequestGuild()
    local now = (G.GetTime and G.GetTime()) or 0
    if now - lastGuildReq < 20 then return end
    lastGuildReq = now
    if G.IsInGuild and G.IsInGuild() and G.GuildRoster then pcall(G.GuildRoster) end
end

function CL.RefreshGuild()
    local out = {}
    if G.IsInGuild and G.IsInGuild() and G.GetNumGuildMembers then
        local n = G.GetNumGuildMembers() or 0
        local i = 1
        while i <= n do
            local name, rank, ri, level, class, zone, note, onote, online = G.GetGuildRosterInfo(i)
            if name then
                CL.Note(name, class, level)
                if online then out[table.getn(out) + 1] = { name = name, level = level, class = CL.ClassToken(class), zone = zone } end
            end
            i = i + 1
        end
        table.sort(out, function(a, b) return a.name < b.name end)
    end
    CL.guild = out
    CL.version = CL.version + 1
end

------------------------------------------------------------------------
-- /who im Hintergrund (nur wenn Klasse/Level unbekannt)
------------------------------------------------------------------------

local whoQueue, whoTried, whoCur = {}, {}, nil
local whoSent, whoLast = 0, 0
local WHO_GAP, WHO_TIMEOUT, WHO_RETRY = 6, 5, 600

local forced = {}
local memberTag = {}
function CL.Ask(name, force, member)
    if type(name) ~= "string" or name == "" then return end
    if force then forced[name] = true end
    local c, l = CL.Info(name)
    if c and l and not force then return end
    local now = Now()
    if whoTried[name] and now - whoTried[name] < WHO_RETRY and not force then return end
    local k = 1
    while k <= table.getn(whoQueue) do
        if whoQueue[k] == name then return end
        k = k + 1
    end
    if table.getn(whoQueue) >= 80 then return end
    if member then memberTag[name] = true end
    whoQueue[table.getn(whoQueue) + 1] = name
end

-- beim Schliessen des Reiters: noch offene Mitglieder-Abfragen verwerfen
function CL.ClearMemberQueue()
    local new, k = {}, 1
    while k <= table.getn(whoQueue) do
        if not memberTag[whoQueue[k]] then new[table.getn(new) + 1] = whoQueue[k] end
        k = k + 1
    end
    whoQueue = new
    memberTag = {}
end

local function WhoDone()
    whoCur = nil
    local ff = G.FriendsFrame
    if ff and ff.RegisterEvent then pcall(ff.RegisterEvent, ff, "WHO_LIST_UPDATE") end
    if G.SetWhoToUI then pcall(G.SetWhoToUI, 0) end
end

local function WhoSend(name)
    whoCur = name
    whoTried[name] = Now()
    whoSent = (G.GetTime and G.GetTime()) or 0
    whoLast = whoSent
    local ff = G.FriendsFrame
    if ff and ff.UnregisterEvent then pcall(ff.UnregisterEvent, ff, "WHO_LIST_UPDATE") end
    if G.SetWhoToUI then pcall(G.SetWhoToUI, 1) end
    if G.SendWho then pcall(G.SendWho, "n-" .. name) end
end

local pump = CreateFrame("Frame")
pump:SetScript("OnUpdate", function()
    local now = (G.GetTime and G.GetTime()) or 0
    if whoCur and now - whoSent > WHO_TIMEOUT then
        if forced[whoCur] then forced[whoCur] = nil; FW:Print(whoCur .. ": ?") end
        WhoDone()
    end
    if not whoCur and table.getn(whoQueue) > 0 and now - whoLast >= WHO_GAP then
        local name = whoQueue[1]
        local n = table.getn(whoQueue)
        local k = 1
        while k < n do whoQueue[k] = whoQueue[k + 1]; k = k + 1 end
        whoQueue[n] = nil
        WhoSend(name)
    end
end)

local function OnWho()
    local n = (G.GetNumWhoResults and G.GetNumWhoResults()) or 0
    local i = 1
    while i <= n do
        local name, guild, level, race, class = G.GetWhoInfo(i)
        if name then
            CL.Note(name, class, level, { race = race, guild = guild or "", cn = class })
            if forced[name] then
                forced[name] = nil
                FW:Print(name .. ": " .. tostring(level) .. " " .. tostring(class) .. (guild and guild ~= "" and (" <" .. guild .. ">") or ""))
            end
        end
        i = i + 1
    end
    if whoCur then WhoDone() end
end

------------------------------------------------------------------------
-- Verlauf
------------------------------------------------------------------------

-- Service-Kanaele (LFT) werden NICHT gespeichert: nur im Arbeitsspeicher, kurze Liste
CL.mem = {}
local MEM_CAP = 150
local function Volatile(key)
    return type(key) == "string" and string.lower(key) == "c:lft"
end

function CL.Lines(key)
    if Volatile(key) then return CL.mem[key] end
    local c = DB()
    return c and c.lines[key] or nil
end

function CL.Add(key, sender, text, out)
    local c = DB()
    if not c or not key then return end
    local vol = Volatile(key)
    local store = vol and CL.mem or c.lines
    local list = store[key]
    if not list then list = {}; store[key] = list end
    local n = table.getn(list) + 1
    list[n] = { t = Now(), s = sender, m = text, o = out and 1 or nil }
    local cap = vol and MEM_CAP or ((string.sub(key, 1, 2) == "c:") and CAP_CH or CAP_OTHER)
    if n > cap + (vol and 20 or 50) then
        local new, i, j = {}, n - cap + 1, 1
        while i <= n do new[j] = list[i]; i = i + 1; j = j + 1 end
        store[key] = new
    end
    if not (CL.viewVisible and CL.viewKey == key) then
        CL.unread[key] = (CL.unread[key] or 0) + 1
    end
    if sender and not out and not vol then CL.Ask(sender) end
    CL.version = CL.version + 1
end

function CL.Prune()
    local c = DB()
    if c then
        local limit = Now() - KEEP
        for key in pairs(c.lines) do
            if Volatile(key) then c.lines[key] = nil end
        end
        for key, list in pairs(c.lines) do
            local n = table.getn(list)
            local first = 1
            while first <= n and (list[first].t or 0) < limit do first = first + 1 end
            if first > 1 then
                local new, j, i = {}, 1, first
                while i <= n do new[j] = list[i]; i = i + 1; j = j + 1 end
                if table.getn(new) == 0 then c.lines[key] = nil else c.lines[key] = new end
            end
        end
        for name, t in pairs(c.open) do
            if type(t) ~= "number" or t < limit then c.open[name] = nil end
        end
    end
    local p = PDB()
    if p then
        local lim = Now() - PLAYER_KEEP
        local cnt = 0
        for name, r in pairs(p) do
            if (r.t or 0) < lim then p[name] = nil else cnt = cnt + 1 end
        end
        if cnt > PLAYER_MAX then
            for name in pairs(p) do p[name] = nil; cnt = cnt - 1; if cnt <= PLAYER_MAX then break end end
        end
    end
end

-- geoeffnete Fluesterchats (Name -> letzte Zeit)
function CL.OpenWhispers()
    local c = DB()
    local out = {}
    if c then
        for name, t in pairs(c.open) do out[table.getn(out) + 1] = { name = name, t = t } end
        table.sort(out, function(a, b) return a.t > b.t end)
    end
    return out
end

function CL.OpenWhisper(name)
    local c = DB()
    if c and name then c.open[name] = Now(); CL.version = CL.version + 1 end
end

function CL.CloseWhisper(name)
    local c = DB()
    if c and name then c.open[name] = nil; CL.version = CL.version + 1 end
end

------------------------------------------------------------------------
-- Ereignisse (ohne Owner registrieren: sonst rutscht der Owner als erstes Argument rein)
------------------------------------------------------------------------

local function IsDataChannel(name)
    return type(name) == "string" and string.find(name, "^Freewood") ~= nil
end

function CL.ChannelKey(num, name)
    local Ch = FW.Channels
    local e = Ch and tonumber(num) and Ch.byNum[tonumber(num)]
    local nm = (e and e.name) or name
    if type(nm) ~= "string" or nm == "" then return nil, nil end
    return "c:" .. nm, nm
end

FW:RegisterEvent("CHAT_MSG_CHANNEL", function(text, sender, lang, chanStr, target, flags, zone, num, cname)
    local key, nm = CL.ChannelKey(num, cname)
    if not key or IsDataChannel(nm) or IsDataChannel(cname) then return end
    CL.Add(key, sender, text, sender == G.UnitName("player"))
end)

local function GuildMsg(text, sender)
    CL.Add("guild", sender, text, sender == G.UnitName("player"))
end
FW:RegisterEvent("CHAT_MSG_GUILD", GuildMsg)
FW:RegisterEvent("CHAT_MSG_OFFICER", GuildMsg)

local function GroupMsg(text, sender)
    CL.Add("group", sender, text, sender == G.UnitName("player"))
end
FW:RegisterEvent("CHAT_MSG_PARTY", GroupMsg)
FW:RegisterEvent("CHAT_MSG_RAID", GroupMsg)
FW:RegisterEvent("CHAT_MSG_RAID_LEADER", GroupMsg)
FW:RegisterEvent("CHAT_MSG_RAID_WARNING", GroupMsg)

FW:RegisterEvent("CHAT_MSG_WHISPER", function(text, sender)
    if not sender then return end
    CL.OpenWhisper(sender)
    CL.Add("w:" .. sender, sender, text, false)
end)
FW:RegisterEvent("CHAT_MSG_WHISPER_INFORM", function(text, target)
    if not target then return end
    CL.OpenWhisper(target)
    CL.Add("w:" .. target, G.UnitName("player"), text, true)
end)

FW:RegisterEvent("GUILD_ROSTER_UPDATE", function() CL.RefreshGuild() end)
FW:RegisterEvent("WHO_LIST_UPDATE", OnWho)
FW:RegisterEvent("PLAYER_TARGET_CHANGED", function() NoteUnit("target") end)
FW:RegisterEvent("UPDATE_MOUSEOVER_UNIT", function() NoteUnit("mouseover") end)
FW:RegisterEvent("PARTY_MEMBERS_CHANGED", function() CL.ScanGroup() end)
FW:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    CL.Prune()
    CL.RequestGuild()
end)

------------------------------------------------------------------------
-- Senden
------------------------------------------------------------------------

-- kind: "channel" (target = Kanalnummer), "guild", "group", "whisper" (target = Name)
function CL.Send(kind, target, text)
    if type(text) ~= "string" or text == "" or not G.SendChatMessage then return end
    if kind == "channel" then
        pcall(G.SendChatMessage, text, "CHANNEL", nil, target)
    elseif kind == "guild" then
        pcall(G.SendChatMessage, text, "GUILD")
    elseif kind == "group" then
        local raid = (G.GetNumRaidMembers and G.GetNumRaidMembers()) or 0
        pcall(G.SendChatMessage, text, raid > 0 and "RAID" or "PARTY")
    elseif kind == "whisper" then
        pcall(G.SendChatMessage, text, "WHISPER", nil, target)
    end
end

-- Klartext (Links/Farbcodes entfernen) fuers Kopieren
function CL.Plain(text)
    local t = tostring(text or "")
    t = string.gsub(t, "|H.-|h(.-)|h", "%1")
    t = string.gsub(t, "|c%x%x%x%x%x%x%x%x", "")
    t = string.gsub(t, "|r", "")
    return t
end

function CL.FirstUrl(text)
    local t = CL.Plain(text)
    local _, _, u = string.find(t, "(https?://%S+)")
    if not u then _, _, u = string.find(t, "(www%.%S+)") end
    return u
end
