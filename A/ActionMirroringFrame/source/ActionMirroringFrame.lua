local AMF
if ActionMirroringFrame == nil then 
    ActionMirroringFrame = {}
end
AMF = ActionMirroringFrame

local _G = getfenv()
setmetatable(AMF, {__index = _G })
setfenv(1, AMF)

ACTION_TYPE_NORMAL = 1
ACTION_TYPE_SPECIAL = 2
ACTION_TYPE_PET = 3

actions = {{},{},{}}
spells = {}

local eventHandler = CreateFrame("frame")
eventHandler:RegisterEvent("ADDON_LOADED")
-- eventHandler:RegisterEvent("SPELLCAST_SUCCEEDED")
eventHandler:RegisterEvent("SPELLCAST_STOP")
-- eventHandler:RegisterEvent("UNIT_SPELLCAST_FAILED")
-- eventHandler:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
-- eventHandler:RegisterEvent("UNIT_SPELLCAST_FAILED")
-- eventHandler:RegisterEvent("SPELLCAST_START")
-- eventHandler:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
-- eventHandler:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
-- eventHandler:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
eventHandler:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")

local current = {}
local currentChannel = {}

local currentAction
local currentError
local lastStopCast = 0

defaultSettings = {
    scale = 1,
    timeout = 3,
    maxFrames = 4,
    vertical = false,
    direction = 1,
    powerAnchor = 0,
    noDoubles = true,
    posAnims = true,
    successAnim = 1,
    showRanks = true,
    rankStyle = 1,
    showHotkeys = true,
    stickyCD = 0,
    showCooldownTip = true,
    cooldownTipThreshold = 1.5,
    showMissingPower = true
}

local defaultColors = {
    CURRENT = {0,1,0,.8},
    NOMANA = {0,0,1,1},
    NOTUSABLE = {0.5,0,0,.8},
    NOTINRANGE = {1,1,0,.8},
    EQUIPPED = {0,1,0,0.5},
}

function eventHandler.ADDON_LOADED()
    if arg1 == "ActionMirroringFrame" then
        if not ActionMirroringFrameProfile then
            setglobal("ActionMirroringFrameProfile", {})
        end
        setmetatable(ActionMirroringFrameProfile, {__index = defaultSettings})
        
        if not ActionMirroringFrameProfile.x then
            anchor.marginLeft = EFrame.bind("(EFrame.root.width - self.width)/2")
            anchor.marginTop =  EFrame.bind("EFrame.root.height*0.6")
        else
            anchor.marginLeft = EFrame.normalizeBind(ActionMirroringFrameProfile.x)
            anchor.marginTop = EFrame.normalizeBind(ActionMirroringFrameProfile.y)
        end
        anchor.anchorTopLeft = EFrame.root.topLeft
        anchor:connect("marginLeftChanged", function(x) ActionMirroringFrameProfile.x = EFrame.normalized(x) end)
        anchor:connect("marginTopChanged", function(y) ActionMirroringFrameProfile.y = EFrame.normalized(y) end)
        
        ActionMirroringFrameHandler.scale = ActionMirroringFrameProfile.scale
        ActionMirroringFrameHandler:connect("scaleChanged", function(s) ActionMirroringFrameProfile.scale = s end)
        
        ActionMirroringFrameHandler.timeout = ActionMirroringFrameProfile.timeout
        ActionMirroringFrameHandler:connect("timeoutChanged", function(n) ActionMirroringFrameProfile.timeout = n end)
        
        ActionMirroringFrameHandler.maxFrames = ActionMirroringFrameProfile.maxFrames
        ActionMirroringFrameHandler:connect("maxFramesChanged", function(n) ActionMirroringFrameProfile.maxFrames = n end)
        
        ActionMirroringFrameHandler.showRanks = ActionMirroringFrameProfile.showRanks
        ActionMirroringFrameHandler:connect("showRanksChanged", function(n) ActionMirroringFrameProfile.showRanks = n end)
        
        ActionMirroringFrameHandler.rankStyle = ActionMirroringFrameProfile.rankStyle
        ActionMirroringFrameHandler:connect("rankStyleChanged", function(n) ActionMirroringFrameProfile.rankStyle = n end)
        
        ActionMirroringFrameHandler.vertical = ActionMirroringFrameProfile.vertical
        ActionMirroringFrameHandler:connect("verticalChanged", function(v) ActionMirroringFrameProfile.vertical = v end)
        
        ActionMirroringFrameHandler.direction = ActionMirroringFrameProfile.direction
        ActionMirroringFrameHandler:connect("directionChanged", function(d) ActionMirroringFrameProfile.direction = d end)
        
        ActionMirroringFrameHandler.powerAnchor = ActionMirroringFrameProfile.powerAnchor
        ActionMirroringFrameHandler:connect("powerAnchorChanged", function(d) ActionMirroringFrameProfile.powerAnchor = d end)
        
        ActionMirroringFrameHandler.noDoubles = ActionMirroringFrameProfile.noDoubles
        ActionMirroringFrameHandler:connect("noDoublesChanged", function(d) ActionMirroringFrameProfile.noDoubles = d end)
        
        ActionMirroringFrameHandler.posAnims = ActionMirroringFrameProfile.posAnims
        ActionMirroringFrameHandler:connect("posAnimsChanged", function(d) ActionMirroringFrameProfile.posAnims = d end)
        
        ActionMirroringFrameHandler.successAnim = ActionMirroringFrameProfile.successAnim
        ActionMirroringFrameHandler:connect("successAnimChanged", function(d) ActionMirroringFrameProfile.successAnim = d end)
        
        ActionMirroringFrameHandler.showHotkeys = ActionMirroringFrameProfile.showHotkeys
        ActionMirroringFrameHandler:connect("showHotkeysChanged", function(d) ActionMirroringFrameProfile.showHotkeys = d end)
        
        ActionMirroringFrameHandler.stickyCD = ActionMirroringFrameProfile.stickyCD
        ActionMirroringFrameHandler:connect("stickyCDChanged", function(d) ActionMirroringFrameProfile.stickyCD = d end)
        
        ActionMirroringFrameHandler.showCooldownTip = ActionMirroringFrameProfile.showCooldownTip
        ActionMirroringFrameHandler:connect("showCooldownTipChanged", function(d) ActionMirroringFrameProfile.showCooldownTip = d end)
        
        ActionMirroringFrameHandler.cooldownTipThreshold = ActionMirroringFrameProfile.cooldownTipThreshold
        ActionMirroringFrameHandler:connect("cooldownTipThresholdChanged", function(d) ActionMirroringFrameProfile.cooldownTipThreshold = d end)
        
        ActionMirroringFrameHandler.showMissingPower = ActionMirroringFrameProfile.showMissingPower
        ActionMirroringFrameHandler:connect("showMissingPowerChanged", function(d) ActionMirroringFrameProfile.showMissingPower = d end)

        this.current = {}
        this.id = 0
        if not _G.ActionMirroringFrameSettings then
            _G.ActionMirroringFrameSettings = {}
        end
        if not ActionMirroringFrameSettings.borderColors then
            ActionMirroringFrameSettings.borderColors = {}
        end
        for k, v in pairs(ActionMirroringFrameSettings.borderColors) do
            borderColors[k] = v
        end
        for k in pairs(defaultColors) do
            local k = k
            borderColors:connect(k.."Changed", function(v) ActionMirroringFrameSettings.borderColors[k] = v end)
        end
    end
end

EFrame.root:connect("update", function ()
    ActionMirroringFrame_SpellHook()
    ActionMirroringFrame_InventoryHook()
    ActionMirroringFrame_ContainerHook()
    ActionMirroringFrame_ShapeshiftHook()
    ActionMirroringFrame_ActionHook(eventHandler)
end)
    
