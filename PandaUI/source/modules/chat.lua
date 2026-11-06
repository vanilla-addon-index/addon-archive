-- pandaUI :: modules/chat.lua
--
-- Adds one explicit resize grip to the primary native chat window, and an
-- opt-in switch that takes the drop shadow off the chat text. Chat tabs,
-- channels, message handling and drawing remain owned by the client.

local U = PandaUI
local M = U.media

local Chat = U.RegisterModule("chat")

local GRIP_SIZE = 20
local MIN_WIDTH = 180
local MIN_HEIGHT = 70
local LIVE_UPDATE_ID = "chat.resize.live"
local LOCK_UPDATE_ID = "chat.resize.lock"
local POSITION_UPDATE_ID = "chat.position.sync"
local POSITION_INTERVAL = 0.15
local RESTORE_PASSES = 8
local DRIFT_EPSILON = 1
local ALPHA_EPSILON = 0.01
local CENTER_INPUT_UPDATE_ID = "chat.input.center"
local CENTER_INPUT_INTERVAL = 0.25
local CHAT_DEFAULTS = {
  resized = false,
  width = 0,
  height = 0,
  left = 0,
  bottom = 0,
  noTextShadow = false,
  wheelScroll = true,
  stickyChannels = true,
  arrowHistory = true,
  hyperlinks = true,
  socialColors = true,
  blockNPCSpam = false,
  hideWorldInInstances = false,
  timestamps = false,
  timestamp24 = true,
  timestampSeconds = true,
  timestampBracket = "[]",
  timestampR = 0.8,
  timestampG = 0.8,
  timestampB = 0.8,
  centerInput = false,
  outlineText = false,
}
-- Consecutive corrections tolerated before the enforcement gives up. At the
-- position interval this is a few seconds of an unbroken fight with another
-- owner, which no legitimate late layout produces.
local ENFORCE_LIMIT = 40

local frame, grip, config
local dragging = false
local startFrameWidth, startFrameHeight, startFrameLeft, startFrameBottom
local startGripLeft, startGripBottom
local lastGripLeft, lastGripBottom
local lastGripShown
local lastSavedWidth, lastSavedHeight, lastSavedLeft, lastSavedBottom
local restorePasses = 0
local positionWasUnlocked = false
local enforceRuns = 0
local enforceStopped = false
local shadowFonts = {}
local shadowTouched = false
local shadowReport = { bound = false, applied = false }
local qol = {
  wheel = {},
  sticky = {},
  outline = {},
  input = {},
  friendRows = {},
  timestampFormat = "%H:%M:%S",
  timestampLeft = "[",
  timestampRight = "]",
  timestampColor = "|cffcccccc",
}
local chatBackground = {
  alpha = 0.25,
  hoverAlpha = 0.5,
  update = "chat.background",
  records = {},
}

local function ReadNumber(object, method)
  if not object or type(object[method]) ~= "function" then return nil end
  local ok, value = pcall(object[method], object)
  if ok and type(value) == "number" then return value end
  return nil
end

local function Clamp(value, minimum, maximum)
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function AnchorGrip()
  if not grip or not frame then return end
  grip:ClearAllPoints()
  grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
end

-- chat.lock_state_detection.v1 (SUPPORTED, BEHAVIOR_VERIFIED): the native
-- field is numeric 1 while General is locked and nil while it is unlocked.
-- ChatFrame1.locked stayed nil in both states and FCF_IsLocked was unavailable,
-- so neither is used as a fallback.
local function ChatIsLocked()
  if not frame then return true end
  local ok, value = pcall(function() return frame.isLocked end)
  return not ok or value == 1
end

local function ChatIsVisible()
  if not frame or type(frame.IsVisible) ~= "function" then return true end
  local ok, visible = pcall(frame.IsVisible, frame)
  if not ok then return true end
  return visible and true or false
end

local function SetGripShown(show)
  if not grip then return end
  show = show and true or false
  if show == lastGripShown then return end
  lastGripShown = show

  -- rendering.parent_alpha_not_propagated: toggle the texture explicitly with
  -- its Button instead of trusting child visibility to follow the parent.
  if show then
    grip:Show()
    if grip.icon then grip.icon:Show() end
  else
    if grip.icon then grip.icon:Hide() end
    grip:Hide()
  end
end

local function UpdateLockVisibility()
  if U.PerfDisabled and U.PerfDisabled("chat") then return end

  -- A menu cannot normally change the lock during a drag. If it somehow does,
  -- finish the current interaction first rather than hiding its active Button.
  if dragging then return end
  SetGripShown(not ChatIsLocked() and ChatIsVisible())
end

local function SaveGeometry(width, height, left, bottom)
  if not config then return end
  width = U.Round(width)
  height = U.Round(height)
  left = U.Round(left)
  bottom = U.Round(bottom)

  if config.resized and width == lastSavedWidth and
     height == lastSavedHeight and left == lastSavedLeft and
     bottom == lastSavedBottom then
    return
  end

  config.resized = true
  config.width = width
  config.height = height
  config.left = left
  config.bottom = bottom
  lastSavedWidth, lastSavedHeight = width, height
  lastSavedLeft, lastSavedBottom = left, bottom
  -- A fresh placement is a new target, so an enforcement that had given up
  -- gets to try again.
  enforceRuns = 0
  enforceStopped = false
end

local function ApplyFrameGeometry(width, height, left, bottom)
  if not frame then return false end

  return pcall(function()
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
  end)
end

local function ApplyGeometry(width, height, left, bottom)
  local ok = ApplyFrameGeometry(width, height, left, bottom)
  -- Re-anchoring a frame during StartMoving breaks the native drag on this
  -- client. The live path therefore updates only the chat; the grip is put
  -- back into its corner after StopMovingOrSizing.
  if ok and not dragging then AnchorGrip() end
  return ok
end

-- The stored geometry clamped to the current screen, or nil while nothing has
-- been placed yet.
local function SavedGeometry()
  if not config or not config.resized then return nil end

  local width = tonumber(config.width)
  local height = tonumber(config.height)
  local left = tonumber(config.left)
  local bottom = tonumber(config.bottom)
  if not (width and height and left and bottom) then return nil end

  width = Clamp(width, MIN_WIDTH, U.UIWidth() - left)
  height = Clamp(height, MIN_HEIGHT, U.UIHeight())
  bottom = Clamp(bottom, 0, U.UIHeight() - height)
  return width, height, left, bottom
end

local function RestoreSavedGeometry()
  local width, height, left, bottom = SavedGeometry()
  if not width then return end
  ApplyGeometry(width, height, left, bottom)
end

