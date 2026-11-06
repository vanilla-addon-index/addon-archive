# ShaguDPS

[![ClassicAPI](https://img.shields.io/badge/ClassicAPI-Optional-yellow.svg)](https://github.com/brues-code/ClassicAPI)
[![Nampower](https://img.shields.io/badge/Nampower-Optional-yellow.svg)](https://github.com/brues-code/nampower)
[![SuperWoW](https://img.shields.io/badge/SuperWoW-Optional-yellow.svg)](https://github.com/balakethelock/SuperWoW)

A very small and lightweight damage, healing, threat and dispel meter for WoW 1.18.1
clients (Interface 11200, Lua 5.0).

It reads structured combat events from **ClassicAPI** or **Nampower** when one is loaded
and falls back to parsing the chat combat log on a plain client.

Based on [ShaguDPS](https://github.com/shagu/ShaguDPS) by Shagu and the Nampower parser
from [Duciel's fork](https://github.com/Duciel/ShaguDPS). See the [changelog](CHANGELOG.md)
for what changed in each version.

## Contents

- [Installation](#installation)
- [Features](#features)
- [Data sources](#data-sources)
- [Commands](#commands)
- [Combat log range](#combat-log-range)
- [Diagnostics](#diagnostics)
- [Notes](#notes)

## Installation

1. Download the latest version and unpack it.
2. Make sure the folder is named `ShaguDPS` (not `ShaguDPS-master`).
3. Copy `ShaguDPS` into `Wow-Directory\Interface\AddOns`.
4. Restart the game (a reload is not enough when a new texture file was added).

When updating, back up the addon and your SavedVariables first. Settings and boss
history carry over.

Optional client mods: [ClassicAPI](https://github.com/brues-code/ClassicAPI),
[Nampower](https://github.com/brues-code/nampower) and [SuperWoW](https://github.com/balakethelock/SuperWoW).
None of them is required; ClassicAPI is needed for Dispels mode.

## Features

### Modes

Pick the mode from the title menu of each window; every window can show a different one.

| Mode | Shows |
|------|-------|
| Damage | Total damage, DPS and share on one bar: `37K (2388 DPS) [62.1%]` |
| Heal | Effective healing, HPS and share, with overhealing as the lighter bar behind: `1500 (97 HPS) [100%]` |
| Threat | The threat list of your current target, from the server's threat API |
| Dispels | Successful removals, done or received (choose per window) |

Large numbers are shortened (`37K`, `1.23M`). Chat reports use the same format, add the
overhealing to heal lines and name the boss, kill or wipe and the fight length for saved fights.

### Segments and boss fight history

The segment menu reads *Current*, *Fights* and *Overall*.

- *Fights* opens the last 10 boss fights, newest first, with their length. Wipes are greyed out.
- A fight counts as a boss fight when someone in the group targeted a raid boss
  (boss classification or skull level) while it ran. Trash fights are not kept.
- The history is saved per character and survives reloads and logouts. A raid boss fight
  takes roughly 50 KB, so ten of them stay under 1 MB. *Reset Data* clears it.
- With ClassicAPI, boss deaths are detected by GUID; otherwise the chat death message is used.

### Threat

- Shows each player's threat and percent of their pull threshold, with a red *Pull Aggro*
  line where you would take aggro: 110% of the tank's threat in melee range, 130% at range.
  The server shows the aggro holder at 100%. Hover a bar to see who has aggro.
- TPS is a rolling five-second average. Switching targets requests fresh data immediately.
- Asks the server twice a second, only while a window shows threat, you are in a group and
  your target is an elite or boss in combat. If TWThreat is also running, ShaguDPS reads
  its answers instead of asking a second time.
- Old bars clear when the target dies, combat ends, you leave the group, or no reply
  arrives for three seconds.
- If you are missing from the reply, the threshold shows a raw-threat range of 110% to 130%
  of the tank's threat until your range is known.
- Replies to older requests are discarded using the target GUID (or name) and a switch
  generation. The server payload has no request ID, so attribution relies on reply order
  with a short expiry and can't be guaranteed if replies are lost, reordered, or supplied
  by another addon.

### Dispels

Select *Dispels* in the mode menu, then open the menu again to choose *Done* or *Received*.
Bars show successful removals and share; tooltips list the top ten removed auras and the
players involved, and the dispelling abilities when ClassicAPI supplies them.

- Curse, disease, poison and magic removals all count, including offensive magic dispels.
  Each aura removed counts once, so one cast that removes several auras can count more than once.
- Failed attempts and casts alone do not count.
- Only aggregate counts are kept, not timestamps. Fights saved before 4.6 have no dispel data
  and say so instead of showing zero.
- Recording needs ClassicAPI with `COMBAT_LOG_EVENT_UNFILTERED` and works independently of
  the selected damage source. Aura-driven dispels and casts the client didn't see show an
  unknown ability.

### Time per second

- *Active Time* (default): each unit's own time spent dealing damage.
- *Fight Duration*: the time the whole segment lasted, the same for everyone, like most raid
  parses. Windows keep ticking while a fight runs.

Bar tooltips show the active time and, in fight duration mode, the fight time and the share
of it the unit was active.

### Window and appearance

- **Themes:** *Classic* (default, tooltip-style window with the silver border and stock
  dialogs) or the original *Flat* look. Switch with the settings or `/sdps theme 0|1`;
  it needs a reload.
- **Textures:** eight bar textures, including three in the style of Puppeteer's health bars
  and *Blizzard Retail (Modern)* (`/sdps texture 8`) with modern palette colors for all nine classes.
- **Class icons** beside player names in Damage, Heal and Threat, scaled with the bar height.
- **Lock button** next to the + button locks or unlocks moving and resizing of all windows.
- New windows start with the size and view of the first window.
- Long names no longer run into the numbers, and unmerged pets show as "Owner - Pet".
- The settings window closes with Escape.

### Performance

- Unit lookups are cached per GUID, so busy raids cost less.
- Windows showing the same segment share sorted display data and skip repainting unchanged rows.
- Hidden windows don't refresh, and names and labels are cached.

## Data sources

Pick one in the settings or with `/sdps source`. *Auto* takes the best one loaded, and the
settings show which source is in use and why a forced one isn't available.

| Source | Reads | Notes |
|--------|-------|-------|
| **ClassicAPI** (preferred) | `COMBAT_LOG_EVENT_UNFILTERED` | Needs a build that includes the combat log. Units come with GUIDs and group/pet flags, so group members, pets, guardians and totems are found without scanning names, and nothing depends on the client language. |
| **Nampower** | `SPELL_DAMAGE_EVENT_*`, `AUTO_ATTACK_*`, `DAMAGE_SHIELD_*`, `SPELL_HEAL_BY_*` | Needs GUID unit tokens from SuperWoW or ClassicAPI, otherwise it isn't used. Nampower 4.5.0 and later enable the events when ShaguDPS registers them; older versions get `NP_EnableAutoAttackEvents` and `NP_EnableSpellHealEvents` set to `1`. |
| **Chat combat log** | The localized combat log text | The original parser, used when neither of the above is available. |

Pets and totems of group members are matched to their owner through the GUID
(`UnitOwnerGUID` with ClassicAPI, the owner token with SuperWoW).

### Healing and overhealing

ClassicAPI reports overhealing with each heal. A positive value is used for effective
healing. Zero is ambiguous on older builds, so it is trusted only after positive overhealing
has been seen in the session and only for visible targets with a maximum health above 100;
otherwise effective healing is estimated from the target's health. ClassicAPI predicts
overhealing on the client, so it isn't server-authoritative. Nampower and the chat parser
always use the health-based estimate.

### Shields

Newer ClassicAPI builds name damage shields such as Thorns. Older builds and ambiguous
events show *Reflect (School)*. Damage ownership is the same either way.

## Commands

`/shagudps`, `/sdps` or `/sd`:

```text
/sdps config           Open the settings
/sdps threatdebug      Measure threat requests/replies for 10 seconds
/sdps perf             Measure addon CPU/memory for 10 seconds
/sdps visible 1        Show main window (0 or 1)
/sdps height 15        Bar height (any number)
/sdps spacing 0        Bar spacing
/sdps trackall 0       Track all nearby units (0 or 1)
/sdps mergepet 1       Merge pets into owner data (0 or 1)
/sdps source 1         Data source (1 auto, 2 ClassicAPI, 3 Nampower, 4 chat log)
/sdps time 0           Per second time (0 active time, 1 fight duration)
/sdps texture 2        Statusbar texture (1 to 8)
/sdps pastel 0         Use pastel colors (0 or 1)
/sdps backdrop 1       Show window backdrop and border (0 or 1)
/sdps theme 1          Theme (0 flat, 1 classic), needs a reload
/sdps lock 0           Lock windows
/sdps toggle           Toggle visibility of the main window
```

## Combat log range

ShaguDPS has no raid syncing between players: it sees what your client is told about, which
is limited by the combat log range (40 yards by default). This applies to every data source.
To raise it to 200:

```
/run for _,n in pairs({"Party", "PartyPet", "FriendlyPlayers", "FriendlyPlayersPets", "HostilePlayers", "HostilePlayersPets", "Creature" }) do SetCVar("CombatLogRange"..n, 200) end
```

Or in your `Config.wtf`:

```
SET CombatLogRangeParty "200"
SET CombatLogRangePartyPet "200"
SET CombatLogRangeFriendlyPlayers "200"
SET CombatLogRangeFriendlyPlayersPets "200"
SET CombatLogRangeHostilePlayers "200"
SET CombatLogRangeHostilePlayersPets "200"
SET CombatLogRangeCreature "200"
```

Some unit frame addons rely on the range being exactly `40` for their range checks, and some
reset it back to `40`.

## Diagnostics

- `/sdps threatdebug` counts threat requests, replies and changed replies for ten seconds.
- `/sdps perf` measures ShaguDPS for ten seconds. Memory is reported in KB with its change;
  garbage collection can change that value. CPU results need a ClassicAPI build with addon
  profiling: run `/console scriptProfile 1` and `/reload` first, and switch it off again with
  `/console scriptProfile 0` and `/reload`, because profiling adds overhead. The values are
  elapsed addon CPU milliseconds and milliseconds per second, not an FPS measurement.
  Builds without profiling report it as unsupported and are otherwise unaffected.

## Notes

- Saved variables are `ShaguDPS_Config` and `ShaguDPS_Fights`, both per character.
- Display caches are not saved with fight history.
- The combat log events and global strings the chat parser uses are listed in
  [docs/combat-log.md](docs/combat-log.md).
- Detailed notes per release are in [docs/](docs/).
