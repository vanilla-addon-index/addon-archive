-- Microchip-chat's embedded World ad filter (WoW 1.12 / Lua 5.0).
-- Independent compact adaptation of WorldChatFilter's rule-based intent/context
-- approach and 30-second repeat tracking (papafru/WorldChatFilter, MIT).
-- This is NOT a verbatim copy of the upstream multilingual v1.1.2 classifier.
-- World messages are classified once, then independently judged per chat tab.
MCWorldFilter = {}
local W = MCWorldFilter
local activity = {}
local lastSweep = 0

local function contains(s, term)
    return string.find(s, term, 1, true) ~= nil
end
local function any(s, arr)
    local i
    for i=1,table.getn(arr) do
        if contains(s, arr[i]) then return true end
    end
    return false
end
local function normalized(message)
    local s=string.lower(message or "")
    s=string.gsub(s,"|c%x%x%x%x%x%x%x%x","")
    s=string.gsub(s,"|H[^|]*|h", " ")
    s=string.gsub(s,"|h", " ")
    s=string.gsub(s,"|r", "")
    s=string.gsub(s,"[%c]", " ")
    s=string.gsub(s,"%s+", " ")
    return s
end
local function keyword(s,word)
    return string.find(" "..string.gsub(s,"[%p]"," ").." "," "..word.." ",1,true) ~= nil
end
local function repeatMessage(s,author,now)
    if not author or author=="" or string.len(s)<14 then return false end
    local body=string.gsub(s,"[%p%s]+"," ")
    local name=string.lower(author)
    if now<lastSweep or now-lastSweep>=30 then
        local a,r
        for a,r in pairs(activity) do
            if now-r.seen>30 or now<r.seen then activity[a]=nil end
        end
        lastSweep=now
    end
    local a=activity[name]
    if not a then a={seen=now,items={}}; activity[name]=a end
    a.seen=now
    local i=1
    while i<=table.getn(a.items) do
        local item=a.items[i]
        if now-item.t>30 or now<item.t then table.remove(a.items,i)
        else
            if item.text==body then
                item.t=now; item.count=item.count+1
                return item.count>=2
            end
            i=i+1
        end
    end
    table.insert(a.items,{text=body,count=1,t=now})
    if table.getn(a.items)>8 then table.remove(a.items,1) end
    return false
end

function W.Classify(message, author)
    local s=normalized(message)
    local now=(GetTime and GetTime()) or 0
    if UnitName and author and UnitName("player") and
       string.lower(UnitName("player"))==string.lower(author) then
        return nil,0
    end
    -- Compute repeats even when another category wins; only one evaluation
    -- is run for each incoming World message.
    local repeated=repeatMessage(s,author,now)
    local score, kind=0,nil
    local directSell=any(s,{"wts ","wtb ","wtt ","selling ","buying ","for sale", "verkaufe ","vendo "})
    local itemLike=contains(message or "","|Hitem:") or any(s,{"stack", "boe ", "recipe", "pattern", "materials", "mats "})
    local pricing=string.find(s,"%d+%s*[gsc]")~=nil or any(s,{"gold", "each", "per stack", "offer", "price", "cheap"})
    local contact=any(s,{"/w me", "whisper me", "pst", "pm me", "send tell", "message me", "cod "})
    if directSell then
        kind="trade"; score=4+(itemLike and 2 or 0)+(pricing and 2 or 0)+(contact and 2 or 0)
    elseif (itemLike and pricing and contact) then
        kind="trade"; score=5
    end

    local groupFlag=any(s,{"lfg ","lfm ","lf1m", "lf2m", "lf3m", "looking for group",
        "looking for more", "need tank", "need healer", "need dps", "forming group", "recruiting for raid"})
    local dungeon=any(s,{"dungeon", "raid", "ubrs", "lbrs", "brd", "strat", "scholo", "dm ",
        "zf ", "sm ", "wc ", "rfk", "rfd", "mara", "ony", "mc ", "bwl", "aq20", "aq40", "zg ", "elite", "quest"})
    if groupFlag then
        local val=4+(dungeon and 3 or 0)+(contact and 1 or 0)
        if val>score then kind="groups"; score=val end
    end

    local guildFlag=any(s,{"guild recruiting", "guild recruitment", "join our guild", "guild is recruiting",
        "recruiting members", "recruiting players", "new guild", "looking for members", "social guild",
        "gilde sucht", "gilde rekrutiert", "recluta", "recrute", "rekrutacja"})
    local guildContext=any(s,{"guild", "gilde", "clan", "raiding", "social", "pvp", "members", "active", "recruit"})
    if guildFlag then
        local val=5+(guildContext and 2 or 0)+(contact and 1 or 0)
        if val>score then kind="guild";score=val end
    end

    local serviceFlag=any(s,{"boosting", "boosts", "boost runs", "powerlevel", "power leveling", "summon service",
        "portal service", "enchants for", "crafting service", "selling runs", "carry service", "taxi service",
        "summons available", "selling boost", "enchants available"})
    local serviceContext=any(s,{"gold", "cheap", "tips", "price", "fast", "spots", "pst", "/w", "service"}) or pricing
    if serviceFlag then
        local val=4+(serviceContext and 3 or 0)+(contact and 1 or 0)
        if val>score then kind="services";score=val end
    end
    if repeated and score<6 then kind="repeats";score=6 end
    return kind,score
end

function W.ShouldHide(category,score,tab)
    if not category or not tab or tab.useWCF==false then return false end
    local enabled=tab.adCategories or {}
    if enabled[category]==false then return false end
    local sensitivity=tab.adSensitivity or "balanced"
    local threshold=5
    if sensitivity=="careful" then threshold=7 end
    if sensitivity=="aggressive" then threshold=3 end
    return (score or 0)>=threshold
end
