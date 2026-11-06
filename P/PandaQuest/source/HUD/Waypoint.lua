--[[
PandaQuest / HUD/Waypoint.lua

The world waypoint marker: one icon over the 3D world showing which way to walk
to reach the main quest, and how far it is.

## What this is, and what it deliberately is not

It is a **yaw projection of a world point onto the screen**. The target's
bearing is compared against the player's facing, and the difference is mapped
through the horizontal field of view onto a screen X offset, so the marker sits
over the point on the horizon where the target lies. Turn left and it slides
right; put the target behind you and it pins to the screen edge.

Stock Octo has no camera getter, so that yaw marker cannot follow camera
tilt or zoom (`camera.pitch_not_readable_octo`). With the optional PandaTool
DLL (PANDATOOL_VERSION >= 101, `cameraProjection` "detected") the marker
instead projects the quest area centre through the engine's own camera
(`PlaceProjected`, `dll.pandatool_camera_projection`); the yaw marker stays as
the fallback. Without PandaTool the marker keeps its own `hudWorldMarker` gate.

## Where the facing comes from, and the one limit left

`GetPlayerFacing()` -- the character's rotation in radians, documented on the
updated client. This layer was gated off from 2026-08-22 to 2026-09-01 for the
want of exactly that call: the preceding build published no facing by any
route, so the marker could only be aimed from the direction the player was
*travelling*, which says nothing while they stand still and turn. HUD/PlayerHeading.lua
keeps that movement estimator as the fallback and reads the real facing first.
It also measures the client reading's angle convention against the estimator
rather than assuming it, because `GetPlayerFacing` is `documented`, not
`verified`, and a wrong zero axis would produce a marker that looks plausible
and points nowhere useful. That belongs there, not here: everything this file
receives from `PlayerHeading:Get` is already in the addon's convention.

The limit that remains is the camera, not the character. The marker is anchored
to where the **character** faces, and those agree whenever the camera sits
behind the character -- the normal case -- and drift apart while the player
holds right-mouse and looks around independently. There is no vertical
projection at all either: without camera pitch and target elevation the marker
can only sit on a fixed horizon band.

## Why the target is the map's own blue area

The point comes from Data/QuestTarget.lua, which is the same computation that
places the map's blue tiles -- not a second one. "Walk towards the blue area"
is the whole promise, so a separately derived centre that eventually disagreed
with the map would be a broken promise rather than a rounding difference.

## Why it hides more often than a Retail waypoint would

Both the map pins and this marker only work for direct coordinates in the
player's uniquely resolved current zone: child-area and continent transforms
are unmeasured on this client and Map/MapContext.lua refuses to guess them. On
top of that, GetPlayerMapPosition only projects the player while the world map
view is the player's own zone, so browsing the map to another zone takes the
player's position away with it. Every one of those exits is counted separately
in `hiddenReason`, and /pq waypoint prints the counts -- so "the marker never
appears" can be diagnosed without a screenshot.
]]

local PQ = PandaQuest
local Client = PQ.Client
local Waypoint = PQ:NewModule("Waypoint")

-- Rendering ------------------------------------------------------------------

Waypoint.MARKER_SIZE = 28
-- Horizontal field of view used to map a yaw offset onto screen X. The client
-- exposes no camera FOV (see cameraProjection), so this is a setting rather
-- than a measurement; 100 degrees matches the wide default of this client's
-- presentation closely enough that the marker sits over its target, and
-- waypointFov trims it without a code change.
Waypoint.DEFAULT_FOV_DEGREES = 100
-- Fraction of half the screen width the marker is allowed to reach before it
-- is treated as off-screen and pinned. Keeps the icon fully on screen and
-- keeps tan() away from its asymptote.
Waypoint.EDGE_FRACTION = 0.92

