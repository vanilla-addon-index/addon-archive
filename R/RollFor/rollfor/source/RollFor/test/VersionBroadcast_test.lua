package.path = "./?.lua;" .. package.path .. ";../src/?.lua;../../?.lua;../src/libs/?.lua"

require( "src/compat" )
local utils = require( "RollFor/test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
local m = require( "src/modules" )
local VersionBroadcast = require( "src/VersionBroadcast" )

VersionBroadcastSpec = {}

function VersionBroadcastSpec.should_recognize_my_version_as_newer()
  -- Given
  local mine = "3.7"
  local theirs = "2.123"

  -- When
  local result = VersionBroadcast.is_new_version( mine, theirs )

  -- Then
  eq( result, false )
end

function VersionBroadcastSpec.should_recognize_their_version_as_newer()
  -- Given
  local mine = "3.7"
  local theirs = "3.11"

  -- When
  local result = VersionBroadcast.is_new_version( mine, theirs )

  -- Then
  eq( result, true )
end

function VersionBroadcastSpec.should_not_recognize_their_version_as_newer_cuz_they_are_the_fukin_same_lol()
  -- Given
  local mine = "3.7"
  local theirs = "3.7"

  -- When
  local result = VersionBroadcast.is_new_version( mine, theirs )

  -- Then
  eq( result, false )
end

function VersionBroadcastSpec.should_recognize_their_version_as_newer_if_they_have_a_bug_fix()
  -- Given
  local mine = "3.7"
  local theirs = "3.7.1"

  -- When
  local result = VersionBroadcast.is_new_version( mine, theirs )

  -- Then
  eq( result, true )
end

function VersionBroadcastSpec.should_not_recognize_their_version_as_newer_if_i_have_a_bug_fix()
  -- Given
  local mine = "3.7.2"
  local theirs = "3.7"

  -- When
  local result = VersionBroadcast.is_new_version( mine, theirs )

  -- Then
  eq( result, false )
end

function VersionBroadcastSpec.should_recognize_their_dot_beta_version_as_newer()
  -- Given
  local mine = "4.91"
  local theirs = "5.0.0.beta1"

  -- When
  local result = VersionBroadcast.is_new_version( mine, theirs )

  -- Then
  eq( result, true )
end

function VersionBroadcastSpec.should_recognize_my_dot_beta_version_as_newer()
  -- Given
  local mine = "5.0.0.beta1"
  local theirs = "4.91"

  -- When
  local result = VersionBroadcast.is_new_version( mine, theirs )

  -- Then
  eq( result, false )
end

function VersionBroadcastSpec.should_not_recognize_the_same_dot_beta_version_as_newer()
  -- Given
  local mine = "5.0.0.beta1"
  local theirs = "5.0.0.beta1"

  -- When
  local result = VersionBroadcast.is_new_version( mine, theirs )

  -- Then
  eq( result, false )
end

function VersionBroadcastSpec.should_recognize_their_dash_beta_version_as_newer()
  -- Given
  local mine = "4.91"
  local theirs = "5.0.0-beta1"

  -- When
  local result = VersionBroadcast.is_new_version( mine, theirs )

  -- Then
  eq( result, true )
end

function VersionBroadcastSpec.should_recognize_my_dash_beta_version_as_newer()
  -- Given
  local mine = "5.0.0-beta1"
  local theirs = "4.91"

  -- When
  local result = VersionBroadcast.is_new_version( mine, theirs )

  -- Then
  eq( result, false )
end

function VersionBroadcastSpec.should_not_recognize_the_same_dash_beta_version_as_newer()
  -- Given
  local mine = "5.0.0-beta1"
  local theirs = "5.0.0-beta1"

  -- When
  local result = VersionBroadcast.is_new_version( mine, theirs )

  -- Then
  eq( result, false )
end

function VersionBroadcastSpec.should_treat_dot_and_dash_beta_versions_as_the_same()
  -- Given
  local dot = "5.0.0.beta1"
  local dash = "5.0.0-beta1"

  -- When
  local dash_is_newer = VersionBroadcast.is_new_version( dot, dash )
  local dot_is_newer = VersionBroadcast.is_new_version( dash, dot )

  -- Then
  eq( dash_is_newer, false )
  eq( dot_is_newer, false )
end

function VersionBroadcastSpec.should_recognize_a_release_as_newer_than_its_dash_beta()
  -- Given
  local release = "5.0.0"
  local beta = "5.0.0-beta1"

  -- When
  local release_is_newer = VersionBroadcast.is_new_version( beta, release )
  local beta_is_newer = VersionBroadcast.is_new_version( release, beta )

  -- Then
  eq( release_is_newer, true )
  eq( beta_is_newer, false )
end

function VersionBroadcastSpec.should_recognize_a_release_as_newer_than_its_dot_beta()
  -- Given
  local release = "5.0.0"
  local beta = "5.0.0.beta1"

  -- When
  local release_is_newer = VersionBroadcast.is_new_version( beta, release )
  local beta_is_newer = VersionBroadcast.is_new_version( release, beta )

  -- Then
  eq( release_is_newer, true )
  eq( beta_is_newer, false )
end

function VersionBroadcastSpec.should_recognize_a_later_beta_as_newer()
  -- Given
  local older = "5.0.0-beta1"
  local newer = "5.0.0-beta2"

  -- When
  local newer_is_newer = VersionBroadcast.is_new_version( older, newer )
  local older_is_newer = VersionBroadcast.is_new_version( newer, older )

  -- Then
  eq( newer_is_newer, true )
  eq( older_is_newer, false )
end

function VersionBroadcastSpec.should_recognize_a_beta_as_newer_than_an_alpha()
  -- Given
  local older = "5.0.0-alpha3"
  local newer = "5.0.0-beta1"

  -- When
  local newer_is_newer = VersionBroadcast.is_new_version( older, newer )
  local older_is_newer = VersionBroadcast.is_new_version( newer, older )

  -- Then
  eq( newer_is_newer, true )
  eq( older_is_newer, false )
end

function VersionBroadcastSpec.should_recognize_a_release_candidate_as_newer_than_a_beta()
  -- Given
  local older = "5.0.0-beta2"
  local newer = "5.0.0-rc1"

  -- When
  local newer_is_newer = VersionBroadcast.is_new_version( older, newer )
  local older_is_newer = VersionBroadcast.is_new_version( newer, older )

  -- Then
  eq( newer_is_newer, true )
  eq( older_is_newer, false )
end

function VersionBroadcastSpec.should_recognize_a_later_release_as_newer_than_a_beta()
  -- Given
  local older = "5.0.0-beta1"
  local newer = "5.0.1"

  -- When
  local newer_is_newer = VersionBroadcast.is_new_version( older, newer )
  local older_is_newer = VersionBroadcast.is_new_version( newer, older )

  -- Then
  eq( newer_is_newer, true )
  eq( older_is_newer, false )
end

function VersionBroadcastSpec.should_ignore_the_case_of_a_pre_release_label()
  -- Given
  local older = "5.0.0-BETA1"
  local newer = "5.0.0-beta2"

  -- When
  local newer_is_newer = VersionBroadcast.is_new_version( older, newer )
  local older_is_newer = VersionBroadcast.is_new_version( newer, older )

  -- Then
  eq( newer_is_newer, true )
  eq( older_is_newer, false )
end

function VersionBroadcastSpec.should_sort_an_unknown_pre_release_label_after_the_known_ones()
  -- Given
  local older = "5.0.0-rc2"
  local newer = "5.0.0-preview1"

  -- When
  local newer_is_newer = VersionBroadcast.is_new_version( older, newer )
  local older_is_newer = VersionBroadcast.is_new_version( newer, older )

  -- Then
  eq( newer_is_newer, true )
  eq( older_is_newer, false )
end

function VersionBroadcastSpec.should_not_recognize_a_version_without_numbers_as_newer()
  -- Given
  local mine = "5.0.0"
  local theirs = "unknown"

  -- When
  local theirs_is_newer = VersionBroadcast.is_new_version( mine, theirs )
  local mine_is_newer = VersionBroadcast.is_new_version( theirs, mine )

  -- Then
  eq( theirs_is_newer, false )
  eq( mine_is_newer, false )
end

function VersionBroadcastSpec.should_recognize_pre_releases()
  eq( VersionBroadcast.is_pre_release( "5.0.0-beta1" ), true )
  eq( VersionBroadcast.is_pre_release( "5.0.0.beta1" ), true )
  eq( VersionBroadcast.is_pre_release( "5.0.0-rc1" ), true )
  eq( VersionBroadcast.is_pre_release( "5.0.0" ), false )
  eq( VersionBroadcast.is_pre_release( "4.91" ), false )
  eq( VersionBroadcast.is_pre_release( nil ), false )
end

---@param sent table
local function mock_api( sent )
  m.api = {
    IsInGuild = function() return true end,
    IsInGroup = function() return true end,
    IsInRaid = function() return false end,
    C_ChatInfo = {
      RegisterAddonMessagePrefix = function() end,
      SendAddonMessage = function( _, message, channel ) table.insert( sent, { message = message, channel = channel } ) end
    }
  }
end

local player_info = { get_name = function() return "Psikutas" end, get_class = function() return "Warrior" end }

function VersionBroadcastSpec.should_broadcast_a_release_to_the_guild_and_the_group()
  -- Given
  local sent = {}
  mock_api( sent )
  local version_broadcast = VersionBroadcast.new( {}, player_info, "5.0.0" )

  -- When
  version_broadcast.broadcast()

  -- Then
  eq( sent, {
    { message = "VERSION::5.0.0", channel = "GUILD" },
    { message = "VERSION::5.0.0", channel = "PARTY" }
  } )
end

function VersionBroadcastSpec.should_not_broadcast_a_pre_release()
  -- Given
  local sent = {}
  mock_api( sent )
  local version_broadcast = VersionBroadcast.new( {}, player_info, "5.0.0-beta1" )

  -- When
  version_broadcast.broadcast()
  version_broadcast.on_group_changed()

  -- Then
  eq( sent, {} )
end

function VersionBroadcastSpec.should_answer_a_version_request_from_a_pre_release()
  -- Given
  local sent = {}
  mock_api( sent )
  local version_broadcast = VersionBroadcast.new( {}, player_info, "5.0.0-beta1" )

  -- When
  version_broadcast.on_version_request( "GUILD", "Obszczymucha" )

  -- Then
  eq( sent, {
    { message = "VERSION_RESPONSE::Obszczymucha::GUILD::Psikutas::Warrior::5.0.0-beta1", channel = "GUILD" }
  } )
end

os.exit( lu.LuaUnit.run() )
