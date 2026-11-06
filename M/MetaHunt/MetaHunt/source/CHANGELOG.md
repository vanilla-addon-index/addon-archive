# Changelog

All notable changes to MetaHunt will be documented in this file.


## [2.1.0] - 2026-10-08

### Added

- **Beast Lore — ability colouring**: In the Hunter's Book Beast Lore list, every beast's abilities are now coloured — **green** if your hunter already knows that exact rank, **red** if it's still unlearned — so you can spot at a glance which beasts can still teach you something new.

- **zTrap — trap cooldown**: The zTrap buttons now show the trap re-arm cooldown (the ~15s before you can lay another trap) as a cooldown spiral plus a seconds countdown, on both the parent and child buttons. A new "Show cooldown" toggle lives in Options → zButtons → zTrap (on by default).

- **zAmmo — total ammo meter**: The zAmmo parent button can now show how stocked you are on your equipped weapon's ammo, as a percentage of your quiver/pouch capacity (all matching arrows or bullets across your bags ÷ total quiver/pouch slots × 200). Two heat-coloured display styles (red when low → green when full) are available as toggles in Options → zButtons → zAmmo → Parent Button: a **centered %** on the button, and a **vertical gauge** beside it (which flips to the side opposite the children's expand direction). A third toggle, **"Counter shows total ammo"**, switches the parent's bottom counter from the equipped stack to your full bag total.

- **zAmmo — low-ammo flash**: The zAmmo parent pulses a red glow when your total ammo drops below your SmartAmmo warning threshold (default 200). Toggle in the Parent Button box (on by default).

- **zAmmo — ammo usage tracker**: Left-click the zAmmo parent to reset a usage counter, then hover it for a report of how much ammo you've burned since the reset — total, elapsed time, average per minute, and a per-type breakdown (how many Rough, Jagged, etc.) with percentages. Counts only ammo actually spent (restocking never corrupts it) and survives `/reload`. The parent tooltip now shows this report instead of the raw item tooltip, with a separate "Show parent tooltip" toggle; the Children "Show Tooltip" option now only affects the child buttons.

- **zPet — unhappy pet flash**: The zPet parent pulses a red glow while your pet is Unhappy, as a persistent "feed me" reminder (complements the existing flash-on-change). Toggle in the Parent Button box (on by default).

### Changed

- **zAmmo — capacity-based counter colouring**: The heat colour on the ammo stack counters now scales to your real quiver/pouch capacity instead of a fixed number, so a stack turns green as it approaches filling your quiver (falls back to the old scale when no quiver/pouch is equipped).

- **SmartAmmo — clearer out-of-ammo alert**: The centre-screen auto-fallback message now names the ammo that ran out (e.g. "Out of Rough Arrow!") instead of a generic "Out of ammo!", so you instantly know which stack emptied.

### Fixed

- **MM Widget — immune schools now show SKIP**: When the current target is immune to the active Explosive Ammunition school, the widget already skipped the special shot (casting Aimed/Steady instead), but the action cell still read "USE" — indistinguishable from a normal shot. It now shows a red **SKIP** with the skipped shot's icon so the skip is visible.

- **Feed-O-Matic — feeding food that's too low level**: With nearly-full bags, FeedOMatic could keep trying to feed a small stack whose level was too low for your pet, which the server refuses ("That food's level is not high enough"). It now skips below-minimum-level foods and only offers food the pet can actually eat.

- **Pets — taming & feeding history disappearing**: Fixed a long-standing issue where a pet's taming info and feeding history could vanish from the Book — caused by the server handing out non-unique pet GUIDs that split one pet into several empty duplicate records. The Stable scan now re-adopts the real record instead of an empty duplicate, so the data reappears on your next stable visit (no data rewrite needed).

- **Pet notifications on login**: Your pet's existing level and loyalty no longer trigger celebration pop-ups right after you log in or reload — a short grace period means only genuine in-session gains are announced.


## [2.0.0] - 2026-09-14

Resurrecting on Octowow.

### Added

- **SmartAmmo — low-ammo alerts**: SmartAmmo can now monitor the total matching arrows or bullets in your bags and equipped slot: Enable the option, choose a warning threshold (default: 200), and MetaHunt will ouput a chat and centered-screen alert when you cross it. Sarcasms are always enabled ofc.