Waypoint.frame = nil
Waypoint.shown = false
Waypoint.createFailed = false
Waypoint.placements = 0
Waypoint.placementFailures = 0
Waypoint.hiddenReason = nil
Waypoint.hiddenCounts = {}
Waypoint.lastDistanceYards = nil
Waypoint.lastRelativeAngle = nil
Waypoint.lastClamped = false
Waypoint.context = nil
Waypoint.contextReason = nil
Waypoint.lastLabelDistance = nil
Waypoint.lastLabelDirection = nil
Waypoint.lastLabelStale = nil
Waypoint.projectedDistanceYards = nil
Waypoint.halfFov = nil
Waypoint.halfScreenWidth = nil
Waypoint.verticalOffset = nil

-- PandaTool camera projection (Client.HasCameraProjection). One reused table:
-- RefreshContext fills it; the render-frame path reads it without allocating.
-- Inset from the screen edge for a pinned marker, in marker units.
Waypoint.EDGE_INSET = 40
-- C_Map's player position must land this close to UnitPosition, yards.
Waypoint.WORLD_CHECK_YARDS = 10
-- A zone-yards target re-anchored on UnitPosition drifts by more than this
-- only when the zone size disagrees with the world.
Waypoint.REANCHOR_YARDS = 3
Waypoint.projection = {
    available = false,
    ready = false,
    reason = nil,
    areaId = nil,
    targetX = nil,
    targetY = nil,
    posY = nil,
    posX = nil,
    groundZ = nil,
    source = nil,
    checkError = nil,
    maxDrift = 0,
    width = nil,
    height = nil,
    scale = nil,
    placements = 0,
    failures = 0,
    lastVisible = nil,
    lastX = nil,
    lastY = nil,
}

local RAD_PER_DEGREE = 0.017453292519943

local function Config()
    return PQ:GetModule("Config")
end

local function MainQuest()
    return PQ:GetModule("MainQuest")
end

local function MapContext()
    return PQ:GetModule("MapContext")
end

local function QuestTarget()
    return PQ:GetModule("QuestTarget")
end

local function GetPlayerHeading()
    return PQ:GetModule("PlayerHeading")
end

-- Records why the marker is not on screen. Counted rather than logged: the
-- distinction between "no main quest", "quest is in another zone" and "no
-- facing source" needs to survive to a /pq waypoint read-out, and a chat line
-- at 20Hz would not.
function Waypoint:Hide(reason)
    self.hiddenReason = reason
    if reason then
        self.hiddenCounts[reason] = (self.hiddenCounts[reason] or 0) + 1
    end
    if self.frame and self.shown then
        Client.HideObject(self.frame)
        self.shown = false
    end
end

function Waypoint:GetFrame()
    if self.frame or self.createFailed then
        return self.frame
    end
    -- The widget name must never contain a hyphen: this client rewrites "-" in
    -- widget names into a filler string.
    self.frame = Client.CreateWaypointMarker("PandaQuestWaypointMarker", self.MARKER_SIZE)
    if not self.frame then
        self.createFailed = true
        PQ:Debug("waypoint marker could not be created")
    end
    return self.frame
end

-- Projection -----------------------------------------------------------------

-- Maps a yaw offset onto a screen X offset from the centre.
--
-- Positive `relative` means the target is to the player's LEFT (the angle
-- convention increases towards west, and west is left when facing north), so
-- the screen offset is its negation. Within the field of view the mapping is
-- the true perspective one, x = halfWidth * tan(angle) / tan(halfFov), which
-- is what makes the marker sit over its target rather than merely lean the
-- right way. Beyond it, or anywhere behind the player, the marker pins to the
-- edge -- tan() is worthless past a quarter turn and the target is not on
-- screen to sit over anyway.
--
-- Returns offsetX, clamped.
function Waypoint:ProjectToScreen(relative, halfWidth, halfFovRadians)
    local screenAngle = -relative
    local limit = halfWidth * self.EDGE_FRACTION

    if screenAngle >= halfFovRadians then
        return limit, true
    end
    if screenAngle <= -halfFovRadians then
        return -limit, true
    end

    local denominator = math.tan(halfFovRadians)
    if denominator == 0 then
        return 0, true
    end
    local offset = halfWidth * math.tan(screenAngle) / denominator
    if offset > limit then
        return limit, true
    end
    if offset < -limit then
        return -limit, true
    end
    return offset, false
