-- pandaUI :: core/mover.lua
--
-- The shared mover system. Modules register the frames they want the user to
-- be able to place; unlocking shows a drag handle over each one.
--
-- Deliberately small. This is not pfUI's mover/config framework: it provides
-- only an alignment grid, nearby-mover magnets, pixel nudging and an opt-in
-- per-anchor scale -- no configuration machinery. Only intended pandaUI
-- elements are ever registered. Explicitly requested native widgets use either
-- their native root (modules/minimap.lua) or an pandaUI-owned placement anchor
-- (modules/durabilityframe.lua); their artwork and visibility remain
-- client-owned.

local U = PandaUI
local M = U.media

local movers = {}       -- id -> entry
local moverOrder = {}
local unlocked = false
local activeMover
-- Snap tracer state. One table rather than a set of loose locals, per
-- rules/pandaui.md: a diagnostic has no business spending top-level slots.
local trace = { on = false, samples = {}, max = 400, seq = 0, dropped = 0,
                current = nil, startedAt = nil, reason = nil, before = nil,
                -- Diagnostic logs beside the snap samples: what the mouse is
                -- over, anchors that move on their own, and store writes.
                focus = {}, drift = {}, events = {}, rects = {},
                maxLog = 300, lastFocus = nil, nextDrift = 0,
                lockedAt = nil, afterLock = nil, LOCK_WATCH = 20 }
local grid, editPanel, editKeys, alignmentGuides, clickCatcher
local IsEntryAvailable, IsEntryVisible
local UpdateAlignmentGuides, HideAlignmentGuides
local advanced = {
  width = 350,
  -- Eleven rows of the game settings checkbox, 22 apart from 40 down.
  height = 292,
  rowSpacing = 22,
  closedWidth = 1,
  duration = 0.22,
  currentWidth = 1,
  open = false,
  rows = {},
  hiddenEntries = {},
  hiddenCount = 0,
  groupLookup = {},
  -- One callback per group key: the module that owns an element registers it
  -- so its own views re-read the switch this drawer just wrote.
  changed = {},
  rowsPerColumn = 11,
  columnWidth = 162,
  groups = {
    { key = "petbar", labelKey = "MOVER_LABEL_PET_BAR",
      movers = { "petbar" } },
    { key = "petunit", labelKey = "MOVER_LABEL_PET_UNIT_FRAME",
      movers = { "unitframes.pet", "castbar.pet" } },
    { key = "buffs", labelKey = "MOVER_LABEL_BUFFS",
      nativeAuras = true, movers = { "buffs", "debuffs" } },
    { key = "swingbar", labelKey = "MOVER_LABEL_SWING_BAR",
      setting = { module = "swingbar", key = "enabled", default = true,
                  apply = "ApplySwingBar" }, movers = { "swingbar" } },
    { key = "targettarget", labelKey = "MOVER_LABEL_TARGET_TARGET",
      movers = { "unitframes.targettarget" } },
    { key = "targetcast", labelKey = "MOVER_LABEL_TARGET_CASTBAR",
      movers = { "castbar.target" } },
    { key = "xpbar", labelKey = "MOVER_LABEL_XP_BAR",
      movers = { "xpbar.xp" } },
    { key = "repbar", labelKey = "MOVER_LABEL_REP_BAR",
      setting = { module = "xpbar", key = "repEnabled", default = false,
                  apply = "ApplyXPBar" }, movers = { "xpbar.reputation" } },
    -- keepAnchor: switched off, the overlay hides its own content and its
    -- anchor stays in edit mode, so it can be switched back on there.
    { key = "status", labelKey = "MOVER_LABEL_STATUS", keepAnchor = true,
      setting = { module = "status", key = "enabled", default = true,
                  apply = "ApplyStatusOverlay" },
      movers = { "status.overlay" } },
    { key = "online", labelKey = "MOVER_LABEL_ONLINE_COUNT", keepAnchor = true,
      setting = { module = "status", key = "onlineEnabled", default = true,
                  apply = "ApplyOnlineOverlay" },
      movers = { "status.population" } },
    { key = "microbar", labelKey = "MOVER_LABEL_MICRO_BAR",
      setting = { module = "microbar", key = "enabled", default = true,
                  apply = "ApplyMicroBar" }, movers = { "microbar" } },
    { key = "actionbar1", labelKey = "MOVER_LABEL_ACTION_BAR", labelArg = 1,
      actionBar = 1, movers = { "actionbar.bar1", "actionbar.native1" } },
    { key = "actionbar2", labelKey = "MOVER_LABEL_ACTION_BAR", labelArg = 2,
      actionBar = 2, movers = { "actionbar.bar2" } },
    { key = "actionbar3", labelKey = "MOVER_LABEL_ACTION_BAR", labelArg = 3,
      actionBar = 3, movers = { "actionbar.bar3" } },
    { key = "actionbar4", labelKey = "MOVER_LABEL_ACTION_BAR", labelArg = 4,
      actionBar = 4, movers = { "actionbar.bar4" } },
    { key = "actionbar5", labelKey = "MOVER_LABEL_ACTION_BAR", labelArg = 5,
      actionBar = 5, movers = { "actionbar.bar5" } },
    { key = "actionbar6", labelKey = "MOVER_LABEL_ACTION_BAR", labelArg = 6,
      actionBar = 6, movers = { "actionbar.bar6" } },
    { key = "actionbar7", labelKey = "MOVER_LABEL_ACTION_BAR", labelArg = 7,
      actionBar = 7, movers = { "actionbar.bar7" } },
    { key = "actionbar8", labelKey = "MOVER_LABEL_ACTION_BAR", labelArg = 8,
      actionBar = 8, movers = { "actionbar.bar8" } },
    { key = "actionbar9", labelKey = "MOVER_LABEL_ACTION_BAR", labelArg = 9,
      actionBar = 9, movers = { "actionbar.bar9" } },
    { key = "actionbar10", labelKey = "MOVER_LABEL_ACTION_BAR", labelArg = 10,
      actionBar = 10, movers = { "actionbar.bar10" } },
  },
  moverKeys = {
    petbar = "petbar",
    ["unitframes.pet"] = "petunit",
    ["castbar.pet"] = "petunit",
    buffs = "buffs",
    debuffs = "buffs",
    swingbar = "swingbar",
    ["unitframes.targettarget"] = "targettarget",
    ["castbar.target"] = "targetcast",
    ["xpbar.xp"] = "xpbar",
    ["xpbar.reputation"] = "repbar",
    ["status.overlay"] = "status",
    ["status.population"] = "online",
    microbar = "microbar",
    ["actionbar.bar1"] = "actionbar1",
    ["actionbar.native1"] = "actionbar1",
    ["actionbar.bar2"] = "actionbar2",
    ["actionbar.bar3"] = "actionbar3",
    ["actionbar.bar4"] = "actionbar4",
    ["actionbar.bar5"] = "actionbar5",
    ["actionbar.bar6"] = "actionbar6",
    ["actionbar.bar7"] = "actionbar7",
    ["actionbar.bar8"] = "actionbar8",
    ["actionbar.bar9"] = "actionbar9",
    ["actionbar.bar10"] = "actionbar10",
  },
  moverActionBars = {
    ["actionbar.bar1"] = 1, ["actionbar.native1"] = 1,
    ["actionbar.bar2"] = 2,
    ["actionbar.bar3"] = 3, ["actionbar.bar4"] = 4,
    ["actionbar.bar5"] = 5, ["actionbar.bar6"] = 6,
    ["actionbar.bar7"] = 7, ["actionbar.bar8"] = 8,
    ["actionbar.bar9"] = 9, ["actionbar.bar10"] = 10,
  },
}

-- Frames that are drag-placed outside this system still store their position
-- through U.SavePosition, so /pui reset has to be able to put them back. They
-- register a callback rather than a mover entry because their default anchor
-- is not UIParent-relative and cannot be expressed as a mover default -- the
-- minimap settings button sits beside Minimap, not at a screen coordinate.
local resetHooks = {}

-- Edit-mode grid. Sized in UIParent units (U.UIWidth / U.UIHeight, which are
-- GetScreenWidth / GetScreenHeight on OctoWoW -- core/compat.lua).
local DEFAULT_GRID_SIZE = 20
local MIN_GRID_SIZE = 5
local MAX_GRID_SIZE = 50
local MAGNET_DISTANCE = 8
local ALIGNMENT_EPSILON = 0.01

local function MoverConfig()
  -- Read every frame while a mover is switched off: return the saved table
  -- without building the defaults below when nothing needs filling in
  -- (knowledge.json / perf.pandaui_only_stutter).
  local modules = U.db and U.db.modules
  local saved = type(modules) == "table" and modules.mover
  if type(saved) == "table" and type(saved.gridShown) == "boolean" and
     type(saved.gridSize) == type(DEFAULT_GRID_SIZE) and
     type(saved.magnet) == "boolean" and
     type(saved.groupTouching) == "boolean" and
     type(saved.anchorEnabled) == "table" and type(saved.scales) == "table" then
    return saved
  end
  return U.ModuleConfig("mover", {
    gridShown = true,
    gridSize = DEFAULT_GRID_SIZE,
    magnet = true,
    -- Anchors that touch travel as one block. Off moves the anchor under the
    -- cursor and nothing else, for placing a single element out of a stack.
    -- Off by default.
    groupTouching = false,
    anchorEnabled = {},
    -- Player scale per scalable mover id, in percent; absent means 100.
    scales = {},
  })
end

local function GridSize()
  local size = tonumber(MoverConfig().gridSize) or DEFAULT_GRID_SIZE
  size = math.floor(size + 0.5)
  if size < MIN_GRID_SIZE then size = MIN_GRID_SIZE end
  if size > MAX_GRID_SIZE then size = MAX_GRID_SIZE end
  return size
end

-- ---------------------------------------------------------------------------
-- Position handling
--
-- Anchors are read through U.GetFramePoint (SetPoint's own tuple on 1.12,
-- knowledge.json / layout.getpoint_y_sign_native_on_112) and positions through
-- U.GetFramePlacement. Two approaches recorded as failed are avoided here:
--
--   * persisting the raw GetPoint tuple as if it were Blizzard-compatible
--   * recapturing a point and immediately clearing/re-applying it
--
-- so a drop is captured and stored, and the frame is left exactly where the
-- user released it rather than being re-anchored on the spot.
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- Bottom-anchored windows
--
-- A window whose height follows its content grows away from the point it is
-- anchored by, so one the client left on a TOP* corner pushes its lower rows
-- off the bottom of the screen as it gets taller. The bag's category view is
-- the first PandaUI window that changes height this way. anchorEdge =
-- "BOTTOM" pins such a frame by its bottom edge instead, so it can only ever
-- extend upwards, and the converted point is stored so a reload keeps it.
--
-- The conversion is done in screen space rather than by arithmetic over the
-- stored offsets: GetLeft/GetBottom report where the frame actually is, so one
-- expression covers whichever of the eight point names a drag was collapsed
-- onto, with no second Y convention to get wrong. Reading a rect and then
-- applying a stored-shaped point is the direction knowledge.json /
-- frames.getpoint_relative_name_y_inverted confirms works; the failed approach
-- that record warns about -- recapturing through GetPoint and immediately
-- re-applying that same tuple -- is not what happens here.
-- ---------------------------------------------------------------------------
local BOTTOM_POINTS = { BOTTOM = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }

local function Edge(frame, method)
  local fn = frame and frame[method]
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, frame)
  if not ok then return nil end
  return tonumber(value)
end

-- UIParent units per unit of a mover's frame (U.FrameUIRatio).
--
-- On 1.12 a frame's GetLeft/GetBottom/GetWidth/GetHeight/GetCenter and its
-- SetPoint offsets are all in the frame's OWN units (knowledge.json /
-- layout.own_scale_space_on_112). This file therefore works in two spaces:
--
--   * positions -- stored, applied, read back (U.GetFramePlacement) -- stay
--     in the frame's own units, exactly as SetPoint takes them;
--   * every comparison -- grid, magnet, collision, screen centre, the
--     alignment guides, the cursor -- is made in UIParent units: own value *
--     this ratio, and a UIParent-unit correction goes back as delta / ratio.
--
-- 1 for an unscaled UIParent child, so every such mover behaves exactly as
-- before. The scaled ones are the modern-wow frames (mw.ApplyFrameScale: the
-- pixel scale, times 0.75 on the cast bars). The comment this replaces
-- recorded Unreal Azeroth, where own scale left geometry in the parent's units
-- (frames.own_scale_resizes_about_anchor_in_parent_space); that measurement
-- does not hold here.
local function EntryScale(entry)
  local frame = entry and entry.frame
  if not frame or type(U.FrameUIRatio) ~= "function" then return 1 end
  local ratio = tonumber(U.FrameUIRatio(frame))
  if not ratio or ratio <= 0 then return 1 end
  return ratio
end

local function NormaliseAnchorEdge(entry)
  if not entry or entry.anchorEdge ~= "BOTTOM" then return end

  -- Already growing upwards: a frame held by any bottom point keeps its bottom
  -- edge when it is resized, which is the whole point of the conversion.
  local stored = U.GetPosition(entry.id)
  local active = stored or entry.default
  if active and BOTTOM_POINTS[active.point] then return end

  local left = Edge(entry.frame, "GetLeft")
  local bottom = Edge(entry.frame, "GetBottom")
  if not left or not bottom then
    -- A frame registered during load can have no resolved rect yet, and this
    -- runs from RegisterMover. Failing quietly there would leave the window
    -- top-anchored for the whole session, so retry once on the next
    -- shared-driver tick before giving up.
    if entry.anchorEdgeRetried then
      U.Debug("mover " .. entry.id .. ": no readable rect to bottom-anchor")
      return
    end
    entry.anchorEdgeRetried = true

    local update = "mover.anchorEdge." .. entry.id
    U.RegisterUpdate(update, 0, function()
      U.UnregisterUpdate(update)
      NormaliseAnchorEdge(entry)
    end)
    return
  end

  -- UIParent's origin is subtracted rather than assumed to be (0, 0), so a
  -- client that does not place it flush with the screen corner still converts
  -- to the right offsets. The frame's edges and the offsets are in its own
  -- units; UIParent's origin is in UIParent's, so it is divided by the ratio
  -- (EntryScale).
  local ratio = EntryScale(entry)
  local x = left - (Edge(UIParent, "GetLeft") or 0) / ratio
  local y = bottom - (Edge(UIParent, "GetBottom") or 0) / ratio

  if not U.ApplyFramePoint(entry.frame, {
       point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = x, y = y }) then
    U.Debug("mover " .. entry.id .. ": failed to apply bottom anchor")
    return
  end

  -- Only a position the player actually placed is written back. A frame still
  -- sitting on its default is re-derived from that default on every login, so
  -- persisting one here would invent a saved placement nobody made.
  if stored then
    U.SavePosition(entry.id, "BOTTOMLEFT", "BOTTOMLEFT", x, y)
  end
end

local function ApplyStoredPosition(entry)
  local saved = U.GetPosition(entry.id)
  local position = saved or entry.default
  if not position then return false end
  -- A placement stored on a larger screen or UI scale is pulled back inside
  -- this one (core/screenguard.lua). Applied only, not re-saved: going back to
  -- the larger screen restores the original placement.
  local clamped
  position, clamped = U.ClampPositionToScreen(entry.frame, position)
  -- Remembered so the screen watch below can release the clamp again when the
  -- UI scale goes back down.
  entry.clamped = clamped and true or nil

  local applied = U.ApplyFramePoint(entry.frame, position)
  if not applied then
    U.Debug("mover " .. entry.id .. ": failed to apply position")
    return false
  end

  if saved then
    U.Debug("mover " .. entry.id .. ": restored saved position")
  end
  trace.Event("apply", entry, position, { fromSaved = saved and true or false })

  NormaliseAnchorEdge(entry)
  return true
end

-- Snapping
--
-- The live drag path derives its unconstrained position from the cursor delta
-- at the start of the drag, then applies grid and magnet constraints on the
-- shared driver. Keeping that original cursor origin is important: restarting
-- StartMoving after every snap would continually rebase the grab offset and
-- leave a frame stuck on its first grid line.
--
-- knowledge.json / frames.getpoint_relative_name_y_inverted lists "recapturing
-- then immediately clearing/reapplying the same point" as a failed approach,
-- while the same record confirms that applying a *stored* point with SetPoint
-- restores a frame correctly. The final drop is still captured, stored, and
-- re-applied on the next shared-driver tick; live feedback applies a newly
-- calculated cursor-relative point rather than replaying a raw GetPoint tuple.
local pendingSnap

local function SnapValue(value)
  value = tonumber(value) or 0
  local size = GridSize()
  return math.floor(value / size + 0.5) * size
end

-- Magnetic snapping uses the stored UIParent-relative positions and frame
-- dimensions, never the live edges, so a request can be judged before it is
-- applied. Both are in the frame's own units; MoverBounds converts them to
-- UIParent units (EntryScale), the one space every mover is compared in.
local function PointFactor(point, low, high)
  if type(point) ~= "string" then return 0.5 end
  if string.find(point, low, 1, true) then return 0 end
  if string.find(point, high, 1, true) then return 1 end
  return 0.5
end

local function MoverBounds(entry, position)
  if not entry or type(position) ~= "table" then return nil end

  local widthOk, width = pcall(entry.frame.GetWidth, entry.frame)
  local heightOk, height = pcall(entry.frame.GetHeight, entry.frame)
  width, height = tonumber(width), tonumber(height)
  if not widthOk or not heightOk or not width or not height or
     width <= 0 or height <= 0 then return nil end

  -- Offsets and dimensions are in the frame's own units; the rectangle is
  -- returned in UIParent units. UIParent's relative point is a UIParent-unit
  -- position, the offset and size scale by the ratio (EntryScale).
  local ratio = EntryScale(entry)
  width, height = width * ratio, height * ratio
  local x = (tonumber(position.x) or 0) * ratio
  local y = (tonumber(position.y) or 0) * ratio
  local relativePoint = position.relativePoint or position.point
  local left = U.UIWidth() * PointFactor(relativePoint, "LEFT", "RIGHT") + x -
               width * PointFactor(position.point, "LEFT", "RIGHT")
  local bottom = U.UIHeight() * PointFactor(relativePoint, "BOTTOM", "TOP") + y -
                 height * PointFactor(position.point, "BOTTOM", "TOP")
  return left, left + width, bottom, bottom + height
end

local function IntervalsNear(aLow, aHigh, bLow, bHigh)
  return aLow <= bHigh + MAGNET_DISTANCE and
         aHigh >= bLow - MAGNET_DISTANCE
end

-- Edges that touch are not an overlap. The tolerance matters: a flush magnet
-- snap reproduces the neighbour's edge through float arithmetic, and a
-- hundredth over read as a collision would push the anchor back out.
local function Overlaps(left, right, bottom, top,
                        otherLeft, otherRight, otherBottom, otherTop)
  return left < otherRight - ALIGNMENT_EPSILON and
         right > otherLeft + ALIGNMENT_EPSILON and
         bottom < otherTop - ALIGNMENT_EPSILON and
         top > otherBottom + ALIGNMENT_EPSILON
end

-- limit is the reach for this candidate; bestDistance the closest kept so far.
local function ClosestDelta(candidate, best, bestDistance, limit)
  local distance = math.abs(candidate)
  if distance <= (limit or MAGNET_DISTANCE) and distance < bestDistance then
    return candidate, distance
  end
  return best, bestDistance
end

-- Snap reach and spacing (knowledge.json mover.magnet_snaps_thin_bars_flush).
-- A fixed 8-unit reach was wider than the 7-unit XP and reputation bars: every
-- gap under 8 closed to flush, and with several lines per bar inside 8 units
-- the bar jumped between targets.
-- SPACING: the space every magnet join leaves between two anchors' drawn
-- edges (user request 2026-11-03: at most 1-2 px between joined elements).
local magnet = { MIN_REACH = 3, BIG = 1000000, SPACING = 1 }

-- Half the thinner of the two anchors on that axis, between MIN_REACH and
-- MAGNET_DISTANCE, then capped (half a grid cell with the grid on).
function magnet.Reach(size, otherSize, cap)
  local reach = tonumber(size) or MAGNET_DISTANCE * 2
  if otherSize and otherSize < reach then reach = otherSize end
  reach = reach / 2
  if reach > MAGNET_DISTANCE then reach = MAGNET_DISTANCE end
  if reach < magnet.MIN_REACH then reach = magnet.MIN_REACH end
  if cap and cap < reach then reach = cap end
  return reach + ALIGNMENT_EPSILON
end

-- The empty space between two intervals on one axis; 0 when they overlap.
function magnet.Gap(low, high, otherLow, otherHigh)
  if otherLow > high then return otherLow - high end
  if low > otherHigh then return low - otherHigh end
  return 0
end

-- How far an anchor's drawn art reaches past its box, as left, right,
-- bottom, top in UIParent units. RegisterMover option snapPadding: a number
-- for every side, or a function returning x, y or left, right, bottom, top in
-- the frame's own units. Two anchors join with the facing sides' paddings
-- plus SPACING between their boxes; most anchors draw inside their box and
-- have none.
-- The larger of snapPadding and the measured snapArt on each side. Cached
-- for the length of a drag (magnet.cache, set by StartDrag): nothing being
-- measured changes while one anchor is dragged.
function magnet.Padding(entry)
  if not entry then return 0, 0, 0, 0 end
  local cached = magnet.cache and magnet.cache[entry]
  if cached then return cached[1], cached[2], cached[3], cached[4] end
  local l, r, b, t = magnet.FixedPadding(entry)
  if entry.snapArt then
    local al, ar, ab, at = magnet.ArtPadding(entry)
    if al > l then l = al end
    if ar > r then r = ar end
    if ab > b then b = ab end
    if at > t then t = at end
  end
  if magnet.cache then magnet.cache[entry] = { l, r, b, t } end
  return l, r, b, t
