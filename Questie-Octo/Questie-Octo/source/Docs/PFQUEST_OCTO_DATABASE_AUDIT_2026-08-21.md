# pfQuest-Octo 1.1.0 / Current Server Quest Data Audit

**Audit date:** 2026-08-21  
**Questie-Octo baseline:** 1.0.57  
**Resulting build:** 1.0.58

## Scope and authority

This pass compares the current Questie-Octo source with the user-supplied
`pfQuest-octo-master` 1.1.0 reference and the supplied current Turtle/Tortoise
server source. Per the project handoff, Questie-Octo is implementation truth,
current Turtle/Tortoise source is server-side quest/objective authority, and
pfQuest is a reference implementation rather than an automatic replacement
database.

The supplied pfQuest archive is byte-identical by SHA-256 to the current 1.1.0
pfQuest reference already recorded in `SOURCE_PROVENANCE.md`. The audit therefore
finishes the previously deferred review rather than treating the upload as an
unreviewed newer database generation.

## Accepted safe corrections

### Quest 1704 — Klockmort Spannerspan

The current server setup starts from its database state and then applies the
packaged `database_updates` in order. In that effective server state, quest 1704
uses race mask **68** and requires item **6926 — Furen's Notes**. The recent
pfQuest-octo reference broadens the race mask to 589, but there is no current
server-side migration supporting that broader restriction, so 1.0.58 deliberately
keeps Questie-Octo's existing race mask 68. The missing 6926 formal item objective
is restored.

### Quest 5206 — Marauders of Darrowshire

Current server truth requires **5 Resonating Skulls (13155)** and **1 Mystic
Crystal (13156)**. Fetid Skull (13157) is part of the interaction/source flow, not
the formal turn-in objective. The static quest record now contains 13155 and
13156. For map/minimap usefulness, the Resonating Skull objective receives a
presentation-only source at **Scourge Champion (8529)**, the current source of
Fetid Skulls. Its 80% Fetid Skull drop rate is intentionally not displayed as a
Resonating Skull conversion chance.

### Quest 6661 — Deeprun Rat Roundup

The current server quest template formally tracks **13017 — Enthralled Deeprun
Rat** and uses spell 21050 from the Rat Catcher's Flute. The player must first
find **13016 — Deeprun Rat**. Therefore the database keeps 13017 for live
progress/completion while map/minimap presentation resolves that objective to
13016. This is the same conservative formal-target/actionable-source separation
used elsewhere in Questie-Octo.

### Quest 41312 — Restoration

Current server data requires all four items **41371, 41373, 41397, 41445**. The
Questie row was missing 41371; the pfQuest replacement candidate was also
incomplete because it omitted 41445. 1.0.58 keeps all four current server
requirements.

### Quest 41659 — The Sal'Galaz Mines

The quest text requires Bonesplitter Troggs, Seers, Bonesnappers, and
Skullthumpers. Current server creature data identifies the ordinary Bonesplitter
Trogg as **62228**; there is no corresponding current objective creature 62229.
The quest objective set is now **62228, 62230, 62231, 62232**.

The legacy compatibility unit record 62229 is deliberately not deleted in this
pass because inherited item-source tables still contain references to that ID.
Those historical loot/source links need a separate audit before the compatibility
record itself can be removed safely.

### Event 164 metadata

Current server `game_event_quest` data associates **8595, 8764, 8765, 8766**
with event 164. Questie-Octo already treats 164 as a permanent/non-seasonal 1.9
content gate. The four missing memberships are restored as metadata completeness;
the change does not make the quests seasonal.

## Rejected / deliberately untouched pfQuest replacements

The old 38-quest replacement batch is still **not** suitable for wholesale
import. Several replacements discard server-backed objectives or physical
guidance that Questie-Octo already preserves. In particular:

- **8249 — Junkboxes Needed:** the pfQuest replacement conflicts with the current
  server's required item and remains rejected.
- **40056 — The Scroll of Cow Portal:** the pfQuest replacement would substitute
  unrelated requirements and remains rejected.
- Capture/transform and item-use quests are handled additively when current server
  completion truth and actionable physical source differ; shorter replacement
  arrays are not assumed to be more correct.

No other member of the deferred replacement batch was changed by 1.0.58.

## Runtime impact

After regeneration and validation:

- quests: **6700**
- items: **3635**
- units: **14136**
- objects: **1637**
- refloot: **124**
- quest item requirements: **189**
- maps: **109**
- map links: **8677**
- item names: **6395**
- unit names: **14133**
- object names: **1636**
- compiled/pruned runtime: **true**

The one-net-item increase versus 1.0.57 is an intentional reachability result of
restoring formal quest objective items while removing Fetid Skull from quest
5206's formal objective set.
