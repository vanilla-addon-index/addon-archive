# 3.8.2 final validation and measurement

Only the player can run these checks in the game. No performance gain has been
measured by the automated tests. The live game folder was not modified.

## First verify behavior

- Real Health Numbers: take damage, heal, spend/regenerate power, switch targets
  and summon/dismiss a pet. Druid forms should show the appropriate resource and
  update the separate mana display. Check Big Health and standalone layouts.
- Swing/Wand Timer: attack, stop, move out of range, change targets, and change
  weapons. Dual-wield bars and wand Shoot should reset and stop correctly.
- Druid Maul or Warrior Heroic Strike/Cleave: queue and cancel, checking colors.
  Hunter Auto Shot: check the last-half-second red warning if a Hunter is available.
- Hold Ctrl+Shift+Alt during a swing: preview labels remain stable, countdowns
  resume on release, and drag/reset/saved positions still work after reload.
- Energy & Mana Tick: test a fresh login, Cat/Bear/caster transitions, spending
  mana, channel completion/cancellation, a potion and a drain if practical.
  Verify the spark after the first observed gain, its five-second cast-cost
  sweep, and resizing with Big Health/standalone bars.
- Macros: test bare/explicit/conditional #showtooltip, item macros, castsequence,
  chosen icons and any legacy --showtooltip or /pfcast display hints you use.
  Edit/delete a custom hint and reload; check for stale overrides. Check missing
  /equip, /use, focus and attack aliases without replacing another addon's aliases.
- Shift-compare rings, trinkets and weapons from bags/vendors/chat links; check
  one empty paired slot, enchanted/random-suffix items, Shift release, hover
  changes and tooltip closure. Compare with other tooltip addons enabled.

## Find the remaining bottlenecks

Profile the current build first. The purpose is to identify expensive workloads
and then narrow them down to modules/functions, not to prove the recent changes
made the addon faster. Older builds are not required for this investigation.

Keep the same character, location, target, addon list, UI settings and frame-rate
limit. Enable Real Health Numbers and the applicable Swing/Wand Timer in both.
Warm up for two minutes after loading; do not include loading or option changes
in a measured run. Keep GentleGC and other client mods configured identically.

Enable profiling, then reload:

```
/console scriptProfile 1
/reload
```

Start each sample with:

```
/script ResetCPUUsage(); STPerfStart=GetTime()
```

Perform the chosen scenario for about 60 seconds, then print average addon Lua
CPU milliseconds per elapsed second:

```
/script UpdateAddOnCPUUsage(); DEFAULT_CHAT_FRAME:AddMessage(string.format("ShaguTweaks: %.3f ms/s over %.1f s",GetAddOnCPUUsage("ShaguTweaks")/(GetTime()-STPerfStart),GetTime()-STPerfStart))
```

Scenarios: (1) idle with no windows open; (2) steady melee/wand attacks;
(3) repeated damage/healing and power changes, including druid form changes;
(4) repeated map, inventory, mail and auction-window interactions. Record which
windows were used and how many times. Repeat each three times on the current
build and compare medians. Repeating comparable activity matters more than
identical duration alone.

These addon totals are the first triage step, not module/function attribution.
For workloads with meaningful cost, follow with focused function CPU profiling
and, where practical, repeat the same scenario with one relevant option disabled
(reload after changing options). That separates module cost from unrelated
activity and tells us where a code change might be worthwhile. Respect the
decision to preserve the working theme recoloring behavior.

At the same point after warm-up and after a fixed test session, sample Lua memory:

```
/script UpdateAddOnMemoryUsage(); DEFAULT_CHAT_FRAME:AddMessage(string.format("ShaguTweaks: %.1f KiB",GetAddOnMemoryUsage("ShaguTweaks")))
```

Memory includes uncollected objects; compare at equivalent GentleGC collection
points. Do not force collections during CPU samples. Native textures/DLL memory
and total garbage production are not represented by this single memory number.

Send the build, scenario, enabled options, three CPU results and memory readings.
Those results guide the next targeted investigation. Lower addon Lua
CPU does not by itself prove higher FPS: native timer work moves out of Lua,
profiling adds overhead, and other addons/client rendering may dominate. Do not
use GetFrameCPUUsage for this comparison. Afterward, turn profiling off:

```
/console scriptProfile 0
/reload
```
