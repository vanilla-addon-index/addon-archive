# Changelog

Player-visible PandaQuest changes, newest first. Keep every bullet short, clear and focused on what changes for the player.

## Unreleased

## 0.6.0

### Changed

- PandaQuest and PandaMap now share one panda minimap settings button without pandaUI.
- With PandaTool installed, the HUD quest marker now follows camera tilt and zoom, even without ClassicAPI (PandaTool 0.1.3+).
- A ready quest's hand-in page now heads its reward panel "Rewards", like the completion page.
- Clicking the Immersive Dialogue card only turns pages; accepting or completing needs the button or Space.

### Fixed

- The navigation arrow now points at the quest area centre, the same spot as the HUD marker.
- The HUD marker and navigation arrow now find targets recorded on a neighbouring zone's map, e.g. Shazknock from Durotar.
- Immersive Dialogue reward choices now remain clickable outside the Minimal theme.
- The quest log's Follow button no longer cuts its label short.
- The Alliance and Horde dialogue buttons now centre their label on the button face.
- With pfUI's nameplates, the quest number now sits right beside the health bar instead of far off.
- With pfUI's tooltip, quest progress is added inside pfUI's tooltip, keeping its border and health bar.
- Spell and item tooltips sharing an NPC's name (e.g. Ancestral Spirit) no longer get a borderless box with a respawn timer.

## 0.5.5

### Changed

- The quest-tracker NPC finder now uses Modern WoW borders and checkboxes.
- The unfinished HUD quest marker and its settings remain hidden for later.
- The windowed (minimized) world map no longer shows its own copy of the quest tracker.
- The Minimal dialogue theme is 20% larger, with larger objective text and more room above its buttons.
- Tracker progress bars now have a two-pixel gap below objective text.
- Quest givers on the map and minimap show a grey "!" when the quest is 5+ levels above you.

### Fixed

- Minimal dialogue no longer reopens after accepting a quest.
- Minimal dialogue no longer cuts short NPC names and quest titles.
- World-map quest areas and markers now draw above PandaConquest overlays.
- Minimap quest areas and markers now follow PandaUI's Circle/Square setting.
- ClassicAPI's yellow question mark no longer appears over quest targets.
- Lucky Coin now shows the Trade District fountain on the map.
- Zooming out on the windowed world map no longer snaps back to your current zone.
- The windowed world map now updates quest areas and markers live, e.g. when a quest completes.
- The sell-value coin now shows on rewards whose name is shared by another item (e.g. Ranger Leggings).
- Minimap quest markers no longer get pulled into pfUI's minimap button bar.

## 0.5.4

### Added

- Quest reward comparisons now include Turtle WoW custom-item sell prices.
- NPC finder: 140 Turtle trainers, including Stonetalon's Shaman and the High Elf class trainers.
- NPC finder: 77 service NPCs: flight masters, innkeepers, vendors, repair and battlemasters.
- NPC finder: 87 missing creatures, 47 missing elite/rare/boss ranks and spawns for 152 creatures.
- Moonwhisper Coast now shows its flight masters, inns, vendors and elites.
- Settings: the Import page now asks the server for your completed quests.

### Fixed

- The quest tracker and navigation arrows stay on screen when you raise the UI scale.

### Removed

- The pfQuest, Questie-Octo and Questline imports and `/pq pfquest`.

## 0.5.3

### Added

- Settings: new Import page that copies finished quests from pfQuest, Questie-Octo or Questline.
- Settings: one Undo button takes back every import.
- Turtle WoW 1.18.1 world data: about 2,450 new quests, 5,000 creatures and 12,000 objects.

### Changed

- Settings: the pfQuest button moved from General to the Import page.
- Settings: with pandaUI, PandaQuest pages use the game's settings text size.
- Settings: PandaQuest pages now use the PandaQuest mascot watermark.
- Performance: fewer short freezes while idle.
- Tracker: with pandaUI, the quest tracker now draws under the game settings window.
- Quest dialogue: one click on Complete now hands a quest in.
- Translations are kept only while they match the English quest; Turtle quests show in English.
- Patrol routes, class trainers and sell prices still come from the Vanilla data.

