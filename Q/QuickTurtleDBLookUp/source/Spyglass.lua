SpyglassDB = SpyglassDB or { enabled = true, debug = false, dbUrl = "" }
Spyglass_CurrentType = "npc"
Spyglass_CurrentID = nil
Spyglass_CurrentName = nil

local L = {
    ["DB_LOOKUP"] = "Spyglass Lookup",
    ["CANCEL"] = "Cancel",
    ["NPC_NO_ID"] = "NPC: %s",
    ["NPC_WITH_ID"] = "NPC: %s (ID: %s)",
    ["ITEM_NO_ID"] = "Item: %s",
    ["ITEM_WITH_ID"] = "Item: %s (ID: %s)",
    ["QUEST_NO_ID"] = "Quest: %s",
    ["QUEST_WITH_ID"] = "Quest: %s (ID: %s)",
    ["SPELL_NO_ID"] = "Spell/Enchant: %s",
    ["SPELL_WITH_ID"] = "Spell/Enchant: %s (ID: %s)",
    ["CLOSE"] = "Close",
    ["ENABLED"] = "Enabled.",
    ["DISABLED"] = "Disabled.",
    ["NO_TARGET"] = "You don't have a target to look up! (Type /spyglass help for commands)",
    ["DEBUG_ON"] = "Debug mode Enabled. Use /spyglass to see extraction details.",
    ["DEBUG_OFF"] = "Debug mode Disabled.",
    ["HELP_BASE"] = "/spyglass - Attempt lookup on your current target",
    ["HELP_TOGGLE"] = "/spyglass toggle - Enable / Disable",
    ["HELP_DEBUG"] = "/spyglass debug - Toggle debug mode",
    ["HELP_SETUP"] = "/spyglass setup - Open database URL setup",
    ["LOADED"] = "v1.1.0 loaded. /spyglass for options.",
    ["OPENED_LINK"] = "Opened database link for: ",
    ["SETUP_TITLE"] = "Spyglass Setup",
    ["SETUP_SUBTITLE"] = "Enter your custom database URL below:",
    ["SETUP_PRESETS"] = "Database Presets",
    ["SETUP_SAVE"] = "Save",
    ["SETUP_CLOSE"] = "Close",
    ["SETUP_SUGGEST"] = "Suggest: %s",
}

if GetLocale() == "esES" or GetLocale() == "esMX" then
    L["DB_LOOKUP"] = "Buscar con Spyglass"
    L["CANCEL"] = "Cancelar"
    L["NPC_NO_ID"] = "PNJ: %s"
    L["NPC_WITH_ID"] = "PNJ: %s (ID: %s)"
    L["ITEM_NO_ID"] = "Objeto: %s"
    L["ITEM_WITH_ID"] = "Objeto: %s (ID: %s)"
    L["QUEST_NO_ID"] = "Misión: %s"
    L["QUEST_WITH_ID"] = "Misión: %s (ID: %s)"
    L["SPELL_NO_ID"] = "Hechizo/Encantamiento: %s"
    L["SPELL_WITH_ID"] = "Hechizo/Encantamiento: %s (ID: %s)"
    L["CLOSE"] = "Cerrar"
    L["ENABLED"] = "Activado."
    L["DISABLED"] = "Desactivado."
    L["NO_TARGET"] = "¡No tienes un objetivo! (Usa /spyglass help para comandos)"
    L["DEBUG_ON"] = "Modo de depuración Activado. Usa /spyglass para ver detalles."
    L["DEBUG_OFF"] = "Modo de depuración Desactivado."
    L["HELP_BASE"] = "/spyglass - Buscar tu objetivo actual"
    L["HELP_TOGGLE"] = "/spyglass toggle - Activar / Desactivar addon"
    L["HELP_DEBUG"] = "/spyglass debug - Alternar modo de depuración"
    L["HELP_SETUP"] = "/spyglass setup - Abrir configuración de URL"
    L["LOADED"] = "v1.1.0 cargado. Usa /spyglass para opciones."
    L["OPENED_LINK"] = "Enlace de la base de datos abierto para: "
    L["SETUP_TITLE"] = "Configuración de Spyglass"
    L["SETUP_SUBTITLE"] = "Introduce la URL de tu base de datos:"
    L["SETUP_PRESETS"] = "Ajustes Preestablecidos"
    L["SETUP_SAVE"] = "Guardar"
    L["SETUP_CLOSE"] = "Cerrar"
    L["SETUP_SUGGEST"] = "Sugerir: %s"
