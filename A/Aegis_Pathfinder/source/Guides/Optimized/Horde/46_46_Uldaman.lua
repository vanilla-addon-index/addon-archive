-- Optimized Guide: Uldaman (46-46)
-- The Uldaman run for the Optimized Horde route: the quests from Orgrimmar,
-- the Undercity and the Badlands that end inside, and the Platinum Discs on
-- to Thunder Bluff. Givers, takers and coordinates from pfQuest

AegisPathfinder:RegisterGuide("Optimized/Uldaman (46-46)", "Optimized/Azshara (46-46)", "Horde", function()

return [[

N Uldaman |N|With Uldaman ticked, this is where you run it: quests from Orgrimmar, the Undercity and the Badlands end inside. One full run, in and out, should take you most of the way through level 46| |D|ULDA|
N Not running Uldaman |N|Nothing to do here: continue to Azshara| |D|!ULDA|

F Orgrimmar |QID|2283| |N|Fly from Camp Mojache to Orgrimmar| |D|ULDA| |Z|Orgrimmar|
A Necklace Recovery |QID|2283| |N|Dran Droffers in The Drag (59.5, 36.6)| |D|ULDA| |Z|Orgrimmar|
b Undercity |QID|2342| |N|Take the zeppelin outside Orgrimmar to Tirisfal Glades, and walk into the Undercity| |D|ULDA| |Z|Undercity|
A Reclaimed Treasures |QID|2342| |N|Patrick Garrett (62.3, 48.6)| |D|ULDA| |Z|Undercity|

F Kargath |QID|2202| |N|Fly to Kargath in the Badlands| |D|ULDA| |Z|Badlands|
A Uldaman Reagent Run |QID|2202| |N|Jarkal Mossmeld in Kargath (2.4, 46.1)| |D|ULDA| |Z|Badlands|
R Theldurin the Lost |QID|709| |N|Ride east along the road, then south to Theldurin the Lost's camp (51.4, 76.9)| |D|ULDA| |Z|Badlands|
A Solution to Doom |QID|709| |N|Theldurin the Lost (51.4, 76.9)| |D|ULDA| |Z|Badlands|

R Uldaman |QID|709| |N|Travel north to the dig site at Uldaman's entrance (39.6, 18.5)| |D|ULDA| |Z|Badlands|
C Solution to Doom |QID|709| |N|Loot the Tablet of Ryun'eh from the Ancient Chest in the dig site, outside the instance (39.3, 18.8)| |D|ULDA| |Z|Badlands|

N Uldaman |N|Enter the instance with your group| |D|ULDA|
C Uldaman Reagent Run |QID|2202| |N|Collect 12 Magenta Fungus Caps, outside and inside the instance| |D|ULDA|
C Necklace Recovery |QID|2283| |N|The Shadowforge dwarves in and around Uldaman drop the Shattered Necklace| |D|ULDA|
C Reclaimed Treasures |QID|2342| |N|Loot the Garrett Family Treasure from the family chest in the South Common Hall| |D|ULDA|
A The Platinum Discs |QID|2278| |N|The Discs of Norgannon, in the chamber past Archaedas| |D|ULDA|
C The Platinum Discs |QID|2278| |N|Speak with the Stone Watcher of Norgannon until it has told you everything, then use the Discs again| |D|ULDA|
T The Platinum Discs |QID|2278| |N|The Discs of Norgannon| |D|ULDA|
A The Platinum Discs |QID|2280| |N|The Discs of Norgannon| |D|ULDA|

R Theldurin the Lost |QID|709| |N|Leave Uldaman and ride back south to Theldurin the Lost (51.4, 76.9)| |D|ULDA| |Z|Badlands|
T Solution to Doom |QID|709| |N|Theldurin the Lost (51.4, 76.9)| |D|ULDA| |Z|Badlands|
A To the Undercity for Yagyin's Digest |QID|728| |N|Theldurin the Lost (51.4, 76.9)| |D|ULDA| |Z|Badlands|
R Kargath |QID|2202| |N|Ride back to Kargath (2.4, 46.1)| |D|ULDA| |Z|Badlands|
T Uldaman Reagent Run |QID|2202| |N|Jarkal Mossmeld (2.4, 46.1)| |D|ULDA| |Z|Badlands|

F Undercity |QID|2342| |N|Fly to the Undercity| |D|ULDA| |Z|Undercity|
T Reclaimed Treasures |QID|2342| |N|Patrick Garrett (62.3, 48.6)| |D|ULDA| |Z|Undercity|
T To the Undercity for Yagyin's Digest |QID|728| |N|Keeper Bel'dugur (53.7, 54.5)| |D|ULDA| |Z|Undercity|
b Orgrimmar |QID|2283| |N|Take the zeppelin from Tirisfal Glades back to Orgrimmar| |D|ULDA| |Z|Orgrimmar|
T Necklace Recovery |QID|2283| |N|Dran Droffers in The Drag (59.5, 36.6)| |D|ULDA| |Z|Orgrimmar|

F Thunder Bluff |QID|2280| |N|Fly to Thunder Bluff| |D|ULDA| |Z|Thunder Bluff|
T The Platinum Discs |QID|2280| |N|Sage Truthseeker (34.4, 46.9)| |D|ULDA| |Z|Thunder Bluff|
A The Platinum Discs |QID|2440| |N|Sage Truthseeker (34.4, 46.9)| |D|ULDA| |Z|Thunder Bluff|
T The Platinum Discs |QID|2440| |N|Bena Winterhoof (46.6, 33.2)| |D|ULDA| |Z|Thunder Bluff|
A Portents of Uldum |QID|2965| |N|Sage Truthseeker (34.4, 46.9)| |D|ULDA| |Z|Thunder Bluff|
T Portents of Uldum |QID|2965| |N|Nara Wildmane on the Elder Rise (75.6, 31.6)| |D|ULDA| |Z|Thunder Bluff|
A Seeing What Happens |QID|2966| |N|Nara Wildmane (75.6, 31.6). You take the discs to Uldum in Tanaris later| |D|ULDA| |Z|Thunder Bluff|

N Level 46 |N|Continue to Azshara: fly to Orgrimmar and ride north| |D|ULDA| |LV|46|

]]
end)
