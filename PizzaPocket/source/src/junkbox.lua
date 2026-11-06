local PP = PizzaPocket

PP.junkbox = {}

local JUNKBOXES = {
  ['Sturdy Junkbox'] = true,
  ['Heavy Junkbox']  = true,
}

local scanTip = CreateFrame('GameTooltip', 'PizzaPocketScanTip', nil, 'GameTooltipTemplate')
scanTip:SetOwner(WorldFrame, 'ANCHOR_NONE')

local function isLocked(bag, slot)
  scanTip:ClearLines()
  scanTip:SetBagItem(bag, slot)
  for i = 1, scanTip:NumLines() do
    local text = getglobal('PizzaPocketScanTipTextLeft' .. i)
    if text then
      local str = text:GetText()
      if str and string.find(str, 'Locked') then
        return true
      end
    end
  end
  return false
end

local function itemName(link)
  local _, _, name = string.find(link, '|h%[(.-)%]|h')
  return name
end

local function isLockedJunkbox(bag, slot)
  local link = GetContainerItemLink(bag, slot)
  if not link then return nil end
  local name = itemName(link)
  if name and JUNKBOXES[name] and isLocked(bag, slot) then return name end
  return nil
end

local function scan()
  local firstBag, firstSlot, firstName
  local count = 0
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local name = isLockedJunkbox(bag, slot)
      if name then
        count = count + 1
        if not firstBag then firstBag, firstSlot, firstName = bag, slot, name end
      end
    end
  end
  return firstBag, firstSlot, firstName, count
end

function PP.junkbox.unlock()
  local bag, slot, name, remaining = scan()
  if not bag then
    PP:Print('No locked junkboxes in bags')
    return
  end

  CastSpellByName('Pick Lock')
  PickupContainerItem(bag, slot)
  PP:Print('Unlocking ' .. name .. ' (' .. remaining .. ' remaining)')
end
