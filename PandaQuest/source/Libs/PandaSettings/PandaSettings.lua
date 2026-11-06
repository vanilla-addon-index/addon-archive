--[[
PandaSettings -- the shared settings window of the Panda addons.

Every Panda addon with options ships this folder (Libs/PandaSettings)
byte-identical. The copy with the highest MINOR wins at load; the others
return at once. Each addon names the folder it ships with AddMediaRoot, and the
art is read from the copy that matches the winning version.

pandaUI has priority. While it is installed every addon registers its pages
with pandaUI, and this window and its minimap button stay hidden. Without it,
every addon that registers here is one category of one window, drawn like
pandaUI's Game Settings window, and one panda button on the minimap opens it.

The registration contract is pandaUI's own (RegisterSettingsGroup,
RegisterSettingsTab, OpenSettingsPage, CreateCheckbox, CreateRadioGroup,
CreateSlider, CreateDropdown, GetIntegratedSettingsPageHeight), so a page
builder does not care which of the two hosts calls it.

Group options this host reads beyond pandaUI's: get/set (the addon's stored
values: minimapButton, settingsPoint, settingsX, settingsY), languages,
getLanguage, setLanguage(code, quiet) and minimapTooltip.

GetPoint is never called on a frame the client has moved
(frames.getpoint_after_native_move_access_violation): positions are measured
with GetLeft/GetBottom and re-anchored. Thumbs follow from the press with the
native move recipe (widgets.slider_thumb_waits_for_drag_threshold).
]]

local MINOR = 1

if type(PandaSettings) == "table" then
  PandaSettings.lastLoadedMinor = MINOR
  if type(PandaSettings.minor) == "number" and PandaSettings.minor >= MINOR then
    return
  end
end

local lib = type(PandaSettings) == "table" and PandaSettings or {}
PandaSettings = lib
lib.minor = MINOR
lib.lastLoadedMinor = MINOR
lib.groups = lib.groups or {}
lib.mediaRoots = lib.mediaRoots or {}
lib.ui = lib.ui or {}

-- Measurements are pandaUI's Game Settings window (modules/gamesettings.lua,
-- core/media.lua M.foreverWow / M.modernWow), copied so both windows match.
local T = {
  TITLE = "Panda Settings",
  WIDTH = 749.3, HEIGHT = 611.52,
  HEADER = 30, PLATE_TOP = 66, PLATE_SIDE = 17, PLATE_BOTTOM = 42,
  LIST_LEFT = 18, LIST_DROP = 12,
  SIDEBAR_WIDTH = 187.16, ROW_WIDTH = 167.16, ROW_PLATE = 179.16,
  ROW_HEIGHT = 20, HEADER_ROW = 30, ROW_LABEL_INSET = 10, SUB_INDENT = 12,
  CATEGORY_LOGO = 18, PAGE_LOGO = 20, LOGO_GAP = 5,
  CONTAINER_GAP = 16, CONTENT_RIGHT = 6, CONTENT_HEADER = 27.3, TITLE_INSET = 7,
  SCROLL_COLUMN = 22, LEFT_PAD = 28.3, WHEEL_STEP = 36, PAGE_WIDTH = 460,
  BUTTON_WIDTH = 96, BUTTON_HEIGHT = 22, BUTTON_INSET = 16,
  CLOSE_SIZE = 20.4, CLOSE_X = -2, CLOSE_Y = 2,
  SCREEN_SCALE = 0.9,
  MINIMAP_SIZE = 33, MINIMAP_ICON = 28, MINIMAP_ANGLE = 225 * math.pi / 180,
  MINIMAP_OUTSET = 10,
  MINIMAP_HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
  FLAG_WIDTH = 18, FLAG_HEIGHT = 14, FLAG_GAP = 3, FLAG_RIGHT = 8,
  FLAG_SELECTED = 1, FLAG_IDLE = 0.3, FLAG_HOVER = 0.95,
  WATERMARK = 185, WATERMARK_ALPHA = 0.2, WATERMARK_INSET = 8,
  MENU_ROW = 18, MENU_LEVEL = 30,
  PANEL_COLOR = { 0.110, 0.153, 0.188, 0.95 },
  GOLD = { 1.00, 0.82, 0.00 }, WHITE = { 1, 1, 1 }, DIM = { 0.60, 0.60, 0.60 },
  GREY = { 0.50, 0.50, 0.50 },
  LANGUAGES = { "enUS", "zhCN", "ruRU", "frFR" },
  FLAGS = { enUS = "flag-en", zhCN = "flag-cn", ruRU = "flag-ru", frFR = "flag-fr" },
}

-- ButtonFrameTemplateNoPortrait's metal rim (M.modernWow.gameSettingsFrame).
T.rim = {
  left = -8, right = 4, top = 16, bottom = -3,
  topLeft = { 75, 74, { 0.00195312, 0.294922, 0.00195312, 0.294922 } },
  topRight = { 75, 74, { 0.298828, 0.591797, 0.00195312, 0.294922 } },
  bottomLeft = { 32, 32, { 0.298828, 0.423828, 0.298828, 0.423828 } },
  bottomRight = { 32, 32, { 0.427734, 0.552734, 0.298828, 0.423828 } },
  edgeTop = { 74, { 0, 1, 0.00390625, 0.589844 } },
  edgeBottom = { 32, { 0, 0.5, 0.597656, 0.847656 } },
  edgeLeft = { 75, { 0.00195312, 0.294922, 0, 1 } },
  edgeRight = { 75, { 0.298828, 0.591797, 0, 1 } },
  body = { 3, 18, 3, 3 },
  titleY = -13,
}

-- Cells on the 1024x1024 Options atlas, drawn from its four 512 quadrants.
T.options = {
  inner = { 1, 887, 150, 768 }, innerWidth = 886, innerHeight = 618,
  slice = { rim = 8, seam = 199, seamKeep = 11, keepRight = 30, top = 8, bottom = 8 },
  divider = { 1, 631, 147, 148 },
  rowActive = { 604, 791, 1, 22 },
  rowHover = { 793, 980, 1, 22 },
  categoryHeader = { 1, 200, 1, 145 }, categoryHeaderHeight = 144,
}

-- The control art (M.foreverWow.control, M.modernWow.button128Red, scrollbar).
T.checkbox = { width = 20.25, height = 19.575, box = { 1, 31, 1, 30 },
  check = { 1, 31, 32, 61 }, checkDisabled = { 33, 63, 1, 30 }, size = 14 }
T.dropdown = { controlHeight = 18.2, height = 29.25, overhang = 5.5, cap = 22,
  normal = { 431, 509, 1, 79 }, hover = { 401, 479, 85, 163 },
  pressed = { 81, 159, 345, 423 }, open = { 1, 79, 425, 503 },
  disabled = { 321, 399, 85, 163 }, textInset = 10,
  arrow = { 321, 345, 165, 175 }, arrowWidth = 9, arrowHeight = 4, arrowY = -4,
  menu = { cell = { 1, 181, 1, 181 }, left = 45, right = 45, top = 35, bottom = 56,
    scale = 0.5, inset = { 16.5, 11.5, 16.5, 21.5 } } }
T.stepper = { width = 19.5, height = 18.9, bed = 29.25, icon = 13, gapLeft = 3.9,
  gapRight = 3, normal = { 431, 509, 1, 79 }, hover = { 1, 79, 345, 423 },
  pressed = { 81, 159, 425, 503 }, disabled = { 321, 399, 85, 163 },
  back = { 393, 427, 183, 217 }, backDisabled = { 429, 463, 183, 217 },
  next = { 465, 499, 183, 217 }, nextDisabled = { 393, 427, 237, 271 } }
T.slider = { width = 158.6, barHeight = 13, cap = 8.3,
  left = { 14, 25, 41, 58 }, middle = { 0, 1, 1, 18 }, right = { 1, 12, 62, 79 },
  thumb = { 1, 21, 20, 39 }, thumbWidth = 15, thumbHeight = 14.3,
  back = { 1, 12, 41, 60 }, backWidth = 8.3, backHeight = 14.3,
  forward = { 1, 10, 81, 99 }, forwardWidth = 6.9, forwardHeight = 13.65,
  stepperGap = 3, valueGap = 18.2 }
T.redButton = { sheet = 512, cellHeight = 125, bar = 291, cap = 40,
  normal = { 0, 300, 0 }, pressed = { 128, 300, 128 }, disabled = { 256, 300, 256 },
  glow = { 0, 409, 384, 456 }, glowMargin = -4, glowIntensity = 0.8 }
T.close = { normal = { 40, 74, 2, 40 }, pushed = { 40, 74, 82, 120 },
  highlight = { 116, 150, 2, 40 } }
T.scroll = { arrowWidth = 17, arrowHeight = 11, arrowGap = 8, disabledAlpha = 0.35,
  upNormal = { 1, 18, 1, 12 }, upPushed = { 1, 18, 14, 25 }, upHover = { 1, 18, 27, 38 },
  downNormal = { 20, 37, 1, 12 }, downPushed = { 1, 18, 40, 51 },
  downHover = { 20, 37, 14, 25 },
  width = 8, cap = 8, trackTop = { 39, 47, 14, 22 }, trackBottom = { 49, 57, 1, 9 },
  trackMiddle = { 1, 9 },
  minExtent = 44, thumbTop = 8, thumbBottom = 36, thumbFade = 28,
  thumbNormal = { { 39, 47, 1, 9 }, { 31, 39 }, { 40, 48, 27, 63 } },
  thumbHover = { { 1, 9, 53, 61 }, { 21, 29 }, { 20, 28, 27, 63 } },
  thumbPushed = { { 49, 57, 14, 22 }, { 11, 19 }, { 30, 38, 27, 63 } } }

T.SIDEBAR_HEIGHT = T.HEIGHT - T.PLATE_TOP - T.LIST_DROP - T.PLATE_BOTTOM
T.CONTENT_WIDTH = T.WIDTH - T.PLATE_SIDE - T.CONTENT_RIGHT
  - (T.LIST_LEFT + T.SIDEBAR_WIDTH + T.CONTAINER_GAP)
T.CANVAS_HEIGHT = T.SIDEBAR_HEIGHT - T.CONTENT_HEADER - 4

-- Helpers -------------------------------------------------------------------

local function Num(object, method)
  if not object or type(object[method]) ~= "function" then return nil end
  local ok, value = pcall(object[method], object)
  if ok then return tonumber(value) end
  return nil
end

local function Show(object, shown)
  if not object then return end
  if shown then
    if type(object.Show) == "function" then pcall(object.Show, object) end
  elseif type(object.Hide) == "function" then
    pcall(object.Hide, object)
  end
end

local function IsShown(object)
  if not object or type(object.IsShown) ~= "function" then return false end
  local ok, shown = pcall(object.IsShown, object)
  return ok and shown and true or false
end

local function NewFrame(kind, name, parent)
  if type(CreateFrame) ~= "function" then return nil end
  local ok, frame = pcall(CreateFrame, kind, name, parent)
  if ok then return frame end
  return nil
end

local function Size(object, width, height)
  if not object then return end
  if width then pcall(object.SetWidth, object, width) end
  if height then pcall(object.SetHeight, object, height) end
end

local function Place(object, point, relative, relativePoint, x, y)
  if not object then return end
  pcall(object.ClearAllPoints, object)
  pcall(object.SetPoint, object, point, relative, relativePoint, x or 0, y or 0)
end

local function Level(object, level)
  if object and level then pcall(object.SetFrameLevel, object, level) end
end

local function SetScript(object, kind, handler)
  if object and type(object.SetScript) == "function" then
    pcall(object.SetScript, object, kind, handler)
  end
end

-- The copy that matches the running version, else the newest one.
local function MediaRoot()
  local best
  local index
  for index = 1, table.getn(lib.mediaRoots) do
    local root = lib.mediaRoots[index]
    if root.minor == lib.minor then return root.path end
    if not best or root.minor > best.minor then best = root end
  end
  return best and best.path or ""
end

local function Media(name)
  return MediaRoot() .. name
end

local function NewTexture(parent, layer, name)
  if not parent or type(parent.CreateTexture) ~= "function" then return nil end
  local ok, texture = pcall(parent.CreateTexture, parent, nil, layer or "ARTWORK")
  if not ok or not texture then return nil end
  if name then pcall(texture.SetTexture, texture, Media(name)) end
  return texture
end

-- A texel cell { x0, x1, y0, y1 } on a sheet of the given size.
local function Cell(texture, cell, width, height)
  if not texture or not cell then return end
  height = height or width
  pcall(texture.SetTexCoord, texture, cell[1] / width, cell[2] / width,
    cell[3] / height, cell[4] / height)
end

