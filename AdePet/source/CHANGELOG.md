# Changelog

All notable changes to AdePet are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.2] - 2026-10-26

### Fixed
- Standing still with a summoned pet made the AFK flag flicker ("You are no
  longer AFK" immediately followed by "You are now AFK", can cosidered as boting).
  The addon now makes no pet queries at all while the player is AFK and resumes
  on the first check after the flag is cleared.

### Changed
- Timer work now runs in one-second ticks, so the hunger check interval is
  accurate to about a second.
- `/adepet debug` also shows the current AFK state.

## [1.0.1] - 2026-10-10

### Fixed
- The "Pet is hungry" warning never appeared at maximum loyalty (Level 6). The
  hunger timer stopped running while the window was hidden; it now runs
  independently of the window.

### Added
- `/adepet debug` prints the raw pet happiness and loyalty values returned by
  the client, for troubleshooting.

## [1.0] - 2026-10-08

First release.

### Added
- Small movable window showing `Pet_Name: Loyalty_Level (Loyalty_Name)`.
- Window width adjusts automatically to the text length.
- Hunter-only: the addon stays inactive for every other class.
- Hunger warning: a "Pet is hungry" line under the pet name when happiness is
  below Happy (yellow for Content, red for Unhappy).
- Hunger check every 15 seconds, after leaving combat, on pet change, and
  right after feeding ends (detected via the "Feed Pet Effect" buff).
- `/hungry X` command to change the hunger check interval (seconds, minimum 1);
  saved per character.
- `/adepet lock`, `/adepet unlock` and `/adepet reset` (alias `/ap`) to lock,
  unlock and reset the window position; position is saved per character.
- At maximum loyalty (Level 6, Best Friend) the window is hidden and shown only
  while the pet is hungry.
- Compatibility with OctoWoW, whose `GetPetLoyalty()` returns text instead of a
  plain number.
