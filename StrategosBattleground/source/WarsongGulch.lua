local S, SB
if StrategosCore == nil then 
    StrategosCore = {}
end
S = StrategosCore

if StrategosBattleground == nil then 
    StrategosBattleground = {}
end
SB = StrategosBattleground

setmetatable(S, {__index = getfenv() })
setfenv(1, S)

setmetatable(SB, {__index = getfenv() })
setfenv(1, SB)

WarsongGulch = {}

setmetatable(WarsongGulch, { __index = Battleground })

local ressoff = 0

CreateFrame("GameTooltip","StrategosWSGFlagFinder",UIParent,"GameTooltipTemplate")

function StrategosWSGFlagFinder_CarrierUnit()
    for i=1,GetNumRaidMembers() do
        local unit = "raid"..i
        for i = 1,16 do
            StrategosWSGFlagFinder:SetOwner(UIParent, "ANCHOR_NONE");
            StrategosWSGFlagFinder:SetUnitBuff(unit,i)
            local sn = StrategosWSGFlagFinderTextLeft1:GetText()
            if sn == tr("WARSONG_FLAG", "native_client") or sn == tr("SILVERWING_FLAG", "native_client") then
                StrategosWSGFlagFinder:Hide()
                return unit
            end
        end
    end
    StrategosWSGFlagFinder:Hide()
end

function WarsongGulch.alliedFlagFrame()
    return UnitFactionGroup("player") == "Alliance" and AlwaysUpFrame1DynamicIconButton or AlwaysUpFrame2DynamicIconButton
end

function WarsongGulch.enemyFlagFrame()
    return UnitFactionGroup("player") == "Horde" and AlwaysUpFrame1DynamicIconButton or AlwaysUpFrame2DynamicIconButton
end

function WarsongGulch:lookForCarrier()
    if not (WarsongGulch.alliedFlagFrame() and WarsongGulch.alliedFlagFrame():IsVisible()) then
        return
    end
    local flag = self:alliedCarriedFlag()
    if flag.carrier and flag.carrier.name then
        return
    end
    local uc = StrategosWSGFlagFinder_CarrierUnit()
    if uc then
        flag:pick(UnitName(uc))
        return
    end
    self.finderTimer:start()
end

local function prepare(template) --courtesy of shagu
    template = gsub(template, "%(", "%%(") -- fix ( in string
    template = gsub(template, "%)", "%%)") -- fix ) in string
    template = gsub(template, "%d%$","")
    template = gsub(template, "%%s", "(.+)")
    return gsub(template, "%%d", "(%%d+)")
end

local CombatEventsMatches = {
    COMBAT_HITS =  {
        regexes = {
            prepare(COMBATHITOTHEROTHER),
            prepare(COMBATHITSCHOOLOTHEROTHER),
            prepare(COMBATHITCRITOTHEROTHER),
            prepare(COMBATHITCRITSCHOOLOTHEROTHER)
        },
        captures = {1,2}
    },
    COMBAT_MISSES = {
        regexes = {
            prepare(MISSEDOTHEROTHER),
            prepare(IMMUNEOTHEROTHER),
            prepare(VSDODGEOTHEROTHER),
            prepare(VSBLOCKOTHEROTHER),
            prepare(VSPARRYOTHEROTHER),
            prepare(VSRESISTOTHEROTHER)
        },
        captures = {1,2}
    },
    SPELL_DAMAGE = {
        regexes = {
            prepare(SPELLLOGOTHEROTHER),
            prepare(SPELLBLOCKEDOTHEROTHER),
            prepare(SPELLDEFLECTEDOTHEROTHER),
            prepare(SPELLDODGEDOTHEROTHER),
            prepare(SPELLIMMUNEOTHEROTHER),
            prepare(SPELLLOGABSORBOTHEROTHER),
            prepare(SPELLLOGCRITOTHEROTHER),
            prepare(SPELLLOGCRITSCHOOLOTHEROTHER),
            prepare(SPELLLOGSCHOOLOTHEROTHER),
            prepare(SPELLMISSOTHEROTHER),
            prepare(SPELLPARRIEDOTHEROTHER),
            prepare(SPELLRESISTOTHEROTHER)
        },
        captures = {1,3}
    }
}

