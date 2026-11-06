--[[--------------------------------------------------
   002_Durotar.lua
   Authors: mrmr, lanjelin
   Version: 1.04.3
   ------------------------------------------------------
   Description: Guide Serie - 001 Introduction
   1.04.1
   -- First Release
   Orcs&Trolls Durotar's Guide
   from level 1 to lever 12
   1.04.2
   -- no changes in here for this revision
   1.04.3
   -- Cleanup in text, changed formatting of coords
   ------------------------------------------------------
   Connection:
--]]--------------------------------------------------

Table_002_Durotar = {
   -----------1-6 Durotar
   --[11] = {
   [0106] = {
      title = "1-6 Durotar",
      --n = "1-6 Durotar",
      --pID = 1, nID = 12,
      --itemCount = 19,
      items = {
         [1] = { str = "1-6 #ZONEID14#" },
         [2] = { str = "I do every single quest in Durotar! Here's the fastest way to do em:" },
         [3] = { str = "Start off accepting #GETID4641# . (Right in front of you) " },
         [4] = { str = "Then turn it in at #COORD[42,68]# ... accept #GETID788# " },
         [5] = { str = "Go start doing: #DOID788# (keep step #5 in mind)" },
         [6] = { str = "Once you hit level 2, go accept #GETID790# at #COORD[40,62]#", x = 40, y = 62, zone = "Durotar" },
         [7] = { str = "Go do #DOID790# at #COORD[40,66]#.", x = 40, y = 66, zone = "Durotar" },
         [8] = { str = "Then turn #INID790# in at #COORD[40,62]# ... Accept #GETID804# pt.2", x = 40, y = 62, zone = "Durotar" },
         [9] = { str = "Make sure #DOID788# is complete." },
         [10] = { str = "Go turn in #INID790# pt.2 and #INID788# at #COORD[42,68]# ... Accept #GETID3082# and #GETID789# ", x = 42, y = 68, zone = "Durotar" },
         [11] = { str = "Turn in #GETID3082#, around #COORD[43,69]#, and get new spells/abilities for your class.", x = 43, y = 69, zone = "Durotar" },
         [12] = { str = "Then accept and do the following:  #DOID789#   #DOID792#   #DOID4402# and #DOID5441#   (all these are done north and north-east of Valley of Trials)" },
         [13] = { str = "Turn all those quests in, then accept #GETID794# and #GETID6394# " },
         [14] = { str = "Go do #DOID794# and #DOID6394#, these are done in the cave at #COORD[44,56]#", x = 44, y = 56, zone = "Durotar" },
         [15] = { str = "Once those two quests are done use your hearthstone." },
         [16] = { str = "Turn those 2 quests in and accept #GETID805# " },
         [17] = { str = "The starting area is now completed.  Leave starting noob zone (by heading east)." },
         --[18] = { str = "." },
         --[19] = { str = "." },
      }
   },

   -----------6-9 Durotar
   --[12] = {
   [0609] = {
      title = "6-9 Durotar",
      --n = "6-9 Durotar",
      --pID = 11, nID = 13, 
      --itemCount = 31,
      items = {
         [1] = { str = "6-9 #ZONEID14#" },
         [2] = { str = "Accept #GETID2161# at #COORD[52,68]#", x = 52, y = 68, zone = "Durotar" },
         [3] = { str = "Accept #GETID786# at #COORD[54,75]#", x = 54, y = 75, zone = "Durotar" },
         [4] = { str = "Go turn in #INID805# at Sen'jen Village, #COORD[55,74]#", x = 55, y = 74, zone = "Durotar" },
         [5] = { str = "Then collect all the quests in Sen'jin Village.  (which include:  #GETID818# #GETID817# #GETID808# #GETID823# and #GETID826# )" },
         [6] = { str = "Do NOT do #DOID818# at the water around Sen'jin Village.  Make sure the quest is accepted though." },
         [7] = { str = "Then run up to Razor Hill #COORD[52,44]#, grinding mobs along the way, and make sure you get to level 6 before you get up there for new spells.", x = 52, y = 44, zone = "Durotar" },
         [8] = { str = "Turn in #INID823# and collect all the quests at Razor Hill (#GETID806# #GETID784# , #GETID837# #GETID815# " },
         [9] = { str = "Go up to the watch tower north-west of Razor Hill, at #COORD[49,40]# and accept #GETID791# ", x = 49, y = 40, zone = "Durotar" },
         [10] = { str = "Go in the Inn #COORD[51,41]# and turn in #INID2161# .  And also make Razor Hill your home.", x = 51, y = 41, zone = "Durotar" },
         [11] = { str = "Get first aid. at #COORD[54,41]#", x = 51, y = 41, zone = "Durotar" },
         [12] = { str = "Then go do this: #DOID784# along with #DOID791#. These are done at Tiragarde Keep, #COORD[57,55]#", x = 57, y = 55, zone = "Durotar" },
         [13] = { str = "After killing Benedict (he is up in the building at #COORD[59,58]#), get his key, go up the steps, open the chest and grab the note that starts:  #GETID830# accept the quest.", x = 59, y = 58, zone = "Durotar" },
         [14] = { str = "Go turn in #INID784# #INID830# and #INID791# at Razor Hill #COORD[52,44]#, and accept #GETID825# #GET831# (part2).", x = 52, y = 44, zone = "Durotar" },
         [15] = { str = "Go do #DOID818# and #DOID825# Do these two quests at the water east of Tiragarde Keep, around #COORD[62,50]#.", x = 62, y = 50, zone = "Durotar" },
         [16] = { str = "Then do the first half of #DOID837# at #COORD[49,49]#.", x = 49, y = 49, zone = "Durotar" },
         [17] = { str = "Then if you're not at least 3 bars away from lvl 8, grind till you are, go turn in #INID825# at Razor Hill #COORD[52,44]# and get new spells/abilities.", x = 52, y = 44, zone = "Durotar" },
         [18] = { str = "Run way down south and do #DOID786# at #COORD[48,79]# ", x = 48, y = 79, zone = "Durotar" },
         [19] = { str = "Once that is done turn it in at #COORD[54,75]#.", x = 54, y = 75, zone = "Durotar" },
         [20] = { str = "Turn in #INID818# at Sen'jin #COORD[55,74]#", x = 55, y = 74, zone = "Durotar" },
         [21] = { str = "Then go to Echo Isles (the islands south-east of Durotar) and do the following 4 quests together:" },
         [22] = { str = "#DOID815# " },
         [23] = { str = "#DOID817# " },
         [24] = { str = "#DOID808#  at #COORD[67,87]#", x = 67, y = 87, zone = "Durotar" },
         [25] = { str = "#DOID826# at #COORD[67,86]#." },
         [26] = { str = "After completing all these quests, die on purpose, so you end up right at Sen'jin Village #COORD[55,74]#...", x = 55, y = 74, zone = "Durotar" },
         [27] = { str = "Turn in #INID817# #INID808# and #INID826# .  Save the quest reward item #ITEMID4945# for a later quest called #DOID832# " },
         [28] = { str = "Hearth to Razor Hill.  Turn in #INID815# " },
         [29] = { str = "Then do the second half of #DOID837# (west of Razor Hill, at #COORD[42,38]#)", x = 42, y = 38, zone = "Durotar" },
         --[30] = { str = "." },
         --[31] = { str = "." },
      }
   },

   -----------9-12 Durotar
   --[13] = {
   [0912] = {
      title = "9-12 Durotar",
      --n = "9-12 Durotar",
      --pID = 12, nID = 101, 
      --itemCount = 45,
      items = {
         [1] = { str = "9-12 #ZONEID14#" },
         [2] = { str = "Then go up and accept #GETID816# at the little hut at #COORD[43,30]#", x = 43, y = 30, zone = "Durotar" },
         [3] = { str = "Then go up (grind mobs along the way) and accept  #GETID834# at the goblin, #COORD[46,22]#.", x = 46, y = 22, zone = "Durotar" },
         [4] = { str = "Then do #DOID834# " },
         [5] = { str = "Then turn it in, accept  #GETID835# at #COORD[46,22]#", x = 46, y = 22, zone = "Durotar" },
         [6] = { str = "Grind mobs to lvl 10." },
         [7] = { str = "Go down to razor hill #COORD[52,44]#, turn in #INID837# ", x = 52, y = 44, zone = "Durotar" },
         [8] = { str = "Get new spells/abilities." },
         [9] = { str = "Do your level 10 class quests." },
         [10] = { str = "Then go way west (grinding mobs along the way) and accept #GETID812# at #COORD[41,18]#", x = 41, y = 18, zone = "Durotar" },
         [11] = { str = "Go to Orgrimmar at #COORD[45,11]#", x = 45, y = 11, zone = "Durotar" },
         [12] = { str = "Then turn in #INID830# in thrall's chamber #COORD[34,36]#", x = 34, y = 36, zone = "Orgrimmar" },
         [13] = { str = "Accept #GETID5726# (Thrall gives it)" },
         [14] = { str = "Go into Cleft of Shadow, accept #GETID813# #COORD[46,53]#", x = 46, y = 53, zone = "Orgrimmar" },
         [15] = { str = "Then go do #DOID835# at #COORD[53,23]# in Durotar", x = 53, y = 23, zone = "Durotar" },
         [16] = { str = "Turn in #INID835# at #COORD[46,22]#", x = 46, y = 22, zone = "Durotar" },
         [17] = { str = "Then go do #DOID813# (the scorpids are all over the place) and #DOID816# (all along the river west of Durotar)" },
         [18] = { str = "Then go do #DOID806# at #COORD[41,26]#", x = 41, y = 26, zone = "Durotar" },
         [19] = { str = "Turn in #INID816# #COORD[43,30]#", x = 43, y = 30, zone = "Durotar" },
         [20] = { str = "Turn in #INID806# at Razor Hill, #COORD[52,44]#", x = 52, y = 44, zone = "Durotar" },
         [21] = { str = "Accept #GETID828# " },
         [22] = { str = "Turn in #INID828# at #COORD[56,20]# accept #GETID827# ", x = 56, y = 20, zone = "Durotar" },
         [23] = { str = "Go do #DOID827# along with #DOID5726# in the cave at #COORD[54,11]#", x = 54, y = 11, zone = "Durotar" },
         [24] = { str = "If you can, try to kill Gazz'uz, he drops 'Eye of Burning Shadow' item which starts #GETID832# quest.  HINT: use the quest reward item #ITEMID4945# to help you kill him, he's tough without it, also try to party up with somebody if you can." },
         [25] = { str = "Turn in #INID827# #COORD[56,20]# accept #GETID829# ", x = 56, y = 20, zone = "Durotar" },
         [26] = { str = "Go to into Orgrimmar." },
         [27] = { str = "Turn in #INID5726# at #COORD[33,37]# in Orgrimmar accept the next part to #GETID5726# ", x = 33, y = 37, zone = "Orgrimmar" },
         [28] = { str = "Go to Cleft of Shadows #COORD[47,53]# and turn in #INID813# ", x = 47, y = 53, zone = "Orgrimmar" },
         [29] = { str = "Turn in #INID829# and #INID832# at Neeru Fireblade #COORD[49,50]# accept #GETID809# ", x = 49, y = 50, zone = "Orgrimmar" },
         [30] = { str = "Also keep talking to him to complete #DOID5726# " },
         [31] = { str = "Then go back to Thrall and turn in #INID5726# again. The 3rd part refers to RFC instance, which I skip." },
         [32] = { str = "Leave Orgrimmar, and turn in #INID812# at #COORD[41,18]# (you will most likely have to accept it again to turn it in)", x = 40, y = 62, zone = "Durotar" },
         [33] = { str = "Hearth to Razor Hill." },
         [34] = { str = "Build up first aid." },
         [35] = { str = "Get new spells/abilities." },
         [36] = { str = "Accept #GETID840# at #COORD[50,43]# in Razor Hill", x = 51, y = 44, zone = "Durotar" },
         [37] = { str = "Run west into the Barrens...at #COORD[35,42]#", x = 35, y = 42, zone = "Durotar" },
         --[44] = { str = "." },
         --[45] = { str = "." },
      }
   },

}