### Fixed

- Race- and class-locked quests no longer show for every character on OctoWoW.
- Russian and Chinese text no longer shows blank on English clients (bundled PT Sans Narrow font).
- World map: an NPC that offers and takes quests now shows "!" and "?" side by side.
- World map: the followed quest's objective dots show their quest colour again.
- World map: a quest's numbered red circle no longer loses its number.
- The navigation and rare/elite arrows now show when pandaUI is enabled.
- Turtle's Heroic Training Dummy and tokenless city elites no longer show as Rare/Elite/Boss pins.

### Removed

- Tooltips: the grey divider line between stacked quests in map and tracker tooltips.

## 0.5.2

### Added

- Quest number icons on mob nameplates.

## 0.5.1

### Fixed

- The interface for client update 2432.

## 0.5.0

### Added

- Immersive quest dialogue with 6 themes.
- Option to auto-accept and complete quests.
- Quest marker on the target frame.
- Minimum and maximum levels for each dungeon on the map.

### Changed

- Dungeon and raid icons now use retail images.
- Completed quest numbers now appear in a green circle.
- Quest number icons no longer show on the map once the quest is complete.

## 0.4.1

### Added

- Elite quests show a "+" after their level ("[11+]") in the trackers, quest log and map tooltip.
- "Auto accept and complete quests" option, off by default; reward choices are left to you.
- Minimal dialogue: gossip options and a giver's quests are listed as buttons inside the card.
- Minimal dialogue: a "!" or "?" badge under the language flags.
- Minimal dialogue theme: a small dark card with portrait, objectives, rewards and Accept/Decline.
- Quest dialogue: a scene of the quest's zone behind the portrait; 40 outdoor zones have their own art.
- Quest dialogue: text types itself letter by letter; click once to show the whole page.
- Quest dialogue: with pandaUI, hovering a gear reward compares it with your equipped item.
- Quest dialogue: "Accept Quest" / "Complete Quest" button on the card's bottom border.
- Horde light dialogue: the quest badge shows "!" to accept and "?" to turn in.
- Quest creatures show Retail's quest shield on the pandaUI target portrait.

### Changed

- Performance: fewer slowdowns when accepting quests and drawing quest areas.
- The followed quest has a golden bar glow in the trackers and quest log.
- Quest dialogue: a compact parchment card with choices on the right, not a full-screen window.
- Quest dialogue: click the card to continue, right-click to page, Escape to close.
- Quest dialogue: rewards show under the text; turn-ins show required items and their counts.
- Quest dialogue: turn-ins list objectives with their counts, e.g. "Kobold Vermin slain: 10/10".
- Quest dialogue: reward money uses gold, silver and copper coin icons in every theme.
- Quest dialogue: drawn 40% smaller, text included.
- Quest dialogue: new profiles start on Minimal; an unknown saved theme falls back to Minimal.
- Quest dialogue: themes are Minimal, Parchment, Alliance, Horde, Alliance light and Horde light.
- Quest dialogue: the theme is picked from a dropdown and applies its size without a reload.
- Quest dialogue: objectives no longer have blank lines between steps.
- Minimal dialogue: the card sits two thirds down the screen.
- Minimal dialogue: the NPC name and "Quest Giver" are grey, the quest title gold.
- Minimal dialogue: reward experience and reputation are drawn in white.
- Parchment dialogue: new header, objectives under the text and gold-framed choice buttons.
- Alliance dialogue: new conversation frame with banners on both posts.
- Alliance, Horde and Alliance light cards draw a brown divider above the objectives.
- Horde light dialogue: taller reward banners with larger item icons.
- Without pandaUI, the first language follows the game client: Chinese, Russian or English.
- Zone-grouped trackers show each zone once, with completed quests at the bottom.
- Tracker header rails, zone bars and objective marks stay sharp at large UI scales.

### Fixed

