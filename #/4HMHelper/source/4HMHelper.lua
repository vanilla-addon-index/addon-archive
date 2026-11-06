-- 4 Horsemen Helper Addon for WoW 1.12.1
local addonName = "4HMHelper"
local frame = nil
local isVisible = false
local TEXT_SIZE_SMALL = 20
local TEXT_SIZE_LARGE = 26
local TEXT_SIZE_SAFE = 18

-- Boss configuration
-- Position mapping: BL = Bottom Left, TR = Top Right, BR = Bottom Right, TL = Top Left
local bosses = {
    TL = { name = "Lady Blaumeux", unitID = 16065, spellID = 28833, icon = "Spell_Holy_ElunesGrace" },
    TR = { name = "Sir Zeliek", unitID = 16063, spellID = 28835, icon = "Spell_Shadow_CurseOfAchimonde" },
    BL = { name = "Thane Korth'azz", unitID = 16064, spellID = 28832, icon = "Spell_Shadow_Metamorphosis" },
    BR = { name = "Highlord Mograine", unitID = 16062, spellID = 28834, icon = "Spell_Shadow_SealOfKings" },
}

local SAFE_DISTANCE = 65.5 -- yards
local HOLY_WRATH_DISTANCE = 38 -- yards (Zeliek)
local DEBUFF_DURATION = 60 -- seconds
local ICON_SIZE = 40
local BAR_WIDTH = 5

-- Fixed boss positions in the 4 Horsemen room (set via /4hm record <TL|TR|BL|BR>)
-- Replace nil with recorded coordinates to hardcode them permanently.
local bossPositions = {
    TL = { x = 2466.40, y = -2983.00 }, -- Lady Blaumeux    { x = ?, y = ? }
    TR = { x = 2546.17, y = -2885.58 }, -- Sir Zeliek       { x = ?, y = ? }
    BL = { x = 2527.42, y = -3048.61 }, -- Thane Korth'azz  { x = ?, y = ? }
    BR = { x = 2617.52, y = -2956.50 }, -- Highlord Mograine{ x = ?, y = ? }
}

local distanceCheckAvailable = not not (GetDistanceBetweenUnits or (SuperWoW and SuperWoW.GetDistanceBetweenUnits) or UnitPosition)

-- Per-boss debuff state for tracking remaining duration
local debuffState = {
    TL = { stacks = 0, appliedAt = 0 },
    TR = { stacks = 0, appliedAt = 0 },
    BL = { stacks = 0, appliedAt = 0 },
    BR = { stacks = 0, appliedAt = 0 },
}

local testMode = false
local testData = {
    TL = { stacks = 4, remaining = 40 },
    TR = { stacks = 0, remaining = 0 },
    BL = { stacks = 2, remaining = 25 },
    BR = { stacks = 1, remaining = 8 },
}
if not distanceCheckAvailable then
    DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": WARNING - SuperWoW not detected. Distance checking disabled.")
end

-- Helper function to calculate distance using UnitPosition (SuperWoW)
local function GetDistance(unit1, unit2)
    if GetDistanceBetweenUnits then
        return GetDistanceBetweenUnits(unit1, unit2)
    elseif SuperWoW and SuperWoW.GetDistanceBetweenUnits then
        return SuperWoW.GetDistanceBetweenUnits(unit1, unit2)
    elseif UnitPosition then
        local x1, y1 = UnitPosition(unit1)
        local x2, y2 = UnitPosition(unit2)
        if x1 and y1 and x2 and y2 then
            local dx = x2 - x1
            local dy = y2 - y1
            return math.sqrt(dx * dx + dy * dy)
        end
    end
    return nil
end

local function GetDistanceToPosition(pos)
    if not UnitPosition then return nil end
    local bp = bossPositions[pos]
    if not bp then return nil end
    local x, y = UnitPosition("player")
    if not x or not y then return nil end
    local dx = bp.x - x
    local dy = bp.y - y
    return math.sqrt(dx * dx + dy * dy)
end

