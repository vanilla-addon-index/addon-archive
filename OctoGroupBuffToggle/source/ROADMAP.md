# GroupBuffToggle — roadmap and verification

**Creator and final decision-maker:** Babuni.dev. **Current implementation:** v1.2.0, interface 11200. Items below are **proposed tests/choices**, not approved behavior changes.

## What source inspection establishes

- **Four** party units (`party1`–`party4`) and one `target`, default Blizzard unit-frame anchoring.
- **16** buff icons per unit, laid out in two rows of eight, at **20 px** with 2 px spacing.
- `UnitBuff(unit,index)` textures, native buff tooltips on hover; no duration/stack rendering.
- Two opt-in **buff overlay** switches, plus two independently saved **checkbox visibility** switches in account-wide `GroupBuffsDB`.
- No additional libraries, persistent buff history, external app or network services.
- Four event triggers and **0.5-second** periodic refresh; slash controls via `/groupbuffs`.
- Original Sept 10 implementation and same-day independent-controls refinement; Sept 18 rename/upgrade helper.
- Explicit [MIT License](LICENSE) with Babuni.dev notice.
- A [v1.2.0 published release](https://github.com/babunidev/GroupBuffToggle/releases/tag/v1.2.0) including ZIP and SHA256SUMS. Its historical notes **report** syntax/migration checks; not rerun here.

## P0 — verify intended 1.12 behavior

1. Install on the intended **WoW 1.12** client; record build, active unit-frame addons, Lua errors, and successful TOC load.
2. Confirm on first install **buff displays off** and **checkbox visibility enabled**, with checkboxes only appearing when a unit frame exists.
3. Join parties of sizes two to five and check party1–party4 overlays and which frame the party checkbox anchors below. Leave the group; confirm controls and grids hide cleanly without orphan frames.
4. Select a friendly unit, hostile unit with buffs, dead unit, targetless state and targets with 0/1/8/9/16/more-than-16 buffs. Verify 16-icon truncation and tooltip correctness.
5. Test both buff overlay switches independently, then hide one checkbox **without turning off its icons**; use `/groupbuffs group on` and equivalent target command to prove hidden-checkbox control.
6. Test all `on`, `off`, `toggle` and aliases, blank/help/status output, and persistence after `/reload`, logging out and switching account characters.
7. Verify icons update promptly on `UNIT_AURA`, party changes and periodic refresh. Confirm obsolete buff buttons are hidden when aura counts shrink or unit positions change.
8. Ensure the addon does not overwrite or modify Blizzard's existing target/party frame contents.

## P1 — interoperability and accessibility

9. Test normal UI scale, enlarged UI, ultra-wide and low-resolution clients; avoid overlaps with target frame combat icons, cast bars, buff bars and party text.
10. Test with **unit-frame replacements**: document that absence of `PartyMemberFrameN` or `TargetFrame` may make grids unavailable; don't claim unsupported combinations work.
11. Test with other addons that supply separate aura icons; look for redundancy, overlay conflicts and mouse-hit areas.
12. Verify native tooltip display/hiding and the correct `SetUnitBuff` unit/index after targeting and group roster changes.
13. Profile the **0.5-second polling** behavior in a five-member party with all icons visible and when disabled; the code refreshes frames even without active overlay.
14. Test color/readability and accessible alternative to icon-only information (the native tooltip). No accessibility test performed in this audit.

## P2 — continuity and packaging

15. Execute [tests/test_upgrade.ps1](tests/test_upgrade.ps1) in PowerShell and capture actual output. Test a backup copy of old OctoGroupBuffToggle settings with the game shut down; never overwrite sole user data.
16. Download the [v1.2.0 ZIP](https://github.com/babunidev/GroupBuffToggle/releases/tag/v1.2.0) and compare it with published SHA256SUMS; inspect content against the current manifest. Asset bytes were not inspected here.
17. Retain and verify the existing **MIT LICENSE** and Babuni.dev copyright in packaging and future copies.
18. Consider adding a focused stubbed-Lua test for four-switch semantics and unit-slot/tooltip assignment, but do not pretend that mocks prove WoW-client behavior.

## Open creative choices — not approved

- Should checkbox visibility ever depend on whether the overlays are currently on?
- Should 16 icons remain fixed or offer a compact/expanded choice?
- Would buffs need durations, stack numbers or sorting, or would that harm the small original design?
- Should raid frames or custom unit-frame APIs be supported?
- Is half-second polling preferable to narrower event updates?
- Should a temporary **per-character** profile exist instead of shared account settings?

Only the creator may authorize a change. Record tests and decisions in the dev journal before treating these as implemented milestones.
