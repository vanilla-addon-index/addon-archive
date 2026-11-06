-- Freewood-OctoWoW-Mail: eigenes Briefkasten (Logik).
--
-- Posteingang   "Alle oeffnen" / "Nur Ausgewaehlte oeffnen": nimmt Gold und Items, ein Schritt nach dem anderen.
--               - loescht und retourniert nie einen Brief; Nachnahme-Briefe und reine Briefe bleiben unberuehrt
--               - ein Taschenplatz bleibt immer frei (Items bleiben sonst im Briefkasten)
--               - nach jedem Schritt wird der Posteingang neu gelesen (die Nummern verschieben sich)
-- Senden        Empfaenger mit den letzten 5, mehrere Items (je Item ein Brief, nacheinander), Gold, Nachnahme
-- Mailinglisten Namen mit Items, optional Gold-Ueberschuss und Automatik beim Oeffnen des Briefkastens
--
-- Alle Sendungen laufen ueber dieselbe Warteschlange (Mail.send): ein Brief, dann auf MAIL_SEND_SUCCESS warten,
-- dann Pause, dann der naechste. Sie laufen nie, solange ein Brett-Auftrag einen Brief vorbereitet (BoardBusy).
--
-- Gespeichert: Account-weit Mail.db = { settings, recipients, lists }.

local ADDON, NS = ...

local FW = _G.Freewood
if not FW or not FW:RequireAPI(1, ADDON) then
    return
end

local Util = FW.Util
local L = FW.L

local MAX_RECENT = 5
local MAX_LISTS = 30
local MAX_ITEMS_PER_LIST = 60
local MAX_JOBS = 120
local STEP = 0.1            -- Takt des Treibers
local INBOX_GAP = 0.5       -- Pause nach dem Nehmen
local INBOX_TIMEOUT = 2.5   -- so lange auf die Antwort des Servers warten
local GAP_START = 0.4       -- Pause nach jedem gesendeten Brief: Start, wird dynamisch angepasst
local GAP_MIN = 0.25
local GAP_MAX = 4
local MAX_RETRY = 3         -- so oft wird ein vom Server abgelehnter Brief mit langsamerem Tempo wiederholt
local SEND_TIMEOUT = 8
local POSTAGE = 30          -- Kupfer je Brief (Schaetzung fuer den Gold-Ueberschuss)
local AUTO_DELAY = 2.5
local KEEP_FREE = 1         -- so viele Taschenplaetze bleiben beim Oeffnen immer frei

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

local Mail = FW:NewModule("Mail", {
    version = GetMeta("Version") or "dev",
    title = L.MAIL_TITLE,
    description = L.MAIL_DESC,
    defaults = {
        settings = { replace = false, chat = true, cleanup = true, archiveDays = 0, boardAuto = true },
        recipients = {},
        lists = {},
        archive = {},          -- entfernte Briefe, neueste zuerst
        sentSubjects = {},     -- Betreffe, die wir selbst ohne Text gesendet haben (Betreff -> Zeit)
    },
})
NS.Mail = Mail
FW.Mail = Mail

Mail.open = false      -- ein Briefkasten ist offen
Mail.busy = nil        -- nil | "inbox" | "send"
Mail.gen = 0           -- zaehlt die Briefkasten-Oeffnungen
Mail.gap = GAP_START   -- aktuelle Pause zwischen zwei Briefen (so klein wie moeglich, waechst bei Ablehnung)

local function Now() return GetTime and GetTime() or 0 end
local function After(t, fn)
    if C_Timer and C_Timer.After then C_Timer.After(t, fn) else pcall(fn) end
end

local function Trace(msg)
    local C = FW.Creator
    if C and C.Trace then pcall(C.Trace, "Mail: " .. tostring(msg)) end
end
Mail.Trace = Trace

local function Say(msg)
    if Mail.db and Mail.db.settings.chat and FW.Print then FW:Print(msg) end
end

function Mail.Money(c)
    if Util.FormatMoney then return Util.FormatMoney(c) end
    return tostring(c) .. "c"
end

local function Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Charaktername: Leerzeichen weg, erster Buchstabe gross
function Mail.CleanName(s)
    s = Trim(s):gsub("%s+", "")
    if s == "" then return "" end
    return (s:sub(1, 1):upper() .. s:sub(2))
end

local function IsSelf(name)
    local me = UnitName and UnitName("player")
    return me and name and name:lower() == me:lower()
end
Mail.IsSelf = IsSelf

------------------------------------------------------------------------
-- Taschen
------------------------------------------------------------------------

local function NumSlots(bag)
    local fn = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    if type(fn) ~= "function" then return 0 end
    local ok, n = pcall(fn, bag)
    return (ok and tonumber(n)) or 0
end

local function SlotInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" then
            return tonumber(info.itemID), tonumber(info.stackCount) or 1, info.isLocked and true or false
        end
    end
    if GetContainerItemInfo then
        local ok, _, count, locked, _, _, _, link, _, _, itemID = pcall(GetContainerItemInfo, bag, slot)
        if ok then
            local id = tonumber(itemID) or (type(link) == "string" and tonumber(link:match("item:(%d+)"))) or nil
            if not id and GetContainerItemLink then
                local ok2, l2 = pcall(GetContainerItemLink, bag, slot)
                if ok2 and type(l2) == "string" then id = tonumber(l2:match("item:(%d+)")) end
            end
            return id, tonumber(count) or 1, locked and true or false
        end
    end
    return nil
end

local function BagCount() return tonumber(_G.NUM_BAG_SLOTS) or 4 end

