local HC
if HonorCounter == nil then 
    HonorCounter = {}
end
HC = HonorCounter

local _G = getfenv(0)

local function difftime(a,b)
    if type(b) == "table" then
        b = time(b)
    end
    if type(a) == "table" then
        a = time(a)
    end
    return a - b
end

setmetatable(HC, {__index = getfenv() })
setfenv(1, HC)

local function prepare(template) --courtesy of shagu
    template = gsub(template, "%(", "%%(") -- fix ( in string
    template = gsub(template, "%)", "%%)") -- fix ) in string
    template = gsub(template, "%d%$","")
    template = gsub(template, "%%s", "(.+)")
    return gsub(template, "%%d", "(%%d+)")
end

local hkRex = prepare(COMBATLOG_HONORGAIN)
local haRex = prepare(COMBATLOG_HONORAWARD)

local COMBATLOG_HONORGAIN_HONORCOUTNER = " Estimated diminish: %d%% => %d Honor"

local decay = 0.1
local pdecay = decay * 100
local ndecay = math.ceil(1/decay-0.001)

HonorCounterSettingsDefaults = {
    ta = 1
}

EventHandler = CreateFrame("FRAME")

HonorCounter = EFrame.Object()

HonorCounter:attach("today")
HonorCounter:attach("session")
HonorCounter:attach("sessionHonor")
HonorCounter:attach("sessionAwards")
HonorCounter:attach("sessionWorld")
HonorCounter:attach("honorableKills")
HonorCounter:attach("honorMean")
HonorCounter:attach("decayMean")
HonorCounter:attach("killsMean")
HonorCounter:attach("targetKills")
HonorCounter:attach("ta")
HonorCounter:attach("sessionTime")
HonorCounter.__honorMean = 0
HonorCounter.__decayMean = 0
HonorCounter.__killsMean = 0
HonorCounter.__ta = 1
HonorCounter.__today = 0
HonorCounter.__session = 0
HonorCounter.__sessionTime = 0
HonorCounter.__sessionHonor = 0
HonorCounter.__sessionAwards = 0
HonorCounter.__sessionWorld = 0
lastUpdateTime = GetTime()

function HonorCounter:onTodayChanged(t)
    _G.HonorCounterProfile.today = t
end

local HonorCounterWindow

local hks
local lastMessage = ""
local lastKillTime = GetTime()
local pending = {}
local sessionStartTime = GetTime()
local countIsDirty

function resetIfNeeded()
    local hk, hp = GetPVPSessionStats()
    if HonorCounter.honorableKills > hk and not countIsDirty then
        HonorCounter.honorableKills = hk
        hks = {}
        _G.HonorCounterProfile.hks = hks
        HonorCounter.today = 0
        if hk ~= 0 then
            HonorCounter:recover(hk)
        else
            _G.HonorCounterDump = {kills={}, awards={}}
            hcdump = _G.HonorCounterDump
        end
        return true
    end
    return false
end

function HonorCounter:recover(hk)
    self.honorableKills = 0
    local stale = 0
    local fk = math.max(1, getn(hcdump.kills) - hk +1)
    for k, v in ipairs(hcdump.kills) do
        if getn(hcdump.kills) - k < hk then
            if difftime(time(), v.date) > 24 * 3600 then
                stale = stale + 1
            end
            self:process(v.name, v.honor)
        end
    end
    local k = 1
    if fk > 1 then
        local t = hcdump.kills[fk].date
        while hcdump.awards[k] and difftime(hcdump.awards[k].date, t) < 0 do
            k = k+1
        end
    else
        k = 1
    end
    for i = k, getn(hcdump.awards) do
        HonorCounter.today = HonorCounter.today + hcdump.awards[i].honor
    end
    if stale > 0 then
        print(format("|c00ff0000HonorCounter: WARNING: %d honorable kills are older than 24h|r", stale))
    end
    if hk ~= self.honorableKills then
        print(format("|c00ff0000HonorCounter: Missing data: %d requested, %d loaded|r", hk, self.honorableKills))
        self.honorableKills = hk
    end
end

