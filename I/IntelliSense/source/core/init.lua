SHELL:LOCKED()

-- mainframe
IS = CreateFrame'Frame'
IS:RegisterEvent'PLAYER_ENTERING_WORLD'
IS:RegisterEvent'PLAYER_LOGOUT'
IS:SetScript('OnEvent', function()
    if event == 'PLAYER_ENTERING_WORLD' then
        IS:LoadDBs()
        IS:RunModules()
        IS:UnregisterEvent'PLAYER_ENTERING_WORLD'
        print('IntelliSense loaded - V: ' .. info.TOCversion .. ' - open via /int')
    elseif event == 'PLAYER_LOGOUT' then
        IS:SaveDBs()
    end
end)

-- tables
_G.IS_WORDS = {}
_G.IS_CONFIG = {}
_G.IS_CONTEXT = {}
_G.IS_TRIGRAMS = {}

IS.TEMPWORDS = {}
IS.TEMPCONFIG = {}
IS.TEMPCONTEXT = {}
IS.TEMPTRIGRAMS = {}

IS.modules = {}
IS.words = {}
IS.stats = {}
IS.gui = {}

-- modules
function IS:NewModule(module, func)
    self.modules[module] = func
    debugprint('NewModule: ' .. module)
end

function IS:RunModules()
    for name, func in pairs(self.modules) do
        debugprint('RunModules - Exec: ' .. name)
        func()
    end
end

-- database
function IS:LoadDBs()
    local currentVersion = info.DBversion
    local savedVersion = _G.IS_CONFIG.dbVersion

    if savedVersion ~= currentVersion or not currentVersion then
        debugprint('LoadDBs - Version mismatch: ' .. tostring(savedVersion) .. ' -> ' .. currentVersion .. ' - Wiping data')
        _G.IS_WORDS = {}
        _G.IS_CONFIG = {dbVersion = currentVersion}
        _G.IS_CONTEXT = {}
        _G.IS_TRIGRAMS = {}
        IS.TEMPWORDS = {}
        IS.TEMPCONFIG = {dbVersion = currentVersion}
        IS.TEMPCONTEXT = {}
        IS.TEMPTRIGRAMS = {}
    else
        debugprint('LoadDBs - Version match: ' .. currentVersion)
        IS.TEMPWORDS = copy(_G.IS_WORDS)
        IS.TEMPCONFIG = copy(_G.IS_CONFIG)
        IS.TEMPCONTEXT = copy(_G.IS_CONTEXT)
        IS.TEMPTRIGRAMS = copy(_G.IS_TRIGRAMS)
    end
    debugprint('LoadDBs - copied WORDS: ' .. table.getn(IS.TEMPWORDS))
    debugprint('LoadDBs - copied SETUP: ' .. table.getn(IS.TEMPCONFIG))
    debugprint('LoadDBs - copied CONTEXT: ' .. table.getn(IS.TEMPCONTEXT))
    debugprint('LoadDBs - copied TRIGRAMS: ' .. table.getn(IS.TEMPTRIGRAMS))
end

function IS:SaveDBs()
    _G.IS_WORDS = IS.TEMPWORDS
    _G.IS_CONFIG = IS.TEMPCONFIG
    _G.IS_CONTEXT = IS.TEMPCONTEXT
    _G.IS_TRIGRAMS = IS.TEMPTRIGRAMS
    debugprint('SaveDBs - saved WORDS: ' .. table.getn(_G.IS_WORDS))
    debugprint('SaveDBs - saved SETUP: ' .. table.getn(_G.IS_CONFIG))
    local contextCount = 0
    if _G.IS_CONTEXT then
        for word1, pairs in _G.IS_CONTEXT do
            for word2, usage in pairs do
                contextCount = contextCount + 1
            end
        end
    end
    local trigramCount = 0
    if _G.IS_TRIGRAMS then
        for word1, word2Pairs in _G.IS_TRIGRAMS do
            for word2, word3Pairs in word2Pairs do
                for word3, usage in word3Pairs do
                    trigramCount = trigramCount + 1
                end
            end
        end
    end
    debugprint('SaveDBs - saved CONTEXT pairs: ' .. contextCount)
    debugprint('SaveDBs - saved TRIGRAM patterns: ' .. trigramCount)
end
