# Changelog

All notable changes to ShaguDPS for WoW 1.18.1 clients. Release notes with install steps and
validation details for 4.5 and 4.6 are in [docs/](docs/).

## Unreleased

### Documentation

- README shows ClassicAPI, Nampower and SuperWoW badges (all optional) under the title.

## 4.6.1

### Changed

- Nampower 4.5.0 and later enable the auto attack and heal events when ShaguDPS registers
  them, so ShaguDPS no longer changes `NP_EnableAutoAttackEvents` and `NP_EnableSpellHealEvents`
  in your saved settings on those versions. Older Nampower versions still get both set to `1`.

### Documentation

- Rewrote the README: one table of modes, one of data sources, a contents list, and the
  per-version "what's new" text moved here.
- Added this changelog. The Nampower link now points to the brues-code build.

## 4.6.0

### Added

- **Dispels mode** with per-window *Done* and *Received* selections, aura, player and ability
  breakdowns, and Current, Overall and saved-fight data. Requires ClassicAPI combat logging.
- Newer ClassicAPI builds supply named damage shields (for example Thorns) and the dispelling
  ability. Older builds keep *Reflect (School)* names and unknown-ability labels.

### Changed

- Valid positive ClassicAPI overhealing values are used for effective healing. Zero is trusted
  only after positive overhealing was seen in the session and only for visible targets with a
  maximum health above 100; otherwise the health-based estimate remains the fallback.
- Windows showing the same segment share sorted display data and skip repainting unchanged rows.
- Pull-threshold labels are correct, confirmed in game with melee and ranged samples.
  *Pull Aggro* now displays 100%. The raw-threat thresholds and 0.5 second polling are unchanged.

### Fixed

- Missing dispel history is labelled as not recorded instead of showing zero.
- Threat replies to older outstanding requests are discarded using the target GUID and a
  switch generation.

## 4.5.0

### Added

- Class icons in Damage, Heal and Threat (on by default; toggle *Show Class Icons*).
- *Blizzard Retail (Modern)* bar texture with modern colors for all nine classes
  (`/sdps texture 8`).
- `/sdps threatdebug` and `/sdps perf` diagnostics.
- A 110-130% pull-threshold range when your melee or ranged status is unknown.

### Changed

- Totals, rates and percentages align in columns; DPS, HPS and TPS are whole numbers:
  `100K (1000 DPS) [100%]`. Chat reports use the same format.
- Threat: requests on target switch, immediate display of replies, a rolling five-second TPS,
  stale-data clearing, and centered target and mode titles. Polling stays at 0.5 seconds.
- Boss deaths are detected through the destination GUID on ClassicAPI builds with combat
  logging, with the chat message as the fallback.

### Fixed

- Missing players in the threat list caused by decimal threat values and percentages.
- Duplicate wipe entries caused by healing while targeting a boss corpse. Existing duplicate
  entries in saved history are not removed.

## 4.3

### Added

- **Boss fight history**: the segment menu gains *Fights* with the last 10 boss fights, saved
  per character. Chat reports name the boss, kill or wipe and the fight length.

## 4.2

### Added

- **Damage and Heal modes** replace the DPS and HPS views, with total, rate and share on one bar
  and overhealing as the lighter bar behind effective healing.

### Changed

- Large numbers are shortened (`37K`, `1.23M`) in windows and chat reports.

### Fixed

- Lua error when sending the heal report to chat.

## 4.1

### Added

- **Threat mode**: the threat list of your current target from the server's threat API, with a
  *Pull Aggro* line, TPS, and sharing of replies with TWThreat.

## Earlier

Changes from before the versions above were not recorded with a version number.

- **Data sources**: ClassicAPI and Nampower parsers next to the chat combat log, selectable with
  `/sdps source`. Nampower is only used when GUID unit tokens are available.
- *Fight Duration* per-second time mode next to *Active Time*.
- *Classic* theme (default) and the original *Flat* theme.
- Lock button, three Puppeteer-style bar textures, and per-GUID unit caching.
- New windows start with the size and view of the first window; long names no longer run into
  the numbers; unmerged pets show as "Owner - Pet"; the best effective heal value used for the
  heal bar scale was fixed; bars of different windows no longer share global frame names; the
  settings window closes with Escape.
