setfenv(1, Gromissingcrafts)

---@shape GromissingcraftsLocale
---@field recipe_tooltip_already_known string
---@field recipe_tooltip_can_learn_now string
---@field recipe_tooltip_can_learn_later string
---@field craft_tooltip_source string
---@field craft_source_chest string
---@field craft_source_craft string
---@field craft_source_drop string
---@field craft_source_fishing string
---@field craft_source_gift string
---@field craft_source_pickpocketing string
---@field craft_source_quest string
---@field craft_source_trainer string
---@field craft_source_unknown string
---@field craft_source_vendor string
---@field craft_source_world_object string

--[[
Minimal AceLocale-free replacement. enUS.lua must load first (see the .toc) and
always populates every key, acting as the fallback. Every other locale file only
receives the shared table (and thus only gets to override keys) when the running
client's GetLocale() matches its own code; otherwise NewLocale returns nil and the
file's `if L == nil then return end` guard skips it entirely.
]]

---@type GromissingcraftsLocale
L = L or --[[---@type GromissingcraftsLocale]] {}

---@alias LocaleCode "deDE" | "enUS" | "esES" | "frFR" | "koKR" | "ptBR" | "ruRU" | "zhCN" | "zhTW"

---@param code LocaleCode
---@param is_default boolean
---@return GromissingcraftsLocale|nil
function NewLocale(code, is_default)
    if is_default then
        return L
    end
    if GetLocale() == code then
        return L
    end
    return nil
end
