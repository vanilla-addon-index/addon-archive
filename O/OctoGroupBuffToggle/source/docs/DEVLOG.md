# GroupBuffToggle — narrative development journal

**Project creator and creative director:** Babuni.dev  
**Retrospective prepared:** October 27, 2026. Sources inspected: current 303-line Lua, manifest, MIT LICENSE, README, saved-data migration helper and fixture, September Git patches and GitHub v1.2.0 release metadata. This is **not** a recovered transcript of original planning conversations.

## The question is not whether buffs exist, but whether the player wants to see them

Group Buff Toggle is a good example of an addon whose small scale is the point. It does not build a new combat system, automate group maintenance or turn every spell effect into an alert. It makes a narrow visual request: let me inspect the **beneficial effects on my party and my target** without covering the existing unit frames.

The creator's solution is spatial rather than statistical. Four normal `PartyMemberFrame` units and the normal `TargetFrame` stay in place. If the player opts in, compact grids of aura icons appear to their right—no separate window, no hovering status meter elsewhere on the screen and no requirement to keep tracking an entire raid.

Each grid is two rows of eight icon buttons. At 20 pixels each with a 2-pixel gap, it is small enough to fit beside familiar unit frames but wide enough to present a substantial buff list. A hover surfaces the game's native `GameTooltip:SetUnitBuff` information, so the icon itself doesn't have to explain what the spell does.

This intent is attributed to **Babuni.dev** as creator, not to the AI documenting the work later. The available repository doesn't contain the first brainstorm or direct statements of every reason behind the layout. We can faithfully describe what the source and original README say without inventing a design meeting.

## September 10, 2026 — the first committed Octo Group Buff Toggle

The repository's first visible commit, **`31411b3c252b`** (“Initial release”), is dated **September 10**. It introduced the name **Octo Group Buff Toggle**, `OctoGroupBuffToggle.lua`, a version **1.1.0** TOC, a README and an explicit MIT license with the creator's earlier pseudonym.

The initial implementation already had both party and target buff displays and their respective native-looking checkboxes. It relied on `UnitBuff` rather than duplicating a spell database. That saved a large amount of maintainable content and let the game supply icons directly. The code worked with the four default party frames and the target frame, not modern raid APIs or re-skinning every unit.

One decision makes the addon polite: **both buff overlays default off**. On a first installation, a small checkbox becomes available in context but the player has to enable the extra aura information. The source doesn't presume the screen needs more icons simply because the addon is installed.

The original `/groupbuffs` was a straightforward single toggle for party buffs. This was not yet a full preference interface. The initial README described only two saved display settings, matching that earlier design. Its later continued use of the phrase “stores only two settings” became outdated.

The first version was already usable-shaped. Still, an upload and version number alone do not prove a particular game-client playtest or a series of rejected visual sketches.

## Later September 10 — moving from two switches to four

Just minutes after the initial commit, **`c20bc1805b1f`**, “Add independent slash controls,” introduced a small but conceptually important extension. The code gained **`groupCheckbox`** and **`targetCheckbox`** SavedVariables, on top of the original party and target overlay flags.

This separated **the state of the information** from **the state of its control**. Perhaps a player likes seeing buffs but doesn't want the checkbox to remain visible. Perhaps they want the toggle there but prefer the icons off until a particular encounter. The implementation now supports both with explicit `/groupbuffs group / groupbox / target / targetbox on|off|toggle` commands.

Importantly, hiding the checkbox was not implemented as another way of disabling buffs. The two pieces are independent: the button can disappear while its corresponding aura strip keeps showing, and the slash commands remain available. This makes the addon more flexible without adding another settings panel.

The command parser also added aliases for party vs group and checkbox names, status reporting on blank/unknown input, and updates to the displayed check state when settings are changed from chat. Version advanced from **1.1.0** to **1.2.0** in the manifest.

The actual commit proves the code change. It doesn't contain the conversation that prompted it, whether an AI suggested the extra controls, or whether a specific party member complained about clutter. This journal deliberately does not claim any of that.

## The small engineering decisions supporting the gesture

The 303-line current Lua file demonstrates how much detail is needed to make a small visual addition feel as though it belongs to the game. For each party member the addon creates sixteen hoverable icon buttons and anchors their container just beyond the right edge of the default party frame. The target gets its own matching grid at an offset that fits beside Blizzard's target artwork.

