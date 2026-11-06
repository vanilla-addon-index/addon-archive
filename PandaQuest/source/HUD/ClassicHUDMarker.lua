--[[
PandaQuest / HUD/ClassicHUDMarker.lua

Camera-aware quest targets supplied by ClassicAPI. Creatures use the engine's
projected nameplate frame. Gameobjects and interactable units use its
soft-interact targeting only; PandaQuest suppresses ClassicAPI's native icon.
No camera angles are reconstructed in Lua.
]]

local PQ = PandaQuest
local Client = PQ.Client
local ClassicHUDMarker = PQ:NewModule("ClassicHUDMarker")

ClassicHUDMarker.context = nil
ClassicHUDMarker.contextReason = nil
ClassicHUDMarker.cvarsActive = false
ClassicHUDMarker.shownSourceType = nil
ClassicHUDMarker.shownSourceId = nil

local function Config()
    return PQ:GetModule("Config")
end

local function MainQuest()
    return PQ:GetModule("MainQuest")
end

local function Waypoint()
    return PQ:GetModule("Waypoint")
end

function ClassicHUDMarker:SetCVarState(active)
    active = active and true or false
    if active == self.cvarsActive then
        return
    end
    if Client.SetClassicAPIHudCVars(active) then
        self.cvarsActive = active
    end
end

function ClassicHUDMarker:Hide(reason)
    self.contextReason = reason or self.contextReason
    local waypoint = Waypoint()
    if waypoint then
        waypoint:Hide(reason)
    end
    self.shownSourceType = nil
    self.shownSourceId = nil
end

function ClassicHUDMarker:RefreshContext()
    self.context = nil
    local config = Config()
    if not config or not config:Get("waypointEnabled") then
        self.contextReason = "disabled"
        self:SetCVarState(false)
        return
    end

    local mainQuest = MainQuest()
    local quest = mainQuest and mainQuest:GetQuest()
    if not quest then
        self.contextReason = "noMainQuest"
        return
    end

    local mapContext = PQ:GetModule("MapContext")
    local areaId = mapContext and mapContext:GetCurrentZoneView()
    if not areaId then
        self.contextReason = "noZoneView"
        return
    end

    local questTarget = PQ:GetModule("QuestTarget")
    local target, reason = questTarget and questTarget:Resolve(quest, areaId)
    if questTarget and not target and reason == "noLocationsInArea" then
        target, reason = questTarget:ResolveNearby(quest, areaId)
    end
    if not target then
        self.contextReason = reason or "noTarget"
        return
    end
    self.contextReason = nil
    self.context = target
end

function ClassicHUDMarker:RefreshMarker()
    local context = self.context
    if not context then
        self:SetCVarState(false)
        return self:Hide(self.contextReason or "noContext")
    end

    local plate, unitId = Client.FindClassicAPIQuestNameplate(context.unitIds)
    if plate then
        self:SetCVarState(true)
        local waypoint = Waypoint()
        local frame = waypoint and waypoint:GetFrame()
        if not frame then
            return self:Hide("noMarkerFrame")
        end
        Client.SetWaypointLabel(frame, "")
        Client.SetWaypointAlpha(frame, 1)
        if context.complete then
            Client.SetWaypointColor(frame, 0.2, 1, 0.2)
        else
            Client.SetWaypointColor(frame, 1, 1, 1)
        end
        if Client.AnchorWaypointMarker(frame, plate) then
            waypoint.shown = true
            waypoint.hiddenReason = nil
            self.shownSourceType = "unit"
            self.shownSourceId = unitId
            return
        end
    end

    self:Hide("noVisibleNameplate")
    local sourceType, sourceId = Client.GetClassicAPISoftInteract()
    local matches = sourceId and ((sourceType == "unit" and context.unitIds[sourceId])
        or (sourceType == "object" and context.objectIds[sourceId]))
    self:SetCVarState(true)
    if matches then
        self.shownSourceType = sourceType
        self.shownSourceId = sourceId
    end
end

function ClassicHUDMarker:OnEnable()
    if not PQ:IsFeatureEnabled("hudWorldMarker")
        or not PQ:IsFeatureEnabled("mainQuestWaypoint") then
        return
    end
    local detected = Client.GetClassicAPIStatus()
    -- With PandaTool, Waypoint projects the area centre itself and owns the
    -- shared marker frame.
    if not detected or Client.HasCameraProjection() then
        return
    end
    local driver = PQ:GetModule("Driver")
    if not driver then
        return
    end
    driver:Schedule("hud.classiccontext", 0.25, function()
        ClassicHUDMarker:RefreshContext()
    end)
    driver:Schedule("hud.classicmarker", 0.10, function()
        ClassicHUDMarker:RefreshMarker()
    end)
    local mainQuest = MainQuest()
    if mainQuest then
        mainQuest:AddListener(function()
            driver:Wake("hud.classiccontext")
            driver:Wake("hud.classicmarker")
        end)
    end
end
