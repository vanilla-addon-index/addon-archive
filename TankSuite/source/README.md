# TankSuite

[![Release](https://img.shields.io/github/v/release/ShikawaLePaladin/TankSuite?label=release)](https://github.com/ShikawaLePaladin/TankSuite/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![WoW 1.12](https://img.shields.io/badge/WoW-1.12.x-orange)
![SuperWoW](https://img.shields.io/badge/requires-SuperWoW-8a2be2)

A tank toolkit for **World of Warcraft 1.12 (vanilla)** clients running **[SuperWoW](https://github.com/balakethelock/SuperWoW)**, such as Turtle WoW and compatible private servers.

- **Announcer** – calls out failed taunts and, optionally, the taunts and defensive cooldowns you use.
- **Nameplates** – shows on every enemy nameplate *who the mob is attacking*, with tanks detected automatically.
- **In-game menu** – every option is configurable from a full settings window. No file editing.
- **English and French** – the client language is detected automatically and can be overridden.

## Screenshots

> Add screenshots to `docs/` and reference them here.

## Requirements

| Requirement | Notes |
|---|---|
| WoW client 1.12.x | Interface `11200` |
| [SuperWoW](https://github.com/balakethelock/SuperWoW) | Needed for nameplate target detection (GUID access) and for spell-use detection. Without it the addon loads and warns you. |
| pfUI / ShaguPlates / ShaguTweaks | Optional. Nameplate colouring is integrated with pfUI and ShaguPlates. |

## Installation

**From a release (recommended)**

1. Download `TankSuite-<version>.zip` from the [Releases](https://github.com/ShikawaLePaladin/TankSuite/releases) page.
2. Extract it so the path is `Interface\AddOns\TankSuite\TankSuite.toc`.
3. Restart the game, or type `/reload` if it is already running.

**With git**

```bash
cd "<WoW folder>/Interface/AddOns"
git clone https://github.com/ShikawaLePaladin/TankSuite.git
```

The folder must be named exactly `TankSuite`.

## Usage

Open the settings with `/tks` (also `/tanksuite` or `/tsuite`), or click the minimap button.

| Command | Action |
|---|---|
| `/tks` | Open or close the menu |
| `/tks add [name]` | Add a tank manually (your target if no name is given) |
| `/tks remove <name>` | Remove a manually added tank |
| `/tks list` | List the tanks currently detected |
| `/tks clear` | Clear the manual tank list |
| `/tks test` | Send a sample announcement |
| `/tks announce on\|off` | Enable or disable the announcer |
| `/tks plates on\|off` | Enable or disable the nameplate colouring |
| `/tks lang en\|fr\|auto` | Change the language |

## Features

### Announcer

- Reports your **failed taunts** (resisted, missed, immune, dodged, parried…): Taunt, Growl, Mocking Blow, Hand of Reckoning, Earthshaker Slam, Challenging Shout and Challenging Roar.
- Optionally announces taunts **when you use them**.
- Announces **defensive cooldowns**: Shield Wall, Last Stand, Gift of Life, Challenging Shout and Challenging Roar.
- **Main Tank mode** reports every miss, dodge and parry during the first seconds of a pull.
- Sends to any channel: Say, Yell, Party, Raid, Raid Warning, a custom channel, or only to yourself.
- Every message template can be edited in the menu.
- Failures are read from the combat log using the client's own global strings, so it works on non-English clients.

### Nameplates

| Colour | Meaning |
|---|---|
| Green | The mob is attacking you |
| Tank colour | The mob is on a tank. Each tank gets their own colour and a shield icon. |
| Red | The mob is on someone who is not a tank: a **loose mob** |
| Orange | The mob has no target (resetting or fleeing) |
| Grey | The mob is on a pet |

The target's name is written above or below the plate in class colour. All colours, the font size and the text position can be changed in the menu.

### Tank detection

A player counts as a tank when, in this order of priority:

1. **Manual** – you added them (menu, `/tks add`, or the *add target* button).
2. **Main Tank** – they hold the Main Tank role in the raid frame.
3. **Automatic** – they were seen doing something only tanks do: casting Taunt, Growl, Righteous Fury, Defensive Stance or Shield Block, or standing in Bear Form. The flag expires after a few minutes without a new signal.

## Compatibility

- Written for **Lua 5.0** (WoW 1.12): no `#` operator, no `%` operator, no `string.match`, no `select`, no varargs.
- Optional APIs such as SuperWoW's `SpellInfo` are accessed through `getglobal`, so a missing API never raises an error.
- Every event handler runs inside `pcall`. A Lua error is reported once in chat instead of breaking the addon.
- Saved variables live in `TankSuiteDB`. Missing keys are merged in on load, so upgrading never resets your settings.

## Project layout

| File | Role |
|---|---|
| `Core.lua` | Namespace, defaults, helpers, event bus, slash commands |
| `Locale.lua` | English and French strings |
| `Roster.lua` | Group roster and tank detection |
| `Announcer.lua` | Failed-taunt and cooldown announcements |
| `Nameplates.lua` | Nameplate colouring and target text |
| `UI.lua` | Shared UI widgets |
| `Menu.lua` | Configuration window and minimap button |

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Released under the [MIT License](LICENSE).
