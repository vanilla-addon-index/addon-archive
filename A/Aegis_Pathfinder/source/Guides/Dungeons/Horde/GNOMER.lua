-- Dungeon guide: Gnomeregan, Horde
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Gnomeregan (29-38)", nil, "Horde", function()

return [[

N Gnomeregan |N|Every quest for Gnomeregan: picked up, then the way in, what each asks for inside, and the hand-ins after|

N Given elsewhere |N|Also for Gnomeregan, not on this guide's way: Backup Capacitor, from Technician Grimzlow in Durotar|

R Gnomeregan |N|Gnomeregan's front door is in the valley west of Kharanos (24.4, 39.6)| |Z|Dun Morogh|
A A Fine Mess |QID|2904| |N|Kernobee|
A Return of the Ring |QID|2949| |N|The Sparklematic 5200| |O| |PRE|2945|
K Grubbis |N|He comes at the end of Emi Shortfuse's event by the entrance, with his basilisk Chomper.| |TANK|Pick up Chomper as well.| |BOSS|Grubbis|
K Viscous Fallout |N|No special abilities known.| |BOSS|Viscous Fallout|
K Electrocutioner 6000 |N|Megavolt hits everyone in front of him, Chain Bolt jumps between players, and Shock hits his target.| |TANK|Face him away from the group.| |HEAL|It's all Nature damage: Nature resistance helps.| |DPS|Interrupt Chain Bolt; keep out of his front.| |BOSS|Electrocutioner 6000|
K Crowd Pummeler 9-60 |N|Crowd Pummel knocks back and interrupts everyone near it, Arcing Smash hits in front, and Trample hits those near.| |TANK|Face it away, with your back to a wall.| |HEAL|Stand out of Crowd Pummel's reach, or your heals are interrupted.| |DPS|Casters stand back out of Crowd Pummel.| |BOSS|Crowd Pummeler 9-60|
K Dark Iron Ambassador |N|Rare: not always here. Fire Shield burns those near him, he casts Fireball, and he summons Burning Servants.| |DPS|Kill the Burning Servants; interrupt Fireball.| |BOSS|Dark Iron Ambassador| |O|
K Mekgineer Thermaplugg |N|Knock Away throws his target back. The bomb faces round the room let out Walking Bombs that run at you and explode; the buttons by the faces shut them off.| |TANK|Keep your back to a wall.| |DPS|Kill the Walking Bombs before they reach the group, and press the buttons by the bomb faces.| |BOSS|Mekgineer Thermaplugg|

R Orgrimmar |N|Travel to Orgrimmar| |Z|Orgrimmar|
T Return of the Ring |QID|2949| |N|Nogg (76, 25.4)| |Z|Orgrimmar| |O|
A Nogg's Ring Redo |QID|2950| |N|Nogg (76, 25.4)| |Z|Orgrimmar| |O| |PRE|2949|

F Booty Bay |N|Fly to Booty Bay in Stranglethorn Vale| |Z|Stranglethorn Vale|
T A Fine Mess |QID|2904| |N|Scooty (27.6, 77.5)| |Z|Stranglethorn Vale|

N Gnomeregan again |N|What you have handed in leads back to Gnomeregan|

R Gnomeregan |N|Gnomeregan's front door is in the valley west of Kharanos (24.4, 39.6)| |Z|Dun Morogh|
C Nogg's Ring Redo |QID|2950| |N|Get the Brilliant Gold Ring, a Silver Bar, a Moss Agate, and 30 silver coins, outside too (30.5, 27.1) (21.5, 37.1)| |Z|Dun Morogh| |O|

R Orgrimmar |N|Travel to Orgrimmar| |Z|Orgrimmar| |O| |PRE|2949|
T Nogg's Ring Redo |QID|2950| |N|Nogg (76, 25.4)| |Z|Orgrimmar| |O|

N Done |N|That is every quest for Gnomeregan|

]]
end)
