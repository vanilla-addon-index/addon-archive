# pfUI Octo nameplates: design spec (Plater for 1.12)

Written 21 Oct 2026. User (20 Oct): "https://www.curseforge.com/wow/addons/plater-nameplates - I want
to implement our own version of this name plate addon into our PFUI with all features and art work".
Target: 1.12.1 build 5875 (OctoWoW), Lua 5.0, pfUI `octo` branch.

## 0. Licence: why nothing of Plater is copied

Plater (Tercio / Team Details!) is **All Rights Reserved** on CurseForge ("All Rights Reserved unless
otherwise explicitly stated", project licence tab, read 21 Oct 2026). Its GitHub repo
(Tercioo/Plater-Nameplates) has no licence file (`"license": null` from the GitHub API). So, as with
TWThreat, **no Plater code and no Plater texture is copied**. Its features are rebuilt from scratch on
pfUI's nameplates, and the artwork is our own, drawn by `tools\MakePlateArt.ps1` (same approach as
the minimap masks), plus the game's own textures. Plater's fonts are not needed: pfUI Octo already
ships Expressway and the Octo fonts (Roboto, Fira...).

Reference: the user gave Plater v661 (`Downloads\Plater-v661.zip`, 21 Oct 2026). Only its setting
names and default colours were read, as a feature checklist (Plater_DefaultSettings.lua: about 80
aura settings, 37 extra-indicator, 45 cast / cast bar, 18 indicator, 13 range, 12 auto-toggle, 15
boss mod). Its DPS colours agree with ours: aggro red, `noaggro` / `notontank` blue-purple
(.5, .5, 1), pulling yellow-orange; tanks also get `pulling_from_tank` (a tank taking it from another
tank) - phase 3.

## 1. Plater's features, mapped to this client

Plater's options tabs (from its long-standing public feature set: General, Threat & Aggro, Target,
Cast Bar, Level & Strata, Personal Bar, Buff Settings / Tracking / Special, Ghost Auras, Enemy NPC,
Enemy Player, Friendly NPC, Friendly Player, Colors, Npc Colors & Names, Cast Colors & Names,
Scripting, Modding, Profiles, Auto, Animations, Search). The CurseForge description only adds: 500+
settings, aggro colours that flip for tanks, smaller plates out of combat, quest colouring, Lua
scripts and mods with their own options, wago.io updates.

Data on this client: SuperWoW (installed) gives each plate's GUID (`plate:GetName(1)`) and lets every
`Unit*` call take that GUID (health, target of the mob, buffs, debuffs; pfUI's libcast fills
`UnitCastingInfo(guid)` from SuperWoW's cast events). UnitXP_SP3 (installed) gives
`UnitXP("distanceBetween", "player", guid)` (yards) and `UnitXP("inSight", "player", guid)` (boolean) -
both used on GUIDs by Cursive here. ClassicAPI gives `C_UnitAuras.GetUnitAuras(unit)` with expiry
times. Server threat for the current target: pfUI Octo's `pfUI.meters.threat.list` (TWT protocol).

| Plater feature | Here | Phase |
|---|---|---|
| Bar textures, background, border, fonts | available | 1 |
| Sizes per unit kind (enemy NPC / enemy player / friendly NPC / friendly player) | available | 1 |
| Smaller out of combat, bigger target, smooth resize | available (frame scale) | 1 |
| Aggro colours, flipped for tanks; "pulling aggro" colour; off-tank colour | available: mob's target via GUID; pulling only on your target (server threat) | 1 |
| Aggro glow around the plate | available | 1 |
| Target indicator styles, target glow, mouseover highlight, non-target alpha | available | 1 |
| Health text formats, health % | available (pfUI) | 1 |
| Execute range (colour + marker below N %) | available | 1 |
| Cast bar: colours for cast / channel / done / interrupted, spark, icon, name, timer, fade | available | 1 |
| "Interrupted by NAME" on the cast bar | available (combat log "X interrupts Y's Z") | 1 |
| Range alpha (out of range plates fade), line of sight | available with UnitXP | 1 |
| Elite / rare / boss icons | available | 1 |
| One "Nameplates" options section in OctoBG's look (replaces pfUI's page) | available | 1 |
| Buff and debuff rows: size, rows, growth, timers, stacks, borders by type | available (SuperWoW auras on GUID) | 2 |
| Automatic tracking: your debuffs, CC, enemy important buffs, dispellable buffs | available; durations from libdebuff / ClassicAPI | 2 |
| Special auras (big icons for chosen spells), manual lists | available | 2 |
| Ghost auras (your missing debuffs shown faded on combat targets) | available | 2 |
| NPC colours and renames | available by name; NPC id from GUID unverified | 3 |
| Cast colours and renames per spell | available | 3 |
| Quest units (colour + icon) | partial: tooltip scan of quest objectives | 3 |
| Class / pet / totem icons, friendly "name only" mode, big actor title | available | 3 |
| Auto tab (friendly plates on in dungeons, off in cities, enemy plates in combat) | available (ShowNameplates / ShowFriendNameplates) | 3 |
| Personal bar and resources under your character | partial: no own nameplate on 1.12; a fixed frame instead | 3 |
| Animations (shake / pop on big hits) | available (combat log + frame offsets) | 4 |
| Scripts and mods with their own options | available (sandboxed Lua per plate event) | 4 |
| Profiles, import / export | pfUI's profile strings already carry C.plates | 1 |
| wago.io / WeakAuras-Companion updates | impossible (no web access in 1.12) | - |
| Absorb / heal prediction bars, interruptible-shield on cast bar, spec icons | impossible (no data on 1.12) | - |
| Boss mod timers on plates | skipped (no BigWigs plate API here) | - |

