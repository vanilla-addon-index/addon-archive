-- EGM mail: bag counts. Only unlocked stacks in bags 0-4 count as mailable.
EGM = EGM or {}
EGM.Bags = EGM.Bags or {}
local B = EGM.Bags

local function idFromLink(link)
  if not link then return nil end
  if EGM.Util and EGM.Util.itemIdFromLink then
    local id = EGM.Util.itemIdFromLink(link)
    return tonumber(id)
  end
  local _, _, id = string.find(link, "item:(%d+)")
  return id and tonumber(id) or nil
end

-- array of {bag, slot, count} for item id (unlocked slots only)
function B.stacks(item)
  local out = {}
  item = tonumber(item)
  if not item then return out end
  for bag = 0, 4 do
    local n = GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      local link = GetContainerItemLink(bag, slot)
      if link and idFromLink(link) == item then
        local _, count, locked = EGM.Util.real("GetContainerItemInfo")(bag, slot)
        if count and not locked then
          table.insert(out, { bag = bag, slot = slot, count = count })
        end
      end
    end
  end
  return out
end

function B.count(item)
  local s = B.stacks(item)
  local total = 0
  for i = 1, table.getn(s) do total = total + s[i].count end
  return total
end

-- first empty slot -> bag, slot (or nil)
function B.freeSlot()
  for bag = 0, 4 do
    local n = GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      if not GetContainerItemLink(bag, slot) then return bag, slot end
    end
  end
  return nil
end

if CreateFrame then
  local f = CreateFrame("Frame", "EGMBagsFrame")
  f:RegisterEvent("BAG_UPDATE")
  f:SetScript("OnEvent", function()
    if EGM.Fire then EGM.Fire("BAGS") end
  end)
end
