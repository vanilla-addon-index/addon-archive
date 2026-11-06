# 🍕 PizzaSlices

Radial action menus for vanilla WoW. A simplified [OPie](https://www.curseforge.com/wow/addons/opie) clone.

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSlices/demo.gif" width="100%">

## Install

### [⬇️ Download the latest version](https://codeberg.org/Pizzahawaii/PizzaSlices/releases/latest)

1. Download `PizzaSlices-<version>.zip` from the release page and extract it
2. Copy the `PizzaSlices` folder inside it to `<WoW>/Interface/AddOns`
3. (Re)start WoW

> [!WARNING]
> Extracting might give you a `PizzaSlices-<version>` folder with the actual `PizzaSlices` folder inside it. If so, copy the inner one. WoW only loads it as `AddOns/PizzaSlices/PizzaSlices.toc`, not `AddOns/PizzaSlices-<version>/PizzaSlices/PizzaSlices.toc`.

## Version Upgrade

To update to the latest version, delete your `<WoW>/Interface/AddOns/PizzaSlices` folder and follow the [installation steps](#install) again.

Check the [commit history](https://codeberg.org/Pizzahawaii/PizzaSlices/commits/branch/main) to see the latest changes.

## Features

PizzaSlices lets you create custom rings, fill them with various types of actions and bind them to different keys. It doesn't reuse any of your existing action buttons so you won't lose any of that precious action bar space.

### Raid Marks

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSlices/raidmarks.gif" width="50%" align="left" />

Assign any raid marks quickly and easily with the press of a single button, no matter if you're using [SoloRaidTargetIcons](https://github.com/refaim/SoloRaidTargetIcons) or in a group/raid. There's also a special action to instantly clear all previously assigned raid marks.
<br clear="left"/>

### Abilities

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSlices/abilities.gif" width="50%" align="left" />

You can add all your active abilities to rings. Buffs, auras, hunter aspects, or even damage and healing abilities if you really want to - go crazy!
<br clear="left"/>

### Mounts

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSlices/mounts.gif" width="50%" align="left" />

All your mounts can be added to rings as well, anything you see in the 'Mounts' tab in your spellbook.
<br clear="left"/>

### Toys & Companions

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSlices/toys-companions.gif" width="50%" align="left" />

Anything from the 'Toys' and 'Companions' tabs in your spellbook can also be added to rings.
<br clear="left"/>

### Professions & General

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSlices/professions.gif" width="50%" align="left" />

Your professions and anything else listed in the 'General' tab of your spellbook are available as well. Excluding passive abilities, obviously.
<br clear="left"/>

### Macros

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSlices/macros.gif" width="50%" align="left" />

You can also add macros to rings if you need even more flexibility.
<br clear="left"/>

### ItemRack Sets

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSlices/sets.gif" width="50%" align="left" />

If you're using ItemRack, you can also add your gear sets to rings to quickly change outfits on the fly.
<br clear="left"/>

## Opening Rings via Macros

You can open your PizzaSlices rings through macros instead of game-internal key bindings with this command:

```
/ps open <ringIndex>
```

`<ringIndex>` has to be a number - the index of the ring you want to open according to the ring list in the settings menu, starting with `1`.

Let's say you see three rings in the settings:

```
Raid Marks
General
Mounts
```

Then creating a macro with `/ps open 1` would open the Raid Marks, `/ps open 2` would open the General ring, and `/ps open 3` would open the Mounts ring.

> [!WARNING]
>
> Opening rings through macros is currently not supported if you have the addon Bongos installed.

> [!NOTE]
> 
> This feature requires your action buttons to trigger on keydown, not on keyup (which is the game's default). PizzaSlices therefore comes with its own version of [Snowfall](https://github.com/Linae-Kronos/Classic-Snowfall). Note that if you're using pfUI, PizzaSlices forces your "Trigger Actions on Key Down" pfUI action bar setting to always be enabled.

> [!NOTE]
>
> Opening rings via macros doesn't work when clicking the macro button. You have to bind the macro action button to a key and press that key to open the ring.

## Settings

Use one of the following commands to open the settings menu:

```
/ps
/slices
/pizzaslices
```

### Add Stuff to a Ring

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSlices/settings-ringcreation.gif" width="65%" align="left" />

On the 'Rings' tab, click on the green + or on the name of one of the existing rings. Select one of the categories on the right. Then, drag & drop any of the items from the center into the ring area on the left (purple background). Finally, click 'Save'.
<br clear="left"/>

### Remove Stuff from a Ring

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSlices/settings-slice-deletion.gif" width="65%" align="left" />

To remove an item from a ring, simply drag & drop it into the red trash can area that appears when you start dragging it away from the ring section (purple background).
<br clear="left"/>

## Missing Feature? Bug?

Please check the [issue list](https://codeberg.org/Pizzahawaii/PizzaSlices/issues) to see if it was reported already. If not, create a new issue or contact me on Discord or ingame (see below).

## Contact

You're always more than welcome to ask questions or provide any kind of feedback.

- **Discord**: Pizza
- **Nordanaar**: Pizzahawaii, Pizzamista, Pizzapimp, Pizzapaws, Pizzapog<br />If you see anyone whose name starts with 'Pizza', chances are it's me. 

## Credits

Thanks to [foxlit](https://www.curseforge.com/members/foxlit) for the inspiration! 🚀

Thanks to all the beta testers for providing valuable feedback! ♥️

- Hersi/blu5hit
- Cliffholger
- Lo5t1ncyb3r
- mentalxpc
- rooti
- Ténébreux
- Zcoobee

Thanks to Kanki for the name PizzaSlices! 💯
