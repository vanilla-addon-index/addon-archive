RollForAutoLoot = RollForAutoLoot or {}
local al = RollForAutoLoot

if al.AutoLoot then return end

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

local item_utils = m.ItemUtils ---@type ItemUtils
local auto_loot_db = al.AutoLootDb

local M = {}

M.interface = {
  decide = "function"
}

---@class AutoLoot
---@field is_auto_looted fun( item: DroppedItem ): boolean
---@field is_on_predefined_list fun( item: DroppedItem ): boolean
---@field decide fun( slot: number, item: DroppedItem ): string?
---@field on_awarded fun( slot: number, item: DroppedItem, recipient: string )

---@param api function
---@param autoloot_db table the persisted db backing the auto-loot window's predefined list
--- (see AutoLootDb.ensure_seeded). The window owns every write to it; this module only ever reads.
---@param config Config
---@param player_info PlayerInfo
---@param chat Chat
function M.new( api, autoloot_db, config, player_info, chat )
  local info = chat.info

  -- Items the player ticked in the auto-loot GUI (/rf autoloot). A deliberate choice, so they're
  -- auto-looted regardless of quality or bind type, and they stay announced even when auto-loot
  -- announcements are otherwise off (see DroppedLootAnnounce).
  local function is_on_predefined_list( item )
    return auto_loot_db.is_enabled( autoloot_db, item.id )
  end

  local function is_auto_looted( item )
    if not config.auto_loot() then
      return false
    end

    if is_on_predefined_list( item ) then
      return true
    end

    -- The General category's quality rows: sweep up everything of this quality, whatever the
    -- master loot threshold is. As deliberate a selection as ticking an item, so it answers to
    -- the same rules -- above the threshold and bind type included.
    if auto_loot_db.is_quality_enabled( autoloot_db, item.quality ) then
      return true
    end

    if item.bind == item_utils.BindType.BindOnPickup or item.bind == item_utils.BindType.Quest then
      return false
    end

    return (item.quality or 0) < api().GetLootThreshold()
  end

  -- What this policy would do with the slot: take it, to the player's own bags.
  --
  -- Nothing happens here. Core walks the slots, resolves the candidate index, sends the award
  -- and writes down who took it -- which is what lets the next policy have a slot this one
  -- wanted and turned out not to be able to take. The loop, the master-looter check and the
  -- shift key are all core's now; what is left is the only part that was ever this addon's,
  -- which is whether the item is one we sweep.
  --
  -- The feature's own on/off switch stays here rather than moving to core with the loop --
  -- it is this policy's answer and nothing to do with the pass. It is already the first thing
  -- is_auto_looted asks, so there is nothing to repeat.
  --
  -- Coins fall out on their own: core skips any slot whose item has no id.
  ---@param _ number -- slot; the rule is about the item
  ---@param item DroppedItem
  ---@return string?
  local function decide( _, item )
    if not is_auto_looted( item ) then return end

    return player_info.get_name()
  end

  -- Said once the award is actually on its way, rather than on deciding to want it: core may
  -- still find the player is not a candidate for the slot, and a message about looting
  -- something nobody looted is worse than no message.
  ---@param _ number
  ---@param item DroppedItem
  local function on_awarded( _, item )
    if config.auto_loot_messages() then
      info( string.format( "Auto-looting %s.", item.link ) )
    end
  end

  ---@type AutoLoot
  return {
    is_auto_looted = is_auto_looted,
    is_on_predefined_list = is_on_predefined_list,
    decide = decide,
    on_awarded = on_awarded
  }
end

al.AutoLoot = M
return M
