-- The test harness lives in RollForSoftRes now. See Decoder_test.lua.
package.path = "./?.lua;" .. package.path ..
    ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../../RollFor/src/libs/LibStub/?.lua" ..
    ";../../RollForSoftRes/src/?.lua;../../RollForSoftRes/test/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

-- What this addon is, from both sides.
--
-- It registers twice and does nothing else: with `Extensions`, so it has a page and an
-- Enabled checkbox and reports its version; and with `RollForSoftRes`, so "raidres.top" is
-- in the import window's Provider dropdown. Decoder_test covers the format. This covers the
-- two registrations and the one identity string that has to be the same in three places.

require( "src/compat" )
local u = require( "RollForSoftRes/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )

u.mock_wow_api()
require( "src/modules" )
require( "src/Extensions" )

-- The library, loaded the way the client loads it: before this addon, because the TOC says
-- `## Dependencies: RollForSoftRes`. Only its main file is needed here -- the store, the
-- window and the chain are somebody else's test.
require( "RollForSoftRes" )

require( "Decoder" )
local raidres = require( "RollForRaidRes" )

local ID = "raidres"

-- Raises rather than answering nil. Every case here reads a field off it, so a nil would
-- be an index error one line later in whichever case ran first -- and only one of them
-- remembered to check. `error` also tells the language server the result is never nil, which
-- is what lets the call sites read as they do.
---@return table
local function registered_extension()
  for _, extension in ipairs( RollFor.Extensions.all() ) do
    if extension.name == ID then return extension end
  end

  error( string.format( "%s did not register itself with RollFor.", ID ), 2 )
end

---@return table?
local function registered_provider()
  for _, provider in ipairs( RollForSoftRes.providers() ) do
    if provider.id == ID then return provider end
  end
end

-- Split rather than pattern-matched on the field name: `X-RollFor-Extension` has a `-` in
-- it, which is a quantifier in a Lua pattern and would silently match nothing.
local function toc_field( field )
  local file = assert( io.open( "../src/RollForRaidRes.toc" ) )
  local result

  for line in file:lines() do
    local name, value = string.match( line, "^## ([^:]+): (.+)$" )
    if name == field then result = (string.gsub( value, "%s+$", "" )) end
  end

  file:close()

  return result
end

ExtensionSpec = {}

function ExtensionSpec:should_have_registered_itself_on_load()
  local found = registered_extension()

  eq( found.title, "SR Provider (raidres)" )
  eq( found.incompatible, nil )
end

-- A disabled extension does not get on_enable, so a page declared from there would never
-- exist -- and that page is where the checkbox to turn it back on lives.
function ExtensionSpec:should_declare_its_options_page_on_the_spec()
  eq( type( registered_extension().options_page ), "function" )
end

function ExtensionSpec:should_be_on_by_default()
  eq( RollFor.Extensions.is_enabled( ID ), true )
end

-- Nothing in this addon touches the soft-res chain, the source registry, the minimap or a
-- slash command, so there is no phase it needs beyond declaring its decoder.
function ExtensionSpec:should_have_nothing_to_build()
  eq( registered_extension().on_ready, nil )
end

ProviderSpec = {}

-- From on_enable, which is what a disabled extension never gets -- and that is the whole
-- mechanism keeping a disabled provider out of the dropdown.
function ProviderSpec:should_hand_its_decoder_to_the_library_on_enable()
  RollForSoftRes.clear_providers()
  eq( registered_provider(), nil )

  raidres.on_enable()

  local provider = assert( registered_provider() )
  eq( provider.title, "raidres.top" )
  eq( provider.decode, RollForRaidRes.Decoder.decode )
end

IdentitySpec = {}

-- Provider id, extension name and X-RollFor-Extension are one string in three places. The
-- id is saved with an imported list, the name scopes the db, and the TOC field is how core
-- finds this addon's version -- so a drift between any two of them is a silent breakage.
function IdentitySpec:should_use_one_id_everywhere()
  raidres.on_enable()

  eq( registered_extension().name, ID )
  eq( assert( registered_provider() ).id, ID )
  eq( toc_field( "X-RollFor-Extension" ), ID )
end

-- The library first, then this. Without it the client would load the two in alphabetical
-- order, and this one comes first. RollFor is named as well as implied, so unticking it in
-- the addon list greys this one out directly rather than through the library.
function IdentitySpec:should_depend_on_the_library()
  eq( toc_field( "Dependencies" ), "RollFor, RollForSoftRes" )
end

-- The game's AddOns screen groups addons by a `Group` its C++ side infers from similar
-- names and dependencies, and only builds a group node for the addon whose own name *is*
-- the group (Blizzard_AddOnList/AddonList.lua:436,461). Left to the heuristic, this addon's
-- name is a strict prefix match for RollForSoftRes rather than RollFor, so it was grouped
-- under an addon that never becomes a group parent -- and ended up at the top level of the
-- list instead of under RollFor with its siblings. The TOC field is the documented
-- override, and it has to name the parent addon exactly.
function ExtensionSpec:should_group_under_rollfor_in_the_addons_list()
  eq( toc_field( "Group" ), "RollFor" )
end

os.exit( lu.LuaUnit.run() )
