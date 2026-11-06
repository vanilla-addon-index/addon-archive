-- Ashen Builds combat simulator: item and enchant effects shared by every melee class.
--
-- Chance-on-hit data. src says where each entry comes from:
--   DB   proc rate read from the Turtle server item data (Tortoise DB snapshot)
--   REF  taken from the maintained Turtle WarriorSim (thrunk112), not confirmed on the server
--   LIVE a guessed rate in the reference ("assumed"/"unknown"); needs combat-log testing
-- ppm = procs per minute (chance = weapon speed * ppm / 60); chance = flat % per hit.
-- dmg + magic = spell damage (can be resisted, crits for 150%); dmg alone = physical hit.
-- extra = extra main-hand attacks; spell = a buff/debuff from AshenSim.ProcAuras.
-- OH entries replace P entries for the same item when it is in the off hand.

AshenSim = AshenSim or {}
local S = AshenSim

local P, OH = {}, {}
S.ItemProcs, S.OffhandProcs = P, OH

P[81124]={chance=5,dmg=20,magic=true,src="REF"} -- Helmet of the Scarlet Avenger
P[17111]={chance=100,dmg=3,magic=true,src="REF"} -- Blazefury Medallion
P[61010]={chance=1,extra=1,src="REF"} -- Wing of the Time-Lord
P[84035]={chance=5,dmg=60,magic=true,src="REF"} -- Fists of the Red Dawn
P[19289]={chance=2,dmg=250,magic=true,src="LIVE"} -- Darkmoon Card: Maelstrom
P[11815]={chance=2,extra=1,src="DB"} -- Hand of Justice
P[22321]={chance=2,dmg=165,magic=true,src="LIVE"} -- Heart of Wyrmthalak
P[61541]={ppm=2,extra=1,src="DB"} -- Letashaz's Right Claw
P[55494]={ppm=1,dmg=120,magic=true,src="REF"} -- The Abyssal Pincer
P[84030]={ppm=5,dmg=75,magic=true,src="DB"} -- Gauntlet of a Thousand Cuts
P[65008]={ppm=3.5,dmg=150,magic=true,src="DB"} -- Dream's Herald
P[83564]={ppm=0.4,spell="Tempest",src="REF"} -- Tempest's Rage
P[60422]={ppm=4,dmg=25,magic=true,coeff=1,src="DB"} -- The Ripper
P[61042]={ppm=1.5,dmg=59,magic=true,coeff=1,src="DB"} -- Stormfist
P[81288]={ppm=15,dmg=20,src="DB"} -- Mechanist's Bonechopper Replica
P[81003]={ppm=6,dmg=102,src="DB"} -- Ancient Hakkari Flayer
P[13246]={ppm=1,spell="Avenger",src="REF"} -- Argent Avenger
P[19852]={ppm=1,dmg=56,magic=true,coeff=1,src="REF"} -- Ancient Hakkari Manslayer
P[12798]={ppm=1,spell="Annihilator",src="DB"} -- Annihilator
P[13286]={ppm=5,spell="Rivenspike",src="DB"} -- Rivenspike
P[811]={ppm=0.8,dmg=108,magic=true,gcd=true,src="REF"} -- Axe of the Deep Woods
P[17068]={ppm=0.8,dmg=138,magic=true,gcd=true,src="REF"} -- Deathbringer
P[871]={ppm=1.8,extra=1,src="REF"} -- Flurry Axe
P[14555]={ppm=1.3,dmg=99,magic=true,src="DB"} -- Alcor's Sunrazor
P[13984]={ppm=1,dmg=99,magic=true,src="REF"} -- Darrowspike
P[20578]={ppm=1,dmg=97,magic=true,src="REF"} -- Emerald Dragonfang
P[12590]={ppm=1.4,spell="Felstriker",src="DB"} -- Felstriker
P[19099]={ppm=1,dmg=49,magic=true,src="REF"} -- Glacial Blade
P[17071]={ppm=1,dmg=82,magic=true,binary=true,gcd=true,src="REF"} -- Gutgore Ripper
P[18816]={ppm=1.3,dmg=53,magic=true,src="DB"} -- Perdition's Blade
P[19324]={ppm=1,dmg=250,src="REF"} -- The Lobotomizer
P[18203]={ppm=1,spell="Eskhandar",src="REF"} -- Eskhandar's Right Claw
P[19170]={ppm=0.8,dmg=220,magic=true,gcd=true,src="DB"} -- Ebon Hand
P[17112]={ppm=1,spell="Empyrean",src="DB"} -- Empyrean Demolisher
P[11684]={ppm=1,extra=2,src="DB"} -- Ironfoe
P[23221]={ppm=4,dmg=125,magic=true,src="REF"} -- Misplaced Servo Arm
P[19908]={ppm=1,dmg=78,magic=true,coeff=1,src="REF"} -- Sceptre of Smiting
P[6622]={ppm=1.8,spell="Zeal",src="REF"} -- Sword of Zeal
P[19901]={ppm=1,dmg=84,magic=true,coeff=1,src="REF"} -- Zulian Slicer
P[1728]={ppm=1,dmg=165,magic=true,src="REF"} -- Teebu's Blazing Longsword
P[17705]={ppm=1,extra=1,src="REF"} -- Thrash Blade
P[19019]={ppm=8,dmg=300,magic=true,binary=true,src="DB"} -- Thunderfury, Blessed Blade of the Windseeker
P[17075]={ppm=1.3,dmg=240,src="DB"} -- Vis'kag the Bloodletter
P[14487]={ppm=1.7,dmg=99,magic=true,src="REF"} -- Bonechill Hammer
P[58214]={ppm=1,spell="Modrag",src="REF"} -- Modrag'zan, Heart of the Mountain
OH[83564]={ppm=0.6,spell="Tempest",src="REF"} -- Tempest's Rage
OH[19852]={ppm=1,dmg=51,magic=true,coeff=1,src="REF"} -- Ancient Hakkari Manslayer
P[19910]={ppm=4,dmg=77,magic=true,gcd=true,src="DB"} -- Arlokk's Grasp
P[61247]={ppm=2,dmg=286,magic=true,src="DB"} -- Shadowbringer
P[33093]={ppm=1,dmg=212,magic=true,spell="ElementiumChampion",src="REF"} -- Elementium Champion
P[33094]={ppm=1,dmg=650,src="REF"} -- Elementium Reaper
P[61277]={ppm=1,dmg=212,magic=true,spell="ForgottenOrder",src="DB"} -- Fist of the Forgotten Order
P[55495]={chance=5,spell="ZandalariVigil",src="REF"} -- Zandalar Predator's Glaive
P[55504]={ppm=1,dmg=200,magic=true,src="REF"} -- Anchor of the Wavecutter
P[61049]={ppm=0.6,extra=1,src="DB"} -- Chronobreaker
P[9372]={ppm=1.5,dmg=275,magic=true,src="REF"} -- Sul'thraze the Lasher
P[12790]={ppm=1.2,spell="Champion",src="DB"} -- Arcanite Champion
P[1263]={ppm=1,dmg=250,src="REF"} -- Brain Hacker
P[19353]={ppm=2,dmg=240,src="DB"} -- Drake Talon Cleaver
P[21856]={ppm=1.4,dmg=152,magic=true,src="DB"} -- Neretzek, The Blood Drinker
P[13285]={ppm=1,dmg=100,src="REF"} -- The Blackrock Slicer
P[19918]={ppm=4,dmg=210,src="DB"} -- Jeklik's Crusher
P[17182]={ppm=3,dmg=333,magic=true,gcd=true,src="REF"} -- Sulfuras, Hand of Ragnaros
P[17193]={ppm=1,dmg=101,magic=true,gcd=true,src="REF"} -- Sulfuron Hammer
P[12583]={ppm=1,dmg=432,src="REF"} -- Blackhand Doomsaw
P[19874]={ppm=1.2,dmg=564,src="REF"} -- Halberd of Smiting
P[17223]={ppm=1.5,dmg=200,magic=true,src="DB"} -- Thunderstrike
P[17076]={ppm=2,spell="Bonereaver",src="DB"} -- Bonereaver's Edge
P[22691]={ppm=1,dmg=200,magic=true,src="REF"} -- Corrupted Ashbringer
P[647]={ppm=1,spell="Destiny",src="REF"} -- Destiny
P[21679]={ppm=1.75,dmg=258,magic=true,src="REF"} -- Kalimdor's Revenge
P[19334]={ppm=2,spell="Untamed",src="DB"} -- The Untamed Blade
P[13348]={ppm=1,dmg=270,magic=true,src="REF"} -- Demonshear
P[12782]={ppm=3,dmg=90,magic=true,src="DB"} -- Corruption

