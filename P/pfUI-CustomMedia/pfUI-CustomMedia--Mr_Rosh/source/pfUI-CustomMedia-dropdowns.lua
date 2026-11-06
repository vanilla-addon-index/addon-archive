-- ClassicAPI dropdown integration for pfUI-CustomMedia. This lives here so the
-- shared pfUI files stay untouched.
--
-- pfUI (brues-code fork) builds its dropdowns with ClassicAPI's modern
-- DropdownButton widget (CreateFrame("DropdownButton", ..., "pfUIDropdownTemplate")
-- + SetupMenu), and that widget brings its own menu system with it:
--   * a menu only scrolls when its root description opts in through
--     SetScrollMode(maxHeightPixels), so long lists (bar textures, fonts,
--     buttons, gryphons) are one giant list otherwise;
--   * a menu always opens scrolled to its first row;
--   * the rows of a texture picker give no hint of what they pick.
--
-- All three are handled from here.
if not DropdownButtonMixin or type(DropdownButtonMixin.CreateDefaultRootMenuDescription) ~= "function" then
  return end
if DropdownButtonMixin.customMediaDropdowns then return end

local ROW_HEIGHT = 20
local MAX_VISIBLE_ROWS = 14
local MIN_VISIBLE_ROWS = 4

-- Texture previews.
--
-- pfUI's texture pickers pass the texture path as the radio's `data`
-- (gui.lua: CreateRadio(text, IsSelected, SetSelected, value)), so the path is
-- known per row. It cannot simply be SetTexture'd from the row initializer,
-- though: ClassicAPI builds and initializes *every* row when it generates a
-- menu, virtualized or not, and the bar texture list alone is ~400 files and
-- 20 MB. 1.12 loads textures on the main thread, so that would freeze the
-- client on every open and push the whole folder into texture memory.
--
-- So the initializer only attaches an empty swatch and records its path, and
-- the path is loaded once the row is near the visible window.
local PREVIEW_LEFT = 18
local PREVIEW_RIGHT = 4
local PREVIEW_INSET = 3
local PREVIEW_ALPHA = 0.6
-- rows loaded past each edge of the window, so scrolling a line or two never
-- reaches a row that is still bare
local PREVIEW_MARGIN = 3

local function IsTexturePath(value)
  if type(value) ~= "string" then return false end
  local extension = value:lower():match("%.([%w_]+)$")
  return extension == "tga" or extension == "blp"
end

local function EnsurePreview(frame)
  if not frame or frame.customMediaPreviewLoaded then return end
  local texture, path = frame.customMediaPreviewTex, frame.customMediaPreviewPath
  if not texture or not path then return end
  texture:SetTexture(path)
  frame.customMediaPreviewLoaded = true
end

-- The menu inserts one row frame per element into the scroll box's data
-- provider and lays all rows out at a common height, so the visible window is
-- plain division of the scroll offset. The offset is measured the way
-- ScrollToElementDataIndex measures it, against the rows' extents from the top.
local function PreviewScrollWindow(scrollBox)
  local size = scrollBox:GetDataProviderSize()
  if not size or size == 0 then return end

  local rowExtent = scrollBox:GetElementExtent(1)
  if type(rowExtent) ~= "number" or rowExtent <= 0 then
    rowExtent = ROW_HEIGHT
  end

  -- The scroll offset the view measures rows against starts at the upper
  -- padding, so subtract it to keep the division in row units.
  local offset = (scrollBox:GetDerivedScrollOffset() or 0) - (scrollBox:GetUpperPadding() or 0)
  if offset < 0 then offset = 0 end

  local visible = scrollBox:GetVisibleExtent() or (MAX_VISIBLE_ROWS * rowExtent)

  local first = math.floor(offset / rowExtent) + 1 - PREVIEW_MARGIN
  if first < 1 then first = 1 end
  local last = first + math.ceil(visible / rowExtent) + PREVIEW_MARGIN * 2
  if last > size then last = size end

  for index = first, last do
    EnsurePreview(scrollBox:FindElementData(index))
  end
end

-- A menu that fits on screen gets no scroll box, so all of its rows show.
local function PreviewAllRows(menuFrame)
  for _, child in ipairs({ menuFrame:GetChildren() }) do
    EnsurePreview(child)
  end
