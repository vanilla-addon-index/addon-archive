-- Caches important information about units and makes the data easily readable at any time.
-- If using SuperWoW, the cache map will have GUIDs as the key instead of unit IDs.

PTUnit = {}
PTUtil.SetEnvironment(PTUnit)
local _G = getfenv(0)

local util = PTUtil
local GetAuraInfo = util.GetAuraInfo
local AllUnits = util.AllUnits
local AllRealUnits = util.AllRealUnits
local AllUnitsSet = util.AllUnitsSet
local superwow = util.IsSuperWowPresent()
local canGetAuraIDs = util.CanClientGetAuraIDs()

-- ClassicAPI aura reading, decided once options load (see ApplyClassicAPIOptions)
local classicAuras = false
local classicResurrection = false
local GetAuraSlots, UnitAuraBySlot

local compost = PTPool

-- Non-instance variable
-- Key: Unit ID(Unmodded) or GUID(SuperWoW) | Value: PTUnit Instance
PTUnit.Cached = {}

PTUnit.Unit = nil

PTUnit.AurasPopulated = false
-- Buff/debuff entry contents: {"name", "stacks", "texture", "index", "type", "id"(SuperWoW/ClassicAPI only), "time"}
-- With ClassicAPI, "index" is the C_UnitAuras index and "filter" is "HELPFUL" or "HARMFUL" (used for tooltips)
PTUnit.Buffs = {} -- Array of all buffs
PTUnit.BuffsMap = {} -- Key: Name | Value: Array of buffs with key's name
PTUnit.BuffsIDSet = {} -- Set of currently applied buff IDs
PTUnit.Debuffs = {} -- Array of all debuffs
PTUnit.DebuffsMap = {} -- Key: Name | Value: Array of debuffs with key's name
PTUnit.DebuffsIDSet = {} -- Set of currently applied debuff IDs
PTUnit.TypedDebuffs = {} -- Key: Type | Value: Array of debuffs that are the type
PTUnit.AfflictedDebuffTypes = {} -- Set of the afflicted debuff types
PTUnit.TrackedDebuffTypes = {} -- Set of debuff types that exclude frivilous debuffs

PTUnit.HasHealingModifier = false
PTUnit.HasImportantDebuff = false

-- Only used with SuperWoW, managed in AuraTracker.lua
PTUnit.AuraTimes = {} -- Key: Aura Name | Value: {"startTime", "duration"}
PTUnit.AuraTimesByName = {}

PTUnit.DisplayPVP = false -- This is not the real PVP status of the unit, this is affected by other conditions

PTUnit.Distance = 0
PTUnit.InSight = true
PTUnit.IsNew = false

function ApplyClassicAPIOptions()
    classicAuras = util.IsClassicAPIActive("AuraSlots")
    if classicAuras then
        GetAuraSlots = C_UnitAuras.GetAuraSlots
        UnitAuraBySlot = C_UnitAuras.UnitAuraBySlot
        canGetAuraIDs = true -- Spell IDs come with every aura
    end
    classicResurrection = util.IsClassicAPIActive("Resurrection")
end

function UsesClassicAuras()
    return classicAuras
end

-- Non-GUID function
function CreateCaches()
    if superwow then
        Puppeteer.print("Tried to create non-SuperWoW caches while using SuperWoW!")
        return
    end
    for _, unit in ipairs(AllUnits) do
        PTUnit:New(unit)
    end
end

function UpdateGuidCaches()
    local cached = PTUnit.Cached
    local prevCached = PTUtil.CloneTableCompost(cached)
    for _, unit in ipairs(AllRealUnits) do
        local exists, guid = UnitExists(unit)
        if exists then
            if not cached[guid] then
                PTUnit:New(guid)
                Puppeteer.EvaluateTracking(unit, true)
            end
            prevCached[guid] = nil
        end
    end
    for guid, units in pairs(PTUnitProxy.GUIDCustomUnitMap) do
        if not cached[guid] then
            PTUnit:New(guid)
            for _, unit in ipairs(units) do
                Puppeteer.EvaluateTracking(unit, true)
            end
        end
        prevCached[guid] = nil
    end
    for garbageGuid, cache in pairs(prevCached) do
        cache:Dispose()
        compost:Reclaim(cache)
        cached[garbageGuid] = nil
    end
    compost:Reclaim(prevCached)
