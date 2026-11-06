# Questline party protocol 1

`Party.lua` sends `QL_P1` addon messages on `PARTY`. Only current, connected party members are accepted. Raid groups disable this feature. Remote state is never saved. No database rebuild is required when changing synchronization code.

## Records

Fields below are separated by literal tabs. Each addon load generates a session identifier; sequence numbers increase within that session.

```text
H  session
D  session  sequence  questId  part  total  payload
```

`H` requests a snapshot. Requests from the same peer are honored at most once every five seconds. A new session clears that peer's old progress; recently retired sessions cannot overwrite it.

Quest ID `0` carries a comma-separated manifest of identified quest IDs currently in the sender's log. An empty manifest removes all older quest records. Other IDs carry a quest record, beginning with `A` (active), `C` (complete), or `F` (failed). Subsequent newline-separated objective rows contain five tab-separated fields:

```text
kind  normalizedLabel  current  required  done
```

`done` is `1` or `0`. Non-counted objectives leave both counter fields empty. Kind and label percent-escape `%`, tabs, carriage returns, and newlines using `%XX`. Labels come from the live quest log, with trailing counters removed and Questline's normal name normalization applied. Matching uses quest ID plus objective kind, label, and required count. Duplicate remote labels are ambiguous and never matched by position. Unknown quest IDs on the local client cannot provide synchronized objective counters.

Payload fragments contain at most 180 bytes, with at most 34 fragments and 6,000 assembled bytes per record. A record is applied only after every fragment arrives; fragment order does not matter. Incomplete records expire after 15 seconds. Per-quest revisions reject older updates. An older record may follow a newer manifest if that manifest still includes its quest; removed quests reject such packets.

## Scheduling and bounds

- Send at most one packet per 0.25 seconds; the normal update tick can increase this interval.
- Coalesce unsent changes per quest and send full snapshots every 60 seconds.
- Refresh native shared-quest membership every 15 seconds, using temporarily expanded live log indices.
- Omit counters older than 90 seconds from tooltips. On reconnect, clear previous progress until fresh data arrives.
- Accept at most 80 packets per sender per five seconds, 100 quest records, and 20 objectives per quest. Bound numeric values, fragment counts, and text lengths before use.

Only quest IDs, objective labels, counters, and completion flags are sent. Vanilla's `IsUnitOnQuest` can identify shared quests, but does not supply counters; members without usable synchronized data are omitted from tooltips. Other addons' protocols are not implemented.

## Validation

Run `node Questline/tests/run.js` from `Interface/AddOns`. The runtime suite passes emitted packets to a second simulated client and checks throttling, coalescing, manifest ordering, fragmented updates, timeout/retry, quest removal, reloads, disconnects, stale progress, invalid messages, and tooltip refresh/fade behavior.

In game, fully restart both clients after installing this version. Join a party with the same collection quest, hover its mob and tracker row, and collect an item on one character. Check both tooltips, then complete or abandon the quest and confirm the other client updates. Repeat with one party member without Questline to verify that unavailable progress is omitted. Actual server transport and tooltip layout still require this two-client smoke test.
