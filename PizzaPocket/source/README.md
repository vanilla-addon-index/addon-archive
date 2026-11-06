# 🍕 PizzaPocket

Pick Pocket helper for WoW 1.12. One key, and it goes through the room robbing people for you.

Doing it by hand is tedious. You tab around, try to remember who you already hit, cast, get nothing, tab again, and lose track of who's left. `/pick` does the looking for you: it finds the nearest enemy you haven't robbed yet, casts Pick Pocket on it, and skips everyone else. Bind it to a key and press it as you walk past mobs.

> **[ClassicAPI](https://github.com/brues-code/ClassicAPI) is strongly recommended.** PizzaPocket works without it, but with ClassicAPI it's faster and more reliable.

## Install

### [⬇️ Download the latest version](https://codeberg.org/Pizzahawaii/PizzaPocket/releases/latest)

1. Download `PizzaPocket-<version>.zip` from the release page and extract it
2. Copy the `PizzaPocket` folder inside it to `<WoW>/Interface/AddOns`
3. (Re)start WoW

> [!WARNING]
> Extracting might give you a `PizzaPocket-<version>` folder with the actual `PizzaPocket` folder inside it. If so, copy the inner one. WoW only loads it as `AddOns/PizzaPocket/PizzaPocket.toc`, not `AddOns/PizzaPocket-<version>/PizzaPocket/PizzaPocket.toc`.

## Who's fair game

- Alive
- Within 3 yards
- Not already robbed this run
- Humanoid or Undead (wolves don't carry wallets)

Victims are tracked by GUID, so the addon knows exactly who it already emptied. A mob goes on the list when a loot window opens while it's still alive. The list wipes on zone change, so the next dungeon starts fresh.

## Requirements

- **ClassicAPI**, strongly recommended. Keep enemy nameplates switched on.
- Without ClassicAPI, you need SuperWoW and UnitXP_SP3 instead.
- pfUI is optional. If you run it with SuperWoW, robbed mobs turn grey on their nameplates so you can see at a glance who's left.

If something's missing, PizzaPocket tells you in chat instead of quietly doing nothing.

## Stats frame

A small frame shows how often mobs resist your Pick Pocket, this session and all-time, and how much gold you're making (see below). It shows up on its own when you're in a dungeon solo or with one other person. `/pick stats` shows or hides it by hand, which switches the automatic showing off until you turn it back on with `/pick stats auto`.

## Gold per run

The gold part of the stats frame shows what the current run has made: your gold now minus your gold when the run started. Pockets and anything you vendor count, and whatever you spend during the run (repairs, poisons) counts against it.

A run starts when you enter a dungeon other than the one the current run is in. It ends when the "has been reset" message for an instance shows up in chat, or when you log out, and the next dungeon you enter starts a new one. When a new run replaces one, chat tells you what the last one made.

A run only counts while you're inside the dungeon. Leaving pauses both its gold and its clock, and going back into the same instance before resetting picks up where it left off. AFKing outside, resetting late or going questing afterwards doesn't count toward the run. AFKing inside the dungeon does. The current run's gold per hour shows up once the run is a minute old.

Finished runs are remembered per dungeon. The Average column shows what a run in the dungeon you're in makes on average, the average gold per hour, and how many runs that's based on. Runs that made no money at all aren't counted.

With ClassicAPI a `/reload` keeps the run going. Without it, a `/reload` can't be told apart from logging in, so it ends the run too.

## Commands

- `/pick`: rob the nearest mob you haven't robbed yet
- `/pick reset`: forget everyone, start over
- `/pick count`: how many you've done this run
- `/pick status`: the count, plus whether ClassicAPI is in use
- `/pick debug`: prints why each mob got skipped, for when it's not picking someone you think it should
- `/pick throttle N`: seconds between attempts, or no number to see the current one. Only without ClassicAPI
- `/pick cycles N`: how many enemies one attempt will cycle through. Only without ClassicAPI
- `/pick stats`: a little frame counting how often mobs resist you, this session and all-time. `report` for the breakdown in chat, `reset` to wipe the numbers, `auto` to toggle it showing up on its own in solo or duo dungeons
- `/pick gold`: how much gold this run has made so far, plus the average for this dungeon. `reset` forgets all finished runs
- `/pick help`: the list you're reading
- `/unlock`: cast Pick Lock on the first locked Sturdy or Heavy Junkbox in your bags

`/pizzapocket` works too, if you like typing.

## Tips

Put `/pick` in a macro, drag it onto your action bar, and bind mouse wheel to that button. Now you scroll to rob. It's much less annoying than mashing a key.

With ClassicAPI you can scroll as fast as you like. Presses that don't find a mob cost nothing, and casts are spaced a quarter second apart, so there's nothing to tune.

Without it, don't lean on the wheel too hard. Attempts are throttled to one every quarter second and the rest are dropped, because the client's target cycle keeps its position between attempts: hammering the macro can walk that cycle past the mob standing in front of you instead of starting over at the nearest one. If it still feels like it needs several presses to catch on, raise the gap with `/pick throttle 0.4` and see whether it settles down. `/pick cycles 10` is the other dial worth trying, it stops one attempt from walking the cycle so far.

Turn on auto loot as well, otherwise you're opening and closing a loot window for every single pocket. Scroll wheel plus auto loot means you can clear a whole pack without stopping.
