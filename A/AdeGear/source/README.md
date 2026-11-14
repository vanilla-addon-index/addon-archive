# AdeGear

Talent-aware gear comparison for the 1.12 client (OctoWoW, Turtle WoW style servers).
Mostly for new players who want to ask "What better X or Y for Class_Name" at /world (without spec).
Hover an item and AdeGear tells you whether it is better than what you wear, for **your** role and talents.
Needs no other addon. Works with **AdeTalents** (talent ranks, strongly recommended) and **pfUI** (colors, font, bags).
Window look: Auto (pfUI style when pfUI is loaded, else the usual vanilla windows), pfUI, or Vanilla; set in the options, General tab.

## Install

Copy the folder to `Interface\AddOns\AdeGear\` (the path must end in `AdeGear\AdeGear.toc`). Keep AdeTalents next to it.
Updates: copy the files over the old ones and `/reload`.

## What you get

**Hover panel.** Hover any item (bags, bank, vendor, loot, links, trade, auction) and a panel shows the gear you wear in
that slot, the new item, a verdict (BIG UPGRADE, UPGRADE, SIDEGRADE, DOWNGRADE ...) with the change in percent, stat by stat
differences with their value, the talents that changed those values, set bonuses gained and lost, hit and defense cap
notes, and effects you gain or lose. Rings, trinkets and one-handers are compared with every slot they could take.
Detail level (compact / normal / detailed) is set in the options.

**What "points" mean.** The score of an item is in the currency of your class: 1 point = 1 spell power, healing power or
attack power. A stat is worth: base value of your class and role, plus what your talents add, times what your talents
multiply, adjusted for caps (hit, defense, armor) and your gear. `/adeg weights` or the Weights tab show every number and why.

**Role.** Taken from the talents you picked (tank, healer, damage; feral druids and hunters also get a style).
You can force it with the Role buttons, the minimap button (right click) or `/adeg role`.
Only your role counts, except while soloing with "tanks and healers also count damage" on (Leveling tab).

**Modes.** Solo (low levels, damage share optional), Party and Raids. Raids also count level 63 bosses: hit and defense caps,
weapon skill and, for healers, mana regeneration are worth more.

**Upgrade arrows.** A green arrow on bag and bank icons for items you can wear now that beat what you wear by 2% or more.

**/adeg best.** A window with every upgrade in your bags, best first, plus upgrades you cannot use yet. Hover a row for the item.

**GearScore.** One class-independent number: fixed weight per stat, armor divided by what its type normally gives, weapon dps,
a small bonus per effect, and a bonus for rare / epic / legendary quality (item level is not available on this client).
Shown on your character window (drag it, it remembers where), on item tooltips, and on the tooltip of players you hover
(read by inspecting them; hold Shift to read again, `/adeg gs reset` forgets everyone). `/adeg gs` lists your items.

**Options window** (`/adeg options` or the minimap button): General (switches, role, mode, window look), Leveling, Weights (the
calculated value of every stat; type your own number to override it; Reset clears), Talents (the talents that change your values).

**Items it understands.** Stats, enchants, resistances, school spell damage, weapon skill, avoidance, set bonuses
(learned from tooltips: hover the pieces of a set once), Equip/Use effects (listed, not counted), races and their passives.

## Commands

| Command | What it does |
|---|---|
| `/adeg options` | options window |
| `/adeg role auto\|heal\|dmg\|tank` | force the role; `/adeg role why` shows which talents decide it |
| `/adeg weights` | what one point of each stat is worth, and why |
| `/adeg best` | upgrades in your bags |
| `/adeg gs`, `gs reset`, `gs on\|off`, `gs top\|bottom` | GearScore window, forget players, switch, label position |
| `/adeg arrows` | arrows on bag icons on/off |
| `/adeg minimap`, `minimap round\|square` | minimap button on/off and its shape |
| `/adeg weapon <0-2>` | how much weapon dps counts (default 0.3) |
| `/adeg skin auto\|pfui\|vanilla` | window look; without an argument it reports the look in use and whether pfUI was found (then `/reload`) |
| `/adeg reset` | forget saved window positions |

For testing and bug reports:

| Command | What it does |
|---|---|
| `/adeg status` | versions and settings in two lines: send this with a bug report |
| `/adeg me` | what the addon reads about your character (role, skill, target level, gear totals) |
| `/adeg unparsed`, `unparsed clear` | tooltip lines the parser did not understand; `/reload` writes them to `WTF\Account\<account>\SavedVariables\AdeGear.lua`, send that file |
| `/adeg item`, `/adeg equipped <slot>` | what was understood about an item |
| `/adeg set` | set bonus details of the last hovered item |
| `/adeg scan` | show the test panel instead of the comparison |
| `/adeg error` | last error of a comparison |

## Good to know

- All class numbers are **estimates** (tanks' Strength, Agility, block, regeneration, GearScore weights ...). They are tuned from
  real play; tell the author when two items are ranked wrongly.
- Talents are read by AdeTalents. Without it only base values are used (`/adeg status` shows whether it was found).
- Set bonus piece counts are learned from tooltips. A bonus whose piece count is unknown gives a note instead of a number
  until you have hovered the set's other pieces.
- GearScore of other players needs the game to answer the inspect request; at long range, or for items your client has
  not seen yet, it can take a few seconds or show a partial score ("N items read").
- Not covered: pet talents (they do not change which gear is better), numbers of procs and use effects, enchant and
  gem advice, Shaman was only tested offline.
