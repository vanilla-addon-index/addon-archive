# Regression checks

Run every suite from the addon root (Linux/WSL with Lua 5.0):

```sh
sh tests/run_all.sh ../tools/lua5.0/lua5.0
```

The interpreter defaults to `lua5.0` if omitted. The runner discovers all
`tests/test_*.lua` files, reports every failure, prints a final count, and exits
unsuccessfully if any suite fails. It is developer tooling, is not loaded by the
addon, and has no in-game overhead. The current suite contains 45 test files.

Individual checks can also be run from the addon root:

```
lua5.0 tests/test_ui_rarity.lua .
lua5.0 tests/test_ui_slot_edges.lua .
lua5.0 tests/test_ui_palette.lua .
lua5.0 tests/test_options_search.lua .
lua5.0 tests/test_player_frame_options.lua .
lua5.0 tests/test_hide_player_resources.lua .
lua5.0 tests/test_personal_resource_display.lua .
lua5.0 tests/test_actionbar_movers.lua .
lua5.0 tests/test_golden_unit_names.lua .
lua5.0 tests/test_quest_parchment.lua .
lua5.0 tests/test_castbar_mover.lua .
lua5.0 tests/test_bighealth_split.lua .
lua5.0 tests/test_loss_of_control_style.lua .
lua5.0 tests/test_health_text_alignment.lua .
lua5.0 tests/test_classicapi_runtime.lua .
lua5.0 tests/test_actionbar_grid.lua .
lua5.0 tests/test_range_events.lua .
lua5.0 tests/test_healing_prediction.lua .
lua5.0 tests/test_healing_shared.lua .
lua5.0 tests/test_cast_tracking.lua .
lua5.0 tests/test_runtime_helpers.lua .
lua5.0 tests/test_health_event_routing.lua .
lua5.0 tests/test_swing_native.lua .
lua5.0 tests/test_energy_tick.lua .
lua5.0 tests/test_macro_native.lua .
lua5.0 tests/test_equip_compare_native.lua .
```

These checks execute private helpers extracted from the production source with
mocked WoW APIs. They cover item qualities, independent option controls, direct
attachment insertion/removal, asymmetric trade offers, empty-slot reuse, palette
filtering, backdrop resets, and deferred-refresh batching with and without native
timers. They also parse the affected modules with Lua 5.0.

The search check loads `config.lua` with mocked frame APIs and exercises
filtering, collapsed categories, empty results, scrolling transitions, widget
reuse, and preservation/application of unsaved settings.

They cannot validate client rendering, actual event order, DLL behavior, or FPS.
In-game testing remains necessary after changes to these paths.

Player-frame checks cover independent resource copies and resource hiding, native
bar/event retention, Big Health sizing, saved positions/sizes, drag/reset,
modifier release and option dependencies. Portrait crops, native animations,
resize rendering and interactions with other addons still need in-game checks.
Compact-frame checks also cover independent name positions/reset, native unit
click forwarding, stopping a hidden drag and persistent raid group-number hiding.

Action-bar checks cover the Reduced Actionbar prerequisite, automatic movement integration, outline-only dragging,
dependent bars, saved anchors, native relayout, reset, hidden progress bars and
mouseover bars. Golden name-header checks cover the opaque texture, active
palette, font/text updates and switching between NPC and player targets. Quest/gossip checks cover native parchment crops, tile dimensions, idempotence and removal of the stationery overlay. Actual action
execution, paging, stances, pet transitions and title-strip rendering need game QA.

Cast-bar checks cover initialization despite an old disabled flag, checkbox removal, saved position protection and reset.

Cast-tracking checks cover authoritative native queries without a duplicate
mirror, demand-driven SuperWoW registration, live channel identity, delayed
failures, expiry/cache limits and Hunter custom timing/hooks. See
[the cast tracking review](../Docs/CAST_TRACKING_REVIEW.md) for ownership and game checks.

Runtime-helper checks load the production API layer and exercise all modifier
combinations, native left/right state precedence, independent deferred startup
requests, preserved fallback delays and removal of one-shot scripts. Action-bar
and resource-display fixtures also use the real shared helpers. In game, verify that
Ctrl+Shift+Alt previews, drag/reset and restored positions still work after login
and reload, including the cast bar, timers and unit frames.