end

local function OnMenuScroll(scrollBox)
  PreviewScrollWindow(scrollBox)
end

-- The scroll box is a pooled frame that outlives every menu it has hosted, so
-- one registration per box covers all later menus and nothing needs cleaning up
-- when a menu closes.
local function ArmScrollPreview(menuFrame)
  local scrollBox = menuFrame and menuFrame.ScrollBox
  if not scrollBox or scrollBox.customMediaPreviewArmed then return end
  scrollBox:RegisterCallback(BaseScrollBoxEvents.OnScroll, OnMenuScroll, scrollBox)
  scrollBox.customMediaPreviewArmed = true
end

-- Index of the selected entry among the root description's elements. They come
-- out in the order the menu fed their frames to the data provider, so this is
-- also the data index.
local function GetSelectedIndex(rootDescription)
  for index, description in rootDescription:EnumerateElementDescriptions() do
    if description:IsRadio() and description:IsSelected() then
      return index
    end
  end

  return nil
end

-- Centering rather than the minimum scroll puts the entries around the current
-- selection in view as well, which is what a picker list is for.
local function OpenAtSelection(menuFrame, rootDescription)
  local scrollBox = menuFrame and menuFrame.ScrollBox
  if not scrollBox or not scrollBox:IsShown() then return end
  if not rootDescription or type(rootDescription.EnumerateElementDescriptions) ~= "function" then return end

  local index = GetSelectedIndex(rootDescription)
  if not index then return end

  scrollBox:ScrollToElementDataIndex(index, ScrollBoxConstants.AlignCenter, 0, ScrollBoxConstants.NoScrollInterpolation)
end

local function PreviewMenu(menuFrame, rootDescription)
  if not rootDescription or not rootDescription.customMediaPreviews then return end

  local scrollBox = menuFrame and menuFrame.ScrollBox
  if scrollBox and scrollBox:IsShown() then
    ArmScrollPreview(menuFrame)
    PreviewScrollWindow(scrollBox)
  elseif menuFrame then
    PreviewAllRows(menuFrame)
  end
end

local originalOnMenuOpened = DropdownButtonMixin.OnMenuOpened

function DropdownButtonMixin:OnMenuOpened(menu)
  originalOnMenuOpened(self, menu)

  -- the manager has finished laying the menu out by now, which is what the
  -- extents and the scroll offset below are measured against
  local rootDescription = self:GetMenuDescription()
  OpenAtSelection(menu, rootDescription)
  PreviewMenu(menu, rootDescription)
end

-- ClassicAPI's virtualized stride math can compute begin indices past the end of the
-- data provider ([size+1, size] ranges), erroring out of the menu layout so reopened
-- menus show nothing. Menu scrollboxes already instantiate every item frame regardless
-- of virtualization, so run them non-virtualized: the view then uses the trivially
-- safe full range (1..size).
local function DevirtualizeMenuScroll(view)
  if view and type(view.SetVirtualized) == "function" then
    view:SetVirtualized(false)
  end
end

-- pfUI-style scrollbar: thin, flat, accent-green thumb, no steppers. The stock
-- ClassicAPI bar re-applies Blizzard atlas art on every enable/disable state
-- change and its thumb sizes itself off atlas info, so those handlers are
-- stubbed per instance before blanking the art.
local function ThemeScrollBar(bar)
  if not bar or bar.customMediaThemed then return end
  bar.customMediaThemed = true

  bar:SetWidth(12)
  if bar.Background then bar.Background:Hide() end

  for _, key in ipairs({ "Back", "Forward" }) do
    local stepper = bar[key]
    if stepper then
      stepper.OnButtonStateChanged = function() end
      stepper:Hide()
    end
  end

  local track = bar.Track
  if track then
    track:ClearAllPoints()
    track:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, -2)
    track:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)

    local thumb = track.Thumb
    if thumb then
      thumb.OnButtonStateChanged = function() end
      thumb.OnSizeChanged = function() end
      for _, key in ipairs({ "Begin", "Middle", "End" }) do
        local tex = thumb[key]
        if tex then tex:SetTexture(0, 0, 0, 0) end
      end
      thumb:SetWidth(8)
      if thumb.thumbTexture then
        thumb.thumbTexture:ClearAllPoints()
        thumb.thumbTexture:SetPoint("TOPLEFT", thumb, "TOPLEFT", 0, 0)
        thumb.thumbTexture:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", 0, 0)
        thumb.thumbTexture:SetTexture(0.3, 1, 0.8, 0.8)
      end
    end
  end
