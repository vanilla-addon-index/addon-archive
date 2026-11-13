# ClassicAPI / pfUI overlap review — 3.8.2

Reviewed 2026-11-04 against the current, uncommitted ShaguTweaks build.
This is a source review and implementation shortlist, not a performance result
or a claim that every finding has been reproduced in game. No addon behavior
or recoloring was changed during this review.

Implementation follow-up: the energy/mana, macro ownership and native equipment
comparison work below has now been applied and has three new mocked regression
suites (25 total). The user confirmed the final energy/mana, macro and comparison
paths work in game, including the Bagshui comparison ownership fix. The energy adaptation retains
the original five-second mana sweep and two-second regen baseline; it adopts
phase rejection/native movement, not pfUI's separate configurable FSR bar or its
server-specific agility/regen-aura modifier calculation. Theme candidates remain
unimplemented.

## Sources and coverage

- [ClassicAPI API.md, commit c0b403ba05a917176fa680cbfc96c619c98d46d6](https://github.com/brues-code/ClassicAPI/blob/c0b403ba05a917176fa680cbfc96c619c98d46d6/docs/API.md).
  Downloaded the pinned document after resolving current master. Reviewed its
  system/function catalog and the contracts relevant to this addon. Its roughly
  1.15 MB includes APIs for systems this addon does not implement.
- [brues-code/pfUI, commit 560343bd746e00898606cf756bdfe533a4823110](https://github.com/brues-code/pfUI/tree/560343bd746e00898606cf756bdfe533a4823110).
  Fetched origin and verified the clean reference checkout matches current
  master. Indexed its 90 module/API Lua files and examined the implementations
  overlapping ShaguTweaks, including native timing, events, macros, tooltips,
  inventories, maps, unit frames, skinning, and helper APIs.
- Indexed ShaguTweaks' 83 module and seven library files, plus its API/helpers,
  loader, compatibility files and current TOC. Read the relevant implementations
  and traced consumers for the findings below. API-symbol inventories are only
  discovery aids: a wrapper can already use a native API elsewhere.

| Overlap | Result |
| --- | --- |
| Action bars, range, reagents and macros | Range subscriptions already adopted; macro ownership is the next substantial cleanup opportunity. |
| Player/target frames, health/power, portraits | Routing already separated; energy tick correctness and portrait event routing remain candidates. |
| Cast, swing, loss-of-control, cooldown, totem and roll displays | Swing native timing adopted; several other displays still animate/count down in Lua. |
| Item/tooltip/vendor, bags and mail/trade rarity | Many native item/tooltip APIs already used; equipment comparison can be simplified. Preserve working rarity behavior. |
| Chat, social/player cache | Native identity and cache interfaces already integrated; no justification to delete the Lua cache wholesale. |
| Minimap, map and coordinate helpers | Mostly visibility-gated/throttled; many updates genuinely depend on cursor/unit movement. Profile before further changes. |
| Golden/Dark UI and addon compatibility | Optional candidates listed separately below. Keep the tested implementation intact. |
| Auction replacement, equipment manager, full raid/unit-frame replacement, Glue/login, TTS and similar systems | Not equivalent to current addon features; do not import simply because pfUI or ClassicAPI offers them. |

## Recommended correctness and ownership work

### 1. Energy/mana tick: strongest next candidate

Current source: `mods/unitframes-energy-tick.lua:21` and its event/update handlers.
Reference: pfUI `modules/energytick.lua`.

Three concrete issues are visible in the source:

- The unit filter runs before event dispatch. ClassicAPI's
  PLAYER_ENTERING_WORLD now carries `true` in arg1 on a fresh login; the filter
  rejects it as not equal to `"player"`, skipping initialization. Reload's arg1
  is nil, so this need not reproduce the same way after /reload.
- `lastMana` is seeded on world entry but not on UNIT_DISPLAYPOWER. Changing
  forms can compare an energy value with the previous mana sample or vice versa.
- Any mana loss sets a five-second sweep. A drain such as Mana Burn does not
  establish the same five-second-rule condition as paying for a spell. Any
  sufficiently large gain can also reset the regen sweep, including a potion
  or unrelated mana proc. The spark's initial width/height are captured once,
  so later standalone/Big Health relayout also deserves testing.

pfUI separates power-mode samples, spell-cost/FSR tracking and the periodic regen
phase. It also uses an invisible native status-bar duration to move the spark.
Adapt the model to the existing player mana bar rather than importing pfUI's
unit-frame layout or assuming every Octo/Turtle regen rule matches its comments.

Benefit: correctness first, plus removal of the spark's Lua per-frame movement.
Risk: medium for a full rewrite; low for the login-payload/unit-filter fix alone.
Test mana spending, drains, potions/procs, channels, full mana, form switching,
and Big Health/standalone layouts. Event-filter initialization can be fixed
independently of the broader native-timer conversion.

### 2. Native macro ownership instead of repeated manual scans

Current sources: `mods/macro-icons.lua:18`, `:47`, `:113`;
`mods/macro-tweaks.lua:17` and its slash registrations.

Current ClassicAPI handles native macro conditions, #showtooltip/#show, spell
and item icons, range, cooldown, usability, count and current castsequence step.
It also exposes C_Macro.GetMacroIcon and C_Macro.SetMacroDisplay. The current
Macro Icons module rebuilds a 36-slot macro cache and scans visible action bars
on several events, parses bodies, resolves spellbook slots and may rewrite icons.

There is a concrete behavior difference: ClassicAPI preserves a manually chosen
macro icon and substitutes spell/item artwork only for the question-mark icon.
Our resolver can replace that chosen artwork with GetSpellTexture when the
specified spell resolves. This is a source-level difference, not a reproduced
user complaint. Conditional/item macros already fall back to GetActionTexture
when our parser cannot resolve them; do not claim every conditional macro fails.

Proposed migration: let native #showtooltip/#show own ordinary macros. Retain
the nonstandard `--showtooltip` / `/pfcast` behavior explicitly if desired,
using SetMacroDisplay where appropriate. Review the global SendChatMessage
metadata filter and old /equip, /use, focus and attack aliases against the
installed native command surface. Finding a native macro command does not prove
that an equivalent interactive chat alias exists in SlashCmdList; test both.

Benefit: less parsing/allocation and fewer competing owners; better consistency
with native macro behavior. Risk: medium, due to existing custom syntax, chosen
icons, macro addons and older supported DLLs. Feature/version detection and
tests must precede deletion. Do not remove Macro Tweaks as one undifferentiated
block. pfUI's current `macroicons.lua` is an icon-picker UI, not the same feature.

### 3. Equip Compare can delegate comparison construction

Current source: `mods/equip-compare.lua:21`, `:53`, `:129`.
Reference: pfUI `modules/eqcompare.lua`.

pfUI calls GameTooltip:SetHyperlinkCompareItem for comparison offsets 1 and 2.
ShaguTweaks still maintains an equipment-type-to-slot table and manually shifts
tooltip lines to insert CURRENTLY_EQUIPPED. A guarded native path could replace
much of that construction while retaining our Shift condition, positioning,
font/color style and third-party tooltip behavior.

Benefit: smaller code and native handling of comparison slots/item instances;
likely little FPS effect. Risk: medium visual/compatibility risk. Test rings,
trinkets, dual wield, two-hand weapons, equipped enchants/random suffixes, bags,
links, vendors and simultaneous tooltip addons. Preserve the actual item link,
not just its item ID, when comparing.

## Native runtime opportunities to prioritize after profiling

| Feature | Current work | Native/pfUI approach | Benefit and risk |
| --- | --- | --- | --- |
| Cooldown Numbers | One visible helper OnUpdate per active cooldown, formatting at 0.1 s, plus alpha synchronization. | pfUI configures native Cooldown countdown fonts/formatters. For stock 1.12 Model indicators, retain the original swipe and consider a duration-text binding for our overlay. | Potentially useful with many cooldowns; medium compatibility risk. Stock Models are not native Cooldown frames, so this is not a blanket method substitution. Preserve GCD suppression, TimeConvert formatting, noCooldownCount/pfCooldownType and other addons' ownership; do not enable a global CVar merely to style ours. |
| Loss of Control | While shown, reselects effects, rebuilds metadata and reapplies theme/text/width every 0.05 s. | pfUI reselects on LOC events plus visible-only UNIT_AURA_DELTA and SPELL_UPDATE_COOLDOWN; native duration/countdown handles display timing. | Reduces repeated aura/list scans and formatting during CC. Medium correctness risk: refreshed CC or an already-locked school can extend without a LOC diff event; expiration/selection also need explicit handling. Keep priority and classic styling. |
| Player/target cast displays | Already discover casts on events; remaining Lua work animates text/fill/spark/alpha while visible. | pfUI uses duration objects, native fill-edge anchors and text bindings. | Conditional saving during casts. Medium risk from pushback, channel updates, fade/preview and SuperWoW fallback. Native cast-duration objects are snapshots, not automatically updated: refresh on delay/channel-update events. Remote channels whose start was unseen can still lack native timing. |
| Totem Timers | Four-slot timed text/color/width updates while totems are up. | GetTotemDuration and duration bindings; scheduled 10/5-second color thresholds and expiry; pfUI uses native cooldown displays. | Shaman-only saving; lower priority for the user's druid. Preserve our bar/tooltip/click design rather than copying pfUI's panel layout. Replacements/destruction/preview must cancel old bindings/timers. |
| Class Portraits | Every portrait event refreshes six frames; target-of-target adds a 0.2 s GUID check through the stock updater. | pfUI's chained frames use UNIT_TARGET subscriptions. Update the relevant portrait on unit events and handle same-name target changes by GUID. | Small conditional saving and clearer ownership. Preserve native portrait refresh hooks: stock code can overwrite custom artwork in the same frame. Validate actual event order before removing the safety path. |
| Group roll bars | One shared visible-only Lua loop queries remaining time for every active roll each frame. | Native durations for the fill with event-driven reset/cancel, as other pfUI displays do. | Low priority: already consolidated and runs only during rolls. Native snapshot timing must account for actual roll changes; profile first. |

No table above promises a measured CPU or frame-rate improvement. Native work
still costs client time, even when it disappears from Lua profiling.

## Golden/Dark UI: optional findings only — do not change now

The current implementation is a compatibility recolorer. pfUI replaces or skins
many widgets with its own artwork/backdrops; copying its skin code would change
the look and bypass the fixes that made parchment, slots, rarity and addon borders
correct. There is no documented single ClassicAPI switch that replaces our theme.

| Candidate | What could improve | Risk | Expected benefit |
| --- | --- | --- | --- |
| Read-only theme inspection | A diagnostic using GetDebugName/GetSourceLocation and region/owner inspection could identify the actual texture/addon behind a missed border, reducing trial and error. It need not change any colors. | Low; keep it on demand. | Maintenance/debugging only, no FPS gain. |
| Coalesce repeated deferred recolors | RecolorOnShow currently applies immediately and schedules another pass. Merge multiple pending requests for the same frame while retaining the immediate and trailing behavior. | Moderate: timing relative to row/frame creation is essential. | Probably small; mainly window creation/show bursts. Profile before considering. |
| Texture-path classification/cache and traversal scratch | Recolor traversals create region/child arrays and repeatedly classify texture paths. A bounded path-only classification cache or carefully scoped reusable arrays could avoid some garbage. Name-based exclusions must remain separate; recursive scratch cannot be shared at the same depth, and reused arrays need correct Lua 5.0 lengths. | Low-to-moderate for narrow path caching; moderate for traversal changes. | Small/unmeasured and mostly startup/window-open work. Existing path/region markers and dynamic texture changes must remain correct. |
| Targeted addon lifecycle hooks | pfUI's skins commonly use addon-load or widget-construction hooks. These might narrow the global CreateFrame wrapper in our recolorer. | High compatibility risk: anonymous or late-created Bagshui/aux/VCB/RollFor widgets can be missed. | Unmeasured; avoid unless the wrapper is actually expensive. |
| Explicit native-menu styling | pfUI styles MenuVariants' default/context menu mixins and selection controls. If a current ClassicAPI-created menu is visibly unthemed, a targeted adapter could extend Golden/Dark coverage. | Moderate; pooled/reused controls and checked/disabled states need testing. | Visual consistency only. This is a potential coverage extension, not a confirmed silver-border defect in the user's build. |

Retain all parchment/slot-edge markers, neutral-color checks, rarity preservation,
TrinketMenu exclusions, default-UI guards and the trailing recolor timing. No
recommendation here requires reopening the working recoloring before profiling.

## Small cleanup and deliberate non-changes

- An internal source-reference scan found no production consumer outside api.lua
  for these wrappers: GetNamePlateForUnit, GetDebuffDataByIndex, UnitDebuff,
  GetDebuffType, SetOverrideBindingClick, ClearOverrideBindings, GetMapOverlays
  and UnitInRange. These are cleanup candidates, not proven safe deletions:
  exposed ShaguTweaks APIs may have external consumers. Runtime benefit is
  negligible; capability flags may still be needed by other helpers.
- Macro migration could shrink libspell/libtipscan further. Currently the macro
  module uses GetSpellIndex and Hunter emulation uses GetSpellInfo. Both
  libraries' scanners are lazy. Do not delete them before migrating these users
  and deciding how to preserve their public interfaces.
- Keep libnameplate: Golden/Dark compatibility registers its callbacks for
  ShaguPlates. It is dormant without consumers and is not an unused library.
- Native HookScript/hooksecurefunc can simplify selected hook sites, but replacing
  our helper globally is unsafe without an argument/order audit. Our helper
  supports prepend and returns a fixed legacy argument shape; native script
  handlers can receive explicit self/event arguments. Styling locks deliberately
  replace methods to intercept colors, which a simple posthook does not replace.
- Keep Auto Stance; ClassicAPI Auto Cancel Form handles the opposite operation.
  pfUI's older autoshift/error handler is not a better replacement for ours.
- Keep observed/shared healing prediction. The reviewed API has healing bonus
  and spell metadata, not a complete authoritative incoming-heal total. Raw DBC
  effects alone cannot safely replace the estimator or the Puppeteer source.
- Keep independent Range Color subscriptions and the existing native merchant,
  item-cache, loot-history, gossip, map-overlay and player-cache integrations.
  Many of the obvious pfUI native implementations are already represented here.
- A cursor-following tooltip still needs movement observation; pfUI also uses a
  visible-only follower. World-map coordinates must track moving cursors/units.
  Replacing every visible OnUpdate with a ticker is not inherently faster.
- ClassicAPI now documents syntax transpilation, extra Lua library functions and
  a raised upvalue limit. That does not supersede this repository's Lua 5.0
  coding/testing rules. Do not modernize syntax merely for stylistic cleanup.
- Do not add pfUI's bags, auction/raid-frame replacements, equipment manager,
  alternate heal model or other large features solely for parity. Existing
  dedicated addons and the user's chosen Blizzard styling remain the design.

## Suggested order at the time of review

1. Energy-tick initialization/form-sample fixes; then decide whether to adopt its
   native sweep and more accurate regen/FSR model.
2. Native macro ownership migration with a clear policy for the two custom
   syntaxes and chosen macro icons.
3. Native equipment comparison if that behavior change is wanted.
4. Profile the current build to select among cooldown, LOC, cast, portrait and
   other runtime candidates. Keep theme candidates documented unless a real
   defect or measured bottleneck justifies their risk.

The existing 22 regression suites passed before this documentation-only review.
The later implementation follow-up noted above added three suites (25 total)
for energy/mana, macros and native equipment comparison. Other recommendations
remain unimplemented and have no measured performance benefit.
