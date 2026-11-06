-- ============================================================================
-- player-monitor.lua - EreaRpMasterPlayerMonitorFrame Controller
-- ============================================================================
-- UI Structure: views/player-monitor.xml
-- Frame: EreaRpMasterPlayerMonitorFrame (defined in XML)
--
-- PURPOSE: Manages the player monitor tab — flat raid overview showing each
--          member's addon status, sync state, and 16-slot inventory inline.
--
-- ROW LAYOUT:
--   [ColorDot 10x10] [PlayerName 110px] [Status 80px] [Zone 120px] [Coords 70px] [icon1..icon16 @ 26x26]
--
-- DEPENDENCIES:
--   - EreaRpLibraries:Messaging() (erea-rp-common)
--   - EreaRpMasterDB (SavedVariable)
--   - EreaRpMasterItemLibrary (services/item-library.lua)
-- ============================================================================

local SLOT_SIZE = 26
local SLOT_SPACING = 2
local SLOT_COUNT = 16
local SLOT_PAD_RIGHT = 4  -- padding from right edge of row
local ROW_HEIGHT = SLOT_SIZE + 8  -- 34px: icon + vertical padding
local NAME_WIDTH = 110
local STATUS_WIDTH = 80
local ZONE_WIDTH = 120
local COORDS_WIDTH = 70
local AUTO_REFRESH_INTERVAL = 30
local STATUS_TIMEOUT = 5

-- Total width consumed by the right-aligned inventory block
local INVENTORY_BLOCK_WIDTH = SLOT_COUNT * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + SLOT_PAD_RIGHT

-- Minimum row width so left text + right icons don't overlap
-- 8 (pad) + 10 (dot) + 4 + NAME_WIDTH + 4 + STATUS_WIDTH + 4 + ZONE_WIDTH + 4 + COORDS_WIDTH + 8 (gap) + INVENTORY_BLOCK
local ROW_MIN_WIDTH = 8 + 10 + 4 + NAME_WIDTH + 4 + STATUS_WIDTH + 4 + ZONE_WIDTH + 4 + COORDS_WIDTH + 8 + INVENTORY_BLOCK_WIDTH

local messaging = EreaRpLibraries:Messaging()
local encoding  = EreaRpLibraries:Encoding()

-- ============================================================================
-- Player state storage (global for cross-module access if needed)
-- ============================================================================
EreaRpMaster_PlayerStates = {}
-- Each entry keyed by player name:
-- { version, syncChecksum, inventory, lastResponse, hasAddon, zone, coordX, coordY }

