# Cast Bar

Custom casting bar that appears above the chat frame.

## Overview

The cast bar replaces the default WoW casting bar with a custom version that:
- Matches the visual style of XP/Rep bars
- Positions above the chat frame
- Shows spell name and cast time
- Includes a spark indicator for progress

## Features

### Display Elements
- **Progress Bar**: Fills as the spell casts
- **Spell Name**: Shows what you're casting (centered)
- **Timer**: Shows remaining cast time (right side)
- **Spark**: Glowing indicator at the progress point

### Spell Types
- **Casting**: Bar fills from left to right
- **Channeling**: Bar drains from right to left

## Configuration

| Setting | Description | Default |
|---------|-------------|---------|
| Enable Cast Bar | Show custom cast bar | On |
| Height | Bar height in pixels | 20 |
| Color | Cast bar color | Blue |

Access these settings in the "Cast Bar" section of the config (`/ce`).

## Position

The cast bar appears:
- Centered horizontally
- Above the chat frame
- Same width as the chat frame

Position adjusts automatically based on:
- Chat frame position
- XP/Rep bar visibility

## Color Customization

Click the color button in config to open the color picker:
1. Select your desired color
2. The cast bar updates immediately
3. Color applies to both casting and channeling

## Blizzard Cast Bar

When the custom cast bar is enabled:
- The default Blizzard cast bar is hidden
- Disable the custom cast bar to restore the default

## Tips

- The cast bar only appears while casting
- Works with all spells and abilities
- Timer helps you track cast completion
- Great for timing spell interrupts on your target
