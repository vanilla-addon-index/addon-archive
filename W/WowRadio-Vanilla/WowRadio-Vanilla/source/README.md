# 📻 WowRadio — Vanilla

Listen to Internet Radio directly inside **World of Warcraft 1.12**.

WowRadio provides a simple in-game radio player with a large built-in station list, compact and full interface modes, custom stream support, saved settings and convenient playback controls.

## ✨ Features

- 100 built-in radio stations
- Game, Rock, Electronic, Jazz, Talk and Variety categories
- Compact and Full interface modes
- Previous / Next / Random station controls
- Custom radio stream support
- Automatic playback on login
- Saved settings and last selected station
- Key bindings
- Titan Panel integration
- Easy station management through `Stations.lua`

## 🖼️ Interface

### Compact mode

<img width="336" height="82" alt="WowRadio Compact Mode" src="https://github.com/user-attachments/assets/6a389409-854a-4c4c-a635-50be52a58229" />

### Full mode

<img width="506" height="389" alt="WowRadio Full Mode" src="https://github.com/user-attachments/assets/1f2b6410-5073-49f0-bff3-46109e278b61" />

## 📦 Installation

1. Download the addon.
2. Place the `WowRadio-Vanilla` folder inside:

   `World of Warcraft\Interface\AddOns\`

3. Start or restart the game.
4. Make sure **in-game music is enabled**, as WowRadio uses the WoW music system for radio playback.

Open the options with:

`/wowradio`

or:

`/wr`

## 🎵 Commands

| Command | Description |
|---|---|
| `/wrtune <number>` | Switch to a station by number |
| `/wrplay` | Play the last selected radio station |
| `/wrstop` | Stop radio playback |
| `/wrnext` | Switch to the next station |
| `/wrprev` | Switch to the previous station |
| `/wrrnd` | Switch to a random station |
| `/wrlist` | Display the available station list |
| `/wrinfo` | Display the currently playing station |
| `/wrauto` | Toggle automatic playback on or off |
| `/wrcustom <url>` | Play a custom stream URL |

Example:

`/wrtune 10`

## 📡 Custom stations

Custom radio streams can be played directly with:

`/wrcustom http://example.com/stream`

Built-in stations are stored in `Stations.lua`.

Each station follows this format:

`{ "Stream URL", "Display Name", "CATEGORY" }`

Available categories:

- `GAME`
- `TALK`
- `ROCK`
- `ELECTRONIC`
- `JAZZ`
- `VARIETY`

Station numbering and synchronization are handled automatically.

## ⚙️ Compatibility

- World of Warcraft client 1.12
- Interface version 11200
- Ace2-based
- Titan Panel support

## 📜 Project identity & licensing

WowRadio-Vanilla is an independent community-maintained addon. It is not
affiliated with or endorsed by Blizzard Entertainment or by the radio stations
listed in `Stations.lua`.

The repository contains mixed-origin material. The historical WowRadio code has
no explicit project-wide license identified in the currently known upstream
repositories, so this fork does **not** claim to relicense that inherited code.

For details, see:

- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
- [PROJECT_IDENTITY.md](PROJECT_IDENTITY.md)
- [Docs/CODE_PROVENANCE.md](Docs/CODE_PROVENANCE.md)
- [Docs/ASSET_PROVENANCE.md](Docs/ASSET_PROVENANCE.md)
- [Docs/STATION_DIRECTORY_NOTICE.md](Docs/STATION_DIRECTORY_NOTICE.md)
- [LICENSES/](LICENSES/)

## 🙏 Credits

Original addon by **Tormentor @ Mannoroth** and **belthazor**.

Initial GUI and ideas by **jack.e**.

Vanilla version maintenance and additional improvements by **Dusk-92**.

## 📜 Changelog

### 1.1
- Updated radio stations
- Added Compact Mode
- Added mute button
- Added UI refinements

### 1.0
- Added 96 radio stations
- Added custom URL support
- Added fade-on-move option
- Added interface resizing
- Added saved settings
- Added key bindings

### 0.4a
- Backported to World of Warcraft Vanilla

### 0.4
- `/wrinfo` now correctly displays custom URLs
- Added Titan Panel plugin
- Moved station definitions to `Stations.lua`
