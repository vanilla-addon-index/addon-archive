local PL = PizzaLoot
PL.stack = {}

local REPOSITION_DELAY = 0.1
local RELAYOUT_STAGGER = 0.03
local ADMIT_DELAY = 0.3
local STRIDE = PL.layout.height + PL.layout.spacing

local active = {}
local admitAt = 0

-- Rows land on the side the card flies in from, so an entrance always crosses
-- empty space instead of the row it is about to sit next to. Sliding in upwards
-- therefore fills the stack top-down; every other direction fills bottom-up.
local function slotY(index)
  if PizzaLoot_config.slideIn == 'up' then
    return PL.utils.snap((PL.layout.rows - index) * STRIDE)
  end
  return PL.utils.snap((index - 1) * STRIDE)
end

function PL.stack.relayout()
  for index, row in ipairs(active) do
    row:slideTo(slotY(index), (index - 1) * RELAYOUT_STAGGER)
  end
end

-- Long enough for the departing card's fade to finish, so the row moving up
-- to replace it never overlaps it, and rows expiring together share one relayout.
local reposition = PL.timer.after(REPOSITION_DELAY, PL.stack.relayout)

-- Searched rather than popped: hold time varies by quality, so rows can expire
-- out of order.
local function retire(row)
  for index, candidate in ipairs(active) do
    if candidate == row then
      table.remove(active, index)
      break
    end
  end

  reposition:restart()
  admitAt = GetTime() + ADMIT_DELAY
end

-- A freed slot is not free until the survivors have slid out of it. Admitting
-- a queued row straight away dropped it onto a card that was still waiting for
-- its relayout.
function PL.stack.hasRoom()
  return table.getn(active) < PL.layout.rows and GetTime() >= admitAt
end

function PL.stack.push(notice)
  local row = PL.row.acquire()
  row:setContent(notice)
  table.insert(active, row)
  row:placeAt(slotY(table.getn(active)))
  row:enter(function () retire(row) end)
end
