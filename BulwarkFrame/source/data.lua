-- BulwarkFrame - data.lua
-- Everything that touches the live client: the buffer aura, the swing timer, combat state.
-- WoW-API file (parse-checked only; the arithmetic it feeds lives in core/ and is unit tested).
--
-- Two reads, and they come from DIFFERENT enumerations -- settled in game on 2026-07-28, no
-- longer an open question:
--   * TIME  -- aura 58130 "Earthen Bulwark", a BUFF. Seen by GetPlayerBuff / UnitBuff (spell id at
--             return 3). Counts 8 seconds down; verified across eight appearances.
--   * POOL  -- aura 58127 "Earthen Bulwark Durability", a DEBUFF. Its stack count IS the fill
--             level, 0..100 (verified building up: 20, 44, 70, 91, 100). It is NOT listed by the
--             HELPFUL player-buff enumeration at all, only by UnitDebuff (spell id at return 4).
-- Both ids stay configurable, and the reader takes each value from whichever aura reports it.

BulwarkFrame = BulwarkFrame or {}
local BF = BulwarkFrame
local S = BulwarkFrameSwing

-- Live state, read by ui.lua. One table, updated in place -- no per-frame allocation.
BF.state = {
    active = false,       -- buffer aura present
    stacks = 0,
    timeLeft = 0,
    maxHP = 0,
    inCombat = false,
    timeLeftAt = 0,       -- GetTime() of the last timeLeft reading (see ScanAuras)
    lastSwingAt = 0,
    swingSpeed = 0,
    swingOffset = 0,
    hasPool = false,      -- pool aura seen at least once this session (probe hint)
    hasTime = false,
}

-- ---- buff scan --------------------------------------------------------------------------

-- Walks one of the 64-slot unit aura enumerations looking for the buffer, and returns the
-- (possibly raised) stack count plus the found flag.
--
-- Deliberately a file-scope function taking its inputs as arguments rather than a closure built
-- inside ScanAuras: as a closure it allocated one object per CALL plus one more per aura SLOT (the
-- per-slot pcall wrapper), and ScanAuras is the PLAYER_AURAS_CHANGED handler -- an event that
-- fires on every stack change of the buffer, i.e. on every absorbed hit. Roughly two dozen
-- throwaway closures per incoming melee swing is exactly the GC churn the rest of this addon
-- takes care to avoid.
--
-- The per-slot pcall went with it. It was never per-slot error recovery either: the old code
-- aborted the WHOLE walk as soon as one slot failed, so a single pcall around the walk (see the
-- call sites) covers the same ground -- and UnitBuff/UnitDebuff on "player" with an integer index
-- does not throw to begin with. The one behavioural difference is that a walk which errors part
-- way through now contributes nothing instead of its partial count, which is the safer of the two.
--
-- Note the id position differs between the two calls -- an easy trap: reading return 4 from
-- UnitBuff (or 3 from UnitDebuff) silently yields nil and the aura is never matched.
local function scanStacks(st, fn, idPos, poolId, timeId, stacks, found)
    local i = 1
    while i <= 64 do
        local r1, r2, r3, r4 = fn("player", i)
        if r1 == nil then break end
        local id = (idPos == 4) and tonumber(r4) or tonumber(r3)
        if id == poolId or id == timeId then
            local n = tonumber(r2)
            if n and n > stacks then
                stacks = n
                found = true
                st.hasPool = true
            end
        end
        i = i + 1
    end
    return stacks, found
end

