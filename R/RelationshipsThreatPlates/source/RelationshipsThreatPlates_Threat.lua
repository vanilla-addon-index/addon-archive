----------------------------------------------------------------------
-- RelationshipsThreatPlates_Threat.lua
-- Threat calculation bridge for WoW 1.12 (Vanilla API)
-- Works with Turtle WoW / Octo WoW threat hooks
-- Standalone - does not require Omen, KLHThreatMeter, or any lib
--
-- THREAT DATA SOURCES (in priority order):
--   1. UnitDetailedThreatSituation (Turtle WoW server extension)
--   2. GetThreatPercent API (custom server extension)
--   3. UnitThreatSituation (partial API on some servers)
--   4. ThreatEngine combat log parsing (precise per-1% values)
--   5. Target-based heuristic (crude fallback for edge cases only)
--
-- The ThreatEngine (RelationshipsThreatPlates_ThreatEngine.lua) parses combat log
-- events using GlobalStrings pattern matching to calculate accurate
-- absolute threat values per mob per player, then derives precise
-- percentages as (playerThreat / topThreat) * 100.
----------------------------------------------------------------------
-- CHANGES (multi-mob threat display fix):
--   * GetThreatPercent now checks ALL party/raid members' threat
--     on each mob, not just the player's own threat
--   * Added groupThreatCache: per-mob cache of best threat from
--     any group member, so ALL attacking mobs show accurate %
--   * Added ScanGroupThreat: iterates party/raid members against
--     each visible hostile mob using native threat APIs
--   * Added ThreatEngine group parsing: CHAT_MSG_SPELL_PARTY_*
--     and CHAT_MSG_SPELL_FRIENDLYPLAYER_* events now tracked
--   * Mobs attacking any group member now show threat bars,
--     not just mobs attacking the player
--   * Previous fixes preserved: UnitAffectingCombat checks,
--     idle mob filtering, Vanilla 1.12 compatibility
----------------------------------------------------------------------

local addon = RelationshipsThreatPlates

addon.Threat = {}

-- Cache for threat values per unit identifier (name-based in 1.12)
local threatCache = {}

-- Group-wide threat cache: groupThreatCache[mobUID] = {
--   bestPct, bestSit, bestSource, mobTargetName, lastUpdate,
--   playerPct, playerSit,
--   sources = { [sourceName] = { pct, sit } }
-- }
-- This stores the BEST threat from ANY group member for each mob,
-- so all attacking mobs show accurate percentages.
local groupThreatCache = {}

-- Player name cache
local playerName = nil

-- Party/raid member names cache: name -> unitToken
local partyNames = {}

-- Party/raid unit tokens cache (ordered list)
local partyUnits = {}

-- Update throttle (seconds)
local THROTTLE = 0.1
-- Cache of per-mob tank-mode details, keyed by mob UID (name in vanilla).
-- Populated by UpdateUnitThreat via ThreatEngine, and read by the Nameplates
-- module when rendering the tank-mode text (raw threat lead).
local tankDetailsCache = {}

-- ==================================================================
-- Safe API call helpers
-- ==================================================================
local function SafeCall2(func, a, b)
    if not func then return nil end
    local ok, r1 = pcall(func, a, b)
    if ok then return r1 end
    return nil
end

local function SafeCall5(func, a, b)
    if not func then return nil, nil, nil, nil, nil end
    local ok, r1, r2, r3, r4, r5 = pcall(func, a, b)
    if ok then return r1, r2, r3, r4, r5 end
    return nil, nil, nil, nil, nil
end

-- ==================================================================
-- Detect which threat APIs are available at runtime
-- ==================================================================
local hasUnitDetailedThreatSituation = false
local hasGetThreatPercent = false
local hasUnitThreatSituation = false

