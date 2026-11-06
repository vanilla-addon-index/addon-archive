package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

-- /src says when it has run its checks.
--
-- This addon owns the command and the data; what else is worth checking about a soft-res
-- list is not a question it should be answering. RollForBtSrLimitCheck's Black Temple budget
-- check subscribes to this and prints its own lines after ours, so neither addon reaches into
-- the other -- which is the whole reason the event exists rather than a direct call.

require( "src/compat" )
local u = require( "RollForSoftRes/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )

u.mock_wow_api()
u.mock_slashcmdlist()
require( "src/modules" )
require( "src/Types" )
require( "src/SoftRes" )
require( "src/EventBus" )
require( "SoftResDataTransformer" )
require( "NameMatchReport" )
local SoftResStore = require( "SoftResStore" )
local SoftResCheck = require( "SoftResCheck" )

---@param provider_id string? -- as if the list had been imported through that provider
---@return table -- the events seen on the bus
local function run_src( provider_id )
  u.mock_slashcmdlist() -- drop the previous case's /src so this one registers its own
  local seen = {}
  local event_bus = RollFor.EventBus.new()
  event_bus.subscribe( "softres_checked", function( event ) table.insert( seen, event ) end )

  local store = SoftResStore.new( {} )
  if provider_id then store.persist( "an import string", provider_id ) end

  SoftResCheck.new(
    store,
    { get_all_players_in_my_group = function() return {} end, find_player = function() return nil end },
    { get_all_matches = function() return {} end, get_matches = function() return {}, {}, {} end },
    { ScheduleTimer = function() end },
    function( softres ) return softres end,
    store,
    event_bus )

  u.run_command( "SRC", "" )

  return seen
end

SoftResCheckedEventSpec = {}

function SoftResCheckedEventSpec:should_say_when_src_has_run()
  eq( #run_src(), 1 )
end

-- Where the list being checked came from. There is one soft-res addon now and several
-- providers, so naming this addon would say nothing -- the provider is the fact a listener
-- can act on.
function SoftResCheckedEventSpec:should_name_the_provider_the_list_was_imported_with()
  eq( run_src( "raidres" )[ 1 ].source, "raidres" )
end

-- Nothing imported, so there is no provider to name. Left absent rather than filled in with
-- this addon's own name, which would be a claim about data that does not exist.
function SoftResCheckedEventSpec:should_name_no_source_with_nothing_imported()
  eq( run_src()[ 1 ].source, nil )
end

os.exit( lu.LuaUnit.run() )
