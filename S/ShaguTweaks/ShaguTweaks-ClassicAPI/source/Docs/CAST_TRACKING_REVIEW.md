# Cast tracking review (3.8.2)

## Data ownership

The Improved Castbar and healing estimator query the normalized ClassicAPI cast
surface directly. Enemy Castbars also queries ClassicAPI first. The old libcast
copy of ClassicAPI cast events, keyed by unit name, had no built-in display
consumer. Name keys also cannot distinguish two enemies with the same name.

Removed the native-event mirror and legacy localized combat-text parser from
libcast. Ordinary non-Hunter initialization now registers no cast events or
casting hooks. Native unit queries do not create cached Lua records.

SuperWoW still supplies timed GUID records when ClassicAPI cannot supply complete
timing. Remote channels require ClassicAPI's live channel state and matching
spell ID before display, so an old timed record cannot resurrect a stopped or
different channel. A cache update refreshes the current target immediately.

The SuperWoW listener is created only when Super WoW Compatibility and Enemy
Castbars are enabled. It ignores the local player and complete native records.
It retains at most 128 remote records, prunes expired records on incoming events
at most every half second, and expires records when read. There is no cache
cleanup OnUpdate loop. Expired records may remain until another event/query,
but the cache remains bounded and expired entries cannot be displayed.

Hunter-only Aimed Shot/Multi-Shot custom timing is retained for compatibility
through ShaguTweaks' legacy query wrappers. Those hooks are no longer installed
for other classes. The built-in Improved Castbar continues to use ClassicAPI
directly; this cleanup does not add custom Hunter casts to that display.

## Validation and limits

`tests/test_cast_tracking.lua` covers native query ownership, duplicate enable
guards, disabled consumers, complete native records, missing channel timing,
live channel identity, delayed failures, expiry, cache limits, and Hunter
custom-cast entry points. These are mocked Lua 5.0 checks, not client/DLL tests.

Before release, test player casts/channels and interruptions; enemy casts and
interruptions; switching targets during a channel; and Enemy Castbars with
Super WoW Compatibility both enabled and disabled. If a Hunter is available,
also test Aimed Shot and Multi-Shot through spellbook, macro and action buttons.

This reduces redundant Lua handlers and records. No FPS, memory or CPU gain has
been measured. Compare the same encounter/options using ClassicAPI's
GetAddOnCPUUsage/GetAddOnMemoryUsage with script profiling enabled; do not rely
on GetFrameCPUUsage or infer a frame-rate gain from code size.
