-- Dungeon guide: Uldaman, Alliance
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Uldaman (41-51)", nil, "Alliance", function()

return [[

N Uldaman |N|Every quest for Uldaman: picked up, then the way in, what each asks for inside, and the hand-ins after|

N Given elsewhere |N|Also for Uldaman, not on this guide's way: Power in Uldaman (Mage), from Tabetha in Dustwallow Marsh|

R Ironforge |N|Travel to Ironforge| |Z|Ironforge|
A Ironband Wants You! |QID|707| |N|Prospector Stormpike (74.6, 11.7)| |Z|Ironforge|
A The Lost Dwarves |QID|2398| |N|Prospector Stormpike (74.6, 11.7)| |Z|Ironforge|
A Reclaimed Treasures |QID|1360| |N|Krom Stoutarm (74.2, 9.4)| |Z|Ironforge|

F Thelsamar |N|Fly to Thelsamar in Loch Modan| |Z|Loch Modan|
T Ironband Wants You! |QID|707| |N|Prospector Ironband (65.9, 65.6)| |Z|Loch Modan|
A Find Agmond |QID|738| |N|Prospector Ironband (65.9, 65.6)| |Z|Loch Modan|
A Badlands Reagent Run |QID|2500| |N|Ghak Healtouch (37.1, 49.4)| |Z|Loch Modan|

R Badlands |N|Travel to the Badlands| |Z|Badlands|
T Find Agmond |QID|738| |N|Battered Dwarven Skeleton (50.9, 62.4)| |Z|Badlands|
A Murdaloc |QID|739| |N|Battered Dwarven Skeleton (50.9, 62.4)| |Z|Badlands|
C Murdaloc |QID|739| |N|Slay Agmond's killer, Murdaloc.  Slay 12 Stonevault Bonesnappers.  Report (50.4, 68.3)| |Z|Badlands|
A Solution to Doom |QID|709| |N|Theldurin the Lost (51.4, 76.9)| |Z|Badlands|
C Badlands Reagent Run |QID|2500| |N|Acquire the reagents Ghak Healtouch needs from the Badlands: Crag Coyote Fang, Buzzard Gizzard, Rock Elemental Shard (57.2, 59.1) (34.9, 70.9) (42.5, 79.6)| |Z|Badlands|
A Power Stones |QID|2418| |N|Rigglefuzz (42.4, 52.9)| |Z|Badlands|
A A Sign of Hope |QID|720| |N|Crumpled Map (53, 33.9)| |Z|Badlands|
T A Sign of Hope |QID|720| |N|Prospector Ryedol (53.4, 43.4)| |Z|Badlands|
A A Sign of Hope |QID|721| |N|Prospector Ryedol (53.4, 43.4)| |Z|Badlands|

F Thelsamar |N|Fly to Thelsamar in Loch Modan| |Z|Loch Modan|
T Badlands Reagent Run |QID|2500| |N|Ghak Healtouch (37.1, 49.4)| |Z|Loch Modan|
A Uldaman Reagent Run |QID|17| |N|Ghak Healtouch (37.1, 49.4)| |Z|Loch Modan|
T Murdaloc |QID|739| |N|Prospector Ironband (65.9, 65.6)| |Z|Loch Modan|
A Agmond's Fate |QID|704| |N|Prospector Ironband (65.9, 65.6)| |Z|Loch Modan|

R Uldaman |N|In the north of the Badlands: past the dig site (39.6, 18.5) to the temple doors (43, 13.9)| |Z|Badlands|
T A Sign of Hope |QID|721| |N|Hammertoe Grez|
C Power Stones |QID|2418| |N|Get 8 Dentrium Power Stones and 8 An'Alleum Power Stones, outside too (43.2, 11.8) (39.1, 18.4)| |Z|Badlands|
C Agmond's Fate |QID|704| |N|Get 4 Carved Stone Urns, outside too (40.2, 16.6) (42.8, 10)| |Z|Badlands|
C Solution to Doom |QID|709| |N|Loot the Tablet of Ryun'eh from the Ancient Chest in the dig site, outside the instance, outside too (39.3, 18.8)| |Z|Badlands|
A Amulet of Secrets |QID|722| |N|Hammertoe Grez|
C Amulet of Secrets |QID|722| |N|Find Hammertoe's Amulet, outside too (38.7, 18.1)| |Z|Badlands|
T Amulet of Secrets |QID|722| |N|Hammertoe Grez|
A Prospect of Faith |QID|723| |N|Hammertoe Grez|
T The Lost Dwarves |QID|2398| |N|Baelog|
C Uldaman Reagent Run |QID|17| |N|Get 12 Magenta Fungus Caps, outside too (40.9, 12.8)| |Z|Badlands|
C Reclaimed Treasures |QID|1360| |N|Get Krom Stoutarm's treasured possession from his chest in the North Common Hall of Uldaman|
A The Platinum Discs |QID|2278| |N|The Discs of Norgannon|
T The Platinum Discs |QID|2278| |N|The Discs of Norgannon|
A The Platinum Discs |QID|2279| |N|The Discs of Norgannon|
A The Hidden Chamber |QID|2240| |N|Baelog|
K The Lost Dwarves |N|Baelog, Eric and Olaf fight together.| |TANK|Gather all three on you.| |DPS|Kill them one at a time.|
C The Hidden Chamber |QID|2240| |N|Explore: Read Baelog's Journal, explore the hidden chamber, then report to Prospector Stormpike.|
K Revelosh |N|Lightning Bolt and Chain Lightning.| |DPS|Interrupt both.| |BOSS|Revelosh|
K Ironaya |N|War Stomp stuns everyone near her, Knock Away throws her target, and Arcing Smash hits in front.| |TANK|Face her away, with your back to a wall.| |HEAL|Stand out of War Stomp's reach.| |DPS|Melee from behind; ranged back from the stomp.| |BOSS|Ironaya|
K Obsidian Sentinel |N|At every fifth of its health it breaks off an Obsidian Shard.| |TANK|Pick up each shard.| |DPS|Kill the shards as they come.| |BOSS|Obsidian Sentinel|
K Ancient Stone Keeper |N|Sand Storms send whirling storms round the room.| |HEAL|Keep away from the storms.| |DPS|Keep away from the storms.| |BOSS|Ancient Stone Keeper|
K Galgann Firehammer |N|Fire Nova around him, Flame Shock, Flame Lash, and Amplify Flames, which raises the fire damage you take.| |HEAL|Dispel Amplify Flames and Flame Shock (Magic: Priest, Paladin).| |DPS|Interrupt Flame Lash; ranged stand back from Fire Nova.| |BOSS|Galgann Firehammer|
K Grimlok |N|A trogg shaman: Lightning Bolt, Chain Bolt, Shrink (a curse) and a Tremor Totem; Bloodlust when his basilisk dies.| |HEAL|Remove Shrink (Curse: Mage, Druid).| |DPS|Interrupt Lightning Bolt and Chain Bolt; kill the Tremor Totem so fears work.| |BOSS|Grimlok|
K Archaedas |N|While he stands above a third of his health he wakes earthen dwarves; at two-thirds he wakes the Earthen Guardians, at one-third the Vault Warders. Ground Tremor stuns everyone near him.| |TANK|Pick up what he wakes.| |HEAL|Stand out of Ground Tremor.| |DPS|Kill what he wakes; the Vault Warders are tough.| |BOSS|Archaedas|

N Back outside |N|Out of Uldaman, in the Badlands|
T Power Stones |QID|2418| |N|Rigglefuzz (42.4, 52.9)| |Z|Badlands|
A The Shattered Necklace |QID|2198| |N|Shattered Necklace: right-click it to start the quest| |Z|Badlands| |U|7666| |O|
T Prospect of Faith |QID|723| |N|Prospector Ryedol (53.4, 43.4)| |Z|Badlands|
A Prospect of Faith |QID|724| |N|Prospector Ryedol (53.4, 43.4)| |Z|Badlands|
T Solution to Doom |QID|709| |N|Theldurin the Lost (51.4, 76.9)| |Z|Badlands|
A To Ironforge for Yagyin's Digest |QID|727| |N|Theldurin the Lost (51.4, 76.9)| |Z|Badlands|

F Thelsamar |N|Fly to Thelsamar in Loch Modan| |Z|Loch Modan|
T Agmond's Fate |QID|704| |N|Prospector Ironband (65.9, 65.6)| |Z|Loch Modan|
T Uldaman Reagent Run |QID|17| |N|Ghak Healtouch (37.1, 49.4)| |Z|Loch Modan|

R Ironforge |N|Travel to Ironforge| |Z|Ironforge|
T Prospect of Faith |QID|724| |N|Historian Karnik (77.5, 11.8)| |Z|Ironforge|
A Passing Word of a Threat |QID|725| |N|Historian Karnik (77.5, 11.8)| |Z|Ironforge|
T Passing Word of a Threat |QID|725| |N|Advisor Belgrum (77.3, 9.7)| |Z|Ironforge|
A Passing Word of a Threat |QID|726| |N|Advisor Belgrum (77.3, 9.7)| |Z|Ironforge|
T Passing Word of a Threat |QID|726| |N|Historian Karnik (77.5, 11.8)| |Z|Ironforge|
A An Ambassador of Evil |QID|762| |N|Historian Karnik (77.5, 11.8)| |Z|Ironforge|
T The Hidden Chamber |QID|2240| |N|Prospector Stormpike (74.6, 11.7)| |Z|Ironforge|
T Reclaimed Treasures |QID|1360| |N|Krom Stoutarm (74.2, 9.4)| |Z|Ironforge|
T The Platinum Discs |QID|2279| |N|High Explorer Magellas (69.9, 18.6)| |Z|Ironforge|
A The Platinum Discs |QID|2439| |N|High Explorer Magellas (69.9, 18.6)| |Z|Ironforge|
T To Ironforge for Yagyin's Digest |QID|727| |N|Gerrig Bonegrip (50.8, 5.6)| |Z|Ironforge|
T The Shattered Necklace |QID|2198| |N|Talvash del Kissel (36.4, 3.6)| |Z|Ironforge| |O|
A Lore for a Price |QID|2199| |N|Talvash del Kissel (36.4, 3.6)| |Z|Ironforge| |O| |PRE|2198|
T Lore for a Price |QID|2199| |N|Talvash del Kissel (36.4, 3.6)| |Z|Ironforge| |O|
A Back to Uldaman |QID|2200| |N|Talvash del Kissel (36.4, 3.6)| |Z|Ironforge| |O| |PRE|2199|
T The Platinum Discs |QID|2439| |N|Dinita Stonemantle (33.5, 60.2)| |Z|Ironforge|
A Portents of Uldum |QID|2963| |N|High Explorer Magellas (69.9, 18.6)| |Z|Ironforge|
T Portents of Uldum |QID|2963| |N|Historian Karnik (77.5, 11.8)| |Z|Ironforge|

N Uldaman again |N|What you have handed in leads back to Uldaman|

R Badlands |N|Travel to the Badlands| |Z|Badlands|
C An Ambassador of Evil |QID|762| |N|Kill Ambassador Infernus in Angor Fortress and bring proof of his death: Ambassador Infernus' Bracer (42.1, 28.9)| |Z|Badlands|

R Uldaman |N|In the north of the Badlands: past the dig site (39.6, 18.5) to the temple doors (43, 13.9)| |Z|Badlands|
C Back to Uldaman |QID|2200| |N|Search for clues as to the current disposition of Talvash's necklace within Uldaman.  The slain paladin he mentioned was the person who has it last| |O|
T Back to Uldaman |QID|2200| |N|Remains of a Paladin| |O|
A Find the Gems |QID|2201| |N|Remains of a Paladin| |O| |PRE|2200|
K Grimlok |N|A trogg shaman: Lightning Bolt, Chain Bolt, Shrink (a curse) and a Tremor Totem; Bloodlust when his basilisk dies.| |HEAL|Remove Shrink (Curse: Mage, Druid).| |DPS|Interrupt Lightning Bolt and Chain Bolt; kill the Tremor Totem so fears work.| |BOSS|Grimlok|
C Find the Gems |QID|2201| |N|Find the ruby, sapphire, and topaz that are scattered throughout Uldaman.  Once acquired, contact Talvash del Kissel remotely by using the Phial of Scrying he previously gave you.  From the journal, you know... * The ruby has been stashed in a barricaded Shadowforge area. * The topaz has been hidden in an urn in one of the Trogg areas, near some Alliance dwarves.  * The sapphire has been claimed by Grimlok, the trogg leader| |O|

R Ironforge |N|Travel to Ironforge| |Z|Ironforge|
T Find the Gems |QID|2201| |N|Talvash del Kissel (36.4, 3.6)| |Z|Ironforge| |O|
A Restoring the Necklace |QID|2204| |N|Talvash del Kissel (36.4, 3.6)| |Z|Ironforge| |O| |PRE|2201|
T An Ambassador of Evil |QID|762| |N|Advisor Belgrum (77.3, 9.7)| |Z|Ironforge|
A The Lost Tablets of Will |QID|1139| |N|Advisor Belgrum (77.3, 9.7)| |Z|Ironforge|

N Uldaman again |N|What you have handed in leads back to Uldaman|

R Uldaman |N|In the north of the Badlands: past the dig site (39.6, 18.5) to the temple doors (43, 13.9)| |Z|Badlands|
C Restoring the Necklace |QID|2204| |N|Obtain a power source from the most powerful construct you can find in Uldaman| |O|
C The Lost Tablets of Will |QID|1139| |N|Find the Tablet of Will|

R Ironforge |N|Travel to Ironforge| |Z|Ironforge|
T Restoring the Necklace |QID|2204| |N|Talvash del Kissel (36.4, 3.6)| |Z|Ironforge| |O|
A Restoring the Necklace |QID|2361| |N|Talvash del Kissel (36.4, 3.6)| |Z|Ironforge| |O| |PRE|2204|
T Restoring the Necklace |QID|2361| |N|Talvash del Kissel (36.4, 3.6)| |Z|Ironforge| |O|
T The Lost Tablets of Will |QID|1139| |N|Advisor Belgrum (77.3, 9.7)| |Z|Ironforge|

N Done |N|That is every quest for Uldaman|

]]
end)
