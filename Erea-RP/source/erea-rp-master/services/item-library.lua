-- ============================================================================
-- item-library.lua - Item Library Service
-- ============================================================================
-- PURPOSE: Business logic facade over EreaRpLibraries:ObjectDatabase()
--          Manages item CRUD, commit/sync, and dirty-state tracking.
--
-- METHODS:
--   EreaRpMasterItemLibrary:GetAllItems()        - Sorted array of items
--   EreaRpMasterItemLibrary:GetItem(id)          - Single item by ID
--   EreaRpMasterItemLibrary:CreateItem(data)     - New item with GUID
--   EreaRpMasterItemLibrary:UpdateItem(id, data) - Update fields (protect id/guid)
--   EreaRpMasterItemLibrary:DeleteItem(id)       - Remove from library
--   EreaRpMasterItemLibrary:CommitDatabase()     - Snapshot to committedDatabase
--   EreaRpMasterItemLibrary:GetCommittedDatabase() - Return committed snapshot
--   EreaRpMasterItemLibrary:IsItemUncommitted(item) - Field compare with committed
--   EreaRpMasterItemLibrary:GetUncommittedCount() - Count dirty + deleted items
--   EreaRpMasterItemLibrary:GetItemCount()       - Total item count
--   EreaRpMasterItemLibrary:SyncToRaid()         - Send committed DB to raid
--
-- DEPENDENCIES:
--   - EreaRpLibraries:ObjectDatabase()
--   - EreaRpLibraries:Messaging()
--   - EreaRpLibraries:Logging()
--   - EreaRpMasterDB (SavedVariable)
-- ============================================================================

-- ============================================================================
-- IMPORTS
-- ============================================================================
local objectDatabase = EreaRpLibraries:ObjectDatabase()
local messaging = EreaRpLibraries:Messaging()
local Log = EreaRpLibraries:Logging("EreaRpMaster")

-- ============================================================================
-- SERVICE TABLE
-- ============================================================================
EreaRpMasterItemLibrary = {}

-- ============================================================================
-- GetAllItems - Return sorted array of all items
-- ============================================================================
function EreaRpMasterItemLibrary:GetAllItems()
    local items = {}
    if not EreaRpMasterDB or not EreaRpMasterDB.itemLibrary then
        return items
    end

    for id, item in pairs(EreaRpMasterDB.itemLibrary) do
        table.insert(items, item)
    end

    table.sort(items, function(a, b)
        return (a.id or 0) < (b.id or 0)
    end)

    return items
end

-- ============================================================================
-- GetItem - Direct hash lookup
-- ============================================================================
function EreaRpMasterItemLibrary:GetItem(id)
    if not EreaRpMasterDB or not EreaRpMasterDB.itemLibrary then
        return nil
    end
    return EreaRpMasterDB.itemLibrary[id]
end

-- ============================================================================
-- CreateItem - Assign nextItemID, generate GUID, store
-- ============================================================================
function EreaRpMasterItemLibrary:CreateItem(data)
    if not EreaRpMasterDB then return nil end

    local id = EreaRpMasterDB.nextItemID or 1
    local guid = objectDatabase.GenerateGUID(data.name or "item")

    local item = {
        id = id,
        guid = guid,
        name = data.name or "New Item",
        icon = data.icon or "",
        tooltip = data.tooltip or "",
        content = data.content or "",
        contentTemplate = data.contentTemplate or "",
        defaultHandoutText = data.defaultHandoutText or "",
        actions = data.actions or {},
        initialCounter = data.initialCounter or 0
    }

    EreaRpMasterDB.itemLibrary[id] = item
    EreaRpMasterDB.nextItemID = id + 1

    Log("Created item #" .. id .. ": " .. item.name)
    return item
end

-- ============================================================================
-- UpdateItem - Copy fields, protect id/guid
-- ============================================================================
function EreaRpMasterItemLibrary:UpdateItem(id, data)
    if not EreaRpMasterDB or not EreaRpMasterDB.itemLibrary then
        return false
    end

    local item = EreaRpMasterDB.itemLibrary[id]
    if not item then return false end

    for key, value in pairs(data) do
        -- Protect immutable fields
        if key ~= "id" and key ~= "guid" then
            item[key] = value
        end
    end

    Log("Updated item #" .. id)
    return true
end

