# Roar Guild Addon — architecture v1.33

This describes the original **RoarGuild** runtime in the renamed **RoarGuildAddon** repository, not the guild organization itself. The source identifiers and communication mechanisms remain unchanged.

**Sources:** `roarguild.lua`, `roarguild.toc` on 2026-10-26. **Static inspection**, not a live WoW test.

## Components

| Component | Source | Role |
| --- | --- | --- |
| Profile/configuration | `ROGU_EnsureDB`, `ROGU_EnsureProfile`, `ROGU_LoadOnce` | Account-wide emote registry plus per-character settings |
| Main emote engine | global `UseAction`, `ROGU_DoBattleEmoteForCfg` | Check configured action-slot instances |
| Independent fallback | `ROGU_TryFallback` | Chance per eligible action, with its own post-success throttle |
| Reminder/statistics | `ROGU_MaybeReminder`, `ROGU_Stats*` | Rare silence reminder, lifetime and rolling-hour emote activity |
| Recruitment | `inviteText`, `ROGU_SendInvite` | Random prewritten guild invitation to numeric channel |
| Roarboard | `RB_*`, `Roarboard`, `CHAT_MSG_CHANNEL` | Shared-channel post/reaction/sync protocol and local frame |

## Emote pathway

```text
UseAction(slot, checkCursor, onSelf)
  -> ROGU_LoadOnce()     [on login also called explicitly]
  -> optional watched-slot debug message
  -> for each configured instance:
        if cfg.slot == slot:
          cooldown gate, advance cfg.last
          chance roll (0-100)
          pick token via profile emoteIDs / account-wide ROGUDB.emotes
          DoEmote(token), update lastRoar and increment stats
  -> independent fallback: if enabled and slot 1..200
        default 5/1000 chance, 2s post-success throttle
        successful roll -> DoEmote, update lastRoar and stats
  -> check 420s-since-last-roar reminder (73s throttle)
  -> prune/report emote stats if hourly report due
  -> delegate original UseAction with unchanged arguments
```

**Distinct timing:** an instance consumes its cooldown after an **eligible attempt**, even on a failed chance roll. Fallback only updates its `last` on **success**, so its 2s default interval does not space failed attempts. The reminder reports after 420s from the last recorded emote, not during a background scheduler. All of these run on action use; `/rogu roar` directly emits ROAR and increments stats regardless of configured pool.

## Saved data

```text
ROGUDB (account-wide SavedVariables)
├── emotes = { [1] = { emote = "ROAR" }, ... }
├── profiles
│   └── "<character>-<realm>"
│       ├── enabled
│       ├── slots = { [instance] = {slot, chance, cd, last, emoteIDs}, ... }
│       ├── fallback = {enabled, cd, chancePermille, last, emoteIDs}
│       ├── stats = {total, stamps, head, lastReport}
│       └── _migrated
└── roarboard
    ├── posts = { [postID] = {username, timestamp, lastActivity, roarcount, text}, ... }
    └── seen = { [eventID] = timestamp, ... }
```

New `ROGUDB.emotes[1]` defaults to ROAR. The code sanitizes instance ID selections to valid unique IDs and restores ID 1 if an array becomes empty. An already present valid ID-1 token may be uppercased, not forcibly reset to ROAR; avoid claiming an invariant that the implementation does not enforce.

`ROGU_MigrateLegacyRootToProfile` moves old root `slots`, `enabled`, `fallback` into a character profile, then clears legacy keys. Because legacy root fields are shared and removed on first migration, migration order across multiple characters deserves a controlled test. Unlike some earlier ROAR addons, this source explicitly calls `ROGU_LoadOnce()` during `PLAYER_LOGIN` and resets cooldown fields there.

## Roarboard protocol and storage

- Named WoW chat channel: **`roarboard`**; protocol string **`RB1`**.
- Outbound `P` = post, `R` = roar reaction event, `S` = sync request.
- New posts use ID `<username>-<timestamp>-<random>`; username is embedded in message data.
- Outgoing post text must be nonempty and have `string.len <= 180` **bytes**. It escapes `%` and `|`, and replaces line breaks with spaces.
- Reception checks `CHAT_MSG_CHANNEL` channel name/display and attempts to parse `RB1` messages. There is no in-protocol sender/guild authentication, cryptographic signature, role authorization or independent trusted server.
- An `S` request causes peers to resend their current cached post list. A `P` merges selected fields; a reaction `R` increments count once per seen event ID, updating `lastActivity`.
- Posts and seen-event stamps older than **seven days of inactivity** are pruned using `time()` where available, otherwise a `GetTime()` fallback. Local clock disagreements and protocol replay warrant testing.
- UI uses a draggable **700×460** dialog, 12 post rows per page, selected details and Newer/Older navigation; “Roar” sends a reaction.

**Trust boundary:** A custom chat channel is not a guild membership control. Anyone with access to that channel may potentially see, inject or replay protocol messages. Each client keeps a separate cache, and sync cannot guarantee global agreement. If multiple connected peers answer a sync request, the message count can multiply quickly. These risks are evident from architecture but have **not been demonstrated with live participants**.

## Events and compatibility

The addon listens for `PLAYER_LOGIN`, `PLAYER_LOGOUT` and `CHAT_MSG_CHANNEL`. It seeds `math.random` on login (affecting global Lua RNG state), initializes profile and board, prunes posts, and attempts to join the custom channel. The global `UseAction` wrapper may interact with other addon hooks. There are no automated tests in the inspected repo. Interface 11200 support and exact WoW event argument behavior require testing in the target client.

## Related development history

Roar Guild Addon (originally RoarGuild) combines the earlier multi-action trigger concept with an **expandable registry of client-native emote tokens**. Its master list starts with ROAR (ID 1), players can register additional client emote tokens via `/rogu emote <TOKEN>`, and select their IDs for individual trigger instances. Guild invitation messages are **manual recruitment chat broadcasts**, while the later August 2026 Roarboard provides a separate community feature. This Vanilla 1.12 history is distinct from the Wrath-targeted ROARTrigger port. Read [the full family timeline](EMOTE_FAMILY_HISTORY.md) for how these capabilities arose in the related repositories.
