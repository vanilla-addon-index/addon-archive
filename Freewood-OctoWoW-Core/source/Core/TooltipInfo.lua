-- Freewood-Core: Zusatzinfos in Tooltips (Reiter "Einstellungen" -> "Tooltips")
--   tipVendor  Haendlerpreis des Items (unabhaengig vom Auktionshaus-Scan)
--   tipQuest   Quest-Fortschritt am Gegner oder Objekt unter der Maus
--   tipCompare Shift-Vergleich mit dem angelegten Item (TooltipCompare.lua)
-- Weitere Module haengen Zeilen an Gegner-Tooltips mit FW.Tooltips.AddUnitLine(function(tt, name, npcID) ... end).
-- Jeder Teil ist einzeln abschaltbar. Die Werte stehen in den Core-Einstellungen (FW.settings.tooltips).

local FW = _G.Freewood
local T = FW and FW.Tooltips
if not FW or not T then
    return
end

local Tip = {}
T.Info = Tip

local function On(key) return T.Get(key) == true end

------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------

function Tip.Money(c)
    c = math.floor((c or 0) + 0.5)
    if _G.GetCoinTextureString then
        local ok, text = pcall(_G.GetCoinTextureString, c)
        if ok and type(text) == "string" then return text end
    end
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    if g > 0 then return string.format("%dg %ds %dc", g, s, k) end
    if s > 0 then return string.format("%ds %dc", s, k) end
    return string.format("%dc", k)
end

local function ItemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- Stapelgroesse des Items unter der Maus (Taschenfeld), sonst 1. Nur wenn das Feld dasselbe Item enthaelt.
local function HoverCount(link)
    local ok, count = pcall(function()
        local f = _G.GetMouseFocus and _G.GetMouseFocus()
        if not f then return 1 end
        local parent = f.GetParent and f:GetParent()
        if parent and parent.GetID and f.GetID and _G.GetContainerItemInfo and _G.GetContainerItemLink then
            local bag, slot = parent:GetID(), f:GetID()
            local l = _G.GetContainerItemLink(bag, slot)
            if l and ItemIDFromLink(l) == ItemIDFromLink(link) then
                local _, n = _G.GetContainerItemInfo(bag, slot)
                if tonumber(n) and n > 1 then return n end
            end
        end
        return 1
    end)
    return ok and count or 1
end

------------------------------------------------------------------------
-- Haendlerpreis
------------------------------------------------------------------------

local function AddVendor(tt, link)
    if not On("tipVendor") or not tt or not tt.AddLine then return end
    local id = ItemIDFromLink(link)
    if not id then return end
    if tt.fwVendID == id then return end
    -- beim Haendler zeigt das Spiel den Preis selbst
    if _G.MerchantFrame and _G.MerchantFrame.IsShown and _G.MerchantFrame:IsShown() then return end
    local info = FW.Util and FW.Util.GetItem and FW.Util.GetItem(id)
    local price = info and tonumber(info.sellPrice) or 0
    if price <= 0 then return end
    tt.fwVendID = id
    Tip.fired.vendor = Tip.fired.vendor + 1
    local L = FW.L
    local n = tt == _G.GameTooltip and HoverCount(link) or 1
    if n > 1 then
        tt:AddLine(string.format(L.TIP_VENDOR_STACK, Tip.Money(price), n, Tip.Money(price * n)), 1, 0.82, 0)
    else
        tt:AddLine(string.format(L.TIP_VENDOR, Tip.Money(price)), 1, 0.82, 0)
    end
end

------------------------------------------------------------------------
-- Quest-Fortschritt am Gegner oder Objekt
------------------------------------------------------------------------

