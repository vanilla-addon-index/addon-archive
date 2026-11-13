# Changelog

Changes in OEVG/ShaguTweaks-ClassicAPI, newest first. Entries summarize released behavior; development iterations and test notes belong in `Docs/` and `tests/`.

Based on [Dusk/ShaguTweaks-ClassicAPI](https://octowow.st/git/Dusk/ShaguTweaks-ClassicAPI) at `4391564` (2026-09-08). Earlier history is available upstream.

## 3.8.8 — 2026-11-13 — Extra action bars

- Add two optional 12-button bars with independent slots, native button styling, drag-and-drop transfers to the default bars, and entries in Key Bindings. Action Bar 6 is horizontal and Action Bar 7 is vertical. Both snap to matching native bars with Reduced Actionbar Size enabled.
- Move the Improved Castbar countdown to the right of the bar so it clears the spell name.

## 3.8.7 — 2026-11-08 — Unit frames and minimap buttons

- Add optional owner class colors for pet health bars, including targeted pets with identifiable owners.
- Add an option to remove the class-colored background behind your player name, including on the detached name frame.
- Apply Darkened and Golden UI tints to the Outfitter, TrinketMenu and Atlas-CFM minimap buttons.
- Preserve the Spellbook's original parchment and torn edges in Darkened and Golden UI.

## 3.8.6 — 2026-11-06 — Module fixes and native timers

- Prevent recursive merchant-click hooks when Buy Em All runs alongside another merchant addon.
- Keep the viewed world map unchanged when hovering the Turtle clock.
- Refresh reagent counts when conditional macros change spells, and apply Minimap Clean's hidden state to late addon buttons.
- Keep the dungeon-finder minimap button's size and position stable when dragging it with Enlarged Minimap enabled.
- Stop Sell Junk's completion check when sales stall, and refresh rarity borders/glows when previously uncached item data arrives.
- Use native ClassicAPI cooldown numbers when native countdowns are enabled, retaining the existing appearance and legacy fallback; remove unused static spell/debuff locale data.
- Use native target cast-bar animation and player countdown text where supported, and limit power/portrait styling updates to affected unit frames.
- Use native totem/control-alert timers where supported, and reduce repeated resource/map styling writes and chat-cache allocations.
- Keep swing-timer and cast-bar preview borders above their fills and match them to the selected UI theme.
- Remove AoE Loot and retire its saved setting. See the [migration guide](Docs/EXTRAS_MERGE.md#removed-later) for AutoAreaLoot.

## 3.8.5 — 2026-11-06 — UI polish and initialization cleanup

- Replace the theme checkboxes with one **UI:** dropdown below Search: Default, Darkened or Golden, preserving existing choices.
- Add a version button beside Defaults in Advanced Options, opening a copyable Gitea project link.
- Match equipped-item comparison backgrounds to the source tooltip in Darkened UI.
- Preserve native mail, quest-log and NPC quest/gossip parchment colors and torn edges in both themes, including empty quest-log artwork. Restore Golden UI's darker NPC title strip.
- Keep item-rarity borders and formatted Golden titles consistent when windows update or are recolored again.
- Consolidate deferred initialization, batch duplicate delayed recolors and bound the texture-classification cache while preserving frame exclusions.

## 3.8.4 — 2026-11-06 — Action-bar proc highlights

- Add **Proc & Reactive Spell Highlights** (Action Bar, off): event-driven pale light-blue glows for supported spells and macros, with native pulsing animation where available. Central proc alerts remain with dedicated addons such as Proc Doc.

## 3.8.3 — 2026-11-05 — Personal Resource Display

- Replace **Standalone Player Frame** with **Personal Resource Display**: independent, movable and resizable copies of player health and power, leaving the original player frame intact. Existing health/power positions migrate.
- Add **Hide Player Frame Resources** to keep only the clean portrait and independently movable class-colored name. **Hide Player Name** now requires this option and also hides the raid group number. Resource hiding and the personal display can be used independently.
- Share healing predictions and Energy & Mana Tick timing with the copied bars, including resizing, and retain the active UI border palette.
- Show a small attached mana bar for druids using Personal Resource Display while shapeshifted.
- Remove **Hide Player Portrait** and retire its saved setting.
- Condense the changelog into release summaries, removing intermediate testing history.

## 3.8.2 — 2026-11-04 — Healing predictions and native API improvements

- Add **Healing Predictions** for player and target: incoming direct heals and upcoming HoT ticks, with Big Health/standalone support. Reuse compatible Puppeteer data when available; otherwise use an observed-heal estimator and vanilla HealComm. See [prediction details and limitations](Docs/HEALING_PREDICTION_REVIEW.md).
- Use native ClassicAPI range subscriptions for **Range Color**, with balanced button subscriptions and an older-version fallback.
- Improve **Energy & Mana Tick** handling of power changes, mana-costing casts and regeneration timing; use native spark animation when available.
- Use ClassicAPI's macro icons and command parsing, retaining compatibility for legacy custom hints and other macro addons.
- Use native equipment comparisons where available, including full item links, paired equipment slots and stat differences; keep comparisons stable during Bagshui tooltip refreshes.
- Route health/power number updates separately and use native duration timers for swing/wand displays where supported.
- Remove redundant cast tracking and consolidate movement/startup helpers. Add a shared regression-test runner. See the [cast tracking review](Docs/CAST_TRACKING_REVIEW.md).
- Prevent caster-bar icons showing through empty druid form slots. Clarify that Auto Stance enters forms; ClassicAPI Auto Cancel Form leaves them.

## 3.8.1 — 2026-11-04 — ClassicAPI baseline and legacy cleanup

- Require **ClassicAPI 1.18.10+**, with a startup check and update message for unsupported runtimes.
- Remove **Auto Dismount** and its unused support code in favor of ClassicAPI's settings; retain Auto Stance for entering required forms.
- Respect **Always Show Action Bars** for empty main/bonus-bar slots.
- Fix disappearing Big Health fills after health updates in standalone mode.
- Remove the unused debuff-timing library and legacy per-frame nameplate discovery; retain optional-mod and missing-data compatibility checks.

## 3.8 — 2026-11-04 — Player frames, movable bars and UI polish

- Add **Standalone Player Frame**, detaching the native portrait, name, health and power into movable pieces, with clean rounded artwork, a class-colored name and saved positions. Add **Hide Player Portrait** and standalone-only **Hide Player Name**.
- Split **Big Health** into independent player and target options, migrating existing settings. Standalone power sizing follows the player setting.
- Include action, pet, stance, XP and reputation bar movement in **Reduced Actionbar Size**. Ctrl+Shift+Alt dragging supports saved positions, reset and snapping to visible bars.
- Make cast-bar movement always available and remove its checkbox.
- Give **Loss of Control Alert** classic artwork and borders that follow the active UI mode.
- Preserve native quest/gossip parchment colors and torn edges in Golden/Darkened UI. Golden UI NPC name headers use opaque title artwork; player names retain class styling.
- Extend Modern Class Colors to name backgrounds. Leave TrinketMenu styling to TrinketMenu.
- Remove Debuff Timer and the three nameplate options to avoid overlapping dedicated addons. See [alternatives and migration notes](Docs/EXTRAS_MERGE.md#removed-later).

## 3.7.4 — 2026-11-03 — Advanced Options search

- Add case-insensitive search by option name, description, category and slider label, retaining unsaved changes while filtering.

## 3.7.3 — 2026-11-03 — Golden UI

- Add **Golden UI**, with configurable gold frame/border colors and brown title bars while retaining default text colors. Darkened UI takes precedence when both are selected.
- Share theme handling across native windows and supported addons, including aux/AuxCraft, Bagshui, Outfitter, VCB and RollFor. Preserve parchment, item icons, slot interiors and existing quality colors.
- Extend **Item Rarity Borders** to outgoing mail/TurtleMail attachments and both sides of trade windows, refreshing on item changes and clearing empty slots. **Loot Quality** remains specific to the loot window.
- Center Tooltip Details health text within its bar.

## 3.7.2 — 2026-11-02 — Loss of Control Alert, Totem Timers and movable cast bar

- Add **Loss of Control Alert** and **Totem Timers**, using ClassicAPI events with animation only while active. Both support modifier dragging and reset.
- Add **Movable Cast Bar** and independent movement for swing, wand and enemy cast bars, with saved positions.
- Link the [Extras migration guide](Docs/EXTRAS_MERGE.md) from the README.

## 3.7.1 — 2026-11-02 — Key-Down Casting removed

- Remove **Key-Down Casting** and its dependent **Alt Self-Cast** option in favor of ClassicAPI's native settings. Use `/console ActionButtonUseKeyDown 1` for key-down activation and the native SELFCAST modified click for self-casting.

## 3.7 — 2026-11-02 — Extras modules built in

- Merge Dusk's Extras action-bar, chat, loot, macro, merchant, map, tooltip and abbreviated-name modules, preserving their saved choices. Warn when the separate Extras addon remains enabled.
- Leave raid frames, bag helpers and auction Alt-Buy to dedicated addons. See [the module list](Docs/EXTRAS_MERGE.md).
- Improve XP text legibility with a shadow instead of an outline.

## 3.6 — 2026-11-02 — Map window, Transports button and Loot History

- Add **Loot History**, using ClassicAPI's stored group-roll results, and an OctoBus **Transports** button on the world map.
- Preserve map scale across reopening/reload and allow dragging from its title bar.

## 3.5 — 2026-11-01 — Swing Timer and Wand Timer

- Add classic-style main/off-hand swing timers, queued-attack colors and ranged/wand timing with Hunter wind-up indication, based on brues-code/pfUI.

## 3.4 — 2026-11-01 — Hide Pet Unit Frame and XP numbers

- Add **Hide Pet Unit Frame** and show current/required XP, percentage and rested bonus on hover.

## 3.3 — 2026-11-01 — World map colors and per-frame checks

- Correct class colors for packed world-map raid icons and battleground teammates.
- Limit map, target-of-target portrait and enlarged-minimap checks to relevant visibility/update intervals.

## 3.2 — 2026-11-01 — Performance

- Bound and expire the shared player cache, refresh sighting ages and avoid redundant GUID/guild lookups. See [cache details](Docs/PERFORMANCE.md).
- Throttle Range Color checks and retain Blizzard's native out-of-range hotkey coloring.

## 3.1 — 2026-10-31 — ClassicAPI review and tidy-up

- Prevent duplicate Debuff Timer countdown text with ClassicAPI's native countdown enabled.
- Refresh feature documentation, compatibility notes and repository ignore rules.

## 3.0 — 2026-10-30 — OEVG customization

- Add **Modern Class Colors** and modern health/power textures, including druid mana, plus independent **White Unit Frame Numbers**.
- Place health percentage left and current health right with matching name-font styling. Limit Big Health's resting glow to the portrait.