-- frames.extra_anchor_point_survives_addon_setpoint (USER_CONFIRMED_INGAME):
-- a native frame this addon re-anchors can end up carrying a second anchor
-- point that actually places it while GetPoint(1) still reads back as ours, so
-- the point count is tested first and any count other than one counts as drift
-- by itself. The rect comparison is what catches the client's own late chat
-- layout writing a different corner or size.
local function GeometryDrifted(width, height, left, bottom)
  local okCount, count = pcall(frame.GetNumPoints, frame)
  if okCount and tonumber(count) and tonumber(count) ~= 1 then return true end

  local currentWidth = ReadNumber(frame, "GetWidth")
  local currentHeight = ReadNumber(frame, "GetHeight")
  local currentLeft = ReadNumber(frame, "GetLeft")
  local currentBottom = ReadNumber(frame, "GetBottom")
  if not (currentWidth and currentHeight and currentLeft and currentBottom) then
    return false
  end

  if math.abs(currentWidth - width) > DRIFT_EPSILON then return true end
  if math.abs(currentHeight - height) > DRIFT_EPSILON then return true end
  if math.abs(currentLeft - left) > DRIFT_EPSILON then return true end
  if math.abs(currentBottom - bottom) > DRIFT_EPSILON then return true end
  return false
end

-- Put the chat back on its saved geometry whenever something else has moved or
-- resized it. This only runs while the chat is locked, where the resize grip is
-- hidden and native tab dragging is unavailable, so any difference from the
-- stored numbers is the client's own layout rather than the player.
local function EnforceSavedGeometry()
  if enforceStopped or not frame then return end

  local width, height, left, bottom = SavedGeometry()
  if not width then return end

  if not GeometryDrifted(width, height, left, bottom) then
    enforceRuns = 0
    return
  end

  ApplyGeometry(width, height, left, bottom)
  enforceRuns = enforceRuns + 1
  if enforceRuns >= ENFORCE_LIMIT then
    -- Another owner is rewriting the chat on every pass. Stand down rather
    -- than flicker the frame between two placements for the whole session.
    enforceStopped = true
    U.Debug("chat position: stopped re-applying the saved geometry; " ..
            "something keeps moving the chat back")
  end
end

local function CaptureCurrentGeometry()
  if dragging or not frame then return false end

  local width = ReadNumber(frame, "GetWidth")
  local height = ReadNumber(frame, "GetHeight")
  local left = ReadNumber(frame, "GetLeft")
  local bottom = ReadNumber(frame, "GetBottom")
  if not (width and height and left and bottom) then return false end

  SaveGeometry(width, height, left, bottom)
  return true
end

local function UpdatePositionPersistence()
  -- The native chat performs late layout work during reload, and it is not
  -- confined to the first second after login: with a single bounded restore
  -- window, any later native placement stood for the rest of the session,
  -- which is why the chat did not keep a custom position across a reload. The
  -- window now only suppresses capturing, so a late default layout cannot
  -- overwrite the correct SavedVariables values in memory; the saved geometry
  -- itself is re-applied for as long as the chat stays locked.
  if restorePasses > 0 then
    restorePasses = restorePasses - 1
    EnforceSavedGeometry()
    positionWasUnlocked = not ChatIsLocked()
    return
  end

  local unlocked = not ChatIsLocked()
  if unlocked and ChatIsVisible() then
    -- While unlocked, native tab dragging owns the frame. Polling only reads
    -- its resulting geometry and stores numbers; it never re-anchors the chat.
    CaptureCurrentGeometry()
  else
    if positionWasUnlocked then
      -- Capture once more on the unlocked -> locked transition so a quick lock
      -- immediately after dropping cannot miss the final position.
      CaptureCurrentGeometry()
    end
    EnforceSavedGeometry()
  end
  positionWasUnlocked = unlocked
end

local function ResetGripAfterFailure(message)
  U.UnregisterUpdate(LIVE_UPDATE_ID)
  dragging = false
  pcall(grip.StopMovingOrSizing, grip)
  AnchorGrip()
  U.Error("chat resize: " .. message)
end

local function GeometryAtGrip(gripLeft, gripBottom)
  local deltaX = gripLeft - startGripLeft
  local deltaY = gripBottom - startGripBottom
  local fixedTop = startFrameBottom + startFrameHeight

  local maxWidth = U.UIWidth() - startFrameLeft
  local maxHeight = fixedTop
  if maxWidth < MIN_WIDTH then maxWidth = MIN_WIDTH end
  if maxHeight < MIN_HEIGHT then maxHeight = MIN_HEIGHT end

  local width = Clamp(startFrameWidth + deltaX, MIN_WIDTH, maxWidth)
  -- The grip is on the lower edge, so dragging downward increases height while
  -- the chat's top-left corner stays fixed.
  local height = Clamp(startFrameHeight - deltaY, MIN_HEIGHT, maxHeight)
  local bottom = fixedTop - height
  return width, height, startFrameLeft, bottom
end

local function UpdateLiveGeometry()
  if U.PerfDisabled and U.PerfDisabled("chat") then return end

  if not dragging then return end

  local gripLeft = ReadNumber(grip, "GetLeft")
  local gripBottom = ReadNumber(grip, "GetBottom")
  if not (gripLeft and gripBottom) then return end
  if gripLeft == lastGripLeft and gripBottom == lastGripBottom then return end

  lastGripLeft, lastGripBottom = gripLeft, gripBottom
  local width, height, left, bottom = GeometryAtGrip(gripLeft, gripBottom)
  if not ApplyFrameGeometry(width, height, left, bottom) then
    ResetGripAfterFailure("the native chat frame rejected live resizing")
  end
end

local function StartResize()
  startFrameWidth = ReadNumber(frame, "GetWidth")
  startFrameHeight = ReadNumber(frame, "GetHeight")
  startFrameLeft = ReadNumber(frame, "GetLeft")
  startFrameBottom = ReadNumber(frame, "GetBottom")
  if not (startFrameWidth and startFrameHeight and startFrameLeft and
          startFrameBottom) then
    ResetGripAfterFailure("could not read the chat geometry")
    return
  end

  if not pcall(grip.SetMovable, grip, true) then
    ResetGripAfterFailure("the corner grip could not be made draggable")
    return
  end

  -- frames.movable_drag_requires_button_handle: this client needs the same
  -- throwaway move/stop pair used by pandaUI's mover before a real drag.
  if pcall(grip.StartMoving, grip) then
    pcall(grip.StopMovingOrSizing, grip)
  end

  startGripLeft = ReadNumber(grip, "GetLeft")
  startGripBottom = ReadNumber(grip, "GetBottom")
  if not (startGripLeft and startGripBottom) then
    ResetGripAfterFailure("could not read the corner grip position")
    return
  end

  if not pcall(grip.StartMoving, grip) then
    ResetGripAfterFailure("the corner grip did not start dragging")
    return
  end

  dragging = true
  lastGripLeft, lastGripBottom = startGripLeft, startGripBottom
  U.RegisterUpdate(LIVE_UPDATE_ID, 0, UpdateLiveGeometry)