end

local function FovRadians()
    local config = Config()
    local degrees = config and config:Get("waypointFov")
    if type(degrees) ~= "number" or degrees < 30 or degrees > 170 then
        degrees = Waypoint.DEFAULT_FOV_DEGREES
    end
    return degrees * RAD_PER_DEGREE * 0.5
end

local function VerticalOffset(screenHeight)
    local config = Config()
    local fraction = config and config:Get("waypointHeight")
    if type(fraction) ~= "number" or fraction < -0.5 or fraction > 0.5 then
        fraction = 0.18
    end
    return screenHeight * fraction
end

-- Formats the distance the way a player reads it, and carries the direction
-- hint in the same string rather than in a second texture. One texture with
-- two states is the idiom the map's "?" pin already uses, and it means there
-- is no second asset that can fail to load.
local function FormatLabel(distanceYards, clamped, offsetX, stale)
    local text
    if type(distanceYards) == "number" then
        if distanceYards >= 1000 then
            text = PQ.L("WAYPOINT_DISTANCE_KILOYARDS",
                string.format("%.1f", distanceYards / 1000))
        else
            -- Floored before formatting rather than handed to "%d" as a
            -- float. Vanilla's Lua tolerates that; newer ones raise "number
            -- has no integer representation", and the offline test runs on a
            -- newer one -- so this is the portable spelling as well as the
            -- correct rounding for a distance readout.
            text = PQ.L("WAYPOINT_DISTANCE_YARDS", tostring(math.floor(distanceYards)))
        end
    else
        text = ""
    end
    if clamped then
        if offsetX < 0 then
            text = "<< " .. text
        else
            text = text .. " >>"
        end
    end
    if stale and text ~= "" then
        text = text .. " ?"
    end
    return text
end

-- The refresh ----------------------------------------------------------------
--
-- Separate context, state and render cadences are a performance requirement.
--
-- RefreshContext resolves the map view and the quest's target point. Both are
-- expensive: MapContext:Inspect allocates a report and makes about eight
-- guarded client calls, and QuestTarget:Resolve reduces up to 200 spawn
-- locations to cells and flood-fills them into components. Neither changes
-- between two frames -- only when the quest, the zone or the player's bags do.
--
-- RefreshMarker runs at 20Hz and does the cheap state half: one position read,
-- one facing read and the distance/label arithmetic. With PandaTool,
-- RefreshProjectedMarker reuses that state and does only WorldToScreen plus
-- the changed SetPoint on every rendered frame.
--
-- Doing the expensive half at 20Hz is precisely the per-tick burst of guarded
-- calls and allocations that docs/ARCHITECTURE.md records as having been
-- reported as visible stuttering on this client.

