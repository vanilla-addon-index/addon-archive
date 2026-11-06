-- Dungeon guide: Razorfen Downs, Alliance
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Razorfen Downs (37-46)", nil, "Alliance", function()

return [[

N Razorfen Downs |N|Every quest for Razorfen Downs: picked up, then the way in, what each asks for inside, and the hand-ins after|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City|
A Bring the Light |QID|3636| |N|Archbishop Benedictus (50.3, 45.5)| |Z|Stormwind City|

R The Barrens |N|Travel to The Barrens| |Z|The Barrens|
A A Host of Evil |QID|6626| |N|Myriam Moonsinger (49, 94.9)| |Z|The Barrens|
C A Host of Evil |QID|6626| |N|Kill 8 Razorfen Battleguard, 8 Razorfen Thornweavers, and 8 Death's Head Cultists (47.6, 91.2)| |Z|The Barrens|
T A Host of Evil |QID|6626| |N|Myriam Moonsinger (49, 94.9)| |Z|The Barrens|

R Razorfen Downs |N|In the south-east of the Barrens, at the top of the thorny ramp by the Great Lift (49.6, 94.5)| |Z|The Barrens|
A Scourge of the Downs |QID|3523| |N|Belnistrasz|
T Scourge of the Downs |QID|3523| |N|Belnistrasz|
A Extinguishing the Idol |QID|3525| |N|Belnistrasz|
C Extinguishing the Idol |QID|3525| |N|Protect Belnistrasz while he extinguishes the idol: speak with him when your group is ready|
T Extinguishing the Idol |QID|3525| |N|Belnistrasz|
K Plaguemaw the Rotting |N|Putrid Stench, a disease, silences everyone near him, and Withered Touch drains mana.| |HEAL|Cure the diseases (Disease: Priest, Shaman, Paladin); stay out of the stench so you can cast.| |DPS|Casters stand back.| |BOSS|Plaguemaw the Rotting|
K Tuten'kash |N|He comes after you ring the gong. Web Spray roots everyone in front of him, his bites poison, and Curse of Tuten'kash slows casting.| |TANK|Face him away from the group.| |HEAL|Remove the curse (Curse: Mage, Druid) and cure the poison (Poison: Druid, Shaman, Paladin).| |BOSS|Tuten'kash|
K Mordresh Fire Eye |N|Fireball and Fire Nova.| |DPS|Interrupt Fireball; ranged stand back from Fire Nova.| |BOSS|Mordresh Fire Eye|
K Glutton |N|A Disease Cloud hurts everyone near him, Thrash gives him extra attacks, and he frenzies at 15%.| |HEAL|The cloud hurts the melee all fight.| |DPS|Burn the last 15% fast.| |BOSS|Glutton|
K Death Prophet Rakameg |N|Pathfinder has no notes on this fight yet.| |BOSS|Death Prophet Rakameg|
K Ragglesnout |N|Rare: not always here. Dominate Mind, Shadow Bolt, Shadow Word: Pain, and he heals.| |HEAL|Dispel Dominate Mind (Magic: Priest, Paladin).| |DPS|Interrupt Dominate Mind and Heal.| |BOSS|Ragglesnout| |O|
K Amnennar the Coldbringer |N|Frostbolt, Frost Nova and Amnennar's Wrath; at 66% and at 33% he calls Frost Spectres.| |TANK|Pick up the Frost Spectres.| |HEAL|Dispel Frost Nova and Frostbolt's slow (Magic: Priest, Paladin).| |DPS|Kill the spectres; interrupt Frostbolt.| |BOSS|Amnennar the Coldbringer|
C Bring the Light |QID|3636| |N|Archbishop Bendictus wants you to slay Amnennar the Coldbringer in Razorfen Downs|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City|
T Bring the Light |QID|3636| |N|Archbishop Benedictus (50.3, 45.5)| |Z|Stormwind City|

N Done |N|That is every quest for Razorfen Downs|

]]
end)
