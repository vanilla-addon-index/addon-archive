-- Vampify -- SavedVariables schema, defaults merge, and migration.
--
-- Migration policy: step FORWARD from a known older version; on an unknown or newer version,
-- reset wholesale. A partial migration from a schema we do not know produces a config that looks
-- valid and is not, which is worse than losing a frame position.

VampifyConfig = {}
local C = VampifyConfig

C.DB_VERSION = 4

-- v1 put the display at CENTER/-150. Confirmed in-game 2026-08-10: on a pfUI layout that is right
-- on top of the action bars, and at strata MEDIUM/level 1 the frame loses every overlap -- it
-- reported shown, visible, alpha 1, and could not be found on screen.
C.V1_POS = { point = "CENTER", x = 0, y = -150 }

C.DEFAULTS = {
    dbVersion = 3,
    pos       = { point = "CENTER", x = 0, y = 200 },
    locked    = false,
    minimap   = true,
    mmAngle   = 200,       -- degrees around the minimap

    -- v3: our own scrolling combat text, alongside (not instead of) Blizzard's. "showFct" (v2 and
    -- earlier) is gone -- superseded by sct.enabled + sct.mode, see the v2->v3 step below. Two
    -- overlapping on/off switches for the same feature is exactly the kind of SavedVariables bloat
    -- the project rules ask to avoid.
    sct = {
        enabled  = false,
        mode     = "own",      -- "own" (this addon's SCT, free-floating anchor) | "bar" (this
                                -- addon's SCT, anchored to the display bar, gui/sct.lua's
                                -- reanchor()) | "blizzard" (gui/fct.lua). New enum value, no
                                -- dbVersion bump: an existing "own"/"blizzard" profile is still
                                -- valid, fillDefaults never touches an explicitly stored mode.
        pos      = { point = "CENTER", x = -180, y = 0 },
        color    = { r = 0.4, g = 0.9, b = 0.4 },
        duration = 1.5,
        -- Both slider-driven. No dbVersion bump is needed to add them: the defaults merge fills
        -- missing keys recursively, so an existing v3 profile simply gains them at their default.
        fontSize = 16,     -- 8..48; the old 8..28 ceiling was reached in practice
        rise     = 40,     -- 20..320 px travelled per number; also widens the anti-overlap spread
        -- One number per CAST rather than per hit: an AoE on five targets shows its summed return
        -- once instead of five times. Display only -- the model still runs per hit, so totals are
        -- identical either way. On by default because it is what was asked for.
        coalesce = true,
        -- Text effect. Green numbers over grass are barely readable without one; an outline is
        -- what separates the glyph from whatever is behind it. "" | "OUTLINE" | "THICKOUTLINE".
        outline  = "THICKOUTLINE",
        shadow   = true,
    },
    -- Whether the display is wanted on screen. A stored PREFERENCE, not a reading of the frame:
    -- the frame's own IsShown() was the single definition of "is it on" until it turned out that
    -- recompute() (which runs on every loading screen and every committed gear scan) overwrites it,
    -- so a hide never survived the next portal. No dbVersion bump needed -- the defaults merge fills
    -- it in recursively, and `true` is what every existing profile was effectively running.
    shown        = true,
    showOverheal = true,

    -- Dev-only per-hit debug export (core/perhit.lua), toggled by /vf perhit on|off and the
    -- "Per-hit debug export" checkbox in gui/options.lua. DEFAULT ON: the module itself still
    -- defaults its in-memory state to disabled (core/perhit.lua's own comment), but the developer
    -- explicitly overrode that for THIS addon -- it is meant to run continuously like a background
    -- capture addon, not be armed by hand each session (follow-up change request, 2026-08-22). No dbVersion bump
    -- needed: the defaults merge below fills it in recursively for an existing profile, same as
    -- shown/showOverheal above -- and `true` for a MISSING key is exactly what a brand new
    -- default-on preference should read as (fillDefaults only ever fills a true nil, never a
    -- stored `false`, so a developer who explicitly turned it off keeps it off across reloads).
    perhitEnabled = true,
}

