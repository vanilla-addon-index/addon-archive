-- GearSetTooltips: Shows which ItemRack/Outfitter sets an item belongs to

GearSetTooltips = {}

-- Cache of set item IDs for performance
GearSetTooltips.SetItems = {}

-- Initialization flag
GearSetTooltips.Initialized = false

-- Settings frame reference
GearSetTooltips.SettingsFrame = nil

-- Default settings
local defaults = {
    setColors = {} -- Individual colors per set
}

-- Color presets
local colorPresets = {
    ["Blue"] = {r = 0.5, g = 0.5, b = 1.0},
    ["Light Blue"] = {r = 0.5, g = 0.8, b = 1.0},
    ["Green"] = {r = 0.5, g = 1.0, b = 0.5},
    ["Yellow"] = {r = 1.0, g = 1.0, b = 0.5},
    ["Orange"] = {r = 1.0, g = 0.6, b = 0.2},
    ["Red"] = {r = 1.0, g = 0.3, b = 0.3},
    ["Purple"] = {r = 0.8, g = 0.5, b = 1.0},
    ["White"] = {r = 1.0, g = 1.0, b = 1.0}
}

-- Get current color based on per-set color
function GearSetTooltips:GetCurrentColor(setName)
    -- Safety check - ensure setColors exists
    if not GearSetTooltipsDB or not GearSetTooltipsDB.setColors then
        return 0.5, 0.5, 1.0 -- fallback to blue
    end
    
    if setName and GearSetTooltipsDB.setColors[setName] then
        -- Use per-set color if defined
        local preset = GearSetTooltipsDB.setColors[setName]
        local color = colorPresets[preset]
        if color then
            return color.r, color.g, color.b
        end
    end
    
    -- Default to Blue
    return 0.5, 0.5, 1.0
end

-- Initialize addon
function GearSetTooltips:Initialize()
    -- Initialize saved variables
    if not GearSetTooltipsDB then
        GearSetTooltipsDB = {}
    end
    
    -- Apply defaults
    for k, v in pairs(defaults) do
        if GearSetTooltipsDB[k] == nil then
            GearSetTooltipsDB[k] = v
        end
    end
    
    -- Ensure setColors is a table
    if type(GearSetTooltipsDB.setColors) ~= "table" then
        GearSetTooltipsDB.setColors = {}
    end
    
    -- Wait for ItemRack or Outfitter to load
    self:RegisterEvents()
end

-- Register events
function GearSetTooltips:RegisterEvents()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    
    frame:SetScript("OnEvent", function()
        if not GearSetTooltips.Initialized then
            if IsAddOnLoaded("ItemRack") or IsAddOnLoaded("Outfitter") then
                GearSetTooltips:OnAddonsLoaded()
            end
        end
    end)
end

function GearSetTooltips:OnAddonsLoaded()
    -- Prevent multiple initializations
    if self.Initialized then
        return
    end
    self.Initialized = true
    
    -- Update set items cache
    self:UpdateSetItems()
    
    -- Hook ItemRack functions to update cache
    if ItemRack and ItemRack.SaveSet then
        self:HookFunction(ItemRack, "SaveSet")
    end
    if ItemRack and ItemRack.DeleteSet then
        self:HookFunction(ItemRack, "DeleteSet")
    end
    
    -- Hook tooltips
    self:HookTooltips()
    
    -- Delay the load message to ensure chat frame is ready
    local msgFrame = CreateFrame("Frame")
    local elapsed = 0
    msgFrame:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed >= 0.5 then
            local msg = "GearSetTooltips loaded"
            if IsAddOnLoaded("ItemRack") and IsAddOnLoaded("Outfitter") then
                msg = msg .. " - Tracking ItemRack and Outfitter sets"
            elseif IsAddOnLoaded("ItemRack") then
                msg = msg .. " - Tracking ItemRack sets"
            elseif IsAddOnLoaded("Outfitter") then
                msg = msg .. " - Tracking Outfitter sets"
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00" .. msg .. "|r")
            msgFrame:SetScript("OnUpdate", nil)
        end
    end)
    
    -- Schedule a delayed update
    self:ScheduleUpdate(2)
end

