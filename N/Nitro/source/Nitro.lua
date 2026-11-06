Nitro = {}

setmetatable(Nitro, {__index = getfenv() })
setfenv(1, Nitro)

local function dist(x,y)
    return sqrt(x*x + y*y)
end

local defaultSettings = {}

handler = EFrame.Object()
handler:attach("scale")
handler.__scale = 1

eventHandler = CreateFrame("frame")
eventHandler:RegisterEvent("ADDON_LOADED")
eventHandler:SetScript("OnEvent", function() EFrame:atomic(this[event]) end)

eventHandler.units = {}
eventHandler.speeds = {}
eventHandler.gx = 0
eventHandler.gy = 0
eventHandler.gspeed = 0
setmetatable(eventHandler.units, {__index = function(self, k) self[k] = {
    x = 0,
    y = 0,
    speed = 0,
    t = GetTime(),
    lz = nil,
    lastSpeed = 0,
} return self[k] end})

eventHandler.zoneData = {}
setmetatable(eventHandler.zoneData, {__index = function(self, k) self[k] = {} return self[k] end})

local GLOBAL_RATIO = 0.0001572857142857143
local function updateUnitPos(unit)
    local x, y = GetPlayerMapPosition(unit)
    local t = GetTime()
    y = y * 2 / 3
    local td = arg1 + this.units[unit].t
    local d = dist(x - this.units[unit].x, y - this.units[unit].y) / td
    if d == 0 and unit ~= "player" and td < 3 then
        this.units[unit].t = this.units[unit].t + arg1
        return
    end
    local ii, it = IsInInstance()
    ii = ii == 1
    if ii and it ~= "pvp" then
        return
    end
    local dd = GLOBAL_RATIO
    local zone = GetRealZoneText()
    if ii then
        if zone == "Alterac Valley" then
            dd = 0.0016666
        elseif zone == "Warsong Gulch" then
            dd = 0.00615
        elseif zone == "Arathi Basin" then
            dd = 0.004
        else
            return
        end
    end
    if NitroSettings.r[zone] then
        dd = dd * NitroSettings.r[zone]
    end
    if zone == this.units[unit].lz and (eventHandler.units[unit].x ~= 0 or eventHandler.units[unit].y ~= 0) then
        if d ~= 0 then
            d = d / dd
            local w = math.pow(1 - math.abs(d - this.units[unit].lastSpeed) / (this.units[unit].lastSpeed + d),2)
            this.units[unit].lastSpeed = d
            this.units[unit].speed = this.units[unit].speed*(1-w) + d * w
        else this.units[unit].speed = this.units[unit].speed*0.9 end
    end
    eventHandler.units[unit].x, eventHandler.units[unit].y, eventHandler.units[unit].t = x, y, 0
    this.units[unit].lz = zone
end

local cache = {}
setmetatable(cache, {__index = function(self, k) self[k] = {} return self[k] end})

setmetatable(cache.party, {__index = function(self, k) self[k] = "party"..k return self[k] end})
setmetatable(cache.raid, {__index = function(self, k) self[k] = "raid"..k return self[k] end})

local data = {}
eventHandler:SetScript("OnUpdate", function ()
    local ii, it = IsInInstance()
    ii = ii == 1
    if ii and it ~= "pvp" then
        return
    end
    local dd = GLOBAL_RATIO
    local zone = GetRealZoneText()
    if ii then
        if zone == "Alterac Valley" then
            dd = 0.0016666
        elseif zone == "Warsong Gulch" then
            dd = 0.00615
        elseif zone == "Arathi Basin" then
            dd = 0.004
        else
            return
        end
    end
    local cc = GetCurrentMapContinent()
    local cz = GetCurrentMapZone()
    SetMapToCurrentZone()
    if NitroSettings.r[zone] or ii then
        updateUnitPos("player")
        for i = 1, GetNumPartyMembers() do
            updateUnitPos(cache.party[i])
        end
        for i = 1, GetNumRaidMembers() do
            updateUnitPos(cache.raid[i])
        end
    else
        local x, y = GetPlayerMapPosition("player")
        local t = GetTime()
        y = y * 2 / 3
        local td = arg1
        local d = dist(x - this.units.player.x, y - this.units.player.y) / td
        if not ii and d ~= 0 then
            SetMapZoom(0)
            local x, y = GetPlayerMapPosition("player")
            y = y * 2 / 3
            local gg = dist(x - this.gx, y - this.gy) / td
            local r = d/gg
                        if d < 0.01 then
                            tinsert(eventHandler.zoneData[zone], r)
                            local mean, error, n = 0, 0, getn(eventHandler.zoneData[zone])
                            for k, v in ipairs(eventHandler.zoneData[zone]) do
                            mean = mean + v
                            error = error + math.pow(v, 2)
                            end
                            mean = mean/n
                        error = math.sqrt((error/n - math.pow(mean,2))/n)/mean
                        if error < 0.0001 and n > 49 then
                            NitroSettings.r[zone] = mean
                        end
                        end
            local gd = gg/GLOBAL_RATIO
            local lspeed = this.speeds[zone] or 1
            if zone == this.units.player.lz then
                this.gspeed = this.gspeed*.95 + gd *.05
                local a = math.min(1, math.abs(1 - lspeed/(d/gd)))
                lspeed = lspeed * (1-a) + (d/gd) * a
                this.speeds[zone] = lspeed
            end
            dd = lspeed
            this.gx, this.gy = x, y
        end
        d = d / dd
        this.units.player.x, this.units.player.y, this.units.player.t = x, y, 0
        if zone == this.units.player.lz then
            local w = math.abs(d - this.units.player.speed) /(math.max(this.units.player.speed, d) + 0.1)
            this.units.player.speed = this.units.player.speed*(1-w) + d * w
        end
    end
    this.units.player.lz = zone
    if cc > -1 then
        SetMapZoom(cc,cz)
    end
end)
    
