-- AnySCT plates.lua -- nameplate lookup and screen placement maths.
--
-- There is no world-to-screen API in the 1.12 client, so the only way to float text over a mob is
-- to ride its nameplate. This file finds the plate frame of a unit, and decides WHERE a line goes:
--   mode 1  plate found, centre on screen            -> spawn at the plate
--   mode 2  plate found, centre off screen / in the edge margin -> clamp to the screen
--   mode 3  no usable plate (or placement says so)    -> fixed anchor
--   mode 0  no plate and the user chose to hide
--
-- Plate detection (verified for TurtleWoW): child of WorldFrame, object type "Button", first region
-- a Texture "Interface\\Tooltips\\Nameplate-Border". Region order: border, glow, name, level,
-- levelicon, raidicon; children: healthbar, castbar. The GUID comes from plate:GetName(1) under
-- SuperWoW (>= 1.0) / nampower (>= 2.28); it is accepted only if it looks like "0x...".

AnySCT_Plates = {}
local P = AnySCT_Plates

P.plates = {}          -- every plate frame seen so far
P.nPlates = 0
P.byGuid = {}          -- normalised guid -> visible plate (rebuilt each scan)
P.guidCapable = false  -- true once any visible plate returned a GUID
P.lastCount = 0
P.lastScan = -1
P.gen = 0              -- bumped by every scan; lines re-check their plate only when it changes
P.SCAN_INTERVAL = 0.2

local function now()
    if GetTime then return GetTime() end
    return 0
end

-- Forget every cached plate (tests; also usable if the plate frames are ever rebuilt).
function P.Reset()
    P.plates = {}
    P.nPlates = 0
    P.byGuid = {}
    P.guidCapable = false
    P.lastCount = 0
    P.lastScan = -1
    P.gen = 0
end

-- ---- pure clamp maths --------------------------------------------------------------------------

-- Clamp a point into [margin, size - margin] on both axes. Third result: true if it moved.
-- If the screen is smaller than twice the margin the axis collapses to its centre.
local function clampAxis(v, size, margin)
    local lo, hi = margin, size - margin
    if hi < lo then return size / 2 end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function AnySCT_ClampToScreen(x, y, width, height, margin)
    margin = margin or 0
    local cx, cy = clampAxis(x, width, margin), clampAxis(y, height, margin)
    return cx, cy, (cx ~= x or cy ~= y)
end

-- ---- detection ----------------------------------------------------------------------------------

function P.IsPlate(f)
    if not f or not f.GetObjectType or f:GetObjectType() ~= "Button" then return false end
    local r = f:GetRegions()
    if not r or not r.GetObjectType or r:GetObjectType() ~= "Texture" then return false end
    return r:GetTexture() == "Interface\\Tooltips\\Nameplate-Border"
end

-- The GUID string of a plate, or nil.
function P.PlateGuid(plate)
    local ok, g = pcall(plate.GetName, plate, 1)
    if ok and type(g) == "string" and string.find(g, "^0x") then return g end
    return nil
end

local function addPlate(f)
    P.nPlates = P.nPlates + 1
    P.plates[P.nPlates] = f
    -- cache what the name fallback needs (regions: border, glow, name, ...)
    local r1, r2, r3 = f:GetRegions()
    f.asctNameRegion = r3
    f.asctBar = f:GetChildren()
end

