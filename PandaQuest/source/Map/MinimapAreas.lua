--[[
PandaQuest / Map/MinimapAreas.lua

The world map's quest areas, drawn on the minimap around the player.

WHAT IT DRAWS. With the Areas presentation on (mapObjectiveAreas), exactly what
the world map shows: the followed quest's area (every in-progress quest's under
"Show all areas"), plus the area of a quest hovered in the tracker or through
a minimap pin, in the lighter hover blue unless it is the followed quest. A
complete quest draws no area -- its turn-in "?" is the destination.

THE SAME SHAPES. The geometry is Map/AreaContours.lua's, read from its cache
(LayoutPatches/BuildLayout): flat-in-y, linear-in-x texture patches on the
800-cell zone grid, textured from the same profile strip. They are converted to
yards once per rebuild; each refresh only turns yards into pixels around the
player, the same arithmetic MinimapPins:Project uses for the dots.

CLIPPED TO THE MINIMAP SHAPE. Nothing clips a child of Minimap on this client
(minimap.addon_children_render_unclipped), so a patch left as computed would
be drawn over the rest of the UI. There is no mask to lean on, so every patch
is clipped here before it is placed. PandaUI's public Circle/Square setting
selects a rectangle or the established circle:
  * a patch entirely outside is not drawn;
  * a patch entirely inside is drawn as it is;
  * a patch crossing a square edge is trimmed to that rectangle;
  * a patch crossing the rim is cut into horizontal strips at most STRIP_HEIGHT
    pixels tall, and each strip is trimmed to the circle's chord at the strip's
    OUTER edge -- the narrowest chord inside the strip -- so no strip can reach
    past the rim. A patch's texture is constant in y and linear in x, so a
    trimmed strip keeps its exact texels by interpolating u across the cut.
The edge is therefore exact to within one strip (about a pixel), and nothing
is ever drawn outside the circle.

MOVED BY ONE FRAME. A patch wholly inside the circle owns its texture and is
anchored once to MinimapPins' origin frame (Client.CreateMinimapPinOrigin) at
its fixed yard position; walking moves the origin, not the patches. Only the
rim strips depend on where the player stands, and they too ride the origin
between clips, so the clip itself is redone only once the player has moved
MOVE_PIXELS: until then everything has shifted by less than EDGE_MARGIN and
still lies inside the minimap. Before this every patch was re-anchored,
resized and re-shown on each 0.1 s pass while walking -- about 250 textures,
most of the walking cost in pandaquest.minimap_zoom_probe_hitch. Without an
origin each pass re-clips as before.

Geometry that is not yet in the cache is built on the shared driver in bounded
grid-row slices, like the world map's, so a rebuild never computes every area
in one frame.
]]

local PQ = PandaQuest
local Client = PQ.Client
local MinimapAreas = PQ:NewModule("MinimapAreas")

-- The tallest strip a rim-crossing patch is cut into, in minimap pixels.
local STRIP_HEIGHT = 1.5
-- Kept inside the rim, like the pins' CLAMP_MARGIN, so the soft outer glow
-- never sits on the minimap's border art.
local EDGE_MARGIN = 2
-- How far, in minimap pixels, the player may move before the rim is clipped
-- again. Must stay below EDGE_MARGIN so a patch never leaves the minimap.
local MOVE_PIXELS = 1
-- The lighter blue a hovered area takes unless it is the followed quest's,
-- the same tint as the world map's AREA_HOVER_RGB.
local HOVER_RED, HOVER_GREEN, HOVER_BLUE = 0.45, 0.82, 1

MinimapAreas.entries = {}
-- Every texture created, in creation order. A texture either belongs to the
-- rim-strip pool (`strips`, reused in order on every clip) or is handed to
-- one record at a time from `free`.
MinimapAreas.textures = {}
MinimapAreas.strips = {}
MinimapAreas.free = {}
MinimapAreas.stripsShown = 0
MinimapAreas.clip = 0
-- What the last clip was drawn with; the drawn quests are compared in place.
MinimapAreas.drawEntries = {}
MinimapAreas.drawTinted = {}
MinimapAreas.drawCount = 0
MinimapAreas.visible = 0
MinimapAreas.buildQueue = {}
MinimapAreas.serial = 0

