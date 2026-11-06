RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.SoftResListWidgets then return end

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

-- The soft-res list's header and row widgets.
--
-- FrameBuilder resolves a line by looking its type up in the gui_elements table, so an extension
-- adding line types is a matter of writing keys into that table -- see PendingLootWidgets and
-- RoundRobinWidgets, which do the same. Registered during on_enable, before any window is built.

local M = {}

local line_height = 16
local text_color = { 1, 1, 1 }

-- Columns shared by the header and the rows, so the headings sit over their cells. Each is as wide
-- as the widest thing in it -- measured by the window over the whole list and handed to every line
-- of a redraw alike (SoftResListWidths) -- or as its heading and sort arrow, if that is wider.
-- Every line of a redraw therefore comes out the same width, which is what ListPopup's centring
-- needs to keep the columns lined up.
local column_gap = 16

-- The roll count hangs left of the item link, in a gutter at the start of the item column, so every
-- link -- and the Item heading above them -- starts at the same x whether it has a count or not.
local count_gap = 3

-- Every row starts with the box that switches its reservation off, in a gutter of its own left of
-- the Player column. Fixed width rather than measured: there is nothing in it but the box, and no
-- heading over it, since there is nothing about a checkbox to sort by.
local row_checkbox_size = 12
local row_checkbox_gap = 5

-- A grouped row with some of its rolls switched off is drawn as a greyed tick rather than as a
-- third texture: it reads as "on, but not entirely", which is what it means.
local tick_color = { 1, 1, 1 }
local partial_tick_color = { 0.5, 0.5, 0.5 }

local columns = {
  { key = "player", title = "Player" },
  { key = "item", title = "Item" },
  { key = "boss", title = "Boss" }
}

-- The checkboxes above the headings, and the space between them and the headings. Smaller than
-- core's checkbox, which is sized for an options page: these sit over a list of small print and
-- are set in the same small font as the headings. `checkbox_x` nudges the first left of the
-- headings' edge and `checkbox_y` up, without moving the headings.
--
-- Both sit on one line rather than stacked, so the list keeps the height it had when there was
-- only one of them.
local checkbox_size = 14
local checkbox_label_gap = 3
local checkbox_gap = 4
local checkbox_spacing = 12
local checkbox_x = -8
local checkbox_y = 2
local absent_checkbox_text = "Show players not in the group"
local group_checkbox_text = "Group items"

-- The button that names everybody in the group who reserved nothing, on the checkboxes' line at the
-- far right, just left of the window's X. The client's own panel button in the list's small font,
-- as wide as its label and its end caps.
local announce_button_text = "Announce missing"
local announce_button_height = 18
local announce_button_caps = 16

-- How far the X reaches into the header from its right, since the button stops short of it rather
-- than of the header's edge. The X is ListPopup's close button: 32 pixels scaled by 0.7, 6 in from
-- the window's edge, which puts its left at 28.4; the header's edge is half PopupBuilder's side
-- margin of 35 in, at 17.5.
local close_button_intrusion = 11

-- Blizzard's own sort arrow, at the size and with the flip the auction house uses
-- (SortButton_UpdateArrow in Blizzard_AuctionUI).
local sort_arrow_texture = "Interface\\Buttons\\UI-SortArrow"
local sort_arrow_width = 9
local sort_arrow_height = 8
local sort_arrow_gap = 3

-- The tint behind a heading or a row under the mouse. Drawn a little past the sides, since the
-- text sits flush against the left edge; the column gap leaves room for that. Top and bottom stay
-- on the line's own edges.
local highlight_texture = "Interface\\Buttons\\WHITE8x8"
local highlight_color = { 1, 1, 1, 0.12 }
local highlight_overhang = 2

-- A row's highlight reaches further out at both ends, where there is no neighbouring column to
-- stop at. The outer edges of the Player and Boss headings' highlights do too, so they line up with
-- the rows' below them.
local row_highlight_overhang = 6

-- The headings' line is always faintly tinted, to set it apart from the rows. Fainter than a
-- highlight, which still shows on top of it.
local heading_row_color = { 1, 1, 1, 0.06 }

-- A font string nobody sees, in the font every cell uses, for measuring text before it is drawn.
local measure

-- How wide `text` draws in the list's font. Colour codes and a link's hyperlink wrapper take no
-- room, so a coloured name or an item link measures as what the player sees.
---@param text string
---@return number
function M.text_width( text )
  if not measure then
    local frame = m.api.CreateFrame( "Frame" )
    frame:Hide()
    measure = frame:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
  end

  measure:SetText( text )

  return measure:GetStringWidth()
end

---@return number
local function announce_button_width()
  return M.text_width( announce_button_text ) + announce_button_caps
end

