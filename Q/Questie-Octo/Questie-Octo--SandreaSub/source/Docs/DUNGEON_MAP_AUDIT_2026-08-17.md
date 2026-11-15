# Questie-Octo — Atlas-CFM Dungeon Map Audit (2026-08-17)

## Scope

Reference-only audit of the supplied current Atlas-CFM package against Questie-Octo 1.0.40, the supplied current Turtle/Tortoise server source/data, current pfQuest ClassicAPI reference, and current ClassicAPI surface.

Atlas-CFM is **not** treated as quest-template authority and no Atlas source code or quest database is imported into Questie-Octo.

## Quest coverage

Every unique quest ID parsed from the supplied Atlas-CFM English dungeon quest data already exists in the Questie-Octo 1.0.40 compiled quest database. Atlas therefore did not reveal a broad missing-dungeon-quest-ID problem.

Where Atlas quest level/minimum-level metadata differed from Questie-Octo, current Turtle server quest-template truth was checked rather than replacing Questie-Octo values from Atlas. The checked ordinary server-template differences agreed with Questie-Octo rather than Atlas.

## Current custom dungeon map identity risk

Questie-Octo 1.0.40 resolved World Map and Minimap identity primarily through display-name reverse lookup. That is unsafe for current custom content because several packaged AreaTable rows share the same visible name. Examples in the current database include:

- Frostmane Hollow: 5734, 5735
- Hateforge Quarry: 5098, 5103
- Gilneas City: 5180, 5208
- Dragonmaw Retreat: 5600, 5601
- The Black Morass: 2366, 5204
- Timbermaw Hold: 1216, 1769, 5640, 5643

A `pairs()` name scan can therefore choose an unrelated parent/subarea/wing nondeterministically. This is a plausible category for misplaced custom-dungeon pins even when the underlying spawn coordinates are correct.

### 1.0.41 correction

Questie-Octo now prefers current client identity through ClassicAPI:

- `C_Map.GetMapAreaIDs()` + `GetMapInfo()` for the map currently displayed by the World Map;
- `C_Map.GetBestMapForUnit("player")` for the player's physical Minimap map;
- `C_Map.GetAreas()` for localized name fallback;
- packaged name fallback only when the name is unambiguous.

This mirrors the current-client identity strategy used by the supplied pfQuest ClassicAPI reference while retaining Questie-Octo's own map/node architecture.

## Wailing Caverns

Wailing Caverns itself is uniquely identified as AreaTable/map ID 718 in the packaged database. Current Turtle-specific static bosses, including Zandara Windhoof and Vangros, already carry map-718 coordinates.

A server-world-position comparison against Questie-Octo's current map-718 coordinates for multiple static Wailing Caverns creatures produces one consistent transform to within a few hundredths of a map percentage point. This supports retaining the current static Wailing coordinates rather than replacing them from Atlas artwork.

### Mutanus the Devourer (3654)

Mutanus is not an ordinary static creature spawn. The current Turtle server `wailing_caverns.cpp` summons him during the Naralex event at world position:

`142.7, 254.0, -102.2`

The current Wailing map transform places that scripted encounter at approximately:

`45.8, 9.2` on map 718.

The server instance script also requires Lady Anacondra, Lord Cobrahn, Lord Pythas and Lord Serpentis to be completed before the Disciple of Naralex receives the special gossip that starts the escort. Mutanus is summoned only near the end of that event.

Questie-Octo 1.0.41 therefore adds this position only as a **presentation fallback** for Mutanus when normal server-derived creature coordinates are absent. Its tooltip explicitly explains the scripted requirement. If a future database provides ordinary coordinates for 3654, those normal coordinates automatically take precedence.

This benefits `60124 Trapped in the Nightmare` and both the item-start and active item-source guidance for `6981 The Glowing Shard` without pretending Mutanus is permanently spawned.

## Crash report

The supplied ERROR #132 is a native access violation and contains no Questie-Octo Lua traceback. The memory dump includes `DBG:MBB_MinimapButtonFrame`, which is not Questie-Octo's `QuestieOctoMinimapButton` frame name. The map-placement issue and the crash therefore remain separate unless a reproducible sequence proves otherwise.

No automatic frame-tree/map diagnostics were added because the project previously encountered an ERROR #132 with aggressive diagnostics during fragile map state.

## Deferred database audit reminder

The previously audited 38 non-additive pfQuest 1.1.0 objective-replacement batch remains separate from this dungeon presentation/map-identity work. No destructive objective replacement from that batch is imported here.
