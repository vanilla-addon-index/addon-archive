-- Vampify -- what happens TO the player: incoming damage and logged healing.
--
-- Separate from capture/damage.lua on purpose. That file listens to the *_SELF events, which mean
-- "the player is the CASTER" -- confirmed in-game, not assumed. Incoming
-- damage is therefore not in them at all; it needs the *_OTHER family, filtered on our own GUID.
--
-- THE COST. The _OTHER events fire for every foreign unit in range, which is why v0.1.0 avoided
-- them. Three things keep that in hand: they are registered only while something actually wants
-- them (see WANTED, below), a group/raid switches the WATCH reason off (the balance is worthless
-- there anyway -- but see WANTED for why that no longer means the events themselves stop), and the
-- GUID comparison is the first statement in the handler, before any decoding, allocating nothing.
--
-- HEALING IS TAKEN FROM THE BY_* EVENTS ONLY. nampower fires both perspectives for the same heal
-- (BY_* for the caster, ON_* for the target); registering both double-counts, measured elsewhere at
-- +16 % against ground truth. Registering only BY_SELF and BY_OTHER and filtering on the target
-- GUID sees every heal on us exactly once, and needs no deduplication.
--
-- SELF VS. EXTERNAL HEALING (follow-up change request, 2026-08-22). Both BY_SELF and BY_OTHER
-- were being summed into ONE "logged" total, which blurred exactly the distinction the per-hit
-- export needs: SPELL_HEAL_BY_SELF fires when the PLAYER is the caster (a self-cast heal, since
-- I.fromHeal's own filter on arg1==playerGuid then requires the player to ALSO be the target --
-- healing we cast on a party member is caster==player, target!=player, and is filtered out, same
-- as always); SPELL_HEAL_BY_OTHER fires when ANY OTHER unit is the caster, filtered the same way
-- on arg1==playerGuid. So yes -- Vampify DOES see foreign healing arriving on the player, via
-- SPELL_HEAL_BY_OTHER (nampower), and it was always being counted; it just was not being told
-- apart from a self-heal. That is exactly the "foreign healing that contaminates a group window"
-- this whole change is about, and it is now kept in its own running total (loggedExternal / the
-- EXTHEAL export line) instead of being folded into loggedSelf. No new event registration was
-- needed -- the two events were already both registered; only their dispatch was unified.
--
-- WANTED, NOT JUST ON/OFF (follow-up change request, 2026-08-22). There are now two
-- INDEPENDENT reasons this module's events might need to be registered: /vf watch (wants a
-- trustworthy HP-reconciliation BALANCE, which foreign healing/group play genuinely invalidates --
-- see core/watch.lua) and the per-hit debug export (core/perhit.lua; wants raw INC/SELFHEAL/
-- EXTHEAL lines regardless of group status, because the raw numbers are exactly what makes foreign
-- healing MEASURABLE instead of invisible). watchWanted and perhitWanted are tracked separately;
-- the underlying registration is active whenever EITHER is true (see WANTED below). A group join
-- clears ONLY watchWanted (I.isWatchOn() flips off, and core/commands.lua's addWindow call for the
-- watch balance is skipped) -- it does NOT touch perhitWanted, so the raw capture keeps running for
-- perhit even in a group. I.isOn() answers "is the capture running at all" (either reason);
-- I.isWatchOn() answers "is watch's OWN feature active" (core/commands.lua uses isOn() to gate the
-- window-tracking machinery itself, and isWatchOn() to gate feeding the watch balance).

VampifyIncoming = {}
local I = VampifyIncoming

local function num(v) return tonumber(v) or 0 end

-- The spell event carries its mitigation as a comma-joined STRING ("0,0,0"), not as numbers. The
-- all-zero case is the overwhelming majority and is compared as a whole, so the parse -- and its
-- allocations -- only happen on hits that actually mitigated something.
function I.mitigationOf(s)
    if type(s) ~= "string" or s == "0,0,0" or s == "" then return 0 end
    local total, from = 0, 1
    while true do
        local p = string.find(s, ",", from, true)
        if not p then
            total = total + num(string.sub(s, from))
            break
        end
        total = total + num(string.sub(s, from, p - 1))
        from = p + 1
    end
    return total
