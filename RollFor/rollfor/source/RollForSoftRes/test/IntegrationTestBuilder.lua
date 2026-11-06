local u = require( "RollForSoftRes/test/utils" )
local reqsrc = u.multi_require_src
local lu, eq = u.luaunit( "assertEquals" ) ---@diagnostic disable-line: unused-local
local m, T, IU = require( "src/modules" ), require( "src/Types" ), require( "src/ItemUtils" )
reqsrc( "DebugBuffer", "Module", "Types", "SoftResDataTransformer", "RollingLogicUtils", "RollTracker" )
reqsrc( "TieRollingLogic", "SoftResRollingLogic", "NonSoftResRollingLogic", "RaidRollRollingLogic", "InstaRaidRollRollingLogic" )
require( "src/AwardedLoot" )
require( "src/Ordering" )
local Chain = require( "src/Chain" )
require( "src/DropTable" )
local SoftRes, Db = require( "src/SoftRes" ), require( "src/Db" )
-- EXTENSION: this addon's modules, so the chains below can carry its links. Named `addon`
-- rather than `softres`: build() has a `softres` of its own -- the chain this one's links
-- were built into -- and one name for both is one name too few.
local addon = (function()
  u.load_extension()
  return RollForSoftRes.main
end)()
local RollingLogic = require( "src/RollingLogic" )
local sr, hr, make_data = u.soft_res_item, u.hard_res_item, u.create_softres_data ---@diagnostic disable-line: unused-local
local c, r, pm = u.console_message, u.raid_message, u.party_message ---@diagnostic disable-line: unused-local
local cr, rw = u.console_and_raid_message, u.raid_warning ---@diagnostic disable-line: unused-local
local C, RT, RS = T.PlayerClass, T.RollType, T.RollingStrategy ---@diagnostic disable-line: unused-local
local make_player = T.make_player
local BindType = IU.BindType

u.mock_wow_api()

local M = {}

---@param name string
---@param class PlayerClass?
---@return Player
function M.p( name, class ) return make_player( name, class or C.Warrior, true ) end

M.mock_roster = require( "test/common/mocks/GroupRosterApi" ).new

local function enable_debug( ... ) ---@diagnostic disable-line: unused-local, unused-function
  local module_names = { ... }

  for _, module_name in ipairs( module_names ) do
    local module = m[ module_name ]
    if module and module.debug and module.debug.enable then
      u.info( string.format( "Enabling debug for %s.", module_name ) )
      module.debug.enable( true )
    end
  end
end

---@return ChatApiMock
function M.mock_chat()
  return require( "mocks/ChatApi" ).new() ---@diagnostic disable-next-line: return-type-mismatch
end

---@return Config
function M.mock_config( configuration )
  local config = configuration

  local result = {
    auto_raid_roll = function() return config and config.auto_raid_roll end,
    raid_roll_again = function() return config and config.raid_roll_again end,
    rolling_popup_lock = function() return config and config.rolling_popup_lock end,
    subscribe = function() end,
    rolling_popup = function() return true end,
    ms_roll_threshold = function() return 100 end,
    os_roll_threshold = function() return 99 end,
    default_rolling_time_seconds = function() return 8 end,
    master_loot_frame_rows = function() return 5 end,
    sr_roll_spacing = function()
      if config and config.sr_roll_spacing then return config.sr_roll_spacing end
      return 24
    end,
    roll_threshold = function()
      return {
        value = 100,
        str = "/roll"
      }
    end,
    classic_look = function() return false end
  }

  -- Core's register_number, as far as an extension sees it: the key becomes a getter answering the
  -- default and a setter.
  result.register_number = function( key, default )
    result[ key ] = function() return default end
    result[ "set_" .. key ] = function() end
  end

  return result
end

