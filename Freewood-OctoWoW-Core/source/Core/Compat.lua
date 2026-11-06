-- Freewood Compat (OctoWoW)
-- Ersatz fuer Funktionen, die im Forever-Client da sind, im OctoWoW-Client (1.12.1 + ClassicAPI) aber fehlen.
-- Gebaut aus dem Pruefergebnis von /fwprobe. Es wird nur ergaenzt, was fehlt - vorhandene Funktionen bleiben unberuehrt.
-- Wird als erste Datei des Core geladen; alles hier ist ohne FW lauffaehig.

local G = _G

local Compat = {}
G.FreewoodCompat = Compat
Compat.applied = {}
Compat.failed = {}

local function Mark(name)
    Compat.applied[#Compat.applied + 1] = name
end

local function Try(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        Compat.failed[#Compat.failed + 1] = name .. ": " .. tostring(err)
    end
end

local function Table(name)
    local t = G[name]
    if type(t) ~= "table" then
        t = {}
        G[name] = t
    end
    return t
end

-- Setzt G[name], wenn es fehlt
local function Global(name, value)
    if G[name] == nil then
        G[name] = value
        Mark(name)
    end
end

-- Setzt t[key], wenn es fehlt
local function Field(t, label, key, value)
    if t[key] == nil then
        t[key] = value
        Mark(label .. "." .. key)
    end
end

------------------------------------------------------------------------
-- Textumbruch von Schriftzuegen: FontString:SetWordWrap
-- 1.12 bricht immer um, sobald eine Breite da ist. "Kein Umbruch" wird ueber eine Hoehe von einer Zeile nachgebildet.
------------------------------------------------------------------------

local function WordWrapImpl(self, wrap)
    if wrap then
        if self.fwSingleLine then
            self.fwSingleLine = nil
            self:SetHeight(0)
        end
    else
        local _, size = self:GetFont()
        if size and size > 0 and not self.fwSingleLine then
            self.fwSingleLine = true
            self:SetHeight(size + 2)
        end
    end
end

local function GetWordWrapImpl(self)
    return not self.fwSingleLine
end

Compat.diag = {}

Try("SetWordWrap", function()
    local frame = CreateFrame("Frame")
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local meta = getmetatable(fs)
    local diag = Compat.diag
    diag.fsType = type(fs)
    diag.fsMeta = type(meta)
    diag.fsIndex = type(meta and meta.__index)
    local methods = type(meta) == "table" and meta.__index or nil
    if type(methods) == "table" and methods.SetWordWrap == nil then
        pcall(function()
            methods.SetWordWrap = WordWrapImpl
            methods.GetWordWrap = GetWordWrapImpl
        end)
    end
    if fs.SetWordWrap ~= nil then
        diag.wrap = "metatable"
        Mark("FontString:SetWordWrap (Metatabelle)")
        return
    end

    -- Zweiter Weg: die Huelle um CreateFrame (weiter unten) gibt jedem neuen FontString die Methoden direkt
    diag.wrap = "CreateFrame-Huelle"
    Compat.needFontStringPatch = true
end)

------------------------------------------------------------------------
-- Huelle um CreateFrame:
--  1. neue FontStrings bekommen SetWordWrap/GetWordWrap, falls die Metatabelle nicht erweiterbar war
--  2. Script-Handler bekommen self und ihre Argumente auch dann, wenn der Client sie nicht uebergibt
--     (1.12 setzt sonst nur die Globals this, event, arg1 ... arg9)
------------------------------------------------------------------------

local ARGS = {
    OnSizeChanged = function() return G.arg1, G.arg2 end,
    OnUpdate = function() return G.arg1 end,
    OnClick = function() return G.arg1, G.arg2 end,
    OnMouseDown = function() return G.arg1 end,
    OnMouseUp = function() return G.arg1 end,
    OnMouseWheel = function() return G.arg1 end,
    OnTextChanged = function() return G.arg1 end,
    OnValueChanged = function() return G.arg1 end,
    OnEvent = function()
        return G.event, G.arg1, G.arg2, G.arg3, G.arg4, G.arg5, G.arg6, G.arg7, G.arg8, G.arg9
    end,
    OnDragStart = function() return G.arg1 end,
    OnReceiveDrag = function() return G.arg1 end,
    OnChar = function() return G.arg1 end,
    OnKeyDown = function() return G.arg1 end,
    OnKeyUp = function() return G.arg1 end,
    OnHyperlinkClick = function() return G.arg1, G.arg2, G.arg3 end,
    OnHyperlinkEnter = function() return G.arg1, G.arg2 end,
    OnHyperlinkLeave = function() return G.arg1, G.arg2 end,
}

local function Adapt(event, fn)
    local getArgs = ARGS[event]
    return function(self, ...)
        if self == nil then
            self = G.this
            if getArgs then
                return fn(self, getArgs())
            end
            return fn(self)
        end
        if getArgs and select("#", ...) == 0 then
            return fn(self, getArgs())
        end
        return fn(self, ...)
    end
end

Try("CreateFrame-Huelle", function()
    local origCreateFrame = G.CreateFrame
    local function PatchFS(obj)
        if Compat.needFontStringPatch and type(obj) == "table" and obj.SetWordWrap == nil then
            obj.SetWordWrap = WordWrapImpl
            obj.GetWordWrap = GetWordWrapImpl
        end
        return obj
    end
    local function Wrap(f)
        if type(f) ~= "table" or f.fwWrapped then
            return f
        end
        f.fwWrapped = true
        if f.CreateFontString then
            local origFS = f.CreateFontString
            f.CreateFontString = function(self, ...)
                return PatchFS(origFS(self, ...))
            end
        end
        if f.SetScript then
            local origSet = f.SetScript
            f.SetScript = function(self, name, fn)
                if type(fn) == "function" then
                    fn = Adapt(name, fn)
                end
                return origSet(self, name, fn)
            end
        end
        if f.HookScript then
            local origHook = f.HookScript
            f.HookScript = function(self, name, fn)
                if type(fn) == "function" then
                    fn = Adapt(name, fn)
                end
                return origHook(self, name, fn)
            end
        end
        return f
    end
    G.CreateFrame = function(...)
        return Wrap(origCreateFrame(...))
    end
    Wrap(G.UIParent)
    Compat.diag.hull = "aktiv"
    Mark("CreateFrame-Huelle (Script-Argumente, FontString)")
end)

------------------------------------------------------------------------
-- Gruppe: GetNumGroupMembers, IsInGroup, IsInRaid
------------------------------------------------------------------------

Global("IsInRaid", function()
    return (G.GetNumRaidMembers and G.GetNumRaidMembers() or 0) > 0
end)

Global("IsInGroup", function()
    return (G.GetNumRaidMembers and G.GetNumRaidMembers() or 0) > 0
        or (G.GetNumPartyMembers and G.GetNumPartyMembers() or 0) > 0
end)

Global("GetNumGroupMembers", function()
    local raid = G.GetNumRaidMembers and G.GetNumRaidMembers() or 0
    if raid > 0 then
        return raid
    end
    local party = G.GetNumPartyMembers and G.GetNumPartyMembers() or 0
    if party > 0 then
        return party + 1
    end
    return 0
end)

------------------------------------------------------------------------
-- Namen: UnitFullName, GetNormalizedRealmName, Ambiguate
------------------------------------------------------------------------

Global("GetNormalizedRealmName", function()
    local realm = G.GetRealmName and G.GetRealmName()
    if type(realm) ~= "string" then
        return nil
    end
    return (string.gsub(realm, "[%s%-']", ""))
end)

Global("UnitFullName", function(unit)
    local name = G.UnitName(unit or "player")
    if not name then
        return nil
    end
    local realm
    if unit == nil or unit == "player" or G.UnitIsUnit(unit, "player") then
        realm = G.GetRealmName and G.GetRealmName() or nil
    end
    return name, realm
end)

Global("Ambiguate", function(name)
    return name
end)

------------------------------------------------------------------------
-- Kleinkram, den der Code abfragt
------------------------------------------------------------------------

Global("issecretvalue", function()
    return false
end)

Global("UnitInVehicle", function()
    return false
end)

Global("IsFlying", function()
    return false
end)

Global("WEAPON_SPEED", "Speed")
Global("INVTYPE_THROWN", "Thrown")
Global("INVTYPE_RANGEDRIGHT", "Ranged")
Global("RETRIEVING_ITEM_INFO", "Retrieving item information")

Global("GetContainerItemID", function(bag, slot)
    local link = G.GetContainerItemLink and G.GetContainerItemLink(bag, slot)
    if type(link) == "string" then
        return tonumber(string.match(link, "item:(%d+)"))
    end
    return nil
end)

Global("LootSlotHasItem", function(slot)
    return G.LootSlotIsItem and G.LootSlotIsItem(slot) and true or false
end)

-- 0 = leer, 1 = Gegenstand, 2 = Geld
Global("GetLootSlotType", function(slot)
    if G.LootSlotIsCoin and G.LootSlotIsCoin(slot) then
        return 2
    end
    if G.LootSlotIsItem and G.LootSlotIsItem(slot) then
        return 1
    end
    return 0
end)

-- Beute-Quelle: 1.12 kennt GetLootSourceInfo nicht. Die Leiche ist das Ziel, das
-- Mouseover oder (wenn die Maus schon weiter ist) die zuletzt angeschaute tote Einheit.
Try("GetLootSourceInfo", function()
    if G.GetLootSourceInfo ~= nil or not G.CreateFrame then return end
    local last, lastT = nil, 0
    local function Dead(unit)
        if not (G.UnitGUID and G.UnitExists and G.UnitExists(unit)) then return nil end
        if G.UnitIsDead and G.UnitIsDead(unit) and not G.UnitIsPlayer(unit) then
            local g = G.UnitGUID(unit)
            if type(g) == "string" then return g end
        end
        return nil
    end
    local f = G.CreateFrame("Frame", "FreewoodCompatLootWatch")
    f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:SetScript("OnEvent", function()
        local g = Dead("mouseover") or Dead("target")
        if g then
            last, lastT = g, (G.GetTime and G.GetTime() or 0)
        end
    end)
    Compat.lootSource = function()
        local g = Dead("target") or Dead("mouseover")
        if g then return g end
        if last and (G.GetTime and G.GetTime() or 0) - lastT < 10 then return last end
        return nil
    end
    G.GetLootSourceInfo = function(slot)
        local guid = Compat.lootSource()
        if not guid then return end
        local qty = 1
        if G.LootSlotIsCoin and G.LootSlotIsCoin(slot) then
            local _, text = G.GetLootSlotInfo(slot)
            qty = 0
            if type(text) == "string" then
                for n, unit in (string.gmatch or string.gfind)(text, "(%d+)%s*(%a+)") do
                    n = tonumber(n) or 0
                    local u = string.lower(unit)
                    if u == string.lower(G.GOLD or "gold") then qty = qty + n * 10000
                    elseif u == string.lower(G.SILVER or "silver") then qty = qty + n * 100
                    else qty = qty + n end
                end
            end
        else
            local _, _, q = G.GetLootSlotInfo(slot)
            qty = tonumber(q) or 1
            if qty < 1 then qty = 1 end
        end
        return guid, qty
    end
    Mark("GetLootSourceInfo")
end)

Global("ChatEdit_InsertLink", function(text)
    local box = G.ChatFrameEditBox
    if text and box and box:IsVisible() then
        box:Insert(text)
        return true
    end
    return false
end)

------------------------------------------------------------------------
-- Questlog: C_QuestLog.GetNumQuestLogEntries / GetInfo / GetQuestObjectives / IsComplete
-- Vorhanden sind nur GetLogIndexForQuestID, GetQuestIDForLogIndex und GetNumQuestObjectives.
------------------------------------------------------------------------

Try("C_QuestLog", function()
    local QL = Table("C_QuestLog")

    if QL.GetNumQuestLogEntries == nil and G.GetNumQuestLogEntries then
        QL.GetNumQuestLogEntries = function()
            return G.GetNumQuestLogEntries()
        end
        Mark("C_QuestLog.GetNumQuestLogEntries")
    end

    if QL.GetInfo == nil and G.GetQuestLogTitle then
        QL.GetInfo = function(index)
            local title, level, tag, isHeader, isCollapsed, isComplete = G.GetQuestLogTitle(index)
            if not title then
                return nil
            end
            local header = isHeader and true or false
            local id = 0
            if not header and QL.GetQuestIDForLogIndex then
                id = QL.GetQuestIDForLogIndex(index) or 0
            end
            return {
                title = title,
                level = level,
                questLogIndex = index,
                isHeader = header,
                isCollapsed = isCollapsed and true or false,
                isComplete = (isComplete == 1),
                isFailed = (isComplete == -1),
                questID = id,
                suggestedGroup = tag,
            }
        end
        Mark("C_QuestLog.GetInfo")
    end

    if QL.GetQuestObjectives == nil and G.GetNumQuestLeaderBoards and G.GetQuestLogLeaderBoard then
        QL.GetQuestObjectives = function(questID)
            local list = {}
            local index = QL.GetLogIndexForQuestID and QL.GetLogIndexForQuestID(questID)
            if not index or index <= 0 then
                return list
            end
            local count = G.GetNumQuestLeaderBoards(index) or 0
            for j = 1, count do
                local text, kind, done = G.GetQuestLogLeaderBoard(j, index)
                local have, need = string.match(text or "", "(%d+)%s*/%s*(%d+)")
                list[j] = {
                    text = text,
                    type = kind,
                    finished = done and true or false,
                    numFulfilled = tonumber(have) or (done and 1 or 0),
                    numRequired = tonumber(need) or 1,
                }
            end
            return list
        end
        Mark("C_QuestLog.GetQuestObjectives")
    end

    if QL.IsComplete == nil and G.GetQuestLogTitle then
        QL.IsComplete = function(questID)
            local index = QL.GetLogIndexForQuestID and QL.GetLogIndexForQuestID(questID)
            if not index or index <= 0 then
                return false
            end
            local _, _, _, isHeader, _, isComplete = G.GetQuestLogTitle(index)
            return (not isHeader) and isComplete == 1
        end
        Mark("C_QuestLog.IsComplete")
    end

    Global("GetQuestLogIndexByID", function(questID)
        local index = QL.GetLogIndexForQuestID and QL.GetLogIndexForQuestID(questID)
        return index or 0
    end)
end)

------------------------------------------------------------------------
-- Begleiter (Pet): C_PetInfo auf die eingebauten Funktionen abbilden
------------------------------------------------------------------------

Try("C_PetInfo", function()
    local PI = Table("C_PetInfo")
    if PI.GetPetHappiness == nil and G.GetPetHappiness then
        PI.GetPetHappiness = function()
            return G.GetPetHappiness()
        end
        Mark("C_PetInfo.GetPetHappiness")
    end
    if PI.GetPetFoodTypes == nil and G.GetPetFoodTypes then
        PI.GetPetFoodTypes = function()
            return G.GetPetFoodTypes()
        end
        Mark("C_PetInfo.GetPetFoodTypes")
    end
    if PI.GetPetTrainingPoints == nil and G.GetPetTrainingPoints then
        PI.GetPetTrainingPoints = function()
            return G.GetPetTrainingPoints()
        end
        Mark("C_PetInfo.GetPetTrainingPoints")
    end
end)

------------------------------------------------------------------------
-- Kleine Luecken in vorhandenen C_-Tabellen
------------------------------------------------------------------------

Try("C_Container", function()
    local C = Table("C_Container")
    if G.GetContainerNumSlots then
        Field(C, "C_Container", "GetContainerNumSlots", function(bag)
            return G.GetContainerNumSlots(bag)
        end)
    end
    if G.PickupContainerItem then
        Field(C, "C_Container", "PickupContainerItem", function(bag, slot)
            return G.PickupContainerItem(bag, slot)
        end)
    end
end)

Try("C_AddOns", function()
    local A = Table("C_AddOns")
    if G.GetAddOnMetadata then
        Field(A, "C_AddOns", "GetAddOnMetadata", function(addon, field)
            return G.GetAddOnMetadata(addon, field)
        end)
    end
end)

Try("C_MerchantFrame", function()
    local M = Table("C_MerchantFrame")
    if G.GetMerchantNumItems then
        Field(M, "C_MerchantFrame", "GetNumItems", function()
            return G.GetMerchantNumItems()
        end)
    end
end)

------------------------------------------------------------------------
-- Addon-Nachrichten: C_ChatInfo auf SendAddonMessage abbilden (RegisterAddonMessagePrefix gibt es in 1.12 nicht)
------------------------------------------------------------------------

Try("C_ChatInfo", function()
    local CI = Table("C_ChatInfo")
    if G.SendAddonMessage then
        Field(CI, "C_ChatInfo", "SendAddonMessage", function(prefix, text, channel, target)
            G.SendAddonMessage(prefix, text, channel or "PARTY", target)
            return 0
        end)
    end
    Field(CI, "C_ChatInfo", "RegisterAddonMessagePrefix", function()
        return true
    end)
    Field(CI, "C_ChatInfo", "IsAddonMessagePrefixRegistered", function()
        return true
    end)
end)

------------------------------------------------------------------------
-- Tooltips: C_TooltipInfo.* ueber einen versteckten Tooltip nachbauen.
-- Rueckgabe wie im Forever-Client: { lines = { { leftText, rightText }, ... } } oder nil.
-- Hinweis: "unit:"-Links kann 1.12 nicht anzeigen, GetHyperlink gibt dafuer nil zurueck.
------------------------------------------------------------------------

Try("C_TooltipInfo", function()
    local TI = Table("C_TooltipInfo")
    local TIP = "FreewoodCompatTip"
    local tip

    local function Prepare()
        if not tip then
            tip = CreateFrame("GameTooltip", TIP, UIParent, "GameTooltipTemplate")
        end
        tip:SetOwner(UIParent, "ANCHOR_NONE")
        tip:ClearLines()
        return tip
    end

    local function Collect()
        local count = tip:NumLines() or 0
        if count < 1 then
            return nil
        end
        local lines = {}
        for i = 1, count do
            local left = G[TIP .. "TextLeft" .. i]
            local right = G[TIP .. "TextRight" .. i]
            local lt = left and left:GetText() or nil
            local rt = right and right:GetText() or nil
            if rt == "" then
                rt = nil
            end
            lines[i] = { type = 0, leftText = lt, rightText = rt }
        end
        return { lines = lines }
    end

    local function Read(setter, ...)
        local t = Prepare()
        local ok = pcall(setter, t, ...)
        if not ok then
            return nil
        end
        return Collect()
    end

    Field(TI, "C_TooltipInfo", "GetUnit", function(unit)
        return Read(function(t, u) t:SetUnit(u) end, unit)
    end)

    Field(TI, "C_TooltipInfo", "GetHyperlink", function(link)
        if type(link) ~= "string" or string.find(link, "^unit:") then
            return nil
        end
        return Read(function(t, l) t:SetHyperlink(l) end, link)
    end)

    Field(TI, "C_TooltipInfo", "GetItemByID", function(id)
        id = tonumber(id)
        if not id then
            return nil
        end
        return Read(function(t, i) t:SetHyperlink("item:" .. i .. ":0:0:0") end, id)
    end)

    Field(TI, "C_TooltipInfo", "GetMerchantItem", function(index)
        return Read(function(t, i) t:SetMerchantItem(i) end, index)
    end)

    Field(TI, "C_TooltipInfo", "GetTrainerService", function(index)
        return Read(function(t, i) t:SetTrainerService(i) end, index)
    end)
end)

-- /fwguid: zeigt die GUID des Ziels und wie Freewood sie versteht (Diagnose)
do
    local G = _G
    G.SLASH_FWGUID1 = "/fwguid"
    G.SlashCmdList = G.SlashCmdList or {}
    G.SlashCmdList["FWGUID"] = function()
        local out = {}
        for _, u in ipairs({ "player", "target", "pet", "mouseover" }) do
            local g = G.UnitGUID and G.UnitGUID(u)
            if g then
                local FW = G.Freewood or G.FW
                local k, id
                local Util = FW and FW.Util
                if Util and Util.ParseHexGUID then k, id = Util.ParseHexGUID(g) end
                out[#out + 1] = u .. "=" .. tostring(g) .. " -> " .. tostring(k) .. " " .. tostring(id)
            end
        end
        local FWx = G.Freewood
        local R = FWx and FWx.Codex and FWx.Codex.Roles
        local d = R and R.diag
        if d then
            out[#out + 1] = "Haendler: n=" .. tostring(d.count) .. " id=" .. tostring(d.id) .. " name=" .. tostring(d.name) ..
                " preis=" .. tostring(d.price) .. " link=" .. tostring(d.link)
        end
        local msg = "Freewood GUID: " .. (#out > 0 and table.concat(out, " | ") or "keine Einheit")
        if G.DEFAULT_CHAT_FRAME then G.DEFAULT_CHAT_FRAME:AddMessage(msg) end
    end
end

-- /fwdisp <npcID>: Diagnose fuer die Kreaturenbilder
do
    local G = _G
    G.SLASH_FWDISP1 = "/fwdisp"
    G.SlashCmdList = G.SlashCmdList or {}
    G.SlashCmdList["FWDISP"] = function(msg)
        local id = tonumber(msg) or 823
        local C = G.C_CreatureInfo
        local P = function(t) if G.DEFAULT_CHAT_FRAME then G.DEFAULT_CHAT_FRAME:AddMessage("Freewood Bild: " .. t) end end
        P("C_CreatureInfo=" .. tostring(C ~= nil) .. " Request=" .. tostring(C and C.RequestLoadCreatureByID ~= nil) ..
            " Info=" .. tostring(C and C.GetCreatureInfoByID ~= nil) .. " Portrait=" .. tostring(G.SetPortraitTextureFromCreatureDisplayID ~= nil))
        local before = C and C.GetCreatureInfoByID and C.GetCreatureInfoByID(id)
        P("ID " .. id .. " vorher im Cache: " .. tostring(before and before.displayID or "nein"))
        local f = G.Freewood
        local st = f and f.Codex and f.Codex.dispStats
        if st then P("gelesen=" .. st.read .. " fehlgeschlagen=" .. st.fail .. " gezeigt=" .. st.shown) end
        if C and C.RequestLoadCreatureByID then
            local fr = G.CreateFrame("Frame")
            fr:RegisterEvent("CREATURE_DATA_LOAD_RESULT")
            fr:SetScript("OnEvent", function(_, _, a1, a2)
                local info = C.GetCreatureInfoByID(id)
                P("Antwort: id=" .. tostring(a1 or G.arg1) .. " ok=" .. tostring(a2 or G.arg2) .. " displayID=" .. tostring(info and info.displayID))
                fr:UnregisterAllEvents()
            end)
            P("Anfrage: " .. tostring(C.RequestLoadCreatureByID(id)))
        end
    end
end

------------------------------------------------------------------------
-- table.remove / table.insert: auf OctoWoW entfernte table.remove teils nichts.
-- Selbsttest beim Laden; ist etwas kaputt, ersetzen wir beide durch eigene Fassungen.
------------------------------------------------------------------------

Try("table-Ersatz", function()
    -- Die eingebauten Fassungen versagen auf Octo in manchen Aufrufen (z.B. mit der Schleifenvariable als Position):
    -- das Element bleibt stehen und wird immer wieder bearbeitet. Wir ersetzen beide immer durch eigene Fassungen.
    local table = G.table
    local function Len(t)
        return #t
    end
    table.remove = function(t, pos)
        local n = Len(t)
        if n == 0 then return nil end
        if pos == nil then pos = n end
        pos = math.floor(tonumber(pos) or n)
        if pos < 1 or pos > n then return nil end
        local v = t[pos]
        local i = pos
        while i < n do
            t[i] = t[i + 1]
            i = i + 1
        end
        t[n] = nil
        return v
    end
    table.insert = function(t, a, b)
        local n = Len(t)
        if b == nil then
            t[n + 1] = a
            return
        end
        local pos = math.floor(tonumber(a) or (n + 1))
        if pos < 1 then pos = 1 end
        if pos > n + 1 then pos = n + 1 end
        local i = n
        while i >= pos do
            t[i + 1] = t[i]
            i = i - 1
        end
        t[pos] = b
    end
    Compat.tableOk = true
    Mark("table.remove/insert (immer eigene Fassung)")
end)

------------------------------------------------------------------------
-- C_Timer.After, falls es fehlt
------------------------------------------------------------------------

Try("C_Timer.After", function()
    local CT = Table("C_Timer")
    if CT.After then return end
    local frame = G.CreateFrame("Frame")
    local list, count, now = {}, 0, 0
    frame:SetScript("OnUpdate", function()
        local dt = G.arg1 or 0
        now = now + dt
        if count == 0 then return end
        local keep, kc = {}, 0
        local due, dc = {}, 0
        for i = 1, count do
            local e = list[i]
            if e.at <= now then
                dc = dc + 1
                due[dc] = e
            else
                kc = kc + 1
                keep[kc] = e
            end
        end
        list, count = keep, kc
        for i = 1, dc do
            pcall(due[i].fn)
        end
    end)
    CT.After = function(delay, fn)
        count = count + 1
        list[count] = { at = now + (tonumber(delay) or 0), fn = fn }
    end
    Mark("C_Timer.After")
end)

------------------------------------------------------------------------
-- C_EncodingUtil in reinem Lua (Octo hat es nicht):
--   SerializeCBOR/DeserializeCBOR  eigenes, selbst beschreibendes Textformat (kein echtes CBOR)
--   CompressString/DecompressString nur ein Kopfzeichen (keine Kompression)
--   EncodeBase64/DecodeBase64      normales Base64
-- Beide Seiten sind Freewood, daher reicht ein gemeinsames eigenes Format.
------------------------------------------------------------------------

Try("C_EncodingUtil", function()
    local E = Table("C_EncodingUtil")
    local sfind, ssub, sbyte, schar, sformat = string.find, string.sub, string.byte, string.char, string.format
    local floor = math.floor

    local function Ser(v, out, st, depth)
        local tv = type(v)
        st.n = st.n + 1
        if st.n > 60000 or depth > 32 then error("zu gross") end
        if tv == "boolean" then
            st.o = st.o + 1; out[st.o] = v and "T" or "F"
        elseif tv == "number" then
            if v ~= v or v == math.huge or v == -math.huge then error("Zahl") end
            st.o = st.o + 1; out[st.o] = "n" .. sformat("%.17g", v) .. ";"
        elseif tv == "string" then
            st.o = st.o + 1; out[st.o] = "s" .. string.len(v) .. ":" .. v
        elseif tv == "table" then
            st.o = st.o + 1; out[st.o] = "{"
            for k, val in pairs(v) do
                local tk, tvv = type(k), type(val)
                if (tk == "string" or tk == "number") and (tvv == "string" or tvv == "number" or tvv == "boolean" or tvv == "table") then
                    Ser(k, out, st, depth + 1)
                    Ser(val, out, st, depth + 1)
                end
            end
            st.o = st.o + 1; out[st.o] = "}"
        else
            error("Typ")
        end
    end

    local function Rd(s, st, depth)
        st.n = st.n + 1
        if st.n > 60000 or depth > 32 then error("zu gross") end
        local pos = st.pos
        local c = ssub(s, pos, pos)
        if c == "T" then st.pos = pos + 1 return true end
        if c == "F" then st.pos = pos + 1 return false end
        if c == "n" then
            local e = sfind(s, ";", pos, true)
            if not e then error("n") end
            local num = tonumber(ssub(s, pos + 1, e - 1))
            if not num then error("n") end
            st.pos = e + 1
            return num
        end
        if c == "s" then
            local e = sfind(s, ":", pos, true)
            if not e then error("s") end
            local len = tonumber(ssub(s, pos + 1, e - 1))
            if not len or len < 0 or e + len > string.len(s) then error("s") end
            st.pos = e + len + 1
            return ssub(s, e + 1, e + len)
        end
        if c == "{" then
            local tbl = {}
            st.pos = pos + 1
            while true do
                local p = st.pos
                local ch = ssub(s, p, p)
                if ch == "}" then st.pos = p + 1 return tbl end
                if ch == "" then error("Ende") end
                local k = Rd(s, st, depth + 1)
                if type(k) ~= "string" and type(k) ~= "number" then error("Schluessel") end
                tbl[k] = Rd(s, st, depth + 1)
            end
        end
        error("Zeichen")
    end

    E.SerializeCBOR = function(value)
        local out = {}
        Ser(value, out, { n = 0, o = 0 }, 1)
        return table.concat(out)
    end
    E.DeserializeCBOR = function(s)
        if type(s) ~= "string" then error("kein Text") end
        local st = { pos = 1, n = 0 }
        local v = Rd(s, st, 1)
        if st.pos ~= string.len(s) + 1 then error("Rest") end
        return v
    end
    E.CompressString = function(s) return "0" .. s end
    E.DecompressString = function(s)
        if type(s) ~= "string" or ssub(s, 1, 1) ~= "0" then error("Kopf") end
        return ssub(s, 2)
    end

    local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local REV = {}
    for i = 1, 64 do REV[sbyte(ALPHA, i)] = i - 1 end

    E.EncodeBase64 = function(s)
        local out, oc = {}, 0
        local len = string.len(s)
        local i = 1
        while i <= len do
            -- einzeln lesen: string.byte liefert in diesem Lua (5.0) nur ein Zeichen
            local b1, b2, b3 = sbyte(s, i), sbyte(s, i + 1), sbyte(s, i + 2)
            local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
            local c1 = floor(n / 262144)
            local r = n - c1 * 262144
            local c2 = floor(r / 4096)
            r = r - c2 * 4096
            local c3 = floor(r / 64)
            local c4 = r - c3 * 64
            oc = oc + 1
            out[oc] = ssub(ALPHA, c1 + 1, c1 + 1) .. ssub(ALPHA, c2 + 1, c2 + 1)
                .. (b2 and ssub(ALPHA, c3 + 1, c3 + 1) or "=") .. (b3 and ssub(ALPHA, c4 + 1, c4 + 1) or "=")
            i = i + 3
        end
        return table.concat(out)
    end

    E.DecodeBase64 = function(s)
        if type(s) ~= "string" then error("kein Text") end
        local len = string.len(s)
        if len == 0 then return "" end
        if floor(len / 4) * 4 ~= len then error("Laenge") end
        local out, oc = {}, 0
        local i = 1
        while i <= len do
            local a, b, c, d = sbyte(s, i), sbyte(s, i + 1), sbyte(s, i + 2), sbyte(s, i + 3)
            local v1, v2 = REV[a], REV[b]
            local v3, v4 = REV[c], REV[d]
            if not v1 or not v2 then error("Zeichen") end
            local pad3, pad4 = (c == 61), (d == 61)
            if (not v3 and not pad3) or (not v4 and not pad4) or (pad3 and not pad4) then error("Zeichen") end
            local n = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
            local x1 = floor(n / 65536)
            local r = n - x1 * 65536
            local x2 = floor(r / 256)
            local x3 = r - x2 * 256
            oc = oc + 1
            if pad3 then
                out[oc] = schar(x1)
            elseif pad4 then
                out[oc] = schar(x1, x2)
            else
                out[oc] = schar(x1, x2, x3)
            end
            i = i + 4
        end
        return table.concat(out)
    end
    Mark("C_EncodingUtil (Eigenbau)")
end)

------------------------------------------------------------------------
-- Datenaustausch ueber den eigenen Kanal ("Freewood...").
-- Octo kennt keine Addon-Nachrichten im Kanal; wir senden normalen Kanaltext
--   <Praefix>^<Text mit maskierten Sonderzeichen>
-- und geben Empfangenes wie ein CHAT_MSG_ADDON (prefix, text, "CHANNEL", sender) an Freewood weiter.
-- Maskierung: ~ -> ~0, | -> ~1, Steuerzeichen -> ~2 (verlustbehaftet, kommt im Protokoll nicht vor)
------------------------------------------------------------------------

Try("Kanal-Transport", function()
    local Net = { sent = 0, got = 0, rejected = 0, deferred = 0, blocks = 0, minGap = 1.2, lastError = "" }
    Compat.Net = Net

    local function Esc(s)
        s = string.gsub(s, "~", "~0")
        s = string.gsub(s, "|", "~1")
        s = string.gsub(s, "[\1-\31]", "~2")
        return s
    end
    local function Unesc(s)
        return (string.gsub(s, "~(%d)", function(d)
            if d == "0" then return "~" end
            if d == "1" then return "|" end
            return ""
        end))
    end
    Net.Esc, Net.Unesc = Esc, Unesc

    local CI = Table("C_ChatInfo")
    local realSend = G.SendAddonMessage
    CI.SendAddonMessage = function(prefix, text, dist, target)
        if dist == "CHANNEL" then
            local id = tonumber(target)
            if not id and G.GetChannelName and type(target) == "string" then
                id = G.GetChannelName(target)
            end
            if type(id) ~= "number" or id <= 0 then
                Net.lastError = "kein Kanal"
                return 1
            end
            -- Der Server erlaubt nur begrenzt viele Zeilen und sperrt sonst ("You must wait N seconds before speaking again").
            -- Wir halten Abstand und senden waehrend einer Sperre nichts; 3 = gebremst, die Module versuchen es spaeter erneut.
            local now = G.GetTime and G.GetTime() or 0
            if now < (Net.blockedUntil or 0) or now - (Net.lastSend or -100) < Net.minGap then
                Net.deferred = Net.deferred + 1
                return 3
            end
            local wire = tostring(prefix) .. "^" .. Esc(tostring(text))
            if string.len(wire) > 255 then
                Net.rejected = Net.rejected + 1
                Net.lastError = "zu lang (" .. string.len(wire) .. ")"
                return 2
            end
            local ok, err = pcall(G.SendChatMessage, wire, "CHANNEL", nil, id)
            if not ok then
                Net.lastError = tostring(err)
                return 1
            end
            Net.sent = Net.sent + 1
            Net.lastSend = now
            return 0
        end
        if realSend then
            local ok = pcall(realSend, prefix, text, dist or "PARTY", target)
            return ok and 0 or 1
        end
        return 1
    end
    Mark("C_ChatInfo.SendAddonMessage (Kanal)")

    -- Sperrmeldung des Servers auswerten
    local errFrame = G.CreateFrame("Frame")
    errFrame:RegisterEvent("UI_ERROR_MESSAGE")
    pcall(errFrame.RegisterEvent, errFrame, "CHAT_MSG_SYSTEM")
    errFrame:SetScript("OnEvent", function()
        local msg = G.arg1
        if type(msg) ~= "string" then return end
        local a, b, secs = string.find(string.lower(msg), "must wait (%d+) seconds? before speaking")
        if a then
            local n = tonumber(secs) or 10
            Net.blockedUntil = (G.GetTime and G.GetTime() or 0) + n + 1
            Net.blocks = Net.blocks + 1
            Net.minGap = math.min(4, Net.minGap + 0.4)   -- danach etwas langsamer senden
        end
    end)

    local function IsOurs(cname)
        return type(cname) == "string" and string.find(cname, "Freewood", 1, true) ~= nil
    end

    local frame = G.CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_CHANNEL")
    frame:SetScript("OnEvent", function()
        local text, sender, cname = G.arg1, G.arg2, G.arg9
        if not IsOurs(cname) or type(text) ~= "string" or type(sender) ~= "string" then return end
        local p = string.find(text, "^", 1, true)
        if not p or p < 3 or p > 20 then return end
        local prefix = string.sub(text, 1, p - 1)
        if string.sub(prefix, 1, 2) ~= "FW" then return end
        Net.got = Net.got + 1
        local FW = G.Freewood
        if FW and FW.InjectEvent then
            FW:InjectEvent("CHAT_MSG_ADDON", prefix, Unesc(string.sub(text, p + 1)), "CHANNEL", sender)
        end
    end)

    -- Datenzeilen und Beitrittsmeldungen unseres Kanals aus dem Chat heraushalten
    if type(G.ChatFrame_AddMessageEventFilter) == "function" then
        local function Hide(_, _, _, _, _, cn)
            cn = cn or G.arg9
            if IsOurs(cn) then return true end
            return false
        end
        pcall(G.ChatFrame_AddMessageEventFilter, "CHAT_MSG_CHANNEL", Hide)
        pcall(G.ChatFrame_AddMessageEventFilter, "CHAT_MSG_CHANNEL_NOTICE", Hide)
        pcall(G.ChatFrame_AddMessageEventFilter, "CHAT_MSG_CHANNEL_JOIN", Hide)
        pcall(G.ChatFrame_AddMessageEventFilter, "CHAT_MSG_CHANNEL_LEAVE", Hide)
        Net.filter = true
    end
end)

-- /fwchan: Zustand des Datenaustauschs
Try("fwchan", function()
    G.SLASH_FWCHAN1 = "/fwchan"
    G.SlashCmdList = G.SlashCmdList or {}
    G.SlashCmdList["FWCHAN"] = function()
        local P = function(t) if G.DEFAULT_CHAT_FRAME then G.DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffFWChan|r " .. t) end end
        local N = Compat.Net or {}
        P("table ok=" .. tostring(Compat.tableOk) .. "  Filter=" .. tostring(N.filter) ..
            "  gesendet=" .. tostring(N.sent) .. "  empfangen=" .. tostring(N.got) ..
            "  zu lang=" .. tostring(N.rejected) .. "  gebremst=" .. tostring(N.deferred) .. "  Sperren=" .. tostring(N.blocks) .. "  Abstand=" .. tostring(N.minGap) .. "  letzter Fehler=" .. tostring(N.lastError))
        local names = { "FreewoodCodex", "FreewoodBeasts", "FreewoodBrett" }
        for i = 1, 3 do
            local id = G.GetChannelName and G.GetChannelName(names[i])
            P(names[i] .. ": Kanal " .. tostring(id))
        end
        local E = G.C_EncodingUtil
        P("Verpackung: " .. tostring(E and E.SerializeCBOR ~= nil))
    end
end)

------------------------------------------------------------------------
-- /fwnpc <ID>: fragt eine Kreatur ueber ihre ID ab und zeigt ALLES, was der Client dazu liefert
-- (C_CreatureInfo.GetCreatureInfoByID, RequestLoadCreatureByID + Antwort-Ereignis, Typ- und Familien-Auskunft).
-- Die Ausgabe steht im Chat und wird in FreewoodDB.npcProbe[ID] abgelegt (SavedVariables, nach /reload lesbar).
------------------------------------------------------------------------

Try("fwnpc", function()
    G.SLASH_FWNPC1 = "/fwnpc"
    G.SlashCmdList = G.SlashCmdList or {}

    local function Dump(v, depth, seen)
        local t = type(v)
        if t ~= "table" then return tostring(v) end
        if depth > 3 or seen[v] then return "{...}" end
        seen[v] = true
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local out = {}
        for i = 1, #keys do
            out[i] = tostring(keys[i]) .. "=" .. Dump(v[keys[i]], depth + 1, seen)
        end
        return "{" .. table.concat(out, ", ") .. "}"
    end

    G.SlashCmdList["FWNPC"] = function(msg)
        local id = tonumber(msg)
        local lines = {}
        local function P(text)
            lines[#lines + 1] = text
            if G.DEFAULT_CHAT_FRAME then G.DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffFWNpc|r " .. text) end
        end
        if not id then P("Aufruf: /fwnpc <Kreatur-ID>   zum Beispiel /fwnpc 51600") return end
        local C = G.C_CreatureInfo
        if not C then P("C_CreatureInfo fehlt") return end

        local function Info(label)
            local ok, info = pcall(C.GetCreatureInfoByID, id)
            P(label .. " GetCreatureInfoByID(" .. id .. "): " .. (ok and Dump(info, 1, {}) or ("Fehler: " .. tostring(info))))
            return ok and info or nil
        end
        local function Details(info)
            if type(info) ~= "table" then return end
            for k, v in pairs(info) do
                local kl = string.lower(tostring(k))
                if type(v) == "number" and (string.find(kl, "type", 1, true) and C.GetCreatureTypeInfo) then
                    local ok, r = pcall(C.GetCreatureTypeInfo, v)
                    P("  GetCreatureTypeInfo(" .. tostring(v) .. ") [" .. tostring(k) .. "]: " .. (ok and Dump(r, 1, {}) or tostring(r)))
                end
                if type(v) == "number" and (string.find(kl, "family", 1, true) and C.GetCreatureFamilyInfo) then
                    local ok, r = pcall(C.GetCreatureFamilyInfo, v)
                    P("  GetCreatureFamilyInfo(" .. tostring(v) .. ") [" .. tostring(k) .. "]: " .. (ok and Dump(r, 1, {}) or tostring(r)))
                end
            end
        end

        local before = Info("vorher:")
        Details(before)
        if C.GetCreatureTypeIDs then
            local ok, r = pcall(C.GetCreatureTypeIDs)
            P("GetCreatureTypeIDs: " .. (ok and Dump(r, 1, {}) or tostring(r)))
        end

        local db = G.FreewoodDB
        local function Save()
            if type(db) == "table" then
                db.npcProbe = db.npcProbe or {}
                db.npcProbe[id] = lines
            end
        end

        if not C.RequestLoadCreatureByID then
            P("RequestLoadCreatureByID fehlt")
            Save()
            return
        end
        local fr = G.CreateFrame("Frame")
        local done = false
        local function Finish(why)
            if done then return end
            done = true
            fr:UnregisterAllEvents()
            P("--- " .. why)
            local after = Info("nachher:")
            Details(after)
            Save()
        end
        fr:RegisterEvent("CREATURE_DATA_LOAD_RESULT")
        fr:SetScript("OnEvent", function()
            P("Ereignis CREATURE_DATA_LOAD_RESULT: " .. tostring(G.arg1) .. ", " .. tostring(G.arg2) .. ", " .. tostring(G.arg3))
            Finish("Antwort erhalten")
        end)
        local ok, r = pcall(C.RequestLoadCreatureByID, id)
        P("RequestLoadCreatureByID(" .. id .. "): " .. tostring(ok and r or ("Fehler: " .. tostring(r))))
        if G.C_Timer and G.C_Timer.After then
            G.C_Timer.After(3, function() Finish("nach 3 Sekunden") end)
        else
            Finish("sofort (kein Zeitgeber)")
        end
    end
end)

------------------------------------------------------------------------
-- /fwmap: Kartenprobe. Zeigt, welche Karten-Funktionen/Frames diese Octo-Karte wirklich hat
-- und ob sich eine Zone per ID umschalten laesst. Aendert nur die angezeigte Karte, sonst nichts.
------------------------------------------------------------------------

Try("fwmap", function()
    G.SLASH_FWMAP1 = "/fwmap"
    G.SlashCmdList = G.SlashCmdList or {}
    G.SlashCmdList["FWMAP"] = function(msg)
        local lines = {}
        local function P(text)
            lines[#lines + 1] = text
            if G.DEFAULT_CHAT_FRAME then G.DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffFWMap|r " .. text) end
        end
        local function Call(name, a, b)
            local f = G[name]
            if type(f) ~= "function" then return "fehlt" end
            local r = { pcall(f, a, b) }
            local out = {}
            for i = 2, 6 do if r[i] ~= nil then out[table.getn(out) + 1] = tostring(r[i]) end end
            if not r[1] then return "FEHLER " .. tostring(r[2]) end
            return table.concat(out, ",")
        end
        local function Has(obj, names)
            local out = {}
            for i = 1, table.getn(names) do
                local v = obj[names[i]]
                out[i] = names[i] .. "=" .. (v ~= nil and (type(v) == "function" and "ja" or type(v)) or "nein")
            end
            return table.concat(out, " ")
        end

        local globals = { "SetMapByID", "SetMapZoom", "SetMapToCurrentZone", "GetCurrentMapAreaID", "GetCurrentMapContinent",
            "GetCurrentMapZone", "GetMapContinents", "GetMapZones", "ToggleWorldMap", "GetPlayerMapPosition", "GetMapInfo",
            "GetNumMapLandmarks", "ProcessMapClick", "GetCursorPosition" }
        for i = 1, table.getn(globals) do
            P(globals[i] .. ": " .. (type(G[globals[i]]) == "function" and "ja" or "nein"))
        end
        P("Anfangszustand: Areal=" .. Call("GetCurrentMapAreaID") .. " Kontinent=" .. Call("GetCurrentMapContinent")
            .. " Zone=" .. Call("GetCurrentMapZone") .. " MapInfo=" .. Call("GetMapInfo"))

        local wm = G.WorldMapFrame
        if not wm then P("WorldMapFrame: FEHLT (Blizzard_WorldMap evtl. nicht geladen, Karte einmal oeffnen)") end
        if wm then
            P("WorldMapFrame sichtbar=" .. tostring(wm:IsShown()) .. " " .. Has(wm, { "SetMapID", "GetMapID", "GetCanvas", "ScrollContainer", "OnMapChanged", "HookScript" }))
        end
        local fr = { "WorldMapDetailFrame", "WorldMapButton", "WorldMapContinentDropDown", "WorldMapZoneDropDown", "WorldMapPlayer" }
        for i = 1, table.getn(fr) do
            local f = G[fr[i]]
            if f then
                local w, h = 0, 0
                if f.GetWidth then w, h = f:GetWidth() or 0, f:GetHeight() or 0 end
                P(fr[i] .. ": da " .. math.floor(w) .. "x" .. math.floor(h) .. " sichtbar=" .. tostring(f.IsShown and f:IsShown())
                    .. " " .. Has(f, { "SetClipsChildren", "CreateTexture", "CreateFontString" }))
            else
                P(fr[i] .. ": fehlt")
            end
        end
        local tex = (G.WorldMapButton or G.WorldMapFrame)
        if tex and tex.CreateTexture then
            local ok, t = pcall(tex.CreateTexture, tex, nil, "OVERLAY")
            if ok and t then
                P("Textur: " .. Has(t, { "SetColorTexture", "SetTexture", "SetVertexColor", "SetRotation", "SetTexCoord", "AddMaskTexture", "SetRotation" }))
            end
        end

        local CM = G.C_Map
        if type(CM) == "table" then
            local keys = {}
            for k in pairs(CM) do keys[table.getn(keys) + 1] = tostring(k) end
            table.sort(keys)
            P("C_Map: " .. table.concat(keys, ", "))
        else
            P("C_Map: nein")
        end

        -- Zone per ID umschalten testen (Durotar 14, Elwynn 12)
        local tests = { 14, 12 }
        for i = 1, table.getn(tests) do
            local id = tests[i]
            local before = Call("GetCurrentMapAreaID")
            local r1 = Call("SetMapByID", id)
            P("SetMapByID(" .. id .. "): " .. r1 .. " | Areal " .. before .. " -> " .. Call("GetCurrentMapAreaID")
                .. " Kont=" .. Call("GetCurrentMapContinent") .. " Zone=" .. Call("GetCurrentMapZone"))
        end
        if type(CM) == "table" and type(CM.SetMapID) == "function" then
            P("C_Map.SetMapID(14): " .. tostring(pcall(CM.SetMapID, 14)) .. " -> Areal " .. Call("GetCurrentMapAreaID"))
        end
        local r = Call("SetMapZoom", 1, 1)
        P("SetMapZoom(1,1): " .. r .. " -> Areal " .. Call("GetCurrentMapAreaID") .. " Kont=" .. Call("GetCurrentMapContinent") .. " Zone=" .. Call("GetCurrentMapZone"))
        P("Zurueck: SetMapToCurrentZone " .. Call("SetMapToCurrentZone") .. " -> Areal " .. Call("GetCurrentMapAreaID"))

        G.FreewoodDB = G.FreewoodDB or {}
        G.FreewoodDB.mapProbe = lines
    end
end)

------------------------------------------------------------------------
-- /fwah: Auktionshaus-Probe. Zeigt, welche Funktionen/Ereignisse es gibt und was eine Abfrage liefert.
--   /fwah          Zustand (Funktionen, Fenster, aktuelle Liste)
--   /fwah query [Seite]   sendet eine leere Abfrage und gibt das Ergebnis aus (Auktionshaus muss offen sein)
------------------------------------------------------------------------

Try("fwah", function()
    G.SLASH_FWAH1 = "/fwah"
    G.SlashCmdList = G.SlashCmdList or {}
    local lines = {}
    local function P(text)
        lines[#lines + 1] = text
        if G.DEFAULT_CHAT_FRAME then G.DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffFWAh|r " .. text) end
        G.FreewoodDB = G.FreewoodDB or {}
        G.FreewoodDB.ahProbe = lines
    end
    local function Res(r)
        local out = {}
        for i = 2, 16 do
            local v = r[i]
            if v ~= nil or i < 14 then out[#out + 1] = tostring(v) end
        end
        while #out > 0 and out[#out] == "nil" do out[#out] = nil end
        return table.concat(out, " | ")
    end
    local counts, opened = {}, false
    local watch = G.CreateFrame("Frame")
    local events = { "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_ITEM_LIST_UPDATE", "AUCTION_OWNED_LIST_UPDATE", "AUCTION_BIDDER_LIST_UPDATE" }
    for i = 1, #events do pcall(watch.RegisterEvent, watch, events[i]) end
    local wantDump = false
    local function Dump(tag)
        local f = G.GetNumAuctionItems
        if type(f) ~= "function" then P("GetNumAuctionItems fehlt") return end
        local r = { pcall(f, "list") }
        P(tag .. " GetNumAuctionItems(list): " .. Res(r))
        local n = tonumber(r[2]) or 0
        for i = 1, math.min(3, n) do
            local info = { pcall(G.GetAuctionItemInfo, "list", i) }
            P("  [" .. i .. "] Info: " .. Res(info))
            if type(G.GetAuctionItemLink) == "function" then
                local l = { pcall(G.GetAuctionItemLink, "list", i) }
                P("  [" .. i .. "] Link: " .. tostring(l[2]))
            end
        end
    end
    watch:SetScript("OnEvent", function()
        local e = G.event
        counts[e] = (counts[e] or 0) + 1
        if e == "AUCTION_HOUSE_SHOW" then opened = true end
        if e == "AUCTION_HOUSE_CLOSED" then opened = false end
        if e == "AUCTION_ITEM_LIST_UPDATE" and wantDump then
            wantDump = false
            Dump("Ereignis AUCTION_ITEM_LIST_UPDATE (Anzahl " .. counts[e] .. ")")
        end
    end)

    G.SlashCmdList["FWAH"] = function(msg)
        msg = msg or ""
        local page = tonumber(string.match(msg, "query%s*(%d*)")) or 0
        if string.find(msg, "^query") then
            if type(G.QueryAuctionItems) ~= "function" then P("QueryAuctionItems fehlt") return end
            local can = type(G.CanSendAuctionQuery) == "function" and { pcall(G.CanSendAuctionQuery) } or nil
            P("CanSendAuctionQuery: " .. (can and Res(can) or "fehlt"))
            wantDump = true
            local r = { pcall(G.QueryAuctionItems, "", nil, nil, 0, 0, 0, page, 0, 0) }
            P("QueryAuctionItems(Seite " .. page .. "): " .. Res(r))
            return
        end
        local names = { "QueryAuctionItems", "GetNumAuctionItems", "GetAuctionItemInfo", "GetAuctionItemLink", "CanSendAuctionQuery",
            "GetAuctionItemClasses", "GetAuctionItemSubClasses", "GetAuctionSort", "SetAuctionsTabShowing", "AuctionFrameBrowse_Update",
            "GetSelectedAuctionItem", "PlaceAuctionBid", "GetItemInfo" }
        local out = {}
        for i = 1, #names do out[#out + 1] = names[i] .. "=" .. (type(G[names[i]]) == "function" and "ja" or "nein") end
        P(table.concat(out, " "))
        local ah = G.C_AuctionHouse
        if type(ah) == "table" then
            local k = {}
            for key in pairs(ah) do k[#k + 1] = tostring(key) end
            table.sort(k)
            P("C_AuctionHouse: " .. table.concat(k, ", "))
        else
            P("C_AuctionHouse: nein")
        end
        P("AuctionFrame=" .. tostring(G.AuctionFrame ~= nil) .. (G.AuctionFrame and (" sichtbar=" .. tostring(G.AuctionFrame:IsShown())) or "")
            .. " AuctionHouseFrame=" .. tostring(G.AuctionHouseFrame ~= nil) .. " Blizzard_AuctionUI geladen=" .. tostring(G.IsAddOnLoaded and G.IsAddOnLoaded("Blizzard_AuctionUI")))
        local c = {}
        for i = 1, #events do c[#c + 1] = events[i] .. "=" .. (counts[events[i]] or 0) end
        P("Ereignisse seit /reload: " .. table.concat(c, " ") .. "  offen=" .. tostring(opened))
        Dump("Jetzt")
        P("Weiter mit: /fwah query   (und /fwah query 1 fuer die zweite Seite)")
    end
end)
