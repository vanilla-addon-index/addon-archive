local lib = LibCraftsGetLibrary()
local name, version = "Professions-Survival", 6
local module = --[[---@type LcProfessionModule]] lib:RegisterProfessionModule(name, version, "Survival")
if not module then return end

local SpellSource = lib.constants.spell_sources

--[[
Survival is a Turtle WoW secondary profession, trained at Nesingwary's
Expedition (Stranglethorn Vale). This is now the full recipe list, skill 1
through 300, triple-confirmed: a player-provided skill-up table, that same
player's own "/gmc dump" of their known trade skill entries (real result
item ids), and a follow-up "/gmc dump" of both trainer NPCs' full service
lists (every recipe on offer, known or not, with skill requirements - just
no item ids, since training a spell has no crafted-item preview). Two
skill-295 entries the original table listed with source "Recipe" rather than
"Trainer" (Oil-Powered Cooker, Prospector's Magnifying Lens) are the only
known gap - they're taught by a recipe item this addon has no id for, not by
the trainer directly, so they're left out rather than mis-tagged.

The client API has no way to read a recipe's actual spell id under any of
the three windows (trade skill, craft, or trainer) - only its name and,
for known trade-skill/craft entries, the crafted item's id. The skill
155-300 result items were instead confirmed by hand against octowow.st
(https://octowow.st/db/?item=<id>) - note that db shows both an Item ID and
an unrelated Display ID (a 3D model reference) on the same page; it's the
Item ID this needs.

Because CraftRepository matches "known vs missing" by recipe NAME (see
CharacterRepository/CraftRepository), not by spell id, every recipe below
still uses a safe placeholder spell id (900001+, an id range nowhere near
any real Blizzard or Turtle spell) where the real one isn't confirmed -
7 recipes have a real one, the rest don't. That doesn't affect accuracy:
every recipe below (all 87) now has a real result item id, and the tooltip
always prefers that over the spell id (see CraftsListItem:_DrawTooltip), so
a placeholder spell id never actually surfaces anywhere.
]]

if lib.env.is_turtle_wow then
    -- Confirmed real spell ids
    module:NewCraft(46064, "Dim Torch", 1, {SpellSource.Trainer})
        :SetResult(6182)
        :Save()

    module:NewCraft(47101, "Survivalist's Skinning Knife", 10, {SpellSource.Trainer})
        :SetResult(7009)
        :Save()

    module:NewCraft(47103, "Driftwood Fishing Pole", 10, {SpellSource.Trainer})
        :SetResult(7010)
        :Save()

    module:NewCraft(46072, "Traveler's Tent", 80, {SpellSource.Trainer})
        :SetResult(51283)
        :Save()

    module:NewCraft(46073, "Fishing Boat", 115, {SpellSource.Trainer})
        :SetResult(51282)
        :Save()

    module:NewCraft(46066, "Murloc's Flippers", 125, {SpellSource.Trainer})
        :SetResult(65028)
        :Save()

    module:NewCraft(46077, "Repaired Electro-Lantern", 230, {SpellSource.Trainer})
        :SetResult(65030)
        :Save()

    -- Placeholder spell ids (900001+) - real names/skill levels/result items,
    -- see header comment
    module:NewCraft(900001, "Bundle of Simple Sticks", 5, {SpellSource.Trainer})
        :SetResult(42149)
        :Save()

    module:NewCraft(900002, "Crude Hunting Bow", 15, {SpellSource.Trainer})
        :SetResult(42092)
        :Save()

    module:NewCraft(900003, "Crude Hatchet", 15, {SpellSource.Trainer})
        :SetResult(42091)
        :Save()

    module:NewCraft(900004, "Crude Machete", 15, {SpellSource.Trainer})
        :SetResult(42090)
        :Save()

    module:NewCraft(900005, "Crude Walking Stick", 15, {SpellSource.Trainer})
        :SetResult(42089)
        :Save()

    module:NewCraft(900006, "Copper Lantern", 20, {SpellSource.Trainer})
        :SetResult(42093)
        :Save()

    module:NewCraft(900007, "Simple Slingshot", 30, {SpellSource.Trainer})
        :SetResult(42229)
        :Save()

    module:NewCraft(900008, "Simple Herbalist's Backpack", 40, {SpellSource.Trainer})
        :SetResult(33369)
        :Save()

    module:NewCraft(900009, "Makeshift Rations Bag", 40, {SpellSource.Trainer})
        :SetResult(33370)
        :Save()

    module:NewCraft(900010, "Weak Healing Salve", 50, {SpellSource.Trainer})
        :SetResult(42233)
        :Save()

    module:NewCraft(900011, "Makeshift Knife", 60, {SpellSource.Trainer})
        :SetResult(42094)
        :Save()

    module:NewCraft(900012, "Gardening Gloves", 65, {SpellSource.Trainer})
        :SetResult(42095)
        :Save()

    module:NewCraft(900013, "Crude Fishing Rod", 70, {SpellSource.Trainer})
        :SetResult(42096)
        :Save()

    module:NewCraft(900014, "Hunting Spear", 90, {SpellSource.Trainer})
        :SetResult(42097)
        :Save()

    module:NewCraft(900015, "Gardening Broom", 95, {SpellSource.Trainer})
        :SetResult(42098)
        :Save()

    module:NewCraft(900016, "Healing Salve", 100, {SpellSource.Trainer})
        :SetResult(42125)
        :Save()

    module:NewCraft(900017, "Oakwood Bow", 100, {SpellSource.Trainer})
        :SetResult(42099)
        :Save()

    module:NewCraft(900018, "Simple Fishing Lure", 100, {SpellSource.Trainer})
        :SetResult(114)
        :Save()

    module:NewCraft(900019, "Fishing Bag", 105, {SpellSource.Trainer})
        :SetResult(33371)
        :Save()

    module:NewCraft(900020, "Skinner's Pack", 110, {SpellSource.Trainer})
        :SetResult(33372)
        :Save()

    module:NewCraft(900021, "Gardening Pitchfork", 120, {SpellSource.Trainer})
        :SetResult(42100)
        :Save()

    module:NewCraft(900022, "Blackmouth Fishing Trap", 125, {SpellSource.Trainer})
        :SetResult(42329)
        :Save()

    module:NewCraft(900023, "Bundle of Bright Wood Sticks", 125, {SpellSource.Trainer})
        :SetResult(42150)
        :Save()

    module:NewCraft(900024, "Murloc Scale Coat", 125, {SpellSource.Trainer})
        :SetResult(42101)
        :Save()

    module:NewCraft(900025, "Sturdy Blade", 130, {SpellSource.Trainer})
        :SetResult(42104)
        :Save()

    module:NewCraft(900026, "Sturdy Cane", 130, {SpellSource.Trainer})
        :SetResult(42102)
        :Save()

    module:NewCraft(900027, "Sturdy Knife", 130, {SpellSource.Trainer})
        :SetResult(42103)
        :Save()

    module:NewCraft(900028, "Sturdy Net", 130, {SpellSource.Trainer})
        :SetResult(42154)
        :Save()

    module:NewCraft(900029, "Reliable Fishing Rod", 135, {SpellSource.Trainer})
        :SetResult(42105)
        :Save()

    module:NewCraft(900030, "Hat of the Junior Chef", 140, {SpellSource.Trainer})
        :SetResult(42106)
        :Save()

    module:NewCraft(900031, "Rugged Mining Sack", 140, {SpellSource.Trainer})
        :SetResult(42294)
        :Save()

    module:NewCraft(900032, "Throwable Net", 140, {SpellSource.Trainer})
        :SetResult(42132)
        :Save()

    module:NewCraft(900033, "Bright Wood Arrows", 145, {SpellSource.Trainer})
        :SetResult(42198)
        :Save()

    module:NewCraft(900034, "Treasure Compass", 145, {SpellSource.Trainer})
        :SetResult(42107)
        :Save()

    module:NewCraft(900035, "Potent Healing Salve", 150, {SpellSource.Trainer})
        :SetResult(42126)
        :Save()

    module:NewCraft(900036, "Spicy Fishing Lure", 150, {SpellSource.Trainer})
        :SetResult(125)
        :Save()

    module:NewCraft(900037, "Studded Rations Bag", 150, {SpellSource.Trainer})
        :SetResult(33373)
        :Save()

    -- Placeholder spell ids (skill 155+), but real result items now -
    -- confirmed via a player pulling Item IDs (not Display IDs - a
    -- different number on the same db page) off octowow.st
    module:NewCraft(900038, "Slowing Bolas", 155, {SpellSource.Trainer}):SetResult(106):Save()
    module:NewCraft(900039, "Iron Lantern", 160, {SpellSource.Trainer}):SetResult(2714):Save()
    module:NewCraft(900040, "Snap Trap", 160, {SpellSource.Trainer}):SetResult(42328):Save()
    module:NewCraft(900041, "Edged Machete", 165, {SpellSource.Trainer}):SetResult(42108):Save()
    module:NewCraft(900042, "Iron Spear", 165, {SpellSource.Trainer}):SetResult(42109):Save()
    module:NewCraft(900043, "Reinforced Fishing Rod", 170, {SpellSource.Trainer}):SetResult(42110):Save()
    module:NewCraft(900044, "Bundle of Shade Wood Sticks", 175, {SpellSource.Trainer}):SetResult(42151):Save()
    module:NewCraft(900045, "Firefin Fishing Trap", 175, {SpellSource.Trainer}):SetResult(42330):Save()
    module:NewCraft(900046, "Water Trudgers", 175, {SpellSource.Trainer}):SetResult(42111):Save()
    module:NewCraft(900047, "Cleaning Cloth", 180, {SpellSource.Trainer}):SetResult(60001):Save()
    module:NewCraft(900048, "Sharpened Herb Sickle", 180, {SpellSource.Trainer}):SetResult(42112):Save()
    module:NewCraft(900049, "Lined Wintercloak", 185, {SpellSource.Trainer}):SetResult(42113):Save()
    module:NewCraft(900050, "Sleek Pinewood Bow", 190, {SpellSource.Trainer}):SetResult(42114):Save()
    module:NewCraft(900051, "Savory Fishing Lure", 200, {SpellSource.Trainer}):SetResult(133):Save()
    module:NewCraft(900052, "Superior Healing Salve", 200, {SpellSource.Trainer}):SetResult(42127):Save()
    module:NewCraft(900053, "Nutritious Rations", 205, {SpellSource.Trainer}):SetResult(42155):Save()
    module:NewCraft(900054, "Shade Wood Arrows", 205, {SpellSource.Trainer}):SetResult(42199):Save()
    module:NewCraft(900055, "Hiking Staff", 215, {SpellSource.Trainer}):SetResult(42116):Save()
    module:NewCraft(900056, "Tree Hatchet", 215, {SpellSource.Trainer}):SetResult(42117):Save()
    module:NewCraft(900057, "Vine Cutter", 215, {SpellSource.Trainer}):SetResult(42115):Save()
    module:NewCraft(900058, "Bundle of Tropical Sticks", 225, {SpellSource.Trainer}):SetResult(42152):Save()
    module:NewCraft(900059, "Sunshade Hat", 235, {SpellSource.Trainer}):SetResult(42118):Save()
    module:NewCraft(900060, "Thick Rations Bag", 235, {SpellSource.Trainer}):SetResult(33374):Save()
    module:NewCraft(900061, "Aromatic Berries", 240, {SpellSource.Trainer}):SetResult(42131):Save()
    module:NewCraft(900062, "Spiced Berries", 240, {SpellSource.Trainer}):SetResult(42130):Save()
    module:NewCraft(900063, "Warped Recurve Bow", 240, {SpellSource.Trainer}):SetResult(42119):Save()
    module:NewCraft(900064, "Advanced Camouflage", 245, {SpellSource.Trainer}):SetResult(42230):Save()
    module:NewCraft(900065, "Emergency Parachute", 250, {SpellSource.Trainer}):SetResult(42156):Save()
    module:NewCraft(900066, "Premium Fishing Lure", 250, {SpellSource.Trainer}):SetResult(145):Save()
    module:NewCraft(900067, "Stabilizing Healing Salve", 250, {SpellSource.Trainer}):SetResult(42128):Save()
    module:NewCraft(900068, "Smooth Ironfeather Arrows", 255, {SpellSource.Trainer}):SetResult(42200):Save()
    module:NewCraft(900069, "Heavy Duty Machete", 260, {SpellSource.Trainer}):SetResult(42120):Save()
    module:NewCraft(900070, "Thorium Edged Machete", 260, {SpellSource.Trainer}):SetResult(42121):Save()
    module:NewCraft(900071, "Thorium Spear", 265, {SpellSource.Trainer}):SetResult(42122):Save()
    module:NewCraft(900072, "Bundle of Star Wood Sticks", 270, {SpellSource.Trainer}):SetResult(42153):Save()
    module:NewCraft(900073, "Razor-sharp Skinning Knife", 270, {SpellSource.Trainer}):SetResult(42124):Save()
    module:NewCraft(900074, "Mastercraft Fishing Rod", 275, {SpellSource.Trainer}):SetResult(42123):Save()
    module:NewCraft(900075, "Stonescale Fishing Trap", 275, {SpellSource.Trainer}):SetResult(42331):Save()
    module:NewCraft(900076, "Miner's Rucksack", 280, {SpellSource.Trainer}):SetResult(33375):Save()
    module:NewCraft(900077, "Herbalist's Knapsack", 285, {SpellSource.Trainer}):SetResult(33376):Save()
    module:NewCraft(900078, "Skinner's Carryall", 285, {SpellSource.Trainer}):SetResult(33378):Save()
    module:NewCraft(900079, "Cooling Rations Bag", 290, {SpellSource.Trainer}):SetResult(33379):Save()
    module:NewCraft(900080, "Major Healing Salve", 300, {SpellSource.Trainer}):SetResult(42129):Save()
end
