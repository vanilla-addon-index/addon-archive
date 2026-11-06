--[[--------------------------------------------------
   003_Alliance_12to20.lua
   Authors: mrmr, lanjelin
   Version: 1.04.3
   ------------------------------------------------------
   Description: Guide Serie - 003 From Lvl 12 to Lvl 20
   1.04.1
   -- First Release
   Alliance's Guide
   from level 12 to lever 20
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
Table_003_Alliance_12to20 = {
   [1214] = {
      title = "12-14 Darkshore",
      --L- Playtested and corrected
      items = {
         [1] = { str = "12-14 #ZONEID148#" },
         [2] = { str = "Get #GETID3524# pt.1 from #NPCID10219# next to the flightmaster, and #GETID963# at the docks at #COORD[35,43]#.", x = 35, y = 43, zone = "Darkshore" },
         [3] = { str = "Be sure to pick up the flightpath aswell, unless you came from Teldrassil. Set Auberdine as your home." },
         [4] = { str = "Accept #GETID983# upstairs in the Inn, #GETID947# in front of the Inn and #GETID4811# near the bridge" },
         [5] = { str = "Buy some 6 slot bags if you haven’t found 3 by now at #COORD[37,40]#, then accept #GETID954# pt.1 and #GETID958#.", x = 37, y = 40, zone = "Darkshore" },
         [6] = { str = "Go south over the bridge, accept #GETID2118# and #GETID984# pt.1. Skip #SKIPID986# for now." },
         [7] = { str = "Go do #DOID3524# pt.1 at #COORD[36,50]# grind from town to there to get #ITEMID9681# for #DOID983#.", x = 36, y = 50, zone = "Darkshore" },
         [8] = { str = "Turn in #INID983# at #COORD[36,46]# accept #GETID1001#, and turn in #INID3524# pt.1 accept #GETID4681# pt.2.", x = 36, y = 46, zone = "Darkshore" },
         [9] = { str = "Swim out and do #DOID4681# pt.2 at #COORD[32,46]#. Turn it in", x = 32, y = 46, zone = "Darkshore" },
         [10] = { str = "Do #DOID1001# by killing #NPCID2185# in the water. Turn it in at #COORD[42,29]# and accept #GETID1002#. You might have to grind a few mobs to hit lvl 13 to accept the quest.", x = 42, y = 29, zone = "Darkshore" },
         [11] = { str = "Stop at #COORD[42,32]# accept #GETID4723#.", x = 42, y = 32, zone = "Darkshore" },
         [12] = { str = "Turn in #INID954# pt.1 at #COORD[44,36]# grinding along the way, accept #GETID955# pt.2 killing #NPCID1988# around him for #ITEMID5336#.", x = 44, y = 36, zone = "Darkshore" },
         [13] = { str = "Turn in #INID955# pt.2 at #COORD[44,36]# accept #GETID956# pt.3", x = 44, y = 36, zone = "Darkshore" },
         [14] = { str = "Do #DOID956# pt.3 by killing #NPCID2212# and turn it in accept #GETID957# pt.4 " },
         [15] = { str = "Grind to #COORD[47,48]# and do #DOID4811#", x = 47, y = 48, zone = "Darkshore" },
         [16] = { str = "Grind to #COORD[40,53]# to find the camp for #DOID984# pt.1", x = 40, y = 53, zone = "Darkshore" },
         [17] = { str = "Run down to #NPCID3639# at #COORD[40,59]# and accept #GETID953#.", x = 40, y = 59, zone = "Darkshore" },
         [18] = { str = "Do #DOID953#, #DOID957# pt.4, #DOID958# and #DOID963# in this area." },
         [19] = { str = "Turn in #INID953# at #COORD[40,59]#.", x = 40, y = 59, zone = "Darkshore" },
         [20] = { str = "Go across the road of Amath’Aran, and do #DOID2118#." },
         [21] = { str = "Hearth back to Auberdine, turn in #INID963#, #INID4723#, #INID4811#, accept #GETID4812#" },
         [22] = { str = "Fill the #ITEMID14338# in the Moonwell for #DOID4812#, turn in #INID2118#, accept #GETID2138#, turn in #INID984# pt.1 accept #GETID985# Pt.2 and #GETID4761#. Accept #GETID965# pt.1 upstairs." },
         [23] = { str = "Go in the merchant house, turn in #INID958# and #INID4761#, accept #GETID4762#." },
         [24] = { str = "You should be 14 by now, get skills in Darnassus and be sure to accept the quest #GETID730# from #NPCID2912# at #COORD[23,64]#" },
      }
   },
   [1417] = {
      title = "14-17 Darkshore",
      --L- Playtested and corrected
      items = {
         [1] = { str = "14-17 #ZONEID148#" },
         [2] = { str = "Turn in #INID957# pt.4 at #COORD[44,36]#.", x = 44, y = 36, zone = "Darkshore" },
         [3] = { str = "Kill #NPCID2069# and #NPCID2164# all around #COORD[48,30]#, for #DOID2138# and #DOID1002#, then head to #COORD[50,25]# for #DOID4762#.", x = 50, y = 25, zone = "Darkshore" },
         [4] = { str = "Accept #GETID4722# at #COORD[44,20]#", x = 44, y = 20, zone = "Darkshore" },
         [5] = { str = "Turn in #INID1002# at #COORD[51,25]# accept #GETID1003#", x = 51, y = 25, zone = "Darkshore" },
         [6] = { str = "Go to #COORD[55,33]# and do #DOID947#.", x = 55, y = 33, zone = "Darkshore" },
         [7] = { str = "Head south to #COORD[47,48]# to turn in #INID4812#, accept #GETID4813#.", x = 47, y = 48, zone = "Darkshore" },
         [8] = { str = "Grind to #COORD[40,53]# and do #DOID985# Pt.2", x = 40, y = 53, zone = "Darkshore" },
         [9] = { str = "Go to #COORD[37,62]# and accept #GETID4722#", x = 37, y = 62, zone = "Darkshore" },
         [10] = { str = "Continue south and accept #GETID4723# at #COORD[36,70]#.", x = 36, y = 70, zone = "Darkshore" },
         [11] = { str = "Kill #NPCID2165# south of #ZONEID448# for #DOID1003# then turn it in at #COORD[41,81]#.", x = 41, y = 81, zone = "Darkshore" },          
         [12] = { str = "Head over to #COORD[32,80]# and get #GETID4723#.", x = 32, y = 80, zone = "Darkshore" },
         [13] = { str = "Hearth back to Auberdine, and turn in all the #INID4723# quests." },
         [14] = { str = "Accept #GETID1138#, turn in #INID947# and accept #GETID948#, turn in #INID4813#, turn in #INID730# and accept #GETID729#" },
         [15] = { str = "Turn in #INID4762#, accept #GETID4763#, turn in #INID2138# and accept #GETID2139#, turn in #INID985# pt.2 accept #GETID986#" },
         [16] = { str = "Fill the #ITEMID12346# at the Moonwell" }, -- Accept #GETWANTED: Murkdeep!# from the wanted sign next to the inn.
         --L-   [13] = { str = "Stop at #COORD[35,74]# and do #DOWANTED: Murkdeep!# you have to clear the camp, then the 2 waves from the ocean, then he comes. He’s lvl 19 If you have trouble with him just kite him.", x = 35, y = 74, zone = "Darkshore" },
         [17] = { str = "Pick up #ITEMID12342# for #DOID4763# at #COORD[50,35]#.", x = 50, y = 35, zone = "Darkshore" },
         [18] = { str = "Go do #DOID2139# at #COORD[52,37]#.", x = 52, y = 37, zone = "Darkshore" },
         [19] = { str = "Get #ITEMID12343# at #COORD[52,34]#, and #ITEMID12341# at #COORD[52,33]# for #DOID4763#.", x = 52, y = 34, zone = "Darkshore" },
         [20] = { str = "Clear around the bonfire at #COORD[52,33]# and place the food. Kill #NPCID10373#, and loot the #ITEMID12355# from the ground beside him..", x = 52, y = 33, zone = "Darkshore" },
         [21] = { str = "Go to #COORD[55,25]# turn in #INID965# pt.1 Accept #GETID966# pt.2, and do it by killing mobs outside the tower.", x = 55, y = 25, zone = "Darkshore" },
         [22] = { str = "Turn in #INID966# pt.2, and accept #GETID967# pt.3" },
         [23] = { str = "Run to #COORD[53,18]# and accept #GETID4723#", x = 53, y = 18, zone = "Darkshore" },
         [24] = { str = "Do #DOID1138# at the #NPCID6250# here." },
         [25] = { str = "Hearth back to Auberdine." },
         [26] = { str = "Turn in #INID4723#, #INID1138#, #INID4763# and #INID2139#." },
         [27] = { str = "Get on boat to #ZONEID150#, the left/south pier." },
         [28] = { str = "If you got flightpath to #ZONEID144# (Loch Modan), fly there, if not, run to #COORD[54,73]#, and follow the mountainpath to #ZONEID38#.", x = 54, y = 73, zone = "Wetlands" },
      }
   },
   [1718] = {
      title = "17-18 Loch Modan",
      --L- Playtested and corrected
      items = {
         [1] = { str = "17-18 #ZONEID38#" },
         [2] = { str = "Go to the #ZONEID925# bunker at #COORD[24,18]#, and accept #GETID307# and #GETID1338#.", x = 24, y = 18, zone = "Loch Modan" },
         [3] = { str = "Run to the Cave at #COORD[35,18]# and do #DOID307#, #ITEMID2640# are looted from the ground. Turn it in back at the bunker.", x = 35, y = 18, zone = "Loch Modan" },
         [4] = { str = "Go to #ZONEID144# at #COORD[33,50]#, and get the flightpath if you don't have it. DO NOT make it your home.", x = 33, y = 50, zone = "Loch Modan" },
         [5] = { str = "Accept #GETID436# in the last house on the right, go turn it in at #COORD[65,67]#, accept #GETID297# and #GETID298#.", x = 65, y = 67, zone = "Loch Modan" },
         [6] = { str = "Do #DOID297# in the Excavation site just west, then turn it back in." },
         [7] = { str = "Run around the excavation site, and get to the house at #COORD[82,62]#.", x = 82, y = 62, zone = "Loch Modan" },
         [8] = { str = "Turn right when you enter, and accept #GETID385#, then go to the other side and accept #GETID257#" },
         [9] = { str = "Do #DOID257# by killing #NPCID1194# in front of the house." },
         [10] = { str = "Turn in #INID257# accept #GETID258#. Kill #NPCID1192# at around #COORD[76,46]#.", x = 76, y = 46, zone = "Loch Modan" },
         [11] = { str = "Turn in #INID258#, accept #GETID271# pt.1." },
         [12] = { str = "Go to #COORD[64,48]# and accept #GETID2038#. Do #DOID385# here on the shore, and on the island at #COORD[54,38]# if necessary.", x = 64, y = 48, zone = "Loch Modan" },
         [13] = { str = "Get all the parts for #DOID2038#. #ITEMID7376# at #COORD[54,27]#, #ITEMID7343# at #COORD[49,30]#, #ITEMID7346# at #COORD[52,24]#, and #ITEMID7345# at #COORD[48,21]#.", x = 54, y = 27, zone = "Loch Modan" },
         [14] = { str = "Access the #ZONEID146# from the west side and accept #GETID161# pt.1 at #COORD[46,14]#, then run out the east entrance and turn it in at the #OBJECTID257#, accept #GETID199# pt.2", x = 45, y = 13, zone = "Loch Modan" },
         [15] = { str = "Run back and turn in #INID199# pt.2 at #COORD[46,14]#, SKIP #SKIPID250# pt.3.", x = 45, y = 13, zone = "Loch Modan" },
         [16] = { str = "Run down to #ZONEID144# and turn in #INID298# at #COORD[37,47]#, accept #GETID301#.", x = 37, y = 47, zone = "Loch Modan" },
         [17] = { str = "Go to #COORD[38,61]# and do #DOID271# pt.1.", x = 38, y = 61, zone = "Loch Modan" },
         [18] = { str = "Run back to the house at #COORD[83,62]# turn in #INID385# and #INID271# pt.1#, accept #GETID531# pt.2, and turn it in.", x = 83, y = 62, zone = "Loch Modan" },
         [19] = { str = "Go to #COORD[63,47]# and turn in #INID2038#.", x = 63, y = 47, zone = "Loch Modan" },
         [20] = { str = "If you got #ZONEID1537# flightpath, fly there, if not, run down to #COORD[22,70]# and follow the path North into #ZONEID1#", x = 22, y = 70, zone = "Loch Modan" },
         [21] = { str = "Run along the road to #ZONEID1537# at #COORD[53,35]#.", x = 53, y = 35, zone = "Dun Morogh" },
         [22] = { str = "Get Ironforge weapon training at #COORD[61,89]#, and get flight path at #COORD[55,38]#. Turn in #INID301# at #COORD[74,12]#, SKIP #SKIPID302#.", x = 74, y = 12, zone = "Ironforge" },
         [23] = { str = "Get on the tram to #ZONEID1519# at #COORD[76,51]#.", x = 76, y = 51, zone = "Ironforge" },
         [24] = { str = "Turn in #INID1338# at #COORD[58,16]# in Stormwind.", x = 58, y = 16, zone = "Stormwind City" },
         [25] = { str = "Get Stormwind weapon training at #COORD[57,57]#, and flightpath at #COORD[66,62]#.", x = 66, y = 62, zone = "Stormwind City" },
         [26] = { str = "Leave #ZONEID1519#, then run towards #COORD[91,73]# in #ZONEID12#, and enter #ZONEID44#", x = 91, y = 73, zone = "Elwynn Forest" },
      }
   },
   [1820] = {
      title = "18-20 Redridge Mountains",
      --L- Playtested and corrected
      items = {
         [1] = { str = "18-20 #ZONEID44#" },
         [2] = { str = "Accept #GETID244# from #NPCID464# at #COORD[15,71]#.", x = 15, y = 71, zone = "Redridge Mountains" },
         [3] = { str = "Turn in #INID244# at #COORD[30,60]#, accept #GETID246#. Get the flightpath.", x = 30, y = 60, zone = "Redridge Mountains" },
         [4] = { str = "Cross the bridge, accept #GETID20#, #GETID125# and #GETID89#. SKIP #SKIPID118#" },
         [5] = { str = "Accept #GETID3741# on the dock, accept #GETID127# near the shed outside the Inn. Go inside the Inn and accept #GETID129#, SKIP #SKIPID116#." },
         [6] = { str = "Go west of #ZONEID69# and accept #GETID92# inside the house at #COORD[23,44]#.", x = 23, y = 44, zone = "Redridge Mountains" },
         [7] = { str = "Get 5 #ITEMID2296# for #DOID92# just west of the houses. Beware #NPCID345#. Loot #ITEMID10958# from the #OBJECTID154357# underwater at #COORD[19,52]#.", x = 19, y = 52, zone = "Redridge Mountains" },
         [8] = { str = "Head towards #COORD[42,55]# for #DOID125# and #DOID127#. Save at least 8 #ITEMID1468# for a later quest.", x = 42, y = 55, zone = "Redridge Mountains" },
         [9] = { str = "Turn in #INID125# by the bridge, #INID3741# on the dock, and #INID127# by the shed. You should be half way to level 20 at this point." },
         [10] = { str = "Turn in #INID129# at #COORD[15,71]#, accept #GETID130#.", x = 15, y = 71, zone = "Redridge Mountains" },
         [11] = { str = "Kill #NPCID442# for #DOID92# between #COORD[15,71]# and #COORD[33,76]#.", x = 33, y = 76, zone = "Redridge Mountains" },
         [12] = { str = "Do #DOID246# at #COORD[31,84]# and #COORD[43,72]#.", x = 43, y = 72, zone = "Redridge Mountains" },
         [13] = { str = "Kill #NPCID428# for #DOID92# around #COORD[57,76]#", x = 57, y = 73, zone = "Redridge Mountains" },
         [14] = { str = "Run back to #ZONEID69#, turn in #INID246# near the flightpath. Go to the two houses West of #ZONEID69#, at #COORD[23,46]# and turn in #INID92# and #INID130#, accept #GETID131#", x = 23, y = 46, zone = "Redridge Mountains" },
         [15] = { str = "Go in the Inn and turn in #INID131#. You should now be level 20, accept #GETID150# in front of the shed, if you still have the #ITEMID1468# in your bag, turn it in." },
         [16] = { str = "Kill #NPCID426# North of #ZONEID69# for #DOID89#, then turn it in." },
         [17] = { str = "Hearth back to #ZONEID442#. You should definitely be level 20 by this point and at least half way to level 21." },
      }
   },
}
