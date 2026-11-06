#!/usr/bin/env python3
"""Talent builds for the Talent Advisor (Part 4), checked against Turtle WoW's
own trees, and written to Tools/data/talent_builds.json (for the review page),
TalentBuilds.lua (what the addon follows) and Tools/tests/talent_trees.lua (the
trees, for the Lua tests).

The trees are the game's: `/apg talents` saved them on a character of each
class (read_talent_trees.py took them out of the saved settings into
Tools/data/turtle_talent_trees.json). Turtle WoW has reworked every class,
so nothing here comes from the original game's trees.

  * A levelling build for every class: the order its points go in, one a
    level from 10, so that by 60 all 51 are spent. Some classes have another
    to choose instead -- Protection for a Warrior or Paladin who levels
    with a shield, Bear for a Druid who tanks.
  * A build at 60 for each of the class's three specs: the talents and their
    ranks, which is all a build at 60 needs, as the points are spent at once.

Every build is checked: talents the class has, no more ranks than a talent
has, 5 points in a tree for each row down, prerequisites at full rank before
the talent, and 51 points. A levelling build is checked point by point, in
its order, as the game would let it be learnt.

RestedXP's Classic levelling orders (import_rxp_talents.py) were the starting
point for the levelling builds, where Turtle WoW kept the talents they used;
the talents of theirs that Turtle WoW has no longer are listed with each
class.

  python3 Tools/build/talent_builds.py [--check]

With --check it writes nothing, and fails if a build has a problem or a
committed file is not what it would write.
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TREES = os.path.join(ROOT, "Tools", "data", "turtle_talent_trees.json")
RXP = os.path.join(ROOT, "Tools", "data", "rxp_classic_talents.json")
OUT = os.path.join(ROOT, "Tools", "data", "talent_builds.json")
LUA_OUT = os.path.join(ROOT, "TalentBuilds.lua")
FIXTURE_OUT = os.path.join(ROOT, "Tools", "tests", "talent_trees.lua")

POINTS = 51          # one a level from 10 to 60
FIRST_LEVEL = 10

# The levelling build for each class: its spec, why, and its talents in the
# order they are learnt, "talent rank" a line, the rank it is taken up to.
LEVELLING = {
    "WARRIOR": ("Arms", "Arms, then Fury. Improved Rend and Deep Wounds bleed what you hit, Sweeping Strikes and "
                "Master of Arms speed up every kill, and Mortal Strike lands at 40. Fury's crit and rage talents "
                "follow.", """
        Improved Heroic Strike 3
        Improved Rend 2
        Improved Charge 2
        Tactical Mastery 3
        Deep Wounds 3
        Improved Overpower 2
        Two-Handed Weapon Specialization 3
        Impale 2
        Sweeping Strikes 1
        Master Strike 1
        Master of Arms 5
        Tactical Mastery 5
        Deflection 1
        Mortal Strike 1
        Cruelty 5
        Unbridled Wrath 5
        Improved Shouts 5
        Enrage 5
    """),
    "MAGE": ("Frost", "Frost. Improved Frostbolt, Frost Nova and Shatter let you freeze a mob and crit it down, "
             "Ice Block and Ice Barrier keep you alive, and Arcane Concentration's free casts save mana from 46.",
             """
        Improved Frostbolt 5
        Piercing Ice 3
        Permafrost 2
        Ice Shards 5
        Frost Channeling 3
        Improved Frost Nova 2
        Ice Block 1
        Shatter 5
        Cold Snap 1
        Elemental Precision 3
        Ice Barrier 1
        Arcane Subtlety 2
        Magic Absorption 3
        Arcane Concentration 5
        Permafrost 3
        Improved Blizzard 3
        Winter's Chill 5
        Frostbite 1
    """),
    "ROGUE": ("Combat", "Combat. Lightning Reflexes and Deflection keep you standing, Precision and Dual Wield "
              "Specialization make both weapons hit, and Surprise Attack, Blade Rush and Adrenaline Rush follow "
              "by 40. Assassination's crits and Slice and Dice after.", """
        Lightning Reflexes 5
        Precision 5
        Deflection 5
        Dual Wield Specialization 5
        Surprise Attack 1
        Weapon Expertise 2
        Hack and Slash 2
        Blade Rush 2
        Aggression 3
        Adrenaline Rush 1
        Malice 5
        Ruthlessness 3
        Murder 2
        Relentless Strikes 1
        Lethality 5
        Improved Blade Tactics 3
        Improved Eviscerate 1
    """),
    "PRIEST": ("Shadow", "Shadow, with a wand. Wand Specialization and Spirit Tap keep your mana up between "
               "kills, Mind Flay and Shadow Weaving do the damage, Vampiric Embrace heals you, and Shadowform "
               "comes at 42.", """
        Wand Specialization 2
        Spirit Tap 5
        Improved Shadow Word: Pain 2
        Improved Mind Blast 5
        Mind Flay 1
        Shadow Focus 2
        Shadow Weaving 5
        Vampiric Embrace 1
        Shadow Reach 2
        Shadow Focus 4
        Darkness 5
        Shadowform 1
        Vampiric Touch 2
        Blackout 5
        Shadow Focus 5
        Mental Agility 5
        Unbreakable Will 3
        Meditation 2
    """),
    "WARLOCK": ("Affliction", "Affliction, then Demonology. Instant Corruption, Siphon Life and Dark Harvest kill "
                "with damage over time while you drain your health back; from 41 your demon gets stronger and "
                "cheaper to summon.", """
        Improved Corruption 5
        Improved Life Tap 2
        Improved Drains 2
        Suppression 1
        Improved Curse of Agony 3
        Fel Concentration 2
        Nightfall 2
        Grim Reach 2
        Suppression 2
        Siphon Life 1
        Rapid Deterioration 2
        Suppression 4
        Shadow Mastery 5
        Dark Harvest 1
        Demonic Embrace 5
        Demonic Aegis 3
        Fel Intellect 2
        Fel Domination 1
        Fel Stamina 4
        Master Summoner 2
        Unholy Power 3
    """),
    "HUNTER": ("Beast Mastery", "Beast Mastery. Your pet does the tanking and much of the damage: Unleashed Fury, "
               "Ferocity and Frenzy for its damage, Bestial Wrath and Spirit Bond, and Kill Command at 40. "
               "Marksmanship's crits after.", """
        Swift Aspects 5
        Thick Hide 3
        Endurance Training 2
        Unleashed Fury 5
        Ferocity 5
        Scent of Blood 3
        Bestial Wrath 1
        Intimidation 1
        Spirit Bond 2
        Frenzy 3
        Kill Command 1
        Frenzy 5
        Endurance Training 5
        Bestial Discipline 2
        Efficiency 5
        Lethal Shots 5
        Aimed Shot 1
        Hawk Eye 2
    """),
    "PALADIN": ("Retribution", "Retribution with a two-hander. Benediction for mana, Conviction and Vengeance for "
                "crits, Seal of Command at 30 and Vengeful Strikes by 40; Divine Strength, then Protection's "
                "Precision to hit more often.", """
        Benediction 5
        Improved Judgement 2
        Improved Seal of the Crusader 3
        Conviction 5
        Two-Handed Weapon Specialization 3
        Pursuit of Justice 2
        Seal of Command 1
        Vengeance 5
        Vengeful Strikes 5
        Divine Strength 5
        Vindication 3
        Repentance 1
        Improved Devotion Aura 5
        Precision 3
        Toughness 3
    """),
    "SHAMAN": ("Enhancement", "Enhancement. Ancestral Knowledge, Thundering Strikes and Flurry, Stormstrike at "
               "30, and Bloodlust at 41; Elemental's cheaper, harder shocks and Clearcasting from your melee "
               "crits follow.", """
        Ancestral Knowledge 5
        Thundering Strikes 5
        Ancestral Guardian 3
        Improved Ghost Wolf 2
        Flurry 5
        Stormstrike 1
        Elemental Weapons 3
        Enhancing Totems 2
        Element's Grace 5
        Bloodlust 1
        Convection 5
        Concussion 5
        Elemental Devastation 3
        Elemental Focus 1
        Reverberation 3
        Call of Flame 2
    """),
    "DRUID": ("Feral Combat", "Feral. Cat form for damage, bear when it goes wrong: Ferocity, Sharpened Claws and "
              "Predatory Strikes, Feral Swiftness to get around, Heart of the Wild and Leader of the Pack by 40. "
              "Omen of Clarity at 51, then Furor.", """
        Ferocity 5
        Thick Hide 3
        Open Wounds 2
        Sharpened Claws 3
        Feral Swiftness 2
        Predatory Strikes 3
        Primal Fury 2
        Improved Shred 2
        Berserk 1
        Blood Frenzy 2
        Heart of the Wild 5
        Leader of the Pack 1
        Nature's Grasp 1
        Improved Nature's Grasp 4
        Natural Weapons 3
        Natural Shapeshifter 2
        Omen of Clarity 1
        Open Wounds 3
        Carnage 2
        Feral Charge 1
        Furor 5
    """),
}

# The other levelling builds a class may choose: name, spec, why, and the
# order, as LEVELLING's.
LEVELLING_ALTS = {
    "WARRIOR": [
        ("Protection", "Protection", "Protection with a shield from 10. Shield Specialization gives rage on "
         "every block, Improved Revenge stuns, Last Stand at 25, Shield Slam at 30 and Concussion Blow at 40; "
         "then Arms' Tactical Mastery and Deep Wounds.", """
            Shield Specialization 5
            Toughness 5
            Improved Revenge 3
            Improved Bloodrage 2
            Last Stand 1
            Defiance 4
            Shield Slam 1
            One-Handed Weapon Specialization 5
            Improved Shield Slam 2
            Reprisal 2
            Concussion Blow 1
            Defiance 5
            Defensive Tactics 3
            Improved Heroic Strike 3
            Tactical Mastery 5
            Improved Rend 2
            Deep Wounds 3
            Improved Charge 2
            Deflection 1
        """),
    ],
    "PALADIN": [
        ("Protection", "Protection", "Protection with a shield from 10. Redoubt and Shield Specialization "
         "block and give mana back, Holy Shield at 30 with Reckoning's extra attacks, Righteous Strikes and "
         "Bulwark of the Righteous at 41; then Holy's Divine Strength and Divine Intellect.", """
            Redoubt 5
            Precision 3
            Toughness 2
            Blessing of Sanctuary 1
            Shield Specialization 3
            Toughness 5
            Improved Hammer of Justice 3
            Holy Shield 1
            Reckoning 5
            Righteous Strikes 5
            Bulwark of the Righteous 1
            Improved Righteous Fury 3
            Righteous Defense 3
            Anticipation 3
            Divine Strength 5
            Divine Intellect 5
        """),
    ],
    "DRUID": [
        ("Bear", "Feral Combat", "Bear form from 10. Ferocity, Thick Hide and Feral Instinct to tank, Sharpened "
         "Claws and Primal Fury for rage, Feral Charge at 28, Heart of the Wild by 39 and Leader of the Pack at "
         "40; Balance's Omen of Clarity at 60.", """
            Ferocity 5
            Thick Hide 3
            Feral Instinct 2
            Sharpened Claws 3
            Primal Fury 2
            Predatory Strikes 3
            Feral Charge 1
            Feral Swiftness 2
            Feral Instinct 3
            Ancient Brutality 2
            Berserk 1
            Heart of the Wild 5
            Leader of the Pack 1
            Carnage 2
            Blood Frenzy 2
            Feral Aggression 5
            Nature's Grasp 1
            Improved Nature's Grasp 4
            Natural Weapons 3
            Natural Shapeshifter 2
            Omen of Clarity 1
        """),
    ],
}

# Builds at 60: the spec, what it is for, and its talents, "talent rank" a line.
SPECS = {
    "WARRIOR": [
        ("Arms", "Mortal Strike with a two-hander and Master of Arms for your weapon: questing at 60, PvP, and "
         "dungeons before Fury gear.", """
            Improved Heroic Strike 3, Tactical Mastery 5, Improved Rend 2, Improved Charge 2, Deflection 1,
            Master Strike 1, Improved Overpower 2, Deep Wounds 3, Two-Handed Weapon Specialization 3, Impale 2,
            Master of Arms 5, Sweeping Strikes 1, Mortal Strike 1,
            Cruelty 5, Unbridled Wrath 5, Improved Shouts 5, Enrage 5
        """),
        ("Fury", "Dual wield with Flurry and Bloodthirst: the raid damage build.", """
            Improved Heroic Strike 3, Tactical Mastery 5, Improved Rend 2, Improved Overpower 2, Deep Wounds 3,
            Impale 2,
            Cruelty 5, Dual Wield Specialization 5, Unbridled Wrath 5, Improved Shouts 5, Enrage 5,
            Death Wish 1, Improved Execute 2, Flurry 5, Bloodthirst 1
        """),
        ("Protection", "Shield Slam tank with Defiance and Concussion Blow: holds threat and lasts in dungeons "
         "and raids.", """
            Improved Heroic Strike 3, Tactical Mastery 5, Improved Rend 2, Deflection 5,
            Improved Bloodrage 2, Shield Specialization 5, Anticipation 3, Toughness 5, Last Stand 1,
            Improved Taunt 1, Improved Revenge 3, Defiance 5, One-Handed Weapon Specialization 5, Shield Slam 1,
            Improved Shield Slam 2, Reprisal 2, Concussion Blow 1
        """),
    ],
    "MAGE": [
        ("Arcane", "Arcane Missiles and Arcane Rupture, Presence of Mind and Arcane Power, with Frost Nova and "
         "slows to kite: burst for PvP.", """
            Arcane Subtlety 2, Magic Absorption 1, Improved Arcane Missiles 5, Arcane Focus 5,
            Arcane Concentration 5, Arcane Impact 3, Arcane Rupture 1, Temporal Convergence 3,
            Arcane Meditation 3, Arcane Instability 3, Presence of Mind 1, Accelerated Arcana 1,
            Arcane Potency 2, Resonance Cascade 5, Arcane Power 1,
            Improved Frostbolt 5, Improved Frost Nova 2, Permafrost 3
        """),
        ("Fire", "Ignite, Hot Streak and Combustion, with Arcane's Clearcasting: raid damage where fire "
         "resistance allows.", """
            Arcane Subtlety 2, Magic Absorption 3, Arcane Concentration 5,
            Improved Fireball 5, Ignite 5, Flame Throwing 2, Improved Fire Blast 3, Incinerate 2,
            Improved Flamestrike 3, Pyroblast 1, Burning Soul 2, Fire Vulnerability 3, Master of Elements 3,
            Blast Wave 1, Critical Mass 3, Hot Streak 2, Fire Power 5, Combustion 1
        """),
        ("Frost", "Winter's Chill, Icicles and Flash Freeze, with Arcane's Clearcasting: steady raid damage.", """
            Arcane Subtlety 2, Magic Absorption 3, Arcane Concentration 5,
            Improved Frostbolt 5, Elemental Precision 3, Piercing Ice 3, Frostbite 3, Ice Shards 5,
            Cold Snap 1, Improved Blizzard 3, Arctic Reach 2, Frost Channeling 3, Ice Block 1, Icicles 1,
            Improved Cone of Cold 3, Winter's Chill 5, Flash Freeze 2, Ice Barrier 1
        """),
    ],
    "ROGUE": [
        ("Assassination", "Seal Fate, Envenom and Noxious Assault: poisons from both weapons and combo points "
         "from crits.", """
            Malice 5, Ruthlessness 3, Murder 2, Improved Blade Tactics 3, Relentless Strikes 1, Lethality 5,
            Vile Poisons 3, Improved Poisons 3, Envenom 1, Cold Blood 1, Seal Fate 5, Noxious Assault 1,
            Opportunity 5, Precision 5, Improved Backstab 3, Deflection 2, Dual Wield Specialization 3
        """),
        ("Combat", "Precision, Weapon Expertise, Blade Rush and Adrenaline Rush, Hack and Slash with swords or "
         "axes: the raid damage build.", """
            Malice 5, Ruthlessness 3, Murder 2, Improved Blade Tactics 3, Relentless Strikes 1, Lethality 5,
            Lightning Reflexes 5, Precision 5, Deflection 5, Riposte 1, Dual Wield Specialization 5,
            Weapon Expertise 2, Hack and Slash 2, Surprise Attack 1, Blade Rush 2, Aggression 3,
            Adrenaline Rush 1
        """),
        ("Subtlety", "Hemorrhage, Preparation and Mark for Death, with Honor Among Thieves and Tricks of the "
         "Trade for the group: control and burst for PvP.", """
            Improved Eviscerate 2, Malice 5, Ruthlessness 3, Murder 2, Improved Blade Tactics 3,
            Relentless Strikes 1,
            Camouflage 5, Improved Ambush 3, Elusiveness 2, Serrated Blades 3, Initiative 3, Hemorrhage 1,
            Cloaked in Shadows 2, Blackjack 2, Dirty Deeds 2, Preparation 1, Shadow of Death 1, Bloody Mess 2,
            Honor Among Thieves 2, Tricks of the Trade 5, Mark for Death 1
        """),
    ],
    "PRIEST": [
        ("Discipline", "Smite and Holy Fire: Searing Light, Purifying Flames, Force of Will and Chastise, with "
         "Holy's Divine Fury and Spiritual Guidance.", """
            Piercing Light 3, Mental Agility 5, Improved Power Word: Fortitude 2, Inner Focus 1,
            Improved Power Word: Shield 3, Meditation 3, Searing Light 3, Purifying Flames 2,
            Mental Strength 3, Enlighten 1, Resurgent Shield 1, Force of Will 5, Chastise 1,
            Divinity 5, Divine Fury 5, Holy Reach 2, Spell Warding 3, Spiritual Guidance 3
        """),
        ("Holy", "Spiritual Healing, Spiritual Guidance and Ascendance, with Discipline's mana: the raid "
         "healer.", """
            Mental Agility 5, Silent Resolve 3, Improved Power Word: Fortitude 2, Inner Focus 1,
            Improved Power Word: Shield 2, Meditation 3,
            Improved Renew 3, Divinity 5, Divine Fury 5, Inspiration 3, Empowered Recovery 2,
            Improved Healing 3, Spiritual Guidance 5, Book of Prayer 2, Spirit of Redemption 1,
            Spiritual Healing 5, Ascendance 1
        """),
        ("Shadow", "Shadowform with Shadow Weaving and Vampiric Embrace: damage, and a little healing for the "
         "group.", """
            Mental Agility 5, Silent Resolve 3, Improved Power Word: Fortitude 2, Inner Focus 1, Meditation 3,
            Spirit Tap 5, Improved Mind Blast 5, Shadow Affinity 3, Improved Shadow Word: Pain 2,
            Shadow Focus 5, Mind Flay 1, Shadow Reach 2, Shadow Weaving 5, Vampiric Embrace 1,
            Vampiric Touch 2, Darkness 5, Shadowform 1
        """),
    ],
    "WARLOCK": [
        ("Affliction", "Malediction, Siphon Life and Dark Harvest, with Destruction's Bane and Devastation: "
         "damage over time for raids.", """
            Suppression 5, Improved Corruption 5, Improved Life Tap 2, Improved Drains 2,
            Improved Curse of Agony 3, Nightfall 2, Soul Siphon 3, Rapid Deterioration 2, Siphon Life 1,
            Malediction 1, Shadow Mastery 5, Dark Harvest 1,
            Cataclysm 5, Bane 5, Intensity 2, Devastation 5, Destructive Reach 2
        """),
        ("Demonology", "Soul Link and Master Demonologist: a strong demon and a hard warlock to kill.", """
            Demonic Embrace 5, Demonic Aegis 3, Fel Intellect 3, Fel Domination 1, Fel Stamina 5,
            Master Summoner 2, Unholy Power 3, Power Overwhelming 1, Demonic Precision 3,
            Master Demonologist 5, Unleashed Potential 3, Soul Link 1,
            Shadow Vulnerability 1, Cataclysm 5, Bane 5, Devastation 5
        """),
        ("Destruction", "Ruin, Emberstorm and Conflagrate, with Demonic Sacrifice: fire and shadow burst for "
         "raids and PvP.", """
            Demonic Embrace 5, Soul Entrapment 3, Demonic Aegis 2, Fel Domination 1, Demonic Sacrifice 1,
            Shadow Vulnerability 5, Cataclysm 5, Bane 5, Intensity 2, Shadowburn 1, Devastation 5,
            Pyroclasm 2, Destructive Reach 2, Improved Immolate 5, Ruin 1, Emberstorm 5, Conflagrate 1
        """),
    ],
    "HUNTER": [
        ("Beast Mastery", "Bestial Wrath, Frenzy and Kill Command, with Marksmanship's crits: your pet does much "
         "of the damage, solo or in a group.", """
            Swift Aspects 5, Endurance Training 5, Unleashed Fury 5, Ferocity 5, Scent of Blood 3,
            Bestial Wrath 1, Intimidation 1, Bestial Precision 2, Spirit Bond 2, Frenzy 5, Kill Command 1,
            Efficiency 5, Lethal Shots 5, Aimed Shot 1, Swiftshot 3, Hawk Eye 2
        """),
        ("Marksmanship", "Mortal Shots, Experimental Ammunition and Lock and Load, with Beast Mastery's Swift "
         "Aspects and Unleashed Fury: the raid damage build.", """
            Swift Aspects 5, Endurance Training 2, Thick Hide 3, Unleashed Fury 5,
            Efficiency 5, Lethal Shots 5, Hawk Eye 1, Aimed Shot 1, Swiftshot 3, Endless Quiver 2,
            Mortal Shots 5, Experimental Ammunition 1, Piercing Shots 2, Barrage 3, Improved Marksmanship 2,
            Ranged Weapon Specialization 5, Lock and Load 1
        """),
        ("Survival", "Melee with Carve, Lacerate and Lightning Reflexes, traps with Untamed Trapper, and Beast "
         "Mastery's Swift Aspects and Coordinated Assault.", """
            Swift Aspects 5, Improved Primal Aspects 3, Endurance Training 2, Unleashed Fury 5,
            Coordinated Assault 1,
            Improved Slaying 3, Swift Reflexes 2, Savage Strikes 2, Improved Wing Clip 3, Survivalist 5,
            Carve 1, Deterrence 1, Surefooted 3, Killer Instinct 3, Trap Mastery 3, Lacerate 1,
            Vicious Strikes 2, Lightning Reflexes 5, Untamed Trapper 1
        """),
    ],
    "PALADIN": [
        ("Holy", "Holy Shock, Illumination, Divine Favor and Daybreak, with Retribution's Blessing of Kings and "
         "Improved Blessings: the raid healer.", """
            Divine Intellect 5, Holy Judgement 3, Spiritual Focus 2, Healing Light 3,
            Improved Lay on Hands 2, Improved Concentration Aura 3, Illumination 5, Ironclad 2,
            Divine Favor 5, Holy Shock 1, Holy Power 3, Daybreak 1,
            Improved Devotion Aura 5,
            Improved Blessings 5, Benediction 5, Blessing of Kings 1
        """),
        ("Protection", "Holy Shield, Righteous Defense, Righteous Strikes and Bulwark of the Righteous, with "
         "Retribution's Deflection and Blessing of Kings: the tank.", """
            Improved Devotion Aura 1, Redoubt 5, Precision 3, Toughness 5, Improved Righteous Fury 3,
            Blessing of Sanctuary 1, Shield Specialization 3, Anticipation 3, Improved Hand of Reckoning 2,
            Righteous Defense 3, Holy Shield 1, Righteous Strikes 5, Bulwark of the Righteous 1,
            Benediction 5, Improved Judgement 2, Deflection 5, Improved Retribution Aura 2, Blessing of Kings 1
        """),
        ("Retribution", "Seal of Command, Vengeance and Vengeful Strikes with a two-hander, Blessing of Kings for "
         "the raid, and Holy's Divine Strength.", """
            Divine Strength 5, Divine Intellect 4,
            Improved Devotion Aura 5, Precision 3,
            Benediction 5, Improved Judgement 2, Improved Seal of the Crusader 3, Conviction 5,
            Blessing of Kings 1, Two-Handed Weapon Specialization 3, Vindication 3, Vengeance 5,
            Seal of Command 1, Vengeful Strikes 5, Repentance 1
        """),
    ],
    "SHAMAN": [
        ("Elemental", "Call of Thunder, Lightning Mastery, Elemental Fury and Earthquake, with Restoration's "
         "Tidal Mastery and Water Shield: the caster.", """
            Convection 5, Concussion 5, Elemental Devastation 3, Elemental Focus 1, Reverberation 3,
            Call of Thunder 5, Call of Flame 3, Elemental Mastery 1, Elemental Fury 2, Lightning Mastery 5,
            Earthquake 1,
            Tidal Focus 5, Tidal Mastery 5, Totemic Mastery 1, Nature's Grace 3, Healing Focus 1,
            Improved Water Shield 2
        """),
        ("Enhancement", "Stormstrike, Elemental Weapons, Element's Grace and Bloodlust, with Elemental's "
         "Clearcasting from melee crits: melee for raids and PvP.", """
            Ancestral Knowledge 5, Thundering Strikes 5, Stable Shields 3, Calming Winds 3,
            Lightning Strike 1, Flurry 5, Enhancing Totems 2, Elemental Weapons 3, Stormstrike 1,
            Element's Grace 5, Bloodlust 1,
            Convection 5, Concussion 5, Elemental Devastation 3, Elemental Focus 1, Reverberation 3
        """),
        ("Restoration", "Chain Heal, Water Shield, Ancestral Swiftness and Spirit Link, with Enhancement's "
         "Stable Shields for more Water Shield charges: the raid healer.", """
            Ancestral Knowledge 5, Improved Ghost Wolf 2, Stable Shields 3,
            Improved Healing Wave 5, Tidal Focus 5, Ancestral Healing 3, Tidal Mastery 5, Healing Way 3,
            Totemic Mastery 1, Restorative Totems 5, Improved Water Shield 3, Tidal Surge 2,
            Ancestral Swiftness 1, Undertow 2, Improved Chain Heal 5, Spirit Link 1
        """),
    ],
    "DRUID": [
        ("Balance", "Moonkin Form, Vengeance, Nature's Grace and Eclipse, with Restoration's Genesis for your "
         "damage over time: the caster.", """
            Improved Wrath 5, Improved Moonfire 2, Natural Weapons 3, Guidance of the Dream 2, Moonfury 3,
            Omen of Clarity 1, Nature's Reach 2, Vengeance 5, Moonglow 3, Moonkin Form 1, Nature's Grace 1,
            Improved Starfire 3, Balance of All Things 3, Eclipse 1,
            Improved Mark of the Wild 5, Subtlety 5, Reflection 3, Genesis 3
        """),
        ("Feral Combat", "Cat and bear: Heart of the Wild, Berserk and Leader of the Pack, Omen of Clarity from "
         "Balance and Furor to shift for energy.", """
            Nature's Grasp 1, Improved Nature's Grasp 4, Natural Weapons 3, Natural Shapeshifter 2,
            Omen of Clarity 1,
            Ferocity 5, Feral Instinct 3, Thick Hide 3, Open Wounds 2, Feral Swiftness 2, Feral Charge 1,
            Sharpened Claws 3, Primal Fury 2, Predatory Strikes 3, Blood Frenzy 2, Improved Shred 2,
            Berserk 1, Heart of the Wild 5, Leader of the Pack 1,
            Furor 5
        """),
        ("Restoration", "Swiftmend, Nature's Swiftness, Improved Regrowth and Tree of Life Form, with Balance's "
         "Omen of Clarity: the raid healer.", """
            Nature's Grasp 1, Improved Nature's Grasp 4, Natural Weapons 3, Natural Shapeshifter 2,
            Omen of Clarity 1,
            Improved Mark of the Wild 5, Improved Healing Touch 5, Nature's Focus 1, Swiftmend 1, Genesis 3,
            Reflection 3, Gift of Nature 5, Tranquil Spirit 5, Aessina's Bloom 2, Nature's Swiftness 1,
            Preservation 3, Improved Regrowth 5, Tree of Life Form 1
        """),
    ],
}


def parse_ranks(body, sep):
    """[(talent, rank)] from "talent rank" entries split by sep."""
    out = []
    for part in body.replace("\n", sep).split(sep):
        part = part.strip()
        if part:
            name, rank = part.rsplit(" ", 1)
            out.append((name, int(rank)))
    return out


class Trees:
    """A class's trees as the game has them, looked up by talent name."""

    def __init__(self, entry):
        self.names = [t["name"] for t in entry["trees"]]
        self.talent = {}
        for tab, tree in enumerate(entry["trees"]):
            at = {(t["tier"], t["column"]): t["name"] for t in tree["talents"]}
            for t in tree["talents"]:
                self.talent[t["name"]] = {
                    "tab": tab, "tier": t["tier"], "column": t["column"], "max": t["max"],
                    "pre": [at[(p["tier"], p["column"])] for p in t["prereqs"]]}

    def split(self, ranks):
        spent = [0] * len(self.names)
        for name, rank in ranks.items():
            if name in self.talent:
                spent[self.talent[name]["tab"]] += rank
        return spent


