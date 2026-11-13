# ClassicAPI integration updates

## Current integration (3.8.3, 2026-11-05)

The [ClassicAPI/pfUI overlap review](CLASSICAPI_PFUI_REVIEW_382.md) pins current
source revisions and records optional recoloring improvements. Its energy/mana
tick, macro ownership and native equipment comparison recommendations have
subsequently been implemented; other candidates remain recommendations.

ClassicAPI is required, with a minimum loaded DLL version of 1.18.10 and core
timer/nameplate API checks. Install the DLL and its bundled `!!!ClassicAPI` addon
together and fully restart the client after a DLL update. Optional SuperWoW
support is detected separately. Newer APIs are detected per feature rather than
assumed available from the minimum version.

- Range Color uses native action-range subscriptions/change events when present;
  older supported APIs retain a throttled fallback.
- Healing Predictions shares compatible OEVG Puppeteer data when available;
  otherwise it uses a lazy ClassicAPI event/observed-heal estimator with live HoT
  aura timing. See [the estimator review](HEALING_PREDICTION_REVIEW.md).
- Personal Resource Display mirrors the native player bars without a second
  health/power event driver; its health copy shares the existing prediction
  estimator. Resource hiding is independent, and Hide Player Name requires it.
  The former standalone setting/positions migrate; Hide Player Portrait is retired.
- Castbars query ClassicAPI directly. The unused name-keyed cast mirror and
  combat-text parser are removed; SuperWoW supplements missing enemy timing with
  a bounded GUID cache. See [the cast review](CAST_TRACKING_REVIEW.md).
- Swing/wand fill and text use native duration objects/bindings when supported,
  with cancellable boundary timers and no Lua per-frame driver. Older APIs retain
  the throttled path. The implementation follows brues-code/pfUI at `560343b`.
- Health and power events refresh only their respective number overlays;
  identity changes/startup retain complete refreshes. Modifier-key checks and
  the repeated delayed layout initialization use shared API helpers.
- Energy/mana ticks handle login/form payloads and use cast-cost-driven FSR with
  a separately observed regen phase and native spark movement where supported.
  Ordinary macro icons are left to ClassicAPI; only custom legacy hints need
  our adapter. Missing interactive command aliases use native macro parsing.
- Native equipment comparison builds equipped headers/slot selection/stat
  differences from full item links, retaining our Shift and positioning rules.
- Legacy debuff timing and nameplate discovery have been removed. Auto Dismount
  is provided by ClassicAPI; ShaguTweaks Auto Stance remains distinct from Auto
  Cancel Form. Theme recoloring remains unchanged by the latest cleanup.

These focused reviews do not constitute a complete audit of all changes between
ClassicAPI releases. Current automated checks and their limits are listed below.

## Historical review (2026-10-31)

