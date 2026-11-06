# Better Everlook Broadcasting Co

An improved replacement for TurtleWow's built-in Everlook Broadcasting Co radio addon.

## Features

- **Minimap orbit button** — the radio icon sits on the minimap edge and can be dragged around it (Ctrl+drag). Ctrl+right-click resets to default position.
- **Redesigned radio window** — larger, cleaner layout with a proper title bar, close button, and well-spaced controls.
- **Movable window** — drag the title bar to reposition the radio window anywhere on screen.
- **Escape to close** — press Escape to dismiss the radio window, like any standard WoW panel.
- **Slash commands** — `/radio` or `/ebc` to toggle the window.
- **Persistent settings** — station selection, minimap button angle, window position, and open/close state are all saved across sessions via SavedVariables.
- **Overrides the built-in** — automatically hides the original TurtleWow radio UI so there's no duplicate.

## Installation

1. Download or clone this repository into your TurtleWow AddOns folder:
   ```
   TurtleWow/Interface/AddOns/BetterEverlookBroadcastingCo/
   ```
2. Restart the game (a `/reload` is not sufficient on first install since the TOC must be read at launch).

## Usage

| Action | Effect |
|---|---|
| Left-click minimap button | Toggle radio window |
| Ctrl+drag minimap button | Move button around minimap edge |
| Ctrl+right-click minimap button | Reset button to default position |
| Drag window title bar | Move the radio window |
| Click X / press Escape | Close the radio window |
| `/radio` or `/ebc` | Toggle the radio window |

## Saved Settings

All settings are stored in `BetterEBC_Settings` and persist across `/reload` and relogs:

- Minimap button angle
- Radio window position
- Selected station
- Window open/closed state
