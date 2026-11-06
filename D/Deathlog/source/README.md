# Deathlog for Vanilla WoW

A death heatmap addon for Vanilla WoW (1.12) that displays player death locations on the world map, helping you identify dangerous areas.

![Heatmap Example 1](https://i.imgur.com/EtdfDCD.png)

## Features

- **Death Heatmap Overlay**: Visual heat map showing death density on the world map
- **Real-time Danger Indicator**: Color-coded indicator showing current location danger level
- **High Resolution**: 100x100 grid with Gaussian blur for smooth visualization
- **96,000+ Death Records**: Comprehensive death data from WoW Classic
- **Movable UI**: Shift + Left-click to reposition the danger indicator

![Heatmap Example 2](https://i.imgur.com/nLRLom0.png)

## Installation

1. Download or clone this repository
2. Copy the `Deathlog_Vanilla` folder to your `WoW/Interface/AddOns/` directory
3. Restart WoW or type `/reload`

```
└── Interface/
└── AddOns/
└── Deathlog_Vanilla/
```

Or just with with Launcher or Addon-Manager.

## Usage

### Slash Commands

| Command | Description |
|---------|-------------|
| `/deathlog` or `/dl` | Show current settings and command list |
| `/dl indicator` | Toggle danger indicator on/off |
| `/dl heatmap` | Toggle heatmap overlay on/off |
| `/dl warning` | Toggle chat warnings on/off |
| `/dl reset` | Reset indicator position to default |

All settings are automatically saved when you exit WoW.

### Danger Indicator Colors

| Color | Danger Level |
|-------|--------------|
| Green | Safe |
| Yellow | Caution |
| Orange | Dangerous |
| Red | VERY DANGEROUS |

### Controls

- **Shift + Left Mouse**: Drag to move the danger indicator
- **Open World Map**: Heatmap overlay appears automatically

## Screenshots

### Heatmap on World Map
The heatmap shows death density with a color gradient from yellow (few deaths) to red (many deaths). The overlapping grid creates a fine mesh pattern for better visibility.

### Danger Indicator
A small colored box at the top of your screen indicates the danger level of your current location in real-time.

## Data

This addon includes death data from approximately **96,000 player deaths** across all Vanilla WoW zones, including:

- All Eastern Kingdoms zones
- All Kalimdor zones
- Major dungeons (Deadmines, Wailing Caverns, Shadowfang Keep, etc.)
- Turtle Zones will be following

## Technical Details

- **Grid Resolution**: 100x100 cells per zone
- **Smoothing**: Gaussian blur (3x3 kernel) for smooth transitions
- **Color Calculation**: Dynamic intensity-based coloring
- **Compatible**: WoW 1.12.x (Vanilla)

## Changelog

### Version 1.1
- Improved danger indicator thresholds to match heatmap colors
- Unified command system (`/dl` with subcommands)
- Added warning toggle (`/dl warning`)
- All settings now saved between sessions
- Fixed heatmap disappearing on subzone changes

### Version 1.0
- Initial release
- 100x100 high-resolution heatmap grid
- Gaussian blur smoothing
- Real-time danger indicator
- Movable indicator (Shift + drag)
- 50 zones with death data
- ~96,000 death records

## Credits

This addon is a port/conversion from foundation and data of the projects:

### [Deathlog by aaronma37](https://github.com/aaronma37/Deathlog)
The original Deathlog addon for WoW Classic (1.13+). Adapted data and rendering.

### [RipMap by DaniilSokolyuk](https://github.com/DaniilSokolyuk/RipMap)
Foundation for the 1.12 compatible implementation.

## License

This project is provided as-is for educational and entertainment purposes.
Original projects are under their respective licenses (GPL-3.0 for Deathlog).
