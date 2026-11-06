--[[--------------------------------------------------
   003_Horde_30to40.lua
   Authors: mrmr, lanjelin
   Version: 1.04.3
   ------------------------------------------------------
   Description: Guide Serie - 003 From Lvl 30 to Lvl 40
   1.04.1
   -- First Release
   Horde's Guide
   from level 30 to lever 40
   1.04.2
   -- no changes in here for this revision
   1.04.3
   -- Cleanup in text, changed formatting of coords
   ------------------------------------------------------
   Connection:
--]]--------------------------------------------------
Table_003_Horde_30to40 = {
   [3029] = {
      title = "30-30 Alterac Mountains",
      --L- Needs playtest
      items = {
         [1] = { str = "30-30 #ZONEID36#" },
         [2] = { str = "Do #DOID501#, killing the level 32-34 #NPCID2406# on the plateaus." },
         [3] = { str = "Charge the third flame #ITEMFlame of Uzel#, for the quest #DOID552# " },
         [4] = { str = "Kill #NPCID4504# (level 37 mob), it's a tough battle so prepare yourself! A group may be needed." },
         [5] = { str = "Run down to Southshore, to drive the rod into #ITEMID3708#, completing #INID552# " },
         [6] = { str = "Run back to #ZONEID272#" },
         [7] = { str = "Turn in #INID501# " },
         [8] = { str = "Accept #GETID676#" },
         [9] = { str = "Run into Arathi Highlands." },
      }
   },
   [3030] = {
      title = "30-30 Arathi Highlands",
      --L- Needs playtest
      items = {
         [1] = { str = "30-30 #ZONEID45#" },              
         [2] = { str = "Do #DOID676# at #COORD[34,45]#", x = 34, y = 45, zone = "Arathi Highlands" },
         [3] = { str = "Then run to #ZONEID321# at #COORD[73,36]#", x = 73, y = 36, zone = "Arathi Highlands" },
         [4] = { str = "Accept #GETID655#." },
         [5] = { str = "Turn in #INID655#, accept #GETID672# " },
         [6] = { str = "Turn in #INID676# " },
         [7] = { str = "Get the flightpath there." },
         [8] = { str = "Then do #DOID672#, just to the left of #ZONEID321# all around #COORD[64,37]#.  Turn it in and accept #GETID672# pt.2", x = 64, y = 37, zone = "Arathi Highlands" },
         [9] = { str = "Turn in #INID672# pt.2, accept #GETID672# pt.3" },
         [10] = { str = "Turn in #INID672# pt.3, skip #SKIPID701# for now" },
         [11] = { str = "Hearth to Orgrimmar. Put #ITEMID5811# into the bank to save bagspace. It will not be turned in until level 43." },
         [12] = { str = "Fly to Crossroads." },
         [13] = { str = "Run west in the Crossroads, accept #GETID1145# " },
         [14] = { str = "Then run west from the Crossroads to the guy in the hut, accept #GETID1362# " },
         [15] = { str = "Run back to Crossroads and make it your home." },
         [16] = { str = "Fly to Ratchet and get on the boat to Booty Bay." },
      }
   },
   [3031] = {
      title = "30-31 Stranglethorn Vale",
      --L- Needs playtest
      items = {
         [1] = { str = "30-31 #ZONEID33#" },
         [2] = { str = "Get the flightpath in Booty Bay, and run up to Grom'Gol, getting the flightpath there too." },
         [3] = { str = "Go up north #COORD[35,10]# and start doing the Stranglethorn hunting quests", x = 35, y = 10, zone = "Stranglethorn Vale" },
         [4] = { str = "#DOID583#, accept and turn it in." },
         [5] = { str = "#DOID185#, #NPCID681# at #COORD[33,10]#", x = 33, y = 10, zone = "Stranglethorn Vale" },
         [6] = { str = "#DOID190#, #NPCID683# at #COORD[41,09]#", x = 41, y = 9, zone = "Stranglethorn Vale" },
         [7] = { str = "#DOID191#, #NPCID736# at #COORD[30,11]#", x = 30, y = 11, zone = "Stranglethorn Vale" },
         [8] = { str = "#DOID186#, #NPCID682# at #COORD[30,10]#", x = 30, y = 11, zone = "Stranglethorn Vale" },
         [9] = { str = "#DOID194#, #NPCID685# at #COORD[25,15]#", x = 25, y = 15, zone = "Stranglethorn Vale" },
         [10] = { str = "Accept #GETID187#, #NPCID1085#, but don't do it now." },
         [11] = { str = "Accept #GETID195#, #NPCID686#, but don't do it now." },
         [12] = { str = "Skip the rest for now." },
         [13] = { str = "You should be level 31 for sure, if not grind to it" },
         [14] = { str = "Hearth to Crossroads." },
         [15] = { str = "Fly to Thousand Needles." },
         [16] = { str = "Go east into Shimmering Flats at #COORD[77,77]#.", x = 77, y = 77, zone = "Thousand Needles" },
      }
   },
   [3132] = {
      title = "31-32 TN (Shimmering Flats)",
      --L- Needs playtest
      items = {
         [1] = { str = "31-32 #ZONEID439#" },
         [2] = { str = "Accept #GETID5762# and #GETID1111#." },
         [3] = { str = "Accept and do the following together: #DOID1175#, #DOID1105#, #DOID1176#, #DOID1110#, #DOID1104#." },
         [4] = { str = "Turn them all in. Accept #GETID1178# and #GETID1106#, SKIP #SKIPID1107# (Elite)." },
         [5] = { str = "Go south into Tanaris to get flightpath in Gadgetzan at #COORD[51,25]#", x = 51, y = 25, zone = "Tanaris" },
         [6] = { str = "Hearth to Crossroads, then fly to Orgrimmar." },
         [7] = { str = "Turn in #INID1145# at #COORD[75,34]#, accept #GETID1145# pt.2.", x = 75, y = 34, zone = "Orgrimma" },
         [8] = { str = "Accept #GETID1431# from #NPCID5639# in the Cleft of Shadow, #COORD[47,50]#", x = 47, y = 50, zone = "Orgrimmar" },
         [9] = { str = "Then go to #NPCID5640# in Orgrimmar #COORD[23,53]# to accept #GETID1431# pt.2.", x = 23, y = 53, zone = "Orgrimmar" },
         [10] = { str = "Fly to #ZONEID406#, and run in to #ZONEID405#." },
      }
   },
   [3234] = {
      title = "32-34 Desolace",
      --L- Needs playtest
      items = {
         [1] = { str = "32-34 #ZONEID405#" },
         [2] = { str = "First thing to do here is start killing mobs at the #ZONEID599# #COORD[55,24]# until #ITEMID20310# dropps, which starts #GETID1480#.", x = 55, y = 24, zone = "Desolace" },
         [3] = { str = "After you got it, go do #DOID5561#, it starts at #COORD[60,61]#.", x = 60, y = 61, zone = "Desolace" },
         [4] = { str = "Then go to #ZONEID597# #COORD[56,59]#", x = 56, y = 59, zone = "Desolace" },
         [5] = { str = "Turn in #INID1362#, accept #GETID1365#." },
         [6] = { str = "Accept #GETID1368#, skip #SKIPID1367#." },
         [7] = { str = " Accept #GETID5386#. Turn in #INID1431#, accept #GETID1431# pt.2 and #GETID1434# " },
         [8] = { str = "Turn in #INID1480#, accept #GETID1480# pt.2." },
         [9] = { str = "Turn in #INID1431# pt.2, accept #GETID1435#." },
         [10] = { str = "Go do #DOID1434# and #DOID1480# pt.2 at #COORD[75,22]#.", x = 75, y = 22, zone = "Desolace" },
         [11] = { str = "Do #DOID1365#, at #COORD[73,48]#", x = 73, y = 48, zone = "Desolace" },
         [12] = { str = "Do #DOID1368#, at #COORD[68,71]#", x = 68, y = 71, zone = "Desolace" },
         [13] = { str = "Go back to #ZONEID597# #COORD[56,59]#, and turn in #INID1365#, accept #GETID1366#. Turn in #INID1434# and #INID1480# pt.2, accept #GETID1480# pt.3.", x = 56, y = 59, zone = "Desolace" },
         [14] = { str = "Then run to #ZONEID2408#, stopping along the way to turn in #INID1368# at #COORD[36,79]#, accept #GETID1370# ", x = 36, y = 79, zone = "Desolace" },
         [15] = { str = "Accept all quests at #ZONEID2408# at #COORD[24,71]#; #GETID5763#, #GETID5381#, #GETID6142# and #GETID6143# ", x = 24, y = 71, zone = "Desolace" },
         [16] = { str = "Make #ZONEID2408# your home." },
         [17] = { str = "Go in the water and collect 10 #ITEMID13545#, from the #OBJECTID176582#." },
         [18] = { str = "Turn those in at #NPCID11317# for 2 #ITEMID13546#." },
         [19] = { str = "Travel up the water, collecting #ITEMID15924# for the quest #DOID6142# along the way" },
         [20] = { str = "Accept #GETID6161# at the chest/wrecked boat along the shore, #COORD[36,30]#. The #ITEMID15878# is dropped by a #NPCID11562#, #NPCID11563#, and the #ITEMID15881# is dropped by a #NPCID4711#.", x = 36, y = 30, zone = "Desolace" },
         [21] = { str = "Go accept #GETID5741# from #NPCID11863# at #COORD[38,27]#", x = 38, y = 27, zone = "Desolace" },
         [22] = { str = "Then go to #ZONEID599# #COORD[54,29]# and do #DOID1435#, #DOID5741# and #DOID5381#.", x = 54, y = 29, zone = "Desolace" },
         [23] = { str = "Grind your way back to #NPCID11863# #COORD[38,27]#, turn in #INID5741# in and get #GETID6027#.", x = 38, y = 27, zone = "Desolace" },
         [24] = { str = "Then head off to do #DOID6143#, #DOID6142#, #DOID1480# pt.3, #DOID6161# and #DOID6027# from the shore and out to #COORD[27,06]#", x = 27, y = 6, zone = "Desolace" },
         [25] = { str = "Turn in #INID6161# at the little chest at #COORD[29,08]#.", x = 29, y = 8, zone = "Desolace" },
         [26] = { str = "Turn in #INID6027# at #COORD[38,27]#", x = 38, y = 27, zone = "Desolace" },
         [27] = { str = "Then go accept #GETID5501# at #COORD[62,38]#, grinding mobs along the way.", x = 62, y = 38, zone = "Desolace" },
         [28] = { str = "Go to Ghost Walker Post #COORD[56,59]#, turn in #INID5386# accept and turn in #INID1435#, turn in #INID1480# pt.3, accept and turn in #INID1480# pt.4. Accept #GETID1431# Skip #SKIPID1480# pt.5.", x = 56, y = 59, zone = "Desolace" },
         [29] = { str = "Then do #DOID5501# at the kodo graveyard #COORD[51,58]#", x = 51, y = 58, zone = "Desolace" },
         [30] = { str = "Then #DOID1366# and #DOID1370# #COORD[70,74]#", x = 70, y = 74, zone = "Desolace" },
         [31] = { str = "Then go turn in #INID1366# at #COORD[56,59]#", x = 56, y = 59, zone = "Desolace" },
         [32] = { str = "Turn in #INID5501# at #COORD[62,38]#", x = 62, y = 38, zone = "Desolace" },
         [33] = { str = "Hearth to #ZONEID2408#." },
         [34] = { str = "Turn in all quests, #INID5381#, #INID6143# and #INID6142#. You should be level 34 by now." },
         [35] = { str = "Turn in #INID1370# at #COORD[36,79]# and accept #GETID1373#.", x = 36, y = 79, zone = "Desolace" },
         [36] = { str = "Fly to #ZONEID378# (#ZONEID17#), then run south-east into #ZONEID15# #COORD[51,79]#.", x = 51, y = 79, zone = "The Barrens" },
         [37] = { str = "Collect the 3 quest-objects at the #ZONEID403#" },
         [38] = { str = "#GETID1268#, just right outside in front of the inn." },
         [39] = { str = "#GETID1252#, laying on one of the planks on the ground." },
         [40] = { str = "#GETID1251#, on top of the fireplace." },
         [41] = { str = "Now run to #ZONEID496# #COORD[35,29]#", x = 35, y = 29, zone = "Dustwallow Marsh" },
         [42] = { str = "Turn in those 3 quests, #INID1268# #INID1252# and #INID1251#, accept and then turn in #INID1251# pt.2 Skip #SKIPID1251# pt.3." },
         --L- Need to check Black Shield quests
         [43] = { str = "Stop at the troll vendor, buy the 3 first aid books." },
         [44] = { str = "Fly to Ratchet to turn in #INID1178# and #INID1111#, accept #GETID1178# pt.2 and #GETID1112#." },
         [45] = { str = "Get on the boat to Booty Bay." },
      }
   },
   [3435] = {
      title = "34-35 Stranglethorn Vale",
      --L- Needs playtest
      items = {
         [1] = { str = "34-35 #ZONEID33#" },
         [2] = { str = "Turn in #INID1178# pt.2, accept #GETID1178# pt.3 Make Booty Bay your home! Accept #GETID605#, #GETID189#, #GETID213# and #GETID201#. Turn in #INID1178# pt.3 at #NPCID2496#, accept #GETID1178# pt.4." },
         [3] = { str = "Fly to Grom'gol, and grab all the quests there; #GETID568#, #GETID570#, #GETBloodscalp Insight#, #GETID581#, #GETID638#, #GETID596#, #GETID629#." },
         [4] = { str = "Make sure you save any #ITEMID2725# pages you find and mail them to your alt for storage, you will need them for a later quest." },
         [5] = { str = "You will need following: Chapter 1: 1, 4, 6 and 8. Chapter 2: 10, 11, 14 and 16. Chapter 3: 18, 20, 21 and 24. Chapter 4: 25, 26, and 27." },
         [6] = { str = "Do #DOID605# at #COORD[25,19]#", x = 25, y = 19, zone = "Stranglethorn Vale" },
         [7] = { str = "Do #DOID185#, killing #NPCID1085# at #COORD[31,19]#", x = 31, y = 19, zone = "Stranglethorn Vale" },
         [8] = { str = "Do #DOID189#, #DOID581# and #DOID596# (no need to complete latter at this time)." },
         [9] = { str = "Do #DOID194# and #DOID568# killing #NPCID686# just outside Grom'gol." },
         [10] = { str = "Go to Grom'gol and turn in #INID581#, accept #GETID582#, turn in #INID568#, accept #GETID568# pt.2" },
         [11] = { str = "Do #DOID582# while finishing up #DOID596# at #COORD[21,14]#", x = 21, y = 14, zone = "Stranglethorn Vale" },
         [12] = { str = "Do #DOID629# along with #DOID1107# at #COORD[24,24]#. Be careful not to drown.", x = 24, y = 24, zone = "Stranglethorn Vale" },
         [13] = { str = "Then go to Nesingwary's Expedition #COORD[35,10]#, turn in ALL quests and accept all new ones, except #SKIPID338#.", x = 35, y = 10, zone = "Stranglethorn Vale" },
         [14] = { str = "Do #DOID185# killing #NPCID729#, he is usually on top of the hill at #COORD[31,17]#. Go turn it in when done.", x = 31, y = 17, zone = "Stranglethorn Vale" },
         [15] = { str = "Do #DOID213# along with #DOID1178# at #COORD[44,19]#", x = 44, y = 19, zone = "Stranglethorn Vale" },
         [16] = { str = "Do #DOID190# along with #DOID570#, kill #NPCID684# at #COORD[48,21]#", x = 48, y = 21, zone = "Stranglethorn Vale" },
         [17] = { str = "Do #DOID568# pt.2 at #COORD[36,30]#", x = 36, y = 30, zone = "Stranglethorn Vale" },
         [18] = { str = "Head up north and turn in #INID190#,accept #GETID190#, #NPCID728#, but don't do it now." },
         [19] = { str = "Hearth to Booty Bay, turn in #INID605#, #INID213#, #INID189# and #INID201#." },
         [20] = { str = "Turn in #INID1178# pt.4, accept #GETID1178# pt.5." },
         [21] = { str = "Fly to Grom'gol and turn in all quests, #INID568#, #INID570#, #INID582#, #INID596# and #INID629#." },
         [22] = { str = "You should be level 36 now, if not, grind to it. Accept #GETID638#." },
         [23] = { str = "Get on the zeppelin to the Undercity." },
         [24] = { str = "Accept #GETID1164# #COORD[63,49]#", x = 63, y = 49, zone = "Undercity" },
         [25] = { str = "Then fly to #ZONEID321#." },
      }
   },
   [3537] = {
      title = "35-37 Arathi Highlands",
      --L- Needs playtest
      items = {
         [1] = { str = "35-37 #ZONEID45#" },
         [2] = { str = "Make #ZONEID321# your home." },
         [3] = { str = "Turn in #INID638#, SKIP #SKIPID639#." },
         [4] = { str = "Accept #GETID677#, #GETID671# and #GETID701# " },
         [5] = { str = "Grind your way down south and do #DOID677#." },
         [6] = { str = "Then go west of #ZONEID321# and accept #GETID642# #COORD[62,33]#", x = 62, y = 33, zone = "Arathi Highlands" },
         [7] = { str = "Then go do #DOID642# while grinding your way inside the cave." },
         [8] = { str = "Turn in #INID642# in the cave, and accept #GETID651#." },
         [9] = { str = "Turn in #INID677#, accept #GETID677# pt.2 " },
         [10] = { str = "Do #DOID651# First key, just west of #ZONEID321# at #COORD[66,29]#", x = 66, y = 29, zone = "Arathi Highlands" },
         [11] = { str = "Do #DOID1164# at #COORD[54,40]#", x = 54, y = 40, zone = "Arathi Highlands" },
         [12] = { str = "Go down south a little and get the next key for #DOID651#, at #COORD[52,50]#", x = 52, y = 50, zone = "Arathi Highlands" },
         [13] = { str = "Do #DOID677# pt.2 killing #NPCOgre#, and #DOID701# killing #NPCID2561# around #COORD[50,75]#", x = 50, y = 75, zone = "Arathi Highlands" },
         [14] = { str = "Do #DOID671# at #COORD[31,28]#", x = 31, y = 28, zone = "Arathi Highlands" },
         [15] = { str = "Then go west and get the last key for #DOID651# at #COORD[25,31]#", x = 25, y = 31, zone = "Arathi Highlands" },
         [16] = { str = "Go discover Stromguard, and turn in #INID651#, at the Circle of Inner Binding #COORD[36,57]#. SKIP #SKIPID652# (Elite), unless you get a group for it.", x = 36, y = 57, zone = "Arathi Highlands" },
         [17] = { str = "Hearth to #ZONEID321#." },
         [18] = { str = "Turn in #INID671#, #INID701# and #INID677# pt.2 " },
         [19] = { str = "Complete the #DOID701# quest chain by running back and forth." },
         [20] = { str = "Fly to #ZONEID272#." },
      }
   },
   [3736] = {
      title = "37-37 Alterac Mountains",
      --L- Needs playtest
      items = {
         [1] = { str = "37-37 #ZONEID36#" },
         [2] = { str = "Once at #ZONEID272#, accept #GETID556# and #GETID544#, then go do them in Alterac Mountains at Dalaran." },
         [3] = { str = "Then turn them in and accept #GETID545# and #GETID557#, doing them a bit further north then the last two." },
         [4] = { str = "Once they are both completed, die on purpose, so you end up at #ZONEID272#." },
         [5] = { str = "Turn them in, then fly to Undercity." },
         [6] = { str = "Once in Undercity, turn in #INID1164# and buy 3x#ITEMID3713#" },
         [7] = { str = "Get on zeppelin to Orgrimmar." },
         [8] = { str = "Once in Orgrimmar, turn in #INID1431# at #NPCID5640# at #COORD[21,53]#", x = 21, y = 53, zone = "Orgrimmar" },
         [9] = { str = "Fly to #ZONEID380#, making it your home." },
         [10] = { str = "Fly to #ZONEID484# (#ZONEID400#)." },
      }
   },
   [3737] = {
      title = "37-37 Thousand Needles",
      --L- Needs playtest
      items = {
         [1] = { str = "37-37 #ZONEID400#" },
         [2] = { str = "Run towards the Shimmering Flats.." },
         [3] = { str = "Turn in #INID1145#, accept #GETID1145# pt.2 at #COORD[67,63]#", x = 67, y = 63, zone = "Thousand Needles" },
         [4] = { str = "Stop at the goblins and turn in #INID1112#, accept #GETID1114#, turn in #INID1114#, turn in #INID1178# pt.3, accept #GETID1186#, turn in #INID1186#, accept #GETID1187#, turn in #INID1107#, lastly accept #GETID1115#." },
         [5] = { str = "Do #DOID1145# and #DOID1148# (quest starts from an item drop) at #COORD[71,85]#", x = 71, y = 85, zone = "Thousand Needles" },
         [6] = { str = "Then go turn in #INID1145# at #COORD[67,63]#", x = 67, y = 63, zone = "Thousand Needles" },
         [7] = { str = "Hearth to Crossroads" },
         [8] = { str = "Turn in #INID1148#, accept #GETID1148# pt.2" },
         [9] = { str = "Fly to Dustwallow Marsh." },
      }
   },
   [3738] = {
      title = "37-38 Dustwallow Marsh",
      --L- Needs playtest
      items = {
         [1] = { str = "37-38 #ZONEID15#" },
         [2] = { str = "Accept #GETID1201# and #GETID1251# pt.3 " },
         [3] = { str = "Go slightly south of Brackenwall Village and accept #GETID1177# from the ogre at #COORD[35,37]#", x = 35, y = 37, zone = "Dustwallow Marsh" },
         [4] = { str = "Do #DOID1201# and #DOID1251# pt.3. Do #DOID1177# at #COORD[58,23]#", x = 58, y = 23, zone = "Dustwallow Marsh" },
         --L- Is Hungry available elysium?
         [5] = { str = "Stop at Jarl's cabin #COORD[55,25]#, get #GETID1238# by clicking the dirt mound next to his cabin, turn in #INID1218# and accept #GETID1206#.", x = 55, y = 25, zone = "Dustwallow Marsh" },
         [6] = { str = "Go south at #COORD[54,56]# to retrive the #ITEMID5862# for Razzeric.", x = 54, y = 56, zone = "Dustwallow Marsh" },
         [7] = { str = "Do #DOID1206#." },
         [8] = { str = "Do the escort quest #DOID1222# that starts at #COORD[47,18]#.", x = 47, y = 18, zone = "Dustwallow Marsh" },
         [9] = { str = "Stop at Brackenwall Village and turn in all quests, accept new ones. Turn in #INID1177#" },
         [10] = { str = "Go to Jarl's cabin at #COORD[55,25]#, go to the #ITEMDirt Mound# once again to get #GETID1239#, turn in #INID1206#, SKIP #SKIPID1203#", x = 55, y = 25, zone = "Dustwallow Marsh" },
         [11] = { str = "Grind some  at the raptors and such, at this point you should be a little over half way to 39." },
         [12] = { str = "Do #DOID1202#, the #ITEMID5881# are under the water at #COORD[71,51]#" , x = 71, y = 51, zone = "Dustwallow Marsh" },
         [13] = { str = "Then die on purpose, so you end up right at Brackenwall Village." },
         [14] = { str = "Turn in #INID1202# and #INID1239#, accept #GETID1240#" },
         [15] = { str = "Hearth to Crossroads, fly to Ratchet and turn in #INID1222#, then get on the boat to Booty Bay." },
      }
   },
   [3840] = {
      title = "38-40 Stranglethorn Vale",
      --L- Needs playtest
      items = {
         [1] = { str = "38-40 #ZONEID33#" },
         [2] = { str = "Accept #GETID595#, #GETID600# and #GETID606#." },
         [3] = { str = "Make Booty Bay your home, then go up the steps and turn in #INID1115#. Fly to Grom'gol." },
         [4] = { str = "Accept #GETID570#, turn in #INID1240#, then right click the cauldron and accept #GETID1261#." },
         --L- Is this available elysium?
         [5] = { str = "Do #DOID194# along with #DOID570# at #COORD[31,41]#, kill #NPCID687#.", x = 31, y = 41, zone = "Stranglethorn Vale" },
         [6] = { str = "Grind away at raptors/cold eye ballisks till level 39." },
         [7] = { str = "Do #DOID600# at #COORD[40,42]#", x = 40, y = 42, zone = "Stranglethorn Vale" },
         [8] = { str = "Once that is done, go back to Grom'Gol and turn in #INID570# pt.2, accept #GETID570# pt.3." },
         [9] = { str = "Do #DOID190#, kill #NPCID728# (he has 3 different spawn points, #COORD[48,20]#, #COORD[49,23]#, and #COORD[47,26]#)", x = 48, y = 20, zone = "Stranglethorn Vale" },
         [10] = { str = "Turn in #INID190# and #INID194# at Nesingwary's Expedition #COORD[35,10]#", x = 35, y = 10, zone = "Stranglethorn Vale" },
         [11] = { str = "Accept #GETID194# for #NPCID730#, but don't do it now." },
         [12] = { str = "Hearth to Booty Bay, turn in #INID600#." },
         [13] = { str = "Go do #DOID595# north-west of Booty Bay at #COORD[27,69]#, there's a little note on a barrel, click on it, accept new quest. ", x = 27, y = 69, zone = "Stranglethorn Vale" },
         [14] = { str = "Do #DOID606# along with #DOID570# pt.3 at #COORD[32,66]#.", x = 32, y = 66, zone = "Stranglethorn Vale" },
         [15] = { str = "Run back to Booty Bay, turn in #INID606#, accept #GETID607#, turn in #INID595#, accept #GETID595# pt.2, turn in #INID607#, then turn in #INID595# at #NPCID2487#." },
         [16] = { str = "Fly to Grom'gol, turn in #INID570# pt.3, accept #GETID570# pt.4" },
         [17] = { str = "You should be level 40 for sure now. If not, grind the rest of the way to 40 on Raptors/Cold Eye Basilisks." },
         [18] = { str = "Then get on the zeppelin to Undercity." },
         [19] = { str = "Check the Aution House for #ITEMID3829#, #ITEMID4389#, #ITEMID929#, #ITEMID3823# and #ITEMID2868# for some fast quests in Badlands." },
         [20] = { str = "Fly to #ZONEID321#, then run all the way to Badlands." },
      }
   },
}
