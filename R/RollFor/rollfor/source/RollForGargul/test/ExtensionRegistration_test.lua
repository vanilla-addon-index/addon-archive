package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua"

-- What this addon is, from RollFor's side: a registration and one subscription. The protocol
-- itself is Gargul's and is exercised against Gargul, not here; what this suite proves is that
-- the addon installs in the right place and stays out of the way when the libraries it needs
-- are not there.
---@diagnostic disable: missing-fields, inject-field

require( "src/compat" )
local u = require( "RollForGargul/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/Ordering" )
local Extensions = require( "src/Extensions" )

u.mock_wow_api()
u.load_extension()

local gargul = RollForGargul.main

---@return table -- what on_ready was given, with everything it wrote to
local function ready_into()
  local registered = { subscriptions = {} }

  RollForGargul.gargul_bridge = nil

  gargul.on_ready( {
    player_info = { get_name = function() return "Psikutas" end },
    config = { ms_roll_threshold = function() return 100 end, os_roll_threshold = function() return 99 end },
    softres_source = { get_import_string = function() return "an-import-string" end },
    event_bus = {
      subscribe = function( event, callback ) registered.subscriptions[ event ] = callback end
    },
    get = function( name )
      if name == "roll_controller" then return { subscribe = function() end } end
      if name == "softres" then return { get = function() return {} end } end
    end
  } )

  return registered
end

RegistrationSpec = {}

function RegistrationSpec:should_register_itself_with_rollfor()
  Extensions.clear()
  eq( gargul.register(), true )

  local all = Extensions.all()
  eq( #all, 1 )
  eq( all[ 1 ].name, "gargul" )
  eq( all[ 1 ].title, "Gargul" )
end

-- softres_source.get_import_string is what answers Gargul's request for soft-res data, and it
-- arrived with API 5. Asking for a version the host does not have is what marks an extension
-- incompatible, which is the whole point of declaring one.
function RegistrationSpec:should_declare_the_api_version_the_seams_it_uses_arrived_in()
  Extensions.clear()
  gargul.register()

  eq( Extensions.all()[ 1 ].incompatible, nil )
  eq( Extensions.API_VERSION >= 5, true )
end

-- It registers no settings, so the page is a summary and the Enabled switch. Offering one at
-- all is the point: core's bare fallback page is a lone checkbox with nothing saying what it
-- turns on, for a feature named after somebody else's addon.
function RegistrationSpec:should_offer_its_own_options_page()
  Extensions.clear()
  gargul.register()

  eq( type( Extensions.all()[ 1 ].options_page ), "function" )
end

LibraryGuardSpec = {}

-- LibStub, AceComm, LibSerialize and LibDeflate are all somebody else's addon, and any of them
-- can be missing. GargulBridge says so by returning nothing rather than erroring, and on_ready
-- has to take that answer: subscribing anyway would crash on the first soft-res import, which is
-- long after anybody could connect the two.
function LibraryGuardSpec:should_subscribe_to_nothing_when_the_libraries_are_missing()
  local registered = ready_into()

  eq( RollForGargul.gargul_bridge, nil )
  eq( registered.subscriptions.softres_imported, nil )
end

os.exit( lu.LuaUnit.run() )
