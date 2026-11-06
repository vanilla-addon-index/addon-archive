# Roar Guild Addon — interaction, visual design and community experience

This addon was meant to give members of my **ROAR guild** a shared expressive tool, including emotes and invitation messages. Its new public name, **Roar Guild Addon**, separates that optional software from the guild itself.

**Creative director:** Babuni.

## The character as an expressive participant

RoarGuild deliberately places small spontaneous gestures on actions the player already makes. The original README contrasts **presence** with optimization: roaring is not intended to improve the player's damage rotation or win an encounter. The player can make an instance reliably expressive with 100% chance or create rare surprises by lowering odds and choosing a larger emote pool.

The UI stays mostly out of the way. `/rogu watch` temporarily prints physical slot numbers; slash commands bind them to independent numbered configurations. The addon uses game-native `DoEmote`, not custom audio files or animations. Fallback supplies a very small chance to react on other eligible button presses. A silence reminder and emote statistics introduce additional feedback, but only in response to player activity.

## From personal flair to belonging

The guild invitation messages are less like automated marketing and more like short statements of community temperament: shared experiences, patience, kindness, unhurried exploration, laughter and stories. They consciously contrast with meters, hurry and competitive optimization in the repository's authorial text. The messages are sent **when the player issues the invitation command**; there is no autonomous recruitment spam engine in the current source.

## Roarboard's spatial metaphor

The board is a simple two-column dialog, **not a full social network**. On the left, 12 compact post previews show name and shortened message; on the right, the selected author's name, timestamp, reaction count and full text. Pagination buttons labeled **Newer** and **Older** advance by a page. The **Roar** button acts as a shared appreciative reaction and extends that post's lifespan.

This is a credible extension of the creative idea: the same expressive “roar” that celebrates an action can celebrate somebody else's words. The UI is rendered using existing WoW frames, font strings, textures and UIPanel buttons rather than imported artwork.

## The consequential mismatch: guild culture versus open channel

The copy calls it a “shared guild message board,” but the technology is an independently joinable chat channel called `roarboard` with no membership verification in the source. This means community boundaries are **aspirational and social**, not enforced technically. It may be suitable for non-sensitive friendly posts, but should not be described as a secure internal guild noticeboard until protections are designed and tested.

The source also does not implement a moderator/admin panel, post deletion command, or reliable offline message storage beyond whatever peers currently have cached.

## Accessibility and test questions

- Are the 180-byte posts readable and practical in localized/UTF-8 client conditions?
- Does Roarboard's 700×460 window fit smaller screens and scale settings?
- Is the 12-row list navigable by keyboard or only by mouse?
- Does a user know the scope of broadcasting to `roarboard` before posting?
- Are chance-driven emotes and periodic reminder messages too noisy during group play?
- Can guild invitations be directed to the intended channel without mistakes?

These are proposed test questions, not evidence of user research or an approved redesign.

## Related development history

Roar Guild Addon (originally RoarGuild) combines the earlier multi-action trigger concept with an **expandable registry of client-native emote tokens**. Its master list starts with ROAR (ID 1), players can register additional client emote tokens via `/rogu emote <TOKEN>`, and select their IDs for individual trigger instances. Guild invitation messages are **manual recruitment chat broadcasts**, while the later August 2026 Roarboard provides a separate community feature. This Vanilla 1.12 history is distinct from the Wrath-targeted ROARTrigger port. Read [the full family timeline](EMOTE_FAMILY_HISTORY.md) for how these capabilities arose in the related repositories.
