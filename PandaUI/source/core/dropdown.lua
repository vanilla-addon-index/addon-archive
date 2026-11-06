-- Reusable skin and placement adapter for native UIDropDownMenuTemplate
-- controls. The popup lists are a shared native pool, so this owns both the
-- per-control presentation and the shared-list cleanup in one component.

local U = PandaUI
local M = U.media

U.Dropdown = U.Dropdown or {}
local D = U.Dropdown

local menuHooked = false
local textHooked = false
local selectedIdHooked = false

-- Doubled from the previous 14-unit height, as requested.
local CONTROL_HEIGHT = 28
-- The -5 riding-high nudge was tuned for the old 14-unit box; at the doubled
-- height the clamped SetHeight + explicit CENTER justify below already lands
-- the glyph on the control's true centre. USER_CONFIRMED_INGAME: still 1px
-- high at that centre, so a small residual nudge remains.
local CONTROL_TEXT_Y = -1

-- Compact tick box for list rows. Native rows are 16 high, so this is smaller
-- than the 14-unit settings checkbox and uses a matching smaller accent mark.
local ROW_CHECK_SIZE = 10
local ROW_CHECK_MARK_INSET = 3
local ROW_TEXT_INSET = 8
-- The label beside a Modern WoW (game settings) row tick sits 3 lower than the
-- tick's centre (user request, 2026-09-23). Flat rows keep 0.
local ROW_FOREVER_TEXT_Y = -3

local StyleList        -- defined below; rows re-run it when a tick changes.
local activeDropdown   -- last dropdown whose button we saw opened.

-- Retail's UIDropDownListTemplate frames every popup list through
-- DialogBorderDarkTemplate. Classic WoW and Modern WoW unit popups use the
-- matching PandaUI ThinBorder family while the flat Modern theme stays flat.
local UNIT_POPUP_DROPDOWNS = {
  PlayerFrameDropDown = true,
  TargetFrameDropDown = true,
  PetFrameDropDown = true,
  PartyMemberFrame1DropDown = true,
  PartyMemberFrame2DropDown = true,
  PartyMemberFrame3DropDown = true,
  PartyMemberFrame4DropDown = true,
  RaidFrameDropDown = true,
  PandaUIRaidDropDown = true,
}

local function UnitPopupUsesModernWowBorder(dropdown)
  if not dropdown then return false end
  local style = type(U.GetActiveThemeStyle) == "function" and
                U.GetActiveThemeStyle() or nil
  if style ~= "classic-wow" and style ~= "modern-wow" then return false end
  if dropdown.puiUnitPopupMenu then return true end
  if type(dropdown.GetName) ~= "function" then return false end
  local ok, name = pcall(dropdown.GetName, dropdown)
  return ok and UNIT_POPUP_DROPDOWNS[name] and true or false
end

local function RemoveButtonArt(button)
  if not button then return end
  local getters = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }
  local setters = { "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture", "SetDisabledTexture" }
  local i
  for i = 1, table.getn(getters) do
    local getter = button[getters[i]]
    if type(getter) == "function" then
      local ok, texture = pcall(getter, button)
      if ok and texture then U.HideRegion(texture) end
    end
  end
  for i = 1, table.getn(setters) do
    local setter = button[setters[i]]
    if type(setter) == "function" then
      if not pcall(setter, button, "") then pcall(setter, button, nil) end
    end
  end
end

local function StyleArrow(button)
  if not button then return end
  if not button.puiDropdownArrow then
    button.puiDropdownArrow = U.CreateLabel(button, {
      size = M.fontSize.small,
      color = M.color.accent,
      inherits = "GameFontNormalSmall",
    })
    if button.puiDropdownArrow then
      button.puiDropdownArrow:SetPoint("RIGHT", button, "RIGHT", -4, 0)
      button.puiDropdownArrow:SetText("v")
    end
  end
  if button.puiDropdownArrow then button.puiDropdownArrow:Show() end
end

local function LayoutText(dropdown, button)
  if not dropdown then return end
  local name = dropdown.GetName and dropdown:GetName()
  local text = name and U.G(name .. "Text")
  if not text then return end
  -- The button now spans the whole control (so clicking the value opens the
  -- menu too), so text width is reserved against the arrow glyph, not the
  -- button's edge.
  local arrow = button and button.puiDropdownArrow
  local bedStyle = dropdown.puiDropdownBed
  U.SetStockFont(text, bedStyle and bedStyle.textSize or M.fontSize.small,
                 bedStyle and bedStyle.textColor or M.color.text)
  pcall(function()
    text:ClearAllPoints()
    -- LEFT/RIGHT anchors put the text region's own centre on the control's
    -- centre. That alone left the label riding high: the native fontstring
    -- keeps a taller template height than the shortened control and aligns its
    -- glyphs to the top of that region. So the region is also clamped to the
    -- control height and given explicit CENTER justification -- the same
    -- explicit-SetJustifyV treatment chat.scrollingmessage_bottom_alignment
    -- records for this client, where inherited vertical alignment is not what
    -- upstream expects.
    local bed = dropdown.puiDropdownBed
    -- A caller may lower or raise one control's value (options.textY).
    local textY = CONTROL_TEXT_Y + (dropdown.puiDropdownTextY or 0)
    text:SetPoint("LEFT", dropdown, "LEFT", (bed and bed.textInset) or 5, textY)
    if dropdown.puiDropdownBedRight then
      -- A bed control stops the value short of the arrow printed in its right
      -- cap, measured off the control itself. Not off the empty spacer glyph:
      -- /pui gamefocus (2026-09-21) read that empty FontString's LEFT at a
      -- different, meaningless x on every Video dropdown, which left the GPU
      -- value in a 19.8-wide box (wrapped into a 120-tall column) and ran
      -- Graphics API's 66 units past the control's right edge.
      text:SetPoint("RIGHT", dropdown, "RIGHT", -(dropdown.puiDropdownBedRight + 4),
                    textY)
    else
      text:SetPoint("RIGHT", arrow or dropdown, arrow and "LEFT" or "RIGHT", -4, textY)
    end
    text:SetHeight(dropdown.puiDropdownHeight or CONTROL_HEIGHT)
    -- A bed may centre its value (options.bed.textAlign); everything else
    -- reads left, as the stock control does.
    text:SetJustifyH((bed and bed.textAlign) or "LEFT")
    if text.SetJustifyV then text:SetJustifyV("CENTER") end

    -- Re-written at the new width. A FontString is truncated against the
    -- width it has when SetText runs and never reflows when widened later
    -- (knowledge.json / tooltip.line_geometry_is_fixed_at_settext), so a
    -- value the client wrote into its narrow stock box stayed cut short in
    -- this wider one -- reported in game 2026-09-21 on the Video page's GPU
    -- and Graphics API dropdowns. Blank first so the same string counts as a
    -- change.
    local current = text:GetText()
    if current and current ~= "" then
      text:SetText("")
      text:SetText(current)
    end
  end)