local function GetSpellID(sn)
    sn = strlower(sn)
    if not rank then
        name = sn
    end
    
    local i,a,r,f = 1, GetSpellName(1,BOOKTYPE_SPELL)
    while a do
        if strlower(format("%s(%s)", a, r or "")) == sn then
            return i
        elseif strlower(a) == sn then
            f = i
        elseif f then
            return f
        end
        i = i+1
        a,r = GetSpellName(i,BOOKTYPE_SPELL)
    end
    return f
end

function eventHandler.SPELLCAST_SUCCEEDED()
    local action = spells[arg1][1]
    if action then
        action.successTime = GetTime()
        if action.actionType == ACTION_TYPE_NORMAL then
            action.used = not IsAutoRepeatAction(action.id)
        else
            action.used = true
        end
    end
end

function eventHandler.SPELLCAST_STOP()
    ActionMirroringFrameHandler:stopCast()
end
eventHandler.UNIT_SPELLCAST_FAILED = eventHandler.UNIT_SPELLCAST_STOP
eventHandler.UNIT_SPELLCAST_FAILED_QUIET = eventHandler.UNIT_SPELLCAST_STOP


function eventHandler.UNIT_SPELLCAST_START()
    local st = spells[arg1]
    if getn(st) == 1 then
        ActionMirroringFrameHandler:onActionUsed(st[1].id, st[1].actionType)
    end
end

function eventHandler.UNIT_SPELLCAST_CHANNEL_START(target)
    if target ~= "player" and target ~= "pet" then return end
    if current[target] then
        current[target].channeling = true
        currentChannel[target] = current[target]
    end
end

function eventHandler.UNIT_SPELLCAST_CHANNEL_STOP(target)
    if target ~= "player" and target ~= "pet" then return end
    if currentChannel[target] then
        currentChannel[target].channeling = false
    end
end

function eventHandler.UNIT_SPELLCAST_CHANNEL_UPDATE(target)
    if target ~= "player" and target ~= "pet" then return end
    if currentChannel[target] then
        currentChannel[target].channeling = true
    end
end

function eventHandler.CURRENT_SPELL_CAST_CHANGED()
    if currentAction then
        currentAction.sent = true
    end
end

eventHandler:SetScript("OnEvent", function() EFrame:atomic(this[event]) end)


ActionMirroringFrameHandler = EFrame.Object()
ActionMirroringFrameHandler:attach("scale")
ActionMirroringFrameHandler:attach("maxFrames")
ActionMirroringFrameHandler:attach("powerAnchor")
ActionMirroringFrameHandler:attach("direction")
ActionMirroringFrameHandler:attach("vertical")
ActionMirroringFrameHandler:attach("mirrors")
ActionMirroringFrameHandler:attach("noDoubles")
ActionMirroringFrameHandler:attach("posAnims")
ActionMirroringFrameHandler:attach("successAnim")
ActionMirroringFrameHandler:attach("showRanks")
ActionMirroringFrameHandler:attach("timeout")
ActionMirroringFrameHandler:attach("rankStyle")
ActionMirroringFrameHandler:attach("showHotkeys")
ActionMirroringFrameHandler:attach("showCooldownTip")
ActionMirroringFrameHandler:attach("stickyCD")
ActionMirroringFrameHandler:attach("cooldownTipThreshold")
ActionMirroringFrameHandler:attach("showMissingPower")
ActionMirroringFrameHandler:attachSignal("actionUsed")
ActionMirroringFrameHandler:attachSignal("stopCast")
ActionMirroringFrameHandler.__scale = 1
ActionMirroringFrameHandler.__direction = 1
ActionMirroringFrameHandler.__powerAnchor = 0
ActionMirroringFrameHandler.__rankStyle = 1
ActionMirroringFrameHandler.__showRanks = true
ActionMirroringFrameHandler.__noDoubles = true
ActionMirroringFrameHandler.__showHotkeys = true
ActionMirroringFrameHandler.__showCooldownTip = true
ActionMirroringFrameHandler.__cooldownTipThreshold = 1.5
ActionMirroringFrameHandler.__mirrors = {}

function ActionMirroringFrameHandler:onMirrorsChanged(m)
    for i = 1, getn(m) do
        m[i].__action.position = m[i].__action.__status ~= "HIDE" and  i or nil
    end
end

-- hooksecurefunc("UseAction", EFrame:makeAtomic(function (id)
--     ActionMirroringFrameHandler:actionUsed(id, ACTION_TYPE_NORMAL)
-- end))
-- hooksecurefunc("CastShapeshiftForm", EFrame:makeAtomic(function (id)
--     ActionMirroringFrameHandler:actionUsed(id, ACTION_TYPE_SPECIAL)
-- end))
-- hooksecurefunc("CastPetAction", EFrame:makeAtomic(function (id)
--     ActionMirroringFrameHandler:actionUsed(id, ACTION_TYPE_PET)
-- end))

function ActionMirroringFrameHandler:onActionUsed(id, type)
    if type == ACTION_TYPE_NORMAL and not HasAction(id) then return
    elseif type == ACTION_TYPE_PET and not GetPetActionInfo(id) then return
    end
    local mirrors = ActionMirroringFrameHandler.__mirrors
    local lasti = getn(mirrors)
    local updatePos = true
    local action
    if ActionMirroringFrameHandler.noDoubles then
        action = actions[type][id]
        if action then
            action.start = GetTime()
            action.actionType = type
            action:update(true)
            if action:IsCurrentMirrorAction() then
                lasti = action.position
                    updatePos = false
            else
                return
            end
        end
    else
        for i = 1, lasti-1 do
            local first = mirrors[i].__action
            if first.__status == "HIDE" or first.id ~= id and first.__status ~= "CURRENT" then
                break
            end
            if first.id == id then
                action = first
                action.start = GetTime()
                action.actionType = type
                action:update(true)
                if action:IsCurrentMirrorAction() then
                    lasti = action.position
                    updatePos = false
                else
                    return
                end
            end
        end
    end
    local le = 1

    local mirror = tremove(mirrors,lasti)
    if not action then
        action = mirror.__action
        action:reset()
        if action.id and actions[type][action.id] == action then actions[type][action.id] = nil end
        action.actionType = type
        action.start = GetTime()
        action.id = id
        actions[type][id] = action
        action:update(true)
    end
    for i = 1, lasti-1 do
        if mirrors[i].__action:IsCurrentMirrorAction() then
            le = i +1
        else
            break
        end
    end
    tinsert(mirrors, le, mirror)
    ActionMirroringFrameHandler:mirrorsChanged(mirrors)
    mirror:updatePosition(updatePos)
    if currentAction and id == currentAction.id then
        action.spell = currentAction.spell
        action.inventory = currentAction.inventory
        action.container = currentAction.container
    end
end

anchor = EFrame.MouseArea()
anchor.width = EFrame.bind(function() return ActionMirroringFrameHandler.scale * EFrame.normalize(45) end)
anchor.height = EFrame.bind(anchor, "width")
anchor.tex = EFrame.Image(anchor)
anchor.tex.anchorFill = anchor
anchor.tex.source = "Interface\\AddOns\\ActionMirroringFrame\\handle.tga"
anchor.tex.rotation = EFrame.bind(function() return ActionMirroringFrameHandler.direction*math.pi/2 + (ActionMirroringFrameHandler.vertical and math.pi/2 or 0) end)
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
        ActionMirroringFrameHandler.scale = math.max((anchor.__width + (x - handle.ox)) / EFrame.normalize(45), 0.5)
    end
end)

EFrame.newClass("Action", EFrame.Object)
Action:attach("status")
Action:attach("texture")
Action:attach("usable")
Action:attach("nomana")
Action:attach("missingPower")
Action:attach("powerType")
Action:attach("cdEnabled")
Action:attach("cdStart")
Action:attach("cdDuration")
Action:attach("pressed")
Action:attach("hotkey")
Action:attach("count")
Action:attach("position")
Action:attach("rank")
Action:attach("rankMax")
Action.__status = "HIDE"
Action.__start = 0
Action.__count = ""
Action.__time = 0
Action.__missingPower = 0
Action.__powerType = 0
Action.__position = 1
Action.__rank = 0
Action.__rankMax = 0

