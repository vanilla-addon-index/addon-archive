local PL = PizzaLoot
PL.queue = {}

local STAGGER = 0.15

local pending = {}
local drain

local function showNext()
  local notice = pending[1]
  if not notice then
    drain:stop()
    return
  end

  local big = notice.quality and notice.quality >= PL.quality.EPIC
  if not big and not PL.stack.hasRoom() then return end

  table.remove(pending, 1)
  if big then PL.banner.show(notice) else PL.stack.push(notice) end
end

drain = PL.timer.every(STAGGER, showNext)

function PL.queue.add(notice)
  table.insert(pending, notice)
  if not drain:isRunning() then
    drain:start()
    showNext()
  end
end
