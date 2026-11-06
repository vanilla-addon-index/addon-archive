-- Base URL structure
local ARMORY_DOMAIN = "https://octo.chronicleclassic.com/armory/"

-- Helper function to dynamically get the current server/realm name
local function GetArmoryBaseUrl()
    local currentRealm = GetRealmName()
    
    if currentRealm and currentRealm ~= "" then
        -- Convert to lower case and remove non-alphanumeric characters for flexible matching
        local cleanRealm = string.lower(currentRealm)
        cleanRealm = string.gsub(cleanRealm, "[^a-z0-9]", "") -- Remove apostrophes, spaces, hyphens
        
        if string.find(cleanRealm, "cthun") then
            return ARMORY_DOMAIN .. "C'Thun/"
        elseif string.find(cleanRealm, "yshaarj") then
            return ARMORY_DOMAIN .. "Y'Shaarj/"
        elseif string.find(cleanRealm, "nzoth") then
            return ARMORY_DOMAIN .. "N'Zoth/"
        else
            -- Fallback if connected to a realm not explicitly in the list
            return ARMORY_DOMAIN .. currentRealm .. "/"
        end
    end

    -- Default fallback if GetRealmName() returned nil or empty string
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[OctoArmory]|r Varning: Kunde inte känna av servernamn (GetRealmName returnerade nil). Använder N'Zoth som standard.")
    return ARMORY_DOMAIN .. "N'Zoth/"
end

-- Variables to track context
local lastChatClickedPlayer = nil
local lastDropdownClickedPlayer = nil