-- Simple function hooking
function GearSetTooltips:HookFunction(table, funcName)
    if not table or not table[funcName] then return end
    
    local original = table[funcName]
    table[funcName] = function(...)
        local result = original(unpack(arg))
        GearSetTooltips:UpdateSetItems()
        return result
    end
end

-- Schedule a delayed update
function GearSetTooltips:ScheduleUpdate(delay)
    local frame = CreateFrame("Frame")
    local elapsed = 0
    
    frame:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed >= delay then
            GearSetTooltips:UpdateSetItems()
            frame:SetScript("OnUpdate", nil)
        end
    end)
end

-- Build cache of all items in ItemRack and Outfitter sets
function GearSetTooltips:UpdateSetItems()
    local success, errorMsg = pcall(function()
        local oldCount = 0
        for _ in pairs(GearSetTooltips.SetItems) do
            oldCount = oldCount + 1
        end
        
        GearSetTooltips.SetItems = {}
        
        local count = 0
        
        -- Read ItemRack sets
        if IsAddOnLoaded("ItemRack") then
            local userData = Rack_User or ItemRack_Users
            
            if userData then
                local user = UnitName("player") .. " of " .. GetRealmName()
                
                if userData[user] and userData[user].Sets then
                    for setName, setData in pairs(userData[user].Sets) do
                        if not string.find(setName, "^ItemRack%-") and not string.find(setName, "^Rack%-") then
                            for slot = 0, 19 do
                                local itemData = setData[slot]
                                if itemData and type(itemData) == "table" then
                                    local itemID = itemData.id
                                    
                                    if itemID and itemID ~= 0 then
                                        if type(itemID) == "string" then
                                            local _, _, extractedID = string.find(itemID, "^(%d+)")
                                            itemID = tonumber(extractedID)
                                        end
                                        
                                        if itemID and itemID > 0 then
                                            if not GearSetTooltips.SetItems[itemID] then
                                                count = count + 1
                                            end
                                            GearSetTooltips.SetItems[itemID] = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Read Outfitter sets
        if IsAddOnLoaded("Outfitter") and gOutfitter_Settings and gOutfitter_Settings.Outfits then
            for cat, outfits in pairs(gOutfitter_Settings.Outfits) do
                if table.getn(outfits) > 0 then
                    for _, outfit in ipairs(outfits) do
                        if outfit.Items then
                            for slot, item in pairs(outfit.Items) do
                                local itemID = tonumber(item.Code)
                                
                                if itemID and itemID > 0 then
                                    if not GearSetTooltips.SetItems[itemID] then
                                        count = count + 1
                                    end
                                    GearSetTooltips.SetItems[itemID] = true
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Show message if count changed
        if count ~= oldCount then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Item Set Change Detected - Tooltips Updated|r")
        end
    end)
    
    if not success then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000GearSetTooltips: Error updating cache - " .. tostring(errorMsg) .. "|r")
    end
end

-- Get which sets an item belongs to (from both ItemRack and Outfitter)
function GearSetTooltips:GetItemSets(itemID)
    if not itemID then return nil end
    
    -- Only process if item is in our cache
    if not self.SetItems[itemID] then return nil end
    
    local sets = {}
    
    -- Check ItemRack sets
    if IsAddOnLoaded("ItemRack") then
        local userData = Rack_User or ItemRack_Users
        
        if userData then
            local user = UnitName("player") .. " of " .. GetRealmName()
            
            if userData[user] and userData[user].Sets then
                for setName, setData in pairs(userData[user].Sets) do
                    if not string.find(setName, "^ItemRack%-") and not string.find(setName, "^Rack%-") then
                        for slot = 0, 19 do
                            local itemData = setData[slot]
                            if itemData and type(itemData) == "table" then
                                local slotItemID = itemData.id
                                
                                if slotItemID and slotItemID ~= 0 then
                                    if type(slotItemID) == "string" then
                                        local _, _, extractedID = string.find(slotItemID, "^(%d+)")
                                        slotItemID = tonumber(extractedID)
                                    end
                                    
                                    if slotItemID and slotItemID == itemID then
                                        table.insert(sets, setName)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Check Outfitter sets
    if IsAddOnLoaded("Outfitter") and gOutfitter_Settings and gOutfitter_Settings.Outfits then
        for cat, outfits in pairs(gOutfitter_Settings.Outfits) do
            if table.getn(outfits) > 0 then
                for _, outfit in ipairs(outfits) do
                    if outfit.Items and outfit.Name then
                        for slot, item in pairs(outfit.Items) do
                            local outfitItemID = tonumber(item.Code)
                            
                            if outfitItemID and outfitItemID == itemID then
                                table.insert(sets, outfit.Name)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
    if table.getn(sets) > 0 then
        return sets
    else
        return nil
    end