end

-- Likely never needed to be called when using GUIDs
function UpdateAllUnits()
    for _, cache in pairs(PTUnit.Cached) do
        cache:UpdateAll()
    end
end

-- Get the PTUnit by unit ID. If using SuperWoW, GUID or unit ID is accepted.
function Get(unit)
    if superwow and AllUnitsSet[unit] then
        return PTUnit.Cached[PTGuidRoster.GetUnitGuid(unit)] or PTUnit
    end
    return PTUnit.Cached[unit] or PTUnit
end

function GetAllUnits()
    return PTUnit.Cached
end

function PTUnit:New(unit)
    local obj = compost:AcquireHash("Unit", unit)
    setmetatable(obj, self)
    self.__index = self
    PTUnit.Cached[unit] = obj
    obj:AllocateAuras()
    obj.AurasPopulated = true -- To force aura fields to generate
    obj.IsNew = true
    obj.IsSelf = UnitIsUnit(unit, "player")
    if superwow then
        obj.AuraTimes = compost:GetTable()
        obj.AuraTimesByName = compost:GetTable()
    end
    obj:UpdateAll()
    return obj
end

function PTUnit:Dispose()
    ReleaseArrayMap(self.BuffsMap)
    ReleaseArrayMap(self.DebuffsMap)
    ReleaseArrayMap(self.TypedDebuffs)
    compost:Reclaim(self.Buffs)
    compost:Reclaim(self.BuffsMap)
    compost:Reclaim(self.BuffsIDSet)
    compost:Reclaim(self.Debuffs)
    compost:Reclaim(self.DebuffsMap)
    compost:Reclaim(self.DebuffsIDSet)
    compost:Reclaim(self.TypedDebuffs)
    compost:Reclaim(self.AfflictedDebuffTypes)
    compost:Reclaim(self.TrackedDebuffTypes)
    compost:Reclaim(self.BuffEntries, 1)
    compost:Reclaim(self.DebuffEntries, 1)
    util.CompostReclaim(self.AuraTimes)
    compost:Reclaim(self.AuraTimesByName)
end

function PTUnit:UpdateAll()
    self:UpdateAuras()
    self:UpdatePVP()
    self:UpdateDistance()
    self:UpdateSight()
end

-- Returns true if this unit is new, clearing its new status.
function PTUnit:CheckNew()
    if self.IsNew then
        self.IsNew = false
        return true
    end
end

function PTUnit:UpdatePVP()
    if not self.Unit then
        return
    end
    local shouldDisplay = UnitIsPVP(self.Unit) and (not util.IsReallyInInstance() or not UnitIsVisible(self.Unit))
    if self.DisplayPVP ~= (shouldDisplay == 1 or shouldDisplay == true) then
        self.DisplayPVP = shouldDisplay
        return true
    end
    return false
end

function PTUnit:ShouldDisplayPVP()
    return self.DisplayPVP
end

-- Returns true if the distance changed
function PTUnit:UpdateDistance()
    if not self.Unit then
        return
    end
    local prevDist = self.Distance
    self.Distance = self.IsSelf and 0 or util.GetDistanceTo(self.Unit)

    return self.Distance ~= prevDist
end

function PTUnit:GetDistance()
    return self.Distance
end

-- Returns true if the sight state has changed
function PTUnit:UpdateSight()
    if not self.Unit then
        return
    end
    local wasInSight = self.InSight
    self.InSight = self.IsSelf or util.IsInSight(self.Unit)

    return self.InSight ~= wasInSight
end

function PTUnit:IsInSight()
    return self.InSight
end

-- ClassicAPI sees resurrections from any nearby caster, including players without HealComm
local function hasClassicResurrection(unit)
    return classicResurrection and UnitHasIncomingResurrection(unit) == true
end

function PTUnit:IsBeingResurrected()
    if not self.Unit then
        return false
    end
    if PTHealPredict then
        return PTHealPredict.IsBeingResurrected(self.Unit) or hasClassicResurrection(self.Unit)
    end
    return Puppeteer.HealComm:UnitisResurrecting(UnitName(self.Unit)) or hasClassicResurrection(self.Unit)
end

