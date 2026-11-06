# Questie-Octo AceConfig Runtime Compatibility Audit

**Build:** 1.0.79  
**Baseline:** 1.0.78  
**Report:** `Questie-Octo ERROR: Questie-style AceConfig runtime unavailable` when opening settings.

## Source findings

The 1.0.78 Full and GitHub/runtime packages contain `LibStub`, `AceCore-3.0`, `AceGUI-3.0`, `QuestieOcto-AceConfigRegistry-3.0`, and `QuestieOcto-AceConfigDialog-3.0`. The TOC loads all of them before `UI/Options.lua`. The relevant Ace/Options files were unchanged by the 1.0.78 tracker-objective and pfUI QuestTimer work.

`UI/Options.lua` nevertheless performed fresh global `LibStub` lookups later when settings were initialized, reset, or shown. This made Questie-Octo's settings entry path depend on whatever global LibStub state existed at that later time instead of on the known-good library objects loaded by Questie-Octo itself.

## Correction

`UI/Options.lua` now captures the three required runtime objects as local references immediately when the module loads:

- `AceGUI-3.0`
- `QuestieOcto-AceConfigRegistry-3.0`
- `QuestieOcto-AceConfigDialog-3.0`

All later options operations use those captured references. No private library names or library implementations were changed.

The diagnostic path now reports the exact missing component(s) if the addon was genuinely unable to load one of them. This preserves safe failure for incomplete/corrupt installations while making future reports actionable.

## Compatibility

The private Registry/Dialog majors remain isolated to Questie-Octo. `AceGUI-3.0` remains a normal shared Ace library; LibStub minor upgrades reuse/update the same library table, so caching the table reference does not block normal compatible upgrades by another addon.

The change does not modify pfUI, DragonflightUI, Blizzard frames, shared Interface Options registration, other addons' AceConfig objects, or their saved positions.

## Resource impact

The change keeps three Lua table references for the lifetime of the options module. It adds no polling, OnUpdate, timer, frame, recurring event handler, database work, or growing cache. CPU impact while idle is zero and permanent memory impact is negligible.

## Validation boundary

Static/package validation can confirm load order, source references, syntax, and package completeness. The original player's exact addon stack is not available here, so final confirmation that their runtime error is eliminated remains an in-game compatibility test.