local CombatEvents = {
    CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS = {accurate = true, matches = CombatEventsMatches.COMBAT_HITS, hostile = 1},
    CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES = {accurate = true, matches = CombatEventsMatches.COMBAT_MISSES, hostile = 1},
    CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE = {accurate = false, matches = CombatEventsMatches.SPELL_DAMAGE, hostile = 1},
    CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS = {accurate = true, matches = CombatEventsMatches.COMBAT_HITS},
    CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES = {accurate = false, matches = CombatEventsMatches.COMBAT_MISSES},
    CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE = {accurate = false, matches = CombatEventsMatches.SPELL_DAMAGE}
}


local CombatEventsHandler = CreateFrame("FRAME")

function WarsongGulch:new(debug)
    local o = Battleground:new()
    o.zone = tr("WARSONG_GULCH", "native_client")
    o.flagA = WSGNode:new({ name = "Alliance Flag", faction = 1})
    o.flagH = WSGNode:new({ name = "Horde Flag", faction = 2})
    o.broadcaster = Broadcaster:new("STRTGSWSG")
    o.broadcaster.healthTimer = Timer:new()
    o.broadcaster.healthTimer:setActive()
    o.finderTimer = Timer:new(1)
    o.finderTimer:setActive()
    function StrategosMinimapPlugin:getHighlight(unit)
        if not o.alliedCarriedFlag then return end
        local cu = o:alliedCarriedFlag():findCarrierUnit()
        if unit == cu then
            return nil, 9
        end
    end
    setmetatable(o, self)
    self.__index = self

    Object.connect(o.finderTimer,"triggered", o, o.lookForCarrier)
    Object.connect(o.broadcaster,"messageRecieved", o, o.processMessage)
    Object.connect(o.broadcaster.healthTimer, "triggered", nil, function()
        o:notifyHealth(nil, nil, true)
    end)
    
    local anchorFrame = debug or WorldStateAlwaysUpFrame
    o.bgtime = 0
    o.b = SpiritHealerIndicator()
    o.b.anchorTopLeft = {frame = anchorFrame, point = "BOTTOMRIGHT"}
    
    return o
end

function WarsongGulch:init()
    if not self.b.ok then
        self.b:restart(self)
        self.b.ok = true
    end
    self:initLocale()
    local aframe = WarsongGulch.alliedFlagFrame()
    if aframe then
        if aframe:IsVisible() then
            self:alliedCarriedFlag():picked()
            self:lookForCarrier()
        end
        aframe:SetScript("OnShow", function()
            local flag = self:alliedCarriedFlag()
            if not flag.carrier then
                self:alliedCarriedFlag():picked()
                self.finderTimer:start()
            end
        end)
    end
    local eframe = WarsongGulch.enemyFlagFrame()
    if eframe then
        if eframe:IsVisible() then
            self:enemyCarriedFlag():pick()
        end
        eframe:SetScript("OnShow", function()
            local flag = self:enemyCarriedFlag()
            if not flag.carrier then
                flag:pick()
            end
        end)
    end
    
    self:registerCombatEvents()
    self:requestCarriersData()
    Object.connect(self:enemyCarriedFlag(), "carrierHealthChanged", self, self.notifyHealth)
    for c,f in {a = self.flagA, h = self.flagH} do
        local flag = f
        local function lhe (p)
            for _,pp in {0.1,0.20,0.4} do
                if p < pp and (not flag.carrier.lastWarn or pp < flag.carrier.lastWarn.health) then
                    return pp
                end
            end
        end
        local n = c
        Object.connect(flag,"carrierHealthChanged",nil,function (p,r)
            if not p or r or not StrategosWSGSettings.warnings then
                return
            end
            if flag.carrier.lastWarn and GetBattlefieldInstanceRunTime() - flag.carrier.lastWarn.time > 20000 then
                flag.carrier.lastWarn = nil
            end
            local pp = lhe(p)
            local time = GetBattlefieldInstanceRunTime()
            if pp then
                local f = n=="a" and 0 or 1
                local m = tr("WARSONG_LOWHEALTH_CHAT_WARN".. f .. (StrategosWSGSettings.warningsNoLink and "_ALT" or ""),"server", {pname = flag.carrier.name, health = pp*100})
                local function ann()
                    if not flag.carrier or strlen(flag.carrier.name or "") == 0 or pp ~= lhe(p) then return end
                    SendChatMessage(m,"BATTLEGROUND")
                    if not flag.carrier.lastWarn then
                        flag.carrier.lastWarn = {}
                    end
                    flag.carrier.lastWarn.health, flag.carrier.lastWarn.time = pp, time
                end
                if not (flag.carrier.updater or flag:isAllied()) then
                    ann()
                else
                    local l = self.broadcaster:sendMessage(format("LHC\t%s%d:%d",n,pp*100,time),"BATTLEGROUND")
                    Object.connect(l, "looped", nil, function (t)
                        if t > 1000 then return end
                        ann()
                    end)
                end
            end
        end)
    end