local function Tint(texture, r, g, b, a)
  if texture then pcall(texture.SetVertexColor, texture, r, g, b, a or 1) end
end

local function TextColor(label, color)
  if label and color then
    pcall(label.SetTextColor, label, color[1], color[2], color[3])
  end
end

local function NewLabel(parent, template, size, color, justify)
  if not parent or type(parent.CreateFontString) ~= "function" then return nil end
  local ok, label = pcall(parent.CreateFontString, parent, nil, "OVERLAY",
    template or "GameFontNormal")
  if not ok or not label then return nil end
  if size and type(label.GetFont) == "function" then
    local fontOk, font, _, flags = pcall(label.GetFont, label)
    if fontOk and type(font) == "string" then
      if flags then
        pcall(label.SetFont, label, font, size, flags)
      else
        pcall(label.SetFont, label, font, size)
      end
    end
  end
  if justify then pcall(label.SetJustifyH, label, justify) end
  TextColor(label, color)
  return label
end

local function SetText(label, text)
  if label then pcall(label.SetText, label, text or "") end
end

local function Resolve(value)
  if type(value) == "function" then
    local ok, result = pcall(value)
    if not ok then return nil end
    value = result
  end
  if type(value) == "number" then return tostring(value) end
  if type(value) == "string" and value ~= "" then return value end
  return nil
end

local function GroupOption(group, key)
  return group and group.options and group.options[key]
end

-- pandaUI's namespace, only if it can host settings pages.
local function PandaUIHost()
  local host = getglobal and getglobal("PandaUI")
  if type(host) == "table" and type(host.RegisterSettingsTab) == "function" then
    return host
  end
  return nil
end

-- Shows a page region and the parts it owns: parent visibility does not
-- reliably reach children on this client.
local function ShowWidget(widget, shown)
  if type(widget) ~= "table" then return end
  if type(widget.puiSetShown) == "function" then
    widget.puiSetShown(shown)
    return
  end
  if type(widget.puiParts) == "table" then
    local index
    for index = 1, table.getn(widget.puiParts) do
      ShowWidget(widget.puiParts[index], shown)
    end
    return
  end
  Show(widget, shown)
  if type(widget.label) == "table" then Show(widget.label, shown) end
end

local function ShowList(widgets, shown)
  if type(widgets) ~= "table" then return end
  local index
  for index = 1, table.getn(widgets) do ShowWidget(widgets[index], shown) end
end

-- Media and registration ------------------------------------------------------

function lib.AddMediaRoot(path, minor)
  if type(path) ~= "string" or path == "" then return false end
  local index
  for index = 1, table.getn(lib.mediaRoots) do
    if lib.mediaRoots[index].path == path then return true end
  end
  table.insert(lib.mediaRoots, { path = path, minor = tonumber(minor) or 0 })
  return true
end

function lib.FindGroup(id)
  local index
  for index = 1, table.getn(lib.groups) do
    if lib.groups[index].id == id then return lib.groups[index], index end
  end
  return nil
end

function lib.FindPage(id)
  local groupIndex, pageIndex
  for groupIndex = 1, table.getn(lib.groups) do
    local pages = lib.groups[groupIndex].pages
    for pageIndex = 1, table.getn(pages) do
      if pages[pageIndex].id == id then return pages[pageIndex] end
    end
  end
  return nil
end

function lib.RegisterSettingsGroup(id, label, options)
  if type(id) ~= "string" or id == "" or lib.FindGroup(id) then return nil end
  local group = { id = id, label = type(label) == "string" and label or id,
    options = type(options) == "table" and options or {}, pages = {} }
  table.insert(lib.groups, group)
  table.sort(lib.groups, function(a, b) return a.id < b.id end)
  lib.Changed()
  return group
end

function lib.RegisterSettingsTab(id, label, build, options)
  if type(id) ~= "string" or type(build) ~= "function" or lib.FindPage(id) then
    return nil
  end
  options = type(options) == "table" and options or {}
  local group = options.parent and lib.FindGroup(options.parent)
  if not group then
    if options.parent then return nil end
    group = lib.RegisterSettingsGroup(id, label, options)
    if not group then return nil end
  end
  local page = { id = id, label = type(label) == "string" and label or id,
    build = build, group = group }
  local position = table.getn(group.pages) + 1
  local index
  for index = 1, table.getn(group.pages) do
    if group.pages[index].id == options.after then position = index + 1 end
  end
  table.insert(group.pages, position, page)
  lib.Changed()
  return page
end

function lib.UnregisterSettingsGroup(id)
  local group, position = lib.FindGroup(id)
  if not group then return false end
  local ui = lib.ui
  local index
  for index = 1, table.getn(group.pages) do
    ShowList(group.pages[index].widgets, false)
    if ui.active == group.pages[index] then ui.active = nil end
    if ui.last == group.pages[index] then ui.last = nil end
  end
  table.remove(lib.groups, position)
  if IsShown(ui.panel) then
    local first = lib.FirstPage()
    if ui.active == nil and first then
      lib.SelectPage(first)
    elseif not first then
      lib.CloseSettings()
    end
  end
  lib.Changed()
  return true
end

function lib.FirstPage()
  local index
  for index = 1, table.getn(lib.groups) do
    local pages = lib.groups[index].pages
    if pages[1] then return pages[1] end
  end
  return nil
end

-- A page id, a group id (its defaultPage or its first page), or nil.
function lib.ResolvePage(id)
  local page = id and lib.FindPage(id)
  if page then return page end
  local group = id and lib.FindGroup(id)
  if group then
    local default = GroupOption(group, "defaultPage")
    return (default and lib.FindPage(default)) or group.pages[1]
  end
  return nil
end

function lib.Changed()
  lib.RefreshMinimapButton()
  if IsShown(lib.ui.panel) then lib.RenderList() end
end

-- Stored values and the shared language -------------------------------------

function lib.Get(key)
  local index
  for index = 1, table.getn(lib.groups) do
    local get = GroupOption(lib.groups[index], "get")
    if type(get) == "function" then
      local ok, value = pcall(get, key)
      if ok and value ~= nil then return value end
    end
  end
  return nil
end

function lib.Set(key, value)
  local index
  for index = 1, table.getn(lib.groups) do
    local set = GroupOption(lib.groups[index], "set")
    if type(set) == "function" then pcall(set, key, value) end
  end
end

-- Hidden as soon as one addon has it hidden; shown or hidden for all at once.
function lib.IsMinimapButtonShown()
  local index
  for index = 1, table.getn(lib.groups) do
    local get = GroupOption(lib.groups[index], "get")
    if type(get) == "function" then
      local ok, value = pcall(get, "minimapButton")
      if ok and value == false then return false end
    end
  end
  return true
end

function lib.SetMinimapButtonShown(shown)
  shown = shown and true or false
  lib.Set("minimapButton", shown)
  lib.RefreshMinimapButton()
  return shown
end

local function GroupSpeaks(group, code)
  local languages = GroupOption(group, "languages")
  if type(languages) ~= "table" then return false end
  local index
  for index = 1, table.getn(languages) do
    if type(languages[index]) == "table" and languages[index].code == code then
      return true
    end
  end
  return false
end

function lib.GetLanguage()
  local index
  for index = 1, table.getn(lib.groups) do
    local get = GroupOption(lib.groups[index], "getLanguage")
    if type(get) == "function" then
      local ok, code = pcall(get)
      if ok and type(code) == "string" then return code end
    end
  end
  return nil
end

-- One language for every addon that has it. Only the first addon that
-- changed announces it; each asks for its own /reload line.
function lib.SetLanguage(code)
  local announced = false
  local index
  for index = 1, table.getn(lib.groups) do
    local group = lib.groups[index]
    local set = GroupOption(group, "setLanguage")
    if type(set) == "function" and GroupSpeaks(group, code) then
      local ok, changed = pcall(set, code, announced)
      if ok and changed then announced = true end
    end
  end
  lib.RefreshFlags()
  return announced
end

-- The minimap button -----------------------------------------------------------

-- On the minimap ring at pandaUI's settings-button angle, as a named child of
-- Minimap so minimap-button collectors treat it as one.
function lib.PlaceMinimapButton(button)
  local minimap = getglobal and getglobal("Minimap")
  if minimap and type(cos) == "function" and type(sin) == "function" then
    local width = Num(minimap, "GetWidth")
    if not width or width <= 0 then width = 140 end
    local radius = width / 2 + T.MINIMAP_OUTSET
    Place(button, "CENTER", minimap, "CENTER", radius * cos(T.MINIMAP_ANGLE),
      radius * sin(T.MINIMAP_ANGLE))
    return "Minimap ring at " .. T.MINIMAP_ANGLE
  end
  local cluster = getglobal and getglobal("MinimapCluster")
  if cluster then
    Place(button, "TOPRIGHT", cluster, "TOPLEFT", -6, -6)
    return "MinimapCluster"
  end
  Place(button, "TOPRIGHT", UIParent, "TOPRIGHT", -8, -8)
  return "UIParent (no minimap found)"
end

function lib.MinimapTooltip(button)
  local tooltip = getglobal and getglobal("GameTooltip")
  if not tooltip then return end
  pcall(tooltip.SetOwner, tooltip, button, "ANCHOR_LEFT")
  pcall(tooltip.SetText, tooltip, T.TITLE, T.GOLD[1], T.GOLD[2], T.GOLD[3])
  local hint
  local index
  for index = 1, table.getn(lib.groups) do
    local group = lib.groups[index]
    pcall(tooltip.AddLine, tooltip, group.label, 1, 1, 1)
    hint = hint or Resolve(GroupOption(group, "minimapTooltip"))
  end
  if hint then pcall(tooltip.AddLine, tooltip, hint, 0.7, 0.7, 0.7) end
  pcall(tooltip.Show, tooltip)
end

function lib.EnsureMinimapButton()
  local ui = lib.ui
  if ui.minimap then return ui.minimap end
  local minimap = getglobal and getglobal("Minimap")
  local button = NewFrame("Button", "PandaSettingsMinimapButton", minimap or UIParent)
  if not button then return nil end
  ui.minimap = button
  Size(button, T.MINIMAP_SIZE, T.MINIMAP_SIZE)
  pcall(button.EnableMouse, button, true)
  pcall(button.RegisterForClicks, button, "LeftButtonUp")
  if minimap then Level(button, (Num(minimap, "GetFrameLevel") or 0) + 5) end

  local icon = NewTexture(button, "ARTWORK", "panda-icon")
  if icon then
    Size(icon, T.MINIMAP_ICON, T.MINIMAP_ICON)
    Place(icon, "CENTER", button, "CENTER", 0, 0)
    button.icon = icon
  end
  if pcall(button.SetHighlightTexture, button, T.MINIMAP_HIGHLIGHT) then
    local ok, glow = pcall(button.GetHighlightTexture, button)
    if ok and glow then
      pcall(glow.SetAllPoints, glow, button)
      pcall(glow.SetBlendMode, glow, "ADD")
    end
  end

  ui.minimapAnchor = lib.PlaceMinimapButton(button)
  SetScript(button, "OnClick", function() lib.ToggleSettings() end)
  SetScript(button, "OnEnter", function() lib.MinimapTooltip(button) end)
  SetScript(button, "OnLeave", function()
    local tooltip = getglobal and getglobal("GameTooltip")
    if tooltip then pcall(tooltip.Hide, tooltip) end
  end)
  return button
end

function lib.RefreshMinimapButton()
  local wanted = table.getn(lib.groups) > 0 and not PandaUIHost()
  if not wanted then
    Show(lib.ui.minimap, false)
    if PandaUIHost() and IsShown(lib.ui.panel) then lib.CloseSettings() end
    return false
  end
  local button = lib.EnsureMinimapButton()
  local shown = lib.IsMinimapButtonShown()
  Show(button, shown)
  return shown
end

function lib.GetMinimapButtonAnchor()
  return lib.ui.minimapAnchor
end

-- Shared ticker: the thumb drags and the deferred relayout ----------------------

function lib.Ticker()
  local ui = lib.ui
  if ui.ticker then return ui.ticker end
  local frame = NewFrame("Frame", nil, UIParent)
  if not frame then return nil end
  ui.ticker = frame
  ui.drags = {}
  SetScript(frame, "OnUpdate", function()
    local busy = false
    local drag
    for drag in pairs(ui.drags) do
      busy = true
      drag.Tick()
    end
    if ui.relayout then
      ui.relayout = ui.relayout - 1
      if ui.relayout <= 0 then
        ui.relayout = nil
        lib.Layout()
      else
        busy = true
      end
    end
    if not busy then Show(frame, false) end
  end)
  Show(frame, false)
  return frame
end

function lib.RequestRelayout()
  local ticker = lib.Ticker()
  lib.ui.relayout = 2
  Show(ticker, true)
