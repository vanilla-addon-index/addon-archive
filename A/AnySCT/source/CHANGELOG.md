# Changelog

All notable changes to AnySCT are documented here.

## 0.3.1 — 2026-10-15

### Fixed
- Lines in a tower no longer overlap: each line reserves its real height (crits at the peak of their size pop) plus the suffix line hanging below the line above it, and crits now rise with the rest of the stack instead of standing still, so newer lines can no longer rise into them.
- Crits of tiny procs (relative to the source's average hit) pop at up to half size.

## 0.3.0 — 2026-10-15

### Added
- **Merge identical hits** (Text tab, on by default): identical attacks (same source, victim and ability; normal hit or crit kept apart) within the **merge window** (0.1-1.5 s, default 0.4) become ONE line whose number is the running sum, updated in place. Misses and other words are not summed; identical words collapse. Optional **Show hit count** appends e.g. ` x5`.
- Placement **Nameplate + anchor** (`/asct place both`): every line and the GO / WAIT label appear over the victim's nameplate and at the fixed anchor, with separate line limits per place. Without a plate it shows once at the anchor.
- The **Demo** button and `/asct demo` now play a 2.5 s burst of the first listed targetSCT's class skills (a shaman demo tank without a list; amounts for the shaman set from recorded tanking fights, estimates for other classes) through the normal display path, so spell names, name prefixes, colours, limits and placement apply. Every result type (crit, Miss, Dodge, Parry, Block) appears, and a simulated GO / WAIT label previews the threat display (also with GO / WAIT switched off).

### Changed
- The GO / WAIT label at the fixed anchor sits inside the anchor box (now 200 x 30); damage lines in anchor mode start above its top edge.
- Anchor X / Y sliders span the real screen instead of fixed +-800 / +-500 and never clamp a stored position.
- The options window is 540 px high to fit the new Text-tab controls.

### Fixed
- The fixed anchor jumped to another place when dropped after a drag: the drop position was computed from `UIParent:GetWidth()` / `GetHeight()`, which are not in the coordinate system of frame rects on a non-default UI scale. It now uses the screen rect's centre and rounds to whole units; slider refreshes no longer write back while dragging.

## 0.2.0 — 2026-10-15

### Changed
- **Every hit is shown**: the default line limits are now 16 per mob (was 4) and 60 on screen (was 16), sliders up to 30 / 100, so a burst of about 10 hits per second is no longer recycled. Saved limits that still equal the old defaults are raised; limits you chose yourself stay. A tall stack is kept below the top screen edge.
- "Tank" is now **targetSCT** in every visible string (menu entry "Mark as targetSCT", options, chat
  output, minimap tooltip). Nothing changed in behaviour. Saved settings are migrated on first load;
  `/asct tank <name>` still works as an alias of `add`.
- The options window is regrouped by function into four tabs (targetSCTs, Text, Colours, Placement) with
  section headers, and **every control's tooltip now also shows when you hover its label**.

### Added
- **targetSCT name** option (Never / Only with several targetSCTs / Always): the unit's name, or the
  owner's for pets and totems, first on the line under the number (`Name - Spell - Victim`).
- **Own colour per targetSCT** (off by default): each listed unit gets its own colour, picked from a
  palette so that colours differ well (the first is the client's pet orange). Pick your own with the
  swatch in the list; **Auto colours** (or `/asct colours`) reassigns them. Saved with the list.
- **Experimental GO / WAIT label** from the server's threat data (like TWThreat): shows over your own
  elite or boss target how much threat lead the targetSCT has over you. Options: enable, required buffer
  (0-7500), and a Threat switch per list row. `/asct threat` prints its state. Optional *Record threat
  trace* (off by default) writes the received data to `<WoW>\imports\anysct_threat.txt` for bug reports.

### Fixed
- nampower builds that deliver spell damage and miss events without the `NP_Enable...` CVars are detected through `GetNampowerVersion`, so spell events no longer fall back to chat rows. An opt-in event ledger (trace option or `/asct debug`) writes `<WoW>\imports\anysct_events.txt`.
- The options window sits above world nameplates (frame strata DIALOG).

### Removed
- The hit-count GO / WAIT indicator (`goAfterHits`); the saved option is dropped.

## 0.1.0 — 2026-10-14

First release.

- A short list of units (right-click menu **Mark as tank**, `/asct add`, options window, or imported
  CT_RaidAssist / oRA main tanks); saved per character.
- Their melee, special attacks and misses float over the **victim** in the client's own world-text style;
  pets and totems of a listed unit are shown under the owner.
- Heals received by a listed unit (green `+amount`, optional healer name, HoT ticks, your own heals).
- Placement over the victim's nameplate (clamped to the screen edge) or at a movable fixed anchor.
- Sources: nampower events when present, otherwise the chat log; SuperWoW GUIDs when present.
- Options window with tabs, colour pickers and a minimap button; zero idle cost.
