local _, enclass = UnitClass('player')
if enclass ~= 'ROGUE' then return end

local b = aBindings.b

b['R'] = [[
    /run if IsAltKeyDown() then return end; for z=1,172 do if IsAttackAction(z)then if not IsCurrentAction(z)then UseAction(z);end;end;end    
    
    /cast [nomod] Sinister Strike
    
    /cast [mod:shift] Eviscerate
    
    /cast [mod:ctrl] Riposte
    /cast [mod:ctrl] Backstab
    
    /cast [mod:alt] Ambush
  ]]
  
b[1] = [[
    /cast [nomod,@mouseover,harm,nodead] [nomod] Throw
  ]]

b['T'] = [[
    /cast [nomod] Slice and Dice
    
    /cast [mod:shift] Blade Flurry
    /cast [mod:shift] Premeditation
    /cast [mod:shift] Cold Blood
    
    /cast [mod:ctrl] Preparation
  ]]

b['F'] = [[
    /cast [nomod,@mouseover,harm,nodead] [nomod] Sap
    
    /cast [mod:shift,@mouseover,harm,nodead] [mod:shift] Gouge
    
    /cast [mod:ctrl] Kidney Shot
    
    /cast [mod:alt] Cheap Shot
  ]]

b['G'] = [[
    /cast [nomod,@mouseover,harm,nodead] [nomod] Blind
    
    /cast [mod:shift] Gnomish Net-o-Matic Projector
    
    /cast [mod:ctrl] Expose Armor
    
    /use [mod:alt] Distract
  ]]

b['B'] = [[
    /cast [nomod] Garrote
    
    /cast [mod:shift] Rupture
  ]]

b['V'] = [[
    /cast [nomod] Evasion
    
    /cast [mod:shift] Ghostly Strike
    
    /use [mod:ctrl] Flame Deflector
  ]]

b['C'] = [[
    /cast [nomod,@mouseover,harm,nodead] [nomod] Kick
  ]]

b['X'] = [[
    /use [nomod] Medallion of the Alliance
    /use [nomod] Insignia of the Alliance
    
    /cast [mod:shift] Will of the Forsaken
    /cast [mod:shift] Escape Artist
  ]]

b['Z'] = [[
    /use [nomod] Lesser Healing Potion
    /use [nomod] Minor Rejuvenation Potion
    /use [nomod] Minor Healing Potion
    
    /use [mod:shift,@mouseover,help,nodead] [mod:shift] Heavy Linen Bandage
    /use [mod:shift,@mouseover,help,nodead] [mod:shift] Linen Bandage
    
    /use [mod:ctrl] Thistle Tea
    
    /use [mod:alt] Conjured Muffin
    /use [mod:alt] Dalaran Sharp
    /use [mod:alt] Tough Jerky
    /use [mod:alt] Charred Wolf Meat
    /use [mod:alt] Healing Herb
    /use [mod:alt] Raw Slitherskin Mackerel
    /use [mod:alt] Forest Mushroom Cap
    /use [mod:alt] Freshly Baked Bread
    /use [mod:alt] 
  ]]

b['BUTTON4'] = [[
    /cast [nomod] Stealth
    
    /cast [mod:shift] Vanish
    
    /cast [mod:ctrl] Feint
  ]]

b['BUTTON5'] = [[
    /cast [nomod] Sprint
    
    /use [mod:shift] Swiftness Potion
    
    /use [mod:ctrl] Gnomish Rocket Boots
    
    /use [mod:ctr] Parachute Cloak
  ]]

b['F5'] = [[
    /run if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then return end; for z=1,172 do if IsAttackAction(z)then if not IsCurrentAction(z)then UseAction(z);end;end;end    
    /cast [nomod,harm,nodead] Backstab
    
    /use [mod:shift] Dark Iron Bomb
    /use [mod:shift] Big Iron Bomb
    /use [mod:shift] Big Bronze Bomb
    /use [mod:shift] Explosive Rocket
    
    /use [mod:ctrl] Arcane Bomb
    
    /use [mod:alt] Gnomish Alarm-O-Bot
  ]]

b['F6'] = [[
    /use [nomod] Engineering Item
  ]]

b['F7'] = [[
    /use [nomod] Mount
    
    /cast [mod:shift,@mouseover,harm,nodead] Pick Pocket; [mod:shift] Pick Lock
    
    /cast [mod:ctrl] Fishing
    
    /run if IsAltKeyDown() then pcall(RingMenu_Toggle or function()end) end
  ]]
