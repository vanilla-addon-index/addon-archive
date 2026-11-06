--[[--------------------------------------------------
   002_DunMorogh.lua
   Authors: mrmr, lanjelin
   Version: 1.04.3
   ------------------------------------------------------
   Description: Guide Serie - 002 DunMorogh
   1.04.1
   -- First Release
   Dwarves&Gnomes DunMorogh's Guide
   from level 1 to lever 12
   1.04.2
   -- no changes in here for this revision
   1.04.3
   -- Added color codes 
   Fixed various spelling errors                        
   Adjustment to coordinate visibility
   ------------------------------------------------------
   Connection:
--]]--------------------------------------------------
Table_002_DunMorogh = {
   [0106] = {
      title = "1-6 Cold Ridge Valley",
      --L- Needs playtest
      items = {
         [1] = { str = "1-6 #ZONEID132#" },
         [2] = { str = "Right in front of where you start accept #GETID179#" },
         [3] = { str = "Go south around #COORD[28,73]# and kill #NPCID705# for the #ITEMID750# then go back to #COORD[29,71]# and turn in #INID179# then accept #GET3109# and #GETID233# ", x = 29, y = 71, zone = "Dun Morogh" },
         [4] = { str = "To your left accept #GETID170# " },
         [5] = { str = "At #COORD[30,74]# kill #NPCID724# and at #COORD[26,72]# there is a camp of #NPCID707#, kill them for #DOID170# ", x = 26, y = 72, zone = "Dun Morogh" },
         [6] = { str = "Go back to #COORD[29,71]# and turn in #INID170# you should be level 3 now " },
         [7] = { str = "Go to Anvilmar at #COORD[28,69]# and turn in your classes skill npc quest which was Encrypted Rune for a rogue", x = 28, y = 69, zone = "Dun Morogh" },
         [8] = { str = "Accept #GETID3361# inside " },
         [9] = { str = "Follow the road south to #COORD[22,71]# and turn in #INID233# pt.1 accept #GETID234# pt.2 and #GETID183#", x = 22, y = 71, zone = "Dun Morogh" },
         [10] = { str = "Just behind him start killing #NPCID708# until you have 12 for #DOID183# then go back to #COORD[22,71]# and turn it in" },
         [11] = { str = "At #COORD[20,76]# clear the front of the tent and grab #ITEMID10438# for #DOID3361#", x = 20, y = 76, zone = "Dun Morogh" },
         [12] = { str = "At #COORD[22,80]# clear in front of the tent and grab #ITEMID16313# for #DOID3361#", x = 22, y = 80, zone = "Dun Morogh" },
         [13] = { str = "Run up to #COORD[25,75]# (it’s the end of the road on the map) and turn in #INID234# pt.2 and accept #GETID182# ", x = 25, y = 75, zone = "Dun Morogh" },
         [14] = { str = "At #COORD[26,79]# clear in front of the cave and grab #ITEMID16314# for #DOID3361# then kill the #NPCID706# in and out of it until you complete #DOID182#", x = 26, y = 79, zone = "Dun Morogh" },
         [15] = { str = "Run back up to #COORD[25,75]# and turn in #INID182# accept #GETID218# you should be level 5 or very close to it now.", x = 25, y = 75, zone = "Dun Morogh" },
         [16] = { str = "Go back in the cave at #COORD[26,79]# and go left at the 3 directions to #COORD[30,80]# and kill #NPCID808# for #DOID218# ", x = 30, y = 80, zone = "Dun Morogh" },
         [17] = { str = "Return back to #COORD[25,75]# and turn in #INID218# accept #GETID282# pt.1", x = 25, y = 75, zone = "Dun Morogh" },
         [18] = { str = "Turn around and accept #GETID3364# and hearth." },
         [19] = { str = "Run up into Anvilmar at #COORD[28,69]# and turn in #INID3361#.", x = 28, y = 69, zone = "Dun Morogh" },
         [20] = { str = "Go further back and turn in #INID3364# accept #GETID3365#." },
         [21] = { str = "Get training before you leave." },
         [22] = { str = "Run right to #COORD[25,75]#, everything is yellow so nothing will attack you, and turn in #INID3365#.", x = 25, y = 75, zone = "Dun Morogh" },
         [23] = { str = "Head toward the tunnel and turn in #INID282# pt.1 at #COORD[33,71]# and accept #GETID283# pt.2.", x = 33, y = 71, zone = "Dun Morogh" },
         [24] = { str = "You should be about 500 xp to 6 now." },
         [25] = { str = "About 10 feet away accept #GETID2160#." },
      }
   },
   [0612] = {
      title = "6-12 Dun Morogh",
      --L- Needs playtest
      items = {
         [1] = { str = "6-12 #ZONEID1#" },
         [2] = { str = "Go through the tunnel and kill all the mobs on the way. Follow the road to #COORD[46,53]# in Kharanos and kill mobs until you’re level 6. Save your #ITEMID2677# and #ITEMID2681#.", x = 46, y = 53, zone = "Dun Morogh" },
         [3] = { str = "Once at #COORD[46,53]# turn in #INID420# pt.2" },
         [4] = { str = "Up ahead on the right, in front of the Inn, accept #GETID384#" },
         [5] = { str = "Go inside the Inn and turn in #INID2160#" },
         [6] = { str = "Go to the Innkeeper, make it your home and purchase a #ITEMID2894# for #DOID384#" },
         [7] = { str = "Get new skills" },
         [8] = { str = "Go across the road from the Inn and accept #GETID400#" },
         [9] = { str = "Go NE to #COORD[49,48]# and accept #GETID317# and #GETID313#", x = 49, y = 48, zone = "Dun Morogh" },
         [10] = { str = "Go to the left house and turn in #INID400#" },
         [11] = { str = "By the tree out front accept #GETID5541#" },
         [12] = { str = "Go to the small camp at #COORD[44,56]# and open the box for #DOID5541#", x = 44, y = 56, zone = "Dun Morogh" },
         [13] = { str = "From around this camp to the SW kill #NPCID1125# and #NPCID1128# until you finish #DOID317# and #DOID384#" },
         [14] = { str = "If you’re having trouble finding #NPCID1125#, just go to around #COORD[40,65]# there are a lot. ", x = 40, y = 65, zone = "Dun Morogh" },
         [15] = { str = "Go into the Grizzled Den at #COORD[42,54]# and kill #NPCID1135# until you get 8 manes for #DOID313#", x = 42, y = 54, zone = "Dun Morogh" },
         [16] = { str = "You also want to head out to #COORD[40,65]# and turn in #INID5541# watch the scene it’s cool, only if you aren’t time running. You should be level 7 or very close now", x = 40, y = 65, zone = "Dun Morogh" },
         [17] = { str = "Hearth back to Kharanos" },
         [18] = { str = "Just outside the Inn, turn in #INID384#" },
         [19] = { str = "Go to the house at #COORD[45,49]#, NE of the Inn, and accept #GETID412#", x = 45, y = 49, zone = "Dun Morogh" },
         [20] = { str = "Run NE to #COORD[49,48]# and turn in #INID317# accept #GETID318#", x = 49, y = 48, zone = "Dun Morogh" },
         [21] = { str = "Turn in #INID313#" },
         [22] = { str = "You should be close to half way through level 7 " },
         [23] = { str = "Run west to #COORD[30,45]# and turn in #INID318# accept #GET319# and #GETID315#. ", x = 30, y = 45, zone = "Dun Morogh" },
         [24] = { str = "Beside him accept #GETID310#" },
         [25] = { str = "To the North/NE from here you’ll find tons of #NPCID1196#, #NPCID1201#, and #NPCID1127# to kill for #DOID319# You should ding level 8 while killing for this. " },
         [26] = { str = "Kill #NPCID1397# and open baskets at #COORD[41,44]# and #COORD[41,35]# for #DOID315#.", x = 41, y = 44, zone = "Dun Morogh" },
         [27] = { str = "Die so you end up in Kharanos" },
         [28] = { str = "Next to the GY accept #GETID287#" },
         [29] = { str = "Go into the Inn and buy a #NPCID2686# off the #NPCID1247# and down in the basement, give the ale to #NPCID1373#. When he leaves touch the barrel to turn in #INID310# accept #GETID311#. " },
         [30] = { str = "Get new skills" },
         [31] = { str = "Go west to Brewnall Village again at #COORD[30,45]# and turn in #INID315# and #INID319# accept #GETID320# and #GETID413#. ", x = 30, y = 45, zone = "Dun Morogh" },
         [32] = { str = "Next to him turn in #INID311# you should be past half way to level 9 now" },
         [33] = { str = "Go west of Brewnall and kill #NPCID1211# until you complete #DOID412# you should hit level 9 getting kills " },
         [34] = { str = "Go to #COORD[24,50]# and enter the cave kill 5 headhunters and explore the cave for #DOID287# To explore it just run in and stay to the right, it will curve left and you can see a raised platform with mobs, get near it to complete exploration ", x = 24, y = 50, zone = "Dun Morogh" },
         [35] = { str = "Die so you end up at Kharanos " },
         [36] = { str = "Either straight down the steps of the Inn, or north of the GY, turn in #INID287# accept #GETID291# " },
         [37] = { str = "Go NW in the house at #COORD[45,49]# and turn in #INID412# ", x = 45, y = 49, zone = "Dun Morogh" },
         [38] = { str = "Go east to #COORD[49,48]# and turn in #INID320# you should be half way to level 10 now " },
         [39] = { str = "Go North to #ZONEID1537# at #COORD[53,35]# ", x = 53, y = 35, zone = "Dun Morogh" },
         [40] = { str = "Make #ZONEID1537# your home at #COORD[21,55]# ", x = 21, y = 55, zone = "Ironforge" },
         [41] = { str = "Go to #COORD[39,56]# in #ZONEID1537#, behind the bank, in the kings room, turn in #INID291#", x = 39, y = 56, zone = "Ironforge" },
         [42] = { str = "Enter the tram at #COORD[76,51]# ", x = 76, y = 51, zone = "Ironforge" },
         [43] = { str = "Take the tram down to SW " },
         --L- Cross check with Elwynd Guide
         [44] = { str = "Go to #COORD[66,62]# and get the FP.", x = 66, y = 62, zone = "Stormwind City" },
         [45] = { str = "Reach goldshire and enter the Inn at #COORD[42,65]# ", x = 42, y = 65, zone = "Elwynn Forest" },
         [46] = { str = "Just to your left accept #GETID60#" },
         [47] = { str = "Exit the Inn and go straight out and accept #GETID62#" },
         [48] = { str = "In the blacksmith house right here accept #GETID1097#" },
         [49] = { str = "Go near the carts at #COORD[42,67]# and accept #GETID47#", x = 42, y = 67, zone = "Elwynn Forest" },
         [50] = { str = "Go south to the Fargodeep Mine at #COORD[39,82]# and kill #NPCID40#, #NPCID475# until you complete all 3 quests #DOID62#, #DOID47#, and #DOID60# Make sure you go in the lower entrance so #DOID62# is easier ", x = 39, y = 82, zone = "Elwynn Forest" },
         [51] = { str = "Once all 3 are done go to the Stonefield Farm just up the hill east at #COORD[34,84]# and accept #GETID85# SKIP #SKIPPrincess Must Die!#", x = 34, y = 84, zone = "Elwynn Forest" },
         [52] = { str = "Go east to the Maclure Vinyard st #COORD[43,85]# and turn in #INID85# accept #GETID86# then turn around and kill #NPCID524# until it’s finished ", x = 43, y = 85, zone = "Elwynn Forest" },
         [53] = { str = "At #COORD[43,80]# and accept #GETID106#", x = 43, y = 80, zone = "Elwynn Forest" },
         [54] = { str = "Go back west to #COORD[34,84]# and turn in #INID86# SKIP #VIDEOBack to Billy#", x = 34, y = 84, zone = "Elwynn Forest" },
         [55] = { str = "Go west to the river at #COORD[29,85]# and turn in #INID106# accept #GETID111#", x = 29, y = 85, zone = "Elwynn Forest" },
         [56] = { str = "Go back to #COORD[34,84]# and turn in #INID111# in the house, accept #GETID107# You should be level 10 now ", x = 34, y = 84, zone = "Elwynn Forest" },
         [57] = { str = "Go back to Goldshire, either die or run " },
         --L- Cross check with Elwynd Guide
         [58] = { str = "Go into the tram again at #COORD[63,10]# accept #GETID6661# just collect 5 rats and turn it in. You could skip this and keep the flute, It can really piss people off if you play it non stop around the #ZONEID1537# bank. SKIP #VIDEOMe Brother, Nipsy# unless you go back to SW on the tram because you get crap xp", x = 63, y = 10, zone = "Stormwind City" },
         [59] = { str = "After this you should be a bit over half way to level 11 " },
         [60] = { str = "Run east to #COORD[68,55]# and accept #GETID433#", x = 68, y = 55, zone = "Dun Morogh" },
         [61] = { str = "Go behind him and accept #GETID432#" },
         [62] = { str = "Go in the pit below and kill #NPCID1115# here and in the cave for both quests then turn them back in at #COORD[68,55]# " },
         [63] = { str = "Go east to #COORD[80,51]# and follow the path into Loch Modan ", x = 80, y = 51, zone = "Dun Morogh" },
         [64] = { str = "Go to #COORD[22,73]# and accept #GETID217#", x = 22, y = 73, zone = "Loch Modan" },
         [65] = { str = "Go up in the bunker and accept #GETID267#" },
         [66] = { str = "At #COORD[33,50]# grab the FP ", x = 33, y = 50, zone = "Loch Modan" },
         [67] = { str = "Look for #NPCID1340# and accept #GETID416#" },
         [68] = { str = "Kill #NPCID1205#, #NPCID1206#, #NPCID1207# from #COORD[27,53]# and north for #DOID217# and #DOID267#", x = 27, y = 53, zone = "Loch Modan" },
         [69] = { str = "Go back to #COORD[22,73]# and turn them both in ", x = 22, y = 73, zone = "Loch Modan" },
         [70] = { str = "Go north to the bunker at #COORD[24,18]# and turn in #INID353#", x = 24, y = 18, zone = "Loch Modan" },
         [71] = { str = "You should be level 12 now or close to it. You can grind if you’d like. Follow the Night Elf to #ZONEID1537# guide but just go backwards. You’re going to go north through the #ZONEID11# to #ZONEID150#, then take the boat to #ZONEID442# from here." },
         --L- Someone has been way too lazy
      }
   },
}