function GetUnitSpeed(unit)
    local speed
    if unit == "player" then
        speed = eventHandler.units.player.speed
    else
        for k, v in pairs(eventHandler.units) do
            if UnitIsUnit(unit, k) then
                speed = v.speed
                break
            end
        end
    end
    return (speed or 0)* 7
end

anchor = EFrame.MouseArea()
anchor.width = EFrame.bind(function() return handler.scale * 1024 end)
anchor.height = EFrame.bind(anchor, "width")
anchor.tex = EFrame.Rectangle(anchor)
anchor.tex.anchorFill = anchor
anchor.tex.borderWidth = 2
anchor.tex.borderColor = {.25,1,1}
anchor.tex.color = {.25,1,1,0.1}
anchor.dragTarget = anchor
anchor.visible = false

anchor.scalingHandle = EFrame.Button(anchor)
anchor.scalingHandle.icon = "Interface\\Addons\\EmeraldFramework\\Textures\\ResizeHandle_small"
anchor.scalingHandle.width=14
anchor.scalingHandle.height=14
anchor.scalingHandle.anchorBottom = anchor.bottom
anchor.scalingHandle.anchorRight = anchor.right
anchor.scalingHandle:connect("pressedChanged", function (p)
    local handle = anchor.scalingHandle
    if p then
        handle.ox = handle.mouseX
        handle.oy = handle.mouseY
    end
end)
anchor.scalingHandle:connect("mouseXChanged", function (x)
    local handle = anchor.scalingHandle
    if handle.__pressed then
        handler.scale = math.max((anchor.__width + (x - handle.ox)) / 1024, 0.2)
    end
end)

meter = EFrame.Item()
meter.anchorFill = anchor

meter.texTop = EFrame.Image(meter)
meter.texTop.anchorTopLeft = meter.topLeft
meter.texTop.width = EFrame.bind(function() return meter.width * 0.5 end)
meter.texTop.height = EFrame.bind(function() return meter.height * 0.5 end)
meter.texTop.source = "Interface\\AddOns\\Nitro\\nitro1"
meter.texBot = EFrame.Image(meter)
meter.texBot.anchorBottomLeft = meter.bottomLeft
meter.texBot.width = EFrame.bind(function() return meter.width * 0.5 end)
meter.texBot.height = EFrame.bind(function() return meter.height * 0.5 end)
meter.texBot.source = "Interface\\AddOns\\Nitro\\nitro2"

function MakeIndicator(unit, color, z)
    local indicator1
    indicator1 = EFrame.Image(meter)
    indicator1:attach("speed")
    indicator1.__speed = 0
    indicator1.source = "Interface\\AddOns\\Nitro\\NitroIndicator"
    indicator1.z = z
    indicator1.width = EFrame.bind(function() return meter.width * 0.09 end)
    indicator1.height = EFrame.bind(indicator1, "width")
    indicator1.color = color
    indicator1.anchorCenter = meter.center
    indicator1.hoffset = EFrame.bind(function() return - meter.width * 0.385 * math.cos(-indicator1.speed/7 * math.pi/4 + math.pi/4 * 1.2) end)
    indicator1.voffset = EFrame.bind(function() return - meter.width * 0.385 * math.sin(-indicator1.speed/7 * math.pi/4 + math.pi/4 * 1.2) end)
    indicator1.rotation = EFrame.bind(function() return indicator1.speed/7 * math.pi/4 - math.pi/4 * 1.2 end)
    EFrame.root:connect("update", function ()
        local a = 0
        if indicator1.lastUpdate then
            a = math.min((GetTime() - indicator1.lastUpdate)/0.125, 1)
        else
            a = 0
        end
        indicator1.lastUpdate = GetTime()
        indicator1.speed = indicator1.speed * (1-a) + a * GetUnitSpeed(unit)
        indicator1.visible = UnitExists(unit)
    end)
    return indicator1
end
indicator1 = MakeIndicator("player", {1,0,0,.66}, 5)
indicator2 = MakeIndicator("target", {0,0,0,.66}, 4)

function eventHandler.ADDON_LOADED()
    if arg1 == "Nitro" then
        if not NitroProfile then
            setglobal("NitroProfile", {})
        end
        if not NitroSettings then
            setglobal("NitroSettings", {r={}})
        end
        setmetatable(NitroProfile, {__index = defaultSettings})
        
        if not NitroProfile.x then
            anchor.marginLeft = EFrame.bind("(EFrame.root.width - self.width)/2")
            anchor.marginTop =  EFrame.bind("(EFrame.root.height - self.height)/2")
        else
            anchor.marginLeft = NitroProfile.x
            anchor.marginTop = NitroProfile.y
        end
        anchor.anchorTopLeft = EFrame.root.topLeft
        anchor:connect("marginLeftChanged", function(x) NitroProfile.x = x end)
        anchor:connect("marginTopChanged", function(y) NitroProfile.y = y end)
        
        handler.scale = NitroProfile.scale
        handler:connect("scaleChanged", function(s) NitroProfile.scale = s end)
    end
end

local function chatcmd(msg)
    if msg == "unlock" then
        anchor.visible = true
    elseif msg == "lock" then
        anchor.visible = false
    end
end

setglobal("SLASH_NITRO1", "/nitro")
    SlashCmdList["NITRO"] = chatcmd
