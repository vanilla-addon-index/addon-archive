# pfUI Octo meters: design spec (roadmap phase 5)

Written 19 Oct 2026. Design only, no code. Target: 1.12.1 build 5875 (OctoWoW), Lua 5.0, pfUI `octo`
branch. Goal from the user: "They should tell you everything. all interupts all casts everything."
Replaces ShaguDPS and TWThreat. Credit ShaguDPS (parser approach); TWThreat code is not copied (no
licence), only its wire protocol is described (section 3).

How this was researched: feature lists of Details!, Recount and Skada come from their long-standing
public feature sets (web search for them returned little; no page enumerated the modes, so the lists
below are from knowledge of the addons and the Numeration / MiliUI pages found, and are the
reference for scope, not a quote). Data sources were read from this install: `ShaguDPS\parser.lua`,
`parser-vanilla.lua`, `Spy\SpyNampower.lua`, `OctoBG\CLAUDE.md`, `OctoBG\modules\Threat.lua`,
`TWThreat\TWThreat.lua`, and the exported names in `nampower.dll` (extracted with grep, checked).
The nampower EVENTS.md on gitea could not be fetched (sign-in page), so argument layouts are marked
**V** (verified in a file here) or **R** (recalled from EVENTS.md, check with a probe before coding).

Status words used below: **available** (data is there), **partial** (say what is missing),
**impossible** (not on 1.12).

---

## 1. What the retail meters show

### 1.1 Display modes

Details! (Tercio), grouped as its own menu does:

| Group | Modes |
|---|---|
| Damage | Damage Done, DPS, Damage Taken, Friendly Fire, Frags (kills), Enemies (damage done to / taken from each enemy), Voidzone damage, Damage Done by Spell (all sources), Damage Done by target |
| Healing | Healing Done, HPS, Overheal, Healing Taken, Healing Prevented, Absorbs ("Damage prevented"), Heal Enemy |
| Resources | Mana restored, Rage / Energy / other power generated |
| Utility ("Misc") | Interrupts, Dispels, Cooldowns used (defensive and raid), CC breaks, Resurrections, Deaths, Buff Uptime, Debuff Uptime, Spell casts ("Spell Cast" is in a plugin) |
| Plugins | Tiny Threat, Vanguard (tank view: tanks' debuffs and incoming), Encounter Details, Time Line, Chart Viewer, Advanced Death Logs, Streamer, Coach |

Recount: Damage Done, Damage Taken, Healing Done, Healing Taken, Overhealing, DPS, Deaths,
Dispels, Interrupts, CC Breakers, Resurrections, Threat, Activity (time spent in combat), Mana
Gained, Buffs gained, Debuffs gained, Friendly Fire, Avoidance (dodge / parry / block counts), Fight
(summary), "Damage done on <mob>" per mob, graphs in the detail window.

Skada: Damage, Damage Taken, Enemy Damage Done / Taken, Healing, Overhealing, Absorbs, Dispels,
Interrupts, Deaths, Buffs and Debuffs (uptime), Avoidance and Mitigation, CC Done, CC Breaks,
Threat, Resurrects, Power Gains, Activity, Casts, Friendly Fire, Fails (avoidable damage),
spell-school splits.

Numeration (found by search) adds a chronological Deathlog and "Damage Taken: Targets / Abilities".

### 1.2 Detail views (drill-down)

- Per-spell breakdown for any actor: total, % of total, hits, crits, misses, glancing, crushing,
  blocked, resisted, absorbed, min / max / average, crit %, hit %, per-second, for DoT ticks vs direct.
- Per-target breakdown (who was hit, by how much) and the reverse (who hit this actor, with what).
- Spells shown per target and targets per spell (Skada "Shift-click"; Details! "Targets" tab).
- Avoidance tab (dodge / parry / block / miss / absorb counts and rates), Auras tab (uptime, applications),
  compare two players side by side (Details!).
- Pets merged under the owner, with a pet sub-line; multi-pet "Pet: Name".
- Death log: last N events before death with timestamp, source, spell, amount, HP at the time,
  heals in between, overkill; click a death to open it. Details! shows a mini HP graph.

### 1.3 Window UX

- Tabs / mode menu in the title bar (click title = pick mode, right-click = options).
- Segments: Current, Overall, previous fights (list, boss fights named), trash merged, auto-reset on
  entering an instance with a prompt, "Remove segment", data kept after reload (saved variables).
- Multiple windows (Details! up to many, Recount one per mode), snapped together, each with its own
  mode and segment, mirrored scale / alpha / bar texture / font.
- Bar: rank number, class icon, name, value, % and per-second; class colour; hover tooltip listing
  top spells (Details! with Shift = targets, Ctrl = pets, Alt = percent only); click opens the drill-down;
  right-click for options; scroll wheel; bar for "You" pinned when outside top N.
- Report to chat: Say / Party / Raid / Guild / Whisper / Officer / channel / "copy window text", with a
  line-count box; report for a single player's spells.
- Title shows the segment name and combat time; collapse to title only; lock; auto-hide out of combat.
- Reset button with confirmation, sync of data between users (Recount "Network" / Details! raid damage
  sync), export of a segment, minimap button.

---

## 2. Data sources on this client

### 2.1 The source toolbox

| Source | What it gives | Requirements / limits |
|---|---|---|
| **A. Combat-log chat events** `CHAT_MSG_COMBAT_*`, `CHAT_MSG_SPELL_*` | Localised strings, parsed with GlobalStrings patterns (`SPELLLOGSCHOOLOTHEROTHER` ...), names only (no GUIDs, no spell ids). ShaguDPS parses only damage and heals (`parser-vanilla.lua`, patterns above line 110). Many more GlobalStrings exist: `SPELLINTERRUPT*`, `DISPEL*`, `UNITDIES*`, `SPELLRESIST*`, `VS*` (dodge / parry / block / absorb), `AURAADDED*`, `AURAREMOVED*`, `SPELLCASTGO*` / `SPELLPERFORMGO*`, `SPELLLOGABSORB*`, `HEALEDCRIT*` | Range-limited: the client only emits log lines for events within the combat-log range CVars (`CombatLogRangeParty` / `Friendly` / `Hostile` / `Creature`, default 50 yd, max is server-/client-clamped; OctoBG's notes mention the range CVars but never measured their ceiling). Raid members out of range are silent. Names are ambiguous for same-name players / pets. |
| **B. nampower events** (installed, v in `nampower.dll`) | GUIDs, spell ids, exact numbers, for the player (`*_SELF`) and everyone else the client sees (`*_OTHER`). Names found in the DLL: `AUTO_ATTACK_SELF/OTHER`, `SPELL_START_SELF/OTHER`, `SPELL_GO_SELF/OTHER`, `SPELL_FAILED_SELF/OTHER`, `SPELL_DELAYED_SELF/OTHER`, `SPELL_DAMAGE_EVENT_SELF/OTHER`, `SPELL_MISS_SELF/OTHER`, `SPELL_HEAL_BY_SELF/OTHER`, `SPELL_HEAL_ON_SELF`, `SPELL_ENERGIZE_BY_SELF/OTHER`, `SPELL_ENERGIZE_ON_SELF`, `SPELL_DISPEL_BY_SELF/OTHER`, `AURA_CAST_ON_SELF/OTHER`, `BUFF_ADDED/REMOVED_SELF/OTHER`, `DEBUFF_ADDED/REMOVED_SELF/OTHER`, `BUFF/DEBUFF_UPDATE_DURATION_SELF`, `DAMAGE_SHIELD_SELF/OTHER`, `ENVIRONMENTAL_DMG_SELF/OTHER`, `UNIT_DIED`, `SPELL_CAST_EVENT` (your own cast attempts), `UNIT_AURA_GUID` / `UNIT_HEALTH_GUID` / `UNIT_COMBAT_GUID` and friends (GUID-keyed unit events). Functions: `GetSpellRecField(id, "name")`, `GetSpellNameAndRankForId`, `GetSpellIconTexture`, `GetUnitField(unit, "aura")`, `GetUnitGUID`, `GetCastInfo`. | CVars must be 1: `NP_EnableSpellStartEvents`, `NP_EnableSpellGoEvents`, `NP_EnableAutoAttackEvents`, `NP_EnableSpellHealEvents`, `NP_EnableSpellEnergizeEvents`, `NP_EnableAuraCastEvents` (Spy sets them; OctoBG never did). `*_OTHER` events are range-limited by the server's visibility (the client must have the unit in its object list); whether they cover party members beyond 50 yd and whether `*_OTHER` includes the player's own party/pets is **not verified in game** (AnySCT marks it unverified too). |
| **C. SuperWoW** | `UNIT_CASTEVENT` (caster GUID, target GUID, kind START / CAST / FAIL / CHANNEL / MAINHAND / OFFHAND, spell id, duration), GUID as the second return of `UnitExists`, `SpellInfo(id)`, GUID-as-unit-token in `Unit*` calls, `RAW_COMBATLOG` (log text with GUIDs; **R**, check it exists in this build), pet owner appended to names as `Name (Owner)` (ShaguDPS handles this in `ScanName`). | Installed. pfUI already wraps it (`modules\superwow.lua`). Use as GUID/spell-id fallback and as the cast-start source when nampower casts are off. |
| **D. ClassicAPI** | `C_UnitAuras.GetUnitAuras(unit)` with expiration time and source GUID, `C_Spell.GetSpellTexture`, `C_NamePlate`, `C_LossOfControl` (see `docs/API.md` of brues-code/ClassicAPI; OctoBG notes list what is verified). | Optional (detect `C_UnitAuras`). |
| **E. UNIT_AURA / aura APIs** | `UnitBuff` / `UnitDebuff` (32 buffs, 16 debuffs visible); nampower `GetUnitField(unit, "aura")` = 48 raw slots with spell ids. | Needs a unit token or GUID the client knows; no caster info except via D or aura-cast events. |
| **F. Plain game APIs** | `UnitAffectingCombat`, `UnitHealth/Max` for group units, `GetNumRaidMembers`, `UnitClass`, `GetTime`, `GetRealZoneText`, `IsInInstance` (return values on this server unverified), `GetInstanceInfo` absent in 1.12 | |
| **G. Addon messages** | `SendAddonMessage` to RAID / PARTY: threat protocol, optional meter sync between pfUI Octo users | Server may rate limit; OctoBG throttles at 500 B/s. |

Rule of thumb for the design: **nampower events are the primary feed** (GUIDs, spell ids, no string parsing, no locale),
**combat-log strings are the fallback** (client without nampower, and the only source for things nampower
has no event for, such as interrupts and absorb amounts), SuperWoW fills gaps. Everything funnels
through one `Feed()` that takes `(time, kind, srcGuid|name, dstGuid|name, spellId|name, amount, flags)`
so sources can be swapped without touching the data model (section 4).

### 2.2 Feature by feature

Argument layouts: **V** from `Spy\SpyNampower.lua` / `OctoBG\CLAUDE.md`, **R** recalled. Where it says
"log string" the GlobalString name is the one to take from `GlobalStrings.lua` of the client (patch-3).

| # | Feature | Verdict | Data source and what is missing |
|---|---|---|---|
| 1 | **Damage done** (melee, spells, DoTs, shields, pets) | **available** | nampower: `AUTO_ATTACK_*` (attacker, target, dmg, hitInfo, victimState, parts, blocked, absorb, resist; **V** OctoBG), `SPELL_DAMAGE_EVENT_*` (target, caster, spellId, amount, "absorb,block,resist", hitInfo, school, "eff1,eff2,eff3,auraType"; **V**; auraType 3 / 53 / 89 = periodic), `DAMAGE_SHIELD_*` (shield owner, attacker, damage; **V**), `ENVIRONMENTAL_DMG_*` (unit, type, damage; **V**). Fallback: `CHAT_MSG_COMBAT_*_HITS`, `CHAT_MSG_SPELL_*_DAMAGE`, `PERIODIC_*_DAMAGE` as in ShaguDPS. Pets: map pet GUID to owner via `UnitName("pet")`/GUID tokens (`raidpetN`), SuperWoW `Name (Owner)` suffix. |
| 2 | **DPS** (per second) | **available** | Computed: value / combat time. Two denominators like Details!: raid time (segment length) and **activity time** (item 14). |
| 3 | **Damage taken**, by source, by spell | **available** | Same events as 1, aggregated by target. Includes mitigated parts: `blocked`, `absorb`, `resist` fields. |
| 4 | **Friendly fire** | **available** | Damage events where source and target are both group members (GUID in roster). Needs the roster map `guid -> player`. |
| 5 | **Enemies** (damage done to / from each mob, "Enemy damage taken") | **available** | Aggregate by target GUID/name (mob). Mob names from `UnitName(guid)` (SuperWoW GUID tokens) else from log strings. Voidzone damage = damage from a creature source whose name matches a list: **partial** (no list shipped; user-curated). |
| 6 | **Damage done by spell (all sources)**, **damage done on <target>** | **available** | Pure aggregation of the spell tables. |
| 7 | **Healing done / HPS / healing taken** | **available** | nampower `SPELL_HEAL_BY_*` (target, caster, spellId, amount, crit, periodic; needs `NP_EnableSpellHealEvents`; **V** layout from OctoBG; for self also `SPELL_HEAL_ON_SELF`). Fallback strings `HEALED*`, `PERIODICAURAHEAL*` (ShaguDPS). |
| 8 | **Overhealing / effective healing** | **partial** | The heal event's `amount` is, as far as known, the gross amount (not verified; OctoBG's overheal estimate "UNIT_HEALTH vs heal event order" is also unverified). Effective = min(amount, maxHP - HP before heal), HP before the heal from the last `UNIT_HEALTH_GUID` value (or `UnitHealth(unit)` for group tokens). Wrong when the health update arrives before the heal event. ShaguDPS does the same with current HP, which is less accurate. Needs an in-game probe: print HP before/after and `amount` on a few heals to learn the order, then pick the formula. Works only for units the client sees with health (group members; not far-away raid targets). |
| 9 | **Absorbs** (damage prevented by shields: PW:S, Ice Barrier, Mana Shield ...) | **partial** | The *victim side* is exact: the "absorb" number in damage events (`SPELL_DAMAGE_EVENT` string field, `AUTO_ATTACK` absorb field) and `SPELL_MISS` missInfo 10 (full absorb). *Attributing it to the shield's caster* needs the active shield on the victim: `AURA_CAST_ON_*` (spellId, caster, target; needs `NP_EnableAuraCastEvents`; **V**) gives who put which absorb spell on whom; the absorbed amount is credited to the caster of the newest absorb aura on that victim that is in a hand-kept absorb-spell list. Not exact with stacked shields or when the aura was cast out of range. Remaining shield amount: **impossible** (not exposed by the 1.12 client). |
| 10 | **Heal prevented / heal on enemy** | **impossible / niche** | Mortal Strike and Wound Poison reduction is not reported as a number. Healing on enemy units is just a heal event with an enemy target, available but low value; skip. |
| 11 | **Resources** (mana restored, rage / energy generated) | **available** | `SPELL_ENERGIZE_BY_*` (target, caster, spellId, powerType, amount, periodic; needs `NP_EnableSpellEnergizeEvents`; **V**). Fallback `POWERGAIN*` strings. Auto-attack rage is not an event: **partial** (UnitMana delta for the player only). |
| 12 | **Interrupts** (who kicked what, with what) | **available** (strings) / **partial** (events) | There is **no `SPELL_INTERRUPT` event** in nampower (checked in `nampower.dll`). Reliable source: the combat-log line `SPELLINTERRUPTSELFOTHER` / `SPELLINTERRUPTOTHEROTHER` / `SPELLINTERRUPTOTHERSELF` ("X interrupts Y's Z"), names only; OctoBG's notes confirm `SPELLINTERRUPTSELFOTHER` exists in this client's GlobalStrings. Event-based cross check: kick spell id seen in `SPELL_GO_*` / `UNIT_CASTEVENT` from a known interrupt spell list (Pummel, Kick, Shield Bash, Earth Shock, Counterspell, Feral Charge..., hand-kept table) and `SPELL_FAILED_OTHER` / `UNIT_CASTEVENT` FAIL on the victim within ~150 ms. Gives GUIDs and spell ids; needs the table. Build both and use the string as the truth, events as enrichment (victim's interrupted spell id). The interrupted spell **name** is in the string. Locked-out school/duration: not reported. |
| 13 | **Dispels / purges** (what was removed, by whom, from whom) | **available** | nampower `SPELL_DISPEL_BY_*` (caster, target, spellId; **V** layout from Spy). The *removed aura's* name: `DISPELLED*` / `AURAREMOVED` log lines (`DISPELLEDSELFOTHER`, `DISPELLEDOTHEROTHER`, `DISPELLEDOTHERSELF` ...), and the preceding `BUFF/DEBUFF_REMOVED_*` at the same timestamp. Failed dispels: `SPELLRESISTED` / `SPELL_MISS` with dispel spell ids (**partial**: only via the resist line). |
| 14 | **Activity time** | **available** | Derived: union of intervals around each action by the actor (gap > 5 s ends an interval, same rule as ShaguDPS `_ctime`, plus cast durations from `SPELL_START/GO` for channelers). |
| 15 | **Casts per player ("all casts")** | **available** | `SPELL_GO_*` / `SPELL_START_*` (nampower; **V** arg2 = spellId, arg3 = casterGuid for `_OTHER` events; the target GUID and flags are further args, **R**), `SPELL_CAST_EVENT` for your own presses, SuperWoW `UNIT_CASTEVENT` as the alternate feed (includes channel starts and swing timers). Counts: casts started, finished (GO), failed (`SPELL_FAILED_*`), interrupted (item 12), delayed (`SPELL_DELAYED_*`), cast time lost. Instants appear as GO only. Range: whatever the client's object list holds, which includes enemy casters far beyond combat-log range (OctoBG sees enemies at 350+ yd) - a real advantage over the log. Filter to group + chosen enemies so it does not drown in trash casts. Spell names/icons via `GetSpellRecField(id, "name")`, `GetSpellIconTexture`. |
| 16 | **Hit / crit / miss / glancing / crushing / block stats per spell** | **available** | Autos: `hitInfo` 0x80 crit, 0x4000 glancing, 0x8000 crushing, 0x10 miss; `victimState` 2 dodge, 3 parry, 5 block, 6 evade, 7 immune, 8 deflect (**V**, OctoBG). Spells: `hitInfo` bit 0x2 crit (**V**), `SPELL_MISS_*` missInfo 1 miss, 2 resist, 3 dodge, 4 parry, 5 block, 6 evade, 7/8 immune, 9 deflect, 10 absorb, 11 reflect (**V**, Spy's table). Partial resists = the resist field. min / max / average from the amounts. Fallback: the "crits" and "resisted" strings. |
| 17 | **Avoidance (dodge / parry / block / miss counts for tanks)** | **available** | The two tables above with the group member as victim. |
| 18 | **Deaths + death log** | **available** (deaths) / **partial** (HP trail) | Death moment: `UNIT_DIED` (guid, from the server's death record, real deaths not Feign; **V**), fallback `UNITDIESSELF`/`UNITDIESOTHER` strings and `PLAYER_DEAD`. Death log = per-player ring buffer of the last ~10 s / 15 events (damage taken, heals received, aura changes) stamped with the time; HP at each step is **partial**: group members' HP from `UNIT_HEALTH_GUID` or `UnitHealth(token)`; raid members beyond the object list have none. Overkill = last hit minus HP just before. Killing blow = last damage event. Needs the buffer to run for **all** group members all the time (cheap, a ring of 15 small tables per player). |
| 19 | **Resurrections** | **available** | `SPELL_GO` of resurrection ids (hand-kept: Resurrection, Redemption, Ancestral Spirit, Rebirth, Soulstone Resurrection) plus a `UNIT_DIED` -> alive transition; fallback `RESURRECT*` strings. |
| 20 | **CC done** (what was crowd-controlled, by whom, how long) | **partial** | `AURA_CAST_ON_OTHER` (spellId, caster, target) + `DEBUFF_ADDED_OTHER` / `DEBUFF_REMOVED_OTHER` (guid, luaSlot, spellId, stacks...; **V**) for spell ids in a hand-kept CC table (Polymorph, Sap, Fear, Hibernate, Hammer of Justice, Shackle, Banish, Seduction ...). Duration = removal time minus add time. Needs the table (OctoBG's `data\` has DR / CC style tables to start from: `OctoBG.CDData`). Breaks of heavy stuns on bosses: skip. |
| 21 | **CC breaks** (who broke it, with what) | **partial** | The game never says who broke a CC. Heuristic: the CC aura on target T is removed (`DEBUFF_REMOVED_*`) within ~200 ms of a damage event on T (`SPELL_DAMAGE_EVENT` / `AUTO_ATTACK`); credit the damage source (retail Details! does the same with its own combat log). False positives when the CC just ended. Mark "probable". |
| 22 | **Buff uptime / debuff uptime** (your debuffs on bosses, raid buffs, flasks) | **available** (own units) / **partial** (everyone) | Buffs: `BUFF_ADDED/REMOVED_*` (guid, luaSlot, spellId, stacks, level, rawSlot, state; **V**) for any unit in the object list; `UNIT_AURA_GUID`; `GetUnitField(unit, "aura")` snapshot at pull (48 slots) to catch auras already up; `UnitBuff` for group tokens. Debuff uptime on a boss: `DEBUFF_ADDED/REMOVED_*` on the boss GUID. Caster attribution (whose Sunder Armor): `AURA_CAST_ON_*` or ClassicAPI `sourceGUID`. Limit: the 16 visible debuff slots on the target (the server can have more than 16 on a boss and the extras are hidden, so counts for the 17th+ debuff are missing). |
| 23 | **Cooldowns used** | **available** | `SPELL_GO_*` of ids in a defensive / raid CD table (Shield Wall, Last Stand, Lay on Hands, Power Infusion ...). Table shared with OctoBG cooldown data. |
| 24 | **Per-spell and per-target breakdowns** | **available** | Pure data model (section 4). |
| 25 | **Segments** (current, overall, per fight, boss, trash merge) | **available** | `PLAYER_REGEN_DISABLED/ENABLED` plus group combat check (ShaguDPS `combat()` in `parser.lua` polls `UnitAffectingCombat` on all group units every second; keep that). Boss detection: `UnitClassification(unit)=="worldboss"`/skull level -1 on the first hostile target, plus kill record by `UNIT_DIED` of a boss GUID (**partial**: 1.12 has no `ENCOUNTER_START`, there is no boss list; use a user-extendable list). Segment name = first enemy with most damage taken. |
| 26 | **Reports to chat** | **available** | `SendChatMessage` to say / party / raid / guild / whisper / channel; one line per row, max ~255 chars, throttle 1 line/0.1 s (pfUI/OctoBG `U.SendBG` pattern). |
| 27 | **Window UX** (multiple windows, tabs, tooltips, drill-down) | **available** | Pure UI. 1.12 constraints from OctoBG notes: no `GetStringHeight`, SetMovable windows, frame levels explicit, `OnUpdate` throttling. |
| 28 | **Saved fights / history after reload** | **available** | SavedVariables. Keep last ~15 segments compact (numbers only), purge detail tables above a size. |
| 29 | **Sync between users** (Recount network, Details! raid sync) | **partial** | `SendAddonMessage` works (OctoBG Spy channel is proven for BG; RAID untested for this). Only needed for range gaps; **not in v1**. |
| 30 | **Threat** | **partial** (server must answer) | Section 3. |
| 31 | **Healing received / taken from healers** | **available** | Aggregation of item 7 by target. |
| 32 | **Time line / charts (DPS over time)** | **available** | Store one bucket per second per actor for the active segment only (damage, healing); charts are UI. Later release. |
| 33 | **Avoidable damage ("fails")** | **partial** | Needs a boss-ability list; the user enters spell ids. Later. |
| 34 | **Item usage (consumables, flasks), mana potion / trinket use** | **available** | `SPELL_GO` with item id (arg1 = itemId on cast events, **R**) - low priority. |
| 35 | **Spell power / stats snapshots at cast time (Details! "Spell Details")** | **impossible** for others | Only your own stats via `GetSpellPower` / paperdoll; no inspect of everyone's live stats. |
| 36 | **Absorb remaining / shield value, mitigation after armour** | **impossible** | Client does not expose it. |
| 37 | **Combat log of players out of range, beyond the 50 yd range** | **partial** | nampower `*_OTHER` events reach as far as the object list; strings do not. Raise range CVars if the client allows (test: `/script SetCVar("CombatLogRangeParty",200)`; ceiling unverified). |
| 38 | **Mana / health graphs of every raider** | **partial** | `UNIT_HEALTH_GUID`, `UNIT_MANA_GUID` for GUIDs in the object list; UnitHealth for tokens. |

### 2.3 Combat-log range limits (what to tell the user)

- Strings: only within the combat-log range CVars (default 50 yd). Players farther away vanish from
  the log. Pets and enemies are subject to the Hostile / Creature CVars. The addon should state it in
  its options: "data from players further away than the combat-log range is missing" and offer a probe
  that tries to raise the CVars (and reports what stuck).
- nampower events: the client generates them for units in its object list (server visibility radius,
  OctoBG measured 350-420 yd for players in BGs). Range for friendly raid members in a 40-man is the
  same list, so it should be better than the log - **verify in a raid**: compare `AUTO_ATTACK_OTHER`
  counts with the log lines for a player standing 80 yd away.
- SuperWoW `UNIT_CASTEVENT` follows the same visibility.
- Double counting: if both a string and a nampower event are processed, the same hit is counted twice.
  Decide per session which feed is active (nampower present and the CVars read back as 1 => events
  only; otherwise strings only). Never both for damage / heal / miss. Interrupt strings and death strings
  are the exception (supplement events).

---

## 3. Threat

### 3.1 The server protocol (from `TWThreat\TWThreat.lua` and `OctoBG\modules\Threat.lua`)

Described in words; no TWThreat code is copied. The server (Turtle-WoW lineage, **not verified on
OctoWoW**: TWThreat is disabled on the user's characters and has never run, and OctoBG's Threat module
has no recorded successful answer yet) answers addon messages for threat:

1. **Request.** The client sends an addon message with prefix `TWT_UDTSv4` and text `limit=N` over
   `RAID` (when in a raid) or `PARTY` (in a party). `N` = how many players the server should list
   (TWThreat sends visible bars minus one, OctoBG sends 10). A variant with prefix `TWT_UDTSv4_TM`
   additionally asks for the tank-mode tail (below). The server evaluates it for the player's
   **current target**, so a target switch changes the answer; a reply for a non-hostile or
   out-of-combat target is empty.
2. **Cadence.** TWThreat asks every 0.5 s while any of its features is on, the player is in a group
   and the target is in combat. OctoBG does the same and skips a request for 0.45 s after any answer
   (so a second addon's answer feeds both). That is the protocol's polling rate; there is no push.
   Group required: alone the server sends nothing.
3. **Reply.** A `CHAT_MSG_ADDON` event; the payload text (`arg2`, not `arg1`, which is the prefix field)
   contains the marker `TWTv4=` followed by entries separated by `;`, each entry
   `name:tank:threat:perc:melee` (more fields may follow; TWThreat passes a sixth through when relaying):
   - `name` - player name (pets appear as their own name, the server decides),
   - `tank` - `1` for the player who currently holds aggro, else `0`,
   - `threat` - raw threat value (integer; can be negative in theory, OctoBG's pattern allows `-`),
   - `perc` - the player's threat as a percentage of the tank's (the server computes it; OctoBG treats it as
     "percent of the holder", and takes 100 for the holder),
   - `melee` - `1` if the player is in melee range of the mob (decides 110 % vs 130 % to pull).
4. **Tank-mode tail.** If the message contains `#` followed by `TMTv1=`, the part after `#` is a second
   record list `creature:guid:name:perc` joined by `;`: for each mob that the player's group is fighting,
   the mob's name, its GUID (kept as a string), who it targets, and the player's threat percent on it.
   Used for the "tank view": which of many mobs are on you or about to leave you. The server only
   includes this in `_TM` mode. OctoBG currently drops it.
5. **Derived values (client side).**
   - *Pull-aggro line*: holder's threat x 1.1 if you are in melee, x 1.3 if ranged (the standard classic
     rule; both addons use it). TWThreat shows this as an extra row "-Pull Aggro at-".
   - *TPS*: threat per second = averaged delta of the player's threat values over the last 10 s (the
     client keeps `time -> threat` history from each reply; TWThreat uses 1 s buckets from `time()`).
   - GUID repair: mob GUIDs come as the **low part only** from some server messages; TWThreat maps those
     low ids back to full GUIDs through SuperWoW's `UNIT_MODEL_CHANGED` event. Needed only for tank mode.
6. **Failure handling.** If the server never answers: stop after N tries (OctoBG: 20) and show
   "this server sent no threat data" until the next zone change. The meter must say so plainly in its
   UI, because the TWT protocol may not exist on OctoWoW.

### 3.2 What a "Tiny Threat" style set of views could show

Details!'s Tiny Threat plugin: a small bar list for the current target with your threat, the tank's,
and the gap; colours by danger; "pull aggro" marker. Using only the reply above:

| View | Data | Notes |
|---|---|---|
| Threat list (bars, top N) | Name, class colour, raw threat, % of tank, TPS | Rows = reply entries sorted by `threat`; "You" pinned |
| Aggro line | Pull-aggro threshold row at 110 / 130 % of the holder | Needs the melee flag from the reply |
| Own gauge | Your threat as % of the pull line, big number, colour ramp | Same as OctoBG's label, but in the meter window |
| Danger alert | Flash / sound when above X % of pull line, once when you pull | Reuse OctoBG's thresholds idea (cap by `ref`-th player) |
| Tank view | Top 3 mobs by threat %, who they target, "loose mob" warning | Needs the `_TM` tail |
| Threat on target frame | % text on target frame/nameplate (pfUI nameplates already colour by aggro state) | Not from this server data alone: nameplate colours come from pfUI's own logic |
| Threat history chart | Your threat and the tank's over the last 30 s | From stored replies; a line chart in the window |
| Per-fight threat summary | End-of-fight peak threat / TPS per player | Store the last reply of each target per segment |
| Threat per mob | Tab per target GUID (current, focus, mouseover) | The server answers only for the current target; one tab = one target at a time. Switch cost = a new request |

**Impossible without server data:** threat of players not in your group; threat for a target you do not
have selected; threat on mobs while solo. A pure client-side estimate (damage + heal x modifiers) is
possible, but needs spell-by-spell threat rules (class talents, stances); not planned (see priorities).

Fallback if the server does not answer: offer a client estimate in v2 (damage done = 1 threat, healing
half, tank stance multipliers) labelled "estimate". Not v1.

---

## 4. Data model and release plan

### 4.1 Model

One feed, three levels. All tables are plain Lua tables, numbers only (no string keys per hit), so a
40-man raid for 15 minutes stays small.

```
meters = {
  actors  = { [guid or name] = Actor },       -- persistent across segments in a session
  segments = {                                  -- ordered, newest last
    current   = Segment,
    overall   = Segment,
    history   = { Segment, ... }                -- last N fights, each has name, start, duration, boss flag
  },
  roster  = { [guid] = actorKey },              -- group members, pets -> owner map
  spells  = { [id] = { name, icon, school } },  -- cache, filled lazily from GetSpellRecField
}

Segment = {
  name, zone, start, stop, active_time,         -- seconds
  actors = { [actorKey] = SegActor },           -- only actors with data in this segment
  deaths = { Death, ... },                      -- ordered
  enemies = { [mobKey] = { name, guid, damage_taken, damage_done } },
}

SegActor = {                                    -- one actor in one segment
  damage      = Totals, healing = Totals, taken = Totals, healtaken = Totals,
  power       = { [powerType] = n },
  active      = n,                              -- activity seconds
  interrupts  = { count, [victimSpell] = n, [kickSpell] = n, targets = {[mobKey]=n} },
  dispels     = { count, [auraId] = n, [spellId] = n },
  cc          = { done = {...}, broken = {...} },
  casts       = { [spellId] = { start, go, failed, interrupted } },
  auras       = { [spellId] = { up = secs, applied = n, since = t } },
  deaths      = n, resses = n, cooldowns = { [spellId] = n },
  avoid       = { dodge, parry, block, miss, absorb },  -- as victim
}

Totals = {                                      -- damage, healing, taken, ...
  total, effective, overkill/overheal, absorbed, blocked, resisted,
  hits, crits, misses, glancing, crushing,
  spells  = { [spellKey] = SpellStat },         -- spellKey = spell id, or name when no id (string feed)
  targets = { [actorOrMobKey] = { total, spells = { [spellKey] = n } } },
  pets    = { [petKey] = n },                   -- merged pet damage by pet
}

SpellStat = { total, hits, crits, misses, glancing, crushing, blocked, resisted, absorbed,
              min, max, ticks, critTotal }

Death = { time, actor, killer, spell, overkill,
          events = ring of { t, kind, src, spell, amount, hpAfter, crit } }  -- 15 events, 10 s
```

Rules:
- Pets are keyed by their own GUID but belong to an owner (`roster`); views merge them into the owner and
  list the pet as a sub-row. Merge toggle as in ShaguDPS (`merge_pets`).
- Keys use GUID when available (nampower), else name (strings). On a GUID's first appearance, resolve its
  name with `UnitName(guid)` once and cache.
- `overall` is updated at event time alongside `current` (no merge at the end), as ShaguDPS does with the
  two segments; closing a fight copies the compact `current` to `history` and starts a fresh one on the next
  action by a group member.
- Views are *pure functions* of a segment: `view.Rows(segment, mode)` returns sorted rows (name, value, per-second,
  percent, class, icon, tooltip builder); the UI never touches the raw tables. Drill-down is a view over a
  single `SegActor` with a different row builder (spells / targets / breakdown).
- Memory guards: ring buffers for deaths, max 15 history segments, enemies capped at 80 per segment (trash
  merges into "Other"), spell cache keyed by id.
- Combat time: segment active window from the first group action to the last action + 2 s (or
  `PLAYER_REGEN_ENABLED` for everyone). DPS per actor uses their activity seconds (the second figure, as
  in Details! "active time").

### 4.2 Feed layer

```
Feed.Damage(t, srcKey, dstKey, spell, amount, school, flags{crit,glance,crush,periodic}, absorbed, blocked, resisted)
Feed.Miss(t, srcKey, dstKey, spell, missType)
Feed.Heal(t, srcKey, dstKey, spell, amount, crit, periodic)         -- overheal computed in the model
Feed.Energize / Feed.Cast(kind) / Feed.Aura(guid, spell, add|remove, srcKey?) / Feed.Dispel / Feed.Interrupt / Feed.Death / Feed.Res
```

Adapters: `nampower` (events), `chatlog` (GlobalStrings patterns; start from ShaguDPS's `sanitize` /
`cfind` approach and add the strings listed in section 2.2), `superwow` (UNIT_CASTEVENT, GUID tokens).
Adapter selection at login and on `/pfmeter probe` which prints what each source delivered, so the user
can tell whether nampower really supplies other players' events.

### 4.3 Priority list

**Release 1 (first meter release): "the numbers are right and the basics are complete"**
1. Feed layer, nampower adapter and string fallback, group combat/segment detection, pets merged, overall + current.
2. Windows: damage done, DPS, damage taken, healing, HPS, overhealing (with the HP-order probe done first),
   absorbs victim-side, interrupts, dispels, deaths. One window, mode picker, segment picker, bar tooltips, reports.
3. Per-spell and per-target drill-down for every mode, with hit / crit / miss / glancing / min / max / avg.
4. Death log with last 10 s of events and heal markers (HP trail only where known).
5. Activity time and DPS on activity time.
6. Casts per player (counts by spell, incl. enemies' casts of the current target) - this is what the user
   asked for by name ("all casts") and the data is already in the feed.
7. Threat window: request / reply / bars / pull line / own gauge / alert / "no data from server" message.
   Replace TWThreat and OctoBG Threat's duplicates (OctoBG defers to pfUI).
8. Saved segments across reload (last ~10), reset prompt on instance entry.

**Release 2: depth**
9. Buff / debuff uptime (own, tanks, boss debuffs) and cooldowns used.
10. CC done and probable CC breaks; resurrections; friendly fire; avoidance; enemies view; power gained.
11. Multiple windows (snap, per-window mode and segment), threat tank view (`_TM` tail), threat history chart.
12. Segment naming by boss list, trash merge.

**Release 3: polish**
13. Absorbs attributed to shield casters, avoidable damage list, voidzones, consumable use.
14. Timeline charts; compare two players; user-curated spell tables (interrupt / CC / CD).
15. Optional sync between pfUI Octo users to cover players out of range.

**Not planned**: threat estimate when the server is silent (until proven needed), healing prevented, shield
remaining, other players' spell power snapshots.

### 4.3b Prior art on 1.12 (from a search-summary screenshot the user pasted, 19 Oct; not checked against the addons)

None of these are installed here. They show what vanilla players already use, so what the Octo meters must beat:
- **ShaguDPS** (github shagu/ShaguDPS, 3.0.1 installed here) - minimal damage / heal only, locale-independent
  log parsing, no SuperWoW / nampower. Repo is **archived** (read-only since 1 Jun 2026), 122 commits, no
  releases, and **no licence file** (the installed folder has none either), unlike pfUI itself (MIT).
  So: use its *approach* (pattern sanitising, capture-index handling), write our own parser, and do not paste
  its files into pfUI. The Octo meters have nothing to wait for from upstream.
- **Caw DPS Meter** - damage, healing, utility and aura uptime in one window; reads SuperWoW's raw combat log
  and syncs data between players. Supports the plan: `RAW_COMBATLOG` (GUIDs in the log text) is a real
  source on SuperWoW clients, and sync is what other meters do for out-of-range players. Probe 5 below
  must confirm the event exists in this build (the only mention of it on this PC is a commented line in
  `WhoDidIt\Chronicle\debug.lua`, so it is not yet proven here).
- **DPSMate** (github tdymel/DPSMate, 1.12.1, 852 commits, 97 stars, 70 open issues; the repo page shows no
  last-commit date, so "newer than ShaguDPS" is not confirmed - it is simply the fuller one and not archived
  as far as the page says). Its README module list is the best vanilla feature checklist and is a subset of
  section 2.2: damage done / taken, healing, effective healing, overhealing, absorbs, healing taken, threat,
  interrupts (incl. stuns and silences), deaths, buffs gained / lost / uptime, dispels (decurse, cure
  disease / poison, lift magic as separate modules), CC breaker, compare mode, casts, procs, failed
  actions, friendly fire, total / current / previous segments, report, multiple resizable frames, and
  "synchronizing, to guarantee accurate data". Two new items for the spec: **procs** (aura gained from a
  weapon / talent proc, from `BUFF_ADDED_*` with proc spell ids - available) and **failed actions**
  (`SPELL_FAILED_*`, already counted under casts). It reads the combat log (install step: raise the
  `CombatLogRange` settings in config.wtf, which confirms the string source is range-limited as in 2.3).
  Licence **GPL-3.0**: incompatible with pfUI's MIT for copying code; read it for ideas only, copy nothing.
  Lesson: keep per-hit tables out of the model (numbers only, ring buffers), as section 4.1 says.
- **GreedMeter** - combined damage + threat window; matches the plan of one window with a threat mode.
- **SW_Stats** - the old vanilla-era meter; log-string based.
- Raid logging services (LegacyLogs, Realmplayers) read the game's own log file, not a meter; out of scope.

### 4.4 Things to verify in game before coding (probe list)

1. Does `AUTO_ATTACK_OTHER` / `SPELL_DAMAGE_EVENT_OTHER` fire for **party/raid members and their pets**, and how far?
2. Heal event `amount`: gross or effective; ordering of `UNIT_HEALTH_GUID` vs `SPELL_HEAL_BY_*`.
3. Do the `*_OTHER` events run in parallel with the log strings (double counting)? Which CVars read back as 1?
4. Does the server answer `TWT_UDTSv4` at all on OctoWoW; what do `perc` and `melee` look like; does `_TM` give the tail?
5. Are `SPELLINTERRUPT*` / `DISPELLED*` / `UNITDIES*` GlobalStrings present with the same arg order as the TBC set; exact `RAW_COMBATLOG` support in this SuperWoW.
6. Range CVar ceiling for the combat log; what `IsInInstance()` returns here.
7. `SPELL_START/GO_*` argument tail (target GUID, flags, itemId) - one probe printing all `argN`.

Everything above rated **available** depends on probe 1 working; if it fails for other players, the string
adapter keeps items 1-7, 13, 16-19 working at the combat-log range and the model does not change.
