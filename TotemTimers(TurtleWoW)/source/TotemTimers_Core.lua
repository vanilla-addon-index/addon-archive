local TT = _G.TotemTimersAddon or {}
_G.TotemTimersAddon = TT

local ELEMENTS = { "Earth", "Fire", "Water", "Air" }
TT.ELEMENTS = ELEMENTS
TT.RECALL_SPELL = "Totemic Recall"

TT.frame = CreateFrame("Frame", "TotemTimersFrame", UIParent)
TotemTimersDB = TotemTimersDB or {}

local defaults = {
    locked = false,
    compact = false,
    vertical = false,
    scale = 1,
    anchor = {
        point = "CENTER",
        x = 0,
        y = 100,
    },
    selected = {},
    twistThreshold = 10,
}

local function CopyDefaults(dst, src)
    if type(dst) ~= "table" then
        dst = {}
    end

    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then
                dst[key] = {}
            end
            CopyDefaults(dst[key], value)
        elseif dst[key] == nil then
            dst[key] = value
        end
    end

    return dst
end

function TT.LoadDB()
    if type(TotemTimersDB) ~= "table" then
        TotemTimersDB = {}
    end

    TotemTimersDB = CopyDefaults(TotemTimersDB, defaults)
end

TT.TOTEMS = {
    Earth = {
        ["Earthbind Totem"] = 45,
        ["Stoneclaw Totem"] = 15,
        ["Stoneskin Totem"] = 120,
        ["Strength of Earth Totem"] = 120,
        ["Tremor Totem"] = 120,
    },
    Fire = {
        ["Fire Nova Totem"] = 5,
        ["Flametongue Totem"] = 120,
        ["Frost Resistance Totem"] = 120,
        ["Magma Totem"] = 20,
        ["Searing Totem"] = 30,
    },
    Water = {
        ["Disease Cleansing Totem"] = 120,
        ["Fire Resistance Totem"] = 120,
        ["Healing Stream Totem"] = 60,
        ["Mana Spring Totem"] = 60,
        ["Mana Tide Totem"] = 12,
        ["Poison Cleansing Totem"] = 120,
    },
    Air = {
        ["Grace of Air Totem"] = 120,
        ["Grounding Totem"] = 45,
        ["Nature Resistance Totem"] = 120,
        ["Sentry Totem"] = 300,
        ["Tranquil Air Totem"] = 120,
        ["Windfury Totem"] = 120,
        ["Windwall Totem"] = 120,
    },
}

TT.ACTIVE = TT.ACTIVE or {}
TT.GCD = TT.GCD or { start = 0, duration = 1.5 }
TT.KNOWN = TT.KNOWN or {}
TT.TOTEM_LOOKUP = TT.TOTEM_LOOKUP or {}
TT.lastUpdateAt = TT.lastUpdateAt or 0
TT.lastActionAt = TT.lastActionAt or {}

local function BuildTotemLookup()
    local element, list, spellName, duration

    for element, list in pairs(TT.TOTEMS) do
        for spellName, duration in pairs(list) do
            TT.TOTEM_LOOKUP[spellName] = {
                element = element,
                duration = duration,
            }
        end
    end
end

local function TrimText(text)
    if not text then
        return ""
    end

    return string.gsub(text, "^%s*(.-)%s*$", "%1")
end

local function MarkRecentAction(spellName)
    TT.lastActionAt[spellName] = GetTime()
end

local function IsRecentAction(spellName, window)
    local lastTime

    if not spellName then
        return false
    end

    lastTime = TT.lastActionAt[spellName]
    if not lastTime then
        return false
    end

    return (GetTime() - lastTime) <= (window or 0.35)
end

BuildTotemLookup()

function TT.GetButton(element)
    return _G["TotemTimers_" .. element]
end

function TT.GetRecallButton()
    return _G["TotemTimers_Recall"]
end

function TT.GetTotemInfo(spellName)
    local info = TT.TOTEM_LOOKUP[spellName]
    if info then
        return info.element, info.duration
    end
end

