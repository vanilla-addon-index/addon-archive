--[[----------------------------------------------------------------------
pfUI_CombatLedgerExt  -  Aggro ring on hostile nameplates + off-screen edge dots

Every hostile (red) nameplate gets a dotted line under it as you approach its estimated aggro range:
  - the middle dot lights `ringwarn` yards (default 15) before the edge and the line grows out to both
    sides until it spans the whole bottom of the plate;
  - each newly lit dot is redder (amber -> orange -> red) and the dots grow and brighten as it fills;
  - when it is complete (you are inside the radius, or the mob is targeting you) every dot turns red
    and pulses slowly.
The plate's name is tinted along with it.  If OctoPad is loaded, its soft-selected unit keeps OctoPad's
own name colour.

Off-screen edge dots: a hostile mob you have already seen (nameplate or target) that is now out of view
(no visible nameplate) gets the same dotted line, as long as a nameplate, on the screen border at the
point in its direction (sides, corners, bottom = behind; the top edge is left empty because a mob in
front of you is on screen).  Lines turn diagonally across the screen corners and are pushed apart so several mobs show as separate lines.  Each grows from its middle out.

Aggro radius estimate (vanilla): about 20 yd at equal level, 1 yd more / less per level the mob is above /
below you, between 5 and 45 yd.  Neutral (yellow) mobs, players and dead units are ignored.

REQUIRES SuperWoW (nameplate GUIDs, UnitPosition) and UnitXP SP3 (exact distance) to work properly.
Without UnitXP SP3 the ring falls back to coarse interact ranges (about 10 and 28 yd) and the edge dots
are disabled.  Does not need CombatLedger data.  Lua 5.0.
------------------------------------------------------------------------]]

CLpfUIThreatRing = {}
local M = CLpfUIThreatRing

local function Cfg()
  local db = CLpfUIThreatDB
  if not db then return nil end
  if db.ring == nil then db.ring = true end
  if db.ringwarn == nil then db.ringwarn = 15 end
  if db.ringedge == nil then db.ringedge = true end
  db.ringmirror, db.ringswap = nil, nil                             -- old direction settings, no longer used
  return db
end

-- the visible name text of a plate: pfUI keeps it on p.nameplate.name (the Blizzard regions are hidden)
local function NameFS(p)
  local np = p.nameplate
  if np and np.name and np.name.GetText then return np.name end
  local regs = { p:GetRegions() }
  local i
  for i = 1, table.getn(regs) do
    if regs[i]:GetObjectType() == "FontString" then return regs[i] end
  end
  return nil
end

local function SoftNameFS()
  if OctoPad and OctoPad.SoftNameFS then return OctoPad.SoftNameFS() end
  return nil
end

local DOT = "Interface\\AddOns\\pfUI_CombatLedgerExt\\ringdot"
local PAD = 4                                          -- dot line distance below the plate
local rings = {}                                       -- plate frame -> ring frame
local hasXP

local function HasUnitXP()
  if hasXP == nil then
    hasXP = (UnitXP ~= nil) and pcall(UnitXP, "nop", "nop") and true or false
  end
  return hasXP
end
M.HasUnitXP = HasUnitXP

-- yards between you and the unit; second value = exact (UnitXP) or coarse (interact ranges)
local function Distance(u)
  if HasUnitXP() then
    local ok, d = pcall(UnitXP, "distanceBetween", "player", u)
    if ok and type(d) == "number" and d >= 0 then return d, true end
  end
  if CheckInteractDistance then
    local ok3, near = pcall(CheckInteractDistance, u, 3)          -- about 10 yd
    if ok3 and near then return 9, false end
    local ok4, mid = pcall(CheckInteractDistance, u, 4)           -- about 28 yd
    if ok4 and mid then return 27, false end
    return 40, false
  end
  return nil
end

local function AggroRadius(u)
  local ml = UnitLevel(u) or 0
  local pl = UnitLevel("player") or 1
  if ml <= 0 then return 45 end                                     -- "??" level
  local r = 20 + (ml - pl)
  if r < 5 then r = 5 elseif r > 45 then r = 45 end
  return r
end

