# Changelog

## v0.2.6-alpha — 2026-10-31

- Drop a DoT when ClassicAPI 1.17.10+ reports its damage as IMMUNE (DAMAGE_SHIELD_MISSED), for example Immolate on a fire-immune mob. Previously it stayed tracked at full value and could show a false skull.
- README: remove the wow_turbo mention.

## v0.2.5-alpha — 2026-10-24

- Add independent options to disable every display while in a party or raid.
- Resume displays automatically when leaving the relevant group type.
- Keep tracking active while hidden; raid detection takes priority over party.

## v0.2.4-alpha — 2026-10-24

- Keep English UI text and spell-description parsing only.
- Remove the six translated locale files and their TOC entries.
- Remove translated spell fixtures and keep the English tracking regression suite.

## v0.2.3-alpha — 2026-10-24

- Fix an unavailable StatusBar GetOrientation call on the 1.18.1 client.
- Read vertical layout from pfUI configuration instead.
- Remove GetOrientation from the test widget API to catch future regressions.

## v0.2.2-alpha — 2026-10-24

- Automatically attach to pfUI target/focus health bars and visible portraits.
- Use pfUI replacement nameplate bars instead of disabled Blizzard originals.
- Place nameplate labels below visible cast bars when necessary.
- Re-evaluate late-created or replaced frames while retaining custom overrides.
- Reuse the target overlay when its health-bar host changes.
- Support vertical bars and pfUI's inverted unit health display.
- Add pfUI regression cases; live pfUI confirmation remains pending.

## v0.2.1-alpha — 2026-10-24

First public alpha candidate, made for 1.12 / 1.18.1 clients; tested only on 1.18.1 (build 7272). Settings persistence confirmed in-game.

### Added

- ClassicAPI port of DoesItDie's tracking, spell parsers, and translations.
- Nampower actual-health reading, with safe behavior when HP is unknown.
- Target shading, damage labels, and lethal portrait skulls.
- GUID-based nameplate displays and support for reparented health bars.
- Optional focus display when a focus health bar exists.
- Independent display toggles in ClassicAPI's AddOn Options window.
- Tracking policies, skull previews, and spell/API diagnostics.
- Bundled skull asset, replay tests, and a verified release builder.

### Fixed during alpha development

- Siphon Life recognition for total-health transfers and decimal durations.
- Target label overlap with the name and frame border.
- Nameplate label overlap with percentage text.
- Skull texture availability, portrait anchoring, and overlay layering.
- Horizontal seam between the skull's head and jaw.

### Known limitations

- 1.12 compatibility has not yet been verified in-game.
- Not every stacking effect or duration modifier is modeled.
- The full upstream visual options, animations, and frame picker are not ported.
- Automated checks use mocked APIs and complement live client testing.
