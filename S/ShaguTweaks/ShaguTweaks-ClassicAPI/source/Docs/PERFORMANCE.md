# Performance notes

## Player cache (`ShaguTweaks_player_cache`)

The account-wide player cache feeds Social Colors, Chat Levels and the
nameplate/chat class colors. It is read at every login and `/reload` and
written at every logout, so its size is a direct load-time and memory cost.
Earlier versions let it grow without limit; one account reached 4.1 MB.

`libs/libunitscan.lua` now owns expiry and runs it once per session, at the
first loading screen:

| Entry | Kept for |
|---|---|
| Player whose class is known | 180 days after last sighting |
| Player whose class was never learned | 90 days after last sighting |
| Whole cache | at most 10,000 players; the oldest sightings go first |

- Every sighting refreshes the age: mouseover, target, nameplate, party,
  raid, guild roster, friend list, `/who` and chat.
- Guild members and friends are refreshed by their roster events every
  session, so they do not expire while they stay in the guild or friend list.
- Entries saved before this change have no age. They are dated from the
  cache's existing grace start (`players_cleanup`), as the old Social Colors
  cleanup did. The first login after the update can remove many entries.
- A player's GUID is saved only while the class is unknown. Such entries are
  resolved later with `GetPlayerInfoByGUID` when the engine knows the GUID.

The separate 180-day cleanup in Social Colors is removed. It ran only every
180 days and only while that module was enabled.

## Event handling

- Chat: a speaker whose class is known and who spoke within the hour needs
  no GUID lookup or write.
- Guild roster: a full rescan runs at most once a minute unless the member
  count changed. Many addons request the roster every few seconds.
- Mouseover, target, nameplate and group sightings skip `UnitGUID` when
  `UnitClass` already gave the class.
- A name missing from the cache queries ClassicAPI's player cache once
  instead of twice.

## Range Color

3.8.2 uses native action-range subscriptions and change events when available.
Visibility and paging maintain balanced references. Older supported APIs retain
the independent 0.2-second timer introduced by the earlier fix; Blizzard's own
range timer remains untouched.

## Health/power numbers and swing timers (3.8.2)

Health events refresh only health text, and power events refresh only power
text, including the alternate druid power display. Target/pet identity changes
and startup still refresh both.

Swing/wand timers use native duration objects and countdown bindings when
available. Cancellable timers cover due/grace and Hunter warning boundaries;
range and action-state events update colors. The native path has no Lua
OnUpdate driver. Older APIs retain a throttled fallback, with numeric-tenth
comparison before formatting text. Current recoloring behavior is unchanged.

These are reductions in Lua work, not measured FPS claims. Follow the
[final 3.8.2 validation/measurement plan](PERFORMANCE_TEST_382.md) for A/B results.

## Map and portrait checks

- WorldMap Class Colors updates its icons ten times a second, and only while
  the world map or battlefield minimap is open. It used to run a check on
  every frame with both maps closed.
- Class Portraits checks the target of target five times a second, plus at
  once when the stock frame reports a new name. It used to call `UnitGUID`
  on every frame.

## Not changed

- Enlarged Minimap still checks the buff anchors every frame while the
  default buff frame is shown. The stock `BuffFrame_Enchant_OnUpdate` moves
  the buff frame back on every frame, so a less frequent check would let the
  buffs jump under the minimap. It writes only when an anchor has actually
  moved. The check is a child of `BuffFrame`, so it stops when a buff addon
  such as VCB hides the default buffs (the stock re-anchoring stops then too).

- Health Numbers and Big Health use one-shot deferred updates only.
- Both castbars update only while visible; Energy Tick hides at full mana
  out of combat.
- Free Slot Count counts slots once per `BAG_UPDATE_DELAYED`. Disable it if a
  bag addon already shows the count.

Nothing here has been measured in game yet. To compare before and after, see
[Measuring performance](CLASSICAPI_UPDATES.md#measuring-performance).