-- ============================================================================
-- Initialize
-- ============================================================================
function EreaRpMasterPlayerMonitorFrame:Initialize()
    local self = EreaRpMasterPlayerMonitorFrame

    -- Store frame references
    self.scrollFrame = EreaRpMasterPlayerMonitorScrollFrame
    self.scrollChild = EreaRpMasterPlayerMonitorScrollFrameScrollChild
    self.bottomBar = EreaRpMasterPlayerMonitorFrameBottomBar
    self.refreshButton = EreaRpMasterPlayerMonitorFrameBottomBarRefreshButton
    self.autoRefreshCheck = EreaRpMasterPlayerMonitorFrameBottomBarAutoRefreshCheck
    self.statusText = EreaRpMasterPlayerMonitorFrameBottomBarStatusText

    -- Row pool
    self.rowFrames = {}

    -- Pending request tracking
    self.pendingRequest = nil
    self.autoRefreshTimer = 0
    self.autoRefreshEnabled = false

    -- OnShow → refresh when tab selected
    self:SetScript("OnShow", function()
        EreaRpMasterPlayerMonitorFrame:RefreshPlayerList()
    end)

    -- OnHide → stop auto-refresh
    self:SetScript("OnHide", function()
        EreaRpMasterPlayerMonitorFrame:StopAutoRefresh()
        EreaRpMasterPlayerMonitorFrame.autoRefreshCheck:SetChecked(false)
        EreaRpMasterPlayerMonitorFrame.autoRefreshEnabled = false
    end)

    -- Refresh button
    self.refreshButton:SetScript("OnClick", function()
        EreaRpMasterPlayerMonitorFrame:RefreshPlayerList()
    end)

    -- Auto-refresh checkbox
    self.autoRefreshCheck:SetScript("OnClick", function()
        if EreaRpMasterPlayerMonitorFrame.autoRefreshCheck:GetChecked() then
            EreaRpMasterPlayerMonitorFrame.autoRefreshEnabled = true
            EreaRpMasterPlayerMonitorFrame:StartAutoRefresh()
        else
            EreaRpMasterPlayerMonitorFrame.autoRefreshEnabled = false
            EreaRpMasterPlayerMonitorFrame:StopAutoRefresh()
        end
    end)

    -- NOTE: CHAT_MSG_ADDON is handled by EreaRpMasterEventHandler (services/event-handler.lua)
    -- which delegates STATUS_RESPONSE back to HandleStatusResponse().

    -- OnUpdate for timeout checking and auto-refresh
    self.timerFrame = CreateFrame("Frame")
    self.timerFrame:SetScript("OnUpdate", function()
        -- Lua 5.0: arg1 is elapsed time
        local elapsed = arg1

        -- Check for pending request timeout
        local pending = EreaRpMasterPlayerMonitorFrame.pendingRequest
        if pending then
            pending.elapsed = (pending.elapsed or 0) + elapsed
            if pending.elapsed >= STATUS_TIMEOUT then
                EreaRpMasterPlayerMonitorFrame:HandleRequestTimeout()
            end
        end

        -- Auto-refresh timer
        if EreaRpMasterPlayerMonitorFrame.autoRefreshEnabled then
            EreaRpMasterPlayerMonitorFrame.autoRefreshTimer = EreaRpMasterPlayerMonitorFrame.autoRefreshTimer + elapsed
            if EreaRpMasterPlayerMonitorFrame.autoRefreshTimer >= AUTO_REFRESH_INTERVAL then
                EreaRpMasterPlayerMonitorFrame.autoRefreshTimer = 0
                if EreaRpMasterPlayerMonitorFrame:IsShown() then
                    EreaRpMasterPlayerMonitorFrame:RefreshPlayerList()
                end
            end
        end
    end)
end

