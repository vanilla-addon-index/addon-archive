local S, SB
if StrategosCore == nil then 
    StrategosCore = {}
end

if StrategosBattleground == nil then 
    StrategosBattleground = {}
end

S = StrategosCore
setmetatable(S, {__index = getfenv() })
setfenv(1, S)

SB = StrategosBattleground
Object.attach(StrategosBattleground, {"newBattleground"})
setmetatable(SB, {__index = getfenv() })
setfenv(1, SB)

resstime, resttime = 30, 0
tresstime = resstime + resttime

local DEFAULT_SETTINGS = {
    autoJoin = true,
    autoJoinAsGroup = false
}

local DEFAULT_WSG_SETTINGS = {
    warnings = true
}

StrategosMinimapPlugin = {
    name = "Battleground"
}

local DEFAULT_PROFILE = {
    serverLocalization = "enUS"
}

EventHandler = CreateFrame("frame")
local Strategos_EventList = {
    "ZONE_CHANGED_NEW_AREA",
    "ZONE_CHANGED",
    "CHAT_MSG_BG_SYSTEM_NEUTRAL",
    "CHAT_MSG_BG_SYSTEM_ALLIANCE",
    "CHAT_MSG_BG_SYSTEM_HORDE",
    "CHAT_MSG_MONSTER_YELL",
    "PLAYER_ENTERING_WORLD",
    "UPDATE_WORLD_STATES",
    "UPDATE_BATTLEFIELD_SCORE",
    "BATTLEFIELDS_SHOW",
    "GOSSIP_SHOW"
}

EventHandler:RegisterEvent("ADDON_LOADED")

function GetDefaultLocale(t)
    local locale = GetLocale()
    if StrategosBattleground_Localizations[locale] then
        return locale
    else
        return "enUS"
    end
end

function GetClientLocale(t)
    local locale = GetLocale()
    if StrategosBattleground_ClientLocalizations[locale] then
        return locale
    else
        return "enUS"
    end
end

function tr(s, c, ...)
    local string
    if c == "client" then
        string = StrategosBattleground_Localizations[StrategosBGSettings[c.."_lang"] or GetDefaultLocale(c)][s]
    elseif c == "native_client" then
        string = StrategosBattleground_ClientLocalizations[GetClientLocale(c)][s]
    elseif c == "server" then
        string = StrategosBattleground_ServerLocalizations[StrategosBGProfile.serverLocalization][s]
    end
    if not string then
        EFrame.print("Strategos: missing "..s.." in "..c)
        return
    end
    return strarg(string, unpack(arg))
end

function EventHandler.ADDON_LOADED()
    if arg1 == "Strategos_Battleground" then
        if not StrategosWSGSettings then
            getfenv(0).StrategosWSGSettings = {}
        end
        if not StrategosAVSettings then
            getfenv(0).StrategosAVSettings = {}
        end
        if not StrategosABSettings then
            getfenv(0).StrategosABSettings = {}
        end
        if not StrategosBGSettings then
            getfenv(0).StrategosBGSettings = {}
        end
        if not StrategosBGProfile then
            getfenv(0).StrategosBGProfile = {}
        end
        setmetatable(StrategosBGSettings, {__index = DEFAULT_SETTINGS})
        setmetatable(StrategosWSGSettings, {__index = DEFAULT_WSG_SETTINGS})
        setmetatable(StrategosBGProfile, {__index = DEFAULT_PROFILE})
    end
end

EventHandler:SetScript("OnEvent",function()
    local handle = EventHandler[event]
    if handle then
        handle(this)
    else
        debug("unhandled event \""..event.."\"")
    end
end)

EventHandler:SetScript("OnUpdate", function()
    if currentBattleground then
        currentBattleground:update()
    end
end)

function register()
    for _, e in Strategos_EventList do
        EventHandler:RegisterEvent(e)
    end
end
register()
function unregister()
    for _, e in Strategos_EventList do
        EventHandler:UnregisterEvent(e)
    end
end

