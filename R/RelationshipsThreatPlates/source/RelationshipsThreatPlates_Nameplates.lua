----------------------------------------------------------------------
-- RelationshipsThreatPlates_Nameplates.lua
-- Nameplate scanning, hooking, and threat bar creation
-- Creates Kui Nameplates-style threat bars above health bars
-- Standalone for WoW 1.12 (Vanilla / Turtle WoW / Octo WoW)
----------------------------------------------------------------------

local addon = RelationshipsThreatPlates

addon.Nameplates = {}

-- Plate registry: nameplate frame -> our data
addon.Nameplates.plates = {}

-- Known nameplates cache (to avoid re-scanning)
local knownPlates = {}

-- Solid texture path for all bar visuals
local SOLID_TEXTURE = "Interface\\Buttons\\WHITE8x8"

-- Font path
local FONT_PATH = "Fonts\\FRIZQT__.TTF"

-- ==================================================================
-- Helpers for same-name mob handling
-- ==================================================================

local function GetPlateNameText(data, nameplate)
    local name = nil

    -- Try the stored FontString reference first
    if data and data.nameFontString then
        local ok, txt = pcall(data.nameFontString.GetText, data.nameFontString)
        if ok and txt and strlen(txt) > 0 then
            name = txt
        end
    end

    -- Fallback: scan regions for FontString
    if (not name or strlen(name) == 0) and nameplate then
        local regions = { nameplate:GetRegions() }
        local numRegions = table.getn(regions)
        for j = 1, numRegions do
            local region = regions[j]
            if region then
                local ok, objType = pcall(region.GetObjectType, region)
                if ok and objType == "FontString" then
                    local ok2, txt = pcall(region.GetText, region)
                    if ok2 and txt and strlen(txt) > 0 and strlen(txt) < 60 then
                        name = txt
                        break
                    end
                end
            end
        end
    end

    return name
end

local function GetPlateHealthPercent(data)
    if not data or not data.healthBar then return nil end

    local okMinMax, minVal, maxVal = pcall(data.healthBar.GetMinMaxValues, data.healthBar)
    local okValue, value = pcall(data.healthBar.GetValue, data.healthBar)

    if not okMinMax or not okValue then return nil end
    if not maxVal or maxVal <= minVal then return nil end

    return ((value - minVal) / (maxVal - minVal)) * 100
end

local function GetUnitHealthPercent(unit)
    if not unit or not UnitExists(unit) then return nil end

    local okCur, cur = pcall(UnitHealth, unit)
    local okMax, maxVal = pcall(UnitHealthMax, unit)

    if not okCur or not okMax then return nil end
    if not maxVal or maxVal <= 0 then return nil end

    return (cur / maxVal) * 100
end

local function IsSameUnitToken(unitA, unitB)
    if not unitA or not unitB then return false end
    if unitA == unitB then return true end
    if UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, unitA, unitB)
        if ok and same then
            return true
        end
    end
    return false
end

-- ==================================================================
-- Health-change based combat detection for nameplates.
--
-- In Vanilla 1.12, non-targeted mobs often have NO unit token.
-- The only way to know they're in combat is by observing their
-- nameplate health bar decreasing. If a mob's health is going
-- down, it's in combat. If it's stable at 100%, it's idle.
--
-- This is the KEY technique that makes multi-mob threat display
-- work without unit tokens, while still filtering idle same-name
-- mobs (whose health stays at 100%).
-- ==================================================================

local function IsPlateInCombat(data)
    if not data then return false end

    -- Method 1: If we have a unit token, use the API directly
    if data.unit and UnitExists(data.unit) then
        local ok, inCombat = pcall(UnitAffectingCombat, data.unit)
        if ok then
            return inCombat
        end
    end

    -- Method 2: Health-change detection.
    -- If the plate's health bar has decreased since last check,
    -- the mob is definitely in combat (taking damage).
    -- We track previousHealth for comparison.
    local currentHealth = GetPlateHealthPercent(data)

    if currentHealth == nil then
        -- Can't read health bar — assume not in combat
        return false
    end

    -- If health is significantly below 100%, the mob has been damaged
    -- and is almost certainly in combat.
    if currentHealth < 98 then
        return true
    end

    -- If health decreased since last check, the mob is taking damage
    -- right now — definitely in combat.
    if data.previousHealth and currentHealth < data.previousHealth - 0.5 then
        return true
    end

    -- Health is near 100% and stable — likely idle.
    -- Exception: a freshly body-pulled mob might be at full health
    -- briefly. We handle this with a grace period in UpdateAllPlates.
    return false
end

function addon.Nameplates:GetCandidateUnitsByName(name)
    local candidates = {}
    if not name then return candidates end

    local unitTokens = { "target", "mouseover", "targettarget", "pet" }

    for i = 1, 4 do
        unitTokens[table.getn(unitTokens) + 1] = "party" .. i .. "target"
        unitTokens[table.getn(unitTokens) + 1] = "party" .. i .. "targettarget"
    end

    for i = 1, 40 do
        unitTokens[table.getn(unitTokens) + 1] = "raid" .. i .. "target"
        unitTokens[table.getn(unitTokens) + 1] = "raid" .. i .. "targettarget"
    end

    for i = 1, table.getn(unitTokens) do
        local unit = unitTokens[i]
        local ok, exists = pcall(UnitExists, unit)
        if ok and exists then
            local ok2, uname = pcall(UnitName, unit)
            if ok2 and uname and uname == name then
                local duplicate = false
                for j = 1, table.getn(candidates) do
                    if IsSameUnitToken(candidates[j].unit, unit) then
                        duplicate = true
                        break
                    end
                end

                if not duplicate then
                    local okCombat, inCombat = pcall(UnitAffectingCombat, unit)
                    local okAttack, canAttack = pcall(UnitCanAttack, "player", unit)
                    candidates[table.getn(candidates) + 1] = {
                        unit = unit,
                        healthPct = GetUnitHealthPercent(unit),
                        inCombat = okCombat and inCombat or false,
                        canAttack = okAttack and canAttack or nil,
                    }
                end
            end
        end
    end

    return candidates
end

