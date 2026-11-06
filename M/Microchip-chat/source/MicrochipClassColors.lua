-- Microchip-chat: player-name class colors for vanilla 1.12 (Lua 5.0).
-- Chat events do not contain reliable class metadata. Cache classes learned
-- from native unit, raid, guild, friend and /who information; do not guess.
MCClassColors = {}

local colors = {
    PALADIN="F58CBA", SHAMAN="0070DE", HUNTER="ABD473",
    WARLOCK="9482C9", WARRIOR="C79C6E", ROGUE="FFF569",
    PRIEST="FFFFFF", DRUID="FF7D0A", MAGE="69CCF0"
}
local known = {}
local localized = {}

local function normalizeClass(value)
    if type(value)~="string" then return nil end
    local english=string.upper(value)
    if colors[english] then return english end
    return localized[value] or localized[english]
end

local function playerKey(name)
    if type(name)~="string" or name=="" then return nil end
    return string.lower(name)
end

local function learn(name,class)
    local key=playerKey(name)
    local token=normalizeClass(class)
    if not key or not token or known[key]==token then return false end
    known[key]=token
    return true
end

-- Prat keeps its own class cache. Reuse it when Prat is already installed,
-- but never require Prat (or any of its Ace libraries) to be present.
-- Native unit/roster information takes priority over this optional cache.
local function learnPrat()
    local prat=Prat_PlayerNames
    if type(prat)~="table" then return false end
    local changed=false
    local function import(source)
        if type(source)~="table" then return end
        local name,class
        for name,class in pairs(source) do
            if type(name)=="string" and not known[playerKey(name)] then
                if learn(name,class) then changed=true end
            end
        end
    end
    import(prat.Classes)
    if prat.db and prat.db.profile then import(prat.db.profile.classes) end
    return changed
end

local function learnUnit(unit)
    if not UnitExists or not UnitName or not UnitClass or not UnitExists(unit) then return false end
    local name=UnitName(unit)
    local localizedClass,englishClass=UnitClass(unit)
    return learn(name,englishClass or localizedClass)
end

function MCClassColors.Initialize(saved)
    known=type(saved)=="table" and saved or {}
    if type(LOCALIZED_CLASS_NAMES_MALE)=="table" then
        for token,name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
            if colors[token] then localized[name]=token end
        end
    end
    if type(LOCALIZED_CLASS_NAMES_FEMALE)=="table" then
        for token,name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
            if colors[token] then localized[name]=token end
        end
    end
    -- Keep the saved table in place so new class discoveries are persisted.
    -- Prat cache is an optional bootstrap source, not a dependency.
    learnPrat()
    local changed=MCClassColors.RefreshUnits()
    return known,changed
end

function MCClassColors.Remember(name,class)
    return learn(name,class)
end

function MCClassColors.Get(name)
    local key=playerKey(name)
    if not key then return nil end
    if known[key] then return known[key] end
    -- An unknown chat sender can be discovered by Prat after our most recent
    -- roster event. Look up only this sender to avoid rescanning large caches
    -- for every World message.
    local prat=Prat_PlayerNames
    if type(prat)=="table" then
        local value=prat.Classes and prat.Classes[name]
        if not value and prat.db and prat.db.profile and prat.db.profile.classes then
            value=prat.db.profile.classes[name]
        end
        if value then learn(name,value) end
    end
    return known[key]
end

function MCClassColors.RefreshPrat()
    return learnPrat()
end

function MCClassColors.Link(name,enabled)
    if type(name)~="string" or name=="" then return "" end
    local class=enabled and MCClassColors.Get(name)
    local hex=(class and colors[class]) or "D4DDE5"
    -- Keep native hyperlinks intact: left click whispers; right click uses
    -- the client's standard player context menu via SetItemRef.
    return "|cff"..hex.."|Hplayer:"..name.."|h["..name.."]|h|r"
end

function MCClassColors.RefreshUnits()
    local changed=learnPrat()
    if learnUnit("player") then changed=true end
    if learnUnit("target") then changed=true end
    if learnUnit("mouseover") then changed=true end
    local i
    for i=1,4 do
        if learnUnit("party"..i) then changed=true end
    end
    local count=GetNumRaidMembers and GetNumRaidMembers() or 0
    if count>0 then
        for i=1,math.min(count,40) do
            if learnUnit("raid"..i) then changed=true end
            -- Prat also learns from GetRaidRosterInfo. The roster is useful
            -- when the client has not instantiated the matching unit token.
            if GetRaidRosterInfo then
                local name,_,_,_,class=GetRaidRosterInfo(i)
                if learn(name,class) then changed=true end
            end
        end
    end
    return changed
end

function MCClassColors.RefreshGuild()
    if not GetNumGuildMembers or not GetGuildRosterInfo then return false end
    local changed=false
    local count=math.min(GetNumGuildMembers() or 0,1000)
    local i
    for i=1,count do
        -- 1.12: name, rank, rankIndex, level, class (localized), ...
        local name,_,_,_,class=GetGuildRosterInfo(i)
        if learn(name,class) then changed=true end
    end
    return changed
end

function MCClassColors.RefreshFriends()
    if not GetNumFriends or not GetFriendInfo then return false end
    local changed=false
    local count=math.min(GetNumFriends() or 0,200)
    local i
    for i=1,count do
        -- 1.12: name, level, class, area, online
        local name,_,class=GetFriendInfo(i)
        if learn(name,class) then changed=true end
    end
    return changed
end

function MCClassColors.RefreshWho()
    if not GetNumWhoResults or not GetWhoInfo then return false end
    local changed=false
    local count=math.min(GetNumWhoResults() or 0,100)
    local i
    for i=1,count do
        -- 1.12: name, guild, level, race, class, zone
        local name,_,_,_,class=GetWhoInfo(i)
        if learn(name,class) then changed=true end
    end
    return changed
end

function MCClassColors.Colors()
    return colors
end