end

function WarsongGulch:spiritHealerTime()
    return tresstime - mod((GetTime() + ressoff), tresstime)
end

function WarsongGulch:sendEFCLost()
    self.broadcaster:sendMessage(format("EFC"),"BATTLEGROUND")
    self.broadcaster.healthTimer:stop()
end

function WarsongGulch:notifyHealth(p, r, force)
    if self.broadcaster.healthLock or r then
        return
    end
    local flag = self:enemyCarriedFlag()
    if not flag.carrier or not force and flag.carrier.updater and flag.carrier.updater ~= UnitName("player") then
        return
    end
    if not flag.carrier.health then
        if UnitName("player") == flag.carrier.updater then
            flag.carrier.updater = nil
            self:sendEFCLost()
            flag.carrier.lastNotifiedHealth = nil
        end
        return
    end
    p = floor((p and p or flag.carrier.health)*100)
    local old = flag.carrier.lastNotifiedHealth
    if not old or abs(p-old) > 10 or force then
        local r = self.broadcaster:sendMessage(format("EFC\th%d\tt%d",p,GetBattlefieldInstanceRunTime()),"BATTLEGROUND")
        flag.carrier.lastNotifiedHealth = p
        flag.carrier.updater = UnitName("player")
        Object.connect(r, "looped", nil, function (t)
            if not flag.carrier then return end
            self.broadcaster.healthLock = nil
            if flag.carrier.updater ~= UnitName("player") then
                return
            end
            if t < 1000 then
                self.broadcaster.healthTimer:start(3.5)
            else
                flag.carrier.updater = nil
                self:sendEFCLost()
            end
        end)
        self.broadcaster.healthLock = true
    end
end

local flags = {"flagA", "flagH"}
function WarsongGulch:update()
    for _,flagn in flags do
        local flag = self[flagn]
        if flag.carrier then
            local r = flag:findCarrierUnit()
            if r then
                local p = UnitHealth(r)/UnitHealthMax(r)
                flag:setCarrierHealth(p)
            else
                flag:setCarrierHealth()
            end
        end
    end
    local time = GetAreaSpiritHealerTime()
    if lastSpiritHealerTime and lastSpiritHealerTime ~= time and time > 1 and time < 30 then
        lastSpiritHealerTime = time
        local off = self:spiritHealerTime() - time -1
        if math.abs(off) > .25 then
            ressoff = ressoff + off
            self.b:restart(self)
        end
    elseif time ~= 0 then
        lastSpiritHealerTime = time
    else
        lastSpiritHealerTime = nil
    end
end

WSGNode = {}
setmetatable(WSGNode, { __index = Node })

function WSGNode:new(o)
    o = Node:new(o)
    setmetatable(o, { __index = self })
    StrategosCore.Object.attach(o,{"picked","resetted","captured","dropped","carrierNameChanged","carrierClassChanged","carrierHealthChanged","carrierEngaged"})
    return o
end

function WSGNode:pick(name)
    self.waitingCarrierData = nil
    if not self.carrier then
        self.timer:stop()
        self.carrier = {}
        self:picked()
    end
    if name then
        self:setCarrierName(name)
    else
        self:setCarrierName("")
    end
end

function WSGNode:drop()
    self.waitingCarrierData = nil
    if self.carrier then
        self.timer:start(10)
        self:dropped()
        self.carrier = nil
        self.updater = nil
        self:carrierNameChanged()
        self:carrierHealthChanged()
    end