end

-- RegisterMover option snapArt: a function returning a list of
-- { region = <Texture/FontString/Frame>, m = { l, r, b, t } }, m being the
-- transparent fraction of the region's drawn quad on each screen side
-- (measured offline from the texture's alpha). Each visible region's opaque
-- part past the anchor's box, per side, in UIParent units. An empty
-- FontString draws nothing and is skipped.
magnet.NO_MARGIN = { 0, 0, 0, 0 }

function magnet.ArtPadding(entry)
  local ok, list = pcall(entry.snapArt)
  if not ok or type(list) ~= "table" then return 0, 0, 0, 0 end
  local frame = entry.frame
  local fl, fr = Edge(frame, "GetLeft"), Edge(frame, "GetRight")
  local fb, ft = Edge(frame, "GetBottom"), Edge(frame, "GetTop")
  local frameScale = Edge(frame, "GetEffectiveScale")
  if not fl or not fr or not fb or not ft or not frameScale or
     frameScale <= 0 then return 0, 0, 0, 0 end
  local l, r, b, t, i = 0, 0, 0, 0, nil
  for i = 1, table.getn(list) do
    local region = list[i] and list[i].region
    local m = list[i] and list[i].m or magnet.NO_MARGIN
    local okV, visible = false, nil
    if region then okV, visible = pcall(region.IsVisible, region) end
    if okV and visible then
      local okK, kind = pcall(region.GetObjectType, region)
      if okK and kind == "FontString" then
        local okT, text = pcall(region.GetText, region)
        if not okT or not text or text == "" then visible = nil end
      end
    end
    local rl, rr = Edge(region, "GetLeft"), Edge(region, "GetRight")
    local rb, rt = Edge(region, "GetBottom"), Edge(region, "GetTop")
    if okV and visible and rl and rr and rb and rt and rr > rl and
       rt > rb then
      -- A region reports edges in its own frame's units.
      local okP, owner = pcall(region.GetParent, region)
      local k = okP and Edge(owner, "GetEffectiveScale")
      k = k and k / frameScale or 1
      rl, rr, rb, rt = rl * k, rr * k, rb * k, rt * k
      local w, h = rr - rl, rt - rb
      -- The opaque part, then each side only where it lies over the box on
      -- the other axis: an ornament wholly beside the box (bar 1's gryphons)
      -- widens it sideways but not above or below.
      local vl, vr = rl + m[1] * w, rr - m[2] * w
      local vb, vt = rb + m[3] * h, rt - m[4] * h
      if vt > fb and vb < ft then
        if fl - vl > l then l = fl - vl end
        if vr - fr > r then r = vr - fr end
      end
      if vr > fl and vl < fr then
        if fb - vb > b then b = fb - vb end
        if vt - ft > t then t = vt - ft end
      end
    end
  end
  local ratio = EntryScale(entry)
  return l * ratio, r * ratio, b * ratio, t * ratio
end

-- snapPadding on its own (see magnet.Padding).
function magnet.FixedPadding(entry)
  local pad = entry and entry.snapPadding
  if not pad then return 0, 0, 0, 0 end
  local l, r, b, t
  if type(pad) == "function" then
    local ok, p1, p2, p3, p4 = pcall(pad)
    if not ok then return 0, 0, 0, 0 end
    l, r, b, t = tonumber(p1) or 0, tonumber(p2), tonumber(p3), tonumber(p4)
    if not b then
      -- x, y form.
      b, t = r or l, r or l
      r = l
    end
  else
    l = tonumber(pad) or 0
  end
  r, b = r or l, b or l
  t = t or b
  local ratio = EntryScale(entry)
  return l * ratio, r * ratio, b * ratio, t * ratio
end

-- Alt held: the drag follows the cursor with no grid, magnet or alignment.
function magnet.Free()
  local fn = U.G("IsAltKeyDown")
  if type(fn) ~= "function" then return false end
  local ok, down = pcall(fn)
  return ok and down and down ~= 0 and true or false
end

-- Smart alignment along one axis: the anchor's low edge, centre and high edge
-- onto the same line of another anchor (low-low, centre-centre, high-high).
-- The six cross pairs (centre onto an edge, an edge onto the opposite edge)
-- are gone: on thin anchors they put a target every few units and the snap
-- jumped between them. Edge-to-opposite-edge is the magnet's contact pull.
local function AlignDelta(low, high, otherLow, otherHigh,
                          best, bestDistance, limit)
  local mid, otherMid = (low + high) / 2, (otherLow + otherHigh) / 2
  best, bestDistance = ClosestDelta(otherLow - low, best, bestDistance, limit)
  best, bestDistance = ClosestDelta(otherMid - mid, best, bestDistance, limit)
  best, bestDistance = ClosestDelta(otherHigh - high, best, bestDistance,
                                    limit)
  return best, bestDistance
end

-- The other anchor's line that one of the anchor's own three lines sits
-- exactly on (same-line pairs only, as AlignDelta), or nil. Drives the red
-- alignment guide.
local function AlignedLine(low, high, otherLow, otherHigh)
  local mid = (low + high) / 2
  local otherMid = (otherLow + otherHigh) / 2
  if math.abs(low - otherLow) <= ALIGNMENT_EPSILON then return otherLow end
  if math.abs(mid - otherMid) <= ALIGNMENT_EPSILON then return otherMid end
  if math.abs(high - otherHigh) <= ALIGNMENT_EPSILON then return otherHigh end
  return nil
end

-- Alignment only considers anchors near on the other axis: within a quarter
-- of the screen. Far anchors no longer capture the drag.
function magnet.Near(low, high, otherLow, otherHigh, screenSize)
  return magnet.Gap(low, high, otherLow, otherHigh) <= screenSize / 4
end

-- Where a frame is, as { point, relative, relativePoint, x, y }. A UIParent
-- child's offsets come from its measured edges (U.GetFramePlacement,
-- core/screenguard.lua), which also re-expresses a point named by another
-- anchoring as a UIParent one.
--
-- A frame parented elsewhere but anchored to UIParent is measured by its edges
-- too: its edges and its offsets share its own units on 1.12, so UIParent's
-- origin and size are divided into them by the ratio (EntryScale). Any other
-- frame falls back to the point read, whose offsets are SetPoint's own on 1.12
-- (U.GetFramePoint).
local function ReadPlacement(frame)
  local placement = U.GetFramePlacement(frame)
  if placement then
    placement.relative = UIParent
    return placement
  end
  local point, relative, relativePoint, x, y = U.GetFramePoint(frame, 1)
  if not point then return nil end
  relativePoint = relativePoint or point

  local ratio = EntryScale({ frame = frame })
  local left, bottom = Edge(frame, "GetLeft"), Edge(frame, "GetBottom")
  local width, height = Edge(frame, "GetWidth"), Edge(frame, "GetHeight")
  if (not relative or relative == UIParent) and left and bottom and
     width and height then
    left = left - (Edge(UIParent, "GetLeft") or 0) / ratio
    bottom = bottom - (Edge(UIParent, "GetBottom") or 0) / ratio
    x = left + width * PointFactor(point, "LEFT", "RIGHT") -
        U.UIWidth() / ratio * PointFactor(relativePoint, "LEFT", "RIGHT")
    y = bottom + height * PointFactor(point, "BOTTOM", "TOP") -
        U.UIHeight() / ratio * PointFactor(relativePoint, "BOTTOM", "TOP")
  end
  return { point = point, relative = relative,
           relativePoint = relativePoint, x = x, y = y }
end

-- Where an anchor is, as the player sees it. The stored tuple can differ from
-- the drawn frame after load (knowledge.json /
-- mover.first_arrow_nudge_replays_stale_saved_position), so arrow nudges, scale
-- changes and snapping start from the live UIParent placement and use the
-- stored or default tuple only when the frame cannot be read that way.
local function EntryPosition(entry)
  local placement = ReadPlacement(entry.frame)
  if placement and (not placement.relative or
                    placement.relative == UIParent) then
    return placement
  end
  return U.GetPosition(entry.id) or entry.default
end

-- The other anchors do not move while one is dragged, so a drag reads each of
-- their placements once instead of allocating them again on every tick.
local dragPlacements

local function OtherPosition(other)
  if not dragPlacements then return EntryPosition(other) end
  local position = dragPlacements[other]
  if position == nil then
    position = EntryPosition(other) or false
    dragPlacements[other] = position
  end
  return position or nil
end

-- ---------------------------------------------------------------------------
-- Per-anchor scale (edit mode "Scale (%)")
--
-- A mover registered with `scalable = true` gets a player scale, stored in
-- percent under the mover config's `scales[id]`. It multiplies the scale the
-- owner gives the frame (entry.baseScale: the modern-wow pixel scale, the cast
-- bar trim, or 1). An owner that rescales a scalable frame goes through
-- U.SetMoverBaseScale, so the player's scale is kept.
--
-- Offsets are in the frame's own units on 1.12 (knowledge.json /
-- layout.own_scale_space_on_112), so a new scale alone would move the frame.
-- The placement is converted by old/new scale, which keeps the frame's anchor
-- point where it was on screen.
-- ---------------------------------------------------------------------------
local scaling = { MIN = 50, MAX = 200, STEP = 5, byFrame = {}, preview = nil }

function scaling.Percent(entry, value)
  value = tonumber(value)
  if not value then
    local stored = MoverConfig().scales
    value = type(stored) == "table" and tonumber(stored[entry.id]) or nil
  end
  if not value then return 100 end
  value = math.floor(value / scaling.STEP + 0.5) * scaling.STEP
  if value < scaling.MIN then value = scaling.MIN end
  if value > scaling.MAX then value = scaling.MAX end
  return value
end

function scaling.Factor(entry, percent)
  if not entry or not entry.scalable then return 1 end
  return scaling.Percent(entry, percent) / 100
end

-- The scalable mover nearest above `frame` in its parent chain, or nil.
function scaling.Ancestor(frame)
  local depth = 0
  local ok, parent = pcall(frame.GetParent, frame)
  while ok and parent and depth < 20 do
    local entry = scaling.byFrame[parent]
    if entry then return entry end
    ok, parent = pcall(parent.GetParent, parent)
    depth = depth + 1
  end
  return nil
end

-- A scalable mover's own Scale (%) replaces an ancestor anchor's rather than
-- compounding it: the target-of-target frame is a child of the target frame,
-- and rescaling the target moved and resized it (user report 2026-10-25). The
-- inherited factor is divided back out, so the frame's effective scale stays
-- its own and a free-placed child keeps its screen position; a docked one
-- still follows its parent's edge. appliedFactor is the live factor, preview
-- included, so children follow a held slider too.
function scaling.Apply(entry, percent)
  local frame = entry.frame
  local factor = scaling.Factor(entry, percent)
  entry.appliedFactor = factor
  local inherited = U.MoverAncestorScale(frame)
  pcall(frame.SetScale, frame, (entry.baseScale or 1) * factor / inherited)
  if type(entry.onScale) == "function" then pcall(entry.onScale, factor) end
  scaling.ApplyChildren(entry)
end

-- Re-applies every scalable mover whose nearest scalable ancestor is `entry`;
-- each of those does the same for its own, so the whole subtree follows.
function scaling.ApplyChildren(entry)
  local frame, child
  for frame, child in pairs(scaling.byFrame) do
    if child ~= entry and scaling.Ancestor(frame) == entry then
      scaling.Apply(child)
    end
  end
end

function scaling.FrameScale(frame)
  local ok, value = pcall(frame.GetScale, frame)
  value = ok and tonumber(value) or nil
  if not value or value <= 0 then return nil end
  return value
end

-- The placement and frame scale a change starts from, captured once so a live
-- preview never compounds its own conversion.
function scaling.Reference(entry)
  return { id = entry.id, position = EntryPosition(entry),
           scale = scaling.FrameScale(entry.frame) }
end

function scaling.Place(entry, ref, store)
  local position = ref and ref.position
  local now = scaling.FrameScale(entry.frame)
  if not position or not ref.scale or not now then return end
  local ratio = ref.scale / now
  local moved = {
    point = position.point,
    relativePoint = position.relativePoint or position.point,
    x = (tonumber(position.x) or 0) * ratio,
    y = (tonumber(position.y) or 0) * ratio,
  }
  U.ApplyFramePoint(entry.frame, moved)
  if store and math.abs(ratio - 1) > ALIGNMENT_EPSILON then
    U.SavePosition(entry.id, moved.point, moved.relativePoint, moved.x, moved.y)
  end
end

function U.MoverScalable(id)
  local entry = type(id) == "string" and movers[id] or nil
  return entry and entry.scalable and true or false
end

function U.MoverScaleRange()
  return scaling.MIN, scaling.MAX, scaling.STEP
end

-- The player's scale for a mover, in percent (100 = the owner's own size).
function U.GetMoverScale(id)
  local entry = type(id) == "string" and movers[id] or nil
  if not entry or not entry.scalable then return 100 end
  return scaling.Percent(entry)
end

-- Live while the slider thumb is held; nothing is stored until it is released.
function U.PreviewMoverScale(id, percent)
  local entry = type(id) == "string" and movers[id] or nil
  if not entry or not entry.scalable then return false end
  if not scaling.preview or scaling.preview.id ~= id then
    scaling.preview = scaling.Reference(entry)
  end
  scaling.Apply(entry, percent)
  scaling.Place(entry, scaling.preview, false)
  return true
end

function U.SetMoverScale(id, percent)
  local entry = type(id) == "string" and movers[id] or nil
  if not entry or not entry.scalable then return nil end
  local ref = scaling.preview
  if not ref or ref.id ~= id then ref = scaling.Reference(entry) end
  scaling.preview = nil

  percent = scaling.Percent(entry, percent)
  local scales = MoverConfig().scales
  if percent == 100 then scales[id] = nil else scales[id] = percent end
  scaling.Apply(entry)
  scaling.Place(entry, ref, true)
  return percent
end

-- For a module that sets its own scale on a frame that may be a scalable
-- mover: the player's scale is multiplied in rather than overwritten.
function U.SetMoverBaseScale(frame, base)
  if not frame or type(frame.SetScale) ~= "function" then return false end
  base = tonumber(base) or 1
  local entry = scaling.byFrame[frame]
  if not entry then return pcall(frame.SetScale, frame, base) end
  entry.baseScale = base
  scaling.Apply(entry)
  return true
end

-- The player scale `frame` inherits from its scalable ancestors. Each scalable
-- mover cancels its own ancestors' factor (scaling.Apply), so only the nearest
-- one's live factor reaches a descendant. A child that cancels its parent
-- chain to land on whole pixels (modern-wow party members) multiplies this
-- back in so it still follows its anchor's scale.
function U.MoverAncestorScale(frame)
  if not frame then return 1 end
  local entry = scaling.Ancestor(frame)
  if not entry then return 1 end
  return entry.appliedFactor or scaling.Factor(entry)
end

-- Bounds of a registered mover in UIParent layout space, as MoverBounds
-- computes them: the same space every other placement decision in this file is
-- made in. Exported so a contextual panel can be placed beside an anchor
-- without repeating the point-factor maths or the own-unit conversion that a
-- scaled frame's GetLeft/GetRight would need.
function U.MoverBounds(id)
  local entry = type(id) == "string" and movers[id] or nil
  if not entry then return nil end
  return MoverBounds(entry, EntryPosition(entry))
end

-- The pandaUI-owned frame a mover is registered on. Exported so
-- core/moversample.lua can draw an empty anchor's placeholder inside it
-- without every module having to hand its own frame over a second time.
function U.MoverFrame(id)
  local entry = type(id) == "string" and movers[id] or nil
  return entry and entry.frame or nil
end

