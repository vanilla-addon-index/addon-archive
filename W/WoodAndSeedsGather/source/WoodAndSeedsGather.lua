-- Wood and Seeds Gather: shows Survival woodcutting trees and the places to get farming seeds
-- on the world map and minimap. Made by stealthzi.
-- Lua 5.0 / client 1.12: no '#', no '%', no string methods with ':'.

-- Type numbers match tools/build_data.py: 1-6 trees, 7-12 seed plants, 13-14 seed vendors.
-- Tree pins use the game's log icons with the black backdrop cut away (tools/make_icons.py).
local ICONS = "Interface\\AddOns\\WoodAndSeedsGather\\icons\\"
local TYPES = {
  { key = "simple",   name = "Simple Wood Tree",   skill = 5,   icon = ICONS .. "simple",   r = 0.92, g = 0.84, b = 0.66, drops = "Simple Wood, Simple Leaves" },
  { key = "bright",   name = "Bright Wood Tree",   skill = 125, icon = ICONS .. "bright",   r = 1.00, g = 0.86, b = 0.30, drops = "Bright Wood, Bright Leaves" },
  { key = "shade",    name = "Shade Wood Tree",    skill = 175, icon = ICONS .. "shade",    r = 0.70, g = 0.55, b = 1.00, drops = "Shade Wood, Shade Leaves" },
  { key = "tropical", name = "Tropical Wood Tree", skill = 225, icon = ICONS .. "tropical", r = 0.35, g = 1.00, b = 0.45, drops = "Tropical Wood, Tropical Leaves" },
  { key = "dead",     name = "Dead Wood Tree",     skill = 250, icon = ICONS .. "star",     r = 0.65, g = 0.65, b = 0.65, drops = "Dead Leaves, sometimes Star Wood", tint = 0.5 },
  { key = "star",     name = "Star Wood Tree",     skill = 270, icon = ICONS .. "star",     r = 0.45, g = 0.80, b = 1.00, drops = "Star Wood, Star Leaves" },
  -- seed plants: name is the plant you click, seed is what it gives
  { key = "pumpkin",  name = "Ripe Garden Pumpkin",    seed = "Country Pumpkin Seeds",     icon = "Interface\\Icons\\inv_misc_food_113",   r = 1.00, g = 0.55, b = 0.15 },
  { key = "berry",    name = "Mountain Berry Bush",    seed = "Mountain Berry Bush Seeds", icon = "Interface\\Icons\\INV_Misc_Food_74",    r = 0.95, g = 0.40, b = 0.55 },
  { key = "melon",    name = "Ripe Garden Watermelon", seed = "Striped Melon Seeds",       icon = "Interface\\Icons\\inv_misc_food_112",   r = 0.55, g = 0.95, b = 0.35 },
  { key = "grape",    name = "Northwind Wild Grapes",  seed = "Wild Grape Seeds",          icon = "Interface\\Icons\\INV_Misc_Food_57",    r = 0.75, g = 0.50, b = 1.00 },
  { key = "yam",      name = "Wildhammer Yams",        seed = "Wildhammer Yam Roots",      icon = "Interface\\Icons\\wildhammer_yams_1",   r = 0.90, g = 0.65, b = 0.40 },
  { key = "carrot",   name = "Sandswept Carrots",      seed = "Sandswept Carrot Seeds",    icon = "Interface\\Icons\\sandswept_carrots_2", r = 1.00, g = 0.75, b = 0.30 },
  -- seed vendors: each pin also carries the vendor's name, title, side and price
  { key = "cabbage",  name = "Cabbage seed vendor",    seed = "Ordinary Cabbage Seeds",    icon = "Interface\\Icons\\INV_Misc_Flower_03",  r = 0.60, g = 0.95, b = 0.60, vendor = true },
  { key = "mushroom", name = "Mushroom spore vendor",  seed = "Magic Mushroom Spores",     icon = "Interface\\Icons\\inv_mushroom_15",     r = 0.90, g = 0.80, b = 0.65, vendor = true },
}
local NUM_TREES = 6
local PLANTER_SKILL = 75 -- Survival needed to use a Simple Wooden Planter

