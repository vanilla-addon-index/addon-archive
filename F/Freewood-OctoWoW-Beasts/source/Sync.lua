-- Freewood-OctoWoW-Beasts: Daten mit anderen Spielern teilen (Addon-Nachrichten)
--
-- Gesendet werden nur eigene Sichtungen, Wildtierkunde-Infos und Faehigkeiten gezaehmter Tiere,
-- keine Namen, keine Notizen. Alles ist standardmaessig AUS und je Kanal einzeln einstellbar:
-- Gilde, Gruppe, Schlachtzug, Global.
--
-- Ablauf (alles "ziehen", nie ungefragt grosse Datenmengen schieben):
--   H  Hallo mit Anzahl und Pruefwert der eigenen Tiere (Kanal)
--   A  Ankuendigung geaenderter Tiere  id:stand,... (Kanal)
--   Q  Anfrage nach dem Verzeichnis (Fluestern)
--   V  Verzeichnis id:stand,... in Stuecken (Fluestern)
--   R  Anfrage nach bestimmten Tieren (Fluestern)
--   B  Datensatz eines Tieres in Stuecken (Fluestern)
-- Zusaetzlich gibt es eine Personenliste (Battle.net-Freunde oder Charakternamen). Daten fliessen
-- nur, wenn beide sich gegenseitig eingetragen haben.
-- Empfangene Datensaetze laufen durch dieselbe Pruefung wie ein Import und liegen getrennt von
-- den eigenen Daten.

local ADDON, NS = ...

local FW = _G.Freewood
local Beasts = NS.Beasts
if not FW or not Beasts then
    return
end

local Sync = { started = false }
NS.Sync = Sync
Beasts.Sync = Sync

local PREFIX = "FWBeasts1"
local GLOBAL_CHANNEL = "FreewoodBeasts"
local MAXLEN = 230            -- Nutzlast je Nachricht
local SEND_INTERVAL = 0.4     -- Sekunden zwischen zwei Nachrichten
local GLOBAL_INTERVAL = 1.5   -- Global noch sparsamer
local MAX_QUEUE = 400
local MAX_CHUNKS = 40         -- Stuecke je Datensatz
local MAX_BUFFERS = 6
local SESSION_TTL = 600       -- Sekunden, so lange werden Antworten eines Anfrage-Partners angenommen
local SERVE_COOLDOWN = 300    -- ein Partner darf unser Verzeichnis alle 5 Minuten holen
local MAX_SERVE = 40          -- Tiere je Partner und Zeitraum
local MAX_REQUEST = 40        -- Tiere je Abgleich
local MAX_SESSIONS_HOUR = 6   -- selbst gestartete Abgleiche je Stunde
local MAX_RECEIVED_HOUR = 200 -- empfangene Datensaetze je Partner und Stunde
local ANNOUNCE_EVERY = 60
local ANNOUNCE_MIN = 300      -- ein Tier hoechstens alle 5 Minuten ankuendigen
local KINDS = { "guild", "party", "raid", "global" }

local state = {
    queue = {},
    peers = {},        -- [name] = { kind, t }
    sessions = {},     -- [name] = { t, digest = {...}, total }
    served = {},       -- [name] = { t, count }
    buffers = {},      -- [name .. id] = { t, n, parts }
    received = {},     -- [name] = { t, count }
    pending = {},      -- angekuendigte Tiere: [id] = true
    announced = {},    -- [id] = zeitpunkt
    sessionLog = {},   -- Zeitpunkte gestarteter Abgleiche
    lastGlobalSend = 0,
    routes = {},       -- [key] = { bn = gameAccountID, t }  (Battle.net-Wege)
    rawNames = {},     -- [key] = Absendername wie vom Spiel geliefert (Fluester-Ziel)
    blind = {},        -- [name] = Zeitpunkt des letzten Hallo an einen Charakter
    status = { global = "off" },
}
Sync.state = state

local function Now()
    return (GetTime and GetTime()) or time()
end

local function Settings()
    local s = Beasts.db.settings
    s.share = s.share or { guild = false, party = false, raid = false, global = false }
    return s.share
end

local function Store()
    Beasts.db.sync = Beasts.db.sync or { have = {}, sent = 0, received = 0 }
    Beasts.db.sync.have = Beasts.db.sync.have or {}
    return Beasts.db.sync
end

local function People()
    local s = Beasts.db.settings
    s.people = s.people or {}
    return s.people
end

function Sync:IsEnabled(kind)
    return Settings()[kind] == true
end

function Sync:AnyEnabled()
    for _, kind in ipairs(KINDS) do
        if Settings()[kind] then
            return true
        end
    end
    return #People() > 0
end

------------------------------------------------------------------------
-- Kleine Helfer
------------------------------------------------------------------------

local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"

local function ToB36(n)
    n = math.floor(n or 0)
    if n <= 0 then
        return "0"
    end
    local out = ""
    while n > 0 do
        local r = n % 36
        out = B36:sub(r + 1, r + 1) .. out
        n = (n - r) / 36
    end
    return out
end

