RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.SoftResListFrame then return end

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

local M = {}

-- Every soft-res reservation, one row per player per item, and a row for everybody in the group
-- who reserved nothing -- the same people /src names.
--
-- ListPopup owns the window itself. What is left here is the list: read through the unfiltered
-- tap, so names are matched and awarded items are gone, but players not in the group are still
-- there for the checkbox to show. Whether they are shown and how the list is sorted is this
-- window's own state, kept in its db next to the position.

-- The soft blue the round-robin queue and the pending loot windows are edged in, rather than
-- ListPopup's default red.
local border_color = { 0.351, 0.553, 1.0, 0.3 }

-- Clearance above the checkbox: ListPopup's default 16, plus 5. The popup's height doesn't count
-- it, so SoftResListContentTransformer's bottom gap has to grow by the same to keep the bottom
-- where it was.
local top_padding = 21

-- How many rows the window shows before it scrolls: a user setting, registered in on_enable and
-- drawn as a slider on the options page, both of which read these. The range is core's master loot
-- frame rows' with a higher ceiling, since a raid's reservations run to a lot more than a loot
-- window's items.
M.rows_setting = { key = "softres_list_rows", default = 15, min = 5, max = 30 }

-- How many times in a row the list asks the client again for items it doesn't have yet.
local max_item_retries = 3

-- The default order, and what breaks ties in any other: player and item together are unique while
-- the list is grouped, so the order is total. Ungrouped, a player's repeated reservations of one
-- item are identical rows, and which of them comes first makes no difference.
local tie_breaks = { "player", "boss", "item" }

-- What the window can be sorted by, and the keys each column sorts on, in order. The item column
-- shows the roll count in front of the link, so it sorts on the count after the name. A column
-- read from the db that isn't one of these -- the rolls column is gone, but a saved sort can still
-- name it -- sorts by player instead.
local sort_keys = {
  player = { "player" },
  item = { "item", "rolls" },
  boss = { "boss" }
}

-- What a group member with no reservations has in the item and boss columns.
local not_softressing = "Not soft-ressing"
local no_value = "-"

-- What an item no boss in the drop table drops is listed under.
local trash = "Trash"

-- Every boss in the drop table has its own colour, picked to suit the boss where one suggests
-- itself -- ice blue for Rage Winterchill, fel green for Illidan -- and so that bosses killed one
-- after the other never share one. Fixed, so a boss is the same colour on every list. Trash and the
-- dash are grey: they are not bosses.
--
-- Published so a spec can check every boss in the drop table is here: a boss renamed there and not
-- here would quietly fall through to a fallback colour.
M.boss_colors = {
  -- Karazhan
  [ "Rokad the Ravager" ] = "a1887f",
  [ "Shadikith the Glider" ] = "9575cd",
  [ "Hyakiss the Lurker" ] = "aed581",
  [ "Attumen the Huntsman" ] = "90a4ae",
  [ "Moroes" ] = "ffca28",
  [ "Maiden of Virtue" ] = "ffe0b2",
  [ "The Wizard of Oz" ] = "66bb6a",
  [ "The Big Bad Wolf" ] = "e57373",
  [ "Romulo and Julianne" ] = "f06292",
  [ "The Curator" ] = "7986cb",
  [ "Terestian Illhoof" ] = "9ccc65",
  [ "Shade of Aran" ] = "4fc3f7",
  [ "Netherspite" ] = "ba68c8",
  [ "Chess Event" ] = "e0e0e0",
  [ "Prince Malchezaar" ] = "ef5350",
  [ "Nightbane" ] = "ffb74d",

  -- Gruul's Lair
  [ "High King Maulgar" ] = "ff8a65",
  [ "Gruul the Dragonkiller" ] = "bcaaa4",

  -- Magtheridon's Lair
  [ "Magtheridon" ] = "ef5350",

  -- Serpentshrine Cavern
  [ "Hydross the Unstable" ] = "4fc3f7",
  [ "The Lurker Below" ] = "4db6ac",
  [ "Leotheras the Blind" ] = "9ccc65",
  [ "Fathom-Lord Karathress" ] = "7986cb",
  [ "Morogrim Tidewalker" ] = "81c784",
  [ "Lady Vashj" ] = "ba68c8",

  -- Tempest Keep
  [ "Al'ar" ] = "ffb74d",
  [ "Void Reaver" ] = "7986cb",
  [ "High Astromancer Solarian" ] = "4fc3f7",
  [ "Kael'thas Sunstrider" ] = "ffd54f",
  [ "Legendaries" ] = "ff8a65",

  -- Mount Hyjal
  [ "Rage Winterchill" ] = "4fc3f7",
  [ "Anetheron" ] = "81c784",
  [ "Kaz'rogal" ] = "ffd54f",
  [ "Azgalor" ] = "ba68c8",
  [ "Archimonde" ] = "e57373",

  -- Black Temple
  [ "High Warlord Naj'entus" ] = "4db6ac",
  [ "Supremus" ] = "ff8a65",
  [ "Shade of Akama" ] = "9575cd",
  [ "Gurtogg Bloodboil" ] = "e57373",
  [ "Reliquary of the Lost" ] = "90a4ae",
  [ "Teron Gorefiend" ] = "aed581",
  [ "Mother Shahraz" ] = "f06292",
  [ "The Illidari Council" ] = "ffd54f",
  [ "Illidan Stormrage" ] = "66bb6a",

  -- Zul'Aman
  [ "Akil'zon" ] = "4fc3f7",
  [ "Nalorakk" ] = "a1887f",
  [ "Jan'alai" ] = "ffb74d",
  [ "Halazzi" ] = "ffd54f",
  [ "Hex Lord Malacrass" ] = "ba68c8",
  [ "Zul'jin" ] = "e57373",
  [ "Timed Chest" ] = "fff59d",

  -- Sunwell Plateau
  [ "Kalecgos" ] = "4fc3f7",
  [ "Brutallus" ] = "e57373",
  [ "Felmyst" ] = "9ccc65",
  [ "Eredar Twins" ] = "ba68c8",
  [ "M'uru" ] = "7986cb",
  [ "Kil'jaeden" ] = "66bb6a"
}

