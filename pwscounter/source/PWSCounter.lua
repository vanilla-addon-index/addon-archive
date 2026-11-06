PWSCounterSettingsDefaults = {
    auto = true
}
local function prepare(template) --courtesy of shagu
    template = gsub(template, "%(", "%%(") -- fix ( in string
    template = gsub(template, "%)", "%%)") -- fix ) in string
    template = gsub(template, "%d%$","")
    template = gsub(template, "%%s", "(.+)")
    return gsub(template, "%%d", "(%%d+)")
end

local CombatEventsMatches = {
    COMBAT_HITS = {
        regexes = {
            prepare(COMBATHITOTHEROTHER),
            prepare(COMBATHITSCHOOLOTHEROTHER),
            prepare(COMBATHITCRITOTHEROTHER),
            prepare(COMBATHITCRITSCHOOLOTHEROTHER)
        },
        captures = {2,1}
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
        captures = {2,1}
    },
    COMBAT_HITS_SELF = {
        regexes = {
            prepare(COMBATHITSELFOTHER),
            prepare(COMBATHITSCHOOLSELFOTHER),
            prepare(COMBATHITCRITSELFOTHER),
            prepare(COMBATHITCRITSCHOOLSELFOTHER)
        },
        captures = {1}
    },
    COMBAT_MISSES_SELF = {
        regexes = {
            prepare(MISSEDSELFOTHER),
            prepare(IMMUNESELFOTHER),
            prepare(VSDODGESELFOTHER),
            prepare(VSBLOCKSELFOTHER),
            prepare(VSPARRYSELFOTHER),
            prepare(VSRESISTSELFOTHER)
        },
        captures = {1}
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
        captures = {3,1}
    },
    SPELL_DAMAGE_SELF = {
        regexes = {
            prepare(SPELLLOGSELFOTHER),
            prepare(SPELLBLOCKEDSELFOTHER),
            prepare(SPELLDEFLECTEDSELFOTHER),
            prepare(SPELLDODGEDSELFOTHER),
            prepare(SPELLIMMUNESELFOTHER),
            prepare(SPELLLOGABSORBSELFOTHER),
            prepare(SPELLLOGCRITSELFOTHER),
            prepare(SPELLLOGCRITSCHOOLSELFOTHER),
            prepare(SPELLLOGSCHOOLSELFOTHER),
            prepare(SPELLMISSSELFOTHER),
            prepare(SPELLPARRIEDSELFOTHER),
            prepare(SPELLRESISTSELFOTHER)
        },
        captures = {1}
    }
}

local ShieldCombatEvents = {
    CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS = { diff = 1 },
    CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS = { diff = 1 },
    CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE = { diff = 1 },
    CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE = { diff = 1 },
    CHAT_MSG_SPELL_AURA_GONE_OTHER = { diff = -1 },
    CHAT_MSG_SPELL_AURA_GONE_SELF = { diff = -1 }
}
local TriggerCombatEvents = {
    CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS = {matches = CombatEventsMatches.COMBAT_HITS, hostile = 1},
    CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES = {matches = CombatEventsMatches.COMBAT_MISSES, hostile = 1},
    CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE = {matches = CombatEventsMatches.SPELL_DAMAGE, hostile = 1},
    CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS = {matches = CombatEventsMatches.COMBAT_HITS},
    CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES = {matches = CombatEventsMatches.COMBAT_MISSES},
    CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE = {matches = CombatEventsMatches.SPELL_DAMAGE},
    CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS = {matches = CombatEventsMatches.COMBAT_HITS, hostile = 1},
    CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES = {matches = CombatEventsMatches.COMBAT_MISSES, hostile = 1},
    CHAT_MSG_COMBAT_SELF_HITS = {matches = CombatEventsMatches.COMBAT_HITS_SELF},
    CHAT_MSG_COMBAT_SELF_MISSES = {matches = CombatEventsMatches.COMBAT_MISSES_SELF},
    CHAT_MSG_SPELL_SELF_DAMAGE = {matches = CombatEventsMatches.SPELL_DAMAGE_SELF}
}

local EventHandler = CreateFrame("FRAME")

function EventHandler:registerEvents(t)
    for k in t do
        self:RegisterEvent(k)
    end
end

function EventHandler:unregisterEvents(t)
    for k in t do
        self:UnregisterEvent(k)
    end
end

PWSCounter = EFrame.Object()
PWSCounter:attach("activeShields", nil, "setActiveShields")
PWSCounter:attach("totalShields")
PWSCounter:attach("auto")
PWSCounter:attach("running")
PWSCounter:attach("currentEngage")
PWSCounter:attach("currentTarget")
PWSCounter:attach("scanning")
PWSCounter:attach("inRaid")
PWSCounter:attach("autoStopOnCombat")
PWSCounter:attach("autoStartOnCombat")

