# 🍕 PizzaLoot

Loot notifications for WoW 1.12. Whatever you pick up slides onto your screen for a few seconds, instead of only landing in chat where it scrolls away behind whatever everyone else is typing.

It shows your own loot and your own money, nothing else. Other people's drops, vendor sales, quest rewards and mail stay out of it.

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaLoot/demo.gif" width="100%">

Regular items stack up as small rows with the icon, the name in its quality color and the stack count. Rare gets a blue sweep of light across the row and a small pop. Epic and legendary get a glowing banner in the middle of the screen and skip the queue, so a Thunderfury never sits behind five stacks of Runecloth.

Money is read straight off your balance when a loot window closes, so it shows up even on servers where the chat event never fires. Coins picked up within half a second of each other get merged into one line.

## Install

### [⬇️ Download the latest version](https://codeberg.org/Pizzahawaii/PizzaLoot/releases/latest)

1. Download `PizzaLoot-<version>.zip` from the release page and extract it
2. Copy the `PizzaLoot` folder inside it to `<WoW>/Interface/AddOns`
3. (Re)start WoW

> [!WARNING]
> Extracting might give you a `PizzaLoot-<version>` folder with the actual `PizzaLoot` folder inside it. If so, copy the inner one. WoW only loads it as `AddOns/PizzaLoot/PizzaLoot.toc`, not `AddOns/PizzaLoot-<version>/PizzaLoot/PizzaLoot.toc`.

PizzaSauce ships with it, so there's nothing else to download.

## Commands

- `/ploot lock`: lock the frame in place
- `/ploot unlock`: show the anchor and drag it wherever you want
- `/ploot reset`: put it back in the middle of the screen
- `/ploot width N`: row width in pixels, 80 to 500, default 190
- `/ploot in up|down|left|right`: which way a row slides in, default down
- `/ploot out up|down|left|right`: which way it slides out again, default left
- `/ploot test`: show one of every tier through epic, plus money
- `/ploot test rare` / `epic` / `legendary`: just that one
- `/ploot`: the list you're reading

`/pizzaloot` works too. Position, width and slide directions are saved per character.

`in up` also flips the list: rows fill from the top down, so the newest one is at the bottom. Every other slide-in direction fills bottom-up with the newest on top. Either way a row always enters across empty space rather than over the row it lands next to.

Long item names get cut off with a `...` to fit the row, so if you're seeing that a lot, `/ploot width 260`. The banner sizes itself to the name and ignores the width setting.

## Built with

[PizzaSauce](https://codeberg.org/Pizzahawaii/PizzaSauce), my animation library for 1.12. Every slide, shake, flash and glow in here is a few lines of it.