end

-- The native control owns its own template height and puts it back from paths
-- pandaUI does not drive: the show/update pass already needed the reassert in
-- StyleStock, and USER_CONFIRMED_INGAME opening the menu snapped the control
-- back to the taller stock size and left it there. Replacing the frame's own
-- SetHeight makes every later Lua-side resize land on the component height
-- instead of chasing each caller separately. The original method is kept so
-- ApplyControlHeight still reaches the real setter.
local function LockControlHeight(dropdown)
  if not dropdown or dropdown.puiDropdownHeightLock then return end
  if type(dropdown.SetHeight) ~= "function" then return end
  local native = dropdown.SetHeight
  local ok = pcall(function()
    dropdown.SetHeight = function(self, _)
      return native(self, self.puiDropdownHeight or CONTROL_HEIGHT)
    end
  end)
  if ok then dropdown.puiDropdownHeightLock = native end
end

local function ApplyControlHeight(dropdown)
  if not dropdown then return end
  pcall(dropdown.puiDropdownHeightLock or dropdown.SetHeight, dropdown,
        dropdown.puiDropdownHeight or CONTROL_HEIGHT)
end

-- A caller whose control must fit a fixed band (the Who list's header) may
-- lower this one control's height; the lock above then holds that value
-- instead of the component default.
function D.SetControlHeight(dropdown, height)
  height = tonumber(height)
  if not dropdown or not height or height <= 0 then return end
  dropdown.puiDropdownHeight = height
  ApplyControlHeight(dropdown)
  local name = dropdown.GetName and dropdown:GetName()
  LayoutText(dropdown, name and U.G(name .. "Button"))
end

-- Selection handlers can continue changing the native FontString after their
-- post-hooks return. Reapply the fixed geometry one shared tick later so every
-- selected value keeps the same Y position, regardless of its text.
local function LayoutTextWhenSettled(dropdown)
  if not dropdown then return end
  local name = dropdown.GetName and dropdown:GetName()
  if not name then return end
  ApplyControlHeight(dropdown)
  LayoutText(dropdown, U.G(name .. "Button"))
  U.DeferOnce("dropdown:text-layout:" .. name, function()
    if dropdown.puiDropdownStyled then
      ApplyControlHeight(dropdown)
      LayoutText(dropdown, U.G(name .. "Button"))
    end
  end)
end

local function IsSelected(check)
  if not check or type(check.IsShown) ~= "function" then return false end
  local ok, shown = pcall(check.IsShown, check)
  return ok and shown and true or false
end

-- Popup list rows are the client's own state carriers, not decoration, so
-- pandaUI only ever changes their ALPHA -- never a shown flag, never a
-- texture path, never a button face.
--
-- USER_CONFIRMED_INGAME (class trainer Filter menu): the generic strip's
-- U.HideRegion (SetTexture(nil) + SetAlpha(0) + Hide) on row regions left the
-- filter doing nothing at all, and keeping only the Check region out of the
-- strip -- the previous fix, and the open probe question in knowledge.json /
-- frames.dropdown_component_checkbox_contract -- did NOT restore it. The
-- single-select /who dropdown kept working throughout, which is what points at
-- per-row state rather than at the click path: /who reads only its own func,
-- while the trainer's entries are keepShownOnClick filters whose ticked state
-- the client stores on the row itself.
--
-- Rather than guess which region or field holds that state, nothing owned by
-- the row is mutated any more. knowledge.json /
-- rendering.native_texture_strip_requires_alpha records alpha as the part that
-- actually removes stock art on this client, so alpha alone gets the flat look
-- with no way left to destroy client state. UnrealPfUI (WORKING_SOURCE,
-- api/ui-widgets.lua SkinDropDown) does not touch list rows at all, which is
-- the same conclusion from the other direction.
local function SuppressRegionArt(region)
  if not region or not region.GetObjectType then return end
  local typeOk, objectType = pcall(region.GetObjectType, region)
  if not typeOk or objectType ~= "Texture" then return end
  pcall(function() if region.SetAlpha then region:SetAlpha(0) end end)
end

local function SuppressRowArt(row)
  if not row then return end

  if row.GetRegions then
    local ok, regions = pcall(function() return { row:GetRegions() } end)
    if ok and type(regions) == "table" then
      local i
      for i = 1, table.getn(regions) do
        SuppressRegionArt(regions[i])
      end
    end
  end

  -- The row's button faces are separate objects from its regions, so they are
  -- faded the same way instead of going through RemoveButtonArt -- that helper
  -- reassigns the textures, which is a mutation rows must not receive.
  local getters = { "GetNormalTexture", "GetPushedTexture",
                    "GetHighlightTexture", "GetDisabledTexture" }
  local i
  for i = 1, table.getn(getters) do
    local getter = row[getters[i]]
    if type(getter) == "function" then
      local ok, texture = pcall(getter, row)
      if ok and texture then SuppressRegionArt(texture) end
    end
  end
end

-- The Check may not be enumerable as a row region on this client, so it is
-- faded explicitly as well. Alpha only, for the same reason as above.
local function SuppressCheckArt(check)
  if not check then return end
  SuppressRegionArt(check)
end

-- Owned tick box replacing the stock Check texture. It is created lazily so
-- rows in plain (single-select) menus never gain an indicator column.
local function RowCheckbox(row)
  if row.puiDropdownCheckbox then return row.puiDropdownCheckbox end
  local box = U.CreatePanel(row, {
    width = ROW_CHECK_SIZE,
    height = ROW_CHECK_SIZE,
    background = M.color.background,
  })
  if not box then return nil end
  pcall(function()
    box:ClearAllPoints()
    box:SetPoint("LEFT", row, "LEFT", ROW_TEXT_INSET, 0)
  end)
  pcall(box.EnableMouse, box, false)
  row.puiDropdownCheckbox = box
  return box
end

-- checkboxes: the owning dropdown was styled as a multi-select filter, so every
-- row reserves the indicator column and shows its own ticked state. Single-select
-- dropdowns pass false and keep the plain accent-highlight row. forever: the
-- tick box draws the game settings checkbox, centred on the flat box, which
-- it overhangs; the label follows its drawn edge. The rows are a shared pool,
-- so a flat multi-select menu clears that face again.
-- The row's registered label cannot keep pandaUI's size: the client repaints it
-- from the button's own font state (GameFontNormal 12) after AddButton and on
-- show, so a SetFont on it lasts only until that repaint. FOCUSED_RUNTIME_PROBE
-- unitmenufont.v3 (knowledge.json /
-- frames.unit_popup_rows_keep_native_font_until_hover): restyles at size 10
-- read 12 again one frame later, and unit-frame menu rows stayed 12 until
-- hovered. Buttons here have no state font-object setters to redirect that
-- repaint (see OwnTabLabel, core/stockui.lua), so each row draws an
-- addon-owned, unregistered label -- the client has no handle on it. The
-- native label stays the text source and is retired underneath.
local function RowLabel(row, native)
  local label = row.puiDropdownLabel
  if not label then
    local ok, created = pcall(row.CreateFontString, row, nil, "ARTWORK", "GameFontNormal")
    if not ok or not created then return nil end
    label = created
    row.puiDropdownLabel = label
    U.HideRegion(native)
    pcall(function()
      native.Show = function() return end
      native.SetAlpha = function() return end
    end)
  end
  local ok, value = pcall(native.GetText, native)
  pcall(label.SetText, label, ok and value or "")
  return label
end

local function StyleListRow(name, index, checkboxes, forever)
  local row = U.G(name .. "Button" .. index)
  local check = U.G(name .. "Button" .. index .. "Check")
  local selected = IsSelected(check)
  if row then
    row.puiDropdownSelected = selected
    SuppressRowArt(row)
  end
  SuppressCheckArt(check)

  local native = U.G(name .. "Button" .. index .. "NormalText")
  if not native or not row then return end
  local text = RowLabel(row, native)
  if not text then return end

  local box = checkboxes and RowCheckbox(row) or row.puiDropdownCheckbox
  local drawn = box
  if box then
    if checkboxes then
      local paint = U.PaintGameSettingsCheckbox
      if forever and type(paint) == "function" then
        drawn = paint(box, selected, true) or box
      else
        if type(paint) == "function" then paint(box, nil, nil, true) end
        U.SetCheckboxIndicator(box, selected, ROW_CHECK_MARK_INSET)
      end
      box:Show()
    else
      box:Hide()
    end
  end

  U.SetStockFont(text, M.fontSize.small, selected and M.color.accent or M.color.text)
  -- Both anchors carry the same y, or the two points pull the label apart.
  local textY = (checkboxes and box and forever) and ROW_FOREVER_TEXT_Y or 0
  pcall(function()
    text:ClearAllPoints()
    if checkboxes and box then
      text:SetPoint("LEFT", drawn, "RIGHT", 6, textY)
    else
      text:SetPoint("LEFT", row, "LEFT", ROW_TEXT_INSET, 0)
    end
    text:SetPoint("RIGHT", row, "RIGHT", -ROW_TEXT_INSET, textY)
    text:SetHeight(row:GetHeight())
    text:SetJustifyH("LEFT")
    if text.SetJustifyV then text:SetJustifyV("CENTER") end
  end)
  -- Hover fill: same white-10% band the game settings list rows use, created
  -- on the row itself so it is positioned exactly. Reset to hidden on every
  -- style pass so a row that was left hovered on the previous open starts clean.
  local hoverFill = row.puiDropdownHoverFill
  if not hoverFill then
    local ok, tex = pcall(row.CreateTexture, row, nil, "BACKGROUND")
    if ok and tex then
      pcall(tex.SetTexture, tex, M.texture.plain)
      local hc = M.foreverWow and M.foreverWow.list and M.foreverWow.list.hover
                 and M.foreverWow.list.hover.color or { 1, 1, 1, 0.1 }
      U.SetColor(tex, M.Unpack(hc))
      pcall(tex.SetAllPoints, tex, row)
      pcall(tex.Hide, tex)
      row.puiDropdownHoverFill = tex
      hoverFill = tex
    end
  else
    pcall(hoverFill.Hide, hoverFill)
  end
  if not row.puiDropdownHoverAttached then
    row.puiDropdownHoverAttached = U.PostHookScript(row, "OnEnter", function()
      U.SetStockFont(text, M.fontSize.small, M.color.accent)
      if hoverFill then pcall(hoverFill.Show, hoverFill) end
    end)
    U.PostHookScript(row, "OnLeave", function()
      U.SetStockFont(text, M.fontSize.small,
        row.puiDropdownSelected and M.color.accent or M.color.text)
      if hoverFill then pcall(hoverFill.Hide, hoverFill) end
    end)
    -- A tickable entry changes its own state without necessarily reopening the
    -- menu, so the owned indicator has to be refreshed after the native click.
    --
    -- USER_CONFIRMED_INGAME: restyling inline here made every tick box lag one
    -- click behind (the user had to click twice to see a tick). The native
    -- handler has not updated its Check texture yet when a post-hooked OnClick
    -- runs, so the inline pass reads the pre-click state. Deferring one shared
    -- tick lets the client settle before the state is read back.
    U.PostHookScript(row, "OnClick", function()
      U.DeferOnce("dropdown:rowtick", function()
        if StyleList then
          StyleList(1)
          StyleList(2)
        end
      end)
    end)
  end
end

-- The popup lists are one shared native pool, so the row style comes from
-- whichever dropdown opened them. The client's own open-menu global is
-- preferred (it is set before the list is built, so the first pass is already
-- correct); activeDropdown is the fallback, set from our own button hook.
-- The global's shape is not in the compact evidence, so both the frame and the
-- Vanilla-style frame-name string are accepted.
local function OwningDropdown()
  local open = U.G("UIDROPDOWNMENU_OPEN_MENU")
  if type(open) == "string" then open = U.G(open) end
  if type(open) ~= "table" then open = activeDropdown end
  return open
end

-- Second result: the owner took its Modern WoW path, so its row ticks draw the
-- game settings checkbox (rules/pandaui-design.md, Modern WoW checkboxes).
-- A bed control drawn under Modern WoW passes `modernWow` too: the bed owns
-- the control's art, the flag still owns its rows' ticks.
local function WantsCheckboxes()
  local dropdown = OwningDropdown()
  local checkboxes = dropdown and dropdown.puiDropdownCheckboxes and true or false
  local modern = dropdown and (dropdown.puiDropdownModernWowStyled or
                               dropdown.puiDropdownModernWowRows)
  return checkboxes, checkboxes and modern and true or false
end

-- Modern WoW chrome (M.modernWow.dropdown): an addon-owned frame over the
-- control or list, below its buttons, carrying the ThinBorder eight-slice. It
-- is a CHILD frame, so StyleList's per-toggle strip of the list itself never
-- reaches it (rules/pandaui.md, region walks never match by identity).
local function ModernWowChrome(host)
  if host.puiDropdownModernWow then return host.puiDropdownModernWow end
  local ok, chrome = pcall(CreateFrame, "Frame", nil, host)
  if not ok or not chrome then return nil end
  pcall(chrome.SetAllPoints, chrome, host)
  pcall(chrome.EnableMouse, chrome, false)
  local levelOk, level = pcall(host.GetFrameLevel, host)
  if levelOk and tonumber(level) then pcall(chrome.SetFrameLevel, chrome, level) end
  if type(U.ModernWowBuildThinBorder) ~= "function" or
     not U.ModernWowBuildThinBorder(chrome, M.modernWow.dropdown.borderSize) then
    pcall(chrome.Hide, chrome)
    return nil
  end
  host.puiDropdownModernWow = chrome
  return chrome
end

-- The flat 1-unit edges are hidden, never faded: vertex alpha is not honoured
-- on this client (knowledge.json rendering.texture_setalpha_darkens_not_translucent).
-- The dark fill, inset inside the border (M.modernWow.dropdown.fillInset).
-- A plain texture instead of the frame backdrop, which always fills to the
-- frame's outer edge. Solid colour: vertex alpha is not honoured here.
local function ModernWowFill(parent, host, color)
  local fill = parent.puiDropdownFill
  if not fill then
    local ok, created = pcall(parent.CreateTexture, parent, nil, "BACKGROUND")
    if not ok or not created then return end
    fill = created
    parent.puiDropdownFill = fill
    local inset = M.modernWow.dropdown.fillInset
    pcall(function()
      fill:SetTexture(M.texture.plain)
      fill:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -inset)
      fill:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, inset)
    end)
  end
  U.SetColor(fill, M.Unpack(color))
  pcall(fill.Show, fill)
