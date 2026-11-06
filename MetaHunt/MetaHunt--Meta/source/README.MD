# MetaHunt

MetaHunt is a Twow Hunter toolkit.

It is a modern modular addon compiling brand new features, and improving a few old hunter add-ons that were broken or disfunctional with twow.

It provides a bunch of useful functionalities for all huntards, wheter they are still levelling, lone-wolf, or HL raider.
You play the best class, now you have the best companion for it (and its not your pet).

### Important notes

- Altough Nampower isn't mandatory for most of the features, it is a must-have for some, and certainly the MM Widget.
- If you were using old versions of Feed-O-Matic, ICU, zHunterMod and HunterHelper, you dont need those with MetaHunt and you SHOULD disable them to avoid conflicts. 
- MetaHunt is fully compatible with QUIVER <3, and is not a replacement for it.
- The addon purposely disable itself on all Capycraft/Ravencraft Realms, following the DDOS attacks they conducted on other servers.


### Installation (READ THIS!) ⚠️⚠️⚠️

After you download the zip, you have a manual action to do because of Gitea behaviour.

When you unzip, you will find a "metahunt" root folder, you SHOULD rename it as exactly "MetaHunt", and then move that folder in your \Interface\AddOns\ directory. If you dont restore the capital letters in the folder name, the addon will be broken.

This is [a known issue from Gitea/Forgejo](https://codeberg.org/forgejo/forgejo/issues/800) when the system creates zip files, and there's nothing add-on devs can do to overcome it.


 ## Twow Data

MetaHunt ships with large twow datastores, and notably:

- 100% accurate beasts' data, their locations, and the abilities they can learn you
- All Pet families, their abilities and their diet
- All pet abilities ranks
- All hunter and pet spells
- All Ammo and ranged weapons
- All Hunter/Pet/Stable Masters
- All Ammo vendors

Online bestiary is also available here https://duvelcorp.codeberg.page/MetaHunt-Web/


 ## Smart Ammo

- Auto swap your main ammo to junk ammo for shots that doesn't scale on damage, and re-equip you main ammo right away. Don't waste your Doomshots on nothing anymore, save money !
- Auto equip another ammo instantly during combat whenever you get out of your current ammo.
- Auto equip the right ammo when you swap from a box/xbow to a gun and the other way around.

## MM Widget

 1.18.1 weapon of mass-destruction. NAMPOWER MANDATORY. The widget is composed of 5 cells, tracking the 3-state of Experimental ammo cycle (Fire → Nature → Arcane), the Lock & Load procs, and a smart dynamic cell. The smart cell shows either Aimed Shot availability or the right shot to use following the current Experimental ammo proc if any, and it bypasses the proc spell if your current target is immune to the school. You can bind the smart cell to turn the widget into a very efficient one-button rotation. Lets make MM great again ! 

 ## Tooltips
 
 Get enhanced mouseover tooltips on :
 - Beasts : Shows which abilities a beast can teach. They appear green if you already know them, and red if not.
 - Vendors : Shows if a vendor sells Arrows and/or Bullets.
 - Your pet : Shows your pet's XP, loyalty, happiness and how much you fed it this session.

 ## zButtons

Old zHunterMod addon on steroids. Fully compatible with Twow, and enhanced with new functionalities

- zAmmo : Track all your ammo Live and swap them in a click or bind
- zPet : Intelligent collapsible pet Bar regrouping all pet spells and providing a main button that always swap on  the right spell to use depending on the situation
- zTrack: All your trackings in one collapsible bar
- zAspect: All your aspects in one collapsible bar
- zRanged : All the ranged weapons currently in your bags to swap them fast
- But also zCrafts, zMounts, zToys and zCompanions.

Additionally, a special _zBar_ can regroup all the zButtons above into a single bar for people that like clean and ordered stuff.

 ## Feed-O-Matic

Now compatible with Twow, feed your pet with one key bind, it will always pickup the best food for your pet, according to your preferences.

 ## Chronometer

The good old Chronometer addon, purged of non-necessary things and reconfigured for a pure hunter usage.

 ## ICU (I see you)

This old addon is mostly a PVP weapon used to display targets' enhanced information when you click on your minimap tracked things. MetaHunt offers many more customization options for it.

 ## Ammo labels

 You can display some labels on all ammo in your bags/bank to instantly see which of those damn same arrows icons really are.

 ## Auto-Buy

Define your own simple rules for auto buy ammo and pet food when you open a vendor. You can also make a food-auto-buy planning based on all your stabled pet's diets.

 ## Auto-Quest

Just spam SHIFT-click on the NPC to validate quests Scorpok and Thorium arrows. Additionally you can have an enhanced tooltip that display your actual Scorpok-related items when you mouseover the Blasted Land mobs involved.

 ## Efficient Scanners

The add-on smartly scan your character and pet tabs, spellbook, beast training, stable and learning masters windows. This is done automatically and fast in the background, and allows to enrich the static datastore with YOUR own data, and to provide meaningfull dynamic information following the context. It also scan your Pet's state constantly, but with minimal ressources.

 ## Animations

Metahunt is the first add-on that uses the great PizzaSauce library of [Pizzahawaii](https://codeberg.org/Pizzahawaii/). This adds fun and makes the interface feel alive.

 ## The Great Book of Huntards

 The Book is the main GUI of MetaHunt, it allows to browse the addon's data to find anything a Hunter needs.

- Search Hunter-related NPCs (Beasts, vendors, masters) and open the map to locate them like in pfQuest.
- Beast model Viewer : Display the model of all beasts in the world. You can also browse all skin models of the same family to find the best-looking pet according to your tastes. 
- Instantly find where the beasts having a specific ability are lying and plan ahead your tracking sessions.
- Get a full understanding of all Pet families. 
- Display meaningfully the pet abilities that you know and don't know yet
- Get your stable's state everywhere and track all possible information about all your pets
- Keep a detailed history of all the pets you abandonned or those that ran away.
- Browse all twow 1.18.1 hunter and pet spells. Get the status of what you already learned or not, and a detailed cost planning.

 ## Tune it the way you like

Metahunt option panel is huge. There are hundreds of settings you can configure in order to tweak it like a boss so it fits YOUR preferences.
Its modular architecture also allows you to completely disable any module in order to decrease the addon's memory footprint and background processes.    


 ### The world is yours. Happy Hunting Fellas !

