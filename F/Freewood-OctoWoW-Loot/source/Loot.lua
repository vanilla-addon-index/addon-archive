-- Freewood-OctoWoW-Loot: Blacklist fuer Beute.
--
-- Ablauf:
--   1. Steht ein Blacklist-Item im Beutefenster, wird es automatisch mitgenommen
--      (damit die Leiche leer ist und sich haeuten laesst).
--   2. Liegt ein Blacklist-Item in den Taschen, kommt es in die Warteschlange (Loot.pending).
--   3. Der naechste Mausklick in der Spielwelt loescht ein wartendes Item.
--      Grund: das Spiel erlaubt Addons das Loeschen nur waehrend einer echten Eingabe
--      (Hardware-Ereignis) und nur ein Item pro Eingabe.
--
-- Gespeichert pro Charakter in Loot.chardb (Einstellungen Account-weit in Loot.db):
--   blacklist = { [itemID] = { name, added } }
--   recent    = { { id, t }, ... }   zuletzt erhaltene Items, neueste zuerst
--   log       = { { id, name, count, t }, ... }  zuletzt geloeschte Items, neueste zuerst
--   settings  = { enabled, autoLoot, chat }

local ADDON, NS = ...

local FW = _G.Freewood
if not FW or not FW:RequireAPI(1, ADDON) then
    return
end

local Util = FW.Util
local L = FW.L

local MAX_LIST = 500
local MAX_RECENT = 20
local MAX_LOG = 30
local MAX_IMPORT = 500
local MAX_FAILURES = 3

local function GetMeta(field)
    local fn = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if fn then
        local ok, value = pcall(fn, ADDON, field)
        if ok then
            return value
        end
    end
    return nil
end

local Loot = FW:NewModule("Loot", {
    version = GetMeta("Version") or "dev",
    title = L.LOOT_TITLE,
    description = L.LOOT_DESC,
    -- Einstellungen gelten fuer den Account, Blacklist/Zuletzt/Protokoll nur fuer den Charakter
    defaults = {
        settings = { enabled = true, autoLoot = true, chat = true },
    },
    charDefaults = {
        blacklist = {},
        recent = {},
        log = {},
    },
})
NS.Loot = Loot
FW.Loot = Loot

Loot.pending = {}   -- { { bag, slot, id, count } }
Loot.failures = 0
Loot.blocked = false

------------------------------------------------------------------------
-- Zugriff auf Taschen (neue und alte API)
------------------------------------------------------------------------

local function NumSlots(bag)
    local fn = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    if type(fn) ~= "function" then
        return 0
    end
    local ok, n = pcall(fn, bag)
    return (ok and tonumber(n)) or 0
end

-- Rueckgabe: itemID, Anzahl, gesperrt
local function SlotItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" then
            return tonumber(info.itemID), tonumber(info.stackCount) or 1, info.isLocked and true or false
        end
        return nil
    end
    if GetContainerItemInfo then
        local ok, _, count, locked, _, _, _, link, _, _, itemID = pcall(GetContainerItemInfo, bag, slot)
        if ok then
            return tonumber(itemID) or (type(link) == "string" and tonumber(link:match("item:(%d+)"))) or nil,
                tonumber(count) or 1, locked and true or false
        end
    end
    return nil
end

local function PickupSlot(bag, slot)
    local fn = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
    if type(fn) == "function" then
        fn(bag, slot)
    end
end

local function BagCount()
    return tonumber(_G.NUM_BAG_SLOTS) or 4
end

local function CursorItemID()
    if not GetCursorInfo then
        return nil
    end
    local kind, id = GetCursorInfo()
    if kind == "item" then
        return tonumber(id)
    end
    return nil
end

local function CursorHasAnything()
    return GetCursorInfo and GetCursorInfo() ~= nil
end

------------------------------------------------------------------------
-- Blacklist
------------------------------------------------------------------------