end

local function ShowFlatEdges(frame, shown)
  if not frame or not frame.puiEdges then return end
  local i
  for i = 1, table.getn(frame.puiEdges) do
    local edge = frame.puiEdges[i]
    if shown then pcall(edge.Show, edge) else pcall(edge.Hide, edge) end
  end
end

StyleList = function(level)
  local name = "DropDownList" .. level
  local list = U.G(name)
  if not list then return nil end

  -- The native list and its child backdrop can each retain artwork. Strip both
  -- before creating our flat panel so no native edge draws over the new border.
  U.StripStockTextures(list)
  local backdropNames = { "MenuBackdrop", "Backdrop", "Border", "BorderFrame" }
  local i
  for i = 1, table.getn(backdropNames) do
    local nativeBackdrop = U.G(name .. backdropNames[i])
    if nativeBackdrop then
      U.StripStockTextures(nativeBackdrop)
      pcall(nativeBackdrop.SetBackdropBorderColor, nativeBackdrop, 0, 0, 0, 0)
      U.HideRegion(nativeBackdrop)
    end
  end
  -- The list is one shared native pool, so its chrome follows whichever
  -- dropdown opened it: Modern WoW for a control styled on that path, flat
  -- otherwise.
  local owner = OwningDropdown()
  local unitPopup = owner and UnitPopupUsesModernWowBorder(owner)
  local modern = owner and ((level == 1 and owner.puiDropdownModernWowStyled) or
                            unitPopup)
  local bedMenu = level == 1 and owner and owner.puiDropdownBed and
                  owner.puiDropdownBed.menu
  if bedMenu then
    -- The bed's own menu art (options.bed.menu): no flat panel, no Modern WoW
    -- chrome, the caller's nine-slice on a child frame -- the list's own
    -- regions are stripped on every toggle, a child frame's are not.
    --
    -- The menu art is chamfered, so anything filling the list's full rectangle
    -- shows through at its corners as a dark square (reported in game with a
    -- screenshot, 2026-09-22). A backdrop is not an enumerable region
    -- (knowledge.json / rendering.setbackdrop_keeps_native_edge_art), so the
    -- strip above cannot reach it and SetBackdrop(nil) alone is not enough:
    -- clear the fill and edge colours too, and hide the plain-fill fallback
    -- U.CreateBackdrop leaves behind when the shared list was last opened by a
    -- flat dropdown.
    pcall(list.SetBackdrop, list, nil)
    pcall(list.SetBackdropColor, list, 0, 0, 0, 0)
    pcall(list.SetBackdropBorderColor, list, 0, 0, 0, 0)
    if list.puiFill then U.SetColor(list.puiFill, 0, 0, 0, 0) end
    ShowFlatEdges(list, false)
    if list.puiDropdownModernWow then pcall(list.puiDropdownModernWow.Hide, list.puiDropdownModernWow) end
    D.BedMenu(list, owner.puiDropdownBed)
  elseif modern then
    -- No backdrop: the fill lives on the chrome child, because the list
    -- itself is region-stripped on every toggle.
    pcall(list.SetBackdrop, list, nil)
    ShowFlatEdges(list, false)
    if list.puiDropdownBedMenu then pcall(list.puiDropdownBedMenu.Hide, list.puiDropdownBedMenu) end
    local chrome = ModernWowChrome(list)
    if chrome then
      local fill = unitPopup and M.modernWow.dropdown.unitPopupListFill or
                   M.modernWow.dropdown.listFill
      ModernWowFill(chrome, list, fill)
      pcall(chrome.Show, chrome)
    end
  else
    if list.puiDropdownBedMenu then pcall(list.puiDropdownBedMenu.Hide, list.puiDropdownBedMenu) end
    U.CreateBackdrop(list, { background = { 0.03, 0.03, 0.03, 0.95 } })
    ShowFlatEdges(list, true)
    if list.puiDropdownModernWow then pcall(list.puiDropdownModernWow.Hide, list.puiDropdownModernWow) end
  end

  local max = tonumber(U.G("UIDROPDOWNMENU_MAXBUTTONS")) or 8
  local checkboxes, forever = WantsCheckboxes()
  i = nil
  for i = 1, max do
    StyleListRow(name, i, checkboxes, forever)
  end
  return list
