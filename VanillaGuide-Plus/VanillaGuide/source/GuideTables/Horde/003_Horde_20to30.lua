--[[--------------------------------------------------
   003_Horde_20to30.lua
   Authors: mrmr, lanjelin
   Version: 1.04.3
   ------------------------------------------------------
   Description: Guide Serie - 003 From Lvl 20 to Lvl 30
   1.04.1
   -- First Release
   Horde's Guide
   from level 20 to lever 30
   1.04.2
   -- no changes in here for this revision
   1.04.3
   -- Cleanup in text, changed formatting of coords
   ------------------------------------------------------
   Connection:
--]]--------------------------------------------------

Table_003_Horde_20to30 = {
   -----------20-21 Stonetalon Mountains
   --[201] = {
   [2021] = {
      title = "20-21 Stonetalon Mountains",
      --n = "20-21 Stonetalon Mountains",
      --pID = 104, nID = 202, 
      --itemCount = 20,
      items = {
         [1] = { str = "20-21 #ZONEID406#" },
         [2] = { str = "Run to Malaka'Jin at #COORD[71,94]#", x = 71, y = 94, zone = "Stonetalon Mountains" },
         [3] = { str = "Accept #GETID6461# " },
         [4] = { str = "Turn in #INID1060# at #COORD[74,97]# in the cave ... accept #GETID1058# ", x = 74, y = 97, zone = "Stonetalon Mountains" },
         [5] = { str = "Then go accept #GETID6284# from the Wanted poster at #COORD[59,75]#", x = 59, y = 75, zone = "Stonetalon Mountains" },
         [6] = { str = "Go do #DOID6461# along with #DOID1069# and #DOID6284# around #COORD[54,76]# NOTE: you can skip Arachnophobia for now, you'll return here later...", x = 54, y = 76, zone = "Stonetalon Mountains" },
         [7] = { str = "Then turn in #INID1483# at the goblin in the hut at Windshear Crag, #COORD[58,62]# ... accept #GETID1093# ", x = 58, y = 62, zone = "Stonetalon Mountains" },
         [8] = { str = "Then do: #DOID1062# and #DOID1093# (the mobs are just north in Windshear Crag)" },
         [9] = { str = "Then turn in #INID1093# #COORD[58,62]# ... accept #GETID1094# ", x = 58, y = 62, zone = "Stonetalon Mountains" },
         [10] = { str = "Run to #ZONEID460# at #COORD[46,59]#.", x = 46, y = 59, zone = "Stonetalon Mountains" },
         [11] = { str = "Turn in #INID6284# and #INID6401# if you did the escort quest" },
         [12] = { str = "Get FP there." },
         [13] = { str = "Run up the little #VIDEOpathway# and accept #GETID6421# and #GETID6562# at #COORD[47,64]#", x = 47, y = 64, zone = "Stonetalon Mountains" },
         [14] = { str = "Then go do #DOID6421# at #COORD[61,92]#", x = 61, y = 92, zone = "Stonetalon Mountains" },
         [15] = { str = "Then turn in #INID6461# #COORD[71,95]#", x = 71, y = 95, zone = "Stonetalon Mountains" },
         [16] = { str = "Turn in #INID1062# at #COORD[35,27]# in the Barrens ... accept #GETID1068#   (I SKIP #SKIPID1063# )", x = 35, y = 27, zone = "The Barrens" },
         [17] = { str = "Hearth to XRs." },
         [18] = { str = "Run north to Ashenvale (stopping along the way to turn in #INID6541# (at 48.5) but SKIP #SKIPID6543# ", x = 48, y = 5, zone = "The Barrens" },
         --[19] = { str = "." },
         --[20] = { str = "." },
      }
   },

   -----------21-21 Ashenvale
   --[202] = {
   [2121] = {
      title = "21-21 Ashenvale",
      --n = "21-21 Ashenvale",
      --pID = 201, nID = 203,
      --itemCount = 11,
      items = {
         [1] = { str = "21-21 #ZONEID331#" },
         [2] = { str = "Run to #ZONEID431# at #COORD[73,65]#", x = 73, y = 65, zone = "Ashenvale" },
         [3] = { str = "Turn in #INID235# .  Then accept and turn in #INID235# again." },
         [4] = { str = "Get FP in #ZONEID431#." },
         [5] = { str = "Run all the way to Zoram Strand at #COORD[13,31]#, grind mobs along the way.", x = 13, y = 31, zone = "Ashenvale" },
         [6] = { str = "Get FP there. #COORD[12,33]#.  Turn in #INID6562# .. i SKIP #SKIPID6563# ", x = 12, y = 33, zone = "Ashenvale" },
         [7] = { str = "Do the following quests:" },
         [8] = { str = "Accept and do #DOID6442# then turn it in." },
         [9] = { str = "Hearth back to XRs, if hearth stone is still on a cooldown, fly there." },
         --[10] = { str = "." },
         --[11] = { str = "." },
      }
   },

   -----------22-23 Southern Barrens
   --[203] = {
   [2223] = {
      title = "22-23 Southern Barrens",
      --n = "22-23 Southern Barrens",
      --pID = 202, nID = 204,
      --itemCount = 19,
      items = {
         [1] = { str = "22-23 #ZONEID1156#" },
         [2] = { str = "Fly to CT." },
         [3] = { str = "Turn in #INID3261# ... accept #GETID882# and #GETID1130# " },
         [4] = { str = "Make CT your home." },
         [5] = { str = "I give bloodshards to the gnoll in the cage to get increased agility/spirit." },
         [6] = { str = "Run south and keep an eye out for the mob named #NPCID3472# around #COORD[45,62]#, he drops 'Owatanka's Tailspike' which starts #GETID884# ", x = 45, y = 62, zone = "The Barrens" },
         [7] = { str = "#DOID868# #COORD[44,71]#", x = 44, y = 71, zone = "The Barrens" },
         [8] = { str = "#DOID819# (if you have it)" },
         [9] = { str = "#DOID879# and #DOID893# #COORD[43,79]#", x = 43, y = 79, zone = "The Barrens" },
         [10] = { str = "Accept #GETID843# from #NPCID3339#.  Then go do it at #COORD[46,86]#. Then turn it in, accept #GETID846# ", x = 46, y = 86, zone = "The Barrens" },
         [11] = { str = "Hearth back to Camp Taurajo, turn in #INID893# and #INID879# ... accept #GETID879# part2" },
         [12] = { str = "Fly to XR." },
         [13] = { str = "Turn in #INID879# part2 and #INID868# " },
         [14] = { str = "Do #DOID882# at #COORD[60,32]#", x = 60, y = 32, zone = "The Barrens" },
         [15] = { str = "Turn in #INID1094# at Ratchet #COORD[63,37]# ... accept #GETID1094# part2", x = 63, y = 37, zone = "The Barrens" },
         [16] = { str = "Turn in #INID1069# and #INID819# " },
         [17] = { str = "Fly to Stonetalon Mountains..." },
         --[18] = { str = "." },
         --[19] = { str = "." },
      }
   },

   -----------23-25 Stonetalon Mountains
   --[204] = {
   [2325] = {
      title = "23-25 Stonetalon Mountains",
      --n = "23-25 Stonetalon Mountains",
      --pID = 203, nID = 205,
      --itemCount = 24,
      items = {
         [1] = { str = "23-25 #ZONEID406#" },
         [2] = { str = "Accept all quests at #ZONEID460# (which include: #GETID1087# #GETID6301# and #GETID6282# )..." },
         [3] = { str = "Make #ZONEID460# your home." },
         [4] = { str = "Turn in #INID6421# .. I SKIP #SKIPID6481# (accept #GETID6393# there though)" },
         [5] = { str = "Do:" },
         [6] = { str = "#DOID6301#, pick up the seeds around #COORD[48,41]#", x = 48, y = 41, zone = "Stonetalon Mountains" },
         [7] = { str = "#DOID1087#, done at around #COORD[35,14]#", x = 35, y = 14, zone = "Stonetalon Mountains" },
         [8] = { str = "#DOID1058#, the mobs are around the path at #COORD[45,27]#, and the area at #COORD[34,14]#", x = 45, y = 27, zone = "Stonetalon Mountains" },
         [9] = { str = "Go back to #ZONEID460# and turn in #INID6301# ... accept #GETID6381# " },
         [10] = { str = "Turn in #INID1087# ... accept  #GETID1088# " },
         [11] = { str = "Go turn in #INID1094# part2 #COORD[58,62]#... accept #GETID1096# ", x = 58, y = 62, zone = "Stonetalon Mountains" },
         [12] = { str = "Go do #DOID1096# at #COORD[64,41]#  and #DOID1068#   (kill #NPCXT:4# and #NPCXT:9#)", x = 64, y = 41, zone = "Stonetalon Mountains" },
         [13] = { str = "Then turn in #INID1096# . #COORD[58,62]#. If you couldn't do Arachnophobia, do it now!", x = 58, y = 62, zone = "Stonetalon Mountains" },
         [14] = { str = "Run down south and turn in #INID1058# #COORD[74,97]#", x = 74, y = 97, zone = "Stonetalon Mountains" },
         [15] = { str = "Turn in #INID1068# in the Barrens at #COORD[35,27]#", x = 35, y = 27, zone = "The Barrens" },
         [16] = { str = "Hearth back to #ZONEID460# and turn in #INID6284# if you just did it." },
         [17] = { str = "Stock back up on food/water." },
         [18] = { str = "Go do #DOID6282# along with #DOID6393# and #DOID6381# at the Charred Vale, #COORD[32,67]#", x = 32, y = 67, zone = "Stonetalon Mountains" },
         [19] = { str = "Once they are all done, make sure you are at least 5 bars away from level 25, so you may have to grind a little.  " },
         [20] = { str = "Then go turn them all in, and accept #GETID5881# " },
         [21] = { str = "Then fly to CT..." },
         --[23] = { str = "." },
         --[24] = { str = "." },
      }
   },

   -----------25-25 Southern Barrens2
   --[205] = {
   [2525] = {
      title = "25-25 Southern Barrens",
      --n = "25-25 Southern Barrens",
      --pID = 204, nID = 206,
      --itemCount = 14,
      items = {
         [1] = { str = "25-25 #ZONEID1156#" },
         [2] = { str = "Turn in #INID882# ... accept #GETID907# " },
         [3] = { str = "Make CT your home." },
         [4] = { str = "Accept #GETID1153# (need to be lvl 25 to get this)" },
         [5] = { str = "Go down and do:" },
         [6] = { str = "#DOID907# " },
         [7] = { str = "You should find the mob #NPCID3471#, he drops 'Washte Pawne Feather' which starts #GETID885# " },
         [8] = { str = "#DOID846# at #COORD[47,85]# Once done, Turn it in, accept the next part...", x = 47, y = 85, zone = "The Barrens" },
         [9] = { str = "Do #DOID846# Part 3 at #COORD[46,85]#, then turn it in.", x = 46, y = 85, zone = "The Barrens" },
         [10] = { str = "Head south down the path to the Great Lift #COORD[44,91]#,and turn in #INID5881# ", x = 44, y = 91, zone = "The Barrens" },
         [11] = { str = "Accept #GETID4542# " },
         [12] = { str = "Run to Freewind Post... #COORD[45,50]# in Thousand Needles", x = 45, y = 50, zone = "Thousand Needles" },
         --[13] = { str = "." },
         --[14] = { str = "." },
      }
   },

   -----------25-26 Thousand Needles
   --[206] = {
   [2526] = {
      title = "25-26 Thousand Needles",
      --n = "25-26 Thousand Needles",
      --pID = 205, nID = 207,
      --itemCount = 23,
      items = {
         [1] = { str = "25-26 #ZONEID400#" },
         [2] = { str = "Turn in #INID4542# accept #GETID4841# " },
         [3] = { str = "Accept #GETID5147# #GETID4821# and #GETID4767# " },
         [4] = { str = "Get FP there." },
         [5] = { str = "Go do (in the following order):" },
         [6] = { str = "#DOID4841# (mobs are just north)" },
         [7] = { str = "#DOID1149#, the cave at #COORD[52,43]#", x = 52, y = 43, zone = "Thousand Needles" },
         [8] = { str = "#DOID1153#   (if you can't find the drop, just skip it for now)" },
         [9] = { str = "#DOID4821#, it has 4 possible spawn points, around: #COORD[52,56]# / #COORD[45,63]# / #COORD[41,60]# / #COORD[50,56]#, and there might be more, just check around those areas.)", x = 52, y = 56, zone = "Thousand Needles" },
         [10] = { str = "If you're not level 26 (or two bars away from it), grind till you are." },
         [11] = { str = "Go up to Freewind Post #COORD[45,50]#..", x = 45, y = 50, zone = "Thousand Needles" },
         [12] = { str = "Turn in #INID4841# ... accept #GETID5064# " },
         [13] = { str = "Turn in #INID4821# ... accept #GETID4865# " },
         [14] = { str = "Hearth to Camp Taurajo." },
         [15] = { str = "Turn in #INID907# and #INID885# ... accept #GETID913# " },
         [16] = { str = "Turn in #INID1153# " },
         [17] = { str = "Go do #DOID913# then turn it in ... I SKIP #NPCID3387# " },
         [18] = { str = "Fly to Thunder Bluff to get new spells/abilities." },
         [19] = { str = "Turn in #INID1130#, #COORD[61,80]# on the Hunter Rise... accept #GETID1131# ", x = 61, y = 80, zone = "Thunder Bluff" },
         [20] = { str = "Accept #GETID1195# #COORD[55,51]#", x = 55, y = 51, zone = "Thunder Bluff" },
         [21] = { str = "Fly to Splintertree Post, Ashenvale..." },
         --[22] = { str = "." },
         --[23] = { str = "." },
      }
   },

   -----------26-27 Ashenvale
   --[207] = {
   [2627] = {
      title = "26-27 Ashenvale",
      --n = "26-27 Ashenvale",
      --pID = 206, nID = 208,
      --itemCount = 26,
      items = {
         [1] = { str = "26-27 #ZONEID331#" },
         [2] = { str = "Make it your home." },
         [3] = { str = "Do the following order:" },
         [4] = { str = "Accept all the quests, which include: #GETID25# #GETID6441# #GETID6503# (accept this at #COORD[71,68]#).  Make sure #GETID235# is turned in at #NPCID12678# (you can accept this quest right at the NPC itself). Note: I SKIP #SKIPID6571# and #SKIPID6504# ", x = 71, y = 68, zone = "Ashenvale" },
         [5] = { str = "Kill the first of the three mobs related to the Ashenvale hunt:" },
         [6] = { str = "#DOID2#, Kill #NPCID12676# who patrols around #COORD[74,70]#, he drops the item that starts this quest. Hint: easy way to kill it (he's lvl 31 mob), is to kite him into the guards at #ZONEID431#. ", x = 74, y = 70, zone = "Ashenvale" },
         [7] = { str = "Do: #DOID6503#, around #COORD[71,72]#. Once the quest is completed, turn it in when you get the chance.", x = 71, y = 72, zone = "Ashenvale" },
         [8] = { str = "Then go slightly west and do #DOID6544# at #COORD[68,75]#", x = 68, y = 75, zone = "Ashenvale" },
         [9] = { str = "Then go do #DOID25# at the lake at #COORD[53,70]#. Find and kill #NPCID12759# he drops an item which starts: #GETID1918# ", x = 53, y = 70, zone = "Ashenvale" },
         [10] = { str = "Kill #NPCID12678#, around #COORD[42,67]# for #DOID23# (Ashenvale hunt)", x = 42, y = 67, zone = "Ashenvale" },
         [11] = { str = "Kill #NPCID12677#, around #COORD[56,54]# for #DOID24# (Ashenvale hunt)", x = 56, y = 54, zone = "Ashenvale" },
         [12] = { str = "#DOID1195#: First find a phial killing the dryads at #COORD[61,52]#, then fill it at the moonwell at #COORD[60,72]#", x = 60, y = 72, zone = "Ashenvale" },
         [13] = { str = "Hearth to #ZONEID431# to turn in #INID25# #INID1918# (accept #GETID824# ) #INID6544# and all three of the 'Ashenvale Hunt' quests, then accept and complete #INID247# " },
         [14] = { str = "Fly to Zoram Strand, and turn in #INID824# " },
         [15] = { str = "Accept and do #DOID6641# .  Once done go back and turn it in." },
         [16] = { str = "Accept and do: #DOID216# #COORD[34,37]# and #DOID6462# at the cave at #COORD[38,30]#.  #VIDEONOTE:#  While you are in the cave, there is an escort quest (a white bear-formed druid in a cage) called #DOID6482# , try to do this quest, you may have to fight 3-5 mobs at once several times, if you fail then it can be skipped.", x = 34, y = 37, zone = "Ashenvale" },
         [17] = { str = "Once they are both completed, go turn in #INID216# and #INID6462# (back at the Zoram Strand), then hearth back to #ZONEID431#.  Turn in #INID6482# (if you did it)" },
         [18] = { str = "If im not level 27 i'll grind till I am." },
         [19] = { str = "Go do #DOID1088# #COORD[61,52]# (#VIDEOfight your way to him, just kill the guy, grab his head and jump out of there!#)", x = 61, y = 52, zone = "Ashenvale" },
         [20] = { str = "Go do #DOID6441#, done at the Night Run, #COORD[67,53]#  (entrance to the area is around #COORD[64,42]#).", x = 67, y = 53, zone = "Ashenvale" },
         [21] = { str = "Run back to #ZONEID431# (don't hearth).  Turn in #INID6441#" },
         [22] = { str = "Fly to Stonetalon Mountains..." },
         --[23] = { str = "." },
         --[24] = { str = "." },
      }
   },

   -----------27-27 Stonetalon Mountains
   --[208] = {
   [2727] = {
      title = "27-27 Stonetalon Mountains",
      --n = "27-27 Stonetalon Mountains",
      --pID = 207, nID = 209,
      --itemCount = 11,
      items = {
         [1] = { str = "27-27 #ZONEID406#" },
         [2] = { str = "Turn in #INID1088# ... I SKIP #SKIPID1089# " },
         [3] = { str = "Make #ZONEID460# your home." },
         [4] = { str = "Accept and do #DOID6283# , go kill Bloodfury Ripper at #COORD[30,63]# (grinding mobs along the way) , then hearth back.." },
         [5] = { str = "Turn #INID6283# in." },
         [6] = { str = "Fly to Thunder Bluff." },
         [7] = { str = "Make Thunder Bluff your home." },
         [8] = { str = "Turn in #INID1195# at #COORD[54,51]# in TB... accept #GETID1195# part2", x = 54, y = 51, zone = "Thunder Bluff" },
         [9] = { str = "Fly to Thousand Needles..." },
         --[10] = { str = "." },
         --[11] = { str = "." },
      }
   },

   -----------27-29 Thousand Needles
   --[209] = {
   [2729] = {
      title = "27-29 Thousand Needles",
      --n = "27-29 Thousand Needles",
      --pID = 208, nID = 210,
      --itemCount = 37,
      items = {
         [1] = { str = "27-29 #ZONEID400#" },
         [2] = { str = "Turn in #INID1195# ... accept #GETID1195# part3" },
         [3] = { str = "I do the following order:" },
         [4] = { str = "#DOID1195#, charge the brazier in the cave at #COORD[44,37]#.", x = 44, y = 37, zone = "Thousand Needles" },
         [5] = { str = "Go to Whitereach Post #COORD[21,32]#, accept #GETID5151# , Turn in #INID4865# ...accept #GETID5062# ", x = 21, y = 32, zone = "Thousand Needles" },
         [6] = { str = "Go do: #DOID5062# #COORD[35,36]#", x = 35, y = 36, zone = "Thousand Needles" },
         [7] = { str = "#DOID4767# #COORD[11,36]#", x = 11, y = 36, zone = "Thousand Needles" },
         [8] = { str = "#DOID4770#, escort starts at #COORD[17,40]#.  (If the Elite gets in the way, skip it).", x = 17, y = 40, zone = "Thousand Needles" },
         [9] = { str = "#DOID1131#, he patrols around #COORD[16,25]#.", x = 16, y = 25, zone = "Thousand Needles" },
         [10] = { str = "Hearth to Thunder Bluff." },
         [11] = { str = "Get new spells/abilities." },
         [12] = { str = "Turn in #INID1131# (on Hunter Rise) ... accept #GETID1136# " },
         [13] = { str = "Turn in #INID5062# (on Elder Rise) ... accept #GETID5088# " },
         [14] = { str = "Fly back to 1K Needles." },
         [15] = { str = "Make Freewind Post your home." },
         [16] = { str = "Turn in #INID1195# and #INID4767# " },
         [17] = { str = "Go to the Darkcloud Pinnacle (the entrance ramp is at #COORD[31,36]#), and do the following quests: #DOID5064#, the notes are up in the rises at #COORD[31,32]#, #COORD[33,39]#, and #COORD[39,41]#", x = 31, y = 36, zone = "Thousand Needles" },
         [18] = { str = "#DOID5088# done at #COORD[37,35]#.", x = 37, y = 35, zone = "Thousand Needles" },
         [19] = { str = "#DOID5147#, at #COORD[38,27]#.", x = 38, y = 27, zone = "Thousand Needles" },
         [20] = { str = "#DOID4904#, escort quest starts at #COORD[38,27]#.", x = 38, y = 27, zone = "Thousand Needles" },
         [21] = { str = "Go to Whitereach Post #COORD[21,32]#, turn in #INID5088# and #INID4770#", x = 21, y = 32, zone = "Thousand Needles" },
         [22] = { str = "You should be level 29 by now, if not grind to level 29, I grind away at centuars around Camp E'Thok #COORD[18,23]#", x = 18, y = 23, zone = "Thousand Needles" },
         [23] = { str = "Then do #DOID5151# (Elite) at #COORD[22,24]#. Clear mobs around the cage, free him and kill him.", x = 22, y = 24, zone = "Thousand Needles" },
         [24] = { str = "Kill the #NPCID10617#, he drops #ITEMID12564# which starts #GETID4881# Turn in for Easy XP.  Also turn in #INID5151#" },
         [25] = { str = "Then do: #DOID4966# " },
         [26] = { str = "If you are not at least 4 bars from level 30, grind until you are.  Then hearth back to Freewind Post." },
         [27] = { str = "Turn in #INID4904# #INID5147# #INID5064#" },
         [28] = { str = "NOTE: I skip #SKIPID1150# " },
         [29] = { str = "Fly to Orgrimmar" },
         [30] = { str = "Make Orgrimmar your home." },
         [31] = { str = "Get new spells/abilities." },
         [32] = { str = "Go to Undercity (UC).  You need to get on the zeppelin just right outside of Orgrimmar." },
         [33] = { str = "Run to #ZONEID272# in #ZONEID267#. (You can just bypass the UC for now if you like and just follow the path south out of Tirisfal Glades and into Silverpine Forest)" },
         --[36] = { str = "." },
         --[37] = { str = "." },
      }
   },

   -----------29-30 Hillsbrad Foothills
   --[210] = {
   [2930] = {
      title = "29-30 Hillsbrad Foothills",
      --n = "29-30 Hillsbrad Foothills",
      --pID = 209, nID = 301,
      --itemCount = 19,
      items = {
         [1] = { str = "29-30 #ZONEID267#" },
         [2] = { str = "Accept #GETID494# (at the Southpoint Tower, right when u enter Hillsbrad)" },
         [3] = { str = "Once at Tarren Mill:" },
         [4] = { str = "Turn in #INID494# " },
         [5] = { str = "Accept #GETID552# " },
         [6] = { str = "Accept #GETID501# " },
         [7] = { str = "GET FLIGHT PATH THERE!!!!" },
         [8] = { str = "Go start killing Yetis..." },
         [9] = { str = "I keep grinding away at Yetis until I hit 30. (OPTIONAL: you could go do RFK instead of the grinding)" },
         [10] = { str = "Also, the #ITEMID3708# should have dropped before hitting 30, if not keep grinding away till it does." },
         [11] = { str = "As soon as i hit 30, I hearth to Orgrimmar to get new spells/abilities." },
         [12] = { str = "Then go back to Hillsbrad." },
         [13] = { str = "Turn #INID552# in, accept the next part to it." },
         [14] = { str = "Go back to the Yeti cave..." },
         [15] = { str = "Charge The Flame of Azel and the Flame of Veraz,  for the quest #DOID552# " },
         [16] = { str = "I keep grinding away at Yetis until my pet levels up." },
         [17] = { str = "Go up into Alterac Mountains..." },
         --[18] = { str = "." },
         --[19] = { str = "." },
      }
   },
}