elseif GetLocale() == "ptBR" or GetLocale() == "ptPT" then
    L["DB_LOOKUP"] = "Buscar no Spyglass"
    L["CANCEL"] = "Cancelar"
    L["NPC_NO_ID"] = "NPC: %s"
    L["NPC_WITH_ID"] = "NPC: %s (ID: %s)"
    L["ITEM_NO_ID"] = "Item: %s"
    L["ITEM_WITH_ID"] = "Item: %s (ID: %s)"
    L["QUEST_NO_ID"] = "Missão: %s"
    L["QUEST_WITH_ID"] = "Missão: %s (ID: %s)"
    L["SPELL_NO_ID"] = "Feitiço/Encantamento: %s"
    L["SPELL_WITH_ID"] = "Feitiço/Encantamento: %s (ID: %s)"
    L["CLOSE"] = "Fechar"
    L["ENABLED"] = "Ativado."
    L["DISABLED"] = "Desactivado."
    L["NO_TARGET"] = "Você não tem um alvo válido! (Use /spyglass help para os comandos)"
    L["DEBUG_ON"] = "Modo de depuração Ativado. Use /spyglass para ver detalhes."
    L["DEBUG_OFF"] = "Modo de depuração Desactivado."
    L["HELP_BASE"] = "/spyglass - Buscar o seu alvo atual"
    L["HELP_TOGGLE"] = "/spyglass toggle - Ativar / Desativar o addon"
    L["HELP_DEBUG"] = "/spyglass debug - Alternar modo de depuração"
    L["HELP_SETUP"] = "/spyglass setup - Abrir a configuração da URL"
    L["LOADED"] = "v1.1.0 carregado. Use /spyglass para opções."
    L["OPENED_LINK"] = "Link do banco de dados aberto para: "
    L["SETUP_TITLE"] = "Configuração do Spyglass"
    L["SETUP_SUBTITLE"] = "Insira a URL do banco de dados abaixo:"
    L["SETUP_PRESETS"] = "Predefinições"
    L["SETUP_SAVE"] = "Salvar"
    L["SETUP_CLOSE"] = "Fechar"
    L["SETUP_SUGGEST"] = "Sugerir: %s"
end

