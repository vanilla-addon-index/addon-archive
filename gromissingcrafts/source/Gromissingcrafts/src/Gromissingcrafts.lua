setfenv(1, Gromissingcrafts)

---@shape AddonInfo
---@field name string
---@field version string

---@type AddonInfo
local addonInfo = {
    name = ADDON_NAME,
    version = ADDON_VERSION
}

---@type LibStubDef
local LibStub = getglobal("LibStub")
assert(LibStub ~= nil, "LibStub is required to run this addon")

local LibCraftingProfessions = --[[---@type LibCraftingProfessions]] LibStub("LibCraftingProfessions-1.0")
local LibCrafts = --[[---@type LibCrafts]] LibStub("LibCrafts-1.0")
local LibItemTooltip = --[[---@type LibItemTooltip]] LibStub("LibItemTooltip-1.0")

---@shape Repositories
---@field characterRepository CharacterRepository
---@field craftRepository CraftRepository

---@class Gromissingcrafts
---@field database Database
---@field uiManager UIManager

---@type Gromissingcrafts
local addon = --[[---@type Gromissingcrafts]] {}

function addon:OnEnable()
    self.database = Database:Create()

    local characterRepository = CharacterRepository:Create(self.database)
    ---@type Repositories
    local repositories = {
        characterRepository = characterRepository,
        craftRepository = CraftRepository:Create(self.database, characterRepository, LibCrafts)
    }

    -- L is the shared locale table populated by src/locale/*.lua, loaded earlier in the .toc
    self.uiManager = UIManager:Create(addonInfo, repositories, --[[---@type GromissingcraftsLocale]] L, LibItemTooltip)

    LibCraftingProfessions:RegisterEvent("LCP_SKILLS_UPDATE", function(profession, skills)
        local skillNames = {}
        for _, skill in ipairs(skills) do
            tinsert(skillNames, skill.localized_name)
        end
        self.database:SaveCurrentPlayerSkills(profession.localized_name, profession.cur_rank, skillNames)

        local playerProfessions = LibCraftingProfessions:GetPlayerProfessions()
        if playerProfessions ~= nil then
            local playerProfessionNames = {}
            for _, playerProfession in ipairs(playerProfessions or {}) do
                tinsert(playerProfessionNames, playerProfession.localized_name)
            end
            self.database:SaveCurrentPlayerProfessions(playerProfessionNames)
        end

        self.uiManager:OnDataUpdated(profession.localized_name)
    end)

    LibCraftingProfessions:RegisterEvent("LCP_FRAME_SHOW", function(profession, frame, frameType)
        self.uiManager:OnProfessionFrameOpened(profession.localized_name, frame, frameType)
    end)

    LibCraftingProfessions:RegisterEvent("LCP_FRAME_CLOSE", function(frame, frameType)
        self.uiManager:OnProfessionFrameClosed(frame, frameType)
    end)

    DevTools:Create()
end

Addon = addon

local bootstrapFrame = CreateFrame("Frame")
bootstrapFrame:RegisterEvent("ADDON_LOADED")
bootstrapFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        bootstrapFrame:UnregisterEvent("ADDON_LOADED")
        addon:OnEnable()
    end
end)