- A quest offered right after a turn-in now opens as an offer with Accept.
- Minimal dialogue: the reward line, name and title no longer run past the card's border.
- Minimal dialogue: Accept and Complete buttons widen to fit their label and key hint.
- Objective text lines up with the Objectives heading in every language.
- Choosing a quest from gossip no longer makes the dialogue blink.
- Quest cards grow with long objectives instead of running under the button.
- Horde dialogue: the "Complete Quest" button no longer cuts its label short.
- Horde light dialogue: the card edges no longer show repeated spikes.

## 0.4.0

### Added

- Quest numbers on the map and quest tracker windows.
- Quest tracker windows on the map.
- Dots and/or areas on the map and minimap.
- Item rewards show an icon for the best item to sell and the best gear upgrade.

### Changed

- Reworked quest tracker windows.
- Reworked quest area mode; now works on Retail.
- Immersive gossip rows use high-resolution service and quest icons.

## 0.3.5

### Added

- Loot and drop rates in boss tooltips on the map.
- A "+" after the level of dungeon quests.

### Changed

- Profession quests are hidden on the map without the related profession.

### Fixed

- The interface for the latest client update.
- The progress bar not turning green for items not flagged as quest items.
- Flickering red button on the Modern WoW theme.

## 0.3.4

### Added

- Experience and reputation when accepting or turning in a quest.
- Quest translation when accepting or turning in a quest.
- Estimated time to reach the position.
- Quest log: pandaUI Modern objectives are grey, orange or green by progress.
- Quest log: a coin row for reward money under "You will receive:".
- Reward names in their item quality colour, with a setting to turn it off.

### Changed

- With pandaUI, PandaQuest is a submenu in pandaUI's settings with General and Mob tracking.
- Quest log: Show, Track and Follow are red buttons; Follow has a gold rim.
- Quest log: experience and reputation lines have a drop shadow.

### Fixed

- Tooltips sometimes showing at the wrong level.
- The quest log description flickering while scrolled down.
- A quest stuck as "ready to turn in" after its quest item was destroyed or sold.
- Experience and reputation lines drawn over the reward item on the offer window.
- "Proving Allegiance" in Tirisfal now points to the candle crate, then the altar.

## 0.3.3

### Added

- Settings: "Mob tracking" tab to search creatures and track one on the map and minimap.
- A movable mob arrow pointing to the tracked creature's nearest recorded spawn.
- Respawn times in creature and object tooltips, with a setting to turn them off.
- Experience and reputation rewards in the quest log and quest-giver windows.
- Language flags on the quest log and quest-giver windows to read one quest in another language.
- Separate rare, elite and boss switches for the mob alert.
- The rare/elite/boss alert shows how many times this character killed the creature.
- Tooltip mouse-out delay (0.25-1 s), shared with pandaUI; `/pq tooltip delay` sets it.

### Changed

- The tracked creature sticks to the minimap edge instead of disappearing.
- The tracked creature's line shows its zone.
- Only one creature is tracked at a time, on its own line with a red cross to stop.
- The player arrow is drawn above minimap quest markers, with a setting to turn it off.

### Fixed

- Quest log flags can switch back to the game's own text.
- Two tooltips showing at once when hovering things with quest progress.
- The native tooltip staying visible behind the combined tooltip.
- "Current zone only" showing the whole quest log inside a dungeon.
- Two settings options drawn on top of each other.
- The tracked creature's level printed inside two sets of brackets.
- Warleader Krazzilak missing from the Rare/Elite/Boss finder in Tanaris.

## 0.3.2

### Added

- Objective progress can be reported to party chat ("[PQ] Kobold Vermin: 4/8"); see `/pq announce`.
- "Completed objectives only" option for party reports.
- In a party, the quest log shows how many members share each quest.

### Fixed

- Completion-only party reports dropped when no member shared the quest.
- Collected-item progress going past the required count (4/3 now shows 3/3).
- Shift-click quest links in chat now use only the quest name.

## 0.3.1

### Added