local function ScoreCandidateForPlate(data, candidate)
    if not data or not candidate then return -999999 end

    local score = 0
    local platePct = GetPlateHealthPercent(data)

    -- MANDATORY: If candidate is NOT in combat, heavily penalize.
    -- This prevents idle same-name mobs from getting assigned
    -- combat-unit tokens and showing incorrect threat bars.
    if not candidate.inCombat then
        score = score - 5000
    end

    -- Check if the plate's health bar is at 100% (likely idle mob)
    -- A mob at full health that hasn't been damaged is very likely idle.
    local plateLooksIdle = false
    if platePct and platePct >= 99.5 then
        plateLooksIdle = true
    end

    -- If plate looks idle but candidate is in combat, this is a
    -- mismatch — the combat unit is probably a DIFFERENT mob with
    -- the same name that has been damaged.
    if plateLooksIdle and candidate.inCombat then
        score = score - 3000
    end

    -- If plate looks damaged and candidate is in combat, great match
    if not plateLooksIdle and candidate.inCombat then
        score = score + 500
    end

    -- If plate looks idle and candidate is also idle, they might match
    -- (but we'll still hide the bar later since idle = no threat)
    if plateLooksIdle and not candidate.inCombat then
        score = score + 50
    end

    -- Previous unit continuity bonus
    if data._previousUnit and IsSameUnitToken(data._previousUnit, candidate.unit) then
        score = score + 1000
    end

    -- Health percentage matching — the STRONGEST discriminator for
    -- same-name mobs. If the plate shows 72% health and the unit
    -- token reports 72% health, they're almost certainly the same mob.
    if platePct and candidate.healthPct then
        local diff = math.abs(platePct - candidate.healthPct)
        score = score + math.max(0, 500 - (diff * 15))
    end

    -- CanAttack check
    if candidate.canAttack == false then
        score = score - 1000
    end

    return score
end

function addon.Nameplates:ResolveVisiblePlateUnits()
    local platesByName = {}

    for nameplate, data in pairs(self.plates) do
        data._previousUnit = data.unit
        data.unit = nil
        data.guid = nil

        if nameplate:IsVisible() then
            local name = GetPlateNameText(data, nameplate)
            if name and strlen(name) > 0 then
                data.plateName = name
                if not platesByName[name] then
                    platesByName[name] = {}
                end
                platesByName[name][table.getn(platesByName[name]) + 1] = data
            else
                data.plateName = nil
            end
        else
            data.plateName = nil
        end
    end

    for name, plates in pairs(platesByName) do
        local candidates = self:GetCandidateUnitsByName(name)
        local plateCount = table.getn(plates)
        local candidateCount = table.getn(candidates)

        if plateCount == 1 and candidateCount == 1 then
            local data = plates[1]
            data.unit = candidates[1].unit
            data.guid = addon:GetUnitID(candidates[1].unit)
        elseif candidateCount > 0 then
            local usedCandidates = {}

            for assignStep = 1, plateCount do
                local bestPlateIndex = nil
                local bestCandidateIndex = nil
                local bestScore = -999999

                for plateIndex = 1, plateCount do
                    local data = plates[plateIndex]
                    if not data.unit then
                        for candidateIndex = 1, candidateCount do
                            if not usedCandidates[candidateIndex] then
                                local score = ScoreCandidateForPlate(data, candidates[candidateIndex])
                                if score > bestScore then
                                    bestScore = score
                                    bestPlateIndex = plateIndex
                                    bestCandidateIndex = candidateIndex
                                end
                            end
                        end
                    end
                end

                if bestPlateIndex and bestCandidateIndex then
                    local data = plates[bestPlateIndex]
                    local candidate = candidates[bestCandidateIndex]
                    data.unit = candidate.unit
                    data.guid = addon:GetUnitID(candidate.unit)
                    usedCandidates[bestCandidateIndex] = true
                else
                    break
                end
            end
        end
    end
end

-- ==================================================================
-- Check if a WoW API function exists and is callable
-- In Vanilla 1.12, many APIs like UnitThreatSituation do not exist
-- ==================================================================
local function APICheck(func)
    if func then
        local ok, _ = pcall(func)
        return ok
    end
    return false
end

-- ==================================================================
-- Initialize the nameplate module
-- ==================================================================
function addon.Nameplates:Initialize()
    -- Set up the periodic nameplate scanner
    self.scanner = CreateFrame("Frame", "RelationshipsThreatPlatesScanner")
    self.scanner.elapsed = 0
    self.scanner:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= 0.5 then
            this.elapsed = 0
            addon.Nameplates:ScanForNameplates()
        end
    end)

    -- Set up the periodic threat updater
    self.updater = CreateFrame("Frame", "RelationshipsThreatPlatesUpdater")
    self.updater.elapsed = 0
    self.updater:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= 0.3 then
            this.elapsed = 0
            addon.Nameplates:UpdateAllPlates()
        end
    end)

    -- Initial scan
    self:ScanForNameplates()
end

-- ==================================================================
-- Scan for nameplates using the vanilla 1.12 WorldFrame method
--
-- In vanilla 1.12, nameplates are direct children of WorldFrame.
-- A nameplate frame has this structure:
--   - It is a direct child of WorldFrame
--   - It contains a child Frame that has a StatusBar (the health bar)
--   - The health bar's children include textures (the bar fill + bg)
--   - The nameplate has FontString regions for the name text
--   - Nameplates have characteristic dimensions (~110 wide, ~40 tall)
--
-- We detect them by looking for frames with a StatusBar child
-- that also have FontString regions.
-- ==================================================================
function addon.Nameplates:ScanForNameplates()
    local numChildren = WorldFrame:GetNumChildren()

    -- Cache children table to avoid calling GetChildren repeatedly
    local children = { WorldFrame:GetChildren() }

    for i = 1, numChildren do
        local nameplate = children[i]

        if nameplate and not knownPlates[nameplate] then
            -- Only mark a plate as "known" once we have actually
            -- attached a threat bar to it. Vanilla recycles nameplate
            -- frames from a pool: a currently-invisible plate frame
            -- can (and usually will) reappear later for another mob.
            -- If we flagged it known while invisible, we would never
            -- attach a bar when it became visible again — that is the
            -- root cause of "plates stop appearing after changing a
            -- setting" (RecreateAll clears knownPlates, then this
            -- scan runs while some pooled plates are hidden).
            if nameplate:IsVisible() then
                local healthBar, nameText = self:IdentifyNameplate(nameplate)
                if healthBar then
                    knownPlates[nameplate] = true
                    self:AttachThreatBar(nameplate, healthBar, nameText)
                end
            end
            -- Invisible plates are intentionally left un-flagged so
            -- the periodic scan will re-check them once they show.
        end
    end
end

