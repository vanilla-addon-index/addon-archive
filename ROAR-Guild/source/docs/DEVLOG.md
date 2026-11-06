# Roar Guild Addon — narrative development journal

**Human creator and creative director:** Babuni  
**Retrospective compiled:** 2026-10-26 from the repository README, TOC, current Lua and selected Git diffs. This is **not** an original chat transcript; motivations and approvals are not invented.

## January 10, 2026: combining two little experiments

The first RoarGuild code arrived on **2026-01-10** (`48db733`) as a larger experiment than the eventual name might imply. Its source comment described **ROARRunlimited / RoarGuild**, carried emotes attached to action-bar slots, and declared both **`/rogu` and `/godbod`**. The manifest and source identified two SavedVariables families. That initial composition linked expressive in-world roars with the real-world exercise nudges explored by WorkThatGodBod.

The available Git diffs show that these capabilities were physically brought into one addon. They do not preserve the creator's original brainstorming session or tell us who proposed combining the modules. A portfolio should record the experiment but should not claim a particular tradeoff was debated if no evidence survives.

That first unified implementation already relied on a player action rather than an autonomous combat engine: a normal `UseAction` press, a configured instance, a chance roll and a built-in emote. The playful surface was character presence rather than competitive advantage.

## Mid-to-late January: RoarGuild becomes its own product

There were many short revision commits on January 12–30. By the **January 24** manifest update (`d4a6e25`), the GodBod description and SavedVariables were removed from RoarGuild. The current file contains no `/godbod` handler: GodBod remains its own separately documentable project. This is a meaningful departure from the early combined-product approach.

The system grew deeper instead of wider in that direction. It gained per-character profiles using a name–realm key, account-wide shared emote definitions, different emote IDs per configured instance, independent chance and cooldown controls, and a global rare fallback. The code includes a one-time migration path from older root SavedVariables into a character profile, showing that maintaining existing player configuration was a concern encoded in implementation.

On **January 30**, commit `c7f8043` exposed **fallback chance and timer commands** and `fb67759` aligned the version constant to **1.32**. The source now presents a default 0.5% fallback chance for action-slot IDs 1–200, a two-second interval after successful fallbacks, and flexible numbered instances. A separate reminder after seven minutes without a recorded roar and rolling-hour emote counts add self-awareness to the expressive toy. They do not measure DPS or combat skill.

The README describes this broader philosophy in vivid human language: **“It is about presence.”** That is the correct attribution for the vision. An AI collaborator may have contributed code, fixes or prose at various points, but no complete conversation in the inspected repo assigns precise origination of every feature, so this journal will not invent it.

## February–March: voice, recruitment, and the meaning of a manual roar

The code and README continued to evolve through February and March. By the **February 19** README change (`b32381f`), guild recruitment had become an explicit part of the project. The `/rogu invite` command sends a randomly selected, ROAR-themed welcome message to a user-selected numbered chat channel. This is not an automatic announcement timer: the player chooses when to broadcast.

There was a small but revealing March correction. On **2026-03-28**, `36727fa` changed the manual `/rogu roar` command to call **ROAR directly**, rather than drawing a token from instance 1's configured pool. That preserves a dependable act of identity—typing the command means roaring, even when the character normally laughs, cheers or performs another emote on their action bar.

A different March 28 commit (`817aae3`) repaired an unterminated quote in one recruitment message, showing practical maintenance of the text pool. The code record establishes the fix, not what errors were observed by players.

## August: Roarboard turns expression into a shared object

On **2026-08-17–18**, the Roarboard feature was added (`64ae579`; PR #5 merge `b539119`) and the addon advanced to **v1.33**. Instead of only making the player's character perform, the addon could now retain short messages and collect Roar reactions from others. The user opens a compact game-native board and sees a list of posts, author, date, text and accumulated appreciation.

The architecture is intentionally lightweight. It uses **`RB1` text packets** over a custom channel called **`roarboard`**, plus local SavedVariables caches. There is no external service. A post expires after seven days of inactivity; a Roar reaction extends its activity. A sync command asks connected peers to resend cached posts, an appealing way to let a small community assemble a shared board with only game-native tools.

The feature's name and subheading position it as a guild space. But the current code does not verify guild membership when someone subscribes to the channel or sends a protocol message. Any account with access to that custom channel may potentially participate. That mismatch between **social intent** and **technical authorization** should not be concealed in the portfolio or user instructions. Source reading cannot establish whether security incidents occurred; it only identifies where verification and future author decisions are required.

## September: refining the guild's public voice

A **2026-09-03** revision (`1ba833d`) substantially simplified the pool of recruitment messages, replacing longer or rhyming variants with shorter, welcoming descriptions of casual adventure, curiosity, shared stories and kindness. This is a visible editorial iteration, not a claim about a recovered author/assistant debate. A **2026-09-18** change generalized specific client branding to Vanilla WoW 1.12 wording.

The current guild copy avoids the language of performance meters. It invites players to enjoy a world rather than complete a checklist. In that sense, the recruitment writing, action-emote mechanics and Roarboard have become three expressions of the same direction: **make room for character and community without reducing play to optimization**.

## October 26: documenting rather than rewriting

Earlier October 26 commits established Babuni display attribution and a short docs scaffold. The present pass examined the extensive repository and Git history, rewrote the user guide and developer documentation, identified technical and privacy boundaries in Roarboard, and distinguished old GodBod functionality from the current RoarGuild release.

**AI contribution in this pass:** source inspection, technical analysis, narrative reconstruction and Markdown documentation changes. **User role:** original creative authority and sole arbiter of future direction. **Not done:** runtime Lua changes, TOC edits, license changes, gameplay/network tests, guild membership verification, approval of new protocols or merging other repositories.

## Living questions

Should Roarboard be open to anyone sharing the custom channel, or should it represent the ROAR guild's actual membership? Should a reaction be limited per person? Do the playful statistics and seven-minute reminder fit the creator's wish for a non-performance-oriented guild? The code poses these questions; the creator has not answered them in the evidence available for this pass. Future journal entries should record the actual conversation and decision when that happens.

**Evidence confirmed:** dated commits, current feature structure, source-level timing and protocol, stated creative philosophy. **Evidence still missing:** complete original discussion history, client-side gameplay tests, synchronization/security outcomes and user experience feedback.

## November 2026 — separating the guild from its addon

The addon was made in connection with my **ROAR guild**, and I hoped members would use it to share expressive emotes and recruitment invitations. The name **RoarGuild** did not clearly separate the actual guild from the software built around it, so I renamed the GitHub repository **RoarGuildAddon** and chose **Roar Guild Addon** as its public title. My AI assistant revised the project documentation at my direction. This does not establish how widely members used it, and no runtime features were changed or tested during this documentation pass.

## 1 November 2026 — finding the editable-emote milestone

Comparing my earlier battle-emote experiments revealed where player-added emotes actually arrived: **this Roar Guild addon**, not ROAR/ROARR or ROARRunlimited. The master list begins with ROAR and players can add client-recognized emote tokens and associate them with numbered trigger instances. I remembered the ROAR guild recruitment copy as another favorite part of this project; its manual invite command sends welcoming chat text, not a game invitation to a named player. My AI assistant verified the source and placed it in [the family history](EMOTE_FAMILY_HISTORY.md), alongside the later Wrath port and Flourish Forever. No runtime changes or game tests.
