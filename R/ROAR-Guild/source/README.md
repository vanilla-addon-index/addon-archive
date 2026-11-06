# Roar Guild Addon — characters are stories in motion

**Creator and project author:** Babuni  
**Current version:** 1.33  
**Target declared by manifest:** World of Warcraft 1.12 / interface `11200`  
**Primary files:** `roarguild.lua`, `roarguild.toc`  
**Verification status:** Source and Git history inspected 2026-10-26; live-client behavior not retested.

This is my **Roar Guild Addon**, originally named **RoarGuild**. I made it in connection with the **ROAR guild**, hoping guild members would use the character emotes and invitation messages as part of our shared identity. The new name makes it clear that the guild and the addon are separate things.

The GitHub repository is [RoarGuildAddon](https://github.com/babunidev/RoarGuildAddon). Its installed addon remains **RoarGuild**, with `roarguild.lua`, `roarguild.toc`, `ROGUDB` and `/rogu` unchanged.

**RoarGuild** is a World of Warcraft character-expression and community addon. It connects three kinds of experience: action-button-driven emotes, welcoming recruitment language for the ROAR guild, and **Roarboard**, a peer-shared message board. The original creative description gives its center of gravity:

> RoarGuild is not about optimization. It is about presence.

**Characters are not loadouts. They are stories in motion.** An ordinary action-bar press may produce a spontaneous emote without changing the player's intended action. Players can configure independent instances and emote selections, while rare global fallback roars and optional reminders add a little unpredictability.

## Install

Place the committed `roarguild.lua` and `roarguild.toc` inside `Interface/AddOns/roarguild/`; restart the client and enable **RoarGuild**. The TOC loads `roarguild.lua` and declares the account-wide SavedVariables table `ROGUDB`.

The source targets 1.12-era Lua APIs but actual compatibility and coexistence with other `UseAction` wrappers have not been verified in this audit.

## The action-triggered emote system (`/rogu`)

1. Type `/rogu watch`, press a button, and note its physical action-slot number; type `/rogu watch` again to hide slot reports.
2. Set up an instance such as `/rogu slot1 13`.
3. Change it with `/rogu chance1 40` and `/rogu timer1 10`.
4. Add an available native WoW token with `/rogu emote LAUGH`, then run `/rogu emote list` to see its assigned ID.
5. Use `/rogu emote1 <id>` to include that ID in instance 1, or `/rogu emote1 list` to inspect the pool.

The number in `slot1`, `chance1`, `timer1` and `emote1` is the **configuration instance ID**, not the physical action-slot number. Multiple instances are supported; each has its own `slot`, `chance`, `cd`, `last`, and `emoteIDs`. Instances may share one physical slot and can then both attempt an emote from one press. Configuring an instance resets its cooldown gate.

The shared emote database starts with **ROAR** at ID 1. The instance's emote IDs refer to this **account-wide list**; instances, enabled state, fallback configuration and statistics are stored in a **per-character profile** under `ROGUDB.profiles`. The code normalizes invalid/empty selections to ID 1, but does not enforce that a previously customized valid ID-1 token must always remain ROAR.

### Main commands

| Command | What it does |
| --- | --- |
| `/rogu` or `/rogu help` | Print usage |
| `/rogu watch` | Toggle action-slot number display |
| `/rogu slotX <slot>` | Create/retarget numbered instance X |
| `/rogu chanceX <0-100>` | Per-instance percent chance |
| `/rogu timerX <seconds>` | Per-instance interval |
| `/rogu emote <TOKEN>` / `emote list` | Register or list master emote tokens and IDs |
| `/rogu emoteX <id>` / `-<id>` / `clear` / `list` | Add, remove, reset, or show an instance's tokens |
| `/rogu fallback chance <0-1000>` | Set the global fallback chance **in thousandths** |
| `/rogu fallback timer <seconds>` | Set the fallback's minimum interval |
| `/rogu info` | Display version, profile, stats, fallback and instance settings |
| `/rogu resetcd` | Reset instance/fallback cooldown gates and session reminder times |
| `/rogu reset` | Clear all configured instances |
| `/rogu on` / `off` | Globally enable/disable automatic emote triggers |
| `/rogu roar` | Perform the built-in **ROAR** token immediately |
| `/rogu rexp` | Display rested XP as up to 30 bubbles |
| `/rogu invite` or `/rogu invite <1-10>` | Send randomized ROAR recruiting text to a numbered chat channel |

**Timing:** For configured instances, the cooldown timestamp advances *before* the chance roll, so a failed roll still consumes an interval. The separate global fallback defaults to **5/1000 = 0.5% per eligible press**, with a **2-second** throttle after a successful fallback only. It considers action-slot IDs 1–200 and may also act on configured buttons. The fallback does not run if the addon is disabled. The manual `/rogu roar` command deliberately always uses **ROAR**, independent of instance emote settings.

**Other session behavior:** After a successful emote, the addon may print “You have not roared in a while.” once **420 seconds** have elapsed without another recorded emote, then throttles repeated reminders by **73 seconds**, checking only on subsequent action presses. It also tracks per-character lifetime emote count and a rolling-hour rate, reporting on activity after an elapsed hour. These are emote events tracked by the addon, not combat or performance metrics.

## Social and recruitment messages

`/rogu invite` chooses one of the curated, welcoming ROAR messages and sends it to a **numeric channel index** (default 1; inputs clamped to 1–10). The README historically called this “General,” but **channel 1 is not verified to be General** on every client/configuration. Check the channel before sending. This is an explicit command, not an automatic advertisement loop.

The messages emphasize exploration, shared stories, curiosity and respect rather than DPS, meters, or pressure. They represent the creator's guild-facing tone.

## Roarboard: a shared message board

Roarboard was added in **August 2026**, providing a small in-game post list and reaction interaction:

| Command / action | Outcome |
| --- | --- |
| `/roarboard` | Open a movable board with a **12-row** paged list and selected post detail |
| `/roarboard <message>` | Send a new post of up to **180 bytes** of string length |
| `/roarboard sync` | Broadcast a request for other connected clients to resend their cached posts |
| Click **Roar** | Send a reaction event, increase the visible count and refresh that post's last-activity timestamp |
| **Newer / Older** | Page through available cached posts |

Posts are retained in a local SavedVariables cache and pruned **seven days after their last recorded activity**. The board communicates using a normal custom WoW chat channel named **`roarboard`** and a simple `RB1` text protocol; there is **no external server or authenticated guild-only backend**.

**Important visibility and trust limitation:** The channel is not checked against actual guild membership. Others able to join or send in the matching custom channel may potentially read or forge board messages, and each client keeps its own cache. Board content is **not private guild storage**, guaranteed delivery or a globally consistent database. This limitation should be considered before posting private guild information.

## Historical scope

The January 2026 first version combined a ROARRunlimited-like emote system with a **GodBod microexercise** component and two slash commands. The later January 2026 versions **removed GodBod**, expanded the profile/emote/fallback/recruitment functionality and matured the standalone RoarGuild scope. Roarboard added a shared community layer in August. These steps are documented from commits, not an invented conversation.

The project has an existing **MIT LICENSE** credited to Babuni. This documentation review did **not** modify Lua, TOC or license, perform client tests, or merge the related `roar`, `roarr`, `ROARRunlimited`, and `WorkThatGodBod` repositories.

## Development documentation

- [Creative concept](CONCEPT.md) · [Interaction design](docs/DESIGN.md) · [Content and tone](docs/CONTENT.md)
- [Architecture and protocol](docs/ARCHITECTURE.md) · [Decision record](docs/DECISIONS.md) · [Narrative journal](docs/DEVLOG.md)
- [Roadmap and verification](ROADMAP.md) · [Changelog](CHANGELOG.md)
- [AI collaboration and attribution](docs/AI_COLLABORATION.md) · [Contributor instructions](AGENTS.md)

## The guild addon's place in the emote family

Roar Guild Addon (originally RoarGuild) combines the earlier multi-action trigger concept with an **expandable registry of client-native emote tokens**. Its master list starts with ROAR (ID 1), players can register additional client emote tokens via `/rogu emote <TOKEN>`, and select their IDs for individual trigger instances. Guild invitation messages are **manual recruitment chat broadcasts**, while the later August 2026 Roarboard provides a separate community feature. This Vanilla 1.12 history is distinct from the Wrath-targeted ROARTrigger port. See the [cross-repository history](docs/EMOTE_FAMILY_HISTORY.md) for the preceding fixed-pool experiments and the subsequent Flourish Forever spellcast model.