local function Contours()
    return PQ:GetModule("AreaContours")
end

function MinimapAreas:Enabled(config)
    config = config or PQ:GetModule("Config")
    return config and config:Get("mapObjectiveAreas") and true or false
end

-- Grid patches -> yard rectangles with their u range, plus the bounds of the
-- whole quest, so a quest far from the player is skipped in one test.
local function ToYards(entry, patches, widthYards, heightYards)
    local contours = Contours()
    local grid = contours.GRID
    local scaleX = widthYards / grid
    local scaleY = heightYards / grid
    local records = {}
    local minX, minY, maxX, maxY = nil, nil, nil, nil
    local index = 1
    local total = table.getn(patches)
    while index <= total do
        local patch = patches[index]
        local left = math.max(0, patch[1])
        local top = math.max(0, patch[2])
        local right = math.min(grid, patch[3])
        local bottom = math.min(grid, patch[4])
        if right > left and bottom > top then
            local record = {
                left * scaleX, top * scaleY, right * scaleX, bottom * scaleY,
                contours.ProfileU(patch[5]), contours.ProfileU(patch[6]),
            }
            table.insert(records, record)
            if not minX or record[1] < minX then minX = record[1] end
            if not minY or record[2] < minY then minY = record[2] end
            if not maxX or record[3] > maxX then maxX = record[3] end
            if not maxY or record[4] > maxY then maxY = record[4] end
        end
        index = index + 1
    end
    entry.records = records
    entry.minX, entry.minY, entry.maxX, entry.maxY = minX, minY, maxX, maxY
end

local function RunBuildQueue()
    local self = MinimapAreas
    local contours = Contours()
    if contours and table.getn(self.buildQueue) > 0 then
        local entry = table.remove(self.buildQueue, 1)
        if entry.serial == self.serial and not entry.records then
            local patches = contours.patchCache[entry.key]
            if not patches then
                local build = entry.build
                if not build then
                    build, patches = contours:BeginLayoutBuild(
                        entry.key, entry.ordered)
                    entry.build = build
                end
                if not patches then
                    local done
                    done, patches = contours:StepLayoutBuild(
                        build, contours.BUILD_ROWS_PER_TICK)
                    if not done then
                        table.insert(self.buildQueue, entry)
                    end
                end
            end
            if patches then
                ToYards(entry, patches, entry.widthYards, entry.heightYards)
                self.lastProjectKey = nil
            end
        end
    end
    if table.getn(self.buildQueue) == 0 then
        local driver = PQ:GetModule("Driver")
        if driver then
            driver:Unschedule("map.minimapareas.build")
        end
    end
end

-- Called by MinimapPins:BuildTargets with the scene it just collected. Every
-- in-progress quest is kept (hover can reveal any of them); which ones are
-- drawn is decided per refresh in Project.
function MinimapAreas:Rebuild(quests, areaId, widthYards, heightYards, config)
    self:HideAll()
    self.serial = self.serial + 1
    self.entries = {}
    self.buildQueue = {}
    self.lastProjectKey = nil
    local contours = Contours()
    local worldMap = PQ:GetModule("WorldMapPins")
    if not self:Enabled(config) or not contours or not worldMap
        or type(widthYards) ~= "number" or type(heightYards) ~= "number" then
        return
    end
    local driver = PQ:GetModule("Driver")
    local index = 1
    local total = table.getn(quests or {})
    while index <= total do
        local quest = quests[index]
        if quest and quest.isComplete ~= 1 then
            local locations = worldMap:CollectQuestLocations(quest, areaId, false, config)
            if table.getn(locations) > 0 then
                local patches, key, ordered = contours:LayoutPatches(quest, areaId, locations)
                local entry = { quest = quest, serial = self.serial }
                if patches then
                    ToYards(entry, patches, widthYards, heightYards)
                elseif driver and Client.Now() then
                    entry.key, entry.ordered = key, ordered
                    entry.widthYards, entry.heightYards = widthYards, heightYards
                    table.insert(self.buildQueue, entry)
                else
                    ToYards(entry, contours:BuildLayout(key, ordered), widthYards, heightYards)
                end
                table.insert(self.entries, entry)
            end
        end
        index = index + 1
    end
    if driver and table.getn(self.buildQueue) > 0 then
        driver:Schedule("map.minimapareas.build", 0, RunBuildQueue)
    end