local function PrintMsg(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96Spyglass:|r " .. tostring(msg))
    end
end

local function DebugMsg(msg)
    if SpyglassDB.debug then
        PrintMsg("|cffaaaaaa[DEBUG]|r " .. tostring(msg))
    end
end

local function URLEncode(str)
    if not str then return "" end
    str = string.gsub(str, " ", "+")
    return str
end

local function GetTableLength(t)
    if table and table.getn then
        return table.getn(t)
    else
        return #t
    end
end

-- Setup UI Frame (Created lazily)
local Spyglass_SetupFrame = nil

function Spyglass_ShowSetupFrame()
    if not Spyglass_SetupFrame then
        -- Frame container
        Spyglass_SetupFrame = CreateFrame("Frame", "Spyglass_SetupFrame", UIParent)
        Spyglass_SetupFrame:SetWidth(400)
        Spyglass_SetupFrame:SetHeight(180)
        Spyglass_SetupFrame:SetPoint("CENTER", UIParent, "CENTER")
        Spyglass_SetupFrame:SetMovable(true)
        Spyglass_SetupFrame:EnableMouse(true)
        Spyglass_SetupFrame:RegisterForDrag("LeftButton")
        Spyglass_SetupFrame:SetScript("OnDragStart", function() this:StartMoving() end)
        Spyglass_SetupFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
        
        -- Backdrop for styling
        Spyglass_SetupFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        Spyglass_SetupFrame:SetBackdropColor(0.06, 0.07, 0.09, 0.95)
        Spyglass_SetupFrame:SetBackdropBorderColor(0.0, 0.7, 1.0, 0.8)
        
        -- Title
        local title = Spyglass_SetupFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOP", Spyglass_SetupFrame, "TOP", 0, -15)
        title:SetText("|cffffd200" .. L["SETUP_TITLE"] .. "|r")
        
        -- Subtitle / Instructions
        local subtitle = Spyglass_SetupFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        subtitle:SetPoint("TOPLEFT", Spyglass_SetupFrame, "TOPLEFT", 30, -45)
        subtitle:SetText(L["SETUP_SUBTITLE"])

        -- EditBox for URL input
        local editBox = CreateFrame("EditBox", "Spyglass_SetupEditBox", Spyglass_SetupFrame, "InputBoxTemplate")
        editBox:SetWidth(340)
        editBox:SetHeight(32)
        editBox:SetPoint("TOPLEFT", Spyglass_SetupFrame, "TOPLEFT", 30, -70)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(255)
        
        -- Clickable suggestion button/label
        local suggestBtn = CreateFrame("Button", "Spyglass_SetupSuggestButton", Spyglass_SetupFrame)
        suggestBtn:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -5)
        suggestBtn:SetWidth(340)
        suggestBtn:SetHeight(20)
        
        local suggestText = suggestBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        suggestText:SetAllPoints(suggestBtn)
        suggestText:SetJustifyH("LEFT")
        
        local recUrl = "https://octowow.st/db/"
        suggestText:SetText(string.format(L["SETUP_SUGGEST"], "|cff00ffff" .. recUrl .. "|r"))
        
        suggestBtn:SetScript("OnClick", function()
            editBox:SetText(recUrl)
            editBox:SetFocus()
        end)
        suggestBtn:SetScript("OnEnter", function()
            suggestText:SetText(string.format(L["SETUP_SUGGEST"], "|cffffdd00" .. recUrl .. "|r"))
        end)
        suggestBtn:SetScript("OnLeave", function()
            suggestText:SetText(string.format(L["SETUP_SUGGEST"], "|cff00ffff" .. recUrl .. "|r"))
        end)
        
        -- Save Button
        local saveBtn = CreateFrame("Button", "Spyglass_SaveButton", Spyglass_SetupFrame, "UIPanelButtonTemplate")
        saveBtn:SetWidth(110)
        saveBtn:SetHeight(26)
        saveBtn:SetPoint("BOTTOMLEFT", Spyglass_SetupFrame, "BOTTOMLEFT", 30, 20)
        saveBtn:SetText(L["SETUP_SAVE"])
        saveBtn:SetScript("OnClick", function()
            local url = editBox:GetText() or ""
            -- Trim whitespace
            url = string.gsub(url, "^%s*(.-)%s*$", "%1")
            
            if url ~= "" and string.sub(url, -1) ~= "/" then
                url = url .. "/"
            end
            
            if url == "" then
                PrintMsg("Saved URL is blank. Database lookups will fail until a URL is set.")
            end
            
            SpyglassDB.dbUrl = url
            PrintMsg("Database URL updated to: " .. url)
            Spyglass_SetupFrame:Hide()
        end)
        
        -- Close Button
        local closeBtn = CreateFrame("Button", "Spyglass_CloseButton", Spyglass_SetupFrame, "UIPanelButtonTemplate")
        closeBtn:SetWidth(110)
        closeBtn:SetHeight(26)
        closeBtn:SetPoint("BOTTOMRIGHT", Spyglass_SetupFrame, "BOTTOMRIGHT", -30, 20)
        closeBtn:SetText(L["SETUP_CLOSE"])
        closeBtn:SetScript("OnClick", function()
            Spyglass_SetupFrame:Hide()
        end)
        
        -- Title bar Close Button (X)
        local closeX = CreateFrame("Button", "Spyglass_SetupCloseX", Spyglass_SetupFrame, "UIPanelCloseButton")
        closeX:SetPoint("TOPRIGHT", Spyglass_SetupFrame, "TOPRIGHT", -5, -5)
        closeX:SetWidth(24)
        closeX:SetHeight(24)
        closeX:SetScript("OnClick", function() Spyglass_SetupFrame:Hide() end)
    end
    
    local editBox = getglobal("Spyglass_SetupEditBox")
    local savedUrl = SpyglassDB.dbUrl or ""
    if savedUrl == "" then
        savedUrl = "https://octowow.st/db/"
    end
    editBox:SetText(savedUrl)
    
    Spyglass_SetupFrame:Show()