-- EXTENSION: the soft-res backbone -- matched_name, awarded_loot, present_players and the
-- unfiltered tap -- is this addon's, not core's, so it goes in through the addon's own
-- on_enable rather than a copy of it. A test then proves the real registration puts the
-- decorators where they belong, rather than proving this file agrees with itself.
--
-- Everything core is still expected to supply after the extraction stays here: the base
-- store this addon registers as the source.
-- Deliberately partial: on_enable touches nine of the context's twenty-seven fields and
-- on_ready nine, so the rest have no stub worth writing -- and a no-op one would turn "you
-- forgot to give the context a group_roster" from a crash into a silent nil. The waiver at
-- the literal is because `@as` fixes the expression's type and missing-fields checks the
-- literal.
---@param group_roster GroupRoster
---@param minimap_refresh fun()
---@param softres_chain Chain
---@param awarded_loot_chain Chain
---@param get fun( name: string ): any
---@return ExtensionContext -- the ctx the addon's on_enable is given
local function extension_context( group_roster, minimap_refresh, softres_chain, awarded_loot_chain, get )
  local db = Db.new( {} )

  ---@diagnostic disable-next-line: missing-fields
  return {
    db = function( key ) return db( string.format( "extension_softres_%s", key ) ) end,
    api = function() return m.api end,
    group_roster = group_roster,
    softres_chain = softres_chain,
    awarded_loot_chain = awarded_loot_chain,
    softres_source = { register = function() return true end, get_import_string = function() return nil end },
    minimap = { register = function() end, refresh = minimap_refresh },
    gui_elements = {},
    config = { register_number = function() end },
    on_group_changed = function() end,
    get = get
  } --[[@as ExtensionContext]]
end

---@param softres_chain Chain
---@param awarded_loot_chain Chain
local function softres_links( softres_chain, awarded_loot_chain, group_roster, get )
  addon.on_enable( extension_context( group_roster, function() end, softres_chain, awarded_loot_chain, get ) )
end

---@param data table?
---@param extend fun( softres_chain: Chain, awarded_loot_chain: Chain )? -- stands in for Extensions.enable
---@return GroupAwareSoftRes
---@return AwardedLoot
local function group_aware_softres( group_roster, awarded_loot, data, extend )
  local awarded_loot_chain = Chain.new( "awarded_loot" )
  local softres_chain = Chain.new( "softres" )

  -- Resolved when the soft-res chain is built, which happens after the awarded-loot one.
  -- This is the ordering hazard AwardedLootFactoryTiming_test pins: the addon's awarded_loot
  -- factory asks for the decorated record from inside the factory, so it sees this value and
  -- not nil.
  local decorated_awarded_loot

  local function get( name )
    if name == "awarded_loot" then return decorated_awarded_loot end
  end

  extend = extend or softres_links
  extend( softres_chain, awarded_loot_chain, group_roster, get )

  decorated_awarded_loot = awarded_loot_chain.build( awarded_loot ).final

  -- The addon registered its store as the source; with the addon switched off there is no
  -- source at all, which is core's null object.
  local base = RollForSoftRes.SoftResStore and softres_chain.has( "matched_name" )
      and RollForSoftRes.SoftResStore.new( Db.new( {} )( "softres" ) )
      or SoftRes.null()

  local result = softres_chain.build( base ).final

  if data and result.import then
    result.import( data )
  end

  return result, decorated_awarded_loot
end

function M.mock_loot_facade()
  return require( "test/common/mocks/LootFacade" ).new()
end

---@param name string
---@param id number?
---@param sr_players RollingPlayer[]?
---@param hard_ressed boolean?
---@param quality number?
---@param bind_type BindType?
---@return MasterLootDistributableItem
function M.i( name, id, sr_players, hard_ressed, quality, bind_type )
  local l = u.item_link( name, id )
  local tooltip_link = IU.get_tooltip_link( l )
  local item = IU.make_dropped_item( id or 123, name, l, tooltip_link, quality or 4, nil, nil, bind_type or BindType.None )

  if hard_ressed then
    return IU.make_hardres_dropped_item( item )
  end

  if sr_players and #sr_players > 0 then
    return IU.make_softres_dropped_item( item, sr_players )
  end

  return item
end

---@param name string
---@param id number?
---@param quality number?
---@param bind_type BindType?
---@return MasterLootDistributableItem
function M.qi( name, id, quality, bind_type )
  return M.i( name, id, nil, nil, quality, bind_type )
end