-- How wide a checkbox and its label draw together.
---@param text string
---@return number
local function checkbox_width( text )
  return checkbox_size + checkbox_label_gap + M.text_width( text )
end

---@class SoftResListColumnLayout
---@field x number
---@field width number
---@field inset number -- where the heading and the content start, from the column's left edge

---@class SoftResListLayout
---@field checkbox SoftResListColumnLayout -- the row's own box; the header leaves it empty
---@field player SoftResListColumnLayout
---@field item SoftResListColumnLayout
---@field boss SoftResListColumnLayout
---@field width number

-- Where each column goes, given how wide their contents measured. Worked out the same way for the
-- header and for every row, which is what keeps them lined up.
---@param widths SoftResListWidths
---@return SoftResListLayout
local function layout( widths )
  local result = {}

  -- The checkbox gutter is part of every line, the header included, which is what keeps the
  -- headings over the cells they name rather than over the boxes.
  result.checkbox = { x = 0, width = row_checkbox_size, inset = 0 }
  local x = row_checkbox_size + row_checkbox_gap

  for _, column in ipairs( columns ) do
    local inset = column.key == "item" and widths.count > 0 and widths.count + count_gap or 0
    local heading = M.text_width( column.title ) + sort_arrow_gap + sort_arrow_width
    local width = inset + math.max( widths[ column.key ], heading )

    result[ column.key ] = { x = x, width = width, inset = inset }
    x = x + width + column_gap
  end

  -- The checkboxes sit over the columns, so they are what set the width when the columns are
  -- narrower. The Announce missing button shares their line, and its room is kept whether it is
  -- showing or not: the window doesn't narrow under the mouse when the last player reserves.
  local checkboxes = checkbox_x + checkbox_width( absent_checkbox_text ) + checkbox_spacing +
      checkbox_width( group_checkbox_text ) + checkbox_spacing + announce_button_width() + close_button_intrusion
  result.width = math.max( x - column_gap, checkboxes )

  return result
end

---@param parent table
local function add_highlight( parent )
  local texture = parent:CreateTexture( nil, "BACKGROUND" )
  texture:SetTexture( highlight_texture )
  texture:SetVertexColor( unpack( highlight_color ) )
  texture:ClearAllPoints()
  texture:SetPoint( "TOPLEFT", parent, "TOPLEFT", -row_highlight_overhang, 0 )
  texture:SetPoint( "BOTTOMRIGHT", parent, "BOTTOMRIGHT", row_highlight_overhang, 0 )

  return texture
end

-- Core's checkbox (GuiElements.checkbox) at the list's own scale.
---@param parent table
local function checkbox( parent )
  local container = m.api.CreateFrame( "Frame", nil, parent )
  local button = m.api.CreateFrame( "CheckButton", nil, container, "UICheckButtonTemplate" )
  button:SetWidth( checkbox_size )
  button:SetHeight( checkbox_size )
  button:SetPoint( "LEFT", container, "LEFT", 0, 0 )

  local label = container:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
  label:SetTextColor( unpack( text_color ) )
  label:SetPoint( "LEFT", button, "RIGHT", checkbox_label_gap, 0 )

  container:SetHeight( checkbox_size )

  container.SetText = function( _, text )
    label:SetText( text )
    container:SetWidth( checkbox_size + checkbox_label_gap + label:GetWidth() )
  end

  container.SetChecked = function( _, checked )
    button:SetChecked( checked and true or false )
  end

  button:SetScript( "OnClick", function()
    if container.on_click then container.on_click( button:GetChecked() and true or false ) end
  end )

  return container
end

-- The box at the head of a row, which switches that reservation off. Bare, with no label: what it
-- refers to is the row it is on.
--
-- The client flips a CheckButton's own state on click; this hands the click on and lets the
-- redraw that follows put the box where the window says it goes. Left to itself it would have no
-- way to land on the greyed third state, and a box that disagreed with the list under it would be
-- worse than one that lagged a frame.
---@param parent table
local function row_checkbox( parent )
  local button = m.api.CreateFrame( "CheckButton", nil, parent, "UICheckButtonTemplate" )
  button:SetWidth( row_checkbox_size )
  button:SetHeight( row_checkbox_size )

  button:SetScript( "OnClick", function()
    if button.on_click then button.on_click() end
  end )

  return button
end

