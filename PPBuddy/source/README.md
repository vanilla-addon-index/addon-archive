# PPBuddy

A compact blessing status bar for WoW 1.12 / TurtleWoW.

Shows your assigned paladin blessings as a small row of icons. At a glance you can see what you have, what you're missing, and click to ask for it.

## Requirements

**No dependencies.** PPBuddy listens directly to PallyPower's `PLPWR` addon channel messages, so it works as long as at least one paladin in your raid or party has PallyPowerTW installed — you don't need it yourself.

If you *do* have PallyPowerTW installed (e.g. as a raid leader), PPBuddy will also read its globals directly. Both modes work simultaneously with no conflict.

## Installation

Drop the `PPBuddy` folder into `Interface/AddOns/` and reload. That's it.

## The Bar

A small horizontal strip of blessing icons — one per buff assigned to your class. Drag it anywhere; position is saved across sessions. Auto-hides when no assignments are known yet.

| Border colour | Meaning |
|---|---|
| 🟢 Green | You have this buff (assigned or preferred) |
| 🔵 Blue | Preferred buff set but missing |
| 🔴 Red | Missing, no preference set |
| ⬛ Grey + dimmed | Banned (auto-removed) |

## Controls

| Input | Action |
|---|---|
| **Hover** | Tooltip shows buff name, assigned paladin, and available actions |
| **Hover (0.5s)** | Opens flyout to select a preferred alternate buff |
| **Left-click** a red/blue icon | Whispers the assigned paladin asking for the buff |
| **Right-click** (no preference set) | Bans that buff — auto-removed whenever applied |
| **Right-click** (preference set) | Clears the preference |

## Preferred Buffs

Sometimes your paladin is buffing your class with a buff you don't need — for example, a feral druid getting Wisdom because the same paladin also covers resto druids. You can set a preferred alternate buff per assignment:

1. Hover over an icon for 0.5 seconds — a flyout of all 6 blessings appears above it
2. Click the one you'd prefer — the icon updates to show your preferred buff with a blue border
3. Left-click the blue icon to whisper the paladin requesting the swap
4. Right-click to clear the preference and revert to normal

The flyout closes automatically a moment after your mouse leaves it.

## Banning a Buff

Right-clicking an icon (with no preference set) bans that blessing. PPBuddy will automatically cancel it via `CancelPlayerBuff()` whenever it is applied to you — the same mechanic LazyPig uses for Salvation removal. Bans persist across sessions.

## Configuring Whisper Messages

Type `/ppb config` to open the message template editor. Two fields let you customise the text sent when you whisper a paladin:

**Assigned buff request:**
```
Hey %player%, could I please get %buff%? Thank you! :)
```

**Alternate buff swap request:**
```
Hey %player%, could I get a 10-minute %altbuff% instead of %buff%? Thank you! :)
```

Keywords: `%player%` = paladin name, `%buff%` = assigned blessing, `%altbuff%` = your preferred blessing. Each field has a Reset button to restore the default. Changes save automatically on focus loss.

## Saved Settings

Position, bans, preferred buffs, and message templates are all saved per-character across sessions via the `PPBuddy_Config` saved variable.

## Slash Commands

| Command | Effect |
|---|---|
| `/ppb show` | Show the bar |
| `/ppb hide` | Hide the bar |
| `/ppb reset` | Reset position to default |
| `/ppb config` | Open the message template editor |
| `/ppb bans` | List currently banned blessings |
| `/ppb clearbans` | Remove all bans |
| `/ppb prefs` | List active preferred buff selections |
| `/ppb clearprefs` | Clear all preferred buff selections |
| `/ppb debug` | Dump known assignment data to chat |

## Notes

- The bar auto-hides when no assignments are known yet (e.g. before any paladin has broadcast their data after a fresh login).
- Paladins already have PallyPowerTW's own BuffBar — PPBuddy is for everyone else.
- Hunter Pets and Warriors share Class ID 0 in PallyPower, so a Warrior blessing covers both (vanilla behaviour, not a bug).

## Changelog

### 2.0.2
- Preferred alternate buff system: hover an icon to open a flyout and select a different blessing to request instead of the assigned one. Blue border indicates a preferred buff is set but missing.
- Flyout closes reliably after mouse leaves, using frame-by-frame polling rather than OnLeave events.
- Configurable whisper message templates via `/ppb config` — supports `%player%`, `%buff%`, and `%altbuff%` keywords, with per-field reset buttons.
- Whisper message for alternate buff requests correctly references both the preferred and assigned buff names.
- Tooltip always shows assigned paladin name and their assigned buff, even when a preference is set.

### 2.0.0
- Rebuilt as fully standalone — no PallyPowerTW dependency. Listens directly to `PLPWR` addon channel messages so any raider can install it without needing PallyPower themselves.
- Broadcasts `REQ` on login and zone change so paladins re-send their assignments immediately, rather than waiting for paladin interaction.
- Bar position now correctly persists between sessions (fixed saved variable initialisation order and coordinate system mismatch).
- Compact icon-only bar replacing the previous row-based layout. Icons show green/red border for have/missing state.
- Right-click to ban a buff — auto-removed on `PLAYER_AURAS_CHANGED`, same mechanic as LazyPig's Salvation remover.
- Tooltip shows buff name, assigned paladin, and context-sensitive action hints.
- Left-click whispers the assigned paladin with a polite buff request.