-- ---------------------------------------------------------------------------
-- Snap tracer
--
-- Armed before edit mode opens (`/pui movesnap`) because no slash command can
-- be typed while the overlay is up, and disarmed automatically by U.LockUI, so
-- one gesture is recorded end to end without the player leaving edit mode.
--
-- It answers one question: does the rectangle the snapper reasons about match
-- the one the player sees? Every sample therefore carries both -- the
-- UIParent-space rect MoverBounds computes from the stored offsets, and the
-- rect the client reports for the live frame (GetLeft/GetBottom/GetWidth/
-- GetHeight, converted through the frame's own effective scale). The two agree
-- for every mover drawn at UIParent's scale; where a theme scales a frame they
-- are the whole diagnosis.
--
-- Write-only, capped, and never read back by the addon: PandaUIDiagDB is the
-- established channel for this (core/commands.lua).
-- ---------------------------------------------------------------------------
local function Rounded(value)
  value = tonumber(value)
  if not value then return nil end
  return math.floor(value * 100 + 0.5) / 100
end

-- The rect the client actually draws, in UIParent units: the frame's own-unit
-- GetLeft/GetBottom/GetWidth/GetHeight times the ratio (EntryScale).
local function LiveRect(entry)
  local frame = entry and entry.frame
  if not frame then return nil end

  local left = Edge(frame, "GetLeft")
  local bottom = Edge(frame, "GetBottom")
  local width = Edge(frame, "GetWidth")
  local height = Edge(frame, "GetHeight")
  if not left or not bottom or not width or not height then return nil end

  local ratio = EntryScale(entry)
  left = left * ratio - (Edge(UIParent, "GetLeft") or 0)
  bottom = bottom * ratio - (Edge(UIParent, "GetBottom") or 0)
  return left, left + width * ratio, bottom, bottom + height * ratio
end

function trace.Name(frame)
  if frame == nil then return "none" end
  if frame == UIParent then return "UIParent" end
  if type(frame) == "string" then return frame end
  if type(frame) ~= "table" or type(frame.GetName) ~= "function" then
    return "?"
  end
  local ok, name = pcall(frame.GetName, frame)
  if ok and type(name) == "string" then return name end
  return "unnamed"
end

-- Layering and hit-test state of one widget: the answer to "why can this
-- handle not be clicked" is in strata, level, visibility, mouse and rect.
function trace.Widget(frame)
  if not frame then return nil end
  local row = { name = trace.Name(frame) }
  local left, bottom = Edge(frame, "GetLeft"), Edge(frame, "GetBottom")
  local width, height = Edge(frame, "GetWidth"), Edge(frame, "GetHeight")
  row.l, row.b = Rounded(left), Rounded(bottom)
  row.w, row.h = Rounded(width), Rounded(height)
  row.level = Edge(frame, "GetFrameLevel")
  row.points = Edge(frame, "GetNumPoints")
  row.effScale = Rounded(Edge(frame, "GetEffectiveScale"))

  local ok, value = pcall(frame.IsShown, frame)
  if ok then row.shown = value and true or false end
  if type(frame.IsVisible) == "function" then
    ok, value = pcall(frame.IsVisible, frame)
    if ok then row.visible = value and true or false end
  end
  if type(frame.GetFrameStrata) == "function" then
    ok, value = pcall(frame.GetFrameStrata, frame)
    if ok then row.strata = value end
  end
  if type(frame.IsMouseEnabled) == "function" then
    ok, value = pcall(frame.IsMouseEnabled, frame)
    if ok then row.mouse = value and true or false end
  end
  if type(frame.GetParent) == "function" then
    ok, value = pcall(frame.GetParent, frame)
    if ok then row.parent = trace.Name(value) end
  end
  return row
end

function trace.Log(list, row)
  if not trace.on or table.getn(list) >= trace.maxLog then return end
  row.t = Rounded(GetTime())
  row.unlocked = unlocked and true or false
  table.insert(list, row)
end

-- A write to or a re-application of a stored position.
function trace.Event(kind, entry, position, extra)
  if not trace.on or not entry then return end
  local row = { kind = kind, id = entry.id }
  if type(position) == "table" then
    row.point = position.point
    row.relativePoint = position.relativePoint
    row.x, row.y = Rounded(position.x), Rounded(position.y)
  end
  if type(extra) == "table" then
    local key, value
    for key, value in pairs(extra) do row[key] = value end
  end
  local left, right, bottom, top = LiveRect(entry)
  row.liveLeft, row.liveBottom = Rounded(left), Rounded(bottom)
  row.liveRight, row.liveTop = Rounded(right), Rounded(top)
  trace.Log(trace.events, row)
end

-- Drawn content past an anchor's box, per side in UIParent units, with the
-- widget reaching furthest on each side (name or type, texture path). Read
-- only while tracing: it is the evidence for each mover's snapPadding. Box
-- sizes cannot see a texture's transparent margin, so a side's texture is
-- named for an offline alpha check (mover.magnet_snaps_thin_bars_flush).
-- Only visible widgets are read; UIParent and WorldFrame never are
-- (frames.root_frame_point_read_crash_suspected).
trace.OVERFLOW_LIMIT = 600

function trace.Describe(object)
  local row = { name = trace.Name(object) }
  local ok, kind = pcall(object.GetObjectType, object)
  if ok then row.kind = kind end
  if kind == "Texture" then
    local texOk, path = pcall(object.GetTexture, object)
    if texOk then row.tex = path end
  end
  return row
end

function trace.Overflow(entry)
  local boxLeft, boxRight, boxBottom, boxTop = LiveRect(entry)
  if not boxLeft then return nil end
  local uiLeft = Edge(UIParent, "GetLeft") or 0
  local uiBottom = Edge(UIParent, "GetBottom") or 0
  local out = { l = 0, r = 0, b = 0, t = 0, read = 0 }

  local function Measure(object, ratio)
    local ok, visible = pcall(object.IsVisible, object)
    if not ok or not visible then return false end
    local left, right = Edge(object, "GetLeft"), Edge(object, "GetRight")
    local bottom, top = Edge(object, "GetBottom"), Edge(object, "GetTop")
    if left and right and bottom and top and right > left and top > bottom then
      left, right = left * ratio - uiLeft, right * ratio - uiLeft
      bottom, top = bottom * ratio - uiBottom, top * ratio - uiBottom
      if boxLeft - left > out.l then
        out.l, out.lBy = boxLeft - left, trace.Describe(object)
      end
      if right - boxRight > out.r then
        out.r, out.rBy = right - boxRight, trace.Describe(object)
      end
      if boxBottom - bottom > out.b then
        out.b, out.bBy = boxBottom - bottom, trace.Describe(object)
      end
      if top - boxTop > out.t then
        out.t, out.tBy = top - boxTop, trace.Describe(object)
      end
    end
    return true
  end

  local function Walk(frame, depth)
    if out.read >= trace.OVERFLOW_LIMIT or depth > 8 then return end
    if frame == entry.handle or frame == entry.dragInput or
       frame == UIParent or frame == WorldFrame then return end
    out.read = out.read + 1
    if not Measure(frame, U.FrameUIRatio(frame) or 1) then return end
    local ratio = U.FrameUIRatio(frame) or 1
    local list, i = { pcall(frame.GetRegions, frame) }, nil
    if list[1] then
      for i = 2, table.getn(list) do
        out.read = out.read + 1
        Measure(list[i], ratio)
      end
    end
    list = { pcall(frame.GetChildren, frame) }
    if list[1] then
      for i = 2, table.getn(list) do Walk(list[i], depth + 1) end
    end
  end

  Walk(entry.frame, 0)
  out.l, out.r = Rounded(out.l), Rounded(out.r)
  out.b, out.t = Rounded(out.b), Rounded(out.t)
  return out
end

-- Every registered mover, as the snapper sees it and as the client draws it.
function trace.Snapshot()
  local rows, i = {}, nil
  for i = 1, table.getn(moverOrder) do
    local entry = movers[moverOrder[i]]
    if entry then
      local position = EntryPosition(entry)
      local left, right, bottom, top = MoverBounds(entry, position)
      local liveLeft, liveRight, liveBottom, liveTop = LiveRect(entry)
      local shownOk, shown = pcall(entry.frame.IsShown, entry.frame)
      table.insert(rows, {
        id = entry.id,
        visible = IsEntryVisible(entry) and true or false,
        shown = shownOk and (shown and true or false) or "?",
        ratio = Rounded(EntryScale(entry)),
        width = Rounded(Edge(entry.frame, "GetWidth")),
        height = Rounded(Edge(entry.frame, "GetHeight")),
        point = position and position.point or "none",
        relativePoint = position and
                        (position.relativePoint or position.point) or "none",
        x = position and Rounded(position.x),
        y = position and Rounded(position.y),
        -- What the snapper works with.
        snapLeft = Rounded(left), snapRight = Rounded(right),
        snapBottom = Rounded(bottom), snapTop = Rounded(top),
        -- What the client draws.
        liveLeft = Rounded(liveLeft), liveRight = Rounded(liveRight),
        liveBottom = Rounded(liveBottom), liveTop = Rounded(liveTop),
        saved = U.GetPosition(entry.id) and true or false,
        enters = entry.enters, dragStarts = entry.dragStarts,
        dragStops = entry.dragStops,
        frame = trace.Widget(entry.frame),
        handle = trace.Widget(entry.handle),
        input = trace.Widget(entry.dragInput),
        overflow = trace.Overflow(entry),
      })
      -- The padding the magnet uses now, beside the measured overflow.
      local padL, padR, padB, padT = magnet.Padding(entry)
      local row = rows[table.getn(rows)]
      row.padL, row.padR = Rounded(padL), Rounded(padR)
      row.padB, row.padT = Rounded(padB), Rounded(padT)
    end
  end
  return rows
end

function trace.Start()
  trace.on = true
  trace.samples = {}
  trace.seq = 0
  trace.dropped = 0
  trace.current = nil
  trace.reason = nil
  trace.startedAt = type(U.DiagnosticStamp) == "function"
                    and U.DiagnosticStamp() or "?"
  trace.focus, trace.drift, trace.events, trace.rects = {}, {}, {}, {}
  trace.lastFocus, trace.nextDrift = nil, 0
  trace.lockedAt, trace.afterLock = nil, nil
  trace.lastId, trace.lastInX, trace.lastInY = nil, nil, nil
  trace.atUnlock = nil
  trace.before = trace.Snapshot()
  trace.NewReport()
  -- trace.Watch is defined further down; it is looked up when the driver runs.
  U.RegisterUpdate("mover.diag", 0, function() trace.Watch() end)
  return true
end

-- Called by ResolveSnap. Returns the sample the rest of that call fills in, or
-- nil while the tracer is off or full.
function trace.Begin(entry, point, relativePoint, x, y, config)
  trace.current = nil
  if not trace.on then return nil end
  -- A held but motionless cursor re-resolves the same request every frame;
  -- one sample per distinct request keeps the cap for actual movement.
  if trace.lastId == entry.id and trace.lastInX == x and trace.lastInY == y then
    return nil
  end
  trace.lastId, trace.lastInX, trace.lastInY = entry.id, x, y
  if table.getn(trace.samples) >= trace.max then
    trace.dropped = trace.dropped + 1
    return nil
  end

  trace.seq = trace.seq + 1
  local left, right, bottom, top = MoverBounds(entry, {
    point = point, relativePoint = relativePoint, x = x, y = y })
  local liveLeft, liveRight, liveBottom, liveTop = LiveRect(entry)

  local sample = {
    seq = trace.seq,
    id = entry.id,
    dragging = entry.dragging and true or false,
    grid = config.gridShown and true or false,
    gridSize = GridSize(),
    magnet = config.magnet and true or false,
    ratio = Rounded(EntryScale(entry)),
    point = point,
    relativePoint = relativePoint,
    -- The position asked for, before any snapping.
    inX = Rounded(x), inY = Rounded(y),
    fromX = Rounded(entry.snapFromX), fromY = Rounded(entry.snapFromY),
    -- The rect that request describes, both ways.
    snapLeft = Rounded(left), snapRight = Rounded(right),
    snapBottom = Rounded(bottom), snapTop = Rounded(top),
    liveLeft = Rounded(liveLeft), liveRight = Rounded(liveRight),
    liveBottom = Rounded(liveBottom), liveTop = Rounded(liveTop),
    hits = {},
  }
  trace.current = sample
  return sample
end

-- One overlap correction, as SnapToMovers resolved it.
function trace.Hit(other, axis, correction, exact, otherLeft, otherRight,
                   otherBottom, otherTop, left, right, bottom, top)
  local sample = trace.current
  if not sample then return end
  if table.getn(sample.hits) >= 8 then return end

  table.insert(sample.hits, {
    other = other and other.id or "?",
    axis = axis,
    correction = Rounded(correction),
    exact = Rounded(exact),
    entryLeft = Rounded(left), entryRight = Rounded(right),
    entryBottom = Rounded(bottom), entryTop = Rounded(top),
    otherLeft = Rounded(otherLeft), otherRight = Rounded(otherRight),
    otherBottom = Rounded(otherBottom), otherTop = Rounded(otherTop),
  })
end

-- The grid pass and the magnet pass, then the position the caller returns.
function trace.Commit(sample, gridX, gridY, x, y)
  if not sample then return end
  sample.gridX, sample.gridY = Rounded(gridX), Rounded(gridY)
  sample.outX, sample.outY = Rounded(x), Rounded(y)
  table.insert(trace.samples, sample)
  trace.current = nil
end

-- The report is written into PandaUIDiagDB as soon as the run is armed, and
-- every log below is the live table it references. SavedVariables are
-- flushed only on /reload or logout, and this client has no verified logout
-- event to save from, so a report written only at the end was lost whenever
-- the player reloaded first (2026-09-17: reload 3 s after the last lock, 17 s
-- before the post-lock watch would have saved). Now a reload at any point
-- keeps everything recorded up to it.
function trace.Publish(reason)
  local report = trace.report
  if not report then return end
  local scaleOk, uiScale = pcall(UIParent.GetEffectiveScale, UIParent)
  report.stoppedAt = type(U.DiagnosticStamp) == "function"
                     and U.DiagnosticStamp() or "?"
  report.reason = reason
  report.theme = type(U.GetActiveThemeStyle) == "function"
                 and U.GetActiveThemeStyle() or "?"
  report.uiWidth = Rounded(U.UIWidth())
  report.uiHeight = Rounded(U.UIHeight())
  report.uiScale = scaleOk and Rounded(uiScale) or "?"
  report.gridSize = GridSize()
  report.magnetDistance = MAGNET_DISTANCE
  report.dropped = trace.dropped
  report.before = trace.before
  report.atUnlock = trace.atUnlock
  report.afterLock = trace.afterLock
  if type(U.SaveDiagnostic) == "function" then
    U.SaveDiagnostic("moveSnap", report)
  end
end

function trace.NewReport()
  trace.report = {
    startedAt = trace.startedAt,
    samples = trace.samples,
    -- GetMouseFocus changes, with the mover part it belongs to.
    focus = trace.focus,
    -- Live rects that changed, sampled every 0.25 s.
    drift = trace.drift,
    -- Store writes and re-applications (save, apply, pin, pendingSnap).
    events = trace.events,
  }
  trace.Publish("running")
end

-- Disarmed after the post-lock watch or by the command, so the recording ends
-- with the gesture rather than needing a command the player cannot type while
-- the overlay is up.
function trace.Stop(reason)
  if not trace.on then return false, 0, 0 end
  trace.on = false
  trace.current = nil
  trace.reason = reason
  U.UnregisterUpdate("mover.diag")

  if trace.report then
    trace.report.after = trace.Snapshot()
    trace.Publish(reason)
  end

  local count = table.getn(trace.samples)
  trace.report = nil
  trace.samples = {}
  trace.before, trace.afterLock, trace.lockedAt = nil, nil, nil
  trace.atUnlock = nil
  trace.focus, trace.drift, trace.events, trace.rects = {}, {}, {}, {}
  return true, count, trace.dropped
end

-- /pui movesnap. Armed before edit mode, disarmed by U.LockUI or by the
-- command again.
function U.MoverSnapTrace(on)
  if on then return trace.Start() end
  return trace.Stop("command")
end

function U.MoverSnapTraceOn()
  return trace.on and true or false
end

-- An anchor travelling with the drag is not a landmark to snap against: it is
-- moving by the same offset, and for a member with a stored position the store
-- still holds where it started, which would pull the dragged frame back there.
local function IsFollower(entry, other)
  if not entry.followerSet or not other then return false end
  return entry.followerSet[other.id] and true or false
end

-- Magnet contact wins over the grid on the axis where two anchors touch.
--
-- With the grid on, this used to skip the proximity pull and round the
-- collision escape up to whole cells, so the grid kept every edge on a drawn
-- line. Against a neighbour whose size is not a whole number of cells that
-- always left a visible gap between the two anchors, which is exactly what
-- enabling the magnet asks not to have. Now:
--
--   * the edge-to-edge pull runs with the grid on too, measured from the
--     cursor's unsnapped position (rawX/rawY) so the grid cell the anchor
--     happens to sit in cannot hold it out of magnet range; a hit on an axis
--     replaces the grid value on that axis only, and the other axis stays on
--     the grid. It stops short of flush by both anchors' snapPadding;
--   * every reach is half the thinner anchor of the pair on that axis,
--     between 3 and MAGNET_DISTANCE (magnet.Reach);
--   * smart alignment -- the screen centre, and the anchor's left/centre/
--     right (bottom/centre/top) line onto the same line of another anchor
--     within a quarter screen on the other axis, touching or not -- runs in
--     both modes. With the grid on it is measured
--     from the grid position, within half a cell (at most MAGNET_DISTANCE):
--     the grid keeps stepping, and the one step nearest a line lands on it
--     exactly. Measured from the cursor instead (the first phase-1 build),
--     a step a unit or two off the centre never reached it -- user report
--     2026-10-25, grid 20; knowledge.json
--     mover.smart_alignment_guides_unverified;
--   * contact wins over alignment on an axis where both hit;
--   * the collision escape is exact, leaving the anchor flush against the
--     edge it approached.
--
-- Alignment runs whatever the magnet toggle says; magnetOn gates only the
-- edge contact pull and the collision barrier, which is what the option
-- names ("Magnet elements (prevent overlap)"). /pui movesnap 2026-10-26
-- (magnet off, grid 10): the swing bar stopped with its centre at 401.00
-- beside a cast bar centred at 401.25 -- a grid step cannot close a quarter
-- unit, the alignment pass never ran, and no guide was drawn.
local function SnapToMovers(entry, point, relativePoint, x, y, gridOn,
                            rawX, rawY, magnetOn)
  local fromX, fromY = x, y
  if gridOn then fromX, fromY = rawX or x, rawY or y end
  local left, right, bottom, top = MoverBounds(entry, {
    point = point, relativePoint = relativePoint, x = fromX, y = fromY,
  })
  -- Where the grid put it (the same rectangle with the grid off).
  local gLeft, gRight, gBottom, gTop = MoverBounds(entry, {
    point = point, relativePoint = relativePoint, x = x, y = y,
  })
  if not left or not gLeft then return x, y, false, false end

  -- Reach scales with the thinner anchor of each pair (magnet.Reach); the
  -- alignment reach is also capped at half a grid cell with the grid on.
  local width, height = right - left, top - bottom
  local cap = gridOn and GridSize() / 2 or nil
  -- The dragged anchor's padding carries the join SPACING, so contact and
  -- the collision barrier below both leave it between the two drawn edges.
  local padL, padR, padB, padT = magnet.Padding(entry)
  padL, padR = padL + magnet.SPACING, padR + magnet.SPACING
  padB, padT = padB + magnet.SPACING, padT + magnet.SPACING
  local screenWidth, screenHeight = U.UIWidth(), U.UIHeight()
  local big = magnet.BIG
  local bestX, bestY, bestXDistance, bestYDistance = nil, nil, big, big
  local alignX, alignY, alignXDistance, alignYDistance = nil, nil, big, big
  local i
  alignX, alignXDistance = ClosestDelta(
    screenWidth / 2 - (gLeft + gRight) / 2, alignX, alignXDistance,
    magnet.Reach(width, nil, cap))
  alignY, alignYDistance = ClosestDelta(
    screenHeight / 2 - (gBottom + gTop) / 2, alignY, alignYDistance,
    magnet.Reach(height, nil, cap))
  for i = 1, table.getn(moverOrder) do
    local other = movers[moverOrder[i]]
    if other ~= entry and IsEntryVisible(other) and
       not IsFollower(entry, other) then
      local otherLeft, otherRight, otherBottom, otherTop =
        MoverBounds(other, OtherPosition(other))
      if otherLeft then
        local otherWidth = otherRight - otherLeft
        local otherHeight = otherTop - otherBottom
        if magnet.Near(gBottom, gTop, otherBottom, otherTop, screenHeight) then
          alignX, alignXDistance = AlignDelta(
            gLeft, gRight, otherLeft, otherRight, alignX, alignXDistance,
            magnet.Reach(width, otherWidth, cap))
        end
        if magnet.Near(gLeft, gRight, otherLeft, otherRight, screenWidth) then
          alignY, alignYDistance = AlignDelta(
            gBottom, gTop, otherBottom, otherTop, alignY, alignYDistance,
            magnet.Reach(height, otherHeight, cap))
        end
        -- Edge contact, from the cursor position in both grid modes, leaving
        -- both anchors' padding between them. Magnet only.
        if magnetOn then
          -- Facing sides only: this anchor's right against the other's left,
          -- its top against the other's bottom, and so on.
          local oPadL, oPadR, oPadB, oPadT = magnet.Padding(other)
          if IntervalsNear(bottom, top, otherBottom, otherTop) then
            local reach = magnet.Reach(width, otherWidth)
            bestX, bestXDistance = ClosestDelta(
              otherLeft - (padR + oPadL) - right, bestX, bestXDistance, reach)
            bestX, bestXDistance = ClosestDelta(
              otherRight + (padL + oPadR) - left, bestX, bestXDistance, reach)
          end
          if IntervalsNear(left, right, otherLeft, otherRight) then
            local reach = magnet.Reach(height, otherHeight)
            bestY, bestYDistance = ClosestDelta(
              otherBottom - (padT + oPadB) - top, bestY, bestYDistance, reach)
            bestY, bestYDistance = ClosestDelta(
              otherTop + (padB + oPadT) - bottom, bestY, bestYDistance, reach)
          end
        end
      end
    end
  end

  -- Every delta above is in UIParent units (MoverBounds); the offsets are in
  -- the frame's own, so each correction is divided by the ratio on the way in.
  -- Contact deltas are from the cursor position, alignment deltas from the
  -- grid position (x, y).
  local ratio = EntryScale(entry)
  if bestX then
    x = fromX + bestX / ratio
  elseif alignX then
    x, bestX = x + alignX / ratio, alignX
  end
  if bestY then
    y = fromY + bestY / ratio
  elseif alignY then
    y, bestY = y + alignY / ratio, alignY
  end
  if not magnetOn then return x, y, bestX ~= nil, bestY ~= nil end

  -- A magnet is also a collision barrier. Resolve every overlap after the
  -- proximity snap, backing the anchor out the way it came in. Repeating the
  -- walk handles a correction that would otherwise push the mover into a
  -- second neighbour.
  --
  -- The direction matters: taking the SHORTEST of the four ways out reads as a
  -- barrier only while the neighbour is small. Against a tall, wide one -- the
  -- party block -- the nearest edge flips from one side to another between two
  -- ticks, and the anchor is teleported several grid cells across the block
  -- instead of stopping at it. entry.snapFrom* is the last position this drag
  -- settled on, and the overlap is undone across the edge the anchor was
  -- still clear of there -- the edge it actually crossed -- which leaves it
  -- flush against that edge and free to slide along it. With no recorded
  -- position -- one applied outside a drag -- or one that already overlapped,
  -- the shortest-route choice applies.
  --
  -- Not the direction of travel. /pui movesnap 2026-09-17, bar 3 (30 x 382)
  -- held against the quest tracker's right edge while the cursor went left:
  -- a 2-unit upward wobble made "undo the vertical travel" (115 units down)
  -- smaller than "undo the horizontal travel" (135 right), so the bar was
  -- shoved below the tracker into the status bar, whose own escape threw it
  -- 188 units right and the screen clamp dropped it 13 more -- a jump across
  -- the whole corner of the screen from a slow drag.
  local lastX, lastY = tonumber(entry.snapFromX), tonumber(entry.snapFromY)
  local lastLeft, lastRight, lastBottom, lastTop
  if lastX and lastY then
    lastLeft, lastRight, lastBottom, lastTop = MoverBounds(entry, {
      point = point, relativePoint = relativePoint, x = lastX, y = lastY,
    })
  end
  local pass
  for pass = 1, table.getn(moverOrder) do
    local resolved = false
    left, right, bottom, top = MoverBounds(entry, {
      point = point, relativePoint = relativePoint, x = x, y = y,
    })
    if not left then break end

    for i = 1, table.getn(moverOrder) do
      local other = movers[moverOrder[i]]
      if other ~= entry and IsEntryVisible(other) and
         not IsFollower(entry, other) then
        local otherLeft, otherRight, otherBottom, otherTop =
          MoverBounds(other, OtherPosition(other))
        -- The barrier is the other anchor grown by both paddings, so an
        -- escape leaves the padding gap rather than flush. A flush escape let
        -- the grid or a fast drag put the XP and rep bars edge to edge,
        -- borders overlapping (offline replay 2026-11-03,
        -- mover.magnet_snaps_thin_bars_flush).
        if otherLeft then
          local oPadL, oPadR, oPadB, oPadT = magnet.Padding(other)
          otherLeft = otherLeft - padR - oPadL
          otherRight = otherRight + padL + oPadR
          otherBottom = otherBottom - padT - oPadB
          otherTop = otherTop + padB + oPadT
        end
        if otherLeft and Overlaps(left, right, bottom, top,
                                  otherLeft, otherRight,
                                  otherBottom, otherTop) then
          local moveLeft = otherLeft - right
          local moveRight = otherRight - left
          local moveDown = otherBottom - top
          local moveUp = otherTop - bottom
          -- Positive x is rightward and positive y upward, here as in
          -- SetPoint. The side the anchor was on at its last position picks
          -- the escape; only an entry across a corner (clear on both axes)
          -- compares the two, so a held edge is never traded for a far one.
          local correction, axis = nil, nil
          if lastLeft then
            local xFix, yFix = nil, nil
            if lastRight <= otherLeft + ALIGNMENT_EPSILON then
              xFix = moveLeft
            elseif lastLeft >= otherRight - ALIGNMENT_EPSILON then
              xFix = moveRight
            end
            if lastTop <= otherBottom + ALIGNMENT_EPSILON then
              yFix = moveDown
            elseif lastBottom >= otherTop - ALIGNMENT_EPSILON then
              yFix = moveUp
            end
            if xFix and yFix then
              if math.abs(yFix) < math.abs(xFix) then
                correction, axis = yFix, "y"
              else
                correction, axis = xFix, "x"
              end
            elseif xFix then
              correction, axis = xFix, "x"
            elseif yFix then
              correction, axis = yFix, "y"
            end
          end

          if not correction then
            correction, axis = moveLeft, "x"
            if math.abs(moveRight) < math.abs(correction) then
              correction, axis = moveRight, "x"
            end
            if math.abs(moveDown) < math.abs(correction) then
              correction, axis = moveDown, "y"
            end
            if math.abs(moveUp) < math.abs(correction) then
              correction, axis = moveUp, "y"
            end
          end
          trace.Hit(other, axis, correction, correction,
                    otherLeft, otherRight, otherBottom, otherTop,
                    left, right, bottom, top)
          if axis == "x" then
            x = x + correction / ratio
            bestX = correction
          else
            y = y + correction / ratio
            bestY = correction
          end
          resolved = true
          break
        end
      end
    end
    if not resolved then break end
  end

  return x, y, bestX ~= nil, bestY ~= nil
end

-- Grid snapping moves the anchor's TOP-LEFT edge onto a grid line, not the
-- stored offsets.
--
-- Snapping the offsets themselves cannot align anything: they are measured
-- from whatever the stored point pair names -- after a drag, PinToUIParent
-- makes that BOTTOMLEFT, so the screen's left/bottom edge -- while LayoutGrid
-- draws the lines from UIParent's centre outwards. The two origins only agree
-- when half the screen is a whole number of grid cells, and the edge that
-- landed on a line was the bottom one, not the top.
--
-- knowledge.json / mover.gridalign_top_left_edge_snap (FOCUSED_RUNTIME_PROBE,
-- gridalign.v3) measured all 46 slider sizes against pandaUI's own drawn
-- lines: the shipped offset snap missed by up to 23.17 units, while snapping
-- the top-left edge to the centre-origin grid landed on the measured line
-- centre exactly, 92 placements out of 92, for odd and even grid sizes and odd
-- and even frame dimensions alike. Grid-size parity turned out to be
-- irrelevant, so no even/odd grid variant is needed.
--
-- The correction is applied as a delta to the offsets the caller already has,
-- so it holds for any point/relativePoint pair without repeating the
-- point-factor maths. The grid and the bounds are in UIParent units, the
-- offsets in the frame's own, so the delta is divided by the ratio
-- (EntryScale): a scaled frame's edge lands on the drawn line, not on a line
-- of a grid scaled with it.
local function SnapPosition(entry, point, relativePoint, x, y)
  x = tonumber(x) or 0
  y = tonumber(y) or 0
  local ratio = EntryScale(entry)

  local left, _, _, top = MoverBounds(entry, {
    point = point, relativePoint = relativePoint, x = x, y = y,
  })
  if not left or not top then
    -- No readable dimensions: snapping the raw offsets at least keeps movement
    -- stepped rather than continuous.
    return SnapValue(x * ratio) / ratio, SnapValue(y * ratio) / ratio
  end

  local centerX, centerY = U.UIWidth() / 2, U.UIHeight() / 2
  local snappedLeft = centerX + SnapValue(left - centerX)
  local snappedTop = centerY + SnapValue(top - centerY)
  return x + (snappedLeft - left) / ratio, y + (snappedTop - top) / ratio
end

local function ResolveSnap(entry, point, relative, relativePoint, x, y)
  local config = MoverConfig()
  local snapped = false
  local sample = trace.Begin(entry, point, relativePoint, x, y, config)
  local rawX, rawY = x, y
  -- Alt held: no grid, magnet or alignment; the screen clamp still applies.
  local free = magnet.Free()
  if config.gridShown and not free then
    local sx, sy = SnapPosition(entry, point, relativePoint, x, y)
    snapped = sx ~= x or sy ~= y
    x, y = sx, sy
  end
  local gridX, gridY = x, y

  -- Alignment always; contact and overlap only with the magnet on.
  if not free and (not relative or relative == UIParent) then
    local magneticX, magneticY
    x, y, magneticX, magneticY =
      SnapToMovers(entry, point, relativePoint, x, y, config.gridShown,
                   rawX, rawY, config.magnet and true or false)
    snapped = snapped or magneticX or magneticY
  end
  trace.Commit(sample, gridX, gridY, x, y)

  -- Last, so neither grid nor magnet can place an element off screen. Counts as
  -- a snap: the drop path then re-applies the stored, corrected point.
  if not relative or relative == UIParent then
    local clamped, moved = U.ClampPositionToScreen(entry.frame, {
      point = point, relativePoint = relativePoint, x = x, y = y,
    })
    if moved then
      x, y, snapped = clamped.x, clamped.y, true
    end
    if sample then sample.clamped = moved and true or false end
  end
  -- Committed above, before the clamp; the sample is still the same table.
  if sample then sample.finalX, sample.finalY = Rounded(x), Rounded(y) end
  return x, y, snapped
end

local function ApplyPendingSnap()
  local entry = pendingSnap
  pendingSnap = nil
  U.UnregisterUpdate("mover.snap")
  if not entry then return end

  local stored = U.GetPosition(entry.id)
  if stored then U.ApplyFramePoint(entry.frame, stored) end
  trace.Event("pendingSnap", entry, stored)
  -- After the snap, not before: converting a pre-snap rect would pin the frame
  -- to the bottom edge it had while it was still off the grid.
  NormaliseAnchorEdge(entry)
end

local function CapturePosition(entry)
  local placement = ReadPlacement(entry.frame)
  if not placement then
    U.Debug("mover " .. entry.id .. ": no readable anchor after drag")
    return false
  end
  local point, relative, relativePoint, x, y = placement.point,
    placement.relative, placement.relativePoint, placement.x, placement.y

  -- Stored positions are always UIParent-relative. If the drag left the frame
  -- anchored to something else, say so rather than silently storing an offset
  -- that will be re-applied against a different origin.
  if relative and relative ~= UIParent then
    U.Debug("mover " .. entry.id ..
            ": anchored to a non-UIParent frame after drag; storing anyway")
  end

  local snapped
  x, y, snapped = ResolveSnap(entry, point, relative, relativePoint, x, y)

  local saved = U.SavePosition(entry.id, point, relativePoint, x, y)
  trace.Event("save", entry, {
    point = point, relativePoint = relativePoint, x = x, y = y,
  }, {
    ok = saved and true or false, snapped = snapped and true or false,
    readRelative = trace.Name(relative),
    -- A non-UIParent parent means ReadPlacement fell back to U.GetFramePoint.
    parent = trace.on and trace.Widget(entry.frame).parent or nil,
  })

  if saved and snapped then
    pendingSnap = entry
    U.RegisterUpdate("mover.snap", 0, ApplyPendingSnap)
  elseif saved then
    -- The snapping path converts from ApplyPendingSnap instead, once the frame
    -- has actually been moved onto the grid.
    NormaliseAnchorEdge(entry)
  end

  return saved
end

-- ---------------------------------------------------------------------------
-- Dragging
--
-- The compact DB has no record at all for RegisterForDrag, StartMoving,
-- SetMovable or frame-level mouse input, so none of it can be assumed. The one
-- implementation of frame dragging demonstrably working on this client is
-- UnrealPfUI's dragger (modules/unlock.lua / CreateDragger), and the parts of
-- its recipe that pandaUI's first attempt did not follow are reproduced here:
--
--   * the handle is a **Button**, not a plain Frame. Buttons take mouse input
--     without EnableMouse, and Button is the only widget type this client is
--     known to deliver OnDragStart to.
--   * the handle is parented to the frame it moves and covers it with
--     SetAllPoints, rather than floating over it as a UIParent child.
--   * it is raised with SetFrameLevel rather than a strata change.
--   * SetMovable is applied immediately before each drag, not once at
--     registration.
--   * the real StartMoving is preceded by a StartMoving/StopMovingOrSizing
--     pair, which collapses a multi-point anchor down to the single point the
--     client will actually move.
--
-- Only the behaviour is reused; none of pfUI's selection, grid, scaling or dock
-- machinery is reproduced.
--
-- Failures here are reported through U.Error, not U.Debug: a mover that cannot
-- be dragged is the whole feature failing, and debug output is off by default.
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- Dragging a group of anchors
--
-- Anchors that touch travel together: dragging the target frame takes the
-- target-of-target frame and the target castbar sitting under it along, and
-- whatever is touching those in turn. The set is collected once, when the drag
-- starts, and every member is then moved by the same offset as the frame under
-- the cursor.
--
-- Movement has to come from that one offset and from nothing else, so a frame
-- riding a live anchor is converted first. A mover's frame is not always
-- anchored to UIParent: target-of-target rests docked under the target frame,
-- and the buff, quest-tracker and pet-bar anchors shadow the client's own
-- frames, which this client hangs off the minimap and the main bar. Left alone,
-- such a frame would be towed by its anchor whether or not it is part of the
-- group -- twice over for a member, and at all for an anchor across the screen
-- that merely shares a chain.
--
-- The conversion is the one NormaliseAnchorEdge performs -- read the live rect,
-- subtract UIParent's origin (in the frame's own units), apply a stored-shaped
-- point -- which
-- frames.getpoint_relative_name_y_inverted confirms is the safe direction. The
-- modules that shadow a native frame already stop following it while edit mode
-- is open, so this completes their intent rather than fighting it.
--
-- The pin itself is applied, not saved; only anchors the gesture actually moved
-- are written to the position store, alongside the dragged frame's own drop.
-- ---------------------------------------------------------------------------
local function PinToUIParent(entry)
  if not entry or not entry.frame then return false end

  local point, relative = U.GetFramePoint(entry.frame, 1)
  if not point or relative == UIParent then return false end

  -- A frame held by two points is sized by them, and a single replacement point
  -- would collapse it. Only a frame carried by one anchor is converted. If this
  -- client has no GetNumPoints the check simply does not apply.
  local countOk, count = pcall(entry.frame.GetNumPoints, entry.frame)
  if countOk and tonumber(count) and count > 1 then
    U.Debug("mover " .. entry.id .. ": held by " .. count ..
            " points; left riding its anchor")
    return false
  end

  local left = Edge(entry.frame, "GetLeft")
  local bottom = Edge(entry.frame, "GetBottom")
  if not left or not bottom then
    -- Nothing readable to convert (a frame with no resolved rect yet, or one
    -- hidden with none). Leaving the anchor alone is the safe outcome.
    U.Debug("mover " .. entry.id .. ": no readable rect to pin")
    return false
  end

  -- Edges and offsets in the frame's own units; UIParent's origin is in its
  -- own, hence the ratio (EntryScale).
  local ratio = EntryScale(entry)
  local applied = U.ApplyFramePoint(entry.frame, {
    point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT",
    x = left - (Edge(UIParent, "GetLeft") or 0) / ratio,
    y = bottom - (Edge(UIParent, "GetBottom") or 0) / ratio,
  })
  if applied then
    trace.Event("pin", entry, nil, { fromRelative = trace.Name(relative) })
    U.Debug("mover " .. entry.id .. ": pinned to UIParent so it is not towed")
  end
  return applied