function Waypoint:RefreshContext()
    self.context = nil
    self.projectedDistanceYards = nil

    local config = Config()
    if config and not config:Get("waypointEnabled") then
        self.contextReason = "disabled"
        return
    end

    -- Cached here rather than read per tick: config lookups and client calls
    -- that cannot change between two frames.
    self.halfFov = FovRadians()
    local screenWidth, screenHeight = Client.GetScreenSize()
    if not screenWidth then
        self.contextReason = "noScreenSize"
        return
    end
    self.halfScreenWidth = screenWidth * 0.5
    self.verticalOffset = VerticalOffset(screenHeight)

    local mainQuest = MainQuest()
    if not mainQuest or not mainQuest:Get() then
        self.contextReason = "noMainQuest"
        return
    end
    local quest = mainQuest:GetQuest()
    if not quest then
        self.contextReason = "questNotInLog"
        return
    end
    if type(quest.questId) ~= "number" then
        self.contextReason = "questUnmatched"
        return
    end

    local mapContext = MapContext()
    if not mapContext then
        self.contextReason = "noMapContext"
        return
    end
    -- The same gate the map pins use: a uniquely resolved player area, and a
    -- view that can actually project the player. Sharing it is what keeps the
    -- marker and the blue tiles agreeing about when a quest is locatable.
    local areaId, zoneReport, why = mapContext:GetCurrentZoneView()
    if not areaId then
        self.contextReason = why or "noZoneView"
        return
    end

    local questTarget = QuestTarget()
    if not questTarget then
        self.contextReason = "noQuestTarget"
        return
    end
    local target, targetWhy = questTarget:Resolve(quest, areaId)
    -- Recorded on a neighbouring zone's map but inside this one.
    if not target and targetWhy == "noLocationsInArea" then
        target, targetWhy = questTarget:ResolveNearby(quest, areaId,
            zoneReport.playerX * 100, zoneReport.playerY * 100)
    end
    if not target then
        self.contextReason = targetWhy or "noTarget"
        return
    end

    -- The area has to carry recorded dimensions or neither the bearing nor the
    -- distance can be trusted. Refusing here rather than falling back to raw
    -- map percentages keeps a skewed arrow off the screen: percentages are not
    -- isotropic, so an angle taken from them is wrong by up to about 19
    -- degrees at the diagonals.
    if not questTarget:ToYards(areaId, 1, 1) then
        self.contextReason = "noZoneDimensions"
        return
    end

    self.contextReason = nil
    self.context = {
        areaId = areaId,
        targetX = target.x,
        targetY = target.y,
        complete = target.complete,
    }
    self:RefreshProjection(self.context)
end

-- Resolves the quest area centre in world yards for PandaTool. The target is
-- fixed, so the conversion runs once per target; ground Z is retried until the
-- terrain under it answers (GetGroundZ is nil on unloaded terrain).
function Waypoint:RefreshProjection(context)
    local p = self.projection
    p.ready = false
    p.available = Client.HasCameraProjection() and true or false
    if not p.available then
        p.reason = "noPandaTool"
        return
    end

    local playerY, playerX, playerZ, playerMap = Client.GetUnitWorldPosition("player")
    if not playerY then
        p.reason = "noUnitPosition"
        return
    end
    local playerU, playerV = Client.GetPlayerMapPosition("player")
    if not playerU then
        p.reason = "playerNotOnView"
        return
    end

    if p.areaId ~= context.areaId or p.targetX ~= context.targetX
        or p.targetY ~= context.targetY then
        p.areaId = context.areaId
        p.targetX = context.targetX
        p.targetY = context.targetY
        p.posY = nil
        p.posX = nil
        p.groundZ = nil
        p.source = nil
        p.checkError = nil
        p.maxDrift = 0

        -- ClassicAPI's map-to-world conversion, accepted only when the same
        -- conversion puts the player where UnitPosition says.
        local continent, targetY, targetX = Client.GetWorldPosFromMapPos(
            context.areaId, context.targetX / 100, context.targetY / 100)
        local playerContinent, checkY, checkX = Client.GetWorldPosFromMapPos(
            context.areaId, playerU, playerV)
        if targetY and checkY then
            local dy = checkY - playerY
            local dx = checkX - playerX
            p.checkError = math.sqrt(dy * dy + dx * dx)
            local sameMap = type(playerMap) ~= "number" or type(continent) ~= "number"
                or (continent == playerMap and playerContinent == playerMap)
            if sameMap and p.checkError <= self.WORLD_CHECK_YARDS then
                p.posY = targetY
                p.posX = targetX
                p.source = "cmap"
            end
        end
    end

    -- Fallback: the zone's WorldMapArea size in yards, anchored on the
    -- player's UnitPosition (posY grows west, posX grows north).
    if p.source ~= "cmap" then
        local questTarget = QuestTarget()
        local eastYards, southYards
        if questTarget then
            eastYards, southYards = questTarget:ToYards(context.areaId,
                context.targetX - playerU * 100, context.targetY - playerV * 100)
        end
        if not eastYards or not southYards then
            p.reason = "noZoneDimensions"
            return
        end
        local posY = playerY - eastYards
        local posX = playerX - southYards
        if p.posY then
            local dy = posY - p.posY
            local dx = posX - p.posX
            local drift = math.sqrt(dy * dy + dx * dx)
            if drift > p.maxDrift then
                p.maxDrift = drift
            end
            if drift > self.REANCHOR_YARDS then
                p.posY = posY
                p.posX = posX
                p.groundZ = nil
            end
        else
            p.posY = posY
            p.posX = posX
            p.source = "zoneYards"
        end
    end

    if not p.groundZ and playerZ then
        p.groundZ = Client.GetGroundZ(p.posY, p.posX, playerZ)
    end

    local frame = self:GetFrame()
    p.width, p.height = Client.GetWorldFrameSize()
    p.scale = frame and Client.GetWorldToFrameScale(frame)
    if not p.width or not p.scale then
        p.reason = "noWorldFrame"
        return
    end
    p.reason = nil
    p.ready = true
