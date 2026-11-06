local A = FonzAppraiser
local L = A.locale

A.module 'fa'

local util = A.requires(
  'util.table',
  'util.money',
  'util.item',
  'util.group',
  'util.string'
)
local palette = A.require 'fa.palette'
local pricing = A.require 'fa.value.pricing'
local filter = A.require 'fa.filter'
local session = A.require 'fa.session'
local misc = A.require 'fa.misc'
local gui_main = A.require 'fa.gui.main'
local gui_config = A.require 'fa.gui.config'
local gui_minimap = A.require 'fa.gui.minimap'

-- Events --

--[[
  Notes:
  - GlobalStrings.lua is Blizzard's own code for Lua string constants
--]]

-- Shared money regex patterns (used across multiple handlers)
local PATTERN_MONEY_LOOT_YOU
local PATTERN_MONEY_LOOT_SPLIT
local PATTERN_MONEY_RECEIVE
local PATTERN_MONEY_GAIN
local PATTERN_MONEY_RECEIVED_SHORT

-- Quest reward tracking shared across handlers
local pending_quest_money
local quest_money_window_until

do
  local find = string.find
  local isInGroup = util.isInGroup
  local GetTime = GetTime

  local function toPatternFromGlobal(gs, fallback)
    local src = gs or fallback
    if not src or src == "" then return nil end
    -- Escape percent signs and punctuation, then replace %s with capture group
    local pat = util.strEscapeFormat(src)
    pat = string.gsub(pat, "%s", "(.+)")
    pat = "^" .. pat .. "$"
    return pat
  end

  -- Localized patterns from GlobalStrings (fallback to enUS literal)
  PATTERN_MONEY_LOOT_YOU = toPatternFromGlobal(_G.YOU_LOOT_MONEY, "You loot %s")
  PATTERN_MONEY_LOOT_SPLIT = toPatternFromGlobal(_G.LOOT_MONEY_SPLIT, "Your share of the loot is %s.")
  PATTERN_MONEY_RECEIVE = toPatternFromGlobal(_G.YOU_RECEIVE_MONEY, "You receive %s.")
  PATTERN_MONEY_GAIN = toPatternFromGlobal(_G.YOU_GAIN_MONEY, "You gain %s.")
  -- Relaxed fallback seen in some UIs: "Received: 2 Gold, 6 Silver, 60 Copper"
  PATTERN_MONEY_RECEIVED_SHORT = "^Received:? (.+)$"

  function A:CHAT_MSG_MONEY(msg)
    -- В одиночку монеты обычно учитываются через LOOT_* события.
    -- Для награды за квест открываем короткое окно перехвата чат-сообщения.
    local now = GetTime()
    local isQuestWindow = quest_money_window_until and now < quest_money_window_until
    -- Не делаем ранний выход для соло: перехватим generic "Received" ниже

    local money_string
    local isGenericReceived = false
    --Shift-click money loot in a group.
    _, _, money_string = find(msg, PATTERN_MONEY_LOOT_YOU)
    if not money_string then
      --Shared money loot in a group.
      _, _, money_string = find(msg, PATTERN_MONEY_LOOT_SPLIT)
    end

    -- Also accept wider money messages (quest reward, XP→gold)
    if not money_string then
      _, _, money_string = find(msg, PATTERN_MONEY_RECEIVE)
      if not money_string then
        _, _, money_string = find(msg, PATTERN_MONEY_GAIN)
        if not money_string then
          _, _, money_string = find(msg, PATTERN_MONEY_RECEIVED_SHORT)
        end
      end
      isGenericReceived = money_string ~= nil
    end

    if not money_string then return end

    -- Support full word forms like "Received 1 Gold, 92 Silver" and localized names
    local value
    if isQuestWindow or isGenericReceived then
      if isGenericReceived and not util.isCurrencyMessage(money_string) then
        return
      end
      value = util.valueFromCurrencyText(money_string)
    else
      value = util.extendedStringToMoney(money_string)
    end
    if value and value > 0 then
      local money_type
      -- Treat generic Received lines and solo context as solo income
      if isQuestWindow or isGenericReceived or not isInGroup() then
        money_type = L["solo"]
      else
        money_type = L["shared"]
      end
      session.lootMoney(value, money_type)
      if isQuestWindow or isGenericReceived then
        pending_quest_money = nil
        quest_money_window_until = nil
      end
      A:guiUpdate()
    else
      A.warn("Money loot message but no value found. Original message: %s",
        msg)
    end
  end
