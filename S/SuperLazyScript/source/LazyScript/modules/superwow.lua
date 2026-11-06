

-- === ---------------- =====
-- === New Cast Monitor =====
-- === ---------------- =====

-- ### Cast Monitor
-- -- SuperWoW event monitor
local castMonitor = CreateFrame("Frame", nil)
castMonitor:SetPoint("CENTER", UIParent, "CENTER", 0, 70)
castMonitor:SetWidth(64)
castMonitor:SetHeight(64)
castMonitor:RegisterEvent("UNIT_CASTEVENT")

castMonitor:SetScript("OnEvent", function()
    -- validate event type & target
    if not arg1 then
        return
    end

    local caster, target, event, spellId, castDuration = arg1, arg2, arg3, arg4, arg5

    local _, playerGuid = UnitExists('player')
    local _, targetGuid = UnitExists('target')

    if event == "MAINHAND" or event == "OFFHAND" or caster ~= targetGuid then
        return
    end

    local spell = SpellInfo(spellId)
    if not spell then
        return
    end

    -- goto interrupt func
    lazyScript.interrupt.OnSuperWoWSpell(spell, event)
end)

-- superLazyScript Helper Functions
-- ---
lazyScript = lazyScript or {}
lazyScript.superLazyScript = lazyScript.superLazyScript or {}
-- === Get Unit Distance ======
-- Get distance between 2 units
-- Defaults to distance to player with 1 argument
function lazyScript.superLazyScript.GetUnitDistance(unit1, unit2)
    if not unit2 then
        unit2 = unit1
        unit1 = "player"
    end
    if not UnitExists(unit2) then return nil end

    if not SUPERWOW_STRING and UnitPosition then return nil end
    -- superwow unit position
    local x1, y1, z1 = UnitPosition(unit1)
    local x2, y2, z2 = UnitPosition(unit2)
    if x1 and y1 and z1 and x2 and y2 and z2 then
        return ((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2) ^ 0.5
    end

    return nil
end
