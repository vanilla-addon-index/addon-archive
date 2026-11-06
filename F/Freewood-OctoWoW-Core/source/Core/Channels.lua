-- Freewood-OctoWoW-Core: Kanaele und ihre Mitglieder (nur lesen, alles UNGEPRUEFT im Spiel)
-- Datenquelle: GetChannelList() + ListChannelByName(n) -> Ereignis CHAT_MSG_CHANNEL_LIST (arg1 = Namensliste).
-- Alle Aufrufe laufen geschuetzt (pcall). /fwchans zeigt Rohdaten zur Pruefung.

local ADDON, FW = ...

local G = _G
local Ch = {}
FW.Channels = Ch

Ch.list = {}        -- { {num=, name=, members={...}, count=, stamp=} }
Ch.byNum = {}
Ch.queue = {}
Ch.current = nil
Ch.lastSend = 0
Ch.probe = false
Ch.version = 0      -- steigt bei jeder Aenderung, die UI prueft das

local SPACING = 0.8       -- Sekunden zwischen zwei Abfragen
local TIMEOUT = 4         -- Sekunden bis eine Abfrage als verloren gilt
local SUPPRESS = 5        -- so lange nach einer Abfrage wird die Chatausgabe der Liste unterdrueckt

local function P(t)
    if G.DEFAULT_CHAT_FRAME then
        G.DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffFWChans|r " .. tostring(t))
    end
end

local function Short(s, n)
    s = tostring(s)
    n = n or 160
    if string.len(s) > n then return string.sub(s, 1, n) .. "..." end
    return s
end

-- Kanalliste lesen: 1.12 liefert num, name, num, name ... (spaeter evtl. mit Zusatzwert)
function Ch.ReadList()
    local out = {}
    if type(G.GetChannelList) ~= "function" then return out end
    local res = { pcall(G.GetChannelList) }
    if not res[1] then return out end
    local i = 2
    local n = table.getn(res)
    local lastNum
    while i <= n do
        local v = res[i]
        if type(v) == "number" then
            lastNum = v
        elseif type(v) == "string" and lastNum then
            out[table.getn(out) + 1] = { num = lastNum, name = v }
            lastNum = nil
        end
        i = i + 1
    end
    return out
end

-- eigenes Entfernen (table.remove zusammen mit table.getn verhaelt sich auf dem Client eigenartig)
local function RemoveAt(t, idx)
    local n = table.getn(t)
    local k = idx
    while k < n do t[k] = t[k + 1]; k = k + 1 end
    t[n] = nil
end

local function Bump() Ch.version = Ch.version + 1 end

-- Liste neu einlesen, bekannte Mitglieder behalten
function Ch.Rescan()
    local fresh = Ch.ReadList()
    local old = Ch.byNum
    Ch.byNum = {}
    Ch.list = {}
    local k = 1
    while k <= table.getn(fresh) do
        local e = fresh[k]
        local prev = old[e.num]
        if prev and prev.name == e.name then
            e.members = prev.members
            e.listed = prev.listed
            e.spk = prev.spk
            e.extra = prev.extra
            e.count = prev.count
            e.stamp = prev.stamp
        else
            e.members = {}
            e.listed = {}
            e.spk = {}
            e.extra = {}
            e.count = 0
        end
        Ch.byNum[e.num] = e
        Ch.list[table.getn(Ch.list) + 1] = e
        k = k + 1
    end
    Bump()
end

-- Mitglieder aller Kanaele abfragen (nacheinander)
function Ch.RefreshAll()
    Ch.Rescan()
    Ch.queue = {}
    local k = 1
    while k <= table.getn(Ch.list) do
        Ch.queue[table.getn(Ch.queue) + 1] = Ch.list[k].num
        k = k + 1
    end
end

function Ch.RefreshOne(num)
    Ch.queue[table.getn(Ch.queue) + 1] = num
end

function Ch.Pending()
    return table.getn(Ch.queue) + (Ch.current and 1 or 0)
end

local function Send(num)
    Ch.current = num
    Ch.sentAt = (G.GetTime and G.GetTime()) or 0
    Ch.lastSend = Ch.sentAt
    local ok, err = pcall(G.ListChannelByName, num)
    if not ok and Ch.probe then P("ListChannelByName(" .. tostring(num) .. ") Fehler: " .. Short(err)) end
