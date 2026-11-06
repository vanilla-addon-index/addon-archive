-- Dungeon guide: Frostmane Hollow, Alliance
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Frostmane Hollow (13-20)", nil, "Alliance", function()

return [[

N Frostmane Hollow |N|Every quest for Frostmane Hollow: picked up, then the way in, what each asks for inside, and the hand-ins after|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City|
A Searching for Archaeologist Evenpike |QID|42006| |N|Brohann Caskbelly (69.5, 40.4)| |Z|Stormwind City|

R Alah'Thalas |N|Travel to Alah'Thalas| |Z|Alah'Thalas|
A The Finest Pelt |QID|42008| |N|Shandlar Thethis (45.3, 46.2)| |Z|Alah'Thalas|

R Dun Morogh |N|Travel to Dun Morogh| |Z|Dun Morogh|
A The Frostmane War |QID|42038| |N|Mountaineer Granitebeard (70.9, 35.5)| |Z|Dun Morogh|
C The Frostmane War |QID|42038| |N|Kill 8 Frostmane Scouts, 6 Frostmane Drudges and 6 Frostmane Mystics round the airfield (70.1, 39.7) (66.8, 38.6) (67.2, 40.9)| |Z|Dun Morogh|
T The Frostmane War |QID|42038| |N|Mountaineer Granitebeard (70.9, 35.5)| |Z|Dun Morogh|
A Chieftain Ubukaz |QID|42039| |N|Mountaineer Granitebeard (70.9, 35.5)| |Z|Dun Morogh|

R Frostmane Hollow |N|By the Ironforge Airfield, in the east of Dun Morogh; the meeting stone is just south (65.9, 42.4) (66.9, 40.3)| |Z|Dun Morogh|
A A Grave Misunderstanding! |QID|42040| |N|Ranix Crackbolt|
C A Grave Misunderstanding! |QID|42040| |N|Recover the Tablet of Kaz'gan for Ranix Crackbolt within Frostmane Hollow|
T A Grave Misunderstanding! |QID|42040| |N|Ranix Crackbolt|
C Searching for Archaeologist Evenpike |QID|42006| |N|Search for Archeologist Evenpike inside Frostmane Hollow in Dun Morogh|
T Searching for Archaeologist Evenpike |QID|42006| |N|Archaeologist Evenpike|
A The Shattered Disc |QID|42007| |N|Archaeologist Evenpike|
C The Finest Pelt |QID|42008| |N|Enter Frostmane Hollow in Dun Morogh and acquire a flawless leopard pelt|
K Tan'sha the Sleek |N|Tan'sha the Sleek fights with Handler Oboka.| |BOSS|Tan'sha the Sleek|
K Battlemaster Ubukaz |N|At 20% he enrages and hits much harder.| |TANK|Save a cooldown for 20%.| |HEAL|Expect big hits from 20%.| |DPS|Burn the last 20% fast.| |BOSS|Battlemaster Ubukaz|
C Chieftain Ubukaz |QID|42039| |N|Slay Battlemaster Ubukaz deep within Frostmane Hollow|
K Kan'za the Seer |N|He starts with two Frostmane Snowcallers, and casts Blizzard and Frostbolt.| |HEAL|Move out of Blizzard.| |DPS|Kill the Snowcallers first; interrupt Blizzard and Frostbolt.| |BOSS|Kan'za the Seer|
K Hailar the Frigid |N|Five Frostmane Ritualists heal him while they live. Flash Freeze hits and freezes everyone within 10 yards for up to 5 seconds.| |TANK|Flash Freeze roots you: keep him away from the group.| |HEAL|Stand more than 10 yards from him.| |DPS|Kill the Ritualists first: he can't die while they heal him. Interrupt Frostbolt.| |BOSS|Hailar the Frigid|

N Back outside |N|Out of Frostmane Hollow, in Dun Morogh|
T Chieftain Ubukaz |QID|42039| |N|Mountaineer Granitebeard (70.9, 35.5)| |Z|Dun Morogh|

R Alah'Thalas |N|Travel to Alah'Thalas| |Z|Alah'Thalas|
T The Finest Pelt |QID|42008| |N|Shandlar Thethis (45.3, 46.2)| |Z|Alah'Thalas|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City|
T The Shattered Disc |QID|42007| |N|Brohann Caskbelly (69.5, 40.4)| |Z|Stormwind City|

N Done |N|That is every quest for Frostmane Hollow|

]]
end)
