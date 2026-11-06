-- Dungeon guide: Shadowfang Keep, Horde
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Shadowfang Keep (22-30)", nil, "Horde", function()

return [[

N Shadowfang Keep |N|Every quest for Shadowfang Keep: picked up, then the way in, what each asks for inside, and the hand-ins after|

N Given elsewhere |N|Also for Shadowfang Keep, not on this guide's way: Too Late to Prelate, from Father Brightcopf in Tirisfal Glades; The Orb of Soran'ruk (Warlock), from Doan Karhan in The Barrens|

R Undercity |N|Travel to the Undercity| |Z|Undercity|
A Into The Jaws |QID|40281| |N|Pierce Shackleton (85.5, 13.5)| |Z|Undercity| |O| |PRE|40280|
A The Book of Ur |QID|1013| |N|Keeper Bel'dugur (53.7, 54.5)| |Z|Undercity|

F The Sepulcher |N|Fly to the Sepulcher in Silverpine Forest| |Z|Silverpine Forest|
A Deathstalkers in Shadowfang |QID|1098| |N|High Executor Hadrec (43.4, 40.9)| |Z|Silverpine Forest|
A Arugal Must Die |QID|1014| |N|Dalar Dawnweaver (44.2, 39.8)| |Z|Silverpine Forest|

R Shadowfang Keep |N|The keep stands on the hill above Pyrewood Village (42.8, 67.5)| |Z|Silverpine Forest|
T Deathstalkers in Shadowfang |QID|1098| |N|Deathstalker Vincent|
C Into The Jaws |QID|40281| |N|Find Melenas' Belongings in the Shadowfang Keep Library| |O|
C The Book of Ur |QID|1013| |N|Get the Book of Ur|
C Arugal Must Die |QID|1014| |N|Kill Arugal and bring his head|
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

N Back outside |N|Out of Shadowfang Keep, in Silverpine Forest|
T Arugal Must Die |QID|1014| |N|Dalar Dawnweaver (44.2, 39.8)| |Z|Silverpine Forest|

R Undercity |N|Travel to the Undercity| |Z|Undercity|
T Into The Jaws |QID|40281| |N|Pierce Shackleton (85.5, 13.5)| |Z|Undercity| |O|
A Darlthos Legacy |QID|40282| |N|Pierce Shackleton (85.5, 13.5)| |Z|Undercity| |O| |PRE|40281|
T The Book of Ur |QID|1013| |N|Keeper Bel'dugur (53.7, 54.5)| |Z|Undercity|

F The Sepulcher |N|Fly to the Sepulcher in Silverpine Forest| |Z|Silverpine Forest| |O| |PRE|40281|
T Darlthos Legacy |QID|40282| |N|Duchess Grelda (42, 10.2)| |Z|Silverpine Forest| |O|

N Done |N|That is every quest for Shadowfang Keep|

]]
end)
