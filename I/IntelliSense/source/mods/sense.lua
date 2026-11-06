SHELL:LOCKED()

IS:NewModule('Sense', function ()
    local lowerCache = {}

    local CORE = {
        suggestion = nil,
        measureText = nil,
        framesCreated = false,
        suggestionColor = {0, 1, 1},
        matchBuffer = {}
    }

    local C = {
        CONTEXT_CLEANUP_BATCH_SIZE = 50,
        SUGGESTION_X_OFFSET = 15,
        FRAME_LEVEL_INCREMENT = 1,
        AUTO_CAPITALIZE_DEFAULT = 1
    }

    local H = {
        searchWordList = function(wordList, lastWordLower, lastWordLen, listType)
            local matches = {}
            CORE.matchBuffer = matches
            debugprint('searchWordList - Searching ' .. listType .. ' for: ' .. lastWordLower)

            local firstLetter = string.sub(lastWordLower, 1, 1)
            local letterWords = wordList[firstLetter]
            if not letterWords then
                debugprint('searchWordList - No words for letter: ' .. firstLetter)
                return nil
            end

            for i = 1, table.getn(letterWords) do
                local word = letterWords[i]
                local wordLower = lowerCache[word]
                if not wordLower then
                    wordLower = string.lower(word)
                    lowerCache[word] = wordLower
                end
                if lastWordLen < string.len(word) and string.sub(wordLower, 1, lastWordLen) == lastWordLower then
                    local usage = IS.stats.wordUsage[word] or 0
                    debugprint('searchWordList - Found match: ' .. word .. ' (usage: ' .. usage .. ')')
                    table.insert(matches, {word = word, usage = usage})
                end
            end

            if table.getn(matches) == 0 then
                debugprint('searchWordList - No matches in ' .. listType)
                return nil
            end

            table.sort(matches, function(a, b) return a.usage > b.usage end)
            debugprint('searchWordList - Best match from ' .. listType .. ': ' .. matches[1].word .. ' (usage: ' .. matches[1].usage .. ')')
            return matches[1].word
        end,

        wordExists = function(wordList, targetWord, listType, useGetData)
            local targetLower = string.lower(targetWord)
            local firstLetter = string.sub(targetLower, 1, 1)
            local letterWords = wordList[firstLetter]
            if not letterWords then
                return false
            end

            for i = 1, table.getn(letterWords) do
                local word = letterWords[i]
                local wordLower = lowerCache[word]
                if not wordLower then
                    wordLower = string.lower(word)
                    lowerCache[word] = wordLower
                end
                if wordLower == targetLower then
                    debugprint('LearnWord - Word exists in ' .. listType)
                    return true
                end
            end
            return false
        end,

        getPreviousWord = function(text)
            local words = {}
            for word in string.gfind(text, '[^%s]+') do
                table.insert(words, word)
            end
            local wordCount = table.getn(words)
            return wordCount > 0 and string.lower(words[wordCount]) or nil
        end,

        getPreviousTwoWords = function(text)
            local beforeLastWord = string.gsub(text, '%s*[^%s]*$', '')
            local words = {}
            for word in string.gfind(beforeLastWord, '[^%s]+') do
                table.insert(words, word)
            end
            local wordCount = table.getn(words)
            if wordCount >= 2 then
                return string.lower(words[wordCount - 1]), string.lower(words[wordCount])
            elseif wordCount == 1 then
                return nil, string.lower(words[wordCount])
            else
                return nil, nil
            end
        end,

        cleanupContext = function()
            local pairList = {}
            for word1, wordPairs in IS.TEMPCONTEXT do
                for word2, usage in wordPairs do
                    table.insert(pairList, {word1 = word1, word2 = word2, usage = usage, weightedUsage = usage, type = 'bigram'})
                end
            end
            for word1, word2Pairs in IS.TEMPTRIGRAMS do
                for word2, word3Pairs in word2Pairs do
                    for word3, usage in word3Pairs do
                        local weightedUsage = usage * 0.5
                        table.insert(pairList, {word1 = word1, word2 = word2, word3 = word3, usage = usage, weightedUsage = weightedUsage, type = 'trigram'})
                    end
                end
            end
            debugprint('cleanupContext - Weighted cleanup: trigrams 2x more likely to be removed')

            table.sort(pairList, function(a, b) return a.weightedUsage < b.weightedUsage end)

            local removed = 0
            local bigramsRemoved = 0
            local trigramsRemoved = 0
            for i = 1, C.CONTEXT_CLEANUP_BATCH_SIZE do
                local pair = pairList[i]
                if not pair then break end

                if pair.type == 'bigram' and IS.TEMPCONTEXT[pair.word1] then
                    IS.TEMPCONTEXT[pair.word1][pair.word2] = nil
                    local hasEntries = nil
                    for k, v in IS.TEMPCONTEXT[pair.word1] do
                        hasEntries = true
                        break
                    end
                    if not hasEntries then
                        IS.TEMPCONTEXT[pair.word1] = nil
                    end
                    IS.contextPairCount = IS.contextPairCount - 1
                    bigramsRemoved = bigramsRemoved + 1
                    removed = removed + 1
                elseif pair.type == 'trigram' and IS.TEMPTRIGRAMS[pair.word1] and IS.TEMPTRIGRAMS[pair.word1][pair.word2] then
                    IS.TEMPTRIGRAMS[pair.word1][pair.word2][pair.word3] = nil
                    local hasWord3Entries = nil
                    for k, v in IS.TEMPTRIGRAMS[pair.word1][pair.word2] do
                        hasWord3Entries = true
                        break
                    end
                    if not hasWord3Entries then
                        IS.TEMPTRIGRAMS[pair.word1][pair.word2] = nil
                        local hasWord2Entries = nil
                        for k, v in IS.TEMPTRIGRAMS[pair.word1] do
                            hasWord2Entries = true
                            break
                        end
                        if not hasWord2Entries then
                            IS.TEMPTRIGRAMS[pair.word1] = nil
                        end
                    end
                    IS.trigramCount = IS.trigramCount - 1
                    trigramsRemoved = trigramsRemoved + 1
                    removed = removed + 1
                end
            end
            debugprint('cleanupContext - Removed ' .. removed .. ' patterns (' .. bigramsRemoved .. ' bigrams, ' .. trigramsRemoved .. ' trigrams)')
        end,

        splitWords = function(text)
            local words = {}
            for word in string.gfind(text, '[^%s]+') do
                table.insert(words, word)
            end
            return words
        end
    }

    function CORE:Initialize()
        IS.stats.completions = IS.stats.completions or (IS.TEMPCONFIG.completions or 0)
        IS.stats.suggestionsShown = IS.stats.suggestionsShown or (IS.TEMPCONFIG.suggestionsShown or 0)
        IS.stats.charactersSaved = IS.stats.charactersSaved or (IS.TEMPCONFIG.charactersSaved or 0)
        IS.stats.wordUsage = IS.stats.wordUsage or (IS.TEMPCONFIG.wordUsage or {})
        IS.TEMPCONTEXT = IS.TEMPCONTEXT or {}
        IS.TEMPTRIGRAMS = IS.TEMPTRIGRAMS or {}
        IS.contextPairCount = 0
        IS.trigramCount = 0
        for word1, wordPairs in IS.TEMPCONTEXT do
            for word2, usage in wordPairs do
                IS.contextPairCount = IS.contextPairCount + 1
            end
        end
        for word1, word2Pairs in IS.TEMPTRIGRAMS do
            for word2, word3Pairs in word2Pairs do
                for word3, usage in word3Pairs do
                    IS.trigramCount = IS.trigramCount + 1
                end
            end
        end
        debugprint('Initialize - Loaded ' .. IS.contextPairCount .. ' bigrams, ' .. IS.trigramCount .. ' trigrams')

        self.suggestionColor = IS.TEMPCONFIG.suggestionColor or self.suggestionColor
        IS.TEMPCONFIG.suggestionColor = self.suggestionColor
        if IS.TEMPCONFIG.autoCapitalize == nil and not IS.TEMPCONFIG.autoCapitalizeSet then
            IS.TEMPCONFIG.autoCapitalize = C.AUTO_CAPITALIZE_DEFAULT
            IS.TEMPCONFIG.autoCapitalizeSet = C.AUTO_CAPITALIZE_DEFAULT
        end
    end

    function CORE:FindMatch(text)
        local lastWord = string.gsub(text, '.*[%s]+([^%s]*)$', '%1')
        if lastWord == text then
            lastWord = text
        end
        local lastWordLower = string.lower(lastWord)
        local lastWordLen = string.len(lastWord)
        debugprint('FindMatch - Cached lastWord length: ' .. lastWordLen .. ' for word: ' .. lastWord)

        if lastWordLen == 0 then
            local contextMatch = self:FindContextMatch(text)
            if contextMatch then
                debugprint('FindMatch - Found context match: ' .. contextMatch)
                return contextMatch, ''
            end
            debugprint('FindMatch - Early exit: empty lastWord')
            return nil
        end

        -- Check if context suggestion matches current prefix
        local contextMatch = self:FindContextMatch(text)
        if contextMatch then
            local contextLower = string.lower(contextMatch)
            if lastWordLen < string.len(contextMatch) and string.sub(contextLower, 1, lastWordLen) == lastWordLower then
                debugprint('FindMatch - Context match fits prefix: ' .. contextMatch .. ' matches ' .. lastWord)
                return contextMatch, lastWord
            else
                debugprint('FindMatch - Context match rejected: ' .. contextMatch .. ' does not match prefix ' .. lastWord)
            end
        end

        local match = H.searchWordList(IS.words, lastWordLower, lastWordLen, 'base words')
        if match then
            return match, lastWord
        end

        if IS.TEMPWORDS then
            local learnedMatch = H.searchWordList(IS.TEMPWORDS, lastWordLower, lastWordLen, 'learned words')
            if learnedMatch then
                return learnedMatch, lastWord
            end
        end
        debugprint('FindMatch - No match found')
        return nil
    end

    function CORE:FindContextMatch(text)
        local word1, word2 = H.getPreviousTwoWords(text)

        -- Try trigram first (3-word context)
        if word1 and word2 and IS.TEMPTRIGRAMS[word1] and IS.TEMPTRIGRAMS[word1][word2] then
            local bestWord = nil
            local bestUsage = 0
            for nextWord, usage in IS.TEMPTRIGRAMS[word1][word2] do
                if usage > bestUsage then
                    bestWord = nextWord
                    bestUsage = usage
                end
            end
            if bestWord then
                debugprint('FindContextMatch - Trigram match: ' .. word1 .. ' ' .. word2 .. ' -> ' .. bestWord .. ' (usage: ' .. bestUsage .. ')')
                return bestWord
            end
        end

        -- Fallback to bigram (2-word context)
        local prevWord = word2 or H.getPreviousWord(text)
        if not prevWord or not IS.TEMPCONTEXT[prevWord] then
            debugprint('FindContextMatch - No context available')
            return nil
        end

        local bestWord = nil
        local bestUsage = 0
        for nextWord, usage in IS.TEMPCONTEXT[prevWord] do
            if usage > bestUsage then
                bestWord = nextWord
                bestUsage = usage
            end
        end

        if bestWord then
            debugprint('FindContextMatch - Bigram match: ' .. prevWord .. ' -> ' .. bestWord .. ' (usage: ' .. bestUsage .. ')')
        end
        return bestWord
    end

    function CORE:TrackContext(text)
        local words = H.splitWords(text)
        for i = 1, table.getn(words) do
            words[i] = string.lower(words[i])
        end

        -- Track bigrams (2-word sequences)
        for i = 1, table.getn(words) - 1 do
            local word1 = words[i]
            local word2 = words[i + 1]

            if not IS.TEMPCONTEXT[word1] then
                IS.TEMPCONTEXT[word1] = {}
            end

            if not IS.TEMPCONTEXT[word1][word2] then
                IS.contextPairCount = IS.contextPairCount + 1
            end
            IS.TEMPCONTEXT[word1][word2] = (IS.TEMPCONTEXT[word1][word2] or 0) + 1
            debugprint('TrackContext - Bigram: ' .. word1 .. ' -> ' .. word2 .. ' (usage: ' .. IS.TEMPCONTEXT[word1][word2] .. ')')
        end

        -- Track trigrams (3-word sequences)
        for i = 1, table.getn(words) - 2 do
            local word1 = words[i]
            local word2 = words[i + 1]
            local word3 = words[i + 2]

            if not IS.TEMPTRIGRAMS[word1] then
                IS.TEMPTRIGRAMS[word1] = {}
            end
            if not IS.TEMPTRIGRAMS[word1][word2] then
                IS.TEMPTRIGRAMS[word1][word2] = {}
            end

            if not IS.TEMPTRIGRAMS[word1][word2][word3] then
                IS.trigramCount = IS.trigramCount + 1
            end
            IS.TEMPTRIGRAMS[word1][word2][word3] = (IS.TEMPTRIGRAMS[word1][word2][word3] or 0) + 1
            debugprint('TrackContext - Trigram: ' .. word1 .. ' ' .. word2 .. ' -> ' .. word3 .. ' (usage: ' .. IS.TEMPTRIGRAMS[word1][word2][word3] .. ')')
        end

        local totalPatterns = IS.contextPairCount + IS.trigramCount
        if totalPatterns > (IS.TEMPCONFIG.contextCleanupThreshold or 550) then
            debugprint('TrackContext - Cleanup triggered: ' .. totalPatterns .. ' total patterns')
            H.cleanupContext()
        end
    end

    function CORE:CreateTxtFrame()
        if self.framesCreated then return end
        assert(ChatFrameEditBox, 'ChatFrameEditBox not available')

        local suggestionFrame = CreateFrame('Frame', nil, UIParent)
        suggestionFrame:SetFrameStrata('TOOLTIP')
        suggestionFrame:SetFrameLevel(ChatFrameEditBox:GetFrameLevel() + C.FRAME_LEVEL_INCREMENT)

        self.suggestion = suggestionFrame:CreateFontString(nil, 'OVERLAY')
        self.suggestion:SetFontObject(ChatFontNormal)
        self.suggestion:SetTextColor(self.suggestionColor[1], self.suggestionColor[2], self.suggestionColor[3])

        self.measureText = UIParent:CreateFontString(nil, 'OVERLAY')
        self.measureText:SetFontObject(ChatFontNormal)
        self.measureText:Hide()

        self.framesCreated = true
        debugprint 'CreateTxtFrame - UI components created'
    end

    function CORE:ClearSuggestion()
        self.suggestion:ClearAllPoints()
        self.suggestion:SetText('')
    end

    function CORE:ShowSuggestion(text, word, lastWord)
        assert(self.suggestion, 'suggestion UI not created')

        self.measureText:SetText(text)
        local textWidth = self.measureText:GetStringWidth()

        self.suggestion:ClearAllPoints()
        self.suggestion:SetPoint('LEFT', ChatFrameEditBox, 'LEFT', 15 + ChatFrameEditBoxHeader:GetWidth() + textWidth, 0)
        self.suggestion:SetText(string.sub(word, string.len(lastWord) + 1))
    end

    function CORE:LearnWord(text)
        assert(text, 'LearnWord - text parameter is nil')
        debugprint('LearnWord - Processing text: ' .. text)

        local _, _, foundWord = string.find(text, '%*([^%*]+)%*')
        if not foundWord then
            debugprint('LearnWord - No learning pattern found')
            return text
        end

        assert(foundWord and string.len(foundWord) > 0, 'LearnWord - extracted word is empty')
        debugprint('LearnWord - Found word to learn: ' .. foundWord)

        assert(IS.words, 'LearnWord - IS.words is nil')

        local exists = H.wordExists(IS.words, foundWord, 'base dictionary', false)

        if not exists and IS.TEMPWORDS then
            exists = H.wordExists(IS.TEMPWORDS, foundWord, 'learned words', true)
        end

        if not exists then
            if not IS.TEMPWORDS then
                IS.TEMPWORDS = {}
                debugprint('LearnWord - Created IS.TEMPWORDS table')
            end
            local firstLetter = string.lower(string.sub(foundWord, 1, 1))
            if not IS.TEMPWORDS[firstLetter] then
                IS.TEMPWORDS[firstLetter] = {}
            end
            table.insert(IS.TEMPWORDS[firstLetter], foundWord)
            debugprint('LearnWord - Added word to dictionary: ' .. foundWord .. ' (letter: ' .. firstLetter .. ')')
            if IS.OnWordsChanged then IS:OnWordsChanged() end
            if IS.OnStatsChanged then IS:OnStatsChanged() end
        else
            debugprint('LearnWord - Word already exists, skipping: ' .. foundWord)
        end

        local cleanText = string.gsub(text, '%*+([^%*]+)%*+', '%1')
        debugprint('LearnWord - Cleaned text: ' .. cleanText)
        return cleanText
    end

    function CORE:TrackNaturalUsage(text)
        local words = H.splitWords(text)

        for i = 1, table.getn(words) do
            local word = words[i]
            if H.wordExists(IS.words, word, 'base words', false) or (IS.TEMPWORDS and H.wordExists(IS.TEMPWORDS, word, 'learned words', false)) then
                IS.stats.wordUsage[word] = (IS.stats.wordUsage[word] or 0) + 1
                IS.TEMPCONFIG.wordUsage = IS.stats.wordUsage
                debugprint('TrackNaturalUsage - Incremented: ' .. word .. ' (usage: ' .. IS.stats.wordUsage[word] .. ')')
            end
        end

        self:TrackContext(text)
        if IS.OnStatsChanged then IS:OnStatsChanged() end
    end

    function CORE:RemoveWord(targetWord)
        assert(targetWord, 'RemoveWord - targetWord is nil')
        assert(IS.TEMPWORDS, 'RemoveWord - IS.TEMPWORDS is nil')

        local targetLower = string.lower(targetWord)
        local firstLetter = string.sub(targetLower, 1, 1)
        local letterWords = IS.TEMPWORDS[firstLetter]
        if not letterWords then
            debugprint('RemoveWord - No words for letter: ' .. firstLetter)
            return
        end

        for i = 1, table.getn(letterWords) do
            local word = letterWords[i]
            if string.lower(word) == targetLower then
                for j = i, table.getn(letterWords) - 1 do
                    letterWords[j] = letterWords[j + 1]
                end
                letterWords[table.getn(letterWords)] = nil
                debugprint('RemoveWord - Removed: ' .. targetWord)
                if IS.OnWordsChanged then IS:OnWordsChanged() end
                if IS.OnStatsChanged then IS:OnStatsChanged() end
                return
            end
        end
        debugprint('RemoveWord - Word not found: ' .. targetWord)
    end

    function CORE:ShouldCapitalize(text, wordPosition)
        debugprint('ShouldCapitalize - wordPosition: ' .. wordPosition .. ', text: "' .. text .. '"')
        if wordPosition == 1 then
            debugprint('ShouldCapitalize - Start of text, should capitalize')
            return true
        end
        local beforeWord = string.sub(text, 1, wordPosition - 1)
        local foundPunctuation = string.find(beforeWord, '[%.%?%!]%s*$')
        debugprint('ShouldCapitalize - beforeWord: "' .. beforeWord .. '", foundPunctuation: ' .. (foundPunctuation and 'true' or 'false'))
        return foundPunctuation
    end

    function CORE:ProcessWordCase(matchedWord, lastWord, text, wordPosition)
        debugprint('ProcessWordCase - matchedWord: "' .. matchedWord .. '", lastWord: "' .. lastWord .. '", autoCapitalize: ' .. (IS.TEMPCONFIG.autoCapitalize and 'true' or 'false'))
        if not IS.TEMPCONFIG.autoCapitalize then
            local result = lastWord .. string.sub(matchedWord, string.len(lastWord) + 1)
            debugprint('ProcessWordCase - Auto-capitalize OFF, result: "' .. result .. '"')
            return result
        end

        if self:ShouldCapitalize(text, wordPosition) then
            local firstChar = string.upper(string.sub(matchedWord, 1, 1))
            local restOfWord = string.sub(matchedWord, 2)
            local result = firstChar .. restOfWord
            debugprint('ProcessWordCase - Should capitalize, result: "' .. result .. '"')
            return result
        else
            debugprint('ProcessWordCase - No capitalization needed, result: "' .. matchedWord .. '"')
            return matchedWord
        end
    end

    function CORE:Hook()
        if not ChatFrameEditBox then
            debugprint 'Hook - ChatFrameEditBox not ready'
            return
        end
        debugprint 'Hook - ChatFrameEditBox ready'

        local originalOnTextChanged = _G.ChatEdit_OnTextChanged
        local originalOnTabPressed = _G.ChatEdit_OnTabPressed
        local originalOnEscapePressed = _G.ChatEdit_OnEscapePressed
        local originalOnEnterPressed = _G.ChatEdit_OnEnterPressed

        _G.ChatEdit_OnTextChanged = function()
            if originalOnTextChanged then originalOnTextChanged() end

            local text = ChatFrameEditBox:GetText()
            local word, lastWord = self:FindMatch(text)
            if word and lastWord then
                IS.stats.suggestionsShown = IS.stats.suggestionsShown + 1
                IS.TEMPCONFIG.suggestionsShown = IS.stats.suggestionsShown
                if IS.OnStatsChanged then IS:OnStatsChanged() end
                self:ShowSuggestion(text, word, lastWord)
            else
                self:ClearSuggestion()
            end
        end

        _G.ChatEdit_OnTabPressed = function()
            local text = ChatFrameEditBox:GetText()
            local word, lastWord = self:FindMatch(text)
            if word then
                IS.stats.completions = IS.stats.completions + 1
                IS.TEMPCONFIG.completions = IS.stats.completions

                local savedChars = string.len(word) - string.len(lastWord)
                IS.stats.charactersSaved = IS.stats.charactersSaved + savedChars
                IS.TEMPCONFIG.charactersSaved = IS.stats.charactersSaved

                IS.stats.wordUsage[word] = (IS.stats.wordUsage[word] or 0) + 1
                IS.TEMPCONFIG.wordUsage = IS.stats.wordUsage

                if lastWord == '' then
                    local prevWord = H.getPreviousWord(text)
                    if prevWord and IS.TEMPCONTEXT[prevWord] and IS.TEMPCONTEXT[prevWord][string.lower(word)] then
                        IS.TEMPCONTEXT[prevWord][string.lower(word)] = IS.TEMPCONTEXT[prevWord][string.lower(word)] + 1
                        debugprint('TabPressed - Context usage incremented: ' .. prevWord .. ' -> ' .. string.lower(word))
                    end
                end

                if IS.OnStatsChanged then IS:OnStatsChanged() end

                local wordPosition = string.len(text) - string.len(lastWord) + 1
                local finalWord = self:ProcessWordCase(word, lastWord, text, wordPosition)
                local newText = string.sub(text, 1, string.len(text) - string.len(lastWord)) .. finalWord .. ' '
                ChatFrameEditBox:SetText(newText)
                return
            end
            if originalOnTabPressed then originalOnTabPressed() end
        end

        _G.ChatEdit_OnEscapePressed = function()
            if originalOnEscapePressed then originalOnEscapePressed(ChatFrameEditBox) end
            self:ClearSuggestion()
        end

        _G.ChatEdit_OnEnterPressed = function()
            debugprint 'ChatEdit_OnEnterPressed'
            local text = ChatFrameEditBox:GetText()

            -- track natural word usage
            self:TrackNaturalUsage(text)

            local cleanText = self:LearnWord(text)
            if cleanText ~= text then
                ChatFrameEditBox:SetText(cleanText)
            end

            if originalOnEnterPressed then originalOnEnterPressed(ChatFrameEditBox) end
            self:ClearSuggestion()
        end
    end

    CORE:Initialize()
    CORE:CreateTxtFrame()
    CORE:Hook()

    -- expose
    function IS:RemoveLearnedWord(targetWord)
        return CORE:RemoveWord(targetWord)
    end

    function IS:UpdateSuggestionColor(color)
        if CORE.suggestion then
            CORE.suggestion:SetTextColor(color[1], color[2], color[3])
        end
    end
end)
