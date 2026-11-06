--[[--------------------------------------------------
   002_Mulgore.lua
   Authors: mrmr, lanjelin
   Version: 1.04.3
   ------------------------------------------------------
   Description: Guide Serie - 001 Introduction
   1.04.1
   -- First Release
   Taurens Mulgore's Guide
   from level 1 to lever 12
   1.04.2
   -- no changes in here for this revision
   1.04.3
   -- Cleanup in text, changed formatting of coords
   ------------------------------------------------------
   Connection:
--]]--------------------------------------------------

Table_002_Mulgore = {
   -----------1-6 Mulgore
   --[14] = {
   [0106] = {
      title = "1-6 Mulgore",
      --ddmtype = 'v'
      --ddmlvl = '2'
      --n = "1-6 Mulgore",
      --pID = 1, nID = 15,
      --itemCount = 17,
      items = {
         [1] = { str = "1-6 #ZONEID215#" },
         [2] = { str = "In reference to the Shamans, please look down the guide at the class quest part and follow the link which will give you all the information on your class quests as you have them from level 4." },
         [3] = { str = "Talk to Grull Hawkwing #COORD[44,77]# and accept #GETID747# then go outside the area kill Plainstriders and loot 7 feathers and 7 meat. Run back turn it in and accept #GETID750# and accept #GETID3092#.", x = 44, y = 77, zone = "Mulgore" },
         [4] = { str = "Talk to your class trainer and turn in #INID3092# then talk to Chief Hawkwind and accept #GETID752#." },
         [5] = { str = "Go to #COORD[50,81]# and turn in #INID752# at Greatmother Hawkwind, accept the next part then click the water pouch on the fountain, then run back and turn in #INID752# and accept #GETID755#. ", x = 50, y = 81, zone = "Mulgore" },
         [6] = { str = "Grind to level 3 then run back to Camp Narache and accept #GETID3376#." },
         [7] = { str = "South of the camp around #COORD[44,88]# kill 10 Cougars and loot their pelts then run to #COORD[42,92]# and talk to Seer Graytongue and turn in #INID755# and accept #GETID757#.", x = 44, y = 88, zone = "Mulgore" },
         [8] = { str = "Run back to Camp Narache to Chief Hawkwind #COORD[44,77]# turn in #INID750# and accept #GETID780# grinding mobs along the way until you hit level 4." },
         [9] = { str = "Run to #COORD[53,81]# and kill Battleboar until you have 8 Flank and 8 Snout. ", x = 53, y = 81, zone = "Mulgore" },
         [10] = { str = "Run to the cave at #COORD[58,85]# kill the Quilboar for 12 Belts as you make your way to the tent at #COORD[64,77]# and kill Sharptusk making sure to loot him for #DOID3376# then run to the little cave at #COORD[63,82]# and on the inside is a Dirt-stained Map. Use it to start #GETID781#.", x = 58, y = 85, zone = "Mulgore" },
         [11] = { str = "Hearth back to Camp Narache go to Chief Hawkwind #COORD[44,77]# and turn in #INID780#, #INID781# and #INID757# then accept #GET763# part 2.", x = 44, y = 77, zone = "Mulgore" },
         [12] = { str = "Talk to Brave Windfeather and turn in #INID3376#." },
         [13] = { str = "Go to #COORD[38,81]# and speak to Antur Fallow and accept #GETID1656# then continue following the road to Bloodhoof Village.", x = 38, y = 81, zone = "Mulgore" },
         [14] = { str = "Talk to Innkeeper Kauth and turn in #INID1656# and make Bloodhoof Village your home." },
         [15] = { str = "You should be level 6 now, if not grind the little exp you should need until you are." },
         --[16] = { str = "." },
         --[17] = { str = "." },
      }
   },

   -----------6-10 Mulgore
   --[15] = {
   [0610] = {
      title = "6-10 Mulgore",
      --n = "6-10 Mulgore",
      --pID = 14, nID = 16,
      --itemCount = 20,
      items = {
         [1] = { str = "6-10 #ZONEID215#" },
         [2] = { str = "Talk to Baine Bloodhoof and turn in #INID755# accept #GETID745#, #GETID767# and #GETID746#." },
         [3] = { str = "Accept #GETID748# from Mull Thunderhorn #COORD[48,60]#. Talk to Zarlman Two-Moons #COORD[47,57]# turn in #INID767# and accept part 2.", x = 48, y = 60, zone = "Mulgore" },
         [4] = { str = "Talk to Ruul Eagletalon #COORD[47,62]# accept #GETID743# then talk to Harken Windtotem #COORD[48,59]# and accept #GETID761#. Talk to Maur Raincaller #COORD[47,57]# accept #GETID766#.", x = 47, y = 62, zone = "Mulgore" },
         [5] = { str = "Go southeast to #COORD[51,66]# and kill Trophy Swops for 8 Quills, Prairie Wolfs for 6 Paws, Plainstriders for 4 Talons and underneath trees loot 2 Ambercorns and 2 Well Stones near the well #COORD[53,64]#.", x = 51, y = 66, zone = "Mulgore" },
         [6] = { str = "Go to #COORD[52,70]# and kill the Palemane for #DOID745#.", x = 52, y = 70, zone = "Mulgore" },
         [7] = { str = "At #COORD[33,41]# kill Harpies for 8 Windfury Talons. Then to #COORD[31,50]# and acquire broken tools for #DOID746#.", x = 33, y = 41, zone = "Mulgore" },
         [8] = { str = "Then go to #COORD[59,62]# and accept #GETID749# from Morin Cloudstalker. Go to #COORD[54,48]# and click on the crates to turn it in then accept the second part. Run back to Morin Cloudstalker #COORD[59,62]# and turn it in then accept #GETID764# and #GETID765#.", x = 59, y = 62, zone = "Mulgore" },
         [9] = { str = "Grind to level 8 if you aren't quite there yet." },
         [10] = { str = "Go back to Bloodhoof Village and turn in #INID748#, #INID743#, #INID761# then turn in #INID767# and accept the next part. Accept #GETID754#." },
         [11] = { str = "Go to #COORD[53,67]# and cleanse it using Thunderhorn's item. Then run back to Mull Thunderhorn #COORD[49,60]# and turn in #INID754# and accept #GETID756#.", x = 53, y = 67, zone = "Mulgore" },
         [12] = { str = "Go to #COORD[47,57]# and drink #ITEMID4823# in your backpack, then follow the wolf spirit.", x = 47, y = 57, zone = "Mulgore" },
         [13] = { str = "Turn in #INID767# #COORD[33,36]# when the spirit stops and accept #GETID773#.", x = 33, y = 36, zone = "Mulgore" },
         [14] = { str = "Continue to #COORD[59,25]# to Lorekeeper Raintotem and accept #GETID833#. ", x = 59, y = 25, zone = "Mulgore" },
         [15] = { str = "Go to the Ancestral Spirit at the Red Rocks #COORD[60,21]# turn in #INID773# accept #GETID775# and kill 8 Bristleback Interlopers nearby and once done speak to Lorekeeper Raintotem #COORD[59,25]# and turn in #INID833#.", x = 60, y = 21, zone = "Mulgore" },
         [16] = { str = "Go to Thunder Bluff to the Forge at #COORD[39,55]# and destroy the Prospector's Picks here by clicking on them to destroy them.", x = 39, y = 55, zone = "Thunder Bluff" },
         [17] = { str = "Go to #COORD[69,51]# and talk to Cairne Bloodhoof to turn in #INID775# accept #GETID755#.", x = 69, y = 51, zone = "Thunder Bluff" },
         [18] = { str = "You should now be level 10, if not grind to it. Its time to do your class quest and below will tell you each class quest and how to do them but you can wait until you hit 12 before doing them to continue with Joana's 12-60 guide." },
         --[19] = { str = "." },
         --[20] = { str = "." },
      }
   },

   -----------10-12 Mulgore
   --[16] ={
   [1012] = {
      title = "10-12 Mulgore",
      --n = "10-12 Mulgore",
      --pID = 15, nID = 101,
      --itemCount = 19,
      items = {
         [1] = { str = "10-12 #ZONEID215#" },
         [2] = { str = "Hearth to Bloodhoof Village. Talk to Skorm Whitecloud #COORD[46,60]# accept #GETID861#.", x = 46, y = 60, zone = "Mulgore" },
         [3] = { str = "Turn in #INID746# and #INID756# then accept #GETID758#." },
         [4] = { str = "Go to #COORD[48,60]# and speak to Baine Bloodhoof and turn in #INID745#.", x = 48, y = 60, zone = "Mulgore" },
         [5] = { str = "Go to the Water Well at #COORD[44,45]# and use it to cleanse your totem in your inventory.", x = 44, y = 45, zone = "Mulgore" },
         [6] = { str = "Go to #COORD[45,16]# and kill Flatland Prowlers until you have 4 claws.", x = 45, y = 16, zone = "Mulgore" },
         [7] = { str = "Go to #COORD[61,47]# and you should see the Venture Co. Mine. Kill 14 Workers and 6 Supervisors. Take a right at the first intersection and you should see Fizsprocket, then kill him.", x = 61, y = 47, zone = "Mulgore" },
         [8] = { str = "Go to #COORD[59,62]# and turn in #INID764# and #INID765#.", x = 59, y = 62, zone = "Mulgore" },
         [9] = { str = "Go to #COORD[49,60]# and turn in #INID758# then accept #GETID759#. Go to #COORD[69,51]# and turn in #INID755#.", x = 49, y = 60, zone = "Mulgore" },
         [10] = { str = "Go to #COORD[46,60]# and turn in #INID861#.", x = 46, y = 60, zone = "Mulgore" },
         [11] = { str = "Go to #COORD[38,60]# in Thunder Bluff and you should see Eyahn Eagletalon. Accept #GETID744#.", x = 38, y = 60, zone = "Thunder Bluff" },
         [12] = { str = "Go behind Thunder Buff and kill Bluffwatchers until you have 6 Azure and 6 Bronze Feathers then run back to #COORD[38,60]# and turn it in.", x = 38, y = 60, zone = "Thunder Bluff" },
         [13] = { str = "Run back to Bloodhoof Village but make sure you kill Prairie Alphas along the way until you have 8 Teeth." },
         [14] = { str = "Go to #COORD[49,60]# and turn in #INID759#.", x = 49, y = 60, zone = "Mulgore" },
         [15] = { str = "You should be level 12 now, if not grind to it then run into the Barrens following the path until you come to Camp Taurajo. Talk to Kirge Sternhorn #COORD[44,58]# and accept #GETID854# and get the Flight Path.", x = 44, y = 58, zone = "Mulgore" },
         [16] = { str = "Run north up the road until you get to the Crossroads and turn in #INID854# get the Flight Path." },
         [17] = { str = "Now you can continue with the 12-15 Barrens guide which is in the 1-60 guide." },
         --[18] = { str = "." },
         --[19] = { str = "." },
      }
   },
}
