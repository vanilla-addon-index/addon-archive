# Roar Guild Addon — creative concept

**Creative author:** Babuni.

## An addon made for my guild

The ROAR guild was already a social identity, and I wanted an addon that could accompany it instead of being mistaken for the guild itself. The hope was that members would use the emotes, recruitment invitations and shared interactions together. Calling the project **Roar Guild Addon** now keeps that distinction visible. The code retains the original **RoarGuild** package identity.

## Presence rather than performance

RoarGuild's README supplies the project's most direct artistic statement: **“RoarGuild is not about optimization. It is about presence.”** The addon treats a WoW character as a participant in a world, not merely an executor of abilities. Player actions can yield moments of unexpected performance: a roar, a laugh, a gesture selected from a personal pool. Chance makes those gestures feel alive, while cooldown and the ability to disable the effect keep the player in control.

The project is distinct from the earlier single-slot `roar`/`roarr` and multi-instance `ROARRunlimited` experiments because **emote vocabulary, character profiles, social invitation text, rare fallback expression and a peer message board** now coexist in one identity.

## A progression from character to community

Three layers emerge in the committed work:

1. **Individual expression:** named action-slot instances with independently tuned chance, cooldown and choices from an account-wide emote list. Default ROAR grounds the experience.
2. **Shared identity:** ROAR guild invitation copy highlights curiosity, exploration, kindness, humor and meaningful stories instead of efficiency races. The user sends recruitment messages explicitly through `/rogu invite`.
3. **Shared memory:** Roarboard holds short posts and visible Roar reactions for up to seven days since the last activity, allowing a collection of small ongoing guild/community moments.

The board is described creatively as a guild space, but its actual transport is a **joinable custom channel**, not verified guild membership or private guild infrastructure. That distinction is important for trustworthy public documentation.

## Original choices and historical boundaries

Git proves that on **2026-01-10**, the first RoarGuild code combined a ROARRunlimited-like emote feature with GodBod reminders. Later code and manifest revisions removed GodBod and concentrated on the guild-expression system. The August 2026 board became another layer. The repository evidence supports that implementation trajectory, not the precise personal motives for every revision.

Keep related addons separate in the portfolio while explaining verified lineage and shared techniques. Nothing here authorizes merging them, changing the guild's lore, or replacing the playful expressive design with a conventional performance dashboard.

## Not the project

RoarGuild is not a DPS tool, automatic guild spammer, secure messaging service, medical reminder application in its current form, or substitute for player social interaction. The original author remains the creative authority; an AI collaborator may analyze, propose and implement only within the direction that Babuni accepts.

## Related development history

Roar Guild Addon (originally RoarGuild) combines the earlier multi-action trigger concept with an **expandable registry of client-native emote tokens**. Its master list starts with ROAR (ID 1), players can register additional client emote tokens via `/rogu emote <TOKEN>`, and select their IDs for individual trigger instances. Guild invitation messages are **manual recruitment chat broadcasts**, while the later August 2026 Roarboard provides a separate community feature. This Vanilla 1.12 history is distinct from the Wrath-targeted ROARTrigger port. Read [the full family timeline](docs/EMOTE_FAMILY_HISTORY.md) for how these capabilities arose in the related repositories.
