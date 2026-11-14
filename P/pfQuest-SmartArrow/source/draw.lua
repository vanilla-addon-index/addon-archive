-- pfQuest SmartArrow
-- Copyright (C) 2026 pfQuest SmartArrow contributors
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.md.

-- pfQuest SmartArrow: the route on the world map and minimap
--
-- pfQuest draws a straight dotted line from you to the objective (bright
-- dots on the world map, dim ones on the minimap) and a second, darker chain
-- between objectives. This replaces only the first: while a planned path
-- exists, pfQuest's player-to-objective dots are hidden and the planned path
-- is drawn instead, in the same texture and colours, on the same layers.
-- pfQuest's objective chain and its "routes" / "routeminimap" settings are
-- left as they are and respected.
--
-- pfQuest's DrawLine is local to route.lua, so its dots are told apart by the
-- colour pfQuest gives them: every dot texture on its layers gets a tiny
-- SetVertexColor wrapper that remembers whether it was coloured as a player
-- dot.

local sqrt, ceil, floor, abs = math.sqrt, math.ceil, math.floor, math.abs
local insert = table.insert
local getn = table.getn

local D = CreateFrame("Frame", "pfQuestSmartArrowDraw", UIParent)
pfQuestSmartArrowDraw = D

D.paths = nil   -- list of polylines (world points)
D.version = 0

local function RouteTexture()
  return pfQuestConfig.path .. "\\img\\route"
end

-- dot pools ---------------------------------------------------------------------

local function Pool(parent)
  return { parent = parent, dots = {}, used = 0 }
end

-- Dots are reused in place: a redraw only moves the dots whose spot changed
-- and hides the ones left over, instead of hiding and re-anchoring every dot
-- (re-anchoring hundreds of textures in one frame is what made it stutter).
local function PoolBegin(pool)
  pool.last = pool.used
  pool.used = 0
end

local function PoolEnd(pool)
  for i = pool.used + 1, pool.last or 0 do
    local dot = pool.dots[i]
    if dot.pfqsaShown then dot:Hide() dot.pfqsaShown = nil end
  end
  pool.last = nil
end

local function PoolReset(pool)
  PoolBegin(pool)
  PoolEnd(pool)
end

local function PoolDot(pool, anchor, x, y, a)
  pool.used = pool.used + 1
  local dot = pool.dots[pool.used]
  if not dot then
    dot = pool.parent:CreateTexture(nil, "OVERLAY")
    dot:SetWidth(4)
    dot:SetHeight(4)
    dot:SetTexture(RouteTexture())
    pool.dots[pool.used] = dot
  end
  if dot.pfqsaA ~= a then
    dot:SetVertexColor(1, 0.8, 0.4, a)
    dot.pfqsaA = a
  end
  -- half a pixel is not worth re-anchoring for
  x, y = floor(x * 2 + 0.5) / 2, floor(y * 2 + 0.5) / 2
  if dot.pfqsaX ~= x or dot.pfqsaY ~= y or dot.pfqsaAnchor ~= anchor then
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", anchor, anchor == WorldMapButton and "TOPLEFT" or "CENTER", x, y)
    dot.pfqsaX, dot.pfqsaY, dot.pfqsaAnchor = x, y, anchor
  end
  if not dot.pfqsaShown then dot:Show() dot.pfqsaShown = true end
  return dot
end

-- pfQuest's own player dots ---------------------------------------------------

-- tag textures with the colour pfQuest last gave them
local function IsPlayerColour(r, g, b, a)
  return (r and r > 0.99 and g and g > 0.79 and g < 0.81) or (a and a < 0.6) or nil
end

-- returns true when the texture's current colour could not be read, so
-- pfQuest has to colour it again (through the wrapper) before we can tell
local function Tag(tex)
  if tex.pfqsaTagged then return false end
  tex.pfqsaTagged = true
  local known = false
  if tex.GetVertexColor then
    local ok, r, g, b, a = pcall(tex.GetVertexColor, tex)
    if ok and r then
      tex.pfqsaPlayer = IsPlayerColour(r, g, b, a)
      known = true
    end
  end
  local orig = tex.SetVertexColor
  tex.SetVertexColor = function(self, r, g, b, a)
    self.pfqsaPlayer = IsPlayerColour(r, g, b, a)
    orig(self, r, g, b, a)
  end
  return not known
end

local function HideRegions(frame, minimap)
  if not frame then return false end
  local unknown = false
  local regions = { frame:GetRegions() }
  for i = 1, getn(regions) do
    local tex = regions[i]
    if tex.SetVertexColor and tex.GetTexture then
      local path = tex:GetTexture()
      if path and string.find(string.lower(path), "img\\route") then
        if Tag(tex) and not minimap and tex:IsShown() then unknown = true end
        -- on the minimap pfQuest only draws the player path
        if (minimap or tex.pfqsaPlayer) and tex:IsShown() then
          tex:Hide()
        end
      end
    end
  end
  return unknown
end