local function TargetsMe(u)
  local ok, yes = pcall(function()
    return UnitExists(u .. "target") and UnitIsUnit(u .. "target", "player")
  end)
  return ok and yes
end

local function Eligible(u)
  if not UnitExists(u) or UnitIsPlayer(u) then return false end
  if UnitIsDead and UnitIsDead(u) then return false end
  if not UnitCanAttack("player", u) then return false end
  local re = UnitReaction and UnitReaction(u, "player")
  if re and re > 2 then return false end                            -- neutral / friendly
  return true
end

-- progress towards the aggro edge: frac 0..1, full = connected
local function Progress(u, warn)
  local d = Distance(u)
  local rad = AggroRadius(u)
  local full = TargetsMe(u) or (d and d <= rad) or false
  local frac = 0
  if d and not full then
    frac = (rad + warn - d) / warn
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
  end
  return frac, full, d
end

----------------------------------------------------------------------
-- ring frames: a dotted line under the plate, growing from the middle out to both ends
----------------------------------------------------------------------
local SEG = 21                                         -- dots under the plate (odd: one in the middle)

local function VisualOf(p)
  return p.nameplate or p                                           -- pfUI draws its plate on p.nameplate
end

local function NewDots(parent, n)
  local t = {}
  local i
  for i = 1, n do
    local d = parent:CreateTexture(nil, "OVERLAY")
    d:SetTexture(DOT)
    d:SetBlendMode("ADD")
    d:Hide()
    t[i] = d
  end
  return t
end

-- light a dotted line from its middle outwards.  Each newly lit dot is redder (amber -> orange -> red)
-- and the dots grow and brighten with `frac`.  full = every dot lit, red.  amul scales the alpha.
local function PaintDots(dots, n, frac, full, small, big, amul)
  local c = (n + 1) / 2
  local half = (n - 1) / 2
  local reach = math.floor(frac * half + .5)                        -- dots lit on each side of the middle
  local size = small + (big - small) * frac
  local i
  for i = 1, n do
    local d = dots[i]
    local off = math.abs(i - c)
    if full then
      d:SetVertexColor(1, .24, .18, amul)
      d:SetWidth(big + 2)
      d:SetHeight(big + 2)
    elseif frac > 0 and off <= reach then
      local t = off / half
      d:SetVertexColor(1, .71 - .47 * t, .23 - .05 * t, (.55 + .45 * frac) * amul)
      d:SetWidth(size)
      d:SetHeight(size)
    else
      d:SetVertexColor(1, 1, 1, .12 * amul)                         -- faint track
      d:SetWidth(4)
      d:SetHeight(4)
    end
    d:Show()
  end
end

local function GetRing(p)
  local r = rings[p]
  if r then return r end
  local vis = VisualOf(p)
  r = CreateFrame("Frame", nil, vis)
  r:SetAllPoints(vis)
  r:SetFrameLevel(vis:GetFrameLevel() + 6)
  r.dots = NewDots(r, SEG)
  r.vis = vis
  rings[p] = r
  return r
end

local function Layout(r)
  local vis = r.vis
  local w, h = vis:GetWidth() or 0, vis:GetHeight() or 0
  if w < 20 or h < 6 then return false end
  if r.w == w and r.h == h then return true end
  r.w, r.h = w, h
  local i
  for i = 1, SEG do
    local d = r.dots[i]
    d:ClearAllPoints()
    d:SetPoint("CENTER", vis, "BOTTOMLEFT", (i - 1) / (SEG - 1) * w, -PAD)
  end
  return true
end

local pulsing = {}

local function Paint(r, frac, full)
  PaintDots(r.dots, SEG, frac, full, 5, 9, 1)
  if full then pulsing[r] = true else pulsing[r] = nil r:SetAlpha(1) end
end
----------------------------------------------------------------------
-- name tint (restored when the ring goes away)
----------------------------------------------------------------------
local function TintName(r, fs, cr, cg, cb)
  if not fs then return end
  if SoftNameFS() == fs then return end                               -- OctoPad soft select owns it
  if not r.tintFS or r.tintFS ~= fs then
    local or_, og, ob = fs:GetTextColor()
    r.tintFS, r.oR, r.oG, r.oB = fs, or_, og, ob
  end
  fs:SetTextColor(cr, cg, cb)
