# SHAlts

An alt manager for OctoWoW and other 1.12 clients. It keeps track of everything your characters own and lets you look at any of them from one window, no matter which character you are playing.

You can also download IRC from OctoWoW's [Gitea](https://octowow.st/git/Fayz/SHalts).

## What it tracks

- **Bags**, with item counts and icons
- **Bank**, recorded each time you open the bank
- **Mailbox**, recorded each time you open a mailbox (items and money waiting)
- **Professions**, skill levels and every recipe you know
- **Gear**, what each character has equipped
- **Cooldowns**, for every alt at once: Salt Shaker, transmutes, Mooncloth, Shadowcloth and Spellcloth. You pick which ones you care about
- **Custom timers**, for anything else you want to count down, like an auction or a delivery
- **Reputation, PvP rank, honor and time played**
- **Instance resets**, the 5 per hour limit, for each character
- **Raid lockouts**, so you can see at a glance which characters are locked, and to which raid
- **Server raid resets**, when each raid resets for everyone so you know when you can run it again

Everything is recorded automatically while you play. There is nothing to save and no command to run.

## Using it

Open the window with the minimap button or `/shalts`. Pick an alt from the dropdown at the top, then use the tabs down the right edge to switch between what you want to see. The search box looks through every alt at once, so you can find out who is holding that stack of Runecloth or who knows a recipe.

- Hover the minimap button for your reset timers, raid lockouts and any ready cooldowns.
- Hover an item for its tooltip.
- Shift-click an item to link it in chat.
- Ctrl-click an item to try it on.
- Drag the corner of the window to resize it, right-click the corner to reset.

## Instance resets and raid lockouts

The IRC tab is the Instance Reset Counter built into SHAlts. The server allows 5 instance resets per hour, and each character keeps its own five timers.

- Each timer counts down from 60:00. Reset 1 is always the oldest. When it runs out it clears and the rest move up.
- A timer starts only when the game confirms the reset, so a reset that fails because someone is still inside starts nothing.
- It also counts resets done by your group leader ("Blackrock Depths has been reset by Name"), so members get a timer too.
- Raids count the same as dungeons. If you farm Molten Core or another raid and reset it to run it again, each reset uses one of the five. One reset action is one timer, even if it resets several dungeons or raids at once. All their names are shown on that one timer.
- Coin you loot inside the instance is added to the newest timer, and the Lockout total adds up all five.
- Timers keep counting while you are logged out.
- Pick any character from the dropdown to see its timers. The Reset instances and Reset all timers rows work for the character you are playing.
- The same list of timers shows when you hover the minimap button, counting down live.
- When a slot frees up or you hit the cap, you get a sound and the minimap button flashes. If you lead the group, the reset is announced in party or raid chat. Both can be turned off in Settings.

Raid lockouts are listed under the timers for the selected character, and the **All characters** list below shows who is locked and who is free. The minimap hover also lists everyone who is raid locked. A character's lockouts are recorded when you log in on it.

If you also have the separate IRC addon installed, turn one of them off. They would both count the same resets.

## Cooldown alerts

When a cooldown finishes on any of your characters, a small window tells you. If several are ready, they are all listed together. Each one is announced once. The alert waits while you are in combat or dead and never steals your keyboard focus.

If you run more than one game window, only one of them shows the alert.

## Choosing cooldowns and custom timers

Not every cooldown matters to every player. Open the Cooldowns tab and click **Choose cooldowns and timers** (or use the button in Settings) to switch any cooldown on or off. A cooldown you switch off is hidden on the Cooldowns tab, in alerts and on the minimap, and your choice is shared between your accounts. Nothing is lost, switch it back on any time.

You can also start a timer of your own for anything you want to keep an eye on, like how long an auction has been posted. In Settings, under **Custom timer**, type a name and a time such as `24h`, `2d`, `90m` or `1d12h`, and press Start. It belongs to the character you are playing, counts down on the Cooldowns tab for every one of your alts, and alerts you when it runs out. Click a timer in the choose list to remove it. Finished timers tidy themselves away after a day.

## Raids tab

The Raids tab has two parts, both separate from your own reset timers.

