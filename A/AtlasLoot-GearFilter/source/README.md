# GearFilter for AtlasLoot TW Edition

A class-based gear filter **module** for [AtlasLoot TW Edition](https://github.com/Turtle-WoW/AtlasLoot-TW-Edition).
Dims items your class cannot equip or does not benefit from, so raid loot tables
stay focused on what matters for the class you pick.

GearFilter is a hard **dependency add-on** — it loads only when AtlasLoot is
installed and enabled, and refuses to initialize without it. It does not
replace AtlasLoot; it extends it without touching any of its files.

Built for **World of Warcraft 1.12 / TurtleWoW**, fully Lua 5.0 compatible.

![GearFilter Screenshot](https://i.imgur.com/xRxazTP.png)

## Features

- **Click-to-filter class row** — a strip of 9 class icons at the top of the
  AtlasLoot window; click a class to dim every item that class cannot use,
  click again to clear.
- **◄ Sub-table page arrows repositioned ►** the previous / next arrows that used
  to sit in the bottom corners of the content area have been moved to the top
  corners, flanking the white sub-table name label.
- **Progression-aware armor visibility** — each class sees its main armor type
  plus every lighter one. Plate users (Warrior, Paladin) see Plate + Mail,
  Mail users (Hunter, Shaman) see Mail + Leather, Leather users (Druid, Rogue)
  see Leather, Cloth users (Priest, Mage, Warlock) see Cloth.
- **Dungeon 1 / Tier 0.5 set whitelist** — 72 set pieces across all 9 classes
  are owner-locked, so Hunters see Beaststalker but not Shadowcraft, Warriors
  see Battlegear of Valor but not Lightforge, and the three cloth caster sets
  (Vestments of the Devout, Magister's Regalia, Dreadmist Raiment) go only to
  their rightful owners.
- **Tooltip stat scan** — primary stats (Str/Agi/Int/Sta/Spirit), spell power,
  healing, attack power, defense, resistances, explicit `Classes:` restrictions
  and `Use:` / `Equip:` proc effects all feed into the filter.
- **Slot-agnostic bypass** — cloaks, rings, necks, trinkets and off-hand
  holdables ignore the armor-class filter, so a Strength cloak is no longer
  hidden for Warriors just because its subtype happens to be "Cloth".
- **Title bar breathing room** — a small 3 px vertical buffer between the
  "AtlasLoot TW Edition" title bar and the row of filter / menu buttons
  underneath.
- **Non-invasive** — no core AtlasLoot files are patched; the addon
  post-hooks `AtlasLootDefaultFrame_OnShow` and `AtlasLoot_ShowItemsFrame`.

## Requirements

- **World of Warcraft 1.12.1** (Interface `11200`) — TurtleWoW or any other
  vanilla 1.12 server
- **AtlasLoot TW Edition** — hard dependency; GearFilter refuses to load
  without it and prints a notice to the default chat frame.

## Installation

### Via the TurtleWoW Launcher (easiest)

Paste the repository URL into the launcher's add-on installer:

```
https://github.com/Kirchlive/AtlasLoot-GearFilter
```

The launcher handles cloning, folder naming and deployment. Make sure
**AtlasLoot TW Edition** is installed too — GearFilter refuses to load
without it.

### Manual installation

1. Download the latest release ZIP from the
   [Releases page](https://github.com/Kirchlive/AtlasLoot-GearFilter/releases)
   or clone the repository directly.
2. Rename the extracted folder to exactly **`AtlasLoot-GearFilter`** (GitHub's
   ZIP download creates a folder suffixed like `AtlasLoot-GearFilter-main`
   that you need to strip).
3. Place the folder inside your `World of Warcraft\Interface\AddOns\`
   directory so the final path is
   `Interface\AddOns\AtlasLoot-GearFilter\AtlasLoot-GearFilter.toc`.
4. Make sure **AtlasLoot TW Edition** is installed in the same `AddOns\`
   directory.
5. Fully restart your WoW client (not just `/reload`) so the new `.toc` is
   picked up.
6. Log in. A row of 9 class icons should appear at the top of the AtlasLoot
   browser the first time you open it.

> **Upgrading from an earlier `AtlasLoot_ClassFilter` install?** Delete the
> old `AtlasLoot_ClassFilter` folder from `Interface\AddOns\` before copying
> the new one in. The addon automatically migrates your previously selected
> class from the old SavedVariables on first launch, so your filter choice
> is preserved.

## Usage

1. Open AtlasLoot the normal way (minimap button, `/atlasloot`, or the
   Atlas integration).
2. Click any of the 9 class icons at the top of the window to filter the
   current loot table for that class.
3. Click the same icon again to clear the filter and show every item at full
   alpha.
4. Your last selection persists across sessions (per character, via
   `SavedVariablesPerCharacter`).

The currently selected class is highlighted at full alpha while the other
eight icons dim slightly so you can tell at a glance which filter is active.

## Dependency

The dependency on AtlasLoot is declared in the `.toc` file:

```
## Dependencies: AtlasLoot
```

WoW's addon loader guarantees that AtlasLoot is loaded **before** GearFilter.
GearFilter also performs a defensive runtime check for
`AtlasLootDefaultFrame_OnShow` during bootstrap — if that global is missing
(because AtlasLoot failed to load or was disabled), GearFilter prints

```
[AtlasLoot-GearFilter] AtlasLoot not found, filter disabled.
```

and exits without hooking anything. Installing or enabling AtlasLoot and
re-logging restores full functionality.

## Lua 5.0 / WoW 1.12 notes

The code follows vanilla Lua 5.0 constraints strictly:

- `this` in event handlers and `OnClick` scripts, never `self`
- `table.getn(t)` instead of `#t`
- `string.find` (no `string.match`)
- `math.mod(a, b)` instead of `a % b`
- No hex literals, no Unicode in source files, no `C_*` namespaces
- `SetPoint` always with an explicit parent

Safe to drop into any vanilla 1.12 or TurtleWoW client.

## License

See the repository for license information.