function PTUnit:GetResurrectionCasts()
    if not self.Unit then
        return 0
    end
    local count
    if PTHealPredict then
        count = PTHealPredict.GetResurrectionCount(self.Unit)
    else
        count = Puppeteer.HealComm:UnitisResurrecting(UnitName(self.Unit)) and 1 or 0
    end
    if count == 0 and hasClassicResurrection(self.Unit) then
        count = 1
    end
    return count
end

-- Aura storage is reused across rescans so that UNIT_AURA produces no garbage:
--  * Each unit keeps one entry table per aura slot (BuffEntries/DebuffEntries) that is overwritten in place.
--  * The name/type -> array maps hand their arrays back to a dedicated free list when cleared.
--  * Buffs, Debuffs and the sets are emptied in place rather than swapped for new tables.
local freeArrays = {}
local freeArrayCount = 0
local MAX_FREE_ARRAYS = 1024
local getn, setn = table.getn, table.setn

local function GetArray()
    if freeArrayCount > 0 then
        local array = freeArrays[freeArrayCount]
        freeArrays[freeArrayCount] = nil
        freeArrayCount = freeArrayCount - 1
        return array
    end
    return {}
end

local function ClearArray(array)
    for i = getn(array), 1, -1 do
        array[i] = nil
    end
    setn(array, 0)
end

-- Empties a map whose values are arrays, keeping the arrays for reuse
function ReleaseArrayMap(map)
    for key, array in pairs(map) do
        map[key] = nil
        ClearArray(array)
        if freeArrayCount < MAX_FREE_ARRAYS then
            freeArrayCount = freeArrayCount + 1
            freeArrays[freeArrayCount] = array
        end
    end
end
local ReleaseArrayMap = ReleaseArrayMap

local function ClearSet(set)
    for key in pairs(set) do
        set[key] = nil
    end
end

local function GetEntry(entries, slot)
    local entry = entries[slot]
    if not entry then
        entry = {}
        entries[slot] = entry
    end
    return entry
end

function PTUnit:AllocateAuras()
    self.Buffs = compost:GetTable()
    self.BuffsMap = compost:GetTable()
    self.BuffsIDSet = compost:GetTable()
    self.Debuffs = compost:GetTable()
    self.DebuffsMap = compost:GetTable()
    self.DebuffsIDSet = compost:GetTable()
    self.TypedDebuffs = compost:GetTable()
    self.AfflictedDebuffTypes = compost:GetTable()
    self.TrackedDebuffTypes = compost:GetTable()
    self.BuffEntries = compost:GetTable()
    self.DebuffEntries = compost:GetTable()
end

function PTUnit:ClearAuras()
    if not self.AurasPopulated or self == PTUnit then
        return
    end
    ClearArray(self.Buffs)
    ReleaseArrayMap(self.BuffsMap)
    ClearSet(self.BuffsIDSet)
    ClearArray(self.Debuffs)
    ReleaseArrayMap(self.DebuffsMap)
    ClearSet(self.DebuffsIDSet)
    ReleaseArrayMap(self.TypedDebuffs)
    ClearSet(self.AfflictedDebuffTypes)
    ClearSet(self.TrackedDebuffTypes)
    self.HasHealingModifier = false
    self.AurasPopulated = false
    self.HasImportantDebuff = false
end

local claimedAuras = {}

-- The SuperWoW/Nampower aura time with the most time left for this spell ID that no other aura claimed yet
local function FindTrackedTime(self, id, time)
    local auraTimes = id and self.AuraTimes[id]
    if not auraTimes then
        return nil
    end
    local auraTime = nil
    local highestDuration = -100
    for owner, aura in pairs(auraTimes) do
        local timeLeft = aura.endTime - time
        if not claimedAuras[aura] and timeLeft > highestDuration then
            auraTime = aura
            highestDuration = timeLeft
        end
    end
    if auraTime then
        claimedAuras[auraTime] = 1
    end
    return auraTime
end

-- ClassicAPI aura reading. One slot enumeration per range, then a positional read per aura,
-- so a scan creates no tables after each entry's first use.
local slotBuffer = {}

