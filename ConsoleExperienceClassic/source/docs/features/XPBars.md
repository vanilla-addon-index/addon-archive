# XP and Reputation Bars

Custom progress bars showing experience and reputation progress.

## Overview

Two separate bars display below the chat frame:
- **XP Bar**: Shows current experience progress
- **Reputation Bar**: Shows watched faction reputation

## XP Bar

### Display Modes
- **Always Visible**: Bar stays on screen
- **Fade Out**: Bar fades after gaining XP (configurable timeout)

### Colors
- **Purple**: Not rested (normal XP gain)
- **Blue**: Rested (bonus XP available)

### Rested Indicator
When you have rested XP, a lighter section of the bar shows your potential bonus XP range.

### Information Shown
- Current XP / Max XP
- Percentage complete
- Rested status (if applicable)

### Tooltip
Hover over the XP bar to see:
- Detailed XP numbers
- Rested XP amount
- XP gained this session
- Average XP per hour
- Estimated time to level

## Reputation Bar

### Display
Shows your currently watched faction's standing.

### Colors
The bar color changes based on standing:
- Hated (Red)
- Hostile (Orange)
- Unfriendly (Yellow)
- Neutral (Gray)
- Friendly (Green)
- Honored (Light Green)
- Revered (Blue)
- Exalted (Purple)

### Information Shown
- Faction name
- Current standing
- Progress to next standing

## Configuration

### XP Bar Settings
| Setting | Description | Default |
|---------|-------------|---------|
| Always Visible | Keep bar on screen | On |
| Width | Bar width (0 = chat width) | 0 |
| Height | Bar height | 20 |
| Timeout | Fade delay in seconds | 5.0 |
| Show Text | Display text on bar | On |

### Rep Bar Settings
| Setting | Description | Default |
|---------|-------------|---------|
| Always Visible | Keep bar on screen | Off |
| Width | Bar width (0 = chat width) | 0 |
| Height | Bar height | 20 |
| Timeout | Fade delay in seconds | 5.0 |
| Show Text | Display text on bar | On |

## Position

Bars appear below the chat frame:
1. Rep Bar (bottom, if visible)
2. XP Bar (above rep bar)
3. Chat Frame (above XP bar)

The chat frame automatically adjusts position based on which bars are visible.