- Click quest dots or markers on the map or minimap to follow that quest.
- Followed quests are highlighted on the map and minimap with a gold circle.
- Hovering a mob dot lists every related quest.
- Hovering a quest dot highlights the quest's turn-in position.

### Changed

- Quest dot colours are saved per quest across relogs.
- Item collection dots disappear one by one as each item is collected.

### Fixed

- The quest level staying visible when scrolling the quest log.
- The quest list running off the window in pandaUI's Modern theme.

## 0.3.0

### Added

- Quest navigator: an arrow to the nearest objective or ready turn-in in your zone.
- Quest navigator: live distance, and a green arrow for a ready turn-in; `/pq nav` explains it.
- Hovering a quest pin fades other quests' pins on the map and minimap.
- Following or hovering a quest pulses a gold circle at its turn-in.
- Hovering a stacked objective dot lists every quest at that spawn in its own colour.
- Unique roaming quest targets show as one dot with their patrol route, e.g. Hogger.
- Quest creature tooltips show the quest item's drop rate.
- Hovering a tracker quest enlarges its dots on the minimap.
- Two-page parchment quest log without pandaUI or with Classic WoW.
- Quest log: Following button and gold plaque for the followed quest.
- pandaUI Modern quest log: quest names coloured by difficulty and the level under the title.

### Changed

- Logging in no longer causes a several-second freeze.
- Stacked dots for the same spawn are merged into one dot.
- Quest dot colours stay the same after a reload or relog.
- The gold circle around the followed quest's turn-in is larger.
- Browsing the quest log no longer changes the followed quest; only Following does.
- pandaUI Modern quest log: smaller action row, roomier rows and green completed objectives.
- pandaUI Modern quest log: the scroll bar sits inside the left panel.
- Quest log levels, markers and plaque refresh instantly after a redraw.
- Two-page quest log: Share and Exit buttons line up with the artwork.
- Tracker rows grow with wrapped text without overlapping.
- The navigator is half the size and can be dragged; its position is saved.
- Navigator arrow opacity follows alignment; the arc is more opaque.

### Fixed

- Repeated game freezes after the world map had first been opened.
- Repeated quest-change notifications with duplicate quest titles.
- Quest levels vanishing from the quest log when scrolling.
- The followed plaque and tracked accent showing twice after scrolling.
- Long quest lists running off the bottom of the quest log.
- Emptied containers kept their dot and stayed navigator targets.
- An unfollowed quest coming back as followed after a reload.
- The pandaUI Modern Following button flashing its hover look.
- The navigator arrow warping instead of turning.
- The navigator pointing an unfinished quest to its future turn-in.

### Removed

- The 3D world quest marker, replaced by the navigator.

## 0.2.3

### Added

- Progress bars under counting objectives in the tracker, with a setting.
- "Show" and Ctrl+click open the map on the zone you need to go to.
- Patrol routes for unique quest targets, and on hover for service, rare and vendor pins.
- NPC finder: dungeon and raid entrances on both maps.
- "Show low-level quests" option, off by default.
- Exploration quests show their destination on the map and minimap.
- Alert card and sound near a rare, rare elite or boss spawn; `/pq rare` sets it up.
- The rare alert card can be dragged; `/pq rare reset` moves it back.
- Vendors selling quest items on the map and minimap; `/pq map vendors off` hides them.
- Quest log: each quest's level before its name.
- French, Russian and Simplified Chinese translations of the interface.
- Language flags in the settings window; with pandaUI the language follows pandaUI.
- Different colours for map points from different quests.
- Patrol paths for quest-giver NPCs.
- Treasures, mining nodes, rares and other nodes on the map.
- Accepted quests are tracked automatically in the tracker window.
- Icons in the NPC finder instead of coloured squares.
- Option to choose the size of map quest markers.
- `/pq minimap span` and `/pq minimap indoors on|off`.

### Changed