function EnteringZone()
    local zone = GetRealZoneText()
    if currentBattleground and currentBattleground.zone ~= zone then
        currentBattleground:_leave()
        currentBattleground = nil
    end
    if not currentBattleground then
        if zone == tr("WARSONG_GULCH", "native_client") then
            currentBattleground = WarsongGulch:new()
        elseif zone == tr("ARATHI_BASIN", "native_client") then
            currentBattleground = ArathiBasin:new()
        elseif zone == tr("ALTERAC_VALLEY", "native_client") then
            currentBattleground = AlteracValley:new()
        end
        if currentBattleground then
            SB:newBattleground(currentBattleground)
            currentBattleground:init()
        end
    end
end

function HandleMessage(message, faction)
    if faction <= 0 then
        if strfind(message, tr("AALLIANCE", "server")) then
            faction = 1
        elseif strfind(message, tr("HHORDE", "server")) then
            faction = 2
        end
    end
    if currentBattleground then
        currentBattleground:processChatEvent(message,  faction)
    end
end

EventHandler.ZONE_CHANGED_NEW_AREA = EnteringZone
EventHandler.ZONE_CHANGED = EnteringZone
EventHandler.PLAYER_ENTERING_WORLD = EnteringZone

EventHandler.CHAT_MSG_BG_SYSTEM_NEUTRAL = function() HandleMessage(arg1, 0) end
EventHandler.CHAT_MSG_BG_SYSTEM_ALLIANCE = function()  HandleMessage(arg1, 1) end
EventHandler.CHAT_MSG_BG_SYSTEM_HORDE = function()  HandleMessage(arg1, 2) end
EventHandler.CHAT_MSG_MONSTER_YELL = function()  HandleMessage(arg1, -1) end

function EventHandler.UPDATE_WORLD_STATES()
    if currentBattleground then
        currentBattleground:updateWorldStates()
    end
end

function EventHandler.UPDATE_BATTLEFIELD_SCORE()
    if currentBattleground then
        currentBattleground:scoreUpdate()
    end
end

local function PlayerInPartyOrRaid() return GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 end

function EventHandler.BATTLEFIELDS_SHOW()
    if IsAltKeyDown() then return end
    if CanJoinBattlefieldAsGroup() and (StrategosBGSettings.autoJoinAsGroup or IsShiftKeyDown()) then
        JoinBattlefield(0,1)
    end
    if StrategosBGSettings.autoJoin and not PlayerInPartyOrRaid() or IsShiftKeyDown() then
        JoinBattlefield(0)
    end
end

function EventHandler.GOSSIP_SHOW()
    if IsAltKeyDown() or not (CanJoinBattlefieldAsGroup() and StrategosBGSettings.autoJoinAsGroup or StrategosBGSettings.autoJoin and not PlayerInPartyOrRaid()) and not IsShiftKeyDown() then return end
    local _, t = GetGossipOptions()
    if t == "battlemaster" then
        SelectGossipOption(1)
    end
end

Node = {}

function Node:new(o)
    if type(o) == "string" then
        o = {name = o}
    end
    StrategosCore.Object.attach(o,{"factionChanged"})
    setmetatable(o, self)
    self.__index = self
    o.timer = Timer:new()
    return o
end

function Node:setFaction(faction, contesting)
    if self.faction == faction then
        return
    end
    if contesting then
        self.assaultingFaction = faction
    else
        self.faction = faction
        self.assaultingFaction = faction
    end
    self:factionChanged()
end

Battleground = {}
function Battleground:new()
    local o = { startTimer = Timer:new(120), nodes = {} }
    Object.attach(o,{"starting","started","finished"})
    setmetatable(o, self)
    self.__index = self
    if StrategosMinimap then
        StrategosBattlegroundMinimapStarting:setTimer(o.startTimer)
        StrategosMinimapPlugin.frames = { StrategosBattlegroundMinimapStarting }
    end
    local time = GetBattlefieldInstanceRunTime()/1000
    if time ~= 0 and time < 120 then
        o.startTimer:set(120 - time)
        o:starting()
    end
    return o
end

function Battleground:init()
end

function Battleground:update()
end

function Battleground:bgTime()
    local t = GetBattlefieldInstanceRunTime()
    if t > 0 then
        return t
    end
end
    

