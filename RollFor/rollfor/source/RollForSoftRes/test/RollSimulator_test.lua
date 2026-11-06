package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

require( "src/compat" )
local u = require( "RollForSoftRes/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local player, leader, is_in_raid = u.player, u.raid_leader, u.is_in_raid

local function mock_config()
  return {
    new = function()
      local result = {
        auto_raid_roll = function() return false end,
        minimap_button_hidden = function() return false end,
        minimap_button_locked = function() return false end,
        subscribe = function() end,
        rolling_popup_lock = function() return true end,
        ms_roll_threshold = function() return 100 end,
        os_roll_threshold = function() return 99 end,
        roll_threshold = function()
          return {
            value = 100,
            str = "/roll"
          }
        end,
        auto_loot = function() return true end,
        rolling_popup = function() return true end,
        raid_roll_again = function() return false end,
        default_rolling_time_seconds = function() return 8 end,
        classic_look = function() return true end,
        sr_roll_spacing = function() return 24 end
      }

      -- Core's register_number, as far as an extension sees it: the key becomes a getter answering the
      -- default and a setter.
      result.register_number = function( key, default )
        result[ key ] = function() return default end
        result[ "set_" .. key ] = function() end
      end

      return result
    end
  }
end

---@type ModuleRegistry
local module_registry = {
  { module_name = "Config",  mock = mock_config },
  { module_name = "ChatApi", mock = "mocks/ChatApi", variable_name = "chat" }
}

local m = {}

local PENDANT = 32370 -- Nadina's Pendant of Purity, Mother Shahraz

RollSimulatorSpec = {}

-- The simulator still has to filter out anyone who isn't in the fake raid, which is the
-- job the replaced layer was doing in the first place.
function RollSimulatorSpec:should_still_drop_soft_ressers_outside_the_fake_raid()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Drutree", "Mendunia" )
  local rf = u.load_roll_for()

  -- When (only Drutree is named, so Mendunia is not in the simulated group)
  u.run_command( "RFSETUP", string.format( "%s Drutree", u.item_link( "Nadina's Pendant of Purity", PENDANT ) ) )

  -- Then
  local rollers = rf.softres.get( { item_id = PENDANT, item_quantity = 1 } )
  eq( u.map( rollers, function( p ) return p.name end ), { "Drutree" } )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run( "-v", "-T", "Spec", "-m", "should", "-o", "text" ) )
