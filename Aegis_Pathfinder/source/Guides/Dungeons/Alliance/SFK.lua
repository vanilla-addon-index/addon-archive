-- Dungeon guide: Shadowfang Keep, Alliance
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Shadowfang Keep (22-30)", nil, "Alliance", function()

return [[

N Shadowfang Keep |N|Every quest for Shadowfang Keep: picked up, then the way in, what each asks for inside, and the hand-ins after|

N Given elsewhere |N|Also for Shadowfang Keep, not on this guide's way: The Test of Righteousness (Paladin), from Jordan Stilwell in Dun Morogh; The Orb of Soran'ruk (Warlock), from Doan Karhan in The Barrens|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City|
A The Missing Sorcerer |QID|60109| |N|High Sorcerer Andromath (48.7, 87.6)| |Z|Stormwind City|
A Arugal's Folly |QID|60108| |N|High Sorcerer Andromath (48.7, 87.6)| |Z|Stormwind City|

R Darnassus |N|Travel to Darnassus| |Z|Darnassus| |C|Priest/Mage/Warlock/Druid| |O| |PRE|41377|
A Blood of Vorgendor |QID|41378| |N|Arch Druid Fandral Staghelm (34.8, 9.3)| |Z|Darnassus| |C|Priest/Mage/Warlock/Druid| |O| |PRE|41377|

R Shadowfang Keep |N|The keep stands on the hill above Pyrewood Village (42.8, 67.5)| |Z|Silverpine Forest|
T The Missing Sorcerer |QID|60109| |N|Sorcerer Ashcrombe|
C Blood of Vorgendor |QID|41378| |N|Gather worgen blood for Fandral Staghelm. He requires blood samples from Karazhan, Gilneas City and Shadowfang Keep| |C|Priest/Mage/Warlock/Druid| |O|
K Rethilgore |N|Soul Drain roots a player and drains their health.| |HEAL|Dispel Soul Drain (Magic: Priest, Paladin).| |DPS|Interrupt Soul Drain.| |BOSS|Rethilgore|
K Razorclaw the Butcher |N|Razorclaw drains his target with Butcher Drain.| |HEAL|Keep the tank topped up through the drain.| |BOSS|Razorclaw the Butcher|
K Baron Silverlaine |N|Veil of Shadow, a curse, cuts the healing his target takes.| |HEAL|Remove Veil of Shadow (Curse: Mage, Druid) before you heal the tank.| |DPS|Interrupt Veil of Shadow.| |BOSS|Baron Silverlaine|
K Prelate Ironmane |N|Pathfinder has no notes on this fight yet.| |BOSS|Prelate Ironmane|
K Commander Springvale |N|A paladin: he heals with Holy Light and stuns with Hammer of Justice.| |HEAL|Dispel Hammer of Justice (Magic: Priest, Paladin) from the tank.| |DPS|Interrupt Holy Light.| |BOSS|Commander Springvale|
K Odo the Blindwatcher |N|At three-quarters health Howling Rage makes him, and those with him, hit harder.| |TANK|His damage climbs after Howling Rage: save a cooldown for it.| |HEAL|Expect heavier hits on the tank later in the fight.| |BOSS|Odo the Blindwatcher|
K Deathsworn Captain |N|Rare: not always here. A warrior: Cleave and Hamstring.| |TANK|Face him away from the group.| |BOSS|Deathsworn Captain| |O|
K Fenrus the Devourer |N|Toxic Saliva poisons a player and drains their mana.| |HEAL|Cure Toxic Saliva (Poison: Druid, Shaman, Paladin).| |DPS|Interrupt Toxic Saliva.| |BOSS|Fenrus the Devourer|
K Wolf Master Nandos |N|Nandos calls his worgs into the fight: Bleak Worgs, Slavering Worgs and a Lupine Horror.| |TANK|Gather the worgs on you.| |DPS|Interrupt his calls when you can, and kill the worgs before Nandos.| |BOSS|Wolf Master Nandos|
K Archmage Arugal |N|Arugal casts Void Bolt, and Thundershock hits and stuns everyone near him.| |HEAL|Void Bolt hits hard: keep everyone topped up.| |DPS|Interrupt Void Bolt; ranged stand back from Thundershock.| |BOSS|Archmage Arugal|
C Arugal's Folly |QID|60108| |N|High Sorcerer Andromath has tasked you with the death of Archmage Arugal|

R Darnassus |N|Travel to Darnassus| |Z|Darnassus| |C|Priest/Mage/Warlock/Druid| |O| |PRE|41377|
T Blood of Vorgendor |QID|41378| |N|Arch Druid Fandral Staghelm (34.8, 9.3)| |Z|Darnassus| |C|Priest/Mage/Warlock/Druid| |O|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City|
T Arugal's Folly |QID|60108| |N|High Sorcerer Andromath (48.7, 87.6)| |Z|Stormwind City|

N Done |N|That is every quest for Shadowfang Keep|

]]
end)
