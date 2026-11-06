RollFor = RollFor or {}
RollForAutoLoot = RollForAutoLoot or {}
local m = RollFor

require( "src/Interface" )
require( "src/AutoLootDb" ) -- AutoLoot reads the predefined list through it, so it must load first.
local RealAutoLoot = require( "src/AutoLoot" )

local M = {}
local mock = m.Interface.mock

---@class AutoLootMock : AutoLoot

function M.new( api, autoloot_db, config, player_info, chat )
  local real_auto_loot = RealAutoLoot.new( function() return api end, autoloot_db, config, player_info, chat )

  local interface = mock( RealAutoLoot.interface )

  interface.is_auto_looted = real_auto_loot.is_auto_looted
  interface.is_on_predefined_list = real_auto_loot.is_on_predefined_list
  interface.decide = real_auto_loot.decide
  interface.on_awarded = real_auto_loot.on_awarded

  ---@type AutoLootMock
  return interface
end

return M