local function DetectThreatAPIs()
    hasUnitDetailedThreatSituation = (UnitDetailedThreatSituation ~= nil)
    hasGetThreatPercent = (GetThreatPercent ~= nil)
    hasUnitThreatSituation = (UnitThreatSituation ~= nil)

    if hasUnitDetailedThreatSituation then
        addon:ui_print("UnitDetailedThreatSituation detected")
    end
    if hasGetThreatPercent then
        addon:ui_print("GetThreatPercent detected")
    end
    if hasUnitThreatSituation then
        addon:ui_print("UnitThreatSituation detected")
    end
    if not hasUnitDetailedThreatSituation and not hasGetThreatPercent and not hasUnitThreatSituation then
        addon:ui_print("No native threat API - using combat log parsing + heuristic")
    end
end

-- ==================================================================
-- Cache party/raid member names for threat heuristic
-- ==================================================================
local function UpdatePartyNames()
    partyNames = {}
    partyUnits = {}
    -- Player
    if playerName then
        partyNames[playerName] = "player"
        partyUnits[1] = "player"
    end
    -- Party
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            local ok, name = pcall(UnitName, unit)
            if ok and name then
                partyNames[name] = unit
                partyUnits[table.getn(partyUnits) + 1] = unit
            end
        end
    end
    -- Raid
    for i = 1, 40 do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local ok, name = pcall(UnitName, unit)
            if ok and name then
                partyNames[name] = unit
                partyUnits[table.getn(partyUnits) + 1] = unit
            end
        end
    end
end

-- ==================================================================
-- Scan group threat: check all party/raid members' threat on
-- a specific mob unit using native threat APIs.
--
-- Returns: bestPct, bestSit, bestSourceName, playerPct, playerSit
--   bestPct = highest threat % from any group member
--   bestSit = threat situation of the member with highest threat
--   bestSourceName = name of the group member with highest threat
--   playerPct = the player's own threat % on this mob
--   playerSit = the player's own threat situation
--
-- If no native APIs are available, returns nil (caller should
-- fall through to ThreatEngine / heuristic).
-- ==================================================================
local function ScanGroupThreatOnUnit(mobUnit)
    if not mobUnit or not UnitExists(mobUnit) then
        return nil
    end

    -- Only scan if at least one native threat API is available
    if not hasUnitDetailedThreatSituation and not hasGetThreatPercent
       and not hasUnitThreatSituation then
        return nil
    end

    local bestPct = 0
    local bestSit = 0
    local bestSource = nil
    local playerPct = 0
    local playerSit = 0

    for i = 1, table.getn(partyUnits) do
        local groupUnit = partyUnits[i]
        if UnitExists(groupUnit) then
            local memberPct = nil
            local memberSit = nil

            -- Method 1: UnitDetailedThreatSituation
            if hasUnitDetailedThreatSituation then
                local isTanking, status, scaledPct, rawPct, threatVal =
                    SafeCall5(UnitDetailedThreatSituation, groupUnit, mobUnit)
                if rawPct then
                    memberPct = math.min(100, math.max(0, rawPct))
                    memberSit = status or 0
                end
            end

            -- Method 2: GetThreatPercent
            if not memberPct and hasGetThreatPercent then
                local pct = SafeCall2(GetThreatPercent, groupUnit, mobUnit)
                if pct then
                    memberPct = math.min(100, math.max(0, pct))
                    if hasUnitThreatSituation then
                        memberSit = SafeCall2(UnitThreatSituation, groupUnit, mobUnit) or 0
                    else
                        if memberPct >= 100 then memberSit = 3
                        elseif memberPct >= 60 then memberSit = 2
                        elseif memberPct >= 30 then memberSit = 1
                        else memberSit = 0 end
                    end
                end
            end

            -- Method 3: UnitThreatSituation
            if not memberPct and hasUnitThreatSituation then
                memberSit = SafeCall2(UnitThreatSituation, groupUnit, mobUnit) or 0
                if memberSit == 0 then
                    memberPct = 0
                elseif memberSit == 1 then
                    memberPct = 25
                elseif memberSit == 2 then
                    memberPct = 60
                elseif memberSit == 3 then
                    memberPct = 100
                end
            end

            if memberPct then
                -- Track player's own threat specifically
                if groupUnit == "player" then
                    playerPct = memberPct
                    playerSit = memberSit or 0
                end

                -- Track the best threat from any group member
                if memberPct > bestPct then
                    bestPct = memberPct
                    bestSit = memberSit or 0
                    local ok, name = pcall(UnitName, groupUnit)
                    bestSource = (ok and name) or groupUnit
                end
            end
        end
    end

    return bestPct, bestSit, bestSource, playerPct, playerSit