function D:HidePfQuestPlayerPath()
  local unknown = HideRegions(WorldMapButton and WorldMapButton.routes, false)
  HideRegions(pfMap and pfMap.drawlayer, true)
  if unknown then
    -- dots drawn before we could tag them: have pfQuest draw them once more
    self:RestorePfQuestPlayerPath()
    self.mustHide = true
  end
end

-- ask pfQuest to redraw its player path (after we stop replacing it)
function D:RestorePfQuestPlayerPath()
  local route = pfQuest and pfQuest.route
  if route then
    route.lastDrawX, route.lastDrawY, route.lastDrawNode = nil, nil, nil
  end
end

-- Runs right after pfQuest's route OnUpdate. pfQuest only redraws its player
-- path when you move or the target changes (it records that in lastDraw*),
-- so the hide pass only runs when it actually drew something.
function D:AfterPfQuest(before)
  local route = pfQuest.route
  if not self:Active() then
    return
  end
  if before.x ~= route.lastDrawX or before.y ~= route.lastDrawY or before.node ~= route.lastDrawNode or self.mustHide then
    self.mustHide = nil
    self:HidePfQuestPlayerPath()
  end
end

function D:Hook()
  if self.hooked or not (pfQuest and pfQuest.route and pfQuest.route.GetScript) then return end
  self.hooked = true
  local route = pfQuest.route
  local orig = route:GetScript("OnUpdate")
  local before = {}
  route:SetScript("OnUpdate", function()
    before.x, before.y, before.node = route.lastDrawX, route.lastDrawY, route.lastDrawNode
    if orig then orig() end
    D:AfterPfQuest(before)
  end)
end

-- our path ----------------------------------------------------------------------

function D:Active()
  return self.paths ~= nil and pfQuestSmartArrow_config.enabled == "1" and pfQuestSmartArrow_config.drawpath ~= "0"
end

-- a cheap fingerprint of the path's shape, to two yards
local function Signature(paths)
  if not paths then return "" end
  local parts = {}
  for _, poly in ipairs(paths) do
    for i = 1, getn(poly) do
      local p = poly[i]
      insert(parts, (p.c or 0) .. ":" .. floor(p.n / 2) .. ":" .. floor(p.w / 2))
    end
    insert(parts, "|")
  end
  return table.concat(parts, ",")
end

-- Solves come every few seconds but usually give the same path again; only a
-- path that really changed is redrawn.
function D:SetPaths(paths)
  local had = self.replacing
  self.paths = paths
  self.replacing = self:Active()
  local sig = self.replacing and Signature(paths) or ""
  if sig ~= self.sig then
    self.sig = sig
    self.version = self.version + 1
  end
  if self.replacing and not had then
    -- just took over: hide pfQuest's dots once; AfterPfQuest keeps them
    -- hidden whenever pfQuest draws them again
    self.mustHide = true
  elseif had and not self.replacing then
    self:RestorePfQuestPlayerPath()
  end
end

local function DrawSegmentWorld(pool, x1, y1, x2, y2, width, height)
  local dx, dy = x2 - x1, y2 - y1
  local dots = ceil(sqrt(dx * 1.5 * dx * 1.5 + dy * dy))
  if dots < 1 then return end
  for i = 0, dots - 1 do
    local x = x1 + dx / dots * i
    local y = y1 + dy / dots * i
    if x >= 0 and x <= 100 and y >= 0 and y <= 100 then
      PoolDot(pool, WorldMapButton, x / 100 * width, -y / 100 * height, 1)
    end
  end
end

function D:DrawWorld()
  if not self.world then
    local layer = (pfQuest.route and pfQuest.route.drawlayer) or WorldMapButton
    local f = CreateFrame("Frame", "pfQuestSmartArrowWorldPath", layer)
    f:SetAllPoints(WorldMapButton)
    f:SetFrameLevel(layer:GetFrameLevel() + 1)
    self.world = Pool(f)
  end
  PoolBegin(self.world)
  self:FillWorld()
  PoolEnd(self.world)
end

function D:FillWorld()
  if not self:Active() or pfQuest_config["routes"] == "0" then return end

  local zone = pfMap:GetMapID(GetCurrentMapContinent(), GetCurrentMapZone())
  if not zone or not pfQuestSmartArrowNav:Transform(zone) then return end
  local width, height = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
  local Nav = pfQuestSmartArrowNav

  for _, poly in ipairs(self.paths) do
    for i = 1, getn(poly) - 1 do
      local p, q = poly[i], poly[i + 1]
      local x1, y1, c1 = Nav:WorldToMap(zone, p.n, p.w)
      local x2, y2 = Nav:WorldToMap(zone, q.n, q.w)
      if x1 and c1 == p.c and not ((x1 < 0 and x2 < 0) or (x1 > 100 and x2 > 100) or (y1 < 0 and y2 < 0) or (y1 > 100 and y2 > 100)) then
        DrawSegmentWorld(self.world, x1, y1, x2, y2, width, height)
      end
    end
  end
end