local function FromB36(s)
    if type(s) ~= "string" or s == "" or #s > 8 or s:find("[^0-9a-z]") then
        return nil
    end
    local n = 0
    for i = 1, #s do
        n = n * 36 + (B36:find(s:sub(i, i), 1, true) - 1)
    end
    return n
end

local function Clean(sender)
    if type(sender) ~= "string" then
        return nil
    end
    if Ambiguate then
        local ok, v = pcall(Ambiguate, sender, "none")
        if ok and v then
            return v
        end
    end
    return sender
end

-- Schluessel eines Absenders: kleingeschrieben, ohne Serveranhang wenn es der eigene ist
local function KeyOf(sender)
    local c = Clean(sender)
    if not c then
        return nil
    end
    if c:sub(1, 3) == "bn:" then
        return c:lower()
    end
    return c:lower()
end

-- Name ohne Realm, ohne Leerzeichen (auch geschuetzte), kleingeschrieben; Namen koennen Leerzeichen enthalten
local function NameCore(s)
    if type(s) ~= "string" then
        return ""
    end
    s = s:gsub("\194\160", " "):match("^([^%-]*)") or s
    s = s:gsub("%s", ""):lower()
    return s
end

-- Eigener Name: Spielfunktionen liefern bei Forever nur den Vornamen; der volle Name (mit Nachnamen),
-- unter dem uns die anderen sehen, wird ueber eine Probe-Nachricht "E|<Nummer>" gelernt
local learnedSelf = {}
local SESSION_NONCE = string.format("%06d", math.random(0, 999999)) .. string.format("%03d", math.random(0, 999))

local function IsSelf(sender)
    if type(sender) ~= "string" then
        return false
    end
    local c = NameCore(sender)
    if c == "" then
        return false
    end
    if learnedSelf[c] then
        return true
    end
    local me = UnitName and UnitName("player")
    return me ~= nil and NameCore(me) == c
end

local function GetEncoder()
    local E = _G.C_EncodingUtil
    if E and E.SerializeCBOR and E.DeserializeCBOR and E.CompressString
        and E.DecompressString and E.EncodeBase64 and E.DecodeBase64 then
        return E
    end
    return nil
end

local function EncodeRecord(rec)
    local E = GetEncoder()
    if not E then
        return nil
    end
    local ok, cbor = pcall(E.SerializeCBOR, rec)
    if not ok or type(cbor) ~= "string" then
        return nil
    end
    local ok2, packed = pcall(E.CompressString, cbor)
    if not ok2 or type(packed) ~= "string" then
        return nil
    end
    local ok3, body = pcall(E.EncodeBase64, packed)
    if not ok3 or type(body) ~= "string" then
        return nil
    end
    return body
end

local function DecodeRecord(body)
    local E = GetEncoder()
    if not E or type(body) ~= "string" or body:find("[^%w%+/=]") then
        return nil
    end
    local ok, packed = pcall(E.DecodeBase64, body)
    if not ok or type(packed) ~= "string" then
        return nil
    end
    local ok2, cbor = pcall(E.DecompressString, packed)
    if not ok2 or type(cbor) ~= "string" then
        return nil
    end
    local ok3, rec = pcall(E.DeserializeCBOR, cbor)
    if not ok3 or type(rec) ~= "table" then
        return nil
    end
    if FW.Export and FW.Export.CheckStructure and not FW.Export.CheckStructure(rec) then
        return nil
    end
    return rec
end

------------------------------------------------------------------------
-- Senden mit Warteschlange
------------------------------------------------------------------------

local function Raw(dist, target, text)
    local api = _G.C_ChatInfo
    if api and api.SendAddonMessage then
        local ok, res = pcall(api.SendAddonMessage, PREFIX, text, dist, target)
        if ok and res == 3 then
            return false, true  -- gebremst: Nachricht behalten
        end
        return ok
    end
    return false
end

