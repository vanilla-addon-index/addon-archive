-- ExplorerMap Addon for Vanilla WoW 1.12
local ExplorerMap = {}
ExplorerMap.db = {}
ExplorerMap.mapIcons = {}
local lastSavedNPC = {}
local questLogSnapshot = {}

---------------------------------------------------
-- Helpers
---------------------------------------------------
local function TableLength(t)
    if not t then return 0 end
    local count = 0
    for _,_ in pairs(t) do count = count + 1 end
    return count
end

local function IsQuestInList(list, questName)
    if not list then return false end
    for i=1,TableLength(list) do
        if list[i]==questName then return true end
    end
    return false
end

local function RemoveQuestFromList(list, questName)
    if not list then return end
    for i=TableLength(list),1,-1 do
        if list[i]==questName then table.remove(list,i) end
    end
end

---------------------------------------------------
-- NPC Discovery
---------------------------------------------------
local function CreateNPCIfNeeded(npcName, x, y, zone, subzone)
    if not ExplorerMap.db[zone] then ExplorerMap.db[zone] = {} end
    
    if not subzone or subzone == "" then
        subzone = "Unknown Area"
    end
    
    local roundedX = math.floor(x*100)
    local roundedY = math.floor(y*100)
    local npcKey = npcName.."_"..roundedX.."_"..roundedY
    
    if not ExplorerMap.db[zone][npcKey] then
        for existingKey, existingNPC in pairs(ExplorerMap.db[zone]) do
            if existingNPC.name == npcName then
                local existingRoundedX = math.floor(existingNPC.x*100)
                local existingRoundedY = math.floor(existingNPC.y*100)
                local distance = math.abs(roundedX - existingRoundedX) + math.abs(roundedY - existingRoundedY)
                if distance <= 2 then
                    return existingNPC
                end
            end
        end
        
        local continent = GetCurrentMapContinent()
        local zoneID = GetCurrentMapZone()
        ExplorerMap.db[zone][npcKey] = {
            name = npcName,
            x = x,
            y = y,
            subzone = subzone,
            continent = continent,
            zoneID = zoneID,
            questInfo = { availableQuests = {}, activeQuests = {}, completedQuests = {}, questLevels = {} },
            discovered = time()
        }
    end
    return ExplorerMap.db[zone][npcKey]
end

---------------------------------------------------
-- Quest Handling
---------------------------------------------------
local function AddAvailableQuest(npc, questName, questLevel)
    if not IsQuestInList(npc.questInfo.availableQuests, questName) and
       not IsQuestInList(npc.questInfo.activeQuests, questName) and
       not IsQuestInList(npc.questInfo.completedQuests or {}, questName) then
        table.insert(npc.questInfo.availableQuests, questName)
        if not npc.questInfo.questLevels then npc.questInfo.questLevels = {} end
        if questLevel then
            npc.questInfo.questLevels[questName] = questLevel
        end
    end
end

local function CompleteQuest(npc, questName)
    RemoveQuestFromList(npc.questInfo.activeQuests, questName)
    RemoveQuestFromList(npc.questInfo.availableQuests, questName)
    
    if not npc.questInfo.completedQuests then
        npc.questInfo.completedQuests = {}
    end
    if not IsQuestInList(npc.questInfo.completedQuests, questName) then
        table.insert(npc.questInfo.completedQuests, questName)
    end
end

local function AcceptQuest(npc, questName)
    if IsQuestInList(npc.questInfo.availableQuests, questName) then
        RemoveQuestFromList(npc.questInfo.availableQuests, questName)
        if not IsQuestInList(npc.questInfo.activeQuests, questName) then
            table.insert(npc.questInfo.activeQuests, questName)
        end
    end
end

local function AbandonQuest(npc, questName)
    if IsQuestInList(npc.questInfo.activeQuests, questName) then
        RemoveQuestFromList(npc.questInfo.activeQuests, questName)
        if not IsQuestInList(npc.questInfo.completedQuests or {}, questName) then
            AddAvailableQuest(npc, questName)
        end
    end
end

---------------------------------------------------
-- Map Icons
---------------------------------------------------
local function GetNPCIconType(npc)
    local hasAvailable = TableLength(npc.questInfo.availableQuests) > 0
    local hasActive = TableLength(npc.questInfo.activeQuests) > 0
    
    if hasAvailable then
        return "available"
    elseif hasActive then
        return "active"  
    else
        return "hidden"
    end
