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

AVNode = {}
setmetatable(AVNode, { __index = Node })

function AVNode:new(o)
    o = Node:new(o)
    o.timer.duration = 300
    setmetatable(o, { __index = self })
    StrategosCore.Object.attach(o,{"assaulted","defended","captured","destroyed"})
    return o
end

function AVNode:assault(faction)
    self:setFaction(faction, true)
    self.timer:start()
    self:assaulted()
end

function AVNode:defend(faction)
    self:setFaction(faction)
    self.timer:stop()
    self:defended()
end

function AVNode:capture(faction)
    self:setFaction(faction)
    self.timer:stop()
    self:captured()
end

function AVNode:destroy(faction)
    self:setFaction(0)
    self.timer:stop()
    self:destroyed()
end

AlteracValley = {}

setmetatable(AlteracValley, { __index = Battleground })

function AlteracValley:new()
    local o = Battleground:new()
    o.zone = tr("ALTERAC_VALLEY", "native_client")
    setmetatable(o, self)
    self.__index = self
    o.nodes = {}
    return o
end

local evs = {}
function AlteracValley:init()
    evs[tr("ALTERAC_VALLEY_START_1M", "server")] = function()
        self.startTimer:set(60)
        self:starting()
    end
    evs[tr("ALTERAC_VALLEY_START_30S", "server")] = function() 
        self.startTimer:set(30)
        self:starting()
    end
    evs[tr("ALTERAC_VALLEY_STARTED", "server")] = function()
        self.startTimer:stop()
        self:started()
    end
    evs[tr("ALTERAC_VALLEY_UNDER_ATTACK", "server")] = function(_,_,a)
        self.nodes[strlower(a)]:assault(faction)
    end
    evs[tr("ALTERAC_VALLEY_TAKEN", "server")] = function(_,_,a)
        local node = self.nodes[strlower(a)]
        if node.assaultingFaction == faction then
            node:capture(faction)
        else
            node:defend(faction)
        end
    end
    evs[tr("ALTERAC_VALLEY_DESTROYED", "server")] = function(_,_,a)
        self.nodes[strlower(a)]:destroy()
    end
end

function AlteracValley:processChatEvent(message, faction)
    for s,f in evs do
        local r = {strfind(message, s)}
        if getn(r) > 0 then
            f(unpack(r))
            return
        end
    end
    Battleground.processChatEvent(self, message, faction)
end

function AlteracValley:updateWorldStates()
    SetMapToCurrentZone()
    if not next(self.nodes) then
        for i = 1,GetNumMapLandmarks() do
            local name, descr, textureIndex, x, y = GetMapLandmarkInfo(i)
            local lname
            if name then
                lname = strlower(name)
            end
            local f = AlteracPOILookup[lname]
            if f then
                local node = AVNode:new(name)
                self.nodes[lname] = node
                node.id = i
                f:setNode(node)
                if descr == tr("ALTERAC_VALLEY_ALLIANCE_CONTROLLED", "native_client") then
                    node:setFaction(1)
                elseif descr == tr("ALTERAC_VALLEY_HORDE_CONTROLLED", "native_client") then
                    node:setFaction(2)
                elseif descr == tr("ALTERAC_VALLEY_IN_CONFLICT", "native_client") then
                    if textureIndex == 3 or textureIndex == 8 then
                        if strfind(name, tr("ALTERAC_VALLEY_TOWER", "native_client")) then
                            node:setFaction(2)
                        elseif name ~= tr("ALTERAC_VALLEY_SNOWFALL_GRAVEYARD", "native_client") then
                            node:setFaction(2)
                        end
                        node:setFaction(1,1)
                        f.ring:Show()
                    elseif textureIndex == 11 or textureIndex == 13 then
                        if strfind(name, tr("ALTERAC_VALLEY_BUNKER", "native_client")) then
                            node:setFaction(1)
                        elseif name ~= tr("ALTERAC_VALLEY_SNOWFALL_GRAVEYARD", "native_client") then
                            node:setFaction(1)
                        end
                        node:setFaction(2,1)
                        f.ring:Show()
                    end
                end
                tinsert(StrategosMinimapPlugin.frames, f)
                f.pin:SetTexCoord(WorldMap_GetPOITextureCoords(textureIndex))
                f:Show()
            end
        end
    end
    for i = 1,GetNumMapLandmarks() do
        local name, descr, textureIndex, x, y = GetMapLandmarkInfo(i)
        local f = AlteracPOILookup[strlower(name)]
        if f then
            f.pin:SetTexCoord(WorldMap_GetPOITextureCoords(textureIndex))
        end
    end
end
