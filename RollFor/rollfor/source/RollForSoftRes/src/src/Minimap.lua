RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.Minimap then return end

local M = {}

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

-- This addon's contribution to RollFor's minimap button.
--
-- The button is core's and there is only one of them, so what an extension registers is a
-- *contribution*: the commands it wants listed in the tooltip, a hint line, and a status
-- callback returning a colour and some lines. Core takes the highest severity across every
-- contribution and paints that. Read at render time rather than at construction, because
-- extensions register after the button exists.
--
-- Same commands and colour mapping as core's old soft-res contribution.
---@param softres_check table
---@return MinimapContribution
function M.new( softres_check )
  local white, green, red, hl = m.colors.white, m.colors.green, m.colors.red, m.colors.hl

  local function status()
    local ResultType = softres_check.ResultType
    local result, players = softres_check.check_softres( true )
    local ColorType = m.MinimapButton.ColorType

    if result == ResultType.NoItemsFound then
      return { color = ColorType.White }
    elseif result == ResultType.SomeoneIsNotSoftRessing then
      local lines = { white( "Missing softres:" ) }

      for _, player in pairs( players ) do
        table.insert( lines, m.colorize_player_by_class( player.name, player.class ) )
      end

      return { color = ColorType.Orange, lines = lines }
    elseif result == ResultType.FoundOutdatedData then
      return {
        color = ColorType.Red,
        lines = { white( "Softres status:" ), red( "Found outdated softres data!" ) }
      }
    end

    return {
      color = ColorType.Green,
      lines = { string.format( "%s %s", white( "Softres status:" ), green( "OK" ) ) }
    }
  end

  return {
    commands = {
      { cmd = "/sr", description = "manage softres" },
      { cmd = "/sro", description = "fix player softres name" },
      { cmd = "/src", description = "check softres status" },
      { cmd = "/srs", description = "show softres items" }
    },
    hint = string.format( "%s to manage softres.\n%s or %s + %s to show soft-ressing players.",
      hl( "Right click" ), hl( "Shift" ), hl( "alt" ), hl( "right click" ) ),
    status = status
  }
end

sr.Minimap = M
return M
