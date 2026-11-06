RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.SoftResPresentPlayersDecorator then return end

local M = {}

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

local filter = m.filter
local map = m.map
local clone = m.clone

-- I decorate given softres class with present players logic.
-- Example: "give me all players who soft-ressed and are in the group".
-- I also enrich the player data with class name.
-- The return annotation is deliberately absent: `GroupAwareSoftRes` is declared in core's
-- src/SoftRes.lua and stays there, and this addon does not redeclare core's types.
---@param group_roster GroupRoster
---@param softres SoftRes
function M.new( group_roster, softres )
  local f = group_roster.is_player_in_my_group
  local enrich_class = function( p )
    local player = group_roster.find_player( p.name )
    p.class = player and player.class
    return p
  end

  local function get( item_data )
    return map( filter( softres.get( item_data ), f, "name" ), enrich_class )
  end

  local function get_all_rollers()
    return map( filter( softres.get_all_rollers(), f, "name" ), enrich_class )
  end

  local decorator = clone( softres )
  decorator.get = get
  decorator.get_all_rollers = get_all_rollers

  return decorator
end

sr.SoftResPresentPlayersDecorator = M
return M