-- Fills the entry's own time table from ClassicAPI's duration and expiration. Returns nil when unknown.
local function ApplyClassicTime(entry, duration, expirationTime, source, now)
    if not expirationTime or expirationTime <= 0 or not duration or duration <= 0 then
        return nil
    end
    local startTime = expirationTime - duration
    if startTime > now then -- A talent-extended aura must not start in the future
        startTime = now
        duration = expirationTime - now
    end
    if duration <= 0 then
        return nil
    end
    local auraTime = entry.classicTime
    if not auraTime then
        auraTime = {}
        entry.classicTime = auraTime
    end
    auraTime.startTime = startTime
    auraTime.endTime = expirationTime
    auraTime.duration = duration
    auraTime.owner = source -- A unit token, or nil when the cast was not seen
    auraTime.ownerName = source and UnitName(source) or nil
    return auraTime
end

function PTUnit:ScanClassicAuras(unit, time)
    local buffs = self.Buffs
    local buffsMap = self.BuffsMap
    local buffsIDSet = self.BuffsIDSet
    local buffEntries = self.BuffEntries
    local trackedHealingBuffs = PuppeteerSettings.TrackedHealingBuffs
    local _, count = GetAuraSlots(unit, "HELPFUL", nil, nil, slotBuffer)
    for index = 1, count or 0 do
        local name, texture, stacks, type, duration, expirationTime, source, _, _, id =
            UnitAuraBySlot(unit, slotBuffer[index])
        if name then
            if trackedHealingBuffs[name] then
                self.HasHealingModifier = true
            end
            local buff = GetEntry(buffEntries, getn(buffs) + 1)
            buff.name = name
            buff.index = index
            buff.filter = "HELPFUL"
            buff.texture = texture
            buff.stacks = stacks or 0
            buff.type = type or ""
            buff.id = id
            buff.time = ApplyClassicTime(buff, duration, expirationTime, source, time) or FindTrackedTime(self, id, time)
            local nameArray = buffsMap[name]
            if not nameArray then
                nameArray = GetArray()
                buffsMap[name] = nameArray
            end
            if id ~= nil then
                buffsIDSet[id] = true
            end
            table.insert(nameArray, buff)
            table.insert(buffs, buff)
        end
    end

    local afflictedDebuffTypes = self.AfflictedDebuffTypes
    local trackedDebuffTypes = self.TrackedDebuffTypes
    local debuffs = self.Debuffs
    local debuffsMap = self.DebuffsMap
    local debuffsIDSet = self.DebuffsIDSet
    local typedDebuffs = self.TypedDebuffs -- Dispellable debuffs
    local debuffEntries = self.DebuffEntries
    local trackedHealingDebuffs = PuppeteerSettings.TrackedHealingDebuffs
    local importantDebuffs = PuppeteerSettings.ImportantDebuffs
    local ignoredDispellableDebuffs = PuppeteerSettings.IgnoredDispellableDebuffs
    -- HARMFUL also returns debuffs the server moved into free buff slots, which UnitDebuff misses
    _, count = GetAuraSlots(unit, "HARMFUL", nil, nil, slotBuffer)
    for index = 1, count or 0 do
        local name, texture, stacks, type, duration, expirationTime, source, _, _, id =
            UnitAuraBySlot(unit, slotBuffer[index])
        if name then
            type = type or ""
            if trackedHealingDebuffs[name] then
                self.HasHealingModifier = true
            end
            if importantDebuffs[name] then
                self.HasImportantDebuff = true
            end
            local debuff = GetEntry(debuffEntries, getn(debuffs) + 1)
            debuff.name = name
            debuff.index = index
            debuff.filter = "HARMFUL"
            debuff.texture = texture
            debuff.stacks = stacks or 0
            debuff.type = type
            debuff.id = id
            debuff.time = ApplyClassicTime(debuff, duration, expirationTime, source, time) or FindTrackedTime(self, id, time)
            local nameArray = debuffsMap[name]
            if not nameArray then
                nameArray = GetArray()
                debuffsMap[name] = nameArray
            end
            if id ~= nil then
                debuffsIDSet[id] = true
            end
            table.insert(nameArray, debuff)
            if type ~= "" then
                afflictedDebuffTypes[type] = 1
                if not ignoredDispellableDebuffs[name] then
                    trackedDebuffTypes[type] = 1
                end
                local typeArray = typedDebuffs[type]
                if not typeArray then
                    typeArray = GetArray()
                    typedDebuffs[type] = typeArray
                end
                table.insert(typeArray, debuff)
            end
            table.insert(debuffs, debuff)
        end
    end