function D:DrawMinimap(player)
  local layer = pfMap and pfMap.drawlayer
  if not layer or not pfMap.minimap_zoom or not pfMap.minimap_indoor then return end
  if not self.mini then
    local f = CreateFrame("Frame", "pfQuestSmartArrowMinimapPath", layer)
    f:SetAllPoints(layer)
    self.mini = Pool(f)
  end
  PoolBegin(self.mini)
  self:FillMinimap(layer, player)
  PoolEnd(self.mini)
end

function D:FillMinimap(layer, player)
  if not self:Active() or pfQuest_config["routeminimap"] ~= "1" or not player or not player.zone then return end

  local Nav = pfQuestSmartArrowNav
  local zone = player.zone
  local px, py = Nav:WorldToMap(zone, player.n, player.w)
  local sizes = pfMap.minimap_sizes and pfMap.minimap_sizes[zone]
  if not px or not sizes then return end

  local mapZoom = pfMap.minimap_zoom[pfMap.minimap_indoor()][layer:GetZoom()]
  local mapWidth, mapHeight = sizes[1] or 0, sizes[2] or 0
  if not mapZoom or mapWidth == 0 or mapHeight == 0 then return end
  local xdraw = layer:GetWidth() / (mapZoom / mapWidth) / 100
  local ydraw = layer:GetHeight() / (mapZoom / mapHeight) / 100
  local zoom = ((mapZoom / mapWidth) + (mapZoom / mapHeight)) * 3
  local half = layer:GetWidth() / 2
  local halfh = layer:GetHeight() / 2
  local square = pfUI and pfUI.minimap
  -- a circle around the player that holds the whole minimap (its corners
  -- too, for a square one): only that part of the route is walked
  local reach = (square and sqrt(half * half + halfh * halfh) or half) + 2

  for _, poly in ipairs(self.paths) do
    for i = 1, getn(poly) - 1 do
      local x1, y1 = Nav:WorldToMap(zone, poly[i].n, poly[i].w)
      local x2, y2 = Nav:WorldToMap(zone, poly[i + 1].n, poly[i + 1].w)
      if x1 and x2 and poly[i].c == player.c then
        -- the segment in minimap pixels, the player at 0,0
        local ax, ay = (px - x1) * xdraw, (py - y1) * ydraw
        local bx, by = (px - x2) * xdraw, (py - y2) * ydraw
        local ex, ey = bx - ax, by - ay
        local len2 = ex * ex + ey * ey
        -- where on the segment it is within reach: |A + tE| = reach
        local t0, t1
        if len2 < 0.0001 then
          if ax * ax + ay * ay <= reach * reach then t0, t1 = 0, 0 end
        else
          local bq = (ax * ex + ay * ey) / len2
          local cq = (ax * ax + ay * ay - reach * reach) / len2
          local disc = bq * bq - cq
          if disc >= 0 then
            local root = sqrt(disc)
            t0, t1 = -bq - root, -bq + root
            if t0 < 0 then t0 = 0 end
            if t1 > 1 then t1 = 1 end
            if t0 > t1 then t0 = nil end
          end
        end
        if t0 then
          local dx, dy = x2 - x1, y2 - y1
          local dots = ceil(sqrt(dx * 1.5 * dx * 1.5 + dy * dy) / zoom)
          if dots < 1 then dots = 1 end
          local kfrom, kto = floor(t0 * dots), ceil(t1 * dots)
          if kto > dots - 1 then kto = dots - 1 end
          for k = kfrom, kto do
            local x = ax + ex * k / dots
            local y = ay + ey * k / dots
            local show
            if square then
              show = abs(x) + 1 < half and abs(y) + 1 < halfh
            else
              show = sqrt(x * x + y * y) + 1 < half
            end
            if show then
              PoolDot(self.mini, layer, -x, y, 0.7)
            end
          end
        end
      end
    end
  end
end

-- redraw when the path changes, the map changes, or you move enough
D:SetScript("OnUpdate", function()
  if not pfQuestSmartArrow or not pfQuestSmartArrow.ready then return end
  local now = GetTime()
  if (this.next or 0) > now then return end
  this.next = now + 0.2

  if WorldMapFrame and WorldMapFrame:IsShown() then
    local zone = pfMap:GetMapID(GetCurrentMapContinent(), GetCurrentMapZone())
    if this.worldversion ~= this.version or this.worldzone ~= zone then
      this.worldversion, this.worldzone = this.version, zone
      this:DrawWorld()
    end
  end

  local player = pfQuestSmartArrow.lastsample
  if player then
    local moved = 999
    if this.miniat and this.miniat.c == player.c then
      local dn, dw = this.miniat.n - player.n, this.miniat.w - player.w
      moved = sqrt(dn * dn + dw * dw)
    end
    local layer = pfMap and pfMap.drawlayer
    local zoom = layer and layer.GetZoom and layer:GetZoom()
    if this.minimapversion ~= this.version or moved > 2 or this.minizoom ~= zoom then
      this.minimapversion, this.miniat, this.minizoom = this.version, player, zoom
      this:DrawMinimap(player)
    end
  end
end)