-- ==================================================================
-- Identify if a frame is a vanilla nameplate
-- Returns: healthBar (StatusBar), nameText (FontString) or nil
-- ==================================================================
function addon.Nameplates:IdentifyNameplate(frame)
    if not frame then return nil end
    if not frame:IsVisible() then return nil end

    -- Nameplates are not too large and not too small
    local w = frame:GetWidth()
    local h = frame:GetHeight()
    if not w or not h then return nil end
    if w < 50 or w > 200 then return nil end
    if h < 10 or h > 100 then return nil end

    local healthBar = nil
    local nameText = nil

    -- Scan children for StatusBar (health bar)
    -- In vanilla, the health bar is usually the first child or
    -- is nested inside a child frame
    local kids = { frame:GetChildren() }
    local numKids = table.getn(kids)
    for j = 1, numKids do
        local child = kids[j]
        if child then
            -- Check if this child IS a StatusBar
            -- In vanilla 1.12, GetObjectType works on all frame types
            local ok, objType = pcall(child.GetObjectType, child)
            if ok and objType == "StatusBar" then
                healthBar = child
            else
                -- The StatusBar might be nested one level deeper
                -- (some nameplate implementations wrap the bar)
                local grandKids = { child:GetChildren() }
                local numGrandKids = table.getn(grandKids)
                for k = 1, numGrandKids do
                    local grandChild = grandKids[k]
                    if grandChild then
                        local ok2, objType2 = pcall(grandChild.GetObjectType, grandChild)
                        if ok2 and objType2 == "StatusBar" then
                            healthBar = grandChild
                            break
                        end
                    end
                end
            end
            if healthBar then break end
        end
    end

    -- Scan regions for FontString (name text)
    local regions = { frame:GetRegions() }
    local numRegions = table.getn(regions)
    for j = 1, numRegions do
        local region = regions[j]
        if region then
            local ok, objType = pcall(region.GetObjectType, region)
            if ok and objType == "FontString" then
                -- This is a FontString - store as name text candidate
                if not nameText then
                    nameText = region
                end
            end
        end
    end

    -- Must have at least a health bar to be a valid nameplate
    if healthBar then
        return healthBar, nameText
    end

    return nil
end

-- ==================================================================
-- Create and attach a Kui-style threat bar to a nameplate
-- ==================================================================
function addon.Nameplates:AttachThreatBar(nameplate, healthBar, nameFontString)
    if self.plates[nameplate] then return end
    if not RelationshipsThreatPlatesDB then return end

    local db = RelationshipsThreatPlatesDB

    -- ==============================================================
    -- Create the threat bar container frame
    -- ==============================================================
    local container = CreateFrame("Frame", nil, nameplate)
    container:SetFrameLevel(nameplate:GetFrameLevel() + 10)

    local barHeight = db.barHeight or 8
    local offsetY = db.barOffsetY or 1
    local offsetX = db.barOffsetX or -17.8
    local widthScale = db.barWidthScale or 0.8

    -- Position: anchored ABOVE the health bar, centered on it
    -- widthScale controls how wide the bar is relative to the health bar
    -- (1.0 = same width, 0.5 = half width, etc.)
    local gap = 2 + offsetY  -- minimum 2px gap, plus user offset
    local healthWidth = healthBar:GetWidth() or 100
    local barWidth = math.floor(healthWidth * widthScale + 0.5)
    -- Minimum width so the bar is always visible
    if barWidth < 20 then barWidth = 20 end

    container:ClearAllPoints()
    container:SetPoint("BOTTOM", healthBar, "TOP", offsetX, gap)
    container:SetWidth(barWidth)
    container:SetHeight(barHeight + 2)

    -- ==============================================================
    -- Dark background (Kui-style)
    -- ==============================================================
    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(SOLID_TEXTURE)
    bg:SetVertexColor(0.06, 0.06, 0.06, 0.9)
    bg:SetAllPoints(container)
    container.bg = bg

    -- ==============================================================
    -- Shadow border (Kui-style, when enabled)
    -- ==============================================================
    if db.glowEnabled and db.glowAsShadow then
        local glow = container:CreateTexture(nil, "BACKGROUND")
        glow:SetTexture(SOLID_TEXTURE)
        glow:SetVertexColor(0, 0, 0, 0.2)
        local gs = db.glowSize or 3
        glow:SetPoint("TOPLEFT", container, -gs, gs)
        glow:SetPoint("BOTTOMRIGHT", container, gs, -gs)
        container.glow = glow
    end

    -- ==============================================================
    -- Threat status bar (inset 1px from container edges)
    -- ==============================================================
    local bar = CreateFrame("StatusBar", nil, container)
    bar:SetFrameLevel(container:GetFrameLevel() + 1)
    bar:SetStatusBarTexture(SOLID_TEXTURE)
    bar:SetMinMaxValues(0, 100)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", container, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)
    bar:SetValue(0)
    bar:SetStatusBarColor(0.33, 0.80, 0.33, db.barAlpha or 1)
    container.bar = bar

    -- ==============================================================
    -- Fill background texture (dim colour behind the bar)
    -- ==============================================================
    if db.showFillBG then
        local fill = bar:CreateTexture(nil, "BACKGROUND")
        fill:SetTexture(SOLID_TEXTURE)
        fill:SetAllPoints(bar)
        fill:SetVertexColor(0.33, 0.80, 0.33)
        fill:SetAlpha(db.fillAlpha or 0.2)
        container.fill = fill
    end

    -- ==============================================================
    -- Spark texture (bright leading edge)
    -- ==============================================================
    if db.showSpark then
        local spark = bar:CreateTexture(nil, "ARTWORK")
        spark:SetTexture(SOLID_TEXTURE)
        spark:SetWidth(2)
        spark:SetHeight(barHeight)
        spark:SetVertexColor(1, 1, 1, 0.8)
        spark:Hide()
        container.spark = spark
    end

    -- ==============================================================
    -- Threat text (outline font, centered in bar)
    -- ==============================================================
    if db.showText then
        local text = bar:CreateFontString(nil, "OVERLAY")
        local fSize = db.fontSize or 9
        if db.fontOutline then
            text:SetFont(FONT_PATH, fSize, "OUTLINE")
        else
            text:SetFont(FONT_PATH, fSize)
        end
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
        text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        text:SetTextColor(1, 1, 1, 1)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        text:SetText("")
        container.text = text
    end

    -- ==============================================================
    -- Threat glow (red glow for high threat)
    -- ==============================================================
    if db.glowEnabled then
        local threatGlow = container:CreateTexture(nil, "BACKGROUND")
        threatGlow:SetTexture(SOLID_TEXTURE)
        local gs = db.glowSize or 3
        threatGlow:SetPoint("TOPLEFT", container, -gs, gs)
        threatGlow:SetPoint("BOTTOMRIGHT", container, gs, -gs)
        threatGlow:SetVertexColor(0.9, 0, 0, 0)
        threatGlow:Hide()
        container.threatGlow = threatGlow
    end

    -- ==============================================================
    -- Store the plate data
    -- ==============================================================
    local plateData = {
        container      = container,
        bar            = bar,
        fill           = container.fill,
        spark          = container.spark,
        text           = container.text,
        bg             = bg,
        glow           = container.glow,
        threatGlow     = container.threatGlow,
        healthBar      = healthBar,
        nameFontString = nameFontString,
        nameplate      = nameplate,
        unit           = nil,
        guid           = nil,
        lastPct        = 0,
        plateName      = nil,
        isUniqueName   = true,
        lastThreatTime = nil,
        -- Health tracking for combat detection without unit tokens.
        -- These are updated every cycle in UpdateAllPlates.
        previousHealth = nil,    -- health % from previous cycle
        combatDetectedAt = nil,  -- timestamp when combat was first detected
    }

    self.plates[nameplate] = plateData

    -- Show or hide based on visibility
    if nameplate:IsVisible() then
        self:OnNameplateShow(nameplate)
    else
        container:Hide()
    end
