RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.SoftResListContentTransformer then return end

local M = {}

-- The soft-res list as lines the window draws.
--
-- Its own module for the reason every other RollFor window's transformer is: what a row says is
-- decided here, out of plain tables, where a test can read it -- the frame builds widgets, and a
-- widget is not something an assertion can ask a question of.

-- Every row is padded the same. A wider gap on the first one would disappear with that row once
-- the list scrolls -- see AutoRoundRobinQueueFrameContentTransformer.
local row_gap = 2
local empty_notice_gap = 10

-- The popup reserves a flat 23 below its content, which less the window's top padding leaves the
-- last row nearly on the border. The trailing spacer is invisible, so its padding widens that gap;
-- PendingLootContentTransformer does the same with a negative number to narrow it. 12 on top of
-- ListPopup's default padding of 16, and 5 more for the 5 SoftResListFrame adds to it.
local bottom_gap = 17

M.row_type = "softres_list_row"
M.header_type = "softres_list_header"

---@alias SoftResListColumn
---| "player"
---| "item"
---| "boss"

---@class SoftResListFrameRow
---@field player string -- already coloured
---@field count string? -- 2x, drawn left of the item; nil for a single roll, for a player who
--- reserved nothing, and for every row while the list is ungrouped. Grouped, it counts the rolls
--- still switched on -- or, once none are, the rolls the imported list said there were
---@field item_link string -- a placeholder while the client doesn't have the item, or a note for a
--- player who reserved nothing
---@field item_tooltip_link TooltipItemLink?
---@field item_chat_link string? -- the ungreyed link a shift-click pastes, when the row draws a
--- greyed one; nil when what is drawn is what should be pasted
---@field adjustment string? -- " +30", drawn right after the item link; nil when no modifier adds anything
---@field boss string -- already coloured
---@field enabled SoftResListRowState? -- the checkbox at the head of the row; nil for a player who
--- reserved nothing, who has no entry to switch off and so no box
---@field on_toggle_enabled fun()? -- what clicking that box asks for

-- Whether a row's reservations count. "partial" is a grouped row some but not all of whose rolls
-- are switched off, drawn as a greyed tick.
---@alias SoftResListRowState
---| "on"
---| "off"
---| "partial"

-- How wide the widest entry in each column draws, over the whole list. Every line of a redraw gets
-- the same one, so the header and the rows lay their columns out alike.
---@class SoftResListWidths
---@field player number
---@field count number -- 0 when nobody has more than one roll, and while the list is ungrouped
---@field item number
---@field boss number

---@class SoftResListFrameData
---@field on_announce_missing fun()? -- names the group members who reserved nothing in group chat;
--- nil when there are none, or nothing has been imported for them to be missing from
---@field show_absent boolean
---@field on_toggle_absent fun( checked: boolean )
---@field group_items boolean
---@field on_toggle_group_items fun( checked: boolean )
---@field sort_column SoftResListColumn
---@field sort_ascending boolean
---@field on_sort fun( column: SoftResListColumn )
---@field rows SoftResListFrameRow[]
---@field widths SoftResListWidths

---@class SoftResListContentTransformer
---@field transform fun( data: SoftResListFrameData ): table[]

---@return SoftResListContentTransformer
function M.new()
  ---@param data SoftResListFrameData
  local function transform( data )
    local content = {}

    table.insert( content, {
      type = M.header_type,
      on_announce_missing = data.on_announce_missing,
      show_absent = data.show_absent,
      on_toggle_absent = data.on_toggle_absent,
      group_items = data.group_items,
      on_toggle_group_items = data.on_toggle_group_items,
      sort_column = data.sort_column,
      sort_ascending = data.sort_ascending,
      on_sort = data.on_sort,
      widths = data.widths
    } )

    for _, row in ipairs( data.rows ) do
      table.insert( content, {
        type = M.row_type,
        player = row.player,
        item_link = row.item_link,
        item_tooltip_link = row.item_tooltip_link,
        item_chat_link = row.item_chat_link,
        count = row.count,
        adjustment = row.adjustment,
        boss = row.boss,
        enabled = row.enabled,
        on_toggle_enabled = row.on_toggle_enabled,
        widths = data.widths,
        padding = row_gap
      } )
    end

    if #data.rows == 0 then
      table.insert( content, { type = "text", value = "No soft-res entries.", padding = empty_notice_gap } )
    end

    table.insert( content, { type = "empty_line", padding = bottom_gap } )

    return content
  end

  return { transform = transform }
end

sr.SoftResListContentTransformer = M
return M
