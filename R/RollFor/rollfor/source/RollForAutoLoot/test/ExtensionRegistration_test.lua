package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua"

-- What this addon is, from RollFor's side: a registration, one loot handler, a dropped-item
-- predicate, four settings, an options page and the /rf subcommand that opens it. AutoLootSpec
-- proves the pass takes the right items; this one proves it gets installed in the right place,
-- which is the part that has nothing to do with auto-loot and everything to do with the
-- extension API holding up.
---@diagnostic disable: missing-fields, inject-field

require( "src/compat" )
local u = require( "RollForAutoLoot/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/Ordering" )
local Extensions = require( "src/Extensions" )
-- on_ready seeds the db from core's catalogue.
require( "src/ItemUtils" )
require( "src/DropTable" )

u.mock_wow_api()
u.load_extension()

local auto_loot = RollForAutoLoot.main

local function enable_into()
  local registered = { toggles = {}, predicates = {}, policies = {} }

  auto_loot.on_enable( {
    config = {
      register_toggle = function( key, row, default )
        registered.toggles[ key ] = { default = default, cmd = row.cmd, display = row.display }
      end,
      auto_loot_announce = function() return true end
    },
    award_policy = function( spec ) table.insert( registered.policies, spec ) end,
    on_dropped_item = function( predicate ) table.insert( registered.predicates, predicate ) end
  } )

  return registered
end

-- Everything on_ready reaches for. It builds the real sweep, so the stubs have to be real enough
-- to be built against -- but what is asserted is only what it registered.
---@param registered table
local function ready_context( registered )
  local Db = require( "src/Db" )
  local db = Db.new( {} )

  return {
    db = function( key ) return db( key ) end,
    api = function() return RollFor.api end,
    config = { auto_loot = function() return true end },
    chat = require( "test/common/mocks/Chat" ).new( require( "mocks/ChatApi" ).new(), "RAID" ),
    player_info = require( "test/common/mocks/PlayerInfo" ).new( "Psikutas", "Warrior", true, true ),
    get = function( name )
      if name == "loot_list" then return { get_items_by_slot = function() return {} end } end
    end,
    on_rf_command = function( name, callback ) registered.rf_commands[ name ] = callback end,
    open_options = function() table.insert( registered.opened, registered.page_tab or "no page" ) end
  }
end

RegistrationSpec = {}