local logCache, logAt = nil, -10
-- { { qid, title, objs = { { text, finished, kind } } } } fuer alle angenommenen Quests (1 s gemerkt)
local function LogObjectives()
    local now = _G.GetTime and _G.GetTime() or 0
    if logCache and now - logAt < 1 then return logCache end
    local out = {}
    local QL = _G.C_QuestLog
    local P = T.questProvider       -- optional (Quest-Modul): AcceptedSet() und TargetsOf(qid)
    if P and P.AcceptedSet and QL and QL.GetQuestObjectives then
        for qid in pairs(P.AcceptedSet()) do
            local ok, objs = pcall(QL.GetQuestObjectives, qid)
            if ok and type(objs) == "table" and #objs > 0 then
                local title
                if QL.GetTitleForQuestID then
                    local ok2, t = pcall(QL.GetTitleForQuestID, qid)
                    if ok2 and type(t) == "string" then title = t end
                end
                local list = {}
                for _, o in ipairs(objs) do
                    if type(o.text) == "string" and o.text ~= "" then
                        list[#list + 1] = { text = o.text, finished = o.finished and true or false, kind = o.type }
                    end
                end
                if #list > 0 then out[#out + 1] = { qid = qid, title = title or ("#" .. qid), objs = list } end
            end
        end
    elseif _G.GetNumQuestLogEntries and _G.GetQuestLogTitle and _G.GetNumQuestLeaderBoards and _G.GetQuestLogLeaderBoard then
        -- ohne Quest-Modul: normales Questlog (Ziele ueber die Questlog-Eintraege, ohne Quest-Nummer)
        local n = _G.GetNumQuestLogEntries() or 0
        for i = 1, n do
            local title, _, _, isHeader = _G.GetQuestLogTitle(i)
            if title and not isHeader then
                local list = {}
                for j = 1, (_G.GetNumQuestLeaderBoards(i) or 0) do
                    local text, kind, done = _G.GetQuestLogLeaderBoard(j, i)
                    if type(text) == "string" and text ~= "" then
                        list[#list + 1] = { text = text, finished = done and true or false, kind = kind }
                    end
                end
                if #list > 0 then out[#out + 1] = { title = title, objs = list } end
            end
        end
    end
    table.sort(out, function(a, b) return a.title < b.title end)
    logCache, logAt = out, now
    return out
end

-- Quests, die zu diesem Gegner oder Objekt gehoeren, mit den passenden Zielen
local function QuestLinesFor(name, npcID)
    local out = {}
    local lname = name and name:lower() or nil
    local TM = T.questProvider
    for _, q in ipairs(LogObjectives()) do
        local hits = {}
        local isTarget = npcID and q.qid and TM and TM.TargetsOf and TM.TargetsOf(q.qid)[npcID] or false
        for _, o in ipairs(q.objs) do
            local byName = lname and o.text:lower():find(lname, 1, true) ~= nil
            local byDrop = isTarget and o.kind == "item"
            if (byName or byDrop) then hits[#hits + 1] = o end
        end
        if #hits > 0 then out[#out + 1] = { title = q.title, objs = hits } end
    end
    return out
end

local function AddQuest(tt, name, npcID)
    if not On("tipQuest") or not tt or not tt.AddLine or not name then return end
    if tt.fwQuestName == name then return end
    local list = QuestLinesFor(name, npcID)
    if #list == 0 then return end
    tt.fwQuestName = name
    Tip.fired.quest = Tip.fired.quest + 1
    for _, e in ipairs(list) do
        tt:AddLine(e.title, 1, 0.82, 0)
        for _, o in ipairs(e.objs) do
            if o.finished then tt:AddLine("  " .. o.text, 0.4, 0.9, 0.4) else tt:AddLine("  " .. o.text, 1, 1, 1) end
        end
    end
end

------------------------------------------------------------------------
-- Anbindung an die Tooltips
------------------------------------------------------------------------

T.unitLines = T.unitLines or {}
function T.AddUnitLine(fn) T.unitLines[#T.unitLines + 1] = fn end
T.Money = Tip.Money

local hooked = {}
Tip.fired = { item = 0, unit = 0, object = 0, vendor = 0, quest = 0 }
local function HookTooltip(tt)
    if not tt or hooked[tt] or not tt.HookScript then return end
    hooked[tt] = true
    tt:HookScript("OnTooltipSetItem", function(self)
        local ok, _, link = pcall(self.GetItem, self)
        Tip.fired.item = Tip.fired.item + 1
        if ok and link then
            pcall(AddVendor, self, link)
            if T.CompareHook then pcall(T.CompareHook, self, link) end
            self:Show()
        end
    end)
    tt:HookScript("OnTooltipSetUnit", function(self)
        local name, unit = self:GetUnit()
        Tip.fired.unit = Tip.fired.unit + 1
        if not name then return end
        local npcID
        if unit then
            local g = _G.UnitGUID and _G.UnitGUID(unit)
            npcID = g and FW.Util and FW.Util.GetNpcID and FW.Util.GetNpcID(g) or nil
            if _G.UnitIsPlayer and _G.UnitIsPlayer(unit) then return end
        end
        pcall(AddQuest, self, name, npcID)
        for _, fn in ipairs(T.unitLines) do pcall(fn, self, name, npcID) end
        self:Show()
    end)
    tt:HookScript("OnTooltipCleared", function(self)
        self.fwVendID, self.fwQuestName, self.fwCmpLink, self.fwShift, self.fwDropID = nil, nil, nil, nil, nil
    end)
end

-- Objekte (Truhen, Kraeuter): der Tooltip hat nur den Namen in der ersten Zeile
local function HookObjects(tt)
    if not tt or not tt.HookScript then return end
    tt:HookScript("OnShow", function(self)
        if self:GetUnit() or (self.GetItem and self:GetItem()) or self.fwQuestName then return end
        local left = _G.GameTooltipTextLeft1
        local name = left and left:GetText()
        if type(name) == "string" and name ~= "" and (_G.UnitExists and not _G.UnitExists("mouseover")) then
            Tip.fired.object = Tip.fired.object + 1
            pcall(AddQuest, self, name, nil)
            if self.fwQuestName then self:Show() end
        end
    end)
end

local function Install()
    HookTooltip(_G.GameTooltip)
    HookTooltip(_G.ItemRefTooltip)
    HookTooltip(_G.ShoppingTooltip1)
    HookTooltip(_G.ShoppingTooltip2)
    HookObjects(_G.GameTooltip)
end

Install()
FW:On("QUEST_TIP_CHANGED", function() logCache = nil end, Tip)
FW:On("CODEX_CHANGED", function(_, kind) if kind == "quest" then logCache = nil end end, Tip)
FW:RegisterEvent("QUEST_LOG_UPDATE", function() logCache = nil end, Tip)

-- /fwtip: Pruefung der Tooltip-Anbindung (wie oft die Hooks gefeuert haben)
_G.SLASH_FREEWOODTIP1 = "/fwtip"
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList["FREEWOODTIP"] = function()
    local f = Tip.fired
    FW:Print(string.format("Tooltips: Item-Hook %dx, Gegner-Hook %dx, Objekt-Hook %dx; Haendlerzeile %dx, Quest-Zeilen %dx. HookScript: %s, TooltipDataProcessor: %s",
        f.item, f.unit, f.object, f.vendor, f.quest, tostring(_G.GameTooltip and _G.GameTooltip.HookScript ~= nil), tostring(_G.TooltipDataProcessor ~= nil)))
end

-- Optionen (die Codex-abhaengigen meldet das Codex-Modul selbst an)
T.RegisterOption("tipVendor", "TIP_OPT_VENDOR", { order = 10 })
T.RegisterOption("tipQuest", "TIP_OPT_QUEST", { order = 20 })
T.RegisterOption("tipCompare", "TIP_OPT_COMPARE", { order = 30, available = function() return T.CompareHook ~= nil end })