function TT.GetSpellbookSlot(spellName)
    local index = 1
    local name

    while true do
        name = GetSpellName(index, BOOKTYPE_SPELL)
        if not name then
            break
        end

        if name == spellName then
            return index
        end

        index = index + 1
    end
end

function TT.IsSpellKnown(spellName)
    return TT.GetSpellbookSlot(spellName) ~= nil
end

function TT.IsRecallKnown()
    return TT.IsSpellKnown(TT.RECALL_SPELL)
end

function TT.RefreshKnownSpells()
    local element, spellList, spellName, selected

    for element, spellList in pairs(TT.TOTEMS) do
        TT.KNOWN[element] = {}
        for spellName in pairs(spellList) do
            if TT.IsSpellKnown(spellName) then
                table.insert(TT.KNOWN[element], spellName)
            end
        end
        table.sort(TT.KNOWN[element])

        selected = TotemTimersDB.selected[element]
        if not selected or not TT.IsSpellKnown(selected) then
            TotemTimersDB.selected[element] = TT.KNOWN[element][1]
        end
    end
end

function TT.GetKnownTotems(element)
    if not TT.KNOWN[element] then
        TT.KNOWN[element] = {}
    end
    return TT.KNOWN[element]
end

function TT.HasKnownTotems(element)
    return table.getn(TT.GetKnownTotems(element)) > 0
end

function TT.GetSelectedSpell(element)
    local active = TT.ACTIVE[element]
    if active and active.name then
        return active.name
    end

    return TotemTimersDB.selected[element]
end

function TT.SetSelectedSpell(element, spellName)
    if not element or not spellName then
        return
    end

    TotemTimersDB.selected[element] = spellName
    TT.UpdateButton(element)
    TT.UpdateSpellMenu(element)
end

function TT.CastSelectedSpell(element)
    local spellName = TotemTimersDB.selected[element]
    if spellName and TT.IsSpellKnown(spellName) then
        TT.pendingAction = {
            kind = "totem",
            spellName = spellName,
        }
        CastSpellByName(spellName)
    end
end

function TT.CastRecall()
    if TT.IsRecallKnown() then
        TT.pendingAction = {
            kind = "recall",
            spellName = TT.RECALL_SPELL,
        }
        CastSpellByName(TT.RECALL_SPELL)
    end
end

function TT.FindTotemInMessage(message)
    local element, spells, spellName
    if not message or message == "" then
        return
    end

    for element, spells in pairs(TT.TOTEMS) do
        for spellName in pairs(spells) do
            if string.find(message, spellName, 1, true) then
                return spellName
            end
        end
    end
end

function TT.StartGCD()
    TT.GCD.start = GetTime()
    TT.RefreshButtons()
end

function TT.StartTimer(spellName)
    local element, duration = TT.GetTotemInfo(spellName)
    if not element then
        return
    end

    if IsRecentAction(spellName, 0.35) then
        return
    end

    MarkRecentAction(spellName)

    TT.ACTIVE[element] = {
        element = element,
        name = spellName,
        start = GetTime(),
        duration = duration,
    }

    TT.UpdateButton(element, duration, spellName)
    TT.UpdateTwistHelper()
end

function TT.StopTotem(element)
    TT.ACTIVE[element] = nil
    TT.UpdateButton(element, nil)
    TT.UpdateTwistHelper()
end

function TT.GetRemainingTime(element)
    local data = TT.ACTIVE[element]
    if not data then
        return nil
    end

    local remain = data.duration - (GetTime() - data.start)
    if remain <= 0 then
        return 0
    end

    return remain
end

function TT.ClearActiveTotems()
    local index

    for index = 1, table.getn(ELEMENTS) do
        TT.ACTIVE[ELEMENTS[index]] = nil
    end

    for index = 1, table.getn(ELEMENTS) do
        TT.UpdateButton(ELEMENTS[index], nil)
    end

    TT.pendingSpell = nil
    TT.pendingAction = nil
    TT.UpdateTwistHelper()
end

function TT.RefreshButtons()
    local index

    for index = 1, table.getn(ELEMENTS) do
        TT.UpdateButton(ELEMENTS[index])
    end

    TT.UpdateRecallButton()
end