function HonorCounter:process(name, honor)
    if not hks[name] then
        hks[name] = {kills = 0, honor = 0}
    end
    local gain, kdecay
    if hks[name].kills < ndecay then
        gain = honor -- math.ceil(honor * ( 1 - hks[name].kills * decay ))
        hks[name].honor = hks[name].honor + gain
        HonorCounter.today = HonorCounter.today + gain
        kdecay = (hks[name].kills * pdecay)
    else
        gain, kdecay = 0, 100
    end
    HonorCounter.honorableKills = HonorCounter.honorableKills + 1
    hks[name].kills = hks[name].kills +1
    return gain, kdecay
end

a = 0.005
ta = 1
function decayc(t)
    return a^(t/ta)
end

function EventHandler:CHAT_MSG_COMBAT_HONOR_GAIN(msg)
    msg = msg or arg1
    if not hks then
        return tinsert(pending, msg)
    end
    local _, _, name, rank, honor = strfind(msg, hkRex)
    if name and honor then
        honor = tonumber(honor)
        if not hks[name] then
            hks[name] = {kills = 0, honor = 0}
        end
        local gain, kdecay = HonorCounter:process(name, honor)
        local world = IsInInstance() ~= 1
        if world then
            HonorCounter.sessionWorld = HonorCounter.sessionWorld + gain
        else
            HonorCounter.sessionHonor = HonorCounter.sessionHonor + gain
        end
        lastMessage = format(COMBATLOG_HONORGAIN_HONORCOUTNER, kdecay, gain)
        local ki = (GetTime() - lastKillTime)/3600
        local ui = (GetTime() - lastUpdateTime)/3600
        if ki == 0 then
            HonorCounter.honorMean = HonorCounter.honorMean + gain * math.log(a)
            HonorCounter.decayMean = HonorCounter.decayMean + kdecay * math.log(a)
            HonorCounter.killsMean = HonorCounter.killsMean + math.log(a)
        else
            local du = decayc(ui)
            local dk = decayc(ki)
            HonorCounter.honorMean = HonorCounter.honorMean * du + gain * (1-du) * ta / ui
            HonorCounter.decayMean = HonorCounter.decayMean * dk + kdecay * (1-dk) * ta / ki
            HonorCounter.killsMean = HonorCounter.killsMean * dk + (1-dk) * ta / ki
        end
        lastKillTime = GetTime()
        lastUpdateTime = GetTime()
        tinsert(hcdump.kills, {name=name, honor=honor, date=time(), world=world})
        countIsDirty = true
    else
        local _, _, honor = strfind(msg, haRex)
        if honor then
            resetIfNeeded()
            honor = tonumber(honor)
            HonorCounter.today = HonorCounter.today + honor
            HonorCounter.sessionAwards = HonorCounter.sessionAwards + honor
            local ki = (GetTime() - lastKillTime)/3600
            local ui = (GetTime() - lastUpdateTime)/3600
            if ki == 0 then
                HonorCounter.honorMean = HonorCounter.honorMean + honor * math.log(a)
            else
                local du = decayc(ui)
                local dk = decayc(ki)
                HonorCounter.honorMean = HonorCounter.honorMean * du + honor * (1-du) * ta / ui
            end
            tinsert(hcdump.awards, {honor=honor, date=time()})
            lastMessage = ""
        end
    end
    HonorCounter_ShowCount()
end

function chat_filter(_, _, msg)
    return false, msg .. lastMessage
end

EventHandler:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")