end

local function FindAvailableIconPosition(originalX, originalY, worldMapWidth, worldMapHeight)
    local iconSize = 20
    local minDistance = 10
    local maxAttempts = 8
    local angleStep = 360 / maxAttempts
    
    for attempt = 0, maxAttempts do
        local testX, testY
        if attempt == 0 then
            testX, testY = originalX * worldMapWidth, originalY * worldMapHeight
        else
            local angle = math.rad((attempt - 1) * angleStep)
            local offsetDistance = minDistance
            testX = originalX * worldMapWidth + math.cos(angle) * offsetDistance
            testY = originalY * worldMapHeight + math.sin(angle) * offsetDistance
        end
        
        local positionFree = true
        for _, existingIcon in ipairs(ExplorerMap.mapIcons) do
            if existingIcon and existingIcon:IsVisible() then
                local existingX = existingIcon.worldX or 0
                local existingY = existingIcon.worldY or 0
                local distance = math.sqrt((testX - existingX)^2 + (testY - existingY)^2)
                if distance < minDistance then
                    positionFree = false
                    break
                end
            end
        end
        
        if positionFree then
            return testX, testY
        end
    end
    
    return originalX * worldMapWidth, originalY * worldMapHeight
end

local function CreateMapIcon(npc)
    local iconType = GetNPCIconType(npc)
    if iconType=="hidden" then return nil end

    local iconName = "ExplorerMap_Icon_"..math.random(1000,9999)
    local icon = CreateFrame("Button", iconName, WorldMapButton)
    icon:SetWidth(18)
    icon:SetHeight(22)
    icon:SetFrameStrata("TOOLTIP")
    icon:SetFrameLevel(100)

    local worldMapWidth = WorldMapButton:GetWidth()
    local worldMapHeight = WorldMapButton:GetHeight()
    
    local finalX, finalY = FindAvailableIconPosition(npc.x, npc.y, worldMapWidth, worldMapHeight)
    icon:SetPoint("CENTER", WorldMapButton, "TOPLEFT", finalX, -finalY)
    
    icon.worldX = finalX
    icon.worldY = finalY

    local texture = icon:CreateTexture(nil,"OVERLAY")
    texture:SetAllPoints(icon)
    texture:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    
    if iconType == "available" then
        texture:SetVertexColor(1, 1, 0, 1.0)
    else
        texture:SetVertexColor(0.7, 1, 0.7)
    end

    icon.npcData = npc

    icon:SetScript("OnEnter", function()
        local available = this.npcData.questInfo.availableQuests
        local active = this.npcData.questInfo.activeQuests
        
        GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(this.npcData.name, 0, 1, 0)
        if this.npcData.subzone and this.npcData.subzone~="" then
            GameTooltip:AddLine(this.npcData.subzone, 0.8, 0.8, 0.8)
        end
        
        if TableLength(available)>0 then
            GameTooltip:AddLine("Available Quests:", 1, 1, 0)
            for i=1,TableLength(available) do
                GameTooltip:AddLine("  "..available[i], 1, 1, 0)
            end
        end
        if TableLength(active)>0 then
            GameTooltip:AddLine("Active Quests:", 0.5, 1, 0.5)
            for i=1,TableLength(active) do
                GameTooltip:AddLine("  "..active[i], 0.7, 1, 0.7)
            end
        end
        GameTooltip:Show()
        GameTooltip:SetFrameStrata("TOOLTIP")
        GameTooltip:SetFrameLevel(101)
    end)

    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icon:Show()
    return icon
end

local function RefreshIconColors()
    for _, icon in ipairs(ExplorerMap.mapIcons) do
        if icon and icon.npcData then
            local iconType = GetNPCIconType(icon.npcData)
            local texture = icon:GetRegions()
            if texture then
                if iconType == "available" then
                    texture:SetVertexColor(1, 1, 0, 1.0)
                elseif iconType == "active" then
                    texture:SetVertexColor(0.7, 1, 0.7)
                end
            end
        end
    end
end

