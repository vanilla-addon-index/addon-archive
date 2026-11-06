---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../src/?.lua;../../?.lua;../src/libs/?.lua"

require( "src/compat" )
local utils = require( "RollFor/test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )

-- ctx.on_new_group, end to end: an extension registers the way a real one does, RollFor loads
-- for real, and the group forms the way the client says it has -- a roster update. The hook is
-- one line in main.lua, and the line that matters is the one that calls it, which nothing but a
-- real roster event reaches.
--
-- It went missing once already. Round robin kept a new-group reset of its own when it moved out
-- of core, and nothing in the extension API could tell it a group had formed, so it never ran.

utils.mock_wow_api()
utils.mock_libraries()
utils.load_real_stuff()

-- What the extension heard, in the order it heard it.
local heard = {}

RollFor.Extensions.register( {
  name = "new_group_probe",
  title = "New Group Probe",
  api_version = RollFor.Extensions.API_VERSION,
  on_enable = function( ctx )
    ctx.on_group_changed( function() table.insert( heard, "group_changed" ) end )
    ctx.on_new_group( function() table.insert( heard, "new_group" ) end )
  end
} )

utils.player( "Psikutas" )

local function leave_the_group()
  utils.mock( "IsInGroup", false )
  utils.mock( "IsInRaid", false )
  utils.fire_event( "GROUP_ROSTER_UPDATE" )
end

---@return number
local function new_groups()
  local result = 0

  for _, name in ipairs( heard ) do
    if name == "new_group" then result = result + 1 end
  end

  return result
end

ExtensionNewGroupSpec = {}

function ExtensionNewGroupSpec:setUp()
  leave_the_group()
  for i = #heard, 1, -1 do heard[ i ] = nil end
end

function ExtensionNewGroupSpec:should_tell_the_extension_when_a_group_forms()
  utils.is_in_raid( "Psikutas", "Obszczymucha" )

  eq( new_groups(), 1 )
end

-- Every roster update after that is the same group changing, not a new one.
function ExtensionNewGroupSpec:should_not_tell_it_again_while_the_group_lasts()
  utils.is_in_raid( "Psikutas", "Obszczymucha" )
  utils.is_in_raid( "Psikutas", "Obszczymucha", "Ohhaimark" )
  utils.is_in_raid( "Psikutas", "Ohhaimark" )

  eq( new_groups(), 1 )
end

function ExtensionNewGroupSpec:should_tell_it_again_for_the_next_group()
  utils.is_in_raid( "Psikutas", "Obszczymucha" )
  leave_the_group()
  utils.is_in_party( "Psikutas", "Ohhaimark" )

  eq( new_groups(), 2 )
end

function ExtensionNewGroupSpec:should_not_tell_it_on_leaving_a_group()
  utils.is_in_raid( "Psikutas", "Obszczymucha" )
  for i = #heard, 1, -1 do heard[ i ] = nil end

  leave_the_group()

  eq( new_groups(), 0 )
end

-- The same roster update carries both, and the new roster is already known by the time the
-- group is new: an extension rebuilding what it keeps about the group rebuilds it from this one.
function ExtensionNewGroupSpec:should_tell_it_after_the_group_changed_hooks()
  utils.is_in_raid( "Psikutas", "Obszczymucha" )

  eq( heard, { "group_changed", "new_group" } )
end

os.exit( lu.LuaUnit.run() )
