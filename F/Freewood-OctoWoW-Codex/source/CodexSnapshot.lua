-- Freewood-OctoWoW-Codex: Charakter-Schnappschuss
--   Holt die Liste der erledigten Quests vom Server (Chat-Befehl ".queststatuses", Antwort als Addon-Nachricht "TWQUEST")
--   und traegt sie in die gemerkten Abgaben des Charakters ein. Dadurch stimmt der Filter "erledigt" im Codex auch fuer Charaktere,
--   die schon lange spielen. Zusaetzlich entsteht je Charakter eine Datei (SavedVariablesPerCharacter: FreewoodSnapshot)
--   mit Name, Klasse, Stufe, EP und allen erledigten Quest-IDs, zum Hochladen im Levelplaner.
--   Im Spiel ungeprueft: Verhalten bei sehr langen Listen (Stufe 60) und ob der Server die Liste ohne Befehl schickt.

local ADDON, NS = ...

local FW = _G.Freewood
local Codex = NS and NS.Codex
if not FW or not Codex then
    return
end

local Snap = {}
NS.Snapshot = Snap
Codex.Snapshot = Snap

local PREFIX = "TWQUEST"
local ASK_DELAY = 12          -- Sekunden nach dem Start, bis der Befehl gesendet wird
local MIN_GAP = 60            -- Mindestabstand zwischen zwei Abfragen
local WAIT = 20               -- so lange gilt eine Antwort als Antwort auf unsere Abfrage

local lastAsk, started = 0, false

local function Now()
    return GetTime and GetTime() or time()
end

local function Say(msg)
    if FW.Print then FW:Print(msg) elseif _G.DEFAULT_CHAT_FRAME then _G.DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Freewood|r " .. msg) end
end

local function Iter(s, pat)
    return (string.gmatch or string.gfind)(s, pat)
end

local function Turned()
    local key = Codex.Trust and Codex.Trust.SelfKey and Codex.Trust.SelfKey() or nil
    local db = Codex.db
    if not db or not key then return nil end
    db.turned = db.turned or {}
    db.turned[key] = db.turned[key] or {}
    return db.turned[key]
end

-- Stufe und EP merken, solange sie lesbar sind (beim Abmelden liefert der Client 0)
local cur = {}
function Snap:Cache()
    local lv = UnitLevel and UnitLevel("player") or 0
    if type(lv) == "number" and lv > 0 then
        cur.level = lv
        cur.xp = UnitXP and UnitXP("player") or 0
        cur.xpMax = UnitXPMax and UnitXPMax("player") or 0
        local s = _G.FreewoodSnapshot
        if s then s.level, s.xp, s.xpMax = cur.level, cur.xp, cur.xpMax end
    end
end

-- Schnappschuss schreiben (Stufe und EP immer frisch, erledigte Quests aus den gemerkten Abgaben)
function Snap:Write()
    if not _G.UnitName then return end
    local t = Turned()
    local ids = {}
    for id, v in pairs(t or {}) do
        if v and tonumber(id) then table.insert(ids, tonumber(id)) end
    end
    table.sort(ids)
    local parts = {}
    for i = 1, table.getn(ids) do parts[i] = string.format("%.0f", ids[i]) end
    local _, classToken = UnitClass("player")
    local _, raceToken = UnitRace("player")
    local old = _G.FreewoodSnapshot
    self:Cache()
    _G.FreewoodSnapshot = {
        format = 1,
        name = UnitName("player"),
        realm = GetRealmName and GetRealmName() or "",
        class = classToken,
        race = raceToken,
        classId = Codex.PlayerClassID and Codex.PlayerClassID() or nil,
        raceId = Codex.PlayerRaceID and Codex.PlayerRaceID() or nil,
        level = cur.level or (old and old.level) or 0,
        xp = cur.xp or (old and old.xp) or 0,
        xpMax = cur.xpMax or (old and old.xpMax) or 0,
        saved = time(),
        serverList = old and old.serverList or nil,   -- Zeitpunkt der letzten Serverantwort
        count = table.getn(ids),
        done = table.concat(parts, " "),
    }
end

-- Abfrage senden (hoechstens einmal je MIN_GAP)
function Snap:Ask(force)
    local now = Now()
    if not force and lastAsk > 0 and now - lastAsk < MIN_GAP then return false end
    if not SendChatMessage then return false end
    lastAsk = now
    SendChatMessage(".queststatuses", "SAY")
    return true
end

function Snap:OnAddon(prefix, text, channel, sender)
    if prefix ~= PREFIX or type(text) ~= "string" then return end
    local t = Turned()
    if not t then return end
    local n, new = 0, 0
    for num in Iter(text, "%d+") do
        local id = tonumber(num)
        if id and id > 0 then
            n = n + 1
            if not t[id] then t[id] = true new = new + 1 end
        end
    end
    if n == 0 then return end
    Snap.stats = { total = n, new = new, at = time() }
    if new > 0 then
        Codex.chainRev = (Codex.chainRev or 0) + 1
        if FW.Fire then FW:Fire("QUEST_TURNED_IN_LOCAL", 0) end
    end
    self:Write()
    if _G.FreewoodSnapshot then _G.FreewoodSnapshot.serverList = time() end
    if Snap.manual or (Now() - lastAsk) < WAIT then
        Say(string.format(FW.L.CODEX_SNAP_GOT, n, new))
        Snap.manual = nil
    end
end

function Snap:OnXp()
    self:Cache()
end

function Snap:OnLogout()
    self:Write()
end

function Snap:OnLevel()
    self:Write()
end

function Snap:Start()
    if started then return end
    started = true
    FW:RegisterEvent("CHAT_MSG_ADDON", self.OnAddon, self)
    FW:RegisterEvent("PLAYER_LOGOUT", self.OnLogout, self)
    FW:RegisterEvent("PLAYER_LEVEL_UP", self.OnLevel, self)
    FW:RegisterEvent("PLAYER_XP_UPDATE", self.OnXp, self)
    if C_Timer and C_Timer.After then
        C_Timer.After(ASK_DELAY, function()
            Snap:Write()
            Snap:Ask(false)
        end)
    end
end

function Snap:Stop()
    started = false
    FW:UnregisterEvent("CHAT_MSG_ADDON", self)
    FW:UnregisterEvent("PLAYER_LOGOUT", self)
    FW:UnregisterEvent("PLAYER_LEVEL_UP", self)
    FW:UnregisterEvent("PLAYER_XP_UPDATE", self)
end

_G.SLASH_FWSNAP1 = "/fwsnap"
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList["FWSNAP"] = function(msg)
    Snap:Write()
    Snap.manual = true
    Snap:Ask(true)
    local s = _G.FreewoodSnapshot
    Say(string.format(FW.L.CODEX_SNAP_ASK, s and s.count or 0))
end