end

-- ==================================================================
-- Check if a name belongs to a party/raid member
-- Returns: true if the name is a group member, false otherwise
-- ==================================================================
function addon.Threat:IsPartyMember(name)
    if not name then return false end
    if name == playerName then return true end
    if partyNames[name] then return true end
    return false
end

-- ==================================================================
-- Initialize threat module
-- ==================================================================
function addon.Threat:Initialize()
    playerName = UnitName("player")

    -- Detect available APIs
    DetectThreatAPIs()

    -- Cache party names
    UpdatePartyNames()

    -- Polling frame for periodic threat updates
    self.pollFrame = CreateFrame("Frame", "RelationshipsThreatPlatesPollFrame")
    self.pollFrame.elapsed = 0
    self.pollFrame:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= THROTTLE then
            this.elapsed = 0
            addon.Threat:PollThreat()
        end
    end)

    -- Event frame for threat-related events
    local eventFrame = CreateFrame("Frame", "RelationshipsThreatPlatesEventFrame")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")

    -- Safely register threat event only if API exists
    if hasUnitThreatSituation or hasUnitDetailedThreatSituation then
        eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    end

    eventFrame:SetScript("OnEvent", function()
        addon.Threat:OnEvent(event)
    end)

    self.eventFrame = eventFrame
end

-- ==================================================================
-- Event handler
-- ==================================================================
function addon.Threat:OnEvent(ev)
    if ev == "PLAYER_TARGET_CHANGED" then
        self:PollThreat()
    elseif ev == "UNIT_THREAT_SITUATION_UPDATE" then
        local unit = arg1
        if unit and UnitExists(unit) then
            self:UpdateUnitThreat(unit)
        end
    elseif ev == "PARTY_MEMBERS_CHANGED" or ev == "RAID_ROSTER_UPDATE" then
        UpdatePartyNames()
        self:PollThreat()
    end
end

-- ==================================================================
-- Poll threat for all visible nameplates
-- ==================================================================
function addon.Threat:PollThreat()
    if not RelationshipsThreatPlatesDB or not RelationshipsThreatPlatesDB.enabled then
        return
    end

    for nameplate, data in pairs(addon.Nameplates.plates) do
        if nameplate:IsVisible() and data.unit then
            self:UpdateUnitThreat(data.unit)
        end
    end
end

-- ==================================================================
-- Get threat percentage for a unit
-- Returns: threatPct (0-100), threatSit (0-3)
--
-- PRIORITY:
--   1. Group-wide scan via UnitDetailedThreatSituation (Turtle WoW)
--   2. Group-wide scan via GetThreatPercent API (custom extension)
--   3. Group-wide scan via UnitThreatSituation (partial API)
--   4. ThreatEngine combat log data (precise per-1% values)
--   5. Target-based heuristic (crude fallback only)
--
-- KEY CHANGE: Methods 1-3 now check ALL party/raid members' threat
-- on the mob, not just the player. This ensures that:
--   - Mobs attacking the player show the player's threat %
--   - Mobs attacking party members show those members' threat %
--   - ALL mobs in combat with the group show accurate threat bars
----------------------------------------------------------------------