def check_allocation(trees, alloc):
    """What is wrong with a build at 60. It can be learnt in some order if
    each talent has 5 points a row above it in its tree, counting only the
    rows above, and its prerequisites at full rank."""
    problems = []
    for name, rank in alloc.items():
        t = trees.talent.get(name)
        if not t:
            problems.append("no talent %r" % name)
            continue
        if rank < 1 or rank > t["max"]:
            problems.append("%s %d of %d" % (name, rank, t["max"]))
        above = sum(r for n, r in alloc.items()
                    if n in trees.talent and trees.talent[n]["tab"] == t["tab"]
                    and trees.talent[n]["tier"] < t["tier"])
        if above < 5 * (t["tier"] - 1):
            problems.append("%s (row %d of %s) needs %d points above it, has %d"
                            % (name, t["tier"], trees.names[t["tab"]], 5 * (t["tier"] - 1), above))
        for pre in t["pre"]:
            if alloc.get(pre, 0) < trees.talent[pre]["max"]:
                problems.append("%s needs %s at full rank" % (name, pre))
    total = sum(alloc.values())
    if total != POINTS:
        problems.append("%d points, not %d" % (total, POINTS))
    return problems


def check_order(trees, order):
    """What is wrong with a levelling build, learnt point by point as the
    game allows: a row needs 5 points spent in its tree for each row above,
    prerequisites at full rank first. Returns the problems and each point:
    (level, tab, talent, rank)."""
    problems, points, have = [], [], {}
    spent = [0] * len(trees.names)
    for name, upto in order:
        t = trees.talent.get(name)
        if not t:
            problems.append("no talent %r" % name)
            continue
        if upto <= have.get(name, 0):
            problems.append("%s %d comes after %s %d" % (name, upto, name, have.get(name, 0)))
        if upto > t["max"]:
            problems.append("%s %d of %d" % (name, upto, t["max"]))
        for pre in t["pre"]:
            if have.get(pre, 0) < trees.talent[pre]["max"]:
                problems.append("%s before %s is at full rank" % (name, pre))
        for rank in range(have.get(name, 0) + 1, upto + 1):
            level = FIRST_LEVEL + len(points)
            if spent[t["tab"]] < 5 * (t["tier"] - 1):
                problems.append("%s %d at level %d: row %d of %s needs %d points in it, has %d"
                                % (name, rank, level, t["tier"], trees.names[t["tab"]],
                                   5 * (t["tier"] - 1), spent[t["tab"]]))
            points.append((level, t["tab"], name, rank))
            spent[t["tab"]] += 1
        have[name] = max(have.get(name, 0), upto)
    if len(points) != POINTS:
        problems.append("%d points by 60, not %d" % (len(points), POINTS))
    return problems, points


