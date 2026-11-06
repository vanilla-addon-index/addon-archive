package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

-- RollFor and this addon loaded the way the client loads them, then PLAYER_LOGIN.
--
-- The registration suite drives on_enable with a stub context; this one drives the real
-- thing all the way through on_ready, which is where SoftResCheck, the soft-res window,
-- the simulation subscriber, the minimap contribution and the slash commands get built. A
-- construction mistake in there does not show up anywhere else in this suite -- it shows
-- up at somebody's login.
--
-- It also pins the first thing installing this addon has to mean: its source wins and
-- core's built-in does not register.

require( "src/compat" )
local u = require( "RollForSoftRes/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )

u.mock_wow_api()
u.mock_libraries()
-- Loads all of RollFor and then this addon on top of it, which is the order the client
-- produces from `## Dependencies: RollFor`.
u.load_real_stuff()

u.player( "Psikutas" )

local rf = u.load_roll_for()
local SoftResSource = RollFor.SoftResSource

SourceSpec = {}

function SourceSpec:should_be_the_registered_source()
  eq( SoftResSource.get().id, "softres" )
end

-- The other half of owning the slot: core saw it taken and contributed none of its own
-- soft-res. If core had also built its store, both would be adding `matched_name` and the
-- second one would have been refused.
function SourceSpec:should_have_left_core_with_no_builtin_of_its_own()
  eq( rf.softres_db, nil )
  eq( rf.unfiltered_softres, nil )
  eq( rf.name_matcher, nil )
  eq( rf.softres_check, nil )
  eq( rf.softres_gui, nil )
end

DisabledEntriesSpec = {}

-- Where the list window's checkboxes are written down. Reached through the saved variables rather
-- than through a handle on the addon, because that is the fact worth pinning: these survive a
-- reload, and a reload is the only reason they are on disk at all.
local function switches()
  return RollForCharDb.extension_softres_disabled_entries
end

local one_switched_off = { [ 123 ] = { Psikutas = { true } } }

-- A list a human just pasted in is the raid's agreement now, so it arrives with every entry on.
function DisabledEntriesSpec:should_switch_everything_back_on_after_an_interactive_import()
  switches().entries = { [ 123 ] = { Psikutas = { true } } }

  rf.event_bus.notify( "softres_imported", { source = "softres", interactive = true } )

  eq( switches().entries, {} )
end

-- Login re-imports the string already on disk, which is not a new agreement. If this reset too,
-- no entry could ever stay switched off past a /reload.
function DisabledEntriesSpec:should_keep_them_through_the_login_re_import()
  switches().entries = { [ 123 ] = { Psikutas = { true } } }

  rf.event_bus.notify( "softres_imported", { source = "softres", interactive = false } )

  eq( switches().entries, one_switched_off )
end

function DisabledEntriesSpec:should_switch_everything_back_on_when_the_list_is_cleared()
  switches().entries = { [ 123 ] = { Psikutas = { true } } }

  rf.event_bus.notify( "softres_cleared", { source = "softres" } )

  eq( switches().entries, {} )
end

ChainSpec = {}

-- The backbone is this addon's now, and core contributes nothing on top of it: the whole
-- soft-res chain is the extension's.
function ChainSpec:should_own_the_whole_backbone()
  eq( rf.softres_chain.names(),
    { "matched_name", "awarded_loot", "present_players", "disabled_entries" } )
end

function ChainSpec:should_expose_the_unfiltered_tap_to_core()
  eq( rf.unfiltered_view ~= nil, true )
  eq( type( rf.unfiltered_view.get_items ), "function" )
end

-- Core's consumers read this and do not know or care who supplied it.
function ChainSpec:should_give_core_a_working_softres()
  eq( type( rf.softres.get ), "function" )
  eq( rf.softres.get_all_rollers(), {} )
end

SlashCommandSpec = {}

-- /sr is this addon's own; /src and /srs come from SoftResCheck.new and /sro from
-- NameManualMatcher.new, so all four existing is also proof those three got constructed.
function SlashCommandSpec:should_register_the_whole_softres_family()
  local commands = RollFor.api.SlashCmdList or {}

  eq( type( commands[ "SR" ] ), "function" )
  eq( type( commands[ "SRO" ] ), "function" )
  eq( type( commands[ "SRC" ] ), "function" )
  eq( type( commands[ "SRS" ] ), "function" )
end

MinimapSpec = {}

-- One: this addon's own. Core contributes nothing to the button, and the Black Temple budget
-- check is RollForBtSrLimitCheck's -- a separate addon, not loaded in this harness.
local function softres_contribution()
  for _, contribution in ipairs( rf.minimap_contributions ) do
    if contribution.hint then return contribution end
  end
end

---@param is_down boolean
local function shift( is_down )
  u.mock( "IsShiftKeyDown", function() return is_down end )
end

---@param is_down boolean
local function alt( is_down )
  u.mock( "IsAltKeyDown", function() return is_down end )
end

local import_frame_name = "RollForSoftResImportFrame"
local list_frame_name = "RollForSoftResListFrame"

---@param name string
---@return boolean
local function visible( name )
  local frame = _G[ name ]
  return frame and frame:IsVisible() and true or false
end

-- Both windows toggle, so each spec starts with neither open.
local function right_click()
  for _, name in ipairs( { import_frame_name, list_frame_name } ) do
    if _G[ name ] then _G[ name ]:Hide() end
  end

  rf.event_bus.notify( "minimap_icon_right_click" )
end

function MinimapSpec:should_contribute_to_the_minimap_button()
  eq( #rf.minimap_contributions, 1 )

  local contribution = softres_contribution()
  local hl = RollFor.colors.hl
  eq( contribution.hint, string.format( "%s to manage softres.\n%s or %s + %s to show soft-ressing players.",
    hl( "Right click" ), hl( "Shift" ), hl( "alt" ), hl( "right click" ) ) )
  eq( #contribution.commands, 4 )
end

function MinimapSpec:should_open_the_import_window_on_right_click()
  shift( false )
  alt( false )
  right_click()

  eq( visible( import_frame_name ), true )
  eq( visible( list_frame_name ), false )
end

function MinimapSpec:should_open_the_list_on_shift_right_click()
  shift( true )
  alt( false )
  right_click()

  eq( visible( list_frame_name ), true )
  eq( visible( import_frame_name ), false )
end

function MinimapSpec:should_open_the_list_on_alt_right_click()
  shift( false )
  alt( true )
  right_click()

  eq( visible( list_frame_name ), true )
  eq( visible( import_frame_name ), false )
end

-- Importing happens before the raid forms, so the right click must not depend on who is
-- master looter, or on being in a group at all.
function MinimapSpec:should_open_the_import_window_on_right_click_outside_a_group()
  u.mock( "IsInGroup", false )
  shift( false )
  alt( false )
  right_click()

  eq( visible( import_frame_name ), true )
  eq( visible( list_frame_name ), false )
end

-- Nothing imported, so the button has nothing to complain about.
function MinimapSpec:should_report_a_white_icon_with_no_data()
  -- assert rather than a bare call: status() is nilable by contract, and a nil here should
  -- fail as a nil status rather than as an index error two lines down.
  local status = assert( softres_contribution().status() )

  eq( status.color, RollFor.MinimapButton.ColorType.White )
end

-- Import is the second thing you want from this button, so it takes the second one.
function MinimapSpec:should_claim_the_minimap_right_click()
  eq( rf.event_bus.has_subscribers( "minimap_icon_right_click" ), true )
end

-- Deliberately not claimed: core's "nobody took it" fallback then fires and the left click
-- opens the options window, which is what every other addon's minimap button does and what
-- a user who has never heard of soft-res expects.
function MinimapSpec:should_leave_the_left_click_to_cores_options_fallback()
  local opened = {}
  local open = rf.interface_options.open
  rf.interface_options.open = function() table.insert( opened, true ) end

  rf.event_bus.notify( "minimap_icon_left_click" )
  rf.interface_options.open = open

  eq( opened, { true } )
end

SimulationSpec = {}

-- /rfsetup's emission is still core's; answering it is the source's job, and with this
-- addon installed there is someone to answer.
function SimulationSpec:should_subscribe_to_simulation_started()
  eq( rf.event_bus.has_subscribers( "simulation_started" ), true )
end

os.exit( lu.LuaUnit.run() )