end

function WSGNode:capture()
    self.waitingCarrierData = nil
    self.timer:stop()
    self:captured()
    self.carrier = nil
    self.updater = nil
    self:carrierNameChanged()
    self:carrierHealthChanged()
end

function WSGNode:reset()
    self.waitingCarrierData = nil
    self.timer:stop()
    self:resetted()
    self.carrier = nil
    self:carrierNameChanged()
    self:carrierHealthChanged()
end

function WSGNode:setCarrierName(name)
    if not self.carrier then
        self:pick()
    end
    if self.carrier.name ~= name then
        self.carrier.name = name
        self:carrierNameChanged(name)
    end
    if self:isAllied() then
        for i = 1, GetNumRaidMembers() do
            if UnitName("raid"..i) == name then
                _, self.carrier.class = UnitClass("raid"..i)
                self:carrierClassChanged()
                break
            end
        end
    else
        currentBattleground:scanEnemyFC()
    end
    if not self.carrier.class then
        RequestBattlefieldScoreData()
    end
end

function WSGNode:setCarrierHealth(p,remote)
    local health = remote and "remoteHealth" or "health"
    if self.carrier[health] == p then
        return
    end
    self.carrier[health] = p
    if remote and self.carrier.health or not (remote or p) and self.carrier.remoteHealth then
        return
    end
    self:carrierHealthChanged(p, remote)
end

local factionNames = {"Horde", "Alliance"}
function WSGNode:isAllied()
    return factionNames[self.faction] == UnitFactionGroup("player")
end

function WSGNode:findCarrierUnit()
    if self.lastUnit and self.carrier and self.carrier.name == UnitName(self.lastUnit) then
        return self.lastUnit
    end
    if self:isAllied() then
        local afc = self.carrier
        if afc and afc.name then
            for i = 1,GetNumRaidMembers() do
                local r = "raid"..i
                if UnitName(r) == afc.name then
                    self.lastUnit = r
                    return r
                end
            end
        end
    else
        local efc = self.carrier
        if efc and efc.name then
            for i = 1,GetNumRaidMembers() do
                local r = "raid"..i.."target"
                if UnitIsPlayer(r) and UnitName(r) == efc.name then
                    self.lastUnit = r
                    return r
                end
                r = "raid"..i.."targettarget"
                if UnitIsPlayer(r) and UnitName(r) == efc.name then
                    self.lastUnit = r
                    return r
                end
            end
        end
    end
end

local evs = {}
local localizedClasses = {}
function WarsongGulch:initLocale()
    evs[tr("WARSONG_GULCH_START_1M", "server")] = function(self)
        self.startTimer:set(60,120)
        self:starting()
    end
    evs[tr("WARSONG_GULCH_START_30S", "server")] = function(self) 
        self.startTimer:set(30,120)
        self:starting()
    end
    evs[tr("WARSONG_GULCH_STARTED", "server")] = function(self)
        self.startTimer:stop()
        self:started()
        self.startTime = Battleground.startTime
    end
    evs[tr("WARSONG_GULCH_FLAG_PICKED_UP", "server")] = function(self, message, faction)
        _,_,name = strfind(message, tr("WARSONG_GULCH_FLAG_PICKED_BY", "server"))
        local flag = self[faction == 1 and "flagH" or "flagA"]
        flag:pick(name)
    end
    evs[tr("WARSONG_GULCH_FLAG_DROPPED", "server")] = function(self, message, faction)
        local flag = self[faction ~= 1 and "flagH" or "flagA"]
        flag:drop(10)
    end
    evs[tr("WARSONG_GULCH_FLAG_RETURNED", "server")] = function(self, message, faction)
        local flag = self[faction ~= 1 and "flagH" or "flagA"]
        flag:reset()
    end
    evs[tr("WARSONG_GULCH_FLAG_CAPTURED", "server")] = function(self)
        self.startTimer:start(23)
        self.flagA:reset()
        self.flagH:reset()
    end
    evs[tr("WARSONG_GULCH_FLAG_RESET", "server")] = function(self, message, faction)
        if strfind(message, tr("HORDE", "server")) then
            self.flagH:reset()
        elseif strfind(message, tr("ALLIANCE", "server")) then
            self.flagA:reset()
        else
            self.flagA:reset()
            self.flagH:reset()
        end
    end
    for _,v in ipairs({"DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"}) do
        localizedClasses[tr(v, "native_client")] = v
    end