local ArathiBases = {
    ST = {
        x = 0.3747319206595421,
        y = 0.2917306870222092
    },
    GM = {
        x = 0.5751497000455856,
        y = 0.3086424916982651
    },
    BS = {
        x = 0.4622423946857452,
        y = 0.4537641629576683
    },
    LM = {
        x = 0.4039658159017563,
        y = 0.5570576936006546
    },
    FM = {
        x = 0.5603127181529999,
        y = 0.5996280610561371
    }
}

local AlteracBases = {
    ALTERAC_VALLEY_WEST_FROSTWOLF_TOWER    = {
        x = 0.625,
        y = 0.9
    },
    ALTERAC_VALLEY_EAST_FROSTWOLF_TOWER    = {
        x = 0.7,
        y = 0.9
    },
    ALTERAC_VALLEY_ICEBLOOD_TOWER     = {
        x = 0.7,
        y = 0.7375
    },
    ALTERAC_VALLEY_TOWER_POINT      = {
        x = 0.625,
        y = 0.7375
    },
    ALTERAC_VALLEY_ICEBLOOD_GRAVEYARD    = {
        x = 0.3,
        y = 0.60
    },
    ALTERAC_VALLEY_FROSTWOLF_GRAVEYARD    = {
        x = 0.3,
        y = 0.75
    },
    ALTERAC_VALLEY_FROSTWOLF_RELIEF_HUT    = {
        x = 0.3,
        y = 0.9
    },
    ALTERAC_VALLEY_DUN_BALDAR_NORTH_BUNKER    = {
        x = 0.625,
        y = 0.25
    },
    ALTERAC_VALLEY_DUN_BALDAR_SOUTH_BUNKER    = {
        x = 0.7,
        y = 0.25
    },
    ALTERAC_VALLEY_ICEWING_BUNKER     = {
        x = 0.625,
        y = 0.4125
    },
    ALTERAC_VALLEY_STONEHEARTH_BUNKER     = {
        x = 0.7,
        y = 0.4125
    },
    ALTERAC_VALLEY_STORMPIKE_AID_STATION    = {
        x = 0.3,
        y = 0.15
    },
    ALTERAC_VALLEY_STORMPIKE_GRAVEYARD    = {
        x = 0.3,
        y = 0.3
    },
    ALTERAC_VALLEY_STONEHEARTH_GRAVEYARD    = {
        x = 0.3,
        y = 0.45
    },
    ALTERAC_VALLEY_SNOWFALL_GRAVEYARD    = {
        x = 0.6625,
        y = 0.575
    }
}

AlteracPOILookup = {}

