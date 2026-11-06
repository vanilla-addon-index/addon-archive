-- The test harness lives in RollForSoftRes now -- one copy for the three addons instead of
-- three. It sits beside this addon, as it does in AddOns, where
-- `## Dependencies: RollForSoftRes` guarantees it is there.
package.path = "./?.lua;" .. package.path ..
    ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../../RollFor/src/libs/LibStub/?.lua" ..
    ";../../RollFor/src/libs/LibDeflate/?.lua" ..
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

-- LibDeflate is core's as well, and the real one: the zlib layer is the entire difference
-- between this provider and RollForRaidRes, so mocking it away would leave nothing under
-- test. Loaded before the decoder, which asks LibStub for it at call time.
require( "LibDeflate" )

local mod = require( "Decoder" )

-- The wire format, asserted against the real thing. `fixtures/sr-ohhaimark.zlib.base64` is
-- an export taken from softres.it and `sr-ohhaimark.json` is what it decodes to -- a
-- matched pair that has been sitting in this addon untested since it was written.
-- `fixtures/raidres.txt` is RollForRaidRes's export, and the point of the pair is that this
-- one is unreadable here: a raidres string carries no zlib header, so decompression fails
-- before there is any JSON to parse.

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

function DecoderSpec:should_decode_a_softres_it_export()
  -- When
  local result = assert( mod.decode( fixture( "sr-ohhaimark.zlib.base64" ) ) )

  -- Then
  eq( result.metadata.id, "t5uf54" )
  eq( result.metadata.instance, "kara" )
  eq( result.softreserves[ 1 ].name, "Ohhaimark" )
  eq( result.softreserves[ 1 ].class, "warrior" )

  local item_ids = {}
  for _, item in ipairs( result.softreserves[ 1 ].items ) do
    table.insert( item_ids, item.id )
  end

  eq( item_ids, { 28749 } )
  eq( result.hardreserves, {} )
end

-- The mirror of RollForRaidRes's negative case. Neither provider pretends to read the
-- other's format, which is the whole reason there are two of them and why the import window
-- asks rather than sniffs.
function DecoderSpec:should_not_decode_a_raidres_export()
  -- When
  local result = mod.decode( fixture( "raidres.txt" ) )

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
