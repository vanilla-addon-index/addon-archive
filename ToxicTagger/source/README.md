# Why ToxicTagger

This addon enables you to easily make macros that are good for tagging mobs with the toxictagger command.

This addon/macro is good for getting the tag on the right mobs with very little effort on your part. 

I tried to make it as faceroll as possible which means that the most optimal way to use this macro is to bind it on the scroll wheel (up and down) and spam it.

If no one else is using this macro, you are pretty much guaranteed to get the tag every time.

You don't have to worry about accidentally wasting your cooldowns or globals on mobs you dont want to attack e.g.: 
Mobs that are tagged by other players, wrong mobs or getting stuck targetting dead mobs. 

# How to use: 
Step 1: Install the addon, obviously. (Remove "-master" from the name")

Step 2: Make a macro like this:

    /run toxictagger("Spell Name Here(Optional Rank X)", {"Name of Mob1", "Name of Mob2"});

For example: 

    /run toxictagger("Fire Blast", {"Mankrik's Wife", "VanCleef", "Stranglethorn Panther"});
    
or 

    /run toxictagger("Fire Blast(Rank 1)", {"Mankrik's Wife", "VanCleef", "Stranglethorn Panther"});
    
Step 3: Bind the macro to scroll up+scroll down or use program like AutoHotkey to spam the macro faster than your framerate.
    
What you need: 

* A spell you want to tag with. E.g. Fire Blast, Charge, Moonfire
* Names of the mob(s) that you want to tag. 

# Example use 1: 
The best use case is when you are waiting for spawn of a rare mob and you have to compete for the tag against others. 
Let's say you need to kill **Yowler** for the quest *Howling in the Hills* and you want to tag with a rank 1 spell.

    /run toxictagger("Fire Blast(Rank 1)", {"Yowler"});

Put that in a macro and bind it to your scrollwheel up and down. 

Stand close to where he spawns and just scroll. You will probably get the tag and you don't have to worry about casting fire blast on the wrong mob.

# Example use 2: 
Let's say you are a lvl 15 Mage in Moonbrook, Westfall and need Defias Pillagers and Defias Looters for your quest. Maybe you need Goretusks too.

    /run toxictagger("Fire Blast", {"Pillager", "Looter", "Goretusk"});

Notice
1) You don't need to write the full name of the mob you want. You only need to write some of it. In this example I didnt write "Defias" but you *could* also make it work with {"Pill", "Loot"}

2) You dont need to specify rank of your spell. If you dont specify rank, it will use the highest rank.

# Example use 3:
Maybe you want to get the tag on earth elementals: 

    /run toxictagger("Lightning Breath", {"Rock Elemental"});

This will tag both *Lesser Rock Elementals* and *Rock Elementals* which both drop Elemental Earth. 

Notice that Lightning Breath is a pet ability.
