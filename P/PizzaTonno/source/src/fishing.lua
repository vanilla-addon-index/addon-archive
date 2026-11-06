local PT = PizzaTonno
PT.fishing = {}

-- Standing around after a cast or a catch counts as fishing time only up to this many seconds.
local IDLE_CAP = 60
local SESSION_GAP = 600

local MODE_EVENTS = { 'LOOT_OPENED', 'SPELLCAST_CHANNEL_START', 'SPELLCAST_CHANNEL_STOP' }

local frame = CreateFrame('Frame')
-- lastMark: the last cast or catch, where fishing time was counted up to
local hasPole, casting, castOnPool, lastCast, lastMark
local lastActivity = 0
local session = { catches = 0, poolCatches = 0, seconds = 0, items = {} }

local function countTime(now)
  if not lastMark then return end
  local seconds = math.min(now - lastMark, IDLE_CAP)
  session.seconds = session.seconds + seconds
  PT.catches.addTime(seconds)
end

-- These only fire while a pole is equipped, so a channeled cast is a fishing cast.
local function onCast()
  local now = GetTime()
  if lastCast and now - lastCast > SESSION_GAP then
    session = { catches = 0, poolCatches = 0, seconds = 0, items = {} }
    PT.catches.newSession()
  else
    countTime(now)
  end
  lastCast, lastMark, lastActivity, casting = now, now, now, true

  castOnPool = GameTooltip:IsVisible() and PT.data.isPool(GameTooltipTextLeft1:GetText())
  PT.hud.show()
end

-- There is no API for what the bobber landed in. A catch counts as a pool catch if the cursor was
-- on a pool when casting, or if it holds something this water can't drop but a pool of the zone can.
local function isPoolCatch(itemIds, zone, area)
  if castOnPool then return true end
  if not area then return false end

  for _, itemId in ipairs(itemIds) do
    if not PT.data.areasWith(itemId)[area.id] and PT.data.poolDrops(zone, itemId) then return true end
  end
  return false
end

-- An escaped fish opens no loot window, so only real catches get here.
local function onLoot()
  if not IsFishingLoot() then return end

  local itemIds = {}
  for slot = 1, GetNumLootItems() do
    if LootSlotIsItem(slot) then
      table.insert(itemIds, PT.utils.itemId(GetLootSlotLink(slot)))
    end
  end
  if table.getn(itemIds) == 0 then return end

  local zone, subzone = PT.player.location()
  local fromPool = isPoolCatch(itemIds, zone, PT.data.spot(zone, subzone))
  PT.catches.add(zone, subzone, itemIds, fromPool)

  session.catches = session.catches + 1
  if fromPool then session.poolCatches = session.poolCatches + 1 end
  for _, itemId in ipairs(itemIds) do
    session.items[itemId] = (session.items[itemId] or 0) + 1
  end

  local now = GetTime()
  countTime(now)
  lastMark, lastActivity = now, now
  PT.hud.catch(itemIds, fromPool)
  PT.almanac.refresh()
end

local function onPoleChange()
  local pole = PT.player.hasPole()
  if pole == hasPole then return end
  hasPole = pole

  for _, event in ipairs(MODE_EVENTS) do
    if pole then frame:RegisterEvent(event) else frame:UnregisterEvent(event) end
  end

  if pole then
    lastActivity = GetTime()
    PT.sounds.start()
    PT.hud.show()
  else
    casting = false
    PT.cast.stop()
    PT.sounds.stop()
    PT.hud.hide()
  end
end

local handlers = {
  PLAYER_LOGIN = onPoleChange,
  ITEM_LOCK_CHANGED = onPoleChange,
  -- equipment events are noise while zoning
  PLAYER_ENTERING_WORLD = function () frame:RegisterEvent('ITEM_LOCK_CHANGED') end,
  PLAYER_LEAVING_WORLD = function () frame:UnregisterEvent('ITEM_LOCK_CHANGED') end,
  SPELLCAST_CHANNEL_START = onCast,
  SPELLCAST_CHANNEL_STOP = function () casting = false end,
  LOOT_OPENED = onLoot,
}

frame:RegisterEvent('PLAYER_LOGIN')
frame:RegisterEvent('PLAYER_ENTERING_WORLD')
frame:RegisterEvent('PLAYER_LEAVING_WORLD')
frame:SetScript('OnEvent', function () handlers[event]() end)

-- Catches, pool catches, per-item counts and seconds spent fishing since the session began.
function PT.fishing.session()
  local seconds = session.seconds
  if lastMark then seconds = seconds + math.min(GetTime() - lastMark, IDLE_CAP) end
  return session, seconds
end

-- Whether the bobber is out.
function PT.fishing.casting()
  return casting
end

-- Seconds since the pole was equipped, a cast went out or a fish was caught.
function PT.fishing.idle()
  return GetTime() - lastActivity
end