end

local function PinPassengers(dragged)
  local i
  for i = 1, table.getn(moverOrder) do
    local entry = movers[moverOrder[i]]
    if entry and entry ~= dragged and IsEntryVisible(entry) then
      PinToUIParent(entry)
    end
  end
end

-- Two anchors count as touching when their bounds meet, overlap, or leave a gap
-- of no more than two units, on both axes. The tolerance is deliberately far
-- smaller than MAGNET_DISTANCE: the default action-bar stack leaves four units
-- between bars, and those are ten separate anchors, not one block. It is not
-- zero because a flush pair still reads a unit or two apart once each anchor
-- has drawn its own outline.
local TOUCH_TOLERANCE = 3

local function BoundsTouch(a, b)
  return a.left < b.right + TOUCH_TOLERANCE and
         a.right > b.left - TOUCH_TOLERANCE and
         a.bottom < b.top + TOUCH_TOLERANCE and
         a.top > b.bottom - TOUCH_TOLERANCE
end

-- Everything touching the dragged anchor, plus everything touching those, and
-- so on outwards. Each member is recorded with the position it started from, so
-- the drag can keep re-deriving it from one offset instead of accumulating.
local function CollectFollowers(dragged)
  local rects, positions, followers = {}, {}, {}

  local i
  for i = 1, table.getn(moverOrder) do
    local other = movers[moverOrder[i]]
    if other and IsEntryVisible(other) then
      local position = EntryPosition(other)
      local left, right, bottom, top = MoverBounds(other, position)
      if left then
        -- Drawn edges, not boxes: two anchors the magnet joined keep their
        -- art padding plus magnet.SPACING (under TOUCH_TOLERANCE) between
        -- boxes and must still read as touching.
        local padL, padR, padB, padT = magnet.Padding(other)
        rects[other.id] = { left = left - padL, right = right + padR,
                            bottom = bottom - padB, top = top + padT }
        positions[other.id] = position
      end
    end
  end

  local frontier = { rects[dragged.id] }
  if not frontier[1] then return followers end

  local taken = { [dragged.id] = true }
  local cursor = 1
  while cursor <= table.getn(frontier) do
    local current = frontier[cursor]
    cursor = cursor + 1
    for i = 1, table.getn(moverOrder) do
      local other = movers[moverOrder[i]]
      local rect = other and rects[other.id]
      if rect and not taken[other.id] and BoundsTouch(current, rect) then
        local position = positions[other.id]
        taken[other.id] = true
        table.insert(frontier, rect)
        table.insert(followers, {
          entry = other,
          point = position.point,
          relativePoint = position.relativePoint or position.point,
          x = tonumber(position.x) or 0,
          y = tonumber(position.y) or 0,
          -- Its own units per UIParent unit, for the shared offset below.
          ratio = EntryScale(other),
        })
      end
    end
  end

  return followers
end

-- deltaX/deltaY are in UIParent units: members may be drawn at different
-- scales, so each converts the shared offset into its own units.
local function MoveFollowers(entry, deltaX, deltaY)
  entry.followerDeltaX, entry.followerDeltaY = deltaX, deltaY
  local i
  for i = 1, table.getn(entry.followers or {}) do
    local follower = entry.followers[i]
    local ratio = follower.ratio or 1
    U.ApplyFramePoint(follower.entry.frame, {
      point = follower.point, relativePoint = follower.relativePoint,
      x = follower.x + deltaX / ratio, y = follower.y + deltaY / ratio,
    })
  end
end

-- Settles the group on the drop. Each member is computed from the position it
-- started at plus the final offset, never read back from the frame:
-- frames.getpoint_relative_name_y_inverted lists recapturing a freshly applied
-- point as a failed approach, and the arithmetic is exact here anyway.
--
-- The offset is taken from what CapturePosition actually stored for the dragged
-- frame, because that call re-resolves grid and magnet once more on the drop.
-- Reusing the last tick's offset would leave the group a few units behind that
-- correction. It falls back to the tick offset when the point names differ,
-- which is NormaliseAnchorEdge having converted the drop to a bottom anchor --
-- the frame is in the same place, so that offset is still the right one.
--
-- As in MoveFollowers the offset is carried in UIParent units: the dragged
-- frame's own-unit difference times its ratio, divided by each member's.
local function FinishFollowers(entry, before)
  local deltaX = entry.followerDeltaX or 0
  local deltaY = entry.followerDeltaY or 0

  local after = U.GetPosition(entry.id)
  if before and after and before.point == after.point and
     (before.relativePoint or before.point) ==
     (after.relativePoint or after.point) then
    local ratio = EntryScale(entry)
    deltaX = ((tonumber(after.x) or 0) - (tonumber(before.x) or 0)) * ratio
    deltaY = ((tonumber(after.y) or 0) - (tonumber(before.y) or 0)) * ratio
  end

  if deltaX == 0 and deltaY == 0 then return end

  local i
  for i = 1, table.getn(entry.followers or {}) do
    local follower = entry.followers[i]
    local ratio = follower.ratio or 1
    local position = {
      point = follower.point, relativePoint = follower.relativePoint,
      x = follower.x + deltaX / ratio, y = follower.y + deltaY / ratio,
    }
    -- Applied as well as stored: an anchor the gesture moved has to keep its
    -- new place across a reload, and a member that was only ever riding a live
    -- anchor has no stored position of its own to fall back on.
    U.ApplyFramePoint(follower.entry.frame, position)
    U.SavePosition(follower.entry.id, position.point, position.relativePoint,
                   position.x, position.y)
    NormaliseAnchorEdge(follower.entry)
  end
end

local function ClearFollowers(entry)
  entry.followers = nil
  entry.followerSet = nil
  entry.followerDeltaX, entry.followerDeltaY = nil, nil
end

-- Diagnostic hooks for PandaRuntimeProbe's `magnet` group, not used by
-- pandaUI itself (knowledge.json mover.magnet_snaps_thin_bars_flush).
-- Distances are UIParent units from the anchor's current place.
function U.MoverMagnetTest()
  local api = { SPACING = magnet.SPACING }

  -- The drop the snapper would settle on for a drag to (dx, dy) that was
  -- last clear at (lastDx, lastDy). Moves nothing.
  function api.Snap(id, dx, dy, lastDx, lastDy)
    local entry = movers[id]
    if not entry or entry.dragging then return nil end
    local position = EntryPosition(entry)
    if not position then return nil end
    local ratio = EntryScale(entry)
    local point = position.point
    local relativePoint = position.relativePoint or point
    local x0, y0 = tonumber(position.x) or 0, tonumber(position.y) or 0
    local oldX, oldY = entry.snapFromX, entry.snapFromY
    entry.snapFromX = x0 + (lastDx or dx) / ratio
    entry.snapFromY = y0 + (lastDy or dy) / ratio
    local ok, x, y = pcall(ResolveSnap, entry, point, UIParent,
                           relativePoint, x0 + dx / ratio, y0 + dy / ratio)
    entry.snapFromX, entry.snapFromY = oldX, oldY
    if not ok then return nil, x end
    local left, right, bottom, top = MoverBounds(entry, {
      point = point, relativePoint = relativePoint, x = x, y = y,
    })
    return { left = left, right = right, bottom = bottom, top = top,
             dx = (x - x0) * ratio, dy = (y - y0) * ratio }
  end

  function api.Padding(id)
    if not movers[id] then return nil end
    return magnet.Padding(movers[id])
  end

  -- Moves the live frame by (dx, dy) without saving; api.Restore puts back
  -- the exact placement it had.
  function api.Place(id, dx, dy)
    local entry = movers[id]
    local position = entry and EntryPosition(entry)
    if not position then return false end
    if not entry.probeRestore then
      local live = ReadPlacement(entry.frame)
      entry.probeRestore = live and live.relative == UIParent and live or false
    end
    local ratio = EntryScale(entry)
    return U.ApplyFramePoint(entry.frame, {
      point = position.point,
      relativePoint = position.relativePoint or position.point,
      x = (tonumber(position.x) or 0) + dx / ratio,
      y = (tonumber(position.y) or 0) + dy / ratio,
    })
  end

  function api.Restore(id)
    local entry = movers[id]
    if not entry then return false end
    local before = entry.probeRestore
    entry.probeRestore = nil
    if before then return U.ApplyFramePoint(entry.frame, before) end
    return ApplyStoredPosition(entry)
  end

  -- Ids that would travel with `id` with grouping on.
  function api.Followers(id)
    local ids, i = {}, nil
    if not movers[id] then return ids end
    local list = CollectFollowers(movers[id])
    for i = 1, table.getn(list) do table.insert(ids, list[i].entry.id) end
    return ids
  end

  return api
end

local function ReadDragPosition(frame)
  return ReadPlacement(frame)
end

-- Cursor position in UIParent units: GetCursorPosition divided by UIParent's
-- effective scale (the pfUI-octo convention on this client). The drag tick
-- divides the cursor delta by the dragged frame's ratio (EntryScale), which
-- together is the cursor over the frame's own effective scale -- its own
-- units, the ones its offsets are in. Without that division a 0.75 cast bar
-- would trail three quarters of the cursor's travel.
local function ReadCursorPoint()
  local cursor = U.G("GetCursorPosition")
  if type(cursor) ~= "function" then return nil end

  local cursorOk, x, y = pcall(cursor)
  local scaleOk, scale = pcall(UIParent.GetEffectiveScale, UIParent)
  x, y, scale = tonumber(x), tonumber(y), tonumber(scale)
  if not cursorOk or not scaleOk or not x or not y or
     not scale or scale <= 0 then return nil end
  return x / scale, y / scale
end

local function PositionChanged(before, after)
  if not before or not after then return true end
  return before.point ~= after.point or
         before.relativePoint ~= after.relativePoint or
         before.x ~= after.x or before.y ~= after.y
end

local StopDrag

-- Best effort only, not the safety net: IsMouseButtonDown appears nowhere in
-- this client's documented globals (documentation.json lists GetCursorPosition,
-- GetMouseFocus and the modifier-key queries, and no mouse-button state call),
-- and neither reference addon uses it. Where it is missing this reports "still
-- held" forever, which is why the drag now ends through the input Button's own
-- OnDragStop and OnMouseUp rather than through a poll.
local function LeftButtonStillDown()
  local fn = U.G("IsMouseButtonDown")
  if type(fn) ~= "function" then return true end
  local ok, down = pcall(fn, "LeftButton")
  if not ok then return true end
  return down and down ~= 0 and true or false
end

