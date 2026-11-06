-- BulwarkFrame - core/config.lua
-- SavedVariables model. BulwarkFrameDB is declared in the .toc; ensureDefaults() fills in
-- anything missing, so a saved file from an older version keeps working after an update.
--
-- Pure table work, no WoW API -- covered by tools/luatests/test_config.lua.

BulwarkFrame = BulwarkFrame or {}
local BF = BulwarkFrame

BulwarkFrameDB = BulwarkFrameDB or {}

-- Aura ids of the buffer, both verified in game on 2026-07-28:
--   58130 "Earthen Bulwark"            -- a BUFF,   carries the remaining DURATION (8 s)
--   58127 "Earthen Bulwark Durability" -- a DEBUFF, its stack count IS the pool level (0..100)
-- They stay configurable rather than baked in because Turtle can renumber a custom spell in any
-- patch, and a hardcoded id would then read a buffer that is not there.
BF.DEFAULT_POOL_AURA = 58127
BF.DEFAULT_TIME_AURA = 58130
BF.BUFFER_DURATION = 8

BF.DEFAULTS = {
    -- placement
    point = "CENTER", relPoint = "CENTER", x = 0, y = -120,
    locked = false,
    hidden = false,               -- explicitly hidden via minimap right-click / '/bulwark hide'
    scale = 1.0,
    minimapAngle = 215,
    showMinimapButton = true,

    -- layout
    width = 150,
    barHeight = 14,
    timeBarHeight = 9,
    swingHeight = 2,
    spacing = 2,

    -- elements
    showThreshold = true,
    showExpiry = true,
    showSwing = true,
    -- Swing marker rides the expiry bar (pfUI mana-tick style) instead of its own line.
    swingOnExpiryBar = true,
    -- What the number on the threshold bar means:
    --   "hit"    -- how large a single incoming hit may be before the buffer is drained
    --   "shield" -- how much damage the buffer still absorbs
    -- Same buffer, two questions; they differ by the absorb rate (factor ~7 at rank 3).
    displayMode = "hit",
    showThresholdText = true,
    showExpiryText = true,
    showSpeedText = true,          -- current attack speed on the left of the expiry bar
    hideOutOfCombat = false,
    -- Visible by default. A readout that hides itself whenever there is nothing to read looks
    -- broken on first install -- you cannot place it, and the obvious fix (clicking things until it
    -- appears) is how a demo mode gets mistaken for live data. Opt in to hiding, not out of it.
    hideWhenInactive = false,

    -- colours (r,g,b 0..1); calc.lua picks WHICH one, these are the values
    colorRed    = { 0.80, 0.15, 0.15 },
    colorYellow = { 0.85, 0.75, 0.20 },
    colorGreen  = { 0.25, 0.75, 0.30 },
    colorSwing  = { 0.90, 0.90, 0.95 },
    colorBg     = { 0.05, 0.05, 0.05, 0.80 },

    -- The expiry bar shares the colour buckets but is drawn at this alpha. Seen side by side at
    -- full saturation the two bars compete for attention even though the lower one is thinner --
    -- the threshold is the primary readout and has to win. Set to 1.0 for the old, flat look.
    expiryAlpha = 0.65,

    -- colour thresholds (fraction of pool / seconds left)
    poolRed = 0.30, poolYellow = 0.70,
    timeRed = 2.0,  timeYellow = 5.0,

    -- absorb model
    talentRank = 3,               -- Elemental Weapons rank -> 5/10/15 %
    setBonusMode = "none",        -- "none" | "add" | "mult"  (T2.5 reading, see README)
    setBonusValue = 3,

    -- swing timer
    swingLatencyShare = 1.0,      -- 1.0 = full round trip, 0.5 = downstream only
    swingUseLatency = true,

    -- aura ids
    poolAura = 58127,
    timeAura = 58130,
}

-- Deep-ish copy for the colour tables: handing out DEFAULTS directly would let a live edit of the
-- saved value mutate the default and make a "reset" a no-op.
local function copyColor(c)
    if type(c) ~= "table" then return nil end
    return { c[1], c[2], c[3], c[4] }
end

function BF.ensureDefaults(db)
    db = db or BulwarkFrameDB
    local k, v
    for k, v in pairs(BF.DEFAULTS) do
        if db[k] == nil then
            if type(v) == "table" then db[k] = copyColor(v) else db[k] = v end
        end
    end
    return db
end

-- Resets everything back to DEFAULTS in place (the caller keeps its table reference).
function BF.resetConfig(db)
    db = db or BulwarkFrameDB
    local k
    for k in pairs(db) do db[k] = nil end
    return BF.ensureDefaults(db)
end

-- The absorb rate the calculation should use, from talent rank plus the optional set bonus.
-- Delegates to BulwarkFrameCalc.rateForRank so the two readings of the T2.5 bonus stay in one
-- place. "mult" passes a factor, so 3 % becomes 1.03 here rather than at the call site.
function BF.currentRate(db)
    db = db or BulwarkFrameDB
    local add, mult = nil, nil
    if db.setBonusMode == "add" then
        add = (db.setBonusValue or 0) / 100
    elseif db.setBonusMode == "mult" then
        mult = 1 + ((db.setBonusValue or 0) / 100)
    end
    return BulwarkFrameCalc.rateForRank(db.talentRank, add, mult)
end
