RollFor = RollFor or {}
local m = RollFor

if m.PlayerInfo then return end

---@class PlayerInfo
---@field get_name fun(): string
---@field get_class fun(): string
---@field is_master_looter fun(): boolean
---@field is_leader fun(): boolean
---@field is_assistant fun(): boolean

local M = {}

---@param api table
function M.new( api )
  local function get_name()
    return api.UnitName( "player" )
  end

  local function get_class()
    return api.UnitClass( "player" )
  end

  -- A party index of 0 is the player, in a party or a raid: the same test the client's own
  -- PlayerFrame uses for the master looter icon. Anything else, and the raid index GetLootMethod
  -- also returns, points at somebody else.
  local function is_master_looter()
    if not api.IsInGroup() then return false end

    local loot_method, party_index = api.C_PartyInfo.GetLootMethod()
    return loot_method == 2 and party_index == 0
  end

  local function is_leader()
    return api.UnitIsGroupLeader( "player" )
  end

  local function is_assistant()
    if not api.IsInRaid() then return false end
    local my_name = get_name()

    for i = 1, 40 do
      local name, rank = api.GetRaidRosterInfo( i )

      if name and name == my_name then
        return rank and rank > 0 or false
      end
    end
  end

  ---@type PlayerInfo
  return {
    get_name = get_name,
    get_class = get_class,
    is_master_looter = is_master_looter,
    is_leader = is_leader,
    is_assistant = is_assistant
  }
end

m.PlayerInfo = M
return M