-- The line above the list that is never scrolled: the checkboxes, then a heading per column.
-- Clicking a heading asks the window to sort by it.
---@param parent table
function M.softres_list_header( parent )
  local container = m.api.CreateFrame( "Frame", nil, parent )
  container:SetHeight( checkbox_size + checkbox_gap + line_height )

  local show_absent = checkbox( container )
  show_absent:SetPoint( "TOPLEFT", container, "TOPLEFT", checkbox_x, checkbox_y )
  show_absent:SetText( absent_checkbox_text )

  show_absent.on_click = function( checked )
    if container.on_toggle_absent then container.on_toggle_absent( checked ) end
  end

  -- Anchored to the first rather than to the container, so the two stay a fixed gap apart
  -- whatever their labels measure.
  local group_items = checkbox( container )
  group_items:SetPoint( "LEFT", show_absent, "RIGHT", checkbox_spacing, 0 )
  group_items:SetText( group_checkbox_text )

  group_items.on_click = function( checked )
    if container.on_toggle_group_items then container.on_toggle_group_items( checked ) end
  end

  -- Anchored to the X itself, which is on the window rather than on this line, so the two sit
  -- together wherever the window's width puts them. Measured once: the label never changes.
  local announce = m.api.CreateFrame( "Button", nil, container, "UIPanelButtonTemplate" )
  announce:SetNormalFontObject( "GameFontNormalSmall" )
  announce:SetHighlightFontObject( "GameFontHighlightSmall" )
  announce:SetDisabledFontObject( "GameFontDisableSmall" )
  announce:SetHeight( announce_button_height )
  announce:SetWidth( announce_button_width() )
  announce:SetText( announce_button_text )
  announce:Hide()

  -- The list window is always built with its X, so the other branch is only there for a window
  -- that wasn't: the header's own corner, level with the checkboxes.
  if parent.close_button then
    announce:SetPoint( "RIGHT", parent.close_button, "LEFT", 0, 0 )
  else
    announce:SetPoint( "RIGHT", container, "TOPRIGHT", 0, checkbox_y - checkbox_size / 2 )
  end

  announce:SetScript( "OnClick", function()
    if container.on_announce_missing then container.on_announce_missing() end
  end )

  -- Spans the headings' line only, not the checkbox above it, out to where the rows' highlights
  -- reach.
  local heading_row = container:CreateTexture( nil, "BACKGROUND" )
  heading_row:SetTexture( highlight_texture )
  heading_row:SetVertexColor( unpack( heading_row_color ) )
  heading_row:ClearAllPoints()
  heading_row:SetPoint( "BOTTOMLEFT", container, "BOTTOMLEFT", -row_highlight_overhang, 0 )
  heading_row:SetPoint( "TOPRIGHT", container, "BOTTOMRIGHT", row_highlight_overhang, line_height )

  local headings = {}

  for i, column in ipairs( columns ) do
    local heading = m.api.CreateFrame( "Button", nil, container )
    local left_overhang = i == 1 and row_highlight_overhang or highlight_overhang
    local right_overhang = i == #columns and row_highlight_overhang or highlight_overhang
    heading:SetHeight( line_height )

    -- The Button's own highlight layer: the client shows and hides it on hover.
    heading:SetHighlightTexture( highlight_texture, "BLEND" )
    local highlight = heading:GetHighlightTexture()
    highlight:SetVertexColor( unpack( highlight_color ) )
    highlight:ClearAllPoints()
    highlight:SetPoint( "TOPLEFT", heading, "TOPLEFT", -left_overhang, 0 )
    highlight:SetPoint( "BOTTOMRIGHT", heading, "BOTTOMRIGHT", right_overhang, 0 )

    local label = heading:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
    label:SetText( m.colors.hl( column.title ) )

    local arrow = heading:CreateTexture( nil, "ARTWORK" )
    arrow:SetTexture( sort_arrow_texture )
    arrow:SetWidth( sort_arrow_width )
    arrow:SetHeight( sort_arrow_height )
    arrow:SetPoint( "LEFT", label, "RIGHT", sort_arrow_gap, 0 )

    heading:SetScript( "OnClick", function()
      if container.on_sort then container.on_sort( column.key ) end
    end )

    headings[ column.key ] = { frame = heading, label = label, arrow = arrow }
  end

  -- FrameBuilder recycles line frames across refreshes, so every field is written on every call,
  -- the callbacks and the layout included.
  container.SetRow = function( _, row )
    show_absent:SetChecked( row.show_absent )
    group_items:SetChecked( row.group_items )
    container.on_toggle_absent = row.on_toggle_absent
    container.on_toggle_group_items = row.on_toggle_group_items
    container.on_sort = row.on_sort
    container.on_announce_missing = row.on_announce_missing

    if row.on_announce_missing then announce:Show() else announce:Hide() end

    local columns_layout = layout( row.widths )
    container:SetWidth( columns_layout.width )

    for key, heading in pairs( headings ) do
      local column = columns_layout[ key ]

      heading.frame:ClearAllPoints()
      heading.frame:SetPoint( "BOTTOMLEFT", container, "BOTTOMLEFT", column.x, 0 )
      heading.frame:SetWidth( column.width )
      heading.label:ClearAllPoints()
      heading.label:SetPoint( "LEFT", heading.frame, "LEFT", column.inset, 0 )

      if key ~= row.sort_column then
        heading.arrow:Hide()
      else
        if row.sort_ascending then
          heading.arrow:SetTexCoord( 0, 0.5625, 0, 1 )
        else
          heading.arrow:SetTexCoord( 0, 0.5625, 1, 0 )
        end

        heading.arrow:Show()
      end
    end
  end

  return container
