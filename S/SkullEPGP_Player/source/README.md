# Skull EPGP Player (WoW 1.12)

Light addon for **raiders** of a guild using the EPGP loot system. It works together with
**[SkullEPGP_Officer](https://octowow.st/git/Hapto/EPGP_Officer)**, used by the master looter / raid leader.
It also works when the loot master uses **RollFor** instead (see below).
Nothing to configure: install it, and a small window pops up each time an item is announced.

<!-- Screenshots: put the PNG files in docs/images/ and uncomment the lines below
![Bidding window](docs/images/bidding-window.png)
![Winner announced](docs/images/winner.png)
-->

## Quick start
1. Copy the folder into `Interface/AddOns/` and `/reload` (or restart the game).
2. Join the raid: the addon silently asks the officer for your priority.
3. When an item is announced, pick **Roll MS**, **Roll OS**, **Tmog**, **MIN**, **NEED** or **MAX** in the window.
4. Watch the list of bidders and the winner in the same window.

## What it does
When the officer announces an item, a window opens with:
- the **item** (hover for its tooltip) and a **countdown**,
- **your priority** (EP / (GP + base GP)),
- the **list of players who already bid or rolled**, sorted like the final ranking (MAX > NEED > MIN > roll, then priority), with their priority and roll. Your own line is highlighted,
- **six buttons**: **Roll MS**, **Roll OS**, **Tmog** on the first row, **MIN**, **NEED**, **MAX** on the second (the GP price is shown on each bid button).

Rules (same as the officer addon): one choice per announcement; the only change allowed is **NEED -> MAX**. Buttons that are not allowed any more are greyed out. MIN / NEED / MAX post the word in the raid chat. With the officer addon, Roll MS, Roll OS and Tmog are all the same plain /roll 1-100 (no GP paid). The officer confirms your choice (the list updates) a moment later.

## RollFor loot masters
When the loot master runs **RollFor** instead of the officer addon, the same window opens for RollFor's roll sessions. You do not need RollFor installed yourself.

| Button | Officer addon | RollFor |
|---|---|---|
| Roll MS | `/roll` | `/roll 100` |
| Roll OS | `/roll` | `/roll 99` |
| Tmog | `/roll` | `/roll 98` |
| MIN / NEED / MAX | posts the word in raid chat | `/roll 100` |

- RollFor's numbers are the loot master's own settings (100 / 99 / 98 by default). If the loot master turned transmog rolls off, the Tmog button is greyed out.
- The addon reads RollFor's hidden addon messages (item, timer, rolls, ties, winner), the same ones RollFor uses for its own roll popup. With an older RollFor that does not send them, it reads the raid warning ("Roll for [item]: /roll (MS) or /roll 99 (OS) ...") and the result lines in the raid chat instead.
- Only one roll counts, like in RollFor. On a tie, the tied players can roll again (same range); the others see "Tie between ...".
- Soft-reserved items: only the players who reserved the item can roll (/roll 100); for everybody else the buttons are greyed out. Items restricted to some classes are greyed out for the other classes.
- The list shows the rolls sorted like RollFor (MS > OS > Tmog, then the roll), and the winner when RollFor announces it.
- Pre-bids work too: a MIN / NEED / MAX pre-bid becomes a /roll 100, a Roll MS / Roll OS / Tmog pre-bid its own roll.

When the officer awards the item, the winner is shown in the window (and "You won" in your chat). The window closes by itself 20 seconds after the end.

## Installation
Copy the files into `Interface/AddOns/SkullEPGP_Player/`. The folder must be named `SkullEPGP_Player` (not `EPGP_Player`), or WoW will not load the addon. Nothing to configure.
Your priority and the prices are sent by the officer (`/epgp publish`, or automatically when you join the group: the addon asks for them). Only messages from the raid leader / assistants / master looter are accepted. If you have no priority yet (officer import done before you connected), the addon silently asks again every 30 s while you are in a group; if you are not in the EPGP list, the window says so and stops asking.

## History
The **History** button next to the close button of the bidding window (or `/epgpp history`) lists the items won during this session: item, winner and bid (MIN / NEED / MAX) or roll. It is kept in memory only: it is cleared by a reload or a disconnection.

## Pre-bids
The minimap button (click) or the **Pre-bids** button of the bidding window opens the pre-bid list (the bidding window is toggled with a right-click on the minimap button).
- Add items with the bar at the top: shift-click an item (bag or chat link) into the box, type its id or name, or use the "Add" button next to the last announced item. What you type is previewed with its icon and link. A name is recognised when the item is in your bags, equipped, or was announced / won this session (otherwise type the id or shift-click it).
- The list scrolls (scrollbar or mouse wheel) when it is long.
- Pick the bid of each item in its drop-down (Roll MS / Roll OS / Tmog / Min / Need / Max, Need by default). Pre-bids saved as "Roll" by an older version become "Roll MS".
- When the loot master announces one of these items, your bid is **sent automatically in the chat** (always active as soon as the list is not empty). When you win the item it is removed from the list.
- **Only pre-bids**: when ticked, the bidding window never opens by itself on an announcement (pre-bids still work). `/epgpp` opens it by hand.

The bidding window shows only the **top 3 bids** (+ N more).

## Commands
`/epgpp` show / hide the window - `/epgpp auto on|off` open it automatically (default on) - `/epgpp reset` reset its position - `/epgpp req` ask the officer for your priority - `/epgpp history` items won - `/epgpp options` pre-bids window - `/epgpp prebid add|remove|list [item]` - `/epgpp minimap` show / hide the minimap button - `/epgpp test` show a fake announcement to check the layout (nothing is sent to the raid) - `/epgpp testrf` the same for a RollFor roll session.

The window is movable (drag it).