function Loot:IsListed(itemID)
    return itemID ~= nil and self.chardb.blacklist[itemID] ~= nil
end

function Loot:Count()
    local n = 0
    for _ in pairs(self.chardb.blacklist) do
        n = n + 1
    end
    return n
end

-- Item-ID aus Zahl, Text oder Item-Link; nil bei Unsinn
function Loot.ParseItem(input)
    local id
    if type(input) == "number" then
        id = input
    elseif type(input) == "string" then
        id = tonumber(input:match("item:(%d+)")) or tonumber(input:match("^%s*(%d+)%s*$"))
    end
    if not id or id ~= math.floor(id) or id < 1 or id > 10000000 then
        return nil
    end
    return id
end

local function ItemName(itemID)
    local info = Util.GetItem and Util.GetItem(itemID)
    if info and info.name then
        return info.name
    end
    if C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        if ok and type(name) == "string" then
            return name
        end
    end
    return nil
end

-- Rueckgabe: true oder false, Grund ("invalid" | "already" | "full")
function Loot:Add(input)
    local id = self.ParseItem(input)
    if not id then
        return false, "invalid"
    end
    if self.chardb.blacklist[id] then
        return false, "already"
    end
    if self:Count() >= MAX_LIST then
        return false, "full"
    end
    local name = ItemName(id)
    self.chardb.blacklist[id] = { name = name and name:sub(1, 80) or nil, added = time() }
    FW:Fire("LOOT_LIST_CHANGED")
    self:Scan()
    return true, id
end

function Loot:Remove(itemID)
    if self.chardb.blacklist[itemID] then
        self.chardb.blacklist[itemID] = nil
        FW:Fire("LOOT_LIST_CHANGED")
        self:Scan()
        return true
    end
    return false
end

