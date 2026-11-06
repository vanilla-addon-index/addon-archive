# Roar Guild Addon — developer and AI collaborator rules

**Human creative and director:** Babuni.

## Naming and publication voice

**Roar Guild Addon** is the project title, with GitHub repository `RoarGuildAddon`. **ROAR** refers to the guild; **RoarGuild** is the old project/package identity. Do not conflate the guild with its optional addon, or rename `roarguild.lua`, `roarguild.toc`, `/rogu` or `ROGUDB` during documentation work.

Write public development narratives from my first-person perspective, without beginning a sentence with “I” or “My”. Use **Babuni** for personal identity and **babuni.dev** for the wider portfolio; use **creative** rather than “creator” as a human role. Attribute work performed by AI explicitly, preserving differences between ideas, code, changes and verification. The human motivation for guild members to use the addon and invitation messages is now directly stated; do not invent adoption statistics or claim members actually used it.

## Identity and authorship

Preserve the intent: in-world character presence, joyful guild recruitment and community stories—not DPS optimization. Do not attribute the original concept, guild values, or characteristic language to AI. AI research and documented implementation contributions must be separately credited.

Document **human direction**, **AI proposals**, **creative iteration**, **explicit creative decisions**, **changed paths/commits**, and **actual verification** in `docs/DEVLOG.md` and `docs/AI_COLLABORATION.md`. Label historical reconstruction; do not invent dialogue, approvals or user testing.

## Preserve accurate technical boundaries

- Distinguish RoarGuild from `roar`, `roarr`, `ROARRunlimited`, `WorkThatGodBod` and `RoarForever`. Trace lineage only from actual commits.
- The **current version has no GodBod runtime subsystem**. Initial January 2026 history did, but it was subsequently removed.
- Fresh `ROGUDB.emotes[1]` defaults to ROAR; sanitation falls back to ID 1. The source does not absolutely guarantee that an existing valid ID-1 entry can never differ.
- `/rogu roar` explicitly calls `DoEmote("ROAR")`; configured emote pools do not determine this manual command.
- Instance cooldown timestamps advance **before** chance rolls; fallback timestamp advances **on successful fallback only**.
- Reminder after 420s since last successful emote; 73s repeat throttle, only checked on action press.
- `/rogu invite` sends a prewritten message to a numeric channel, which may or may not be General.
- **Roarboard is not guild-authenticated or private.** It uses the normal custom `roarboard` chat channel with `RB1` packets and an independently stored local cache. Do not market it as secure guild-only transport.

## Implementation discipline

1. Inspect `roarguild.lua`, `roarguild.toc`, README, LICENSE, DEVLOG, DECISIONS and ARCHITECTURE before changing behavior.
2. Keep changes small and reviewable. Do not modify executable code incidentally during a docs-only audit.
3. Respect intended WoW 1.12/Lua 5.0 API constraints, and test `UseAction` chaining/load order.
4. Validate any protocol input handling, permissions, sync bursts, replay/deduplication, and retention before claiming Roarboard security or delivery guarantees.
5. Preserve MIT license and author credit; do not publish sensitive player communications or unapproved private logs.
6. For every implementation update, revise README, CHANGELOG, DEVLOG, DECISIONS, DESIGN, CONTENT and ROADMAP as applicable and report real test results.

The October 26, 2026 documentation pass neither approved new functionality nor tested WoW runtime behavior.

## Shared emote-history reference

Follow [the source-grounded family history](docs/EMOTE_FAMILY_HISTORY.md) when describing related addons. This project implements an editable *native-token registry* and manual recruitment chat messages; do not extend those claims backward to the early five/four-token battle addons or into an automatic GuildInvite API. Preserve the separate Wrath port and the later Roarboard date.

## Repository-local documentation standard

Before writing or changing project documentation, read [docs/DOCUMENTATION.md](docs/DOCUMENTATION.md). These rules travel with this repository and do not depend on the babuni.dev ChatGPT Project. Preserve all project-specific technical, creative, canon, safety, licensing, and historical rules in this file; follow the linked standard for public first-person narrative, human–AI attribution, concise development journals, decision records, and evidence-based verification. **Babuni** is the human creative; **babuni.dev** is the website/portfolio, not the person. Preserve third-party credits and historical legal notices. References above to a dated “documentation-only audit” describe that past task, not a permanent ban on later authorized implementation.
