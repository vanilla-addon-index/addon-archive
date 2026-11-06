-- PorkNotes v0.4.1
-- by MrToffee and porkfriedlumpia

PorkNotes = PorkNotes or {}

local PORKNOTES_VERSION = "0.4.1"
local realm = GetRealmName()

-- Debug toggle
PorkNotes.ChatDebug = false

-- Sync throttle: tracks last sync timestamp from each player
-- Format: { [playerName] = lastSyncTimestamp }
-- Used to prevent spam cycles from rapid repeated syncs
local syncThrottle = {}
local SYNC_THROTTLE_WINDOW = 300  -- 5 minutes in seconds

-- Event registration helper
local function RegisterEvent(event, func)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent(event)
    frame:SetScript("OnEvent", func)
end

-- Notes data functions
PorkNotes.GetAllNotes = function()
    if PorkNotes_Data and PorkNotes_Data[realm] then
        return PorkNotes_Data[realm].notes
    end
    return nil
end

PorkNotes.GetPlayerNote = function(playername)
    if playername and PorkNotes_Data and PorkNotes_Data[realm] and PorkNotes_Data[realm].notes then
        return PorkNotes_Data[realm].notes[playername]
    end
    return nil
end

PorkNotes.SetPlayerNote = function(playername, text)
    if not playername or not PorkNotes_Data or not PorkNotes_Data[realm] or not PorkNotes_Data[realm].notes then return end

    if text and text ~= "" then
        if not PorkNotes_Data[realm].notes[playername] then
            -- New note — no history to record
            PorkNotes_Data[realm].notes[playername] = {
                created = time(),
                createdBy = UnitName("player"),
                createdAtZone = GetRealZoneText(),
                history = {}
            }
        else
            -- Existing note — archive current text to history before overwriting
            local existing = PorkNotes_Data[realm].notes[playername]
            local limit = PorkNotes.GetSetting("HistoryLimit", -1)
            if limit ~= 0 and existing.text and existing.text ~= "" then
                existing.history = existing.history or {}
                table.insert(existing.history, {
                    text     = existing.text,
                    authorBy = existing.updatedBy or existing.createdBy,
                    authorAt = existing.updated or existing.created,
                    source   = "edit"
                })
                -- Prune history if limit is set
                if limit > 0 then
                    while table.getn(existing.history) > limit do
                        table.remove(existing.history, 1)
                    end
                end
            end
        end
        PorkNotes_Data[realm].notes[playername].text = text
        PorkNotes_Data[realm].notes[playername].updated = time()
        PorkNotes_Data[realm].notes[playername].updatedBy = UnitName("player")
        PorkNotes_Data[realm].notes[playername].updatedAtZone = GetRealZoneText()
    else
        PorkNotes_Data[realm].notes[playername] = nil
    end
end

-- Settings helper
PorkNotes.GetSetting = function(setting, defaultValue)
    if not PorkNotes_Settings then return defaultValue end
    if PorkNotes_Settings[setting] == nil then return defaultValue end
    return PorkNotes_Settings[setting]
end

PorkNotes.SetSetting = function(setting, value)
    PorkNotes_Settings[setting] = value
end

-- PHASE 2: Validate incoming sync message fields
local function ValidateSyncMessage(playername, noteText, createdBy, createdAt, createdZone, updatedBy, updatedAt)
    -- Validate playername: 1-12 characters, alphanumeric only
    if not playername or string.len(playername) < 1 or string.len(playername) > 12 then
        if PorkNotes.ChatDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PorkNotes Debug]|r Invalid playername length: " .. tostring(playername))
        end
        return false
    end
    if not string.match(playername, "^[A-Za-z]+$") then
        if PorkNotes.ChatDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PorkNotes Debug]|r Invalid playername format (non-alphanumeric): " .. tostring(playername))
        end
        return false
    end

    -- Validate note text: ≤150 characters
    if noteText and string.len(noteText) > 150 then
        if PorkNotes.ChatDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PorkNotes Debug]|r Note text exceeds 150 chars: " .. string.len(noteText))
        end
        return false
    end

    -- Validate timestamps: must be integers, reasonable range (past 10 years, not future)
    local now = time()
    local tenYearsAgo = now - (365 * 24 * 60 * 60 * 10)
    if createdAt and (createdAt < tenYearsAgo or createdAt > now) then
        if PorkNotes.ChatDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PorkNotes Debug]|r Invalid createdAt timestamp: " .. tostring(createdAt))
        end
        return false
    end
    if updatedAt and (updatedAt < tenYearsAgo or updatedAt > now) then
        if PorkNotes.ChatDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PorkNotes Debug]|r Invalid updatedAt timestamp: " .. tostring(updatedAt))
        end
        return false
    end

    -- Validate creator/updater names: alphanumeric format
    if createdBy and not string.match(createdBy, "^[A-Za-z]*$") then
        if PorkNotes.ChatDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PorkNotes Debug]|r Invalid createdBy format: " .. tostring(createdBy))
        end
        return false
    end
    if updatedBy and not string.match(updatedBy, "^[A-Za-z]*$") then
        if PorkNotes.ChatDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PorkNotes Debug]|r Invalid updatedBy format: " .. tostring(updatedBy))
        end
        return false
    end

    return true
