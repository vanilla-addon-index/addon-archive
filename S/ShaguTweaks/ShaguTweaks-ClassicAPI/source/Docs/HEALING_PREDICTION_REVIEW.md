# Healing prediction review — 2026-11-04

## Reviewed versions

- ShaguTweaks: local 3.8.2 test build based on `dfe8cea` (3.8.1).
- OEVG's private [Puppeteer](https://octowow.st/git/OEVG/Puppeteer):
  `ee273a93ef7f6d3f60376b601e27a9ec2f49595f`. Fetched `origin/main` and verified
  the clean local checkout matched it. This review does not use upstream
  OldManAlpha Puppeteer as a substitute.

## Implemented in ShaguTweaks

- Prefer Puppeteer's public `PTHealPredict.GetIncomingHealing(guid)` and
  `HookUpdates(callback)` when present and player GUID formats match. Use the
  provider's total once, including its HoTs. Do not add its direct-heal subtotal
  or ShaguTweaks estimates to it.
- Do not start ShaguTweaks' estimator event listener, combat-log processing,
  HealComm reception/broadcasting or expiry polling while this shared provider
  is active. A guarded callback is registered once per provider; repeated
  enable/disable cycles do not accumulate listeners. Puppeteer owns its data
  and its roster of tracked units; this integration does not modify either.
- Without that provider, keep direct cast estimates separate from HoT tick
  samples. Learn periodic amounts only for the two displayed units, by caster
  GUID and spell ID. Observe native aura timing/caster identity and removal;
  unknown amounts or unknown timing are not invented.
- The displayed HoT contribution is **one upcoming tick per active HoT**,
  matching Puppeteer's current total. It is not the sum of every future tick.
  Rejuvenation and Regrowth can coexist; Regrowth's direct cast is not
  confused with its periodic amount. Stopping a direct cast does not remove HoTs.
- Preserve learned values across form changes. Real gear/talent/level changes
  invalidate the standalone player's own estimates. Reuse native positional
  aura getters where possible; scan on events rather than on every frame.
- Expiry work stops when no prediction remains. Explicit Lua 5.0 array-length
  bookkeeping prevents stale entries after repeated HoT expiry/refresh cycles.

## Improvements identified in private Puppeteer (not modified here)

1. **Caster-specific HoT identity.** `AddHot` stores
   `IncomingHots[target][spellName]`; `UpdateCacheHot` and `RemoveHoT` use the
   same name-only identity. If a server permits same-name HoTs from multiple
   casters, the later one overwrites the earlier entry. The ClassicAPI aura
   removal handler also supplies no caster identity to `RemoveHoT`. Prefer
   caster GUID plus spell ID/aura instance, with tests for refresh/remove ordering.
2. **Native expiry rather than a fixed emergency timeout.** The normal path
   removes a HoT on an aura-removal event, but the cleanup fallback drops all
   HoTs after 25 seconds. Actual aura expiry would improve correctness when
   events are missed and avoid treating every effect as the same duration.
3. **Persistent cache validity.** `PTHealCache` and `PTPlayerHealCache` retain
   estimates across sessions; observed values converge gradually. A gear,
   talent, level or build signature for the local player's estimates would
   prevent an old build's values being used until enough new samples arrive.
   Avoid invalidating on form-only spellbook/inventory notifications.
4. **Callback removal API.** `HookUpdates` appends a callback but exposes no
   corresponding removal function. A token/unsubscribe API would allow addon
   integrations to detach cleanly. ShaguTweaks currently registers once and
   guards disabled callbacks.
5. **Clarify HoT semantics.** `GetIncomingHealing` adds each HoT's stored tick
   amount, not all remaining ticks. The UI/help should make this explicit;
   changing to total remaining healing would be a separate behavior change.

## Validation and limits

Lua 5.0 mocks exercise direct/periodic separation, multiple casters,
refresh/removal/expiry, gear changes, shared totals, provider absence/GUID
mismatch, late activation and disabled callbacks. Neither estimator promises
server-authoritative heal amounts. Unknown/cold caches, healing modifiers,
critical heals and remote visibility can affect estimates. Standalone reception
supports explicit-duration vanilla HealComm direct-heal messages; compact/group
protocols are not implemented. Native rendering, real provider event ordering,
and CPU/memory costs still require in-game verification.