-- ============================================================================
-- RefreshPlayerList - Enumerate group members, rebuild rows, send request
-- ============================================================================
function EreaRpMasterPlayerMonitorFrame:RefreshPlayerList()
    local self = EreaRpMasterPlayerMonitorFrame

    -- Enumerate group members
    local players = {}
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()

    if numRaid > 0 then
        for i = 1, numRaid do
            local name = GetRaidRosterInfo(i)
            if name then
                table.insert(players, name)
            end
        end
    elseif numParty > 0 then
        for i = 1, numParty do
            local name = UnitName("party" .. i)
            if name then
                table.insert(players, name)
            end
        end
        -- Add self
        local selfName = UnitName("player")
        if selfName then
            table.insert(players, selfName)
        end
    else
        -- Solo
        local selfName = UnitName("player")
        if selfName then
            table.insert(players, selfName)
        end
    end

    local playerCount = table.getn(players)  -- Lua 5.0: no # operator

    -- Scroll child width: at least ROW_MIN_WIDTH so icons are never clipped
    local visibleWidth = self.scrollFrame:GetWidth() or 400
    local childWidth = visibleWidth
    if childWidth < ROW_MIN_WIDTH then
        childWidth = ROW_MIN_WIDTH
    end
    self.scrollChild:SetWidth(childWidth)

    -- Hide all existing rows
    for i = 1, table.getn(self.rowFrames) do  -- Lua 5.0: no # operator
        self.rowFrames[i]:Hide()
    end

    -- Create/reuse rows for each player
    for i = 1, playerCount do
        local playerName = players[i]
        local row = self:GetOrCreateRow(i)

        -- Position row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
        row:SetWidth(childWidth)
        row:SetHeight(ROW_HEIGHT)

        -- Get player state
        local ps = EreaRpMaster_PlayerStates[playerName]
        local statusText, statusColor = self:GetSyncStatusInfo(ps)

        -- Color dot
        row.colorDot:SetVertexColor(statusColor.r, statusColor.g, statusColor.b)

        -- Player name
        row.nameText:SetText(playerName)
        row.nameText:SetTextColor(1, 1, 1)

        -- Status text
        row.statusText:SetText(statusText)
        row.statusText:SetTextColor(statusColor.r, statusColor.g, statusColor.b)

        -- Zone and coordinates
        if ps and ps.zone and ps.zone ~= "" then
            row.zoneText:SetText(ps.zone)
            row.zoneText:SetTextColor(0.7, 0.7, 0.7)
            if ps.coordX > 0 or ps.coordY > 0 then
                row.coordsText:SetText(string.format("%.1f, %.1f", ps.coordX, ps.coordY))
            else
                row.coordsText:SetText("")
            end
            row.coordsText:SetTextColor(0.6, 0.6, 0.6)
        else
            row.zoneText:SetText("")
            row.coordsText:SetText("")
        end

        -- Inventory icons
        self:UpdateRowInventory(row, ps and ps.inventory or nil)

        -- Store player name on row
        row.playerName = playerName

        -- Row background
        row:SetBackdropColor(0.1, 0.1, 0.1, 0.5)

        -- Hover effect
        row:SetScript("OnEnter", function()
            this:SetBackdropColor(0.15, 0.15, 0.25, 1)
        end)
        row:SetScript("OnLeave", function()
            this:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
        end)

        row:Show()
    end

    -- Update scroll child height
    local totalHeight = playerCount * ROW_HEIGHT
    if totalHeight < 1 then totalHeight = 1 end
    self.scrollChild:SetHeight(totalHeight)
    self.scrollFrame:UpdateScrollChildRect()

    -- Update status bar
    self.statusText:SetText(playerCount .. " player(s)")

    -- Send status request to group
    self:SendStatusRequest()
end

