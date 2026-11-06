-- DictionaryLoader.lua

for fromIdx = 0, numLangs - 1 do
    lookups[fromIdx] = {}
    translations[fromIdx] = {}
    for toIdx = 0, numLangs - 1 do
        translations[fromIdx][toIdx] = {}
    end
end

-- Load both directions for each language
for i = 1, numLangs - 1 do
    local langCode = langNames[i]
    local langIdx = i   -- This is the key line you were missing!

    -- 1. Load lang → English (detection + source → English)
    local toEnDict = _G["dict_" .. langCode .. "_to_en"] or {}
    for foreignWord, english in pairs(toEnDict) do
        local clean = string.lower(foreignWord or "")
        if clean ~= "" then
            lookups[langIdx][clean] = true
            translations[langIdx][0][clean] = english
        end
    end

    -- 2. Load English → lang
    local enToDict = _G["dict_en_to_" .. langCode] or {}
    for englishWord, foreign in pairs(enToDict) do
        local clean = string.lower(englishWord or "")
        if clean ~= "" then
            lookups[0][clean] = true
            translations[0][langIdx][clean] = foreign
        end
    end
	
	local countToEn = 0
    for _ in pairs(toEnDict) do countToEn = countToEn + 1 end
    
    local countEnTo = 0
    for _ in pairs(enToDict) do countEnTo = countEnTo + 1 end
    
	if TurtleTranslatorDB.debugEnabled then
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff88ff88DEBUG|r " .. langCode .. " (" .. langIdx .. "): " ..
        countToEn .. " incoming words loaded, " ..
        countEnTo .. " outgoing words loaded"
    )
	end
	
end

if TurtleTranslatorDB.debugEnabled then
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00TurtleTranslator|r Dictionaries loaded (pivot via English).")
end
