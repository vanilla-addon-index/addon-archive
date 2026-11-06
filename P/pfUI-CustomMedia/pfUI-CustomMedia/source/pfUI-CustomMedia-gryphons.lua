if not pfUI then return end

local addonpath
local tocs = { "", "-master", "-tbc", "-wotlk" }
for _, name in ipairs(tocs) do
  local current = string.format("pfUI-CustomMedia%s", name)
  local _, title = GetAddOnInfo(current)
  if title then
    addonpath = "Interface\\AddOns\\" .. current
    break
  end
end

if type(pfUI.gui) == "table" and type(pfUI.gui.dropdowns) == "table" and type(pfUI.gui.dropdowns.gryphons) ~= "table" then
  pfUI.gui.dropdowns.gryphons = {}
end

-- Keep the familiar gryphons first, then list the remaining options alphabetically.
local gryphons = {
  {name = "Gryphon Dragonflight", path = "GryphonDragonflight"},
  {name = "Gryphon Forever", path = "GryphonForever"},
  {name = "Gryphon Forever Mono", path = "GryphonForeverMono"},
  {name = "Lion Dragonflight", path = "LionDragonflight"},
  {name = "Lion Forever", path = "LionForever"},
  {name = "Lion Forever Mono", path = "LionForeverMono"},
  {name = "Winged Lion", path = "wingedlion"},
  {name = "Dragon Dragonflight", path = "DragonDragonflight"},
  {name = "Dragon Forever", path = "DragonForever"},
  {name = "Dragon Forever Mono", path = "DragonForeverMono"},
  {name = "Diablo 1", path = "diablo1"},
  {name = "Diablo 2", path = "diablo2"},
  {name = "Diablo 3", path = "diablo3"},
  {name = "Diablo 4", path = "diablo4"},
  {name = "Dwarf", path = "dwarf"},
  {name = "Ghoul", path = "ghoul"},
  {name = "Gnome", path = "gnome"},
  {name = "Human", path = "human"},
  {name = "Leaf", path = "Leaf"},
  {name = "Murloc", path = "murloc"},
  {name = "Murloc 2", path = "murloc2"},
  {name = "Night Elf", path = "nightelf"},
  {name = "Octopus", path = "octopus"},
  {name = "Orc", path = "orc"},
  {name = "Skull", path = "skull"},
  {name = "Skull 2", path = "skull2"},
  {name = "Squid", path = "SquidModDefault"},
  {name = "Tauren", path = "tauren"},
  {name = "Troll", path = "troll"},
  {name = "Turtle", path = "turtle"},
}

-- Function to add custom textures
local function AddCustomGryphons()
  if not addonpath or type(pfUI.gryphons) ~= "table" or type(pfUI.gryphons.textures) ~= "table" then return end
  if type(pfUI.gui) ~= "table" or type(pfUI.gui.dropdowns) ~= "table" then return end
  if type(pfUI.gui.dropdowns.gryphons) ~= "table" then pfUI.gui.dropdowns.gryphons = {} end
  local dropdown = pfUI.gui.dropdowns.gryphons
  local registered = {}
  for _, entry in ipairs(dropdown) do registered[entry] = true end

  for _, gryphon in ipairs(gryphons) do
    local fullpath = addonpath .. "\\gryphons\\" .. gryphon.path .. ".tga"
    pfUI.gryphons.textures[gryphon.name] = fullpath
    local option = string.format("%s:%s", gryphon.name, gryphon.name)
    if not registered[option] then
      table.insert(dropdown, option)
      registered[option] = true
    end
  end
  -- Force update the gryphons if they're already configured
  if type(pfUI.gryphons.UpdateConfig) == "function" then
    pfUI.gryphons.UpdateConfig()
  end
end

local moverNames = {
  left = "pfUICustomMediaGryphonLeft",
  right = "pfUICustomMediaGryphonRight",
}

local function HasSavedMoverPosition(name)
  local positions = pfUI_config and pfUI_config.position
  return type(positions) == "table" and type(positions[name]) == "table" and positions[name].xpos ~= nil
end

local function CopyFramePosition(source, target)
  local point, relative, relativePoint, x, y = source:GetPoint()
  target:ClearAllPoints()
  local relativeIsTarget = relative == target or relative == target:GetName() or
    (relative and type(relative) ~= "string" and type(relative) ~= "number" and
      type(relative.GetName) == "function" and relative:GetName() == target:GetName())
  if point and relative and not relativeIsTarget and relative ~= source then
    target:SetPoint(point, relative, relativePoint or point, x or 0, y or 0)
  elseif point then
    -- A gryphon anchor can resolve to this named mover after a reload or
    -- another addon has already reparented the frame. Never create a cycle.
    target:SetPoint(point, UIParent, relativePoint or point, x or 0, y or 0)
  else
    target:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