end

-- Returns the damage that actually left the health bar, or nil when the event was not about us.
--
-- WHETHER `amount` IS ALREADY NET IS UNMEASURED for the incoming direction. Subtracting mitigation
-- assumes it is gross. That assumption is not load-bearing: windows that took no damage at all form
-- a control branch in VampifyWatch, and if the two branches disagree, the reading is wrong rather
-- than the healing (see W.crossCheck). This is the one place where a wrong guess is caught rather
-- than believed.
function I.fromSpell(playerGuid, a1, a2, a3, a4, a5)
    if not playerGuid or a1 ~= playerGuid then return nil end
    local net = num(a4) - I.mitigationOf(a5)
    if net < 0 then return 0 end
    return net
end

-- AUTO_ATTACK_OTHER: 1 attacker 2 target 3 total 4 hitInfo 5 victimState 6 subDamageCount
--                    7 blocked 8 absorbed 9 resisted -- scalars here, unlike the spell event.
function I.fromAuto(playerGuid, a1, a2, a3, a4, a5, a6, a7, a8, a9)
    if not playerGuid or a2 ~= playerGuid then return nil end
    local net = num(a3) - num(a7) - num(a8) - num(a9)
    if net < 0 then return 0 end
    return net
end

-- SPELL_HEAL_BY_*: 1 target 2 caster 3 spellId 4 amount 5 critical 6 periodic. Which of self/
-- external this is comes from WHICH EVENT fired (BY_SELF vs BY_OTHER), not from arg2 -- see the
-- header comment. This function only answers "did it land on us", identically for both.
function I.fromHeal(playerGuid, a1, a2, a3, a4)
    if not playerGuid or a1 ~= playerGuid then return nil end
    return num(a4)
end

-- ---- running window totals ---------------------------------------------------------------------

local incoming, loggedSelf, loggedExternal = 0, 0, 0

function I.reset() incoming, loggedSelf, loggedExternal = 0, 0, 0 end

-- Reads the window's totals and starts the next one in the same breath. Three figures, no table:
-- this is called once per own hit, and an allocation there would be an allocation per hit.
function I.take()
    local a, b, c = incoming, loggedSelf, loggedExternal
    incoming, loggedSelf, loggedExternal = 0, 0, 0
    return a, b, c
end

function I.addIncoming(n) incoming = incoming + n end
function I.addSelfHeal(n) loggedSelf = loggedSelf + n end
function I.addExternalHeal(n) loggedExternal = loggedExternal + n end

-- ---- WoW wiring --------------------------------------------------------------------------------

local playerGuid = nil

-- The two independent "wants" (see the header comment) and the merged registration state they
-- resolve to. `on` mirrors the OLD single boolean's meaning exactly (is the capture running at
-- all), so I.isOn() keeps its old contract unchanged.
local watchWanted, perhitWanted, on = false, false, false

-- SuperWoW returns the GUID as the second value of UnitExists. Wrapped: without SuperWoW there is
-- no GUID, and then this whole subsystem has nothing to filter on and stays off.
local function readGuid()
    local g
    pcall(function() local _, gg = UnitExists("player"); g = gg end)
    return g
end

function I.playerGuid() return playerGuid end
function I.isOn() return on end
-- Watch's OWN feature state -- true only while the player asked for /vf watch on AND it is
-- actually running. False while only perhit wants the capture, even though I.isOn() is true then.
function I.isWatchOn() return watchWanted and on end

-- True while the player is in any group. The WATCH balance cannot survive foreign healing --
-- measured at +29..49 % phantom healing -- so for watch this is not a preference but a validity
-- condition. It says nothing about perhit, which wants the raw numbers (including foreign healing)
-- unconditionally -- see the header comment.
function I.inGroup()
    local r = GetNumRaidMembers and GetNumRaidMembers() or 0
    local p = GetNumPartyMembers and GetNumPartyMembers() or 0
    return (r > 0) or (p > 0)
