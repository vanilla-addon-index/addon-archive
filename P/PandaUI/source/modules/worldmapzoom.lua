-- pandaUI :: modules/worldmapzoom.lua
--
-- Mouse-wheel zoom and drag panning on the native World Map.
--
-- ---------------------------------------------------------------------------
-- Why the map is scaled, not resized
-- ---------------------------------------------------------------------------
--
-- Every stock map position is relative: units, flags, the corpse, the ping
-- and the highlight are placed at (u * width, -v * height) from
-- WorldMapDetailFrame's TOPLEFT, POIs from WorldMapButton's, and the stock
-- click/hover hit-test divides GetCursorPosition by the canvas's effective
-- scale (Octo FrameXML WorldMapFrame.lua, WorldMapButton_OnClick/OnUpdate).
-- Addon pins (pandaQuest, Questline, pandaConquest, this addon's own arrow
-- and readout) are children of WorldMapButton built the same way.
--
-- So the two native canvases are moved into one addon content frame and that
-- frame is scaled. Everything drawn on the map scales with it and keeps its
-- map position by construction, with no addon having to recompute anything.
-- Resizing the canvases instead would leave every addon's pins at stale
-- offsets until that addon happened to refresh.
--
-- The content sits inside a ScrollFrame used only to clip it to the original
-- map rectangle. Panning moves the content's own anchor; the scroll offsets
-- are never used, so nothing depends on how this client measures a scaled
-- scroll child's range.
--
--   WorldFrame  (never reparented; WorldMapFrame is, see Windowed map)
--     PandaUIWorldMapViewport  (ScrollFrame, FULLSCREEN, on the native map
--                               rectangle, shown and hidden with the map)
--       PandaUIWorldMapZoomHolder  (scroll child, same size, never scrolled)
--         PandaUIWorldMapZoomContent  (scaled, anchored at -panX, panY)
--           WorldMapDetailFrame  (native tiles and overlays)
--           WorldMapButton       (native hit-test, units, POIs, addon pins)
--
-- Frames that must stay readable and fixed while zoomed (the native zone
-- label, the cursor readout) stay where they are in the tree and are
-- counter-scaled and anchored to the viewport (U.WorldMapZoomPin).
--
-- ---------------------------------------------------------------------------
-- Evidence
-- ---------------------------------------------------------------------------
--
--   * Octo FrameXML WorldMapFrame.xml (STATIC_ANALYSIS): WorldMapDetailFrame
--     is 1002 x 668, TOPLEFT on WorldMapPositioningGuide's TOP at -502, -69;
--     WorldMapButton is TOPLEFT on WorldMapDetailFrame; WorldMapFrameAreaFrame
--     is a WorldMapButton child anchored TOP, 0, -10.
--   * pfUI-octo modules/map.lua (WORKING_112_SOURCE): WorldMapFrame wheel
--     input through EnableMouseWheel + OnMouseWheel, and RegisterForDrag
--     dragging, on this client.
--   * knowledge.json / map.worldmap_open_workers_require_worldframe_parent:
--     UIParent is hidden while the map is open, so the drag driver is a
--     WorldFrame child.
--   * NOT runtime-verified: clipping of the scaled native canvases by the
--     ScrollFrame, whether mouse hits are clipped with them, and the SetPoint
--     offset units under SetScale. PandaRuntimeProbe group `mapzoom` measures
--     the last two and samples this module's state while the map is used
--     (knowledge.json / map.worldmap_zoom_scaled_content_viewport).

local U = PandaUI

local ZOOM = U.RegisterModule("worldmapzoom")

local MIN_ZOOM = 1
local MAX_ZOOM = 4
local ZOOM_STEP = 0.5

-- The native rectangle, from WorldMapFrame.xml. The anchor is re-applied from
-- these constants rather than read back: GetPoint is avoided on the map tree.
local NATIVE_ANCHOR_X = -502
local NATIVE_ANCHOR_Y = -69