-- Buffs and debuffs started by the procs above (values from the reference sim).
-- stats: flat additions; haste: % attack speed (multiplies with other haste);
-- dmgBonus: flat weapon damage; armor: target armor removed per stack.
S.ProcAuras = {
  Empyrean = {name = "Empyrean Haste", duration = 10, haste = 20},
  Eskhandar = {name = "Eskhandar's Rage", duration = 5, haste = 30},
  Tempest = {name = "Tempest Haste", duration = 20, haste = 15},
  Zeal = {name = "Zeal", duration = 15, dmgBonus = 10},
  Annihilator = {name = "Armor Shatter", duration = 45, armor = 100, maxStacks = 3},     -- DB 16928: 100 per stack
  Rivenspike = {name = "Puncture Armor", duration = 30, armor = 200, maxStacks = 3},      -- DB 17315
  Bonereaver = {name = "Bonereaver's Edge", duration = 10, armor = 700, maxStacks = 3},
  Destiny = {name = "Destiny", duration = 10, stats = {str = 200}},
  Untamed = {name = "Untamed Fury", duration = 8, stats = {str = 300}},
  Champion = {name = "Strength of the Champion", duration = 30, stats = {str = 120}},
  ZandalariVigil = {name = "Zandalari Vigil", duration = 10, stats = {agi = 75}},
  ForgottenOrder = {name = "Fist of the Forgotten Order", duration = 15, stats = {str = 50}},
  ElementiumChampion = {name = "Elementium Champion", duration = 30, stats = {str = 150}},
  Felstriker = {name = "Felstriker", duration = 3, stats = {crit = 100, hit = 100}},
  Crusader = {name = "Crusader", duration = 15, stats = {str = 100}},
  -- Set bonus procs (Turtle DB).
  OverpoweringRage = {name = "Overpowering Rage", duration = 5, haste = 15},        -- Armor of Wrath (3)
  PowerSurge = {name = "Power Surge", duration = 10, stats = {str = 50}},             -- Towerforge Battlegear (4)
  UnrelentingStrikes = {name = "Unrelenting Strikes", duration = 6, haste = 10},     -- Arms of Thaurissan (2)
  PrimalBlessing = {name = "Primal Blessing", duration = 12, stats = {ap = 300}},     -- Primal Blessing (2)
  Revitalize = {name = "Revitalize", duration = 8, haste = 10},                       -- Stormshroud Armor (4)
}

