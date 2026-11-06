# SP_Revenge

Warrior addon for Turtle WoW that alerts you when Revenge is available and shows a countdown timer.

## Installation

1. Download the addon
2. Extract to your `World of Warcraft\Interface\AddOns\` folder
3. Ensure the folder is named `SP_Revenge` and contains:
   - `SP_Revenge.toc`
   - `SP_Revenge.xml`
   - `SP_Revenge.lua`
4. Restart WoW or type `/reload` if already in-game

## How It Works

When you **block**, **dodge**, or **parry** an attack while in Defensive Stance, the Revenge ability becomes usable for 4 seconds. This addon:

1. Detects when you block, dodge, or parry any attack (from creatures or players)
2. Displays a timer bar showing the remaining time to use Revenge
3. Accounts for Revenge's cooldown - the red bar shows actual usable time
4. Optionally plays a sound alert
5. Automatically hides when you use Revenge or the window expires

**Timer Bar:**
- **Yellow bar** - Total 4-second proc window
- **Red bar** - Time you can actually use Revenge (accounts for cooldown)

## Usage

### Slash Commands

Use `/rev` or `/revenge` to configure the addon.

### Settings

| Command | Description | Default |
|---------|-------------|---------|
| `/rev x <value>` | Bar X position | 0 |
| `/rev y <value>` | Bar Y position | -161 |
| `/rev w <value>` | Bar width | 200 |
| `/rev h <value>` | Bar height | 13 |
| `/rev b <value>` | Border height | 0 |
| `/rev a <value>` | Alpha (0-1) | 1 |
| `/rev s <value>` | Scale | 1 |
| `/rev sound <on/off>` | Sound alert | off |
| `/rev reset` | Reset to defaults | - |

Running `/rev` with no arguments displays all current settings.

## Credits

Based on SP_Overpower by EinBaum (https://github.com/EinBaum)
