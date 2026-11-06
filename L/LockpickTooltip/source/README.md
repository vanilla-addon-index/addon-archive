# LockpickTooltip
### World of Warcraft 1.12.1 (Vanilla) Addon — v1.2.0 Stable

Adds a line to item and world-object tooltips showing the required Lockpicking skill, colour-coded based on whether you can pick it or not.

---

## Features

- Works on **bag items** (lockboxes, junkboxes)
- Works on **world objects** (chests, doors, footlockers)
- Works in **loot windows**, **merchant windows**, **chat item links**, and **quest windows**
- Only shows on locked objects — unlocked chests are ignored
- Zone-aware skill requirements for footlockers with multiple variants (Battered, Waterlogged, Mossy, Dented)
- Uses the game's own "Locked" text colour to determine which variant a footlocker is when multiple exist in a zone
- Two colour modes selectable via `/lpt color`:
  - **Simple** (default): Green = Pickable, Red = Skill Level Too Low
  - **Match**: mirrors the colour of the game's own "Locked" text (red, orange, yellow, green, or grey)
- Setting is saved between sessions

---

## Installation

1. Copy the `LockpickTooltip` folder into:
   ```
   World of Warcraft/Interface/AddOns/
   ```
2. Launch WoW and make sure **LockpickTooltip** is enabled in the AddOns list at the character select screen.

---

## Slash Commands

| Command | Description |
|---|---|
| `/lpt` | Show help |
| `/lpt items` | List all known lockbox items and their requirements |
| `/lpt objects` | List all known lockable world objects and their requirements |
| `/lpt color` | Toggle between Simple and Match colour modes |

---

## Covered Content

**Lockbox Items**
- All junkboxes: Battered, Worn, Sturdy, Heavy
- Crafted lockboxes: Ornate Bronze, Heavy Bronze, Iron, Strong Iron, Steel, Reinforced Steel, Mithril, Thorium, Eternium
- Gnomish Lock Box

**World Objects**
- Rogue training boxes: Buccaneer's Strongbox, Practice Lockbox
- Footlockers with zone-aware requirements: Battered, Waterlogged, Mossy, Dented, Scarlet
- Outdoor chests across all Classic zones
- Dungeon chests: Shadowfang Keep, Gnomeregan, Scarlet Monastery, Uldaman, Zul'Farrak, Maraudon, Sunken Temple, Blackrock Depths, Blackrock Spire, Dire Maul, Scholomance, Stratholme
- Lockable doors: Deadmines, Gnomeregan, SM Armory, SM Cathedral, Searing Gorge Gate, Blackrock Depths, Dire Maul (Crescent Door, Gordok Inner Door, Hidden Reach Door), Scholomance, Stratholme Service Entrance

---

## Version History

**1.2.0** — Stable. Full zone-aware footlocker coverage (Battered, Waterlogged, Mossy, Dented, Scarlet). Multi-variant footlockers use the game's Locked text colour to identify which variant is present. Added colour mode toggle (/lpt color) saved between sessions. All dungeon door requirements corrected. Added Deadmines and Dire Maul doors.

**1.1.0** — Zone-aware skill requirements for Battered Footlocker. Corrected all item IDs against wowhead.com/classic. Tooltip now shows Pickable/Skill Level Too Low in green/red.

**1.0.0** — Initial stable release. Full coverage of vanilla lockboxes, junkboxes, and dungeon/outdoor chests.

---

## Known Limitations

- Item and world object coverage is still being tested — some entries may have incorrect skill requirements or missing entries.
- OctoWoW-specific lockable items and objects have not yet been added and will be included in a future update.
