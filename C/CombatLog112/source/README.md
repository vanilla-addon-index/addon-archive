# Combat Log 112

A standalone, resizable combat log window for **WoW 1.12 / Turtle WoW (Octo WoW)**, styled to match **pfUI**.
It reads damage events from **Nampower**, so it also catches damage that the default chat log can miss
(for example some poison and arrow damage).

## Features

- Flat pfUI-style window (uses pfUI's colors and font when pfUI is loaded, a dark flat look otherwise)
- Resizable (drag the grip in either bottom corner) and movable (drag anywhere); size and position are saved
- White text, mouse-wheel and scrollbar support, auto-follows new lines until you scroll up
- Header buttons to filter what is shown (click to cycle):
  - **Source:** Me (you + pet) / Party / Raid
  - **Direction:** Both / Incoming / Outgoing
  - **Distance:** 40 / 80 / Max (yards, Max = no limit)
- Search box in the header: type words to show only matching lines, `-word` hides lines with that word
- Readable lines: unit names, spell names, damage school, crit, periodic ticks, absorb/block/resist amounts
- Melee misses, dodges, parries, blocks and spell misses are shown by type
- Healing: heals you cast and heals you receive (and for Party/Raid scope, the whole group), with crit and periodic marks
- Starts hidden on every login; open it with `/clog`

## Requirements

| Addon / mod | Needed | Used for |
|---|---|---|
| **Nampower** | Required | Damage, melee and miss events |
| **SuperWoW** | Recommended | Resolving names of NPCs you are not targeting |
| **UnitXP_SP3** | Optional | Distance filter (40 / 80) |
| **pfUI** | Optional | Theme colors and font |

Without SuperWoW, units that are not you, your group or your target may show as `Unit:1A2B`.
Without UnitXP, the distance filter cannot work and all events are shown.

## Installation

1. Create the folder `Interface/AddOns/CombatLog112/`
2. Put these files in it:
   - `CombatLog112.lua`
   - `CombatLog112.toc`
3. Start the game (or `/reload`) and type `/clog` to open the window.

## Usage

Example line:

```
[03:03:10] IN  Stormwind Guard -> Yourname: Shoot 81 [Physical]
[03:03:12] OUT  Yourname -> Defias Thug: Shadow Bolt 215 CRIT [Shadow]
```

`IN` means the unit of your chosen group was hit, `OUT` means it dealt the damage.

### Commands

`/clog` and `/combatlog112` are the same command.

| Command | Description |
|---|---|
| `/clog` | Show or hide the window |
| `/clog show` / `/clog hide` | Show or hide explicitly |
| `/clog clear` | Clear the log |
| `/clog find <words>` | Same as the search box. Empty = off |
| `/clog reset` | Reset window position and size, and show it |
| `/clog scope me\|party\|raid` | Choose whose combat is shown |
| `/clog dir in\|out\|both` | Incoming, outgoing or both |
| `/clog dist <yards>\|max` | Distance limit, for example `/clog dist 60` |
| `/clog heal on\|off` | Show or hide healing lines |
| `/clog font <8-24>` | Text size |
| `/clog lines <20-5000>` | How many lines are kept (default 300) |
| `/clog help` | List commands |

### Search

Type in the box in the header. It works on lines already in the log and on new ones, and it is not saved between sessions.

- Several words must all appear, in any order: `shadow bolt`
- A word with `-` in front hides matching lines: `-melee` removes auto-attacks, `mind -melee` combines both
- Matching ignores upper/lower case and looks at the whole line (names, spell, school, `CRIT`, `IN`/`OUT`, `periodic`)
- While the box is focused the keyboard goes to it, so movement keys will not work. Press **Enter** to leave the box, **Esc** to clear the text (Esc again leaves it).

Example for testing a single ability: `ambush` or `ambush out`.

### Filters

- Filters apply to **new** lines only. Existing lines stay as they are.
- Default is **Me / Both / Max**, so fights around you in a city are not shown unless you widen the source.
- **Party** only covers party members. In a raid, use **Raid**.
- **Distance** is measured from you to the other unit in the fight. If the distance cannot be read,
  the log shows everything and prints a note once.

### Healing

Heal lines end with `[Heal]` and use the same Source and Direction buttons as damage:

```
[11:02:41] OUT  Yourname -> Tankname: Flash Heal +1450 CRIT [Heal]
[11:02:44] IN  Healername -> Yourname: Renew +120 (periodic) [Heal]
```

- **Outgoing** = a unit of the chosen group healed someone. **Incoming** = a unit of the chosen group was healed.
- To see only healing, search `heal`. To hide it, search `-heal` or use `/clog heal off`.
- Nampower only sends heal events when the CVar `NP_EnableSpellHealEvents` is on. The addon switches it on at login
  (and `NP_EnableAutoAttackEvents` for melee). These are saved in your game config, so they stay on afterwards.
- Overheal is not available from Nampower, so the amount is the full heal value.

## Saved settings

Stored in `CombatLog112DB` (SavedVariables): size, position, font size, line limit, healing on/off, and the three filters.

## Troubleshooting

| Problem | Fix |
|---|---|
| Nothing is logged | Check that Nampower is installed and loaded. The log prints a warning at login if it is not found. |
| No healing lines | `/clog heal on`. Check that the log did not print a warning about `NP_EnableSpellHealEvents` at login (needs a Nampower version with heal events). Source must include the healer or the target, for example Me, Party or Raid. |
| Names look like `Unit:1A2B` | Install or enable SuperWoW. Targeting or mousing over a unit also lets the log learn its name. |
| Distance filter has no effect | UnitXP_SP3 is missing, or it does not accept GUIDs. Use `Max`. |
| Window is off-screen | `/clog reset` |
| Window is covered by other UI | It uses the HIGH frame strata; move it or resize it. |
| Resize does not grab | Click directly on the corner icon (24x24 area) in either bottom corner and hold while dragging. |
| Crit marks look wrong | Spell crits use hit info bit 2, melee crits use bit 128. Please report the case if it is wrong. |

## Notes

- Written for Lua 5.0 as used by the 1.12 client.
- The chat-log fallback is intentionally not used for damage totals.
