RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

-- The soft-res list, as a RollFor extension.
--
-- RollFor knows there is *a* soft-res source, or there is not, and either way it works
-- against the same six read methods. Who reserved what, how names get matched to the
-- roster, what the import window looks like and what /sr does are all in here. Core's job
-- is to ask; this addon's job is to answer.
--
-- What this addon does *not* know is what a base64 string is. A **provider** -- a separate
-- addon such as RollForSoftResIt or RollForRaidRes -- registers a `decode` here, and that
-- is the whole of what "which website did this come from" means.
--
-- The registration at the bottom runs at file scope: the TOC declares
-- `## Dependencies: RollFor`, which makes the client load RollFor first and refuse to load
-- this addon at all without it, so RollFor.Extensions is there.

local M = {}

-- Core's shared helpers. See the note above about why this is safe at file scope.
local m = RollFor

local hl = m.colors.hl

-- Built in on_enable, read in on_ready. Not upvalues of on_enable itself because the two
-- phases are separate calls from core -- on_enable declares, on_ready builds, and nothing
-- exists to build against until between the two.
local store
local name_matcher
local disabled_entries

-- What a data provider is. It owns no soft-res data: the list belongs to this addon
-- whoever decoded it, so a provider is a decoder and four strings.
---@class SoftResProvider
---@field id string      -- persisted with the imported list; the provider's extension name
---@field title string   -- what the Provider dropdown shows, e.g. "raidres"
---@field decode fun( encoded: string? ): table?

---@type SoftResProvider[]
local providers = {}
---@type table<string, SoftResProvider>
local providers_by_id = {}

-- Providers register from their own `on_enable`, not at file scope and not from
-- `on_ready`. Two reasons: this addon's `on_ready` builds the window and runs *before* any
-- provider's, so a decoder handed over there would arrive too late; and `on_enable` does
-- not run for a **disabled** extension, which is exactly what keeps a disabled provider
-- out of the dropdown with no extra bookkeeping.
--
-- Validation mirrors Extensions.register: refuse rather than half-accept, and say why.
--
-- Called `register_provider` here and published as `RollForSoftRes.register` below: this
-- file already has an `M.register`, which is this addon's own registration with core, and
-- the two are different jobs done by different callers.
---@param spec SoftResProvider
---@return boolean -- whether the provider was registered
function M.register_provider( spec )
  if type( spec ) ~= "table" then
    m.err( "SoftRes provider registration failed: the spec must be a table." )
    return false
  end

  if type( spec.id ) ~= "string" or spec.id == "" then
    m.err( "SoftRes provider registration failed: 'id' must be a non-empty string." )
    return false
  end

  if type( spec.title ) ~= "string" or spec.title == "" then
    m.err( string.format( "SoftRes provider %s failed to register: 'title' must be a non-empty string.",
      hl( spec.id ) ) )
    return false
  end

  if type( spec.decode ) ~= "function" then
    m.err( string.format( "SoftRes provider %s failed to register: 'decode' must be a function.",
      hl( spec.id ) ) )
    return false
  end

  if providers_by_id[ spec.id ] then
    m.err( string.format( "SoftRes provider %s is already registered.", hl( spec.id ) ) )
    return false
  end

  local provider = { id = spec.id, title = spec.title, decode = spec.decode }

  providers_by_id[ provider.id ] = provider
  table.insert( providers, provider )

  return true
end

-- Registration order, which the TOC dependency chain makes load order: the alphabet
-- decides nothing here.
---@return SoftResProvider[]
function M.providers()
  return providers
end

---@param id string?
---@return SoftResProvider?
function M.provider( id )
  return id and providers_by_id[ id ] or nil
end

---Drops every provider. Tests only -- an addon never unregisters.
function M.clear_providers()
  providers = {}
  providers_by_id = {}
end

