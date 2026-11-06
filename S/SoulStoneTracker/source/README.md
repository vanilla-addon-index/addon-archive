# SoulstoneTracker for WoW 1.18.1 Clients

[![Nampower](https://img.shields.io/badge/Nampower-Optional-yellow.svg)](https://github.com/brues-code/nampower)

Works without client mods. With Nampower 4.5 or newer it also detects casts exactly (every soulstone and curse rank, including soulstones cast by group members without the addon).

/ss help for commands

Tracks Soulstones caster and target. Curse / Banish Assignment.
Will sync/update if others have the addon installed

---------------------------------------------------------------------------------------------------------------------------

**Fork changes**

Still syncs with the original SoulstoneTracker: the addon messages are unchanged.

Classic WoW theme
- new default look: Blizzard tooltip-style panel in the same neutral dark colors as Bagshui, gold titles and headers,
  drop-shadow text, silver fading dividers, quest-log hover glow on rows, red title pulse in a stone's last minute
- stock red close button; gold settings cog and S (resync) button that light up on hover
- settings window uses the stock dialog box with a gold header plate that fits the title, checkboxes, sliders and red buttons
- switch back to the original purple look in Settings > Display, or with /ss theme shadow (/ss theme classic to return); needs /reload

Curse and banish section
- a warlock with no curse detected shows a greyed-out Death Coil icon
- a warlock with no banish mark shows a small greyed-out Banish icon
- both turn back to full color once a curse or mark is assigned; clicking them works as before

Minimap button
- same size and round gold border as other minimap buttons (was a small square)

Non-warlock characters
- the addon is off on characters that aren't warlocks: no window, no minimap button, nothing tracked or sent
- /ss enable turns it on for that character (and /ss disable turns it back off); needs /reload
- when turned on for a non-warlock, that character is no longer listed in the curse and banish section as if it were a warlock

Fixes
- tracking keeps running while the window is closed: expiry warnings, expired alerts and raid announcements,
  clearing expired stones, the soulstone cooldown check and the 5-minute resync used to stop until the window was
  reopened (closing it with the X, the minimap button, /ss or "hide when not in party/raid" all caused it)
- the window isn't redrawn while it's closed, and redraws straight away when reopened
- settings, lock and close icons showed up black: the .blp copies have no colour, so the .tga files are now used
  (gold like the S button in the Classic theme, the original colours in the purple theme)
---------------------------------------------------------------------------------------------------------------------------
1.5

- added transparency slider
- fixed SS remaining and timer
- fixed column width
- S icon does a sync now vs scan
- added ability to hide when not in party/raid

V1.2 added settings page cleaned up icons

V1.1 added curse/banish tracking

V1.0

---------------------------------------------------------------------------------------------------------------------------

**Credits**

- SoulstoneTracker by Waylock ([Wayoff333/SoulstoneTracker](https://github.com/Wayoff333/SoulstoneTracker)), the original addon this fork is based on
- [Nampower](https://github.com/brues-code/nampower) (optional), used for exact cast detection