C.CHAR_DEFAULTS = {
    dbVersion   = 2,
    enabled     = true,
    sessionHeal = 0,
    manual      = {},      -- manual source overrides, /vf source add <percent>
    -- Runtime-extendable twin of VampifyConst.NO_TRIGGER, /vf exclude add|remove|list. Damage
    -- shields have no structural signal (see const.lua) -- a new one is only ever found once it
    -- shows up wrongly in the breakdown, so this list has to be growable without a client restart.
    -- Unioned with the hardcoded table at the check site (VampifyConst.triggersVampirism), never
    -- replacing it. No dbVersion bump needed: the defaults merge below fills it in recursively.
    noTrigger   = {},

    -- Persisted per-spell breakdown, two sets side by side (spec 2026-08-10 sec 3). Same shape as
    -- VampifyAggregate's in-memory spHeal/spDmg/spOver (and their lifetime twins): a plain spellId
    -- -> number table each. core/commands.lua points the aggregate's own tables AT these after
    -- login/reload, so a recorded hit is a SavedVariables write with no extra save step and no
    -- extra allocation -- see A.new's comment in core/aggregate.lua.
    --   session  -- survives /reload and loading screens, cleared on a genuine login
    --   lifetime -- never cleared automatically; only /vf reset lifetime|both touches it
    -- No dbVersion bump needed: the defaults merge below fills both in recursively for an existing
    -- character db that predates this feature.
    --
    -- `hist` is the DAMAGE HISTOGRAM (core/histogram.lua) for the same two scopes: hit count per
    -- exact damage value, normal and AoE hits kept apart, with everything above the cap bundled
    -- into a count and a sum. It is what makes "what would one more source be worth" answerable
    -- exactly -- the floor makes healing non-linear in damage, so no total or average can answer
    -- it (see that file's header). Wired by reference the same way the per-spell tables are, so a
    -- recorded hit is already a SavedVariables write.
    --
    -- Bounded on purpose (VampifyHistogram.CAP): at most ~1000 exact keys per side, so a long
    -- session cannot grow this without limit the way a per-GUID table would. No dbVersion bump
    -- needed -- the defaults merge below fills it in recursively for a character db saved before
    -- this existed, including a half-filled one.
    -- `hits` is the per-spell HIT COUNT twin of heal/damage/overheal above, same key, same
    -- session/lifetime split, filled by the same VampifyAggregate.recordSpell call. No dbVersion
    -- bump needed here either: the defaults merge below fills it in as an empty table for a
    -- character db that predates the counter, so an existing profile's heal/damage/overheal HISTORY
    -- is kept while its hit counts start over at 0 -- there is nothing to backfill them from.
    -- healAoe/damageAoe/hitsAoe/splitSeen (2026-08-24, UI-redesign strand A; REDEFINED same day --
    -- see C.migrate's v<4 step and core/aggregate.lua's A.recordSpell for the full history): the
    -- ST/AoE split's persisted twin of heal/damage/hits above. Deliberately a SEPARATE, ADDITIVE
    -- set of tables rather than a reshape of heal/damage/hits -- those three keep their existing
    -- meaning (the GRAND total per spell) untouched by either version of this feature. The defaults
    -- merge below fills these four in as empty tables for a character db that predates the split
    -- entirely; core/aggregate.lua's A.spellSplit reads a spell with nothing in them as "ST equals
    -- the whole existing total, split unknown" (hasSplit=false) rather than guessing. See
    -- core/aggregate.lua's A.recordSpell and A.spellSplit for the read/write halves of this contract.
    --
    -- A VERSION BUMP WAS NEEDED after all, unlike most fields in this table: the split's DEFINITION
    -- changed the same day it shipped (deriveAoE-classification -> current-target-identity), so any
    -- data already collected under the first definition has to be discarded rather than silently
    -- reinterpreted under the second -- C.migrate's v<4 step does exactly that, leaving heal/damage/
    -- overheal/hits (the grand totals) untouched.
    session     = { heal = {}, damage = {}, overheal = {}, hits = {},
                    healAoe = {}, damageAoe = {}, hitsAoe = {}, splitSeen = {},
                    hist = { n = {}, a = {}, nOverN = 0, nOverSum = 0, aOverN = 0, aOverSum = 0 } },
    lifetime    = { heal = {}, damage = {}, overheal = {}, hits = {},
                    healAoe = {}, damageAoe = {}, hitsAoe = {}, splitSeen = {},
                    hist = { n = {}, a = {}, nOverN = 0, nOverSum = 0, aOverN = 0, aOverSum = 0 } },
}

local function fillDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(db[k]) ~= "table" then db[k] = {} end
            fillDefaults(db[k], v)
        elseif db[k] == nil then     -- nil, NOT falsy: a stored `false` must survive
            db[k] = v
        end
    end
    return db
end

local function copy(t)
    local out = {}
    for k, v in pairs(t) do
        if type(v) == "table" then out[k] = copy(v) else out[k] = v end
    end
    return out
end

function C.migrate(db, defaults, currentVersion)
    if type(db) ~= "table" then return copy(defaults) end
    local v = db.dbVersion
    if type(v) ~= "number" or v > currentVersion then
        return copy(defaults)        -- unknown or from the future: reset, do not guess
    end
    -- Known older versions step forward here.
    if v < 2 then
        -- Move the display off the action bars -- but ONLY for users who never dragged it. A
        -- position the user chose is theirs; silently relocating it would be worse than the bug.
        if db.pos and db.pos.point == C.V1_POS.point
           and db.pos.x == C.V1_POS.x and db.pos.y == C.V1_POS.y then
            db.pos = nil    -- fillDefaults below restores the v2 default
        end
    end
    if v < 3 then
        -- showFct only ever meant "show Blizzard's combat text". Carry an explicitly-set value
        -- into the new sct.enabled switch, and into sct.mode = "blizzard" so a user who had it ON
        -- keeps seeing exactly what they had -- our own SCT (mode "own") is a different visual and
        -- must not silently replace what they were already looking at. A false/never-set showFct
        -- needs no mode opinion; the "own" default from C.DEFAULTS is fine for a switch that was
        -- off anyway. showFct itself is then dropped -- see the comment on C.DEFAULTS.sct.
        db.sct = db.sct or {}
        if db.sct.enabled == nil and db.showFct ~= nil then
            db.sct.enabled = db.showFct
            if db.showFct == true then db.sct.mode = "blizzard" end
        end
        db.showFct = nil
    end
    if v < 4 then
        -- ST/AoE split REDEFINED (2026-08-24, the same day the split shipped): from "was this hit
        -- AoE-CLASSIFIED (deriveAoE, area-damage burst detection)" to "did this hit land on
        -- something OTHER than the player's current target" -- a completely different question (see
        -- core/aggregate.lua's A.recordSpell for the full history). Any healAoe/damageAoe/hitsAoe/
        -- splitSeen data already collected under the SUPERSEDED definition would silently mix two
        -- incompatible meanings with data collected under the new one if left in place -- worse than
        -- losing it, so it is discarded ONCE, cleanly, here, exactly like a v<2/v<3 step above steps
        -- an old schema forward rather than half-migrating it.
        --
        -- GRAND TOTALS ARE NOT TOUCHED: db.session.heal/damage/overheal/hits and their lifetime
        -- twins keep every number a player has already earned -- only the split's OWN bookkeeping
        -- (which of that total was ST vs AoE) resets to "unknown" (A.spellSplit's hasSplit reads
        -- false again for every spell until a fresh, correctly-classified hit lands). Guarded on
        -- db.session/db.lifetime existing at all: this migrate() function also runs on VampifyDB
        -- (global settings), which has neither field, and must not error there.
        if db.session then
            db.session.healAoe, db.session.damageAoe, db.session.hitsAoe, db.session.splitSeen =
                {}, {}, {}, {}
        end
        if db.lifetime then
            db.lifetime.healAoe, db.lifetime.damageAoe, db.lifetime.hitsAoe, db.lifetime.splitSeen =
                {}, {}, {}, {}
        end
    end

    db.dbVersion = currentVersion
    return fillDefaults(db, defaults)
end

if CreateFrame then
    local done = false
    local function load_()
        if done then return end
        done = true
        VampifyDB     = C.migrate(VampifyDB, C.DEFAULTS, C.DB_VERSION)
        VampifyCharDB = C.migrate(VampifyCharDB, C.CHAR_DEFAULTS, C.DB_VERSION)
    end

    local f = CreateFrame("Frame", "VampifyConfigFrame")
    -- ADDON_LOADED is the earliest event at which the SavedVariables tables exist, and it fires on
    -- every load path -- migrating any later would leave the addon reading an unmigrated table in
    -- the meantime, invisible until the schema changes and then corrupting.
    -- PLAYER_ENTERING_WORLD is kept as a belt-and-braces second chance; `done` makes it idempotent.
    -- (An earlier version of this comment claimed PLAYER_LOGIN does not fire on /reload. It does --
    -- see core/commands.lua's wireSession for the evidence. Nothing here depended on the claim, but
    -- it propagated from here into code that did.)
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function()
        if event == "ADDON_LOADED" and arg1 ~= "Vampify" then return end
        load_()
    end)
end

function C.get()     return VampifyDB end
function C.getChar() return VampifyCharDB end
