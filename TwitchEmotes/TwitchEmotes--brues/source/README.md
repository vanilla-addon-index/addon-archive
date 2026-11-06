[![ClassicAPI](https://img.shields.io/badge/ClassicAPI%20>=%20v1.14.0-Required-purple.svg)](https://github.com/brues-code/ClassicAPI)

# TwitchEmotes

Twitch, BetterTTV, FrankerFaceZ and Discord emotes in World of Warcraft 1.12.1.

Type `Kappa`, `PepeLaugh` or `:skull:` in chat and it comes out as the emote — for you and for
everyone else running the addon. Over 4,000 codes across 28 packs, 122 of them animated, rendered
inline in chat, chat bubbles and mail.

Originally written for retail by **Ren**; backported to vanilla by **Brues**.

## Features

- **Emotes everywhere** — say, yell, guild, officer, whisper, party, raid, battleground, channels
  and in-game mail. Each channel can be toggled on its own.
- **Animated emotes** at ~30fps, in chat, in the picker, and over chat bubbles.
- **Autocomplete** — type `:` plus two characters for a ranked popup (prefix, then substring, then
  fuzzy). Tab cycles the suggestions, space or a click accepts one.
- **Emote picker** on the minimap button, grouped by pack. Mark the packs you use as favourites and
  hide the rest.
- **Clickable emotes** — hover an emote in chat to see its code, shift-click to put it in your
  edit box.
- **Usage statistics** — how often you have sent and seen each emote (shift-click the minimap
  button).

Minimap button: click for the picker, shift-click for statistics, right-click for options.

## Requirements

[ClassicAPI](https://github.com/brues-code/ClassicAPI) is required. The 1.12 client cannot draw
cropped inline textures on its own, which is what animated emotes and sprite sheets need. Without
the DLL loaded the addon disables itself and points you at the download.

## Adding an emote

`tools/add_emote.py` takes a BetterTTV emote, converts it to a texture the 1.12 client can decode,
and registers it:

```
python tools/add_emote.py https://betterttv.com/emotes/<id> PepeCool
```