end

if MenuProxyMixin and type(MenuProxyMixin.OnLoad) == "function" and not MenuProxyMixin.customMediaDevirtualized then
  local originalMenuOnLoad = MenuProxyMixin.OnLoad
  function MenuProxyMixin:OnLoad()
    originalMenuOnLoad(self)
    if self.ScrollBox and self.ScrollBox.view then
      DevirtualizeMenuScroll(self.ScrollBox.view)
    end
    ThemeScrollBar(self.ScrollBar)
  end
  MenuProxyMixin.customMediaDevirtualized = true
end

-- One closure per texture path, cached: a menu regenerates on every open and
-- each row would otherwise allocate a new function.
local swatchInitializers = {}

local function GetSwatchInitializer(path)
  local initializer = swatchInitializers[path]
  if initializer then return initializer end

  initializer = function(frame)
    -- The row frame is a compositor target, so CreateTexture is disallowed and
    -- the swatch has to be attached. Rows draw their own art, so this sits
    -- below the row's hover highlight (BACKGROUND, level -1) and below the
    -- text, which the font string pool already layers above the row textures.
    if type(frame.AttachTexture) ~= "function" then return end

    local tex = frame:AttachTexture()
    tex:SetDrawLayer("BACKGROUND", -1)
    tex:SetAlpha(PREVIEW_ALPHA)
    -- Inward offsets: negative y from TOPLEFT and positive y from BOTTOMRIGHT,
    -- so the swatch stays inside the row instead of bleeding over its neighbours.
    tex:SetPoint("TOPLEFT", frame, "TOPLEFT", PREVIEW_LEFT, -PREVIEW_INSET)
    tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PREVIEW_RIGHT, PREVIEW_INSET)

    frame.customMediaPreviewTex = tex
    frame.customMediaPreviewPath = path
  end

  swatchInitializers[path] = initializer
  return initializer
end

-- Rows are pooled and reused by whichever menu acquires them, so a row that
-- carried a swatch hands its state back when it leaves.
local function ClearSwatch(frame)
  frame.customMediaPreviewTex = nil
  frame.customMediaPreviewPath = nil
  frame.customMediaPreviewLoaded = nil
end

-- Opt a freshly generated root description into a scrollable menu and give each
-- of its radios a swatch. Initializers run in insertion order, after the stock
-- radio art has been laid down.
local function ThemeRootDescription(description)
  if type(description) ~= "table" then return end

  if type(description.SetScrollMode) == "function" then
    local screenHeight = (UIParent and UIParent:GetHeight()) or 768
    local maxExtent = math.min(MAX_VISIBLE_ROWS * ROW_HEIGHT, math.max(MIN_VISIBLE_ROWS * ROW_HEIGHT, screenHeight - 120))
    description:SetScrollMode(maxExtent)
  end

  -- Every generation hands out a new description proxy, so marking it is
  -- enough to keep this from chaining over itself.
  if type(description.CreateRadio) ~= "function" or description.customMediaRadioPatched then return end

  local originalCreateRadio = description.CreateRadio
  description.CreateRadio = function(self, text, isSelected, setSelected, data)
    local radio = originalCreateRadio(self, text, isSelected, setSelected, data)
    if radio and type(radio.AddInitializer) == "function" and IsTexturePath(data) then
      radio:AddInitializer(GetSwatchInitializer(data))
      radio:AddResetter(ClearSwatch)
      -- counts rows carrying a swatch, so a menu without any never goes
      -- through the preview path
      description.customMediaPreviews = (description.customMediaPreviews or 0) + 1
    end
    return radio
  end
  description.customMediaRadioPatched = true
end

local originalCreateDefaultRootMenuDescription = DropdownButtonMixin.CreateDefaultRootMenuDescription

function DropdownButtonMixin:CreateDefaultRootMenuDescription()
  local description = originalCreateDefaultRootMenuDescription(self)
  ThemeRootDescription(description)
  return description
end

DropdownButtonMixin.customMediaDropdowns = true
