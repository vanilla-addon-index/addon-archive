RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.SoftResDisabledEntries then return end

local M = {}

-- Which soft-res reservations have been switched off.
--
-- An imported list is what a website says people reserved. It is not always what the raid agreed
-- to, and the master looter has no way to argue with a spreadsheet -- so every entry on the list
-- window carries a checkbox, and an entry switched off here does not count. The player loses that
-- roll, and a player whose every roll on an item is off is not soft-ressing it at all: they roll
-- in the normal round like anybody else.
--
-- Entries are keyed by the name on the imported document rather than the in-game name the rest of
-- RollFor knows a player by. A typo matched up later with /sro then moves the player's switches
-- with them instead of orphaning them. Callers pass in-game names and this maps them, so nothing
-- outside has to know the two differ.
--
-- Within one player's reservations of one item a switch belongs to an ordinal -- the first roll,
-- the second -- rather than to a count. Unticking the second of three rows therefore leaves the
-- ticks on the first and third where the user put them; a count would slide them up.

---@class SoftResDisabledEntries
---@field disabled_count fun( item_id: ItemId, player_name: string, rolls: number ): number
---@field is_disabled fun( item_id: ItemId, player_name: string, ordinal: number ): boolean
---@field set fun( item_id: ItemId, player_name: string, ordinal: number, enabled: boolean )
---@field set_all fun( item_id: ItemId, player_name: string, rolls: number, enabled: boolean )
---@field clear fun()

---@param db table -- ctx.db( "disabled_entries" )
---@param name_matcher table -- anything with get_softres_name( matched_name ): string?
---@return SoftResDisabledEntries
function M.new( db, name_matcher )
  db.entries = db.entries or {}

  -- The name the reservation was imported under. Nothing is written until something is actually
  -- switched off, so a list nobody has touched leaves no saved variables behind at all.
  ---@param player_name string -- in-game
  ---@return string
  local function key( player_name )
    return name_matcher.get_softres_name( player_name ) or player_name
  end

  ---@return table<number, boolean>? -- the ordinals that are off, or nil when none are
  local function switches( item_id, player_name )
    local item = db.entries[ item_id ]
    return item and item[ key( player_name ) ]
  end

  -- Only the ordinals the player actually has. An import that shortened somebody's reservations
  -- leaves the switches above the new count on disk, where they mean nothing and cost nothing --
  -- and would mean the right thing again if the longer list came back.
  ---@param item_id ItemId
  ---@param player_name string
  ---@param rolls number -- how many rolls the player has on this item
  ---@return number
  local function disabled_count( item_id, player_name, rolls )
    local off = switches( item_id, player_name )
    if not off then return 0 end

    local result = 0

    for ordinal = 1, rolls do
      if off[ ordinal ] then result = result + 1 end
    end

    return result
  end

  ---@param item_id ItemId
  ---@param player_name string
  ---@param ordinal number
  ---@return boolean
  local function is_disabled( item_id, player_name, ordinal )
    local off = switches( item_id, player_name )
    return off and off[ ordinal ] == true or false
  end

  -- Empty tables are pruned on the way back up rather than left behind: this is a saved variable,
  -- and a raid's worth of items every one of which remembers that nothing is switched off is a
  -- file that only ever grows.
  ---@param item_id ItemId
  ---@param player_name string
  ---@param ordinal number
  ---@param enabled boolean
  local function set( item_id, player_name, ordinal, enabled )
    local name = key( player_name )

    if enabled then
      local item = db.entries[ item_id ]
      local off = item and item[ name ]
      if not off then return end

      off[ ordinal ] = nil

      if not next( off ) then item[ name ] = nil end
      if not next( item ) then db.entries[ item_id ] = nil end

      return
    end

    db.entries[ item_id ] = db.entries[ item_id ] or {}
    db.entries[ item_id ][ name ] = db.entries[ item_id ][ name ] or {}
    db.entries[ item_id ][ name ][ ordinal ] = true
  end

  ---@param item_id ItemId
  ---@param player_name string
  ---@param rolls number
  ---@param enabled boolean
  local function set_all( item_id, player_name, rolls, enabled )
    for ordinal = 1, rolls do
      set( item_id, player_name, ordinal, enabled )
    end
  end

  -- Everything back on. What a fresh import means: the list that just arrived is the raid's
  -- agreement now, and the switches belonged to the one before it.
  local function clear()
    db.entries = {}
  end

  return {
    disabled_count = disabled_count,
    is_disabled = is_disabled,
    set = set,
    set_all = set_all,
    clear = clear
  }
end

sr.SoftResDisabledEntries = M
return M