end

function MinimapAreas:GetGroup()
    if not self.group then
        self.group = Client.CreateMinimapAreaGroup()
    end
    return self.group
end

local function NewTexture(self)
    local texture = Client.CreateMinimapAreaPatch(self:GetGroup())
    if texture then
        table.insert(self.textures, texture)
    end
    return texture
end

-- Hides every texture and takes every record's texture back. table.insert and
-- table.remove only, so table.getn stays right on Lua 5.0.
function MinimapAreas:HideAll()
    self.lastProjectKey = nil
    if self.visible == 0 then
        return
    end
    while table.getn(self.free) > 0 do
        table.remove(self.free)
    end
    local index = 1
    local total = table.getn(self.textures)
    while index <= total do
        local texture = self.textures[index]
        Client.HideMinimapAreaPatch(texture)
        local record = texture.pandaQuestAreaRecord
        if record then
            record.texture = nil
            texture.pandaQuestAreaRecord = nil
        end
        if not texture.pandaQuestAreaStrip then
            table.insert(self.free, texture)
        end
        index = index + 1
    end
    self.stripsShown = 0
    self.visible = 0
end

-- One patch wholly inside the circle, in its record's own texture. The
-- offsets are fixed relative to the origin, so the setters skip every write
-- while the player walks.
function MinimapAreas:PlaceRecord(record, left, top, right, bottom, path,
    red, green, blue, origin)
    local texture = record.texture
    if not texture then
        texture = table.remove(self.free) or NewTexture(self)
        if not texture then
            return false
        end
        record.texture = texture
        texture.pandaQuestAreaRecord = record
    end
    texture.pandaQuestAreaClip = self.clip
    return Client.PlaceMinimapAreaPatch(texture, path, left, top,
        right - left, top - bottom, record[5], record[6], 0.25, 0.75,
        red, green, blue, origin)
end

function MinimapAreas:PlaceStrip(used, left, top, right, bottom, u1, u2, path,
    red, green, blue, origin)
    local texture = self.strips[used]
    if not texture then
        texture = NewTexture(self)
        if not texture then
            return used
        end
        texture.pandaQuestAreaStrip = true
        self.strips[used] = texture
    end
    if Client.PlaceMinimapAreaPatch(texture, path, left, top, right - left,
            top - bottom, u1, u2, 0.25, 0.75, red, green, blue, origin) then
        return used + 1
    end
    return used
end

