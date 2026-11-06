# Forged Pet Happiness

A lightweight Forged WoW addon that improves Hunter pet status tracking through a clean, compact interface.

## Features

- Happiness bar based on in-game `1-3` pet happiness states
  - Green = Happy
  - Yellow = Content
  - Red = Unhappy
  - Gray = No pet / unknown
- Pet feed effect when fed
- Pet XP bar (`current/max`), including max-level display
- Pet info line: level + family (+ custom name when set)
- Loyalty text line
- Training points display (`TP:` label in white, value colorized)
  - Red = negative
  - White = 0
  - Green = positive
- Pet diet icon with tooltip
- Help icon with command tooltip
- Left-click help icon to open the character pet tab
- Draggable frame
- Lock/unlock support
- Show/hide support
- Position persistence per character

## Installation

1. Close WoW.
1. Copy the addon folder to:
   - `World of Warcraft/Interface/AddOns/Forged_PetHappiness`
1. Ensure these files are inside that folder:

- `utils.lua`
- `diet.lua`
- `core.lua`
- `Forged_PetHappiness.toc`
- `README.md` (optional)

1. Start WoW and enable **Forged Pet Happiness** in AddOns at character select.

## Usage

The frame updates automatically based on pet/game events.

Slash commands:

- `/fph lock` — lock frame position
- `/fph unlock` — unlock and allow dragging
- `/fph reset` — reset frame position to default
- `/fph hide` — hide frame
- `/fph show` — show frame (re-centers to default)
- `/fph pet` — open character pet tab

## Vanilla/Forged Limitations

Some values depend on what Forged/Vanilla API returns at runtime.
When data is unavailable, the addon falls back to safe placeholders such as `Unknown` or `N/A`.

## Version

`1.0.3`
