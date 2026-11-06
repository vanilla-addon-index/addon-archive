package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

-- This addon builds its own page in RollFor's options window. Core supplies the canvas
-- and the builders and asks for it; what ends up on it is entirely ours, which is the
-- point -- an extension keeps its own database, so core cannot know what belongs there.
--
-- The doubles are local rather than borrowed from RollFor's test harness. Core's options
-- tests spy on its content transformer, which this page does not use: it talks to the
-- popup builder directly. Owning the page means owning the double for it.

require( "src/compat" )
local u = require( "RollForSoftRes/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )

u.mock_wow_api()
u.load_extension()

local OptionsPage = RollForSoftRes.OptionsPage

-- Widgets that record what was done to them, so a test can ask what the page put on a
-- line rather than what it looks like on screen. What the real widgets draw is RollFor's
-- business, and the game's.
local function fake_widget()
  local widget = {}

  widget.SetText = function( _, text ) widget.text = text end
  widget.SetChecked = function( _, checked ) widget.checked = checked end
  widget.SetMinMaxValues = function( _, min, max ) widget.min, widget.max = min, max end
  widget.SetPrecision = function( _, precision ) widget.precision = precision end
  widget.SetValue = function( _, value ) widget.value = value end
  widget.SetWidth = function( _, width ) widget.width = width end
  widget.GetWidth = function() return widget.width or 0 end
  widget.ClearAllPoints = function() end
  widget.SetPoint = function() end
  widget.Show = function() end
  widget.Hide = function() end

  return widget
end

local function fake_gui_elements()
  local elements = {}

  for _, line_type in ipairs( { "section_header", "paragraph", "checkbox", "slider" } ) do
    elements[ line_type ] = fake_widget
  end

  return elements
end

-- A popup that keeps its lines, which is the whole of what this page does with one.
local function recording_popup_builder()
  local builder = {}
  local popup = { lines = {}, visible = false }

  popup.add_line = function( line_type, modify_fn, padding )
    local frame = fake_widget()
    modify_fn( line_type, frame, popup.lines )

    local line = { line_type = line_type, frame = frame, padding = padding }
    table.insert( popup.lines, line )

    return line
  end

  popup.clear = function() popup.lines = {} end
  popup.Show = function() popup.visible = true end
  popup.IsVisible = function() return popup.visible end

  -- Every setter the page chains, answering with itself.
  for _, setter in ipairs( {
    "name", "parent", "point", "gui_elements", "backdrop_color", "no_border"
  } ) do
    builder[ setter ] = function( self ) return self end
  end

  builder.build = function() return popup end

  return builder
end

-- What core hands over: the builders and this extension's own on/off state. Not the
-- summary -- that is ours, and lives in the page.
---@param overrides table?
local function mock_context( overrides )
  local state = { enabled = true, set_to = nil, rows = 15 }

  local ctx = {
    popup_builder = recording_popup_builder,
    gui_elements = fake_gui_elements(),
    is_enabled = function() return state.enabled end,
    set_enabled = function( value )
      state.set_to = value
      state.enabled = value
    end,
    -- Core's config, as far as this page uses it: the list rows setting's getter and setter.
    config = {
      softres_list_rows = function() return state.rows end,
      set_softres_list_rows = function( value ) state.rows = value end
    },
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

---@return string[]
local function line_types( page )
  local result = {}

  for _, line in ipairs( page.get_frame().lines ) do
    table.insert( result, line.line_type )
  end

  return result
end

---@return table
local function line( page, line_type )
  for _, entry in ipairs( page.get_frame().lines ) do
    if entry.line_type == line_type then return entry.frame end
  end

  error( string.format( "There was no %s on the page.", line_type ), 2 )
end

OptionsPageSpec = {}

-- Summary first, switch second: the checkbox means nothing until you know what it is you
-- would be turning on.
function OptionsPageSpec:should_show_a_summary_then_an_enabled_checkbox_then_the_rows_slider()
  local page = shown_page( mock_context() )

  eq( line_types( page ), { "section_header", "paragraph", "checkbox", "slider" } )
  eq( line( page, "checkbox" ).text, "Enabled" )

  -- The summary is this addon's own copy, not something core handed over. Matched on the
  -- commands it documents rather than the opening line, which is the part most likely to
  -- get reworded.
  eq( string.find( line( page, "paragraph" ).text, "/sr", 1, true ) ~= nil, true )

  -- And it names no website. The addon reads none: a provider supplies the format, and
  -- naming a site here would be this page claiming a capability it does not have.
  eq( string.find( line( page, "paragraph" ).text, "softres.it", 1, true ), nil )
  eq( string.find( line( page, "paragraph" ).text, "raidres", 1, true ), nil )
  eq( string.find( line( page, "paragraph" ).text, "provider", 1, true ) ~= nil, true )
end

function OptionsPageSpec:should_tick_the_checkbox_when_the_extension_is_on()
  local page = shown_page( mock_context() )

  eq( line( page, "checkbox" ).checked, true )
end

function OptionsPageSpec:should_untick_the_checkbox_when_the_extension_is_off()
  local ctx = mock_context()
  ctx.state.enabled = false

  eq( line( shown_page( ctx ), "checkbox" ).checked, false )
end

-- The switch is this addon's, not core's, so it has to be wired to core's on/off through
-- the context rather than assumed to work.
function OptionsPageSpec:should_toggle_the_extension_when_the_checkbox_is_clicked()
  local ctx = mock_context()
  local page = shown_page( ctx )

  line( page, "checkbox" ).on_click( false )

  eq( ctx.state.set_to, false )
end

-- Core calls show() on every visit. Rebuilding rather than appending is what keeps the
-- checkbox honest when the extension was toggled from somewhere else in between.
function OptionsPageSpec:should_rebuild_itself_rather_than_grow_on_every_visit()
  local page = shown_page( mock_context() )

  page.show()
  page.show()

  eq( line_types( page ), { "section_header", "paragraph", "checkbox", "slider" } )
end

function OptionsPageSpec:should_reread_the_enabled_state_on_every_visit()
  local ctx = mock_context()
  local page = shown_page( ctx )

  ctx.state.enabled = false
  page.show()

  eq( line( page, "checkbox" ).checked, false )
end

-- The summary is prose and is meant to wrap, but at the widget's default width it wraps
-- to a column much narrower than the settings window, so it takes the width of the canvas
-- it is actually in.
function OptionsPageSpec:should_widen_the_summary_to_the_canvas()
  local page = shown_page( mock_context() )

  eq( line( page, "paragraph" ).width, CANVAS_WIDTH - 32 )
end

-- The settings window sizes the canvas when it shows the page, so a page asked before
-- that has nothing to measure. Better the widget's own width than a nonsense one.
function OptionsPageSpec:should_leave_the_width_alone_when_the_canvas_has_none_yet()
  local page = shown_page( mock_context(), 0 )

  eq( line( page, "paragraph" ).width, nil )
end

function OptionsPageSpec:should_show_the_list_rows_setting_on_the_slider()
  local ctx = mock_context()
  ctx.state.rows = 22

  local slider = line( shown_page( ctx ), "slider" )

  eq( slider.text, "Soft-res list rows" )
  eq( { slider.min, slider.max, slider.precision, slider.value }, { 5, 30, 0, 22 } )
end

function OptionsPageSpec:should_change_the_list_rows_setting_when_the_slider_moves()
  local ctx = mock_context()
  local slider = line( shown_page( ctx ), "slider" )

  slider.on_change( 8 )

  eq( ctx.state.rows, 8 )
end

-- Like the checkbox: the setting can change from /rf config between visits.
function OptionsPageSpec:should_reread_the_list_rows_setting_on_every_visit()
  local ctx = mock_context()
  local page = shown_page( ctx )

  ctx.state.rows = 11
  page.show()

  eq( line( page, "slider" ).value, 11 )
end

os.exit( lu.LuaUnit.run() )
