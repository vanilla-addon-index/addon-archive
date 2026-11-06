SHELL:LOCKED()

IS:NewModule('Gui', function()
    local DEFAULT_CONTEXT_CLEANUP_THRESHOLD = 550

    local CORE = {
        configFrame = nil,
        blueColor = {0, 0.67, 1},
        grayColor = {0.65, 0.65, 0.65},
        firstWordOffset = 30,
        wordElements = {},
    }

    local function countHashTableWords(hashTable)
        if not hashTable then return 0 end
        local count = 0
        for _, words in pairs(hashTable) do
            if type(words) == 'table' then
                count = count + table.getn(words)
            end
        end
        return count
    end

    local function getAllWordsFromHash(hashTable)
        local allWords = {}
        if not hashTable then return allWords end
        for _, words in pairs(hashTable) do
            if type(words) == 'table' then
                for i = 1, table.getn(words) do
                    table.insert(allWords, words[i])
                end
            end
        end
        return allWords
    end

    function CORE:ShowConfigFrame()
        if not self.configFrame then
            self.configFrame = IS.gui.Frame(UIParent, 600, 600, 0.4)
            self.configFrame:SetPoint('CENTER', 0, 0)
            self.configFrame:EnableMouse(true)
            self.configFrame:SetMovable(true)
            self.configFrame:RegisterForDrag('LeftButton')
            self.configFrame:SetScript('OnMouseDown', function()
                self.configFrame:StartMoving()
            end)
            self.configFrame:SetScript('OnMouseUp', function()
                self.configFrame:StopMovingOrSizing()
            end)
            self.configFrame:Hide()

            local header = IS.gui.Font(self.configFrame, 18, '|cFFEEEEEEIntelli|cFF00AAFFSense|r')
            header:SetPoint('TOP', self.configFrame, 'TOP', 0, -20)

            local closeButton = IS.gui.Button(self.configFrame, 'X', 20, 20, true, {1, 0, 0}, false)
            closeButton:SetPoint('TOPRIGHT', self.configFrame, 'TOPRIGHT', -5, -5)
            closeButton:SetScript('OnClick', function()
                self.configFrame:Hide()
            end)

            self:CreateWordDatabase()
            self:CreateStatistics()
            self:CreateInfo()
            self:CreateBottomControls()
            self:UpdateAll()

            self.configFrame:SetScript('OnShow', function()
                self:UpdateAll()
            end)
        end
    end

    function CORE:ToggleConfigFrame()
        if not self.configFrame then
            self:ShowConfigFrame()
        end
        if self.configFrame:IsVisible() then
            self.configFrame:Hide()
        else
            self.configFrame:Show()
        end
    end

    function CORE:CreateWordDatabase()
        if self.wordScrollframe then return end
        local dbHeader = IS.gui.Font(self.configFrame, 14, 'Learned Words Database:', self.blueColor)
        dbHeader:SetPoint('TOPLEFT', self.configFrame, 'TOPLEFT', 20, -60)

        IS.gui.Font(self.configFrame, 10, 'Asterix to teach new *word* to IntelliSense', self.grayColor, 'LEFT'):SetPoint('TOPLEFT', self.configFrame, 'TOPLEFT', 20, -85)

        local wordDbFrame = IS.gui.Frame(self.configFrame, 250, 480, 0.1)
        wordDbFrame:SetPoint('TOPLEFT', self.configFrame, 'TOPLEFT', 20, -80)

        self.wordScrollframe = IS.gui.Scrollframe(wordDbFrame, 250, 450)
        self.wordScrollframe:SetPoint('TOPLEFT', wordDbFrame, 'TOPLEFT', 0, -30)
    end

    function CORE:CreateStatistics()
        if self.statsFrame then return end
        local statsHeader = IS.gui.Font(self.configFrame, 14, 'Statistics:', self.blueColor)
        statsHeader:SetPoint('TOP', self.configFrame, 'TOP', 61, -60)

        self.statsFrame = IS.gui.Frame(self.configFrame, 250, 330, 0.1)
        self.statsFrame:SetPoint('TOPRIGHT', self.configFrame, 'TOPRIGHT', -20, -80)

        IS.gui.Font(self.statsFrame, 12, 'Learned Words:', self.grayColor, 'LEFT'):SetPoint('TOPLEFT', self.statsFrame, 'TOPLEFT', 5, -self.firstWordOffset)
        self.wordCountValue = IS.gui.Font(self.statsFrame, 12, '0', {1, 1, 1}, 'RIGHT')
        self.wordCountValue:SetPoint('TOPRIGHT', self.statsFrame, 'TOPRIGHT', -5, -self.firstWordOffset)

        assert(IS.words, 'IS.words is nil')
        local internalCount = countHashTableWords(IS.words)
        IS.gui.Font(self.statsFrame, 12, 'Internal Vocabulary:', self.grayColor, 'LEFT'):SetPoint('TOPLEFT', self.statsFrame, 'TOPLEFT', 5, -self.firstWordOffset - 20)
        self.internalVocabValue = IS.gui.Font(self.statsFrame, 12, internalCount, {1, 1, 1}, 'RIGHT')
        self.internalVocabValue:SetPoint('TOPRIGHT', self.statsFrame, 'TOPRIGHT', -5, -self.firstWordOffset - 20)

        IS.gui.Font(self.statsFrame, 12, 'Completions:', self.grayColor, 'LEFT'):SetPoint('TOPLEFT', self.statsFrame, 'TOPLEFT', 5, -self.firstWordOffset - 40)
        self.completionsValue = IS.gui.Font(self.statsFrame, 12, '0', {1, 1, 1}, 'RIGHT')
        self.completionsValue:SetPoint('TOPRIGHT', self.statsFrame, 'TOPRIGHT', -5, -self.firstWordOffset - 40)

        IS.gui.Font(self.statsFrame, 12, 'Suggestions Shown:', self.grayColor, 'LEFT'):SetPoint('TOPLEFT', self.statsFrame, 'TOPLEFT', 5, -self.firstWordOffset - 60)
        self.suggestionsValue = IS.gui.Font(self.statsFrame, 12, '0', {1, 1, 1}, 'RIGHT')
        self.suggestionsValue:SetPoint('TOPRIGHT', self.statsFrame, 'TOPRIGHT', -5, -self.firstWordOffset - 60)

        IS.gui.Font(self.statsFrame, 12, 'Characters Saved:', self.grayColor, 'LEFT'):SetPoint('TOPLEFT', self.statsFrame, 'TOPLEFT', 5, -self.firstWordOffset - 80)
        self.charactersSavedValue = IS.gui.Font(self.statsFrame, 12, '0', {1, 1, 1}, 'RIGHT')
        self.charactersSavedValue:SetPoint('TOPRIGHT', self.statsFrame, 'TOPRIGHT', -5, -self.firstWordOffset - 80)

        IS.gui.Font(self.statsFrame, 12, 'Most Used Word:', self.grayColor, 'LEFT'):SetPoint('TOPLEFT', self.statsFrame, 'TOPLEFT', 5, -self.firstWordOffset - 100)
        self.mostUsedWordValue = IS.gui.Font(self.statsFrame, 12, 'None', {1, 1, 1}, 'RIGHT')
        self.mostUsedWordValue:SetPoint('TOPRIGHT', self.statsFrame, 'TOPRIGHT', -5, -self.firstWordOffset - 100)

        IS.gui.Font(self.statsFrame, 12, 'Efficiency Score:', self.grayColor, 'LEFT'):SetPoint('TOPLEFT', self.statsFrame, 'TOPLEFT', 5, -self.firstWordOffset - 120)
        self.efficiencyScoreValue = IS.gui.Font(self.statsFrame, 12, '0%', {1, 1, 1}, 'RIGHT')
        self.efficiencyScoreValue:SetPoint('TOPRIGHT', self.statsFrame, 'TOPRIGHT', -5, -self.firstWordOffset - 120)

        IS.gui.Font(self.statsFrame, 12, 'Pattern Strength:', self.grayColor, 'LEFT'):SetPoint('TOPLEFT', self.statsFrame, 'TOPLEFT', 5, -self.firstWordOffset - 140)
        self.patternStrengthValue = IS.gui.Font(self.statsFrame, 12, '0', {1, 1, 1}, 'RIGHT')
        self.patternStrengthValue:SetPoint('TOPRIGHT', self.statsFrame, 'TOPRIGHT', -5, -self.firstWordOffset - 140)

        IS.gui.Font(self.statsFrame, 12, 'Context Pairs:', self.grayColor, 'LEFT'):SetPoint('TOPLEFT', self.statsFrame, 'TOPLEFT', 5, -self.firstWordOffset - 160)
        self.contextPairsValue = IS.gui.Font(self.statsFrame, 12, '0/' .. (IS.TEMPCONFIG.contextCleanupThreshold or DEFAULT_CONTEXT_CLEANUP_THRESHOLD), {1, 1, 1}, 'RIGHT')
        self.contextPairsValue:SetPoint('TOPRIGHT', self.statsFrame, 'TOPRIGHT', -5, -self.firstWordOffset - 160)
    end

    function CORE:CreateInfo()
        if self.infoFrame then return end
        local infoHeader = IS.gui.Font(self.configFrame, 14, 'Info:', self.blueColor)
        infoHeader:SetPoint('BOTTOM', self.configFrame, 'BOTTOM', 61, 200)

        self.infoFrame = IS.gui.Frame(self.configFrame, 250, 60, 0.1)
        self.infoFrame:SetPoint('BOTTOMRIGHT', self.configFrame, 'BOTTOMRIGHT', -20, 130)
        IS.gui.Font(self.infoFrame, 12, 'TOC Version:', self.grayColor, 'LEFT'):SetPoint('TOPLEFT', self.infoFrame, 'TOPLEFT', 5, -self.firstWordOffset + 20)
        IS.gui.Font(self.infoFrame, 12, info.TOCversion, {1, 1, 1}, 'RIGHT'):SetPoint('TOPRIGHT', self.infoFrame, 'TOPRIGHT', -5, -self.firstWordOffset + 20)

        IS.gui.Font(self.infoFrame, 12, 'DB Version:', self.grayColor, 'LEFT'):SetPoint('TOPLEFT', self.infoFrame, 'TOPLEFT', 5, -self.firstWordOffset - 20 + 20)
        IS.gui.Font(self.infoFrame, 12, info.DBversion, {1, 1, 1}, 'RIGHT'):SetPoint('TOPRIGHT', self.infoFrame, 'TOPRIGHT', -5, -self.firstWordOffset - 20 + 20)
    end

    function CORE:CreateBottomControls()
        if self.colorPicker then return end
        self.resetButton = IS.gui.Button(self.configFrame, 'Reset', 50, 20, false, {1, 0, 0}, false)
        self.resetButton:SetPoint('BOTTOMRIGHT', self.configFrame, 'BOTTOMRIGHT', -200, 15)
        self.resetButton:SetScript('OnClick', function()
            IS.gui.Confirmbox('Reset all data and reload UI?', function()
                CORE:ResetAll()
            end)
        end)

        self.limitSlider = IS.gui.Slider(self.configFrame, nil, 'Context Limit:', 100, 1000, 50, '%.0f', 100, 24)
        self.limitSlider:SetPoint('BOTTOMRIGHT', self.configFrame, 'BOTTOMRIGHT', -55, 75)
        self.limitSlider:SetValue(IS.TEMPCONFIG.contextCleanupThreshold or DEFAULT_CONTEXT_CLEANUP_THRESHOLD)
        self.limitSlider:SetScript('OnValueChanged', function()
            self.limitSlider.updateValueText()
            local value = self.limitSlider:GetValue()
            IS.TEMPCONFIG.contextCleanupThreshold = value
            self:UpdateStats()
            debugprint('Context cleanup threshold changed to: ' .. value)
        end)

        self.autoCapitalizeCheckbox = IS.gui.Checkbox(self.configFrame, 'Auto-capitalize:      ', 20, 20, self.grayColor)
        self.autoCapitalizeCheckbox:SetPoint('BOTTOMRIGHT', self.configFrame, 'BOTTOMRIGHT', -25, 45)
        self.autoCapitalizeCheckbox:SetChecked(IS.TEMPCONFIG.autoCapitalize)
        self.autoCapitalizeCheckbox:SetScript('OnClick', function()
            IS.TEMPCONFIG.autoCapitalize = self.autoCapitalizeCheckbox:GetChecked()
        end)

        local colorLabel = IS.gui.Font(self.configFrame, 12, 'Suggestion Color:', self.grayColor, 'LEFT')
        colorLabel:SetPoint('BOTTOMRIGHT', self.configFrame, 'BOTTOMRIGHT', -70, 20)

        local initialColor = IS.TEMPCONFIG.suggestionColor
        self.colorPicker = IS.gui.ColorPicker(self.configFrame, initialColor, function(color)
            IS.TEMPCONFIG.suggestionColor = color
            if IS.UpdateSuggestionColor then
                IS:UpdateSuggestionColor(color)
            end
        end)
        self.colorPicker:SetPoint('BOTTOMRIGHT', self.configFrame, 'BOTTOMRIGHT', -20, 12)
    end

    function CORE:RebuildWordList()
        local wordCount = countHashTableWords(IS.TEMPWORDS)
        debugprint('RebuildWordList - IS.TEMPWORDS count: ' .. wordCount)

        local currentScroll = self.wordScrollframe:GetVerticalScroll()

        for i = 1, table.getn(self.wordElements) do
            if self.wordElements[i].label then
                self.wordElements[i].label:Hide()
                self.wordElements[i].label:SetParent(nil)
                self.wordElements[i].label = nil
            end
            if self.wordElements[i].button then
                self.wordElements[i].button:Hide()
                self.wordElements[i].button:SetParent(nil)
                self.wordElements[i].button = nil
            end
        end
        self.wordElements = {}

        local sortedWords = getAllWordsFromHash(IS.TEMPWORDS)
        table.sort(sortedWords, function(a, b)
            return string.lower(a) < string.lower(b)
        end)

        local yOffset = 0
        local elementIndex = 1
        for i = 1, table.getn(sortedWords) do
            local word = sortedWords[i]
            debugprint('RebuildWordList - Index ' .. i .. ': ' .. (word or 'nil'))

            local wordLabel = IS.gui.Font(self.wordScrollframe.content, 12, word, {1, 1, 1}, 'LEFT')
            wordLabel:SetPoint('TOPLEFT', self.wordScrollframe.content, 'TOPLEFT', 5, -yOffset - self.firstWordOffset)

            local deleteBtn = IS.gui.Button(self.wordScrollframe.content, 'X', 20, 16, true, {1, 0, 0}, false)
            deleteBtn:SetPoint('TOPLEFT', self.wordScrollframe.content, 'TOPLEFT', 220, -yOffset - self.firstWordOffset)
            deleteBtn:SetScript('OnClick', function()
                IS:RemoveLearnedWord(word)
            end)

            self.wordElements[elementIndex] = {label = wordLabel, button = deleteBtn}
            elementIndex = elementIndex + 1
            yOffset = yOffset + 16
        end
        self.wordScrollframe.content:SetHeight(yOffset + self.firstWordOffset + 20)

        local maxScroll = math.max(0, self.wordScrollframe.content:GetHeight() - self.wordScrollframe:GetHeight())
        if maxScroll <= 0 then
            self.wordScrollframe.scrollBar:Hide()
        else
            self.wordScrollframe.scrollBar:Show()
            self.wordScrollframe.scrollBar:SetMinMaxValues(0, maxScroll)
            local validScroll = math.min(currentScroll, maxScroll)
            self.wordScrollframe:SetVerticalScroll(validScroll)
            self.wordScrollframe.scrollBar:SetValue(validScroll)
        end
        debugprint('RebuildWordList - Created ' .. (elementIndex - 1) .. ' word elements')
    end

    function CORE:FormatNumber(num)
        if num >= 1000000 then
            return string.format('%.1fm', num / 1000000)
        elseif num >= 1000 then
            return string.format('%.1fk', num / 1000)
        else
            return tostring(num)
        end
    end

    function CORE:UpdateStats()
        self.wordCountValue:SetText(self:FormatNumber(countHashTableWords(IS.TEMPWORDS)))
        assert(IS.stats, 'IS.stats is nil')
        self.completionsValue:SetText(self:FormatNumber(IS.stats.completions))
        self.suggestionsValue:SetText(self:FormatNumber(IS.stats.suggestionsShown))
        self.charactersSavedValue:SetText(self:FormatNumber(IS.stats.charactersSaved))

        local mostUsedWord = 'None'
        local maxCount = 0
        if IS.stats.wordUsage then
            for word, count in pairs(IS.stats.wordUsage) do
                if count > maxCount then
                    maxCount = count
                    mostUsedWord = word .. ' (' .. self:FormatNumber(count) .. ')'
                end
            end
        end
        self.mostUsedWordValue:SetText(mostUsedWord)

        local currentPairs = IS.contextPairCount
        local maxPairs = IS.TEMPCONFIG.contextCleanupThreshold or DEFAULT_CONTEXT_CLEANUP_THRESHOLD
        self.contextPairsValue:SetText(currentPairs .. '/' .. maxPairs)

        debugprint('UpdateStats - Calculating accuracy rate')
        debugprint('UpdateStats - Completions: ' .. IS.stats.completions)
        debugprint('UpdateStats - Suggestions shown: ' .. IS.stats.suggestionsShown)

        local accuracyRate = 0
        if IS.stats.suggestionsShown > 0 then
            local rawRate = math.min(100, (IS.stats.completions / math.max(1, IS.stats.suggestionsShown)) * 100)
            accuracyRate = math.floor(rawRate)
            debugprint('UpdateStats - Raw accuracy: ' .. rawRate .. ', floored: ' .. accuracyRate)
        else
            debugprint('UpdateStats - No suggestions shown yet, accuracy = 0')
        end
        self.efficiencyScoreValue:SetText(accuracyRate .. '%')

        if accuracyRate >= 70 then
            debugprint('UpdateStats - High accuracy (>=70%), setting green color')
            self.efficiencyScoreValue:SetTextColor(0, 1, 0)
        elseif accuracyRate >= 30 then
            debugprint('UpdateStats - Medium accuracy (30-69%), setting orange color')
            self.efficiencyScoreValue:SetTextColor(1, 0.65, 0)
        else
            debugprint('UpdateStats - Low accuracy (<30%), setting red color')
            self.efficiencyScoreValue:SetTextColor(1, 0, 0)
        end

        local patternStrength = 0
        if IS.stats.wordUsage then
            for _, count in pairs(IS.stats.wordUsage) do
                if count > 1 then
                    patternStrength = patternStrength + 1
                end
            end
        end
        self.patternStrengthValue:SetText(self:FormatNumber(patternStrength))
    end

    function CORE:UpdateWordList()
        self:RebuildWordList()
    end

    function CORE:UpdateAll()
        self:UpdateWordList()
        self:UpdateStats()
    end

    function IS:OnStatsChanged()
        if CORE.configFrame and CORE.configFrame:IsVisible() then
            CORE:UpdateStats()
        end
    end

    function IS:OnWordsChanged()
        if CORE.configFrame and CORE.configFrame:IsVisible() then
            CORE:UpdateWordList()
        end
    end

    function CORE:ResetAll()
        _G.IS_WORDS = {}
        _G.IS_CONFIG = {}
        IS.TEMPWORDS = {}
        IS.TEMPCONFIG = {}
        debugprint('ResetAll - Reset all data')
        ReloadUI()
    end

    CORE:ShowConfigFrame()
    SHELL:SLASH('', function() CORE:ToggleConfigFrame() end)
    SHELL:SLASH('reset', function()
        IS.gui.Confirmbox('Reset all data and reload UI?', function()
            CORE:ResetAll()
        end)
    end)
end)