-- Helper function to find unit by name
local function FindUnitByName(name)
    -- Check raid targets first
    for i = 1, 40 do
        local unit = "raid" .. i .. "target"
        if UnitExists(unit) and UnitName(unit) == name then
            return unit
        end
    end
    -- Check party targets
    for i = 1, 4 do
        local unit = "party" .. i .. "target"
        if UnitExists(unit) and UnitName(unit) == name then
            return unit
        end
    end
    -- Check player target
    if UnitExists("target") and UnitName("target") == name then
        return "target"
    end
    return nil
end

-- Helper function to get debuff stacks by spell ID
local function GetDebuffStacks(spellID)
    local i = 1
    while UnitDebuff("player", i) do
        local texture, stacks = UnitDebuff("player", i)
        -- Try to match by checking if this is the right debuff
        -- We'll use a tooltip scan to get the spell ID
        if texture then
            -- For now, we'll have to use a texture lookup table since 1.12.1 doesn't give us spell IDs directly
            -- This matches the debuff icons to spell IDs
            local textureName = string.lower(texture or "")

            -- Match by spell ID through texture (workaround for 1.12.1 API limitation)
            local expectedTexture = ""
            if spellID == 28832 then expectedTexture = "spell_shadow_metamorphosis"
            elseif spellID == 28835 then expectedTexture = "spell_shadow_curseofachimonde"
            elseif spellID == 28834 then expectedTexture = "spell_shadow_sealofkings"
            elseif spellID == 28833 then expectedTexture = "spell_holy_elunesgrace"
            end

            if string.find(textureName, expectedTexture) then
                return stacks or 1 -- Return stack count, default to 1 if not available
            end
        end
        i = i + 1
    end
    return 0 -- No debuff found
end

-- Update function for distance checking and UI updates
local function UpdateFrame()
    if not frame or not frame:IsVisible() then
        return
    end

    local allSafe = true

    for pos, boss in pairs(bosses) do
        -- Resolve stacks and remaining duration
        local stacks, remaining
        if testMode then
            stacks = testData[pos].stacks
            remaining = testData[pos].remaining
        else
            stacks = GetDebuffStacks(boss.spellID)
            local state = debuffState[pos]
            if stacks == 0 then
                state.stacks = 0
                state.appliedAt = 0
                remaining = 0
            else
                if stacks > state.stacks then
                    state.appliedAt = GetTime()
                end
                state.stacks = stacks
                remaining = math.max(0, DEBUFF_DURATION - (GetTime() - state.appliedAt))
            end
        end

        -- Update icon texture and stack text
        local stackText = frame["stack" .. pos]
        local tex = frame["tex" .. pos]
        if stackText and tex then
            if stacks == 0 then
                stackText:SetText("")
                tex:SetVertexColor(0.5, 0.5, 0.5, 1)
            else
                stackText:SetText(stacks)
                tex:SetVertexColor(1, 1, 1, 1)
                if stacks >= 3 then
                    stackText:SetFont("Fonts\\FRIZQT__.TTF", TEXT_SIZE_LARGE, "OUTLINE")
                    stackText:SetTextColor(1, 0, 0, 1)
                else
                    stackText:SetFont("Fonts\\FRIZQT__.TTF", TEXT_SIZE_SMALL, "OUTLINE")
                    stackText:SetTextColor(1, 1, 0, 1)
                end
            end
        end

        -- Update duration bar
        local barContainer = frame["bar" .. pos]
        local barFill = frame["barFill" .. pos]
        if barContainer and barFill then
            if stacks > 0 then
                barContainer:Show()
                barFill:SetHeight(math.max(1, (remaining / DEBUFF_DURATION) * ICON_SIZE))
                barFill:SetVertexColor(1, 1, 1, 1) -- white; overridden to red below if in range
            else
                barContainer:Hide()
            end
        end

        -- Distance check and border/bar color updates
        if distanceCheckAvailable then
            local unit = FindUnitByName(boss.name)
            local inRange = false
            local inHolyWrathRange = false

            local distance = nil
            if unit and UnitExists(unit) then
                distance = GetDistance("player", unit)
            end
            if not distance then
                distance = GetDistanceToPosition(pos)
            end

            if distance then
                if distance <= SAFE_DISTANCE then
                    inRange = true
                    allSafe = false
                end
                if pos == "TR" and distance <= HOLY_WRATH_DISTANCE then
                    inHolyWrathRange = true
                end
            end

            local border = frame["border" .. pos]
            if border then
                if inRange and not inHolyWrathRange then
                    border:Show()
                else
                    border:Hide()
                end
            end

            if pos == "TR" and frame.holyWrathBorder then
                if inHolyWrathRange then
                    frame.holyWrathBorder:Show()
                else
                    frame.holyWrathBorder:Hide()
                end
            end

            if inRange and barFill and stacks > 0 then
                barFill:SetVertexColor(1, 0, 0, 1)
            end
        end
    end

    -- Update safe zone appearance
    if distanceCheckAvailable then
        if allSafe then
            frame.safeZone:SetTexture(0, 1, 0, 0.5)
            frame.safeZoneText:SetText("SAFE")
            frame.safeZoneText:Show()
        else
            frame.safeZone:SetTexture(0.5, 0.5, 0.5, 0.3)
            frame.safeZoneText:Hide()
        end
    end