end

local function UntintName(r)
  if r.tintFS then
    if SoftNameFS() ~= r.tintFS then
      pcall(r.tintFS.SetTextColor, r.tintFS, r.oR or 1, r.oG or 1, r.oB or 1)
    end
    r.tintFS = nil
  end
end

local function HideRing(r)
  pulsing[r] = nil
  UntintName(r)
  r:Hide()
end

----------------------------------------------------------------------
-- off-screen edge dots
----------------------------------------------------------------------
local arrow
local function PlayerFacing()
  if GetPlayerFacing then
    local ok, f = pcall(GetPlayerFacing)
    if ok and type(f) == "number" then return f, "GetPlayerFacing" end
  end
  if not arrow and Minimap then                                     -- the minimap's player arrow model
    local kids = { Minimap:GetChildren() }
    local i
    for i = 1, table.getn(kids) do
      local c = kids[i]
      if c.GetModel and c.GetFacing then
        local ok, m = pcall(c.GetModel, c)
        if ok and type(m) == "string" and string.find(string.lower(m), "minimaparrow") then
          arrow = c
          break
        end
      end
    end
  end
  if arrow then
    local ok, f = pcall(arrow.GetFacing, arrow)
    if ok and type(f) == "number" then return f, "minimap arrow" end
  end
  return nil
end

local function Pos(u)
  if not UnitPosition then return nil end
  local ok, x, y = pcall(UnitPosition, u)
  if ok and type(x) == "number" and type(y) == "number" then return x, y end
  return nil
end

-- direction of a unit relative to where you face: fwd (+ahead / -behind), left (+left / -right), unit length
local function Rel(u)
  local px, py = Pos("player")
  local mx, my = Pos(u)
  local f = PlayerFacing()
  if not (px and mx and f) then return nil end
  local dx, dy = mx - px, my - py
  local len = math.sqrt(dx * dx + dy * dy)
  if len < .01 then return nil end
  dx, dy = dx / len, dy / len
  local c, s = math.cos(f), math.sin(f)
  local fwd = -(dx * c + dy * s)                                    -- signs verified in-game
  local left = dx * s - dy * c
  return fwd, left
end

local function EdgeStatus()
  if not SUPERWOW_VERSION then return false, "needs SuperWoW" end
  if not UnitPosition then return false, "SuperWoW UnitPosition missing" end
  if not HasUnitXP() then return false, "needs UnitXP SP3" end
  if not PlayerFacing() then return false, "player facing unavailable" end
  return true
end

local edge
local marks = {}                                      -- this tick's off-screen mobs: { s, frac, full }
local pool = {}                                       -- indicator frames
local MAXMARK = 6                                     -- most indicators shown at once
local INSET = 14                                      -- distance from the screen border
local CHAMFER = 80                                    -- diagonal cut across each screen corner
local GAP = 24                                        -- minimum space between two indicators
local plateW = 110                                    -- line length = width of the nameplates seen

-- the border path: the screen edge with its corners cut diagonally, clockwise from the top-left,
-- coordinates from the screen centre (y up).  Lines follow it, so they turn diagonally at the corners.
local path, pathW, pathH, pathP

local function BuildPath()
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  if path and pathW == W and pathH == H then return end
  pathW, pathH = W, H
  local hx, hy = W / 2 - INSET, H / 2 - INSET
  local c = math.min(CHAMFER, hx, hy)
  local v = {
    { -hx + c, hy }, { hx - c, hy }, { hx, hy - c }, { hx, -hy + c },
    { hx - c, -hy }, { -hx + c, -hy }, { -hx, -hy + c }, { -hx, hy - c },
  }
  path = {}
  local s, i = 0
  for i = 1, 8 do
    local a, b = v[i], v[math.mod(i, 8) + 1]
    local ex, ey = b[1] - a[1], b[2] - a[2]
    local len = math.sqrt(ex * ex + ey * ey)
    path[i] = { x = a[1], y = a[2], ex = ex, ey = ey, len = len, s = s }
    s = s + len
  end
  pathP = s
  local m
  for _, m in pairs(pool) do m.s = nil end                          -- re-place dots on resize
end

