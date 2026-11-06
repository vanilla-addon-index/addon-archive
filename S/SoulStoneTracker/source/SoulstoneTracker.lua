-- SoulstoneTracker
-- Tracks soulstones cast by warlocks on raid members
-- Author: Waylock

SoulstoneTracker = {}
local m = SoulstoneTracker

local SOULSTONE_DURATION = 30 * 60
-- Soulstone Resurrection spellID, confirmed live via BUFF_ADDED_OTHER
-- (nampower) during actual testing.
local SOULSTONE_SPELL_ID = 20765
local FONT      = "Fonts\\FRIZQT__.TTF"
local BASE_W    = 380
local ROW_H     = 18
local TITLE_H   = 22
local HEADER_H  = 16
local MAX_ROWS  = 10
local MIN_W     = 250
local ADDON_MSG_PREFIX = "SSTracker"

local COL_CASTER_END = 0.38
local COL_ARROW      = 0.40
local COL_TARGET_END = 0.72

-- Curse tracking
local CURSES = {
    ["Curse of the Elements"]    = "CoE",
    ["Curse of Shadow"]          = "CoS",
    ["Curse of Recklessness"]    = "CoR",
    ["Curse of Weakness"]        = "CoW",
}
local CURSE_COLORS = {
    ["CoE"] = "|cffaa00ff",  -- Purple
    ["CoS"] = "|cff0099ff",  -- Blue
    ["CoR"] = "|cffff3333",  -- Red
    ["CoW"] = "|cff00cc44",  -- Green
}
-- Curse icons - exact paths verified from GetSpellTexture in-game
local CURSE_ICONS = {
    ["CoE"] = "Interface\\Icons\\Spell_Shadow_ChillTouch",        -- Curse of the Elements
    ["CoS"] = "Interface\\Icons\\Spell_Shadow_CurseOfAchimonde",  -- Curse of Shadow
    ["CoR"] = "Interface\\Icons\\Spell_Shadow_UnholyStrength",    -- Curse of Recklessness
    ["CoW"] = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth",  -- Curse of Weakness
}
local CURSE_DIVIDER_H = 14
local CURSE_ROW_H     = 16

-- Raid target icons (texture coords in UI-RaidTargetingIcons)
local RAID_ICONS = {
    { name = "Star",     coords = {0,    0.25, 0,    0.25} },
    { name = "Circle",   coords = {0.25, 0.5,  0,    0.25} },
    { name = "Diamond",  coords = {0.5,  0.75, 0,    0.25} },
    { name = "Triangle", coords = {0.75, 1,    0,    0.25} },
    { name = "Moon",     coords = {0,    0.25, 0.25, 0.5 } },
    { name = "Square",   coords = {0.25, 0.5,  0.25, 0.5 } },
    { name = "Cross",    coords = {0.5,  0.75, 0.25, 0.5 } },
    { name = "Skull",    coords = {0.75, 1,    0.25, 0.5 } },
}

m.stones   = {}
m.curses   = {}  -- { shortName = { caster } }
m.banish   = {}  -- { warlockName = raidIconIndex }
m.shardCounts = {} -- { warlockName = count }
m.ssCooldowns = {} -- { warlockName = readyAtEpochSeconds (0/nil = ready now) }
m.history = {} -- { {text=..., time=...}, ... } session-only log

-- Reusable debounce: one persistent frame per key (frames are never freed in
-- 1.12, so creating one per event leaked). Calling again with the same key
-- restarts the delay.
do
    local frames = {}
    function m.debounce(key, delay, fn)
        local f = frames[key]
        if not f then
            f = CreateFrame("Frame")
            frames[key] = f
        end
        local e = 0
        f:SetScript("OnUpdate", function()
            e = e + arg1
            if e >= delay then
                f:SetScript("OnUpdate", nil)
                fn()
            end
        end)
    end
end
m.frame    = nil
m.settings = nil  -- settings panel frame
m.locked   = false
m.muted    = false

-- Default settings
local DEFAULTS = {
    -- Notifications
    muteChat         = false,
    muteSounds       = false,
    warnOnCast       = true,
    warnFiveMin      = true,
    warnOneMin       = true,
    warnExpired      = true,
    warnNoStones     = true,
    warnWarlocks     = true,
    -- Display
    showCurseSection  = true,
    showBanishSection = true,
    frameAlpha        = 0.95,
    hideWhenSolo      = false,
    classicTheme      = true,  -- Blizzard look; false = the original purple "Shadow" look
    -- Timing
    warnMinutes       = 5,   -- first warning threshold in minutes
    warnSeconds       = 60,  -- second warning threshold in seconds
    -- Announce
    announceOnCast   = true,
    announceExpired  = true,
    announceWarnings = true,
    announceCurse    = true,
    announceBanish   = true,
}

m.cfg = {}

-------------------------------------------------------------------------------
-- Config helpers
-------------------------------------------------------------------------------

local function cfg(key)
    if m.cfg[key] == nil then return DEFAULTS[key] end
    return m.cfg[key]
end

local function setCfg(key, val)
    m.cfg[key] = val
    if SoulstoneTrackerDB then
        SoulstoneTrackerDB.cfg = m.cfg
    end
end

-- English class token ("WARLOCK"), so it works on any client language
local function playerIsWarlock()
    local _, class = UnitClass("player")
    return class == "WARLOCK"
end

-- Key for per-character settings stored in the account-wide saved variables
local function charKey()
    return (UnitName("player") or "?").."-"..(GetRealmName() or "?")
end

-------------------------------------------------------------------------------
-- Themes
-------------------------------------------------------------------------------
-- The theme is read once when the windows are built (PLAYER_LOGIN), so
-- switching it asks for a /reload, same as the other reload-only settings.
--
--   classic: the stock Blizzard look -- tooltip-style panel (Bagshui's neutral
--            dark fill and light border) for the tracker, the marbled dialog box with the gold
--            header plate for settings, gold titles, drop-shadow text instead
--            of outlines, silver rules that fade out at the ends, quest-log
--            hover glow on rows, and stock checkboxes / buttons / close button.
--   shadow:  the original flat dark window with the purple title bar.

local THEMES = {
    shadow = {
        classic     = false,
        inset       = 1,                       -- gap between edge and content
        padBottom   = 0,
        bg          = { 0.05, 0.05, 0.08 },
        border      = { 0.25, 0.25, 0.35 },
        titleHex    = "|cffffd700",
        headerColor = { 0.85, 0.85, 0.85 },
        sectionColor= { 0.6, 0.6, 0.6 },
        emptyColor  = { 0.4, 0.4, 0.4 },
        rule        = { 0.3, 0.15, 0.5, 0.8 },
        stripe      = 0.04,
    },
    classic = {
        classic     = true,
        inset       = 4,
        padBottom   = 4,
        -- same neutral window colors as Bagshui's defaults (windowBackground /
        -- windowBorder), so the tracker matches it instead of the navy tooltip tint
        bg          = { 0.090, 0.085, 0.090 },
        border      = { 0.900, 0.850, 0.900 },
        titleHex    = "|cffffd100",            -- NORMAL_FONT_COLOR
        headerColor = { 1, 0.82, 0 },
        sectionColor= { 1, 0.82, 0 },
        emptyColor  = { 0.5, 0.5, 0.5 },
        rule        = { 0.8, 0.8, 0.8, 0.6 },
        stripe      = 0.03,
    },
}

local function theme()
    if cfg("classicTheme") then return THEMES.classic end
    return THEMES.shadow
end

-- Set a font in the active theme's style: classic text has the stock 1px
-- drop shadow and no outline, the shadow theme keeps its thin outline.
local function styleFont(fs, size, T)
    T = T or theme()
    if T.classic then
        fs:SetFont(FONT, size, "")
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetFont(FONT, size, "OUTLINE")
    end
end

-- A 1px horizontal rule as a frame (so callers can ClearAllPoints / SetPoint
-- / Show / Hide it like the plain texture it replaces). Classic: a silver
-- line that fades out toward both ends. Shadow: a solid purple line.
local function makeRule(parent, T)
    T = T or theme()
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(1)
    local c = T.rule
    if T.classic then
        local L = r:CreateTexture(nil, "ARTWORK")
        local R = r:CreateTexture(nil, "ARTWORK")
        L:SetTexture("Interface\\Buttons\\WHITE8X8")
        R:SetTexture("Interface\\Buttons\\WHITE8X8")
        L:SetPoint("TopLeft", r, "TopLeft", 0, 0)
        L:SetPoint("BottomRight", r, "Bottom", 0, 0)
        R:SetPoint("TopLeft", r, "Top", 0, 0)
        R:SetPoint("BottomRight", r, "BottomRight", 0, 0)
        L:SetGradientAlpha("HORIZONTAL", c[1], c[2], c[3], 0, c[1], c[2], c[3], c[4])
        R:SetGradientAlpha("HORIZONTAL", c[1], c[2], c[3], c[4], c[1], c[2], c[3], 0)
    else
        local t = r:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints(r)
        t:SetTexture(c[1], c[2], c[3], c[4])
    end
    return r
end

-- Same as makeRule but the line only fades out to the right: used beside a
-- section label ("Label ———") so it never runs through the text.
local function makeTrailingRule(parent, T)
    T = T or theme()
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(1)
    local c = T.rule
    local t = r:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(r)
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetGradientAlpha("HORIZONTAL", c[1], c[2], c[3], c[4], c[1], c[2], c[3], 0)
    return r
end

-------------------------------------------------------------------------------
-- Utility
-------------------------------------------------------------------------------

local function timeLeft(expires)
    return math.max(0, expires - time())
end

local function formatTime(secs)
    if secs <= 0 then
        return "|cffff3333EXPIRED|r"
    elseif secs <= 300 then
        return "|cffff7c0a"..string.format("%dm %02ds", math.floor(secs/60), math.mod(secs,60)).."|r"
    else
        return "|cff00ff98"..string.format("%dm %02ds", math.floor(secs/60), math.mod(secs,60)).."|r"
    end
end

local function say(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffa050ff[SS]|r " .. msg)
end

-- Look up a name's class from raid/party/player roster and return the name
-- wrapped in that class's color code. Falls back to defaultColorCode (a
-- hex string like "|cffa050ff") if the class can't be determined (e.g. an
-- "Unknown" caster from a scan, or someone who's left the group).
local function classColorName(name, defaultColorCode)
    local class = nil
    if name == UnitName("player") then
        local _, c = UnitClass("player")
        class = c
    else
        local numRaid = GetNumRaidMembers()
        if numRaid > 0 then
            for i = 1, numRaid do
                local n, _, _, _, c = GetRaidRosterInfo(i)
                if n == name then class = c break end
            end
        else
            for i = 1, GetNumPartyMembers() do
                if UnitName("party"..i) == name then
                    local _, c = UnitClass("party"..i)
                    class = c
                    break
                end
            end
        end
    end
    if class and RAID_CLASS_COLORS[string.upper(class)] then
        local c = RAID_CLASS_COLORS[string.upper(class)]
        return string.format("|cff%02x%02x%02x", c.r*255, c.g*255, c.b*255)..name.."|r"
    end
    return (defaultColorCode or "|cffffffff")..name.."|r"
end

local function sendGroup(msg)
    if cfg("muteChat") then return end
    if GetNumRaidMembers() > 0 then
        SendChatMessage(msg, "RAID")
    elseif GetNumPartyMembers() > 0 then
        SendChatMessage(msg, "PARTY")
    end
end

local function playSound(sound)
    if not cfg("muteSounds") then PlaySound(sound) end
end

local function hasActiveStones()
    for _ in pairs(m.stones) do return true end
    return false
end

local function getWarlocksMissingStones()
    local missing = {}
    -- Build set of targets who have a stone
    local coveredTargets = {}
    for target in pairs(m.stones) do
        coveredTargets[target] = true
    end
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local name, _, _, _, class = GetRaidRosterInfo(i)
            if name and class == "Warlock" and not coveredTargets[name] then
                -- Check if they've cast on anyone
                local hasCast = false
                for _, data in pairs(m.stones) do
                    if data.caster == name then hasCast = true break end
                end
                if not hasCast then table.insert(missing, name) end
            end
        end
    else
        for i = 1, GetNumPartyMembers() do
            local name = UnitName("party"..i)
            local class = UnitClass("party"..i)
            if name and class == "Warlock" and not coveredTargets[name] then
                local hasCast = false
                for _, data in pairs(m.stones) do
                    if data.caster == name then hasCast = true break end
                end
                if not hasCast then table.insert(missing, name) end
            end
        end
        -- Check self
        local myClass = UnitClass("player")
        local myName = UnitName("player")
        if myClass == "Warlock" and not coveredTargets[myName] then
            local hasCast = false
            for _, data in pairs(m.stones) do
                if data.caster == myName then hasCast = true break end
            end
            if not hasCast then table.insert(missing, myName) end
        end
    end
    return missing
end

-------------------------------------------------------------------------------
-- Persistence
-------------------------------------------------------------------------------

local function saveAll()
    if not SoulstoneTrackerDB then return end
    local now = time()
    -- Save stones
    local saved = {}
    for target, data in pairs(m.stones) do
        if data.expires > now then
            saved[target] = { caster=data.caster, expires=data.expires, castTime=data.castTime or now, warnedFiveMin=data.warnedFiveMin, warnedOneMin=data.warnedOneMin }
        end
    end
    SoulstoneTrackerDB.stones = saved
    -- Save curses
    SoulstoneTrackerDB.curses = m.curses
    -- Save banish
    SoulstoneTrackerDB.banish = m.banish
end

local function loadAll()
    if not SoulstoneTrackerDB then return end
    -- Load stones
    if SoulstoneTrackerDB.stones then
        local now = time()
        for target, data in pairs(SoulstoneTrackerDB.stones) do
            if data.expires > now then
                m.stones[target] = { caster=data.caster, expires=data.expires, castTime=data.castTime or now, warnedFiveMin=data.warnedFiveMin or false, warnedOneMin=data.warnedOneMin or false }
            end
        end
        SoulstoneTrackerDB.stones = nil
    end
    -- Load curses
    if SoulstoneTrackerDB.curses then
        m.curses = SoulstoneTrackerDB.curses
        SoulstoneTrackerDB.curses = nil
    end
    -- Load banish
    if SoulstoneTrackerDB.banish then
        m.banish = SoulstoneTrackerDB.banish
        SoulstoneTrackerDB.banish = nil
    end
end

-------------------------------------------------------------------------------
-- Raid Sync
-------------------------------------------------------------------------------

local function broadcastStone(target, caster, expires)
    local msg = "ADD:"..target..":"..caster..":"..expires
    if GetNumRaidMembers() > 0 then
        SendAddonMessage(ADDON_MSG_PREFIX, msg, "RAID")
    elseif GetNumPartyMembers() > 0 then
        SendAddonMessage(ADDON_MSG_PREFIX, msg, "PARTY")
    end
end

local function broadcastRemove(target)
    local msg = "REM:"..target
    if GetNumRaidMembers() > 0 then
        SendAddonMessage(ADDON_MSG_PREFIX, msg, "RAID")
    elseif GetNumPartyMembers() > 0 then
        SendAddonMessage(ADDON_MSG_PREFIX, msg, "PARTY")
    end
end

-------------------------------------------------------------------------------
-- Tracking
-------------------------------------------------------------------------------

function m.addStone(target, caster, expires, silent, unknownExpiry)
    local exp = expires or (time() + SOULSTONE_DURATION)
    m.stones[target] = { caster=caster, expires=exp, castTime=time(), warnedFiveMin=false, warnedOneMin=false, unknownExpiry=unknownExpiry or false }
    if not silent then
        say("|cffa050ff"..caster.."|r soulstoned |cffffffff"..target.."|r")
        if cfg("warnOnCast") then playSound("SPELLBOOKCLOSE") end
        broadcastStone(target, caster, exp)
        if cfg("announceOnCast") then
            sendGroup("[Soulstone] "..caster.." -> "..target.." (30 min)")
        end
        m.logHistory(caster.." soulstoned "..target)
    end
    m.refresh()
