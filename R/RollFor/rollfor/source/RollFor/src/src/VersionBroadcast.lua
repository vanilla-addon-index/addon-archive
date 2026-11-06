RollFor = RollFor or {}
local m = RollFor

if m.VersionBroadcast then return end

local M = {}

local pp = m.pretty_print
local ADDON_NAME = "RollFor"
local orange = m.colors.orange
local c = m.colorize_player_by_class
local getn = m.getn

-- Pre-release labels in release order. A label not listed here sorts after these, alphabetically.
local pre_release_rank = { alpha = 1, beta = 2, rc = 3 }

-- "5.0.0-beta1" and "5.0.0.beta1" -> { 5, 0, 0 }, "beta", 1
-- "5.0.0"                         -> { 5, 0, 0 }
---@param version string?
---@return number[]?, string?, number?
local function parse_version( version )
  local numbers, suffix = string.match( version or "", "^v?([%d%.]*%d)[%.%-]?(.*)$" )
  if not numbers then return nil end

  local parts = {}

  for part in string.gmatch( numbers, "%d+" ) do
    table.insert( parts, tonumber( part ) )
  end

  if suffix == "" then return parts end

  local label, number = string.match( suffix, "^(%a*)%.?(%d*)$" )
  return parts, string.lower( label or suffix ), tonumber( number ) or 0
end

---@param version string?
---@return boolean
function M.is_pre_release( version )
  local parts, label = parse_version( version )
  return parts ~= nil and label ~= nil
end

---@param mine string
---@param theirs string
---@return boolean
function M.is_new_version( mine, theirs )
  local my_parts, my_label, my_number = parse_version( mine )
  local their_parts, their_label, their_number = parse_version( theirs )
  if not my_parts or not their_parts then return false end

  for i = 1, math.max( getn( my_parts ), getn( their_parts ) ) do
    local my_part = my_parts[ i ] or 0
    local their_part = their_parts[ i ] or 0

    if their_part ~= my_part then return their_part > my_part end
  end

  -- Same numbers: a release is newer than any of its pre-releases.
  if not my_label or not their_label then return my_label ~= nil and their_label == nil end

  if their_label ~= my_label then
    local my_rank = pre_release_rank[ my_label ]
    local their_rank = pre_release_rank[ their_label ]

    if my_rank and their_rank then return their_rank > my_rank end
    if my_rank or their_rank then return my_rank ~= nil end

    return their_label > my_label
  end

  return their_number > my_number
end

---@param db table
---@param player_info PlayerInfo
---@param my_version string
function M.new( db, player_info, my_version )
  local function version_recently_reminded()
    if not db.last_new_version_reminder_timestamp then return false end

    local time = m.lua.time()

    -- Only remind once a day
    if time - db.last_new_version_reminder_timestamp > 3600 * 24 then
      return false
    else
      return true
    end
  end

  -- A pre-release doesn't announce itself: clients that predate pre-release labels count
  -- "5.0.0-beta1" as newer than 5.0.0 and would tell their players to update to it.
  -- It still answers version requests.
  local function broadcast_version( channel )
    if M.is_pre_release( my_version ) then return end
    m.SendAddonMessage( m.api, ADDON_NAME, "VERSION::" .. my_version, channel )
  end

  local function broadcast_version_to_the_guild()
    if not m.api.IsInGuild() then return end
    broadcast_version( "GUILD" )
  end

  local function group_channel()
    return m.api.IsInRaid() and "RAID" or "PARTY"
  end

  local function broadcast_version_to_the_group()
    if not m.api.IsInGroup() and not m.api.IsInRaid() then return end
    broadcast_version( group_channel() )
  end

  local function on_group_changed()
    broadcast_version_to_the_group()
  end

  local function notify_about_new_version( ver )
    db.last_new_version_reminder_timestamp = m.lua.time()
    pp( string.format( "New version (%s) is available!", m.colors.highlight( string.format( "v%s", ver ) ) ) )
    pp( "https://github.com/rollfor/rollfor/releases" )
  end

  local function on_version( their_version )
    if M.is_new_version( my_version, their_version ) and not version_recently_reminded() then
      notify_about_new_version( their_version )
    end
  end

  local function broadcast()
    broadcast_version_to_the_guild()
    broadcast_version_to_the_group()
  end

  local function on_version_request( channel, requesting_player_name )
    if not channel or not requesting_player_name then return end
    m.SendAddonMessage( m.api, ADDON_NAME,
      string.format(
        "VERSION_RESPONSE::%s::%s::%s::%s::%s",
        requesting_player_name,
        channel,
        player_info.get_name(),
        player_info.get_class(),
        my_version
      ), channel )
  end

  local function on_version_response( requesting_player_name, channel, their_name, their_class, their_version )
    if requesting_player_name ~= player_info.get_name() then return end
    pp( string.format( "%s %s", c( their_name, their_class ), "v" .. (their_version or "unknown") ), orange, string.lower( channel ) )
  end

  local function version_request( channel )
    m.SendAddonMessage( m.api, ADDON_NAME, string.format( "VERSION_REQUEST::%s::%s", channel, player_info.get_name() ), channel )
  end

  local function group_version_request()
    if not m.api.IsInGroup() and not m.api.IsInRaid() then
      pp( "Not in a group.", m.colors.red )
      return
    end

    version_request( group_channel() )
  end

  local function guild_version_request()
    if not m.api.IsInGuild() then
      pp( "Not in a guild.", m.colors.red )
      return
    end

    version_request( "GUILD" )
  end

  m.api.C_ChatInfo.RegisterAddonMessagePrefix( ADDON_NAME )

  return {
    on_group_changed = on_group_changed,
    broadcast = broadcast,
    on_version = on_version,
    on_version_request = on_version_request,
    on_version_response = on_version_response,
    group_version_request = group_version_request,
    guild_version_request = guild_version_request,
  }
end

m.VersionBroadcast = M
return M
