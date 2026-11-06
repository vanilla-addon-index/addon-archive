-- Dungeon guide: Windhorn Canyon, Horde
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Windhorn Canyon (26-30)", nil, "Horde", function()

return [[

N Windhorn Canyon |N|Every quest for Windhorn Canyon: picked up, then the way in, what each asks for inside, and the hand-ins after|

F Freewind Post |N|Fly to Freewind Post in Thousand Needles| |Z|Thousand Needles|
A Message to Freewind Post |QID|4542| |N|Brave Moonhorn (32.2, 22.2)| |Z|Thousand Needles|
A Relics of the Windhorn Tribe |QID|41977| |N|Sagh (30.7, 44.9)| |Z|Thousand Needles|
A The Wrath of Malgan |QID|41978| |N|Malgan Windhorn (31.5, 45.4)| |Z|Thousand Needles|
T Message to Freewind Post |QID|4542| |N|Cliffwatcher Longhorn (45.7, 50.7)| |Z|Thousand Needles|
A Pacify the Centaur |QID|4841| |N|Cliffwatcher Longhorn (45.7, 50.7)| |Z|Thousand Needles|
C Pacify the Centaur |QID|4841| |N|Kill 12 Galak Scouts, 10 Galak Wranglers, and 6 Galak Windchasers (43.5, 39)| |Z|Thousand Needles|
T Pacify the Centaur |QID|4841| |N|Cliffwatcher Longhorn (45.7, 50.7)| |Z|Thousand Needles|
A Grimtotem Spying |QID|5064| |N|Cliffwatcher Longhorn (45.7, 50.7)| |Z|Thousand Needles|
C Grimtotem Spying |QID|5064| |N|Locate and retrieve the three Secret Notes in Darkcloud Pinnacle: Secret Note #1, Secret Note #2, Secret Note #3 (36.6, 40.8) (31.8, 32.6)| |Z|Thousand Needles|
T Grimtotem Spying |QID|5064| |N|Cliffwatcher Longhorn (45.7, 50.7)| |Z|Thousand Needles|
A Rumors of the Deathtotem |QID|41979| |N|Cliffwatcher Longhorn (45.7, 50.7)| |Z|Thousand Needles|

R Thunder Bluff |N|Travel to Thunder Bluff| |Z|Thunder Bluff|
T Rumors of the Deathtotem |QID|41979| |N|Cairne Bloodhoof (60.3, 51.7)| |Z|Thunder Bluff|
A Information for Cairne |QID|41981| |N|Rahauro (70.1, 29.5)| |Z|Thunder Bluff|
T Information for Cairne |QID|41981| |N|Cairne Bloodhoof (60.3, 51.7)| |Z|Thunder Bluff|
A Destroy the Deathtotem |QID|41982| |N|Cairne Bloodhoof (60.3, 51.7)| |Z|Thunder Bluff|

R Windhorn Canyon |N|Into the Windhorn Caverns, in the east of Thousand Needles by the meeting stone (64, 53.7): the canyon is at their far end (64.6, 45.9)| |Z|Thousand Needles|
C Relics of the Windhorn Tribe |QID|41977| |N|Gather 8 Windhorn Relics in the canyon|
C The Wrath of Malgan |QID|41978| |N|Kill 20 Blackwind Villagers|
K Pathun Duskhide |N|Pathfinder has no notes on this fight yet.| |BOSS|Pathun Duskhide|
K Ahgk'tos the Pure |N|Pathfinder has no notes on this fight yet.| |BOSS|Ahgk'tos the Pure|
K Ambassador Vortalus |N|Gust of Wind stuns a player for 4 seconds, and Chain Lightning jumps between everyone.| |HEAL|Chain Lightning hits the whole group.| |DPS|Interrupt both, Gust of Wind first.| |BOSS|Ambassador Vortalus|
K Walgan Bloodcaller |N|Pathfinder has no notes on this fight yet.| |BOSS|Walgan Bloodcaller|
K Bonespeaker Narlgom |N|Pathfinder has no notes on this fight yet.| |BOSS|Bonespeaker Narlgom|
K Prophet Stormhoof |N|Corruption, a curse, burns a player over time.| |HEAL|Remove Corruption (Curse: Mage, Druid).| |BOSS|Prophet Stormhoof|
C Destroy the Deathtotem |QID|41982| |N|Kill Prophet Stormhoof, the leader of the Deathtotem|
K Chieftain Shalk Blackwind |N|Pathfinder has no notes on this fight yet.| |BOSS|Chieftain Shalk Blackwind|

N Back outside |N|Out of Windhorn Canyon, in Thousand Needles|
T Relics of the Windhorn Tribe |QID|41977| |N|Sagh (30.7, 44.9)| |Z|Thousand Needles|
T The Wrath of Malgan |QID|41978| |N|Malgan Windhorn (31.5, 45.4)| |Z|Thousand Needles|

R Thunder Bluff |N|Travel to Thunder Bluff| |Z|Thunder Bluff|
T Destroy the Deathtotem |QID|41982| |N|Cairne Bloodhoof (60.3, 51.7)| |Z|Thunder Bluff|

F Sun Rock Retreat |N|Fly to Sun Rock Retreat in the Stonetalon Mountains| |Z|Stonetalon Mountains| |C|Shaman|
A Windtorn Crest Stone |QID|41938| |N|Windtorn Crest Stone: right-click it to start the quest| |Z|Stonetalon Mountains| |U|42206| |C|Shaman| |O|
T Windtorn Crest Stone |QID|41938| |N|Shovu (46.9, 71.9)| |Z|Stonetalon Mountains| |C|Shaman| |O|
A Vortalus’ Edict |QID|41939| |N|Shovu (46.9, 71.9)| |Z|Stonetalon Mountains| |C|Shaman| |O| |PRE|41938|

N Windhorn Canyon again |N|What you have handed in leads back to Windhorn Canyon|

R Windhorn Canyon |N|Into the Windhorn Caverns, in the east of Thousand Needles by the meeting stone (64, 53.7): the canyon is at their far end (64.6, 45.9)| |Z|Thousand Needles|
K Ambassador Vortalus |N|Gust of Wind stuns a player for 4 seconds, and Chain Lightning jumps between everyone.| |HEAL|Chain Lightning hits the whole group.| |DPS|Interrupt both, Gust of Wind first.| |BOSS|Ambassador Vortalus|
C Vortalus’ Edict |QID|41939| |N|Banish Ambassador Vortalus, the elemental figurehead| |C|Shaman| |O|

F Sun Rock Retreat |N|Fly to Sun Rock Retreat in the Stonetalon Mountains| |Z|Stonetalon Mountains| |C|Shaman| |O| |PRE|41938|
T Vortalus’ Edict |QID|41939| |N|Shovu (46.9, 71.9)| |Z|Stonetalon Mountains| |C|Shaman| |O|

N Done |N|That is every quest for Windhorn Canyon|

]]
end)