end

function D.PlaceListBelow(dropdown)
  if not dropdown then return false end
  activeDropdown = dropdown
  local list = StyleList(1)
  if not list then return false end
  return pcall(function()
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -4)
  end)
end

local function AttachPlacement(dropdown, button)
  if not button or button.puiDropdownPlacementAttached then return end
  if type(button.GetScript) ~= "function" or type(button.SetScript) ~= "function" then return end

  -- Keep the client responsible for invoking its native click handler. Calling
  -- that handler manually omits engine-owned click state and can fault natively.
  local installed = U.PostHookScript(button, "OnClick", function()
    -- Toggling the menu runs the client's own dropdown update path, which
    -- restores the stock control height, so the control must be re-measured
    -- on open and on close. Inline plus one shared tick later, the same gap
    -- the selection path needs, so the control keeps one height whether the
    -- list is open or not.
    LayoutTextWhenSettled(dropdown)
    D.PlaceListBelow(dropdown)
  end)
  if installed then button.puiDropdownPlacementAttached = true end
end

function D.EnsureMenuSkin()
  if menuHooked then return end
  menuHooked = true
  if not U.PostHookGlobal("ToggleDropDownMenu", function()
    StyleList(1)
    StyleList(2)
    -- Unit-frame (UnitPopup) menus fill their rows after this hook, which
    -- left the first paint at the native font size until hover restyled it.
    -- UNVERIFIED in game: a second pass one shared tick later.
    U.DeferOnce("dropdown:menufont", function()
      StyleList(1)
      StyleList(2)
    end)
  end) then
    U.Debug("dropdown: ToggleDropDownMenu unavailable, popup menu stays native")
  end
  -- A row's text is set by AddButton; carry it into the row's own label at
  -- once (RowLabel) so no frame draws the previous menu's text.
  if not U.PostHookGlobal("UIDropDownMenu_AddButton", function(info, level)
    local lvl = tonumber(level) or tonumber(U.G("UIDROPDOWNMENU_MENU_LEVEL")) or 1
    local list = U.G("DropDownList" .. lvl)
    local count = list and tonumber(list.numButtons)
    local prefix = count and "DropDownList" .. lvl .. "Button" .. count
    local row = prefix and U.G(prefix)
    local native = prefix and U.G(prefix .. "NormalText")
    if row and native and row.puiDropdownLabel then RowLabel(row, native) end
  end) then
    U.Debug("dropdown: UIDropDownMenu_AddButton unavailable, row text syncs on menu open")
  end
  -- Optional: the tick-and-stay-open path refreshes entries through this
  -- global on Vanilla-shaped clients. Not present in the compact evidence, so
  -- the hook fails closed and the OnClick restyle above remains the fallback.
  if not U.PostHookGlobal("UIDropDownMenu_Refresh", function()
    StyleList(1)
    StyleList(2)
  end) then
    U.Debug("dropdown: UIDropDownMenu_Refresh unavailable, ticks refresh on click only")
  end
