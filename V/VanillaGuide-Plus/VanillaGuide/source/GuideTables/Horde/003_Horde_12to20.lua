--[[--------------------------------------------------
   003_Horde_12to20.lua
   Authors: mrmr, lanjelin
   Version: 1.04.3
   ------------------------------------------------------
   Description: Guide Serie - 003 From Lvl 12 to Lvl 20
   1.04.1
   -- First Release
   Horde's Guide
   from level 12 to lever 20
   1.04.2
   -- no changes in here for this revision
   1.04.3
   -- Cleanup in text, changed formatting of coords
   ------------------------------------------------------
   Connection:
--]]--------------------------------------------------

Table_003_Horde_12to20 = {
   -----------12-15 Barrens
   --[101] = {
   [1215] = {
      title = "12-15 Barrens",
      --n = "12-15 Barrens",
      --pID = 13, nID = 102, 
      --itemCount = 34,
      items = {
         [1] = { str = "12-15 #ZONEID17#" },
         [2] = { str = "Turn in #INID840# at #COORD[62,19]# in the Barrens, accept #GETID842# ", x = 62, y = 19, zone = "The Barrens" },
         [3] = { str = "Then turn in #INID809# #COORD[62,20]# I SKIP #SKIPID924# ", x = 62, y = 20, zone = "The Barrens" },
         [4] = { str = "Run to XRs (Crossroads) at #COORD[52,30]#.", x = 52, y = 30, zone = "The Barrens" },
         [5] = { str = "(HUNTER) While on my way to XRs, I  abandon my crab and tame a Savannah Huntress cat, for my new pet." },
         [6] = { str = "Once at XRs at #COORD[52,30]# turn in #INID842# Then accept all quests in XRs (which includes: #GETID6365# #GETID844#   #GETID870# #GETID869# #GETID1111# #GETID848# #GETID871# #GETID5041# and #GETID867# on top of the watch tower).  Turn in #INID6365# i SKIP #SKIPID6384# ", x = 52, y = 30, zone = "The Barrens" },
         [7] = { str = "Make XRs your home." },
         [8] = { str = "Get FP (Flight Path)" },
         [9] = { str = "Then go do:  #DOID871# along with #DOID844# and #DOID869# around #COORD[54,26]#.  NOTE: If you find #GETID819# accept it.", x = 54, y = 26, zone = "The Barrens" },
         [10] = { str = "Once #DOID871# is completed go turn it in at #COORD[52,30]# and accept #GETID5041#", x = 52, y = 30, zone = "The Barrens" },
         [11] = { str = "Go do #DOID5041# at #COORD[56,26]#, then run back to Thork and #GETID872#, you'll be going back up to the razormanes one more time.", x = 56, y = 26, zone = "The Barrens" },
         [12] = { str = "If you find #GETID819# accept it." },
         [13] = { str = "Once #DOID844# & #DOID872# and are complete..." },    
         [14] = { str = "Go to Ratchet, get the Flight Path there #COORD[63,37]# and accept #GETID865# #GETID894# #GETID887#  #GETID891# .  Turn in #INID819# if you have it ... accept the next part to it, and focus on doing this quest while throughout the Barrens.", x = 63, y = 37, zone = "The Barrens" },
         [15] = { str = "Grab the quest #GETID895# (the wanted sign by the bank)" },
         [16] = { str = "Turn in #INID1111# (goblin on the docks) accept #GETID896# " },
         [17] = { str = "Then go do #DOID887# along with #DOID895# (along the shore just south of Ratchet)" },
         [18] = { str = "Once those are done, turn them in at #COORD[63,36]#, accept new ones, then go do:", x = 63, y = 36, zone = "The Barrens" },
         [19] = { str = "#INID890# (just turn this in at the goblin at the docks) accept #GETID890# part2" },
         [20] = { str = "Run back, to Gazlowe #COORD[63,36]#, turn in #INID890# part2 accept #GETID888# ", x = 63, y = 36, zone = "The Barrens" },
         [21] = { str = "Then go do #DOID888# south of Ratchet. Telescopic Lens=#COORD[64,49]#, and Shipment of Boots=#COORD[63,50]#", x = 63, y = 50, zone = "The Barrens" },
         [22] = { str = "Once #DOID888#  is completed hearth to XRs. (don't turn it in yet)" },
         [23] = { str = "Turn in #INID872# and #INID5041# " },
         [24] = { str = "Turn in #INID844# (It should be done by now) accept #GETID845# .  Also accept #GETID899# and #GETID4921# " },
         [25] = { str = "At this point, I make sure I have three/four 6 slot bags, if I don't, I buy them at the bag vendor." },
         [26] = { str = "Run west from XRs, go to the guy in the hut... at #COORD[45,28]#", x = 45, y = 28, zone = "The Barrens" },
         [27] = { str = "Accept: #GETID850# and #GETID855# " },
         [28] = { str = "Then go start doing:" },
         [29] = { str = "#DOID850# #DOID855# #DOID869# #DOID845# #DOID848#  and  #DOID870# (all of these are done just slightly north of where you are)" },
         [30] = { str = "Once #DOID850# is done.. Barak is at #COORD[43,24]#.", x = 43, y = 24, zone = "The Barrens" },
         [31] = { str = "Go do: #DOID867# at #COORD[38,17]#", x = 38, y = 17, zone = "The Barrens" },
         [32] = { str = "Once #DOID867# is done, grind your way down into Stonetalon Mountains, at #COORD[35,27]# in the Barrens...", x = 35, y = 27, zone = "The Barrens" },
         --[33] = { str = "." },
         --[34] = { str = "." },
      }
   },

   -----------15-16 Stonetalon Mountains
   --[102] = {
   [1516] = {
      title = "15-16 Stonetalon Mountains",
      --n = "15-16 Stonetalon Mountains",
      --pID = 101, nID = 103, 
      --itemCount = 9,
      items = {
         [1] = { str = "15-16 #ZONEID406#" },
         [2] = { str = "Accept #GETID1062# (you should first accept #GETID1061# from Zor Lonetree in Orgrimmar, but this is a lvl13 quest. Grab it if you're in Orgrimmar at that level) and #GETID6548# at #COORD[35,27]# in the Barrens", x = 35, y = 27, zone = "The Barrens" },
         [3] = { str = "Go do: #DOID6548# then turn it in." },
         [4] = { str = "Then do: #DOID6629# at #COORD[73,86]#.", x = 73, y = 86, zone = "Stonetalon Mountains" },
         [5] = { str = "NOTE: I usually skip the escort quest there (#DOID6523# #COORD[73,85]# in the hut), This quest can be a little tough, kill the Sorcerer first that pops out during the one battle you have to fight.  If it's too hard for you, you can skip it.", x = 73, y = 85, zone = "Stonetalon Mountains" },
         [6] = { str = "Turn in #INID6629# and #INID6523# if you did it, at #COORD[35,28]# in the Barrens ... accept #GETID6401# ", x = 35, y = 28, zone = "The Barrens" },
         [7] = { str = "Then go back to the Barrens.." },
         --[8] = { str = "." },
         --[9] = { str = "." },
      }
   },

   -----------16-20 Barrens PART1
   --[103] = {
   --[1620] = {
   [1618] = {
      title = "16-20 Barrens (part 1)",
      --n = "16-20 Barrens Part 1",
      --pID = 102, nID = 104, 
      --itemCount = 37,
      items = {
         [1] = { str = "16-20 #ZONEID17#" },
         [2] = { str = "Grind your way back to the guy in the hut at #COORD[45,28]#", x = 45, y = 28, zone = "The Barrens" },
         [3] = { str = "Turn in #INID850# accept #GETID851# .  Also turn in #INID855# if it is done, if not don't worry." },
         [4] = { str = "Make sure you finish up #DOID869# #DOID845# #DOID848# and #DOID870# before returning to the XRs." },
         [5] = { str = "Run to Cross Roads, at #COORD[52,30]#", x = 52, y = 30, zone = "The Barrens" },
         [6] = { str = "Turn in ALL quests, grab ALL new ones..." },
         [7] = { str = "Then do #GETID853# Which has you run all the way to Thunder Bluff (TB) at the spirt rise cave. Do these along the way:" },
         [8] = { str = "Grind your way down south to #COORD[49,50]#, and do #DOID4921# (Manrik's Wife)  She's laying dead by the hut, west of the bridge.", x = 49, y = 50, zone = "The Barrens" },
         [9] = { str = "Go down to Camp Taurajo (CT) accept #GETID878# from the gnoll in the cage #COORD[44,59]#, and get FP there. ", x = 44, y = 59, zone = "The Barrens" },
         [10] = { str = "Then do #DOID853# Which has you run all the way to Thunder Bluff (TB) in Mulgore, at #COORD[39,27]#.", x = 39, y = 27, zone = "Mulgore" },
         [11] = { str = "Once at TB, go to the #NPCID8920# #COORD[40,62]# and get what weapon skills you need for your class." },
         [12] = { str = "Get new spells/abilities." },
         [13] = { str = "Turn in #INID853# the cave below the spirit rise at #COORD[29,29]#.", x = 29, y = 29, zone = "The Barrens" },
         [14] = { str = "Go to first aid guy at spirit rise to build up first aid." },
         [15] = { str = "Go up to the tower in middle of town to get FP, but DON'T fly back to XRs." },
         [16] = { str = "Hearth back to XRs." },
         [17] = { str = "Turn in #INID4921# " },
         [18] = { str = "Then go north west of XRs and do #DOID903# #COORD[37,20]#", x = 37, y = 20, zone = "The Barrens" },
         [19] = { str = "Then #DOID875# #COORD[38,14]#", x = 38, y = 14, zone = "The Barrens" },
         [20] = { str = "Then grind your way east and do #DOID894# #COORD[52,11]# complete the whole chain, which in the end has you kill the goblin for the key. " },
         [21] = { str = "Then go east to Sludge Fen and do #DOID858# (56.8)", x = 56, y = 8, zone = "The Barrens" },
         [22] = { str = "Then do #DOID114# (#VIDEOSee video on how I do Ignition and Escape#)" },
         [23] = { str = "Then go north-east and do #DOID896# (61.5)", x = 61, y = 5, zone = "The Barrens" },
         [24] = { str = "Then grind your way south to Ratchet #COORD[63,37]#...", x = 63, y = 37, zone = "The Barrens" },
         [25] = { str = "Turn in #INID888#  #INID894# #INID114# ... accept #GETID1483# ... and SKIP #NPCID9316# " },
         [26] = { str = "Turn in #INID896# " },
         [27] = { str = "Then go west of ratchet and do #DOID877# and #DOID851# at #COORD[54,43]#", x = 54, y = 43, zone = "The Barrens" },
         [28] = { str = "Then run to XRs #COORD[52,30]#..", x = 52, y = 30, zone = "The Barrens" },
         [29] = { str = "Turn in #INID903# #INID875# and #INID877# ... accept #GETID880# #GETID881# #GETID876# #GETID6541# and #GETID868# " },
         [30] = { str = "Go west of XRs #COORD[45,28]#, to turn in: #INID855# and #INID851# ... I SKIP #NPCID3396# ", x = 45, y = 28, zone = "The Barrens" },
         [31] = { str = "Then grind your way north and do: #DOID876# at #COORD[38,11]#", x = 38, y = 11, zone = "The Barrens" },
         [32] = { str = "Then go east (grind mobs along the way) and do #DOID881# at #COORD[55,17]#.", x = 55, y = 17, zone = "The Barrens" },
         [33] = { str = "Hearth to XRs." },
         [34] = { str = "Turn in #INID881# ... accept #GETID905# " },
         [35] = { str = "Turn in #INID876# accept #GETID1060# .  Make sure that #GETID899# is also accepted." },
         --[36] = { str = "." },
         --[37] = { str = "." },
      }
   },

   -----------16-20 Barrens PART2
   --[104] = {
   --[1620] = {
   [1820] = {
      title = "16-20 Barrens (part 2)",
      --n = "16-20 Barrens Part 2",
      --pID = 103, nID = 201, 
      --itemCount = 31,
      items = {
         [1] = { str = "16-20 #ZONEID17#" },
         [2] = { str = "Go down south and do:" },
         [3] = { str = "#DOID880#   #COORD[55,42]#", x = 55, y = 42, zone = "The Barrens" },
         [4] = { str = "#DOID865# along with #DOID3281#   at #COORD[57,54]#  ", x = 57, y = 54, zone = "The Barrens" },
         [5] = { str = "#DOID905#   #COORD[51,46]#", x = 51, y = 46, zone = "The Barrens" },
         [6] = { str = "#DOID878# along with #DOID899#   at #COORD[51,54]#", x = 51, y = 54, zone = "The Barrens" },
         [7] = { str = "Then grind your way to Camp Taurajo #COORD[45,58]#", x = 45, y = 58, zone = "The Barrens" },
         [8] = { str = "Accept #GETID893# " },
         [9] = { str = "Go to gnoll in the cage..." },
         [10] = { str = "Turn in #INID878# accept #GETID5052# and #GETID879# " },
         [11] = { str = "Turn in #INID5052# " },
         [12] = { str = "Turn in 10 bloodshards for #INID889# (repeatable quest) for fast run speed." },
         [13] = { str = "At this point, you should be about half way to level 20." },
         [14] = { str = "Now comes the fun part:  #ZONEID718# Instance! at #COORD[46,36]#.  You will need a full group to do this.  OPTIONAL: GRIND all the way to level 20! (which is what I do, but it's not recommended).  I grind away at beasts and brisstlebacks just north of CT.  " },
         [15] = { str = "Keep an eye out for the mobs named #NPCID3474# (a big grey kodo around #COORD[45,53]#) and #NPCID3473#. They drops #ITEMID5099# which starts #DOID883# and #ITEMID5101# which starts #DOID884#.  Turn these in at CT when you get the chance." },
         [16] = { str = "Once you are at least 5 bars away from 20, run to XRs..." },
         [17] = { str = "Turn in #INID3281# #INID899# #INID880# and #INID905# ...accept all new quests.  SKIP #SKIPID3301# .  You should be lvl 20 now." },
         [18] = { str = "Fly to Orgrimmar, get new spells/abilities." },
         [19] = { str = "Grab #GETID235# quest" },
         [20] = { str = "Hearth back to XRs." },
         [21] = { str = "Fly to Ratchet..." },
         [22] = { str = "Turn in #INID819# (if you did it, if not don't worry) ... accept the next part to it." },
         [23] = { str = "Turn in #INID865# accept #GETID1069# and #GETID1483# " },
         [24] = { str = "Then go do: #DOID891# at #COORD[60,55]#  (#VIDEOSee complete video on this quest along with the escort quest#)", x = 60, y = 55, zone = "The Barrens" },
         [25] = { str = "Then once #DOID891# is done, do:" },
         [26] = { str = "#DOID898# (escort quest)" },
         [27] = { str = "Turn in both quests at Ratchet, then.." },
         [28] = { str = "Hearth to XRs. (if hearth stone is still on a cooldown, fly to XRs)" },
         [29] = { str = "Run west into Stonetalon Mountains..." },
         --[30] = { str = "." },
         --[31] = { str = "." },
      }
   },

}