local state = {
  installed = false,
  failure = nil,
  zoom = 1,
  panX = 0,
  panY = 0,
  width = nil,
  height = nil,
  mapKey = nil,
  pins = {},
  dragging = false,
  justDragged = false,
  downX = nil,
  downY = nil,
  downPanX = 0,
  downPanY = 0,
  wheelCount = 0,
  dragCount = 0,
  swallowedClicks = 0,
  arrowScaled = 0,
  openingFrames = nil,
  levels = {},
}
ZOOM.state = state

local function NumberMethod(object, method)
  if not object or type(object[method]) ~= "function" then return nil end
  local ok, value = pcall(object[method], object)
  if ok then return tonumber(value) end
  return nil
end

local function Clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

-- Cursor position in viewport units, measured from its TOPLEFT (y down).
-- Returns nil when the geometry is unavailable; inside is false when the
-- cursor is outside the visible map rectangle.
local function CursorInView()
  local viewport = state.viewport
  local cursor = U.G("GetCursorPosition")
  if not viewport or type(cursor) ~= "function" then return nil end
  local ok, x, y = pcall(cursor)
  if not ok or not tonumber(x) or not tonumber(y) then return nil end
  local scale = NumberMethod(viewport, "GetEffectiveScale")
  local left = NumberMethod(viewport, "GetLeft")
  local top = NumberMethod(viewport, "GetTop")
  if not scale or scale == 0 or not left or not top then return nil end
  local cx = x / scale - left
  local cy = top - y / scale
  local inside = cx >= 0 and cy >= 0 and cx <= state.width and cy <= state.height
  return cx, cy, inside
end

local function ClampPan()
  local z = state.zoom
  state.panX = Clamp(state.panX, 0, state.width - state.width / z)
  state.panY = Clamp(state.panY, 0, state.height - state.height / z)
end

-- SetPoint offsets are in the anchored frame's own scaled units on 1.12
-- (knowledge.json / layout.unreal_scale_and_getpoint_compensation_wrong_on_112),
-- so the pan is kept in content units and passed through unchanged.
local function ApplyPins()
  local i
  for i = 1, table.getn(state.pins) do
    local pin = state.pins[i]
    local frame = pin.frame
    pcall(frame.SetScale, frame, pin.scale / state.zoom)
    pcall(frame.ClearAllPoints, frame)
    pcall(frame.SetPoint, frame, pin.point, state.viewport, pin.relativePoint,
      pin.x, pin.y)
  end
end

local function Apply()
  if not state.installed then return end
  ClampPan()
  local content = state.content
  pcall(content.SetScale, content, state.zoom)
  pcall(content.ClearAllPoints, content)
  pcall(content.SetPoint, content, "TOPLEFT", state.holder, "TOPLEFT",
    -state.panX, state.panY)
  -- The scaled canvas extends past the viewport, invisibly; keep its mouse
  -- hits to the visible part so the UI around a windowed map stays clickable.
  -- Insets are in the button's own (content) units. Addon pins that are mouse
  -- children of the button are not clipped by this.
  local button = state.button
  pcall(button.SetHitRectInsets, button, state.panX,
    state.width - state.panX - state.width / state.zoom, state.panY,
    state.height - state.panY - state.height / state.zoom)
  ApplyPins()
end

local function Reset()
  state.zoom = 1
  state.panX = 0
  state.panY = 0
  state.dragging = false
  state.justDragged = false
  Apply()
end

-- Keeps the map point under the cursor fixed while the zoom changes; with the
-- cursor outside the map it zooms about the centre.
local function ZoomTo(zoom)
  zoom = Clamp(zoom, MIN_ZOOM, MAX_ZOOM)
  if zoom == state.zoom then return end
  local cx, cy, inside = CursorInView()
  if not cx or not inside then
    cx, cy = state.width / 2, state.height / 2
  end
  local mapX = state.panX + cx / state.zoom
  local mapY = state.panY + cy / state.zoom
  state.zoom = zoom
  state.panX = mapX - cx / zoom
  state.panY = mapY - cy / zoom
  Apply()
end