end

local pump = CreateFrame("Frame")
pump:SetScript("OnUpdate", function()
    local now = (G.GetTime and G.GetTime()) or 0
    if Ch.current and now - Ch.sentAt > TIMEOUT then
        Ch.current = nil
        Ch.timeouts = (Ch.timeouts or 0) + 1
    end
    if not Ch.current and table.getn(Ch.queue) > 0 and now - Ch.lastSend >= SPACING then
        local num = Ch.queue[1]
        RemoveAt(Ch.queue, 1)
        if Ch.byNum[num] then Send(num) end
        Bump()
    end
end)

-- Namensliste aus arg1 zerlegen: "Name1, Name2*, Name3" -> Liste (Markierungen entfernt)
function Ch.ParseNames(text)
    local out = {}
    if type(text) ~= "string" then return out end
    local rest = text
    -- evtl. Kopf "Players in channel ...:" abtrennen
    local pos = string.find(rest, ":", 1, true)
    if pos and pos < 60 and string.find(string.sub(rest, 1, pos), " ", 1, true) then
        rest = string.sub(rest, pos + 1)
    end
    local iter = string.gmatch or string.gfind
    for part in iter(rest, "[^,]+") do
        local name = string.gsub(part, "^%s+", "")
        name = string.gsub(name, "%s+$", "")
        name = string.gsub(name, "%*", "")
        name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
        name = string.gsub(name, "|r", "")
        if name ~= "" then out[table.getn(out) + 1] = name end
    end
    return out
end

-- Mitglieder = Liste vom Server + wer zuletzt geschrieben hat (Listen sind nur Momentaufnahmen)
local SPEAK_KEEP = 1800
function Ch.Merge(e)
    local now = (G.GetTime and G.GetTime()) or 0
    local out, seen, extra = {}, {}, {}
    local k = 1
    while k <= table.getn(e.listed) do
        out[table.getn(out) + 1] = e.listed[k]
        seen[e.listed[k]] = true
        k = k + 1
    end
    for name, t in pairs(e.spk) do
        if now - t > SPEAK_KEEP then
            e.spk[name] = nil
        elseif not seen[name] then
            out[table.getn(out) + 1] = name
            extra[name] = true
        end
    end
    e.members = out
    e.extra = extra
    e.count = table.getn(out)
    Bump()
end

function Ch.NoteSpeaker(num, name)
    local e = tonumber(num) and Ch.byNum[tonumber(num)]
    if not e or type(name) ~= "string" or name == "" then return end
    if e.spk[name] == nil then
        e.spk[name] = (G.GetTime and G.GetTime()) or 0
        Ch.Merge(e)
    else
        e.spk[name] = (G.GetTime and G.GetTime()) or 0
    end
end