-- ============================================================================
-- DeleteItem - Remove from library
-- ============================================================================
function EreaRpMasterItemLibrary:DeleteItem(id)
    if not EreaRpMasterDB or not EreaRpMasterDB.itemLibrary then
        return false
    end

    local item = EreaRpMasterDB.itemLibrary[id]
    if not item then return false end

    local name = item.name or "unknown"
    EreaRpMasterDB.itemLibrary[id] = nil

    Log("Deleted item #" .. id .. ": " .. name)
    return true
end

-- ============================================================================
-- RevertItem - Restore item from committed snapshot
-- ============================================================================
function EreaRpMasterItemLibrary:RevertItem(id)
    if not EreaRpMasterDB or not EreaRpMasterDB.itemLibrary then
        return false
    end
    if not EreaRpMasterDB.committedDatabase or not EreaRpMasterDB.committedDatabase.items then
        return false
    end

    local committedItem = EreaRpMasterDB.committedDatabase.items[id]
    if not committedItem then return false end

    -- Deep copy committed item back to live library
    local restored = {
        id = committedItem.id,
        guid = committedItem.guid,
        name = committedItem.name,
        icon = committedItem.icon,
        tooltip = committedItem.tooltip,
        content = committedItem.content,
        contentTemplate = committedItem.contentTemplate,
        defaultHandoutText = committedItem.defaultHandoutText or "",
        initialCounter = committedItem.initialCounter or 0,
        actions = {}
    }

    -- Deep copy actions
    if committedItem.actions then
        for i = 1, table.getn(committedItem.actions) do  -- Lua 5.0: no # operator
            local action = committedItem.actions[i]
            local actionCopy = {
                id = action.id,
                label = action.label,
                sendStatus = action.sendStatus or false,
                methods = {},
                conditions = {}
            }
            if action.conditions then
                actionCopy.conditions.customTextEmpty = action.conditions.customTextEmpty
                actionCopy.conditions.counterGreaterThanZero = action.conditions.counterGreaterThanZero
            end
            if action.methods then
                for j = 1, table.getn(action.methods) do  -- Lua 5.0: no # operator
                    local method = action.methods[j]
                    local methodCopy = { type = method.type }
                    if method.params then
                        methodCopy.params = {}
                        for key, value in pairs(method.params) do
                            methodCopy.params[key] = value
                        end
                    end
                    table.insert(actionCopy.methods, methodCopy)
                end
            end
            table.insert(restored.actions, actionCopy)
        end
    end

    EreaRpMasterDB.itemLibrary[id] = restored
    Log("Reverted item #" .. id .. ": " .. restored.name)
    return true
end

-- ============================================================================
-- CommitDatabase - Create committed snapshot
-- ============================================================================
function EreaRpMasterItemLibrary:CommitDatabase()
    if not EreaRpMasterDB then return false end

    local databaseName = EreaRpMasterDB.databaseName or ""
    if databaseName == "" then
        Log("CommitDatabase rejected: database name is empty")
        return false, "Database name cannot be empty"
    end

    -- Reuse existing GUID so the same campaign is never treated as a new one.
    -- Lua 5.0: "" is truthy, so check explicitly for empty string.
    local existingId = EreaRpMasterDB.databaseId
    if existingId == "" then existingId = nil end

    -- Merge cinematicLibrary and mergeLibrary so players can look up merge cinematics
    -- by their group ID. Merge entries are shape-compatible with cinematic entries;
    -- the extra fields (amount, description) are ignored by CreateCommittedDatabase.
    local mergedCinematicLibrary = {}
    if EreaRpMasterDB.cinematicLibrary then
        for id, entry in pairs(EreaRpMasterDB.cinematicLibrary) do
            mergedCinematicLibrary[id] = entry
        end
    end
    if EreaRpMasterDB.mergeLibrary then
        for id, entry in pairs(EreaRpMasterDB.mergeLibrary) do
            mergedCinematicLibrary[id] = entry
        end
    end

    local committed = objectDatabase.CreateCommittedDatabase(
        EreaRpMasterDB.itemLibrary,
        databaseName,
        mergedCinematicLibrary,
        EreaRpMasterDB.scriptLibrary,
        existingId  -- nil on first commit → generates one
    )

    -- Persist the GUID so future commits reuse it
    EreaRpMasterDB.databaseId = committed.metadata.id

    EreaRpMasterDB.committedDatabase = committed
    Log("Database committed: " .. databaseName .. " (id: " .. committed.metadata.id .. ", checksum: " .. (committed.metadata.checksum or "?") .. ")")
    return true
