-- pandaUI :: modules/minimap.lua
--
-- A settings button on the minimap ring, ring dragging for every minimap icon,
-- and a mover anchor so the minimap cluster can be dragged in pandaUI's edit
-- mode.
--
-- The map surface and its behavior stay native. Modern gives it a square mask
-- and the flat PandaUI panel treatment. Modern WoW can use its authored round
-- map or DragonflightUI's square frame with Retail's square mask; Classic's
-- explicit Minimap selection keeps the round map. The pending-mail letter is
-- not part of either path: it is
-- pandaUI's animated flipbook under every theme (see "The pending-mail letter"
-- below). knowledge.json /
-- minimap.render_pass_under_ordinary_frames says the map surface is drawn in a
-- special pass beneath ordinary frames, which is why the new shadow is alpha-
-- only over the map.
--
-- The mover targets MinimapCluster rather than bare Minimap: behavior.json /
-- minimap.context.frames.MinimapCluster confirms it holds the map's native
-- chrome (zone text, etc.) and defaults to TOPRIGHT UIParent TOPRIGHT 0,0 with
-- no pfUI involvement, so moving the cluster keeps that chrome attached and
-- the registration's own default matches where the client already puts it.
-- The settings button is a child of Minimap fixed on its rim, so it follows
-- the cluster when it moves; like the other ring icons it only drags along the
-- minimap's edge (see "Icons around the minimap").

local U = PandaUI
local M = U.media

local MM = U.RegisterModule("minimap")

-- The native minimap icons: a 33px button (its hover glow fills it) whose
-- visible MiniMap-TrackingBorder ring is about 28px across (texel bbox 4..39 of
-- 64, drawn at 52px; Octo FrameXML Minimap.xml).
local BUTTON_SIZE = 33
local ICON_SIZE = 28
local MINIMAP_HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
-- The button's old drag position in the shared position store. Only read to
-- clear it: the button is now fixed to the minimap.
local POSITION_ID = "minimapbutton"

local modernFlatMinimap = { dressed = false }
local modernWowMinimap = { dressed = false }
local SHAPE_DEFAULTS = { modernWowShape = "circle" }
local MOVER_SHAPE_WIDTH = 220

local function ModernWow()
  return type(U.ModernWowModuleEnabled) == "function" and
         U.ModernWowModuleEnabled("minimap")
end

-- The flat Modern theme owns a separate square drawing path.
local function ModernFlat()
  return U.GetActiveThemeStyle() == "modern"
end

local function ModernWowTheme()
  return U.GetActiveThemeStyle() == "modern-wow"
end

local function ModernWowShape()
  local cfg = U.ModuleConfig("minimap", SHAPE_DEFAULTS)
  if cfg.modernWowShape == "square" then return "square" end
  return "circle"
end

local function SquareMinimap()
  return ModernFlat() or (ModernWowTheme() and ModernWowShape() == "square")
end

U.MinimapIsSquare = SquareMinimap

-- The stock minimap ring on this client is not one dependable region:
-- knowledge.json / minimap.native_chrome_requires_targeted_suppression and the
-- working UnrealPfUI path both identify an oversized MinimapBackdrop plus the
-- two named border regions. Strip only those exact decorative objects, before
-- any addon art is attached; all native map behavior and status widgets stay.
local BUTTON_ART = { "Normal", "Pushed", "Highlight", "Disabled" }

-- Clears a native button's own state textures by direct getter/setter, never
-- by a region walk (rules: region walks cannot match by identity here), then
-- hides the button and drops its mouse input.
local function ClearButtonArt(button)
  if not button then return end
  local i
  for i = 1, table.getn(BUTTON_ART) do
    local getter = button["Get" .. BUTTON_ART[i] .. "Texture"]
    if type(getter) == "function" then
      local ok, texture = pcall(getter, button)
      if ok and texture then U.HideRegion(texture) end
    end
    local setter = button["Set" .. BUTTON_ART[i] .. "Texture"]
    if type(setter) == "function" then pcall(setter, button, "") end
  end
  pcall(button.EnableMouse, button, false)
  U.HideRegion(button)
end

local function HideStockChrome()
  local backdrop = U.G("MinimapBackdrop")
  if backdrop then U.StripTextures(backdrop) end
  U.HideRegion(U.G("MinimapBorder"))
  U.HideRegion(U.G("MinimapBorderTop"))

  -- The close "X", the day/night clock and the native zone label. All four
  -- globals were confirmed present on 2026-09-14 (user /script readback;
  -- MinimapToggleButton and GameTimeFrame are MinimapCluster children). Hiding
  -- the frames alone left both icons drawn: UnrealPfUI records that child
  -- regions draw independently of their parent on this client, so each
  -- button's own state art is cleared directly as well.
  ClearButtonArt(U.G("MinimapToggleButton"))
  ClearButtonArt(U.G("GameTimeFrame"))
  U.HideRegion(U.G("GameTimeTexture"))
  U.HideRegion(U.G("MinimapZoneText"))

  -- knowledge.json / minimap.native_chrome_requires_targeted_suppression
  -- (WORKING_SOURCE): a single Hide() does not keep this chrome off screen, so
  -- the shared periodic suppression keeps them hidden afterwards.
  U.SuppressNativeFrame({
    "MinimapBorderTop",
    "MinimapToggleButton",
    "GameTimeFrame", "GameTimeTexture",
    "MinimapZoneTextButton", "MinimapZoneText",
  })
end

local function SetButtonTexture(button, methodName, path)
  if not button or not path then return false end
  local method = button[methodName]
  if type(method) ~= "function" then return false end
  return pcall(method, button, path)
end

local function DressZoomButton(button, normal, over, pushed, disabled)
  if not button then return false end
  SetButtonTexture(button, "SetNormalTexture", normal)
  SetButtonTexture(button, "SetHighlightTexture", over)
  SetButtonTexture(button, "SetPushedTexture", pushed)
  SetButtonTexture(button, "SetDisabledTexture", disabled)
  return true
end

local function KeepZoneLabelFresh(label, updateId, interval)
  if not label then return end
  local lastZone
  local function RefreshZone()
    if type(GetMinimapZoneText) ~= "function" then return end
    local ok, zone = pcall(GetMinimapZoneText)
    if not ok or type(zone) ~= "string" or zone == lastZone then return end
    lastZone = zone
    pcall(label.SetText, label, zone)
  end
  RefreshZone()
  U.RegisterEvent("PLAYER_ENTERING_WORLD", RefreshZone)
  U.RegisterEvent("ZONE_CHANGED", RefreshZone)
  U.RegisterEvent("ZONE_CHANGED_INDOORS", RefreshZone)
  U.RegisterEvent("ZONE_CHANGED_NEW_AREA", RefreshZone)
  U.RegisterUpdate(updateId, interval, RefreshZone)
end

-- pfUI-octo uses an all-white 8x8 texture as Minimap's mask. WHITE8X8 is the
-- same shape, so Modern can become square without shipping another asset.
local function DressModernFlatMinimap()
  if modernFlatMinimap.dressed or not ModernFlat() then return false end

  local minimap = U.G("Minimap")
  local layout = M.minimapModern
  if not minimap or not layout or type(minimap.SetMaskTexture) ~= "function" then
    U.Debug("modern minimap: square mask unavailable; native map retained")
    return false
  end
  if not pcall(minimap.SetMaskTexture, minimap, layout.maskTexture) then
    U.Debug("modern minimap: square mask failed; native map retained")
    return false
  end

  HideStockChrome()
  U.CreateBorder(minimap, layout.borderSize)
  U.SetBorderColor(minimap, M.Unpack(M.color.border))

  local width = 140
  local ok, liveWidth = pcall(minimap.GetWidth, minimap)
  if ok and type(liveWidth) == "number" and liveWidth > 0 then width = liveWidth end

  local panel = U.CreatePanel(minimap, {
    name = "PandaUIModernMinimapTopPanel",
    width = width,
    height = layout.topPanelHeight,
    background = M.color.background,
    border = M.color.border,
    thickness = layout.borderSize,
  })
  panel:SetPoint("BOTTOM", minimap, "TOP", 0, layout.topPanelGap)

  local zoneLabel = U.CreateLabel(panel, {
    name = "PandaUIModernMinimapZoneText",
    inherits = "GameFontNormal",
    size = layout.zoneFontSize,
    color = M.color.accent,
    justify = "CENTER",
    width = width - layout.topPanelInset * 2,
    exactSize = true,
  })
  if zoneLabel then
    pcall(zoneLabel.SetPoint, zoneLabel, "CENTER", panel, "CENTER", 0,
      layout.zoneY)
    KeepZoneLabelFresh(zoneLabel, "minimap.modern.zone", layout.zoneRefresh)
  end

  -- Modern keeps mouse-wheel zoom, without the visible native +/- controls.
  ClearButtonArt(U.G("MinimapZoomIn"))
  ClearButtonArt(U.G("MinimapZoomOut"))

  local mailFrame = U.G("MiniMapMailFrame")
  if mailFrame then
    pcall(mailFrame.ClearAllPoints, mailFrame)
    pcall(mailFrame.SetPoint, mailFrame, "TOPRIGHT", minimap, "TOPRIGHT",
      -layout.mailInset, -layout.mailInset)
  end

  modernFlatMinimap.dressed = true
  modernFlatMinimap.zoneLabel = zoneLabel
  modernFlatMinimap.topPanel = panel
  U.Debug("modern minimap: flat square chrome applied")
  return true