end

function Waypoint:RefreshMarker()
    self.projectedDistanceYards = nil
    local context = self.context
    if not context then
        return self:Hide(self.contextReason or "noContext")
    end

    -- Distance remains a 20Hz state value. Camera projection itself uses the
    -- cached world target and does not repeat this map-position call per frame.
    local playerU, playerV = Client.GetPlayerMapPosition("player")
    if not playerU then
        return self:Hide("playerNotOnView")
    end

    local questTarget = QuestTarget()
    if not questTarget then
        return self:Hide("noQuestTarget")
    end
    local eastYards, southYards = questTarget:ToYards(context.areaId,
        context.targetX - playerU * 100, context.targetY - playerV * 100)
    if not eastYards or not southYards then
        return self:Hide("noZoneDimensions")
    end

    local distanceYards = math.sqrt(eastYards * eastYards + southYards * southYards)
    if eastYards == 0 and southYards == 0 then
        -- Standing on the target. Not an error, just nothing to point at.
        self.lastDistanceYards = distanceYards
        return self:Hide("atTarget")
    end

    -- PandaTool path: the engine's own projection, so the marker follows
    -- camera yaw, tilt and zoom. Any failure falls through to the yaw marker.
    self.projectedDistanceYards = distanceYards
    if self.projection.ready and self:PlaceProjected(context, distanceYards) then
        return
    end

    -- The PandaTool path above needs no character-facing work. Resolve it only
    -- for the yaw fallback, including a transient WorldToScreen failure.
    local heading = GetPlayerHeading()
    if not heading then
        return self:Hide("noPlayerHeading")
    end
    heading:Sample(context.areaId, playerU, playerV)
    local bearing = heading.BearingFromYards(eastYards, southYards)
    if not bearing then
        return self:Hide("badAngle")
    end

    local facing, facingSource, stale = heading:Get()
    if not facing then
        return self:Hide("noFacing")
    end

    local relative = heading.NormalizeDelta(bearing - facing)
    if not relative then
        return self:Hide("badAngle")
    end

    local offsetX, clamped = self:ProjectToScreen(
        relative, self.halfScreenWidth, self.halfFov)
    local offsetY = self.verticalOffset

    local frame = self:GetFrame()
    if not frame then
        return self:Hide("noMarkerFrame")
    end
    self:Dress(frame, context, distanceYards, clamped, offsetX, stale)

    if Client.PositionWaypointMarker(frame, offsetX, offsetY) then
        self.placements = self.placements + 1
        self.shown = true
        self.hiddenReason = nil
    else
        self.placementFailures = self.placementFailures + 1
        return self:Hide("placementFailed")
    end

    self.lastDistanceYards = distanceYards
    self.lastRelativeAngle = relative
    self.lastClamped = clamped
    self.lastFacingSource = facingSource
    self.lastTargetX = context.targetX
    self.lastTargetY = context.targetY
    self.lastAreaId = context.areaId
    self.lastProjected = false
