-- pandaUI :: modules/playerarrow.lua

local U = PandaUI
local M = U.media
local ARROW = U.RegisterModule("playerarrow")

local state = {}
ARROW.state = state

local function NumberMethod(object, method)
  if not object or type(object[method]) ~= "function" then return nil end
  local ok, value = pcall(object[method], object)
  if ok then return tonumber(value) end
  return nil
end

local function MakeArrow(name, parent, size, texturePath)
  if not parent then return nil end
  local frame = CreateFrame("Frame", name, parent)
  if not frame then return nil end

  frame:Hide()
  frame:SetWidth(size)
  frame:SetHeight(size)
  frame:SetFrameLevel((NumberMethod(parent, "GetFrameLevel") or 0) + 8)
  if frame.EnableMouse then frame:EnableMouse(false) end

  local texture = frame:CreateTexture(nil, "OVERLAY")
  if not texture then
    frame:Hide()
    return nil
  end
  texture:SetTexture(texturePath or M.playerArrow.texture)
  texture:SetAllPoints(frame)
  frame.arrow = texture
  return frame
end

local function SetCell(texture, cell, layout)
  layout = layout or M.playerArrow
  local columns = layout.columns
  local row = math.floor(cell / columns)
  local column = cell - row * columns
  texture:SetTexCoord(column / columns, (column + 1) / columns,
    row / columns, (row + 1) / columns)
end

-- GetPlayerFacing is absent on OctoWoW (knowledge.json /
-- map.native_arrow_model_facing_per_map). Each map's native MinimapArrow
-- Model tracks the player instead, but only while its map is visible
-- (arrowdraw.v1): the Minimap one freezes while the World Map hides
-- UIParent, and the WorldMapFrame one reads 0 while the map is closed. The
-- Minimap one keeps updating after SetPlayerModel("") clears it
-- (arrowfacing.v1), so find it before that clear: GetModel no longer returns
-- its path afterwards.
local function FindFacingModel(parent)
  if not parent or type(parent.GetChildren) ~= "function" then return nil end
  local children = { parent:GetChildren() }
  local i
  for i = 1, table.getn(children) do
    local child = children[i]
    if type(child.GetFacing) == "function" and type(child.GetModel) == "function" then
      local ok, path = pcall(child.GetModel, child)
      if ok and type(path) == "string" then
        path = string.lower(path)
        if string.find(path, "minimaparrow", 1, true) and
           not string.find(path, "rotating", 1, true) then
          return child
        end
      end
    end
  end
  return nil
end

local function ReadFacing(model)
  local getFacing = U.G("GetPlayerFacing")
  if type(getFacing) == "function" then
    local ok, facing = pcall(getFacing)
    if ok and type(facing) == "number" then return facing end
  end
  if model then
    local ok, facing = pcall(model.GetFacing, model)
    if ok and type(facing) == "number" then return facing end
  end
  return nil
end

local function FacingCell(model)
  local facing = ReadFacing(model or state.facingModel)
  if not facing then return nil end

  local turn = math.pi * 2
  facing = facing - math.floor(facing / turn) * turn
  local cell = math.floor(facing / turn * M.playerArrow.frames + 0.5)
  if cell >= M.playerArrow.frames then cell = 0 end
  return cell
end

local function Atan2(y, x)
  if x > 0 then return math.atan(y / x) end
  if x < 0 then
    if y >= 0 then return math.atan(y / x) + math.pi end
    return math.atan(y / x) - math.pi
  end
  if y > 0 then return math.pi / 2 end
  if y < 0 then return -math.pi / 2 end
  return 0
end

-- GetPlayerMapPosition is the only position source: it projects onto the
-- viewed map and returns 0, 0 on any map the player is not on. The stock
-- PositionWorldMapArrowFrame calls are not: the client stops making them off
-- the player's map, and the few made while the view changes still carry the
-- previous view's coordinates (maparrowzone.v1, 2026-10-04). Placement uses
-- the stock arrow's own reference, CENTER on WorldMapDetailFrame's TOPLEFT
-- scaled by its size, as those calls showed.
local function UpdateWorldMapPosition()
  local frame = state.worldMap
  local canvas = U.G("WorldMapDetailFrame") or U.G("WorldMapButton")
  local getPosition = U.G("GetPlayerMapPosition")
  if not frame or not canvas or type(getPosition) ~= "function" then return end

  local ok, x, y = pcall(getPosition, "player")
  local width = NumberMethod(canvas, "GetWidth")
  local height = NumberMethod(canvas, "GetHeight")
  if not ok or type(x) ~= "number" or type(y) ~= "number" or
     not width or not height or width <= 0 or height <= 0 or
     (x <= 0 and y <= 0) then
    frame:Hide()
    return
  end

  if not state.worldMapFacingModel then
    state.worldMapFacingModel = FindFacingModel(U.G("WorldMapFrame"))
  end
  local cell = FacingCell(state.worldMapFacingModel)
  if cell ~= nil and cell ~= state.worldMapCell then
    state.worldMapCell = cell
    SetCell(frame.arrow, cell)
  end
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", canvas, "TOPLEFT", x * width, -y * height)
  frame:Show()
