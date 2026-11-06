RollForGargul = RollForGargul or {}
local g = RollForGargul

-- The Gargul bridge, as a RollFor extension.
--
-- Gargul is another loot addon with its own addon-channel protocol. This speaks it: it answers
-- Gargul's request for soft-res data, broadcasts the data when a soft-res import happens, and
-- announces RollFor's roll-offs so a Gargul user sees them in their own UI.
--
-- An extension because it is 200 lines of core speaking somebody else's protocol, pinned to
-- that addon's version numbers, and nothing in core depends on it. The protocol constants and
-- the version floor are the whole reason: they change when Gargul changes, which has nothing
-- to do with RollFor.
--
-- The registration below runs at file scope: the TOC declares `## Dependencies: RollFor`,
-- which makes the client load RollFor first and refuse to load this addon without it.

local M = {}

---@param ctx ExtensionContext
local function on_ready( ctx )
  -- Nothing in on_enable: this addon declares no settings, no loot handlers and no commands.
  -- It subscribes to things that only exist once core has built them, which is on_ready.
  g.gargul_bridge = g.GargulBridge.new(
    ctx.player_info,
    ctx.get( "roll_controller" ),
    ctx.config,
    ctx.softres_source.get_import_string,
    ctx.get( "softres" )
  )

  -- LibStub or one of the three libraries it wants is missing, so there is nothing to talk to
  -- Gargul with. GargulBridge says so by returning nothing rather than by erroring.
  if not g.gargul_bridge then return end

  ctx.event_bus.subscribe( "softres_imported", function( event )
    -- Only on an interactive (GUI) import -- not on the login reload re-importing the saved
    -- string, which would otherwise re-broadcast to Gargul on every login.
    if not event.interactive then return end

    g.gargul_bridge.broadcast_softres( event.raw )
  end )
end

function M.register()
  if not RollFor.Extensions then
    RollFor.warn( "Unsupported RollFor version.", "RollForGargul" )
    return
  end

  return RollFor.Extensions.register( {
    name = "gargul",
    title = "Gargul",
    -- softres_source.get_import_string arrived with API 5; the rest of what this reads is older.
    api_version = 5,
    default_enabled = true,
    on_ready = on_ready,

    -- Core creates the canvas and asks us to fill it in. Declared here rather than from
    -- on_ready because a disabled extension still needs its page -- that page is where the
    -- switch to turn it back on lives, and on_ready does not run when we are off.
    options_page = function( ctx, parent ) return g.OptionsPage.new( ctx, parent ) end
  } )
end

M.on_ready = on_ready

g.main = M

-- Registration happens on load, which is the whole point: by the time RollFor builds its
-- components on PLAYER_LOGIN, the registry already knows about us. Tests that want a clean
-- registry clear it and call M.register() again.
M.register()

return M