-- ============================================================================
-- GetOrCreateRow - Row pool with inline inventory icons
-- ============================================================================
function EreaRpMasterPlayerMonitorFrame:GetOrCreateRow(index)
    local self = EreaRpMasterPlayerMonitorFrame

    if self.rowFrames[index] then
        return self.rowFrames[index]
    end

    local rowName = "EreaRpMasterPlayerMonitorRow" .. index
    local row = CreateFrame("Button", rowName, self.scrollChild)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)

    -- Backdrop
    row:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    row:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
    row:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)

    -- Color dot (10x10)
    local colorDot = row:CreateTexture(rowName .. "Dot", "ARTWORK")
    colorDot:SetWidth(10)
    colorDot:SetHeight(10)
    colorDot:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    colorDot:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.colorDot = colorDot

    -- Player name (fixed width)
    local nameText = row:CreateFontString(rowName .. "Name", "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", colorDot, "RIGHT", 4, 0)
    nameText:SetWidth(NAME_WIDTH)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    -- Status text (fixed width)
    local statusTextFs = row:CreateFontString(rowName .. "Status", "OVERLAY", "GameFontNormalSmall")
    statusTextFs:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
    statusTextFs:SetWidth(STATUS_WIDTH)
    statusTextFs:SetJustifyH("LEFT")
    row.statusText = statusTextFs

    -- Zone text (fixed width)
    local zoneText = row:CreateFontString(rowName .. "Zone", "OVERLAY", "GameFontNormalSmall")
    zoneText:SetPoint("LEFT", statusTextFs, "RIGHT", 4, 0)
    zoneText:SetWidth(ZONE_WIDTH)
    zoneText:SetJustifyH("LEFT")
    row.zoneText = zoneText

    -- Coordinates text
    local coordsText = row:CreateFontString(rowName .. "Coords", "OVERLAY", "GameFontNormalSmall")
    coordsText:SetPoint("LEFT", zoneText, "RIGHT", 4, 0)
    coordsText:SetWidth(COORDS_WIDTH)
    coordsText:SetJustifyH("LEFT")
    row.coordsText = coordsText

    -- 16 inventory slots right-aligned (slot 16 at far right, slot 1 leftmost)
    -- Each slot has a button frame (for hover tooltip) + bg texture + icon texture
    row.invSlots = {}
    for s = 1, SLOT_COUNT do
        local slotName = rowName .. "Slot" .. s
        -- Right-to-left offset: slot 16 closest to right edge
        local rightOfs = -SLOT_PAD_RIGHT - (SLOT_COUNT - s) * (SLOT_SIZE + SLOT_SPACING)

        -- Background: dark square, always visible so empty slots are shown
        local bg = row:CreateTexture(slotName .. "Bg", "ARTWORK")
        bg:SetWidth(SLOT_SIZE)
        bg:SetHeight(SLOT_SIZE)
        bg:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        bg:SetVertexColor(0.12, 0.12, 0.12, 1)
        bg:SetPoint("RIGHT", row, "RIGHT", rightOfs, 0)

        -- Icon: item texture, drawn on top of background
        local icon = row:CreateTexture(slotName .. "Icon", "OVERLAY")
        icon:SetWidth(SLOT_SIZE - 2)
        icon:SetHeight(SLOT_SIZE - 2)
        -- Lua 5.0: explicit parent for SetPoint
        icon:SetPoint("CENTER", bg, "CENTER", 0, 0)

        -- Hover button: invisible frame on top for mouse events
        local hoverBtn = CreateFrame("Button", slotName .. "Hover", row)
        hoverBtn:SetWidth(SLOT_SIZE)
        hoverBtn:SetHeight(SLOT_SIZE)
        hoverBtn:SetPoint("CENTER", bg, "CENTER", 0, 0)
        hoverBtn.itemGuid = nil  -- set by UpdateRowInventory

        hoverBtn:SetScript("OnEnter", function()
            if not this.itemGuid or this.itemGuid == "" then return end
            local itemInfo = EreaRpMasterPlayerMonitorFrame:ResolveItemInfo(this.itemGuid)
            if itemInfo then
                GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:AddLine(itemInfo.name or "Unknown", 1, 1, 1)
                if itemInfo.tooltip and itemInfo.tooltip ~= "" then
                    GameTooltip:AddLine(itemInfo.tooltip, 0.7, 0.7, 0.7, true)
                end
                if this.customText and this.customText ~= "" then
                    GameTooltip:AddLine("Text: " .. this.customText, 0.5, 0.8, 1, true)
                end
                if this.customNumber and this.customNumber ~= 0 then
                    GameTooltip:AddLine("Counter: " .. this.customNumber, 1, 0.82, 0)
                end
                GameTooltip:Show()
            end
        end)
        hoverBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row.invSlots[s] = { bg = bg, icon = icon, hoverBtn = hoverBtn }
    end

    self.rowFrames[index] = row
    return row
end

-- ============================================================================
-- UpdateRowInventory - Set the 16 inline icon textures on a row
-- ============================================================================
function EreaRpMasterPlayerMonitorFrame:UpdateRowInventory(row, inventory)
    local self = EreaRpMasterPlayerMonitorFrame
    for s = 1, SLOT_COUNT do
        local slot = row.invSlots[s]
        if not inventory then
            -- No data yet: empty slots (bg still visible)
            slot.icon:SetTexture(nil)
            slot.hoverBtn.itemGuid = nil
            slot.hoverBtn.customText = nil
            slot.hoverBtn.customNumber = nil
        else
            local slotData = inventory[s]
            local itemGuid = slotData and slotData.guid or ""
            if itemGuid ~= "" then
                local itemIcon = self:ResolveItemIcon(itemGuid)
                if itemIcon then
                    slot.icon:SetTexture(itemIcon)
                else
                    slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end
                slot.hoverBtn.itemGuid = itemGuid
                slot.hoverBtn.customText = slotData.customText or ""
                slot.hoverBtn.customNumber = slotData.customNumber or 0
            else
                -- Empty slot
                slot.icon:SetTexture(nil)
                slot.hoverBtn.itemGuid = nil
                slot.hoverBtn.customText = nil
                slot.hoverBtn.customNumber = nil
            end
        end
    end