end

local function StopResize()
  U.UnregisterUpdate(LIVE_UPDATE_ID)
  if not dragging then
    AnchorGrip()
    return
  end
  dragging = false

  pcall(grip.StopMovingOrSizing, grip)

  local finalLeft = ReadNumber(grip, "GetLeft")
  local finalBottom = ReadNumber(grip, "GetBottom")
  if not (finalLeft and finalBottom) then
    ResetGripAfterFailure("could not read the dropped corner position")
    return
  end

  local width, height, left, bottom = GeometryAtGrip(finalLeft, finalBottom)

  -- chat.chatframe1_resize.v1 (SUPPORTED, BEHAVIOR_VERIFIED) measured this
  -- exact native frame accepting SetWidth/SetHeight and reading both values
  -- back, then restoring its original dimensions.
  if not ApplyGeometry(width, height, left, bottom) then
    ResetGripAfterFailure("the native chat frame rejected its new size")
    return
  end

  SaveGeometry(width, height, left, bottom)
end

local function CreateGrip()
  grip = CreateFrame("Button", "PandaUIChatResizeGrip", frame)
  grip:Hide()
  grip:SetWidth(GRIP_SIZE)
  grip:SetHeight(GRIP_SIZE)
  grip:RegisterForDrag("LeftButton")
  pcall(grip.EnableMouse, grip, true)

  local level = ReadNumber(frame, "GetFrameLevel")
  if level then pcall(grip.SetFrameLevel, grip, level + 10) end

  local icon = grip:CreateTexture(nil, "ARTWORK")
  local textureOk = pcall(icon.SetTexture, icon, M.texture.chatResizeGrip)
  icon:SetAllPoints(grip)
  grip.icon = icon
  icon:Hide()
  if not textureOk then
    U.Error("chat resize: the bundled grip texture could not be loaded")
  end

  grip:SetScript("OnDragStart", StartResize)
  grip:SetScript("OnDragStop", StopResize)

  AnchorGrip()
end

-- ---------------------------------------------------------------------------
-- Chat text shadow
--
-- chat.native_private_font_removes_shadow: native probe v2 + user screenshot
-- verified SetFont(stock path, measured size), an owned FontString bound to
-- that private Font, SetTextColor(1,1,1), then ChatFrame1:SetFontObject(font).
-- White initialization is essential: a fresh Font otherwise makes new
-- default-color messages dark. Explicit message colors remain intact.
-- The same class/sequence is used on ChatFrame2; its visual result is pending.
-- No shadow setters, native region walks, message hooks or font polling.
-- Native chat has no GetFontObject, so disabling defers restoration to reload.
-- ---------------------------------------------------------------------------

local function BoundFontName(region)
  if not region or type(region.GetFontObject) ~= "function" then return nil end

  local ok, object = pcall(region.GetFontObject, region)
  if not ok or not object or type(object.GetName) ~= "function" then
    return nil
  end

  local nameOk, name = pcall(object.GetName, object)
  if not nameOk or type(name) ~= "string" then return nil end
  return name
end

local function ChatShadowFont(chat, index)
  local cached = shadowFonts[index]
  if cached then return cached.ready and cached.font or nil end
  local ok, _, size = pcall(function() return chat:GetFont() end)
  if not ok or type(size) ~= "number" or size <= 0 then return nil end
  -- Retain only owned objects, never a client-owned message region.
  local record = {}
  shadowFonts[index] = record
  local created = pcall(function()
    local name = "PandaUIChatNoShadowFont" .. index
    record.font = CreateFont(name)
    record.font:SetFont("Fonts\\FRIZQT__.TTF", size)
    record.holder = CreateFrame("Frame", nil, UIParent)
    record.holder:Hide()
    record.proxy = record.holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    record.proxy:SetFontObject(record.font)
    if BoundFontName(record.proxy) ~= name then return end
    record.proxy:SetTextColor(1, 1, 1)
    record.proxy:SetText("AaBb 123")
    local width = record.proxy:GetStringWidth()
    record.ready = type(width) == "number" and width > 0
  end)
  if not created or not record.ready then return nil end
  return record.font
end

-- Is the cursor inside this chat frame?
--
-- GetMouseFocus reports <none> on this client (core/commands.lua records the
-- 8s hover watch that found it useless), and the chat frames are client-owned,
-- so no OnEnter/OnLeave script may be taken from them. The cursor rectangle
-- test is the same GetCursorPosition/GetEffectiveScale pattern the world map
-- and minimap already rely on. An unreadable rect answers "not hovered", which
-- simply leaves the background at its idle opacity.
local function CursorOverFrame(frame, cursorX, cursorY)
  if not cursorX or not cursorY then return false end

  local scale = ReadNumber(frame, "GetEffectiveScale")
  if not scale or scale <= 0 then return false end

  local left = ReadNumber(frame, "GetLeft")
  local bottom = ReadNumber(frame, "GetBottom")
  local width = ReadNumber(frame, "GetWidth")
  local height = ReadNumber(frame, "GetHeight")
  if not (left and bottom and width and height) then return false end
  if width <= 0 or height <= 0 then return false end

  local x, y = cursorX / scale, cursorY / scale
  return x >= left and x <= left + width and y >= bottom and y <= bottom + height
end

local function CursorPoint()
  if type(GetCursorPosition) ~= "function" then return nil end
  local ok, x, y = pcall(GetCursorPosition)
  if not ok or type(x) ~= "number" or type(y) ~= "number" then return nil end
  return x, y
end

-- WORKING_SOURCE: UnrealPfUI/modules/chat.lua addresses ChatFrameNBackground
-- directly. No native region discovery or cached native texture references.
-- The background is held at 25% while idle and 50% while the cursor is over
-- that chat frame. Unlike the earlier floor-only treatment this overrides the
-- native hover fade in both directions, so the two states stay the ones
-- configured here. Chat text and frame alpha stay intact.
function chatBackground.Tick()
  if not config or not config.noTextShadow then return end
  local cursorX, cursorY = CursorPoint()
  local i
  for i = 1, 2 do
    local chat = U.G("ChatFrame" .. i)
    if chat then
      pcall(function()
        local record = chatBackground.records[i] or {}
        chatBackground.records[i] = record
        local target = chatBackground.alpha
        if CursorOverFrame(chat, cursorX, cursorY) then
          target = chatBackground.hoverAlpha
        end
        local texture = U.G("ChatFrame" .. i .. "Background")
        if texture and type(texture.SetAlpha) == "function" and type(texture.Show) == "function" then
          if not record.native then
            record.alpha = ReadNumber(texture, "GetAlpha")
            local ok, shown = pcall(texture.IsShown, texture)
            if ok then record.shown = shown and shown ~= 0 and true or false end
            record.native = true
          end
          if record.owned then record.owned:Hide() end
        else
          if not record.owned then
            record.owned = chat:CreateTexture(nil, "BACKGROUND")
            record.owned:SetTexture(M.texture.plain)
            record.owned:SetVertexColor(0, 0, 0, 1)
            record.owned:SetAllPoints(chat)
          end
          texture = record.owned
        end
        -- Compared with a tolerance because the native fade animates: an
        -- exact test would re-set the alpha on every frame of it.
        local alpha = ReadNumber(texture, "GetAlpha")
        if not alpha or alpha > target + ALPHA_EPSILON
            or alpha < target - ALPHA_EPSILON then
          texture:SetAlpha(target)
        end
        local ok, shown = pcall(texture.IsShown, texture)
        if not ok or not shown or shown == 0 then texture:Show() end
      end)
    end
  end