end

function WarsongGulch:processChatEvent(message, faction)
    for s,f in evs do
        if strfind(message, s) then
            f(self, message, faction)
            return
        end
    end
    Battleground.processChatEvent(self, message, faction)
end

function WarsongGulch:scoreUpdate()
    local flag = self:enemyCarriedFlag()
    if flag.carrier and not flag.carrier.class then
        self:scanEnemyFC()
    end 
end

function WarsongGulch:alliedCarriedFlag()
    return UnitFactionGroup("player") == "Alliance" and self.flagH or self.flagA
end

function WarsongGulch:enemyCarriedFlag()
    return UnitFactionGroup("player") == "Alliance" and self.flagA or self.flagH
end

function WarsongGulch:scanEnemyFC()
    local node = self:enemyCarriedFlag()
    if not node.carrier or not node.carrier.name or node.carrier.name == "" then
        return
    end
    for i = 1, GetNumBattlefieldScores() do
        sn, _, _, _, _, _, _, _, sc = GetBattlefieldScore(i)
        if sn == node.carrier.name then
            node.carrier.class = localizedClasses[sc]
            node:carrierClassChanged()
            break
        end
    end
    if not node.carrier.class then
        debug("Cannot find enemy flag carrier class.")
    end
end

function WarsongGulch:requestCarriersData()
    local r = self.broadcaster:sendMessage("REQUEST_CARRIERS","BATTLEGROUND")
    self.flagA.waitingCarrierData = true
    self.flagH.waitingCarrierData = true
end

function WarsongGulch:REQUEST_CARRIERS()
    local reply = ""
    for k,flag in {a=self.flagA, h=self.flagH} do
        if flag.carrier and flag.carrier.name and flag.carrier.name ~= "" then
            reply = reply .. "\t" ..k..flag.carrier.name
        end
    end
    local efc = self:enemyCarriedFlag().carrier
    if efc and efc.updater then
        reply = reply .. "\tu" .. efc.updater
    end
    if reply ~= "" then
        self.broadcaster:sendMessage("DATA_CARRIERS"..reply,"BATTLEGROUND")
    end
end

function WarsongGulch:DATA_CARRIERS(body)
    local t = {}
    for a in string.gfind(body,"([^\t]+)") do
        t[strsub(a,1,1)] = strsub(a,2)
    end
    for k,flag in {a=self.flagA, h=self.flagH} do
        if flag.waitingCarrierData then
            local name = t[k]
            
            if name then
                flag:pick(name)
            end
        end
        local efc = self:enemyCarriedFlag().carrier
        if efc then
            local r = t[u]
            if r then
                efc.updater = r
            end
        end
    end
end

function WarsongGulch:EFC(_, pkt)
    local flag = self:enemyCarriedFlag()
    if not flag.carrier then
        return
    end
    local _, _, p = strfind(pkt.message,"\th(%d+)")
    if not p then
        if flag.carrier.updater == pkt.sender then
            flag.carrier.updater = nil
            self:enemyCarriedFlag():setCarrierHealth(nil, true)
            self:notifyHealth(nil, nil, true)
        end
        return
    end
    local _, _, t = strfind(pkt.message,"\tt(%d+)")
    t = tonumber(t)
    if not self.broadcaster.healthLock and flag.carrier.updater == UnitName("player") then
        return
    end
    local now = GetBattlefieldInstanceRunTime()
    if ( not flag.carrier.lastHealthTime or t == 0 or flag.carrier.lastHealthTime < t ) and ( t == 0 or now == 0 or now - t < 1000 ) then
        flag.carrier.updater = pkt.sender
        flag:setCarrierHealth(tonumber(p)/100, true)
        self.broadcaster.healthTimer:start(5)
        flag.carrier.lastHealthTime = t
    end
end