---@param ctx ExtensionContext
local function on_enable( ctx )
  -- The list window's widgets, into the table FrameBuilder resolves lines against. Here rather
  -- than in on_ready because the window built there looks them up by name as it draws.
  sr.SoftResListWidgets.register( ctx.gui_elements )

  local rows = sr.SoftResListFrame.rows_setting
  ctx.config.register_number( rows.key, rows.default, rows.min, rows.max )

  store = sr.SoftResStore.new( ctx.db( "store" ) )

  local function absent( softres )
    return sr.SoftResAbsentPlayersDecorator.new( ctx.group_roster, softres )
  end

  name_matcher = sr.NameManualMatcher.new(
    ctx.db( "name_matcher" ), ctx.api,
    absent( store ),
    sr.NameAutoMatcher.new( ctx.group_roster, store, 0.57, 0.4 ),
    function() ctx.minimap.refresh() end )

  -- After the matcher, which it asks for the name a player's reservations were imported under.
  disabled_entries = sr.SoftResDisabledEntries.new( ctx.db( "disabled_entries" ), name_matcher )

  -- One registration, unconditionally. Core's rule that exactly one source may register is
  -- now trivially satisfied instead of being a race between two addons: the providers
  -- register with us, not with core.
  ctx.softres_source.register( {
    id = "softres",
    title = "SoftRes",
    base = function() return store end,
    -- A saved import string counts as data even when it decoded to nothing: /rfsetup
    -- refuses to run over real data, and a string that failed to decode is still the
    -- user's, not the simulator's to overwrite. Same rule core's built-in applies.
    has_data = function()
      if m.getn( store.get_items() ) > 0 then return true end
      local data = ctx.db( "store" ).data

      return data and data ~= "" and true or false
    end,
    get_import_string = function() return ctx.db( "store" ).data end
  } )

  -- The soft-res backbone. These are the names other extensions anchor to --
  -- RollForNetherVortex sits between `awarded_loot` and `present_players` -- so renaming
  -- one is a breaking change for that addon, not a local rename. They used to be core's;
  -- whoever owns the list owns them now.
  --
  -- Addons load alphabetically, so RollForNetherVortex has already declared its anchors
  -- by the time this runs. That works only because Chain resolves anchors at build time.
  ctx.softres_chain.add( {
    name = "matched_name",
    after = m.Chain.BASE,
    factory = function( inner ) return sr.SoftResMatchedNameDecorator.new( name_matcher, inner ) end
  } )

  ctx.softres_chain.add( {
    name = "awarded_loot",
    -- ctx.get inside the factory, not outside: factories run at build time, by which point
    -- core has finished building the awarded-loot chain. Asking from on_enable gets nil.
    after = "matched_name",
    factory = function( inner )
      return sr.SoftResAwardedLootDecorator.new( ctx.get( "awarded_loot" ), inner )
    end
  } )

  ctx.softres_chain.add( {
    name = "present_players",
    after = "awarded_loot",
    factory = function( inner ) return sr.SoftResPresentPlayersDecorator.new( ctx.group_roster, inner ) end
  } )

  -- The full soft-res picture before the group filter drops everyone who isn't here.
  -- SoftResCheck and the roll simulator both want exactly this.
  ctx.softres_chain.tap( { name = "unfiltered", before = "present_players" } )

  -- The list window's checkboxes, last of all -- after the tap, so the window that draws the
  -- boxes still sees the entries they switch off. See SoftResDisabledEntriesDecorator.
  ctx.softres_chain.add( {
    name = "disabled_entries",
    after = "present_players",
    factory = function( inner ) return sr.SoftResDisabledEntriesDecorator.new( disabled_entries, inner ) end
  } )

  -- Keeps name matching current as people join and leave.
  ctx.on_group_changed( function() name_matcher.auto_match() end )
end

M.on_enable = on_enable

-- The name a player reserved under, given the name RollFor knows them by.
--
-- A player matched to a different in-game name -- by /sro or the auto-matcher -- reaches rolls,
-- previews and every window under that in-game name. An addon that reads the imported document
-- itself knows them only by the name on it, so it asks here to look them up. The name itself
-- when nothing renamed them, which includes this addon being off: nothing matches then.
---@param player_name string
---@return string
function M.softres_name( player_name )
  return name_matcher and name_matcher.get_softres_name( player_name ) or player_name
end

-- The import proper, once the provider's decoding is out of the way.
---@param softres_data table
function M.import_softres_data( softres_data )
  store.import( softres_data )
  name_matcher.auto_match()
end