end

function m.removeStone(target, silent)
    if m.stones[target] then
        m.stones[target] = nil
        if not silent then broadcastRemove(target) end
        m.refresh()
    end
end

function m.clearExpired()
    local now = time()
    local changed = false
    for target, data in pairs(m.stones) do
        local secs = data.expires - now
        -- First warning (configurable, default 5 min)
        local firstWarnSecs = cfg("warnMinutes") * 60
        if not data.warnedFiveMin and secs <= firstWarnSecs and secs > 0 then
            data.warnedFiveMin = true
            if cfg("warnFiveMin") then
                say("|cffff7c0a[WARNING]|r Soulstone on |cffffffff"..target.."|r expires in "..cfg("warnMinutes").." minutes!")
                playSound("RAID_WARNING")
                -- Only the actual caster's client broadcasts to raid chat --
                -- every client independently evaluates the same synced
                -- data on the same timer, so without this every warlock
                -- running the addon would announce identically at once.
                if cfg("announceWarnings") and data.caster == UnitName("player") then
                    sendGroup("[Soulstone] WARNING: "..target.."'s soulstone expires in "..cfg("warnMinutes").." minutes!")
                end
            end
            m.refresh()
        end
        -- Second warning (configurable, default 60 sec)
        local secondWarnSecs = cfg("warnSeconds")
        if not data.warnedOneMin and secs <= secondWarnSecs and secs > 0 then
            data.warnedOneMin = true
            if cfg("warnOneMin") then
                say("|cffff3333[WARNING]|r Soulstone on |cffffffff"..target.."|r expires in "..cfg("warnSeconds").." seconds!")
                playSound("RAID_WARNING")
                if cfg("announceWarnings") and data.caster == UnitName("player") then
                    sendGroup("[Soulstone] WARNING: "..target.."'s soulstone expires in "..cfg("warnSeconds").." seconds!")
                end
            end
            m.refresh()
        end
        -- Expired
        if now >= data.expires then
            if cfg("warnExpired") then
                say("|cffff3333[WARNING]|r Soulstone expired on |cffffffff"..target.."|r")
                playSound("LOOTCLOSE")
                if cfg("announceExpired") and data.caster == UnitName("player") then
                    sendGroup("[Soulstone] "..target.."'s soulstone has expired!")
                end
            end
            m.stones[target] = nil
            changed = true
        end
    end
    if changed then
        m.refresh()
        if not hasActiveStones() and cfg("warnNoStones") then
            say("|cffff3333[WARNING]|r No active soulstones in the raid!")
            playSound("RAID_WARNING")
            if cfg("warnWarlocks") then
                local missing = getWarlocksMissingStones()
                if table.getn(missing) > 0 then
                    say("|cffff7c0aWarlocks with available SS: |cffffffff"..table.concat(missing, ", ").."|r")
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Buff Scan
-------------------------------------------------------------------------------

function m.scanForSoulstones(silent)
    local units = {}
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do table.insert(units, "raid"..i) end
    else
        table.insert(units, "player")
        for i = 1, GetNumPartyMembers() do table.insert(units, "party"..i) end
    end
    local found = 0
    for _, unit in ipairs(units) do
        local name = UnitName(unit)
        if name then
            local i = 1
            while true do
                local tex = UnitBuff(unit, i)
                if not tex then break end
                if string.find(tex, "Spell_Shadow_SoulGem") then
                    if not m.stones[name] then
                        m.addStone(name, "Unknown", nil, true, true)
                        found = found + 1
                    end
                end
                i = i + 1
            end
        end
    end
    if found > 0 then
        say("Found "..found.." existing soulstone(s) on group members.")
        m.refresh()
    elseif not silent then
        say("No soulstones found on group members.")
    end
end

-- Rebroadcasts everything we confidently know (soulstones, banish
-- assignments, curses) to the group. Used both when responding to someone
-- else's SYNCREQ, and as the basis for a manual force-resync.
-- Counts Soul Shards in the local player's bags by matching the item's
-- icon texture (same robust substring approach used for soulstone/curse
-- detection, rather than relying on item-ID APIs that may not exist here).
function m.countShards()
    local count = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        if slots and slots > 0 then
            for slot = 1, slots do
                local texture, itemCount = GetContainerItemInfo(bag, slot)
                if texture and string.find(texture, "INV_Misc_Gem_Amethyst_02", 1, true) then
                    count = count + (itemCount or 1)
                end
            end
        end
    end
    return count
end

-- Rescans and broadcasts our own shard count if it changed since last
-- broadcast, so we don't spam the addon channel on every bag update.
local lastBroadcastShardCount = nil
function m.updateAndBroadcastShards()
    local count = m.countShards()
    m.shardCounts[UnitName("player")] = count
    if count ~= lastBroadcastShardCount then
        lastBroadcastShardCount = count
        local channel = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
        if channel then
            SendAddonMessage(ADDON_MSG_PREFIX, "SHARDS:"..count, channel)
        end
    end
    m.refreshBanish()
end

-- Tracks the soulstone-USE cooldown (separate from a stone's 30-min
-- duration on the target -- this is whether the warlock can use/make a NEW
-- one right now). Confirmed via in-game tooltip: using a soulstone puts a
-- fixed 30-min cooldown on it. Five different Blizzard/nampower cooldown
-- APIs were all tried and all failed against a real, tooltip-confirmed
-- active cooldown (GetSpellIdCooldown, GetItemCooldown by name, by numeric
-- ID, GetSpellCooldown via spellbook slot, GetContainerItemCooldown) --
-- rather than keep guessing at a sixth API, this just starts our OWN
-- 30-minute timer at the exact moment we detect a real soulstone
-- application, reusing the detection logic that's already proven solid
-- all session. No API dependency, no bag-scan requirement.
local lastBroadcastReadyAt = nil
function m.startOwnSoulstoneCooldown()
    local readyAt = time() + SOULSTONE_DURATION
    m.ssCooldowns[UnitName("player")] = readyAt
    if SoulstoneTrackerDB then
        SoulstoneTrackerDB.ssReadyAt = SoulstoneTrackerDB.ssReadyAt or {}
        SoulstoneTrackerDB.ssReadyAt[UnitName("player")] = readyAt
    end
    if not lastBroadcastReadyAt or math.abs((lastBroadcastReadyAt or 0) - readyAt) > 5 then
        lastBroadcastReadyAt = readyAt
        local channel = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
        if channel then
            SendAddonMessage(ADDON_MSG_PREFIX, "SSCD:"..readyAt, channel)
        end
    end
    m.refreshBanish()
end
-- Kept as a no-op stub so the periodic ticker's existing call site doesn't
-- need touching -- the timer above is event-driven now, not polled.
function m.updateSoulstoneCooldown()
end

-- Session-only log of "who stoned who, when" and curse/banish assignments,
-- for answering "did I get stoned tonight" type questions after a wipe.
function m.logHistory(text)
    table.insert(m.history, { text = text, time = time() })
    -- Cap growth over a long session
    if table.getn(m.history) > 100 then
        table.remove(m.history, 1)
    end
end

function m.rebroadcastKnownData()
    local channel = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
    if not channel then return end
    -- Skip our own uncertain scanned entries -- those shouldn't propagate
    -- and risk overwriting someone else's accurate value with a guess.
    for target, data in pairs(m.stones) do
        if data.expires > time() and not data.unknownExpiry then
            SendAddonMessage(ADDON_MSG_PREFIX, "ADD:"..target..":"..data.caster..":"..data.expires, channel)
        end
    end
    for wName, iconIdx in pairs(m.banish) do
        SendAddonMessage(ADDON_MSG_PREFIX, "BANISH:"..wName..":"..iconIdx, channel)
    end
    for shortName, data in pairs(m.curses) do
        if data.caster ~= "Unknown" then
            SendAddonMessage(ADDON_MSG_PREFIX, "CURSE:"..shortName..":"..data.caster, channel)
        end
    end
    local myShards = m.shardCounts[UnitName("player")]
    if myShards then
        SendAddonMessage(ADDON_MSG_PREFIX, "SHARDS:"..myShards, channel)
    end
    local myCd = m.ssCooldowns[UnitName("player")]
    if myCd then
        SendAddonMessage(ADDON_MSG_PREFIX, "SSCD:"..myCd, channel)
    end
end

function m.scanForCurses(silent)
    if not UnitExists("target") then
        if not silent then say("No target selected -- target the mob you want to check.") end
        return
    end
    -- Match on just the icon filename portion (e.g. "ChillTouch"), same
    -- robust substring approach already used for soulstone texture
    -- detection, rather than requiring an exact full-path match.
    local CURSE_ICON_NAMES = {
        ["CoE"] = "ChillTouch",
        ["CoS"] = "CurseOfAchimonde",
        ["CoR"] = "UnholyStrength",
        ["CoW"] = "CurseOfMannoroth",
    }
    local found = 0
    local i = 1
    while true do
        local tex = UnitDebuff("target", i)
        if not tex then break end
        for shortName, iconName in pairs(CURSE_ICON_NAMES) do
            if string.find(tex, iconName, 1, true) then
                -- Only a genuinely new discovery counts as newsworthy --
                -- don't re-announce something we already know about every
                -- time the debounced auto-scan re-runs on retarget.
                if not m.curses[shortName] then
                    m.curses[shortName] = { caster = "Unknown" }
                    found = found + 1
                end
            end
        end
        i = i + 1
    end
    if found > 0 then
        if not silent then
            say("Found "..found.." new curse(s) on your target (caster unknown -- see curse section).")
        end
        m.refreshBanish()
    elseif not silent then
        say("No curses found on your target.")
    end
end

-------------------------------------------------------------------------------
-- Minimap Button
-------------------------------------------------------------------------------

function m.createMinimapButton()
    local radius = 80
    local btn = CreateFrame("Button", "SoulstoneTrackerMinimap", Minimap)
    -- Standard minimap button layout (same as the stock tracking button and
    -- other addons' buttons): 31x31 button, round gold tracking border over
    -- it, round dark backing, and the icon trimmed to sit inside the ring.
    btn:SetWidth(31)
    btn:SetHeight(31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetClampedToScreen(true)

    -- Round dark backing behind the icon
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetWidth(20)
    bg:SetHeight(20)
    bg:SetPoint("TopLeft", btn, "TopLeft", 7, -5)

    -- Soulstone icon, edges trimmed so its square corners hide under the ring
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\Spell_Shadow_SoulGem")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetWidth(18)
    icon:SetHeight(18)
    icon:SetPoint("TopLeft", btn, "TopLeft", 7, -6)
    btn.icon = icon

    -- Round gold border
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(53)
    border:SetHeight(53)
    border:SetPoint("TopLeft", btn, "TopLeft", 0, 0)

    -- Highlight on hover
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local highlight = btn:GetHighlightTexture()
    if highlight then highlight:SetBlendMode("ADD") end

    -- Icon nudges down-right while pressed, like the stock buttons
    btn:SetScript("OnMouseDown", function() icon:SetPoint("TopLeft", btn, "TopLeft", 8, -7) end)
    btn:SetScript("OnMouseUp", function() icon:SetPoint("TopLeft", btn, "TopLeft", 7, -6) end)

    local angle = SoulstoneTrackerDB.minimapAngle or 195
    local function updatePos()
        btn:SetPoint("Center", Minimap, "Center", math.cos(math.rad(angle))*radius, math.sin(math.rad(angle))*radius)
    end
    updatePos()

    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function()
        btn:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            angle = math.deg(math.atan2(py/s - my, px/s - mx))
            SoulstoneTrackerDB.minimapAngle = angle
            updatePos()
        end)
    end)
    btn:SetScript("OnDragStop", function()
        btn:SetScript("OnUpdate", nil)
        icon:SetPoint("TopLeft", btn, "TopLeft", 7, -6)
    end)
    btn:SetScript("OnClick", function()
        if m.frame:IsVisible() then
            m.frame:Hide() SoulstoneTrackerDB.hidden = true
        else
            m.frame:Show() SoulstoneTrackerDB.hidden = false
        end
    end)
    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:SetText("|cffa050ffSoulstone Tracker|r")
        local n = 0
        for _ in pairs(m.stones) do n = n + 1 end
        if n > 0 then
            GameTooltip:AddLine(n.." active soulstone(s)", 0, 1, 0)
        else
            GameTooltip:AddLine("No active soulstones", 0.5, 0.5, 0.5)
        end
        GameTooltip:AddLine("Click to toggle", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m.minimap = btn
end

-------------------------------------------------------------------------------
-- Column repositioning on resize
-------------------------------------------------------------------------------

-- Background fill follows the transparency slider; in the classic theme the
-- border fades with it a little (never fully), like OctoBus does.
function m.applyFrameAlpha(f)
    f = f or m.frame
    if not f then return end
    local T = f.theme or theme()
    local a = cfg("frameAlpha")
    f:SetBackdropColor(T.bg[1], T.bg[2], T.bg[3], a)
    if T.classic then
        f:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], math.min(0.98, a + 0.25))
    else
        f:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
    end
end

function m.repositionColumns()
    local f = m.frame
    if not f or not f.cols then return end
    local w = f:GetWidth()

    local tx = math.floor(w * COL_ARROW) + 14
    f.cols.hTarget:ClearAllPoints()
    f.cols.hTarget:SetPoint("TopLeft", f, "TopLeft", tx, f.headerY or -(TITLE_H + HEADER_H/2))

    for i = 1, MAX_ROWS do
        local row = f.rows[i]
        if row then
            local rowY = -(TITLE_H + HEADER_H + 2 + (i-1)*ROW_H)
            row.caster:SetWidth(math.floor(w * COL_CASTER_END) - 8)
            row.arrow:ClearAllPoints()
            row.arrow:SetPoint("TopLeft", f, "TopLeft", math.floor(w * COL_ARROW), rowY)
            row.target:ClearAllPoints()
            row.target:SetPoint("TopLeft", f, "TopLeft", tx, rowY)
            row.target:SetWidth(math.floor(w * COL_TARGET_END) - tx - 4)
            row.timer:SetWidth(w - math.floor(w * COL_TARGET_END) - 8)
        end
    end
end

-------------------------------------------------------------------------------
-- UI
-------------------------------------------------------------------------------