-- knowledge.json / widgets.thumb_reposition_during_drag_breaks_drag
-- (RUNTIME_FAILURE_CONFIRMED): re-anchoring a frame while this client is moving
-- it with StartMoving makes the client drop the drag, and with it the
-- OnDragStop that would end the gesture. The live feedback below rewrites
-- entry.frame's point on every tick, and the drag input rides that frame's
-- rect while it is idle -- so the moment a drag begins the input is cut loose
-- into UIParent space, given the anchor's current rect once, and never touched
-- again until the drop. Nothing in its hierarchy moves for the rest of the
-- gesture, which is the condition the settings slider's reliable thumb enjoys.
--
-- This is also why the input cannot simply stay parented to the handle: the
-- handle covers the anchor, so every tick of live movement would re-anchor an
-- ancestor of the frame the client is dragging.
local function DetachDragInput(entry)
  local frame, input = entry.frame, entry.dragInput
  if not frame or not input then return false end

  local widthOk, width = pcall(frame.GetWidth, frame)
  local heightOk, height = pcall(frame.GetHeight, frame)
  local centreOk, centreX, centreY = pcall(frame.GetCenter, frame)
  width, height = tonumber(width), tonumber(height)
  centreX, centreY = tonumber(centreX), tonumber(centreY)

  -- Without a usable rect the input keeps the SetAllPoints(handle) stretch it
  -- was created with. That is the weaker arrangement this record warns about,
  -- so it is reported rather than passed over silently.
  if not widthOk or not heightOk or not centreOk or not width or not height or
     not centreX or not centreY or width <= 0 or height <= 0 then
    U.Debug("mover " .. entry.id .. ": drag input keeps its handle anchor")
    return false
  end

  -- GetCenter and GetWidth report in the frame's own units; the input is a
  -- UIParent child with units of its own. Through UIParent units (frame
  -- ratio) into the input's (its ratio, 1 unless something scales it), with
  -- UIParent's origin subtracted as the anchor is UIParent's BOTTOMLEFT.
  local ratio = EntryScale(entry)
  local inputRatio = EntryScale({ frame = input })
  centreX = (centreX * ratio - (Edge(UIParent, "GetLeft") or 0)) / inputRatio
  centreY = (centreY * ratio - (Edge(UIParent, "GetBottom") or 0)) / inputRatio
  input:ClearAllPoints()
  input:SetWidth(width * ratio / inputRatio)
  input:SetHeight(height * ratio / inputRatio)
  input:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centreX, centreY)
  return true
end

-- Returns the input to the handle it covers, so the next press lands on it.
local function ReattachDragInput(entry)
  local input = entry.dragInput
  if not input or not entry.handle then return false end
  input:ClearAllPoints()
  input:SetAllPoints(entry.handle)
  return true
end

local function StartDrag(entry)
  -- Start only after the client recognises its registered drag gesture. The
  -- invisible input Button remains in native StartMoving until OnDragStop, the
  -- same lifecycle used by U.CreateSlider's reliable thumb. The visible anchor
  -- is moved separately from cursor coordinates so snapping cannot interrupt
  -- the input Button's matching release callback.
  if entry.dragging then return true end

  -- Detach everything still riding a live anchor, so what moves is decided by
  -- the group below and by nothing else. The dragged frame is converted too:
  -- until it sits in UIParent space it has no bounds to collect a group with --
  -- EntryPosition rejects a point relative to anything else.
  PinToUIParent(entry)
  PinPassengers(entry)
  -- Measured art padding is read once per anchor for this drag.
  magnet.cache = {}
  -- With grouping off the pins above are the whole of it: every anchor is
  -- independent, and this gesture moves the one under the cursor.
  entry.followers = MoverConfig().groupTouching and CollectFollowers(entry) or {}
  entry.followerSet = {}
  entry.followerDeltaX, entry.followerDeltaY = 0, 0
  local followerIndex
  for followerIndex = 1, table.getn(entry.followers) do
    entry.followerSet[entry.followers[followerIndex].entry.id] = true
  end

  local frame = entry.frame
  local input = entry.dragInput
  if not input then return false end

  DetachDragInput(entry)

  if not pcall(input.SetMovable, input, true) then
    U.Error("mover " .. entry.id .. ": SetMovable failed; drag input is unavailable")
    ReattachDragInput(entry)
    return false
  end

  if pcall(input.StartMoving, input) then
    pcall(input.StopMovingOrSizing, input)
  end

  if not pcall(input.StartMoving, input) then
    U.Error("mover " .. entry.id .. ": StartMoving failed; drag input will not move")
    ReattachDragInput(entry)
    return false
  end

  entry.dragging = true
  dragPlacements = {}
  -- PinToUIParent above has already reduced the visible anchor to one stable
  -- point. Keep that point independent of the native input Button's movement.
  entry.dragStartPosition = ReadDragPosition(frame)
  entry.dragCursorX, entry.dragCursorY = ReadCursorPoint()
  -- Where the anchor is now. SnapToMovers reads this to know which way it is
  -- travelling when it has to undo an overlap; it is updated below on every
  -- tick that settles on a position, so it always names the last place the
  -- anchor was clear.
  entry.snapFromX = entry.dragStartPosition and entry.dragStartPosition.x
  entry.snapFromY = entry.dragStartPosition and entry.dragStartPosition.y
  U.RegisterUpdate("mover.drag", 0, function()
    if not entry.dragging then
      U.UnregisterUpdate("mover.drag")
      return
    end
    if not LeftButtonStillDown() then
      StopDrag(entry)
      return
    end

    local origin = entry.dragStartPosition
    local cursorX, cursorY = ReadCursorPoint()
    if not origin or not cursorX or not entry.dragCursorX then return end
    -- Cursor travel in UIParent units; the offsets are in the frame's own.
    local ratio = EntryScale(entry)
    local deltaX = cursorX - entry.dragCursorX
    local deltaY = cursorY - entry.dragCursorY
    -- Selecting a mover with an ordinary click must not silently snap it.
    if deltaX == 0 and deltaY == 0 then return end
    local point, relativePoint = origin.point, origin.relativePoint
    local x = (tonumber(origin.x) or 0) + deltaX / ratio
    local y = (tonumber(origin.y) or 0) + deltaY / ratio
    local snappedX, snappedY = ResolveSnap(
      entry, point, origin.relative, relativePoint, x, y)

    -- The cursor origin above remains stable for the full gesture, so applying
    -- this point every shared-driver tick gives immediate feedback without
    -- accumulating a new grab offset at each grid or magnet boundary.
    U.ApplyFramePoint(frame, {
      point = point, relativePoint = relativePoint,
      x = snappedX, y = snappedY,
    })
    entry.snapFromX, entry.snapFromY = snappedX, snappedY
    -- The offset the frame actually took, snapping included, is the offset the
    -- rest of the group takes, handed over in UIParent units.
    MoveFollowers(entry, (snappedX - (tonumber(origin.x) or 0)) * ratio,
                  (snappedY - (tonumber(origin.y) or 0)) * ratio)
    UpdateAlignmentGuides(entry, point, relativePoint, snappedX, snappedY)
  end)
  return true
end

StopDrag = function(entry)
  if not entry.dragging then return false end
  entry.dragging = false
  U.UnregisterUpdate("mover.drag")

  local input = entry.dragInput
  if input then
    pcall(input.StopMovingOrSizing, input)
    ReattachDragInput(entry)
  end
  local before = entry.dragStartPosition
  entry.dragStartPosition = nil
  entry.dragCursorX, entry.dragCursorY = nil, nil
  HideAlignmentGuides()
  if not PositionChanged(before, ReadDragPosition(entry.frame)) then
    dragPlacements = nil
    magnet.cache = nil
    ClearFollowers(entry)
    return true
  end
  -- The drop still snaps against the placements this drag read.
  local captured = CapturePosition(entry)
  dragPlacements = nil
  magnet.cache = nil
  entry.snapFromX, entry.snapFromY = nil, nil
  FinishFollowers(entry, before)
  ClearFollowers(entry)
  -- The panel follows its anchor while the frame is dragged; once the drop is
  -- stored, reconsider which side of the anchor still has room for it.
  if activeMover == entry and type(U.PlaceMoverPanel) == "function" then
    U.PlaceMoverPanel()
  end
  return captured
end

-- ---------------------------------------------------------------------------
-- Drag handle
--
-- Created on first unlock and reused afterwards. knowledge.json /
-- scripts.child_onupdate_unreliable applies here: the handle is populated
-- synchronously at creation and never waits on an OnUpdate tick to become
-- usable.
--
-- The counters exist so /pui check can report whether the client delivered
-- mouse and drag events at all. Without them a handle that never receives
-- OnDragStart is indistinguishable from one whose StartMoving failed.
-- ---------------------------------------------------------------------------
local handleCount = 0
-- Mover handles cover complete interface elements while edit mode is active.
-- A small offset is not enough for elements with raised child frames (action
-- buttons and their cooldown/readout layers are one example): those children
-- can win mouse hit-testing over part of the mover. Keep the offset relative
-- to the moved frame so separate frame ordering is preserved, but leave enough
-- room above its complete child hierarchy for one continuous drag surface.
local HANDLE_LEVEL_OFFSET = 100

-- Lowest strata a drag input may take (see RaiseHandle). MEDIUM clears the
-- top-right HUD; HIGH would cover the edit panels, which sit there.
local INPUT_STRATA_FLOOR = "MEDIUM"
local INPUT_STRATA_RANK = {
  BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
  FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}

-- The anchor draws the client's own Edit Mode selection nine-slice
-- (M.modernWow.moveUI) rather than a flat panel inside a stack of stepped
-- glow strips. The art is Blizzard's, carries its own falloff, and already
-- says what the strips were approximating: cyan for an anchor being pointed
-- at, gold for the one that is selected.
--
-- Every piece is a 16-unit cell centred on the frame's own edge, so the
-- border straddles it by `straddle` in each direction and the centre fill is
-- inset by the same amount. Both kits share one sheet, so a state change is
-- a texture coordinate change rather than a rebuild.
local function CreateHandleArt(handle)
  local token = M.modernWow.moveUI
  if not token or not handle.CreateTexture then return nil end

  local piece, straddle = token.piece, token.straddle
  local art = { pieces = {} }

  -- The fill covers the frame exactly, so it meets the border line rather
  -- than stopping short of it. NineSlice.lua's SetupCenter anchors the Center
  -- to the corner pieces, not to the frame: TOPLEFT to TopLeftCorner's
  -- BOTTOMRIGHT plus the layout's (-8, 8). That corner straddles the frame
  -- corner by `straddle`, so its BOTTOMRIGHT is already `straddle` inside the
  -- frame and the offset puts the fill back on the frame's own edge. Reading
  -- those offsets as frame-relative gives a fill inset or outset by a whole
  -- straddle -- an unfilled band inside the rim, or art spilling past it.
  art.fill = handle:CreateTexture(nil, "BACKGROUND")
  art.fill:SetAllPoints(handle)

  -- `key` names the cell in whichever kit is current; `flipH`/`flipV` reverse
  -- its coordinates, which is how core/media.lua's single authored top-left
  -- corner becomes the other three (the same reversal U.ModernWowHorizontalBar
  -- uses for its flipped divider).
  local function Piece(path, key, flipH, flipV)
    local texture = handle:CreateTexture(nil, "ARTWORK")
    texture:SetTexture(path)
    table.insert(art.pieces, {
      texture = texture, key = key, flipH = flipH, flipV = flipV,
    })
    return texture
  end

  local sheet, vertical = token.texture, token.textureVertical

  local topLeft = Piece(sheet, "corner", false, false)
  topLeft:SetWidth(piece)
  topLeft:SetHeight(piece)
  topLeft:SetPoint("TOPLEFT", handle, "TOPLEFT", -straddle, straddle)

  local topRight = Piece(sheet, "corner", true, false)
  topRight:SetWidth(piece)
  topRight:SetHeight(piece)
  topRight:SetPoint("TOPRIGHT", handle, "TOPRIGHT", straddle, straddle)

  local bottomLeft = Piece(sheet, "corner", false, true)
  bottomLeft:SetWidth(piece)
  bottomLeft:SetHeight(piece)
  bottomLeft:SetPoint("BOTTOMLEFT", handle, "BOTTOMLEFT", -straddle, -straddle)

  local bottomRight = Piece(sheet, "corner", true, true)
  bottomRight:SetWidth(piece)
  bottomRight:SetHeight(piece)
  bottomRight:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", straddle, -straddle)

  local top = Piece(sheet, "top", false, false)
  top:SetHeight(piece)
  top:SetPoint("TOPLEFT", handle, "TOPLEFT", straddle, straddle)
  top:SetPoint("TOPRIGHT", handle, "TOPRIGHT", -straddle, straddle)

  local bottom = Piece(sheet, "bottom", false, false)
  bottom:SetHeight(piece)
  bottom:SetPoint("BOTTOMLEFT", handle, "BOTTOMLEFT", straddle, -straddle)
  bottom:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", -straddle, -straddle)

  local left = Piece(vertical, "left", false, false)
  left:SetWidth(piece)
  left:SetPoint("TOPLEFT", handle, "TOPLEFT", -straddle, -straddle)
  left:SetPoint("BOTTOMLEFT", handle, "BOTTOMLEFT", -straddle, straddle)

  local right = Piece(vertical, "right", false, false)
  right:SetWidth(piece)
  right:SetPoint("TOPRIGHT", handle, "TOPRIGHT", straddle, -straddle)
  right:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", straddle, straddle)

  return art
end

local function SetHandleArtShown(entry, shown)
  local art = entry and entry.handleArt
  if not art then return end

  local index = nil
  for index = 1, table.getn(art.pieces) do
    if shown then
      art.pieces[index].texture:Show()
    else
      art.pieces[index].texture:Hide()
    end
  end
  if shown then art.fill:Show() else art.fill:Hide() end
end

local function ApplyHandleState(entry)
  if not entry or not entry.handle then return end

  local selected = activeMover == entry
  local highlighted = selected or entry.listHovered
  local token = M.modernWow.moveUI
  local art = entry.handleArt

  if art and token then
    local kit = highlighted and token.selected or token.hover
    local state = "idle"
    if highlighted then
      state = "selected"
    elseif entry.hovered then
      state = "hover"
    end

    local index = nil
    for index = 1, table.getn(art.pieces) do
      local part = art.pieces[index]
      local cell = kit[part.key]
      local u1, u2, v1, v2 = cell[1], cell[2], cell[3], cell[4]
      if part.flipH then u1, u2 = u2, u1 end
      if part.flipV then v1, v2 = v2, v1 end
      -- knowledge.json / textures.rle_512_tga_atlas_four_arg_supported: only
      -- the four-argument form is used, guarded like every other texture call
      -- on this client.
      pcall(part.texture.SetTexCoord, part.texture, u1, u2, v1, v2)
      part.texture:SetAlpha(token.alpha[state])
    end

    art.fill:SetTexture(kit.fill)
    art.fill:SetAlpha(token.fillAlpha[state])
  end

  if entry.handle.label then
    if highlighted then entry.handle.label:Show() else entry.handle.label:Hide() end
  end
end

-- Click-outside deselect.
--
-- A full-screen Button under everything edit mode draws: every anchor's drag
-- input takes its strata from the frame it moves, and the edit panel, the
-- contextual panel and the advanced drawer are ordinary windows, so all of
-- them sit above BACKGROUND and take their own clicks first. What reaches
-- this is a click on nothing -- which is the gesture that deselects.
--
-- It exists only while an anchor is selected, and that is deliberate. A
-- mouse-enabled frame over UIParent also stops clicks reaching WorldFrame, so
-- a catcher shown for all of edit mode would cost camera turning and
-- targeting the whole time it is open. Bound to the selection instead, the
-- capture lasts exactly until the click that ends it, and edit mode with
-- nothing selected still behaves like the rest of the UI.
--
-- Every button deselects, not just the left one: the frame swallows a click
-- whether or not that button can fire OnClick, so registering fewer would
-- leave a right-click both unable to turn the camera and unable to clear the
-- selection that is blocking it.
--
-- Shape taken from quickbind's shade (modules/quickbind.lua CreateShade),
-- which swallows world clicks the same way and is known to work here: a
-- Button over UIParent at BACKGROUND, frame level 0. This one draws nothing,
-- so the alignment grid one level above it is unaffected.
local function CreateClickCatcher(onOutsideClick)
  local catcher = CreateFrame("Button", "PandaUIMoverClickCatcher", UIParent)
  pcall(catcher.SetAllPoints, catcher, UIParent)
  pcall(catcher.SetFrameStrata, catcher, "BACKGROUND")
  pcall(catcher.SetFrameLevel, catcher, 0)
  pcall(catcher.EnableMouse, catcher, true)
  pcall(catcher.RegisterForClicks, catcher, "LeftButtonUp", "RightButtonUp")
  catcher:SetScript("OnClick", onOutsideClick)
  catcher:Hide()
  return catcher
end

-- ---------------------------------------------------------------------------
-- Arrow keys held off the client while an anchor is selected
--
-- The edit-mode key catcher hears the arrows, but it does not stop the binding
-- layer: this client resolves a bound key before an addon frame hears it
-- (core/searchbox.lua, modules/quickbind.lua), so a nudge also turned or moved
-- the character (user report, 2026-09-29). While an anchor is selected, each
-- bound arrow is taken off the client with SetBinding and put back when the
-- selection ends -- core/searchbox.lua's typing-mode mechanism. The catcher
-- receives unbound keys too, so nudging is unaffected.
--
-- Nothing is saved: the change is to the live set only and SaveBindings is
-- never called. The held list is still written to SavedVariables, so keys left
-- off by a disconnect or crash mid-edit are put back on the next load, and
-- leaving the world releases them first.
-- ---------------------------------------------------------------------------
local nudgeKeys = {
  KEYS = { "LEFT", "RIGHT", "UP", "DOWN" },
  held = {},   -- { { key = , command = }, ... }
}

function nudgeKeys.Call(name, a1, a2)
  local fn = U.G(name)
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, a1, a2)
  if not ok then return nil end
  return result
end

function nudgeKeys.Store(held)
  local config = MoverConfig()
  if held then config.heldKeys = held end
  if type(config.heldKeys) ~= "table" then config.heldKeys = {} end
  return config.heldKeys
end

function nudgeKeys.Hold()
  if table.getn(nudgeKeys.held) > 0 then return end
  local held = {}
  local i
  for i = 1, table.getn(nudgeKeys.KEYS) do
    local key = nudgeKeys.KEYS[i]
    local command = nudgeKeys.Call("GetBindingAction", key)
    if type(command) == "string" and command ~= "" then
      nudgeKeys.Call("SetBinding", key)
      table.insert(held, { key = key, command = command })
    end
  end
  nudgeKeys.held = held
  nudgeKeys.Store(held)
end

-- Puts back every held key the client has not been given to something else.
function nudgeKeys.Release(list)
  list = list or nudgeKeys.held
  local i
  for i = 1, table.getn(list) do
    local entry = list[i]
    if type(entry) == "table" and type(entry.key) == "string" and
       type(entry.command) == "string" then
      local current = nudgeKeys.Call("GetBindingAction", entry.key)
      if type(current) ~= "string" or current == "" then
        nudgeKeys.Call("SetBinding", entry.key, entry.command)
      end
    end
  end
  nudgeKeys.held = {}
  nudgeKeys.Store({})
end

if type(U.RegisterEvent) == "function" then
  U.RegisterEvent("PLAYER_ENTERING_WORLD", function()
    if table.getn(nudgeKeys.held) > 0 then return end
    local leftovers = nudgeKeys.Store()
    if table.getn(leftovers) > 0 then nudgeKeys.Release(leftovers) end
  end)
  U.RegisterEvent("PLAYER_LEAVING_WORLD", function() nudgeKeys.Release() end)
end

-- True once the user closed the selected anchor's panel. The anchor stays
-- selected so it can be moved without the panel in the way; dragging it does
-- not bring the panel back, a plain click on it does.
local panelDismissed = false

local function SetActiveMover(entry, reopenPanel)
  local previous = activeMover
  activeMover = entry
  if entry ~= previous or reopenPanel then panelDismissed = false end
  ApplyHandleState(previous)
  if entry ~= previous then ApplyHandleState(entry) end

  if entry and unlocked then nudgeKeys.Hold() else nudgeKeys.Release() end

  -- A local function is in scope inside its own body, so the catcher can call
  -- straight back here to clear the selection it was created for.
  if entry and unlocked then
    if not clickCatcher then
      clickCatcher = CreateClickCatcher(function() SetActiveMover(nil) end)
    end
    clickCatcher:Show()
  elseif clickCatcher then
    clickCatcher:Hide()
  end

  -- The panel belongs to the anchor, not to the edit window: it is handed the
  -- addon-owned handle so it can sit beside that anchor and carry its label as
  -- the window title. Using the handle rather than entry.frame also keeps the
  -- panel off a client-owned relative when a mover deliberately owns a native
  -- root such as Classic's MainMenuBar.
  --
  -- Which movers have a panel is not decided here: a module registers one for
  -- its own mover id (core/moverpanel.lua), and a mover with no registered
  -- panel simply selects with nothing beside it.
  if entry and panelDismissed then
    -- Closed by the user for this selection: leave it down.
    return
  elseif entry and type(entry.id) == "string" and
     type(U.ShowMoverPanel) == "function" then
    U.ShowMoverPanel(entry.id, {
      id = entry.id, frame = entry.handle or entry.frame, label = entry.label,
    })
  elseif type(U.HideMoverPanel) == "function" then
    U.HideMoverPanel()
  end
end

-- Deselects whatever handle is selected. The contextual panel's close button
-- calls this rather than hiding itself, so the handle stops being highlighted
-- at the same moment its panel goes away; SetActiveMover(nil) is what takes the
-- panel down. Returns false when nothing was selected, which lets
-- U.CloseMoverPanel fall back to a plain hide.
function U.ClearMoverSelection()
  if not activeMover then return false end
  SetActiveMover(nil)
  return true
end

-- The contextual panel's close button: hides the panel but keeps the anchor
-- selected (highlight, arrow-key nudging, click-outside deselect). Returns
-- false when nothing is selected, so U.CloseMoverPanel falls back to a hide.
function U.DismissMoverPanel()
  if not activeMover then return false end
  panelDismissed = true
  if type(U.HideMoverPanel) == "function" then U.HideMoverPanel() end
  return true
end