local function PathPoint(s)
  s = math.mod(s, pathP)
  if s < 0 then s = s + pathP end
  local i
  for i = 1, 8 do
    local g = path[i]
    if s <= g.s + g.len or i == 8 then
      local u = 0
      if g.len > 0 then u = (s - g.s) / g.len end
      return g.x + g.ex * u, g.y + g.ey * u
    end
  end
end

-- where a ray from the screen centre in direction (sx, sy) meets the border path
local function PathHit(sx, sy)
  local i
  for i = 1, 8 do
    local g = path[i]
    local den = sx * g.ey - sy * g.ex
    if math.abs(den) > 1e-6 then
      local t = (g.x * g.ey - g.y * g.ex) / den
      local u = (g.x * sy - g.y * sx) / den
      if t > 0 and u >= -1e-6 and u <= 1 + 1e-6 then return g.s + u * g.len end
    end
  end
  return 0
end

-- push indicators apart along the path so every line stands on its own
local function Spread(list, need)
  local n = table.getn(list)
  if n < 2 then return end
  if n * need > pathP then need = pathP / n end
  table.sort(list, function(a, b) return a.s < b.s end)
  local it, i
  for it = 1, 40 do
    local moved = false
    for i = 1, n do
      local a, b = list[i], list[math.mod(i, n) + 1]
      local d = b.s - a.s
      if i == n then d = d + pathP end
      if d < need - .5 then
        local p = (need - d) / 2
        a.s, b.s = a.s - p, b.s + p
        moved = true
      end
    end
    if not moved then break end
  end
end

-- Estimate for mobs without a nameplate: a mob at bearing t (tan of its angle right of your facing)
-- shows about camA * t right of the screen centre (typical camera, about 90 deg at 4:3).
local function CamA()
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  return (W / 2) / (0.75 * W / H)
end

-- a nameplate that exists but sits outside the screen: its position from the screen centre
local function OffScreen(p)
  local cx, cy = p:GetCenter()
  if not cx then return nil end
  local k = p:GetEffectiveScale() / UIParent:GetEffectiveScale()
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  local x, y = cx * k - W / 2, cy * k - H / 2
  if math.abs(x) > W / 2 - 4 or math.abs(y) > H / 2 - 4 then return x, y end
  return nil
end

-- estimated path position for a mob without a nameplate: ahead and inside the view -> none (it is on
-- screen; the top edge gets no marks); outside the view -> down the side towards the bottom centre (straight behind)
local function ScreenS(fwd, left)
  local hx, hy = pathW / 2 - INSET, pathH / 2 - INSET
  local right = -left
  local A = CamA()
  if fwd > .01 then
    local x = A * (right / fwd)
    if math.abs(x) <= hx then return nil end                        -- ahead, in view: no mark on top
  end
  local side = (right >= 0) and 1 or -1                             -- screen side the mob is on
  local ang = math.atan2(math.abs(right), fwd)                      -- 0 ahead .. pi behind
  local edgeAng = math.atan2(hx, A)                                 -- where the view ends
  local u = (ang - edgeAng) / (math.pi - edgeAng)
  if u < 0 then u = 0 elseif u > 1 then u = 1 end
  local sc, sb = PathHit(hx, hy), PathHit(0, -1)                    -- top-right corner, bottom centre
  local x, y = PathPoint(sc + u * (sb - sc))
  return PathHit(side * x, y)
end

-- true for a path position on the flat top edge: no marks there, a mob in front of you is on screen
local function OnTop(s)
  if not s then return true end
  local g = path[1]
  local t = math.mod(s, pathP)
  if t < 0 then t = t + pathP end
  return t >= g.s and t <= g.s + g.len
end

local function BuildEdge()
  edge = CreateFrame("Frame", "CLpfUIThreatRingEdge", UIParent)
  edge:SetAllPoints(UIParent)
  edge:SetFrameStrata("FULLSCREEN")
  edge:EnableMouse(false)
end

local function GetMark(i)
  local m = pool[i]
  if m then return m end
  m = CreateFrame("Frame", nil, edge)
  m:SetAllPoints(edge)
  m.dots = NewDots(m, SEG)
  pool[i] = m
  return m
end