StaticPopupDialogs["SOULSTONETRACKER_RELOAD"] = {
    text = "SoulstoneTracker: some changes need a UI reload to fully apply. Reload now?",
    button1 = "Reload Now",
    button2 = "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Call this instead of m.settings:Hide() directly whenever the settings
-- panel is closed, so a pending reload-required change gets flagged.
function m.closeSettings()
    if not m.settings then return end
    m.settings:Hide()
    if m.settings.needsReload then
        m.settings.needsReload = false
        StaticPopup_Show("SOULSTONETRACKER_RELOAD")
    end
end

function m.onClose()
    if m.frame then
        m.frame:Hide()
        SoulstoneTrackerDB.hidden = true
    end
end

function m.onLockClick()
    m.locked = not m.locked
    SoulstoneTrackerDB.locked = m.locked
    m.frame.updateLock()
    say(m.locked and "Frame locked." or "Frame unlocked.")
end

function m.createFrame()
    local savedW = SoulstoneTrackerDB.size and SoulstoneTrackerDB.size.w or BASE_W
    local savedH = SoulstoneTrackerDB.size and SoulstoneTrackerDB.size.h or TITLE_H + HEADER_H + ROW_H + 6

    local T = theme()
    local IN = T.inset

    local f = CreateFrame("Frame", "SoulstoneTrackerFrame", UIParent)
    f:SetWidth(savedW)
    f:SetHeight(savedH)
    f:SetFrameStrata("MEDIUM")
    if T.classic then
        -- classic Blizzard tooltip panel: dark blue fill, silver rounded border
        f:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets   = { left=4, right=4, top=4, bottom=4 }
        })
    else
        f:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets   = { left=1, right=1, top=1, bottom=1 }
        })
    end
    f.theme = T
    m.applyFrameAlpha(f)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function()
        if not m.locked then this:StartMoving() end
    end)
    f:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local point, _, rpoint, x, y = this:GetPoint()
        SoulstoneTrackerDB.position = { point=point, rpoint=rpoint, x=x, y=y }
    end)
    f:SetScript("OnSizeChanged", function()
        local w = math.max(MIN_W, this:GetWidth())
        this:SetWidth(w)
        SoulstoneTrackerDB.size = { w=w, h=this:GetHeight() }
        m.repositionColumns()
    end)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f)
    f.titleBar = titleBar
    if T.classic then
        -- no filled bar: gold title straight on the panel, silver rule below
        titleBar:SetPoint("TopLeft",  f, "TopLeft",  IN, -IN)
        titleBar:SetPoint("TopRight", f, "TopRight", -IN, -IN)
        titleBar:SetHeight(TITLE_H - IN)

        -- red glow behind the title that pulses while a stone is in its
        -- final minute (the shadow theme flashes its title bar instead)
        local glow = titleBar:CreateTexture(nil, "BACKGROUND")
        glow:SetAllPoints(titleBar)
        glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(1, 0.15, 0.1, 0)
        f.titleGlow = glow

        local titleRule = makeRule(f, T)
        titleRule:SetPoint("TopLeft",  f, "TopLeft",  IN + 4, -TITLE_H)
        titleRule:SetPoint("TopRight", f, "TopRight", -(IN + 4), -TITLE_H)
    else
        titleBar:SetPoint("TopLeft",  f, "TopLeft",  1, -1)
        titleBar:SetPoint("TopRight", f, "TopRight", -1, -1)
        titleBar:SetHeight(TITLE_H)
        titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        titleBar:SetBackdropColor(0.22, 0.08, 0.38, 1)

        local grad = titleBar:CreateTexture(nil, "OVERLAY")
        grad:SetAllPoints(titleBar)
        grad:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        grad:SetBlendMode("ADD")
        grad:SetVertexColor(0.2, 0.05, 0.4, 0.4)
    end

    local title = titleBar:CreateFontString(nil, "OVERLAY")
    styleFont(title, T.classic and 12 or 11, T)
    title:SetPoint("Left", titleBar, "Left", T.classic and 4 or 6, 0)
    title:SetText(T.titleHex.."Soulstone Tracker v1.5|r")
    f.title = title

    -- Title bar icons. The .blp copies of these icons have no colour data
    -- (they render as solid black), and WoW picks the .blp over the .tga when
    -- the path has no extension -- so the .tga files are named explicitly.
    -- Classic: white versions tinted gold like the "S", white on hover.
    -- Shadow: the original coloured icons (grey cog, green lock, red X).
    local IMG = "Interface\\AddOns\\SoulstoneTracker\\images\\"
    local function iconFile(name)
        return IMG..name..(T.classic and "_white.tga" or ".tga")
    end
    local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0   -- same gold as the "S"
    local function goldOnHover(btn, tex)
        if not T.classic or not tex then return end
        tex:SetVertexColor(GOLD_R, GOLD_G, GOLD_B)
        local onEnter = btn:GetScript("OnEnter")
        local onLeave = btn:GetScript("OnLeave")
        btn:SetScript("OnEnter", function()
            tex:SetVertexColor(1, 1, 1)
            if onEnter then onEnter() end
        end)
        btn:SetScript("OnLeave", function()
            tex:SetVertexColor(GOLD_R, GOLD_G, GOLD_B)
            if onLeave then onLeave() end
        end)
    end

    -- Settings button (defined in XML)
    local settingsBtn = _G["SSTSettingsButton"]
    settingsBtn:SetParent(titleBar)
    settingsBtn:SetPoint("Right", titleBar, "Right", -42, 0)
    settingsBtn:Show()
    local cog = settingsBtn:GetNormalTexture()
    if cog then cog:SetTexture(iconFile("icon_cog")) end
    goldOnHover(settingsBtn, cog)

    -- Scan button (pure Lua, not XML -- avoids the reload/staleness issues
    -- we hit with the XML-defined buttons).
    local scanBtn = CreateFrame("Button", nil, titleBar)
    scanBtn:SetWidth(16) scanBtn:SetHeight(16)
    scanBtn:SetPoint("Right", titleBar, "Right", -60, 0)
    -- Text glyph instead of a mismatched item icon -- guaranteed to fit the
    -- theme since it's just colored text, same approach (and now the exact
    -- same colors) as the settings panel's own text-based close button.
    local scanTxt = scanBtn:CreateFontString(nil, "OVERLAY")
    styleFont(scanTxt, 13, T)
    scanTxt:SetAllPoints(scanBtn)
    scanTxt:SetJustifyH("Center")
    scanTxt:SetJustifyV("Middle")
    local scanIdle = T.classic and "|cffffd100S|r" or "|cffaaaaaaS|r"
    scanTxt:SetText(scanIdle)
    scanBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(scanBtn, "ANCHOR_LEFT")
        GameTooltip:SetText("Force resync with group")
        GameTooltip:Show()
        scanTxt:SetText("|cffffffffS|r")
    end)
    scanBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        scanTxt:SetText(scanIdle)
    end)
    scanBtn:SetScript("OnClick", function()
        local channel = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
        if not channel then
            say("Not in a group -- nothing to sync.")
        else
            m.rebroadcastKnownData()
            SendAddonMessage(ADDON_MSG_PREFIX, "SYNCREQ", channel)
            say("Resync requested -- rebroadcast your data and asked others to do the same.")
        end
    end)

    -- Lock button (defined in XML with BLP texture)
    local lockBtn = _G["SSTLockButton"]
    lockBtn:SetParent(titleBar)
    lockBtn:SetPoint("Right", titleBar, "Right", -24, 0)
    lockBtn:Show()

    local lockTex = _G["SSTLockButtonNT"]
    f.lockTex = lockTex
    goldOnHover(lockBtn, lockTex)

    local function updateLock()
        if m.locked then
            lockTex:SetTexture(iconFile("icon_locked"))
        else
            lockTex:SetTexture(iconFile("icon_unlocked"))
        end
    end
    updateLock()
    f.updateLock = updateLock

    -- X close button (defined in XML with BLP texture)
    local closeBtn = _G["SSTCloseButton"]
    if T.classic then
        -- the stock red Blizzard close button instead of the flat X
        closeBtn:Hide()
        closeBtn = CreateFrame("Button", "SSTClassicCloseButton", titleBar, "UIPanelCloseButton")
        closeBtn:SetWidth(24) closeBtn:SetHeight(24)
        closeBtn:SetPoint("Right", titleBar, "Right", 4, 0)
        closeBtn:SetFrameLevel(titleBar:GetFrameLevel() + 3)
        closeBtn:SetScript("OnClick", function() m.onClose() end)
        closeBtn:Show()
    else
        closeBtn:SetParent(titleBar)
        closeBtn:SetPoint("Right", titleBar, "Right", -4, 0)
        local xTex = closeBtn:GetNormalTexture()
        if xTex then xTex:SetTexture(IMG.."icon_x.tga") end
        closeBtn:Show()
    end

    -- Column headers
    -- classic: headers sit a bit higher so they clear the rule under them
    local hY = T.classic and -(TITLE_H + 3) or -(TITLE_H + HEADER_H/2)
    f.headerY = hY

    local hc = T.headerColor
    local hCaster = f:CreateFontString(nil, "OVERLAY")
    styleFont(hCaster, 10, T)
    hCaster:SetTextColor(hc[1], hc[2], hc[3], 1)
    hCaster:SetPoint("TopLeft", f, "TopLeft", 8, hY)
    hCaster:SetText("Caster")

    local hTarget = f:CreateFontString(nil, "OVERLAY")
    styleFont(hTarget, 10, T)
    hTarget:SetTextColor(hc[1], hc[2], hc[3], 1)
    hTarget:SetPoint("TopLeft", f, "TopLeft", math.floor(savedW * COL_ARROW) + 14, hY)
    hTarget:SetText("Target")

    local hExpires = f:CreateFontString(nil, "OVERLAY")
    styleFont(hExpires, 10, T)
    hExpires:SetTextColor(hc[1], hc[2], hc[3], 1)
    hExpires:SetPoint("TopRight", f, "TopRight", -8, hY)
    hExpires:SetJustifyH("Right")
    hExpires:SetText("Expires")

    local div = makeRule(f, T)
    local divIn = T.classic and IN + 4 or 1
    div:SetPoint("TopLeft",  f, "TopLeft",  divIn, -(TITLE_H + HEADER_H))
    div:SetPoint("TopRight", f, "TopRight", -divIn, -(TITLE_H + HEADER_H))

    local empty = f:CreateFontString(nil, "OVERLAY")
    styleFont(empty, 10, T)
    empty:SetTextColor(T.emptyColor[1], T.emptyColor[2], T.emptyColor[3], 1)
    empty:SetPoint("TopLeft", f, "TopLeft", 8, -(TITLE_H + HEADER_H + 3))
    empty:SetText("No active soulstones")
    f.empty = empty

    f.cols = { hTarget = hTarget }

    -- Rows
    f.rows = {}
    for i = 1, MAX_ROWS do
        local rowY = -(TITLE_H + HEADER_H + 2 + (i-1)*ROW_H)
        local w = savedW

        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TopLeft",  f, "TopLeft",  IN, rowY)
        bg:SetPoint("TopRight", f, "TopRight", -IN, rowY)
        bg:SetHeight(ROW_H)
        if math.mod(i, 2) == 0 then bg:SetTexture(1,1,1,T.stripe) else bg:SetTexture(0,0,0,0) end
        bg:Hide()

        local caster = f:CreateFontString(nil, "OVERLAY")
        styleFont(caster, 11, T)
        caster:SetPoint("TopLeft", f, "TopLeft", 8, rowY)
        caster:SetWidth(math.floor(w * COL_CASTER_END) - 8)
        caster:SetJustifyH("Left")

        local arrow = f:CreateFontString(nil, "OVERLAY")
        styleFont(arrow, 11, T)
        arrow:SetTextColor(0.4, 0.4, 0.4, 1)
        arrow:SetPoint("TopLeft", f, "TopLeft", math.floor(w * COL_ARROW), rowY)
        arrow:SetText("->")

        local tx = math.floor(w * COL_ARROW) + 14
        local target = f:CreateFontString(nil, "OVERLAY")
        styleFont(target, 11, T)
        target:SetPoint("TopLeft", f, "TopLeft", tx, rowY)
        target:SetWidth(math.floor(w * COL_TARGET_END) - tx - 4)
        target:SetJustifyH("Left")

        local timer = f:CreateFontString(nil, "OVERLAY")
        styleFont(timer, 11, T)
        timer:SetPoint("TopRight", f, "TopRight", -8, rowY)
        timer:SetWidth(w - math.floor(w * COL_TARGET_END) - 8)
        timer:SetJustifyH("Right")

        local hitbox = CreateFrame("Frame", nil, f)
        hitbox:SetHeight(ROW_H)
        hitbox:SetPoint("TopLeft",  f, "TopLeft",  IN, rowY)
        hitbox:SetPoint("TopRight", f, "TopRight", -IN, rowY)
        hitbox:EnableMouse(true)
        hitbox.rowIndex = i

        -- classic quest-log style hover glow on rows that have a stone
        -- (drawn on the window itself, under the row text, not on the hitbox
        -- which sits above the text)
        if T.classic then
            local hl = f:CreateTexture(nil, "BORDER")
            hl:SetAllPoints(hitbox)
            hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            hl:SetBlendMode("ADD")
            hl:SetAlpha(0.5)
            hl:Hide()
            hitbox.hl = hl
        end

        hitbox:SetScript("OnEnter", function()
            local row = f.rows[this.rowIndex]
            if not row or not row.data then return end
            if this.hl then this.hl:Show() end
            local d = row.data
            GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
            GameTooltip:SetText("|cffa050ff"..d.caster.."|r -> |cffffffff"..d.target.."|r")
            GameTooltip:AddLine("Cast: "..date("%H:%M:%S", d.castTime), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Expires: "..date("%H:%M:%S", d.expires), 0.8, 0.8, 0.8)
            local s = timeLeft(d.expires)
            GameTooltip:AddLine(string.format("Time left: %dm %02ds", math.floor(s/60), math.mod(s,60)), 1,1,0)
            GameTooltip:Show()
        end)
        hitbox:SetScript("OnLeave", function()
            if this.hl then this.hl:Hide() end
            GameTooltip:Hide()
        end)

        f.rows[i] = { caster=caster, arrow=arrow, target=target, timer=timer, bg=bg, hitbox=hitbox, data=nil }
    end

    local SEC_ROW_H = 18

    -- Combined Warlock section (curse + banish on same row)
    -- classic: "Curse and Banish Assignment ———" with the rule trailing the
    -- label; shadow: the original small caps label on a full-width line
    local warlockDivTex = T.classic and makeTrailingRule(f, T) or makeRule(f, T)
    f.curseDivider = warlockDivTex

    local warlockHdr = f:CreateFontString(nil, "OVERLAY")
    styleFont(warlockHdr, T.classic and 10 or 8, T)
    warlockHdr:SetTextColor(T.sectionColor[1], T.sectionColor[2], T.sectionColor[3], 1)
    warlockHdr:SetText(T.classic and "Curse and Banish Assignment" or "CURSE AND BANISH ASSIGNMENT")
    f.curseHeader = warlockHdr

    -- Footer line for curses found via target-scan whose caster is unknown
    -- (e.g. cast by a warlock not running the addon) -- these don't fit the
    -- per-warlock row display since there's no known warlock to attach them
    -- to, so they get a small summary line instead.
    local unknownCurseLine = f:CreateFontString(nil, "OVERLAY")
    styleFont(unknownCurseLine, 9, T)
    unknownCurseLine:SetTextColor(0.7, 0.7, 0.7, 1)
    unknownCurseLine:Hide()
    f.unknownCurseLine = unknownCurseLine

    -- One row per warlock (up to 5), shows: Name | CurseIcon | BanishIcon
    f.warlockRows = {}
    for i = 1, 5 do
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetHeight(SEC_ROW_H)
        if math.mod(i,2)==0 then bg:SetTexture(1,1,1,T.stripe) else bg:SetTexture(0,0,0,0) end
        bg:Hide()

        -- Warlock name
        local nameTxt = f:CreateFontString(nil, "OVERLAY")
        styleFont(nameTxt, 11, T)
        nameTxt:SetJustifyH("Left")
        nameTxt:Hide()

        -- Curse icon (auto-detected)
        local curseIcon = f:CreateTexture(nil, "ARTWORK")
        curseIcon:SetWidth(14)
        curseIcon:SetHeight(14)
        curseIcon:Hide()

        -- Curse label
        local curseLbl = f:CreateFontString(nil, "OVERLAY")
        styleFont(curseLbl, 10, T)
        curseLbl:SetJustifyH("Left")
        curseLbl:Hide()

        -- Curse override button (manual assign/correct, mirrors banish button below)
        local curseBtn = CreateFrame("Button", "SSWarlockCurse_"..i, f)
        curseBtn:SetHeight(SEC_ROW_H)
        curseBtn:SetFrameLevel(f:GetFrameLevel() + 5)
        curseBtn.rowIndex = i

        curseBtn:SetScript("OnEnter", function()
            local row = f.warlockRows[this.rowIndex]
            if not row or not row.warlockName then return end
            GameTooltip:SetOwner(curseBtn, "ANCHOR_LEFT")
            GameTooltip:SetText(row.warlockName, 0.6, 0.3, 1)
            local shortName = nil
            for sn, data in pairs(m.curses) do
                if data.caster == row.warlockName then shortName = sn break end
            end
            GameTooltip:AddLine(shortName and ("Curse: "..shortName) or "No curse detected", 1,1,0)
            GameTooltip:AddLine("Click to manually set/correct", 0.7,0.7,0.7)
            GameTooltip:Show()
        end)
        curseBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        curseBtn:SetScript("OnClick", function()
            local row = f.warlockRows[this.rowIndex]
            if not row or not row.warlockName then return end
            local wName = row.warlockName
            local menu = CreateFrame("Frame", "SSWarlockCurseMenu_"..this.rowIndex, UIParent, "UIDropDownMenuTemplate")
            UIDropDownMenu_Initialize(menu, function()
                local none = { text="-- None --", notCheckable=true }
                none.func = function()
                    local ch = GetNumRaidMembers()>0 and "RAID" or (GetNumPartyMembers()>0 and "PARTY" or nil)
                    for sn, data in pairs(m.curses) do
                        if data.caster == wName then
                            m.curses[sn] = nil
                            if ch then SendAddonMessage(ADDON_MSG_PREFIX, "CURSEREM:"..sn, ch) end
                        end
                    end
                    m.refresh()
                    say("Cleared curse assignment for "..wName..".")
                end
                UIDropDownMenu_AddButton(none)
                for fullName, shortName in pairs(CURSES) do
                    local ci = { text=fullName.." ("..shortName..")", notCheckable=true, arg1=shortName }
                    ci.func = function(sn)
                        local ch = GetNumRaidMembers()>0 and "RAID" or (GetNumPartyMembers()>0 and "PARTY" or nil)
                        -- Remove wName from any other curse slot first, and
                        -- broadcast that removal so other clients don't keep
                        -- a stale entry for the superseded curse.
                        for sn2, data in pairs(m.curses) do
                            if data.caster == wName and sn2 ~= sn then
                                m.curses[sn2] = nil
                                if ch then SendAddonMessage(ADDON_MSG_PREFIX, "CURSEREM:"..sn2, ch) end
                            end
                        end
                        m.curses[sn] = { caster = wName }
                        m.refresh()
                        local msg = "[Curse] "..wName.." -> "..sn.." (manual override)"
                        say(msg)
                        if ch then SendAddonMessage(ADDON_MSG_PREFIX, "CURSE:"..sn..":"..wName, ch) end
                    end
                    UIDropDownMenu_AddButton(ci)
                end
            end, "MENU")
            ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
        end)
        curseBtn:Hide()

        -- Banish icon button
        local banishBtn = CreateFrame("Button", "SSWarlockBanish_"..i, f)
        banishBtn:SetWidth(16)
        banishBtn:SetHeight(16)
        banishBtn:SetFrameLevel(f:GetFrameLevel() + 5)
        banishBtn.rowIndex = i

        local banishTex = banishBtn:CreateTexture(nil, "ARTWORK")
        banishTex:SetAllPoints(banishBtn)
        banishTex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        banishTex:SetTexCoord(0,0,0,0)
        banishBtn.iconTex = banishTex

        local banishLbl = banishBtn:CreateFontString(nil, "OVERLAY")
        styleFont(banishLbl, 10, T)
        banishLbl:SetAllPoints(banishBtn)
        banishLbl:SetJustifyH("Center")
        banishLbl:SetJustifyV("Middle")
        banishLbl:SetTextColor(0.4, 0.4, 0.4, 1)
        banishLbl:SetText("-")
        banishBtn.lbl = banishLbl

        banishBtn:SetScript("OnEnter", function()
            local row = f.warlockRows[this.rowIndex]
            if not row or not row.warlockName then return end
            GameTooltip:SetOwner(banishBtn, "ANCHOR_LEFT")
            GameTooltip:SetText(row.warlockName, 0.6, 0.3, 1)
            local idx = m.banish[row.warlockName]
            GameTooltip:AddLine(idx and ("Banish: "..RAID_ICONS[idx].name) or "Click to assign banish target", 1,1,0)
            GameTooltip:Show()
        end)
        banishBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        banishBtn:SetScript("OnClick", function()
            local row = f.warlockRows[this.rowIndex]
            if not row or not row.warlockName then return end
            local wName = row.warlockName
            local menu = CreateFrame("Frame", "SSWarlockMenu_"..this.rowIndex, UIParent, "UIDropDownMenuTemplate")
            UIDropDownMenu_Initialize(menu, function()
                local none = { text="-- None --", notCheckable=true }
                none.func = function()
                    m.banish[wName] = nil
                    m.refreshBanish()
                    local ch = GetNumRaidMembers()>0 and "RAID" or (GetNumPartyMembers()>0 and "PARTY" or nil)
                    if ch then SendAddonMessage(ADDON_MSG_PREFIX, "BANISH:"..wName..":0", ch) end
                end
                UIDropDownMenu_AddButton(none)
                for idx, iconData in ipairs(RAID_ICONS) do
                    local ii = { text=iconData.name, notCheckable=true, arg1=idx }
                    ii.func = function(iconIdx)
                        m.banish[wName] = iconIdx
                        m.refreshBanish()
                        local msg = "[Banish] "..wName.." -> "..RAID_ICONS[iconIdx].name
                        say(msg)
                        m.logHistory(wName.." assigned banish: "..RAID_ICONS[iconIdx].name)
                        local ch = GetNumRaidMembers()>0 and "RAID" or (GetNumPartyMembers()>0 and "PARTY" or nil)
                        if ch then sendGroup(msg) SendAddonMessage(ADDON_MSG_PREFIX, "BANISH:"..wName..":"..iconIdx, ch) end
                    end
                    UIDropDownMenu_AddButton(ii)
                end
            end, "MENU")
            ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
        end)
        banishBtn:Hide()

        f.warlockRows[i] = {
            bg=bg, nameTxt=nameTxt, curseIcon=curseIcon, curseLbl=curseLbl, curseBtn=curseBtn,
            banishBtn=banishBtn, banishTex=banishTex, banishLbl=banishLbl,
            warlockName=nil
        }
    end

    -- Keep these for compatibility
    f.curseRows  = {}
    f.banishRows = {}
    f.banishDivider = f:CreateTexture(nil, "ARTWORK") -- unused but referenced
    f.banishHeader  = f:CreateFontString(nil, "OVERLAY") -- unused but referenced


    -- Resize grip
    local grip = CreateFrame("Button", nil, f)
    grip:SetWidth(16)
    grip:SetHeight(16)
    if T.classic then
        grip:SetPoint("BottomRight", f, "BottomRight", -2, 2)
    else
        grip:SetPoint("BottomRight", f, "BottomRight", 0, 0)
    end
    grip:SetFrameLevel(f:GetFrameLevel() + 10)
    grip:SetNormalTexture("Interface\\AddOns\\SoulstoneTracker\\ResizeGrip")
    grip:SetScript("OnEnter", function()
        GameTooltip:SetOwner(grip, "ANCHOR_LEFT")
        GameTooltip:SetText("Drag to resize", 1,1,1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

    -- Ticker
    -- Runs on its own always-shown, parentless frame rather than on the
    -- tracker window: WoW doesn't run OnUpdate on hidden frames, so with the
    -- ticker on the window, closing it (X, minimap button, /ss, or "hide when
    -- not in party/raid") stopped expiry warnings, expired alerts and
    -- announcements, clearing expired stones, the soulstone cooldown check and
    -- the periodic resync. No parent also keeps it running when the UI is
    -- hidden with Alt+Z.
    local tick = 0
    local ssCdTick = 0
    local autoSyncTick = 0
    local flashTime = 0
    local flashDir = 1
    local ticker = m.ticker or CreateFrame("Frame", "SoulstoneTrackerTicker")
    m.ticker = ticker
    ticker:Show()
    ticker:SetScript("OnUpdate", function()
        tick = tick + arg1
        if tick >= 1 then
            tick = 0
            m.clearExpired()
            m.refresh()
        end
        ssCdTick = ssCdTick + arg1
        if ssCdTick >= 15 then
            ssCdTick = 0
            m.updateSoulstoneCooldown()
        end
        autoSyncTick = autoSyncTick + arg1
        if autoSyncTick >= 300 then
            autoSyncTick = 0
            -- Periodic background resync (every 5 min) to catch any drift
            -- over a long raid session -- same logic as /ss resync, but
            -- silent (no chat message) since this runs automatically.
            local channel = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
            if channel then
                m.rebroadcastKnownData()
                SendAddonMessage(ADDON_MSG_PREFIX, "SYNCREQ", channel)
            end
        end
        -- the last-minute title pulse is only worth animating when visible
        if not f:IsVisible() then return end
        local shouldFlash = false
        local now = time()
        for _, data in pairs(m.stones) do
            if data.expires - now <= 60 and data.expires - now > 0 then
                shouldFlash = true
                break
            end
        end

        if shouldFlash then
            flashTime = flashTime + arg1 * flashDir
            if flashTime >= 1 then flashDir = -1
            elseif flashTime <= 0 then flashDir = 1 end
            if f.titleGlow then
                f.titleGlow:SetVertexColor(1, 0.15, 0.1, 0.8 * flashTime)
            else
                local r = 0.22 + (0.5 * flashTime)
                local g = 0.08 * (1 - flashTime)
                local b = 0.38 * (1 - flashTime)
                f.titleBar:SetBackdropColor(r, g, b, 1)
            end
        else
            flashTime = 0
            flashDir = 1
            if f.titleGlow then
                f.titleGlow:SetVertexColor(1, 0.15, 0.1, 0)
            else
                f.titleBar:SetBackdropColor(0.22, 0.08, 0.38, 1)
            end
        end
    end)

    -- Redraw as soon as the window becomes visible again, so it never shows
    -- stale times after being closed (m.refresh skips work while hidden).
    f:SetScript("OnShow", function() m.refresh() end)

    -- Restore position
    if SoulstoneTrackerDB.position then
        local p = SoulstoneTrackerDB.position
        f:ClearAllPoints()
        f:SetPoint(p.point, UIParent, p.rpoint, p.x, p.y)
    else
        f:SetPoint("Center", UIParent, "Center", 300, 0)
    end

    -- Restore scale
    if SoulstoneTrackerDB.scale then
        f:SetScale(SoulstoneTrackerDB.scale)
    end

    -- Restore lock state
    if SoulstoneTrackerDB.locked then
        m.locked = true
    end

    m.frame = f
    m.repositionColumns()
    -- Apply lock state after m.frame is set
    f.updateLock()
    m.refresh()
end

function m.refresh()
    if not m.frame then return end
    -- Purely visual: skip while the window is closed (or the UI is hidden
    -- with Alt+Z). The window's OnShow redraws it the moment it reappears,
    -- and warnings / expiry keep running from the ticker regardless.
    if not m.frame:IsVisible() then return end
    local f = m.frame

    local list = {}
    for target, data in pairs(m.stones) do
        table.insert(list, { target=target, caster=data.caster, expires=data.expires, castTime=data.castTime or 0, unknownExpiry=data.unknownExpiry })
    end
    table.sort(list, function(a,b) return a.expires < b.expires end)
    local count = table.getn(list)

    local missing = getWarlocksMissingStones()
    if table.getn(missing) > 0 and (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0) then
        f.title:SetText((f.theme or theme()).titleHex.."Soulstone Tracker|r |cffff7c0a["..table.getn(missing).." available]|r")
    else
        f.title:SetText((f.theme or theme()).titleHex.."Soulstone Tracker v1.5|r")
    end

    if count == 0 then f.empty:Show() else f.empty:Hide() end

    for i = 1, MAX_ROWS do
        local row  = f.rows[i]
        local data = list[i]
        if data then
            row.caster:SetText(classColorName(data.caster, "|cffa050ff"))
            row.arrow:SetText("->")
            row.target:SetText(classColorName(data.target, "|cffffffff"))
            if data.unknownExpiry then
                row.timer:SetText("|cff888888~"..formatTime(timeLeft(data.expires)).." ?|r")
            else
                row.timer:SetText(formatTime(timeLeft(data.expires)))
            end
            row.bg:Show()
            row.data = data
        else
            row.caster:SetText("")
            row.arrow:SetText("")
            row.target:SetText("")
            row.timer:SetText("")
            row.bg:Hide()
            if row.hitbox.hl then row.hitbox.hl:Hide() end
            row.data = nil
        end
    end

    local rows = math.max(1, count)
    -- Height is managed by refreshBanish which accounts for all sections
    m.refreshBanish()
end

-- Auto-shows/hides the frame based on party/raid membership, if the
-- "hideWhenSolo" setting is enabled. Never fights a manual close -- if the
-- user explicitly hid the frame (X button), this won't force it back open.
function m.updateGroupVisibility()
    if not m.frame then return end
    if not cfg("hideWhenSolo") then return end
    if SoulstoneTrackerDB.hidden then return end
    local inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
    if inGroup then
        if not m.frame:IsShown() then m.frame:Show() end
    else
        if m.frame:IsShown() then m.frame:Hide() end
    end
end

-- Placeholders shown when a warlock has no curse / no banish mark
local EMPTY_CURSE_ICON  = "Interface\\Icons\\Spell_Shadow_DeathCoil"
local EMPTY_BANISH_ICON = "Interface\\Icons\\Spell_Shadow_Cripple"

-- Grey an icon out (desaturated where the client supports it, dimmed either
-- way), or restore it to full color.
local function setGreyed(tex, grey)
    if grey then
        if tex.SetDesaturated then tex:SetDesaturated(1) end
        tex:SetVertexColor(0.6, 0.6, 0.6)
        tex:SetAlpha(0.55)
    else
        if tex.SetDesaturated then tex:SetDesaturated(nil) end
        tex:SetVertexColor(1, 1, 1)
        tex:SetAlpha(1)
    end
end

function m.refreshBanish()
    if not m.frame then return end
    -- same as m.refresh: nothing to draw while hidden. (Joining or leaving a
    -- group still shows/hides the window: the roster events call
    -- updateGroupVisibility directly.)
    if not m.frame:IsVisible() then return end
    local f = m.frame
    m.applyFrameAlpha(f)
    m.updateGroupVisibility()
    local SEC_ROW_H = 18
    local HEADER_H2 = 10

    local FALLBACK_ICON = "Interface\\Icons\\Spell_Shadow_UnholyStrength"

    -- Build warlock list
    local warlocks = {}
    local playerName = UnitName("player")
    if playerName and playerIsWarlock() then table.insert(warlocks, playerName) end
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local name, _, _, _, class = GetRaidRosterInfo(i)
            if name and name ~= playerName and class == "Warlock" then
                table.insert(warlocks, name)
            end
        end
    else
        for i = 1, GetNumPartyMembers() do
            local name = UnitName("party"..i)
            if name and UnitClass("party"..i) == "Warlock" then
                table.insert(warlocks, name)
            end
        end
    end

    -- Build reverse curse lookup: warlock name -> shortName
    local warlockCurse = {}
    for shortName, data in pairs(m.curses) do
        if data.caster then
            warlockCurse[data.caster] = shortName
        end
    end

    -- Count stones for base Y
    local stoneCount = 0
    for _ in pairs(m.stones) do stoneCount = stoneCount + 1 end
    local stoneRows = math.max(1, stoneCount)
    local baseY = -(TITLE_H + HEADER_H + stoneRows * ROW_H + 6)
    local curY = baseY

    local warlockCount = table.getn(warlocks)
    local T = f.theme or theme()
    local IN = T.inset

    if not f.warlockRows then
        -- Frame height only
        f:SetHeight(TITLE_H + HEADER_H + stoneRows * ROW_H + 6 + T.padBottom)
        return
    end

    if warlockCount > 0 and cfg("showCurseSection") then
        -- Divider
        if T.classic then
            -- gold label, then a silver rule trailing off to the right of it
            curY = curY - 4
            f.curseHeader:ClearAllPoints()
            f.curseHeader:SetPoint("TopLeft", f, "TopLeft", 8, curY)
            f.curseHeader:Show()
            local ruleX = 8 + math.ceil(f.curseHeader:GetStringWidth() or 150) + 6
            f.curseDivider:ClearAllPoints()
            f.curseDivider:SetPoint("TopLeft",  f, "TopLeft",  ruleX, curY - 6)
            f.curseDivider:SetPoint("TopRight", f, "TopRight", -(IN + 4), curY - 6)
            f.curseDivider:Show()
            curY = curY - 14
        else
            f.curseDivider:ClearAllPoints()
            f.curseDivider:SetPoint("TopLeft",  f, "TopLeft",  1, curY)
            f.curseDivider:SetPoint("TopRight", f, "TopRight", -1, curY)
            f.curseDivider:Show()
            -- Header inline on divider
            f.curseHeader:ClearAllPoints()
            f.curseHeader:SetPoint("TopLeft", f, "TopLeft", 8, curY + 5)
            f.curseHeader:Show()
            curY = curY - 2
        end

        for i = 1, 5 do
            local row = f.warlockRows[i]
            local wName = warlocks[i]
            if row then
                row.warlockName = wName
                if wName then
                    -- Bg
                    row.bg:ClearAllPoints()
                    row.bg:SetPoint("TopLeft",  f, "TopLeft",  IN, curY)
                    row.bg:SetPoint("TopRight", f, "TopRight", -IN, curY)
                    row.bg:SetHeight(SEC_ROW_H)
                    row.bg:Show()

                    -- Fixed-width columns anchored from the right edge, so
                    -- name/curse/banish can never overlap regardless of
                    -- frame width (the old percentage-based layout had a
                    -- built-in overlap zone between the name and curse
                    -- columns). Banish only needs its 16px icon, curse
                    -- needs icon+3-letter label, name gets whatever's left.
                    local BANISH_COL_W = 44
                    local CURSE_COL_W = 52
                    -- Prefer a compact, close-to-name position; only fall
                    -- back to the right-edge-anchored math (which guarantees
                    -- no overlap) when the frame is narrow enough to need it.
                    local compactCurseColX = 175
                    local curseColX = math.min(compactCurseColX, f:GetWidth() - BANISH_COL_W - CURSE_COL_W)

                    -- Name
                    row.nameTxt:ClearAllPoints()
                    row.nameTxt:SetPoint("TopLeft", f, "TopLeft", 8, curY - 2)
                    row.nameTxt:SetWidth(curseColX - 12)
                    local nameStr = classColorName(wName, "|cffa050ff")
                    if m.shardCounts[wName] then
                        nameStr = nameStr.." |cffcc66ff("..m.shardCounts[wName]..")|r"
                    end
                    local readyAt = m.ssCooldowns[wName]
                    if readyAt and readyAt > time() then
                        local mins = math.ceil((readyAt - time()) / 60)
                        nameStr = nameStr.." |cffff6666[SS "..mins.."m]|r"
                    elseif readyAt then
                        nameStr = nameStr.." |cff00ff00[SS rdy]|r"
                    end
                    row.nameTxt:SetText(nameStr)
                    row.nameTxt:Show()

                    -- Curse info (fixed-width column)
                    local shortName = warlockCurse[wName]
                    if shortName then
                        row.curseIcon:ClearAllPoints()
                        row.curseIcon:SetPoint("TopLeft", f, "TopLeft", curseColX, curY - 2)
                        row.curseIcon:SetTexture(CURSE_ICONS[shortName] or "Interface\\Icons\\Spell_Shadow_Curse")
                        row.curseIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        setGreyed(row.curseIcon, false)
                        row.curseIcon:Show()
                        row.curseLbl:ClearAllPoints()
                        row.curseLbl:SetPoint("TopLeft", f, "TopLeft", curseColX + 18, curY - 2)
                        row.curseLbl:SetWidth(CURSE_COL_W - 18)
                        row.curseLbl:SetText((CURSE_COLORS[shortName] or "|cffffffff")..shortName.."|r")
                        row.curseLbl:Show()
                    else
                        -- no curse: greyed-out Death Coil placeholder
                        row.curseIcon:ClearAllPoints()
                        row.curseIcon:SetPoint("TopLeft", f, "TopLeft", curseColX, curY - 2)
                        row.curseIcon:SetTexture(EMPTY_CURSE_ICON)
                        row.curseIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        setGreyed(row.curseIcon, true)
                        row.curseIcon:Show()
                        row.curseLbl:SetText("")
                        row.curseLbl:Hide()
                    end

                    -- Curse override hitbox (covers icon+label area, click to manually set)
                    row.curseBtn:ClearAllPoints()
                    row.curseBtn:SetPoint("TopLeft", f, "TopLeft", curseColX - 2, curY - 2)
                    row.curseBtn:SetWidth(CURSE_COL_W)
                    row.curseBtn:Show()

                    -- Banish icon button (fixed-width column, right edge)
                    row.banishBtn:ClearAllPoints()
                    row.banishBtn:SetPoint("TopRight", f, "TopRight", -28, curY - 1)
                    row.banishBtn:Show()
                    local iconIdx = m.banish[wName]
                    if iconIdx and RAID_ICONS[iconIdx] then
                        local c = RAID_ICONS[iconIdx].coords
                        row.banishTex:ClearAllPoints()
                        row.banishTex:SetAllPoints(row.banishBtn)
                        row.banishTex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
                        row.banishTex:SetTexCoord(c[1], c[2], c[3], c[4])
                        setGreyed(row.banishTex, false)
                        row.banishLbl:SetText("")
                    else
                        -- no mark: small greyed-out Banish placeholder
                        row.banishTex:ClearAllPoints()
                        row.banishTex:SetWidth(14) row.banishTex:SetHeight(14)
                        row.banishTex:SetPoint("Center", row.banishBtn, "Center", 0, 0)
                        row.banishTex:SetTexture(EMPTY_BANISH_ICON)
                        row.banishTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        setGreyed(row.banishTex, true)
                        row.banishLbl:SetText("")
                    end

                    curY = curY - SEC_ROW_H
                else
                    row.warlockName = nil
                    row.bg:Hide() row.nameTxt:Hide()
                    row.curseIcon:Hide() row.curseLbl:Hide() row.curseBtn:Hide()
                    row.banishBtn:Hide()
                end
            end
        end
    else
        f.curseDivider:Hide()
        f.curseHeader:Hide()
        for i = 1, 5 do
            local row = f.warlockRows[i]
            if row then
                row.bg:Hide() row.nameTxt:Hide()
                row.curseIcon:Hide() row.curseLbl:Hide() row.curseBtn:Hide()
                row.banishBtn:Hide()
            end
        end
    end

    -- Unattributed curses (found via target-scan, no known caster)
    local unknownList = {}
    for shortName, data in pairs(m.curses) do
        if data.caster == "Unknown" then
            table.insert(unknownList, (CURSE_COLORS[shortName] or "|cffffffff")..shortName.."|r")
        end
    end
    if table.getn(unknownList) > 0 and cfg("showCurseSection") then
        f.unknownCurseLine:ClearAllPoints()
        f.unknownCurseLine:SetPoint("TopLeft", f, "TopLeft", 6, curY - 2)
        f.unknownCurseLine:SetText("|cff888888On target, unattributed:|r "..table.concat(unknownList, ", "))
        f.unknownCurseLine:Show()
        curY = curY - 14
    else
        f.unknownCurseLine:Hide()
    end

    -- Resize
    local totalH = TITLE_H + HEADER_H + (stoneRows * ROW_H) + 6 + math.abs(curY - baseY) + T.padBottom
    f:SetHeight(totalH)
end

-------------------------------------------------------------------------------
-- Curse tracking
-------------------------------------------------------------------------------

local lastCurseCaster = nil

local SHORT_NAMES = {
    ["Curse of the Elements"]  = "CoE",
    ["Curse of Shadow"]        = "CoS",
    ["Curse of Recklessness"]  = "CoR",
    ["Curse of Weakness"]      = "CoW",
}

-- Reverse lookup: shortName -> fullName, so SPELL_GO_SELF (which gives us a
-- spellID, not text) can still feed detectCurse()'s existing message-based
-- logic unchanged.
local FULL_NAMES = {}
for full, short in pairs(SHORT_NAMES) do FULL_NAMES[short] = full end

-- Curse spellIDs confirmed live via SPELL_GO_SELF on this server (Turtle/
-- OctoWow's client lacks GetSpellInfo, so these can't be looked up
-- generically -- only whichever ranks are actually reported get added).
-- If a warlock with an untracked rank casts a curse, add their reported ID
-- here rather than falling back to guessing.
local CURSE_SPELL_IDS = {
    [702]   = "CoW", -- Curse of Weakness
    [17937] = "CoS", -- Curse of Shadow
    [11722] = "CoE", -- Curse of the Elements
    [11717] = "CoR", -- Curse of Recklessness
}

-- Classify a spellId as "SS" (any rank of Soulstone Resurrection), a curse
-- short name (CoE/CoS/CoR/CoW), or nil. Uses nampower's spell name lookup
-- when available so every rank is covered; falls back to the hard-coded IDs.
do
    local cache = {}
    function m.classifySpell(id)
        if not id then return nil end
        local v = cache[id]
        if v == nil then
            v = false
            if id == SOULSTONE_SPELL_ID then
                v = "SS"
            elseif CURSE_SPELL_IDS[id] then
                v = CURSE_SPELL_IDS[id]
            elseif GetSpellNameAndRankForId then
                local name = GetSpellNameAndRankForId(id)
                if name == "Soulstone Resurrection" then
                    v = "SS"
                elseif name and SHORT_NAMES[name] then
                    v = SHORT_NAMES[name]
                end
            end
            cache[id] = v
        end
        return v or nil
    end
end

function m.isInGroup(name)
    if not name then return false end
    if name == UnitName("player") then return true end
    for i = 1, GetNumRaidMembers() do
        if UnitName("raid"..i) == name then return true end
    end
    for i = 1, GetNumPartyMembers() do
        if UnitName("party"..i) == name then return true end
    end
    return false
end

function m.detectCurse(msg, caster)
    for fullName, shortName in pairs(SHORT_NAMES) do
        if string.find(msg, fullName) then
            local casterName = caster or UnitName("player")
            -- Only update if:
            -- 1. This curse has no caster yet, OR
            -- 2. The same warlock is casting it (already assigned to them), OR
            -- 3. The caster previously had a different curse (they switched)
            local existing = m.curses[shortName]
            local casterPrevCurse = nil
            for sn, data in pairs(m.curses) do
                if data.caster == casterName then
                    casterPrevCurse = sn
                    break
                end
            end

            local shouldUpdate = false
            if not existing then
                -- New curse not yet tracked
                shouldUpdate = true
            elseif existing.caster == casterName then
                -- Same warlock recasting the same curse -- nothing actually
                -- changed (no timestamp is tracked per-curse), so skip the
                -- announce/broadcast entirely to avoid repeat noise.
                shouldUpdate = false
            end
            -- If another warlock already has this curse slot, don't overwrite

            -- Clear the caster's previous curse whenever they're switching to
            -- a different one, regardless of whether the new curse is
            -- already tracked -- this used to only run in one of the three
            -- branches above, so switching to an untracked curse left the
            -- old assignment stuck forever and never told other clients.
            if casterPrevCurse and casterPrevCurse ~= shortName then
                m.curses[casterPrevCurse] = nil
                shouldUpdate = true
                local channel = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
                if channel then
                    SendAddonMessage(ADDON_MSG_PREFIX, "CURSEREM:"..casterPrevCurse, channel)
                end
            end

            if shouldUpdate then
                m.curses[shortName] = { caster = casterName }
                say((CURSE_COLORS[shortName] or "|cffffffff")..shortName.."|r detected — cast by |cffa050ff"..casterName.."|r")
                m.logHistory(casterName.." cast "..shortName)
                if cfg("announceCurse") then
                    sendGroup("[Curse] "..casterName.." is on "..shortName.." ("..fullName..")")
                end
                local channel = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
                if channel then
                    SendAddonMessage(ADDON_MSG_PREFIX, "CURSE:"..shortName..":"..casterName, channel)
                    -- Addon messages over RAID scope can occasionally get
                    -- dropped (a known vanilla-era limitation, not something
                    -- fixable in code) -- send a redundant follow-up after a
                    -- short delay so a single lost packet doesn't leave
                    -- other clients out of sync. Idempotent to repeat.
                    m.debounce("curseResend_"..shortName, 1.5, function()
                        local ch = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
                        if ch and m.curses[shortName] and m.curses[shortName].caster == casterName then
                            SendAddonMessage(ADDON_MSG_PREFIX, "CURSE:"..shortName..":"..casterName, ch)
                        end
                    end)
                end
                m.refreshBanish()
            end
            return true
        end
    end
    return false
end

function m.removeCurse(msg)
    for fullName, shortName in pairs(SHORT_NAMES) do
        if string.find(msg, fullName) then
            -- Only remove locally if THIS client's own player is the one
            -- who cast it. AURA_GONE events aren't reliably self-scoped --
            -- they can fire from fade/replace text visible near a shared
            -- target regardless of who's tracking it, which was wiping out
            -- another warlock's correctly-synced curse entry. Removal for
            -- another warlock's curse should come from their own client's
            -- sync instead, not from ambient combat text here.
            local existing = m.curses[shortName]
            if existing and existing.caster == UnitName("player") then
                m.curses[shortName] = nil
                m.refresh()
            end
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- Settings Panel
-------------------------------------------------------------------------------

function m.toggleSettings()
    if m.settings and m.settings:IsVisible() then
        m.closeSettings()
        return
    end
    if not m.settings then
        m.createSettings()
    end
    m.settings:Show()
    m.refreshSettings()
end

function m.createSettings()
    local T = theme()
    -- SW is the content width; the classic dialog border adds PADX each side
    local PADX = T.classic and 12 or 0
    local SW, SH = 320, 420
    local s = CreateFrame("Frame", "SoulstoneTrackerSettings", UIParent)
    s:SetWidth(SW + 2 * PADX)
    s:SetHeight(SH)
    s:SetFrameStrata("HIGH")
    if T.classic then
        -- the stock Blizzard dialog box: marbled dark background, gold-trimmed border
        s:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets   = { left=11, right=12, top=12, bottom=11 }
        })
    else
        s:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets   = { left=1, right=1, top=1, bottom=1 }
        })
        s:SetBackdropColor(0.05, 0.05, 0.08, 0.98)
        s:SetBackdropBorderColor(0.4, 0.2, 0.6, 1)
    end
    s:SetMovable(true)
    s:EnableMouse(true)
    s:RegisterForDrag("LeftButton")
    s:SetScript("OnDragStart", function() this:StartMoving() end)
    s:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    s:SetClampedToScreen(true)

    -- Position next to main frame
    if m.frame then
        s:SetPoint("TopLeft", m.frame, "TopRight", 4, 0)
    else
        s:SetPoint("Center", UIParent, "Center", 0, 0)
    end

    if T.classic then
        -- gold title plate across the top edge, like the stock option windows.
        -- Built from three slices of the stock header art (left cap, middle,
        -- right cap) so the middle stretches to fit the title without
        -- squashing the end caps.
        local HEADER_TEX = "Interface\\DialogFrame\\UI-DialogBox-Header"
        local title = s:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetText("Soulstone Tracker Settings")

        local mid = s:CreateTexture(nil, "ARTWORK")
        mid:SetTexture(HEADER_TEX)
        mid:SetTexCoord(0.31, 0.67, 0, 0.63)
        mid:SetHeight(40)
        mid:SetWidth(math.ceil(title:GetStringWidth() or 170) + 16)
        mid:SetPoint("Top", s, "Top", 0, 12)

        local capL = s:CreateTexture(nil, "ARTWORK")
        capL:SetTexture(HEADER_TEX)
        capL:SetTexCoord(0.21, 0.31, 0, 0.63)
        capL:SetWidth(30) capL:SetHeight(40)
        capL:SetPoint("Right", mid, "Left", 0, 0)

        local capR = s:CreateTexture(nil, "ARTWORK")
        capR:SetTexture(HEADER_TEX)
        capR:SetTexCoord(0.67, 0.77, 0, 0.63)
        capR:SetWidth(30) capR:SetHeight(40)
        capR:SetPoint("Left", mid, "Right", 0, 0)

        title:SetPoint("Top", mid, "Top", 0, -14)

        local closeBtn = CreateFrame("Button", nil, s, "UIPanelCloseButton")
        closeBtn:SetPoint("TopRight", s, "TopRight", -5, -5)
        closeBtn:SetFrameLevel(s:GetFrameLevel() + 5)
        closeBtn:SetScript("OnClick", function() m.closeSettings() end)
    else
        -- Title bar
        local titleBar = CreateFrame("Frame", nil, s)
        titleBar:SetPoint("TopLeft",  s, "TopLeft",  1, -1)
        titleBar:SetPoint("TopRight", s, "TopRight", -1, -1)
        titleBar:SetHeight(22)
        titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        titleBar:SetBackdropColor(0.22, 0.08, 0.38, 1)

        local grad = titleBar:CreateTexture(nil, "OVERLAY")
        grad:SetAllPoints(titleBar)
        grad:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        grad:SetBlendMode("ADD")
        grad:SetVertexColor(0.2, 0.05, 0.4, 0.4)

        local title = titleBar:CreateFontString(nil, "OVERLAY")
        title:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        title:SetPoint("Left", titleBar, "Left", 6, 0)
        title:SetText("|cffffd700Soulstone Tracker — Settings|r")

        local closeBtn = CreateFrame("Button", nil, titleBar)
        closeBtn:SetWidth(18) closeBtn:SetHeight(18)
        closeBtn:SetPoint("Right", titleBar, "Right", -4, 0)
        local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
        closeTxt:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
        closeTxt:SetAllPoints(closeBtn) closeTxt:SetJustifyH("Center") closeTxt:SetJustifyV("Middle")
        closeTxt:SetText("|cffaaaaaaX|r")
        closeBtn:SetScript("OnEnter", function() closeTxt:SetText("|cffffffffX|r") end)
        closeBtn:SetScript("OnLeave", function() closeTxt:SetText("|cffaaaaaaX|r") end)
        closeBtn:SetScript("OnClick", function() m.closeSettings() end)
    end

    -- left / right content edges inside the border
    local LX = 10 + PADX
    local RX = -(10 + PADX)

    -- shared click handling for both checkbox styles
    local function onToggle(key, newVal)
        setCfg(key, newVal)
        -- the theme is applied when the windows are built
        if key == "classicTheme" then
            s.needsReload = true
            say("Theme changes apply after a UI reload.")
        end
        if m.frame then m.refreshBanish() end
    end

    -- Helper to create a toggle checkbox row
    local function makeToggle(parent, label, key, yOff)
        if T.classic then
            -- stock gold-trimmed options checkbox with a white label
            local name = "SSTrackerCheck_"..key
            local cb = CreateFrame("CheckButton", name, parent, "OptionsCheckButtonTemplate")
            cb:SetWidth(22) cb:SetHeight(22)
            cb:SetPoint("TopLeft", parent, "TopLeft", LX - 4, yOff + 4)
            cb:SetHitRectInsets(0, -180, 0, 0)
            local text = getglobal(name.."Text")
            text:SetText(label)
            text:SetTextColor(1, 1, 1)
            cb.key = key
            cb:SetScript("OnClick", function()
                local on = this:GetChecked() and true or false
                if on then PlaySound("igMainMenuOptionCheckBoxOn") else PlaySound("igMainMenuOptionCheckBoxOff") end
                onToggle(this.key, on)
            end)
            cb:SetChecked(cfg(key))
            return cb
        end

        local cb = CreateFrame("Button", nil, parent)
        cb:SetWidth(14) cb:SetHeight(14)
        cb:SetPoint("TopLeft", parent, "TopLeft", LX, yOff)

        local box = cb:CreateTexture(nil, "ARTWORK")
        box:SetAllPoints(cb)
        box:SetTexture("Interface\\Buttons\\WHITE8X8")
        box:SetVertexColor(0.15, 0.15, 0.2, 1)

        local check = cb:CreateTexture(nil, "OVERLAY")
        check:SetAllPoints(cb)
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        check:SetVertexColor(0.6, 0.3, 1, 1)

        local lbl = parent:CreateFontString(nil, "OVERLAY")
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        lbl:SetPoint("Left", cb, "Right", 6, 0)
        lbl:SetText(label)
        lbl:SetTextColor(0.85, 0.85, 0.85, 1)

        cb.check = check
        cb.key   = key
        cb:SetScript("OnClick", function()
            local cur = cfg(this.key)
            if not cur then this.check:Show() else this.check:Hide() end
            onToggle(this.key, not cur)
        end)
        cb:SetScript("OnEnter", function() box:SetVertexColor(0.25, 0.15, 0.35, 1) end)
        cb:SetScript("OnLeave", function() box:SetVertexColor(0.15, 0.15, 0.2, 1) end)

        return cb
    end

    -- Helper for section header
    local function makeHeader(parent, text, yOff)
        if T.classic then
            -- gold label with a silver rule trailing off to its right
            local hdr = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            hdr:SetPoint("TopLeft", parent, "TopLeft", LX - 2, yOff + 6)
            hdr:SetText(text)
            local rule = makeTrailingRule(parent, T)
            local rx = LX - 2 + math.ceil(hdr:GetStringWidth() or 100) + 6
            rule:SetPoint("TopLeft",  parent, "TopLeft",  rx, yOff)
            rule:SetPoint("TopRight", parent, "TopRight", RX, yOff)
            return hdr
        end

        local div = parent:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1)
        div:SetPoint("TopLeft",  parent, "TopLeft",  6, yOff)
        div:SetPoint("TopRight", parent, "TopRight", -6, yOff)
        div:SetTexture(0.3, 0.15, 0.5, 0.8)

        local hdr = parent:CreateFontString(nil, "OVERLAY")
        hdr:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        hdr:SetTextColor(0.7, 0.5, 1, 1)
        hdr:SetPoint("TopLeft", parent, "TopLeft", 10, yOff + 5)
        hdr:SetText(string.upper(text))
        return hdr
    end

    -- label + value line above a slider, styled per theme
    local function sliderLabels(parent, label, yOff)
        local lbl = parent:CreateFontString(nil, "OVERLAY")
        local valLbl = parent:CreateFontString(nil, "OVERLAY")
        if T.classic then
            lbl:SetFontObject(GameFontHighlightSmall)
            valLbl:SetFontObject(GameFontNormalSmall)
        else
            lbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            lbl:SetTextColor(0.85, 0.85, 0.85, 1)
            valLbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            valLbl:SetTextColor(0.6, 0.3, 1, 1)
        end
        lbl:SetPoint("TopLeft", parent, "TopLeft", LX, yOff)
        lbl:SetText(label)
        valLbl:SetPoint("TopRight", parent, "TopRight", RX, yOff)
        valLbl:SetJustifyH("Right")
        return lbl, valLbl
    end

    -- Helper for number input
    local function makeSlider(parent, label, key, minV, maxV, step, yOff)
        local lbl, valLbl = sliderLabels(parent, label, yOff)

        local sliderName = "SSTracker_Slider_"..key
        local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
        slider:SetWidth(SW - 30)
        slider:SetHeight(16)
        slider:SetPoint("TopLeft", parent, "TopLeft", LX, yOff - 14)
        slider:SetMinMaxValues(minV, maxV)
        slider:SetValueStep(step)
        slider:SetValue(cfg(key))
        getglobal(sliderName.."Low"):SetText(tostring(minV))
        getglobal(sliderName.."High"):SetText(tostring(maxV))
        local sliderText = getglobal(sliderName.."Text")
        sliderText:SetText(tostring(cfg(key)))
        if T.classic then sliderText:Hide() else sliderText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE") end
        slider.key = key
        slider.valLbl = valLbl
        slider:SetScript("OnValueChanged", function()
            local v = math.floor(this:GetValue() / step + 0.5) * step
            setCfg(this.key, v)
            getglobal(this:GetName().."Text"):SetText(tostring(v))
            this.valLbl:SetText(tostring(v))
        end)
        valLbl:SetText(tostring(cfg(key)))
        return slider
    end

    -- Dedicated slider for frameAlpha specifically: displays as a 0-100%
    -- percentage (more intuitive) while storing/reading the underlying
    -- 0-1 float config value, and applies live rather than requiring reopen.
    local function makeAlphaSlider(parent, label, yOff)
        local lbl, valLbl = sliderLabels(parent, label, yOff)

        local sliderName = "SSTracker_Slider_frameAlpha"
        local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
        slider:SetWidth(SW - 30)
        slider:SetHeight(16)
        slider:SetPoint("TopLeft", parent, "TopLeft", LX, yOff - 14)
        slider:SetMinMaxValues(10, 100)
        slider:SetValueStep(5)
        local startPct = math.floor(cfg("frameAlpha") * 100 + 0.5)
        slider:SetValue(startPct)
        getglobal(sliderName.."Low"):SetText("10%")
        getglobal(sliderName.."High"):SetText("100%")
        local sliderText = getglobal(sliderName.."Text")
        sliderText:SetText(startPct.."%")
        if T.classic then sliderText:Hide() else sliderText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE") end
        slider.valLbl = valLbl
        slider:SetScript("OnValueChanged", function()
            local pct = math.floor(this:GetValue() / 5 + 0.5) * 5
            setCfg("frameAlpha", pct / 100)
            getglobal(this:GetName().."Text"):SetText(pct.."%")
            this.valLbl:SetText(pct.."%")
            m.refreshBanish()
        end)
        valLbl:SetText(startPct.."%")
        return slider
    end

    -- Helper for action button
    local btnCount = 0
    local function makeButton(parent, label, onClick, yOff)
        if T.classic then
            -- stock red-and-gold panel button
            btnCount = btnCount + 1
            local btn = CreateFrame("Button", "SSTrackerSettingsButton"..btnCount, parent, "UIPanelButtonTemplate")
            btn:SetWidth(SW - 20) btn:SetHeight(22)
            btn:SetPoint("TopLeft", parent, "TopLeft", LX, yOff)
            btn:SetText(label)
            btn:SetScript("OnClick", onClick)
            return btn
        end

        local btn = CreateFrame("Button", nil, parent)
        btn:SetWidth(SW - 20) btn:SetHeight(20)
        btn:SetPoint("TopLeft", parent, "TopLeft", LX, yOff)
        btn:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1, insets={left=1,right=1,top=1,bottom=1} })
        btn:SetBackdropColor(0.15, 0.08, 0.25, 1)
        btn:SetBackdropBorderColor(0.4, 0.2, 0.6, 0.8)
        local txt = btn:CreateFontString(nil, "OVERLAY")
        txt:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        txt:SetAllPoints(btn) txt:SetJustifyH("Center") txt:SetJustifyV("Middle")
        txt:SetText(label)
        txt:SetTextColor(0.85, 0.85, 0.85, 1)
        btn:SetScript("OnEnter", function() btn:SetBackdropColor(0.25, 0.12, 0.4, 1) end)
        btn:SetScript("OnLeave", function() btn:SetBackdropColor(0.15, 0.08, 0.25, 1) end)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    -- Store checkboxes for refresh
    s.checks = {}
    s.needsReload = false
    -- classic: start below the gold header plate, and give each section
    -- header a little air above and below
    local y = T.classic and -34 or -28
    local HGAP = T.classic and 6 or 0

    -- NOTIFICATIONS section
    y = y - HGAP makeHeader(s, "Notifications", y) y = y - 14 - HGAP
    s.checks["warnOnCast"]    = makeToggle(s, "Play sound on soulstone cast",       "warnOnCast",    y) y = y - 18
    s.checks["warnFiveMin"]   = makeToggle(s, "Warn when soulstone nears expiry",    "warnFiveMin",   y) y = y - 18
    s.checks["warnOneMin"]    = makeToggle(s, "Warn at final countdown",             "warnOneMin",    y) y = y - 18
    s.checks["warnExpired"]   = makeToggle(s, "Alert when soulstone expires",        "warnExpired",   y) y = y - 18
    s.checks["warnNoStones"]  = makeToggle(s, "Alert when no stones remain",         "warnNoStones",  y) y = y - 18
    s.checks["warnWarlocks"]  = makeToggle(s, "List warlocks with available SS",     "warnWarlocks",  y) y = y - 24

    -- SOUNDS section
    y = y - HGAP makeHeader(s, "Sounds", y) y = y - 14 - HGAP
    s.checks["muteSounds"]    = makeToggle(s, "Mute all sounds",                     "muteSounds",    y) y = y - 24

    -- RAID CHAT section
    y = y - HGAP makeHeader(s, "Raid Chat Announcements", y) y = y - 14 - HGAP
    s.checks["muteChat"]         = makeToggle(s, "Mute all raid chat",               "muteChat",         y) y = y - 18
    s.checks["announceOnCast"]   = makeToggle(s, "Announce soulstone casts",         "announceOnCast",   y) y = y - 18
    s.checks["announceWarnings"] = makeToggle(s, "Announce expiry warnings",         "announceWarnings", y) y = y - 18
    s.checks["announceExpired"]  = makeToggle(s, "Announce when stone expires",      "announceExpired",  y) y = y - 18
    s.checks["announceCurse"]    = makeToggle(s, "Announce curse assignments",       "announceCurse",    y) y = y - 18
    s.checks["announceBanish"]   = makeToggle(s, "Announce banish assignments",      "announceBanish",   y) y = y - 24

    -- DISPLAY section
    y = y - HGAP makeHeader(s, "Display", y) y = y - 14 - HGAP
    s.checks["showCurseSection"]  = makeToggle(s, "Show curse & banish section",     "showCurseSection",  y) y = y - 24
    s.checks["hideWhenSolo"]      = makeToggle(s, "Hide when not in party/raid",     "hideWhenSolo",       y) y = y - 24
    s.checks["classicTheme"]      = makeToggle(s, "Classic WoW look (needs reload)", "classicTheme",       y) y = y - 24
    s.alphaSlider = makeAlphaSlider(s, "Background transparency:", y) y = y - 46

    -- TIMING section
    y = y - HGAP makeHeader(s, "Warning Thresholds", y) y = y - 14 - HGAP
    s.warnMinSlider = makeSlider(s, "First warning (minutes):", "warnMinutes", 1, 15, 1, y) y = y - (T.classic and 44 or 36)
    s.warnSecSlider = makeSlider(s, "Final warning (seconds):", "warnSeconds", 15, 120, 5, y) y = y - 40

    -- ACTION BUTTONS
    y = y - HGAP makeHeader(s, "Actions", y) y = y - 14 - HGAP
    makeButton(s, "Clear all soulstones", function()
        m.stones = {} m.refresh() say("Cleared all soulstones.")
    end, y) y = y - 26
    makeButton(s, "Clear curse assignments", function()
        m.curses = {} m.refreshBanish() say("Cleared curse assignments.")
    end, y) y = y - 26
    makeButton(s, "Clear banish assignments", function()
        m.banish = {} m.refreshBanish() say("Cleared banish assignments.")
    end, y) y = y - 26
    makeButton(s, "Scan group for soulstones", function()
        m.scanForSoulstones()
    end, y) y = y - 26
    makeButton(s, "Scan target for curses", function()
        m.scanForCurses()
    end, y) y = y - 26
    makeButton(s, "Force resync with group", function()
        local channel = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
        if not channel then
            say("Not in a group -- nothing to sync.")
        else
            m.rebroadcastKnownData()
            SendAddonMessage(ADDON_MSG_PREFIX, "SYNCREQ", channel)
            say("Resync requested -- rebroadcast your data and asked others to do the same.")
        end
    end, y) y = y - 26
    makeButton(s, "Reset position & size", function()
        SoulstoneTrackerDB.position = nil
        SoulstoneTrackerDB.size = nil
        s.needsReload = true
        say("Position reset. Reload to apply.")
    end, y)

    s:SetHeight(math.abs(y) + 30 + (T.classic and 6 or 0))
    s:Hide()
    m.settings = s