end

function D.EnsureTextLayout()
  -- WORKING_SOURCE: the client uses UIDropDownMenu_SetText(text, frame), not
  -- the modern frame-first signature. Its selection path can also update the
  -- label through UIDropDownMenu_SetSelectedID(frame, id, useValue).
  if not textHooked then
    local installed = U.PostHookGlobal("UIDropDownMenu_SetText", function(_, dropdown)
      if dropdown and dropdown.puiDropdownStyled then
        LayoutTextWhenSettled(dropdown)
      end
    end)
    if installed then textHooked = true end
  end
  if not selectedIdHooked then
    local installed = U.PostHookGlobal("UIDropDownMenu_SetSelectedID", function(dropdown)
      if dropdown and dropdown.puiDropdownStyled then
        LayoutTextWhenSettled(dropdown)
      end
    end)
    if installed then selectedIdHooked = true end
  end
end

-- options.bed: the control is drawn from a caller-supplied atlas bed instead
-- of either chrome below -- a three-slice cell stretched sideways only. The
-- caller owns the art and hands in only data, so this component reads no
-- theme token for it:
--
--   texture, sheet             file and its square size in texels
--   normal, hover, disabled    { x0, x1, y0, y1 } cells, in texels
--   pressed                    optional cell while the button is held
--   capLeft, capRight          texels kept at fixed aspect at each end
--   height                     drawn bed height
--   controlHeight              the control's own height (optional; the bed
--                              height when absent)
--   overhang                   how far the bed reaches outside the control on
--                              the left and right (optional, default 0)
--   arrow                      optional { cell, width, height, y }: a glyph
--                              shown BOTTOM of the control only while hovered
--                              or held, for a bed without a printed arrow
--   textInset                  the value's left inset (optional, default 5)
--   textAlign                  the value's justification (optional, "LEFT")
--   textColor, textSize        the value's colour and size (optional)
--
-- State is the cell: pressed while the button is held, hover while the pointer
-- is over it, disabled while it reports disabled, normal otherwise.
function D.BedPiece(dropdown, layer)
  local ok, texture = pcall(dropdown.CreateTexture, dropdown, nil, layer or "BACKGROUND")
  if not ok or not texture then return nil end
  pcall(texture.SetTexture, texture, dropdown.puiDropdownBed.texture)
  return texture
