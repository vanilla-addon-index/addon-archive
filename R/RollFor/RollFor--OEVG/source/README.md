# RollFor

[![ClassicAPI](https://img.shields.io/badge/ClassicAPI-Optional-yellow.svg)](https://github.com/brues-code/ClassicAPI)
[![SuperWoW](https://img.shields.io/badge/SuperWoW-Optional-yellow.svg)](https://github.com/balakethelock/SuperWoW)

RollFor manages raid loot, soft reserves, and item rolls. Version **4.8.3** targets OctoWoW / TurtleWoW 1.18.1 on the Vanilla 1.12 client and builds on prodigeomix's RollFor 4.8.2.

## Fork changelog

### 4.8.3 · 2026-11-21

- Fixed minimap clicks on ClassicAPI clients and prevented a minimap drag from toggling a window when released.
- Fixed a main-spec tie-break error that could leave roll rows outside the popup. Older master-looter clients can omit +1 counts, which now default to zero.
- Cached group roster lookups and limited automatic soft-reserve name matching and version broadcasts to changes in group membership.

See the [dated changelog](CHANGELOG.md) for the local changes and inherited release history.

## Features

- Roll for one item or several copies at once, run a raid roll, and handle main-spec, off-spec, and transmog rolls. RollFor ignores extra rolls and prompts tied players to reroll.
- Import soft reserves from Raidres, see reserved items in the loot list, and restrict rolls to the players who reserved them.
- Use automatic Master Loot for bosses and return to Group Loot after looting and rolls finish. The award window groups recipients by class and confirms the award.
- Open the winners window to review awards and raid trades. Click a column header to sort, right-click it to filter, or right-click a roll type to change it.
- Show the roll popup to group members using RollFor when the master looter starts a roll. Set it to `Eligible` or `Always` with `/rf config client show-roll`.

## Installation

Place the `RollFor` folder in `Interface/AddOns` so that `RollFor.toc` is directly inside it. Enable RollFor on the character selection screen, then use `/rfo` in-game to open its options.

ClassicAPI is supported for minimap clicks. SuperWoW enables optional coin auto-looting through `/rf config superwow-auto-loot-coins`.

## Commands

| Command | Action |
| --- | --- |
| `/rf <item link>` | Start a roll for one item. |
| `/rf 2x<item link>` | Roll for two copies. The two highest rolls win. |
| `/arf <item link>` | Let everyone roll even if the item is soft-reserved. |
| `/rr <item link>` | Start a raid roll for an item in your bags. |
| `/irr <item link>` | Run an instant raid roll for an item in your bags. |
| `/fr` / `/cr` | Finish early or cancel the active roll. |
| `/rfw` or Shift-click the minimap button | Open the winners window. |
| `/rfo` or Ctrl-click the minimap button | Open options. |
| `/rf config help` | List configuration commands. |

Use `/roll 99` for off-spec and `/roll 98` for transmog when those rolls are enabled.

### Common options

| Option | Action |
| --- | --- |
| `/rf config auto-master-loot` | Toggle automatic Master Loot when targeting a boss. |
| `/rf config auto-group-loot` | Toggle the return to Group Loot. |
| `/rf config auto-class-announce` | Include class restrictions in roll announcements. |
| `/rf config auto-tmog` | Toggle whether transmog rolls are suppressed for trash loot. |
| `/rf config loot-frame-cursor` | Position the loot frame at the cursor. |
| `/rf config classic-look` | Toggle the classic appearance. Reload to apply it. |

## Soft-reserve setup

1. Create a raid on [Raidres](https://raidres.fly.dev) and ask players to reserve their items.
2. Lock the raid, choose **RollFor export**, and copy the export data.
3. Open `/sr` or left-click the minimap button, paste the data, and choose **Import**.
4. Use `/src` to check reservations and `/srs` to list reserved items. If a player name is still unmatched, use `/sro` to match it manually.

Hover over the minimap button for details. Green means everyone in the group has a reservation, orange means some are missing, red means the import is stale, and white means there is no import. Reimport after changing reservations, or use `/sr init` to clear the data.

## Demos

- [Master Loot and soft-reserve walkthrough](https://youtu.be/f5nY-CxreIM)
- [Classic appearance](https://youtu.be/G37j5XXBKxs)

## Credits

- **Obszczymucha** created the original RollFor addon.
- **sica42** maintained the fork that introduced features such as the winners and options windows. [sica42/RollFor](https://github.com/sica42/RollFor)
- **prodigeomix** maintained the upstream fork used as the 4.8.2 base. [prodigeomix/RollFor](https://github.com/prodigeomix/RollFor)
- **Salahaja** contributed the ClassicAPI minimap click fix. [Salahaja/RollFor](https://github.com/Salahaja/RollFor)
- **Itamedruids** built Raidres and its RollFor export. Thanks to the Turtle WoW team, raiders, testers, and bug reporters.