end

function m.refreshSettings()
    if not m.settings then return end
    local s = m.settings
    for key, cb in pairs(s.checks) do
        if cb.check then
            if cfg(key) then cb.check:Show() else cb.check:Hide() end
        elseif cb.SetChecked then
            cb:SetChecked(cfg(key))
        end
    end
    if s.warnMinSlider then
        s.warnMinSlider:SetValue(cfg("warnMinutes"))
        getglobal(s.warnMinSlider:GetName().."Text"):SetText(tostring(cfg("warnMinutes")))
    end
    if s.warnSecSlider then
        s.warnSecSlider:SetValue(cfg("warnSeconds"))
        getglobal(s.warnSecSlider:GetName().."Text"):SetText(tostring(cfg("warnSeconds")))
    end
    if s.alphaSlider then
        local pct = math.floor(cfg("frameAlpha") * 100 + 0.5)
        s.alphaSlider:SetValue(pct)
        getglobal(s.alphaSlider:GetName().."Text"):SetText(pct.."%")
    end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

-- Track last caster per target using addon messages
-- When YOU cast soulstone, SPELLCAST_START fires, then CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS
-- When OTHERS cast, we only get the buff gain message with no caster info
-- Solution: broadcast via addon message with caster info, and use target unit scanning

local lastCaster = nil
local isSelfCast = false

