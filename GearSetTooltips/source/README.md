# GearSetTooltips

A simple addon for World of Warcraft (Vanilla 1.12) that displays which ItemRack and/or Outfitter sets an item belongs to when you hover over items in your bags.

## Features

- Shows set membership on bag item tooltips
- Supports both ItemRack and Outfitter addons
- Automatically updates when you modify your sets
- Displays up to 5 sets per item (with count if more)
- Individual color customization per set
- 8 color presets available (Blue, Light Blue, Green, Yellow, Orange, Red, Purple, White)
- Easy-to-use settings window with dark theme
- Displays each set on its own line with custom colors

## Installation

1. Extract the `GearSetTooltips` folder to your `World of Warcraft\Interface\AddOns\` directory
2. Restart WoW or reload UI (`/reload`)
3. The addon will automatically detect ItemRack and/or Outfitter

## Requirements

- World of Warcraft 1.12.1 (Vanilla)
- At least one of the following addons:
  - ItemRack
  - Outfitter

## Usage

Simply hover over any item in your bags. If the item is part of any gear sets, you'll see a white "Gear Sets:" label followed by the set names, each in their custom color.

Example:
```
Gear Sets:
  PvP (in blue)
  Healing (in green)
  Tank (in red)
```

## Commands

- `/gst` or `/gearsettooltips` - Show available commands
- `/gst options` - Open settings window
- `/gst update` - Manually refresh the set items cache

## Settings Window

Access the settings with `/gst options` to:
- View all detected sets from ItemRack and Outfitter
- Click any set to choose a custom color (8 presets available)
- Detect set changes manually
- Reset all set colors back to default blue
- Modern dark-themed interface
- Press ESC to close

## Notes

- Only shows tooltips for items in bags (not equipped items or other locations)
- Automatically updates when you create, modify, or delete sets
- Ignores ItemRack internal sets (those starting with "ItemRack-" or "Rack-")
- Each set can have its own color for easy visual identification
- "Gear Sets:" label always appears in white
- Settings are saved per character

## Version

1.1

## Changelog

### Version 1.1
- Added graphical settings window with dark theme
- Per-set color customization with 8 color presets
- Each set now displays on its own line in tooltips
- Added "Detect Set Changes" and "Reset All Colors" buttons
- Improved UI with dividers and better spacing
- ESC key closes all windows
- Changed command from `/ist` to `/gst`

### Version 1.0
- Initial release
- Basic tooltip display for ItemRack and Outfitter sets

## Author

Olzon
