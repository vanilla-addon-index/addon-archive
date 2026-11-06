-- This file deliberately uses Lua 5.0 syntax so the diagnostic can load on stock clients.
DoesItDieVanilla = {}
local ns = DoesItDieVanilla
ns.ready = CLASSIC_API_VERSION and C_Spell and C_Spell.GetSpellDescription
    and UnitGUID and CombatLogGetCurrentEventInfo and C_NamePlate
    and C_NamePlate.GetNamePlateGUIDs and C_NamePlate.GetNamePlateForGUID
    and GetModernScriptArgs and GetModernScriptArgs()
if not ns.ready then
    DEFAULT_CHAT_FRAME:AddMessage("DoesItDie: a recent ClassicAPI with modern script arguments enabled is required. See README.md.")
end

-- Never compare raw damage against the stock enemy-health percentage (0..100).
-- Nampower exposes descriptor health in actual hit points. No global API overrides.
function ns.health(unit)
    if GetUnitField then
        local ok, hp, maximum = pcall(function()
            return GetUnitField(unit, "health"), GetUnitField(unit, "maxHealth")
        end)
        if ok and type(hp) == "number" and type(maximum) == "number" and maximum > 0 then
            return hp, maximum, "Nampower fields"
        end
    end
    if GetUnitData then
        local ok, data = pcall(GetUnitData, unit)
        if ok and type(data) == "table" and type(data.health) == "number"
            and type(data.maxHealth) == "number" and data.maxHealth > 0 then
            return data.health, data.maxHealth, "Nampower data"
        end
    end
    local hp, maximum = UnitHealth(unit), UnitHealthMax(unit)
    -- 100 is ambiguous even if the creature happens to have exactly 100 HP.
    if type(hp) == "number" and type(maximum) == "number" and maximum > 0 and maximum ~= 100 then
        return hp, maximum, "client"
    end
    return nil, nil, "unknown (percentage health)"
end