local function on_ready( ctx )
  local function absent( softres )
    return sr.SoftResAbsentPlayersDecorator.new( ctx.group_roster, softres )
  end

  local softres_check = sr.SoftResCheck.new(
    ctx.softres_tap( "unfiltered" ), ctx.group_roster, name_matcher, ctx.ace_timer,
    absent, store, ctx.event_bus )

  local list_frame = sr.SoftResListFrame.new(
    ctx.popup_builder(), ctx.db( "list_frame" ), sr.SoftResListContentTransformer.new(),
    ctx.softres_tap( "unfiltered" ), ctx.group_roster, ctx.ace_timer, sr.SoftResListWidgets.text_width,
    ctx.config[ sr.SoftResListFrame.rows_setting.key ], ctx.roll_modifier.preview, disabled_entries, ctx.chat )

  -- The list is read fresh on every redraw, so these only have to say something changed. Group
  -- changes come after on_enable's auto_match, which registered first, so names are matched by
  -- the time the window redraws.
  ctx.on_group_changed( list_frame.refresh_if_visible )
  ctx.config.subscribe( sr.SoftResListFrame.rows_setting.key, list_frame.refresh_if_visible )
  -- A list a human just pasted in is the raid's agreement now, so it arrives with every entry on;
  -- the switches belonged to the list before it. The login re-import is not that -- it re-decodes
  -- the string already on disk -- so it leaves them alone, and a disabled entry survives a reload.
  ctx.event_bus.subscribe( "softres_imported", function( event )
    if event and event.interactive then disabled_entries.clear() end
    list_frame.refresh_if_visible()
  end )

  ctx.event_bus.subscribe( "softres_cleared", function()
    disabled_entries.clear()
    list_frame.refresh_if_visible()
  end )
  ctx.get( "roll_controller" ).subscribe( "loot_awarded", list_frame.refresh_if_visible )
  ctx.get( "roll_controller" ).subscribe( "loot_unawarded", list_frame.refresh_if_visible )

  local softres_gui
  local import_encoded

  local store_db = ctx.db( "store" )

  -- Wipes this addon's data and tells core, which clears the winner tracker and repaints
  -- the button off the back of the event rather than by being called.
  local function clear_data()
    -- Read before the store is wiped: what is being cleared is the list *that provider*
    -- imported, and once clear() has run there is nothing left to ask.
    local provider_id = store.get_provider()

    softres_gui.clear()
    name_matcher.clear( true )
    store.clear( true )
    ctx.event_bus.notify( "softres_cleared", { source = provider_id } )
  end

  softres_gui = sr.SoftResGui.new(
    ctx.api,
    function( data, provider_id, callback ) return import_encoded( data, provider_id, callback ) end,
    softres_check,
    ctx.get( "softres" ),
    clear_data,
    ctx.get( "dropped_loot_announce" ).reset,
    function()
      local simulator = ctx.get( "roll_simulator" )
      return simulator and simulator.is_simulating()
    end,
    ctx.db( "provider" ),
    ctx.gui_elements )

  -- The import, end to end. `data_loaded_callback` is how SoftResGui says a human clicked
  -- Import rather than this being the login reload re-reading the saved string --
  -- `interactive` carries that distinction to core, which must not re-broadcast to Gargul
  -- or fire auto-master-loot on every login.
  ---@param data string?
  ---@param provider_id string? -- whose decoder to use; the list's own at login, the dropdown's on Import
  import_encoded = function( data, provider_id, data_loaded_callback )
    if not data or data == "" then
      -- Recomputed rather than set to White outright: the icon is the highest severity
      -- across every contribution, and this addon having nothing to import says nothing
      -- about what the others have to report.
      ctx.minimap.refresh()
      return
    end

    local provider = M.provider( provider_id )

    -- The provider that imported this list is not installed any more. Report it by name
    -- and leave the raw string exactly where it is: an uninstalled decoder is not a reason
    -- to destroy data, and reinstalling the addon brings the list back at the next login.
    if not provider then
      m.pretty_print( string.format(
        "Soft-res data was imported with the %s provider, which is not installed. " ..
        "The saved list is kept; install it again or re-import to load it.",
        hl( provider_id or "unknown" ) ), m.colors.red )
      ctx.minimap.refresh()
      return
    end

    local softres_data = provider.decode( data )

    if not softres_data then
      m.pretty_print( string.format( "Could not load soft-res data with the %s provider!",
        hl( provider.title ) ), m.colors.red )
      return
    end

    M.import_softres_data( softres_data )

    m.pretty_print( "Soft-res data loaded successfully!" )

    local interactive = data_loaded_callback ~= nil

    -- Not persisted here. SoftResGui's Import handler already calls softres.persist from
    -- inside this callback, and only when the check found something -- pasting a string
    -- that decodes to an empty list does not overwrite the list you already had. Writing
    -- it here as well would persist on that path too, which is a behaviour change.
    if data_loaded_callback then data_loaded_callback( softres_data ) end

    -- `document` is what the provider decoded, handed over whole and unread. This addon
    -- takes `name`, `items[].id` and the hard reserves out of it and has no opinion about
    -- the rest -- but a provider's format may carry more (raidres puts a roll bonus on
    -- every reservation), and an extension that cares about one of those fields has no
    -- other way to see it. The store keeps the list; this keeps the source.
    --
    -- Fires on the login re-import as well, so a reader rebuilds from it every session
    -- rather than needing saved state of its own. `interactive` is what tells the two
    -- apart.
    ctx.event_bus.notify( "softres_imported",
      { source = provider.id, raw = data, document = softres_data, interactive = interactive } )
  end

  sr.Simulation.new( ctx, store, softres_gui )

  ctx.minimap.register( sr.Minimap.new( softres_check ) )

  -- This addon's claim on the minimap button's right click. The left one is left alone
  -- deliberately: core falls back to opening the options window there, which is what every
  -- other addon's minimap button does and what a user who has never heard of soft-res
  -- expects.
  --
  -- The right click is shared between the import window and the soft-res list: right click
  -- imports, shift or alt + right click shows the list. For everyone, not just the master
  -- looter -- the data is usually imported before the raid forms or loot is set to master,
  -- and a right click that silently did something else then looked broken.
  ctx.event_bus.subscribe( "minimap_icon_right_click", function()
    if m.is_shift_key_down() or m.is_alt_key_down() then
      list_frame.toggle()
      return
    end

    softres_gui.toggle()
  end )

  -- /sro comes from NameManualMatcher.new and /src and /srs from SoftResCheck.new, so
  -- they are already registered by the time we get here. /sr is this file's own.
  m.slash_cmd( "sr", function( args )
    if args == "init" then clear_data() end

    softres_gui.toggle()
  end )

  -- Core emits this at the same point in the login sequence where it used to do the import
  -- inline, so the ordering is unchanged by the move.
  -- The list is re-imported at login through the decoder that produced it, not through
  -- whatever the dropdown happens to be showing: switching provider re-decodes nothing.
  ctx.event_bus.subscribe( "player_login", function()
    local data = store_db.data

    import_encoded( data, store.get_provider() )
    softres_gui.load( data )
  end )