function Action:new()
    EFrame.Object.new(self)
    EFrame.root:connect("update", self, "update")
    self:connect("statusChanged", function (s)
        if s == "HIDE" then
            local mirrors = ActionMirroringFrameHandler.__mirrors
            tinsert(mirrors, tremove(mirrors, self.__position))
            ActionMirroringFrameHandler:mirrorsChanged(mirrors)
            self:reset()
        end
    end)
end

function Action:IsCurrentMirrorAction()
    local id = self.id
    if id then
        ActionMirroringFrameTooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
        ActionMirroringFrameTooltipScanner:SetAction(id)
        if ActionMirroringFrameTooltipScannerTextLeft1:IsVisible() then
            local idx = 1
            local _, name, active = GetShapeshiftFormInfo(idx)
            while name do
                if active == 1 then
                    if name == ActionMirroringFrameTooltipScannerTextLeft1:GetText() then
                        return false
                    end
                    break
                end
                idx = idx + 1
                _, name, active = GetShapeshiftFormInfo(idx)
            end
        end
        return self.actionType == ACTION_TYPE_NORMAL and actions[ACTION_TYPE_NORMAL][id] == self and (IsCurrentAction(id) or IsAutoRepeatAction(id))
    end
end

local bindNameCache = {}
local bindCache = {}
local bindMap = {
    MOUSEWHEELUP = "W↑",
    MOUSEWHEELDOWN = "W↓",
    NUMPAD = "P",
    BUTTON = "M",
}

local function mangleBind(s)
    if not s or s == "" then return "" end
    local c = bindCache[s]
    if c then return c end
    c = ""
    if strfind(s, "ALT") then
        c = "a"
    end
    if strfind(s, "CTRL") then
        c = c .. "c"
    end
    if strfind(s, "SHIFT") then
        c = c .. "s"
    end
    local r
    local b, _, n = strfind(s, "-([^-]*)$")
    if c == "" then
        r = s
    else
        r = n
    end
    if string.len(r) < 4 then
        c = c .. r
    elseif bindMap[r] then
        c = c .. bindMap[r]
    elseif r == "MOUSEWHEELDOWN" then
        c = c .. "MD"
    else
        local b, _, t, n = strfind(r, "(%D*)(%d*)")
        if b then
            c = c .. (bindMap[t] or t) .. n
        else
            c = c .. r
        end
    end
    bindCache[s] = c
    return c
end


CreateFrame("GameTooltip", "ActionMirroringFrameTooltipScanner", nil, "GameTooltipTemplate")

local dummyThis = {}
local function getBindString(name, id)
    if not bindNameCache[name] then
        bindNameCache[name] = {}
    end
    local n = bindNameCache[name]
    if not n[id] then
        n[id] = name .. id
    end
    if not _G.this then
        _G.this = dummyThis
    end
    local r = mangleBind(GetBindingKey(n[id]))
    if _G.this == dummyThis then
        _G.this = nil
    end
    return r
end

local getActionBarNameCache = {}
local function getActionBarName(id)
        local bar = 6 - math.floor((id-1)/12)
        if bar == 4 then
            bar = 3
        elseif bar == 3 then
            bar = 4
        end
    if not getActionBarNameCache[id] then
        getActionBarNameCache[id] = (bar < 1 or id <= 12) and "ACTIONBUTTON" or ("MULTIACTIONBAR"..bar.."BUTTON")
    end
    return getActionBarNameCache[id]
end