end

-- Re-reads stacks and timers of the scanned auras in place. Returns false if the aura list itself
-- changed, in which case a full UpdateAuras is needed.
local function RefreshClassicList(unit, filter, list, now)
    local _, count = GetAuraSlots(unit, filter, nil, nil, slotBuffer)
    count = count or 0
    if count ~= getn(list) then
        return false
    end
    for index = 1, count do
        local name, _, stacks, _, duration, expirationTime, source, _, _, id = UnitAuraBySlot(unit, slotBuffer[index])
        local entry = list[index]
        if not name or entry.id ~= id or entry.index ~= index then
            return false
        end
        entry.stacks = stacks or 0
        local classicTime = ApplyClassicTime(entry, duration, expirationTime, source, now)
        if classicTime then
            entry.time = classicTime
        elseif entry.time == entry.classicTime then
            entry.time = nil
        end
    end
    return true
end

-- For UNIT_AURA_DELTA events that only refreshed auras (new duration or stack count)
function PTUnit:RefreshClassicAuras()
    local unit = self.Unit
    if not classicAuras or not unit or self == PTUnit or not self.AurasPopulated then
        return false
    end
    local now = GetTime()
    return RefreshClassicList(unit, "HELPFUL", self.Buffs, now) and RefreshClassicList(unit, "HARMFUL", self.Debuffs, now)
end

function PTUnit:UpdateAuras()
    local unit = self.Unit

    if not unit then
        return
    end

    Puppeteer.StartTiming("PTUnitAuraUpdate")

    self:ClearAuras()

    if not UnitExists(unit) then
        Puppeteer.EndTiming("PTUnitAuraUpdate")
        return
    end

    local time = GetTime()

    if classicAuras then
        self:ScanClassicAuras(unit, time)
        self.AurasPopulated = true
        util.ClearTable(claimedAuras)
        Puppeteer.EndTiming("PTUnitAuraUpdate")
        return
    end

    local buffs = self.Buffs
    local buffsMap = self.BuffsMap
    local buffsIDSet = self.BuffsIDSet
    local buffEntries = self.BuffEntries
    for index = 1, 32 do
        local texture, stacks, id = UnitBuff(unit, index)
        if not texture then
            break
        end
        local name, type = GetAuraInfo(unit, index, "Buff", id)
        if PuppeteerSettings.TrackedHealingBuffs[name] then
            self.HasHealingModifier = true
        end
        local auraTime = FindTrackedTime(self, id, time)
        local buff = GetEntry(buffEntries, index)
        buff.name = name
        buff.index = index
        buff.texture = texture
        buff.stacks = stacks
        buff.type = type
        buff.id = id
        buff.time = auraTime
        local nameArray = buffsMap[name]
        if not nameArray then
            nameArray = GetArray()
            buffsMap[name] = nameArray
        end
        if id ~= nil then
            buffsIDSet[id] = true
        end
        table.insert(nameArray, buff)
        table.insert(buffs, buff)
    end

    local afflictedDebuffTypes = self.AfflictedDebuffTypes
    local trackedDebuffTypes = self.TrackedDebuffTypes
    local debuffs = self.Debuffs
    local debuffsMap = self.DebuffsMap
    local debuffsIDSet = self.DebuffsIDSet
    local typedDebuffs = self.TypedDebuffs -- Dispellable debuffs
    local debuffEntries = self.DebuffEntries
    for index = 1, 16 do
        local texture, stacks, type, id = UnitDebuff(unit, index)
        if not texture then
            break
        end
        type = type or ""
        local name = GetAuraInfo(unit, index, "Debuff", id)
        if PuppeteerSettings.TrackedHealingDebuffs[name] then
            self.HasHealingModifier = true
        end
        if PuppeteerSettings.ImportantDebuffs[name] then
            self.HasImportantDebuff = true
        end
        local auraTime = FindTrackedTime(self, id, time)
        local debuff = GetEntry(debuffEntries, index)
        debuff.name = name
        debuff.index = index
        debuff.texture = texture
        debuff.stacks = stacks
        debuff.type = type
        debuff.id = id
        debuff.time = auraTime
        local nameArray = debuffsMap[name]
        if not nameArray then
            nameArray = GetArray()
            debuffsMap[name] = nameArray
        end
        if id ~= nil then
            debuffsIDSet[id] = true
        end
        table.insert(nameArray, debuff)
        if type ~= "" then
            afflictedDebuffTypes[type] = 1
            if not PuppeteerSettings.IgnoredDispellableDebuffs[name] then
                trackedDebuffTypes[type] = 1
            end
            local typeArray = typedDebuffs[type]
            if not typeArray then
                typeArray = GetArray()
                typedDebuffs[type] = typeArray
            end
            table.insert(typeArray, debuff)
        end
        table.insert(debuffs, debuff)
    end
    self.AurasPopulated = true
    util.ClearTable(claimedAuras)
    Puppeteer.EndTiming("PTUnitAuraUpdate")
