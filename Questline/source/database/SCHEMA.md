# Database schema 1

The current source snapshot is imported from OctoQuestDatabase's resolved tables
with `npm run import -- [path-to-OctoQuestDatabase]`. `database-source.json` pins
the exact shared content revision; deliberate updates require `--update-lock`.
The import records input hashes and generated snapshot hashes in `manifest.json`.
OctoQuestDatabase is the sole authority; there are no local overrides or fallback
databases. `npm run build` produces the in-game `Data/` files. Submit data
corrections to OctoQuestDatabase, then refresh the snapshot and generated Lua.

All entity tables are JSON objects keyed by numeric ID strings. Runtime Lua uses numeric entity keys and string location keys. IDs from different kinds are distinct.

The compiler preserves quest `attributes.type` as runtime `questType` (1 is
Elite, 62 Raid, 81 Dungeon). Live quest-log tags can override its presentation.

| File | Record fields |
| --- | --- |
| `quests.json` | `title`, `level`, `minLevel`, `raceMask`, `classMask`, `description`, `summary`, `starters`, `finishers`, `objectives`, `prerequisites`, `closes`, `attributes` |
| `units.json`, `objects.json` | `name`, `coordinates`, `faction`, `level`, `attributes` |
| `items.json` | `name`, `drops: { units, objects, groups }`, `vendors`, `attributes` |
| `lootGroups.json` | `units`, `objects`, `groups`, `attributes`; the first three map source IDs to upstream values |
| `itemUses.json` | Item ID to an array of `{kind, id, spell}` interactions; negative upstream IDs become positive `object` IDs |
| `events.json` | `coordinates`, `attributes`; exploration trigger targets |
| `scriptedEncounters.json` | Unit ID to upstream presentation guidance: `roles`, `coordinates`, optional `anchorObject`, `displayName`, `note`. Used only for the stated role when canonical unit coordinates are absent; an object anchor resolves through `objects.json`. |
| `zones.json` | `name`, `coordinateCount`, optional `bounds: { parent, width, height, x, y }` |
| `reference.json` | Merged profession names, service/resource metadata, minimap dimensions, and Turtle quest patch metadata; the compiler extracts profession names and zone dimensions needed at runtime |

Targets are `{kind, id}`. Kinds are `unit`, `object`, `item`, `event`, `use`, and `zone`. A `use` ID is a quest item, resolved through `itemUses`. No objective ordering or required quantity is invented: live quest-log objective strings supply current counts. Extra upstream fields are retained in `attributes` rather than discarded or assigned guessed semantics.

Coordinates are arrays of `[x, y, zoneId, respawnSeconds?]`. X/Y use percentages in the named zone, not continent coordinates. Zero-zero placeholders, non-finite values, out-of-range points, and non-positive zone IDs are rejected. Respawn is optional. Duplicate X/Y/zone triples collapse to one coordinate. Faction is the upstream friendly-faction string (`A`, `H`, `AH`, or empty/unspecified). Unit levels may be ranges, so they remain strings.

All JSON entity tables are disposable import output. Import replaces them completely; build compiles them without applying any local corrections. Upstream zone IDs are preserved.

Upstream `attributes.preActive` compiles to an `activePrerequisites` ID array.
Availability requires any such predecessor in the live quest log. These IDs
cannot also satisfy an ordinary `prerequisites` entry through completion history;
other completed predecessors remain alternatives to the active requirement.

Runtime `QuestlineDB.locations[targetKey][zoneId]` contains:

- `anchor`: `[x,y]`, an actual spawn near the largest cluster's center, used for the quest selector.
- `points`: arrays of `[x,y]` for precise markers.
- `spawnPoints`: optional packed source positions for selected-quest spawn markers. Four characters per point encode x then y as two base64-pairs integers, each representing percent multiplied by 40 (range 0?4000). Deduplicated after quantization and sorted by x/y; absent for turn-ins, zone centers, and exploration triggers.
- `runs`: runtime schema 2 packs zero-based `[row, startColumn, exclusiveEndColumn]` triples into strings. Each integer occupies two characters from `0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_`; its value is `firstDigit * 64 + secondDigit`. Each triple is six characters. `tools/packed-runs.js` encodes/decodes this generated representation. `QuestlineDB.grid` is 1280. The normalized JSON remains schema 1 and is unchanged by this runtime encoding.
- `spawns`: number of unique source points in that zone.
- `vendorNames`: optional names of recorded item vendors keyed by `x:y`, where
  x/y are coordinates rounded to percent times 40. These keys identify vendors
  at precise and packed spawn pins; names sharing a coordinate are joined with
  ` / `. This metadata comes directly from upstream vendor and unit records.
