-- Freewood-OctoWoW-Vendor: Listen fuer den Haendler.
--
-- Zwei Listen (gelten fuer den ganzen Account):
--   black = "Nie verkaufen"    steht immer an erster Stelle: Was hier steht, wird nie verkauft
--                              (auch nicht grau, nicht ueber den Knopf, nicht bei der Automatik).
--   white = "Immer verkaufen"  wird beim Haendler mitverkauft.
-- Dazu: graue Items (Qualitaet 0) werden mitverkauft, wenn der Haken "gray" an ist.
--
-- Reihenfolge der Entscheidung je Item (die erste zutreffende Regel gilt):
--   1. Nie-verkaufen-Liste                     -> bleibt
--   2. geschuetzt (Quest-Item, von einer angenommenen Quest gebraucht) -> bleibt
--   3. Immer-verkaufen-Liste                   -> wird verkauft
--   4. grau und Haken "gray"                   -> wird verkauft
--   5. sonst                                   -> bleibt
-- Items ohne Verkaufspreis werden nie angefasst.
--
-- Verkauft wird mit UseContainerItem, solange das Haendlerfenster offen ist, ein Item je kurzem Takt.
-- Der Haendler haelt die letzten 12 verkauften Items im Rueckkauf.
--
-- Gespeichert: Account-weit Vendor.db = { black, white, settings }, je Charakter Vendor.chardb.log (zuletzt verkauft).

local ADDON, NS = ...

local FW = _G.Freewood
if not FW or not FW:RequireAPI(1, ADDON) then
    return
end

local Util = FW.Util
local L = FW.L

local MAX_LIST = 500
local MAX_LOG = 30
local MAX_IMPORT = 1000
local SELL_GAP = 0.15

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

local Vendor = FW:NewModule("Vendor", {
    version = GetMeta("Version") or "dev",
    title = L.VENDOR_TITLE,
    description = L.VENDOR_DESC,
    defaults = {
        settings = { auto = false, gray = true, chat = true },
        black = {},
        white = {},
    },
    charDefaults = {
        log = {},
    },
})
NS.Vendor = Vendor
FW.Vendor = Vendor

Vendor.merchant = false
Vendor.run = nil
Vendor.sellable = 0

