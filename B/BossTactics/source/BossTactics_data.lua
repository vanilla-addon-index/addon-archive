-- BossTactics - Data File
-- You can safely edit this file to add or change tactics.

-- Ensure the main addon table exists before we add data to it.
BossTactics = BossTactics or {};

-------------------------------------------------
-- DATA - EDIT THIS SECTION
-------------------------------------------------
-- Instructions:
-- To add a new tactic, follow the existing format.
-- - The first level is the Raid Name (e.g., "Molten Core").
-- - The second level is the Boss Name (e.g., "Lucifron").
-- - The third level is the Tactic Name (e.g., "Curse").
-- - The value is the text that will be posted to chat.
--
-- Example:
-- ["My New Raid"] = {
--   ["Some Boss"] = {
--     ["Some Tactic"] = "This is the text that will be posted.",
--     ["Another Tactic"] = "Do the thing!",
--   },
-- },
-------------------------------------------------
BossTactics.Data = {
    ["Molten Core"] = {
        ["Lucifron"] = {
            ["Mechanics"] = "Dispel Curse. Remove Impending Doom (8k dmg in 10s) and Lucifron's Curse (-5% chance to hit, +100% cost to abilities).",
        },
        ["Magmadar"] = {
            ["Mechanics"] = "Tank in the center. Run away from Frenzy (AoE fire damage). Tranquilizing Shot to remove frenzy.",
        },
        ["Gehennas"] = {
            ["Mechanics"] = "Dispel Gehennas's Curse (-75% healing). Tank adds away from Gehennas.",
        },
        ["Garr"] = {
            ["Mechanics"] = "Warlock tank adds. Do not banish. Spread out to avoid chaining Harvest.",
        },
        ["Baron Geddon"] = {
            ["Mechanics"] = "Avoid Living Bomb (run away from raid). Dispel Ignite Mana.",
        },
        ["Shazzrah"] = {
            ["Mechanics"] = "Dispel Curse of Shazzrah. Tank teleports and wipes aggro, offtank taunts.",
        },
        ["Sulfuron Harbinger"] = {
            ["Mechanics"] = "Tank and kill adds. Dispel Inspire (healing received increase).",
        },
        ["Golemagg the Incinerator"] = {
            ["Mechanics"] = "Tank boss and adds separately. Adds become invulnerable at 10%.",
        },
        ["Majordomo Executus"] = {
            ["Mechanics"] = "Kill healers first. Tank and banish adds. ",
        },
        ["Ragnaros"] = {
            ["Mechanics"] = "Melee out on Wrath of Ragnaros. Tank knockback, offtank taunts.",
        },
    },
    ["Blackwing Lair"] = {
        ["Razorgore the Untamed"] = {
            ["Mechanics"] = "Destroy eggs with Orb of Domination, protect the controller from mobs. Phase 2: kill the boss, avoid conflagration.",
        },
        ["Vaelastrasz the Corrupt"] = {
            ["Mechanics"] = "High DPS race. Healing reduced by 50%, mana burns quickly. Tanks swap due to Burning Adrenaline.",
        },
        ["Broodlord Lashlayer"] = {
            ["Mechanics"] = "Remove Blast Wave. Avoid Cleave and Mortal Strike.",
        },
        ["Firemaw"] = {
            ["Mechanics"] = "Hide behind pillar during Wing Buffet. Tanks swap due to stacks of Flame Buffet.",
        },
        ["Ebonroc"] = {
            ["Mechanics"] = "Tanks swap due to Shadow of Ebonroc. Don't heal the tank with the debuff.",
        },
        ["Flamegor"] = {
            ["Mechanics"] = "Tanks swap due to stacks of Flame Buffet. Tranquilizing Shot during Frenzy.",
        },
        ["Chromaggus"] = {
            ["Mechanics"] = "Dispel debuffs. Match resistance to breath. Tranquilizing Shot during Enrage.",
        },
        ["Nefarian"] = {
            ["Mechanics"] = "Phase 1: kill adds. Phase 2: Class call handling. Priest - no direct heals. Warlock - kill Infernals.",
        },
    },
    ["Onyxia's Lair"] = {
        ["Onyxia"] = {
            ["Mechanics"] = "Phase 1: Tank and spank. Phase 2: Avoid Fireball, kill Whelps. Phase 3: Avoid Bellowing Roar (fear).",
        },
    },
    ["Zul'Gurub"] = {
        ["High Priest Venoxis"] = {
            ["Mechanics"] = "Move out of poison clouds. Avoid Holy Fire. Dispel Renew.",
        },
        ["High Priestess Jeklik"] = {
            ["Mechanics"] = "Kill bats. Interrupt heals. Dispel Mind Flay.",
        },
        ["High Priestess Mar'li"] = {
            ["Mechanics"] = "Kill Spawn of Mar'li. Interrupt drain life. Dispel poison.",
        },
        ["High Priest Thekal"] = {
            ["Mechanics"] = "Kill all tigers simultaneously. Tank away from Zealots.",
        },
        ["High Priestess Arlokk"] = {
            ["Mechanics"] = "Kill panthers. Tank boss away from raid.",
        },
        ["Hakkar"] = {
            ["Mechanics"] = "Tank in center. Mind Control priests for Greater Heal. Drain Power to reduce damage.",
        },
    },
    ["Ruins of Ahn'Qiraj"] = {
        ["Kurinnaxx"] = {
            ["Mechanics"] = "Avoid Sand Trap. Tank swap at 10 stacks of Mortal Wound.",
        },
        ["General Rajaxx"] = {
            ["Mechanics"] = "Kill waves of adds. Tank swap at 3 stacks of Mortal Strike.",
        },
        ["Moam"] = {
            ["Mechanics"] = "Kill Mana Fiends. Tank away from raid due to Arcane Explosion.",
        },
        ["Buru the Gorger"] = {
            ["Mechanics"] = "Kite boss over eggs. Kill eggs to damage boss.",
        },
        ["Ayamiss the Hunter"] = {
            ["Mechanics"] = "Avoid poison clouds. Tank swap at 10 stacks of Stinger Spray.",
        },
        ["Ossirian the Unscarred"] = {
            ["Mechanics"] = "Kite boss to crystals to remove boss buff.",
        },
    },
};
