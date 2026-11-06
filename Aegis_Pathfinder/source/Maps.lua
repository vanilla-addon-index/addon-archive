--[[ Maps.lua -- the options' Maps page: what Pathfinder draws on the world
	map and the minimap.

	  * Reveal the whole map: the places you have not been, drawn dimmer, from
	    pfUI's reveal data (MapOverlays.lua). Held off while pfUI's own reveal
	    is on, or Cartographer or MetaMap's fog of war module draws them.
	  * The step on the map: the current step's quest givers, hand-ins and kill
	    areas, from pfQuest's database, and the place its note gives -- on the
	    zone you are looking at.
	  * An ant trail from you to the waypoint: dots or dashes marching toward
	    it on the world map, and on the minimap when Astrolabe is loaded
	    (TomTom-TWOW brings it), which knows how far the minimap reaches.
	  * Points of interest: the rare creatures within a few levels of yours,
	    where they can spawn (Rares.lua). Whether one is up, 1.12 cannot say.

	All of it on the zone's own map; nothing across zones or continents.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme
local L = AegisPathfinder.Locale

local Maps = {}
AegisPathfinder.Maps = Maps

-- Layout and limits, in one table (the 32-upvalue note in CONTRIBUTING.md).
local M = {
	TILE = 256, DIM = 0.55,                 -- the unexplored, a little dimmer
	MARKERS = 60, KILL_SPOTS = 25, GIVER_SPOTS = 3,
	PIN = 14, SPOT = 7,
	DOT_GAP = 14, DOT = 5, DASH_GAP = 4, DASH = 4, TRAIL_MAX = 160, MARCH = 1.2,
	MINI_DOTS = 8, MINI_FILL = 0.85, MINI_DOT = 4, MINI_EVERY = 0.4,
	RARE_PIN = 16, RARE_BELOW = 4, RARE_ABOVE = 4,
	EVERY = 0.1,
}
-- The minimap's diameter, in yards, at each zoom: Astrolabe's own table.
M.OUTDOOR = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
M.INDOOR = { [0] = 300, 240, 180, 120, 80, 50 }

local function Settings() return AegisPathfinder.db and AegisPathfinder.db.profile end

--- The zone the world map shows, by name; nil on a continent or the world.
function Maps.ShownZone()
	local c, z = GetCurrentMapContinent(), GetCurrentMapZone()
	if not c or c < 1 or not z or z < 1 then return end
	return (AegisPathfinder.select(z, GetMapZones(c)))
end

--[[ Revealing the map --------------------------------------------------------------- ]]

--- Another addon drawing the unexplored parts already: pfUI with its reveal
--- on, Cartographer (its Foglight), MetaMap's fog of war module.
function Maps.OtherReveal()
	if Cartographer or (IsAddOnLoaded and IsAddOnLoaded("MetaMapFWM")) then return true end
	local wm = pfUI and pfUI.mapreveal and pfUI_config and pfUI_config.appearance
		and pfUI_config.appearance.worldmap
	return wm and wm.mapreveal == "1" or false
end

-- The `i`th tile of our own, on the map's detail frame.
local function Tile(i)
	local t = Maps.tiles[i]
	if not t then
		t = WorldMapDetailFrame:CreateTexture(nil, "ARTWORK")
		Maps.tiles[i] = t
	end
	return t
end

-- The smallest power of two a texture file of `n` pixels is stored in.
local function FileSize(n)
	local f = 16
	while f < n do f = f * 2 end
	return f
end

--- One overlay, as the client draws an explored one: 256-pixel tiles, the
--- last of each row and column cut to fit. Returns how many tiles are in use.
function Maps:DrawOverlay(path, w, h, x, y, used)
	local across, down = math.ceil(w / M.TILE), math.ceil(h / M.TILE)
	for j = 1, down do
		local ph = j < down and M.TILE or (math.mod(h, M.TILE) == 0 and M.TILE or math.mod(h, M.TILE))
		local fh = j < down and M.TILE or FileSize(ph)
		for k = 1, across do
			local pw = k < across and M.TILE or (math.mod(w, M.TILE) == 0 and M.TILE or math.mod(w, M.TILE))
			local fw = k < across and M.TILE or FileSize(pw)
			used = used + 1
			local t = Tile(used)
			t:SetTexture(path .. ((j - 1) * across + k))
			t:SetWidth(pw)
			t:SetHeight(ph)
			t:SetTexCoord(0, pw / fw, 0, ph / fh)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", WorldMapDetailFrame, "TOPLEFT", x + M.TILE * (k - 1), -(y + M.TILE * (j - 1)))
			t:SetVertexColor(M.DIM, M.DIM, M.DIM, 1)
			t:Show()
		end
	end
	return used
end

--- Draw the zone's unexplored overlays, or none.
function Maps:Reveal()
	self.tiles = self.tiles or {}
	local used, s = 0, Settings()
	local file = GetMapInfo and GetMapInfo()
	local data = file and AegisPathfinder.MAP_OVERLAYS and AegisPathfinder.MAP_OVERLAYS[file]
	if s and s.mapreveal ~= false and data and WorldMapDetailFrame and not Maps.OtherReveal() then
		local known = {}
		for i = 1, GetNumMapOverlays() do
			local tex = GetMapOverlayInfo(i)
			if tex then known[string.upper(tex)] = true end
		end
		local prefix = "Interface\\WorldMap\\" .. file .. "\\"
		for _, entry in ipairs(data) do
			local _, _, name, w, h, x, y = string.find(entry, "^([^:]+):(%d+):(%d+):(%d+):(%d+)")
			if name and not known[string.upper(prefix .. name)] then
				used = self:DrawOverlay(prefix .. name, tonumber(w), tonumber(h), tonumber(x), tonumber(y), used)
			end
		end
	end
	for i = used + 1, table.getn(self.tiles) do self.tiles[i]:Hide() end
	return used
end

--[[ Pins: the step's places, and the rares ------------------------------------------ ]]

-- The `i`th pin of a pool, on the map, built as needed.
local function Pin(pool, i)
	local p = pool[i]
	if not p then
		p = CreateFrame("Button", nil, WorldMapButton)
		p:SetFrameLevel(WorldMapButton:GetFrameLevel() + 5)
		p.tex = p:CreateTexture(nil, "OVERLAY")
		p.tex:SetAllPoints(p)
		p:SetScript("OnEnter", function()
			if this.title then Theme:ShowTip(this, "TOP", this.title, this.lines) end
		end)
		p:SetScript("OnLeave", function() Theme:HideTip(this) end)
		pool[i] = p
	end
	return p
end

-- Put pin `p` at `x`, `y` (percent of the zone's map), `size` across.
local function Place(p, x, y, size)
	p:SetWidth(size)
	p:SetHeight(size)
	p:ClearAllPoints()
	p:SetPoint("CENTER", WorldMapButton, "TOPLEFT", x / 100 * WorldMapButton:GetWidth(),
		-y / 100 * WorldMapButton:GetHeight())
	p:Show()
end

--- The current step's places: { zone, x, y, kind, name }, kind being start
--- (a quest giver), finish (a hand-in), kill, loot or step (its note's place).
--- Worked out once per step.
function Maps:StepMarkers()
	local A = AegisPathfinder
	local i = A.current
	if not (A.actions and i and A.actions[i]) then return {} end
	-- The step by its guide, place, action and quest: a guide read again
	-- with steps skipped moves them up.
	local key = table.concat({ tostring(A.db and A.db.char.currentguide), i, A.actions[i],
		tostring(A.quests and A.quests[i]), tostring(pfDB ~= nil) }, ":")
	if self.markerKey == key then return self.markerList end
	local out = {}
	local function add(zone, x, y, kind, name)
		if zone and x and y and table.getn(out) < M.MARKERS then
			table.insert(out, { zone = zone, x = x, y = y, kind = kind, name = name })
		end
	end
	local db, action = pfDB, A.actions[i]
	local qid = tonumber((A:GetObjectiveTag("QID", i)))
	local quest = qid and db and db.quests and db.quests.data and db.quests.data[qid]
	local zones = db and db.zones and db.zones.loc
	local function unit(id, kind, cap)
		local data = db.units and db.units.data and db.units.data[id]
		local name = db.units and db.units.loc and db.units.loc[id]
		local n = 0
		for _, c in ipairs(data and data.coords or {}) do
			if n >= cap then return end
			add(zones and zones[c[3]], c[1], c[2], kind, name)
			n = n + 1
		end
	end
	if quest then
		if action == "ACCEPT" then
			for _, id in ipairs(quest.start and quest.start.U or {}) do unit(id, "start", M.GIVER_SPOTS) end
		elseif action == "TURNIN" then
			for _, id in ipairs(quest["end"] and quest["end"].U or {}) do unit(id, "finish", M.GIVER_SPOTS) end
		elseif action == "COMPLETE" then
			for _, id in ipairs(quest.obj and quest.obj.U or {}) do unit(id, "kill", M.KILL_SPOTS) end
			for _, item in ipairs(quest.obj and quest.obj.I or {}) do
				local drops = db.items and db.items.data and db.items.data[item] and db.items.data[item].U
				for id in pairs(drops or {}) do unit(id, "loot", M.GIVER_SPOTS) end
			end
		end
	end
	local _, _, x, y = string.find(A:GetObjectiveTag("N", i) or "", L.COORD_MATCH)
	if x then
		local name = string.gsub(A.quests and A.quests[i] or "", "@.*$", "")
		add(A:GetObjectiveTag("Z", i) or A.zonename, tonumber(x), tonumber(y), "step", name)
	end
	self.markerKey, self.markerList = key, out
	return out
end

-- What each kind of place looks like, and says.
local KIND = {
	start = { glyph = "A", colour = "gold", big = true, what = "Gives the quest" },
	finish = { glyph = "T", colour = "gold", big = true, what = "Takes the quest" },
	step = { glyph = "N", colour = "accent", big = true, what = "The step's place" },
	kill = { colour = "danger", what = "To kill" },
	loot = { colour = "gold", what = "Drops what the quest wants" },
}

--- The step's places on the zone the map shows.
function Maps:DrawMarkers()
	self.pins = self.pins or {}
	local used, s, zone = 0, Settings(), Maps.ShownZone()
	if s and s.mapmarkers ~= false and zone and WorldMapButton then
		for _, m in ipairs(self:StepMarkers()) do
			if m.zone == zone then
				used = used + 1
				local p, kind = Pin(self.pins, used), KIND[m.kind]
				if kind.glyph then
					p.tex:SetTexture(Theme.actionIcon[kind.glyph])
				else
					p.tex:SetTexture(Theme.texture.circleFill)
				end
				Theme:Tint(p.tex, kind.colour)
				p.title, p.lines = m.name or kind.what, { kind.what }
				Place(p, m.x, m.y, kind.big and M.PIN or M.SPOT)
			end
		end
	end
	for i = used + 1, table.getn(self.pins) do self.pins[i]:Hide() end
	return used
end

--- The rares near your level on the zone the map shows, at each place they
--- can spawn.
function Maps:DrawRares()
	self.rarePins = self.rarePins or {}
	local used, s, zone = 0, Settings(), Maps.ShownZone()
	local list = zone and AegisPathfinder.RARES and AegisPathfinder.RARES[zone]
	if s and s.maprares and list and WorldMapButton then
		local level = UnitLevel("player") or 1
		local size = math.floor(M.RARE_PIN * (s.raresize or 1) + 0.5)
		for _, r in ipairs(list) do
			if r[3] >= level - M.RARE_BELOW and r[2] <= level + M.RARE_ABOVE then
				local levels = r[2] == r[3] and tostring(r[2]) or (r[2] .. "-" .. r[3])
				local pts = r[5]
				for k = 1, table.getn(pts), 2 do
					used = used + 1
					local p = Pin(self.rarePins, used)
					p.tex:SetTexture(Theme.actionIcon.K)
					Theme:Tint(p.tex, r[4] == "elite" and "danger" or "gold")
					p:SetAlpha(s.raresseethru and 0.5 or 1)
					p.title = r[1]
					p.lines = { "Level " .. levels .. (r[4] == "elite" and " rare elite" or " rare"), "Can spawn here" }
					Place(p, pts[k], pts[k + 1], size)
				end
			end
		end
	end
	for i = used + 1, table.getn(self.rarePins) do self.rarePins[i]:Hide() end
	return used
end

--[[ The ant trail -------------------------------------------------------------------- ]]

-- The `i`th dot of a pool on `parent`, `size` across.
local function Dot(pool, i, parent, size)
	local d = pool[i]
	if not d then
		d = CreateFrame("Frame", nil, parent)
		d.tex = d:CreateTexture(nil, "OVERLAY")
		d.tex:SetAllPoints(d)
		d.tex:SetTexture(Theme.texture.circleFill)
		pool[i] = d
	end
	d:SetWidth(size)
	d:SetHeight(size)
	Theme:Tint(d.tex, "accent")
	return d
end

--- The trail on the world map, from you to the waypoint, when both are on
--- the zone it shows: dots, or dashes, marching toward the waypoint.
function Maps:DrawTrail(now)
	self.trail = self.trail or {}
	local used, s, wp = 0, Settings(), AegisPathfinder.waypointtarget
	if s and s.anttrail ~= false and wp and WorldMapButton
		and GetCurrentMapContinent() == wp.continent and GetCurrentMapZone() == wp.zoneindex then
		local px, py = GetPlayerMapPosition("player")
		if px and (px > 0 or py > 0) then
			local W, H = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
			local x1, y1 = px * W, py * H
			local dx, dy = wp.x / 100 * W - x1, wp.y / 100 * H - y1
			local len = math.sqrt(dx * dx + dy * dy)
			local dashes = s.antstyle == "dashes"
			local gap, size = dashes and M.DASH_GAP or M.DOT_GAP, dashes and M.DASH or M.DOT
			local n = math.min(M.TRAIL_MAX, math.floor(len / gap))
			-- How far along the march is: a gap's worth every MARCH seconds.
			local phase = math.mod((now or 0) / M.MARCH, 1)
			for k = 1, n - 1 do
				-- Dashes: three dots on, three off.
				if not dashes or math.mod(k, 6) < 3 then
					used = used + 1
					local t = (k + phase) * gap / len
					local d = Dot(self.trail, used, WorldMapButton, size)
					d:SetFrameLevel(WorldMapButton:GetFrameLevel() + 4)
					d:ClearAllPoints()
					d:SetPoint("CENTER", WorldMapButton, "TOPLEFT", x1 + dx * t, -(y1 + dy * t))
					d:Show()
				end
			end
		end
	end
	for i = used + 1, table.getn(self.trail) do self.trail[i]:Hide() end
	return used
end

--- The trail on the minimap, with Astrolabe: dots from you toward the
--- waypoint, as far as the minimap reaches, when it is in your zone.
function Maps:DrawMiniTrail()
	self.mini = self.mini or {}
	local placed, s, wp = 0, Settings(), AegisPathfinder.waypointtarget
	local astro = Astrolabe
	if s and s.anttrail ~= false and wp and astro and astro.PlaceIconOnMinimap and Minimap
		and not (WorldMapFrame and WorldMapFrame:IsShown()) then
		local ok, c, z, x, y = pcall(astro.GetCurrentPlayerPosition, astro)
		if ok and c == wp.continent and z == wp.zoneindex and x then
			local wx, wy = wp.x / 100, wp.y / 100
			local ok2, dist = pcall(astro.ComputeDistance, astro, c, z, x, y, c, z, wx, wy)
			if ok2 and dist and dist > 0 then
				local sizes = astro.minimapOutside == false and M.INDOOR or M.OUTDOOR
				local reach = math.min(dist, (sizes[Minimap:GetZoom()] or sizes[0]) / 2 * M.MINI_FILL)
				for k = 1, M.MINI_DOTS do
					local f = reach * k / (M.MINI_DOTS + 1) / dist
					placed = placed + 1
					local d = Dot(self.mini, placed, Minimap, M.MINI_DOT)
					pcall(astro.PlaceIconOnMinimap, astro, d, c, z, x + (wx - x) * f, y + (wy - y) * f)
				end
			end
		end
	end
	for i = placed + 1, table.getn(self.mini) do
		local d = self.mini[i]
		if astro and astro.RemoveIconFromMinimap then pcall(astro.RemoveIconFromMinimap, astro, d) end
		d:Hide()
	end
	return placed
end

--[[ Keeping up -------------------------------------------------------------------------- ]]

--- Everything on the world map, again: the map changed, or a setting did.
function Maps:OnMapUpdate()
	if not Settings() then return end
	self:Reveal()
	self:DrawMarkers()
	self:DrawRares()
	self:DrawTrail(GetTime())
end

--- A setting changed on the Maps page: draw it now.
function Maps:Refresh()
	if WorldMapFrame and WorldMapFrame:IsShown() then self:OnMapUpdate() end
	self:DrawMiniTrail()
end

-- After the client draws the map, our part of it.
if WorldMapFrame_Update then
	local drawn = WorldMapFrame_Update
	WorldMapFrame_Update = function(a)
		drawn(a)
		Maps:OnMapUpdate()
	end
end

-- While the world map is open: the trail marches, and follows you.
local ticker = CreateFrame("Frame", nil, WorldMapFrame or UIParent)
ticker:SetScript("OnUpdate", function()
	this.wait = (this.wait or 0) - (arg1 or 0)
	if this.wait > 0 or not (WorldMapFrame and WorldMapFrame:IsShown()) then return end
	this.wait = M.EVERY
	if Settings() then Maps:DrawTrail(GetTime()) end
end)
Maps.ticker = ticker

-- The minimap's trail, a few times a second; the step changing redraws the
-- markers next time the map opens.
local mini = CreateFrame("Frame")
mini:SetScript("OnUpdate", function()
	this.wait = (this.wait or 0) - (arg1 or 0)
	if this.wait > 0 then return end
	this.wait = M.MINI_EVERY
	if Settings() then Maps:DrawMiniTrail() end
end)
Maps.miniTicker = mini
