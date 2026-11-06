# pandaUI tests to do

In-game tests still owed on OctoWoW. Tick an item once it passes. Report a
failure with its number and what you saw (exact error text if any); every
result is recorded in `knowledge.json` (`USER_CONFIRMED_INGAME`).

## Blizzard "Show Action Bar" options (coded 2026-11-03, not yet tested)

Code: `modules/actionbar.lua` (`nativeToggles`).
Knowledge record: `actionbars.blizzard_show_multibar_toggles_hidden`. `/reload` is enough.

- [ ] SB1. After the reload, any Blizzard bar box already ticked now shows its PandaUI bar.
- [ ] SB2. Esc > Interface Options: tick Bottom Left, Bottom Right, Right and Right 2: PandaUI bars 5, 4, 2 and 3 appear at once.
- [ ] SB3. Untick one and press Cancel: the bar is back as before Cancel.
- [ ] SB4. Untick one and press Okay: its bar hides. `/reload`: it stays hidden.
- [ ] SB5. Disable a bar in `/pui` > Action Bars with its Blizzard box still ticked, then `/reload`: it stays off.

## Friendly and enemy nameplates together (coded 2026-11-03, not yet tested)

Code: `modules/nameplates.lua` (`style.ApplyVisibility`, `ScheduleVisibility`, `SyncKeyVisibility`).
Knowledge record: `nameplates.friend_enemy_visibility_keys`. `/reload` is enough.
Stand near friendly and enemy units (a town with guards and a hostile mob nearby, or players of both factions).

- [ ] NV1. Nameplates > General: tick both "Show on hostile units" and "Show on friendly units": both plate types show.
- [ ] NV2. `/reload`, then take a loading screen (hearth or instance): both still show.
- [ ] NV3. Press V: only enemy plates. Press Shift-V: only friendly. Press Ctrl-V: both.
- [ ] NV4. After NV3, take a loading screen: the last key choice is kept, and the settings ticks match it.

## Edit mode magnet (coded 2026-11-03, probe)

Code: `core/mover.lua` (`magnet`, `SnapToMovers`, `U.MoverMagnetTest`), `modules/xpbar.lua` (`SnapPadding`).
Probe `magnet` (`PandaRuntimeProbe/MoverScaleProbe.lua`). Knowledge record: `mover.magnet_snaps_thin_bars_flush`.
Already confirmed by the 20:47 trace: swing bar joined the cast bar 1.00 apart, centres aligned.

- [x] MG1. `/prp magnet` (magnet.v1, 2026-11-03 20:58): Alt, grouping, bar2/bar1 and castbar/player joins passed at exactly 1 unit; xp/rep pair untestable in that layout.
- [x] MG1b. magnet.v2 (2026-11-03 21:05): computed padding equals measured art on every mover; bar2/bar1 joins at 8.98 (6.3 + 1.68 + 1), Alt and grouping pass. xp/rep pair blocked by the layout (bar3 3 units above XP).
- [x] MG2. Confirmed in game 2026-11-03: "done it work well".

## Hunter swing timer (probe, needs a hunter, added 2026-11-03)

Code: `modules/swingbar.lua`. Probe `huntswing` (`PandaRuntimeProbe/HuntSwingProbe.lua`).
Knowledge record: `combat.swingbar_hunter_lanes_jump_unverified`.
Relaunch the client once (new probe file). Hunter with a bow or gun, a pet, a melee weapon, Auto Shot on a bar.