end

---@param parent table
---@param justify string?
local function cell( parent, justify )
  local text = parent:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
  text:SetHeight( line_height )
  text:SetJustifyH( justify or "LEFT" )
  text:SetTextColor( unpack( text_color ) )

  return text
end

---@param text table
---@param parent table
---@param x number
---@param width number
local function place( text, parent, x, width )
  text:ClearAllPoints()
  text:SetPoint( "LEFT", parent, "LEFT", x, 0 )
  text:SetWidth( width )
end

-- One reservation: player, item, boss. While the list is grouped, more than one roll shows as 2x
-- in the gutter left of the item; ungrouped, each roll is its own row and the gutter is empty.
---@param parent table
function M.softres_list_row( parent )
  local container = m.api.CreateFrame( "Frame", nil, parent )
  container:SetHeight( line_height )

  local player = cell( container )
  local boss = cell( container )

  -- Whether this reservation counts. Created for every row, including the ones that have nothing
  -- to switch off: FrameBuilder recycles row frames, so a row that built its box conditionally
  -- would hand it to whoever occupied the frame next.
  local enabled = row_checkbox( container )

  -- Drawn here rather than by the link, which puts its own count inline and so pushes the name
  -- right by however wide the count is.
  local count = cell( container, "RIGHT" )

  -- Core's item link, which brings the tooltip, the ctrl-click dressing room and the shift-click
  -- chat link.
  local item = m.GuiElements.item_link( container )

  -- What modifiers add to the player's rolls, right after the link. Its own text rather than
  -- part of the link's, which is what a shift-click pastes into chat.
  local adjustment = cell( container )

  -- The whole row lights up under the mouse. Polled rather than driven by OnEnter/OnLeave: those
  -- need the row to take the mouse, and a row that takes the mouse stops the window being dragged
  -- by it -- and the item link, which does take the mouse, would count as leaving the row.
  local highlight = add_highlight( container )
  highlight:Hide()

  container:SetScript( "OnUpdate", function()
    if m.api.MouseIsOver( container ) then highlight:Show() else highlight:Hide() end
  end )

  container.SetRow = function( _, row )
    local columns_layout = layout( row.widths )
    local item_column = columns_layout.item
    container:SetWidth( columns_layout.width )

    enabled:ClearAllPoints()
    enabled:SetPoint( "LEFT", container, "LEFT", columns_layout.checkbox.x, 0 )
    place( player, container, columns_layout.player.x, columns_layout.player.width )
    place( count, container, item_column.x, row.widths.count )
    place( boss, container, columns_layout.boss.x, columns_layout.boss.width )
    item:ClearAllPoints()
    item:SetPoint( "LEFT", container, "LEFT", item_column.x + item_column.inset, 0 )
    adjustment:ClearAllPoints()
    adjustment:SetPoint( "LEFT", item, "RIGHT", 0, 0 )

    -- A player who reserved nothing has no entry to switch off, so the gutter is left empty --
    -- the space stays, or the columns would step left on that row alone.
    if row.enabled then
      enabled:Show()
      enabled:SetChecked( row.enabled ~= "off" )
      enabled.on_click = row.on_toggle_enabled

      local tick = enabled.GetCheckedTexture and enabled:GetCheckedTexture()

      if tick then
        tick:SetVertexColor( unpack( row.enabled == "partial" and partial_tick_color or tick_color ) )
      end
    else
      enabled:Hide()
      enabled.on_click = nil
    end

    player:SetText( row.player )
    count:SetText( row.count or "" )
    item:SetItem( { link = row.item_link, chat_link = row.item_chat_link }, row.item_tooltip_link )
    adjustment:SetText( row.adjustment or "" )
    boss:SetText( row.boss )
  end

  -- Nothing emits a header row for this list, but ListPopup calls this on every row it draws.
  container.SetHeader = function() end

  return container
end

-- Written into core's table, which is what FrameBuilder resolves lines against. Called from
-- on_enable, before anything builds a window.
---@param gui_elements table -- ctx.gui_elements
function M.register( gui_elements )
  gui_elements[ sr.SoftResListContentTransformer.header_type ] = M.softres_list_header
  gui_elements[ sr.SoftResListContentTransformer.row_type ] = M.softres_list_row
end

sr.SoftResListWidgets = M
return M