-- Draws one yard rectangle around the player, clipped to the circle of
-- `radius`. Pixel y runs up, so top > bottom. The test is made around the
-- player; the texture is placed around the origin, `shiftX`/`shiftY` pixels
-- from the player (zero without an origin). Returns the next free strip.
function MinimapAreas:DrawRecord(used, record, playerX, playerY, pixelsPerYard,
    radius, square, halfWidth, halfHeight, path, red, green, blue, origin,
    shiftX, shiftY)
    local left = (record[1] - playerX) * pixelsPerYard
    local right = (record[3] - playerX) * pixelsPerYard
    local top = -(record[2] - playerY) * pixelsPerYard
    local bottom = -(record[4] - playerY) * pixelsPerYard
    local u1, u2 = record[5], record[6]
    if square then
        local clipLeft = math.max(left, -halfWidth)
        local clipRight = math.min(right, halfWidth)
        local clipTop = math.min(top, halfHeight)
        local clipBottom = math.max(bottom, -halfHeight)
        if clipRight <= clipLeft or clipTop <= clipBottom then
            return used
        end
        if clipLeft == left and clipRight == right
            and clipTop == top and clipBottom == bottom then
            if origin then
                left = record[1] * pixelsPerYard
                right = record[3] * pixelsPerYard
                top = -record[2] * pixelsPerYard
                bottom = -record[4] * pixelsPerYard
            end
            self:PlaceRecord(record, left, top, right, bottom, path, red, green,
                blue, origin)
            return used
        end
        local width = right - left
        local stripU1 = u1 + (u2 - u1) * (clipLeft - left) / width
        local stripU2 = u1 + (u2 - u1) * (clipRight - left) / width
        return self:PlaceStrip(used, clipLeft + shiftX, clipTop + shiftY,
            clipRight + shiftX, clipBottom + shiftY, stripU1, stripU2, path,
            red, green, blue, origin)
    end
    local r2 = radius * radius
    -- Nearest point of the rectangle to the centre: outside the circle means
    -- nothing of it is visible.
    local nearX, nearY = 0, 0
    if left > 0 then nearX = left elseif right < 0 then nearX = right end
    if bottom > 0 then nearY = bottom elseif top < 0 then nearY = top end
    if nearX * nearX + nearY * nearY >= r2 then
        return used
    end
    local farX = math.max(math.abs(left), math.abs(right))
    local farY = math.max(math.abs(top), math.abs(bottom))
    if farX * farX + farY * farY <= r2 then
        if origin then
            -- Straight from yards, not player-relative plus shift: the same
            -- record must land on bit-identical offsets on every clip.
            left = record[1] * pixelsPerYard
            right = record[3] * pixelsPerYard
            top = -record[2] * pixelsPerYard
            bottom = -record[4] * pixelsPerYard
        end
        self:PlaceRecord(record, left, top, right, bottom, path, red, green, blue, origin)
        return used
    end
    local width = right - left
    local y = top
    while y > bottom do
        local lower = y - STRIP_HEIGHT
        if lower < bottom then lower = bottom end
        -- The chord is narrowest at the strip edge farthest from the centre.
        local outer = math.max(math.abs(y), math.abs(lower))
        if outer < radius then
            local half = math.sqrt(r2 - outer * outer)
            local clipLeft = math.max(left, -half)
            local clipRight = math.min(right, half)
            if clipRight > clipLeft then
                local stripU1 = u1 + (u2 - u1) * (clipLeft - left) / width
                local stripU2 = u1 + (u2 - u1) * (clipRight - left) / width
                used = self:PlaceStrip(used, clipLeft + shiftX, y + shiftY,
                    clipRight + shiftX, lower + shiftY, stripU1, stripU2,
                    path, red, green, blue, origin)
            end
        end
        y = lower
    end
    return used
end

-- Fills drawEntries/drawTinted with the quests to draw and says whether the
-- list differs from the last one. Allocation-free: this runs on every pass.
function MinimapAreas:SelectDrawn(owner, mainQuest, showAll)
    local changed = false
    local count = 0
    local index = 1
    local total = table.getn(self.entries)
    while index <= total do
        local entry = self.entries[index]
        local quest = entry.quest
        local followed = mainQuest and quest.titleKey and mainQuest:IsMain(quest.titleKey) or false
        local hovered = owner and owner:IsQuestAreaHovered(quest) or false
        if entry.records and (followed or showAll or hovered) then
            local tinted = hovered and not followed and true or false
            count = count + 1
            if self.drawEntries[count] ~= entry or self.drawTinted[count] ~= tinted then
                self.drawEntries[count] = entry
                self.drawTinted[count] = tinted
                changed = true
            end
        end
        index = index + 1
    end
    if count ~= self.drawCount then
        changed = true
        index = count + 1
        while index <= self.drawCount do
            self.drawEntries[index] = nil
            self.drawTinted[index] = nil
            index = index + 1
        end
        self.drawCount = count
    end
    return changed
end

