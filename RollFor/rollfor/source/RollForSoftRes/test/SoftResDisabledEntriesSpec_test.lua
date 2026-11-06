-- What a switched-off soft-res entry means to the rest of RollFor.
--
-- The list window's checkboxes are only half the feature; this is the other half, and the half
-- that decides loot. A reservation switched off is a roll the player does not have, and a player
-- with none of them left is not soft-ressing that item at all.
---@diagnostic disable: missing-fields
package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

require( "src/compat" )
local u = require( "RollForSoftRes/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )

u.mock_wow_api()
u.load_extension()

local DisabledEntries = RollForSoftRes.SoftResDisabledEntries
local Decorator = RollForSoftRes.SoftResDisabledEntriesDecorator

local TSUNAMI = 30627
local ROBE = 30056

-- Nothing here renames anybody, so a reservation's imported name is the in-game one. The one spec
-- that does care builds its own.
local straight_names = { get_softres_name = function( name ) return name end }

-- The chain below this decorator, as the four read methods it actually leans on. Reservations are
-- given as { item_id, name, rolls }.
---@param reservations table[]
local function inner( reservations )
  local items, rollers = {}, {}

  for _, reservation in ipairs( reservations ) do
    local item_id, name, rolls = reservation[ 1 ], reservation[ 2 ], reservation[ 3 ] or 1

    if not rollers[ item_id ] then
      rollers[ item_id ] = {}
      table.insert( items, { item_id = item_id } )
    end

    table.insert( rollers[ item_id ], { name = name, rolls = rolls } )
  end

  local function get( item_data )
    -- Cloned the way the store clones, so the decorator mutating a roller's count cannot write
    -- back into the list itself.
    local result = {}

    for _, roller in ipairs( rollers[ item_data.item_id ] or {} ) do
      table.insert( result, { name = roller.name, rolls = roller.rolls } )
    end

    return result
  end

  return {
    get = get,
    get_items = function() return items end,
    get_all_rollers = function()
      local seen, result = {}, {}

      for _, item in pairs( rollers ) do
        for _, roller in ipairs( item ) do
          if not seen[ roller.name ] then
            seen[ roller.name ] = true
            table.insert( result, { name = roller.name } )
          end
        end
      end

      table.sort( result, function( a, b ) return a.name < b.name end )

      return result
    end,
    is_player_softressing = function( player_name, item_data )
      for _, item in ipairs( item_data and { { item_id = item_data.item_id } } or items ) do
        for _, roller in ipairs( rollers[ item.item_id ] or {} ) do
          if roller.name == player_name then return true end
        end
      end

      return false
    end
  }
end

---@param reservations table[]
---@param name_matcher table?
local function decorated( reservations, name_matcher )
  local db = {}
  local disabled_entries = DisabledEntries.new( db, name_matcher or straight_names )

  return Decorator.new( disabled_entries, inner( reservations ) ), disabled_entries, db
end

---@param item_id number
local function item( item_id )
  return { item_id = item_id, item_quantity = 1 }
end

-- Who the decorator says may roll for an item, as { name, rolls }.
---@param softres table
---@param item_id number
local function rollers_for( softres, item_id )
  local result = {}

  for _, roller in ipairs( softres.get( item( item_id ) ) ) do
    table.insert( result, { roller.name, roller.rolls } )
  end

  return result
end

RollsSpec = {}

function RollsSpec:should_leave_an_untouched_list_alone()
  local softres = decorated( { { TSUNAMI, "Psikutas", 2 }, { TSUNAMI, "Obszczymucha" } } )

  eq( rollers_for( softres, TSUNAMI ), { { "Psikutas", 2 }, { "Obszczymucha", 1 } } )
end

-- The point of the ungrouped view: one of two reservations off leaves the player one roll.
function RollsSpec:should_take_one_roll_away_for_each_entry_switched_off()
  local softres, disabled = decorated( { { TSUNAMI, "Psikutas", 3 } } )

  disabled.set( TSUNAMI, "Psikutas", 2, false )

  eq( rollers_for( softres, TSUNAMI ), { { "Psikutas", 2 } } )
end

function RollsSpec:should_drop_a_player_whose_every_roll_is_switched_off()
  local softres, disabled = decorated( { { TSUNAMI, "Psikutas", 2 }, { TSUNAMI, "Obszczymucha" } } )

  disabled.set_all( TSUNAMI, "Psikutas", 2, false )

  eq( rollers_for( softres, TSUNAMI ), { { "Obszczymucha", 1 } } )
end

-- Switched off per item, not per player: Psikutas keeps the robe.
function RollsSpec:should_leave_the_players_other_items_alone()
  local softres, disabled = decorated( { { TSUNAMI, "Psikutas" }, { ROBE, "Psikutas" } } )

  disabled.set_all( TSUNAMI, "Psikutas", 1, false )

  eq( rollers_for( softres, TSUNAMI ), {} )
  eq( rollers_for( softres, ROBE ), { { "Psikutas", 1 } } )
end

function RollsSpec:should_give_the_rolls_back_when_switched_on_again()
  local softres, disabled = decorated( { { TSUNAMI, "Psikutas", 2 } } )

  disabled.set_all( TSUNAMI, "Psikutas", 2, false )
  disabled.set_all( TSUNAMI, "Psikutas", 2, true )

  eq( rollers_for( softres, TSUNAMI ), { { "Psikutas", 2 } } )
end

-- A switch above the rolls the player actually has counts for nothing. An import that shortened
-- somebody's reservations must not take a roll off the ones they have left.
function RollsSpec:should_ignore_a_switch_beyond_the_rolls_on_the_list()
  local softres, disabled = decorated( { { TSUNAMI, "Psikutas" } } )

  disabled.set( TSUNAMI, "Psikutas", 2, false )

  eq( rollers_for( softres, TSUNAMI ), { { "Psikutas", 1 } } )
end

SoftRessingSpec = {}

function SoftRessingSpec:should_say_a_player_with_a_roll_left_is_still_softressing()
  local softres, disabled = decorated( { { TSUNAMI, "Psikutas", 2 } } )

  disabled.set( TSUNAMI, "Psikutas", 1, false )

  eq( softres.is_player_softressing( "Psikutas", item( TSUNAMI ) ), true )
end

-- The answer the rest of RollFor acts on: not soft-ressing means they roll in the normal round.
function SoftRessingSpec:should_say_a_fully_switched_off_player_is_not_softressing_the_item()
  local softres, disabled = decorated( { { TSUNAMI, "Psikutas", 2 } } )

  disabled.set_all( TSUNAMI, "Psikutas", 2, false )

  eq( softres.is_player_softressing( "Psikutas", item( TSUNAMI ) ), false )
end

-- Asked without an item, the question is whether they are on the list at all, so one item left
-- on is enough.
function SoftRessingSpec:should_still_be_softressing_while_any_item_is_left_on()
  local softres, disabled = decorated( { { TSUNAMI, "Psikutas" }, { ROBE, "Psikutas" } } )

  disabled.set_all( TSUNAMI, "Psikutas", 1, false )

  eq( softres.is_player_softressing( "Psikutas" ), true )
end

function SoftRessingSpec:should_not_be_softressing_once_every_item_is_switched_off()
  local softres, disabled = decorated( { { TSUNAMI, "Psikutas" }, { ROBE, "Psikutas" } } )

  disabled.set_all( TSUNAMI, "Psikutas", 1, false )
  disabled.set_all( ROBE, "Psikutas", 1, false )

  eq( softres.is_player_softressing( "Psikutas" ), false )
end

function SoftRessingSpec:should_drop_a_fully_switched_off_player_from_the_roller_list()
  local softres, disabled = decorated( { { TSUNAMI, "Psikutas" }, { ROBE, "Obszczymucha" } } )

  disabled.set_all( TSUNAMI, "Psikutas", 1, false )

  eq( softres.get_all_rollers(), { { name = "Obszczymucha" } } )
end

NamesSpec = {}

-- Switches belong to the name on the imported document, so matching a typo'd name to an in-game
-- one with /sro carries them over instead of orphaning them.
function NamesSpec:should_follow_a_player_whose_name_was_matched_later()
  local matched = { get_softres_name = function( name ) return name == "Psikutas" and "Pskutas" or name end }
  local softres, disabled, db = decorated( { { TSUNAMI, "Psikutas", 2 } }, matched )

  disabled.set_all( TSUNAMI, "Psikutas", 2, false )

  eq( db.entries[ TSUNAMI ][ "Pskutas" ], { true, true } )
  eq( rollers_for( softres, TSUNAMI ), {} )
end

StorageSpec = {}

function StorageSpec:should_write_nothing_until_something_is_switched_off()
  local _, _, db = decorated( { { TSUNAMI, "Psikutas" } } )

  eq( db.entries, {} )
end

-- A saved variable only ever grows, so an entry switched back on takes its empty tables with it.
function StorageSpec:should_leave_nothing_behind_when_switched_on_again()
  local _, disabled, db = decorated( { { TSUNAMI, "Psikutas", 2 } } )

  disabled.set_all( TSUNAMI, "Psikutas", 2, false )
  disabled.set_all( TSUNAMI, "Psikutas", 2, true )

  eq( db.entries, {} )
end

function StorageSpec:should_forget_everything_when_cleared()
  local softres, disabled, db = decorated( { { TSUNAMI, "Psikutas", 2 } } )

  disabled.set_all( TSUNAMI, "Psikutas", 2, false )
  disabled.clear()

  eq( db.entries, {} )
  eq( rollers_for( softres, TSUNAMI ), { { "Psikutas", 2 } } )
end

os.exit( lu.LuaUnit.run() )
