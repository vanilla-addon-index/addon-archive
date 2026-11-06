# Changelog

## 4.2
**New**
- Life Tap ranks are found by spell ID when ClassicAPI is present (`FindSpellBookSlotByID`), so the spell name and rank text no longer have to match. The name scan still runs and covers anything the ID scan misses. The combat log check also recognises Life Tap by spell ID.
- `/slt verify` compares each rank's base health with the game's own spell data (`C_Spell.GetSpellDescription`, needs ClassicAPI). `/slt verify adopt` uses the spell data numbers, `/slt verify reset` goes back to the built-in table. A one-time notice appears at login if they disagree.
- Macro buttons that contain `/slt cast` show the Life Tap rank that would be cast right now (ClassicAPI, `C_Macro.SetMacroDisplay`). Turn it off with `/slt macrodisplay off` or in the options window.
- With `/slt debug on`, the combat log check prints the raw values after the spell fields, to confirm which one is the power type.

**Changed**
- `Options.lua` window is taller to fit the new checkbox.

## 4.1
**New**
- Options window: `/slt options`, or with ClassicAPI, game menu → AddOn Options → ScaledLifeTap. Includes a Ranks page showing the health cost and mana gained per rank. Without ClassicAPI, the same settings open in a small window of their own.
- The mana check now also works with ClassicAPI alone, using its combat log. It listens only for a few seconds after each tap.

**Changed**
- `/slt status` and the options window share the same status text.
- The mana check only records a tap when it is turned on.

## 4.0
Complete rewrite of ScaledLifeTap 3.

**New**
- Reads exact shadow spell damage, including buffs, from ClassicAPI (`GetSpellBonusDamage`) or Nampower (`GetSpellPower`) when present.
- BonusScanner is no longer used: a built-in gear scanner gives the same totals and also works on German and French clients. It can still be forced with `/slt source bonusscanner`.
- Mana check (Nampower): compares the mana each tap actually gives with the prediction and learns a correction if your server differs. See `/slt calibrate`.
- `/slt` commands: `cast`, `status`, `overtap`, `reserve`, `bonus`, `source`, `calibrate`, `debug`, `rescan`.
- Health reserve: never tap below a set % of max health.

**Fixed**
- Game freeze when Life Tap wasn't in the spellbook (the spellbook loop never ended).
- Settings were never saved (a `local SLT_Config` hid the saved variable).
- Overtap could cast rank 1 even when it would take more health than you had.

**Changed**
- Gear is scanned only after your equipment changes, and only on the next cast. No per-frame work.
- Spellbook and talents are cached and refreshed on events.
- Improved Life Tap is found by name, so a reordered talent tree doesn't break it.
- Casts by spellbook slot, so rank text localization no longer matters.
- Replaced the config window, which never worked, with `/slt` commands.

## 3
- Previous release by Kimilly. Required BonusScanner.
