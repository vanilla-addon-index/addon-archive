--[[
    ConsoleExperienceClassic - Locale Module
    
    Handles translations and locale-specific data
]]

if ConsoleExperience.locale == nil then
    ConsoleExperience.locale = {}
end

local Locale = ConsoleExperience.locale

-- Initialize translation tables
if not ConsoleExperience_translation then
    ConsoleExperience_translation = {}
end

-- Current locale (will be set on initialization)
Locale.current = GetLocale() or "enUS"

-- Translation function - returns translated string or key if not found
function Locale:Translate(key)
    local lang = self.current
    local translation = ConsoleExperience_translation[lang]
    
    if translation and translation[key] then
        return translation[key]
    end
    
    -- Fallback to English
    if lang ~= "enUS" then
        local enTranslation = ConsoleExperience_translation["enUS"]
        if enTranslation and enTranslation[key] then
            return enTranslation[key]
        end
    end
    
    -- Return key as fallback
    return key
end

-- Short alias for translation function
-- Defined as regular function (not method) so it can be assigned and called directly
Locale.T = function(key)
    return Locale:Translate(key)
end

-- Initialize locale system
function Locale:Initialize()
    -- Get language from config or use game locale
    local config = ConsoleExperience.config
    if config then
        local configLang = config:Get("language")
        if configLang and ConsoleExperience_translation[configLang] then
            self.current = configLang
        else
            self.current = GetLocale() or "enUS"
        end
    else
        self.current = GetLocale() or "enUS"
    end
    
    CE_Debug("Locale initialized: " .. self.current)
end

-- Set language
function Locale:SetLanguage(lang)
    if not lang then
        CE_Debug("Language not available: (nil)")
        return false
    end
    
    if ConsoleExperience_translation[lang] then
        self.current = lang
        local config = ConsoleExperience.config
        if config then
            config:Set("language", lang)
        end
        CE_Debug("Language set to: " .. tostring(lang))
        return true
    else
        CE_Debug("Language not available: " .. tostring(lang))
        return false
    end
end

-- Get available languages
function Locale:GetAvailableLanguages()
    local languages = {}
    for lang, _ in pairs(ConsoleExperience_translation) do
        table.insert(languages, lang)
    end
    table.sort(languages)
    return languages
end

-- Get language display name
function Locale:GetLanguageName(lang)
    local names = {
        ["enUS"] = "English",
        ["deDE"] = "Deutsch",
        ["esES"] = "Español",
        ["frFR"] = "Français",
        ["koKR"] = "한국어",
        ["ruRU"] = "Русский",
        ["zhCN"] = "简体中文",
        ["zhTW"] = "繁體中文",
    }
    return names[lang] or lang
end