end

-- ============================================================================
-- ResolveItemIcon - Look up item icon from committed database by GUID
-- ============================================================================
function EreaRpMasterPlayerMonitorFrame:ResolveItemIcon(guid)
    if not guid or guid == "" then return nil end
    if not EreaRpMasterDB or not EreaRpMasterDB.committedDatabase then return nil end

    local items = EreaRpMasterDB.committedDatabase.items
    if not items then return nil end

    -- Items keyed by integer ID, scan for matching GUID
    for id, item in pairs(items) do
        if item.guid == guid then
            return item.icon
        end
    end

    return nil
end

-- ============================================================================
-- ResolveItemInfo - Look up item name and tooltip from committed database by GUID
-- ============================================================================
function EreaRpMasterPlayerMonitorFrame:ResolveItemInfo(guid)
    if not guid or guid == "" then return nil end
    if not EreaRpMasterDB or not EreaRpMasterDB.committedDatabase then return nil end

    local items = EreaRpMasterDB.committedDatabase.items
    if not items then return nil end

    for id, item in pairs(items) do
        if item.guid == guid then
            return item
        end
    end

    return nil
end

-- ============================================================================
-- SendStatusRequest - Send STATUS_REQUEST to group
-- ============================================================================
function EreaRpMasterPlayerMonitorFrame:SendStatusRequest()
    local self = EreaRpMasterPlayerMonitorFrame

    local requestId = tostring(GetTime()) .. tostring(math.random(1000, 9999))

    self.pendingRequest = {
        requestId = requestId,
        sentTime = GetTime(),
        elapsed = 0,
        responded = {}
    }

    local message = messaging.MESSAGE_TYPES.STATUS_REQUEST ..
        messaging.MESSAGE_DELIMITER .. requestId

    local distribution = messaging.GetDistribution()
    SendAddonMessage(messaging.ADDON_PREFIX, message, distribution)

    self.statusText:SetText("Requesting status...")
end

