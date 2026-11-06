-- DopingControl scan/addons.lua
-- Addons tab backend: finds out which raid addons the OTHER raiders run.
-- They do not run DopingControl, so detection rides only on what their own
-- addons send or answer:
--   BigWigs   prefix "BigWigs" (RAID): query "BWVQ BigWigs"; replies
--             "PEPO_BWVR <rev> <nick>", "BWVR <rev> <nick> <Fork>", the
--             old "MC:REV" style or a bare number. Any other BigWigs sync
--             proves presence without a version.
--   Threat    prefix "TWT": query "TWT_WHO"; replies "TWT_ME:<ver>";
--             passive "TWTVersion:<ver>" at login. (Server threat packets
--             use the prefix "TWT " with a trailing space - a different
--             prefix, ignored here.)
--   EPGP      shootyepgp, prefix "SEPGP_PREFIX" (GUILD): "VERSION;<ver>;<n>"
--             at the sender's login only; no query answer.
--   SuperWoW  prefix "SWOW_Q" (GUILD) is answered by shootyepgp on prefix
--             "SWOW_R" with "1" (SuperWoW present) or "0". A reply also
--             proves shootyepgp itself is installed.
--   Rinse     prefix "Rinse": query "REPORT_ADDON_VERSION", reply
--             "V_<ver>" (only the UpsiRinse fork answers).
--   RABuffs   passive only. Every client in a raid broadcasts on prefix
--             "RAB/BT" (RAID) every 30 s: "<key> <number>" pairs ("h2oc 20
--             fort 1500 ..."), but only when it has something to report
--             (mana users, tracked timed buffs). The version messages
--             "RAB/V" ("<ver> <deci>") and "RAB/VC" are disabled upstream;
--             parsed if they ever arrive, never sent. Its own version check
--             runs over visible chat and is never used. Silence is weak
--             evidence: "not seen" only after RAB_SILENT seconds in the raid.
--   BCS       BetterCharacterStats, passive only. Its sole traffic is prefix
--             "bcs" on PARTY: "TREE,<name>[,<bonus>]", sent by druids in
--             Tree of Life form. Too rare to prove anything: without a
--             responder answer (below) a member is unknown, never missing.
--   ADDONCHECK  the shootyepgp responder. One query "Q1:<id>:<folders>" on
--             the group channel, every guild member's shootyepgp answers
--             "A1:<id>:<Folder>=L/<ver>;<Folder>=D;<Folder>=M" (loaded /
--             installed but disabled / not installed), split over several
--             messages when long. That is certain evidence per folder and
--             beats every passive rule. Older shootyepgp versions and
--             non-guildmates stay silent: silence is never red for BCS/RAB.
-- Honest-unknown rule: silence is only "no reply" after a query window has
-- passed for a member who was in the group when the query went out;
-- before that the cell is unknown, and members who cannot answer (not in
-- the guild, a class that cannot dispel) are n/a.
-- The parsers, the evaluation and the query state machine are pure Lua 5.0
-- (dofile-loadable offline); the WoW wiring sits behind "if CreateFrame".

DopingControl = DopingControl or {}
local DC = DopingControl

DC_Addons = DC_Addons or {}
local A = DC_Addons

A.WINDOW        = 6    -- seconds a query waits for replies
A.AUTO_THROTTLE = 30   -- seconds between automatic queries
A.MAX_NAMES     = 400  -- passive-store cap (guild chatter from non-raiders)
A.RAB_SILENT    = 70   -- seconds in the raid before RABuffs silence counts
                       -- (two 30 s broadcast cycles plus margin)

-- slot ids (match DC.SLOTS_ADDONS)
A.SLOT_IDS = { "BIGWIGS", "TWT", "EPGP", "SUPERWOW", "RINSE", "RABUFFS", "BCS" }

A.DISPELLERS = {
    DRUID = true, PRIEST = true, PALADIN = true, SHAMAN = true, MAGE = true,
}

-- prefix -> slot (hash lookup = the whole cost of an unrelated message)
local PREFIX_SLOT = {
    ["BigWigs"]      = "BIGWIGS",
    ["TWT"]          = "TWT",
    ["Rinse"]        = "RINSE",
    ["SEPGP_PREFIX"] = "EPGP",
    ["SWOW_R"]       = "SUPERWOW",
    ["RAB/BT"]       = "RABUFFS",
    ["RAB/V"]        = "RABUFFS",
    ["RAB/VC"]       = "RABUFFS",
    ["bcs"]          = "BCS",
    ["ADDONCHECK"]   = "CHECK",   -- responder answers, own parser
}
A.PREFIXES = PREFIX_SLOT

-- ADDONCHECK protocol: folder name (as on the client) -> column
A.CHECK_PREFIX = "ADDONCHECK"
A.CHECK_NAMES = { "BigWigs", "TWThreat", "shootyepgp", "UpsiRinse", "Rinse",
                  "RABuffs", "BetterCharacterStats" }
local CHECK_SLOT = {
    BigWigs = "BIGWIGS", TWThreat = "TWT", shootyepgp = "EPGP",
    UpsiRinse = "RINSE", Rinse = "RINSE", RABuffs = "RABUFFS",
    BetterCharacterStats = "BCS",
}
local CHECK_CHANNEL = { RAID = true, PARTY = true, GUILD = true, BATTLEGROUND = true }

-- passive store: A.data[name][slot] = entry
A.data = {}
A.dataCount = 0

-- roster time: A.since[name] = when the name was first seen in the group
-- (feeds the RABuffs "not seen" rule)
A.since = {}

-- responder store: A.resp[name][folder] = { s = "L"|"D"|"M", ver = text|nil }
-- (evicted with the roster in Prune, capped like the passive store)
A.resp = {}
A.respCount = 0
A.checkId = nil      -- id of the ADDONCHECK query in flight (answers to any
                     -- other id are ignored)
A.checkSeq = 0       -- survives Reset so ids never repeat inside a session

-- query state
A.query = { at = nil, sent = {}, roster = {} }
A.lastStatus = nil   -- last StartQuery verdict text (shown next to the button)

-- ------------------------------------------------------------------
-- text + version helpers
-- ------------------------------------------------------------------

-- Reply text from other people goes into UI strings: drop colour escapes,
-- trailing "<...>" decorations, control characters, and cap the length.
function A.Clean(s)
    if type(s) ~= "string" then
        return nil
    end
    s = string.gsub(s, "|", "")
    s = string.gsub(s, "[%c]", "")
    s = string.gsub(s, "%s*<.*>%s*$", "")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    if string.len(s) > 24 then
        s = string.sub(s, 1, 24)
    end
    if s == "" then
        return nil
    end
    return s
end

-- "r4521" / "v1.2.3" / "1.10.0" -> { 4521 } / { 1, 2, 3 } / { 1, 10, 0 };
-- anything else -> nil (shown raw, never compared).
function A.Segments(text)
    if type(text) ~= "string" then
        return nil
    end
    local s = string.gsub(text, "^[rRvV]", "")
    if not string.find(s, "^%d+$") and not string.find(s, "^%d+%.[%d%.]*%d$") then
        return nil
    end
    if string.find(s, "%.%.") then
        return nil
    end
    local out = {}
    for d in string.gfind(s, "(%d+)") do
        table.insert(out, tonumber(d))
    end
    return out
end

-- numeric segment compare, missing segments count as 0: -1 / 0 / 1
function A.Compare(a, b)
    local na, nb = table.getn(a), table.getn(b)
    local n = na
    if nb > n then
        n = nb
    end
    for i = 1, n do
        local x, y = a[i] or 0, b[i] or 0
        if x < y then
            return -1
        elseif x > y then
            return 1
        end
    end
    return 0
end

local function entry(text, variant, raw, channel)
    return {
        text = text,
        ver = A.Segments(text),
        variant = variant,
        raw = raw,
    }
end

-- ------------------------------------------------------------------
-- reply parsers. Each returns an entry table or nil (not a reply);
-- a second return value "query" marks the query messages themselves.
-- ------------------------------------------------------------------

function A.ParseBigWigs(msg)
    if type(msg) ~= "string" then
        return nil
    end
    local _, _, sync, rest = string.find(msg, "^(%S+)%s*(.*)$")
    if not sync then
        return nil
    end
    if sync == "BWVQ" then
        return nil, "query"
    end
    if not string.find(sync, "BWVR") then
        -- some other BigWigs sync (boss engaged, ...): presence, no version
        local e = entry("yes", nil, msg)
        e.presenceOnly = true
        return e
    end
    local rev, fork
    if string.find(rest, ":") then
        -- old style "MC:1234 BWL:1234": the highest number is the revision
        for d in string.gfind(rest, "(%d+)") do
            local n = tonumber(d)
            if rev == nil or n > rev then
                rev = n
            end
        end
        fork = "Legacy"
    elseif tonumber(rest) then
        rev = tonumber(rest)
        fork = "Legacy"
    else
        local f1, f2, f3
        local _, _, a, b, c = string.find(rest, "^(%S*)%s*(%S*)%s*(%S*)")
        f1, f2, f3 = a, b, c
        rev = tonumber(f1)
        if f3 and f3 ~= "" then
            fork = A.Clean(f3)
        elseif sync == "PEPO_BWVR" then
            fork = "Pepo"
        else
            fork = "unknown"
        end
    end
    if rev == nil or rev < 0 then
        -- reply without a usable revision (zone unknown): BigWigs is there
        local e = entry("yes", fork, msg)
        e.presenceOnly = true
        return e
    end
    return entry("r" .. rev, fork, msg)
end

function A.ParseTWT(msg)
    if type(msg) ~= "string" then
        return nil
    end
    if string.find(msg, "^TWT_WHO") then
        return nil, "query"
    end
    local _, _, v = string.find(msg, "^TWT_ME:(.+)$")
    if not v then
        _, _, v = string.find(msg, "^TWTVersion:(.+)$")
    end
    v = A.Clean(v)
    if not v then
        return nil
    end
    return entry(v, nil, msg)
end

function A.ParseRinse(msg)
    if type(msg) ~= "string" then
        return nil
    end
    if msg == "REPORT_ADDON_VERSION" then
        return nil, "query"
    end
    local _, _, v = string.find(msg, "^V_(.+)$")
    v = A.Clean(v)
    if not v then
        return nil
    end
    return entry(v, nil, msg)
end

function A.ParseEPGP(msg)
    if type(msg) ~= "string" then
        return nil
    end
    local _, _, v = string.find(msg, "^VERSION;([^;]+)")
    v = A.Clean(v)
    if v then
        return entry(v, nil, msg)
    end
    if string.find(msg, ";") then
        -- any other shootyepgp traffic (EP awards, ...) proves it runs
        local e = entry("yes", nil, msg)
        e.presenceOnly = true
        return e
    end
    return nil
end

-- "1" -> present, "0" -> absent; anything else is not an answer
function A.ParseSwow(msg)
    if msg == "1" then
        local e = entry("yes", nil, msg)
        e.flag = true
        return e
    elseif msg == "0" then
        local e = entry("no", nil, msg)
        e.flag = false
        return e
    end
    return nil
end

-- RABuffs. "RAB/V" payload "<ver> <deci>" (pattern RABuffs itself uses)
-- gives the version; a "RAB/BT" payload is "<key> <number>" pairs and only
-- proves presence. Anything else is ignored.
function A.ParseRABuffs(msg)
    if type(msg) ~= "string" then
        return nil
    end
    local _, _, v = string.find(msg, "^([%w.]+) %d+[.,]%d+%s*$")
    v = A.Clean(v)
    if v then
        return entry(v, nil, msg)
    end
    if not string.find(msg, "^%a%w+ %d+") then
        return nil
    end
    -- every byte must belong to a pair, else it is not a broadcast
    local rest = string.gsub(msg, "%a%w+ %d+", "")
    if string.find(rest, "%S") then
        return nil
    end
    local e = entry("yes", nil, msg)
    e.presenceOnly = true
    return e
end

-- BetterCharacterStats: only "TREE,<name>[,<bonus>]" exists
function A.ParseBCS(msg)
    if type(msg) ~= "string" or not string.find(msg, "^TREE,") then
        return nil
    end
    local e = entry("yes", nil, msg)
    e.presenceOnly = true
    return e
end

local PARSER = {
    BIGWIGS  = A.ParseBigWigs,
    TWT      = A.ParseTWT,
    RINSE    = A.ParseRinse,
    EPGP     = A.ParseEPGP,
    SUPERWOW = A.ParseSwow,
    RABUFFS  = A.ParseRABuffs,
    BCS      = A.ParseBCS,
}

-- ------------------------------------------------------------------
-- passive store
-- ------------------------------------------------------------------
local function put(name, slot, e, now)
    local byName = A.data[name]
    if not byName then
        if A.dataCount >= A.MAX_NAMES then
            A.data = {}
            A.dataCount = 0
        end
        byName = {}
        A.data[name] = byName
        A.dataCount = A.dataCount + 1
    end
    local old = byName[slot]
    -- a presence-only hint never replaces a real version
    if e.presenceOnly and old and not old.presenceOnly then
        return false
    end
    e.at = now
    byName[slot] = e
    return true
end

-- OnAddonMessage(prefix, msg, channel, sender, now) -> changed (bool)
-- Early return on an unrelated prefix: one table lookup, no allocation.
function A.OnAddonMessage(prefix, msg, channel, sender, now)
    local slot = PREFIX_SLOT[prefix]
    if not slot or type(sender) ~= "string" or sender == A.own then
        return false
    end
    if slot == "CHECK" then
        return A.OnCheckAnswer(msg, channel, sender, now)
    end
    -- BigWigs itself only honours its syncs on RAID
    if slot == "BIGWIGS" and channel ~= "RAID" then
        return false
    end
    local e = PARSER[slot](msg)
    if not e then
        return false
    end
    e.channel = channel
    local changed = put(sender, slot, e, now)
    if slot == "SUPERWOW" then
        -- the responder lives inside shootyepgp: an answer proves it
        local p = entry("yes", nil, msg)
        p.presenceOnly = true
        p.channel = channel
        if put(sender, "EPGP", p, now) then
            changed = true
        end
    end
    return changed
end

-- Build the query text for a fresh id (alphanumeric only) and remember it.
function A.NewCheckQuery(now)
    A.checkSeq = A.checkSeq + 1
    local id = "d" .. string.format("%x", math.mod(math.floor((now or 0) * 1000), 1048576))
        .. "x" .. string.format("%x", A.checkSeq)
    A.checkId = id
    return "Q1:" .. id .. ":" .. table.concat(A.CHECK_NAMES, ",")
end

-- Parse "A1:<id>:<Folder>=L/<ver>;<Folder>=D;..." -> id, list of
-- { folder, s, ver } or nil. Strict: one malformed part drops the message.
-- Folders we never asked about are skipped.
function A.ParseCheckAnswer(msg)
    if type(msg) ~= "string" or string.len(msg) > 255 then
        return nil
    end
    local _, _, id, list = string.find(msg, "^A1:(%w+):(.+)$")
    if not id then
        return nil
    end
    local out = {}
    for part in string.gfind(list, "([^;]+)") do
        local _, _, folder, st, rest = string.find(part, "^([%w_%-%.]+)=([LDM])(.*)$")
        if not folder then
            return nil
        end
        local ver
        if st == "L" then
            local _, _, v = string.find(rest, "^/(.*)$")
            if not v then
                return nil
            end
            v = A.Clean(v)
            if v and v ~= "?" then
                ver = v
            end
        elseif rest ~= "" then
            return nil
        end
        if CHECK_SLOT[folder] then
            table.insert(out, { folder = folder, s = st, ver = ver })
        end
    end
    return id, out
end

-- responder answer -> store. Returns changed (bool).
function A.OnCheckAnswer(msg, channel, sender, now)
    if not CHECK_CHANNEL[channel] or not A.checkId then
        return false
    end
    local id, list = A.ParseCheckAnswer(msg)
    if not id or id ~= A.checkId or table.getn(list) == 0 then
        return false
    end
    local byName = A.resp[sender]
    if not byName then
        if A.respCount >= A.MAX_NAMES then
            A.resp = {}
            A.respCount = 0
        end
        byName = {}
        A.resp[sender] = byName
        A.respCount = A.respCount + 1
    end
    for i = 1, table.getn(list) do
        local r = list[i]
        byName[r.folder] = { s = r.s, ver = r.ver, at = now }
    end
    return true
end

-- Responder verdict for one cell: nil (no answer) | { present = entry } |
-- { missing = why }. Rinse counts present when either fork is loaded and
-- missing only when both forks answered D/M.
function A.ResponderState(name, slot)
    local byName = A.resp[name]
    if not byName then
        return nil
    end
    local want, got, disabled = 0, 0, false
    for i = 1, table.getn(A.CHECK_NAMES) do
        local folder = A.CHECK_NAMES[i]
        if CHECK_SLOT[folder] == slot then
            want = want + 1
            local r = byName[folder]
            if r then
                got = got + 1
                if r.s == "L" then
                    local e = entry(r.ver or "yes", nil, "addoncheck " .. folder .. "=L")
                    if not r.ver then
                        e.presenceOnly = true
                    end
                    e.at = r.at
                    e.responder = true
                    return { present = e }
                elseif r.s == "D" then
                    disabled = true
                end
            end
        end
    end
    if want == 0 or got < want then
        return nil
    end
    return { missing = disabled and "installed but disabled (shootyepgp addon check)"
        or "not installed (shootyepgp addon check)" }
end

-- drop everybody not in the given name set (members who left)
function A.Prune(nameSet)
    for name in pairs(A.data) do
        if not nameSet[name] then
            A.data[name] = nil
            A.dataCount = A.dataCount - 1
        end
    end
    for name in pairs(A.resp) do
        if not nameSet[name] then
            A.resp[name] = nil
            A.respCount = A.respCount - 1
        end
    end
end

-- Remember when each roster name first appeared; forget names that left.
-- names = array of member names.
function A.NoteRoster(names, now)
    local set = {}
    for i = 1, table.getn(names) do
        local nm = names[i]
        set[nm] = true
        if not A.since[nm] then
            A.since[nm] = now
        end
    end
    for nm in pairs(A.since) do
        if not set[nm] then
            A.since[nm] = nil
        end
    end
end

function A.Reset()
    A.data = {}
    A.dataCount = 0
    A.since = {}
    A.resp = {}
    A.respCount = 0
    A.checkId = nil
    A.query = { at = nil, sent = {}, roster = {} }
    A.lastStatus = nil
end

-- ------------------------------------------------------------------
-- query
-- env = { now, inCombat, raid, party, guild, send(prefix, msg, channel),
--         roster = array of names }
-- StartQuery(env, auto) -> started (bool), reason (string|nil)
-- ------------------------------------------------------------------
function A.StartQuery(env, auto)
    local q = A.query
    if env.inCombat then
        A.lastStatus = "not in combat"
        return false, "in combat"
    end
    if q.at and env.now - q.at < A.WINDOW then
        return false, "query running"
    end
    if auto and q.at and env.now - q.at < A.AUTO_THROTTLE then
        return false, "throttled"
    end
    if not env.raid and not env.party then
        A.lastStatus = "not in a group"
        return false, "no group"
    end
    local send = env.send
    local chan = env.raid and "RAID" or "PARTY"
    local sent = {}
    if env.raid then
        pcall(send, "BigWigs", "BWVQ BigWigs", "RAID")
        sent.BIGWIGS = true
    end
    pcall(send, "TWT", "TWT_WHO", chan)
    sent.TWT = true
    pcall(send, "Rinse", "REPORT_ADDON_VERSION", chan)
    sent.RINSE = true
    -- one responder query on the same group channel (shootyepgp answers)
    pcall(send, A.CHECK_PREFIX, A.NewCheckQuery(env.now), chan)
    if env.guild then
        pcall(send, "SWOW_Q", "1", "GUILD")
        sent.SUPERWOW = true
        sent.EPGP = true
    end
    local roster = {}
    local names = env.roster or {}
    for i = 1, table.getn(names) do
        roster[names[i]] = true
    end
    A.query = { at = env.now, sent = sent, roster = roster }
    A.lastStatus = nil
    return true
end

-- AutoCheck: the throttled variant used when the tab is opened
function A.AutoCheck(env)
    return A.StartQuery(env, true)
end

function A.IsSilent(name, slot, now)
    local q = A.query
    if not q.at or not q.sent[slot] or not q.roster[name] then
        return false
    end
    return now >= q.at + A.WINDOW
end

-- ------------------------------------------------------------------
-- own row: local knowledge instead of replies (several addons never
-- answer their own sender).
-- g = { loaded = function(name) -> bool, meta = function(addon, field),
--       bigwigsRev = number|nil, twtVer = string|nil, superwow = any }
-- returns slot -> entry | false (known not installed)
-- ------------------------------------------------------------------
function A.LocalEntries(g)
    local out = {}
    local function mk(text, variant)
        local e = entry(A.Clean(text) or "yes", variant, "local")
        e.islocal = true
        return e
    end
    -- BigWigs
    if g.loaded("BigWigs") then
        local rev = g.bigwigsRev or tonumber(g.meta("BigWigs", "X-Revision"))
        local fork = A.Clean(g.meta("BigWigs", "X-Fork"))
        if rev and rev > 0 then
            out.BIGWIGS = mk("r" .. rev, fork or "unknown")
        else
            out.BIGWIGS = mk("yes", fork or "unknown")
            out.BIGWIGS.presenceOnly = true
        end
    else
        out.BIGWIGS = false
    end
    -- threat meter
    if g.twtVer then
        out.TWT = mk(g.twtVer)
    elseif g.loaded("TWThreat") then
        out.TWT = mk(g.meta("TWThreat", "Version") or "yes")
    else
        out.TWT = false
    end
    -- shootyepgp
    if g.loaded("shootyepgp") then
        out.EPGP = mk(g.meta("shootyepgp", "Version") or "yes")
    else
        out.EPGP = false
    end
    -- SuperWoW: a global the DLL sets, no version needed
    if g.superwow then
        local e = mk("yes")
        e.flag = true
        out.SUPERWOW = e
    else
        local e = mk("no")
        e.flag = false
        out.SUPERWOW = e
    end
    -- Rinse (the fork first: it is the one that answers queries)
    if g.loaded("UpsiRinse") then
        out.RINSE = mk(g.meta("UpsiRinse", "Version") or "yes")
    elseif g.loaded("Rinse") then
        out.RINSE = mk(g.meta("Rinse", "Version") or "yes")
    else
        out.RINSE = false
    end
    -- RABuffs / BetterCharacterStats: only the addon list is known locally
    local function localPassive(addon)
        if not g.loaded(addon) then
            return false
        end
        local ver = g.meta(addon, "Version")
        local e = mk(ver or "yes")
        if not ver then
            e.presenceOnly = true
        end
        return e
    end
    out.RABUFFS = localPassive("RABuffs")
    out.BCS = localPassive("BetterCharacterStats")
    return out
end

-- ------------------------------------------------------------------
-- evaluation
-- ------------------------------------------------------------------

local function variantKey(e)
    return e.variant or ""
end

-- Group the present entries of one slot by fork/variant and find the
-- reference variant (most members, ties broken by name) plus the newest
-- parseable version inside each variant.
local function buildGroups(list)
    local byVar, vars = {}, {}
    for i = 1, table.getn(list) do
        local e = list[i]
        local k = variantKey(e)
        local g = byVar[k]
        if not g then
            g = { key = k, count = 0, parseable = 0, uniform = true,
                  first = e.text, best = nil }
            byVar[k] = g
            table.insert(vars, g)
        end
        g.count = g.count + 1
        if e.text ~= g.first then
            g.uniform = false
        end
        if e.ver then
            g.parseable = g.parseable + 1
            if not g.best or A.Compare(e.ver, g.best.ver) > 0 then
                g.best = e
            end
        end
    end
    local ref
    for i = 1, table.getn(vars) do
        local g = vars[i]
        if not ref or g.count > ref.count
           or (g.count == ref.count and g.key < ref.key) then
            ref = g
        end
    end
    return byVar, ref
end

-- Decide check / bang for one present entry. Returns mark, note.
local function markFor(e, byVar, ref)
    if e.flag ~= nil then
        return "check", nil   -- SuperWoW has no version
    end
    local g = byVar[variantKey(e)]
    if g ~= ref then
        local who = (e.variant and e.variant ~= "") and e.variant or "other"
        local refName = (ref.key ~= "") and ref.key or "main"
        return "bang", "fork " .. who .. " (the raid mostly runs "
            .. refName .. ", newest " .. (ref.best and ref.best.text or ref.first) .. ")"
    end
    if e.ver then
        if g.best and A.Compare(e.ver, g.best.ver) < 0 then
            return "bang", "newest in raid: " .. g.best.text
        end
        return "check", nil
    end
    -- unparseable text: fine only when nothing different is around
    if g.parseable == 0 and g.uniform then
        return "check", nil
    end
    return "bang", "version cannot be compared"
        .. (g.best and (" (newest in raid: " .. g.best.text .. ")") or "")
end

local NA_CLASS  = "this class cannot dispel, so Rinse is not expected"
local NA_GUILD  = "not in your guild - shootyepgp only talks on guild chat"
local NA_NOGLD  = "you are not in a guild - this check needs guild chat"
local CONFIRM = " Only confirmed when the player runs shootyepgp with the"
    .. " addon check."
local WHY_RAB = "No RABuffs message seen. Weak evidence only: RABuffs"
    .. " broadcasts only when the member has mana or a tracked timed buff,"
    .. " so silence does not prove it is missing." .. CONFIRM
local WHY_RAB_WAIT = "no RABuffs message yet - RABuffs broadcasts every 30 s,"
    .. " so this needs about a minute in the raid." .. CONFIRM
local WHY_BCS = "No BetterCharacterStats message seen. It rarely sends, so"
    .. " silence proves nothing." .. CONFIRM

-- Annotate(players, ctx): sets p.addons[slot] and p.addonsAnswered on every
-- player table. ctx:
--   now          clock
--   own          own character name (nil in test mode)
--   ownEntries   LocalEntries result (or nil)
--   myGuild      bool, I am in a guild
--   inGuild(p)   bool, this player is in my guild
--   lookup(p, slot) -> entry | nil
--   silent(p, slot) -> bool (queried, window over, no reply)
--   queryAt      query time (nil = nothing asked yet)
function A.Annotate(players, ctx)
    local n = table.getn(players)
    local resolved = {}     -- resolved[i][slot] = entry | false | "na" ... see below
    local lists = {}        -- present entries per slot (for the groups)
    for s = 1, table.getn(A.SLOT_IDS) do
        lists[A.SLOT_IDS[s]] = {}
    end
    local info = {}         -- info[i][slot] = { kind=..., e=..., why=... }

    for i = 1, n do
        local p = players[i]
        local row = {}
        info[i] = row
        local isOwn = ctx.own ~= nil and p.name == ctx.own and ctx.ownEntries
        for s = 1, table.getn(A.SLOT_IDS) do
            local slot = A.SLOT_IDS[s]
            local r
            local ownE = isOwn and ctx.ownEntries[slot] or nil
            local resp = (not isOwn and ctx.responder) and ctx.responder(p, slot) or nil
            if p.online == false then
                r = { kind = "unknown", why = "offline" }
            elseif ownE then
                -- own character: the local addon list is certain, so an
                -- installed addon shows even where the class rule below
                -- would call it not expected
                r = { kind = "present", e = ownE }
                if not ownE.presenceOnly then
                    table.insert(lists[slot], ownE)
                end
            elseif resp and resp.present then
                -- shootyepgp answered: certain, beats every passive rule
                r = { kind = "present", e = resp.present }
                if not resp.present.presenceOnly then
                    table.insert(lists[slot], resp.present)
                end
            elseif resp and resp.missing
                   and not (slot == "RINSE" and not A.DISPELLERS[p.class or ""]) then
                r = { kind = "missing", why = resp.missing }
            elseif slot == "RINSE" and not A.DISPELLERS[p.class or ""] then
                r = { kind = "na", why = NA_CLASS }
            elseif isOwn then
                r = { kind = "missing",
                      why = "not installed on your own character" }
            elseif (slot == "EPGP" or slot == "SUPERWOW")
                   and not ctx.inGuild(p) then
                r = { kind = "na", why = ctx.myGuild and NA_GUILD or NA_NOGLD }
            else
                local e = ctx.lookup(p, slot)
                if e then
                    r = { kind = "present", e = e }
                    if not e.presenceOnly then
                        table.insert(lists[slot], e)
                    end
                elseif slot == "RABUFFS" then
                    -- passive only: silence is weak evidence, shown as
                    -- "not seen" and only after two broadcast cycles
                    local secs = ctx.inGroupFor and ctx.inGroupFor(p)
                    if secs and secs >= A.RAB_SILENT then
                        r = { kind = "notseen", why = WHY_RAB }
                    else
                        r = { kind = "unknown", why = WHY_RAB_WAIT }
                    end
                elseif slot == "BCS" then
                    r = { kind = "unknown", why = WHY_BCS }
                elseif ctx.silent(p, slot) then
                    r = { kind = "missing" }
                else
                    local why
                    if ctx.queryAt then
                        why = "waiting for a reply, or this addon was not"
                            .. " queried in this kind of group"
                    else
                        why = "not asked yet - use Check addons"
                    end
                    r = { kind = "unknown", why = why }
                end
            end
            row[slot] = r
        end
    end

    -- newest per slot and variant
    local groups, refs = {}, {}
    for s = 1, table.getn(A.SLOT_IDS) do
        local slot = A.SLOT_IDS[s]
        if table.getn(lists[slot]) > 0 then
            groups[slot], refs[slot] = buildGroups(lists[slot])
        end
    end

    for i = 1, n do
        local p = players[i]
        local out = {}
        local answered = false
        for s = 1, table.getn(A.SLOT_IDS) do
            local slot = A.SLOT_IDS[s]
            local r = info[i][slot]
            local res
            if r.kind == "present" then
                local e = r.e
                if e.flag == false then
                    res = { status = "missing", text = e.text, raw = e.raw,
                            at = e.at, islocal = e.islocal,
                            why = e.islocal and "SuperWoW is not loaded"
                                or "shootyepgp reports: no SuperWoW" }
                    answered = true
                else
                    local mark, note, newest
                    if e.presenceOnly then
                        -- present, version unknown: fine unless somebody
                        -- else reported one to compare against
                        if refs[slot] and refs[slot].best then
                            mark = "bang"
                            newest = refs[slot].best.text
                            note = "version unknown (newest in raid: "
                                .. newest .. ")"
                        else
                            mark = "check"
                        end
                    else
                        mark, note = markFor(e, groups[slot], refs[slot])
                        local g = groups[slot][variantKey(e)]
                        newest = g.best and g.best.text or nil
                    end
                    res = { status = (mark == "check") and "ok" or "old",
                            mark = mark, text = e.text, raw = e.raw,
                            at = e.at, variant = e.variant,
                            islocal = e.islocal, note = note,
                            presenceOnly = e.presenceOnly,
                            newest = newest }
                    answered = true
                end
            elseif r.kind == "missing" then
                res = { status = "missing", why = r.why
                    or "no reply - addon missing, or an old version / fork"
                       .. " that does not answer" }
            elseif r.kind == "na" then
                res = { status = "na", why = r.why }
            elseif r.kind == "notseen" then
                res = { status = "notseen", why = r.why }
            else
                res = { status = "unknown", why = r.why }
            end
            out[slot] = res
        end
        p.addons = out
        p.addonsAnswered = answered
    end
end

-- ------------------------------------------------------------------
-- WoW wiring
-- ------------------------------------------------------------------

-- the real-game ctx: passive store + query state + guild lookup
function A.RealCtx(env)
    local now = env.now
    return {
        now = now,
        own = env.own,
        ownEntries = env.ownEntries,
        myGuild = env.myGuild,
        inGuild = env.inGuild,
        queryAt = A.query.at,
        lookup = function(p, slot)
            local byName = A.data[p.name]
            return byName and byName[slot] or nil
        end,
        silent = function(p, slot)
            return A.IsSilent(p.name, slot, now)
        end,
        responder = function(p, slot)
            return A.ResponderState(p.name, slot)
        end,
        inGroupFor = function(p)
            local since = A.since[p.name]
            return since and (now - since) or nil
        end,
    }
end

-- the simulated raid: players carry p.addonSim = { guild = bool,
-- <slot> = entry (replied) | false (queried, silent) | nil (unknown) }
function A.SimCtx(now)
    return {
        now = now,
        myGuild = true,
        queryAt = now,
        inGuild = function(p)
            return p.addonSim ~= nil and p.addonSim.guild == true
        end,
        lookup = function(p, slot)
            local v = p.addonSim and p.addonSim[slot]
            if type(v) ~= "table" then
                return nil
            end
            local e = entry(v.text, v.variant, "sim: " .. v.text)
            e.flag = v.flag
            e.presenceOnly = v.presenceOnly
            e.at = now
            return e
        end,
        silent = function(p, slot)
            return p.addonSim ~= nil and p.addonSim[slot] == false
        end,
        inGroupFor = function(p)
            -- sim: a RABUFFS = false member has been around long enough
            if p.addonSim ~= nil and p.addonSim.RABUFFS == false then
                return A.RAB_SILENT
            end
            return nil
        end,
    }
end

-- Annotate a store's players for display (called before the model builds).
function A.AnnotateStore(store, env)
    if not store or not store.players then
        return
    end
    if store.source == "sim" then
        A.Annotate(store.players, A.SimCtx(env and env.now or 0))
        return
    end
    if env and env.roster and env.now then
        A.NoteRoster(env.roster, env.now)
    end
    A.Annotate(store.players, A.RealCtx(env))
    -- evict against the live roster (not the store: before the first scan
    -- finishes the store is empty and would wipe everything)
    if env and env.roster and table.getn(env.roster) > 0 then
        local set = {}
        for i = 1, table.getn(env.roster) do
            set[env.roster[i]] = true
        end
        A.Prune(set)
    end
end

-- tooltip/age helper (pure): seconds -> "5s ago" / "2m ago" / "1h ago"
function A.AgeText(sec)
    if type(sec) ~= "number" or sec < 0 then
        return "just now"
    end
    if sec < 60 then
        return math.floor(sec) .. "s ago"
    elseif sec < 3600 then
        return math.floor(sec / 60) .. "m ago"
    end
    return math.floor(sec / 3600) .. "h ago"
end

if CreateFrame then

local function names()
    local list = {}
    local own = UnitName("player")
    if own then
        table.insert(list, own)
    end
    local nr = GetNumRaidMembers and GetNumRaidMembers() or 0
    if nr > 0 then
        list = {}
        for i = 1, nr do
            local nm = GetRaidRosterInfo(i)
            if nm then
                table.insert(list, nm)
            end
        end
    else
        local np = GetNumPartyMembers and GetNumPartyMembers() or 0
        for i = 1, np do
            local nm = UnitName("party" .. i)
            if nm then
                table.insert(list, nm)
            end
        end
    end
    return list
end

local function guildName(unit)
    if GetGuildInfo then
        return (GetGuildInfo(unit))
    end
    return nil
end

-- name -> true for raid/party members in MY guild, rebuilt per call (the
-- display refresh is event driven, not per frame)
local function guildSet()
    local set = {}
    local mine = guildName("player")
    if not mine then
        return set, false
    end
    local nr = GetNumRaidMembers and GetNumRaidMembers() or 0
    for i = 1, nr do
        local unit = "raid" .. i
        if guildName(unit) == mine then
            set[UnitName(unit)] = true
        end
    end
    local np = GetNumPartyMembers and GetNumPartyMembers() or 0
    for i = 1, np do
        local unit = "party" .. i
        if guildName(unit) == mine then
            set[UnitName(unit)] = true
        end
    end
    local own = UnitName("player")
    if own then
        set[own] = true
    end
    return set, true
end

function A.GameEnv()
    local now = GetTime()
    local nr = GetNumRaidMembers and GetNumRaidMembers() or 0
    local np = GetNumPartyMembers and GetNumPartyMembers() or 0
    local gs, inGuild = guildSet()
    local g = {
        loaded = function(name)
            return IsAddOnLoaded and IsAddOnLoaded(name) and true or false
        end,
        meta = function(addon, field)
            return GetAddOnMetadata and GetAddOnMetadata(addon, field) or nil
        end,
        bigwigsRev = (type(BigWigs) == "table") and tonumber(BigWigs.revision) or nil,
        twtVer = (type(TWT) == "table") and TWT.addonVer or nil,
        superwow = SUPERWOW_VERSION,
    }
    local own = UnitName("player")
    A.own = own
    return {
        now = now,
        raid = nr > 0,
        party = nr == 0 and np > 0,
        guild = inGuild,
        myGuild = inGuild,
        inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false,
        send = SendAddonMessage,
        roster = names(),
        own = own,
        ownEntries = A.LocalEntries(g),
        inGuild = function(p)
            return gs[p.name] == true
        end,
    }
end

-- Check addons button / tab open. Returns started, reason.
function A.Check(auto)
    local ok, env = pcall(A.GameEnv)
    if not ok then
        return false, "error"
    end
    local started, reason = A.StartQuery(env, auto)
    if started then
        A.finishAt = GetTime() + A.WINDOW + 0.3
        A.Wake()
    end
    return started, reason
end

-- one frame: passive listener + a throttled updater that repaints the tab
-- when replies came in and again when the query window ends
local listener = CreateFrame("Frame", "DopingControlAddonsEventFrame", UIParent)
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:RegisterEvent("RAID_ROSTER_UPDATE")
listener:RegisterEvent("PARTY_MEMBERS_CHANGED")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:SetScript("OnEvent", function()
    if event ~= "CHAT_MSG_ADDON" then
        A.NoteRoster(names(), GetTime())
        return
    end
    if A.OnAddonMessage(arg1, arg2, arg3, arg4, GetTime()) then
        A.dirty = true
        A.Wake()
    end
end)

local updater = CreateFrame("Frame", "DopingControlAddonsUpdateFrame", UIParent)
updater.dcT = 0
updater:Hide()
updater:SetScript("OnUpdate", function()
    this.dcT = this.dcT + arg1
    if this.dcT < 0.5 then
        return
    end
    this.dcT = 0
    local now = GetTime()
    local repaint = false
    if A.dirty then
        A.dirty = false
        repaint = true
    end
    if A.finishAt and now >= A.finishAt then
        A.finishAt = nil
        repaint = true
    end
    if repaint and DC_Matrix and DC_Matrix.RefreshAddons then
        DC_Matrix.RefreshAddons()
    end
    if not A.dirty and not A.finishAt then
        this:Hide()
    end
end)

function A.Wake()
    updater:Show()
end

end -- if CreateFrame
