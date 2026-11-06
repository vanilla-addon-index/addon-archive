-- Dungeon guide: Razorfen Kraul, Horde
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Razorfen Kraul (29-38)", nil, "Horde", function()

return [[

N Razorfen Kraul |N|Every quest for Razorfen Kraul: picked up, then the way in, what each asks for inside, and the hand-ins after|

R Undercity |N|Travel to the Undercity| |Z|Undercity|
A Speak with Ruga |QID|1823| |N|Baltus Fowler (47.4, 17.3)| |Z|Undercity| |C|Warrior|
A Going, Going, Guano! |QID|1109| |N|Master Apothecary Faranell (48.8, 69.3)| |Z|Undercity|

R Thunder Bluff |N|Travel to Thunder Bluff| |Z|Thunder Bluff|
A Tainted Brambleheart |QID|41758| |N|Kym Wildmane (77.1, 29.8)| |Z|Thunder Bluff|
A A Vengeful Fate |QID|1102| |N|Auld Stonespire (36, 59.9)| |Z|Thunder Bluff|

R The Barrens |N|Travel to The Barrens| |Z|The Barrens|
T Speak with Ruga |QID|1823| |N|Ruga Ragetotem (44.7, 59.4)| |Z|The Barrens| |C|Warrior|
A Trial at the Field of Giants |QID|1824| |N|Ruga Ragetotem (44.7, 59.4)| |Z|The Barrens| |C|Warrior|
C Trial at the Field of Giants |QID|1824| |N|Get 5 twitching antennae (45.1, 70.7)| |Z|The Barrens| |C|Warrior|
T Trial at the Field of Giants |QID|1824| |N|Ruga Ragetotem (44.7, 59.4)| |Z|The Barrens| |C|Warrior|
A Speak with Thun'grim |QID|1825| |N|Ruga Ragetotem (44.7, 59.4)| |Z|The Barrens| |C|Warrior|
A Blueleaf Tubers |QID|1221| |N|Mebok Mizzyrix (62.4, 37.6)| |Z|The Barrens|
T Speak with Thun'grim |QID|1825| |N|Thun'grim Firegaze (57.2, 30.3)| |Z|The Barrens| |C|Warrior|
A Brutal Armor |QID|1838| |N|Thun'grim Firegaze (57.2, 30.3)| |Z|The Barrens| |C|Warrior|

R Razorfen Kraul |N|In the south of the Barrens, west of the Thousand Needles road, among the thorns (40.8, 89.4)| |Z|The Barrens|
C Blueleaf Tubers |QID|1221| |N|Grab a Crate with Holes. Grab a Snufflenose Command Stick. Grab and read the Snufflenose Owner's Manual.  In Razorfen Kraul, use the Crate with Holes to summon a Snufflenose Gopher, and use the Command Stick on the gopher to make it search for Tubers.  Bring 6 Blueleaf Tubers, the Snufflenose Command Stick and the Crate with Holes, outside too (62.3, 37.6)| |Z|The Barrens|
A Willix the Importer |QID|1144| |N|Willix the Importer|
C Willix the Importer |QID|1144| |N|Escort Willix the Importer out of Razorfen Kraul.|
T Willix the Importer |QID|1144| |N|Willix the Importer|
C Brutal Armor |QID|1838| |N|Bring to Thun'grim Firegaze 15 Smoky Iron Ingots, 10 Powdered Azurite, 10 Iron Bars and a Vial of Phlogiston| |C|Warrior|
C Tainted Brambleheart |QID|41758| |N|Destroy the living embodiment of natural corruption within the depths of Razorfen Kraul, and bring the Tainted Brambleheart|
C Going, Going, Guano! |QID|1109| |N|Get 1 pile of Kraul Guano|
C A Vengeful Fate |QID|1102| |N|Get Razorflank's Heart|
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
T Brutal Armor |QID|1838| |N|Thun'grim Firegaze (57.2, 30.3)| |Z|The Barrens| |C|Warrior|
A Orm Stonehoof and the Brutal Helm |QID|1840| |N|Thun'grim Firegaze (57.2, 30.3)| |Z|The Barrens| |C|Warrior|
A Velora Nitely and the Brutal Legguards |QID|1841| |N|Thun'grim Firegaze (57.2, 30.3)| |Z|The Barrens| |C|Warrior|
A Brutal Hauberk |QID|1848| |N|Thun'grim Firegaze (57.2, 30.3)| |Z|The Barrens| |C|Warrior|
T Brutal Hauberk |QID|1848| |N|Thun'grim Firegaze (57.2, 30.3)| |Z|The Barrens| |C|Warrior|

R Thunder Bluff |N|Travel to Thunder Bluff| |Z|Thunder Bluff|
T Orm Stonehoof and the Brutal Helm |QID|1840| |N|Orm Stonehoof (38.9, 56)| |Z|Thunder Bluff| |C|Warrior|
T A Vengeful Fate |QID|1102| |N|Auld Stonespire (36, 59.9)| |Z|Thunder Bluff|
T Tainted Brambleheart |QID|41758| |N|Kym Wildmane (77.1, 29.8)| |Z|Thunder Bluff|

R Undercity |N|Travel to the Undercity| |Z|Undercity|
T Velora Nitely and the Brutal Legguards |QID|1841| |N|Velora Nitely (62.1, 39.1)| |Z|Undercity| |C|Warrior|
T Going, Going, Guano! |QID|1109| |N|Master Apothecary Faranell (48.8, 69.3)| |Z|Undercity|

N Done |N|That is every quest for Razorfen Kraul|

]]
end)