local function RaiseHandle(entry)
  if not entry or not entry.handle then return false end
  local levelOk, level = pcall(entry.frame.GetFrameLevel, entry.frame)
  if not levelOk or not tonumber(level) then return false end
  local handleLevel = level + HANDLE_LEVEL_OFFSET
  local raised = pcall(entry.handle.SetFrameLevel, entry.handle, handleLevel)
  if entry.dragInput then
    -- The input is a UIParent child, so it does not inherit the moved frame's
    -- strata. Without matching it the handle would win hit-testing and the
    -- drag gesture would never reach the Button that owns it.
    --
    -- Read from the moved frame, not the handle. /pui movesnap 2026-09-17: at
    -- unlock every handle read GetFrameStrata "PARENT" (it inherits), so the
    -- input was set to "PARENT" too and resolved against UIParent -- MEDIUM.
    -- That is above a LOW anchor but BELOW the HIGH cast bars, whose handles
    -- then covered their inputs: 0 OnEnter, 0 drag starts, unselectable.
    -- Most anchors inherit their target's strata. A native root may contain
    -- client buttons above that level, so a caller can raise only the temporary
    -- edit-mode input without changing the actual frame's draw order.
    local strata = entry.inputStrata
    if not strata then
      local strataOk, value = pcall(entry.frame.GetFrameStrata, entry.frame)
      if strataOk and type(value) == "string" and value ~= "PARENT" then
        strata = value
      else
        strataOk, value = pcall(entry.handle.GetFrameStrata, entry.handle)
        if strataOk and type(value) == "string" and value ~= "PARENT" then
          strata = value
        end
      end
    end
    -- Floor it at INPUT_STRATA_FLOOR. An anchor under a BACKGROUND or LOW frame
    -- (minimap, quest and craft trackers) otherwise lost its input wherever
    -- MEDIUM HUD overlapped it -- the native buff and debuff buttons in the
    -- top-right corner -- and could not be picked up there (user report,
    -- 2026-09-29). Only the temporary input is raised; the frame keeps its
    -- strata, and the edit panels stay above it at HIGH.
    if not strata or (INPUT_STRATA_RANK[strata] or 0) <
                     INPUT_STRATA_RANK[INPUT_STRATA_FLOOR] then
      strata = INPUT_STRATA_FLOOR
    end
    pcall(entry.dragInput.SetFrameStrata, entry.dragInput, strata)
    pcall(entry.dragInput.SetFrameLevel, entry.dragInput, handleLevel + 1)
  end
  return raised
end

local function CreateHandle(entry)
  handleCount = handleCount + 1

  -- Named because an unnamed Button gives the client nothing to report in an
  -- error, and the mover handles are exactly what a drag failure is about.
  local handle = CreateFrame("Button", "PandaUIMoverHandle" .. handleCount,
                             entry.frame)
  handle:SetAllPoints(entry.frame)
  -- Visual only: every script lives on the input below. A mouse-enabled handle
  -- that ends up above its input swallows the hover and the drag.
  pcall(handle.EnableMouse, handle, false)

  -- Match the settings slider's reliable two-layer drag: this visible handle
  -- never enters native movement. A separate transparent Button owns the
  -- complete OnDragStart -> StartMoving -> OnDragStop gesture while the anchor
  -- below it follows the shared cursor updater.
  --
  -- It is a UIParent child rather than a child of the handle, because the
  -- handle covers the anchor and therefore moves with it: see DetachDragInput
  -- for why nothing in the dragged Button's hierarchy may be re-anchored while
  -- the client is moving it. frames.movable_drag_requires_button_handle rules
  -- out a plain Frame raised by strata, not a Button ordered by frame level,
  -- and U.CreateSlider's thumb is the working precedent for a Button that is
  -- not parented to what it moves. While idle it still covers the handle
  -- exactly, so the press that starts a drag lands on it.
  --
  -- Its shown state deliberately follows ShowHandle/HideHandle, not
  -- handle:IsVisible(). Unit and cast frames are hidden while empty and expose
  -- their edit-mode shells on the next shared refresh after U.UnlockUI. If the
  -- UIParent-owned input inherits that brief hidden state, nothing calls back
  -- into the mover when the shell appears and the visible anchor can never be
  -- hovered. The mover lifetime is the authoritative mouse gate.
  local input = CreateFrame("Button", "PandaUIMoverDragInput" .. handleCount,
                            UIParent)
  input:SetAllPoints(handle)
  input:RegisterForDrag("LeftButton")
  pcall(input.EnableMouse, input, true)

  -- No U.CreateBackdrop here: the Edit Mode art carries its own centre fill
  -- and border, and a flat panel under it would only show through the art's
  -- transparent straddle.
  entry.handleArt = CreateHandleArt(handle)

  -- knowledge.json / buttons.plain_settext_no_fontstring: an untemplated Button
  -- can accept SetText without ever showing a FontString, so the label is a
  -- FontString pandaUI creates and owns rather than the Button's own text.
  local label = U.CreateLabel(handle, {
    size = M.fontSize.small,
    color = M.color.text,
    inherits = "GameFontNormal",
  })
  if label then
    label:SetPoint("CENTER", handle, "CENTER", 0, 0)
    label:SetText(entry.label)
  end
  handle.label = label

  -- knowledge.json / scripts.handler_arguments_direct: these close over entry
  -- instead of depending on the callback argument shape.
  -- dragGesture tells OnClick whether this press was a drag: a drag keeps a
  -- closed panel closed, a plain click on the anchor reopens it.
  input:SetScript("OnMouseDown", function() entry.dragGesture = nil end)

  input:SetScript("OnDragStart", function()
    entry.dragGesture = true
    SetActiveMover(entry)
    entry.dragStarts = entry.dragStarts + 1
    StartDrag(entry)
  end)

  input:SetScript("OnDragStop", function()
    entry.dragStops = entry.dragStops + 1
    StopDrag(entry)
  end)

  -- Second release path. The detached input stays under the cursor for the
  -- whole native move, so a release lands on it even when the client does not
  -- deliver the drag callback; StopDrag is idempotent, so receiving both is
  -- harmless. This matters because this client documents no
  -- IsMouseButtonDown -- see LeftButtonStillDown -- and therefore offers no
  -- way to poll a missed release back out of the shared updater.
  input:SetScript("OnMouseUp", function() StopDrag(entry) end)

  input:SetScript("OnClick", function()
    SetActiveMover(entry, not entry.dragGesture)
    entry.dragGesture = nil
  end)

  -- OnEnter is instrumentation as much as highlight: if the enter count stays
  -- at zero the client is not routing mouse input to the handle at all, which
  -- is a different failure from a drag that starts and does not move.
  input:SetScript("OnEnter", function()
    entry.enters = entry.enters + 1
    entry.hovered = true
    ApplyHandleState(entry)
  end)

  input:SetScript("OnLeave", function()
    entry.hovered = false
    ApplyHandleState(entry)
  end)

  entry.handle = handle
  entry.dragInput = input
  RaiseHandle(entry)
  ApplyHandleState(entry)
  return handle
end

-- The edit window, its anchor drawer and the per-anchor settings panel all sit
-- at HIGH. A moved frame in HIGH or above (the cast bars, raised over crafting
-- windows) puts its handle there too, at frame level + HANDLE_LEVEL_OFFSET, so
-- the handle drew over those panels. While its handle is shown such a frame is
-- held at MEDIUM; the strata it had is restored when the handle goes away.
local EDIT_CHROME_STRATA = "HIGH"
local EDIT_TARGET_STRATA = "MEDIUM"

local function LowerForEdit(entry)
  if entry.editStrata then return end
  local ok, strata = pcall(entry.frame.GetFrameStrata, entry.frame)
  if not ok or type(strata) ~= "string" then return end
  if (INPUT_STRATA_RANK[strata] or 0) <
     INPUT_STRATA_RANK[EDIT_CHROME_STRATA] then
    return
  end
  if pcall(entry.frame.SetFrameStrata, entry.frame, EDIT_TARGET_STRATA) then
    entry.editStrata = strata
  end
end

local function RestoreEditStrata(entry)
  local strata = entry.editStrata
  if not strata then return end
  entry.editStrata = nil
  pcall(entry.frame.SetFrameStrata, entry.frame, strata)
end

local function HideHandle(entry)
  entry.handleShown = false
  RestoreEditStrata(entry)
  -- An anchor whose element a module has just switched off must not stay
  -- selected: its highlight and panel would be gone, but the click catcher
  -- holding the screen would not.
  if activeMover == entry then SetActiveMover(nil) end
  if type(U.SetMoverSampleShown) == "function" then
    pcall(U.SetMoverSampleShown, entry.id, false)
  end
  if not entry.handle then return end
  -- Hiding a Button during a drag does not reliably promise an OnDragStop on
  -- this client. Finish it explicitly so locking the UI or hiding an element
  -- can never leave its frame attached to the cursor.
  if entry.dragging then StopDrag(entry) end
  entry.hovered = false
  entry.listHovered = false
  if entry.handle.label then entry.handle.label:Hide() end
  SetHandleArtShown(entry, false)
  if entry.dragInput then entry.dragInput:Hide() end
  entry.handle:Hide()
end

-- A module may register a frame that is not always part of the layout -- a
-- disabled action bar keeps its stored position but must not offer a handle to
-- drag. options.visible is that predicate; without one a mover is available.
IsEntryAvailable = function(entry)
  if type(entry.visible) ~= "function" then return true end
  local ok, visible = pcall(entry.visible)
  if not ok then return true end
  return visible and true or false
end

-- Advanced visibility is a second gate over module availability. Keeping the
-- two separate lets the drawer distinguish "the user hid this anchor" from
-- "this feature/bar currently has no anchor to show".
IsEntryVisible = function(entry)
  if not advanced.UserEnabled(entry) then return false end
  return IsEntryAvailable(entry)
end

local function ShowHandle(entry)
  if not IsEntryVisible(entry) then
    HideHandle(entry)
    return
  end

  if not entry.handle then CreateHandle(entry) end
  -- Before RaiseHandle, which reads the frame's strata for the drag input.
  LowerForEdit(entry)
  -- Parent/native frame levels can change while the handle is hidden. Refresh
  -- on every unlock instead of trusting the value captured at construction.
  RaiseHandle(entry)
  entry.handle:Show()
  if entry.dragInput then entry.dragInput:Show() end
  -- rendering.parent_alpha_not_propagated: children are shown and hidden
  -- explicitly rather than relying on the parent's visibility carrying.
  SetHandleArtShown(entry, true)
  ApplyHandleState(entry)
  entry.handleShown = true

  -- An anchor that is empty right now gets a sample of the content that will
  -- occupy it, so it is not placed blind. Most movers register none and this
  -- is a no-op for them.
  if type(U.SetMoverSampleShown) == "function" then
    pcall(U.SetMoverSampleShown, entry.id, true)
  end
end

-- ---------------------------------------------------------------------------
-- Edit-mode overlay
--
-- The grid is plain textures on one full-screen frame: behavior.json /
-- textures.pfui_bar_path.v1 verifies that path, and it keeps the overlay off
-- backdrop edges, which are not reliably rasterised here.
--
-- Lines are laid out from UIParent's centre outwards so the grid is symmetric
-- and the centre axes land exactly on 0,0 -- the offsets a snapped drop
-- produces are multiples of the selected grid size from that same origin.
-- ---------------------------------------------------------------------------

local function LayoutGridLine(index, vertical, offset, color, length, thickness)
  local line = grid.puiLines[index]
  if not line then
    line = grid:CreateTexture(nil, "BACKGROUND")
    line:SetTexture(M.texture.plain)
    grid.puiLines[index] = line
  end
  line:ClearAllPoints()
  U.SetColor(line, M.Unpack(color))

  if vertical then
    line:SetWidth(thickness)
    line:SetHeight(length)
    line:SetPoint("CENTER", UIParent, "CENTER", offset, 0)
  else
    line:SetWidth(length)
    line:SetHeight(thickness)
    line:SetPoint("CENTER", UIParent, "CENTER", 0, offset)
  end

  line:Show()
  return line
end

local function LayoutGrid(previewSize)
  local width, height = U.UIWidth(), U.UIHeight()
  local thickness = U.BorderSize()
  local offset, index = nil, 0
  local size = tonumber(previewSize)
  if size then
    size = math.floor(size + 0.5)
    if size < MIN_GRID_SIZE then size = MIN_GRID_SIZE end
    if size > MAX_GRID_SIZE then size = MAX_GRID_SIZE end
  else
    size = GridSize()
  end

  index = index + 1
  LayoutGridLine(index, true, 0, M.color.gridAxis, height, thickness)
  index = index + 1
  LayoutGridLine(index, false, 0, M.color.gridAxis, width, thickness)

  offset = size
  while offset < width / 2 do
    index = index + 1
    LayoutGridLine(index, true, offset, M.color.grid, height, thickness)
    index = index + 1
    LayoutGridLine(index, true, -offset, M.color.grid, height, thickness)
    offset = offset + size
  end

  offset = size
  while offset < height / 2 do
    index = index + 1
    LayoutGridLine(index, false, offset, M.color.grid, width, thickness)
    index = index + 1
    LayoutGridLine(index, false, -offset, M.color.grid, width, thickness)
    offset = offset + size
  end

  local i
  for i = index + 1, table.getn(grid.puiLines) do
    grid.puiLines[i]:Hide()
  end
end

local function CreateGrid()
  grid = CreateFrame("Frame", "PandaUIGrid", UIParent)
  grid:SetAllPoints(UIParent)
  grid.puiLines = {}
  pcall(grid.SetFrameStrata, grid, "BACKGROUND")
  -- Keep the decoration above any BACKGROUND-strata shade (quick binding
  -- uses one to swallow world clicks) while remaining below normal UI.
  pcall(grid.SetFrameLevel, grid, 1)
  -- The grid is decoration; it must never eat a click meant for a handle.
  pcall(grid.EnableMouse, grid, false)

  LayoutGrid()
  grid:Hide()
end

-- Live centre guides are independent from the optional grid: hiding the grid
-- makes movement continuous, but a precisely centred anchor still receives
-- the requested red visual confirmation. Full-screen lines keep alignment with
-- both the screen centre and another mover readable across the layout.
local function CreateAlignmentGuides()
  alignmentGuides = CreateFrame("Frame", "PandaUIAlignmentGuides", UIParent)
  alignmentGuides:SetAllPoints(UIParent)
  pcall(alignmentGuides.SetFrameStrata, alignmentGuides, "HIGH")
  pcall(alignmentGuides.EnableMouse, alignmentGuides, false)

  alignmentGuides.vertical = alignmentGuides:CreateTexture(nil, "OVERLAY")
  alignmentGuides.vertical:SetTexture(M.texture.plain)
  U.SetColor(alignmentGuides.vertical, M.Unpack(M.color.moverGuide))

  alignmentGuides.horizontal = alignmentGuides:CreateTexture(nil, "OVERLAY")
  alignmentGuides.horizontal:SetTexture(M.texture.plain)
  U.SetColor(alignmentGuides.horizontal, M.Unpack(M.color.moverGuide))

  alignmentGuides.vertical:Hide()
  alignmentGuides.horizontal:Hide()
  alignmentGuides:Hide()
end

HideAlignmentGuides = function()
  if not alignmentGuides then return end
  alignmentGuides.vertical:Hide()
  alignmentGuides.horizontal:Hide()
  alignmentGuides:Hide()
end

UpdateAlignmentGuides = function(entry, point, relativePoint, x, y)
  local left, right, bottom, top = MoverBounds(entry, {
    point = point, relativePoint = relativePoint, x = x, y = y,
  })
  if not left then
    HideAlignmentGuides()
    return
  end

  local centerX, centerY = (left + right) / 2, (bottom + top) / 2
  local guideX, guideY
  local screenCenterX, screenCenterY = U.UIWidth() / 2, U.UIHeight() / 2
  if math.abs(centerX - screenCenterX) <= ALIGNMENT_EPSILON then
    guideX = screenCenterX
  end
  if math.abs(centerY - screenCenterY) <= ALIGNMENT_EPSILON then
    guideY = screenCenterY
  end
  local i
  -- Any of the anchor's three lines per axis on the same line of a nearby
  -- anchor, touching or not: the pairs and range the snap uses (AlignDelta,
  -- magnet.Near).
  for i = 1, table.getn(moverOrder) do
    if guideX and guideY then break end
    local other = movers[moverOrder[i]]
    if other ~= entry and IsEntryVisible(other) and
       not IsFollower(entry, other) then
      local otherLeft, otherRight, otherBottom, otherTop =
        MoverBounds(other, OtherPosition(other))
      if otherLeft then
        if not guideX and magnet.Near(bottom, top, otherBottom, otherTop,
                                      U.UIHeight()) then
          guideX = AlignedLine(left, right, otherLeft, otherRight)
        end
        if not guideY and magnet.Near(left, right, otherLeft, otherRight,
                                      U.UIWidth()) then
          guideY = AlignedLine(bottom, top, otherBottom, otherTop)
        end
      end
    end
  end

  if not guideX and not guideY then
    HideAlignmentGuides()
    return
  end
  if not alignmentGuides then CreateAlignmentGuides() end
  alignmentGuides:Show()

  local thickness = U.BorderSize()
  if guideX then
    alignmentGuides.vertical:ClearAllPoints()
    alignmentGuides.vertical:SetWidth(thickness)
    alignmentGuides.vertical:SetHeight(U.UIHeight())
    alignmentGuides.vertical:SetPoint(
      "CENTER", UIParent, "CENTER", guideX - screenCenterX, 0)
    alignmentGuides.vertical:Show()
  else
    alignmentGuides.vertical:Hide()
  end
  if guideY then
    alignmentGuides.horizontal:ClearAllPoints()
    alignmentGuides.horizontal:SetWidth(U.UIWidth())
    alignmentGuides.horizontal:SetHeight(thickness)
    alignmentGuides.horizontal:SetPoint(
      "CENTER", UIParent, "CENTER", 0, guideY - screenCenterY)
    alignmentGuides.horizontal:Show()
  else
    alignmentGuides.horizontal:Hide()
  end
end

-- Edit mode's housing and controls under every theme (user request,
-- 2026-10-25): the diamond-metal frame, the red close X and the game settings
-- window's control art, the way Retail's edit-mode dialogs wear one dialog
-- border, UIPanelCloseButton and the settings controls (RetailFrameXML
-- 12.1.0.69933, Blizzard_EditMode/Shared/EditModeDialogs.xml:254-319).
-- Shared with core/moverpanel.lua through the same exports.
local editChrome = {}

function editChrome.Housing(frame, width, height)
  if type(U.ModernWowMetalFrame) ~= "function" then return end
  if U.ModernWowMetalFrame(frame, width, height, true) then
    U.SetBackdropShown(frame, false)
  end
end

function editChrome.CheckboxSize()
  if type(U.GameSettingsCheckboxSize) == "function" then
    return U.GameSettingsCheckboxSize()
  end
  return 14
end

-- Art only: these windows are laid out around the flat controls.
function editChrome.StyleControls(widgets)
  if type(U.StyleGameSettingsWidgets) == "function" then
    U.StyleGameSettingsWidgets(widgets, true)
  end
end

function editChrome.CloseX(frame, name, onClick)
  local token = M.editModeChrome.close
  local button = U.CreateRedCloseButton(frame, {
    name = name, size = token.size, onClick = onClick,
  })
  if not button then return nil end
  button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -token.right, -token.top)
  return button
end