function Action:update(wake)
    if wake then self.__status = ""
    elseif self.__status == "HIDE" then return end
    local time = GetTime() - self.start
    if not self.id then return end
    local action = self.id;
    local checkmana
    if self.actionType == ACTION_TYPE_NORMAL then
        if wake then
            self.shapeshift = currentAction.shapeshift
            if currentAction.sent then
                self.sent = ActionMirroringFrameHandler:connect("stopCast", self, "stopCast")
            end
        end
        local button = self.id 
        local actionButtonType = getActionBarName(button)
        self.hotkey = getBindString(actionButtonType, mod(button -1,12)+1)
        if self.shapeshift then
            local current, usable
            self.texture,current = GetShapeshiftFormInfo(self.shapeshift)
            current = self.sent and GetTime() > lastStopCast
            self.cdStart, self.cdDuration, self.cdEnabled = GetShapeshiftFormCooldown(self.shapeshift)
            if not (ActionMirroringFrameHandler.timeout > 0 and time <= ActionMirroringFrameHandler.timeout or current and not self.used or self.channeling or self.cdStart > 0 and self.cdDuration - (GetTime() - self.cdStart)  <= ActionMirroringFrameHandler.stickyCD) then
                self.status = "HIDE"
                if actions[self.actionType][self.id] == self then actions[self.actionType][self.id] = nil end
                return
            elseif current then
                self.status = "CURRENT"
            else
                self.status = "NORMAL"
            end
            checkmana = true
        else
    --         local actionType, id = GetActionInfo(self.id)
    --         if actionType == "macro" then
    --             self.spell = GetMacroSpell(id)
    --         elseif actionType == "spell" then
    --             self.spell = id
    --         elseif actionType == "item" then
    --             _, self.spell = GetItemSpell(id)
    --             self.item = id
    --         else
    --             self.spell = nil
    --         end
            if ( IsConsumableAction(action) or GetActionCount(action) > 0) then
                local count = GetActionCount(action);
                if ( count > 9999 ) then
                    self.count = "*";
                else
                    self.count = count;
                end
            else
                self.count = ""
            end
            local smw = this
            setglobal("this", nil)
            if self.spell then
                self.texture = GetSpellTexture(self.spell, BOOKTYPE_SPELL)
                self.cdStart, self.cdDuration, self.cdEnabled = GetSpellCooldown(self.spell, BOOKTYPE_SPELL)
            elseif self.inventory then
                self.texture = GetInventoryItemTexture("player", self.inventory)
                self.cdStart, self.cdDuration, self.cdEnabled = GetInventoryItemCooldown(self.inventory)
            elseif self.container then
                self.texture = GetContainerItemInfo(self.container.bag, self.container.slot)
                self.cdStart, self.cdDuration, self.cdEnabled = GetContainerItemCooldown(self.container.bag, self.container.slot)
            else
                self.texture = GetActionTexture(self.id)
                self.cdStart, self.cdDuration, self.cdEnabled = GetActionCooldown(self.id)
            end
            setglobal("this", smw)
            local usable, nomana = IsUsableAction(self.id)
            local current = self:IsCurrentMirrorAction()
            if not HasAction(self.id) or not (ActionMirroringFrameHandler.timeout > 0 and time <= ActionMirroringFrameHandler.timeout or current and not self.used or self.channeling or self.cdStart > 0 and self.cdDuration - (GetTime() - self.cdStart)  <= ActionMirroringFrameHandler.stickyCD) then
                self.status = "HIDE"
                if actions[self.actionType][self.id] == self then actions[self.actionType][self.id] = nil end
                return
            elseif current then
                self.status = "CURRENT"
            elseif IsEquippedAction(self.id) then
                self.status = "EQUIPPED"
            elseif nomana then
                self.status = "NOMANA"
                checkmana = true
            elseif not usable then
                self.status = "NOTUSABLE"
            elseif IsActionInRange(self.id) == 0 then
                self.status = "NOTINRANGE"
            else
                self.status = "NORMAL"
            end
        end
    elseif self.actionType == ACTION_TYPE_SPECIAL then
        self.hotkey = getBindString("SHAPESHIFTBUTTON", self.id)
        local current, usable
        self.texture,current,usable,self.spell = GetShapeshiftFormInfo(self.id)
     --   current = current or IsCurrentSpell(self.spell)
        self.cdStart, self.cdDuration, self.cdEnabled = GetShapeshiftFormCooldown(self.id)
        if not (ActionMirroringFrameHandler.timeout > 0 and time <= ActionMirroringFrameHandler.timeout or current and not self.used or self.channeling or self.cdStart > 0 and self.cdDuration - (GetTime() - self.cdStart)  <= ActionMirroringFrameHandler.stickyCD) then
            self.status = "HIDE"
            if actions[self.actionType][self.id] == self then actions[self.actionType][self.id] = nil end
            return
        elseif current then
            self.status = "CURRENT"
        elseif not usable then
            self.status = "NOTUSABLE"
        else
            self.status = "NORMAL"
        end
        checkmana = true
    elseif self.actionType == ACTION_TYPE_PET then
        self.hotkey = getBindString("BONUSACTIONBUTTON", self.id)
        local inRange, hasTarget, tex
        _,tex,_,_, useMana, mana,self.spell, hasTarget,inRange = GetPetActionInfo(self.id)
        self.texture = tonumber(tex) and tex or _G[tex]
        self.cdStart, self.cdDuration, self.cdEnabled = GetPetActionCooldown(self.id)
        local usable = GetPetActionsUsable(self.id)
        if not GetPetActionInfo(self.id) or not (ActionMirroringFrameHandler.timeout > 0 and time <= ActionMirroringFrameHandler.timeout or self.channeling or self.channeling or self.cdStart > 0 and self.cdDuration - (GetTime() - self.cdStart)  <= ActionMirroringFrameHandler.stickyCD) then
            self.status = "HIDE"
            if actions[self.actionType][self.id] == self then actions[self.actionType][self.id] = nil end
            return
        elseif not usable then
            self.status = "NOTUSABLE"
        elseif hasTarget and not inRange then
            self.status = "NOTINRANGE"
        else
            self.status = "NORMAL"
        end
        checkmana = true
    end
    
    if wake and self.spell then
        if not spells[self.spell] then
            spells[self.spell] = {self}
        else
            local found
            for k, s in ipairs(spells[self.spell]) do
                if s.id == self.id then
                    spells[self.spell][k] = self
                    found = true
                    break
                end
            end
            if not found then
                tinsert(spells[self.spell], self)
            end
        end
    end
    if self.lastUpdate and GetTime() - self.lastUpdate < TOOLTIP_UPDATE_TIME then return end
    
    ActionMirroringFrameTooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
    
    self.lastUpdate = GetTime()
    local spell = self.spell
    local inventory = self.inventory
    local container = self.container
    if spell then
        ActionMirroringFrameTooltipScanner:SetSpell(spell,BOOKTYPE_SPELL)
    elseif inventory then
        ActionMirroringFrameTooltipScanner:SetInventoryItem("player", inventory)
    elseif container then
        ActionMirroringFrameTooltipScanner:SetBagItem(container.bag, container.slot)
    else
        ActionMirroringFrameTooltipScanner:SetAction(self.id)
    end
    if ActionMirroringFrameTooltipScannerTextRight1:IsVisible() then
        local tipR1 = ActionMirroringFrameTooltipScannerTextRight1:GetText()
        if tipR1 ~= nil then
            local _,_,rank = strfind(tipR1 or "","(%d+)")
            self.rank = tonumber(rank) or 0
        end
        local tipL1 = ActionMirroringFrameTooltipScannerTextLeft1:GetText()
        if self.rank and tipL1 ~= nil then
            local i = 1
            local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
            local rankMax
            while name do
                if name == tipL1 then
                    rankMax = rank
                elseif rankMax then
                    break
                end
                i = i + 1
                name, rank = GetSpellName(i, BOOKTYPE_SPELL)
            end
            if rankMax then
                _, _, self.rankMax = strfind(rankMax,"(%d+)")
            else
                self.rankMax = self.rank
            end
        end
    end
    if ActionMirroringFrameHandler.showMissingPower then
        local usable, nomana = IsUsableAction(self.id)
        if usable ~= 1 and nomana == 1 then
            local powerType
            if ActionMirroringFrameTooltipScannerTextLeft2:IsVisible() then
                local tip = ActionMirroringFrameTooltipScannerTextLeft2:GetText()
                if tip then
                    local _,_,req, t = strfind(tip or "","(%d+).-(%w+)")
                    if t == MANA then
                        powerType = 0
                    elseif t == RAGE then
                        powerType = 1
                    elseif t == ENERGY then
                        powerType = 3
                    end
                    if powerType and UnitPowerType("player") == powerType then
                        self.missingPower = tonumber(req) - UnitMana("player")
                    end
                    self.powerType = powerType
                end
            end
        end
    end
    self.pressed = time < 0.125
end

function Action:reset()
    self.channeling = false
    self.successTime = nil
    self.used = false
    self.item = nil
    self.rankMax = 0
    self.rank = 0
    self:stopCast()
    if not (self.spell and spells[self.spell]) then return end
    for k, s in ipairs(spells[self.spell]) do
        if s.id == self.id then
            tremove(spells[self.spell], k)
            break
        end
    end
    self.spell = nil
end

function Action:stopCast()
    if self.sent then
        self.sent:disconnect()
        self.sent = nil
    end
end

EFrame.newClass("ActionMirroringFrame", EFrame.Item)
ActionMirroringFrame:attach("action")
ActionMirroringFrame:attach("position")
ActionMirroringFrame.__position = 1

borderColors = EFrame.Object()
for k, v in pairs(defaultColors) do
    borderColors:attach(k)
    borderColors[k] = v
end
borderColors.HIDE = {0,0,0,0}


powerColors = {
    [-2] = {0.5 , 0   , 0   , 0.5 }, -- HP
    [-1] = {0.75, 0.75, 0.75, 0.5 }, -- NONE
    [0] =  {0   , 0   , 1   , 0.5 }, -- MANA
    [1] =  {1   , 0   , 0   , 0.5 }, -- RAGE
    [2] =  {1   , 0.5 , 0   , 0.5 }, -- FOCUS
    [3] =  {1   , 1   , 0   , 0.5 }, -- ENERGY
    [4] =  {1   , 0.96, 0.41, 0.25}, -- COMBO
    [5] =  {0.5 , 0.5 , 0.5 , 0.5 }, -- RUNES
    [6] =  {0   , 0.82, 1   , 0.5 }, -- RUNIC POWER
    [7] =  {0.5 , 0.32, 0.55, 0.5 }, -- SOUL SHARDS
    [8] =  {0.3 , 0.52, 0.90, 0.5 }, -- LUNAR POWER
    [9] =  {0.95, 0.9 , 0.6 , 0.5 }, -- HOLY POWER
    [10] = {0.75, 0.75, 0.75, 0.5 }, -- NONE
    [11] = {0   , 0.5 , 1   , 0.5 }, -- MAELSTROM
    [12] = {0.71, 1   , 0.92, 0.5 }, -- CHI
    [13] = {0.4 , 0   , 0.8 , 0.5 }, -- INSANITY
    [16] = {0.1 , 0.1 , 0.98, 0.5 }, -- ARCANE CHARGES
    [17] = {0.79, 0.26, 0.99, 0.5 }, -- FURY
    [18] = {1   , 0.61, 0   , 0.5 }, -- PAIN
}

rankColors = {
    [0] = {0  ,0  ,0  ,0},
    [1] = {0  ,1  ,0  ,1},
    [2] = {1  ,1  ,0  ,1},
    [3] = {1  ,0  ,0  ,1}
}

hasRanks = true