local eFrame = CreateFrame("Frame")
eFrame:RegisterEvent("PLAYER_LOGIN")
eFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
eFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eFrame:RegisterEvent("BAG_UPDATE")
eFrame:RegisterEvent("SPELLCAST_START")
eFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
eFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS")
eFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS")
eFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
eFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER")
eFrame:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH")
eFrame:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF")
eFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
eFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
eFrame:RegisterEvent("CHAT_MSG_SPELL_DAMAGESHIELDS_SELF")
eFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
eFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
eFrame:RegisterEvent("CHAT_MSG_ADDON")
-- Reliable curse self-detection via nampower, if available. SPELL_GO_SELF
-- is guaranteed to only ever fire for spells the local player casts -- no
-- ambiguous chat-text parsing, unlike the CHAT_MSG_SPELL_* fallback below.
local hasNampower = (GetNampowerVersion ~= nil)
if hasNampower then
    eFrame:RegisterEvent("SPELL_GO_SELF")
    -- Others' casts: gives exact caster/target GUIDs for soulstones cast by
    -- group members who don't run this addon. Filtered by spellId first.
    eFrame:RegisterEvent("SPELL_GO_OTHER")
    -- AURA_CAST_* only matter for /ss diag aura, and (nampower 4.5+) merely
    -- registering an event enables its emission, so they are registered only
    -- while the diagnostic is on -- see m.setAuraDiag.
    function m.setAuraDiag(on)
        m.diagAura = on and true or false
        if on then
            eFrame:RegisterEvent("AURA_CAST_ON_OTHER")
            eFrame:RegisterEvent("AURA_CAST_ON_SELF")
            SetCVar("NP_EnableAuraCastEvents", 1)
        else
            eFrame:UnregisterEvent("AURA_CAST_ON_OTHER")
            eFrame:UnregisterEvent("AURA_CAST_ON_SELF")
            SetCVar("NP_EnableAuraCastEvents", 0)
        end
    end
    -- Fallback for auras without a spell effect component (which
    -- AURA_CAST_ON_OTHER/SELF won't catch) -- Soulstone Resurrection may be
    -- one of these, per nampower's own docs.
    eFrame:RegisterEvent("BUFF_ADDED_SELF")
    eFrame:RegisterEvent("BUFF_ADDED_OTHER")
end

eFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        SoulstoneTrackerDB = SoulstoneTrackerDB or {}
        -- Load config
        if SoulstoneTrackerDB.cfg then
            m.cfg = SoulstoneTrackerDB.cfg
        end

        -- Off on non-warlock characters unless turned on for that character
        -- with /ss enable. Nothing is built and every event is dropped, so a
        -- disabled character costs nothing (and sends nothing to the group).
        SoulstoneTrackerDB.enabledChars = SoulstoneTrackerDB.enabledChars or {}
        if not playerIsWarlock() and not SoulstoneTrackerDB.enabledChars[charKey()] then
            m.disabled = true
            this:UnregisterAllEvents()
            -- tell each character once, so it isn't a mystery later
            SoulstoneTrackerDB.toldDisabled = SoulstoneTrackerDB.toldDisabled or {}
            if not SoulstoneTrackerDB.toldDisabled[charKey()] then
                SoulstoneTrackerDB.toldDisabled[charKey()] = true
                say("Off on this character (not a warlock). Type |cffffd700/ss enable|r to turn it on here.")
            end
            return
        end

        loadAll()
        m.createFrame()
        m.createMinimapButton()
        -- Baseline "ready" state -- purely event-driven now (no cooldown
        -- API works on this client), so without this the display would stay
        -- blank until the first soulstone cast is actually detected this
        -- session. If you're actually still on cooldown from before this
        -- reload, it'll incorrectly show ready until corrected by your next
        -- real cast -- an accepted limitation given no API can tell us.
        -- The ready-at time of our own last cast is persisted, so a reload
        -- or relog mid-cooldown now restores it (item cooldowns tick in
        -- real time, including while offline).
        if playerIsWarlock() then
            local saved = SoulstoneTrackerDB.ssReadyAt and SoulstoneTrackerDB.ssReadyAt[UnitName("player")]
            if saved and saved > time() then
                m.ssCooldowns[UnitName("player")] = saved
            else
                m.ssCooldowns[UnitName("player")] = 0
            end
        end
        if SoulstoneTrackerDB.hidden then m.frame:Hide() else m.frame:Show() end
        if SoulstoneTrackerDB.locked then m.locked = true m.frame.updateLock() end
        m.updateGroupVisibility()
        m.refreshBanish()
        say("Loaded. Type |cffffd700/ss help|r for commands.")
        local t = CreateFrame("Frame") local e = 0
        t:SetScript("OnUpdate", function()
            e = e + arg1
            if e >= 2 then
                t:SetScript("OnUpdate", nil)
                m.scanForSoulstones()
                m.updateAndBroadcastShards()
                m.updateSoulstoneCooldown()
                -- Request sync from others with the addon
                local channel = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
                if channel then
                    SendAddonMessage(ADDON_MSG_PREFIX, "SYNCREQ", channel)
                end
            end
        end)

    elseif event == "PLAYER_LEAVING_WORLD" then
        saveAll()

    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        m.refreshBanish()
        m.updateGroupVisibility()
        -- Debounced scan for existing soulstones on newly-joined members --
        -- without this, a stone already active on someone who just joined
        -- your group wouldn't be picked up until next login/zone change.
        -- Silent unless it actually finds something, and coalesces rapid
        -- roster churn (e.g. several people joining a raid in quick
        -- succession) into a single scan instead of one per event.
        m.debounce("rosterScan", 2, function()
            do
                m.scanForSoulstones(true)
                -- Ask others with the addon to resend their accurate data --
                -- this is what lets a scanned "Unknown"/estimated stone get
                -- corrected once the real caster's client responds. Without
                -- this, joining a raid mid-session (unlike login, which
                -- already does this) would leave scanned entries permanently
                -- estimated.
                local channel = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
                if channel then
                    SendAddonMessage(ADDON_MSG_PREFIX, "SYNCREQ", channel)
                end
            end
        end)

    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Debounced silent curse scan on the new target -- catches curses
        -- from warlocks who don't have the addon (best-effort, no caster
        -- attribution possible). Debounced since target changes can fire
        -- rapidly while tab-targeting.
        m.debounce("targetScan", 0.5, function()
            m.scanForCurses(true)
        end)

    elseif event == "BAG_UPDATE" then
        -- Debounced since bag updates fire once per slot touched, and a
        -- single bag operation (looting, splitting stacks) can touch many.
        m.debounce("shardScan", 1, function()
            m.updateAndBroadcastShards()
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        if m.frame then
            m.debounce("enterWorldScan", 3, function() m.scanForSoulstones() end)
        end

    elseif event == "SPELLCAST_START" then
        -- Only fires for player's own casts
        if arg1 and string.find(arg1, "Soulstone Resurrection") then
            lastCaster = UnitName("player")
            isSelfCast = true
            -- Broadcast that we're casting so others know the caster
            if GetNumRaidMembers() > 0 then
                SendAddonMessage(ADDON_MSG_PREFIX, "CASTING:"..UnitName("player")..">"..UnitName("target"), "RAID")
            elseif GetNumPartyMembers() > 0 then
                SendAddonMessage(ADDON_MSG_PREFIX, "CASTING:"..UnitName("player")..">"..UnitName("target"), "PARTY")
            end
        end
        -- Track curse caster (you casting)
        for fullName in pairs(SHORT_NAMES) do
            if arg1 and string.find(arg1, fullName) then
                lastCurseCaster = UnitName("player")
                break
            end
        end

    elseif event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then
        -- "You gain Soulstone Resurrection (1)." - you received a soulstone
        -- Only apply locally if we're confident who cast it (lastCaster set
        -- via our own SPELLCAST_START, or received via the CASTING: sync).
        -- Otherwise skip rather than guessing "Unknown" and broadcasting a
        -- wrong/premature attribution that could race the real caster's own.
        if arg1 and string.find(arg1, "Soulstone Resurrection") and lastCaster then
            m.addStone(UnitName("player"), lastCaster, nil, not isSelfCast)
            if isSelfCast then m.startOwnSoulstoneCooldown() end
            lastCaster = nil
        end

    elseif event == "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS"
        or event == "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS" then
        -- "Playername gains Soulstone Resurrection (1)." -- fallback for
        -- when BUFF_ADDED_OTHER doesn't fire/isn't available; usually
        -- already a no-op since lastCaster gets consumed by BUFF_ADDED_OTHER
        -- first when it fires.
        if arg1 then
            local suffix = " gains Soulstone Resurrection"
            local pos = string.find(arg1, suffix, 1, true)
            local target = pos and string.sub(arg1, 1, pos - 1)
            if target and target ~= "" and lastCaster then
                m.addStone(target, lastCaster, nil, not isSelfCast)
                if isSelfCast then m.startOwnSoulstoneCooldown() end
                lastCaster = nil
            end
        end

    elseif event == "CHAT_MSG_SPELL_AURA_GONE_SELF" then
        if arg1 and string.find(arg1, "Soulstone Resurrection") then
            m.removeStone(UnitName("player"))
        end
        m.removeCurse(arg1 or "")

    elseif event == "CHAT_MSG_SPELL_AURA_GONE_OTHER" then
        if arg1 then
            local _, _, target = string.find(arg1, "Soulstone Resurrection fades from (.+)%.")
            if target then m.removeStone(target) end
            m.removeCurse(arg1)
        end

    elseif event == "SPELL_GO_SELF" then
        -- itemId, spellID, casterGuid, targetGuid, castFlags, numTargetsHit, numTargetsMissed
        local spellID = arg2
        local shortName = m.classifySpell(spellID)
        if shortName == "SS" then shortName = nil end
        if shortName then
            -- Guaranteed self-scoped by nampower, so always safe to
            -- attribute directly to the local player.
            m.detectCurse(FULL_NAMES[shortName], UnitName("player"))
        end
        m.updateSoulstoneCooldown()

    elseif event == "SPELL_GO_OTHER" then
        -- itemId, spellId, casterGuid, targetGuid, castFlags, ...
        -- Cheap early filter: this fires for every spell cast near us.
        if m.classifySpell(arg2) == "SS" then
            local casterName = UnitName(arg3)
            local targetName = UnitName(arg4)
            if m.diagAura then
                say("|cff00ff00[DIAG]|r SPELL_GO_OTHER soulstone: spellId="..tostring(arg2).." caster="..tostring(casterName).." target="..tostring(targetName))
            end
            -- Only group members' stones; silent (the caster's own client
            -- is the one that broadcasts/announces, as before).
            if casterName and targetName and m.isInGroup(casterName) then
                local ex = m.stones[targetName]
                if not (ex and ex.caster == casterName and (time() - (ex.castTime or 0)) < 5) then
                    m.addStone(targetName, casterName, time() + SOULSTONE_DURATION, true)
                end
            end
        end

    elseif event == "AURA_CAST_ON_OTHER" or event == "AURA_CAST_ON_SELF" then
        -- spellId, casterGuid, targetGuid, effect, effectAuraName, effectAmplitude, effectMiscValue, durationMs, auraCapStatus
        if m.diagAura then
            local targetName = UnitName(arg3) or tostring(arg3)
            say("|cff00ff00[DIAG]|r "..event..": spellId="..tostring(arg1).." target="..tostring(targetName).." durationMs="..tostring(arg8))
        end

    elseif event == "BUFF_ADDED_SELF" then
        -- guid, slot, spellId, stackCount, casterLevel (confirmed via live
        -- testing: casterLevel matched Waylock's actual level of 60).
        -- Precise soulstone detection: only trusted when we're already
        -- confident WE are the one mid-cast (lastCaster set via our own
        -- SPELLCAST_START) -- this event alone doesn't tell us who cast it,
        -- so blindly trusting it would reintroduce the same cross-warlock
        -- misattribution risk we already fixed for curses.
        if arg3 == SOULSTONE_SPELL_ID and lastCaster then
            m.addStone(UnitName("player"), lastCaster, time() + SOULSTONE_DURATION, not isSelfCast)
            if isSelfCast then m.startOwnSoulstoneCooldown() end
            lastCaster = nil
        end
        if m.diagAura then
            say("|cff00ff00[DIAG]|r BUFF_ADDED_SELF: a1="..tostring(arg1).." a2="..tostring(arg2).." a3="..tostring(arg3).." a4="..tostring(arg4).." a5="..tostring(arg5))
        end

    elseif event == "BUFF_ADDED_OTHER" then
        -- guid, slot, spellId, stackCount, casterLevel
        if arg3 == SOULSTONE_SPELL_ID and lastCaster then
            local targetName = UnitName(arg1)
            if targetName then
                m.addStone(targetName, lastCaster, time() + SOULSTONE_DURATION, not isSelfCast)
                if isSelfCast then m.startOwnSoulstoneCooldown() end
                lastCaster = nil
            end
        end
        if m.diagAura then
            say("|cff00ff00[DIAG]|r BUFF_ADDED_OTHER: a1="..tostring(arg1).." a2="..tostring(arg2).." a3="..tostring(arg3).." a4="..tostring(arg4).." a5="..tostring(arg5))
        end

    elseif event == "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF"
        or event == "CHAT_MSG_SPELL_SELF_DAMAGE"
        or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE"
        or event == "CHAT_MSG_SPELL_DAMAGESHIELDS_SELF"
        or event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"
        or event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" then
        -- When nampower is available, SPELL_GO_SELF above is the reliable
        -- source of truth for local curse casts, so this ambiguous
        -- chat-text fallback is skipped entirely to avoid the cross-warlock
        -- misattribution these shared-visibility channels can cause. This
        -- does mean a curse rank not yet in CURSE_SPELL_IDS above simply
        -- won't register -- add its spellID there rather than re-enabling
        -- this fallback. Without nampower at all, use best-effort behavior.
        if arg1 and not hasNampower then
            m.detectCurse(arg1, lastCurseCaster or UnitName("player"))
            lastCurseCaster = nil
        end

    elseif event == "CHAT_MSG_COMBAT_FRIENDLY_DEATH" then
        if arg1 then
            local _, _, dead = string.find(arg1, "(.+) dies%.")
            if dead and m.stones[dead] then m.removeStone(dead) end
        end

    elseif event == "CHAT_MSG_ADDON" then
        -- arg1=prefix arg2=message arg3=channel arg4=sender
        if arg1 == ADDON_MSG_PREFIX then
            if string.find(arg2, "^CASTING:") then
                local rest = string.sub(arg2, 9) -- strip leading "CASTING:" (8 chars)
                local gtPos = string.find(rest, ">", 1, true)
                local caster = gtPos and string.sub(rest, 1, gtPos - 1)
                local target = gtPos and string.sub(rest, gtPos + 1)
                if caster and target and caster ~= "" and target ~= "" and arg4 ~= UnitName("player") then
                    lastCaster = caster
                    isSelfCast = false
                end
            elseif string.find(arg2, "^ADD:") then
                local rest = string.sub(arg2, 5) -- strip leading "ADD:" (4 chars)
                local p1 = string.find(rest, ":", 1, true)
                local target = p1 and string.sub(rest, 1, p1 - 1)
                local rest2 = p1 and string.sub(rest, p1 + 1)
                local p2 = rest2 and string.find(rest2, ":", 1, true)
                local caster = p2 and string.sub(rest2, 1, p2 - 1)
                local expires = p2 and string.sub(rest2, p2 + 1)
                if target and caster and expires and target ~= "" and caster ~= "" and expires ~= "" and arg4 ~= UnitName("player") then
                    m.addStone(target, caster, tonumber(expires), true)
                end
            elseif string.find(arg2, "^REM:") then
                local target = string.sub(arg2, 5) -- strip leading "REM:" (4 chars)
                if target and target ~= "" then m.removeStone(target, true) end
            elseif string.find(arg2, "^BANISH:") then
                local rest = string.sub(arg2, 8) -- strip leading "BANISH:" (7 chars)
                local colonPos = string.find(rest, ":", 1, true)
                local wName = colonPos and string.sub(rest, 1, colonPos - 1)
                local iconIdx = colonPos and string.sub(rest, colonPos + 1)
                if wName and iconIdx and wName ~= "" and iconIdx ~= "" and arg4 ~= UnitName("player") then
                    local idx = tonumber(iconIdx)
                    if idx == 0 then
                        m.banish[wName] = nil
                    else
                        m.banish[wName] = idx
                    end
                    m.refreshBanish()
                end
            elseif string.find(arg2, "^CURSE:") then
                local rest = string.sub(arg2, 7) -- strip leading "CURSE:" (6 chars)
                local colonPos = string.find(rest, ":", 1, true)
                local shortName = colonPos and string.sub(rest, 1, colonPos - 1)
                local caster = colonPos and string.sub(rest, colonPos + 1)
                if shortName and caster and shortName ~= "" and caster ~= "" and arg4 ~= UnitName("player") then
                    m.curses[shortName] = { caster=caster }
                    m.refresh()
                end
            elseif string.find(arg2, "^CURSEREM:") then
                local shortName = string.sub(arg2, 10) -- strip leading "CURSEREM:" (9 chars)
                if shortName and shortName ~= "" and arg4 ~= UnitName("player") then
                    m.curses[shortName] = nil
                    m.refresh()
                end
            elseif string.find(arg2, "^SHARDS:") then
                local countStr = string.sub(arg2, 8) -- strip leading "SHARDS:" (7 chars)
                local count = tonumber(countStr)
                if count and arg4 ~= UnitName("player") then
                    m.shardCounts[arg4] = count
                    m.refreshBanish()
                end
            elseif string.find(arg2, "^SSCD:") then
                local readyAtStr = string.sub(arg2, 6) -- strip leading "SSCD:" (5 chars)
                local readyAt = tonumber(readyAtStr)
                if readyAt and arg4 ~= UnitName("player") then
                    m.ssCooldowns[arg4] = readyAt
                    m.refreshBanish()
                end
            elseif arg2 == "SYNCREQ" and arg4 ~= UnitName("player") then
                m.rebroadcastKnownData()
            end
        end
    end
end)

