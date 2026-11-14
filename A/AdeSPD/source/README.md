# AdeSPD

Real spell damage and healing in the 1.12 / Turtle WoW spell tooltips.

The stock tooltip ignores spell power. AdeSPD rewrites the numbers so they include your spell power,
talents and buffs, and works out the coefficients of spells it has no data for by watching your own
hits in combat.

    Shadow Bolt, Rank 6      (60 shadow power)
    stock:   causing 204 to 230 Shadow damage.
    AdeSPD:  causing 255 to 281 Shadow damage.        <- changed numbers are green

    Arcane Missiles, Rank 5  (no coefficient known yet)
    ...causing 115 Arcane damage every 0.95 sec for 4.75 sec.
    AdeSPD: calculating in process, need combat data (3/15 hits)

## Requirements

| Mod | Needed | Used for |
|---|---|---|
| [Nampower](https://github.com/Emyrk/nampower) | **yes** (4.5.0 or newer recommended) | spell records, talent/buff spell modifiers, spell durations, combat events, player auras |
| [SuperWoW](https://github.com/balakethelock/SuperWoW) | optional | fallback to read your buff ids (`GetPlayerBuffID`) if Nampower's aura field is not available |
| [ClassicAPI](https://github.com/brues-code/ClassicAPI) | optional, recommended | `GetSpellBonusDamage(school)` / `GetSpellBonusHealing()` |

Without Nampower the addon still works, but only for the spells in `Data.lua`, and without talents,
buffs or learning (it prints a warning at login). Without ClassicAPI the spell power is computed
from the "Equip:" lines of your gear plus the spell power / damage % of your active buffs.

## Install

Copy the `AdeSPD` folder to `Interface\AddOns\` and restart the game.
Make sure the DLL mods are loaded first (VanillaFixes `dlls.txt`, SuperWoW launcher, etc.).
On the first login the addon indexes the spell ids of your spellbook in the background (a few
seconds, once; the result is saved).

## What goes into a number

For every damage / healing number in the tooltip:

    shown = (tooltipNumber + spellPower * coefficient * modMultiplier) * buffMultiplier

- **spellPower**: school damage or healing, from ClassicAPI, otherwise gear + buff scan.
- **coefficient**: from `Data.lua` (Turtle wiki, Turtle class changes) or learned from combat.
  Every spell has up to four separate parts: direct damage (`d`), damage over time (`o`), direct heal (`hd`) and heal over time (`ho`). Spells that deal damage and heal (Holy Nova) get one of each, taken from their triggered spells. Ranks that cast faster than the listed cast time scale
  down (the cast time is snapped to the nearest 0.5 s, so haste does not distort it), and the vanilla level rules apply (spells learned below level 20 lose 3.75% per missing level; a rank far below your level is scaled by (rank level + 6) / your level; rank levels come from the spell record).
- **tooltipNumber**: the number the game already shows. It already contains your talent modifiers (a Frostbolt test against real hits showed this), so only the spell power part is added.
- **modMultiplier**: Nampower `GetSpellModifiers` for the spell (damage, or DoT for periodic parts), the percent talents such as Piercing Ice. Nampower reports it as a multiplier in percent (102 = x1.02, 0 = none). It scales the spell power bonus, because the server applies it to base + bonus.
- **buffMultiplier**: "% damage done" / "% healing done" auras that are active right now.

## Spells without data: learning in combat

Spells that are not in `Data.lua` (for example the reworked Turtle spells) show

    AdeSPD: calculating in process, need combat data (n/15 hits)

Cast the spell on a target. Every normal (non-crit) hit is turned back into a coefficient estimate
(the base range is known from the spell record, the spell power and modifiers at the time of the hit
are known), and the estimates are averaged. When at least 15 hits agree within 5 percentage points
the value is used and the tooltip says `coefficient learned from combat`. Data is saved between
sessions.

After that the learner keeps collecting in batches of 100 hits per spell part. When a batch is
finished (and is stable) its average replaces the shown value, then a new batch starts, so the
number keeps getting corrected. The cost is a few additions per hit.

- Direct damage, DoT ticks, channels (Arcane Missiles, via the triggered spell) and heals are handled.
- Needs at least 25 spell power on the cast, otherwise a hit says nothing about the coefficient.
- Crits are ignored; resisted and absorbed amounts are added back; hits that cannot be explained
  are discarded.
- Learned values are per spell rank (they are not copied to other ranks).

Limits of the measurement:

- Target debuffs that raise damage taken (Curse of the Elements, ...) and talents that are not
  spell modifiers are not modelled, so they bias the result. Learn on a clean target if you can.
- Healing is less reliable because overhealing hides part of the amount.
- The learner runs for every spell, including the ones in `Data.lua`, so you can check the table:
  `/spd compare` lists learned vs table values.

## Commands (`/spd` or `/adespd`)

| Command | |
|---|---|
| `on` / `off` | enable / disable |
| `armor [on/off]` | with an attackable target selected, direct physical numbers (and weapon ranges / totals) are reduced by its armor; no target: unreduced numbers (default on) |
| `window [on/off]` | long output (`probe`, `explain`, `why`, `compare`, `weapon`, `debug`, `auras`) opens in a scrollable window you can select and copy from (Ctrl+A, Ctrl+C); off prints to chat |
| `record [on/off/auto]` | non English clients: the tooltip text is not parsed, the real numbers are added as extra green lines computed from the spell record (default `auto`: on for every client that is not enUS / enGB; `on` forces it on an English client) |
| `dump [book/on/off/clear]` | saves the tooltip texts of every spell in the trainer window (automatic every time you open a trainer, `on/off`) and with `dump book` of your spellbook, into the saved variable `AdeSPDDump` (file `WTF/Account/<account>/SavedVariables/AdeSPD.lua`, written at logout or `/reload`); send that file to have the texts of your client language supported |
| `book [on/off]` | also change spellbook tooltips (default off: only action bar tooltips are changed) |
| `detail` | toggle an extra gray line: spell power, coefficient, modifiers |
| `mods [on/off]` | use talent / buff modifiers (turn off if numbers look double counted) |
| `learn [on/off]` | combat learning |
| `prefer table / learned` | which coefficient wins when both exist (default `table`) |
| `status` | detected mods, option values, index size |
| `debug` | spell power per school: API value vs gear + buff scan, attack power |
| `auras` | your active auras and the spell power / % effects detected in them |
| `probe <spell>` | spell record effects (incl. triggered spells), detected parts and every modifier Nampower reports |
| `weapon` | lists weapon damage abilities of your spellbook that get no `Total damage` line, with their tooltip text (send it to me to add the wording) |
| `explain` | after hovering a spell: parts, coefficient sources, spell power, modifiers used for the last tooltip |
| `why [spell]` | why the learner skipped its latest events; with a spell name: which spell ids its damage / heal events came with, how many, and the last skip reason (use it right after casting the spell a few times) |
| `compare` | learned coefficients with standard error, next to the table value |
| `forget <spell>` / `forget all` | delete combat data |
| `log [on/off]` | print raw damage / heal events (to verify the event layout) |
| `rescan` / `scan <maxid>` | rebuild the spell id index / change the highest spell id scanned (default 110000) |

## Melee and ranged abilities

Physical abilities (and Serpent Sting / the hunter shots through `Data_Melee.lua`) use **attack power**
(ranged attack power for shots) in place of spell power, with the same formula, modifiers and learning.

- Abilities that hit for weapon damage (Sinister Strike, Backstab, ...) already contain the attack
  power in the weapon hit, so their "plus N" numbers are left alone. When such an ability has its own
  extra damage number (Steady Shot: "an additional 50 damage") that number is rewritten and its
  coefficient is learned: the addon subtracts your average weapon hit (from the character sheet damage)
  from every shot and attributes the rest to attack power.
- Learning works for bleeds and other direct-damage abilities. Direct physical hits are reduced by the
  armor of the target, so they are only learned when you have the mob targeted (its armor is read and
  corrected); bleeds ignore armor. Combo point abilities are never learned.
- Tooltips with "N% weapon damage", "N% ranged weapon damage" or just "weapon damage" get your real
  weapon damage range in green, for example `100% weapon damage (212 to 268)`. It is the damage of your
  character sheet (ranged weapon for ranged abilities, so attack power is included); damage multipliers
  from talents / buffs are applied.
- The weapon wording "weapon damage", "melee damage" and "your melee damage" is recognised. When a red
  `Requires ...` line says the wrong weapon is equipped (Backstab with a sword), no weapon range and no total are shown.
- Flat abilities with no scaling (Kick, Gouge) are listed in `Data_Melee.lua` with `d = 0`, so nothing is learned for them.
- Abilities with weapon damage plus an extra number (Steady Shot, Arcane Shot, Sinister Strike) also get a
  `Total damage: low to high` line. The range is widened to the lowest / highest hit you actually landed
  (last 100 hits), because target debuffs such as Hunter's Mark are not modelled.
- Arcane Shot is the exception: its extra damage scales with spell power (Arcane and general), so it is
  learned like a spell, with the weapon part taken out.
- Combo point finishers that list a range per combo point (Eviscerate: `3 points: 103-131 damage`): both
  numbers of every line get the attack power bonus (coefficient x attack power x combo points) and the
  target armor. The coefficient is learned against the stock ranges, so hover the tooltip once after login
  and use the finisher with combo points; the addon remembers the points you had before the finisher spent them.
- Text such as `deals 25% of your Attack Power as damage` (Surprise Attack) gets the real number added in
  green: `... as damage (250)`.
- Add known values to `Data_Melee.lua` (`d` / `o` = fraction of attack power, `ap = true` for non-physical
  school abilities, `ranged = true` for ranged attack power).

## Other client languages (Russian)

On a client that is not English the addon does not read the tooltip words. Spells are found by id (spell name and rank text come from the client, so `Уровень 2` is read as rank 2), the English name of a spell comes from `Data_Names.lua` (spell id -> English name, generated from the AdeNameDump files) and is used for the coefficient tables, and the numbers are computed from the spell record.

The real numbers replace the stock ones in the description, in green, like on the English client (`нанося 289 - 315 ед. урона`). A number is replaced only when it matches what the record says for that spell (within 2.5 %); when the game text is wrong, cut or has no such number, the value is added as an extra green line instead (`Урон: 289-315`, `Урон за время: 336 (84 за тик)`, `Исцеление: 279-315`). Combat learning works the same as on the English client.

`Data_Ru.lua` holds replacement descriptions for spells whose Russian game text is wrong (Lightwell / Колодец Света so far), by English spell name. Add more there when you find one.

Not shown yet in this mode: weapon damage abilities, abilities that deal a percent of attack power (Surprise Attack, Kill Command) and combo point finishers (Eviscerate).

`/spd record on` uses the same method on an English client, to compare the two.

## Data.lua

Edit it freely. `d` = direct coefficient, `o` = coefficient of the whole over-time part,
`ct` = cast time the coefficient is valid for, `mult` = Turtle balance multiplier,
`drank` = per-rank override, `heal = true` for healing spells. Spell names are English.

## Troubleshooting

If a tooltip shows nothing or a number looks wrong: hover the spell, then run `/spd explain`; if the
learner stays at 0 hits run `/spd why`; `/spd probe <spell>` shows the raw record; `/spd detail` shows
the power, coefficient and modifiers behind a number. `/spd mods off` shows the result without talent /
buff modifiers.

If you used an earlier version, run `/spd forget all` once: healing data used to be stored under the
damage parts.