end

-- Classic and Modern WoW keep the round map. The client does not reset the
-- minimap mask when the UI reloads, so a square mask applied under Modern would
-- survive the reload a theme change needs; put the stock round one back.
local function RestoreRoundMinimapMask()
  if ModernFlat() then return false end
  local minimap = U.G("Minimap")
  if not minimap or type(minimap.SetMaskTexture) ~= "function" then return false end
  if not pcall(minimap.SetMaskTexture, minimap, M.minimapRoundMask) then
    U.Debug("minimap: round mask restore failed")
    return false
  end
  return true
end

local function SetRegionVisible(region, visible)
  if not region then return end
  if visible then pcall(region.Show, region) else pcall(region.Hide, region) end
end

local function PlaceModernWowZoomButtons(square)
  local minimap = U.G("Minimap")
  local zoomIn = U.G("MinimapZoomIn")
  local zoomOut = U.G("MinimapZoomOut")
  local layout = M.modernWow and M.modernWow.minimap
  if not minimap or not layout then return end

  if zoomIn then pcall(zoomIn.ClearAllPoints, zoomIn) end
  if zoomOut then pcall(zoomOut.ClearAllPoints, zoomOut) end

  if square then
    local rightInset = layout.squareZoomRightInset / layout.zoomScale
    local bottomGap = layout.squareZoomBottomGap / layout.zoomScale
    local gap = layout.squareZoomGap / layout.zoomScale
    if zoomIn then
      pcall(zoomIn.SetPoint, zoomIn, "TOPRIGHT", minimap, "BOTTOMRIGHT",
        -rightInset, -bottomGap)
    end
    if zoomOut then
      if zoomIn then
        pcall(zoomOut.SetPoint, zoomOut, "TOPRIGHT", zoomIn, "TOPLEFT",
          -gap, 0)
      else
        pcall(zoomOut.SetPoint, zoomOut, "TOPRIGHT", minimap, "BOTTOMRIGHT",
          -rightInset, -bottomGap)
      end
    end
    return
  end

  if zoomIn then
    pcall(zoomIn.SetPoint, zoomIn, "TOPLEFT", minimap, "BOTTOMRIGHT",
      layout.zoomX, layout.zoomY)
  end
  if zoomOut then
    if zoomIn then
      pcall(zoomOut.SetPoint, zoomOut, "TOPRIGHT", zoomIn, "BOTTOMLEFT", 0, 0)
    else
      pcall(zoomOut.SetPoint, zoomOut, "TOPLEFT", minimap, "BOTTOMRIGHT",
        layout.zoomX, layout.zoomY - 42.6)
    end
  end
end

local function ApplyModernWowShape()
  if not modernWowMinimap.dressed then return false end
  local minimap = U.G("Minimap")
  local art = M.modernWow and M.modernWow.texture
  if not minimap or not art or type(minimap.SetMaskTexture) ~= "function" then
    return false
  end

  local square = ModernWowTheme() and ModernWowShape() == "square"
  local mask = square and art.minimapSquareMask or M.minimapRoundMask
  if not mask or not pcall(minimap.SetMaskTexture, minimap, mask) then
    U.Debug("modern-wow minimap: shape mask failed")
    return false
  end

  SetRegionVisible(modernWowMinimap.border, not square)
  SetRegionVisible(modernWowMinimap.shadow, not square)
  SetRegionVisible(modernWowMinimap.squareBorder, square)
  PlaceModernWowZoomButtons(square)
  modernWowMinimap.square = square

  if type(U.RefreshMinimapShapeGeometry) == "function" then
    U.RefreshMinimapShapeGeometry()
  end
  U.Debug("modern-wow minimap shape applied: " .. (square and "square" or "circle"))
  return true
end

U.ApplyMinimapShape = ApplyModernWowShape

-- The settings page and the selected minimap mover are two views of the same
-- saved shape. Keep both current when either one changes it.
local function SetModernWowShape(value)
  local shape = value == "square" and "square" or "circle"
  U.ModuleConfig("minimap", SHAPE_DEFAULTS).modernWowShape = shape
  ApplyModernWowShape()
  if type(U.RefreshSettingsPage) == "function" then
    U.RefreshSettingsPage("minimap")
  end
  if type(U.RefreshMoverPanel) == "function" then
    U.RefreshMoverPanel("minimap")
  end
end

-- Complete modern-wow drawing path. The imported layout is working-source
-- evidence from DragonflightUI-Reforged; every client-owned object remains
-- capability-checked because only MinimapZoomIn is named in official client
-- documentation and the other exact globals are not runtime-verified here.
local function DressModernWowMinimap()
  if modernWowMinimap.dressed then return false end
  if not ModernWow() then return false end

  local minimap = U.G("Minimap")
  local art = M.modernWow and M.modernWow.texture
  local layout = M.modernWow and M.modernWow.minimap
  if not minimap or not art or not layout then return false end

  HideStockChrome()

  local border = minimap:CreateTexture(nil, "OVERLAY")
  border:SetTexture(art.minimapBorder)
  border:SetPoint("TOPLEFT", minimap, "TOPLEFT",
    -layout.borderOffset, layout.borderOffset)
  border:SetPoint("BOTTOMRIGHT", minimap, "BOTTOMRIGHT",
    layout.borderOffset, -layout.borderOffset)

  local shadow = minimap:CreateTexture(nil, "BORDER")
  shadow:SetTexture(art.minimapShadow)
  shadow:SetPoint("TOPLEFT", minimap, "TOPLEFT",
    -layout.borderOffset, layout.borderOffset)
  shadow:SetPoint("BOTTOMRIGHT", minimap, "BOTTOMRIGHT",
    layout.borderOffset, -layout.borderOffset)
  shadow:SetAlpha(layout.shadowAlpha)

  local panel = CreateFrame("Frame", "PandaUIModernWowMinimapTopPanel", minimap)
  local width = 140
  local ok, liveWidth = pcall(minimap.GetWidth, minimap)
  if ok and type(liveWidth) == "number" and liveWidth > 0 then width = liveWidth end

  local squareBorder = minimap:CreateTexture(
    "PandaUIModernWowMinimapSquareBorder", "ARTWORK")
  squareBorder:SetTexture(art.minimapSquareFrame)
  squareBorder:SetPoint("TOPLEFT", minimap, "TOPLEFT",
                        -layout.squareBorderOffset,
                        layout.squareBorderOffset + layout.squareBorderYOffset)
  squareBorder:SetPoint("BOTTOMRIGHT", minimap, "BOTTOMRIGHT",
                        layout.squareBorderOffset,
                        -layout.squareBorderOffset + layout.squareBorderYOffset)
  squareBorder:Hide()

  panel:SetWidth(width)
  panel:SetHeight(layout.topPanelHeight)
  panel:SetPoint("BOTTOM", minimap, "TOP", 0, layout.topPanelGap)

  local panelArt = panel:CreateTexture(nil, "BACKGROUND")
  panelArt:SetTexture(art.minimapTopPanel)
  -- One anchor plus explicit size: the stretched two-point form did not
  -- visibly change the height in game (2026-09-14).
  panelArt:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT",
    0, -layout.topPanelBottomOverhang)
  panelArt:SetWidth(width + layout.topPanelRightOverhang)
  panelArt:SetHeight(layout.topPanelArtHeight)

  -- The zone name is an addon-owned label on the panel art. Reparenting the
  -- native MinimapZoneTextButton did not take on this client (2026-09-14: it
  -- was still a MinimapCluster child afterwards), so the native label is
  -- suppressed in HideStockChrome and this one reads GetMinimapZoneText
  -- (DOCUMENTED_NOT_RUNTIME_VERIFIED) -- the same source UnrealPfUI's working
  -- zone panel uses. No zone event is verified here, so a throttled refresh
  -- is the guarantee and the events are only a faster path.
  local artWidth = width + layout.topPanelRightOverhang
  local visibleBandWidth = artWidth *
    (layout.topPanelVisibleRight - layout.topPanelVisibleLeft) /
    layout.topPanelTexWidth
  local zoneLabel = U.CreateLabel(panel, {
    name = "PandaUIModernWowMinimapZoneText",
    inherits = "GameFontNormal",
    size = layout.zoneFontSize,
    color = layout.zoneColor,
    justify = "CENTER",
    width = visibleBandWidth - layout.zoneX * 2,
    exactSize = true,
  })
  if zoneLabel then
    -- Vertically centre on the art's visible band, derived from the measured
    -- texel rows and the art's drawn height.
    local artHeight = layout.topPanelArtHeight
    local bandCentreFromBottom = artHeight * (1 -
      (layout.topPanelVisibleTop + layout.topPanelVisibleBottom) /
      (2 * layout.topPanelTexHeight))
    local bandCentreX = artWidth *
      (layout.topPanelVisibleLeft + layout.topPanelVisibleRight) /
      (2 * layout.topPanelTexWidth)
    pcall(zoneLabel.SetPoint, zoneLabel, "CENTER", panel, "BOTTOMLEFT",
      bandCentreX,
      bandCentreFromBottom - layout.topPanelBottomOverhang + layout.zoneY)

    KeepZoneLabelFresh(zoneLabel, "minimap.modernwow.zone", layout.zoneRefresh)
    modernWowMinimap.zoneLabel = zoneLabel
  end

  local zoomIn = U.G("MinimapZoomIn")
  if zoomIn then
    pcall(zoomIn.SetParent, zoomIn, minimap)
    pcall(zoomIn.ClearAllPoints, zoomIn)
    pcall(zoomIn.SetPoint, zoomIn, "TOPLEFT", minimap, "BOTTOMRIGHT",
      layout.zoomX, layout.zoomY)
    pcall(zoomIn.SetScale, zoomIn, layout.zoomScale)
    DressZoomButton(zoomIn, art.minimapZoomIn, art.minimapZoomInOver,
      art.minimapZoomInPush, art.minimapZoomInOff)
  end

  local zoomOut = U.G("MinimapZoomOut")
  if zoomOut then
    pcall(zoomOut.SetParent, zoomOut, minimap)
    pcall(zoomOut.ClearAllPoints, zoomOut)
    if zoomIn then
      pcall(zoomOut.SetPoint, zoomOut, "TOPRIGHT", zoomIn, "BOTTOMLEFT", 0, 0)
    else
      pcall(zoomOut.SetPoint, zoomOut, "TOPLEFT", minimap, "BOTTOMRIGHT",
        layout.zoomX, layout.zoomY - 42.6)
    end
    pcall(zoomOut.SetScale, zoomOut, layout.zoomScale)
    DressZoomButton(zoomOut, art.minimapZoomOut, art.minimapZoomOutOver,
      art.minimapZoomOutPush, art.minimapZoomOutOff)
  end

  -- Only where the letter sits. Its art is the shared flipbook every theme
  -- draws (`mail` below), so nothing theme-specific is applied to the icon
  -- itself here.
  local mailFrame = U.G("MiniMapMailFrame")
  if mailFrame then
    pcall(mailFrame.ClearAllPoints, mailFrame)
    pcall(mailFrame.SetPoint, mailFrame, "TOPLEFT", panel, "BOTTOMLEFT",
      layout.mailX, layout.mailY)
  end

  modernWowMinimap.dressed = true
  modernWowMinimap.border = border
  modernWowMinimap.shadow = shadow
  modernWowMinimap.squareBorder = squareBorder
  modernWowMinimap.topPanel = panel
  ApplyModernWowShape()
  U.Debug("modern-wow minimap chrome applied")
  return true
