HardcoreAlarmsPfDBHelper = {}

local zones_by_name = {}
local units_by_name = {}

local locale = GetLocale()
if locale == "enGB" then
    locale = "enUS"
end

local function ensureZonesLookupTable()
    zones_by_name = {[locale .. "-turtle"] = {}, [locale] = {}}
    if HardcoreAlarms_pfDB["zones"][locale] then
        for id, name in pairs(HardcoreAlarms_pfDB["zones"][locale]) do
            if type(name) == "string" then zones_by_name[locale][name] = id end
        end
    end
    if HardcoreAlarms_pfDB["zones"][locale .. "-turtle"] then
        for id, name in pairs(HardcoreAlarms_pfDB["zones"][locale .. "-turtle"]) do
            if type(name) == "string" then zones_by_name[locale .. "-turtle"][name] = id end
        end
    end
end

local function ensureUnitsLookupTable()
    units_by_name = {[locale .. "-turtle"] = {}, [locale] = {}}
    if HardcoreAlarms_pfDB["units"][locale] then
        for id, name in pairs(HardcoreAlarms_pfDB["units"][locale]) do
            if type(name) == "string" then units_by_name[locale][name] = id end
        end
    end
    if HardcoreAlarms_pfDB["zones"][locale .. "-turtle"] then
        for id, name in pairs(HardcoreAlarms_pfDB["units"][locale .. "-turtle"]) do
            if type(name) == "string" then units_by_name[locale .. "-turtle"][name] = id end
        end
    end
end

local zoneIdCache = {}
local unitNameCache = {}
local questTitleCache = {}
local zoneIdError = {}
local unitNameError = {}
local questTitleError = {}

function HardcoreAlarmsPfDBHelper:SetPrint(callback)
    if callback == nil then
        self.print = nil
    else
        self.print = callback
    end
end

-- Safe call helper for listener
function HardcoreAlarmsPfDBHelper:Print(msg)
    if type(self.print) ~= "function" then return end
    pcall(self.print, msg)
end

function HardcoreAlarmsPfDBHelper:GetZoneId(zoneText)
    ensureZonesLookupTable()
    if zoneIdCache[zoneText] ~= nil then return zoneIdCache[zoneText] end
    if not zones_by_name or not zones_by_name[locale] then return nil end -- sanity checks
    local zoneId = nil
    if zones_by_name[locale][zoneText] then zoneId = zones_by_name[locale][zoneText]
    elseif zones_by_name[locale .. "-turtle"][zoneText] then zoneId = zones_by_name[locale .. "-turtle"][zoneText] end
    if not zoneId and zoneIdError[zoneText] == nil then
        HardcoreAlarmsPfDBHelper:Print("|cffff0000ERROR! GetZoneId - zoneId could not be retrieved for zoneName: '" .. zoneText .. "'|r")
        zoneIdError[zoneText] = true
    end
    zoneIdCache[zoneText] = zoneId
    return zoneId
end

function HardcoreAlarmsPfDBHelper:GetUnitName(unitId)
    if unitNameCache[unitId] ~= nil then return unitNameCache[unitId] end
    if not HardcoreAlarms_pfDB["units"] or not HardcoreAlarms_pfDB["units"][locale] then return nil end -- sanity checks
    local unitName = nil
    if HardcoreAlarms_pfDB["units"][locale][unitId] then unitName = HardcoreAlarms_pfDB["units"][locale][unitId]
    elseif HardcoreAlarms_pfDB["units"][locale .. "-turtle"][unitId] then unitName = HardcoreAlarms_pfDB["units"][locale .. "-turtle"][unitId] end
    if not unitName and unitNameError[unitId] == nil then
        HardcoreAlarmsPfDBHelper:Print("|cffff0000ERROR! GetUnitName - unitName could not be retrieved for unitId: '" .. unitId .. "'|r")
        unitNameError[unitId] = true
    end
    unitNameCache[unitId] = unitName
    return unitName
end

function HardcoreAlarmsPfDBHelper:GetQuestTitle(questId)
    if questTitleCache[questId] ~= nil then return questTitleCache[questId] end
    if not HardcoreAlarms_pfDB["quests"] or not HardcoreAlarms_pfDB["quests"][locale] or not HardcoreAlarms_pfDB["quests"][locale][questId] then return nil end -- sanity checks
    local questTitle = nil
    if HardcoreAlarms_pfDB["quests"][locale][questId]["T"] then questTitle = HardcoreAlarms_pfDB["quests"][locale][questId]["T"]
    elseif HardcoreAlarms_pfDB["quests"][locale .. "-turtle"][questId]["T"] then questTitle = HardcoreAlarms_pfDB["quests"][locale .. "-turtle"][questId]["T"] end
    if not questTitle and questTitleError[questId] == nil then
        HardcoreAlarmsPfDBHelper:Print("|cffff0000ERROR! GetQuestTitle - questTitle could not be retrieved for questId: '" .. questId .. "'|r")
        questTitleError[questId] = true
    end
    questTitleCache[questId] = questTitle
    return questTitle
end