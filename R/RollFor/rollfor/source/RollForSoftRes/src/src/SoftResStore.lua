RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.SoftResStore then return end

local M = {}

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

local keys = m.keys

-- The soft-res store: what everybody reserved, and what is hard-ressed.
--
-- This was `SoftRes.new`'s body in core. What core kept is the *interface* -- the six read
-- methods, plus the null object it falls back to when no source is installed -- and what
-- came here is the only implementation of it that knows how a list is stored. `import`,
-- `clear` and `persist` are on top of those six: they are the source's own, and nothing in
-- core calls them.
---@param db table -- ctx.db( "store" )
function M.new( db )
  ---@type SoftResData
  local softres_data = {}
  local hardres_data = {}

  -- `provider_id` is which decoder turned this string into a list. It is saved with the
  -- string because login re-imports it, and the dropdown's current selection is not
  -- necessarily what produced the list on disk -- switching provider without importing
  -- changes nothing, so the two are separate facts.
  ---@param data string?
  ---@param provider_id string?
  local function persist( data, provider_id )
    if data ~= nil then
      db.import_timestamp = m.lua.time()
      db.provider = provider_id
    else
      db.import_timestamp = nil
      db.provider = nil
    end

    db.data = data
  end

  local function clear( report )
    if m.count_elements( softres_data ) == 0 then return end
    softres_data = {}
    persist( nil )
    if report then m.pretty_print( "Cleared soft-res data." ) end
  end

  local function get( item_data )
    local item_id = item_data.item_id
    return softres_data[ item_id ] and m.clone( softres_data[ item_id ].rollers ) or {}
  end

  local function get_all_rollers()
    local roller_name_map = {}

    for _, item in pairs( softres_data ) do
      for _, roller in pairs( item.rollers or {} ) do
        roller_name_map[ roller.name ] = roller
      end
    end

    local result = {}

    for _, roller in pairs( roller_name_map ) do
      table.insert( result, roller )
    end

    return result
  end

  local function find_roller( player_name, data )
    for _, player in ipairs( data ) do
      if player.name == player_name then return player end
    end
  end

  local function is_player_softressing( player_name, item_data )
    local item_id = item_data and item_data.item_id
    if item_id and not softres_data[ item_id ] then return false end

    if item_id then
      local item = softres_data[ item_id ]
      local player = item and find_roller( player_name, item.rollers )
      if player and player.name == player_name then return true end

      return false
    end

    for _, item in pairs( softres_data ) do
      local roller = find_roller( player_name, item.rollers )
      if roller and roller.name == player_name then return true end
    end

    return false
  end

  local function sort_players()
    for _, item in pairs( softres_data ) do
      if item.rollers then
        table.sort( item.rollers, function( left, right ) return left.name < right.name end )
      end
    end
  end

  local function import( data )
    clear()
    if not data then return end

    softres_data, hardres_data = sr.SoftResDataTransformer.transform( data )
    sort_players()
  end

  -- When the current list was imported. The store owns it -- persist writes it and clear
  -- wipes it -- so anything that wants to know how old the data is asks here rather than
  -- reading the db behind the store's back.
  ---@return number?
  local function get_import_timestamp()
    return db.import_timestamp
  end

  -- Which provider decoded the list currently held. Nil until something is imported, and
  -- the only honest answer to "where did this data come from" -- the dropdown's selection
  -- is what the *next* import will use, not what this one did.
  ---@return string?
  local function get_provider()
    return db.provider
  end

  local function get_items()
    local result = {}

    for k, _ in pairs( softres_data ) do
      table.insert( result, m.SoftRes.softres_item_data( k, 1 ) )
    end

    return result
  end

  local function get_hr_item_ids()
    return keys( hardres_data )
  end

  local function is_item_hardressed( item_id )
    return hardres_data[ item_id ] and true or false
  end

  return {
    get = get,
    get_all_rollers = get_all_rollers,
    is_player_softressing = is_player_softressing,
    get_items = get_items,
    get_hr_item_ids = get_hr_item_ids,
    is_item_hardressed = is_item_hardressed,
    get_import_timestamp = get_import_timestamp,
    get_provider = get_provider,
    import = import,
    clear = clear,
    persist = persist
  }
end

sr.SoftResStore = M
return M
