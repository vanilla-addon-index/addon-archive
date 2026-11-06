# Roar Guild Addon — observed choices, unresolved decisions and alternatives

**Decision authority:** Babuni. Source evidence is not itself a record of formal conversations or approvals.

## Implemented, evidenced choices

| Subject | Current code and history | Status |
| --- | --- | --- |
| Emotes linked to player action | `UseAction`, numbered instances | Implemented; does not verify successful cast |
| User-defined emote pools | Account-wide `ROGUDB.emotes` and per-instance `emoteIDs` | Implemented; ID 1 defaults ROAR |
| Character-specific settings | `ROGUDB.profiles[name-realm]` | Implemented with legacy root-data migration |
| Rare global fallback | `chancePermille=5`, `cd=2` | Implemented; successful fallback advances its timer |
| Guaranteed manual ROAR | `36727fa` March 2026 | Implemented `/rogu roar` no longer chooses from instance 1 |
| Recruitment to selected channel | `/rogu invite`, `inviteText` | Explicit outbound text; not automated broadcasts |
| Roar activity statistics | Per-profile `stats`, rolling hour | Implemented on button-press activity |
| Roarboard | August 2026 PR/commit `64ae579` | Implemented as custom-channel peer cache, **not authenticated guild data** |

## The important early direction change

The earliest January 10, 2026 committed code combined RoarGuild with **GodBod** exercise functionality. January 24 changes removed the GodBod component from the standalone product and TOC, leaving RoarGuild focused on emotes and guild tools. This **implemented direction** can be traced in code and manifest; a detailed conversation describing rejected alternatives is not present in the inspected repository.

The August 2026 board added a community record layer. September shortened recruitment copy. Those iterations should remain visible rather than presenting the current feature set as if it appeared in one fully approved initial plan.

## Risks, not verified bug reports

- Roarboard custom channel is not guild-authenticated; arbitrary matching protocol messages can affect local caches.
- No independent server, permission model, sender identity proof or guaranteed delivery.
- Sync request may cause many peers to resend all posts.
- Reaction deduplication is by event ID, not verified per-player identity.
- Character profile migration consumes legacy root fields on first migration.
- An instance chance failure consumes an interval; fallback failure does not.
- The account-wide ID-1 emote is not permanently forced to ROAR when an existing valid token is present.
- Guild invitation numeric channel index may differ by client.
- UI/window and WoW 1.12 event assumptions have not been tested during documentation.

## Open creator questions, not implicit approvals

1. Should Roarboard become truly guild-restricted or retain its open-channel social nature?
2. Does the project need moderation, per-user reaction limits, post deletion or a more controlled sync protocol?
3. Should stats and reminders remain as written or become optional to avoid competitive pressure?
4. Should fallback and configured slots be able to both produce emotes on one press?
5. Which historical combined-GodBod experiments deserve portfolio focus without reintroducing removed behavior?
6. Does Babuni want clearer channel selection and explicit confirmation for recruitment posts?

No executable feature or policy decision was made by the documentation-only session.

## November 2026 — name and community purpose

The public project name is **Roar Guild Addon**, and the GitHub repository is **RoarGuildAddon**. I chose this to distinguish the addon from the ROAR guild itself and to preserve the original intention of encouraging guild members to share emotes and invitation messages. The installed **RoarGuild** addon identifiers remain unchanged. AI performed documentation edits only.

## Related development history

Roar Guild Addon (originally RoarGuild) combines the earlier multi-action trigger concept with an **expandable registry of client-native emote tokens**. Its master list starts with ROAR (ID 1), players can register additional client emote tokens via `/rogu emote <TOKEN>`, and select their IDs for individual trigger instances. Guild invitation messages are **manual recruitment chat broadcasts**, while the later August 2026 Roarboard provides a separate community feature. This Vanilla 1.12 history is distinct from the Wrath-targeted ROARTrigger port. Read [the full family timeline](EMOTE_FAMILY_HISTORY.md) for how these capabilities arose in the related repositories.