end

M.on_ready = on_ready

function M.register()
  if not m.Extensions then
    m.warn( "Unsupported RollFor version.", "RollForSoftRes" )
    return
  end

  return m.Extensions.register( {
    name = "softres",
    title = "SoftRes",
    -- 7, not Extensions.API_VERSION: this is what the addon was written against -- the list
    -- window reads roll_modifier.preview -- and claiming whatever core happens to be at would
    -- be a promise it cannot keep.
    api_version = 7,
    default_enabled = true,
    on_enable = on_enable,
    on_ready = on_ready,

    -- Declared here rather than from on_enable because a disabled extension still needs
    -- its page -- that page is where the switch to turn it back on lives, and on_enable
    -- does not run when we are off.
    options_page = function( ctx, parent ) return sr.OptionsPage.new( ctx, parent ) end
  } )
end

sr.main = M

-- The provider registry is the addon's published surface, so it sits on the addon table
-- itself: a provider says `RollForSoftRes.register{ ... }` and never has to know that the
-- rest of this file exists.
sr.register = M.register_provider
sr.providers = M.providers
sr.provider = M.provider
sr.clear_providers = M.clear_providers

-- Published for the same reason, to addons that read the imported document: see softres_name.
sr.softres_name = M.softres_name

-- Registration happens on load, which is the whole point: by the time RollFor builds its
-- components on PLAYER_LOGIN, the registry already knows about us. Tests that want a
-- clean registry clear it and call M.register() again.
M.register()

return M
