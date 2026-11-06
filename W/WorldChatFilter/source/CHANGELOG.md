# Changelog

## 1.1.2 — 2026-10-14

**German and Polish guild recruitment detection hotfix.** The new rules use multiple contextual signals, not specific guild/player names. Only `/World` messages are filtered; UI, custom lists, SavedVariables and historical statistics remain unchanged. All **40/40 Lua regression tests** passed for the development build before publication.

- **German:** Detect informal social-guild invitations that advertise leveling, casual raids and community benefits together with contact phrases like `Melde dich per PM`, `Meldet euch per PN`, or invitations to join—even without class requests or numbered raid slots.
- **Polish:** Recognize direct recruitment by a guild (`gildia rekrutuje`, `poszukuje`, `przyjmuje`) with WoW/raid context even when the message omits explicit player words like `graczy` or `osób`. Support additional Polish raid spellings (`rajd`, `rajdy`, `raidy`).
- **Safeguards:** Preserve normal conversation, reported advertisements and negated references. Require multiple recruitment signals; never blacklist guild or player names.
- **Tests:** New German and Polish fixtures cover original leak examples, paraphrased adverts, ordinary conversations, Careful/Balanced/Aggressive thresholds, non-World channel isolation, category/master toggles and the user's own messages.

## 1.1.1 — 2026-10-14

**Multilingual guild advertisement detection hotfix.** Builds on the official v1.1.0; no settings migration, UI changes or new dependencies. Only the World chat channel is filtered. All 39 Lua regression test files passed on the v1.1-dev branch before release.

- **Swedish:** Recognize tagged guild welcome/recruitment pitches like `Alla är välkomna` alongside gameplay activities such as `levla`, `chilla` and `raida`, including Swedish diacritics.
- **Polish:** Recognize recruitment phrases `szuka osób` and `szukamy graczy` with guild/team and WoW context; also catch `rekrutują lvlujących i Raiderów` with Azeroth/leveling cues and `napisz do nas`. Match accented and accentless variants.
- **Spanish:** Detect promotional guild/community showcases with active members, PvE/weekly raids (including MC25/Kara10) and calls to contact such as `/whisp para info`, even without `reclutamos`.
- **French:** Recognize guild invitations such as `recrute tout joueur` and `nous sommes ouverts aux joueurs en lvling` alongside MC/Ony/Octo context.
- **False-positive protections:** Require combined recruitment evidence rather than isolated words, support quoted/reported-discussion exclusions, and prevent negated `nie WoW` from counting as positive WoW context. No specific guild or player names are blacklisted.
- **Regression coverage:** Add dedicated Swedish, Polish, Spanish and French test files, including Careful/Balanced/Aggressive, non-World channels, master and Guild toggles, own messages, and everyday conversations.

## 1.1.0 — 2026-10-13

**Official v1.1 release.** All features below were developed and tested on `v1.1-dev`, with 35/35 Lua regression tests passing before publication. Only /World is filtered; existing settings, historical statistics and personal block lists are retained.

- Restyle the Statistics panel with the Dark Arcane theme, unified bronze controls, clean counters and in-panel two-step reset confirmation (no chat spam).
- Add a Help / Commands panel with General, Custom Filters and Tools tabs, real supported slash commands and usage tips. `/wcf help` and the existing settings-menu entry now open the panel instead of printing commands in chat.
- Restyle the Custom Filters manager as **Dark Arcane Blizzard**: cohesive slate/bronze buttons and tabs, Dusty Gold highlights, sage/gray filtering status, strong dark backdrop, subtle row stripes, understated Remove buttons, and dual Partial/Whole Word controls. All textures and APIs are Vanilla 1.12 compatible; stored custom filters remain unchanged.
- Redesign Custom Filters as a narrower Blizzard-style window with original Vanilla tabs for Blocked Players / Words & Phrases, one named input, contextual match controls, and an opaque backdrop.
- Use a shared six-row paginated list with clear Remove buttons, per-tab paging, per-tab entry counts, and automatic navigation to freshly added entries; existing saved lists remain intact.
- Fix clipped/missing middle border in the Blocked Words / Phrases input by assigning unique global names to both Vanilla `InputBoxTemplate` edit boxes (required for `$parent` texture anchors).
- Add custom World-only player/word/phrase filters, a paginated native settings panel, case-insensitive partial and whole-word matching, and saved per-character lists.
- Add Block/Unblock from World Chat to the 1.12 chat player's right-click FRIEND popup without invoking Blizzard /ignore. Track custom blocks separately in statistics; the master toggle and World-only channel gate remain authoritative.
- Add `/wcf custom`, `/wcf block player|text|word`, and `/wcf unblock player|text` commands for quick control.
- Add `/wcf toggle` as a single-button macro command: saves the ON/OFF state, prints the status, and refreshes the World color/UI. All category preferences and other chat channels are preserved.
- Development-only changes on `v1.1-dev`, independent from `main` and stable v1.0.1.

## 1.0.1 — 2026-10-13

- Detect direct guild join invitations without the literal word `recruiting` (for example `Join THE CULT, we're a social guild`).
- Default World color is now Dusty Gold (`#D1B77F`); Color Presets submenu opens to the left instead of overlapping the main menu. Existing user-selected colors are retained.
- Reset Color returns to Dusty Gold.
- Detect `LF` immediately followed by a linked enchant/recipe (`LF[Enchant Weapon - Spell Power]`), with or without spaces/counts; support native enchant/spell/item/tradeskill hyperlinks. Keep crafting links under Services rather than Trade and allow normal link discussions.

- Recognize leading `LF` with or without a number plus class/role/spec or dungeon/raid/BG, including Vanilla and Turtle WoW full names/abbreviations (`LF4 RAZORFEN KRAUL`, `LF RFK`).
- Regression tests for optional counts, ordinary chat and World-channel isolation.


## 0.3.23 — Beta (2026-10-12)

- Recognize short `LF + dungeon` ads, including Scarlet Graveyard variants.
- Recognize numbered group needs such as `need 1 heal for ...` with unknown destinations.
- Recognize compact role compositions like `DEADMINES HEAL 2DPS`.
- Add regression tests for these patterns, ordinary chat and World/Trade isolation.
- Keep the color picker, statistics and other features unchanged.

## 1.0.0 — 2026-10-12

Initial stable release based on **v0.3.23**, including the latest contextual LFG fixes.

- World-only contextual detection for trade, group finding, guild recruitment, professions/services, summon/taxi listings, and repeat spam.
- Expanded short-hand LFG detection (e.g., `LF7M`, `LF 1M`, `LF1Healer`, `LF 2 DPS`, and class variants).
- Multilingual and indirect guild recruitment detection without guild-name blacklists.
- Expanded English and Italian guild recruitment patterns, including PvP/PvE communities.
- Scheduled PUG/raid recruitment detection using role/class demand and recurring event context.
- Local per-character statistics, sensitivity settings, minimap button, and diagnostic commands.
- Optional World-only color tint with four presets and a native RGB picker.
- Standalone addon, with no SocialChat dependency.
- Performance improvements to classifier lookups and repeat-history cleanup from earlier betas.

**Known limitations:** Rule-based filtering cannot guarantee zero misses or false positives. The channel must be named `World`. Competing chat and color addons may affect appearance/behavior.