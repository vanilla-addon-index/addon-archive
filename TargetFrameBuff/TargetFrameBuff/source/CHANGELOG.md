# Changelog

## 0.9.6

- Add settings for the most buffs (0-32) and debuffs (0-16) shown: `/tfb buffs N`,
  `/tfb debuffs N` and two options-panel sliders. A lowered debuff limit hides the
  extras instead of spilling them into the buff row.
- Tests: 23 scenarios.

## 0.9.5

- Fix the `/tfb` help text: `|` is a chat escape character, so it printed garbled.

## 0.9.4

- Add `/tfb test [buffs debuffs]` and an options-panel button: fake auras on the
  current target for checking layout, timers, stacks, borders and sweeps.
- Tests: 21 scenarios.

## 0.9.3

- Warn once in chat when ShaguTweaks Debuff Timer is drawing on target debuffs.
- Use the client font (`STANDARD_TEXT_FONT`) for timers and stack counts.
- Tidy source comments; add `.gitattributes` (LF) and `.gitignore`.
- Rewrite the README: ClassicAPI version table (1.17.11+ recommended for the
  reverse-sweep fix) and a ShaguTweaks compatibility table.
- Tests: 19 scenarios; no machine-specific paths.

## 0.9.2

- ClassicAPI 1.17.10+: use `UNIT_AURA_DELTA`; no periodic polling. The displayed
  snapshot is rebuilt to keep filtered ordering and tooltip indices aligned.
- Older ClassicAPI keeps the 0.5-second fallback.
- Hide native cooldown numbers on our sweeps; disable the expiration flash and
  clear removed sweeps where supported.
- Spellbook and player-pet changes refresh capability-dependent presentation.

## 0.9.1

- Refresh on target change and target aura events, with a 0.5-second fallback.
- Update only active countdowns every 0.2 s from cached expirations.
- Use `GetAuraSlots` / `UnitAuraBySlot` with reusable buffers; positional
  `UnitAura` fallback for older ClassicAPI.
- Stack counts for buffs and overflow debuffs; debuff-type borders.
- Gold borders on enemy buffs you or your pet can remove.
- Optional reverse cooldown sweeps.
- Saved settings, an AddOn Options panel and `/tfb` commands.
- Guard against an aura vanishing just before its tooltip opens.
