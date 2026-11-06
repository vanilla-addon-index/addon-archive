# Roar Guild Addon — writing, emotes and board content

The guild recruitment messages, emote text and Roarboard content belong to the **Roar Guild Addon**, created to accompany the **ROAR guild**. They do not constitute the guild's organizational identity or prove members adopted the addon.

**Creative author:** Babuni  
**Source of truth:** `roarguild.lua` and its historical Git revisions.

## ROAR as a design motif

ROAR is both a game-native gesture and an identity word. The fresh install's shared emote registry starts with `ROAR` at ID 1, and the manual `/rogu roar` command unconditionally performs `ROAR`. A configured instance can instead select from multiple user-registered emote tokens via numeric IDs.

A built-in `DoEmote` token is not custom voice acting, bespoke animation or authored text. The current code uses user-entered tokens without confirming they are supported by the specific client; verify results in-game.

## Guild invitation language

The committed `inviteText` array contains friendly, hand-curated invitation variants chosen randomly by `/rogu invite`. Their recurring content values are:

| Theme | Editorial voice |
| --- | --- |
| Curiosity | Azeroth as a place worth wandering and exploring |
| Kindness and respect | Welcoming fellow players without performance gatekeeping |
| Celebrating the ordinary | Laughs, level-ups, loot and little adventures |
| Shared narrative | Stories and memories matter as much as progression |
| Playful identity | A collective roar is an invitation, not a command |

The development record includes a notable **2026-09-03** revision from longer/more rhymed recruitment pieces to shorter accessible messages. The Git diff establishes that textual change; it does not reconstruct the creator's hidden reasons for approving or revising particular word choices.

The source sends these lines through a numeric channel chosen by the user (default 1). Never claim channel 1 is guaranteed to correspond to General on every client.

## Roarboard writing and reactions

- A post contains a username, creation time, activity timestamp, reaction count and body text.
- Locally composed post text is restricted by `string.len` to **180 bytes**, not 180 Unicode characters.
- The board displays a preview shortened to about 42 bytes/characters according to Lua string operations; UTF-8 behavior has not been verified.
- “Roar” is a visible appreciation/reaction mechanic that increments `roarcount` and resets the activity window.
- Posts are pruned locally seven days after their last activity, not seven days after original creation if people keep reacting.

Roarboard is **not private** just because its interface says it is “for the people of ROAR”. It uses a custom chat channel and trusts protocol fields that any matching channel sender may provide. Avoid writing anything intended to be confidential or unmoderated abuse-resistant.

## Portfolio writing guidance

Preserve the author's original artistic statement—**“Characters are not loadouts. They are stories in motion.”**—while clearly separating built-in game emotes, project-authored guild copy, AI documentation writing and user-generated board posts. Do not publish actual players' posts or names in an external portfolio without their permission.

## Related development history

Roar Guild Addon (originally RoarGuild) combines the earlier multi-action trigger concept with an **expandable registry of client-native emote tokens**. Its master list starts with ROAR (ID 1), players can register additional client emote tokens via `/rogu emote <TOKEN>`, and select their IDs for individual trigger instances. Guild invitation messages are **manual recruitment chat broadcasts**, while the later August 2026 Roarboard provides a separate community feature. This Vanilla 1.12 history is distinct from the Wrath-targeted ROARTrigger port. Read [the full family timeline](EMOTE_FAMILY_HISTORY.md) for how these capabilities arose in the related repositories.