function ActionMirroringFrame:new(action)
    self.__action = action
    EFrame.Item.new(self)
    self.anchorCenter = anchor.center
    self.hoffset = EFrame.bind(function() return ActionMirroringFrameHandler.vertical and 0 or EFrame.normalize(44) * ActionMirroringFrameHandler.direction * self.position * self.scale end)
    self.voffset = EFrame.bind(function() return -(ActionMirroringFrameHandler.vertical and EFrame.normalize(44) * ActionMirroringFrameHandler.direction * self.position * self.scale or 0) end)
    self.width = EFrame.normalizeBind(40)
    self.height = EFrame.normalizeBind(40)
    self.scale = EFrame.bind(ActionMirroringFrameHandler, "scale")
    self.tex = EFrame.Image(self)
    self.tex:setCoords(0.1,0.9,0.1,0.9)
    self.tex.margins = 2
    self.tex.anchorFill = self
    self.tex.source = EFrame.bind(function() return self.action.texture end)
    self.tex.layer = "BACKGROUND"
    
    ActionMirroringFrameHandler:connect("successAnimChanged", self, "initAnim")
    
    self.border = EFrame.Image(self)
    self.border.margins = EFrame.normalizeBind(-14)
    self.border.anchorFill = self
    self.border.source = 'Interface\\AddOns\\ActionMirroringFrame\\ButtonBorder.tga'
    self.border.layer = "OVERLAY"
    self.highlight = EFrame.Image(self)
    self.highlight.margins = 1
    self.highlight.anchorFill = self
    self.highlight.source = 'Interface\\AddOns\\ActionMirroringFrame\\ButtonHighlight.tga'
    self.highlight.color = EFrame.bind(function() return borderColors[self.action.status] or borderColors.HIDE  end)
    self.highlight.layer = "OVERLAY"
    self.highlight.blendMode = "ADD"
    self.highlight.visible = EFrame.bind(function() return self.action.status ~= "HIDE" end)
    self.powerIndicator = EFrame.Rectangle(self)
    self.powerIndicator.margins = 2
    self.powerIndicator.color = EFrame.bind(function() return powerColors[self.action.powerType] end)
    self.powerIndicator.visible = EFrame.bind(function() return ActionMirroringFrameHandler.showMissingPower and self.action.status == "NOMANA" end)
    local powerAnchor = EFrame.bind(function()
        self.powerIndicator:clearAnchors()
        if ActionMirroringFrameHandler.powerAnchor == -1 or ActionMirroringFrameHandler.vertical then
            self.powerIndicator.anchorBottom = self.bottom
        elseif ActionMirroringFrameHandler.powerAnchor == 1 then
            self.powerIndicator.anchorTop = self.bottom
        else
            self.powerIndicator.anchorBottom = self.top
        end
        self.powerIndicator.anchorLeft = self.left
        self.powerIndicator.anchorRight = self.right
    end)
    powerAnchor.parent = self.powerIndicator
    powerAnchor:update()
    self.powerLabel = EFrame.Label(self.powerIndicator)
    self.powerLabel.marginBottom = 4
    self.powerLabel.marginTop = 2
    self.powerLabel.anchorFill = self.powerIndicator
    self.powerLabel.sizeMode = EFrame.Label.VerticalFit
    self.powerLabel.implicitHeight = EFrame.normalizeBind(10)
    self.powerLabel.text = EFrame.bind(function() return self.action.missingPower end)
    self.powerIndicator.implicitHeight = EFrame.bind(function() return self.powerLabel.implicitHeight + 6 end)
    self.cooldown = EFrame.Cooldown(self)
    self.cooldown.margins = 0
    self.cooldown.anchorCenter = self.tex.center
    self.cooldown.height = EFrame.bind(self.tex, "height");
    self.cooldown.width = EFrame.bind(self.tex, "width");
    self.cooldown.enabled = EFrame.bind(function() return self.action.cdEnabled == 1 end)
    self.cooldown.start = EFrame.bind(function() return self.action.cdStart end)
    self.cooldown.duration = EFrame.bind(function() return self.action.cdDuration end)
    self.cooldownTip = EFrame.Label(self.cooldown)
    self.cooldownTip.anchorFill = self.tex
    self.cooldownTip.margins = 3
    self.cooldownTip.sizeMode = EFrame.Label.Fit
    self.cooldownTip.visible = EFrame.bind(function() return ActionMirroringFrameHandler.showCooldownTip and not self.cooldown.stopping and self.cooldown.duration > ActionMirroringFrameHandler.cooldownTipThreshold end)
    EFrame.root:connect("update", function()
        if self.visible == false then return end
        local left = self.cooldown.duration - GetTime() + self.cooldown.start
        if left <= 60 then
            self.cooldownTip.text = string.format("%.1fs", left)
        else
            self.cooldownTip.text = string.format("%d:%02d", left/60, mod(left,60))
        end
    end)
    self.click = EFrame.Image(self)
    self.click.margins = 1
    self.click.source = "Interface\\Buttons\\UI-Quickslot-Depress"
    self.click.layer = "ARTWORK"
    self.click.anchorFill = self
    self.click.visible = EFrame.bind(function() return self.action.pressed end)
    self.label = EFrame.Label(self)
    self.label.n_text:SetFontObject("NumberFontNormalSmallGray")
    self.label.n_text:SetNonSpaceWrap(true)
    self.label.marginRight = 2
    self.label.marginTop = 4
    self.label.sizeMode = EFrame.Label.VerticalFit
    self.label.height = EFrame.normalizeBind(10)
    self.label.anchorTop = self.top
    self.label.anchorRight = self.right
    self.label.anchorLeft = self.left
    self.label.hAlignment = "RIGHT"
    self.label.text = EFrame.bind(function() return self.action.hotkey end)
    self.label.visible = EFrame.bind(ActionMirroringFrameHandler, "showHotkeys")
    self.countLabel = EFrame.Label(self)
    self.countLabel.n_text:SetFontObject("NumberFontNormal")
    self.countLabel.margins = 3
    self.countLabel.sizeMode = EFrame.Label.VerticalFit
    self.countLabel.anchorBottom = self.bottom
    self.countLabel.anchorRight = self.right
    self.countLabel.anchorLeft = self.left
    self.countLabel.hAlignment = EFrame.bind(function() return self.label.marginTop + self.label.height > self.height - self.countLabel.height - self.countLabel.marginBottom and "LEFT" or "RIGHT" end)
    self.countLabel.text = EFrame.bind(function() return self.action.count end)
    if hasRanks then
        for i=1,5 do
            local ci = i
            local border = EFrame.Image(self)
            border.source = "Interface\\AddOns\\ActionMirroringFrame\\Rank2"
            border.color = EFrame.bind(function() local rank = self.action.rankMax return rankColors[(mod(rank, 5) < ci and 0 or 1) + math.floor(rank/5)] end)
            border.height = EFrame.normalizeBind(10)
            border.width = EFrame.normalizeBind(14)
            border:setCoords(0,1,0.25,0.75)
            border.marginBottom = EFrame.normalizeBind(5*(i -1) + 3)
            border.anchorBottom = self.bottomLeft
            border.z = 3
            border.visible = EFrame.bind(function() return self.action.rank > 0 and ActionMirroringFrameHandler.showRanks and (ActionMirroringFrameHandler.rankStyle == 1 or ActionMirroringFrameHandler.rankStyle == 3) end)
            
            local rank = EFrame.Image(border)
            rank.source = "Interface\\AddOns\\ActionMirroringFrame\\Rank"
            rank.color = EFrame.bind(function() local rank = self.action.rank return rankColors[(mod(rank, 5) < ci and 0 or 1) + math.floor(rank/5)] end)
            rank.height = EFrame.normalizeBind(8)
            rank.width = EFrame.normalizeBind(12)
            rank:setCoords(0,1,0.25,0.75)
            rank.marginBottom = EFrame.normalizeBind(5*(i -1) + 3)
            rank.anchorBottom = self.bottomLeft
            
        end
        self.rankLabel = EFrame.Label(self)
        self.rankLabel.anchorCenter = self.bottomLeft
        self.rankLabel.n_text:SetFontObject("NumberFontNormal")
        self.rankLabel.text = EFrame.bind(function() return self.action.rank end)
        self.rankLabel.z = 4
        self.rankLabel.sizeMode = EFrame.Label.VerticalFit
        self.rankLabel.height = EFrame.normalizeBind(10)
        self.rankLabel.visible = EFrame.bind(function() return self.action.rank > 0 and ActionMirroringFrameHandler.showRanks and (ActionMirroringFrameHandler.rankStyle == 1 or ActionMirroringFrameHandler.rankStyle == 2) end)
    end
    self.action:connect("positionChanged", self, "startPosition")
    EFrame.root:connect("update", self, "updateAnimations")
    self.visible = EFrame.bind(function(self) return self.action.status ~= "HIDE" end)
    if ActionMirroringFrameHandler.successAnim then
        self:initAnim()
    end
