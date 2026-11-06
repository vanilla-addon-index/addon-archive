# Changelog

Player-visible PandaUI changes, newest first. Keep every bullet short, clear and focused on what changes for the player.

## [Unreleased]

## [0.13.4] - 2026-11-03

### Added

- Shift-click a recipe in the Professions window to link it and its reagents in chat.
- Hold Alt while dragging in edit mode to move an element without snapping.

### Changed

- Edit mode snapping is gentler on thin elements, aligns only to nearby elements, and the magnet leaves 1 px between what joined elements draw.

### Fixed

- Friendly and enemy nameplates can be shown together, and V, Shift-V and Ctrl-V choices are kept after loading screens.
- Nameplates no longer flash the default Blizzard plate, or a yellow health bar on hostile mobs, when a mob comes into range.
- The edit-mode magnet no longer makes elements overlap, such as the XP and reputation bars.
- Custom bag categories are kept after a reload.
- Moving items into the bank no longer shows an "Invalid inventory slot" error.
- In edit mode, the health and power text size of the player, target, pet and party frames is now set separately.
- Blizzard's "Show Action Bar" interface options now turn the matching PandaUI action bars on and off.

## [0.13.3] - 2026-11-03

### Added

- Nameplate aura icons can use any plate corner with an adjustable gap.
- Action buttons now have two press effects: Punch and glow, or Zoom and fade (Action Bars > General).
- Action buttons show Retail-style casting sweeps, cast-complete bursts and interrupt effects (toggle in Action Bars > General).
- Bag and bank items on cooldown show a white countdown timer.

### Changed

- Classic WoW and Modern WoW tooltips now use ThinBorder frames.
- With Nampower, nameplates use exact server health and target frames use exact server health/power.
- Modern WoW target-of-target names use 8-point text aligned higher in their health bar.

### Fixed

- Long spell tooltips in the spellbook wrap instead of running off the screen.
- Classic and Modern WoW tooltip borders now enclose bag item details and no longer show background outside the border.
- Nameplates stay below the minimap.
- Classic WoW sell prices no longer overlap item tooltip text.
- Buyback items show their tooltip on hover and can be bought back again.

## [0.13.2] - 2026-10-30

### Added

- Turtle WoW Jewelcrafting and Survival appear in Professions and crafting tabs.
- Modern WoW edit mode lets the Minimap anchor switch between circle and square.
- Right-click the grouped minimap icon for Modern WoW controls, hover and outside-click closing.
- The bag header has a settings button that opens the bag settings page.
- Custom category settings show a "?" beside Priority, Match and Rules that explains how to use them.
- Browse the bags and bank of your other characters on this account.

### Changed

- The grouped minimap icon flyout now uses the right-click menu border.
- Modern inspection uses working flat tabs and contained Arena and Talent panels.
- Modern WoW inspection aligns its title and tabs with a character-only model scene.

### Fixed

- Enchanting and Beast Training cast bars no longer hide behind their crafting window.
- Player inspection keeps its gear tab available after viewing talents.
- Crafting profession portraits now display clean circular icons.
- Raid group borders now fit the complete group frame, including its title row.
- Custom category dropdowns now show their entries and the selected name.
- Custom category priority now works as expected: the highest number wins.
- The Modern WoW Professions page fits its background with Turtle WoW's Survival.
- Modern WoW secondary professions show the rank beside the name, and skill values are centred on their bars.
- The Modern WoW crafting window's Difficulty filter text sits 3 higher.

### Removed

- Opening the World Map no longer shows the misplaced player ping.

## [0.13.1] - 2026-10-29

### Added

- Crafting windows add right-edge tabs for learned professions, including First Aid.

### Changed

- Classic WoW and Modern WoW unit menus use Retail-style 80% backgrounds.

### Removed

- PandaUI leaves minimap and world-map ping placement native.

### Fixed

- Live HUD anchor checks no longer trigger native client crashes.
- Fullscreen world-map zoom waits for native marker placement before drawing.
- Trainer styling avoids opening, closing, updating and collapse-control crash paths.
- Trainer lifecycle probing completed cleanly through opening, updating and closing.
- Raid right-click menus now include Whisper; test members open its chat input.
- Profession actions no longer show the Spellbook's hover or action-bar glows.

## [0.13.0] - 2026-10-28

### Added

