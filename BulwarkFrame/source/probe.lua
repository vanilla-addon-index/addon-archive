-- BulwarkFrame - probe.lua
-- `/bulwark probe` -- one read-only sweep of everything the display still needs answered, dumped
-- both to chat and (with SuperWoW) to <WoW>\imports\bulwark_probe.txt so it can be read from
-- the dev side without anyone transcribing numbers. WoW-API file (parse-checked only).
--
-- It answers, in one go:
--   1. which aura carries the remaining DURATION -- 58130 or 58127 (the bar depends on it);
--   2. the real aura ids of the buffs we may want to show. A CAST id is not a BUFF id:
--      Stormstrike is cast as 17364 but sits on the player as 52412;
--   3. weapon speeds and the Elemental Weapons rank (-> absorb rate).
--
-- Best run WITH THE BUFFS UP, in combat, Rockbiter active. A buff that is not up simply does not
-- appear -- that is a valid answer too, just a less complete one.
--
-- ExportFile GOTCHA (in-game verified): it appends ".txt" itself, so the name is passed WITHOUT
-- an extension -- "bulwark_probe" becomes bulwark_probe.txt, "bulwark_probe.txt" would become
-- bulwark_probe.txt.txt.

BulwarkFrame = BulwarkFrame or {}
local BF = BulwarkFrame

local function out(lines, s)
    table.insert(lines, s)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66bbffBF|r " .. s)
end

function BF.RunProbe()
    local lines = {}
    out(lines, "probe " .. date("%Y-%m-%d %H:%M:%S"))
    out(lines, "superwow=" .. tostring(SUPERWOW_VERSION) .. " nampower=" .. tostring(NAMPOWER_VERSION))

    -- 1) every player buff with id, stacks and remaining time
    local i = 0
    local shown = 0
    while i < 32 do
        local slot = GetPlayerBuff(i, "HELPFUL")
        if not slot or slot < 0 then break end
        local id = GetPlayerBuffID and GetPlayerBuffID(slot)
        local tl = GetPlayerBuffTimeLeft and GetPlayerBuffTimeLeft(slot)
        local n = GetPlayerBuffApplications and GetPlayerBuffApplications(slot)
        local nm = "?"
        if SpellInfo and type(id) == "number" then
            local ok, s = pcall(SpellInfo, id)
            if ok and s then nm = s end
        end
        out(lines, "buff id=" .. tostring(id) .. " name=" .. tostring(nm)
            .. " stacks=" .. tostring(n) .. " timeLeft=" .. tostring(tl))
        shown = shown + 1
        i = i + 1
    end
    if shown == 0 then out(lines, "buff NONE -- no player buffs found") end

    -- 2) the two candidate auras, called out explicitly so the answer is not buried in the list
    local poolId, timeId = BulwarkFrameDB.poolAura, BulwarkFrameDB.timeAura
    out(lines, "configured poolAura=" .. tostring(poolId) .. " timeAura=" .. tostring(timeId))
    out(lines, "state hasPool=" .. tostring(BF.state.hasPool) .. " hasTime=" .. tostring(BF.state.hasTime)
        .. " stacks=" .. tostring(BF.state.stacks) .. " timeLeft=" .. tostring(BF.state.timeLeft))

    -- 3) API availability -- a missing function should be data, not a silent nil later
    local names = { "GetPlayerBuff", "GetPlayerBuffID", "GetPlayerBuffTimeLeft",
                    "GetPlayerBuffApplications", "UnitAttackSpeed", "SpellInfo", "ExportFile",
                    "GetNetStats", "UnitExists" }
    local j
    for j = 1, table.getn(names) do
        out(lines, "api " .. names[j] .. "=" .. type(getglobal(names[j])))
    end

    -- 4) weapon speeds, health, latency
    local main, off = nil, nil
    pcall(function() main, off = UnitAttackSpeed("player") end)
    out(lines, "attackSpeed main=" .. tostring(main) .. " off=" .. tostring(off))
    out(lines, "maxHP=" .. tostring(UnitHealthMax("player"))
        .. " -> 1 stack = " .. tostring(BulwarkFrameCalc.stackPoints(UnitHealthMax("player")))
        .. " points, full pool = " .. tostring(BulwarkFrameCalc.maxPool(UnitHealthMax("player"))))
    local _, _, lag = GetNetStats()
    out(lines, "latency_ms=" .. tostring(lag))

    -- 5) talent rank of Elemental Weapons, read rather than assumed
    local rank = nil
    if GetTalentInfo then
        local tab, idx
        for tab = 1, 3 do
            for idx = 1, 20 do
                local nm, _, _, _, cur = GetTalentInfo(tab, idx)
                if nm == "Elemental Weapons" then rank = cur end
            end
        end
    end
    out(lines, "talent ElementalWeapons rank=" .. tostring(rank)
        .. " configured=" .. tostring(BulwarkFrameDB.talentRank))

    -- 6) to disk, so the dev side can read it directly instead of transcribing chat
    if type(ExportFile) == "function" then
        local blob = table.concat(lines, "\n")
        local ok = pcall(ExportFile, "bulwark_probe", blob)
        if ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cff66bbffBF|r written to imports\\bulwark_probe.txt")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff66bbffBF|r ExportFile failed -- chat output only")
        end
    end
    return lines
end
