# RollFor - SoftRes

The soft-res list for [RollFor](https://github.com/rollfor/rollfor): the import window, name
matching, the `/sr` commands and the minimap status.

## Requirements

`RollFor`, and a provider for the site your list is on:

| Provider | Reads |
|---|---|
| `RollForSoftResIt` | [softres.it](https://softres.it) exports |
| `RollForRaidRes` | [raidres.top](https://raidres.top) exports |

Both can be installed at once.

## Importing

1. Open your raid on the site and copy its import string.
2. `/sr` in game, pick the provider, paste the string and click **Import**.

## Commands

| Command | What it does |
|---|---|
| `/sr` | Import window |
| `/sr init` | Clears the list |
| `/src` | Who in the group hasn't soft-reserved |
| `/srs` | Reserved items |
| `/sro` | Matches a player whose in-game name differs from the one they reserved under |

## Options

On/off switch on its page in RollFor's options window. Each provider has its own page and
switch; a provider turned off leaves the Provider dropdown after a UI reload.
