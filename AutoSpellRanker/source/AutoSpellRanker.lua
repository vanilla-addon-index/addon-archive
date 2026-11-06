local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")

-- Get highest rank from spellbook
local function GetHighestRank(spellBase)
    local i = 1
    local highest = 0
    while true do
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then break end

        spellName = tostring(spellName)
        local baseName = string.gsub(spellName, " %(Rank %d+%)", "")
        local rankNum = 0
        if spellRank and type(spellRank) == "string" then
            local found = string.match(spellRank, "(%d+)")
            if found then rankNum = tonumber(found) end
        end

        if baseName == spellBase and rankNum > highest then
            highest = rankNum
        end
        i = i + 1
    end
    return highest
end

-- Safely read tooltip lines
local function GetTooltipLines(slot)
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:ClearLines()
    GameTooltip:SetAction(slot)

    local lines = {}
    local numLines = GameTooltip:NumLines() or 0
    for i = 1, numLines do
        local leftLine = getglobal("GameTooltipTextLeft" .. i)
        if leftLine and leftLine.GetText then
            table.insert(lines, leftLine:GetText())
        end
        local rightLine = getglobal("GameTooltipTextRight" .. i)
        if rightLine and rightLine.GetText then
            table.insert(lines, rightLine:GetText())
        end
    end

    GameTooltip:Hide()
    return lines
end

-- Scan action bars
local function CheckOutdatedSpells()
    DEFAULT_CHAT_FRAME:AddMessage("AutoSpellRanker: Scanning your bars...")
    local outdatedCount = 0

    for slot = 1, 120 do
        if HasAction(slot) then
            local lines = GetTooltipLines(slot)
            local spellName = lines[1] or nil
            local currentRank = 0

            if spellName and type(spellName) == "string" then
                -- Check rank embedded in spell name (e.g., "Fireball (Rank 4)")
                local embedded = string.match(spellName, "%(Rank (%d+)%)")
                if embedded then
                    currentRank = tonumber(embedded)
                else
                    -- Otherwise, search all tooltip lines for "Rank X"
                    for _, line in ipairs(lines) do
                        if type(line) == "string" and string.find(line, "Rank") then
                            local found = string.match(line, "(%d+)")
                            if found then
                                currentRank = tonumber(found)
                                break
                            end
                        end
                    end
                end

                -- Compare to spellbook
                local highestRank = GetHighestRank(string.gsub(spellName, " %(Rank %d+%)", ""))
                if highestRank > 0 and currentRank < highestRank then
                    outdatedCount = outdatedCount + 1
                    DEFAULT_CHAT_FRAME:AddMessage(
                        "Slot " .. slot .. ": " .. spellName ..
                        " (Rank " .. currentRank .. ") → Highest Rank " .. highestRank
                    )
                end
            end
        end
    end

    if outdatedCount > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("Found " .. outdatedCount .. " outdated spells. Drag higher ranks manually.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("All spells are already at their highest ranks.")
    end
end

-- Slash command
f:SetScript("OnEvent", function()
    SLASH_ASR1 = "/asr"
    SlashCmdList["ASR"] = CheckOutdatedSpells
    DEFAULT_CHAT_FRAME:AddMessage("AutoSpellRanker loaded. Type /asr to scan for outdated spells.")
end)