- Modern WoW square minimaps place right-aligned zoom buttons below the map.
- Chat settings add Shagu-inspired scrolling, links, class colors, filters, timestamps, centering and outlines.
- Guarded five-stack merchant bulk buying is available.
- The saved bank opened from the bag now follows the bag's category view.
- Bag settings add a Bagshui-style custom category editor with rules, priorities and item lists.
- Nameplates add an optional Tank Mode coloring hostile mobs by aggro, no aggro or crowd control (needs Nampower).

### Fixed

- Unticking Bags > Enable now also restores the default bank window, so other bag addons can use it.
- Modern WoW Social tabs now have improved header, control, button, scrollbar and divider alignment.
- Guild and Who lists now use each player's correct class color.
- Party frames now hide automatically while the player is in a raid.
- Talking to class, profession or talent trainers no longer crashes the game.
- Arrow-key nudges, Scale changes and snapping no longer jump an Edit Mode element back to an old position.
- Modern WoW party-frame player names always stay on one line.

## [0.12.2] - 2026-10-27

### Added

- Turtle WoW custom items now show their bundled vendor sell prices.
- Advanced Character Stats now matches BetterCharacterStats item, talent, aura, set and oil calculations.
- Full Character Stats are now available in Classic, Modern and Modern WoW themes.
- Items that begin quests now show a small yellow exclamation mark.
- Bag and bank windows now have separate scale settings.
- Bag and bank windows resize by dragging their bottom-right corner; the grip shows on hover.
- With Nampower, every nameplate shows debuffs and casts, your debuffs get exact timers, and settings describe both features.

### Removed

- The Modern minimap no longer shows its plus and minus zoom icons.

### Changed

- The Modern theme now uses a flat square minimap; Classic WoW and Modern WoW keep the round one.
- The custom Turtle WoW items are now properly categorized.
- Bags settings descriptions are much shorter.
- Class-icon portraits now also apply to the target-of-target frame.
- pandaUI settings pages show the pandaUI logo; client settings pages keep the settings panda.

### Fixed

- The Modern theme Quest Log now shows its window background.
- Target cast bars now recognize more NPC spells and recover casts started before targeting.
- Target cast bars automatically use Nampower when detected; its status shows in Unit Frames and Nameplates settings.
- The bag-bar setting now aligns with the Bags page's left edge.
- PandaQuest and PandaMap pages in Game Settings now use the game's settings text size.
- The Modern WoW Quest Log parchment no longer shows tile seams.
- Quest Log money no longer draws twice when PandaQuest is enabled.
- Ticking Raid-style frames for the party no longer causes a Lua error.
- The Modern WoW crafting window now fits its art, recipe list, labels and controls correctly, without stray lines.
- HUD elements move back inside the screen when you raise the UI scale.
- The settings window keeps its size when you change the UI scale while it is open.
- On the Classic WoW theme, the unit frame Scale (%) slider now scales the whole frame.
- On the Classic WoW theme, action bar icons now match their slot size.
- On the Modern theme, the action bar "Slot border" option is now correctly named "Slot background".

## [0.12.1] - 2026-10-26

### Added

- New option to show or hide the target-of-target frame, in the Unit Frames settings and its edit mode panel.
- Font size of the health and power bar text on unit frames can be chosen, in the Unit Frames settings and the edit mode panels.
- Health and power text on unit frames can be limited to when the cursor is over the frame.
- Power text can be set per side (default, hidden, percentage or value), in the Unit Frames settings and the unit frame edit mode panels.
- The pet frame has its own 2D/3D portrait option, in the Unit Frames settings and its edit mode panel.
- Classic-wow and modern-wow action bars have a "Slot background" option showing the Bar 1 slot plate, in ActionBars settings and edit mode.
- Classic-wow and modern-wow party frames can look like raid frames, in one column with a 30% taller power bar, in Party Frames settings and edit mode.
- Party frames have one icon size option in percent for buffs, debuffs and HoTs, raid-style included, on top of the mover scale.

### Changed

- The raid frame icon size option now sizes debuffs and dispel icons as well as HoTs.
- The action bar "Hide Slot Background" option is now "Slot border" (ticked shows the border); the edit mode bar panel drops its keybind hint.
- Addon settings categories can now provide their own mascot watermark.
- The settings pages show a new panda in the bottom-right corner.
- The modern-wow target nameplate cast bar now uses the Retail look, with spark and icon inside.
- The modern-wow pet frame text is now smaller and stays inside its bars.
- Closing an anchor's settings panel in edit mode keeps the anchor selected; click it to reopen the panel.
- The Tracked Bars edit mode "Size" slider is now "Scale (%)", like the other anchors; your size is kept.

### Fixed