end

function D.BuildBed(dropdown, bed)
  dropdown.puiDropdownBed = bed
  if dropdown.puiDropdownBedPieces then return true end

  local pieces = { left = D.BedPiece(dropdown), middle = D.BedPiece(dropdown),
                   right = D.BedPiece(dropdown) }
  if not pieces.left or not pieces.middle or not pieces.right then return false end

  local cellHeight = bed.normal[4] - bed.normal[3]
  local height = bed.height or CONTROL_HEIGHT
  local left = bed.capLeft * height / cellHeight
  local right = bed.capRight * height / cellHeight
  local overhang = bed.overhang or 0
  -- Fixed height, centred on the control, never pinned to its top and bottom.
  -- Reported in game 2026-09-21: clicking the control changed the bed's
  -- height. Opening the list runs the client's own update path, which puts
  -- the stock height back on the frame from native code the SetHeight lock
  -- above cannot intercept, and a bed anchored TOP/BOTTOM stretched with it.
  -- The frame is anchored by its LEFT, so a height change leaves its centre
  -- where it is and a centred bed does not move.
  pcall(function()
    pieces.left:SetHeight(height)
    pieces.middle:SetHeight(height)
    pieces.right:SetHeight(height)
    pieces.left:SetWidth(left)
    pieces.left:SetPoint("LEFT", dropdown, "LEFT", -overhang, 0)
    pieces.right:SetWidth(right)
    pieces.right:SetPoint("RIGHT", dropdown, "RIGHT", overhang, 0)
    pieces.middle:SetPoint("LEFT", pieces.left, "RIGHT", 0, 0)
    pieces.middle:SetPoint("RIGHT", pieces.right, "LEFT", 0, 0)
  end)

  if bed.arrow then
    local arrow = D.BedPiece(dropdown, "OVERLAY")
    if arrow then
      local sheet, cell = bed.sheet, bed.arrow.cell
      pcall(function()
        arrow:SetTexCoord(cell[1] / sheet, cell[2] / sheet, cell[3] / sheet, cell[4] / sheet)
        arrow:SetWidth(bed.arrow.width)
        arrow:SetHeight(bed.arrow.height)
        -- Off the control's centre rather than its BOTTOM: the client puts
        -- its stock height back on the frame (see above), and the arrow has
        -- to stay with the drawn bed.
        local control = bed.controlHeight or height
        arrow:SetPoint("BOTTOM", dropdown, "CENTER", 0, -control / 2 + (bed.arrow.y or 0))
        arrow:Hide()
      end)
      pieces.arrow = arrow
    end
  end

  dropdown.puiDropdownBedPieces = pieces
  -- How far into the control the right cap reaches, which is what the value
  -- has to stop short of.
  dropdown.puiDropdownBedRight = math.max(0, right - overhang)
  return true
end