Health routing checks separate health/power events for all three units and retain
identity/startup refreshes and alternate-power updates. Swing checks cover native
capability/method guards, fill/text ownership without a Lua driver, timer reset
cancellation, completion/grace, range and Hunter colors, Maul queue cancellation,
preview suspension/restoration, death and the older-API fallback. Native DLL
animation, actual action-state event delivery and weapon timing still require
game testing. See [the measurement plan](../Docs/PERFORMANCE_TEST_382.md).

Energy/mana checks cover world-entry booleans, form samples, casts versus drains,
channel-stop ownership, proc rejection, native/fallback sweeps, size changes and
idle cancellation. Macro checks cover native ownership/chosen icons, custom
hints and conditions, item-cache retry, release on edit/logout, conditional-only
polling, foreign parser/alias ownership and compatibility paths. Comparison checks
cover full item links, native offsets, Shift, batching and hide/clear ownership,
including item-link tooltips and the old-method fallback.

Comparison regression also simulates native callbacks during construction and
50 consecutive source clear/set refreshes plus 50 source hide/re-show cycles,
including native side effects hiding ShoppingTooltip1/2 and clearing their
owners. Hidden comparisons must rebind to the hovered item button and refill
their native contents synchronously; merely calling Show is insufficient.
An independently hidden comparison recovers without a new source event. The
unchanged visible case still avoids native rebuilds. Changed links/equipment
rebuild; a non-item or persistently hidden source removes comparisons after the
deferred lifecycle check.

Proc-highlight checks cover capability detection, pre-existing procs, direct spells/macros, paging, hidden buttons, event-only updates and native-animation/static paths.

Initialization-hook checks exercise one deferred listener, duplicate dependency checks, callback ordering/context, nested registration, reentrant events, errors, teardown and reactivation using Lua 5.0.

Recolor-audit regressions cover marked rarity preservation during recursive passes, formatted Golden titles, and partial/zero-size mail tile retries without duplicate crops.

Quest-log checks use the inspected Turtle native 512/256-pixel tiles, preserve list and parchment crops, exclude empty-page art, and reject replacement stationery overlays.

Recolor scheduling checks verify immediate/trailing behavior, one pending callback per frame, callback reuse, late children and FIFO cache limits with dynamic name/path changes.

Recolor profiling tests verify opt-in traversal counts, recursive root attribution, unique/repeat visits and that stopped captures no longer receive updates.

Module lifecycle checks cover foreign merchant hook chains and error recovery,
conditional-macro reagent changes, late minimap buttons, Turtle clock map
selection, scaled LFT button dragging, and AoE Loot removal/migration.

Sell Junk checks cover throttled completion, stalled progress, extended active
sales, merchant close, profit reporting and fresh attempts. Item-cache checks
cover cold/warm metadata, native failure replies, hidden/removed/reused slots,
coalesced refreshes, disabled visuals and native/fallback deferred scheduling.

Cooldown checks compare native formatting against TimeConvert at color/unit
boundaries, verify no native Lua update driver, shared formatter reuse, CVar
changes without global writes, ownership flags, native number-only children for
legacy indicators, and fallback timer/clock-wrap behavior. Locale checks retain the class mappings and Hunter fallback names
while rejecting obsolete sections and Turtle debuff writes.

Cast-bar tests cover native duration snapshots and separate reusable fallback
durations, cast/channel direction, pushback, interruption, expiry cancellation,
self-targets, native player fade, target aura layout, mover previews, SuperWoW
timing and older API animation. Unit-frame styling tests cover explicit/legacy
hook contexts, per-unit routing, aliases, startup passes, Druid fixed mana,
packed native colors and corrective updates after artwork overwrites.

Control-timer checks cover native totem fill/text, replacement/expiry, preview
and disable cleanup, timed/untimed control effects, priority changes, silent
school-lockout extensions and older API fallback. Cosmetic checks count skipped
resource-copy writes, party-name lookups and map tint/icon writes, and retain
per-tab spam suppression while pruning the cache in place. These operation
counts do not measure in-game CPU or FPS gains.