-- Alle Staepel in den normalen Taschen: { bag, slot, id, count, locked }
function Mail.BagStacks()
    local out = {}
    for bag = 0, BagCount() do
        for slot = 1, NumSlots(bag) do
            local id, count, locked = SlotInfo(bag, slot)
            if id then out[#out + 1] = { bag = bag, slot = slot, id = id, count = count, locked = locked } end
        end
    end
    return out
end

-- freie Plaetze in Taschen ohne Spezialtyp (Koecher, Seelentasche ... zaehlen nicht)
function Mail.FreeSlots()
    local fn = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
    if type(fn) ~= "function" then return 0 end
    local n = 0
    for bag = 0, BagCount() do
        local ok, free, kind = pcall(fn, bag)
        if ok and tonumber(free) and (kind == nil or kind == 0) then n = n + free end
    end
    return n
end

------------------------------------------------------------------------
-- Zusammenspiel mit den Brett-Auftraegen (Creator)
------------------------------------------------------------------------

-- Ein Brett-Auftrag bereitet gerade einen Brief vor oder fragt danach: dann fassen wir den Brief nicht an.
function Mail.BoardBusy()
    local C = FW.Creator
    if not C then return false end
    if C.mailChoice or C.asking then return true end
    if C.askQueue and #C.askQueue > 0 then return true end
    if C.GuardState then
        local ok, st = pcall(C.GuardState)
        if ok and st and st ~= "off" then return true end
    end
    return false
end

-- Items, die ein offener Brett-Auftrag noch verschicken muss: set[itemID] = true
function Mail.Reserved()
    local set, n = {}, 0
    local C = FW.Creator
    if C and C.ActiveList and C.db and C.ObjProgress then
        local ok = pcall(function()
            for _, id in ipairs(C.ActiveList()) do
                local q = C.db.quests[id]
                for i, o in ipairs(q and q.objs or {}) do
                    if o.type == "mail" and o.item then
                        local have, need = C.ObjProgress(id, i)
                        if have < need and not set[o.item] then
                            set[o.item] = true
                            n = n + 1
                        end
                    end
                end
            end
        end)
        if not ok then Trace("Reservierung konnte nicht gelesen werden") end
    end
    return set, n
end

------------------------------------------------------------------------
-- Empfaenger (die letzten 5)
------------------------------------------------------------------------

function Mail:AddRecipient(name)
    name = Mail.CleanName(name)
    if name == "" or IsSelf(name) then return end
    local list = self.db.recipients
    for i = #list, 1, -1 do
        if list[i]:lower() == name:lower() then table.remove(list, i) end
    end
    table.insert(list, 1, name)
    while #list > MAX_RECENT do table.remove(list) end
    FW:Fire("MAIL_RECIPIENTS_CHANGED")
end

function Mail:Recipients()
    return self.db.recipients
end

------------------------------------------------------------------------
-- Posteingang
------------------------------------------------------------------------

-- Liste der Briefe: { i, sender, subject, money, cod, days, hasItem, itemName, itemTex, itemCount, sig, key, take, why }
-- Grosse Postfaecher werden in Haeppchen eingelesen (wie die Seiten des Spiels: 7 je Schritt, mit Pause), sonst haengt der Client.
local CHUNK, LOAD_GAP = 7, 0.45

local function InboxCount()
    if not GetInboxNumItems then return 0 end
    local ok, n = pcall(GetInboxNumItems)
    return (ok and tonumber(n)) or 0
end
Mail.InboxCount = InboxCount

-- Rueckgabe: laedt noch?, geladen, gesamt
function Mail.Loading()
    local n = InboxCount()
    if n <= CHUNK then return false, n, n end
    local L = math.min(n, Mail.loadedN or CHUNK)
    return L < n, L, n
end

function Mail:StartLoader()
    if not self.loader then
        self.loader = CreateFrame("Frame")
        local acc = 0
        self.loader:SetScript("OnUpdate", function(f, elapsed)
            acc = acc + (elapsed or 0)
            if acc < LOAD_GAP then return end
            acc = 0
            if not Mail.open then f:Hide() return end
            local loading = Mail.Loading()
            if loading then
                Mail.loadedN = (Mail.loadedN or CHUNK) + CHUNK
                FW:Fire("MAIL_INBOX_CHANGED")
            end
            if not Mail.Loading() then f:Hide() FW:Fire("MAIL_INBOX_CHANGED") end
        end)
    end
    if Mail.Loading() then self.loader:Show() else self.loader:Hide() end
end

function Mail.ReadInbox()
    local list = {}
    if not GetInboxNumItems then return list end
    local n = InboxCount()
    if n > CHUNK then n = math.min(n, Mail.loadedN or CHUNK) end
    local seen = {}
    for i = 1, n do
        local ok1, _, _, sender, subject, money, cod, days, hasItem, wasRead, wasReturned, _, canReply = pcall(GetInboxHeaderInfo, i)
        if ok1 then
            local m = {
                i = i, sender = sender or "?", subject = subject or "",
                money = tonumber(money) or 0, cod = tonumber(cod) or 0, days = tonumber(days),
                hasItem = (hasItem and hasItem ~= 0) and true or false, read = wasRead and true or false,
                returned = wasReturned and true or false, canReply = not (canReply == false or canReply == 0),
            }
            if m.hasItem and GetInboxItem then
                local ok2, name, tex, count = pcall(GetInboxItem, i)
                if ok2 then m.itemName, m.itemTex, m.itemCount = name, tex, tonumber(count) or 1 end
            end
            m.sig = table.concat({ m.sender, m.subject, m.money, m.cod, tostring(m.itemName), tostring(m.itemCount) }, "|")
            seen[m.sig] = (seen[m.sig] or 0) + 1
            m.key = m.sig .. "#" .. seen[m.sig]
            if m.cod > 0 then
                m.take, m.why = false, "cod"
            elseif m.money > 0 or m.hasItem then
                m.take = true
            else
                m.take, m.why = false, "letter"
            end
            list[#list + 1] = m
        end
    end
    return list
end

------------------------------------------------------------------------
-- Brieftext, Archiv, einzelne Briefe
------------------------------------------------------------------------

local MAX_ARCHIVE = 500
Mail.taken = {}     -- "Absender|Betreff" -> { money, items = { "Name xN" } }: was aus dem Brief genommen wurde

local function Pair(m) return tostring(m.sender) .. "|" .. tostring(m.subject) end
Mail.Pair = Pair

-- Text eines Briefs (markiert ihn als gelesen). Rueckgabe: Text, istRechnung
function Mail.ReadText(i)
    if not GetInboxText then return "", false end
    local ok, body, _, _, invoice = pcall(GetInboxText, i)
    if not ok then return "", false end
    body = type(body) == "string" and body or ""
    if invoice and GetInboxInvoiceInfo then
        local ok2, kind, item, who, bid = pcall(GetInboxInvoiceInfo, i)
        if ok2 and item then
            local parts = { tostring(kind or "invoice"), tostring(item) }
            if who then parts[#parts + 1] = tostring(who) end
            if bid then parts[#parts + 1] = Mail.Money(bid) end
            body = (body ~= "" and (body .. "\n") or "") .. table.concat(parts, " - ")
        end
    end
    return body, invoice and true or false
end

-- Nichts mehr angehaengt, kein Gold, keine Nachnahme: dann gehen beim Loeschen keine Werte verloren
function Mail.Deletable(m)
    return m ~= nil and not m.hasItem and m.money == 0 and m.cod == 0
end

local function NoteTaken(m, what)
    local p = Pair(m)
    local t = Mail.taken[p] or { money = 0, items = {} }
    Mail.taken[p] = t
    if what == "money" then
        t.money = t.money + m.money
    else
        t.items[#t.items + 1] = (m.itemName or "?") .. ((m.itemCount or 1) > 1 and (" x" .. m.itemCount) or "")
    end
end

-- Eigene Briefe ohne Text (Betreff steht alles): werden ohne Archiv entfernt
function Mail:NoteSent(subject, body)
    if (body or "") ~= "" or not subject or subject == "" then return end
    local t = self.db.sentSubjects
    local now = time()
    t[subject] = now
    local n = 0
    for k, v in pairs(t) do
        n = n + 1
        if now - (tonumber(v) or 0) > 30 * 86400 then t[k] = nil end
    end
end

function Mail:IsOwnSent(subject, body)
    return (body or "") == "" and self.db.sentSubjects[subject] ~= nil
end

function Mail:AddArchive(m, body)
    local info = Mail.taken[Pair(m)]
    local e = {
        t = time(), sender = m.sender, subject = m.subject, body = body or "",
        money = info and info.money or 0, items = info and info.items or {},
        char = UnitName and UnitName("player") or "?",
    }
    table.insert(self.db.archive, 1, e)
    while #self.db.archive > MAX_ARCHIVE do table.remove(self.db.archive) end
    FW:Fire("MAIL_ARCHIVE_CHANGED")
end

-- Archiv-Eintraege nach der eingestellten Zeit loeschen (0 = nie)
function Mail:Purge()
    local days = tonumber(self.db.settings.archiveDays) or 0
    if days <= 0 then return 0 end
    local limit = time() - days * 86400
    local a, n = self.db.archive, 0
    for i = #a, 1, -1 do
        if (a[i].t or 0) < limit then table.remove(a, i) n = n + 1 end
    end
    if n > 0 then FW:Fire("MAIL_ARCHIVE_CHANGED") end
    return n
end

-- Leeren Brief entfernen: erst ins Archiv (ausser unseren eigenen Textlosen), dann loeschen.
-- Rueckgabe: true, "archived"|"own"  oder  false, Grund
function Mail:RemoveMail(m)
    if not Mail.Deletable(m) then return false, "notempty" end
    local body = Mail.ReadText(m.i)
    if body:find("FW%d+:[a-z0-9]+:%x+:") then return false, "data" end   -- Freewood-Daten: bleiben fuer die Annahme
    local own = self:IsOwnSent(m.subject, body)
    if not own then self:AddArchive(m, body) end
    pcall(DeleteInboxItem, m.i)
    Mail.taken[Pair(m)] = nil
    return true, own and "own" or "archived"
end

-- Kennung der Brett-Briefe (vom Freewood-Briefkasten geschrieben): gruen darstellen
local GREEN = "|cff6cc070"
-- Kennung steht vorn, bei Nachnahme steht "(COD) " davor
local function BoardTagPos(s)
    if type(s) ~= "string" then return nil end
    local a, b = s:find("[Brett] ", 1, true)
    if a and a <= 12 then return a, b end
    return nil
end
function Mail.IsBoardSubject(s)
    return BoardTagPos(s) ~= nil
end
function Mail.ColorSubject(s)
    s = tostring(s or "")
    local a, b = BoardTagPos(s)
    if a then return s:sub(1, a - 1) .. GREEN .. "[Brett]|r " .. s:sub(b + 1) end
    return s
end

-- Nachnahme-Briefe werden NIE geloescht: auch ueber das Blizzard-Fenster wird "Loeschen" zu "An Absender zurueck"
if not Mail.deleteWrapped and _G.DeleteInboxItem and _G.ReturnInboxItem and _G.GetInboxHeaderInfo then
    Mail.deleteWrapped = true
    local origDelete = _G.DeleteInboxItem
    _G.DeleteInboxItem = function(i, ...)
        if not Mail.allowDelete then
            local ok, _, _, sender, _, _, cod, _, hasItem = pcall(_G.GetInboxHeaderInfo, i)
            if ok and tonumber(cod) and cod > 0 then
                pcall(_G.ReturnInboxItem, i)
                if FW.Print and FW.L.MAIL_COD_RETURNED then FW:Print(FW.L.MAIL_COD_RETURNED) end
                return
            end
        end
        return origDelete(i, ...)
    end
end
function Mail.ColorBody(text)
    text = tostring(text or "")
    if text:sub(1, 16) ~= "[Freewood Brett]" then return text end
    local out, data, first = {}, false, true
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if first then
            first = false
            out[#out + 1] = GREEN .. FW.L.MAIL_BOARD_TAG .. "|r"
        elseif not data and not line:find("FW%d+:") then
            out[#out + 1] = GREEN .. line .. "|r"
        else
            data = true
            out[#out + 1] = line
        end
    end
    return table.concat(out, "\n")
end

-- Brett-Brief: Ein Brett-Auftrag bereitet einen Brief vor (Creator befuellt das verdeckte Briefformular).
-- Mit ersetztem Briefkasten zeigt unser Fenster den Stand und sendet selbst, sobald alles stimmt.
function Mail.BoardLetter()
    local C = FW.Creator
    if not (C and C.GuardState and C.MailCheck) then return nil end
    local ok, st = pcall(C.GuardState)
    if not ok or not st or st == "off" then return nil end
    local ok2, list, all = pcall(C.MailCheck)
    if not ok2 then list, all = nil, false end
    return { state = st, list = list or {}, all = all and true or false }
end

function Mail:BoardSend()
    local bl = Mail.BoardLetter()
    if not bl or bl.state ~= "armed" or not bl.all then return false end
    local b = _G.SendMailMailButton
    if not (b and b.Click) then return false end
    if b.IsEnabled and not b:IsEnabled() then return false end
    self.boardSending = true
    Trace("Brett-Brief: Senden ueber den Freewood-Briefkasten")
    pcall(b.Click, b)
    return true
end

-- Automatisch senden, wenn alles stimmt (Einstellung "boardAuto"), hoechstens 3 Versuche je Oeffnung
function Mail:BoardAuto()
    if not (self.open and self.Replacing() and self.db.settings.boardAuto) then return end
    if self.boardAutoAt or (self.boardTries or 0) >= 3 then return end
    local bl = Mail.BoardLetter()
    if not bl or bl.state ~= "armed" or not bl.all then return end
    self.boardAutoAt = true
    After(0.8, function()
        Mail.boardAutoAt = nil
        if Mail.open and Mail.Replacing() then
            Mail.boardTries = (Mail.boardTries or 0) + 1
            Mail:BoardSend()
        end
    end)
end

-- Brief an den Absender zurueckschicken (Anhang und Gold gehen mit zurueck). Nicht moeglich bei System-/Auktionsbriefen.
function Mail.Returnable(m)
    if not m or not m.canReply or m.returned then return false end
    local s = tostring(m.sender or "")
    if s == "" or s == "?" or Mail.IsSelf(s) then return false end
    return true
end

function Mail:ReturnMail(m)
    if self.busy then return false, "busy" end
    if not Mail.Returnable(m) then return false, "noreturn" end
    if not ReturnInboxItem then return false, "noreturn" end
    local ok = pcall(ReturnInboxItem, m.i)
    if not ok then return false, "noreturn" end
    Mail.taken[Pair(m)] = nil
    return true
end

function Mail:FindMail(key, pair)
    local list = Mail.ReadInbox()
    for _, m in ipairs(list) do
        if m.key == key then return m end
    end
    if pair then
        for _, m in ipairs(list) do
            if Pair(m) == pair then return m end
        end
    end
end

-- Inhalt eines einzelnen Briefs nehmen (erst Gold, dann Item). Nachnahme zahlt der Spieler mit einem zweiten Klick (UI).
function Mail:TakeOne(m)
    if self.busy then return false, "busy" end
    if m.cod > 0 then
        local B = FW.Brett
        if B and B.InspectMail then
            local ok, st = pcall(B.InspectMail, m.i)
            if ok and st == "high" then return false, "codbad" end
            if ok and st == "nodeal" then return false, "codnodeal" end
            if ok and st == "taken" then return false, "codtaken" end
        end
        if ((GetMoney and GetMoney()) or 0) < m.cod then return false, "codmoney" end
    end
    if m.money > 0 and m.cod == 0 then
        NoteTaken(m, "money")
        pcall(TakeInboxMoney, m.i)
        return true
    elseif m.hasItem then
        if Mail.FreeSlots() <= KEEP_FREE then return false, "full" end
        NoteTaken(m, "item")
        if m.cod > 0 and FW.Brett and FW.Brett.NoteDelivered then pcall(FW.Brett.NoteDelivered, m.sender, m.subject) end
        pcall(TakeInboxItem, m.i)
        return true
    end
    return false, "empty"
end

Mail.selected = {}      -- key -> true

function Mail:SelectedCount()
    local n = 0
    for _ in pairs(self.selected) do n = n + 1 end
    return n
end

function Mail:ToggleSelect(key, on)
    if on == nil then on = not self.selected[key] end
    self.selected[key] = on and true or nil
    FW:Fire("MAIL_SELECTION_CHANGED")
end

function Mail:SelectAll(on)
    self.selected = {}
    if on then
        for _, m in ipairs(Mail.ReadInbox()) do
            if m.take then self.selected[m.key] = true end
        end
    end
    FW:Fire("MAIL_SELECTION_CHANGED")
end

-- onlySelected: nur angehakte Briefe
function Mail:StartOpen(onlySelected)
    if self.busy or not self.open then return false end
    if Mail.Loading() then Say(FW.L.MAIL_LOADING_WAIT) return false end
    local only
    if onlySelected then
        only = {}
        for k in pairs(self.selected) do only[k] = true end
        if next(only) == nil then return false end
    end
    self.run = { only = only, tries = {}, money = 0, items = 0, pending = nil, removed = 0, archived = 0, touched = {} }
    self.busy = "inbox"
    self.driver:Show()
    Trace("Posteingang: Start" .. (only and " (nur Ausgewaehlte)" or " (alle)"))
    FW:Fire("MAIL_STATE")
    return true
end

local function FinishOpen(self, reason)
    local run = self.run
    self.run, self.busy = nil, nil
    if not run then return end
    local skipped = 0
    if run.full and reason == "done" then
        for _, m in ipairs(Mail.ReadInbox()) do
            if m.take and m.hasItem and (not run.only or run.only[m.key]) then skipped = skipped + 1 end
        end
    end
    Trace(string.format("Posteingang: Ende (%s), %d Gold-Briefe, %d Items, %d Items liegen geblieben", reason, run.money, run.items, skipped))
    if reason == "stopped" or reason == "closed" then
        Say(string.format(FW.L.MAIL_RUN_STOPPED, run.money, run.items))
    else
        Say(string.format(FW.L.MAIL_RUN_DONE, run.money, run.items, skipped > 0 and string.format(FW.L.MAIL_RUN_SKIP_FULL, skipped) or ""))
    end
    if run.removed > 0 then Say(string.format(FW.L.MAIL_RUN_CLEANED, run.removed, run.archived)) end
    self.lastRun = { money = run.money, items = run.items, skipped = skipped, removed = run.removed }
    self.selected = {}
    FW:Fire("MAIL_STATE")
    FW:Fire("MAIL_SELECTION_CHANGED")
    FW:Fire("MAIL_INBOX_CHANGED")
end

function Mail:Stop()
    if self.busy == "inbox" and self.run then FinishOpen(self, "stopped") end
    if self.busy == "send" and self.send then self:FinishSend("stopped") end
end

function Mail:StepOpen()
    local run = self.run
    local now = Now()
    if not self.open then return FinishOpen(self, "closed") end
    if run.pending then
        -- auf die Antwort des Servers warten (oder den Ablauf der Zeit)
        if not ((run.updated and now >= run.pending + INBOX_GAP) or now >= run.pending + INBOX_TIMEOUT) then return end
        run.pending = nil
    end
    local list = Mail.ReadInbox()
    local free = Mail.FreeSlots()
    for idx = #list, 1, -1 do
        local m = list[idx]
        if m.take and (not run.only or run.only[m.key]) and (run.tries[m.sig] or 0) < 3 then
            if m.money > 0 then
                run.tries[m.sig] = (run.tries[m.sig] or 0) + 1
                run.money = run.money + 1
                run.touched[Pair(m)] = true
                NoteTaken(m, "money")
                run.pending, run.updated = now, false
                pcall(TakeInboxMoney, m.i)
                Trace(string.format("Brief %d von %s: Gold %d genommen", m.i, m.sender, m.money))
                FW:Fire("MAIL_STATE")
                return
            elseif m.hasItem then
                if free <= KEEP_FREE then
                    run.full = true
                else
                    run.tries[m.sig] = (run.tries[m.sig] or 0) + 1
                    run.items = run.items + 1
                    run.touched[Pair(m)] = true
                    NoteTaken(m, "item")
                    run.pending, run.updated = now, false
                    pcall(TakeInboxItem, m.i)
                    Trace(string.format("Brief %d von %s: Item %s genommen (frei vorher %d)", m.i, m.sender, tostring(m.itemName), free))
                    FW:Fire("MAIL_STATE")
                    return
                end
            end
        end
    end
    -- nichts mehr zu nehmen: leere Briefe entfernen (mit Text und fremde kommen vorher ins Archiv)
    if self.db.settings.cleanup then
        for idx = #list, 1, -1 do
            local m = list[idx]
            local key = "del|" .. m.sig
            if Mail.Deletable(m) and (not run.only or run.touched[Pair(m)]) and (run.tries[key] or 0) < 2 then
                run.tries[key] = (run.tries[key] or 0) + 1
                local ok, how = self:RemoveMail(m)
                if ok then
                    run.removed = run.removed + 1
                    if how == "archived" then run.archived = run.archived + 1 end
                    run.pending, run.updated = now, false
                    FW:Fire("MAIL_STATE")
                    return
                end
            end
        end
    end
    FinishOpen(self, "done")
end

------------------------------------------------------------------------
-- Senden (gemeinsame Warteschlange)
------------------------------------------------------------------------

local function AttachedName()
    if not GetSendMailItem then return nil end
    local ok, name = pcall(GetSendMailItem, 1)
    if ok and name and name ~= "" then return name end
    return nil
end

-- Anhang-Platz leeren (zurueck in die Tasche)
local function ClearAttachment()
    if AttachedName() and ClickSendMailItemButton then
        pcall(ClickSendMailItemButton)
        if CursorHasItem and CursorHasItem() then pcall(ClearCursor) end
    end
end

local function FindStack(item)
    local fallback
    for _, s in ipairs(Mail.BagStacks()) do
        if s.id == item.id and not s.locked then
            if s.count == item.count then return s end
            fallback = fallback or s
        end
    end
    return fallback
end

-- Bereitet einen Brief vor. Rueckgabe: true oder false, Grund
local function Prepare(job)
    if CursorHasItem and CursorHasItem() then return false, "cursor" end
    ClearAttachment()
    if job.item then
        local s = FindStack(job.item)
        if not s then return false, "gone" end
        pcall(ClearCursor)
        pcall(PickupContainerItem, s.bag, s.slot)
        if not (CursorHasItem and CursorHasItem()) then return false, "pickup" end
        if not ClickSendMailItemButton then pcall(ClearCursor) return false, "noapi" end
        pcall(ClickSendMailItemButton)
        if not AttachedName() then
            pcall(ClearCursor)
            return false, "attach"
        end
    end
    if SetSendMailMoney then pcall(SetSendMailMoney, (job.cod or 0) > 0 and 0 or (job.money or 0)) end
    if SetSendMailCOD then pcall(SetSendMailCOD, job.cod or 0) end
    return true
end

local function JobLabel(job)
    if job.item then
        local info = Util.GetItem and Util.GetItem(job.item.id)
        return (info and info.name) or ("#" .. tostring(job.item.id))
    end
    return Mail.Money(job.money or 0)
end

-- jobs: { to, subject, body, item = {id,count}, money, cod }
function Mail:StartSend(jobs)
    if self.busy then return false, "busy" end
    if not self.open then return false, "closed" end
    if Mail.BoardBusy() then return false, "board" end
    if not jobs or #jobs == 0 then return false, "empty" end
    self.send = { jobs = jobs, i = 0, sent = 0, failed = 0, stage = "next", nextAt = 0 }
    self.busy = "send"
    self.driver:Show()
    Trace(string.format("Senden: Start mit %d Briefen", #jobs))
    FW:Fire("MAIL_STATE")
    return true
end

function Mail:FinishSend(reason)
    local s = self.send
    self.send, self.busy = nil, nil
    if not s then return end
    pcall(ClearCursor)
    if reason ~= "done" then ClearAttachment() end
    Trace(string.format("Senden: Ende (%s), %d von %d gesendet, %d uebersprungen", reason, s.sent, #s.jobs, s.failed))
    if reason == "done" then
        Say(string.format(FW.L.MAIL_SEND_DONE, s.sent, #s.jobs, s.failed > 0 and string.format(FW.L.MAIL_SEND_DONE_FAIL, s.failed) or ""))
    elseif reason == "timeout" then
        Say(FW.L.MAIL_SEND_FAIL_TIMEOUT)
    elseif reason == "error" then
        Say(FW.L.MAIL_SEND_FAIL_ERROR)
    else
        Say(string.format(FW.L.MAIL_SEND_STOPPED, s.sent, #s.jobs))
    end
    FW:Fire("MAIL_STATE")
    FW:Fire("MAIL_SENT_DONE", s.sent, #s.jobs)
end

function Mail:StepSend()
    local s = self.send
    local now = Now()
    if not self.open then return self:FinishSend("closed") end
    if Mail.BoardBusy() then return self:FinishSend("board") end
    if s.stage == "wait" then
        if s.ok then
            -- Erfolg: Tempo langsam wieder erhoehen (Pause kleiner), solange der Server mitkommt
            s.streak = (s.streak or 0) + 1
            if s.streak >= 3 then s.streak = 0 Mail.gap = math.max(GAP_MIN, Mail.gap * 0.8) end
            s.retry = 0
            s.stage, s.nextAt = "next", now + Mail.gap
        elseif s.err then
            -- Der Server hat den Brief abgelehnt (meist zu schnell): Pause verdoppeln und denselben Brief nochmal versuchen
            s.retry = (s.retry or 0) + 1
            if s.retry > MAX_RETRY then return self:FinishSend("error") end
            s.streak = 0
            Mail.gap = math.min(GAP_MAX, Mail.gap * 2 + 0.3)
            Trace(string.format("Server lehnt ab: Pause jetzt %.2f s, Versuch %d von %d fuer Brief %d", Mail.gap, s.retry, MAX_RETRY, s.i))
            if not s.slowSaid then s.slowSaid = true Say(FW.L.MAIL_SPEED_ADAPT) end
            pcall(ClearCursor)
            ClearAttachment()
            s.i = s.i - 1
            s.err, s.stage, s.nextAt = false, "next", now + Mail.gap + 0.5
            return
        elseif now > s.deadline then
            return self:FinishSend("timeout")
        end
        return
    end
    if now < s.nextAt then return end
    if CursorHasItem and CursorHasItem() then return end
    s.i = s.i + 1
    local job = s.jobs[s.i]
    if not job then return self:FinishSend("done") end
    s.current = job
    local ok, why = Prepare(job)
    if not ok then
        s.failed = s.failed + 1
        s.nextAt = now + 0.2
        Trace(string.format("Brief %d (%s) nicht vorbereitet: %s", s.i, JobLabel(job), tostring(why)))
        if why == "attach" or why == "gone" or why == "pickup" then
            Say(string.format(FW.L.MAIL_SEND_FAIL_ATTACH, JobLabel(job)))
        end
        FW:Fire("MAIL_STATE")
        return
    end
    s.ok, s.err, s.deadline, s.stage = false, false, now + SEND_TIMEOUT, "wait"
    Trace(string.format("Brief %d von %d an %s: %s (Betreff '%s', Nachnahme %d)", s.i, #s.jobs, job.to, JobLabel(job), tostring(job.subject), job.cod or 0))
    FW:Fire("MAIL_STATE")
    local okc = pcall(SendMail, job.to, job.subject or "", job.body or "")
    if not okc then s.err = true end
end

-- Fortschritt fuer die Anzeige: i, n, an wen
function Mail:SendProgress()
    local s = self.send
    if not s then return nil end
    local job = s.current or s.jobs[1]
    return math.min(s.i, #s.jobs), #s.jobs, job and job.to or "?"
end

------------------------------------------------------------------------
-- Briefe zusammenstellen
------------------------------------------------------------------------

local function Stamp() return date and date("%d.%m. %H:%M") or "" end

-- Eingabe des Senden-Reiters: form = { to, subject, body, picks = { {id,count}... }, money, cod = bool }
function Mail:BuildCompose(form)
    local to = Mail.CleanName(form.to)
    if to == "" then return nil, "to" end
    if IsSelf(to) then return nil, "self" end
    local picks = form.picks or {}
    local money = math.floor(tonumber(form.money) or 0)
    -- Ein reiner Textbrief (ohne Anhang und Gold) ist erlaubt; leer ist nur, wer weder Betreff noch Text noch Anhang hat
    if #picks == 0 and money <= 0 and Trim(form.subject) == "" and Trim(form.body) == "" then return nil, "nothing" end
    if form.cod and #picks == 0 then return nil, "codItem" end
    if form.cod and money <= 0 then return nil, "codMoney" end
    local base = Trim(form.subject)
    local jobs = {}
    local n = math.max(#picks, 1)
    for i = 1, n do
        local pick = picks[i]
        local subject = base
        if subject == "" then
            local info = pick and Util.GetItem and Util.GetItem(pick.id)
            subject = (info and info.name) or ""
            if subject == "" then
                -- Textbrief ohne Betreff: erste Zeile des Textes
                local first = Trim(tostring(form.body or ""):match("^[^\r\n]*") or "")
                if #first > 40 then first = first:sub(1, 40) end
                subject = first ~= "" and first or FW.L.MAIL_SUBJECT_DEFAULT
            end
        end
        if n > 1 then subject = string.format(FW.L.MAIL_SUBJECT_ITEM_N, subject, i, n) end
        local job = { to = to, subject = subject, body = form.body or "", item = pick }
        if form.cod then
            job.cod = money
        elseif i == 1 and money > 0 then
            job.money = money
        end
        jobs[#jobs + 1] = job
    end
    if #jobs > MAX_JOBS then return nil, "many" end
    return jobs
end

-- Eintrag der Mailingliste -> Briefe. reserved: Items fuer Brett-Auftraege (werden nicht gesendet)
function Mail:BuildList(entry, reserved)
    local jobs = {}
    if not entry or IsSelf(entry.name) then return jobs end
    reserved = reserved or Mail.Reserved()
    local stacks = Mail.BagStacks()
    local picks = {}
    for _, id in ipairs(entry.ids or {}) do
        if not reserved[id] then
            for _, s in ipairs(stacks) do
                if s.id == id and not s.locked then picks[#picks + 1] = { id = id, count = s.count } end
            end
        end
    end
    local surplus = 0
    if entry.gold then
        local have = (GetMoney and GetMoney()) or 0
        surplus = have - (entry.keep or 0) - (#picks + 1) * POSTAGE
        if surplus < 100 then surplus = 0 end
    end
    for _, p in ipairs(picks) do jobs[#jobs + 1] = { to = entry.name, item = p } end
    if surplus > 0 then jobs[#jobs + 1] = { to = entry.name, money = surplus } end
    local n, stamp = #jobs, Stamp()
    for i, job in ipairs(jobs) do
        job.subject = n > 1 and string.format(FW.L.MAIL_SUBJECT_N, stamp, i, n) or string.format(FW.L.MAIL_SUBJECT_STAMP, stamp)
        job.body = ""
    end
    return jobs
end

function Mail:ListFor(name)
    for _, e in ipairs(self.db.lists) do
        if e.name:lower() == (name or ""):lower() then return e end
    end
end

function Mail:AddList(name)
    name = Mail.CleanName(name)
    if name == "" or name:find("[^%w\128-\255%-]") then return false, "invalid" end
    if #self.db.lists >= MAX_LISTS then return false, "full" end
    if self:ListFor(name) then return false, "exists" end
    self.db.lists[#self.db.lists + 1] = { name = name, ids = {}, auto = false, gold = false, keep = 0 }
    FW:Fire("MAIL_LISTS_CHANGED")
    return true
end

function Mail:RemoveList(entry)
    for i, e in ipairs(self.db.lists) do
        if e == entry then table.remove(self.db.lists, i) break end
    end
    FW:Fire("MAIL_LISTS_CHANGED")
end

function Mail:ToggleListItem(entry, id)
    for i, v in ipairs(entry.ids) do
        if v == id then table.remove(entry.ids, i) FW:Fire("MAIL_LISTS_CHANGED") return false end
    end
    if #entry.ids >= MAX_ITEMS_PER_LIST then return nil end
    entry.ids[#entry.ids + 1] = id
    FW:Fire("MAIL_LISTS_CHANGED")
    return true
end

function Mail:HasListItem(entry, id)
    for _, v in ipairs(entry.ids) do
        if v == id then return true end
    end
    return false
end

-- Eine Liste (entry) oder alle (entry = nil) jetzt senden. auto: nur Listen mit Haken
function Mail:SendLists(entry, autoOnly)
    local reserved = Mail.Reserved()
    local jobs = {}
    for _, e in ipairs(self.db.lists) do
        if (entry == nil or entry == e) and (not autoOnly or e.auto) then
            local part = self:BuildList(e, reserved)
            if #part == 0 and entry == e then Say(string.format(FW.L.MAIL_SEND_NOTHING_LIST, e.name)) end
            for _, j in ipairs(part) do jobs[#jobs + 1] = j end
        end
    end
    if #jobs == 0 then return false, "empty" end
    return self:StartSend(jobs)
end

-- Automatik: kurz nach dem Oeffnen, aber erst wenn Brett-Auftraege und andere Aktionen fertig sind
function Mail:ScheduleAuto()
    local any
    for _, e in ipairs(self.db.lists) do if e.auto then any = true end end
    if not any then return end
    local gen, tries, told = self.gen, 0, false
    local function Try()
        if not Mail.open or Mail.gen ~= gen then return end
        if Mail.busy or Mail.BoardBusy() then
            tries = tries + 1
            if Mail.BoardBusy() and not told then
                told = true
                Say(FW.L.MAIL_AUTO_WAIT_BOARD)
            end
            if tries < 60 then After(1.5, Try) end
            return
        end
        Mail:SendLists(nil, true)
    end
    After(AUTO_DELAY, Try)
end

------------------------------------------------------------------------
-- Normales Fenster ausblenden (es bleibt technisch offen, damit Brett-Auftraege weiter funktionieren)
------------------------------------------------------------------------

function Mail.Replacing()
    return Mail.db and Mail.db.settings.replace and true or false
end

function Mail.Anchor()
    local w = Mail.window
    if Mail.Replacing() and w and w:IsShown() then return w end
    return nil
end

function Mail:ApplyReplace()
    local f = _G.MailFrame
    if not f then return end
    if self.Replacing() and not self.uiFailed then
        if not self.hidden then
            self.hidden = { alpha = f:GetAlpha(), scale = f:GetScale() }
        end
        f:SetAlpha(0)
        f:SetScale(0.01)
    elseif self.hidden then
        f:SetAlpha(self.hidden.alpha or 1)
        f:SetScale(self.hidden.scale or 1)
        self.hidden = nil
    end
end

function Mail:SetReplace(on)
    self.db.settings.replace = on and true or false
    self.uiFailed = nil
    self:ApplyReplace()
    FW:Fire("MAIL_REPLACE_CHANGED")
    if self.open then
        FW:Fire(on and "MAIL_WINDOW_SHOW" or "MAIL_WINDOW_HIDE")
    end
end

------------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------------

function Mail:OnMailShow()
    pcall(self.Purge, self)
    self.open = true
    self.gen = self.gen + 1
    self.boardTries, self.boardAutoAt, self.boardSending = 0, nil, nil
    self.selected = {}
    self.loadedN = CHUNK
    self:StartLoader()
    self:ApplyReplace()
    Trace("Briefkasten geoeffnet")
    if self.Replacing() then FW:Fire("MAIL_WINDOW_SHOW") end
    FW:Fire("MAIL_INBOX_CHANGED")
    self:ScheduleAuto()
end

function Mail:OnMailClosed()
    if not self.open then return end
    self.open = false
    if self.busy == "inbox" then FinishOpen(self, "closed") end
    if self.busy == "send" then self:FinishSend("closed") end
    self.busy = nil
    FW:Fire("MAIL_WINDOW_HIDE")
end

-- Der Client meldet MAIL_INBOX_UPDATE zeitweise zigtausendmal in einem Bild. Darum nur vormerken und hoechstens alle 0,2 s einmal aufbauen.
function Mail:OnInboxUpdate()
    if self.run then self.run.updated = true end
    self.updDirty = true
    if not self.updFrame then
        self.updFrame = CreateFrame("Frame")
        local acc = 0
        self.updFrame:SetScript("OnUpdate", function(f, elapsed)
            if not Mail.updDirty then acc = 0 return end
            acc = acc + (elapsed or 0)
            if acc < 0.2 then return end
            acc = 0
            Mail.updDirty = false
            if Mail.open and Mail.Loading() and (not Mail.loader or not Mail.loader:IsShown()) then Mail:StartLoader() end
            FW:Fire("MAIL_INBOX_CHANGED")
        end)
    end
end

function Mail:OnSendSuccess()
    if self.boardSending then
        self.boardSending = nil
        local C = FW.Creator
        if C then C.mailChoice = nil end   -- Brett-Brief ist raus: unser Fenster ist wieder frei
        Say(FW.L.MAIL_BOARD_SENT)
        FW:Fire("MAIL_STATE")
    end
    local s = self.send
    if self.lastTo then
        self:AddRecipient(self.lastTo)
        self.lastTo = nil
    end
    if s and s.stage == "wait" then
        s.ok = true
        s.sent = s.sent + 1
        FW:Fire("MAIL_STATE")
    end
end

function Mail:OnSendFailed()
    local s = self.send
    if s and s.stage == "wait" then s.err = true end
end

function Mail:OnEnable()
    self.driver = self.driver or CreateFrame("Frame")
    local acc = 0
    self.driver:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < STEP then return end
        acc = 0
        local ok, err = pcall(function()
            if Mail.busy == "inbox" and Mail.run then Mail:StepOpen()
            elseif Mail.busy == "send" and Mail.send then Mail:StepSend()
            else Mail.driver:Hide() end
        end)
        if not ok then
            Trace("Fehler im Takt: " .. tostring(err))
            Mail.run, Mail.send, Mail.busy = nil, nil, nil
            Mail.driver:Hide()
            FW:Fire("MAIL_STATE")
        end
    end)
    self.driver:Hide()
    FW:RegisterEvent("MAIL_SHOW", function() pcall(Mail.OnMailShow, Mail) end, self)
    FW:RegisterEvent("MAIL_CLOSED", function() pcall(Mail.OnMailClosed, Mail) end, self)
    FW:RegisterEvent("MAIL_INBOX_UPDATE", function() pcall(Mail.OnInboxUpdate, Mail) end, self)
    FW:RegisterEvent("MAIL_SEND_SUCCESS", function() pcall(Mail.OnSendSuccess, Mail) end, self)
    FW:RegisterEvent("MAIL_FAILED", function() pcall(Mail.OnSendFailed, Mail) end, self)
    FW:On("CREATOR_MAIL_UPDATE", function() pcall(Mail.BoardAuto, Mail) end, self)
    if not self.hooked then
        self.hooked = true
        -- Empfaenger merken, egal wer sendet (auch das normale Fenster und Brett-Auftraege)
        if hooksecurefunc and _G.SendMail then
            pcall(hooksecurefunc, "SendMail", function(to, subject, body)
                if Mail.db then
                    Mail.lastTo = to
                    pcall(Mail.NoteSent, Mail, subject, body)
                end
            end)
        end
        if _G.MailFrame and MailFrame.HookScript then
            pcall(MailFrame.HookScript, MailFrame, "OnShow", function() pcall(Mail.ApplyReplace, Mail) end)
            -- das Ereignis MAIL_CLOSED kommt nicht immer; das Verschwinden des Fensters ist sicher
            pcall(MailFrame.HookScript, MailFrame, "OnHide", function() pcall(Mail.OnMailClosed, Mail) end)
        end
    end
    After(3, function() pcall(Mail.Purge, Mail) end)
    -- Briefkasten schon offen (z. B. nach /reload)?
    if _G.MailFrame and MailFrame.IsShown and MailFrame:IsShown() then
        After(0.5, function() pcall(Mail.OnMailShow, Mail) end)
    end
end

function Mail:OnDisable()
    for _, ev in ipairs({ "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SEND_SUCCESS", "MAIL_FAILED" }) do
        FW:UnregisterEvent(ev, self)
    end
    pcall(FW.Off, FW, "CREATOR_MAIL_UPDATE", self)
    if self.driver then self.driver:Hide() end
    self.run, self.send, self.busy = nil, nil, nil
    if self.hidden then
        local f = _G.MailFrame
        if f then f:SetAlpha(self.hidden.alpha or 1) f:SetScale(self.hidden.scale or 1) end
        self.hidden = nil
    end
end