local function Money(c)
    c = math.floor(tonumber(c) or 0)
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local out = {}
    if g > 0 then out[#out + 1] = g .. "g" end
    if s > 0 then out[#out + 1] = s .. "s" end
    if k > 0 or #out == 0 then out[#out + 1] = k .. "c" end
    return table.concat(out, " ")
end
Vendor.Money = Money

------------------------------------------------------------------------
-- Taschen
------------------------------------------------------------------------

local function NumSlots(bag)
    local fn = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    if type(fn) ~= "function" then
        return 0
    end
    local ok, n = pcall(fn, bag)
    return (ok and tonumber(n)) or 0
end

-- Rueckgabe: itemID, Anzahl, gesperrt, Qualitaet (nil, wenn unbekannt)
local function SlotInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" then
            return tonumber(info.itemID), tonumber(info.stackCount) or 1, info.isLocked and true or false, tonumber(info.quality)
        end
    end
    if GetContainerItemInfo then
        local ok, _, count, locked, quality, _, _, link, _, _, itemID = pcall(GetContainerItemInfo, bag, slot)
        if ok then
            local id = tonumber(itemID) or (type(link) == "string" and tonumber(link:match("item:(%d+)"))) or nil
            if not id and GetContainerItemLink then
                local ok2, l2 = pcall(GetContainerItemLink, bag, slot)
                if ok2 and type(l2) == "string" then id = tonumber(l2:match("item:(%d+)")) end
            end
            return id, tonumber(count) or 1, locked and true or false, tonumber(quality)
        end
    end
    return nil
end
Vendor.SlotInfo = SlotInfo

local function BagCount()
    return tonumber(_G.NUM_BAG_SLOTS) or 4
end

local function UseSlot(bag, slot)
    local fn = (C_Container and C_Container.UseContainerItem) or UseContainerItem
    if type(fn) == "function" then
        fn(bag, slot)
        return true
    end
    return false
end

local function CursorHasAnything()
    return GetCursorInfo and GetCursorInfo() ~= nil
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

-- Item-ID aus Zahl, Text oder Item-Link; nil bei Unsinn
function Vendor.ParseItem(input)
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

------------------------------------------------------------------------
-- Listen
------------------------------------------------------------------------

local function ListOf(self, which)
    return which == "black" and self.db.black or self.db.white
end

function Vendor:IsBlack(itemID) return itemID ~= nil and self.db.black[itemID] ~= nil end
function Vendor:IsWhite(itemID) return itemID ~= nil and self.db.white[itemID] ~= nil end

function Vendor:Count(which)
    local n = 0
    for _ in pairs(ListOf(self, which)) do n = n + 1 end
    return n
end

-- which = "black" | "white". Ein Item steht nie auf beiden Listen: Nie-verkaufen verdraengt Immer-verkaufen.
-- Rueckgabe: true, id  oder  false, Grund ("invalid" | "already" | "full" | "black")
function Vendor:Add(which, input)
    local id = self.ParseItem(input)
    if not id then
        return false, "invalid"
    end
    local list = ListOf(self, which)
    if list[id] then
        return false, "already"
    end
    if which == "white" and self.db.black[id] then
        return false, "black"     -- steht auf "Nie verkaufen": zuerst dort entfernen
    end
    if self:Count(which) >= MAX_LIST then
        return false, "full"
    end
    if which == "black" and self.db.white[id] then
        self.db.white[id] = nil   -- Nie-verkaufen gewinnt
    end
    local name = ItemName(id)
    list[id] = { name = name and name:sub(1, 80) or nil, added = time() }
    FW:Fire("VENDOR_LIST_CHANGED")
    self:Recount()
    return true, id
end

function Vendor:Remove(which, itemID)
    local list = ListOf(self, which)
    if list[itemID] then
        list[itemID] = nil
        FW:Fire("VENDOR_LIST_CHANGED")
        self:Recount()
        return true
    end
    return false
end

-- Sortierte Liste { { id, name } }
function Vendor:List(which)
    local out = {}
    for id, entry in pairs(ListOf(self, which)) do
        local name = ItemName(id) or entry.name
        if name and entry.name ~= name then
            entry.name = name:sub(1, 80)
        end
        out[#out + 1] = { id = id, name = name }
    end
    table.sort(out, function(a, b)
        local an, bn = a.name and a.name:lower() or "\255", b.name and b.name:lower() or "\255"
        if an ~= bn then
            return an < bn
        end
        return a.id < b.id
    end)
    return out
end

------------------------------------------------------------------------
-- Schutz: Items, die eine angenommene Quest noch braucht
------------------------------------------------------------------------

local protectedIDs, protectedNames = {}, {}

-- Liest die Questliste und den Codex neu. Wird beim Oeffnen des Haendlers und vor jedem Verkauf aufgerufen.
function Vendor:RefreshProtected()
    local ids, names = {}, {}
    -- 1. Questliste: Ziele vom Typ "item", die noch nicht erfuellt sind (Name aus "Wolfsfleisch: 3/8")
    if GetNumQuestLogEntries and GetQuestLogTitle and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        local n = tonumber((GetNumQuestLogEntries())) or 0
        for i = 1, n do local i = i
            local ok, _, _, _, isHeader = pcall(GetQuestLogTitle, i)
            if ok and not isHeader then
                local nb = tonumber((GetNumQuestLeaderBoards(i))) or 0
                for j = 1, nb do local j = j
                    local ok2, desc, kind, done = pcall(GetQuestLogLeaderBoard, j, i)
                    if ok2 and kind == "item" and not done and type(desc) == "string" then
                        local name = desc:match("^(.-):%s*%-?%d+%s*/%s*%d+") or desc
                        names[name:lower()] = true
                    end
                end
            end
        end
    end
    -- 2. Codex: Quest-Items aller angenommenen Quests (deckt auch zugeklappte Gebiete der Questliste ab)
    local C = FW.Codex
    if C and C.LocalActive and C.V then
        local ok, active = pcall(C.LocalActive)
        local V = ok and C.V() or nil
        if ok and type(active) == "table" and V and V.quests then
            for _, qid in ipairs(active) do
                local q = V.quests[qid]
                if type(q) == "table" and type(q.qi) == "table" then
                    for itemID in pairs(q.qi) do
                        if type(itemID) == "number" then ids[itemID] = true end
                    end
                end
            end
        end
    end
    protectedIDs, protectedNames = ids, names
end

function Vendor:IsProtected(itemID, info)
    if protectedIDs[itemID] then
        return true
    end
    if info then
        if info.classID == 12 or info.type == "Quest" then
            return true     -- Quest-Item
        end
        if info.name and protectedNames[info.name:lower()] then
            return true
        end
    end
    return false
end

------------------------------------------------------------------------
-- Entscheidung
------------------------------------------------------------------------

-- Rueckgabe: verkaufen (bool), Grund ("black" | "protected" | "white" | "gray" | "noprice" | "keep")
function Vendor:Decide(itemID, quality, info)
    if self.db.black[itemID] then
        return false, "black"
    end
    if not info then
        return false, "keep"
    end
    if self:IsProtected(itemID, info) then
        return false, "protected"
    end
    local sell, why = false, "keep"
    if self.db.white[itemID] then
        sell, why = true, "white"
    elseif self.db.settings.gray and quality == 0 then
        sell, why = true, "gray"
    end
    if sell and (info.sellPrice or 0) <= 0 then
        return false, "noprice"
    end
    return sell, why
end

-- Alle Items in den Taschen, die jetzt verkauft wuerden: { { bag, slot, id, count, price, why } }, Gesamtpreis
function Vendor:Collect()
    self:RefreshProtected()
    local list, total = {}, 0
    for bag = 0, BagCount() do
        for slot = 1, NumSlots(bag) do
            local id, count, _, q = SlotInfo(bag, slot)
            if id then
                local info = Util.GetItem and Util.GetItem(id)
                local quality = q
                if quality == nil and info then quality = info.quality end
                if info and quality ~= nil then
                    local sell, why = self:Decide(id, quality, info)
                    if sell then
                        local price = (info.sellPrice or 0) * (count or 1)
                        list[#list + 1] = { bag = bag, slot = slot, id = id, count = count or 1, price = price, why = why }
                        total = total + price
                    end
                end
            end
        end
    end
    return list, total
end

-- Taschen-Inhalt ohne Doppelte: { { id, count } } (fuer die Anzeige "In deinen Taschen")
function Vendor:BagItems()
    local seen, out = {}, {}
    for bag = 0, BagCount() do
        for slot = 1, NumSlots(bag) do
            local id, count = SlotInfo(bag, slot)
            if id then
                if seen[id] then
                    seen[id].count = seen[id].count + (count or 1)
                else
                    local e = { id = id, count = count or 1 }
                    seen[id] = e
                    out[#out + 1] = e
                end
            end
        end
    end
    return out
end

function Vendor:Recount()
    local n = 0
    if self.merchant then
        n = #self:Collect()
    end
    if n ~= self.sellable then
        self.sellable = n
        FW:Fire("VENDOR_COUNT_CHANGED", n)
    end
    return n
end

------------------------------------------------------------------------
-- Verkaufen
------------------------------------------------------------------------

local function AddLog(self, id, count, price)
    local log = self.chardb.log
    local name = ItemName(id) or ("#" .. id)
    table.insert(log, 1, { id = id, name = name:sub(1, 80), count = count or 1, price = price or 0, t = time() })
    while #log > MAX_LOG do
        table.remove(log)
    end
end

local function MerchantOpen()
    return _G.MerchantFrame and _G.MerchantFrame.IsShown and _G.MerchantFrame:IsShown() and true or false
end

local function Finish(self, reason)
    local run = self.run
    self.run = nil
    if self.driver then self.driver:Hide() end
    if not run then return end
    if run.n > 0 then
        FW:Fire("VENDOR_LOG_CHANGED")
        if self.db.settings.chat then
            FW:Print(string.format(FW.L.VENDOR_DONE, run.n, Money(run.money)))
        end
    end
    if reason == "closed" and run.i <= #run.list and self.db.settings.chat then
        FW:Print(string.format(FW.L.VENDOR_STOPPED, run.i - 1, #run.list))
    end
    self:Recount()
end

-- Startet den Verkauf. manual = true: Knopfdruck (meldet auch, wenn nichts zu verkaufen ist)
function Vendor:Start(manual)
    if self.run then
        return false
    end
    if not self.merchant or not MerchantOpen() then
        if manual then FW:Print(FW.L.VENDOR_NO_MERCHANT) end
        return false
    end
    local list = self:Collect()
    if #list == 0 then
        if manual then FW:Print(FW.L.VENDOR_NOTHING) end
        return false
    end
    self.run = { list = list, i = 1, n = 0, money = 0, wait = 0 }
    self.driver:Show()
    return true
end

-- Ein Schritt: das naechste Item verkaufen, nach erneuter Pruefung
function Vendor:Step()
    local run = self.run
    if not run then return end
    if not self.merchant or not MerchantOpen() then
        return Finish(self, "closed")
    end
    if CursorHasAnything() then
        return      -- warten, bis der Cursor frei ist (UseContainerItem koennte sonst etwas anderes tun)
    end
    local e = run.list[run.i]
    if not e then
        return Finish(self, "done")
    end
    run.i = run.i + 1
    -- Neu pruefen: gleiche Stelle, gleiches Item, nicht gesperrt, und die Regeln erlauben es immer noch
    self:RefreshProtected()
    local id, count, locked, q = SlotInfo(e.bag, e.slot)
    if id ~= e.id or locked then
        return
    end
    local info = Util.GetItem and Util.GetItem(id)
    local quality = q
    if quality == nil and info then quality = info.quality end
    if not info or quality == nil then
        return
    end
    local sell = self:Decide(id, quality, info)
    if not sell then
        return
    end
    if UseSlot(e.bag, e.slot) then
        local price = (info.sellPrice or 0) * (count or 1)
        run.n = run.n + 1
        run.money = run.money + price
        AddLog(self, id, count, price)
    else
        Finish(self, "noapi")
    end
end

function Vendor:OnMerchantShow()
    self.merchant = true
    FW:Fire("VENDOR_MERCHANT_CHANGED", true)
    self:Recount()
    if self.db.settings.auto and C_Timer and C_Timer.After then
        C_Timer.After(0.4, function()
            if Vendor.merchant and Vendor.db.settings.auto then Vendor:Start(false) end
        end)
    end
end

function Vendor:OnMerchantClosed()
    self.merchant = false
    if self.run then Finish(self, "closed") end
    self.sellable = 0
    FW:Fire("VENDOR_MERCHANT_CHANGED", false)
end

local bagAcc = 0
function Vendor:OnBagUpdate()
    if self.merchant and not self.run then
        local now = GetTime and GetTime() or 0
        if now - bagAcc > 0.3 then
            bagAcc = now
            self:Recount()
        end
    end
end

function Vendor:OnEnable()
    self.driver = self.driver or CreateFrame("Frame")
    local acc = 0
    self.driver:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < SELL_GAP then return end
        acc = 0
        local ok, err = pcall(Vendor.Step, Vendor)
        if not ok then
            Vendor.run = nil
            Vendor.driver:Hide()
        end
    end)
    self.driver:Hide()
    FW:RegisterEvent("MERCHANT_SHOW", self.OnMerchantShow, self)
    FW:RegisterEvent("MERCHANT_CLOSED", self.OnMerchantClosed, self)
    FW:RegisterEvent("BAG_UPDATE", self.OnBagUpdate, self)
    FW:RegisterEvent("BAG_UPDATE_DELAYED", self.OnBagUpdate, self)
end

function Vendor:OnDisable()
    for _, event in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "BAG_UPDATE", "BAG_UPDATE_DELAYED" }) do
        FW:UnregisterEvent(event, self)
    end
    if self.driver then self.driver:Hide() end
    self.run = nil
end

------------------------------------------------------------------------
-- Export / Import
------------------------------------------------------------------------

function Vendor:ExportData()
    local data = {}
    for _, which in ipairs({ "black", "white" }) do
        local list = {}
        for _, e in ipairs(self:List(which)) do
            list[#list + 1] = { id = e.id, name = e.name }
        end
        if #list > 0 then data[which] = list end
    end
    return data
end

function Vendor:ValidateImport(data)
    if type(data) ~= "table" or (type(data.black) ~= "table" and type(data.white) ~= "table") then
        return false, L.VENDOR_IMPORT_EMPTY
    end
    if #(data.black or {}) + #(data.white or {}) > MAX_IMPORT then
        return false, L.VENDOR_IMPORT_TOO_MANY
    end
    return true
end

function Vendor:ImportData(data)
    local added, known = 0, 0
    -- zuerst "Nie verkaufen", damit es "Immer verkaufen" verdraengt
    for _, which in ipairs({ "black", "white" }) do
        for _, e in ipairs(data[which] or {}) do
            local id = type(e) == "table" and self.ParseItem(e.id) or nil
            if id then
                local list = ListOf(self, which)
                if list[id] or (which == "white" and self.db.black[id]) then
                    known = known + 1
                elseif self:Count(which) < MAX_LIST then
                    if which == "black" then self.db.white[id] = nil end
                    local name = type(e.name) == "string" and e.name:sub(1, 80) or ItemName(id)
                    list[id] = { name = name, added = time() }
                    added = added + 1
                end
            end
        end
    end
    FW:Fire("VENDOR_LIST_CHANGED")
    self:Recount()
    return string.format(FW.L.VENDOR_IMPORT_STATS, added, known)
end

if FW.Export and FW.Export.RegisterHandler then
    FW.Export.RegisterHandler("vendorlist", {
        label = function() return FW.L.VENDOR_EXPORT_LABEL end,
        export = function() return Vendor:ExportData() end,
        validate = function(data) return Vendor:ValidateImport(data) end,
        import = function(data) return Vendor:ImportData(data) end,
    })
end

------------------------------------------------------------------------
-- Test im Spiel: /fwsell test  (verkauft nichts)
------------------------------------------------------------------------

function Vendor:RunTest()
    local Lc = FW.L
    local function yn(v) return v and Lc.VENDOR_YES or Lc.VENDOR_NO end
    FW:Print(string.format(Lc.VENDOR_TEST_API,
        yn(C_Container and C_Container.UseContainerItem or UseContainerItem),
        yn(C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo),
        yn(MerchantOpen())))
    self:RefreshProtected()
    local gray, white, black, prot, noq, noprice, keep = 0, 0, 0, 0, 0, 0, 0
    local total = 0
    for bag = 0, BagCount() do
        for slot = 1, NumSlots(bag) do
            local id, count, _, q = SlotInfo(bag, slot)
            if id then
                local info = Util.GetItem and Util.GetItem(id)
                local quality = q
                if quality == nil and info then quality = info.quality end
                if not info or quality == nil then
                    noq = noq + 1
                else
                    local sell, why = self:Decide(id, quality, info)
                    if sell then
                        if why == "gray" then gray = gray + 1 else white = white + 1 end
                        total = total + (info.sellPrice or 0) * (count or 1)
                    elseif why == "black" then black = black + 1
                    elseif why == "protected" then prot = prot + 1
                    elseif why == "noprice" then noprice = noprice + 1
                    else keep = keep + 1 end
                end
            end
        end
    end
    FW:Print(string.format(Lc.VENDOR_TEST_RESULT, gray, white, Money(total)))
    FW:Print(string.format(Lc.VENDOR_TEST_KEPT, black, prot, noprice, keep, noq))
end
