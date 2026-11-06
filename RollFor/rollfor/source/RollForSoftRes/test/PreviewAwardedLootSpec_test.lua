package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

require( "src/compat" )
local u = require( "RollForSoftRes/test/utils" )
local lu, eq = u.luaunit( "assertEquals" ) ---@diagnostic disable-line: unused-local
local sr = u.soft_res_item
local builder = require( "RollForSoftRes/test/IntegrationTestBuilder" )
local mock_loot_facade, mock_chat, new_roll_for = builder.mock_loot_facade, builder.mock_chat, builder.new_roll_for
local i, p = builder.i, builder.p
local gui = require( "test/common/gui_helpers" )
local item_link, text, buttons = gui.item_link, gui.text, gui.buttons
local enabled_item, selected_item = gui.enabled_item, gui.selected_item
local individual_award_button = gui.individual_award_button

-- Two specs out of core's PreviewSpec_test, moved here because they need this addon: they award an item
-- to one soft-resser and then assert the winner list no longer offers the player who
-- already won. That is awarded-loot filtering, which is this addon's
-- SoftResAwardedLootDecorator, so this is where they can pass. The other seventeen preview
-- specs need data and not filtering, and stayed in core.

u.mock_wow_api()
u.load_extension()

PreviewSoftResWinnersSpec = {}

function PreviewSoftResWinnersSpec:should_display_award_winner_buttons_and_award_the_winner_when_confirmed_then_display_the_remaining_winner()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- When
  loot_facade.notify( "LootOpened", item, item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha" } ),
    enabled_item( 2, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  chat.party( "Princess Kenny dropped 2 items:" )
  chat.party( "1. [Hearthstone] (SR by Obszczymucha)" )
  chat.party( "2. [Hearthstone] (SR by Psikutas)" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha" } ),
    selected_item( 2, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 2 ),
    text( "Obszczymucha soft-ressed this item.", 11 ),
    individual_award_button,
    text( "Psikutas soft-ressed this item.", 8 ),
    individual_award_button,
    buttons( "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.award( "Obszczymucha" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()
  -- TODO: verify loot confirmation popup content

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  chat.console( "RollFor: Obszczymucha received [Hearthstone]." )
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Psikutas soft-ressed this item.", 11 ),
    buttons( "AwardWinner", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()
  -- TODO: verify loot confirmation popup content

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  chat.console( "RollFor: Psikutas received [Hearthstone]." )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
end

function PreviewSoftResWinnersSpec:should_display_award_winner_buttons_and_award_the_winner_then_award_the_next_winner_after_closing_and_reopening_the_popup()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- When
  loot_facade.notify( "LootOpened", item, item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha" } ),
    enabled_item( 2, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  chat.party( "Princess Kenny dropped 2 items:" )
  chat.party( "1. [Hearthstone] (SR by Obszczymucha)" )
  chat.party( "2. [Hearthstone] (SR by Psikutas)" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha" } ),
    selected_item( 2, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 2 ),
    text( "Obszczymucha soft-ressed this item.", 11 ),
    individual_award_button,
    text( "Psikutas soft-ressed this item.", 8 ),
    individual_award_button,
    buttons( "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.award( "Obszczymucha" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()
  -- TODO: verify loot confirmation popup content

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  chat.console( "RollFor: Obszczymucha received [Hearthstone]." )
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Psikutas soft-ressed this item.", 11 ),
    buttons( "AwardWinner", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Close" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Psikutas soft-ressed this item.", 11 ),
    buttons( "AwardWinner", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()
  -- TODO: verify loot confirmation popup content

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  chat.console( "RollFor: Psikutas received [Hearthstone]." )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
end

os.exit( lu.LuaUnit.run() )