## 2. Architecture

- `modules/plates.lua`, module "plates", loaded right after "nameplates". It wraps
  `pfUI.nameplates` (OnCreate / OnConfigChange / OnDataChanged / OnUpdate are looked up on the
  table each call, so wrapping them before the first plate exists covers every plate). pfUI's file
  stays as upstream. Our parts live in `nameplate.octo` (indicators, glow, spark, icons).
- Settings `C.plates` (pfUI strings, "1" / "0"), defaults in api/config.lua, so profile strings
  carry them. pfUI's own `C.nameplates` keys keep working and are shown on our pages.
- `modules/plates-options.lua`: the "Nameplates" section in OctoBG's look (O:AddPage), with every
  pfUI nameplate setting plus ours; pfUI's own "Nameplates" category is hidden from the topic list
  (`O.replaced`), as combat text's was.
- Art: `tools\MakePlateArt.ps1` -> `img\plates\*.tga` (white, tinted in game).

## 3. Phase 1 (this release)

Art (all 32-bit TGA, white + alpha, drawn with 4 x 4 samples):
`bar-flat, bar-soft, bar-gloss, bar-glass, bar-split` (256 x 32 bar fills), `arrow` (64, points
right; mirrored by tex coords), `chevron` (double arrow, 64), `corner` (32, an L; turned for the four
corners), `underglow` (256 x 64 soft light under the bar), `spark` (32 x 64), `star` (32, elite /
rare), `skull` (32, boss), `tick` (8 x 32, execute marker).