end

-- PHASE 3: Throttle management
local function CheckAndUpdateThrottle(playerName)
    local now = time()
    local lastSync = syncThrottle[playerName]
    
    -- Record this sync
    syncThrottle[playerName] = now
    
    -- Return true if this is a throttled sync (within window of last sync)
    if lastSync and (now - lastSync) < SYNC_THROTTLE_WINDOW then
        return true
    end
    return false
end

-- Restore throttle table from settings on load
local function RestoreThrottleTable()
    local saved = PorkNotes.GetSetting("SyncThrottle", nil)
    if saved then
        syncThrottle = saved
    end
end

-- Persist throttle table to settings
local function SaveThrottleTable()
    PorkNotes.SetSetting("SyncThrottle", syncThrottle)
end

-- CaramelNotes import
PorkNotes.ImportFromCaramelNotes = function()
    if not CaramelNotes_Data then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r No CaramelNotes data found.")
        return
    end
    local imported = 0
    local skipped = 0
    for realmName, realmData in pairs(CaramelNotes_Data) do
        if realmData.notes then
            PorkNotes_Data[realmName] = PorkNotes_Data[realmName] or {}
            PorkNotes_Data[realmName].notes = PorkNotes_Data[realmName].notes or {}
            for playername, note in pairs(realmData.notes) do
                if not PorkNotes_Data[realmName].notes[playername] then
                    PorkNotes_Data[realmName].notes[playername] = note
                    imported = imported + 1
                else
                    skipped = skipped + 1
                end
            end
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r Import complete: " .. imported .. " notes imported, " .. skipped .. " skipped (already exist).")
    PorkNotes.UpdateNotesFrame()
end

-- Check if PorkNotes has any notes across all realms
local function HasAnyNotes()
    if not PorkNotes_Data then return false end
    for _, realmData in pairs(PorkNotes_Data) do
        if realmData.notes then
            for _ in pairs(realmData.notes) do
                return true
            end
        end
    end
    return false
end

-- Addon loaded
local function OnAddonLoaded()
    if arg1 == "PorkNotes" then
        PorkNotes_Data = PorkNotes_Data or {}
        PorkNotes_Data[realm] = PorkNotes_Data[realm] or {}
        PorkNotes_Data[realm].notes = PorkNotes_Data[realm].notes or {}
        PorkNotes_Settings = PorkNotes_Settings or {}

        -- Restore throttle table from settings
        RestoreThrottleTable()

        -- Prompt for CaramelNotes import if data exists and PorkNotes has no notes yet
        if CaramelNotes_Data and not HasAnyNotes() then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r CaramelNotes data detected. Type |cffffcc00/pn import|r to import your notes.")
        end

        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r v" .. PORKNOTES_VERSION .. " loaded. Type |cffffcc00/pn|r to open.")

        -- Restore any pending sync reviews from last session
        local saved = PorkNotes.GetSetting("PendingSyncReviews", nil)
        if saved and table.getn(saved) > 0 then
            pendingSyncReviews = saved
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r You have |cffffcc00" .. table.getn(pendingSyncReviews) .. "|r pending sync review(s). Click a |cffffcc00[Review]|r link or use |cffffcc00/pn|r to review.")
            TryShowSyncReview()
        end
    end
end

-- Item ref handler
local originalSetItemRef = SetItemRef
function SetItemRef(link, text, button)
    if string.sub(link, 1, 10) == "porknotes:" then
        PorkNotes.ShowNoteDetailFrame(string.sub(link, 11))
    elseif string.sub(link, 1, 17) == "porknotes_review:" then
        if PorkNotes.ShowSyncReviewFrame then
            PorkNotes.ShowSyncReviewFrame()
        end
    else
        originalSetItemRef(link, text, button)
    end