end

StaticPopupDialogs["SPYGLASS_POPUP"] = {
    text = L["NPC_NO_ID"],
    button1 = L["CLOSE"],
    hasEditBox = 1,
    maxLetters = 999,
    closeButton = true,
    closeButtonIsHide = true,
    OnShow = function()
        local editBox = getglobal(this:GetName().."EditBox")
        if editBox then
            editBox:SetMaxLetters(999)
            local data = this.data
            
            -- Use the configured dbUrl, falling back to suggestion if blank.
            local url = SpyglassDB.dbUrl or ""
            if url == "" then
                url = "https://octowow.st/db/"
            end
            
            local lookupType = data and data.type or "npc"
            local currentID = data and data.id
            local currentName = data and data.name or ""

            DebugMsg("Popup OnShow - Type: " .. tostring(lookupType) .. ", ID: " .. tostring(currentID))
            
            if currentID and currentID ~= "Unknown" then
                if lookupType == "item" then
                    url = url .. "?item=" .. tostring(currentID)
                elseif lookupType == "quest" then
                    url = url .. "?quest=" .. tostring(currentID)
                elseif lookupType == "spell" then
                    url = url .. "?spell=" .. tostring(currentID)
                else
                    url = url .. "?npc=" .. tostring(currentID)
                end
            else
                url = url .. "?search=" .. URLEncode(currentName)
            end

            DebugMsg("Generated URL: " .. url)
            editBox:SetText(url)
            editBox:HighlightText()
            editBox:SetFocus()
        end
    end,
    EditBoxOnEnterPressed = function()
        local editBox = getglobal(this:GetParent():GetName().."EditBox") or this
        editBox:ClearFocus()
        this:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function()
        this:GetParent():Hide()
    end,
    OnAccept = function()
    end,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1,
    whileDead = 1,
}

local function ExtractNPCID(guid)
    if type(guid) ~= "string" then return "Unknown" end
    
    if string.find(guid, "-") then
        local parts = {}
        for part in string.gfind(guid, "([^-]+)") do
            table.insert(parts, part)
        end
        if GetTableLength(parts) >= 6 then
            return tonumber(parts[6]) or "Unknown"
        end
    end

    if string.sub(guid, 1, 2) == "0x" then
        local val_end = tonumber(string.sub(guid, -10, -7), 16)
        local val_front = tonumber(string.sub(guid, 7, 10), 16)
        local val_mid = tonumber(string.sub(guid, 9, 12), 16)
        local val_nine_fourteen = tonumber(string.sub(guid, 9, 14), 16)
        local val_seven_twelve = tonumber(string.sub(guid, 7, 12), 16)
        
        DebugMsg("Extraction candidates:")
        DebugMsg("(-10 to -7) -> " .. tostring(string.sub(guid, -10, -7)) .. " = " .. tostring(val_end))
        DebugMsg("(7 to 10) -> " .. tostring(string.sub(guid, 7, 10)) .. " = " .. tostring(val_front))
        DebugMsg("(9 to 12) -> " .. tostring(string.sub(guid, 9, 12)) .. " = " .. tostring(val_mid))
        DebugMsg("(9 to 14) -> " .. tostring(string.sub(guid, 9, 14)) .. " = " .. tostring(val_nine_fourteen))
        DebugMsg("(7 to 12) -> " .. tostring(string.sub(guid, 7, 12)) .. " = " .. tostring(val_seven_twelve))

        if tonumber(string.sub(guid, -10, -7), 16) ~= 0 then
            return tonumber(string.sub(guid, -10, -7), 16)
        end
        return tonumber(string.sub(guid, 7, 10), 16) or "Unknown"
    end

    return "Unknown"
end