end

-- UIParent is hidden while the fullscreen world map is open, so the shared
-- updater (a UIParent child) gets no OnUpdate then (knowledge.json /
-- map.worldmap_open_workers_require_worldframe_parent). The world-map arrow
-- gets its own WorldFrame driver, run every frame while the map is visible so
-- a view change never shows the previous view's position.
local function WorldMapDriverOnUpdate()
  local map = U.G("WorldMapFrame")
  if not map or not map:IsVisible() then
    -- Hidden while closed, so reopening never draws the last position first.
    if state.worldMap and state.worldMap:IsShown() then state.worldMap:Hide() end
    return
  end
  UpdateWorldMapPosition()
end

local function BuildWorldMapDriver()
  local world = U.G("WorldFrame")
  if not world then return nil end
  local driver = CreateFrame("Frame", "PandaUIPlayerArrowWorldMapDriver", world)
  if not driver then return nil end
  driver:SetScript("OnUpdate", WorldMapDriverOnUpdate)
  return driver
end

-- The native corpse pointer cannot be removed on this client: SetArrowModel,
-- SetIconTexture and SetBlipTexture leave it unchanged and no other Minimap
-- method or widget reaches it (knowledge.json /
-- minimap.corpse_pointer_not_removable). The gold arrow is drawn beside it.
local function HideCorpseArrow()
  if state.corpse then state.corpse:Hide() end
end

local function UpdateCorpseArrow()
  local frame = state.corpse
  local minimap = U.G("Minimap")
  local layout = M.corpseArrow
  local isDead = U.G("UnitIsDeadOrGhost")
  local getPlayer = U.G("GetPlayerMapPosition")
  local getCorpse = U.G("GetCorpseMapPosition")
  if not frame or not minimap or not layout or type(isDead) ~= "function" or
     type(getPlayer) ~= "function" or type(getCorpse) ~= "function" then
    HideCorpseArrow()
    return
  end

  local deadOK, dead = pcall(isDead, "player")
  local playerOK, playerX, playerY = pcall(getPlayer, "player")
  local corpseOK, corpseX, corpseY = pcall(getCorpse)
  local width = NumberMethod(minimap, "GetWidth")
  local height = NumberMethod(minimap, "GetHeight")
  if not deadOK or not dead or not playerOK or not corpseOK or
     type(playerX) ~= "number" or type(playerY) ~= "number" or
     type(corpseX) ~= "number" or type(corpseY) ~= "number" or
     not width or not height or width <= 0 or height <= 0 or
     (playerX <= 0 and playerY <= 0) or
     (corpseX <= 0 and corpseY <= 0) then
    HideCorpseArrow()
    return
  end

  -- Map UVs are not square: a zone map spans about 1.5 times as many yards
  -- across as down, so scale each axis by the map canvas before the bearing.
  local canvas = U.G("WorldMapButton")
  local mapWidth = NumberMethod(canvas, "GetWidth")
  local mapHeight = NumberMethod(canvas, "GetHeight")
  if not mapWidth or not mapHeight or mapWidth <= 0 or mapHeight <= 0 then
    mapWidth, mapHeight = layout.mapAspect, 1
  end
  local dx = (corpseX - playerX) * mapWidth
  local dy = (corpseY - playerY) * mapHeight
  if dx == 0 and dy == 0 then
    HideCorpseArrow()
    return
  end
  local turn = math.pi * 2
  local angle = Atan2(-dx, -dy)
  if angle < 0 then angle = angle + turn end
  local cell = math.floor(angle / turn * layout.frames + 0.5)
  if cell >= layout.frames then cell = 0 end
  if cell ~= state.corpseCell then
    state.corpseCell = cell
    SetCell(frame.arrow, cell, layout)
  end

  local inset = layout.visibleSize / 2
  local directionX = -math.sin(angle)
  local directionY = math.cos(angle)
  local offsetX, offsetY
  if state.squareMinimap then
    local xLimit = width / 2 - inset
    local yLimit = height / 2 - inset
    local distance
    local absX = math.abs(directionX)
    local absY = math.abs(directionY)
    if absX > 0 then distance = xLimit / absX end
    if absY > 0 then
      local yDistance = yLimit / absY
      if not distance or yDistance < distance then distance = yDistance end
    end
    distance = distance or 0
    offsetX, offsetY = directionX * distance, directionY * distance
  else
    offsetX = directionX * (width / 2 - inset)
    offsetY = directionY * (height / 2 - inset)
  end
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", minimap, "CENTER", offsetX, offsetY)
  frame:Show()