end

-- ---------------------------------------------------------------------------
-- The pending-mail letter
--
-- Requested for every theme, not just modern-wow: the native envelope beside
-- the minimap is replaced by pandaUI's animated one (M.minimapMail), so the
-- letter folds itself shut when mail arrives and then keeps sparkling while it
-- is still waiting. MiniMapMailFrame stays the client-owned state and mouse
-- owner; the art is an addon-owned texture.
--
-- The focused minimapmail comparison verified that the 256x512 atlas travels
-- when SetTexCoord changes even on an addon-owned Texture, while the same 32
-- cells animate in place as separate files. Keep the visual parented to
-- UIParent and place it from bounded numeric geometry; a native object is never
-- retained as its relative anchor.
-- ---------------------------------------------------------------------------
local mail = { updateId = "minimap.mail", cell = 1, cellTime = 0 }

function mail.SetCell(index)
  local icon = mail.art
  if not icon then return end
  pcall(icon.SetTexture, icon,
    string.format(M.minimapMail.framePattern, index))
end

function mail.HideNativeArt()
  U.HideRegion(U.G("MiniMapMailIcon"))
  U.HideRegion(U.G("MiniMapMailBorder"))
end

function mail.Place(frame)
  local visual = mail.visual
  if not visual or not frame then return false end

  local leftOk, left = pcall(frame.GetLeft, frame)
  local bottomOk, bottom = pcall(frame.GetBottom, frame)
  local widthOk, width = pcall(frame.GetWidth, frame)
  local heightOk, height = pcall(frame.GetHeight, frame)
  if not leftOk or not bottomOk or not widthOk or not heightOk or
     type(left) ~= "number" or type(bottom) ~= "number" or
     type(width) ~= "number" or type(height) ~= "number" then
    return false
  end

  local cfg = M.minimapMail
  local x = left + (width - cfg.size) / 2
  local y = bottom + (height - cfg.size) / 2
  if x == mail.x and y == mail.y then return true end
  mail.x, mail.y = x, y
  pcall(visual.ClearAllPoints, visual)
  pcall(visual.SetPoint, visual, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
  return true
end

-- Run on every hidden -> visible transition: restarts the intro, and re-asserts
-- the two things a native refresh is able to put back.
function mail.Rewind()
  mail.HideNativeArt()
  pcall(mail.visual.Show, mail.visual)
  mail.cell = 1
  mail.cellTime = 0
  mail.lastTick = GetTime()
  mail.SetCell(mail.cell)
end

function mail.Tick()
  local frame = U.G("MiniMapMailFrame")
  if not frame then
    mail.shown = false
    pcall(mail.visual.Hide, mail.visual)
    return
  end

  mail.HideNativeArt()
  local ok, visible = pcall(frame.IsVisible, frame)
  if not ok or not visible then
    mail.shown = false
    pcall(mail.visual.Hide, mail.visual)
    return
  end

  if not mail.Place(frame) then
    pcall(mail.visual.Hide, mail.visual)
    mail.shown = false
    return
  end

  if not mail.shown then
    mail.shown = true
    mail.Rewind()
    return
  end

  -- Stepped off elapsed time rather than one cell per fire, so a frame the
  -- shared driver skips under load costs the animation its timing and not its
  -- position. The clamp keeps a long stall (a loading screen) from fast-
  -- forwarding through several cycles at once.
  local now = GetTime()
  local elapsed = now - (mail.lastTick or now)
  mail.lastTick = now
  if elapsed < 0 then elapsed = 0 end
  if elapsed > 0.25 then elapsed = 0.25 end

  local cfg = M.minimapMail
  mail.cellTime = mail.cellTime + elapsed
  while mail.cellTime >= cfg.interval do
    mail.cellTime = mail.cellTime - cfg.interval
    mail.cell = mail.cell + 1
    -- The intro is played once per arrival; the loop is what repeats.
    if mail.cell > cfg.frames then mail.cell = cfg.intro + 1 end
    mail.SetCell(mail.cell)
  end
end

local function DressMailIcon()
  local frame = U.G("MiniMapMailFrame")
  if not frame then
    U.Debug("minimap: no MiniMapMailFrame; mail letter left native")
    return false
  end

  local cfg = M.minimapMail
  local visual = CreateFrame("Frame", "PandaUIMinimapMail", UIParent)
  visual:SetWidth(cfg.size)
  visual:SetHeight(cfg.size)
  pcall(visual.EnableMouse, visual, false)

  local art = visual:CreateTexture("PandaUIMinimapMailArt", "ARTWORK")
  art:SetAllPoints(visual)
  mail.visual = visual
  mail.art = art

  mail.Place(frame)
  mail.HideNativeArt()
  mail.SetCell(mail.cell)
  visual:Hide()

  U.RegisterUpdate(mail.updateId, cfg.interval, mail.Tick)
  U.Debug("minimap: mail letter drawn from separate frame textures")
  return true
end

-- ---------------------------------------------------------------------------
-- Icons around the minimap
--
-- Every icon on the minimap ring can be dragged along it (user request,
-- 2026-10-22): the native tracking, mail, battleground, meeting-stone icons,
-- the Turtle battleground/shop/LFT buttons and pandaUI's settings button. The
-- angle is saved per frame name in the module config. An icon never dragged
-- keeps the place the client or the active theme gave it, and /pui reset puts
-- every icon back there. The 1.12 globals cos, sin and atan2 work in degrees
-- (WORKING_SOURCE: pandaConquest's ring button on this client).
--
-- The drag runs from one addon frame's OnUpdate, never the icon's own:
-- LFTMinimapButton animates its eye through its OnUpdate. The icons' own
-- drag scripts are replaced -- the Turtle buttons free-move to any screen
-- spot, and LFT re-parents itself to UIParent on drop.
-- ---------------------------------------------------------------------------
local RING_ICONS = {
  "PandaUISettingsButton", "PandaUIGroupButton",
  "MiniMapTrackingFrame", "MiniMapMailFrame", "MiniMapBattlefieldFrame",
  "MiniMapMeetingStoneFrame", "TWMiniMapBattlefieldFrame",
  "TWMinimapShopFrame", "LFTMinimapButton",
}
local SETTINGS_NAME = "PandaUISettingsButton"
local GROUP_NAME = "PandaUIGroupButton"
-- Left of the map, between the native icons and the settings button.
local GROUP_DEFAULT_ANGLE = 180
local FLYOUT_PAD = 6
local FLYOUT_GAP = 4
local GROUP_MENU_WIDTH = 240
local GROUP_MENU_ROW_HEIGHT = 20
local GROUP_MENU_FRAME_LEVEL = 80
-- Bottom-left, the usual minimap-button spot; no native icon starts there.
local SETTINGS_DEFAULT_ANGLE = 225
-- Icon centres sit this far outside the map's edge, like the native icons.
local RING_OUTSET = 10

local ring = { hooked = {}, original = {}, dragging = nil, stoppedAt = nil }
-- The icon group and its flyout (see "Grouped icons").
local group = {}

function ring.Angles()
  local cfg = U.ModuleConfig("minimap", { enabled = true, iconAngles = {} })
  if type(cfg.iconAngles) ~= "table" then cfg.iconAngles = {} end
  return cfg.iconAngles
end

function ring.Place(frame, angle)
  local minimap = U.G("Minimap")
  local cos, sin = U.G("cos"), U.G("sin")
  if not frame or not minimap or type(angle) ~= "number" or
     type(cos) ~= "function" or type(sin) ~= "function" then
    return false
  end

  local width = 140
  local ok, liveWidth = pcall(minimap.GetWidth, minimap)
  if ok and type(liveWidth) == "number" and liveWidth > 0 then width = liveWidth end
  local x, y = cos(angle), sin(angle)
  local radius = width / 2 + RING_OUTSET
  if SquareMinimap() then
    local edge = math.max(math.abs(x), math.abs(y))
    if edge > 0 then radius = radius / edge end
  end

  -- SetPoint offsets are in the icon's own scale, and the Turtle buttons are
  -- UIParent children rather than Minimap children.
  local mapOk, mapScale = pcall(minimap.GetEffectiveScale, minimap)
  local ownOk, ownScale = pcall(frame.GetEffectiveScale, frame)
  if mapOk and ownOk and type(mapScale) == "number" and
     type(ownScale) == "number" and ownScale > 0 then
    radius = radius * mapScale / ownScale
  end

  pcall(frame.ClearAllPoints, frame)
  return pcall(frame.SetPoint, frame, "CENTER", minimap, "CENTER",
    radius * x, radius * y)
end

-- The cursor's angle around the minimap centre, in [0, 360).
function ring.CursorAngle()
  local minimap, atan2 = U.G("Minimap"), U.G("atan2")
  if not minimap or type(atan2) ~= "function" or
     type(GetCursorPosition) ~= "function" then
    return nil
  end
  local x, y = GetCursorPosition()
  local scaleOk, scale = pcall(minimap.GetEffectiveScale, minimap)
  local centerOk, cx, cy = pcall(minimap.GetCenter, minimap)
  if type(x) ~= "number" or type(y) ~= "number" or not scaleOk or
     not centerOk or type(cx) ~= "number" or type(cy) ~= "number" or
     type(scale) ~= "number" or scale <= 0 then
    return nil
  end
  return math.mod(atan2(y / scale - cy, x / scale - cx) + 360, 360)
end

function ring.Update()
  local frame = ring.dragging
  if not frame then return end
  local angle = ring.CursorAngle()
  if not angle then return end
  angle = math.mod(math.floor(angle + 0.5), 360)
  if angle ~= ring.dragAngle and ring.Place(frame, angle) then
    ring.dragAngle = angle
  end
end

function ring.StartDrag(frame)
  -- An icon inside the flyout has no rim place to be dragged along.
  if group.IsGrouped(frame) then return end
  ring.dragging = frame
  ring.dragAngle = nil
  pcall(frame.LockHighlight, frame)
  if not ring.driver then
    ring.driver = CreateFrame("Frame", nil, UIParent)
    ring.driver:SetScript("OnUpdate", ring.Update)
  end
  ring.driver:Show()
end

function ring.StopDrag(frame)
  if ring.dragging ~= frame then return end
  ring.dragging = nil
  ring.stoppedAt = GetTime()
  if ring.driver then ring.driver:Hide() end
  pcall(frame.UnlockHighlight, frame)
  -- Keeps the client's layout cache from restoring an old free-moved spot.
  pcall(frame.SetUserPlaced, frame, false)
  local ok, name = pcall(frame.GetName, frame)
  if ring.dragAngle and ok and name then ring.Angles()[name] = ring.dragAngle end
end

-- Whether the click arriving now is the release of a drag. GetTime is updated
-- once per UI draw (api.json / core.time.v1), so a release in the same frame
-- as the drop reads an identical stamp.
function ring.ClickEndedADrag()
  if ring.dragging then return true end
  return ring.stoppedAt ~= nil and (GetTime() - ring.stoppedAt) < 0.02
end

-- Wraps an icon's click script so releasing a drag does not also click it.
-- The original reads this/arg1 from globals, which are still set here.
function ring.GuardScript(frame, script)
  local ok, original = pcall(frame.GetScript, frame, script)
  if not ok or type(original) ~= "function" then return end
  pcall(frame.SetScript, frame, script, function()
    if ring.ClickEndedADrag() then return end
    original()
  end)
end

-- A frame's anchors as SetPoint tuples. GetPoint returns the tuple SetPoint
-- was given (frames.getpoint_y_same_sign_as_setpoint).
function ring.ReadPoints(frame)
  local points = {}
  local countOk, count = pcall(frame.GetNumPoints, frame)
  if not countOk or type(count) ~= "number" then count = 0 end
  local i
  for i = 1, count do
    local pointOk, point, relative, relativePoint, x, y = pcall(frame.GetPoint, frame, i)
    if pointOk and point then
      table.insert(points, { point, relative, relativePoint, x, y })
    end
  end
  return points
end

function ring.SetPoints(frame, points)
  if not frame or not points or table.getn(points) == 0 then return end
  pcall(frame.ClearAllPoints, frame)
  local i
  for i = 1, table.getn(points) do
    pcall(frame.SetPoint, frame, unpack(points[i]))
  end
end

function ring.Hook(frame)
  local ok, name = pcall(frame.GetName, frame)
  if not ok or not name or ring.hooked[name] then return false end

  -- Where the client or the theme put it, re-applied by /pui reset.
  local points = ring.ReadPoints(frame)

  if not pcall(frame.RegisterForDrag, frame, "LeftButton") then
    U.Debug("minimap ring: RegisterForDrag failed on " .. name)
    return false
  end
  pcall(frame.SetScript, frame, "OnDragStart", function() ring.StartDrag(frame) end)
  pcall(frame.SetScript, frame, "OnDragStop", function() ring.StopDrag(frame) end)
  ring.GuardScript(frame, "OnClick")
  ring.GuardScript(frame, "OnMouseUp")

  ring.original[name] = points
  ring.hooked[name] = true
  return true
end

function ring.ApplySaved()
  local angles = ring.Angles()
  local i
  for i = 1, table.getn(RING_ICONS) do
    local name = RING_ICONS[i]
    local angle = tonumber(angles[name])
    if ring.hooked[name] and angle and not group.saved[name] then
      ring.Place(U.G(name), angle)
    end
  end
end

function ring.FrameAngle(frame)
  local minimap, atan2 = U.G("Minimap"), U.G("atan2")
  if not frame or not minimap or type(atan2) ~= "function" then return nil end
  local ownOk, x, y = pcall(frame.GetCenter, frame)
  local mapOk, mapX, mapY = pcall(minimap.GetCenter, minimap)
  local ownScaleOk, ownScale = pcall(frame.GetEffectiveScale, frame)
  local mapScaleOk, mapScale = pcall(minimap.GetEffectiveScale, minimap)
  if not ownOk or not mapOk or not ownScaleOk or not mapScaleOk or
     type(x) ~= "number" or type(y) ~= "number" or
     type(mapX) ~= "number" or type(mapY) ~= "number" or
     type(ownScale) ~= "number" or type(mapScale) ~= "number" then
    return nil
  end
  return math.mod(atan2(y * ownScale - mapY * mapScale,
                        x * ownScale - mapX * mapScale) + 360, 360)
end

function ring.Reflow()
  local angles = ring.Angles()
  local i
  for i = 1, table.getn(RING_ICONS) do
    local name = RING_ICONS[i]
    if ring.hooked[name] and not (group.saved and group.saved[name]) then
      local frame = U.G(name)
      local angle = tonumber(angles[name]) or ring.FrameAngle(frame)
      if angle then ring.Place(frame, angle) end
    end
  end
end

function ring.RestoreCircle()
  local angles = ring.Angles()
  local i
  for i = 1, table.getn(RING_ICONS) do
    local name = RING_ICONS[i]
    if ring.hooked[name] and not (group.saved and group.saved[name]) then
      local frame = U.G(name)
      local angle = tonumber(angles[name])
      if angle then
        ring.Place(frame, angle)
      else
        ring.SetPoints(frame, ring.original[name])
      end
    end
  end
end

function ring.ApplyShape()
  if SquareMinimap() then ring.Reflow() else ring.RestoreCircle() end
end

function ring.Reset()
  local angles = ring.Angles()
  local i
  -- Grouped icons go back onto the map first, so every icon is reset to its
  -- native spot; the group is then rebuilt from the same choices.
  group.ReleaseAll()
  for i = 1, table.getn(RING_ICONS) do
    local name = RING_ICONS[i]
    angles[name] = nil
    ring.SetPoints(U.G(name), ring.original[name])
  end
  group.Apply()
  return true
end

function ring.Setup()
  local hooked = 0
  local i
  for i = 1, table.getn(RING_ICONS) do
    local frame = U.G(RING_ICONS[i])
    if frame and ring.Hook(frame) then hooked = hooked + 1 end
  end
  ring.ApplyShape()
  -- The client can re-apply a user-placed spot from its layout cache after
  -- login, so the saved angles are asserted again on entering the world.
  U.RegisterEvent("PLAYER_ENTERING_WORLD", ring.ApplyShape)
  U.OnPositionReset(ring.Reset)
  U.Debug("minimap ring: " .. hooked .. " icons draggable around the minimap")
end

-- ---------------------------------------------------------------------------
-- Grouped icons (roadmap item, optional)
--
-- With "Group minimap icons" on, the chosen icons are re-parented into one
-- flyout that a single launcher icon on the rim opens. Candidates are the ring
-- icons above plus other addons' minimap buttons, found the way pfUI-octo's
-- addonbuttons module finds them (WORKING_112_SOURCE): named Minimap and
-- MinimapBackdrop children up to 40px with a click or mouse script. The
-- Minimap settings and the launcher's right-click menu pick the members;
-- config ungrouped[name] keeps an icon on the map. The icons stay their
-- owners' frames: parent, strata, level and anchors are saved on capture and
-- all restored on release
-- (knowledge.json / minimap.icon_grouping_flyout_unverified).
-- ---------------------------------------------------------------------------
local ADDON_BUTTON_MAX = 40
local FLYOUT_COLUMNS = 6
-- Name prefixes of Minimap children that are not icons to group: map pins and
-- notes (pfUI-octo's ignore list), the map's own controls and this suite's
-- own frames.
local NOT_ICONS = {
  "note", "jquest", "naut_", "minimapicon", "gathermatepin", "westpointer",
  "chinchilla_", "smartminimapzoom", "questienote", "smm", "pfminimappin",
  "gathernote", "mininotepoi", "fwgminimappoi", "reciperadarminimapicon",
  "cartographernotespoi", "minimapzoom", "minimapping", "minimaptoggle",
  "minimapworldmap", "minimapbackdrop", "pandaui", "pandaquest",
}
-- Labels for the client's own icons; any other icon shows its frame name.
local ICON_LABELS = {
  MiniMapTrackingFrame = "MINIMAP_ICON_TRACKING",
  MiniMapMailFrame = "MINIMAP_ICON_MAIL",
  MiniMapBattlefieldFrame = "MINIMAP_ICON_BATTLEFIELD",
  MiniMapMeetingStoneFrame = "MINIMAP_ICON_MEETING_STONE",
  TWMiniMapBattlefieldFrame = "MINIMAP_ICON_BATTLEFIELD",
  TWMinimapShopFrame = "MINIMAP_ICON_SHOP",
  LFTMinimapButton = "MINIMAP_ICON_GROUP_FINDER",
}

group.saved = {}
group.found = {}

function group.Config()
  local cfg = U.ModuleConfig("minimap", { enabled = true })
  if type(cfg.ungrouped) ~= "table" then cfg.ungrouped = {} end
  return cfg
end

function group.IsGrouped(frame)
  local ok, name = pcall(frame.GetName, frame)
  return ok and name ~= nil and group.saved[name] ~= nil
end

function group.IsRingIcon(name)
  local i
  for i = 1, table.getn(RING_ICONS) do
    if RING_ICONS[i] == name then return true end
  end
  return false
end

-- Whether a Minimap child looks like an addon's minimap button.
function group.LooksLikeButton(frame)
  local ok, name = pcall(frame.GetName, frame)
  if not ok or type(name) ~= "string" or group.IsRingIcon(name) then return false end
  local lower = string.lower(name)
  local i
  for i = 1, table.getn(NOT_ICONS) do
    if string.find(lower, NOT_ICONS[i], 1, true) == 1 then return false end
  end
  local wOk, width = pcall(frame.GetWidth, frame)
  local hOk, height = pcall(frame.GetHeight, frame)
  if not wOk or not hOk or type(width) ~= "number" or type(height) ~= "number" or
     width > ADDON_BUTTON_MAX or height > ADDON_BUTTON_MAX then
    return false
  end
  local isButton = pcall(frame.IsFrameType, frame, "Button") and frame:IsFrameType("Button")
  local function Has(script)
    local scriptOk, handler = pcall(frame.GetScript, frame, script)
    return scriptOk and type(handler) == "function"
  end
  if isButton then
    return Has("OnClick") or Has("OnMouseDown") or Has("OnMouseUp")
  end
  if string.find(lower, "icon", 1, true) or string.find(lower, "button", 1, true) then
    return Has("OnMouseDown") or Has("OnMouseUp")
  end
  return false
end

-- Adds newly created addon buttons to group.found. Buttons already captured
-- are flyout children now, so they are never lost from the list.
function group.Scan()
  local holders = { U.G("Minimap"), U.G("MinimapBackdrop") }
  local known = {}
  local i, j
  for i = 1, table.getn(group.found) do known[group.found[i]] = true end
  for i = 1, table.getn(holders) do
    local holder = holders[i]
    local ok, children = false, nil
    if holder then ok, children = pcall(function() return { holder:GetChildren() } end) end
    if ok and type(children) == "table" then
      for j = 1, table.getn(children) do
        local child = children[j]
        if group.LooksLikeButton(child) then
          local name = child:GetName()
          if not known[name] then
            known[name] = true
            table.insert(group.found, name)
          end
        end
      end
    end
  end
end

-- Every icon the player can put in the group, ring icons first.
function group.Candidates()
  local list = {}
  local i
  for i = 1, table.getn(RING_ICONS) do
    local name = RING_ICONS[i]
    if name ~= SETTINGS_NAME and name ~= GROUP_NAME and ring.hooked[name] then
      table.insert(list, name)
    end
  end
  for i = 1, table.getn(group.found) do
    if U.G(group.found[i]) then table.insert(list, group.found[i]) end
  end
  return list
end

function group.Label(name)
  local key = ICON_LABELS[name]
  if key then return U.L(key) end
  -- LibDBIcon-style names carry a library prefix before the addon name.
  local short = string.gsub(name, "^LibDBIcon10_", "")
  return short
end

function group.Build()
  if group.flyout then return group.flyout end
  local flyout = U.CreatePanel(UIParent, {
    name = "PandaUIGroupFlyout", width = 100, height = 40,
    background = M.modernWow.dropdown.unitPopupListFill,
    border = false,
    textureFill = true,
  })
  group.StyleMenu(flyout)
  pcall(flyout.SetFrameStrata, flyout, "DIALOG")
  pcall(flyout.EnableMouse, flyout, true)
  pcall(flyout.SetClampedToScreen, flyout, true)
  flyout:SetScript("OnShow", function() group.Layout() end)
  flyout:Hide()
  local special = U.G("UISpecialFrames")
  if type(special) == "table" then
    table.insert(special, "PandaUIGroupFlyout")
  end
  group.flyout = flyout
  return flyout
end

-- The same Modern WoW framed menu as the unit and party right-click menus.
-- Its fill is inset before the shared ThinBorder is built, so it cannot show
-- through the rim's transparent outer pixels or rounded corners.
function group.StyleMenu(menu)
  if not menu or menu.puiGroupMenuStyled then return end
  menu.puiGroupMenuStyled = true
  local borderSize = M.modernWow.dropdown.borderSize
  if menu.puiFill then
    U.SetColor(menu.puiFill, M.Unpack(M.modernWow.dropdown.unitPopupListFill))
    if type(U.ModernWowThinBorderFill) == "function" then
      U.ModernWowThinBorderFill(menu.puiFill, menu, borderSize)
    end
  end
  if type(U.ModernWowBuildThinBorder) == "function" then
    U.ModernWowBuildThinBorder(menu, borderSize)
  end
end

-- The textured checkbox painter clears the row's old flat hover backdrop, so
-- the membership list owns a simple hover fill above that retired backdrop.
function group.StyleMenuRow(control)
  local row = control and control.row
  if not row or row.puiGroupMenuHover then return end
  local hover = row:CreateTexture(nil, "BACKGROUND")
  if not hover then return end
  hover:SetTexture(M.texture.plain)
  hover:SetAllPoints(row)
  local color = M.foreverWow.list.hover.color
  U.SetColor(hover, M.Unpack(color))
  hover:Hide()
  row.puiGroupMenuHover = hover
  U.PostHookScript(row, "OnEnter", function()
    if control.enabled then hover:Show() end
  end)
  U.PostHookScript(row, "OnLeave", function() hover:Hide() end)
end

-- A screen-sized button below the menu absorbs the next outside click. The
-- menu remains above it at the same DIALOG strata, so icon rows stay usable.
function group.BuildMenuClickCatcher()
  if group.menuClickCatcher then return group.menuClickCatcher end
  local catcher = CreateFrame("Button", "PandaUIGroupMenuClickCatcher", UIParent)
  pcall(catcher.SetAllPoints, catcher, UIParent)
  pcall(catcher.SetFrameStrata, catcher, "DIALOG")
  pcall(catcher.SetFrameLevel, catcher, GROUP_MENU_FRAME_LEVEL - 1)
  pcall(catcher.EnableMouse, catcher, true)
  pcall(catcher.RegisterForClicks, catcher, "LeftButtonUp", "RightButtonUp")
  catcher:SetScript("OnClick", function()
    if group.menu then group.menu:Hide() end
  end)
  catcher:Hide()
  group.menuClickCatcher = catcher
  return catcher
end

-- Right-clicking the group launcher opens a compact membership list. Ticked
-- icons live in the flyout; unticked icons are restored to the minimap rim.
function group.BuildMenu()
  if group.menu then return group.menu end
  local menu = U.CreatePanel(UIParent, {
    name = "PandaUIGroupMenu", width = GROUP_MENU_WIDTH, height = 12,
    background = M.modernWow.dropdown.unitPopupListFill,
    border = false,
    textureFill = true,
  })
  group.StyleMenu(menu)
  pcall(menu.SetFrameStrata, menu, "DIALOG")
  pcall(menu.SetFrameLevel, menu, GROUP_MENU_FRAME_LEVEL)
  pcall(menu.EnableMouse, menu, true)
  pcall(menu.SetClampedToScreen, menu, true)
  menu.rows = {}
  group.BuildMenuClickCatcher()
  menu:SetScript("OnShow", function()
    group.RefreshMenu()
    if group.menuClickCatcher then group.menuClickCatcher:Show() end
  end)
  menu:SetScript("OnHide", function()
    if group.menuClickCatcher then group.menuClickCatcher:Hide() end
  end)
  menu:Hide()
  local special = U.G("UISpecialFrames")
  if type(special) == "table" then
    table.insert(special, "PandaUIGroupMenu")
  end
  group.menu = menu
  return menu
end

function group.RefreshMenu()
  local menu = group.menu
  if not menu then return end

  group.Scan()
  local cfg = group.Config()
  local candidates = group.Candidates()
  local visible = {}
  local count = 0
  local i
  for i = 1, table.getn(candidates) do
    local name = candidates[i]
    local control = menu.rows[name]
    if not control then
      local boxSize = 12
      if type(U.GameSettingsCheckboxSize) == "function" then
        local size = U.GameSettingsCheckboxSize()
        if type(size) == "number" then boxSize = size end
      end
      control = U.CreateCheckbox(menu, {
        size = boxSize,
        rowHover = true,
        rowWidth = GROUP_MENU_WIDTH - 12,
        rowHeight = GROUP_MENU_ROW_HEIGHT,
        text = group.Label(name),
        textWidth = GROUP_MENU_WIDTH - 34,
        value = not cfg.ungrouped[name],
        onChange = function(value)
          group.Config().ungrouped[name] = (not value) and true or nil
          group.Apply()
        end,
      })
      if type(U.StyleGameSettingsCheckbox) == "function" then
        U.StyleGameSettingsCheckbox(control)
      end
      group.StyleMenuRow(control)
      menu.rows[name] = control
    end

    visible[name] = true
    count = count + 1
    if control.label then control.label:SetText(group.Label(name)) end
    control.SetValue(not cfg.ungrouped[name])
    if control.row and control.row.puiGroupMenuHover then
      control.row.puiGroupMenuHover:Hide()
    end
    if control.row then
      control.row:ClearAllPoints()
      control.row:SetPoint("TOPLEFT", menu, "TOPLEFT", 6,
                           -6 - (count - 1) * GROUP_MENU_ROW_HEIGHT)
      control.row:Show()
    end
  end

  local name, control
  for name, control in pairs(menu.rows) do
    if not visible[name] and control.row then control.row:Hide() end
  end
  menu:SetHeight(12 + count * GROUP_MENU_ROW_HEIGHT)
end

function group.ShowMenu()
  local menu = group.BuildMenu()
  group.RefreshMenu()
  if group.flyout then group.flyout:Hide() end

  -- Match the flyout's scale when the player has resized the minimap.
  local minimap = U.G("Minimap")
  if minimap then
    local mapOk, mapScale = pcall(minimap.GetEffectiveScale, minimap)
    local uiOk, uiScale = pcall(UIParent.GetEffectiveScale, UIParent)
    if mapOk and uiOk and type(mapScale) == "number" and
       type(uiScale) == "number" and uiScale > 0 then
      pcall(menu.SetScale, menu, mapScale / uiScale)
    end
  end

  local launcher = group.launcher
  local below = false
  local ok, _, cy = pcall(launcher.GetCenter, launcher)
  local scaleOk, scale = pcall(launcher.GetEffectiveScale, launcher)
  local uiOk, uiScale = pcall(UIParent.GetEffectiveScale, UIParent)
  if ok and scaleOk and uiOk and type(cy) == "number" and
     type(scale) == "number" and type(uiScale) == "number" then
    below = cy * scale > UIParent:GetHeight() * uiScale / 2
  end
  menu:ClearAllPoints()
  if below then
    menu:SetPoint("TOPRIGHT", launcher, "BOTTOMRIGHT", 0, -2)
  else
    menu:SetPoint("BOTTOMRIGHT", launcher, "TOPRIGHT", 0, 2)
  end
  menu:Show()
end

-- Lays the members the client currently shows in rows, then hangs the flyout
-- off the launcher on the side facing the middle of the screen.
function group.Layout()
  local flyout, launcher = group.flyout, group.launcher
  if not flyout or not launcher then return end

  local shown = {}
  local candidates = group.Candidates()
  local i
  for i = 1, table.getn(candidates) do
    local frame = group.saved[candidates[i]] and U.G(candidates[i])
    if frame and frame:IsShown() then table.insert(shown, frame) end
  end
  local count = table.getn(shown)
  if count == 0 then
    flyout:Hide()
    return
  end

  -- Same scale the icons had on the minimap.
  local minimap = U.G("Minimap")
  if minimap then
    local mapOk, mapScale = pcall(minimap.GetEffectiveScale, minimap)
    local uiOk, uiScale = pcall(UIParent.GetEffectiveScale, UIParent)
    if mapOk and uiOk and type(mapScale) == "number" and
       type(uiScale) == "number" and uiScale > 0 then
      pcall(flyout.SetScale, flyout, mapScale / uiScale)
    end
  end

  local columns = math.min(count, FLYOUT_COLUMNS)
  local rows = math.ceil(count / FLYOUT_COLUMNS)
  local cell = BUTTON_SIZE + FLYOUT_GAP
  flyout:SetWidth(FLYOUT_PAD * 2 + columns * cell - FLYOUT_GAP)
  flyout:SetHeight(FLYOUT_PAD * 2 + rows * cell - FLYOUT_GAP)
  local level = flyout:GetFrameLevel()
  for i = 1, count do
    local frame = shown[i]
    local row = math.floor((i - 1) / FLYOUT_COLUMNS)
    local column = (i - 1) - row * FLYOUT_COLUMNS
    pcall(frame.SetFrameLevel, frame, level + 2)
    pcall(frame.ClearAllPoints, frame)
    pcall(frame.SetPoint, frame, "CENTER", flyout, "TOPLEFT",
      FLYOUT_PAD + column * cell + BUTTON_SIZE / 2,
      -(FLYOUT_PAD + row * cell + BUTTON_SIZE / 2))
  end

  local below = false
  local ok, _, cy = pcall(launcher.GetCenter, launcher)
  local scaleOk, scale = pcall(launcher.GetEffectiveScale, launcher)
  local uiOk, uiScale = pcall(UIParent.GetEffectiveScale, UIParent)
  if ok and scaleOk and uiOk and type(cy) == "number" and
     type(scale) == "number" and type(uiScale) == "number" then
    below = cy * scale > UIParent:GetHeight() * uiScale / 2
  end
  flyout:ClearAllPoints()
  if below then
    flyout:SetPoint("TOPRIGHT", launcher, "BOTTOMRIGHT", 0, -2)
  else
    flyout:SetPoint("BOTTOMRIGHT", launcher, "TOPRIGHT", 0, 2)
  end
end

function group.Capture(name)
  local frame = U.G(name)
  if not frame or group.saved[name] then return end
  local ok, parent = pcall(frame.GetParent, frame)
  if not ok or not parent then return end
  local state = { parent = parent, points = ring.ReadPoints(frame) }
  local strataOk, strata = pcall(frame.GetFrameStrata, frame)
  if strataOk then state.strata = strata end
  local levelOk, level = pcall(frame.GetFrameLevel, frame)
  if levelOk then state.level = level end
  -- Another addon's own drag would move its button out of the flyout.
  if not ring.hooked[name] then
    local startOk, start = pcall(frame.GetScript, frame, "OnDragStart")
    local stopOk, stop = pcall(frame.GetScript, frame, "OnDragStop")
    if startOk then state.dragStart = start end
    if stopOk then state.dragStop = stop end
    pcall(frame.SetScript, frame, "OnDragStart", nil)
    pcall(frame.SetScript, frame, "OnDragStop", nil)
  end
  group.saved[name] = state
  pcall(frame.SetParent, frame, group.flyout)
end

function group.Release(name)
  local frame = U.G(name)
  local state = group.saved[name]
  group.saved[name] = nil
  if not frame or not state then return end
  pcall(frame.SetParent, frame, state.parent)
  if state.strata then pcall(frame.SetFrameStrata, frame, state.strata) end
  if state.level then pcall(frame.SetFrameLevel, frame, state.level) end
  if not ring.hooked[name] then
    pcall(frame.SetScript, frame, "OnDragStart", state.dragStart)
    pcall(frame.SetScript, frame, "OnDragStop", state.dragStop)
  end
  local angle = ring.hooked[name] and tonumber(ring.Angles()[name])
  if angle then
    ring.Place(frame, angle)
  else
    ring.SetPoints(frame, state.points)
  end
  -- Moved out of the hidden flyout, a shown icon stays invisible under its
  -- visible parent until it is shown again (probe minimapgroup.v1:
  -- IsShown true, IsVisible false; knowledge.json /
  -- minimap.icon_grouping_flyout_unverified).
  local shownOk, shown = pcall(frame.IsShown, frame)
  if shownOk and shown then
    pcall(frame.Hide, frame)
    pcall(frame.Show, frame)
  end
end

function group.ReleaseAll()
  local names = {}
  for name in pairs(group.saved) do table.insert(names, name) end
  local i
  for i = 1, table.getn(names) do group.Release(names[i]) end
end

function group.Apply()
  if not group.launcher then return end
  local cfg = group.Config()
  local on = cfg.groupIcons and true or false
  if on then
    group.Build()
    group.Scan()
  end

  local candidates = group.Candidates()
  local i
  for i = 1, table.getn(candidates) do
    local name = candidates[i]
    if on and not cfg.ungrouped[name] then
      group.Capture(name)
    elseif group.saved[name] then
      group.Release(name)
    end
  end

  if on then
    group.launcher:Show()
    if group.flyout:IsShown() then group.Layout() end
  else
    group.launcher:Hide()
    if group.flyout then group.flyout:Hide() end
    if group.menu then group.menu:Hide() end
  end
end
U.ApplyMinimapGroup = function() group.Apply() end

function U.RefreshMinimapShapeGeometry()
  group.Apply()
  ring.ApplyShape()
  if type(U.ApplyMinimapArrowShape) == "function" then
    U.ApplyMinimapArrowShape()
  end
end

-- For the settings page: { name, label } per candidate, scanned fresh.
function U.MinimapGroupCandidates()
  group.Scan()
  local list = {}
  local candidates = group.Candidates()
  local i
  for i = 1, table.getn(candidates) do
    table.insert(list, { name = candidates[i], label = group.Label(candidates[i]) })
  end
  return list
end

function group.CreateLauncher(minimap)
  local button = CreateFrame("Button", GROUP_NAME, minimap or UIParent)
  button:SetWidth(BUTTON_SIZE)
  button:SetHeight(BUTTON_SIZE)
  pcall(button.EnableMouse, button, true)
  if minimap then
    local ok, level = pcall(minimap.GetFrameLevel, minimap)
    if ok and type(level) == "number" then
      pcall(button.SetFrameLevel, button, level + 5)
    end
  end

  -- The native icon build: a small face under the stock tracking ring.
  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetWidth(20)
  icon:SetHeight(20)
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
  pcall(icon.SetTexture, icon, "Interface\\Icons\\INV_Misc_Gear_01")
  pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetWidth(52)
  border:SetHeight(52)
  border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  pcall(border.SetTexture, border, "Interface\\Minimap\\MiniMap-TrackingBorder")
  if pcall(button.SetHighlightTexture, button, MINIMAP_HIGHLIGHT) then
    local ok, glow = pcall(button.GetHighlightTexture, button)
    if ok and glow then
      pcall(glow.SetAllPoints, glow, button)
      pcall(glow.SetBlendMode, glow, "ADD")
    end
  end

  pcall(button.RegisterForClicks, button, "LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", function()
    if arg1 == "RightButton" then
      group.ShowMenu()
      return
    end
    if group.menu then group.menu:Hide() end
    local flyout = group.Build()
    if flyout:IsShown() then flyout:Hide() else flyout:Show() end
  end)

  local angle = tonumber(ring.Angles()[GROUP_NAME]) or GROUP_DEFAULT_ANGLE
  if not ring.Place(button, angle) and minimap then
    button:SetPoint("CENTER", minimap, "CENTER", 0, 0)
  end
  button:Hide()
  group.launcher = button
end

-- The settings button's first place: its saved angle, else bottom-left. The
-- fallbacks below only apply when the minimap or the trig globals are missing.
local function AnchorButton(button)
  pcall(button.ClearAllPoints, button)

  local angle = tonumber(ring.Angles()[SETTINGS_NAME]) or SETTINGS_DEFAULT_ANGLE
  if ring.Place(button, angle) then
    return "Minimap ring at " .. angle
  end

  local cluster = U.G("MinimapCluster")
  if cluster then
    button:SetPoint("TOPRIGHT", cluster, "TOPLEFT", -6, -6)
    return "MinimapCluster"
  end

  -- No minimap to sit beside: park it in the corner rather than not existing.
  button:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -8, -8)
  return "UIParent (no minimap found)"
end

-- MinimapCluster is preferred: it is the whole native unit (map plus its
-- attached chrome) and its default anchor is measured. A bare Minimap fallback
-- carries no default -- its own point is only known from a pfUI-influenced
-- snapshot, not trustworthy as this client's un-modded native anchor -- so
-- Reset simply leaves it wherever it already is in that rare case.
local function ResolveMoverTarget()
  local cluster = U.G("MinimapCluster")
  if cluster then
    return cluster, "MinimapCluster",
      { point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = 0, y = 0 }
  end

  local minimap = U.G("Minimap")
  if minimap then return minimap, "Minimap", nil end

  return nil
end

local function RegisterMinimapMover()
  local target, name, default = ResolveMoverTarget()
  if not target then
    U.Debug("minimap: no MinimapCluster or Minimap to register as a mover")
    return
  end

  U.RegisterMover("minimap", target, { label = U.L("MOVER_LABEL_MINIMAP"),
                                       default = default, scalable = true })
  U.Debug("minimap mover registered on " .. name)
end

-- Let the native zoom controls own the actual zoom change. Their click paths
-- already clamp the zoom level, update both buttons and play the expected
-- sound; the minimap only translates a hovered wheel movement into that same
-- native action. On 1.12 script handlers receive the wheel delta through the
-- global arg1 rather than as a function parameter.
local function EnableMouseWheelZoom()
  local minimap = U.G("Minimap")
  local zoomIn = U.G("Minimap_ZoomIn")
  local zoomOut = U.G("Minimap_ZoomOut")
  if not minimap or type(zoomIn) ~= "function" or type(zoomOut) ~= "function" then
    U.Debug("minimap: mouse-wheel zoom unavailable (native zoom functions missing)")
    return false
  end

  if not pcall(minimap.EnableMouseWheel, minimap, 1) then
    U.Debug("minimap: mouse-wheel zoom unavailable (EnableMouseWheel failed)")
    return false
  end

  local applied = pcall(minimap.SetScript, minimap, "OnMouseWheel", function()
    local delta = arg1
    if type(delta) ~= "number" then return end
    if delta > 0 then
      pcall(zoomIn)
    elseif delta < 0 then
      pcall(zoomOut)
    end
  end)
  if not applied then
    U.Debug("minimap: mouse-wheel zoom unavailable (OnMouseWheel failed)")
    return false
  end

  U.Debug("minimap: mouse-wheel zoom enabled")
  return true
end

-- Applies the current enabled state to an already-created button. Public so
-- modules/settings.lua's General page can flip the checkbox without reaching
-- into this module's internals.
local function Apply()
  local button = MM.button
  if not button then return end

  if U.ModuleConfig("minimap", { enabled = true }).enabled then
    button:Show()
    if button.label then button.label:Show() end
  else
    button:Hide()
  end
end
U.ApplyMinimapButton = Apply

-- The Minimap settings page: the group switch, then one checkbox per icon that
-- can join the group, in two columns like the Classic modules page. Icons are
-- listed as found when the page is first built.
local function BuildSettingsPage(parent)
  local widgets = {}
  local controls = {}
  local pageWidth = U.SETTINGS_PAGE_WIDTH
  local columnWidth = math.floor(pageWidth / 2)

  local header = U.CreateSectionHeader(parent, {
    text = U.L("SETTINGS_PAGE_MINIMAP"),
    width = pageWidth,
    y = -4,
  })
  table.insert(widgets, header)

  local shape
  local shapeShift = 0
  if ModernWowTheme() then
    local shapeLabel = U.CreateSettingsLabel(parent, {
      size = M.fontSize.small,
      color = M.color.text,
      inherits = "GameFontNormalSmall",
      justify = "LEFT",
    })
    if shapeLabel then
      shapeLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -34)
      shapeLabel:SetText(U.L("SETTINGS_MINIMAP_SHAPE"))
      table.insert(widgets, shapeLabel)
    end

    shape = U.CreateDropdown(parent, {
      name = "PandaUISettingsMinimapShape",
      value = ModernWowShape(),
      width = 220,
      height = 24,
      rowHeight = 20,
      items = {
        { value = "circle", text = U.L("SETTINGS_MINIMAP_SHAPE_CIRCLE") },
        { value = "square", text = U.L("SETTINGS_MINIMAP_SHAPE_SQUARE") },
      },
      onChange = function(value)
        SetModernWowShape(value)
      end,
    })
    shape.SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -51)
    table.insert(widgets, shape)
    shapeShift = 62
  end

  local enable = U.CreateCheckbox(parent, {
    name = "PandaUISettingsMinimapGroup",
    text = U.L("SETTINGS_MINIMAP_GROUP"),
    value = group.Config().groupIcons and true or false,
    onChange = function(value)
      group.Config().groupIcons = value and true or false
      group.Apply()
    end,
  })
  enable.SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -34 - shapeShift)
  table.insert(widgets, enable)

  local hint = U.CreateSettingsLabel(parent, {
    size = M.fontSize.small,
    color = M.color.textDim,
    inherits = "GameFontNormalSmall",
    justify = "LEFT",
    width = pageWidth,
  })
  if hint then
    U.AnchorSettingsDescription(hint, enable.box)
    hint:SetText(U.L("SETTINGS_MINIMAP_GROUP_HINT"))
    table.insert(widgets, hint)
  end

  local listHeader = U.CreateSectionHeader(parent, {
    text = U.L("SETTINGS_MINIMAP_GROUP_ICONS"),
    width = pageWidth,
    y = -110 - shapeShift,
  })
  table.insert(widgets, listHeader)

  local candidates = U.MinimapGroupCandidates()
  local firstBox
  local i
  for i = 1, table.getn(candidates) do
    local entry = candidates[i]
    local row = math.floor((i - 1) / 2)
    local column = (i - 1) - row * 2
    local control = U.CreateCheckbox(parent, {
      name = "PandaUIMinimapGroupIcon" .. i,
      text = entry.label,
      textWidth = columnWidth - 20,
      value = not group.Config().ungrouped[entry.name],
      onChange = function(value)
        group.Config().ungrouped[entry.name] = (not value) and true or nil
        group.Apply()
      end,
    })
    if i == 1 then
      control.SetPoint("TOPLEFT", listHeader.title, "BOTTOMLEFT", 0, -8)
      firstBox = control.box
    else
      control.SetPoint("TOPLEFT", firstBox, "TOPLEFT",
                       column * columnWidth, -row * 22)
    end
    table.insert(controls, { control = control, name = entry.name })
    table.insert(widgets, control)
  end

  local function Refresh()
    local cfg = group.Config()
    if shape then shape.SetValue(ModernWowShape(), false) end
    enable.SetValue(cfg.groupIcons and true or false)
    local n
    for n = 1, table.getn(controls) do
      controls[n].control.SetValue(not cfg.ungrouped[controls[n].name])
    end
  end

  return widgets, Refresh