function TT.HandleRecallSuccess()
    if IsRecentAction(TT.RECALL_SPELL, 0.35) then
        return
    end

    MarkRecentAction(TT.RECALL_SPELL)
    TT.ClearActiveTotems()
end

function TT.UpdateTimers()
    local now = GetTime()
    if (now - TT.lastUpdateAt) < 0.1 then
        return
    end

    TT.lastUpdateAt = now

    for _, element in ipairs(ELEMENTS) do
        local data = TT.ACTIVE[element]
        if data then
            local remain = data.duration - (now - data.start)
            if remain <= 0 then
                TT.ACTIVE[element] = nil
                TT.UpdateButton(element, nil)
            else
                TT.UpdateButton(element, remain, data.name)
            end
        end
    end
    TT.UpdateTwistHelper()
end

TT.frame:RegisterEvent("VARIABLES_LOADED")
TT.frame:RegisterEvent("PLAYER_LOGIN")
TT.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
TT.frame:RegisterEvent("PLAYER_DEAD")
TT.frame:RegisterEvent("PLAYER_ALIVE")
TT.frame:RegisterEvent("PLAYER_UNGHOST")
TT.frame:RegisterEvent("SPELLS_CHANGED")
TT.frame:RegisterEvent("SPELLCAST_START")
TT.frame:RegisterEvent("SPELLCAST_STOP")
TT.frame:RegisterEvent("SPELLCAST_FAILED")
TT.frame:RegisterEvent("SPELLCAST_INTERRUPTED")
TT.frame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
TT.frame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")

TT.frame:SetScript("OnEvent", function()
    local event = event
    if event == "VARIABLES_LOADED" then
        TT.LoadDB()
    elseif event == "PLAYER_LOGIN" then
        TT.RefreshKnownSpells()
        TT.CreateAnchor()
        TT.InitUI()
        TT.ApplyLayout()
        TT.UpdateAnchorState()
        TT.UpdateTwistHelper()
        TT.pendingSpell = nil
        TT.pendingAction = nil
    elseif event == "PLAYER_ENTERING_WORLD" then
        TT.RefreshButtons()
        TT.UpdateTwistHelper()
    elseif event == "PLAYER_DEAD" then
        TT.ClearActiveTotems()
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        TT.pendingSpell = nil
        TT.pendingAction = nil
        TT.UpdateTwistHelper()
    elseif event == "SPELLS_CHANGED" then
        TT.RefreshKnownSpells()
        TT.ApplyLayout()
    elseif event == "SPELLCAST_START" then
        local spellName = arg1
        if spellName == TT.RECALL_SPELL then
            TT.pendingAction = {
                kind = "recall",
                spellName = spellName,
            }
            TT.StartGCD()
        elseif spellName and TT.GetTotemInfo(spellName) then
            TT.pendingSpell = spellName
            TT.pendingAction = {
                kind = "totem",
                spellName = spellName,
            }
            TT.StartGCD()
        end
    elseif event == "SPELLCAST_STOP" then
        local spellName = arg1 or TT.pendingSpell or (TT.pendingAction and TT.pendingAction.spellName)
        if spellName == TT.RECALL_SPELL then
            TT.StartGCD()
            TT.HandleRecallSuccess()
        elseif spellName and TT.GetTotemInfo(spellName) then
            TT.StartGCD()
            TT.StartTimer(spellName)
        end
        TT.pendingSpell = nil
        TT.pendingAction = nil
    elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
        TT.pendingSpell = nil
        TT.pendingAction = nil
    elseif event == "CHAT_MSG_SPELL_SELF_BUFF" or event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        local message = TrimText(arg1)
        local spellName = TT.FindTotemInMessage(message)
        if string.find(message, TT.RECALL_SPELL, 1, true) then
            TT.StartGCD()
            TT.HandleRecallSuccess()
            TT.pendingSpell = nil
            TT.pendingAction = nil
        elseif spellName then
            TT.StartGCD()
            TT.StartTimer(spellName)
            TT.pendingSpell = nil
            TT.pendingAction = nil
        end
    end
end)

TT.frame:SetScript("OnUpdate", function()
    TT.UpdateTimers()
end)