function Spyglass_ShowPopup()
    DebugMsg("ShowPopup called")
    if not SpyglassDB.enabled then 
        DebugMsg("Addon disabled")
        return 
    end
    
    local lookupType = Spyglass_CurrentType or "npc"
    local id, name
    
    if lookupType == "item" then
        id = Spyglass_CurrentID or "Unknown"
        name = Spyglass_CurrentName or "Unknown Item"
    elseif lookupType == "quest" then
        id = Spyglass_CurrentID or "Unknown"
        name = Spyglass_CurrentName or "Unknown Quest"
    elseif lookupType == "spell" then
        id = Spyglass_CurrentID or "Unknown"
        name = Spyglass_CurrentName or "Unknown Spell"
    else
        if not UnitExists("target") then 
            DebugMsg("No target exists")
            return 
        end
        
        if UnitIsPlayer("target") then 
            DebugMsg("Target is player, ignoring")
            return 
        end

        local guid = nil
        if UnitGUID then
            guid = UnitGUID("target")
            DebugMsg("Raw GUID from UnitGUID: '" .. tostring(guid) .. "' (length: " .. tostring(guid and string.len(guid) or 0) .. ")")
        else
            local _, possibleGuid = UnitExists("target")
            if type(possibleGuid) == "string" then 
                guid = possibleGuid 
                DebugMsg("Raw GUID from UnitExists possibleGuid (SuperWoW): '" .. tostring(guid) .. "'")
            else
                DebugMsg("No GUID found.")
            end
        end
        
        id = ExtractNPCID(guid)
        DebugMsg("Final parsed npcID selected: " .. tostring(id))
        name = UnitName("target") or "Unknown"
        Spyglass_CurrentID = id
        Spyglass_CurrentName = name
    end
    
    local popupData = { id = id, type = lookupType, name = name }

    if id ~= "Unknown" then
        if lookupType == "item" then
            StaticPopupDialogs["SPYGLASS_POPUP"].text = L["ITEM_WITH_ID"]
        elseif lookupType == "quest" then
            StaticPopupDialogs["SPYGLASS_POPUP"].text = L["QUEST_WITH_ID"]
        elseif lookupType == "spell" then
            StaticPopupDialogs["SPYGLASS_POPUP"].text = L["SPELL_WITH_ID"]
        else
            StaticPopupDialogs["SPYGLASS_POPUP"].text = L["NPC_WITH_ID"]
        end
        StaticPopup_Show("SPYGLASS_POPUP", name, id, popupData)
    else
        if lookupType == "item" then
            StaticPopupDialogs["SPYGLASS_POPUP"].text = L["ITEM_NO_ID"]
        elseif lookupType == "quest" then
            StaticPopupDialogs["SPYGLASS_POPUP"].text = L["QUEST_NO_ID"]
        elseif lookupType == "spell" then
            StaticPopupDialogs["SPYGLASS_POPUP"].text = L["SPELL_NO_ID"]
        else
            StaticPopupDialogs["SPYGLASS_POPUP"].text = L["NPC_NO_ID"]
        end
        StaticPopup_Show("SPYGLASS_POPUP", name, nil, popupData)
    end
    
    PrintMsg(L["OPENED_LINK"] .. tostring(name))
end

local Spyglass_DropDown = CreateFrame("Frame", "Spyglass_DropDown", UIParent, "UIDropDownMenuTemplate")
UIDropDownMenu_Initialize(Spyglass_DropDown, function()
    local info = {}
    if Spyglass_CurrentType == "item" or Spyglass_CurrentType == "quest" or Spyglass_CurrentType == "spell" then
        info.text = Spyglass_CurrentName or "Unknown"
    else
        info.text = UnitName("target") or "Unknown"
    end
    info.isTitle = 1
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info)

    info = {}
    info.text = "|cff00ff00" .. L["DB_LOOKUP"] .. "|r"
    info.notCheckable = 1
    info.func = Spyglass_ShowPopup
    UIDropDownMenu_AddButton(info)
    
    info = {}
    info.text = L["CANCEL"]
    info.notCheckable = 1
    info.func = function() end
    UIDropDownMenu_AddButton(info)
end, "MENU")