local function InstallMovableGryphons()
  if type(pfUI.gryphons) ~= "table" or type(pfUI.gryphons.frames) ~= "table" then return end
  if type(pfUI.gryphons.UpdateConfig) ~= "function" or type(pfUI.api) ~= "table" or type(pfUI.api.UpdateMovable) ~= "function" then return end
  if pfUI.gryphons.customMediaMoversInstalled then return end

  local originalUpdate = pfUI.gryphons.UpdateConfig
  local movers = {}
  local environment = type(pfUI.GetEnvironment) == "function" and pfUI:GetEnvironment() or _G
  local config = environment.C and environment.C.bars and environment.C.bars.gryphons
  local lastAnchors = type(config) == "table" and {
    left = config.anchor_left,
    right = config.anchor_right,
  } or {}
  pfUI.gryphons.customMediaMovers = movers
  pfUI.gryphons.customMediaMoversInstalled = true

  local function ClearSavedMoverPosition(name)
    local saved = pfUI_config and pfUI_config.position
    if type(saved) == "table" then saved[name] = nil end
    local configured = environment.C and environment.C.position
    if type(configured) == "table" then configured[name] = nil end
  end

  local function UpdateMovers()
    -- The core gryphon updater uses SetPoint without clearing prior anchors.
    -- Remove the child-to-mover anchor first so it cannot be mistaken for
    -- pfUI's configured default anchor when resetting or changing settings.
    for _, frame in pairs(pfUI.gryphons.frames) do
      if frame then frame:ClearAllPoints() end
    end
    -- pfUI's updater assumes that every anchor name resolves to a frame.
    -- "None" (or an empty anchor) resolves to nil and SetParent(nil) crashes.
    -- Use UIParent just for this update; keep the user's selected value intact.
    local anchors = {}
    if type(config) == "table" then
      for position in pairs(moverNames) do
        local key = "anchor_" .. position
        anchors[key] = { value = config[key] }
        if lastAnchors[position] ~= config[key] then
          ClearSavedMoverPosition(moverNames[position])
          local mover = movers[position]
          if mover then mover:SetScale(1) end
        end
        if not config[key] or not _G[config[key]] then config[key] = "UIParent" end
      end
    end
    originalUpdate()
    if type(config) == "table" then
      for position in pairs(moverNames) do
        local key = "anchor_" .. position
        config[key] = anchors[key].value
        lastAnchors[position] = anchors[key].value
      end
    end
    for position, name in pairs(moverNames) do
      local frame = pfUI.gryphons.frames[position]
      if frame then
        local mover = movers[position]
        if not mover then
          mover = CreateFrame("Frame", name, UIParent)
          mover:SetFrameStrata("MEDIUM")
          CopyFramePosition(frame, mover)
          pfUI.api.UpdateMovable(mover, true)
          movers[position] = mover
        elseif not HasSavedMoverPosition(name) then
          CopyFramePosition(frame, mover)
        end
        -- pfUI clamps movable frames when its offscreen option is disabled.
        -- Gryphon movers must remain freely draggable past the screen edges.
        mover:SetClampedToScreen(false)

        mover:SetWidth(frame:GetWidth())
        mover:SetHeight(frame:GetHeight())
        local point = frame:GetPoint()
        point = point or "CENTER"
        frame:SetParent(mover)
        frame:SetFrameStrata("HIGH")
        frame:SetFrameLevel(mover:GetFrameLevel() + 1)
        frame:ClearAllPoints()
        frame:SetPoint(point, mover, point, 0, 0)
      end
    end
  end

  pfUI.gryphons.UpdateConfig = UpdateMovers
  UpdateMovers()
end

local function ResetGryphonPosition()
  local positions = pfUI_config and pfUI_config.position
  if type(positions) == "table" then
    for _, name in pairs(moverNames) do positions[name] = nil end
  end
  if type(C.position) == "table" then
    for _, name in pairs(moverNames) do C.position[name] = nil end
  end
  local movers = pfUI.gryphons and pfUI.gryphons.customMediaMovers
  if type(movers) == "table" then
    for _, mover in pairs(movers) do
      if mover then mover:SetScale(1) end
    end
  end

  if type(pfUI.gryphons.UpdateConfig) == "function" then
    pfUI.gryphons.UpdateConfig()
  end
end

-- C and pfUI_config are already available in this module's environment via
-- pfUI:GetEnvironment(), so no setfenv is needed here.
pfUI.customMedia = pfUI.customMedia or {}
pfUI.customMedia.ResetGryphonPosition = ResetGryphonPosition

local function InitializeCustomGryphons()
  InstallMovableGryphons()
  AddCustomGryphons()
end

-- Hook into pfUI's module registration system
if type(pfUI.RegisterModule) == "function" then
  pfUI:RegisterModule("custom-gryphons", "vanilla:tbc", function()
    InitializeCustomGryphons()
  end)
else
  -- Fallback: try to add immediately and on events
  InitializeCustomGryphons()

  local frame = CreateFrame("Frame")
  frame:RegisterEvent("ADDON_LOADED")
  frame:SetScript("OnEvent", function()
    -- Capture event and arg1 into locals (Classic 1.12-safe).
    local event, arg1 = event, arg1
    if event == "ADDON_LOADED" and arg1 == "pfUI" then
      InitializeCustomGryphons()
      this:UnregisterEvent("ADDON_LOADED")
    end
  end)
end
