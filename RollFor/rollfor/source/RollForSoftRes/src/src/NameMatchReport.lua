RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.NameMatchReport then return end

local M = {}

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

local hl = m.colors.hl
local grey = m.colors.grey
local red = m.colors.red
local p = m.pretty_print

function M.report( name_matcher )
  local auto_matched, auto_not_matched, manually_matched = name_matcher.get_matches()

  if manually_matched then
    for _, match in pairs( manually_matched ) do
      p( string.format( "%s is manually matched with %s.", hl( match.softres_name ), hl( match.matched_name ) ), grey )
    end
  end

  for _, match in pairs( auto_matched ) do
    p( string.format( "%s is auto-matched with %s.", hl( match.softres_name ), hl( match.matched_name ) ), grey )
  end

  for _, match in pairs( auto_not_matched ) do
    p( string.format( "%s could not be auto-matched. Top candidate: %s.", hl( match.softres_name ), hl( match.matched_name ) ), red )
  end
end

sr.NameMatchReport = M
return M