-- options.bed.menu: the open list's art for a bed control --
--   cell { x0, x1, y0, y1 }   texels on the bed's sheet, drawn as a nine-slice
--   cut { left, right, top, bottom } texels kept at fixed size on each side
--   scale                     drawn units per texel for those kept edges
--   inset { left, top, right, bottom } how far the art reaches outside the list
--   alpha                     the art's opacity (optional, default 1)
-- Drawn on a mouse-transparent child frame of the list, at the list's own
-- level so its rows stay above it.
function D.BedMenu(list, bed)
  local menu = bed and bed.menu
  if not list or not menu then return end
  local frame = list.puiDropdownBedMenu
  if not frame then
    local ok, made = pcall(CreateFrame, "Frame", nil, list)
    if not ok or not made then return end
    frame = made
    pcall(frame.EnableMouse, frame, false)
    frame.pieces = {}
    local keys = { "tl", "t", "tr", "l", "c", "r", "bl", "b", "br" }
    local i
    for i = 1, 9 do
      local okTexture, texture = pcall(frame.CreateTexture, frame, nil, "BACKGROUND")
      if okTexture and texture then frame.pieces[keys[i]] = texture end
    end
    list.puiDropdownBedMenu = frame
  end

  local p = frame.pieces
  if not p.tl or not p.c or not p.br then return end
  local sheet, cell, cut = bed.sheet, menu.cell, menu.cut
  local unit = menu.scale or 1
  local x0, x1, y0, y1 = cell[1], cell[2], cell[3], cell[4]
  local xs = { x0, x0 + cut.left, x1 - cut.right, x1 }
  local ys = { y0, y0 + cut.top, y1 - cut.bottom, y1 }
  -- Drawn sizes of the kept edges, per side.
  local wl, wr = cut.left * unit, cut.right * unit
  local ht, hb = cut.top * unit, cut.bottom * unit
  local order = { { "tl", 1, 1 }, { "t", 2, 1 }, { "tr", 3, 1 },
                  { "l", 1, 2 }, { "c", 2, 2 }, { "r", 3, 2 },
                  { "bl", 1, 3 }, { "b", 2, 3 }, { "br", 3, 3 } }
  local i
  for i = 1, 9 do
    local piece = p[order[i][1]]
    local col, row = order[i][2], order[i][3]
    if piece then
      pcall(piece.SetTexture, piece, bed.texture)
      pcall(piece.SetTexCoord, piece, xs[col] / sheet, xs[col + 1] / sheet,
            ys[row] / sheet, ys[row + 1] / sheet)
      pcall(piece.ClearAllPoints, piece)
    end
  end

  local inset = menu.inset or {}
  pcall(function()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", list, "TOPLEFT", -(inset.left or 0), inset.top or 0)
    frame:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", inset.right or 0, -(inset.bottom or 0))
    local levelOk, level = pcall(list.GetFrameLevel, list)
    if levelOk and tonumber(level) then frame:SetFrameLevel(level) end

    p.tl:SetWidth(wl); p.tl:SetHeight(ht); p.tl:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    p.tr:SetWidth(wr); p.tr:SetHeight(ht); p.tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    p.bl:SetWidth(wl); p.bl:SetHeight(hb); p.bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    p.br:SetWidth(wr); p.br:SetHeight(hb); p.br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    p.t:SetPoint("TOPLEFT", p.tl, "TOPRIGHT", 0, 0)
    p.t:SetPoint("BOTTOMRIGHT", p.tr, "BOTTOMLEFT", 0, 0)
    p.b:SetPoint("TOPLEFT", p.bl, "TOPRIGHT", 0, 0)
    p.b:SetPoint("BOTTOMRIGHT", p.br, "BOTTOMLEFT", 0, 0)
    p.l:SetPoint("TOPLEFT", p.tl, "BOTTOMLEFT", 0, 0)
    p.l:SetPoint("BOTTOMRIGHT", p.bl, "TOPRIGHT", 0, 0)
    p.r:SetPoint("TOPLEFT", p.tr, "BOTTOMLEFT", 0, 0)
    p.r:SetPoint("BOTTOMRIGHT", p.br, "TOPRIGHT", 0, 0)
    p.c:SetPoint("TOPLEFT", p.tl, "BOTTOMRIGHT", 0, 0)
    p.c:SetPoint("BOTTOMRIGHT", p.br, "TOPLEFT", 0, 0)
  end)
  -- Set on every open: the list is one shared pool, so another bed's alpha
  -- must not carry over.
  pcall(frame.SetAlpha, frame, menu.alpha or 1)
  pcall(frame.Show, frame)
end

-- `state` is "pressed", "hover" (or true, the older form), or nil for rest.
function D.PaintBed(dropdown, state)
  local pieces = dropdown and dropdown.puiDropdownBedPieces
  local bed = dropdown and dropdown.puiDropdownBed
  if not pieces or not bed then return end
  if state == true then state = "hover" end
  if state == false then state = nil end

  local cell = bed.normal
  local name = dropdown.GetName and dropdown:GetName()
  local button = dropdown.puiDropdownStateButton or
                 (name and U.G(name .. "Button"))
  if button and type(button.IsEnabled) == "function" then
    -- IsEnabled returns 1 / 0 on this client, not a boolean.
    local ok, enabled = pcall(button.IsEnabled, button)
    if ok and (enabled == 0 or enabled == nil or enabled == false) then
      cell = bed.disabled or cell
      state = "disabled"
    end
  end
  if state == "disabled" then
    -- A caller that is not a dropdown says so itself: the lookup above only
    -- finds the enabled state of a dropdown's own <name>Button.
    cell = bed.disabled or cell
  elseif state == "pressed" then
    cell = bed.pressed or bed.hover or cell
  elseif state == "hover" then
    cell = bed.hover or cell
  end

  local sheet = bed.sheet
  local x0, x1, y0, y1 = cell[1], cell[2], cell[3], cell[4]
  local l, r = x0 + bed.capLeft, x1 - bed.capRight
  pcall(pieces.left.SetTexCoord, pieces.left, x0 / sheet, l / sheet, y0 / sheet, y1 / sheet)
  pcall(pieces.middle.SetTexCoord, pieces.middle, l / sheet, r / sheet, y0 / sheet, y1 / sheet)
  pcall(pieces.right.SetTexCoord, pieces.right, r / sheet, x1 / sheet, y0 / sheet, y1 / sheet)

  if pieces.arrow then
    if state == "hover" or state == "pressed" then
      pcall(pieces.arrow.Show, pieces.arrow)
    else
      pcall(pieces.arrow.Hide, pieces.arrow)
    end
  end
