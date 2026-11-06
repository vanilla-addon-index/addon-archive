# SmartBuff for Turtle WoW

SmartBuff addon optimized for Turtle WoW 1.18. Automatically buffs yourself, party members, raid members, and pets with a single keybind.

## What's New in This Version

This fork includes critical fixes and optimizations for Turtle WoW 1.18:

### Turtle WoW Fixes
- **Fixed negative item counts**: Turtle WoW's `GetContainerItemInfo` API returns negative stack counts, which broke reagent detection. Now handles both negative and positive values correctly.
- **Fixed weapon buff initialization**: Weapon buffs (oils, stones, poisons) are now properly loaded on game startup, not just after `/reload`.

### Buff Improvements
- **Priority-based buffing**: Weapon buffs now apply LAST in the buff sequence, preventing GCD conflicts with other buffs.
- **Smart buff order**: Regular buffs (Mark of the Wild, Thorns, etc.) are applied first, then weapon enchants are applied when nothing else needs casting.
- **Shapeshift support**: Buffs and Weapon buffs now work correctly in Tree of Life form while remaining blocked in Cat/Bear forms.

## Installation

1. Download this repository
2. Extract the `SmartBuff` folder to your `World of Warcraft/Interface/AddOns/` directory
3. Restart the game

## Usage

### Basic or Macro Commands
- `/sb` or `/smartbuff` - Cast buffs on yourself/party/raid
- `/sbm` - Open options menu
- `/sb toggle` - Enable/disable SmartBuff
- `/sb menu` - Show/hide options menu

### Keybinding
Bind a key in the game's keybinding menu under "SmartBuff" for quick access.

## Features

- **All classes supported**: Druid, Mage, Priest, Warlock, Hunter, Shaman, Warrior, Rogue, Paladin
- **Smart buff detection**: Checks what buffs are needed before casting
- **Template system**: Configure different buff sets for Solo, Party, Raid, Battleground, etc.
- **Group buffs**: Supports Gift of the Wild, Arcane Brilliance, Prayer of Fortitude, Prayer of Spirit
- **Class buffs**: All Paladin Greater Blessings
- **Weapon buffs**: Shaman enchants, Rogue poisons, oils, stones, whetstones (with reagent checking)
- **Pet support**: Buffs hunter and warlock pets
- **Rebuff timer**: Set custom timers for when to reapply expiring buffs
- **Buff reminder**: Visual/audio notifications for missing buffs
- **Level-based buffs**: Automatically uses appropriate rank based on target level
- **Tracking abilities**: Supports tracking spells (Find Herbs, Track Humanoids, etc.)

## Configuration

Open the menu with `/sbm` and configure:
- Which buffs to use in each template
- Enable/disable buffs for self, party, or raid
- Set rebuff timers for each buff
- Configure main hand/off hand weapon enchants
- Enable/disable combat casting
- Set up auto-buff on login/rest

## Credits

- **Original Author**: Aeldra (EU-Proudmoore)
- **Turtle WoW Port**: Lexiebean

## Original Repository
Based on [SmartBuff by Azzc0](https://github.com/Azzc0/SmartBuff)
