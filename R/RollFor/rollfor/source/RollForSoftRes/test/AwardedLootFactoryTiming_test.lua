package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

-- The awarded-loot ordering hazard, which is the one mistake in this addon that fails silently.
--
-- The `awarded_loot` soft-res link filters out a player who has already been given the
-- item. To do that it needs the *decorated* awarded-loot record, which core builds from
-- its own chain -- after Extensions.enable has run, and before it builds the soft-res
-- chain. So the addon must ask for it with ctx.get from *inside* the factory body, where
-- it exists, and not in on_enable, where it does not.
--
-- Get it wrong and the decorator is constructed on nil. It does not throw at login: it
-- throws the first time somebody wins an item, deep inside a roll, and until then the
-- addon looks fine. That is why this test exists.

require( "src/compat" )
local u = require( "RollForSoftRes/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/Ordering" )
local Chain = require( "src/Chain" )
local Db = require( "src/Db" )

u.mock_wow_api()
u.load_extension()

local m = RollFor
local sr = RollForSoftRes
local softres = sr.main
local alid = m.AwardedLoot.awarded_loot_item_data

local ITEM_ID = 30183

---@param on_get fun( name: string ): any
-- Deliberately partial: on_enable touches eight of the context's twenty-seven fields and
-- on_ready nine, so the rest have no stub worth writing -- and a no-op one would turn "you
-- forgot to give the context a group_roster" from a crash into a silent nil. The waiver at
-- the literal is because `@as` fixes the expression's type and missing-fields checks the
-- literal.
---@return ExtensionContext
local function context( softres_chain, awarded_loot_chain, on_get )
  local db = Db.new( {} )

  ---@diagnostic disable-next-line: missing-fields
  return {
    db = function( key ) return db( string.format( "extension_softres_%s", key ) ) end,
    api = function() return m.api end,
    -- Empty on purpose: every assertion below reads through the unfiltered tap, which is
    -- the view *before* the group filter, so who is in the group is not what is under test.
    group_roster = require( "src/GroupRoster" ).new(
      require( "test/common/mocks/GroupRosterApi" ).new( {} ),
      require( "test/common/mocks/PlayerInfo" ).new( "Psikutas", "Warrior", true, true ) ),
    softres_chain = softres_chain,
    awarded_loot_chain = awarded_loot_chain,
    softres_source = { register = function() return true end, get_import_string = function() return nil end },
    minimap = { register = function() end, refresh = function() end },
    gui_elements = {},
    config = { register_number = function() end },
    on_group_changed = function() end,
    get = on_get
  } --[[@as ExtensionContext]]
end

FactoryTimingSpec = {}

-- The whole point, stated as an assertion: nothing asks for the awarded-loot record while
-- on_enable is running. If the addon ever hoists that ctx.get out of the factory, this is
-- what notices.
function FactoryTimingSpec:should_not_ask_for_the_awarded_loot_record_during_on_enable()
  local asked_during_enable = false
  local enabling = true

  local softres_chain = Chain.new( "softres" )
  softres.on_enable( context( softres_chain, Chain.new( "awarded_loot" ), function( name )
    if enabling and name == "awarded_loot" then asked_during_enable = true end
  end ) )

  enabling = false

  eq( asked_during_enable, false )
end

-- ...and it does ask at build time, when the answer exists. A link that never asks at all
-- would pass the spec above for the wrong reason.
function FactoryTimingSpec:should_ask_for_the_awarded_loot_record_at_build_time()
  local asked_at_build = false
  local building = false

  local softres_chain = Chain.new( "softres" )
  local awarded_loot_chain = Chain.new( "awarded_loot" )
  local decorated

  softres.on_enable( context( softres_chain, awarded_loot_chain, function( name )
    if name ~= "awarded_loot" then return end
    if building then asked_at_build = true end

    return decorated
  end ) )

  decorated = awarded_loot_chain.build(
    m.AwardedLoot.new( Db.new( {} )( "awarded_loot" ), require( "mocks/ChatApi" ).new() ) ).final

  building = true
  softres_chain.build( sr.SoftResStore.new( Db.new( {} )( "softres" ) ) )

  eq( asked_at_build, true )
end

-- The behaviour the timing exists for. A player who already won the item is dropped from
-- the soft-res list, so the next roll for it does not offer them again.
function FactoryTimingSpec:should_filter_out_a_player_who_already_won_the_item()
  local softres_chain = Chain.new( "softres" )
  local awarded_loot_chain = Chain.new( "awarded_loot" )
  local decorated

  softres.on_enable( context( softres_chain, awarded_loot_chain, function( name )
    if name == "awarded_loot" then return decorated end
  end ) )

  local awarded_loot = m.AwardedLoot.new( Db.new( {} )( "awarded_loot" ), require( "mocks/ChatApi" ).new() )
  decorated = awarded_loot_chain.build( awarded_loot ).final

  local store = sr.SoftResStore.new( Db.new( {} )( "softres" ) )
  store.import( u.create_softres_data(
    u.soft_res_item( "Psikutas", ITEM_ID ),
    u.soft_res_item( "Obszczymucha", ITEM_ID ) ) )

  local built = softres_chain.build( store )

  -- Read through the unfiltered tap, so the group filter is not what is being measured.
  local unfiltered = built.tap( "unfiltered" )

  local before = {}
  for _, roller in ipairs( unfiltered.get( m.SoftRes.softres_item_data( ITEM_ID ) ) ) do
    table.insert( before, roller.name )
  end
  table.sort( before )
  eq( before, { "Obszczymucha", "Psikutas" } )

  decorated.award( "Psikutas", alid( ITEM_ID ) )

  local after = {}
  for _, roller in ipairs( unfiltered.get( m.SoftRes.softres_item_data( ITEM_ID ) ) ) do
    table.insert( after, roller.name )
  end
  eq( after, { "Obszczymucha" } )
end

os.exit( lu.LuaUnit.run() )
