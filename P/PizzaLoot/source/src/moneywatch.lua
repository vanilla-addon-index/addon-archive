local PL = PizzaLoot

local BATCH_WINDOW = 0.5
local SETTLE_DELAY = 0.4
local CHAT_MEMORY = 10

local pending = 0
local balanceBefore
local chats = {}

local flush = PL.timer.after(BATCH_WINDOW, function ()
  PL.queue.add(PL.notice.money(pending))
  pending = 0
end)

local function collect(copper)
  pending = pending + copper
  flush:restart()
end

local function forgetStale()
  local cutoff = GetTime() - CHAT_MEMORY
  while chats[1] and chats[1].at < cutoff do table.remove(chats, 1) end
end

-- CHAT_MSG_MONEY cannot be relied on: on some servers the coin lands in your
-- bags with no chat event at all. GetMoney() always tells the truth, so take a
-- reading when the loot window opens and report whatever turned up once it
-- closes. Tying this to the loot window is what keeps vendor sales, quest
-- rewards and mail out of the display. Coin can arrive a moment after the
-- window closes, hence the settle delay.
--
-- The chat line can also arrive just before its window opens, with the coin
-- landing only after it closes, so the balance change is matched against chat
-- lines oldest-first rather than by when they came in. Unmatched lines expire,
-- so a party share that never lands inside a window cannot swallow later coin.
local settle = PL.timer.after(SETTLE_DELAY, function ()
  if balanceBefore then
    forgetStale()
    local unreported = GetMoney() - balanceBefore
    while chats[1] and unreported > 0 do
      local covered = math.min(chats[1].copper, unreported)
      unreported = unreported - covered
      chats[1].copper = chats[1].copper - covered
      if chats[1].copper == 0 then table.remove(chats, 1) end
    end
    if unreported > 0 then collect(unreported) end
  end
  balanceBefore = nil
end)

local frame = CreateFrame('Frame')
frame:RegisterEvent('CHAT_MSG_MONEY')
frame:RegisterEvent('LOOT_OPENED')
frame:RegisterEvent('LOOT_CLOSED')
frame:SetScript('OnEvent', function ()
  if event == 'CHAT_MSG_MONEY' then
    local copper = PL.money.parse(arg1)
    if copper then
      forgetStale()
      table.insert(chats, { at = GetTime(), copper = copper })
      collect(copper)
    end
    return
  end

  if event == 'LOOT_OPENED' then
    if not balanceBefore then balanceBefore = GetMoney() end
    return
  end

  if event == 'LOOT_CLOSED' then
    settle:restart()
  end
end)
