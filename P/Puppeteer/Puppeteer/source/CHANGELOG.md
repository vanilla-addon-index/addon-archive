# Changelog

OEVG's fork of [OldManAlpha/Puppeteer](https://github.com/OldManAlpha/Puppeteer). Newest version first.

## 1.2 (2026-11-02)

### Added

- **Optional ClassicAPI support.** Puppeteer uses [ClassicAPI](https://github.com/brues-code/ClassicAPI) when it is installed. Each feature is detected separately, so an older ClassicAPI only loses the parts it lacks. Turn it off with **Use ClassicAPI** in `/pt` → Options → Mods, then reload. The Mods tab also shows whether ClassicAPI was detected, and its version.
  - Buffs and debuffs are read in one pass with their spell IDs, dispel types, timers and casters, with no tooltip scanning. Debuffs that the server moved into buff slots show as debuffs.
  - A refreshed aura updates its timer and stack count in place, without rebuilding the aura icons or the health bar.
  - Aura timers work without SuperWoW.
  - The game draws aura timer sweeps itself.
  - Range, online status, visibility and incoming resurrections update right away. Resurrections are seen from any nearby caster, including players without HealComm.
  - With SuperWoW, heal amounts are learned from the combat log event instead of combat log chat text, so learning works in every client language.
  - Distance and line-of-sight are provided when UnitXP SP3 is not installed. Distance is only provided when SuperWoW is also missing.
- **Tooltip Behavior** option in Options → Other:
  - **Default** keeps the game's mouseover tooltip, which only shows for nearby units.
  - **Always** shows the unit tooltip for every unit, including far away party and raid members.
  - **Never** hides the tooltip while you hover unit frames, so it doesn't cover other frames. The spells tooltip still shows.
- **Test UI shows raid frames while you're solo or in a party** (from [fey](https://github.com/fey/Puppeteer), `fix/testui-raid-frames`). While `/pt testui` is on, every frame group shows (Party, Pets, Raid, Raid Pets) whatever your real group is, and Hide While Solo doesn't hide the test frames. Turning test mode off restores the normal rules.

### Changed

These patterns come from brues-code/pfUI's unit frames.

- **Hidden frames skip event updates.** A frame skips health, power, aura, range, sight, connection and resurrection updates while it, or its group, is hidden, for example the party frames while you're in a raid. The unit cache still updates, and showing the frame or its group redraws it. A UI hidden with Alt+Z still counts as shown. Incoming heals are still always updated.
- **Heal prediction's cleanup check stops when idle.** It used to run every frame. Now it stops when no cast, HoT, resurrection or cast icon is left, and starts again when one is added.
- **ClassicAPI's range event (`UNIT_IN_RANGE_UPDATE`) is only used without UnitXP SP3 and SuperWoW.** ClassicAPI checks every registered unit on every frame. With either of those mods, Puppeteer already polls precise distance.

### Fixed

- **A timed-out resurrection removed every resurrection on its target.** When one caster's resurrection passed its 20-second limit, other casters' resurrections on the same target disappeared too. Now only the expired one is removed. The bug was found in razzeee/Puppeteer's summoning commit.
- **Settings text outside the window.** Long labels in the Other tab ("Pets Use Owner's Class Color", "(1.18.1) LFT Auto Role") and the contributor line on the About tab no longer run outside the window.

### ClassicAPI implementation notes

When ClassicAPI is not installed, or Use ClassicAPI is off, the code takes the same paths as in 1.1.3.

- **Aura scan (`libs/PTUnit.lua`).** `C_UnitAuras.GetAuraSlots` fills one reused slot buffer (its fill-a-table form, checked at load), and `C_UnitAuras.UnitAuraBySlot` returns each aura positionally. The per-slot entry reuse from 1.1.3 is kept, so a scan creates no tables after an entry's first use. Each entry keeps its own reused time table for ClassicAPI's duration, expiration and caster. A start time is never set in the future. SuperWoW/Nampower tracked times are the fallback when ClassicAPI has none. Tooltips use `GameTooltip:SetUnitAura` with the C_UnitAuras index.
- **Aura deltas (`core/EventHandler.lua`).** For visible real unit tokens, `UNIT_AURA_DELTA` replaces `UNIT_AURA`. An event with only updated auras re-reads stacks and timers in place (`PTUnit:RefreshClassicAuras`) and updates the shown icons (`PTUnitFrame:RefreshAuras`). Added or removed auras, or a changed list, take the full path. `UNIT_AURA` still handles SuperWoW GUID arguments and members out of view.
- **Aura timers (`PTUnitFrame.lua`).** Icons use a native `Cooldown` frame (no end flash, no built-in numbers) instead of a `Model` with an `OnUpdateModel` script. One shared driver updates the countdown text of visible timers, and only rewrites the text when the second changes. Second strings 0–60 are cached. The game's own countdown numbers are not used, because they need the game-wide `countdownForCooldowns` setting.
- **Events.**
  - `UNIT_DISTANCE_CHECK_UPDATE` and `UNIT_IN_RANGE_UPDATE` re-read distance and sight for the unit.
  - `UNIT_CONNECTION` updates health, power and range.
  - `INCOMING_RESURRECT_CHANGED` updates the health text, and `UnitHasIncomingResurrection` is added to resurrection checks.
- **Heal learning (`libs/HealPredict.lua`, SuperWoW only).** `COMBAT_LOG_EVENT_UNFILTERED` replaces the four combat-log chat frames for `SPELL_HEAL`, `SPELL_PERIODIC_HEAL` and `SPELL_AURA_REMOVED`. Critical heals are ignored as before. Direct heals are only learned when they match the caster's last cast, by spell ID or name. The switch happens at the first `PLAYER_ENTERING_WORLD`, and only if ClassicAPI's player GUID string equals SuperWoW's.
- **Distance and sight (`libs/Util.lua`).** `UnitDistanceSquared` (center to center) is the distance provider only without UnitXP SP3 and SuperWoW. `UnitInLineOfSight` is the sight provider only without UnitXP SP3.
- **Not used.** ClassicAPI's `collectgarbage` options are no-ops on the Lua 5.0 collector, and ClassicAPI does not shorten GC pauses itself. Its duration text bindings can't reproduce Puppeteer's flashing timer colors.

## 1.1.3-lowgc

Low-garbage build based on OldManAlpha's latest `dev` branch. That branch includes the Nampower cast-fail fix for heal predictions and the Vanilla Shaman Color option.

### Added

- **Blizzard Modern bars.** Blizzard Modern health and power textures, with a nine-class health palette and optional white health and power numbers. See the README and [MODERN-BLIZZARD.txt](MODERN-BLIZZARD.txt).
- **Puppeteer Flat and Puppeteer Flat Borderless bar textures.** The original Puppeteer textures are brighter in the top half than the bottom (about 188 vs 137–120 brightness), which makes bar colors look darker halfway down. The flat textures use the top-half brightness all the way down. The bordered one keeps Puppeteer's dark top and bottom edge.
- **Pets Use Owner's Class Color** (on by default). When health bars or names use the Class color, a hunter's pet is hunter green and a warlock's pet is warlock purple. Each pet slot's owner is looked up in a table built at load, so this adds no garbage.
- **Move frames with hidden titles.** While a group's title is hidden, hold Shift+Ctrl+Alt and left-drag any of its unit frames to move the group.
  - It uses the normal drag code, so frame locking, "move all frames" and saved positions behave as with the title.
  - That click never casts, even if the keys are released before the mouse button.
  - Groups with a visible title or a locked position keep the old behavior, including any Shift+Ctrl+Alt left-click binding.
- **Raid and healer mana in the Raid header**, with reporting for raid leaders and officers (from [skrymsli](https://github.com/skrymsli/Puppeteer)). As shipped, it rescanned all 40 raid frames and redrew the header on every mana, rage or energy event in the raid:
  - Each event became about 20x more expensive in CPU (111 µs vs 5.6 µs), and a raid-wide mana tick about twice as slow.
  - Here it updates at most twice per second, which is back to OldManAlpha's cost (5.3 µs per event) and adds about 2 bytes of garbage per raid-wide tick.
- **Variable test UI size, `/pt testui [count]`** (from skrymsli). Its per-call pattern match was replaced with a value cached when each frame is created.

### Changed

- **Shorter title bars.** The title bar above each frame group is 16 px tall instead of 20 px (`HEADER_HEIGHT` at the top of `PTUnitFrameGroup.lua`).
- **Much less garbage in combat.** WoW 1.12 runs Lua 5.0, whose collector stops the game and walks the whole heap whenever enough garbage piles up. That is the combat hitch, and the only fix an addon can make is to allocate less. None of these changes alter how the frames look or behave.

| Event (40-man raid) | OldManAlpha | 1.1.3-lowgc |
|---|---:|---:|
| Full group check (RAID_ROSTER_UPDATE) | 17,657 bytes | 237 bytes |
| Target change | 4,789 bytes | 1.5 bytes |
| HealComm message from another healer | 436 bytes | 4.3 bytes |
| Heal cast (SuperWoW START + CAST) | 409 bytes | 1.8 bytes |
| HoT cast + Nampower aura event | 419 bytes | 0.4 bytes |
| Heal cast + its combat log line | 134 bytes | 5.6 bytes |
| UNIT_HEALTH | 50 bytes | 21 bytes |

A simulated Naxxramas-style fight went from 21.1 KB/s to 8.6 KB/s of garbage. The SuperWoW + Nampower + UnitXP client and the plain 1.12 client gave the same results.

- **Private table pool (`libs/Pool.lua`).**
  - Puppeteer used Compost-2.0, which strongly keeps only 10 tables and puts the rest in a weak table that every GC empties. Its erase also shrinks tables, so every reuse has to grow them again.
  - Puppeteer's own code now uses a pool that survives GC and keeps table capacity. The shared Ace libraries still use their own Compost.
- **Aura scanning (`PTUnit`).** Each unit reuses one entry table per aura slot, and its name and type arrays, instead of rebuilding everything on every UNIT_AURA.
- **Target changes and group checks.**
  - The heal prediction GUID set is refilled in place, instead of building a new array and set every time.
  - Frame sorting and layout use reusable scratch tables and static comparators.
  - Role ranks are computed once per frame instead of inside the comparator, which also removes an O(n²) lookup during the sort.
- **Heal prediction.**
  - Tables orphaned on every cast are now reclaimed: the last cast, overwritten HoTs and overwritten resurrections.
  - Debug messages are only built when debug output is on.
- **Aura tracking.**
  - Nampower aura events reuse one table instead of creating `{target}` each time.
  - AoE buff target lists are released after use.
- **Unit frame text.**
  - Health, missing health, power, incoming heal and range text are each built with one `string.format`.
  - Color code prefixes and aura minute strings ("5m") are cached.
  - Range text is only rebuilt when the shown distance or its color changes.
- **Bundled HealComm-1.0.** The message split table and heal entries are reused. This only applies when Puppeteer's copy is the one loaded.

### Verification

- All files compile under a real Lua 5.0 VM.
- OldManAlpha's build, skrymsli's build and this build were run through the same deterministic simulated fight. Every frame's texts, bar values, colors, alpha, positions, aura icons, heal predictions and aura caches were compared at checkpoints across 10 settings and client combinations.
- Against OldManAlpha's build, every unit frame matched exactly. The only differences were in the raid header, where skrymsli's mana labels are.
- Against skrymsli's build, the only difference was that a stale aura icon reference now holds that slot's current aura instead of an erased table. That only affects what a hover tooltip would show.