end

-- 1.12-mod compatibility: some servers print money as system text
do
  local find = string.find
  local parseItemLink = util.parseItemLink
  local makeStoreToken = util.makeStoreToken

  function A:CHAT_MSG_SYSTEM(msg)
    -- First, try to handle generic money lines
    local _, _, money_string = find(msg, PATTERN_MONEY_RECEIVED_SHORT)
    if not money_string then
      _, _, money_string = find(msg, PATTERN_MONEY_RECEIVE)
      if not money_string then
        _, _, money_string = find(msg, PATTERN_MONEY_GAIN)
      end
    end

    if money_string and util.isCurrencyMessage(money_string) then
      local value = util.valueFromCurrencyText(money_string)
      if value and value > 0 then
        session.lootMoney(value, L["solo"]) -- treat system money as solo income
        A:guiUpdate()
      else
        A.warn("System money message but no value found. Original message: %s", msg)
      end
      return
    end

    -- Next, try to parse quest reward items printed as system messages
    local item_link, _, id, code = parseItemLink(msg)
    if not code then return end

    local _, _, count = find(msg, "x(%d+)")
    count = count and tonumber(count) or 1

    local token = makeStoreToken(code)
    if A:isEnabled() and filter.itemMatchQuality(id) then
      local value = pricing.value(token)
      if value and value > 0 then
        A:print(string.format("%dx %s = %s", count, item_link,
          util.formatMoneyFull(count * value)))
      else
        A:print(string.format("%dx %s", count, item_link))
      end
    end

    session.lootItem(token, count, id)
    A:guiUpdate()
  end
end

do
  local GetTime = GetTime

  local find = string.find
  local makeStoreToken = util.makeStoreToken
  local parseItemLink = util.parseItemLink

  --GlobalStrings.lua: LOOT_ITEM_SELF = "You receive loot: %s."
  -- e.g. "You receive loot: [Heavy Leather]."
  --GlobalStrings.lua: LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
  -- e.g. "You receive loot: [Heavy Leather]x3."
  local PATTERN_ITEM_LOOT_SELF = "^You receive loot: (.+)%.$"
  local PATTERN_ITEM_LOOT_SELF_COUNT = "x(%d+)$"
  --GlobalStrings.lua: LOOT_ROLL_WON = "%s won: %s|Hitem:%d:%d:%d:%d|h[%s]|h%s"
  -- e.g. "You won: [Heavy Leather]"
  local PATTERN_ITEM_LOOT_WON = "^You won: (.+)"

  local LOOT_TYPE_SELF = 0
  local LOOT_TYPE_WON = 1

  local loot_type
  local last_loot_time, last_won_code, last_self_code

  local function seenTooSoon(loot_time)
    return (GetTime() - loot_time) < 1
  end

  function A:CHAT_MSG_LOOT(msg)
    local loot_string
    _, _, loot_string = find(msg, PATTERN_ITEM_LOOT_SELF)
    if loot_string then
      loot_type = LOOT_TYPE_SELF
    else
      _, _, loot_string = find(msg, PATTERN_ITEM_LOOT_WON)
      if not loot_string then return end
      loot_type = LOOT_TYPE_WON
    end

    local item_link, _, id, code = parseItemLink(loot_string)
    if code then
      -- Check for immediate duplicate item loot messages across loot types
      if last_loot_time then
        if loot_type == LOOT_TYPE_SELF
            and last_won_code and code == last_won_code
            and seenTooSoon(last_loot_time) then
          return
        elseif loot_type == LOOT_TYPE_WON
            and last_self_code and code == last_self_code
            and seenTooSoon(last_loot_time) then
          return
        end
      end

      -- Record last sucessful loot
      last_loot_time = GetTime()
      if loot_type == LOOT_TYPE_SELF then
        last_self_code = code
      elseif loot_type == LOOT_TYPE_WON then
        last_won_code = code
      end

      local token = makeStoreToken(code)
      local _, _, count = find(loot_string, PATTERN_ITEM_LOOT_SELF_COUNT)
      count = count and tonumber(count) or 1

      if A:isEnabled() and filter.itemMatchQuality(id) then
        local value = pricing.value(token)

        if value and value > 0 then
          A:print(format("%dx %s = %s", count, item_link,
            util.formatMoneyFull(count * value)))
        else
          A:print(format("%dx %s", count, item_link))
        end
      end

      session.lootItem(token, count, id)
      A:guiUpdate()
    else
      A.warn("Item loot message but no item code found. Original message: %s",
        msg)
    end
  end