end

-- One press-and-drag for every thumb: it follows from the press, the handle is
-- moved natively and only re-anchored after the release, and GetPoint is never
-- read from it.
function lib.AttachThumbDrag(handle, onPress, onMove, onRelease)
  local drag = { active = false, moving = false }
  pcall(handle.EnableMouse, handle, true)
  pcall(handle.RegisterForDrag, handle, "LeftButton")

  local function NativeMove()
    if drag.moving then return end
    if not pcall(handle.SetMovable, handle, true) then return end
    if pcall(handle.StartMoving, handle) then
      pcall(handle.StopMovingOrSizing, handle)
    end
    drag.moving = pcall(handle.StartMoving, handle) and true or false
  end

  function drag.Finish()
    if not drag.active then return end
    drag.active = false
    drag.moving = false
    if lib.ui.drags then lib.ui.drags[drag] = nil end
    pcall(handle.StopMovingOrSizing, handle)
    onRelease()
  end

  function drag.Tick()
    onMove()
  end

  local function Begin()
    if drag.active then return end
    if onPress() == false then return end
    drag.active = true
    NativeMove()
    local ticker = lib.Ticker()
    if ticker then
      lib.ui.drags[drag] = true
      Show(ticker, true)
    end
    onMove()
  end

  SetScript(handle, "OnMouseDown", function()
    if arg1 and arg1 ~= "LeftButton" then return end
    Begin()
  end)
  SetScript(handle, "OnMouseUp", function() drag.Finish() end)
  SetScript(handle, "OnDragStart", function()
    Begin()
    if drag.active then NativeMove() end
  end)
  SetScript(handle, "OnDragStop", function() drag.Finish() end)
  SetScript(handle, "OnHide", function() drag.Finish() end)
  return drag
end

-- The cursor in `object`'s own units.
local function Cursor(object)
  if type(GetCursorPosition) ~= "function" then return nil end
  local ok, x, y = pcall(GetCursorPosition)
  local scale = Num(object, "GetEffectiveScale")
  if not ok or not tonumber(x) or not tonumber(y) or not scale or scale <= 0 then
    return nil
  end
  return x / scale, y / scale
end

-- Window chrome -------------------------------------------------------------

-- One member of the Options atlas at an exact drawn size, rebuilt from the
-- four 512 tiles (OctoWoW drops the 1024 sheet; M.foreverWow.optionsTiles).
function lib.OptionsCell(parent, layer, cell, width, height)
  local frame = NewFrame("Frame", nil, parent)
  if not frame then return nil end
  pcall(frame.EnableMouse, frame, false)
  Level(frame, Num(parent, "GetFrameLevel"))
  Size(frame, width, height)
  local x0, x1, y0, y1 = cell[1], cell[2], cell[3], cell[4]
  local sourceWidth, sourceHeight = x1 - x0, y1 - y0
  if sourceWidth <= 0 or sourceHeight <= 0 then return frame end
  local tiles = { { 0, 0, "options-0-0" }, { 512, 0, "options-1-0" },
    { 0, 512, "options-0-1" }, { 512, 512, "options-1-1" } }
  local index
  for index = 1, 4 do
    local tile = tiles[index]
    local left = math.max(x0, tile[1])
    local right = math.min(x1, tile[1] + 512)
    local top = math.max(y0, tile[2])
    local bottom = math.min(y1, tile[2] + 512)
    if right > left and bottom > top then
      local texture = NewTexture(frame, layer, tile[3])
      if texture then
        pcall(texture.SetTexCoord, texture, (left - tile[1]) / 512,
          (right - tile[1]) / 512, (top - tile[2]) / 512, (bottom - tile[2]) / 512)
        Size(texture, width * (right - left) / sourceWidth,
          height * (bottom - top) / sourceHeight)
        Place(texture, "TOPLEFT", frame, "TOPLEFT",
          width * (left - x0) / sourceWidth, -height * (top - y0) / sourceHeight)
      end
    end
  end
  return frame
end

function lib.BuildBackground(panel)
  local body = T.rim.body
  local bg = NewFrame("Frame", nil, panel)
  if not bg then return end
  pcall(bg.EnableMouse, bg, false)
  Level(bg, Num(panel, "GetFrameLevel"))
  Size(bg, T.WIDTH - body[1] - body[3], T.HEIGHT - body[2] - body[4])
  Place(bg, "TOPLEFT", panel, "TOPLEFT", body[1], -body[2])
  local color = T.PANEL_COLOR
  local bottomLeft = NewTexture(bg, "BACKGROUND", "panel-background")
  local bottomRight = NewTexture(bg, "BACKGROUND", "panel-background")
  Cell(bottomLeft, { 1, 17, 1, 17 }, 64, 32)
  Cell(bottomRight, { 19, 35, 1, 17 }, 64, 32)
  Size(bottomLeft, 16, 16)
  Size(bottomRight, 16, 16)
  Place(bottomLeft, "BOTTOMLEFT", bg, "BOTTOMLEFT", 0, 0)
  Place(bottomRight, "BOTTOMRIGHT", bg, "BOTTOMRIGHT", 0, 0)
  local edge = NewTexture(bg, "BACKGROUND")
  local top = NewTexture(bg, "BACKGROUND")
  if edge then
    pcall(edge.SetTexture, edge, "Interface\\Buttons\\WHITE8X8")
    pcall(edge.SetPoint, edge, "TOPLEFT", bg, "BOTTOMLEFT", 16, 16)
    pcall(edge.SetPoint, edge, "BOTTOMRIGHT", bg, "BOTTOMRIGHT", -16, 0)
  end
  if top then
    pcall(top.SetTexture, top, "Interface\\Buttons\\WHITE8X8")
    pcall(top.SetPoint, top, "TOPLEFT", bg, "TOPLEFT", 0, 0)
    pcall(top.SetPoint, top, "BOTTOMRIGHT", bg, "BOTTOMRIGHT", 0, 16)
  end
  local pieces = { bottomLeft, bottomRight, edge, top }
  local index
  for index = 1, 4 do
    Tint(pieces[index], color[1], color[2], color[3], color[4])
  end
end

-- Options_InnerFrame as a 5x3 grid: rims and the list/page seam drawn 1:1,
-- the two flat fields squeezed (M.foreverWow.options.innerSlice).
function lib.BuildPlate(panel)
  local o = T.options
  local s = o.slice
  local width = T.WIDTH - 2 * T.PLATE_SIDE
  local height = T.HEIGHT - T.PLATE_TOP - T.PLATE_BOTTOM
  local plate = NewFrame("Frame", nil, panel)
  if not plate then return nil end
  pcall(plate.EnableMouse, plate, false)
  Level(plate, (Num(panel, "GetFrameLevel") or 0) + 1)
  Size(plate, width, height)
  Place(plate, "TOPLEFT", panel, "TOPLEFT", T.PLATE_SIDE, -T.PLATE_TOP)

  local seam = (T.LIST_LEFT - T.PLATE_SIDE) + T.SIDEBAR_WIDTH
  local x0, y0 = o.inner[1], o.inner[3]
  local columns = {
    { 0, s.rim, 0, s.rim },
    { s.rim, s.seam, s.rim, seam - s.rim },
    { s.seam, s.seam + s.seamKeep, seam, s.seamKeep },
    { s.seam + s.seamKeep, o.innerWidth - s.keepRight, seam + s.seamKeep,
      width - seam - s.seamKeep - s.keepRight },
    { o.innerWidth - s.keepRight, o.innerWidth, width - s.keepRight, s.keepRight },
  }
  local rows = {
    { 0, s.top, 0, s.top },
    { s.top, o.innerHeight - s.bottom, s.top, height - s.top - s.bottom },
    { o.innerHeight - s.bottom, o.innerHeight, height - s.bottom, s.bottom },
  }
  local i, j
  for i = 1, 5 do
    local column = columns[i]
    for j = 1, 3 do
      local row = rows[j]
      local piece = lib.OptionsCell(plate, "BACKGROUND",
        { x0 + column[1], x0 + column[2], y0 + row[1], y0 + row[2] },
        column[4], row[4])
      Place(piece, "TOPLEFT", plate, "TOPLEFT", column[3], -row[3])
    end
  end
  return plate
end

function lib.BuildRim(panel)
  local r = T.rim
  local rim = NewFrame("Frame", nil, panel)
  if not rim then return nil end
  pcall(rim.SetAllPoints, rim, panel)
  pcall(rim.EnableMouse, rim, false)
  Level(rim, (Num(panel, "GetFrameLevel") or 0) + 6)
  local function Corner(spec, point, x, y)
    local piece = NewTexture(rim, "OVERLAY", "metal-corners")
    if not piece then return nil end
    local c = spec[3]
    pcall(piece.SetTexCoord, piece, c[1], c[2], c[3], c[4])
    Size(piece, spec[1], spec[2])
    Place(piece, point, panel, point, x, y)
    return piece
  end
  local tl = Corner(r.topLeft, "TOPLEFT", r.left, r.top)
  local tr = Corner(r.topRight, "TOPRIGHT", r.right, r.top)
  local bl = Corner(r.bottomLeft, "BOTTOMLEFT", r.left, r.bottom)
  local br = Corner(r.bottomRight, "BOTTOMRIGHT", r.right, r.bottom)
  local function Rail(name, spec, first, firstPoint, firstRel, second, secondPoint,
      secondRel, horizontal)
    local piece = NewTexture(rim, "OVERLAY", name)
    if not piece or not first or not second then return end
    local c = spec[2]
    pcall(piece.SetTexCoord, piece, c[1], c[2], c[3], c[4])
    if horizontal then Size(piece, nil, spec[1]) else Size(piece, spec[1], nil) end
    pcall(piece.SetPoint, piece, firstPoint, first, firstRel, 0, 0)
    pcall(piece.SetPoint, piece, secondPoint, second, secondRel, 0, 0)
  end
  Rail("metal-horizontal", r.edgeTop, tl, "TOPLEFT", "TOPRIGHT", tr, "TOPRIGHT",
    "TOPLEFT", true)
  Rail("metal-horizontal", r.edgeBottom, bl, "TOPLEFT", "TOPRIGHT", br, "TOPRIGHT",
    "TOPLEFT", true)
  Rail("metal-vertical", r.edgeLeft, tl, "TOPLEFT", "BOTTOMLEFT", bl, "BOTTOMLEFT",
    "TOPLEFT", false)
  Rail("metal-vertical", r.edgeRight, tr, "TOPRIGHT", "BOTTOMRIGHT", br,
    "BOTTOMRIGHT", "TOPRIGHT", false)
  return rim
end

-- The 128RedButton face (gs.DressButton): resting face, a pressed row, a grey
-- disabled row, and an additive glow while hovered. Gold label, white on hover.
function lib.PaintButton(button)
  local face = button and button.psFace
  if not face then return end
  local token = T.redButton
  local enabled = 1
  if type(button.IsEnabled) == "function" then
    local ok, value = pcall(button.IsEnabled, button)
    if ok then enabled = value end
  end
  local disabled = enabled == 0 or enabled == false or enabled == nil
  local wanted = disabled and "disabled" or (face.down and "pressed" or "normal")
  if face.painted ~= wanted then
    face.painted = wanted
    local cell = token[wanted]
    local sheet, rowHeight = token.sheet, token.cellHeight
    local function Slice(texture, left, right, top)
      pcall(texture.SetTexCoord, texture, left / sheet, right / sheet, top / sheet,
        (top + rowHeight) / sheet)
    end
    Slice(face.left, cell[2], cell[2] + token.cap, cell[3])
    Slice(face.middle, 0, token.bar - token.cap, cell[1])
    Slice(face.right, token.bar - token.cap, token.bar, cell[1])
  end
  Show(face.glow, face.over and not face.down and not disabled)
  local color = T.GOLD
  if disabled then
    color = T.GREY
  elseif face.over then
    color = T.WHITE
  end
  TextColor(button.psLabel, color)
end

local function ChainScript(object, kind, handler)
  local old
  if type(object.GetScript) == "function" then
    local ok, existing = pcall(object.GetScript, object, kind)
    if ok then old = existing end
  end
  SetScript(object, kind, function()
    if type(old) == "function" then old() end
    handler()
  end)
end

