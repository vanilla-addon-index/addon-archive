package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua;../src/src/?.lua"

-- The import window, once it stopped belonging to a website.
--
-- This addon holds the list and knows nothing about wire formats: a provider addon
-- registers a `decode`, and the window's Provider dropdown is where the user says which
-- one a pasted string came from. There is one case here per state that dropdown has to
-- answer.
--
-- Driven through the real thing -- RollFor, then this addon, then `/sr` -- rather than
-- against SoftResGui in isolation, because half of what is under test is which provider id
-- reaches the store and the event bus, and that crosses three files.

require( "src/compat" )
local u = require( "RollForSoftRes/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )

u.mock_wow_api()
u.mock_libraries()
u.load_real_stuff()

-- A raidres-shaped document, which is what the transformer reads. Whatever a real provider
-- does to get here is exactly the part this addon does not have an opinion about.
local function decoded( item_id )
  return {
    metadata = { id = "TEST", instance = 0, instances = {}, origin = "raidres" },
    softreserves = { { name = "Psikutas", items = { { id = item_id or 123, quality = 4 } } } },
    hardreserves = {}
  }
end

---@param id string
---@param title string
---@param decode fun( encoded: string? ): table?
local function provider( id, title, decode )
  return { id = id, title = title, decode = decode }
end

-- Everything the console was told, decolorized. Installed over the built addon rather than
-- read out of a mock, because pretty_print goes straight to DEFAULT_CHAT_FRAME.
local printed

local function capture_console()
  printed = {}
  RollFor.api.DEFAULT_CHAT_FRAME = {
    AddMessage = function( _, message ) table.insert( printed, (u.decolorize( message )) ) end
  }
end

local function said( fragment )
  for _, message in ipairs( printed ) do
    if string.find( message, fragment, 1, true ) then return true end
  end

  return false
end

-- Builds RollFor with exactly these providers registered, then opens the window. The
-- registry is cleared first: providers register from on_enable in the client, and here the
-- test stands in for that, so it must not inherit the previous case's.
--
-- Repeated calls are repeated logins of the *same* character: the saved variables carry
-- over, which is the only way to see what a saved list and a saved provider do when the
-- install around them changes. Cases that need to start from nothing say so.
---@return table -- the import frame
local function open_window( ... )
  RollForSoftRes.clear_providers()

  for _, spec in ipairs( { ... } ) do RollForSoftRes.register( spec ) end

  -- Before the login, not after: the saved list is re-imported during PLAYER_LOGIN, and
  -- what that says about a provider it can no longer find is the point of half these cases.
  capture_console()
  u.player( "Psikutas" )
  u.run_command( "SR", "" )

  ---@diagnostic disable-next-line: undefined-global
  return _G[ "RollForSoftResImportFrame" ]
end

-- Wipes the saved variables, the way a brand new character has none. Every case starts
-- here: luaunit runs them in alphabetical order, and one case's saved provider is the next
-- one's mystery otherwise.
local function fresh_character()
  ---@diagnostic disable-next-line: undefined-global
  RollForCharDb = {}
end

---@param frame table
---@param text string
local function paste( frame, text )
  frame.editbox:SetText( text )
end

local function click_import( frame )
  frame.import_button.OnClickCallback()
end

DropdownSpec = {}

-- Registration order, which the TOC dependency chain makes load order. Nothing here relies
-- on the alphabet.
function DropdownSpec:should_list_every_registered_provider_by_title()
  fresh_character()
  open_window(
    provider( "softres_it", "softres.it", decoded ),
    provider( "raidres", "raidres", decoded ) )

  local listed = {}
  for _, option in ipairs( u.dropdown_buttons() ) do
    table.insert( listed, { option.text, option.value, option.checked } )
  end

  eq( listed, {
    { "softres.it", "softres_it", true },
    { "raidres", "raidres", false }
  } )
end

-- Present even with a single provider installed, so the window does not change shape
-- underneath the user the day they install a second one.
function DropdownSpec:should_show_the_dropdown_with_one_provider_and_preselect_it()
  fresh_character()
  local frame = open_window( provider( "raidres", "raidres", decoded ) )

  eq( frame.provider_dropdown:IsVisible(), true )
  eq( frame.provider_message:IsVisible(), false )
  eq( frame.provider_dropdown.value, "raidres" )
end

-- The choice is state. It survives a logout, which is the only reason to write it down.
function DropdownSpec:should_remember_the_selected_provider_across_sessions()
  fresh_character()
  local specs = { provider( "softres_it", "softres.it", decoded ), provider( "raidres", "raidres", decoded ) }
  open_window( unpack( specs ) )

  u.click_dropdown_option( "raidres" )

  -- The db is per character and survives the rebuild below, the way SavedVariables survive
  -- a reload.
  eq( open_window( unpack( specs ) ).provider_dropdown.value, "raidres" )
end

-- A saved choice whose addon has been uninstalled is not the same thing as no choice: the
-- fallback shows what is installed without overwriting what was picked, so reinstalling it
-- restores the selection.
function DropdownSpec:should_fall_back_to_the_first_provider_when_the_saved_one_is_gone()
  fresh_character()
  local both = { provider( "softres_it", "softres.it", decoded ), provider( "raidres", "raidres", decoded ) }
  open_window( unpack( both ) )
  u.click_dropdown_option( "raidres" )

  eq( open_window( provider( "softres_it", "softres.it", decoded ) ).provider_dropdown.value, "softres_it" )
  eq( open_window( unpack( both ) ).provider_dropdown.value, "raidres" )
end

NoProviderSpec = {}

function NoProviderSpec:should_say_so_when_nothing_registered_a_decoder()
  fresh_character()
  local frame = open_window()

  eq( frame.provider_dropdown:IsVisible(), false )
  eq( frame.provider_message:IsVisible(), true )
end

function NoProviderSpec:should_refuse_to_import()
  fresh_character()
  local frame = open_window()

  paste( frame, "some string a provider would understand" )

  eq( frame.import_button:IsEnabled(), false )
end

-- The simulation lock disables the editbox *and* clears it. This one must not: the string
-- in there is the user's, and a missing provider addon is a state of the install rather
-- than a reason to throw data away.
function NoProviderSpec:should_disable_the_editbox_without_clearing_it()
  fresh_character()
  local frame = open_window()

  paste( frame, "a string worth keeping" )

  eq( frame.editbox.mouse_enabled, false )
  eq( frame.editbox.keyboard_enabled, false )
  eq( frame.editbox:GetText(), "a string worth keeping" )
end

ImportSpec = {}

function ImportSpec:should_decode_with_the_selected_provider()
  fresh_character()
  local decoded_by = {}

  local frame = open_window(
    provider( "softres_it", "softres.it", function() table.insert( decoded_by, "softres_it" ); return decoded() end ),
    provider( "raidres", "raidres", function() table.insert( decoded_by, "raidres" ); return decoded() end ) )

  u.click_dropdown_option( "raidres" )
  paste( frame, "an export string" )
  click_import( frame )

  eq( decoded_by, { "raidres" } )
  eq( said( "Soft-res data loaded successfully!" ), true )
end

-- The existing failure path, with the selected provider named so the cause is obvious:
-- pasting a softres.it string with raidres selected is the mistake this catches.
function ImportSpec:should_name_the_selected_provider_when_the_string_does_not_decode()
  fresh_character()
  local frame = open_window( provider( "raidres", "raidres", function() return nil end ) )

  paste( frame, "a string from the other website" )
  click_import( frame )

  eq( said( "Could not load soft-res data with the raidres provider!" ), true )
end

-- Nothing reads this field today, which is exactly why it is free to become the honest
-- value now that one addon imports from either site.
function ImportSpec:should_tag_the_import_event_with_the_provider_id()
  fresh_character()
  local frame = open_window( provider( "raidres", "raidres", decoded ) )
  local rf = u.load_roll_for()

  local seen = {}
  rf.event_bus.subscribe( "softres_imported", function( event ) table.insert( seen, event.source ) end )

  paste( frame, "an export string" )
  click_import( frame )

  eq( seen, { "raidres" } )
end

function ImportSpec:should_tag_the_cleared_event_with_the_provider_that_imported_the_list()
  fresh_character()
  local frame = open_window( provider( "raidres", "raidres", decoded ) )
  local rf = u.load_roll_for()

  paste( frame, "an export string" )
  click_import( frame )

  local seen = {}
  rf.event_bus.subscribe( "softres_cleared", function( event ) table.insert( seen, event.source ) end )

  u.run_command( "SR", "init" )

  eq( seen, { "raidres" } )
end

-- Selection alone changes nothing. The next Import is what re-decodes, which is why the
-- provider is saved with the list rather than read off the dropdown at login.
function ImportSpec:should_keep_the_list_when_the_dropdown_is_switched()
  fresh_character()
  local ITEM = 32232
  local frame = open_window(
    provider( "raidres", "raidres", function() return decoded( ITEM ) end ),
    provider( "softres_it", "softres.it", function() return nil end ) )

  paste( frame, "an export string" )
  click_import( frame )

  u.click_dropdown_option( "softres_it" )

  local rf = u.load_roll_for()
  eq( #rf.softres.get( { item_id = ITEM, item_quantity = 1 } ), 1 )
end

UninstalledProviderSpec = {}

-- Note on what these can assert. `u.player()` wipes the soft-res list right after firing
-- the login events -- that is the harness resetting between cases, not the addon -- so
-- "the list is there after a login" is not observable through `softres.get`. What is
-- observable is whether the saved string was handed to a decoder at all, which is the
-- behaviour in question either way.

-- The list was imported with a provider that is no longer installed. Report it by name and
-- leave the raw string exactly where it is: reinstalling the addon brings the list back at
-- the next login, and an uninstalled decoder is not a reason to destroy data.
function UninstalledProviderSpec:should_report_a_missing_provider_and_keep_the_string()
  fresh_character()
  local frame = open_window( provider( "raidres", "raidres", decoded ) )

  paste( frame, "an export string" )
  click_import( frame )

  -- Same character, next login, with the provider addon uninstalled.
  local reopened = open_window()

  eq( said( "raidres" ), true )
  eq( said( "is not installed" ), true )

  -- Untouched on disk, and still in the window, so it can be copied back out.
  eq( RollFor.SoftResSource.get().get_import_string(), "an export string" )
  eq( reopened.editbox:GetText(), "an export string" )
end

function UninstalledProviderSpec:should_load_the_list_again_once_the_provider_is_back()
  fresh_character()
  local decoded_strings = {}
  local spec = provider( "raidres", "raidres", function( encoded )
    table.insert( decoded_strings, encoded )
    return decoded()
  end )

  local frame = open_window( spec )
  paste( frame, "an export string" )
  click_import( frame )

  decoded_strings = {}
  open_window()

  -- Nothing to decode with, so nothing was decoded -- and nothing was thrown away either.
  eq( decoded_strings, {} )

  decoded_strings = {}
  open_window( spec )

  -- Reinstalled: the saved string goes back through its own decoder at login.
  eq( decoded_strings, { "an export string" } )
  eq( said( "Soft-res data loaded successfully!" ), true )
end

ImportWindowSimulationSpec = {}

-- /rfsetup is not an import. It fabricates already-decoded data and hands it to the store,
-- so it has to keep working with no provider registered at all.
function ImportWindowSimulationSpec:should_simulate_without_any_provider()
  fresh_character()
  local PENDANT = 32370

  RollForSoftRes.clear_providers()
  u.player( "Psikutas" )
  u.is_in_raid( u.raid_leader( "Psikutas" ), "Drutree" )
  local rf = u.load_roll_for()

  u.run_command( "RFSETUP", string.format( "%s Drutree", u.item_link( "Nadina's Pendant of Purity", PENDANT ) ) )

  local rollers = rf.softres.get( { item_id = PENDANT, item_quantity = 1 } )
  eq( #rollers, 1 )
  eq( rollers[ 1 ].name, "Drutree" )
end

os.exit( lu.LuaUnit.run() )