The party checkbox doesn't float at a fixed world-screen coordinate. The source scans the party members from fourth down to first, finds the last visible populated frame and puts the checkbox just below that member. As the group grows, it moves with the list. The target checkbox follows the target frame and hides when there is no target.

The source refreshes on world entry, group changes and aura updates. A half-second periodic pass also rechecks frame visibility and position. This is a straightforward legacy-client solution: older addons have limited layout change signals, so polling ensures the display can recover from missed updates. It also creates repeated work even when nothing changed; performance should be assessed in a real client instead of assumed good or bad.

The icon-border texture uses a file named `UI-Debuff-Overlays`, which could mislead someone reading the name alone. The code's data path is `UnitBuff`: it shows **buffs**, not a separate debuff list. There are no aura duration numbers, charge overlays, timers, dispel hints, group-message logs or raid-unit panels. These absences are part of an honest source inventory, not evidence that features were intentionally rejected in an unavailable discussion.

## September 18 — renaming without sacrificing preferences

On **September 18**, commit **`59f925060d5a`**, “Use provider-neutral names and client compatibility descriptions,” changed the project's visible identity from **Octo Group Buff Toggle** to **Group Buff Toggle**. This was a practical step toward letting the addon stand by its own purpose rather than a named Vanilla server.

The change was deeper than a README title. File names, TOC identity, UI global names and SavedVariables changed from `OctoGroupBuffsDB` to **`GroupBuffsDB`**. A player who had customized the four switches under the old addon name wouldn't automatically have those settings in the new folder.

The project therefore added **`Upgrade-SavedData.ps1`** and **`tests/test_upgrade.ps1`**. The helper reads old/new saved-variable names from their TOCs, makes backups under `AddonUpgradeBackups`, creates new files without overwriting existing destinations, and rewrites the top-level root assignment. Its fixture simulates account and per-character save paths, Unicode, preservation of originals and overwrite/path-name refusal.

This is a modest but meaningful form of authorship: if the purpose is to make the player's game more comfortable, a name change shouldn't casually reset their chosen comfort. No migration script was executed during the October documentation audit, so the narrative distinguishes safeguards visible in code from successful execution on real saved files.

A [v1.2.0 GitHub release](https://github.com/babunidev/GroupBuffToggle/releases/tag/v1.2.0) was published the same day with **GroupBuffToggle.zip** and **SHA256SUMS.txt**. The release notes report packaging/syntax and migration checks, but still recommend live in-game validation. Such notes are evidence of what was reported at release, **not** evidence that this assistant independently ran a test.

## October 26 — proper attribution and a licensing distinction

The October 26 commits established **Babuni.dev** in the TOC and README and changed the existing **MIT LICENSE** copyright line from the creator's earlier pseudonym to **Babuni.dev**. Later commits added a compact documentation skeleton (CONCEPT, ROADMAP, CHANGELOG, AGENTS and three docs) and linked it from README.

This is a difference from several other Babuni.dev addon repositories in the same audit. GroupBuffToggle has an explicit license, and its terms were present from the first Git upload. The documentation should not describe it as unlicensed or insert a competing license. The MIT notice remains exactly as committed.

The current October 27 review extends the existing skeleton into a substantive design record, content/data inventory, architecture, verification plan, decision history and human–AI methodology. It corrects one visible mismatch: the original README says it saves “only two settings,” but the later current version actually saves **four** independent flags. No Lua change is necessary to document that accurately.

**Human contribution:** the original concept, visual direction and authority over the addon; implementation choices visible through commits. **AI contribution in this session:** reading source/history, comparing descriptions to code, writing and committing documentation, pointing out limits and tests. The record does **not** identify every original author of every Lua line or recreate missing private discussions.

**Verified in this session:** source, current license, TOC, change chronology, release metadata, new Markdown links and unchanged non-document files (after commit verification). **Not done:** run WoW 1.12, observe a live party aura change, install competing unit-frame mods, run PowerShell migration fixtures, download/recalculate the release ZIP digest, or handle real user SavedVariables.

## What a meaningful next test would show

The next useful chapter should be based on actual play: a Shaman or other character in a five-member party, buff icons appearing beside the right players, a target whose auras change, and the two checkboxes hidden and restored independently of their overlays. Test a player joining/leaving, a buff falling off, and another addon affecting the default frames.

The publishable story is not about a complex invention. It is about making **a very small information display respectful of the player's space**—and then refining its controls so the player can keep exactly the information and exactly the UI affordance they want.