end

-- Create icon frame helper
local function CreateBossIcon(parent, position, boss, iconSize)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetWidth(iconSize)
    icon:SetHeight(iconSize)

    -- Position the icon
    if position == "BL" then
        icon:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    elseif position == "TR" then
        icon:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    elseif position == "BR" then
        icon:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    elseif position == "TL" then
        icon:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    end

    -- Icon texture
    local tex = icon:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(icon)
    tex:SetTexture("Interface\\Icons\\" .. boss.icon)

    -- Border glow (shown when within range of boss)
    local border = icon:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetVertexColor(1, 0, 0, 0.8)
    border:SetWidth(iconSize * 2.0)
    border:SetHeight(iconSize * 2.0)
    border:SetPoint("CENTER", icon, "CENTER", 0, 0)
    border:Hide()

    -- Stack count text
    local stackText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stackText:SetPoint("CENTER", icon, "CENTER", 0, 0)
    stackText:SetTextColor(1, 1, 0, 1)
    stackText:SetFont("Fonts\\FRIZQT__.TTF", TEXT_SIZE_SMALL, "OUTLINE")
    stackText:SetText("") -- Will be updated by UpdateFrame()

    return icon, tex, border, stackText
end

-- Create the main frame
local function CreateMainFrame()
    -- Root frame
    frame = CreateFrame("Frame", "FourHMHelperFrame", UIParent)
    frame:SetWidth(120)
    frame:SetHeight(120)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    -- Semi-transparent black background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetTexture(0, 0, 0, 0.4)

    -- Create boss icons for each position
    for pos, boss in pairs(bosses) do
        local icon, tex, border, stackText = CreateBossIcon(frame, pos, boss, ICON_SIZE)
        frame["icon" .. pos] = icon
        frame["tex" .. pos] = tex
        frame["border" .. pos] = border
        frame["stack" .. pos] = stackText
    end

    -- Holy Wrath glow for Zeliek (TR) - golden proc border, pulsing
    local hwBorder = frame["iconTR"]:CreateTexture(nil, "OVERLAY")
    hwBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    hwBorder:SetBlendMode("ADD")
    hwBorder:SetVertexColor(1, 0.8, 0, 1)
    hwBorder:SetWidth(ICON_SIZE * 2.0)
    hwBorder:SetHeight(ICON_SIZE * 2.0)
    hwBorder:SetPoint("CENTER", frame["iconTR"], "CENTER", 0, 0)
    hwBorder:Hide()
    frame.holyWrathBorder = hwBorder

    -- Duration bars (vertical, outside each icon)
    local barAnchors = {
        TL = { point = "TOPRIGHT",    relPoint = "TOPLEFT"    },
        BL = { point = "BOTTOMRIGHT", relPoint = "BOTTOMLEFT" },
        TR = { point = "TOPLEFT",     relPoint = "TOPRIGHT"   },
        BR = { point = "BOTTOMLEFT",  relPoint = "BOTTOMRIGHT"},
    }
    for pos, anchors in pairs(barAnchors) do
        local barContainer = CreateFrame("Frame", nil, frame)
        barContainer:SetWidth(BAR_WIDTH)
        barContainer:SetHeight(ICON_SIZE)
        barContainer:SetPoint(anchors.point, frame["icon" .. pos], anchors.relPoint, 0, 0)

        local barBg = barContainer:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints(barContainer)
        barBg:SetTexture(0, 0, 0, 0.4)

        local barFill = barContainer:CreateTexture(nil, "ARTWORK")
        barFill:SetWidth(BAR_WIDTH)
        barFill:SetHeight(ICON_SIZE)
        barFill:SetPoint("BOTTOMLEFT", barContainer, "BOTTOMLEFT", 0, 0)
        barFill:SetPoint("BOTTOMRIGHT", barContainer, "BOTTOMRIGHT", 0, 0)
        barFill:SetTexture(1, 1, 1, 1)

        barContainer:Hide()
        frame["bar" .. pos] = barContainer
        frame["barFill" .. pos] = barFill
    end

    -- Safe zone in the center
    local safeZone = frame:CreateTexture(nil, "ARTWORK")
    safeZone:SetWidth(40)
    safeZone:SetHeight(40)
    safeZone:SetPoint("CENTER", frame, "CENTER", 0, 0)
    safeZone:SetTexture(0.5, 0.5, 0.5, 0.3) -- Start as grey (not safe)

    local safeZoneText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    safeZoneText:SetPoint("CENTER", safeZone, "CENTER", 0, 0)
    safeZoneText:SetTextColor(1, 1, 1, 1)
    safeZoneText:SetFont("Fonts\\FRIZQT__.TTF", TEXT_SIZE_SAFE, "OUTLINE")
    safeZoneText:Hide()

    frame.safeZone = safeZone
    frame.safeZoneText = safeZoneText

    -- Progress bar at bottom (outside the frame)
    --local progressBar = CreateFrame("StatusBar", nil, frame)
    --progressBar:SetWidth(frame:GetWidth())
    --progressBar:SetHeight(8)
    --progressBar:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    --progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    --progressBar:SetStatusBarColor(1, 0.7, 0, 1)
    --progressBar:SetMinMaxValues(0, 100)
    --progressBar:SetValue(50) -- PLACEHOLDER

    --local pbBg = progressBar:CreateTexture(nil, "BACKGROUND")
    --pbBg:SetAllPoints(progressBar)
    --pbBg:SetTexture(0, 0, 0, 0.5)
    --
    --frame.progressBar = progressBar

    -- Set up update timer
    frame:SetScript("OnUpdate", function()
        this.timeSinceLastUpdate = (this.timeSinceLastUpdate or 0) + arg1
        this.animTime = (this.animTime or 0) + arg1
        if this.timeSinceLastUpdate >= 0.1 then -- Update every 0.1 seconds
            UpdateFrame()
            this.timeSinceLastUpdate = 0
        end
        -- Pulse the Holy Wrath glow
        if frame.holyWrathBorder and frame.holyWrathBorder:IsVisible() then
            frame.holyWrathBorder:SetAlpha(0.5 + 0.5 * math.sin(this.animTime * 8))
        end
    end)

    frame:Hide()