end

-- ============================================================================
-- GetCommittedDatabase - Return committed snapshot
-- ============================================================================
function EreaRpMasterItemLibrary:GetCommittedDatabase()
    if not EreaRpMasterDB then return nil end
    return EreaRpMasterDB.committedDatabase
end

-- ============================================================================
-- IsItemUncommitted - Field-by-field compare with committed copy
-- ============================================================================
function EreaRpMasterItemLibrary:IsItemUncommitted(item)
    if not item or not item.id then return true end
    if not EreaRpMasterDB or not EreaRpMasterDB.committedDatabase then return true end

    local committed = EreaRpMasterDB.committedDatabase.items
    if not committed then return true end

    local committedItem = committed[item.id]
    if not committedItem then return true end

    -- Compare key fields
    if (item.name or "") ~= (committedItem.name or "") then return true end
    if (item.icon or "") ~= (committedItem.icon or "") then return true end
    if (item.tooltip or "") ~= (committedItem.tooltip or "") then return true end
    if (item.content or "") ~= (committedItem.content or "") then return true end
    if (item.contentTemplate or "") ~= (committedItem.contentTemplate or "") then return true end
    if (item.guid or "") ~= (committedItem.guid or "") then return true end
    if (item.defaultHandoutText or "") ~= (committedItem.defaultHandoutText or "") then return true end
    if (item.initialCounter or 0) ~= (committedItem.initialCounter or 0) then return true end

    -- Compare actions count
    local itemActionsCount = 0
    if item.actions then
        for _ in pairs(item.actions) do
            itemActionsCount = itemActionsCount + 1
        end
    end
    local committedActionsCount = 0
    if committedItem.actions then
        for _ in pairs(committedItem.actions) do
            committedActionsCount = committedActionsCount + 1
        end
    end
    if itemActionsCount ~= committedActionsCount then return true end

    return false
end

-- ============================================================================
-- GetUncommittedCount - Count dirty items + deleted-since-commit
-- ============================================================================
function EreaRpMasterItemLibrary:GetUncommittedCount()
    if not EreaRpMasterDB then return 0 end

    local count = 0

    -- Count dirty items in current library
    for id, item in pairs(EreaRpMasterDB.itemLibrary or {}) do
        if self:IsItemUncommitted(item) then
            count = count + 1
        end
    end

    -- Count items in committed that no longer exist (deleted since commit)
    if EreaRpMasterDB.committedDatabase and EreaRpMasterDB.committedDatabase.items then
        for id, _ in pairs(EreaRpMasterDB.committedDatabase.items) do
            if not EreaRpMasterDB.itemLibrary[id] then
                count = count + 1
            end
        end
    end

    return count
end

-- ============================================================================
-- GetItemCount - Count via pairs()
-- ============================================================================
function EreaRpMasterItemLibrary:GetItemCount()
    if not EreaRpMasterDB or not EreaRpMasterDB.itemLibrary then
        return 0
    end

    local count = 0
    for _ in pairs(EreaRpMasterDB.itemLibrary) do
        count = count + 1
    end
    return count
end

-- ============================================================================
-- SyncToRaid - Send committed DB to raid channel
-- ============================================================================
function EreaRpMasterItemLibrary:SyncToRaid()
    local committed = self:GetCommittedDatabase()
    if not committed then
        return false
    end

    -- Check if in a raid or party
    local numRaidMembers = GetNumRaidMembers()
    local numPartyMembers = GetNumPartyMembers()
    if numRaidMembers == 0 and numPartyMembers == 0 then
        return false
    end

    local messages = objectDatabase.CreateSyncMessageChunks(committed)
    if not messages then
        return false
    end

    -- Determine distribution channel
    local distribution = "RAID"
    if numRaidMembers == 0 then
        distribution = "PARTY"
    end

    -- Send all chunks
    local msgCount = 0
    for i = 1, table.getn(messages) do  -- Lua 5.0: no # operator
        SendAddonMessage(messaging.ADDON_PREFIX, messages[i], distribution)
        msgCount = msgCount + 1
    end

    Log("Synced database to " .. distribution .. " (" .. msgCount .. " messages)")
    return true
end