-- The edit panel is the only way out of edit mode that does not need a slash
-- command. It is deliberately not registered as a mover: it belongs to the mode
-- rather than to the layout.
local function CreateEditPanel()
  editPanel = U.CreatePanel(UIParent, {
    name = "PandaUIEditPanel",
    width = 280,
    height = 237,
  })
  editPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  pcall(editPanel.SetFrameStrata, editPanel, "HIGH")
  editChrome.Housing(editPanel, 280, 237)

  local title = U.CreateLabel(editPanel, {
    size = M.fontSize.large,
    color = M.color.accent,
    inherits = "GameFontNormal",
  })
  if title then
    title:SetPoint("TOP", editPanel, "TOP", 0, -12)
    title:SetText(U.L("MOVER_TITLE"))
  end
  editPanel.title = title

  local hint3 = U.CreateLabel(editPanel, {
    size = M.fontSize.small,
    color = M.color.textDim,
    inherits = "GameFontNormalSmall",
    width = 252,
  })
  if hint3 then
    hint3:SetPoint("TOP", editPanel, "TOP", 0, -34)
    hint3:SetText(U.L("MOVER_HINT_ARROWS"))
  end
  editPanel.hint3 = hint3

  local config = MoverConfig()
  editPanel.gridToggle = U.CreateCheckbox(editPanel, {
    name = "PandaUIEditGridToggle",
    text = U.L("MOVER_GRID"),
    size = editChrome.CheckboxSize(),
    textWidth = 220,
    value = config.gridShown,
    onChange = function(value)
      MoverConfig().gridShown = value
      if value then U.ShowAlignmentGrid() else U.HideAlignmentGrid() end
    end,
  })
  editPanel.gridToggle.SetPoint("TOPLEFT", editPanel, "TOPLEFT", 18, -54)

  editPanel.magnetToggle = U.CreateCheckbox(editPanel, {
    name = "PandaUIEditMagnetToggle",
    text = U.L("MOVER_MAGNET"),
    size = editChrome.CheckboxSize(),
    textWidth = 220,
    value = config.magnet,
    onChange = function(value) MoverConfig().magnet = value end,
  })
  editPanel.magnetToggle.SetPoint("TOPLEFT", editPanel, "TOPLEFT", 18, -76)

  editPanel.groupToggle = U.CreateCheckbox(editPanel, {
    name = "PandaUIEditGroupToggle",
    text = U.L("MOVER_GROUP"),
    size = editChrome.CheckboxSize(),
    textWidth = 220,
    value = config.groupTouching,
    onChange = function(value) MoverConfig().groupTouching = value end,
  })
  editPanel.groupToggle.SetPoint("TOPLEFT", editPanel, "TOPLEFT", 18, -98)

  editPanel.gridSlider = U.CreateSlider(editPanel, {
    name = "PandaUIEditGridSize",
    text = U.L("MOVER_GRID_SIZE"),
    width = 220,
    min = MIN_GRID_SIZE,
    max = MAX_GRID_SIZE,
    step = 1,
    value = GridSize(),
    onInput = function(value)
      if grid then LayoutGrid(value) end
    end,
    onChange = function(value)
      MoverConfig().gridSize = value
      if grid then LayoutGrid() end
    end,
  })
  editPanel.gridSlider.SetPoint("TOP", editPanel, "TOP", 0, -135)

  editPanel.save = U.CreateButton(editPanel, {
    name = "PandaUIEditSave",
    text = U.L("MOVER_SAVE_EXIT"),
    width = 140,
    height = 24,
    onClick = function() U.LockUI() end,
  })
  editPanel.save:SetPoint("BOTTOM", editPanel, "BOTTOM", -38, 12)

  editPanel.reset = U.CreateButton(editPanel, {
    name = "PandaUIEditReset",
    text = U.L("MOVER_RESET"),
    width = 68,
    height = 24,
    onClick = function()
      U.ShowConfirm({
        owner = "mover.reset",
        editMode = true,
        centered = true,
        text = U.L("COMMON_ARE_YOU_SURE"),
        detail = U.L("COMMON_CANNOT_BE_UNDONE"),
        acceptText = U.L("MOVER_RESET"),
        onAccept = function() U.ResetPositions() end,
      })
    end,
  })
  editPanel.reset:SetPoint("BOTTOM", editPanel, "BOTTOM", 68, 12)

  -- The edit window uses the same persistent header-drag behavior as the other
  -- PandaUI windows. Only its title strip is a drag surface, leaving every
  -- option below fully interactive.
  -- Retail's edit-mode window closes from a red X at its top-right; here it
  -- leaves edit mode, as Save and exit does. Kept above the title-strip drag
  -- handle and its drag input, which would otherwise take its clicks.
  local close = editChrome.CloseX(editPanel, "PandaUIEditClose",
    function() U.LockUI() end)
  editPanel.close = close
  local closeOffsets
  if close then
    closeOffsets = {}
    closeOffsets[close] = 2
  end

  U.MakeWindowDraggable("mover.edit", editPanel, {
    headerHeight = 30,
    headerInset = 0,
    avoidOverlap = false,
    interactiveFrames = close and { close } or nil,
    interactiveFrameOffsets = closeOffsets,
  })

  editChrome.StyleControls({
    editPanel.gridToggle, editPanel.magnetToggle, editPanel.groupToggle,
    editPanel.gridSlider, editPanel.save, editPanel.reset,
  })

  editPanel:Hide()
end

local function SetControlShown(control, shown)
  local parts = control and control.puiParts
  if type(parts) ~= "table" then return end
  local i
  for i = 1, table.getn(parts) do
    if shown then parts[i]:Show() else parts[i]:Hide() end
  end
end

-- ---------------------------------------------------------------------------
-- Advanced anchor drawer
--
-- A row controls edit-mode visibility only. Grouped rows (the pet unit frame)
-- hide and restore all of their mover handles together without touching the
-- underlying interface frames. A row is checked only while at least one of its
-- handles is actually shown by the mover system; unavailable and class-reserved
-- action pages are unchecked and disabled.
-- ---------------------------------------------------------------------------
function advanced.SetContentShown(shown)
  if not shown and advanced.ClearHighlights then advanced.ClearHighlights() end
  if advanced.title then
    if shown then advanced.title:Show() else advanced.title:Hide() end
  end
  local i
  for i = 1, table.getn(advanced.rows) do
    SetControlShown(advanced.rows[i], shown)
  end
end

function advanced.SetArrow(open)
  if not advanced.arrow or not advanced.arrow.label then return end
  local label = U.L("MOVER_ADVANCED_ANCHORS")
  advanced.arrow.label:SetText(open and ("<<  " .. label) or
                                        (label .. "  >>"))
end

function advanced.SetWidth(width)
  width = tonumber(width) or advanced.closedWidth
  if width < advanced.closedWidth then width = advanced.closedWidth end
  if width > advanced.width then width = advanced.width end
  advanced.currentWidth = width
  if advanced.panel then
    advanced.panel:SetWidth(width)
    editChrome.Housing(advanced.panel, width, advanced.height)
  end
end

function advanced.SetOpen(open, immediate)
  if not advanced.panel then return end
  open = open and true or false
  advanced.open = open
  advanced.SetArrow(open)
  advanced.SetContentShown(false)

  local target = open and advanced.width or advanced.closedWidth
  if open then advanced.panel:Show() end

  if immediate then
    U.StopEasing("mover.advanced")
    advanced.SetWidth(target)
    if open then
      advanced.SetContentShown(true)
    else
      advanced.panel:Hide()
    end
    return
  end

  U.StartEasing("mover.advanced", {
    from = advanced.currentWidth,
    to = target,
    duration = advanced.duration,
    ease = open and U.EaseOutCubic or U.EaseInOutCubic,
    onUpdate = advanced.SetWidth,
    onComplete = function()
      if advanced.open then
        advanced.SetContentShown(true)
      else
        advanced.panel:Hide()
      end
    end,
  })
end

function advanced.GroupLocked(group)
  if not group.actionBar then return false end
  if type(U.ActionBarIsNative) == "function" and
     U.ActionBarIsNative(group.actionBar) then return true end
  return type(U.ActionBarReservation) == "function" and
         U.ActionBarReservation(group.actionBar) ~= nil
end

-- Existing module toggles remain the single saved source of truth. nil means a
-- group has no module-level setting and therefore uses mover.anchorEnabled.
function advanced.GroupSettingValue(group)
  if not group then return nil end
  if group.actionBar then
    if type(U.ActionBarIsNative) == "function" and
       U.ActionBarIsNative(group.actionBar) then return true end
    if advanced.GroupLocked(group) or
       type(U.GetActionBarSetting) ~= "function" then return nil end
    return U.GetActionBarSetting(group.actionBar, "Enabled")
  end
  if group.nativeAuras then
    if type(U.GetNativeAuraFrameShown) ~= "function" then return nil end
    return U.GetNativeAuraFrameShown()
  end
  local setting = group.setting
  if not setting then return nil end
  local defaults = {}
  defaults[setting.key] = setting.default
  local config = U.ModuleConfig(setting.module, defaults)
  return config[setting.key] and true or false
end

function advanced.SetGroupSetting(group, value)
  if group.actionBar then
    if advanced.GroupLocked(group) or
       type(U.SetActionBarSetting) ~= "function" then return false, value end
    local stored = U.SetActionBarSetting(group.actionBar, "Enabled", value)
    return stored ~= nil, stored and true or false
  end
  if group.nativeAuras then
    if type(U.SetNativeAuraFrameShown) ~= "function" then return false, value end
    U.SetNativeAuraFrameShown(value)
    return true, U.GetNativeAuraFrameShown()
  end
  local setting = group.setting
  if not setting then return false, value end
  local defaults = {}
  defaults[setting.key] = setting.default
  U.ModuleConfig(setting.module, defaults)[setting.key] = value and true or false
  local apply = U[setting.apply]
  if type(apply) == "function" then apply() end
  return true, value and true or false
end

-- The group for one drawer key, with the lookup filled on first use.
function advanced.Group(key)
  if type(key) ~= "string" then return nil end
  if advanced.groupLookup[key] then return advanced.groupLookup[key] end
  local i
  for i = 1, table.getn(advanced.groups) do
    advanced.groupLookup[advanced.groups[i].key] = advanced.groups[i]
  end
  return advanced.groupLookup[key]
end

-- One place applies a group's visibility, whoever asked for it: the drawer
-- row, the contextual panel beside the anchor, or the element's settings page.
-- The saved preference, the handles, the content gate and the rows are all
-- written from here, so the views of one element cannot drift into several
-- settings. Returns the value that was actually stored.
function advanced.ApplyGroup(group, value)
  if not group then return nil end

  local handled, stored = advanced.SetGroupSetting(group, value)
  if handled then
    -- Older builds kept a second mover-only gate. Once a real module setting
    -- owns this row, discard that stale value so every view reads and writes
    -- exactly one saved preference.
    MoverConfig().anchorEnabled[group.key] = nil
    value = stored
  else
    MoverConfig().anchorEnabled[group.key] = value and true or false
  end

  local i
  for i = 1, table.getn(group.movers) do
    local entry = movers[group.movers[i]]
    if entry then
      if value or group.keepAnchor then
        -- Handles exist only in edit mode; the content gate is persistent, so
        -- it is released whether or not the drawer is on screen. A settings
        -- page can switch an element back on with edit mode closed.
        if unlocked then ShowHandle(entry) end
        advanced.SetEntryContent(entry, true)
      else
        if activeMover == entry then SetActiveMover(nil) end
        HideHandle(entry)
        advanced.SetEntryContent(entry, false)
      end
    end
  end

  advanced.RefreshRows()

  local notify = advanced.changed[group.key]
  if type(notify) == "function" then pcall(notify, value and true or false) end
  return value and true or false
end

-- ---------------------------------------------------------------------------
-- The drawer rows as a public switch
--
-- A drawer row is the addon's show/hide for a whole HUD element. A module that
-- offers the same switch somewhere else -- a contextual mover panel, its page
-- in the settings window -- reads and writes it through these rather than
-- storing a second preference of its own.
-- ---------------------------------------------------------------------------
function U.MoverGroupEnabled(key)
  local group = advanced.Group(key)
  if not group then return nil end
  local setting = advanced.GroupSettingValue(group)
  if setting ~= nil then return setting and true or false end
  local enabled = MoverConfig().anchorEnabled
  return type(enabled) ~= "table" or enabled[key] ~= false
end

function U.SetMoverGroupEnabled(key, value)
  local group = advanced.Group(key)
  if not group then return nil end
  return advanced.ApplyGroup(group, value and true or false)
end

-- fn(enabled) whenever that element's switch is written from anywhere.
function U.OnMoverGroupChanged(key, fn)
  if type(key) ~= "string" or type(fn) ~= "function" then return false end
  advanced.changed[key] = fn
  return true
end

function advanced.GroupAvailable(group)
  if advanced.GroupSettingValue(group) ~= nil then return true end
  local i
  for i = 1, table.getn(group.movers) do
    local entry = movers[group.movers[i]]
    if entry and IsEntryAvailable(entry) then return true end
  end
  return false
end

function advanced.GroupShown(group)
  local settingValue = advanced.GroupSettingValue(group)
  if settingValue ~= nil then return settingValue and true or false end
  local i
  for i = 1, table.getn(group.movers) do
    local entry = movers[group.movers[i]]
    if entry and entry.handleShown then return true end
  end
  return false
end

function advanced.UserEnabled(entry)
  local groupKey = entry and advanced.moverKeys[entry.id]
  if not groupKey then return true end
  local group = advanced.Group(groupKey)
  -- The module gates its own content and the anchor always stays.
  if group and group.keepAnchor then return true end
  local settingValue = advanced.GroupSettingValue(group)
  if settingValue ~= nil then return settingValue and true or false end
  local enabled = MoverConfig().anchorEnabled
  local actionBar = advanced.moverActionBars[entry.id]
  local reserved = actionBar and type(U.ActionBarReservation) == "function" and
                   U.ActionBarReservation(actionBar) ~= nil
  return reserved or type(enabled) ~= "table" or enabled[groupKey] ~= false
end

function advanced.EnforceHiddenContent()
  local _, entry, i
  -- Runs every frame: reuse one scratch list instead of a new table.
  local release = advanced.releaseScratch
  if not release then
    release = {}
    advanced.releaseScratch = release
  end
  for _, entry in pairs(advanced.hiddenEntries) do
    if advanced.UserEnabled(entry) then
      table.insert(release, entry)
    else
      advanced.SetEntryContent(entry, false)
    end
  end
  local count = table.getn(release)
  if count == 0 then return end
  -- Empty the list before releasing, so a re-entrant call starts clean.
  local pending = {}
  for i = count, 1, -1 do
    pending[i] = release[i]
    table.remove(release, i)
  end
  for i = 1, count do
    advanced.SetEntryContent(pending[i], true)
  end
end

-- The advanced rows control the whole HUD element, not only its edit handle.
-- Most movers own their content frame, so hiding that frame is sufficient.
-- Native-backed movers provide setEditShown to apply the same persistent gate
-- without changing their module's separate feature configuration.
function advanced.SetEntryContent(entry, shown)
  if not entry then return end

  if shown == nil or shown then
    if not entry.editContentHidden then return end
    if type(entry.setEditShown) == "function" then
      pcall(entry.setEditShown, nil)
    else
      -- Rows can only be re-enabled from edit mode. Show the owned frame
      -- directly so modules whose cached edit-state already says "shown" do
      -- not leave content hidden after the persistent gate is removed.
      pcall(entry.frame.Show, entry.frame)
    end
    entry.editContentHidden = false
    if advanced.hiddenEntries[entry.id] then
      advanced.hiddenEntries[entry.id] = nil
      advanced.hiddenCount = math.max(advanced.hiddenCount - 1, 0)
      if advanced.hiddenCount == 0 then
        U.UnregisterUpdate("mover.advanced.hidden")
      end
    end
    return
  end

  local shownOk, nowShown = pcall(entry.frame.IsShown, entry.frame)
  if not entry.editContentHidden then
    advanced.hiddenEntries[entry.id] = entry
    advanced.hiddenCount = advanced.hiddenCount + 1
    if advanced.hiddenCount == 1 then
      U.RegisterUpdate("mover.advanced.hidden", 0, advanced.EnforceHiddenContent)
    end
  end
  entry.editContentHidden = true
  if type(entry.setEditShown) == "function" then
    pcall(entry.setEditShown, false)
  elseif not shownOk or (nowShown and nowShown ~= 0) then
    pcall(entry.frame.Hide, entry.frame)
  end
end

function advanced.RefreshRow(row)
  local group = row and row.puiAdvancedGroup
  if not group then return end
  local locked = advanced.GroupLocked(group)
  local available = advanced.GroupAvailable(group)
  local checked = advanced.GroupShown(group)
  if row.value ~= checked then row.SetValue(checked) end
  local enabled = available and not locked
  if row.enabled ~= enabled then row.SetEnabled(enabled) end
end

function advanced.RefreshRows()
  local i
  for i = 1, table.getn(advanced.rows) do
    advanced.RefreshRow(advanced.rows[i])
  end
end

function advanced.SetGroupHighlighted(group, shown)
  local i
  for i = 1, table.getn(group.movers) do
    local entry = movers[group.movers[i]]
    if entry then
      entry.listHovered = shown and entry.handleShown and true or false
      ApplyHandleState(entry)
    end
  end
end

function advanced.ClearHighlights()
  local i
  for i = 1, table.getn(moverOrder) do
    local entry = movers[moverOrder[i]]
    if entry and entry.listHovered then
      entry.listHovered = false
      ApplyHandleState(entry)
    end
  end
end

-- While edit mode is open, feature settings can still change underneath the
-- drawer. Keep both sides of the contract aligned: a newly available mover is
-- shown when its checkbox permits it, a mover that becomes unavailable is
-- hidden, and the checkbox follows that same result.
function advanced.Sync()
  if not unlocked then return end
  local i
  for i = 1, table.getn(moverOrder) do
    local entry = movers[moverOrder[i]]
    local shown = IsEntryVisible(entry)
    if shown and not entry.handleShown then
      ShowHandle(entry)
    elseif not shown and entry.handleShown then
      HideHandle(entry)
      -- An anchor that has left the layout cannot stay selected: its
      -- contextual settings panel would be left beside an element that is no
      -- longer there. Unticking Enable in that very panel is the usual way to
      -- get here, so this is what closes it. The bar is re-enabled from its
      -- page in the settings window.
      if activeMover == entry then SetActiveMover(nil) end
    end
    advanced.SetEntryContent(entry, advanced.UserEnabled(entry))
  end
  advanced.RefreshRows()
end

function advanced.AddRow(group)
  if not advanced.panel or not group then return end

  local index = table.getn(advanced.rows) + 1
  local column = math.floor((index - 1) / advanced.rowsPerColumn)
  local line = (index - 1) - column * advanced.rowsPerColumn
  local row
  row = U.CreateCheckbox(advanced.panel, {
    name = "PandaUIAdvancedAnchorToggle" .. index,
    text = U.L(group.labelKey, group.labelArg),
    size = editChrome.CheckboxSize(),
    textWidth = 132,
    rowHover = true,
    rowWidth = advanced.columnWidth - 10,
    rowHeight = editChrome.CheckboxSize(),
    value = true,
    onEnter = function() advanced.SetGroupHighlighted(group, true) end,
    onLeave = function() advanced.SetGroupHighlighted(group, false) end,
    onChange = function(value)
      advanced.ApplyGroup(group, value)
    end,
  })
  row.puiAdvancedGroup = group
  editChrome.StyleControls({ row })
  row.SetPoint("TOPLEFT", advanced.panel, "TOPLEFT",
               28 + column * advanced.columnWidth,
               -40 - line * advanced.rowSpacing)
  table.insert(advanced.rows, row)
  advanced.RefreshRow(row)
  SetControlShown(row, advanced.open)
end

function advanced.Build()
  if advanced.panel then return end

  advanced.panel = U.CreatePanel(UIParent, {
    name = "PandaUIAdvancedMoverPanel",
    width = advanced.closedWidth,
    height = advanced.height,
  })
  advanced.panel:SetPoint("TOPLEFT", editPanel, "TOPRIGHT",
                          M.editModeChrome.drawerGap, 0)
  pcall(advanced.panel.SetFrameStrata, advanced.panel, "HIGH")

  advanced.title = U.CreateLabel(advanced.panel, {
    size = M.fontSize.normal,
    color = M.color.accent,
    inherits = "GameFontNormal",
    width = advanced.width - 40,
    justify = "LEFT",
  })
  if advanced.title then
    advanced.title:SetPoint("TOPLEFT", advanced.panel, "TOPLEFT", 28, -14)
    advanced.title:SetText(U.L("MOVER_ADVANCED_ANCHORS"))
  end

  -- A full-width, labelled row inside the edit window cannot be lost behind
  -- the drawer or missed as an unlabelled edge glyph. The double chevron keeps
  -- its open/close direction explicit while reusing the localized drawer title.
  advanced.arrow = U.CreateButton(editPanel, {
    name = "PandaUIAdvancedMoverArrow",
    text = U.L("MOVER_ADVANCED_ANCHORS") .. "  >>",
    width = 244,
    height = 24,
    background = M.color.accentFill,
    border = M.color.accent,
    hoverBorder = M.color.accent,
    textColor = M.color.accent,
    onClick = function() advanced.SetOpen(not advanced.open, false) end,
  })
  advanced.arrow:SetPoint("TOP", editPanel, "TOP", 0, -168)
  pcall(advanced.arrow.SetFrameStrata, advanced.arrow, "HIGH")
  editChrome.StyleControls({ advanced.arrow })
  local levelOk, level = pcall(editPanel.GetFrameLevel, editPanel)
  if levelOk and tonumber(level) then
    pcall(advanced.panel.SetFrameLevel, advanced.panel, level + 1)
    pcall(advanced.arrow.SetFrameLevel, advanced.arrow, level + 2)
  end

  local i
  for i = 1, table.getn(advanced.groups) do
    advanced.AddRow(advanced.groups[i])
  end

  advanced.SetContentShown(false)
  advanced.panel:Hide()
  advanced.arrow:Hide()
end

function advanced.Show()
  advanced.Build()
  advanced.RefreshRows()
  -- Several HUD modules refresh every rendered frame while editing. Run after
  -- them on the shared driver so an unchecked entry cannot be re-shown between
  -- slower polling intervals.
  U.RegisterUpdate("mover.advanced.sync", 0, advanced.Sync)
  advanced.arrow:Show()
  advanced.SetOpen(advanced.open, true)
end

function advanced.Hide()
  U.UnregisterUpdate("mover.advanced.sync")
  U.StopEasing("mover.advanced")
  advanced.SetContentShown(false)
  if advanced.panel then advanced.panel:Hide() end
  if advanced.arrow then advanced.arrow:Hide() end
end

-- Keyboard input is deliberately scoped to edit mode. Runtime evidence shows
-- a shown keyboard-enabled Frame captures every key and cannot propagate the
-- rest of the input layer, but that is safe while this modal edit mode is open.
-- It must be a plain Frame and use OnKeyDown; Buttons and OnKeyUp do not work.
local function ResolveKey(a, b)
  if type(a) == "string" then return a end
  if type(b) == "string" then return b end
  local legacy = U.G("arg1")
  if type(legacy) == "string" then return legacy end
  return nil
end

