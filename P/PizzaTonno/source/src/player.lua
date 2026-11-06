local PT = PizzaTonno
PT.player = {}

local NAT_PAGLES_FISH_TERMINATOR = 19944

local skillIndex

function PT.player.location()
  return GetRealZoneText(), GetSubZoneText()
end

-- Fishing skill the server rolls with: rank plus the modifier, which already holds gear and lure.
function PT.player.skill()
  if not skillIndex or GetSkillLineInfo(skillIndex) ~= 'Fishing' then
    skillIndex = nil
    for i = 1, GetNumSkillLines() do
      if GetSkillLineInfo(i) == 'Fishing' then
        skillIndex = i
        break
      end
    end
    if not skillIndex then return 0, 0, 0 end
  end

  local _, _, _, rank, _, modifier = GetSkillLineInfo(skillIndex)
  return rank + modifier, rank, modifier
end

-- Seconds left on the lure, nil without one. A pole carries no other weapon enchant.
function PT.player.lure()
  local hasEnchant, msLeft = GetWeaponEnchantInfo()
  if hasEnchant then return msLeft / 1000 end
end

function PT.player.hasPole()
  local slot = GetInventorySlotInfo('MainHandSlot')
  local texture = GetInventoryItemTexture('player', slot)
  if not texture or not string.find(texture, 'INV_Fishingpole') then return false end

  -- a mace with a fishing pole icon
  return PT.utils.itemId(GetInventoryItemLink('player', slot)) ~= NAT_PAGLES_FISH_TERMINATOR
end
