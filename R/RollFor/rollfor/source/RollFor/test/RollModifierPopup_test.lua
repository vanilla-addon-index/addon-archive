package.path = "./?.lua;" .. package.path .. ";../src/?.lua;../../?.lua"

-- The rolling popup's "SR" label carries what a modifier adds to the player's rolls, as
-- "SR +30", from the preview until the rolling is over. A tie re-roll is its own round, so
-- its rows carry only what takes part in that round.

require( "src/compat" )
local u = require( "RollFor/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local sr = u.soft_res_item
local builder = require( "RollFor/test/IntegrationTestBuilder" )
local mock_loot_facade, mock_chat, new_roll_for = builder.mock_loot_facade, builder.mock_chat, builder.new_roll_for
local i, p = builder.i, builder.p

local RLU = RollFor.RollingLogicUtils
local RS = RollFor.Types.RollingStrategy

local BAG = 69

local function sr_plus( bonus )
  RLU.clear_modifiers()
  RLU.register_delta( {
    name = "sr_plus",
    rounds = { RS.SoftResRoll },
    apply = function( player ) return bonus[ player.name ] end
  } )
end

-- Each roll row in the popup, top to bottom, as { player name, adjustment }.
local function adjustments( rf )
  local result = {}

  for _, v in ipairs( rf.rolling_popup.content() ) do
    if v.type == "roll" then table.insert( result, { v.player_name, v.adjustment } ) end
  end

  return result
end

-- Each cast roll in the popup, top to bottom, as { player name, roll, adjustments }.
local function cast_rolls( rf )
  local result = {}

  for _, v in ipairs( rf.rolling_popup.content() ) do
    for _, cell in ipairs( v.type == "roll" and v.rolls or {} ) do
      if cell.roll then table.insert( result, { v.player_name, cell.roll, cell.adjustments } ) end
    end
  end

  return result
end

local function soft_res_rolling( p1, p2 )
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, BAG ), sr( p2.name, BAG ) )
      :build()

  loot_facade.notify( "LootOpened", i( "Bag", BAG ) )

  return rf
end

RollModifierPopupSpec = {}

function RollModifierPopupSpec:should_show_the_adjustment_in_the_preview()
  -- Given
  local p1, p2 = p( "Psikutas" ), p( "Obszczymucha" )
  local rf = soft_res_rolling( p1, p2 )
  sr_plus( { [ p1.name ] = 30 } )

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  eq( adjustments( rf ), { { "Obszczymucha" }, { "Psikutas", 30 } } )
end

function RollModifierPopupSpec:should_keep_the_adjustment_while_rolling()
  -- Given
  local p1, p2 = p( "Psikutas" ), p( "Obszczymucha" )
  local rf = soft_res_rolling( p1, p2 )
  sr_plus( { [ p1.name ] = 30, [ p2.name ] = -5 } )
  rf.loot_frame.click( 1 )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  eq( adjustments( rf ), { { "Obszczymucha", -5 }, { "Psikutas", 30 } } )

  -- When
  rf.roll( p1, 50, 1, 100 )

  -- Then
  eq( adjustments( rf ), { { "Psikutas", 30 }, { "Obszczymucha", -5 } } )
end

function RollModifierPopupSpec:should_not_show_the_adjustment_on_tie_rows()
  -- Given
  local p1, p2 = p( "Psikutas" ), p( "Obszczymucha" )
  local rf = soft_res_rolling( p1, p2 )
  sr_plus( { [ p1.name ] = 30 } )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- When: 39+30 ties Obszczymucha's 69.
  rf.roll( p1, 39, 1, 100 )
  rf.roll( p2, 69, 1, 100 )
  rf.ace_timer.tick()

  -- Then
  eq( adjustments( rf ), {
    { "Obszczymucha" },
    { "Psikutas", 30 },
    { "Obszczymucha" },
    { "Psikutas" }
  } )
end

function RollModifierPopupSpec:should_not_show_anything_without_modifiers()
  -- Given
  local p1, p2 = p( "Psikutas" ), p( "Obszczymucha" )
  local rf = soft_res_rolling( p1, p2 )
  RLU.clear_modifiers()

  -- When
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- Then
  eq( adjustments( rf ), { { "Obszczymucha" }, { "Psikutas" } } )
end

RollBreakdownSpec = {}

function RollBreakdownSpec:should_carry_what_modifiers_made_of_a_cast_roll()
  -- Given
  local p1, p2 = p( "Psikutas" ), p( "Obszczymucha" )
  local rf = soft_res_rolling( p1, p2 )
  sr_plus( { [ p1.name ] = 30 } )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- When
  rf.roll( p1, 56, 1, 100 )
  rf.roll( p2, 40, 1, 100 )

  -- Then
  eq( cast_rolls( rf ), {
    { "Psikutas", 86, { { by = "sr_plus", delta = 30 } } },
    { "Obszczymucha", 40 }
  } )
end

function RollBreakdownSpec:should_not_carry_a_breakdown_on_tie_rolls()
  -- Given
  local p1, p2 = p( "Psikutas" ), p( "Obszczymucha" )
  local rf = soft_res_rolling( p1, p2 )
  sr_plus( { [ p1.name ] = 30 } )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )
  rf.roll( p1, 39, 1, 100 )
  rf.roll( p2, 69, 1, 100 )
  rf.ace_timer.tick()

  -- When
  rf.roll( p1, 50, 1, 100 )

  -- Then
  eq( cast_rolls( rf ), {
    { "Obszczymucha", 69 },
    { "Psikutas", 69, { { by = "sr_plus", delta = 30 } } },
    { "Psikutas", 50 }
  } )
end

function RollBreakdownSpec:should_decompose_the_breakdown_the_way_the_announcement_does()
  eq( RLU.decompose( 86, { { by = "sr_plus", delta = 30 } } ), "56+30=86" )
  eq( RLU.decompose( 100, { { by = "sr_plus", delta = 30 }, { by = "role_bonus", delta = -20 } } ), "90+30-20=100" )
  eq( RLU.decompose( 40 ), 40 )
end

-- Other raiders' clients fill their placeholders through the same function.
function RollBreakdownSpec:should_fill_a_placeholder_with_the_breakdown()
  -- Given
  local rolls = { { player_name = "Psikutas", player_class = "Warrior", roll_type = "SoftRes", adjustment = 30 } }

  -- When
  RLU.update_roll( rolls, { player_name = "Psikutas", roll_type = "SoftRes", roll = 86, ordinal = 1, adjustments = { { by = "sr_plus", delta = 30 } } } )

  -- Then
  eq( rolls, { {
    player_name = "Psikutas",
    player_class = "Warrior",
    roll_type = "SoftRes",
    roll = 86,
    ordinal = 1,
    adjustment = 30,
    adjustments = { { by = "sr_plus", delta = 30 } }
  } } )
end

os.exit( lu.LuaUnit.run() )