end

-- ==================================================================
-- Nameplate show handler
-- ==================================================================
function addon.Nameplates:OnNameplateShow(nameplate)
    local data = self.plates[nameplate]
    if not data then return end

    self:ResolveNameplateName(nameplate)

    if RelationshipsThreatPlatesDB and RelationshipsThreatPlatesDB.enabled then
        data.container:Show()
    else
        data.container:Hide()
    end
end

-- ==================================================================
-- Read the name text from a nameplate
-- ==================================================================
function addon.Nameplates:ResolveNameplateName(nameplate)
    local data = self.plates[nameplate]
    if not data then return end

    local name = GetPlateNameText(data, nameplate)

    if name and strlen(name) > 0 then
        data.plateName = name

        -- Important for same-name mobs: only bind immediately if we can
        -- resolve EXACTLY one visible unit token for this name. If there
        -- are multiple candidates, defer assignment to ResolveVisiblePlateUnits.
        local candidates = self:GetCandidateUnitsByName(name)
        if table.getn(candidates) == 1 then
            data.unit = candidates[1].unit
            data.guid = addon:GetUnitID(candidates[1].unit)
        else
            data.unit = nil
            data.guid = nil
        end
    else
        data.plateName = nil
        data.unit = nil
        data.guid = nil
    end
end

-- ==================================================================
-- Find a unit token by its name
-- ==================================================================
function addon.Nameplates:FindUnitByName(name)
    if not name then return nil end

    -- Direct unit tokens (highest priority - these have full API access)
    local quickUnits = { "target", "mouseover", "targettarget", "pet" }
    for i = 1, table.getn(quickUnits) do
        local unit = quickUnits[i]
        local ok, exists = pcall(UnitExists, unit)
        if ok and exists then
            local ok2, uname = pcall(UnitName, unit)
            if ok2 and uname and uname == name then
                return unit
            end
        end
    end

    -- Party members' targets (gives us API access to mobs party members are targeting)
    for i = 1, 4 do
        local unit = "party" .. i .. "target"
        local ok, exists = pcall(UnitExists, unit)
        if ok and exists then
            local ok2, uname = pcall(UnitName, unit)
            if ok2 and uname and uname == name then
                return unit
            end
        end
    end

    -- Party members' target-of-target (lets us see who a mob is targeting)
    -- This is crucial for heuristic threat estimation in parties
    for i = 1, 4 do
        local unit = "party" .. i .. "targettarget"
        local ok, exists = pcall(UnitExists, unit)
        if ok and exists then
            local ok2, uname = pcall(UnitName, unit)
            if ok2 and uname and uname == name then
                return unit
            end
        end
    end

    -- Raid member targets
    for i = 1, 40 do
        local unit = "raid" .. i .. "target"
        local ok, exists = pcall(UnitExists, unit)
        if ok and exists then
            local ok2, uname = pcall(UnitName, unit)
            if ok2 and uname and uname == name then
                return unit
            end
        end
    end

    -- Raid member target-of-target
    for i = 1, 40 do
        local unit = "raid" .. i .. "targettarget"
        local ok, exists = pcall(UnitExists, unit)
        if ok and exists then
            local ok2, uname = pcall(UnitName, unit)
            if ok2 and uname and uname == name then
                return unit
            end
        end
    end

    return nil
end

-- ==================================================================
-- Update threat display for a specific unit
-- ==================================================================
function addon.Nameplates:UpdateThreatForUnit(unit, pct, situation)
    if not RelationshipsThreatPlatesDB or not RelationshipsThreatPlatesDB.enabled then return end
    if not unit or not UnitExists(unit) then return end

    local realGuid = addon:SafeGUID(unit)

    for nameplate, data in pairs(self.plates) do
        local isMatch = false

        -- In Vanilla, unit-name fallback is NOT unique for same-name mobs.
        -- Therefore, match by exact unit token whenever possible.
        if data.unit and UnitExists(data.unit) then
            if IsSameUnitToken(data.unit, unit) then
                isMatch = true
            end
        elseif realGuid and data.guid == realGuid then
            -- GUID-based fallback is only safe on clients/servers that
            -- actually expose UnitGUID.
            isMatch = true
        end

        if isMatch then
            self:ApplyThreatToPlate(data, pct, situation)
        end
    end
end

