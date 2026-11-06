# Ade Alts

Alt manager for **Turtle WoW / Octo WoW (1.12 client)**. It remembers everything about all your characters,
including those on **other accounts**, and shows it in one window.

- **Profession cooldowns** – Salt Shaker, Transmutes, Mooncloth; "ready" popup at login.
- **Alt list** – level, class icon, sorted by level or name.
- **Item tooltips** show how many of the item your other alts carry (bags / bank).
- **Inventory and bank** of every alt, with each bag and its used/total slots, plus **item search** across all of them.
- **Total gold** of all alts.
- **Professions** – skill levels, known and **missing recipes** with required level and source (trainer, vendor, drop, quest...), sortable, with tooltips. Recipe items also show which of your alts can learn them, and every item tooltip shows how many of it your other alts carry.
- **Equipped gear** of every alt.
- **Minimap button** – classic round button; docks into pfUI's addon button panel automatically.
- **Settings** – window scale, width, height, background opacity, background colour, cooldown-window opacity, window style.
- **Looks** – classic Blizzard windows by default, pfUI look automatically when pfUI is installed (switchable).

## Requirements

- Turtle WoW / any 1.12 client.
- Optional but recommended: **[SuperWoW](https://github.com/balakethelock/SuperWoW)** – lets all accounts in the same
  game folder share data through `imports\AdeAlts.txt`. Without it, nothing is shared between accounts unless you enable chat sync with `/ade chat` (cooldowns only).
- Optional: pfUI (pfUI window look and minimap button docking). Not required: without pfUI the addon uses classic Blizzard-style windows.

## Installation

1. Put the `AdeAlts` folder into `<WoW folder>\Interface\AddOns\` (the folder must be named `AdeAlts` and contain `AdeAlts.toc`).
2. Do this for every account / client you use, then log in with each character once so it gets cached.
3. Updating: replace the whole folder. Saved data is kept (`WTF\...\SavedVariables\AdeAlts.lua`).

## Usage

Left-click the minimap button (or `/ade`) opens the alt manager. Right-click the button forces a sync.
The button tooltip lists only characters that have cooldowns.

Open each profession window once per character (clear its filters first) so its recipes and cooldowns are recorded.
Fishing, Skinning and Herbalism have no recipes and need nothing.

## Slash commands

Every alias works the same: `/ade`, `/adealts`, `/pcd`, `/profcd`, `/cdt`.

| Command | What it does |
|---|---|
| `/ade` (also `show`, `toggle`, `alts`) | Open / close the alt manager window |
| `/ade cd` (also `cooldowns`) | Open / close the profession cooldowns window |
| `/ade find <text>` | Open the manager and search items and recipes across all alts |
| `/ade list` | Print all cooldowns to the chat frame |
| `/ade sync` | Sync now: shared file (SuperWoW) and a chat request to guild/party/raid (only if chat sync is on) |
| `/ade scan` | Rescan this character (level, gold, bags, gear, professions) and print what the client reports |
| `/ade status` | Show whether SuperWoW file sync is on and how many characters are known |
| `/ade export` | Open a text box with all data (copy it to move data by hand) |
| `/ade import` | Open a text box to paste exported data into |
| `/ade minimap` | Show / hide the minimap button |
| `/ade alert` | Turn the login "cooldown ready" popup on / off |
| `/ade test` | Show the "ready" popup now (also when nothing is ready) |
| `/ade debug` | Print raw cooldown values of tracked bag items and stored cooldowns (for troubleshooting) |
| `/ade bags` | Print how each bag (0-10) maps to its item (troubleshooting; open the bank first for bank bags) |
| `/ade reset` | Set all cooldowns of the current character to Ready |
| `/ade del <name>` | Remove a cached character and ignore it from now on, so chat / shared-file sync cannot bring it back (not the one you are logged in on) |
| `/ade unignore <name>` | Stop ignoring a character removed with `del` |
| `/ade counts` | Turn the "On alts: N" item amounts in item tooltips on / off |
| `/ade style [auto\|blizz\|pfui]` | Window style: `auto` = pfUI look when pfUI is installed, otherwise Blizzard; `blizz` forces the classic look; `pfui` forces pfUI (needs pfUI installed). Also in Settings. |
| `/ade chat` | Turn guild / party / raid addon-message sync on or off (**off by default**; SuperWoW file sync is unaffected) |

## How data is shared

Each character stores its own record (gold, bags, bank, gear, professions, cooldowns). With SuperWoW all accounts
read and write one shared file, `<WoW folder>\imports\AdeAlts.txt`, and the newest data per character wins.
If you turn it on with `/ade chat`, cooldowns (and only cooldowns) are also exchanged through guild / party / raid addon messages (off by default), so characters of other players who run the addon (or the old ProfCD Tracker) in your guild or group can appear in your list; remove them with `/ade del`.

## Notes

- Bank contents are updated when you open the bank.
- Salt Shaker cooldown is capped to 3 days.
- Written for Lua 5.0 (1.12 client); the code is split into several files that share one global table `AdeAlts`.

## Recipe database

Missing recipes are computed from a bundled database (Vanilla + Turtle WoW: Jewelcrafting, Survival) taken from LibCrafts-1.0 (MIT), see [CREDITS.md](CREDITS.md). Recipes are matched by their English name. The database lists the *type* of source (trainer, vendor, drop, ...), not the exact NPC. Faction and specialization restrictions are not filtered.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