end

-- Mouseover tooltip
local lastMouseoverTooltipNote = nil

-- Reset tracker when tooltip is hidden so re-hovering the same player works
GameTooltip:HookScript("OnHide", function()
    lastMouseoverTooltipNote = nil
end)

local function OnUpdateMouseoverUnit()
    if not PorkNotes.GetSetting("ShowNotesInTooltips", true) then
        lastMouseoverTooltipNote = nil
        return
    end
    local unit = "mouseover"
    if not UnitIsPlayer(unit) then
        lastMouseoverTooltipNote = nil
        return
    end
    if not GameTooltip:IsShown() then
        lastMouseoverTooltipNote = nil
        return
    end
    local name = UnitName(unit)
    local note = PorkNotes.GetPlayerNote(name)
    if not note then
        lastMouseoverTooltipNote = nil
        return
    end
    if lastMouseoverTooltipNote == name then return end
    lastMouseoverTooltipNote = name
    GameTooltip:AddLine(note.text, 1, 1, 0)
    GameTooltip:Show()
end

-- UnitPopup menus
local function RegisterUnitPopupMenus()
    if UnitPopupButtons["PORKNOTES_EDIT_NOTE"] then return end
    UnitPopupButtons["PORKNOTES_EDIT_NOTE"] = { text = "Edit note", dist = 0 }
    local menus = { "PLAYER", "FRIEND", "PARTY", "RAID" }
    for _, menu in ipairs(menus) do
        local atIndex = 1
        for index, value in ipairs(UnitPopupMenus[menu]) do
            if value == "CANCEL" then atIndex = index break end
        end
        table.insert(UnitPopupMenus[menu], atIndex, "PORKNOTES_EDIT_NOTE")
    end
end

-- Hook unit popup
hooksecurefunc("UnitPopup_OnClick", function()
    local button = this
    if not button then return end
    if button.value == "PORKNOTES_EDIT_NOTE" then
        local menu = UIDROPDOWNMENU_INIT_MENU
        if type(menu) == "string" then menu = _G[menu] end
        local playername = menu and menu.name
        if playername then PorkNotes.ShowNoteDetailFrame(playername) end
    end
end)

-- Slash commands
local function RegisterCommands()
    SLASH_PORKNOTES1 = "/porknotes"
    SLASH_PORKNOTES2 = "/pn"
    SlashCmdList["PORKNOTES"] = function(msg)
        if string.lower(msg) == "import" then
            PorkNotes.ImportFromCaramelNotes()
        else
            PorkNotes.ShowNotesFrame()
        end
    end

    SLASH_PORKNOTESDEBUG1 = "/pndebug"
    SlashCmdList["PORKNOTESDEBUG"] = function(msg)
        PorkNotes.ChatDebug = not PorkNotes.ChatDebug
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PorkNotes]|r Chat debug: " .. tostring(PorkNotes.ChatDebug))
    end
end

-- Chat alert routing
local function SendChatFrame1(alertText)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(alertText)
    end
end

-- Build chat alert metadata suffix based on settings
local function BuildAlertMetadata(note)
    local showCreatedBy = PorkNotes.GetSetting("ChatShowCreatedBy", false)
    local showTimestamp = PorkNotes.GetSetting("ChatShowTimestamp", false)

    local meta = {}
    if showCreatedBy and note.createdBy then
        table.insert(meta, "by " .. note.createdBy)
    end
    if showTimestamp and note.created then
        table.insert(meta, date("%Y-%m-%d", note.created))
    end

    if table.getn(meta) > 0 then
        return " |cff888888(" .. table.concat(meta, ", ") .. ")|r"
    end
    return ""
end