function addon.Threat:GetThreatPercent(unit)
    if not unit or not UnitExists(unit) then
        return 0, 0
    end

    -- ==============================================================
    -- Pre-filter: Only check threat for hostile, in-combat mobs
    -- These checks apply regardless of which method we use below.
    -- ==============================================================

    -- Only check threat for hostile units
    local reaction = UnitReaction(unit, "player")
    if reaction and reaction > 4 then
        -- Friendly unit - no threat display
        return 0, 0
    end

    -- Check if player OR any group member is in combat.
    -- CRITICAL FIX: Previously only checked UnitAffectingCombat("player"),
    -- which meant mobs attacking party members showed no threat when the
    -- player wasn't in combat. Now we check the entire group.
    local playerInCombat = UnitAffectingCombat("player")
    local groupInCombat = addon.ThreatEngine:IsGroupInCombat()

    -- The MOB itself must be in combat.
    local ok_mc, mobCombat = pcall(UnitAffectingCombat, unit)
    if ok_mc and not mobCombat then
        return 0, 0
    end

    -- Verify this is a hostile unit the player can attack
    local ok_ca, canAttack = pcall(UnitCanAttack, "player", unit)
    if ok_ca and not canAttack then
        -- Also check if any group member can attack it
        local groupCanAttack = false
        for i = 1, table.getn(partyUnits) do
            local ok_gca, gca = pcall(UnitCanAttack, partyUnits[i], unit)
            if ok_gca and gca then
                groupCanAttack = true
                break
            end
        end
        if not groupCanAttack then
            return 0, 0
        end
    end

    -- Get mob name and who the mob is targeting (used by multiple methods)
    local ok_name, mobName = pcall(UnitName, unit)
    if not ok_name or not mobName then
        return 0, 0
    end

    local mobTargetName = nil
    local ok_mt, mt = pcall(UnitName, unit .. "target")
    if ok_mt and mt then
        mobTargetName = mt
    end

    -- ==============================================================
    -- Methods 1-3: Group-wide native threat API scan
    -- Check ALL party/raid members' threat on this mob.
    -- This is the KEY fix: instead of only checking the player's
    -- threat, we check every group member and return the best.
    -- ==============================================================

    if hasUnitDetailedThreatSituation or hasGetThreatPercent or hasUnitThreatSituation then
        local bestPct, bestSit, bestSource, playerPct, playerSit =
            ScanGroupThreatOnUnit(unit)

        if bestPct and bestPct > 0 then
            -- We have threat data from at least one group member.

            -- Determine whose threat to display:
            -- If the mob is targeting the player -> show player's threat
            -- If the mob is targeting a group member -> show that member's threat
            -- If the mob is targeting an outsider -> show player's threat
            -- Otherwise -> show the best (highest) threat from any member

            -- The threat bar on a nameplate is always displayed from the
            -- PLAYER's point of view: "how close am I to pulling aggro
            -- off whoever currently has it?". Showing another group
            -- member's percentage would incorrectly make every mob a
            -- party member is tanking read as 100% — that is the bug
            -- users describe as "snap causes all party-combat enemies
            -- to show 100%". So: always return the player's own value
            -- here. If the player has no threat on this mob, return 0
            -- so the bar hides.

            if mobTargetName == playerName then
                -- Mob is attacking the player - show player's own threat
                return playerPct, playerSit
            elseif mobTargetName and partyNames[mobTargetName] then
                -- Mob is attacking a group member. Show the player's
                -- own relative threat, not the party member's.
                if playerPct > 0 then
                    return playerPct, playerSit
                end
                -- Player has no threat yet, but a party member is in
                -- the aggro seat. Show a low visible bar so the plate
                -- is still displayed (bar hides completely at pct=0).
                return 8, 0
            else
                -- Mob targets an outsider, or we can't see its target.
                -- Show player's own threat only.
                if playerPct > 0 then
                    return playerPct, playerSit
                end
                -- Fall through: let ThreatEngine / heuristic decide
                -- below instead of hiding the bar outright.
            end
        end

        -- All group members have 0 threat on this mob via native APIs,
        -- but the mob IS in combat. This can happen if:
        --   - Only ThreatEngine has data (combat log parsing)
        --   - The mob is fighting an outsider
        --   - The mob was just pulled and the API hasn't updated yet
        -- Fall through to ThreatEngine / heuristic below.
    end

    -- ==============================================================
    -- Method 4: ThreatEngine combat log parsing
    -- This provides precise per-1% threat values based on actual
    -- damage/healing/ability threat tracked from the combat log.
    -- This is the PRIMARY method on servers without native APIs.
    --
    -- KEY FIX: Now uses group combat state instead of only player combat.
    -- If any group member is in combat, ThreatEngine data is relevant.
    -- ==============================================================

    -- Someone in the group must be in combat for ThreatEngine data
    -- to be relevant. This prevents threat bars on idle mobs when
    -- no one in the group is fighting.
    if not groupInCombat then
        return 0, 0
    end

    -- If the mob targets an outsider (someone not in the
    -- player's party/raid), verify the player has actually engaged
    -- this mob personally before showing any threat bar.
    if mobTargetName and mobTargetName ~= playerName and not partyNames[mobTargetName] then
        -- Mob targets someone outside our group.
        -- Check if the player has personally hit this mob.
        -- If player has 0 threat on this mob, don't show a bar.
        local playerThreat = addon.ThreatEngine:GetPlayerThreat(mobName)
        if playerThreat <= 0 then
            return 0, 0
        end
        -- Player has some threat but mob targets an outsider.
        -- The player's threat is secondary - show it but reduced.
        -- We can't know the outsider's threat, so estimate conservatively.
        -- Use ThreatEngine data if available, otherwise heuristic.
        local enginePct, engineSit, _, _, hasGroupData = addon.ThreatEngine:GetThreatOnTarget(mobName)
        if enginePct > 0 then
            if hasGroupData then
                return enginePct, engineSit
            end
            -- Solo data only - the outsider probably has more threat.
            -- Cap our displayed percentage conservatively.
            if enginePct >= 100 then
                return 80, 2
            end
            return enginePct, engineSit
        end
        -- No ThreatEngine data but player is hitting it - rough estimate
        if UnitIsUnit("target", unit) then
            return 40, 1
        end
        return 20, 0
    end

    -- Query ThreatEngine with the mob's name
    local enginePct, engineSit, enginePlayerThreat, engineTopThreat, hasGroupData =
        addon.ThreatEngine:GetThreatOnTarget(mobName)

    if enginePct > 0 then
        if hasGroupData then
            -- We have threat data from multiple sources (group broadcasts).
            -- The percentage is reliable - use it directly.
            return enginePct, engineSit
        end

        -- ThreatEngine only has the player's own threat data (no group
        -- broadcasts). Cross-reference with mob's target to calibrate.
        if mobTargetName then
            if mobTargetName == playerName then
                -- Mob targets the player AND player has threat data.
                -- Player really does have aggro. Since we only know our
                -- own threat and we're the top, show as 100%.
                return 100, 3
            elseif partyNames[mobTargetName] then
                -- Mob targets a PARTY/RAID member. The player doesn't
                -- have aggro but does have some threat. Show the
                -- ThreatEngine percentage as the player's relative threat.
                -- This is much better than the old fixed 60%/30% estimate.
                return enginePct, engineSit
            else
                -- Mob targets an outsider - show conservative estimate
                if enginePct >= 100 then
                    return 90, 2
                end
                return enginePct, engineSit
            end
        else
            -- Can't see mob's target. Show raw ThreatEngine data
            -- but cap at 90% since we can't confirm we have aggro.
            if enginePct >= 100 then
                return 90, 2
            end
            return enginePct, engineSit
        end
    end

    -- ==============================================================
    -- Method 5: Target-based heuristic (last resort fallback)
    -- Only used when ThreatEngine has NO data for a mob.
    -- This can happen for: newly engaged mobs, mobs in combat with
    -- other players outside our group, or very brief encounters.
    --
    -- This is the MOST RELIABLE heuristic in Vanilla WoW:
    -- Who is the mob targeting? That person has aggro.
    --
    -- KEY CHANGE: Now properly handles party/raid members.
    -- If the mob is targeting a group member, we show a high
    -- threat bar (that member has aggro), not a low estimate.
    -- ==============================================================

    -- Check if the mob is targeting someone
    if mobTargetName then
        if mobTargetName == playerName then
            -- Mob is targeting the PLAYER - player has AGGRO (100%)
            threatPct = 100
            situation = 3
        elseif partyNames[mobTargetName] then
            -- Mob is targeting a PARTY/RAID member. The party member
            -- has aggro, NOT the player. Showing 100% here would
            -- incorrectly light every mob in party combat up as full
            -- aggro on the player. Show a low estimate instead — the
            -- player is not in the aggro seat, but the bar must still
            -- be visible so users know the mob is engaged.
            if UnitIsUnit("target", unit) then
                threatPct = 20
                situation = 0
            else
                threatPct = 8
                situation = 0
            end
        else
            -- Mob is targeting someone outside the party
            -- (another player, a pet, etc.)
            if UnitIsUnit("target", unit) then
                threatPct = 40
                situation = 1
            else
                threatPct = 15
                situation = 0
            end
        end
    else
        -- Mob's target is nil. We already know it's in combat.
        -- This happens when someone outside our group has aggro
        -- or the mob is between targets.
        if UnitIsUnit("target", unit) then
            threatPct = 40
            situation = 1
        else
            threatPct = 10
            situation = 0
        end
    end

    return threatPct, situation
