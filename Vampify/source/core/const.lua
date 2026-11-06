-- Vampify -- shared constants and the pinned formula descriptor.
--
-- The formula was MEASURED in-game (a companion telemetry addon's instrumentation, 2026-08-07..09), it is not derived from tooltips
-- or forum lore. It lives in a descriptor rather than inside the arithmetic so that a resolved
-- open question (spec 4.3) is a one-line change here, not a refactor of model.lua.

VampifyConst = {}
local C = VampifyConst

C.VERSION = "0.4.0"

-- Empty a list buffer for reuse. THE table.setn IS THE POINT: in Lua 5.0 table.insert maintains an
-- `n` field, and nil-ing the indices by hand does not reset it -- so the next round of inserts
-- lands BEHIND the stale n, leaving nil holes at 1..n. That crashed the options window
-- ("table.concat: table contains non-strings") on its second refresh and silently grew the tooltip
-- line buffer on every gear scan. One helper, so the trap exists in exactly one place.
function C.resetList(t)
    for i = table.getn(t), 1, -1 do t[i] = nil end
    table.setn(t, 0)
    return t
end

-- Vampirism source spell ids: items are ranks 1-5, enchants are bracer/boots at +1% each.
C.SPELL_IDS = { 45420, 45421, 45422, 45423, 45424, 57146, 57148 }

-- ---- error capture -----------------------------------------------------------------------------
--
-- Two problems, one mechanism. A Lua error in an OnUpdate repeats every frame, which floods the
-- chat and makes the game unpleasant; and the developer only learns about it if the player thinks
-- to mention it. So: every error is written to <WoW>\imports\vampify_errors.txt where tooling
-- can read it, and only the FIRST occurrence of each distinct message reaches the chat. Repeats are
-- counted, not shown.
--
-- Lives here rather than in its own file purely so it loads first, before anything that could
-- throw, without costing a client restart to add a new file to the toc.
--
-- Deliberately chains to the previous handler for that first occurrence: swallowing errors outright
-- would trade a visible problem for an invisible one.

C._errSeen  = {}
C._errOrder = {}
C._errPrev  = nil

local function writeErrors()
    if not ExportFile then return end          -- SuperWoW only; harmless without it
    local lines = {}
    table.insert(lines, "addon=Vampify version=" .. tostring(C.VERSION))
    for i = 1, table.getn(C._errOrder) do
        local m = C._errOrder[i]
        table.insert(lines, "[x" .. tostring(C._errSeen[m]) .. "] " .. m)
    end
    -- ExportFile appends .txt itself -- passing "vampify_errors.txt" would yield a double
    -- extension, which is a known in-game gotcha.
    ExportFile("vampify_errors", table.concat(lines, "\n"))
end

function C.installErrorCapture()
    if C._errInstalled then return end
    C._errInstalled = true
    C._errPrev = geterrorhandler and geterrorhandler() or nil

    seterrorhandler(function(msg)
        local show, write = C.recordError(msg)
        if write then writeErrors() end
        if show and C._errPrev then C._errPrev(msg) end
    end)
end

-- Pure counting half, split out so it can be tested offline: WoW's error handler cannot be, and a
-- bug in the thing that reports bugs is the worst kind. Returns (showInChat, writeToFile).
function C.recordError(msg)
    msg = tostring(msg)
    local firstTime = C._errSeen[msg] == nil
    if firstTime then
        C._errSeen[msg] = 1
        table.insert(C._errOrder, msg)
    else
        C._errSeen[msg] = C._errSeen[msg] + 1
    end
    -- Show it once, then stay quiet: the player has been told, and a per-frame repeat adds nothing
    -- but noise. Write on the first sighting and every 50th repeat, so a runaway loop stays visible
    -- in the file without writing on every single frame.
    local write = firstTime or math.mod(C._errSeen[msg], 50) == 0
    return firstTime, write
end

-- Installed at file scope, not from an event: an error thrown while a later file is still loading
-- would otherwise be missed, and those are exactly the errors worth catching.
if seterrorhandler then C.installErrorCapture() end

-- ---- spells that do NOT trigger Vampirism -------------------------------------------------------
--
-- Damage shields were MEASURED not to trigger (Thorns 236 triggers, Thorium Shield Spike 27 -- zero
-- healing from either). Excluding the DAMAGE_SHIELD_SELF event is not enough: the client also
-- reports shield procs as ordinary SPELL_DAMAGE_EVENT_SELF, so they slipped in and were credited
-- with healing that never happened (spotted in-game via the per-ability breakdown, which showed
-- Thorium Shield Spike at 12.4%).
--
-- There is no reliable structural signal that marks a proc as a damage shield, so this is a list.
-- It is extendable at runtime with /vf exclude <id> for anything found later, and excluded spells
-- are dropped from BOTH the healing and the damage side -- counting damage that cannot trigger
-- would drag the headline percentage below the truth.

C.NO_TRIGGER = {
    [16624] = "Thorium Shield Spike",   -- id read from the live client 2026-08-10
}

function C.triggersVampirism(spellId)
    if not spellId then return true end                 -- auto attacks always trigger
    if C.NO_TRIGGER[spellId] then return false end
    local cfg = VampifyConfig and VampifyConfig.getChar and VampifyConfig.getChar()
    if cfg and cfg.noTrigger and cfg.noTrigger[spellId] then return false end
    return true
end

-- ---- runtime exclusion management (cfg.noTrigger) -----------------------------------------------
--
-- cfg.noTrigger is the SAME mechanism as NO_TRIGGER above, made runtime-extendable: a new damage
-- shield is only ever found once it shows up wrongly in the breakdown (there is no structural
-- signal, see the comment above), so the list has to grow without a client restart. These three
-- functions are the one place that reads/writes cfg.noTrigger, so core/commands.lua's slash
-- handlers stay thin wiring and the union logic in triggersVampirism above is never duplicated.
--
-- New exclusions apply forward-only: they change what counts as triggering from the moment they
-- are added, but do not reach back into totals already recorded for earlier hits. See the /vf
-- exclude add command in commands.lua for the reasoning (kept there, next to where it is user-
-- visible); /vf reset remains the explicit way to discard a tainted session.

-- Adds spellId to the character-scoped runtime set. Returns false (and changes nothing) if the id
-- is already covered -- either hardcoded or already added -- with a reason string so the caller
-- can tell the player why, rather than silently re-adding.
function C.addNoTrigger(spellId, cfg)
    if C.NO_TRIGGER[spellId] then return false, "builtin" end
    if not cfg then return false, "no-config" end
    if not cfg.noTrigger then cfg.noTrigger = {} end
    if cfg.noTrigger[spellId] then return false, "already" end
    cfg.noTrigger[spellId] = true
    return true
end

-- Removes spellId from the runtime set. The hardcoded list is not reachable through this path --
-- it is measured fact, not a preference -- so this only ever touches cfg.noTrigger.
function C.removeNoTrigger(spellId, cfg)
    if not (cfg and cfg.noTrigger and cfg.noTrigger[spellId]) then return false end
    cfg.noTrigger[spellId] = nil
    return true
end

-- Combined listing for /vf exclude list: hardcoded entries first, then runtime ones, each tagged
-- so the caller can say which is which. `out` is reused like every other list buffer in this addon
-- (see resetList above) so a repeated /vf exclude list stays allocation-free.
function C.listNoTrigger(cfg, out)
    out = out or {}
    C.resetList(out)
    local n = 0
    for id in pairs(C.NO_TRIGGER) do
        n = n + 1
        out[n] = { id = id, builtin = true }
    end
    if cfg and cfg.noTrigger then
        for id in pairs(cfg.noTrigger) do
            n = n + 1
            out[n] = { id = id, builtin = false }
        end
    end
    table.setn(out, n)
    return out
end

-- ---- spell id -> name --------------------------------------------------------------------------
--
-- nampower hands us numeric spell ids; the tooltip has to show something a player recognises. 1.12
-- has no GetSpellInfo, but this client has two independent routes that do work, and the result is
-- cached because a tooltip refresh must not re-resolve on every frame.
--
-- Explicitly NOT tried: GameTooltip:SetHyperlink("spell:<id>"). It is documented broken on
-- 1.12/TurtleWoW -- it fails SILENTLY and leaves the tooltip empty -- so attempting it would cost
-- work per unknown id and yield nothing.
--
-- (Belongs in its own file; it is here so it loads first and needs no toc change, which would cost
-- a client restart. Move it when something else forces a restart anyway.)

C._spellNames = {}
C.spellNameSource = "none"

function C.spellName(id)
    -- -1 is the aggregate's sentinel for auto attacks (VampifyAggregate.MELEE), which have no id.
    if type(id) ~= "number" or id < 0 then return "Melee" end
    local cached = C._spellNames[id]
    if cached then return cached end

    local name

    -- 1. SuperWoW's SpellInfo(spellId). It reads the client's spell DBC by numeric id rather than
    --    walking the spellbook, so it resolves foreign and NPC spells too, not just our own.
    if SpellInfo then
        local ok, n = pcall(SpellInfo, id)
        if ok and type(n) == "string" and n ~= "" then
            name = n
            C.spellNameSource = "SpellInfo"
        end
    end

    -- 2. nampower's own resolver, an independent second route in case SuperWoW is absent.
    if not name and GetSpellNameAndRankForId then
        local ok, n = pcall(GetSpellNameAndRankForId, id)
        if ok and type(n) == "string" and n ~= "" then
            name = n
            C.spellNameSource = "nampower"
        end
    end

    if not name then name = "Spell #" .. id end
    C._spellNames[id] = name
    return name
end

-- ---- spell id -> icon ---------------------------------------------------------------------------
--
-- The UI redesign's per-ability rows want an icon next to the name, not just text. SpellInfo(id)
-- already returns this as its 3rd value (name, rank, texture, minRange, maxRange) -- C.spellName
-- above discards it -- so this is a second thin reader over the SAME SuperWoW call, cached exactly
-- like C.spellName (a tooltip/bar refresh must not re-resolve on every frame), just with its own
-- cache table because the two calls can return a texture where the name lookup failed or vice versa
-- (unlikely, but nothing guarantees the two are correlated) and sharing a cache would only save one
-- pcall while entangling two independently-failing things for no reason.
--
-- Unlike C.spellName, a miss here has no readable-string fallback to manufacture -- "no icon" is a
-- real, displayable answer (the caller substitutes its own placeholder texture), so this returns nil
-- rather than inventing a path that does not exist on disk for a genuine SPELL id.
--
-- A.MELEE (-1) and any non-number id are NOT a SpellInfo lookup at all. Two revisions on
-- this, both 2026-08-24, in order:
--   (1) first: read the equipped main-hand weapon's texture directly (GetInventoryItemTexture) --
--       superseded below;
--   (2) then (this version): WoW's OWN spellbook already carries this mapping. Every character has
--       a base "Attack" entry in their spellbook, and its icon IS the equipped weapon's icon,
--       maintained by the client itself across a weapon swap (confirmed from an in-game spellbook
--       screenshot). Reading it through GetSpellTexture on the "Attack" entry therefore needs no
--       swap-invalidation machinery of its own -- WoW already does that job; see C.meleeIcon below
--       for exactly what is and is not independently confirmed about this here.
C.MELEE_ICON = "Interface\\Icons\\Ability_MeleeDamage"   -- fixed fallback only, see C.meleeIcon

-- The "Attack" entry's SPELLBOOK INDEX, found once by NAME and cached -- an index is class- and
-- level-dependent (talent respecs, new abilities learned into earlier tabs can shift it), so it is
-- never hardcoded, exactly the same reasoning gui/display.lua's own buildSpellbookSet gives for
-- never assuming a fixed spell id. `_attackIndexKnown` distinguishes "not searched yet" (nil, look
-- again) from "searched, genuinely not found" (also nil, but do NOT re-scan every call -- that would
-- turn a one-time cost into a per-frame one for a locale/build where no "Attack" entry exists).
C._attackIndex = nil
C._attackIndexKnown = false

-- Invalidates the cached index -- wired to SPELLS_CHANGED/LEARNED_SPELL_IN_TAB below, the same two
-- events Blizzard's own FrameXML\SpellBookFrame.lua registers in 1.12.1 -- a newly learned ability
-- can insert into an earlier tab and shift every
-- later index, which is exactly the class of change that would silently point this at the wrong
-- spellbook row if never re-checked. Exposed (not local) so an offline test can simulate the event
-- without needing a real WoW event frame.
function C.invalidateAttackIndex()
    C._attackIndex, C._attackIndexKnown = nil, false
end

-- Iterates the spellbook by index from 1, same loop shape as gui/display.lua's buildSpellbookSet
-- (GetSpellName(i, bookType) until nil) -- the established pattern in this codebase for "walk the
-- whole spellbook", not a second invention of it. pcall-wrapped like every other WoW API read in
-- this file: GetSpellName may be absent entirely (offline tests, or a hypothetical client without
-- it) and must degrade to "not found" rather than error.
local function findAttackIndex()
    if not GetSpellName then return nil end
    local bookType = BOOKTYPE_SPELL or "spell"   -- literal fallback matches SpellBookFrame.lua's own
                                                  -- BOOKTYPE_SPELL = "spell" in case load order ever
                                                  -- left the global unset when this runs
    local i = 1
    while true do
        local ok, name = pcall(GetSpellName, i, bookType)
        if not ok or not name then break end
        if name == "Attack" then return i end
        i = i + 1
    end
    return nil
end

-- The "Attack" spellbook entry's current icon. The INDEX is cached (found by name, invalidated on
-- the events above); the TEXTURE itself is read FRESH on every call via GetSpellTexture, which is
-- what carries a weapon swap through without this file needing its own swap-invalidation -- WoW's
-- client is claimed to keep that entry's icon in sync with the equipped weapon on its own (confirmed
-- from an in-game screenshot of the "Attack" spellbook row).
--
-- NOT INDEPENDENTLY VERIFIED HERE: this file (and the FrameXML source it was checked against) can
-- only confirm the API SURFACE -- GetSpellName(i, bookType)/GetSpellTexture(i, bookType), bookType
-- BOOKTYPE_SPELL == "spell", both used exactly this way by Blizzard's own SpellBookFrame.lua. Whether
-- the "Attack" entry's texture is genuinely weapon-linked is a client-side (C++) behavior no Lua
-- source exposes -- that rests on in-game observation and is still open for an in-game
-- double-check (see this feature's own verdict).
--
-- Falls back to C.MELEE_ICON when there is no client API at all (offline tests), no "Attack" entry
-- was found (unknown locale/build), or GetSpellTexture itself returns nothing for it.
function C.meleeIcon()
    if not C._attackIndexKnown then
        C._attackIndex, C._attackIndexKnown = findAttackIndex(), true
    end
    if C._attackIndex and GetSpellTexture then
        local bookType = BOOKTYPE_SPELL or "spell"
        local ok, tex = pcall(GetSpellTexture, C._attackIndex, bookType)
        if ok and type(tex) == "string" and tex ~= "" then return tex end
    end
    return C.MELEE_ICON
end

if CreateFrame then
    local f = CreateFrame("Frame", "VampifyConstSpellbookWatcher")
    f:RegisterEvent("SPELLS_CHANGED")
    f:RegisterEvent("LEARNED_SPELL_IN_TAB")
    f:SetScript("OnEvent", C.invalidateAttackIndex)
end

C._spellIcons = {}

function C.spellIcon(id)
    if type(id) ~= "number" or id < 0 then return C.meleeIcon() end
    local cached = C._spellIcons[id]
    if cached ~= nil then
        if cached == false then return nil end     -- a cached MISS, not "never looked up"
        return cached
    end

    local icon
    if SpellInfo then
        -- pcall-wrapped like C.spellName: SuperWoW may be absent, or SpellInfo may throw for an id
        -- the client's DBC does not know. Either way this must degrade to nil, never propagate an
        -- error into the hot damage/tooltip path.
        local ok, _, _, tex = pcall(SpellInfo, id)
        if ok and type(tex) == "string" and tex ~= "" then icon = tex end
    end

    -- Cache a MISS too (as `false`, distinguishable from "not yet looked up" = nil), so an id that
    -- keeps failing (no SuperWoW, or genuinely no icon) is not re-queried every frame -- the whole
    -- point of caching at all.
    C._spellIcons[id] = icon or false
    return icon
end

function C.errorCount()
    local n = 0
    for _, c in pairs(C._errSeen) do n = n + c end
    return n, table.getn(C._errOrder)
end

C.FORMULA = {
    -- AoE damping. Measured 0.7021 on Flame Wave, independent of the number of targets hit.
    -- An earlier 0.86 estimate was wrong and is retracted.
    aoeFactor  = 0.7,

    -- Per-hit floor equals the NUMBER OF SOURCES (3 items -> min 3 HP, 2 items -> exactly 2.000).
    -- A fixed floor of 3, and no floor at all, are both refuted by measurement.
    floorMode  = "sources",

    -- Settled 2026-08-10 (spec 4a): of 7239 own hits during active Vampirism epochs, 14 carried
    -- mitigation and 9 were decisive after discarding full-health windows -- 7 pointed clearly at
    -- net, one favoured gross by 0.6 HP (noise), one was a full-block window too noisy to count.
    -- The gross error tracked mitigation * sumPercent almost exactly, which is the shape the
    -- mechanism predicts. The server pays Vampirism on damage already reduced by block/absorb/
    -- resist, not on the logged (pre-mitigation) amount.
    damageBase = "net",

    -- Three-valued. "undecided" behaves as "off" and makes the displayed total a LOWER BOUND.
    channels = {
        melee     = "on",         -- measured
        spell     = "on",         -- measured
        aoe       = "on",         -- measured, with aoeFactor
        proc      = "on",         -- measured: Tidal Wave 12/12 windows, 0/36 control
        dmgshield = "off",        -- refuted: Thorns 236 + Thorium Spike 27 triggers -> 0 healing
        dot       = "on",         -- measured 2026-08-10: ticks trigger per tick, no special
                                  -- handling, measured in-game over two Flame Shock sequences.
                                  -- The old "never occurred in a Vampirism epoch" note predated
                                  -- that measurement.
        totempet  = "off",        -- the developer's read from play; undecidable as instrumented
        pvp       = "undecided",  -- no Vampirism-geared BG epoch with own damage
    },
}

-- ---- item proc origins (spell id -> item name) --------------------------------------------------
--
-- C.ORIGINS itself is generated (see the block below) from the server-source
-- item_template + spell_template dump, in two layers: DIRECT spelltrigger_N == 2 ("chance on hit")
-- ids, which appear in the combat log exactly as-is; and CHAIN ids, reached by following item
-- spells at trigger 1 (on-equip proc auras) OR 2 one spell_template effect hop via
-- effectTriggerSpell1/2/3. The chain layer exists because a real proc can sit one hop away from
-- the item: spell 16614 ("Lightning Strike") never appears as an item_template spellid_N at all --
-- only its equip-aura wrapper (spell 16615, trigger==1) does, and 16615's own spell_template
-- effect is what fires 16614. A direct-only lookup would silently miss exactly that case. Plain
-- on-use procs (trigger 0) are still excluded -- they answer "what did this item grant", a
-- different question than a damage-origin lookup needs.
--
-- Nil-safe by construction: returns nil both when spellId has no known item origin AND when the
-- generator has never been run yet (C.ORIGINS absent entirely), so callers never need a separate
-- guard for "table not generated yet" vs. "id not a proc".
function C.itemProcOrigin(spellId)
    if not C.ORIGINS then return nil end
    return C.ORIGINS[spellId]
end

-- BEGIN GENERATED ORIGINS (generated by an offline generator script -- do not edit by hand)
--
-- Generated by an offline generator script. Two sources, unioned, two layers:
--   Pass 1 (item->spell edges): UNION of a live game-database dump of item-to-spell
--   links and a local item_template dump. Conflict rule: for an
--   item entry known to both, the live database wins outright (current server state); the local
--   dump contributes ONLY items the live database does not know at all. See this generator's file
--   header ("TWO SOURCES, UNION not replacement") for the full rule and why.
--   Pass 2 (spell effect chain): local spell_template dump -- the live database
--   has no equivalent effectTriggerSpell field, see this generator's file header.
--   1. DIRECT: item-attached spell at trigger == 2 ("chance on hit") --
--      these appear in the combat log exactly as-is.
--   2. CHAIN: item-attached spell at trigger == 1 (on-equip proc auras) OR == 2,
--      followed ONE spell_template effect hop via effectTriggerSpell1/2/3.
--      This exists because a real proc (spell 16614 "Lightning Strike") never
--      appears as an item-attached spell at all -- only the equip-aura wrapper
--      (16615) does, at trigger==1, and 16615's own spell_template effect is what
--      fires 16614.
--      A direct-only lookup silently misses cases exactly like this one.
-- An id reachable through both layers gets one entry with item names unioned.
--
-- Maps a proc spell id to the item(s) that carry it, so the addon can answer
-- "is this spell id an item proc, and from what" via a plain table lookup.
--
-- Lives in const.lua (not its own file) for the same reason C.spellName does: a new
-- .lua file needs a Vampify.toc entry, which costs a full client restart, while
-- const.lua loads first as the very first module and a table literal here needs only
-- a /reload. Re-run the generator and replace this block; do not hand-edit it.
--
-- Regenerate: run the offline generator script
C.ORIGINS = {
    [56] = "Carved Ragetotem and others",
    [89] = "Fire Sword of Crippling",
    [695] = "Betrayer",
    [744] = "Gift of the Spider God",
    [772] = "Serrated Handaxe",
    [871] = "Glaive of the Defender",
    [1054] = "Lesser Firestone",
    [2606] = "Stormfist",
    [2912] = "Sentinel's Moonslicer",
    [3264] = "Bloodhowler",
    [3271] = "Chilton Wand",
    [3396] = "The Ripper, Vile Sting",
    [3424] = "Gift of the Spider God",
    [3742] = "Gahz'rilla Fang, Aura Proc Damage Sword",
    [5597] = "The Ripper",
    [6647] = "The Ripper",
    [6751] = "Venom Infused Blade",
    [7712] = "Fiery Retributer and others",
    [7714] = "Embergem Cuffs and others",
    [8191] = "Sword of Zeal",
    [8277] = "Cursed Shinbone",
    [8313] = "Bite of Serra'kis",
    [8348] = "Julie's Dagger",
    [8552] = "Staff of Horrors, Cursed Thornblade",
    [9057] = "Red Whelp Gloves, Helmet of the Scarlet Avenger",
    [9159] = "Green Whelp Armor",
    [9329] = "Soulstring and others",
    [9632] = "Ravager, The Cruel Blade",
    [9633] = "Ravager, The Cruel Blade",
    [9777] = "Truesilver Breastplate",
    [9796] = "Blight",
    [9800] = "Truesilver Champion",
    [9806] = "Phantom Blade",
    [10342] = "Guardian Talisman",
    [10351] = "Blade of the Basilisk",
    [10368] = "Uther's Strength",
    [10370] = "Mutilator",
    [10371] = "Obedient Whacker",
    [10373] = "Pendulum of Doom",
    [11657] = "Jang'thraze the Protector",
    [11658] = "Sul'thraze the Lasher",
    [11790] = "Toxic Revenger",
    [11791] = "Digmaster 5000, Vibroblade, Nail on a Plank",
    [11879] = "Shoni's Disarming Tool, The Murkfisher",
    [12484] = "Einhorn's Skinner",
    [12685] = "Stealthblade",
    [12686] = "Ragehammer",
    [12731] = "Stoneslayer",
    [13049] = "Dragon's Call",
    [13318] = "Barman Shanker, Blood Talon, Killmaim",
    [13438] = "Excavator's Brand",
    [13439] = "Winter's Bite and others",
    [13440] = "Grimclaw and others",
    [13441] = "Orb of Fire",
    [13442] = "Meteor Shard, Baron Charr's Sceptre, Scroll of Cow Portal",
    [13480] = "Night Reaver",
    [13482] = "The Ziggler, Electrocutioner Leg",
    [13486] = "Bloodletter Scalpel, Fleshrender",
    [13490] = "Howling Blade",
    [13491] = "Iron Knuckles",
    [13496] = "Mug O' Hurt",
    [13518] = "Blackvenom Blade, Fang of the Broodmother",
    [13519] = "Shortsword of Vengeance, Fishbringer",
    [13524] = "Stalvan's Reaper",
    [13526] = "Strike of the Hydra, Hookfang Shanker",
    [13527] = "Supercharger Battle Axe",
    [13528] = "Sword of Decay",
    [13530] = "Tainted Pierce",
    [13532] = "The Hand of Antu'sul",
    [13533] = "The Jackhammer, Carved Grimtotem",
    [13534] = "The Shatterer",
    [13752] = "Dazzling Longsword",
    [14106] = "The Black Knight",
    [14118] = "Drakefang Butcher",
    [14119] = "Phytoblade, Thunder 45, Thunderhorn",
    [14126] = "Grim Reaper, Rusty Coghammer",
    [15280] = "Dark Iron Sunderer",
    [15283] = "Dark Iron Pulverizer",
    [15494] = "Ironfoe",
    [15592] = "Skaldrenox's Rage",
    [15595] = "Force of Will",
    [15601] = "Hand of Justice",
    [15602] = "Lord General's Sword",
    [15661] = "Terrorblade Glaive",
    [15662] = "Smoldering Claw",
    [16393] = "Glutton's Cleaver",
    [16400] = "Widow's Kiss and others",
    [16401] = "Poison-tipped Bone Spear",
    [16403] = "The Goldtusk and others",
    [16405] = "Ripsaw and others",
    [16406] = "Gutwrencher, Hameya's Slayer",
    [16407] = "Edge of Winter",
    [16408] = "Darkwater Talwar",
    [16409] = "Ghoulfang and others",
    [16411] = "Deathblow",
    [16413] = "Firebreather, Searing Blade",
    [16414] = "Wraith Scythe, Scythe of the Harvest",
    [16415] = "Taran Icebreaker",
    [16433] = "Bloodfist and others",
    [16454] = "Searing Needle",
    [16528] = "Keris of Zul'Serak",
    [16549] = "Blackhand Doomsaw",
    [16551] = "Felstriker",
    [16559] = "Flame Wrath",
    [16560] = "Flame Wrath",
    [16602] = "Blackblade of Shahram",
    [16603] = "Demonfork",
    [16608] = "Demon Forged Breastplate, Breastplate of the Dark Reaver",
    [16614] = "Storm Gauntlets and others",
    [16621] = "Invulnerable Mail",
    [16782] = "Charged Servo Arm and others",
    [16783] = "Totem of Infliction, Girdle of Reprisal",
    [16784] = "Vile Protector",
    [16871] = "Bleakwood Hew",
    [16898] = "Blazing Rapier",
    [16908] = "Serenity",
    [16916] = "Arcanite Champion",
    [16921] = "Masterwork Stormhammer, Thunderforge Lance",
    [16927] = "Frostguard",
    [16928] = "Annihilator",
    [16939] = "Darkspear",
    [17144] = "Stormpike",
    [17148] = "Brain Hacker",
    [17152] = "Destiny",
    [17153] = "Kang the Decapitator",
    [17154] = "The Green Tower",
    [17196] = "Seeping Willow",
    [17308] = "Femur Club and others",
    [17315] = "Bashguuder, Rivenspike",
    [17331] = "Fang of the Crystal Spider",
    [17351] = "Argent Defender",
    [17352] = "Argent Avenger",
    [17407] = "The Nicker",
    [17483] = "Demonshear",
    [17484] = "Skullforge Reaver",
    [17496] = "Crest of Retribution",
    [17500] = "Malown's Slam",
    [17504] = "Bloodrazor",
    [17505] = "The Cruel Hand of Timmy",
    [17506] = "Soul Breaker",
    [17509] = "Dark Reaver",
    [17510] = "Sword of Corruption",
    [17511] = "Serpent Slicer, Ichor Spitter, Toxic Ripper",
    [17936] = "Firestone",
    [17940] = "Greater Firestone",
    [17942] = "Major Firestone",
    [18077] = "Venom Web Fang",
    [18078] = "Bloody Pick and others",
    [18081] = "Gryphon Rider's Stormhammer",
    [18082] = "Volcanic Hammer",
    [18083] = "Galgann's Firehammer",
    [18084] = "Fist of the Damned",
    [18086] = "Teebu's Blazing Longsword, Force of Magma",
    [18088] = "Blade of the Wretched, Corruption",
    [18089] = "Linken's Sword of Mastery",
    [18090] = "Gutrender, Fisher's Harpoon, Ancient Hakkari Flayer",
    [18091] = "Archeus",
    [18092] = "Shiver Blade, Coldheart Icicle",
    [18104] = "Axe of the Deep Woods",
    [18107] = "Gut Ripper, Fleshslasher",
    [18112] = "Ashbringer",
    [18138] = "Black Duskwood Staff, Shadowblade, Deathbringer",
    [18187] = "Pan of Po'rool, Overloaded Heating Coil, Fists of the Red Dawn",
    [18197] = "Serpent's Kiss, Stinging Viper",
    [18199] = "Burning War Axe",
    [18200] = "Bloodspiller",
    [18202] = "Bloodpike, Gargoyle Shredder Talons, Jaw of the Ancient",
    [18203] = "Venomspitter",
    [18204] = "Cobalt Crusher",
    [18205] = "Black Malice and others",
    [18206] = "Diabolic Skiver",
    [18208] = "Scorpion Sting",
    [18211] = "Nightblade, Doombringer, Ebon Hand",
    [18214] = "Witchfury, Sun's Tail",
    [18217] = "Duskbringer",
    [18276] = "Darrowspike, Bonechill Hammer",
    [18278] = "Silent Fang",
    [18289] = "Gravestone War Axe",
    [18350] = "Black Grasp of the Destroyer",
    [18381] = "Cursed Felblade",
    [18398] = "Sliverblade, Glacial Blade",
    [18543] = "Everflame Torch",
    [18633] = "Frightskull Shaft",
    [18652] = "Barovian Family Sword",
    [18656] = "Ebon Hilt of Marduk, Shadowbringer",
    [18796] = "Fiery War Axe",
    [18797] = "Flurry Axe",
    [18798] = "Freezing Band",
    [18803] = "Hand of Edward the Odd",
    [18817] = "Skullflame Shield",
    [18818] = "Skullflame Shield",
    [18819] = "Archaic Slicer",
    [18828] = "Wall of the Dead",
    [18833] = "Alcor's Sunrazor",
    [18946] = "The Lion Horn of Stormwind",
    [18980] = "Electrified Gloves",
    [19260] = "Chillpike",
    [19755] = "Frightalon",
    [19874] = "Shimmering Platinum Warhammer",
    [20586] = "Windreaper",
    [20869] = "Glacial Stone",
    [20883] = "Joonho's Mercy",
    [21140] = "Vis'kag the Bloodletter, Drake Talon Cleaver",
    [21151] = "Gutgore Ripper",
    [21152] = "Earthshaker",
    [21153] = "Bonereaver's Edge",
    [21159] = "Sulfuron Hammer",
    [21162] = "Sulfuras, Hand of Ragnaros",
    [21165] = "Empyrean Demolisher, Steamrigged Servohammer",
    [21170] = "Shadowstrike",
    [21179] = "Thunderstrike",
    [21186] = "Spinal Reaper",
    [21330] = "Eye of the Abyss",
    [21898] = "Cowl of Terror",
    [21919] = "Thrash Blade, Chronobreaker, Letashaz's Right Claw",
    [21949] = "Gatorbite Axe",
    [21951] = "Fist of Stone, Energized Spear",
    [21952] = "Claw of Celebras",
    [21961] = "Princess Theradras' Scepter, Carved Runetotem",
    [21970] = "Mark of the Chosen",
    [21992] = "Thunderfury, Blessed Blade of the Windseeker",
    [22600] = "Force Reactive Disk",
    [22619] = "Force Reactive Disk",
    [22639] = "Eskhandar's Left Claw",
    [22640] = "Eskhandar's Right Claw",
    [22850] = "Quel'Serrar",
    [22863] = "Sprinter's Sword",
    [23267] = "Perdition's Blade",
    [23454] = "Ironfist and others",
    [23592] = "Electrified Dagger",
    [23604] = "Black Amnesty",
    [23605] = "Nightfall",
    [23682] = "Darkmoon Card: Heroism",
    [23684] = "Darkmoon Card: Blue Dragon",
    [23687] = "Darkmoon Card: Maelstrom",
    [23719] = "The Untamed Blade",
    [24241] = "Halberd of Smiting",
    [24251] = "Zulian Slicer",
    [24254] = "Sceptre of Smiting",
    [24257] = "Jeklik's Crusher",
    [24362] = "Feralkin Necklace, Ancient Hakkari Flayer, Devilsaur Claws",
    [24388] = "The Lobotomizer",
    [24405] = "Glacial Spike, Scale of the Blue Drake",
    [24585] = "Ancient Hakkari Manslayer",
    [24993] = "Emerald Dragonfang",
    [25768] = "Staff of the Qiraji Prophets",
    [25907] = "Wrath of Cenarius",
    [26108] = "Dark Edge of Insanity",
    [26415] = "Kalimdor's Revenge",
    [26693] = "Neretzek, The Blood Drinker, Shadowbringer, Pulseseeker",
    [27039] = "Beastmaster's Cap, Deathmist Mask, Pendant of Kindred Spirit",
    [27042] = "Beastmaster's Gloves, Deathmist Wraps",
    [27205] = "Beastmaster's Boots, Deathmist Sandals, Charm of Dark Domination",
    [27208] = "Beastmaster's Tunic, Deathmist Robe",
    [27559] = "Hushblade, Jagged Obsidian Shield",
    [27648] = "Thunderfury, Blessed Blade of the Windseeker",
    [27655] = "Heart of Wyrmthalak",
    [27657] = "Inflatable Woman",
    [27860] = "Blade of Eternal Darkness",
    [27868] = "Icemail Jerkin",
    [28414] = "Corrupted Ashbringer",
    [28441] = "Corrupted Ashbringer",
    [28701] = "Tempest's Rage",
    [29151] = "Misplaced Servo Arm",
    [29155] = "Corrupted Ashbringer",
    [29164] = "Stygian Buckler",
    [29502] = "Hurricane",
    [29638] = "Bow of Searing Arrows",
    [29639] = "Dwarven Hand Cannon",
    [29640] = "Heartseeking Crossbow, Lodestone",
    [29641] = "Dark Iron Rifle",
    [29644] = "Galgann's Fireblaster",
    [29646] = "Quillshooter",
    [29647] = "Shell Launcher Shotgun",
    [29653] = "Venomstrike",
    [29655] = "Verdant Keeper's Aim",
    [45076] = "Aspect of Seradane",
    [45416] = "Vial of Potent Venoms",
    [45522] = "Idol of the Emerald Rot",
    [45841] = "Rod of Resuscitation",
    [45843] = "Mana Binding Signet",
    [45848] = "Fist of the Forgotten Order",
    [45849] = "Totem of Crackling Thunder",
    [45856] = "Shawl of the Castellan",
    [45858] = "Breath of Solnius",
    [45860] = "Chromie's Broken Pocket Watch",
    [45862] = "Libram of the Faithful",
    [45867] = "Crystal of Vengeance",
    [45869] = "Concentrated Power of Will",
    [45873] = "Black Widow Eggs",
    [45875] = "Vampire Heart",
    [46104] = "Tempered Runeblade",
    [46318] = "Demoralization Club",
    [46319] = "Horde Defender's Axe",
    [46431] = "Idol of Evergrowth",
    [47354] = "Breastplate of Beast Mastery",
    [48004] = "Dream's Herald",
    [48005] = "Frostbound Slasher",
    [48006] = "Pauldron of Deflection",
    [48008] = "Bloodletter Razor",
    [48048] = "Ornate Bloodstone Dagger",
    [48101] = "Totem of the Stonebreaker",
    [48102] = "Towerforge Demolisher",
    [49369] = "Modrag'zan, Heart of the Mountain",
    [51001] = "Ornate Pyrium Gauntlets",
    [51144] = "Shar'tateth, the Shattered Edge",
    [51250] = "Splinterspear Mace",
    [51251] = "Claw of the Mageweaver",
    [51266] = "Stonewrought Vambraces",
    [51277] = "Crystalvein Breastplate",
    [51740] = "Treant's Bane",
    [52843] = "Bloodcaller's Decapitator",
    [52853] = "Draenethyst Blade",
    [52854] = "Draenethyst Juggernaut",
}
-- END GENERATED ORIGINS
