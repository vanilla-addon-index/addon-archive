-- Optimized Guide: Sunken Temple (56-56)
-- The Sunken Temple run the Optimized route's Sunken Temple quests lead up to:
-- Into The Temple of Atal'Hakkar, Into the Depths and Jammal'an the Prophet.
-- Givers, takers and coordinates from pfQuest

AegisPathfinder:RegisterGuide("Optimized/Sunken Temple (56-56)", "Optimized/Silithus (56-57)", "Alliance", function()

return [[

N Sunken Temple |N|With the Sunken Temple ticked, this is where you run it: the quests from Rhapsody Shindigger, Marvon Rivetseeker and the Atal'ai Exile end inside| |D|ST|
N Not running the Sunken Temple |N|Nothing to do here: continue to Silithus| |D|!ST|

R Stormwind City |QID|1475| |N|Take the Deeprun Tram to Stormwind City| |D|ST| |Z|Stormwind City|
A Into The Temple of Atal'Hakkar |QID|1475| |N|Brohann Caskbelly in Dwarven District (64.27, 20.74)| |D|ST| |Z|Stormwind City|
F Nethergarde Keep |QID|1475| |N|Fly to Nethergarde Keep in the Blasted Lands| |D|ST| |Z|Blasted Lands|
R Swamp of Sorrows |QID|1475| |N|Ride north out of the Blasted Lands into the Swamp of Sorrows, then east to the Pool of Tears| |D|ST| |Z|Swamp of Sorrows|
C Into The Temple of Atal'Hakkar |QID|1475| |N|Collect 10 Atal'ai Tablets from the ground: around the temple's ruins in the Pool of Tears (76.7, 51.3) (78.3, 49.5), and inside| |D|ST| |Z|Swamp of Sorrows|

N The Temple of Atal'Hakkar |N|The entrance is at the bottom of the Pool of Tears, by the meeting stone (69.1, 54.7). Enter with your group| |D|ST| |Z|Swamp of Sorrows|
T Into the Depths |QID|3446| |N|Click the Altar of Hakkar, on the temple's lower level| |D|ST|
A Secret of the Circle |QID|3447| |N|The Altar of Hakkar| |D|ST|
T Secret of the Circle |QID|3447| |N|Light the six Atal'ai Statues around the lower level in order -- south, north, south-west, south-east, north-west, north-east -- then click the Idol of Hakkar in the middle| |D|ST|
C Jammal'an the Prophet |QID|1446| |N|Kill the six Atal'ai trolls on the upper level's platforms to open the way, then kill Jammal'an the Prophet for his head| |D|ST|
A The Essence of Eranikus |QID|3373| |N|The Shade of Eranikus dropped his essence: right-click it| |U|10454| |D|ST| |O|
T The Essence of Eranikus |QID|3373| |N|Place it in the Essence Font in his lair| |D|ST| |O|

R Nethergarde Keep |QID|1446| |N|Leave the temple and ride back to Nethergarde Keep (65.5, 24.3)| |D|ST| |Z|Blasted Lands|
F Aerie Peak |QID|1446| |N|Fly to Aerie Peak in The Hinterlands| |D|ST| |Z|The Hinterlands|
R Shadra'Alor |QID|1446| |N|Ride south-east to Shadra'Alor (33.74, 75.16)| |D|ST| |Z|The Hinterlands|
T Jammal'an the Prophet |QID|1446| |N|Atal'ai Exile in Shadra'Alor (33.74, 75.16)| |D|ST| |Z|The Hinterlands|
F Stormwind City |QID|1475| |N|Ride back to Aerie Peak and fly to Stormwind City| |D|ST| |Z|Stormwind City|
T Into The Temple of Atal'Hakkar |QID|1475| |N|Brohann Caskbelly in Dwarven District (64.27, 20.74)| |D|ST| |Z|Stormwind City|

N Level 56 |N|Continue to Silithus, from Stormwind| |LV|56|

]]
end)