- **Server raid resets** lists every raid on its own line with its size range and when it resets for everyone, so you know when you can run it again. Raids that share a reset timer, like Molten Core and Naxxramas, show the same time. Edge of Madness also shows which boss is up right now, like Edge of Madness (Wushoolay).
- **Saved to raids** lists the raids the character picked in the dropdown is saved to, and how long until each save runs out. Pick your Mage from the dropdown while playing your Paladin to check its Zul'Gurub save without logging over. A character's saves are recorded when you play it, so log in on each character once.

## Using more than one account

The game keeps each account's data separate, so by itself an addon can only see the characters on the account you are logged into. With SuperWoW installed, SHAlts shares its data through a small text file in your game folder (`Imports\SHAltsSync.txt`). Every account that runs from the same game folder reads and writes the same file, so all of your alts show up everywhere.

If you play two characters at the same time, each one picks up the other's changes within a few seconds, so the window stays current without a reload. A character that is offline catches up the next time you log in on it.

Log in once on each account and the rest takes care of itself. Without SuperWoW the addon still works, it just shows the characters of the account you are on.

The file is plain text and is never run as code. It stays on your computer. Nothing is sent anywhere.

## Settings

Open the Settings tab (the gear) to:

- change the window opacity or reset its size
- sort alts by name or level
- show or hide the minimap button
- turn cooldown alerts on or off, or test one
- choose which cooldowns to track, and start custom timers
- turn the reset sound alerts and the reset announcements on or off
- turn sharing between accounts on or off
- rescan the current character
- remove an alt: type the name and press Delete

A removed alt stays removed, even with the shared file, until you play that character again.

## Commands

| Command | What it does |
| --- | --- |
| `/shalts` or `/sha` | Open or close the window |
| `/shalts find <text>` | Search items and recipes on all alts |
| `/shalts cd` | List cooldowns in chat |

## Good to know

- The bank and the mailbox can only be read while they are open, so each is updated whenever you visit it. The window shows when it was last seen.
- Recipes are saved when you open that profession's window.
- Profession cooldowns are read from the recipe tooltip when you open the profession window, and started when you craft the item. If a cooldown was running before you installed the addon, open that profession once.
- Item tooltips come from your game's own item cache. An item no character on this install has seen yet shows its name and color until the game learns it.
- If you use SHAlts for a very long time it asks once, politely, whether you would like to star the project on GitHub. It never does this in combat, in a group, in an instance, or while you are busy, and it never asks again.

## Install

1. Download the addon and put the `SHAlts` folder in `Interface\AddOns`. If you downloaded a zip from GitHub, the folder must be named exactly `SHAlts`, so remove any `-main` from the end of its name.
2. Start the game and log in. The minimap button appears right away.

## Enjoying it?

If SHAlts saves you some time, please take a second to **star the project on GitHub**: https://github.com/TheRealFayz/SHalts

Stars are how other players find it, and they tell me it is worth keeping up. Bug reports and ideas are welcome too. Open an issue on the same page and include what you were doing when it happened.

## More addons by Fayz

All for OctoWoW and other 1.12 clients. A star on any of them is appreciated.

- **[SHPlates](https://github.com/TheRealFayz/SHPlates)** is a highly customizable nameplate addon. Server threat, cast bars, debuff timers, combo points, raid marks and per-spec settings. Know who has aggro before the mob gets to your healer.
- **[TotemNesia](https://github.com/TheRealFayz/TotemNesia)** is a totem management addon for Shaman.
- **[Arcanum](https://github.com/TheRealFayz/Arcanum)** helps Mages manage their spells and items.
- **[AutoSpam](https://github.com/TheRealFayz/AutoSpam)** posts your messages to chat channels at the interval you choose, from 1 to 10 minutes.
- **[BigTimer](https://github.com/TheRealFayz/BigTimer)** is a see-through toolbar for starting BigWigs pull timers without writing macros, with built-in raid target marking.
- **[TimeToDrink](https://github.com/TheRealFayz/TimeToDrink)** tells the tank when the healer is low on mana. It watches the healer you choose and posts a warning to party chat when their mana drops below your threshold.