- [x] HS1. `/prp huntswing`, then Auto Shot a mob (or dummy) for about 30 s.
- [x] HS2. During that, use instant shots (Arcane Shot, Serpent Sting, Hunter's Mark) and send the pet in.
- [x] HS3. Then go into melee for about 20 s (Raptor Strike, melee attack).
- [x] HS4. `/prp huntswing stop`, then `/prp reload`. Note what the swing bar looked like.
  Done 2026-11-03 at level 1 (no pet, no instant shots): no jumping, bars followed every shot and swing.
- [ ] HS5. Repeat HS1-HS4 at level 6+ weaving Arcane Shot and Serpent Sting during Auto Shot.
- [ ] HS6. Repeat at level 10+ with the pet attacking.

## Action button press and Retail cast animations (coded 2026-11-01, not yet tested)

Code: `modules/actionbarpress.lua`, `modules/actionbar.lua` (`OnButtonClick`),
art `media/Textures/modern-wow/actionbar/fx-*.tga`. Knowledge records:
`actionbars.press_zoomfade_animation`, `actionbars.retail_cast_fx`.
Relaunch the client once (new textures).

- [ ] PA1. Style Modern: an instant spell dips the icon and springs back, with a ring round the slot edge.
- [ ] PA2. Style pfUI Zoom & Fade: icon copy grows to 2x and fades, as before.
- [ ] PA3. Cast-time spell (e.g. Healing Wave): orange sweep fills the button for the cast, then a gold ring burst.
- [ ] PA4. Channel (e.g. fishing): green sweep from the right, then a burst.
- [ ] PA5. Move during a cast: red frame with a sweep down, fading after about 1 s.
- [ ] PA6. Pushback (get hit while casting): the sweep slows to match the cast bar.
- [ ] PA7. Each theme (Modern, Modern WoW, Classic WoW stock bar 1, bars 2-5): effects centred, ring colour right.
- [ ] PA8. Both toggles and the style dropdown off/on take effect immediately; no Lua errors.

## Fullscreen world-map ping with zoom (broken 2026-10-29)

Code: `modules/worldmapzoom.lua`, `modules/playerarrow.lua`. Knowledge records:
`map.worldmap_open_ping_detached_from_player_arrow` and
`map.worldmap_zoom_scaled_content_viewport`.

Opening the fullscreen world map with PandaUI zoom enabled draws the
player-position ping away from `PandaUIPlayerArrowWorldMap`. Disabling only the
zoom restores correct alignment, so the zoom coordinate handling must be
redesigned without removing wheel zoom, panning or the custom player cursor.
Windowed-map and minimap ping placement must remain unchanged.

- [ ] WM1. Open the fullscreen world map: the ping appears exactly on the custom player cursor immediately.
- [ ] WM2. Zoom in and out at several cursor positions: ping and player cursor remain aligned.
- [ ] WM3. Pan at zoom levels 1.5–4: ping and player cursor move together without drift.
- [ ] WM4. Minimize and maximize the map: alignment remains correct and the client does not crash.
- [ ] WM5. Confirm windowed-map zoom, minimap pings and native map clicks remain unchanged.

## Nameplate Tank Mode (coded 2026-10-28, not yet tested)

Code: `modules/nameplates.lua` (`style.TankKey`), `modules/nameplatesettings.lua`.
Knowledge record: `nameplates.tank_mode_guid_target_flags`. Probe:
`/prp platetank` (in `PlatePlaceProbe.lua`, `/reload` is enough).

Probes 2026-10-28 (modern-wow): green on you, red on a party member, idle mobs ordinary and nonp passed. Still owed: blue (TM4), pet victim (TM3), TM5-TM7, TM9, TM10.

- [x] TM1. `/reload`. `/pui` > Nameplates > Tank Mode: page shows Nampower status, Enable, Aggro, No Aggro, Inactive Enemies, Inactive. Tick Enable.
- [x] TM2. Near a pack, out of combat: plates keep muted red (hostile) and yellow (neutral).
- [ ] TM3. `/prp platetank`. Pull 3+ mobs. Mob on you: green. Mob on your pet or a party member: red. Taunt/pull it back: green within a moment.
- [ ] TM4. Tick Inactive Enemies. Stun, sheep, sap, fear or blind one mob: blue. Root, snare, silence or disarm alone: stays green/red. Untick: back to green/red at once.
- [ ] TM5. Kill a mob: its plate loses green/red/blue. Neutral mob: yellow until attacked.
- [ ] TM6. Players, pets, totems and mobs another player tagged keep their usual colours.
- [ ] TM7. Change each colour picker: visible plates follow at once. `/reload`: settings kept.
- [x] TM8. `/prp platetank stop`, then `/prp platetank nonp` in a pull, wait 12 s, then `/prp reload`.
- [ ] TM9. Repeat TM3 once in each theme: classic-wow, modern, modern-wow.
- [ ] TM10. Untick Enable: every plate returns to its usual colour.

## Game Settings search (coded 2026-10-25, passed in game 2026-10-25)

Code: `modules/gamesettingslist.lua`, `modules/settings.lua`. Knowledge
record: `settings.gamesettings_search_only_open_native_leaf`.

- [x] G1. `/reload`. Esc > Options (opens on Video). Type `chat` in the search: Interface lists only its Chat sub-row, and it opens.
- [x] G2. Clear the search, open Video > Display, then type an option from another leaf (e.g. `combat text`): only matching sub-rows show, the first opens with that option.
- [x] G3. Type a Panda UI option label (e.g. `font`): Panda UI lists only pages holding it; click each, it opens. Note any hitch on the first letter typed.
- [x] G4. Type a pandaQuest and a pandaMap option label: their category lists only the matching page. Disable one addon, relaunch: its category never appears.
- [x] G5. Type `move forward`: Key Bindings is listed and its list shows that binding.
- [x] G6. `/pui` (opens on Panda UI), type a Video option: does it show? Then click Video once and retype: it must show.
- [x] G7. Clear the search: every category and sub-row returns, nothing stray drawn on any page, the game menu did not pop up.
