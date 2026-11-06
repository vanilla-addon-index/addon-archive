# Roar Guild Addon — verification, security, and creator choices

The GitHub project is **RoarGuildAddon**, titled **Roar Guild Addon**, while the actual guild is **ROAR**. My hope was to encourage guild members to use the addon and recruitment messages. The historical runtime identifiers remain unchanged; no adoption or in-game testing is asserted by this rename.

**Creator:** Babuni  
**Status:** documented existing behavior plus proposed verification. **No new runtime features approved in this documentation pass.**

## Current implementation baseline

- Version **1.33**, interface 11200, one Lua source + TOC and `ROGUDB` SavedVariables.
- Per-character profiles for action-slot instances, fallback, enabled status and roar statistics.
- Shared account-wide master emote IDs; default ROAR in a fresh database.
- Global fallback default **5/1000 per eligible action press** with 2s cooldown after success; 420s since last emote reminder with 73s reminder throttle.
- Explicit guild invitation to a numeric channel; manual `/rogu roar` always chooses ROAR.
- Roarboard post/reaction/sync via `roarboard` custom channel, 180-byte text cap, 12 visible rows, seven-day inactivity expiry.
- No automated tests found in repository tree. No gameplay test was executed here.

## P0 — test the source rather than assuming it works

1. Install on the actual target 1.12-compatible client and test initial login, /reload, and logout with and without action presses.
2. `/rogu watch`, `slot1`, `chance1`, `timer1` and instance emote pool creation, removal, clear and list; verify emote tokens on the client.
3. Confirm **`/rogu roar` is always ROAR**, not a random instance-1 token; test with a non-ROAR instance.
4. Test configured-slot and independent fallback on the same press, as well as `/rogu off`; record how multiple responses are handled.
5. Verify 0%, 100%, and other configured chance values, timing gates, session resets, and stats after an hour of actual activity.
6. Test `/rogu invite` in a **controlled channel**: channel indices vary; avoid unintentionally advertising into unrelated chat.
7. Inspect profile migration from old root-level saved data across multiple characters and realm names. Confirm that root settings are not inadvertently assigned only to the first character to load.
8. Test coexistence with other addons that override `UseAction`, including related ROAR addons; check performance with many configured instances.

## P0 — Roarboard trust, delivery and data integrity

9. Use two or more authorized test clients to join `roarboard`, create posts, synchronize, react and compare caches.
10. Confirm the board is a **custom-channel** feature rather than verified guild-only messaging; investigate channel permissions, spoofable usernames, unauthorized submissions, moderation needs and whether non-guild subscribers can participate.
11. Verify `RB1` post/reaction/sync parsing and event IDs, including duplicate messages, replayed events, conflicting post versions and malformed or oversized incoming packets.
12. Measure whether many clients replying to `/roarboard sync` create a burst of duplicate channel messages; test rate limits, disconnects, reconnects and late joining.
13. Verify 7-day inactivity-based pruning, new Roar activity extending retention, client clock differences and UI order/paging.
14. Check 180-byte limit for multilingual/UTF-8 text, and test untrusted message text/UI rendering without assuming sanitization or transport privacy.

No tests above have been run by this documentation audit.

## Creator decisions (not approved)

- Does Roarboard need verified guild restriction, opt-in membership or clear public-channel labeling?
- Should permission checks, message rate limits, per-user Roar deduplication or moderation be added?
- Should statistics stay playful and opt-in rather than reinforce performance pressure?
- Should fallback and configured-slot effects be mutually exclusive?
- Should “invite channel 1” be clarified in-game before sending?
- Does Roarboard remain a lightweight peer cache, or need a stronger synchronization model?
- Which parts of the early combined GodBod version deserve treatment as a historical experiment versus a portfolio feature?

Document explicit Babuni decisions before implementing alternatives. Preserve verification evidence, client builds, screenshots/logs and Git references.

## Related development history

Roar Guild Addon (originally RoarGuild) combines the earlier multi-action trigger concept with an **expandable registry of client-native emote tokens**. Its master list starts with ROAR (ID 1), players can register additional client emote tokens via `/rogu emote <TOKEN>`, and select their IDs for individual trigger instances. Guild invitation messages are **manual recruitment chat broadcasts**, while the later August 2026 Roarboard provides a separate community feature. This Vanilla 1.12 history is distinct from the Wrath-targeted ROARTrigger port. Read [the full family timeline](docs/EMOTE_FAMILY_HISTORY.md) for how these capabilities arose in the related repositories.
