-- SimpleLvl Core
-- Simple leveling tracker for exp, kills, quests, and time to level.
-- Gtihub Link


-- Provide acces to the global environment without using getglobal()
-- Must be declared before simplelvlEnvironment because things in there require it
local _G = _G or getfenv(0)
local SL_DATA_VERSION = 1
local SLVersion = "1.0.0"

SimpleLvl = CreateFrame("Frame")

SimpleLvl.util = {}
SimpleLvl.tracker = {}
SimpleLvl.config = {}
SimpleLvl.ui = nil
SimpleLvl.log = nil


function SimpleLvl:Init()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function()
        self:OnEvent()
    end)

    self.eventFrame:RegisterEvent("ADDON_LOADED")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function SimpleLvl:OnEvent()
    if event == "ADDON_LOADED" then
        if arg1 == "SimpleLvl" then
            self.eventFrame:UnregisterEvent("ADDON_LOADED")

            if SLDatastore == nil then
                self:SetupDefaults()
            elseif SLDatastore.DatabaseVersion ~= SL_DATA_VERSION then
                self:Print("Datastore outdated, Settings reset back to default")
                self:SetupDefaults()
            end

            if SLProfile == nil or not SLDatastore.data[SLProfile] then
                SLProfile = "Default"
                --self:Print("Profile not found, using Default profile")
            end

            if not SLDatastore.data[SLProfile].SilenceWelcomeMessage then
                self:Print("v" .. SLVersion .. " by BeardedRasta")
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        SLLoadTracker()
    end
end

function SimpleLvl:SetupDefaults()
    SLProfile = "Default"
    SLDatastore = {
        DatabaseVersion = SL_DATA_VERSION,
        data = {}
    }
    SLDatastore.data[SLProfile] = SimpleLvl_Copy(SLData.Default, {})
    SLDatastore.data[SLProfile].Name = "Default"
end

function SimpleLvl_Copy(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return
    end

    for k, v in pairs(a) do
        if type(v) ~= "table" then
            b[k] = v;
        else
            local x = {}
            SimpleLvl_Copy(v, x);
            b[k] = x;
        end
    end
    return b
end

SLData = {
    Default = {
        Name = "New Profile (Default)",
        SilenceWelcomeMessage = true,
        locked = false,
        Store = {
            trackerPos = {
                point = "CENTER",
                parentName = "UIParent",
                relativePoint = "CENTER",
                xOfs = -300,
                yOfs = 0,
            },
            ttswap = false,
            trackerScale = 1,

        }
    }
}

SLTextures = {
    Background = "Interface\\AddOns\\SimpleLvl\\Media\\background.blp",
    Frame = "Interface\\AddOns\\SimpleLvl\\Media\\Frame.blp",
    Button = "Interface\\AddOns\\SimpleLvl\\Media\\SimpleUI-Default.blp",
    Attack = "Interface\\AddOns\\SimpleLvl\\Media\\Combat.blp",
    Quest = "Interface\\AddOns\\SimpleLvl\\Media\\quest.tga",
    Time = "Interface\\AddOns\\SimpleLvl\\Media\\timer_icon.tga"
}

function SimpleLvl:GetTexture(string)
    if SLTextures[string] then
        return SLTextures[string]
    end
    return ""
end

function SimpleLvl:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("Simple |cff1a9fc0Lvl|cFFFFFFFF: " .. msg)
end

SimpleLvl:Init()
