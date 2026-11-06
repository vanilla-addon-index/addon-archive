# TotemTimers 3.6

## A lightweight totem bar for Turtle WoW shamans

TotemTimers is a polished Turtle WoW addon that gives shamans a fast, readable totem bar with timers, flyout selection, layout controls, Totemic Recall support, and a smarter twist warning helper.

---

## Highlights

- Always-visible totem buttons for the elements you actually know
- Left-click to cast your selected/default totem
- Hover to open a flyout of learned alternatives
- Click a flyout spell to cast it and make it the new default
- Right-click a button to clear that element's active timer
- Dedicated Totemic Recall button when the spell is known
- Larger timer text with a cleaner bottom timer strip
- Urgency colors and glow effects as a totem nears expiration
- Smarter twist helper focused on likely Air/Fire twist targets
- Adjustable addon scale
- Compact and vertical layout modes
- Drag-and-drop positioning while unlocked
- Per-character saved settings
- Built for Turtle WoW / Vanilla 1.12

---

## What It Does

Each element button represents your selected totem for that school:

- If a totem is active, the button shows its icon, timer, and timer strip
- If no totem is active, the button still shows your selected/default spell
- Elements with no learned totems are hidden automatically
- Hovering a button opens a flyout menu with other learned totems for that element
- If Totemic Recall is known, a Recall button is added to the bar
- If you die, active totem timers are cleared so the bar stays in sync

---

## Controls

- Left-click: Cast the selected/default totem for that element
- Hover: Show the flyout of learned totems for that element
- Click flyout spell: Cast it and make it the new default
- Right-click: Clear that element's active timer
- Recall button: Cast Totemic Recall when known
- Drag while unlocked: Move the bar anywhere on screen

---

## Commands

| Command | What it does |
|---------|---------------|
| `/tt lock` | Toggle lock/unlock so the bar can be moved |
| `/tt compact` | Toggle compact button sizing |
| `/tt vertical` | Toggle vertical bar layout |
| `/tt scale 0.8` | Set addon scale from `0.5` to `1.5` |
| `/tt twist 8` | Set twist warning threshold from `1` to `30` seconds |
| `/tt reset` | Reset position, scale, and twist warning to defaults |
| `/tt test` | Start a test timer |

---

## Twist Helper

The twist helper text appears below the anchor and warns you when a likely Air or Fire twist target is getting close to expiring.

- Default warning threshold: `10` seconds
- Adjustable with `/tt twist <seconds>`
- Prioritizes common twist candidates such as Windfury Totem and Grace of Air Totem

---

## Installation

1. Clone or download this repository.
2. Place the `TotemTimers` folder in your World of Warcraft `AddOns` directory.
   - `World of Warcraft\Interface\AddOns\`
3. Make sure the folder name is exactly `TotemTimers`.
4. Restart World of Warcraft or reload the UI with `/reload`.

---

## Usage

Once installed:

1. Log into a shaman.
2. Use the bar buttons to cast your selected totems quickly.
3. Hover each element to pick a different default totem.
4. Use Recall to clear all active totems when needed.
5. Unlock and drag the bar wherever you want it.
6. Adjust layout with compact, vertical, scale, or twist commands.

---

## Features In Detail

### Timer Feedback

- Countdown text for active totems
- Subtle bottom timer strip instead of a large dark overlay
- Urgency colors and glow when a totem is close to expiring
- Global cooldown overlay refresh on casts

### Flexible Layout

- Horizontal or vertical layout
- Compact mode for a smaller footprint
- Scalable bar size with `/tt scale`
- Per-character saved position and layout settings
- Optional Recall button integrated into the same layout flow

### Quick Selection

- Flyout menu per element
- Improved flyout spacing and selected-state visuals
- Selected spell is remembered per element
- Hover tooltips show the selected spell, active spell, and remaining time

---

## Files

- `TotemTimers_Core.lua` - Core event handling, spell tracking, timer state, and recall logic
- `TotemTimers_UI.lua` - Button creation, flyout menus, tooltips, and timer visuals
- `TotemTimers_Init.lua` - UI initialization
- `TotemTimers_Config.lua` - Slash command handling
- `TotemTimers_Layout.lua` - Anchor handling, layout logic, and twist helper
- `TotemTimers_Advanced.lua` - GCD overlay and advanced visual effects
- `TotemTimers.toc` - Addon table of contents file

---

## Requirements

- Turtle WoW
- World of Warcraft client `1.12.x`
- Shaman character

---

## Credits

- Original TotemTimers authors
- Turtle WoW community
- Modern Turtle-compatible rewrite and polish by Greg Deichler

---

## License

This project is open source and available under the MIT License. See [LICENSE](LICENSE).
