# QuestTracker - Zone Progress

A vanilla WoW 1.12.1 addon for TurtleWoW that tracks quest completion progress per zone.

## Requirements

- **pfQuest** addon (required for quest database)

## Features

### World Map Hover
- Hover over any zone on the world map to see quest completion progress
- Shows completed/total quests with percentage
- Visual progress bar

### Quest Tracker Window
Open with `/qt` or `/qt show`

**Left Panel - Zone List:**
- All zones with quest progress (completed/total and percentage)
- Click column headers to sort by name or progress
- Click a zone to view its quests

**Right Panel - Quest List:**
- Quests grouped by: Available, Locked, Completed
- Quest level with difficulty coloring (red/orange/yellow/green/gray)
- Quest type indicators:
  - **K** (red) = Kill quest
  - **G** (green) = Gather quest
  - **?** (gray) = Other quest type
- Filter buttons: All | Kill | Gather | Other
- Right-click any quest for detailed info

### Quest Detail Popup
Right-click a quest to see:
- Quest status (Available/Locked/Completed)
- Objectives text
- Quest and minimum level
- Race/class restrictions
- Prerequisites with completion status
- Quest giver NPC with coordinates
- Turn-in NPC with coordinates
- Objective targets with coordinates and mob levels
- Item drop sources with drop rates

### Statistics View
Click the "Statistics" tab in the Quest Tracker window to see:
- Overall quest completion progress with visual progress bar
- Quest type breakdown (Kill/Gather/Other) with completion stats
- Progress by level range (1-10, 11-20, etc.)
- Progress by region (Eastern Kingdoms, Kalimdor, Cities, TurtleWoW)
- Top 10 zones needing work (lowest completion %)
- List of fully completed zones

## Commands

| Command | Description |
|---------|-------------|
| `/qt` | Toggle Quest Tracker window |
| `/qt show` | Open Quest Tracker window |
| `/qt rebuild` | Rebuild quest cache |
| `/qt debug` | Toggle debug mode |
| `/qt audit` | Audit current/hovered zone |
| `/qt export` | Export zone quests to copyable window |
| `/qt inspect <id>` | Show quest details by ID |

## Supported Zones

- All vanilla Eastern Kingdoms and Kalimdor zones
- Capital cities (Stormwind, Ironforge, Orgrimmar, etc.)
- TurtleWoW custom zones (Hyjal, Gilneas, Northwind, etc.)
- TurtleWoW custom cities (Alah'Thalas)

## Notes

- Quests are counted in the zone where they **start**, not where objectives are
- Quest filtering is based on your character's race and class
- Completion tracking uses pfQuest history data