-- ==================================================================
-- Apply threat values to a specific plate
-- ==================================================================
function addon.Nameplates:ApplyThreatToPlate(data, pct, situation)
    if not data or not data.bar then return end
    if not RelationshipsThreatPlatesDB or not RelationshipsThreatPlatesDB.enabled then
        data.container:Hide()
        return
    end

    -- Check visibility filters
    if not self:ShouldShowOnPlate(data, situation) then
        data.container:Hide()
        return
    end

    -- FINAL SAFETY NET: If we have a unit token, verify the mob is
    -- actually in combat. This catches any edge cases where the threat
    -- system returned a non-zero percentage for an idle mob.
    -- Without this check, healing threat split could still cause bars
    -- to appear on nearby idle mobs that share a unit token.
    if data.unit and UnitExists(data.unit) then
        local ok, inCombat = pcall(UnitAffectingCombat, data.unit)
        if ok and not inCombat then
            data.container:Hide()
            return
        end
    end

    -- ADDITIONAL SAFETY NET for SAME-NAME mobs only:
    -- If the nameplate health bar is at or near 100%, this is very
    -- likely an idle mob that hasn't been attacked. A mob in active
    -- combat with threat data should show damage on its health bar.
    --
    -- IMPORTANT: This check only applies when there are multiple
    -- plates sharing the same name (same-name mobs). For UNIQUE-name
    -- mobs (only one plate with this name visible), we rely on
    -- IsPlateInCombat() which uses health-change detection, so this
    -- full-health safety net is redundant and counterproductive.
    --
    -- The isUniqueName flag is set by UpdateAllPlates before calling
    -- this function. If not set, default to false (apply safety net).
    if not data.isUniqueName then
        local plateHealthPct = GetPlateHealthPercent(data)
        if plateHealthPct and plateHealthPct >= 99.5 then
            -- Plate is at full/near-full health. Check if we have a
            -- unit token in combat. If the unit token is valid and in
            -- combat, it might be a freshly pulled mob — allow it.
            -- Also allow if IsPlateInCombat detected a health decrease.
            local unitInCombat = false
            if data.unit and UnitExists(data.unit) then
                local ok, inCombat = pcall(UnitAffectingCombat, data.unit)
                if ok and inCombat then
                    unitInCombat = true
                end
            end
            -- Check health-change combat detection
            local plateCombatDetected = IsPlateInCombat(data)
            if not unitInCombat and not plateCombatDetected then
                data.container:Hide()
                return
            end
            -- Unit/plate appears in combat but at full health. This can
            -- happen briefly after the first hit. Allow a short grace period.
            if not data.lastThreatTime then
                data.lastThreatTime = GetTime()
            end
            if GetTime() - data.lastThreatTime > 0.5 then
                -- Showing a bar for 5+ seconds on a full-health
                -- mob in combat. Likely a same-name mob mismatch.
                data.container:Hide()
                return
            end
        else
            -- Mob is damaged, reset the grace period tracker
            data.lastThreatTime = GetTime()
        end
    else
        -- Unique-name mob: update the grace tracker but don't use
        -- full-health as a reason to hide. ThreatEngine data for a
        -- unique name is unambiguous.
        data.lastThreatTime = GetTime()
    end

    -- If no threat percentage, hide the bar.
    -- KEY FIX: Removed the old gate that required player to be in combat.
    -- Now we only check if there's actual threat data to show. The combat
    -- verification is done earlier in the pipeline (IsPlateInCombat,
    -- GetThreatByName, etc.).
    -- Combat-only display (2.6)
    if RelationshipsThreatPlatesDB.combatOnly then
        local inCombat = false
        if UnitAffectingCombat then
            local ok, r = pcall(UnitAffectingCombat, "player")
            if ok then inCombat = r end
        end
        if not inCombat then
            data.container:Hide()
            if addon.Nameplates.SetFlashing then addon.Nameplates:SetFlashing(data, false) end
            return
        end
    end

    -- Hide below threshold (2.6)
    local minShow = RelationshipsThreatPlatesDB.hideBelowPct or 0
    if minShow > 0 and (pct or 0) < minShow then
        data.container:Hide()
        if addon.Nameplates.SetFlashing then addon.Nameplates:SetFlashing(data, false) end
        return
    end

    if pct == 0 then
        data.container:Hide()
        if addon.Nameplates.SetFlashing then addon.Nameplates:SetFlashing(data, false) end
        return
    end

    data.container:Show()

    -- Preserve the RAW threat percent (may exceed 100 when the player
    -- is the top threat holder and well ahead of the runner-up). The
    -- text label shows this uncapped value so the user can see e.g.
    -- "185%" for a tank comfortably holding threat. The bar fill
    -- itself is clamped to 0-100 because the statusbar range is fixed.
    local rawPct = pct or 0

    -- Smooth the percentage (bar fill only — clamp to 0..100)
    local oldPct = data.lastPct or 0
    local barPct = math.min(100, math.max(0, rawPct))
    local smoothPct
    -- Snap instantly when jumping to full aggro or dropping to 0
    -- (mob switched target). Smooth intermediate transitions moderately.
    if barPct == 0 or barPct >= 99.5 or math.abs(barPct - oldPct) > 40 then
        smoothPct = barPct
    else
        smoothPct = oldPct + (barPct - oldPct) * 0.6
    end
    data.lastPct = smoothPct

    smoothPct = math.min(100, math.max(0, smoothPct))

    -- Update bar value (0-100 range)
    data.bar:SetValue(smoothPct)

    -- Update bar colour (smooth gradient) — driven by barPct so colours
    -- top out at aggro red even if rawPct exceeds 100.
    local r, g, b = addon.Media.GetThreatColour(barPct)
    data.bar:SetStatusBarColor(r, g, b, RelationshipsThreatPlatesDB.barAlpha or 1)

    -- Update statusbar texture vertex colour
    local tex = data.bar:GetStatusBarTexture()
    if tex then
        tex:SetVertexColor(r, g, b)
    end

    -- Update fill background
    if data.fill then
        data.fill:SetVertexColor(r, g, b)
        data.fill:SetAlpha(RelationshipsThreatPlatesDB.fillAlpha or 0.2)
    end

    -- Update spark
    if data.spark then
        if smoothPct > 0 and smoothPct < 100 then
            -- Re-anchor spark to the leading edge of the bar fill
            data.spark:ClearAllPoints()
            if tex then
                data.spark:SetPoint("TOP", tex, "TOPRIGHT", 0, 0)
                data.spark:SetPoint("BOTTOM", tex, "BOTTOMRIGHT", 0, 0)
            end
            -- Brighten spark colour
            local br = math.min(1, r + (1 - r) * 0.3)
            local bg2 = math.min(1, g + (1 - g) * 0.3)
            local bb = math.min(1, b + (1 - b) * 0.3)
            data.spark:SetVertexColor(br, bg2, bb, 0.8)
            data.spark:Show()
        else
            data.spark:Hide()
        end
    end

    -- Update text — uses rawPct so values above 100% are shown as-is.
    if data.text then
        local fmt = RelationshipsThreatPlatesDB.textFormat or "percent"
        local pctStr = math.floor(rawPct + 0.5) .. "%"
        local tankStr = nil
        if data.plateName and (RelationshipsThreatPlatesDB.tankMode or fmt == "tank" or fmt == "combo") then
            tankStr = addon.Threat:GetTankDisplayForMob(data.plateName)
        end
        local textStr
        if RelationshipsThreatPlatesDB.tankMode and tankStr and tankStr ~= "--" then
            textStr = tankStr
        elseif fmt == "tank" and tankStr and tankStr ~= "--" then
            textStr = tankStr
        elseif fmt == "status" then
            if rawPct >= 100 then textStr = "PULL!"
            elseif rawPct >= 80 then textStr = "WARN"
            elseif rawPct >= 50 then textStr = "HIGH"
            else textStr = "SAFE" end
        elseif fmt == "combo" and tankStr and tankStr ~= "--" then
            textStr = pctStr .. " " .. tankStr
        else
            textStr = pctStr
        end
        data.text:SetText(textStr)

        if rawPct >= 100 then
            data.text:SetTextColor(1, 0.2, 0.2, 1)
        elseif rawPct >= 60 then
            data.text:SetTextColor(1, 0.9, 0.8, 1)
        else
            data.text:SetTextColor(1, 1, 1, 1)
        end
    end

    -- Warning sound (edge-triggered, 2.6)
    do
        local db = RelationshipsThreatPlatesDB
        local prevWarn = data.lastWarnPct or 0
        local threshold = db.warningThreshold or 80
        if db.warningSound and threshold > 0
           and rawPct >= threshold and prevWarn < threshold then
            local snd = db.warningSoundName or "RaidWarning"
            pcall(PlaySound, snd)
        end
        data.lastWarnPct = rawPct

        -- Flash on aggro (2.6)
        if addon.Nameplates.SetFlashing then
            addon.Nameplates:SetFlashing(data, (db.flashOnAggro and rawPct >= 100) and true or false)
        end
    end

    -- Update threat glow (drive by clamped barPct so it caps at max intensity)
    if data.threatGlow then
        if barPct >= 80 then
            local intensity = (barPct - 80) / 20
            if intensity > 1 then intensity = 1 end
            data.threatGlow:SetVertexColor(0.9, 0, 0, 0.6 * intensity)
            data.threatGlow:Show()
        else
            data.threatGlow:Hide()
        end
    end