-- 1. Define the popup dialog for copying the link
StaticPopupDialogs["OCTO_ARMORY_COPY_LINK"] = {
    text = "Armory Link (Press Ctrl+C to copy):",
    button1 = "Close",
    hasEditBox = 1,
    maxLetters = 255,
    
    OnShow = function()
        local editBox = getglobal(this:GetName().."EditBox")
        if editBox and this.data then
            editBox:SetText(this.data)
            editBox:SetWidth(280)
            editBox:HighlightText() -- Highlight all text automatically
            editBox:SetFocus()      -- Focus the box so the user can immediately press Ctrl+C
        end
    end,
    
    EditBoxOnEnterPressed = function()
        this:GetParent():Hide()
    end,
    
    EditBoxOnEscapePressed = function()
        this:GetParent():Hide()
    end,
    
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

-- Helper function to open the link window with the player's name
local function OpenArmoryLink(name)
    if not name or name == "" then return end
    
    -- Ensure correct casing for the character name (First letter capitalized, rest lowercase)
    name = string.upper(string.sub(name, 1, 1)) .. string.lower(string.sub(name, 2))
    
    -- Dynamically generate the full URL based on current server
    local fullUrl = GetArmoryBaseUrl() .. name
    
    -- Display the popup dialog with the formatted URL
    local dialog = StaticPopup_Show("OCTO_ARMORY_COPY_LINK")
    if dialog then
        dialog.data = fullUrl
        local editBox = getglobal(dialog:GetName().."EditBox")
        if editBox then
            editBox:SetText(fullUrl)
            editBox:HighlightText()
            editBox:SetFocus()
        end
    end
end

-- Hook SetItemRef to catch right-clicks on player names in chat
local original_SetItemRef = SetItemRef
SetItemRef = function(link, text, button)
    if link and string.sub(link, 1, 6) == "player" then
        local name = string.sub(link, 8)
        local colonIndex = string.find(name, ":")
        if colonIndex then
            name = string.sub(name, 1, colonIndex - 1)
        end
        
        if name and name ~= "" then
            lastChatClickedPlayer = name
            lastDropdownClickedPlayer = nil
        end
    end

    if original_SetItemRef then
        original_SetItemRef(link, text, button)
    end
end

-- Hook UnitPopup_ShowMenu to capture the exact target/player name when a menu opens
local original_UnitPopup_ShowMenu = UnitPopup_ShowMenu
UnitPopup_ShowMenu = function(dropdownFrame, which, unit, name, userData)
    if unit and UnitExists(unit) and UnitIsPlayer(unit) then
        lastDropdownClickedPlayer = UnitName(unit)
        lastChatClickedPlayer = nil
    elseif name and name ~= "" then
        lastDropdownClickedPlayer = name
        lastChatClickedPlayer = nil
    end

    if original_UnitPopup_ShowMenu then
        original_UnitPopup_ShowMenu(dropdownFrame, which, unit, name, userData)
    end
end

-- Robust name detection function for 1.12.1
local function GetSelectedPlayerName()
    local name = nil
    
    -- 1. Priority: If clicked via chat link
    if lastChatClickedPlayer and lastChatClickedPlayer ~= "" then
        name = lastChatClickedPlayer
        lastChatClickedPlayer = nil
        return name
    end

    -- 2. Priority: Captured from UnitPopup_ShowMenu (Target, Party, Raid, etc.)
    if lastDropdownClickedPlayer and lastDropdownClickedPlayer ~= "" then
        name = lastDropdownClickedPlayer
        lastDropdownClickedPlayer = nil
        return name
    end

    -- 3. Check dropdown unit or name references
    local dropdown = UIDROPDOWNMENU_INIT_MENU
    if dropdown then
        if dropdown.unit and UnitExists(dropdown.unit) then
            name = UnitName(dropdown.unit)
        elseif dropdown.name and dropdown.name ~= "" then
            name = dropdown.name
        elseif dropdown.chatTarget and dropdown.chatTarget ~= "" then
            name = dropdown.chatTarget
        end
    end

    -- 4. Fallback to Target ONLY if no menu or chat context was found
    if (not name or name == "") and UnitExists("target") and UnitIsPlayer("target") then
        name = UnitName("target")
    end

    -- Strip out realm/server name if present (e.g., "Welf-TurtleWoW" -> "Welf")
    if name then
        local dashIndex = string.find(name, "-")
        if dashIndex then
            name = string.sub(name, 1, dashIndex - 1)
        end
    end

    return name
end

-- Function to safely inject our button into UnitPopupMenus
local function InitializeOctoArmoryLink()
    -- Register the button in UnitPopupButtons
    UnitPopupButtons["OCTO_ARMORY_LINK"] = { 
        text = "Copy armory link", 
        dist = 0 
    }

    -- Target popup categories including Chat and Guild menus
    local popupTypes = {
        "PLAYER",
        "TARGET",
        "PARTY",
        "RAID",
        "FRIEND",
        "GUILD",
        "GUILD_OFFLINE",
        "MEMBER",
        "CHAT_ROSTER"
    }

    for _, menuType in ipairs(popupTypes) do
        if UnitPopupMenus[menuType] then
            local count = table.getn(UnitPopupMenus[menuType])
            local inserted = false
            
            for i = 1, count do
                if UnitPopupMenus[menuType][i] == "CANCEL" then
                    table.insert(UnitPopupMenus[menuType], i, "OCTO_ARMORY_LINK")
                    inserted = true
                    break
                end
            end
            
            if not inserted then
                table.insert(UnitPopupMenus[menuType], "OCTO_ARMORY_LINK")
            end
        end
    end
end

-- Safe hook handler for UnitPopup_OnClick
local original_UnitPopup_OnClick = UnitPopup_OnClick
UnitPopup_OnClick = function()
    local isArmoryLinkClick = false
    
    if this.value == "OCTO_ARMORY_LINK" then
        isArmoryLinkClick = true
    elseif UIDROPDOWNMENU_BUTTON_INFO and UIDROPDOWNMENU_BUTTON_INFO.value == "OCTO_ARMORY_LINK" then
        isArmoryLinkClick = true
    end

    -- Text verification fallback to prevent sub-menu overrides
    if not isArmoryLinkClick and this:GetName() then
        local buttonTextFrame = getglobal(this:GetName().."Text")
        if buttonTextFrame and buttonTextFrame:GetText() == "Copy armory link" then
            isArmoryLinkClick = true
        end
    end

    if isArmoryLinkClick then
        local name = GetSelectedPlayerName()
        if name and name ~= "" then
            OpenArmoryLink(name)
        end
        return
    end
    
    if original_UnitPopup_OnClick then
        original_UnitPopup_OnClick()
    end
end

-- Frame to defer execution until game UI is fully loaded
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:SetScript("OnEvent", function()
    InitializeOctoArmoryLink()
end)
