-- The test harness lives in RollForSoftRes now -- one copy for the three addons instead of
-- three. It sits beside this addon, as it does in AddOns, where
-- `## Dependencies: RollForSoftRes` guarantees it is there.
package.path = "./?.lua;" .. package.path ..
    ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../../RollFor/src/libs/LibStub/?.lua" ..
    ";../../RollForSoftRes/src/?.lua;../../RollForSoftRes/test/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

require( "src/compat" )
local u = require( "RollForSoftRes/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.mock_wow_api()
require( "src/modules" )

-- Json-0.1.2 registers itself with LibStub on load, which is exactly how the client
-- provides it: RollFor's TOC ships src\Json.lua, so by the time this addon's Decoder runs
-- the library is already there to be asked for.
---@diagnostic disable-next-line: lowercase-global
strmatch = string.match
require( "LibStub" )
require( "src/Json" )

local mod = require( "Decoder" )

-- The wire format, asserted against the real thing. `fixtures/raidres.txt` is an export
-- taken from raidres.top; `fixtures/softres-it.zlib.base64` is an export taken from
-- softres.it. The point of the pair is that the second one is unreadable here -- this
-- addon does not decompress, so a softres.it string gets as far as base64 and no further.

local function fixture( name )
  local file = assert( io.open( string.format( "fixtures/%s", name ) ) )
  local contents = file:read( "*a" )
  file:close()

  return (string.gsub( contents, "%s", "" ))
end

-- `decode` answers nil for a string it cannot read, which is what the negative cases below
-- are about. A positive case asserts instead: a decode that failed here should say so, not
-- become an index error on the next line.
DecoderSpec = {}

function DecoderSpec:should_decode_a_raidres_export()
  -- When
  local result = assert( mod.decode( fixture( "raidres.txt" ) ) )

  -- Then
  eq( result.metadata.id, "GQZDMQ" )
  eq( result.metadata.origin, "raidres" )
  eq( result.metadata.instances, { "Black Temple" } )
  eq( result.softreserves[ 1 ].name, "Boulderdash" )

  local item_ids = {}
  for _, item in ipairs( result.softreserves[ 1 ].items ) do
    table.insert( item_ids, item.id )
  end

  eq( item_ids, { 32241, 32232, 32236 } )
  eq( result.hardreserves, {} )
end

-- raidres emits a per-item roll bonus. It is absent from every other export in this repo
-- because those are all from raids where nobody had points set, and a field raidres omits
-- when it is zero cannot appear in them -- which is how "not in our samples" was once read
-- as "not in the format".
function DecoderSpec:should_decode_the_per_item_roll_bonus()
  -- When
  local result = assert( mod.decode( fixture( "raidres-sr-plus.txt" ) ) )

  -- Then
  eq( result.metadata.id, "8UTE26" )

  local boulderdash = result.softreserves[ 1 ]
  eq( boulderdash.name, "Boulderdash" )

  local bonuses = {}
  for _, item in ipairs( boulderdash.items ) do
    table.insert( bonuses, { item.id, item.sr_plus } )
  end

  eq( bonuses, { { 32242, 5 }, { 32232, 5 }, { 32232, 5 } } )
end

-- The same raid with the duplicates edited apart, which is what the transform's
-- highest-wins rule is tested against.
function DecoderSpec:should_decode_duplicate_entries_that_disagree()
  -- When
  local result = assert( mod.decode( fixture( "raidres-sr-plus-divergent.txt" ) ) )

  -- Then
  eq( result.metadata.id, "UMMMKB" )

  local bonuses = {}
  for _, item in ipairs( result.softreserves[ 1 ].items ) do
    table.insert( bonuses, { item.id, item.sr_plus } )
  end

  eq( bonuses, { { 32242, 5 }, { 32232, 7 }, { 32232, 9 } } )
end

function DecoderSpec:should_not_decode_a_softres_it_export()
  -- When
  local result = mod.decode( fixture( "softres-it.zlib.base64" ) )

  -- Then
  eq( result, nil )
end

function DecoderSpec:should_not_decode_a_string_that_isnt_soft_res_data()
  -- When
  local result = mod.decode( "not a soft-res string" )

  -- Then
  eq( result, nil )
end

function DecoderSpec:should_have_nothing_to_decode_without_a_string()
  -- When
  local result = mod.decode( nil )

  -- Then
  eq( result, nil )
end

os.exit( lu.LuaUnit.run() )
