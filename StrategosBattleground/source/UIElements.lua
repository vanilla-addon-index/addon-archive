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

EFrame.newClass("SpinningCountdown", EFrame.Image)

SpinningCountdown:attach("time")
SpinningCountdown:attach("looping")
SpinningCountdown:attach("duration")
SpinningCountdown:attach("remaning")
SpinningCountdown:attach("showTime")
SpinningCountdown:attach("message")
SpinningCountdown.__time = 0
SpinningCountdown.__remaning = 0
SpinningCountdown.__duration = 0
SpinningCountdown.__message = ""

function SpinningCountdown:new(parent)
    EFrame.Image.new(self, parent)
    self.source = "Interface\\AddOns\\"..addonName.."\\Textures\\SpinningCountdownRing"
    self.implicitWidth = 32
    self.implicitHeight = 32
    self.head = EFrame.Image(self)
    self.head.source = "Interface\\AddOns\\"..addonName.."\\Textures\\SpinningCountdownHead"
    self.head.implicitWidth = EFrame.bind(function() return self.width end)
    self.head.implicitHeight = EFrame.bind(function() return self.height end)
    self.head.voffset = -2
    self.head.anchorCenter = self.top
    self._headColor = EFrame.bind(function() return self.head.color end)
    self.head.color = EFrame.bind(function() return self.color end)
    self.animation = EFrame.PropertyAnimation(self)
    self.animation.property = "remaning"
    self.animation.from = EFrame.bind(function() return self.time - GetTime() end)
    self.animation.duration = EFrame.bind(function() return self.time - GetTime() end)
    self.animation.to = 0
    self.label = EFrame.Label(self)
    self.label.anchorCenter = self.center
    self.label.text = EFrame.bind(function() return math.max(0, math.ceil(self.remaning)) end)
    self.label.visible = EFrame.bind(self, "showTime")
    self.rotation = EFrame.bind(function ()
        return self.duration > 0 and (self.duration - self.remaning) / self.duration * 2 * math.pi or 0
    end)
    self.animation:connect("finished", function ()
        if self.looping then
            self:restart(self.duration)
        else
            self.flashing.running = true
        end
    end)
    self.flashing = EFrame.PropertyAnimation(self)
    self.flashing.from = 1
    self.flashing.to = 0
    self.flashing.duration = 1.125
    self.flashing.property = "opacity"
    self.flashing.looping = true
    self.mouse = EFrame.MouseArea(self)
    self.mouse.anchorFill = self
    self.mouse.hoverEnabled = true
    self.mouse:connect("containsMouseChanged", function (c)
        if c then
            GameTooltip:SetOwner(self.mouse.frame, "ANCHOR_BOTTOM")
            self:refreshTooltip()
            EFrame.root:connect("update", self, "refreshTooltip")
            GameTooltip:Show()
        elseif GameTooltip:IsOwned(self.mouse.frame) then
            EFrame.root:disconnect("update", self, "refreshTooltip")
            GameTooltip:Hide()
        end
    end)
    self.mouse:connect("clicked", function (c)
        if self.time - GetTime() >= 0 then
            local t = math.max(0, math.ceil(self.time - GetTime()))
            SendChatMessage(format("%s in: %d:%02d", self.message , math.floor(t/60), mod(t,60)), "INSTANCE_CHAT")
        end
    end)
    self.mouse.enabled = EFrame.bind(function() return self.animation.running or self.flashing.running end)
end

function SpinningCountdown:refreshTooltip()
    if not GameTooltip:IsOwned(self.mouse.frame) then
        return EFrame.root:disconnect("update", self, "refreshTooltip")
    end
    if self.time - GetTime() >= 0 then
        local t = math.max(0, math.ceil(self.time - GetTime()))
        GameTooltip:SetText(format("%s in: %d:%02d", self.message , math.floor(t/60), mod(t,60)))
    else
        GameTooltip:SetText(self.message)
    end
end

function SpinningCountdown:restart(r,d)
    self.animation.running = false
    d = d or r
    self.duration = d
    self.time = GetTime() + r
    self.opacity = 1
    self.flashing.running = false
    self.animation.running = true
end

function SpinningCountdown:stop()
    self.animation.running = false
    self.flashing.running = false
    self.opacity = 0
end

EFrame.newClass("FlagFrame", EFrame.Item)

FlagFrame:attach("flag")
FlagFrame:attach("faction")

local classIdx = {
    WARRIOR = 0,
    MAGE = 1,
    ROGUE = 2,
    DRUID = 3,
    HUNTER = 4,
    SHAMAN = 5,
    PRIEST = 6,
    WARLOCK = 7,
    PALADIN = 8
}

