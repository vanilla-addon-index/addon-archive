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

ABNode = {}
setmetatable(ABNode, { __index = Node })

local grave

function ABNode:new(o)
    o = Node:new(o)
    o.timer.duration = 60
    setmetatable(o, { __index = self })
    StrategosCore.Object.attach(o,{"assaulted","defended","captured"})
    o.ressoff = 0
    return o
end

function ABNode:spiritHealerTime()
    return tresstime - mod((GetTime() + self.ressoff),tresstime)
end

function ABNode:assault(faction)
    self:setFaction(faction, true)
    self.timer:start()
    self:assaulted()
end

function ABNode:defend(faction)
    self:setFaction(faction)
    self.timer:stop()
    self:defended()
    self:resetSpiritHealer()
end

function ABNode:capture(faction)
    self:setFaction(faction)
    self.timer:stop()
    self:captured()
    self:resetSpiritHealer()
end

function ABNode:resetSpiritHealer()
    self.ressoff = self.ressoff + self:spiritHealerTime() - 1
end

ArathiBasin = {}

setmetatable(ArathiBasin,{ __index = Battleground })

function ArathiBasin:new(debug)
    if not grave then
        ArathiBasin.zone = zone == tr("ARATHI_BASIN", "native_client")
        grave = setmetatable({
        [tr("ARATHI_BASIN_FARM_ZONE", "native_client")] = tr("ARATHI_BASIN_FARM", "server"),
        [tr("ARATHI_BASIN_STABLES_ZONE", "native_client")] = tr("ARATHI_BASIN_STABLES", "server"),
        [tr("ARATHI_BASIN_GOLD_MINE_ZONE", "native_client")] = tr("ARATHI_BASIN_GOLD_MINE", "server"),
        [tr("ARATHI_BASIN_LUMBER_MILL_ZONE", "native_client")] = tr("ARATHI_BASIN_LUMBER_MILL", "server"),
        [tr("ARATHI_BASIN_BLACKSMITH_ZONE", "native_client")] = tr("ARATHI_BASIN_BLACKSMITH", "server"),
    }, { __index = function(_,k) return k end })
    end
    local o = Battleground:new()
    o.zone = tr("ARATHI_BASIN", "native_client")
    setmetatable(o, self)
    self.__index = self
    o.nodes = {}
    o.nodes[tr("ARATHI_BASIN_BLACKSMITH", "server")] = ABNode:new(tr("ARATHI_BASIN_BLACKSMITH_LABEL", "server"))
    o.nodes[tr("ARATHI_BASIN_FARM", "server")] = ABNode:new(tr("ARATHI_BASIN_FARM_LABEL", "server"))
    o.nodes[tr("ARATHI_BASIN_STABLES", "server")] = ABNode:new(tr("ARATHI_BASIN_STABLES_LABEL", "server"))
    o.nodes[tr("ARATHI_BASIN_GOLD_MINE", "server")] = ABNode:new(tr("ARATHI_BASIN_GOLD_MINE_LABEL", "server"))
    o.nodes[tr("ARATHI_BASIN_LUMBER_MILL", "server")] = ABNode:new(tr("ARATHI_BASIN_LUMBER_MILL_LABEL", "server"))
    if StrategosMinimap then
        for _,b in {{StrategosMinimapArathiIndicatorST, o.nodes[tr("ARATHI_BASIN_STABLES", "server")]}, 
                    {StrategosMinimapArathiIndicatorGM, o.nodes[tr("ARATHI_BASIN_GOLD_MINE", "server")]},
                    {StrategosMinimapArathiIndicatorBS, o.nodes[tr("ARATHI_BASIN_BLACKSMITH", "server")]},
                    {StrategosMinimapArathiIndicatorLM, o.nodes[tr("ARATHI_BASIN_LUMBER_MILL", "server")]},
                    {StrategosMinimapArathiIndicatorFM, o.nodes[tr("ARATHI_BASIN_FARM", "server")]}} do
            b[1]:setNode(b[2])
            tinsert(StrategosMinimapPlugin.frames, b[1])
            b[1]:Show()
        end
    end
    Object.attach(o,{"updateWinTime"})
    o.team = {{},{}}
    
    local anchorFrame = debug or WorldStateAlwaysUpFrame
    o.bgtime = 0
    o.ressoff = 0
    o.b = SpiritHealerIndicator()
    o.b.anchorTopLeft = {frame = anchorFrame, point = "BOTTOMRIGHT"}
    return o
