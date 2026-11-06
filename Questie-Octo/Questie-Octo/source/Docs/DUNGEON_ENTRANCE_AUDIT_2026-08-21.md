# Questie-Octo 1.0.60 — Dungeon Entrance Audit

> **Status after 1.0.61:** historical audit only. The 1.0.60 runtime entrance-pin feature was removed after live testing showed a bad Scarlet Monastery Cathedral exterior projection and the project chose not to duplicate dungeon-entrance guidance already common in other Turtle addons. The AreaTrigger/server-teleport findings below remain useful research, but they no longer create Questie-Octo map/minimap pins.

## Scope and authority

This document records the 1.0.60 experiment that implemented the previously deferred dungeon entrance guidance for **active quests**. It did not treat reference-addon entrance tables as authority; the runtime experiment itself is removed in 1.0.61.

Current sources used:

- `DBFilesClient(1).zip` → `AreaTrigger.dbc`, `WorldMapArea.dbc`, `Map.dbc`.
- `tortoise-wow-main(7).zip` → `sql/base/tw_world_areatrigger_teleport.sql`.
- Questie-Octo 1.0.59 source → existing node, map, minimap, continent, tooltip and objective-refresh architecture.

The current server teleport table contains **133 rows**. Raw rows are not equivalent to safe player markers: the table also contains exits, internal transitions, conditioned portals, PvP/city portals, duplicate legacy entries and unavailable content.

## Historical 1.0.60 runtime behavior

1. Questie-Octo first builds the normal current actionable nodes for an active quest.
2. If those nodes reach a supported current client instance/floor context, the entrance subsystem considers that instance's verified physical server entrance(s).
3. A single-entrance context publishes that verified entrance.
4. A multi-entrance context compares the active internal objective/turn-in points to each entrance's authoritative **inside teleport destination**. Distances are weighted with the current client WorldMapArea dimensions, so rectangular dungeon maps are not treated as square.
5. Each active point can select its nearest entrance. A quest spanning multiple wings can therefore show multiple legitimate entrances. Equal inside destinations preserve equivalent alternatives, as with Stormwind Vault's outside and Mirror Lake entrances.
6. If a multi-entrance dungeon has no usable internal point, Questie-Octo publishes no guessed entrance.
7. Entrance nodes are attached to the quest and are rebuilt by the existing quest/objective refresh path, including while standing still.

The entrance uses the existing interaction icon and `(Entrance)` tooltip status. Multiple active quests using the same portal share one physical pin and keep their separate quest lines in its tooltip. It follows the existing objective/map/minimap visibility controls. No new toggle, polling path, navigation arrow, or quest-truth rewrite is introduced.

## Included verified entrance contexts

The curated runtime table contains **40 unique physical AreaTrigger IDs**, represented by **41 target-map records across 30 current client instance/floor contexts**. Black Morass accounts for the extra record because both current client floors use the same physical entrance.

Included contexts:

- Shadowfang Keep
- The Stockade
- The Deadmines
- Wailing Caverns
- Razorfen Kraul
- Blackfathom Deeps
- Uldaman — front/back selection
- Gnomeregan — front/back selection
- Razorfen Downs
- The Temple of Atal'Hakkar / Sunken Temple
- Scarlet Monastery — Graveyard, Library, Armory and Cathedral current floors
- Zul'Farrak
- Blackrock Depths
- Blackrock Spire
- Stratholme — back/right/left selection
- Ragefire Chasm
- Scholomance
- Maraudon — Orange/Purple selection
- Dire Maul — six current server entrances selected from internal destination geometry
- Zul'Gurub
- Black Morass — both current client floors, one physical entrance
- Gilneas City
- Hateforge Quarry
- Karazhan Crypt
- Crescent Grove
- Stormwind Vault — current outside entrance plus distinct Mirror Lake entrance

The legacy Stormwind Vault trigger 107 and current explicit outside trigger 5002 occupy the same physical entrance. 1.0.60 keeps the current explicit row 5002 and does not double-publish 107.

## Intentionally excluded / unresolved

These are not guessed in 1.0.60:

- **Onyxia's Lair (2848):** server requires condition 16309 / Drakefire access.
- **Molten Core:** ordinary trigger 2886 originates inside Blackrock Depths; outdoor window triggers 3528/3529 are condition-gated.
- **Blackwing Lair (3726):** source trigger is inside Blackrock Spire rather than an outdoor entrance.
- **Ruins of Ahn'Qiraj / AQ20 (4008):** condition-gated and the physical trigger does not fit the normal Silithus WorldMapArea; presenting it cleanly would require the overlapping helper map explicitly rejected by the earlier audit.
- **Temple of Ahn'Qiraj / AQ40 (4010):** condition 126.
- **Naxxramas (4055):** condition 9124.
- **Emerald Sanctum (5017):** condition 30003.
- **Lower Karazhan Halls (5018):** client area 3457 is shared between server map 532 Lower Karazhan and server map 814 Upper Karazhan. Questie-Octo's current area-ID-centric node graph cannot distinguish that safely.
- **Grim Batol (5337):** current server message explicitly says the raid is not available yet.
- **Dragonmaw Retreat (816), Stormwrought Ruins (818), Timbermaw Hold (819), Windhorn Canyon (820), Frostmane Hollow (822):** no current authoritative `areatrigger_teleport` destination row targets these maps in the supplied server snapshot. No static portal is invented.

Zul'Gurub's entrance has server content phase `1` but no per-character `required_condition`; it is retained as a current physical entrance. Server phase metadata is preserved in the runtime table but is not used as a player-specific access claim.

## Exterior-map choices

Current WorldMapArea rectangles overlap in several places. The feature therefore records one conservative physical exterior map per trigger instead of publishing every rectangle that mathematically contains the point. Examples include Tirisfal for Scarlet Monastery, Westfall for Deadmines, Barrens for Wailing Caverns/Razorfen, Badlands for Uldaman and Western Plaguelands for Scholomance.

Blackrock Depths' physical trigger is on server map 0 and fits the current Searing Gorge WorldMapArea, so the zone marker uses that current client projection. Blackrock Spire's trigger fits the current Blackrock Mountain context; the existing continent projector deliberately does not treat Blackrock Mountain as a normal outdoor leveling zone, so that particular entrance remains available on its detailed map without changing the older projection boundary.

## Validation boundary

The source/static release checks verify the curated trigger set, coordinate ranges, multi-entrance selection behavior, Lua parsing, node integration and package/runtime invariants. They do not constitute in-game validation of every doorway. Player testing remains valuable, especially for multi-entrance dungeons and current Turtle custom instances.
