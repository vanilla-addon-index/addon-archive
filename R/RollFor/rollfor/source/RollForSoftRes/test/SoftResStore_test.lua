package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

local lu = require( "test/common/luaunit" )
local test_utils = require( "RollForSoftRes/test/utils" )
test_utils.mock_wow_api()
require( "src/modules" )
require( "src/Types" )
-- Core's SoftRes is still loaded because the store asks it for softres_item_data. The
-- transformer is this addon's -- core has none any more.
require( "src/SoftRes" )
require( "SoftResDataTransformer" )
local mod = require( "SoftResStore" )

local sr = test_utils.soft_res_item
local data = test_utils.create_softres_data
local sid = test_utils.softres_item_data

StoreIntegrationSpec = {}

-- Two stores share no state. Dead until now: it was named `new_instances_should_...`, which
-- the suite's `-m should` filter never matched, and it asserted nil where `get` has always
-- answered an empty list -- so it would have failed the moment it ran.
function StoreIntegrationSpec:should_give_each_new_store_its_own_empty_list()
  -- Given
  local soft_res = mod.new( {} )
  local soft_res2 = mod.new( {} )

  -- Expect
  lu.assertEquals( soft_res.get( sid( 123 ) ), {} )
  lu.assertEquals( soft_res2.get( sid( 123 ) ), {} )
end

function StoreIntegrationSpec:should_create_a_proper_object_and_add_an_item()
  -- Given
  local soft_res = mod.new( {} )
  soft_res.import( data( sr( "Psikutas", 123 ) ) )
  local soft_res2 = mod.new( {} )

  -- When
  local result = soft_res.get( sid( 123 ) )
  local result2 = soft_res2.get( sid( 123 ) )

  -- Then
  lu.assertEquals( result, {
    { name = "Psikutas", rolls = 1, type = "Roller" }
  } )
  lu.assertEquals( result2, {} )
end

function StoreIntegrationSpec:should_return_no_rollers_for_an_untracked_item()
  -- Given
  local soft_res = mod.new( {} )
  soft_res.import( data( sr( "Psikutas", 123 ) ) )

  -- When
  local result = soft_res.get( sid( "111" ) )

  -- Then
  lu.assertEquals( result, {} )
end

function StoreIntegrationSpec:should_add_multiple_players()
  -- Given
  local soft_res = mod.new( {} )
  soft_res.import( data( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) ) )

  -- When
  local result = soft_res.get( sid( 123 ) )

  -- Then
  lu.assertEquals( result, {
    { name = "Obszczymucha", rolls = 1, type = "Roller" },
    { name = "Psikutas",     rolls = 1, type = "Roller" }
  } )
end

function StoreIntegrationSpec:should_accumulate_rolls()
  -- Given
  local soft_res = mod.new( {} )
  soft_res.import( data( sr( "Psikutas", 123 ), sr( "Psikutas", 123 ) ) )

  -- When
  local result = soft_res.get( sid( 123 ) )

  -- Then
  lu.assertEquals( result, {
    { name = "Psikutas", rolls = 2, type = "Roller" }
  } )
end

function StoreIntegrationSpec:should_check_if_player_is_soft_ressing()
  -- When
  local soft_res = mod.new( {} )
  soft_res.import( data( sr( "Psikutas", 123 ), sr( "Obszczymucha", 111 ) ) )

  -- Expect
  lu.assertEquals( soft_res.is_player_softressing( "Psiktuas", sid( 123 ) ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Psikutas", sid( 123 ) ), true )
  lu.assertEquals( soft_res.is_player_softressing( "Psikutas", sid( 333 ) ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Psikutas", sid( 111 ) ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Obszczymucha", sid( 111 ) ), true )
  lu.assertEquals( soft_res.is_player_softressing( "Obszczymucha", sid( 123 ) ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Obszczymucha", sid( 124 ) ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Ponpon", sid( 123 ) ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Ponpon", sid( 111 ) ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Ponpon", sid( 333 ) ), false )
end

os.exit( lu.LuaUnit.run() )