-- Scan for new plates (only when WorldFrame's child count changed) and rebuild the GUID map.
-- Throttled to SCAN_INTERVAL unless force.
function P.Scan(force)
    local t = now()
    if not force and t - P.lastScan < P.SCAN_INTERVAL then return end
    P.lastScan = t
    local n = WorldFrame:GetNumChildren()
    if n ~= P.lastCount then
        local kids = { WorldFrame:GetChildren() }
        for i = P.lastCount + 1, n do
            local f = kids[i]
            if f and P.IsPlate(f) then addPlate(f) end
        end
        P.lastCount = n
    end
    local map = P.byGuid
    for k in pairs(map) do map[k] = nil end
    for i = 1, P.nPlates do
        local pl = P.plates[i]
        if pl:IsVisible() then
            local g = P.PlateGuid(pl)
            if g then
                P.guidCapable = true
                map[AnySCT_Core.NormGuid(g)] = pl
            end
        end
    end
    P.gen = P.gen + 1
end

-- Health fraction of a plate's bar, or nil.
local function barFraction(plate)
    local bar = plate.asctBar
    if not bar or not bar.GetValue then return nil end
    local lo, hi = bar:GetMinMaxValues()
    if not hi or hi <= lo then return nil end
    return (bar:GetValue() - lo) / (hi - lo)
end

-- Debug dump of a failed lookup: victim GUID, normalised form, scan-map size and up to 10 visible
-- plates with name and GUID. Only called with /asct debug on.
local function dumpMiss(guid, name)
    local C = AnySCT_Core
    local ng = guid and C.NormGuid(guid) or "-"
    local n = 0
    for _ in pairs(P.byGuid) do n = n + 1 end
    C.Dbg("plate miss: guid=" .. tostring(guid) .. " norm=" .. tostring(ng) .. " name=" .. tostring(name)
        .. " mapped=" .. n .. " plates=" .. P.nPlates)
    local shown = 0
    for i = 1, P.nPlates do
        local pl = P.plates[i]
        if shown < 10 and pl:IsVisible() then
            shown = shown + 1
            local g = P.PlateGuid(pl)
            local nm = pl.asctNameRegion and pl.asctNameRegion.GetText and pl.asctNameRegion:GetText() or "?"
            C.Dbg("  plate '" .. tostring(nm) .. "' guid=" .. tostring(g) .. " norm=" .. tostring(g and C.NormGuid(g)))
        end
    end
end

-- Find the plate of a unit. guid: SuperWoW GUID string or nil; name: unit name; unit: token for the
-- health comparison of the name fallback. Returns a visible plate or nil.
-- Chain, never stopping early: scan map by GUID -> one forced rescan -> UnitNameplate(guid) ->
-- plate name (event name, else UnitName(guid)) -> nil.
function P.Find(guid, name, unit)
    P.Scan(false)
    if guid then
        local ng = AnySCT_Core.NormGuid(guid)
        local pl = P.byGuid[ng]
        if not pl and now() - P.lastScan > 0.05 then
            P.Scan(true)
            pl = P.byGuid[ng]
        end
        if pl and pl:IsVisible() then return pl end
        if UnitNameplate then
            local ok, f = pcall(UnitNameplate, guid)
            if ok and type(f) == "table" and f.IsVisible and f:IsVisible() then return f end
        end
        if not name and UnitName then
            local ok, n = pcall(UnitName, guid)
            if ok and type(n) == "string" then name = n end
        end
    end
    if not name then
        if AnySCT_Core.debug then dumpMiss(guid, name) end
        return nil
    end
    local want
    if unit and UnitHealth and UnitHealthMax then
        local mx = UnitHealthMax(unit)
        if mx and mx > 0 then want = UnitHealth(unit) / mx end
    end
    local best = P.FindByName(name, want)
    if not best and now() - P.lastScan > 0.05 then
        P.Scan(true)          -- the plate may be new since the last scan: one forced rescan on a miss
        best = P.FindByName(name, want)
    end
    if not best and AnySCT_Core.debug then dumpMiss(guid, name) end
    return best
end

-- Visible plate whose name text is `name`; with several, the one whose health is closest to `want`.
function P.FindByName(name, want)
    local best, bestDiff
    for i = 1, P.nPlates do
        local pl = P.plates[i]
        if pl:IsVisible() and pl.asctNameRegion and pl.asctNameRegion.GetText
            and pl.asctNameRegion:GetText() == name then
            local diff = 0
            if want then
                local fr = barFraction(pl)
                if fr then diff = want - fr; if diff < 0 then diff = -diff end end
            end
            if not best or diff < bestDiff then best, bestDiff = pl, diff end
        end
    end
    return best
end

-- ---- placement -----------------------------------------------------------------------------------

-- Spawn point of a plate in UIParent coordinates (horizontal centre, TOP edge, like the Blizzard
-- pet text) plus the screen size, or nil when the plate has no position.
function P.PlatePosition(plate)
    if not plate then return nil end
    local cx, cy = plate:GetCenter()
    if not cx then return nil end
    local top = plate.GetTop and plate:GetTop() or nil
    if top then cy = top end
    local ps = plate:GetEffectiveScale()
    local us = UIParent:GetEffectiveScale()
    if ps and us and us > 0 then
        cx = cx * ps / us
        cy = cy * ps / us
    end
    return cx, cy, UIParent:GetWidth(), UIParent:GetHeight()
end

-- Decide the display mode. opt needs: placement ("clamp" | "anchorOff" | "anchor" | "both"), noPlate
-- ("anchor" | "hide"), edgeMargin. Returns mode, x, y, screenW, screenH (x, y only for mode 1/2).
function P.Select(plate, opt)
    if opt.placement == "anchor" then return 3 end
    local cx, cy, w, h = P.PlatePosition(plate)
    if not cx then
        if opt.noPlate == "hide" then return 0 end
        return 3
    end
    local m = opt.edgeMargin or 0
    if cx >= m and cx <= w - m and cy >= m and cy <= h - m then return 1, cx, cy, w, h end
    if opt.placement == "anchorOff" then return 3 end
    return 2, cx, cy, w, h
end
AnySCT_SelectMode = P.Select

-- Placement "both": the plate rules of "clamp" (modes 1/2) plus a copy at the fixed anchor. Without a
-- usable plate (none found, off screen with hide, or hidden) the anchor shows it once, whatever the
-- no-plate setting says. Returns mode, x, y, screenW, screenH, alsoAnchor.
function P.Places(plate, opt)
    local mode, x, y, w, h = P.Select(plate, opt)
    if opt.placement == "both" then
        if mode == 1 or mode == 2 then return mode, x, y, w, h, true end
        return 3
    end
    return mode, x, y, w, h, false
end

-- Does the plate still show the mob? Uses the last scan only (no per-frame GetName).
function P.PlateMatches(plate, guidNorm)
    if not plate:IsVisible() then return false end
    if guidNorm and P.guidCapable then
        local mapped = P.byGuid[guidNorm]
        if mapped then return mapped == plate end
        -- the mob's GUID is not exposed (plate was found by name): keep following unless the plate
        -- now shows a different, GUID-exposing mob
        for k, pl in pairs(P.byGuid) do
            if pl == plate then return false end
        end
    end
    return true
end

-- Per-frame follow of a line (fields: plate, guidNorm, gen, valid, lastX, lastY, lastW, lastH).
-- The identity check runs only when a new scan generation exists; between scans a frame costs a
-- visibility test and a position read, no allocation.
function P.FollowLine(s)
    if s.gen ~= P.gen then
        s.gen = P.gen
        s.valid = P.PlateMatches(s.plate, s.guidNorm)
    end
    if s.valid and s.plate:IsVisible() then
        local px, py, w, h = P.PlatePosition(s.plate)
        if px then s.lastX, s.lastY, s.lastW, s.lastH = px, py, w, h end
    end
end
