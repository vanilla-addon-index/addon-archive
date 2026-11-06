-- Dungeon guide: Scarlet Monastery, Alliance
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Scarlet Monastery (34-45)", nil, "Alliance", function()

return [[

N Scarlet Monastery |N|Every quest for Scarlet Monastery: picked up, then the way in, what each asks for inside, and the hand-ins after|

N Given elsewhere |N|Also for Scarlet Monastery, not on this guide's way: The Orb of Kaladus, from Watch Paladin Janathos in Deadwind Pass; Rituals of Power (Mage), from Magus Tirth in Thousand Needles; Scarlet Corruption, from Brother Elias in Gilneas|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City|
A Brother Anton |QID|6141| |N|Brother Crowley (52.6, 43.4)| |Z|Stormwind City|

R Ironforge |N|Travel to Ironforge| |Z|Ironforge|
A Mythology of the Titans |QID|1050| |N|Librarian Mae Paledust (75, 12.5)| |Z|Ironforge|

F Nijel's Point |N|Fly to Nijel's Point in Desolace| |Z|Desolace|
T Brother Anton |QID|6141| |N|Brother Anton (66.5, 7.9)| |Z|Desolace|
A Down the Scarlet Path |QID|261| |N|Brother Anton (66.5, 7.9)| |Z|Desolace|
C Down the Scarlet Path |QID|261| |N|Destroy 30 Undead Ravagers (63.2, 88.8)| |Z|Desolace|
T Down the Scarlet Path |QID|261| |N|Brother Anton (66.5, 7.9)| |Z|Desolace|
A Down the Scarlet Path |QID|1052| |N|Brother Anton (66.5, 7.9)| |Z|Desolace|

F Southshore |N|Fly to Southshore in Hillsbrad Foothills| |Z|Hillsbrad Foothills|
T Down the Scarlet Path |QID|1052| |N|Raleigh the Devout (51.5, 58.4)| |Z|Hillsbrad Foothills|
A In the Name of the Light |QID|1053| |N|Raleigh the Devout (51.5, 58.4)| |Z|Hillsbrad Foothills|

R Scarlet Monastery |N|In the north-east of Tirisfal Glades: the Graveyard, Library, Armory and Cathedral all open off the monastery's courtyard (83, 33.6)| |Z|Tirisfal Glades|
C Mythology of the Titans |QID|1050| |N|Retrieve Mythology of the Titans from the Monastery|
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
K Herod |N|Whirlwind hits everyone near him, Cleave hits in front, and he enrages at 30%. When he dies, Scarlet Trainees rush in.| |TANK|Face him away from the group; save a cooldown for 30%.| |HEAL|Whirlwind hits all the melee.| |DPS|Melee step away while he whirlwinds; be ready to deal with the trainees after he dies.| |BOSS|Herod|
K High Inquisitor Fairbanks |N|Fear, Sleep, Curse of Blood, and Dispel Magic on your buffs; at low health he shields and heals himself.| |HEAL|Remove Curse of Blood (Curse: Mage, Druid); dispel Sleep and Fear (Magic: Priest, Paladin).| |DPS|Interrupt his Heal.| |BOSS|High Inquisitor Fairbanks|
K Scarlet Commander Mograine |N|A paladin: Crusader Strike, Hammer of Justice and Retribution Aura. When he dies, High Inquisitor Whitemane comes in.| |HEAL|Dispel Hammer of Justice (Magic: Priest, Paladin) from the tank.| |DPS|Retribution Aura hurts whoever hits him.| |BOSS|Scarlet Commander Mograine|
C In the Name of the Light |QID|1053| |N|Kill High Inquisitor Whitemane, Scarlet Commander Mograine,  Herod, the Scarlet Champion and Houndmaster Loksey|
K High Inquisitor Whitemane |N|At half health she puts everyone to sleep with Deep Sleep and raises Mograine; then they fight together. She heals, shields, and casts Holy Smite.| |TANK|Be ready to pick up Mograine when he rises.| |HEAL|Deep Sleep can't be stopped: heal straight after it.| |DPS|Interrupt her Heal and Holy Smite.| |BOSS|High Inquisitor Whitemane|

F Southshore |N|Fly to Southshore in Hillsbrad Foothills| |Z|Hillsbrad Foothills|
T In the Name of the Light |QID|1053| |N|Raleigh the Devout (51.5, 58.4)| |Z|Hillsbrad Foothills|

R Ironforge |N|Travel to Ironforge| |Z|Ironforge|
T Mythology of the Titans |QID|1050| |N|Librarian Mae Paledust (75, 12.5)| |Z|Ironforge|

N Done |N|That is every quest for Scarlet Monastery|

]]
end)
