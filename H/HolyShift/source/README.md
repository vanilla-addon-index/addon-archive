# HolyShift

HolyShift is a Turtle WoW feral druid addon focused on one-button cat DPS with optional raid automation and debug tooling.

Maintainer: **Miioon**
Original author: **Maulbatross (Kronos 3)**

## What It Does

- Runs cat DPS from one macro: `/hsdps dps`
- Uses a bleed-engine style priority:
  - Keep **Rake** up
  - Use **5 CP Rip opener** when Rip is missing
  - Use **5 CP Ferocious Bite** after Rip is up
  - Use **Shred** when behind + high energy
  - Use **Claw** otherwise
- Supports automatic powershifting on low energy
- Supports Turtle WoW **Reshift** (if learned), with Cat Form fallback
- Handles raid utility/automation options (MCP, consumables, cower, FF, etc.)

## Requirements

- Vanilla client API compatible with Turtle WoW
- Class: **Druid**
- Recommended level: **60**
- Action bar requirements for rotation logic checks:
  - Auto Attack
  - Claw
  - Shred (optional but recommended)
  - Rake
  - Ferocious Bite

## Quick Start

1. Install addon in `Interface/AddOns/HolyShift`
2. Create a macro with:
   - `/hsdps dps`
3. Bind it to the same key in caster and cat bars
4. In game, type:
   - `/hsdps`

## Commands

Main:
- `/hsdps dps`

Toggles:
- `/hsdps innervate on|off`
- `/hsdps mcp on|off`
- `/hsdps manapot on|off`
- `/hsdps demonicrune on|off`
- `/hsdps flurry on|off`
- `/hsdps clawadds on|off` (legacy toggle; current rotation no longer uses this in builder selection)
- `/hsdps tiger on|off`
- `/hsdps shift on|off`
- `/hsdps cower on|off`
- `/hsdps deathrate on|off`
- `/hsdps ff on|off`

Config:
- `/hsdps weapon <name|none>`
- `/hsdps offhand <name|none>`

Debug:
- `/hsdps debug on|off`
- `/hsdps debug status`
- `/hsdps debug show <N>`
- `/hsdps debug clear`

## Rotation Notes

- Tiger's Fury is used as a maintenance priority (configurable)
- Rake is refreshed only when missing
- Rip is only cast at 5 combo points and only if missing
- Ferocious Bite is used as the default 5 CP finisher once Rip is active
- Shred/Claw builder logic is automatic:
  - Shred when behind and energy is high enough
  - Claw otherwise
- "Must be behind" errors trigger a short lockout before trying behind-only behavior again

## Powershifting and Reshift

- Low-energy branches attempt shift acceleration when enabled (`/hsdps shift on`)
- If `Reshift` exists in spellbook, HolyShift will attempt to use it first
- If `Reshift` is unavailable or not ready, HolyShift falls back to Cat Form shifting
- If DruidManaLib is missing, HolyShift uses fallback shift mode (attempt-based)

## Raid/Combat Automation (Optional)

Depending on toggles and context, HolyShift can automate:
- Cower logic
- Faerie Fire upkeep
- Tiger's Fury usage
- MCP use/swap behavior
- Demonic Rune / Mana Potion / Innervate usage
- Juju Flurry usage
- Threat/defensive boss behavior branches

## Utility Functions (`/run`)

Available helper functions include:
- `AutoBuff()`
- `PatchHeal()`
- `BLTaunt()`
- `StealthOne()`
- `StealthTwo()`
- `QuickCast(spell,target)`
- `QuickStone()`
- `QuickHT()`

Examples:
- `/run QuickStone()`
- `/run QuickHT()`
- `/run QuickCast('Healing Touch(Rank 5)',1)`

## Debug Export to File

HolyShift stores debug lines in SavedVariables. They are written on `/reload` or logout.

To export them to a text file from this repo:
- Run `./debug-log-export.ps1`
- Output file: `logs/HolyShift-debug.txt`

Typical workflow:
1. `/hsdps debug on`
2. Fight/test
3. `/reload`
4. Run export script

## Dev Auto-Sync (Optional)

If you develop directly from this repo and want automatic sync into Turtle WoW AddOns:
- Run `./dev-autosync.ps1`
- Then `/reload` in game after changes

## Repository

https://github.com/qrospars/HolyShiftMiio
