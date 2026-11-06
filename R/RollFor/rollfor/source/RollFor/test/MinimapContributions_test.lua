---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../src/?.lua;../../?.lua;../src/libs/?.lua"

require( "src/compat" )
local u = require( "RollFor/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.mock_libraries()
u.load_real_stuff_and_inject( {}, {} )
local EventBus = require( "src/EventBus" )
local MinimapButton = require( "src/MinimapButton" )

local function api() return RollFor.api end

---@param show_commands boolean? -- defaults to true, so the ordering specs below can keep
--- asserting where a contribution's commands land among core's
local function mock_config( show_commands )
  return {
    minimap_button_locked = function() return false end,
    minimap_button_hidden = function() return false end,
    minimap_tooltip_commands = function() return show_commands ~= false end,
    subscribe = function() end
  }
end

-- A GameTooltip stand-in that just records everything written to it, in order.
local function make_tooltip()
  local tooltip = { lines = {} }
  tooltip.SetOwner = function( ... ) end
  tooltip.SetText = function( self, text, _, _, _, _, _ ) table.insert( self.lines, text ) end
  tooltip.AddLine = function( self, text, _, _, _, _ ) table.insert( self.lines, text ) end
  tooltip.Show = function( ... ) end
  tooltip.Hide = function( ... ) end
  return tooltip
end

---@param lines string[]
---@param needle string
---@return number?
local function index_of_line( lines, needle )
  for i, line in ipairs( lines ) do
    if string.find( line, needle, 1, true ) then return i end
  end
end

local options_line = string.format( "%s to open options.", RollFor.colors.hl( "Left click" ) )

---@param contributions MinimapContribution[]
---@param show_commands boolean?
---@param left_click_taken boolean? -- an extension claimed the left click, so main.lua never
--- tells the button it opens options
---@return string[] -- the tooltip's lines after OnEnter ran
local function render_tooltip( contributions, show_commands, left_click_taken )
  local button = MinimapButton.new( api, {}, mock_config( show_commands ), EventBus.new(), contributions )
  if not left_click_taken then button.open_options_on_left_click() end

  local frame = _G[ "RollForMinimapButton" ]
  local tooltip = make_tooltip()
  _G[ "GameTooltip" ] = tooltip

  frame.OnEnter( frame )

  return tooltip.lines
end

TooltipOrderingSpec = {}

function TooltipOrderingSpec:should_list_a_contributions_commands_after_cores_own()
  local lines = render_tooltip( { {
    commands = { { cmd = "/sr", description = "manage softres" } }
  } } )

  local core_line = index_of_line( lines, "/htr" )
  local contributed_line = index_of_line( lines, "/sr" )

  eq( core_line ~= nil, true )
  eq( contributed_line ~= nil, true )
  eq( contributed_line > core_line, true )
end

function TooltipOrderingSpec:should_list_commands_from_two_contributions_in_registration_order()
  local lines = render_tooltip( {
    { commands = { { cmd = "/first", description = "one" } } },
    { commands = { { cmd = "/second", description = "two" } } }
  } )

  local first = index_of_line( lines, "/first" )
  local second = index_of_line( lines, "/second" )

  eq( first ~= nil and second ~= nil, true )
  eq( first < second, true )
end

function TooltipOrderingSpec:should_use_the_first_contributions_hint()
  local lines = render_tooltip( {
    { hint = "Click to foo." },
    { hint = "Click to bar." }
  } )

  eq( index_of_line( lines, "Click to foo." ) ~= nil, true )
  eq( index_of_line( lines, "Click to bar." ), nil )
end

function TooltipOrderingSpec:should_say_left_click_opens_options_when_no_contribution_supplies_a_hint()
  local lines = render_tooltip( { { commands = { { cmd = "/foo", description = "foo" } } } } )

  eq( index_of_line( lines, options_line ) ~= nil, true )
end

function TooltipOrderingSpec:should_say_left_click_opens_options_with_no_contributions_at_all()
  local lines = render_tooltip( {} )

  eq( index_of_line( lines, options_line ) ~= nil, true )
end

-- A contribution's hint is about the other button, so the left click's line is not replaced by
-- it -- the two sit together, core's first.
function TooltipOrderingSpec:should_put_the_options_line_right_before_a_contributions_hint()
  local lines = render_tooltip( { { hint = "Right click to foo." } } )

  local options = index_of_line( lines, options_line )
  local hint = index_of_line( lines, "Right click to foo." )

  eq( options ~= nil and hint ~= nil, true )
  eq( hint, options + 1 )
end

-- main.lua installs core's fallback only when nothing else claimed the left click. If
-- something did, the click doesn't open options, and the tooltip must not say it does.
function TooltipOrderingSpec:should_not_mention_options_when_an_extension_took_the_left_click()
  local lines = render_tooltip( { { hint = "Left click to foo." } }, nil, true )

  eq( index_of_line( lines, "to open options." ), nil )
  eq( index_of_line( lines, "Left click to foo." ) ~= nil, true )
end

function TooltipOrderingSpec:should_append_each_contributions_status_lines_after_the_hint()
  local lines = render_tooltip( { {
    status = function() return { color = "Orange", lines = { "Missing softres:", "Drutree" } } end
  } } )

  local hint_line = index_of_line( lines, options_line )
  local status_line = index_of_line( lines, "Missing softres:" )
  local name_line = index_of_line( lines, "Drutree" )

  eq( hint_line ~= nil and status_line ~= nil and name_line ~= nil, true )
  eq( status_line > hint_line, true )
  eq( name_line, status_line + 1 )
end

function TooltipOrderingSpec:should_omit_a_status_block_when_status_has_no_lines()
  local lines = render_tooltip( { {
    status = function() return { color = "Green" } end
  } } )

  eq( index_of_line( lines, "Missing" ), nil )
end

-- The single most likely mistake in this area: a button built before extensions register
-- (main.lua builds it in create_components(); extensions register in on_ready, which runs
-- later) must still show what gets registered after it exists, because contributions are
-- read at render time rather than snapshotted at construction.
RenderTimeSpec = {}

function RenderTimeSpec:should_show_a_contribution_registered_after_the_button_was_built()
  local contributions = {}
  MinimapButton.new( api, {}, mock_config(), EventBus.new(), contributions )

  -- Registered well after construction, simulating an extension's on_ready.
  table.insert( contributions, { commands = { { cmd = "/late", description = "arrived late" } } } )

  local frame = _G[ "RollForMinimapButton" ]
  local tooltip = make_tooltip()
  _G[ "GameTooltip" ] = tooltip
  frame.OnEnter( frame )

  eq( index_of_line( tooltip.lines, "/late" ) ~= nil, true )
end

-- Colour severity resolution lives in main.lua's refresh_minimap(), which recomputes from
-- the live RollFor.minimap_contributions list -- so this goes through the full addon
-- rather than MinimapButton in isolation.
ColourSeveritySpec = {}

function ColourSeveritySpec:should_pick_the_highest_severity_colour_across_contributions()
  u.player( "Psikutas" )
  local rf = u.load_roll_for()

  table.insert( rf.minimap_contributions, { status = function() return { color = rf.minimap_button.ColorType.Orange } end } )
  table.insert( rf.minimap_contributions, { status = function() return { color = rf.minimap_button.ColorType.Green } end } )

  rf.on_group_changed()

  eq( rf.minimap_button.get_icon_color(), rf.minimap_button.ColorType.Orange )
end

function ColourSeveritySpec:should_stay_white_when_nothing_reports_a_colour()
  u.player( "Psikutas" )
  local rf = u.load_roll_for()

  table.insert( rf.minimap_contributions, { hint = "no status at all" } )

  rf.on_group_changed()

  eq( rf.minimap_button.get_icon_color(), rf.minimap_button.ColorType.White )
end

function ColourSeveritySpec:should_reflect_a_contribution_registered_after_login()
  u.player( "Psikutas" )
  local rf = u.load_roll_for()

  -- Nothing loud yet.
  rf.on_group_changed()
  eq( rf.minimap_button.get_icon_color(), rf.minimap_button.ColorType.White )

  table.insert( rf.minimap_contributions, { status = function() return { color = rf.minimap_button.ColorType.Red } end } )
  rf.on_group_changed()

  eq( rf.minimap_button.get_icon_color(), rf.minimap_button.ColorType.Red )
end

-- The real addon, logged in with no source installed: nothing claimed the left click, so
-- main.lua's fallback is what answers it, and the tooltip has to have been told.
RealAddonTooltipSpec = {}

function RealAddonTooltipSpec:should_say_left_click_opens_options_after_a_real_login()
  u.player( "Psikutas" )
  u.load_roll_for()

  local frame = _G[ "RollForMinimapButton" ]
  local tooltip = make_tooltip()
  _G[ "GameTooltip" ] = tooltip
  RollFor.api.GameTooltip = tooltip
  frame.OnEnter( frame )

  eq( index_of_line( tooltip.lines, options_line ) ~= nil, true )
end

TitleSpec = {}

-- Which RollFor this is, on the line naming it. The first thing anyone is asked when they
-- report something is what version they are on, and a hover is cheaper to ask for than a
-- slash command.
function TitleSpec:should_name_the_addon_and_its_version()
  local lines = render_tooltip( {} )

  eq( lines[ 1 ], string.format( "%s %s",
    RollFor.colors.blue( "RollFor" ), RollFor.colors.grey( "v2.6" ) ) )
end

-- The commands setting hides commands, and the title is not one of them.
function TitleSpec:should_keep_the_version_with_the_commands_hidden()
  eq( render_tooltip( {}, false )[ 1 ], render_tooltip( {}, true )[ 1 ] )
end

CommandVisibilitySpec = {}

-- Off by default, and this is what off looks like: no core commands, no contributed ones,
-- and the hint still there. The hint is what the tooltip must never stop saying.
function CommandVisibilitySpec:should_draw_no_commands_when_the_setting_is_off()
  local lines = render_tooltip( { {
    commands = { { cmd = "/sr", description = "manage softres" } },
    hint = "Right click to manage softres."
  } }, false )

  eq( index_of_line( lines, "/htr" ), nil )
  eq( index_of_line( lines, "/rf config" ), nil )
  eq( index_of_line( lines, "/sr" ), nil )
  eq( index_of_line( lines, "Right click to manage softres." ) ~= nil, true )
end

function CommandVisibilitySpec:should_draw_them_when_the_setting_is_on()
  local lines = render_tooltip( { {
    commands = { { cmd = "/sr", description = "manage softres" } },
    hint = "Right click to manage softres."
  } }, true )

  eq( index_of_line( lines, "/htr" ) ~= nil, true )
  eq( index_of_line( lines, "/sr" ) ~= nil, true )
end

-- The title is not a command, so it stays either way -- an empty tooltip would read as a
-- broken button rather than as a setting being off.
function CommandVisibilitySpec:should_keep_the_title_with_the_commands_hidden()
  local lines = render_tooltip( {}, false )

  eq( index_of_line( lines, "RollFor" ) ~= nil, true )
end

-- Status lines are what a contribution has to *report* rather than what a user can type,
-- so they are not commands and the setting does not touch them.
function CommandVisibilitySpec:should_still_report_status_lines_with_the_commands_hidden()
  local lines = render_tooltip( { {
    status = function() return { color = "Red", lines = { "Found outdated softres data." } } end
  } }, false )

  eq( index_of_line( lines, "Found outdated softres data." ) ~= nil, true )
end

os.exit( lu.LuaUnit.run() )