end

local frame = nil

local EVENTS = {
    "SPELL_DAMAGE_EVENT_OTHER",
    "AUTO_ATTACK_OTHER",
    "SPELL_HEAL_BY_SELF",
    "SPELL_HEAL_BY_OTHER",
}

-- Registers/unregisters the underlying events to match (watchWanted OR perhitWanted). Returns
-- whether the capture ended up running -- false only when activation was needed but no GUID could
-- be obtained (no SuperWoW). Idempotent: a call that changes nothing is a no-op, so re-asserting a
-- want that is already satisfied does not re-read the GUID or touch the frame.
local function applyWanted()
    if not frame then return on end
    local want = (watchWanted or perhitWanted) and true or false
    if want == on then return on end
    if want then
        playerGuid = readGuid()
        if not playerGuid then return on end   -- nothing to filter on; stay off rather than
                                                -- process every foreign unit for nothing
        for i = 1, table.getn(EVENTS) do frame:RegisterEvent(EVENTS[i]) end
        I.reset()
        on = true
    else
        for i = 1, table.getn(EVENTS) do frame:UnregisterEvent(EVENTS[i]) end
        on = false
    end
    return on
end

-- Sets watch's own want and applies it. Return contract matches the old I.enable(want): turning
-- off always reports false (from watch's own perspective it succeeded -- the underlying wire may
-- stay hot for perhit, which is the whole point of this change); turning on reports whether
-- activation actually succeeded (false only on a missing GUID).
function I.setWatchWanted(want)
    want = want and true or false
    watchWanted = want
    applyWanted()
    if want then return on end
    return false
end

-- Sets perhit's want and applies it. Same activation semantics as setWatchWanted, just without a
-- group guard of its own -- perhit's caller (core/commands.lua) never refuses on group status.
function I.setPerHitWanted(want)
    want = want and true or false
    perhitWanted = want
    applyWanted()
    if want then return on end
    return false
end

if CreateFrame then
    frame = CreateFrame("Frame", "VampifyIncomingFrame")
    -- Registered even while the subsystem is off: the GUID has to be refreshed after every world
    -- load, and a group change invalidates watch's own mode at any time. Three events, not per-hit
    -- cost.
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    frame:RegisterEvent("RAID_ROSTER_UPDATE")
    frame:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            playerGuid = readGuid()
            return
        end
        -- This is the switch-off the header promises, but ONLY for watch's own want -- it must not
        -- touch perhitWanted, or a raid night would silently blind the per-hit export too (the
        -- follow-up change request this whole split exists for). Checking inGroup() inside the per-hit path
        -- would call GetNumRaidMembers/GetNumPartyMembers for every foreign unit in range, which
        -- costs more than the GUID compare it would precede -- so this stays event-driven.
        -- Announced rather than silent -- watch reports its own state via /vf watch, and a reader
        -- who never saw it change would read that as a bug. Not re-enabled automatically when the
        -- group breaks up: /vf watch on is one keystroke and stays the player's decision.
        if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
            if watchWanted and I.inGroup() then
                watchWanted = false
                applyWanted()
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff8080ffVampify|r watch: off -- you joined a"
                        .." group, and foreign healing makes the balance meaningless.")
                end
            end
            return
        end
        if not on then return end
        if event == "SPELL_DAMAGE_EVENT_OTHER" then
            local d = I.fromSpell(playerGuid, arg1, arg2, arg3, arg4, arg5)
            if d then incoming = incoming + d end
        elseif event == "AUTO_ATTACK_OTHER" then
            local d = I.fromAuto(playerGuid, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
            if d then incoming = incoming + d end
        elseif event == "SPELL_HEAL_BY_SELF" then
            local h = I.fromHeal(playerGuid, arg1, arg2, arg3, arg4)
            if h then loggedSelf = loggedSelf + h end
        else -- SPELL_HEAL_BY_OTHER
            local h = I.fromHeal(playerGuid, arg1, arg2, arg3, arg4)
            if h then loggedExternal = loggedExternal + h end
        end
    end)
end