end

-- Hook all tooltip events
function GearSetTooltips:HookTooltips()
    -- Store a reference to the last item we added info for to prevent duplicates
    self.lastItemProcessed = nil
    
    -- Hook GameTooltip SetBagItem for bag items only
    local orig_SetBagItem = GameTooltip.SetBagItem
    GameTooltip.SetBagItem = function(this, bag, slot)
        orig_SetBagItem(this, bag, slot)
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
            GearSetTooltips:AddSetsToTooltip(this, itemLink)
        end
    end
    
    -- Hook OnHide to clear the last processed item
    local orig_OnHide = GameTooltip:GetScript("OnHide")
    GameTooltip:SetScript("OnHide", function()
        if orig_OnHide then
            orig_OnHide()
        end
        GearSetTooltips.lastItemProcessed = nil
    end)
end

-- Add set information directly to the game tooltip
function GearSetTooltips:AddSetsToTooltip(tooltip, itemLink)
    if not itemLink then
        return
    end
    
    -- Prevent adding the same item multiple times
    if self.lastItemProcessed == itemLink then
        return
    end
    self.lastItemProcessed = itemLink
    
    local _, _, itemID = string.find(itemLink, "item:(%d+)")
    itemID = tonumber(itemID)
    
    if not itemID then
        return
    end
    
    local sets = self:GetItemSets(itemID)
    if sets then
        -- Limit to 5 sets
        local totalSets = table.getn(sets)
        local displayCount = math.min(5, totalSets)
        
        -- Add 'Gear Sets:' label in white
        tooltip:AddLine("Gear Sets:", 1.0, 1.0, 1.0)
        
        -- Add each set on its own line with its individual color, indented
        for i = 1, displayCount do
            local setName = sets[i]
            local r, g, b = GearSetTooltips:GetCurrentColor(setName)
            tooltip:AddLine("  " .. setName, r, g, b)
        end
        
        -- If there are more than 5, show count
        if totalSets > 5 then
            tooltip:AddLine("  (+" .. (totalSets - 5) .. " more)", 0.5, 0.5, 0.5)
        end
    end
end

