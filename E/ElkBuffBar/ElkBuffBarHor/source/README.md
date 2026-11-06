# ElkBuffBar — TurtleWoW Enhanced Edition

<img src="https://i.imgur.com/e7H2Xsk.png">

A heavily updated version of [ElkBuffBarHor](https://github.com/gimerstedt/ElkBuffBarHor), tailored for **TurtleWoW** (Vanilla 1.12.1 private server).

Elkano's BuffBar displays your buffs and debuffs as colored status bars, sorted by category. This fork expands the buff database significantly and reorganizes consumable categories for better raid readability.

## What's Changed

### Consumable Sub-Categories (ElkBuffData.lua)
The old mega-category `[80]` for all consumables has been split into **14 granular sub-categories** `[60]`–`[73]`, sorted by duration:

| Cat | Duration | Contents |
|-----|----------|----------|
| `[60]` | 2h (persist) | Flasks |
| `[61]` | 2h | Zanza |
| `[62]` | 1h | Offensive Elixirs (Frost/Fire/Shadow/Arcane Power) |
| `[63]` | 1h | Defensive/Stat Elixirs (Mongoose, Giants, Brute Force) |
| `[64]` | 1h | Blasted Lands buffs |
| `[65]` | 1h | Utility Defense (Fortitude) |
| `[66]` | 1h | Utility Mana (Mageblood) |
| `[67]` | 1h | Misc Utility (Gift of Arthas) |
| `[68]` | 30–60min | TurtleWoW Elixirs (Dreamshard, Concoctions) |
| `[69]` | 20min | Juju, Winterfall Firewater |
| `[70]` | 20min | TurtleWoW custom (Dreamtonic) |
| `[71]` | 15min | Drinks/Alcohol (Rumsey, Medivh's Merlot) |
| `[72]` | 15min | Food (Well Fed, Dragonbreath Chili) |
| `[73]` | <5min | On-use (Free Action, Noggenfogger, potions) |

All consumable sub-categories share the same dark blue color — they're visually grouped but spatially sorted by duration (longest right, shortest left).

### Burning Wish Fix (ElkBuffBar.lua)
- **Bug:** `untilCancelled == 1` set `colorAlpha = 0` for ALL buffs without duration, hiding category colors for things like Burning Wish (Warlock)
- **Fix:** Only `[0]` Auras (mounts, passives) get transparent bars. All other categories show their color even when untilCancelled.

### Class Auras Moved to Class Categories
Paladin auras, Hunter aspects, Druid forms, Warlock Blood Pact, and other class-specific "permanent" buffs have been moved from `[0]` (invisible) to their respective class categories `[21]`–`[29]`. They now show in class colors instead of being hidden.

### Expanded Buff Database (~390 entries, up from ~350)
New entries include:
- **TurtleWoW custom:** Daybreak, Resist Fire, Dreamshard Elixir, Dreamtonic, Concoctions
- **Warlock:** Voidstone, Spellstone, Wrathstone, Firestone, Felstone, Fire Shield, Burning Wish
- **Paladin:** Blessing/Greater Blessing of Sanctuary, Seal of Command, Daybreak
- **Druid:** Omen of Clarity, Emerald Blessing, Barkskin, Aquatic/Cat Form
- **Consumables:** Medivh's Merlot, Greater Frost/Arcane/Nature Power, Gift of Arthas, Dragonbreath Chili, Chromatic Resistance
- **Protection:** Holy Protection
- **On-use:** Restoration, Stoneshield, Lesser Invisibility, Potion of Quickness, Lucidity Potion
- **World Buffs:** Warchief's Blessing, Songflower Serenade, Power of the Guardian (Atiesh)
- **Scrolls:** Moved to own category `[55]`

### Other Changes
- Removed unused `[1]` (Flask) and `[60]` (Elixir) legacy categories from the original
- Scrolls moved from `[70]` to `[55]` for better spatial ordering
- Trinket list expanded with many raid trinkets (Naxx, AQ, ZG)
- Class categories enriched with abilities and talent procs

## Installation

1. Download or clone this repo
2. Copy the `ElkBuffBar` folder into `World of Warcraft/Interface/AddOns/`
3. `/ebb` or `/elkbuffbar` in-game for settings

## Credits

- **Elkano** — Original ElkBuffBar addon (2006)
- **Boldilocks (Warsong, Feenix)** — Horizontal version & category system ([ElkBuffBarHor](https://github.com/gimerstedt/ElkBuffBarHor))
- **Kirchlive** — TurtleWoW Enhanced Edition (this fork)

## License

Same as the original — free to use and modify. Keep credits intact.