end

function ActionMirroringFrame:initAnim(a)
    if self.texAnim then self.texAnim:deleteLater() end
    local a = a or ActionMirroringFrameHandler.successAnim
    if a == 1 then
        self.texAnim = EFrame.Image(self)
        self.texAnim:setCoords(0.1,0.9,0.1,0.9)
        self.texAnim.margins = 2
        self.texAnim.anchorCenter = self.center
        self.texAnim.width = EFrame.bind(self, "width")
        self.texAnim.height = EFrame.bind(self, "height")
        self.texAnim.source = EFrame.bind(function() return self.action.texture end)
        self.texAnim.layer = "ARTWORK"
        self.texAnim.blendMode = "ADD"
        self.texAnim.duration = 0.250
    elseif a == 2 then
        self.texAnim = EFrame.Image(self)
        self.texAnim.margins = 2
        self.texAnim.anchorFill = self
        self.texAnim.source = "Interface\\AddOns\\ActionMirroringFrame\\ButtonHighlight"
        self.texAnim.color = {0,1,0,1}
        self.texAnim.layer = "ARTWORK"
        self.texAnim.duration = 0.5
    elseif a == 3 then
        self.texAnim = EFrame.Rectangle(self)
        self.texAnim.margins = 2
        self.texAnim.anchorFill = self
        self.texAnim.color = {.25,1,.25,0.5}
        self.texAnim.layer = "ARTWORK"
        self.texAnim.blendMode = "ADD"
        self.texAnim.duration = 0.5
    end
end

function ActionMirroringFrame:startPosition()
    self.animStart = GetTime()
end

function ActionMirroringFrame:updateAnimations()
    local s = self.__action.successTime
    if s then
        local t = (GetTime() - s) * 1/self.texAnim.duration
        if t >= 1 then
            t = 1
            self.__action.successTime = nil
        end
        local a = ActionMirroringFrameHandler.successAnim
        if a == 1 then
            self.texAnim.scale = 1 + math.sin(t*math.pi/2)*0.6
            self.texAnim.opacity = math.cos(t*math.pi/2)
        elseif a == 2 then
            self.texAnim.rotation = t * 20
            self.texAnim.opacity = math.cos(t*math.pi/2)
        elseif a == 3 then
            self.texAnim.color = {1 - math.cos(t*math.pi/2), 1, 1-math.cos(t*math.pi/2), 1-math.sin(t*math.pi/2)}
        end
        self.texAnim.visible = true
    else
        self.texAnim.visible = false
    end
    self:updatePosition()
end

function ActionMirroringFrame:updatePosition(instant)
    if not self.animStart or instant or not ActionMirroringFrameHandler.posAnims then self.position = self.__action.__position - 1 return end
    local t = (GetTime() - self.animStart) * 4
    if t >= 1 then
        t = 1
        self.animStart = nil
    end
    self.position = (self.__action.__position - 1) * t + self.__position * (1-t)
end

function ActionMirroringFrameHandler:onMaxFramesChanged(m)
    local mirrors = ActionMirroringFrameHandler.__mirrors
    if m > getn(mirrors) then
        for i = getn(mirrors) +1, m do
            tinsert(mirrors, ActionMirroringFrame(Action()))
        end
    elseif m < getn(mirrors) then
        for i = getn(mirrors), m +1, -1 do
            mirrors[i].action:destroy()
            mirrors[i]:destroy()
            tremove(mirrors, i)
        end
    end
end


-- ///////////////////////////////////////////////////




function ActionMirroringFrame_onUseAction(amf, id)
    amf.currentAction = id
    if amf.standby or CursorHasItem() or CursorHasSpell() or HasAction(id) == nil then
        return
    end
    ActionMirroringFrameHandler:actionUsed(id, ACTION_TYPE_NORMAL)
end

local function GetSpellID(sn)
    sn = strlower(sn)
    if not rank then
        name = sn
    end
    
    local i = 1
    local a,r = GetSpellName(1,BOOKTYPE_SPELL)
    local f
    while a do
        if strlower(format("%s(%s)", a, r or "")) == sn then
            return i
        elseif strlower(a) == sn then
            f = i
        elseif f then
            return f
        end
        i = i+1
        a,r = GetSpellName(i,BOOKTYPE_SPELL)
    end
    return f
end

function ActionMirroringFrame_onSpellUsed(idx, name)
    if SM_UpdateActionSpell and SM_UpdateAction then
        SM_UpdateActionSpell(GetActionText(idx), "regular", "/cast "..name)
        SM_UpdateAction()
    end
    if currentAction then
        currentAction.inventory = nil
        currentAction.container = nil
        currentAction.spell = GetSpellID(name)
    end
end

function ActionMirroringFrame_onInventoryUsed(idx, slot)
    if SM_UpdateActionSpell and SM_UpdateAction then
        SM_UpdateActionSpell(GetActionText(idx), "regular", format("/run UseInventoryItem(%d)", slot))
        SM_UpdateAction()
    end
    if currentAction then
        currentAction.spell = nil
        currentAction.container = nil
        currentAction.inventory = slot
    end
end

function ActionMirroringFrame_onContainerUsed(idx, bag, slot)
    if SM_UpdateActionSpell and SM_UpdateAction then
        SM_UpdateActionSpell(GetActionText(idx), "regular", format("/run UseContainerItem(%d,%d)", bag, slot))
        SM_UpdateAction()
    end
    if currentAction then
        currentAction.spell = nil
        currentAction.inventory = nil
        currentAction.container = {bag = bag, slot = slot, link = GetContainerItemLink(bag, slot)}
    end
end

function ActionMirroringFrame_onShapeshiftUsed(idx, bag, slot)
    if SM_UpdateActionSpell and SM_UpdateAction then
        SM_UpdateActionSpell(GetActionText(idx), "regular", format("/run UseContainerItem(%d,%d)", bag, slot))
        SM_UpdateAction()
    end
    if currentAction then
        currentAction.spell = nil
        currentAction.inventory = nil
        currentAction.container = {bag = bag, slot = slot, link = GetContainerItemLink(bag, slot)}
    end
end


local hooks = {}

local Hook = {}

local function DEBUG(s, ...)
    if ActionMirroringFrame.debug then
        if arg.n > 0 then
            s = format(s, unpack(arg))
        end
    end
end

function Hook:new(fname, pre, post)
    local o = {wrapped = getglobal(fname), fname = fname, shared = hooks[fname], pre = pre, post = post}
    setmetatable(o, {__index = Hook, __call = Hook.call})
    return o
end

function Hook:lock()
    if not self.shared.lock then
        self.shared.lock = self
    end
    return self.shared.lock == self
end

function Hook:unlock()
    if self.shared.lock == self then
        self.shared.lock = nil
    end
end