end

-- Camera motion can change between two 20Hz state samples. Reproject the
-- already-resolved world point every rendered frame without repeating map,
-- quest, position, distance or label work.
function Waypoint:RefreshProjectedMarker()
    local context = self.context
    local distanceYards = self.projectedDistanceYards
    if not context or not self.projection.ready or type(distanceYards) ~= "number" then
        return
    end
    self:PlaceProjected(context, distanceYards)
end

-- Colour, alpha and distance label, shared by both placement paths.
function Waypoint:Dress(frame, context, distanceYards, clamped, offsetX, stale)
    -- A quest ready to hand in points at its turn-in, so it wears the turn-in
    -- colour the map already uses for that: green rather than the accent.
    if context.complete then
        Client.SetWaypointColor(frame, 0.2, 1, 0.2)
    else
        Client.SetWaypointColor(frame, 1, 1, 1)
    end
    Client.SetWaypointAlpha(frame, clamped and 0.6 or 1)

    -- Keep primitive label inputs: building a string key every 20 Hz would
    -- allocate even when the visible text did not change.
    local roundedDistance = math.floor(distanceYards)
    local direction = clamped and (offsetX < 0 and -1 or 1) or 0
    local staleFlag = stale and true or false
    if roundedDistance ~= self.lastLabelDistance
        or direction ~= self.lastLabelDirection
        or staleFlag ~= self.lastLabelStale then
        self.lastLabelDistance = roundedDistance
        self.lastLabelDirection = direction
        self.lastLabelStale = staleFlag
        Client.SetWaypointLabel(frame,
            FormatLabel(distanceYards, clamped, offsetX, stale))
    end
end

-- Pins a WorldFrame offset from the screen centre to the inset rectangle,
-- along the same direction. Returns the pinned dx, dy.
function Waypoint.PinToEdge(dx, dy, limitX, limitY)
    if dx == 0 and dy == 0 then
        return 0, -limitY
    end
    local ax = dx < 0 and -dx or dx
    local ay = dy < 0 and -dy or dy
    local scale
    if ax * limitY >= ay * limitX then
        scale = limitX / ax
    else
        scale = limitY / ay
    end
    return dx * scale, dy * scale
end

-- Projects the quest area centre with PandaTool and places the marker in
-- WorldFrame space. Off screen or behind the camera (visible false), the
-- marker pins to the edge in the direction of x, y from the centre
-- (PandaTool 0.1.1 keeps x on the correct side for points behind).
-- Allocation-free: the projected path runs once per rendered frame.
function Waypoint:PlaceProjected(context, distanceYards)
    local p = self.projection
    local z = p.groundZ
    if not z then
        local _, _, playerZ = Client.GetUnitWorldPosition("player")
        z = playerZ
    end
    if not z then
        p.failures = p.failures + 1
        return false
    end
    local x, y, visible = Client.WorldToScreen(p.posY, p.posX, z)
    if not x then
        p.failures = p.failures + 1
        return false
    end
    local frame = self:GetFrame()
    if not frame then
        return false
    end

    local halfWidth = p.width * 0.5
    local halfHeight = p.height * 0.5
    local inset = self.EDGE_INSET / p.scale
    local limitX = halfWidth - inset
    local limitY = halfHeight - inset
    if limitX < 1 then
        limitX = 1
    end
    if limitY < 1 then
        limitY = 1
    end
    local dx = x - halfWidth
    local dy = y - halfHeight
    local clamped = false
    if not visible or dx > limitX or dx < -limitX or dy > limitY or dy < -limitY then
        clamped = true
        dx, dy = Waypoint.PinToEdge(dx, dy, limitX, limitY)
    end

    self:Dress(frame, context, distanceYards, clamped, dx, false)
    if not Client.PlaceWaypointMarkerOnWorld(frame,
        (halfWidth + dx) * p.scale, (halfHeight + dy) * p.scale, not self.shown) then
        p.failures = p.failures + 1
        return false
    end

    self.placements = self.placements + 1
    p.placements = p.placements + 1
    p.lastVisible = visible
    p.lastX = x
    p.lastY = y
    self.shown = true
    self.hiddenReason = nil
    self.lastDistanceYards = distanceYards
    self.lastRelativeAngle = nil
    self.lastClamped = clamped
    self.lastFacingSource = "camera"
    self.lastTargetX = context.targetX
    self.lastTargetY = context.targetY
    self.lastAreaId = context.areaId
    self.lastProjected = true
    return true