local function NudgeActiveMover(x, y)
  local entry = activeMover
  if not entry or entry.dragging or not IsEntryVisible(entry) then return false end

  -- Keyboard nudges deliberately bypass both grid and magnet snapping so each
  -- arrow press moves exactly one UIParent unit, converted into the frame's
  -- own units (EntryScale). They still preserve drag grouping: nothing is
  -- towed by a live anchor, and touching anchors travel together.
  PinToUIParent(entry)
  PinPassengers(entry)

  -- From the anchor the player can see, not the stored tuple (EntryPosition).
  local position = EntryPosition(entry)
  if not position then
    U.Print(U.L("MOVER_DRAG_FIRST", entry.label))
    return false
  end

  entry.followers = MoverConfig().groupTouching and CollectFollowers(entry) or {}
  entry.followerSet = {}
  local followerIndex
  for followerIndex = 1, table.getn(entry.followers) do
    entry.followerSet[entry.followers[followerIndex].entry.id] = true
  end

  local ratio = EntryScale(entry)
  local nextX = (tonumber(position.x) or 0) + x / ratio
  local nextY = (tonumber(position.y) or 0) + y / ratio

  local saved = U.SavePosition(entry.id, position.point, position.relativePoint,
                               nextX, nextY)
  if saved then
    U.ApplyFramePoint(entry.frame, U.GetPosition(entry.id))
    FinishFollowers(entry, position)
  end
  ClearFollowers(entry)
  return saved
end

local function CreateEditKeys()
  editKeys = CreateFrame("Frame", "PandaUIMoverKeys", UIParent)
  pcall(editKeys.SetAllPoints, editKeys, UIParent)
  pcall(editKeys.SetFrameStrata, editKeys, "FULLSCREEN_DIALOG")
  pcall(editKeys.EnableKeyboard, editKeys, true)
  pcall(editKeys.EnableMouse, editKeys, false)

  editKeys:SetScript("OnKeyDown", function(a, b)
    local key = ResolveKey(a, b)
    if key == "LEFT" then
      NudgeActiveMover(-1, 0)
    elseif key == "RIGHT" then
      NudgeActiveMover(1, 0)
    elseif key == "UP" then
      NudgeActiveMover(0, 1)
    elseif key == "DOWN" then
      NudgeActiveMover(0, -1)
    elseif key == "ESCAPE" then
      U.LockUI()
    end
  end)
  editKeys:Hide()
end

-- rendering.parent_alpha_not_propagated: children are shown and hidden
-- explicitly rather than relying on the parent's visibility carrying.
local function ShowEditOverlay()
  if not editPanel then CreateEditPanel() end
  if not editKeys then CreateEditKeys() end

  local config = MoverConfig()
  editPanel.gridToggle.SetValue(config.gridShown)
  editPanel.magnetToggle.SetValue(config.magnet)
  editPanel.gridSlider.SetValue(GridSize())
  if config.gridShown then U.ShowAlignmentGrid() else U.HideAlignmentGrid() end
  editPanel:Show()
  editKeys:Show()
  if editPanel.title then editPanel.title:Show() end
  if editPanel.hint3 then editPanel.hint3:Show() end
  SetControlShown(editPanel.gridToggle, true)
  SetControlShown(editPanel.magnetToggle, true)
  SetControlShown(editPanel.groupToggle, true)
  SetControlShown(editPanel.gridSlider, true)
  if editPanel.save then editPanel.save:Show() end
  if editPanel.reset then editPanel.reset:Show() end
  advanced.Show()
end

local function HideEditOverlay()
  U.HideAlignmentGrid()
  HideAlignmentGuides()
  U.HideConfirm("mover.reset")
  if type(U.HideMoverPanel) == "function" then
    U.HideMoverPanel()
  end
  if editKeys then editKeys:Hide() end
  if not editPanel then return end

  if editPanel.title then editPanel.title:Hide() end
  if editPanel.hint3 then editPanel.hint3:Hide() end
  SetControlShown(editPanel.gridToggle, false)
  SetControlShown(editPanel.magnetToggle, false)
  SetControlShown(editPanel.groupToggle, false)
  SetControlShown(editPanel.gridSlider, false)
  if editPanel.save then editPanel.save:Hide() end
  if editPanel.reset then editPanel.reset:Hide() end
  advanced.Hide()
  editPanel:Hide()
end

function U.GridSize()
  return GridSize()
end

-- The alignment grid is shared by edit mode and other full-screen placement
-- modes. Callers own their mode lifetime and must hide it when they close.
function U.ShowAlignmentGrid()
  if not grid then CreateGrid() else LayoutGrid() end
  grid:Show()
  return grid
end

function U.HideAlignmentGrid()
  if grid then grid:Hide() end
end

-- ---------------------------------------------------------------------------
-- Edit-mode diagnostic snapshot
--
-- Anchors that appear on the first unlock and not on the second cannot be
-- diagnosed from chat: CreateEditKeys' keyboard capture means no slash command
-- is reachable while edit mode is open, and the per-mover readout is far past
-- what is worth screenshotting. Every unlock and lock therefore appends one
-- machine-readable snapshot to PandaUIDiagDB.moverLog, read straight out of
-- SavedVariables after a /reload.
--
-- Write-only, capped by U.AppendDiagnostic, and every client call is pcall'd:
-- the diagnostic must never become the thing that breaks edit mode.
-- ---------------------------------------------------------------------------
local function Probe(object, method)
  if not object then return "-" end
  local fn = object[method]
  if type(fn) ~= "function" then return "?" end
  local ok, value = pcall(fn, object)
  if not ok then return "err" end
  if value == nil then return "nil" end
  return value
end

local function Stamp()
  if type(date) ~= "function" then return "?" end
  local ok, formatted = pcall(date, "%Y-%m-%d %H:%M:%S")
  if ok and type(formatted) == "string" then return formatted end
  return "?"
end

-- failures is the list built by the Show/HideHandle walks below: a mover whose
-- handle call threw is exactly what a blank edit mode looks like, and it is
-- invisible in any readback taken afterwards.
local function SnapshotMovers(phase, failures, overlayError)
  if type(U.AppendDiagnostic) ~= "function" then return end

  local entries, i = {}, nil
  for i = 1, table.getn(moverOrder) do
    local entry = movers[moverOrder[i]]
    local handle = entry and entry.handle
    table.insert(entries, {
      id = entry and entry.id or "?",
      order = i,
      entryVisible = entry and IsEntryVisible(entry) and true or false,
      frameShown = Probe(entry and entry.frame, "IsShown"),
      frameVisible = Probe(entry and entry.frame, "IsVisible"),
      frameLevel = Probe(entry and entry.frame, "GetFrameLevel"),
      frameAlpha = Probe(entry and entry.frame, "GetAlpha"),
      hasHandle = handle and true or false,
      handleShown = Probe(handle, "IsShown"),
      handleVisible = Probe(handle, "IsVisible"),
      handleLevel = Probe(handle, "GetFrameLevel"),
      handleWidth = Probe(handle, "GetWidth"),
      handleHeight = Probe(handle, "GetHeight"),
    })
  end

  U.AppendDiagnostic("moverLog", {
    phase = phase,
    at = Stamp(),
    unlocked = unlocked and true or false,
    moverCount = table.getn(moverOrder),
    overlayError = overlayError,
    failures = failures,
    gridShown = Probe(grid, "IsShown"),
    panelShown = Probe(editPanel, "IsShown"),
    keysShown = Probe(editKeys, "IsShown"),
    entries = entries,
  })
end

-- One mover whose handle call throws must not cost every anchor after it in
-- moverOrder, which an unguarded walk did. Each call is isolated and the
-- failure recorded for the snapshot instead.
local function WalkHandles(action)
  local i, failures = nil, nil
  for i = 1, table.getn(moverOrder) do
    local entry = movers[moverOrder[i]]
    local ok, err = pcall(action, entry)
    if not ok then
      failures = failures or {}
      table.insert(failures, {
        id = entry and entry.id or "?",
        order = i,
        err = tostring(err),
      })
      U.Error("mover " .. (entry and entry.id or "?") .. ": " .. tostring(err))
    end
  end
  return failures
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

-- A window that is dragged directly and never registers a mover still needs
-- the same bottom-edge conversion the anchorEdge option gives a mover: a drag
-- the client collapses onto a TOP point would otherwise make a content-sized
-- window grow downwards, pushing its lower rows off the screen. Takes the same
-- id, frame and default a mover entry carries so both paths run one
-- implementation instead of a module-local copy. modules/bags.lua is the
-- current caller.
function U.PinFrameToBottomEdge(id, frame, default)
  if type(id) ~= "string" or not frame then
    U.Error("PinFrameToBottomEdge requires an id and a frame")
    return false
  end

  NormaliseAnchorEdge({
    id = id,
    frame = frame,
    anchorEdge = "BOTTOM",
    default = default,
  })
  return true
end

-- id       stable string key, also the SavedVariables key
-- frame    the frame the user drags
-- options  { label = "Player", default = { point, relativePoint, x, y },
--            visible = function() return true end,
--            setEditShown = function(falseOrNil) end,
--            inputStrata = "HIGH",
--            scalable = true,   -- edit mode offers a Scale (%) slider
--            onScale = function(factor) end }  -- extra frames to follow it
function U.RegisterMover(id, frame, options)
  if type(id) ~= "string" or not frame then
    U.Error("RegisterMover requires an id and a frame")
    return nil
  end
  if movers[id] then
    U.Error("mover already registered: " .. id)
    return movers[id]
  end

  options = options or {}

  local entry = {
    id = id,
    frame = frame,
    label = options.label or id,
    default = options.default,
    visible = options.visible,
    setEditShown = options.setEditShown,
    -- Optional edit-mode-only input override for a native target whose own
    -- children otherwise sit above the transparent drag/click Button.
    inputStrata = options.inputStrata,
    -- "BOTTOM" for a window that changes height with its content: it is then
    -- always held by its bottom edge and grows upwards. See NormaliseAnchorEdge.
    anchorEdge = options.anchorEdge,
    -- Space kept around the anchor when the magnet joins it to another: a
    -- number, or a function returning x, y or left, right, bottom, top
    -- (frame units). See magnet.Padding.
    snapPadding = options.snapPadding,
    -- Drawn regions with their transparent margins, measured live instead.
    -- See magnet.ArtPadding.
    snapArt = options.snapArt,
    dragging = false,
    -- Measured drag activity; reported by U.MoverReport.
    enters = 0,
    dragStarts = 0,
    dragStops = 0,
  }

  movers[id] = entry
  table.insert(moverOrder, id)

  pcall(frame.SetMovable, frame, true)

  -- Scale before position: the stored offsets are in the scaled frame's units.
  if options.scalable then
    entry.scalable = true
    entry.onScale = options.onScale
    entry.baseScale = scaling.FrameScale(frame) or 1
    scaling.byFrame[frame] = entry
    -- Also at 100%: a child of a scaled anchor divides that scale out.
    if scaling.Percent(entry) ~= 100 or U.MoverAncestorScale(frame) ~= 1 then
      scaling.Apply(entry)
    end
  end

  -- Position is applied immediately, not deferred to a tick.
  ApplyStoredPosition(entry)

  advanced.SetEntryContent(entry, advanced.UserEnabled(entry))
  if unlocked then
    ShowHandle(entry)
  end
  if advanced.panel then advanced.RefreshRows() end
  return entry
end

function U.IsUnlocked()
  return unlocked
end

function U.UnlockUI()
  unlocked = true
  if U.db then U.db.locked = false end

  SetActiveMover(nil)

  -- Isolated for the same reason the handle walk is: the overlay failing must
  -- not stop every anchor from being shown, and the error has to survive into
  -- the snapshot rather than vanishing under error suppression.
  local overlayOk, overlayError = pcall(ShowEditOverlay)
  if not overlayOk then
    U.Error("mover overlay: " .. tostring(overlayError))
  else
    overlayError = nil
  end

  local failures = WalkHandles(ShowHandle)
  if advanced.panel then advanced.Sync() end
  SnapshotMovers("unlock", failures, overlayError and tostring(overlayError))
  -- Handles only exist from the first unlock, so the arm-time snapshot has no
  -- layering to show; this one does.
  if trace.on then
    trace.atUnlock = trace.Snapshot()
    trace.lockedAt = nil
    trace.Publish("unlocked")
  end

  U.Print(U.L("MOVER_ENTERED"))
end

-- Diagnostic driver, every frame while the tracer is armed.
--
--   * focus: GetMouseFocus (documented, pcall-guarded) whenever it changes,
--     named and mapped to the mover part it is, so a handle that cannot be
--     clicked shows what takes the cursor instead.
--   * drift: every mover's live rect every 0.25 s; a change is logged with
--     whether a drag was in progress, so an anchor moved by its own module
--     (after a drop, after lock, on a target change) is caught.
--   * after lock: keeps watching for LOCK_WATCH seconds, then saves.
function trace.Watch()
  if not trace.on then
    U.UnregisterUpdate("mover.diag")
    return
  end
  local now = GetTime()
  local i

  local focusFn = U.G("GetMouseFocus")
  if type(focusFn) == "function" then
    local ok, focus = pcall(focusFn)
    local name = ok and trace.Name(focus) or "error"
    if name ~= trace.lastFocus then
      trace.lastFocus = name
      local part = nil
      if ok and focus then
        for i = 1, table.getn(moverOrder) do
          local entry = movers[moverOrder[i]]
          if entry then
            if focus == entry.handle then part = entry.id .. ":handle"
            elseif focus == entry.dragInput then part = entry.id .. ":input"
            elseif focus == entry.frame then part = entry.id .. ":frame" end
          end
          if part then break end
        end
      end
      local cursorOk, cx, cy = pcall(U.G("GetCursorPosition"))
      local scale = Edge(UIParent, "GetEffectiveScale") or 1
      if scale <= 0 then scale = 1 end
      trace.Log(trace.focus, {
        focus = name, part = part,
        widget = ok and part == nil and focus and trace.Widget(focus) or nil,
        cursorX = cursorOk and Rounded((tonumber(cx) or 0) / scale) or nil,
        cursorY = cursorOk and Rounded((tonumber(cy) or 0) / scale) or nil,
      })
    end
  end

  if now >= trace.nextDrift then
    trace.nextDrift = now + 0.25
    local dragging = nil
    for i = 1, table.getn(moverOrder) do
      local entry = movers[moverOrder[i]]
      if entry and entry.dragging then dragging = entry.id end
    end
    for i = 1, table.getn(moverOrder) do
      local entry = movers[moverOrder[i]]
      if entry then
        local left, right, bottom, top = LiveRect(entry)
        local key = left and (Rounded(left) .. "," .. Rounded(bottom) .. "," ..
                              Rounded(right) .. "," .. Rounded(top)) or "none"
        local last = trace.rects[entry.id]
        if last and last ~= key then
          local stored = U.GetPosition(entry.id)
          trace.Log(trace.drift, {
            id = entry.id, from = last, to = key, dragging = dragging,
            storedX = stored and Rounded(stored.x),
            storedY = stored and Rounded(stored.y),
            storedPoint = stored and stored.point,
            points = Edge(entry.frame, "GetNumPoints"),
            parent = trace.Widget(entry.frame).parent,
          })
        end
        trace.rects[entry.id] = key
      end
    end
  end

  if trace.lockedAt and now - trace.lockedAt >= trace.LOCK_WATCH then
    local _, count, dropped = trace.Stop("lock+" .. trace.LOCK_WATCH .. "s")
    U.Print("mover snap trace: " .. tostring(count) .. " samples" ..
            (dropped > 0 and (", " .. tostring(dropped) .. " dropped") or "") ..
            " saved to PandaUIDiagDB.moveSnap - |cffffff00/reload|r then " ..
            "open " .. U.SavedVariablesHint() .. " to read it")
  end
end

function U.LockUI()
  -- The tracer is armed before edit mode because no command can be typed while
  -- the overlay is up. Closing the overlay starts a short watch instead of
  -- ending the run, so an anchor its module moves after the drop is recorded.
  if trace.on and not trace.lockedAt then
    trace.afterLock = trace.Snapshot()
    trace.lockedAt = GetTime()
    trace.Publish("locked, watching")
    U.Print("mover snap trace: watching " .. trace.LOCK_WATCH ..
            " s more (change target now), then it saves itself")
  end

  -- Before `unlocked` goes false, so the selection is cleared through the same
  -- path a click outside uses and the click catcher comes down with it. A
  -- catcher left shown after edit mode closes would hold the whole screen.
  SetActiveMover(nil)

  unlocked = false
  if U.db then U.db.locked = true end

  HideEditOverlay()

  local failures = WalkHandles(HideHandle)
  SnapshotMovers("lock", failures)

  U.Print(U.L("MOVER_SAVED"))
end

function U.ToggleUI()
  if unlocked then U.LockUI() else U.UnlockUI() end
end

-- Called after /pui reset has cleared the position store, so a callback can
-- re-anchor its frame from scratch. Return true when a frame was restored, so
-- it is counted in the same total the movers are.
function U.OnPositionReset(callback)
  if type(callback) ~= "function" then
    U.Error("OnPositionReset requires a function")
    return false
  end
  table.insert(resetHooks, callback)
  return true
end

-- Drops every saved position and puts each registered frame back on its
-- module-supplied default.
function U.ResetPositions()
  U.ClearAllPositions()
  -- The defaults were authored at the owner's own size, so scales reset too.
  MoverConfig().scales = {}
  scaling.preview = nil

  local i, restored = nil, 0
  for i = 1, table.getn(moverOrder) do
    local entry = movers[moverOrder[i]]
    if entry.scalable then scaling.Apply(entry) end
    if ApplyStoredPosition(entry) then restored = restored + 1 end
  end

  for i = 1, table.getn(resetHooks) do
    local ok, handled = pcall(resetHooks[i])
    if ok and handled then restored = restored + 1 end
  end

  U.Print(U.LN("MOVER_RESET", restored))
  return restored
end

-- Re-applies the stored (or default) point of the mover that owns `frame`.
-- For a module that changes a registered frame's own scale after
-- RegisterMover already placed it: the moveSnap trace of 2026-09-11 recorded
-- the 0.75 modern-wow cast bar stored at x=831, y=-344 but drawn at left 623.33,
-- top 318 -- the offsets are resolved with the frame's scale at SetPoint time,
-- so a point applied at scale 1 and then rescaled lands somewhere else after
-- every reload.
function U.ReapplyMoverPosition(frame)
  if not frame then return false end
  local i
  for i = 1, table.getn(moverOrder) do
    local entry = movers[moverOrder[i]]
    if entry and entry.frame == frame then
      return ApplyStoredPosition(entry)
    end
  end
  return false
end

-- Screen watch. A larger UI scale shrinks UIParent in its own units, so a HUD
-- anchor placed near an edge at a smaller scale ends up past that edge.
-- UI_SCALE_CHANGED is not on this client (modules/gamesettings.lua polls for
-- the same reason), so UIParent's effective scale and the screen size are
-- read on a slow tick. On a change, every mover whose stored (or default)
-- position now needs a clamp, or was clamped before, is re-applied through
-- ApplyStoredPosition: clamped in, applied, never re-saved, so a smaller
-- scale gives the original placement back.
local screenWatch = { INTERVAL = 0.5, SCALE_EPSILON = 0.001, SIZE_EPSILON = 0.5 }

function screenWatch.Changed(scale, width, height)
  local last = screenWatch.last
  return not last or
         math.abs(scale - last.scale) > screenWatch.SCALE_EPSILON or
         math.abs(width - last.width) > screenWatch.SIZE_EPSILON or
         math.abs(height - last.height) > screenWatch.SIZE_EPSILON
end

function screenWatch.Tick()
  local scale = Edge(UIParent, "GetEffectiveScale")
  if not scale or scale <= 0 then return end
  local width, height = U.UIWidth(), U.UIHeight()
  if not screenWatch.Changed(scale, width, height) then return end

  local first = not screenWatch.last
  local i
  -- A drag or a pending drop owns its frame; retry on the next tick.
  if not first then
    if pendingSnap then return end
    for i = 1, table.getn(moverOrder) do
      local entry = movers[moverOrder[i]]
      if entry and entry.dragging then return end
    end
  end
  screenWatch.last = { scale = scale, width = width, height = height }
  -- Registration already clamped against the screen as it was then.
  if first then return end

  for i = 1, table.getn(moverOrder) do
    local entry = movers[moverOrder[i]]
    local position = entry and (U.GetPosition(entry.id) or entry.default)
    if position then
      local _, needed = U.ClampPositionToScreen(entry.frame, position)
      if needed or entry.clamped then ApplyStoredPosition(entry) end
    end
  end
end

U.RegisterUpdate("mover.screenwatch", screenWatch.INTERVAL, screenWatch.Tick)

function U.MoverCount()
  return table.getn(moverOrder)
end

-- Reports what the client actually did with each mover, so a drag that does not
-- work produces measured detail instead of a shrug. `enters` distinguishes "no
-- mouse input reached the handle" from "input arrived but the move failed", and
-- movable/mouse are read back rather than assumed from the setter succeeding.
function U.MoverReport()
  local report, i = {}, nil

  for i = 1, table.getn(moverOrder) do
    local entry = movers[moverOrder[i]]
    local line = {
      id = entry.id,
      enters = entry.enters,
      dragStarts = entry.dragStarts,
      dragStops = entry.dragStops,
      hasHandle = entry.handle and true or false,
      saved = U.GetPosition(entry.id) and true or false,
    }

    -- A readback of `false` is a real answer and must not be collapsed into the
    -- "call unavailable" case, so ok is tested on its own.
    local ok, value = pcall(entry.frame.IsMovable, entry.frame)
    if ok then line.movable = value else line.movable = "?" end

    line.mouse = "-"
    if entry.handle then
      ok, value = pcall(entry.handle.GetObjectType, entry.handle)
      if ok and value then line.handleType = value else line.handleType = "?" end

      ok, value = pcall(entry.handle.IsMouseEnabled, entry.handle)
      if ok then line.mouse = value else line.mouse = "?" end
    end

    local point, _, _, x, y = U.GetFramePoint(entry.frame, 1)
    line.point = point or "none"
    line.x = x
    line.y = y

    table.insert(report, line)
  end

  return report
end
