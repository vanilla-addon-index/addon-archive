-- Ashen Builds item-set catalog. Generated from Tortoise DB SQLite.
-- Tooltip layout and spell-token resolution follow the current upstream viewer.
AshenBuilds = AshenBuilds or {}
AshenBuilds.SetCatalog = {}
AshenBuilds.ItemToSet = {}
local C = AshenBuilds.SetCatalog
local M = AshenBuilds.ItemToSet
AshenBuilds.SetCatalogMeta={dataVersion="ec14bfe00852",schemaRef="Xian55/tortoise-db-viewer main (2026-07-16)",setCount=359,memberCount=2064,bonusCount=1137}
C[1]={name="The Gladiator",classMask=0,items={{11726,"Savage Gladiator Chain",4,-1},{11731,"Savage Gladiator Greaves",3,-1},{11730,"Savage Gladiator Grips",3,-1},{11729,"Savage Gladiator Helm",3,-1},{11728,"Savage Gladiator Leggings",3,-1}},bonuses={{2,15666,"+100 Armor."},{3,13384,"Increased Defense +6."},{4,9336,"+30 Attack Power."},{5,7598,"Improves your chance to get a critical strike by 2%."}}}
C[41]={name="Dal'Rend's Arms",classMask=0,items={{12940,"Dal'Rend's Sacred Charge",3,-1},{12939,"Dal'Rend's Tribal Guardian",3,-1}},bonuses={{2,14056,"+50 Attack Power."}}}
C[65]={name="Spider's Kiss",classMask=0,items={{13183,"Venomspitter",3,-1},{13218,"Fang of the Crystal Spider",3,-1}},bonuses={{2,17332,"Chance on Hit: Immobilizes the target and lowers their armor by 100 for 10 sec."}}}
C[81]={name="The Postmaster",classMask=0,items={{13390,"The Postmaster's Band",3,-1},{13392,"The Postmaster's Seal",3,-1},{13391,"The Postmaster's Treads",3,-1},{13389,"The Postmaster's Trousers",3,-1},{13388,"The Postmaster's Tunic",3,-1}},bonuses={{2,9764,"+50 Armor."},{3,14590,"+10 Fire Resistance."},{3,14712,"+10 Arcane Resistance."},{4,9346,"Increases damage and healing done by magical spells and effects by up to 18."},{5,14410,"+20 Intellect."},{5,17498,"Increases run speed by 5%."}}}
C[121]={name="Cadaverous Garb",classMask=0,items={{14637,"Cadaverous Armor",3,-1},{14636,"Cadaverous Belt",3,-1},{14640,"Cadaverous Gloves",3,-1},{14638,"Cadaverous Leggings",3,-1},{14641,"Cadaverous Walkers",3,-1}},bonuses={{2,7516,"Increased Defense +3."},{3,9140,"+10 Attack Power."},{4,18686,"+15 All Resistances."},{5,15465,"Improves your chance to hit by 2%."}}}
C[122]={name="Necropile Raiment",classMask=0,items={{14631,"Necropile Boots",3,-1},{14629,"Necropile Cuffs",3,-1},{14632,"Necropile Leggings",3,-1},{14633,"Necropile Mantle",3,-1},{14626,"Necropile Robe",3,-1}},bonuses={{2,7516,"Increased Defense +3."},{3,7495,"+5 Intellect."},{4,18686,"+15 All Resistances."},{5,14047,"Increases damage and healing done by magical spells and effects by up to 23."}}}
C[123]={name="Bloodmail Regalia",classMask=0,items={{14614,"Bloodmail Belt",3,-1},{14616,"Bloodmail Boots",3,-1},{14615,"Bloodmail Gauntlets",3,-1},{14611,"Bloodmail Hauberk",3,-1},{14612,"Bloodmail Legguards",3,-1}},bonuses={{2,7516,"Increased Defense +3."},{3,9140,"+10 Attack Power."},{4,18686,"+15 All Resistances."},{5,13665,"Increases your chance to parry an attack by 1%."}}}
C[124]={name="Deathbone Guardian",classMask=0,items={{14624,"Deathbone Chestplate",3,-1},{14622,"Deathbone Gauntlets",3,-1},{14620,"Deathbone Girdle",3,-1},{14623,"Deathbone Legguards",3,-1},{14621,"Deathbone Sabatons",3,-1}},bonuses={{2,7516,"Increased Defense +3."},{3,9764,"+50 Armor."},{4,18686,"+15 All Resistances."},{5,13665,"Increases your chance to parry an attack by 1%."}}}
C[141]={name="Volcanic Armor",classMask=0,items={{15054,"Volcanic Leggings",2,-1},{15053,"Volcanic Breastplate",2,-1},{15055,"Volcanic Shoulders",2,-1}},bonuses={{3,9233,"5% chance of dealing 15 to 25 Fire damage on a successful melee attack."}}}
C[142]={name="Stormshroud Armor",classMask=32767,items={{15057,"Stormshroud Pants",3,-1},{15056,"Stormshroud Armor",3,-1},{15058,"Stormshroud Shoulders",3,-1},{21278,"Stormshroud Gloves",3,32767}},bonuses={{2,14027,"+24 Attack Power."},{3,44065,"Chance of dealing 35 to 50 Nature damage on a successful melee attack."},{4,23863,"Your melee attacks have a chance to restore 30 energy and increase your chance to dodge and melee attack speed by 10% for 8 sec."}}}
C[143]={name="Devilsaur Armor",classMask=0,items={{15063,"Devilsaur Gauntlets",3,-1},{15062,"Devilsaur Leggings",3,-1}},bonuses={{2,15465,"Improves your chance to hit by 2%."}}}
C[144]={name="Ironfeather Armor",classMask=0,items={{15067,"Ironfeather Shoulders",3,-1},{15066,"Ironfeather Breastplate",3,-1}},bonuses={{2,14799,"Increases damage and healing done by magical spells and effects by up to 20."}}}
C[161]={name="Defias Leather",classMask=0,items={{10402,"Blackened Defias Boots",2,-1},{10401,"Blackened Defias Gloves",2,-1},{10400,"Blackened Defias Leggings",2,-1},{81007,"Blackened Defias Mask",3,-1},{10403,"Blackened Defias Belt",2,-1},{10399,"Blackened Defias Armor",3,-1}},bonuses={{2,14712,"+10 Arcane Resistance."},{3,7575,"Increased Daggers +4."},{4,9762,"+30 Armor."},{5,44073,"Your successful melee attacks have a chance to strike the target again, dealing 33 to 45 Physical damage. This damage is increased by 35% if the target is not facing you."}}}
C[162]={name="Embrace of the Viper",classMask=0,items={{10412,"Belt of the Fang",2,-1},{10413,"Gloves of the Fang",2,-1},{6473,"Armor of the Fang",2,-1},{10411,"Footpads of the Fang",2,-1},{10410,"Leggings of the Fang",3,-1},{81006,"Cowl of the Fang",3,-1}},bonuses={{2,13679,"Increases your attack and casting speed by 1%."},{3,9408,"Increases healing done by spells and effects by up to 22."},{3,9411,"Increases damage done by Nature spells and effects by up to 14."},{4,9106,"+10 Intellect."},{5,44070,"When your health drops below 35%, you rapidly heal health over 5 sec. This effect can trigger only once every 3 min."},{6,44085,"Your Cat Form seems to react to the full embrace of the Viper."}}}
C[163]={name="Chain of the Scarlet Crusade",classMask=0,items={{10332,"Scarlet Boots",3,-1},{10333,"Scarlet Wristguards",2,-1},{10329,"Scarlet Belt",2,-1},{10331,"Scarlet Gauntlets",2,-1},{10328,"Scarlet Chestpiece",3,-1},{10330,"Scarlet Leggings",3,-1}},bonuses={{2,7517,"Increased Defense +4."},{3,14678,"+15 Shadow Resistance."},{4,18074,"+30 Attack Power when fighting Undead."},{5,15464,"Improves your chance to hit by 1%."},{6,44076,"Your successful melee attacks and damaging Holy spells have a chance to consume the enemy in holy flames for 80 to 95 Holy damage. Undead are stunned for 3 sec."}}}
C[181]={name="Magister's Regalia",classMask=0,items={{16683,"Magister's Bindings",3,-1},{16685,"Magister's Belt",3,-1},{16682,"Magister's Boots",3,-1},{16684,"Magister's Gloves",3,-1},{16689,"Magister's Mantle",3,-1},{16687,"Magister's Leggings",3,-1},{16686,"Magister's Crown",3,-1},{16688,"Magister's Robes",3,-1}},bonuses={{2,29091,"+200 Armor."},{4,30777,"Increases damage and healing done by magical spells and effects by up to 23."},{6,27867,"When struck in combat has a chance of freezing the attacker in place for 3 sec."},{8,18679,"+8 All Resistances."}}}
C[182]={name="Vestments of the Devout",classMask=0,items={{16697,"Devout Bracers",3,-1},{16696,"Devout Belt",3,-1},{16692,"Devout Gloves",3,-1},{16691,"Devout Sandals",3,-1},{16695,"Devout Mantle",3,-1},{16694,"Devout Skirt",3,-1},{16693,"Devout Crown",3,-1},{16690,"Devout Robe",3,-1}},bonuses={{2,14803,"+200 Armor."},{4,30779,"Increases damage and healing done by magical spells and effects by up to 23."},{6,27778,"When struck in combat has a chance of shielding the wearer in a protective shield which will absorb 350 damage."},{8,18679,"+8 All Resistances."}}}
C[183]={name="Dreadmist Raiment",classMask=0,items={{16703,"Dreadmist Bracers",3,-1},{16702,"Dreadmist Belt",3,-1},{16704,"Dreadmist Sandals",3,-1},{16705,"Dreadmist Wraps",3,-1},{16701,"Dreadmist Mantle",3,-1},{16699,"Dreadmist Leggings",3,-1},{16698,"Dreadmist Mask",3,-1},{16700,"Dreadmist Robe",3,-1}},bonuses={{2,29090,"+200 Armor."},{4,30778,"Increases damage and healing done by magical spells and effects by up to 23."},{6,27780,"When struck in combat has a chance of causing the attacker to flee in terror for 2 seconds."},{8,18679,"+8 All Resistances."}}}
C[184]={name="Shadowcraft Armor",classMask=0,items={{16710,"Shadowcraft Bracers",3,-1},{16713,"Shadowcraft Belt",3,-1},{16711,"Shadowcraft Boots",3,-1},{16712,"Shadowcraft Gloves",3,-1},{16708,"Shadowcraft Spaulders",3,-1},{16709,"Shadowcraft Pants",3,-1},{16707,"Shadowcraft Cap",3,-1},{16721,"Shadowcraft Tunic",3,-1}},bonuses={{2,29096,"+200 Armor."},{4,30771,"+40 Attack Power."},{6,27787,"Chance on melee attack to restore 35 energy."},{8,18679,"+8 All Resistances."}}}
C[185]={name="Wildheart Raiment",classMask=0,items={{16714,"Wildheart Bracers",3,-1},{16716,"Wildheart Belt",3,-1},{16715,"Wildheart Boots",3,-1},{16717,"Wildheart Gloves",3,-1},{16718,"Wildheart Spaulders",3,-1},{16719,"Wildheart Kilt",3,-1},{16720,"Wildheart Cowl",3,-1},{16706,"Wildheart Vest",3,-1}},bonuses={{2,29097,"+200 Armor."},{4,9334,"+26 Attack Power."},{4,9344,"Increases damage and healing done by magical spells and effects by up to 15."},{6,27781,"When struck in combat has a chance of returning 300 mana, 10 rage, or 40 energy to the wearer."},{8,18679,"+8 All Resistances."}}}
C[186]={name="Beaststalker Armor",classMask=0,items={{16681,"Beaststalker's Bindings",3,-1},{16680,"Beaststalker's Belt",3,-1},{16675,"Beaststalker's Boots",3,-1},{16676,"Beaststalker's Gloves",3,-1},{16679,"Beaststalker's Mantle",3,-1},{16678,"Beaststalker's Pants",3,-1},{16677,"Beaststalker's Cap",3,-1},{16674,"Beaststalker's Tunic",3,-1}},bonuses={{2,29094,"+200 Armor."},{4,30772,"+40 Attack Power."},{6,27785,"Your normal melee and ranged attacks have a 4% chance of restoring 200 mana."},{8,18679,"+8 All Resistances."}}}
C[187]={name="The Elements",classMask=0,items={{16671,"Bindings of Elements",3,-1},{16673,"Cord of Elements",3,-1},{16670,"Boots of Elements",3,-1},{16672,"Gauntlets of Elements",3,-1},{16669,"Pauldrons of Elements",3,-1},{16668,"Kilt of Elements",3,-1},{16667,"Coif of Elements",3,-1},{16666,"Vest of Elements",3,-1}},bonuses={{2,29095,"+200 Armor."},{4,30780,"Increases damage and healing done by magical spells and effects by up to 23."},{6,27774,"Chance on spell cast to increase your damage and healing by up to 95 for 10 sec."},{8,18679,"+8 All Resistances."}}}
C[188]={name="Lightforge Armor",classMask=0,items={{16722,"Lightforge Bracers",3,-1},{16723,"Lightforge Belt",3,-1},{16725,"Lightforge Boots",3,-1},{16724,"Lightforge Gauntlets",3,-1},{16729,"Lightforge Spaulders",3,-1},{16728,"Lightforge Legplates",3,-1},{16727,"Lightforge Helm",3,-1},{16726,"Lightforge Breastplate",3,-1}},bonuses={{2,29093,"+200 Armor."},{4,30775,"+40 Attack Power."},{6,27498,"Chance on melee attack to increase your damage and healing done by magical spells and effects by up to 95 for 10 sec."},{8,18679,"+8 All Resistances."}}}
C[189]={name="Battlegear of Valor",classMask=0,items={{16735,"Bracers of Valor",3,-1},{16736,"Belt of Valor",3,-1},{16734,"Boots of Valor",3,-1},{16737,"Gauntlets of Valor",3,-1},{16733,"Spaulders of Valor",3,-1},{16732,"Legplates of Valor",3,-1},{16731,"Helm of Valor",3,-1},{16730,"Breastplate of Valor",3,-1}},bonuses={{2,29092,"+200 Armor."},{4,30770,"+40 Attack Power."},{6,27419,"Chance on melee attack to heal you for 88 to 132 and increase your rage by 10."},{8,18679,"+8 All Resistances."}}}
C[201]={name="Arcanist's Regalia",classMask=128,items={{16802,"Arcanist Belt",4,128},{16799,"Arcanist Bindings",4,128},{16800,"Arcanist Boots",4,128},{16795,"Arcanist Crown",4,128},{16801,"Arcanist Gloves",4,128},{16796,"Arcanist Leggings",4,128},{16797,"Arcanist Mantle",4,128},{16798,"Arcanist Robes",4,128}},bonuses={{3,9346,"Increases damage and healing done by magical spells and effects by up to 18."},{5,26175,"Decreases the magical resistances of your spell targets by -10."},{8,23545,"Decreases the threat generated by your spells by -15%."}}}
C[202]={name="Vestments of Prophecy",classMask=16,items={{16811,"Boots of Prophecy",4,16},{16813,"Circlet of Prophecy",4,16},{16817,"Girdle of Prophecy",4,16},{16812,"Gloves of Prophecy",4,16},{16816,"Mantle of Prophecy",4,16},{16814,"Pants of Prophecy",4,16},{16815,"Robes of Prophecy",4,16},{16819,"Vambraces of Prophecy",4,16}},bonuses={{3,21973,"-0 sec to the casting time of your Flash Heal spell."},{5,21092,"Improves your chance to get a critical strike with Holy spells by 2%."},{8,23550,"Increases your chance of a critical hit with Prayer of Healing by 25%."}}}
C[203]={name="Felheart Raiment",classMask=256,items={{16806,"Felheart Belt",4,256},{16804,"Felheart Bracers",4,256},{16805,"Felheart Gloves",4,256},{16808,"Felheart Horns",4,256},{16810,"Felheart Pants",4,256},{16809,"Felheart Robes",4,256},{16807,"Felheart Shoulder Pads",4,256},{16803,"Felheart Slippers",4,256}},bonuses={{3,23554,"Health or Mana gained from Drain Life and Drain Mana increased by 15%."},{5,21741,"Your pet gains 15 stamina and 100 spell resistance against all schools of magic."},{8,23553,"Mana cost of Fire and Shadow spells reduced by -15%."}}}
C[204]={name="Nightslayer Armor",classMask=8,items={{16827,"Nightslayer Belt",4,8},{16824,"Nightslayer Boots",4,8},{16825,"Nightslayer Bracelets",4,8},{16820,"Nightslayer Chestpiece",4,8},{16821,"Nightslayer Cover",4,8},{16826,"Nightslayer Gloves",4,8},{16822,"Nightslayer Pants",4,8},{16823,"Nightslayer Shoulder Pads",4,8}},bonuses={{3,21874,"Reduces the cooldown of your Vanish ability by -30 sec."},{5,21975,"Increases your maximum Energy by 10."},{8,23582,"Heals the rogue for 500 when Vanish is performed."}}}
C[205]={name="Cenarion Raiment",classMask=1024,items={{16828,"Cenarion Belt",4,1024},{16829,"Cenarion Boots",4,1024},{16830,"Cenarion Bracers",4,1024},{16831,"Cenarion Gloves",4,1024},{16834,"Cenarion Helm",4,1024},{16835,"Cenarion Leggings",4,1024},{16836,"Cenarion Spaulders",4,1024},{16833,"Cenarion Vestments",4,1024}},bonuses={{3,23557,"Damage dealt by Thorns increased by 4 and duration increased by 50%."},{5,18382,"Improves your chance to get a critical strike with spells by 2%."},{8,23556,"Reduces the cooldown of your Tranquility and Hurricane spells by -50%."}}}
C[206]={name="Giantstalker Armor",classMask=4,items={{16851,"Giantstalker's Belt",4,4},{16849,"Giantstalker's Boots",4,4},{16850,"Giantstalker's Bracers",4,4},{16845,"Giantstalker's Breastplate",4,4},{16848,"Giantstalker's Epaulets",4,4},{16852,"Giantstalker's Gloves",4,4},{16846,"Giantstalker's Helmet",4,4},{16847,"Giantstalker's Leggings",4,4}},bonuses={{3,23560,"Increases the range of your Mend Pet spell by 50% and the effect by 10%. Also reduces the cost by -30%."},{5,21926,"Increases your pet's stamina by 30 and all spell resistances by 40."},{8,23566,"Increases the damage of Carve, Multi-shot and Volley by 15%."}}}
C[207]={name="The Earthfury",classMask=64,items={{16838,"Earthfury Belt",4,64},{16837,"Earthfury Boots",4,64},{16840,"Earthfury Bracers",4,64},{16841,"Earthfury Chestpiece",4,64},{16839,"Earthfury Gloves",4,64},{16842,"Earthfury Helmet",4,64},{16843,"Earthfury Pants",4,64},{16844,"Earthfury Spaulders",4,64}},bonuses={{3,21895,"Increases the radius of your totems that affect friendly targets by 10 yards."},{5,23572,"After casting your Healing Wave or Lesser Healing Wave spell, gives you a 25% chance to gain Mana equal to 35% of the base cost of the spell."},{8,52893,"Your Healing Wave and Lesser Healing Wave have a 25% chance to surround the target with an earth wall, absorbing 250 damage for 6 sec."}}}
C[208]={name="Lawbringer Armor",classMask=2,items={{16858,"Lawbringer Belt",4,2},{16859,"Lawbringer Boots",4,2},{16857,"Lawbringer Bracers",4,2},{16853,"Lawbringer Breastplate",4,2},{16860,"Lawbringer Gloves",4,2},{16854,"Lawbringer Helm",4,2},{16855,"Lawbringer Legplates",4,2},{16856,"Lawbringer Spaulders",4,2},{1982861,"Lawbringer Spaulders",4,2}},bonuses={{3,9317,"Increases healing done by spells and effects by up to 31."},{5,18382,"Improves your chance to get a critical strike with spells by 2%."},{8,21747,"Gives the Paladin a chance on every melee hit to heal your party for 189 to 211."}}}
C[209]={name="Battlegear of Might",classMask=1,items={{16864,"Belt of Might",4,1},{16861,"Bracers of Might",4,1},{16865,"Breastplate of Might",4,1},{16863,"Gauntlets of Might",4,1},{16866,"Helm of Might",4,1},{16867,"Legplates of Might",4,1},{16868,"Pauldrons of Might",4,1},{16862,"Sabatons of Might",4,1}},bonuses={{3,23562,"Increases the block value of your shield by 30."},{5,21838,"Gives you a chance to generate an additional Rage point whenever damage is dealt to you."},{8,23561,"Increases the threat generated by Sunder Armor by 15%."}}}
C[210]={name="Netherwind Regalia",classMask=128,items={{16818,"Netherwind Belt",4,128},{16918,"Netherwind Bindings",4,128},{16912,"Netherwind Boots",4,128},{16914,"Netherwind Crown",4,128},{16913,"Netherwind Gloves",4,128},{16917,"Netherwind Mantle",4,128},{16915,"Netherwind Pants",4,128},{16916,"Netherwind Robes",4,128}},bonuses={{3,21879,"Reduces the threat generated by your Scorch, Arcane Missiles, Fireball, and Frostbolt spells."},{5,23549,"Increases the radius of Arcane Explosion, Flamestrike, and Blizzard by 25%."},{8,22007,"10% chance after casting Arcane Missiles, Fireball, or Frostbolt that your next spell with a casting time under 10 seconds cast instantly."}}}
C[211]={name="Vestments of Transcendence",classMask=16,items={{16925,"Belt of Transcendence",4,16},{16926,"Bindings of Transcendence",4,16},{16919,"Boots of Transcendence",4,16},{16921,"Halo of Transcendence",4,16},{16920,"Handguards of Transcendence",4,16},{16922,"Leggings of Transcendence",4,16},{16924,"Pauldrons of Transcendence",4,16},{16923,"Robes of Transcendence",4,16}},bonuses={{3,21894,"Allows 15% of your Mana regeneration to continue while casting."},{5,21853,"When struck in melee there is a chance you will Fade for 4 sec."},{8,22010,"Your Greater Heals now have a heal over time component equivalent to a rank 5 Renew."}}}
C[212]={name="Nemesis Raiment",classMask=256,items={{16933,"Nemesis Belt",4,256},{16934,"Nemesis Bracers",4,256},{16928,"Nemesis Gloves",4,256},{16930,"Nemesis Pants",4,256},{16931,"Nemesis Robes",4,256},{16929,"Nemesis Skullcap",4,256},{16927,"Nemesis Slippers",4,256},{16932,"Nemesis Spaulders",4,256}},bonuses={{3,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{5,21922,"Your pet gains 20 stamina and 130 spell resistance against all schools of magic."},{8,23555,"Reduces the threat generated by your Destruction spells by -20%."}}}
C[213]={name="Bloodfang Armor",classMask=8,items={{16910,"Bloodfang Belt",4,8},{16906,"Bloodfang Boots",4,8},{16911,"Bloodfang Bracers",4,8},{16905,"Bloodfang Chestpiece",4,8},{16907,"Bloodfang Gloves",4,8},{16908,"Bloodfang Hood",4,8},{16909,"Bloodfang Pants",4,8},{16832,"Bloodfang Spaulders",4,8}},bonuses={{3,21881,"Increases the chance to apply poisons to your target by 5%."},{5,23558,"Improves the threat reduction of Feint by 25%."},{8,23581,"Gives the Rogue a chance to inflict 283 to 317 damage on the target and heal the Rogue for 50 health every sec. for 6 sec. on a melee hit."}}}
C[214]={name="Stormrage Raiment",classMask=1024,items={{16903,"Stormrage Belt",4,1024},{1447079,"Stormrage Belt",4,1024},{16898,"Stormrage Boots",4,1024},{1447080,"Stormrage Boots",4,1024},{16904,"Stormrage Bracers",4,1024},{1447081,"Stormrage Bracers",4,1024},{16897,"Stormrage Chestguard",4,1024},{1901786,"Stormrage Chestguard",4,1024},{16900,"Stormrage Cover",4,1024},{16899,"Stormrage Gloves",4,1024},{1447082,"Stormrage Gloves",4,1024},{16901,"Stormrage Legguards",4,1024},{16902,"Stormrage Pauldrons",4,1024}},bonuses={{3,21894,"Allows 15% of your Mana regeneration to continue while casting."},{5,21872,"Reduces the casting time of your Regrowth spell by 0 sec."},{8,21871,"Increases the duration of your Rejuvenation spell by 2 sec."}}}
C[215]={name="Dragonstalker Armor",classMask=4,items={{16936,"Dragonstalker's Belt",4,4},{16935,"Dragonstalker's Bracers",4,4},{16942,"Dragonstalker's Breastplate",4,4},{1594113,"Dragonstalker's Breastplate",4,4},{16940,"Dragonstalker's Gauntlets",4,4},{1586329,"Dragonstalker's Gauntlets",4,4},{16941,"Dragonstalker's Greaves",4,4},{1568469,"Dragonstalker's Greaves",4,4},{16939,"Dragonstalker's Helm",4,4},{604518,"Dragonstalker's Helm",4,4},{16938,"Dragonstalker's Legguards",4,4},{1586121,"Dragonstalker's Legguards",4,4},{16937,"Dragonstalker's Spaulders",4,4},{1568468,"Dragonstalker's Spaulders",4,4}},bonuses={{3,23559,"Increases the Ranged Attack Power bonus of your Aspect of the Hawk by 20% and Melee Attack Power bonus of your Aspect of the Wolf by 20%."},{5,21928,"Increases your pet's stamina by 40 and all spell resistances by 60."},{8,23578,"You have a chance whenever you deal melee or ranged damage to gain the Detect Weakness effect. Detect Weakness increases your Attack Power by 450 for 7 sec."}}}
C[216]={name="Garb of the Ten Storms",classMask=64,items={{16943,"Bindings of Ten Storms",4,64},{16945,"Epaulets of Ten Storms",4,64},{16948,"Gauntlets of Ten Storms",4,64},{16949,"Greaves of Ten Storms",4,64},{16946,"Legplates of Ten Storms",4,64},{16950,"Raiments of Ten Storms",4,64},{16944,"Sash of Ten Storms",4,64},{16947,"Visor of Ten Storms",4,64}},bonuses={{3,51864,"Increases the duration of your Flame Shock by 6 seconds."},{5,51868,"Your Shock spells and Lightning Bolt have a and 15% chance respectively to trigger your Lightning Shield's effect on the target without expending a charge."},{8,51870,"Your Lightning Bolt has a chance to discharge an additional Lightning Bolt at no additional cost that does not generate any threat, but its damage is reduced by 50%. This effect can trigger only once every 3 sec."}}}
C[217]={name="Judgement Armor",classMask=2,items={{16952,"Judgement Belt",4,2},{1363583,"Judgement Belt",4,2},{16957,"Judgement Boots",4,2},{16951,"Judgement Bracers",4,2},{16958,"Judgement Breastplate",4,2},{16956,"Judgement Gloves",4,2},{1245005,"Judgement Gloves",4,2},{16955,"Judgement Helm",4,2},{1982860,"Judgement Helm",4,2},{16954,"Judgement Legplates",4,2},{1982862,"Judgement Legplates",4,2},{16953,"Judgement Spaulders",4,2}},bonuses={{3,18037,"Increases healing done by spells and effects by up to 57."},{5,51807,"Reduces the mana cost of your Holy Light spell by -15%."},{8,51809,"Whenever you critically heal a target, you have a chance to heal them for an additional 300 health."}}}
C[218]={name="Battlegear of Wrath",classMask=1,items={{16959,"Bracelets of Wrath",4,1},{16966,"Breastplate of Wrath",4,1},{16964,"Gauntlets of Wrath",4,1},{16963,"Helm of Wrath",4,1},{16962,"Legplates of Wrath",4,1},{16961,"Pauldrons of Wrath",4,1},{16965,"Sabatons of Wrath",4,1},{16960,"Waistband of Wrath",4,1}},bonuses={{3,23563,"Increases the attack power granted by Battle Shout by 30."},{5,21890,"Chance after using an offensive ability requiring rage that your next offensive ability requires -5 less rage to use."},{8,23548,"Chance to parry the next attack after a block."}}}
C[221]={name="Garb of Thero-shan",classMask=8,items={{7950,"Armor of Thero-shan",2,8},{7952,"Boots of Thero-shan",2,8},{7948,"Girdle of Thero-shan",2,8},{7951,"Hands of Thero-shan",2,8},{7949,"Leggings of Thero-shan",2,8},{7953,"Mask of Thero-shan",2,8}},bonuses={{6,7597,"Improves your chance to get a critical strike by 1%."}}}
C[241]={name="Shard of the Gods",classMask=0,items={{17082,"Shard of the Flame",4,-1},{17064,"Shard of the Scale",4,-1}},bonuses={{2,18681,"+10 All Resistances."},{2,21603,"Restores 8 health per 5 sec."},{2,21629,"Restores 8 mana per 5 sec."}}}
C[261]={name="Spirit of Eskhandar",classMask=0,items={{18205,"Eskhandar's Collar",4,-1},{18202,"Eskhandar's Left Claw",4,-1},{18204,"Eskhandar's Pelt",4,-1},{18203,"Eskhandar's Right Claw",4,-1}},bonuses={{4,22648,"1% chance on a melee critical hit to call forth the spirit of Eskhandar to protect you in battle for 120 sec."}}}
C[281]={name="Champion's Battlegear",classMask=1,items={{16509,"Blood Guard's Plate Boots",3,1},{16510,"Blood Guard's Plate Gloves",3,1},{16514,"Champion's Plate Headguard",3,1},{16516,"Champion's Plate Pauldrons",3,1},{16513,"Legionnaire's Plate Armor",3,1},{16515,"Legionnaire's Plate Legguards",3,1}},bonuses={{2,13665,"Increases your chance to parry an attack by 1%."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{4,22738,"Reduces the cooldown of your Intercept and Intervene abilities by -5 sec."},{6,14462,"+15 Stamina."}}}
C[282]={name="Lieutenant Commander's Battlegear",classMask=1,items={{16430,"Knight-Captain's Plate Chestguard",3,1},{16431,"Knight-Captain's Plate Leggings",3,1},{16405,"Knight-Lieutenant's Plate Boots",3,1},{16406,"Knight-Lieutenant's Plate Gauntlets",3,1},{16429,"Lieutenant Commander's Plate Helm",3,1},{16432,"Lieutenant Commander's Plate Pauldrons",3,1}},bonuses={{2,13665,"Increases your chance to parry an attack by 1%."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{4,22738,"Reduces the cooldown of your Intercept and Intervene abilities by -5 sec."},{6,14462,"+15 Stamina."}}}
C[301]={name="Champion's Earthshaker",classMask=64,items={{16519,"Blood Guard's Mail Grips",3,64},{16518,"Blood Guard's Mail Walkers",3,64},{16521,"Champion's Mail Helm",3,64},{16524,"Champion's Mail Shoulders",3,64},{16522,"Legionnaire's Mail Chestpiece",3,64},{16523,"Legionnaire's Mail Leggings",3,64}},bonuses={{2,14049,"+40 Attack Power."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{4,22804,"Improves your chance to get a critical strike with all Shock spells by 2%."},{6,14462,"+15 Stamina."}}}
C[321]={name="Imperial Plate",classMask=0,items={{12424,"Imperial Plate Belt",2,-1},{12428,"Imperial Plate Shoulders",2,-1},{65007,"Imperial Plate Gauntlets",2,-1},{12425,"Imperial Plate Bracers",2,-1},{12426,"Imperial Plate Boots",2,-1},{12427,"Imperial Plate Helm",2,-1},{12422,"Imperial Plate Chest",2,-1},{12429,"Imperial Plate Leggings",2,-1}},bonuses={{2,15666,"+100 Armor."},{4,9335,"+28 Attack Power."},{6,14465,"+18 Stamina."},{8,13665,"Increases your chance to parry an attack by 1%."}}}
C[341]={name="Champion's Regalia",classMask=128,items={{16485,"Blood Guard's Silk Footwraps",3,128},{16487,"Blood Guard's Silk Gloves",3,128},{16489,"Champion's Silk Hood",3,128},{16492,"Champion's Silk Shoulderpads",3,128},{16490,"Legionnaire's Silk Pants",3,128},{16491,"Legionnaire's Silk Robes",3,128}},bonuses={{2,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{4,23025,"Reduces the cooldown of your Blink spell by -2 sec."},{6,14462,"+15 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[342]={name="Champion's Raiment",classMask=16,items={{17616,"Blood Guard's Satin Boots",3,16},{17617,"Blood Guard's Satin Gloves",3,16},{17610,"Champion's Satin Cowl",3,16},{17613,"Champion's Satin Shoulderpads",3,16},{17611,"Legionnaire's Satin Trousers",3,16},{17612,"Legionnaire's Satin Vestments",3,16}},bonuses={{2,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{4,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{6,14462,"+15 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[343]={name="Lieutenant Commander's Regalia",classMask=128,items={{16414,"Knight-Captain's Silk Leggings",3,128},{16413,"Knight-Captain's Silk Raiment",3,128},{16369,"Knight-Lieutenant's Silk Boots",3,128},{16391,"Knight-Lieutenant's Silk Gloves",3,128},{16416,"Lieutenant Commander's Crown",3,128},{16415,"Lieutenant Commander's Silk Spaulders",3,128}},bonuses={{2,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{4,23025,"Reduces the cooldown of your Blink spell by -2 sec."},{6,14462,"+15 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[344]={name="Lieutenant Commander's Raiment",classMask=16,items={{17599,"Knight-Captain's Satin Leggings",3,16},{17600,"Knight-Captain's Satin Robes",3,16},{17594,"Knight-Lieutenant's Satin Boots",3,16},{17596,"Knight-Lieutenant's Satin Gloves",3,16},{17598,"Lieutenant Commander's Diadem",3,16},{17601,"Lieutenant Commander's Satin Amice",3,16}},bonuses={{2,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{4,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{6,14462,"+15 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[345]={name="Champion's Threads",classMask=256,items={{17576,"Blood Guard's Dreadweave Boots",3,256},{17577,"Blood Guard's Dreadweave Gloves",3,256},{17570,"Champion's Dreadweave Hood",3,256},{17573,"Champion's Dreadweave Shoulders",3,256},{17571,"Legionnaire's Dreadweave Leggings",3,256},{17572,"Legionnaire's Dreadweave Robe",3,256}},bonuses={{2,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{4,23047,"Reduces the casting time of your Immolate spell by 0.2 sec."},{6,14462,"+15 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[346]={name="Lieutenant Commander's Threads",classMask=256,items={{17567,"Knight-Captain's Dreadweave Leggings",3,256},{17568,"Knight-Captain's Dreadweave Robe",3,256},{17562,"Knight-Lieutenant's Dreadweave Boots",3,256},{17564,"Knight-Lieutenant's Dreadweave Gloves",3,256},{17569,"Lieutenant Commander's Dreadweave Mantle",3,256},{17566,"Lieutenant Commander's Headguard",3,256}},bonuses={{2,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{4,23047,"Reduces the casting time of your Immolate spell by 0.2 sec."},{6,14462,"+15 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[347]={name="Champion's Vestments",classMask=8,items={{16498,"Blood Guard's Leather Treads",3,8},{16499,"Blood Guard's Leather Vices",3,8},{16506,"Champion's Leather Headguard",3,8},{16507,"Champion's Leather Mantle",3,8},{16505,"Legionnaire's Leather Hauberk",3,8},{16508,"Legionnaire's Leather Leggings",3,8}},bonuses={{2,13665,"Increases your chance to parry an attack by 1%."},{4,23048,"Reduces the cooldown of your Gouge ability by -1 sec."},{6,14462,"+15 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[348]={name="Lieutenant Commander's Vestments",classMask=8,items={{16417,"Knight-Captain's Leather Armor",3,8},{16419,"Knight-Captain's Leather Legguards",3,8},{16392,"Knight-Lieutenant's Leather Boots",3,8},{16396,"Knight-Lieutenant's Leather Gauntlets",3,8},{16420,"Lieutenant Commander's Leather Spaulders",3,8},{16418,"Lieutenant Commander's Leather Veil",3,8}},bonuses={{2,13665,"Increases your chance to parry an attack by 1%."},{4,23048,"Reduces the cooldown of your Gouge ability by -1 sec."},{6,14462,"+15 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[361]={name="Champion's Pursuit",classMask=4,items={{16531,"Blood Guard's Chain Boots",3,4},{16530,"Blood Guard's Chain Gauntlets",3,4},{16526,"Champion's Chain Headguard",3,4},{16528,"Champion's Chain Pauldrons",3,4},{16525,"Legionnaire's Chain Breastplate",3,4},{16527,"Legionnaire's Chain Leggings",3,4}},bonuses={{2,13665,"Increases your chance to parry an attack by 1%."},{4,23158,"Reduces the cooldown of Concussive Shot by -1 sec and Wing Clip by 0 sec."},{6,14462,"+15 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[362]={name="Lieutenant Commander's Pursuit",classMask=4,items={{16425,"Knight-Captain's Chain Hauberk",3,4},{16426,"Knight-Captain's Chain Leggings",3,4},{16401,"Knight-Lieutenant's Chain Boots",3,4},{16403,"Knight-Lieutenant's Chain Gauntlets",3,4},{16428,"Lieutenant Commander's Chain Helmet",3,4},{16427,"Lieutenant Commander's Chain Pauldrons",3,4}},bonuses={{2,13665,"Increases your chance to parry an attack by 1%."},{4,23158,"Reduces the cooldown of Concussive Shot by -1 sec and Wing Clip by 0 sec."},{6,14462,"+15 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[381]={name="Lieutenant Commander's Sanctuary",classMask=1024,items={{16422,"Knight-Captain's Dragonhide Leggings",3,1024},{16421,"Knight-Captain's Dragonhide Tunic",3,1024},{16393,"Knight-Lieutenant's Dragonhide Footwraps",3,1024},{16397,"Knight-Lieutenant's Dragonhide Gloves",3,1024},{16423,"Lieutenant Commander's Dragonhide Epaulets",3,1024},{16424,"Lieutenant Commander's Dragonhide Shroud",3,1024}},bonuses={{2,14049,"+40 Attack Power."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14462,"+15 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[382]={name="Champion's Sanctuary",classMask=1024,items={{16494,"Blood Guard's Dragonhide Boots",3,1024},{16496,"Blood Guard's Dragonhide Gauntlets",3,1024},{16503,"Champion's Dragonhide Helm",3,1024},{16501,"Champion's Dragonhide Spaulders",3,1024},{16504,"Legionnaire's Dragonhide Breastplate",3,1024},{16502,"Legionnaire's Dragonhide Trousers",3,1024}},bonuses={{2,14049,"+40 Attack Power."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14462,"+15 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[383]={name="Warlord's Battlegear",classMask=1,items={{16545,"General's Plate Boots",4,1},{16548,"General's Plate Gauntlets",4,1},{16543,"General's Plate Leggings",4,1},{16541,"Warlord's Plate Armor",4,1},{16542,"Warlord's Plate Headpiece",4,1},{16544,"Warlord's Plate Shoulders",4,1}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,22738,"Reduces the cooldown of your Intercept and Intervene abilities by -5 sec."},{6,14049,"+40 Attack Power."}}}
C[384]={name="Field Marshal's Battlegear",classMask=1,items={{16477,"Field Marshal's Plate Armor",4,1},{16478,"Field Marshal's Plate Helm",4,1},{16480,"Field Marshal's Plate Shoulderguards",4,1},{16483,"Marshal's Plate Boots",4,1},{16484,"Marshal's Plate Gauntlets",4,1},{16479,"Marshal's Plate Legguards",4,1}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,22738,"Reduces the cooldown of your Intercept and Intervene abilities by -5 sec."},{6,14049,"+40 Attack Power."}}}
C[386]={name="Warlord's Earthshaker",classMask=64,items={{16573,"General's Mail Boots",4,64},{16574,"General's Mail Gauntlets",4,64},{16579,"General's Mail Leggings",4,64},{16577,"Warlord's Mail Armor",4,64},{16578,"Warlord's Mail Helm",4,64},{16580,"Warlord's Mail Spaulders",4,64}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,22804,"Improves your chance to get a critical strike with all Shock spells by 2%."},{6,14049,"+40 Attack Power."}}}
C[387]={name="Warlord's Regalia",classMask=128,items={{16539,"General's Silk Boots",4,128},{16540,"General's Silk Handguards",4,128},{16534,"General's Silk Trousers",4,128},{16536,"Warlord's Silk Amice",4,128},{16533,"Warlord's Silk Cowl",4,128},{16535,"Warlord's Silk Raiment",4,128}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,23025,"Reduces the cooldown of your Blink spell by -2 sec."},{6,14047,"Increases damage and healing done by magical spells and effects by up to 23."}}}
C[388]={name="Field Marshal's Regalia",classMask=128,items={{16441,"Field Marshal's Coronet",4,128},{16444,"Field Marshal's Silk Spaulders",4,128},{16443,"Field Marshal's Silk Vestments",4,128},{16437,"Marshal's Silk Footwraps",4,128},{16440,"Marshal's Silk Gloves",4,128},{16442,"Marshal's Silk Leggings",4,128}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,23025,"Reduces the cooldown of your Blink spell by -2 sec."},{6,14047,"Increases damage and healing done by magical spells and effects by up to 23."}}}
C[389]={name="Field Marshal's Raiment",classMask=16,items={{17602,"Field Marshal's Headdress",4,16},{17604,"Field Marshal's Satin Mantle",4,16},{17605,"Field Marshal's Satin Vestments",4,16},{17608,"Marshal's Satin Gloves",4,16},{17603,"Marshal's Satin Pants",4,16},{17607,"Marshal's Satin Sandals",4,16}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{6,14047,"Increases damage and healing done by magical spells and effects by up to 23."}}}
C[390]={name="Warlord's Raiment",classMask=16,items={{17618,"General's Satin Boots",4,16},{17620,"General's Satin Gloves",4,16},{17625,"General's Satin Leggings",4,16},{17623,"Warlord's Satin Cowl",4,16},{17622,"Warlord's Satin Mantle",4,16},{17624,"Warlord's Satin Robes",4,16}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{6,14047,"Increases damage and healing done by magical spells and effects by up to 23."}}}
C[391]={name="Warlord's Threads",classMask=256,items={{17586,"General's Dreadweave Boots",4,256},{17588,"General's Dreadweave Gloves",4,256},{17593,"General's Dreadweave Pants",4,256},{17591,"Warlord's Dreadweave Hood",4,256},{17590,"Warlord's Dreadweave Mantle",4,256},{17592,"Warlord's Dreadweave Robe",4,256}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,23047,"Reduces the casting time of your Immolate spell by 0.2 sec."},{6,14047,"Increases damage and healing done by magical spells and effects by up to 23."}}}
C[392]={name="Field Marshal's Threads",classMask=256,items={{17578,"Field Marshal's Coronal",4,256},{17581,"Field Marshal's Dreadweave Robe",4,256},{17580,"Field Marshal's Dreadweave Shoulders",4,256},{17583,"Marshal's Dreadweave Boots",4,256},{17584,"Marshal's Dreadweave Gloves",4,256},{17579,"Marshal's Dreadweave Leggings",4,256}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,23047,"Reduces the casting time of your Immolate spell by 0.2 sec."},{6,14047,"Increases damage and healing done by magical spells and effects by up to 23."}}}
C[393]={name="Warlord's Vestments",classMask=8,items={{16564,"General's Leather Legguards",4,8},{16560,"General's Leather Mitts",4,8},{16558,"General's Leather Treads",4,8},{16563,"Warlord's Leather Breastplate",4,8},{16561,"Warlord's Leather Helm",4,8},{16562,"Warlord's Leather Spaulders",4,8}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,23048,"Reduces the cooldown of your Gouge ability by -1 sec."},{6,14049,"+40 Attack Power."}}}
C[394]={name="Field Marshal's Vestments",classMask=8,items={{16453,"Field Marshal's Leather Chestpiece",4,8},{16457,"Field Marshal's Leather Epaulets",4,8},{16455,"Field Marshal's Leather Mask",4,8},{16446,"Marshal's Leather Footguards",4,8},{16454,"Marshal's Leather Handgrips",4,8},{16456,"Marshal's Leather Leggings",4,8}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,23048,"Reduces the cooldown of your Gouge ability by -1 sec."},{6,14049,"+40 Attack Power."}}}
C[395]={name="Field Marshal's Pursuit",classMask=4,items={{16466,"Field Marshal's Chain Breastplate",4,4},{16465,"Field Marshal's Chain Helm",4,4},{16468,"Field Marshal's Chain Spaulders",4,4},{16462,"Marshal's Chain Boots",4,4},{16463,"Marshal's Chain Grips",4,4},{16467,"Marshal's Chain Legguards",4,4}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,23158,"Reduces the cooldown of Concussive Shot by -1 sec and Wing Clip by 0 sec."},{6,14384,"+20 Agility."}}}
C[396]={name="Warlord's Pursuit",classMask=4,items={{16569,"General's Chain Boots",4,4},{16571,"General's Chain Gloves",4,4},{16567,"General's Chain Legguards",4,4},{16565,"Warlord's Chain Chestpiece",4,4},{16566,"Warlord's Chain Helmet",4,4},{16568,"Warlord's Chain Shoulders",4,4}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,23158,"Reduces the cooldown of Concussive Shot by -1 sec and Wing Clip by 0 sec."},{6,14384,"+20 Agility."}}}
C[397]={name="Field Marshal's Sanctuary",classMask=1024,items={{16452,"Field Marshal's Dragonhide Breastplate",4,1024},{16451,"Field Marshal's Dragonhide Helmet",4,1024},{16449,"Field Marshal's Dragonhide Spaulders",4,1024},{16459,"Marshal's Dragonhide Boots",4,1024},{16448,"Marshal's Dragonhide Gauntlets",4,1024},{16450,"Marshal's Dragonhide Legguards",4,1024}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14049,"+40 Attack Power."}}}
C[398]={name="Warlord's Sanctuary",classMask=1024,items={{16554,"General's Dragonhide Boots",4,1024},{16555,"General's Dragonhide Gloves",4,1024},{16552,"General's Dragonhide Leggings",4,1024},{16551,"Warlord's Dragonhide Epaulets",4,1024},{16549,"Warlord's Dragonhide Hauberk",4,1024},{16550,"Warlord's Dragonhide Helmet",4,1024}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14049,"+40 Attack Power."}}}
C[401]={name="Lieutenant Commander's Aegis",classMask=2,items={{16433,"Knight-Captain's Lamellar Breastplate",3,2},{16435,"Knight-Captain's Lamellar Leggings",3,2},{16410,"Knight-Lieutenant's Lamellar Gauntlets",3,2},{16409,"Knight-Lieutenant's Lamellar Sabatons",3,2},{16434,"Lieutenant Commander's Lamellar Headguard",3,2},{16436,"Lieutenant Commander's Lamellar Shoulders",3,2}},bonuses={{2,7496,"+6 Intellect."},{2,28118,"Improves your chance to get a critical strike by 1%."},{4,23302,"Reduces the cooldown of your Hammer of Justice by -10 sec."},{6,14462,"+15 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[402]={name="Field Marshal's Aegis",classMask=2,items={{16473,"Field Marshal's Lamellar Chestplate",4,2},{16474,"Field Marshal's Lamellar Faceguard",4,2},{16476,"Field Marshal's Lamellar Pauldrons",4,2},{16472,"Marshal's Lamellar Boots",4,2},{16471,"Marshal's Lamellar Gloves",4,2},{16475,"Marshal's Lamellar Legplates",4,2}},bonuses={{2,14467,"+20 Stamina."},{3,23302,"Reduces the cooldown of your Hammer of Justice by -10 sec."},{6,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[421]={name="Bloodvine Garb",classMask=0,items={{19684,"Bloodvine Boots",3,-1},{19683,"Bloodvine Leggings",3,-1},{19682,"Bloodvine Vest",3,-1}},bonuses={{3,45501,"Your damaging spells have a chance to inflict the target with a disease, dealing Shadow damage over 6 sec. Damage caused by the disease heals you."}}}
C[441]={name="Primal Batskin",classMask=0,items={{19687,"Primal Batskin Bracers",3,-1},{19686,"Primal Batskin Gloves",3,-1},{19685,"Primal Batskin Jerkin",3,-1}},bonuses={{3,24090,"Minor increase to running and swimming speed."}}}
C[442]={name="Blood Tiger Harness",classMask=0,items={{19688,"Blood Tiger Breastplate",3,-1},{19689,"Blood Tiger Shoulders",3,-1}},bonuses={{2,45498,"Gives a chance when your melee attacks, harmful spells or abilities land to steal 80 life from the target enemy."}}}
C[443]={name="Bloodsoul Embrace",classMask=0,items={{19690,"Bloodsoul Breastplate",3,-1},{19692,"Bloodsoul Gauntlets",3,-1},{19691,"Bloodsoul Shoulders",3,-1}},bonuses={{3,21636,"Restores 12 mana per 5 sec."}}}
C[444]={name="The Darksoul",classMask=0,items={{19693,"Darksoul Breastplate",3,-1},{19694,"Darksoul Leggings",3,-1},{19695,"Darksoul Shoulders",3,-1}},bonuses={{3,21416,"Increased Defense +20."}}}
C[461]={name="The Twin Blades of Hakkari",classMask=0,items={{19865,"Warblade of the Hakkari",4,-1},{19866,"Warblade of the Hakkari",4,-1}},bonuses={{2,15763,"Increased Swords +6."}}}
C[462]={name="Zanzil's Concentration",classMask=0,items={{19905,"Zanzil's Band",3,-1},{19893,"Zanzil's Seal",3,-1}},bonuses={{2,9396,"Increases damage and healing done by magical spells and effects by up to 6."},{2,23727,"Improves your chance to hit with spells by 1%."}}}
C[463]={name="Primal Blessing",classMask=0,items={{19910,"Arlokk's Grasp",4,-1},{19896,"Thekal's Grasp",4,-1}},bonuses={{2,24256,"Grants a small chance when ranged or melee damage is dealt to infuse the wielder with a blessing from the Primal Gods. Ranged and melee attack power increased by 300 for 12 seconds."}}}
C[464]={name="Overlord's Resolution",classMask=0,items={{19873,"Overlord's Crimson Band",3,-1},{19912,"Overlord's Onyx Band",3,-1}},bonuses={{2,13669,"Increases your chance to dodge an attack by 1%."}}}
C[465]={name="Prayer of the Primal",classMask=0,items={{19920,"Primalist's Band",3,-1},{19863,"Primalist's Seal",3,-1}},bonuses={{2,9318,"Increases healing done by spells and effects by up to 33."}}}
C[466]={name="Major Mojo Infusion",classMask=0,items={{19925,"Band of Jin",3,-1},{19898,"Seal of Jin",3,-1}},bonuses={{2,9336,"+30 Attack Power."}}}
C[467]={name="The Highlander's Resolution",classMask=3,items={{20041,"Highlander's Plate Girdle",3,3},{20048,"Highlander's Plate Greaves",3,3},{20057,"Highlander's Plate Spaulders",4,3}},bonuses={{2,7503,"+5 Stamina."},{3,7597,"Improves your chance to get a critical strike by 1%."},{3,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[468]={name="The Highlander's Resolve",classMask=2,items={{20042,"Highlander's Lamellar Girdle",3,2},{20049,"Highlander's Lamellar Greaves",3,2},{20058,"Highlander's Lamellar Spaulders",4,2}},bonuses={{2,7503,"+5 Stamina."},{3,7597,"Improves your chance to get a critical strike by 1%."},{3,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[469]={name="The Highlander's Determination",classMask=4,items={{20043,"Highlander's Chain Girdle",3,4},{20050,"Highlander's Chain Greaves",3,4},{20055,"Highlander's Chain Pauldrons",4,4}},bonuses={{2,7503,"+5 Stamina."},{3,7597,"Improves your chance to get a critical strike by 1%."},{3,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[470]={name="The Highlander's Fortitude",classMask=4,items={{20044,"Highlander's Mail Girdle",3,4},{20051,"Highlander's Mail Greaves",3,4},{20056,"Highlander's Mail Pauldrons",4,4}},bonuses={{2,7503,"+5 Stamina."},{3,18384,"Improves your chance to get a critical strike with spells by 1%."},{3,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[471]={name="The Highlander's Purpose",classMask=1032,items={{20052,"Highlander's Leather Boots",3,1032},{20045,"Highlander's Leather Girdle",3,1032},{20059,"Highlander's Leather Shoulders",4,1032}},bonuses={{2,7503,"+5 Stamina."},{3,7597,"Improves your chance to get a critical strike by 1%."},{3,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[472]={name="The Highlander's Will",classMask=1032,items={{20053,"Highlander's Lizardhide Boots",3,1032},{20046,"Highlander's Lizardhide Girdle",3,1032},{20060,"Highlander's Lizardhide Shoulders",4,1032}},bonuses={{2,7503,"+5 Stamina."},{3,18384,"Improves your chance to get a critical strike with spells by 1%."},{3,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[473]={name="The Highlander's Intent",classMask=400,items={{20054,"Highlander's Cloth Boots",3,400},{20047,"Highlander's Cloth Girdle",3,400},{20061,"Highlander's Epaulets",4,400}},bonuses={{2,7503,"+5 Stamina."},{3,18384,"Improves your chance to get a critical strike with spells by 1%."},{3,18384,"Improves your chance to get a critical strike with spells by 1%."}}}
C[474]={name="Vindicator's Battlegear",classMask=1,items={{19577,"Rage of Mugamba",4,1},{19824,"Zandalar Vindicator's Armguards",4,1},{19823,"Zandalar Vindicator's Belt",4,1},{19822,"Zandalar Vindicator's Breastplate",4,1},{19951,"Gri'lek's Charm of Might",4,1}},bonuses={{2,13675,"Increases your chance to block attacks with a shield by 2%."},{3,24456,"Decreases the cooldown of Intimidating Shout by -15 sec."},{5,24431,"Decrease the rage cost of Whirlwind by -3."}}}
C[475]={name="Freethinker's Armor",classMask=2,items={{19588,"Hero's Brand",4,2},{19827,"Zandalar Freethinker's Armguards",4,2},{19826,"Zandalar Freethinker's Belt",4,2},{19825,"Zandalar Freethinker's Breastplate",4,2},{19952,"Gri'lek's Charm of Valor",4,2}},bonuses={{2,21618,"Restores 4 mana per 5 sec."},{3,23591,"Inflicts 60 to 66 additional Holy damage on the target of a Paladin's Judgement."},{5,24460,"Increases the duration of all Blessings by 10%."}}}
C[476]={name="Augur's Regalia",classMask=64,items={{19609,"Unmarred Vision of Voodress",4,64},{19829,"Zandalar Augur's Belt",4,64},{19830,"Zandalar Augur's Bracers",4,64},{19828,"Zandalar Augur's Hauberk",4,64},{19956,"Wushoolay's Charm of Spirits",4,64}},bonuses={{2,21618,"Restores 4 mana per 5 sec."},{3,24461,"Improves the duration of your Frost Shock spell by 1 sec."},{5,24462,"Increase the range of your Lightning Bolt spell by 5 yds."}}}
C[477]={name="Predator's Armor",classMask=4,items={{19621,"Maelstrom's Wrath",4,4},{19832,"Zandalar Predator's Belt",4,4},{19833,"Zandalar Predator's Bracers",4,4},{19831,"Zandalar Predator's Mantle",4,4},{19953,"Renataki's Charm of Beasts",4,4}},bonuses={{2,9331,"+20 Attack Power."},{3,24465,"Decreases the cooldown of Concussive Shot and Wing Clip by -1 sec."},{5,24467,"Reduces the time between periodic ticks and duration of Serpent Sting by -20%."}}}
C[478]={name="Madcap's Outfit",classMask=8,items={{19836,"Zandalar Madcap's Bracers",4,8},{19835,"Zandalar Madcap's Mantle",4,8},{19834,"Zandalar Madcap's Tunic",4,8},{19617,"Zandalarian Shadow Mastery Talisman",4,8},{19954,"Renataki's Charm of Trickery",4,8}},bonuses={{2,9331,"+20 Attack Power."},{3,24469,"Decreases the cooldown of Blind by -20 sec."},{5,24471,"Decrease the energy cost of Eviscerate and Rupture by -5."}}}
C[479]={name="Haruspex's Garb",classMask=1024,items={{19613,"Pristine Enchanted South Seas Kelp",4,1024},{19839,"Zandalar Haruspex's Belt",4,1024},{19840,"Zandalar Haruspex's Bracers",4,1024},{19838,"Zandalar Haruspex's Tunic",4,1024},{19955,"Wushoolay's Charm of Nature",4,1024}},bonuses={{2,21618,"Restores 4 mana per 5 sec."},{3,24479,"Increases the duration of Faerie Fire by 5 sec."},{5,24480,"Increases the critical hit chance of your Starfire spell 3%."}}}
C[480]={name="Confessor's Raiment",classMask=16,items={{19594,"The All-Seeing Eye of Zuldazar",4,16},{19842,"Zandalar Confessor's Bindings",4,16},{19841,"Zandalar Confessor's Mantle",4,16},{19843,"Zandalar Confessor's Wraps",4,16},{19958,"Hazza'rah's Charm of Healing",4,16}},bonuses={{2,9408,"Increases healing done by spells and effects by up to 22."},{3,24482,"Increase the range of your Smite and Holy Fire spells by 5 yds."},{5,24483,"Reduces the casting time of your Mind Control spell by 0 sec."}}}
C[481]={name="Demoniac's Threads",classMask=256,items={{19605,"Kezan's Unstoppable Taint",4,256},{19849,"Zandalar Demoniac's Mantle",4,256},{20033,"Zandalar Demoniac's Robe",4,256},{19848,"Zandalar Demoniac's Wraps",4,256},{19957,"Hazza'rah's Charm of Destruction",4,256}},bonuses={{2,9417,"Increases damage and healing done by magical spells and effects by up to 12."},{3,24486,"Corruption now deals an amount of damage equal to 1.5 sec. of Corruption upon application."},{5,24487,"Decreases the cooldown of Soul Fire and Death Coil by -15%."}}}
C[482]={name="Illusionist's Attire",classMask=128,items={{19601,"Jewel of Kajaro",4,128},{19845,"Zandalar Illusionist's Mantle",4,128},{20034,"Zandalar Illusionist's Robe",4,128},{19846,"Zandalar Illusionist's Wraps",4,128},{19959,"Hazza'rah's Charm of Magic",4,128}},bonuses={{2,9417,"Increases damage and healing done by magical spells and effects by up to 12."},{3,24489,"Decreases the mana cost of Arcane Intellect and Arcane Brilliance by -5%."},{5,24491,"Reduces the casting time of your Flamestrike spell by 0 sec."}}}
C[483]={name="The Defiler's Determination",classMask=68,items={{20150,"Defiler's Chain Girdle",3,68},{20154,"Defiler's Chain Greaves",3,68},{20158,"Defiler's Chain Pauldrons",4,68}},bonuses={{2,7503,"+5 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{3,7597,"Improves your chance to get a critical strike by 1%."}}}
C[484]={name="The Defiler's Fortitude",classMask=64,items={{20195,"Defiler's Mail Girdle",3,64},{20199,"Defiler's Mail Greaves",3,64},{20203,"Defiler's Mail Pauldrons",4,64}},bonuses={{2,7503,"+5 Stamina."},{3,18384,"Improves your chance to get a critical strike with spells by 1%."},{3,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[485]={name="The Defiler's Intent",classMask=400,items={{20159,"Defiler's Cloth Boots",3,400},{20163,"Defiler's Cloth Girdle",3,400},{20176,"Defiler's Epaulets",4,400}},bonuses={{2,7503,"+5 Stamina."},{3,18384,"Improves your chance to get a critical strike with spells by 1%."},{3,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[486]={name="The Defiler's Purpose",classMask=1032,items={{20186,"Defiler's Leather Boots",3,1032},{20190,"Defiler's Leather Girdle",3,1032},{20194,"Defiler's Leather Shoulders",4,1032}},bonuses={{2,7503,"+5 Stamina."},{3,7597,"Improves your chance to get a critical strike by 1%."},{3,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[487]={name="The Defiler's Resolution",classMask=1,items={{20204,"Defiler's Plate Girdle",3,1},{20208,"Defiler's Plate Greaves",3,1},{20212,"Defiler's Plate Spaulders",4,1}},bonuses={{2,7503,"+5 Stamina."},{3,7597,"Improves your chance to get a critical strike by 1%."},{3,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[488]={name="The Defiler's Will",classMask=1032,items={{20167,"Defiler's Lizardhide Boots",3,1032},{20171,"Defiler's Lizardhide Girdle",3,1032},{20175,"Defiler's Lizardhide Shoulders",4,1032}},bonuses={{2,7503,"+5 Stamina."},{3,18384,"Improves your chance to get a critical strike with spells by 1%."},{3,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[489]={name="Black Dragon Mail",classMask=0,items={{15050,"Black Dragonscale Breastplate",3,-1},{15051,"Black Dragonscale Shoulders",3,-1},{15052,"Black Dragonscale Leggings",3,-1},{16984,"Black Dragonscale Boots",4,-1}},bonuses={{2,15464,"Improves your chance to hit by 1%."},{3,7598,"Improves your chance to get a critical strike by 2%."},{4,14598,"+18 Fire Resistance."}}}
C[490]={name="Green Dragon Mail",classMask=0,items={{15045,"Green Dragonscale Breastplate",3,-1},{15046,"Green Dragonscale Leggings",3,-1},{20296,"Green Dragonscale Gauntlets",3,-1}},bonuses={{2,21625,"Restores 3 mana per 5 sec."},{3,21894,"Allows 15% of your Mana regeneration to continue while casting."}}}
C[491]={name="Blue Dragon Mail",classMask=0,items={{15048,"Blue Dragonscale Breastplate",3,-1},{65015,"Blue Dragonscale Boots",3,-1},{15049,"Blue Dragonscale Shoulders",3,-1},{20295,"Blue Dragonscale Leggings",3,-1}},bonuses={{2,18675,"+4 All Resistances."},{3,14127,"Increases damage and healing done by magical spells and effects by up to 28."},{4,45543,"Chance on landing a damaging spell to deal 75-85 Arcane damage and increase the target's Arcane damage taken by 10 for 15 sec. This stacks up to 3 times."}}}
C[492]={name="Twilight Trappings",classMask=32767,items={{20408,"Twilight Cultist Cowl",2,32767},{20406,"Twilight Cultist Mantle",2,32767},{20407,"Twilight Cultist Robe",2,32767}},bonuses={{3,24746,"Bestows the wearer with the evil aura of a Twilight's Hammer cultist."}}}
C[493]={name="Genesis Regalia",classMask=1024,items={{21353,"Genesis Circlet",4,1024},{21354,"Genesis Mantle",4,1024},{21355,"Genesis Slippers",4,1024},{21356,"Genesis Trousers",4,1024},{21357,"Genesis Vest",4,1024}},bonuses={{3,18056,"Increases damage and healing done by magical spells and effects by up to 40."},{5,26106,"Reduces the cooldown of Rebirth by -10 minutes."}}}
C[494]={name="Symbols of Unending Life",classMask=1024,items={{21408,"Band of Unending Life",4,1024},{21409,"Cloak of Unending Life",4,1024},{21407,"Mace of Unending Life",4,1024}},bonuses={{2,26107,"Your finishing moves now refund 30 energy on a Miss, Dodge, Block, or Parry."},{3,52693,"Your Swipe hits 1 additional target."},{3,52697,"Your finishing moves have a chance per combo point to restore 35 Energy."}}}
C[495]={name="Battlegear of Unyielding Strength",classMask=1,items={{21394,"Drape of Unyielding Strength",4,1},{21392,"Sickle of Unyielding Strength",4,1},{21393,"Signet of Unyielding Strength",4,1}},bonuses={{2,26111,"--2 rage cost to Intercept and Intervene."},{3,52686,"You gain 5 Rage when your Heroic Strike or Slam is dodged or parried."}}}
C[496]={name="Conqueror's Battlegear",classMask=1,items={{21331,"Conqueror's Breastplate",4,1},{21329,"Conqueror's Crown",4,1},{21333,"Conqueror's Greaves",4,1},{21332,"Conqueror's Legguards",4,1},{21330,"Conqueror's Spaulders",4,1}},bonuses={{3,26109,"Decreases the rage cost of all Warrior shouts by -35%."},{5,26110,"Increase the Slow effect and damage of Thunder Clap by 50%."}}}
C[497]={name="Deathdealer's Embrace",classMask=8,items={{21359,"Deathdealer's Boots",4,8},{21360,"Deathdealer's Helm",4,8},{21362,"Deathdealer's Leggings",4,8},{21361,"Deathdealer's Spaulders",4,8},{21364,"Deathdealer's Vest",4,8},{279593,"Deathdealer's Vest",4,8}},bonuses={{3,26112,"Reduces the cooldown of your Evasion ability by --1 min."},{5,26113,"15% increased damage to your Eviscerate ability."}}}
C[498]={name="Emblems of Veiled Shadows",classMask=8,items={{21405,"Band of Veiled Shadows",4,8},{21406,"Cloak of Veiled Shadows",4,8},{21404,"Dagger of Veiled Shadows",4,8}},bonuses={{2,26114,"--10 energy cost for your Slice and Dice ability."},{3,52688,"On successful poison application, you have a 25% chance to deal 80 Nature damage."}}}
C[499]={name="Doomcaller's Raiment",classMask=256,items={{21337,"Doomcaller's Circlet",4,256},{21338,"Doomcaller's Footwraps",4,256},{21335,"Doomcaller's Mantle",4,256},{21336,"Doomcaller's Trousers",4,256},{21334,"Doomcaller's Robes",4,256}},bonuses={{3,26116,"5% increased damage on your Immolate spell."},{5,26117,"Reduces the mana cost of Shadow Bolt and Searing Pain by -15%."}}}
C[500]={name="Implements of Unspoken Names",classMask=256,items={{21416,"Kris of Unspoken Names",4,256},{21417,"Ring of Unspoken Names",4,256},{21418,"Shroud of Unspoken Names",4,256}},bonuses={{2,26118,"5% increased damage from your summoned pets' melee attacks and damage spells."},{3,52681,"Reduces the casting time of your Immolate spell by 0 sec."},{3,52682,"Conflagrate deals an amount of damage equal to 3 sec. of your Immolate spell without consuming its duration."}}}
C[501]={name="Stormcaller's Garb",classMask=64,items={{21372,"Stormcaller's Diadem",4,64},{21376,"Stormcaller's Epaulets",4,64},{21373,"Stormcaller's Greaves",4,64},{21374,"Stormcaller's Hauberk",4,64},{21375,"Stormcaller's Legplates",4,64}},bonuses={{3,26119,"Your Lightning Bolt, Chain Lightning, and Shock spells have a 20% chance to grant up to 50 Nature damage to spells for 8 sec."},{5,51884,"Your Chain Lightning is imbued with unpredictable storm energies, it now chains to an additional target and deals 15% increased damage if it hits only one target."}}}
C[502]={name="Gift of the Gathering Storm",classMask=64,items={{21400,"Cloak of the Gathering Storm",4,64},{21398,"Hammer of the Gathering Storm",4,64},{21399,"Ring of the Gathering Storm",4,64}},bonuses={{2,26123,"Increases the chain target damage multiplier of your Chain Lightning spell by 5%."},{3,52701,"Purge increases your casting speed by 5% for 6 sec or until you cast a spell when it successfully removes a magic effect."}}}
C[503]={name="Enigma Regalia",classMask=128,items={{21344,"Enigma Boots",4,128},{21347,"Enigma Circlet",4,128},{21346,"Enigma Leggings",4,128},{21345,"Enigma Shoulderpads",4,128},{21343,"Enigma Robes",4,128}},bonuses={{3,26127,"Your Blizzard spell has a 30% chance to be uninterruptible."},{5,26128,"Grants +5% increased spell hit chance for 20 sec when one of your spells is resisted."}}}
C[504]={name="Trappings of Vaulted Secrets",classMask=128,items={{21414,"Band of Vaulted Secrets",4,128},{21413,"Blade of Vaulted Secrets",4,128},{21415,"Drape of Vaulted Secrets",4,128}},bonuses={{2,26131,"15% increase to the total damage absorbed by Mana Shield."},{3,52690,"Using a Mana Gem increases your damage and healing from magical spells and effects by up to 60 for 10 sec."}}}
C[505]={name="Avenger's Battlegear",classMask=2,items={{21389,"Avenger's Chestplate",4,2},{21387,"Avenger's Crown",4,2},{21390,"Avenger's Leggings",4,2},{21391,"Avenger's Pauldrons",4,2},{21388,"Avenger's Sabatons",4,2}},bonuses={{3,51818,"Increases the damage of Judgement of Righteousness and Judgement of Command by 15%."},{5,28264,"Increases damage and healing done by magical spells and effects by up to 46."}}}
C[506]={name="Battlegear of Eternal Justice",classMask=2,items={{21395,"Blade of Eternal Justice",4,2},{21397,"Cape of Eternal Justice",4,2},{21396,"Ring of Eternal Justice",4,2}},bonuses={{2,26135,"20% chance to regain 100 mana when you cast a Judgement."},{3,52698,"Reduces the casting time of your Hammer of Wrath by -100%."}}}
C[507]={name="Regalia of the Oracle",classMask=16,items={{21348,"Coronet of the Oracle",4,16},{21349,"Footwraps of the Oracle",4,16},{21350,"Mantle of the Oracle",4,16},{21352,"Pants of the Oracle",4,16},{21351,"Raiments of the Oracle",4,16}},bonuses={{3,51789,"Increases the duration of your Chastise spell by 2 sec."},{5,51796,"Your Chastise increases damage and healing done by magical spells and effects by up to 40, and reduces the mana cost of Smite and Holy Fire by -15% for 12 sec. Grants stacks when Chastise critically strikes."}}}
C[508]={name="Finery of Infinite Wisdom",classMask=16,items={{21410,"Gavel of Infinite Wisdom",4,16},{21411,"Ring of Infinite Wisdom",4,16},{21412,"Shroud of Infinite Wisdom",4,16}},bonuses={{2,26172,"Increases the damage of your Shadow Word: Pain spell by 5%."},{3,52699,"Increases Pain Spike damage by 20% and heals you for 40% of its damage."}}}
C[509]={name="Striker's Garb",classMask=4,items={{21366,"Striker's Diadem",4,4},{21365,"Striker's Footguards",4,4},{21370,"Striker's Hauberk",4,4},{21368,"Striker's Leggings",4,4},{21367,"Striker's Pauldrons",4,4}},bonuses={{3,26173,"Your Serpent Sting damage has a chance to deal 100 Nature damage and restore 40 Mana."},{5,26174,"Reduces the cooldown of your Rapid Fire ability by -2 minutes."}}}
C[510]={name="Trappings of the Unseen Path",classMask=4,items={{21403,"Cloak of the Unseen Path",4,4},{21401,"Scythe of the Unseen Path",4,4},{21402,"Signet of the Unseen Path",4,4}},bonuses={{2,26176,"Increases your pet's damage by 3%."},{3,52684,"Increases the critical strike chance of Steady Shot, Raptor Strike and Mongoose Bite by 2%."},{3,52685,"Increases pet Focus regeneration by 2."}}}
C[511]={name="Battlegear of Heroism",classMask=0,items={{21994,"Belt of Heroism",4,-1},{21995,"Boots of Heroism",4,-1},{21996,"Bracers of Heroism",4,-1},{21997,"Breastplate of Heroism",4,-1},{21998,"Gauntlets of Heroism",4,-1},{21999,"Helm of Heroism",4,-1},{22000,"Legplates of Heroism",4,-1},{22001,"Spaulders of Heroism",4,-1}},bonuses={{2,18679,"+8 All Resistances."},{4,27419,"Chance on melee attack to heal you for 88 to 132 and increase your rage by 10."},{6,14049,"+40 Attack Power."},{8,14803,"+200 Armor."}}}
C[512]={name="Darkmantle Armor",classMask=0,items={{22002,"Darkmantle Belt",4,-1},{22003,"Darkmantle Boots",4,-1},{22004,"Darkmantle Bracers",4,-1},{22005,"Darkmantle Cap",4,-1},{22006,"Darkmantle Gloves",4,-1},{22007,"Darkmantle Pants",4,-1},{22008,"Darkmantle Spaulders",4,-1},{22009,"Darkmantle Tunic",4,-1}},bonuses={{2,18679,"+8 All Resistances."},{4,27787,"Chance on melee attack to restore 35 energy."},{6,14049,"+40 Attack Power."},{8,14803,"+200 Armor."}}}
C[513]={name="Moonheart Raiment",classMask=0,items={{22106,"Moonheart Belt",4,-1},{281044,"Moonheart Belt",4,-1},{22107,"Moonheart Boots",4,-1},{22108,"Moonheart Bracers",4,-1},{22109,"Moonheart Cowl",4,-1},{22110,"Moonheart Gloves",4,-1},{22111,"Moonheart Kilt",4,-1},{22112,"Moonheart Spaulders",4,-1},{22113,"Moonheart Vest",4,-1}},bonuses={{2,18679,"+8 All Resistances."},{4,27781,"When struck in combat has a chance of returning 300 mana, 10 rage, or 40 energy to the wearer."},{6,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{8,14803,"+200 Armor."}}}
C[514]={name="Vestments of the Virtuous",classMask=0,items={{22078,"Virtuous Belt",4,-1},{22079,"Virtuous Bracers",4,-1},{22080,"Virtuous Crown",4,-1},{22081,"Virtuous Gloves",4,-1},{22082,"Virtuous Mantle",4,-1},{22083,"Virtuous Robe",4,-1},{22084,"Virtuous Sandals",4,-1},{22085,"Virtuous Skirt",4,-1}},bonuses={{2,18679,"+8 All Resistances."},{4,27778,"When struck in combat has a chance of shielding the wearer in a protective shield which will absorb 350 damage."},{6,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{8,14803,"+200 Armor."}}}
C[515]={name="Beastmaster Armor",classMask=0,items={{22010,"Beastmaster's Belt",4,-1},{22011,"Beastmaster's Bindings",4,-1},{22061,"Beastmaster's Boots",4,-1},{22013,"Beastmaster's Cap",4,-1},{22015,"Beastmaster's Gloves",4,-1},{22016,"Beastmaster's Mantle",4,-1},{22017,"Beastmaster's Pants",4,-1},{22060,"Beastmaster's Tunic",4,-1}},bonuses={{2,18679,"+8 All Resistances."},{4,27785,"Your normal melee and ranged attacks have a 4% chance of restoring 200 mana."},{6,14049,"+40 Attack Power."},{8,14803,"+200 Armor."}}}
C[516]={name="Soulforge Armor",classMask=0,items={{22086,"Soulforge Belt",4,-1},{22087,"Soulforge Boots",4,-1},{22088,"Soulforge Bracers",4,-1},{22089,"Soulforge Breastplate",4,-1},{22090,"Soulforge Gauntlets",4,-1},{22091,"Soulforge Helm",4,-1},{22092,"Soulforge Legplates",4,-1},{22093,"Soulforge Spaulders",4,-1}},bonuses={{2,18679,"+8 All Resistances."},{4,27498,"Chance on melee attack to increase your damage and healing done by magical spells and effects by up to 95 for 10 sec."},{6,14049,"+40 Attack Power."},{8,14803,"+200 Armor."}}}
C[517]={name="Sorcerer's Regalia",classMask=0,items={{22062,"Sorcerer's Belt",4,-1},{22063,"Sorcerer's Bindings",4,-1},{22064,"Sorcerer's Boots",4,-1},{22065,"Sorcerer's Crown",4,-1},{22066,"Sorcerer's Gloves",4,-1},{22067,"Sorcerer's Leggings",4,-1},{22068,"Sorcerer's Mantle",4,-1},{22069,"Sorcerer's Robes",4,-1}},bonuses={{2,18679,"+8 All Resistances."},{4,27867,"When struck in combat has a chance of freezing the attacker in place for 3 sec."},{6,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{8,14803,"+200 Armor."}}}
C[518]={name="Deathmist Raiment",classMask=0,items={{22070,"Deathmist Belt",4,-1},{22071,"Deathmist Bracers",4,-1},{22072,"Deathmist Leggings",4,-1},{22073,"Deathmist Mantle",4,-1},{22074,"Deathmist Mask",4,-1},{22075,"Deathmist Robe",4,-1},{22076,"Deathmist Sandals",4,-1},{22077,"Deathmist Wraps",4,-1}},bonuses={{2,18679,"+8 All Resistances."},{4,27780,"When struck in combat has a chance of causing the attacker to flee in terror for 2 seconds."},{6,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{8,14803,"+200 Armor."}}}
C[519]={name="The Five Thunders",classMask=32767,items={{22095,"Bindings of The Five Thunders",4,32767},{22096,"Boots of The Five Thunders",4,32767},{22097,"Coif of The Five Thunders",4,32767},{22098,"Cord of The Five Thunders",4,32767},{22099,"Gauntlets of The Five Thunders",4,32767},{22100,"Kilt of The Five Thunders",4,32767},{22101,"Pauldrons of The Five Thunders",4,32767},{22102,"Vest of The Five Thunders",4,32767}},bonuses={{2,18679,"+8 All Resistances."},{4,27774,"Chance on spell cast to increase your damage and healing by up to 95 for 10 sec."},{6,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{8,14803,"+200 Armor."}}}
C[520]={name="Ironweave Battlesuit",classMask=1424,items={{22306,"Ironweave Belt",3,1424},{22311,"Ironweave Boots",3,1424},{22313,"Ironweave Bracers",3,1424},{22304,"Ironweave Gloves",3,1424},{22305,"Ironweave Mantle",3,1424},{22303,"Ironweave Pants",3,1424},{22302,"Ironweave Cowl",3,1424},{22301,"Ironweave Robe",3,1424}},bonuses={{2,27733,"Increases your chance to resist Silence and Interrupt effects by 10%."},{4,14462,"+15 Stamina."},{6,13669,"Increases your chance to dodge an attack by 1%."},{6,23727,"Improves your chance to hit with spells by 1%."},{8,15957,"+300 Armor."}}}
C[521]={name="Dreamwalker Raiment",classMask=1024,items={{22494,"Dreamwalker Belt",4,1024},{22492,"Dreamwalker Boots",4,1024},{22495,"Dreamwalker Bracers",4,1024},{22493,"Dreamwalker Handguards",4,1024},{22490,"Dreamwalker Headpiece",4,1024},{1891641,"Dreamwalker Headpiece",4,1024},{22489,"Dreamwalker Legguards",4,1024},{22491,"Dreamwalker Spaulders",4,1024},{22488,"Dreamwalker Tunic",4,1024},{23064,"Ring of The Dreamwalker",4,1024}},bonuses={{2,28716,"Your Rejuvenation ticks have a chance to restore 60 mana, 8 energy, or 2 rage to your target."},{4,28743,"Reduces the mana cost of your Healing Touch, Regrowth, Rejuvenation, and Tranquility spells by -3%."},{6,28744,"Your initial cast and Regrowth ticks will increase the maximum health of your target by up to 50, stacking up to 7 times."},{8,28719,"On Healing Touch critical hits, you regain 30% of the mana cost of the spell."}}}
C[522]={name="Champion's Guard",classMask=8,items={{22864,"Blood Guard's Leather Grips",3,8},{22856,"Blood Guard's Leather Walkers",3,8},{23257,"Champion's Leather Helm",3,8},{23258,"Champion's Leather Shoulders",3,8},{22879,"Legionnaire's Leather Chestpiece",3,8},{22880,"Legionnaire's Leather Legguards",3,8}},bonuses={{2,14049,"+40 Attack Power."},{4,23048,"Reduces the cooldown of your Gouge ability by -1 sec."},{6,14467,"+20 Stamina."}}}
C[523]={name="Dreadnaught's Battlegear",classMask=1,items={{22423,"Dreadnaught Bracers",4,1},{22416,"Dreadnaught Breastplate",4,1},{22421,"Dreadnaught Gauntlets",4,1},{22418,"Dreadnaught Helmet",4,1},{22417,"Dreadnaught Legplates",4,1},{22419,"Dreadnaught Pauldrons",4,1},{22420,"Dreadnaught Sabatons",4,1},{22422,"Dreadnaught Waistguard",4,1},{23059,"Ring of the Dreadnaught",4,1}},bonuses={{2,28844,"Increases the damage done by your Revenge ability by 75."},{4,28843,"Improves your chance to hit with Taunt and Challenging Shout by 5%."},{6,28842,"Improves your chance to hit with Sunder Armor, Heroic Strike, Revenge, and Shield Slam by 5%."},{8,28845,"When your health drops below 20%, for the next 5 seconds healing spells cast on you help you to Cheat Death, increasing healing done by up to 160."}}}
C[524]={name="Bonescythe Armor",classMask=8,items={{22483,"Bonescythe Bracers",4,8},{22476,"Bonescythe Breastplate",4,8},{22481,"Bonescythe Gauntlets",4,8},{22478,"Bonescythe Helmet",4,8},{22477,"Bonescythe Legplates",4,8},{22479,"Bonescythe Pauldrons",4,8},{22480,"Bonescythe Sabatons",4,8},{22482,"Bonescythe Waistguard",4,8},{23060,"Bonescythe Ring",4,8}},bonuses={{2,28816,"Your normal melee swings have a chance to Invigorate you, healing you for 90 to 110."},{4,28812,"Critical strikes from your Backstab, Sinister Strike, Noxious Assault, and Hemorrhage restore 5 Energy."},{6,28811,"Reduces the threat generated by your Backstab, Sinister Strike, Noxious Assault, Hemorrhage, and Eviscerate abilities."},{8,28814,"Your Eviscerate has a chance per combo point to reveal a flaw in your opponent's armor, granting a 100% critical hit chance for your next Backstab, Sinister Strike, Noxious Assault, or Hemorrhage."}}}
C[525]={name="Vestments of Faith",classMask=16,items={{22518,"Belt of Faith",4,16},{22519,"Bindings of Faith",4,16},{1634107,"Bindings of Faith",4,16},{22514,"Circlet of Faith",4,16},{22517,"Gloves of Faith",4,16},{22513,"Leggings of Faith",4,16},{22515,"Mantle of Faith",4,16},{22516,"Sandals of Faith",4,16},{23061,"Ring of Faith",4,16},{22512,"Robe of Faith",4,16}},bonuses={{2,28807,"Reduces the mana cost of your Renew spell by -12%."},{4,28809,"On Greater Heal critical hits, your target will gain Armor of Faith, absorbing up to 500 damage."},{6,28808,"Reduces the threat from your healing spells."},{8,28802,"Each spell you cast has a chance to trigger an Epiphany, increasing your mana regeneration by 24 for 30 sec."}}}
C[526]={name="Frostfire Regalia",classMask=128,items={{22502,"Frostfire Belt",4,128},{22503,"Frostfire Bindings",4,128},{22498,"Frostfire Circlet",4,128},{22501,"Frostfire Gloves",4,128},{22497,"Frostfire Leggings",4,128},{22500,"Frostfire Sandals",4,128},{22499,"Frostfire Shoulderpads",4,128},{23062,"Frostfire Ring",4,128},{22496,"Frostfire Robe",4,128}},bonuses={{2,28763,"Reduces cooldown on your Evocation by -1 minute."},{4,28764,"Gives your Mage Armor a chance when struck by a harmful spell to increase resistance against that school of magic by 35 for 30 sec."},{6,28771,"Your damage spells have a chance to cause your target to take up to 200 increased damage from subsequent spells."},{8,28761,"Your damage spells have a chance to displace you, causing the next spell cast to generate no threat."}}}
C[527]={name="The Earthshatterer",classMask=64,items={{22470,"Earthshatter Belt",4,64},{22468,"Earthshatter Boots",4,64},{22469,"Earthshatter Handguards",4,64},{22466,"Earthshatter Headpiece",4,64},{22465,"Earthshatter Legguards",4,64},{22467,"Earthshatter Spaulders",4,64},{22464,"Earthshatter Tunic",4,64},{22471,"Earthshatter Wristguards",4,64},{23065,"Ring of the Earthshatterer",4,64}},bonuses={{2,28818,"Reduces the mana cost of your totem spells by -12%."},{4,29171,"Increases the mana gained from your Mana Spring totems by 25%."},{6,28823,"Your Healing Wave and Lesser Healing Wave spells have a chance to imbue your target with Totemic Power."},{8,28821,"Your Water Shield spell also grants you 15 mana per 5 sec. while active."}}}
C[528]={name="Redemption Armor",classMask=2,items={{22431,"Redemption Belt",4,2},{22430,"Redemption Boots",4,2},{22424,"Redemption Bracers",4,2},{22426,"Redemption Gloves",4,2},{22428,"Redemption Helm",4,2},{1756154,"Redemption Helm",4,2},{22427,"Redemption Pants",4,2},{22429,"Redemption Spaulders",4,2},{22425,"Redemption Tunic",4,2},{23066,"Ring of Redemption",4,2}},bonuses={{2,51820,"Increases the amount healed by your Judgement of Light by 20 and Flash of Light by 60."},{4,28774,"Reduces cooldown on your Lay on Hands by -12 min."},{6,51821,"Your Flash of Light, Holy Light and Holy Shock spells have a chance to imbue your target with Holy Power."},{8,28787,"Your Cleanse spell also heals the target for 200."}}}
C[529]={name="Plagueheart Raiment",classMask=256,items={{22510,"Plagueheart Belt",4,256},{22511,"Plagueheart Bracers",4,256},{22506,"Plagueheart Circlet",4,256},{22509,"Plagueheart Gloves",4,256},{22505,"Plagueheart Pants",4,256},{22508,"Plagueheart Sandals",4,256},{22507,"Plagueheart Shoulderpads",4,256},{23063,"Plagueheart Ring",4,256},{22504,"Plagueheart Robe",4,256}},bonuses={{2,28831,"Grants your Shadow Bolts a chance to heal you for 270 to 330."},{4,28829,"Increases damage caused by your Corruption by 12%."},{6,28746,"Your spell critical hits generate -25% less threat. In addition, Corruption, Immolate, Curse of Agony, and Siphon Life generate -25% less threat."},{8,28830,"Reduces health cost of your Life Tap by -12%."}}}
C[530]={name="Cryptstalker Armor",classMask=4,items={{22440,"Cryptstalker Boots",4,4},{22442,"Cryptstalker Girdle",4,4},{22441,"Cryptstalker Handguards",4,4},{22438,"Cryptstalker Headpiece",4,4},{22437,"Cryptstalker Legguards",4,4},{22439,"Cryptstalker Spaulders",4,4},{22436,"Cryptstalker Tunic",4,4},{22443,"Cryptstalker Wristguards",4,4},{23067,"Ring of the Cryptstalker",4,4}},bonuses={{2,28755,"Increases the duration of your Rapid Fire by 4 secs."},{4,28756,"Increases Attack Power by 50 for both you and your pet."},{6,28752,"Your ranged and melee critical hits cause an Adrenaline Rush, granting you 50 mana."},{8,28751,"Reduces the mana cost of your Raptor Strike, Mongoose Bite, Carve, Multi-Shot, Aimed Shot and Steady Shot by -20."}}}
C[533]={name="Battlegear of Undead Slaying",classMask=1535,items={{23078,"Gauntlets of Undead Slaying",3,1535},{23090,"Bracers of Undead Slaying",3,1535},{23087,"Breastplate of Undead Slaying",3,1535}},bonuses={{3,29068,"Increases your damage against undead by 2%."}}}
C[534]={name="Undead Slayer's Armor",classMask=1535,items={{23081,"Handwraps of Undead Slaying",3,1535},{23089,"Tunic of Undead Slaying",3,1535},{23093,"Wristwraps of Undead Slaying",3,1535}},bonuses={{3,29068,"Increases your damage against undead by 2%."}}}
C[535]={name="Garb of the Undead Slayer",classMask=32767,items={{23082,"Handguards of Undead Slaying",3,32767},{23088,"Chestguard of Undead Slaying",3,32767},{23092,"Wristguards of Undead Slaying",3,32767}},bonuses={{3,29068,"Increases your damage against undead by 2%."}}}
C[536]={name="Regalia of Undead Cleansing",classMask=32767,items={{23084,"Gloves of Undead Cleansing",3,32767},{23091,"Bracers of Undead Cleansing",3,32767},{23085,"Robe of Undead Cleansing",3,32767}},bonuses={{3,29068,"Increases your damage against undead by 2%."}}}
C[537]={name="Champion's Battlearmor",classMask=1,items={{22868,"Blood Guard's Plate Gauntlets",3,1},{22858,"Blood Guard's Plate Greaves",3,1},{23244,"Champion's Plate Helm",3,1},{23243,"Champion's Plate Shoulders",3,1},{22872,"Legionnaire's Plate Hauberk",3,1},{22873,"Legionnaire's Plate Leggings",3,1}},bonuses={{2,14049,"+40 Attack Power."},{4,22738,"Reduces the cooldown of your Intercept and Intervene abilities by -5 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[538]={name="Champion's Stormcaller",classMask=64,items={{22857,"Blood Guard's Mail Greaves",3,64},{22867,"Blood Guard's Mail Vices",3,64},{23259,"Champion's Mail Headguard",3,64},{23260,"Champion's Mail Pauldrons",3,64},{22876,"Legionnaire's Mail Hauberk",3,64},{22887,"Legionnaire's Mail Legguards",3,64}},bonuses={{2,14049,"+40 Attack Power."},{4,22804,"Improves your chance to get a critical strike with all Shock spells by 2%."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[539]={name="Champion's Refuge",classMask=1024,items={{22863,"Blood Guard's Dragonhide Grips",3,1024},{22852,"Blood Guard's Dragonhide Treads",3,1024},{23253,"Champion's Dragonhide Headguard",3,1024},{23254,"Champion's Dragonhide Shoulders",3,1024},{22877,"Legionnaire's Dragonhide Chestpiece",3,1024},{22878,"Legionnaire's Dragonhide Leggings",3,1024}},bonuses={{2,14049,"+40 Attack Power."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[540]={name="Champion's Investiture",classMask=16,items={{22869,"Blood Guard's Satin Handwraps",3,16},{22859,"Blood Guard's Satin Walkers",3,16},{23261,"Champion's Satin Hood",3,16},{23262,"Champion's Satin Mantle",3,16},{22882,"Legionnaire's Satin Legguards",3,16},{22885,"Legionnaire's Satin Tunic",3,16}},bonuses={{2,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{4,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[541]={name="Champion's Dreadgear",classMask=256,items={{22865,"Blood Guard's Dreadweave Handwraps",3,256},{22855,"Blood Guard's Dreadweave Walkers",3,256},{23255,"Champion's Dreadweave Cowl",3,256},{23256,"Champion's Dreadweave Spaulders",3,256},{22881,"Legionnaire's Dreadweave Legguards",3,256},{22884,"Legionnaire's Dreadweave Tunic",3,256}},bonuses={{2,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{4,23047,"Reduces the casting time of your Immolate spell by 0.2 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[542]={name="Champion's Arcanum",classMask=128,items={{22870,"Blood Guard's Silk Handwraps",3,128},{22860,"Blood Guard's Silk Walkers",3,128},{23263,"Champion's Silk Cowl",3,128},{23264,"Champion's Silk Mantle",3,128},{22883,"Legionnaire's Silk Legguards",3,128},{22886,"Legionnaire's Silk Tunic",3,128}},bonuses={{2,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{4,23025,"Reduces the cooldown of your Blink spell by -2 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[543]={name="Champion's Pursuance",classMask=4,items={{22843,"Blood Guard's Chain Greaves",3,4},{22862,"Blood Guard's Chain Vices",3,4},{23251,"Champion's Chain Helm",3,4},{23252,"Champion's Chain Shoulders",3,4},{22874,"Legionnaire's Chain Hauberk",3,4},{22875,"Legionnaire's Chain Legguards",3,4}},bonuses={{2,14384,"+20 Agility."},{4,23158,"Reduces the cooldown of Concussive Shot by -1 sec and Wing Clip by 0 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[544]={name="Lieutenant Commander's Redoubt",classMask=2,items={{23272,"Knight-Captain's Lamellar Breastplate",3,2},{23273,"Knight-Captain's Lamellar Leggings",3,2},{23274,"Knight-Lieutenant's Lamellar Gauntlets",3,2},{23275,"Knight-Lieutenant's Lamellar Sabatons",3,2},{23276,"Lieutenant Commander's Lamellar Headguard",3,2},{23277,"Lieutenant Commander's Lamellar Shoulders",3,2}},bonuses={{2,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{4,23302,"Reduces the cooldown of your Hammer of Justice by -10 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[545]={name="Lieutenant Commander's Battlearmor",classMask=1,items={{23300,"Knight-Captain's Plate Hauberk",3,1},{23301,"Knight-Captain's Plate Leggings",3,1},{23286,"Knight-Lieutenant's Plate Gauntlets",3,1},{23287,"Knight-Lieutenant's Plate Greaves",3,1},{23314,"Lieutenant Commander's Plate Helm",3,1},{23315,"Lieutenant Commander's Plate Shoulders",3,1}},bonuses={{2,14049,"+40 Attack Power."},{4,22738,"Reduces the cooldown of your Intercept and Intervene abilities by -5 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[546]={name="Lieutenant Commander's Arcanum",classMask=128,items={{23304,"Knight-Captain's Silk Legguards",3,128},{23305,"Knight-Captain's Silk Tunic",3,128},{23290,"Knight-Lieutenant's Silk Handwraps",3,128},{23291,"Knight-Lieutenant's Silk Walkers",3,128},{23318,"Lieutenant Commander's Silk Cowl",3,128},{23319,"Lieutenant Commander's Silk Mantle",3,128}},bonuses={{2,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{4,23025,"Reduces the cooldown of your Blink spell by -2 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[547]={name="Lieutenant Commander's Dreadgear",classMask=256,items={{23296,"Knight-Captain's Dreadweave Legguards",3,256},{23297,"Knight-Captain's Dreadweave Tunic",3,256},{23282,"Knight-Lieutenant's Dreadweave Handwraps",3,256},{23283,"Knight-Lieutenant's Dreadweave Walkers",3,256},{23310,"Lieutenant Commander's Dreadweave Cowl",3,256},{23311,"Lieutenant Commander's Dreadweave Spaulders",3,256}},bonuses={{2,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{4,23047,"Reduces the casting time of your Immolate spell by 0.2 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[548]={name="Lieutenant Commander's Guard",classMask=8,items={{23298,"Knight-Captain's Leather Chestpiece",3,8},{23299,"Knight-Captain's Leather Legguards",3,8},{23284,"Knight-Lieutenant's Leather Grips",3,8},{23285,"Knight-Lieutenant's Leather Walkers",3,8},{23312,"Lieutenant Commander's Leather Helm",3,8},{23313,"Lieutenant Commander's Leather Shoulders",3,8}},bonuses={{2,14049,"+40 Attack Power."},{4,23048,"Reduces the cooldown of your Gouge ability by -1 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[549]={name="Lieutenant Commander's Investiture",classMask=16,items={{23302,"Knight-Captain's Satin Legguards",3,16},{23303,"Knight-Captain's Satin Tunic",3,16},{23288,"Knight-Lieutenant's Satin Handwraps",3,16},{23289,"Knight-Lieutenant's Satin Walkers",3,16},{23316,"Lieutenant Commander's Satin Hood",3,16},{23317,"Lieutenant Commander's Satin Mantle",3,16}},bonuses={{2,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{4,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[550]={name="Lieutenant Commander's Pursuance",classMask=4,items={{23292,"Knight-Captain's Chain Hauberk",3,4},{23293,"Knight-Captain's Chain Legguards",3,4},{23278,"Knight-Lieutenant's Chain Greaves",3,4},{23279,"Knight-Lieutenant's Chain Vices",3,4},{23306,"Lieutenant Commander's Chain Helm",3,4},{23307,"Lieutenant Commander's Chain Shoulders",3,4}},bonuses={{2,14384,"+20 Agility."},{4,23158,"Reduces the cooldown of Concussive Shot by -1 sec and Wing Clip by 0 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[551]={name="Lieutenant Commander's Refuge",classMask=1024,items={{23294,"Knight-Captain's Dragonhide Chestpiece",3,1024},{23295,"Knight-Captain's Dragonhide Leggings",3,1024},{23280,"Knight-Lieutenant's Dragonhide Grips",3,1024},{23281,"Knight-Lieutenant's Dragonhide Treads",3,1024},{23308,"Lieutenant Commander's Dragonhide Headguard",3,1024},{23309,"Lieutenant Commander's Dragonhide Shoulders",3,1024}},bonuses={{2,14049,"+40 Attack Power."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[600]={name="Primalist's Trappings",classMask=0,items={{81065,"Primalist's Boots",2,-1},{81061,"Primalist's Gloves",2,-1},{81063,"Primalist's Headdress",2,-1},{81064,"Primalist's Pants",2,-1},{81062,"Primalist's Shoulders",2,-1},{81066,"Primalist's Vest",3,-1}},bonuses={{3,18676,"+5 All Resistances."},{6,9314,"Increases healing done by spells and effects by up to 24."}}}
C[601]={name="Rune-Etched Armor",classMask=0,items={{60290,"Rune-Etched Breastplate",3,-1},{60291,"Rune-Etched Crown",3,-1},{60288,"Rune-Etched Greaves",3,-1},{60287,"Rune-Etched Grips",3,-1},{60289,"Rune-Etched Legplates",3,-1},{60292,"Rune-Etched Mantle",3,-1}},bonuses={{3,21598,"Restores 6 health per 5 sec."},{6,7219,"Immune to Disarm."}}}
C[602]={name="Grifter's Armor",classMask=0,items={{83403,"Grifter's Belt",2,-1},{83405,"Grifter's Boots",2,-1},{83404,"Grifter's Gauntlets",2,-1},{83402,"Grifter's Leggings",2,-1},{83401,"Grifter's Tunic",2,-1},{83400,"Grifter's Cover",2,-1}},bonuses={{3,9121,"+10 Strength."},{6,13665,"Increases your chance to parry an attack by 1%."}}}
C[603]={name="Steel Plate Armor",classMask=0,items={{83410,"Steel Plate Boots",2,-1},{83411,"Steel Plate Gauntlets",2,-1},{83413,"Steel Plate Armor",2,-1},{83415,"Steel Plate Barbute",3,-1},{1983345,"Steel Plate Barbute",3,-1},{83412,"Steel Plate Legguards",2,-1},{83414,"Steel Plate Pauldrons",2,-1}},bonuses={{3,14803,"+200 Armor."},{6,9336,"+30 Attack Power."}}}
C[604]={name="Diviner's Garments",classMask=0,items={{83283,"Diviner's Boots",2,-1},{83284,"Diviner's Mitts",2,-1},{83282,"Diviner's Cowl",2,-1},{83285,"Diviner's Epaulets",2,-1},{83280,"Diviner's Pantaloons",2,-1},{83281,"Diviner's Robe",3,-1}},bonuses={{3,9111,"+10 Spirit."},{6,9407,"Increases healing done by spells and effects by up to 20."}}}
C[605]={name="Augerer's Attire",classMask=0,items={{83288,"Augerer's Boots",2,-1},{83289,"Augerer's Gloves",2,-1},{83290,"Augerer's Mantle",2,-1},{83291,"Augerer's Trousers",2,-1},{83286,"Augerer's Hat",2,-1},{83287,"Augerer's Robe",3,-1}},bonuses={{3,9106,"+10 Intellect."},{6,14713,"+11 Arcane Resistance."}}}
C[606]={name="Pillager's Garb",classMask=0,items={{83296,"Pillager's Shoes",2,-1},{83295,"Pillager's Grips",2,-1},{83297,"Pillager's Pantaloons",2,-1},{83293,"Pillager's Amice",2,-1},{83292,"Pillager's Hood",2,-1},{83294,"Pillager's Robe",3,-1}},bonuses={{3,21599,"Restores 6 health per 5 sec."},{6,18384,"Improves your chance to get a critical strike with spells by 1%."}}}
C[607]={name="Red Dragon Mail",classMask=0,items={{65002,"Red Dragonscale Boots",3,-1},{65000,"Red Dragonscale Leggings",3,-1},{15047,"Red Dragonscale Breastplate",3,-1},{65001,"Red Dragonscale Shoulders",3,-1}},bonuses={{2,14592,"+12 Fire Resistance."},{3,9315,"Increases healing done by spells and effects by up to 26."},{4,48000,"Your direct healing spells have a chance to heal your target for 240 over 12 sec."}}}
C[608]={name="Bloody Gladiator's Regalia",classMask=0,items={{83427,"Bloody Gladiator's Amice",4,-1},{83423,"Bloody Gladiator's Britches",3,-1},{83428,"Bloody Gladiator's Circlet",4,-1},{83424,"Bloody Gladiator's Footwraps",3,-1},{83421,"Bloody Gladiator's Handwraps",3,-1},{83420,"Bloody Gladiator's Sash",3,-1},{83426,"Bloody Gladiator's Vestments",4,-1},{83425,"Bloody Gladiator's Wraps",3,-1}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{4,26283,"Decreases the magical resistances of your spell targets by -20."},{6,14047,"Increases damage and healing done by magical spells and effects by up to 23."},{8,18382,"Improves your chance to get a critical strike with spells by 2%."}}}
C[609]={name="Bloody Gladiator's Vestments",classMask=0,items={{83433,"Bloody Gladiator's Bands",3,-1},{83429,"Bloody Gladiator's Belt",3,-1},{83432,"Bloody Gladiator's Boots",3,-1},{83430,"Bloody Gladiator's Gloves",3,-1},{83436,"Bloody Gladiator's Headband",4,-1},{83431,"Bloody Gladiator's Pants",3,-1},{83435,"Bloody Gladiator's Shoulders",4,-1},{83434,"Bloody Gladiator's Tunic",4,-1}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{4,48036,"Your attacks ignore -100 of the target's armor."},{6,14049,"+40 Attack Power."},{8,7598,"Improves your chance to get a critical strike by 2%."}}}
C[610]={name="Bloody Gladiator's Pursuit",classMask=0,items={{60355,"Bloody Gladiator's Armor",4,-1},{60350,"Bloody Gladiator's Cord",3,-1},{60351,"Bloody Gladiator's Handguards",3,-1},{60357,"Bloody Gladiator's Helmet",4,-1},{60352,"Bloody Gladiator's Leggings",3,-1},{60356,"Bloody Gladiator's Pauldrons",4,-1},{60353,"Bloody Gladiator's Trudgeons",3,-1},{60354,"Bloody Gladiator's Wristguards",3,-1}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{4,8815,"Increases your attack and casting speed by 2%."},{4,25975,"Decreases the magical resistances of your spell targets by -10."},{6,9331,"+20 Attack Power."},{6,9342,"Increases damage and healing done by magical spells and effects by up to 13."},{8,7597,"Improves your chance to get a critical strike by 1%."},{8,18384,"Improves your chance to get a critical strike with spells by 1%."}}}
C[611]={name="Bloody Gladiator's Battlegear",classMask=0,items={{60362,"Bloody Gladiator's Bracers",3,-1},{60363,"Bloody Gladiator's Breastplate",4,-1},{60359,"Bloody Gladiator's Gauntlets",3,-1},{60358,"Bloody Gladiator's Girdle",3,-1},{60361,"Bloody Gladiator's Greaves",3,-1},{60365,"Bloody Gladiator's Helm",4,-1},{60360,"Bloody Gladiator's Legguards",3,-1},{60364,"Bloody Gladiator's Spaulders",4,-1}},bonuses={{2,14467,"+20 Stamina."},{2,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."},{4,48036,"Your attacks ignore -100 of the target's armor."},{6,14049,"+40 Attack Power."},{8,7598,"Improves your chance to get a critical strike by 2%."}}}
C[612]={name="Incendosaur Skin Armor",classMask=0,items={{60582,"Incendosaur Skin Gloves",3,-1},{60572,"Incendosaur Skin Pauldrons",3,-1},{60568,"Incendosaur Skin Boots",3,-1}},bonuses={{2,7711,"Adds 2 fire damage to your melee attacks."},{3,9233,"5% chance of dealing 15 to 25 Fire damage on a successful melee attack."}}}
C[613]={name="Redemption of the Prophecy",classMask=2,items={{21704,"Boots of the Redeemed Prophecy",4,32767},{21889,"Gloves of the Redeemed Prophecy",4,2},{1487825,"Gloves of the Redeemed Prophecy",4,2},{21683,"Mantle of the Redeemed Prophecy",4,32767}},bonuses={{2,9343,"Increases damage and healing done by magical spells and effects by up to 14."},{3,8815,"Increases your attack and casting speed by 2%."},{3,21408,"Increased Defense +12."}}}
C[614]={name="Fall of the Prophet",classMask=64,items={{21705,"Boots of the Fallen Prophet",4,32767},{21890,"Gloves of the Fallen Prophet",4,64},{21684,"Mantle of the Fallen Prophet",4,32767}},bonuses={{2,9343,"Increases damage and healing done by magical spells and effects by up to 14."},{3,8815,"Increases your attack and casting speed by 2%."},{3,21408,"Increased Defense +12."}}}
C[615]={name="Hateforge Armor",classMask=0,items={{60576,"Hateforge Belt",3,-1},{60578,"Hateforge Boots",3,-1},{60577,"Hateforge Grips",4,-1},{60574,"Hateforge Cuirass",3,-1},{60573,"Hateforge Helmet",3,-1},{60575,"Hateforge Leggings",3,-1}},bonuses={{2,9331,"+20 Attack Power."},{4,48036,"Your attacks ignore -100 of the target's armor."},{6,8815,"Increases your attack and casting speed by 2%."}}}
C[616]={name="Living Armor",classMask=0,items={{15061,"Living Shoulders",3,-1},{15060,"Living Leggings",3,-1},{15059,"Living Breastplate",3,-1}},bonuses={{2,9314,"Increases healing done by spells and effects by up to 24."},{3,14776,"Allows 10% of your Mana regeneration to continue while casting."}}}
C[617]={name="Warbear Armor",classMask=0,items={{15064,"Warbear Harness",3,-1},{15065,"Warbear Woolies",3,-1}},bonuses={{2,7597,"Improves your chance to get a critical strike by 1%."},{2,13669,"Increases your chance to dodge an attack by 1%."}}}
C[618]={name="Dragon Mail",classMask=0,items={{8347,"Dragonscale Gauntlets",3,-1},{65019,"Dragonscale Leggings",3,-1},{8367,"Dragonscale Breastplate",3,-1}},bonuses={{2,9117,"+10 Stamina."},{3,48036,"Your attacks ignore -100 of the target's armor."}}}
C[619]={name="Bronze Dragon Mail",classMask=0,items={{60581,"Bronze Dragonscale Gloves",3,-1},{60580,"Bronze Dragonscale Leggings",3,-1},{60579,"Bronze Dragonscale Breastplate",3,-1}},bonuses={{2,15687,"+250 Armor."},{3,13670,"Increases your chance to dodge an attack by 2%."}}}
C[620]={name="Convergence of the Elements",classMask=0,items={{65026,"Depthstalker Helm",4,-1},{65024,"Earthguard Tunic",4,-1},{65025,"Flamewrath Leggings",4,-1},{65027,"Windwalker Boots",4,-1}},bonuses={{2,18676,"+5 All Resistances."},{3,13669,"Increases your chance to dodge an attack by 1%."},{3,15464,"Improves your chance to hit by 1%."},{4,13679,"Increases your attack and casting speed by 1%."},{4,14027,"+24 Attack Power."},{4,24090,"Minor increase to running and swimming speed."}}}
C[621]={name="Cloudweave Raiment",classMask=0,items={{60558,"Cloudweaver Gloves",3,-1},{60557,"Cloudweaver Kilt",3,-1},{60555,"Cloudweaver Mantle",3,-1},{60556,"Cloudweaver Vest",3,-1}},bonuses={{2,24595,"Increases damage and healing done by magical spells and effects by up to 24."},{3,21629,"Restores 8 mana per 5 sec."},{4,23729,"Improves your chance to hit with spells by 2%."}}}
C[622]={name="Greymane Armor",classMask=0,items={{61376,"Greymane Gauntlets",2,-1},{61378,"Greymane Legplates",2,-1},{61377,"Greymane Sabatons",2,-1},{61379,"Greymane Vambraces",2,-1},{61313,"Greymane Helmet",3,-1},{61324,"Greymane Shoulders",3,-1}},bonuses={{2,7524,"Increased Swords +4."},{4,45421,"2% of damage dealt is returned as healing."},{6,44087,"Your successful melee attacks have a chance to bestow you with the mark of Greymane, increasing your Strength by 40 and causes 5% of damage dealt to heal you but damages you for 50 Shadow damage every second for 10 sec."}}}
C[623]={name="Dreamsteel Armor",classMask=0,items={{61367,"Dreamsteel Boots",4,-1},{61366,"Dreamsteel Bracers",4,-1},{61365,"Dreamsteel Leggings",4,-1},{61364,"Dreamsteel Mantle",4,-1}},bonuses={{2,9330,"+18 Attack Power."},{4,48036,"Your attacks ignore -100 of the target's armor."}}}
C[626]={name="Dreamhide Battlegarb",classMask=0,items={{61359,"Dreamhide Belt",4,-1},{61357,"Dreamhide Bracers",4,-1},{61358,"Dreamhide Leggings",4,-1},{61356,"Dreamhide Mantle",4,-1}},bonuses={{2,18681,"+10 All Resistances."},{4,45431,"+56 Attack Power in Cat, Bear, Dire Bear, and Moonkin forms only."}}}
C[627]={name="Dreamthread Regalia",classMask=0,items={{61362,"Dreamthread Bracers",4,-1},{61363,"Dreamthread Gloves",4,-1},{61361,"Dreamthread Kilt",4,-1},{61360,"Dreamthread Mantle",4,-1}},bonuses={{2,9346,"Increases damage and healing done by magical spells and effects by up to 18."},{4,8815,"Increases your attack and casting speed by 2%."}}}
C[628]={name="Mooncloth Regalia",classMask=0,items={{15802,"Mooncloth Boots",3,-1},{14137,"Mooncloth Leggings",3,-1},{14138,"Mooncloth Vest",3,-1},{18486,"Mooncloth Robe",3,-1},{14139,"Mooncloth Shoulders",3,-1},{14140,"Mooncloth Circlet",3,-1},{18409,"Mooncloth Gloves",3,-1}},bonuses={{2,9408,"Increases healing done by spells and effects by up to 22."},{4,21364,"Restores 7 mana per 5 sec."},{6,45491,"Your direct healing spells have a small chance to instantly heal your target for 150 and increase healing taken by up to 20 for 10 sec."}}}
C[629]={name="Flarecore Regalia",classMask=1535,items={{16979,"Flarecore Gloves",4,-1},{65035,"Flarecore Boots",4,-1},{19165,"Flarecore Leggings",4,-1},{16980,"Flarecore Mantle",4,-1},{19156,"Flarecore Robe",4,-1},{18263,"Flarecore Wraps",4,1535}},bonuses={{2,23727,"Improves your chance to hit with spells by 1%."},{4,14594,"+14 Fire Resistance."},{6,45846,"You have a chance when landing a damaging spell to deal 100 Fire damage to all targets within yards."}}}
C[630]={name="Towerforge Battlegear",classMask=0,items={{60008,"Towerforge Breastplate",4,-1},{60007,"Towerforge Crown",4,-1},{60010,"Towerforge Demolisher",4,-1},{60009,"Towerforge Pauldrons",4,-1}},bonuses={{2,15774,"Increased Two-handed Maces +6."},{3,45847,"You have a 3% chance to reflect harmful spells."},{4,45496,"Your melee hits have a 2% chance to grant 50 Strength for 10 sec."}}}
C[631]={name="Spellweaver's Accessories",classMask=0,items={{56090,"Spellweaver Pendant",2,-1},{55271,"Spellweaver Rod",2,-1}},bonuses={{2,7501,"+7 Spirit."}}}
C[632]={name="Ornate Mithril Jewelry",classMask=0,items={{56070,"Ornate Mithril Bracelets",3,-1},{56089,"Ornate Mithril Crown",2,-1}},bonuses={{2,25975,"Decreases the magical resistances of your spell targets by -10."}}}
C[633]={name="Midnight Regalia",classMask=0,items={{41312,"Pendant of Midnight",2,-1},{56091,"Ring of Midnight",2,-1}},bonuses={{2,14673,"+10 Shadow Resistance."}}}
C[634]={name="Stormcloud Jewelry",classMask=0,items={{56092,"Stormcloud Shackles",2,-1},{56035,"Stormcloud Sigil",2,-1},{56093,"Stormcloud Signet",3,-1}},bonuses={{3,9411,"Increases damage done by Nature spells and effects by up to 14."}}}
C[635]={name="Goldmaster's Jewelry",classMask=0,items={{41340,"Shimmering Gold Necklace",2,-1},{56050,"Elaborate Golden Bracelets",2,-1},{56053,"Golden Jade Ring",3,-1}},bonuses={{3,21430,"+12 ranged Attack Power."}}}
C[636]={name="Aquamarine Jewelry",classMask=0,items={{56048,"Dazzling Aquamarine Loop",2,-1},{55196,"Aquamarine Pendant",2,-1}},bonuses={{2,7507,"+5 Strength."}}}
C[637]={name="Mastercrafted Diamond Jewelry",classMask=0,items={{56096,"Mastercrafted Diamond Bangles",4,-1},{56064,"Mastercrafted Diamond Crown",4,-1}},bonuses={{2,23727,"Improves your chance to hit with spells by 1%."}}}
C[638]={name="Possessions of the Lost",classMask=2,items={{60798,"Loop of the Lost",3,-1},{60809,"Remains of the Lost",3,-1},{22253,"Tome of the Lost",3,-1},{70503,"Lawbringer Bindings",4,2},{70502,"Lawbringer Chestplate",4,2},{70500,"Lawbringer Crown",4,2},{70508,"Lawbringer Gauntlets",4,2},{70504,"Lawbringer Girdle",4,2},{70506,"Lawbringer Leggings",4,2},{70501,"Lawbringer Pauldrons",4,2},{70507,"Lawbringer Sabatons",4,2},{60790,"Memento of the Lost",3,-1}},bonuses={{3,51130,"Gives a chance when your harmful spells land to reawaken the Lost for 20 sec."}}}
C[639]={name="Medivh's Clarity",classMask=2,items={{70511,"Lawbringer Chestguard",4,2},{70515,"Lawbringer Greaves",4,2},{70516,"Lawbringer Handguards",4,2},{70509,"Lawbringer Helmet",4,2},{70514,"Lawbringer Legguards",4,2},{70510,"Lawbringer Shoulderguards",4,2},{70513,"Lawbringer Waistguard",4,2},{70512,"Lawbringer Wristguards",4,2},{61251,"Medivh's Foresight",4,-1},{55094,"Medivh's Hindsight",4,-1}},bonuses={{2,18056,"Increases damage and healing done by magical spells and effects by up to 40."}}}
C[640]={name="Dreadslayer's Rampage",classMask=2,items={{55113,"Dreadslayer Horns",4,-1},{55108,"Dreadslayer Shoulderblades",4,-1},{70519,"Judgement Chestguard",4,2},{70524,"Judgement Greaves",4,2},{70521,"Judgement Handguards",4,2},{70517,"Judgement Helmet",4,2},{70523,"Judgement Legguards",4,2},{70518,"Judgement Shoulderguards",4,2},{70522,"Judgement Waistguard",4,2},{70520,"Judgement Wristguards",4,2}},bonuses={{2,48037,"Your attacks ignore -150 of the target's armor."}}}
C[641]={name="Lawbringer Battleplate",classMask=2,items={{70528,"Judgement Bindings",4,2},{70527,"Judgement Chestplate",4,2},{70525,"Judgement Crown",4,2},{70529,"Judgement Gauntlets",4,2},{70530,"Judgement Girdle",4,2},{70531,"Judgement Leggings",4,2},{70526,"Judgement Pauldrons",4,2},{70532,"Judgement Sabatons",4,2},{47002,"Lawbringer Chestguard",4,2},{47007,"Lawbringer Greaves",4,2},{47004,"Lawbringer Handguards",4,2},{47000,"Lawbringer Helmet",4,2},{47006,"Lawbringer Legguards",4,2},{47001,"Lawbringer Shoulderguards",4,2},{47005,"Lawbringer Waistguard",4,2},{47003,"Lawbringer Wristguards",4,2}},bonuses={{3,51806,"Reduces the cost of Consecration by -20%."},{5,13675,"Increases your chance to block attacks with a shield by 2%."},{8,51805,"Gives the Paladin a chance on each melee hit to burst with Holy radiance, dealing an additional 90 to 98 Holy damage to the target."}}}
C[642]={name="Lawbringer Battlegear",classMask=2,items={{70539,"Avenger's Chestguard",4,2},{70541,"Avenger's Greaves",4,2},{70537,"Avenger's Helmet",4,2},{70540,"Avenger's Legguards",4,2},{70538,"Avenger's Shoulderguards",4,2},{47011,"Lawbringer Bindings",4,2},{47010,"Lawbringer Chestplate",4,2},{47008,"Lawbringer Crown",4,2},{47012,"Lawbringer Gauntlets",4,2},{47013,"Lawbringer Girdle",4,2},{47014,"Lawbringer Leggings",4,2},{47009,"Lawbringer Pauldrons",4,2},{47015,"Lawbringer Sabatons",4,2}},bonuses={{3,51801,"Judgement of Righteousness and Judgement of Command deal an additional 148 Holy damage."},{5,7598,"Improves your chance to get a critical strike by 2%."},{8,51803,"Gives the Paladin a chance on each melee hit to burst with Holy radiance, dealing an additional 112 to 134 Holy damage to the target."}}}
C[643]={name="Judgement Battleplate",classMask=2,items={{70546,"Avenger's Boots",4,2},{70544,"Avenger's Breastplate",4,2},{70542,"Avenger's Helm",4,2},{70545,"Avenger's Legplates",4,2},{70543,"Avenger's Spaulders",4,2},{47018,"Judgement Chestguard",4,2},{1899481,"Judgement Chestguard",4,2},{47023,"Judgement Greaves",4,2},{1956894,"Judgement Greaves",4,2},{47020,"Judgement Handguards",4,2},{1906961,"Judgement Handguards",4,2},{47016,"Judgement Helmet",4,2},{47022,"Judgement Legguards",4,2},{1899483,"Judgement Legguards",4,2},{47017,"Judgement Shoulderguards",4,2},{1899480,"Judgement Shoulderguards",4,2},{47021,"Judgement Waistguard",4,2},{1899482,"Judgement Waistguard",4,2},{47019,"Judgement Wristguards",4,2}},bonuses={{3,51811,"Adds 3 Holy damage to your melee attacks."},{5,14054,"Increases damage and healing done by magical spells and effects by up to 27."},{8,51815,"Whenever you block an attack, you have a chance to increase the block value of your next block by 200."}}}
C[644]={name="Judgement Battlegear",classMask=2,items={{47027,"Judgement Bindings",4,2},{47026,"Judgement Chestplate",4,2},{47024,"Judgement Crown",4,2},{47028,"Judgement Gauntlets",4,2},{47029,"Judgement Girdle",4,2},{47030,"Judgement Leggings",4,2},{47025,"Judgement Pauldrons",4,2},{47031,"Judgement Sabatons",4,2},{70573,"Redemption Chestguard",4,2},{70578,"Redemption Greaves",4,2},{70575,"Redemption Handguards",4,2},{70571,"Redemption Helmet",4,2},{70577,"Redemption Legguards",4,2},{70572,"Redemption Shoulderguards",4,2},{70576,"Redemption Waistguard",4,2},{70574,"Redemption Wristguards",4,2},{70579,"Ring of Redemption",4,2}},bonuses={{3,51811,"Adds 3 Holy damage to your melee attacks."},{5,14054,"Increases damage and healing done by magical spells and effects by up to 27."},{8,21882,"Chance to deal 300 additional Holy damage whenever you cause a critical hit in melee."}}}
C[645]={name="Avenger's Battleplate",classMask=2,items={{47034,"Avenger's Chestguard",4,2},{47036,"Avenger's Greaves",4,2},{47032,"Avenger's Helmet",4,2},{47035,"Avenger's Legguards",4,2},{47033,"Avenger's Shoulderguards",4,2},{70583,"Redemption Bindings",4,2},{70582,"Redemption Chestplate",4,2},{70580,"Redemption Crown",4,2},{70584,"Redemption Gauntlets",4,2},{70585,"Redemption Girdle",4,2},{70586,"Redemption Leggings",4,2},{70581,"Redemption Pauldrons",4,2},{70587,"Redemption Sabatons",4,2},{70588,"Ring of Redemption",4,2}},bonuses={{3,51819,"Increases the damage of Judgement of Righteousness and Judgement of Command by 15%."},{5,28264,"Increases damage and healing done by magical spells and effects by up to 46."}}}
C[646]={name="Avenger's Armor",classMask=2,items={{47041,"Avenger's Boots",4,2},{47039,"Avenger's Breastplate",4,2},{47037,"Avenger's Helm",4,2},{47040,"Avenger's Legplates",4,2},{47038,"Avenger's Spaulders",4,2}},bonuses={{3,57161,"Allows 15% of your Mana regeneration to continue while casting."},{5,51817,"Your Holy Shock, Flash of Light and Holy Light have a chance to empower you with Spirit of Arathor, increasing healing done by spells and effects by up to 173 for 12 sec."}}}
C[647]={name="Redemption Battleplate",classMask=2,items={{47044,"Redemption Chestguard",4,2},{1968914,"Redemption Chestguard",4,2},{47049,"Redemption Greaves",4,2},{1968915,"Redemption Greaves",4,2},{47046,"Redemption Handguards",4,2},{47042,"Redemption Helmet",4,2},{1966257,"Redemption Helmet",4,2},{47048,"Redemption Legguards",4,2},{1915084,"Redemption Legguards",4,2},{47043,"Redemption Shoulderguards",4,2},{47047,"Redemption Waistguard",4,2},{1965577,"Redemption Waistguard",4,2},{47045,"Redemption Wristguards",4,2},{47050,"Signet of Redemption",4,2}},bonuses={{2,13676,"Increases your chance to block attacks with a shield by 3%."},{4,28325,"Increases the block value of your shield by 32."},{6,51823,"Reduces the cooldown of Exorcism by -5 seconds."},{8,23213,"Increases damage and healing done by magical spells and effects by up to 57."}}}
C[648]={name="Redemption Battlegear",classMask=2,items={{47059,"Band of Redemption",4,2},{47054,"Redemption Bindings",4,2},{1710912,"Redemption Bindings",4,2},{47053,"Redemption Chestplate",4,2},{47051,"Redemption Crown",4,2},{47055,"Redemption Gauntlets",4,2},{47056,"Redemption Girdle",4,2},{1983150,"Redemption Girdle",4,2},{47057,"Redemption Leggings",4,2},{47052,"Redemption Pauldrons",4,2},{47058,"Redemption Sabatons",4,2}},bonuses={{2,7599,"Improves your chance to get a critical strike by 3%."},{4,8815,"Increases your attack and casting speed by 2%."},{6,51823,"Reduces the cooldown of Exorcism by -5 seconds."},{8,23213,"Increases damage and healing done by magical spells and effects by up to 57."}}}
C[649]={name="Cenarion Regalia",classMask=1024,items={{47330,"Cenarion Circlet",4,1024},{47334,"Cenarion Handwraps",4,1024},{47331,"Cenarion Mantle",4,1024},{47335,"Cenarion Sash",4,1024},{47337,"Cenarion Slippers",4,1024},{47336,"Cenarion Trousers",4,1024},{47332,"Cenarion Vest",4,1024},{47333,"Cenarion Wristbands",4,1024}},bonuses={{3,18382,"Improves your chance to get a critical strike with spells by 2%."},{5,52323,"Reduce the Mana costs of your Balance spells by -15%."},{8,52325,"Your landing Balance spells have a chance to heal the lowest health friendly target within 30 yards for 150 health."}}}
C[650]={name="Cenarion Harness",classMask=1024,items={{47343,"Cenarion Girdle",4,1024},{47342,"Cenarion Handguards",4,1024},{47338,"Cenarion Helmet",4,1024},{47344,"Cenarion Pants",4,1024},{47340,"Cenarion Raiments",4,1024},{47339,"Cenarion Shoulderpads",4,1024},{47345,"Cenarion Treads",4,1024},{47341,"Cenarion Wristguards",4,1024}},bonuses={{3,52350,"Reduces the cooldown of Faerie Fire (Feral) by -2 seconds."},{5,52351,"Reduces the energy cost of Tiger's Fury by -5."},{8,52352,"Ferocious Bite has a 20% chance per combo point spent to put you into a frenzy, increasing the attack speed of your next 5 attacks by 15%."}}}
C[651]={name="Stormrage Regalia",classMask=1024,items={{47346,"Stormrage Circlet",4,1024},{47350,"Stormrage Handwraps",4,1024},{47347,"Stormrage Mantle",4,1024},{47351,"Stormrage Sash",4,1024},{47353,"Stormrage Slippers",4,1024},{47352,"Stormrage Trousers",4,1024},{47348,"Stormrage Vest",4,1024},{47349,"Stormrage Wristbands",4,1024}},bonuses={{3,52326,"Increase the mana regeneration of Owlkin Frenzy by 1%."},{5,52328,"Critical strikes with your Balance spells shield you, absorbing 250 damage for 6 sec."},{8,52330,"Casting Moonfire reduces the Mana cost of your Moonfire by -12% for 6 sec. Stacks up to 3 times."}}}
C[652]={name="Stormrage Harness",classMask=1024,items={{47359,"Stormrage Girdle",4,1024},{47358,"Stormrage Handguards",4,1024},{47354,"Stormrage Helmet",4,1024},{47360,"Stormrage Pants",4,1024},{47356,"Stormrage Raiments",4,1024},{47355,"Stormrage Shoulderpads",4,1024},{47361,"Stormrage Treads",4,1024},{47357,"Stormrage Wristguards",4,1024}},bonuses={{3,52354,"Increase the damage and duration of Thorns by 100%."},{5,52355,"Reduces the Rage cost of your Savage Bite by -5."},{8,52357,"Increase Defenses by 30 while Frenzied Regeneration is active."}}}
C[653]={name="Genesis Raiment",classMask=1024,items={{47366,"Genesis Boots",4,1024},{47362,"Genesis Helm",4,1024},{47365,"Genesis Leggings",4,1024},{47363,"Genesis Spaulders",4,1024},{47364,"Genesis Vestments",4,1024}},bonuses={{3,52344,"Reduces the cast time of your Healing Touch spell by 0 sec."},{5,52345,"Your Healing Touch spells heal targets affected by Rejuvenation and Regrowth each for 10% more."}}}
C[654]={name="Genesis Harness",classMask=1024,items={{47367,"Genesis Helmet",4,1024},{47370,"Genesis Pants",4,1024},{47369,"Genesis Raiments",4,1024},{47368,"Genesis Shoulderpads",4,1024},{47371,"Genesis Treads",4,1024}},bonuses={{3,52358,"Reduces the Energy cost of Rake, Shred, and Claw by -3."},{5,52360,"Damage of your Rake and Rip have a 6% and 10% chance respectively to empower your next Shred, Rake or Claw, increasing its critical strike chance and damage by 15%."}}}
C[655]={name="Dreamwalker Regalia",classMask=1024,items={{47372,"Dreamwalker Circlet",4,1024},{47376,"Dreamwalker Handwraps",4,1024},{47373,"Dreamwalker Mantle",4,1024},{47377,"Dreamwalker Sash",4,1024},{47379,"Dreamwalker Slippers",4,1024},{47378,"Dreamwalker Trousers",4,1024},{47374,"Dreamwalker Vest",4,1024},{47375,"Dreamwalker Wristbands",4,1024},{47380,"Signet of the Dreamwalker",4,1024}},bonuses={{2,52333,"Casting Innervate on a different friendly target now also applies an Innervate with 50% effectiveness on yourself."},{4,52331,"Increase the duration of Moonfire by 3. and of Insect Swarm by 2."},{6,52335,"Damage of your Moonfire and Insect Swarm has a chance to increase Nature and Arcane damage taken by 3% for 6 sec."},{8,52337,"Entering an Eclipse increases your casting speed by 10% for 8 sec."}}}
C[656]={name="Dreamwalker Harness",classMask=1024,items={{47389,"Band of the Dreamwalker",4,1024},{47386,"Dreamwalker Girdle",4,1024},{47385,"Dreamwalker Handwraps",4,1024},{47381,"Dreamwalker Helmet",4,1024},{47387,"Dreamwalker Pants",4,1024},{47383,"Dreamwalker Raiments",4,1024},{47382,"Dreamwalker Shoulderpads",4,1024},{47388,"Dreamwalker Treads",4,1024},{47384,"Dreamwalker Wristguards",4,1024}},bonuses={{2,13670,"Increases your chance to dodge an attack by 2%."},{4,52363,"Increases your chance to hit with Growl and Challenging Roar by 5%."},{6,52364,"Increase the health contribution of Bear and Dire Bear Form by 25%."},{8,52366,"Using Savage Bite reduces all damage taken by -2% for 15 sec. Stacks up to 4 times."}}}
C[657]={name="Arcanist's Vestments",classMask=128,items={{47078,"Arcanist Circlet",4,128},{47083,"Arcanist Cord",4,128},{47079,"Arcanist Epaulets",4,128},{47082,"Arcanist Handwraps",4,128},{47085,"Arcanist Slippers",4,128},{47084,"Arcanist Trousers",4,128},{1982112,"Arcanist Trousers",4,128},{47080,"Arcanist Vestments",4,128},{47081,"Arcanist Wristbands",4,128}},bonuses={{3,8815,"Increases your attack and casting speed by 2%."},{5,52568,"Your damaging Arcane spells have a chance to restore mana over 5 sec."},{8,52587,"Your Arcane Rupture affects all Arcane spells that deal damage."}}}
C[658]={name="Netherwind Vestments",classMask=128,items={{47086,"Netherwind Circlet",4,128},{1983138,"Netherwind Circlet",4,128},{47091,"Netherwind Cord",4,128},{1983136,"Netherwind Cord",4,128},{47087,"Netherwind Epaulets",4,128},{1983618,"Netherwind Epaulets",4,128},{47090,"Netherwind Handwraps",4,128},{1983619,"Netherwind Handwraps",4,128},{47093,"Netherwind Slippers",4,128},{1983411,"Netherwind Slippers",4,128},{47092,"Netherwind Trousers",4,128},{47088,"Netherwind Vestments",4,128},{47089,"Netherwind Wristbands",4,128},{1983137,"Netherwind Wristbands",4,128}},bonuses={{3,52579,"Mage Armor increases resistance by an additional 15 to all magic schools and allows an additional 15% of your mana regeneration to continue while casting."},{5,52570,"Your critical strikes with damaging Arcane spells increase your casting speed by 5% for 6 sec."},{8,52572,"Arcane Surge increases the damage of your spells and effects by up to 40 for 8 sec."}}}
C[659]={name="Enigma Vestments",classMask=128,items={{47094,"Enigma Crown",4,128},{47095,"Enigma Epaulets",4,128},{47098,"Enigma Slippers",4,128},{47097,"Enigma Trousers",4,128},{47096,"Enigma Vestments",4,128}},bonuses={{3,52586,"When any of your Arcane spells is partially or fully resisted, the cooldown of your next Evocation is reduced by -10 sec. Stacks up to times."},{5,52594,"Upon fully channeling Evocation, the damage of your magical spells and effects is increased by 10% and their mana costs is increased by 10% for 8 sec."}}}
C[660]={name="Frostfire Vestments",classMask=128,items={{47102,"Frostfire Bracers",4,128},{47104,"Frostfire Cord",4,128},{1981001,"Frostfire Cord",4,128},{47099,"Frostfire Crown",4,128},{1980971,"Frostfire Crown",4,128},{47100,"Frostfire Epaulets",4,128},{47103,"Frostfire Handwraps",4,128},{47107,"Frostfire Signet",4,128},{47106,"Frostfire Slippers",4,128},{1980974,"Frostfire Slippers",4,128},{47105,"Frostfire Trousers",4,128},{47101,"Frostfire Vestments",4,128},{1980973,"Frostfire Vestments",4,128}},bonuses={{2,52582,"When your Mana Shield is broken, it erupts violently, dealing Arcane damage equal to 20% of the absorbed damage to all targets within yards."},{4,52592,"Your Arcane Rupture and Arcane Surge critical strikes displace enemies within yards of the target, reducing all their resistances by -25 for 8 sec."},{6,52580,"While Arcane Power is active, your Arcane spell critical strikes restore 3% of your maximum mana."},{8,52589,"Whenever your damaging Arcane spells are partially or fully resisted, the damage of your next direct spell cast within 6 sec is increased by 10%."}}}
C[661]={name="Regalia of Prophecy",classMask=16,items={{47201,"Bracers of Prophecy",4,16},{47198,"Coronet of Prophecy",4,16},{47202,"Handguards of Prophecy",4,16},{47200,"Raiments of Prophecy",4,16},{47205,"Sandals of Prophecy",4,16},{47203,"Sash of Prophecy",4,16},{47199,"Shoulderpads of Prophecy",4,16},{47204,"Trousers of Prophecy",4,16}},bonuses={{3,51771,"Your Shadow spells generate -15% less threat."},{5,51772,"Increases the duration of Mind Flay by 1 secs."},{8,51774,"Damage from your Shadow spells has a chance to cause an Epiphany, increasing damage done by Shadow spells and effects by up to 45 for 10 sec. This effect can only trigger once every 10 sec."}}}
C[662]={name="Regalia of Transcendence",classMask=16,items={{47209,"Bracers of Transcendence",4,16},{47206,"Coronet of Transcendence",4,16},{47210,"Gloves of Transcendence",4,16},{47212,"Pants of Transcendence",4,16},{47208,"Raiments of Transcendence",4,16},{47213,"Sandals of Transcendence",4,16},{47211,"Sash of Transcendence",4,16},{47207,"Shoulderpads of Transcendence",4,16}},bonuses={{3,51775,"Increases damage done by your Mana Burn by 30%."},{5,51776,"Increases the duration of your Vampiric Embrace by 20 sec."},{8,51778,"Your Shadow Word: Pain has a chance to increase the critical strike chance of your Mind Blast by 10%. This effect is expended when your Mind Blast critically strikes an enemy."}}}
C[663]={name="Attire of the Oracle",classMask=16,items={{47215,"Spaulders of the Oracle",4,16},{47214,"Tiara of the Oracle",4,16},{47218,"Treads of the Oracle",4,16},{47217,"Trousers of the Oracle",4,16},{47216,"Vestments of the Oracle",4,16}},bonuses={{3,51797,"When Heal or Greater Heal critically heals, your Spirit increases by 80 for 10 sec."},{5,51798,"Increases the radius of your Lightwell's Splendor of Light by 5 yards and the number of charges by 5."}}}
C[664]={name="Regalia of Faith",classMask=16,items={{47222,"Bracers of Faith",4,16},{47219,"Coronet of Faith",4,16},{47223,"Handguards of Faith",4,16},{47225,"Pants of Faith",4,16},{47221,"Raiments of Faith",4,16},{47224,"Sash of Faith",4,16},{47220,"Shoulderpads of Faith",4,16},{47227,"Signet of Faith",4,16},{47226,"Slippers of Faith",4,16}},bonuses={{2,51779,"Reduces the chance your Mind Control will be resisted by 3%."},{4,51780,"When your Mind Blast critically strikes a target its cooldown is reduced by -2 sec."},{6,51782,"Mind Flay has a chance to deal additional damage equal to 3 sec. of your Shadow Word: Pain if the effect is active on your target."},{8,51784,"Damage from your Shadow spells has a chance to grant your party a vampiric aura for 6 sec, returning 5% of their damage as healing. This effect can only trigger once every 10 sec."}}}
C[665]={name="Earthfury Battlegear",classMask=64,items={{47123,"Earthfury Bracelets",4,64},{47122,"Earthfury Breastplate",4,64},{47120,"Earthfury Crown",4,64},{47124,"Earthfury Fists",4,64},{47125,"Earthfury Girdle",4,64},{47126,"Earthfury Leggings",4,64},{47121,"Earthfury Pauldrons",4,64},{47127,"Earthfury Sabatons",4,64}},bonuses={{3,51837,"Reduces the cost of your instant cast spells by -15%."},{5,51838,"Flametongue Weapon deals 45% increased damage against targets affected by your Flame Shock."},{8,51840,"Your Earth Shock causes an Aftershock, dealing an additional 175 to 225 Nature damage after 4 sec."}}}
C[666]={name="Earthfury Garb",classMask=64,items={{47131,"Earthfury Bindings",4,64},{47129,"Earthfury Epaulets",4,64},{47132,"Earthfury Gauntlets",4,64},{47135,"Earthfury Greaves",4,64},{47134,"Earthfury Legplates",4,64},{47130,"Earthfury Raiments",4,64},{47133,"Earthfury Sash",4,64},{47128,"Earthfury Visor",4,64}},bonuses={{3,51861,"Increases the duration of your Searing Totem by 15 sec."},{5,51867,"Earth Shield increases all your resistances by 25 and increases your chance to ignore spell pushback by an additional 10%."},{8,46114,"Earthquake's broken earth lasts 2 sec longer, and its aftershock deals 25% increased damage."}}}
C[667]={name="Battlegear of the Ten Storms",classMask=64,items={{47139,"Bracelets of Ten Storms",4,64},{47138,"Breastplate of Ten Storms",4,64},{47136,"Crown of Ten Storms",4,64},{47140,"Fists of Ten Storms",4,64},{47141,"Girdle of Ten Storms",4,64},{47142,"Leggings of Ten Storms",4,64},{47137,"Pauldrons of Ten Storms",4,64},{47143,"Sabatons of Ten Storms",4,64}},bonuses={{3,51841,"Reduces the cooldown of your Lightning Strike and Stormstrike by sec."},{5,51844,"Lightning Strike causes your next attack to deal an additional 10% of its damage as Nature damage."},{8,51846,"Your Stormstrike has a chance to cause your next Lightning Bolt to cast instantly and guarantee it to land."}}}
C[668]={name="The Ten Storms",classMask=64,items={{47149,"Belt of Ten Storms",4,64},{47151,"Boots of Ten Storms",4,64},{47147,"Bracers of Ten Storms",4,64},{47146,"Chestpiece of Ten Storms",4,64},{47148,"Gloves of Ten Storms",4,64},{47144,"Helmet of Ten Storms",4,64},{47150,"Pants of Ten Storms",4,64},{47145,"Spaulders of Ten Storms",4,64}},bonuses={{3,51892,"Increases the number of charges of your shield spells by 2."},{5,23570,"Improves your chance to get a critical strike with Nature spells by 3%."},{8,23551,"When you cast a Healing Wave or Lesser Healing Wave, there is a 25% chance the target also receives a free Lightning Shield that causes 50 Nature damage to attacker on hit."}}}
C[669]={name="Stormcaller's Battlegear",classMask=64,items={{47154,"Stormcaller's Breastplate",4,64},{47152,"Stormcaller's Crown",4,64},{47155,"Stormcaller's Leggings",4,64},{47153,"Stormcaller's Pauldrons",4,64},{47156,"Stormcaller's Sabatons",4,64}},bonuses={{3,51848,"Triggering your elemental shield reduces all spell damage taken by -4% for 10 sec, stacking up to 3 times. All charges of this effect are removed when you're hit by a direct damaging spell."},{5,51849,"Increases the amount of Earthen Bulwark built up from physical damage by 25% for Elemental Weapons' Rockbiter effect, and increases the damage absorbed by the Earthen Bulwark by an additional 3%."}}}
C[670]={name="The Stormcaller",classMask=64,items={{47161,"Stormcaller's Boots",4,64},{47159,"Stormcaller's Chestpiece",4,64},{47157,"Stormcaller's Helmet",4,64},{47160,"Stormcaller's Pants",4,64},{47158,"Stormcaller's Spaulders",4,64}},bonuses={{3,51893,"The amount of mana you're resurrected with after using Reincarnation is increased by 50%."},{5,51894,"Deepen the spiritual connections of your allies, the amount of damage distributed by your Spirit Link is increased by 5%."}}}
C[671]={name="Earthshatterer's Battlegear",classMask=64,items={{47165,"Earthshatter Bracelets",4,64},{1732038,"Earthshatter Bracelets",4,64},{1927740,"Earthshatter Bracelets",4,64},{47164,"Earthshatter Breastplate",4,64},{1758375,"Earthshatter Breastplate",4,64},{1971301,"Earthshatter Breastplate",4,64},{47162,"Earthshatter Crown",4,64},{1732025,"Earthshatter Crown",4,64},{1958997,"Earthshatter Crown",4,64},{47166,"Earthshatter Fists",4,64},{47167,"Earthshatter Girdle",4,64},{1980135,"Earthshatter Girdle",4,64},{47168,"Earthshatter Leggings",4,64},{1745702,"Earthshatter Leggings",4,64},{1927738,"Earthshatter Leggings",4,64},{47163,"Earthshatter Pauldrons",4,64},{1738324,"Earthshatter Pauldrons",4,64},{1943560,"Earthshatter Pauldrons",4,64},{47169,"Earthshatter Sabatons",4,64},{1732029,"Earthshatter Sabatons",4,64},{1943561,"Earthshatter Sabatons",4,64},{47170,"Signet of the Earthshatterer",4,64}},bonuses={{2,51850,"Increases the effectiveness of your empowered shields by 15%."},{4,51851,"Increases the critical strike chance of your Shock spells by 5%."},{6,51855,"Your Earth Shock, Frost Shock and Flame Shock increase the damage of your next Flame Shock, Earth Shock and Frost Shock respectively by 10%."},{8,51856,"Your Stormstrike and Lightning Strike spells have a chance to energize you with the power of the elements, resetting the cooldown of your Shock spells."}}}
C[672]={name="Earthshatterer's Garb",classMask=64,items={{47174,"Earthshatter Bindings",4,64},{47172,"Earthshatter Epaulets",4,64},{47175,"Earthshatter Gauntlets",4,64},{47178,"Earthshatter Greaves",4,64},{47171,"Earthshatter Helmet",4,64},{47177,"Earthshatter Legplates",4,64},{47173,"Earthshatter Raiments",4,64},{47176,"Earthshatter Sash",4,64},{47179,"Loop of the Earthshatterer",4,64}},bonuses={{2,46113,"Molten Blast's cast time is reduced by 0.2 sec."},{4,51886,"Improves your chance to hit with spells by 3%."},{6,51887,"Reduce the time between Searing Totem and Magma Totem's attacks by 0.4 seconds."},{8,46112,"Earthquake causes your next Earth Shock within 8 sec to cause 125 to 185 additional damage to targets in a yards radius."}}}
C[673]={name="Armor of Might",classMask=1,items={{47243,"Bindings of Might",4,1},{47247,"Boots of Might",4,1},{47242,"Chestplate of Might",4,1},{47240,"Crown of Might",4,1},{47245,"Girdle of Might",4,1},{47244,"Gloves of Might",4,1},{47246,"Leggings of Might",4,1},{47241,"Spaulders of Might",4,1}},bonuses={{3,51899,"Whenever you hit with an ability, you have a chance to gain 15 Rage."},{5,53200,"Your Bloodthirst and Mortal Strike abilities cost -10 less Rage."},{8,52401,"Increases your Critical Strike chance by 2% when in Berserker Stance."}}}
C[674]={name="Armor of Wrath",classMask=1,items={{47251,"Bindings of Wrath",4,1},{47255,"Boots of Wrath",4,1},{1981142,"Boots of Wrath",4,1},{47250,"Chestplate of Wrath",4,1},{47248,"Crown of Wrath",4,1},{47253,"Girdle of Wrath",4,1},{47252,"Gloves of Wrath",4,1},{47254,"Leggings of Wrath",4,1},{47249,"Spaulders of Wrath",4,1}},bonuses={{3,53203,"Your Overpower ability now increases your attack speed by 15% for 5 sec."},{5,52322,"+5 to All Weapons"},{8,53204,"Whirlwind now hits 2 additional targets."}}}
C[676]={name="Armor of the Dreadnought",classMask=1,items={{47264,"Dreadnaught Bindings",4,1},{47268,"Dreadnaught Boots",4,1},{47263,"Dreadnaught Chestplate",4,1},{47261,"Dreadnaught Crown",4,1},{47266,"Dreadnaught Girdle",4,1},{47265,"Dreadnaught Gloves",4,1},{47267,"Dreadnaught Leggings",4,1},{47262,"Dreadnaught Spaulders",4,1},{47269,"Signet of the Dreadnaught",4,1}},bonuses={{2,53206,"Your Sweeping Strikes and Death Wish abilities cost -10 less Rage."},{4,53207,"Increases the critical strike damage bonus of your abilities by 4%"},{6,53205,"Reduces the threat generated by Heroic Strike and Slam by -30%"},{8,53208,"Your melee critical strikes cause you to shout a rallying cry, increasing the physical damage of your party members' next attack by 30."}}}
C[677]={name="Felheart Attire",classMask=256,items={{47279,"Felheart Bindings",4,256},{47283,"Felheart Boots",4,256},{47276,"Felheart Crown",4,256},{47280,"Felheart Handwraps",4,256},{47282,"Felheart Leggings",4,256},{47277,"Felheart Mantle",4,256},{47278,"Felheart Raiments",4,256},{47281,"Felheart Sash",4,256}},bonuses={{3,52599,"Increases the damage dealt by Drain Soul by 5%."},{5,52609,"Damage from your periodic spells and effects has a chance to instantly deal 50 Shadow damage."},{8,52611,"The periodic damage of your Curse of Agony has a chance to increase casting speed by 10% for 6 sec."}}}
C[678]={name="Nemesis Attire",classMask=256,items={{47287,"Nemesis Bindings",4,256},{47291,"Nemesis Boots",4,256},{47284,"Nemesis Crown",4,256},{47288,"Nemesis Handwraps",4,256},{47290,"Nemesis Leggings",4,256},{47285,"Nemesis Mantle",4,256},{47286,"Nemesis Raiments",4,256},{47289,"Nemesis Sash",4,256}},bonuses={{3,52600,"Increases the range of Drain Life, Drain Mana and Drain Soul spells by 10%."},{5,52601,"Increases the duration of Corruption and Siphon Life spells by 3 sec."},{8,52626,"Damage from your Drain Soul has a chance to increase the damage of your next Corruption spell by 15%."}}}
C[679]={name="Doomcaller's Attire",classMask=256,items={{47292,"Doomcaller's Crown",4,256},{1784245,"Doomcaller's Crown",4,256},{47295,"Doomcaller's Leggings",4,256},{1784248,"Doomcaller's Leggings",4,256},{47294,"Doomcaller's Raiments",4,256},{1784242,"Doomcaller's Raiments",4,256},{47296,"Doomcaller's Slippers",4,256},{47293,"Doomcaller's Spaulders",4,256},{1784244,"Doomcaller's Spaulders",4,256}},bonuses={{3,52655,"Increases the damage done by your Curse of Agony spell by 5%."},{5,52656,"The last tick of your Dark Harvest spell deals 400% damage. If your target dies while under the effect of your Dark Harvest, there is a chance a Doomguard will be summoned."}}}
C[680]={name="Plagueheart Attire",classMask=256,items={{47300,"Plagueheart Bindings",4,256},{47304,"Plagueheart Boots",4,256},{47297,"Plagueheart Crown",4,256},{47301,"Plagueheart Handwraps",4,256},{47303,"Plagueheart Leggings",4,256},{47298,"Plagueheart Mantle",4,256},{47299,"Plagueheart Raiments",4,256},{47302,"Plagueheart Sash",4,256},{1784249,"Plagueheart Sash",4,256},{47305,"Plagueheart Signet",4,256}},bonuses={{2,52607,"Whenever you use Life Tap, the mana cost of your next spell cast within 10 sec is reduced by -10%."},{4,52606,"Your Curse of Agony deals 100% increased damage for the first 4."},{6,52604,"Reduces the cooldown of your Dark Harvest by -5 sec."},{8,52620,"The periodic damage of your Corruption has a chance to inflict the enemy with a devastating plague, increasing their chance to be critically struck by spells by 2% and draining health over 6 sec."}}}
C[681]={name="Raiment of the Talon",classMask=1024,items={{47395,"Amulet of the Talon",4,1024},{47394,"Boots of the Talon",4,1024},{47390,"Helm of the Talon",4,1024},{47393,"Leggings of the Talon",4,1024},{1901787,"Leggings of the Talon",4,1024},{47391,"Spaulders of the Talon",4,1024},{1696579,"Spaulders of the Talon",4,1024},{47392,"Vestments of the Talon",4,1024}},bonuses={{3,52346,"Reduces the cooldown of Swiftmend by -3 seconds."},{5,52349,"Your Swiftmend empowers the target, additionally healing them for 240 health each time they take direct damage, up to times."}}}
C[682]={name="Regalia of the Talon",classMask=1024,items={{47396,"Circlet of the Talon",4,1024},{47397,"Mantle of the Talon",4,1024},{47401,"Pendant of the Talon",4,1024},{47400,"Slippers of the Talon",4,1024},{47399,"Trousers of the Talon",4,1024},{47398,"Vest of the Talon",4,1024}},bonuses={{3,52341,"Your Hurricane now cuts your enemies with razor sharp winds, dealing 50% of its total damage as Nature damage over 10 sec."},{5,52342,"Increases the bonuses provided by Balance of All Things by 50%."}}}
C[683]={name="Harness of the Talon",classMask=1024,items={{47407,"Choker of the Talon",4,1024},{47402,"Helmet of the Talon",4,1024},{47405,"Pants of the Talon",4,1024},{47404,"Raiments of the Talon",4,1024},{47403,"Shoulderpads of the Talon",4,1024},{47406,"Treads of the Talon",4,1024}},bonuses={{3,52368,"Damage from your Claw, Rake and Shred abilities has a chance to increase your Attack Power by 100 for 10 sec."},{5,52372,"Spending combo points grants a stack of Primal Ferocity per combo point spent. Upon reaching stacks, all stacks are consumed, increasing your Attack Power by 25% and granting 3 Energy each time you attack for 10 sec."}}}
C[684]={name="Regalia of the Guardian",classMask=128,items={{47112,"Boots of the Guardian",4,128},{47108,"Crown of the Guardian",4,128},{47111,"Leggings of the Guardian",4,128},{47109,"Mantle of the Guardian",4,128},{47113,"Pendant of the Guardian",4,128},{47110,"Robes of the Guardian",4,128}},bonuses={{3,52596,"Initial hits from Flamestrike, Cone of Cold, Frost Nova, Blast Wave, and Arcane Explosion have a chance to trigger a rewind effect. On rewind, Arcane spells deal 10% additional damage, and Frost and Fire spells deal 20% additional damage."},{5,52584,"Your spell critical strikes conjure a magical barrier that absorbs 350 damage. While the barrier holds, the damage you deal with magical spells and effects is increased by up to 42 and the threat you generate is reduced by -15%."}}}
C[685]={name="Vestments of the Guardian",classMask=128,items={{47119,"Amulet of the Guardian",4,128},{47114,"Circlet of the Guardian",4,128},{47115,"Epaulets of the Guardian",4,128},{47118,"Slippers of the Guardian",4,128},{47117,"Trousers of the Guardian",4,128},{47116,"Vestments of the Guardian",4,128}},bonuses={{3,52598,"Increases the chance for Resonance Cascade to trigger by 5%."},{5,52566,"Reduce the mana cost of your spells by -100% for 6 sec after Presence of Mind is consumed."}}}
C[686]={name="Vestments of Pestilence",classMask=16,items={{47233,"Amulet of Pestilence",4,16},{47232,"Boots of Pestilence",4,16},{1980518,"Boots of Pestilence",4,16},{47228,"Crown of Pestilence",4,16},{47231,"Leggings of Pestilence",4,16},{47229,"Mantle of Pestilence",4,16},{1892919,"Mantle of Pestilence",4,16},{47230,"Robes of Pestilence",4,16}},bonuses={{3,41358,"Each tick of your Renew spell has a chance to refund 15% of its mana cost."},{5,41360,"Casting Flash Heal reduces the mana cost of Flash Heal by -3% for 8 sec. Stacks up to 5 times."}}}
C[687]={name="Regalia of Pestilence",classMask=16,items={{47234,"Coronet of Pestilence",4,16},{47237,"Pants of Pestilence",4,16},{47239,"Pendant of Pestilence",4,16},{47236,"Raiments of Pestilence",4,16},{47238,"Sandals of Pestilence",4,16},{47235,"Shoulderpads of Pestilence",4,16}},bonuses={{3,51785,"Your Fade increases your Shadow damage done by 15% for 10 sec."},{5,51795,"Mind Flay and Mind Blast have a chance to inject a deadly pestilence into the target, dealing Shadow damage over 8 sec. Stacks up to times."}}}
C[688]={name="Stormhowl Battlegear",classMask=64,items={{47185,"Choker of the Stormhowl",4,64},{47182,"Stormhowl Breastplate",4,64},{47180,"Stormhowl Crown",4,64},{47183,"Stormhowl Leggings",4,64},{47181,"Stormhowl Pauldrons",4,64},{47184,"Stormhowl Sabatons",4,64}},bonuses={{3,41197,"Your melee attacks, Stormstrike and Lightning Strike have a chance to trigger an empowered version of your active shield without expending a charge."},{5,41196,"Your normal melee swings have a chance to grant you Stormwolf's Frenzy, increasing your attack speed by 10% and your Strength by 5% for 12 sec."}}}
C[689]={name="Stormhowl Garb",classMask=64,items={{47191,"Pendant of the Stormhowl",4,64},{47187,"Stormhowl Epaulets",4,64},{47190,"Stormhowl Greaves",4,64},{47186,"Stormhowl Helmet",4,64},{47189,"Stormhowl Legplates",4,64},{47188,"Stormhowl Raiments",4,64}},bonuses={{3,46762,"Increase the mana-cost reduction of Clearcasting to 70%."},{5,51891,"Elemental Mastery infuses you with the Stormwolf's Cunning, increasing your casting speed by 10% for 12 sec. This effect is refreshed when you critically hit an enemy with a nature spell."}}}
C[690]={name="The Stormhowl",classMask=64,items={{47197,"Amulet of the Stormhowl",4,64},{47196,"Stormhowl Boots",4,64},{47192,"Stormhowl Headpiece",4,64},{47195,"Stormhowl Legguards",4,64},{47193,"Stormhowl Spaulders",4,64},{47194,"Stormhowl Tunic",4,64}},bonuses={{3,41199,"Increases the effectiveness of Healing Stream Totem and Mana Spring Totem by 20% and reduces their periodic timer by -15%."},{5,41198,"Increases the critical strike chance of your healing spells on targets affected by Healing Way by 3% per stack."}}}
C[691]={name="Battlegear of the Brotherhood",classMask=1,items={{47272,"Chestguard of the Brotherhood",4,1},{47275,"Choker of the Brotherhood",4,1},{47274,"Greaves of the Brotherhood",4,1},{47270,"Helmet of the Brotherhood",4,1},{47273,"Legguards of the Brotherhood",4,1},{47271,"Shoulderguards of the Brotherhood",4,1}},bonuses={{3,41361,"Reduces the rage cost of Sunder Armor, Whirlwind and Heroic Strike by -5."},{5,41363,"Shield Wall, Recklessness and Retaliation inspire your group, granting unique benefits during their duration depending on the ability used."}}}
C[692]={name="Lionheart Armor",classMask=2,items={{47065,"Lionheart Amulet",4,2},{47064,"Lionheart Boots",4,2},{47062,"Lionheart Breastplate",4,2},{47060,"Lionheart Headpiece",4,2},{47063,"Lionheart Legplates",4,2},{47061,"Lionheart Spaulders",4,2}},bonuses={{3,51826,"Increases the amount healed by your Holy Shock by 192."},{5,46000,"Increases healing of your Holy Strike by 10%."}}}
C[693]={name="Lionheart Battleplate",classMask=2,items={{47068,"Lionheart Chestguard",4,2},{1983149,"Lionheart Chestguard",4,2},{47070,"Lionheart Greaves",4,2},{47066,"Lionheart Helmet",4,2},{47069,"Lionheart Legguards",4,2},{47071,"Lionheart Pendant",4,2},{47067,"Lionheart Shoulderguards",4,2}},bonuses={{3,51836,"Increases the block value of your shield by 67 and threat generated by Holy Shield by 40%."},{5,51813,"Reduces damage taken from all sources by -3%."}}}
C[694]={name="Lionheart Battlegear",classMask=2,items={{47074,"Lionheart Chestplate",4,2},{47077,"Lionheart Choker",4,2},{47072,"Lionheart Crown",4,2},{1918162,"Lionheart Crown",4,2},{47075,"Lionheart Leggings",4,2},{47073,"Lionheart Pauldrons",4,2},{1983148,"Lionheart Pauldrons",4,2},{47076,"Lionheart Sabatons",4,2},{1983152,"Lionheart Sabatons",4,2}},bonuses={{3,51832,"Your Holy Might increases your Strength by an additional 6%."},{5,51834,"Your melee attacks and abilities have a chance to begin a Crusade, increasing the attack speed of your party members by 4% for 20 sec."}}}
C[695]={name="Nathrezim Attire",classMask=256,items={{47311,"Nathrezim Amulet",4,256},{47310,"Nathrezim Boots",4,256},{47306,"Nathrezim Crown",4,256},{47309,"Nathrezim Leggings",4,256},{47307,"Nathrezim Mantle",4,256},{47308,"Nathrezim Raiments",4,256}},bonuses={{3,52628,"Increases the health drained by Siphon Life by 25%. In addition, you gain 25% of the health drained as mana and attempt to drain that mana directly from the target."},{5,52613,"Damage from your periodic spells and effects has a chance to grant Ruination, increasing your casting speed by 5% and your damage done by Shadow spells and effects by up to 45 for 8 sec."}}}
C[696]={name="Nathrezim Raiment",classMask=256,items={{47315,"Nathrezim Pants",4,256},{47317,"Nathrezim Pendant",4,256},{47314,"Nathrezim Robes",4,256},{47312,"Nathrezim Skullcap",4,256},{47316,"Nathrezim Slippers",4,256},{47313,"Nathrezim Spaulders",4,256}},bonuses={{3,52624,"Increases the critical strike damage bonus of your Shadow Bolt and Searing Pain spells by 10% and the critical strike damage bonus of your controlled demon's attacks, abilities and spells by 10%."},{5,52630,"Dealing direct Shadow and Fire damage has a chance to coat the enemy in Felfire, dealing 45 Shadow and 45 Fire damage every second for 6 sec. While burning, Shadow and Fire damage taken is increased by 3%."}}}
C[697]={name="Ravenstalker Armor",classMask=4,items={{47322,"Ravenstalker Boots",4,4},{47323,"Ravenstalker Choker",4,4},{47318,"Ravenstalker Headpiece",4,4},{47321,"Ravenstalker Legguards",4,4},{47319,"Ravenstalker Spaulders",4,4},{47320,"Ravenstalker Tunic",4,4}},bonuses={{3,52602,"Reduces the cooldown of Multi-Shot and Carve by -1 sec."},{5,52603,"Increases the attack speed provided by Swift Aspects by an additional 5%."}}}
C[698]={name="Trickster Armor",classMask=8,items={{47326,"Trickster Breastplate",4,8},{47329,"Trickster Choker",4,8},{47324,"Trickster Helmet",4,8},{47327,"Trickster Leggings",4,8},{47325,"Trickster Pauldrons",4,8},{47328,"Trickster Sabatons",4,8}},bonuses={{3,52562,"Your opening moves have a 100% chance and your finishing moves have a chance per combo point to increase your attack speed by 10% for 6 sec."},{5,52564,"Sinister Strike, Backstab, Noxious Assault, and Hemorrhage have a 20% chance to veil you in shadows, catching your enemy off guard. The next ability you use to generate combo points restores 20 Energy and grants 1 additional combo if used within 6 sec."}}}
C[699]={name="Dragonmaw Battlegarb",classMask=0,items={{58113,"Dragonmaw Bracers",2,-1},{58115,"Dragonmaw Greaves",2,-1},{58114,"Dragonmaw Leggings",2,-1},{41724,"Dragonmaw Shoulders",3,-1},{58112,"Dragonmaw Gloves",3,-1},{58111,"Dragonmaw Hauberk",2,-1},{58099,"Dragonmaw Helmet",3,-1}},bonuses={{2,15464,"Improves your chance to hit by 1%."},{4,13198,"+15 Strength."},{6,44035,"Your successful melee attacks have a 5% chance to breathe flames at your enemy, dealing 45 to 55 Fire damage and an additional Fire damage over 6 sec."}}}
C[700]={name="Stormreaver Attire",classMask=0,items={{58131,"Stormreaver Belt",2,-1},{58134,"Stormreaver Gloves",3,-1},{58147,"Stormreaver Mantle",3,-1},{58178,"Stormreaver Boots",2,-1},{58176,"Stormreaver Hood",2,-1},{58177,"Stormreaver Robe",3,-1}},bonuses={{2,23727,"Improves your chance to hit with spells by 1%."},{4,9346,"Increases damage and healing done by magical spells and effects by up to 18."},{6,44081,"Your landing damaging spells have a 5% chance to curse the enemy with Impending Doom, which arrives after 5 sec and deals 103 to 132 Shadow damage. Dealing Shadow damage to the target causes the Doom to arrive instantly and deal 20% more damage."}}}
C[701]={name="Arms of Thaurissan",classMask=0,items={{11684,"Ironfoe",4,-1},{58214,"Modrag'zan, Heart of the Mountain",4,-1}},bonuses={{2,49368,"Your extra attacks increase your attack speed by 10% for 6 sec."}}}
C[702]={name="Sacred Windhorn Attire",classMask=0,items={{33021,"Sacred Windhorn Gloves",2,-1},{33026,"Sacred Windhorn Shoulders",2,-1},{33029,"Sacred Windhorn Footwraps",3,-1},{33035,"Sacred Windhorn Pants",3,-1},{33037,"Sacred Windhorn Robe",3,-1},{33042,"Sacred Windhorn Headdress",3,-1}},bonuses={{2,7499,"+5 Spirit."},{4,57159,"Allows 10% of your Mana regeneration to continue while casting."},{6,52860,"Your direct healing spells have a chance to envelop the target in gentle winds, healing for 325 to 379 and increasing movement speed by 15% for 8 sec."},{6,52862,"Your landing damaging spells have a chance to envelop the target in harsh winds, dealing 175 to 199 Nature damage and reducing the movement speed of enemies around the target within yards by -25% for 8 sec."}}}
C[703]={name="Attire of Prophecy",classMask=16,items={{33003,"Bindings of Prophecy",4,16},{33005,"Cord of Prophecy",4,16},{33000,"Crown of Prophecy",4,16},{33001,"Epaulets of Prophecy",4,16},{33004,"Handwraps of Prophecy",4,16},{33006,"Leggings of Prophecy",4,16},{33007,"Slippers of Prophecy",4,16},{33002,"Vestments of Prophecy",4,16}},bonuses={{3,52881,"Reduces the mana cost of Holy and Discipline spells by -15%."},{5,52880,"Inner Fire gains 10 additional charges and grants an extra 35 spell damage and armor."},{8,52882,"Successful Smite hits have a chance to consume a charge of Inner Fire, castigating the target and burning them for Holy damage over 15 sec."}}}
C[704]={name="Attire of Transcendence",classMask=16,items={{33013,"Cord of Transcendence",4,16},{33008,"Crown of Transcendence",4,16},{33009,"Epaulets of Transcendence",4,16},{33012,"Handwraps of Transcendence",4,16},{33015,"Slippers of Transcendence",4,16},{33014,"Trousers of Transcendence",4,16},{33010,"Vestments of Transcendence",4,16},{33011,"Wristbands of Transcendence",4,16}},bonuses={{3,52884,"Power Word: Shield increases the target's movement speed by 10% for 4 sec."},{5,52886,"Your instant Smite casts increase the casting speed of your next Smite within 6 sec by -10% and reduce its mana cost by -25%."},{8,52888,"Increases the duration of the benefit granted by Enlighten 4 sec."}}}
C[705]={name="Attire of Faith",classMask=16,items={{33167,"Cord of Faith",4,16},{33162,"Crown of Faith",4,16},{33163,"Epaulets of Faith",4,16},{33166,"Handwraps of Faith",4,16},{33170,"Signet of Faith",4,16},{33169,"Slippers of Faith",4,16},{33168,"Trousers of Faith",4,16},{33164,"Vestments of Faith",4,16},{33165,"Wristbands of Faith",4,16}},bonuses={{2,52889,"Reduces the time between periodic ticks of Holy Fire by -50%."},{4,52938,"Damage caused by Holy Fire increases the damage of your next Holy Fire or Holy Nova by 4% for 15 sec, stacking up to times."},{6,52941,"Resurgent Shield causes your Power Word: Shield to grant 5 stacks of Blessed Wildfire and activate Resurgent Shield. This effect can only occur once every 15 sec."},{8,52940,"Reduces Chastise's cooldown by -20% and grants 10 stacks of Blessed Wildfire when cast."}}}
C[706]={name="Attire of Pestilence",classMask=16,items={{33176,"Choker of Pestilence",4,16},{33171,"Crown of Pestilence",4,16},{33172,"Epaulets of Pestilence",4,16},{33175,"Slippers of Pestilence",4,16},{33174,"Trousers of Pestilence",4,16},{33173,"Vestments of Pestilence",4,16}},bonuses={{3,52977,"Casting Lightwell grants Light Infusion, giving Smite, Holy Fire, and Chastise a chance to increase your party's attack and casting speed by 5% for 8 sec. Lasts 30 sec."},{5,52981,"Casting Holy Fire on a target afflicted by your Shadow Word: Pain (Rank 8) converts it into Burning Zeal, dealing Holy damage over 18 sec and increasing Holy damage taken by 2%."}}}
C[707]={name="Regalia of the Oracle",classMask=16,items={{33016,"Crown of the Oracle",4,16},{33019,"Leggings of the Oracle",4,16},{33018,"Robes of the Oracle",4,16},{33020,"Sandals of the Oracle",4,16},{33017,"Shoulderpads of the Oracle",4,16}},bonuses={{3,52895,"Vampiric Embrace deals Shadow damage over 60 sec, healing you for 50% of each damage dealt."},{5,52897,"Mind Blast and Pain Spike critical strikes increase the damage of your next Mind Flay within 6 sec by 25%."}}}
C[708]={name="Majesty of the Stag",classMask=0,items={{33381,"Burden of the Stag",4,-1},{33382,"Embrace of the Stag",4,-1},{33383,"Grasp of the Stag",4,-1},{33380,"Guile of the Stag",4,-1},{33385,"Path of the Stag",4,-1},{33384,"Vigor of the Stag",4,-1}},bonuses={{3,58167,"Your harmful spell critical strikes have a chance to restore 3% of your base mana and health."},{5,58165,"Your harmful direct spell damage increases your spell critical strike chance by 2% until your next spell critical strike."}}}
C[709]={name="Rage of the Ursa",classMask=0,items={{33387,"Burden of the Ursa",4,-1},{33388,"Embrace of the Ursa",4,-1},{33389,"Grasp of the Ursa",4,-1},{33386,"Guile of the Ursa",4,-1},{33391,"Path of the Ursa",4,-1},{33390,"Vigor of the Ursa",4,-1}},bonuses={{3,58156,"Your successful melee attacks have a chance to restore 2 Rage, 4 Energy, or 30 Mana."},{5,58158,"Your melee critical strikes grant a stack of Brooding Rage. At stacks, you bellow a mighty roar, increasing physical damage done by 25 and Strength by 25 for 10 sec."}}}
C[710]={name="Might of the Hippogryph",classMask=0,items={{33393,"Burden of the Hippogryph",4,-1},{33394,"Embrace of the Hippogryph",4,-1},{33395,"Grasp of the Hippogryph",4,-1},{33392,"Guile of the Hippogryph",4,-1},{33397,"Path of the Hippogryph",4,-1},{33396,"Vigor of the Hippogryph",4,-1}},bonuses={{3,58169,"Your melee and ranged attacks have a chance to increase your attack speed by 20% and cause your attacks to deal 150 Nature damage. Lasts 8 sec or until you attack times."},{5,58153,"Your melee and ranged critical strikes have a chance to call forth a Hippogryph Spirit to fight alongside you for -0.0 sec. While present, it increases your physical critical damage bonus by 10% and Agility by 10%."}}}
C[711]={name="Coil of the Hydra",classMask=0,items={{33367,"Hydracoil Gauntlets",3,-1},{33368,"Hydracoil Spaulders",3,-1},{33366,"Hydracoil Trousers",3,-1},{33205,"Skull of Larnaea",3,-1}},bonuses={{2,52929,"Reduces the mana cost of Fire, Nature, and Frost spells by -4%."},{3,52930,"Your critical strikes with spells increase damage done by your Fire, Nature, and Frost spells by up to 75 for 6 sec."},{4,52932,"Dealing direct damage with Fire, Nature, or Frost spells has a chance to blast the target with a tricolored spell, causing 100 Fire, Nature, and Frost damage simultaneously."}}}
C[712]={name="Pride of the Moose",classMask=0,items={{33399,"Burden of the Moose",4,-1},{33400,"Embrace of the Moose",4,-1},{33401,"Grasp of the Moose",4,-1},{33398,"Guile of the Moose",4,-1},{33403,"Path of the Moose",4,-1},{33402,"Vigor of the Moose",4,-1}},bonuses={{3,58150,"Blocking, dodging, or parrying an attack increases your Stamina by 10 and your Defense by 5 for 15 sec, stacking up to times."},{5,58148,"Taking damage has a chance to increase your armor by 1000 and healing taken by 15% for 10 sec."}}}
C[713]={name="Combatant's Battlegear",classMask=1,items={{33406,"Combatant's Plate Armor",3,1},{33409,"Combatant's Plate Boots",3,1},{33407,"Combatant's Plate Gauntlets",3,1},{33404,"Combatant's Plate Helm",3,1},{33408,"Combatant's Plate Legguards",3,1},{33405,"Combatant's Plate Shoulderguards",3,1}},bonuses={{2,22778,"Hamstring Rage cost reduced by -3."},{4,22738,"Reduces the cooldown of your Intercept and Intervene abilities by -5 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[714]={name="Partisan's Battlegear",classMask=1,items={{33412,"Partisan's Plate Armor",4,1},{33415,"Partisan's Plate Boots",4,1},{33413,"Partisan's Plate Gauntlets",4,1},{33410,"Partisan's Plate Helm",4,1},{33414,"Partisan's Plate Legguards",4,1},{33411,"Partisan's Plate Shoulderguards",4,1}},bonuses={{2,22778,"Hamstring Rage cost reduced by -3."},{4,22738,"Reduces the cooldown of your Intercept and Intervene abilities by -5 sec."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[715]={name="Veteran's Battlegear",classMask=0,items={},bonuses={{2,22778,"Hamstring Rage cost reduced by -3."},{4,22738,"Reduces the cooldown of your Intercept and Intervene abilities by -5 sec."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[716]={name="Tactician's Arcanum",classMask=128,items={{33422,"Tactician's Coronet",3,128},{33427,"Tactician's Silk Footwraps",3,128},{33425,"Tactician's Silk Gloves",3,128},{33426,"Tactician's Silk Leggings",3,128},{33423,"Tactician's Silk Spaulders",3,128},{33424,"Tactician's Silk Vestments",3,128}},bonuses={{2,23037,"Increases the damage absorbed by your Mana Shield by 285."},{4,23025,"Reduces the cooldown of your Blink spell by -2 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[717]={name="Strategist's Arcanum",classMask=128,items={{33428,"Strategist's Coronet",4,128},{33433,"Strategist's Silk Footwraps",4,128},{33431,"Strategist's Silk Gloves",4,128},{33432,"Strategist's Silk Leggings",4,128},{33429,"Strategist's Silk Spaulders",4,128},{33430,"Strategist's Silk Vestments",4,128}},bonuses={{2,23037,"Increases the damage absorbed by your Mana Shield by 285."},{4,23025,"Reduces the cooldown of your Blink spell by -2 sec."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[718]={name="Executor's Arcanum",classMask=0,items={},bonuses={{2,23037,"Increases the damage absorbed by your Mana Shield by 285."},{4,23025,"Reduces the cooldown of your Blink spell by -2 sec."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[719]={name="Combatant's Pursuit",classMask=4,items={{33445,"Combatant's Chain Boots",3,4},{33442,"Combatant's Chain Breastplate",3,4},{33443,"Combatant's Chain Grips",3,4},{33440,"Combatant's Chain Helm",3,4},{33444,"Combatant's Chain Legguards",3,4},{33441,"Combatant's Chain Spaulders",3,4}},bonuses={{2,28539,"Increases the damage done by your Multi-Shot and Carve by 4%."},{4,23158,"Reduces the cooldown of Concussive Shot by -1 sec and Wing Clip by 0 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[720]={name="Partisan's Pursuit",classMask=4,items={{33451,"Partisan's Chain Boots",4,4},{33448,"Partisan's Chain Breastplate",4,4},{33449,"Partisan's Chain Grips",4,4},{33446,"Partisan's Chain Helm",4,4},{33450,"Partisan's Chain Legguards",4,4},{33447,"Partisan's Chain Spaulders",4,4}},bonuses={{2,28539,"Increases the damage done by your Multi-Shot and Carve by 4%."},{4,23158,"Reduces the cooldown of Concussive Shot by -1 sec and Wing Clip by 0 sec."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[721]={name="Veteran's Pursuit",classMask=0,items={},bonuses={{2,28539,"Increases the damage done by your Multi-Shot and Carve by 4%."},{4,23158,"Reduces the cooldown of Concussive Shot by -1 sec and Wing Clip by 0 sec."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[722]={name="Tactician's Threads",classMask=256,items={{33458,"Tactician's Coronal",3,256},{33463,"Tactician's Dreadweave Boots",3,256},{33461,"Tactician's Dreadweave Gloves",3,256},{33462,"Tactician's Dreadweave Leggings",3,256},{33460,"Tactician's Dreadweave Robe",3,256},{33459,"Tactician's Dreadweave Shoulders",3,256}},bonuses={{2,23047,"Reduces the casting time of your Immolate spell by 0.2 sec."},{4,23046,"Gives a 30% chance to avoid interruption caused by damage while casting Searing Pain, Shadow Bolt, and Drain Soul."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[723]={name="Strategist's Threads",classMask=256,items={{33464,"Strategist's Coronal",4,256},{33469,"Strategist's Dreadweave Boots",4,256},{33467,"Strategist's Dreadweave Gloves",4,256},{33468,"Strategist's Dreadweave Leggings",4,256},{33466,"Strategist's Dreadweave Robe",4,256},{33465,"Strategist's Dreadweave Shoulders",4,256}},bonuses={{2,23047,"Reduces the casting time of your Immolate spell by 0.2 sec."},{4,23046,"Gives a 30% chance to avoid interruption caused by damage while casting Searing Pain, Shadow Bolt, and Drain Soul."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[724]={name="Executor's Threads",classMask=0,items={},bonuses={{2,23047,"Reduces the casting time of your Immolate spell by 0.2 sec."},{4,23046,"Gives a 30% chance to avoid interruption caused by damage while casting Searing Pain, Shadow Bolt, and Drain Soul."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[725]={name="Combatant's Earthshaker",classMask=64,items={{33478,"Combatant's Mail Armor",3,64},{33481,"Combatant's Mail Boots",3,64},{33479,"Combatant's Mail Gauntlets",3,64},{33476,"Combatant's Mail Helm",3,64},{33480,"Combatant's Mail Leggings",3,64},{33477,"Combatant's Mail Spaulders",3,64}},bonuses={{2,22804,"Improves your chance to get a critical strike with all Shock spells by 2%."},{4,22801,"Increases the speed of your Ghost Wolf ability by 15%."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[726]={name="Partisan's Earthshaker",classMask=64,items={{33484,"Partisan's Mail Armor",4,64},{33487,"Partisan's Mail Boots",4,64},{33485,"Partisan's Mail Gauntlets",4,64},{33482,"Partisan's Mail Helm",4,64},{33486,"Partisan's Mail Leggings",4,64},{33483,"Partisan's Mail Spaulders",4,64}},bonuses={{2,22804,"Improves your chance to get a critical strike with all Shock spells by 2%."},{4,22801,"Increases the speed of your Ghost Wolf ability by 15%."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[727]={name="Veteran''s Earthshaker",classMask=0,items={},bonuses={{2,22804,"Improves your chance to get a critical strike with all Shock spells by 2%."},{4,22801,"Increases the speed of your Ghost Wolf ability by 15%."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[728]={name="Tactician's Earthshaker",classMask=64,items={{33496,"Tactician's Mail Armor",3,64},{33499,"Tactician's Mail Boots",3,64},{33497,"Tactician's Mail Gauntlets",3,64},{33494,"Tactician's Mail Helm",3,64},{33498,"Tactician's Mail Leggings",3,64},{33495,"Tactician's Mail Spaulders",3,64}},bonuses={{2,22804,"Improves your chance to get a critical strike with all Shock spells by 2%."},{4,22801,"Increases the speed of your Ghost Wolf ability by 15%."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[729]={name="Strategist's Earthshaker",classMask=64,items={{33502,"Strategist's Mail Armor",4,64},{33505,"Strategist's Mail Boots",4,64},{33503,"Strategist's Mail Gauntlets",4,64},{33500,"Strategist's Mail Helm",4,64},{33504,"Strategist's Mail Leggings",4,64},{33501,"Strategist's Mail Spaulders",4,64}},bonuses={{2,22804,"Improves your chance to get a critical strike with all Shock spells by 2%."},{4,22801,"Increases the speed of your Ghost Wolf ability by 15%."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[730]={name="Executor's Earthshaker",classMask=0,items={},bonuses={{2,22804,"Improves your chance to get a critical strike with all Shock spells by 2%."},{4,22801,"Increases the speed of your Ghost Wolf ability by 15%."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[731]={name="Corpsman's Earthshaker",classMask=64,items={{33514,"Corpsman's Mail Armor",3,64},{33517,"Corpsman's Mail Boots",3,64},{33515,"Corpsman's Mail Gauntlets",3,64},{33512,"Corpsman's Mail Helm",3,64},{33516,"Corpsman's Mail Leggings",3,64},{33513,"Corpsman's Mail Spaulders",3,64}},bonuses={{2,22804,"Improves your chance to get a critical strike with all Shock spells by 2%."},{4,22801,"Increases the speed of your Ghost Wolf ability by 15%."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[732]={name="Physician's Earthshaker",classMask=64,items={{33520,"Physician's Mail Armor",4,64},{33523,"Physician's Mail Boots",4,64},{33521,"Physician's Mail Gauntlets",4,64},{33518,"Physician's Mail Helm",4,64},{33522,"Physician's Mail Leggings",4,64},{33519,"Physician's Mail Spaulders",4,64}},bonuses={{2,22804,"Improves your chance to get a critical strike with all Shock spells by 2%."},{4,22801,"Increases the speed of your Ghost Wolf ability by 15%."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[733]={name="Field Medic's Earthshaker",classMask=0,items={},bonuses={{2,22804,"Improves your chance to get a critical strike with all Shock spells by 2%."},{4,22801,"Increases the speed of your Ghost Wolf ability by 15%."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[734]={name="Combatant's Sanctuary",classMask=1024,items={{33535,"Combatant's Dragonhide Boots",3,1024},{33531,"Combatant's Dragonhide Epaulets",3,1024},{33533,"Combatant's Dragonhide Gloves",3,1024},{33532,"Combatant's Dragonhide Hauberk",3,1024},{33530,"Combatant's Dragonhide Helmet",3,1024},{33534,"Combatant's Dragonhide Leggings",3,1024}},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[735]={name="Partisan's Sanctuary",classMask=1024,items={{33541,"Partisan's Dragonhide Boots",4,1024},{33537,"Partisan's Dragonhide Epaulets",4,1024},{33539,"Partisan's Dragonhide Gloves",4,1024},{33538,"Partisan's Dragonhide Hauberk",4,1024},{33536,"Partisan's Dragonhide Helmet",4,1024},{33540,"Partisan's Dragonhide Leggings",4,1024}},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[736]={name="Veteran's Sanctuary",classMask=0,items={},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[737]={name="Tactician's Sanctuary",classMask=1024,items={{33553,"Tactician's Dragonhide Boots",3,1024},{33549,"Tactician's Dragonhide Epaulets",3,1024},{33551,"Tactician's Dragonhide Gloves",3,1024},{33550,"Tactician's Dragonhide Hauberk",3,1024},{33548,"Tactician's Dragonhide Helmet",3,1024},{33552,"Tactician's Dragonhide Leggings",3,1024}},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[738]={name="Strategist's Sanctuary",classMask=1024,items={{33559,"Strategist's Dragonhide Boots",4,1024},{33555,"Strategist's Dragonhide Epaulets",4,1024},{280590,"Strategist's Dragonhide Epaulets",4,1024},{33557,"Strategist's Dragonhide Gloves",4,1024},{280592,"Strategist's Dragonhide Gloves",4,1024},{33556,"Strategist's Dragonhide Hauberk",4,1024},{280591,"Strategist's Dragonhide Hauberk",4,1024},{33554,"Strategist's Dragonhide Helmet",4,1024},{280589,"Strategist's Dragonhide Helmet",4,1024},{33558,"Strategist's Dragonhide Leggings",4,1024}},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[739]={name="Executor's Sanctuary",classMask=0,items={},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[740]={name="Corpsman's Sanctuary",classMask=1024,items={{33571,"Corpsman's Dragonhide Boots",3,1024},{33567,"Corpsman's Dragonhide Epaulets",3,1024},{33569,"Corpsman's Dragonhide Gloves",3,1024},{33568,"Corpsman's Dragonhide Hauberk",3,1024},{33566,"Corpsman's Dragonhide Helmet",3,1024},{33570,"Corpsman's Dragonhide Leggings",3,1024}},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[741]={name="Physician's Sanctuary",classMask=1024,items={{33577,"Physician's Dragonhide Boots",4,1024},{33573,"Physician's Dragonhide Epaulets",4,1024},{33575,"Physician's Dragonhide Gloves",4,1024},{33574,"Physician's Dragonhide Hauberk",4,1024},{33572,"Physician's Dragonhide Helmet",4,1024}},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[742]={name="Field Medic's Sanctuary",classMask=0,items={},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[743]={name="Combatant's Aegis",classMask=2,items={{33589,"Combatant's Lamellar Boots",3,2},{33586,"Combatant's Lamellar Chestplate",3,2},{33584,"Combatant's Lamellar Faceguard",3,2},{33587,"Combatant's Lamellar Gloves",3,2},{33588,"Combatant's Lamellar Legplates",3,2},{33585,"Combatant's Lamellar Pauldrons",3,2}},bonuses={{2,23300,"Increases the Holy damage bonus of your Judgement of the Crusader by 20."},{4,23302,"Reduces the cooldown of your Hammer of Justice by -10 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[744]={name="Partisan's Aegis",classMask=2,items={{33595,"Partisan's Lamellar Boots",4,2},{33592,"Partisan's Lamellar Chestplate",4,2},{33590,"Partisan's Lamellar Faceguard",4,2},{33593,"Partisan's Lamellar Gloves",4,2},{1983154,"Partisan's Lamellar Gloves",4,2},{33594,"Partisan's Lamellar Legplates",4,2},{1983151,"Partisan's Lamellar Legplates",4,2},{33591,"Partisan's Lamellar Pauldrons",4,2}},bonuses={{2,23300,"Increases the Holy damage bonus of your Judgement of the Crusader by 20."},{4,23302,"Reduces the cooldown of your Hammer of Justice by -10 sec."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[745]={name="Veteran's Aegis",classMask=0,items={},bonuses={{2,23300,"Increases the Holy damage bonus of your Judgement of the Crusader by 20."},{4,23302,"Reduces the cooldown of your Hammer of Justice by -10 sec."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[746]={name="Corpsman's Aegis",classMask=2,items={{33607,"Corpsman's Lamellar Boots",3,2},{33604,"Corpsman's Lamellar Chestplate",3,2},{33602,"Corpsman's Lamellar Faceguard",3,2},{33605,"Corpsman's Lamellar Gloves",3,2},{33606,"Corpsman's Lamellar Legplates",3,2},{33603,"Corpsman's Lamellar Pauldrons",3,2}},bonuses={{2,23300,"Increases the Holy damage bonus of your Judgement of the Crusader by 20."},{4,23302,"Reduces the cooldown of your Hammer of Justice by -10 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[747]={name="Physician's Aegis",classMask=2,items={{33613,"Physician's Lamellar Boots",4,2},{33610,"Physician's Lamellar Chestplate",4,2},{33608,"Physician's Lamellar Faceguard",4,2},{33611,"Physician's Lamellar Gloves",4,2},{33612,"Physician's Lamellar Legplates",4,2},{33609,"Physician's Lamellar Pauldrons",4,2}},bonuses={{2,23300,"Increases the Holy damage bonus of your Judgement of the Crusader by 20."},{4,23302,"Reduces the cooldown of your Hammer of Justice by -10 sec."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[748]={name="Field Medic's Aegis",classMask=0,items={},bonuses={{2,23300,"Increases the Holy damage bonus of your Judgement of the Crusader by 20."},{4,23302,"Reduces the cooldown of your Hammer of Justice by -10 sec."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[749]={name="Tactician's Investiture",classMask=16,items={{33620,"Tactician's Headdress",3,16},{33623,"Tactician's Satin Gloves",3,16},{33621,"Tactician's Satin Mantle",3,16},{33624,"Tactician's Satin Pants",3,16},{33625,"Tactician's Satin Sandals",3,16},{33622,"Tactician's Satin Vestments",3,16}},bonuses={{2,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{4,23043,"Gives a 30% chance to avoid interruption caused by damage while casting Mind Blast, Smite, and Flash Heal."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[750]={name="Strategist's Investiture",classMask=16,items={{33626,"Strategist's Headdress",4,16},{33629,"Strategist's Satin Gloves",4,16},{33627,"Strategist's Satin Mantle",4,16},{33630,"Strategist's Satin Pants",4,16},{33631,"Strategist's Satin Sandals",4,16},{33628,"Strategist's Satin Vestments",4,16}},bonuses={{2,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{4,23043,"Gives a 30% chance to avoid interruption caused by damage while casting Mind Blast, Smite, and Flash Heal."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[751]={name="Executor's Investiture",classMask=0,items={},bonuses={{2,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{4,23043,"Gives a 30% chance to avoid interruption caused by damage while casting Mind Blast, Smite, and Flash Heal."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[752]={name="Corpsman's Investiture",classMask=16,items={{33638,"Corpsman's Headdress",3,16},{33641,"Corpsman's Satin Gloves",3,16},{33639,"Corpsman's Satin Mantle",3,16},{33642,"Corpsman's Satin Pants",3,16},{33643,"Corpsman's Satin Sandals",3,16},{33640,"Corpsman's Satin Vestments",3,16}},bonuses={{2,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{4,23043,"Gives a 30% chance to avoid interruption caused by damage while casting Mind Blast, Smite, and Flash Heal."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[753]={name="Physician's Investiture",classMask=16,items={{33644,"Physician's Headdress",4,16},{33647,"Physician's Satin Gloves",4,16},{33645,"Physician's Satin Mantle",4,16},{33648,"Physician's Satin Pants",4,16},{33649,"Physician's Satin Sandals",4,16},{33646,"Physician's Satin Vestments",4,16}},bonuses={{2,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{4,23043,"Gives a 30% chance to avoid interruption caused by damage while casting Mind Blast, Smite, and Flash Heal."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[754]={name="Field Medic's Investiture",classMask=0,items={},bonuses={{2,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{4,23043,"Gives a 30% chance to avoid interruption caused by damage while casting Mind Blast, Smite, and Flash Heal."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[755]={name="Combatant's Cover",classMask=8,items={{33658,"Combatant's Leather Chestpiece",3,8},{33657,"Combatant's Leather Epaulets",3,8},{33661,"Combatant's Leather Footguards",3,8},{33659,"Combatant's Leather Handgrips",3,8},{33660,"Combatant's Leather Leggings",3,8},{33656,"Combatant's Leather Mask",3,8}},bonuses={{2,23048,"Reduces the cooldown of your Gouge ability by -1 sec."},{4,23049,"Increases the duration of your Sprint ability by 3 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[756]={name="Partisan's Cover",classMask=8,items={{33844,"Combatant's Leather Chestpiece",3,8},{33843,"Combatant's Leather Epaulets",3,8},{33847,"Combatant's Leather Footguards",3,8},{33845,"Combatant's Leather Handgrips",3,8},{33846,"Combatant's Leather Leggings",3,8},{33842,"Combatant's Leather Mask",3,8},{33664,"Partisan's Leather Chestpiece",4,8},{33663,"Partisan's Leather Epaulets",4,8},{33667,"Partisan's Leather Footguards",4,8},{33665,"Partisan's Leather Handgrips",4,8},{33666,"Partisan's Leather Leggings",4,8},{33662,"Partisan's Leather Mask",4,8}},bonuses={{2,23048,"Reduces the cooldown of your Gouge ability by -1 sec."},{4,23049,"Increases the duration of your Sprint ability by 3 sec."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[757]={name="Veteran's Cover",classMask=8,items={{33850,"Partisan's Leather Chestpiece",4,8},{33849,"Partisan's Leather Epaulets",4,8},{33853,"Partisan's Leather Footguards",4,8},{33851,"Partisan's Leather Handgrips",4,8},{33852,"Partisan's Leather Leggings",4,8},{33848,"Partisan's Leather Mask",4,8}},bonuses={{2,23048,"Reduces the cooldown of your Gouge ability by -1 sec."},{4,23049,"Increases the duration of your Sprint ability by 3 sec."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[758]={name="Surrender to Madness",classMask=8,items={{33275,"Signet of Howling Nightmares",4,-1},{33269,"Signet of Screaming Nightmares",4,-1},{33859,"Veteran's Leather Footguards",4,8},{33857,"Veteran's Leather Handgrips",4,8},{33858,"Veteran's Leather Leggings",4,8}},bonuses={{2,58122,"Your successful attacks have a chance to grant you 1 extra."}}}
C[759]={name="Wisdom of the Deer",classMask=0,items={{33675,"Burden of the Deer",4,-1},{33676,"Embrace of the Deer",4,-1},{33677,"Grasp of the Deer",4,-1},{33674,"Guile of the Deer",4,-1},{33679,"Path of the Deer",4,-1},{33678,"Vigor of the Deer",4,-1}},bonuses={{3,58163,"Your helpful spells have a chance to imbue you with natural wisdom, allowing 20% of your mana regeneration to continue while casting for 15 sec."},{5,58161,"Your direct healing spells have a chance to revitalize the target, increasing their Strength, Intellect, and Stamina by 30 for 10 sec."}}}
C[760]={name="Combatant's Battlegear",classMask=1,items={{33682,"Combatant's Plate Armor",3,1},{33685,"Combatant's Plate Boots",3,1},{33683,"Combatant's Plate Gauntlets",3,1},{33680,"Combatant's Plate Helm",3,1},{33684,"Combatant's Plate Legguards",3,1},{33681,"Combatant's Plate Shoulderguards",3,1}},bonuses={{2,22778,"Hamstring Rage cost reduced by -3."},{4,22738,"Reduces the cooldown of your Intercept and Intervene abilities by -5 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[761]={name="Partisan's Battlegear",classMask=1,items={{33688,"Partisan's Plate Armor",4,1},{33691,"Partisan's Plate Boots",4,1},{33689,"Partisan's Plate Gauntlets",4,1},{33686,"Partisan's Plate Helm",4,1},{33690,"Partisan's Plate Legguards",4,1},{33687,"Partisan's Plate Shoulderguards",4,1}},bonuses={{2,22778,"Hamstring Rage cost reduced by -3."},{4,22738,"Reduces the cooldown of your Intercept and Intervene abilities by -5 sec."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[762]={name="Veteran's Battlegear",classMask=0,items={},bonuses={{2,22778,"Hamstring Rage cost reduced by -3."},{4,22738,"Reduces the cooldown of your Intercept and Intervene abilities by -5 sec."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[763]={name="Tactician's Arcanum",classMask=128,items={{33698,"Tactician's Coronet",3,128},{33703,"Tactician's Silk Footwraps",3,128},{33701,"Tactician's Silk Gloves",3,128},{33702,"Tactician's Silk Leggings",3,128},{33699,"Tactician's Silk Spaulders",3,128},{33700,"Tactician's Silk Vestments",3,128}},bonuses={{2,23037,"Increases the damage absorbed by your Mana Shield by 285."},{4,23025,"Reduces the cooldown of your Blink spell by -2 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[764]={name="Strategist's Arcanum",classMask=128,items={{33704,"Strategist's Coronet",4,128},{33709,"Strategist's Silk Footwraps",4,128},{33707,"Strategist's Silk Gloves",4,128},{33708,"Strategist's Silk Leggings",4,128},{33705,"Strategist's Silk Spaulders",4,128},{33706,"Strategist's Silk Vestments",4,128}},bonuses={{2,23037,"Increases the damage absorbed by your Mana Shield by 285."},{4,23025,"Reduces the cooldown of your Blink spell by -2 sec."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[765]={name="Executor's Arcanum",classMask=0,items={},bonuses={{2,23037,"Increases the damage absorbed by your Mana Shield by 285."},{4,23025,"Reduces the cooldown of your Blink spell by -2 sec."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[766]={name="Combatant's Pursuit",classMask=4,items={{33721,"Combatant's Chain Boots",3,4},{33718,"Combatant's Chain Breastplate",3,4},{33719,"Combatant's Chain Grips",3,4},{33716,"Combatant's Chain Helm",3,4},{33720,"Combatant's Chain Legguards",3,4},{33717,"Combatant's Chain Spaulders",3,4}},bonuses={{2,28539,"Increases the damage done by your Multi-Shot and Carve by 4%."},{4,23158,"Reduces the cooldown of Concussive Shot by -1 sec and Wing Clip by 0 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[767]={name="Partisan's Pursuit",classMask=4,items={{33727,"Partisan's Chain Boots",4,4},{33724,"Partisan's Chain Breastplate",4,4},{33725,"Partisan's Chain Grips",4,4},{33722,"Partisan's Chain Helm",4,4},{33726,"Partisan's Chain Legguards",4,4},{33723,"Partisan's Chain Spaulders",4,4}},bonuses={{2,28539,"Increases the damage done by your Multi-Shot and Carve by 4%."},{4,23158,"Reduces the cooldown of Concussive Shot by -1 sec and Wing Clip by 0 sec."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[768]={name="Veteran's Pursuit",classMask=4,items={{33733,"Veteran's Chain Boots",4,4}},bonuses={{2,28539,"Increases the damage done by your Multi-Shot and Carve by 4%."},{4,23158,"Reduces the cooldown of Concussive Shot by -1 sec and Wing Clip by 0 sec."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[769]={name="Tactician's Threads",classMask=256,items={{33734,"Tactician's Coronal",3,256},{33739,"Tactician's Dreadweave Boots",3,256},{33737,"Tactician's Dreadweave Gloves",3,256},{33738,"Tactician's Dreadweave Leggings",3,256},{33736,"Tactician's Dreadweave Robe",3,256},{33735,"Tactician's Dreadweave Shoulders",3,256}},bonuses={{2,23047,"Reduces the casting time of your Immolate spell by 0.2 sec."},{4,23046,"Gives a 30% chance to avoid interruption caused by damage while casting Searing Pain, Shadow Bolt, and Drain Soul."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[770]={name="Strategist's Threads",classMask=256,items={{33740,"Strategist's Coronal",4,256},{33745,"Strategist's Dreadweave Boots",4,256},{33743,"Strategist's Dreadweave Gloves",4,256},{33744,"Strategist's Dreadweave Leggings",4,256},{33742,"Strategist's Dreadweave Robe",4,256},{33741,"Strategist's Dreadweave Shoulders",4,256}},bonuses={{2,23047,"Reduces the casting time of your Immolate spell by 0.2 sec."},{4,23046,"Gives a 30% chance to avoid interruption caused by damage while casting Searing Pain, Shadow Bolt, and Drain Soul."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[771]={name="Executor's Threads",classMask=0,items={},bonuses={{2,23047,"Reduces the casting time of your Immolate spell by 0.2 sec."},{4,23046,"Gives a 30% chance to avoid interruption caused by damage while casting Searing Pain, Shadow Bolt, and Drain Soul."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[772]={name="Combatant's Sanctuary",classMask=1024,items={{33757,"Combatant's Dragonhide Boots",3,1024},{33753,"Combatant's Dragonhide Epaulets",3,1024},{33755,"Combatant's Dragonhide Gloves",3,1024},{33754,"Combatant's Dragonhide Hauberk",3,1024},{33752,"Combatant's Dragonhide Helmet",3,1024},{33756,"Combatant's Dragonhide Leggings",3,1024}},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[773]={name="Partisan's Sanctuary",classMask=1024,items={{33763,"Partisan's Dragonhide Boots",4,1024},{33759,"Partisan's Dragonhide Epaulets",4,1024},{33761,"Partisan's Dragonhide Gloves",4,1024},{33760,"Partisan's Dragonhide Hauberk",4,1024},{33758,"Partisan's Dragonhide Helmet",4,1024},{33762,"Partisan's Dragonhide Leggings",4,1024}},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[774]={name="Veteran's Sanctuary",classMask=0,items={},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[775]={name="Tactician's Sanctuary",classMask=1024,items={{33775,"Tactician's Dragonhide Boots",3,1024},{33771,"Tactician's Dragonhide Epaulets",3,1024},{33773,"Tactician's Dragonhide Gloves",3,1024},{33772,"Tactician's Dragonhide Hauberk",3,1024},{33770,"Tactician's Dragonhide Helmet",3,1024},{33774,"Tactician's Dragonhide Leggings",3,1024}},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[776]={name="Strategist's Sanctuary",classMask=1024,items={{33781,"Strategist's Dragonhide Boots",4,1024},{33777,"Strategist's Dragonhide Epaulets",4,1024},{33779,"Strategist's Dragonhide Gloves",4,1024},{33778,"Strategist's Dragonhide Hauberk",4,1024},{33776,"Strategist's Dragonhide Helmet",4,1024},{33780,"Strategist's Dragonhide Leggings",4,1024}},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[777]={name="Executor's Sanctuary",classMask=0,items={},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[778]={name="Corpsman's Sanctuary",classMask=1024,items={{33793,"Corpsman's Dragonhide Boots",3,1024},{33789,"Corpsman's Dragonhide Epaulets",3,1024},{33791,"Corpsman's Dragonhide Gloves",3,1024},{33790,"Corpsman's Dragonhide Hauberk",3,1024},{33788,"Corpsman's Dragonhide Helmet",3,1024},{33792,"Corpsman's Dragonhide Leggings",3,1024}},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[779]={name="Physician's Sanctuary",classMask=1024,items={{33799,"Physician's Dragonhide Boots",4,1024},{33795,"Physician's Dragonhide Epaulets",4,1024},{33797,"Physician's Dragonhide Gloves",4,1024},{33794,"Physician's Dragonhide Helmet",4,1024}},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[780]={name="Field Medic's Sanctuary",classMask=0,items={},bonuses={{2,51871,"Reduces the mana cost of all shapeshifting by -15%."},{4,23218,"Increases your movement speed by 15% while in Bear, Cat, or Travel Form. Only active outdoors."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[781]={name="Tactician's Investiture",classMask=16,items={{33806,"Tactician's Headdress",3,16},{33809,"Tactician's Satin Gloves",3,16},{33807,"Tactician's Satin Mantle",3,16},{33810,"Tactician's Satin Pants",3,16},{33811,"Tactician's Satin Sandals",3,16},{33808,"Tactician's Satin Vestments",3,16}},bonuses={{2,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{4,23043,"Gives a 30% chance to avoid interruption caused by damage while casting Mind Blast, Smite, and Flash Heal."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[782]={name="Strategist's Investiture",classMask=16,items={{33812,"Strategist's Headdress",4,16},{33815,"Strategist's Satin Gloves",4,16},{33813,"Strategist's Satin Mantle",4,16},{33816,"Strategist's Satin Pants",4,16},{33817,"Strategist's Satin Sandals",4,16},{33814,"Strategist's Satin Vestments",4,16}},bonuses={{2,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{4,23043,"Gives a 30% chance to avoid interruption caused by damage while casting Mind Blast, Smite, and Flash Heal."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[783]={name="Executor's Investiture",classMask=0,items={},bonuses={{2,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{4,23043,"Gives a 30% chance to avoid interruption caused by damage while casting Mind Blast, Smite, and Flash Heal."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[784]={name="Corpsman's Investiture",classMask=16,items={{33824,"Corpsman's Headdress",3,16},{33827,"Corpsman's Satin Gloves",3,16},{33825,"Corpsman's Satin Mantle",3,16},{33828,"Corpsman's Satin Pants",3,16},{33829,"Corpsman's Satin Sandals",3,16},{33826,"Corpsman's Satin Vestments",3,16}},bonuses={{2,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{4,23043,"Gives a 30% chance to avoid interruption caused by damage while casting Mind Blast, Smite, and Flash Heal."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[785]={name="Physician's Investiture",classMask=16,items={{33830,"Physician's Headdress",4,16},{33833,"Physician's Satin Gloves",4,16},{33831,"Physician's Satin Mantle",4,16},{33834,"Physician's Satin Pants",4,16},{33835,"Physician's Satin Sandals",4,16},{33832,"Physician's Satin Vestments",4,16}},bonuses={{2,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{4,23043,"Gives a 30% chance to avoid interruption caused by damage while casting Mind Blast, Smite, and Flash Heal."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[786]={name="Field Medic's Investiture",classMask=0,items={},bonuses={{2,23044,"Increases the duration of your Psychic Scream spell by 1 sec."},{4,23043,"Gives a 30% chance to avoid interruption caused by damage while casting Mind Blast, Smite, and Flash Heal."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
C[787]={name="Combatant's Cover",classMask=0,items={},bonuses={{2,23048,"Reduces the cooldown of your Gouge ability by -1 sec."},{4,23049,"Increases the duration of your Sprint ability by 3 sec."},{6,14467,"+20 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[788]={name="Partisan's Cover",classMask=0,items={},bonuses={{2,23048,"Reduces the cooldown of your Gouge ability by -1 sec."},{4,23049,"Increases the duration of your Sprint ability by 3 sec."},{6,14477,"+30 Stamina."},{6,45530,"Reduces damage taken from critical hits and damage over time effects by -3%."}}}
C[789]={name="Veteran's Cover",classMask=0,items={},bonuses={{2,23048,"Reduces the cooldown of your Gouge ability by -1 sec."},{4,23049,"Increases the duration of your Sprint ability by 3 sec."},{6,14482,"+35 Stamina."},{6,45531,"Reduces damage taken from critical hits and damage over time effects by -6%."}}}
M[6473]=162
M[7948]=221
M[7949]=221
M[7950]=221
M[7951]=221
M[7952]=221
M[7953]=221
M[8347]=618
M[8367]=618
M[10328]=163
M[10329]=163
M[10330]=163
M[10331]=163
M[10332]=163
M[10333]=163
M[10399]=161
M[10400]=161
M[10401]=161
M[10402]=161
M[10403]=161
M[10410]=162
M[10411]=162
M[10412]=162
M[10413]=162
M[11684]=701
M[11726]=1
M[11728]=1
M[11729]=1
M[11730]=1
M[11731]=1
M[12422]=321
M[12424]=321
M[12425]=321
M[12426]=321
M[12427]=321
M[12428]=321
M[12429]=321
M[12939]=41
M[12940]=41
M[13183]=65
M[13218]=65
M[13388]=81
M[13389]=81
M[13390]=81
M[13391]=81
M[13392]=81
M[14137]=628
M[14138]=628
M[14139]=628
M[14140]=628
M[14611]=123
M[14612]=123
M[14614]=123
M[14615]=123
M[14616]=123
M[14620]=124
M[14621]=124
M[14622]=124
M[14623]=124
M[14624]=124
M[14626]=122
M[14629]=122
M[14631]=122
M[14632]=122
M[14633]=122
M[14636]=121
M[14637]=121
M[14638]=121
M[14640]=121
M[14641]=121
M[15045]=490
M[15046]=490
M[15047]=607
M[15048]=491
M[15049]=491
M[15050]=489
M[15051]=489
M[15052]=489
M[15053]=141
M[15054]=141
M[15055]=141
M[15056]=142
M[15057]=142
M[15058]=142
M[15059]=616
M[15060]=616
M[15061]=616
M[15062]=143
M[15063]=143
M[15064]=617
M[15065]=617
M[15066]=144
M[15067]=144
M[15802]=628
M[16369]=343
M[16391]=343
M[16392]=348
M[16393]=381
M[16396]=348
M[16397]=381
M[16401]=362
M[16403]=362
M[16405]=282
M[16406]=282
M[16409]=401
M[16410]=401
M[16413]=343
M[16414]=343
M[16415]=343
M[16416]=343
M[16417]=348
M[16418]=348
M[16419]=348
M[16420]=348
M[16421]=381
M[16422]=381
M[16423]=381
M[16424]=381
M[16425]=362
M[16426]=362
M[16427]=362
M[16428]=362
M[16429]=282
M[16430]=282
M[16431]=282
M[16432]=282
M[16433]=401
M[16434]=401
M[16435]=401
M[16436]=401
M[16437]=388
M[16440]=388
M[16441]=388
M[16442]=388
M[16443]=388
M[16444]=388
M[16446]=394
M[16448]=397
M[16449]=397
M[16450]=397
M[16451]=397
M[16452]=397
M[16453]=394
M[16454]=394
M[16455]=394
M[16456]=394
M[16457]=394
M[16459]=397
M[16462]=395
M[16463]=395
M[16465]=395
M[16466]=395
M[16467]=395
M[16468]=395
M[16471]=402
M[16472]=402
M[16473]=402
M[16474]=402
M[16475]=402
M[16476]=402
M[16477]=384
M[16478]=384
M[16479]=384
M[16480]=384
M[16483]=384
M[16484]=384
M[16485]=341
M[16487]=341
M[16489]=341
M[16490]=341
M[16491]=341
M[16492]=341
M[16494]=382
M[16496]=382
M[16498]=347
M[16499]=347
M[16501]=382
M[16502]=382
M[16503]=382
M[16504]=382
M[16505]=347
M[16506]=347
M[16507]=347
M[16508]=347
M[16509]=281
M[16510]=281
M[16513]=281
M[16514]=281
M[16515]=281
M[16516]=281
M[16518]=301
M[16519]=301
M[16521]=301
M[16522]=301
M[16523]=301
M[16524]=301
M[16525]=361
M[16526]=361
M[16527]=361
M[16528]=361
M[16530]=361
M[16531]=361
M[16533]=387
M[16534]=387
M[16535]=387
M[16536]=387
M[16539]=387
M[16540]=387
M[16541]=383
M[16542]=383
M[16543]=383
M[16544]=383
M[16545]=383
M[16548]=383
M[16549]=398
M[16550]=398
M[16551]=398
M[16552]=398
M[16554]=398
M[16555]=398
M[16558]=393
M[16560]=393
M[16561]=393
M[16562]=393
M[16563]=393
M[16564]=393
M[16565]=396
M[16566]=396
M[16567]=396
M[16568]=396
M[16569]=396
M[16571]=396
M[16573]=386
M[16574]=386
M[16577]=386
M[16578]=386
M[16579]=386
M[16580]=386
M[16666]=187
M[16667]=187
M[16668]=187
M[16669]=187
M[16670]=187
M[16671]=187
M[16672]=187
M[16673]=187
M[16674]=186
M[16675]=186
M[16676]=186
M[16677]=186
M[16678]=186
M[16679]=186
M[16680]=186
M[16681]=186
M[16682]=181
M[16683]=181
M[16684]=181
M[16685]=181
M[16686]=181
M[16687]=181
M[16688]=181
M[16689]=181
M[16690]=182
M[16691]=182
M[16692]=182
M[16693]=182
M[16694]=182
M[16695]=182
M[16696]=182
M[16697]=182
M[16698]=183
M[16699]=183
M[16700]=183
M[16701]=183
M[16702]=183
M[16703]=183
M[16704]=183
M[16705]=183
M[16706]=185
M[16707]=184
M[16708]=184
M[16709]=184
M[16710]=184
M[16711]=184
M[16712]=184
M[16713]=184
M[16714]=185
M[16715]=185
M[16716]=185
M[16717]=185
M[16718]=185
M[16719]=185
M[16720]=185
M[16721]=184
M[16722]=188
M[16723]=188
M[16724]=188
M[16725]=188
M[16726]=188
M[16727]=188
M[16728]=188
M[16729]=188
M[16730]=189
M[16731]=189
M[16732]=189
M[16733]=189
M[16734]=189
M[16735]=189
M[16736]=189
M[16737]=189
M[16795]=201
M[16796]=201
M[16797]=201
M[16798]=201
M[16799]=201
M[16800]=201
M[16801]=201
M[16802]=201
M[16803]=203
M[16804]=203
M[16805]=203
M[16806]=203
M[16807]=203
M[16808]=203
M[16809]=203
M[16810]=203
M[16811]=202
M[16812]=202
M[16813]=202
M[16814]=202
M[16815]=202
M[16816]=202
M[16817]=202
M[16818]=210
M[16819]=202
M[16820]=204
M[16821]=204
M[16822]=204
M[16823]=204
M[16824]=204
M[16825]=204
M[16826]=204
M[16827]=204
M[16828]=205
M[16829]=205
M[16830]=205
M[16831]=205
M[16832]=213
M[16833]=205
M[16834]=205
M[16835]=205
M[16836]=205
M[16837]=207
M[16838]=207
M[16839]=207
M[16840]=207
M[16841]=207
M[16842]=207
M[16843]=207
M[16844]=207
M[16845]=206
M[16846]=206
M[16847]=206
M[16848]=206
M[16849]=206
M[16850]=206
M[16851]=206
M[16852]=206
M[16853]=208
M[16854]=208
M[16855]=208
M[16856]=208
M[16857]=208
M[16858]=208
M[16859]=208
M[16860]=208
M[16861]=209
M[16862]=209
M[16863]=209
M[16864]=209
M[16865]=209
M[16866]=209
M[16867]=209
M[16868]=209
M[16897]=214
M[16898]=214
M[16899]=214
M[16900]=214
M[16901]=214
M[16902]=214
M[16903]=214
M[16904]=214
M[16905]=213
M[16906]=213
M[16907]=213
M[16908]=213
M[16909]=213
M[16910]=213
M[16911]=213
M[16912]=210
M[16913]=210
M[16914]=210
M[16915]=210
M[16916]=210
M[16917]=210
M[16918]=210
M[16919]=211
M[16920]=211
M[16921]=211
M[16922]=211
M[16923]=211
M[16924]=211
M[16925]=211
M[16926]=211
M[16927]=212
M[16928]=212
M[16929]=212
M[16930]=212
M[16931]=212
M[16932]=212
M[16933]=212
M[16934]=212
M[16935]=215
M[16936]=215
M[16937]=215
M[16938]=215
M[16939]=215
M[16940]=215
M[16941]=215
M[16942]=215
M[16943]=216
M[16944]=216
M[16945]=216
M[16946]=216
M[16947]=216
M[16948]=216
M[16949]=216
M[16950]=216
M[16951]=217
M[16952]=217
M[16953]=217
M[16954]=217
M[16955]=217
M[16956]=217
M[16957]=217
M[16958]=217
M[16959]=218
M[16960]=218
M[16961]=218
M[16962]=218
M[16963]=218
M[16964]=218
M[16965]=218
M[16966]=218
M[16979]=629
M[16980]=629
M[16984]=489
M[17064]=241
M[17082]=241
M[17562]=346
M[17564]=346
M[17566]=346
M[17567]=346
M[17568]=346
M[17569]=346
M[17570]=345
M[17571]=345
M[17572]=345
M[17573]=345
M[17576]=345
M[17577]=345
M[17578]=392
M[17579]=392
M[17580]=392
M[17581]=392
M[17583]=392
M[17584]=392
M[17586]=391
M[17588]=391
M[17590]=391
M[17591]=391
M[17592]=391
M[17593]=391
M[17594]=344
M[17596]=344
M[17598]=344
M[17599]=344
M[17600]=344
M[17601]=344
M[17602]=389
M[17603]=389
M[17604]=389
M[17605]=389
M[17607]=389
M[17608]=389
M[17610]=342
M[17611]=342
M[17612]=342
M[17613]=342
M[17616]=342
M[17617]=342
M[17618]=390
M[17620]=390
M[17622]=390
M[17623]=390
M[17624]=390
M[17625]=390
M[18202]=261
M[18203]=261
M[18204]=261
M[18205]=261
M[18263]=629
M[18409]=628
M[18486]=628
M[19156]=629
M[19165]=629
M[19577]=474
M[19588]=475
M[19594]=480
M[19601]=482
M[19605]=481
M[19609]=476
M[19613]=479
M[19617]=478
M[19621]=477
M[19682]=421
M[19683]=421
M[19684]=421
M[19685]=441
M[19686]=441
M[19687]=441
M[19688]=442
M[19689]=442
M[19690]=443
M[19691]=443
M[19692]=443
M[19693]=444
M[19694]=444
M[19695]=444
M[19822]=474
M[19823]=474
M[19824]=474
M[19825]=475
M[19826]=475
M[19827]=475
M[19828]=476
M[19829]=476
M[19830]=476
M[19831]=477
M[19832]=477
M[19833]=477
M[19834]=478
M[19835]=478
M[19836]=478
M[19838]=479
M[19839]=479
M[19840]=479
M[19841]=480
M[19842]=480
M[19843]=480
M[19845]=482
M[19846]=482
M[19848]=481
M[19849]=481
M[19863]=465
M[19865]=461
M[19866]=461
M[19873]=464
M[19893]=462
M[19896]=463
M[19898]=466
M[19905]=462
M[19910]=463
M[19912]=464
M[19920]=465
M[19925]=466
M[19951]=474
M[19952]=475
M[19953]=477
M[19954]=478
M[19955]=479
M[19956]=476
M[19957]=481
M[19958]=480
M[19959]=482
M[20033]=481
M[20034]=482
M[20041]=467
M[20042]=468
M[20043]=469
M[20044]=470
M[20045]=471
M[20046]=472
M[20047]=473
M[20048]=467
M[20049]=468
M[20050]=469
M[20051]=470
M[20052]=471
M[20053]=472
M[20054]=473
M[20055]=469
M[20056]=470
M[20057]=467
M[20058]=468
M[20059]=471
M[20060]=472
M[20061]=473
M[20150]=483
M[20154]=483
M[20158]=483
M[20159]=485
M[20163]=485
M[20167]=488
M[20171]=488
M[20175]=488
M[20176]=485
M[20186]=486
M[20190]=486
M[20194]=486
M[20195]=484
M[20199]=484
M[20203]=484
M[20204]=487
M[20208]=487
M[20212]=487
M[20295]=491
M[20296]=490
M[20406]=492
M[20407]=492
M[20408]=492
M[21278]=142
M[21329]=496
M[21330]=496
M[21331]=496
M[21332]=496
M[21333]=496
M[21334]=499
M[21335]=499
M[21336]=499
M[21337]=499
M[21338]=499
M[21343]=503
M[21344]=503
M[21345]=503
M[21346]=503
M[21347]=503
M[21348]=507
M[21349]=507
M[21350]=507
M[21351]=507
M[21352]=507
M[21353]=493
M[21354]=493
M[21355]=493
M[21356]=493
M[21357]=493
M[21359]=497
M[21360]=497
M[21361]=497
M[21362]=497
M[21364]=497
M[21365]=509
M[21366]=509
M[21367]=509
M[21368]=509
M[21370]=509
M[21372]=501
M[21373]=501
M[21374]=501
M[21375]=501
M[21376]=501
M[21387]=505
M[21388]=505
M[21389]=505
M[21390]=505
M[21391]=505
M[21392]=495
M[21393]=495
M[21394]=495
M[21395]=506
M[21396]=506
M[21397]=506
M[21398]=502
M[21399]=502
M[21400]=502
M[21401]=510
M[21402]=510
M[21403]=510
M[21404]=498
M[21405]=498
M[21406]=498
M[21407]=494
M[21408]=494
M[21409]=494
M[21410]=508
M[21411]=508
M[21412]=508
M[21413]=504
M[21414]=504
M[21415]=504
M[21416]=500
M[21417]=500
M[21418]=500
M[21683]=613
M[21684]=614
M[21704]=613
M[21705]=614
M[21889]=613
M[21890]=614
M[21994]=511
M[21995]=511
M[21996]=511
M[21997]=511
M[21998]=511
M[21999]=511
M[22000]=511
M[22001]=511
M[22002]=512
M[22003]=512
M[22004]=512
M[22005]=512
M[22006]=512
M[22007]=512
M[22008]=512
M[22009]=512
M[22010]=515
M[22011]=515
M[22013]=515
M[22015]=515
M[22016]=515
M[22017]=515
M[22060]=515
M[22061]=515
M[22062]=517
M[22063]=517
M[22064]=517
M[22065]=517
M[22066]=517
M[22067]=517
M[22068]=517
M[22069]=517
M[22070]=518
M[22071]=518
M[22072]=518
M[22073]=518
M[22074]=518
M[22075]=518
M[22076]=518
M[22077]=518
M[22078]=514
M[22079]=514
M[22080]=514
M[22081]=514
M[22082]=514
M[22083]=514
M[22084]=514
M[22085]=514
M[22086]=516
M[22087]=516
M[22088]=516
M[22089]=516
M[22090]=516
M[22091]=516
M[22092]=516
M[22093]=516
M[22095]=519
M[22096]=519
M[22097]=519
M[22098]=519
M[22099]=519
M[22100]=519
M[22101]=519
M[22102]=519
M[22106]=513
M[22107]=513
M[22108]=513
M[22109]=513
M[22110]=513
M[22111]=513
M[22112]=513
M[22113]=513
M[22253]=638
M[22301]=520
M[22302]=520
M[22303]=520
M[22304]=520
M[22305]=520
M[22306]=520
M[22311]=520
M[22313]=520
M[22416]=523
M[22417]=523
M[22418]=523
M[22419]=523
M[22420]=523
M[22421]=523
M[22422]=523
M[22423]=523
M[22424]=528
M[22425]=528
M[22426]=528
M[22427]=528
M[22428]=528
M[22429]=528
M[22430]=528
M[22431]=528
M[22436]=530
M[22437]=530
M[22438]=530
M[22439]=530
M[22440]=530
M[22441]=530
M[22442]=530
M[22443]=530
M[22464]=527
M[22465]=527
M[22466]=527
M[22467]=527
M[22468]=527
M[22469]=527
M[22470]=527
M[22471]=527
M[22476]=524
M[22477]=524
M[22478]=524
M[22479]=524
M[22480]=524
M[22481]=524
M[22482]=524
M[22483]=524
M[22488]=521
M[22489]=521
M[22490]=521
M[22491]=521
M[22492]=521
M[22493]=521
M[22494]=521
M[22495]=521
M[22496]=526
M[22497]=526
M[22498]=526
M[22499]=526
M[22500]=526
M[22501]=526
M[22502]=526
M[22503]=526
M[22504]=529
M[22505]=529
M[22506]=529
M[22507]=529
M[22508]=529
M[22509]=529
M[22510]=529
M[22511]=529
M[22512]=525
M[22513]=525
M[22514]=525
M[22515]=525
M[22516]=525
M[22517]=525
M[22518]=525
M[22519]=525
M[22843]=543
M[22852]=539
M[22855]=541
M[22856]=522
M[22857]=538
M[22858]=537
M[22859]=540
M[22860]=542
M[22862]=543
M[22863]=539
M[22864]=522
M[22865]=541
M[22867]=538
M[22868]=537
M[22869]=540
M[22870]=542
M[22872]=537
M[22873]=537
M[22874]=543
M[22875]=543
M[22876]=538
M[22877]=539
M[22878]=539
M[22879]=522
M[22880]=522
M[22881]=541
M[22882]=540
M[22883]=542
M[22884]=541
M[22885]=540
M[22886]=542
M[22887]=538
M[23059]=523
M[23060]=524
M[23061]=525
M[23062]=526
M[23063]=529
M[23064]=521
M[23065]=527
M[23066]=528
M[23067]=530
M[23078]=533
M[23081]=534
M[23082]=535
M[23084]=536
M[23085]=536
M[23087]=533
M[23088]=535
M[23089]=534
M[23090]=533
M[23091]=536
M[23092]=535
M[23093]=534
M[23243]=537
M[23244]=537
M[23251]=543
M[23252]=543
M[23253]=539
M[23254]=539
M[23255]=541
M[23256]=541
M[23257]=522
M[23258]=522
M[23259]=538
M[23260]=538
M[23261]=540
M[23262]=540
M[23263]=542
M[23264]=542
M[23272]=544
M[23273]=544
M[23274]=544
M[23275]=544
M[23276]=544
M[23277]=544
M[23278]=550
M[23279]=550
M[23280]=551
M[23281]=551
M[23282]=547
M[23283]=547
M[23284]=548
M[23285]=548
M[23286]=545
M[23287]=545
M[23288]=549
M[23289]=549
M[23290]=546
M[23291]=546
M[23292]=550
M[23293]=550
M[23294]=551
M[23295]=551
M[23296]=547
M[23297]=547
M[23298]=548
M[23299]=548
M[23300]=545
M[23301]=545
M[23302]=549
M[23303]=549
M[23304]=546
M[23305]=546
M[23306]=550
M[23307]=550
M[23308]=551
M[23309]=551
M[23310]=547
M[23311]=547
M[23312]=548
M[23313]=548
M[23314]=545
M[23315]=545
M[23316]=549
M[23317]=549
M[23318]=546
M[23319]=546
M[33000]=703
M[33001]=703
M[33002]=703
M[33003]=703
M[33004]=703
M[33005]=703
M[33006]=703
M[33007]=703
M[33008]=704
M[33009]=704
M[33010]=704
M[33011]=704
M[33012]=704
M[33013]=704
M[33014]=704
M[33015]=704
M[33016]=707
M[33017]=707
M[33018]=707
M[33019]=707
M[33020]=707
M[33021]=702
M[33026]=702
M[33029]=702
M[33035]=702
M[33037]=702
M[33042]=702
M[33162]=705
M[33163]=705
M[33164]=705
M[33165]=705
M[33166]=705
M[33167]=705
M[33168]=705
M[33169]=705
M[33170]=705
M[33171]=706
M[33172]=706
M[33173]=706
M[33174]=706
M[33175]=706
M[33176]=706
M[33205]=711
M[33269]=758
M[33275]=758
M[33366]=711
M[33367]=711
M[33368]=711
M[33380]=708
M[33381]=708
M[33382]=708
M[33383]=708
M[33384]=708
M[33385]=708
M[33386]=709
M[33387]=709
M[33388]=709
M[33389]=709
M[33390]=709
M[33391]=709
M[33392]=710
M[33393]=710
M[33394]=710
M[33395]=710
M[33396]=710
M[33397]=710
M[33398]=712
M[33399]=712
M[33400]=712
M[33401]=712
M[33402]=712
M[33403]=712
M[33404]=713
M[33405]=713
M[33406]=713
M[33407]=713
M[33408]=713
M[33409]=713
M[33410]=714
M[33411]=714
M[33412]=714
M[33413]=714
M[33414]=714
M[33415]=714
M[33422]=716
M[33423]=716
M[33424]=716
M[33425]=716
M[33426]=716
M[33427]=716
M[33428]=717
M[33429]=717
M[33430]=717
M[33431]=717
M[33432]=717
M[33433]=717
M[33440]=719
M[33441]=719
M[33442]=719
M[33443]=719
M[33444]=719
M[33445]=719
M[33446]=720
M[33447]=720
M[33448]=720
M[33449]=720
M[33450]=720
M[33451]=720
M[33458]=722
M[33459]=722
M[33460]=722
M[33461]=722
M[33462]=722
M[33463]=722
M[33464]=723
M[33465]=723
M[33466]=723
M[33467]=723
M[33468]=723
M[33469]=723
M[33476]=725
M[33477]=725
M[33478]=725
M[33479]=725
M[33480]=725
M[33481]=725
M[33482]=726
M[33483]=726
M[33484]=726
M[33485]=726
M[33486]=726
M[33487]=726
M[33494]=728
M[33495]=728
M[33496]=728
M[33497]=728
M[33498]=728
M[33499]=728
M[33500]=729
M[33501]=729
M[33502]=729
M[33503]=729
M[33504]=729
M[33505]=729
M[33512]=731
M[33513]=731
M[33514]=731
M[33515]=731
M[33516]=731
M[33517]=731
M[33518]=732
M[33519]=732
M[33520]=732
M[33521]=732
M[33522]=732
M[33523]=732
M[33530]=734
M[33531]=734
M[33532]=734
M[33533]=734
M[33534]=734
M[33535]=734
M[33536]=735
M[33537]=735
M[33538]=735
M[33539]=735
M[33540]=735
M[33541]=735
M[33548]=737
M[33549]=737
M[33550]=737
M[33551]=737
M[33552]=737
M[33553]=737
M[33554]=738
M[33555]=738
M[33556]=738
M[33557]=738
M[33558]=738
M[33559]=738
M[33566]=740
M[33567]=740
M[33568]=740
M[33569]=740
M[33570]=740
M[33571]=740
M[33572]=741
M[33573]=741
M[33574]=741
M[33575]=741
M[33577]=741
M[33584]=743
M[33585]=743
M[33586]=743
M[33587]=743
M[33588]=743
M[33589]=743
M[33590]=744
M[33591]=744
M[33592]=744
M[33593]=744
M[33594]=744
M[33595]=744
M[33602]=746
M[33603]=746
M[33604]=746
M[33605]=746
M[33606]=746
M[33607]=746
M[33608]=747
M[33609]=747
M[33610]=747
M[33611]=747
M[33612]=747
M[33613]=747
M[33620]=749
M[33621]=749
M[33622]=749
M[33623]=749
M[33624]=749
M[33625]=749
M[33626]=750
M[33627]=750
M[33628]=750
M[33629]=750
M[33630]=750
M[33631]=750
M[33638]=752
M[33639]=752
M[33640]=752
M[33641]=752
M[33642]=752
M[33643]=752
M[33644]=753
M[33645]=753
M[33646]=753
M[33647]=753
M[33648]=753
M[33649]=753
M[33656]=755
M[33657]=755
M[33658]=755
M[33659]=755
M[33660]=755
M[33661]=755
M[33662]=756
M[33663]=756
M[33664]=756
M[33665]=756
M[33666]=756
M[33667]=756
M[33674]=759
M[33675]=759
M[33676]=759
M[33677]=759
M[33678]=759
M[33679]=759
M[33680]=760
M[33681]=760
M[33682]=760
M[33683]=760
M[33684]=760
M[33685]=760
M[33686]=761
M[33687]=761
M[33688]=761
M[33689]=761
M[33690]=761
M[33691]=761
M[33698]=763
M[33699]=763
M[33700]=763
M[33701]=763
M[33702]=763
M[33703]=763
M[33704]=764
M[33705]=764
M[33706]=764
M[33707]=764
M[33708]=764
M[33709]=764
M[33716]=766
M[33717]=766
M[33718]=766
M[33719]=766
M[33720]=766
M[33721]=766
M[33722]=767
M[33723]=767
M[33724]=767
M[33725]=767
M[33726]=767
M[33727]=767
M[33733]=768
M[33734]=769
M[33735]=769
M[33736]=769
M[33737]=769
M[33738]=769
M[33739]=769
M[33740]=770
M[33741]=770
M[33742]=770
M[33743]=770
M[33744]=770
M[33745]=770
M[33752]=772
M[33753]=772
M[33754]=772
M[33755]=772
M[33756]=772
M[33757]=772
M[33758]=773
M[33759]=773
M[33760]=773
M[33761]=773
M[33762]=773
M[33763]=773
M[33770]=775
M[33771]=775
M[33772]=775
M[33773]=775
M[33774]=775
M[33775]=775
M[33776]=776
M[33777]=776
M[33778]=776
M[33779]=776
M[33780]=776
M[33781]=776
M[33788]=778
M[33789]=778
M[33790]=778
M[33791]=778
M[33792]=778
M[33793]=778
M[33794]=779
M[33795]=779
M[33797]=779
M[33799]=779
M[33806]=781
M[33807]=781
M[33808]=781
M[33809]=781
M[33810]=781
M[33811]=781
M[33812]=782
M[33813]=782
M[33814]=782
M[33815]=782
M[33816]=782
M[33817]=782
M[33824]=784
M[33825]=784
M[33826]=784
M[33827]=784
M[33828]=784
M[33829]=784
M[33830]=785
M[33831]=785
M[33832]=785
M[33833]=785
M[33834]=785
M[33835]=785
M[33842]=756
M[33843]=756
M[33844]=756
M[33845]=756
M[33846]=756
M[33847]=756
M[33848]=757
M[33849]=757
M[33850]=757
M[33851]=757
M[33852]=757
M[33853]=757
M[33857]=758
M[33858]=758
M[33859]=758
M[41312]=633
M[41340]=635
M[41724]=699
M[47000]=641
M[47001]=641
M[47002]=641
M[47003]=641
M[47004]=641
M[47005]=641
M[47006]=641
M[47007]=641
M[47008]=642
M[47009]=642
M[47010]=642
M[47011]=642
M[47012]=642
M[47013]=642
M[47014]=642
M[47015]=642
M[47016]=643
M[47017]=643
M[47018]=643
M[47019]=643
M[47020]=643
M[47021]=643
M[47022]=643
M[47023]=643
M[47024]=644
M[47025]=644
M[47026]=644
M[47027]=644
M[47028]=644
M[47029]=644
M[47030]=644
M[47031]=644
M[47032]=645
M[47033]=645
M[47034]=645
M[47035]=645
M[47036]=645
M[47037]=646
M[47038]=646
M[47039]=646
M[47040]=646
M[47041]=646
M[47042]=647
M[47043]=647
M[47044]=647
M[47045]=647
M[47046]=647
M[47047]=647
M[47048]=647
M[47049]=647
M[47050]=647
M[47051]=648
M[47052]=648
M[47053]=648
M[47054]=648
M[47055]=648
M[47056]=648
M[47057]=648
M[47058]=648
M[47059]=648
M[47060]=692
M[47061]=692
M[47062]=692
M[47063]=692
M[47064]=692
M[47065]=692
M[47066]=693
M[47067]=693
M[47068]=693
M[47069]=693
M[47070]=693
M[47071]=693
M[47072]=694
M[47073]=694
M[47074]=694
M[47075]=694
M[47076]=694
M[47077]=694
M[47078]=657
M[47079]=657
M[47080]=657
M[47081]=657
M[47082]=657
M[47083]=657
M[47084]=657
M[47085]=657
M[47086]=658
M[47087]=658
M[47088]=658
M[47089]=658
M[47090]=658
M[47091]=658
M[47092]=658
M[47093]=658
M[47094]=659
M[47095]=659
M[47096]=659
M[47097]=659
M[47098]=659
M[47099]=660
M[47100]=660
M[47101]=660
M[47102]=660
M[47103]=660
M[47104]=660
M[47105]=660
M[47106]=660
M[47107]=660
M[47108]=684
M[47109]=684
M[47110]=684
M[47111]=684
M[47112]=684
M[47113]=684
M[47114]=685
M[47115]=685
M[47116]=685
M[47117]=685
M[47118]=685
M[47119]=685
M[47120]=665
M[47121]=665
M[47122]=665
M[47123]=665
M[47124]=665
M[47125]=665
M[47126]=665
M[47127]=665
M[47128]=666
M[47129]=666
M[47130]=666
M[47131]=666
M[47132]=666
M[47133]=666
M[47134]=666
M[47135]=666
M[47136]=667
M[47137]=667
M[47138]=667
M[47139]=667
M[47140]=667
M[47141]=667
M[47142]=667
M[47143]=667
M[47144]=668
M[47145]=668
M[47146]=668
M[47147]=668
M[47148]=668
M[47149]=668
M[47150]=668
M[47151]=668
M[47152]=669
M[47153]=669
M[47154]=669
M[47155]=669
M[47156]=669
M[47157]=670
M[47158]=670
M[47159]=670
M[47160]=670
M[47161]=670
M[47162]=671
M[47163]=671
M[47164]=671
M[47165]=671
M[47166]=671
M[47167]=671
M[47168]=671
M[47169]=671
M[47170]=671
M[47171]=672
M[47172]=672
M[47173]=672
M[47174]=672
M[47175]=672
M[47176]=672
M[47177]=672
M[47178]=672
M[47179]=672
M[47180]=688
M[47181]=688
M[47182]=688
M[47183]=688
M[47184]=688
M[47185]=688
M[47186]=689
M[47187]=689
M[47188]=689
M[47189]=689
M[47190]=689
M[47191]=689
M[47192]=690
M[47193]=690
M[47194]=690
M[47195]=690
M[47196]=690
M[47197]=690
M[47198]=661
M[47199]=661
M[47200]=661
M[47201]=661
M[47202]=661
M[47203]=661
M[47204]=661
M[47205]=661
M[47206]=662
M[47207]=662
M[47208]=662
M[47209]=662
M[47210]=662
M[47211]=662
M[47212]=662
M[47213]=662
M[47214]=663
M[47215]=663
M[47216]=663
M[47217]=663
M[47218]=663
M[47219]=664
M[47220]=664
M[47221]=664
M[47222]=664
M[47223]=664
M[47224]=664
M[47225]=664
M[47226]=664
M[47227]=664
M[47228]=686
M[47229]=686
M[47230]=686
M[47231]=686
M[47232]=686
M[47233]=686
M[47234]=687
M[47235]=687
M[47236]=687
M[47237]=687
M[47238]=687
M[47239]=687
M[47240]=673
M[47241]=673
M[47242]=673
M[47243]=673
M[47244]=673
M[47245]=673
M[47246]=673
M[47247]=673
M[47248]=674
M[47249]=674
M[47250]=674
M[47251]=674
M[47252]=674
M[47253]=674
M[47254]=674
M[47255]=674
M[47261]=676
M[47262]=676
M[47263]=676
M[47264]=676
M[47265]=676
M[47266]=676
M[47267]=676
M[47268]=676
M[47269]=676
M[47270]=691
M[47271]=691
M[47272]=691
M[47273]=691
M[47274]=691
M[47275]=691
M[47276]=677
M[47277]=677
M[47278]=677
M[47279]=677
M[47280]=677
M[47281]=677
M[47282]=677
M[47283]=677
M[47284]=678
M[47285]=678
M[47286]=678
M[47287]=678
M[47288]=678
M[47289]=678
M[47290]=678
M[47291]=678
M[47292]=679
M[47293]=679
M[47294]=679
M[47295]=679
M[47296]=679
M[47297]=680
M[47298]=680
M[47299]=680
M[47300]=680
M[47301]=680
M[47302]=680
M[47303]=680
M[47304]=680
M[47305]=680
M[47306]=695
M[47307]=695
M[47308]=695
M[47309]=695
M[47310]=695
M[47311]=695
M[47312]=696
M[47313]=696
M[47314]=696
M[47315]=696
M[47316]=696
M[47317]=696
M[47318]=697
M[47319]=697
M[47320]=697
M[47321]=697
M[47322]=697
M[47323]=697
M[47324]=698
M[47325]=698
M[47326]=698
M[47327]=698
M[47328]=698
M[47329]=698
M[47330]=649
M[47331]=649
M[47332]=649
M[47333]=649
M[47334]=649
M[47335]=649
M[47336]=649
M[47337]=649
M[47338]=650
M[47339]=650
M[47340]=650
M[47341]=650
M[47342]=650
M[47343]=650
M[47344]=650
M[47345]=650
M[47346]=651
M[47347]=651
M[47348]=651
M[47349]=651
M[47350]=651
M[47351]=651
M[47352]=651
M[47353]=651
M[47354]=652
M[47355]=652
M[47356]=652
M[47357]=652
M[47358]=652
M[47359]=652
M[47360]=652
M[47361]=652
M[47362]=653
M[47363]=653
M[47364]=653
M[47365]=653
M[47366]=653
M[47367]=654
M[47368]=654
M[47369]=654
M[47370]=654
M[47371]=654
M[47372]=655
M[47373]=655
M[47374]=655
M[47375]=655
M[47376]=655
M[47377]=655
M[47378]=655
M[47379]=655
M[47380]=655
M[47381]=656
M[47382]=656
M[47383]=656
M[47384]=656
M[47385]=656
M[47386]=656
M[47387]=656
M[47388]=656
M[47389]=656
M[47390]=681
M[47391]=681
M[47392]=681
M[47393]=681
M[47394]=681
M[47395]=681
M[47396]=682
M[47397]=682
M[47398]=682
M[47399]=682
M[47400]=682
M[47401]=682
M[47402]=683
M[47403]=683
M[47404]=683
M[47405]=683
M[47406]=683
M[47407]=683
M[55094]=639
M[55108]=640
M[55113]=640
M[55196]=636
M[55271]=631
M[56035]=634
M[56048]=636
M[56050]=635
M[56053]=635
M[56064]=637
M[56070]=632
M[56089]=632
M[56090]=631
M[56091]=633
M[56092]=634
M[56093]=634
M[56096]=637
M[58099]=699
M[58111]=699
M[58112]=699
M[58113]=699
M[58114]=699
M[58115]=699
M[58131]=700
M[58134]=700
M[58147]=700
M[58176]=700
M[58177]=700
M[58178]=700
M[58214]=701
M[60007]=630
M[60008]=630
M[60009]=630
M[60010]=630
M[60287]=601
M[60288]=601
M[60289]=601
M[60290]=601
M[60291]=601
M[60292]=601
M[60350]=610
M[60351]=610
M[60352]=610
M[60353]=610
M[60354]=610
M[60355]=610
M[60356]=610
M[60357]=610
M[60358]=611
M[60359]=611
M[60360]=611
M[60361]=611
M[60362]=611
M[60363]=611
M[60364]=611
M[60365]=611
M[60555]=621
M[60556]=621
M[60557]=621
M[60558]=621
M[60568]=612
M[60572]=612
M[60573]=615
M[60574]=615
M[60575]=615
M[60576]=615
M[60577]=615
M[60578]=615
M[60579]=619
M[60580]=619
M[60581]=619
M[60582]=612
M[60790]=638
M[60798]=638
M[60809]=638
M[61251]=639
M[61313]=622
M[61324]=622
M[61356]=626
M[61357]=626
M[61358]=626
M[61359]=626
M[61360]=627
M[61361]=627
M[61362]=627
M[61363]=627
M[61364]=623
M[61365]=623
M[61366]=623
M[61367]=623
M[61376]=622
M[61377]=622
M[61378]=622
M[61379]=622
M[65000]=607
M[65001]=607
M[65002]=607
M[65007]=321
M[65015]=491
M[65019]=618
M[65024]=620
M[65025]=620
M[65026]=620
M[65027]=620
M[65035]=629
M[70500]=638
M[70501]=638
M[70502]=638
M[70503]=638
M[70504]=638
M[70506]=638
M[70507]=638
M[70508]=638
M[70509]=639
M[70510]=639
M[70511]=639
M[70512]=639
M[70513]=639
M[70514]=639
M[70515]=639
M[70516]=639
M[70517]=640
M[70518]=640
M[70519]=640
M[70520]=640
M[70521]=640
M[70522]=640
M[70523]=640
M[70524]=640
M[70525]=641
M[70526]=641
M[70527]=641
M[70528]=641
M[70529]=641
M[70530]=641
M[70531]=641
M[70532]=641
M[70537]=642
M[70538]=642
M[70539]=642
M[70540]=642
M[70541]=642
M[70542]=643
M[70543]=643
M[70544]=643
M[70545]=643
M[70546]=643
M[70571]=644
M[70572]=644
M[70573]=644
M[70574]=644
M[70575]=644
M[70576]=644
M[70577]=644
M[70578]=644
M[70579]=644
M[70580]=645
M[70581]=645
M[70582]=645
M[70583]=645
M[70584]=645
M[70585]=645
M[70586]=645
M[70587]=645
M[70588]=645
M[81006]=162
M[81007]=161
M[81061]=600
M[81062]=600
M[81063]=600
M[81064]=600
M[81065]=600
M[81066]=600
M[83280]=604
M[83281]=604
M[83282]=604
M[83283]=604
M[83284]=604
M[83285]=604
M[83286]=605
M[83287]=605
M[83288]=605
M[83289]=605
M[83290]=605
M[83291]=605
M[83292]=606
M[83293]=606
M[83294]=606
M[83295]=606
M[83296]=606
M[83297]=606
M[83400]=602
M[83401]=602
M[83402]=602
M[83403]=602
M[83404]=602
M[83405]=602
M[83410]=603
M[83411]=603
M[83412]=603
M[83413]=603
M[83414]=603
M[83415]=603
M[83420]=608
M[83421]=608
M[83423]=608
M[83424]=608
M[83425]=608
M[83426]=608
M[83427]=608
M[83428]=608
M[83429]=609
M[83430]=609
M[83431]=609
M[83432]=609
M[83433]=609
M[83434]=609
M[83435]=609
M[83436]=609
M[279593]=497
M[280589]=738
M[280590]=738
M[280591]=738
M[280592]=738
M[281044]=513
M[604518]=215
M[1245005]=217
M[1363583]=217
M[1447079]=214
M[1447080]=214
M[1447081]=214
M[1447082]=214
M[1487825]=613
M[1568468]=215
M[1568469]=215
M[1586121]=215
M[1586329]=215
M[1594113]=215
M[1634107]=525
M[1696579]=681
M[1710912]=648
M[1732025]=671
M[1732029]=671
M[1732038]=671
M[1738324]=671
M[1745702]=671
M[1756154]=528
M[1758375]=671
M[1784242]=679
M[1784244]=679
M[1784245]=679
M[1784248]=679
M[1784249]=680
M[1891641]=521
M[1892919]=686
M[1899480]=643
M[1899481]=643
M[1899482]=643
M[1899483]=643
M[1901786]=214
M[1901787]=681
M[1906961]=643
M[1915084]=647
M[1918162]=694
M[1927738]=671
M[1927740]=671
M[1943560]=671
M[1943561]=671
M[1956894]=643
M[1958997]=671
M[1965577]=647
M[1966257]=647
M[1968914]=647
M[1968915]=647
M[1971301]=671
M[1980135]=671
M[1980518]=686
M[1980971]=660
M[1980973]=660
M[1980974]=660
M[1981001]=660
M[1981142]=674
M[1982112]=657
M[1982860]=217
M[1982861]=208
M[1982862]=217
M[1983136]=658
M[1983137]=658
M[1983138]=658
M[1983148]=694
M[1983149]=693
M[1983150]=648
M[1983151]=744
M[1983152]=694
M[1983154]=744
M[1983345]=603
M[1983411]=658
M[1983618]=658
M[1983619]=658
AshenDB = AshenDB or {}
AshenDB.ItemSets = C
AshenDB.ItemToSet = M
AshenDB.SetCatalogMeta = AshenBuilds.SetCatalogMeta