-- Chat alerts
local function RegisterChatAlerts()
    local frame = CreateFrame("Frame")

    frame:SetScript("OnEvent", function()
        local msg = arg1
        local author = arg2
        local channelID = tonumber(arg7) or 0
        local channelName = tostring(arg9 or "")

        if PorkNotes.ChatDebug then
            local skipDebug = false
            if event == "CHAT_MSG_CHANNEL" and channelID == 0 then
                local lname = string.lower(channelName)
                if lname == "ttrp" or lname == "lft" then
                    skipDebug = true
                end
            end
            if not skipDebug then
                local argsText = ""
                for i = 1, 9 do
                    local val = _G["arg" .. i]
                    if val == nil then val = "<nil>" end
                    argsText = argsText .. " arg" .. i .. "=" .. tostring(val)
                end
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PorkNotes Debug]|r Event=" .. tostring(event) .. argsText)
            end
        end

        if not msg or not author then return end
        if not PorkNotes.GetSetting("ShowNotesInChat", true) then return end

        -- Only filter channelID==0 for actual channel messages
        -- (non-channel events like SAY/PARTY/WHISPER have arg7==nil which resolves to 0)
        if event == "CHAT_MSG_CHANNEL" and channelID == 0 then return end

        local note = PorkNotes.GetPlayerNote(author)
        if not note then return end

        local alertText = "|cff00ccff[PorkNotes]|r |Hporknotes:" .. author .. "|h|cffffcc00[" .. author .. "]|h|r|cffaaaaaa: " .. note.text .. "|r" .. BuildAlertMetadata(note)

        -- Route World and LookingForGroup channels to user-configured chat frame
        if event == "CHAT_MSG_CHANNEL" then
            local lname = string.lower(channelName)
            if string.find(lname, "world") or string.find(lname, "lookingforgroup") then
                local frameIndex = PorkNotes.GetSetting("WorldChatFrame", 3)
                local targetFrame = _G["ChatFrame" .. frameIndex]
                if targetFrame then
                    targetFrame:AddMessage(alertText)
                else
                    SendChatFrame1(alertText)
                end
                return
            end
        end
        SendChatFrame1(alertText)
    end)

    local events = {
        "CHAT_MSG_SAY",
        "CHAT_MSG_YELL",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_GUILD",
        "CHAT_MSG_WHISPER",
        "CHAT_MSG_CHANNEL"
    }

    for _, e in ipairs(events) do
        frame:RegisterEvent(e)
    end
end

-- Sync system
local SYNC_PREFIX = "PORKNOTES"
local SYNC_THROTTLE = 0.15
local syncQueue = {}
local syncTimer = 0
local pendingSyncReviews = {}

-- Encode/decode pipes for safe transmission
local function EncodeNote(text)
    if not text then return "" end
    return string.gsub(text, "|", "PNPIPE")
end

local function DecodeNote(text)
    if not text then return "" end
    return string.gsub(text, "PNPIPE", "|")
end

-- Build a sync message for a single note
local function BuildSyncMessage(playername, note)
    return "SYNC\t" .. playername
        .. "\t" .. EncodeNote(note.text or "")
        .. "\t" .. (note.createdBy or "")
        .. "\t" .. tostring(note.created or 0)
        .. "\t" .. EncodeNote(note.createdAtZone or "")
        .. "\t" .. (note.updatedBy or "")
        .. "\t" .. tostring(note.updated or 0)
end

-- Queue a note for sending
local function QueueSyncMessage(msg, channel)
    table.insert(syncQueue, { msg = msg, channel = channel })
end

-- Process sync queue with throttle via OnUpdate
local syncFrame = CreateFrame("Frame")
syncFrame:SetScript("OnUpdate", function()
    if table.getn(syncQueue) == 0 then return end
    syncTimer = syncTimer + arg1
    if syncTimer < SYNC_THROTTLE then return end
    syncTimer = 0
    local item = syncQueue[1]
    table.remove(syncQueue, 1)
    SendAddonMessage(SYNC_PREFIX, item.msg, item.channel)
end)

-- Save pending reviews to settings so they survive reloads
local function SavePendingReviews()
    PorkNotes.SetSetting("PendingSyncReviews", pendingSyncReviews)
end

-- Handle an incoming sync message
-- Try to show sync review frame — respects setting and combat state
local function TryShowSyncReview()
    if not PorkNotes.GetSetting("SyncAutoPopup", false) then return end
    if UnitAffectingCombat("player") then return end
    if table.getn(pendingSyncReviews) == 0 then return end
    if PorkNotes.ShowSyncReviewFrame then
        PorkNotes.ShowSyncReviewFrame()
    end
end

