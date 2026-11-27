# AdeLazyBuffs

Remembers which buffs you cast on whom and keeps them up for you, for WoW 1.12.
No per-buff setup: cast a buff once the way you like it and the addon repeats it.
It works with **Seals** as well as raid and party buffs (Blessings, Greater Blessings).

Classes: Paladin, Mage, Priest, Druid, Warlock, Warrior, Shaman (Hunter and Rogue have no buff list yet and
stay idle). Single-target buffs (Arcane Intellect, Fortitude, Mark of the Wild, Blessings...), group buffs
(Arcane Brilliance, Prayer of ..., Gift of the Wild, Greater Blessings) and self buffs (armors, Inner Fire,
Battle Shout, Lightning Shield, ...) are all learned from your own casts. Seals are Paladin only.

## What it does

- **Learns from your casts.** Cast a buff on a friend and the addon remembers "this buff on that player".
  A group buff (Greater Blessing) is remembered for every player of that class who got it. Cast a different
  buff on the same player later and the memory is updated.
- **Rebuffs out of combat.** Two sliders set how many seconds must be left before a blessing is rebuffed: one for
  normal blessings (2 min by default) and one for Greater blessings (3 min). It never goes above half of that
  blessing's own duration. Time left on yourself is read from the game; on others it is counted from your cast.
  The real durations are learned from your own casts.
- **Reminder window.** When a blessing is due, outlined text lists who needs what (drag it where you like,
  lock it, pick the font and text size). Seals are not listed.
- **Casts when you act.** The game ignores casts that do not come from you, so the addon casts in the middle of
  your own input, like SmartBuff: you press any button, scroll the mouse wheel or change target and the due buff
  is cast. In the window you can limit this to the mouse wheel only, or to your own key (set it there).
- **Checks that the buff is really there.** A buff that was cancelled, dispelled or lost on death is recast at once,
  whatever the timer says. The timer can be switched off (`/alb timer off` or the window): then buffs are
  recast only when they are gone.
- **Keeps your Seal up in a fight.** In combat, whenever you have no seal on you, the last Seal you cast is cast
  again on your next input. Out of combat it is left alone.
- **Stays out of the way.** Nothing is cast in rested areas (cities, inns) unless you are fighting (quest mob, PvP,
  training dummy): a fight switches the rested-area rule off. Buffs are never cast in a fight, only the Seal.
  Also nothing while you are eating, drinking or mounted, while you cast something else, or on players flagged
  for PvP when you are not. Targets that are out of range are skipped
  and tried again later. Your target is not changed (SuperWoW is used when present, otherwise the target is
  switched and restored).
- A minimap button (Blessing of Wisdom icon) opens the settings; drag it around the minimap or hide it in the window.
- The settings window background opacity can be changed (text and buttons stay solid).
- English and Russian, picked from the game language (can be switched in the window).

Blessings of Protection, Freedom and Sacrifice are never remembered.

## Commands (`/alb` or `/lazybuffs`)

| Command | |
|---|---|
| `/alb` | open / close the settings window |
| `/alb on` / `off` | enable / disable |
| `/alb auto on` / `off` | casting on your input on / off (the reminder stays) |
| `/alb seal on` / `off` | keep the seal up on / off |
| `/alb timer on` / `off` | rebuff by time left on / off (off: only when the buff is gone) |
| `/alb now` | one pass right now, even in a rested area or with auto-cast off (also a key binding, which you can set in the window) |
| `/alb size <8-64>` | reminder text size (also a slider in the window) |
| `/alb list` | show what is remembered |
| `/alb why` | show the state the addon looks at right now (rested, fight, seal on you, ...) |
| `/alb debug on` / `off` | print the reason every few seconds when nothing is cast |
| `/alb forget <name>` / `forget all` | forget one player / everybody |
| `/alb lang auto` / `en` / `ru` | language |

## Install

Copy the `AdeLazyBuffs` folder to `Interface\AddOns\` and restart the game.
Optional: [SuperWoW](https://github.com/balakethelock/SuperWoW) (casting without changing your target),
pfUI (the window takes its look).
