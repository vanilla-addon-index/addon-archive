-- Turtle WoW changes parts of the stock 1.12 UI and gameplay APIs.
-- Keep the small compatibility adjustments that ShaguTweaks still needs.

-- Skip module initialization on every other client than TurtleWoW.
if not TargetHPText or not TargetHPPercText then return end

local T = ShaguTweaks.T
local _G = ShaguTweaks.GetGlobalEnv()

local function IsFirstContinent()
  local maps = _G.C_Map
  local first = GetMapContinents()
  if first and maps and type(maps.GetBestMapForUnit) == "function"
    and type(maps.GetMapInfo) == "function" then
    local id = maps.GetBestMapForUnit("player")
    for depth = 1, 8 do
      if not id or id == 0 then return false end
      local info = maps.GetMapInfo(id)
      if not info then break end
      if info.name == first then return true end
      id = info.parentMapID
    end
  end

  -- Older ClassicAPI builds lack the map hierarchy. Restore the viewed map
  -- immediately instead of leaving it on the player's zone after clock hover.
  local continent, zone = GetCurrentMapContinent(), GetCurrentMapZone()
  if continent == nil or zone == nil then return end
  SetMapToCurrentZone()
  local result = GetCurrentMapContinent() == 1
  if continent == 0 then SetMapZoom(0) else SetMapZoom(continent, zone) end
  return result
end

local module = ShaguTweaks:register({
  title = T["Turtle WoW Compatibility"],
  description = T["Adds compatibility to Turtle WoW's custom changes."],
  expansions = { ["vanilla"] = true },
  enabled = true,
})

module.enable = function(self)
  -- Minimap Clock owns its tooltip script. Expose only Turtle's time conversion
  -- so the clock can consume it dynamically regardless of module enable order.
  ShaguTweaks.GetTurtleClockTimes = function()
    local zh, zm = GetGameTime()
    local sh, sm = zh, zm

    if IsFirstContinent() then
      sh = sh + 12
      sh = sh >= 24 and sh - 24 or sh
    end

    local servertime = string.format("%.2d:%.2d", sh, sm)
    local zonetime = string.format("%.2d:%.2d", zh, zm)
    return servertime, zonetime
  end

  -- Turtle changes WorldMapFrame_Maximize. Keep our compatibility wrapper
  -- completely out of the way when a dedicated map addon owns the world map.
  if not Cartographer and not METAMAP_TITLE then
    local HookWorldMapFrame_Maximize = WorldMapFrame_Maximize
    WorldMapFrame_Maximize = function()
      -- run original function
      HookWorldMapFrame_Maximize()

      -- Re-apply only when WorldMap Window really initialized.
      if ShaguTweaks.WorldMapWindowActive then
        WorldMapFrame:SetMovable(true)
        WorldMapFrame:EnableMouse(true)

        -- Keep the size picked with Ctrl + Mousewheel (saved by WorldMap Window).
        WorldMapFrame:SetScale(ShaguTweaks.GetWorldMapScale and ShaguTweaks.GetWorldMapScale() or .85)
        WorldMapFrame:ClearAllPoints()
        WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
        WorldMapFrame:SetWidth(WorldMapButton:GetWidth() + 15)
        WorldMapFrame:SetHeight(WorldMapButton:GetHeight() + 55)

        -- overwrite wrong title position set by turtlewow
        WorldMapFrameTitle:SetPoint("TOP", WorldMapFrame, 0, 17)

        -- The title now sits above the frame: let the title bar drag it too.
        if ShaguTweaks.UpdateWorldMapDragArea then
          ShaguTweaks.UpdateWorldMapDragArea()
        end

        BlackoutWorld:Hide()
      end
    end

    -- Trigger once after every module has handled PLAYER_ENTERING_WORLD. A
    -- zero-delay ClassicAPI timer makes the result independent of event order.
    local worldmapInit = CreateFrame("Frame")
    worldmapInit:RegisterEvent("PLAYER_ENTERING_WORLD")
    worldmapInit:SetScript("OnEvent", function()
      this:UnregisterAllEvents()
      this:Hide()
      C_Timer.After(0, function()
        WorldMapFrame_Maximize()
      end)
    end)
  end

  -- Vendor Values exposes a lazy ClassicAPI-backed SellValueDB compatibility
  -- table, so do not allocate a second Turtle-specific static price database.
end