function lib.DressButton(button, height)
  if not button or button.psFace then return false end
  height = height or Num(button, "GetHeight") or T.BUTTON_HEIGHT
  if type(button.GetRegions) == "function" then
    local ok, regions = pcall(function() return { button:GetRegions() } end)
    if ok and type(regions) == "table" then
      local index
      for index = 1, table.getn(regions) do
        local region = regions[index]
        if type(region) == "table" and type(region.GetObjectType) == "function" then
          local typeOk, kind = pcall(region.GetObjectType, region)
          if typeOk and kind == "Texture" then Show(region, false) end
        end
      end
    end
  end
  local face = {}
  face.left = NewTexture(button, "BACKGROUND", "red-button-128")
  face.middle = NewTexture(button, "BACKGROUND", "red-button-128")
  face.right = NewTexture(button, "BACKGROUND", "red-button-128")
  if not face.left or not face.middle or not face.right then return false end
  local token = T.redButton
  local capWidth = height * token.cap / token.cellHeight
  Size(face.left, capWidth, nil)
  Size(face.right, capWidth, nil)
  pcall(face.left.SetPoint, face.left, "TOPLEFT", button, "TOPLEFT", 0, 0)
  pcall(face.left.SetPoint, face.left, "BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  pcall(face.right.SetPoint, face.right, "TOPRIGHT", button, "TOPRIGHT", 0, 0)
  pcall(face.right.SetPoint, face.right, "BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
  pcall(face.middle.SetPoint, face.middle, "TOPLEFT", face.left, "TOPRIGHT", 0, 0)
  pcall(face.middle.SetPoint, face.middle, "BOTTOMRIGHT", face.right, "BOTTOMLEFT", 0, 0)
  face.glow = NewTexture(button, "OVERLAY", "red-button-128")
  if face.glow then
    Cell(face.glow, token.glow, token.sheet)
    pcall(face.glow.SetBlendMode, face.glow, "ADD")
    local margin = token.glowMargin
    pcall(face.glow.SetPoint, face.glow, "TOPLEFT", button, "TOPLEFT", -margin, margin)
    pcall(face.glow.SetPoint, face.glow, "BOTTOMRIGHT", button, "BOTTOMRIGHT",
      margin, -margin)
    Tint(face.glow, token.glowIntensity, token.glowIntensity, token.glowIntensity, 1)
    Show(face.glow, false)
  end
  button.psFace = face

  local label = button.label or button.pandaQuestLabel
  if not label and type(button.GetFontString) == "function" then
    local ok, found = pcall(button.GetFontString, button)
    if ok then label = found end
  end
  button.psLabel = label
  if label then
    Place(label, "CENTER", button, "CENTER", 0, 0)
    pcall(label.SetJustifyH, label, "CENTER")
  end

  ChainScript(button, "OnEnter", function() face.over = true; lib.PaintButton(button) end)
  ChainScript(button, "OnLeave", function()
    face.over = false
    face.down = false
    lib.PaintButton(button)
  end)
  ChainScript(button, "OnMouseDown", function() face.down = true; lib.PaintButton(button) end)
  ChainScript(button, "OnMouseUp", function() face.down = false; lib.PaintButton(button) end)
  ChainScript(button, "OnShow", function() lib.PaintButton(button) end)
  local enable, disable = button.Enable, button.Disable
  if type(enable) == "function" then
    button.Enable = function(self)
      enable(self)
      lib.PaintButton(button)
    end
  end
  if type(disable) == "function" then
    button.Disable = function(self)
      disable(self)
      lib.PaintButton(button)
    end
  end
  lib.PaintButton(button)
  return true
end

-- A page's own native Buttons (an action such as "Search") wear the red face,
-- as pandaUI's window dresses them (gs.StyleOwnedButton).
function lib.StyleWidgets(widgets)
  if type(widgets) ~= "table" then return end
  local index
  for index = 1, table.getn(widgets) do
    local widget = widgets[index]
    if type(widget) == "table" and type(widget.GetObjectType) == "function"
        and not widget.psFace and not widget.puiFlag then
      local ok, kind = pcall(widget.GetObjectType, widget)
      local height = Num(widget, "GetHeight")
      if ok and kind == "Button" and height and height >= 8 and height <= 40 then
        lib.DressButton(widget, height)
      end
    end
  end
end

function lib.NewRedButton(parent, name, text, width, height, onClick)
  local button = NewFrame("Button", name, parent)
  if not button then return nil end
  Size(button, width, height)
  pcall(button.EnableMouse, button, true)
  pcall(button.RegisterForClicks, button, "LeftButtonUp")
  local label = NewLabel(button, "GameFontNormal", 11, T.GOLD, "CENTER")
  SetText(label, text)
  button.label = label
  SetScript(button, "OnClick", function() if onClick then onClick() end end)
  lib.DressButton(button, height)
  return button
end

function lib.BuildCloseX(panel)
  local button = NewFrame("Button", "PandaSettingsWindowCloseX", panel)
  if not button then return end
  Size(button, T.CLOSE_SIZE, T.CLOSE_SIZE)
  pcall(button.EnableMouse, button, true)
  pcall(button.RegisterForClicks, button, "LeftButtonUp")
  Level(button, (Num(panel, "GetFrameLevel") or 0) + 12)
  Place(button, "RIGHT", panel, "TOPRIGHT", T.CLOSE_X, -T.HEADER / 2 + T.CLOSE_Y)
  local face = NewTexture(button, "ARTWORK", "red-button")
  local glow = NewTexture(button, "OVERLAY", "red-button")
  if face then pcall(face.SetAllPoints, face, button) end
  if glow then
    pcall(glow.SetAllPoints, glow, button)
    Cell(glow, T.close.highlight, 256, 128)
    pcall(glow.SetBlendMode, glow, "ADD")
    Show(glow, false)
  end
  local state = {}
  local function Paint()
    Cell(face, state.down and T.close.pushed or T.close.normal, 256, 128)
    Show(glow, state.over)
  end
  SetScript(button, "OnEnter", function() state.over = true; Paint() end)
  SetScript(button, "OnLeave", function() state.over = false; state.down = false; Paint() end)
  SetScript(button, "OnMouseDown", function() state.down = true; Paint() end)
  SetScript(button, "OnMouseUp", function() state.down = false; Paint() end)
  SetScript(button, "OnClick", function() lib.CloseSettings() end)
  Paint()
end

-- Window position: measured edges, re-anchored BOTTOMLEFT on UIParent, in the
-- window's own units. Never GetPoint after the client moved it.
function lib.CapturePosition()
  local panel = lib.ui.panel
  local left, bottom = Num(panel, "GetLeft"), Num(panel, "GetBottom")
  if not left or not bottom then return end
  Place(panel, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
  lib.Set("settingsPoint", "BOTTOMLEFT")
  lib.Set("settingsX", left)
  lib.Set("settingsY", bottom)
end

function lib.ApplyPosition()
  local panel = lib.ui.panel
  local x, y = tonumber(lib.Get("settingsX")), tonumber(lib.Get("settingsY"))
  if lib.Get("settingsPoint") ~= "BOTTOMLEFT" or not x or not y then
    Place(panel, "CENTER", UIParent, "CENTER", 0, 0)
    return
  end
  -- Back to the centre when the stored corner would leave the window off
  -- screen (another resolution or UI scale).
  local own = Num(panel, "GetEffectiveScale")
  local parent = Num(UIParent, "GetEffectiveScale")
  local width, height = Num(UIParent, "GetWidth"), Num(UIParent, "GetHeight")
  if own and parent and own > 0 and width and height and width > 0 then
    local ratio = parent / own
    if x < 0 or y < 0 or x + T.WIDTH > width * ratio or y + T.HEIGHT > height * ratio then
      Place(panel, "CENTER", UIParent, "CENTER", 0, 0)
      return
    end
  end
  Place(panel, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

-- One on-screen size whatever the client's UI scale, as pandaUI's window.
function lib.ApplyScale()
  local panel = lib.ui.panel
  pcall(panel.SetScale, panel, 1)
  local parent = Num(UIParent, "GetEffectiveScale")
  if parent and parent > 0 then pcall(panel.SetScale, panel, T.SCREEN_SCALE / parent) end
end

function lib.BuildHandle(panel)
  local handle = NewFrame("Button", nil, panel)
  if not handle then return end
  Size(handle, T.WIDTH - 40, T.HEADER)
  Place(handle, "TOPLEFT", panel, "TOPLEFT", 0, 0)
  Level(handle, (Num(panel, "GetFrameLevel") or 0) + 10)
  pcall(handle.EnableMouse, handle, true)
  pcall(handle.RegisterForDrag, handle, "LeftButton")
  SetScript(handle, "OnDragStart", function()
    pcall(panel.SetMovable, panel, true)
    if pcall(panel.StartMoving, panel) then pcall(panel.StopMovingOrSizing, panel) end
    pcall(panel.StartMoving, panel)
  end)
  SetScript(handle, "OnDragStop", function()
    pcall(panel.StopMovingOrSizing, panel)
    lib.CapturePosition()
  end)
end

-- The sidebar ----------------------------------------------------------------

function lib.NewHeader(index)
  local ui = lib.ui
  local header = NewFrame("Frame", "PandaSettingsWindowHeader" .. index, ui.sidebar)
  if not header then return nil end
  Size(header, T.SIDEBAR_WIDTH, T.HEADER_ROW)
  pcall(header.EnableMouse, header, false)
  local art = lib.OptionsCell(header, "ARTWORK", T.options.categoryHeader,
    T.SIDEBAR_WIDTH, T.options.categoryHeaderHeight)
  Place(art, "TOPLEFT", header, "TOPLEFT", 0, 0)
  header.art = art
  local logo = NewTexture(header, "OVERLAY")
  Size(logo, T.CATEGORY_LOGO, T.CATEGORY_LOGO)
  Place(logo, "LEFT", header, "LEFT", T.ROW_LABEL_INSET, 0)
  header.logo = logo
  header.label = NewLabel(header, "GameFontHighlight", 11, T.WHITE, "LEFT")
  return header
end

function lib.NewRow(index)
  local ui = lib.ui
  local row = NewFrame("Button", "PandaSettingsWindowRow" .. index, ui.sidebar)
  if not row then return nil end
  Size(row, T.ROW_WIDTH, T.ROW_HEIGHT)
  pcall(row.EnableMouse, row, true)
  pcall(row.RegisterForClicks, row, "LeftButtonUp")
  local function Plate(cell)
    local plate = lib.OptionsCell(row, "BACKGROUND", cell, T.ROW_PLATE, 21)
    Place(plate, "CENTER", row, "CENTER", 6, 0)
    Show(plate, false)
    return plate
  end
  row.hover = Plate(T.options.rowHover)
  row.active = Plate(T.options.rowActive)
  local inset = T.ROW_LABEL_INSET + T.SUB_INDENT
  row.label = NewLabel(row, "GameFontNormal", 11, T.DIM, "LEFT")
  if row.label then
    Place(row.label, "LEFT", row, "LEFT", inset, 0)
    Size(row.label, T.ROW_WIDTH - inset - 4, nil)
  end
  SetScript(row, "OnEnter", function() if not row.selected then Show(row.hover, true) end end)
  SetScript(row, "OnLeave", function() Show(row.hover, false) end)
  SetScript(row, "OnClick", function()
    if row.page then lib.SelectPage(row.page) end
  end)
  return row
end

function lib.GroupTitle(group)
  local version = Resolve(GroupOption(group, "version"))
  if not version then return group.label end
  return group.label .. " |cff999999v" .. version .. "|r"
end

function lib.RenderList()
  local ui = lib.ui
  if not ui.sidebar then return end
  ui.headers = ui.headers or {}
  ui.rows = ui.rows or {}
  local y = 0
  local headers, rows = 0, 0
  local groupIndex, pageIndex
  for groupIndex = 1, table.getn(lib.groups) do
    local group = lib.groups[groupIndex]
    headers = headers + 1
    local header = ui.headers[headers] or lib.NewHeader(headers)
    ui.headers[headers] = header
    if header then
      local icon = GroupOption(group, "icon")
      if header.logo and type(icon) == "string" then
        pcall(header.logo.SetTexture, header.logo, icon)
        Show(header.logo, true)
        Place(header.label, "LEFT", header.logo, "RIGHT", T.LOGO_GAP, 0)
      else
        Show(header.logo, false)
        Place(header.label, "LEFT", header, "LEFT", T.ROW_LABEL_INSET, 0)
      end
      SetText(header.label, lib.GroupTitle(group))
      Place(header, "TOPLEFT", ui.sidebar, "TOPLEFT", 0, -y)
      Show(header, y + T.HEADER_ROW <= T.SIDEBAR_HEIGHT)
      y = y + T.HEADER_ROW
    end
    for pageIndex = 1, table.getn(group.pages) do
      local page = group.pages[pageIndex]
      rows = rows + 1
      local row = ui.rows[rows] or lib.NewRow(rows)
      ui.rows[rows] = row
      if row then
        row.page = page
        row.selected = ui.active == page
        SetText(row.label, page.label)
        TextColor(row.label, row.selected and T.WHITE or T.DIM)
        Show(row.active, row.selected)
        if row.selected then Show(row.hover, false) end
        Place(row, "TOPLEFT", ui.sidebar, "TOPLEFT", 0, -y)
        Show(row, y + T.ROW_HEIGHT <= T.SIDEBAR_HEIGHT)
        y = y + T.ROW_HEIGHT
      end
    end
  end
  local index
  for index = headers + 1, table.getn(ui.headers) do Show(ui.headers[index], false) end
  for index = rows + 1, table.getn(ui.rows) do
    if ui.rows[index] then
      ui.rows[index].page = nil
      Show(ui.rows[index], false)
    end
  end
  lib.RefreshFlags()
end

-- The language flags ----------------------------------------------------------

function lib.ShadeFlag(flag, shade)
  Tint(flag.icon, 1, 1, 1, shade)
  if flag.badge then
    TextColor(flag.badge, flag.selected and T.GOLD or T.DIM)
  end
end

function lib.NewFlag(code)
  local ui = lib.ui
  local flag = NewFrame("Button", "PandaSettingsWindowLanguage" .. code, ui.content)
  if not flag then return nil end
  Size(flag, T.FLAG_WIDTH, T.FLAG_HEIGHT)
  pcall(flag.EnableMouse, flag, true)
  pcall(flag.RegisterForClicks, flag, "LeftButtonUp")
  Level(flag, (Num(ui.content, "GetFrameLevel") or 0) + 4)
  flag.code = code
  local file = T.FLAGS[code]
  if file then
    flag.icon = NewTexture(flag, "ARTWORK", file)
    if flag.icon then pcall(flag.icon.SetAllPoints, flag.icon, flag) end
  else
    flag.badge = NewLabel(flag, "GameFontHighlightSmall", nil, T.DIM, "CENTER")
    Place(flag.badge, "CENTER", flag, "CENTER", 0, 0)
    SetText(flag.badge, string.sub(code, 1, 2))
  end
  SetScript(flag, "OnClick", function() lib.SetLanguage(code) end)
  SetScript(flag, "OnEnter", function()
    if not flag.selected then lib.ShadeFlag(flag, T.FLAG_HOVER) end
  end)
  SetScript(flag, "OnLeave", function()
    if not flag.selected then lib.ShadeFlag(flag, T.FLAG_IDLE) end
  end)
  return flag
end

function lib.RefreshFlags()
  local ui = lib.ui
  if not ui.content then return end
  ui.flags = ui.flags or {}
  local codes = {}
  local index, groupIndex
  for index = 1, table.getn(T.LANGUAGES) do
    local code = T.LANGUAGES[index]
    for groupIndex = 1, table.getn(lib.groups) do
      if GroupSpeaks(lib.groups[groupIndex], code) then
        table.insert(codes, code)
        break
      end
    end
  end
  local shown = {}
  local active = lib.GetLanguage()
  local count = table.getn(codes)
  for index = 1, count do
    local code = codes[index]
    local flag = ui.flags[code] or lib.NewFlag(code)
    ui.flags[code] = flag
    if flag then
      shown[code] = true
      flag.selected = code == active
      Place(flag, "RIGHT", ui.content, "TOPRIGHT",
        -T.FLAG_RIGHT - (count - index) * (T.FLAG_WIDTH + T.FLAG_GAP),
        -T.CONTENT_HEADER / 2)
      lib.ShadeFlag(flag, flag.selected and T.FLAG_SELECTED or T.FLAG_IDLE)
      Show(flag, true)
    end
  end
  local code, flag
  for code, flag in pairs(ui.flags) do
    if not shown[code] then Show(flag, false) end
  end
end

-- The page canvas and its scroll bar ----------------------------------------

function lib.ScrollArrow(bar, up)
  local s = T.scroll
  local arrow = NewFrame("Button", nil, bar)
  if not arrow then return nil end
  Size(arrow, s.arrowWidth, s.arrowHeight)
  pcall(arrow.EnableMouse, arrow, true)
  pcall(arrow.RegisterForClicks, arrow, "LeftButtonUp")
  pcall(arrow.SetHitRectInsets, arrow, -3, -3, -3, -3)
  if up then
    Place(arrow, "BOTTOM", bar, "TOP", 0, s.arrowGap)
  else
    Place(arrow, "TOP", bar, "BOTTOM", 0, -s.arrowGap)
  end
  local face = NewTexture(arrow, "ARTWORK", "scrollbar-proportional")
  if face then pcall(face.SetAllPoints, face, arrow) end
  arrow.face = face
  arrow.cells = up and { s.upNormal, s.upPushed, s.upHover }
    or { s.downNormal, s.downPushed, s.downHover }
  arrow.state = 1
  arrow.enabled = true
  SetScript(arrow, "OnEnter", function() arrow.state = 3; lib.PaintArrow(arrow) end)
  SetScript(arrow, "OnLeave", function() arrow.state = 1; lib.PaintArrow(arrow) end)
  SetScript(arrow, "OnMouseDown", function() arrow.state = 2; lib.PaintArrow(arrow) end)
  SetScript(arrow, "OnMouseUp", function() arrow.state = 3; lib.PaintArrow(arrow) end)
  SetScript(arrow, "OnClick", function()
    if arrow.enabled then
      lib.SetOffset((lib.ui.offset or 0) + (up and -T.WHEEL_STEP or T.WHEEL_STEP))
    end
  end)
  lib.PaintArrow(arrow)
  return arrow
end

function lib.PaintArrow(arrow)
  if not arrow or not arrow.face then return end
  if arrow.enabled then
    Cell(arrow.face, arrow.cells[arrow.state] or arrow.cells[1], 64)
    Tint(arrow.face, 1, 1, 1, 1)
  else
    Cell(arrow.face, arrow.cells[1], 64)
    Tint(arrow.face, 1, 1, 1, T.scroll.disabledAlpha)
  end
end

function lib.PaintThumb(state)
  local ui = lib.ui
  local art = ui.thumbArt
  if not art then return end
  local s = T.scroll
  local cells = s.thumbNormal
  if state == "pushed" then
    cells = s.thumbPushed
  elseif state == "hover" then
    cells = s.thumbHover
  end
  Cell(art.top, cells[1], 64)
  pcall(art.middle.SetTexCoord, art.middle, cells[2][1] / 64, cells[2][2] / 64, 1 / 512, 1)
  Cell(art.bottom, cells[3], 64)
end

function lib.BuildScrollBar(root)
  local ui = lib.ui
  local s = T.scroll
  local inset = s.arrowHeight + s.arrowGap
  local bar = NewFrame("Frame", nil, root)
  if not bar then return end
  ui.bar = bar
  ui.barHeight = T.CANVAS_HEIGHT - 2 * inset
  Size(bar, s.width, ui.barHeight)
  Place(bar, "TOPRIGHT", root, "TOPRIGHT", -4, -inset)
  pcall(bar.EnableMouse, bar, true)
  local top = NewTexture(bar, "BACKGROUND", "scrollbar-proportional")
  local middle = NewTexture(bar, "BACKGROUND", "scrollbar-vertical-0")
  local bottom = NewTexture(bar, "BACKGROUND", "scrollbar-proportional")
  Cell(top, s.trackTop, 64)
  Cell(bottom, s.trackBottom, 64)
  if middle then
    pcall(middle.SetTexCoord, middle, s.trackMiddle[1] / 64, s.trackMiddle[2] / 64, 0, 1 / 512)
  end
  Size(top, s.width, s.cap)
  Size(bottom, s.width, s.cap)
  Size(middle, s.width, nil)
  Place(top, "TOP", bar, "TOP", 0, 0)
  Place(bottom, "BOTTOM", bar, "BOTTOM", 0, 0)
  if middle then
    pcall(middle.SetPoint, middle, "TOP", top, "BOTTOM", 0, 0)
    pcall(middle.SetPoint, middle, "BOTTOM", bottom, "TOP", 0, 0)
  end

  -- The visible thumb is mouse-transparent and re-placed every tick; the
  -- invisible handle over it is the one the client moves during a drag.
  local thumb = NewFrame("Frame", nil, bar)
  Size(thumb, s.width, s.minExtent)
  pcall(thumb.EnableMouse, thumb, false)
  Level(thumb, (Num(bar, "GetFrameLevel") or 0) + 1)
  ui.thumb = thumb
  ui.thumbArt = {
    top = NewTexture(thumb, "ARTWORK", "scrollbar-proportional"),
    middle = NewTexture(thumb, "ARTWORK", "scrollbar-vertical-0"),
    bottom = NewTexture(thumb, "OVERLAY", "scrollbar-proportional"),
  }
  Size(ui.thumbArt.top, s.width, s.thumbTop)
  Size(ui.thumbArt.bottom, s.width, s.thumbBottom)
  Place(ui.thumbArt.top, "TOP", thumb, "TOP", 0, 0)
  Place(ui.thumbArt.bottom, "BOTTOM", thumb, "BOTTOM", 0, 0)
  Place(ui.thumbArt.middle, "TOP", ui.thumbArt.top, "BOTTOM", 0, 0)
  lib.PaintThumb()

  local handle = NewFrame("Button", nil, bar)
  Size(handle, s.width + 6, s.minExtent)
  Level(handle, (Num(bar, "GetFrameLevel") or 0) + 2)
  ui.thumbHandle = handle
  local grab
  lib.AttachThumbDrag(handle,
    function()
      local _, y = Cursor(bar)
      local barTop = Num(bar, "GetTop")
      if not y or not barTop then return false end
      grab = barTop - y - (ui.thumbOffset or 0)
      lib.PaintThumb("pushed")
    end,
    function()
      local _, y = Cursor(bar)
      local barTop = Num(bar, "GetTop")
      local travel = (ui.barHeight or 0) - (ui.thumbExtent or s.minExtent)
      if not y or not barTop or travel <= 0 or (ui.maximum or 0) <= 0 then return end
      local position = barTop - y - (grab or 0)
      if position < 0 then position = 0 end
      if position > travel then position = travel end
      lib.SetOffset(position / travel * ui.maximum, true)
    end,
    function()
      lib.PaintThumb()
      lib.PlaceThumb(true)
    end)
  SetScript(handle, "OnEnter", function() lib.PaintThumb("hover") end)
  SetScript(handle, "OnLeave", function() lib.PaintThumb() end)

  ui.up = lib.ScrollArrow(bar, true)
  ui.down = lib.ScrollArrow(bar, false)
end

-- dragging: the handle is being moved by the client; only the visual moves.
function lib.PlaceThumb(placeHandle)
  local ui = lib.ui
  if not ui.thumb then return end
  local s = T.scroll
  local height = ui.barHeight or 0
  local viewport, total = ui.viewport or 0, (ui.viewport or 0) + (ui.maximum or 0)
  local extent = s.minExtent
  if total > 0 and viewport > 0 then
    extent = math.max(s.minExtent, height * viewport / total)
  end
  if extent > height then extent = height end
  ui.thumbExtent = extent
  local travel = height - extent
  local offset = 0
  if travel > 0 and (ui.maximum or 0) > 0 then
    offset = math.floor((ui.offset or 0) / ui.maximum * travel + 0.5)
  end
  ui.thumbOffset = offset
  Size(ui.thumb, nil, extent)
  Place(ui.thumb, "TOP", ui.bar, "TOP", 0, -offset)
  local middle = extent - s.thumbTop - s.thumbBottom + s.thumbFade
  if middle < 0 then middle = 0 end
  Size(ui.thumbArt.middle, s.width, middle)
  if placeHandle then
    Size(ui.thumbHandle, nil, extent)
    Place(ui.thumbHandle, "TOP", ui.bar, "TOP", 0, -offset)
  end
end

-- The canvas is scrolled by re-anchoring the sheet inside a scroll child that
-- never scrolls, as pandaUI does
-- (rendering.scroll_child_regions_flash_unscrolled_on_poll).
function lib.SetOffset(value, dragging)
  local ui = lib.ui
  local maximum = ui.maximum or 0
  value = tonumber(value) or 0
  if value < 0 then value = 0 end
  if value > maximum then value = maximum end
  ui.offset = value
  if ui.sheet and ui.holder then
    Place(ui.sheet, "TOPLEFT", ui.holder, "TOPLEFT", 0, value)
  end
  if ui.up then
    ui.up.enabled = value > 0.5
    lib.PaintArrow(ui.up)
  end
  if ui.down then
    ui.down.enabled = value < maximum - 0.5
    lib.PaintArrow(ui.down)
  end
  lib.PlaceThumb(not dragging)
end

function lib.BuildCanvas(content)
  local ui = lib.ui
  local root = NewFrame("Frame", "PandaSettingsWindowCanvasRoot", content)
  if not root then return end
  ui.root = root
  Size(root, T.CONTENT_WIDTH, T.CANVAS_HEIGHT)
  Place(root, "TOPLEFT", content, "TOPLEFT", 0, -(T.CONTENT_HEADER + 4))
  pcall(root.EnableMouse, root, false)

  local scroll = NewFrame("ScrollFrame", "PandaSettingsWindowScroll", root)
  ui.scroll = scroll
  Size(scroll, T.CONTENT_WIDTH - T.SCROLL_COLUMN, T.CANVAS_HEIGHT)
  Place(scroll, "TOPLEFT", root, "TOPLEFT", 0, 0)
  pcall(scroll.EnableMouseWheel, scroll, true)
  SetScript(scroll, "OnMouseWheel", function()
    local delta = tonumber(arg1)
    if not delta or delta == 0 then return end
    lib.SetOffset((ui.offset or 0) + (delta > 0 and -T.WHEEL_STEP or T.WHEEL_STEP))
  end)
  local holder = NewFrame("Frame", "PandaSettingsWindowHolder", scroll)
  ui.holder = holder
  Size(holder, T.CONTENT_WIDTH - T.SCROLL_COLUMN, T.CANVAS_HEIGHT)
  local sheet = NewFrame("Frame", "PandaSettingsWindowSheet", holder)
  ui.sheet = sheet
  Size(sheet, T.PAGE_WIDTH + T.LEFT_PAD, T.CANVAS_HEIGHT)
  local canvas = NewFrame("Frame", "PandaSettingsWindowCanvas", sheet)
  ui.canvas = canvas
  Size(canvas, T.PAGE_WIDTH, T.CANVAS_HEIGHT)
  Place(canvas, "TOPLEFT", sheet, "TOPLEFT", T.LEFT_PAD, 0)
  pcall(scroll.SetScrollChild, scroll, holder)
  lib.SetOffset(0)
  lib.BuildScrollBar(root)
end

-- How far the open page reaches below the canvas top, in page units.
function lib.ContentHeight(scale)
  local ui = lib.ui
  local top = Num(ui.canvas, "GetTop")
  local page = ui.active
  if not top or not page or type(page.widgets) ~= "table" then return 0 end
  local lowest = top
  local function Visit(widget, depth)
    if type(widget) ~= "table" or depth > 3 then return end
    if type(widget.puiParts) == "table" then
      local index
      for index = 1, table.getn(widget.puiParts) do
        Visit(widget.puiParts[index], depth + 1)
      end
      return
    end
    if IsShown(widget) then
      local bottom = Num(widget, "GetBottom")
      if bottom and bottom < lowest then lowest = bottom end
    end
  end
  local index
  for index = 1, table.getn(page.widgets) do Visit(page.widgets[index], 1) end
  if not scale or scale <= 0 then scale = 1 end
  return (top - lowest) / scale
end

function lib.Layout()
  local ui = lib.ui
  if not ui.root or not ui.sheet then return end
  local width = T.CONTENT_WIDTH
  local height = T.CANVAS_HEIGHT
  local viewport = width - T.SCROLL_COLUMN
  local pageWidth = ui.pageWidth or T.PAGE_WIDTH
  local contentWidth = pageWidth + T.LEFT_PAD
  Size(ui.sheet, contentWidth, nil)
  Size(ui.canvas, pageWidth, nil)
  local scale = math.min(1, viewport / contentWidth)
  ui.scale = scale
  pcall(ui.sheet.SetScale, ui.sheet, scale)
  ui.viewport = height / scale
  local contentHeight = lib.ContentHeight(scale)
  ui.maximum = math.max(0, contentHeight - height / scale)
  local scrolls = ui.maximum > 0
  Show(ui.bar, scrolls)
  Show(ui.thumbHandle, scrolls)
  Show(ui.up, scrolls)
  Show(ui.down, scrolls)
  lib.SetOffset(ui.offset or 0)
end

function lib.RelayoutIntegratedSettings()
  lib.Layout()
end

function lib.GetIntegratedSettingsPageHeight()
  return tonumber(lib.ui.viewport)
end

-- Building the window ---------------------------------------------------------

function lib.BuildContent(panel)
  local ui = lib.ui
  local sidebar = NewFrame("Frame", "PandaSettingsWindowSidebar", panel)
  ui.sidebar = sidebar
  Size(sidebar, T.SIDEBAR_WIDTH, T.SIDEBAR_HEIGHT)
  Place(sidebar, "TOPLEFT", panel, "TOPLEFT", T.LIST_LEFT, -(T.PLATE_TOP + T.LIST_DROP))
  Level(sidebar, (Num(panel, "GetFrameLevel") or 0) + 2)
  pcall(sidebar.EnableMouse, sidebar, false)

  local content = NewFrame("Frame", "PandaSettingsWindowContent", panel)
  ui.content = content
  Size(content, T.CONTENT_WIDTH, T.SIDEBAR_HEIGHT)
  Place(content, "TOPLEFT", sidebar, "TOPRIGHT", T.CONTAINER_GAP, 0)
  Level(content, (Num(panel, "GetFrameLevel") or 0) + 2)
  pcall(content.EnableMouse, content, false)

  local watermark = NewTexture(content, "BACKGROUND")
  Size(watermark, T.WATERMARK, T.WATERMARK)
  Place(watermark, "BOTTOMRIGHT", content, "BOTTOMRIGHT", -T.WATERMARK_INSET,
    T.WATERMARK_INSET)
  Tint(watermark, 1, 1, 1, T.WATERMARK_ALPHA)
  ui.watermark = watermark

  local divider = lib.OptionsCell(content, "ARTWORK", T.options.divider, T.CONTENT_WIDTH, 1)
  Place(divider, "TOPLEFT", content, "TOPLEFT", 0, -T.CONTENT_HEADER)

  ui.pageLogo = NewTexture(content, "OVERLAY")
  Size(ui.pageLogo, T.PAGE_LOGO, T.PAGE_LOGO)
  Place(ui.pageLogo, "LEFT", content, "TOPLEFT", T.TITLE_INSET, -T.CONTENT_HEADER / 2)
  ui.pageTitle = NewLabel(content, "GameFontNormalLarge", 13, T.WHITE, "LEFT")

  lib.BuildCanvas(content)
end

function lib.BuildWindow()
  local ui = lib.ui
  if ui.panel then return ui.panel end
  local panel = NewFrame("Frame", "PandaSettingsWindow", UIParent)
  if not panel then return nil end
  ui.panel = panel
  Size(panel, T.WIDTH, T.HEIGHT)
  pcall(panel.SetFrameStrata, panel, "HIGH")
  pcall(panel.EnableMouse, panel, true)
  pcall(panel.SetToplevel, panel, true)
  lib.BuildBackground(panel)
  lib.BuildPlate(panel)
  local rim = lib.BuildRim(panel)
  local title = NewLabel(rim or panel, "GameFontNormal", 13, T.GOLD, "CENTER")
  Place(title, "CENTER", panel, "TOP", 0, T.rim.titleY)
  SetText(title, T.TITLE)
  lib.BuildHandle(panel)
  lib.BuildCloseX(panel)
  lib.BuildContent(panel)
  local close = lib.NewRedButton(panel, "PandaSettingsWindowClose",
    type(CLOSE) == "string" and CLOSE or "Close", T.BUTTON_WIDTH, T.BUTTON_HEIGHT,
    function() lib.CloseSettings() end)
  Place(close, "BOTTOMRIGHT", panel, "BOTTOMRIGHT", -T.BUTTON_INSET, T.BUTTON_INSET)
  Level(close, (Num(panel, "GetFrameLevel") or 0) + 12)
  SetScript(panel, "OnHide", function() lib.OnWindowHidden() end)
  Show(panel, false)
  return panel
end

-- Pages -----------------------------------------------------------------------

function lib.SelectPage(page)
  local ui = lib.ui
  if not page or not ui.canvas then return false end
  lib.CloseMenus()
  local groupIndex, pageIndex
  for groupIndex = 1, table.getn(lib.groups) do
    local pages = lib.groups[groupIndex].pages
    for pageIndex = 1, table.getn(pages) do
      if pages[pageIndex] ~= page then ShowList(pages[pageIndex].widgets, false) end
    end
  end
  local group = page.group
  ui.pageWidth = tonumber(GroupOption(group, "pageWidth")) or T.PAGE_WIDTH
  ui.active = page
  ui.last = page
  ui.offset = 0
  lib.Layout()
  if not page.widgets then
    local ok, widgets, refresh = pcall(page.build, ui.canvas)
    if not ok then
      if DEFAULT_CHAT_FRAME then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME,
          "|cffff5555" .. T.TITLE .. ": " .. tostring(widgets) .. "|r")
      end
      widgets, refresh = nil, nil
    end
    page.widgets = type(widgets) == "table" and widgets or {}
    page.refresh = refresh
    lib.StyleWidgets(page.widgets)
  end
  ShowList(page.widgets, true)
  if type(page.refresh) == "function" then pcall(page.refresh) end

  local logo = GroupOption(group, "icon")
  if type(logo) == "string" and ui.pageLogo then
    pcall(ui.pageLogo.SetTexture, ui.pageLogo, logo)
    Show(ui.pageLogo, true)
    Place(ui.pageTitle, "LEFT", ui.pageLogo, "RIGHT", T.LOGO_GAP, 0)
  else
    Show(ui.pageLogo, false)
    Place(ui.pageTitle, "LEFT", ui.content, "TOPLEFT", T.TITLE_INSET, -T.CONTENT_HEADER / 2)
  end
  SetText(ui.pageTitle, Resolve(GroupOption(group, "title")) or lib.GroupTitle(group))
  local watermark = GroupOption(group, "watermark")
  if type(watermark) == "string" and ui.watermark then
    pcall(ui.watermark.SetTexture, ui.watermark, watermark)
    Show(ui.watermark, true)
  else
    Show(ui.watermark, false)
  end

  lib.Layout()
  lib.RequestRelayout()
  lib.RenderList()
  return true
end

function lib.OpenSettingsPage(id)
  if PandaUIHost() then return false end
  local page = lib.ResolvePage(id) or lib.ui.last or lib.FirstPage()
  if not page or not lib.BuildWindow() then return false end
  local panel = lib.ui.panel
  lib.ApplyScale()
  if not lib.ui.placed then
    lib.ui.placed = true
    lib.ApplyPosition()
  end
  Show(panel, true)
  lib.SelectPage(page)
  return true
end

function lib.OpenSettings()
  return lib.OpenSettingsPage(nil)
end

function lib.IsSettingsShown()
  return IsShown(lib.ui.panel)
end

function lib.CloseSettings()
  local panel = lib.ui.panel
  if not panel then return false end
  Show(panel, false)
  lib.OnWindowHidden()
  return true
end

function lib.OnWindowHidden()
  local ui = lib.ui
  lib.CloseMenus()
  if ui.active then ShowList(ui.active.widgets, false) end
  ui.active = nil
end

function lib.ToggleSettings(id)
  if lib.IsSettingsShown() then return lib.CloseSettings() end
  return lib.OpenSettingsPage(id)
end

-- Controls ----------------------------------------------------------------------

local function CheckFace(frame)
  local c = T.checkbox
  local box = NewTexture(frame, "ARTWORK", "checkmark-minimal")
  local tick = NewTexture(frame, "OVERLAY", "checkmark-minimal")
  Cell(box, c.box, 64)
  Cell(tick, c.check, 64)
  Size(box, c.width, c.height)
  Size(tick, c.width, c.height)
  Place(box, "CENTER", frame, "CENTER", 0, 0)
  Place(tick, "CENTER", frame, "CENTER", 0, 0)
  Show(tick, false)
  return { box = box, tick = tick }
end

local function PaintCheck(face, checked, enabled)
  if not face then return end
  local shade = enabled == false and 0.5 or 1
  Tint(face.box, shade, shade, shade, 1)
  if checked then
    Cell(face.tick, enabled == false and T.checkbox.checkDisabled or T.checkbox.check, 64)
  end
  Show(face.tick, checked)
end

-- The label is part of the click area, up to the width its text takes.
local function ExtendHit(button, label, maxWidth)
  local width = Num(label, "GetStringWidth") or 0
  if maxWidth and width > maxWidth then width = maxWidth end
  pcall(button.SetHitRectInsets, button, 0, -(6 + width), 0, 0)
end

function lib.CreateCheckbox(parent, options)
  options = options or {}
  local c = T.checkbox
  local control = { enabled = options.disabled ~= true, value = false }
  local box = NewFrame("Button", options.name, parent)
  if not box then return nil end
  Size(box, c.size, c.size)
  pcall(box.EnableMouse, box, true)
  pcall(box.RegisterForClicks, box, "LeftButtonUp")
  control.box = box
  control.face = CheckFace(box)
  local label = NewLabel(parent, "GameFontNormal", 11, T.GOLD, "LEFT")
  control.label = label
  if label then
    pcall(label.SetPoint, label, "LEFT", box, "RIGHT", 6, 0)
    if options.textWidth then Size(label, options.textWidth, nil) end
    SetText(label, options.text)
    ExtendHit(box, label, options.textWidth)
  end
  control.puiParts = { box, label }

  control.Apply = function()
    PaintCheck(control.face, control.value, control.enabled)
    TextColor(label, control.enabled and T.GOLD or T.DIM)
    pcall(box.EnableMouse, box, control.enabled)
  end
  control.SetValue = function(value)
    control.value = value and true or false
    control.Apply()
  end
  control.SetEnabled = function(enabled)
    control.enabled = enabled and true or false
    control.Apply()
  end
  control.SetPoint = function(point, relative, relativePoint, x, y)
    Place(box, point, relative, relativePoint, x, y)
  end
  SetScript(box, "OnClick", function()
    if not control.enabled then return end
    control.SetValue(not control.value)
    if type(options.onChange) == "function" then options.onChange(control.value) end
  end)
  SetScript(box, "OnEnter", function()
    if control.enabled then TextColor(label, T.WHITE) end
  end)
  SetScript(box, "OnLeave", function() control.Apply() end)
  control.SetValue(options.value)
  return control
end

function lib.CreateRadioGroup(parent, options)
  options = options or {}
  local control = { rows = {}, puiParts = {} }
  local items = options.items or {}
  local width = options.width or 220
  local rowHeight = options.rowHeight or 18
  local columns = math.floor(tonumber(options.columns) or 1)
  if columns < 1 then columns = 1 end
  local columnGap = options.columnGap or 3
  local rowGap = options.rowGap or 3

  local function PaintRow(row)
    local selected = row.item.value == control.value
    local enabled = not row.item.disabled
    PaintCheck(row.face, selected, enabled)
    TextColor(row.label, enabled and (row.over and T.WHITE or T.GOLD) or T.DIM)
  end
  control.Apply = function()
    local index
    for index = 1, table.getn(control.rows) do PaintRow(control.rows[index]) end
  end
  control.SetValue = function(value, notify)
    local index
    for index = 1, table.getn(items) do
      if items[index].value == value and not items[index].disabled then
        local changed = control.value ~= value
        control.value = value
        control.Apply()
        if changed and notify and type(options.onChange) == "function" then
          options.onChange(value)
        end
        return true
      end
    end
    return false
  end
  control.GetValue = function() return control.value end
  control.SetPoint = function(point, relative, relativePoint, x, y)
    Place(control.rows[1], point, relative, relativePoint, x, y)
  end

  local index
  for index = 1, table.getn(items) do
    local item = items[index]
    local row = NewFrame("Button", options.name and (options.name .. index) or nil, parent)
    if row then
      row.item = item
      Size(row, width, rowHeight)
      pcall(row.EnableMouse, row, not item.disabled)
      pcall(row.RegisterForClicks, row, "LeftButtonUp")
      local indicator = NewFrame("Frame", nil, row)
      Size(indicator, T.checkbox.size, T.checkbox.size)
      Place(indicator, "LEFT", row, "LEFT", 0, 0)
      row.face = CheckFace(indicator)
      row.label = NewLabel(row, "GameFontNormal", 11, T.GOLD, "LEFT")
      if row.label then
        pcall(row.label.SetPoint, row.label, "LEFT", indicator, "RIGHT", 6, 0)
        Size(row.label, width - T.checkbox.size - 6, nil)
        SetText(row.label, item.text or tostring(item.value or ""))
      end
      SetScript(row, "OnEnter", function() row.over = true; PaintRow(row) end)
      SetScript(row, "OnLeave", function() row.over = false; PaintRow(row) end)
      SetScript(row, "OnClick", function() control.SetValue(row.item.value, true) end)
      if index > 1 then
        local gridRow = math.floor((index - 1) / columns)
        local column = (index - 1) - gridRow * columns
        if column > 0 then
          Place(row, "TOPLEFT", control.rows[index - 1], "TOPRIGHT", columnGap, 0)
        else
          Place(row, "TOPLEFT", control.rows[index - columns], "BOTTOMLEFT", 0, -rowGap)
        end
      end
      table.insert(control.rows, row)
      table.insert(control.puiParts, row)
    end
  end
  if not control.SetValue(options.value, false) then
    for index = 1, table.getn(items) do
      if not items[index].disabled then
        control.SetValue(items[index].value, false)
        break
      end
    end
  end
  return control
end

local function SliderStepper(parent, cell, width, height, direction, onStep)
  local s = T.slider
  local button = NewFrame("Button", nil, parent)
  if not button then return nil end
  Size(button, width, height)
  pcall(button.EnableMouse, button, true)
  pcall(button.RegisterForClicks, button, "LeftButtonUp")
  Level(button, (Num(parent, "GetFrameLevel") or 0) + 1)
  local face = NewTexture(button, "ARTWORK", "minimal-slider-silver")
  if face then
    pcall(face.SetAllPoints, face, button)
    Cell(face, cell, 32, 128)
  end
  button.face = face
  button.enabled = true
  SetScript(button, "OnClick", function()
    if button.enabled then onStep(direction) end
  end)
  if direction < 0 then
    Place(button, "RIGHT", parent, "LEFT", -s.stepperGap, 0)
  else
    Place(button, "LEFT", parent, "RIGHT", s.stepperGap, 0)
  end
  return button
end

local function PaintSliderStepper(button, enabled)
  if not button then return end
  button.enabled = enabled and true or false
  local shade = button.enabled and 1 or 0.5
  Tint(button.face, shade, shade, shade, 1)
  pcall(button.EnableMouse, button, button.enabled)
end

function lib.CreateSlider(parent, options)
  options = options or {}
  local s = T.slider
  local minimum = tonumber(options.min) or 0
  local maximum = tonumber(options.max) or 100
  if maximum < minimum then maximum = minimum end
  local step = tonumber(options.step) or 1
  if step <= 0 then step = 1 end
  local control = { min = minimum, max = maximum, step = step, enabled = true,
    puiParts = {} }
  local usable = s.width - s.thumbWidth

  local function Clamp(raw)
    raw = tonumber(raw)
    if not raw then return minimum end
    raw = math.floor((raw - minimum) / step + 0.5) * step + minimum
    if raw < minimum then raw = minimum end
    if raw > maximum then raw = maximum end
    return raw
  end

  local caption = NewLabel(parent, "GameFontNormal", 11, T.GOLD, "LEFT")
  SetText(caption, options.text)
  control.caption = caption
  local track = NewFrame("Frame", options.name and (options.name .. "Track") or nil, parent)
  if not track then return nil end
  control.track = track
  Size(track, s.width, s.barHeight)
  pcall(track.EnableMouse, track, true)
  local bar = {}
  bar.left = NewTexture(track, "BACKGROUND", "minimal-slider-silver")
  bar.middle = NewTexture(track, "BACKGROUND", "minimal-slider-silver")
  bar.right = NewTexture(track, "BACKGROUND", "minimal-slider-silver")
  Cell(bar.left, s.left, 32, 128)
  Cell(bar.middle, s.middle, 32, 128)
  Cell(bar.right, s.right, 32, 128)
  Size(bar.left, s.cap, s.barHeight)
  Size(bar.right, s.cap, s.barHeight)
  Size(bar.middle, nil, s.barHeight)
  Place(bar.left, "LEFT", track, "LEFT", 0, 0)
  Place(bar.right, "RIGHT", track, "RIGHT", 0, 0)
  if bar.middle then
    pcall(bar.middle.SetPoint, bar.middle, "LEFT", bar.left, "RIGHT", 0, 0)
    pcall(bar.middle.SetPoint, bar.middle, "RIGHT", bar.right, "LEFT", 0, 0)
  end

  local visual = NewTexture(track, "OVERLAY", "minimal-slider-silver")
  Cell(visual, s.thumb, 32, 128)
  Size(visual, s.thumbWidth, s.thumbHeight)
  control.thumbVisual = visual
  local handle = NewFrame("Button", nil, track)
  Size(handle, s.thumbWidth + 4, s.thumbHeight + 4)
  Level(handle, (Num(track, "GetFrameLevel") or 0) + 2)
  control.thumb = handle

  local readout = NewLabel(parent, "GameFontHighlight", 11, T.WHITE, "LEFT")
  pcall(readout.SetPoint, readout, "LEFT", track, "RIGHT", s.valueGap, 0)
  control.readout = readout

  local function Offset(value)
    if maximum <= minimum then return 0 end
    return (value - minimum) / (maximum - minimum) * usable
  end
  local function PlaceVisual(offset)
    Place(visual, "LEFT", track, "LEFT", offset, 0)
  end
  local function PlaceHandle(value)
    Place(handle, "CENTER", track, "LEFT", Offset(value) + s.thumbWidth / 2, 0)
  end

  local steppers = {}
  local function RefreshSteppers()
    local value = Clamp(control.current or minimum)
    PaintSliderStepper(steppers.back, control.enabled and value > minimum)
    PaintSliderStepper(steppers.forward, control.enabled and value < maximum)
  end
  local function Display(value)
    control.current = value
    SetText(readout, tostring(value))
    PlaceVisual(Offset(value))
    RefreshSteppers()
  end
  local function Publish(raw, silent)
    local value = Clamp(raw)
    local changed = value ~= control.published
    control.published = value
    Display(value)
    PlaceHandle(value)
    if changed and not silent and type(options.onChange) == "function" then
      options.onChange(value)
    end
  end

  local function CursorValue(grab)
    local x = Cursor(track)
    local left = Num(track, "GetLeft")
    if not x or not left or usable <= 0 then return nil end
    local offset = x - left - (grab or s.thumbWidth / 2)
    if offset < 0 then offset = 0 end
    if offset > usable then offset = usable end
    return minimum + offset / usable * (maximum - minimum), offset
  end

  local grab, pressed
  lib.AttachThumbDrag(handle,
    function()
      if not control.enabled then return false end
      local x = Cursor(track)
      local left = Num(track, "GetLeft")
      grab = s.thumbWidth / 2
      if x and left then
        grab = x - left - Offset(Clamp(control.current or minimum))
        if grab < 0 then grab = 0 end
        if grab > s.thumbWidth then grab = s.thumbWidth end
      end
      pressed = Clamp(control.current or minimum)
    end,
    function()
      local value, offset = CursorValue(grab)
      if not value then return end
      local stepped = Clamp(value)
      control.current = stepped
      SetText(readout, tostring(stepped))
      PlaceVisual(offset)
    end,
    function()
      local value = CursorValue(grab)
      if value then
        Publish(value, Clamp(value) == pressed)
      else
        PlaceHandle(control.current or minimum)
      end
      grab, pressed = nil, nil
    end)

  SetScript(track, "OnMouseDown", function()
    if not control.enabled then return end
    local value = CursorValue()
    if value then Publish(value) end
  end)

  local function Step(direction)
    if not control.enabled then return end
    Publish(Clamp((control.current or minimum) + (direction < 0 and -step or step)))
  end
  steppers.back = SliderStepper(track, s.back, s.backWidth, s.backHeight, -1, Step)
  steppers.forward = SliderStepper(track, s.forward, s.forwardWidth, s.forwardHeight, 1, Step)

  control.puiParts = { caption, track, handle, readout, steppers.back, steppers.forward }
  control.RefreshDrag = function() return control.current end
  control.SetValue = function(raw)
    Publish(raw, true)
  end
  control.GetValue = function() return control.current end
  control.GetStepState = function()
    local value = Clamp(control.current or minimum)
    return control.enabled and value > minimum, control.enabled and value < maximum
  end
  control.StepValue = function(direction)
    Step(tonumber(direction) or 0)
    return true
  end
  control.SetEnabled = function(enabled)
    control.enabled = enabled and true or false
    pcall(track.EnableMouse, track, control.enabled)
    pcall(handle.EnableMouse, handle, control.enabled)
    TextColor(caption, control.enabled and T.GOLD or T.DIM)
    TextColor(readout, control.enabled and T.WHITE or T.DIM)
    RefreshSteppers()
  end
  control.SetPoint = function(point, relative, relativePoint, x, y)
    Place(track, point, relative, relativePoint, x, y)
    Place(caption, "BOTTOMLEFT", track, "TOPLEFT", 0, 4)
  end
  control.SetValue(options.value == nil and minimum or options.value)
  return control
end

-- Dropdowns ----------------------------------------------------------------------

function lib.CloseMenus()
  local ui = lib.ui
  if ui.openMenu then
    local control = ui.openMenu
    ui.openMenu = nil
    control.SetOpen(false)
  end
end

local function BedPieces(button)
  local d = T.dropdown
  local pieces = {}
  local index
  local names = { "left", "middle", "right" }
  for index = 1, 3 do
    pieces[names[index]] = NewTexture(button, "BACKGROUND", "setting-ui")
    Size(pieces[names[index]], nil, d.height)
  end
  local cap = d.cap * d.height / 78
  Size(pieces.left, cap, nil)
  Size(pieces.right, cap, nil)
  pcall(pieces.left.SetPoint, pieces.left, "LEFT", button, "LEFT", -d.overhang, 0)
  pcall(pieces.right.SetPoint, pieces.right, "RIGHT", button, "RIGHT", d.overhang, 0)
  pcall(pieces.middle.SetPoint, pieces.middle, "LEFT", pieces.left, "RIGHT", 0, 0)
  pcall(pieces.middle.SetPoint, pieces.middle, "RIGHT", pieces.right, "LEFT", 0, 0)
  return pieces
end

local function PaintBed(pieces, cell, sheet, cap)
  local x0, x1, y0, y1 = cell[1], cell[2], cell[3], cell[4]
  pcall(pieces.left.SetTexCoord, pieces.left, x0 / sheet, (x0 + cap) / sheet,
    y0 / sheet, y1 / sheet)
  pcall(pieces.middle.SetTexCoord, pieces.middle, (x0 + cap) / sheet,
    (x1 - cap) / sheet, y0 / sheet, y1 / sheet)
  pcall(pieces.right.SetTexCoord, pieces.right, (x1 - cap) / sheet, x1 / sheet,
    y0 / sheet, y1 / sheet)
end

local function DropdownStepper(button, direction, onStep)
  local st = T.stepper
  local stepper = NewFrame("Button", nil, button)
  if not stepper then return nil end
  Size(stepper, st.width, st.height)
  pcall(stepper.EnableMouse, stepper, true)
  pcall(stepper.RegisterForClicks, stepper, "LeftButtonUp")
  Level(stepper, (Num(button, "GetFrameLevel") or 0) + 1)
  stepper.bed = NewTexture(stepper, "BACKGROUND", "setting-ui")
  Size(stepper.bed, st.bed, st.bed)
  Place(stepper.bed, "CENTER", stepper, "CENTER", 0, 0)
  stepper.icon = NewTexture(stepper, "OVERLAY", "setting-ui")
  Size(stepper.icon, st.icon, st.icon)
  Place(stepper.icon, "CENTER", stepper, "CENTER", 0, 0)
  stepper.key = direction < 0 and "back" or "next"
  stepper.enabled = true
  if direction < 0 then
    Place(stepper, "RIGHT", button, "LEFT", -st.gapLeft, 0)
  else
    Place(stepper, "LEFT", button, "RIGHT", st.gapRight, 0)
  end
  local function Paint()
    local cell = st.normal
    if not stepper.enabled then
      cell = st.disabled
    elseif stepper.down then
      cell = st.pressed
    elseif stepper.over then
      cell = st.hover
    end
    Cell(stepper.bed, cell, 512)
    Cell(stepper.icon, st[stepper.key .. (stepper.enabled and "" or "Disabled")], 512)
    pcall(stepper.EnableMouse, stepper, stepper.enabled)
  end
  stepper.Paint = Paint
  SetScript(stepper, "OnEnter", function() stepper.over = true; Paint() end)
  SetScript(stepper, "OnLeave", function() stepper.over = false; stepper.down = false; Paint() end)
  SetScript(stepper, "OnMouseDown", function() stepper.down = true; Paint() end)
  SetScript(stepper, "OnMouseUp", function() stepper.down = false; Paint() end)
  SetScript(stepper, "OnClick", function()
    if stepper.enabled then onStep(direction) end
  end)
  Paint()
  return stepper
end

function lib.BuildMenu(control, width)
  local d = T.dropdown
  local m = d.menu
  local parent = lib.ui.panel or UIParent
  local menu = NewFrame("Frame", nil, parent)
  if not menu then return nil end
  pcall(menu.SetFrameStrata, menu, "DIALOG")
  pcall(menu.EnableMouse, menu, true)
  local count = table.getn(control.items)
  Size(menu, width, count * T.MENU_ROW + 6)
  local menuLevel = Num(menu, "GetFrameLevel") or 0
  local art = NewFrame("Frame", nil, menu)
  if not art then return menu end
  Level(art, menuLevel)
  pcall(art.EnableMouse, art, false)
  pcall(art.SetPoint, art, "TOPLEFT", menu, "TOPLEFT", -m.inset[1], m.inset[2])
  pcall(art.SetPoint, art, "BOTTOMRIGHT", menu, "BOTTOMRIGHT", m.inset[3], -m.inset[4])
  local cell = m.cell
  local xs = { cell[1], cell[1] + m.left, cell[2] - m.right, cell[2] }
  local ys = { cell[3], cell[3] + m.top, cell[4] - m.bottom, cell[4] }
  local widths = { m.left * m.scale, nil, m.right * m.scale }
  local heights = { m.top * m.scale, nil, m.bottom * m.scale }
  local pieces = {}
  local row, column
  for row = 1, 3 do
    pieces[row] = {}
    for column = 1, 3 do
      local piece = NewTexture(art, "BACKGROUND", "setting-ui")
      pieces[row][column] = piece
      if piece then
        pcall(piece.SetTexCoord, piece, xs[column] / 512, xs[column + 1] / 512,
          ys[row] / 512, ys[row + 1] / 512)
        Size(piece, widths[column], heights[row])
      end
    end
  end
  local points = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
  local corners = { { 1, 1 }, { 1, 3 }, { 3, 1 }, { 3, 3 } }
  local index
  for index = 1, 4 do
    Place(pieces[corners[index][1]][corners[index][2]], points[index], art, points[index], 0, 0)
  end
  local function Span(piece, a, aPoint, b, bPoint)
    if not piece then return end
    pcall(piece.SetPoint, piece, "TOPLEFT", a, aPoint, 0, 0)
    pcall(piece.SetPoint, piece, "BOTTOMRIGHT", b, bPoint, 0, 0)
  end
  Span(pieces[1][2], pieces[1][1], "TOPRIGHT", pieces[1][3], "BOTTOMLEFT")
  Span(pieces[3][2], pieces[3][1], "TOPRIGHT", pieces[3][3], "BOTTOMLEFT")
  Span(pieces[2][1], pieces[1][1], "BOTTOMLEFT", pieces[3][1], "TOPRIGHT")
  Span(pieces[2][3], pieces[1][3], "BOTTOMLEFT", pieces[3][3], "TOPRIGHT")
  Span(pieces[2][2], pieces[1][1], "BOTTOMRIGHT", pieces[3][3], "TOPLEFT")

  control.menuRows = {}
  for index = 1, count do
    local item = control.items[index]
    local line = NewFrame("Button", nil, menu)
    if line then
      Level(line, menuLevel + 2)
      Size(line, width - 4, T.MENU_ROW)
      Place(line, "TOPLEFT", menu, "TOPLEFT", 2, -3 - (index - 1) * T.MENU_ROW)
      pcall(line.EnableMouse, line, true)
      pcall(line.RegisterForClicks, line, "LeftButtonUp")
      local glow = NewTexture(line, "BACKGROUND")
      if glow then
        pcall(glow.SetTexture, glow, "Interface\\Buttons\\WHITE8X8")
        pcall(glow.SetAllPoints, glow, line)
        Tint(glow, 1, 1, 1, 0.1)
        Show(glow, false)
      end
      line.label = NewLabel(line, "GameFontHighlight", 11, T.WHITE, "LEFT")
      Place(line.label, "LEFT", line, "LEFT", 8, 0)
      Size(line.label, width - 20, nil)
      SetText(line.label, item.text or tostring(item.value or ""))
      line.item = item
      SetScript(line, "OnEnter", function() Show(glow, true) end)
      SetScript(line, "OnLeave", function() Show(glow, false) end)
      SetScript(line, "OnClick", function()
        lib.CloseMenus()
        control.SetValue(item.value, true)
      end)
      table.insert(control.menuRows, line)
    end
  end
  Show(menu, false)
  return menu
end

function lib.CreateDropdown(parent, options)
  options = options or {}
  local d = T.dropdown
  local width = tonumber(options.width) or 200
  local control = { items = options.items or {}, open = false, shown = true }
  local button = NewFrame("Button", options.name, parent)
  if not button then return nil end
  control.button = button
  Size(button, width, d.controlHeight)
  pcall(button.EnableMouse, button, true)
  pcall(button.RegisterForClicks, button, "LeftButtonUp")
  local pieces = BedPieces(button)
  local arrow = NewTexture(button, "OVERLAY", "setting-ui")
  Cell(arrow, d.arrow, 512)
  Size(arrow, d.arrowWidth, d.arrowHeight)
  Place(arrow, "BOTTOM", button, "CENTER", 0, -d.controlHeight / 2 + d.arrowY)
  Show(arrow, false)
  local label = NewLabel(button, "GameFontNormal", 11, T.GOLD, "CENTER")
  if label then
    pcall(label.SetPoint, label, "LEFT", button, "LEFT", d.textInset, 0)
    pcall(label.SetPoint, label, "RIGHT", button, "RIGHT", -d.textInset, 0)
  end
  control.label = label

  local state = {}
  local function Paint()
    local cell = d.normal
    if control.open then
      cell = d.open
    elseif state.down then
      cell = d.pressed
    elseif state.over then
      cell = d.hover
    end
    PaintBed(pieces, cell, 512, d.cap)
    Show(arrow, state.over and not control.open)
  end

  local function IndexOf(value)
    local index
    for index = 1, table.getn(control.items) do
      if control.items[index].value == value then return index end
    end
    return nil
  end
  local steppers = {}
  local function RefreshSteppers()
    local index = IndexOf(control.value)
    local count = table.getn(control.items)
    if steppers.back then
      steppers.back.enabled = index ~= nil and index > 1
      steppers.back.Paint()
    end
    if steppers.next then
      steppers.next.enabled = index ~= nil and index < count
      steppers.next.Paint()
    end
  end

  control.SetValue = function(value, notify)
    local index = IndexOf(value)
    if not index then return false end
    local changed = control.value ~= value
    control.value = value
    SetText(label, control.items[index].text or tostring(value))
    RefreshSteppers()
    if changed and notify and type(options.onChange) == "function" then
      options.onChange(value)
    end
    return true
  end
  control.GetValue = function() return control.value end
  control.GetStepState = function()
    local index = IndexOf(control.value)
    return index ~= nil and index > 1, index ~= nil and index < table.getn(control.items)
  end
  control.StepValue = function(direction)
    local index = IndexOf(control.value)
    if not index then return false end
    local target = control.items[index + (direction < 0 and -1 or 1)]
    if not target then return false end
    return control.SetValue(target.value, true)
  end
  local function Step(direction) control.StepValue(direction) end
  steppers.back = DropdownStepper(button, -1, Step)
  steppers.next = DropdownStepper(button, 1, Step)

  control.SetOpen = function(open)
    open = open and control.shown and true or false
    if open and not control.menu then control.menu = lib.BuildMenu(control, width) end
    control.open = open
    if open then
      lib.CloseMenus()
      lib.ui.openMenu = control
      Place(control.menu, "TOPLEFT", button, "BOTTOMLEFT", 0, -6)
      local index
      for index = 1, table.getn(control.menuRows or {}) do
        local line = control.menuRows[index]
        TextColor(line.label, line.item.value == control.value and T.GOLD or T.WHITE)
      end
    elseif lib.ui.openMenu == control then
      lib.ui.openMenu = nil
    end
    Show(control.menu, open)
    Paint()
  end
  control.SetPoint = function(point, relative, relativePoint, x, y)
    Place(button, point, relative, relativePoint, x, y)
  end
  control.puiSetShown = function(shown)
    control.shown = shown and true or false
    Show(button, control.shown)
    if not control.shown and control.open then control.SetOpen(false) end
  end
  control.puiParts = { button }

  SetScript(button, "OnEnter", function() state.over = true; Paint() end)
  SetScript(button, "OnLeave", function() state.over = false; state.down = false; Paint() end)
  SetScript(button, "OnMouseDown", function() state.down = true; Paint() end)
  SetScript(button, "OnMouseUp", function() state.down = false; Paint() end)
  SetScript(button, "OnClick", function() control.SetOpen(not control.open) end)
  if not control.SetValue(options.value, false) and control.items[1] then
    control.SetValue(control.items[1].value, false)
  end
  Paint()
  return control
end
