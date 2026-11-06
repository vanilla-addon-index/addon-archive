RollForAutoLoot = RollForAutoLoot or {}
local al = RollForAutoLoot

if al.AutoLootDb then return end

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

local M = {}

-- What the player ticked in the auto-loot window, and the one category that is auto-loot's own.
--
-- The catalogue of who drops what lives in DropTable, which is core's because core reads it.
-- This is the selection layer on top of it: the persisted `enabled` flags and the queries
-- auto-loot runs against them.
--
-- General is auto-loot's own category and belongs to nobody else, so it is defined here rather
-- than in the catalogue: two checkboxes that say "sweep up everything of this quality", whatever
-- the master loot threshold happens to be. It names qualities where every catalogue entry names
-- bosses, which is the same shape the round-robin catalogue's Trash category uses, and the tree
-- already draws. First in the window (order 0), because it is the only part of the list that is
-- not about a particular raid.
local GENERAL = "General"

local GENERAL_ENTRY = {
  order = 0,
  -- RollFor's own highlight colour, as RRGGBB the way a category names one (see the round-robin
  -- catalogue). Every other row at this level is dungeon blue; this one is not a raid, and the
  -- window is easier to read when the part that is about the loot itself says so.
  color = "ff9f69",
  qualities = {
    [ 2 ] = { name = "Uncommon" },
    [ 3 ] = { name = "Rare" }
  }
}

-- The catalogue and General, as one table to seed from. Built per call rather than kept: the
-- catalogue is DropTable's and this borrows it for the walk below, which only ever reads.
---@return table
local function catalogue_with_general()
  local result = { [ GENERAL ] = GENERAL_ENTRY }

  for dungeon_name, dungeon_entry in pairs( m.DropTable.ids ) do
    result[ dungeon_name ] = dungeon_entry
  end

  return result
end

-- Seeds db (the persisted selection SavedVariables table) with a copy of the catalogue plus
-- General, with `enabled = false` added to every dungeon/boss/item -- the user's actual
-- selection state, which the tree reads and writes from here on so it survives a /reload.
--
-- Reconciles instead of bailing out when db.ids already exists: the catalogue grows between
-- releases (Mount Hyjal's "Patterns" node did), and a db seeded once and never revisited would
-- hide every later addition from anyone who has already opened the GUI. Anything missing is
-- added disabled -- new rows are an offer, not a change to what the user picked -- while
-- `enabled` on rows that already exist is never touched. Everything else (order, name, icon,
-- quality) is a fact about the game rather than a choice, so the catalogue overwrites it.
--
-- Entries no longer in the catalogue are left alone rather than pruned: they cost a row in the
-- GUI at worst, and dropping them would throw away a selection over what may well be a typo in
-- an item id.
---@param db table
function M.ensure_seeded( db )
  db.ids = db.ids or {}

  for dungeon_name, dungeon_entry in pairs( catalogue_with_general() ) do
    local dungeon = db.ids[ dungeon_name ] or { enabled = false }
    dungeon.order = dungeon_entry.order
    -- Overwritten from the catalogue every login, like order and the names below: what colour a
    -- category is drawn in is a fact of the catalogue, not of anybody's selection.
    dungeon.color = dungeon_entry.color
    dungeon.bosses = dungeon.bosses or {}

    -- An entry names either encounters or qualities, never both. General is the only one of the
    -- second kind; seeded the same way, so a row's `enabled` is its own and survives.
    if dungeon_entry.qualities then
      dungeon.qualities = dungeon.qualities or {}

      for quality, quality_entry in pairs( dungeon_entry.qualities ) do
        local row = dungeon.qualities[ quality ] or { enabled = false }
        row.name = quality_entry.name

        dungeon.qualities[ quality ] = row
      end
    end

    for boss_name, boss_entry in pairs( dungeon_entry.bosses or {} ) do
      local boss = dungeon.bosses[ boss_name ] or { enabled = false }
      boss.order = boss_entry.order
      boss.items = boss.items or {}

      for item_id, item_entry in pairs( boss_entry.items or {} ) do
        local item = boss.items[ item_id ] or { enabled = false }
        item.quality = item_entry.quality
        item.icon = item_entry.icon
        item.name = item_entry.name

        boss.items[ item_id ] = item
      end

      dungeon.bosses[ boss_name ] = boss
    end

    db.ids[ dungeon_name ] = dungeon
  end
end

-- The two queries below are what auto-loot runs against the player's selection. Both read the
-- persisted db.ids (see ensure_seeded), never the catalogue -- that one carries no selection
-- state at all. An item only counts if it and both nodes above it are enabled, which is the
-- same rule the window's own rows are drawn by.
--
-- Skipping disabled dungeons/bosses wholesale keeps these proportional to what's actually selected
-- rather than to the size of the catalogue, so no lookup index is maintained here.

-- Items that appear under more than one boss (shared trash drops) count as soon as any one of
-- those occurrences is enabled.
---@param db table the persisted selection db
---@param item_id number
---@return boolean
function M.is_enabled( db, item_id )
  if not db or not db.ids then return false end

  for _, dungeon_entry in pairs( db.ids ) do
    if dungeon_entry.enabled then
      for _, boss_entry in pairs( dungeon_entry.bosses or {} ) do
        if boss_entry.enabled then
          local item = boss_entry.items and boss_entry.items[ item_id ]
          if item and item.enabled then return true end
        end
      end
    end
  end

  return false
end

-- Whether a whole quality is being swept up, which is what the General category's rows say. The
-- same rule as an item's: the row and the category above it both have to be ticked.
---@param db table the persisted selection db
---@param quality number?
---@return boolean
function M.is_quality_enabled( db, quality )
  if not db or not db.ids or not quality then return false end

  local general = db.ids[ GENERAL ]
  if not general or not general.enabled then return false end

  local row = general.qualities and general.qualities[ quality ]

  return (row and row.enabled) and true or false
end

-- Whether any quality row is ticked at all -- the General half of has_enabled_items.
---@param db table the persisted selection db
---@return boolean
function M.has_enabled_qualities( db )
  if not db or not db.ids then return false end

  local general = db.ids[ GENERAL ]
  if not general or not general.enabled then return false end

  for _, row in pairs( general.qualities or {} ) do
    if row.enabled then return true end
  end

  return false
end

-- Whether the player has anything at all selected -- i.e. whether M.is_enabled could ever return
-- true for this db. Stops at the first hit instead of counting.
---@param db table the persisted selection db
---@return boolean
function M.has_enabled_items( db )
  if not db or not db.ids then return false end

  for _, dungeon_entry in pairs( db.ids ) do
    if dungeon_entry.enabled then
      for _, boss_entry in pairs( dungeon_entry.bosses or {} ) do
        if boss_entry.enabled then
          for _, item in pairs( boss_entry.items or {} ) do
            if item.enabled then return true end
          end
        end
      end
    end
  end

  return false
end
M.GENERAL = GENERAL

al.AutoLootDb = M
return M