-- For a boss not in the table above. Picked from the boss's name rather than at random, so it looks
-- arbitrary but is the same colour on every redraw and after a reload.
local fallback_boss_colors = {
  "4fc3f7", "81c784", "ffd54f", "ba68c8", "e57373", "4db6ac",
  "f06292", "aed581", "7986cb", "ffb74d", "a1887f", "90a4ae"
}

-- What a switched-off row is drawn in: grey throughout, the item's quality colour included, so a
-- row that does not count reads as one without having to be read.
--
-- A shade darker than m.colors.grey, which is what the dash and the "Not soft-ressing" note are
-- set in. Those are ordinary things the list has nothing to say about; this is a row that has been
-- struck out, and it sits below them rather than alongside.
local grey_code = "|cff656565"

-- Every colour already in the text -- a class colour, an item's quality, a boss's own -- replaced
-- rather than wrapped. A wrapping code would lose to the inner one and change nothing.
---@param text string
---@return string
local function greyed( text )
  local result, replaced = string.gsub( text, "|c%x%x%x%x%x%x%x%x", grey_code )

  return replaced > 0 and result or string.format( "%s%s|r", grey_code, text )
end

---@param boss string?
---@return string
local function colorize_boss( boss )
  if not boss then return m.colors.grey( no_value ) end
  if boss == trash then return m.colors.grey( trash ) end

  local hex = M.boss_colors[ boss ]

  if not hex then
    local hash = 0

    for i = 1, string.len( boss ) do
      hash = (hash * 31 + string.byte( boss, i )) % 2147483647
    end

    hex = fallback_boss_colors[ hash % #fallback_boss_colors + 1 ]
  end

  return string.format( "|cff%s%s|r", hex, boss )
end

-- Each boss's place in the kill order, as a string that sorts that way: the raid's order, then the
-- boss's, then the name, for the Karazhan Opera bosses that share a place. Trash sorts after every
-- boss and a player with no reservations before them, the same way an empty item name does.
local boss_sort_keys

---@param boss string
---@return string
local function boss_sort_key( boss )
  if boss == trash then return "~" end

  if not boss_sort_keys then
    boss_sort_keys = {}

    for _, dungeon in pairs( m.DropTable.ids ) do
      for name, entry in pairs( dungeon.bosses or {} ) do
        boss_sort_keys[ name ] = string.format( "%03d%03d%s", dungeon.order or 0, entry.order or 0, name )
      end
    end
  end

  return boss_sort_keys[ boss ] or string.format( "999999%s", boss )
end

---@param column SoftResListColumn
---@param ascending boolean -- the direction of the active column's keys only
local function comparator( column, ascending )
  local keys = {}

  for _, key in ipairs( sort_keys[ column ] ) do
    table.insert( keys, key )
  end

  local column_key_count = #keys

  for _, key in ipairs( tie_breaks ) do
    if key ~= column then table.insert( keys, key ) end
  end

  return function( a, b )
    for i, key in ipairs( keys ) do
      local left, right = a.keys[ key ], b.keys[ key ]

      if left ~= right then
        if i <= column_key_count and not ascending then return left > right end
        return left < right
      end
    end

    return false
  end
end

---@param popup_builder PopupBuilder
---@param db table -- ctx.db( "list_frame" )
---@param content_transformer SoftResListContentTransformer
---@param softres GroupAwareSoftRes -- the unfiltered tap
---@param group_roster GroupRoster
---@param ace_timer AceTimer
---@param text_width fun( text: string ): number -- how wide text draws in the list's font
---@param max_rows fun(): number -- rows shown before the list scrolls; read on every redraw
---@param preview fun( player: RollingPlayer, item: Item, strategy: RollingStrategyType ): number? -- ctx.roll_modifier.preview
---@param disabled_entries SoftResDisabledEntries -- which reservations the checkboxes have switched off
---@param chat Chat -- where the Announce missing button says who they are
function M.new( popup_builder, db, content_transformer, softres, group_roster, ace_timer, text_width, max_rows, preview,
                disabled_entries, chat )
  ---@type ListPopup
  local list

  local item_retries = 0

  ---@return SoftResListFrameData
  local function content()
    local sort_column = sort_keys[ db.sort_column ] and db.sort_column or "player"
    local sort_ascending = db.sort_ascending ~= false
    -- Grouped unless the box was unticked: a db that has never seen the checkbox is the default.
    local group_items = db.group_items ~= false
    local entries = {}
    local missing_link = false
    local items = softres.get_items()

    -- Asked for once rather than per reservation: find_player walks the whole roster every call.
    local group = {}

    for _, player in ipairs( group_roster.get_all_players_in_my_group() ) do
      group[ string.lower( player.name ) ] = player
    end

    local softressing = {}

    for _, item_data in ipairs( items ) do
      local item_id = item_data.item_id
      local link = m.fetch_item_link( item_id )
      local boss = m.DropTable.find_boss( item_id ) or trash
      local item = m.ItemUtils.make_item( item_id, link and m.ItemUtils.get_item_name( link ) or tostring( item_id ), link )

      -- Asked for now and drawn as its id until the client has it; the retry below redraws.
      if not link then
        m.set_game_tooltip_with_item_id( item_id )
        missing_link = true
      end

      for _, roller in ipairs( softres.get( item_data ) ) do
        local player = group[ string.lower( roller.name ) ]
        softressing[ string.lower( roller.name ) ] = true

        if player or db.show_absent then
          -- What modifiers will add to the player's rolls on this item, drawn after the link.
          -- The space is part of the text, so measuring link and adjustment together measures
          -- the gap as well.
          local adjustment = preview( roller, item, m.Types.RollingStrategy.SoftResRoll )

          -- Bound rather than read off `roller` inside the callbacks below: the roster is walked
          -- again on every redraw, so the table these close over is gone by the time one is
          -- clicked.
          local name = roller.name
          local rolls = math.max( roller.rolls or 1, 1 )
          local disabled = disabled_entries.disabled_count( item_id, name, rolls )

          -- Grouped, the extra rolls are a 2x in front of one row, and the count is what is left
          -- on -- two reservations with one switched off read as one roll, because that is what
          -- the player has. Ungrouped, the rolls are the rows themselves, one per entry on the
          -- imported list, each with a box of its own and none of them needing the count gutter.
          local row_count = group_items and 1 or rolls
          local enabled_rolls = rolls - disabled

          for ordinal = 1, row_count do
            local enabled

            if group_items then
              enabled = disabled == 0 and "on" or enabled_rolls == 0 and "off" or "partial"
            else
              enabled = disabled_entries.is_disabled( item_id, name, ordinal ) and "off" or "on"
            end

            -- Only a row with nothing left on it. A partial one still has rolls that count, and
            -- greying it would say otherwise.
            local off = enabled == "off"

            -- The count is the rolls still on, so switching one of two off drops the 2x. A row
            -- with nothing left on shows what the list said instead: greyed out and worth
            -- nothing, but still visibly a double reservation rather than a single one.
            local shown_rolls = off and rolls or enabled_rolls

            ---@param text string?
            ---@return string?
            local function shade( text )
              if not text or not off then return text end

              return greyed( text )
            end

            table.insert( entries, {
              row = {
                player = shade( player and m.colorize_player_by_class( player.name, player.class ) or
                  m.colors.red( roller.name ) ),
                item_link = shade( link or m.colors.grey( "item:" .. item_id ) ),
                item_tooltip_link = link and m.ItemUtils.get_tooltip_link( link ),
                -- The real link, kept back for the shift-click even while the row draws a grey
                -- one: what is greyed out here is still an epic in somebody's chat window.
                item_chat_link = off and link or nil,
                count = group_items and shown_rolls > 1 and shade( string.format( "%dx", shown_rolls ) ) or nil,
                adjustment = shade( adjustment and
                  m.colors.white( string.format( " %s%d", adjustment > 0 and "+" or "-", math.abs( adjustment ) ) ) or nil ),
                enabled = enabled,
                -- A ticked box switches off, and anything else -- unticked, or the grey that says
                -- only some of a grouped row is on -- switches on. That is the usual way round for
                -- a box with a third state: a partial one fills before it empties.
                on_toggle_enabled = group_items and function()
                  disabled_entries.set_all( item_id, name, rolls, enabled ~= "on" )
                  list.refresh_if_visible()
                end or function()
                  disabled_entries.set( item_id, name, ordinal, enabled == "off" )
                  list.refresh_if_visible()
                end
              },
              boss = boss,
              disabled = off,
              keys = {
                player = roller.name,
                item = link and m.ItemUtils.get_item_name( link ) or tostring( item_id ),
                -- What the column shows, which grouped is the rolls still on -- or, for a row
                -- with none left, the ones the list said it had.
                rolls = group_items and shown_rolls or 1,
                boss = boss_sort_key( boss )
              }
            } )
          end
        end
      end
    end

    -- Who the Announce missing button names, alphabetically so the message reads the same however
    -- the roster came back.
    local missing = {}

    -- Only once there is a list to be missing from. Before an import everybody would be on it.
    if #items > 0 then
      for key, player in pairs( group ) do
        if not softressing[ key ] then
          table.insert( missing, player.name )
          table.insert( entries, {
            row = {
              player = m.colorize_player_by_class( player.name, player.class ),
              item_link = m.colors.grey( not_softressing )
            },
            keys = { player = player.name, item = "", rolls = 0, boss = "" }
          } )
        end
      end
    end

    if not missing_link then
      item_retries = 0
    elseif item_retries < max_item_retries then
      item_retries = item_retries + 1
      ace_timer.ScheduleTimer( M, list.refresh_if_visible, 1 )
    end

    table.sort( entries, comparator( sort_column, sort_ascending ) )

    -- Measured over the whole list rather than the rows on screen, so scrolling never resizes a
    -- column.
    ---@type SoftResListWidths
    local widths = { player = 0, count = 0, item = 0, boss = 0 }

    local function widen( key, text )
      if not text then return end

      local width = text_width( text )
      if width > widths[ key ] then widths[ key ] = width end
    end

    local rows = {}

    for _, entry in ipairs( entries ) do
      local row = entry.row
      row.boss = colorize_boss( entry.boss )
      if entry.disabled then row.boss = greyed( row.boss ) end

      widen( "player", row.player )
      widen( "count", row.count )
      widen( "item", row.adjustment and row.item_link .. row.adjustment or row.item_link )
      widen( "boss", row.boss )

      table.insert( rows, row )
    end

    table.sort( missing )

    return {
      -- nil when there is nobody to name, which is what hides the button.
      on_announce_missing = #missing > 0 and function()
        for _, message in ipairs( m.split_message( "Missing SR: ", missing ) ) do
          chat.announce( message )
        end
      end or nil,
      show_absent = db.show_absent == true,
      on_toggle_absent = function( checked )
        db.show_absent = checked
        list.refresh_if_visible()
      end,
      group_items = group_items,
      on_toggle_group_items = function( checked )
        db.group_items = checked
        list.refresh_if_visible()
      end,
      sort_column = sort_column,
      sort_ascending = sort_ascending,
      ---@param column SoftResListColumn
      on_sort = function( column )
        if column == sort_column then
          db.sort_ascending = not sort_ascending
        else
          db.sort_column = column
          db.sort_ascending = true
        end

        list.refresh_if_visible()
      end,
      rows = rows,
      widths = widths
    }
  end

  list = m.ListPopup.new( {
    name = "RollForSoftResListFrame",
    db = db,
    popup_builder = popup_builder,
    content_transformer = content_transformer,
    content = content,
    row_type = sr.SoftResListContentTransformer.row_type,
    header_type = sr.SoftResListContentTransformer.header_type,
    close_button = true,
    border_color = border_color,
    top_padding = top_padding,
    esc = true,
    max_rows = max_rows
  } )

  return {
    show = list.show,
    hide = list.hide,
    toggle = list.toggle,
    refresh_if_visible = list.refresh_if_visible,
    get_frame = list.get_frame
  }
end

sr.SoftResListFrame = M
return M
