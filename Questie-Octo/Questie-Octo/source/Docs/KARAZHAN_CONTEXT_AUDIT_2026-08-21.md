# Karazhan map-context audit — 2026-08-21

## Scope

Focused audit for the current Octo/Turtle client/server data collision where Lower Karazhan Halls and Upper Karazhan first floor share AreaTable ID `3457`.

Questie-Octo 1.0.62 keyed most map work by that numeric area ID, so Lower and Upper first floor could share one prepared-map/node bucket even though they are distinct physical instance contexts.

Karazhan is not currently accessible on the live OctoWoW realm according to current project testing, so this is a preventive, Karazhan-only compatibility correction rather than a response to a live player regression.

## Current client evidence

Current `WorldMapArea.dbc` contains:

| WorldMapArea | Server map | AreaTable | Texture | World span |
| ---: | ---: | ---: | --- | ---: |
| 657 | 532 | 3457 | `Karazhan` | 619 × 410 |
| 682 | 814 | 3457 | `UpperKarazhan` | 823 × 549 |
| 683 | 814 | 5557 | `UpperKarazhan2f` | separate area ID |

The collision is therefore limited to:

- server map 532 / texture `Karazhan` / AreaTable 3457 — Lower Karazhan Halls;
- server map 814 / texture `UpperKarazhan` / AreaTable 3457 — Upper Karazhan first floor.

Upper Karazhan second floor already has distinct AreaTable ID `5557` and requires no special split.

Current `AreaTrigger.dbc` also retains server-map identity for triggers that project to the shared AreaTable:

- trigger 5019 belongs to server map 532;
- triggers 5341, 5349, 5350 and 5351 belong to server map 814.

## Current runtime collision

Questie-Octo's compiled 1.0.62 runtime contains 107 units and 8 objects with coordinates under numeric map ID `3457`.

The current server spawn audit cleanly separates the ordinary static population: 38 current static creature identities belong to map 532 and 38 belong to map 814. Additional scripted/non-static sources exist, but a numeric `3457` coordinate by itself is not enough to prove which first-floor context owns them.

Examples of the collision:

- Doorman Montigue (61571) is a Lower Karazhan source on server map 532;
- Big Whiskers (61990) is an Upper Karazhan source on server map 814;
- both were represented to the old map layer as coordinates on `3457`.

That means an AreaTable-only renderer could place a believable Upper coordinate onto the Lower texture or vice versa.

## 1.0.63 correction

The normal Questie-Octo numeric-map architecture is preserved. Only AreaTable `3457` receives a secondary Karazhan context.

### Displayed World Map

For map ID 3457, native `GetMapInfo()` texture identity is retained:

- `Karazhan` => `lower`;
- `UpperKarazhan` => `upper`.

Prepared data may remain cached under numeric map ID 3457, but rendering filters each source through the proven Lower/Upper source context. Switching between the two native textures forces a Questie map refresh even though the numeric area ID did not change.

### Physical minimap

For physical map ID 3457, ClassicAPI's backported `GetInstanceInfo()` instance-map ID distinguishes:

- server map 532 => `lower`;
- server map 814 => `upper`.

The minimap also selects the correct physical WorldMapArea span (619×410 vs 823×549) rather than trusting the single legacy `runtime/minimap[3457]` value.

If the physical server-map context cannot be proven, Questie fails closed and publishes no 3457 minimap nodes instead of guessing.

### Tracker Show on Map

Tracker objective/turn-in targets on 3457 retain their source context. Lower targets cannot be treated as valid merely because an Upper `3457` map is visible, and vice versa.

Interface 11200 still has no arbitrary native API for selecting Lower vs Upper Karazhan by an AreaTable number, so tracker Show on Map only accepts the shared 3457 context when:

- that exact Lower/Upper texture is already displayed; or
- the player is physically in the matching instance context.

No synthetic outdoor fallback, Atlas replacement, navigation arrow, or fake map selector was added.

## Source classification rule

For the shared area only, Questie uses a small explicit source-context table derived from current client/server evidence.

- ordinary current static creature spawns are classified by server map 532 or 814;
- current quest-relevant non-static Upper sources with explicit server relationships are classified when the context is supported;
- current gameobjects are classified only when their context is supported;
- current AreaTriggers are classified directly from `AreaTrigger.dbc` server-map identity;
- an unclassified source is hidden on shared area 3457 rather than projected onto the wrong texture.

This fail-closed rule is deliberate. Future current-database/server updates or live player evidence can add a missing source context without weakening the Lower/Upper separation.

## Intentionally unchanged

- No quest templates or objective truth changed.
- No coordinates were rewritten.
- Upper second floor area 5557 is unchanged.
- No global map-ID redesign was introduced.
- No continent projection was added.
- No dungeon entrance markers were restored.
- README/options/UI layout are unchanged.

## Validation boundary

This correction can be source/static validated now, but Karazhan is not currently accessible on the live OctoWoW realm, so it cannot be called live player-confirmed yet. Re-audit the current release data if Karazhan is enabled or its client/server map definitions change.
