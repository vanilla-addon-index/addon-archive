local PL = PizzaLoot

local function pattern(globalString)
  local result = string.gsub(globalString, '%%s', '(.+)')
  return (string.gsub(result, '%%d', '(%%d+)'))
end

local one = pattern(LOOT_ITEM_SELF)
local many = pattern(LOOT_ITEM_SELF_MULTIPLE)

local frame = CreateFrame('Frame')
frame:RegisterEvent('CHAT_MSG_LOOT')
frame:SetScript('OnEvent', function ()
  local _, _, text, count = string.find(arg1, many)
  if not text then _, _, text = string.find(arg1, one) end
  if not text then return end

  local _, _, link = string.find(text, '(item:%d+:%d+:%d+:%d+)')
  if not link then return end

  local name, _, quality, _, _, _, _, _, icon = GetItemInfo(link)
  if not name then return end

  PL.queue.add(PL.notice.item(name, quality, tonumber(count) or 1, icon))
end)