-- ---------------------------------------------------------------------------
-- Windowed map
--
-- The client's minimize button (Turtle FrameXML WorldMapFrame_Minimize,
-- WORKING_SOURCE) reparents WorldMapFrame to UIParent, and maximize reparents
-- it back to nil; both rescale and re-anchor WorldMapDetailFrame and
-- WorldMapButton relative to their parent. While the viewport ScrollFrame was
-- a WorldMapFrame child the client crashed twice after those reparents
-- (ACCESS_VIOLATION at 0x00594B9E: a wheel turn on the windowed map, then
-- maximizing; knowledge.json / map.worldmap_zoom_windowed_wheel_client_crash).
-- The viewport is therefore a WorldFrame child, which is never reparented, and
-- follows the map by anchor, scale and show/hide only. Layout() matches it to
-- the current mode: the canvases stay at scale 1 on the content and the
-- viewport carries the map's effective scale times the windowed scale, so the
-- zoom maths keeps one unit system. A mode switch resets the zoom; wheel zoom
-- works in both modes once the viewport is off the reparented tree.
-- ---------------------------------------------------------------------------

local function Windowed()
  if U.G("WORLDMAP_WINDOWED") == 1 then return true end
  local map = U.G("WorldMapFrame")
  if not map or type(map.GetParent) ~= "function" then return false end
  local ok, parent = pcall(map.GetParent, map)
  return ok and parent ~= nil and parent == U.G("UIParent")
end

local function Layout()
  if not state.installed then return end
  local map, viewport = U.G("WorldMapFrame"), state.viewport
  local detail, button = state.detail, state.button
  local windowed = Windowed()
  state.windowed = windowed

  local scale = 1
  if windowed then
    scale = tonumber(U.G("WORLDMAP_WINDOWED_SCALE")) or 0.7
    if scale <= 0 then scale = 0.7 end
    state.zoom, state.panX, state.panY = 1, 0, 0
    state.dragging, state.justDragged = false, false
  end
  -- The viewport's scale relative to WorldMapFrame (the native arrow's scale).
  state.viewportScale = scale
  local mapScale = NumberMethod(map, "GetEffectiveScale") or 1
  local worldScale = NumberMethod(state.world, "GetEffectiveScale") or 1
  if worldScale <= 0 then worldScale = 1 end
  pcall(viewport.SetScale, viewport, mapScale * scale / worldScale)

  pcall(detail.SetScale, detail, 1)
  pcall(button.SetScale, button, 1)
  pcall(detail.ClearAllPoints, detail)
  pcall(detail.SetPoint, detail, "TOPLEFT", state.content, "TOPLEFT", 0, 0)
  pcall(viewport.ClearAllPoints, viewport)
  if windowed then
    -- The client's own windowed offset, in the canvas's scaled units.
    pcall(viewport.SetPoint, viewport, "TOPLEFT", map, "TOPLEFT", 15, -33)
  else
    pcall(viewport.SetPoint, viewport, "TOPLEFT", U.G("WorldMapPositioningGuide"),
      "TOP", NATIVE_ANCHOR_X, NATIVE_ANCHOR_Y)
  end
  Apply()
end

-- Fullscreen opens with native marker anchors still carrying their XML
-- defaults. Keep the zoomed canvas logically visible but transparent long
-- enough for the client's own OnUpdate to place every marker. Hiding it would
-- suppress those native visibility checks, so alpha is used instead.
local function BeginOpeningGate()
  state.openingFrames = nil
  pcall(state.viewport.SetAlpha, state.viewport, 1)
  if not state.windowed then
    state.openingFrames = 2
    pcall(state.viewport.SetAlpha, state.viewport, 0)
  end
end

local function OnMapShow()
  pcall(state.viewport.Show, state.viewport)
  Layout()
  Reset()
  BeginOpeningGate()
end

local function OnMapHide()
  state.dragging = false
  state.openingFrames = nil
  pcall(state.viewport.SetAlpha, state.viewport, 1)
  pcall(state.viewport.Hide, state.viewport)
end

