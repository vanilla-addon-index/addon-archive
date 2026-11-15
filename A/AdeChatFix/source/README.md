# AdeChatFix

For the Russian WoW 1.12 client. The language patch shows "32" instead of a space in chat (`Сказать:32`, `%s говорит:32`). This addon puts the space back.

It runs at login, on `/reload` and after every loading screen (instances, teleports, portals, hearthstone). It only changes `CHAT_*` strings that end in `32`.

Install: copy the `AdeChatFix` folder into `Interface\AddOns`.