end

-- ==================================================================
-- Update threat for a specific unit and notify nameplates
-- ==================================================================
function addon.Threat:UpdateUnitThreat(unit)
    if not unit or not UnitExists(unit) then return end

    local pct, situation = self:GetThreatPercent(unit)
    local uid = addon:GetUnitID(unit)

    if uid then
        -- Get mob target info for group context
        local mobTargetName = nil
        local ok_mt, mt = pcall(UnitName, unit .. "target")
        if ok_mt and mt then
            mobTargetName = mt
        end

        -- ------------------------------------------------------------
        -- TARGET-SNAP override: if the mob is currently targeting the
        -- player, force display to 100% (aggro). Some mobs pick focused
        -- / random targets regardless of threat, so the plate should
        -- immediately snap to 100% while targeted, and fall back to the
        -- real threat % when the mob switches targets.
        -- ------------------------------------------------------------
        local targetSnapped = false
        if RelationshipsThreatPlatesDB and RelationshipsThreatPlatesDB.targetSnap100
           and mobTargetName and playerName and mobTargetName == playerName then
            local ok_pc, pc = pcall(UnitAffectingCombat, "player")
            if ok_pc and pc then
                -- Player is being targeted, so they have aggro. Force
                -- pct to at least 100 without clobbering a real value
                -- above 100 (which happens when the player is top and
                -- well ahead of the second-highest threat holder).
                if not pct or pct < 100 then
                    pct = 100
                end
                situation = 3
                targetSnapped = true
            end
        end

        -- ------------------------------------------------------------
        -- Compute raw tank-mode details (player threat vs 2nd highest).
        -- Uses ThreatEngine's combat-log-parsed absolute values when
        -- available. This is what the nameplate renders in Tank Mode.
        -- ------------------------------------------------------------
        local ok_mn, mobName = pcall(UnitName, unit)
        if ok_mn and mobName then
            local ePct, eSit, ePlayerThreat, eTopThreat, eHasGroup, eTopPlayer, eSecondThreat =
                addon.ThreatEngine:GetThreatOnTarget(mobName)

            tankDetailsCache[uid] = {
                playerThreat  = ePlayerThreat or 0,
                topThreat     = eTopThreat or 0,
                secondThreat  = eSecondThreat or 0,
                topPlayer     = eTopPlayer,
                hasAggro      = (eTopPlayer == playerName) or targetSnapped,
                hasGroupData  = eHasGroup or false,
                targetSnapped = targetSnapped,
                mobTargetName = mobTargetName,
                lastUpdate    = GetTime(),
            }
        end

        threatCache[uid] = {
            pct = pct,
            situation = situation,
            unit = unit,
            lastUpdate = GetTime(),
            mobTargetName = mobTargetName,
            targetSnapped = targetSnapped,
        }

        -- Also store in group threat cache for cross-reference
        groupThreatCache[uid] = {
            bestPct = pct,
            bestSit = situation,
            mobTargetName = mobTargetName,
            lastUpdate = GetTime(),
        }

        addon.Nameplates:UpdateThreatForUnit(unit, pct, situation)
    end
