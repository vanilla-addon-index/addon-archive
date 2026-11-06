PTUtil.SetEnvironment(Puppeteer)
local _G = getfenv(0)
local util = PTUtil

EventHandlerFrames = {}
local function RegisterEventHandler(events, handler)
    if type(events) == "string" then
        events = {events}
    end
    local frame = CreateFrame("Frame", "PTEventHandler_"..events[1])
    for _, event in ipairs(events) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", handler)
    table.insert(EventHandlerFrames, frame)
end

function UnregisterEventHandlers()
    for _, frame in ipairs(EventHandlerFrames) do
        frame:UnregisterAllEvents()
    end
end

RegisterEventHandler("ADDON_LOADED", function()
    if arg1 ~= "Puppeteer" then
        return
    end
    GuidRoster = PTGuidRoster
    OnAddonLoaded()
end)
RegisterEventHandler("PLAYER_ENTERING_WORLD", function()
    CheckGroup()

    if PTOptions.DisablePartyFrames.InParty then
        SetPartyFramesEnabled(false)
    end

    PromptHealersMateImport()
end)
RegisterEventHandler({"UNIT_HEALTH", "UNIT_MAXHEALTH"}, function()
    local unit = arg1
    if not IsRelevantUnit(unit) then
        return
    end
    for ui in UnitFrames(unit) do
        if ui:IsActive() then -- Hidden frames catch up in UpdateAll when shown
            ui:UpdateHealth()
        end
    end
end)
RegisterEventHandler({"UNIT_MANA", "UNIT_RAGE", "UNIT_ENERGY", "UNIT_FOCUS", "UNIT_MAXMANA", "UNIT_DISPLAYPOWER"}, function()
    local unit = arg1
    if not IsRelevantUnit(unit) then
        return
    end

    for ui in UnitFrames(unit) do
        if ui:IsActive() then
            ui:UpdatePower()
        end
    end

    if unit == "player" then
        ReapplySpellsTooltip()
    end

    local raidFrameGroup = UnitFrameGroups["Raid"]
    if raidFrameGroup then
        raidFrameGroup:RequestRaidManaUpdate()
    end
end)
-- Rescans the unit's auras and rebuilds its aura icons
local function UpdateUnitAuras(unit)
    if unit == "player" then
        util.MarkSpellCostCacheDirty()
    end
    PTUnit.Get(unit):UpdateAuras() -- The unit cache stays current for every frame
    for ui in UnitFrames(unit) do
        if ui:IsActive() then
            ui:UpdateAuras()
            ui:UpdateHealth() -- Update health because there may be an aura that changes health bar color
        end
    end
end

-- True once UNIT_AURA_DELTA handles the real unit tokens (see RegisterClassicAPIEvents)
local auraDeltaActive = false
local AllRealUnitsSet = util.AllRealUnitsSet

RegisterEventHandler("UNIT_AURA", function()
    local unit = arg1
    if not IsRelevantUnit(unit) then
        return
    end
    -- ClassicAPI reports the same changes for these tokens through UNIT_AURA_DELTA, with what changed.
    -- Other arguments (SuperWoW GUIDs of custom units) still come only through UNIT_AURA, and so do
    -- members out of view, whose auras arrive with the party stats rather than the unit's own fields.
    if auraDeltaActive and AllRealUnitsSet[unit] and UnitIsVisible(unit) then
        return
    end
    UpdateUnitAuras(unit)
end)

