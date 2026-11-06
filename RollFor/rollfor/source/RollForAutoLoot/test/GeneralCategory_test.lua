package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua"

-- The General category: this addon's own, and the one part of the selection tree that is not
-- a raid. The tree and the window are core's (SelectionTree_test covers them); what is here
-- is the category this addon defines and seeds into the db that tree is built from.

require( "src/compat" )
local u = require( "RollForAutoLoot/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
u.mock_wow_api()
require( "src/ItemUtils" )
require( "src/DropTable" )
require( "src/AutoLootDb" )
require( "src/Tree" )
local SelectionTree = require( "src/SelectionTree" )

GeneralCategorySpec = {}

-- The catalogue's one static category: two quality rows rather than a dungeon's bosses, and
-- first in the window because it is the only part of the list that is not about a raid.
local function seeded_tree()
  local db = {}

  RollForAutoLoot.AutoLootDb.ensure_seeded( db )

  return SelectionTree.build( db, RollFor.DropTable.non_bosses ), db
end

function GeneralCategorySpec:should_come_first()
  local roots = seeded_tree()

  eq( roots[ 1 ].data.name, RollForAutoLoot.AutoLootDb.GENERAL )
end

-- Label leaves: a checkbox and a coloured word, no icon and no item tooltip, which is what a
-- quality row is. Uncommon before Rare, the order the qualities themselves are in.
function GeneralCategorySpec:should_offer_an_uncommon_and_a_rare_row()
  local roots = seeded_tree()
  local rows = {}

  for _, row in ipairs( roots[ 1 ].children ) do
    table.insert( rows, { name = row.data.name, quality = row.data.quality, id = row.data.id } )
  end

  eq( rows, { { name = "Uncommon", quality = 2 }, { name = "Rare", quality = 3 } } )
end

-- It is not a raid and should not read as one: the window is a wall of dungeon-blue category
-- rows, and this is the one that is about the loot itself.
function GeneralCategorySpec:should_be_drawn_in_its_own_colour()
  local roots = seeded_tree()

  lu.assertNotEquals( roots[ 1 ].data.color, roots[ 2 ].data.color )
  lu.assertNotEquals( roots[ 1 ].data.hover_text_color, roots[ 2 ].data.hover_text_color )
end

function GeneralCategorySpec:should_start_with_both_rows_unticked()
  local roots = seeded_tree()

  eq( roots[ 1 ].data.checked, false )
  eq( roots[ 1 ].children[ 1 ].data.checked, false )
  eq( roots[ 1 ].children[ 2 ].data.checked, false )
end

-- Ticking a row writes through to the persisted entry, the same as every other row in this tree.
function GeneralCategorySpec:should_write_a_ticked_row_back_to_the_db()
  local roots, db = seeded_tree()

  SelectionTree.set_checked( roots[ 1 ].children[ 1 ], true )

  eq( db.ids[ RollForAutoLoot.AutoLootDb.GENERAL ].qualities[ 2 ].enabled, true )
end

os.exit( lu.LuaUnit.run() )