-- Re-lays the map after the client's own minimize/maximize. Each wrapper
-- returns exactly what the original returns (nothing).
local function WrapWindowToggle(name)
  local original = U.G(name)
  if type(original) ~= "function" then return end
  setglobal(name, function(a1, a2, a3, a4)
    original(a1, a2, a3, a4)
    Layout()
    BeginOpeningGate()
  end)
end
local function OnWheel()
  local delta = tonumber(arg1)
  if not delta or delta == 0 then return end
  state.wheelCount = state.wheelCount + 1
  if delta > 0 then
    ZoomTo(state.zoom + ZOOM_STEP)
  else
    ZoomTo(state.zoom - ZOOM_STEP)
  end
end

-- Public: keep a WorldMapButton descendant at its own size and pinned to the
-- visible map while zoomed. Callable before the module is installed. Also
-- handed to pandaMap's zoom, which owns the zoom when pandaMap is loaded.
function U.WorldMapZoomPin(frame, point, relativePoint, x, y)
  if not frame or type(frame.SetScale) ~= "function" then return end
  local pandaMapZoom = U.G("PandaMapZoom")
  if type(pandaMapZoom) == "table" and type(pandaMapZoom.Pin) == "function" then
    pcall(pandaMapZoom.Pin, frame, point, relativePoint, x, y)
  end
  local i
  for i = 1, table.getn(state.pins) do
    if state.pins[i].frame == frame then return end
  end
  table.insert(state.pins, {
    frame = frame,
    point = point,
    relativePoint = relativePoint,
    x = x or 0,
    y = y or 0,
    scale = NumberMethod(frame, "GetScale") or 1,
  })
  if state.installed then ApplyPins() end
end

-- ---------------------------------------------------------------------------
-- Drag panning
--
-- The engine's own drag threshold separates a pan from a click. The stock
-- OnMouseUp (WorldMapButton_OnClick: zoom into a zone, or zoom out) still
-- runs on release, so it is skipped after a pan and for releases outside the
-- visible map, where the zoomed canvas extends but is not drawn.
-- ---------------------------------------------------------------------------

local function CursorRaw()
  local cursor = U.G("GetCursorPosition")
  if type(cursor) ~= "function" then return nil end
  local ok, x, y = pcall(cursor)
  if not ok or not tonumber(x) or not tonumber(y) then return nil end
  return x, y
end

local function OnMouseDown()
  state.justDragged = false
  state.downX, state.downY = CursorRaw()
  state.downPanX, state.downPanY = state.panX, state.panY
end

local function OnDragStart()
  if state.zoom <= MIN_ZOOM or not state.downX then return end
  state.dragging = true
  state.dragCount = state.dragCount + 1
end

local function OnDragStop()
  if state.dragging then state.justDragged = true end
  state.dragging = false
end

local function DriverOnUpdate()
  local map = U.G("WorldMapFrame")
  if state.openingFrames then
    if not map or not map:IsVisible() then
      state.openingFrames = nil
      pcall(state.viewport.SetAlpha, state.viewport, 1)
    else
      state.openingFrames = state.openingFrames - 1
      if state.openingFrames <= 0 then
        state.openingFrames = nil
        pcall(state.viewport.SetAlpha, state.viewport, 1)
      end
    end
  end
  if not state.dragging then return end
  if not map or not map:IsVisible() then
    state.dragging = false
    return
  end
  local x, y = CursorRaw()
  local scale = NumberMethod(state.viewport, "GetEffectiveScale")
  if not x or not scale or scale == 0 then return end
  local dx = (x - state.downX) / scale
  local dy = (y - state.downY) / scale
  state.panX = state.downPanX - dx / state.zoom
  state.panY = state.downPanY + dy / state.zoom
  Apply()
end

local function WrapMouseUp(button)
  local ok, previous = pcall(button.GetScript, button, "OnMouseUp")
  if not ok then return false end
  return pcall(button.SetScript, button, "OnMouseUp",
    function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
      local swallow = state.dragging or state.justDragged
      state.justDragged = false
      if not swallow and state.zoom > MIN_ZOOM then
        local cx, _, inside = CursorInView()
        if cx and not inside then swallow = true end
      end
      if swallow then
        state.swallowedClicks = state.swallowedClicks + 1
        return
      end
      if previous then previous(a1, a2, a3, a4, a5, a6, a7, a8, a9) end
    end) and true or false