end

function U.ApplyMinimapArrowShape()
  state.squareMinimap = type(U.MinimapIsSquare) == "function" and
                        U.MinimapIsSquare() and true or false
  UpdateCorpseArrow()
end

local function Refresh()
  local cell = FacingCell()
  if cell ~= nil and cell ~= state.cell then
    state.cell = cell
    if state.minimap then SetCell(state.minimap.arrow, cell) end
  end
  UpdateCorpseArrow()
end

local function InstallWorldMapPark()
  local original = U.G("PositionWorldMapArrowFrame")
  if type(original) ~= "function" then return false end

  local park = M.playerArrow.parkOffset
  local function Wrapped(a1, a2, a3, a4, a5, a6)
    if type(a2) == "number" then a2 = park end
    if type(a3) == "number" then a3 = park end
    if type(a4) == "number" then a4 = park end
    if type(a5) == "number" then a5 = park end
    return original(a1, a2, a3, a4, a5, a6)
  end

  PositionWorldMapArrowFrame = Wrapped
  if U.G("PositionWorldMapArrowFrame") ~= Wrapped then return false end
  state.originalWorldMapPosition = original
  pcall(original, "CENTER", park, park)
  return true
end

local function BuildMinimapArrow()
  local minimap = U.G("Minimap")
  if not minimap or type(minimap.SetPlayerModel) ~= "function" then return nil end
  local frame = MakeArrow("PandaUIPlayerArrowMinimap", minimap,
    M.playerArrow.minimapTextureSize)
  if not frame then return nil end
  frame:SetPoint("CENTER", minimap, "CENTER", 0, 0)
  -- SetPlayerModel("") raises "Couldn't load the file" on OctoWoW yet still
  -- clears the native arrow (knowledge.json /
  -- minimap.setplayermodel_empty_errors_but_clears). Judge it by the native
  -- model afterwards:
  -- keep the replacement whenever that model no longer holds its arrow path.
  local called = pcall(minimap.SetPlayerModel, minimap, "")
  local model = state.facingModel
  local cleared = called
  if model and type(model.GetModel) == "function" then
    local ok, path = pcall(model.GetModel, model)
    cleared = not ok or type(path) ~= "string" or
      not string.find(string.lower(path), "minimaparrow", 1, true)
  end
  if not cleared then
    frame:Hide()
    return nil
  end
  return frame
end

local function BuildMinimapCorpseArrow()
  local minimap = U.G("Minimap")
  local layout = M.corpseArrow
  if not minimap or not layout then return nil end
  return MakeArrow("PandaUIPlayerCorpseArrowMinimap", minimap,
    layout.textureSize, layout.texture)
end

local function BuildWorldMapArrow()
  local canvas = U.G("WorldMapButton")
  if not canvas then return nil end
  local frame = MakeArrow("PandaUIPlayerArrowWorldMap", canvas,
    M.playerArrow.worldMapTextureSize)
  if frame then frame:Hide() end
  return frame
end

function ARROW:OnEnable()
  if state.enabled then return end
  if not M.playerArrow then
    U.Debug("player arrow: media unavailable; native arrows retained")
    return
  end

  state.facingModel = FindFacingModel(U.G("Minimap"))
  state.squareMinimap = type(U.MinimapIsSquare) == "function" and
                        U.MinimapIsSquare() and true or false
  state.worldMapFacingModel = FindFacingModel(U.G("WorldMapFrame"))
  local initialCell = FacingCell()
  if initialCell == nil then
    U.Debug("player arrow: facing unreadable; native arrows retained")
    return
  end

  state.minimap = BuildMinimapArrow()
  state.corpse = BuildMinimapCorpseArrow()
  state.worldMap = BuildWorldMapArrow()
  if state.worldMap then
    state.worldMapDriver = BuildWorldMapDriver()
    if not state.worldMapDriver or not InstallWorldMapPark() then
      if state.worldMapDriver then state.worldMapDriver:SetScript("OnUpdate", nil) end
      state.worldMapDriver = nil
      state.worldMap:Hide()
      state.worldMap = nil
    end
  end

  if not state.minimap and not state.worldMap and not state.corpse then
    U.Debug("player arrow: replacement unavailable; native arrows retained")
    return
  end

  state.cell = initialCell
  if state.minimap then
    SetCell(state.minimap.arrow, initialCell)
    state.minimap:Show()
  end
  if state.worldMap then
    state.worldMapCell = initialCell
    SetCell(state.worldMap.arrow, initialCell)
  end
  state.enabled = true
  Refresh()
  U.RegisterUpdate("playerarrow.refresh", M.playerArrow.updateInterval, Refresh)
end