local function AttemptHookUIFrame(fNameOrObj, isExplicitTargetFrame)
    local f = fNameOrObj
    if type(f) == "string" then
        f = getglobal(f)
    end
    
    if f and type(f) == "table" and not f.SpyglassHooked then
        local function TriggerIfValid(frame, btn)
            if not SpyglassDB or not SpyglassDB.enabled then return end
            if btn ~= "RightButton" then return end
            if not UnitExists("target") or UnitIsPlayer("target") then return end

            local isValid = isExplicitTargetFrame
            if not isValid and frame then
                if frame.unit == "target" then
                    isValid = true
                elseif frame.unit == nil then
                    local name = frame.GetName and frame:GetName()
                    name = name and string.lower(name) or ""
                    if string.find(name, "target") then
                        isValid = true
                    end
                end
            end

            if isValid then
                Spyglass_CurrentType = "npc"
                ToggleDropDownMenu(1, nil, Spyglass_DropDown, "cursor", 0, 0)
            end
        end

        if f:HasScript("OnClick") then
            local oldClick = f:GetScript("OnClick")
            f:SetScript("OnClick", function(a1, a2, a3)
                if oldClick then oldClick(a1, a2, a3) end
                local btn = arg1 or a1
                TriggerIfValid(this, btn)
            end)
            f.SpyglassHooked = true
        elseif f:HasScript("OnMouseUp") then
            local oldMouseUp = f:GetScript("OnMouseUp")
            f:SetScript("OnMouseUp", function(a1, a2, a3)
                if oldMouseUp then oldMouseUp(a1, a2, a3) end
                local btn = arg1 or a1
                TriggerIfValid(this, btn)
            end)
            f.SpyglassHooked = true
        end
    end
end

local old_TargetFrame_OnClick = TargetFrame_OnClick
if TargetFrame_OnClick then
    function TargetFrame_OnClick(button)
        if old_TargetFrame_OnClick then
            old_TargetFrame_OnClick(button)
        end
        if SpyglassDB and SpyglassDB.enabled and button == "RightButton" and UnitExists("target") and not UnitIsPlayer("target") then
            Spyglass_CurrentType = "npc"
            ToggleDropDownMenu(1, nil, Spyglass_DropDown, "cursor", 0, 0)
        end
    end
end

local old_SetItemRef = SetItemRef
function SetItemRef(link, text, button)
    if SpyglassDB and SpyglassDB.enabled and button == "RightButton" and IsControlKeyDown() then
        DebugMsg("SetItemRef called for: " .. tostring(link))
        if string.sub(link, 1, 4) == "item" then
            local _, _, itemId = string.find(link, "^item:(%d+)")
            local _, _, itemName = string.find(text, "%[(.+)%]")
            DebugMsg("Extracted Item ID: " .. tostring(itemId) .. ", Name: " .. tostring(itemName))
            Spyglass_CurrentType = "item"
            Spyglass_CurrentID = tonumber(itemId)
            Spyglass_CurrentName = itemName or "Unknown Item"
            ToggleDropDownMenu(1, nil, Spyglass_DropDown, "cursor", 0, 0)
            return
        elseif string.sub(link, 1, 5) == "quest" then
            local _, _, questId = string.find(link, "^quest:(%d+)")
            local _, _, questName = string.find(text, "%[(.+)%]")
            DebugMsg("Extracted Quest ID: " .. tostring(questId) .. ", Name: " .. tostring(questName))
            Spyglass_CurrentType = "quest"
            Spyglass_CurrentID = tonumber(questId)
            Spyglass_CurrentName = questName or "Unknown Quest"
            ToggleDropDownMenu(1, nil, Spyglass_DropDown, "cursor", 0, 0)
            return
        elseif string.sub(link, 1, 5) == "spell" then
            local _, _, spellId = string.find(link, "^spell:(%d+)")
            local _, _, spellName = string.find(text, "%[(.+)%]")
            DebugMsg("Extracted Spell ID: " .. tostring(spellId) .. ", Name: " .. tostring(spellName))
            Spyglass_CurrentType = "spell"
            Spyglass_CurrentID = tonumber(spellId)
            Spyglass_CurrentName = spellName or "Unknown Spell"
            ToggleDropDownMenu(1, nil, Spyglass_DropDown, "cursor", 0, 0)
            return
        elseif string.sub(link, 1, 7) == "enchant" then
            local _, _, enchantId = string.find(link, "^enchant:(%d+)")
            local _, _, enchantName = string.find(text, "%[(.+)%]")
            DebugMsg("Extracted Enchant ID: " .. tostring(enchantId) .. ", Name: " .. tostring(enchantName))
            Spyglass_CurrentType = "spell"
            Spyglass_CurrentID = tonumber(enchantId)
            Spyglass_CurrentName = enchantName or "Unknown Enchant"
            ToggleDropDownMenu(1, nil, Spyglass_DropDown, "cursor", 0, 0)
            return
        end
    end
    if old_SetItemRef then
        old_SetItemRef(link, text, button)
    end