end

function chatBackground.Apply(enabled)
  if enabled then
    chatBackground.Tick()
    U.RegisterUpdate(chatBackground.update, 0, chatBackground.Tick)
    return
  end
  U.UnregisterUpdate(chatBackground.update)
  local index, record
  for index, record in pairs(chatBackground.records) do
    if record.owned then pcall(record.owned.Hide, record.owned) end
    if record.native then
      local texture = U.G("ChatFrame" .. index .. "Background")
      if texture then
        if record.alpha then pcall(texture.SetAlpha, texture, record.alpha) end
        if record.shown == false then pcall(texture.Hide, texture) end
        if record.shown == true then pcall(texture.Show, texture) end
      end
      record.native = nil
    end
  end
end

function U.ApplyChatTextShadow()
  local remove = config and config.noTextShadow and not config.outlineText and true or false
  chatBackground.Apply(remove)
  if not remove then
    shadowReport.applied = false
    -- Return whether settings must display the reload notice. No guessed
    -- ChatFontNormal restore: the original native font cannot be read back.
    return shadowTouched
  end
  local applied, bound, found = true, true, false
  local index
  for index = 1, 2 do
    local chat = U.G("ChatFrame" .. index)
    if chat then
      found = true
      local font = ChatShadowFont(chat, index)
      if not font then
        bound, applied = false, false
      else
        local ok = pcall(chat.SetFontObject, chat, font)
        if ok then shadowTouched = true else applied = false end
      end
    end
  end
  shadowReport.bound = found and bound
  shadowReport.applied = found and applied
  return false
end

-- ---------------------------------------------------------------------------
-- Shagu-inspired chat quality-of-life features. Every runtime dependency here
-- is a stock 1.12 FrameXML function or widget method; no ClassicAPI bridge is
-- used. Persistent chat history is deliberately outside this module.
-- ---------------------------------------------------------------------------

local STICKY_TYPES = { "WHISPER", "OFFICER", "RAID_WARNING", "CHANNEL" }
local INPUT_DODGE_FRAMES = {
  "MainMenuBar", "MainMenuBarArtFrame", "MultiBarBottomLeft",
  "MultiBarBottomRight", "PetActionBarFrame", "ShapeshiftBarFrame",
  "PandaUIPetBarAnchor", "PandaUIStanceBar", "PandaUIActionBar1",
  "PandaUIActionBar2", "PandaUIActionBar3", "PandaUIActionBar4",
  "PandaUIActionBar5", "PandaUIActionBar6", "PandaUIActionBar7",
  "PandaUIActionBar8", "PandaUIActionBar9", "PandaUIActionBar10",
}
local BLOCKED_NPCS = {
  ["Tansy Sparkpen"] = true,
  ["Fara Boltbreaker"] = true,
  ["Shellcoin Promoter"] = true,
  ["tansy sparkpen"] = true,
  ["fara boltbreaker"] = true,
  ["shellcoin promoter"] = true,
  ["Зазывала ярмарки Новолуния"] = true,
  ["Томас Миллер"] = true, ["Уильям"] = true, ["Донна"] = true,
  ["Жюстина Демалье"] = true, ["Мерлис Малаган"] = true,
  ["Лиана Пирс"] = true, ["Сюзанна"] = true, ["Джейни Аншип"] = true,
}
local URL_PATTERNS = {
  { " (www%d-)%.([_A-Za-z0-9-]+)%.(%S+)%s?", "%s.%s.%s" },
  { " (%a+)://(%S+)%s?", "%s://%s" },
  { " ([_A-Za-z0-9-%.:]+)@([_A-Za-z0-9-]+)(%.)([_A-Za-z0-9-]+%.?[_A-Za-z0-9-]*)%s?", "%s@%s%s%s" },
  { " (%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?):(%d%d?%d?%d?%d?)%s?", "%s.%s.%s.%s:%s" },
  { " (%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%s?", "%s.%s.%s.%s" },
  { " (%a+)%.(%a+)/(%S+)%s?", "%s.%s/%s" },
  { " ([_A-Za-z0-9-]+)%.([_A-Za-z0-9-]+)%.(%S+)%:([_0-9-]+)%s?", "%s.%s.%s:%s" },
  { " ([_A-Za-z0-9-]+)%.([_A-Za-z0-9-]+)%.(%S+)%s?", "%s.%s.%s" },
}

local function Byte(value)
  value = tonumber(value) or 0
  if value < 0 then value = 0 elseif value > 1 then value = 1 end
  return math.floor(value * 255 + 0.5)
end

local function ColorCode(r, g, b)
  return "|cff" .. string.format("%02x%02x%02x", Byte(r), Byte(g), Byte(b))
end

local function UpdateTimestampFormat()
  if config.timestamp24 then
    qol.timestampFormat = config.timestampSeconds and "%H:%M:%S" or "%H:%M"
  else
    qol.timestampFormat = config.timestampSeconds and "%I:%M:%S %p" or "%I:%M %p"
  end
  local bracket = config.timestampBracket
  if bracket == "()" then
    qol.timestampLeft, qol.timestampRight = "(", ")"
  elseif bracket == "" then
    qol.timestampLeft, qol.timestampRight = "", ""
  else
    qol.timestampLeft, qol.timestampRight = "[", "]"
  end
  qol.timestampColor = ColorCode(config.timestampR, config.timestampG,
                                 config.timestampB)
end

local function FormatURL(formatter, a1, a2, a3, a4, a5)
  if not a1 then return "" end
  local value = string.format(formatter, a1, a2, a3, a4, a5)
  return " " .. "|cffccccff|Hurl:" .. value .. "|h[" .. value .. "]|h|r "
end

local function LinkifyURLs(text)
  local i
  for i = 1, table.getn(URL_PATTERNS) do
    local pattern = URL_PATTERNS[i][1]
    local formatter = URL_PATTERNS[i][2]
    text = string.gsub(text, pattern,
      function(a1, a2, a3, a4, a5)
        return FormatURL(formatter, a1, a2, a3, a4, a5)
      end)
  end
  return text