function FlagFrame:new(bg, flag, secureId, arenaId)
    EFrame.Item.new(self)
    self.secureId = secureId
    local carrier = flag.carrier
    self.faction = EFrame.bind(carrier, "faction", 3)
    self.bar = EFrame.ProgressBar(self)
    self.label = EFrame.Label(self)
    self.icon = EFrame.Image(self)
    self.button = EFrame.Item(self, _G["StrategosSecureBtn"..secureId] or CreateFrame("Button", "StrategosSecureBtn"..secureId, nil, "SecureActionButtonTemplate"), false)
    _G["StrategosSecureBtn" .. secureId]:Show()
    self.button.frame:SetParent(self.frame)
    if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC or not arenaId then
        self.button:attach("actual")
        self.button.frame:SetAttribute("type1","macro")
        carrier:connect("nameChanged", self, "updateSecureButton").nocombat = true
    else
        self.button.frame:SetAttribute("type", "target")
        self.button.frame:SetAttribute("unit", "arena"..arenaId)
    end
        
    self.timer = SpinningCountdown(self)
    if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC or not arenaId then
        self.label.color = EFrame.bind(function() return self.button.actual == carrier.name and (self.faction == Alliance and {0,0,1,1} or {1,0,0,1}) or {.5,.5,.5} end)
    else
        self.label.color = EFrame.bind(function() return self.faction == Alliance and {0,0,1,1} or {1,0,0,1} end)
    end
    self.label.text = EFrame.bind(function ()
        if flag.status == Flag.Carried then
            return flag.carrier.name or "????"
        elseif flag.status == Flag.Ground then
            return tr("__GROUND__")
        end
    end)
    self.bar.anchorLeft = self.left
    self.bar.anchorRight = self.icon.left
    self.bar.marginRight = 6
    self.bar.from = 0
    self.bar.to = 100
    self.bar.texture = "Interface\\TargetingFrame\\UI-StatusBar"
    self.bar.color = {0,1,0,1}
    self.bar.implicitWidth = EFrame.bind(function() return math.max(self.label.implicitWidth, EFrame.normalizeUI(96)) + 8 end)
    self.bar:setNoCombat("implicitWidth")
    self.bar.height = EFrame.bind(function() return self.height end)
    self.bar.value = EFrame.bind(function() return carrier.health or 0 end)
    self.label.z = 2
    self.label.anchorFill = self.bar
    
    self.button.margins = -4
    self.button.anchorFill = self.bar
    self.button.flat = true
    self.button.backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    }
    self.button.backdropColor = EFrame.bind(function() return self.faction == Alliance and {0,0,1,.25} or {1,0,0,.25} end)
    
    self.icon.marginRight = 2
    self.icon.anchorRight = self.timer.left
    self.icon.source = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes.blp"
    self.icon.height = EFrame.bind(function() return self.height end)
    self.icon.width = EFrame.bind(function() return self.height end)
    carrier:connect("classChanged", function (class)
        local idx = classIdx[class]
        if idx then
            local sx, sy = mod(idx,4), floor(idx/4)
            self.icon:setCoords(sx/4, (sx +1)/4, sy/4, (sy +1)/4)
        end
    end)
    self.icon.opacity = EFrame.bind(function() return flag.status == Flag.Carried and 1 or 0 end)
    self.timer.anchorRight = self.right
    self.timer.height = EFrame.bind(function() return self.height end)
    self.timer.width = EFrame.bind(function() return self.height end)
    flag:connect("placed", self.timer, "stop")
    flag:connect("picked", self.timer, "stop")
    self.timer.message = "Resetting"
    self.timer.opacity = 0
    flag:connect("resetting", self.timer, "restart")
    self.implicitWidth = EFrame.bind(function() return self.bar.implicitWidth + self.icon.width + self.timer.width + 8 end)
    self.opacity = EFrame.bind(function() local status = flag.status return status and status ~= Flag.Resetting and 1 or 0.15 end)
end

function FlagFrame:destroy()
    EFrame.Item.destroy(self)
    EFrame:invokeNoCombat(_G["StrategosSecureBtn" .. self.secureId].Hide, _G["StrategosSecureBtn" .. self.secureId])
end

function FlagFrame:updateSecureButton(v)
    if v then
        self.button.frame:SetAttribute("macrotext1", "/target "..v)
    else
        self.button.frame:SetAttribute("macrotext1", nil)
    end
    self.button.actual = v
end

EFrame.newClass("SpiritHealerIndicator", EFrame.Item)

SpiritHealerIndicator:attach("node")

function SpiritHealerIndicator:new(parent)
    EFrame.Item.new(self, parent)
    self.bar = EFrame.ProgressBar(self, parent)
    self.bar.marginTop = 4
    self.bar.anchorTop = self.top
    self._value = EFrame.alias(self.bar, "value")
    self.marginTop = 60 * UIParent:GetScale() / EFrame.root.scale
    self.anim = EFrame.PropertyAnimation(self)
    self.bl = EFrame.Label(self)
    self.bl.anchorFill = self.bar
    self.bl.text = EFrame.bind(function() return format("Spirit Healer: %d", math.floor(tresstime) - self.bar.value) end)
    self.bar.texture = "Interface\\TargetingFrame\\UI-StatusBar"
    self.bar.height = 15
    self.bar.from = 0
    self.bar.to = math.ceil(tresstime)
    self.width = 115 * UIParent:GetScale() / EFrame.root.scale
    self.bar.width = EFrame.bind(self, "width")
    self.anim.from = EFrame.bind(function() return (1-mod(tresstime,1)) + tresstime - self.anim.duration end)
    self.anim.to = math.ceil(tresstime)
    self.anim.property = "value"
    self.anim:connect("runningChanged", function (v)
        if not v then
            self.anim.duration = self.node:spiritHealerTime()
            self.anim.running = true
        end
    end)
    self.br = EFrame.Rectangle(self)
    self.br.anchorFill = self.bar
    self.br.margins = -4
    self.br.color = {0,0,0,0}
    self.br.borderWidth = 2
    self.br.borderColor = {0,0,0,1}
    self.opacity = EFrame.bind(function() return 0.33 + self.bar.value/self.bar.to * 0.66 end)
    self.label = EFrame.Label(self.bar)
    self.label.anchorTop = self.br.bottom
    self.label.text = EFrame.bind(function() return self.node and self.node.name or "" end)
    self.height = EFrame.bind(function() return self.bar.height + self.label.height + 8 end)
end

function SpiritHealerIndicator:restart(node)
    self.anim.running = false
    self.anim.duration = node:spiritHealerTime()
    self.node = node
    self.anim.running = true
end