function EventHandler:ADDON_LOADED()
    if strlower(arg1) == "honorcounter" then
        if not HonorCounterSettings then
            _G.HonorCounterSettings = {}
        end
        setmetatable(_G.HonorCounterSettings, { __index = HonorCounterSettingsDefaults })
        
        if not _G.HonorCounterProfile then
            _G.HonorCounterProfile = {today = 0, hks = {}, hk = 0}
        end
        hks = _G.HonorCounterProfile.hks
        setmetatable(_G.HonorCounterProfile, { __index = HonorCounterProfileDefaults })
        if not HonorCounterDump or getn(HonorCounterDump) > 0 and difftime(time(), getn(HonorCounterDump[getn(HonorCounterDump)]).date) > 36*3600 then
            _G.HonorCounterDump = {kills={}, awards={}}
        end
        hcdump = _G.HonorCounterDump
        if getn(hcdump) > 0 then
            hcdump.kills = {}
            hcdump.awards = {}
            for k,v in ipairs(hcdump) do
                if v.name then
                    tinsert(hcdump.kills, v)
                else
                    tinsert(hcdump.awards, v)
                end
                hcdump[k] = nil
            end
        end
        EventHandler:UnregisterEvent("ADDON_LOADED")
        HonorCounter.today = _G.HonorCounterProfile.today
        HonorCounter.session = EFrame.bind(function() return HonorCounter.sessionHonor + HonorCounter.sessionAwards + HonorCounter.sessionWorld end)
        HonorCounter.honorableKills = _G.HonorCounterProfile.hk
        HonorCounter:connect("honorableKillsChanged", function(h) _G.HonorCounterProfile.hk = h end)
        for _, msg in ipairs(pending) do
            EventHandler:CHAT_MSG_COMBAT_HONOR_GAIN(msg)
        end
        pending = {}

        HonorCounter.ta = HonorCounterSettings.ta
        HonorCounter:connect("taChanged", function(v) ta = v HonorCounterSettings.ta = v end)
        
    end
end

function EventHandler:PLAYER_TARGET_CHANGED()
    if UnitIsPlayer("target") == 1 and UnitFactionGroup("player") ~= UnitFactionGroup("target") then
        local p = hks[UnitName("target")]
        HonorCounter.targetKills = p and p.kills or 0
    else
        HonorCounter.targetKills = nil
    end
end

function EventHandler:PLAYER_PVP_KILLS_CHANGED()
    countIsDirty = nil
    resetIfNeeded()
end

EventHandler:RegisterEvent("PLAYER_TARGET_CHANGED")
EventHandler:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")

function EventHandler:process(event)
    local handle = EventHandler[event]
    if handle then
        handle(EventHandler)
        return
    end
end

EFrame.root:connect("update", function ()
    local ui = (GetTime() - lastUpdateTime)
    if ui < 1 then return end
    ui = ui/3600
    HonorCounter.honorMean = HonorCounter.honorMean * decayc(ui)
    lastUpdateTime = GetTime()
    HonorCounter.sessionTime = GetTime() - sessionStartTime
    if graph then
        local max = 0
        local k = math.max(1, getn(hcdump.kills) - HonorCounter.honorableKills +1)
        local k2 = 1
        local fk = math.max(1, getn(hcdump.kills) - HonorCounter.honorableKills +1)
        local decays = {}
        local d = date("*t", time())
        if fk > 1 then
            local t = hcdump.kills[fk].date
            while hcdump.awards[k2] and difftime(hcdump.awards[k2].date, t) < 0 do
                k2 = k2+1
            end
        else
            k2 = 1
        end
        for i = 1, getn(graph.bars) do
            local h, ha, hw = 0, 0, 0
            while hcdump.kills[k] and difftime(time(), hcdump.kills[k].date) + (60 - d.min) * 60 + (60 - d.sec) > (getn(graph.bars)-i) * 3600 / graph.freq do
                local name = hcdump.kills[k].name
                if not decays[name] then
                    decays[name] = 0
                end
                if hcdump.kills[k].world then
                    hw = hw + hcdump.kills[k].honor * math.max(0, 1-decays[name]*decay)
                else
                    h = h + hcdump.kills[k].honor * math.max(0, 1-decays[name]*decay)
                end
                decays[name] = decays[name] + 1
                k = k + 1
            end
            while hcdump.awards[k2] and difftime(time(), hcdump.awards[k2].date) + (60 - d.min) * 60 + (60 - d.sec) > (getn(graph.bars)-i) * 3600 / graph.freq do
                ha = ha + hcdump.awards[k2].honor
                k2 = k2 + 1
            end
            max = math.max(h+ha+hw, max)
            graph.bars[i].honor = h
            graph.bars[i].honorAwards = ha
            graph.bars[i].honorWorld = hw
        end
        graph.max = max
    end
end)

