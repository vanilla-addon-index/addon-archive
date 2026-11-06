# GroupBuffToggle — concept and creative direction

**Creator and creative director:** Babuni.dev. **Project:** Group Buff Toggle for WoW Vanilla 1.12.

## Put helpful information beside the people it describes

Buff icons usually live inside or around the game's unit-frame information hierarchy. When fighting alongside a party or watching a target, a player may want to know **which positive effects are active** without cramming more status information on top of the name, health and mana bars.

The project's concrete answer is a **small supplementary buff strip beside** each normal party frame and the selected target frame. Up to sixteen aura icons fit in two rows of eight, leaving the original frame readable. Hovering a symbol uses the familiar built-in game tooltip rather than introducing a separate interpretation layer.

This is deliberately not a complex raid frame, aura-warning assistant or combat automation system. No casts, prioritization, suggestions or warnings are authored; it simply makes current buffs easier to inspect when the player chooses to.

## Respect the existing UI until invited

An unusually valuable design constraint is present from the initial version: **both displays default to off**. Installing Group Buff Toggle should not dramatically change the player's screen by surprise. The controls are familiar native **Buffs** checkboxes, positioned only when a matching unit frame is present.

The September 10 second commit pushed user control further: **checkbox visibility itself** became independent from **the buff display**. A user could leave party buffs showing and hide the small toggle control for a cleaner layout—or turn everything off without leaving a permanently unused widget. That is a meaningful design refinement: the checkbox is an optional affordance, not the owner's source of truth.

The four switches persist account-wide. “Off by default” applies to **buff icons**, not to checkbox availability. That distinction is part of the authored user experience and shouldn't be blurred.

## Lightweight means bounded and local

The addon uses client `UnitBuff` data for a maximum of **four party members plus one target**, capped at **16 icons each**. It attaches to Blizzard's already-present `PartyMemberFrame1` through `4` and `TargetFrame`. It does not rebuild the frames, ask for an addon framework or create an external service.

The cost of that approach is limited compatibility with wholesale unit-frame replacements and a deliberately modest information set: aura **icons with hover details**, not timers, stack badges, or comprehensive raid support. These are limits of the current code, not promised future features.

## Identity and creative provenance

The repository started on September 10 as **Octo Group Buff Toggle**, aimed at an older Vanilla-compatible environment. The September 18 version changed to a provider-neutral title, `GroupBuffToggle`, and renamed its SavedVariables while retaining the small original interaction concept.

The MIT License makes reuse terms explicit, and its existing 2026 copyright notice now credits **Babuni.dev**. Git proves the dated code changes but does not reproduce the creator's original conversations or necessarily the author of every line. The original purpose and creative decisions belong to Babuni.dev; later AI source interpretation is separately credited in the collaboration record.