end

-- ==================================================================
-- Should this plate show a threat bar based on settings?
-- KEY CHANGE: Now shows threat bars for mobs attacking any group
-- member, not just the player. This ensures ALL attacking mobs
-- display threat percentages.
-- ==================================================================
function addon.Nameplates:ShouldShowOnPlate(data, situation)
    if not RelationshipsThreatPlatesDB then return false end
    if not RelationshipsThreatPlatesDB.enabled then return false end

    local unit = data.unit
    if not unit then
        -- No unit token resolved. Check if the mob is attacking
        -- a group member via mob target name heuristic.
        -- This allows threat bars to appear on nameplates even
        -- when we can't resolve a unit token.
        if data.plateName then
            -- Try to find who this mob is targeting
            local foundUnit = self:FindUnitByName(data.plateName)
            if foundUnit then
                local ok_mt, mt = pcall(UnitName, foundUnit .. "target")
                if ok_mt and mt then
                    -- Mob is targeting someone in our group
                    if mt == UnitName("player") or addon.Threat:IsPartyMember(mt) then
                        return RelationshipsThreatPlatesDB.showOnHostile
                    end
                end
            end
        end
        return true
    end

    if not UnitExists(unit) then return false end

    local reaction = UnitReaction(unit, "player")
    if not reaction then return true end

    if reaction <= 3 then
        return RelationshipsThreatPlatesDB.showOnHostile
    elseif reaction == 4 then
        return RelationshipsThreatPlatesDB.showOnNeutral
    else
        return RelationshipsThreatPlatesDB.showOnFriendly
    end
end

-- ==================================================================
-- Find a combat-verified unit token for a nameplate that has no
-- resolved unit token. This is the same-name mob disambiguator.
--
-- Strategy:
--   1. Find ALL unit tokens matching the plate's name
--   2. Filter to only those that are in combat (UnitAffectingCombat)
--   3. Score remaining candidates by health % match with the plate
--   4. Return the best match, or nil if no combat unit found
--
-- Returns: unit token string, or nil
-- ==================================================================
function addon.Nameplates:FindCombatUnitForPlate(data, excludeUnits)
    if not data or not data.plateName then return nil end
    if strlen(data.plateName) == 0 then return nil end

    -- KEY FIX: Only require that someone in the group is in combat,
    -- not necessarily the player. This allows finding combat units
    -- for mobs attacking party/raid members.
    if not addon.ThreatEngine:IsGroupInCombat() then return nil end

    local name = data.plateName

    -- Collect ALL unit tokens matching this name
    local candidates = self:GetCandidateUnitsByName(name)
    if table.getn(candidates) == 0 then return nil end

    -- Get plate health percentage for matching
    local plateHealthPct = GetPlateHealthPercent(data)

    -- Same-name mob safety: if THIS plate's health looks idle
    -- (near-full and not dropping), refuse to bind any combat
    -- unit token. Binding a nearby attacker's unit token to an
    -- idle same-name plate is the root cause of the "idle mob
    -- shows attacker's threat bar" bug.
    local plateLooksIdle = false
    if plateHealthPct and plateHealthPct >= 99.5 then
        if not data.previousHealth or data.previousHealth >= 99.5 then
            plateLooksIdle = true
        end
    end
    if plateLooksIdle then
        return nil
    end

    -- Score each candidate: we want a unit that is:
    --   1. In combat (mandatory — idle mobs must never match)
    --   2. Health % close to the plate's health bar
    --   3. Hostile and attackable
    --   4. Not already assigned to a different plate this cycle
    local bestUnit = nil
    local bestScore = -999999

    for i = 1, table.getn(candidates) do
        local c = candidates[i]

        -- Skip candidates already claimed by another plate this cycle
        local excluded = false
        if excludeUnits then
            for j = 1, table.getn(excludeUnits) do
                if IsSameUnitToken(excludeUnits[j], c.unit) then
                    excluded = true
                    break
                end
            end
        end

        -- MANDATORY: Unit must be in combat AND not already claimed.
        if c.inCombat and not excluded then
            local score = 0
            local healthMatched = false

            -- Health % matching (most important discriminator).
            -- Require a reasonably close match — if the plate is at
            -- 40% and the only combat candidate is at 100%, it is
            -- almost certainly a DIFFERENT mob with the same name
            -- and must NOT be bound to this plate.
            if plateHealthPct and c.healthPct then
                local diff = math.abs(plateHealthPct - c.healthPct)
                if diff <= 8 then
                    healthMatched = true
                    score = score + math.max(0, 500 - (diff * 15))
                else
                    -- Too far apart — skip this candidate entirely.
                    score = -999999
                end
            else
                -- No health info to compare. Fall back to previous
                -- behaviour so freshly-shown plates can still bind
                -- when their health bar hasn't been read yet.
                healthMatched = true
            end

            -- Hostile/attackable bonus
            if c.canAttack then
                score = score + 50
            end

            if score > bestScore and healthMatched then
                bestScore = score
                bestUnit = c.unit
            end
        end
    end

    return bestUnit
end

