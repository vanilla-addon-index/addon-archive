# Roar Guild Addon — creative ownership, AI assistance and provenance

**Human project author and creative director:** Babuni.

## What is actually recorded

This public repository contains the creator's stated design philosophy, the game addon Lua and TOC, dated source edits and several PR merge records. Its README explains RoarGuild as **presence rather than optimization**, and later as an invitation into a guild valuing curiosity, shared stories and joy. Those are the project's authorial direction and must not be presented as ideas invented by a documentation assistant.

The Git history shows a 2026-01-10 combined RoarGuild/GodBod experiment, later removal of the exercise subsystem, expansion of user-defined emote selections and profiles, a manual-ROAR fix, a new August 2026 Roarboard subsystem, and September recruitment-text revisions. It does **not** preserve a complete human–AI design conversation explaining every individual decision.

Some historical PRs have `codex/` branch names, showing tool-assisted branch naming for those changes, but that alone does not allocate creative authorship or prove what code was generated versus reviewed by a human. Do not overclaim either side's contribution.

## This 2026-10-26 audit

An AI assistant inspected `README.md`, `roarguild.lua`, `roarguild.toc`, the existing MIT license, prior short docs and representative Git commit diffs. It documented current behavior, the historical stages, Roarboard's custom-channel trust limitations and pending client tests. It drafted and committed eleven Markdown documentation files only.

**The AI did not conceive the RoarGuild concept in this session, approve new features, modify runtime source, make guild policy, test the game client, or validate Roarboard's security.**

## How to record future collaboration

For material changes, preserve:
1. The creator's original direction and why it mattered.
2. AI suggestions, architecture and tradeoffs—not silently accepted requirements.
3. Alternative approaches, misunderstandings, iterations and corrections.
4. Explicit decisions Babuni accepted, rejected or postponed.
5. Actual file paths, commits, PRs and migration notes.
6. Tests performed, observed results and limits to confidence.

Write publishable narrative summaries, not raw private chat transcripts. Keep other players' chat messages, personal information, account IDs, credentials and unreleased guild decisions out of public records.

## Attribution and legal boundary

The repository's existing MIT LICENSE is credited to **Babuni (2026)**. Displayed author credit in the TOC and README agrees. Licensing and source credit should be maintained without silent changes. Any third-party game emotes or user-generated board content have their own origin and must not be rebranded as Babuni-authored prose.

## November 2026 — guild and addon distinction

The decision to rename this repository **RoarGuildAddon** came from my wish to separate the actual ROAR guild from the addon made for its members. The original hope was that members would use the emotes, invitations and other social features. An AI assistant updated the current documentation at my request, without changing addon code or independently verifying member adoption.

## Related development history

Roar Guild Addon (originally RoarGuild) combines the earlier multi-action trigger concept with an **expandable registry of client-native emote tokens**. Its master list starts with ROAR (ID 1), players can register additional client emote tokens via `/rogu emote <TOKEN>`, and select their IDs for individual trigger instances. Guild invitation messages are **manual recruitment chat broadcasts**, while the later August 2026 Roarboard provides a separate community feature. This Vanilla 1.12 history is distinct from the Wrath-targeted ROARTrigger port. Read [the full family timeline](EMOTE_FAMILY_HISTORY.md) for how these capabilities arose in the related repositories.