-- Sortierte Liste { { id, name } } (nach Name, unbekannte ans Ende)
function Loot:List()
    local list = {}
    for id, entry in pairs(self.chardb.blacklist) do
        local name = ItemName(id) or entry.name
        if name and entry.name ~= name then
            entry.name = name:sub(1, 80)
        end
        list[#list + 1] = { id = id, name = name }
    end
    table.sort(list, function(a, b)
        local an, bn = a.name and a.name:lower() or "\255", b.name and b.name:lower() or "\255"
        if an ~= bn then
            return an < bn
        end
        return a.id < b.id
    end)
    return list
end

------------------------------------------------------------------------
-- Zuletzt erhalten, Protokoll
------------------------------------------------------------------------

function Loot:NoteLooted(itemID)
    if not itemID then
        return
    end
    local recent = self.chardb.recent
    for i = #recent, 1, -1 do
        if recent[i].id == itemID then
            table.remove(recent, i)
        end
    end
    table.insert(recent, 1, { id = itemID, t = time() })
    while #recent > MAX_RECENT do
        table.remove(recent)
    end
    FW:Fire("LOOT_RECENT_CHANGED")
end

local function AddLog(self, itemID, count)
    local log = self.chardb.log
    local name = ItemName(itemID) or (self.chardb.blacklist[itemID] and self.chardb.blacklist[itemID].name) or ("#" .. itemID)
    table.insert(log, 1, { id = itemID, name = name:sub(1, 80), count = count or 1, t = time() })
    while #log > MAX_LOG do
        table.remove(log)
    end
    return name
end

------------------------------------------------------------------------
-- Taschen durchsuchen
------------------------------------------------------------------------

-- Fruehere Versionen (<= 0.1.1) legten die Blacklist Account-weit ab. Jeder Charakter
-- uebernimmt diese alte Liste einmalig als Kopie, danach sind die Listen unabhaengig.
function Loot:OnInitialize()
    local old = self.db.blacklist
    if type(old) == "table" and not self.chardb.migrated then
        self.chardb.migrated = true
        for id, entry in pairs(old) do
            if self.chardb.blacklist[id] == nil and type(entry) == "table" then
                self.chardb.blacklist[id] = { name = entry.name, added = entry.added }
            end
        end
    end
end

function Loot:Scan()
    local list = {}
    if self.chardb then
        for bag = 0, BagCount() do
            for slot = 1, NumSlots(bag) do
                local id, count = SlotItem(bag, slot)
                if id and self.chardb.blacklist[id] then
                    list[#list + 1] = { bag = bag, slot = slot, id = id, count = count }
                end
            end
        end
    end
    local changed = #list ~= #self.pending
    self.pending = list
    if changed then
        FW:Fire("LOOT_PENDING_CHANGED", #list)
    end
    return #list
end

function Loot:PendingCount()
    return #self.pending
end

------------------------------------------------------------------------
-- Loeschen (nur im Moment einer Mausaktion in der Spielwelt)
------------------------------------------------------------------------

function Loot:CanDelete()
    local s = self.db and self.db.settings
    if not s or not s.enabled or self.blocked then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    if CursorHasAnything() then
        return false
    end
    if _G.LootFrame and _G.LootFrame.IsShown and _G.LootFrame:IsShown() then
        return false
    end
    return true
end

-- Loescht ein wartendes Item. Rueckgabe: true bei Erfolg, sonst false und Grund.
function Loot:DeleteOne()
    if not self:CanDelete() then
        return false, "blocked"
    end
    -- Frisch suchen, falls sich die Taschen seit dem letzten Durchlauf geaendert haben
    self:Scan()
    local entry = self.pending[1]
    if not entry then
        return false, "none"
    end
    local id, count, locked = SlotItem(entry.bag, entry.slot)
    if id ~= entry.id or locked or not self.chardb.blacklist[id] then
        return false, "changed"
    end

    PickupSlot(entry.bag, entry.slot)
    if CursorItemID() ~= entry.id then
        if CursorHasAnything() then
            ClearCursor()
        end
        return false, "pickup"
    end

    local fn = _G.DeleteCursorItem
    if type(fn) ~= "function" then
        ClearCursor()
        return false, "noapi"
    end
    pcall(fn)

    if CursorHasAnything() then
        -- Das Spiel hat das Loeschen nicht ausgefuehrt
        ClearCursor()
        self.failures = self.failures + 1
        if self.failures >= MAX_FAILURES and not self.blocked then
            self.blocked = true
            FW:Print(FW.L.LOOT_BLOCKED)
        end
        return false, "denied"
    end

    self.failures = 0
    local name = AddLog(self, entry.id, count)
    if self.db.settings.chat then
        FW:Print(string.format(FW.L.LOOT_DELETED, name, count or 1))
    end
    FW:Fire("LOOT_LOG_CHANGED")
    self:Scan()
    return true
end

local lastClick = 0
function Loot:OnWorldClick()
    if #self.pending == 0 then
        return
    end
    local now = GetTime and GetTime() or 0
    if now - lastClick < 0.15 then
        return
    end
    lastClick = now
    self:DeleteOne()
end

function Loot:InstallHook()
    if self.hooked then
        return true
    end
    if _G.WorldFrame and _G.WorldFrame.HookScript then
        _G.WorldFrame:HookScript("OnMouseUp", function()
            Loot:OnWorldClick()
        end)
        self.hooked = true
        return true
    end
    return false
end

------------------------------------------------------------------------
-- Beute
------------------------------------------------------------------------

function Loot:OnLootOpened()
    pcall(self.LootOpenedImpl, self)
end

function Loot:LootOpenedImpl()
    if not GetNumLootItems then
        return
    end
    local autoLoot = self.db.settings.autoLoot
    for slot = GetNumLootItems(), 1, -1 do
        local link = GetLootSlotLink and Util.Clean(GetLootSlotLink(slot))
        local id = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
        if id then
            self:NoteLooted(id)
            if autoLoot and self.chardb.blacklist[id] and (not LootSlotHasItem or LootSlotHasItem(slot)) then
                pcall(LootSlot, slot)
            end
        end
    end
end

function Loot:OnChatLoot(text, ...)
    -- Geheime Werte (secret values) werden ignoriert
    pcall(function(...)
        if Util.IsSecret(text) or type(text) ~= "string" then
            return
        end
        local guid = select(11, ...)
        if Util.IsSecret(guid) then
            return
        end
        if guid and UnitGUID and guid ~= UnitGUID("player") then
            return
        end
        local id = tonumber(text:match("item:(%d+)"))
        if id then
            self:NoteLooted(id)
        end
    end, ...)
end

function Loot:OnBagUpdate()
    self:Scan()
end

function Loot:OnEnable()
    self:InstallHook()
    FW:RegisterEvent("LOOT_OPENED", self.OnLootOpened, self)
    FW:RegisterEvent("CHAT_MSG_LOOT", self.OnChatLoot, self)
    FW:RegisterEvent("BAG_UPDATE_DELAYED", self.OnBagUpdate, self)
    FW:RegisterEvent("PLAYER_ENTERING_WORLD", self.OnBagUpdate, self)
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            Loot:Scan()
        end)
    end
end

function Loot:OnDisable()
    for _, event in ipairs({ "LOOT_OPENED", "CHAT_MSG_LOOT", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" }) do
        FW:UnregisterEvent(event, self)
    end
end

------------------------------------------------------------------------
-- Export / Import der Blacklist
------------------------------------------------------------------------

function Loot:ExportData()
    local list = {}
    for _, e in ipairs(self:List()) do
        list[#list + 1] = { id = e.id, name = e.name }
    end
    if #list == 0 then
        return {}
    end
    return { list = list }
end

function Loot:ValidateImport(data)
    if type(data) ~= "table" or type(data.list) ~= "table" or #data.list == 0 then
        return false, L.LOOT_IMPORT_EMPTY
    end
    if #data.list > MAX_IMPORT then
        return false, L.LOOT_IMPORT_TOO_MANY
    end
    return true
end

function Loot:ImportData(data)
    local added, known = 0, 0
    for _, e in ipairs(data.list or {}) do
        local id = type(e) == "table" and self.ParseItem(e.id) or nil
        if id then
            if self.chardb.blacklist[id] then
                known = known + 1
            elseif self:Count() < MAX_LIST then
                local name = type(e.name) == "string" and e.name:sub(1, 80) or ItemName(id)
                self.chardb.blacklist[id] = { name = name, added = time() }
                added = added + 1
            end
        end
    end
    FW:Fire("LOOT_LIST_CHANGED")
    self:Scan()
    return string.format(FW.L.LOOT_IMPORT_STATS, added, known)
end

if FW.Export and FW.Export.RegisterHandler then
    FW.Export.RegisterHandler("lootlist", {
        label = function()
            return FW.L.LOOT_EXPORT_LABEL
        end,
        export = function()
            return Loot:ExportData()
        end,
        validate = function(data)
            return Loot:ValidateImport(data)
        end,
        import = function(data)
            return Loot:ImportData(data)
        end,
    })
end

------------------------------------------------------------------------
-- Test im Spiel: /fwloot test
------------------------------------------------------------------------

function Loot:RunTest()
    local Lc = FW.L
    local function yn(v)
        return v and Lc.LOOT_YES or Lc.LOOT_NO
    end
    FW:Print(string.format(Lc.LOOT_TEST_API,
        yn(C_Container and C_Container.PickupContainerItem or PickupContainerItem),
        yn(type(_G.DeleteCursorItem) == "function"),
        yn(self.hooked)))
    if self.blocked then
        self.blocked = false
        self.failures = 0
        FW:Print(Lc.LOOT_TEST_RESET)
    end
    local n = self:Scan()
    if n == 0 then
        FW:Print(Lc.LOOT_TEST_NONE)
    else
        FW:Print(string.format(Lc.LOOT_TEST_PENDING, n))
    end
end
