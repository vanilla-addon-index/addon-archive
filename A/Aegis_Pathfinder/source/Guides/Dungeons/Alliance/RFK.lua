-- Dungeon guide: Razorfen Kraul, Alliance
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Razorfen Kraul (29-38)", nil, "Alliance", function()

return [[

N Razorfen Kraul |N|Every quest for Razorfen Kraul: picked up, then the way in, what each asks for inside, and the hand-ins after|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City| |C|Warrior| |O| |PRE|1702|
A Fire Hardened Mail |QID|1701| |N|Furen Longbeard (64.6, 37.2)| |Z|Stormwind City| |C|Warrior| |O| |PRE|1702|

R The Barrens |N|Travel to The Barrens| |Z|The Barrens|
A Blueleaf Tubers |QID|1221| |N|Mebok Mizzyrix (62.4, 37.6)| |Z|The Barrens|

R Razorfen Kraul |N|In the south of the Barrens, west of the Thousand Needles road, among the thorns (40.8, 89.4)| |Z|The Barrens|
C Blueleaf Tubers |QID|1221| |N|Grab a Crate with Holes. Grab a Snufflenose Command Stick. Grab and read the Snufflenose Owner's Manual.  In Razorfen Kraul, use the Crate with Holes to summon a Snufflenose Gopher, and use the Command Stick on the gopher to make it search for Tubers.  Bring 6 Blueleaf Tubers, the Snufflenose Command Stick and the Crate with Holes, outside too (62.3, 37.6)| |Z|The Barrens|
C Fire Hardened Mail |QID|1701| |N|Gather the materials Furen Longbeard requires: Scorched Spider Fang, Charred Horn, Galvanized Horn, Vial of Phlogiston| |C|Warrior| |O|
A Mortality Wanes |QID|1142| |N|Heralath Fallowbrook|
C Mortality Wanes |QID|1142| |N|Find: Treshala's Pendant|
A Willix the Importer |QID|1144| |N|Willix the Importer|
C Willix the Importer |QID|1144| |N|Escort Willix the Importer out of Razorfen Kraul.|
T Willix the Importer |QID|1144| |N|Willix the Importer|
K Death Speaker Jargba |N|Dominate Mind takes control of a player, and he casts Shadow Bolt.| |HEAL|Dispel Dominate Mind (Magic: Priest, Paladin).| |DPS|Interrupt Dominate Mind; slow or crowd-control a controlled player rather than killing them.| |BOSS|Death Speaker Jargba|
K Aggem Thorncurse |N|He heals with Chain Heal from 75%, summons a Boar Spirit, and uses Battle Shout.| |TANK|Pick up the Boar Spirit.| |DPS|Interrupt Chain Heal; kill the Boar Spirit.| |BOSS|Aggem Thorncurse|
K Overlord Ramtusk |N|Thunderclap hits and slows everyone near him, and Battle Shout raises his attack power.| |HEAL|Dispel Thunderclap's slow (Magic: Priest, Paladin).| |DPS|Ranged stand back.| |BOSS|Overlord Ramtusk|
K Earthcaller Halmgar |N|Rare: not always here. He drops an Earthbind Totem, summons an Earth Rumbler, and casts Lightning Bolt.| |DPS|Kill the Earthbind Totem; interrupt Lightning Bolt.| |BOSS|Earthcaller Halmgar| |O|
K Rotthorn |N|Pathfinder has no notes on this fight yet.| |BOSS|Rotthorn|
K Agathelos the Raging |N|Rampage hits and stuns everyone near him, he charges, and he frenzies at 60% and at 40%.| |TANK|He hits harder each time he frenzies.| |HEAL|Rampage hits the melee too.| |DPS|Ranged stand back out of Rampage.| |BOSS|Agathelos the Raging|
K Blind Hunter |N|Rare: not always here. No special abilities known.| |BOSS|Blind Hunter| |O|
K Charlga Razorflank |N|She casts Chain Bolt, heals her allies with Renew, and restores her mana with Mana Spike.| |DPS|Interrupt Chain Bolt; dispel or Purge her Renew (Priest, Shaman).| |BOSS|Charlga Razorflank|

N Back outside |N|Out of Razorfen Kraul, in The Barrens|
T Blueleaf Tubers |QID|1221| |N|Mebok Mizzyrix (62.4, 37.6)| |Z|The Barrens|
A Lonebrow's Journal |QID|1100| |N|Henrig Lonebrow's Journal: right-click it to start the quest| |Z|The Barrens| |U|5791| |O|

F Thalanaar |N|Fly to Thalanaar in Feralas| |Z|Feralas|
T Lonebrow's Journal |QID|1100| |N|Falfindel Waywarder (89.6, 46.6)| |Z|Feralas| |O|
A The Crone of the Kraul |QID|1101| |N|Falfindel Waywarder (89.6, 46.6)| |Z|Feralas| |O| |PRE|1100|

R Darnassus |N|Travel to Darnassus| |Z|Darnassus|
T Mortality Wanes |QID|1142| |N|Treshala Fallowbrook (69.5, 67.8)| |Z|Darnassus|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City|
T Fire Hardened Mail |QID|1701| |N|Furen Longbeard (64.6, 37.2)| |Z|Stormwind City| |C|Warrior| |O|
A Grimand Elmore |QID|1700| |N|Furen Longbeard (64.6, 37.2)| |Z|Stormwind City| |C|Warrior| |R|Human/High Elf| |O| |PRE|1701|
A Mathiel |QID|1703| |N|Furen Longbeard (64.6, 37.2)| |Z|Stormwind City| |C|Warrior| |R|Night Elf| |O| |PRE|1701|
A Furen's Armor |QID|1782| |N|Furen Longbeard (64.6, 37.2)| |Z|Stormwind City| |O| |PRE|1701|
T Furen's Armor |QID|1782| |N|Furen Longbeard (64.6, 37.2)| |Z|Stormwind City| |O|
T Grimand Elmore |QID|1700| |N|Grimand Elmore (59.7, 33.8)| |Z|Stormwind City| |C|Warrior| |R|Human/High Elf| |O|

N Razorfen Kraul again |N|What you have handed in leads back to Razorfen Kraul|

R Darnassus |N|Travel to Darnassus| |Z|Darnassus| |C|Warrior| |R|Night Elf| |O| |PRE|1701|
T Mathiel |QID|1703| |N|Mathiel (59.5, 45.4)| |Z|Darnassus| |C|Warrior| |R|Night Elf| |O|

R Razorfen Kraul |N|In the south of the Barrens, west of the Thousand Needles road, among the thorns (40.8, 89.4)| |Z|The Barrens|
C The Crone of the Kraul |QID|1101| |N|Get Razorflank's Medallion| |O|

F Thalanaar |N|Fly to Thalanaar in Feralas| |Z|Feralas| |O| |PRE|1100|
T The Crone of the Kraul |QID|1101| |N|Falfindel Waywarder (89.6, 46.6)| |Z|Feralas| |O|

N Done |N|That is every quest for Razorfen Kraul|

]]
end)