local DEFAULTS = {
  trees = true, seeds = true, worldmap = true, minimap = true, onlyUsable = false,
  size = 12, minisize = 10,
  types = {}, -- filled with true for every type
}

-- minimap diameter in yards for each zoom level (indoor / outdoor), same values pfQuest uses
local MINIMAP_YARDS = {
  [0] = { 300, 240, 180, 120, 80, 50 },
  [1] = { 466.667, 400, 333.333, 266.667, 200, 133.333 },
}

local SIDE_COLORS = { Alliance = { 0.35, 0.6, 1 }, Horde = { 1, 0.35, 0.3 } }

local CELL = 200          -- grid cell size in yards for the minimap lookup
local DB                  -- saved settings
local zones = {}          -- mapFile -> list of nodes
local grid = { [0] = {}, [1] = {} } -- continent -> cell key -> list of nodes
local survival            -- the player's Survival skill, nil if unknown
local worldPins, miniPins, contPins = {}, {}, {}
local player = { cont = nil, e = 0, s = 0 }
local indoor, indoorCheck = false, 0
local nextZoneFix = 0

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff88cc44Wood and Seeds Gather|r: " .. msg)
end

local function CellKey(e, s)
  return math.floor(e / CELL) * 4096 + math.floor(s / CELL)
end

