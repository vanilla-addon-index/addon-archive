# Roar Guild Addon — changelog

**Project author:** Babuni. Historical dates here are **Git commit dates**, not asserted release or in-game-test dates.

## 2026-10-26 — expanded portfolio/developer documentation

- Rebuilt source-grounded README, concept, roadmap, architecture, design, content, decisions, narrative development history, attribution and agent instructions.
- Documented the early combined GodBod implementation and its later removal, the per-character/emote/fallback evolution and Roarboard's August 2026 addition.
- Clarified manual ROAR behavior, fallback and reminder timing, board retention and its unauthenticated custom-channel transport.
- Added a security and multiplayer verification backlog without claiming the addon is secure or already tested.
- **Markdown-only:** no Lua, TOC, LICENSE or gameplay behavior changed; no in-game tests.

## Milestones visible in Git history

| Date | Commit | Evidence |
| --- | --- | --- |
| **2026-01-10** | `48db733`, `6833bfc` | Early RoarGuild code joined ROARRunlimited-style battle emotes with a `/godbod` microbreak system; source/TOC showed both saved-variable families. |
| **2026-01-12 to 01-24** | Many source and TOC revisions; `d4a6e25` | Gradual refinement toward the RoarGuild-only package; TOC removed integrated GodBod wording and declared only `ROGUDB`. |
| **2026-01-26 to 01-30** | Profile/emote and README updates; `fb67759`, `c7f8043` | Source version was aligned to **1.32** and `/rogu fallback chance` / `fallback timer` customization was added. |
| **2026-02 to 03** | Repeated source edits; `b32381f`, `36727fa` | README clarified guild recruitment; `/rogu roar` changed to always use the built-in ROAR token. |
| **2026-03-28** | `817aae3` | Corrected a broken quoted guild invitation line—evidence of content/parse maintenance, not of test success. |
| **2026-08-17–18** | `64ae579`, merge PR #5 `b539119` | Roarboard message board code and **v1.33** README/manifest added via a PR lineage. |
| **2026-09-03** | `1ba833d` | Rewrote/condensed the guild recruitment text pool to shorter approachable messages. |
| **2026-09-18** | `c682e5b` | Generalized client names to Vanilla WoW 1.12 terminology. |
| **2026-10-26** | Prior author-credit and docs commits | Standardized display credit and added an initial lightweight documentation scaffold before this expansion. |

The source is the authority for current functionality. Past commit messages do not reveal every discussion, motivation, or success/failure in game. Do not infer that all originally proposed features were approved or retained.

## 2026-11-01 — Roar Guild Addon naming

- I renamed the GitHub repository from `RoarGuild` to `RoarGuildAddon` to distinguish the addon from my ROAR guild.
- I clarified that the addon was made for guild members, including its emote and manual invitation features; this records my intent, not verified adoption.
- At my request, AI updated documentation only. No Lua, TOC, license or gameplay test was changed.

## 2026-11-01 — documented the emote-family evolution

- Clarified this project's expandable native-emote registry as a new capability relative to the fixed earlier battle-emote lists.
- Linked [the complete family history](docs/EMOTE_FAMILY_HISTORY.md) and separated the Wrath port from later Roarboard features. No Lua/TOC edits.