end

-- Debug command: reports distance API availability and distances to nearby units
local function DebugRangeCheck()
    local p = function(msg) DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": " .. msg) end

    p("--- Range Check Debug ---")

    -- API availability
    p("GetDistanceBetweenUnits: " .. tostring(GetDistanceBetweenUnits ~= nil))
    p("SuperWoW: " .. tostring(SuperWoW ~= nil))
    p("SuperWoW.GetDistanceBetweenUnits: " .. tostring(SuperWoW ~= nil and SuperWoW.GetDistanceBetweenUnits ~= nil))
    p("UnitPosition: " .. tostring(UnitPosition ~= nil))
    p("distanceCheckAvailable: " .. tostring(distanceCheckAvailable))

    -- Sanity check: UnitPosition on player (should always return coords if SuperWoW is loaded)
    if UnitPosition then
        local x, y = UnitPosition("player")
        p("UnitPosition(player) -> " .. tostring(x) .. ", " .. tostring(y))
    end

    -- Try each API directly against target
    if UnitExists("target") then
        local targetName = UnitName("target") or "unknown"
        p("Target: " .. targetName)

        if GetDistanceBetweenUnits then
            local d = GetDistanceBetweenUnits("player", "target")
            p("  GetDistanceBetweenUnits -> " .. tostring(d))
        end
        if SuperWoW and SuperWoW.GetDistanceBetweenUnits then
            local d = SuperWoW.GetDistanceBetweenUnits("player", "target")
            p("  SuperWoW.GetDistanceBetweenUnits -> " .. tostring(d))
        end
        if UnitPosition then
            local x1, y1 = UnitPosition("player")
            local x2, y2 = UnitPosition("target")
            p("  UnitPosition(player) -> " .. tostring(x1) .. ", " .. tostring(y1))
            p("  UnitPosition(target) -> " .. tostring(x2) .. ", " .. tostring(y2))
            if x1 and y1 and x2 and y2 then
                local d = math.sqrt((x2-x1)^2 + (y2-y1)^2)
                p("  Calculated distance -> " .. string.format("%.1f", d))
            end
        end
        -- Combined GetDistance helper result
        local d = GetDistance("player", "target")
        p("  GetDistance() result -> " .. tostring(d))
    else
        p("No target. Target a unit to test distance.")
    end

    -- Try boss1-boss4 unit IDs with UnitPosition (instance boss units may have position data)
    p("Boss unit positions (boss1-boss4):")
    for i = 1, 4 do
        local unit = "boss" .. i
        if UnitExists(unit) then
            local name = UnitName(unit) or unit
            local x, y = UnitPosition(unit)
            p("  " .. unit .. " (" .. name .. "): " .. tostring(x) .. ", " .. tostring(y))
            local d = GetDistance("player", unit)
            p("    GetDistance -> " .. tostring(d))
        else
            p("  " .. unit .. ": does not exist")
        end
    end

    -- Scan party/raid members via UnitPosition (expected to work for group members)
    local units = { "target" }
    for i = 1, 4 do units[table.getn(units) + 1] = "party" .. i end
    for i = 1, 40 do units[table.getn(units) + 1] = "raid" .. i end

    p("Scanning units via GetDistance:")
    local found = 0
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local name = UnitName(unit) or unit
            local d = GetDistance("player", unit)
            if d then
                p("  " .. unit .. " (" .. name .. "): " .. string.format("%.1f", d) .. " yds")
                found = found + 1
            else
                p("  " .. unit .. " (" .. name .. "): nil")
            end
        end
    end
    if found == 0 then
        p("  (no units returned a distance)")
    end

    p("--- End Debug ---")