end

local function ConvertChatLinks(text)
  text = string.gsub(text,
    "{CLINK:(%x+):([%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-):([^}]-)}",
    "|c%1|Hitem:%2|h[%3]|h|r")
  text = string.gsub(text,
    "{CLINK:(%x+):([%d-]-:[%d-]-:[%d-]-:[%d-]-):([^}]-)}",
    "|c%1|Hitem:%2|h[%3]|h|r")
  text = string.gsub(text,
    "{CLINK:item:(%x+):([%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-):([^}]-)}",
    "|c%1|Hitem:%2|h[%3]|h|r")
  text = string.gsub(text, "{CLINK:enchant:(%x+):([%d-]-):([^}]-)}",
                     "|c%1|Henchant:%2|h[%3]|h|r")
  text = string.gsub(text, "{CLINK:spell:(%x+):([%d-]-):([^}]-)}",
                     "|c%1|Hspell:%2|h[%3]|h|r")
  text = string.gsub(text,
                     "{CLINK:quest:(%x+):([%d-]-):([%d-]-):([^}]-)}",
                     "|c%1|Hquest:%2:%3|h[%4]|h|r")
  return LinkifyURLs(text)
end

local function ColorPlayerLinks(text)
  return string.gsub(text, "|Hplayer:([^|]+)|h%[([^%]]+)%]|h",
    function(payload, display)
      local _, _, name = string.find(payload, "^([^:]+)")
      local class = name and U.PlayerInfo(name)
      local r, g, b
      if class then r, g, b = M.ClassColor(class) end
      if not r then return "|Hplayer:" .. payload .. "|h[" .. display .. "]|h" end
      return "|Hplayer:" .. payload .. "|h[" .. ColorCode(r, g, b) ..
             display .. "|r]|h"
    end)
end

local function TransformChatMessage(text, richLinks)
  if richLinks and config.hyperlinks then text = ConvertChatLinks(text) end
  if richLinks and config.socialColors then text = ColorPlayerLinks(text) end
  if config.timestamps then
    text = qol.timestampColor .. qol.timestampLeft .. date(qol.timestampFormat) ..
           qol.timestampRight .. "|r " .. text
  end
  return text
end

local function RichLinksAllowed(chat)
  if type(chat.messageTypeList) ~= "table" then return true end
  local combat = 0
  local _, messageType
  for _, messageType in pairs(chat.messageTypeList) do
    if type(messageType) == "string" and
       (string.find(messageType, "SPELL", 1, true) or
        string.find(messageType, "COMBAT", 1, true)) then
      combat = combat + 1
    end
  end
  return combat < 5
end

local function InstallMessageHook(chat)
  if not chat or chat.puiChatQolAddMessage or type(chat.AddMessage) ~= "function" then
    return
  end
  local original = chat.AddMessage
  local richLinks = RichLinksAllowed(chat)
  chat.puiChatQolAddMessage = original
  chat.AddMessage = function(owner, text, r, g, b, id)
    if type(text) == "string" then text = TransformChatMessage(text, richLinks) end
    return original(owner, text, r, g, b, id)
  end
end

local function InstallMessageHooks()
  local count = tonumber(U.G("NUM_CHAT_WINDOWS")) or 7
  local i
  for i = 1, count do InstallMessageHook(U.G("ChatFrame" .. i)) end
end

local function InstallItemRefHook()
  if qol.itemRefInstalled then return end
  local original = U.G("SetItemRef")
  if type(original) ~= "function" then return end
  local wrapper = function(link, text, button)
    if type(link) == "string" and string.sub(link, 1, 4) == "url:" then
      local open = U.G("ChatFrame_OpenChat")
      if type(open) == "function" then pcall(open, string.sub(link, 5)) end
      return
    end

    local _, _, questId = string.find(link or "", "^quest:(%d+):")
    if questId and not U.G("PandaQuest") and not U.G("pfQuest") and
       not U.G("Questie") then
      local _, _, title = string.find(text or "", ".*|h%[(.*)%]|h.*")
      local tooltip = U.G("ItemRefTooltip")
      if title and tooltip then
        local hide = U.G("HideUIPanel")
        local show = U.G("ShowUIPanel")
        if type(hide) == "function" then pcall(hide, tooltip) end
        if type(show) == "function" then pcall(show, tooltip) end
        pcall(tooltip.SetOwner, tooltip, UIParent, "ANCHOR_PRESERVE")
        pcall(tooltip.AddLine, tooltip, title, 1, 1, 0)
        pcall(tooltip.AddDoubleLine, tooltip, "Quest ID", questId,
              0.6, 0.6, 0.6, 1, 1, 1)
        pcall(tooltip.Show, tooltip)
        return
      end
    end
    return original(link, text, button)
  end
  U.SetG("SetItemRef", wrapper)
  qol.itemRefInstalled = U.G("SetItemRef") == wrapper
end

local function ChatMouseWheel()
  local delta = tonumber(arg1) or 0
  if delta > 0 then
    if IsShiftKeyDown() and type(this.ScrollToTop) == "function" then
      this:ScrollToTop()
    elseif type(this.ScrollUp) == "function" then
      this:ScrollUp()
    end
  elseif delta < 0 then
    if IsShiftKeyDown() and type(this.ScrollToBottom) == "function" then
      this:ScrollToBottom()
    elseif type(this.ScrollDown) == "function" then
      this:ScrollDown()
    end
  end
end

local function ApplyWheelScrolling()
  local count = tonumber(U.G("NUM_CHAT_WINDOWS")) or 7
  local i
  for i = 1, count do
    local chat = U.G("ChatFrame" .. i)
    if chat then
      local record = qol.wheel[i]
      if not record then
        record = {}
        qol.wheel[i] = record
        local ok, handler = pcall(chat.GetScript, chat, "OnMouseWheel")
        if ok then record.handler = handler end
        local enabledOk, enabled = pcall(chat.IsMouseWheelEnabled, chat)
        if enabledOk then record.enabled = enabled and enabled ~= 0 and true or false end
      end
      if config.wheelScroll then
        pcall(chat.EnableMouseWheel, chat, true)
        pcall(chat.SetScript, chat, "OnMouseWheel", ChatMouseWheel)
      else
        pcall(chat.SetScript, chat, "OnMouseWheel", record.handler)
        pcall(chat.EnableMouseWheel, chat, record.enabled and true or false)
      end
    end
  end
end

local function ApplyStickyChannels()
  local types = U.G("ChatTypeInfo")
  if type(types) ~= "table" then return end
  local i
  for i = 1, table.getn(STICKY_TYPES) do
    local key = STICKY_TYPES[i]
    local info = types[key]
    if type(info) == "table" then
      if not qol.sticky[key] then qol.sticky[key] = { value = info.sticky } end
      info.sticky = config.stickyChannels and 1 or qol.sticky[key].value
    end
  end