-- Scans the player's buffs once and writes pool/time into BF.state.
-- GetPlayerBuff walks HELPFUL slots; GetPlayerBuffID (SuperWoW) gives the spell id, which is the
-- whole reason SuperWoW is a hard requirement -- matching the icon texture instead would collide
-- with unrelated auras and produce a confidently wrong readout.
--
-- GOTCHA (in-game verified): GetPlayerBuffTimeLeft returns 0 for a permanent buff, not nil, so
-- "has a duration" must be tested as > 0.
function BF.ScanAuras()
    local st = BF.state
    local db = BulwarkFrameDB
    local poolId, timeId = db.poolAura, db.timeAura

    local stacks, timeLeft = 0, 0
    local found = false
    local i = 0
    while i < 32 do
        local slot = GetPlayerBuff(i, "HELPFUL")
        if not slot or slot < 0 then break end
        local id = GetPlayerBuffID and GetPlayerBuffID(slot)
        if id == poolId or id == timeId then
            found = true
            -- Stacks AND duration are taken from whichever of the two auras carries them, rather
            -- than assuming the pool id owns the count. Reading the count only from poolId meant
            -- that if the buffer happens to sit on the other id, the aura was detected but the
            -- count stayed 0 -- and the "no count means one stack" fallback below then reported a
            -- single stack. On a full buffer that renders as 61 instead of 6117: a plausible
            -- number, off by a factor of a hundred. Whichever aura reports more wins; they cannot
            -- contradict each other because they describe the same buffer.
            local n = GetPlayerBuffApplications and GetPlayerBuffApplications(slot)
            if type(n) == "number" and n > stacks then
                stacks = n
                if id == poolId then st.hasPool = true end
            end
            local tl = GetPlayerBuffTimeLeft and GetPlayerBuffTimeLeft(slot)
            if type(tl) == "number" and tl > 0 and tl > timeLeft then
                timeLeft = tl
                st.hasTime = true
            end
        end
        i = i + 1
    end

    -- The fill level is NOT reachable through GetPlayerBuff. Measured in game 2026-07-28 while the
    -- buffer was building (20 -> 44 -> 70 -> 91 -> 100):
    --
    --   58130 "Earthen Bulwark"            -- UnitBuff,   spell id at return 3, carries the TIME
    --   58127 "Earthen Bulwark Durability" -- UnitDebuff, spell id at return 4, carries the STACKS
    --
    -- The durability aura runs as a DEBUFF, and the HELPFUL player-buff enumeration above never
    -- lists it. Reading only that API is why a full buffer reported a single stack -- and one stack
    -- renders as 61 against a maximum of 6117: a plausible number, wrong by a factor of a hundred.
    --
    -- The walk itself lives at file scope (see scanStacks above). pcall is handed the arguments
    -- directly instead of a wrapper closure, so this path allocates nothing at all.
    if UnitDebuff then
        local ok, s, f = pcall(scanStacks, st, UnitDebuff, 4, poolId, timeId, stacks, found)
        if ok then stacks, found = s, f end
    end
    if UnitBuff then
        local ok, s, f = pcall(scanStacks, st, UnitBuff, 3, poolId, timeId, stacks, found)
        if ok then stacks, found = s, f end
    end

    -- A buffer aura with no applications at all still means "buffer up": 1.12 reports a
    -- single-stack aura without a count, and treating that as 0 would blank the bar while it is
    -- protecting us. Only reached when NO source reported a count.
    if found and stacks == 0 then stacks = 1 end

    st.active = found
    st.stacks = stacks
    st.timeLeft = timeLeft
    -- When this reading was taken. GetPlayerBuffTimeLeft is only sampled on aura events, so the
    -- display interpolates from here instead of holding the same number until the next event --
    -- otherwise an 8 second bar visibly steps down in chunks.
    st.timeLeftAt = GetTime()
end

-- Re-reads ONLY the remaining time, cheaply enough to run on a timer rather than waiting for an
-- event. This exists because 1.12 does not reliably fire PLAYER_AURAS_CHANGED when an aura that is
-- already up is merely REFRESHED: same aura, same stack count, new duration. The event-driven read
-- then keeps its old timestamp and the interpolation counts down past a buffer that was in fact
-- reset to 8 seconds -- which is exactly the reported symptom.
--
-- Deliberately not the full ScanAuras: the stack count needs the two 64-slot unit enumerations,
-- while the duration only needs the player-buff walk, so the expensive part stays event-driven.
function BF.ScanTime()
    local st = BF.state
    local db = BulwarkFrameDB
    local poolId, timeId = db.poolAura, db.timeAura
    local timeLeft = 0
    local i = 0
    while i < 32 do
        local slot = GetPlayerBuff(i, "HELPFUL")
        if not slot or slot < 0 then break end
        local id = GetPlayerBuffID and GetPlayerBuffID(slot)
        if id == poolId or id == timeId then
            local tl = GetPlayerBuffTimeLeft and GetPlayerBuffTimeLeft(slot)
            if type(tl) == "number" and tl > timeLeft then timeLeft = tl end
        end
        i = i + 1
    end
    -- Only accept a reading that moves the clock FORWARD (a refresh) or keeps it running down.
    -- A zero here means the aura is gone; the caller's active flag comes from ScanAuras.
    if timeLeft > 0 then
        st.timeLeft = timeLeft
        st.timeLeftAt = GetTime()
    end
    return timeLeft
end

-- ---- swing ------------------------------------------------------------------------------