-- Called at the end of every MinimapPins:Project. `owner` answers which quest
-- is hovered (MinimapPins:IsQuestAreaHovered); `origin` is the frame the pins
-- ride (nil without one). Skipped entirely while nothing it depends on has
-- changed and the player has moved less than MOVE_PIXELS since the last clip,
-- which is most refreshes, walking or not.
function MinimapAreas:Project(playerX, playerY, pixelsPerYard, halfSize,
    owner, mainQuest, showAll, origin, width, height)
    local radius = halfSize - EDGE_MARGIN
    local square = Client.IsMinimapSquare()
    local halfWidth, halfHeight = radius, radius
    if square then
        width = width or halfSize * 2
        height = height or halfSize * 2
        halfWidth, halfHeight = Client.GetMinimapClipBounds(width, height,
            EDGE_MARGIN, true)
    end
    if radius <= 0 or halfWidth <= 0 or halfHeight <= 0
        or table.getn(self.entries) == 0 then
        self:HideAll()
        return
    end
    -- Which quests are drawn, and how, is part of the key: a hover or a
    -- follow change redraws even when the player has not moved.
    local changed = self:SelectDrawn(owner, mainQuest, showAll)
    if not changed and self.lastProjectKey and self.lastSerial == self.serial
        and self.lastPixelsPerYard == pixelsPerYard and self.lastRadius == radius
        and self.lastSquare == square and self.lastHalfWidth == halfWidth
        and self.lastHalfHeight == halfHeight and self.lastOrigin == (origin or false) then
        local dx = (playerX - self.lastPlayerX) * pixelsPerYard
        local dy = (playerY - self.lastPlayerY) * pixelsPerYard
        if origin then
            if dx * dx + dy * dy < MOVE_PIXELS * MOVE_PIXELS then
                return
            end
        elseif dx == 0 and dy == 0 then
            return
        end
    end
    self.clip = self.clip + 1
    self.lastProjectKey = self.clip
    self.lastSerial = self.serial
    self.lastPixelsPerYard = pixelsPerYard
    self.lastRadius = radius
    self.lastSquare = square
    self.lastHalfWidth, self.lastHalfHeight = halfWidth, halfHeight
    self.lastOrigin = origin or false
    self.lastPlayerX, self.lastPlayerY = playerX, playerY

    local shiftX, shiftY = 0, 0
    if origin then
        shiftX = playerX * pixelsPerYard
        shiftY = -playerY * pixelsPerYard
    end
    local reachX = halfWidth / pixelsPerYard
    local reachY = halfHeight / pixelsPerYard
    local used = 1
    local index = 1
    local total = self.drawCount
    while index <= total do
        local entry = self.drawEntries[index]
        -- The whole quest outside the active shape's bounding rectangle: skip it.
        if entry.minX and entry.maxX >= playerX - reachX and entry.minX <= playerX + reachX
            and entry.maxY >= playerY - reachY and entry.minY <= playerY + reachY then
            local path, red, green, blue = Client.WORLD_MAP_AREA_CONTOUR_TEXTURE, 1, 1, 1
            if self.drawTinted[index] then
                path = Client.WORLD_MAP_AREA_CONTOUR_NEUTRAL_TEXTURE
                red, green, blue = HOVER_RED, HOVER_GREEN, HOVER_BLUE
            end
            local records = entry.records
            local recordIndex = 1
            local recordTotal = table.getn(records)
            while recordIndex <= recordTotal do
                used = self:DrawRecord(used, records[recordIndex], playerX, playerY,
                    pixelsPerYard, radius, square, halfWidth, halfHeight, path,
                    red, green, blue, origin, shiftX, shiftY)
                recordIndex = recordIndex + 1
            end
        end
        index = index + 1
    end
    -- Records this clip did not draw give their texture back.
    local owned = 0
    index = 1
    total = table.getn(self.textures)
    while index <= total do
        local texture = self.textures[index]
        local record = texture.pandaQuestAreaRecord
        if record then
            if texture.pandaQuestAreaClip == self.clip then
                owned = owned + 1
            else
                Client.HideMinimapAreaPatch(texture)
                record.texture = nil
                texture.pandaQuestAreaRecord = nil
                table.insert(self.free, texture)
            end
        end
        index = index + 1
    end
    index = used
    while index <= self.stripsShown do
        Client.HideMinimapAreaPatch(self.strips[index])
        index = index + 1
    end
    self.stripsShown = used - 1
    self.visible = owned + self.stripsShown
end

function MinimapAreas:GetStatus()
    return {
        quests = table.getn(self.entries),
        pending = table.getn(self.buildQueue),
        patches = self.visible,
        rimStrips = self.stripsShown,
        clips = self.clip,
    }
end