end

-- The native player arrow is a WorldMapFrame Model placed with offsets in
-- WorldMapDetailFrame units, so its offsets are scaled with the map. When the
-- playerarrow module has parked it, its own WorldMapButton arrow is used and
-- these calls are passed through untouched.
local function WrapNativeArrow()
  local original = U.G("PositionWorldMapArrowFrame")
  if type(original) ~= "function" then return end
  local function Wrapped(a1, a2, a3, a4, a5, a6)
    local arrow = U.GetModule("playerarrow")
    local parked = arrow and arrow.state and arrow.state.originalWorldMapPosition
    -- The stock caller passes offsets for an arrow at WorldMapFrame scale; the
    -- viewport is viewportScale times that while windowed.
    local vs = state.viewportScale or 1
    if not parked and (state.zoom ~= 1 or vs ~= 1) and type(a4) == "number" and
       type(a5) == "number" then
      local mapX, mapY = a4, -a5
      if mapX < state.panX or mapY < state.panY or
         mapX > state.panX + state.width / state.zoom or
         mapY > state.panY + state.height / state.zoom then
        a4, a5 = -5000, -5000
      else
        a4 = (mapX - state.panX) * state.zoom * vs
        a5 = -(mapY - state.panY) * state.zoom * vs
        -- By name, as the stock caller passes "WorldMapDetailFrame".
        a2, a3 = "PandaUIWorldMapViewport", "TOPLEFT"
      end
      state.arrowScaled = state.arrowScaled + 1
    end
    return original(a1, a2, a3, a4, a5, a6)
  end
  PositionWorldMapArrowFrame = Wrapped
end

local function MapKey()
  local continent, zone
  local getContinent = U.G("GetCurrentMapContinent")
  local getZone = U.G("GetCurrentMapZone")
  if type(getContinent) == "function" then
    local ok, value = pcall(getContinent)
    if ok then continent = value end
  end
  if type(getZone) == "function" then
    local ok, value = pcall(getZone)
    if ok then zone = value end
  end
  return tostring(continent) .. ":" .. tostring(zone)
end

local function OnMapUpdate()
  local key = MapKey()
  if key ~= state.mapKey then
    state.mapKey = key
    if state.zoom ~= 1 then Reset() end
  end
end

-- ---------------------------------------------------------------------------
-- Install
--
-- Everything that can fail is created and checked before a native frame is
-- touched, so a failure leaves the stock map exactly as it was.
-- ---------------------------------------------------------------------------

