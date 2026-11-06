package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua"

-- This addon builds its own page in RollFor's options window, and it is the only reason there
-- is a page at all: it registers no settings, so core's fallback would draw a lone Enabled
-- checkbox with nothing saying what it turns on -- for a feature named after somebody else's
-- addon, which is the worst case for a bare switch.
--
-- The doubles are local rather than borrowed from RollFor's test harness. Core's options
-- tests spy on its content transformer, which this page does not use: it talks to the
-- popup builder directly. Owning the page means owning the double for it.

require( "src/compat" )
local u = require( "RollForGargul/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )

u.mock_wow_api()
u.load_extension()

local OptionsPage = RollForGargul.OptionsPage

-- Widgets that record what was done to them, so a test can ask what the page put on a
-- line rather than what it looks like on screen. What the real widgets draw is RollFor's
-- business, and the game's.
local function fake_widget()
  local widget = {}

  widget.SetText = function( _, text ) widget.text = text end
  widget.SetChecked = function( _, checked ) widget.checked = checked end
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

  for _, line_type in ipairs( { "section_header", "paragraph", "checkbox" } ) do
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

-- What core hands over: the builders and this extension's own on/off state. No config, because
-- there are no settings -- and not the summary either, which is ours and lives in the page.
---@param overrides table?
local function mock_context( overrides )
  local state = { enabled = true, set_to = nil }

  local ctx = {
    popup_builder = recording_popup_builder,
    gui_elements = fake_gui_elements(),
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


---@return table
local function checkbox( page, label )
  for _, entry in ipairs( page.get_frame().lines ) do
    if entry.line_type == "checkbox" and entry.frame.text == label then return entry.frame end
  end

  error( string.format( "There was no %q checkbox on the page.", label ), 2 )
end

OptionsPageSpec = {}

-- Summary first, switch second: a checkbox means nothing until you know what it is you would be
-- turning on, and "Gargul" on its own tells somebody who does not use Gargul nothing at all.
function OptionsPageSpec:should_show_a_summary_then_the_switch()
  local page = shown_page( mock_context() )

  eq( line_types( page ), { "section_header", "paragraph", "checkbox" } )
end

-- This addon's own copy, not something core handed over. Matched on what it actually does for
-- the raid rather than the opening line, which is the part most likely to get reworded.
function OptionsPageSpec:should_say_what_it_does_for_the_raid()
  local summary = line( shown_page( mock_context() ), "paragraph" ).text

  eq( string.find( summary, "Gargul", 1, true ) ~= nil, true )
  eq( string.find( summary, "soft-res", 1, true ) ~= nil, true )
end

-- Rebuilt from scratch on every visit: the switch has to show what is true now, and it can be
-- changed from the extension list between one viewing and the next.
function OptionsPageSpec:should_redraw_rather_than_stack_lines_on_a_second_visit()
  local ctx = mock_context()
  local page = shown_page( ctx )

  page.show()

  eq( line_types( page ), { "section_header", "paragraph", "checkbox" } )
end

ExtensionSwitchSpec = {}

-- Core only injects the Enabled switch onto the page it draws for an extension that supplies
-- none of its own. Supplying this page means carrying it -- and without it there would be
-- nowhere left to turn the addon back on.
function ExtensionSwitchSpec:should_carry_the_extensions_own_enabled_switch()
  local page = shown_page( mock_context() )

  eq( checkbox( page, "Enabled" ).checked, true )
end

function ExtensionSwitchSpec:should_show_the_switch_off_when_the_extension_is_disabled()
  local ctx = mock_context()
  ctx.is_enabled = function() return false end

  eq( checkbox( shown_page( ctx ), "Enabled" ).checked, false )
end

-- Through ctx.set_enabled, which is core's: whether an extension is on is core's record, not
-- something this addon keeps a second copy of.
function ExtensionSwitchSpec:should_turn_the_extension_off_when_the_switch_is_clicked()
  local ctx = mock_context()
  local page = shown_page( ctx )

  checkbox( page, "Enabled" ).on_click( false )

  eq( ctx.state.set_to, false )
  eq( ctx.state.enabled, false )
end

os.exit( lu.LuaUnit.run() )