end

-- ==================================================================
-- Get cached threat for a unit identifier
-- ==================================================================
function addon.Threat:GetCachedThreat(uid)
    if not uid then return 0, 0 end
    local cache = threatCache[uid]
    if cache then
        if GetTime() - cache.lastUpdate < 5 then
            return cache.pct, cache.situation
        end
    end
    return 0, 0
end

-- ==================================================================
-- Tank-mode details for a mob (by UID / name in vanilla).
-- Returns a table (or nil) with:
--   playerThreat, topThreat, secondThreat, topPlayer,
--   hasAggro, hasGroupData, targetSnapped, mobTargetName
-- ==================================================================
function addon.Threat:GetTankDetails(uid)
    if not uid then return nil end
    local d = tankDetailsCache[uid]
    if not d then return nil end
    if GetTime() - d.lastUpdate > 5 then return nil end
    return d
end

-- ==================================================================
-- Format a raw threat value as a compact signed string.
-- Examples: 12345 -> "+12.3K", -845 -> "-845", 0 -> "0"
-- ==================================================================
function addon.Threat:FormatThreatLead(v)
    if not v then return "--" end
    local a = math.abs(v)
    local sign = ""
    if v > 0 then sign = "+" elseif v < 0 then sign = "-" end
    if a >= 100000 then
        return sign .. string.format("%.0fK", a / 1000)
    elseif a >= 10000 then
        return sign .. string.format("%.1fK", a / 1000)
    elseif a >= 1000 then
        return sign .. string.format("%.2fK", a / 1000)
    else
        return sign .. string.format("%d", a)
    end
