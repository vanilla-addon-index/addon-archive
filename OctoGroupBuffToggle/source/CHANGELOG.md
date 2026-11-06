# GroupBuffToggle — dated implementation and documentation history

**Creator:** Babuni.dev. Commit timestamps are **evidence of committed changes**, not evidence of full in-game testing.

## 2026-10-27 — portfolio documentation expansion

- Updated README to describe **four saved switches**, not the prior inaccurate “two settings” summary; clarified buff display defaults off and checkbox visibility defaults on.
- Added precise vanilla-client architecture, placement math, 16-icon grid, event/0.5-second polling, commands, compatibility limitations and saved-data migration guidance.
- Wrote design/content/decisions/AI collaboration records and a longer narrative DEVLOG documenting the two September 10 commits and September 18 rename.
- Verified the existing **MIT LICENSE** and published v1.2.0 release with ZIP/checksum metadata. Preserved both without modifications.
- No Lua, TOC, scripts or regression tests changed. **No target-client or fixture tests executed.**

## 2026-09-10 — initial Octo Group Buff Toggle v1.1.0

**`31411b3c252b` (“Initial release”)** introduced `OctoGroupBuffToggle.lua`, TOC, README and MIT LICENSE. The first source already supported four party members and the target, 16 buffs per unit, Blizzard-style Buffs checkboxes, tooltip hover, half-second refresh, account-wide SavedVariables, and **two independent overlays defaulting off**.

Original slash command `/groupbuffs` was a simple party-visibility toggle. The initial license notice named the creator's earlier project pseudonym, later updated to Babuni.dev.

## 2026-09-10 — independent slash and checkbox controls, v1.2.0

**`c20bc1805b1f` (“Add independent slash controls”)** made the important user-experience change. It added `groupCheckbox` and `targetCheckbox` persistent flags and exposed explicit `/groupbuffs group/groupbox/target/targetbox on|off|toggle` controls, plus synonyms and a status/help view. The two checkbox switches **only govern the controls**, not the respective overlays.

This change is visible in the commit; original debugging/user dialogue was not available for reconstruction.

## 2026-09-18 — provider-neutral identity and migration

**`59f925060d5a` (“Use provider-neutral names and client compatibility descriptions”)** renamed source/manifest from OctoGroupBuffToggle to **GroupBuffToggle**, changed saved root **OctoGroupBuffsDB → GroupBuffsDB**, and created PowerShell migration tooling and a synthetic saved-data fixture. The addon version remained **1.2.0**.

The published [v1.2.0 release](https://github.com/babunidev/GroupBuffToggle/releases/tag/v1.2.0) dates to September 18 and contains **GroupBuffToggle.zip** plus **SHA256SUMS.txt**. Its notes report packaging/syntax/migration checks and still recommend game-client verification; this audit didn't rerun them.

## 2026-10-26 — attribution and first documentation scaffold

- **`7ac69414`** changed the TOC author to **Babuni.dev**.
- **`42993801`** added README creator credit.
- **`6fd3590b`** changed the MIT copyright notice from the creator's earlier pseudonym to **Babuni.dev**.
- **`f8b682cf`** created brief CONCEPT, ROADMAP, CHANGELOG, AGENTS, ARCHITECTURE, DECISIONS and DEVLOG.
- **`24f91130`** linked the new documentation from README.

This documentation audit extends that existing history. It does not imply code changes were made in October.