-- Weapon enchant procs by enchant spell id (reference values; Crusader matches the enchant text).
S.EnchantProcs = {
  [20034] = {ppm = 1, spell = "Crusader", src = "REF"},
  [13898] = {ppm = 6, dmg = 44, magic = true, src = "REF"},  -- Fiery Weapon
  [20032] = {ppm = 6, dmg = 33, magic = true, src = "REF"},  -- Lifestealing
}

-- "+N damage" from a weapon enchant (Striking/Impact), read from the enchant text.
function S.EnchantWeaponDamage(enchant)
  if not enchant or not enchant.tip then return 0 end
  local tip = enchant.tip
  if string.find(tip, "against") or string.find(tip, " to [A-Z]%a+s%.") then return 0 end  -- slayer enchants
  local _, _, n = string.find(tip, "to do (%d+) additional points? of damage")
  if not n then _, _, n = string.find(tip, "to do %+(%d+) damage") end
  return tonumber(n) or 0
end

-- BEGIN GENERATED SET EFFECTS
-- Generated by tools/build_set_effects.py from the Tortoise DB. Do not edit by hand.
local E = {}
S.SetEffects = E
E[7219]={none=true} -- Immune to Disarm
E[7495]={none=true} -- Increased Intellect 05
E[7496]={none=true} -- Increased Intellect 06
E[7499]={none=true} -- Increased Spirit 05
E[7501]={none=true} -- Increased Spirit 07
E[7503]={none=true} -- Increased Stamina 05
E[7507]={str=5} -- Increased Strength 05
E[7516]={none=true} -- Increased Defense
E[7517]={none=true} -- Increased Defense
E[7524]={skill={Sword=4}} -- Increased 1H Sword
E[7575]={skill={Dagger=4}} -- Increased Dagger
E[7597]={crit=1} -- Increased Critical 1
E[7598]={crit=2} -- Increased Critical 2
E[7599]={crit=3} -- Increased Critical 3
E[7711]={special=true} -- Add Fire Dam - Weap 02
E[8815]={haste=2} -- Haste 2
E[9106]={none=true} -- Increased Intellect 10
E[9111]={none=true} -- Increased Spirit 10
E[9117]={none=true} -- Increased Stamina 10
E[9121]={str=10} -- Increased Strength 10
E[9140]={ap=10} -- Attack Power 10
E[9233]={special=true} -- Firebolt
E[9314]={none=true} -- Increase Healing 24
E[9315]={none=true} -- Increase Healing 26
E[9317]={none=true} -- Increase Healing 31
E[9318]={none=true} -- Increase Healing 33
E[9330]={ap=18} -- Attack Power 18
E[9331]={ap=20} -- Attack Power 20
E[9334]={ap=26} -- Attack Power 26
E[9335]={ap=28} -- Attack Power 28
E[9336]={ap=30} -- Attack Power 30
E[9342]={none=true} -- Increase Spell Dam 13
E[9343]={none=true} -- Increase Spell Dam 14
E[9344]={none=true} -- Increase Spell Dam 15
E[9346]={none=true} -- Increase Spell Dam 18
E[9396]={none=true} -- Increase Spell Dam 6
E[9407]={none=true} -- Increase Healing 20
E[9408]={none=true} -- Increase Healing 22
E[9411]={none=true} -- Increase Nature Dam 14
E[9417]={none=true} -- Increase Spell Dam 12
E[9762]={none=true} -- Increased Armor 30
E[9764]={none=true} -- Increased Armor 50
E[13198]={str=15} -- Increased Strength 15
E[13384]={none=true} -- Increased Defense
E[13665]={none=true} -- Increased Parry 1
E[13669]={none=true} -- Increased Dodge 1
E[13670]={none=true} -- Increased Dodge 2
E[13675]={none=true} -- Increased Block 2
E[13676]={none=true} -- Increased Block 3
E[13679]={haste=1} -- Haste 1
E[14027]={ap=24} -- Attack Power 24
E[14047]={none=true} -- Increase Spell Dam 23
E[14049]={ap=40} -- Attack Power 40
E[14054]={none=true} -- Increase Spell Dam 27
E[14056]={ap=50} -- Attack Power 50
E[14127]={none=true} -- Increase Spell Dam 28
E[14384]={agi=20} -- Increased Agility 20
E[14410]={none=true} -- Increased Intellect 20
E[14462]={none=true} -- Increased Stamina 15
E[14465]={none=true} -- Increased Stamina 18
E[14467]={none=true} -- Increased Stamina 20
E[14477]={none=true} -- Increased Stamina 30
E[14482]={none=true} -- Increased Stamina 35
E[14590]={none=true} -- Increased Fire Resist 10
E[14592]={none=true} -- Increased Fire Resist 12
E[14594]={none=true} -- Increased Fire Resist 14
E[14598]={none=true} -- Increased Fire Resist 18
E[14673]={none=true} -- Increased Shadow Resist 10
E[14678]={none=true} -- Increased Shadow Resist 15
E[14712]={none=true} -- Increased Arcane Resist 10
E[14713]={none=true} -- Increased Arcane Resist 11
E[14776]={none=true} -- Meditation
E[14799]={none=true} -- Increase Spell Dam 20
E[14803]={none=true} -- Increased Armor 200
E[15464]={hit=1} -- Increased Hit Chance 1
E[15465]={hit=2} -- Increased Hit Chance 2
E[15666]={none=true} -- Increased Armor 100
E[15687]={none=true} -- Increased Armor 250
E[15763]={skill={Sword=6}} -- Increased 1H Sword
E[15774]={skill={TwoHandMace=6}} -- Increased 2H Mace
E[15957]={none=true} -- Increased Armor 300
E[17332]={special=true} -- Spider's Kiss
E[17498]={none=true} -- Speed
E[18037]={none=true} -- Increase Healing 57
E[18056]={none=true} -- Increase Spell Dam 40
E[18074]={none=true} -- Undead Slayer 30
E[18382]={none=true} -- Increased Critical Spell
E[18384]={none=true} -- Increased Critical Spell
E[18675]={none=true} -- Increased All Resist 04
E[18676]={none=true} -- Increased All Resist 05
E[18679]={none=true} -- Increased All Resist 08
E[18681]={none=true} -- Increased All Resist 10
E[18686]={none=true} -- Increased All Resist 15
E[21092]={none=true} -- Increased Critical Holy
E[21364]={none=true} -- Increased Mana Regen
E[21408]={none=true} -- Increased Defense
E[21416]={none=true} -- Increased Defense
E[21430]={none=true} -- Attack Power Ranged 12
E[21598]={none=true} -- Vitality
E[21599]={none=true} -- Vitality
E[21603]={none=true} -- Vitality
E[21618]={none=true} -- Increased Mana Regen
E[21625]={none=true} -- Increased Mana Regen
E[21629]={none=true} -- Increased Mana Regen
E[21636]={none=true} -- Increased Mana Regen
E[21741]={none=true} -- Demonic Ally
E[21747]={special=true} -- Lawbringer
E[21838]={special=true} -- Battlegear of Might
E[21853]={special=true} -- Reactive Fade
E[21871]={none=true} -- Increased Rejuvenation Duration
E[21872]={special=true} -- Faster Regrowth Cast
E[21874]={special=true} -- Improved Vanish
E[21879]={none=true} -- Friendly Nukes
E[21881]={special=true} -- Improved Poisons
E[21882]={special=true} -- Judgement Smite
E[21890]={special=true} -- Warrior's Wrath
E[21894]={none=true} -- Meditation
E[21895]={none=true} -- Increased Totem Radius
E[21922]={none=true} -- Demonic Ally
E[21926]={none=true} -- Nature's Ally
E[21928]={none=true} -- Nature's Ally
E[21973]={special=true} -- Prophecy Flash Heal Bonus
E[21975]={none=true} -- Vigor
E[22007]={special=true} -- Netherwind Focus
E[22010]={none=true} -- Greater Heal Renew
E[22648]={special=true} -- Call of Eskhandar
E[22738]={special=true} -- Intercept Cooldown Reduction
E[22778]={special=true} -- Hamstring Rage Reduction
E[22801]={special=true} -- Ghost Wolf Speed
E[22804]={special=true} -- Shaman Shock Crit Bonus
E[23025]={special=true} -- Blink Cooldown Reduction
E[23037]={special=true} -- Mana Shield Absorb Increase
E[23043]={special=true} -- Priest Pushback Reduction
E[23044]={none=true} -- Psychic Scream Duration Increase
E[23046]={special=true} -- Warlock Cast Pushback Reduction
E[23047]={special=true} -- Immolate Cast Time Reduction
E[23048]={special=true} -- Gouge Cooldown Reduction
E[23049]={none=true} -- Sprint Duration Increase
E[23158]={special=true} -- Concussive Shot & Wing Clip Cooldown Reduction
E[23213]={none=true} -- Increase Spell Dam 57
E[23218]={none=true} -- Feral Move Speed Increase
E[23300]={special=true} -- Seal of the Crusader Judgement Increase
E[23302]={special=true} -- Hammer of Justice Cooldown Reduction
E[23545]={none=true} -- Subtlety
E[23548]={special=true} -- Parry
E[23549]={none=true} -- Increased Area
E[23550]={special=true} -- Increased Prayer of Healing Criticals
E[23551]={special=true} -- Lightning Shield
E[23553]={none=true} -- Shadow Cost Reduction
E[23554]={special=true} -- Improved Drain Life
E[23555]={none=true} -- Decreased Destruction Threat
E[23556]={special=true} -- Decreased Tranquility and Hurricane Cooldown
E[23557]={special=true} -- Improved Thorns Damage
E[23558]={special=true} -- Improved Feint
E[23559]={special=true} -- Improved Aspect of the Hawk
E[23560]={special=true} -- Improved Mend Pet
E[23561]={none=true} -- Enhanced Sunder Armor
E[23562]={none=true} -- Block Value 30
E[23563]={special=true} -- Enhanced Battle Shout
E[23566]={special=true} -- Improved Volley and Multishot
E[23570]={none=true} -- Increased Critical Spell Nature
E[23572]={special=true} -- Mana Surge
E[23578]={special=true} -- Detect Weakness
E[23581]={special=true} -- Bloodfang
E[23582]={none=true} -- Clean Escape
E[23591]={none=true} -- Judgement
E[23727]={none=true} -- Increased Spell Hit Chance 1
E[23729]={none=true} -- Increased Spell Hit Chance 2
E[23863]={special=true} -- Revitalize
E[24090]={none=true} -- Minor Movement Speed
E[24256]={special=true} -- Primal Blessing Trigger DND
E[24431]={special=true} -- Improved Whirlwind
E[24456]={special=true} -- Improved Intimidating Shout
E[24460]={none=true} -- Improved Blessings
E[24461]={none=true} -- Improved Frost Shock
E[24462]={none=true} -- Improved Lightning Bolt
E[24465]={special=true} -- Improved Concussive Shot
E[24467]={special=true} -- Improved Serpent Sting
E[24469]={special=true} -- Improved Blind
E[24471]={special=true} -- Improved Eviscerate and Rupture
E[24479]={none=true} -- Improved Faerie Fire
E[24480]={special=true} -- Improved Starfire
E[24482]={none=true} -- Improved Smite and Holy Fire
E[24483]={special=true} -- Improved Mind Control
E[24486]={special=true} -- Improved Corruption
E[24487]={special=true} -- Improved Death Coil
E[24489]={special=true} -- Improved Arcane Intellect
E[24491]={special=true} -- Improved Flamestrike
E[24595]={none=true} -- Increase Spell Dam 24
E[24746]={special=true} -- Twilight Cultist Disguise
E[25975]={none=true} -- Increased Spell Penetration 10
E[26106]={special=true} -- Genesis Rebirth Bonus
E[26107]={special=true} -- Symbols of Unending Life Finisher Bonus
E[26109]={special=true} -- Conqueror Shout Bonus
E[26110]={special=true} -- Conqueror Thunder Clap Bonus
E[26111]={special=true} -- Battlegear of Unyielding Strength Intercept Bonus
E[26112]={special=true} -- Deathdealer Evasion Bonus
E[26113]={special=true} -- Deathdealer Eviscerate Bonus
E[26114]={special=true} -- Emblems of Veiled Shadows Slice and Dice Bonus
E[26116]={special=true} -- Doomcaller Immolate Bonus
E[26117]={special=true} -- Doomcaller Reduced Shadow Bolt Cost
E[26118]={special=true} -- Implements of Unspoken Names Pet Bonus
E[26119]={special=true} -- Stormcaller Spelldamage Bonus
E[26123]={special=true} -- Gift of the Gathering Storm Chain Lightning Bonus
E[26127]={none=true} -- Enigma Blizzard Bonus
E[26128]={special=true} -- Enigma Resist Bonus
E[26131]={special=true} -- Trappings of Vaulted Secrets Mana Shield Bonus
E[26135]={special=true} -- Battlegear of Eternal Justice
E[26172]={special=true} -- Infinite Wisdom Shadow Word: Pain Bonus
E[26173]={special=true} -- Striker's Arcane Shot Bonus
E[26174]={special=true} -- Striker's Rapid Fire Bonus
E[26175]={none=true} -- Increased Spell Penetration 10
E[26176]={none=true} -- Unseen Path Pet Bonus
E[26283]={none=true} -- Increased Spell Penetration 20
E[27419]={special=true} -- Warrior's Resolve
E[27498]={special=true} -- Crusader's Wrath
E[27733]={none=true} -- Ironweave Battlesuit
E[27774]={special=true} -- The Furious Storm
E[27778]={special=true} -- Divine Protection
E[27780]={special=true} -- Corrupted Fear
E[27781]={special=true} -- Nature's Bounty
E[27785]={special=true} -- Hunter Armor Energize
E[27787]={special=true} -- Rogue Armor Energize
E[27867]={special=true} -- Freeze
E[28118]={crit=1} -- PvP Armor Increased Critical 1
E[28264]={none=true} -- Increase Spell Dam 46
E[28325]={none=true} -- Block Value 32
E[28539]={special=true} -- Multi-Shot Damage Increase
E[28716]={none=true} -- Rejuvenation
E[28719]={none=true} -- Healing Touch
E[28743]={special=true} -- Dreamwalker
E[28744]={none=true} -- Regrowth
E[28746]={none=true} -- Plagueheart
E[28751]={special=true} -- Multi-Shot
E[28752]={special=true} -- Adrenaline Rush
E[28755]={none=true} -- Rapid Fire
E[28756]={ap=51} -- Stalker's Ally
E[28761]={special=true} -- Not There
E[28763]={special=true} -- Evocation
E[28764]={none=true} -- Adaptive Warding
E[28771]={special=true} -- Elemental Vulnerability
E[28774]={special=true} -- Lay Hands
E[28787]={none=true} -- Cleanse
E[28802]={special=true} -- Epiphany
E[28807]={special=true} -- Renew
E[28808]={none=true} -- Reduced Threat
E[28809]={none=true} -- Greater Heal
E[28811]={none=true} -- Reduced Threat
E[28812]={special=true} -- Head Rush
E[28814]={none=true} -- Revealed Flaw
E[28816]={special=true} -- Invigorate
E[28818]={special=true} -- Totemic Energy
E[28821]={none=true} -- Water Shield Bonus
E[28823]={none=true} -- Totemic Power
E[28829]={special=true} -- Corruption
E[28830]={special=true} -- Life Tap
E[28831]={special=true} -- Vampirism
E[28842]={special=true} -- Increased Hit Chance
E[28843]={special=true} --  Increased Spell Hit Chance
E[28844]={special=true} -- Revenge
E[28845]={special=true} -- Cheat Death
E[29068]={none=true} -- Increased Damage 2
E[29090]={none=true} -- Increased Armor 200 Dreadmist
E[29091]={none=true} -- Increased Armor 200 Magister
E[29092]={none=true} -- Increased Armor 200 Valor
E[29093]={none=true} -- Increased Armor 200 Lightforge
E[29094]={none=true} -- Increased Armor 200 Beaststalker
E[29095]={none=true} -- Increased Armor 200 Elements
E[29096]={none=true} -- Increased Armor 200 Shadowcraft
E[29097]={none=true} -- Increased Armor 200 Wildheart
E[29171]={special=true} -- Strong Current
E[30770]={ap=40} -- Attack Power 40 - Valor
E[30771]={ap=40} -- Attack Power 40 - Shadowcraft
E[30772]={ap=40} -- Attack Power 40 - Beaststalker
E[30775]={ap=40} -- Attack Power 40 - Lightforge
E[30777]={none=true} -- Increase Spell Dam 23 - Magister
E[30778]={none=true} -- Increase Spell Dam 23 - Dreadmist
E[30779]={none=true} -- Increase Spell Dam 23 - Devout
E[30780]={none=true} -- Increase Spell Dam 23 - Elements
E[41196]={special=true} -- Stormwolf's Frenzy Passive
E[41197]={special=true} -- Shaman Enhancement T3.5 3P Bonus
E[41198]={none=true} -- Improved Healing Way
E[41199]={special=true} -- Improved Restorative Totems
E[41358]={special=true} -- Mana Renewal Passive
E[41360]={special=true} -- Empowered Flash Heal Passive
E[41361]={special=true} -- Reduced Ability Costs
E[41363]={special=true} -- Warrior T3.5 5P Passive
E[44035]={special=true} -- Dragon’s Maw Passive
E[44065]={special=true} -- Lightning
E[44070]={special=true} -- Wild Regeneration Passive
E[44073]={special=true} -- Opportunistic Strike Passive
E[44076]={special=true} -- Purging Flames Passive
E[44081]={special=true} -- Impending Doom Passive
E[44085]={none=true} -- Cat to Serpent Form
E[44087]={special=true} -- Mark of Greymane Passive
E[45421]={none=true} -- Vampirism 2
E[45431]={ap=56} --  Attack Power - Feral (+56)
E[45491]={special=true} -- Moon's Blessing
E[45496]={special=true} -- Power Surge
E[45498]={special=true} -- Blood Tiger's Blessing
E[45501]={special=true} -- Blood Plague
E[45530]={none=true} -- Resilience 3
E[45531]={none=true} -- Resilience 6
E[45543]={special=true} -- Arcane Vulnerability
E[45846]={special=true} -- Fire Rune
E[45847]={none=true} -- Deflect
E[46000]={special=true} -- Improved Mending Light Heal
E[46112]={special=true} -- Seismic Strength Passive
E[46113]={special=true} -- Molten Blast Cast Time Reduction
E[46114]={special=true} -- Improved Earthquake
E[46762]={none=true} -- Improved Clearcasting
E[48000]={special=true} -- Lifebinding
E[48036]={none=true} -- Armor Penetration 100
E[48037]={none=true} -- Armor Penetration 150
E[49368]={special=true} -- Unrelenting Strikes Passive
E[51130]={special=true} -- Accursed Remains
E[51771]={none=true} -- Prophecy Threat Reduction
E[51772]={none=true} -- Improved Mind Flay
E[51774]={special=true} -- Epiphany
E[51775]={special=true} -- Transcendance Mana Burn Bonus
E[51776]={none=true} -- Vampiric Embrace Duration Bonus
E[51778]={special=true} -- Dark Transcendance
E[51779]={special=true} -- Faith Mind Control Resist Chance
E[51780]={special=true} -- Rapid Mind Blasting Passive
E[51782]={special=true} -- Mind Flay Damage Proc
E[51784]={special=true} -- Vampiric Aura Passive
E[51785]={none=true} -- Pestilence Fade Bonus
E[51789]={none=true} -- Oracle Chastise Duration
E[51795]={special=true} -- Pestilence Passive
E[51796]={special=true} -- Oracle's Insight Passive
E[51797]={special=true} -- Spiritual Elevation Passive
E[51798]={special=true} -- Improved Lightwell
E[51801]={special=true} -- Lawbringer Judgement Bonus
E[51803]={special=true} -- Holy Radiance Passive
E[51805]={special=true} -- Holy Radiance Passive
E[51806]={special=true} -- Consecration Cost Reduction
E[51807]={special=true} -- Holy Light Cost Reduction
E[51809]={special=true} -- Surge of Light
E[51811]={special=true} -- Add Holy Dam - Weap 03
E[51813]={none=true} -- Protective Light
E[51815]={special=true} -- Iron Shield Passive
E[51817]={special=true} -- Spirit of Arathor Passive
E[51818]={special=true} -- Improved Judgement Righteous Command 1
E[51819]={special=true} -- Improved Judgement Righteous Command 2
E[51820]={special=true} -- JoL FoL Healing Bonus
E[51821]={none=true} -- Holy Power
E[51823]={special=true} -- Exorcism Cooldown Reduction
E[51826]={special=true} -- Holy Shock Bonus Healing
E[51832]={special=true} -- Holy Might Strength Bonus
E[51834]={special=true} -- Crusade Passive
E[51836]={none=true} -- Block Mastery
E[51837]={special=true} -- Shaman Instant Cost Reduction
E[51838]={none=true} -- Flametongue Damage Bonus
E[51840]={special=true} -- Aftershock Passive
E[51841]={special=true} -- Stormstrike Lightning Strike Cooldown Bonus
E[51844]={special=true} -- Echoed Thunder
E[51846]={special=true} -- Seeking Thunder
E[51848]={none=true} -- Elemental Shell Passive
E[51849]={none=true} -- Earthmother's Attunement
E[51850]={none=true} -- Lightning Strike Shield Bonus
E[51851]={special=true} -- Improved Shocks
E[51855]={special=true} -- Shock Mastery
E[51856]={none=true} -- Shaman Strikes Cooldown Reset
E[51861]={none=true} -- Searing Totem Duration Bonus
E[51864]={none=true} -- Improved Flame Shock
E[51867]={special=true} -- Earth Shield Resistance Bonus Passive
E[51868]={none=true} -- Lightning Shield Trigger Passive
E[51870]={special=true} -- Lightning Bolt Duplication
E[51871]={special=true} -- Shapeshift Mana Reduction
E[51884]={special=true} -- Chain Lightning Extra Target
E[51886]={none=true} -- Increased Spell Hit Chance 3
E[51887]={special=true} -- Fire Totems Faster Cast
E[51891]={none=true} -- Stormwolf's Cunning Passive
E[51892]={special=true} -- Shaman Shield Charges Bonus
E[51893]={none=true} -- Reincarnation Mana Bonus
E[51894]={special=true} -- Improved Spirit Link
E[51899]={special=true} -- Effective Strike Passive
E[52322]={skill={all=5}} -- +5 to All Weapons
E[52323]={special=true} -- Balance Spells Cost Reduction
E[52325]={none=true} -- Cenarion Blessing Passive
E[52326]={special=true} -- Owlkin Frenzy Increased Regen
E[52328]={special=true} -- Thorned Bulwark Passive
E[52330]={special=true} -- Astral Shower Passive
E[52331]={none=true} -- Moonfire Insect Swarm Duration
E[52333]={special=true} -- Lesser Innervate Passive
E[52335]={special=true} -- Equilibrium Passive
E[52337]={none=true} -- Rapid Solstice Passive
E[52341]={special=true} -- Aviana's Torrent Passive
E[52342]={special=true} -- Improved Balance of All Things
E[52344]={special=true} -- Faster Healing Touch Cast
E[52345]={none=true} -- Resto T2.5 5p Bonus
E[52346]={special=true} -- Swiftmend Reduced Cooldown
E[52349]={special=true} -- Blooming Bud Passive
E[52350]={special=true} -- Faerie Fire (Feral) Reduced Cooldown
E[52351]={special=true} -- Tiger's Fury Reduced Cost
E[52352]={none=true} -- Ferocious Bite Frenzy
E[52354]={special=true} -- Improved Thorns
E[52355]={special=true} -- Savage Bite Cost Reduction
E[52357]={special=true} -- Frenzied Defense Passive
E[52358]={special=true} -- Rake Claw Reduced Cost
E[52360]={special=true} -- Improved Attacks Passive
E[52363]={special=true} -- Druid Taunt Hit Chance Bonus
E[52364]={special=true} -- Bear Form Health Bonus
E[52366]={special=true} -- Grizzled Hide Passive
E[52368]={special=true} -- Sharpened Claws Passive
E[52372]={none=true} -- Primal Ferocity
E[52401]={crit=2} -- Berserker Stance Extra Crit
E[52562]={none=true} -- Dispatch
E[52564]={none=true} -- Nightblade
E[52566]={none=true} -- Improved Presence of Mind
E[52568]={special=true} -- Revitalize
E[52570]={special=true} -- Cosmic Residue
E[52572]={special=true} -- Oversurge
E[52579]={special=true} -- Improved Mage Armor
E[52580]={special=true} -- Coalesced Mana
E[52582]={none=true} -- Erupting Shield
E[52584]={special=true} -- Guardian's Barrier
E[52586]={special=true} -- Evocation Mastery
E[52587]={none=true} -- Improved Arcane Rupture
E[52589]={special=true} -- Rift Feedback
E[52592]={special=true} -- Reality Fracture
E[52594]={none=true} -- Nether Overcharge
E[52596]={special=true} -- Mirror Magic
E[52598]={special=true} -- Improved Resonance Cascade
E[52599]={special=true} -- Felheart Drain Soul
E[52600]={none=true} -- Nemesis Drain Range
E[52601]={none=true} -- Nemesis Corruption and Siphon Life
E[52602]={special=true} -- Multishot and Carve Cooldown
E[52603]={special=true} -- Improved Swift Aspects
E[52604]={special=true} -- Dark Harvest Cooldown
E[52606]={none=true} -- Curse of Agony Bonus Damage
E[52607]={special=true} -- Lifeforce
E[52609]={special=true} -- Phantom Pain
E[52611]={special=true} -- Fel Heartbeat
E[52613]={special=true} -- Ruination
E[52620]={special=true} -- Plagued Heart
E[52624]={special=true} -- Subjugation
E[52626]={special=true} -- Corrupted Soul
E[52628]={special=true} -- Improved Siphon Life
E[52630]={special=true} -- Felfire Punishment
E[52655]={special=true} -- Improved Agony
E[52656]={none=true} -- Dark Harvest Doomguard
E[52681]={special=true} -- Immolate Cast Time Bonus
E[52682]={none=true} -- Conflagrate Tick Bonus
E[52684]={special=true} -- Steady Shot and Raptor Strike Crit Bonus
E[52685]={special=true} -- Pet Focus Regen Bonus
E[52686]={special=true} -- Unyielding Assault
E[52688]={none=true} -- Qiraji Poison
E[52690]={none=true} -- Crystal Infusion
E[52693]={special=true} -- Swipe Chain Bonus
E[52697]={none=true} -- Qiraji Recuperation
E[52698]={special=true} -- T2.5 Set Bonus - Hammer of Wrath
E[52699]={special=true} -- T2.5 Set Bonus - Pain Spike
E[52701]={none=true} -- Purge Haste Passive
E[52860]={special=true} -- Updraft
E[52862]={special=true} -- Downdraft
E[52880]={special=true} -- Improved Inner Fire
E[52881]={none=true} -- Holy and Discipline Cost Reduction
E[52882]={special=true} -- Castigation
E[52884]={none=true} -- Light Speed
E[52886]={special=true} -- Flickering Light
E[52888]={none=true} -- Improved Enlightened
E[52889]={special=true} -- Improved Holy Fire
E[52893]={none=true} -- Earthwall
E[52895]={special=true} -- Qiraji Deterioration
E[52897]={special=true} -- Uncoiled Shadows
E[52929]={none=true} -- Elemental Efficiency
E[52930]={special=true} -- Coil of the Hydra Passive
E[52932]={special=true} -- Tricolored Blast Passive
E[52938]={special=true} -- Blessed Wildfire - Holy Fire
E[52940]={special=true} -- Blessed Wildfire - Chastise
E[52941]={special=true} -- Blessed Wildfire - Power Word: Shield
E[52977]={none=true} -- Light Infusion Passive
E[52981]={special=true} -- Burning Zeal Passive
E[53200]={special=true} -- Bloodthirst Mortal Strike Cost Reduction
E[53203]={special=true} -- Overpowering Rage Passive
E[53204]={special=true} -- Whirlwind Extra Targets
E[53205]={none=true} -- Heroic Strike Slam Reduced Threat
E[53206]={special=true} -- Sweeping Strikes Death Wish Cost Reduction
E[53207]={special=true} -- Warrior Crit Damage Bonus
E[53208]={special=true} -- Rallying Cry Passive
E[57159]={none=true} -- Casting Regen 10%
E[57161]={none=true} -- Casting Regen 15%
E[58122]={special=true} -- Maddened Strikes Passive
E[58148]={special=true} -- Unyielding Determination Passive
E[58150]={special=true} -- Mounting Protection Passive
E[58153]={special=true} -- Hippogryph Spirit Passive
E[58156]={special=true} -- Ursine Restoration Passive
E[58158]={special=true} -- Brooding Rage Passive
E[58161]={special=true} -- Imparted Wisdom Passive
E[58163]={special=true} -- Tranquility of the Deer Passive
E[58165]={special=true} -- Stag's Edict Passive
E[58167]={special=true} -- Cervid Rejuvenation Passive
E[58169]={special=true} -- Hippogryph Charge Passive
-- END GENERATED SET EFFECTS