local function HandleIncomingSync(msg, sender)
    -- PHASE 1: Check if sync receiving is enabled
    if not PorkNotes.GetSetting("SyncEnabled", true) then
        if PorkNotes.ChatDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PorkNotes Debug]|r Sync disabled by user. Ignoring sync from " .. sender)
        end
        return
    end

    local _, _, playername, encodedText, createdBy, createdAtStr, encodedZone, updatedBy, updatedAtStr
        = string.find(msg, "([^\t]+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)")

    if not playername then return end

    local noteText    = DecodeNote(encodedText)
    local createdAt   = tonumber(createdAtStr) or 0
    local createdZone = DecodeNote(encodedZone)
    local updatedAt   = tonumber(updatedAtStr) or 0

    -- PHASE 2: Validate all fields
    if not ValidateSyncMessage(playername, noteText, createdBy, createdAt, createdZone, updatedBy, updatedAt) then
        if PorkNotes.ChatDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PorkNotes Debug]|r Rejected malformed sync from " .. sender .. " for player " .. playername)
        end
        return
    end

    local incomingNote = {
        text          = noteText,
        createdBy     = createdBy,
        created       = createdAt,
        createdAtZone = createdZone,
        updatedBy     = updatedBy,
        updated       = updatedAt,
        history       = {}
    }

    local existing     = PorkNotes.GetPlayerNote(playername)
    local localTime    = existing and (existing.updated or existing.created or 0) or 0
    local incomingTime = updatedAt or createdAt or 0
    local autoAccept   = PorkNotes.GetSetting("SyncAutoAccept", false)

    -- PHASE 3: Apply throttle and log if applicable
    local isThrottled = CheckAndUpdateThrottle(sender)
    SaveThrottleTable()

    -- Case: timestamps identical — always silently ignore, nothing to review
    if existing and incomingTime == localTime then return end

    -- If auto-accept is off, queue everything for manual review (throttled or not)
    if not autoAccept then
        table.insert(pendingSyncReviews, {
            playername   = playername,
            senderName   = sender,
            incomingNote = incomingNote,
            localNote    = existing,
            throttled    = isThrottled  -- Track throttle state in review
        })
        SavePendingReviews()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r Note for |cffffcc00" .. playername .. "|r received from " .. sender .. ". |Hporknotes_review:" .. playername .. "|h|cffffcc00[Review]|h|r")
        TryShowSyncReview()
        return
    end

    -- Auto-accept mode with throttle: if throttled and timestamp is old/equal, silently ignore
    if isThrottled and incomingTime <= localTime then
        if PorkNotes.ChatDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[PorkNotes Debug]|r Throttled sync from " .. sender .. " for " .. playername .. " ignored (older/equal timestamp)")
        end
        return
    end

    -- Auto-accept mode: apply logic based on timestamp
    -- Case 1: no local note — apply immediately with sync history entry
    if not existing then
        incomingNote.history = incomingNote.history or {}
        table.insert(incomingNote.history, {
            text     = incomingNote.text,
            authorBy = incomingNote.updatedBy or incomingNote.createdBy,
            authorAt = incomingNote.updated or incomingNote.created,
            editedBy = sender,
            source   = "sync"
        })
        PorkNotes_Data[realm].notes[playername] = incomingNote
        PorkNotes.UpdateNotesFrame()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r Note for |cffffcc00" .. playername .. "|r received from " .. sender .. " and saved.")
        return
    end

    -- Case 2: incoming is newer — apply immediately
    if incomingTime > localTime then
        existing.history = existing.history or {}
        if existing.text and existing.text ~= "" then
            table.insert(existing.history, {
                text     = existing.text,
                authorBy = existing.updatedBy or existing.createdBy,
                authorAt = existing.updated or existing.created,
                editedBy = sender,
                source   = "sync"
            })
        end
        existing.text          = noteText
        existing.updatedBy     = updatedBy
        existing.updated       = updatedAt
        existing.updatedAtZone = createdZone
        PorkNotes.UpdateNotesFrame()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r Note for |cffffcc00" .. playername .. "|r updated from " .. sender .. " (newer version).")
        return
    end

    -- Case 3: incoming is older — queue for review even in auto-accept mode
    table.insert(pendingSyncReviews, {
        playername   = playername,
        senderName   = sender,
        incomingNote = incomingNote,
        localNote    = existing
    })
    SavePendingReviews()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r " .. sender .. " sent an older note for |cffffcc00" .. playername .. "|r. |Hporknotes_review:" .. playername .. "|h|cffffcc00[Review]|h|r")
    TryShowSyncReview()
end

-- Register CHAT_MSG_ADDON listener
local function RegisterSyncListener()
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function()
        if event == "PLAYER_REGEN_ENABLED" then
            -- Left combat — show review frame if setting is on and reviews pending
            TryShowSyncReview()
            return
        end
        if arg1 ~= SYNC_PREFIX then return end
        local msg    = arg2
        local sender = arg4
        if not msg or not sender then return end
        local _, _, msgType = string.find(msg, "^([^\t]+)")
        if msgType == "SYNC" then
            local rest = string.sub(msg, 6)
            HandleIncomingSync(rest, sender)
        end
    end)
