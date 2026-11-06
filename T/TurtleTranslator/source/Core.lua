-- Instead of old loop over dict rows
-- Call the loader early (e.g. at top or in ADDON_LOADED)

-- Your TranslateMessage stays almost the same:
-- It uses lookups[sourceIndex][wClean] for detection
-- translations[sourceIndex][targetIndex][wLower] for translation

TurtleTranslatorDB.channels = TurtleTranslatorDB.channels or {}

for key, value in pairs(defaultChannels) do
    if TurtleTranslatorDB.channels[key] == nil then
        TurtleTranslatorDB.channels[key] = value
    end
end

if TurtleTranslatorDB.debugEnabled == nil then
    TurtleTranslatorDB.debugEnabled = false
end

local playerName = UnitName("player")

local function TranslateMessage(msg, author)
    if not TurtleTranslatorDB.enabled then return end
    if not msg or msg == "" then return end
    if author == playerName then return end

    -- Step 1: Split into words, but keep original form with punctuation
    local words = {}
    for word in string.gfind(msg, "%S+") do
        table.insert(words, word)
    end
    if next(words) == nil then return end

    local targetIndex = TurtleTranslatorDB.targetLangIndex
	local sourceLangs = TurtleTranslatorDB.sourceLangs

    -- Step 2: Detection – clean words for matching only
    local matchCounts = {}
    for i = 1, numLangs do
        local langIdx = langs[i].index
        matchCounts[langIdx] = 0   -- count ALL languages (as per latest change)
    end

	for _, word in ipairs(words) do
		local wClean = string.lower(word) 
		wClean = string.gsub(wClean, "[%p%c%s¿¡]", "")   -- remove punctuation, control chars, spaces

		if wClean ~= "" then
			-- Only check lookups if we have a non-empty cleaned word
			for i = 1, numLangs do
				local langIdx = langs[i].index
				if lookups[langIdx][wClean] then
					-- Safe byte length (counts bytes, not characters — same as what # would return)
					local wordLen = 0
					for _ in string.gfind(wClean, ".") do
						wordLen = wordLen + 1
					end
					
					local points = math.max(1, wordLen - 3)  -- e.g. 4 bytes = 1 pt, 6 bytes = 3 pts, etc.
					matchCounts[langIdx] = matchCounts[langIdx] + points
				end
			end
		end
	end

    -- Find winner
    local maxCount = 0
    local sourceIndex = nil
    for langIdx, count in pairs(matchCounts) do
        if count > maxCount then
            maxCount = count
            sourceIndex = langIdx
        end
    end

    if TurtleTranslatorDB.debugEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88DEBUG|r Detection - words: " .. (function() local c=0 for _ in ipairs(words) do c=c+1 end return c end)() .. " | max matches: " .. maxCount .. " | source: " .. (sourceIndex or "nil"))
    end

    if not sourceIndex or maxCount == 0 then return end
	
	-- Check if user wants to translate FROM this detected language
    if sourceLangs[sourceIndex] ~= true then
        if TurtleTranslatorDB.debugEnabled then
            DEFAULT_CHAT_FRAME:AddMessage("|cff8888ffDEBUG|r Skipped: source language not selected for translation (" .. langs[sourceIndex + 1].name .. ")")
        end
        return
    end

    -- Skip if already in target language
    if sourceIndex == targetIndex then
        if TurtleTranslatorDB.debugEnabled then
            local matchedWords = {}
            for _, word in ipairs(words) do
                local wClean = string.lower(word)
                wClean = string.gsub(wClean, "[%p%c%s¿¡]", "")
                if wClean ~= "" and lookups[sourceIndex][wClean] then
                    table.insert(matchedWords, wClean)
                end
            end
            
            local matchList = table.concat(matchedWords, ", ")
            if matchList == "" then
                matchList = "(no matching words found)"
            end
            
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff8888ffDEBUG|r Skipped: source == target (" .. 
                langs[sourceIndex + 1].name .. "). " ..
                "Matched words in source language: " .. matchList
            )
        end
        return
    end

    -- Step 3: Translate with English pivot (any → any)
	local translatedWords = {}

	for _, word in ipairs(words) do
		local wLower = string.lower(word)
		wLower = string.gsub(wLower, "[%p%c%s¿¡。！？，；：（）“”‘’【】]", "")   -- expanded punctuation

		local translated = word  -- fallback

		if wLower ~= "" then
			local fromIdx = sourceIndex
			local toIdx   = targetIndex

			-- Try direct translation first (if we ever add direct dicts)
			local direct = translations[fromIdx][toIdx] and translations[fromIdx][toIdx][wLower]
			
			if direct then
				translated = direct
			else
				-- Pivot: Source → English → Target
				local english = translations[fromIdx][0] and translations[fromIdx][0][wLower]
				if english then
					local final = translations[0][toIdx] and translations[0][toIdx][english]
					if final then
						translated = final
					end
				end
			end

			-- Preserve letter capitalization
			if translated ~= word then
				local wlen = string.len(word)
				if wlen == 0 then 
					-- edge case, shouldn't happen
				else
					local first = string.sub(word, 1, 1)
					local is_all_upper = (string.upper(word) == word) and (wlen > 0)
					
					if is_all_upper then
						-- ALL CAPS original → make translated ALL CAPS
						translated = string.upper(translated)
						
					elseif first >= "A" and first <= "Z" then
						-- First letter was uppercase → capitalize only first letter of translation
						local rest = string.sub(translated, 2)
						if rest then
							translated = string.upper(string.sub(translated, 1, 1)) .. string.lower(rest)
						else
							translated = string.upper(translated)  -- single letter
						end
						
					else
						-- Original started with lowercase → keep translated lowercase
						translated = string.lower(translated)
					end
				end
			end
		end

		table.insert(translatedWords, translated)
	end

	local translated = table.concat(translatedWords, " ")

    DEFAULT_CHAT_FRAME:AddMessage("|cff19e6ca" .. "[TT]" .. "[" .. (author or "?") .. "]" .. ": " .. translated .. "|r (from " .. langs[sourceIndex + 1].name .. ")")
end

-- Event frame (unchanged)
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHAT_MSG_SAY")
f:RegisterEvent("CHAT_MSG_YELL")
f:RegisterEvent("CHAT_MSG_PARTY")
f:RegisterEvent("CHAT_MSG_GUILD")
f:RegisterEvent("CHAT_MSG_EMOTE")
f:RegisterEvent("CHAT_MSG_OFFICER")
f:RegisterEvent("CHAT_MSG_RAID")
f:RegisterEvent("CHAT_MSG_RAID_LEADER")
f:RegisterEvent("CHAT_MSG_RAID_WARNING")
f:RegisterEvent("CHAT_MSG_BATTLEGROUND")
f:RegisterEvent("CHAT_MSG_CHANNEL")

f:SetScript("OnEvent", function()
    local shouldTranslate = false

    if event == "CHAT_MSG_WHISPER" 		   and TurtleTranslatorDB.channels.whisper 		  then shouldTranslate = true end
    if event == "CHAT_MSG_SAY"    		   and TurtleTranslatorDB.channels.say     		  then shouldTranslate = true end
    if event == "CHAT_MSG_YELL"    		   and TurtleTranslatorDB.channels.yell    		  then shouldTranslate = true end
    if event == "CHAT_MSG_PARTY"   		   and TurtleTranslatorDB.channels.party   		  then shouldTranslate = true end
	if event == "CHAT_MSG_GUILD"   		   and TurtleTranslatorDB.channels.guild   		  then shouldTranslate = true end
	if event == "CHAT_MSG_EMOTE"   		   and TurtleTranslatorDB.channels.emote   		  then shouldTranslate = true end
	if event == "CHAT_MSG_OFFICER" 		   and TurtleTranslatorDB.channels.officer 		  then shouldTranslate = true end
	
    -- Raid chat (regular + leader messages)
    if (event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER")
       and TurtleTranslatorDB.channels.raid
    then
        shouldTranslate = true
    end
	
	if event == "CHAT_MSG_RAID_WARNING"    and TurtleTranslatorDB.channels.raidwarning    then shouldTranslate = true end
	if event == "CHAT_MSG_BATTLEGROUND"    and TurtleTranslatorDB.channels.battleground   then shouldTranslate = true end
	if event == "CHAT_MSG_CHANNEL"    	   and TurtleTranslatorDB.channels.otherchannels  then shouldTranslate = true end

    if shouldTranslate then
        TranslateMessage(arg1, arg2)
    end
end)

-- Load message (unchanged)
DEFAULT_CHAT_FRAME:AddMessage("|cffffffff[TT]" .. "|cff19e6ca Turtle Translator [" .. ADDON_VERSION .. "]|cffffffff loaded! Use /tt menu for settings.|r")