-- ==================================================================
-- Update all plates (called periodically)
--
-- DESIGN: Shows threat bars for ALL mobs in combat with the player
-- or any group member, not just the targeted mob.
--
-- COMBAT DETECTION STRATEGY:
--   In Vanilla 1.12, non-targeted mobs have NO unit tokens.
--   We use THREE methods to detect if a mob is in combat:
--     1. Unit token API (UnitAffectingCombat) — if we have a token
--     2. Health decrease detection — if the plate's health bar is
--        dropping, the mob is taking damage and is in combat
--     3. ThreatEngine data — if we have threat data for this mob,
--        someone in the group has hit it, so it's in combat
--
-- SAME-NAME MOB HANDLING:
--   - UNIQUE-name mobs (only 1 plate with that name): ThreatEngine
--     data is unambiguous. Can use it directly.
--   - SAME-name mobs (multiple plates share a name): Must verify
--     combat to avoid showing threat on idle same-name mobs.
--     Health-change detection is the KEY discriminator — idle mobs
--     stay at 100% health while combat mobs take damage.
--
-- This approach ensures:
--   - All attacking mobs show threat bars (multi-mob requirement)
--   - Idle same-name mobs don't get false threat bars
--   - Mobs attacking party members show threat even when player
--     isn't in combat
-- ==================================================================

