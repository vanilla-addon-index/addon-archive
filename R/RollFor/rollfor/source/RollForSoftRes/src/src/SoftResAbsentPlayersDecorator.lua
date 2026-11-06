RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.SoftResAbsentPlayersDecorator then return end

local M = {}

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

local filter = m.filter
local negate = m.negate
local clone = m.clone

-- I decorate given softres class with absent players logic.
-- Example: "give me all players who soft-ressed but are not in the group".
function M.new( group_roster, softres )
  local f = negate( group_roster.is_player_in_my_group )

  local function get( item_data )
    return filter( softres.get( item_data ), f, "name" )
  end

  local function get_all_rollers()
    return filter( softres.get_all_rollers(), f, "name" )
  end

  local decorator = clone( softres )
  decorator.get = get
  decorator.get_all_rollers = get_all_rollers

  return decorator
end

sr.SoftResAbsentPlayersDecorator = M
return M