-- Create settings frame
function GearSetTooltips:CreateSettingsFrame()
    if self.SettingsFrame then
        return self.SettingsFrame
    end
    
    local frame = CreateFrame("Frame", "GearSetTooltipsSettings", UIParent)
    frame:SetWidth(400)
    frame:SetHeight(280)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 1.0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame:Hide()
    
    -- Make ESC key close the window
    table.insert(UISpecialFrames, "GearSetTooltipsSettings")
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("GearSet Tooltips")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    -- Sets label
    local setsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    setsLabel:SetPoint("TOPLEFT", 20, -50)
    setsLabel:SetText("Detected Sets:")
    setsLabel:SetTextColor(1.0, 1.0, 1.0)
    
    -- Column headings
    local nameHeading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameHeading:SetPoint("TOPLEFT", 25, -75)
    nameHeading:SetText("Set Name")
    nameHeading:SetTextColor(1.0, 0.82, 0)
    
    local colorHeading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colorHeading:SetPoint("TOPLEFT", 265, -75)
    colorHeading:SetText("Color")
    colorHeading:SetTextColor(1.0, 0.82, 0)
    
    -- Scrollable sets list
    local scrollFrame = CreateFrame("ScrollFrame", "GearSetTooltipsScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -97)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 60)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(310)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    
    frame.scrollChild = scrollChild
    
    -- Horizontal divider line between column headings and list
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("LEFT", 15, 50)
    divider:SetPoint("RIGHT", -15, 50)
    divider:SetTexture(0.5, 0.5, 0.5, 1.0)
    
    -- Detect Set Changes button (left)
    local updateBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    updateBtn:SetWidth(130)
    updateBtn:SetHeight(25)
    updateBtn:SetPoint("BOTTOMLEFT", 10, 15)
    updateBtn:SetText("Detect Set Changes")
    updateBtn:SetScript("OnClick", function()
        GearSetTooltips:UpdateSetItems()
        GearSetTooltips:RefreshSettingsFrame()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Sets updated!|r")
    end)
    
    -- Save & Close button (center)
    local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveBtn:SetWidth(100)
    saveBtn:SetHeight(25)
    saveBtn:SetPoint("BOTTOM", 0, 15)
    saveBtn:SetText("Save & Close")
    saveBtn:SetScript("OnClick", function()
        frame:Hide()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00GearSetTooltips settings saved!|r")
    end)
    
    -- Reset All Colors button (right)
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetWidth(130)
    resetBtn:SetHeight(25)
    resetBtn:SetPoint("BOTTOMRIGHT", -10, 15)
    resetBtn:SetText("Reset All Colors")
    resetBtn:SetScript("OnClick", function()
        GearSetTooltipsDB.setColors = {}
        GearSetTooltips:RefreshSettingsFrame()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00All set colors reset to blue!|r")
    end)
    
    self.SettingsFrame = frame
    return frame
end

-- Create color selection dialog for a specific set
function GearSetTooltips:ShowColorDialog(setName)
    -- Create or reuse dialog frame
    if not self.ColorDialog then
        local dialog = CreateFrame("Frame", "GearSetTooltipsColorDialog", UIParent)
        dialog:SetWidth(200)
        dialog:SetHeight(280)
        dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        dialog:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        dialog:SetBackdropColor(0.1, 0.1, 0.1, 1.0)
        dialog:SetFrameStrata("DIALOG")
        dialog:Hide()
        
        -- Make ESC key close the color dialog
        table.insert(UISpecialFrames, "ItemSetTooltipColorDialog")
        
        -- Title
        dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dialog.title:SetPoint("TOP", 0, -15)
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -5, -5)
        
        -- Color buttons
        dialog.colorButtons = {}
        local buttonY = -45
        local buttonIndex = 0
        
        for presetName, color in pairs(colorPresets) do
            local btn = CreateFrame("Button", nil, dialog)
            btn:SetWidth(170)
            btn:SetHeight(26)
            btn:SetPoint("TOP", 0, buttonY)
            
            -- Highlight only (no background texture)
            btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
            
            -- Color preview square
            btn.colorBox = btn:CreateTexture(nil, "OVERLAY")
            btn.colorBox:SetWidth(14)
            btn.colorBox:SetHeight(14)
            btn.colorBox:SetPoint("LEFT", 8, 0)
            btn.colorBox:SetTexture(color.r, color.g, color.b, 1)
            
            -- Text
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.text:SetPoint("LEFT", 28, 0)
            btn.text:SetText(presetName)
            
            btn.presetName = presetName
            btn:SetScript("OnClick", function()
                -- Ensure setColors table exists
                if not GearSetTooltipsDB.setColors then
                    GearSetTooltipsDB.setColors = {}
                end
                GearSetTooltipsDB.setColors[dialog.currentSet] = this.presetName
                GearSetTooltips:RefreshSettingsFrame()
                dialog:Hide()
            end)
            
            table.insert(dialog.colorButtons, btn)
            buttonY = buttonY - 28
            buttonIndex = buttonIndex + 1
        end
        
        self.ColorDialog = dialog
    end
    
    self.ColorDialog.currentSet = setName
    self.ColorDialog.title:SetText("Color for: " .. setName)
    self.ColorDialog:Show()
end