-- ============================================================================
-- HandleStatusResponse - Process STATUS_RESPONSE from a player
-- ============================================================================
-- Player sends: STATUS_RESPONSE^requestId^version^syncStateEncoded^inventoryEncoded^locationEncoded
-- Where:
--   syncStateEncoded = Base64 of "dbId^dbName^version^checksum^lastSyncTime"
--   inventoryEncoded = Base64 of "slot1^slot2^...^slot16"
--     Each slot: "guid~base64(customText)~customNumber" or just "guid" (backward compat)
--   locationEncoded  = Base64 of "zoneName^coordX^coordY" (optional, backward compat)
function EreaRpMasterPlayerMonitorFrame:HandleStatusResponse(sender, parts)
    local self = EreaRpMasterPlayerMonitorFrame

    local requestId         = parts[2] or ""
    local version           = parts[3] or ""
    local syncStateEncoded  = parts[4] or ""
    local inventoryEncoded  = parts[5] or ""
    local locationEncoded   = parts[6] or ""

    -- Decode sync state: "dbId^dbName^version^checksum^lastSyncTime"
    local syncChecksum = ""
    if syncStateEncoded ~= "" then
        local syncStateStr = encoding.Base64Decode(syncStateEncoded)
        if syncStateStr and syncStateStr ~= "" then
            -- Parse caret-delimited fields: dbId(1) ^ dbName(2) ^ version(3) ^ checksum(4) ^ lastSyncTime(5)
            local syncParts = {}
            for field in string.gfind(syncStateStr, "([^^]*)%^?") do
                table.insert(syncParts, field)
            end
            syncChecksum = syncParts[4] or ""
        end
    end

    -- Decode inventory: each slot is "guid~base64(customText)~customNumber" or just "guid"
    local inventory = {}
    if inventoryEncoded ~= "" then
        local inventoryStr = encoding.Base64Decode(inventoryEncoded)
        if inventoryStr and inventoryStr ~= "" then
            local idx = 0
            for field in string.gfind(inventoryStr, "([^^]*)%^?") do
                idx = idx + 1
                if idx <= SLOT_COUNT then
                    -- Parse slot: check for ~ sub-delimiter
                    local tildePos = string.find(field, "~", 1, true)
                    if tildePos then
                        local guid = string.sub(field, 1, tildePos - 1)
                        local rest = string.sub(field, tildePos + 1)
                        local tilde2 = string.find(rest, "~", 1, true)
                        local customText = ""
                        local customNumber = 0
                        if tilde2 then
                            local ct64 = string.sub(rest, 1, tilde2 - 1)
                            customText = encoding.Base64Decode(ct64) or ""
                            customNumber = tonumber(string.sub(rest, tilde2 + 1)) or 0
                        end
                        inventory[idx] = { guid = guid, customText = customText, customNumber = customNumber }
                    elseif field ~= "" then
                        -- Backward compat: plain GUID only
                        inventory[idx] = { guid = field, customText = "", customNumber = 0 }
                    else
                        inventory[idx] = { guid = "", customText = "", customNumber = 0 }
                    end
                end
            end
        end
    end
    -- Fill remaining slots
    for i = table.getn(inventory) + 1, SLOT_COUNT do  -- Lua 5.0: no # operator
        inventory[i] = { guid = "", customText = "", customNumber = 0 }
    end

    -- Decode location: "zoneName^coordX^coordY"
    local zone = ""
    local coordX = 0
    local coordY = 0
    if locationEncoded ~= "" then
        local locationStr = encoding.Base64Decode(locationEncoded)
        if locationStr and locationStr ~= "" then
            local locParts = {}
            -- Lua 5.0: no string.gmatch
            for field in string.gfind(locationStr, "([^^]*)%^?") do
                table.insert(locParts, field)
            end
            zone = locParts[1] or ""
            coordX = tonumber(locParts[2]) or 0
            coordY = tonumber(locParts[3]) or 0
        end
    end

    -- Update player state
    EreaRpMaster_PlayerStates[sender] = {
        version = version,
        syncChecksum = syncChecksum,
        inventory = inventory,
        lastResponse = GetTime(),
        hasAddon = true,
        zone = zone,
        coordX = coordX,
        coordY = coordY
    }

    -- Mark as responded
    if self.pendingRequest and self.pendingRequest.requestId == requestId then
        self.pendingRequest.responded[sender] = true
    end

    -- Refresh that player's row
    self:RefreshPlayerRow(sender)
end

-- ============================================================================
-- HandleRequestTimeout - Mark non-responders after timeout
-- ============================================================================
function EreaRpMasterPlayerMonitorFrame:HandleRequestTimeout()
    local self = EreaRpMasterPlayerMonitorFrame

    if not self.pendingRequest then return end

    local responded = self.pendingRequest.responded

    for i = 1, table.getn(self.rowFrames) do  -- Lua 5.0: no # operator
        local row = self.rowFrames[i]
        if row:IsShown() and row.playerName then
            if not responded[row.playerName] then
                local ps = EreaRpMaster_PlayerStates[row.playerName]
                if not ps then
                    EreaRpMaster_PlayerStates[row.playerName] = {
                        hasAddon = false,
                        lastResponse = nil
                    }
                else
                    -- Only mark as no addon if they've never responded
                    if not ps.lastResponse then
                        ps.hasAddon = false
                    end
                end
                self:RefreshPlayerRow(row.playerName)
            end
        end
    end

    self.pendingRequest = nil

    -- Update status bar with addon count
    local playerCount = 0
    local addonCount = 0
    for i = 1, table.getn(self.rowFrames) do  -- Lua 5.0: no # operator
        local row = self.rowFrames[i]
        if row:IsShown() then
            playerCount = playerCount + 1
            local ps = EreaRpMaster_PlayerStates[row.playerName]
            if ps and ps.hasAddon then
                addonCount = addonCount + 1
            end
        end
    end
    self.statusText:SetText(playerCount .. " player(s), " .. addonCount .. " with addon")
