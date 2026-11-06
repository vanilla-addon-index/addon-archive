-- Escaped, typed event wire format. All transport runs on the guild channel.
EGM = EGM or {}
EGM.Comm = EGM.Comm or {}
local C = EGM.Comm
local PREFIX, MAX_MESSAGE = "EGM", 252 -- prefix + body <= 255 bytes
local queue, head, tail = {}, 1, 0
local controls, controlHead, controlTail = {}, 1, 0
local assemblies, assemblyCount, peers = {}, 0, {}
local syncJobs, syncHead, syncTail, syncClock = {}, 1, 0, 0
local serial, credit, housekeeping = 0, 0, 0
local started, loginAt, electionAt, nextPing, warned
local function player()
    if EGM.Util and EGM.Util.player then return EGM.Util.player() end
    return UnitName("player")
end
local function stamp()
    if EGM.Util and EGM.Util.now then return EGM.Util.now() end
    return time()
end
local function escape(s)
    return (string.gsub(s, "([^%w%._%-])", function(c) return string.format("%%%02X", string.byte(c)) end))
end
local function unescape(s)
    local rest = string.gsub(s, "%%[%x][%x]", "")
    if string.find(rest, "%", 1, true) then return nil end
    return (string.gsub(s, "%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end
local function split(s)
    local result, start = {}, 1
    while true do
        local at = string.find(s, "~", start, true)
        if not at then table.insert(result, string.sub(s, start)); return result end
        table.insert(result, string.sub(s, start, at - 1))
        start = at + 1
    end
end
local function finite(n) return type(n) == "number" and n == n and n - n == 0 end
function C.serialize(ev)
    if type(ev) ~= "table" or type(ev.id) ~= "string" or ev.id == "" or
        type(ev.t) ~= "string" or type(ev.o) ~= "string" or not finite(ev.at) or type(ev.d) ~= "table" then return nil end
    local out = {escape(ev.id), escape(ev.t), escape(ev.o), string.format("%.17g", ev.at)}
    local keys, k, v = {}, nil, nil
    for k, v in pairs(ev.d) do
        if type(k) ~= "string" or (type(v) ~= "string" and not finite(v)) then return nil end
        table.insert(keys, k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        v = ev.d[k]
        table.insert(out, escape(k))
        table.insert(out, type(v) == "number" and "n" or "s")
        table.insert(out, escape(type(v) == "number" and string.format("%.17g", v) or v))
    end
    local wire = table.concat(out, "~")
    if string.len(wire) > 65536 then return nil end
    return wire
end
function C.deserialize(wire)
    if type(wire) ~= "string" or string.len(wire) > 65536 then return nil end
    local p = split(wire)
    local n = table.getn(p)
    if n < 4 or math.mod(n - 4, 3) ~= 0 then return nil end
    local ev = {id = unescape(p[1]), t = unescape(p[2]), o = unescape(p[3]), at = tonumber(p[4]), d = {}}
    if not ev.id or ev.id == "" or not ev.t or ev.t == "" or not ev.o or ev.o == "" or not finite(ev.at) then return nil end
    local i
    for i = 5, n, 3 do
        local k, v = unescape(p[i]), unescape(p[i + 2])
        if not k or not v or ev.d[k] ~= nil then return nil end
        if p[i + 1] == "n" then v = tonumber(v); if not finite(v) then return nil end
        elseif p[i + 1] ~= "s" then return nil end
        ev.d[k] = v
    end
    return ev
end
local function enqueue(messages)
    local n = table.getn(messages)
    if tail - head + 1 + n > 4096 then return nil end
    for _, message in ipairs(messages) do tail = tail + 1; queue[tail] = message end
    return true
end
function C.chunk(payload, id)
    if type(payload) ~= "string" or string.len(payload) > 65539 then return nil end
    serial = serial + 1
    id = id or (tostring(stamp()) .. "-" .. tostring(serial))
    if type(id) ~= "string" or string.len(id) > 40 or not string.find(id, "^[%w%-_]+$") then return nil end
    local size = MAX_MESSAGE - string.len("CH~" .. id .. "~512~512~")
    local count = math.max(1, math.ceil(string.len(payload) / size))
    if count > 512 then return nil end
    local out, i = {}, nil
    for i = 1, count do
        out[i] = "CH~" .. id .. "~" .. i .. "~" .. count .. "~" .. string.sub(payload, (i - 1) * size + 1, i * size)
    end
    return out
end
local function send(payload)
    if string.sub(payload, 1, 3) ~= "EV~" and string.len(payload) <= MAX_MESSAGE then
        if controlTail - controlHead >= 255 then return nil end
        controlTail = controlTail + 1; controls[controlTail] = payload
        return true
    end
    if string.len(payload) <= MAX_MESSAGE then return enqueue({payload}) end
    local chunks = C.chunk(payload)
    if chunks then return enqueue(chunks) end
end
function C.broadcast(ev)
    if EGM.Journal and EGM.Journal.relayable and not EGM.Journal.relayable(ev) then return end
    local wire = C.serialize(ev)
    if wire then return send("EV~" .. wire) end
end
local function summary()
    local all = EGM.Journal and EGM.Journal.all and EGM.Journal.all() or {}
    local newest = 0
    for _, ev in ipairs(all) do if ev.at and ev.at > newest then newest = ev.at end end
    return table.getn(all), newest
end
local function hello(kind, target)
    local count, newest = summary()
    send(kind .. "~" .. (EGM.PROTO or 1) .. "~" .. escape(EGM.VERSION or "0") .. "~" .. count .. "~" .. newest .. "~" .. escape(target or ""))
end
local function newer(a, b)
    local aa, bb = {}, {}
    for n in string.gfind(a, "%d+") do table.insert(aa, tonumber(n)) end
    for n in string.gfind(b, "%d+") do table.insert(bb, tonumber(n)) end
    local i
    for i = 1, math.max(table.getn(aa), table.getn(bb)) do
        if (aa[i] or 0) ~= (bb[i] or 0) then return (aa[i] or 0) > (bb[i] or 0) end
    end
    return false
end
local function receive(payload, sender)
    if string.sub(payload, 1, 3) == "EV~" then
        local ev = C.deserialize(string.sub(payload, 4))
        local peer = peers[sender]
        if ev and (not peer or peer.proto == (EGM.PROTO or 1)) and EGM.Journal and EGM.Journal.add then EGM.Journal.add(ev, sender) end
        return
    end
    local p = split(payload)
    if (p[1] == "HI" or p[1] == "PING") and table.getn(p) == 6 then
        local proto, ver, count, newest, target = tonumber(p[2]), unescape(p[3]), tonumber(p[4]), tonumber(p[5]), unescape(p[6])
        if not finite(proto) or not ver or not finite(count) or count < 0 or not finite(newest) or not target then return end
        peers[sender] = {proto = proto, count = count, newest = newest, at = GetTime()}
        if not warned and (proto > (EGM.PROTO or 1) or newer(ver, EGM.VERSION or "0")) then
            warned = true
            if EGM.Fire then EGM.Fire("UPDATE", ver) end
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("[EGM] A newer version is available: " .. ver) end
        end
        if p[1] == "HI" and target == "" and proto == (EGM.PROTO or 1) then hello("HI", sender) end
    elseif p[1] == "WANT" and table.getn(p) == 4 then
        local target, at, proto = unescape(p[2]), tonumber(p[3]), tonumber(p[4])
        if target ~= player() or not finite(at) or at < 0 or proto ~= (EGM.PROTO or 1) then return end
        local peer = peers[sender]
        if not peer or GetTime() - peer.at > 180 or (peer.lastWant and GetTime() - peer.lastWant < 30) then return end
        peer.lastWant = GetTime()
        if EGM.Journal and EGM.Journal.all and syncTail - syncHead < 8 then
            syncTail = syncTail + 1
            local all = EGM.Journal.all()
            syncJobs[syncTail] = {events = all, index = 1, last = table.getn(all), since = at}
        end
    end
end
function C.receive(prefix, message, channel, sender)
    if prefix ~= PREFIX or channel ~= "GUILD" or sender == player() or type(sender) ~= "string" or sender == "" or type(message) ~= "string" or string.len(message) > MAX_MESSAGE then return end
    if EGM.Roster and EGM.Roster.notePeer then EGM.Roster.notePeer(sender) end
    if string.sub(message, 1, 3) ~= "CH~" then receive(message, sender); return end
    local _, _, id, index, count, data = string.find(message, "^CH~([%w%-_]+)~(%d+)~(%d+)~(.*)$")
    index, count = tonumber(index), tonumber(count)
    if not id or string.len(id) > 40 or not index or not count or index < 1 or count < 1 or count > 512 or index > count then return end
    local key = sender .. ":" .. id
    local a = assemblies[key]
    if not a then
        if assemblyCount >= 64 then return end
        local perSender = 0
        for _, entry in pairs(assemblies) do if entry.sender == sender then perSender = perSender + 1 end end
        if perSender >= 8 then return end
        -- A maximum-sized event can take over 30 seconds at eight chunks/second.
        a = {sender = sender, count = count, parts = {}, got = 0, bytes = 0,
            expires = GetTime() + math.max(30, count * 0.125 + 10)}
        assemblies[key] = a; assemblyCount = assemblyCount + 1
    end
    if a.count ~= count or GetTime() > a.expires then assemblies[key] = nil; assemblyCount = assemblyCount - 1; return end
    if a.parts[index] then return end
    a.parts[index] = data; a.got = a.got + 1; a.bytes = a.bytes + string.len(data)
    if a.bytes > 65539 then assemblies[key] = nil; assemblyCount = assemblyCount - 1; return end
    if a.got == count then
        assemblies[key] = nil; assemblyCount = assemblyCount - 1
        local payload = table.concat(a.parts, "")
        if string.sub(payload, 1, 3) ~= "CH~" then receive(payload, sender) end
    end
end
function C.init()
    if started then return end
    started = true
    loginAt = GetTime() + 2
    nextPing = GetTime() + 60
end
C.start = C.init -- core/init.lua may explicitly start communication.
function C.update(dt)
    local now = GetTime()
    if started and loginAt and now >= loginAt then
        loginAt = nil; hello("HI"); electionAt = now + 3
    end
    if electionAt and now >= electionAt then
        electionAt = nil
        local count, newest = summary()
        local chosen, name, peer
        for name, peer in pairs(peers) do
            if peer.proto == (EGM.PROTO or 1) and now - peer.at <= 180 and
                (peer.count > count or peer.newest > newest) and (not chosen or name < chosen) then chosen = name end
        end
        -- Request all on a count mismatch: timestamps alone cannot reveal old holes.
        if chosen then
            local since = 0
            if peers[chosen].count == count then since = math.max(0, newest - 1) end
            send("WANT~" .. escape(chosen) .. "~" .. since .. "~" .. (EGM.PROTO or 1))
        end
    end
    if started and nextPing and now >= nextPing then nextPing = now + 60; hello("PING") end
    syncClock = syncClock + dt
    if syncClock >= 0.125 then
        syncClock = 0
        -- Feed the bounded queue gradually, even for a many-thousand-event history.
        local job = syncJobs[syncHead]
        if job and tail - head < 64 then
            local ev = job.index <= job.last and job.events[job.index]
            if ev then
                if ev.at >= job.since then C.broadcast(ev) end
                job.index = job.index + 1
            else
                syncJobs[syncHead] = nil; syncHead = syncHead + 1
                if syncHead > syncTail then syncHead = 1; syncTail = 0 end
            end
        end
    end
    housekeeping = housekeeping + dt
    if housekeeping >= 5 then
        housekeeping = 0
        local key, a
        for key, a in pairs(assemblies) do
            if now > a.expires then assemblies[key] = nil; assemblyCount = assemblyCount - 1 end
        end
        for key, a in pairs(peers) do if now - a.at > 180 then peers[key] = nil end end
    end
    credit = math.min(1, credit + dt)
    while (head <= tail or controlHead <= controlTail) and credit >= 0.125 do
        if IsInGuild and not IsInGuild() then break end
        -- Presence and election replies must not wait behind a large history.
        if controlHead <= controlTail then
            SendAddonMessage(PREFIX, controls[controlHead], "GUILD")
            controls[controlHead] = nil; controlHead = controlHead + 1
        else
            SendAddonMessage(PREFIX, queue[head], "GUILD")
            queue[head] = nil; head = head + 1
        end
        credit = credit - 0.125
    end
    if head > tail then head = 1; tail = 0 end
    if controlHead > controlTail then controlHead = 1; controlTail = 0 end
    if tail == 0 and controlTail == 0 then credit = 0 end
end
local frame = CreateFrame("Frame", "EGMFrameComm")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then C.init()
    else C.receive(arg1, arg2, arg3, arg4) end
end)
frame:SetScript("OnUpdate", function() C.update(arg1 or 0) end)
