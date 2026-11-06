-- Dungeon guide: The Stockade, Alliance
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/The Stockade (24-32)", nil, "Alliance", function()

return [[

N The Stockade |N|Every quest for The Stockade: picked up, then the way in, what each asks for inside, and the hand-ins after|

F Menethil Harbor |N|Fly to Menethil Harbor in the Wetlands| |Z|Wetlands|
A Uncovering Mystery |QID|55215| |N|Lord Commander Ryke (36.4, 67.3)| |Z|Wetlands|
T Uncovering Mystery |QID|55215| |N|Marge Blackwood (39.2, 65.4)| |Z|Wetlands|
A The Mystery Continues |QID|55216| |N|Lord Commander Ryke (36.4, 67.3)| |Z|Wetlands|
T The Mystery Continues |QID|55216| |N|Poppy Zabini (39.4, 61.3)| |Z|Wetlands|
A Zabini's Information |QID|55217| |N|Poppy Zabini (39.4, 61.3)| |Z|Wetlands|
T Zabini's Information |QID|55217| |N|Marge Blackwood (39.2, 65.4)| |Z|Wetlands|
A A Potential Clue |QID|55218| |N|Marge Blackwood (39.2, 65.4)| |Z|Wetlands|
T A Potential Clue |QID|55218| |N|Lord Commander Ryke (36.4, 67.3)| |Z|Wetlands|
A Overlapping Investigations |QID|55219| |N|Lord Commander Ryke (36.4, 67.3)| |Z|Wetlands|
T Overlapping Investigations |QID|55219| |N|Robb Dursley (34.7, 65.3)| |Z|Wetlands|
A Robb's Report |QID|55220| |N|Robb Dursley (34.7, 65.3)| |Z|Wetlands|
A The Dark Iron War |QID|303| |N|Motley Garmason (49.7, 18.2)| |Z|Wetlands|
C The Dark Iron War |QID|303| |N|Motley Garmason at Dun Modr wants you to kill 15 Dark Iron Dwarves,  5 Dark Iron Tunnelers, 5 Dark Iron Saboteurs and 5 Dark Iron Demolitionists (47.3, 16.9) (61.3, 26.1)| |Z|Wetlands|
T The Dark Iron War |QID|303| |N|Motley Garmason (49.7, 18.2)| |Z|Wetlands|
A The Fury Runs Deep |QID|378| |N|Motley Garmason (49.7, 18.2)| |Z|Wetlands|

F Lakeshire |N|Fly to Lakeshire in Redridge Mountains| |Z|Redridge Mountains|
A What Comes Around... |QID|386| |N|Guard Berton (26.3, 46.6)| |Z|Redridge Mountains|

F Darkshire |N|Fly to Darkshire in Duskwood| |Z|Duskwood|
A Crime and Punishment |QID|377| |N|Councilman Millstipe (71.9, 47.8)| |Z|Duskwood|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City|
T Robb's Report |QID|55220| |N|Master Mathias Shaw (78.3, 70.7)| |Z|Stormwind City|
A The Stockade Search |QID|55221| |N|Master Mathias Shaw (78.3, 70.7)| |Z|Stormwind City|
A The Color of Blood |QID|388| |N|Nikova Raskol (73.3, 55.5)| |Z|Stormwind City|
A Quell The Uprising |QID|387| |N|Warden Thelwater (51.5, 69.4)| |Z|Stormwind City|
A The Stockade Riots |QID|391| |N|Warden Thelwater (51.5, 69.4)| |Z|Stormwind City| |O| |PRE|389|

R The Stockade |N|The prison's door is on the canal between the Mage Quarter and the Trade District (50.8, 67.6)| |Z|Stormwind City|
C The Stockade Search |QID|55221| |N|Delve into the Stockades and find information on Martin Corinth. Report your findings to Mathias Shaw|
C Quell The Uprising |QID|387| |N|Warden Thelwater of Stormwind wants you to kill 10 Defias Prisoners, 8 Defias Convicts, and 8 Defias Insurgents in The Stockade|
C The Color of Blood |QID|388| |N|Nikova Raskol of Stormwind wants you to collect 10 Red Wool Bandanas|
K Targorr the Dread |N|He dual wields with Thrash, and enrages at 30% health.| |TANK|Save a cooldown for his enrage at 30%.| |HEAL|Damage on the tank jumps when he enrages.| |DPS|Burn him down from 30%.| |BOSS|Targorr the Dread|
C What Comes Around... |QID|386| |N|Get the head of Targorr the Dread|
K Kam Deepfury |N|A warrior in Defensive Stance: Shield Slam stuns for 2 seconds, and Shield Wall cuts the damage he takes by 60% for 12 seconds.| |DPS|Hold your big cooldowns while Shield Wall is up.| |BOSS|Kam Deepfury|
C The Fury Runs Deep |QID|378| |N|Motley Garmason wants Kam Deepfury's head brought to him at Dun Modr|
K Hamhock |N|Chain Lightning jumps between three players, and Bloodlust speeds up him and his allies.| |HEAL|Don't stand bunched up, or Chain Lightning hits more of you.| |DPS|Interrupt Chain Lightning; Purge or Dispel Magic his Bloodlust (Shaman, Priest).| |BOSS|Hamhock|
K Bazil Thredd |N|Smoke Bomb stuns everyone near him for 4 seconds, and Battle Shout raises his attack power.| |HEAL|Stand out of Smoke Bomb's reach so you can keep healing.| |DPS|Ranged stand back from the smoke.| |BOSS|Bazil Thredd|
C The Stockade Riots |QID|391| |N|Kill Bazil Thredd and bring his head back| |O|
K Bruegal Ironknuckle |N|Rare: not always here. No special abilities known.| |BOSS|Bruegal Ironknuckle| |O|
K Dextren Ward |N|Intimidating Shout fears everyone near him for 6 seconds.| |TANK|Clear the cells around him first: feared players run into more prisoners.| |HEAL|Fear Ward or Tremor Totem help; stand at range.| |DPS|Ranged stand back out of the shout.| |BOSS|Dextren Ward|
C Crime and Punishment |QID|377| |N|Councilman Millstipe of Darkshire wants you to bring him the hand of Dextren Ward|

N Back outside |N|Out of The Stockade, in Stormwind City|
T The Stockade Search |QID|55221| |N|Master Mathias Shaw (78.3, 70.7)| |Z|Stormwind City|
A Investigating Corinth |QID|55222| |N|Master Mathias Shaw (78.3, 70.7)| |Z|Stormwind City|
T The Color of Blood |QID|388| |N|Nikova Raskol (73.3, 55.5)| |Z|Stormwind City|
T Quell The Uprising |QID|387| |N|Warden Thelwater (51.5, 69.4)| |Z|Stormwind City|
T The Stockade Riots |QID|391| |N|Warden Thelwater (51.5, 69.4)| |Z|Stormwind City| |O|
A The Curious Visitor |QID|392| |N|Warden Thelwater (51.5, 69.4)| |Z|Stormwind City| |O| |PRE|391|
T The Curious Visitor |QID|392| |N|Baros Alexston (57.7, 47.9)| |Z|Stormwind City| |O|
A Shadow of the Past |QID|393| |N|Baros Alexston (57.7, 47.9)| |Z|Stormwind City| |O| |PRE|392|
T Shadow of the Past |QID|393| |N|Master Mathias Shaw (78.3, 70.7)| |Z|Stormwind City| |O|
A Look to an Old Friend |QID|350| |N|Master Mathias Shaw (78.3, 70.7)| |Z|Stormwind City| |O| |PRE|393|
T Look to an Old Friend |QID|350| |N|Elling Trias (66, 74.1)| |Z|Stormwind City| |O|
A Infiltrating the Castle |QID|2745| |N|Elling Trias (66, 74.1)| |Z|Stormwind City| |O| |PRE|350|
T Infiltrating the Castle |QID|2745| |N|Tyrion (73.2, 35.7)| |Z|Stormwind City| |O|
A Items of Some Consequence |QID|2746| |N|Tyrion (73.2, 35.7)| |Z|Stormwind City| |O| |PRE|2745|

F Darkshire |N|Fly to Darkshire in Duskwood| |Z|Duskwood|
T Crime and Punishment |QID|377| |N|Councilman Millstipe (71.9, 47.8)| |Z|Duskwood|

F Lakeshire |N|Fly to Lakeshire in Redridge Mountains| |Z|Redridge Mountains|
T What Comes Around... |QID|386| |N|Guard Berton (26.3, 46.6)| |Z|Redridge Mountains|

F Menethil Harbor |N|Fly to Menethil Harbor in the Wetlands| |Z|Wetlands|
T Investigating Corinth |QID|55222| |N|Innkeeper Helbrek (10.7, 61)| |Z|Wetlands|
T The Fury Runs Deep |QID|378| |N|Motley Garmason (49.7, 18.2)| |Z|Wetlands|

N The Stockade again |N|What you have handed in leads back to The Stockade|

R The Stockade |N|The prison's door is on the canal between the Mage Quarter and the Trade District (50.8, 67.6)| |Z|Stormwind City|
C Items of Some Consequence |QID|2746| |N|Get 3 Silk Cloth and 2 of Clara's Fresh Apples, outside too (51.4, 68.2) (55.1, 5) (27.6, 52.3)| |Z|Stormwind City| |O|

N Back outside |N|Out of The Stockade, in Stormwind City|
T Items of Some Consequence |QID|2746| |N|Tyrion (73.2, 35.7)| |Z|Stormwind City| |O|

N Done |N|That is every quest for The Stockade|

]]
end)
