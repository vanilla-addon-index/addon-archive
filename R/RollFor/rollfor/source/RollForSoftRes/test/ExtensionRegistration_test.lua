package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

-- What this addon is, from RollFor's side: a source registration, three backbone links and
-- a tap. The other suites prove the soft-res rules are right; this one proves they get
-- installed in the right place, which is the part that has nothing to do with softres.it
-- and everything to do with the extension API holding up.

require( "src/compat" )
local u = require( "RollForSoftRes/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/Ordering" )
local Chain = require( "src/Chain" )
local Extensions = require( "src/Extensions" )
local Db = require( "src/Db" )

u.mock_wow_api()
u.load_extension()

local softres = RollForSoftRes.main

-- A context with just enough on it for on_enable. What is under test is what the addon
-- puts into the chain and the source registry, so everything else is a stub.
-- Deliberately partial: on_enable touches nine of the context's twenty-seven fields and
-- on_ready nine, so the rest have no stub worth writing -- and a no-op one would turn "you
-- forgot to give the context a group_roster" from a crash into a silent nil. The waiver at
-- the literal is because `@as` fixes the expression's type and missing-fields checks the
-- literal.
---@return ExtensionContext
---@return table -- the source spec the addon registered, once on_enable has run
local function context( softres_chain, awarded_loot_chain )
  local db = Db.new( {} )
  local registered = { gui_elements = {} }

  ---@diagnostic disable-next-line: missing-fields
  return {
    db = function( key ) return db( string.format( "extension_softres_%s", key ) ) end,
    api = function() return RollFor.api end,
    group_roster = u.mock_group_roster and u.mock_group_roster() or
        require( "src/GroupRoster" ).new(
          require( "test/common/mocks/GroupRosterApi" ).new( {} ),
          require( "test/common/mocks/PlayerInfo" ).new( "Psikutas", "Warrior", true, true ) ),
    softres_chain = softres_chain,
    awarded_loot_chain = awarded_loot_chain,
    softres_source = { register = function( spec ) registered.spec = spec; return true end,
      get_import_string = function() return nil end },
    minimap = { register = function() end, refresh = function() end },
    gui_elements = registered.gui_elements,
    config = { register_number = function() end },
    on_group_changed = function() end,
    get = function() end
  } --[[@as ExtensionContext]], registered
end

---@return Chain
---@return table
local function enable_into( softres_chain, awarded_loot_chain )
  local ctx, registered = context( softres_chain, awarded_loot_chain or Chain.new( "awarded_loot" ) )
  softres.on_enable( ctx )

  return softres_chain, registered
end

RegistrationSpec = {}

function RegistrationSpec:should_have_registered_itself_on_load()
  local found

  for _, extension in ipairs( Extensions.all() ) do
    if extension.name == "softres" then found = extension end
  end

  if not found then lu.fail( "The addon did not register itself with RollFor." ) end

  -- `name` is the contract -- it is the db key, what core looks us up by, and what scopes
  -- this addon's saved variables, so it must not drift. The title is display text for the
  -- settings tree and can be reworded freely, so this only insists there is one.
  eq( type( found.title ), "string" )
  eq( found.title ~= "", true )
  eq( found.incompatible, nil )
end

-- The context this addon uses -- softres_source, softres_tap, minimap -- arrived in v2, and
-- roll_modifier.preview, which the list window reads, in v7. Declaring less would be a lie that
-- core would believe.
function RegistrationSpec:should_declare_the_api_version_it_actually_needs()
  local found

  for _, extension in ipairs( Extensions.all() ) do
    if extension.name == "softres" then found = extension end
  end

  eq( found.api_version, 7 )
  eq( found.api_version <= Extensions.API_VERSION, true )
end

function RegistrationSpec:should_be_on_by_default()
  eq( Extensions.is_enabled( "softres" ), true )
end

-- A disabled extension does not get on_enable, so a page declared from there would never
-- exist -- and that page is where the checkbox to turn it back on lives.
function RegistrationSpec:should_declare_its_options_page_on_the_spec()
  local found

  for _, extension in ipairs( Extensions.all() ) do
    if extension.name == "softres" then found = extension end
  end

  eq( type( found.options_page ), "function" )