end

local function ApplyArrowHistory()
  local edit = U.G("ChatFrameEditBox")
  if not edit or type(edit.SetAltArrowKeyMode) ~= "function" then return end
  if not qol.arrowCaptured then
    qol.arrowCaptured = true
    local ok, value = pcall(edit.GetAltArrowKeyMode, edit)
    if ok then qol.arrowOriginal = value end
  end
  local value = config.arrowHistory and nil or qol.arrowOriginal
  pcall(edit.SetAltArrowKeyMode, edit, value)
end

local function CaptureInputPosition(edit)
  if qol.input.captured then return end
  qol.input.captured = true
  qol.input.points = {}
  local okWidth, width = pcall(edit.GetWidth, edit)
  if okWidth then qol.input.width = width end
  local okCount, count = pcall(edit.GetNumPoints, edit)
  count = okCount and tonumber(count) or 0
  local i
  for i = 1, math.min(count, 2) do
    local ok, point, relative, relativePoint, x, y = pcall(edit.GetPoint, edit, i)
    if ok and point then
      qol.input.points[i] = { point, relative, relativePoint, x or 0, y or 0 }
    end
  end
end

local function RestoreInputPosition(edit)
  if not qol.input.active then return end
  pcall(edit.ClearAllPoints, edit)
  local points = qol.input.points or {}
  local i
  for i = 1, table.getn(points) do
    local point = points[i]
    pcall(edit.SetPoint, edit, point[1], point[2], point[3], point[4], point[5])
  end
  if tonumber(qol.input.width) then pcall(edit.SetWidth, edit, qol.input.width) end
  qol.input.active, qol.input.lastY = false, nil
end

local function UpdateInputPosition()
  local edit = U.G("ChatFrameEditBox")
  if not edit then return end
  if not config.centerInput then RestoreInputPosition(edit) return end
  CaptureInputPosition(edit)

  local top = 0
  local i
  for i = 1, table.getn(INPUT_DODGE_FRAMES) do
    local bar = U.G(INPUT_DODGE_FRAMES[i])
    if bar and type(bar.IsVisible) == "function" and type(bar.GetTop) == "function" then
      local visibleOk, visible = pcall(bar.IsVisible, bar)
      if visibleOk and visible then
        local topOk, value = pcall(bar.GetTop, bar)
        value = topOk and tonumber(value) or nil
        if value and value > top then top = value end
      end
    end
  end
  local y = U.Round(top + 8)
  if qol.input.active and qol.input.lastY == y then return end
  pcall(edit.SetWidth, edit, 300)
  pcall(edit.ClearAllPoints, edit)
  pcall(edit.SetPoint, edit, "BOTTOM", UIParent, "BOTTOM", 0, y)
  qol.input.active, qol.input.lastY = true, y
end

local function ApplyOutlineText()
  local count = tonumber(U.G("NUM_CHAT_WINDOWS")) or 7
  local i
  for i = 1, count do
    local chat = U.G("ChatFrame" .. i)
    if chat and type(chat.GetFont) == "function" then
      local record = qol.outline[i]
      if not record then
        record = {}
        qol.outline[i] = record
        local fontOk, path, size, flags = pcall(chat.GetFont, chat)
        if fontOk then record.path, record.size, record.flags = path, size, flags end
        local shadowOk, x, y = pcall(chat.GetShadowOffset, chat)
        if shadowOk then record.shadowX, record.shadowY = x, y end
      end
      if record.path and tonumber(record.size) then
        if config.outlineText then
          pcall(chat.SetFont, chat, record.path, record.size, "OUTLINE")
          pcall(chat.SetShadowOffset, chat, 0, 0)
        else
          pcall(chat.SetFont, chat, record.path, record.size, record.flags)
          if record.shadowX then
            pcall(chat.SetShadowOffset, chat, record.shadowX, record.shadowY)
          end
        end
      end
    end
  end
  U.ApplyChatTextShadow()
end

local function IsBlockedNPCMessage(evt)
  if evt ~= "CHAT_MSG_MONSTER_SAY" and evt ~= "CHAT_MSG_MONSTER_YELL" then
    return false
  end
  local message, sender = arg1, arg2
  if type(sender) == "string" and
     (BLOCKED_NPCS[sender] or BLOCKED_NPCS[string.lower(sender)]) then
    return true
  end
  if type(message) ~= "string" then return false end
  local normalized = string.lower(string.gsub(message, "[^A-Za-z0-9]", ""))
  if string.find(normalized, "shellcoin", 1, true) and
     string.find(normalized, "invest", 1, true) then return true end
  if string.find(normalized, "shells", 1, true) and
     (string.find(normalized, "trade", 1, true) or
      string.find(normalized, "money", 1, true)) then return true end
  return false
end

local function IsWorldMessageInInstance(evt)
  if evt ~= "CHAT_MSG_CHANNEL" then return false end
  local inInstance = U.G("IsInInstance")
  if type(inInstance) ~= "function" then return false end
  local ok, inside = pcall(inInstance)
  if not ok or (inside ~= 1 and inside ~= true) then return false end
  if type(arg9) == "string" and string.lower(arg9) == "world" then return true end
  if type(arg4) ~= "string" then return false end
  local channel = string.lower(arg4)
  if channel == "world" then return true end
  local _, _, base = string.find(channel, "^%d+%.%s*(.+)$")
  return base == "world"
end

local function InstallEventFilter()
  if qol.filterInstalled then return end
  local original = U.G("ChatFrame_OnEvent")
  if type(original) ~= "function" then return end
  local wrapper = function(evt)
    local current = evt or event
    if config.blockNPCSpam and IsBlockedNPCMessage(current) then return end
    if config.hideWorldInInstances and IsWorldMessageInInstance(current) then return end
    return original(current)
  end
  U.SetG("ChatFrame_OnEvent", wrapper)
  qol.filterInstalled = U.G("ChatFrame_OnEvent") == wrapper
end

local function SocialColor(localized)
  local token = type(U.PlayerClassToken) == "function" and
                U.PlayerClassToken(localized) or nil
  if token then return M.ClassColor(token) end
  return nil
end

