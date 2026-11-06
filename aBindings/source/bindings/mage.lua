local _, enclass = UnitClass('player')
if enclass ~= 'MAGE' then return end

local b = aBindings.b

b['R'] = [[
    /cast [nomod,@mouseover,harm,nodead] [nomod] Frostbolt
    
    /cast [mod:shift,@mouseover,harm,nodead] [mod:shift] Scorch
    /cast [mod:shift,@mouseover,harm,nodead] [mod:shift] Fireball
    
    /cast [mod:ctrl,@mouseover,harm,nodead] [mod:ctrl] Fire Blast
    
    /cast [mod:alt,@mouseover,harm,nodead] [mod:alt] Arcane Missiles
  ]]

b['T'] = [[
    /cast [nomod] Blizzard
    
    /cast [mod:shift] Arcane Explosion
    
    /cast [mod:ctrl] Flamestrike
  ]]

b['F'] = [[
    /cast [nomod,@mouseover,harm,nodead] [nomod] Polymorph
    
    /cast [mod:shift] Cone of Cold
    
    /cast [mod:ctrl] Frost Nova
    
    /cast [mod:alt,@mouseover,harm,nodead] [mod:alt] Frostbolt(Rank 1)
  ]]

b['G'] = [[
    /use [nomod] Iron Grenade
    
    /use [mod:shift] 
    
    /use [mod:ctrl]
    
    /use [mod:alt]
  ]]

b['B'] = [[
    /cast [nomod] Cold Snap
  ]]

b['C'] = [[
    /cast [nomod,@mouseover,harm,nodead] [nomod] Counterspell
    
    /cast [mod:shift,@mouseover,harm,nodead] [mod:shift] Detect Magic
  ]]

b['V'] = [[
    /use [nomod] Medallion of the Horde
    /use [nomod] Insignia of the Horde
    
    /use [mod:shift] Will of the Forsaken
    /use [mod:shift] Escape Artist
  ]]

b['X'] = [[
    /use [nomod] Lesser Mana Potion
    /use [nomod] Minor Mana Potion
    
    /use [mod:shift] Mana Agate
    
    /use [mod:ctrl] Evocation
    
    /run if IsAltKeyDown() then aMageDrink() end
  ]]

b['Z'] = [[
    /use [nomod] Lesser Healing Potion
    /use [nomod] Healing Potion
    /use [nomod] Minor Healing Potion
    
    /use [mod:shift,@mouseover,help,nodead] [mod:shift,@player] Heavy Linen Bandage
    /use [mod:shift,@mouseover,help,nodead] [mod:shift,@player] Linen Bandage
    
    /cast [mod:ctrl] Cannibalize
    
    /run if IsAltKeyDown() then aMageEat() end
]]

b['BUTTON4'] = [[
    /cast [nomod] Ice Barrier
    
    /cast [mod:shift] Ice Block
    
    /cast [mod:ctrl] Fire Ward
    
    /cast [mod:alt] Frost Ward
  ]]

b['BUTTON5'] = [[
    /cast [nomod] Blink
    
    /use [mod:shift] Gnomish Rocket Boots
    
    /cast [mod:ctrl] Slow Fall
  ]]

b['F5'] = [[
    /cast [nomod,@mouseover,help,nodead] [nomod,@player] Remove Lesser Curse
    
    /cast [mod:shift,@mouseover,help,nodead] [mod:shift,@player] Dampen Magic
    
    /cast [mod:ctrl,@mouseover,help,nodead] [mod:ctrl,@player] Amplify Magic
  ]]

b['F6'] = [[
    /cast [nomod] Frost Armor
    
    /cast [mod:shift] Mage Armor
    
    /cast [mod:ctrl,@mouseover,help,nodead] [mod:ctrl,@player] Arcane Intellect
    
    /cast [mod:alt,@mouseover,help,nodead] [mod:alt,@player] Arcane Brilliance
  ]]

b['F7'] = [[
    /use [nomod] Mount
    
    /run if IsAltKeyDown() then pcall(RingMenu_Toggle or function()end) end
  ]]