- `sources`: optional named drop/interaction sources for item and use targets,
  each `{name, kind, points}`. Kind is `unit` or `object`; points uses the same
  packed coordinate pairs as `spawnPoints`. Names come from upstream source
  records, including reference loot. Runtime derives and caches a coordinate
  lookup, keeping source NPCs separate from vendors and world objects.

Compiler display policy omits vendor coordinates for items stocked without a
limit by at least ten vendors. Their objective records and actual drop sources
remain intact; specialty and limited-stock items retain vendor destinations.
Unfinished quest badges prefer the area target with the most spawns, falling
back to the first mapped point target when no area remains.

Turn-in location keys are prefixed `turnin:` and always use point geometry. Ordinary keys look like `item:5087` or `unit:3338`. Multiple quests reuse target geometry. The runtime retains objective names, summary/description for identification, and finishers. It also retains minimum level, race/class masks, `prerequisites`, reverse `blockedBy` lists derived from other quests' `closes`, an optional profession name (`skill`), holiday `event`, and explicit `repeatable` flags for availability checks. Prerequisites follow the upstream any-completed-predecessor semantics; unrecorded requirements are not invented.

`QuestlineDB.mobObjectives[normalizedMobName]` is a generated array of `unit:<id>` and `item:<id>` objective keys used by mob tooltips. Names are lowercase with normalized whitespace. The compiler follows direct unit drops and reference-loot groups, retains zero-rate quest-only drops, and excludes negative/disabled drops, vendors, and containers. Only targets used by quests enter this index. Item and mob names still come from the owned JSON; runtime progress and required counts come from the current quest log, not this index. Rebuild to regenerate `Data/MobObjectives.lua` after corrections to item sources or mob names.

`QuestlineDB.objectObjectives[normalizedObjectName]` is generated in the same file using the same normalization and reference-loot rules. It maps world-object names to `object:<id>` and `item:<id>` objective keys. It follows object loot sources rather than unit drops, excluding vendors and inventory-container contents. Runtime uses this index only for world-object tooltips, with live quest-log counters; it does not assign mob drop rates to objects.

`QuestlineDB.mobDropRates[normalizedMobName][itemKey] = percentage` is generated in the same `Data/MobObjectives.lua` file. It contains positive known percentages up to 100 for quest items. Direct unit rates take precedence over reference records. For reference loot, the item's reference chance supplies the percentage; membership values are not multiplied into it. Cycles are guarded, and conflicting reference paths or same-name NPC variants omit the percentage. Zero/unknown, negative, invalid, and vendor-only values never become displayed drop percentages, while the objective index still retains valid sources with unknown rates. The tooltip adds rates to a per-mob copy of the live counter so one mob's percentage cannot affect another's.

`QuestlineDB.npcQuests[normalizedNPCName] = {starters={questIDs}, finishers={questIDs}}` is the reverse NPC role index in `Data/NPCQuests.lua`. Only unit targets are included; a talk-to objective is identified independently from the live objective text and quest summary.

`QuestlineDB.givers[unitID] = {name, quests={questIDs}, coordinates={{x,y,zoneID}, ...}}` contains NPC starters and deduplicated recorded positions. `QuestlineDB.zoneGivers[zoneID] = {unitIDs}` limits lookup to the displayed zone. These are generated as `Data/QuestGivers.lua` and `Data/ZoneGivers.lua`. Unlocated NPCs can still have tooltip offers, but receive no invented map position. Multiple quests offered by one NPC share its marker.

Givers also retain the source `faction` for both unit and object starters.
The NPC name index includes `factions[questID]`, the union of allowed factions
across same-name unit starters for that quest; unspecified factions allow both.
Predicted map offers use the individual giver's faction, while NPC tooltip
predictions use this per-quest name index. These restrictions supplement quest
race masks, which may be zero even for a faction-specific starter. Neutral,
unspecified, or unknown player factions remain permissive. Actual observed
server offers retain precedence over predicted starter-faction restrictions.

Runtime zones have an optional `mapSize = {widthYards,heightYards}`, extracted from `reference.minimap`, for converting zone percentages to minimap distance. These are map dimensions, not pixel sizes. Unknown dimensions disable minimap markers for that zone.

`QuestlineSettings.completedQuests[questID] = true` is per-character history, separate from all generated database tables. Native server history, a one-time pfQuest history import, and confirmed quest-completion messages can add entries. Recent NPC offers and availability caches remain session-only.

Item-target locations may include `spawnKinds`, one character per packed spawn: `g` for a world-object interaction and `l` for other item sources. Source types survive direct and reference-loot traversal; coincident object/item sources prefer the gear. Missing metadata falls back to the target icon.