PWSCounter.scanning = EFrame.bind(function() return PWSCounter.inRaid and PWSCounter.auto and not PWSCounter.currentEngage end)
PWSCounter.autoStartOnCombat = EFrame.bind(function() return not PWSCounter.running and PWSCounter.scanning end)
PWSCounter.autoStopOnCombat = EFrame.bind(function() return PWSCounter.running and PWSCounter.auto end)
PWSCounter.autoStopOnDeath = EFrame.bind(function() return PWSCounter.auto and PWSCounter.currentEngage end)

function PWSCounter:onScanningChanged(scanning)
    if scanning then
        EventHandler:registerEvents(TriggerCombatEvents)
    else
        EventHandler:unregisterEvents(TriggerCombatEvents)
    end
end

function PWSCounter:onCurrentEngageChanged(t)
    if t then
        EventHandler:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
    else
        EventHandler:UnregisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
    end
end

function PWSCounter:onAutoStartOnCombatChanged(t)
    if t then
        EventHandler:RegisterEvent("PLAYER_REGEN_DISABLED")
    else
        EventHandler:UnregisterEvent("PLAYER_REGEN_DISABLED")
    end
end

function PWSCounter:onAutoStopOnCombatChanged(t)
    if t then
        EventHandler:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        EventHandler:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end

function PWSCounter:setActiveShields(v)
    if v < 0 or self._activeShields.value == v then return end
    self._activeShields.value = v
    self.activeShieldsChanged(v)
end

PWSCounter.activeShields = 0
PWSCounter.totalShields = 0

local PWSCounterWindow

function PWSCounter:onRunningChanged(running)
    if running then
        self.activeShields = 0
        self.totalShields = 0
        EventHandler:registerEvents(ShieldCombatEvents)
        PWSCounter:scanShields()
        PWSCounter_ShowCount()
    else
        EventHandler:unregisterEvents(ShieldCombatEvents)
        PWSCounter.currentEngage = nil
    end
end

function PWSCounter:onAutoChanged(auto)
    if PWSCounterSettings then
        PWSCounterSettings.auto = auto
    end
end

function EventHandler:PARTY_MEMBERS_CHANGED()
    PWSCounter.inRaid = GetNumRaidMembers() > 0
end

function EventHandler:PLAYER_TARGET_CHANGED()
    PWSCounter.currentTarget = UnitName("target")
end

function EventHandler:PLAYER_REGEN_DISABLED()
    PWSCounter.running = true
end

function EventHandler:PLAYER_REGEN_ENABLED()
    PWSCounter.running = false
end

local deathRex = prepare(UNITDIESOTHER)

function EventHandler:CHAT_MSG_COMBAT_HOSTILE_DEATH()
    local _,_,name = strfind(arg1, deathRex)
    if name and name == PWSCounter.currentEngage then
        PWSCounter.running = false
    end
end

function EventHandler:ADDON_LOADED()
    if arg1 == "PWSCounter" then
        if not PWSCounterSettings then
            PWSCounterSettings = {npcs = {}}
        end
        setmetatable(PWSCounterSettings, { __index = PWSCounterSettingsDefaults })
        PWSCounter.auto = PWSCounterSettings.auto
        EventHandler:UnregisterEvent("ADDON_LOADED")
    end
end

local CombatLogCVars = {
    CombatLogRangeParty = true,
    CombatLogRangePartyPet = true,
    CombatLogRangeFriendlyPlayers = true,
    CombatLogRangeFriendlyPlayersPets = true,
    CombatLogRangeCreature = true
}
function EventHandler:VARIABLES_LOADED()
    for k in CombatLogCVars do
        if tonumber(GetCVar(k)) < 120 then
            SetCVar(k, "200")
        end
    end
end

function EventHandler:process()
    local handle = EventHandler[event]
    if handle then
        handle(EventHandler)
        return
    end
    local se = ShieldCombatEvents[event]
    if se then
        local diff = se.diff
        if diff then
            if strfind(arg1, "Power Word: Shield", 1) then
                PWSCounter.activeShields = PWSCounter.activeShields + diff
            elseif strfind(arg1, "Weakened Soul", 1) and diff > 0 then
                PWSCounter.totalShields = PWSCounter.totalShields + diff
            end
        end
    end
    local ce = TriggerCombatEvents[event]
    if ce then
        for _,m in ce.matches.regexes do
            local en
            local r = {}
            r = {strfind(arg1,m)}
            if getn(r) >= 4 then
                local ten
                if ce.hostile then
                    ten = r[2+ce.matches.captures[2]]
                else
                    ten = r[2+ce.matches.captures[1]]
                end
                if ten and PWSCounterSettings.npcs[strlower(ten)] then
                    PWSCounter.currentEngage = ten
                    PWSCounter.running = true
                    break
                end
            end
        end
    end
end