end

local function RecordBossPosition(pos)
    local p = function(msg) DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": " .. msg) end
    pos = string.upper(pos)
    if not bosses[pos] then
        p("Unknown position '" .. pos .. "'. Use TL, TR, BL, or BR.")
        return
    end
    if not UnitPosition then
        p("UnitPosition not available.")
        return
    end
    local x, y = UnitPosition("player")
    if not x or not y then
        p("Could not get player position.")
        return
    end
    bossPositions[pos] = { x = x, y = y }
    p(bosses[pos].name .. " (" .. pos .. ") recorded at " .. string.format("%.2f, %.2f", x, y))
    p("To hardcode: bossPositions." .. pos .. " = { x = " .. string.format("%.2f", x) .. ", y = " .. string.format("%.2f", y) .. " }")
end

-- Slash command handler
local function SlashCommandHandler(msg)
    if msg == "debug" then
        DebugRangeCheck()
        return
    end

    if msg == "test" then
        testMode = not testMode
        DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": Test mode " .. (testMode and "ON" or "OFF"))
        return
    end

    local recordPos = string.match(msg, "^record%s+(%S+)$")
    if recordPos then
        RecordBossPosition(recordPos)
        return
    end

    if not frame then
        CreateMainFrame()
    end

    isVisible = not isVisible
    if isVisible then
        frame:Show()
        DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": Enabled")
    else
        frame:Hide()
        DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": Disabled")
    end
end

-- Register slash command
SLASH_FOURHM1 = "/4hm"
SlashCmdList["FOURHM"] = SlashCommandHandler

DEFAULT_CHAT_FRAME:AddMessage(addonName .. " loaded. Use /4hm to toggle, /4hm record <TL|TR|BL|BR> to record boss positions, /4hm debug to test range checking.")