local function ColorWhoRows()
  if not config.socialColors then return end
  local frame = U.G("WhoFrame")
  if not frame or type(frame.IsVisible) ~= "function" then return end
  local visibleOk, visible = pcall(frame.IsVisible, frame)
  if not visibleOk or not visible then return end
  local scroll = U.G("WhoListScrollFrame")
  local offset = scroll and FauxScrollFrame_GetOffset(scroll) or 0
  local count = tonumber(U.G("WHOS_TO_DISPLAY")) or 17
  local i
  for i = 1, count do
    local ok, name, _, _, _, localized = pcall(GetWhoInfo, offset + i)
    if ok and name then
      if type(U.PlayerCacheRemember) == "function" then
        U.PlayerCacheRemember(name, localized)
      end
      local r, g, b = SocialColor(localized)
      if r then
        local nameText = U.G("WhoFrameButton" .. i .. "Name")
        local classText = U.G("WhoFrameButton" .. i .. "Class")
        if nameText then pcall(nameText.SetTextColor, nameText, r, g, b, 1) end
        if classText then pcall(classText.SetTextColor, classText, r, g, b, 1) end
      end
    end
  end
end

local function ColorGuildRows()
  if not config.socialColors then return end
  local frame = U.G("GuildFrame")
  if not frame or type(frame.IsVisible) ~= "function" then return end
  local visibleOk, visible = pcall(frame.IsVisible, frame)
  if not visibleOk or not visible then return end
  local scroll = U.G("GuildListScrollFrame")
  local offset = scroll and FauxScrollFrame_GetOffset(scroll) or 0
  local count = tonumber(U.G("GUILDMEMBERS_TO_DISPLAY")) or 13
  local guild = type(U.PlayerGuild) == "function" and U.PlayerGuild() or nil
  local i
  for i = 1, count do
    local ok, name, _, _, _, localized, _, _, _, online =
      pcall(GetGuildRosterInfo, offset + i)
    if ok and name then
      if type(U.PlayerCacheRemember) == "function" then
        U.PlayerCacheRemember(name, localized, guild)
      end
      local r, g, b = SocialColor(localized)
      if r then
        local alpha = (online and online ~= 0) and 1 or 0.5
        local nameText = U.G("GuildFrameButton" .. i .. "Name")
        local classText = U.G("GuildFrameButton" .. i .. "Class")
        if nameText then pcall(nameText.SetTextColor, nameText, r, g, b, alpha) end
        if classText then pcall(classText.SetTextColor, classText, r, g, b, alpha) end
      end
    end
  end
end

local function ColorSocialRows()
  -- FriendsFrame can load after PandaUI and its stock refresh functions repaint
  -- these rows. The visibility guards keep this inexpensive while guaranteeing
  -- the final visible colors without touching or replacing row handlers.
  ColorWhoRows()
  ColorGuildRows()
end

-- FriendsList_Update owns row text, selection and visibility. Do not hook it:
-- this client previously crashed when addon row work followed that refresh.
-- The shared updater calls this independently, and each named FontString is
-- repainted only when its displayed friend or class changes. No row, handler,
-- highlight or native text is modified.
local function ColorFriendRows()
  local list = U.G("FriendsListFrame")
  if not list or type(list.IsVisible) ~= "function" then return end
  local visibleOk, visible = pcall(list.IsVisible, list)
  if not visibleOk or not visible then return end

  local offset = 0
  local scroll = U.G("FriendsFrameFriendsScrollFrame")
  if scroll and type(FauxScrollFrame_GetOffset) == "function" then
    local offsetOk, value = pcall(FauxScrollFrame_GetOffset, scroll)
    if offsetOk then offset = tonumber(value) or 0 end
  end

  local count = tonumber(U.G("FRIENDS_TO_DISPLAY")) or 10
  local i
  for i = 1, count do
    local label = U.G("FriendsFrameFriendButton" .. i ..
                      "ButtonTextNameLocation")
    if label then
      local state = qol.friendRows[i]
      if not state then
        state = {}
        qol.friendRows[i] = state
        if type(label.GetTextColor) == "function" then
          local colorOk, r, g, b, a = pcall(label.GetTextColor, label)
          if colorOk then state.r, state.g, state.b, state.a = r, g, b, a end
        end
      end

      local infoOk, name, _, localized, _, connected =
        pcall(GetFriendInfo, offset + i)
      if not infoOk then name, localized, connected = nil, nil, nil end
      if name and (state.name ~= name or state.localized ~= localized) and
         type(U.PlayerCacheRemember) == "function" then
        U.PlayerCacheRemember(name, localized)
      end
      state.name, state.localized = name, localized

      local token = name and type(U.PlayerClassToken) == "function" and
                    U.PlayerClassToken(localized) or nil
      if not token and name and type(U.PlayerInfo) == "function" then
        token = U.PlayerInfo(name)
      end
      local enabled = config.socialColors and name and token and true or false
      local signature = tostring(enabled) .. ":" .. tostring(name) .. ":" ..
                        tostring(token) .. ":" .. tostring(connected)
      if state.signature ~= signature then
        state.signature = signature
        if enabled then
          local r, g, b = M.ClassColor(token)
          if r then
            local alpha = (connected and connected ~= 0) and 1 or 0.5
            pcall(label.SetTextColor, label, r, g, b, alpha)
          end
        elseif state.r then
          pcall(label.SetTextColor, label, state.r, state.g, state.b,
                state.a or 1)
        end
      end
    end
  end
end

local function RememberFriends()
  if type(U.PlayerCacheRemember) ~= "function" then return end
  local ok, count = pcall(GetNumFriends)
  count = ok and tonumber(count) or 0
  local i
  for i = 1, count do
    local infoOk, name, _, localized = pcall(GetFriendInfo, i)
    if infoOk and name then U.PlayerCacheRemember(name, localized) end
  end
end

local function ApplyChatQoL()
  UpdateTimestampFormat()
  ApplyWheelScrolling()
  ApplyStickyChannels()
  ApplyArrowHistory()
  UpdateInputPosition()
  ApplyOutlineText()
end

local function AddCheck(parent, widgets, name, textKey, key, x, y, apply)
  local control = U.CreateCheckbox(parent, {
    name = name,
    text = U.L(textKey),
    textWidth = 205,
    value = config[key],
    onChange = function(value)
      config[key] = value and true or false
      if apply then apply() end
    end,
  })
  control.SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  table.insert(widgets, control)
  return control
end