local function Enqueue(item)
    local q = state.queue
    if #q >= MAX_QUEUE then
        -- aelteste Rundrufe verwerfen, Datensaetze bleiben
        for i = 1, #q do
            local t = q[i].text:sub(1, 1)
            if t == "H" or t == "A" then
                table.remove(q, i)
                break
            end
        end
        if #q >= MAX_QUEUE then
            return false
        end
    end
    q[#q + 1] = item
    return true
end

-- Eine Nachricht aus der Schlange senden (vom Zeitgeber aufgerufen)
function Sync:Pump()
    local q = state.queue
    if #q == 0 then
        return false
    end
    local now = Now()
    for i = 1, #q do
        local item = q[i]
        if item.dist == "CHANNEL" and now - state.lastGlobalSend < GLOBAL_INTERVAL then
            -- noch nicht dran, naechste Nachricht versuchen
        else
            table.remove(q, i)
            if item.dist == "CHANNEL" then
                state.lastGlobalSend = now
            end
            if item.bn then
                Sync.SendBN(item.bn, item.text)
            else
                local _, throttled = Raw(item.dist, item.target, item.text)
                if throttled then
                    item.tries = (item.tries or 0) + 1
                    if item.tries <= 12 then table.insert(q, 1, item) end
                    state.lastGlobalSend = now + 3
                end
            end
            return true
        end
    end
    return false
end

-- Battle.net-Nachricht an ein Spielkonto eines Freundes
function Sync.SendBN(gameAccountID, text)
    local fn = (_G.C_BattleNet and _G.C_BattleNet.SendGameData) or _G.BNSendGameData
    if type(fn) ~= "function" then
        return false
    end
    return pcall(fn, gameAccountID, PREFIX, text)
end

function Sync:BNAvailable()
    return type((_G.C_BattleNet and _G.C_BattleNet.SendGameData) or _G.BNSendGameData) == "function"
        and type(_G.C_BattleNet and _G.C_BattleNet.GetFriendAccountInfo) == "function"
end

-- Antwort an einen Absender (Schluessel): Battle.net-Weg oder Fluestern
local function Whisper(key, text)
    if key:sub(1, 3) == "bn:" then
        local route = state.routes[key]
        if route and route.bn then
            return Enqueue({ bn = route.bn, text = text })
        end
        return false
    end
    -- OctoWoW: kein Fluestern. Antwort ueber denselben Kanal, mit dem Namen des Empfaengers in der Nachricht
    -- (andere ignorieren sie).
    local peer = state.peers[key]
    local kind = (peer and peer.kind) or "global"
    if kind == "people" then kind = "global" end
    local dist, target = Sync:Distribution(kind)
    if not dist then
        return false
    end
    local who = state.rawNames[key] or key
    return Enqueue({ dist = dist, target = target, text = text:sub(1, 1) .. "|" .. who .. text:sub(2) })
end

local function InstanceGroup()
    return _G.LE_PARTY_CATEGORY_INSTANCE and IsInGroup and IsInGroup(_G.LE_PARTY_CATEGORY_INSTANCE)
end

-- Verteilung fuer eine Art: Rueckgabe dist, target oder nil
function Sync:Distribution(kind)
    -- OctoWoW: nur der eigene Kanal (Gilde/Gruppe/Schlachtzug werden nicht benutzt)
    if kind ~= "global" then return nil end
    if kind == "guild" then
        if IsInGuild and IsInGuild() then
            return "GUILD"
        end
    elseif kind == "party" then
        if InstanceGroup() then
            return "INSTANCE_CHAT"
        end
        if IsInGroup and IsInGroup() and not (IsInRaid and IsInRaid()) then
            return "PARTY"
        end
    elseif kind == "raid" then
        if IsInRaid and IsInRaid() then
            if InstanceGroup() then
                return "INSTANCE_CHAT"
            end
            return "RAID"
        end
    elseif kind == "global" then
        if GetChannelName then
            local id = GetChannelName(GLOBAL_CHANNEL)
            if type(id) == "number" and id > 0 then
                return "CHANNEL", id
            end
        end
    end
    return nil
end

-- Rundruf in alle eingeschalteten Kanaele (ohne Doppelsendung ueber dieselbe Verteilung)
local function Broadcast(text)
    local used = {}
    local sent = 0
    for _, kind in ipairs(KINDS) do
        if Settings()[kind] then
            local dist, target = Sync:Distribution(kind)
            if dist then
                local key = dist .. tostring(target or "")
                if not used[key] then
                    used[key] = true
                    Enqueue({ dist = dist, target = target, text = text })
                    sent = sent + 1
                end
            end
        end
    end
    return sent
end

------------------------------------------------------------------------
-- Personenliste (Battle.net-Freunde und Charakternamen)
------------------------------------------------------------------------

function Sync:GetPeople()
    return People()
end

local function PersonKey(p)
    if p.kind == "bnet" then
        return "bn:" .. (p.tag or ""):lower()
    end
    return (Clean(p.name or "") or ""):lower()
end

function Sync:AddPerson(kind, value, label)
    value = type(value) == "string" and value:gsub("^%s+", ""):gsub("%s+$", "") or nil
    if not value or value == "" or #value > 64 or value:find("[%c|]") then
        return false, "invalid"
    end
    if kind ~= "bnet" and kind ~= "char" then
        return false, "invalid"
    end
    local p = { kind = kind, label = type(label) == "string" and label:sub(1, 48) or nil }
    if kind == "bnet" then
        p.tag = value
    else
        p.name = value
    end
    local key = PersonKey(p)
    for _, q in ipairs(People()) do
        if PersonKey(q) == key then
            return false, "exists"
        end
    end
    if #People() >= 50 then
        return false, "full"
    end
    People()[#People() + 1] = p
    FW:Fire("BEASTS_SYNC_CHANGED")
    C_Timer.After(2 + math.random() * 3, function()
        Sync:SendHelloPeople()
    end)
    return true
end

function Sync:RemovePerson(index)
    local list = People()
    if list[index] then
        table.remove(list, index)
        FW:Fire("BEASTS_SYNC_CHANGED")
        return true
    end
    return false
end

-- Ist dieser Absender (Schluessel) auf meiner Liste?
function Sync:IsListed(key)
    if type(key) ~= "string" then
        return false
    end
    for _, p in ipairs(People()) do
        if PersonKey(p) == key then
            return true
        end
    end
    return false
end

-- Freunde bei Battle.net: { {tag, name, online, gameAccountID, character} }
function Sync:BNFriends()
    local out = {}
    local api = _G.C_BattleNet
    if not api or type(api.GetFriendAccountInfo) ~= "function" then
        return out
    end
    local num = _G.BNGetNumFriends and select(1, _G.BNGetNumFriends()) or 0
    for i = 1, num do
        local ok, info = pcall(api.GetFriendAccountInfo, i)
        if ok and type(info) == "table" then
            local g = info.gameAccountInfo or {}
            out[#out + 1] = {
                tag = info.battleTag,
                name = info.accountName,
                online = (g.isOnline and g.clientProgram == "WoW") and true or false,
                gameAccountID = g.gameAccountID,
                character = g.characterName,
            }
        end
    end
    return out
end

-- Battle.net-Schluessel zu einer Spielkonto-Nummer (Absender einer Nachricht)
function Sync:BNKeyForGameAccount(gameAccountID)
    for _, f in ipairs(self:BNFriends()) do
        if f.gameAccountID == gameAccountID and f.tag then
            return "bn:" .. f.tag:lower(), f
        end
    end
    return nil
end

-- Erreichbare Personen aus der Liste: Liste von Schluesseln (Battle.net nur wenn gerade in WoW)
function Sync:ReachablePeople(includeBlind)
    local keys = {}
    local friends
    for _, p in ipairs(People()) do
        local key = PersonKey(p)
        if p.kind == "bnet" then
            friends = friends or self:BNFriends()
            for _, f in ipairs(friends) do
                if f.tag and ("bn:" .. f.tag:lower()) == key and f.online and f.gameAccountID then
                    state.routes[key] = { bn = f.gameAccountID, t = Now() }
                    keys[#keys + 1] = key
                    break
                end
            end
        else
            local peer = state.peers[key]
            local heard = peer and Now() - peer.t < 1200
            if heard then
                keys[#keys + 1] = key
            elseif includeBlind and Now() - (state.blind[key] or 0) > 600 then
                state.blind[key] = Now()
                state.rawNames[key] = state.rawNames[key] or p.name
                keys[#keys + 1] = key
            end
        end
    end
    return keys
end

-- Fehlermeldung "Spieler nicht gefunden" fuer Personen unserer Liste ausblenden
local filterInstalled = false
local function InstallFilter()
    if filterInstalled or type(ChatFrame_AddMessageEventFilter) ~= "function" then
        return
    end
    filterInstalled = true
    local pattern
    local fmt = _G.ERR_CHAT_PLAYER_NOT_FOUND_S
    if type(fmt) == "string" then
        pattern = "^" .. fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, msg)
        if pattern and type(msg) == "string" then
            local who = msg:match(pattern)
            if who and Sync:IsListed(KeyOf(who:gsub("^'", ""):gsub("'$", "")) or "") then
                return true
            end
        end
        return false
    end)
end

function Sync:SendHelloPeople()
    if #People() == 0 then
        return 0
    end
    local n, h = Beasts:ShareSummary()
    if n == 0 then
        return 0
    end
    InstallFilter()
    local sent = 0
    for _, key in ipairs(self:ReachablePeople(true)) do
        if Whisper(key, string.format("H|%d|%d", h, n)) then
            sent = sent + 1
        end
    end
    return sent
end

------------------------------------------------------------------------
-- Hallo und Ankuendigungen
------------------------------------------------------------------------

function Sync:SendHello()
    if not self:AnyEnabled() then
        return false
    end
    local n, h = Beasts:ShareSummary()
    if n == 0 then
        return false
    end
    if next(learnedSelf) == nil then
        Broadcast("E|" .. SESSION_NONCE)
    end
    local sent = Broadcast(string.format("H|%d|%d", h, n))
    sent = sent + self:SendHelloPeople()
    return sent > 0
end

local function Version(id)
    local e = Beasts:ShareEntry(id)
    return e and (e.updated or 0) or 0
end

local function Have(id, upd)
    local h = Store().have[id]
    return h and h[upd] == true
end

local function MarkHave(id, upd)
    local have = Store().have
    local h = have[id]
    if not h then
        h = { order = {} }
        have[id] = h
    end
    h.order = h.order or {}
    if not h[upd] then
        h[upd] = true
        h.order[#h.order + 1] = upd
        while #h.order > 20 do
            h[table.remove(h.order, 1)] = nil
        end
    end
end

local function SessionAllowed()
    local now = Now()
    local log = state.sessionLog
    for i = #log, 1, -1 do
        if now - log[i] > 3600 then
            table.remove(log, i)
        end
    end
    return #log < MAX_SESSIONS_HOUR
end

function Sync:QueueAnnounce(id)
    if not self:AnyEnabled() or type(id) ~= "number" then
        return
    end
    local e = Beasts:ShareEntry(id)
    if e and (e.seen or e.lored or e.tamed) then
        state.pending[id] = true
    end
end

function Sync:FlushAnnounce()
    if not self:AnyEnabled() then
        state.pending = {}
        return 0
    end
    local now = Now()
    local ids = {}
    for id in pairs(state.pending) do
        if now - (state.announced[id] or 0) >= ANNOUNCE_MIN then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    local parts, count = {}, 0
    local function flush()
        if #parts > 0 then
            local text = "A|" .. table.concat(parts, ",")
            Broadcast(text)
            for _, key in ipairs(Sync:ReachablePeople(false)) do
                Whisper(key, text)
            end
            parts = {}
        end
    end
    for _, id in ipairs(ids) do
        state.pending[id] = nil
        state.announced[id] = now
        parts[#parts + 1] = string.format("%d:%s", id, ToB36(Version(id)))
        count = count + 1
        if #parts >= 12 then
            flush()
        end
    end
    flush()
    return count
end

------------------------------------------------------------------------
-- Verzeichnis und Datensaetze
------------------------------------------------------------------------

-- Eintraege "id:stand" in Nachrichten verpacken
local function PackList(prefix, entries)
    local msgs, current = {}, {}
    local len = 0
    for _, e in ipairs(entries) do
        local add = #e + 1
        if len + add > MAXLEN - 36 and #current > 0 then
            msgs[#msgs + 1] = table.concat(current, ",")
            current, len = {}, 0
        end
        current[#current + 1] = e
        len = len + add
    end
    if #current > 0 then
        msgs[#msgs + 1] = table.concat(current, ",")
    end
    local out = {}
    for i, body in ipairs(msgs) do
        out[i] = string.format("%s|%d/%d|%s", prefix, i, #msgs, body)
    end
    return out
end

local function ParseEntries(body)
    local out = {}
    if type(body) ~= "string" then
        return out
    end
    for id, upd in body:gmatch("(%d+):([0-9a-z]+)") do
        local nid, nupd = tonumber(id), FromB36(upd)
        if nid and nupd and nid >= 1 and nid <= 10000000 and #out < 400 then
            out[#out + 1] = { id = nid, upd = nupd }
        end
    end
    return out
end

function Sync:SendDigest(name)
    local entries = {}
    for id, e in pairs(Beasts:ShareIds()) do
        entries[#entries + 1] = { id = id, upd = e.updated or 0 }
    end
    table.sort(entries, function(a, b)
        return a.upd > b.upd
    end)
    local flat = {}
    for i, e in ipairs(entries) do
        if i > 400 then
            break
        end
        flat[#flat + 1] = string.format("%d:%s", e.id, ToB36(e.upd))
    end
    for _, msg in ipairs(PackList("V", flat)) do
        Whisper(name, msg)
    end
    return #flat
end

-- Welche Tiere aus einer Liste fehlen uns (neuer Stand, den wir noch nicht kennen)?
local function Missing(entries)
    local need = {}
    for _, e in ipairs(entries) do
        if e.upd > 0 and not Have(e.id, e.upd) then
            need[#need + 1] = e
        end
    end
    table.sort(need, function(a, b)
        return a.upd > b.upd
    end)
    return need
end

function Sync:SendRequest(name, need)
    local ids = {}
    for i, e in ipairs(need) do
        if i > MAX_REQUEST then
            break
        end
        ids[#ids + 1] = string.format("%d:%s", e.id, ToB36(e.upd))
    end
    if #ids == 0 then
        return 0
    end
    for _, msg in ipairs(PackList("R", ids)) do
        Whisper(name, msg)
    end
    state.sessions[name] = state.sessions[name] or { t = Now() }
    state.sessions[name].t = Now()
    return #ids
end

function Sync:ServeRecords(name, entries)
    local now = Now()
    local s = state.served[name]
    if not s or now - s.t > SERVE_COOLDOWN then
        s = { t = now, count = 0 }
        state.served[name] = s
    end
    local sent = 0
    for _, e in ipairs(entries) do
        if s.count >= MAX_SERVE then
            break
        end
        local rec = Beasts:ShareRecord(e.id)
        if rec then
            local body = EncodeRecord(rec)
            local upd = Version(e.id)
            if body then
                local PIECE = MAXLEN - 46      -- Platz fuer Kopf und Empfaengername
                local n = math.ceil(#body / PIECE)
                if n >= 1 and n <= MAX_CHUNKS then
                    for i = 1, n do
                        local piece = body:sub((i - 1) * PIECE + 1, i * PIECE)
                        Whisper(name, string.format("B|%d|%s|%d/%d|%s", e.id, ToB36(upd), i, n, piece))
                    end
                    s.count = s.count + 1
                    sent = sent + 1
                    Store().sent = (Store().sent or 0) + 1
                end
            end
        end
    end
    return sent
end

local function ReceivedAllowed(name)
    local now = Now()
    local r = state.received[name]
    if not r or now - r.t > 3600 then
        r = { t = now, count = 0 }
        state.received[name] = r
    end
    return r.count < MAX_RECEIVED_HOUR, r
end

function Sync:ReceiveChunk(name, id, upd, i, n, piece)
    local sess = state.sessions[name]
    if not sess or Now() - sess.t > SESSION_TTL then
        return false
    end
    if not id or not upd or not i or not n or n < 1 or n > MAX_CHUNKS or i < 1 or i > n or #piece > MAXLEN then
        return false
    end
    local key = name .. ":" .. id
    local buf = state.buffers[key]
    if not buf then
        local count = 0
        for _ in pairs(state.buffers) do
            count = count + 1
        end
        if count >= MAX_BUFFERS then
            return false
        end
        buf = { t = Now(), n = n, parts = {}, got = 0, id = id, upd = upd }
        state.buffers[key] = buf
    end
    if buf.n ~= n or buf.id ~= id then
        state.buffers[key] = nil
        return false
    end
    if not buf.parts[i] then
        buf.parts[i] = piece
        buf.got = buf.got + 1
    end
    if buf.got < n then
        return true
    end
    state.buffers[key] = nil
    local ok, r = ReceivedAllowed(name)
    if not ok then
        return false
    end
    r.count = r.count + 1
    local rec = DecodeRecord(table.concat(buf.parts))
    if not rec or rec.id ~= id then
        return false
    end
    MarkHave(id, upd)
    Beasts:ImportData({ list = { rec } }, { merge = true })
    local store = Store()
    store.received = (store.received or 0) + 1
    store.lastReceived = time()
    return true
end

------------------------------------------------------------------------
-- Empfang
------------------------------------------------------------------------

local function KindOf(channel)
    if channel == "GUILD" then
        return "guild"
    elseif channel == "PARTY" then
        return "party"
    elseif channel == "RAID" then
        return "raid"
    elseif channel == "INSTANCE_CHAT" then
        return (Settings().party and "party") or (Settings().raid and "raid") or "party"
    elseif channel == "CHANNEL" then
        return "global"
    end
    return nil
end

-- text: "T|..."; channel: Verteilung laut Ereignis; sender: Absender
function Sync:HandleMessage(channel, sender, text)
    if type(text) ~= "string" or #text < 3 or #text > 255 then
        return false
    end
    if type(sender) ~= "string" or sender == "" or IsSelf(sender) then
        return false
    end
    local name = KeyOf(sender)
    if not name then
        return false
    end
    if channel ~= "BN" then
        state.rawNames[name] = sender
    end
    if channel == "CHANNEL" then
        local t0 = text:sub(1, 1)
        if t0 == "Q" or t0 == "V" or t0 == "R" or t0 == "B" then
            -- an uns persoenlich gerichtet? Format: "<Art>|<Empfaenger>|<Rest>"
            local target, rest = text:sub(3):match("^([^|]+)|(.*)$")
            if not target or not IsSelf(target) then
                return false
            end
            text = t0 .. "|" .. rest
            channel = "WHISPER"
            -- wer uns ueber den eingeschalteten Kanal anspricht, darf auch bedient werden
            if (t0 == "Q" or t0 == "R") and Settings().global then
                local pr = state.peers[name]
                if not pr then
                    state.peers[name] = { kind = "global", t = Now() }
                elseif pr.kind == "global" then
                    pr.t = Now()
                end
            end
        end
    end
    local t = text:sub(1, 1)
    local body = text:sub(3)
    local kind = KindOf(channel)
    local listed = (channel == "WHISPER") and self:IsListed(name)
    if not kind and listed and (t == "H" or t == "A") then
        kind = "people"
    end

    if kind then
        -- Rundrufe nur aus eingeschalteten Kanaelen bzw. von Personen aus der Liste
        if kind == "people" then
            if not listed then
                return false
            end
        elseif not Settings()[kind] then
            return false
        end
        if t == "H" then
            local h, n = body:match("^(%d+)|(%d+)$")
            h, n = tonumber(h), tonumber(n)
            if not h or not n or n < 1 then
                return false
            end
            local mine = select(2, Beasts:ShareSummary())
            local peer = state.peers[name] or {}
            state.peers[name] = { kind = kind, t = Now(), hash = h, count = n, queried = peer.queried }
            if h ~= mine and not (peer.queried and Now() - peer.queried < 600) and SessionAllowed() then
                local active = 0
                for _, s in pairs(state.sessions) do
                    if Now() - s.t < 120 and s.digest then
                        active = active + 1
                    end
                end
                if active < 2 then
                    state.peers[name].queried = Now()
                    state.sessionLog[#state.sessionLog + 1] = Now()
                    state.sessions[name] = { t = Now(), digest = {}, got = 0 }
                    Whisper(name, "Q|1")
                end
            end
            return true
        elseif t == "A" then
            local entries = ParseEntries(body)
            state.peers[name] = { kind = kind, t = Now(), hash = (state.peers[name] or {}).hash, queried = (state.peers[name] or {}).queried }
            local need = Missing(entries)
            if #need > 0 and #need <= 12 then
                self:SendRequest(name, need)
            end
            return true
        end
        return false
    end

    if channel ~= "WHISPER" then
        return false
    end
    local peer = state.peers[name]
    if t == "Q" then
        -- nur Partner bedienen, die uns ueber einen eingeschalteten Kanal gerufen haben
        if not listed and (not peer or Now() - peer.t > 900 or not Settings()[peer.kind]) then
            return false
        end
        local s = state.served[name]
        if s and Now() - s.t < SERVE_COOLDOWN and s.digest then
            return false
        end
        state.served[name] = { t = Now(), count = 0, digest = true }
        self:SendDigest(name)
        return true
    elseif t == "V" then
        local sess = state.sessions[name]
        if not sess or not sess.digest or Now() - sess.t > SESSION_TTL then
            return false
        end
        local i, n, list = body:match("^(%d+)/(%d+)|(.*)$")
        i, n = tonumber(i), tonumber(n)
        if not i or not n or n < 1 or n > 30 or i < 1 or i > n then
            return false
        end
        for _, e in ipairs(ParseEntries(list)) do
            if #sess.digest < 400 then
                sess.digest[#sess.digest + 1] = e
            end
        end
        sess.got = (sess.got or 0) + 1
        if sess.got >= n then
            local need = Missing(sess.digest)
            sess.digest = nil
            self:SendRequest(name, need)
        end
        return true
    elseif t == "R" then
        if not listed and (not peer or Now() - peer.t > 900 or not Settings()[peer.kind]) then
            return false
        end
        local _, _, list = body:match("^(%d+)/(%d+)|(.*)$")
        local entries = ParseEntries(list)
        -- nur ausliefern, was wir wirklich haben
        local valid = {}
        for _, e in ipairs(entries) do
            if Beasts:ShareEntry(e.id) then
                valid[#valid + 1] = e
            end
        end
        self:ServeRecords(name, valid)
        return true
    elseif t == "B" then
        local id, upd, i, n, piece = body:match("^(%d+)|([0-9a-z]+)|(%d+)/(%d+)|(.+)$")
        return self:ReceiveChunk(name, tonumber(id), FromB36(upd), tonumber(i), tonumber(n), piece)
    end
    return false
end

------------------------------------------------------------------------
-- Global-Kanal
------------------------------------------------------------------------

function Sync:JoinGlobal()
    if not Settings().global then
        return
    end
    local id = GetChannelName and GetChannelName(GLOBAL_CHANNEL)
    if type(id) == "number" and id > 0 then
        state.status.global = "ok"
        return
    end
    if type(JoinChannelByName) ~= "function" then
        state.status.global = "unavailable"
        return
    end
    local ok = pcall(JoinChannelByName, GLOBAL_CHANNEL)
    if not ok then
        state.status.global = "failed"
        return
    end
    -- aus allen Chatfenstern ausblenden, damit nichts im Chat auftaucht
    if type(ChatFrame_RemoveChannel) == "function" then
        for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
            local frame = _G["ChatFrame" .. i]
            if frame then
                pcall(ChatFrame_RemoveChannel, frame, GLOBAL_CHANNEL)
            end
        end
    end
    state.status.global = "joining"
    C_Timer.After(3, function()
        local cid = GetChannelName and GetChannelName(GLOBAL_CHANNEL)
        state.status.global = (type(cid) == "number" and cid > 0) and "ok" or "failed"
        if state.status.global == "ok" and Sync:AnyEnabled() then
            Sync:SendHello()
        end
        FW:Fire("BEASTS_SYNC_CHANGED")
    end)
end

function Sync:LeaveGlobal()
    if type(LeaveChannelByName) == "function" then
        pcall(LeaveChannelByName, GLOBAL_CHANNEL)
    end
    state.status.global = "off"
end

function Sync:SetShare(kind, on)
    local s = Settings()
    if s[kind] == nil then
        return
    end
    s[kind] = on and true or false
    if kind == "global" then
        if on then
            self:JoinGlobal()
        else
            self:LeaveGlobal()
        end
    end
    if on then
        C_Timer.After(2 + math.random() * 3, function()
            Sync:SendHello()
        end)
    end
    FW:Fire("BEASTS_SYNC_CHANGED")
end

------------------------------------------------------------------------
-- Start / Stopp und Zeitgeber
------------------------------------------------------------------------

local function Tick()
    if not Sync.started then
        return
    end
    Sync:Pump()
    -- abgelaufene Zwischenspeicher entfernen
    local now = Now()
    for key, buf in pairs(state.buffers) do
        if now - buf.t > 60 then
            state.buffers[key] = nil
        end
    end
    C_Timer.After(SEND_INTERVAL, Tick)
end

local function AnnounceLoop()
    if not Sync.started then
        return
    end
    Sync:FlushAnnounce()
    C_Timer.After(ANNOUNCE_EVERY, AnnounceLoop)
end

local function HelloLoop()
    if not Sync.started then
        return
    end
    Sync:SendHello()
    C_Timer.After(2700, HelloLoop)   -- alle 45 Minuten
end

function Sync:OnAddonMessage(prefix, text, channel, sender)
    if prefix ~= PREFIX then
        return
    end
    if type(text) == "string" and text:sub(1, 2) == "E|" then
        if text == "E|" .. SESSION_NONCE and type(sender) == "string" then
            local c = NameCore(sender)
            if c ~= "" then
                learnedSelf[c] = true
            end
        end
        return
    end
    if type(text) == "string" and text:sub(1, 2) == "G|" then
        self:HandleBye(sender)
        return
    end
    self:HandleMessage(channel, sender, text)
end

-- Ein Spieler meldet sich ab: ihm nichts mehr senden, Warteschlange fuer ihn leeren
function Sync:HandleBye(sender)
    local name = KeyOf(sender)
    if not name or IsSelf(sender) then return end
    state.peers[name] = nil
    state.sessions[name] = nil
    state.served[name] = nil
    local q = state.queue
    for i = #q, 1, -1 do
        local item = q[i]
        if not item.bn then
            local who = tostring(item.text or ""):match("^%a|([^|]+)|")
            if who and KeyOf(who) == name then table.remove(q, i) end
        end
    end
end

-- Beim Ausloggen/Beenden "Tschuess" in den Kanal (an der Warteschlange vorbei)
function Sync:SayBye()
    if not self.started or not self:AnyEnabled() then return end
    local dist, target = self:Distribution("global")
    if dist then Raw(dist, target, "G|") end
    state.queue = {}
end

local byeHooked = false
local function InstallByeHooks()
    if byeHooked then return end
    byeHooked = true
    if _G.hooksecurefunc then
        for _, fn in ipairs({ "Logout", "Quit" }) do
            if type(_G[fn]) == "function" then pcall(hooksecurefunc, fn, function() Sync:SayBye() end) end
        end
    end
    for _, ev in ipairs({ "PLAYER_QUITING", "PLAYER_CAMPING", "PLAYER_LOGOUT" }) do
        pcall(FW.RegisterEvent, FW, ev, function() Sync:SayBye() end, Sync)
    end
    pcall(FW.RegisterEvent, FW, "CANCEL_LOGOUT", function()
        if Sync.started then C_Timer.After(2, function() Sync:SendHello() end) end
    end, Sync)
end

-- Nachricht eines Battle.net-Freundes
function Sync:OnBNMessage(prefix, text, _, senderID)
    if prefix ~= PREFIX then
        return
    end
    local key = self:BNKeyForGameAccount(senderID)
    if not key or not self:IsListed(key) then
        return
    end
    state.routes[key] = { bn = senderID, t = Now() }
    self:HandleMessage("WHISPER", key, text)
end

local friendHelloAt = 0
function Sync:OnFriendOnline()
    if #People() == 0 or Now() - friendHelloAt < 60 then
        return
    end
    friendHelloAt = Now()
    C_Timer.After(5 + math.random() * 5, function()
        Sync:SendHelloPeople()
    end)
end

local groupHelloAt = 0
function Sync:OnGroupChanged()
    if not (Settings().party or Settings().raid) then
        return
    end
    if Now() - groupHelloAt < 120 then
        return
    end
    groupHelloAt = Now()
    C_Timer.After(8, function()
        Sync:SendHello()
    end)
end

function Sync:Start()
    if self.started then
        return
    end
    self.started = true
    local api = _G.C_ChatInfo
    if api and api.RegisterAddonMessagePrefix then
        pcall(api.RegisterAddonMessagePrefix, PREFIX)
    end
    FW:RegisterEvent("CHAT_MSG_ADDON", self.OnAddonMessage, self)
    FW:RegisterEvent("GROUP_ROSTER_UPDATE", self.OnGroupChanged, self)
    FW:RegisterEvent("BN_CHAT_MSG_ADDON", self.OnBNMessage, self)
    FW:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE", self.OnFriendOnline, self)
    InstallByeHooks()
    FW:On("BEASTS_UPDATED", function(_, id)
        if id then
            Sync:QueueAnnounce(id)
        end
    end, self)
    C_Timer.After(SEND_INTERVAL, Tick)
    C_Timer.After(ANNOUNCE_EVERY, AnnounceLoop)
    -- erstes Hallo nach dem Einloggen, etwas verteilt, damit nicht alle gleichzeitig rufen
    C_Timer.After(20 + math.random() * 30, function()
        if Sync.started then
            Sync:JoinGlobal()
            HelloLoop()
        end
    end)
end

function Sync:Stop()
    self.started = false
    FW:UnregisterEvent("CHAT_MSG_ADDON", self)
    FW:UnregisterEvent("GROUP_ROSTER_UPDATE", self)
    FW:UnregisterEvent("BN_CHAT_MSG_ADDON", self)
    FW:UnregisterEvent("BN_FRIEND_ACCOUNT_ONLINE", self)
    FW:Off("BEASTS_UPDATED", self)
    state.queue = {}
end

-- fuer die Einstellungen: Zaehler und Status
function Sync:Stats()
    local store = Store()
    return {
        sent = store.sent or 0,
        received = store.received or 0,
        lastReceived = store.lastReceived,
        queue = #state.queue,
        global = state.status.global,
        bnet = self:BNAvailable(),
        people = #People(),
    }
end

if Beasts.state == "enabled" then
    Sync:Start()
end