function RegistrationSpec:should_register_itself_with_rollfor()
  Extensions.clear()
  eq( auto_loot.register(), true )

  local all = Extensions.all()
  eq( #all, 1 )
  eq( all[ 1 ].name, "auto_loot" )
  eq( all[ 1 ].title, "Auto Loot" )
end

-- Core draws a bare Enabled-switch page for an extension that supplies none of its own, so
-- offering one is what puts the summary and these settings in the options window -- and its own
-- Enabled switch on it, since core stops injecting that once we take the page.
function RegistrationSpec:should_offer_its_own_options_page()
  Extensions.clear()
  auto_loot.register()

  eq( type( Extensions.all()[ 1 ].options_page ), "function" )
end

-- The selection tree arrived on ctx with API 5, award_policy with API 6, and open_options with
-- API 8.
function RegistrationSpec:should_declare_the_api_version_the_seams_it_uses_arrived_in()
  Extensions.clear()
  auto_loot.register()

  eq( Extensions.all()[ 1 ].incompatible, nil )
  eq( Extensions.all()[ 1 ].api_version, 8 )
end

-- "Auto-loot" is this addon's on/off switch, so core must not offer a second one above it. The
-- flag is also what keeps the extension enabled: with no switch anywhere, "off" would be a state
-- nothing could bring it back from.
function RegistrationSpec:should_ask_core_not_to_draw_an_enabled_switch()
  Extensions.clear()
  auto_loot.register()

  eq( Extensions.all()[ 1 ].hide_enabled_option, true )
  eq( Extensions.is_enabled( "auto_loot" ), true )
end

SettingsSpec = {}

-- Verbatim what core registered before this addon existed, so `/rf config auto-loot` and its
-- siblings answer exactly as they did. A renamed cmd is a user's macro broken silently.
function SettingsSpec:should_register_the_settings_core_used_to_own()
  local toggles = enable_into().toggles

  eq( toggles.auto_loot, { default = true, cmd = "auto-loot", display = "Auto-loot" } )
  eq( toggles.auto_loot_announce,
    { default = true, cmd = "auto-loot-announce", display = "Announce auto-looted items" } )
end

-- Off, and deliberately: core registered no default for this one, so it has been falsy for every
-- player since it was added. Moving it here is not the place to change that.
function SettingsSpec:should_keep_auto_loot_messages_off_by_default()
  eq( enable_into().toggles.auto_loot_messages.default, false )
end

AwardPolicySpec = {}

-- The sweep registers no loot handler at all now. Taking items is a policy: it says whose bags
-- a slot should go to and core performs the award, walks the slots, applies the master-looter
-- and shift-key guards once for everybody, and decides -- from the user's ordering -- which
-- claimant outranks which.
function AwardPolicySpec:should_register_itself_as_an_award_policy()
  local policies = enable_into().policies

  eq( table.getn( policies ), 1 )
  eq( policies[ 1 ].name, "auto_loot" )
  eq( type( policies[ 1 ].decide ), "function" )
  eq( type( policies[ 1 ].on_awarded ), "function" )
end

-- The title is what the user reads in core's priority list, so it says what the feature is
-- rather than repeating the id.
function AwardPolicySpec:should_give_the_priority_list_something_readable_to_show()
  eq( enable_into().policies[ 1 ].title, "Auto-loot" )
end

-- The sweep is built in on_ready and core asks at loot time, so arriving early is normal and a
-- policy that answers before there is a sweep must simply not want anything.
function AwardPolicySpec:should_have_no_opinion_before_the_sweep_is_built()
  local policy = enable_into().policies[ 1 ]
  local sweep = RollForAutoLoot.auto_loot
  RollForAutoLoot.auto_loot = nil

  eq( policy.decide( 1, { id = 123 } ), nil )

  RollForAutoLoot.auto_loot = sweep
end

DroppedItemSpec = {}

function DroppedItemSpec:should_register_exactly_one_predicate()
  eq( table.getn( enable_into().predicates ), 1 )
end

-- Nothing is built here, so the pass does not exist and the predicate has no opinion. What it
-- answers once it does is AutoLootSpec's business.
function DroppedItemSpec:should_have_no_opinion_before_the_pass_is_built()
  RollForAutoLoot.auto_loot = nil

  eq( enable_into().predicates[ 1 ]( { id = 123 } ), nil )
end

SlashCommandSpec = {}

-- A subcommand of core's /rf rather than a command of its own, so the list opens the way every
-- other RollFor window does.
function SlashCommandSpec:should_own_the_rf_autoloot_subcommand()
  local registered = { rf_commands = {}, opened = {} }

  auto_loot.on_ready( ready_context( registered ) )

  eq( type( registered.rf_commands[ "autoloot" ] ), "function" )
end

-- The list is on the Loot tab of this addon's options page now, not in a window of its own. The
-- tab is picked before the window opens, so the page is drawn on it.
function SlashCommandSpec:should_open_the_options_page_on_the_loot_tab()
  local registered = { rf_commands = {}, opened = {} }
  local page = RollForAutoLoot.options_page
  RollForAutoLoot.options_page = { select_tab = function( label ) registered.page_tab = label end }

  auto_loot.on_ready( ready_context( registered ) )
  registered.rf_commands[ "autoloot" ]( "" )

  RollForAutoLoot.options_page = page
  eq( registered.opened, { "Loot" } )
end

-- The page is core's to build, and a command typed before it exists still opens the window.
function SlashCommandSpec:should_still_open_the_options_without_a_page()
  local registered = { rf_commands = {}, opened = {} }
  local page = RollForAutoLoot.options_page
  RollForAutoLoot.options_page = nil

  auto_loot.on_ready( ready_context( registered ) )
  registered.rf_commands[ "autoloot" ]( "" )

  RollForAutoLoot.options_page = page
  eq( registered.opened, { "no page" } )
end

-- What core hands back when it asks for the page is kept, so the command can reach it.
function SlashCommandSpec:should_keep_the_page_it_built()
  Extensions.clear()
  auto_loot.register()

  local canvas = u.modules().api.CreateFrame( "Frame" )
  local page = Extensions.all()[ 1 ].options_page( {}, canvas ) --[[@as AutoLootOptionsPage]]

  eq( RollForAutoLoot.options_page, page )
  eq( type( page.select_tab ), "function" )
end

PublishedSurfaceSpec = {}

-- `claims` is gone, and this is the deliberate break API 6 is for. It was committed, and
-- RollForAutoRobin was the one addon reading it -- to decide whether an item was already spoken
-- for, because GiveMasterLoot is asynchronous and the loot list still shows a slot this addon
-- has taken. Core answers that now, about the slot that was actually taken rather than about
-- what a predicate would have wanted: ctx.loot_claim( slot ).
--
-- Pinned as an absence so that nobody quietly puts it back: a shim would keep the coupling
-- alive and answer the wrong question while doing it.
function PublishedSurfaceSpec:should_not_publish_claims_any_more()
  auto_loot.on_ready( ready_context( { rf_commands = {}, opened = {} } ) )

  eq( RollForAutoLoot.claims, nil )
end

os.exit( lu.LuaUnit.run() )