end

-- FrameBuilder resolves a line by looking its type up in the gui_elements table, so a window
-- naming a type nobody registered gets nil and crashes the first time it draws.
function RegistrationSpec:should_register_the_list_windows_widgets_on_enable()
  local _, registered = enable_into( Chain.new( "softres" ) )
  local Transformer = RollForSoftRes.SoftResListContentTransformer

  eq( type( registered.gui_elements[ Transformer.header_type ] ), "function" )
  eq( type( registered.gui_elements[ Transformer.row_type ] ), "function" )
end

SourceRegistrationSpec = {}

function SourceRegistrationSpec:should_register_itself_as_the_softres_source()
  local _, registered = enable_into( Chain.new( "softres" ) )

  eq( registered.spec.id, "softres" )
  eq( type( registered.spec.base ), "function" )
  eq( type( registered.spec.has_data ), "function" )
  eq( type( registered.spec.get_import_string ), "function" )
end

-- has_data is what /rfsetup consults before refusing to run over real data. A fresh store
-- with no saved string is the one case where the simulator is allowed to take over.
function SourceRegistrationSpec:should_report_no_data_when_nothing_is_imported()
  local _, registered = enable_into( Chain.new( "softres" ) )

  eq( registered.spec.has_data(), false )
end

ChainPlacementSpec = {}

-- The backbone, in order. These are the names RollForNetherVortex anchors to, so this
-- order is a published contract and not an implementation detail.
function ChainPlacementSpec:should_contribute_the_backbone_in_order()
  local chain = enable_into( Chain.new( "softres" ) )

  eq( chain.names(), { "matched_name", "awarded_loot", "present_players", "disabled_entries" } )
end

function ChainPlacementSpec:should_wrap_the_awarded_loot_record_from_inside_the_factory()
  -- The addon adds nothing to the awarded-loot chain: it reads the decorated record
  -- through ctx.get from inside its own factory instead, which is what lets another
  -- extension decorate that record first.
  local awarded_loot_chain = Chain.new( "awarded_loot" )
  enable_into( Chain.new( "softres" ), awarded_loot_chain )

  eq( awarded_loot_chain.names(), {} )
end

-- The unfiltered tap means "everything except the group filter". SoftResCheck and the roll
-- simulator are built on it, so it has to resolve to the value before present_players.
function ChainPlacementSpec:should_declare_the_unfiltered_tap_before_present_players()
  local chain = enable_into( Chain.new( "softres" ) )

  -- Built on a real store, because the decorators are real: they clone what they wrap.
  local built = chain.build( RollForSoftRes.SoftResStore.new( Db.new( {} )( "softres" ) ) )
  eq( built.has_tap( "unfiltered" ), true )

  -- The tap is the value before the group filter, so it still answers with the store's
  -- six read methods rather than with the filtered view on top.
  eq( type( built.tap( "unfiltered" ).get_items ), "function" )

  local position = {}
  for index, name in ipairs( chain.names() ) do position[ name ] = index end

  eq( position.matched_name < position.awarded_loot, true )
  eq( position.awarded_loot < position.present_players, true )

  -- The list window's checkboxes come after the tap, not before it: the window draws a box for
  -- every entry, including the ones it has switched off, and reads the tap to find them.
  eq( position.present_players < position.disabled_entries, true )
end

-- Addons load alphabetically, so RollForNetherVortex declares its anchors before this
-- addon contributes them. That works only because Chain resolves anchors at build time --
-- if it ever went back to resolving at add time, Nether Vortex would be silently dropped.
function ChainPlacementSpec:should_accept_a_link_anchored_to_the_backbone_before_it_arrives()
  local chain = Chain.new( "softres" )

  chain.add( {
    name = "early_bird",
    after = "awarded_loot",
    before = "present_players",
    factory = function( inner ) return inner end
  } )

  enable_into( chain )

  eq( chain.names(), { "matched_name", "awarded_loot", "early_bird", "present_players", "disabled_entries" } )
end

os.exit( lu.LuaUnit.run() )
