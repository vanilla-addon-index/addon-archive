RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.SoftResDisabledEntriesDecorator then return end

local M = {}

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

-- I decorate given softres class with the list window's checkboxes.
-- Example: "give me players who soft-ressed, minus the rolls that have been switched off".
--
-- A player with some of their rolls off keeps the rest: two reservations with one switched off is
-- one roll, exactly as if the list had only said it once. A player with all of them off is
-- dropped, the same way SoftResAwardedLootDecorator drops one who already has the item -- so they
-- are not on the soft-res roll and go into the normal round instead.
--
-- This sits after the `unfiltered` tap on purpose. The list window reads that tap, and a window
-- that drew the filtered view would have no way to show you the entry you just switched off, let
-- alone a box to switch it back on.
---@param disabled_entries SoftResDisabledEntries
---@param softres SoftRes
function M.new( disabled_entries, softres )
  ---@param item_data ItemData
  local function get( item_data )
    local result = {}

    for _, roller in ipairs( softres.get( item_data ) ) do
      local rolls = roller.rolls or 1
      local enabled = rolls - disabled_entries.disabled_count( item_data.item_id, roller.name, rolls )

      if enabled > 0 then
        roller.rolls = enabled
        table.insert( result, roller )
      end
    end

    return result
  end

  ---@param player_name string
  ---@param item_data ItemData
  ---@return boolean
  local function has_an_enabled_roll( player_name, item_data )
    for _, roller in ipairs( get( item_data ) ) do
      if roller.name == player_name then return true end
    end

    return false
  end

  -- Asked without an item, the question is whether the player is on the list at all, so every item
  -- has to be looked at before the answer can be no.
  ---@param player_name string
  ---@param item_data ItemData?
  ---@return boolean
  local function is_player_softressing( player_name, item_data )
    if not softres.is_player_softressing( player_name, item_data ) then return false end
    if item_data then return has_an_enabled_roll( player_name, item_data ) end

    for _, data in ipairs( softres.get_items() ) do
      if has_an_enabled_roll( player_name, data ) then return true end
    end

    return false
  end

  local function get_all_rollers()
    return m.filter( softres.get_all_rollers(), function( roller )
      return is_player_softressing( roller.name )
    end )
  end

  local decorator = m.clone( softres )
  decorator.get = get
  decorator.get_all_rollers = get_all_rollers
  decorator.is_player_softressing = is_player_softressing

  return decorator
end

sr.SoftResDisabledEntriesDecorator = M
return M
