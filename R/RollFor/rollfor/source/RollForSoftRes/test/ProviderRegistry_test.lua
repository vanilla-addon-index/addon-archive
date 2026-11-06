package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

-- What a provider has to be to get in.
--
-- Mirrors Extensions.register: a spec that is wrong is refused and says why, rather than
-- being half-accepted and failing later at somebody's import. The whole surface a provider
-- addon touches is this function and the three fields it takes.

require( "src/compat" )
local u = require( "RollForSoftRes/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )

u.mock_wow_api()
u.load_extension()

local errors

local function capture_errors()
  errors = {}
  RollFor.api.DEFAULT_CHAT_FRAME = {
    AddMessage = function( _, message ) table.insert( errors, (u.decolorize( message )) ) end
  }
end

local function complained_about( fragment )
  for _, message in ipairs( errors ) do
    if string.find( message, fragment, 1, true ) then return true end
  end

  return false
end

local function decode() return {} end

---@return boolean -- what register answered
local function register( spec )
  RollForSoftRes.clear_providers()
  capture_errors()

  return RollForSoftRes.register( spec )
end

RegisterSpec = {}

function RegisterSpec:should_accept_a_complete_spec()
  eq( register( { id = "raidres", title = "raidres", decode = decode } ), true )
  eq( #RollForSoftRes.providers(), 1 )
end

function RegisterSpec:should_refuse_something_that_is_not_a_table()
  eq( register( "raidres" ), false )
  eq( complained_about( "must be a table" ), true )
end

function RegisterSpec:should_refuse_a_missing_id()
  eq( register( { title = "raidres", decode = decode } ), false )
  eq( complained_about( "'id' must be a non-empty string" ), true )
end

function RegisterSpec:should_refuse_a_missing_title()
  eq( register( { id = "raidres", decode = decode } ), false )
  eq( complained_about( "'title' must be a non-empty string" ), true )
end

function RegisterSpec:should_refuse_a_decode_that_is_not_a_function()
  eq( register( { id = "raidres", title = "raidres", decode = "base64" } ), false )
  eq( complained_about( "'decode' must be a function" ), true )
end

-- Two addons claiming the same id would make the saved provider ambiguous, which is the one
-- thing the id exists to prevent.
function RegisterSpec:should_refuse_a_duplicate_id()
  register( { id = "raidres", title = "raidres", decode = decode } )
  capture_errors()

  eq( RollForSoftRes.register( { id = "raidres", title = "raidres.top", decode = decode } ), false )
  eq( complained_about( "already registered" ), true )
  eq( #RollForSoftRes.providers(), 1 )
end

-- Registration order, not the alphabet: the TOC dependency chain is what decides it, and
-- the dropdown shows them in the order they arrived.
function RegisterSpec:should_keep_registration_order()
  RollForSoftRes.clear_providers()
  RollForSoftRes.register( { id = "softres_it", title = "softres.it", decode = decode } )
  RollForSoftRes.register( { id = "raidres", title = "raidres", decode = decode } )

  local ids = {}
  for _, provider in ipairs( RollForSoftRes.providers() ) do table.insert( ids, provider.id ) end

  eq( ids, { "softres_it", "raidres" } )
end

os.exit( lu.LuaUnit.run() )
