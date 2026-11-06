-- Dungeon guide: Blackfathom Deeps, Alliance
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Blackfathom Deeps (24-32)", nil, "Alliance", function()

return [[

N Blackfathom Deeps |N|Every quest for Blackfathom Deeps: picked up, then the way in, what each asks for inside, and the hand-ins after|

N Given elsewhere |N|Also for Blackfathom Deeps, not on this guide's way: The Orb of Soran'ruk (Warlock), from Doan Karhan in The Barrens|

R Ironforge |N|Travel to Ironforge| |Z|Ironforge|
A Knowledge in the Deeps |QID|971| |N|Gerrig Bonegrip (50.8, 5.6)| |Z|Ironforge|

R Darnassus |N|Travel to Darnassus| |Z|Darnassus|
A In Search of Thaelrid |QID|1198| |N|Dawnwatcher Shaedlass (55.4, 25)| |Z|Darnassus|
A Twilight Falls |QID|1199| |N|Argent Guard Manados (55.2, 24)| |Z|Darnassus|

F Auberdine |N|Fly to Auberdine in Darkshore| |Z|Darkshore| |O| |PRE|3765|
A Researching the Corruption |QID|1275| |N|Gershala Nightwhisper (38.3, 43)| |Z|Darkshore| |O| |PRE|3765|

F Astranaar |N|Fly to Astranaar in Ashenvale| |Z|Ashenvale|
A The Moonshrine Ruins |QID|41812| |N|Aelennia Starbloom (17.3, 26)| |Z|Ashenvale|

R Blackfathom Deeps |N|Out along the Zoram Strand to the sunken temple in the north-west; swim down into it (14.1, 14.4)| |Z|Ashenvale|
C Knowledge in the Deeps |QID|971| |N|Get the Lorgalis Manuscript|
T In Search of Thaelrid |QID|1198| |N|Argent Guard Thaelrid|
C Researching the Corruption |QID|1275| |N|Gershala Nightwhisper in Auberdine wants 8 Corrupt Brain stems, outside too (14.7, 10.5)| |Z|Ashenvale| |O|
C Twilight Falls |QID|1199| |N|Get 10 Twilight Pendants|
C The Moonshrine Ruins |QID|41812| |N|Traverse into the depths of Blackfathom Deeps and recover a 'Seed of Bloom' from within the Moonshrine Ruins. Once acquired|
A Blackfathom Villainy |QID|1200| |N|Argent Guard Thaelrid|
K Ghamoo-ra |N|Trample hits everyone near him.| |HEAL|Trample hits the melee group.| |BOSS|Ghamoo-ra|
K Lady Sarevess |N|Frost Nova roots everyone near her, Slow slows a player, and Forked Lightning hits everyone in front of her.| |TANK|Face her away from the group.| |HEAL|Dispel Frost Nova and Slow (Magic: Priest, Paladin).| |DPS|Interrupt Forked Lightning; keep out of her front.| |BOSS|Lady Sarevess|
K Gelihast |N|Gelihast throws a Net that roots a player.| |BOSS|Gelihast|
K Lorgus Jett |N|A shaman: Lightning Bolt, and a Lightning Shield that hurts whoever hits him.| |DPS|Interrupt Lightning Bolt; Purge or Dispel Magic his Lightning Shield (Shaman, Priest).| |BOSS|Lorgus Jett|
K Velthelaxx the Defiler |N|Pathfinder has no notes on this fight yet.| |BOSS|Velthelaxx the Defiler|
K Old Serra'kis |N|No special abilities known.| |BOSS|Old Serra'kis|
K Twilight Lord Kelris |N|Sleep puts players near him to sleep, and Mind Blast hits hard.| |HEAL|Dispel Sleep (Magic: Priest, Paladin), the tank first.| |DPS|Interrupt Sleep and Mind Blast.| |BOSS|Twilight Lord Kelris|
C Blackfathom Villainy |QID|1200| |N|Get the head of Twilight Lord Kelris|
K Aku'mai |N|Poison Cloud poisons everyone near her; at 30% Frenzied Rage makes her hit harder and faster.| |TANK|Save a cooldown for 30%.| |HEAL|Cure Poison Cloud (Poison: Druid, Shaman, Paladin); damage jumps at 30%.| |DPS|Burn her down from 30%.| |BOSS|Aku'mai|

N Back outside |N|Out of Blackfathom Deeps, in Ashenvale|
T The Moonshrine Ruins |QID|41812| |N|Aelennia Starbloom (17.3, 26)| |Z|Ashenvale|

F Auberdine |N|Fly to Auberdine in Darkshore| |Z|Darkshore| |O| |PRE|3765|
T Researching the Corruption |QID|1275| |N|Gershala Nightwhisper (38.3, 43)| |Z|Darkshore| |O|

R Darnassus |N|Travel to Darnassus| |Z|Darnassus|
T Twilight Falls |QID|1199| |N|Argent Guard Manados (55.2, 24)| |Z|Darnassus|
T Blackfathom Villainy |QID|1200| |N|Dawnwatcher Selgorm (56.2, 24.4)| |Z|Darnassus|

R Ironforge |N|Travel to Ironforge| |Z|Ironforge|
T Knowledge in the Deeps |QID|971| |N|Gerrig Bonegrip (50.8, 5.6)| |Z|Ironforge|

N Done |N|That is every quest for Blackfathom Deeps|

]]
end)