end

-- ============================================================================
-- RefreshPlayerRow - Update a single player's row (status + inventory)
-- ============================================================================
function EreaRpMasterPlayerMonitorFrame:RefreshPlayerRow(playerName)
    local self = EreaRpMasterPlayerMonitorFrame

    for i = 1, table.getn(self.rowFrames) do  -- Lua 5.0: no # operator
        local row = self.rowFrames[i]
        if row:IsShown() and row.playerName == playerName then
            local ps = EreaRpMaster_PlayerStates[playerName]
            local statusText, statusColor = self:GetSyncStatusInfo(ps)

            row.colorDot:SetVertexColor(statusColor.r, statusColor.g, statusColor.b)
            row.statusText:SetText(statusText)
            row.statusText:SetTextColor(statusColor.r, statusColor.g, statusColor.b)

            -- Zone and coordinates
            if ps and ps.zone and ps.zone ~= "" then
                row.zoneText:SetText(ps.zone)
                row.zoneText:SetTextColor(0.7, 0.7, 0.7)
                if ps.coordX > 0 or ps.coordY > 0 then
                    row.coordsText:SetText(string.format("%.1f, %.1f", ps.coordX, ps.coordY))
                else
                    row.coordsText:SetText("")
                end
                row.coordsText:SetTextColor(0.6, 0.6, 0.6)
            else
                row.zoneText:SetText("")
                row.coordsText:SetText("")
            end

            self:UpdateRowInventory(row, ps and ps.inventory or nil)
            break
        end
    end
end

-- ============================================================================
-- GetSyncStatusInfo - Returns status text and color for a player state
-- ============================================================================
function EreaRpMasterPlayerMonitorFrame:GetSyncStatusInfo(ps)
    local gray = { r = 0.5, g = 0.5, b = 0.5 }
    local green = { r = 0.2, g = 0.8, b = 0.2 }
    local orange = { r = 1, g = 0.6, b = 0 }

    if not ps then
        return "Unknown", gray
    end

    if not ps.hasAddon then
        return "No addon", gray
    end

    if not ps.syncChecksum or ps.syncChecksum == "" then
        return "Unknown", gray
    end

    local localChecksum = ""
    if EreaRpMasterDB and EreaRpMasterDB.committedDatabase
        and EreaRpMasterDB.committedDatabase.metadata then
        localChecksum = EreaRpMasterDB.committedDatabase.metadata.checksum or ""
    end

    if localChecksum == "" then
        return "No DB", gray
    end

    if ps.syncChecksum == localChecksum then
        return "Synced", green
    else
        return "Out of sync", orange
    end
end

-- ============================================================================
-- StartAutoRefresh / StopAutoRefresh
-- ============================================================================
function EreaRpMasterPlayerMonitorFrame:StartAutoRefresh()
    local self = EreaRpMasterPlayerMonitorFrame
    self.autoRefreshTimer = 0
    self.autoRefreshEnabled = true
end

function EreaRpMasterPlayerMonitorFrame:StopAutoRefresh()
    local self = EreaRpMasterPlayerMonitorFrame
    self.autoRefreshEnabled = false
    self.autoRefreshTimer = 0
end
