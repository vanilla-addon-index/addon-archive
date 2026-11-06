-- Dungeon guide: Scarlet Monastery, Horde
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Scarlet Monastery (34-45)", nil, "Horde", function()

return [[

N Scarlet Monastery |N|Every quest for Scarlet Monastery: picked up, then the way in, what each asks for inside, and the hand-ins after|

N Given elsewhere |N|Also for Scarlet Monastery, not on this guide's way: Rituals of Power (Mage), from Magus Tirth in Thousand Needles|

R Thunder Bluff |N|Travel to Thunder Bluff| |Z|Thunder Bluff| |R|Orc/Tauren/Troll/Goblin|
A Compendium of the Fallen |QID|1049| |N|Sage Truthseeker (34.4, 46.9)| |Z|Thunder Bluff| |R|Orc/Tauren/Troll/Goblin|

R Undercity |N|Travel to the Undercity| |Z|Undercity|
A Scarlet with Rage |QID|60117| |N|Innkeeper Norman (67.7, 37.9)| |Z|Undercity|
A Reminiscent of Steel |QID|41368| |N|Basil Frye (60.2, 29.1)| |Z|Undercity| |O| |PRE|41397|
A Test of Lore |QID|1160| |N|Parqual Fintallas (57.8, 65.4)| |Z|Undercity| |O| |PRE|1159|
A Hearts of Zeal |QID|1113| |N|Master Apothecary Faranell (48.8, 69.3)| |Z|Undercity| |O| |PRE|1109|
A Into The Scarlet Monastery |QID|1048| |N|Varimathras (56.3, 92.2)| |Z|Undercity|

R Tirisfal Glades |N|Travel to Tirisfal Glades| |Z|Tirisfal Glades|
T Scarlet with Rage |QID|60117| |N|Deathguard Burgess (60.9, 52)| |Z|Tirisfal Glades|
A Paint the Roses Red |QID|60116| |N|Deathguard Burgess (60.9, 52)| |Z|Tirisfal Glades|

R Scarlet Monastery |N|In the north-east of Tirisfal Glades: the Graveyard, Library, Armory and Cathedral all open off the monastery's courtyard (83, 33.6)| |Z|Tirisfal Glades|
C Paint the Roses Red |QID|60116| |N|Eliminate the Scarlet forces outside the Scarlet Monastery, outside too (83.1, 32.8)| |Z|Tirisfal Glades|
C Hearts of Zeal |QID|1113| |N|Master Apothecary Faranell in the Undercity wants 20 Hearts of Zeal, outside too (83.2, 32.8)| |Z|Tirisfal Glades| |O|
C Test of Lore |QID|1160| |N|Find The Beginnings of the Undead Threat| |O|
C Compendium of the Fallen |QID|1049| |N|Retrieve the Compendium of the Fallen from the Monastery in Tirisfal Glades| |R|Orc/Tauren/Troll/Goblin|
K Interrogator Vishas |N|Shadow Word: Pain, and Immolate burns on his blows.| |HEAL|Dispel both (Magic: Priest, Paladin).| |BOSS|Interrogator Vishas|
K Duke Dreadmoore |N|Pathfinder has no notes on this fight yet.| |BOSS|Duke Dreadmoore|
K Ironspine |N|Rare: not always here. Poison Cloud and Curse of Weakness hit everyone near him.| |HEAL|Cure the poison (Poison: Druid, Shaman, Paladin) and remove the curse (Curse: Mage, Druid).| |BOSS|Ironspine| |O|
K Azshir the Sleepless |N|Rare: not always here. Terrify fears, Call of the Grave curses, and Soul Siphon drains a player.| |HEAL|Remove Call of the Grave (Curse: Mage, Druid) and dispel Terrify (Magic: Priest, Paladin).| |DPS|Interrupt Soul Siphon.| |BOSS|Azshir the Sleepless| |O|
K Fallen Champion |N|Rare: not always here. A warrior: Cleave, Rend, and Execute on targets below 20% health.| |TANK|Face him away, and keep your health above 20%.| |BOSS|Fallen Champion| |O|
K Bloodmage Thalnos |N|Fire Nova and Flame Spike hit everyone near him; Flame Shock and Shadow Bolt hit one player.| |HEAL|Dispel Flame Shock (Magic: Priest, Paladin); the melee take fire damage.| |DPS|Interrupt Shadow Bolt and Flame Spike; ranged stand back from Fire Nova.| |BOSS|Bloodmage Thalnos|
K Houndmaster Loksey |N|He fights with his hounds; Bloodlust speeds them up, and Battle Shout raises his attack power.| |TANK|Gather the hounds on you.| |DPS|Kill the hounds; Purge or Dispel Magic his Bloodlust (Shaman, Priest).| |BOSS|Houndmaster Loksey|
K Brother Wystan |N|Pathfinder has no notes on this fight yet.| |BOSS|Brother Wystan|
K Arcanist Doan |N|He silences, polymorphs, and casts Arcane Explosion around him. At half health he shields himself in an Arcane Bubble, then Detonation blasts everyone near him.| |HEAL|Dispel Polymorph and Silence (Magic: Priest, Paladin).| |DPS|When the bubble goes up, run away from him until Detonation has gone off.| |BOSS|Arcanist Doan|
K Armory Quartermaster Daghelm |N|Pathfinder has no notes on this fight yet.| |BOSS|Armory Quartermaster Daghelm|
C Reminiscent of Steel |QID|41368| |N|Slay Armory Quartermaster Daghelm: Journal of Basil Frye| |O|
K Herod |N|Whirlwind hits everyone near him, Cleave hits in front, and he enrages at 30%. When he dies, Scarlet Trainees rush in.| |TANK|Face him away from the group; save a cooldown for 30%.| |HEAL|Whirlwind hits all the melee.| |DPS|Melee step away while he whirlwinds; be ready to deal with the trainees after he dies.| |BOSS|Herod|
K High Inquisitor Fairbanks |N|Fear, Sleep, Curse of Blood, and Dispel Magic on your buffs; at low health he shields and heals himself.| |HEAL|Remove Curse of Blood (Curse: Mage, Druid); dispel Sleep and Fear (Magic: Priest, Paladin).| |DPS|Interrupt his Heal.| |BOSS|High Inquisitor Fairbanks|
K Scarlet Commander Mograine |N|A paladin: Crusader Strike, Hammer of Justice and Retribution Aura. When he dies, High Inquisitor Whitemane comes in.| |HEAL|Dispel Hammer of Justice (Magic: Priest, Paladin) from the tank.| |DPS|Retribution Aura hurts whoever hits him.| |BOSS|Scarlet Commander Mograine|
C Into The Scarlet Monastery |QID|1048| |N|Kill High Inquisitor Whitemane, Scarlet Commander Mograine, Herod, the Scarlet Champion and Houndmaster Loksey|
K High Inquisitor Whitemane |N|At half health she puts everyone to sleep with Deep Sleep and raises Mograine; then they fight together. She heals, shields, and casts Holy Smite.| |TANK|Be ready to pick up Mograine when he rises.| |HEAL|Deep Sleep can't be stopped: heal straight after it.| |DPS|Interrupt her Heal and Holy Smite.| |BOSS|High Inquisitor Whitemane|

N Back outside |N|Out of Scarlet Monastery, in Tirisfal Glades|
T Paint the Roses Red |QID|60116| |N|Deathguard Burgess (60.9, 52)| |Z|Tirisfal Glades|

R Undercity |N|Travel to the Undercity| |Z|Undercity|
T Hearts of Zeal |QID|1113| |N|Master Apothecary Faranell (48.8, 69.3)| |Z|Undercity| |O|
T Test of Lore |QID|1160| |N|Parqual Fintallas (57.8, 65.4)| |Z|Undercity| |O|
A Test of Lore |QID|6628| |N|Parqual Fintallas (57.8, 65.4)| |Z|Undercity| |O| |PRE|1160|
T Test of Lore |QID|6628| |N|Parqual Fintallas (57.8, 65.4)| |Z|Undercity| |O|
T Into The Scarlet Monastery |QID|1048| |N|Varimathras (56.3, 92.2)| |Z|Undercity|
T Reminiscent of Steel |QID|41368| |N|Basil Frye (60.2, 29.1)| |Z|Undercity| |O|

R Thunder Bluff |N|Travel to Thunder Bluff| |Z|Thunder Bluff| |R|Orc/Tauren/Troll/Goblin|
T Compendium of the Fallen |QID|1049| |N|Sage Truthseeker (34.4, 46.9)| |Z|Thunder Bluff| |R|Orc/Tauren/Troll/Goblin|

N Done |N|That is every quest for Scarlet Monastery|

]]
end)