local function LayoutMark(m, s, len)
  if m.s == s and m.len == len then return end
  m.s, m.len = s, len
  local i
  for i = 1, SEG do
    local x, y = PathPoint(s + ((i - 1) / (SEG - 1) - .5) * len)
    local d = m.dots[i]
    d:ClearAllPoints()
    d:SetPoint("CENTER", UIParent, "CENTER", x, y)
  end
end

local function DrawEdge(cfg)
  local n = table.getn(marks)
  if n == 0 then
    if edge and edge:IsShown() then edge:Hide() end
    return
  end
  if not edge then BuildEdge() end
  local amul = .5 + .5 * ((cfg and cfg.strength) or 0.6)
  local pulse = .6 + .4 * math.sin(GetTime() * 3)
  local i
  for i = 1, MAXMARK do
    local k = marks[i]
    if k then
      local m = GetMark(i)
      LayoutMark(m, k.s, plateW)
      PaintDots(m.dots, SEG, k.frac, k.full, 5, 9, k.full and amul * pulse or amul)
      m:Show()
    elseif pool[i] then
      pool[i]:Hide()
    end
  end
  edge:Show()
end

local known = {}                                      -- hostile GUIDs seen recently (plates / target)

local function EdgePass(cfg, onPlate, warn, plateMarks)
  marks = plateMarks or {}
  if not (cfg.ringedge and EdgeStatus()) then
    marks = {}
    known = {}
    return
  end
  BuildPath()
  local guid
  for guid in pairs(known) do
    if not onPlate[guid] then
      if not Eligible(guid) then
        known[guid] = nil
      else
        local frac, full, d = Progress(guid, warn)
        if not d or d > 100 then
          known[guid] = nil
        elseif full or frac > 0 then
          local fwd, left = Rel(guid)
          if fwd then                                               -- screen up = ahead, left = left
            local ps = ScreenS(fwd, left)
            if not OnTop(ps) then table.insert(marks, { s = ps, frac = frac, full = full }) end
          end
        end
      end
    end
  end
  -- keep the ones closest to pulling, then space them out
  table.sort(marks, function(a, b)
    if a.full ~= b.full then return a.full end
    return a.frac > b.frac
  end)
  while table.getn(marks) > MAXMARK do table.remove(marks) end
  Spread(marks, plateW + GAP)
end

----------------------------------------------------------------------
-- driver
----------------------------------------------------------------------
local function Tick()
  local cfg = Cfg()
  local seen, onPlate = {}, {}
  if cfg and cfg.ring and SUPERWOW_VERSION then
    local warn = cfg.ringwarn or 15
    local plateMarks = {}
    local edgeReady = cfg.ringedge and EdgeStatus()
    if edgeReady then BuildPath() end
    local kids = { WorldFrame:GetChildren() }
    local i
    for i = 1, table.getn(kids) do
      local p = kids[i]
      if p ~= UIParent and p:IsVisible() and not p:GetName() then
        local okg, guid = pcall(p.GetName, p, 1)
        if okg and type(guid) == "string" and guid ~= "" and Eligible(guid) then
          onPlate[guid] = true
          known[guid] = true
          local frac, full = Progress(guid, warn)
          local ox, oy
          if edgeReady then ox, oy = OffScreen(p) end
          if ox then                                                -- plate exists but is off screen:
            if full or frac > 0 then                                -- mark the edge at its real position
              local ps = PathHit(ox, oy)
              if not OnTop(ps) then table.insert(plateMarks, { s = ps, frac = frac, full = full }) end
            end
          elseif full or frac > 0 then
            local r = GetRing(p)
            if Layout(r) then
              plateW = r.w
              seen[r] = true
              r:Show()
              Paint(r, frac, full)
              local fs = NameFS(p)
              if fs then
                if full then TintName(r, fs, 1, .29, .23)
                else TintName(r, fs, 1, .71 - .35 * frac, .23) end
              end
            end
          end
        end
      end
    end
    local okt, _, tg = pcall(UnitExists, "target")                -- SuperWoW: 2nd value is the GUID
    if okt and type(tg) == "string" and Eligible(tg) then known[tg] = true end
    EdgePass(cfg, onPlate, warn, plateMarks)
  else
    marks = {}
    known = {}
  end
  local p, r
  for p, r in pairs(rings) do
    if not seen[r] and r:IsShown() then HideRing(r) end
  end
