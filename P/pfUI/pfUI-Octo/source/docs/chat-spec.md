# pfUI Octo :: Chat (Prat's ideas) - plan

User, 23 Oct 2026: "I want to add prat to our addon the functions and art work automatic whisper
window options etc there is alot here menu feels messy could we use a preview here also ? with
window toggles etc to test whats what".

Licence: Prat-3.0 (3.9.113, the user's zip) is GPL-3; pfUI is MIT. Its option list was read for
feature names only - no code, art or sounds copied (its sounds are .ogg, which 1.12 cannot play).
Some of its fonts carry their own free licences (Liberation, Fira, DejaVu: OFL / free); if used,
they come with their licence files, like the fonts copied from OctoBG.

## What pfUI already has (kept, moved onto the new pages)
History, timestamps (format, colour, brackets), short channel names, URL detection and copy, class
colours and unknown-class who-search, player links, item tooltips on mouse-over, sticky chat, dock
background / dock on mouse-over, tab flashing, custom colours, whisper colour and layout, fade,
chat bubbles (+ party, borders), text shadow, frame shadow, input box size, chat widths, combat log
hide, left / right panels.

## Phase 1 - the Chat section and its preview
- Octo section "Chat" (replaces pfUI's Chat category; Panels stay on their own page):
  pages Windows, Messages, Input and tabs, Whispers (phase 3 fills it).
- Pinned preview: a scaled copy of your chat area - left and right chat panels, their tabs, the
  edit box, the dock - showing sample lines of every kind (guild, party, raid, whisper in / out,
  say, yell, channel, loot, system, an item link, a URL, your name mentioned) drawn with your
  settings: font, size, outline, shadow, timestamps, channel tags, name colours, background,
  border.
- Every part is clickable to its card (tab, edit box, timestamp, channel tag, a name, the
  background, the border, a link); drag the panels, Shift + wheel = font size / panel size,
  right-click = put back - as on the other previews.
- Window toggles over the preview: Left chat / Right chat / Whisper window / Combat log on or off,
  lit while on; "Show test lines in my chat" (local only, never sent).
- Looks (one click, lit while in use): Octo, Clean, Classic (Blizzard-like), Minimal, Bubble.

## Phase 2 - Prat's message features
Timestamps (more formats, per window), channel names editor (own short tag per channel), player
names (class colour, level, brackets, target / group marks), highlight words + your name (colour,
sound, popup), sounds per message type (game sounds), copy a whole window, search (/find), more
scrollback lines, mouse wheel speed with Shift / Ctrl jumps, edit box above / below / attached,
arrow keys without Alt, edit history, /tt (tell target), alt-click a name to invite, item icons in
links, link tooltips on hover, spam throttle and custom filters, /clear.

## Phase 3 - whisper windows
Whispers open in their own small window (or a tab, picked in options), one per person: history,
class icon and level, reply box, unread flash and count, sound, auto-hide in combat, keep / close
rules. Opened automatically on an incoming whisper (and on yours). Art of our own
(tools\MakePlateArt.ps1 style): window frame, tab, unread badge, buttons.

## Not planned
Prat's retail-only parts (achievements, newcomers chat, server names, cross-realm), Alias (game
already has macros), AddonMessages (debug).

## Phase 1 done (23 Oct 2026, not seen in game)
modules/chat-options.lua (`pfUI.chatOcto`): section "Chat" (chwindows, chmessages, chinput) replacing pfUI's Chat
category; pinned preview (CH.Format draws each sample like pfUI's formatter: time, [G] tags, [2] channel
numbers, class colours, [W] whispers, web links); switches over it (CH.TOGGLES: Loot & Spam, Whispers tab via
FCF_OpenNewWindow + WHISPER group, Combat log tab, timestamps, class colours, short channels), looks
(CH.LOOKS), "Show test lines in my chat" (local AddMessage only). Settings pfUI reads only at login are
marked "Takes a reload".

## Phase 2 done (23 Oct 2026, not seen in game)
modules/chat-plus.lua (`pfUI.chatPlus`, settings C.chat.plus): before pfUI's formatter (frame.AddMessage) hidden
words, spam throttle, own channel tags; after it (frame.HookAddMessage) levels next to names (P.levels from units /
/who), your name + words highlighted in the message part (not inside links), /find buffer; events: sound per kind,
mention sound + popup (pfChatMention), whispered invite word; Alt-click name = invite (SetItemRef wrapped, re-wrapped
every 2 s if replaced); Shift / Ctrl + wheel jumps; /tt, /find, /clear. Cards on Messages (Highlights, Sounds,
Filters, own tags, levels) and page Tools. Not possible on 1.12: item icons in links (no |T escapes).

## Phase 3 done (23 Oct 2026, not seen in game)
modules/chat-whispers.lua (`pfUI.whispers`, settings C.chat.whisper): a window per person (header: class icon,
name in class colour, level / guild from GetUnitData + chatPlus.levels; buttons invite / target / who / fold /
close; ScrollingMessageFrame with times; edit box sends SendChatMessage WHISPER; corner grip; edge flashes while
unread - focus tracked by hand, 1.12 has no HasFocus). Windows cascade from the first one's saved place. Combat:
pop | fold | wait (queue opened on PLAYER_REGEN_ENABLED). Last lines per person in pfUI_cache.whispers[char-realm].
"Also in chat" off removes the WHISPER group from chat windows (put back when on). Mode tab = phase 1's Whispers
tab. /whispers [close|test]; WH.Test() talks only to itself. Page Chat > Whispers.
