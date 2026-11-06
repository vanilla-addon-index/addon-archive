-- Dungeon guide: The Deadmines, Alliance
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/The Deadmines (17-24)", nil, "Alliance", function()

return [[

N The Deadmines |N|Every quest for The Deadmines: picked up, then the way in, what each asks for inside, and the hand-ins after|

N Given elsewhere |N|Also for The Deadmines, not on this guide's way: The Test of Righteousness (Paladin), from Jordan Stilwell in Dun Morogh|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City|
A Collecting Memories |QID|168| |N|Wilder Thistlenettle (70.3, 40.8)| |Z|Stormwind City|
A Oh Brother. . . |QID|167| |N|Wilder Thistlenettle (70.3, 40.8)| |Z|Stormwind City|
A Underground Assault |QID|2040| |N|Shoni the Shilent (62.6, 34.1)| |Z|Stormwind City| |O| |PRE|2041|
A Drones In Westfall |QID|41390| |N|Renzik "The Shiv" (78.3, 71.1)| |Z|Stormwind City|

F Sentinel Hill |N|Fly to Sentinel Hill in Westfall| |Z|Westfall|
T Drones In Westfall |QID|41390| |N|Agent Kearnen (68.5, 70.1)| |Z|Westfall|
A Venture Delivery |QID|41391| |N|Agent Kearnen (68.5, 70.1)| |Z|Westfall|
C Venture Delivery |QID|41391| |N|Recover valuable documents from the goblin: Order of Alchemical Compounds (71.4, 71.8)| |Z|Westfall|
A The Harvest Golem Mystery |QID|40470| |N|Christopher Hewen (52.2, 52.8)| |Z|Westfall|
A The Defias Brotherhood |QID|65| |N|Gryan Stoutmantle (56.3, 47.5)| |Z|Westfall|
C The Harvest Golem Mystery |QID|40470| |N|Collect a Cracked Animation Rune (53.4, 33.7) (37.4, 49.9) (63.6, 60.7)| |Z|Westfall|
T The Harvest Golem Mystery |QID|40470| |N|Christopher Hewen (52.2, 52.8)| |Z|Westfall|
A The Harvest Golem Mystery |QID|40471| |N|Christopher Hewen (52.2, 52.8)| |Z|Westfall|
C The Harvest Golem Mystery |QID|40471| |N|Gather 10 Intact Animation Runes from Harvest Golems in Westfall (53.7, 32.1) (37.4, 49.9) (53.7, 22.3)| |Z|Westfall|
T The Harvest Golem Mystery |QID|40471| |N|Christopher Hewen (52.2, 52.8)| |Z|Westfall|
A The Harvest Golem Mystery |QID|40472| |N|Christopher Hewen (52.2, 52.8)| |Z|Westfall|
A Food for Sailing Thoughts? |QID|40395| |N|Guide to a Sailor's Stomach (26.1, 16.5)| |Z|Westfall|
T Food for Sailing Thoughts? |QID|40395| |N|Captain Grayson (30, 86)| |Z|Westfall|
A Captain Grayson's Revenge |QID|40396| |N|Captain Grayson (30, 86)| |Z|Westfall|

R The Deadmines |N|In Moonbrook: through the Defias hideout under the inn, and down the mine (42.5, 72.7)| |Z|Westfall|
C Collecting Memories |QID|168| |N|Retrieve 4 Miners' Union Cards, outside too (41.3, 82.1)| |Z|Westfall|
C Oh Brother. . . |QID|167| |N|Get Foreman Thistlenettle's Explorers' League Badge, outside too (42.2, 82.6)| |Z|Westfall|
C Underground Assault |QID|2040| |N|Retrieve the Gnoam Sprecklesprocket from the Deadmines| |O|
A The Unsent Letter |QID|373| |N|An Unsent Letter: right-click it to start the quest| |U|2874| |O|
K Jared Voss |N|Pathfinder has no notes on this fight yet.| |BOSS|Jared Voss|
K Rhahk'Zor |N|Rhahk'Zor Slam hits hard and stuns his target for 3 seconds.| |TANK|Build threat before the others go all out: you'll be stunned now and then.| |HEAL|Expect sudden damage on the tank.| |BOSS|Rhahk'Zor|
K Miner Johnson |N|Rare: not always here. Pierce Armor lowers his target's armour by 10%.| |TANK|He hits harder as your armour drops.| |BOSS|Miner Johnson| |O|
K Sneed |N|Sneed fights in his Shredder first, and jumps out when it breaks. He disarms his target.| |TANK|Disarm takes your weapon for 5 seconds: have threat to spare when it comes.| |BOSS|Sneed|
K Gilnid |N|Molten Metal burns his target and slows their movement and attacks.| |HEAL|Molten Metal burns the tank for 15 seconds.| |DPS|Interrupt Molten Metal.| |BOSS|Gilnid|
K Masterpiece Harvester |N|Pathfinder has no notes on this fight yet.| |BOSS|Masterpiece Harvester|
K Mr. Smite |N|At two-thirds and at one-third health he stuns everyone with Smite Stomp and goes to his chest to change weapons: two axes, then a hammer whose Smite Slam stuns. He parries far more at first.| |TANK|Pick him up again when he comes back from his chest.| |HEAL|Use his trips to the chest to top everyone up and drink.| |DPS|Attack from behind: he parries a lot early on.| |BOSS|Mr. Smite|
K Captain Greenskin |N|Captain Greenskin cleaves everyone in front of him, and his Poisoned Harpoon ticks for a minute.| |TANK|Face him away from the group.| |HEAL|Cure the harpoon's poison (Poison: Druid, Shaman, Paladin).| |DPS|Interrupt Poisoned Harpoon; stay behind him.| |BOSS|Captain Greenskin|
K Edwin VanCleef |N|At half health he calls two Defias Blackguards, and Thrash gives him extra attacks.| |TANK|Pick up the Blackguards when they come.| |HEAL|Thrash makes his damage spiky: keep the tank topped up.| |DPS|Kill the Blackguards, then VanCleef.| |BOSS|Edwin VanCleef|
K Cookie |N|Acid Splash poisons everyone near him; at half health he eats to heal himself.| |HEAL|Cure the Acid Splash poison (Poison: Druid, Shaman, Paladin).| |DPS|Interrupt Cookie's Cooking.| |BOSS|Cookie|
C Captain Grayson's Revenge |QID|40396| |N|End Cookie: Grayson's Pendant|

N Back outside |N|Out of The Deadmines, in Westfall|
T Captain Grayson's Revenge |QID|40396| |N|Captain Grayson (30, 86)| |Z|Westfall|

F Lakeshire |N|Fly to Lakeshire in Redridge Mountains| |Z|Redridge Mountains|
T The Defias Brotherhood |QID|65| |N|Wiley the Black (26.5, 45.3)| |Z|Redridge Mountains|
A The Defias Brotherhood |QID|132| |N|Wiley the Black (26.5, 45.3)| |Z|Redridge Mountains|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City|
T The Harvest Golem Mystery |QID|40472| |N|Lilliam Sparkspindle (62.1, 30.3)| |Z|Stormwind City|
A The Harvest Golem Mystery |QID|40473| |N|Lilliam Sparkspindle (62.1, 30.3)| |Z|Stormwind City|
T Underground Assault |QID|2040| |N|Shoni the Shilent (62.6, 34.1)| |Z|Stormwind City| |O|
T Collecting Memories |QID|168| |N|Wilder Thistlenettle (70.3, 40.8)| |Z|Stormwind City|
T Oh Brother. . . |QID|167| |N|Wilder Thistlenettle (70.3, 40.8)| |Z|Stormwind City|
T The Unsent Letter |QID|373| |N|Baros Alexston (57.7, 47.9)| |Z|Stormwind City| |O|
A Bazil Thredd |QID|389| |N|Baros Alexston (57.7, 47.9)| |Z|Stormwind City| |O| |PRE|373|
T Bazil Thredd |QID|389| |N|Warden Thelwater (51.5, 69.4)| |Z|Stormwind City| |O|
T Venture Delivery |QID|41391| |N|Renzik "The Shiv" (78.3, 71.1)| |Z|Stormwind City|
A Turning Off The Tap |QID|41392| |N|Renzik "The Shiv" (78.3, 71.1)| |Z|Stormwind City|

N The Deadmines again |N|What you have handed in leads back to The Deadmines|

F Sentinel Hill |N|Fly to Sentinel Hill in Westfall| |Z|Westfall|
T The Harvest Golem Mystery |QID|40473| |N|Christopher Hewen (52.2, 52.8)| |Z|Westfall|
A The Harvest Golem Mystery |QID|40474| |N|Christopher Hewen (52.2, 52.8)| |Z|Westfall|
T The Defias Brotherhood |QID|132| |N|Gryan Stoutmantle (56.3, 47.5)| |Z|Westfall|
A The Defias Brotherhood |QID|135| |N|Gryan Stoutmantle (56.3, 47.5)| |Z|Westfall|
T The Harvest Golem Mystery |QID|40474| |N|Maltimor Gartside (31.3, 37.6)| |Z|Westfall|
A The Harvest Golem Mystery |QID|40475| |N|Maltimor Gartside (31.3, 37.6)| |Z|Westfall|

R The Deadmines |N|In Moonbrook: through the Defias hideout under the inn, and down the mine (42.5, 72.7)| |Z|Westfall|
C The Harvest Golem Mystery |QID|40475| |N|Recover the Old Engineering Tools, outside too (44.6, 71)| |Z|Westfall|
C Turning Off The Tap |QID|41392| |N|Infiltrate the Deadmines in Westfall and acquire Voss' Sizzling Brew|

N Back outside |N|Out of The Deadmines, in Westfall|
T The Harvest Golem Mystery |QID|40475| |N|Maltimor Gartside (31.3, 37.6)| |Z|Westfall|
A The Harvest Golem Mystery |QID|40476| |N|Maltimor Gartside (31.3, 37.6)| |Z|Westfall|
T The Harvest Golem Mystery |QID|40476| |N|Maltimor Gartside (31.3, 37.6)| |Z|Westfall|
A The Harvest Golem Mystery |QID|40477| |N|Maltimor Gartside (31.3, 37.6)| |Z|Westfall|
C The Harvest Golem Mystery |QID|40477| |N|Gather the Jangolode Mine Shipment, and the Gold Coast Shipment (45.9, 19.4) (29, 48.6)| |Z|Westfall|
T The Harvest Golem Mystery |QID|40477| |N|Maltimor Gartside (31.3, 37.6)| |Z|Westfall|
A The Harvest Golem Mystery |QID|40478| |N|Maltimor Gartside (31.3, 37.6)| |Z|Westfall|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City|
T The Defias Brotherhood |QID|135| |N|Master Mathias Shaw (78.3, 70.7)| |Z|Stormwind City|
A The Defias Brotherhood |QID|141| |N|Master Mathias Shaw (78.3, 70.7)| |Z|Stormwind City|
T Turning Off The Tap |QID|41392| |N|Renzik "The Shiv" (78.3, 71.1)| |Z|Stormwind City|

N The Deadmines again |N|What you have handed in leads back to The Deadmines|

F Sentinel Hill |N|Fly to Sentinel Hill in Westfall| |Z|Westfall|
T The Defias Brotherhood |QID|141| |N|Gryan Stoutmantle (56.3, 47.5)| |Z|Westfall|
A The Defias Brotherhood |QID|142| |N|Gryan Stoutmantle (56.3, 47.5)| |Z|Westfall|
C The Defias Brotherhood |QID|142| |N|Track down the Defias Messenger in Westfall and bring his message to Stoutmantle (45.7, 68)| |Z|Westfall|
T The Defias Brotherhood |QID|142| |N|Gryan Stoutmantle (56.3, 47.5)| |Z|Westfall|
A The Defias Brotherhood |QID|155| |N|The Defias Traitor (55.7, 47.5)| |Z|Westfall|
C The Defias Brotherhood |QID|155| |N|Explore: Escort the Defias Traitor to the secret hideout of the Defias Brotherhood.  Once the Defias Traitor shows you where VanCleef and his men are hiding out, return to Gryan Stoutmantle with the information.| |Z|Westfall|
T The Defias Brotherhood |QID|155| |N|Gryan Stoutmantle (56.3, 47.5)| |Z|Westfall|
A The Defias Brotherhood |QID|166| |N|Gryan Stoutmantle (56.3, 47.5)| |Z|Westfall|
A Red Silk Bandanas |QID|214| |N|Scout Riell (56.7, 47.3)| |Z|Westfall|

R The Deadmines |N|In Moonbrook: through the Defias hideout under the inn, and down the mine (42.5, 72.7)| |Z|Westfall|
C Red Silk Bandanas |QID|214| |N|Scout Riell at the Sentinel Hill Tower wants you to bring her 10 Red Silk Bandanas, outside too (41.9, 77.1)| |Z|Westfall|
K Masterpiece Harvester |N|Pathfinder has no notes on this fight yet.| |BOSS|Masterpiece Harvester|
C The Harvest Golem Mystery |QID|40478| |N|Venture into the Deadmines and slay the Masterpiece Harvester. Once done|
K Edwin VanCleef |N|At half health he calls two Defias Blackguards, and Thrash gives him extra attacks.| |TANK|Pick up the Blackguards when they come.| |HEAL|Thrash makes his damage spiky: keep the tank topped up.| |DPS|Kill the Blackguards, then VanCleef.| |BOSS|Edwin VanCleef|
C The Defias Brotherhood |QID|166| |N|Kill Edwin VanCleef and bring his head to Gryan Stoutmantle|

N Back outside |N|Out of The Deadmines, in Westfall|
T Red Silk Bandanas |QID|214| |N|Scout Riell (56.7, 47.3)| |Z|Westfall|
T The Defias Brotherhood |QID|166| |N|Gryan Stoutmantle (56.3, 47.5)| |Z|Westfall|
T The Harvest Golem Mystery |QID|40478| |N|Maltimor Gartside (31.3, 37.6)| |Z|Westfall|
A The Harvest Golem Mystery |QID|40479| |N|Maltimor Gartside (31.3, 37.6)| |Z|Westfall|
T The Harvest Golem Mystery |QID|40479| |N|Christopher Hewen (52.2, 52.8)| |Z|Westfall|
A The Harvest Golem Mystery |QID|40480| |N|Christopher Hewen (52.2, 52.8)| |Z|Westfall|

F Lakeshire |N|Fly to Lakeshire in Redridge Mountains| |Z|Redridge Mountains|
T The Harvest Golem Mystery |QID|40480| |N|Franklin Hamar (27.2, 45.5)| |Z|Redridge Mountains|

N Done |N|That is every quest for The Deadmines|

]]
end)
