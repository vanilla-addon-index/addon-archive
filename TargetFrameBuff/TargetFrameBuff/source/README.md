# TargetFrameBuff

[![ClassicAPI](https://img.shields.io/badge/ClassicAPI-Optional-yellow.svg)](https://github.com/brues-code/ClassicAPI)

Shows up to **32 buffs** and **16 debuffs** on the default target frame of a
1.12 client (tested target: Turtle WoW 1.18.1). Buffs sit above the frame in
rows of 5-11-11-5, debuffs below it in rows of 4-4-8.

With the optional [ClassicAPI](https://github.com/brues-code/ClassicAPI) client
mod it also adds countdown text, stack counts, debuff-type borders, a gold
border on enemy buffs you can remove, optional cooldown sweeps, and accurate
tooltips. Without ClassicAPI it behaves like the original: more icons, no timers.

## Installation

1. Copy the `TargetFrameBuff` folder into `Interface/AddOns`, replacing any older copy.
2. Restart the client (or `/reload`).
3. Optional: install ClassicAPI.

## ClassicAPI

| Version | What you get |
| --- | --- |
| none | 32 buffs and 16 debuffs, no timers, borders or sweeps |
| 1.17.x | Timers, stack counts, borders; auras are re-read every 0.5 s |
| 1.17.10+ | Event-driven updates (`UNIT_AURA_DELTA`), no polling |
| 1.17.11+ | **Recommended.** Fixes the reverse sweep briefly showing a bright icon just before an aura ends |

Harmful auras beyond the first 16 use free buff-row slots (only while the debuff limit is 16; the buff limit still applies). ClassicAPI decides
aura order and lists your own auras first.

## Settings

`/tfb` opens the AddOn Options panel (or prints help if the client has none).

| Command | Action | Default |
| --- | --- | --- |
| `/tfb timers [on\|off]` | Countdown text | on |
| `/tfb highlight [on\|off]` | Gold border on removable enemy buffs | on |
| `/tfb sweeps [on\|off]` | Reverse cooldown sweeps | off |
| `/tfb size 6-20` | Countdown font size | 9 |
| `/tfb warning 0-30` | Seconds left at which text turns red | 5 |
| `/tfb buffs 0-32` | Most buffs shown | 32 |
| `/tfb debuffs 0-16` | Most debuffs shown. Below 16, extra debuffs are hidden rather than moved into the buff row. | 16 |
| `/tfb test [buffs debuffs]` | Fake auras on your target for checking layout (default 32 and 16; 0-32 each). Run again or `/tfb test off` to stop. | off |
| `/tfb reset` | Restore defaults | |

Settings are saved and kept even while ClassicAPI is absent.

**Test mode** fills the target frame with fake buffs and debuffs so you can check
layout, borders, stack counts and, with ClassicAPI, timers, sweeps and the
red warning. It targets you if you have no target, restarts expiring fake auras
so timers keep running, and is not saved; `/reload` turns it off. Debuffs past 16
spill into the buff row, as real ones do. The options panel has a matching button.

## Compatibility with ShaguTweaks

Checked against the upstream [ShaguTweaks](https://github.com/shagu/ShaguTweaks) source.

| ShaguTweaks option | Effect | What to do |
| --- | --- | --- |
| **Unit Frames > Debuff Timer** | Conflict. Adds its own timer text, sweep and green stack count to debuffs 1-16, on top of ours. It ignores overflow debuffs in the buff row. | Disable it. TargetFrameBuff prints a warning in chat if it detects it. Alternatively use `/tfb timers off` and `/tfb sweeps off`. |
| Cooldown Numbers | No conflict found. It only hooks `CooldownFrame_SetTimer`; our sweeps use `SetCooldown`. | Keep. |
| Dark UI Elements | Adds a dark border to every `TargetFrameBuff*` button. Ours draws above it, so the gold removable-buff border should stay visible. | Not verified in-game. |
| Target Castbar | Positions the castbar from debuff 7 and 11 being shown. With the 4-4-8 layout it can sit over the second and third debuff rows. | Disable it or move the castbar if it overlaps. |
| Move Unit Frames | Buff and debuff buttons are children of `TargetFrame`, so they follow it. | Keep. |

## Notes

- Timings from ClassicAPI are best effort. Unobserved applications and some
  max-stack refreshes have unknown expiration; their timer and sweep stay hidden
  while the icon remains.
- This is not a live WoW test. See [VALIDATION.md](VALIDATION.md) for what was
  simulated and what to check in-game, and [CHANGELOG.md](CHANGELOG.md) for history.

## Development

Tests simulate the WoW API under Lua 5.1: `pip install lupa`, then `python3 tests/test_addon.py`.

## Credits

Based on [project-949](https://wow.curseforge.com/projects/project-949).
Original author lua@lumpn.de; modified.
