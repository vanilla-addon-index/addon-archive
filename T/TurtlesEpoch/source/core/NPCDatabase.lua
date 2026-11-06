-- TurtlesEpoch: NPCDatabase.lua
-- Wraps the pre-built TT_NPC_DATA table (loaded from data/npc_data.lua)
-- Provides lookup functions for NPC race and sex

local TT = TurtlesEpoch

---Look up an NPC's voice profile data by name.
-- @param npcName  The NPC name as returned by UnitName("npc")
-- @return race, sex  or "Narrator", "unknown" if not found
function TT:LookupNPC(npcName)
    if not npcName or not TT_NPC_DATA then
        return "Narrator", "unknown"
    end

    local entry = TT_NPC_DATA[npcName]
    if entry then
        return entry.race or "Narrator", entry.sex or "unknown"
    end

    return "Narrator", "unknown"
end

---Attempt runtime race detection via WoW API.
-- Falls back to database lookup if API returns nil (non-playable races).
-- @param unit  Unit token (usually "npc")
-- @return race, sex
function TT:DetectNPCRace(unit)
    local name = UnitName(unit)

    -- Try WoW API first (only works for playable races)
    local apiRace = UnitRace(unit)
    if apiRace and apiRace ~= "" then
        -- UnitSex: 1=unknown, 2=male, 3=female
        local sexCode = UnitSex(unit)
        local sex = "unknown"
        if sexCode == 2 then
            sex = "male"
        elseif sexCode == 3 then
            sex = "female"
        end
        return apiRace, sex
    end

    -- Fall back to pre-built database
    return self:LookupNPC(name)
end
