-- RelationshipsAttune: Comm.lua
-- Party/Raid/Guild addon-channel sync. Small, fixed-format messages so
-- we don't need a serializer library.

RelationshipsAttune = RelationshipsAttune or {}
local RA = RelationshipsAttune
RA.Comm = {}
local C  = RA.Comm

-- Message formats (all pipe-delimited, single line):
--   V|<version>                                  -> version ping
--   R                                            -> request full sync
--   S|<attId>|<doneCount>|<total>|<doneBool>     -> per-attunement status
--   D|<attId>|<b1><b2>...<bN>                    -> per-step done bits
--
-- Bits are '1'/'0' chars so we stay printable.

local function send(msg, channel, target)
    if not msg then return end
    channel = channel or "PARTY"
    if channel == "WHISPER" then
        SendAddonMessage(RA.COMM_PREFIX, msg, channel, target)
    else
        SendAddonMessage(RA.COMM_PREFIX, msg, channel)
    end
end

local function currentChannel()
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then return "RAID" end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then return "PARTY" end
    return nil
end

function C:Init()
    -- On login, broadcast a version ping and share current state.
    local ch = currentChannel()
    if ch then
        send("V|" .. RA.VERSION, ch)
        self:BroadcastAll(ch)
    end
end

function C:RequestSync()
    local ch = currentChannel()
    if not ch then RA.print("No group to sync with."); return end
    send("R", ch)
    self:BroadcastAll(ch)
end

function C:BroadcastAll(channel, target)
    channel = channel or currentChannel()
    if not channel then return end
    local data = RelationshipsAttune_Data
    for i = 1, table.getn(data) do
        local att = data[i]
        local prog = RelationshipsAttuneCharDB.progress[att.id]
        if prog and prog.applicable then
            send(string.format("S|%s|%d|%d|%d",
                att.id, prog.doneCount, prog.total, prog.done and 1 or 0),
                channel, target)
            -- pack steps
            local bits = ""
            for s = 1, prog.total do
                bits = bits .. (prog.steps[s] and "1" or "0")
            end
            send("D|" .. att.id .. "|" .. bits, channel, target)
        end
    end
end

local function ensurePlayer(sender)
    RelationshipsAttuneDB.players = RelationshipsAttuneDB.players or {}
    local key = sender  -- vanilla addon sender = "Name" (no realm)
    if not RelationshipsAttuneDB.players[key] then
        RelationshipsAttuneDB.players[key] = {
            name = sender, realm = RA.playerRealm, faction = "Unknown",
            progress = {}, updated = time and time() or 0,
        }
    end
    return RelationshipsAttuneDB.players[key]
end

function C:OnMessage(msg, channel, sender)
    if not msg or not sender then return end
    if sender == RA.playerName then return end  -- ignore self-echo

    local _, _, tag, rest = string.find(msg, "^(%a)|?(.*)$")
    if not tag then return end
    local p = ensurePlayer(sender)
    p.updated = time and time() or 0

    if tag == "V" then
        -- version ping; nothing to do beyond note
        p.version = rest

    elseif tag == "R" then
        -- someone wants my data
        self:BroadcastAll(channel, sender)

    elseif tag == "S" then
        -- S|attId|done|total|doneBool
        local _, _, attId, d, t, full = string.find(rest, "^([^|]+)|(%d+)|(%d+)|(%d+)$")
        if attId then
            p.progress = p.progress or {}
            local prog = p.progress[attId] or { steps = {} }
            prog.applicable = true
            prog.doneCount = tonumber(d) or 0
            prog.total     = tonumber(t) or 0
            prog.done      = (tonumber(full) == 1)
            p.progress[attId] = prog
        end

    elseif tag == "D" then
        -- D|attId|bits
        local _, _, attId, bits = string.find(rest, "^([^|]+)|([01]*)$")
        if attId and bits then
            p.progress = p.progress or {}
            local prog = p.progress[attId] or { steps = {}, done = false, doneCount = 0, total = string.len(bits) }
            local steps = {}
            for i = 1, string.len(bits) do
                steps[i] = (string.sub(bits, i, i) == "1")
            end
            prog.steps = steps
            prog.total = prog.total or string.len(bits)
            p.progress[attId] = prog
        end
    end

    if RA.UI and RA.UI.Refresh then RA.UI:Refresh() end
end