-- ==================================================================
-- Fallback threat values when we know a mob is in combat but have
-- no ThreatEngine percentage. Distinguishes "mob is attacking the
-- player" (full aggro on us) from "mob is attacking a party member"
-- (we're not the aggro target, show a low visible bar).
-- ==================================================================
local function GetFallbackThreatForMob(name)
    if name
       and addon.ThreatEngine
       and addon.ThreatEngine.IsMobAttackingPlayer
       and addon.ThreatEngine:IsMobAttackingPlayer(name) then
        return 100, 3
    end
    return 20, 0
end

function addon.Nameplates:UpdateAllPlates()
    if not RelationshipsThreatPlatesDB or not RelationshipsThreatPlatesDB.enabled then
        for nameplate, data in pairs(self.plates) do
            data.container:Hide()
        end
        return
    end

    local now = GetTime()
    local groupInCombat = addon.ThreatEngine:IsGroupInCombat()

    -- Step 1: Count how many visible plates share each name.
    -- This determines whether a name is unique or ambiguous.
    local platesPerName = {}
    for nameplate, data in pairs(self.plates) do
        if nameplate:IsVisible() and data.plateName then
            if not platesPerName[data.plateName] then
                platesPerName[data.plateName] = 0
            end
            platesPerName[data.plateName] = platesPerName[data.plateName] + 1
        end
    end

    -- Step 2: Resolve unit tokens for all visible plates.
    -- ResolveVisiblePlateUnits handles same-name mob assignment via
    -- health-matching and combat-status scoring.
    self:ResolveVisiblePlateUnits()

    -- Step 3: Update health tracking for combat detection.
    -- Store current health for comparison next cycle.
    -- This is done BEFORE the main update loop so IsPlateInCombat
    -- can use the previous cycle's health for change detection.
    for nameplate, data in pairs(self.plates) do
        if nameplate:IsVisible() then
            local currentHealth = GetPlateHealthPercent(data)
            -- We'll update previousHealth AFTER the main loop,
            -- so IsPlateInCombat can compare current vs previous.
            data._currentHealth = currentHealth
        end
    end

    -- Step 4: Update threat display for each visible plate.
    -- Track combat unit tokens assigned this cycle so a single
    -- combat mob can never be bound to multiple same-name plates
    -- (which was causing idle same-name plates to display the
    -- attacker's threat bar).
    local assignedUnits = {}
    for nameplate, data in pairs(self.plates) do
        if data.unit then
            assignedUnits[table.getn(assignedUnits) + 1] = data.unit
        end
    end
    for nameplate, data in pairs(self.plates) do
        if nameplate:IsVisible() then
            local isUniqueName = (platesPerName[data.plateName] or 1) <= 1
            data.isUniqueName = isUniqueName

            local plateInCombat = IsPlateInCombat(data)
            local hasThreatData = data.plateName and addon.ThreatEngine:HasDataForTarget(data.plateName)

            -- v2.6.2: A mob is also "in combat with us" if the incoming
            -- combat-log parser has seen it hit or miss the player /
            -- a party member within the last few seconds. In Vanilla
            -- 1.12 non-targeted mobs have no unit token, so this is
            -- the ONLY reliable signal for "this specific mob is
            -- attacking the group" when its health bar hasn't
            -- dropped yet. We only apply this signal to unique-name
            -- plates to avoid lighting up every same-name plate when
            -- only one of them is actually attacking.
            local mobAttackingGroup =
                data.plateName
                and addon.ThreatEngine.IsMobAttackingGroup
                and addon.ThreatEngine:IsMobAttackingGroup(data.plateName)
                or false

            if data.unit and UnitExists(data.unit) then
                -- We have a resolved unit token. Verify it's in combat.
                local ok_combat, mobInCombat = pcall(UnitAffectingCombat, data.unit)
                if ok_combat and not mobInCombat then
                    -- Unit is NOT in combat — idle mob. Never show threat.
                    data.container:Hide()
                else
                    -- Unit is in combat (or can't verify). Get threat.
                    local pct, situation = addon.Threat:GetThreatPercent(data.unit)
                    self:ApplyThreatToPlate(data, pct, situation or 0)
                end
            elseif isUniqueName and data.plateName then
                -- UNIQUE-NAME MOB with no unit token.
                --
                -- CAUTION: "unique" here only means one plate of this
                -- name is currently VISIBLE. The camera may have rotated
                -- away from a same-name attacker who is still active.
                -- Because ThreatEngine data (and IsMobAttackingGroup)
                -- are keyed by NAME, trusting them for an idle-looking
                -- plate would light up the wrong mob when its twin
                -- attacker is off-screen. So we require one of:
                --   (a) confirmed health drop on THIS plate, OR
                --   (b) a resolved combat unit token whose health
                --       matches THIS plate.
                -- A name-only signal (mobAttackingGroup / ThreatEngine
                -- data) is never enough on its own.

                if plateInCombat then
                    -- This specific plate's health is dropping — it's
                    -- in combat. Safe to trust name-keyed threat data.
                    if not data.combatDetectedAt then
                        data.combatDetectedAt = now
                    end

                    local pct, sit = addon.Threat:GetThreatByName(data.plateName)
                    if pct > 0 then
                        self:ApplyThreatToPlate(data, pct, sit or 0)
                    else
                        if groupInCombat then
                            do local _fp, _fs = GetFallbackThreatForMob(data.plateName); self:ApplyThreatToPlate(data, _fp, _fs) end
                        else
                            data.container:Hide()
                        end
                    end
                elseif groupInCombat and (mobAttackingGroup or hasThreatData) then
                    -- Name-only signal says a mob of this name is
                    -- attacking the group, but THIS plate shows no
                    -- health drop. Verify by matching a real combat
                    -- unit token to this plate (health % match). If
                    -- none matches, this plate is an idle bystander
                    -- (e.g. the real attacker rotated off-screen).
                    local unit = self:FindCombatUnitForPlate(data, assignedUnits)
                    if unit then
                        data.unit = unit
                        data.guid = addon:GetUnitID(unit)
                        assignedUnits[table.getn(assignedUnits) + 1] = unit
                        if not data.combatDetectedAt then
                            data.combatDetectedAt = now
                        end
                        local pct, situation = addon.Threat:GetThreatPercent(unit)
                        if pct > 0 then
                            self:ApplyThreatToPlate(data, pct, situation or 0)
                        else
                            do local _fp, _fs = GetFallbackThreatForMob(data.plateName); self:ApplyThreatToPlate(data, _fp, _fs) end
                        end
                    else
                        -- Can't verify this plate is the attacker.
                        -- Do NOT show a bar based on name alone.
                        data.combatDetectedAt = nil
                        data.container:Hide()
                    end
                else
                    -- No combat detected, no threat data, or group not in combat.
                    data.combatDetectedAt = nil
                    data.container:Hide()
                end
            elseif not isUniqueName and data.plateName then
                -- SAME-NAME MOB with no unit token:
                -- Multiple plates share this name. Must be careful.
                -- Use health-based combat detection as the primary filter.

                if plateInCombat then
                    -- This specific plate's health is dropping — it's in combat.
                    if not data.combatDetectedAt then
                        data.combatDetectedAt = now
                    end

                    -- Try to find a combat-verified unit with matching health.
                    local unit = self:FindCombatUnitForPlate(data, assignedUnits)
                    if unit then
                        data.unit = unit
                        data.guid = addon:GetUnitID(unit)
                        assignedUnits[table.getn(assignedUnits) + 1] = unit
                        local pct, situation = addon.Threat:GetThreatPercent(unit)
                        self:ApplyThreatToPlate(data, pct, situation or 0)
                    elseif hasThreatData then
                        -- No matching unit token but ThreatEngine has data.
                        -- For same-name mobs this is ambiguous, but the
                        -- health-drop verification means THIS plate IS in
                        -- combat, so it's safe to show ThreatEngine data.
                        local pct, sit = addon.Threat:GetThreatByName(data.plateName)
                        if pct > 0 then
                            self:ApplyThreatToPlate(data, pct, sit or 0)
                        else
                            -- In combat but no threat data — mob is being
                            -- attacked by someone we can't track.
                            if groupInCombat then
                                do local _fp, _fs = GetFallbackThreatForMob(data.plateName); self:ApplyThreatToPlate(data, _fp, _fs) end
                            else
                                data.container:Hide()
                            end
                        end
                    else
                        -- In combat (health dropping) but no ThreatEngine data.
                        -- Show default high-threat bar.
                        if groupInCombat then
                            do local _fp, _fs = GetFallbackThreatForMob(data.plateName); self:ApplyThreatToPlate(data, _fp, _fs) end
                        else
                            data.container:Hide()
                        end
                    end
                else
                    -- Same-name plate at full health and stable — likely idle.
                    -- But check if a unit token reveals this specific mob
                    -- is attacking a group member (body pull scenario).
                    if groupInCombat then
                        local unit = self:FindCombatUnitForPlate(data, assignedUnits)
                        if unit then
                            -- Found a combat-verified unit for this plate.
                            data.unit = unit
                            data.guid = addon:GetUnitID(unit)
                            assignedUnits[table.getn(assignedUnits) + 1] = unit
                            local pct, situation = addon.Threat:GetThreatPercent(unit)
                            if pct > 0 then
                                if not data.combatDetectedAt then
                                    data.combatDetectedAt = now
                                end
                                self:ApplyThreatToPlate(data, pct, situation or 0)
                            else
                                data.combatDetectedAt = nil
                                data.container:Hide()
                            end
                        else
                            -- No combat unit found. Idle same-name mob.
                            data.combatDetectedAt = nil
                            data.container:Hide()
                        end
                    else
                        data.combatDetectedAt = nil
                        data.container:Hide()
                    end
                end
            else
                -- No plate name at all — can't determine anything.
                data.container:Hide()
            end
        else
            -- Plate not visible
            data.combatDetectedAt = nil
            data.container:Hide()
        end
    end

    -- Step 5: Update previousHealth for next cycle's change detection.
    for nameplate, data in pairs(self.plates) do
        data.previousHealth = data._currentHealth
        data._currentHealth = nil
    end
end

-- ==================================================================
-- Force update all (called on settings change)
-- ==================================================================
function addon.Nameplates:UpdateAll()
    for nameplate, data in pairs(self.plates) do
        if RelationshipsThreatPlatesDB and RelationshipsThreatPlatesDB.enabled then
            data.container:Show()
        else
            data.container:Hide()
        end
    end
    self:UpdateAllPlates()
end

-- ==================================================================
-- Recreate all bars (called when visual settings change)
-- ==================================================================
function addon.Nameplates:RecreateAll()
    for nameplate, data in pairs(self.plates) do
        if data.container then
            data.container:Hide()
            data.container:SetParent(nil)
        end
        self.plates[nameplate] = nil
    end
    -- Don't clear knownPlates - we need to re-scan for new nameplates
    -- But we do need to re-attach to known ones
    knownPlates = {}
    self:ScanForNameplates()
end


-- ==================================================================
-- Flash driver (2.6) — pulses bar alpha on aggro plates
-- ==================================================================
addon.Nameplates.flashSet = addon.Nameplates.flashSet or {}

if not addon.Nameplates.flashFrame then
    local ff = CreateFrame("Frame")
    addon.Nameplates.flashFrame = ff
    ff:SetScript("OnUpdate", function()
        local db = RelationshipsThreatPlatesDB
        if not db then return end
        local baseA = db.barAlpha or 1
        if not db.flashOnAggro then
            -- Restore any lingering flashers to base alpha
            for d in pairs(addon.Nameplates.flashSet) do
                if d and d.bar then d.bar:SetAlpha(baseA) end
                addon.Nameplates.flashSet[d] = nil
            end
            return
        end
        local speed = db.flashSpeed or 4
        local t = GetTime() * speed
        -- fabs(sin) style pulse in [0.35, 1.0]
        local s = math.sin(t)
        if s < 0 then s = -s end
        local a = 0.35 + 0.65 * s
        for d in pairs(addon.Nameplates.flashSet) do
            if d and d.bar and d.container and d.container:IsShown() then
                d.bar:SetAlpha(a * baseA)
            end
        end
    end)
end

function addon.Nameplates:SetFlashing(data, on)
    if not data then return end
    if on then
        addon.Nameplates.flashSet[data] = true
    else
        if addon.Nameplates.flashSet[data] then
            addon.Nameplates.flashSet[data] = nil
            if data.bar then
                data.bar:SetAlpha(RelationshipsThreatPlatesDB and RelationshipsThreatPlatesDB.barAlpha or 1)
            end
        end
    end
end
