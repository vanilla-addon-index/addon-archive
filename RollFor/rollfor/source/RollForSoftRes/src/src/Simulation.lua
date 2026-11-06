RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.Simulation then return end

local M = {}

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

-- What answers `/rfsetup`.
--
-- Core's RollSimulator keeps the argument parsing, the fake group, the preview and the
-- roll injection; what it no longer has is anywhere to put the reservations it invented,
-- so it emits `simulation_started` and whoever owns the soft-res source turns that into
-- data. That is this. Moved out of RollSimulator's old setup()/fake_group() bodies via
-- core's temporary `simulation_started` subscriber, not rewritten.
---@param ctx ExtensionContext
---@param store table -- the extension's SoftResStore
---@param softres_gui table
function M.new( ctx, store, softres_gui )
  local function on_simulation_started( event )
    local soft_reserves = {}

    for _, reservation in ipairs( event.reservations ) do
      -- One entry per roll: duplicates in a raidres import are what grant extra rolls.
      local items = {}
      for _ = 1, reservation.rolls do
        table.insert( items, { id = event.item.id, quality = event.item.quality or 3 } )
      end
      table.insert( soft_reserves, { name = reservation.name, items = items } )
    end

    store.import( {
      metadata = { id = "SIM", instance = 0, instances = {}, origin = "raidres" },
      softreserves = soft_reserves,
      hardreserves = {}
    } )

    local by_name = {}
    for _, player in ipairs( event.players ) do by_name[ player.name ] = player end

    -- SoftResPresentPlayersDecorator captures group_roster.is_player_in_my_group as an
    -- upvalue when it is constructed, so overriding the roster afterwards cannot reach it
    -- and every simulated soft-resser is filtered out as absent. Skip just that layer by
    -- delegating to the chain's "unfiltered" tap, which keeps every decorator below it in
    -- play, and do its class enrichment here.
    local function enrich( rollers )
      for _, roller in ipairs( rollers or {} ) do
        local player = by_name[ roller.name ]
        roller.class = player and player.class
      end

      return rollers
    end

    local softres = ctx.get( "softres" )
    local unfiltered = ctx.softres_tap( "unfiltered" )
    if not softres or not unfiltered then return end

    -- Everything *above* the present-players layer still has to run, so it is rebuilt here
    -- rather than reproduced: hardcoding the stand-in as one named decorator would pin what
    -- the outermost layer is, and silently drop anything added above it later.
    -- Cloned rather than built from scratch: the stand-in *is* the current softres with the
    -- present-players filtering swapped out, so it has to keep the rest of the interface.
    -- Re-running /rfsetup is idempotent -- .get is overwritten before it is wrapped again.
    local stand_in = m.clone( softres )
    stand_in.get = function( item_data ) return enrich( unfiltered.get( item_data ) ) end
    stand_in.get_all_rollers = function() return enrich( unfiltered.get_all_rollers() ) end

    softres.get = stand_in.get
    softres.get_all_rollers = stand_in.get_all_rollers

    softres_gui.refresh()
  end

  ctx.event_bus.subscribe( "simulation_started", on_simulation_started )

  return {
    on_simulation_started = on_simulation_started
  }
end

sr.Simulation = M
return M