local function UpdateMapIcons()
    local currentContinent = GetCurrentMapContinent()
    local currentZoneID = GetCurrentMapZone()
    
    if not currentZoneID or currentZoneID == 0 then
        for _, icon in ipairs(ExplorerMap.mapIcons) do
            icon:Hide()
        end
        ExplorerMap.mapIcons = {}
        return
    end
    
    for _, icon in ipairs(ExplorerMap.mapIcons) do
        icon:Hide()
    end
    ExplorerMap.mapIcons = {}

    for zoneName, npcs in pairs(ExplorerMap.db) do
        for _, npc in pairs(npcs) do
            if npc.continent == currentContinent and npc.zoneID == currentZoneID then
                local icon = CreateMapIcon(npc)
                if icon then table.insert(ExplorerMap.mapIcons, icon) end
            end
        end
    end
end

local function CheckWorldMap()
    if WorldMapFrame:IsVisible() then
        UpdateMapIcons()
    end
end

---------------------------------------------------
-- GUI Creation
---------------------------------------------------
local ExplorerMapGUI = {}
ExplorerMapGUI.frame = nil
ExplorerMapGUI.isVisible = false
ExplorerMapGUI.collapsedZones = {}
ExplorerMapGUI.collapsedNPCs = {}
ExplorerMapGUI.collapsedSubzones = {}
ExplorerMapGUI.collapsedQuestSections = {}
ExplorerMapGUI.uiElements = {}

local function SaveGUIState()
    local key = UnitName("player").."-"..GetRealmName()
    if ExplorerMapDB and ExplorerMapDB[key] then
        if not ExplorerMapDB[key].guiState then
            ExplorerMapDB[key].guiState = {}
        end
        ExplorerMapDB[key].guiState.collapsedZones = ExplorerMapGUI.collapsedZones
        ExplorerMapDB[key].guiState.collapsedSubzones = ExplorerMapGUI.collapsedSubzones
        ExplorerMapDB[key].guiState.collapsedNPCs = ExplorerMapGUI.collapsedNPCs
        ExplorerMapDB[key].guiState.collapsedQuestSections = ExplorerMapGUI.collapsedQuestSections
    end
end

local function ClearGUIContent()
    for _, element in ipairs(ExplorerMapGUI.uiElements) do
        if element.Hide then
            element:Hide()
        end
    end
    ExplorerMapGUI.uiElements = {}
end

local function AddUIElement(element)
    table.insert(ExplorerMapGUI.uiElements, element)
    return element
end