end

-- ==================================================================
-- Return the display string for tank mode given a plate's mob name.
-- Uses the ThreatEngine directly (works even without a unit token,
-- e.g. for unique-name plates).
-- Returns: string like "+1.20K" or "-450", or "--" if unknown.
-- ==================================================================
function addon.Threat:GetTankDisplayForMob(mobName)
    if not mobName then return "--" end
    local d = tankDetailsCache[mobName]
    if not d or (GetTime() - d.lastUpdate > 5) then
        -- Query ThreatEngine on demand (no cache hit).
        local _, _, playerThreat, topThreat, _, topPlayer, secondThreat =
            addon.ThreatEngine:GetThreatOnTarget(mobName)
        if not playerThreat or playerThreat <= 0 then
            return "--"
        end
        local lead
        if topPlayer == playerName then
            lead = playerThreat - (secondThreat or 0)
        else
            lead = playerThreat - (topThreat or 0)
        end
        return self:FormatThreatLead(lead)
    end

    if d.playerThreat <= 0 then return "--" end
    local lead
    if d.hasAggro then
        lead = d.playerThreat - (d.secondThreat or 0)
    else
        lead = d.playerThreat - (d.topThreat or 0)
    end
    return self:FormatThreatLead(lead)
end


-- ==================================================================
-- Get threat percentage by mob NAME (no unit token required)
-- This is the fallback for when FindUnitByName couldn't resolve
-- a unit token for a nameplate.
--
-- CRITICAL FIX for same-name mob confusion:
--   In Vanilla 1.12 there is no UnitGUID. Multiple mobs with the
--   same name (e.g. "Defias Bandit") all share one ThreatEngine
--   entry. If we return threat data by name alone, idle same-name
--   mobs will incorrectly show threat bars.
--
--   Solution: GetThreatByName now REQUIRES finding a unit token
--   that is verified to be in combat. If no combat-verified unit
--   token can be found for the given name, it returns 0, 0.
--   This ensures idle mobs never get threat data.
--
-- Returns: threatPct (0-100), threatSit (0-3)
-- ==================================================================
function addon.Threat:GetThreatByName(mobName)
    if not mobName or strlen(mobName) == 0 then
        return 0, 0
    end

    -- KEY FIX: Only require that SOMEONE in the group is in combat,
    -- not necessarily the player. This allows threat bars to show
    -- on mobs attacking party/raid members even when the player
    -- isn't in combat themselves.
    if not addon.ThreatEngine:IsGroupInCombat() then
        return 0, 0
    end

    -- ==============================================================
    -- Step 1: Try to find a combat-verified unit token.
    -- If we can find one and verify it's in combat, use the full
    -- GetThreatPercent which has all the proper checks.
    -- ==============================================================

    local unitTokens = {
        "target", "mouseover", "targettarget", "pet",
    }

    for i = 1, 4 do
        unitTokens[table.getn(unitTokens) + 1] = "party" .. i .. "target"
        unitTokens[table.getn(unitTokens) + 1] = "party" .. i .. "targettarget"
    end

    for i = 1, 40 do
        unitTokens[table.getn(unitTokens) + 1] = "raid" .. i .. "target"
        unitTokens[table.getn(unitTokens) + 1] = "raid" .. i .. "targettarget"
    end

    -- Search for a unit token that matches the name AND is in combat
    for i = 1, table.getn(unitTokens) do
        local token = unitTokens[i]
        local ok, exists = pcall(UnitExists, token)
        if ok and exists then
            local ok2, name = pcall(UnitName, token)
            if ok2 and name and name == mobName then
                local ok3, inCombat = pcall(UnitAffectingCombat, token)
                if ok3 and inCombat then
                    local pct, sit = self:GetThreatPercent(token)
                    return pct, sit
                end
            end
        end
    end

    -- ==============================================================
    -- Step 2: No combat-verified unit token found.
    --
    -- For UNIQUE-name mobs (only 1 plate with this name visible),
    -- the ThreatEngine data IS unambiguous — there's only one mob
    -- with this name, so the threat data is definitely about it.
    -- We can use ThreatEngine data directly.
    --
    -- For SAME-name mobs (multiple plates share this name), we
    -- CANNOT use ThreatEngine data without a unit token because
    -- it would apply the same threat to all same-name plates,
    -- including idle ones.
    --
    -- The caller (UpdateAllPlates) decides whether a name is
    -- unique. GetThreatByName is ONLY called for unique names
    -- from UpdateAllPlates, so it's safe to use ThreatEngine here.
    -- ==============================================================

    if addon.ThreatEngine:HasDataForTarget(mobName) then
        local enginePct, engineSit, _, _, hasGroupData =
            addon.ThreatEngine:GetThreatOnTarget(mobName)

        if enginePct > 0 then
            -- We have ThreatEngine data for this unique-name mob.
            -- Cap at 90% since we can't verify who has aggro
            -- without seeing the mob's target.
            if enginePct >= 100 then
                return 90, 2
            end
            return enginePct, engineSit
        end
    end

    -- No ThreatEngine data either. This mob likely hasn't been
    -- engaged by the player. Return 0.
    return 0, 0
end

-- ==================================================================
-- Check if a mob is attacking any group member
-- Returns: the name of the group member being attacked, or nil
-- ==================================================================
function addon.Threat:GetMobTarget(mobUnit)
    if not mobUnit or not UnitExists(mobUnit) then
        return nil
    end

    local ok, targetName = pcall(UnitName, mobUnit .. "target")
    if ok and targetName then
        if targetName == playerName or partyNames[targetName] then
            return targetName
        end
    end
    return nil
end

-- ==================================================================
-- Get cached group threat for a unit identifier
-- Returns: bestPct, bestSit, mobTargetName
-- ==================================================================
function addon.Threat:GetGroupCachedThreat(uid)
    if not uid then return 0, 0, nil end
    local cache = groupThreatCache[uid]
    if cache then
        if GetTime() - cache.lastUpdate < 5 then
            return cache.bestPct, cache.bestSit, cache.mobTargetName
        end
    end
    return 0, 0, nil
end

-- ==================================================================
-- Clear all threat data
-- ==================================================================
function addon.Threat:ClearAll()
    threatCache = {}
    groupThreatCache = {}
end