end

local old_ContainerFrameItemButton_OnClick = ContainerFrameItemButton_OnClick
if ContainerFrameItemButton_OnClick then
    function ContainerFrameItemButton_OnClick(button, ignoreShift)
        if SpyglassDB and SpyglassDB.enabled and button == "RightButton" and IsControlKeyDown() then
            local bag = this:GetParent():GetID()
            local slot = this:GetID()
            local link = GetContainerItemLink(bag, slot)
            DebugMsg("ContainerClick - Bag: " .. tostring(bag) .. ", Slot: " .. tostring(slot))
            if link then
                local _, _, itemId = string.find(link, "item:(%d+)")
                local _, _, itemName = string.find(link, "%[(.+)%]")
                DebugMsg("Container Extracted - Item ID: " .. tostring(itemId) .. ", Name: " .. tostring(itemName))
                if itemId and itemName then
                    Spyglass_CurrentType = "item"
                    Spyglass_CurrentID = tonumber(itemId)
                    Spyglass_CurrentName = itemName
                    ToggleDropDownMenu(1, nil, Spyglass_DropDown, "cursor", 0, 0)
                end
            end
            return
        end
        if old_ContainerFrameItemButton_OnClick then
            old_ContainerFrameItemButton_OnClick(button, ignoreShift)
        end
    end
end

SLASH_SPYGLASS1 = "/spyglass"
SLASH_SPYGLASS2 = "/qdb"
SlashCmdList["SPYGLASS"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "toggle" then
        SpyglassDB.enabled = not SpyglassDB.enabled
        if SpyglassDB.enabled then
            PrintMsg(L["ENABLED"])
        else
            PrintMsg(L["DISABLED"])
        end
    elseif msg == "debug" then
        SpyglassDB.debug = not SpyglassDB.debug
        if SpyglassDB.debug then
            PrintMsg(L["DEBUG_ON"])
        else
            PrintMsg(L["DEBUG_OFF"])
        end
    elseif msg == "setup" then
        Spyglass_ShowSetupFrame()
    elseif msg == "help" then
        PrintMsg(L["HELP_BASE"])
        PrintMsg(L["HELP_TOGGLE"])
        PrintMsg(L["HELP_DEBUG"])
        PrintMsg(L["HELP_SETUP"])
    else
        if UnitExists("target") then
            Spyglass_ShowPopup()
        else
            PrintMsg(L["NO_TARGET"])
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if SpyglassDB == nil then
            SpyglassDB = { enabled = true, debug = false, dbUrl = "" }
        end
        if type(SpyglassDB.debug) ~= "boolean" then
            SpyglassDB.debug = false
        end
        if type(SpyglassDB.dbUrl) ~= "string" then
            SpyglassDB.dbUrl = ""
        end
        PrintMsg(L["LOADED"])
        
        -- Automatically show Setup frame on first loading if dbUrl is empty
        if SpyglassDB.dbUrl == "" then
            Spyglass_ShowSetupFrame()
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_TARGET_CHANGED" then
        local frames = {"pfTarget", "LunaTargetFrame", "XPerl_Target", "SUFUnittarget", "DUF_TargetFrame", "DiscordUnitFrame2", "TargetFrame"}
        for _, name in pairs(frames) do
            AttemptHookUIFrame(name, true)
        end
        
        -- Universal UI Hook
        if ClickCastFrames then
            for clickFrame, _ in pairs(ClickCastFrames) do
                if clickFrame and not clickFrame.SpyglassHooked then
                    AttemptHookUIFrame(clickFrame, false)
                end
            end
        end
    end
end)