local units = {"raid", "raidpet"}
CreateFrame("GameTooltip", "PWSCounterBuffScanner",UIParent,"GameTooltipTemplate")
function PWSCounter:scanShields()
    for i = 1, GetNumRaidMembers() do
        for _,v in units do
            local unit = v .. i
            for bi = 1, 16 do
                local tex = UnitBuff(unit, bi)
                if not tex then
                    break
                elseif tex == "Interface\\Icons\\Spell_Holy_PowerWordShield" then
                    PWSCounterBuffScanner:SetOwner(UIParent, "ANCHOR_NONE");
                    PWSCounterBuffScanner:SetUnitBuff(unit,bi)
                    local sn = PWSCounterBuffScannerTextLeft1:GetText()
                    PWSCounterBuffScanner:Hide()
                    if sn == "Power Word: Shield" then
                        self.activeShields = self.activeShields +1
                        self.totalShields = self.totalShields +1
                        break
                    end
                end
            end
        end
    end
end


local function UIInit()
    PWSCounterWindow = EFrame.Window()
    PWSCounterWindow.visible = false
    PWSCounterWindow.title = "PWSCounter"
    PWSCounterWindow.centralItem = EFrame.ColumnLayout(PWSCounterWindow)
    PWSCounterWindow.centralItem.spacing = 2
    local targetButton = EFrame.Button(PWSCounterWindow.centralItem)
    targetButton.text = EFrame.bind(function() return PWSCounter.currentTarget and PWSCounterSettings.npcs[strlower(PWSCounter.currentTarget)] and "Unregister Target" or "Register Target" end)
    targetButton.enabled = EFrame.bind(function() return PWSCounter.currentTarget and PWSCounter.currentTarget ~= "" end)
    function targetButton:onClicked()
        if PWSCounterSettings.npcs[strlower(PWSCounter.currentTarget)] then
            PWSCounterSettings.npcs[strlower(PWSCounter.currentTarget)] = nil
        else
            PWSCounterSettings.npcs[strlower(PWSCounter.currentTarget)] = true
        end
        PWSCounter.currentTargetChanged()
    end
    local targetLabel = EFrame.Label(PWSCounterWindow.centralItem)
    targetLabel.text = EFrame.bind(function() return format("Current encounter: %s", PWSCounter.currentEngage or PWSCounter.scanning and "scanning..." or "<off>") end)
    local activeLabel = EFrame.Label(PWSCounterWindow.centralItem)
    activeLabel.text = EFrame.bind(function() return format("Active shields: %d", PWSCounter.activeShields) end)
    local totalLabel = EFrame.Label(PWSCounterWindow.centralItem)
    totalLabel.text = EFrame.bind(function() return format("Total shields casted: %d", PWSCounter.totalShields) end)
    local buttonRow = EFrame.RowLayout(PWSCounterWindow.centralItem)
    buttonRow.spacing = 2
    local toggleButton = EFrame.Button(buttonRow)
    toggleButton.text = EFrame.bind(function() return PWSCounter.running and 'Stop' or 'Start' end)
    toggleButton.onClicked = function() PWSCounter.running = not PWSCounter.running end
    local autoButton = EFrame.CheckButton(buttonRow)
    autoButton.text = "Auto Start/Stop"
    autoButton.checked = PWSCounter._auto
    autoButton.onCheckedChanged = function (self, checked) PWSCounter.auto = checked end
    
    PWSCounterWindow.dragActiveChanged:connect(function (dragged)
        if not dragged then
            PWSCounterSettings.windowX = PWSCounterWindow.x
            PWSCounterSettings.windowY = PWSCounterWindow.y
        end
    end)
    function PWSCounterWindow:onVisibleChanged(visible)
        if visible then
            if PWSCounterSettings.windowX and PWSCounterSettings.windowY then
                self.x = PWSCounterSettings.windowX
                self.y = PWSCounterSettings.windowY
            else
                self.x = self.parent.width/2 - self.width/2
                self.y = self.parent.height/2 - self.height/2
            end
        end
    end
end

function PWSCounter_ShowCount()
    if not PWSCounterWindow then
        UIInit()
    end
    PWSCounterWindow.visible = true
end

local function chatcmd()
    if not PWSCounterWindow then
        UIInit()
    end
    PWSCounterWindow.visible = not PWSCounterWindow.visible
end

SLASH_PWSCOUNTER1 = "/pwscounter"
SLASH_PWSCOUNTER2 = "/pwsc"
SlashCmdList["PWSCOUNTER"] = chatcmd

EventHandler:SetScript("OnEvent", function() EventHandler:process() end)
EventHandler:RegisterEvent("ADDON_LOADED")
EventHandler:RegisterEvent("VARIABLES_LOADED")
EventHandler:RegisterEvent("PLAYER_TARGET_CHANGED")
EventHandler:RegisterEvent("PARTY_MEMBERS_CHANGED")
PWSCounter.inRaid = GetNumRaidMembers() > 0


