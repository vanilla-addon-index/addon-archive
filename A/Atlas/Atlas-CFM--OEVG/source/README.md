# Atlas-CFM

[![ClassicAPI](https://img.shields.io/badge/ClassicAPI-Optional-yellow.svg)](https://github.com/brues-code/ClassicAPI)
[![OctoBus](https://img.shields.io/badge/OctoBus-Optional-yellow.svg)](https://octowow.st/git/OEVG/OctoBus)

An English-only dungeon and raid atlas for the OctoWoW 1.18.1 client (WoW 1.12.1, interface 11200). Browse instance maps, boss loot, and quests, or check transport countdowns directly on the Blizzard world map.

**Version 1.89.1.** See the [changelog](CHANGELOG.md) for changes in this fork.

## Installation

1. Exit the game. If you have an older Atlas-CFM, back up its addon folder and move it out of `Interface/AddOns`.
2. Copy the `Atlas-CFM` and `Atlas-CFM_Core` folders from this repository into `Interface/AddOns` as siblings. Keep both folder names as shown.
3. Enable both entries on the character selection screen. Keep your existing SavedVariables to carry over settings, wishlists, and quest progress.

The `Atlas-CFM` folder provides the minimap button, world map markers, and slash commands at login. It loads `Atlas-CFM_Core` when you open Atlas or its options, click an Atlas world map pin, or open a trade skill or craft window.

## Quick start

| Control | What it does |
| --- | --- |
| `/atlascfm` or left-click the minimap button | Toggle Atlas. |
| `/atlascfm options` or middle-click the minimap button | Open settings. |
| Right-drag the minimap button | Move the button. |
| Click an Atlas pin on the world map | Open the corresponding Atlas map or transport page. |
| `/atlascfm ver` | Print the installed version. |
| `/atlascfm status` | Check whether the core is loaded and whether preload is enabled. |
| `/atlascfm preload` | Toggle loading the core at login. Takes effect on the next login or UI reload. |

## Features

- **Maps, loot, and quests.** Browse instance maps and boss drops, and view faction-specific quests and rewards.
- **Search and wishlist.** Search for items, spells, and enchants. Save items to your character’s wishlist.
- **Tooltip sources and drop rates.** Enable **Show Source on Tooltips** and **Show Drop Rate on Tooltips** to show the recorded percentage beside the source. Tooltip additions become available as the core builds its index. Enable preload to start that process at login.
- **Professions.** Browse recipes and reagents, see skill requirements, and filter recipes by profession.
- **World map markers.** See dungeon, raid, world boss, and transport pins. Toggle markers and cursor coordinates in Atlas settings.

## Optional integrations

- **OctoBus** adds countdowns to supported boat and zeppelin pins. Use `1.3.6-oevg.5-test` or a later build with `GetDockTimer`. The labels work with the OctoBus window hidden. **Docks** counts down to arrival and **Leaves** to departure. A `~` marks an estimate. A `?` means OctoBus has yet to see the route since a known restart. Atlas can display OctoBus estimates without ZepSense.
- **pfQuest** adds lookups for item sources and quest starters or rewards.
- **EquipCompare, EQCompare, or pfUI** can provide equipment comparisons. Use **Use EquipCompare** in Atlas settings.
- **ClassicAPI** supplies a timer scheduler and item cache APIs when available. Atlas also has fallbacks for the stock client.

## Credits

- **CFM and contributors** for [the original Atlas-CFM project](https://github.com/byCFM2/Atlas-CFM).
- **SandreaSub** for [the upstream fork](https://github.com/SandreaSub/Atlas-CFM).
- **Hapto** for [the load-on-demand split and search priority fix](https://octowow.st/git/Hapto/Atlas-CFM).
- **tilr and Heallios** for ModernMapMarkers, and **Otari98** for the item tooltip enhancement idea.
- **Phridgey** for [OctoBus](https://github.com/Phridgey/OctoBus).

See the [license](LICENSE) for distribution terms.
