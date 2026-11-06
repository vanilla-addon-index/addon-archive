# TurtleMail 1.4.5 — Compatibility audit

Target: Turtle WoW 1.18.x / Octo client.

## Fixed in 1.4.6

- **Horizontal mail bar crash:** the upstream code creates `MailHorizontalBarLeft/Right` and then assumes the textures are exported as globals. Some client/UI combinations return the textures without the expected global, causing `attempt to index field 'MailHorizontalBarLeft' (a nil value)`. The compatibility layer guarantees valid texture references before setup and updates.
- **Autocomplete SavedVariables crash:** `TurtleMail_AutoCompleteNames` and its realm/faction table are used without schema validation. The patch initializes/repairs missing or malformed SavedVariables before `ADDON_LOADED`, `PLAYER_LOGIN`, slash commands, and autocomplete.
- **Broken sender-learning hook:** upstream `GetInboxHeaderInfo` hook reads `arg[3]`/`arg[12]` from function inputs even though sender/canReply are return values. The patch captures return values first, so received senders can actually populate autocomplete.
- **Sent money not logged:** upstream checks the nonexistent `state.send_money` field. The patch records sent money when it is not COD and `sent_money > 0`.
- **Inbox bounds/COD safety:** header data is no longer queried/compared unsafely after the inbox index has moved past the last mail; nil COD values are treated as zero.
- **Stale inbox icons:** AH/returned icons are explicitly hidden on empty rows/pages.
- **Fragile package-button regions:** `MAIL_SHOW` no longer assumes regions 1 and 3 always exist.
- **Mailbox frame guards:** bag updates, attachment bookkeeping, inbox locking, and money display tolerate missing/replaced frames instead of immediately throwing Lua errors.
- **Locale-safe COD label:** unexpected `COD_AMOUNT` formatting no longer turns the label into nil and causes string concatenation errors.
- **Malformed log entries:** logging tolerates missing subjects/participant fields and repairs missing log tables.
- **Calendar tooltip:** disabled/empty calendar days no longer concatenate a nil/stale `mails` value.
- **OnUpdate rebinding:** `TurtleMail:init()` binds the original `on_update` function before the compatibility file loads; the patch explicitly rebinds the frame script so the safer handler is actually used.


## Fixed in 1.4.8

- **`MailMailButton` nil crash:** upstream stores the real `SendMailMailButton` in a loose global named `MailMailButton`, then replaces the Blizzard global with a proxy table. If the saved global is missing or another UI addon changes it, `SendMailFrame_CanSend()` and `sendmail_clear()` crash while calling `Enable()` / `Disable()`. The compatibility layer now preserves a strong reference to the real button before the proxy swap, restores it when the mailbox opens, replaces the fragile CanSend hook, and uses a guarded clear routine.
- **Paired subject edit-box hardening:** the same proxy pattern is used for `MailSubjectEditBox`; the real edit box is now preserved and restored alongside the send button to avoid the equivalent follow-up failure.

## Fixed in 1.4.9

- **Missing `Open Mail` button:** upstream creates `TurtleMailOpenMailButton` only once in `inbox_load()` and assumes it will remain parented, positioned, and visible forever. If that creation path is interrupted or another mailbox/UI addon hides or re-parents the button, TurtleMail never recovers it. The compatibility layer now uses an idempotent inbox loader and an `ensure_open_mail_button()` recovery path that recreates the button if needed and restores its parent/anchor/text/click handler/frame level.

## Fixed in 1.4.10

- **First mailbox-open freeze/stutter after the 1.4.9 recovery fix:** 1.4.9 called `ensure_open_mail_button()` on every `MAIL_INBOX_UPDATE`. Initial inbox population can emit a burst of those events, so the button was repeatedly re-parented, re-anchored, re-labeled, resized, and given a new frame level. 1.4.10 removes that work from `MAIL_INBOX_UPDATE` and makes `ensure_open_mail_button()` state-aware, so it only mutates the UI when the button is missing, hidden, moved, re-parented, or otherwise incorrect.

## Fixed in 1.4.11

- **Residual mailbox hitch / excessive garbage generation:** the upstream `GetContainerItemInfo` hook used `pack()` + `unpack()` for every bag query, allocating a temporary table each time. Bag/mailbox refreshes can call this path very frequently and trigger avoidable garbage collection pauses. 1.4.11 replaces the installed hook after login with a fixed-local wrapper that performs no per-call table allocation. The native return count is detected once and the exact arity is preserved for signatures of up to 12 return values; unusual signatures fall back to the previous hook.

## Fixed in 1.4.12

- **Open Mail recovery overhead on mailbox open:** 1.4.11 still called the full `ensure_open_mail_button()` routine from `MAIL_SHOW()`. Even when the button was healthy, that path inspected parent, anchor, label, script, size, frame level and visibility. 1.4.12 keeps the normal path Otari-like: if `TurtleMailOpenMailButton` already exists, is parented to `InboxFrame`, and is shown, `MAIL_SHOW()` leaves it completely untouched. The full recovery routine now runs only if the button is missing, hidden, or re-parented. No inbox polling, Open All, sending, logging, or mail-processing logic is changed.

## Remaining architectural risks upstream

These are intentionally not rewritten in the compatibility layer because changing them would be much more invasive and could alter mail behavior:

1. TurtleMail directly replaces global Blizzard functions during `PLAYER_LOGIN` rather than using a cooperative hook system. This makes load order important when another addon also replaces the mail/bag functions.
2. `sendmail_load()` temporarily/proxy-replaces global `SendMailMailButton` and `SendMailSubjectEditBox`. This is a clever Vanilla-era workaround but can conflict with UI replacements.
3. Several layouts rely on specific Blizzard frame names and region ordering. The compatibility layer protects the confirmed/high-risk cases, but a full mail-frame replacement can still be incompatible.
4. The pfUI skin accesses pfUI internals (`MailFrame.backdrop`, `pfUI_config`, specific widget members). A future pfUI layout change can therefore break the skin even when core TurtleMail remains functional.
5. Inbox polling is frame-count based (`200` OnUpdate ticks), so the interval changes with FPS. It is not a correctness bug but is less predictable than elapsed-time polling.
6. The addon has no automated runtime test harness for Turtle WoW mail APIs; future changes still need in-game validation with representative mail/send scenarios.

## Compatibility context

The upstream repository already had a Turtle WoW 1.18.1 report where `MailFrame` became nil; that report was ultimately traced to MoveAnything. This reinforces that TurtleMail is sensitive to addons that replace or re-parent the mail UI.

## Validation

The compatibility build was tested in-game on Turtle WoW 1.18.x and the reported setup produced no Lua errors after the fixes were applied. Because mailbox behavior can be affected by other UI addons, future changes should still be checked with normal mail, item mail, gold, COD, AH/returned mail, multi-attachment send, autocomplete, logging, and pfUI when applicable.

## Status

**1.4.12 is the current test build pending in-game validation.** The fixes remain isolated in `TurtleMailFix.lua` so upstream code stays easy to compare and future upstream changes remain easier to merge.