- **New spell datastore**: Metahunt now ships a datastore of all twow 1.18.1 hunter and pet spells. You can browse them with new pages in the Book.

- **Trainer cost planning**: Added shared Hunter and Pet Trainer spell cost planning for spells available now, at the next training level, and still remaining.

- **Hunter and Pet spell scanning**: MetaHunt now reads your Hunter and Pet spellbooks to mark every spell rank you already know. When you visit a Hunter or Pet Trainer, it also records which ranks you can learn now and which ones are still unavailable.

- **Level-up tracking**: Added Hunter, Pet, and Pet Loyalty level-up notifications. When you hit level, you can have a summary in the chat of all new spells available and their costs.

- **Pet Auto-Teach — Growl**: When you tame a new beast, MetaHunt now offers to teach it Growl at the best rank for the pet's level. Click **Yes** and it opens the Beast Training window, teaches the ability and closes the window automatically.

- **Animations**: MetaHunt now plays optional animations that add fun and make the interface feel alive. Powered by the great PizzaSauce library of [Pizzahawaii](https://codeberg.org/Pizzahawaii/) ! Thank you man.

- **zTrack — Find Fish**: Added new spell Find Fish to zTrack.

- **DDOSers Realm Blocking**: The Addon will auto-disable itself on all Mafia's realms, we know who they are.

### Changed

- **Complete revamp of SavedVariables**: All your settings now live in one tidy place instead of being scattered around. A migration happens the first time you log in, and you shouldn't lose any settings.

- **Polished options**: The option panel had become messy over time and it finally received some attention to look cleaner and coherent with same styling everywhere and better arrangement.

- **Book navigation**: The book navigation is no longer done with horizontal tabs, but with a left vertical menu just like in the options. This allow more pages and fix the  tab overfloading issues on some resolutions and UI scales.

- **Web database links**: All links in the data that were pointing on old Turtle WoW DB have been replaced to point on the OctoWoW DB.

- **Addon's code repository change**: The addon repo is now hosted on Codeberg and the "update available" link will point on the new location.


### Fixed

- **NPC Finder — zone accuracy**: Fixed NPCs that could show a wrong zone (e.g. Feathermoon vendors in Feralas were labelled "Duskwood") caused by a zone-ID mix-up. NPCs that stand on a zone border or in a capital city now list **all** the zones they appear on, most precise first — e.g. "Darnassus, Teldrassil" or "Alterac, Hilsbrad".

- **zCraft — profession ranks**: zCraft now refreshes after learning a profession rank, without requiring a UI reload.

- **Tooltips — your pet's info showing on other players**: In a party, mousing over or targeting another player could wrongly show YOUR pet's details (mood, loyalty, happiness, XP) on their tooltip. The own-pet detection no longer misfires on other units.

- **zCraft — Smelting**: Smelting was previously not appearing in zCraft because incorrectly hardcoded as "Mining", this is fixed. 

- **Wrong icons on pet spells**: Fixed the Rank 0 of Bubble Barrier and Charge that had incorrect icons. 

- **Fixed tracking data in Book's Stables**: Fixed an issue with pets' GUID returned by the server, that was not really unique and caused issues with pets' tracking, notably when you had several pets with the same name. Taming info was disapearing, amongst other weirdness. A migration is done on first load to fix your existing data.

- **FeedOMatic — "Set Key" button error**: Clicking **Set Key** in Options → Feed-o-Matic threw an error and wouldn't let you bind a feed key. It now works again.

- **FeedOMatic — pet left hungry when bags were full**: When your bags were full, FeedOMatic could grab a random tiny stack (like a single meat your pet won't eat) to free a bag slot, so your pet stayed hungry. It now always picks food your pet can actually eat.

- **Tooltips — "Not learned yet" hint missing on pet abilities**: When you tamed a new beast, hovering one of its abilities on your pet bar no longer showed the red "Not learned yet, keep going !" reminder, even for abilities you hadn't learned. The hint is back and now correctly shows for any ability rank your hunter hasn't learned yet.

- **Pet training — new rank of a known ability not registered**: When you trained a higher rank of an ability you already had (e.g. learning Charge Rank 2 after Rank 1), MetaHunt treated it as already known — so the "Pet ability learned and recorded" message never appeared and the pet-bar tooltip kept saying "Not learned yet" for the new rank. Learning a new rank is now recognised on its own, announces correctly, and the tooltip immediately reflects the rank you just learned.

- **Hunter's Book — fixed "Unique" beasts**: Restored a curated list of the one-of-a-kind beasts (Humar the Pridelord, Darksaber, Shar'lan, Frostsaber Pride Watcher, Mazzranache, Moonfeather, Azurebeak, Old Cliff Jumper, Rotting Agam'ar, Razzashi Serpent, Magmalash Scorpid, Spirit Fox and more).



## [1.5.1] - 2026-04-01


### Added

- **zAmmo — bag ammo labels**: Quality-colored short-name labels overlaid on ammo items in bags and bank, with optional heat-colored DPS damage indicator. Three new checkboxes General options: bag labels, bank labels, and damage display. Works with both default bags and pfUI bags.

- **MM Widget — immunity detection**: The MM Widget keybind now detects when the current target is immune to a damage school (Fire / Nature / Arcane) and automatically skips the useless shot, casting Aimed or Steady Shot instead. Immunity is detected in two ways: reactively via combat log "immune" messages, and proactively via hardcoded creature-type rules (e.g. Elementals are always flagged Nature-immune on target). Immune cells show a red border. 

- **MM Widget — rotation toggles**: Three new checkboxes in Options → ExpAmmo → Rotation let you permanently disable individual shots (Multi-Shot, Serpent Sting, Arcane Shot) — unchecked shots are skipped during their proc window.


### Fixed

- **Zone mapping — 22 beasts with raw zone IDs**: Fixed 8 unmapped zone IDs (Blackrock Depths, Molten Core, Wailing Caverns, Maraudon, Sunnyglade, Icepoint Rock, Winter Veil Vale, Gilneas City, Karazhan) that caused 22 beasts to display as "Zone xxx" instead of their proper zone name in the Hunter Book.

- **MM Widget — IsStateBlocked nil error**: Moved `MTH_EA_IsStateBlocked` definition before its first use, fixing a nil function call on load.


## [1.5.0] - 2026-03-31


### Changed

- **Beast spawn coordinates — custom-zone remap**: Reworked 63 beast coordinate sets in the datastore. The largest changes move placeholder vanilla-zone coords onto the proper Turtle WoW custom zones for **Grim Reaches**, **Northwind**, and **Balor**, and clean up prairie beasts that were incorrectly spilling into **Thunder Bluff**.

- **Beast spawn coordinates — Stonetalon recalibration**: Recalibrated several **Stonetalon Mountains** beast spawn clusters to match the Twow updated zone bounds and improve marker placement consistency.

- **MM Widget — ClickThrough **: The whole widget is now clickable through, and ALT-drag to reposition it is thus no longer possible

- **MM Widget — clearer bottom-cell display**: The bottom cell now shows the cooldown of the current shot you would use, and only shows `USE` when that shot is ready.

- **Feed-O-Matic — NO-BUFF quarantine disabled**: The mechanism that permanently blacklisted a food item per pet family after a failed feed (no buff detected within 2.5 s) has been disabled. Foods are no longer quarantined on a no-buff timeout — the feed will simply retry without banning the item. This avoids false positives caused by server lag or client timeouts.


### Added

- **zCraft — new zButton for crafting professions**: A new `zCraft` button (Options → zButtons → zCraft) scans your spellbook and shows a child button for each crafting profession you know — Alchemy, Blacksmithing, Cooking, Disenchanting, Enchanting, Engineering, Fishing, First Aid, Herbalism, Jewelcrafting, Leatherworking, Mining (Smelting), Skinning, Survival, and Tailoring. Clicking a child opens the corresponding tradeskill window. Disabled by default.

- **zBar — unified draggable toolbar for all zButtons**: A new "zBar" tab (Options → zButtons → zBar) groups all enabled zButton bars into a single draggable anchor. Alt-drag the zBar to move the whole group together. Options: Horizontal or Vertical layout; which side children pop out (Up/Down for horizontal, Left/Right for vertical); spacing between buttons; anchor icon size; per-bar include/exclude toggle and drag-to-reorder. Disabled by default — existing layouts are untouched until you enable it.

- **zAspect / zTrack — Smart Parent**: A new "Smart Parent" checkbox in Options → zButtons → zAspect and zTrack. When enabled, the parent button automatically toggles between your 1st and 2nd spell: if the 1st is active, the parent shows the 2nd, and vice-versa. Perfect for PvP — put Track Hidden and Track Humanoids as your first two tracking spells, and the parent always shows the one you're *not* currently using. When disabled, the parent always shows the 1st spell. Enabled by default.

- **zPet — Smart Parent**: A new "Smart Parent" checkbox in Options → zButtons → zPet. When enabled, the parent button dynamically changes based on your pet's state: Revive Pet if dead, Mend Pet if hurt, Feed Pet if unhappy, or your default spell otherwise. When disabled, the parent always shows the 1st spell. Enabled by default.

- **zMounts / zCompanions — Random Parent**: A new "Random Parent" checkbox in Options → zButtons → zMounts and zCompanions. When enabled, a random child mount is picked as the parent icon on each login and after each use. Disabled by default.

- **zMounts — AQ Mount Filter**: A new "AQ Mount Filter" checkbox in Options → zButtons → zMounts. When enabled, Qiraji mounts are hidden outside AQ40, and only Qiraji mounts are shown inside AQ40. Enabled by default.

- **zAspect — NamPower support**: The Aspect button now listens to `NamPower` aura events when available, so aspect changes update faster and without the old polling delay.

- **MM Widget — NamPower support**: The widget now uses `NamPower` aura updates when available, which makes ammo proc tracking faster and more reliable. It still falls back to the old tracking method if NamPower is not installed.

- **MM Widget — keybind **: The MM Widget options panel now has a "Set Key" button. Press any key (with optional ALT/CTRL/SHIFT modifiers), or mouse button/wheel to bind the MM Widget action, turning it into a One-button rotation feature.

- **MM Widget — Quiver no-clip option**: New "Use Quiver no-clip casting" checkbox in the MM Widget options. When enabled and Quiver is installed, Aimed Shot, Steady Shot, and Multi-Shot of the Action bind are routed through Quiver's no-clip system to avoid clipping your auto-shot swing timer.

- **MM Widget — Anchor **: Since the widget is now clickable-through, a new anchor system was implemented to move the widget: toggling the anchor button in the options shows 4 drag handles (top, bottom, left, right) outside the widget edge. Any handle can be dragged to reposition the widget.

- **Hunter Book — Families stats modifiers**: The Families page now also shows `Health`, `Damage`, and `Armor` modifiers for every family. Those modifier values can be shown as raw multipliers or as `%` with a footer checkbox, and are color-coded for easier reading. Additionaly the footer recap now also shows the total number of families, and the Named/Coord counts are plugged on the new accurate server's data instead of old pfQuest data.

- **FOM — keybind**: The Feed-O-Matic "Set Key" button in options now also accepts modifiers and mouse.

- **/mth food command**: Added a new slash command to inspect Feed-O-Matic state, clear one item ban, or reset all food bans and quarantines.

- **AntiDaze — NamPower support**: Daze detection now uses NamPower's aura events when available, replacing chat-message parsing for faster and more reliable aspect cancellation.

- **Chronometer — NamPower support**: Timer bars now start and stop instantly via NamPower aura events when available. Bar durations are read directly from the NamPower aura array instead of guessed from spell data.

- **Feed-O-Matic — NamPower support**: Mount and buff detection (Shadowmeld, Feign Death, eating, etc.) now uses the NamPower aura array when available, replacing the old tooltip-scraping method.



### Fixed

- **Pet lifecycle — duplicate / ghost pets in Stable**: Reworked pet identity with GUID-based matching and fixed stable tracking so the same pet is no longer split into multiple rows after tame, rename, stable swap, or `/reload`. Old stale pets should also stop reappearing in the Stable tab as fake active/stabled entries.

- **Pet lifecycle — wrong taming info shown on old pets**: Fixed several cases where MetaHunt could invent tame data for pets that were only seen later through stable swaps or normal pet refreshes. Taming info is now only recorded from a real tame event, so old pets should no longer show fake tame location / tame date data.

- **Hunter Book — Stable tab now trusts real stable slots**: The Stable tab now shows the current pet plus the pets that are actually in your stable slots, instead of trusting stale saved slot data from older sessions.

- **Hunter Book — pet training kept on the correct pet**: Fixed cases where a pet could keep its row but lose its Training section after lifecycle repairs or row merges. Training/spellbook data now stays attached to the right pet.

- **Hunter Book — stable feed item icons**: Fixed broken food icons in the Stable tab feed summary, including cases where foods like `Roasted Quail` were showing as a red square or question mark.

- **Minimap markers moving with the player since 1.4.0**: Reworked minimap marker zone resolution and calibration so pins stay anchored to world locations again instead of sliding with player movement. The minimap path now uses exact current-zone lookup in pfQuest space, while the world map keeps the WMA-aware logic introduced for 1.18.1 zone support.

- **Chronometer — "Grow bars upward" forgotten after `/reload`**: Checking the "Grow bars upward" option and reloading the UI would revert the bars back to growing downward, even though the checkbox still appeared checked. Fixed.

- **Chronometer — bars appear below the anchor instead of above when "Grow bars upward" is enabled**: Even with "Grow bars upward" checked, the bars were still spawning a bit below the anchor and stacking upward from there, because of an existing issue in old `CandyBar` library. Fixed — bars now correctly start at the anchor and grow upward.

- **Chronometer — Aimed Shot tracker removed**: Chronometer no longer tracks Aimed Shot cooldowns. The MM Widget now owns that behavior, so Chronometer keeps its hunter timers focused on the remaining spell and proc bars.

- **MM Widget — Quiver no-clip covers Multi-Shot**: The Quiver no-clip option now explicitly includes Multi-Shot alongside Aimed Shot and Steady Shot.

- **MM Widget — stale NamPower proc state**: The widget now resyncs from the NamPower aura array after aura events, so it no longer keeps showing a proc after the debuff is gone.

- **Quiver no-clip macro — Steady Shot castbar not showing**: If you were using Quiver and its no-clip macro for your shots, the Quiver castbar for those shots would not appear with MetaHunt enabled. Fixed — the castbar now appears correctly when using the macro. 


## [1.4.1] - 2026-03-24

### Added

- **zTrack**: added `Find Trees` in tracking spells.

### Changed

- **Performance — MM Widget / ExpAmmo**: Replaced tooltip-based aura scanning (which triggered hidden tooltip rendering on every aura check) with direct texture/icon comparison via `UnitBuff`/`UnitDebuff`. Added a 150 ms throttle on `PLAYER_AURAS_CHANGED`, which fires 10–50+ times per second in combat. Lock and Load detection and ammo cycle recovery after `/reload` both updated to use the new zero-cost texture path.

- **Performance — event frame leaks**: Some addon features were registering WoW game events at load time and never unregistering them when the feature was disabled from the options, causing their `OnEvent` handlers to fire even with the option turned off. Fixed for: Auto-Strip (`PLAYER_REGEN_*`), Smart Ammo (`SPELLCAST_*`, `START/STOP_AUTOREPEAT_SPELL`), and some zButton frames (Pet, Mounts, Track, Trap, Toys). Events are now properly registered on enable and unregistered on disable.

- **Chronometer — trap effects from other hunters**: Trap effect bars (`Immolation Trap Effect`, `Explosive Trap Effect`, `Freezing Trap Effect`, `Frost Trap Aura`) were incorrectly appearing when another hunter's trap triggered on a mob you were also targeting. .

- **Version check broadcast interval**: Increased update notification broadcast cooldown from 10 minutes to 1 hour to reduce channel traffic now that the user base has grown.

- **Profile snapshot memory**: The auto `BuildSnapshot` (called on every `/reload` via `PLAYER_LOGOUT`) was deep-copying `feedomatic.legacy`, a large migration table mirroring `FOM_Cooking`, `FOM_QuestFood`, `FOM_AddedFoods` etc. These are runtime/operational blobs, not user configuration settings, and should never be included in a profile. Introduced `MTH_Profile_CopyModules` which skips `legacy` and `history` keys, reducing the snapshot allocation from ~1 MB to a few KB.



## [1.4.0] - 2026-03-23

### TWoW 1.18.1 "Nightmares of Ursol" support

### Added

- **Complete beast database overhaul**: The MTH beast datastore was reconstructed from scratch, based on a full (beasts) 1.18.1 extract from live DB, gladly provided by Twow staff (thanks @Haaxor!). The beast data should now be 100% accurate, and notably all spawn coordinates, respawn times and pet abilities learnable on all beasts in the world.

- The **Beast Lore** page of the Book now allows to filter the list by Zone. Additionally, the beast inspector has been reformatted and all meaningful beast's data is displayed nicely.

- All new and missing **Beasts Models** have been (re)scanned from MPQ game files and are viewable in the Beast Lore page, and browsable in the Family Model viewer. 

- Added **MM widget** module: tracks the new 3-state of Experimental ammo cycle (Fire → Nature → Arcane), the Lock and Load procs, and has a dynamic cell that shows either Aimed Shot availability or the right shot to use following the current Experimental ammo proc if any. Lets Make MM great again.

- Added new **Moth** pet family.

- Added new **Pollen Burst** pet ability.

- Added new **Aspect of the Viper** in zAspect.

- Added new **Chronometer** timer entries for 1.18.1 spells:
  - Aimed Shot cooldown tracker
  - Kill Command cooldown tracker
  - Lock and Load proc timer
  - Scent of Blood proc timer

- Added new **Chronometer** target debuff entries for the Experimental Ammo states:
  - Poisonous Ammunition: 15s armor-reduction debuff (triggered when Serpent Sting consumes the Poisonous state)
  - Enchanted Ammunition: 6s magic-resist debuff (triggered when Arcane Shot consumes the Enchanted state)

- Added the **5 new craftable ammo** to the Projectiles book's page, SmartAmmo and zAmmo button:
  - **Bright Wood Arrows** (Survival: Journeyman, req. 30) — 10.5 DPS
  - **Shade Wood Arrows** (Survival: Expert, req. 40) — 14.5 DPS
  - **Smooth Ironfeather Arrows** (Survival: Artisan, req. 50) — 17.5 DPS
  - **Starfeather Arrows** (Survival: Artisan, req. 55) — 19 DPS 
  - **Enchanted Thorium Shells** (Engineering: Artisan, req. 55) — 19 DPS 

- Added new hunter-friends NPC of **Moonwhisper Coast** to the NPC Finder Book's page:
  - **Hula Swiftmane** — Horde Stable Master (66.1, 39.1)
  - **Ornala** — Horde Ammo Vendor (67.3, 37.1) — sells Arrows and Slugs
  - **Badel Wildlance** — Alliance Stable Master (59.0, 24.9)
  - **Elendon Truebough** — Alliance Ammo Vendor (58.8, 24.5) — sells Arrows

### Fixed

- Fixed **Chronometer** bars appearing from nearby players' combat events (e.g. another hunter's traps or DoTs triggering your own bars).
- Fixed the list in Families Book's page, that wasn't tall enough to display all families (wolves were hidden).

## [1.3.0] - 2026-03-19


### Added
- Added a **3D Model Viewer** to the Hunter Book Beast Lore inspector panel. Clicking a beast in the list shows its in-game model.
- Added a standalone **3D Model Viewer** that is shown when cliking the model of a beast in the Beast lore. The model is rotatable with the mouse, and you can browse all models of the same pet family and shows all other beasts that share the same skin, with one-click to jump to any of them in the Beast Lore.
- Added a **Family icon** column to the Beast Lore list, replacing the text family name with the pet family icon for a more compact view.
- Added an **Attack Speed (AS)** column to the Beast Lore list.
- Added `displayId` and `skinId` fields to **all ~1000 beasts** in the MetaHunt datastore. `displayId` was scraped from the Turtle WoW DB, and `skinId` derived from it following an extraction on MPQ game files. This is what powers the model viewer and skin-grouping.
- Added per-family icons to all 19 pet families in the family data table.
- Added missing food types (`raw meat`, `raw fish`) to all pet families that accept `meat` or `fish` respectively (sourced from MPQ data). 
- Added **Profile Management** panel (Options → Profiles): save the current addon configuration as a named profile and instantly load it on any character. Profiles cover all module settings (ICU, Chronometer, AutoBuy, AutoQuest, SmartAmmo, Feed-O-Matic, zButtons layout) and per-character module enabled/disabled states.
- Added automatic per-character **config snapshots** saved on every logout (`CharName-RealmName`), visible in the "Copy from Character" section — import any character's snapshot as a loadable profile in one click.


### Fixed
- Fixed the pet feeding counter never incrementing: `MTH_FEED_Trace` was a no-op stub and `FOM_CORE_ATTEMPT_TRACKING_ENABLED` was `false`; both are now active.
- Fixed `FOM_AddFood` not clearing a food from `FOM_RemovedFoods` when the item belongs to the base diet list, which permanently banned it even after an explicit `/fom add`.
- Wired `FOM_ClearItemBans` into the `/fom add` command path: explicitly re-adding a food now clears it from `FOM_RemovedFoods`, FOM quarantine, and core exceptions in one step.
- Removed debug messages forgotten when releasing 1.2. 
- Fixed SmartAmmo + **Quiver castbar conflict**: Quiver's castbar was disappearing when both addons were active. Root cause: MetaHunt SmartAmmo was re-installing its hooks every 0.5 seconds, constantly bumping Quiver off the top of the hook chain. Fixed by removing the repeated re-hook and adding a guard that only installs once (or when no other addon is on top).


## [1.2.0] - 2026-03-10

### Added
- Added keybinding text overlay on zButtons: parent and child buttons now display their bound key for the 5 bindable sets (Aspect, Track, Trap, Ammo, Pet). 
- Added "Expand on Hover" option for zButton children: when enabled, hovering over the parent button automatically expands children (instead of requiring right-click).
- Added "Auto-Hide Timer" option for zButton children: a configurable 0–10 second timer that automatically collapses expanded children after the mouse leaves the button group. Timer resets while hovering any button in the group.

### Fixed 
- Fixed SavedVariables data loss on login caused by initialization race condition overwriting persisted data.
- Fixed SavedVariables bloat by adding a migration that strips redundant default-valued keys on first load.
- Fixed six performance issues including throttling high-frequency event handlers, caching repeated `getglobal` lookups, and reducing unnecessary table allocations in hot paths.
- Cleaned up ICU module global variable leaks by properly scoping locals.
- Standardized all remaining `SetScript` handler patterns to use the WoW 1.12 `this`-based convention consistently.


## [1.1.0] - 2026-03-09

### Added
- Added new `ICU` module with dedicated options panel.
- Added ICU custom popup anchor mode with draggable anchor and direction toggle.
- Added ICU popup hide delay options (`INSTANT`, 1..10 seconds).
- Added new `Auto Quest` module for :
	- `Salt of the Scorpok` (`Bloodmage Drazial`)
	- `Arrows Are For Sissies` (`Artilleryman Sheldonore`)
- Added a Food Feed learning feature to Feed-O-Matic.
- Added Chronometer `Entrapment` effect tracking support.    

### Changed
- Loads of Frame/Handlers/Processes adjustments to optimize addon's CPU time and Memory usage.
- Updated Chronometer Improved Wing Clip effect color to `MAROON` for clearer effect-bar distinction.
- Reworked Stable Master processing to minimize swap-time overhead:
	- No auto-scan on `PET_STABLE_SHOW`.
	- Deferred stable scan moved to `PET_STABLE_CLOSED`.
	- Optional heavy workloads are skipped while stable UI is open.
- Changed Hunter Book page order, and default opening page to `Beast Lore`.
- Optimized `Pet History` result build/sort path using cached precomputed sort keys.
- Modules Auto-Buy, Auto-Quest, ICU, Feed-O-Matic are by default disabled on first use on a character.

### Fixed
- Fixed issues with zBouttons,Autostrp and Chronometer bar anchor not retaining their configured spawn position after the disabling/renabling of the Addon.
- Fixed issues with options checkbox-state not always retaining their state on startup.
- Fixed multiple issues in Feeed-O-Matic with some foods that were accepted by lvl 60 pets in Vanilla and are not anymore on Turtle.
- Fixed Chronometer spell/event disable toggles in options so disabled entries now reliably block bar creation.
- Fixed Chronometer `Feed Pet` bar missing trigger by adding `UNIT_AURA` fallback detection.
- Fixed stable swap stutter/freezes by removing heavy processing from repeated `UNIT_PET` bursts during stable interactions.


## [1.0.6] - 2026-03-05

### Fixed
- Added missing abilities to all pet families.
- Rescraped from Twow DB the previously in correct `Roar of Fortitude` pet-ability.
- Fixed an issue with Tooltip on pet action bar abilities, that were falsely displayed as not learned yet for rankless abilities.
- Restored visible Stable Master auto-scan feedback (`Stable scan complete: X slot(s).`) when opening the stable window.
- Fixed stable scan icon persistence for active pets that were never stabled by capturing current-pet icon data during stable scans.
- Hardened stable-scan bootstrap to initialize on both `PET_STABLE_SHOW` and `PET_STABLE_UPDATE` event paths.
- Fixed issues with taming pet metadata that were not properly recorded since the last update.
- Fixed issues with pet runaway interception that was broken since the last update.
- Updated version-update notification text to include clearer upgrade guidance and plain GitHub URL text for updates.
- Fixed an issue with `zTrack` buttons spells being incorrect after having respec the talents using brainwashing device.


## [1.0.5] - 2026-03-01

### Fixed
- Multiple changes to the addon to reduce its memory and CPU time footprint to the strict minimum possible.
- Restored FeedOMatic pet hunger notifications so hungry/very hungry warnings are emitted reliably again when enabled.
- Fixed Chronometer `Wing Clip` tracking by adding a safe fallback timer path for the missing trigger case.
- Fixed Chronometer `Quick Shots` bar icon by mapping the event to the correct icon texture.
- Fixed module enabled/disabled persistence to be truly per-character (`MTH_CharSavedVariables.moduleStates`) instead of account-shared.
- Fixed AutoBuy persistence fallback by removing undeclared `MTH_AutoBuy_Saved` paths and using module stores/transient runtime fallback only.
- Consolidated FeedOMatic legacy persistence to a single module-backed store (`modules.feedomatic.legacy`) with globals bound to that source.
- Switched Chronometer profile persistence to per-character module storage with one-time migration from existing account profile data.
- Switched Tooltips module options persistence to per-character module storage with one-time migration from existing account settings.

## [1.0.4] - 2026-02-27

### Added
- Added new zButton bar `zRanged` that tracks all ranged weapons in bags and allows to quickly swap them.
- Added structured localization architecture with dedicated locale packs under `locales/` and loader wiring through `init/localization.xml`.
- Added a dedicated `Messages` options panel with per-message toggles.
- Added Smart Ammo option `Enable Weapon-Swap Auto Ammo` to instantly equip best bullets/arrows when switching ranged weapon type.
- Added two new Hunter Book pages in the main tab bar: `Projectiles` and `Ammo Bags`

### Changed
- Reworked core localization runtime to support explicit locale fallback rules (`enUS`, `deDE`, `esES`, `ptBR`, `ruRU`, `zhCN`; no `frFR` target).
- Updated Hunter Book NPC finder and map vendor markers to use localized NPC names by NPC ID.
- Updated Hunter Book, item search/sort, AutoBuy item labels, and drop map markers to use localized item names by item ID.


### Fixed
- Fixed version metadata consistency so all first-party module descriptors report the same release version as the main addon.
- Fixed SmartAmmo junk-shot detection by including `Baited Shot` and `Tranquilizing Shot` in `MTH_AMMO_JUNKSHOT_SET`.
- Fixed zButtons options side effect where opening Mounts/Companions/Toys options could implicitly enable those buttons.
- Normalized zButtons checkbox defaults (`enabled`, `tooltip`, `hideonclick`, `parent.hide`, `parent.circle`, `showammoname`) so toggle states are always explicit and never nil.
- Fixed Beast Lore ability dropdown to exclude trainer-only abilities and list beast-learned abilities only.
- Removed junk `TBD` ability value from Wind Serpent dataset entry (`Venomflayer Serpent`) so it no longer appears in Beast Lore filters.
- Fixed zhunter child-button visibility restore so collapsed bars no longer hard-hide children (`ztrack` / `ztrap` expansion regression).
- Fixed pet tame metadata fallback so existing pets are not assigned current zone/time unless a real tame attempt is pending.
- Fixed Smart Ammo options copy mismatch by clarifying junk-shot swap behavior and restoring ammo target as previous equipped ammo.
- Fixed Smart Ammo default state so junk-shot swaps are enabled when no saved value exists.
- Fixed Beast Training startup prompt behavior so low-level hunters no longer receive training-scan warnings before level threshold.
- Restored hidden `/mth err` slash command behavior for debug-frame access.
- Fixed `zammo` children refresh on bag/inventory updates so newly acquired ammo types appear without `/reload`.
- Preserved `zammo` out-of-stock behavior so previously shown ammo entries still remain visible with zero/out state.
- Fixed intermittent `ztrack`/`ztrap` right-click expand/collapse issue after fresh login by preventing duplicate child-frame recreation during startup.
- Fixed `zpet` spell resolution after trainer updates by using robust spellbook lookup and immediate refresh on `LEARNED_SPELL_IN_TAB`.


## [1.0.3] - 2026-02-24

### Added
- Initial published release.
