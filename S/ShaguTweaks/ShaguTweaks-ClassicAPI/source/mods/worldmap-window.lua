local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API
local HookScript = ShaguTweaks.HookScript

local module = ShaguTweaks:register({
  title = T["WorldMap Window"],
  description = T["Turns the world map into a movable window. The map can be scaled with <Ctrl> + Mousewheel."],
  expansions = { ["vanilla"] = true },
  category = T["Minimap & World Map"],
  enabled = true,
})

local DEFAULT_SCALE = .85
local MIN_SCALE, MAX_SCALE = .4, 2

local function AddSpecialFrame(name)
  for i = 1, table.getn(UISpecialFrames) do
    if UISpecialFrames[i] == name then return end
  end
  table.insert(UISpecialFrames, name)
end

-- The scale chosen with Ctrl + Mousewheel is saved per character, so the map
-- reopens (and survives a reload) at the size it was left at.
local function GetSavedScale()
  local scale = ShaguTweaks_config and tonumber(ShaguTweaks_config["WorldMapScale"])
  if not scale then return DEFAULT_SCALE end
  if scale < MIN_SCALE then return MIN_SCALE end
  if scale > MAX_SCALE then return MAX_SCALE end
  return scale
end

local function SaveScale(scale)
  if not ShaguTweaks_config then return end
  ShaguTweaks_config["WorldMapScale"] = scale
end

-- Turtle WoW Compatibility re-applies the window layout after Turtle's own
-- WorldMapFrame_Maximize and uses this instead of a fixed scale.
ShaguTweaks.GetWorldMapScale = GetSavedScale

-- The window's title bar is drawn above the frame's top edge (Turtle places
-- the title 17 units above it), so clicks there missed the frame and only
-- the dropdown row could be dragged. Extend the frame's clickable area up to
-- the top of the title. The close and minimize buttons are child frames on
-- a higher level, so they keep their clicks.
local TITLE_MARGIN = 6

local function TitleHeightAboveFrame()
  local title = WorldMapFrameTitle
  if not title then return 0 end

  -- Prefer the anchor: exact, and valid before the layout is computed.
  local count = title.GetNumPoints and title:GetNumPoints() or 1
  for i = 1, count do
    local point, relativeTo, relativePoint, _, y = title:GetPoint(i)
    if point == "TOP" and relativeTo == WorldMapFrame
      and (relativePoint == nil or relativePoint == "TOP") and y then
      return y
    end
  end

  local frameTop, titleTop = WorldMapFrame:GetTop(), title:GetTop()
  if frameTop and titleTop then return titleTop - frameTop end
  return 0
end

local function UpdateDragArea()
  local extra = TitleHeightAboveFrame()
  if extra > 0 then
    extra = math.floor(extra + TITLE_MARGIN + .5)
    if extra > 40 then extra = 40 end
  else
    extra = 0
  end

  WorldMapFrame:SetHitRectInsets(0, 0, -extra, 0)
end

ShaguTweaks.UpdateWorldMapDragArea = UpdateDragArea

-- OctoBus (github.com/Phridgey/OctoBus) shows transport timers. When it is
-- loaded, add a "Transports" button in front of the Continent dropdown that
-- toggles its window, the same as a left-click on its minimap icon.
local function OctoBusAvailable()
  return OctoBusPanel and SlashCmdList and SlashCmdList["OCTOBUS"] and true or false
end

