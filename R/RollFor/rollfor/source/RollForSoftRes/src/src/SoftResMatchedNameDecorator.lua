RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.SoftResMatchedNameDecorator then return end

local M = {}

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

local map = m.map

-- I decorate given softres class with matched name logic.
-- Some players make typos in SoftRes.it and then their names don't match
-- their in-game names. NameMatcher fixes that.
function M.new( name_matcher, softres )
  local f = function( player )
    player.name = name_matcher.get_matched_name( player.name ) or player.name
    return player
  end

  local function get( item_data )
    return map( softres.get( item_data ), f )
  end

  local function get_all_rollers()
    return map( softres.get_all_rollers(), f )
  end

  local function is_player_softressing( player_name, item_data )
    local name = name_matcher.get_softres_name( player_name ) or player_name
    return softres.is_player_softressing( name, item_data )
  end

  local decorator = m.clone( softres )
  decorator.get = get
  decorator.get_all_rollers = get_all_rollers
  decorator.is_player_softressing = is_player_softressing

  return decorator
end

sr.SoftResMatchedNameDecorator = M
return M