function StrategosMinimapPlugin:load()
    CreateFrame("Frame","StrategosBattlegroundMinimapStarting",StrategosMinimap,"StrategosRingFrameTemplate")
    StrategosMinimapPOI:new(StrategosBattlegroundMinimapStarting)
    StrategosBattlegroundMinimapStarting:SetPoint("CENTER",StrategosMinimap)
    StrategosBattlegroundMinimapStarting.buildTooltip = function(self)
        local left = self.timer:remaning()
        local m,s = floor(left/60), mod(left, 60)
        return format(tr("BG_START_IN_UI","client")..": %d:%02d", m, s)
    end
    StrategosBattlegroundMinimapStarting.buildMenu = function(self)
        if self.timer:remaning() then
            UIDropDownMenu_AddButton({
                text = tr("BG_START_IN_UI","client").."...",
                func = function()
                    local left = self.timer:remaning()
                    if left then
                        local m,s = floor(left/60), mod(left, 60)
                        SendChatMessage(tr("BG_START_IN_CHAT","server",{time = format("%d:%02d", m, s)}), "BATTLEGROUND")
                    end
                end
            })
        end
    end
    
    for n,b in ArathiBases do
        local f = getglobal("StrategosMinimapArathiIndicator"..n)
        if not f then
            f = CreateFrame("Frame", "StrategosMinimapArathiIndicator"..n, StrategosMinimap, "StrategosIndicatorFrameTemplate")
            StrategosMinimapPOI:new(f)
            f:SetPoint("CENTER", StrategosMinimap, "TOPLEFT", b.x * StrategosMinimap:GetWidth(), -b.y * StrategosMinimap:GetHeight())
            f.buildTooltip = function(self, t)
                local left = self.node.timer:remaning()
                if left then
                    local m,s = floor(left/60), mod(left, 60)
                    return format(self.node.name..": %d:%02d", m, s)
                end
            end
            f.buildMenu = function(self)
                if self.node.timer:remaning() then
                    UIDropDownMenu_AddButton({
                        text = "[BG] " .. self.node.name,
                        func = function()
                            local left = self.node.timer:remaning()
                            if left then
                                local m,s = floor(left/60), mod(left, 60)
                                SendChatMessage(format(self.node.name..": %d:%02d", m, s), "BATTLEGROUND")
                            end
                        end
                    })
                end
            end
        end
    end
    
    for n,b in AlteracBases do
        local f = getglobal("StrategosMinimapAlteracIndicator"..n)
        if not f then
            local name = tr(n, "native_client")
            f = CreateFrame("Frame", "StrategosMinimapAlteracIndicator"..n, StrategosMinimap, "StrategosIndicatorFrameTemplate")
            f:SetPoint("CENTER", StrategosMinimap, "TOPLEFT", b.x * StrategosMinimap:GetWidth(), -b.y * StrategosMinimap:GetHeight())
            AlteracPOILookup[strlower(name)] = f
            StrategosMinimapPOI:new(f)
            f.name = name
            f.buildTooltip = function(self, t)
                local left = self.node.timer:remaning()
                if left then
                    local m,s = floor(left/60), mod(left, 60)
                    return format(self.node.name..": %d:%02d", m, s)
                end
            end
            f.buildMenu = function(self)
                if self.node.timer:remaning() then
                    UIDropDownMenu_AddButton({
                        text = "[BG] " .. self.node.name,
                        func = function()
                            local left = self.node.timer:remaning()
                            if left then
                                local m,s = floor(left/60), mod(left, 60)
                                SendChatMessage(format(self.node.name..": %d:%02d", m, s), "BATTLEGROUND")
                            end
                        end
                    })
                end
            end
            f.pin:SetTexture("Interface\\Minimap\\POIIcons")
            f.colorful = true
            f:Hide()
        end
    end
    
    local f = getglobal("StrategosMinimapEFCIndicator")
    if not f then
        f = CreateFrame("Model", "StrategosMinimapEFCIndicator", StrategosMinimap)
        f:SetWidth(125)
        f:SetHeight(125)
        f:SetPosition(-0.0125,-0.0125,0)
        f:SetModel("Interface\\MiniMap\\Ping\\MinimapPing.mdx")
        f.closeTimer = Timer:new(2.5)
        f.farTimer = Timer:new(2.5)
        f:SetScript("OnUpdate",function()
            if f.closeTimer:remaning() then
                this:ClearAllPoints()
                this:SetPoint("CENTER", getglobal("StrategosMinimapDot"..this.closeIndex))
                this:SetScale(0.4)
                this:SetAlpha(1)
                this:Show()
            elseif f.farTimer:remaning() then
                this:ClearAllPoints()
                this:SetPoint("CENTER", getglobal("StrategosMinimapDot"..this.farIndex))
                this:SetScale(1)
                this:SetAlpha(0.33)
                this:Show()
            else
                this:Hide()
            end
        end)
        Object.connect(f.closeTimer, "started", f, f.Show)
        Object.connect(f.farTimer, "started", f, f.Show)
    end
end

function Battleground:scoreUpdate()
end

function Battleground:updateWorldStates()
end

function Battleground:leave()
end

function Battleground:_leave()
    self:leave()
    self:finished()
    self.startTimer:stop()
    function StrategosMinimapPlugin:getHighlight() end
    for _,f in StrategosMinimapPlugin.frames or {} do
        f:Hide()
    end
    StrategosMinimapPlugin.frames = {}
end

function Battleground:processChatEvent(message, faction)
    debug(format("Unhandled chat \"%s\" faction %d", message, faction))
end

if not StrategosMinimap_Plugins then
    getfenv(0).StrategosMinimap_Plugins = {}
end

function Battleground:processAddOnMessage()
end

tinsert(StrategosMinimap_Plugins, StrategosMinimapPlugin)