end

function PTUnit:HasBuff(name)
    return self.BuffsMap[name] ~= nil
end

-- SuperWoW/WoW 1.18.1 Clients only
function PTUnit:HasBuffID(id)
    return self.BuffsIDSet[id] ~= nil
end

-- Looks for ID if SuperWoW/WoW 1.18.1 Clients is present, otherwise searches by name
function PTUnit:HasBuffIDOrName(id, name)
    if canGetAuraIDs then
        return self:HasBuffID(id)
    end
    return self:HasBuff(name)
end

function PTUnit:HasDebuff(name)
    return self.DebuffsMap[name] ~= nil
end

-- SuperWoW/WoW 1.18.1 Clients only
function PTUnit:HasDebuffID(id)
    return self.DebuffsIDSet[id] ~= nil
end

-- Looks for ID if SuperWoW/WoW 1.18.1 Clients is present, otherwise searches by name
function PTUnit:HasDebuffIDOrName(id, name)
    if canGetAuraIDs then
        return self:HasDebuffID(id)
    end
    return self:HasDebuff(name)
end

function PTUnit:HasDebuffType(type)
    return self.AfflictedDebuffTypes[type]
end

function PTUnit:HasTrackedDebuffType(type)
    return self.TrackedDebuffTypes[type]
end

-- Returns the first buff with the provided name
function PTUnit:GetBuff(name)
    if not self:HasBuff(name) then
        return
    end
    return self.BuffsMap[name][1]
end

-- Returns the table of all buffs with the provided name
function PTUnit:GetBuffs(name)
    return self.BuffsMap[name]
end

function PTUnit:GetDebuff(name)
    if not self:HasDebuff(name) then
        return
    end
    return self.DebuffsMap[name][1]
end

function PTUnit:GetDebuffs(name)
    return self.DebuffsMap[name]
end

function PTUnit:ApplyTimedAura(spellName, spellID, owner, duration, isNampower)
    if not self.AuraTimes[spellID] then
        self.AuraTimes[spellID] = compost:GetTable()
    end
    if not self.AuraTimesByName[spellName] then
        self.AuraTimesByName[spellName] = compost:GetTable()
    end
    duration = duration or 0
    local time = GetTime()
    local entry = compost:AcquireHash(
        "startTime", time,
        "endTime", time + duration,
        "duration", duration,
        "owner", owner,
        "ownerName", UnitName(owner),
        "nampower", isNampower ~= nil and isNampower ~= false
    )
    if self.AuraTimes[spellID][owner] then
        compost:Reclaim(self.AuraTimes[spellID][owner])
    end
    self.AuraTimes[spellID][owner] = entry
    self.AuraTimesByName[spellName] = entry

    self:UpdateAuras()
    for ui in Puppeteer.UnitFrames(self.Unit) do
        ui:UpdateAuras()
    end
end

function PTUnit:GetAuraTimeRemaining(name)
    local auraTime = superwow and self.AuraTimesByName[name] or nil
    if not auraTime and classicAuras then -- ClassicAPI times are kept on the aura entries
        local array = self.BuffsMap[name] or self.DebuffsMap[name]
        local entry = array and array[1]
        auraTime = entry and entry.time
    end
    if not auraTime then
        return
    end
    return auraTime.startTime - GetTime() + auraTime.duration
end