local function OnList(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    if Ch.probe then
        P("CHAT_MSG_CHANNEL_LIST arg1=" .. Short(a1) .. " | arg2=" .. tostring(a2) .. " arg4=" .. tostring(a4) ..
          " arg7=" .. tostring(a7) .. " arg8=" .. tostring(a8) .. " arg9=" .. tostring(a9))
    end
    local num = tonumber(a8)
    local e = num and Ch.byNum[num]
    if not e and Ch.current then e = Ch.byNum[Ch.current] end
    if not e and a9 then
        local k = 1
        while k <= table.getn(Ch.list) do
            if Ch.list[k].name == a9 then e = Ch.list[k] end
            k = k + 1
        end
    end
    if not e then return end
    e.listed = Ch.ParseNames(a1)
    e.stamp = (G.GetTime and G.GetTime()) or 0
    if Ch.current == e.num then Ch.current = nil end
    Ch.Merge(e)
end

local function OnJoin(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    if Ch.probe then P("CHANNEL_JOIN arg2=" .. tostring(a2) .. " arg8=" .. tostring(a8) .. " arg9=" .. tostring(a9)) end
    local e = tonumber(a8) and Ch.byNum[tonumber(a8)]
    if e and type(a2) == "string" and a2 ~= "" then
        local k = 1
        while k <= table.getn(e.listed) do
            if e.listed[k] == a2 then return end
            k = k + 1
        end
        e.listed[table.getn(e.listed) + 1] = a2
        Ch.Merge(e)
    end
end

local function OnLeave(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    if Ch.probe then P("CHANNEL_LEAVE arg2=" .. tostring(a2) .. " arg8=" .. tostring(a8) .. " arg9=" .. tostring(a9)) end
    local e = tonumber(a8) and Ch.byNum[tonumber(a8)]
    if e and type(a2) == "string" then
        e.spk[a2] = nil
        local k = 1
        while k <= table.getn(e.listed) do
            if e.listed[k] == a2 then
                RemoveAt(e.listed, k)
                break
            end
            k = k + 1
        end
        Ch.Merge(e)
    end
end

local function OnNotice(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    if Ch.probe then P("CHANNEL_NOTICE arg1=" .. tostring(a1) .. " arg4=" .. tostring(a4) .. " arg8=" .. tostring(a8) .. " arg9=" .. tostring(a9)) end
    if a1 == "YOU_JOINED" or a1 == "YOU_LEFT" or a1 == "YOU_CHANGED" then
        Ch.dirty = true
    end
end

FW:RegisterEvent("CHAT_MSG_CHANNEL_LIST", OnList)
FW:RegisterEvent("CHAT_MSG_CHANNEL", function(text, sender, lang, chanStr, target, flags, zone, num)
    Ch.NoteSpeaker(num, sender)
end)
FW:RegisterEvent("CHAT_MSG_CHANNEL_JOIN", OnJoin)
FW:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE", OnLeave)
FW:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE", OnNotice)

-- Die Listenausgabe des Spiels soll nicht im Chat landen, solange wir selbst abfragen
if type(G.ChatFrame_AddMessageEventFilter) == "function" then
    local function Hide()
        if Ch.probe then return false end
        local now = (G.GetTime and G.GetTime()) or 0
        if Ch.current or (now - Ch.lastSend) < SUPPRESS then return true end
        return false
    end
    pcall(G.ChatFrame_AddMessageEventFilter, "CHAT_MSG_CHANNEL_LIST", Hide)
    Ch.filter = true
end

-- Zweiter Weg gegen die Chatausgabe: AddMessage der Chatfenster, solange das Listen-Ereignis laeuft
local function Suppressing()
    if Ch.probe then return false end
    local now = (G.GetTime and G.GetTime()) or 0
    return Ch.current ~= nil or (now - Ch.lastSend) < SUPPRESS
end
local ci = 1
while ci <= 10 do
    local cf = G["ChatFrame" .. ci]
    if cf and cf.AddMessage and not cf.fwChanWrapped then
        local orig = cf.AddMessage
        cf.fwChanWrapped = true
        cf.AddMessage = function(self, ...)
            if G.event == "CHAT_MSG_CHANNEL_LIST" and Suppressing() then return end
            return orig(self, ...)
        end
    end
    ci = ci + 1
end

-- Beitreten / Verlassen (JoinChannelByName legt den Kanal bei Bedarf an). Das Spiel erlaubt hoechstens 10 Kanaele.
Ch.MAX = 10
Ch.pendingCat = {}

function Ch.FreeSlots()
    local n = Ch.MAX - table.getn(Ch.list)
    if n < 0 then n = 0 end
    return n
end

function Ch.Join(name, pw, catId)
    if type(name) ~= "string" or name == "" then return false end
    if Ch.FreeSlots() <= 0 then return false, "full" end
    if type(G.JoinChannelByName) ~= "function" then return false end
    if pw == "" then pw = nil end
    pcall(G.JoinChannelByName, name, pw)
    if catId then Ch.pendingCat[string.lower(name)] = catId end
    Ch.rescanAt = ((G.GetTime and G.GetTime()) or 0) + 1.5
    return true
end

function Ch.Leave(name)
    if type(name) ~= "string" or name == "" then return end
    if string.find(name, "^Freewood") then return end
    if type(G.LeaveChannelByName) == "function" then pcall(G.LeaveChannelByName, name) end
    Ch.rescanAt = ((G.GetTime and G.GetTime()) or 0) + 1.0
end

local rescanPump = CreateFrame("Frame")
rescanPump:SetScript("OnUpdate", function()
    if Ch.rescanAt and G.GetTime and G.GetTime() >= Ch.rescanAt then
        Ch.rescanAt = nil
        Ch.RefreshAll()
    end
end)

-- Aktionen (geschuetzt)
function Ch.Whisper(name)
    if type(G.ChatFrame_SendTell) == "function" then pcall(G.ChatFrame_SendTell, name) end
end
function Ch.Invite(name)
    if type(G.InviteByName) == "function" then pcall(G.InviteByName, name)
    elseif type(G.InviteUnit) == "function" then pcall(G.InviteUnit, name) end
end
function Ch.Ignore(name)
    if type(G.AddIgnore) == "function" then pcall(G.AddIgnore, name) end
end

-- Suche ueber alle Kanaele: Liste { {name=, chans={Kanalnamen}} } (Teiltreffer, ohne Gross/Klein)
function Ch.Find(text, limit)
    local out = {}
    text = string.lower(text or "")
    if text == "" then return out end
    local byName = {}
    local k = 1
    while k <= table.getn(Ch.list) do
        local e = Ch.list[k]
        local m = 1
        while m <= table.getn(e.members) do
            local nm = e.members[m]
            if string.find(string.lower(nm), text, 1, true) then
                local r = byName[nm]
                if not r then
                    if limit and table.getn(out) >= limit then
                        Ch.moreFound = true
                    else
                        r = { name = nm, chans = {} }
                        byName[nm] = r
                        out[table.getn(out) + 1] = r
                    end
                end
                if r then r.chans[table.getn(r.chans) + 1] = e.num .. ". " .. e.name end
            end
            m = m + 1
        end
        k = k + 1
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- /fwchans [find <name>|probe|list]
G.SLASH_FWCHANS1 = "/fwchans"
G.SlashCmdList = G.SlashCmdList or {}
G.SlashCmdList["FWCHANS"] = function(msg)
    msg = msg or ""
    local cmd, rest = string.match and string.match(msg, "^(%S*)%s*(.*)$")
    if not cmd then
        local _, _, c, r = string.find(msg, "^(%S*)%s*(.*)$")
        cmd, rest = c or "", r or ""
    end
    cmd = string.lower(cmd or "")
    if cmd == "find" then
        local res = Ch.Find(rest, 20)
        if table.getn(res) == 0 then P("keine Treffer (Mitglieder bekannt: " .. Ch.TotalMembers() .. ")") end
        local k = 1
        while k <= table.getn(res) do
            P(res[k].name .. ": " .. table.concat(res[k].chans, ", "))
            k = k + 1
        end
        return
    end
    if cmd == "list" then
        Ch.Rescan()
        local k = 1
        while k <= table.getn(Ch.list) do
            local e = Ch.list[k]
            P(e.num .. ". " .. e.name .. " - " .. e.count .. " Mitglieder" .. (e.stamp and "" or " (noch nicht abgefragt)"))
            k = k + 1
        end
        return
    end
    -- Standard: Rohdaten zeigen und Abfrage mit Rohausgabe starten
    Ch.probe = true
    local raw = { pcall(G.GetChannelList) }
    local parts = {}
    local i = 2
    while i <= table.getn(raw) do parts[table.getn(parts) + 1] = type(raw[i]) .. ":" .. tostring(raw[i]); i = i + 1 end
    P("GetChannelList: " .. table.concat(parts, " | "))
    P("Filter=" .. tostring(Ch.filter) .. " ListChannelByName=" .. type(G.ListChannelByName))
    Ch.RefreshAll()
    P("Abfrage laeuft (" .. Ch.Pending() .. " Kanaele). Rohdaten erscheinen unten. '/fwchans list' zeigt danach die Zahlen, '/fwchans find <Name>' sucht.")
    Ch.probeUntil = (G.GetTime and G.GetTime() or 0) + 60
end

function Ch.TotalMembers()
    local n, k = 0, 1
    while k <= table.getn(Ch.list) do n = n + Ch.list[k].count; k = k + 1 end
    return n
end

-- Rohausgabe nach 60 s wieder abschalten
local off = CreateFrame("Frame")
off:SetScript("OnUpdate", function()
    if Ch.probe and Ch.probeUntil and G.GetTime and G.GetTime() > Ch.probeUntil then
        Ch.probe = false
        P("Rohausgabe aus.")
    end
end)