local function CreateClickableText(parent, text, x, y, color, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(350)
    button:SetHeight(16)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    
    local fontString = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontString:SetPoint("LEFT", button, "LEFT", 0, 0)
    fontString:SetText(text)
    fontString:SetTextColor(color.r, color.g, color.b)
    
    if onClick then
        button:SetScript("OnClick", onClick)
    end
    
    button:SetScript("OnEnter", function()
        fontString:SetTextColor(1, 1, 1)
    end)
    button:SetScript("OnLeave", function()
        fontString:SetTextColor(color.r, color.g, color.b)
    end)
    
    AddUIElement(button)
    return button
end

local function CreateStaticText(parent, text, x, y, color)
    local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fontString:SetText(text)
    fontString:SetTextColor(color.r, color.g, color.b)
    AddUIElement(fontString)
    return fontString
end

local function UpdateGUIContent()
    if not ExplorerMapGUI.content then return end
    
    ClearGUIContent()
    
    local yPos = -10
    local lineHeight = 18
	local colors = {
		zone = {r=1, g=0.4, b=0.2},
		subzone = {r=1, g=0.7, b=0.5},
		npc = {r=0, g=1, b=0},
		availableHeader = {r=1, g=0.8, b=0},
		activeHeader = {r=0.5, g=0.8, b=0.5},
		available = {r=0.6, g=0.6, b=0.6},
		active = {r=0.8, g=1, b=0.8}
    }
    
    local sortedZones = {}
    for zoneName, npcs in pairs(ExplorerMap.db) do
        if zoneName and zoneName ~= "" then
            local zoneHasQuests = false
            for _, npc in pairs(npcs) do
                if npc.questInfo and (TableLength(npc.questInfo.availableQuests) > 0 or TableLength(npc.questInfo.activeQuests) > 0) then
                    zoneHasQuests = true
                    break
                end
            end
            if zoneHasQuests then
                table.insert(sortedZones, zoneName)
            end
        end
    end
    table.sort(sortedZones)
    
    for _, zoneName in ipairs(sortedZones) do
        local npcs = ExplorerMap.db[zoneName]
        local subzoneGroups = {}
        
        for _, npc in pairs(npcs) do
            if npc.questInfo and (TableLength(npc.questInfo.availableQuests) > 0 or TableLength(npc.questInfo.activeQuests) > 0) then
                local subzoneName = npc.subzone
                if not subzoneName or subzoneName == "" then
                    subzoneName = "Unknown Area"
                end
                if not subzoneGroups[subzoneName] then
                    subzoneGroups[subzoneName] = {}
                end
                table.insert(subzoneGroups[subzoneName], npc)
            end
        end
        
        local isZoneCollapsed = ExplorerMapGUI.collapsedZones[zoneName]
        local zoneSymbol = isZoneCollapsed and "|cFF00FFFF[+]|r" or "|cFF00FFFF[-]|r"
        
        local zoneButton = CreateClickableText(
            ExplorerMapGUI.content,
            zoneSymbol .. " " .. string.upper(zoneName),
            10, yPos,
            colors.zone,
            nil
        )
        
        zoneButton.zoneName = zoneName
        zoneButton:SetScript("OnClick", function()
            local zn = this.zoneName
            ExplorerMapGUI.collapsedZones[zn] = not ExplorerMapGUI.collapsedZones[zn]
            SaveGUIState()
            UpdateGUIContent()
        end)
        
        yPos = yPos - lineHeight - 3
        
        if not isZoneCollapsed then
            local sortedSubzones = {}
            for subzoneName, _ in pairs(subzoneGroups) do
                table.insert(sortedSubzones, subzoneName)
            end
            table.sort(sortedSubzones)
            
            for _, subzoneName in ipairs(sortedSubzones) do
                local subzoneNPCs = subzoneGroups[subzoneName]
                local subzoneKey = zoneName .. "_" .. subzoneName
                local isSubzoneCollapsed = ExplorerMapGUI.collapsedSubzones[subzoneKey]
                local subzoneSymbol = isSubzoneCollapsed and "|cFF00FFFF[+]|r" or "|cFF00FFFF[-]|r"
                
                local subzoneButton = CreateClickableText(
                    ExplorerMapGUI.content,
                    "  " .. subzoneSymbol .. " " .. subzoneName,
                    20, yPos,
                    colors.subzone,
                    nil
                )
                
                subzoneButton.subzoneKey = subzoneKey
                subzoneButton:SetScript("OnClick", function()
                    local sk = this.subzoneKey
                    ExplorerMapGUI.collapsedSubzones[sk] = not ExplorerMapGUI.collapsedSubzones[sk]
                    SaveGUIState()
                    UpdateGUIContent()
                end)
                
                yPos = yPos - lineHeight
                
                if not isSubzoneCollapsed then
                    table.sort(subzoneNPCs, function(a, b) return a.name < b.name end)
                    
                    for _, npc in ipairs(subzoneNPCs) do
                        local npcKey = zoneName .. "_" .. subzoneName .. "_" .. npc.name
                        local isNPCCollapsed = ExplorerMapGUI.collapsedNPCs[npcKey]
                        local npcSymbol = isNPCCollapsed and "|cFF00FFFF[+]|r" or "|cFF00FFFF[-]|r"
                        
                        local npcButton = CreateClickableText(
                            ExplorerMapGUI.content,
                            "    " .. npcSymbol .. " " .. npc.name,
                            30, yPos,
                            colors.npc,
                            nil
                        )
                        
                        npcButton.npcKey = npcKey
                        npcButton:SetScript("OnClick", function()
                            local nk = this.npcKey
                            ExplorerMapGUI.collapsedNPCs[nk] = not ExplorerMapGUI.collapsedNPCs[nk]
                            SaveGUIState()
                            UpdateGUIContent()
                        end)
                        
                        yPos = yPos - lineHeight
                        
                        if not isNPCCollapsed then
                            if TableLength(npc.questInfo.availableQuests) > 0 then
                                local availableKey = npcKey .. "_available"
                                local isAvailableCollapsed = ExplorerMapGUI.collapsedQuestSections[availableKey]
                                local availableSymbol = isAvailableCollapsed and "|cFF00FFFF[+]|r" or "|cFF00FFFF[-]|r"
                                
                                local availableButton = CreateClickableText(
                                    ExplorerMapGUI.content,
                                    "      " .. availableSymbol .. " Available Quests",
                                    40, yPos,
                                    colors.availableHeader,
                                    nil
                                )
                                
                                availableButton.questSectionKey = availableKey
                                availableButton:SetScript("OnClick", function()
                                    local qsk = this.questSectionKey
                                    ExplorerMapGUI.collapsedQuestSections[qsk] = not ExplorerMapGUI.collapsedQuestSections[qsk]
                                    SaveGUIState()
                                    UpdateGUIContent()
                                end)
                                
                                yPos = yPos - lineHeight
                                
                                if not isAvailableCollapsed then
                                    for i = 1, TableLength(npc.questInfo.availableQuests) do
                                        local questName = npc.questInfo.availableQuests[i]
                                        local level = npc.questInfo.questLevels and npc.questInfo.questLevels[questName]
                                        local displayText = "        - "
                                        if level then
                                            displayText = displayText .. "[" .. level .. "] "
                                        end
                                        displayText = displayText .. questName
                                        CreateStaticText(ExplorerMapGUI.content, displayText, 50, yPos, colors.available)
                                        yPos = yPos - lineHeight
                                    end
                                end
                            end
                            
                            if TableLength(npc.questInfo.activeQuests) > 0 then
                                local activeKey = npcKey .. "_active"
                                local isActiveCollapsed = ExplorerMapGUI.collapsedQuestSections[activeKey]
                                local activeSymbol = isActiveCollapsed and "|cFF00FFFF[+]|r" or "|cFF00FFFF[-]|r"
                                
                                local activeButton = CreateClickableText(
                                    ExplorerMapGUI.content,
                                    "      " .. activeSymbol .. " Active Quests",
                                    40, yPos,
                                    colors.activeHeader,
                                    nil
                                )
                                
                                activeButton.questSectionKey = activeKey
                                activeButton:SetScript("OnClick", function()
                                    local qsk = this.questSectionKey
                                    ExplorerMapGUI.collapsedQuestSections[qsk] = not ExplorerMapGUI.collapsedQuestSections[qsk]
                                    SaveGUIState()
                                    UpdateGUIContent()
                                end)
                                
                                yPos = yPos - lineHeight
                                
                                if not isActiveCollapsed then
                                    for i = 1, TableLength(npc.questInfo.activeQuests) do
                                        local questName = npc.questInfo.activeQuests[i]
                                        local level = npc.questInfo.questLevels and npc.questInfo.questLevels[questName]
                                        local displayText = "        - "
                                        if level then
                                            displayText = displayText .. "[" .. level .. "] "
                                        end
                                        displayText = displayText .. questName
                                        CreateStaticText(ExplorerMapGUI.content, displayText, 50, yPos, colors.active)
                                        yPos = yPos - lineHeight
                                    end
                                end
                            end
                        end
                        
                        yPos = yPos - 5
                    end
                end
                
                yPos = yPos - 8
            end
        end
        
        yPos = yPos - 8
    end
    
    local contentHeight = math.abs(yPos) + 30
    ExplorerMapGUI.content:SetHeight(contentHeight)
    ExplorerMapGUI.scrollFrame:UpdateScrollChildRect()
    
    local scrollBar = getglobal(ExplorerMapGUI.scrollFrame:GetName().."ScrollBar")
    if scrollBar and contentHeight <= ExplorerMapGUI.scrollFrame:GetHeight() then
        scrollBar:SetValue(0)
    end
end

local function CollapseAll()
    for zoneName, npcs in pairs(ExplorerMap.db) do
        ExplorerMapGUI.collapsedZones[zoneName] = true
        
        local subzoneGroups = {}
        for _, npc in pairs(npcs) do
            if TableLength(npc.questInfo.availableQuests) > 0 or TableLength(npc.questInfo.activeQuests) > 0 then
                local subzoneName = npc.subzone
                if not subzoneName or subzoneName == "" then
                    subzoneName = "Undiscovered Area"
                end
                subzoneGroups[subzoneName] = true
            end
        end
        
        for subzoneName, _ in pairs(subzoneGroups) do
            local subzoneKey = zoneName .. "_" .. subzoneName
            ExplorerMapGUI.collapsedSubzones[subzoneKey] = true
            
            for _, npc in pairs(npcs) do
                if (npc.subzone == subzoneName or (not npc.subzone and subzoneName == "Undiscovered Area")) and
                   (TableLength(npc.questInfo.availableQuests) > 0 or TableLength(npc.questInfo.activeQuests) > 0) then
                    local npcKey = zoneName .. "_" .. subzoneName .. "_" .. npc.name
                    ExplorerMapGUI.collapsedNPCs[npcKey] = true
                    
                    if TableLength(npc.questInfo.availableQuests) > 0 then
                        ExplorerMapGUI.collapsedQuestSections[npcKey .. "_available"] = true
                    end
                    if TableLength(npc.questInfo.activeQuests) > 0 then
                        ExplorerMapGUI.collapsedQuestSections[npcKey .. "_active"] = true
                    end
                end
            end
        end
    end
    SaveGUIState()
    UpdateGUIContent()
end

local function ExpandAll()
    ExplorerMapGUI.collapsedZones = {}
    ExplorerMapGUI.collapsedSubzones = {}
    ExplorerMapGUI.collapsedNPCs = {}
    ExplorerMapGUI.collapsedQuestSections = {}
    SaveGUIState()
    UpdateGUIContent()
end

local function CreateGUI()
    if ExplorerMapGUI.frame then return end
    
    local frame = CreateFrame("Frame", "ExplorerMapGUIFrame", UIParent)
    frame:SetWidth(384)
    frame:SetHeight(512)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    
    table.insert(UISpecialFrames, "ExplorerMapGUIFrame")
    
    local topLeft = frame:CreateTexture(nil, "BACKGROUND")
    topLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft")
    topLeft:SetWidth(256)
    topLeft:SetHeight(256)
    topLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -1)
    
    local topRight = frame:CreateTexture(nil, "BACKGROUND")
    topRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight")
    topRight:SetWidth(128)
    topRight:SetHeight(256)
    topRight:SetPoint("TOPLEFT", frame, "TOPLEFT", 258, -1)
    
    local bottomLeft = frame:CreateTexture(nil, "BACKGROUND")
    bottomLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft")
    bottomLeft:SetWidth(256)
    bottomLeft:SetHeight(256)
    bottomLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -257)
    
    local bottomRight = frame:CreateTexture(nil, "BACKGROUND")
    bottomRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight")
    bottomRight:SetWidth(128)
    bottomRight:SetHeight(256)
    bottomRight:SetPoint("TOPLEFT", frame, "TOPLEFT", 258, -257)
    
    local portrait = frame:CreateTexture("ExplorerMapFramePortrait", "ARTWORK")
    portrait:SetTexture("Interface\\AddOns\\ExplorerMap\\icon")
    portrait:SetWidth(64)
    portrait:SetHeight(64)
    portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -7)
    
    local title = frame:CreateFontString("ExplorerMapNameText", "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    title:SetText("Explorer's Map")
    title:SetTextColor(1, 1, 1)
    
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("CENTER", frame, "TOPRIGHT", -44, -26)
    closeBtn:SetScript("OnClick", function() ToggleGUI() end)
    
    local collapseBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    collapseBtn:SetWidth(80)
    collapseBtn:SetHeight(20)
    collapseBtn:SetPoint("CENTER", frame, "TOP", -50, -60)
    collapseBtn:SetText("Collapse All")
    collapseBtn:SetScript("OnClick", function() CollapseAll() end)

    local expandBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    expandBtn:SetWidth(80)
    expandBtn:SetHeight(20)
    expandBtn:SetPoint("CENTER", frame, "TOP", 50, -60)
    expandBtn:SetText("Expand All")
    expandBtn:SetScript("OnClick", function() ExpandAll() end)
    
    local scrollFrame = CreateFrame("ScrollFrame", "ExplorerMapScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -85)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -65, 90)
    
    local content = CreateFrame("Frame", "ExplorerMapContent", scrollFrame)
    content:SetWidth(290)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    
    ExplorerMapGUI.frame = frame
    ExplorerMapGUI.content = content
    ExplorerMapGUI.scrollFrame = scrollFrame
    
    frame:Hide()
end

function ToggleGUI()
    if not ExplorerMapGUI.frame then
        CreateGUI()
    end
    
    if ExplorerMapGUI.isVisible then
        ExplorerMapGUI.frame:Hide()
        ExplorerMapGUI.isVisible = false
    else
        UpdateGUIContent()
        ExplorerMapGUI.frame:Show()
        ExplorerMapGUI.isVisible = true
    end
end

---------------------------------------------------
-- Quest Log Scanning 
---------------------------------------------------
local function ScanQuestLog()
    local currentQuests = {}
    local questLevels = {}
    local numQuests = GetNumQuestLogEntries()
    for i=1,numQuests do
        local title, level, _, isHeader = GetQuestLogTitle(i)
        if title and not isHeader then
            currentQuests[title] = true
            questLevels[title] = level
        end
    end

    for zone, npcs in pairs(ExplorerMap.db) do
        for _, npc in pairs(npcs) do
            if not npc.questInfo then
                npc.questInfo = { availableQuests = {}, activeQuests = {}, completedQuests = {}, questLevels = {} }
            end
            if not npc.questInfo.questLevels then npc.questInfo.questLevels = {} end
            for questName, level in pairs(questLevels) do
                npc.questInfo.questLevels[questName] = level
            end
        end
    end

    for questName,_ in pairs(questLogSnapshot) do
        if not currentQuests[questName] then
            for zone,npcs in pairs(ExplorerMap.db) do
                for _, npc in pairs(npcs) do
                    if npc.questInfo then
                        AbandonQuest(npc, questName)
                    end
                end
            end
        end
    end

    for questName,_ in pairs(currentQuests) do
        if not questLogSnapshot[questName] then
            local targetNPC = UnitName("target")
            local questHandled = false
            
            for zone,npcs in pairs(ExplorerMap.db) do
                if questHandled then break end
                for _, npc in pairs(npcs) do
                    if npc.questInfo and IsQuestInList(npc.questInfo.availableQuests, questName) and not questHandled then
                        if targetNPC and npc.name == targetNPC then
                            AcceptQuest(npc, questName)
                            questHandled = true
                            break
                        end
                    end
                end
            end
            
            if not questHandled then
                for zone,npcs in pairs(ExplorerMap.db) do
                    if questHandled then break end
                    for _, npc in pairs(npcs) do
                        if npc.questInfo and IsQuestInList(npc.questInfo.availableQuests, questName) and not questHandled then
                            AcceptQuest(npc, questName)
                            questHandled = true
                            break
                        end
                    end
                end
            end
        end
    end

    questLogSnapshot = currentQuests
    RefreshIconColors()
end

---------------------------------------------------
-- Data Management
---------------------------------------------------
local function CleanOldData()
    local cleaned = 0
    local questsCleaned = 0
    
    for zoneName, npcs in pairs(ExplorerMap.db) do
        for npcKey, npc in pairs(npcs) do
            if npc.questInfo then
                local cleanedActive = {}
                local numQuests = GetNumQuestLogEntries()
                
                for i = 1, TableLength(npc.questInfo.activeQuests) do
                    local questName = npc.questInfo.activeQuests[i]
                    local foundInLog = false
                    
                    for j = 1, numQuests do
                        local title, _, _, isHeader = GetQuestLogTitle(j)
                        if title and not isHeader and title == questName then
                            foundInLog = true
                            break
                        end
                    end
                    
                    if foundInLog then
                        table.insert(cleanedActive, questName)
                    else
                        questsCleaned = questsCleaned + 1
                    end
                end
                
                npc.questInfo.activeQuests = cleanedActive
                
                if TableLength(npc.questInfo.availableQuests) == 0 and 
                   TableLength(npc.questInfo.activeQuests) == 0 and
                   TableLength(npc.questInfo.completedQuests) == 0 then
                    ExplorerMap.db[zoneName][npcKey] = nil
                    cleaned = cleaned + 1
                end
            end
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("ExplorerMap: Removed " .. cleaned .. " obsolete NPCs and " .. questsCleaned .. " orphaned quests")
end

---------------------------------------------------
-- Event Handling
---------------------------------------------------
local function CanSaveNPC(npcName, t)
    return not lastSavedNPC[npcName] or (t - lastSavedNPC[npcName] > 2)
end

local function OnEvent()
    if event=="PLAYER_LOGIN" then
        local key = UnitName("player").."-"..GetRealmName()
        if not ExplorerMapDB then ExplorerMapDB = {} end
        if not ExplorerMapDB[key] then ExplorerMapDB[key] = {} end
        ExplorerMap.db = ExplorerMapDB[key]
        
        if not ExplorerMapDB[key].guiState then
            ExplorerMapDB[key].guiState = {
                collapsedZones = {},
                collapsedSubzones = {},
                collapsedNPCs = {},
                collapsedQuestSections = {}
            }
        end
        
        ExplorerMapGUI.collapsedZones = ExplorerMapDB[key].guiState.collapsedZones
        ExplorerMapGUI.collapsedSubzones = ExplorerMapDB[key].guiState.collapsedSubzones
        ExplorerMapGUI.collapsedNPCs = ExplorerMapDB[key].guiState.collapsedNPCs
        ExplorerMapGUI.collapsedQuestSections = ExplorerMapDB[key].guiState.collapsedQuestSections
            
    elseif event=="QUEST_DETAIL" then
        SetMapToCurrentZone()
        local npcName = UnitName("target")
        local questTitle = GetTitleText()
        local x,y = GetPlayerMapPosition("player")
        local zone = GetRealZoneText()
        local subzone = GetSubZoneText()
        local t = time()
        
        if npcName and questTitle and zone then
            local questAlreadyInLog = false
            local numQuests = GetNumQuestLogEntries()
            for i=1,numQuests do
                local title, level, _, isHeader = GetQuestLogTitle(i)
                if title and not isHeader and title == questTitle then
                    questAlreadyInLog = true
                    break
                end
            end
            
            if not questAlreadyInLog then
                if x == 0 and y == 0 then
                    SetMapToCurrentZone()
                    x, y = GetPlayerMapPosition("player")
                end
                
                if x > 0 and y > 0 then
                    local npc = CreateNPCIfNeeded(npcName,x,y,zone,subzone)
                    
                    local questLevel = nil
                    for i=1,numQuests do
                        local title, level, _, isHeader = GetQuestLogTitle(i)
                        if title and not isHeader and title == questTitle then
                            questLevel = level
                            break
                        end
                    end
                    
                    AddAvailableQuest(npc, questTitle, questLevel)
                    lastSavedNPC[npcName] = t
                end
            end
        end
            
    elseif event=="QUEST_GREETING" then
        SetMapToCurrentZone()
        local npcName = UnitName("target")
        local x,y = GetPlayerMapPosition("player")
        local zone = GetRealZoneText()
        local subzone = GetSubZoneText()
        local t = time()
        
        if npcName and zone and x > 0 and y > 0 and CanSaveNPC(npcName,t) then
            CreateNPCIfNeeded(npcName,x,y,zone,subzone)
            lastSavedNPC[npcName] = t
        end
        
    elseif event=="QUEST_COMPLETE" then
        local questTitle = GetTitleText()
        if questTitle then
            for zone,npcs in pairs(ExplorerMap.db) do
                for _, npc in pairs(npcs) do
                    CompleteQuest(npc, questTitle)
                end
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("QUEST_GREETING")  
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_COMPLETE")
frame:SetScript("OnEvent", OnEvent)

---------------------------------------------------
-- OnUpdate Timer
---------------------------------------------------
local checkFrame = CreateFrame("Frame")
checkFrame.timer = 0
checkFrame:SetScript("OnUpdate", function()
    checkFrame.timer = checkFrame.timer + arg1
    if checkFrame.timer > 1.0 then
        checkFrame.timer = 0
        ScanQuestLog()
        CheckWorldMap()
    end
end)

---------------------------------------------------
-- Slash Commands
---------------------------------------------------
SLASH_EXPLORER1 = "/explorer"
SLASH_EXPLORER2 = "/exp"
SlashCmdList["EXPLORER"] = function(msg)
    if msg=="gui" then
        ToggleGUI()
    elseif msg=="refresh" then
        UpdateMapIcons()
        DEFAULT_CHAT_FRAME:AddMessage("ExplorerMap: Icons refreshed")
    elseif msg=="clear" then
        local key = UnitName("player").."-"..GetRealmName()
        if ExplorerMapDB then 
            ExplorerMapDB[key] = {}
        end
        ExplorerMap.db = {}
        ExplorerMapGUI.collapsedZones = {}
        ExplorerMapGUI.collapsedSubzones = {}
        ExplorerMapGUI.collapsedNPCs = {}
        ExplorerMapGUI.collapsedQuestSections = {}
        DEFAULT_CHAT_FRAME:AddMessage("ExplorerMap: All data cleared")
    elseif msg=="sweep" then
        CleanOldData()
    else
        DEFAULT_CHAT_FRAME:AddMessage("ExplorerMap commands:")
        DEFAULT_CHAT_FRAME:AddMessage("/explorer gui - Open quest giver window")
        DEFAULT_CHAT_FRAME:AddMessage("/explorer refresh - Refresh map icons")
        DEFAULT_CHAT_FRAME:AddMessage("/explorer clear - Clear all data")
        DEFAULT_CHAT_FRAME:AddMessage("/explorer sweep - Remove NPCs with no quests")
    end
end