function Hook:call(...)
    if not self:lock() then
        self.shared.ok = true
        return self.wrapped(unpack(arg))
    end
    self.shared.ok = false
    if self.pre then
        self.pre(unpack(arg))
    end
    local r = self.wrapped(unpack(arg))
    if self.post then
        self.post(unpack(arg))
    end
    if getglobal(self.fname) == self and not self.tested then
        if self.shared.ok then
            DEBUG("%s was already hooked, dropping.", self.fname)
            self.shared.checked = self.wrapped
            setglobal(self.fname, self.wrapped)
        end
        self.tested = true
    end
    self:unlock()
    return r
end

function ActionMirroringFrame_Hook(fn, fs, fc)
    if not hooks[fn] then
        hooks[fn] = {}
    end
    local hook = hooks[fn]
    local mt = getmetatable(getglobal(fn))
    if getglobal(fn) == hook.checked or mt and mt.__index == Hook then
        return
    end
    setglobal(fn,Hook:new(fn, fs, fc))
    DEBUG("%s hook set.", fn)
end


local actionHookFuns = {
    function (id)
        currentAction = {id = id, old = currentAction}
    end,
    function (id)
        ActionMirroringFrame_onUseAction(ActionMirroringFrame,id)
        currentAction = currentAction.old
    end
}
function ActionMirroringFrame_ActionHook()
    ActionMirroringFrame_Hook("UseAction", unpack(actionHookFuns))
end

local function containerHookFun(bag, slot)
    if currentAction then
        ActionMirroringFrame_onContainerUsed(currentAction.id,bag, slot)
    end
end
function ActionMirroringFrame_ContainerHook()
    ActionMirroringFrame_Hook("UseContainerItem", containerHookFun)
end

local function shapeshiftHookFun(id)
    if currentAction then
        currentAction.shapeshift = id
    end
end
function ActionMirroringFrame_ShapeshiftHook()
    ActionMirroringFrame_Hook("CastShapeshiftForm", shapeshiftHookFun)
end

local function inventoryHookFun(slot)
    if currentAction then
        ActionMirroringFrame_onInventoryUsed(currentAction.id, slot)
    end
end
function ActionMirroringFrame_InventoryHook()
    ActionMirroringFrame_Hook("UseInventoryItem", inventoryHookFun)
end

local function spellHookFun(sn)
    if currentAction then
        ActionMirroringFrame_onSpellUsed(currentAction.id, sn)
    end
end
function ActionMirroringFrame_SpellHook()
    ActionMirroringFrame_Hook("CastSpellByName", spellHookFun)
end
            
function ActionMirroringFrame_new(parent)
    local o = CreateFrame("Frame", parent:GetName() .. parent.id, parent, "MirrorTemplate")
    o.id = parent.id
    parent.id = parent.id + 1
    return o
end

function ActionMirroringFrame_hold(self)
  local o = ActionMirroringFrame.root
  return self:isCurrent() and ActionMirroringSettings.stickyActive
end

function ActionMirroringFrame_overflow(self, nid)
  local sid = self:GetID()
  if self:IsShown() and sid ~= 0 and sid ~= nid and (ActionMirroringSettings.overflow > self.id or self:isCurrent() and ActionMirroringSettings.stickyActive) then
    if self.next == nil then
      self.next = ActionMirroringFrame_new(self:GetParent())
      self:updateOrientation()
    end
    self.next:overflow()
    self.next:SetID(self:GetID())
    self.next.spell = self.spell
    self.next.inventory = self.inventory
    self.next.timer = self.timer
    self.next.flashing = self.flashing
    self.next.flashtime = self.flashtime
    if self:isCurrent() then
        ActionMirroringFrame.current[self:GetID()] = self.next
    end
    self.next:Show()
    self.next:refresh()
  end
end


-- ///////////////////////////////////////////////////

local options