- Paladins get their aura bar back, as a movable stance bar in every theme.
- Addon names and versions in the Game Settings category list now line up vertically with their icons.
- The player mana and energy tick now runs to the end of the bar at any frame scale.
- Opening Sound or Interface in Game Settings no longer shows an OptionsFrame.lua:496 error on some client versions.
- The durability readout and the damaged-armour figure now update as soon as gear is damaged.

## [0.12.0] - 2026-10-26

### Added

- Edit mode now has a Scale (%) slider for unit frames, raid, minimap, trackers and more.
- Unit frames can independently show health percentage, value or nothing on each bar side from Game Settings and Edit Mode.
- General settings now has a Font dropdown to choose the typeface of PandaUI text, with each font name shown in its own font.
- The status and online-count overlays can be switched off in Edit Mode or on a new Status overlay settings page, which also picks each status readout.
- A new Minimap settings page can group the chosen minimap icons, including other addons' buttons, behind one gear launcher icon.
- In edit mode, anchors snap to the screen centre and to other anchors' edges and centres, with a red guide line when aligned, even with Magnet off.

### Changed

- The micro bar's Size (%) slider is now named Scale (%).
- The modern-wow minimap zone name background is now one text line tall.
- Edit mode windows and their confirmation popups now use the metal frame, red close button and game settings controls in every theme.
- The modern-wow player frame name and level sit slightly higher.
- Game Settings search now finds every Video, Sound and Interface option, key binding and Panda addon option, listing only the pages with a match.

### Fixed

- Fixed the short freeze about once a minute that happened with PandaUI enabled.
- Unit frames now draw above the action bars where they overlap.
- In edit mode, cast bar anchors no longer cover the edit and anchor settings panels.
- The settings window keeps its size at any UI scale, and Panda UI pages now use the game's own settings text size.
- All sliders, including Game Settings and the colour picker, now follow the mouse as soon as you press them.
- Video, Sound and Interface settings keep the same row order and alignment when you switch pages.

## [0.11.2] - 2026-10-25

### Added

- The Pet tab now shows a clear level, loyalty, happiness and training-points summary, with a mood and diet tooltip on the happiness icon.
- Drag the pet model to rotate it, like the character model.
- Player and target frames can show class icons instead of portraits for player characters, in Blizzard or four flat styles.

### Changed

- Modern minimap zone names are smaller and fit the full width of their panel.
- Talent Advisor builds now match OctoWoW's custom talent trees.
- The Modern WoW Pet tab now groups its attributes in framed columns.
- With pandaMap installed, pandaMap now provides the world map zoom.
- Modern WoW Spellbook spell names are now white.
- Spellbook spell names now have a soft bottom-right text shadow.

### Fixed

- Modern WoW NPC windows: the NPC portrait now always sits behind the gold ring.
- Modern WoW merchant: the repair and buyback tray no longer disappears behind the footer background, and "Repair Items" is centred on the repair buttons.
- The pet experience bar now fits cleanly inside its frame.
- XP tooltip values no longer wrap onto extra lines.
- Party-frame Edit Mode handles now cover the full group at custom scale.
- Druids now get a movable form bar (Bear, Cat, Travel and more) in themes that replace the main bar.

## [0.11.1] - 2026-10-22

### Added

- A round Panda settings button now sits on the minimap rim.
- The Panda logo now appears in the settings title and watermark.

### Changed

- Every minimap icon can now be dragged around the rim.
- `/pui reset` now restores every minimap icon.

### Fixed

- Character profiles now support apostrophes and accented names.
- Existing settings carry over when a corrected character profile is created.
- Profile names may now contain apostrophes.

## [0.11.0] - 2026-10-21

### Added

- First OctoWoW release, ported from UnrealUI 0.10.2.
- Raid frames support 8 groups with healing, HoTs, debuffs and dispel highlights.
- Nameplates include reaction colours, target emphasis, raid marks and class colours.
- The minimap supports mouse-wheel zoom and a Retail-style player arrow.
- Bags recognize junk and custom OctoWoW quest items.

### Changed

- PandaUI settings now live inside OctoWoW's Game Settings window.
- The World Map no longer shows black side bands.
- Modern WoW tabs, scrollbars, buttons and thin bars now draw correctly.

### Fixed

- Game Settings sliders and dropdown layering now work correctly.
- Windowed World Map zoom no longer crashes the client.
- Quest and loot rows no longer overlap their text or artwork.
- Buffs remain where the player placed them.
- PandaQuest arrows and rare alerts keep their direction.