end

local drv = CreateFrame("Frame")
local acc = 0
drv:SetScript("OnUpdate", function()
  if not CLpfUIThreatDB then return end
  acc = acc + arg1
  if acc >= 0.1 then
    acc = 0
    Tick()
  end
  -- slow pulse on connected rings
  local a = .6 + .4 * math.sin(GetTime() * 3)
  local r
  for r in pairs(pulsing) do r:SetAlpha(a) end
  DrawEdge(CLpfUIThreatDB)
end)

----------------------------------------------------------------------
-- /clpf ring ...   (called from the main file's slash handler)
----------------------------------------------------------------------
local function Where(Print)
  local cfg = Cfg()
  local ok, _, g = pcall(UnitExists, "target")
  if not (ok and type(g) == "string") then Print("Target a mob first (needs SuperWoW).") return end
  local fwd, left = Rel(g)
  local _, src = PlayerFacing()
  if not fwd then
    Print("Cannot work out direction: UnitPosition=" .. tostring(UnitPosition ~= nil) ..
      " facing=" .. tostring(src))
    return
  end
  local fb = fwd >= .38 and "ahead" or (fwd <= -.38 and "behind" or "")
  local lr = left >= .38 and "left" or (left <= -.38 and "right" or "")
  local where = fb .. ((fb ~= "" and lr ~= "") and "-" or "") .. lr
  if where == "" then where = "right here" end
  Print("Target is " .. where .. string.format("  (fwd=%.2f left=%.2f, facing from %s)", fwd, left, src))
end

function M.Slash(arg, Print)
  local cfg = Cfg()
  if not cfg then return end
  local _, _, a, b = string.find(arg or "", "^(%S*)%s*(.-)$")
  a = a or ""
  local n = tonumber(a)
  if n then
    if n < 3 then n = 3 elseif n > 40 then n = 40 end
    cfg.ringwarn = math.floor(n)
    Print("Aggro ring starts " .. cfg.ringwarn .. " yd before the edge")
    return
  end
  if a == "edge" then
    if b == "on" then cfg.ringedge = true elseif b == "off" then cfg.ringedge = false
    else cfg.ringedge = not cfg.ringedge end
    local ok, why = EdgeStatus()
    Print("Off-screen edge dots " .. (cfg.ringedge and "on" or "off") ..
      ((cfg.ringedge and not ok) and ("  |cffff6655" .. why .. "|r") or ""))
    return
  elseif a == "where" then
    Where(Print)
    return
  end
  if a == "on" then cfg.ring = true elseif a == "off" then cfg.ring = false else cfg.ring = not cfg.ring end
  Print("Aggro ring " .. (cfg.ring and "on" or "off") ..
    (HasUnitXP() and "  (UnitXP SP3 distance)" or "  |cffff6655no UnitXP SP3: coarse 10 / 28 yd steps, no edge dots|r") ..
    (SUPERWOW_VERSION and "" or "  |cffff6655needs SuperWoW|r"))
end

M.BUILD = "1.3.0-notop"                                 -- shown by /clpf debug to confirm the installed files

function M.Debug(Print)
  local cfg = Cfg()
  Print("ring module build=" .. M.BUILD)
  local n, k = 0, 0
  local p, r, g
  for p, r in pairs(rings) do if r:IsShown() then n = n + 1 end end
  for g in pairs(known) do k = k + 1 end
  local ok, why = EdgeStatus()
  local _, src = PlayerFacing()
  Print("ring=" .. tostring(cfg and cfg.ring) .. " ringwarn=" .. tostring(cfg and cfg.ringwarn) ..
    " SuperWoW=" .. tostring(SUPERWOW_VERSION ~= nil) .. " UnitXP=" .. tostring(HasUnitXP()) .. " ringsShown=" .. n)
  Print("edge=" .. tostring(cfg and cfg.ringedge) .. " ready=" .. tostring(ok) .. (why and (" (" .. why .. ")") or "") ..
    " facing=" .. tostring(src) .. " tracked=" .. k .. " shownNow=" .. table.getn(marks) .. "")
end
