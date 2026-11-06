--[[--------------------------------------------------
   003_Horde_40to50.lua
   Authors: mrmr, lanjelin
   Version: 1.04.3
   ------------------------------------------------------
   Description: Guide Serie - 003 From Lvl 40 to Lvl 50
   1.04.1
   -- First Release
   Horde's Guide
   from level 40 to lever 50
   1.04.2
   -- no changes in here for this revision
   1.04.3
   -- Cleanup in text, changed formatting of coords
   Removed unavailable quests, and some elite quests
   Playtested every step.
   ------------------------------------------------------
   Connection:
--]]--------------------------------------------------
Table_003_Horde_40to50 = {
   [4041] = {
      title = "40-41 Badlands",
      --L- Playtested, need a small fix at 6
      items = {
         [1] = { str = "40-41 #ZONEID3#" },
         [2] = { str = "The goal here is not to leave till you're level 41, so grind mobs everywhere you go. As you enter Badlands, run southwest to #COORD[42,52]#.", x = 42, y = 52, zone = "Badlands" },
         [3] = { str = "Turn in #INID1106# at #COORD[42,52]# , accept #GETID1108# and #GETID703# ", x = 42, y = 52, zone = "Badlands" },
         [4] = { str = "Go down south a little and do #DOID1108# #COORD[51,67]#", x = 51, y = 67, zone = "Badlands" },
         [5] = { str = "Go back up and turn #INID1108# in, accept #GETID1137#." },
         [6] = { str = "Then go north-west and accept #GETID710# at #COORD[25,44]#. NOTE: If you have the #ITEMID3829#, the #ITEMID4389#, the #ITEMID929#, the #ITEMID3823# and the #ITEMID2868# items, accept and complete all the quests there.", x = 25, y = 44, zone = "Badlands" },
         --L- Needs to be split
         [7] = { str = "Grind your way west to Kargath #COORD[04,46]#.", x = 4, y = 46, zone = "Badlands" },
         [8] = { str = "Get flightpath at Kargath. Do NOT make Kargath your home, it should still be Booty Bay." },
         [9] = { str = "Accept #GETID1419#, #GETID1420#, #GETID782# and #GETID2203#." },
         [10] = { str = "Go do #DOID1419# and #DOID703# around #COORD[14,60]#", x = 14, y = 60, zone = "Badlands" },
         [11] = { str = "Do #DOID782#, #NPCID2944# patrols the area counter-clockwise. (skip the next part of this quest)." },
         [12] = { str = "Do #DOID2203#." },
         [13] = { str = "Do #DOID710#, kill #NPCID2735# at #COORD[19,43]#. Turn in, accept next.", x = 19, y = 43, zone = "Badlands" },
         [14] = { str = "Do #DOID710#, kill #NPCID92# at #COORD[13,35]#. Turn in, accept next.", x = 13, y = 35, zone = "Badlands" },
         [15] = { str = "Do #DOID710#, kill #NPCID2736# at #COORD[8,84]#.", x = 8, y = 84, zone = "Badlands" },
         [16] = { str = "Then make sure all Badlands quests besides #GETID1420# are done and turned in." },
         [17] = { str = "You should be about level 41 right now, if not grind to it." },
         [18] = { str = "Hearth to BB and check if you have #DOID1116# in your questlog. If not, go accept it from #NPCID773# at #COORD[27,77]#", x = 27, y = 77, zone = "Stranglethorn Vale" },
         [19] = { str = "Fly to Grom'gol." },
         [20] = { str = "Go turn in all the #INID338# at Nesingwary's Expedition #COORD[35,10]# if you have all the pages for it, if not you have another chance to turn this in again later. You can also look in the AH for your missing pages.", x = 35, y = 10, zone = "Badlands" },
         [21] = { str = "Then run all the way to Swamp of Sorrows, stopping along the way to accept #GETID1372# in Duskwood at #COORD[87,35]#", x = 87, y = 35, zone = "Duskwood" },
         [22] = { str = "Turn in #INID1372# at the guy next to the questiver. Get #GETID1372# pt.2, then run to Swamp of Sorrows." },
      }
   },
   [4142] = {
      title = "41-42 Swamp of Sorrows",
      --L- Playtested, needs adjust, some of the quests at 13-16 can be grouped.
      items = {
         [1] = { str = "41-42 #ZONEID8#" },
         [2] = { str = "Start off by doing #DOID1116# #COORD[14,59]#.", x = 14, y = 59, zone = "Swamp of Sorrows" },
         [3] = { str = "#DOID1372# kill the #NPCID1081# for the #ITEMID6081# at #COORD[06,32]#", x = 6, y = 32, zone = "Swamp of Sorrows" },
         [4] = { str = "Find and kill #NPCID5477#, he drops #ITEMID6196#, which starts #GETID1392#. Spawns at #COORD[48,38]#, but roams the area.", x = 48, y = 38, zone = "Swamp of Sorrows" },
         [5] = { str = "Go turn in #INID1392# #COORD[25,31]#, accept #GETID1389# ", x = 25, y = 31, zone = "Swamp of Sorrows" },
         [6] = { str = "Grind your way to Stonard #COORD[45,54]#, make it your home, and pick up the flightpath", x = 45, y = 54, zone = "Swamp of Sorrows" },
         [7] = { str = "Accept #GETID698# and #GETID1430#, turn in #INID1420#, accept #GETID1424# (Elite)." },
         [8] = { str = "Do #DOID1424#, #ITEMID6175# is looted in the water around temple of Atal'hakkar (Sunken Temple)." },
         [9] = { str = "Do #DOID698# then turn it in at #COORD[81,80]#, accept #GETID698# pt.2 and go do it.", x = 81, y = 80, zone = "Swamp of Sorrows" },
         [10] = { str = "Go do #DOID1430# and #DOID1372#, #NPCID768#' hearts." },
         [11] = { str = "Do #DOID1389#, then turn it in at #COORD[25,31]#", x = 25, y = 31, zone = "Swamp of Sorrows" },
         [12] = { str = "Do #DOID1373#." },
         [13] = { str = "Turn in #INID698# pt.2, accept #GETID1422#" },
         [14] = { str = "Turn in #INID1422# then accept #GETID1422# pt.2." },
         [15] = { str = "Go do #DOID1422# pt.2 along with #DOID1430#." },
         [16] = { str = "Turn in #INID1422# pt.2, accept #GETID1428#." },
         [17] = { str = "Go do #DOID1428# then turn it in." },
         [18] = { str = "Hearth to Stonard." },
         [19] = { str = "Turn in #INID1430# and #INID1424#, accept #GETID1429# " },
         [20] = { str = "Should be about lvl 42 now, if not grind to it." },
         [21] = { str = "Fly to Grom'gol." },
      }
   },
   [4243] = {
      title = "42-43 Stranglethorn Vale",
      --L- Playtested
      items = {
         [1] = { str = "42-43 #ZONEID33#" },
         [2] = { str = "Accept #GETID570# pt.4 and #GETID598#." },
         [3] = { str = "Fly to Booty Bay, and accept all quests, #GETID595#, #GETID587#, #GETID1127#, #GETID617#, #GETID609#, #GETID2872#, #GETID348# and #GETID576#" },
         [4] = { str = "Turn in #INID1116#, make Booty Bay your home." },
         [5] = { str = "Do #DOID595# along with #DOID587# and #DOID576# These are done at the shore around #COORD[31,80]#, and some more mobs can be found at #COORD[27,70]#.", x = 31, y = 80, zone = "Stranglethorn Vale" },
         [6] = { str = "Also do #DOID348#, you will need 10x #ITEMID2799#, and the #NPCID1449# is in the cave at #COORD[34,60]#", x = 34, y = 60, zone = "Stranglethorn Vale" },
         [7] = { str = "Do #DOID570# pt.4 along with #DOID617# #COORD[25,63]#", x = 25, y = 63, zone = "Stranglethorn Vale" },
         [8] = { str = "Do #DOID1127# along with #DOID609# #COORD[34,52]# and #COORD[39,58]#", x = 34, y = 52, zone = "Stranglethorn Vale" },
         [9] = { str = "Do #DOID209# along with #DOID598# at #COORD[46,42]#. Skip #DOID598# if you get to 43 before getting all.", x = 46, y = 42, zone = "Stranglethorn Vale" },
         [10] = { str = "If not at least 2-3 bars away from 43, keep grinding til you are, then hearth to Booty Bay." },
         [11] = { str = "Turn in ALL quests and make sure to accept #GETID2864# and #GETID1117# from #NPCID773#, and #GETID580# from #NPCID2491#." },
         [12] = { str = "Fly to Grom'gol and turn in #INID570# pt.4 and #INID598#. Accept #GETID2932#." },
         [13] = { str = "Get on the zeppelin to Orgrimmar" },
         [14] = { str = "Once there go to #NPCID4485# at #COORD[75,34]# and accept #GETID2981#", x = 75, y = 34, zone = "Orgrimmar" },
         [15] = { str = "Fly to Thunder Bluff, get #ITEMID5811# from the bank if you put it there, then turn in #INID1136#, accept #GETID1205# at #COORD[61,81]#.", x = 61, y = 81, zone = "Thunder Bluff" },
         [16] = { str = "Fly to Desolace." },
      }
   },
   [4342] = {
      title = "43-43 Desolace",
      --L- Playtested and corrected
      items = {
         [1] = { str = "43-43 #ZONEID405#" },
         [2] = { str = "Make Shadowprey Village your home." },
         [3] = { str = "Accept #GETID5581# at #COORD[26,68]#", x = 26, y = 68, zone = "Desolace" },
         [4] = { str = "Go turn in #INID1373# at #COORD[36,79]#, SKIP #SKIPID1374# ", x = 36, y = 79, zone = "Desolace" },
         [5] = { str = "Go to Mannoroc Coven at #COORD[50,76]# and do #DOID5581# ", x = 50, y = 76, zone = "Desolace" },
         [6] = { str = "Then hearth or run back to Shadowprey Village" },
         [7] = { str = "Turn in #INID5581# at #COORD[26,68]#", x = 26, y = 68, zone = "Desolace"},
         [8] = { str = "Fly to Dustwallow Marsh." },
      }
   },
   [4343] = {
      title = "43-43 Dustwallow Marsh",
      --L- Playtested and corrected
      items = {
         [1] = { str = "43-43 #ZONEID15#" },
         --[2] = { str = "Accept #GETID1169# " },
         [2] = { str = "Go down to #COORD[40,36]# and accept #DOID1273# then do it.", x = 40, y = 36, zone = "Dustwallow Marsh" },
         [3] = { str = "Go down and do #DOID1205# around #COORD[47,55]#", x = 47, y = 55, zone = "Dustwallow Marsh" },
         [4] = { str = "Do #DOID1261#, kill the mobs at around #COORD[58,63]#", x = 58, y = 63, zone = "Dustwallow Marsh" },
         --[6] = { str = "Do #DOID1169# at #COORD[46,68]#.", x = 46, y = 68, zone = "Dustwallow Marsh" },
         [5] = { str = "Then grind your way back to Brackenwall Village." },
         --[8] = { str = "Turn in #INID1273# and #INID1169#, accept #GETID1170# " },
         --[9] = { str = "Run back and forth completing #DOID1170# and #DOID1170# pt.2. Skip #SKIPThe Brood of Onyxia pt.3#" },
         [6] = { str = "Turn in #INID1261#, accept #GETID1262#." },
         [7] = { str = "Fly to Tanaris." },
      }
   },
   [4344] = {
      title = "43-44 Tanaris",
      --L- Playtested and corrected
      items = {
         [1] = { str = "43-44 #ZONEID440#" },
         [2] = { str = "Go into Gadgetzan, make it your home." },
         [3] = { str = "Accept: #GETID2781# and #GETID2875# from the #ITEMWanted! Poster#." },
         [4] = { str = "Turn in #INID2864#, accept #GETID992#, #GETID1690# and #GETID1707#." },
         [5] = { str = "Go to the Shimmering Flats in Thousand Needles, at #COORD[78,77]# and turn in #INID1117#, #INID1137# and #INID1187#, accept #GETID1188#.", x = 53, y = 76, zone = "Tanaris" },
         [6] = { str = "Accept #GETID1190#, Turn #INID1190# in at #NPCID4708#, then go pick up #ITEMRizzle's Plans# at #COORD[77,77]#, accept #GETID1194#." },
         [7] = { str = "Accept #GETID1118# at #NPCID4451#, turn in #INID1194# at #NPCID4629#." },
         [8] = { str = "Hearth back to Gadgetzan." },
         [9] = { str = "Turn in #INID1188#. #SKIPSKIP the next part to this quest#." },
         [10] = { str = "Then grind your way east to Steamwheedle Port at #COORD[67,23]#", x = 67, y = 23, zone = "Tanaris" },
         [11] = { str = "Accept #GETID8365# and #GETID3520#, turn in #INID2872# and accept #GETID2873#" },
         [12] = { str = "Do #DOID1690# along with #DOID1707# at #COORD[64,29]# or #COORD[60,23]#", x = 64, y = 29, zone = "Tanaris" },
         [13] = { str = "Then do the following at Lost Rigger Cove #COORD[72,47]#; #DOID8365#, #DOID2873# and #DOID2875# ", x = 72, y = 47, zone = "Tanaris" },
         [14] = { str = "#DOID2876# (find this in one of the #ITEMID9276#, looted from mobs at Lost Rigger Cove. If the item cannot be found, just skip it)" },
         [15] = { str = "Once they're all done, hearth to Gadgetzan." },
         [16] = { str = "Turn in #INID1707#, #INID1690#, accept #GETID1691#. Save leftover #ITEMID8483#." },
         [17] = { str = "Go do #DOID992# at #COORD[38,29]#, grinding mobs along the way. Then go back and turn it in.", x = 38, y = 29, zone = "Tanaris" },
         [18] = { str = "Go to Steamwheedle Port. #COORD[67,23]#", x = 67, y = 23, zone = "Tanaris" },
         [19] = { str = "Turn in ALL quests there, accept #GETID2874#." },
         [20] = { str = "Then do #DOID1691# along with #DOID2781# at #COORD[59,37]#.", x = 59, y = 37, zone = "Tanaris" },
         [21] = { str = "Hearth to Gadgetzan. Put all the #ITEMID8483# you have in the bank, as you will need them for a later quest." },
         [22] = { str = "Turn in #INID1691# and #INID2781#." },
         [23] = { str = "Fly to Freewind Post." },
         [24] = { str = "Run west into Feralas, #COORD[08,11]#", x = 8, y = 11, zone = "Thousand Needles" },
      }
   },
   [4446] = {
      title = "44-46 Feralas",
      --L- Playtested and corrected, needs a check @ 27
      items = {
         [1] = { str = "44-46 #ZONEID357#" },
         [2] = { str = "Run to Camp Mojache. #COORD[75,44]#", x = 75, y = 44, zone = "Feralas" },
         [3] = { str = "Turn in #INID2981#" },
         [4] = { str = "Accept ALL quests there: #GETID2973#, #GETID2975#, #GETID2987#, #GETID2862#, #GETID2821# and #GETID3121#. Skip #SKIPID3128# for now." },
         [5] = { str = "Get flightpath, and make Camp Mojache your home." },
         [6] = { str = "Then do #DOID2862# just north of Camp Mojache, #COORD[72,39]#", x = 72, y = 39, zone = "Feralas" },
         [7] = { str = "Do #DOID2975# along with #DOID2987# #COORD[75,31]#. Make sure to click one of the scrolls laying on the ground to start #GETID2978#.", x = 75, y = 31, zone = "Feralas" },
         [8] = { str = "Then do #DOID2973# #COORD[67,48]#", x = 67, y = 48, zone = "Feralas" },
         [9] = { str = "Go back to Camp Mojache, turn in ALL quests, accept all new quests: #GETID2979#, #GETID2975#, #GETID2974# and #GETID2863#" },
         [10] = { str = "Go do #DOID2863# at #COORD[72,56]# then turn it in. Accept #GETID2902#.", x = 72, y = 56, zone = "Feralas" },
         [11] = { str = "Go turn in #INID2902# at #COORD[72,56]#, click the #ITEMID9266# lying on top of a box, accept #GETID2903# ", x = 72, y = 56, zone = "Feralas" },
         [12] = { str = "Then go do #DOID2974# #COORD[67,46]#", x = 67, y = 46, zone = "Feralas" },
         [13] = { str = "Hearth back to Camp Mojache, turn in #INID2903# and #INID2974#, accept alle new quests: #GETID7731#, #GETID7730# and #GETID2974#." },
         [14] = { str = "If #ITEMID8705# drops, accept the quest #GETID2766# . Turn in #INID2766# at #COORD[53,55]#.", x = 53, y = 55, zone = "Feralas" },
         [15] = { str = "Then go do the following: #DOID7731# along with #DOID7730# #COORD[77,62]#", x = 77, y = 62, zone = "Feralas" },
         [16] = { str = "#DOID3520# #COORD[55,56]#", x = 55, y = 56, zone = "Feralas" },
         [17] = { str = "#DOID2821# #COORD[53,55]#", x = 53, y = 55, zone = "Feralas" },
         [18] = { str = "#DOID2975# part2 #COORD[59,68]#", x = 59, y = 68, zone = "Feralas" },
         [19] = { str = "#DOID2979# #COORD[59,68]#, kill Gordunni Mage-Lord", x = 59, y = 68, zone = "Feralas" },
         [20] = { str = "Make sure you pick up an #ITEMID8564# down south-west around #COORD[59,76]# (looted from a nest), this will be turned in at Tanaris for a later quest.", x = 53, y = 76, zone = "Feralas" },
         [21] = { str = "Run back to Camp Mojache, then go turn those quests in. Accept #GETID3002#" },
         [22] = { str = "Fly to Orgrimmar." },
         [23] = { str = "Accept #GETID649# from #NPCID6966# at #COORD[59,36]#", x = 59, y = 36, zone = "Orgrimmar" },
         [24] = { str = "Then turn in #INID649# at the guy right next to #NPCID6386#, accept #GETID649# again." },
         [25] = { str = "Turn in #INID1148# and #INID2974# at #NPCID4484#, accept #GETID3504# #COORD[75,34]#.", x = 75, y = 34, zone = "Orgrimmar" },
         [26] = { str = "Go turn in #INID3121#, accept #GETID3122# in Cleft of Shadow, #COORD[49,50]#", x = 49, y = 50, zone = "Orgrimmar" },
         [27] = { str = "Go turn in #GETID1262#, accept/complete #DOID7541# in Valley of Wisdom, #COORD[38,38]#.", x = 38, y = 38, zone = "Orgrimmar" },
         --L- Needs to be checked
         [28] = { str = "Go turn in #INID3002# in Valley of Spirits, #COORD[39,86]#", x = 39, y = 86, zone = "Orgrimmar" },
         [29] = { str = "Also get new spells/abilities while you are in Orgrimmar.", x = 37, y = 87, zone = "Orgrimmar" },
         [30] = { str = "You should have 90+ gold by now, so go buy your mount!" },
         [31] = { str = "Hearth back to Feralas." },
         [32] = { str = "Turn in #INID3122#, accept #GETID3128# and #GETID3123# " },
         [33] = { str = "Then do #DOID3128#. Kill #NPCID5278# at #COORD[68,48]# for #ITEMID9589#.", x = 68, y = 48, zone = "Feralas" },
         [34] = { str = "Kill #NPCID7584# (Elite) at #COORD[57,73]# for #ITEMID9590#. You'll have to wait for respawn, so meanwhile do next step.", x = 57, y = 73, zone = "Feralas" },
         [35] = { str = "Kill #NPCID5300# at #COORD[56,62]# and south for #ITEMID9591# and #ITEMID9592#.", x = 56, y = 62, zone = "Feralas" },
         [36] = { str = "If you're not level 46, keep grinding Hippogryphs till you are." },
         [37] = { str = "If #ITEMID8705# drops, accept the quest #GETID2766# . Turn in #INID2766# at #COORD[53,55]#.", x = 53, y = 55, zone = "Feralas" },
         [38] = { str = "Hearth or run back to Camp Mojache." },
         [39] = { str = "Turn in #INID3128#, accept #GETID3380#." },
         [40] = { str = "Fly to Thunder Bluff" },
         [41] = { str = "Turn in #INID1205# at #COORD[61,81]#.", x = 61, y = 81, zone = "Thunder Bluff" },
         [42] = { str = "Fly to Splintertree Post (Ashenvale)" },
         [43] = { str = "Then go east into Azshara, there is a bridge just east of #COORD[92,46]#", x = 92, y = 46, zone = "Ashenvale" },
      }
   },
   [4646] = {
      title = "46-46 Azshara",
      --L- Playtested and corrected
      items = {
         [1] = { str = "46-46 #ZONEID16#" },
         [2] = { str = "Go accept #DOID5535# and #DOID5536# at #COORD[11,78]#", x = 11, y = 78, zone = "Azshara" },
         [3] = { str = "Go do them at #COORD[17,71]# and #COORD[20,62]#, then run back and turn them in.", x = 17, y = 71, zone = "Azshara" },
         [4] = { str = "Go to Valormok at #COORD[22,52]#", x = 22, y = 52, zone = "Azshara" },
         [5] = { str = "Turn in #INID3504#, #SKIPskip the next part to this quest#." },
         [6] = { str = "Get the FP there and fly to Orgrimmar." },
         [7] = { str = "Take the Zeppelin to Undercity." },
         [8] = { str = "Go to the Magic Quarter and accept #GETID2995# at #COORD[73,32]#", x = 73, y = 32, zone = "Undercity" },
         [9] = { str = "Head to Apothecarium and accept #GETID3568# and #GETID232#, downstairs #COORD[49,70]#", x = 49, y = 70, zone = "Undercity" },
         [10] = { str = "Go turn in #GETID232# at #COORD[58,55]#", x = 58, y = 55, zone = "Undercity" },
         [11] = { str = "Then back to the apothecary, turning in #INID232#, accept #GETID243#", x = 49, y = 70, zone = "Undercity" },
         [12] = { str = "You can put the #ITEMID8523# and the #ITEMID10695# in the Bank for now."},
         [13] = { str = "Fly to #ZONEID272# and make it your home."},
         [14] = { str = "Head to the #ZONEID47#. There is a passage at around #COORD[85,32]#", x = 85, y = 32, zone = "Hillsbrad Foothills" },
      }
   },
   [4647] = {
      title = "46-47 Hinterlands",
      --L- Playtested and corrected
      items = {
         [1] = { str = "46-47 #ZONEID47#" },
         [2] = { str = "Go turn in #INID649# at #COORD[27,49]#, accept #GETID77# ", x = 27, y = 49, zone = "The Hinterlands" },
         [3] = { str = "Ride all the way to Revantusk Village at #COORD[77,80]#, get the flightpath there, at the docks.", x = 77, y = 80, zone = "The Hinterlands" },
         [4] = { str = "Accept #GETID7839#, #GETID7844#, #GETID7841#, #GETID7828#, #GETID7829# and #GETID7830# " },
         [5] = { str = "Then go do #DOID580#, #DOID7839#, #DOID7844# #DOID7828#, #DOID7829#, #DOID3123#, #DOID7830#, #DOID2995#, #DOID7841# and #DOID77# - turn it in when you're in the area." },
         [6] = { str = "Do #DOID2742#, escort quest that starts at #COORD[31,48]#", x = 31, y = 48, zone = "The Hinterlands" },
         [7] = { str = "Do #DOID2932#, be sure to accept #GETID2933# from one of those little bottles on the table. Place #ITEMID9319# at #COORD[23,58]#", x = 32, y = 58, zone = "The Hinterlands" },
         [8] = { str = "If #ITEMID8704# drops, accept the quest #GETID485#. Turn it in at #COORD[49,38]#", x = 49, y = 38, zone = "The Hinterlands" },
         [9] = { str = "Turn in #INID2742# at #COORD[86,59]#, accept #GETID2782# ", x = 86, y = 59, zone = "The Hinterlands" },
         [10] = { str = "Go to Revantusk Village, and turn in ALL the quests." },
         [11] = { str = "Then get to the flightpath, and fly to #ZONEID272#." },
         [12] = { str = "Turn in #INID2933#, accept #GETID2934# " },
         [13] = { str = "Then ride back into #ZONEID47#, don’t fly!" },
         [14] = { str = "Go do #DOID2934#, turn in #INID1429#, accept #GETID1444#" },
         [15] = { str = "When done, hearth to #ZONEID272#." },
         [16] = { str = "Turn in #INID2934#, SKIP #SKIPID2935# Only accept this quest if you still need to get a mount as orc/troll, as you turn it in in the same spot." },
         [17] = { str = "Fly to Undercity." },
         [18] = { str = "Turn in #INID2995# and #INID2782#. " },
         [19] = { str = "Get 15x #ITEMID4306# from the bank/AH for a later quest." },
         [20] = { str = "Get on the zeppelin to Grom'gol." },
      }
   },
   [4747] = {
      title = "47-47 Stranglethorn Vale",
      --L- Playtested and corrected
      items = {
         [1] = { str = "47-47 #ZONEID33#" },
         [2] = { str = "Turn in #INID2932#."},
         [3] = { str = "Go do #DOID194#, kill #NPCID730# at #COORD[28,44]#, and go turn it in", x = 28, y = 44, zone = "Stranglethorn Vale" },
         [4] = { str = "Accept #GETID208# (Elite), go do it, then turn it in." },
         [5] = { str = "Go to Grom'gol then fly to Booty Bay." },
         [6] = { str = "Accept #GETID595# pt.5, turn in #INID580#." },
         [7] = { str = "Make Booty Bay your home." },
         [8] = { str = "Turn in #INID1118# and #INID2874# " },
         [9] = { str = "Find #OBJECTID2560# laying around the shore east of Booty Bay #COORD[33,76]#, until #ITEMID4098# drop, which starts #GETID594# ", x = 33, y = 76, zone = "Stranglethorn Vale" },
         [10] = { str = "Go turn #INID594# in at #COORD[38,80]# #SKIPSKIP the next part#, its a 51 elite.", x = 38, y = 80, zone = "Stranglethorn Vale" },
         [11] = { str = "Then go do #DOID595# pt.5, kill the three pirates in the three ships, while doing it, find #GETID624#, it's usually a little scroll downstairs in the middle ship." },
         [12] = { str = "Then hearth back to Booty Bay, if hearth stone still is on a cooldown, die on purpose." },
         [13] = { str = "Turn in #INID595# pt.5" },
         [14] = { str = "Fly to Kargath (Badlands)." },
         [15] = { str = "Go into Searing Gorge through the passage at #COORD[03,62]#.", x = 3, y = 62, zone = "Badlands" },
      }
   },
   [4748] = {
      title = "47-48 Searing Gorge",
      --L- Playtested and massively corrected
      items = {
         [1] = { str = "47-48 #ZONEID51#" },
         [2] = { str = "Go south-east and do #DOID4449#, guy in the outhouse #COORD[65,62]#, then turn it in. Accept #GETID4450#, pick up #ITEMID11727# just beside the outhouse.", x = 65, y = 62, zone = "Searing Gorge" },
         [3] = { str = "Kill #NPCID5856# for the #DOID4450# quest." },
         [4] = { str = "Talk to #NPCID8478# at #COORD[39,38]# on your way to Thorium Point #COORD[35,25]#. Listen to him to do #DOID3441#, complete it and get #GETID3442#.", x = 35, y = 25, zone = "Searing Gorge" },
         [5] = { str = "Go to Thorium Point, get the flightpath, and accept #GETID7722#.", x = 35, y = 25, zone = "Searing Gorge" },
         [6] = { str = "Do #DOID7722# -the plans are right behind #NPCID14621#, and #DOID3442# by killing #NPCID5853# and #NPCID5850#/#NPCID5855#." },
         [7] = { str = "Turn in #INID3442# and accept #GETID3443#, go turn in #INID7722#, and accept #GETID7729# from the #ITEMID4639#." },
         [8] = { str = "Go do #DOID3443# and #DOID7729#." },
         [9] = { str = "If #ITEMID11818# drops, accept the quest, and go turn it in at the outhouse at #COORD[65,62]#. If you're far from 48, you could grind a while for it.", x = 65, y = 62, zone = "Searing Gorge" },
         [10] = { str = "Turn in #INID3443#, SKIP #SKIPID3452#, turn in #INID7729#." },
         [11] = { str = "Make sure you have all 20 #ITEMID11725#, then head south into Burning Steppes, via Black Rock Mountains #COORD[34,77]#.", x = 34, y = 77, zone = "Searing Gorge" },
         [12] = { str = "Get flightpath there at #COORD[65,25]#, and fly directly to Stonard (Swamp of Sorrows).", x = 65, y = 25, zone = "Burning Steppes" },
      }
   },
   [4848] = {
      title = "48-48 Swamp of Sorrows",
      --L- Playtested and corrected
      items = {
         [1] = { str = "48-48 #ZONEID8#" },
         [2] = { str = "Do NOT make Stonard your home, it should still be Booty Bay." },
         [3] = { str = "Go to the #NPCID7570# #COORD[34,66]#, keep talking to him till you get the quest #GETID2621# ", x = 34, y = 66, zone = "Swamp of Sorrows" },
         [4] = { str = "Then go do #DOID624# at #COORD[22,48]#, under the bridge click #OBJECTID2553#. Accept #GETID624# pt.2", x = 22, y = 48, zone = "Swamp of Sorrows" },
         [5] = { str = "Go back to Stonard and turn in #INID2621# and #INID1444#. Accept #GETID2622#" },
         [6] = { str = "Go turn in #INID2622# in the inn, accept #GETID2623# " },
         [7] = { str = "Go do #DOID2623# in the cave at #COORD[65,78]#", x = 65, y = 78, zone = "Swamp of Sorrows" },
         [8] = { str = "Then head north east and kill the mob #NPCID9916# at around #COORD[94,50]# or #COORD[92,65]#, he drops #ITEMID11723# for the quest #DOID4450# ", x = 94, y = 50, zone = "Swamp of Sorrows" },
         [9] = { str = "Go to the #NPCID7570# #COORD[34,66]# and turn in #INID2623#. Accept and do #DOID2801#, just talk with him. SKIP #SKIPID2681#.", x = 34, y = 66, zone = "Swamp of Sorrows" },
         [10] = { str = "Hearth to Booty Bay, and get on the boat to Ratchet." },
         [11] = { str = "Fly to #ZONEID496# (Dustwallow Marsh)." },
         --[11] = { str = "Fly to Brackenwall Village (Dustwallow Marsh). Once there accept #GETID1170# pt.3 " },
         [12] = { str = "Head south and get the #ITEMID11724# for the quest #DOID4450# at #COORD[54,55]#", x = 54, y = 55, zone = "Dustwallow Marsh" },
         --[13] = { str = "Go down a bit and do #DOID1170#, the #ITEM[Eggs of Onyxia]# can be found at #COORD[53,72]# and #COORD[48,75]#", x = 53, y = 72, zone = "Dustwallow Marsh" },
         [13] = { str = "Then head to Bloodfen Burrow cave #COORD[32,66]#, and do #DOID624#, click the #OBJECTID2555# inside the cave, turn in and accept the next part to it.", x = 32, y = 66, zone = "Dustwallow Marsh" },
         --[15] = { str = "Turn in #INID1170#, accept #GETID1173#. Do #DOID1173# Then turn it in." },
         [14] = { str = "Head back to #ZONEID496#, then fly to Gadgetzan (Tanaris)." },
         [15] = { str = "Turn in #INID4450# and #INID243#, accept and complete #DOID379# using #ITEMID8483# from your bank. Put the #ITEMID8524# in the bank for now." },
         [16] = { str = "Fly to Camp Mojache (Feralas)." },
      }
   },
   [4849] = {
      title = "48-49 Feralas",
      --L- Playtested and corrected
      items = {
         [1] = { str = "48-49 #ZONEID357#" },
         [2] = { str = "Make Camp Mojache your home. Turn in #INID3123#, accept #GETID3124#, #GETID3063# and #GETID3062# (Elite)." },
         --L-  ,  #GETID7733# not available!?
         [3] = { str = "Go do #DOID3124# at #COORD[56,63]#", x = 56, y = 63, zone = "Feralas" },
         [4] = { str = "Hearth back to Camp Mojache, Turn in #INID3124# and accept #GETID3125#." },
         [5] = { str = "Go do #DOID3125# at #COORD[68,48]#, turn it in, accept #GETID3126# (Elite).", x = 68, y = 48, zone = "Feralas" },
         [6] = { str = "Go do #DOID3126# (Elite) at #COORD[57,73]#, turn it in, accept #GETID3127# (Elite).", x = 57, y = 73, zone = "Feralas" },
         [7] = { str = "Go accept #GETID7003# at #COORD[45,43]#.", x = 45, y = 43, zone = "Feralas" },
         [8] = { str = "Do #DOID3127# (Elite) along with #DOID7003# at #COORD[39,21]#. Zap then kill the #NPCID5357#, to make them easier to kill.", x = 39, y = 21, zone = "Feralas" },
         [9] = { str = "Do #DOID3063# and #DOID3062# (Elite)." },
         --L- #DOID7733#, #DOID7738#, not available! 1.12.2!?
         [10] = { str = "Run back and turn in #INID7003#, then hearth to Camp Mojache." },
         [11] = { str = "Turn in #INID3127# (Elite), accept #GETID3129#, then turn it in." },
         [12] = { str = "Turn in #INID3063# and #INID3062#." },
         [13] = { str = "Accept #GETID4120#." },
         [14] = { str = "Fly to Gadgetzan (Tanaris)." },
      }
   },
   [4950] = {
      title = "49-50 Tanaris",
      --L- Needs playtest
      items = {
         [1] = { str = "49-50 #ZONEID440#" },
         [2] = { str = "Go to the #ITEMEgg-O-Matic# Machine in Gadgetzan, and turn in the #ITEMID8564# for #DOID2741#." },
         [3] = { str = "Make Gadgetzan your home." },
         [4] = { str = "Accept #GETID2605#, #GETID82#, #GETID4504#, #GETID3362# and #GETID5863#." },
         [5] = { str = "Go turn in #INID3380# at #COORD[53,46]#, accept #GETID3444# and #GETID3161#.", x = 52, y = 45, zone = "Tanaris" },
         [6] = { str = "Do #DOID5863#  in the area at #COORD[40,58]#, #NPCID12046# is in the cave at #COORD[41,57]#. Look for #ITEMID8443# for #DOID3161# while doing these next quests.", x = 40, y = 58, zone = "Tanaris" },
         [7] = { str = "Do #DOID82# at #COORD[34,47]#.", x = 34, y = 47, zone = "Tanaris" },
         [8] = { str = "Do #DOID3362# along with #DOID2605# at #COORD[28,65]#.", x = 28, y = 65, zone = "Tanaris" },
         [9] = { str = "Do #DOID1560#, escort turtle quest that starts in the Thistleshrub Valley, lead #NPCID5955# to #NPCID6015# at #COORD[66,25]#.", x = 66, y = 25, zone = "Tanaris" },
         --[10] = { str = "If you haven't completed #DOID3161# yet, get the rest of the #ITEM[Gahz'ridian Ornaments]# at #COORD[39,73]#.", x = 39, y = 73, zone = "Tanaris" },
         [10] = { str = "Turn in #INID1560# along with #INID3520#, SKIP #SKIPID3527#." },
         [11] = { str = "Go back to Gadgetzan and turn in #INID2605#, accept #GETID2606# turn it in, accept #GETID2641#, turn in #INID3362#, #INID5863# and #INID82#, accept #GETID10#." },
         [12] = { str = "Get your #ITEMID8523# and #ITEMID8524# from the bank, accept #GETID654# from it, then go do it. turn in #INID3161# at #COORD[52,45]#.", x = 52, y = 45, zone = "Tanaris" },
         [13] = { str = "Do #DOID10#, in the cave at #COORD[56,70]# The secret for finding the item for this quest is keep making right turns in the cave and it will lead you to it.", x = 53, y = 70, zone = "Tanaris" },
         [14] = { str = "If the #ITEMID8623# drops, accept the quest #GETID351# and tun it in at #COORD[60,64]#.", x = 60, y = 64, zone = "Tanaris" },
         [15] = { str = "Hearth to Gadgetzan." },
         [16] = { str = "Turn in #INID654#, accept #GETID864#." },
         [17] = { str = "Turn in #INID10#, accept #GETID110#." },
         [18] = { str = "Turn in #INID110#, accept #GETID110# pt.2." },
         [19] = { str = "Turn in #INID110# pt.2, accept #GETID32#." },
         [20] = { str = "Fly to Orgrimmar, and make it your home." },
         [21] = { str = "Get the #ITEMID10695# out of your Bank." },
         [22] = { str = "Fly to Azshara." },
      }
   },
}