-- ClassicAPI events, registered once options are loaded and the unit frames exist
function RegisterClassicAPIEvents()
    if util.IsClassicAPIActive("AuraDelta") then
        auraDeltaActive = true
        RegisterEventHandler("UNIT_AURA_DELTA", function()
            local unit = arg1
            if not IsRelevantUnit(unit) then
                return
            end
            local info = arg2 -- Valid only during this handler
            if info and not info.isFullUpdate and not info.addedAuraInstanceIDs and not info.removedAuraInstanceIDs then
                -- Only refreshes and stack changes: update the timers and stacks in place
                if PTUnit.Get(unit):RefreshClassicAuras() then
                    if unit == "player" then
                        util.MarkSpellCostCacheDirty()
                    end
                    for ui in UnitFrames(unit) do
                        if ui:IsActive() then
                            ui:RefreshAuras()
                        end
                    end
                    return
                end
            end
            UpdateUnitAuras(unit)
        end)
    end

    if util.IsClassicAPIActive("Resurrection") then
        RegisterEventHandler("INCOMING_RESURRECT_CHANGED", function()
            local unit = arg1
            if not IsRelevantUnit(unit) then
                return
            end
            for ui in UnitFrames(unit) do
                if ui:IsActive() then
                    ui:UpdateHealth()
                end
            end
        end)
    end

    if util.IsClassicAPIActive("ConnectionEvent") then
        RegisterEventHandler("UNIT_CONNECTION", function()
            local unit = arg1
            if not IsRelevantUnit(unit) then
                return
            end
            PTUnit.Get(unit):UpdateDistance()
            for ui in UnitFrames(unit) do
                if ui:IsActive() then
                    ui:UpdateHealth()
                    ui:UpdatePower()
                    ui:UpdateRange()
                end
            end
        end)
    end

    -- Visibility and the 40 yard check change state right away instead of at the next tracking scan
    local function UpdateUnitRange()
        local unit = arg1
        if not IsRelevantUnit(unit) then
            return
        end
        local cache = PTUnit.Get(unit)
        local distanceChanged = cache:UpdateDistance()
        local sightChanged = cache:UpdateSight()
        if distanceChanged or sightChanged then
            for ui in UnitFrames(unit) do
                if ui:IsActive() then
                    if distanceChanged then
                        ui:UpdateRange()
                    end
                    if sightChanged then
                        ui:UpdateSight()
                    end
                end
            end
        end
    end
    if util.IsClassicAPIActive("VisibilityEvent") then
        RegisterEventHandler("UNIT_DISTANCE_CHECK_UPDATE", UpdateUnitRange)
    end
    -- ClassicAPI checks every unit registered for UNIT_IN_RANGE_UPDATE on every frame, so it is only used when
    -- nothing better measures range: UnitXP SP3 and SuperWoW distances are already polled by the unit tracker.
    if util.IsClassicAPIActive("RangeEvent") and not util.IsUnitXPSP3Present() and not util.IsSuperWowPresent() then
        -- RegisterEvent covers pet, party and raid members and their pets
        RegisterEventHandler("UNIT_IN_RANGE_UPDATE", UpdateUnitRange)
    end
end
RegisterEventHandler({"PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE"}, function()
    CheckGroupThrottled()
end)
RegisterEventHandler({"UNIT_PET", "PLAYER_PET_CHANGED"}, function()
    local unit = arg1
    if IsRelevantUnit(unit) then
        CheckGroupThrottled()
    end
end)
RegisterEventHandler("PLAYER_TARGET_CHANGED", function()
    for _, ui in ipairs(AllUnitFrames) do
        ui:EvaluateTarget()
    end
    local exists, guid = UnitExists("target")
    if util.IsSuperWowPresent() then
        PTUnit.UpdateGuidCaches()
    end

    PTUnit.Get("target"):UpdateAll()
    if util.IsSuperWowPresent() then
        GuidRoster.SetUnitGuid("target", guid)
        PTHealPredict.SetRelevantGUIDsFromMap(GuidRoster.GuidUnitMap)
    end

    if exists then
        EvaluateTracking("target", true)
    end

    if PTOptions.Hidden then
        return
    end

    CheckTarget()
end)
RegisterEventHandler("SPELLS_CHANGED", function()
    PuppeteerSettings.UpdateTrackedDebuffTypes()
    util.MarkSpellCostCacheDirty()
end)
RegisterEventHandler("CHARACTER_POINTS_CHANGED", function()
    util.MarkSpellCostCacheDirty()
end)
RegisterEventHandler("RAID_TARGET_UPDATE", function()
    for _, ui in ipairs(AllUnitFrames) do
        ui:UpdateRaidMark()
    end
end)
RegisterEventHandler("UNIT_FACTION", function()
    if not IsRelevantUnit(arg1) then
        return
    end
    for ui in UnitFrames(arg1) do
        ui:UpdatePVP()
    end
end)
RegisterEventHandler("PLAYER_LOGOUT", function()
    RemoveOverrideBindings()
    PuppeteerSettings.SaveFramePositions()
end)

local GetKeyModifier = util.GetKeyModifier
local keyListener = CreateFrame("Frame", "PTTooltipKeyListener")
local lastModifier = "None"
local function PTTooltipKeyListener_OnUpdate()
    local modifier = GetKeyModifier()
    if lastModifier ~= modifier then
        lastModifier = modifier
        if SpellsTooltip:IsVisible() then
            ReapplySpellsTooltip()
        end
    end
end

function SetTooltipKeyListenerEnabled(enabled)
    if keyListener:GetScript("OnUpdate") ~= nil == enabled then -- Don't set the script if the state is unchanged
        return
    end
    if enabled then
        lastModifier = GetKeyModifier()
        keyListener:SetScript("OnUpdate", PTTooltipKeyListener_OnUpdate)
    else
        keyListener:SetScript("OnUpdate", nil)
    end
end