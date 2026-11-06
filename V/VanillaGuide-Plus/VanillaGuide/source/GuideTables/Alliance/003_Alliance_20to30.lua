--[[--------------------------------------------------
   003_Alliance_20to30.lua
   Authors: mrmr, lanjelin
   Version: 1.04.3
   ------------------------------------------------------
   Description: Guide Serie - 003 From Lvl 20 to Lvl 30
   1.04.1
   -- First Release
   Alliance's Guide
   from level 20 to lever 30
   1.04.2
   -- no changes in here for this revision
   1.04.3
   -- Added color codes
   Fixed various spelling errors
   Adjustment to coordinate visibility
   ------------------------------------------------------
   Connection:
--]]--------------------------------------------------

Table_003_Alliance_20to30 = {
   [2021] = {
      title = "20-21 Darkshore",
      --L- Needs playtest
      items = {
         [1] = { str = "20-21 #ZONEID148#" },
         [2] = { str = "First fly to #ZONEID1657# and get your new Skills." },
         [3] = { str = "Turn in #INID948# at #COORD[43,76]# accept #GETID944#.", x = 43, y = 76, zone = "Darkshore" },
         [4] = { str = "Go to #COORD[39,85]# it should say you found #DOID944# now use the #ITEMID5251#. Click it turn in #INID944# accept #GETID949#", x = 39, y = 85, zone = "Darkshore" },
         [5] = { str = "Click the #OBJECTID12144# at #COORD[38,86]# turn in #INID949# accept #GETID950#.", x = 38, y = 86, zone = "Darkshore" },
         [6] = { str = "Accept #GETID945# (escort) at #COORD[38,87]# and do it.", x = 38, y = 87, zone = "Darkshore" },
         [7] = { str = "Turn in #INID729# pt.1 at #COORD[35,83]# accept #GETID731# pt.2 and do it.", x = 35, y = 83, zone = "Darkshore" },
         [8] = { str = "Go west to #COORD[31,83]# and #COORD[31,85]# and accept #GETID4722# at both.", x = 31, y = 83, zone = "Darkshore" },
         [9] = { str = "Go back to #COORD[43,76]# and turn in #INID950# accept #GETID951#.", x = 43, y = 76, zone = "Darkshore" },
         [10] = { str = "Accept #GETID5321# (escort) the sleeping bear behind Onu. Put his #ITEMID13536# on your hotbar because he falls asleep every minute or so. This quest will bring you into #ZONEID331#. #ITEMID13536# is in the box beside him. Note: since he follows you, with aspect of the cheetah on you can skip mobs by running down the road or taking the offroad." },
      }
   },
   [2122] = {
      title = "21-22 Ashenvale",
      --L- Needs playtest
      items = {
         [1] = { str = "21-22 #ZONEID331#" },
         [2] = { str = "Run to #COORD[26,36]# #ZONEID413# in Ashenvale, and this will complete #DOID5321# Go turn it in straight ahead in the house.", x = 26, y = 36, zone = "Ashenvale" },
         [3] = { str = "Accept #GETID1010#." },
         [4] = { str = "Kill mobs around #COORD[31,31]# in #ZONEID412# for #DOID970# pt.4 I then clear the camp a total of 4 times. If I find it early I still clear it 4 times total. I am then half way to level 22.", x = 31, y = 31, zone = "Ashenvale" },
         [5] = { str = "Grab plant bundles for #DOID1010# at #COORD[31,21]# in #ZONEID411#", x = 31, y = 21, zone = "Ashenvale" },
         [6] = { str = "Go back to #ZONEID413# at #COORD[26,38]# and turn in #INID970# pt.4 Accept #GETID973# pt.5.", x = 26, y = 36, zone = "Ashenvale" },
         [7] = { str = "Turn in #INID1010# accept #GETID1020#." },
         [8] = { str = "Go to #COORD[22,51]# turn in #INID945#.", x = 22, y = 51, zone = "Ashenvale" },
         [9] = { str = "Run into #ZONEID415# at #COORD[33,48]# and get FP", x = 33, y = 48, zone = "Ashenvale" },
         [10] = { str = "Accept #GETID1008# right as you enter town." },
         [11] = { str = "Accept #GETID1070# pt.1 on the house to the right." },
         [12] = { str = "Cross the road near the gazebo accept #GETID1056#" },
         [13] = { str = "In the Inn accept #GETID991# pt.1 and #GETID1054#." },
         [14] = { str = "Make #ZONEID415# your home." },
         [15] = { str = "Turn in #INID1020# at the last house accept #GETID1033#" },
         [16] = { str = "Go to #ZONEID414#. Stop at #COORD[14,31]# accept #GETID1007#", x = 14, y = 31, zone = "Ashenvale" },
         [17] = { str = "do #DOID1008# Naga all around here." },
         [18] = { str = "And #DOID1007# at #COORD[14,20]# it's on the ground. ", x = 14, y = 20, zone = "Ashenvale" },
         [19] = { str = "Turn in #INID1007# at #COORD[14,31]# accept #GETID1009#", x = 14, y = 31, zone = "Ashenvale" },
         [20] = { str = "Do #DOID1009# at 9,15 You don't actually have to kill Ruuzel. Kill Lady Vespia. A 22 weak elite and doesn't have guards like Ruuzel", x = 9, y = 15, zone = "Ashenvale" },
         [21] = { str = "Turn in #INID1009# at #COORD[14,20]#.", x = 14, y = 20, zone = "Ashenvale" },
         [22] = { str = "Turn in #INID991# pt.1 at #COORD[20,42]# accept #GETID1023# pt.2 Kill murlocs for the gem", x = 20, y = 42, zone = "Ashenvale" },
         [23] = { str = "Hearth back to Astranaar" },
         [24] = { str = "Turn in #INID1008# right as you enter town accept #GETID1134#" },
         [25] = { str = "Go to the Inn Turn in #INID1023# pt.2 accept #GETID1024# pt.3 and #GETID1025#" },
         [26] = { str = "Grind to #COORD[46,46]# and do #DOID1033#", x = 46, y = 46, zone = "Ashenvale" },
         [27] = { str = "Go to #COORD[49,56]# then grind north to #COORD[53,46]# turn in #INID1024# pt.3 accept #GETID1026# pt.4.", x = 49, y = 56, zone = "Ashenvale" },
         [28] = { str = "You should already be level 22. Go to #COORD[55,61]# and do #DOID1025#", x = 55, y = 61, zone = "Ashenvale" },
         [29] = { str = "Hearth to Astranaar" },
         [30] = { str = "Turn in #INID1025#" },
         [31] = { str = "Go to the east exit house, turn in #INID1033# accept #GETID1034#" },
         [32] = { str = "Exit Astranaar out the east exit follow the south path till you are at #COORD[33,66]# and grab #ITEMID5494# for #DOID1034#", x = 33, y = 66, zone = "Ashenvale" },
         [33] = { str = "Grind east to Talondeep path at #COORD[42,71]#", x = 42, y = 71, zone = "Ashenvale" },
      }
   },

   -----------22-23 Stonetalon Mountains
   --[203] = {
   [2223] = {
      title = "22-23 Stonetalon Mountains",
      --n = "22-23 Stonetalon Mountains",
      --pID = 202, nID = 204,
      --itemCount = 10,
      items = {
         [1] = { str = "22-23 #ZONEID406#" },
         [2] = { str = "Run down Stonetalon to the hut at #COORD[58,62]# accept #GETID1093#", x = 58, y = 62, zone = "Stonetalon Mountains" },
         [3] = { str = "Then go to #COORD[59,66]# and turn in #INID1070# pt.1# accept #GETID1085# pt.2.", x = 59, y = 66, zone = "Stonetalon Mountains" },
         [4] = { str = "Turn it in right behind you accept #GETID1071#" },
         [5] = { str = "Kill Loggers and Deforesters for #DOID1071# and Operators for #DOID1093# all around Windshear Crag. Operators hang out around buildings only." },
         [6] = { str = "Turn in #INID1093# at the hut #COORD[58,62]# SKIP #SKIPID1094# Unless you want to run to Ratchet.", x = 58, y = 62, zone = "Stonetalon Mountains" },
         [7] = { str = "Then go to #COORD[59,66]# and turn in #INID1071# accept #GETID1072# and #GETID1075# We'll do these later.", x = 59, y = 66, zone = "Stonetalon Mountains" },
         [8] = { str = "Stop at Mirkfallon Lake at #COORD[48,40]# and kill Pridewings for #DOID1134# South and East of it.", x = 48, y = 40, zone = "Stonetalon Mountains" },
         [9] = { str = "Run to 37,8 turn in #INID1056# SKIP #SKIPID1057# for now", x = 37, y = 8, zone = "Stonetalon Mountains" },
         [10] = { str = "Grab FP at 36,7 and Fly to Auberdine.", x = 36, y = 7, zone = "Stonetalon Mountains" },
      }
   },

   -----------23-24 Darkshore
   --[204] = {
   [2324] = {
      title = "23-24 Darkshore",
      --n = "23-24 Darkshore",
      --pID = 203, nID = 205,
      --itemCount = 20,
      items = {
         [1] = { str = "23-24 Darkshore" },
         [2] = { str = "Turn in both #INID4722# on the dock" },
         [3] = { str = "Make Auberdine your home" },
         [4] = { str = "Turn in #INID371# pt.2 just outside the merchant house accept #GETID741# pt.3." },
         [5] = { str = "Go in the last house accept #GETID986#." },
         [6] = { str = "Fly to Darnassus and turn in #INID741# pt.3 outside the Temple of the Moon at #COORD[31,84]# accept #GETID942# pt.4 Get talents if you need them.", x = 31, y = 84, zone = "Darnassus" },
         [7] = { str = "Fly back to Auberdine." },
         [8] = { str = "Go to around #COORD[58,21]# for #DOID951# The relics are all over.", x = 58, y = 21, zone = "Darkshore" },
         [9] = { str = "Stop at #COORD[56,13]# accept #GETID2098# Kill raging reef crawlers around here and Murlocs north near the ship at #COORD[55,12]#", x = 56, y = 13, zone = "Darkshore" },
         [10] = { str = "Run north of Ruins of Mathystra killing sire's and matriach's for #DOID986# Also kill Foreststriders for #DOID2098#" },
         [11] = { str = "Turn in #INID2098# at #COORD[56,13]# accept #GETID2078#.", x = 56, y = 13, zone = "Darkshore" },
         [12] = { str = "Turn the key on The First Mate at #COORD[55,18]# somewhere in the middle he's gonna attack you. You have to kill him. Then turn it in at #COORD[56,13]#", x = 55, y = 18, zone = "Darkshore" },
         [13] = { str = "Run back to Auberdine." },
         [14] = { str = "Turn in #INID986# pt.1 at the first house in town. Accept #GETID993# pt.2" },
         [15] = { str = "Run down to #COORD[43,76]# turn in #INID951#.", x = 43, y = 76, zone = "Darkshore" },
         [16] = { str = "Run down to #COORD[41,81]# and do /wave at Grimclaw He'll point southwest at the cave. Go to it at #COORD[45,85]# and turn in #INID993# pt.2 accept #GETID994# Run him back to Grimclaw at #COORD[41,81]#.", x = 41, y = 81, zone = "Darkshore" },
         [17] = { str = "If you're not level 24 yet or 1750 xp to level 24, grind to 1750 until you level." },
         [18] = { str = "Hearth to Auberdine." },
         [19] = { str = "Turn in #INID994# at the house before exiting town. Accept #GETID990#" },
         [20] = { str = "Fly to Darnassus and get new skills then fly to Astranaar." },
      }
   },

   -----------24-25 Ashenvale
   --[205] = {
   [2425] = {
      title = "24-25 Ashenvale",
      --n = "24-25 Ashenvale",
      --pID = 204, nID = 206,
      --itemCount = 16,
      items = {
         [1] = { str = "24-25 #ZONEID331#" },
         [2] = { str = "Turn in #INID990# right in front of you when you hearth." },
         [3] = { str = "Run to the house on the East side, turn in #INID1034# accept #GETID1035#." },
         [4] = { str = "Run to the West side of town, turn in #INID1134# accept #GETID4581#" },
         [5] = { str = "Grind every mob down into #ZONEID417# and kill #NPCID3664# at #COORD[25,61]# for #DOID973# pt.5 Take him out as fast as you can. He summons 2 voidwalkers if you take too long.", x = 25, y = 61, zone = "Ashenvale" },
         [6] = { str = "Grind a path up to between #COORD[35,33]# and #COORD[36,36]# (he patrols) and kill #NPCID3987# for #DOID1054#.", x = 35, y = 33, zone = "Ashenvale" },
         [7] = { str = "I then grind furbolg's until I'm half way to level 25 " },
         [8] = { str = "Then run to Maestra's Post at #COORD[26,38]# turn in #INID973# pt.5 accept #GETID981# pt.6.", x = 26, y = 38, zone = "Ashenvale" },
         [9] = { str = "Accept #GETID976# (escort) may seem out of the way, you run into a fight of 4, and 2 fights of 3. You only go to the darkshore border and it completes. Easy 2900 xp, not far out of the way. Turn it back in at #COORD[26,38]#.", x = 26, y = 38, zone = "Ashenvale" },
         [10] = { str = "Run to Astranaar" },
         [11] = { str = "Turn in #INID1054# at the inn " },
         [12] = { str = "Run down to Silverwing Refuge at #COORD[49,67]# and accept #GETID1016# do it in the lake here.", x = 49, y = 67, zone = "Ashenvale" },
         [13] = { str = "Once you have all 5 inact bracers, use the scroll on them and then hand it back in at #COORD[49,67]# SKIP #SKIPID1017#. ", x = 49, y = 67, zone = "Ashenvale" },
         [14] = { str = "I'm usually about 1 bar from level 25 so I grind to level 25 on the elementals " },
         [15] = { str = "Go to #COORD[49,56]# then grind north to #COORD[53,46]# turn in #INID1027# pt.3 accept #GETID1028# pt.4.", x = 53, y = 46, zone = "Wetlands" },
         [16] = { str = "Hearth to Auberdine" },
         [17] = { str = "Get on the boat to Menethil Harbor." },
      }
   },

   -----------25-27 Wetlands
   --[206] = {
   [2526] = {
      title = "25-27 Wetlands",
      --n = "25-27 Wetlands",
      --pID = 205, nID = 207,
      --itemCount = 53,
      items = {
         [1] = { str = "25-27 #ZONEID11#" },
         [2] = { str = "Stop at the end of the docks, accept #GETID279#" },
         [3] = { str = "On the west side of town accept #GETID484#" },
         [4] = { str = "Go to the top of the castle, accept #GETID464#" },
         [5] = { str = "On the east side of town accept #GETID470#" },
         [6] = { str = "In front of the Inn accept #GETID288# and #GETID463#" },
         [7] = { str = "-blank-" },
         [8] = { str = "Make Menethil Harbor your home" },
         [9] = { str = "Go upstairs in the inn, turn in #INTID942# pt.4 accept #GETID943# pt.5" },
         [10] = { str = "Buy a #ITEMID2394# from the bartender for #DOID288# and give it to the guy outside the inn. Accept #GETID289#" },
         [11] = { str = "On the bridge accept #GETID305# pt.1" },
         [12] = { str = "Kill Young Crocolisks just east of the bridge around #COORD[14,52]# and north on the land of the lake also along the road to the greenwarden for #DOID484#", x = 14, y = 52, zone = "Wetlands" },
         [13] = { str = "Kill Bluegill Murlocs and Gobbler at #COORD[18,40]# for #DOID279#", x = 18, y = 40, zone = "Wetlands" },
         [14] = { str = "Kill #NPCID1020#s and #NPCID1021# around #COORD[25,46]# for #DOID943# pt.5", x = 25, y = 46, zone = "Wetlands" },
         [15] = { str = "Enter the Excavation Site at #COORD[34,40]#.", x = 34, y = 40, zone = "Wetlands" },
         [16] = { str = "Run up the path on the left and grab the fossil near the 2 npc's at #COORD[38,52]# for #DOID943# pt.5", x = 38, y = 52, zone = "Wetlands" },
         [17] = { str = "Turn in #INID305# pt.1 accept #GETID306# pt.2" },
         [18] = { str = "Accept #GETID299#." },
         [19] = { str = "Outside the cave accept #GETID294# pt.1." },
         [20] = { str = "Go back to where you killed the raptors a few minutes ago at #COORD[25,46]# and do #DOID294# pt.1 by killing #NPCID1020#s and #NPCID1021#.", x = 25, y = 46, zone = "Wetlands" },
         [21] = { str = "Run back up to the cave at #COORD[38,52]# and turn in #INID294# pt.1 accept #GETID295# pt.2", x = 38, y = 52, zone = "Wetlands" },
         [22] = { str = "Now do both #DOID295# pt.2 by killing Scythclaw and Razormaw Raptors below, and #DOID299# relics for this are all around the raptors. There are 4 different ones that randomly spawn but each is in it's own shape which are: (Modr=Thin Red Vase) (Golm=Fat Yellow Vase) (Neru=Dirt Pile) (Ados=Tomb)." },
         [23] = { str = "Go back up to #COORD[38,52]# and turn in #INID295# pt.2 accept #GETID296# pt.3", x = 38, y = 52, zone = "Wetlands" },
         [24] = { str = "Turn in #INID299#" },
         [25] = { str = "Do #DOID296# pt.3 atop the hill at #COORD[32,51]# #NPCID1353# is a 29 But he's as easy as the others. Go turn it back in at #COORD[38,52]#.", x = 32, y = 51, zone = "Wetlands" },
         [26] = { str = "Go in to #ZONEID1036# at #COORD[43,40]# and do #DOID464#", x = 43, y = 40, zone = "Wetlands" },
         [27] = { str = "Stop at #COORD[49,39]# accept #GETID469#.", x = 49, y = 39, zone = "Wetlands" },
         [28] = { str = "Run straight East from here to #COORD[56,40]# and turn in #INID463# accept #GETID276#", x = 56, y = 40, zone = "Wetlands" },
         [29] = { str = "Kill #NPCID1007#, #NPCID1008# around #COORD[56,74]# for #DOID276# at the camp. They're a fast respawn I couldn't kill them fast enough. Turn it in at #COORD[56,40]# and accept #GETID277# You should be level 26 by now, if not you will be soon", x = 56, y = 74, zone = "Wetlands" },
         [30] = { str = "Do #DOID277# by killing any #NPCID1007# but the ones you just killed, The #ITEMID2611# are easily dropped by the ones around #COORD[44,33]# there is a few.", x = 44, y = 33, zone = "Wetlands" },
         [31] = { str = "Turn in #INID277# at #COORD[56,40]# accept #GETID275# Now this is one of those quests you just do as you go. #NPCID1040# are stealthed elementals that lurk in the water. If you see one, kill it.", x = 56, y = 40, zone = "Wetlands" },
         [32] = { str = "Hearth back to Menethil Harbor." },
         [33] = { str = "Turn in #INID943# pt.5 2nd floor of the Inn" },
         [34] = { str = "Go inside the castle upstairs, turn in #INID464# accept #GETID465#" },
         [35] = { str = "On the west side of town turn in #INID469# and #INID484# accept #GETID471#" },
         [36] = { str = "Go on the dock and turn in #INID279# accept #GETID281#" },
         [37] = { str = "On the bridge turn in #INID306# pt.2." },
         [38] = { str = "You should definitely be level 26 by this point and near ½ way to 27. You can either wait till you fly through IF to get talents or do it now." },
         [39] = { str = "Touch the damaged crate at #COORD[13,41]# turn in #INID281# accept #GETID284#.", x = 13, y = 41, zone = "Wetlands" },
         [40] = { str = "Go just north to the next camp touch the sealed barrel at #COORD[13,38]# turn in #INID284# accept #GETID285#.", x = 13, y = 38, zone = "Wetlands" },
         [41] = { str = "Go north again touch the half-burried barrel at #COORD[13,34]# turn in #INID285# accept #GETID286#", x = 13, y = 34, zone = "Wetlands" },
         [42] = { str = "Stop at the sunken ships around #COORD[14,28]# #COORD[14,25]# and kill the undead on either ship for #DOID289# Try to stay on top of the ships. Kill #NPCID1159# in the broken part of the first ship in the rear near the shore for the box.", x = 14, y = 28, zone = "Wetlands" },
         [43] = { str = "From here north you should be able to find Giant crocolisks for #DOID471# as well as the #NPCID1039# (track hidden) in the waters all over this area while you head toward Ironbeard's Tomb at #COORD[44,25]# for #DOID470# Kill oozes for the bag.", x = 44, y = 25, zone = "Wetlands" },
         [44] = { str = "Now once all your #NPCID1040# are dead head back to #NPCID1244# at #COORD[56,40]# and hand it in.", x = 56, y = 40, zone = "Wetlands" },
         [45] = { str = "Hearth Back to Menethil Harbor." },
         [46] = { str = "Just outside turn in #INID289# accept #GETID290#." },
         [47] = { str = "Go north a little bit and turn in #INID470#" },
         [48] = { str = "Go to the west side of town, turn in #INID471#." },
         [49] = { str = "Next down to the docks, turn in #INID286#" },
         [50] = { str = "You should be level 27 now. " },
         [51] = { str = "Fly to IF, get new skills, turn in #INID1072# at #COORD[71,51]# SKIP the next part", x = 71, y = 51, zone = "Wetlands" },
         [52] = { str = "Fly to SW, turn in #INID1071# at #COORD[43,80]# SKIP the next part", x = 43, y = 80, zone = "Wetlands" },
         [53] = { str = "Fly to Lakeshire" },
      }
   },

   -----------27-28 Lakeshire
   --[207] = {
   [2728] = {
      title = "27-28 Lakeshire",
      --n = "27-28 Lakeshire",
      --pID = 206, nID = 208,
      --itemCount = 18,
      items = {
         [1] = { str = "27-28 #ZONEID69#" },
         [2] = { str = "Accept #GETID128# right in front of FP near bridge " },
         [3] = { str = "Accept #GETID20# just over bridge on right." },
         [4] = { str = "Go in the town hall, accept #GETID91#" },
         [5] = { str = "Accept #GETID180# Outside the Inn on the wall" },
         [6] = { str = "Make Lakeshire your home" },
         [7] = { str = "Just west of town at the house past the inn, accept #GETID34# now go do it just west of this house at #COORD[16,49]# (Bellygrub) kill him then hand it back in.", x = 16, y = 49, zone = "Redridge Mountains" },
         [8] = { str = "Go to Render's Camp at #COORD[44,19]# and kill the orcs here for #DOID20# while you head NW to 34,7 for #DOID128#", x = 44, y = 19, zone = "Redridge Mountains" },
         [9] = { str = "Once at the cave kill for the axes and champions Go left when you go in towards the down area with water, there is an escort quest here." },
         [10] = { str = "You should have your axes and champions killed by the time you get to the escort. If not you can kill them on your way out." },
         [11] = { str = "Get the escort quest #GETID219# at #COORD[28,12]# in the cave and escort him out. He's a 25 elite so he won't die easy. Once you're out of the camp he starts running back to Lakeshire, turn the quest in right where you stop as well as #INID20# SKIP #SKIPID19#", x = 28, y = 12, zone = "Redridge Mountains" },
         [12] = { str = "Run over the Bridge near the FP turn in, #INID128#" },
         [13] = { str = "Kill the Gnolls all around #COORD[74,42]# for #DOID91# and Keep an eye out for #DOID180# he is at #COORD[80,40]# Make sure you clear the mobs around him or they come running in", x = 74, y = 42, zone = "Redridge Mountains" },
         [14] = { str = "Once you got those both done, grind on these #NPCID433# until youre about 4k or 2 bars from level 28" },
         [15] = { str = "Hearth to Lakeshire" },
         [16] = { str = "Go in the town hall and turn in both #INID91# and #INID180#" },
         [17] = { str = "You should have hit level 28 after that." },
         [18] = { str = "Run down to the SW corner of Redridge Mountains, and take the path that forks south into #ZONEID10#" },
      }
   },

   -----------28-29 Duskwood
   --[208] = {
   [2829] = {
      title = "28-29 Duskwood",
      --n = "28-29 Duskwood",
      --pID = 207, nID = 209,
      --itemCount = 48,
      items = {
         [1] = { str = "28-29 #ZONEID10#" },
         [2] = { str = "Note on Duskwood, it has a few long, pointless chains that you only do a few parts of, then SKIP the rest" },
         [3] = { str = "Follow the road until you get to Darkshire and get FP at #COORD[72,44]#", x = 72, y = 44, zone = "Duskwood" },
         [4] = { str = "Go to the house just south of FP at #COORD[79,47]# accept #GETID174# pt.1 Buy a #ITEMID4371# from the gnome engineer just south of here at #COORD[78,48]# and hand it back in, accept #GETID175# pt.2", x = 79, y = 47, zone = "Duskwood" },
         [5] = { str = "Go towards town and the first big house on the left outside accept #GETID173# pt.1" },
         [6] = { str = "Go in the house and accept #GETID163# #GETID165# and #GETID164#" },
         [7] = { str = "Exit the house and go straight to the house across the street and accept #GETID66# pt.1 and #GETID101#." },
         [8] = { str = "Run out the door straight across to the Inn and make it your home." },
         [9] = { str = "Exit and go to the right, accept #GETID56# pt.1" },
         [10] = { str = "Turn in #INID66# pt.1 SKIP the rest" },
         [11] = { str = "Start off doing #DOID173# pt.1 to the east of Duskwood around #COORD[64,46]# by killing #NPCID533#", x = 64, y = 46, zone = "Duskwood" },
         [12] = { str = "Turn in #INID173# pt.1 back in the center of town, accept #GETID221# pt.2" },
         [13] = { str = "Go back to around #COORD[64,46]# and kill #NPCID205# now for #DOID221# pt.2 There are a lot in the camps", x = 64, y = 46, zone = "Duskwood" },
         [14] = { str = "Go turn in #INID221# pt.2 in the center of town again and accept #GETID222# pt.3" },
         [15] = { str = "Run to the house at #COORD[81,59]# turn in #INID175# pt.2 accept #GETID177# pt.3", x = 81, y = 59, zone = "Duskwood" },
         [16] = { str = "Do #DOID56# pt.1 and the skeleton finger part of #DOID101# at Tranquil Garden Cemetary around #COORD[79,70]#.", x = 79, y = 70, zone = "Duskwood" },
         [17] = { str = "Ger Mary's Looking Glass for #DOID177# pt.3 inside the chapel here from the #NPCID511#" },
         [18] = { str = "Kill the mobs around #COORD[73,73]# inside and out of the cave for #DOID222# pt.3.", x = 73, y = 73, zone = "Duskwood" },
         [19] = { str = "Hearth back to Darkshire." },
         [20] = { str = "Just outside the Inn, hand in #INID56# pt.1 accept #GETID57# pt.2." },
         [21] = { str = "Go east from here and hand in #INID222# pt.3 accept #GETID223# pt.4 go in the house and turn that in." },
         [22] = { str = "Go just south of the FP to #COORD[79,47]# turn in #INID177# pt.3 accept #GETID181# pt.4", x = 79, y = 47, zone = "Duskwood" },
         [23] = { str = "You should be over half way to level 29, more near ¾ the way" },
         [24] = { str = "Stop at the ogre mound cave at #COORD[33,75]# and kill #NPCID300# for #DOID181# pt.4 Stay left inside the cave", x = 33, y = 75, zone = "Duskwood" },
         [25] = { str = "Stop at the front of Raven Hill at #COORD[18,56]# and turn in #INID163# SKIP the rest since they're grey", x = 18, y = 56, zone = "Duskwood" },
         [26] = { str = "Run north into the cemetery and kill skeletons for #DOID57# pt.2 and spiders in here for #DOID101#." },
         [27] = { str = "Kill ghouls in the northern part of the cemetery at #COORD[22,38]# to get ghoul fangs for #DOID101#", x = 22, y = 38, zone = "Duskwood" },
         [28] = { str = "Kill black widow's east of the graveyard for the last part of #DOID101#" },
         [29] = { str = "Go to the shack NE of Raven Hill at #COORD[28,31]# and turn in #INID165# accept #GETID148#.", x = 28, y = 31, zone = "Duskwood" },
         [30] = { str = "Go to #COORD[17,29]# at the grave and accept #GETID225#", x = 17, y = 29, zone = "Duskwood" },
         [31] = { str = "Run to 7,34 and turn in #INID164# accept #GETID95#", x = 7, y = 34, zone = "Duskwood" },
         [32] = { str = "Hearth to Darkshire" },
         [33] = { str = "Right in front of the inn, turn in #INID57# pt.2 accept #GETID58# pt.3" },
         [34] = { str = "Go in town hall, turn in #INID225# accept #GETID227# Turn it in just out front of the town hall SKIP #SKIPID228#" },
         [35] = { str = "Go in the house east of the Inn, turn in #INID101# and #INID148# accept #GETID149#" },
         [36] = { str = "Go in the last house to the east, turn in #INID181# pt.4." },
         [37] = { str = "Go to Blind Mary in the house at #COORD[81,59]# turn in #INID149# accept #GETID154# Go turn it in at the house east of the Inn, accept #GETID157#", x = 81, y = 59, zone = "Duskwood" },
         [38] = { str = "Go to #COORD[49,77]# (you can sneak around everything to here by going towards STV and then to this location) and turn in #INID95# accept #GETID230#", x = 49, y = 77, zone = "Duskwood" },
         [39] = { str = "Run up to the shack NE of Raven Hill and hand in #INID157# accept #GETID158#" },
         [40] = { str = "Go to the underground at #COORD[23,35]# kill plagued spreaders just around here and down inside for #DOID58# pt.3 you probably won't get them all in 1 pass.", x = 23, y = 35, zone = "Duskwood" },
         [41] = { str = "Grind your way back out then over to Sven at 7,34 hand in #INID95# accept #GETID262#", x = 7, y = 34, zone = "Duskwood" },
         [42] = { str = "Hearth back to Darkshire" },
         [43] = { str = "Turn in #INID158# right in front of you, SKIP the rest" },
         [44] = { str = "Turn in #INID58# pt.3 right outside the Inn" },
         [45] = { str = "Turn in #INID262# at the house east of the Inn accept #GETID265#" },
         [46] = { str = "Turn it in at the town hall, accept #GETID266# SKIP the rest" },
         [47] = { str = "If you happened to find #NPCID2794# (drops off all mobs in Duskwood) start the quest #GETID337# and Fly to SW and turn it in at #COORD[74,7]# and accept #GETID538#", x = 74, y = 7, zone = "Duskwood" },
         [48] = { str = "Fly to Menethil Harbor and get on the boat to Auberdine, Fly to Ashenvale" },
      }
   },

   -----------29-30 Ashenvale
   --[209] = {
   [2930] = {
      title = "29-30 Ashenvale",
      --n = "29-30 Ashenvale",
      --pID = 208, nID = 210,
      --itemCount = 18,
      items = {
         [1] = { str = "29-30 #ZONEID331#" },
         [2] = { str = "Make Astranaar your home." },
         [3] = { str = "Stop at #COORD[66,56]# and touch the crystal for the first part of #DOID981# pt.6.", x = 66, y = 56, zone = "Ashenvale" },
         [4] = { str = "Kill #NPCID3919# for the #ITEMID5475# for #DOID1028# pt.4 around #COORD[55,35]# then use the key on the chest at #COORD[54,35]#", x = 55, y = 35, zone = "Ashenvale" },
         [5] = { str = "Run to #COORD[53,46]# turn in #INID1028# pt.4 accept #GETID1029# pt.5", x = 53, y = 46, zone = "Ashenvale" },
         [6] = { str = "Go to #COORD[85,44]# and turn in #INID4581# accept #GETID1011#", x = 85, y = 44, zone = "Ashenvale" },
         [7] = { str = "Go to #COORD[81,48]# and get the second part of #GETID981# pt.6", x = 81, y = 48, zone = "Ashenvale" },
         [8] = { str = "Go to #COORD[66,81]# and do #DOID1035# the mob is in the center", x = 66, y = 81, zone = "Ashenvale" },
         [9] = { str = "Kill #UNITID3928# until a chest falls east of the road near the lake for #DOID1029# pt.5" },
         [10] = { str = "Go to #COORD[75,71]# and do #DOID1011# the bottle is on the table.", x = 75, y = 71, zone = "Ashenvale" },
         [11] = { str = "Hand in #INID1011# at #COORD[85,44]# SKIP the next part.", x = 85, y = 44, zone = "Ashenvale" },
         [12] = { str = "Hearth back to Astranaar" },
         [13] = { str = "Turn in #INID1035# at the last house on the east side of town" },
         [14] = { str = "Go to #COORD[53,46]# turn in #INID1029# pt.5 accept #GETID1030# pt.6 Go turn it in at the shrine inside the tree at #COORD[56,49]# accept #GETID1045# pt.7 Turn it back in at the moonwell at #COORD[53,46]# accept #GETID1046# pt.8 die so you end up near town", x = 53, y = 46, zone = "Ashenvale" },
         [15] = { str = "Hand in #INID1046# pt.7 at the Inn, SKIP the rest but keep the rod, you can use it forever to transform for fun =P" },
         [16] = { str = "Go to #COORD[26,38]# turn in #INID981# pt.6 SKIP the rest", x = 26, y = 38, zone = "Ashenvale" },
         [17] = { str = "Fly to Darnassus and get your level 30 talents" },
         [18] = { str = "Fly to Auberdine then get on the boat to Menethil Harbor" },
      }
   },

   -----------30-30 Wetlands
   --[210] = {
   [3030] = {
      title = "30-30 Wetlands",
      --n = "30-30 Wetlands",
      --pID = 209, nID = 301,
      --itemCount = 18,
      items = {
         [1] = { str = "30-30 #ZONEID11#" },
         [2] = { str = "Make Menethil Harbor your home." },
         [3] = { str = "Go to #COORD[14,25]# and kill Captain Halyndor for his key on top of the ship, the chest is in the bottom of the ship. Send your pet in to grab all the aggro, then send it out to attack a murloc so it trains them all out. Touch the chest and turn in #INID290# accept #GETID292#", x = 14, y = 25, zone = "Wetlands" },
         [4] = { str = "Touch the catapult at #COORD[47,47]#, hand in #INID465# accept #GETID474#", x = 47, y = 47, zone = "Wetlands" },
         [5] = { str = "Go to #COORD[53,55]# and clear the left side, walk up and around the back, to do #DOID474# clear anything he might aggro, die doing so if you must. He's kinda weak. Pretty easy for a 32 elite.", x = 53, y = 55, zone = "Wetlands" },
         [6] = { str = "Hearth back to Menethil Harbor." },
         [7] = { str = "Turn in #INID292# right in front of you, accept #GETID293#." },
         [8] = { str = "Go up top of the castle, hand in #INID474#." },
         [9] = { str = "Accept #GETID472# just outside the inn " },
         [10] = { str = "Turn in #INID472# at #COORD[49,18]# accept #GETID631# pt.1", x = 49, y = 18, zone = "Wetlands" },
         [11] = { str = "Go half way across the bridge to #COORD[51,8]# and go in the door that leads down, look for the dead dwarf body, hand in #INID631# pt.1 accept #GETID632# pt.2 turn that back in at the camp at #COORD[49,18]# accept #GETID633# pt.3", x = 51, y = 8, zone = "Wetlands" },
         [12] = { str = "Go back over the bridge, just to the right is a tinier bridge. Cross it and destroy the explosives cart for #DOID633# pt.3 at #COORD[48,88]# accept #GETID634#", x = 48, y = 88, zone = "Wetlands" },
         [13] = { str = "Run into Arathi Highlands to Refuge Point at #COORD[45,47]# and hand in #INID634#.", x = 45, y = 47, zone = "Arathi Highlands" },
         [14] = { str = "Grab the FP" },
         [15] = { str = "You should be half way to level 31 or more by now." },
         [16] = { str = "Run towards Hillsbrad Foothills." },
         [17] = { str = "Stop at #COORD[27,49]# and run south into Stormgarde Keep, at the first intersection go right and hug the wall around over the bridge, buy all 3 first aid books at #COORD[26,58]#", x = 27, y = 49, zone = "Arathi Highlands" },
         [18] = { str = "Continue heading to Hillsbrad " },
      }
   },
}