local function BuildChatSettings(parent)
  local widgets = {}
  local column = U.SETTINGS_COLUMN_X or 245
  local header = U.CreateSectionHeader(parent, {
    text = U.L("CHAT_QOL_HEADER"), width = U.SETTINGS_PAGE_WIDTH, y = -4,
  })
  table.insert(widgets, header)

  AddCheck(parent, widgets, "PandaUIChatWheel", "CHAT_WHEEL", "wheelScroll",
           0, -36, ApplyWheelScrolling)
  AddCheck(parent, widgets, "PandaUIChatSticky", "CHAT_STICKY", "stickyChannels",
           0, -64, ApplyStickyChannels)
  AddCheck(parent, widgets, "PandaUIChatHistory", "CHAT_ARROW_HISTORY", "arrowHistory",
           0, -92, ApplyArrowHistory)
  AddCheck(parent, widgets, "PandaUIChatLinks", "CHAT_HYPERLINKS", "hyperlinks",
           0, -120)
  AddCheck(parent, widgets, "PandaUIChatSocial", "CHAT_SOCIAL_COLORS", "socialColors",
           column, -36, function()
             ColorWhoRows(); ColorGuildRows(); ColorFriendRows()
           end)
  AddCheck(parent, widgets, "PandaUIChatNPCSpam", "CHAT_BLOCK_NPC", "blockNPCSpam",
           column, -64)
  AddCheck(parent, widgets, "PandaUIChatWorldHide", "CHAT_HIDE_WORLD", "hideWorldInInstances",
           column, -92)
  AddCheck(parent, widgets, "PandaUIChatCenterInput", "CHAT_CENTER_INPUT", "centerInput",
           column, -120, UpdateInputPosition)

  local extras = U.CreateSectionHeader(parent, {
    text = U.L("CHAT_FORMAT_HEADER"), width = U.SETTINGS_PAGE_WIDTH, y = -166,
  })
  table.insert(widgets, extras)
  AddCheck(parent, widgets, "PandaUIChatTimestamps", "CHAT_TIMESTAMPS", "timestamps",
           0, -198)
  AddCheck(parent, widgets, "PandaUIChat24Hour", "CHAT_24_HOUR", "timestamp24",
           0, -226, UpdateTimestampFormat)
  AddCheck(parent, widgets, "PandaUIChatSeconds", "CHAT_SECONDS", "timestampSeconds",
           0, -254, UpdateTimestampFormat)
  AddCheck(parent, widgets, "PandaUIChatOutline", "CHAT_OUTLINE", "outlineText",
           column, -198, ApplyOutlineText)

  local bracketLabel = U.CreateSettingsLabel(parent, {
    size = M.fontSize.small, color = M.color.text, inherits = "GameFontNormalSmall",
    justify = "LEFT", width = 205, height = 14,
  })
  if bracketLabel then
    bracketLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", column, -228)
    bracketLabel:SetText(U.L("CHAT_BRACKETS"))
    table.insert(widgets, bracketLabel)
  end
  local bracket = U.CreateDropdown(parent, {
    name = "PandaUIChatTimestampBracket", width = 205, height = 24, rowHeight = 20,
    value = config.timestampBracket,
    items = {
      { value = "[]", text = U.L("CHAT_BRACKET_SQUARE") },
      { value = "()", text = U.L("CHAT_BRACKET_ROUND") },
      { value = "", text = U.L("CHAT_BRACKET_NONE") },
    },
    onChange = function(value)
      config.timestampBracket = value
      UpdateTimestampFormat()
    end,
  })
  bracket.SetPoint("TOPLEFT", parent, "TOPLEFT", column, -246)
  table.insert(widgets, bracket)

  local color = U.CreateColorPicker(parent, {
    name = "PandaUIChatTimestampColor", text = U.L("CHAT_TIMESTAMP_COLOR"),
    value = { r = config.timestampR, g = config.timestampG,
              b = config.timestampB, a = 1 },
    hasOpacity = false,
    onChange = function(value)
      config.timestampR, config.timestampG, config.timestampB =
        value.r, value.g, value.b
      UpdateTimestampFormat()
    end,
  })
  color.SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -296)
  table.insert(widgets, color)

  local note = U.CreateSettingsLabel(parent, {
    size = M.fontSize.small, color = M.color.textDim,
    inherits = "GameFontNormalSmall", justify = "LEFT",
    width = U.SETTINGS_PAGE_WIDTH, height = 28,
  })
  if note then
    note:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -332)
    note:SetText(U.L("CHAT_HISTORY_NOTE"))
    table.insert(widgets, note)
  end
  return widgets
end

function Chat:OnInit()
  config = U.ModuleConfig("chat", CHAT_DEFAULTS)
  UpdateTimestampFormat()
  if type(U.RegisterSettingsTab) == "function" then
    U.RegisterSettingsTab("chat", U.L("CHAT_SETTINGS_PAGE"),
                          BuildChatSettings, { after = "general" })
  end
  if config and config.resized then
    lastSavedWidth = tonumber(config.width)
    lastSavedHeight = tonumber(config.height)
    lastSavedLeft = tonumber(config.left)
    lastSavedBottom = tonumber(config.bottom)
  end
end

function Chat:OnEnable()
  frame = U.G("ChatFrame1")
  if not frame then
    U.Error("chat resize: ChatFrame1 is unavailable")
    return
  end

  CreateGrip()
  InstallMessageHooks()
  InstallItemRefHook()
  InstallEventFilter()
  ApplyChatQoL()
  U.PostHookGlobal("UIParent_ManageFramePositions", UpdateInputPosition)
  U.PostHookGlobal("WhoList_Update", ColorWhoRows)
  U.PostHookGlobal("GuildStatus_Update", ColorGuildRows)
  U.RegisterUpdate("chat.social-rows", 0.25, ColorSocialRows)
  U.RegisterEvent("FRIENDLIST_UPDATE", RememberFriends)
  RememberFriends()
  U.RegisterUpdate("chat.social-friends", 0.5, ColorFriendRows)
  ColorFriendRows()
  U.RegisterUpdate(CENTER_INPUT_UPDATE_ID, CENTER_INPUT_INTERVAL,
                   UpdateInputPosition)
  RestoreSavedGeometry()
  restorePasses = config and config.resized and RESTORE_PASSES or 0
  positionWasUnlocked = not ChatIsLocked()
  lastGripShown = nil
  UpdateLockVisibility()
  U.RegisterUpdate(LOCK_UPDATE_ID, 0.10, UpdateLockVisibility)
  U.RegisterUpdate(POSITION_UPDATE_ID, POSITION_INTERVAL,
                   UpdatePositionPersistence)
end

function U.ChatResizeReport()
  local gripShown = false
  if grip and type(grip.IsShown) == "function" then
    local ok, shown = pcall(grip.IsShown, grip)
    if ok then gripShown = shown and true or false end
  end
  return {
    frame = frame and true or false,
    grip = grip and true or false,
    dragging = dragging,
    saved = config and config.resized and true or false,
    locked = ChatIsLocked(),
    shown = gripShown,
    left = frame and ReadNumber(frame, "GetLeft") or nil,
    bottom = frame and ReadNumber(frame, "GetBottom") or nil,
    savedLeft = config and config.left or nil,
    savedBottom = config and config.bottom or nil,
    enforceRuns = enforceRuns,
    enforceStopped = enforceStopped,
    noTextShadow = config and config.noTextShadow and true or false,
    shadowBound = shadowReport.bound,
    shadowApplied = shadowReport.applied,
    width = frame and ReadNumber(frame, "GetWidth") or nil,
    height = frame and ReadNumber(frame, "GetHeight") or nil,
  }
end