local function showOptions()
    if not options then
        options = EFrame.Window()
        options.title = "ActionMirroringFrame Options"
      --  options.width = EFrame.root.width / 3
       -- options.height = EFrame.root.height / 2
        options.centralItem = EFrame.ColumnLayout(options)
        options.toolBar = EFrame.RowLayout(options.centralItem)
        options.toolBar.Layout.fillWidth = true
        options.toolRow = EFrame.Rectangle(options.centralItem)
        options.toolRow.color = {0.4,0.4,0.4,0.6}
        options.toolRow.Layout.fillWidth = true
        options.toolRow.implicitHeight = 1
        options.unlockButton = options.style.Button(options.toolBar)
        options.unlockButton.text = EFrame.bind(function() return anchor.visible and "Lock" or "Unlock" end)
        options.unlockButton:connect("clicked", function() anchor.visible = not anchor.visible end)
        options.main = EFrame.ColumnLayout(options.centralItem)
        options.toolBar.Layout.fillWidth = true
        options.main.spacing = 4
        
        
        options.timeoutRow = EFrame.RowLayout(options.main)
        options.timeoutRow.spacing = 2
        options.timeoutLabel = EFrame.Label(options.timeoutRow)
        options.timeoutLabel.text = "Show actions duration (seconds):"
        options.timeoutSpinBox = options.style.SpinBox(options.timeoutRow)
        options.timeoutSpinBox.from = 0
        options.timeoutSpinBox.step = 0.1
        options.timeoutSpinBox.value = ActionMirroringFrameHandler.timeout
        function options.timeoutSpinBox:onValueModified(v) ActionMirroringFrameHandler.timeout = v end
        
        EFrame.Item(options.main).implicitHeight = 4
        
        options.maxFramesRow = EFrame.RowLayout(options.main)
        options.maxFramesRow.spacing = 2
        options.maxFramesLabel = EFrame.Label(options.maxFramesRow)
        options.maxFramesLabel.text = "Maximum number of actions shown:"
        options.maxFramesSpin = options.style.SpinBox(options.maxFramesRow)
        options.maxFramesSpin.from = 1
        options.maxFramesSpin.value = EFrame.bind(ActionMirroringFrameHandler, "maxFrames")
        function options.maxFramesSpin:onValueModified(v)
            ActionMirroringFrameHandler.maxFrames = v
        end
        
        options.cdRow = EFrame.RowLayout(options.main)
        options.cdRow.spacing = 2
        options.cdLabel = EFrame.Label(options.cdRow)
        options.cdLabel.text = "Keep visible cooldowns below (seconds):"
        options.cdSpinBox = options.style.SpinBox(options.cdRow)
        options.cdSpinBox.from = 0
        options.cdSpinBox.step = 0.1
        options.cdSpinBox.value = ActionMirroringFrameHandler.stickyCD
        function options.cdSpinBox:onValueModified(v) ActionMirroringFrameHandler.stickyCD = v end
        
        options.cdTipRow = EFrame.RowLayout(options.main)
        options.cdTipRow.spacing = 2
        options.cdTipCheck = options.style.CheckButton(options.cdTipRow)
        options.cdTipCheck.text = "Show Cooldown Text for spells above (seconds):"
        options.cdTipCheck.checked = ActionMirroringFrameHandler.showCooldownTip
        function options.cdTipCheck:onCheckedChanged(v) ActionMirroringFrameHandler.showCooldownTip = v end
        options.cdTipSpinBox = options.style.SpinBox(options.cdTipRow)
        options.cdTipSpinBox.enabled = EFrame.bind(ActionMirroringFrameHandler.showCooldownTip, "enabled")
        options.cdTipSpinBox.from = 0
        options.cdTipSpinBox.step = 0.5
        options.cdTipSpinBox.value = ActionMirroringFrameHandler.cooldownTipThreshold
        function options.cdTipSpinBox:onValueModified(v) ActionMirroringFrameHandler.cooldownTipThreshold = v end
        
        EFrame.Item(options.main).implicitHeight = 4
        
        options.noDoublesCheck = options.style.CheckButton(options.main)
        options.noDoublesCheck.checked = ActionMirroringFrameHandler.noDoubles
        options.noDoublesCheck.text = "No duplicates"
        function options.noDoublesCheck:onCheckedChanged(c)
            ActionMirroringFrameHandler.noDoubles = c
        end
        
        options.verticalRow = EFrame.RowLayout(options.main)
        options.verticalRow.spacing = 2
        options.verticalLabel = EFrame.Label(options.verticalRow)
        options.verticalLabel.text = "Growth:"
        options.growthCombo = options.style.ComboBox(options.verticalRow)
        options.growthCombo.model = {"Right", "Bottom", "Left", "Top"}
        options.growthCombo.currentIndex = (ActionMirroringFrameHandler.vertical and 3 or 2) - ActionMirroringFrameHandler.direction
        options.growthCombo:connect("activated", function(a) ActionMirroringFrameHandler.vertical = mod(a, 2) == 0 ActionMirroringFrameHandler.direction = (mod(a, 2) == 0 and 3 or 2) - a end)
        
        EFrame.Item(options.main).implicitHeight = 4
        
        
        options.showMissingPower = options.style.CheckButton(options.main)
        options.showMissingPower.checked = ActionMirroringFrameHandler.showMissingPower
        options.showMissingPower.text = "Show missing power"
        function options.showMissingPower:onCheckedChanged(c)
            ActionMirroringFrameHandler.showMissingPower = c
        end
        options.powerAnchorRow = EFrame.RowLayout(options.main)
        options.powerAnchorRow.spacing = 2
        options.powerAnchorLabel = EFrame.Label(options.powerAnchorRow)
        options.powerAnchorLabel.enabled = EFrame.Bind(ActionMirroringFrameHandler, "showMissingPower")
        options.powerAnchorLabel.text = "Missing Power frame position:"
        options.powerAnchorCombo = options.style.ComboBox(options.powerAnchorRow)
        options.powerAnchorCombo.model = {"Inner", "Top", "Bottom"}
        options.powerAnchorCombo.currentIndex = EFrame.bind(function() return ActionMirroringFrameHandler.vertical and 1 or ActionMirroringFrameHandler.powerAnchor + 2 end)
        options.powerAnchorCombo:connect("activated", function(a) ActionMirroringFrameHandler.powerAnchor = a - 2 end)
        options.powerAnchorCombo.enabled = EFrame.bind(function() return ActionMirroringFrameHandler.showMissingPower and not ActionMirroringFrameHandler.vertical end)
        
        EFrame.Item(options.main).implicitHeight = 4
        
        options.hotkeysCheck = options.style.CheckButton(options.main)
        options.hotkeysCheck.checked = ActionMirroringFrameHandler.showHotkeys
        options.hotkeysCheck.text = "Show Action Hotkeys"
        function options.hotkeysCheck:onCheckedChanged(c)
            ActionMirroringFrameHandler.showHotkeys = c
        end
            
        EFrame.Item(options.main).implicitHeight = 4
        
        if hasRanks then
            options.rankCheck = options.style.CheckButton(options.main)
            options.rankCheck.checked = ActionMirroringFrameHandler.showRanks
            options.rankCheck.text = "Show spell ranks"
            function options.rankCheck:onCheckedChanged(c)
                ActionMirroringFrameHandler.showRanks = c
            end
            options.rankStyle = options.style.ComboBox(options.main)
            options.rankStyle.model = { "Icon and Number", "Number only", "Icon only" }
            options.rankStyle.currentIndex = ActionMirroringFrameHandler.rankStyle
            options.rankStyle:connect("activated", function(a) ActionMirroringFrameHandler.rankStyle = a end)
            options.rankStyle.enabled = EFrame.bind(ActionMirroringFrameHandler, "showRanks")
        
            EFrame.Item(options.main).implicitHeight = 4
        end
        
        options.animsTitle = EFrame.Label(options.main)
        options.animsTitle.text = "Animation Options"
        
        options.posAnims = options.style.CheckButton(options.main)
        options.posAnims.text = "Animate mirrors' positions changes"
        options.posAnims.checked = ActionMirroringFrameHandler.posAnims
        function options.posAnims:onCheckedChanged(c) ActionMirroringFrameHandler.posAnims = c end
        
        options.successAnimRow = EFrame.RowLayout(options.main)
        options.successAnimRow.spacing = 2
        options.successAnimLabel = EFrame.Label(options.successAnimRow)
        options.successAnimLabel.text = "Success Animation:"
        options.successAnimCombo = options.style.ComboBox(options.successAnimRow)
        options.successAnimCombo.model = {"Zoom", "Green Spin", "Green Flash"}
        options.successAnimCombo.currentIndex = EFrame.bind(ActionMirroringFrameHandler, "successAnim")
        options.successAnimCombo:connect("activated", function(a) ActionMirroringFrameHandler.successAnim = a end)
        
        
        local function ShowColorPicker(r, g, b, a, changedCallback)
            ColorPickerFrame:Hide()
            ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = nil, nil, nil
            ColorPickerFrame:SetColorRGB(r,g,b)
            ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = (a ~= nil), 1 - a or 0
            ColorPickerFrame.previousValues = {r,g,b,a}
            ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = changedCallback, changedCallback, changedCallback
            ColorPickerFrame:Show()
        end
        function colorPick(p, text, colors)
            local row = EFrame.RowLayout(p)
            row.Layout.fillWidth = true
            row.spacing = 2
            row.square = EFrame.Rectangle(row)
            row.square.Layout.fillHeight = true
            row.square.Layout.preferredWidth = EFrame.bind(row.square, "height")
            row.square.color = borderColors[colors[1]]
            row.label = EFrame.Label(row)
            row.label.text = text
            row.mouse = EFrame.MouseArea(row.square)
            row.mouse.anchorFill = row.square
            row.mouse:connect("clicked", function ()
                local color = borderColors[colors[1]]
                ShowColorPicker(color[1], color[2], color[3], color[4], function (restore)
                    if restore then
                        for _, v in ipairs(colors) do
                            borderColors[v] = restore
                        end
                    else
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        for _, v in ipairs(colors) do
                            borderColors[v] = {r, g, b, 1 - OpacitySliderFrame:GetValue()}
                        end
                    end
                    row.square.color = borderColors[colors[1]]
                end)
            end)
            row.reset = options.style.Button(row)
            row.reset.text = "X"
            row.reset:connect("clicked", function ()
                local color = defaultColors[colors[1]]
                for _, v in ipairs(colors) do
                    borderColors[v] = color
                end
                row.square.color = color
            end)
            row.reset.Layout.alignment = EFrame.Layout.AlignRight
            return row
        end
        
        options.borderColors = EFrame.ColumnLayout(options.main)
        options.borderColors.Layout.alignment = EFrame.Layout.AlignTop
        options.borderColors.spacing = 2
        options.borderColors.caption = EFrame.Label(options.borderColors)
        options.borderColors.caption.text = "Border Colors"
        for _,v in ipairs(
            {{"Casting", {"CURRENT"}},
            {"No Power", {"NOMANA"}},
            {"Not in range", {"NOTINRANGE"}},
            {"Not usable", {"NOTUSABLE"}},
            {"Equipped", {"EQUIPPED"}}}) do
            colorPick(options.borderColors, v[1], v[2])
        end
    end
end

local function chatcmd(msg)
    if not msg or msg == "" then
        if not options then
            showOptions()
            return
        end
        options.visible = not options.visible
        return
    elseif msg == "unlock" then
        anchor.visible = true
    elseif msg == "lock" then
        anchor.visible = false
    else
        print("ActionMirroringFrame slash commands (/amf):")
        print("    unlock - allows to move and resize the frame")
        print("    lock - locks the frame in place")
    end
end

setglobal("SLASH_ACTIONMIRRORINGFRAME1", "/actionmirroringframe")
setglobal("SLASH_ACTIONMIRRORINGFRAME2", "/amf")
getglobal("SlashCmdList")["ACTIONMIRRORINGFRAME"] = chatcmd
