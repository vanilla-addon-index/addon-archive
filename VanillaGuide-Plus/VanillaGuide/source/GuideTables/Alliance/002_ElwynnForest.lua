--[[--------------------------------------------------
   002_ElwynnForest.lua
   Authors: mrmr, lanjelin
   Version: 1.04.3
   ------------------------------------------------------
   Description: Guide Serie - 001 Elwynn Forest
   1.04.1
   -- First Release
   Human Elwynn Forest's Guide
   from level 1 to lever 12
   1.04.2
   -- no changes in here for this revision
   1.04.3
   -- Added color codes
   Fixed various spelling errors
   Adjustment to coordinate visibility
   Playtested and corrected all steps
   ------------------------------------------------------
   Connection:
--]]--------------------------------------------------
Table_002_ElwynnForest = {
   [0110] = {
      title = "1-10 Elwynn Forest",
      --L- Playtested and corrected
      items = {
         [1] = { str = "1-10 #ZONEID12#" },
         [2] = { str = "Accept #GETID783# then go in the building and turn it in, accept #GETID7#." },
         [3] = { str = "Run back out, and turn in #INID5805# at the wagons at #COORD[47,41]#.", x = 47, y = 41, zone = "Elwynn Forest" },
         [4] = { str = "Go to the nook at the NorthWest corner of the building at #COORD[48,40]# and accept #GETID33#.", x = 48, y = 40, zone = "Elwynn Forest" },
         [5] = { str = "Kill #NPCID69#, #NPCID299# in front of you for #DOID33#, while working your way to the #NPCID6# at #COORD[47,35]# for #DOID7#.", x = 47, y = 35, zone = "Elwynn Forest" },
         [6] = { str = "Go back to #COORD[48,40]# and turn in #INID33#.", x = 48, y = 40, zone = "Elwynn Forest" },
         [7] = { str = "Run into the house at #COORD[48,41]# and turn in #INID7#, accept #GETID3100# and #GETID15#.", x = 48, y = 41, zone = "Elwynn Forest" },
         [8] = { str = "Go to your class trainer and turn in #INID3100# and get new skills.", x = 50, y = 42, zone = "Elwynn Forest" },
         [9] = { str = "Exit the house and accept #GETID18#." },
         [10] = { str = "Go NorthWest toward the cave at #COORD[47,32]#, and kill #NPCID257# on the way for #DOID15#.", x = 47, y = 32, zone = "Elwynn Forest" },
         [11] = { str = "Go West to #COORD[54,40]# and go south killing #NPCID38# for #DOID18#, you should be level 4 by the time you're done, if not grind until you are.", x = 54, y = 40, zone = "Elwynn Forest" },
         [12] = { str = "Run back to the abbey at #COORD[48,42]# and turn in #INID18#, accept #GETID3903# and #GETID6#.", x = 48, y = 42, zone = "Elwynn Forest" },
         [13] = { str = "Go inside the house and turn in #INID15#, accept #GETID21#, then get new skills." },
         [14] = { str = "Go North of the house at #COORD[50,39]# next to the barn, turn in #INID3903#, accept #GETID3904#.", x = 50, y = 39, zone = "Elwynn Forest" },
         [15] = { str = "Go back East and grab the #ITEMID11119# in the garden at #COORD[54,48]# for #DOID3904# then NorthEast to #COORD[57,48]# you'll see a shack with #NPCID103#. Kill him for #DOID6#.", x = 57, y = 48, zone = "Elwynn Forest" },
         [16] = { str = "Go back to #COORD[50,39]# and turn in #INID3904#, accept #GETID3905#.", x = 50, y = 39, zone = "Elwynn Forest" },
         [17] = { str = "Go into the cave at #COORD[47,31]# and kill #NPCID80# for #DOID21#.", x = 47, y = 31, zone = "Elwynn Forest" },
         [18] = { str = "Hearth back to the Abbey." },
         [19] = { str = "Turn in #INID6#." },
         [20] = { str = "Go inside the house, turn in #INID21#, accept #GETID54#." },
         [21] = { str = "Go to the top of the tower through the spiral staircase, turn in #INID3905#." },
         [22] = { str = "Go to #COORD[45,47]# and accept #GETID2158#.", x = 45, y = 47, zone = "Elwynn Forest" },
         [23] = { str = "If you're not level 6 you should be close, just grind on a few mobs while you head towards the house near Goldshire at #COORD[46,62]# and pick up skinning if you want it.", x = 46, y = 42, zone = "Elwynn Forest" },
         [24] = { str = "Enter the Inn at #COORD[42,65]#, accept #GETID60#, turn in #INID2158# and make Goldshire your home.", x = 42, y = 65, zone = "Elwynn Forest" },
         [25] = { str = "Exit the Inn, turn in #INID54#, accept #GETID62#." },
         [26] = { str = "Find your trainer and buy new skills." },
         [27] = { str = "Go near the carts at #COORD[42,67]# and accept #GETID47#", x = 42, y = 67, zone = "Elwynn Forest" },
         [28] = { str = "Go South to the Fargodeep Mine at #COORD[39,82]# and kill the #NPCID40#, #NPCID475# until you complete all 3 quests #DOID62#, #DOID47#, and #DOID60#. Use the lower enterance, as it is easier.", x = 39, y = 82, zone = "Elwynn Forest" },
         [29] = { str = "Once all 3 are done go to the Stonefield Farm just up the hill East at #COORD[34,84]# and accept #GETID85# SKIP #SKIPPrincess Must Die!# if you cannot fight 3 mobs at a time.", x = 34, y = 84, zone = "Elwynn Forest" },
         [30] = { str = "Go east to the Maclure Vinyard at #COORD[43,90]# and accept #GETID106#", x = 43, y = 90, zone = "Elwynn Forest" },
         [31] = { str = "Go to #COORD[43,86]# and turn in #INID85#, accept #GETID86# then kill #NPCID524# until it's finished.", x = 43, y = 86, zone = "Elwynn Forest" },
         [32] = { str = "Go back West to #COORD[34,84]# and turn in #INID86#, and accept #GETID84#.", x = 34, y = 84, zone = "Elwynn Forest" },
         [33] = { str = "Go West to the river at #COORD[30,86]#, and turn in #INID106#, accept #GETID111#.", x = 30, y = 86, zone = "Elwynn Forest" },
         [34] = { str = "Go back to #COORD[34,84]# and turn in #INID111#, accept #GETID107#.", x = 34, y = 84, zone = "Elwynn Forest" },
         [35] = { str = "Run back east to #COORD[43,86]# and turn in #INID84# accept #GETID87#.", x = 43, y = 86, zone = "Elwynn Forest" },
         [36] = { str = "Go in the bottom entrance of the Fargodeep Mine at #COORD[39,82]# and to about #COORD[41,78]#, kill #NPCID327# for #DOID87#. You should ding level 7 during this quest.", x = 41, y = 78, zone = "Elwynn Forest" },
         [37] = { str = "Hearth back to Goldshire." },
         [38] = { str = "In the Inn turn in #INID60#, accept #GETID61# also turn in #INID107#, accept #GETID112#." },
         [39] = { str = "Straight outside the Inn, turn in #INID62# accept #GETID76#." },
         [40] = { str = "South near the fence, turn in #INID47# You should have dinged level 7 now, accept #GETID40#, accept #GETID35# by the blacksmith." },
         [41] = { str = "Kill #NPCID285#, #NPCID735# around the lake at #COORD[51,65]# for #DOID112#.", x = 51, y = 65, zone = "Elwynn Forest" },
         [42] = { str = "Grind up to the Jasperlode Mine at #COORD[61,53]# and run through it about half way to #COORD[60,50]# for #DOID76#.", x = 60, y = 50, zone = "Elwynn Forest" },
         [43] = { str = "Run to the bridge at #COORD[74,72]# and turn in #INID35#, accept #GETID37# and #GETID52#.", x = 74, y = 72, zone = "Elwynn Forest" },
         [44] = { str = "Stop at the house at #COORD[79,69]# and accept #GETID83#.", x = 79, y = 69, zone = "Elwynn Forest" },
         [45] = { str = "At the center of the camp, #COORD[81,66]#, accept #GETID5545#.", x = 81, y = 66, zone = "Elwynn Forest" },
         [46] = { str = "Run just West of the waterfall at #COORD[73,60]# touch the #OBJECTID55#, and turn in #INID37#, accept #GETID45# You should now be level 8, if not grind until you are.", x = 73, y = 60, zone = "Elwynn Forest" },
         [47] = { str = "Go to the Murloc camp at #COORD[80,56]# and loot the #OBJECTID56# there, and turn in #INID45#, accept #GETID71#.", x = 80, y = 56, zone = "Elwynn Forest" },
         [48] = { str = "Go south to #COORD[81,66]# and turn in #INID5545#.", x = 81, y = 66, zone = "Elwynn Forest" },
         [49] = { str = "Cross the road and go south and east and finish killing the #NPCID822# and #NPCID118# for #DOID52#." },
         [50] = { str = "Go back to #COORD[74,72]# near the bridge and turn in #INID52# and #INID71#, accept #GETID39#.", x = 74, y = 72, zone = "Elwynn Forest" },
         [51] = { str = "Go down to the pumpkin patch at #COORD[69,78]# and kill #NPCID116# for #DOID83#.", x = 69, y = 78, zone = "Elwynn Forest" },
         [52] = { str = "You might find #ITEMID1972#, for the quest #DOID184# while you're killing #NPCID116#. Just hold it for now." },
         [53] = { str = "Go to #COORD[79,69]# and turn in #INID83#, it should make you level 9 or bring you really close.", x = 79, y = 69, zone = "Elwynn Forest" },
         [54] = { str = "Stop at the bridge again at #COORD[74,72]# and accept #GETID109#, must be level 9 to accept.", x = 74, y = 72, zone = "Elwynn Forest" },
         [55] = { str = "Hearth to Goldshire" },
         [56] = { str = "Turn in #INID112# accept #GETID114#, #INID76# and #INID39# SKIP #SKIPCloth and Leather Armor# accept #GETID239#. Accept #GETID1097# at the blacksmith." },
         [57] = { str = "Run South to the Maclure Vinyard at #COORD[43,89]# and turn in #INID114#.", x = 43, y = 89, zone = "Elwynn Forest" },
         [58] = { str = "Run West to the Stonefield Farm at #COORD[34,84]# and turn in #INID87#.", x = 34, y = 84, zone = "Elwynn Forest" },
         [59] = { str = "Go NorthWest to #COORD[24,74]# and turn in #INID239#, accept #GETID11# and #GETID176# from the #ITEMWanted! sign#.", x = 24, y = 74, zone = "Elwynn Forest" },
         [60] = { str = "Go just South of the road and start killing #NPCID97#, #NPCID478# for #DOID11# they can also drop a #ITEMID1307# which starts a quest." },
         [61] = { str = "Go back up to #COORD[24,74]# and turn in #INID11#.", x = 24, y = 74, zone = "Elwynn Forest" },
         [62] = { str = "You should be very close to level 10 now, follow the road west into Westfall." },
      }
   },
   [1012] = {
      title = "10-12 Westfall and Loch Modan",
      --L- Playtested and corrected
      items = {
         [1] = { str = "10-12 #ZONEID40# and #ZONEID38#" },
         [2] = { str = "Go to #COORD[60,19]# and turn in #INID184# if you found #ITEMID1972#.", x = 60, y = 19, zone = "Westfall" },
         [3] = { str = "Accept #GETID36# SKIP #SKIPPoor Old Blanchy#." },
         [4] = { str = "Go in the house at #COORD[56,30]# and turn in #INID36#.", x = 56, y = 30, zone = "Westfall" },
         [5] = { str = "Go to #COORD[56,47]# and turn in #INID109#.", x = 56, y = 47, zone = "Westfall" },
         [6] = { str = "Go in the tower and accept #GETID6181#." },
         [7] = { str = "Get the flightpath at #COORD[56,53]# and turn in #INID6181# accept #GETID6281#.", x = 56, y = 53, zone = "Westfall" },
         [8] = { str = "Fly to Stormwin. If you did #NPCID448#, then hearth to Goldshire instead, and turn it in outside the Inn." },
         [9] = { str = "In Stormwind go to #COORD[56,66]# and turn in #INID61#.", x = 56, y = 66, zone = "Stormwind City" },
         [10] = { str = "Train new weapons at #COORD[57,57]#.", x = 57, y = 57, zone = "Stormwind City" },
         [11] = { str = "Go to #COORD[74,48]# and turn in #INID6281# accept #GETID6261#.", x = 74, y = 48, zone = "Stormwind City" },
         [12] = { str = "Go to #COORD[52,12]# and turn in #INID1097# accept #GETID353# this will be done on the way to the Wetlands.", x = 52, y = 12, zone = "Stormwind City" },
         [13] = { str = "Go to #COORD[66,62]# and turn in #INID353# accept #GETID2#Return to Lewis# then fly back to Westfall.", x = 66, y = 62, zone = "Stormwind City" },
         [14] = { str = "Go to the tower at #COORD[56,47]# and turn in #INID6285#.", x = 56, y = 47, zone = "Westfall" },
         [15] = { str = "Fly back to Stormwind.", x = 74, y = 37, zone = "Stormwind City" },
         [16] = { str = "Go into the tram at #COORD[64,08]# and take it to Ironforge.", x = 64, y = 8, zone = "Stormwind City" },
         [17] = { str = "Once it stops accept #GETID6661# just collect 5 rats and turn it in. You could skip this and keep the flute, It can really piss people off if you play it non stop around the IF bank. SKIP #VIDEOMe Brother, Nipsy#." },
         [18] = { str = "Grab the flightpath at #COORD[55,47]#.", x = 55, y = 47, zone = "Ironforge" },
         [19] = { str = "Leave Ironforge and head into Dun Morogh." },
         [20] = { str = "Run east to #COORD[69,56]# and accept #GETID433#.", x = 69, y = 56, zone = "Dun Morogh" },
         [21] = { str = "Go behind him and accept #GETID432#" },
         [22] = { str = "Go in the pit below and kill the #NPCID1115# here and in the cave for both quests, then turn them back in at #COORD[69,56]#.", x = 69, y = 56, zone = "Dun Morogh" },
         [23] = { str = "Go east to #COORD[81,53]# and follow the path into Loch Modan.", x = 81, y = 53, zone = "Dun Morogh" },
         [24] = { str = "Go to #COORD[22,73]# and accept #GETID217#. Go inside the bunker and accept #GETID267#.", x = 22, y = 73, zone = "Loch Modan" },
         [25] = { str = "Go grab the flightpath at #COORD[34,51]#.", x = 34, y = 51, zone = "Loch Modan" },
         [26] = { str = "Kill #NPCID1115# from #COORD[27,53]# and north for #DOID217# and #DOID267#.", x = 27, y = 53, zone = "Loch Modan" },
         [27] = { str = "Go back to #COORD[22,73]# and turn them both in.", x = 22, y = 73, zone = "Loch Modan" },
         [28] = { str = "Go north to the bunker at #COORD[25,18]# and turn in #INID353#.", x = 25, y = 18, zone = "Loch Modan" },
         [29] = { str = "You should be level 12 now or close to it. You can grind if you'd like." },
         [30] = { str = "Head to #COORD[25,11]# and follow the mountainpath to Wetlands.", x = 25, y = 11, zone = "Loch Modan" },
         [31] = { str = "Follow the road to Menethil Harbor at #COORD[11,53]#, get the flighpath, then get on the boat for Darkshore.", x = 25, y = 11, zone = "Wetlands" },
      }
   },
}
