Time To Drink - Turtle WoW (vanilla 1.12) addon  v1.1
=====================================================

WHAT IT DOES
  In a 5-man party (disabled in raids) it watches a healer you pick and posts
  to PARTY chat when their mana drops below your threshold, repeating on a
  cooldown you set (minimum 10s). Message: "<Healer> has less than <X>% mana".

INSTALL
  Copy the "TimeToDrink" folder into <Turtle WoW>\Interface\AddOns\ so you have:
     ...\Interface\AddOns\TimeToDrink\TimeToDrink.toc
     ...\Interface\AddOns\TimeToDrink\TimeToDrink.lua
  IMPORTANT: make sure it is NOT double-nested (no TimeToDrink\TimeToDrink\...).
  Then /reload or restart, and tick it in the AddOns list at character select.

COMMANDS
  /ttd          open / close the window
  /ttd enable   turn alerts on  (unmute)
  /ttd disable  turn alerts off (mute)
  /ttd reset    recenter the window and show it
  /ttd status   print current threshold, cooldown, healer, and party state
  /ttd test     send a test line to party chat (only works while in a party)
  /ttd debug    toggle verbose messages (announces show up in your own chat)

TROUBLESHOOTING
  Turn on Lua errors so problems are visible:  /console scriptErrors 1
  This build also prints any error to your chat in red starting "TTD error:".

## More addons by Fayz

All for OctoWoW and other 1.12 clients. A star on any of them is appreciated.

- **[SHPlates](https://github.com/TheRealFayz/SHPlates)** is a highly customizable nameplate addon. Server threat, cast bars, debuff timers, combo points, raid marks and per-spec settings. Know who has aggro before the mob gets to your healer.
- **[TotemNesia](https://github.com/TheRealFayz/TotemNesia)** is a totem management addon for Shaman.
- **[Arcanum](https://github.com/TheRealFayz/Arcanum)** helps Mages manage their spells and items.
- **[SHAlts](https://github.com/TheRealFayz/SHAlts)** is an alt manager for OctoWoW and other 1.12 clients. It keeps track of everything your characters own and lets you look at any of them from one window, no matter which character you are playing.
- **[AutoSpam](https://github.com/TheRealFayz/AutoSpam)** posts your messages to chat channels at the interval you choose, from 1 to 10 minutes.
- **[TimeToDrink](https://github.com/TheRealFayz/TimeToDrink)** tells the tank when the healer is low on mana. It watches the healer you choose and posts a warning to party chat when their mana drops below your threshold.