end

do
  local LootSlotIsCoin = LootSlotIsCoin
  local GetTime = GetTime

  local isInGroup = util.isInGroup
 
  local money_loot_slot, money_loot_amount

  function A:LOOT_OPENED()
    --These events are checked only while solo.
    if isInGroup() then return end

    local count = GetNumLootItems()
    if count < 1 then return end

    for slot=1,count do
      local _, name, quantity = GetLootSlotInfo(slot)
      if LootSlotIsCoin(slot) then
        local value = util.extendedStringToMoney(name)
        if value and value > 0 then
          money_loot_slot = slot
          money_loot_amount = value
          --Leave because there should only be a single coin slot
          return
        end
      end
    end
  end

  function A:LOOT_SLOT_CLEARED(slot)
    if not money_loot_slot then return end
    if not slot or slot ~= money_loot_slot then return end

    if money_loot_amount then
      session.lootMoney(money_loot_amount, L["solo"])
      money_loot_slot = nil
      money_loot_amount = nil

      A:guiUpdate()
    end
  end
  function A:LOOT_CLOSED()
    money_loot_slot = nil
    money_loot_amount = nil
  end

  -- Quest reward handling: support multiple client versions
  -- WotLK: QUEST_TURNED_IN provides money directly
  function A:QUEST_TURNED_IN(questID, xpReward, moneyReward)
    -- Откроем окно ожидания чат-сообщения с полной суммой (с конверсией XP).
    quest_money_window_until = GetTime() + 5
    pending_quest_money = (moneyReward and moneyReward > 0) and moneyReward or nil
  end

  -- Vanilla/TBC compatibility: use QUEST_COMPLETE/QUEST_FINISHED
  -- Cache reward money on QUEST_COMPLETE, apply on QUEST_FINISHED
  function A:QUEST_COMPLETE()
    local GetRewardMoney = _G.GetRewardMoney
    if GetRewardMoney then
      local money = GetRewardMoney()
      pending_quest_money = money and money > 0 and money or nil
      quest_money_window_until = GetTime() + 5
    end
  end

  function A:QUEST_FINISHED()
    -- Закрытие окна квеста (ESC/Cancel) не должно начислять деньги.
    -- Если чат-сообщение о награде не пришло, учтём минимум базовую сумму.
    if pending_quest_money and pending_quest_money > 0 then
      session.lootMoney(pending_quest_money, L["solo"]) -- резервный учёт
      A:guiUpdate()
    end
    -- Сбрасываем состояние окна перехвата чата
    pending_quest_money = nil
    quest_money_window_until = nil
  end
end

function A:guiUpdate()
  gui_main.update()
  gui_config.update()
  gui_minimap.update()
end

-- Loading --

local frame = CreateFrame("Frame")
A.eventframe = frame

-- Fires when an addon and its saved variables are loaded
frame:RegisterEvent("ADDON_LOADED")
-- Fires when receiving notice that the player or a member of the player’s 
-- group has looted an item.
frame:RegisterEvent("CHAT_MSG_LOOT")
-- Fires when the player receives money as loot
frame:RegisterEvent("CHAT_MSG_MONEY")
-- Some 1.12-mod clients emit money lines as system messages
frame:RegisterEvent("CHAT_MSG_SYSTEM")
-- Fires when the player begins interaction with a lootable corpse or object
frame:RegisterEvent("LOOT_OPENED")
-- Fires when the contents of a loot slot are removed
frame:RegisterEvent("LOOT_SLOT_CLEARED")
-- Fires when the player ends interaction with a lootable corpse or object
frame:RegisterEvent("LOOT_CLOSED")
-- Fires when the quest reward is shown (Vanilla/TBC)
frame:RegisterEvent("QUEST_COMPLETE")
-- Fires when the quest window is closed (Vanilla/TBC)
frame:RegisterEvent("QUEST_FINISHED")
-- Fires when a quest is turned in (WotLK)
frame:RegisterEvent("QUEST_TURNED_IN")

frame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == A.name then
    A.is_loaded = true
    A.loaded_name = A.name
    A.setCharConfigDefaults()
    filter.populateItemType()
    gui_minimap.update()
  else
    local event_method = A[event]
    if event_method then
      event_method(A, arg1, arg2, arg3, arg4, arg5)
    end
  end
end)