local EFrame = EFrame.Blizzlike
local function UIInit()
    HonorCounterWindow = EFrame.Window()
    HonorCounterWindow.visible = false
    HonorCounterWindow.title = "HonorCounter"
    HonorCounterWindow.centralItem = EFrame.ColumnLayout(HonorCounterWindow)
    HonorCounterWindow.centralItem.spacing = 2
    local killLabel = EFrame.Label(HonorCounterWindow.centralItem)
    killLabel.text = "Estimated Honor"
    killLabel.sizeMode = EFrame.Label.VerticalFit
    killLabel.Layout.fillHeight = true
    local sessionRow = EFrame.RowLayout(HonorCounterWindow.centralItem)
    sessionRow.Layout.fillHeight = true
    local sessionText = EFrame.Label(sessionRow)
    sessionText.sizeMode = EFrame.Label.VerticalFit
    sessionText.Layout.fillHeight = true
    sessionText.text = EFrame.bind(function() local s = HonorCounter.sessionTime return format("Session: %d (%dh%02dm)", HonorCounter.session, math.floor(s/3600), mod(math.floor(s/60),60)) end)
    local sessionMouseArea = EFrame.MouseArea(sessionText)
    sessionMouseArea.anchorFill = sessionText
    sessionMouseArea.hoverEnabled = true
    sessionMouseArea:connect("containsMouseChanged", function (c)
        if c then
            GameTooltip:SetOwner(sessionMouseArea.frame, "ANCHOR_TOP")
            GameTooltip:AddLine(format("Honor/hour: %d", HonorCounter.session/(HonorCounter.sessionTime/3600)))
            GameTooltip:AddLine(format("World Honor: %d (%d%%)", HonorCounter.sessionWorld, HonorCounter.session > 0 and HonorCounter.sessionWorld/HonorCounter.session * 100 or 0))
            GameTooltip:AddLine(format("BG Honor: %d (%d%%)", HonorCounter.sessionHonor, HonorCounter.session > 0 and HonorCounter.sessionHonor/HonorCounter.session * 100 or 0))
            GameTooltip:AddLine(format("Awards: %d (%d%%)", HonorCounter.sessionAwards, HonorCounter.session > 0 and HonorCounter.sessionAwards/HonorCounter.session * 100 or 0))
            GameTooltip:Show()
        elseif GameTooltip:IsOwned(sessionMouseArea.frame) then
            GameTooltip:FadeOut()
        end
    end)
    
    local sessionResetBtn = EFrame.Button(sessionRow)
    sessionResetBtn.text = "Reset"
    sessionResetBtn:connect("clicked", function() HonorCounter.sessionAwards = 0 HonorCounter.sessionWorld = 0 HonorCounter.sessionHonor = 0 HonorCounter.sessionTime = 0 sessionStartTime = GetTime() end)
    sessionResetBtn.Layout.alignment = EFrame.Layout.AlignBottom
    
    local totalText = EFrame.Label(HonorCounterWindow.centralItem)
    totalText.sizeMode = EFrame.Label.VerticalFit
    totalText.Layout.fillHeight = true
    local _, thisWeek = GetPVPThisWeekStats()
    totalText.text = EFrame.bind(function() local h = HonorCounter.today return format("Today: %d (Week: %d)", h, h + thisWeek) end)
    local meanText = EFrame.Label(HonorCounterWindow.centralItem)
    meanText.sizeMode = EFrame.Label.VerticalFit
    meanText.Layout.fillHeight = true
    meanText.text = EFrame.bind(function() local m = HonorCounter.honorMean / ta return format("Estimated Honor/Hour: %d", m == 1/0 and 0 or m) end)
    local decayText = EFrame.Label(HonorCounterWindow.centralItem)
    decayText.sizeMode = EFrame.Label.VerticalFit
    decayText.Layout.fillHeight = true
    decayText.text = EFrame.bind(function() return format("Mean Diminishing: %d%%", HonorCounter.killsMean > 0 and HonorCounter.decayMean / HonorCounter.killsMean or 0) end)
    local tarow = EFrame.RowLayout(HonorCounterWindow.centralItem)
    tarow.Layout.alignment = EFrame.Layout.AlignRight
    tarow.Layout.fillHeight = true
    local infoText1 = EFrame.Label(tarow)
    infoText1.sizeMode = EFrame.Label.VerticalFit
    infoText1.Layout.fillHeight = true
    infoText1.text = "(adjust speed:"
    
    local taSpin = EFrame.SpinBox(tarow)
    taSpin.from = 5
    taSpin.value = EFrame.bind(function() return HonorCounter.ta * 60 end)
    taSpin:connect("valueChanged", function(v) HonorCounter.ta = v*60/3600 end)
    
    local infoText2 = EFrame.Label(tarow)
    infoText2.text = "min)"
    infoText2.sizeMode = EFrame.Label.VerticalFit
    infoText2.Layout.fillHeight = true
    
    local targetDiminishing
    if HonorCounterProfile.targetX and HonorCounterProfile.targetY then
        targetDiminishing = EFrame.Label(EFrame.root)
        targetDiminishing.anchorTopLeft = EFrame.root.topLeft
        targetDiminishing.marginTop = HonorCounterProfile.targetY
        targetDiminishing.marginLeft = HonorCounterProfile.targetX
    else
        targetDiminishing = EFrame.Label(HonorCounterWindow.centralItem)
        targetDiminishing.Layout.fillHeight = true
    end
    targetDiminishing.text = EFrame.bind(function() return HonorCounter.targetKills and format("%s%d%% (%d kills)", targetDiminishing.parent == EFrame.root and "" or "Target's diminish: ", math.min(HonorCounter.targetKills*pdecay, 100), HonorCounter.targetKills) or targetDiminishing.parent == EFrame.root and "[]" or "Target's diminish:" end)
    local targetDiminishingHandle = EFrame.MouseArea(targetDiminishing)
    targetDiminishingHandle.anchorFill = targetDiminishing
    targetDiminishingHandle.dragTarget = targetDiminishing
    targetDiminishing.sizeMode = EFrame.bind(function() return targetDiminishing.parent == EFrame.root and EFrame.Label.NoFit or EFrame.Label.VerticalFit end)
    targetDiminishingHandle:connect("dragActiveChanged", EFrame:makeAtomic(function (active)
        if active and targetDiminishing.__parent ~= EFrame.root then
            targetDiminishing.parent = EFrame.root
            local x, y = targetDiminishing.frame:GetLeft(), EFrame.root.height / EFrame.root.scale - targetDiminishing.frame:GetTop()
            targetDiminishing:clearAnchors()
            targetDiminishing.anchorTopLeft = EFrame.root.topLeft
        elseif not active and targetDiminishing.__parent == EFrame.root then
            local cx, cy = targetDiminishing.marginLeft + targetDiminishing.width/2 - HonorCounterWindow.marginLeft, targetDiminishing.marginTop + targetDiminishing.height/2 - HonorCounterWindow.marginTop
            if cx > 0 and cx < HonorCounterWindow.width * HonorCounterWindow.scale and cy > 0 and cy < HonorCounterWindow.height * HonorCounterWindow.scale then
                targetDiminishing:clearAnchors()
                targetDiminishing.parent = HonorCounterWindow.centralItem
                targetDiminishing.Layout.fillHeight = true
            end
        end
    end))
    targetDiminishing:connect("marginLeftChanged", function (l)
        if targetDiminishing.__parent == EFrame.root then
            HonorCounterProfile.targetX = l
        else
            HonorCounterProfile.targetX = nil
        end
    end)
    targetDiminishing:connect("marginTopChanged", function (t)
        if targetDiminishing.__parent == EFrame.root then
            HonorCounterProfile.targetY = t
        else
            HonorCounterProfile.targetY = nil
        end
    end)
    
    graph = EFrame.RowLayout(HonorCounterWindow.centralItem)
    graph.__max = 0
    graph:attach("max")
    graph.bars = {}
    graph.freq = 1
    graph.targets = {
        {target="honorAwards", color={1,1  ,0,.66}},
        {target="honor",       color={1,0.5,0,.66}},
        {target="honorWorld",  color={1,0  ,0,.66}},
    }
    for i = 1, 24 * graph.freq do
        local m = EFrame.MouseArea(graph)
        local r = EFrame.ColumnLayout(m)
        r.__honor = 0
        r.__honorAwards = 0
        r.__honorWorld = 0
        r:attach("honor")
        r:attach("honorAwards")
        r:attach("honorWorld")
        r:attach("honorTotal")
        r.honorTotal = EFrame.bind(function() return r.honor + r.honorAwards + r.honorWorld end)
        r.implicitWidth = 5
        r.anchorBottom = m.bottom
        local r0 = EFrame.Rectangle(r)
        r0.implicitHeight = 1
        r0.visible = EFrame.bind(function() return r.honorTotal == 0 end)
        r0.color = {.5,.5,.5,.5}
        r0.Layout.fillWidth = true
        for _, c in ipairs(graph.targets) do
            local r1 = EFrame.Rectangle(r)
            r1.target = c.target
            r1.implicitHeight = EFrame.bind(function() return math.max(r[r1.target]/ graph.max * graph.height, 1) end)
            r1.visible = EFrame.bind(function() return r[r1.target] > 0 end)
            r1.color = c.color
            r1.Layout.fillWidth = true
        end
        tinsert(graph.bars, r)
        m.Layout.fillWidth = true
        m.Layout.fillHeight = true
        m.hoverEnabled = true
        m:connect("containsMouseChanged", function (c)
            if c then
                GameTooltip:SetOwner(m.frame, "ANCHOR_TOP")
                local h = mod((date("*t",time()).hour - (24 - i) + 24), 24)
                GameTooltip:AddLine(format("TIME %d:00-%d:00", h, h+1))
                GameTooltip:AddLine(format("World Honor: %d", r.honorWorld))
                GameTooltip:AddLine(format("BG Honor: %d", r.honor))
                GameTooltip:AddLine(format("Awards: %d", r.honorAwards))
                GameTooltip:AddLine(format("Total: %d", r.honorTotal))
                GameTooltip:Show()
            elseif GameTooltip:IsOwned(m.frame) then
                GameTooltip:FadeOut()
            end
        end)
        local mr = EFrame.Rectangle(m)
        mr.anchorFill = r
        mr.color = {1,1,1,.33}
        mr.visible = EFrame.bind(m, "containsMouse")
        mr.z = 7
    end
    graph.Layout.fillWidth = true
    graph.Layout.fillHeight = true
    
    HonorCounterWindow:connect("marginLeftChanged", function (l)
        HonorCounterProfile.windowX = l
    end)
    HonorCounterWindow:connect("marginTopChanged", function (t)
        HonorCounterProfile.windowY = t
    end)
    
    
    
    function HonorCounterWindow:onVisibleChanged(visible)
        if visible then
            if HonorCounterProfile.windowX and HonorCounterProfile.windowY then
                self.marginLeft = HonorCounterProfile.windowX
                self.marginTop = HonorCounterProfile.windowY
            else
                self.marginRight = self.parent.width/2 - self.width/2
                self.marginLeft = self.parent.height/2 - self.height/2
            end
        end
        if HonorCounterProfile.windowWidth then
            HonorCounterWindow.width = HonorCounterProfile.windowWidth
        else
            HonorCounterWindow.width = 250
        end
        if HonorCounterProfile.windowHeight then
            HonorCounterWindow.height = HonorCounterProfile.windowHeight
        else
            HonorCounterWindow.height = 150
        end
        HonorCounterWindow:connect("widthChanged", function (w)
            if HonorCounterWindow.visible then
                HonorCounterProfile.windowWidth = w
            end
        end)
        HonorCounterWindow:connect("heightChanged", function (h)
            if HonorCounterWindow.visible then
                HonorCounterProfile.windowHeight = h
            end
        end)
        HonorCounterWindow.onVisibleChanged = nil
    end
    function HonorCounterWindow:onImplicitWidthChanged(w)
        self.width = math.max(w, self.__width)
    end
end

function HonorCounter_ShowCount()
    if not HonorCounterWindow then
        UIInit()
    end
    HonorCounterWindow.visible = true
end

local function chatcmd()
    if not HonorCounterWindow then
        UIInit()
    end
    HonorCounterWindow.visible = not HonorCounterWindow.visible
end

_G.SLASH_HONORCOUNTER1 = "/honorcounter"
_G.SLASH_HONORCOUNTER2 = "/hc"
_G.SlashCmdList["HONORCOUNTER"] = chatcmd

EventHandler:SetScript("OnEvent", EFrame:makeAtomic(function() EventHandler:process(event) end))
EventHandler:RegisterEvent("ADDON_LOADED")