end

-- One call that resolves everything and then draws, at the cost of doing the
-- expensive half every time. Kept as the single entry point for the offline
-- test and for /pq waypoint; the driver deliberately does not use it.
function Waypoint:Refresh()
    self:RefreshContext()
    self:RefreshMarker()
end

-- Reporting ------------------------------------------------------------------

function Waypoint:GetReport()
    return {
        enabled = Config() and Config():Get("waypointEnabled") or false,
        created = self.frame ~= nil,
        createFailed = self.createFailed,
        shown = self.shown,
        placements = self.placements,
        placementFailures = self.placementFailures,
        hiddenReason = self.hiddenReason,
        hiddenCounts = self.hiddenCounts,
        distanceYards = self.lastDistanceYards,
        relativeAngle = self.lastRelativeAngle,
        clamped = self.lastClamped,
        facingSource = self.lastFacingSource,
        -- Built here rather than cached from RefreshMarker: it is a string, and
        -- building one per tick for a readout nobody reads until /pq waypoint
        -- runs is the allocation these split cadences exist to avoid.
        facingConvention = GetPlayerHeading()
            and GetPlayerHeading():ConventionLabel() or nil,
        targetX = self.lastTargetX,
        targetY = self.lastTargetY,
        areaId = self.lastAreaId,
        projected = self.lastProjected and true or false,
        projection = self.projection,
    }
end

-- Persists enough to diagnose an invisible marker from SavedVariables alone,
-- the same way mapDiagnostics does for the map layer. Written on a slow job:
-- "placed but not visible" and "never placed" are different bugs and only the
-- counters separate them.
function Waypoint:RecordDiagnostics()
    local config = Config()
    if not config then
        return
    end
    config:SetSectionEntry("waypointDiagnostics", "placements", self.placements)
    config:SetSectionEntry("waypointDiagnostics", "placementFailures", self.placementFailures)
    config:SetSectionEntry("waypointDiagnostics", "shown", self.shown and 1 or 0)
    config:SetSectionEntry("waypointDiagnostics", "createFailed", self.createFailed and 1 or 0)
    config:SetSectionEntry("waypointDiagnostics", "hiddenReason",
        tostring(self.hiddenReason or "none"))
    config:SetSectionEntry("waypointDiagnostics", "facingSource",
        tostring(self.lastFacingSource or "none"))
    -- PandaTool projection: which world conversion was used and how far its
    -- player check landed from UnitPosition, for the Octo evidence log.
    local p = self.projection
    config:SetSectionEntry("waypointDiagnostics", "projectionAvailable", p.available and 1 or 0)
    config:SetSectionEntry("waypointDiagnostics", "projectionReason", tostring(p.reason or "none"))
    config:SetSectionEntry("waypointDiagnostics", "projectionSource", tostring(p.source or "none"))
    config:SetSectionEntry("waypointDiagnostics", "projectionCheckYards", p.checkError or -1)
    config:SetSectionEntry("waypointDiagnostics", "projectionMaxDrift", p.maxDrift)
    config:SetSectionEntry("waypointDiagnostics", "projectionGroundZ", p.groundZ and 1 or 0)
    config:SetSectionEntry("waypointDiagnostics", "projectionPlacements", p.placements)
    config:SetSectionEntry("waypointDiagnostics", "projectionFailures", p.failures)
    local headingModule = GetPlayerHeading()
    if headingModule then
        config:SetSectionEntry("waypointDiagnostics", "headingSamples", headingModule.samples)
        config:SetSectionEntry("waypointDiagnostics", "movementFixes", headingModule.movementFixes)
        -- Which convention the facing was read in, persisted alongside the
        -- placement counters: "the marker appears but points the wrong way"
        -- and "the marker never appears" are different bugs, and only this
        -- line separates the first from a projection error.
        config:SetSectionEntry("waypointDiagnostics", "facingConvention",
            tostring(headingModule:ConventionLabel()))
    end