def learning_order(trees, alloc):
    """The order a build at 60 is learnt in after a respec: its biggest tree
    first, each tree a row at a time, a talent's prerequisite before it.
    [(talent, rank)], as a levelling build's order is."""
    per = trees.split(alloc)
    first = {tab: i for i, tab in enumerate(sorted(range(len(per)), key=lambda t: (-per[t], t)))}

    def depth(name):
        t = trees.talent[name]
        return 1 + max([depth(p) for p in t["pre"] if trees.talent[p]["tier"] == t["tier"]] or [-1])

    names = sorted(alloc, key=lambda n: (first[trees.talent[n]["tab"]], trees.talent[n]["tier"], depth(n),
                                          trees.talent[n]["column"]))
    return [(n, alloc[n]) for n in names]


def lua_str(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def lua_order(order, indent):
    """A build's order as Lua: talent, rank, talent, rank, ... a few a line."""
    items = ["%s, %d" % (lua_str(n), r) for n, r in order]
    lines, line = [], ""
    for item in items:
        if line and len(line) + len(item) > 96:
            lines.append(line)
            line = ""
        line += item + ", "
    if line:
        lines.append(line)
    return "\n".join(indent + l.rstrip() for l in lines)


def lua_builds(classes):
    """TalentBuilds.lua: each class's levelling build and builds at 60, by
    talent name, in the order their points go."""
    out = ["-- TalentBuilds.lua",
           "--",
           "-- GENERATED FILE -- do not edit by hand.",
           "-- Generator: Tools/build/talent_builds.py, which checks every build against",
           "-- Turtle WoW's trees (Tools/data/turtle_talent_trees.json, saved by /apg talents).",
           "--",
           "-- Each build's order is talent, rank, talent, rank, ...: each talent taken up",
           "-- to that rank, a point a level from 10, 51 in all. The Talent Advisor checks",
           "-- them against the tree the game has before it follows one.",
           "",
           "AegisPathfinder.TalentBuilds = {"]
    for cls in sorted(classes):
        e = classes[cls]
        spec, split, order = e["levelling"]
        out.append("\t%s = {" % cls)
        out.append("\t\tlevelling = { spec = %s, split = %s, order = {" % (lua_str(spec), lua_str(split)))
        out.append(lua_order(order, "\t\t\t"))
        out.append("\t\t} },")
        if e.get("alts"):
            out.append("\t\talts = {")
            for name, aspec, asplit, aorder in e["alts"]:
                out.append("\t\t\t{ name = %s, spec = %s, split = %s, order = {"
                           % (lua_str(name), lua_str(aspec), lua_str(asplit)))
                out.append(lua_order(aorder, "\t\t\t\t"))
                out.append("\t\t\t} },")
            out.append("\t\t},")
        out.append("\t\tspecs = {")
        for sname, ssplit, learn in e["specs"]:
            out.append("\t\t\t{ spec = %s, split = %s, order = {" % (lua_str(sname), lua_str(ssplit)))
            out.append(lua_order(learn, "\t\t\t\t"))
            out.append("\t\t\t} },")
        out.append("\t\t},")
        out.append("\t},")
    out.append("}")
    return "\n".join(out) + "\n"


def lua_fixture(game):
    """The trees as a Lua table for the tests' talent API: each talent's name,
    tier, column, ranks, and its prerequisite's tier and column (0 for none)."""
    out = ["-- The talent trees Turtle WoW has, for the Talent Advisor's tests.",
           "-- Generated by Tools/build/talent_builds.py from Tools/data/turtle_talent_trees.json.",
           "return {"]
    for cls in sorted(game):
        out.append("\t%s = {" % cls)
        for tree in game[cls]["trees"]:
            out.append("\t\t{ name = %s, talents = {" % lua_str(tree["name"]))
            for t in tree["talents"]:
                pre = t["prereqs"][0] if t["prereqs"] else {"tier": 0, "column": 0}
                out.append("\t\t\t{ %s, %d, %d, %d, %d, %d }," % (lua_str(t["name"]), t["tier"], t["column"],
                                                                   t["max"], pre["tier"], pre["column"]))
            out.append("\t\t} },")
        out.append("\t},")
    out.append("}")
    return "\n".join(out) + "\n"


def rxp_gone(trees, guides):
    """The talents RestedXP's levelling orders use that Turtle WoW's trees
    no longer have; a point where RestedXP gives a choice counts each."""
    gone = []
    for g in guides:
        for p in g["points"]:
            for c in p.get("choices", [p]):
                if c["name"] not in trees.talent and c["name"] not in gone:
                    gone.append(c["name"])
    return gone


def main():
    with open(TREES, encoding="utf-8") as fh:
        game = json.load(fh)
    rxp = None
    if os.path.exists(RXP):
        with open(RXP, encoding="utf-8") as fh:
            rxp = json.load(fh)
    problems = []
    lua_classes = {}
    out = {"note": "Checked against Turtle WoW's trees, saved by /apg talents.",
           "trees_saved": {}, "classes": {}}
    for cls in sorted(LEVELLING):
        trees = Trees(game[cls])
        out["trees_saved"][cls] = "%s (Aegis: Pathfinder %s)" % (game[cls]["saved"], game[cls]["version"])
        spec, why, body = LEVELLING[cls]
        order = parse_ranks(body, "\n")
        bad, points = check_order(trees, order)
        problems += ["%s levelling: %s" % (cls, b) for b in bad]
        final = {}
        for _, _, name, rank in points:
            final[name] = rank
        last = {}
        for level, _, name, rank in points:
            last[(name, rank)] = level
        entry = {
            "trees": trees.names,
            "levelling": {
                "spec": spec, "why": why,
                "split": "/".join(str(n) for n in trees.split(final)),
                "order": [[name, rank, last.get((name, rank))] for name, rank in order],
                "points": [[level, tab + 1, name, rank] for level, tab, name, rank in points],
            },
            "specs": [],
        }
        if rxp and cls in rxp.get("classes", {}):
            entry["rxp_gone"] = rxp_gone(trees, [g for g in rxp["classes"][cls] if not g["survival"]])
        lua_entry = {"levelling": (spec, entry["levelling"]["split"], order), "specs": [], "alts": []}
        for aname, aspec, awhy, abody in LEVELLING_ALTS.get(cls, []):
            aorder = parse_ranks(abody, "\n")
            abad, apoints = check_order(trees, aorder)
            problems += ["%s %s levelling: %s" % (cls, aname, b) for b in abad]
            afinal = {}
            for _, _, name, rank in apoints:
                afinal[name] = rank
            alast = {}
            for level, _, name, rank in apoints:
                alast[(name, rank)] = level
            asplit = "/".join(str(n) for n in trees.split(afinal))
            entry.setdefault("alts", []).append({
                "name": aname, "spec": aspec, "why": awhy, "split": asplit,
                "order": [[name, rank, alast.get((name, rank))] for name, rank in aorder],
                "points": [[level, tab + 1, name, rank] for level, tab, name, rank in apoints],
            })
            lua_entry["alts"].append((aname, aspec, asplit, aorder))
        for sname, swhy, sbody in SPECS[cls]:
            ranks = parse_ranks(sbody, ",")
            alloc = dict(ranks)
            if len(alloc) != len(ranks):
                problems.append("%s %s: a talent named twice" % (cls, sname))
            bad = check_allocation(trees, alloc)
            problems += ["%s %s: %s" % (cls, sname, b) for b in bad]
            learn = learning_order(trees, alloc) if not bad else []
            if learn:
                problems += ["%s %s, in the order it is learnt: %s" % (cls, sname, b)
                             for b in check_order(trees, learn)[0]]
            lua_entry["specs"].append((sname, "/".join(str(n) for n in trees.split(alloc)), learn))
            by_tab = [[] for _ in trees.names]
            for name in alloc:
                if name in trees.talent:
                    t = trees.talent[name]
                    by_tab[t["tab"]].append(name)
            entry["specs"].append({
                "spec": sname, "why": swhy,
                "split": "/".join(str(n) for n in trees.split(alloc)),
                "trees": [[trees.names[i], {n: alloc[n] for n in sorted(
                    by_tab[i], key=lambda n: (trees.talent[n]["tier"], trees.talent[n]["column"]))}]
                          for i in range(len(trees.names))],
            })
        out["classes"][cls] = entry
        lua_classes[cls] = lua_entry
    for p in problems:
        print(p)
    written = {
        OUT: json.dumps(out, indent=1) + "\n",
        LUA_OUT: lua_builds(lua_classes),
        FIXTURE_OUT: lua_fixture(game),
    }
    if "--check" in sys.argv[1:]:
        stale = []
        for path, text in written.items():
            try:
                with open(path, encoding="utf-8") as fh:
                    if fh.read() != text:
                        stale.append(path)
            except OSError:
                stale.append(path)
        for path in stale:
            print("%s is not what talent_builds.py writes: run it" % os.path.relpath(path, ROOT))
        builds = sum(4 + len(c.get("alts", [])) for c in out["classes"].values())
        print("%d classes, %d builds, %d problems" % (len(out["classes"]), builds, len(problems)))
        return 1 if problems or stale else 0
    for path, text in written.items():
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
    print("wrote %s: %d classes, %d problems" % (", ".join(os.path.relpath(p, ROOT) for p in written),
                                                  len(out["classes"]), len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
