local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["WorldMap Class Colors"],
  description = T["Show class colored circles on world and battlefield map."],
  expansions = { ["vanilla"] = true },
  category = T["Minimap & World Map"],
  enabled = true,
})

local addonpath
local tocs = { "", "-master", "-tbc", "-wotlk" }
for _, name in pairs(tocs) do
  local current = string.format("ShaguTweaks%s", name)
  local _, title = GetAddOnInfo(current)
  if title then
    addonpath = "Interface\\AddOns\\" .. current
    break
  end
end

local partyUnits = { "party1", "party2", "party3", "party4" }
local UPDATE_INTERVAL = .1
local partyNames = {}

local function RefreshPartyNames()
  for name in pairs(partyNames) do partyNames[name] = nil end
  for i = 1, 4 do
    local name = UnitName(partyUnits[i])
    if name then partyNames[name] = true end
  end
end

local function SetAllPointsOffset(frame, parent, offset)
  frame:SetPoint("TOPLEFT", parent, "TOPLEFT", offset, -offset)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -offset, offset)
end

-- Icon names for one map ("WorldMap" or "BattlefieldMinimap"), each with the
-- unit the icon shows when the map does not say otherwise.
local function BuildButtons(prefix)
  local buttons = {}
  for i = 1, 4 do
    table.insert(buttons, { prefix .. "Party" .. i, "party" .. i })
  end
  for i = 1, 40 do
    table.insert(buttons, { prefix .. "Raid" .. i, "raid" .. i })
  end
  return buttons
end

-- In a raid the map packs its raid icons: WorldMapRaid1 is the first raid
-- member who is on this map (yourself excluded), not raid1. The map stores
-- the real unit on the icon as .unit, and battleground team members outside
-- the raid only as .name. Using raidN for WorldMapRaidN showed other players'
-- class colors.
local function ResolveIcon(frame, fallback)
  if frame.name then
    return nil, frame.name
  elseif frame.unit and UnitExists(frame.unit) then
    return frame.unit, UnitName(frame.unit)
  elseif not frame.unit and UnitExists(fallback) then
    return fallback, UnitName(fallback)
  end
end

local function UpdateIcon(frame, fallback)
  local unit, name = ResolveIcon(frame, fallback)
  if not unit and not name then return end

  local icon = _G[frame:GetName() .. "Icon"]
  if icon and icon:GetTexture() then icon:SetTexture() end

  -- create icon if not yet existing
  if not frame.texture then
    frame.texture = frame:CreateTexture(nil, "OVERLAY")
    SetAllPointsOffset(frame.texture, frame, 12)
  end

  -- check if unit is in same party group
  local ingroup = name and partyNames[name]

  -- update texture according to raid/group state
  if ingroup and frame.texture.ingroup ~= "PARTY" then
    frame.texture:SetTexture(addonpath .. "\\img\\circleparty")
    frame.texture.ingroup = "PARTY"
  elseif not ingroup and frame.texture.ingroup ~= "RAID" then
    frame.texture:SetTexture(addonpath .. "\\img\\circleraid")
    frame.texture.ingroup = "RAID"
  end

  -- detect unit class and set color
  local class
  if unit then
    local _, token = UnitClass(unit)
    class = token
  elseif name and ShaguTweaks.GetUnitData then
    class = ShaguTweaks.GetUnitData(name)
  end

  local color = class and RAID_CLASS_COLORS[class]
  local r, g, b = color and color.r or .5, color and color.g or 1, color and color.b or .5
  if frame.texture.classR ~= r or frame.texture.classG ~= g or frame.texture.classB ~= b then
    frame.texture.classR, frame.texture.classG, frame.texture.classB = r, g, b
    frame.texture:SetVertexColor(r, g, b)
  end
end

local function UpdateMapColors()
  this.elapsed = (this.elapsed or UPDATE_INTERVAL) + arg1
  if this.elapsed < UPDATE_INTERVAL then return end
  this.elapsed = 0
  local partyRefreshed = false

  local buttons = this.buttons
  for i = 1, table.getn(buttons) do
    local frame = _G[buttons[i][1]]
    if frame and frame:IsVisible() then
      if not partyRefreshed then RefreshPartyNames(); partyRefreshed = true end
      UpdateIcon(frame, buttons[i][2])
    end
  end
end

-- The updater is a child of its map, so its OnUpdate only runs while that
-- map is shown. This module used to run a frame-wide updater all the time.
local updaters = {}
local function AttachUpdater(map, prefix)
  if not map or updaters[prefix] then return end

  local updater = CreateFrame("Frame", nil, map)
  updater.buttons = BuildButtons(prefix)
  updater:SetScript("OnUpdate", UpdateMapColors)
  updaters[prefix] = updater
end

module.enable = function(self)
  AttachUpdater(_G.WorldMapFrame, "WorldMap")

  -- The battlefield minimap is a load-on-demand Blizzard addon.
  if _G.BattlefieldMinimap then
    AttachUpdater(_G.BattlefieldMinimap, "BattlefieldMinimap")
  else
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function()
      if _G.BattlefieldMinimap then
        AttachUpdater(_G.BattlefieldMinimap, "BattlefieldMinimap")
        this:UnregisterEvent("ADDON_LOADED")
      end
    end)
  end
end