Behaviour:
- Look: bar texture (ours + pfUI's list), background colour and alpha, border colour, name font and
  size, health text font size.
- Size: per kind (enemy NPC, enemy player, friendly NPC, friendly player) as % of pfUI's width /
  height, out-of-combat %, target %; done with the overlay's scale and eased over 0.15 s.
- Threat: role auto (warrior in Defensive Stance, druid in bear form, paladin with Righteous Fury)
  / tank / damage. States, from the mob's target (GUID.."target") and, for your target, the server's
  threat list:
  - damage / healer: `aggro` (attacking you, red), `pulling` (you are at >= N % of the tank,
    orange), `safe` (attacking someone else: blue-purple, or the normal colour - pfUI's normal
    enemy colour is red, which would look like aggro);
  - tank: `aggro` (attacking you, blue-green), `losing` (someone else >= N % of you, orange),
    `offtank` (attacking another tank, purple), `lost` (attacking a non-tank, red);
  - only while you and the mob are in combat. Tanks = pfUI's raid tank roles + its off-tank list.
  - aggro glow (pfUI's img:glow edge) on `aggro` (damage) / `lost` (tank), optional.
- Target: indicator none / arrows / chevrons / corners / underglow, colour (accent by default),
  mouseover highlight on the bar.
- Execute: auto (warrior, paladin) / on / off at N % (20): bar colour and a marker on the bar.
- Cast bar, Plater layout (icon left of the bar, spell name left, time right, spark, fade out) or
  pfUI's layout. Colours: cast, channel, finished, interrupted. "Interrupted by NAME" for 1 s from
  SPELLINTERRUPTSELFOTHER / SPELLINTERRUPTOTHEROTHER lines, matched to the plate by name.
- Range: plates of units further than N yards (UnitXP) fade to an alpha; units out of line of sight
  fade too (option). Checked every 0.2 s per plate. Without UnitXP: off.
- Elite / rare / boss icon left of the name.
- Looks: "Plater look" (130 x 12 bars, health % in the middle, arrows, Plater cast bar), "Slim" and
  "pfUI look" buttons (`pfUI.plates.ApplyPreset`); the Plater look is applied once on first load
  (`C.plates.firstlook`). `docs\plates-preview.png` is a drawing of it from the real textures.

Not verified in game (all of phase 1): every look, the scale easing with pfUI's click area, the
threat states, UnitXP on plate GUIDs, the interrupt lines' wording on this server.

## 4. Phase 2: auras (done 21 Oct 2026, not seen in game)

`modules/plates-auras.lua` (`pfUI.plates.Auras`), hooked from plates.lua (Configure / Update /
Tick / Off). While `C.plates.auras` is on, pfUI's own debuff row is skipped (showdebuffs is set to
"0" only for the length of pfUI's OnDataChanged, put back even on an error).
- Data: SuperWoW `UnitDebuff(guid, i)` -> texture, stacks, type, spell id; `UnitBuff(guid, i)` ->
  texture, stacks, spell id; names by `SpellInfo(id)`, else pfUI libdebuff's tooltip scan (only when
  a slot changes, `o.acache`). Your own debuffs' timers and "mine" from libdebuff.objects (no scan).
  ClassicAPI `C_UnitAuras.GetUnitAuras(unit, "HARMFUL" / "HELPFUL")` end times and sourceGUID when
  it returns them - field names assumed retail-like, NOT verified.
- Row above the name: debuffs (yours / yours + crowd control (default) / all, pfUI's black / white
  list), then enemy buffs (important (default) / all / none); order yours, CC, other debuffs,
  important buffs. Icons 20 x 16 (cropped), rows of N, 1-3 rows, grow middle / left / right; timer
  (minutes, whole seconds, tenths under 3 s in red), stacks, edge by debuff type, important buffs gold.
- Special auras: names list -> big icons (28) on top, accent edge (default: main CC and immunities).
- Ghost auras: your listed debuffs missing on a mob fighting you, desaturated, icons from your
  spellbook; a button fills the list with your class's usual ones. Off by default.
- Preview: the target sample shows pretend auras, the threat sample one of yours plus ghosts;
  "Test on real nameplates" puts pretend auras on every plate too.

## 5. Phase 3: lists, quests, icons, auto (done 21 Oct 2026, not seen in game)

`modules/plates-lists.lua` (`pfUI.plates.Lists`), hooked from plates.lua.
- NPC colours and names (`C.plates.npclist`) and cast colours and spell names (`castlist`): strings
  "Name|r,g,b|New name#..." so profile strings carry them. Bar colour order: execute, threat, NPC
  colour (wins over threat with `npcoverthreat`), quest colour (`questbar`), pfUI's own.
  Options page "Colours and names": an editor per list (name, colour, new name, Use my target /
  No colour / Save / Remove) and the list below it.
- Quest marks right of the name: pfQuest's `pfMap.tooltips[name][quest][map].QTYPE`
  (UNIT_OBJECTIVE / _ITEMREQ / ITEM_OBJECTIVE_LOOT = objective diamond, NPC_START = "!",
  NPC_END = "?"); without pfQuest, quest log lines "X slain: a/b" not done (QUEST_MONSTERS_KILLED,
  checked in every patch's GlobalStrings.lua).
- Class icon on enemy (default) / friendly players (pfUI's img:classicons), paw on pets
  (UnitPlayerControlled, not a player).
- Auto: enemy plates in / out of combat, friendly plates in cities (list by zone name) / dungeons
  and raids (IsInInstance party / raid) / open world: Leave, On, Off. Runs after pfUI's own
  PLAYER_ENTERING_WORLD show / hide, on zone change and combat start / end.
- Tank state `taking` (Plater's pulling_from_tank): the mob is on another tank and you are at the
  pull %, colour `c_taking`.
- Art: quest-objective, quest-start, quest-end, pet (tools\MakePlateArt.ps1).

## 6. Phase 4: animations and rules (done 23 Oct 2026, not seen in game)

`modules/plates-fx.lua` (`P.Fx`), called from plates.lua's Tick (`P.Fx.Scale` multiplies the eased
size, `P.Fx.Tick` runs last). Animations (C.plates.animcrit / animtarget / animsize): Pop (grow
fast, settle), Bounce (damped wobble), Flash (white over the bar). Your crits are read with the
meters' reader (any language) or English patterns, and play on every plate with that name seen
in the last second (pfUI's plate registry is private, so Fx keeps `Fx.seen`). Rules (Plater's
scripts without code, C.plates.rule1..6: on, when, value, effect, color, size), checked 5 times
a second: when name has / casts / health below % / has debuff (texture or ClassicAPI name) /
is your target; then colour the bar / glow / bigger / smaller / hide. Later rules win. Page
"Animations and rules" (npfx) with the shared preview and "Play on the preview".

## 7. Later phases

3. Lists and indicators (NPC colours, cast colours, quest units, class / pet icons, name-only friends,
   Auto tab, personal bar).
4. Animations, scripts / mods, nameplate-only presets.