local function CreateTransportsButton()
  if module.transports or not OctoBusAvailable() then return end
  if not WorldMapContinentDropDown or not WorldMapZoomOutButton then return end

  local button = CreateFrame("Button", "ShaguTweaksWorldMapTransports", WorldMapFrame, "UIPanelButtonTemplate")
  button:SetWidth(WorldMapZoomOutButton:GetWidth() or 110)
  button:SetHeight(WorldMapZoomOutButton:GetHeight() or 22)
  -- Mirror of the Zoom Out button, which sits 10 units into the zone
  -- dropdown's transparent right edge and 3 units higher.
  button:SetPoint("RIGHT", WorldMapContinentDropDown, "LEFT", 10, 3)
  button:SetText(T["Transports"])

  -- OctoBus' window lives on the MEDIUM strata, behind the full-screen map.
  -- Lift it above the map while both are open (also when OctoBus opens it
  -- by itself at a dock), and give it its own strata back afterwards.
  local function RaisePanel()
    if not WorldMapFrame:IsShown() or not OctoBusPanel:IsShown() then return end
    if not module.panelStrata then
      module.panelStrata = OctoBusPanel:GetFrameStrata()
    end
    OctoBusPanel:SetFrameStrata("FULLSCREEN_DIALOG")
  end

  local function RestorePanel()
    if module.panelStrata then
      OctoBusPanel:SetFrameStrata(module.panelStrata)
      module.panelStrata = nil
    end
  end

  HookScript(WorldMapFrame, "OnShow", RaisePanel)
  HookScript(WorldMapFrame, "OnHide", RestorePanel)
  HookScript(OctoBusPanel, "OnShow", RaisePanel)

  button:SetScript("OnClick", function()
    -- OctoBus' "/ob" without arguments is the same toggle as its icon.
    SlashCmdList["OCTOBUS"]("")
    RaisePanel()
  end)

  button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:SetText(T["Transports"])
    GameTooltip:AddLine(T["Shows or hides the OctoBus transport timers."], 1, 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  module.transports = button
end

module.enable = function(self)
  -- Only advertise the window as active after the delayed compatibility check.
  -- Turtle WoW consumes this flag instead of looking at config alone.
  ShaguTweaks.WorldMapWindowActive = nil

  -- Reuse one initialization frame so repeated enable() calls cannot stack
  -- PLAYER_ENTERING_WORLD handlers or duplicate WorldMapFrame hooks.
  if not self.delay then
    self.delay = CreateFrame("Frame")
  end

  local delay = self.delay
  delay:RegisterEvent("PLAYER_ENTERING_WORLD")
  delay:SetScript("OnEvent", function()
    -- Do not touch the stock world-map controls at all when a dedicated map
    -- addon owns them. Run this before replacing ToggleWorldMap or adding hooks.
    if Cartographer or METAMAP_TITLE then
      ShaguTweaks.WorldMapWindowActive = nil
      this:UnregisterAllEvents()
      this:Hide()
      return
    end

    ShaguTweaks.WorldMapWindowActive = true
    AddSpecialFrame("WorldMapFrame")

    -- Window mode requires a direct Show/Hide toggle instead of the stock
    -- full-screen panel toggle. Install it only after the compatibility check.
    if not self.toggleInstalled then
      self.toggleInstalled = true
      function _G.ToggleWorldMap()
        if WorldMapFrame:IsShown() then
          WorldMapFrame:Hide()
        else
          WorldMapFrame:Show()
        end
      end
    end

    UIPanelWindows["WorldMapFrame"] = { area = "center" }

    if not self.hooked then
      self.hooked = true

      HookScript(WorldMapFrame, "OnShow", function()
        this:EnableKeyboard(false)
        this:EnableMouseWheel(1)
        WorldMapFrame:SetScale(GetSavedScale())
        UpdateDragArea()
      end)

      HookScript(WorldMapFrame, "OnMouseWheel", function()
        if API.IsShiftKeyDown() then
          WorldMapFrame:SetAlpha(WorldMapFrame:GetAlpha() + arg1 / 10)
        elseif API.IsControlKeyDown() then
          local scale = WorldMapFrame:GetScale() + arg1 / 10
          if scale < MIN_SCALE then scale = MIN_SCALE end
          if scale > MAX_SCALE then scale = MAX_SCALE end
          WorldMapFrame:SetScale(scale)
          SaveScale(scale)
        end
      end)

      HookScript(WorldMapFrame, "OnMouseDown", function()
        WorldMapFrame:StartMoving()
      end)

      HookScript(WorldMapFrame, "OnMouseUp", function()
        WorldMapFrame:StopMovingOrSizing()
      end)
    end

    WorldMapFrame:SetMovable(true)
    WorldMapFrame:EnableMouse(true)

    WorldMapFrame:SetScale(GetSavedScale())
    WorldMapFrame:ClearAllPoints()
    WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    WorldMapFrame:SetWidth(WorldMapButton:GetWidth() + 15)
    WorldMapFrame:SetHeight(WorldMapButton:GetHeight() + 55)
    BlackoutWorld:Hide()
    UpdateDragArea()

    CreateTransportsButton()

    -- Initialization is complete. Keeping this event registered would repeat
    -- the full layout work on every loading screen and reset a moved window.
    this:UnregisterAllEvents()
    this:Hide()
  end)
end
