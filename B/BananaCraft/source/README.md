# 🍌 BananaCraft

**Share professions and recipes with your guild: find the crafter, whisper them, done.**

![Version](https://img.shields.io/badge/version-3.0.0-ffd100) ![Client](https://img.shields.io/badge/client-1.12.1-blue) ![License](https://img.shields.io/badge/license-MIT-lightgrey)

*Formerly known as BananaRepublik Partnerguild.* Every guild member scans their professions, the addon shares the recipes over the guild channel, and everyone can search who can craft what. Built for the guild **Banana Republic**. Lua 5.0, no libraries.

## Features

- **Recipe catalog (new in 3.0):** profession → tier/category → recipe, like in AtlasLoot (Alchemy: Apprentice … Artisan, Flasks, Protection Potions, …). Item and enchant tooltips, quality colours, reagents, and **who in the guild can craft it**. Filters *Only with crafter* and *Only online*.
- **Gathering professions (new in 3.0):** Mining and Herbalism show **who can mine or gather which node**, based on the skill level every member shares.
- **Recipe database for the whole guild:** open a profession window and the addon scans it. Search by recipe name across all professions, see reagents, icon and crafter.
- **Sync that only fetches what is outdated:** `/bc sync` compares hashes, `/bc send` sends everything. CSV export for Discord and Excel.
- **Shift-click search:** with the cursor in the search box, Shift+click an item, enchant or recipe (bags, profession window, vendor, chat links) to put its name into the search box.
- **Alts of your account:** *Share database with guild* also sends the professions of your other characters (same realm). They show up as "Alt of <character>", whether the alt is in another guild or has none. You choose your **Main** in the settings window; every other character of the account is shown as "Alt of <Main>". You can untick single alts there. An optional *Alt confirmation* lets alts report themselves, so the list can show "confirmed" or "claimed" (this is not proof of the same account; the 1.12 client has no account ID). Alts on **other accounts** come in via *Export alts* / *Import alts* in the settings window: export on the other account, copy the text (Ctrl+C), paste it into the import window on your main account (Ctrl+V). An alt has to have been logged in once with the addon, with its profession windows opened.
- **Settings window (gear icon)** with language, *Online only* filter, minimap button, rescan, send, sync, CSV export, bank scan, version check and delete. The `/bc` commands still work.
- German and English, minimap button.

## Installation

1. Download the [latest release](https://github.com/BananaForge/BananaCraft/releases) and put the `BananaCraft` folder into `Interface/AddOns/`.
2. Enable it on the character screen and open the window with `/bc show`.

**Updating from 2.x:** just copy the new `BananaCraft` folder over the old one and overwrite. You do not have to delete anything, and your saved data stays. (If you come from *BananaRepublik Partnerguild*, that folder is a different addon and its data does not carry over.) **Every member needs the addon.** It is a standalone addon with its own saved variables (`BananaCraftDB`) and prefix, so it can run next to BananaRepublicProfs, but the two do not share data.

## Usage

| Command | Effect |
|---|---|
| `/bc show` | Open or close the catalog |
| `/bc checkmats` | Check that every recipe lists its materials |
| `/bc scan` / `rescan` | Scan the open profession / allow rescanning |
| `/bc send` / `sync` | Send all professions / fetch only what is outdated |
| `/bc versioncheck` | Which addon version do guildmates run? |
| `/bc delete [prof\|all]` | Delete one or all professions |
| `/bc scanbank` | Scan the bank manually |
| `/bc export` | CSV export for Discord/Excel |
| `/bc lang en\|de\|auto` | Language |
| `/bc debug` / `about` | Debug output / info and support |

## Technical notes

- The catalog (`BananaCraft_Catalog.lua`) is generated from AtlasLoot data by `tools/gen_catalog.py`; materials of enchantings are read from the game client's tooltips.
- Client 1.12.1 (Interface 11200), saved variables `BananaCraftDB`, addon prefix `BCRAFT0`.
- Database keys are `Charname@Guild`, the same string goes over the wire.
- Limits: private servers may behave differently from original vanilla; if chunks arrive broken, `/bc debug` shows why.
- Details on the design, the code and the limits: [docs/ENTWICKLUNG.md](docs/ENTWICKLUNG.md).

## To do

- [ ] About 20 missing Enchanting recipes (Runed Rods, Wands, Oils) in `BananaCraft_RecipeMaps.lua`. A pure data gap.

## Contributing

Pull requests welcome, tested in-game on a 1.12 client. Lua 5.0 rules: no `#`, `%`, `string.match`, `select` or `...`; script handlers read `this`, `event` and `arg1..9` as globals; German texts in `Locale.lua` use umlauts and `ss` instead of `ß`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Credits and license

Part of **BananaForge** (with [BananaRepublicProfs](https://github.com/BananaForge/BananaRepublicProfs), [BananaBank](https://github.com/BananaForge/BananaBank) and [BananaLootline](https://github.com/BananaForge/BananaLootline)). Development: **Lumihunt**, guild Banana Republic. Free forever; if you want to support it, send in-game mail to Lumihunt. MIT, see [LICENSE](LICENSE).