end

-- options.modernWow: the caller has chosen its Modern WoW drawing path
-- (rules/pandaui-design.md branching rule); the control and its list take
-- the ThinBorder chrome instead of the flat edge. The caller decides the
-- theme once; this component never reads it.
--
-- options.checkboxes: the entries are independent on/off filters (the class
-- trainer's Filter menu), so each row gets an owned tick box. Leave it unset for
-- an ordinary single-select dropdown such as the Who list's zone/guild filter.
function D.StyleStock(dropdown, width, options)
  if not dropdown then return nil end
  options = options or {}
  D.EnsureMenuSkin()
  D.EnsureTextLayout()

  local name
  if dropdown.GetName then
    local ok, value = pcall(dropdown.GetName, dropdown)
    if ok then name = value end
  end
  if not name then return dropdown end
  dropdown.puiDropdownStyled = true
  dropdown.puiDropdownCheckboxes = options.checkboxes and true or false
  dropdown.puiDropdownModernWowRows = options.modernWow and true or false
  -- options.textY: added to this control's value offset (SetPoint sign,
  -- negative lowers it).
  dropdown.puiDropdownTextY = tonumber(options.textY) or nil

  U.HideRegion(U.G(name .. "Left"))
  U.HideRegion(U.G(name .. "Middle"))
  U.HideRegion(U.G(name .. "Right"))
  U.HideRegion(U.G(name .. "Icon"))
  if options.bed then
    local controlHeight = options.bed.controlHeight or options.bed.height
    if controlHeight then dropdown.puiDropdownHeight = controlHeight end
    D.BuildBed(dropdown, options.bed)
  elseif options.modernWow then
    dropdown.puiDropdownModernWowStyled = true
    -- The fill sits on the control itself, BACKGROUND, so its text (ARTWORK)
    -- stays above it; the border rides on the chrome child.
    ModernWowFill(dropdown, dropdown, M.modernWow.dropdown.fill)
    ModernWowChrome(dropdown)
  else
    U.CreateBackdrop(dropdown, { background = { 0.03, 0.03, 0.03, 0.85 } })
  end
  LockControlHeight(dropdown)
  ApplyControlHeight(dropdown)
  if width then pcall(dropdown.SetWidth, dropdown, width) end

  local button = U.G(name .. "Button")
  if button then
    -- Cover the whole control, not just the arrow's corner, so clicking the
    -- selected value opens the menu the same way clicking the arrow does.
    pcall(function()
      button:ClearAllPoints()
      button:SetAllPoints(dropdown)
    end)
    RemoveButtonArt(button)
    StyleArrow(button)
    if options.bed and button.puiDropdownArrow then
      -- The bed prints its own arrow. The glyph stays as an empty spacer over
      -- the right cap so LayoutText still stops the value short of it.
      local arrow = button.puiDropdownArrow
      pcall(function()
        arrow:SetText("")
        arrow:ClearAllPoints()
        arrow:SetPoint("RIGHT", button, "RIGHT",
                       -(dropdown.puiDropdownBedRight or 0), 0)
      end)
      if not button.puiDropdownBedHooked then
        button.puiDropdownBedHooked = true
        U.PostHookScript(button, "OnEnter", function()
          button.puiDropdownOver = true
          D.PaintBed(dropdown, "hover")
        end)
        U.PostHookScript(button, "OnLeave", function()
          button.puiDropdownOver = false
          D.PaintBed(dropdown, nil)
        end)
        U.PostHookScript(button, "OnMouseDown", function() D.PaintBed(dropdown, "pressed") end)
        U.PostHookScript(button, "OnMouseUp", function()
          D.PaintBed(dropdown, button.puiDropdownOver and "hover" or nil)
        end)
      end
    elseif options.modernWow and button.puiDropdownArrow then
      local arrow = button.puiDropdownArrow
      pcall(arrow.SetTextColor, arrow, M.Unpack(M.modernWow.dropdown.arrowColor))
      pcall(function()
        arrow:ClearAllPoints()
        arrow:SetPoint("RIGHT", button, "RIGHT", M.modernWow.dropdown.arrowX, 0)
      end)
    end
    AttachPlacement(dropdown, button)
  end

  -- Now and again one tick later: a FontString's new width does not settle in
  -- the frame that set it (widgets.fontstring_stringwidth_clamped_by_setwidth),
  -- and LayoutText re-writes the value against that width.
  LayoutTextWhenSettled(dropdown)
  if not dropdown.puiDropdownTextHooked then
    dropdown.puiDropdownTextHooked = U.PostHookScript(dropdown, "OnShow", function()
      -- USER_CONFIRMED_INGAME: changing the one-time SetHeight above did not
      -- change the visible trainer control. Reassert the component geometry
      -- after the native template's show/update path has restored its size.
      LayoutTextWhenSettled(dropdown)
      D.PaintBed(dropdown, false)
    end)
  end
  D.PaintBed(dropdown, false)
  return dropdown
end

-- Compatibility alias for callers not yet migrated to the component namespace.
function U.StyleStockDropdown(dropdown, width, options)
  return D.StyleStock(dropdown, width, options)
end