end

-- Public sync API
PorkNotes.SyncNote = function(playername, channel)
    local note = PorkNotes.GetPlayerNote(playername)
    if not note then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r No note found for " .. playername .. ".")
        return
    end
    local msg = BuildSyncMessage(playername, note)
    QueueSyncMessage(msg, channel)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r Sharing note for |cffffcc00" .. playername .. "|r to " .. channel .. ".")
end

PorkNotes.SyncAll = function(channel)
    local notes = PorkNotes.GetAllNotes()
    if not notes then return end
    local count = 0
    for playername, note in pairs(notes) do
        local msg = BuildSyncMessage(playername, note)
        QueueSyncMessage(msg, channel)
        count = count + 1
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r Queued " .. count .. " notes to sync to " .. channel .. ".")
end



PorkNotes.GetPendingSyncReviews = function()
    return pendingSyncReviews
end

PorkNotes.ResolveSyncReview = function(index, keepIncoming)
    local review = pendingSyncReviews[index]
    if not review then return end
    if keepIncoming then
        local existing = PorkNotes.GetPlayerNote(review.playername)
        local incoming = review.incomingNote
        if existing then
            -- Archive existing note to history before overwriting
            existing.history = existing.history or {}
            if existing.text and existing.text ~= "" then
                table.insert(existing.history, {
                    text     = existing.text,
                    authorBy = existing.updatedBy or existing.createdBy,
                    authorAt = existing.updated or existing.created,
                    editedBy = review.senderName or "unknown",
                    source   = "sync"
                })
            end
            existing.text          = incoming.text
            existing.updatedBy     = incoming.updatedBy or incoming.createdBy
            existing.updated       = incoming.updated or incoming.created
            existing.updatedAtZone = incoming.createdAtZone
        else
            -- Brand new note — add a history entry recording the sync receipt
            incoming.history = incoming.history or {}
            table.insert(incoming.history, {
                text     = incoming.text,
                authorBy = incoming.updatedBy or incoming.createdBy,
                authorAt = incoming.updated or incoming.created,
                editedBy = review.senderName or "unknown",
                source   = "sync"
            })
            PorkNotes_Data[realm].notes[review.playername] = incoming
        end
        PorkNotes.UpdateNotesFrame()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r Accepted incoming note for |cffffcc00" .. review.playername .. "|r from " .. (review.senderName or "unknown") .. ".")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[PorkNotes]|r Kept local note for |cffffcc00" .. review.playername .. "|r.")
    end
    table.remove(pendingSyncReviews, index)
    SavePendingReviews()
end

-- Minimap button
local function RegisterMinimapButton()
    local minimapButton = CreateFrame("Button", "PorkNotes_MinimapButton", Minimap)
    minimapButton:SetWidth(30)
    minimapButton:SetHeight(30)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 20, -20)
    minimapButton:SetNormalTexture("Interface\\AddOns\\PorkNotes\\Textures\\porknotes")
    minimapButton:SetPushedTexture("Interface\\AddOns\\PorkNotes\\Textures\\porknotes")
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(50)
    border:SetHeight(50)
    border:SetPoint("CENTER", minimapButton, "CENTER", 10, -10)

    if PorkNotes.GetSetting("ShowMinimapButton", true) then
        minimapButton:Show()
    else
        minimapButton:Hide()
    end

    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            PorkNotes.ShowNotesFrame()
        else
            PorkNotes.ShowSettingsFrame()
        end
    end)

    minimapButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(minimapButton, "ANCHOR_LEFT")
        GameTooltip:SetText("PorkNotes")
        GameTooltip:AddLine("Left click: Open notes", 1, 1, 1)
        GameTooltip:AddLine("Right click: Settings", 1, 1, 1)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    PorkNotes.SetMinimapButtonVisible = function(visible)
        if visible then
            minimapButton:Show()
        else
            minimapButton:Hide()
        end
    end
end

-- Register events
RegisterEvent("ADDON_LOADED", OnAddonLoaded)
RegisterEvent("UPDATE_MOUSEOVER_UNIT", OnUpdateMouseoverUnit)
RegisterChatAlerts()
RegisterCommands()
RegisterUnitPopupMenus()
RegisterSyncListener()
RegisterMinimapButton()
