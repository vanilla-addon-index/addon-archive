# 🍕🐟 PizzaTonno

A fishing addon that knows where, when and how likely every fish bites.

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaTonno/hud-confetti.webp" width="43%"> <img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaTonno/almanac-today.png" width="56.3%">

Equip your pole and the HUD shows every fish you can catch where you stand, the chance of each one right now, and how often you've actually caught it there. The almanac has the rest: every fish in every spot by day, night and season, what's worth farming right now, and your own stats. It also does what FishingBuddy does (right-click to cast, lures, louder splashes), so you can import your FishingBuddy history and turn that one off.

> **Animations powered by [PizzaSauce](https://codeberg.org/Pizzahawaii/PizzaSauce).** If flying fish and confetti aren't your thing, turn off "Catch animation" in the minimap menu.

## Install

### [⬇️ Download the latest version](https://codeberg.org/Pizzahawaii/PizzaTonno/releases/latest)

1. Download `PizzaTonno-<version>.zip` from the release page and extract it
2. Copy the `PizzaTonno` folder inside it to `<WoW>/Interface/AddOns`
3. (Re)start WoW

> [!WARNING]
> Extracting might give you a `PizzaTonno-<version>` folder with the actual `PizzaTonno` folder inside it. If so, copy the inner one. WoW only loads it as `AddOns/PizzaTonno/PizzaTonno.toc`, not `AddOns/PizzaTonno-<version>/PizzaTonno/PizzaTonno.toc`.

## Version Upgrade

To update to the latest version, delete your `<WoW>/Interface/AddOns/PizzaTonno` folder and follow the [installation steps](#install) again.

Check the [commit history](https://codeberg.org/Pizzahawaii/PizzaTonno/commits/branch/main) to see the latest changes.

## Importing FishingBuddy

<!-- screenshot: the import prompt -->

If FishingBuddy is on, PizzaTonno asks once at login whether you want your old catches. `/pt import` asks again if you said no, and importing twice replaces the first import instead of doubling up. FishingBuddy never saved the season of a catch (and for older ones not even the hour), so those only count for your all time numbers.

> [!IMPORTANT]
> Turn FishingBuddy off once you've imported. While it's on, PizzaTonno leaves right-click casting, lures and sounds to FishingBuddy.

## Commands

- `/fish`: open or close the almanac
- `/pt here`: every catch chance where you stand, your skill and how often a catch lands
- `/pt time`: zone clocks, seasons and the Stranglethorn Fishing Extravaganza
- `/pt watch [item]`: watch or unwatch a fish (shift-click the item into the command)
- `/pt lock` / `/pt unlock`: lock the HUD in place, or unlock it to drag it
- `/pt reset`: put the HUD back where it started
- `/pt import`: import your FishingBuddy history (again)
- `/pt minimap`: show or hide the minimap button
- `/pt`: this list

`/tonno` works the same as `/pt`, and `/pt almanac` is `/fish`. Left-click the minimap button for the almanac, right-click it for the settings.

## Fishing

<!-- gif: right-click casting, a lure going on first, then the cast -->

- **Right-click to cast.** With a pole equipped, a quick right-click casts. While the bobber is out it takes a double right-click, so a single one still loots it. Holding Shift, Ctrl or Alt gives you the normal right-click. There's also a "Fish" key binding.
- **Lures.** If you need a lure, the click puts on the weakest one in your bags that's still enough for this spot, and the next click casts.
- **Sounds.** While your pole is out, sound effects go to max and music and ambience go quiet, so you can hear the splash.

All of it can be switched off in the minimap menu.

## The HUD

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaTonno/hud.png" width="30%" align="left" />

Shows up when you equip a pole or cast, and goes away when you take the pole off or haven't fished for two minutes.

Every fish you can catch here with its chance right now. The white number and tick under it are how often you caught it yourself, and the faint band around the tick narrows the more you fish. A sun or snowflake means it only bites by day, at night, in summer or in winter. Pool catches don't count here, pools have their own loot.

The top has the zone's clock with a day and night strip, your skill and how often a catch lands. Hover anything for more.

When you catch something, the fish flops out of the water and flies into its row. Right-click a fish to watch it: watched fish go to the top, never drop off the list and come with confetti. Left-click one for its page in the almanac.

Drag it wherever you want, then lock it with `/pt lock`.

<br clear="left"/><br>

## The almanac

`/fish` or left-click the minimap button. Right-click any fish in it to watch it.

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaTonno/almanac-today.png" width="65%" align="left" />

**Today** is what to farm right now: of your watched fish, the one having its best time, and if several are, the one whose window closes first. Below that, every watched fish with its best spot right now and how good now is for it, from Peak to Poor.

<br clear="left"/><br>

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaTonno/almanac-fish-list.png" width="65%" align="left" />

**Fish** is everything you can catch, sorted into sections you can fold, with its best spot right now.

<br clear="left"/><br>

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaTonno/almanac-fish-details.png" width="65%" align="left" />

**A fish's page** has its best spot right now, your own best spot and the best of all, then every spot with the skill it needs and the chance by day and at night. Yours are in purple underneath. At the bottom: the pools that have it and the recipes that use it.

<br clear="left"/><br>

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaTonno/almanac-search.png" width="65%" align="left" />

**Search** finds fish, places and dishes. The arrows next to it (or your mouse's back and forward buttons) work like in a browser.

<br clear="left"/><br>

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaTonno/almanac-calendar.png" width="65%" align="left" />

**Calendar** shows summer and winter across the year, day and night on both continents, and what's coming up. Kalimdor's clock is 12 hours off from the Eastern Kingdoms, so when it's night in Stranglethorn it's day in Feralas.

<br clear="left"/><br>

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaTonno/almanac-places-list.png" width="65%" align="left" />

**Places** has every zone, dungeon, raid and battleground, with everything its waters have, spot by spot.

<br clear="left"/><br>

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaTonno/almanac-journal.png" width="65%" align="left" />

**Journal** is your fishing in numbers: catches over time, catches by hour of the day, your most caught fish and most fished spots. The tiles with a purple corner open the full lists, including a log of every single catch.

<br clear="left"/><br>
