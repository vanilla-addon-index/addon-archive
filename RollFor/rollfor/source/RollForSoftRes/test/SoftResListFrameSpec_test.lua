-- The soft-res list window: which reservations it shows, what each row says, and the order it
-- says them in.
--
-- The transformer is the observation point rather than the widgets, the same way
-- PendingLootFrameSpec does it: what a row is made of is decided in the model handed to it, and a
-- drawn frame is not something an assertion can ask a question of.
---@diagnostic disable: missing-fields, inject-field
package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

require( "src/compat" )
local u = require( "RollForSoftRes/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local m = RollFor
require( "src/modules" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/ItemUtils" )

u.mock_wow_api()
require( "src/GuiElements" )
require( "src/ListPopup" )
require( "src/DropTable" )
u.load_extension()

local popup_builder = require( "mocks/PopupBuilder" )
local SoftResListFrame = RollForSoftRes.SoftResListFrame
local Transformer = RollForSoftRes.SoftResListContentTransformer
local DisabledEntries = RollForSoftRes.SoftResDisabledEntries

-- Nothing in these specs renames anybody, so a reservation's imported name is the in-game one.
local name_matcher = { get_softres_name = function( name ) return name end }

local TSUNAMI = 30627     -- Leotheras the Blind
local FATHOMSTONE = 30049 -- Hydross the Unstable
local ROBE = 30056        -- Hydross the Unstable
local CORD = 30064        -- The Lurker Below, killed before Leotheras but named after him
local UNCATALOGUED = 999999

local names = {
  [ TSUNAMI ] = "Tsunami Talisman",
  [ FATHOMSTONE ] = "Fathomstone",
  [ ROBE ] = "Robe of Hateful Echoes",
  [ CORD ] = "Cord of Screaming Terrors",
  [ UNCATALOGUED ] = "Mystery Trinket"
}

local group = {
  Obszczymucha = { name = "Obszczymucha", class = "Rogue" },
  Psikutas = { name = "Psikutas", class = "Warrior" }
}

---@param cached boolean? -- whether the client has the items; true unless a spec says otherwise
local function item_cache( cached )
  u.mock( "GetItemInfo", function( item_id )
    local name = cached ~= false and names[ item_id ]
    if name then return name, u.item_link( name, item_id ) end
  end )
end

-- Who reserved what, as { item_id, name, rolls }, in whatever order the spec lists it. The double
-- groups it by item the way the store does.
---@param reservations table[]
local function softres( reservations )
  local items, rollers = {}, {}

  for _, reservation in ipairs( reservations ) do
    local item_id, name, rolls = reservation[ 1 ], reservation[ 2 ], reservation[ 3 ] or 1

    if not rollers[ item_id ] then
      rollers[ item_id ] = {}
      table.insert( items, { item_id = item_id } )
    end

    table.insert( rollers[ item_id ], { name = name, rolls = rolls } )
  end

  return {
    get_items = function() return items end,
    get = function( item_data ) return rollers[ item_data.item_id ] or {} end
  }
end

-- One unit per character the player sees: colour codes and a link's hyperlink wrapper draw nothing.
---@param text string
local function text_width( text )
  local visible = string.gsub( text, "|c%x%x%x%x%x%x%x%x", "" )
  visible = string.gsub( visible, "|r", "" )
  visible = string.gsub( visible, "|H.-|h(.-)|h", "%1" )

  return string.len( visible )
end

local group_roster = {
  get_all_players_in_my_group = function()
    local result = {}
    for _, player in pairs( group ) do table.insert( result, player ) end
    return result
  end
}

-- What modifiers add, as bonuses[ player ][ item_id ], for whichever spec sets it. Asked about the
-- soft-res round only, the way the list asks.
local bonuses = {}
local asked_rounds = {}

---@param player RollingPlayer
---@param item Item
---@param strategy RollingStrategyType
local function preview( player, item, strategy )
  asked_rounds[ strategy ] = true
  return bonuses[ player.name ] and bonuses[ player.name ][ item.id ]
end

---@param reservations table[]
---@param cached boolean?
local function window( reservations, cached )
  item_cache( cached )
  u.mock_object( "GameTooltip", { SetHyperlink = function() end } )

  local db = {}
  local model, content
  local real = Transformer.new()
  local scheduled = {}

  -- The real thing rather than a stub: which entries are off is half of what the rows say, and a
  -- stub would only be asserting that the window asked.
  local disabled_db = {}
  local disabled_entries = DisabledEntries.new( disabled_db, name_matcher )

  -- Every message announced to the group, in order.
  local announced = {}
  local chat = { announce = function( message ) table.insert( announced, message ) end }

  local ace_timer = {
    ScheduleTimer = function( _, callback, delay )
      table.insert( scheduled, { callback = callback, delay = delay } )
    end
  }

  local frame = SoftResListFrame.new( popup_builder.new(), db, {
    transform = function( data )
      model = data
      content = real.transform( data )

      return content
    end
  }, softres( reservations ), group_roster, ace_timer, text_width, function() return 15 end, preview,
    disabled_entries, chat )

  frame.db = db
  frame.disabled_entries = disabled_entries
  frame.disabled_db = disabled_db
  frame.model = function() return model end
  frame.announced = announced
  frame.scheduled = function() return scheduled end

  ---@param type string
  frame.lines = function( type )
    local result = {}

    for _, line in ipairs( content or {} ) do
      if line.type == type then table.insert( result, line ) end
    end

    return result
  end

  -- What each row says, uncoloured, as { player, item, boss }. More than one roll is a 2x in front
  -- of the item, the way the row draws it. A player who reserved nothing has a note where the item
  -- goes and a dash for the boss.
  frame.rows = function()
    local result = {}

    for _, row in ipairs( frame.lines( Transformer.row_type ) ) do
      local is_link = string.find( row.item_link, "|H", 1, true )
      local item = is_link and m.ItemUtils.get_item_name( row.item_link ) or (u.decolorize( row.item_link ))
      if row.count then item = string.format( "%s %s", (u.decolorize( row.count )), item ) end
      table.insert( result, { u.decolorize( row.player ), item, (u.decolorize( row.boss )) } )
    end

    return result
  end

  -- The rows that are reservations, leaving out the group members who made none.
  frame.reservations = function()
    local result = {}

    for _, row in ipairs( frame.lines( Transformer.row_type ) ) do
      if u.decolorize( row.item_link ) ~= "Not soft-ressing" then table.insert( result, row ) end
    end

    return result
  end

  frame.header = function() return frame.lines( Transformer.header_type )[ 1 ] end

  -- Clicking the box at the head of the nth reservation row, the way the widget does.
  ---@param index number
  frame.toggle = function( index )
    frame.reservations()[ index ].on_toggle_enabled()
  end

  -- Each reservation row's checkbox state, in the order the rows are drawn.
  frame.boxes = function()
    local result = {}

    for _, row in ipairs( frame.reservations() ) do
      table.insert( result, row.enabled )
    end

    return result
  end

  return frame
end

RowSpec = {}

function RowSpec:should_draw_one_row_per_player_per_item()
  local frame = window( {
    { TSUNAMI, "Psikutas" },
    { TSUNAMI, "Obszczymucha" },
    { FATHOMSTONE, "Psikutas", 2 }
  } )

  frame.show()

  eq( frame.rows(), {
    { "Obszczymucha", "Tsunami Talisman", "Leotheras the Blind" },
    { "Psikutas", "2x Fathomstone", "Hydross the Unstable" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" }
  } )
end

function RowSpec:should_name_the_boss_from_the_drop_table()
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()

  eq( u.decolorize( frame.reservations()[ 1 ].boss ), "Leotheras the Blind" )
end

function RowSpec:should_say_trash_for_an_item_no_boss_drops()
  local frame = window( { { UNCATALOGUED, "Psikutas" } } )

  frame.show()

  eq( frame.reservations()[ 1 ].boss, m.colors.grey( "Trash" ) )
end

function RowSpec:should_colour_present_players_by_class_and_absent_ones_red()
  local frame = window( { { TSUNAMI, "Psikutas" }, { TSUNAMI, "Absentee" } } )

  frame.show()
  frame.model().on_toggle_absent( true )

  local rows = frame.reservations()
  eq( rows[ 1 ].player, m.colors.red( "Absentee" ) )
  eq( rows[ 2 ].player, m.colorize_player_by_class( "Psikutas", "Warrior" ) )
end

function RowSpec:should_carry_the_item_link_and_its_tooltip_link()
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()

  local row = frame.reservations()[ 1 ]
  eq( row.item_link, u.item_link( "Tsunami Talisman", TSUNAMI ) )
  eq( row.item_tooltip_link, m.ItemUtils.get_tooltip_link( u.item_link( "Tsunami Talisman", TSUNAMI ) ) )
end

AbsentSpec = {}

function AbsentSpec:should_hide_players_not_in_the_group_by_default()
  local frame = window( { { TSUNAMI, "Psikutas" }, { TSUNAMI, "Absentee" } } )

  frame.show()

  eq( frame.rows(), {
    { "Obszczymucha", "Not soft-ressing", "-" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" }
  } )
  eq( frame.header().show_absent, false )
end

function AbsentSpec:should_show_them_once_the_box_is_ticked()
  local frame = window( { { TSUNAMI, "Psikutas" }, { TSUNAMI, "Absentee" } } )

  frame.show()
  frame.model().on_toggle_absent( true )

  eq( frame.db.show_absent, true )
  eq( frame.header().show_absent, true )
  eq( frame.rows(), {
    { "Absentee", "Tsunami Talisman", "Leotheras the Blind" },
    { "Obszczymucha", "Not soft-ressing", "-" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" }
  } )
end

-- Two players, five reservations, two of which are doubled.
local sorting_fixture = {
  { TSUNAMI, "Psikutas" },
  { UNCATALOGUED, "Obszczymucha" },
  { ROBE, "Psikutas" },
  { TSUNAMI, "Obszczymucha", 2 },
  { FATHOMSTONE, "Psikutas", 2 }
}

GroupItemsSpec = {}

-- Grouped is the default, so a db that has never seen the checkbox lists two rolls as one 2x row.
function GroupItemsSpec:should_group_repeated_reservations_by_default()
  local frame = window( { { TSUNAMI, "Psikutas", 2 } } )

  frame.show()

  eq( frame.header().group_items, true )
  eq( frame.rows(), {
    { "Obszczymucha", "Not soft-ressing", "-" },
    { "Psikutas", "2x Tsunami Talisman", "Leotheras the Blind" }
  } )
end

function GroupItemsSpec:should_list_each_roll_on_its_own_row_once_the_box_is_unticked()
  local frame = window( { { TSUNAMI, "Psikutas", 3 }, { FATHOMSTONE, "Psikutas" } } )

  frame.show()
  frame.model().on_toggle_group_items( false )

  eq( frame.db.group_items, false )
  eq( frame.header().group_items, false )
  eq( frame.rows(), {
    { "Obszczymucha", "Not soft-ressing", "-" },
    { "Psikutas", "Fathomstone", "Hydross the Unstable" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" }
  } )
end

-- No 2x anywhere, so the gutter the count hung in goes away and the item column is measured
-- without it.
function GroupItemsSpec:should_leave_no_room_for_a_count_when_ungrouped()
  local frame = window( sorting_fixture )

  frame.show()
  eq( frame.model().widths.count, 2 )

  frame.model().on_toggle_group_items( false )

  eq( frame.model().widths.count, 0 )

  for _, row in ipairs( frame.lines( Transformer.row_type ) ) do
    eq( row.count, nil )
  end
end

-- Ungrouped rows are single rolls, so the item column sorts on the name alone.
function GroupItemsSpec:should_sort_the_item_column_by_name_when_ungrouped()
  local frame = window( sorting_fixture )

  frame.show()
  frame.model().on_toggle_group_items( false )
  frame.model().on_sort( "item" )

  eq( frame.rows(), {
    { "Psikutas", "Fathomstone", "Hydross the Unstable" },
    { "Psikutas", "Fathomstone", "Hydross the Unstable" },
    { "Obszczymucha", "Mystery Trinket", "Trash" },
    { "Psikutas", "Robe of Hateful Echoes", "Hydross the Unstable" },
    { "Obszczymucha", "Tsunami Talisman", "Leotheras the Blind" },
    { "Obszczymucha", "Tsunami Talisman", "Leotheras the Blind" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" }
  } )
end

-- Every roll is its own row, so the modifier that applies to the player's rolls is on all of them.
function GroupItemsSpec:should_repeat_the_adjustment_on_every_row()
  bonuses = { Psikutas = { [ TSUNAMI ] = 30 } }
  local frame = window( { { TSUNAMI, "Psikutas", 2 } } )

  frame.show()
  frame.model().on_toggle_group_items( false )

  local rows = frame.reservations()
  eq( #rows, 2 )
  eq( rows[ 1 ].adjustment, m.colors.white( " +30" ) )
  eq( rows[ 2 ].adjustment, m.colors.white( " +30" ) )
  bonuses = {}
end

function GroupItemsSpec:should_group_again_once_the_box_is_reticked()
  local frame = window( { { TSUNAMI, "Psikutas", 2 } } )

  frame.show()
  frame.model().on_toggle_group_items( false )
  frame.model().on_toggle_group_items( true )

  eq( frame.db.group_items, true )
  eq( #frame.reservations(), 1 )
  eq( frame.reservations()[ 1 ].count, "2x" )
end

DisabledEntriesSpec = {}

function DisabledEntriesSpec:should_have_every_entry_enabled_to_start_with()
  local frame = window( { { TSUNAMI, "Psikutas", 2 }, { ROBE, "Obszczymucha" } } )

  frame.show()

  eq( frame.boxes(), { "on", "on" } )
end

-- A player who reserved nothing has no entry to switch off, so there is no box on that row.
function DisabledEntriesSpec:should_give_no_box_to_a_player_who_reserved_nothing()
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()

  local rows = frame.lines( Transformer.row_type )
  eq( u.decolorize( rows[ 1 ].item_link ), "Not soft-ressing" )
  eq( rows[ 1 ].enabled, nil )
  eq( rows[ 1 ].on_toggle_enabled, nil )
end

-- Grouped, the box speaks for the whole reservation: one click takes both rolls off.
function DisabledEntriesSpec:should_switch_every_roll_off_from_a_grouped_row()
  local frame = window( { { TSUNAMI, "Psikutas", 2 } } )

  frame.show()
  frame.toggle( 1 )

  eq( frame.boxes(), { "off" } )
  eq( frame.disabled_entries.disabled_count( TSUNAMI, "Psikutas", 2 ), 2 )
end

function DisabledEntriesSpec:should_switch_them_all_back_on()
  local frame = window( { { TSUNAMI, "Psikutas", 2 } } )

  frame.show()
  frame.toggle( 1 )
  frame.toggle( 1 )

  eq( frame.boxes(), { "on" } )
  eq( frame.disabled_entries.disabled_count( TSUNAMI, "Psikutas", 2 ), 0 )
end

-- Ungrouped, each roll has a box of its own, and the one that was clicked is the one that goes
-- off -- the tick does not slide up to the top of the run.
function DisabledEntriesSpec:should_switch_off_one_roll_at_a_time_when_ungrouped()
  local frame = window( { { TSUNAMI, "Psikutas", 3 } } )

  frame.show()
  frame.model().on_toggle_group_items( false )
  frame.toggle( 2 )

  eq( frame.boxes(), { "on", "off", "on" } )
  eq( frame.disabled_entries.is_disabled( TSUNAMI, "Psikutas", 2 ), true )
  eq( frame.disabled_entries.is_disabled( TSUNAMI, "Psikutas", 1 ), false )
end

-- The heart of it: a reservation with one of its two rolls off is worth one roll, and the
-- grouped row says so rather than still claiming 2x.
function DisabledEntriesSpec:should_count_only_the_rolls_left_on_when_grouped()
  local frame = window( { { TSUNAMI, "Psikutas", 2 } } )

  frame.show()
  frame.model().on_toggle_group_items( false )
  frame.toggle( 1 )
  frame.model().on_toggle_group_items( true )

  eq( frame.boxes(), { "partial" } )
  eq( frame.rows(), {
    { "Obszczymucha", "Not soft-ressing", "-" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" }
  } )
end

function DisabledEntriesSpec:should_still_show_a_count_when_more_than_one_roll_is_left_on()
  local frame = window( { { TSUNAMI, "Psikutas", 3 } } )

  frame.show()
  frame.model().on_toggle_group_items( false )
  frame.toggle( 1 )
  frame.model().on_toggle_group_items( true )

  eq( frame.boxes(), { "partial" } )
  eq( frame.reservations()[ 1 ].count, "2x" )
end

-- A partial box fills before it empties, the usual way round for a box with a third state.
function DisabledEntriesSpec:should_switch_a_partial_row_fully_on_when_clicked()
  local frame = window( { { TSUNAMI, "Psikutas", 2 } } )

  frame.show()
  frame.model().on_toggle_group_items( false )
  frame.toggle( 1 )
  frame.model().on_toggle_group_items( true )
  frame.toggle( 1 )

  eq( frame.boxes(), { "on" } )
  eq( frame.reservations()[ 1 ].count, "2x" )
end

-- Every roll off is not the same as a row that is gone: the window still lists it, because the
-- box that switches it back on is on that row.
function DisabledEntriesSpec:should_keep_listing_a_reservation_with_everything_switched_off()
  local frame = window( { { TSUNAMI, "Psikutas", 2 } } )

  frame.show()
  frame.toggle( 1 )

  eq( frame.rows(), {
    { "Obszczymucha", "Not soft-ressing", "-" },
    { "Psikutas", "2x Tsunami Talisman", "Leotheras the Blind" }
  } )
end

-- With nothing left on there is no live count to show, so the row shows what the list said it
-- was. Without it a double reservation switched off would read as a single one.
function DisabledEntriesSpec:should_show_the_imported_count_once_every_roll_is_off()
  local frame = window( { { TSUNAMI, "Psikutas", 2 } } )

  frame.show()
  frame.toggle( 1 )

  eq( u.decolorize( frame.reservations()[ 1 ].count ), "2x" )
end

function DisabledEntriesSpec:should_show_no_count_for_a_single_reservation_switched_off()
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()
  frame.toggle( 1 )

  eq( frame.reservations()[ 1 ].count, nil )
end

GreyingSpec = {}

-- SoftResListFrame's own shade, a step darker than m.colors.grey.
local grey = "|cff656565"

---@param text string?
local function is_grey( text )
  return text and string.sub( text, 1, 10 ) == grey and not string.find( text, "|c", 11, true ) or false
end

-- A row that does not count is drawn as one: the class colour, the item's quality and the boss's
-- own colour all go, or the eye has nothing to go on but a small box at the far left.
function GreyingSpec:should_grey_the_whole_row_when_every_roll_is_off()
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()
  frame.toggle( 1 )

  local row = frame.reservations()[ 1 ]
  eq( { is_grey( row.player ), is_grey( row.item_link ), is_grey( row.boss ) }, { true, true, true } )
end

function GreyingSpec:should_grey_the_count_and_the_modifier_too()
  bonuses = { Psikutas = { [ TSUNAMI ] = 30 } }
  local frame = window( { { TSUNAMI, "Psikutas", 2 } } )

  frame.show()
  frame.toggle( 1 )

  local row = frame.reservations()[ 1 ]
  eq( { is_grey( row.count ), is_grey( row.adjustment ) }, { true, true } )
  bonuses = {}
end

-- A partial row still has rolls that count, so it keeps its colours; only the box says otherwise.
function GreyingSpec:should_leave_a_partially_switched_off_row_in_its_own_colours()
  local frame = window( { { TSUNAMI, "Psikutas", 2 } } )

  frame.show()
  frame.model().on_toggle_group_items( false )
  frame.toggle( 1 )
  frame.model().on_toggle_group_items( true )

  local row = frame.reservations()[ 1 ]
  eq( row.enabled, "partial" )
  eq( { is_grey( row.player ), is_grey( row.item_link ) }, { false, false } )
end

function GreyingSpec:should_grey_only_the_row_that_is_off_when_ungrouped()
  local frame = window( { { TSUNAMI, "Psikutas", 2 } } )

  frame.show()
  frame.model().on_toggle_group_items( false )
  frame.toggle( 2 )

  local rows = frame.reservations()
  eq( { is_grey( rows[ 1 ].item_link ), is_grey( rows[ 2 ].item_link ) }, { false, true } )
end

function GreyingSpec:should_put_the_colours_back_when_switched_on_again()
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()
  frame.toggle( 1 )
  frame.toggle( 1 )

  local row = frame.reservations()[ 1 ]
  eq( is_grey( row.item_link ), false )
  eq( row.item_link, u.item_link( "Tsunami Talisman", TSUNAMI ) )
end

-- Greyed on the window, but still an epic in somebody's chat window: the shift-click gets the
-- link the client gave us, not ours with the colour taken out of it.
function GreyingSpec:should_keep_the_real_link_for_a_shift_click()
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()
  frame.toggle( 1 )

  eq( frame.reservations()[ 1 ].item_chat_link, u.item_link( "Tsunami Talisman", TSUNAMI ) )
end

function GreyingSpec:should_hand_over_no_separate_link_while_the_row_is_on()
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()

  eq( frame.reservations()[ 1 ].item_chat_link, nil )
end

-- Colour codes draw nothing, so greying a row cannot move a column.
function GreyingSpec:should_measure_a_greyed_row_the_same_as_any_other()
  local frame = window( { { TSUNAMI, "Psikutas" }, { ROBE, "Obszczymucha" } } )

  frame.show()
  local before = frame.model().widths
  local widths = { player = before.player, count = before.count, item = before.item, boss = before.boss }

  frame.toggle( 1 )

  eq( frame.model().widths, widths )
end

-- Switched off per player, not per item: taking Psikutas' roll away leaves Obszczymucha's alone.
function DisabledEntriesSpec:should_switch_off_one_players_entry_only()
  local frame = window( { { TSUNAMI, "Psikutas" }, { TSUNAMI, "Obszczymucha" } } )

  frame.show()
  frame.toggle( 1 ) -- Obszczymucha sorts first

  eq( frame.boxes(), { "off", "on" } )
end

-- The count is what the item column shows, so an item whose count changed sorts by the new one.
function DisabledEntriesSpec:should_sort_the_item_column_by_the_count_that_is_left()
  local frame = window( { { TSUNAMI, "Psikutas", 2 }, { TSUNAMI, "Obszczymucha", 2 } } )

  frame.show()
  frame.model().on_sort( "item" )
  eq( frame.rows()[ 1 ], { "Obszczymucha", "2x Tsunami Talisman", "Leotheras the Blind" } )

  frame.model().on_toggle_group_items( false )
  frame.toggle( 1 ) -- one of Obszczymucha's two
  frame.model().on_toggle_group_items( true )

  -- Obszczymucha is down to one roll, so Psikutas' two sort after them rather than before.
  eq( frame.rows(), {
    { "Obszczymucha", "Tsunami Talisman", "Leotheras the Blind" },
    { "Psikutas", "2x Tsunami Talisman", "Leotheras the Blind" }
  } )
end

SortSpec = {}

function SortSpec:should_order_by_player_then_boss_then_item_by_default()
  local frame = window( sorting_fixture )

  frame.show()

  eq( frame.rows(), {
    { "Obszczymucha", "2x Tsunami Talisman", "Leotheras the Blind" },
    { "Obszczymucha", "Mystery Trinket", "Trash" },
    { "Psikutas", "2x Fathomstone", "Hydross the Unstable" },
    { "Psikutas", "Robe of Hateful Echoes", "Hydross the Unstable" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" }
  } )
end

function SortSpec:should_sort_by_a_clicked_column_ascending()
  local frame = window( sorting_fixture )

  frame.show()
  frame.model().on_sort( "boss" )

  eq( frame.rows(), {
    { "Psikutas", "2x Fathomstone", "Hydross the Unstable" },
    { "Psikutas", "Robe of Hateful Echoes", "Hydross the Unstable" },
    { "Obszczymucha", "2x Tsunami Talisman", "Leotheras the Blind" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" },
    { "Obszczymucha", "Mystery Trinket", "Trash" }
  } )
end

-- The count is part of what the item column shows, so it orders the same item before the player
-- does: Psikutas' single roll comes ahead of Obszczymucha's two.
function SortSpec:should_sort_the_item_column_by_name_then_count()
  local frame = window( sorting_fixture )

  frame.show()
  frame.model().on_sort( "item" )

  eq( frame.rows(), {
    { "Psikutas", "2x Fathomstone", "Hydross the Unstable" },
    { "Obszczymucha", "Mystery Trinket", "Trash" },
    { "Psikutas", "Robe of Hateful Echoes", "Hydross the Unstable" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" },
    { "Obszczymucha", "2x Tsunami Talisman", "Leotheras the Blind" }
  } )
end

-- The count flips with the name: it belongs to the column, not to the tie-breaks.
function SortSpec:should_flip_the_count_with_the_item_name()
  local frame = window( sorting_fixture )

  frame.show()
  frame.model().on_sort( "item" )
  frame.model().on_sort( "item" )

  eq( frame.rows(), {
    { "Obszczymucha", "2x Tsunami Talisman", "Leotheras the Blind" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" },
    { "Psikutas", "Robe of Hateful Echoes", "Hydross the Unstable" },
    { "Obszczymucha", "Mystery Trinket", "Trash" },
    { "Psikutas", "2x Fathomstone", "Hydross the Unstable" }
  } )
end

-- Only the active column flips. The tie-breaks stay ascending.
function SortSpec:should_flip_the_active_column_when_clicked_again()
  local frame = window( sorting_fixture )

  frame.show()
  frame.model().on_sort( "player" )

  eq( frame.rows(), {
    { "Psikutas", "2x Fathomstone", "Hydross the Unstable" },
    { "Psikutas", "Robe of Hateful Echoes", "Hydross the Unstable" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" },
    { "Obszczymucha", "2x Tsunami Talisman", "Leotheras the Blind" },
    { "Obszczymucha", "Mystery Trinket", "Trash" }
  } )
end

-- The rolls column is gone, but a sort saved while it was there still names it.
function SortSpec:should_sort_by_player_when_the_saved_column_no_longer_exists()
  local frame = window( sorting_fixture )

  frame.db.sort_column = "rolls"
  frame.show()

  eq( frame.header().sort_column, "player" )
  eq( frame.rows()[ 1 ], { "Obszczymucha", "2x Tsunami Talisman", "Leotheras the Blind" } )
end

function SortSpec:should_tell_the_header_the_sort_state()
  local frame = window( sorting_fixture )

  frame.show()
  eq( { frame.header().sort_column, frame.header().sort_ascending }, { "player", true } )

  frame.model().on_sort( "boss" )
  eq( { frame.db.sort_column, frame.db.sort_ascending }, { "boss", true } )
  eq( { frame.header().sort_column, frame.header().sort_ascending }, { "boss", true } )

  frame.model().on_sort( "boss" )
  eq( { frame.db.sort_column, frame.db.sort_ascending }, { "boss", false } )
  eq( { frame.header().sort_column, frame.header().sort_ascending }, { "boss", false } )
end

EmptySpec = {}

function EmptySpec:should_say_so_when_there_is_nothing_to_list()
  local frame = window( {} )

  frame.show()

  eq( frame.lines( Transformer.row_type ), {} )
  eq( frame.lines( "text" )[ 1 ].value, "No soft-res entries." )
end

-- Nothing imported is not the same as nobody reserving: the group isn't listed as missing from a
-- list that doesn't exist.
function EmptySpec:should_not_list_the_group_when_there_is_nothing_imported()
  local frame = window( {} )

  frame.show()

  eq( frame.rows(), {} )
end

NotSoftRessingSpec = {}

function NotSoftRessingSpec:should_list_group_members_who_reserved_nothing()
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()

  eq( frame.rows(), {
    { "Obszczymucha", "Not soft-ressing", "-" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" }
  } )
end

function NotSoftRessingSpec:should_colour_them_by_class()
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()

  eq( frame.lines( Transformer.row_type )[ 1 ].player, m.colorize_player_by_class( "Obszczymucha", "Rogue" ) )
end

-- Everybody who reserved anything is elsewhere and the box is unticked, so only the group is left.
function NotSoftRessingSpec:should_list_the_whole_group_when_only_absent_players_reserved()
  local frame = window( { { TSUNAMI, "Absentee" } } )

  frame.show()

  eq( frame.rows(), {
    { "Obszczymucha", "Not soft-ressing", "-" },
    { "Psikutas", "Not soft-ressing", "-" }
  } )
  eq( frame.lines( "text" ), {} )
end

-- Matched case-insensitively, the way the roster finds players.
function NotSoftRessingSpec:should_not_list_a_member_whose_reservation_differs_in_case()
  local frame = window( { { TSUNAMI, "psikutas" }, { ROBE, "Obszczymucha" } } )

  frame.show()

  eq( #frame.reservations(), 2 )
  eq( #frame.lines( Transformer.row_type ), 2 )
end

-- Nothing to sort them by but the player, so they come first on the item column.
function NotSoftRessingSpec:should_sort_them_ahead_of_reservations_by_item()
  local frame = window( { { TSUNAMI, "Obszczymucha" } } )

  frame.show()
  frame.model().on_sort( "item" )

  eq( frame.rows(), {
    { "Psikutas", "Not soft-ressing", "-" },
    { "Obszczymucha", "Tsunami Talisman", "Leotheras the Blind" }
  } )
end

AnnounceMissingSpec = {}

function AnnounceMissingSpec:should_name_group_members_who_reserved_nothing()
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()
  frame.header().on_announce_missing()

  eq( frame.announced, { "Missing SR: Obszczymucha" } )
end

function AnnounceMissingSpec:should_name_them_alphabetically()
  local frame = window( { { TSUNAMI, "Absentee" } } )

  frame.show()
  frame.header().on_announce_missing()

  eq( frame.announced, { "Missing SR: Obszczymucha and Psikutas" } )
end

-- No callback is what hides the button.
function AnnounceMissingSpec:should_offer_nothing_when_everybody_reserved()
  local frame = window( { { TSUNAMI, "Psikutas" }, { ROBE, "Obszczymucha" } } )

  frame.show()

  eq( frame.header().on_announce_missing, nil )
end

function AnnounceMissingSpec:should_offer_nothing_when_there_is_nothing_imported()
  local frame = window( {} )

  frame.show()

  eq( frame.header().on_announce_missing, nil )
end

-- Switched off is still reserved: the list doesn't call them not soft-ressing, and neither does this.
function AnnounceMissingSpec:should_not_name_a_player_whose_reservations_are_all_switched_off()
  local frame = window( { { TSUNAMI, "Psikutas" }, { ROBE, "Obszczymucha" } } )

  frame.show()
  frame.toggle( 1 )
  frame.toggle( 2 )

  eq( frame.header().on_announce_missing, nil )
end

-- Nobody outside the group is named: telling the raid somebody who isn't in it is missing an SR
-- helps nobody, and the box is only about what the list shows.
function AnnounceMissingSpec:should_ignore_the_show_absent_box()
  local frame = window( { { TSUNAMI, "Psikutas" }, { ROBE, "Absentee" } } )

  frame.show()
  frame.header().on_toggle_absent( true )
  frame.header().on_announce_missing()

  eq( frame.announced, { "Missing SR: Obszczymucha" } )
end

BossSpec = {}

local boss_fixture = {
  { TSUNAMI, "Psikutas" },
  { UNCATALOGUED, "Psikutas" },
  { CORD, "Psikutas" },
  { ROBE, "Obszczymucha" }
}

-- Alphabetically Leotheras comes before The Lurker Below, which is killed first.
function BossSpec:should_sort_bosses_in_kill_order_with_trash_last()
  local frame = window( boss_fixture )

  frame.show()
  frame.model().on_sort( "boss" )

  eq( frame.rows(), {
    { "Obszczymucha", "Robe of Hateful Echoes", "Hydross the Unstable" },
    { "Psikutas", "Cord of Screaming Terrors", "The Lurker Below" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" },
    { "Psikutas", "Mystery Trinket", "Trash" }
  } )
end

function BossSpec:should_break_ties_in_kill_order_too()
  local frame = window( boss_fixture )

  frame.show()

  eq( frame.rows(), {
    { "Obszczymucha", "Robe of Hateful Echoes", "Hydross the Unstable" },
    { "Psikutas", "Cord of Screaming Terrors", "The Lurker Below" },
    { "Psikutas", "Tsunami Talisman", "Leotheras the Blind" },
    { "Psikutas", "Mystery Trinket", "Trash" }
  } )
end

function BossSpec:should_colour_a_boss_by_its_own_colour()
  local frame = window( boss_fixture )

  frame.show()
  frame.model().on_sort( "boss" )

  local rows = frame.lines( Transformer.row_type )
  eq( rows[ 1 ].boss, "|cff4fc3f7Hydross the Unstable|r" )
  eq( rows[ 2 ].boss, "|cff4db6acThe Lurker Below|r" )
  eq( rows[ 3 ].boss, "|cff9ccc65Leotheras the Blind|r" )
end

-- Fixed, not handed out per list: Leotheras is the same colour whether Hydross is on the list or not.
function BossSpec:should_keep_a_boss_colour_whatever_else_is_on_the_list()
  local alone = window( { { TSUNAMI, "Psikutas" } } )
  alone.show()

  local crowded = window( boss_fixture )
  crowded.show()

  eq( alone.reservations()[ 1 ].boss, "|cff9ccc65Leotheras the Blind|r" )
  eq( crowded.reservations()[ 3 ].boss, "|cff9ccc65Leotheras the Blind|r" )
end

function BossSpec:should_colour_a_boss_the_same_on_every_row()
  local frame = window( { { TSUNAMI, "Psikutas" }, { TSUNAMI, "Obszczymucha" } } )

  frame.show()

  local rows = frame.lines( Transformer.row_type )
  eq( rows[ 1 ].boss, rows[ 2 ].boss )
  eq( u.decolorize( rows[ 1 ].boss ), "Leotheras the Blind" )
end

-- A boss missing from the table gets a colour anyway, and the same one every time.
function BossSpec:should_give_a_boss_without_a_colour_a_steady_one()
  local find_boss = m.DropTable.find_boss
  m.DropTable.find_boss = function( item_id ) return item_id == UNCATALOGUED and "Mystery Boss" or find_boss( item_id ) end

  local first = window( { { UNCATALOGUED, "Psikutas" } } )
  first.show()
  local second = window( { { UNCATALOGUED, "Psikutas" } } )
  second.show()

  m.DropTable.find_boss = find_boss

  local boss = first.reservations()[ 1 ].boss
  eq( u.decolorize( boss ), "Mystery Boss" )
  eq( boss ~= m.colors.grey( "Mystery Boss" ), true )
  eq( second.reservations()[ 1 ].boss, boss )
end

-- The table is keyed by name, so a boss renamed in the drop table and not here would slip through to
-- the fallback without anything saying so.
function BossSpec:should_have_a_colour_for_every_boss_in_the_drop_table()
  local missing = {}

  for _, dungeon in pairs( m.DropTable.ids ) do
    for name in pairs( dungeon.bosses or {} ) do
      if not m.DropTable.non_bosses[ name ] and not SoftResListFrame.boss_colors[ name ] then
        table.insert( missing, name )
      end
    end
  end

  table.sort( missing )
  eq( missing, {} )
end

function BossSpec:should_grey_out_trash_and_the_dash()
  local frame = window( { { UNCATALOGUED, "Psikutas" } } )

  frame.show()

  local rows = frame.lines( Transformer.row_type )
  eq( rows[ 1 ].boss, m.colors.grey( "-" ) )
  eq( rows[ 2 ].boss, m.colors.grey( "Trash" ) )
end

WidthSpec = {}

-- Players are 12 and 8 characters, the widest item is "[Robe of Hateful Echoes]" and the widest
-- boss "Hydross the Unstable".
function WidthSpec:should_measure_each_column_by_its_widest_entry()
  local frame = window( sorting_fixture )

  frame.show()

  eq( frame.model().widths, { player = 12, count = 2, item = 24, boss = 20 } )
end

function WidthSpec:should_leave_no_room_for_a_count_nobody_has()
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()

  eq( frame.model().widths.count, 0 )
end

-- The note stands in for an item, so it is measured like one: 16 characters against the uncached
-- item's 11-character placeholder.
function WidthSpec:should_measure_the_note_for_a_player_who_reserved_nothing()
  local frame = window( { { UNCATALOGUED, "Psikutas" } }, false )

  frame.show()

  eq( frame.model().widths.item, 16 )
end

function WidthSpec:should_hand_the_same_widths_to_the_header_and_every_row()
  local frame = window( sorting_fixture )

  frame.show()

  local widths = frame.model().widths
  eq( frame.header().widths, widths )

  for _, row in ipairs( frame.lines( Transformer.row_type ) ) do
    eq( row.widths, widths )
  end
end

AdjustmentSpec = {}

function AdjustmentSpec:should_show_what_modifiers_add_after_the_item()
  bonuses = { Psikutas = { [ TSUNAMI ] = 30 } }
  local frame = window( { { TSUNAMI, "Psikutas" }, { FATHOMSTONE, "Psikutas" } } )

  frame.show()

  local rows = frame.reservations()
  eq( rows[ 1 ].adjustment, nil ) -- Fathomstone
  eq( rows[ 2 ].adjustment, m.colors.white( " +30" ) )
  bonuses = {}
end

function AdjustmentSpec:should_show_a_penalty_with_a_minus()
  bonuses = { Psikutas = { [ TSUNAMI ] = -5 } }
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()

  eq( frame.reservations()[ 1 ].adjustment, m.colors.white( " -5" ) )
  bonuses = {}
end

function AdjustmentSpec:should_ask_about_the_soft_res_round()
  asked_rounds = {}
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()

  eq( asked_rounds, { [ RollFor.Types.RollingStrategy.SoftResRoll ] = true } )
end

-- "[Tsunami Talisman]" is 18 characters and " +30" another 4.
function AdjustmentSpec:should_measure_the_item_column_with_the_adjustment()
  bonuses = { Psikutas = { [ TSUNAMI ] = 30 } }
  local frame = window( { { TSUNAMI, "Psikutas" } } )

  frame.show()

  eq( frame.model().widths.item, 22 )
  bonuses = {}
end

UncachedSpec = {}

function UncachedSpec:should_draw_a_placeholder_and_retry_in_a_second()
  local frame = window( { { TSUNAMI, "Psikutas" } }, false )

  frame.show()

  eq( frame.reservations()[ 1 ].item_link, m.colors.grey( "item:" .. TSUNAMI ) )
  eq( #frame.scheduled(), 1 )
  eq( frame.scheduled()[ 1 ].delay, 1 )
end

function UncachedSpec:should_give_up_after_three_retries()
  local frame = window( { { TSUNAMI, "Psikutas" } }, false )

  frame.show()

  for i = 1, 5 do
    local timer = frame.scheduled()[ i ]
    if timer then timer.callback() end
  end

  eq( #frame.scheduled(), 3 )
end

function UncachedSpec:should_draw_the_link_once_the_client_has_the_item()
  local frame = window( { { TSUNAMI, "Psikutas" } }, false )

  frame.show()
  item_cache( true )
  frame.scheduled()[ 1 ].callback()

  eq( frame.reservations()[ 1 ].item_link, u.item_link( "Tsunami Talisman", TSUNAMI ) )
  eq( #frame.scheduled(), 1 )
end

os.exit( lu.LuaUnit.run() )
