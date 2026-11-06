# Nameplates roadmap

Status of pandaUI's nameplates (`modules/nameplates.lua`, settings in
`modules/nameplatesettings.lua`) against ShaguPlates' nameplate options
(`C:\Games\Azeroth Launcher\diagnostics\shaguplates-index`), ported from
UnrealUI's adaptation (`unrealUI/NAMEPLATES_ROADMAP.md`, 2026-10-20).
ShaguPlates and UnrealUI are reference for intent only. No ShaguPlates code,
config schema or assets are copied. UnrealUI findings are leads, not OctoWoW
evidence.

Legend: **Done** = implemented and confirmed in game · **Done (untested)** =
code is in, compiler-checked only · **Blocked** = needs runtime evidence first
· **Won't do** = out of scope.

## State (2026-10-20)

Phases 0–2 are ported. None of it has run on OctoWoW. This needs a **client
relaunch**, because the TOC gained `core/playercache.lua` and
`modules/nameplatesettings.lua`.

**Reported 2026-10-27:** the observed issue may be a conflict with ShaguTweaks
and ShaguTweaks Extra. Confirm with each addon disabled independently before
changing pandaUI.

## OctoWoW differences from UnrealUI (deliberate)

| UnrealUI | pandaUI | Why |
|---|---|---|
| Reaction from the bundled VMaNGOS faction table (`Database/unit_reactions.lua`) | Native bar tint (`GetStatusBarColor`, pfUI-octo's route), then the name learned from the target or mouseover, then the player cache | Octo's plate is the stock 1.12 plate with a tinted health bar. Unreal's has neither. The table was not ported. |
| `PLATE_LIFT`, invisible `NAMEPLATE_FONT`, every-frame `WatchPlates`, `MuteNativePlate` on every pass | Not ported | Unreal flicker workarounds. |
| Modern WoW `backgroundWindow` mapping (`style.LayoutArt`) | pandaUI's own `backgroundInset` anchoring, kept | Octo's art is repacked (client-safe sheet, padded `nameplate-selected`). |
| Modern WoW cast art, spell icon, `/uui npcast` preview | Retail-look target cast bar with spark and icon inside (2026-10-26, untested); no `npcast` preview | Icon placement: `style.LayoutCastIcon`. |
| Level-size slider disabled | Kept disabled | Unreal user report. Unverified on Octo. Re-enable once tested. |

## Phase 0: Foundation

Already in pandaUI before this port: discovery, muting, three themes, name,
level and health, tint reaction, target debuffs and cast, fade. Still
**untested** (`nameplates.pandaui_theme_auras_castbar_unverified`).

## Phase 1: Core options (Done, untested)

Settings group **Nameplates**, with four pages: General, Health, Target and
Raid Marks.

| Option | Keys |
|---|---|
| Enable (reload prompt), target debuffs, target cast | `enabled`, `showAuras`, `attachTargetCast` |
| Width, health height (flat / Modern WoW), vertical offset, font sizes | `width`, `healthHeight`, `artHealthHeight`, `verticalOffset`, `nameSize`, `levelSize`, `healthTextSize` |
| Hostile / friendly plates | `showHostile`, `showFriendly`, via `Show/HideNameplates` and `Show/HideFriendNameplates` (documented 1.12.1 FrameXML calls) |
| Health text format, position, number abbreviation | `healthFormat` (default `curmax` from `core/unitvitals.lua`, falling back to percent), `healthTextPos`, `abbrevNumbers` |
| Hide health per disposition, with target and damaged exceptions | `hide*`, `keepHealthTarget`, `keepHealthDamaged` |
| Fade, target zoom, target outline and colour, reaction outlines | `fadeOthers`, `otherAlpha`, `targetZoom*`, `targetOutline`, `highlightR/G/B`, `outline*` |
| Raid marks | `raidIcon*`. Target: `GetRaidTargetIndex`. Others: the native region's texture cell. |
| Show / abbreviate names | `showName`, `abbrevNames` (on by default, UTF-8 safe). Names over 18 characters after that end in "..." (`style.NAME_LIMIT`). |

**Visual change:** the flat themes no longer draw a resting border or an
accent border on the target. Both are now off-by-default outline options, as
in UnrealUI. Modern WoW keeps its untinted selected frame on the target.

## Phase 2: Conditional features (Done, untested)

| Feature | Notes |
|---|---|
| Class colours (enemy, friendly, friendly name) and guild line | `core/playercache.lua`: player, target, mouseover, party, raid and guild roster. Session-only. |
| Combo points on the target plate | `GetComboPoints("target")`, the same call the unit-frame combo strip makes |
| Totem icons and totem health hiding | `style.TOTEM_IDS` via `U.unitNames`. Works for enUS, ruRU and zhCN; frFR has no name table, so totems aren't recognised there. |
| Critter health hiding | `style.CRITTER_IDS` (93 VMaNGOS type-8 ids) |
| Target plate above overlapping plates | `style.RefreshStrata`: others BACKGROUND, target LOW |

## Blocked (needs Octo evidence or a provider)

| Feature | Octo lead |
|---|---|
| Debuffs on non-target plates | No unit token per plate. See "Without a DLL" (name-keyed estimate) and "Optional DLL path" below. |
| Casts on non-target plates | `UnitCastingInfo` is absent. See "Without a DLL" (combat log) and "Optional DLL path" below. |
| Clickthrough, overlap, right-click mouselook | `EnableMouse` on a native plate is unprobed. |
| Client nameplate key state (`NAMEPLATES_ON`) | Unverified. |

## Without a DLL: possible workarounds (not implemented)

Both reuse code pandaUI already ships. Both key data by **name**, so two nearby
mobs with the same name cannot be told apart. That is the same limit
ShaguPlates has on Vanilla without SuperWoW.

| Feature | Route | Reuses | Limits |
|---|---|---|---|
| Casts on non-target plates | Combat log: `SPELLCASTOTHERSTART` / `SPELLPERFORMOTHERSTART` ("X begins to cast Y") on the `CHAT_MSG_SPELL_*` family, timed from a spell table. ShaguPlates `libs/libcast.lua`. | `modules/castbar.lua` already parses this for the target and the pet, matched to `UnitName("target")`. Generalise it to a per-name cast table that the plates read. | Name only: one mob casting lights every plate with that name. Only spells with a known cast time are drawn. Interrupts and stops are inferred, not reported. Combat log range (~40 yd) and locale strings apply. The parsing itself is not yet confirmed in game on Octo. |
| Debuffs on non-target plates | (1) Exact snapshot: `UnitDebuff("mouseover")` / `("target")`, cached by name + level and shown on matching plates until it expires (ShaguPlates `PlateCacheDebuffs`). (2) Combat log: "X is afflicted by Y" / "Y fades from X" (`CHAT_MSG_SPELL_PERIODIC_*`, `CHAT_MSG_SPELL_AURA_GONE_OTHER`), timed from `core/auradata.lua`. ShaguPlates `libs/libdebuff.lua`. | `core/auradata.lua` (duration table) and `modules/auras.lua` (timer tracking for the target). | Name + level only. The cache goes stale until the next hover or target. Durations are max-rank estimates. "Own debuffs only" works only from your own combat lines. |

**Effort:** medium for casts, larger for debuffs. Both are estimates, so the
UI should show them as such. Record any test in `knowledge.json` before
building on it.

## Optional DLL path (not planned)

Decision 2026-10-20: **pandaUI does not depend on DLLs.** This section records
what they would add, in case that changes. OctoWoW's launcher already ships
nampower, UnitXP_SP3 and VanillaHelpers (knowledge.json
`dll.optional_extensions_feature_detection`). Any use must be feature-detected
once in `core/compat.lua` and keep the stock fallback above.

ShaguPlates' blocked features depend on **SuperWoW**, which OctoWoW does not
ship. The root problem is that a stock 1.12 nameplate has no unit token and no
GUID.

| ShaguPlates feature | Octo DLL lead (`query_api.py`, documentation only) |
|---|---|
| Debuffs on non-target plates | nampower `GetUnitGUID`, `GetUnitData` / `GetUnitField`, `AURA_CAST_ON_OTHER`, `UNIT_DIED` |
| Casts on non-target plates | nampower `SPELL_START_OTHER`, `SPELL_GO_OTHER`, `SPELL_FAILED_OTHER` |
| Combat-state colours (attacking you / others / casting) | nampower spell events plus `GetUnitData` for the unit's target |
| Same-name mobs told apart | A GUID per unit |

**Blocker even with nampower:** no API found that maps a *native plate frame*
to its GUID (SuperWoW names the plate with it). Without that link, a GUID's
cast or debuff cannot be placed on the right plate when names repeat. Probe
this first.

Ready-made client switches in UnitXP_SP3 (no plate code needed):
`modernNameplateDistance` (longer view distance), `prioritizeTargetNameplate`
and `prioritizeMarkedNameplate` (overlap our `style.RefreshStrata`),
`hideCritterNameplate` (removes the whole plate, ours hides only the bar),
`nameplateCombatFilter` and `showInCombatNameplatesNearPlayer`.

nampower `GetUnitData` could also give real HP for players and creatures
missing from `core/unitvitals.lua`.

None of this is verified on OctoWoW.

## Requested (user request 2026-10-26, not started)

**Tank plates / threat mode:** build this once as a complete colour-coded
health-bar feature rather than shipping a percentage display first and
replacing it later. Prefer the player-facing name **Tank plates**. If OctoWoW
cannot provide enough state for a proper tank mode, expose the supported
subset as a **Threat** option instead.

| State | Colour |
|---|---|
| The player has aggro on the mob | Green |
| The player does not have aggro | Red |
| Another tank has aggro | Blue (or another colour) |

The health-bar colours are the preferred display. A threat percentage or
compact indicator above the plate is only a fallback if reliable numeric
threat is available but colour coding cannot represent the supported states.
Do not plan separate percentage and colour upgrades.

Also wanted: a colour choice for a target that is stunned, disoriented or
otherwise crowd-controlled.

**Constraint:** a stock 1.12 plate has no unit token, so threat and CC state
are only readable for the target and mouseover, or by name from the combat log.
The DLL-based combat-state colours sit under "Won't do" until Octo evidence
exists. Probe what is readable first (`UnitExists("targettarget")` for the
target, combat-log aura lines for CC) and record it in `knowledge.json`.

## Won't do

Target glow, font/border/texture pickers, vertical bar, SuperWoW combat-state
colours (no SuperWoW evidence on Octo), `libhealth` (`core/unitvitals.lua`
covers it), Turtle extras, profiles, `/rl` and `/sp`.