The following sections record the integration written against v1.17.6 and the
subsequent v1.17.7–v1.18.13 review. They describe that snapshot, not the current
feature list. Debuff Timer was removed in 3.8 in favor of
[TargetFrameBuff](https://octowow.st/git/OEVG/TargetFrameBuff), and its unused
library was removed in 3.8.1. See [migration notes](EXTRAS_MERGE.md#removed-later).

### Changes at that time

- **Health correctness:** `UnitHealthMissing` returns a deficit in the same units
  as the health getters. It can be a percentage, so it is no longer used to infer
  absolute health. Direct health and the existing combat-estimation cache remain.
- **Chat identity:** `GetPlayerInfoByGUID` supplies the name in return position 6.
  The synchronous class fallback now checks that name against the requested player.
- **Cooldown rendering:** Target Debuff Timer creates native `Cooldown` frames on
  ClassicAPI 1.17.1+, retaining `Model` frames on older builds. Numeric timers and
  the existing timer dispatcher are preserved.
- **Unit event filtering:** health/power overlays register only player, target and
  pet unit events; the health estimator and target castbar register only target
  unit events. Older clients without `RegisterUnitEvent` use plain registration
  and their existing handler-side checks.
- **Chat payload:** spam filtering and passive sender collection read
  `GetCurrentChatEvent` when available. The filter uses local payload values and
  does not overwrite shared `arg1`/`arg2` globals. The older global path remains.
- **Player-cache duplication:** when native persistence is already enabled and
  `C_PlayerCache.RememberPlayer` succeeds, new chat-only sightings do not also
  create ShaguTweaks SavedVariables records. Native class-only lookups can avoid
  creating another record. Existing records, raw levels and social history stay
  intact. With persistence off or native storage unavailable, the original Lua
  cache behavior remains. The addon never enables native persistence itself.

### Reviewed since v1.17.6

156 ClassicAPI commits (v1.17.7 to v1.18.13) were read against the modules in
this addon.

**Changed here**

- **Debuff Timer:** the native `Cooldown` frame it creates now calls
  `SetHideCountdownNumbers(true)` when available. ClassicAPI can draw its own
  countdown numbers when the `countdownForCooldowns` CVar is `1` (default `0`),
  which would have doubled the timer text this module draws itself.

**Worth knowing, no code change**

- **Nameplate crash fix (v1.18.10):** world-tick subscribers now run after the
  UI draw. Before this, an addon that restyled a nameplate from
  `NAME_PLATE_CREATED` or a `C_Timer` callback could crash the client. No
  crash was traced to this addon, but v1.18.10 or newer is recommended for the
  Nameplates modules.
- **Range Color:** since v1.18.0, `C_Spell.IsSpellInRange` returns `nil` for a
  unit the spell cannot be cast at. The module already treats `nil` as "no
  range to fail", so it needs nothing.
- **Cooldown Numbers:** action, bag and spellbook cooldowns are still 1.12
  indicator Models, and `CooldownFrame_SetTimer` still serves them. The
  module's hook is still required; the native countdown numbers do not replace
  it.
- **Filtered unit events:** `RegisterUnitEvent` now also filters custom events
  that ClassicAPI fires itself (v1.18.9). The vanilla events used here were
  already filtered.

**Not adopted**

- `UNIT_POWER_UPDATE`, `UNIT_POWER_FREQUENT`, `UNIT_MAXPOWER` (v1.18.10): the
  legacy `UNIT_MANA` / `UNIT_ENERGY` / `UNIT_RAGE` events still fire and the
  overlays depend on their payloads. Switching would add a code path without a
  measured gain.
- `UNIT_AURA_DELTA` and aura instance IDs (v1.17.10): the debuff library
  refreshes on `UNIT_AURA` for the target and reads auras by index, so it does
  not need change sets.
- `UNIT_TARGET`, `UnitFacing`, `wipe`, the `Cooldown` countdown formatter and
  the other new APIs: no module here needs them.

At the time of that historical review, its changes had not been tested in game.

## Measuring performance

On current ClassicAPI, the following prints ShaguTweaks' Lua memory in KiB:

```lua
/script UpdateAddOnMemoryUsage(); DEFAULT_CHAT_FRAME:AddMessage(GetAddOnMemoryUsage("ShaguTweaks"))
```

Memory readings include uncollected objects. For comparisons, collect through
GentleGC first and measure at the same point after login and after playing.
Texture/native allocations are not equivalent to this Lua-memory counter.

For a short CPU investigation:

1. Run `/console scriptProfile 1`, then `/reload`.
2. Run `/script ResetCPUUsage()` and play through a representative encounter.
3. Read the total CPU time in milliseconds:
   `/script UpdateAddOnCPUUsage(); DEFAULT_CHAT_FRAME:AddMessage(GetAddOnCPUUsage("ShaguTweaks"))`
4. Run `/console scriptProfile 0`, then `/reload` when finished.

Profiling adds overhead. Compare the same workload and measurement duration;
the cumulative CPU number alone is not an FPS measurement. Profiling is not
turned on by this addon.

## Verification

Changed/new Lua files are parse-checked with a real Lua 5.0 interpreter. The
current 25 mocked regression suites cover UI styling/rarity, options search,
unit-frame layouts, action-bar behavior/movement, runtime guards, range-event
ownership, cast tracking, healing prediction, shared startup/modifier helpers,
health/power routing, native/fallback swing and energy timers, macro ownership
and equipment comparison. Run them together with
`sh tests/run_all.sh ../tools/lua5.0/lua5.0` from the addon root; see
[tests/README.md](../tests/README.md).

These checks do not replace in-game rendering, DLL event-order and combat tests.
The user confirmed the range/healing/cast changes and the final energy/mana,
macro and equipment-comparison paths in game, including stable Bagshui comparisons
after the ownership recovery fix. Automated coverage does not establish every
possible addon/client combination. No memory/FPS
improvement is claimed without a live measurement.

## Primary references

- [ClassicAPI v1.18.13](https://github.com/brues-code/ClassicAPI/releases/tag/v1.18.13)
- [API reference (v1.18.13)](https://github.com/brues-code/ClassicAPI/blob/v1.18.13/docs/API.md)
- [ClassicAPI v1.17.6](https://github.com/brues-code/ClassicAPI/releases/tag/v1.17.6)
- [Nameplate crash fix](https://github.com/brues-code/ClassicAPI/commit/4eb214f)
- [Native cooldown rendering](https://github.com/brues-code/ClassicAPI/commit/b83bb5b52b11ffd51dd59aa7465b1185222f2bd4)
- [Reliable chat payload](https://github.com/brues-code/ClassicAPI/commit/b5aed30a5db5ef033dd9a6619d8f74310787c4c9)
- [Native player-name lookup](https://github.com/brues-code/ClassicAPI/commit/c7bb90895f8802ba837833d5ad1f9acbe0afece4)