-- map coordinates (0-1 on a zone's map) to yards east/south on that continent
local function ToWorld(m, x, y)
  return x * (m[2] - m[3]) - m[2], y * (m[4] - m[5]) - m[4]
end

-- copy = a second pin for a vendor on a city map: drawn on that map only, not on the
-- minimap or continent (the vendor's zone pin already covers those)
local function AddNode(mapFile, x, y, t, copy)
  local m = WoodAndSeedsGather_Maps[mapFile]
  if not m or not TYPES[t] then return nil end
  local e, s = ToWorld(m, x, y)
  local node = { x = x, y = y, t = t, e = e, s = s, zone = mapFile, copy = copy }
  if not zones[mapFile] then zones[mapFile] = {} end
  table.insert(zones[mapFile], node)
  if not copy then
    local cells = grid[m[1]]
    local key = CellKey(e, s)
    if not cells[key] then cells[key] = {} end
    table.insert(cells[key], node)
  end
  return node
end

local function SetVendor(node, v)
  node.npc, node.title, node.side, node.price, node.note = v[5], v[6], v[7], v[8], v[9]
end

local function BuildNodes()
  local trees, seeds = 0, 0
  for mapFile, byType in pairs(WoodAndSeedsGather_Nodes) do
    for t, str in pairs(byType) do
      for xs, ys in string.gfind(str, "(%d+),(%d+)") do
        if AddNode(mapFile, tonumber(xs) / 1000, tonumber(ys) / 1000, t) then
          if TYPES[t].seed then seeds = seeds + 1 else trees = trees + 1 end
        end
      end
    end
  end
  for _, v in ipairs(WoodAndSeedsGather_Vendors) do
    local node = AddNode(v[1], v[2] / 1000, v[3] / 1000, v[4])
    if node then
      seeds = seeds + 1
      SetVendor(node, v)
      if v[10] then
        local copy = AddNode(v[10], v[11] / 1000, v[12] / 1000, v[4], true)
        if copy then SetVendor(copy, v) end
      end
    end
  end
  return trees, seeds
end

local function ReadSkill()
  survival = nil
  local header
  for i = 1, GetNumSkillLines() do
    local name, isHeader, _, rank = GetSkillLineInfo(i)
    if isHeader then
      header = name
    elseif name == "Survival" and (header == "Secondary Skills" or not survival) then
      survival = rank
    end
  end
end

local function Shown(node)
  local t = TYPES[node.t]
  if not DB.types[node.t] then return false end
  if t.seed then return DB.seeds end
  if not DB.trees then return false end
  if DB.onlyUsable and survival and survival < t.skill then return false end
  return true
end

-- tooltip ------------------------------------------------------------------

-- "label 125" in green or red against the player's Survival skill
local function AddSkillLine(tip, label, need)
  local text = label .. need
  if survival then
    text = text .. "  (you have " .. survival .. ")"
    if survival >= need then
      tip:AddLine(text, 0.25, 1, 0.25)
    else
      tip:AddLine(text, 1, 0.3, 0.3)
    end
  else
    tip:AddLine(text, 1, 0.82, 0)
  end
end

-- count is set for the continent markers (one per zone and type)
local function NodeTooltip(tip, node, yards, count)
  local t = TYPES[node.t]
  local m = WoodAndSeedsGather_Maps[node.zone]
  if node.npc then
    tip:AddLine(node.npc, t.r, t.g, t.b)
    if node.title ~= "" then tip:AddLine("<" .. node.title .. ">", 0.85, 0.85, 0.85) end
    tip:AddLine("Sells " .. t.seed .. ", " .. node.price .. " each", 1, 0.82, 0)
    local c = SIDE_COLORS[node.side] or { 0.85, 0.85, 0.85 }
    tip:AddLine(node.side, c[1], c[2], c[3])
  elseif t.seed then
    tip:AddLine(t.name, t.r, t.g, t.b)
    if t.vendor then
      tip:AddLine("Sells " .. t.seed, 1, 0.82, 0)
    else
      tip:AddLine("Gives " .. t.seed, 1, 0.82, 0)
    end
  else
    tip:AddLine(t.name, t.r, t.g, t.b)
    AddSkillLine(tip, "Requires Survival ", t.skill)
  end
  if m then
    local where = m[6]
    if m[7] ~= "" then where = where .. ", level " .. m[7] end
    if count then
      local one, many = " tree in ", " trees in "
      if t.vendor then
        one, many = " vendor in ", " vendors in "
      elseif t.seed then
        one, many = " plant in ", " plants in "
      end
      if count == 1 then where = count .. one .. where else where = count .. many .. where end
    end
    tip:AddLine(where, 0.85, 0.85, 0.85)
  end
  if t.seed then
    AddSkillLine(tip, "Simple Wooden Planter needs Survival ", PLANTER_SKILL)
    if node.note and node.note ~= "" then
      for line in string.gfind(node.note, "[^;]+") do
        tip:AddLine(line, 0.6, 0.6, 0.6)
      end
    end
  else
    tip:AddLine("Drops: " .. t.drops, 0.6, 0.6, 0.6)
  end
  if yards then
    tip:AddLine(string.format("About %d yards away", yards), 0.6, 0.6, 0.6)
  end
  if count then
    tip:AddLine("Click to open this zone's map", 0.5, 0.8, 1)
  end
  tip:Show()
end

local CONTINENT_NAMES = { [0] = "Eastern Kingdoms", [1] = "Kalimdor" }

-- open a zone's map from the continent view (matches the zone by its English name)
local function OpenZoneMap(zoneFile)
  local m = WoodAndSeedsGather_Maps[zoneFile]
  if not m then return end
  local ci = 2
  if m[1] == 1 then ci = 1 end
  local conts = { GetMapContinents() }
  for i = 1, table.getn(conts) do
    if conts[i] == CONTINENT_NAMES[m[1]] then ci = i end
  end
  local names = { GetMapZones(ci) }
  for i = 1, table.getn(names) do
    if names[i] == m[6] then
      SetMapZoom(ci, i)
      return
    end
  end
end

local function PinOnEnter()
  local node = this.node
  if not node then return end
  if this.isMini then
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    local de, ds = node.e - player.e, node.s - player.s
    NodeTooltip(GameTooltip, node, math.floor(math.sqrt(de * de + ds * ds) + 0.5))
  else
    local tip = WorldMapTooltip or GameTooltip
    tip:SetOwner(this, "ANCHOR_RIGHT")
    if this.isSummary then
      NodeTooltip(tip, node, nil, this.found)
    else
      NodeTooltip(tip, node)
    end
  end
end

local function PinOnLeave()
  if WorldMapTooltip then WorldMapTooltip:Hide() end
  GameTooltip:Hide()
end

local function PinOnClick()
  if this.isMini then return end
  if arg1 == "RightButton" then
    -- keep right-click on the world map working (zoom out) when it lands on a pin
    if WorldMapZoomOutButton_OnClick then WorldMapZoomOutButton_OnClick() end
  elseif this.isSummary and this.node then
    OpenZoneMap(this.node.zone)
  end
end

local function CreatePin(parent, isMini, isSummary)
  local f = CreateFrame("Button", nil, parent)
  f:EnableMouse(true)
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f.isMini = isMini
  if isSummary then
    f.isSummary = true
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOP", f, "BOTTOM", 0, -1)
    fs:SetTextColor(1, 1, 1)
    f.count = fs
  end
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
  bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
  f.bg = bg
  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(f)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.icon = icon
  f:SetScript("OnEnter", PinOnEnter)
  f:SetScript("OnLeave", PinOnLeave)
  f:SetScript("OnClick", PinOnClick)
  return f
end

-- pin backing: half-see-through black behind the cut-out tree icons, green for seed plants, gold for vendors
local function SetPinNode(pin, node, size)
  local t = TYPES[node.t]
  pin.node = node
  pin:SetWidth(size)
  pin:SetHeight(size)
  pin.icon:SetTexture(t.icon)
  if t.tint then
    pin.icon:SetVertexColor(t.tint, t.tint, t.tint)
  else
    pin.icon:SetVertexColor(1, 1, 1)
  end
  local kind = "tree"
  if t.vendor then kind = "vendor" elseif t.seed then kind = "seed" end
  if pin.kind ~= kind then
    pin.kind = kind
    if kind == "vendor" then
      pin.bg:SetTexture(1, 0.82, 0, 0.95)
      pin.bg:Show()
    elseif kind == "seed" then
      pin.bg:SetTexture(0.2, 0.6, 0.15, 0.95)
      pin.bg:Show()
    else
      pin.bg:SetTexture(0, 0, 0, 0.5)
      pin.bg:Show()
    end
  end
end

-- world map ----------------------------------------------------------------

local function HideWorldPins(from)
  for i = from, table.getn(worldPins) do
    worldPins[i]:Hide()
  end
end

local function HideContPins(from)
  for i = from, table.getn(contPins) do
    contPins[i]:Hide()
  end
end

-- continent view: one marker per zone and type, at the middle of that zone's spots
local function UpdateContinent(m)
  local w, h = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
  local level = WorldMapButton:GetFrameLevel() + 3
  local size = DB.size + 2
  local n = 0
  for zoneFile, list in pairs(zones) do
    local zm = WoodAndSeedsGather_Maps[zoneFile]
    if zm and zm[1] == m[1] then
      local count, sumE, sumS, k = {}, 0, 0, 0
      for _, node in ipairs(list) do
        if not node.copy and Shown(node) then
          count[node.t] = (count[node.t] or 0) + 1
          sumE = sumE + node.e
          sumS = sumS + node.s
          k = k + 1
        end
      end
      if k > 0 then
        local x = (sumE / k + m[2]) / (m[2] - m[3])
        local y = (sumS / k + m[4]) / (m[4] - m[5])
        local types = {}
        for t = 1, table.getn(TYPES) do
          if count[t] then table.insert(types, t) end
        end
        local nt = table.getn(types)
        for i = 1, nt do
          local t = types[i]
          n = n + 1
          local pin = contPins[n]
          if not pin then
            pin = CreatePin(WorldMapButton, false, true)
            contPins[n] = pin
          end
          local nd = pin.summaryNode or {}
          pin.summaryNode = nd
          nd.t, nd.zone = t, zoneFile
          SetPinNode(pin, nd, size)
          pin.found = count[t]
          pin.count:SetText(count[t])
          pin:SetFrameLevel(level)
          pin:ClearAllPoints()
          pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", x * w + (i - (nt + 1) / 2) * (size + 4), -y * h)
          pin:Show()
        end
      end
    end
  end
  HideContPins(n + 1)
end

local function UpdateWorldMap()
  if not ((DB.trees or DB.seeds) and DB.worldmap) or not WorldMapFrame:IsVisible() then
    HideWorldPins(1)
    HideContPins(1)
    return
  end
  local mapFile = GetMapInfo()
  local m = mapFile and WoodAndSeedsGather_Maps[mapFile]
  if m and (mapFile == "Kalimdor" or mapFile == "Azeroth") then
    HideWorldPins(1)
    UpdateContinent(m)
    return
  end
  HideContPins(1)
  local list = mapFile and zones[mapFile]
  if not list then
    HideWorldPins(1)
    return
  end
  local w, h = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
  local level = WorldMapButton:GetFrameLevel() + 3
  local n = 0
  for _, node in ipairs(list) do
    if Shown(node) then
      n = n + 1
      local pin = worldPins[n]
      if not pin then
        pin = CreatePin(WorldMapButton, false)
        worldPins[n] = pin
      end
      SetPinNode(pin, node, DB.size)
      pin:SetFrameLevel(level)
      pin:ClearAllPoints()
      pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", node.x * w, -node.y * h)
      pin:Show()
    end
  end
  HideWorldPins(n + 1)
end

-- minimap ------------------------------------------------------------------

local function HideMiniPins(from)
  for i = from, table.getn(miniPins) do
    miniPins[i]:Hide()
  end
end

local function IsIndoors()
  local zoom = Minimap:GetZoom()
  local inside, outside = GetCVar("minimapInsideZoom"), GetCVar("minimapZoom")
  if inside ~= outside then
    return tonumber(inside) == zoom
  end
  -- both settings match: nudge the zoom and see which setting follows it
  local step = 1
  if zoom >= 3 then step = -1 end
  Minimap:SetZoom(zoom + step)
  local result = tonumber(GetCVar("minimapInsideZoom")) == zoom + step
  Minimap:SetZoom(zoom)
  return result
end

local function IsSquareMinimap()
  if ShaguTweaks_config and ShaguTweaks_config["MiniMap Square"] == 1 then return true end
  if pfUI and pfUI.minimap then return true end
  return false
end

-- where the player is, in yards on their continent; nil when not on a known map
local function ReadPlayer()
  local mapFile = GetMapInfo()
  local m = mapFile and WoodAndSeedsGather_Maps[mapFile]
  if not m then return false end
  local px, py = GetPlayerMapPosition("player")
  if px == 0 and py == 0 then return false end
  player.cont = m[1]
  player.e, player.s = ToWorld(m, px, py)
  return true
end

local function UpdateMinimap()
  if not ((DB.trees or DB.seeds) and DB.minimap) then
    HideMiniPins(1)
    return
  end
  local ok = ReadPlayer()
  if not ok then
    if WorldMapFrame:IsVisible() then return end -- map shows another zone: keep the pins as they are
    if GetTime() > nextZoneFix then
      nextZoneFix = GetTime() + 2
      SetMapToCurrentZone()
      ok = ReadPlayer()
    end
    if not ok then
      HideMiniPins(1)
      return
    end
  end

  if GetTime() > indoorCheck then
    indoor = IsIndoors()
    indoorCheck = GetTime() + 2
  end

  local yards = MINIMAP_YARDS[indoor and 0 or 1][Minimap:GetZoom() + 1] or 466.667
  local width = Minimap:GetWidth()
  local scale = width / yards
  local half = DB.minisize / 2
  local limit = width / 2 - half
  local square = IsSquareMinimap()
  local cells = grid[player.cont]
  local range = yards / 2 + CELL
  local cx0, cx1 = math.floor((player.e - range) / CELL), math.floor((player.e + range) / CELL)
  local cy0, cy1 = math.floor((player.s - range) / CELL), math.floor((player.s + range) / CELL)
  local level = Minimap:GetFrameLevel() + 5
  local n = 0

  for cx = cx0, cx1 do
    for cy = cy0, cy1 do
      local list = cells and cells[cx * 4096 + cy]
      if list then
        for _, node in ipairs(list) do
          if Shown(node) then
            local dx = (node.e - player.e) * scale
            local dy = (node.s - player.s) * scale
            local inside
            if square then
              inside = math.abs(dx) < limit and math.abs(dy) < limit
            else
              inside = dx * dx + dy * dy < limit * limit
            end
            if inside then
              n = n + 1
              local pin = miniPins[n]
              if not pin then
                pin = CreatePin(Minimap, true)
                miniPins[n] = pin
              end
              SetPinNode(pin, node, DB.minisize)
              pin:SetFrameLevel(level)
              pin:ClearAllPoints()
              pin:SetPoint("CENTER", Minimap, "CENTER", dx, -dy)
              pin:Show()
            end
          end
        end
      end
    end
  end
  HideMiniPins(n + 1)
end

local function RefreshAll()
  UpdateWorldMap()
  UpdateMinimap()
end

-- world map boxes and menus ---------------------------------------------------

local treeToggle, seedToggle, treeMenu, seedMenu

local function SyncToggle()
  if treeToggle then treeToggle:SetChecked(DB.trees and 1 or nil) end
  if seedToggle then seedToggle:SetChecked(DB.seeds and 1 or nil) end
end

local function AddMenuToggle(text, get, set)
  local item = {}
  item.text = text
  item.checked = get() and 1 or nil
  item.keepShownOnClick = 1
  item.func = function() set(not get()); RefreshAll() end
  UIDropDownMenu_AddButton(item)
end

local function AddMapToggles()
  AddMenuToggle("Show on world map", function() return DB.worldmap end, function(v) DB.worldmap = v end)
  AddMenuToggle("Show on minimap", function() return DB.minimap end, function(v) DB.minimap = v end)
end

local function AddTypeToggles(from, to)
  for i = from, to do
    local t, index = TYPES[i], i
    local color = string.format("|cff%02x%02x%02x", t.r * 255, t.g * 255, t.b * 255)
    local label
    if t.skill then
      label = color .. t.name .. "|r  (" .. t.skill .. ")"
    elseif t.vendor then
      label = color .. t.seed .. "|r  (vendor)"
    else
      label = color .. t.seed .. "|r"
    end
    AddMenuToggle(label, function() return DB.types[index] end, function(v) DB.types[index] = v end)
  end
end

local function TreeMenuInit()
  UIDropDownMenu_AddButton({ text = "Trees", isTitle = 1 })
  AddMapToggles()
  AddMenuToggle("Only trees I can chop", function() return DB.onlyUsable end, function(v) DB.onlyUsable = v end)
  AddTypeToggles(1, NUM_TREES)
end

local function SeedMenuInit()
  UIDropDownMenu_AddButton({ text = "Seeds", isTitle = 1 })
  AddMapToggles()
  AddTypeToggles(NUM_TREES + 1, table.getn(TYPES))
end

-- how many tree (seeds = false) or seed (seeds = true) spots the open map has
local function CountOnMap(seeds)
  local mapFile = GetMapInfo()
  local list = mapFile and zones[mapFile]
  if not list then return nil end
  local n = 0
  for _, node in ipairs(list) do
    if (TYPES[node.t].seed and true or false) == seeds then n = n + 1 end
  end
  return n
end

local function MakeToggle(name, label, x, what, menu, isSeeds)
  local b = CreateFrame("CheckButton", name, WorldMapButton, "UICheckButtonTemplate")
  b:SetWidth(24)
  b:SetHeight(24)
  -- bottom-right: Octo's map puts zone info and cursor coordinates in the bottom-left
  b:SetPoint("BOTTOMRIGHT", WorldMapButton, "BOTTOMRIGHT", x, 4)
  b:SetFrameLevel(WorldMapButton:GetFrameLevel() + 6)
  getglobal(name .. "Text"):SetText(label)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function()
    if arg1 == "RightButton" then
      SyncToggle()
      ToggleDropDownMenu(1, nil, menu, "cursor")
    else
      if isSeeds then
        DB.seeds = this:GetChecked() and true or false
      else
        DB.trees = this:GetChecked() and true or false
      end
      RefreshAll()
    end
  end)
  b:SetScript("OnEnter", function()
    local tip = WorldMapTooltip or GameTooltip
    tip:SetOwner(this, "ANCHOR_RIGHT")
    tip:AddLine("Wood and Seeds Gather")
    tip:AddLine("Left-click: show or hide the " .. string.lower(label), 1, 1, 1)
    tip:AddLine("Right-click: options and types", 1, 1, 1)
    local mapFile = GetMapInfo()
    local here = CountOnMap(isSeeds)
    if here and here > 0 then
      tip:AddLine(here .. " " .. what .. " spots on this map", 0.6, 0.6, 0.6)
    elseif mapFile == "Kalimdor" or mapFile == "Azeroth" then
      tip:AddLine("Markers show what each zone has; click one to open it", 0.6, 0.6, 0.6)
    end
    tip:Show()
  end)
  b:SetScript("OnLeave", PinOnLeave)
  return b
end

local function CreateToggles()
  treeMenu = CreateFrame("Frame", "WoodAndSeedsGatherTreeMenu", UIParent, "UIDropDownMenuTemplate")
  UIDropDownMenu_Initialize(treeMenu, TreeMenuInit, "MENU")
  seedMenu = CreateFrame("Frame", "WoodAndSeedsGatherSeedMenu", UIParent, "UIDropDownMenuTemplate")
  UIDropDownMenu_Initialize(seedMenu, SeedMenuInit, "MENU")

  treeToggle = MakeToggle("WoodAndSeedsGatherTreeToggle", "Trees", -44, "tree", treeMenu, false)
  seedToggle = MakeToggle("WoodAndSeedsGatherSeedToggle", "Seeds", -110, "seed", seedMenu, true)
  SyncToggle()

  -- redraw when the map opens (WORLD_MAP_UPDATE covers zone changes while it is open)
  local watcher = CreateFrame("Frame", nil, WorldMapButton)
  watcher:SetScript("OnShow", UpdateWorldMap)
end

-- slash command -------------------------------------------------------------

local function OnOff(v)
  if v then return "|cff40ff40on|r" end
  return "|cffff5050off|r"
end

local function TypeList(from, to)
  local parts = {}
  for i = from, to do
    table.insert(parts, TYPES[i].key .. " " .. OnOff(DB.types[i]))
  end
  return table.concat(parts, ", ")
end

local function Status()
  Print("trees " .. OnOff(DB.trees) .. ", seeds " .. OnOff(DB.seeds) .. ", world map " .. OnOff(DB.worldmap)
    .. ", minimap " .. OnOff(DB.minimap) .. ", only trees I can chop " .. OnOff(DB.onlyUsable))
  Print("trees: " .. TypeList(1, NUM_TREES))
  Print("seeds: " .. TypeList(NUM_TREES + 1, table.getn(TYPES)))
  if survival then
    Print("your Survival skill: " .. survival)
  else
    Print("Survival skill not found on this character")
  end
end

local function Help()
  Print("/trees on | off  -  show or hide everything")
  Print("/trees trees | seeds  -  show or hide the trees or the seeds")
  Print("/trees map | minimap  -  toggle the world map or minimap pins")
  Print("/trees mine  -  only show trees your Survival skill can chop")
  Print("/trees simple | bright | shade | tropical | dead | star  -  toggle a tree type")
  Print("/trees pumpkin | berry | melon | grape | yam | carrot | cabbage | mushroom  -  toggle a seed type")
  Print("/trees size <8-24> | minisize <6-20>  -  pin sizes")
  Print("/trees status  -  current settings.  Right-click the Trees or Seeds box on the world map for a menu.")
end

local function Slash(msg)
  local _, _, cmd, rest = string.find(string.lower(msg or ""), "^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd or ""
  if cmd == "" or cmd == "help" then
    Help()
    return
  elseif cmd == "on" then
    DB.trees, DB.seeds = true, true
  elseif cmd == "off" then
    DB.trees, DB.seeds = false, false
  elseif cmd == "trees" then
    DB.trees = not DB.trees
  elseif cmd == "seeds" then
    DB.seeds = not DB.seeds
  elseif cmd == "map" then
    DB.worldmap = not DB.worldmap
  elseif cmd == "minimap" then
    DB.minimap = not DB.minimap
  elseif cmd == "mine" then
    DB.onlyUsable = not DB.onlyUsable
  elseif cmd == "size" or cmd == "minisize" then
    local v = tonumber(rest)
    local lo, hi = 8, 24
    if cmd == "minisize" then lo, hi = 6, 20 end
    if not v or v < lo or v > hi then
      Print("use a number from " .. lo .. " to " .. hi)
      return
    end
    DB[cmd] = math.floor(v)
  elseif cmd == "status" then
    Status()
    return
  elseif cmd == "debug" then
    local mapFile = GetMapInfo() or "?"
    Print("map " .. mapFile .. ", trees here " .. (CountOnMap(false) or 0) .. ", seed spots here "
      .. (CountOnMap(true) or 0) .. ", indoors " .. tostring(indoor) .. ", zoom " .. Minimap:GetZoom())
    if ReadPlayer() then
      Print(string.format("you: continent %d, %.0f yards east, %.0f yards south", player.cont, player.e, player.s))
    end
    return
  else
    local found
    for i = 1, table.getn(TYPES) do
      if TYPES[i].key == cmd then found = i end
    end
    if not found then
      Help()
      return
    end
    DB.types[found] = not DB.types[found]
  end
  SyncToggle()
  RefreshAll()
  Status()
end

-- startup -------------------------------------------------------------------

local function LoadSettings()
  if type(WoodAndSeedsGatherDB) ~= "table" then WoodAndSeedsGatherDB = {} end
  DB = WoodAndSeedsGatherDB
  for k, v in pairs(DEFAULTS) do
    if DB[k] == nil then
      if type(v) == "table" then
        DB[k] = {}
        for i, w in pairs(v) do DB[k][i] = w end
      else
        DB[k] = v
      end
    end
  end
  for i = 1, table.getn(TYPES) do
    if DB.types[i] == nil then DB.types[i] = true end
  end
end

local core = CreateFrame("Frame", "WoodAndSeedsGatherCore")
local elapsed, lastE, lastS, lastZoom, lastForce = 0, nil, nil, nil, 0

core:RegisterEvent("PLAYER_LOGIN")
core:RegisterEvent("PLAYER_ENTERING_WORLD")
core:RegisterEvent("ZONE_CHANGED_NEW_AREA")
core:RegisterEvent("SKILL_LINES_CHANGED")
core:RegisterEvent("WORLD_MAP_UPDATE")

core:SetScript("OnEvent", function()
  if event == "PLAYER_LOGIN" then
    LoadSettings()
    local trees, seeds = BuildNodes()
    ReadSkill()
    CreateToggles()
    SLASH_WOODANDSEEDSGATHER1 = "/trees"
    SLASH_WOODANDSEEDSGATHER2 = "/seeds"
    SLASH_WOODANDSEEDSGATHER3 = "/wood"
    SLASH_WOODANDSEEDSGATHER4 = "/wsgather"
    SlashCmdList["WOODANDSEEDSGATHER"] = Slash
    Print(trees .. " trees and " .. seeds .. " seed spots loaded. Type /trees for options.")
  elseif not DB then
    return
  elseif event == "SKILL_LINES_CHANGED" then
    ReadSkill()
    RefreshAll()
  elseif event == "WORLD_MAP_UPDATE" then
    UpdateWorldMap()
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    if not WorldMapFrame:IsVisible() then SetMapToCurrentZone() end
    indoorCheck = 0
    lastForce = 0
  end
end)

core:SetScript("OnUpdate", function()
  if not DB then return end
  elapsed = elapsed + arg1
  if elapsed < 0.1 then return end
  elapsed = 0
  -- redraw when the player moved or zoomed, and at least once a second
  local px, py = GetPlayerMapPosition("player")
  local zoom = Minimap:GetZoom()
  if px == lastE and py == lastS and zoom == lastZoom and GetTime() < lastForce then return end
  lastE, lastS, lastZoom, lastForce = px, py, zoom, GetTime() + 1
  UpdateMinimap()
end)