function M.new_roll_for()
  local dependencies = {}
  local builder = {}

  ---@param chat_api ChatApi|ChatApiMock
  function builder.chat( self, chat_api )
    dependencies[ "ChatApi" ] = chat_api
    return self
  end

  function builder.config( self, config )
    dependencies[ "Config" ] = M.mock_config( config )
    return self
  end

  ---@param loot_facade LootFacadeMock
  function builder.loot_facade( self, loot_facade )
    dependencies[ "LootFacade" ] = loot_facade
    return self
  end

  function builder.no_master_loot_candidates( self )
    dependencies[ "MasterLootCandidatesApi" ] = require( "test/common/mocks/MasterLootCandidatesApi" ).new()
    return self
  end

  ---@param ... Player[]
  function builder.roster( self, ... )
    dependencies[ "GroupRosterApi" ] = M.mock_roster( { ... } )
    return self
  end

  ---@param ... Player[]
  function builder.raid_roster( self, ... )
    dependencies[ "GroupRosterApi" ] = M.mock_roster( { ... }, true )
    return self
  end

  function builder.soft_res_data( self, ... )
    dependencies[ "SoftResData" ] = make_data( ... )
    return self
  end

  -- EXTENSION: builds RollFor as if this addon were switched off in the options window,
  -- so a test can show what core looks like with no soft-res source installed at all.
  function builder.without_softres( self )
    dependencies[ "ExtendChains" ] = function() end
    return self
  end

  ---@param threshold number
  function builder.loot_threshold( self, threshold )
    u.loot_threshold( threshold )
    return self
  end

  function builder.build()
    u.mock_slashcmdlist() -- Drop the previous build's commands so this one can register its own.
    u.zone_name()
    u.loot_threshold( 2 )
    u.targetting_enemy( "Princess Kenny" )

    local deps = dependencies or {}
    local db = Db.new( {} )

    local config = deps[ "Config" ] or M.mock_config()
    deps[ "Config" ] = config

    local player_info = require( "test/common/mocks/PlayerInfo" ).new( "Psikutas", "Warrior", true, true )
    deps[ "PlayerInfo" ] = player_info

    local group_roster_api = deps[ "GroupRosterApi" ] or M.mock_roster( { M.p( "Jogobobek", C.Warrior ), M.p( "Obszczymucha", C.Druid ) } )
    local group_roster = require( "src/GroupRoster" ).new( group_roster_api, player_info )
    deps[ "GroupRoster" ] = group_roster

    local chat_api = deps[ "ChatApi" ] or require( "mocks/ChatApi" ).new()
    local chat = deps[ "Chat" ] or require( "src/Chat" ).new( chat_api, group_roster, player_info )
    deps[ "Chat" ] = chat

    local loot_facade = deps[ "LootFacade" ] or M.mock_loot_facade()
    deps[ "LootFacade" ] = loot_facade

    local raw_awarded_loot = require( "src/AwardedLoot" ).new( db( "awarded_loot" ), chat )

    local softres, awarded_loot = group_aware_softres(
      group_roster, raw_awarded_loot, deps[ "SoftResData" ], deps[ "ExtendChains" ] )
    deps[ "SoftRes" ] = softres

    local raw_loot_list = require( "mocks/LootList" ).new( loot_facade )
    deps[ "LootList" ] = raw_loot_list
    local loot_list = require( "src/SoftResLootListDecorator" ).new( raw_loot_list, softres )
    deps[ "SoftResLootList" ] = loot_list

    local ml_candidates_api = deps[ "MasterLootCandidatesApi" ] or require( "test/common/mocks/MasterLootCandidatesApi" ).new( group_roster, raw_loot_list )
    local ml_candidates = require( "src/MasterLootCandidates" ).new( ml_candidates_api, group_roster, raw_loot_list )
    deps[ "MasterLootCandidates" ] = ml_candidates

    local ace_timer = require( "test/common/mocks/AceTimer" ).new()
    deps[ "AceTimer" ] = ace_timer

    local winner_tracker = require( "src/WinnerTracker" ).new( db( "winner_tracker" ) )
    deps[ "WinnerTracker" ] = winner_tracker

    local frame_builder = require( "mocks/FrameBuilder" )
    local loot_frame_skin = require( "test/common/mocks/MockedLootFrameSkin" ).new( frame_builder )
    local loot_frame = require( "mocks/LootFrame" ).new( loot_frame_skin, db( "loot_frame" ), config )
    local popup_builder = require( "mocks/PopupBuilder" )
    local rolling_popup = require( "mocks/RollingPopup" ).new( popup_builder.new(), db( "dummy" ), config )

    local confirmation_popup = require( "test/common/mocks/LootAwardPopup" ).new( nil )
    deps[ "LootAwardPopup" ] = confirmation_popup

    local player_selection_frame = require( "test/common/mocks/MasterLootCandidateSelectionFrame" ).new( frame_builder, config )
    deps[ "PlayerSelectionFrame" ] = player_selection_frame

    local roll_controller = require( "src/RollController" ).new(
      ml_candidates,
      softres,
      loot_list,
      config,
      rolling_popup,
      confirmation_popup, ---@diagnostic disable-line: param-type-mismatch
      player_selection_frame
    )

    local loot_award_callback = require( "src/LootAwardCallback" ).new( awarded_loot, roll_controller, winner_tracker, group_roster )
    local master_loot = require( "src/MasterLoot" ).new( ml_candidates, loot_award_callback, loot_list, roll_controller, player_info )

    -- Where main.lua registers them, and for its reason: an award by hand goes through the same
    -- callback master loot and trading do, so everything downstream hears it.
    u.modules().slash_cmd( "award", raw_awarded_loot.make_command( "/award", function( player_name, item_data )
      loot_award_callback.on_loot_awarded( item_data.item_id, item_data.link, player_name )
    end ) )

    u.modules().slash_cmd( "unaward", raw_awarded_loot.make_command( "/unaward", function( player_name, item_data )
      awarded_loot.unaward( player_name, item_data, true )
      roll_controller.loot_unawarded( item_data.item_id, item_data.link, player_name )
    end ) )
    deps[ "MasterLoot" ] = master_loot

    local strategy_factory = require( "src/RollingStrategyFactory" ).new(
      group_roster,
      loot_list,
      ml_candidates,
      chat,
      ace_timer,
      winner_tracker,
      config,
      softres,
      player_info
    )
    deps[ "RollingStrategyFactory" ] = strategy_factory

    local rolling_logic = RollingLogic.new(
      chat,
      ace_timer,
      roll_controller,
      strategy_factory,
      ml_candidates,
      winner_tracker,
      config
    )
    deps[ "RollingLogic" ] = rolling_logic

    local loot_controller = require( "src/LootController" ).new(
      player_info,
      loot_facade,
      loot_list,
      loot_frame,
      roll_controller,
      softres,
      rolling_logic,
      chat
    )
    deps[ "LootController" ] = loot_controller

    local rolling_popup_content = require( "src/RollingPopupContentTransformer" ).new( config )
    deps[ "RollingPopupContent" ] = rolling_popup_content

    require( "src/RollResultAnnouncer" ).new( chat, roll_controller, config )
    local boss_killed = deps[ "BossKilled" ] or require( "src/BossKilled" ).new( db( "boss_killed" ) )
    deps[ "BossKilled" ] = boss_killed

    local dropped_loot = require( "src/DroppedLoot" ).new( db( "dummy" ), loot_list, player_info, boss_killed )
    local dropped_loot_announce = require( "src/DroppedLootAnnounce" ).new(
      loot_list,
      chat,
      softres,
      winner_tracker,
      player_info
    )

    local auto_group_loot = require( "test/common/mocks/AutoGroupLoot" ).new()
    local loot_facade_listener = require( "src/LootFacadeListener" ).new()

    -- The real one, not a stand-in: an addon registering an award policy has to have somewhere
    -- to register it, and core is what performs the award now.
    local award_policies = require( "src/AwardPolicies" ).new( db( "award_order" ) )
    award_policies.attach( loot_list, player_info, ml_candidates )

    require( "src/CoreLootHandlers" ).register( loot_facade_listener, {
      award_policies = award_policies,
      dropped_loot = dropped_loot,
      dropped_loot_announce = dropped_loot_announce,
      master_loot = master_loot,
      auto_group_loot = auto_group_loot,
      roll_controller = roll_controller
    } )

    loot_facade_listener.start( loot_facade )
    deps[ "LootFacadeListener" ] = loot_facade_listener

    require( "src/DebugBuffer" ).disable_all()
    deps.roll = rolling_logic.on_roll

    return {
      loot_frame = loot_frame,
      rolling_popup = rolling_popup,
      confirmation_popup = confirmation_popup,
      player_selection = player_selection_frame,
      loot_list = loot_list, ---@type LootList
      dropped_loot = dropped_loot, ---@type DroppedLoot
      ace_timer = ace_timer,
      roll = rolling_logic.on_roll,
      roll_controller = roll_controller,
      awarded_loot = awarded_loot, ---@type AwardedLoot
      softres = softres, ---@type GroupAwareSoftRes
      reset_announcements = dropped_loot_announce.reset,
      enable_debug = enable_debug
    }
  end

  return builder
end

return M