function WarsongGulch:LHC(message)
    local _,_,f,h,t = strfind(message,"(%a)(%d+):(%d+)")
    if not f then
        debug(format("Invalid LHC packet: %s", message))
        return
    end
    local flag = f == "a" and self.flagA or self.flagH
    if not flag.carrier then
        return
    end
    if not flag.carrier.lastWarn then
        flag.carrier.lastWarn = {}
    end
    flag.carrier.lastWarn.health, flag.carrier.lastWarn.time = tonumber(h)/100, math.max(tonumber(t), flag.carrier.lastWarn.time or 0)
end

function WarsongGulch:CE(message)
    local _,_,name,accurate,time = strfind(message,"(%a+):(.):(%d+)")
    if not name then
        debug(format("Invalid CE packet: %s", message))
        return
    end
    accurate, time = accurate~="0", tonumber(time)
    local flag = self:enemyCarriedFlag()
    if not flag.carrier then
        return
    end
    if not flag.carrier.lastEngage or flag.carrier.lastEngage < time then
        flag.carrier.lastEngage = time
        self:engageEFC(name, accurate)
    end
end

function WarsongGulch:processMessage(pkt)
    local head, body
    local _,_,h,b = strfind(pkt.message, "^([%a_]+)\t(.*)$")
    if h and b then
        head = h
        body = b
    else
        head = pkt.message
    end
    debug({head = head, body = body})
    local f = WarsongGulch[head]
    if f then
        f(self,body,pkt)
    else
        debug(format("Unknown packet %s: \"%s\"", head, body))
    end
end
                
function WarsongGulch:leave()
    local aframe = WarsongGulch.alliedFlagFrame()
    local flag = self:alliedCarriedFlag()
    if flag.carrier then
        self:alliedCarriedFlag():drop()
    end
    flag = self:enemyCarriedFlag()
    if flag.carrier then
        self:enemyCarriedFlag():drop()
    end
    if aframe then
        aframe:SetScript("OnShow", nil)
        aframe:SetScript("OnHide", nil)
    end
    local eframe = WarsongGulch.enemyFlagFrame()
    if eframe then
        eframe:SetScript("OnShow", nil)
        eframe:SetScript("OnHide", nil)
    end
    self:unregisterCombatEvents()
    self.broadcaster:unregister()
    self.b:destroy()
end

function WarsongGulch:registerCombatEvents()
    for e in CombatEvents do
        CombatEventsHandler:RegisterEvent(e)
    end
    local bg = self
    CombatEventsHandler:SetScript("OnEvent", function()
        local ce = CombatEvents[event]
        for _,m in ce.matches.regexes do
            local fn, en
            local r = {}
            r = {strfind(arg1,m)}
            if getn(r) >= 4 then
                if ce.hostile then
                    fn = r[2+ce.matches.captures[2]]
                    en = r[2+ce.matches.captures[1]]
                else
                    fn = r[2+ce.matches.captures[1]]
                    en = r[2+ce.matches.captures[2]]
                end
            end
            if fn == "you" then
                fn = UnitName("player")
            end
            if en and fn then
                local flag = bg:enemyCarriedFlag()
                if flag.carrier and flag.carrier.name and en == flag.carrier.name then
                    self.broadcaster:sendMessage(format("CE\t%s:%d:%d",fn, ce.accurate and 1 or 0,GetBattlefieldInstanceRunTime()),"BATTLEGROUND")
                    self:engageEFC(fn, ce.accurate)
                end
                return
            end
        end
    end)
end

function WarsongGulch:engageEFC(name, accurate)
    if name == UnitName("player") then
        self:enemyCarriedFlag():carrierEngaged(name, accurate, "player")
        return
    end
    for i = 1, GetNumRaidMembers() do
        local unit = "raid"..i
        if UnitName(unit) == name then
            if accurate then
                StrategosMinimapEFCIndicator.closeTimer:start()
                StrategosMinimapEFCIndicator.closeIndex = i
            else
                StrategosMinimapEFCIndicator.farTimer:start()
                StrategosMinimapEFCIndicator.farIndex = i
            end
            self:enemyCarriedFlag():carrierEngaged(name, accurate, unit)
            PlaySound("MapPing")
            return
        end
    end
end

function WarsongGulch:unregisterCombatEvents()
    for e in CombatEvents do
        CombatEventsHandler:UnregisterEvent(e)
    end
end
