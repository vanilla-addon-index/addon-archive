package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua"

-- This addon builds its own page in RollFor's options window. Core supplies the canvas and the
-- builders and asks for it; what ends up on it is entirely ours. These settings used to be on
-- core's own page, and core's page renders an explicit list of core's settings and nothing else
-- -- so this page is now the only place they are visible. The list of what gets looted used to
-- be a window of its own, and is the page's Loot tab now.
--
-- The doubles are local rather than borrowed from RollFor's test harness. Core's options
-- tests spy on its content transformer, which this page does not use: it talks to the
-- popup builder directly. Owning the page means owning the double for it.

require( "src/compat" )
local u = require( "RollForAutoLoot/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )

u.mock_wow_api()
require( "src/ItemUtils" )
require( "src/DropTable" )
require( "src/Tree" )
require( "src/SelectionTree" )
u.load_extension()

local OptionsPage = RollForAutoLoot.OptionsPage

-- Widgets that record what was done to them, so a test can ask what the page put on a
-- line rather than what it looks like on screen. What the real widgets draw is RollFor's
-- business, and the game's.
local function fake_widget()
  local widget = {}

  widget.SetText = function( _, text ) widget.text = text end
  widget.SetChecked = function( _, checked ) widget.checked = checked end
  widget.SetTabs = function( _, labels, selected )
    widget.labels = labels
    widget.selected = selected
  end
  widget.SetWidth = function( _, width ) widget.width = width end
  widget.GetWidth = function() return widget.width or 0 end
  widget.GetHeight = function() return 20 end
  widget.ClearAllPoints = function() end
  widget.SetPoint = function() end
  widget.Show = function() end
  widget.Hide = function() end

  return widget
end

-- A row of the list. Only the methods the real tree_node widget has, and nothing else, so a
-- call the widget would not answer fails here rather than in the game.
local function fake_tree_node()
  local row = {}

  row.SetDepth = function( _, depth ) row.depth = depth end
  row.SetExpandable = function( _, expandable, expanded )
    row.expandable = expandable
    row.expanded = expanded
  end
  row.SetChecked = function( _, checked ) row.checked = checked end
  row.SetDesaturated = function( _, desaturated ) row.desaturated = desaturated end
  row.SetItem = function( _, item, tooltip_link )
    row.item = item
    row.tooltip_link = tooltip_link
    row.text = nil
  end
  row.SetText = function( _, text )
    row.text = text
    row.item = nil
  end
  row.SetLabelStyle = function( _, color ) row.color = color end
  row.SetLabelTooltip = function() end
  row.SetWidth = function() end
  row.SetHeight = function() end
  row.GetWidth = function() return 0 end
  row.GetHeight = function() return 14 end
  row.ClearAllPoints = function() end
  row.SetPoint = function() end

  return row
end

local function fake_gui_elements()
  local elements = {}

  for _, line_type in ipairs( { "section_header", "paragraph", "tabs", "checkbox" } ) do
    elements[ line_type ] = fake_widget
  end

  elements.tree_node = fake_tree_node

  return elements
end

-- A popup that keeps its lines, which is the whole of what this page does with one. Scrolls the
-- way the real one does: a line of a scrolling type outside the window is dropped, and the
-- caller is told by getting nil back.
local function recording_popup_builder()
  local builder = {}
  local popup = { lines = {}, visible = false }
  local elements = {}
  local scrolling, on_scroll
  local scroll = { offset = 0, total = 0, index = 0 }

  local function is_scrolled_out( line_type )
    if not scrolling or scrolling.line_types ~= line_type then return false end

    scroll.index = scroll.index + 1

    return scroll.index <= scroll.offset or scroll.index > scroll.offset + scrolling.max_lines
  end

  local function max_offset()
    local result = scroll.total - (scrolling and scrolling.max_lines or 0)
    return result > 0 and result or 0
  end

  popup.add_line = function( line_type, modify_fn, padding )
    if is_scrolled_out( line_type ) then return end

    local frame = (elements[ line_type ] or fake_widget)()
    modify_fn( line_type, frame, popup.lines )

    local line = { line_type = line_type, frame = frame, padding = padding }
    table.insert( popup.lines, line )

    return line
  end

  popup.set_scroll_total = function( _, total )
    scroll.total = total
    if scroll.offset > max_offset() then scroll.offset = max_offset() end
  end

  popup.get_scroll = function()
    return { offset = scroll.offset, total = scroll.total, max_lines = scrolling and scrolling.max_lines or 0 }
  end

  popup.scroll_by = function( _, delta )
    local offset = math.min( math.max( scroll.offset + delta, 0 ), max_offset() )
    if offset == scroll.offset then return end

    scroll.offset = offset
    if on_scroll then on_scroll() end
  end

  popup.clear = function()
    popup.lines = {}
    scroll.index = 0
  end
  popup.Show = function() popup.visible = true end
  popup.IsVisible = function() return popup.visible end
  popup.SetBackdrop = function( _, backdrop ) popup.backdrop = backdrop end
  popup.SetBackdropColor = function() end
  popup.SetBackdropBorderColor = function() end
  popup.ClearAllPoints = function() popup.anchor = nil end
  popup.SetPoint = function( _, point, relative_frame, relative_point, x, y )
    popup.anchor = { point = point, relative_frame = relative_frame, relative_point = relative_point, x = x, y = y }
  end
  popup.SetWidth = function( _, width ) popup.width = width end
  popup.SetHeight = function( _, height ) popup.height = height end

  -- Every setter the page chains, answering with itself.
  for _, setter in ipairs( { "name", "parent", "point", "backdrop_color", "no_border" } ) do
    builder[ setter ] = function( self ) return self end
  end

  builder.gui_elements = function( self, value )
    elements = value
    return self
  end

  builder.scrollable = function( self, opts )
    scrolling = opts
    return self
  end

  builder.on_scroll = function( self, callback )
    on_scroll = callback
    return self
  end

  builder.build = function() return popup end

  return builder
end

-- What core hands over: the builders, this extension's own on/off state, the config its
-- settings were registered into, the selection tree, and this extension's db, seeded the way
-- on_ready seeds it. Not the summary -- that is ours, and lives in the page.
---@param overrides table?
local function mock_context( overrides )
  local store = {}
  RollForAutoLoot.AutoLootDb.ensure_seeded( store )

  local state = { enabled = true, set_to = nil, settings = {
    auto_loot = true,
    auto_loot_announce = true,
    auto_loot_messages = false
  } }

  local config = {}

  for key in pairs( state.settings ) do
    config[ key ] = function() return state.settings[ key ] end
    config[ "set_" .. key ] = function( value ) state.settings[ key ] = value end
  end

  local ctx = {
    popup_builder = recording_popup_builder,
    gui_elements = fake_gui_elements(),
    config = config,
    selection_tree = RollFor.SelectionTree,
    db = function() return store end,
    store = store,
    is_enabled = function() return state.enabled end,
    set_enabled = function( value )
      state.set_to = value
      state.enabled = value
    end,
    state = state
  }

  for key, value in pairs( overrides or {} ) do ctx[ key ] = value end

  return ctx
end

local CANVAS_WIDTH = 665

---@param ctx table
---@param canvas_width number?
local function shown_page( ctx, canvas_width )
  local canvas = u.modules().api.CreateFrame( "Frame" )
  canvas.GetWidth = function() return canvas_width or CANVAS_WIDTH end

  local page = OptionsPage.new( ctx, canvas )
  page.show()

  return page
end

-- Every line on the page, the summary and the tabs first and then what is in the panel under
-- them, in the order they read.
---@return table[]
local function all_lines( page )
  local result = {}

  for _, frame in ipairs( { page.get_frame(), page.get_panel() } ) do
    for _, entry in ipairs( frame.lines ) do table.insert( result, entry ) end
  end

  return result
end

---@return string[]
local function line_types( page )
  local result = {}

  for _, line in ipairs( all_lines( page ) ) do
    table.insert( result, line.line_type )
  end

  return result
end

---@return table
local function line( page, line_type )
  for _, entry in ipairs( all_lines( page ) ) do
    if entry.line_type == line_type then return entry.frame end
  end

  error( string.format( "There was no %s on the page.", line_type ), 2 )
end


---@return table
local function checkbox( page, label )
  for _, entry in ipairs( all_lines( page ) ) do
    if entry.line_type == "checkbox" and entry.frame.text == label then return entry.frame end
  end

  error( string.format( "There was no %q checkbox on the page.", label ), 2 )
end

-- The rows of the list that are on screen, top to bottom.
---@return table[]
local function rows( page )
  local result = {}

  for _, entry in ipairs( page.get_panel().lines ) do
    if entry.line_type == "tree_node" then table.insert( result, entry.frame ) end
  end

  return result
end

---@return table
local function row( page, text )
  for _, frame in ipairs( rows( page ) ) do
    if frame.text == text then return frame end
  end

  error( string.format( "There was no %q row on the page.", text ), 2 )
end

-- Opens rows until the list is longer than the panel shows at once.
local function expand_past_the_window( page )
  local index = 1

  while page.get_panel().get_scroll().total <= page.get_panel().get_scroll().max_lines do
    local frame = rows( page )[ index ]

    if frame.expandable and not frame.expanded then frame.on_click() end

    index = index + 1
  end
end

---@param label string
local function select_tab( page, label )
  local tabs = line( page, "tabs" )

  for index, tab_label in ipairs( tabs.labels ) do
    if tab_label == label then return tabs.on_select( index ) end
  end

  error( string.format( "There was no %q tab on the page.", label ), 2 )
end

OptionsPageSpec = {}

-- Summary first, tabs second, and the General tab open: a checkbox means nothing until you
-- know what it is you would be turning on.
function OptionsPageSpec:should_show_a_summary_then_the_general_tab()
  local page = shown_page( mock_context() )

  eq( line_types( page ), { "section_header", "paragraph", "tabs", "checkbox", "checkbox", "checkbox" } )
end

-- This addon's own copy, not something core handed over. Matched on what the pass actually does
-- rather than the opening line, which is the part most likely to get reworded.
function OptionsPageSpec:should_say_what_the_pass_does()
  local summary = line( shown_page( mock_context() ), "paragraph" ).text

  eq( string.find( summary, "Master-loots", 1, true ) ~= nil, true )
  eq( string.find( summary, "/rf autoloot", 1, true ) ~= nil, true )
end

TabsSpec = {}

function TabsSpec:should_offer_general_then_loot()
  local tabs = line( shown_page( mock_context() ), "tabs" )

  eq( tabs.labels, { "General", "Loot" } )
  eq( tabs.selected, 1 )
end

-- The summary stays put whichever tab is open; only what is under the tabs changes.
function TabsSpec:should_show_the_loot_tab_under_the_same_summary()
  local page = shown_page( mock_context() )

  select_tab( page, "Loot" )

  local types = line_types( page )
  eq( { types[ 1 ], types[ 2 ], types[ 3 ] }, { "section_header", "paragraph", "tabs" } )
  eq( line( page, "tabs" ).selected, 2 )
  eq( string.find( line( page, "paragraph" ).text, "Master-loots", 1, true ) ~= nil, true )
  eq( #rows( page ) > 0, true )
  eq( #rows( page ), #page.get_panel().lines )
end

function TabsSpec:should_switch_back_to_the_general_tab()
  local page = shown_page( mock_context() )

  select_tab( page, "Loot" )
  select_tab( page, "General" )

  eq( line_types( page ), { "section_header", "paragraph", "tabs", "checkbox", "checkbox", "checkbox" } )
  eq( checkbox( page, "Auto-loot" ).checked, true )
end

-- Coming back to the settings window finds the page on the tab it was left on.
function TabsSpec:should_keep_the_open_tab_between_visits()
  local page = shown_page( mock_context() )

  select_tab( page, "Loot" )
  page.show()

  eq( line( page, "tabs" ).selected, 2 )
  eq( rows( page )[ 1 ].text, "General" )
end

-- What /rf autoloot does before it opens the window: the page is drawn on that tab when the
-- window shows it.
function TabsSpec:should_open_on_the_tab_it_is_told_to()
  local canvas = u.modules().api.CreateFrame( "Frame" )
  canvas.GetWidth = function() return CANVAS_WIDTH end
  local page = OptionsPage.new( mock_context(), canvas )

  page.select_tab( "Loot" )
  page.show()

  eq( line( page, "tabs" ).selected, 2 )
end

-- The window only redraws a page when it switches to it, so a page already on screen redraws
-- itself.
function TabsSpec:should_switch_straight_away_when_it_is_already_on_screen()
  local page = shown_page( mock_context() )

  page.select_tab( "Loot" )

  eq( line( page, "tabs" ).selected, 2 )
  eq( rows( page )[ 1 ].text, "General" )
end

LootTabSpec = {}

-- The catalogue, every category closed, General first because it is the only part that is not
-- a raid.
function LootTabSpec:should_list_the_catalogue_collapsed()
  local page = shown_page( mock_context() )
  select_tab( page, "Loot" )

  eq( rows( page )[ 1 ].text, "General" )

  for _, frame in ipairs( rows( page ) ) do
    eq( frame.depth, 0 )
    eq( frame.expanded or false, false )
  end
end

function LootTabSpec:should_open_a_row_when_it_is_clicked()
  local page = shown_page( mock_context() )
  select_tab( page, "Loot" )

  row( page, "General" ).on_click()

  eq( rows( page )[ 2 ].text, "Uncommon" )
  eq( rows( page )[ 2 ].depth, 1 )
  eq( rows( page )[ 3 ].text, "Rare" )
end

-- Which rows are open lives on the tree, which the page keeps.
function LootTabSpec:should_keep_open_rows_open_between_visits()
  local page = shown_page( mock_context() )
  select_tab( page, "Loot" )

  row( page, "General" ).on_click()
  page.show()

  eq( row( page, "General" ).expanded, true )
  eq( rows( page )[ 2 ].text, "Uncommon" )
end

-- Ticking a row is the whole point of the list: it is what the sweep reads.
function LootTabSpec:should_write_a_ticked_row_back_to_the_db()
  local ctx = mock_context()
  local page = shown_page( ctx )
  select_tab( page, "Loot" )

  row( page, "General" ).on_click()
  row( page, "Uncommon" ).on_check( true )

  eq( ctx.store.ids[ RollForAutoLoot.AutoLootDb.GENERAL ].qualities[ 2 ].enabled, true )
  eq( row( page, "Uncommon" ).checked, true )
end

-- An item is drawn as its link, so it has the item's tooltip rather than a bare name.
function LootTabSpec:should_draw_an_item_as_its_link()
  local page = shown_page( mock_context() )
  select_tab( page, "Loot" )

  rows( page )[ 2 ].on_click()
  rows( page )[ 3 ].on_click()

  local item = rows( page )[ 4 ].item

  eq( type( item.link ), "string" )
  eq( string.find( item.link, "|Hitem:", 1, true ) ~= nil, true )
end

ScrollSpec = {}

function ScrollSpec:should_draw_no_more_rows_than_fit()
  local page = shown_page( mock_context() )
  select_tab( page, "Loot" )

  expand_past_the_window( page )

  -- However many rows the page asked the panel to show, rather than a copy of that number.
  eq( #rows( page ), page.get_panel().get_scroll().max_lines )
end

-- Whichever row is at the top, it sits the panel's inset below the border, and the panel keeps
-- its height as the list moves under it.
function ScrollSpec:should_keep_the_panel_still_while_the_list_scrolls()
  local page = shown_page( mock_context() )
  select_tab( page, "Loot" )
  expand_past_the_window( page )
  local height = page.get_panel().height

  page.get_panel():scroll_by( 1 )

  eq( page.get_panel().get_scroll().offset, 1 )
  eq( page.get_panel().lines[ 1 ].padding, 12 )
  eq( page.get_panel().height, height )
end

-- Nothing on the General tab scrolls, so the list's scrollbar does not follow it there.
function ScrollSpec:should_not_scroll_the_general_tab()
  local page = shown_page( mock_context() )
  select_tab( page, "Loot" )
  expand_past_the_window( page )

  select_tab( page, "General" )

  eq( page.get_panel().get_scroll().total, 0 )
end

-- The open tab's content is boxed in under the tabs, so it is plain which tab it belongs to.
PanelSpec = {}

function PanelSpec:should_put_the_tab_contents_in_the_bordered_panel()
  local page = shown_page( mock_context() )

  eq( #page.get_panel().lines, 3 )
  eq( page.get_panel().backdrop.edgeFile, "Interface\\Tooltips\\UI-Tooltip-Border" )
end

function PanelSpec:should_hang_the_panel_under_the_tabs()
  local page = shown_page( mock_context() )
  local anchor = page.get_panel().anchor

  eq( anchor.relative_frame, line( page, "tabs" ) )
  eq( anchor.point, "TOPLEFT" )
  eq( anchor.relative_point, "BOTTOMLEFT" )
end

-- Across the page rather than as wide as its widest setting, reaching further left than the
-- summary, with the first tab held in from the panel's corner.
function PanelSpec:should_span_the_page()
  local page = shown_page( mock_context() )
  local panel = page.get_panel()

  eq( panel.anchor.x, -8 )
  eq( panel.width, CANVAS_WIDTH - 32 + 14 )
end

-- Room above the first line and below the last, whichever tab is open.
function PanelSpec:should_fit_its_lines()
  local page = shown_page( mock_context() )

  eq( page.get_panel().height, 12 + 20 + 5 + 20 + 5 + 20 + 12 )

  select_tab( page, "Loot" )
  local count = #rows( page )

  eq( page.get_panel().height, 12 + count * 14 + (count - 1) * 2 + 12 )
end

SettingsSpec = {}

-- The three settings that moved here with the addon, in the order they read: the feature, then
-- what it says out loud.
function SettingsSpec:should_draw_a_checkbox_per_setting()
  local page = shown_page( mock_context() )

  eq( checkbox( page, "Auto-loot" ).checked, true )
  eq( checkbox( page, "Announce auto-looted items" ).checked, true )
  eq( checkbox( page, "Auto-loot messages" ).checked, false )
end

-- Read from the config every time the page is shown, so a value changed by a slash command
-- since the last visit is picked up rather than remembered.
function SettingsSpec:should_reread_the_config_every_time_it_is_shown()
  local ctx = mock_context()
  local page = shown_page( ctx )

  ctx.config.set_auto_loot( false )
  page.show()

  eq( checkbox( page, "Auto-loot" ).checked, false )
end

function SettingsSpec:should_write_a_clicked_checkbox_back_to_the_config()
  local ctx = mock_context()
  local page = shown_page( ctx )

  checkbox( page, "Auto-loot messages" ).on_click( true )

  eq( ctx.config.auto_loot_messages(), true )
end

ExtensionSwitchSpec = {}

-- No Enabled switch, because "Auto-loot" is already it: two switches for one question could
-- disagree, and Auto-loot ticked on a disabled extension reads as broken. The addon declares
-- hide_enabled_option, so core draws none either and keeps the extension on -- which is what
-- makes leaving it off this page safe rather than a way to strand somebody.
function ExtensionSwitchSpec:should_not_draw_an_enabled_switch()
  local page = shown_page( mock_context() )

  for _, entry in ipairs( all_lines( page ) ) do
    eq( entry.frame.text ~= "Enabled", true, "The page still draws an Enabled switch." )
  end
end

-- It never asks core either. A page that read is_enabled would be showing a value nothing can
-- change, and one that wrote it would be writing something core refuses.
function ExtensionSwitchSpec:should_not_touch_cores_enabled_state()
  local ctx = mock_context()
  shown_page( ctx )

  eq( ctx.state.set_to, nil )
end

os.exit( lu.LuaUnit.run() )