end

-- Lifecycle ------------------------------------------------------------------

function Waypoint:OnEnable()
    -- Two gates, and the second one is why this layer is quiet today.
    -- `mainQuestWaypoint` owns the follow-one-quest layer as a whole and is on;
    -- `hudWorldMarker` owns this projected marker alone and is off, so the
    -- navigator can use the same main quest, target and facing without this
    -- also drawing. Both are checked because either being off means there is
    -- nothing here to schedule.
    -- PandaTool supplies the missing camera projection, so it opens the
    -- marker's own gate; without it nothing changes.
    if not PQ:IsFeatureEnabled("mainQuestWaypoint")
        or not (PQ:IsFeatureEnabled("hudWorldMarker") or Client.HasCameraProjection()) then
        -- The expensive half of the disable. Without this the driver would run
        -- hud.waypoint forever -- reading state and re-projecting -- for a
        -- marker that is never shown.
        -- Nothing else creates the marker frame either: GetFrame is lazy and is
        -- only ever reached from RefreshMarker, which is only ever reached from
        -- the job scheduled below.
        return
    end

    local driver = PQ:GetModule("Driver")
    if not driver then
        return
    end

    local config = Config()
    local interval = config and config:Get("waypointInterval")
    if type(interval) ~= "number" or interval < 0.02 or interval > 1 then
        interval = 0.05
    end

    -- Four times a second for the expensive half. A quest's target does not
    -- move, so this only has to notice that the quest, the zone or the bags
    -- changed.
    driver:Schedule("hud.waypointcontext", 0.25, function()
        Waypoint:RefreshContext()
    end)

    if Client.HasCameraProjection() then
        -- Position, distance and labels stay throttled; only the measured
        -- zero-garbage projection and changed anchor write run every frame.
        driver:Schedule("hud.waypointstate", interval, function()
            Waypoint:RefreshMarker()
        end)
        driver:Schedule("hud.waypoint", 0, function()
            Waypoint:RefreshProjectedMarker()
        end)
    else
        driver:Unschedule("hud.waypointstate")
        driver:Schedule("hud.waypoint", interval, function()
            Waypoint:RefreshMarker()
        end)
    end

    driver:Schedule("hud.waypointdiagnostics", 5, function()
        Waypoint:RecordDiagnostics()
    end)

    -- A selection change should show the marker on the next tick, not up to
    -- one interval later. Same accelerator pattern the map layer uses.
    local mainQuest = MainQuest()
    if mainQuest then
        mainQuest:AddListener(function()
            -- A selection change invalidates the context, so wake that job:
            -- waking only the marker would redraw the previous target.
            driver:Wake("hud.waypointcontext")
            driver:Wake("hud.waypointstate")
            driver:Wake("hud.waypoint")
        end)
    end
end
