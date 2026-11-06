package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

-- The outdated-data branch, which until now could not fire: SoftResCheck read
-- `import_timestamp` out of its own db table while SoftResStore wrote it into the store's,
-- so the read was always nil and the minimap icon never went red. It asks the store
-- directly now. This suite exists because a branch nobody can reach is a branch nobody
-- notices is broken.

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
local SoftResStore = require( "SoftResStore" )
local SoftResCheck = require( "SoftResCheck" )

local m = RollFor
local NOW = 1000000

-- The clock the store stamps imports with. One assignment site rather than three, so the
-- field is set once and moved rather than redefined.
local function clock_at( t )
  m.lua.time = function() return t end
end

local function check_with( import_age_in_hours )
  clock_at( NOW )

  local store = SoftResStore.new( {} )

  if import_age_in_hours then
    clock_at( NOW - import_age_in_hours * 3600 )
    store.persist( "an-import-string" )
    clock_at( NOW )
  end

  return SoftResCheck.new(
    store, -- nothing is soft-ressed, so the view and the store can be the same empty thing
    { get_all_players_in_my_group = function() return {} end, find_player = function() return nil end },
    { get_all_matches = function() return {} end },
    { ScheduleTimer = function() end },
    function( softres ) return softres end,
    store,
    -- A real bus: this spec asserts nothing about the event, but a partial stub would have
    -- to keep up with EventBus's interface for no benefit.
    m.EventBus.new() )
end

SoftResCheckTimestampSpec = {}

function SoftResCheckTimestampSpec:should_report_outdated_data_for_an_old_import()
  local check = check_with( 7 )

  eq( check.check_softres( true ), check.ResultType.FoundOutdatedData )
end

function SoftResCheckTimestampSpec:should_not_report_outdated_data_for_a_recent_import()
  local check = check_with( 5 )

  eq( check.check_softres( true ), check.ResultType.NoItemsFound )
end

-- Nothing imported, nothing to be stale.
function SoftResCheckTimestampSpec:should_not_report_outdated_data_when_nothing_was_imported()
  local check = check_with( nil )

  eq( check.check_softres( true ), check.ResultType.NoItemsFound )
end

os.exit( lu.LuaUnit.run() )