local function Install()
  local map = U.G("WorldMapFrame")
  local guide = U.G("WorldMapPositioningGuide")
  local detail = U.G("WorldMapDetailFrame")
  local button = U.G("WorldMapButton")
  if not map or not guide or not detail or not button then
    return false, "native map frames missing"
  end

  local width = NumberMethod(detail, "GetWidth")
  local height = NumberMethod(detail, "GetHeight")
  if not width or not height or width <= 0 or height <= 0 then
    return false, "no WorldMapDetailFrame size"
  end
  state.width, state.height = width, height

  local detailLevel = NumberMethod(detail, "GetFrameLevel")
  local buttonLevel = NumberMethod(button, "GetFrameLevel")
  if not detailLevel or not buttonLevel then return false, "no frame levels" end
  state.levels.detailBefore = detailLevel
  state.levels.buttonBefore = buttonLevel

  -- A WorldFrame child: never reparented by the client (see Windowed map).
  local world = U.G("WorldFrame")
  if not world then return false, "no WorldFrame" end
  local ok, viewport = pcall(CreateFrame, "ScrollFrame", "PandaUIWorldMapViewport", world)
  if not ok or not viewport then return false, "no ScrollFrame" end
  pcall(viewport.SetFrameStrata, viewport, "FULLSCREEN")
  local holder = CreateFrame("Frame", "PandaUIWorldMapZoomHolder", viewport)
  local content = CreateFrame("Frame", "PandaUIWorldMapZoomContent", holder)
  if not holder or not content then return false, "no content frames" end

  local built = pcall(function()
    viewport:SetWidth(width)
    viewport:SetHeight(height)
    viewport:SetPoint("TOPLEFT", guide, "TOP", NATIVE_ANCHOR_X, NATIVE_ANCHOR_Y)
    viewport:SetFrameLevel(detailLevel)
    holder:SetWidth(width)
    holder:SetHeight(height)
    holder:SetFrameLevel(detailLevel)
    content:SetWidth(width)
    content:SetHeight(height)
    content:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    content:SetFrameLevel(detailLevel)
    viewport:SetScrollChild(holder)
  end)
  if not built then
    viewport:Hide()
    return false, "viewport setup failed"
  end

  state.viewport, state.holder, state.content = viewport, holder, content
  state.world = world
  state.detail, state.button = detail, button

  -- SetParent is not assumed to keep frame levels; both are restored to the
  -- measured values so pins built from WorldMapButton:GetFrameLevel() stay
  -- above the tiles.
  detail:SetParent(content)
  detail:ClearAllPoints()
  detail:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  button:SetParent(content)
  state.levels.detailAfterParent = NumberMethod(detail, "GetFrameLevel")
  state.levels.buttonAfterParent = NumberMethod(button, "GetFrameLevel")
  pcall(detail.SetFrameLevel, detail, detailLevel)
  pcall(button.SetFrameLevel, button, buttonLevel)

  pcall(viewport.EnableMouseWheel, viewport, true)
  pcall(viewport.SetScript, viewport, "OnMouseWheel", OnWheel)

  pcall(button.RegisterForDrag, button, "LeftButton")
  U.PostHookScript(button, "OnMouseDown", OnMouseDown)
  U.PostHookScript(button, "OnDragStart", OnDragStart)
  U.PostHookScript(button, "OnDragStop", OnDragStop)
  state.mouseUpWrapped = WrapMouseUp(button)

  if world then
    state.driver = CreateFrame("Frame", "PandaUIWorldMapZoomDriver", world)
    if state.driver then state.driver:SetScript("OnUpdate", DriverOnUpdate) end
  end

  WrapNativeArrow()
  WrapWindowToggle("WorldMapFrame_Minimize")
  WrapWindowToggle("WorldMapFrame_Maximize")
  U.PostHookScript(map, "OnShow", OnMapShow)
  U.PostHookScript(map, "OnHide", OnMapHide)
  if not (map.IsVisible and map:IsVisible()) then viewport:Hide() end
  U.RegisterEvent("WORLD_MAP_UPDATE", OnMapUpdate)

  state.installed = true
  return true
end

-- pandaMap's MapZoom.lua owns the zoom while it claims it, so two zooms never
-- stack; it calls OnEnable again when its own install fails.
local function PandaMapClaimsZoom()
  local pandaMapZoom = U.G("PandaMapZoom")
  if type(pandaMapZoom) ~= "table" or type(pandaMapZoom.ClaimsZoom) ~= "function" then
    return false
  end
  local ok, claims = pcall(pandaMapZoom.ClaimsZoom)
  return ok and claims and true or false
end

function ZOOM:OnEnable()
  if state.installed then return end
  if PandaMapClaimsZoom() then
    state.yielded = "pandaMap"
    U.Debug("world map zoom left to pandaMap")
    return
  end
  state.yielded = nil
  local ok, installed, failure = pcall(Install)
  if not ok then
    state.failure = tostring(installed)
  elseif not installed then
    state.failure = failure
  end
  if state.failure then
    U.Debug("world map zoom unavailable: " .. tostring(state.failure))
    return
  end

  local area = U.G("WorldMapFrameAreaFrame")
  if area then U.WorldMapZoomPin(area, "TOP", "TOP", 0, -10) end
  state.mapKey = MapKey()
  Layout()
  local map = U.G("WorldMapFrame")
  if map and map.IsVisible and map:IsVisible() then BeginOpeningGate() end
end