-------------------------------------------------------------------------------
-- Slash
-------------------------------------------------------------------------------

SLASH_SOULSTONETRACKER1 = "/ss"
SLASH_SOULSTONETRACKER2 = "/soulstone"
SlashCmdList["SOULSTONETRACKER"] = function(args)
    args = args or ""
    local cmd = string.lower(string.gsub(args, "^%s*(.-)%s*$", "%1"))

    -- per-character on/off for non-warlocks (warlocks always have it on)
    if cmd == "enable" or cmd == "disable" then
        if playerIsWarlock() then
            say("Always on for warlocks.")
            return
        end
        local on = (cmd == "enable")
        local was = SoulstoneTrackerDB.enabledChars[charKey()] and true or false
        SoulstoneTrackerDB.enabledChars[charKey()] = on or nil
        if on == was then
            say(on and "Already on for this character." or "Already off for this character.")
        elseif on == not m.disabled then
            say(on and "Turned on for this character." or "Turned off for this character.")
        else
            say((on and "Turned on" or "Turned off").." for this character. Reload the UI to apply.")
            StaticPopup_Show("SOULSTONETRACKER_RELOAD")
        end
        return
    end
    if m.disabled then
        say("Off on this character (not a warlock). Type |cffffd700/ss enable|r to turn it on here.")
        return
    end

    if cmd == "clear" then
        m.stones = {} m.refresh() say("Cleared all soulstones.")

    elseif string.find(cmd, "^testcurse") then
        local _, _, sn, caster = string.find(args, "%a+%s+(%a+)%s*(%a*)")
        sn = sn or "CoE"
        local CURSE_LOOKUP = { coe="CoE", cos="CoS", cor="CoR", cow="CoW" }
        sn = CURSE_LOOKUP[string.lower(sn)] or sn
        if not CURSE_COLORS[sn] then
            say("Unknown curse short name |cffffffff"..sn.."|r. Use one of: |cffffd700CoE, CoS, CoR, CoW|r")
        else
            caster = (caster ~= "" and caster) or UnitName("player")
            -- Injects directly into m.curses exactly like the CHAT_MSG_ADDON
            -- "CURSE:" receive-branch does, to simulate a sync arriving from
            -- another player without needing a second client.
            m.curses[sn] = { caster = caster }
            m.refresh()
            say("Simulated sync: |cffa050ff"..caster.."|r -> "..(CURSE_COLORS[sn] or "|cffffffff")..sn.."|r (as if received from another player)")
            -- The curse/banish section only draws a row for your own name or
            -- an actual Warlock currently in your raid/party, so a made-up
            -- name won't visibly appear even though it's tracked internally.
            if caster ~= UnitName("player") then
                local isRealWarlock = false
                local numRaid = GetNumRaidMembers()
                if numRaid > 0 then
                    for i = 1, numRaid do
                        local n, _, _, _, class = GetRaidRosterInfo(i)
                        if n == caster and class == "Warlock" then isRealWarlock = true break end
                    end
                else
                    for i = 1, GetNumPartyMembers() do
                        if UnitName("party"..i) == caster and UnitClass("party"..i) == "Warlock" then
                            isRealWarlock = true break
                        end
                    end
                end
                if not isRealWarlock then
                    say("|cffff7c0aNote:|r "..caster.." isn't a Warlock in your current group, so no row will show for them. Use your own name or an actual grouped warlock to see it rendered.")
                end
            end
        end

    elseif string.find(cmd, "^testcast") then
        local _, _, target, caster, secs = string.find(args, "%a+%s+(%a+)%s*(%a*)%s*(%d*)")
        if not target then
            say("Usage: |cffffd700/ss testcast <target> [caster] [seconds]|r")
        else
            caster = (caster ~= "" and caster) or UnitName("player")
            local duration = (secs ~= "" and tonumber(secs)) or (30 * 60)
            m.addStone(target, caster, time() + duration)
            say("Test stone: |cffa050ff"..caster.."|r -> |cffffffff"..target.."|r ("..duration.."s)")
        end

    elseif string.find(cmd, "^test") then
        local _, _, secs = string.find(cmd, "test%s+(%d+)")
        local duration = tonumber(secs) or (30 * 60)
        m.addStone(UnitName("player"), UnitName("player"), time() + duration)
        if secs then
            say("Test stone added with "..secs.."s duration.")
        else
            say("Test stone added. Use |cffffd700/ss test 90|r to test with 90 seconds.")
        end

    elseif cmd == "scan" then
        m.scanForSoulstones()

    elseif cmd == "scancurse" then
        m.scanForCurses()

    elseif cmd == "shards" then
        m.updateAndBroadcastShards()
        local any = false
        for name, count in pairs(m.shardCounts) do
            any = true
            say(classColorName(name, "|cffa050ff").." — "..count.." shards")
        end
        if not any then say("No shard data yet.") end

    elseif cmd == "sscd" then
        m.updateSoulstoneCooldown()
        local any = false
        for name, readyAt in pairs(m.ssCooldowns) do
            any = true
            if readyAt > time() then
                say(classColorName(name, "|cffa050ff").." — |cffff6666"..formatTime(readyAt - time()).." until ready|r")
            else
                say(classColorName(name, "|cffa050ff").." — |cff00ff00ready now|r")
            end
        end
        if not any then
            say("No soulstone cooldown data yet. (Requires nampower; won't work for non-warlocks.)")
        end

    elseif string.find(cmd, "^history") then
        local numStr = string.find(cmd, " ") and string.sub(cmd, string.find(cmd, " ") + 1)
        local n = (numStr and tonumber(numStr)) or 15
        local total = table.getn(m.history)
        if total == 0 then
            say("No history logged this session yet.")
        else
            say("Last "..math.min(n, total).." event(s) this session:")
            local start = math.max(1, total - n + 1)
            for i = start, total do
                local entry = m.history[i]
                local elapsed = time() - entry.time
                local ago
                if elapsed < 60 then
                    ago = elapsed.."s ago"
                else
                    ago = math.floor(elapsed/60).."m ago"
                end
                say("|cff888888["..ago.."]|r "..entry.text)
            end
        end

    elseif cmd == "resync" then
        local channel = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
        if not channel then
            say("Not in a group -- nothing to sync.")
        else
            m.rebroadcastKnownData()
            SendAddonMessage(ADDON_MSG_PREFIX, "SYNCREQ", channel)
            say("Resync requested -- rebroadcast your data and asked others to do the same.")
        end

    elseif cmd == "list" then
        local n = 0
        for target, data in pairs(m.stones) do
            local s = timeLeft(data.expires)
            say(data.caster.." -> "..target.." ("..math.floor(s/60).."m "..math.mod(s,60).."s)")
            n = n + 1
        end
        if n == 0 then say("No active soulstones.") end

    elseif cmd == "warlocks" then
        local missing = getWarlocksMissingStones()
        if table.getn(missing) == 0 then
            say("All warlocks have active soulstones!")
        else
            say("|cffff7c0aMissing: |cffffffff"..table.concat(missing, ", ").."|r")
        end

    elseif string.find(cmd, "^diag") then
        local spacePos = string.find(cmd, " ", 1, true)
        local sub = spacePos and string.sub(cmd, spacePos + 1)
        if sub == "aura" then
            if m.setAuraDiag then
                m.setAuraDiag(not m.diagAura)
            else
                m.diagAura = not m.diagAura
            end
            say("Aura-cast diagnostic "..(m.diagAura and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r")..". Cast/receive anything to see spellId/target/durationMs in chat.")
        else
            -- On-demand diagnostic: reveal exact string contents (including
            -- hidden whitespace or realm suffixes) of both the roster-derived
            -- warlock names and the synced curse caster names, since they can
            -- look identical on screen but fail an exact string match in code.
            local playerName = UnitName("player")
            say("|cff00ff00[DIAG]|r player = "..string.format("%q", playerName))
            local numRaid = GetNumRaidMembers()
            if numRaid > 0 then
                for i = 1, numRaid do
                    local name, _, _, _, class = GetRaidRosterInfo(i)
                    if name and class == "Warlock" then
                        say("|cff00ff00[DIAG]|r roster warlock = "..string.format("%q", name))
                    end
                end
            else
                for i = 1, GetNumPartyMembers() do
                    local name = UnitName("party"..i)
                    if name and UnitClass("party"..i) == "Warlock" then
                        say("|cff00ff00[DIAG]|r roster warlock = "..string.format("%q", name))
                    end
                end
            end
            local any = false
            for sn, data in pairs(m.curses) do
                any = true
                say("|cff00ff00[DIAG]|r m.curses["..sn.."].caster = "..string.format("%q", data.caster or "nil"))
            end
            if not any then say("|cff00ff00[DIAG]|r m.curses is empty") end
        end

    elseif cmd == "lock" then
        m.locked = not m.locked
        SoulstoneTrackerDB.locked = m.locked
        m.frame.updateLock()
        say(m.locked and "Frame locked." or "Frame unlocked.")

    elseif cmd == "curses" then
        local n = 0
        for shortName, data in pairs(m.curses) do
            say((CURSE_COLORS[shortName] or "|cffffffff")..shortName.."|r — "..data.caster.." on "..data.target)
            n = n + 1
        end
        if n == 0 then say("No active curses tracked.") end

    elseif cmd == "clearcurses" then
        m.curses = {}
        m.refresh()
        say("Cleared all curse assignments.")

    elseif cmd == "clearbanish" then
        m.banish = {}
        m.refreshBanish()
        say("Cleared all banish assignments.")
        local channel = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
        if channel then
            SendAddonMessage(ADDON_MSG_PREFIX, "SYNCREQ", channel)
            say("Requesting sync from others with SoulstoneTracker...")
        end

    elseif cmd == "reset" then
        SoulstoneTrackerDB.position = nil
        SoulstoneTrackerDB.size = nil
        SoulstoneTrackerDB.scale = nil
        say("Position/size reset. /reload to apply.")

    elseif string.find(cmd, "^scale") then
        local _, _, val = string.find(cmd, "scale%s+([%d%.]+)")
        local scale = tonumber(val)
        if scale and scale >= 0.5 and scale <= 2.0 then
            m.frame:SetScale(scale)
            SoulstoneTrackerDB.scale = scale
            say("Scale set to "..scale)
        else
            say("Usage: /ss scale 0.5-2.0  (e.g. /ss scale 0.8)")
        end

    elseif string.find(cmd, "^theme") then
        local _, _, which = string.find(cmd, "^theme%s*(%a*)")
        if which == "classic" or which == "shadow" then
            setCfg("classicTheme", which == "classic")
            if m.settings and m.settings.checks and m.settings.checks["classicTheme"] then
                m.refreshSettings()
            end
            say("Theme set to "..which..". /reload to apply.")
        else
            say("Theme: "..(cfg("classicTheme") and "classic" or "shadow")..
                ".  Usage: /ss theme classic, or /ss theme shadow")
        end

    elseif cmd == "help" then
        say("|cffffd700Commands:|r")
        say("|cffffd700/ss|r — toggle window")
        say("|cffffd700/ss test|r — add test stone (30 min)")
        say("|cffffd700/ss test 90|r — add test stone with 90 second duration")
        say("|cffffd700/ss clear|r — clear all stones")
        say("|cffffd700/ss list|r — list active stones in chat")
        say("|cffffd700/ss curses|r — list active curse assignments")
        say("|cffffd700/ss testcurse CoE Bob|r — simulate a curse sync from 'Bob' (CoE/CoS/CoR/CoW)")
        say("|cffffd700/ss testcast Bob Waylock 90|r — simulate Waylock soulstoning Bob, 90s")
        say("|cffffd700/ss clearcurses|r — clear curse assignments")
        say("|cffffd700/ss lock|r — toggle frame lock")
        say("|cffffd700/ss scale 0.8|r — resize (0.5-2.0)")
        if not playerIsWarlock() then
            say("|cffffd700/ss disable|r — turn the addon off on this (non-warlock) character")
        end
        say("|cffffd700/ss theme classic|r or |cffffd700shadow|r — Blizzard look or the original purple look (needs /reload)")
        say("|cffffd700/ss scan|r — scan group for existing stones")
        say("|cffffd700/ss scancurse|r — scan your target for curses (unknown caster)")
        say("|cffffd700/ss resync|r — force resync of known data with group")
        say("|cffffd700/ss shards|r — list known soul shard counts")
        say("|cffffd700/ss sscd|r — list soulstone-creation cooldowns")
        say("|cffffd700/ss history [n]|r — show last n session events (default 15)")
        say("|cffffd700/ss diag aura|r — toggle live aura-cast spellId/duration diagnostic")
        say("|cffffd700/ss reset|r — reset position and size")

    else
        if m.frame and m.frame:IsVisible() then
            m.frame:Hide() SoulstoneTrackerDB.hidden = true say("Hidden.")
        else
            if not m.frame then m.createFrame() end
            m.frame:Show() SoulstoneTrackerDB.hidden = false say("Shown.")
        end
    end
end
