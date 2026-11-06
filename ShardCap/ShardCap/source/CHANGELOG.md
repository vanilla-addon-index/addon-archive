# Changelog

## 2.1.1 - 2026-11-06

- Reuse ClassicAPI's item-info buffer during bag scans, with compatibility for older builds.
- Use a count-only scan for status text instead of allocating sorting records.
- Stop the current pass when ClassicAPI refuses to send a move request. Do not report or track it as sent; later bag events can retry.
- Describe move and merge notifications as requests, since the server confirms them asynchronously.
- Shard deletion, sorting priorities, and soul-bag reserve rules are unchanged.