-- Refreshes weapon speed and the latency offset. Cheap, but not per-frame cheap: called on
-- swing events and on the slow ticker, not from OnUpdate.
function BF.RefreshSwingInputs()
    local st = BF.state
    local db = BulwarkFrameDB
    local main = UnitAttackSpeed("player")
    if type(main) == "number" and main > 0 then st.swingSpeed = main end
    if db.swingUseLatency then
        local _, _, lag = GetNetStats()
        st.swingOffset = S.latencySeconds(lag, db.swingLatencyShare)
    else
        st.swingOffset = 0
    end
end

-- ---- events -----------------------------------------------------------------------------

local driver = CreateFrame("Frame", "BulwarkFrameDataDriver")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_AURAS_CHANGED")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("UNIT_INVENTORY_CHANGED")

-- Max health is the base of EVERY number on screen (maxPool = maxHP/5), so it must not be read
-- only on zone-in and gear swaps. A stamina buff landing at the raid entrance -- Fortitude, Gift
-- of the Wild, food, a world buff -- moves max health without either of those events, and the
-- readout would then be ~10% low for the whole encounter. UNIT_MAXHEALTH carries a unit token in
-- arg1 and fires for every group member, so it has to be filtered; PLAYER_LEVEL_UP carries the
-- new level in arg1 and must NOT go through that filter.
driver:RegisterEvent("UNIT_MAXHEALTH")
driver:RegisterEvent("PLAYER_LEVEL_UP")

-- SuperWoW's UNIT_CASTEVENT is the swing source: arg3 is "MAINHAND"/"OFFHAND" for auto-attacks.
-- It is language independent and fires on misses too, unlike parsing combat-log text -- which is
-- how the third-party swing timers get it wrong on a dodge.
driver:RegisterEvent("UNIT_CASTEVENT")

driver:SetScript("OnEvent", function()
    if event == "UNIT_CASTEVENT" then
        -- arg1 = caster GUID, arg3 = type. "MAINHAND"/"OFFHAND" are auto-attacks, not spells.
        -- Only the main hand drives the bar: an off-hand swing has its own clock, and drawing
        -- both on one line would show a marker that jumps backwards.
        if arg3 == "MAINHAND" and arg1 == BF.playerGuid then
            BF.state.lastSwingAt = GetTime()
            BF.RefreshSwingInputs()
            -- Redraw explicitly, because this branch returns before the shared RequestUpdate at
            -- the end of the handler. Without it a swing landing while idle and out of combat
            -- never re-attaches the update loop and the marker simply does not move -- the one
            -- wakeup path that is neither an aura nor a combat event. The call stays INSIDE the
            -- main-hand test on purpose: UNIT_CASTEVENT fires for every cast of every unit in
            -- range, and redrawing on all of them is exactly the churn this addon avoids.
            if BF.RequestUpdate then BF.RequestUpdate() end
        end
        return
    end
    if event == "UNIT_MAXHEALTH" then
        -- Health only: no GUID re-capture, no swing re-read. This fires for party and raid
        -- members too, hence the filter.
        if arg1 == "player" then BF.state.maxHP = UnitHealthMax("player") or 0 end
    elseif event == "PLAYER_LEVEL_UP" then
        BF.state.maxHP = UnitHealthMax("player") or 0
    elseif event == "PLAYER_REGEN_DISABLED" then
        BF.state.inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        BF.state.inCombat = false
    elseif event == "PLAYER_ENTERING_WORLD" or event == "UNIT_INVENTORY_CHANGED" then
        BF.state.maxHP = UnitHealthMax("player") or 0
        -- Seeded from the live API, not only from the REGEN transitions: those fire on ENTERING
        -- combat, never on login, so a /reload taken mid-fight would leave the flag false for the
        -- rest of the encounter and strand anyone running "Combat only".
        BF.state.inCombat = UnitAffectingCombat("player") and true or false
        BF.CapturePlayerGuid()
        BF.RefreshSwingInputs()
    end
    if event == "PLAYER_AURAS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        BF.ScanAuras()
    end
    if BF.RequestUpdate then BF.RequestUpdate() end
end)

-- The player's own GUID, needed to tell our swings from everyone else's. SuperWoW appends it as a
-- second return of UnitExists -- resolved the same way elsewhere, rather than via a second API call.
-- Cached on world entry, not read per event.
BF.playerGuid = nil

function BF.CapturePlayerGuid()
    local _, guid = UnitExists("player")
    if guid then BF.playerGuid = guid end
    return BF.playerGuid
end