end

function ArathiBasin:spiritHealerTime()
    return tresstime - mod((GetTime() + self.ressoff), tresstime)
end

function ArathiBasin:updateWorldStates()
    local now = GetTime()
    for i=1,2 do
        local _, msg = GetWorldStateUIInfo(i)
        if not msg then
            return
        end
        local _,_, n, s = strfind(msg, "(%d).-(%d+)/")
        if not n then return end
        n = tonumber(n)
        s = tonumber(s)
        if self.team[i].lastN ~= n or self.team[i].lastScore ~= s then
            if self.team[i].lastScore ~= s then
                self.team[i].lastScore = s
                self.team[i].lastTime = now
            end
            if n == 0 then
                self.team[i].winTime = nil
            else
                local tt = n == 5 and 1 or (5 - n) * 3
                local w = ceil((2000 - s) / 10 * tt)
                if n == 5 then
                    w = w / 3
                end
                self.team[i].winTime = self.team[i].lastTime + w
                self:updateWinTime(i, self.team[i].winTime)
            end
        end
    end
end

function ArathiBasin:timeToWin(team)
    local time = self.team[team].winTime
    return time and time - GetTime() or nil
end

function ArathiBasin:processChatEvent(message, faction)
    local evs = {}
    evs[tr("ARATHI_BASIN_START_1M", "server")] = function()
        self.startTimer:set(60)
        self:starting()
    end
    evs[tr("ARATHI_BASIN_START_30S", "server")] = function()
        self.startTimer:set(30)
        self:starting()
    end
    evs[tr("ARATHI_BASIN_STARTED", "server")] = function()
        self.startTimer:stop()
        self:started()
    end
    evs[tr("ARATHI_BASIN_CLAIMS", "server")] = function()
        _,_,name = strfind(message, tr("ARATHI_BASIN_CLAIMS_CAP", "server"))
        self.nodes[name]:assault(faction)
    end
    evs[tr("ARATHI_BASIN_ASSAULTED", "server")] = function()
        _,_,name = strfind(message, tr("ARATHI_BASIN_ASSAULTED_CAP", "server"))
        self.nodes[name]:assault(faction)
    end
    evs[tr("ARATHI_BASIN_TAKEN", "server")] = function()
        _,_,name = strfind(message, tr("ARATHI_BASIN_TAKEN_CAP", "server"))
        self.nodes[name]:capture(faction)
    end
    evs[tr("ARATHI_BASIN_DEFENDED", "server")] = function()
        _,_,name = strfind(message, tr("ARATHI_BASIN_DEFENDED_CAP", "server"))
        self.nodes[name]:defend(faction)
    end
    
    for s,f in evs do
        if strfind(message, s) then
            f()
            return
        end
    end
    Battleground.processChatEvent(self, message, faction)
end

function ArathiBasin:leave()
    self.b:destroy()
end

local lastSpiritHealerTime = 0
function ArathiBasin:update()
    local node = self.nodes[grave[GetSubZoneText()]] or self
    local time = GetAreaSpiritHealerTime()
    if lastSpiritHealerTime and lastSpiritHealerTime ~= time and time > 1 and time < 30 then
        if not node then return end
        lastSpiritHealerTime = time
        local off = node:spiritHealerTime() - time -1
        if math.abs(off) > .25 then
            node.ressoff = node.ressoff + off
        end
    elseif time ~= 0 then
        lastSpiritHealerTime = time
    else
        lastSpiritHealerTime = nil
    end
    if node and self.b.node ~= node and (GetAreaSpiritHealerTime() > 0 or node) then
        self.b:restart(node)
    end
end