end

-- The edit-mode panel is deliberately available only for the Modern WoW
-- theme, which is the only path with the circle/square minimap choice.
local function BuildMoverPanel(frame, contentTop)
  local pad = U.MoverPanelPad()
  local widgets = {}

  local label = U.CreateSettingsLabel(frame, {
    size = M.fontSize.small,
    color = M.color.text,
    inherits = "GameFontNormalSmall",
    justify = "LEFT",
  })
  if label then
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, contentTop)
    label:SetText(U.L("SETTINGS_MINIMAP_SHAPE"))
    table.insert(widgets, label)
  end

  local shape = U.CreateDropdown(frame, {
    name = "PandaUIMinimapMoverShape",
    value = ModernWowShape(),
    width = MOVER_SHAPE_WIDTH,
    height = 24,
    rowHeight = 20,
    items = {
      { value = "circle", text = U.L("SETTINGS_MINIMAP_SHAPE_CIRCLE") },
      { value = "square", text = U.L("SETTINGS_MINIMAP_SHAPE_SQUARE") },
    },
    onChange = SetModernWowShape,
  })
  shape.SetPoint("TOPLEFT", frame, "TOPLEFT", pad, contentTop - 16)
  table.insert(widgets, shape)

  local function Refresh()
    shape.SetValue(ModernWowShape(), false)
  end
  return widgets, Refresh
