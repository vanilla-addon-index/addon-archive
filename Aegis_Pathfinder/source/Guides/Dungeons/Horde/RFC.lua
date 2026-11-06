-- Dungeon guide: Ragefire Chasm, Horde
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Ragefire Chasm (13-18)", nil, "Horde", function()

return [[

N Ragefire Chasm |N|Every quest for Ragefire Chasm: picked up, then the way in, what each asks for inside, and the hand-ins after|

R Thunder Bluff |N|Travel to Thunder Bluff| |Z|Thunder Bluff|
A Testing an Enemy's Strength |QID|5723| |N|Rahauro (70.1, 29.5)| |Z|Thunder Bluff|
A Searching for the Lost Satchel |QID|5722| |N|Rahauro (70.1, 29.5)| |Z|Thunder Bluff|

R Undercity |N|Travel to the Undercity| |Z|Undercity|
A The Power to Destroy... |QID|5725| |N|Varimathras (56.3, 92.2)| |Z|Undercity|

R Orgrimmar |N|Travel to Orgrimmar| |Z|Orgrimmar|
A Hidden Enemies |QID|5726| |N|Thrall (31.7, 37.8)| |Z|Orgrimmar|
A Slaying the Beast |QID|5761| |N|Neeru Fireblade (49.5, 50.6)| |Z|Orgrimmar|

R Durotar |N|Travel to Durotar| |Z|Durotar|
C Hidden Enemies |QID|5726| |N|Get a Lieutenant's Insignia (53, 9.3)| |Z|Durotar|

R Orgrimmar |N|Travel to Orgrimmar| |Z|Orgrimmar|
T Hidden Enemies |QID|5726| |N|Thrall (31.7, 37.8)| |Z|Orgrimmar|
A Hidden Enemies |QID|5727| |N|Thrall (31.7, 37.8)| |Z|Orgrimmar|
T Hidden Enemies |QID|5727| |N|Thrall (31.7, 37.8)| |Z|Orgrimmar|
A Hidden Enemies |QID|5728| |N|Thrall (31.7, 37.8)| |Z|Orgrimmar|

R Ragefire Chasm |N|The entrance is in the Cleft of Shadow (53, 48.6)| |Z|Orgrimmar|
C Testing an Enemy's Strength |QID|5723| |N|Search Orgrimmar for Ragefire Chasm, then kill 8 Ragefire Troggs and 8 Ragefire Shaman before returning|
C Searching for the Lost Satchel |QID|5722| |N|Search Ragefire Chasm for Maur Grimtotem's corpse and search it for any items of interest|
T Searching for the Lost Satchel |QID|5722| |N|Maur Grimtotem|
A Returning the Lost Satchel |QID|5724| |N|Maur Grimtotem|
C The Power to Destroy... |QID|5725| |N|Get the books Spells of Shadow and Incantations from the Nether|
K Oggleflint |N|Oggleflint cleaves everyone in front of him.| |TANK|Face him away from the group.| |DPS|Stay behind him.| |BOSS|Oggleflint|
K Taragaman the Hungerer |N|Fire Nova burns everyone near him, and Uppercut knocks his target back.| |TANK|Keep your back to a wall so Uppercut doesn't throw you into another pack.| |HEAL|Fire Nova hits everyone in melee: keep the melee topped up.| |DPS|Ranged stand back, out of Fire Nova.| |BOSS|Taragaman the Hungerer|
C Slaying the Beast |QID|5761| |N|Enter Ragefire Chasm and slay Taragaman the Hungerer, then bring his heart back|
K Jergosh the Invoker |N|Jergosh casts Immolate and puts Curse of Weakness on his targets.| |HEAL|Remove Curse of Weakness (Curse: Mage, Druid) and Immolate (Magic: Priest, Paladin).| |DPS|Interrupt Immolate.| |BOSS|Jergosh the Invoker|
C Hidden Enemies |QID|5728| |N|Kill Bazzalan and Jergosh the Invoker before returning|
K Bazzalan |N|A rogue: Sinister Strike, and poison on his blows.| |HEAL|Cure the poison (Poison: Druid, Shaman, Paladin).| |BOSS|Bazzalan|

N Back outside |N|Out of Ragefire Chasm, in Orgrimmar|
T Hidden Enemies |QID|5728| |N|Thrall (31.7, 37.8)| |Z|Orgrimmar|
A Hidden Enemies |QID|5729| |N|Thrall (31.7, 37.8)| |Z|Orgrimmar|
T Slaying the Beast |QID|5761| |N|Neeru Fireblade (49.5, 50.6)| |Z|Orgrimmar|
T Hidden Enemies |QID|5729| |N|Neeru Fireblade (49.5, 50.6)| |Z|Orgrimmar|
A Hidden Enemies |QID|5730| |N|Neeru Fireblade (49.5, 50.6)| |Z|Orgrimmar|
T Hidden Enemies |QID|5730| |N|Thrall (31.7, 37.8)| |Z|Orgrimmar|

R Undercity |N|Travel to the Undercity| |Z|Undercity|
T The Power to Destroy... |QID|5725| |N|Varimathras (56.3, 92.2)| |Z|Undercity|

R Thunder Bluff |N|Travel to Thunder Bluff| |Z|Thunder Bluff|
T Testing an Enemy's Strength |QID|5723| |N|Rahauro (70.1, 29.5)| |Z|Thunder Bluff|
T Returning the Lost Satchel |QID|5724| |N|Rahauro (70.1, 29.5)| |Z|Thunder Bluff|

N Done |N|That is every quest for Ragefire Chasm|

]]
end)