- Completed quests show the complete icon and sink below unfinished ones in the tracker.
- A completed quest takes one green line in the tracker.
- Items you use on a target are no longer shown as farming objectives, e.g. Frostmaw.
- "Current zone only" keeps subzone quests and quests whose objectives are in your zone.
- Folding quests until progress is on by default and keeps their titles visible.
- Hovering minimap quest dots, markers and vendors shows their tooltip.
- Finished creature objectives remove their own dots while the quest is in progress.
- Rare, elite, boss, giver and turn-in markers ease into their hover size.
- Rare/Elite/Boss shows every ranked creature once per zone, with silver, gold or red stars.
- Hovering a rare, elite or boss pin grows it 1.5x.
- Elites near dungeon entrances are hidden; rares and bosses still show.
- 75 dungeon-approach Rare/Elite/Boss records hidden across 16 outdoor zones.
- City guards, faction leaders and Darkmoon Faire staff no longer show as elites.
- Proximity alerts are off in the six capital cities.
- The alert says "A rare creature is nearby" and its distance counts down live.
- Quest markers and dots follow the map you have open, not your zone.
- The "?" map marker turns orange when a quest is complete.
- Smaller map quest markers.
- Hovering a quest on the map dims other markers and enlarges its linked marker.
- Map dots are no longer limited in number.
- Quests from the other faction's NPCs are hidden on the map.
- Long quest names are cut without leaving blank space.
- French is written without accents; the client font cannot draw them.
- Better world-map frame rate with many quest points.
- Better filtering against duplicated quests on the map.
- Minimap markers are hidden indoors, where the map scale is unknown.

### Fixed

- "Current zone only" showing the whole log where you had no quests.
- The tracker emptying itself indoors.
- Two tooltips when hovering a quest creature.
- Right-click not unfolding automatically folded quests.
- Tracker text drawing over unit frames or the minimap.
- Quest-log tracking marks jumping after Shift-click.
- A Lua error in the client's QuestLogFrame.lua for unreadable objectives.
- The map and minimap empty in Westfall.
- The map empty while standing in a building such as Brill Town Hall.
- Accepted quests sometimes not disappearing from the map.
- Tracker windows limited to 5 quests.

### Removed

- Arrow scrolling from the tracker windows.

## 0.0.2

### Added

- Russian and Chinese client support.
- Spanish client support.
- A custom quest tracker, no longer limited to 5 watched quests.
- A settings window, standalone and pandaUI-compatible.
- Option to show quest objectives as an area or a point.
- A tooltip listing every marker when two or more overlap on the map, with a setting.
- An experimental pfQuest import for completed quests.
- An NPC tracker, including trainers.
- Trainers and patrol routes from vMangos.

### Changed

- About 80% fewer ambiguously flagged quests.

### Fixed

- Quests not always appearing when opening the map.

## 0.0.1

### Added

- First version; PandaQuest now supports OctoWoW only.
- A movable quest tracker window with every quest, its objectives and progress.
- A maximum height for the tracker window; a short log shrinks it.
- A tracker background opacity slider.
- Show and Track/Untrack buttons above the quest log description.
- Quest tracking kept across reloads.
- World-map objective areas, quest-giver markers and turn-in markers.
- Minimap pins for nearby objectives and quest givers.
- A movable selector for service NPCs and objects, filtering class trainers to your class.
- Objective dots on the world map, now the default; `/pq map dots|areas` switches.
- Quest names and progress in creature tooltips.
- Detailed world-map tooltips for quests and quest givers.
- One tooltip for markers too close together, with a setting.
- Quest filtering by level, race, class and season.
- Item-use quest objectives.
- Optional quest-creature marks where the client allows them.
- An options window via `/pq config` or a minimap button; inside pandaUI's settings when installed.
- pfQuest completed-quest import; `/pq pfquest undo` takes it back.
- `/pq` commands for controls and diagnostics.

### Changed

- The pfQuest import works when pfQuest is disabled, enabling it for one reload.
- Quest completion is stored per character instead of per account.

### Fixed

- The tracker not scrolling to its last lines when limited by height.
- The client's quest watch panel reappearing on track or untrack.
- Quests losing their pins when titles had a level prefix ("[24] Weapons of Choice").
- The quest completion record stopping after 250 entries.