-- Refresh settings frame with current set list
function GearSetTooltips:RefreshSettingsFrame()
    if not self.SettingsFrame then return end
    
    -- Clear existing rows
    if self.SettingsFrame.setRows then
        for _, row in ipairs(self.SettingsFrame.setRows) do
            row:Hide()
        end
    else
        self.SettingsFrame.setRows = {}
    end
    
    local setList = {}
    
    -- Get ItemRack sets
    if IsAddOnLoaded("ItemRack") then
        local userData = Rack_User or ItemRack_Users
        if userData then
            local user = UnitName("player") .. " of " .. GetRealmName()
            if userData[user] and userData[user].Sets then
                for setName, _ in pairs(userData[user].Sets) do
                    if not string.find(setName, "^ItemRack%-") and not string.find(setName, "^Rack%-") then
                        table.insert(setList, {name = setName, addon = "ItemRack"})
                    end
                end
            end
        end
    end
    
    -- Get Outfitter sets
    if IsAddOnLoaded("Outfitter") and gOutfitter_Settings and gOutfitter_Settings.Outfits then
        for cat, outfits in pairs(gOutfitter_Settings.Outfits) do
            if table.getn(outfits) > 0 then
                for _, outfit in ipairs(outfits) do
                    if outfit.Name and outfit.Items then
                        -- Check if the outfit actually has items
                        local hasItems = false
                        for slot, item in pairs(outfit.Items) do
                            if item.Code and tonumber(item.Code) and tonumber(item.Code) > 0 then
                                hasItems = true
                                break
                            end
                        end
                        
                        -- Only add to list if it has items
                        if hasItems then
                            table.insert(setList, {name = outfit.Name, addon = "Outfitter"})
                        end
                    end
                end
            end
        end
    end
    
    -- Sort alphabetically by name
    table.sort(setList, function(a, b) return a.name < b.name end)
    
    -- Create or update rows
    local rowHeight = 16
    local yOffset = -5
    
    for i, setData in ipairs(setList) do
        local row = self.SettingsFrame.setRows[i]
        
        if not row then
            -- Create new row
            row = CreateFrame("Button", nil, self.SettingsFrame.scrollChild)
            row:SetHeight(rowHeight)
            row:SetWidth(320)
            
            -- Highlight texture
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            
            -- Set name text
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("LEFT", 5, 0)
            row.nameText:SetJustifyH("LEFT")
            row.nameText:SetWidth(220)
            
            -- Color indicator (small colored square)
            row.colorBox = row:CreateTexture(nil, "OVERLAY")
            row.colorBox:SetWidth(12)
            row.colorBox:SetHeight(12)
            row.colorBox:SetPoint("LEFT", 256, 0)
            
            -- Click handler
            row:SetScript("OnClick", function()
                GearSetTooltips:ShowColorDialog(this.setName)
            end)
            
            table.insert(self.SettingsFrame.setRows, row)
        end
        
        row:SetPoint("TOPLEFT", 0, yOffset)
        row.nameText:SetText(setData.name .. " (" .. setData.addon .. ")")
        row.setName = setData.name
        
        -- Set color box to this set's individual color
        local r, g, b = self:GetCurrentColor(setData.name)
        row.colorBox:SetTexture(r, g, b, 1)
        
        row:Show()
        yOffset = yOffset - rowHeight
    end
    
    -- Show "No sets found" if empty
    if table.getn(setList) == 0 then
        local row = self.SettingsFrame.setRows[1]
        if not row then
            row = CreateFrame("Frame", nil, self.SettingsFrame.scrollChild)
            row:SetHeight(16)
            row:SetWidth(320)
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("LEFT", 5, 0)
            row.nameText:SetJustifyH("LEFT")
            table.insert(self.SettingsFrame.setRows, row)
        end
        row:SetPoint("TOPLEFT", 0, -5)
        row.nameText:SetText("No sets found")
        row:Show()
    end
    
    -- Update scroll child height
    local totalHeight = math.max(1, table.getn(setList) * rowHeight + 30)
    self.SettingsFrame.scrollChild:SetHeight(totalHeight)
end

-- Show settings frame
function GearSetTooltips:ShowSettings()
    local frame = self:CreateSettingsFrame()
    self:RefreshSettingsFrame()
    frame:Show()
end

-- Slash commands
SLASH_GEARSETTOOLTIPS1 = "/gearsettooltips"
SLASH_GEARSETTOOLTIPS2 = "/gst"
SlashCmdList["GEARSETTOOLTIPS"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "update" or msg == "refresh" then
        GearSetTooltips:UpdateSetItems()
    elseif msg == "options" or msg == "config" or msg == "settings" then
        GearSetTooltips:ShowSettings()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00GearSetTooltips commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("/gst options - Open settings window")
        DEFAULT_CHAT_FRAME:AddMessage("/gst update - Refresh set items cache")
    end
end

-- Initialize on load
GearSetTooltips:Initialize()
