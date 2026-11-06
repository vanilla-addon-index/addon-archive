# GroupBuffToggle — aura content, UI labels and stored data

**Creator:** Babuni.dev. **Source:** v1.2.0 `GroupBuffToggle.lua` and TOC.

## The content comes from the game, not a static spell list

Unlike a curated combat-addon whitelist, this addon **does not store names or icons for individual spells**. It queries the current game client's **UnitBuff** textures for five possible units:

| Unit token | Vanilla frame anchor | Cap |
| --- | --- | --- |
| `party1` | `PartyMemberFrame1` | 16 buffs |
| `party2` | `PartyMemberFrame2` | 16 buffs |
| `party3` | `PartyMemberFrame3` | 16 buffs |
| `party4` | `PartyMemberFrame4` | 16 buffs |
| `target` | `TargetFrame` | 16 buffs |

The game supplies textures, their order and the tooltip returned for the unit/index. The addon doesn't generate individual buff names, build a spell database, communicate with the party or log aura history.

## Authored controls and text

- The two checkboxes use the simple label **Buffs**.
- Party checkbox tooltip: **Group Buffs**, explaining party-member buffs beside group frames.
- Target checkbox tooltip: **Target Buffs**, explaining buffs beside the target frame.
- Chat command prefix uses **Group Buffs:** and shows command status.
- Slash help displays `group`, `groupbox`, `target`, `targetbox` with `on|off|toggle` choices.

The names are English literals, but individual buff tooltips come from the game. The project contains **no localization directory** or translated settings UI.

## Saved flags

`GroupBuffsDB`, account-wide:

| Field | Initial value | Meaning |
| --- | --- | --- |
| `enabled` | false | Party buff grid visible when appropriate |
| `targetEnabled` | false | Target buff grid visible when appropriate |
| `groupCheckbox` | true | Show contextual party Buffs checkbox |
| `targetCheckbox` | true | Show contextual target Buffs checkbox |

The settings persist through game SavedVariables, shared across characters in the account. There is no persisted buff content, player name, target identity, instance or session history.

The older project data used `OctoGroupBuffsDB` until the September 18 rename; users need the documented migration if moving existing configuration.

## Assets and provenance

The addon bundles **no screenshots, custom icons, fonts or images**. Buff textures and border materials come from the WoW client via `UnitBuff`, `UICheckButtonTemplate`, `UI-Debuff-Overlays`, etc., not from a new art collection in the repository.

A real **MIT License** is included, with **2026 Babuni.dev** copyright. The license applies to the repository's software/documentation as written; it doesn't transfer ownership of Blizzard game assets to Babuni.dev or an AI assistant.

The published [v1.2.0 release](https://github.com/babunidev/GroupBuffToggle/releases/tag/v1.2.0) contains a ZIP and checksum, but those bytes were not downloaded or compared during this documentation task. No private aura state was exported.