end

function MM:OnInit()
  if type(U.RegisterSettingsTab) == "function" then
    U.RegisterSettingsTab("minimap", U.L("SETTINGS_PAGE_MINIMAP"), BuildSettingsPage,
                          { after = "general" })
  end
  if type(U.RegisterMoverPanel) == "function" then
    U.RegisterMoverPanel("minimap", {
      name = "PandaUIMinimapMoverSettings",
      width = MOVER_SHAPE_WIDTH + U.MoverPanelPad() * 2,
      height = 96,
      build = BuildMoverPanel,
      title = function() return U.L("MOVER_LABEL_MINIMAP") end,
      available = function() return ModernWowTheme() end,
    })
  end
end

function MM:OnEnable()
  if self.button then return end

  -- Nameplates use BACKGROUND/LOW strata, including the current target. Keep
  -- the minimap in the HUD layer so a plate cannot draw over it.
  local minimap = U.G("Minimap")
  if minimap then pcall(minimap.SetFrameStrata, minimap, "MEDIUM") end

  if ModernFlat() then
    DressModernFlatMinimap()
  else
    RestoreRoundMinimapMask()
    DressModernWowMinimap()
  end

  -- A child of Minimap, so it moves, scales and hides with the map. Its frame
  -- level sits above the map's own so its clicks are not taken as pings.
  minimap = U.G("Minimap")
  -- A plain Button rather than U.CreateButton: the round panda icon carries
  -- its own gold rim, so the square backdrop and border are left out.
  local button = CreateFrame("Button", "PandaUISettingsButton", minimap or UIParent)
  button:SetWidth(BUTTON_SIZE)
  button:SetHeight(BUTTON_SIZE)
  pcall(button.EnableMouse, button, true)
  button:SetScript("OnClick", function()
    if type(U.OpenSettings) == "function" then U.OpenSettings() end
  end)
  if minimap then
    local ok, level = pcall(minimap.GetFrameLevel, minimap)
    if ok and type(level) == "number" then
      pcall(button.SetFrameLevel, button, level + 5)
    end
  end

  -- The button used to be draggable to any screen position. That position is
  -- no longer used, so drop it from SavedVariables.
  if U.db and type(U.db.positions) == "table" then
    U.db.positions[POSITION_ID] = nil
  end

  -- The panda icon fills the button; the stock gear is the fallback if the
  -- addon texture is rejected.
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetWidth(ICON_SIZE)
  icon:SetHeight(ICON_SIZE)
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  if not pcall(icon.SetTexture, icon, M.texture.settingsIcon) then
    pcall(icon.SetTexture, icon, "Interface\\ICONS\\INV_Misc_Gear_01")
    pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
  end
  button.icon = icon

  -- Hover glow: the same texture the native minimap buttons (mail, meeting
  -- stone, zoom) declare as their HighlightTexture with alphaMode ADD in Octo
  -- FrameXML Minimap.xml. Set through the client's own highlight slot so the
  -- client owns the mouseover show/hide; ADD is requested as well.
  if pcall(button.SetHighlightTexture, button, MINIMAP_HIGHLIGHT) then
    local ok, glow = pcall(button.GetHighlightTexture, button)
    if ok and glow then
      pcall(glow.SetAllPoints, glow, button)
      pcall(glow.SetBlendMode, glow, "ADD")
    end
  end

  local anchor = AnchorButton(button)

  self.button = button
  Apply()
  U.Debug("settings button anchored to " .. anchor)

  RegisterMinimapMover()
  EnableMouseWheelZoom()

  -- After the theme has placed the native icons, so /pui reset returns them
  -- there. Own pcall: a failure must not take the mail letter down with it.
  local groupOk, groupErr = pcall(group.CreateLauncher, minimap)
  if not groupOk then
    U.Error("minimap group launcher: " .. tostring(groupErr))
  end
  local ringOk, ringErr = pcall(ring.Setup)
  if not ringOk then
    U.Error("minimap ring icons: " .. tostring(ringErr))
  end
  local applyOk, applyErr = pcall(group.Apply)
  if not applyOk then
    U.Error("minimap grouping: " .. tostring(applyErr))
  end
  -- Other addons create their minimap buttons while loading; by entering the
  -- world they all exist and can join the group.
  U.RegisterEvent("PLAYER_ENTERING_WORLD", function() pcall(group.Apply) end)

  -- Last, and inside its own pcall. RunModulePhase already wraps OnEnable, so
  -- an error raised here would abort the whole method -- and everything above
  -- it, the settings button included, would silently not exist. The mail
  -- letter is decoration; nothing else in this module may depend on it.
  local dressed, err = pcall(DressMailIcon)
  if not dressed then
    U.Error("minimap mail letter: " .. tostring(err))
  end
end
