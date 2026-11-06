-- Dungeon guide: Blackfathom Deeps, Horde
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Blackfathom Deeps (24-32)", nil, "Horde", function()

return [[

N Blackfathom Deeps |N|Every quest for Blackfathom Deeps: picked up, then the way in, what each asks for inside, and the hand-ins after|

N Given elsewhere |N|Also for Blackfathom Deeps, not on this guide's way: The Orb of Soran'ruk (Warlock), from Doan Karhan in The Barrens|

F Sun Rock Retreat |N|Fly to Sun Rock Retreat in the Stonetalon Mountains| |Z|Stonetalon Mountains|
A Trouble in the Deeps |QID|6562| |N|Tsunaman (50.1, 65.3)| |Z|Stonetalon Mountains|

F Splintertree Post |N|Fly to Splintertree Post in Ashenvale| |Z|Ashenvale|
T Trouble in the Deeps |QID|6562| |N|Je'neu Sancrea (11.6, 34.3)| |Z|Ashenvale|
A The Essence of Aku'Mai |QID|6563| |N|Je'neu Sancrea (11.6, 34.3)| |Z|Ashenvale|
A Amongst the Ruins |QID|6921| |N|Je'neu Sancrea (11.6, 34.3)| |Z|Ashenvale|
A The Moonshrine Ruins |QID|41812| |N|Aelennia Starbloom (17.3, 26)| |Z|Ashenvale|
C The Essence of Aku'Mai |QID|6563| |N|Get 20 Sapphires of Aku'Mai (14.4, 10.9)| |Z|Ashenvale|
T The Essence of Aku'Mai |QID|6563| |N|Je'neu Sancrea (11.6, 34.3)| |Z|Ashenvale|

R Blackfathom Deeps |N|Out along the Zoram Strand to the sunken temple in the north-west; swim down into it (14.1, 14.4)| |Z|Ashenvale|
C The Moonshrine Ruins |QID|41812| |N|Traverse into the depths of Blackfathom Deeps and recover a 'Seed of Bloom' from within the Moonshrine Ruins. Once acquired|
A Blackfathom Villainy |QID|6561| |N|Argent Guard Thaelrid|
C Amongst the Ruins |QID|6921| |N|Get the Fathom Core|
K Ghamoo-ra |N|Trample hits everyone near him.| |HEAL|Trample hits the melee group.| |BOSS|Ghamoo-ra|
K Lady Sarevess |N|Frost Nova roots everyone near her, Slow slows a player, and Forked Lightning hits everyone in front of her.| |TANK|Face her away from the group.| |HEAL|Dispel Frost Nova and Slow (Magic: Priest, Paladin).| |DPS|Interrupt Forked Lightning; keep out of her front.| |BOSS|Lady Sarevess|
K Gelihast |N|Gelihast throws a Net that roots a player.| |BOSS|Gelihast|
K Lorgus Jett |N|A shaman: Lightning Bolt, and a Lightning Shield that hurts whoever hits him.| |DPS|Interrupt Lightning Bolt; Purge or Dispel Magic his Lightning Shield (Shaman, Priest).| |BOSS|Lorgus Jett|
K Velthelaxx the Defiler |N|Pathfinder has no notes on this fight yet.| |BOSS|Velthelaxx the Defiler|
K Old Serra'kis |N|No special abilities known.| |BOSS|Old Serra'kis|
K Twilight Lord Kelris |N|Sleep puts players near him to sleep, and Mind Blast hits hard.| |HEAL|Dispel Sleep (Magic: Priest, Paladin), the tank first.| |DPS|Interrupt Sleep and Mind Blast.| |BOSS|Twilight Lord Kelris|
C Blackfathom Villainy |QID|6561| |N|Get the head of Twilight Lord Kelris|
K Aku'mai |N|Poison Cloud poisons everyone near her; at 30% Frenzied Rage makes her hit harder and faster.| |TANK|Save a cooldown for 30%.| |HEAL|Cure Poison Cloud (Poison: Druid, Shaman, Paladin); damage jumps at 30%.| |DPS|Burn her down from 30%.| |BOSS|Aku'mai|

N Back outside |N|Out of Blackfathom Deeps, in Ashenvale|
T The Moonshrine Ruins |QID|41812| |N|Aelennia Starbloom (17.3, 26)| |Z|Ashenvale|
A Allegiance to the Old Gods |QID|6564| |N|Damp Note: right-click it to start the quest| |Z|Ashenvale| |U|16790| |O|
T Amongst the Ruins |QID|6921| |N|Je'neu Sancrea (11.6, 34.3)| |Z|Ashenvale|
T Allegiance to the Old Gods |QID|6564| |N|Je'neu Sancrea (11.6, 34.3)| |Z|Ashenvale| |O|
A Allegiance to the Old Gods |QID|6565| |N|Je'neu Sancrea (11.6, 34.3)| |Z|Ashenvale| |O| |PRE|6564|

R Thunder Bluff |N|Travel to Thunder Bluff| |Z|Thunder Bluff|
T Blackfathom Villainy |QID|6561| |N|Bashana Runetotem (71.1, 34.2)| |Z|Thunder Bluff|

N Blackfathom Deeps again |N|What you have handed in leads back to Blackfathom Deeps|

R Blackfathom Deeps |N|Out along the Zoram Strand to the sunken temple in the north-west; swim down into it (14.1, 14.4)| |Z|Ashenvale|
K Lorgus Jett |N|A shaman: Lightning Bolt, and a Lightning Shield that hurts whoever hits him.| |DPS|Interrupt Lightning Bolt; Purge or Dispel Magic his Lightning Shield (Shaman, Priest).| |BOSS|Lorgus Jett|
C Allegiance to the Old Gods |QID|6565| |N|Kill Lorgus Jett in Blackfathom Deeps| |O|

N Back outside |N|Out of Blackfathom Deeps, in Ashenvale|
T Allegiance to the Old Gods |QID|6565| |N|Je'neu Sancrea (11.6, 34.3)| |Z|Ashenvale| |O|

N Done |N|That is every quest for Blackfathom Deeps|

]]
end)
