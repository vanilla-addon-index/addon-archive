-- Freewood-OctoWoW-Mail: eigenes Briefkasten-Fenster (Freewood-Design, verschiebbar).
-- Es geht nur auf, wenn im Spiel ein Briefkasten geoeffnet wird, und nur, wenn es in den Einstellungen so gewaehlt ist.
-- Reiter: Posteingang | Senden | Mailinglisten.

local ADDON, NS = ...

local FW = _G.Freewood
local Mail = NS.Mail
if not FW or not Mail then
    return
end

local UI = FW.UI
local Util = FW.Util

local W, H = 660, 560
local ROW_H, ROW_GAP = 40, 4
local OWNER = {}

local window, content, footer, tabs
local current = "inbox"
local panes = {}
local SelectTab
local picks = {}          -- Senden-Reiter: gewaehlte Staepel { id, count, key }
local picker

-- Breite einer Zeile: aus dem Rahmen gelesen, nicht von der Kindbreite abhaengig (die ist beim ersten Zeichnen manchmal zu klein)
local function RowWidth(scroll, minW)
    local w = scroll and scroll.GetWidth and scroll:GetWidth() or 0
    return math.max((w or 0) - 14, minW or 200)
end

-- Ziehen und Ablegen: Item mit der Maus aus der Tasche auf ein Ziel ziehen
local Drop = {}
local function CursorItem()
    if not GetCursorInfo then return nil end
    local ok, kind, id = pcall(GetCursorInfo)
    if ok and kind == "item" then return tonumber(id) end
end
local function MakeDropTarget(frame, fn)
    if not frame then return end
    frame:EnableMouse(true)
    local function Go()
        local id = CursorItem()
        if not id then return end
        pcall(fn, id)
        if ClearCursor then pcall(ClearCursor) end
    end
    frame:SetScript("OnReceiveDrag", Go)
    frame:SetScript("OnMouseUp", Go)
end

local function T(key) return FW.L[key] or key end

------------------------------------------------------------------------
-- Bausteine
------------------------------------------------------------------------

local function ColoredName(name, quality, id)
    return "|cff" .. UI.RarityHex(quality) .. (name or ("#" .. tostring(id))) .. "|r"
end

local function MakeEdit(parent, width, hintText, maxLetters, numeric)
    local box = UI.CreatePanel(parent, "bgDeep", "bronze")
    box:SetSize(width, 26)
    local edit = CreateFrame("EditBox", nil, box)
    edit:SetAutoFocus(false)
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -2)
    edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 2)
    edit:SetMaxLetters(maxLetters or 100)
    if numeric and edit.SetNumeric then pcall(edit.SetNumeric, edit, true) end
    if not edit:SetFont(UI.GetFontPath("body"), 12, "") then
        edit:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    end
    edit:SetTextColor(UI.Color("text"))
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    if hintText then
        box.hint = UI.CreateLabel(box, hintText, { size = 12, color = "textDim" })
        box.hint:SetPoint("LEFT", box, "LEFT", 10, 0)
    end
    edit:SetScript("OnTextChanged", function(self)
        if box.hint then
            if self:GetText() == "" then box.hint:Show() else box.hint:Hide() end
        end
        if box.onChange and not box.loading then box.onChange(self:GetText()) end
    end)
    box.edit = edit
    function box:Set(text)
        self.loading = true
        edit:SetText(text or "")
        self.loading = nil
        if self.hint then
            if (text or "") == "" then self.hint:Show() else self.hint:Hide() end
        end
    end
    return box, edit
end

local function Tooltip(frame, itemID, inboxIndex)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local idx = self.inboxIndex
        local id = self.itemID
        if idx and GameTooltip.SetInboxItem then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetInboxItem, GameTooltip, idx)
            GameTooltip:Show()
        elseif id then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetItemByID, GameTooltip, id)
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

-- Zeile mit Symbol und Namen
local function ItemRow(parent, h)
    local row = UI.CreatePanel(parent, "card", "bronze")
    row:SetHeight(h or 32)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = UI.CreateLabel(row, "", { size = 12 })
    row.name:SetWordWrap(false)
    Tooltip(row)
    return row
end

local function FillItem(row, id, count)
    row.itemID = id
    local suffix = (count and count > 1) and (" x" .. count) or ""
    row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    row.name:SetText(ColoredName(nil, 1, id) .. suffix)
    Util.RequestItem(id, function(info)
        if row.itemID ~= id or not info then return end
        row.icon:SetTexture(info.icon)
        row.name:SetText(ColoredName(info.name, info.quality, id) .. suffix)
    end)
end

local function Heading(parent, text, x, y)
    local h = UI.CreateLabel(parent, text, { font = "heading", size = 13, color = "goldLight" })
    h:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
    return h
end

------------------------------------------------------------------------
-- Auswahlfenster fuer Items
------------------------------------------------------------------------

local function BuildPicker()
    local p = UI.CreatePanel(window, "bgDeep", "gold")
    p:SetSize(460, 440)
    p:SetPoint("CENTER", window, "CENTER", 0, 0)
    p:SetFrameStrata("DIALOG")
    p:EnableMouse(true)
    p.title = UI.CreateLabel(p, "", { font = "heading", size = 15, color = "goldLight" })
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -14)
    p.hint = UI.CreateLabel(p, "", { size = 11, color = "textDim", justifyV = "TOP" })
    p.hint:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -38)
    p.hint:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -38)
    p.hint:SetHeight(28)
    p.hint:SetWordWrap(true)
    p.scroll = UI.CreateScrollFrame(p)
    p.scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -72)
    p.scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 52)
    p.empty = UI.CreateLabel(p.scroll.child, T("MAIL_PICK_EMPTY"), { size = 12, color = "textDim" })
    p.empty:SetPoint("TOPLEFT", p.scroll.child, "TOPLEFT", 4, -6)
    p.done = UI.CreateButton(p, T("MAIL_PICK_DONE"), 140, 28, function() p:Hide() end, "primary")
    p.done:SetPoint("BOTTOM", p, "BOTTOM", 0, 14)
    p.rows = {}
    p:Hide()

    local function Row(i)
        local row = p.rows[i]
        if row then return row end
        row = ItemRow(p.scroll.child, 32)
        row.cb = UI.CreateCheckbox(row, "", function() return row.checked end, function(v)
            if row.onToggle then row.onToggle(v) end
        end)
        row.cb:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.cb:SetWidth(22)
        row.icon:SetPoint("LEFT", row, "LEFT", 34, 0)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        p.rows[i] = row
        return row
    end

    function p:Fill()
        local data = {}
        local stacks = Mail.BagStacks()
        if self.mode == "list" then
            local agg, order = {}, {}
            for _, s in ipairs(stacks) do
                local a = agg[s.id]
                if not a then
                    a = { id = s.id, count = 0 }
                    agg[s.id] = a
                    order[#order + 1] = a
                end
                a.count = a.count + s.count
            end
            table.sort(order, function(a, b) return a.id < b.id end)
            for _, a in ipairs(order) do data[#data + 1] = a end
            local extraStart = #data + 1
            for _, id in ipairs(self.entry.ids) do
                if not agg[id] then data[#data + 1] = { id = id, count = 0, extra = true } end
            end
            self.extraStart = extraStart
        else
            local seen = {}
            for _, s in ipairs(stacks) do
                local base = s.id .. ":" .. s.count
                seen[base] = (seen[base] or 0) + 1
                if not s.locked then
                    data[#data + 1] = { id = s.id, count = s.count, key = base .. ":" .. seen[base] }
                end
            end
        end
        for i, d in ipairs(data) do local d = d
            local row = Row(i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", p.scroll.child, "TOPLEFT", 0, -((i - 1) * 36))
            row:SetWidth(RowWidth(p.scroll))
            FillItem(row, d.id, d.count)
            if d.extra then row.name:SetText(row.name:GetText() .. "  |cff8a8f9a(" .. T("MAIL_PICK_EXTRA") .. ")|r") end
            if self.mode == "list" then
                row.checked = Mail:HasListItem(self.entry, d.id)
                row.onToggle = function()
                    local r = Mail:ToggleListItem(self.entry, d.id)
                    row.checked = (r == true) or (r == nil and false)
                    row.cb:Refresh()
                    if self.onChange then self.onChange() end
                end
            else
                local function Index()
                    for k, pk in ipairs(picks) do if pk.key == d.key then return k end end
                end
                row.checked = Index() and true or false
                row.onToggle = function()
                    local k = Index()
                    if k then
                        table.remove(picks, k)
                        row.checked = false
                    else
                        picks[#picks + 1] = { id = d.id, count = d.count, key = d.key }
                        row.checked = true
                    end
                    row.cb:Refresh()
                    if self.onChange then self.onChange() end
                end
            end
            row.cb:Refresh()
            row:Show()
        end
        for i = #data + 1, #p.rows do p.rows[i]:Hide() end
        self.empty:SetShown(#data == 0)
        self.scroll:SetContentHeight(#data * 36 + 4)
    end

    return p
end

-- mode "list": entry = Eintrag der Mailingliste; mode "send": Auswahl des Senden-Reiters
local function OpenPicker(mode, entry, onChange)
    picker = picker or BuildPicker()
    picker.mode, picker.entry, picker.onChange = mode, entry, onChange
    if mode == "list" then
        picker.title:SetText(string.format(T("MAIL_PICK_LIST_TITLE"), entry.name))
        picker.hint:SetText(T("MAIL_PICK_HINT_LIST"))
    else
        picker.title:SetText(T("MAIL_PICK_TITLE"))
        picker.hint:SetText(T("MAIL_PICK_HINT_SEND"))
    end
    picker:Show()
    picker:Raise()
    picker:Fill()
end

------------------------------------------------------------------------
-- Reiter: Posteingang
------------------------------------------------------------------------

local function BuildInbox(parent)
    local f = CreateFrame("Frame", nil, parent)
    local rows = {}
    local LIST_W = 300

    f.info = UI.CreateLabel(f, "", { size = 12, color = "textDim" })
    f.info:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -6)

    f.none = UI.CreateButton(f, T("MAIL_SELECT_NONE"), 130, 24, function() Mail:SelectAll(false) end, "default")
    f.none:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.all = UI.CreateButton(f, T("MAIL_SELECT_ALL"), 130, 24, function() Mail:SelectAll(true) end, "default")
    f.all:SetPoint("RIGHT", f.none, "LEFT", -6, 0)

    f.open = UI.CreateButton(f, T("MAIL_OPEN_ALL"), 280, 30, function()
        Mail:StartOpen(Mail:SelectedCount() > 0)
    end, "primary")
    f.open:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -32)
    f.stop = UI.CreateButton(f, T("MAIL_STOP"), 110, 30, function() Mail:Stop() end, "danger")
    f.stop:SetPoint("LEFT", f.open, "RIGHT", 8, 0)

    f.note = UI.CreateLabel(f, T("MAIL_NOTE_SAFE"), { size = 11, color = "textDim", justifyV = "TOP" })
    f.note:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f.note:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.note:SetHeight(30)
    f.note:SetWordWrap(true)

    f.scroll = UI.CreateScrollFrame(f)
    f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -70)
    f.scroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 36)
    f.scroll:SetWidth(LIST_W)
    -- Ladebalken ueber dem Postfach, solange grosse Postfaecher in Haeppchen geholt werden
    f.load = CreateFrame("Frame", nil, f)
    f.load:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -70)
    f.load:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 36)
    f.load:SetWidth(LIST_W)
    f.load:SetFrameLevel((f.scroll:GetFrameLevel() or 1) + 20)
    f.load:EnableMouse(true)
    f.load.bg = f.load:CreateTexture(nil, "BACKGROUND")
    f.load.bg:SetAllPoints(f.load)
    f.load.bg:SetColorTexture(0.02, 0.02, 0.04, 0.82)
    f.load.text = UI.CreateLabel(f.load, "", { size = 12, color = "goldLight", justify = "CENTER" })
    f.load.text:SetPoint("CENTER", f.load, "CENTER", 0, 14)
    f.load.track = f.load:CreateTexture(nil, "ARTWORK")
    f.load.track:SetPoint("CENTER", f.load, "CENTER", 0, -8)
    f.load.track:SetWidth(LIST_W - 40)
    f.load.track:SetHeight(10)
    f.load.track:SetColorTexture(0.15, 0.13, 0.08, 1)
    f.load.fill = f.load:CreateTexture(nil, "OVERLAY")
    f.load.fill:SetPoint("LEFT", f.load.track, "LEFT", 0, 0)
    f.load.fill:SetHeight(10)
    f.load.fill:SetColorTexture(0.9, 0.7, 0.25, 1)
    f.load:Hide()
    f.empty = UI.CreateLabel(f.scroll.child, T("MAIL_INBOX_EMPTY"), { size = 12, color = "textDim" })
    f.empty:SetPoint("TOPLEFT", f.scroll.child, "TOPLEFT", 4, -6)

    ---------------- Lesefenster rechts ----------------
    local d = UI.CreatePanel(f, "card", "bronze")
    d:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 12, -70)
    d:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 36)
    d.empty = UI.CreateLabel(d, T("MAIL_DETAIL_EMPTY"), { size = 12, color = "textDim", justify = "CENTER" })
    d.empty:SetPoint("CENTER", d, "CENTER", 0, 0)
    d.subj = UI.CreateLabel(d, "", { font = "heading", size = 14, color = "goldLight" })
    d.subj:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -10)
    d.subj:SetPoint("RIGHT", d, "RIGHT", -12, 0)
    d.subj:SetWordWrap(false)
    d.meta = UI.CreateLabel(d, "", { size = 11, color = "textDim" })
    d.meta:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -32)
    d.meta:SetPoint("RIGHT", d, "RIGHT", -12, 0)
    d.meta:SetWordWrap(false)
    d.attach = UI.CreateLabel(d, "", { size = 12 })
    d.attach:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -52)
    d.attach:SetPoint("RIGHT", d, "RIGHT", -12, 0)
    d.attach:SetWordWrap(false)
    d.bodyScroll = UI.CreateScrollFrame(d)
    d.bodyScroll:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -76)
    d.bodyScroll:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -12, 132)
    d.body = UI.CreateLabel(d.bodyScroll.child, "", { size = 12, justifyV = "TOP" })
    d.body:SetPoint("TOPLEFT", d.bodyScroll.child, "TOPLEFT", 2, -2)
    d.msg = UI.CreateLabel(d, "", { size = 11, color = "danger" })
    d.msg:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 12, 108)
    d.msg:SetPoint("RIGHT", d, "RIGHT", -12, 0)
    d.msg:SetWordWrap(false)
    d.take = UI.CreateButton(d, T("MAIL_TAKE_ITEM"), 120, 26, nil, "primary")
    d.take:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 12, 76)   -- drei feste Reihen: Nehmen / Zurueck / Antworten + Loeschen
    d.reply = UI.CreateButton(d, T("MAIL_REPLY"), 80, 26, nil, "default")
    d.reply:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 12, 12)
    d.ret = UI.CreateButton(d, T("MAIL_RETURN"), 170, 26, nil, "default")
    d.ret:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 12, 44)
    UI.AttachTooltip(d.ret, function() return T("MAIL_RETURN") end, function() return T("MAIL_RETURN_TIP") end)
    d.delete = UI.CreateButton(d, T("MAIL_DELETE"), 80, 26, nil, "danger")
    d.delete:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -12, 12)
    UI.AttachTooltip(d.delete, function() return T("MAIL_DELETE") end, function()
        local c = f.current
        if c and (c.cod or 0) > 0 then return T("MAIL_DELETE_COD_TIP") end
        return T("MAIL_DELETE_TIP")
    end)
    f.detail = d

    local function ShowError(why)
        d.msg:SetText(why and (FW.L["MAIL_ERR_" .. why] or why) or "")
    end

    d.take:SetScript("OnClick", function()
        local m = f.current
        if not m then return end
        if m.cod > 0 and f.codConfirm ~= m.key then
            f.codConfirm = m.key
            f.Refresh()
            return
        end
        f.codConfirm = nil
        local ok, why = Mail:TakeOne(m)
        ShowError(not ok and why or nil)
        f.Refresh()
    end)
    d.delete:SetScript("OnClick", function()
        local m = f.current
        if not m then return end
        -- Nachnahme: nie loeschen, sofort an den Absender zurueck (ohne Rueckfrage)
        if (m.cod or 0) > 0 then
            local rok, rwhy = Mail:ReturnMail(m)
            if rok then
                Mail.view, f.current, f.shownKey = nil, nil, nil
                ShowError(nil)
                if FW.Print then FW:Print(FW.L.MAIL_COD_RETURNED) end
            else
                ShowError(rwhy)
            end
            f.Refresh()
            return
        end
        local ok, why = Mail:RemoveMail(m)
        if ok then
            Mail.view, f.current, f.shownKey = nil, nil, nil
            ShowError(nil)
        else
            ShowError(why)
        end
        f.Refresh()
    end)
    local function DoReturn(m)
        if not m then return end
        if f.retConfirm ~= m.key then
            f.retConfirm = m.key
            f.Refresh()
            return
        end
        f.retConfirm = nil
        local ok, why = Mail:ReturnMail(m)
        if ok then
            Mail.view, f.current, f.shownKey = nil, nil, nil
            ShowError(nil)
        else
            ShowError(why)
        end
        f.Refresh()
    end
    f.DoReturn = DoReturn
    d.ret:SetScript("OnClick", function() DoReturn(f.current) end)
    d.reply:SetScript("OnClick", function()
        local m = f.current
        if m and panes.send and panes.send.Prefill then
            local subj = m.subject or ""
            if subj:sub(1, 3):lower() ~= "re:" then subj = "Re: " .. subj end
            SelectTab("send")
            panes.send.Prefill(m.sender, subj)
        end
    end)

    local function Row(i)
        local row = rows[i]
        if row then return row end
        row = UI.CreatePanel(f.scroll.child, "card", "bronze")
        row:SetHeight(ROW_H)
        row.cb = UI.CreateCheckbox(row, "", function() return row.mail and Mail.selected[row.mail.key] end, function(v)
            if row.mail then Mail:ToggleSelect(row.mail.key, v) end
        end)
        row.cb:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.cb:SetWidth(22)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(28, 28)
        row.icon:SetPoint("LEFT", row, "LEFT", 32, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.l1 = UI.CreateLabel(row, "", { size = 12 })
        row.l1:SetPoint("TOPLEFT", row, "TOPLEFT", 66, -6)
        row.l1:SetPoint("RIGHT", row, "RIGHT", -70, 0)
        row.l1:SetWordWrap(false)
        row.l2 = UI.CreateLabel(row, "", { size = 11, color = "textDim" })
        row.l2:SetPoint("TOPLEFT", row, "TOPLEFT", 66, -22)
        row.l2:SetPoint("RIGHT", row, "RIGHT", -70, 0)
        row.l2:SetWordWrap(false)
        row.ret = UI.CreateButton(row, "<", 24, 22, nil, "default")
        row.ret:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        UI.AttachTooltip(row.ret, function() return T("MAIL_RETURN") end, function() return T("MAIL_RETURN_TIP") end)
        row.ret:SetScript("OnClick", function()
            if row.mail then
                Mail.view = { key = row.mail.key, pair = Mail.Pair(row.mail) }
                f.DoReturn(row.mail)
            end
        end)
        row.days = UI.CreateLabel(row, "", { size = 11, color = "textDim", justify = "RIGHT" })
        row.days:SetPoint("RIGHT", row.ret, "LEFT", -4, 0)
        Tooltip(row)
        row:SetScript("OnMouseUp", function()
            if row.mail then
                Mail.view = { key = row.mail.key, pair = Mail.Pair(row.mail) }
                f.codConfirm = nil
                f.retConfirm = nil
                ShowError(nil)
                f.Refresh()
            end
        end)
        rows[i] = row
        return row
    end

    local function RefreshDetail(list)
        local view = Mail.view
        local cur
        if view then
            for _, m in ipairs(list) do
                if m.key == view.key then cur = m break end
            end
            if not cur then
                for _, m in ipairs(list) do
                    if Mail.Pair(m) == view.pair then cur = m break end
                end
            end
        end
        f.current = cur
        d.empty:SetShown(cur == nil)
        for _, w in ipairs({ d.subj, d.meta, d.attach, d.bodyScroll, d.msg, d.take, d.reply, d.ret, d.delete }) do
            w:SetShown(cur ~= nil)
        end
        if not cur then f.shownKey = nil return end
        view.key = cur.key
        if f.shownKey ~= cur.key then
            f.shownKey = cur.key
            f.bodyTries = 0
            f.bodyText = Mail.ReadText(cur.i)
            if FW.Brett and FW.Brett.CheckMailData then pcall(FW.Brett.CheckMailData, cur.i) end
        elseif (f.bodyText or "") == "" and (f.bodyTries or 0) < 5 then
            -- der Server liefert den Brieftext manchmal erst einen Moment spaeter: noch einmal lesen
            f.bodyTries = (f.bodyTries or 0) + 1
            f.bodyText = Mail.ReadText(cur.i)
            if (f.bodyText or "") == "" and C_Timer and C_Timer.After then
                local key = cur.key
                C_Timer.After(0.7, function() if f.shownKey == key and f:IsShown() then f.Refresh() end end)
            end
        end
        d.subj:SetText(cur.subject ~= "" and Mail.ColorSubject(cur.subject) or T("MAIL_ARCH_NOSUBJECT"))
        d.meta:SetText(string.format(T("MAIL_DETAIL_FROM"), cur.sender) .. (cur.days and ("   " .. string.format(T("MAIL_ROW_DAYS"), math.floor(cur.days))) or ""))
        local parts = {}
        if cur.hasItem then parts[#parts + 1] = string.format(T("MAIL_ATTACH_ITEM"), (cur.itemName or "?") .. ((cur.itemCount or 1) > 1 and (" x" .. cur.itemCount) or "")) end
        if cur.money > 0 then parts[#parts + 1] = string.format(T("MAIL_ATTACH_GOLD"), Mail.Money(cur.money)) end
        local attach = #parts > 0 and table.concat(parts, "   ") or T("MAIL_ATTACH_NONE")
        if cur.cod > 0 then attach = attach .. "   |cffff7060" .. string.format(T("MAIL_ATTACH_COD"), Mail.Money(cur.cod)) .. "|r" end
        d.attach:SetText(attach)
        local text = f.bodyText or ""
        d.body:SetText(text ~= "" and Mail.ColorBody(text) or "|cff8a8f9a" .. T("MAIL_DETAIL_NOTEXT") .. "|r")
        local bw = math.max(200, (d.bodyScroll:GetWidth() or 0) - 22)
        local h = UI.FitLabel(d.body, bw, 20)
        d.bodyScroll:SetContentHeight(h + 8)

        local busy = Mail.busy ~= nil
        local canTake = (cur.money > 0 and cur.cod == 0) or cur.hasItem
        if cur.cod > 0 then
            d.take:SetLabel(f.codConfirm == cur.key and string.format(T("MAIL_TAKE_COD_CONFIRM"), Mail.Money(cur.cod)) or string.format(T("MAIL_TAKE_COD"), Mail.Money(cur.cod)))
            d.take:SetWidth(210)
        else
            d.take:SetLabel(cur.money > 0 and T("MAIL_TAKE_GOLD") or T("MAIL_TAKE_ITEM"))
            d.take:SetWidth(120)
        end
        d.take:SetButtonEnabled(canTake and not busy and Mail.open)
        d.delete:SetButtonEnabled(((cur.cod or 0) > 0 and Mail.Returnable(cur) or Mail.Deletable(cur)) and not busy and Mail.open)
        d.reply:SetButtonEnabled(true)
        d.ret:SetLabel(f.retConfirm == cur.key and T("MAIL_RETURN_CONFIRM") or T("MAIL_RETURN"))
        d.ret:SetButtonEnabled(Mail.Returnable(cur) and not busy and Mail.open)
    end

    function f.Refresh()
        local loading, done, total = Mail.Loading()
        if loading then
            f.load.text:SetText(string.format(T("MAIL_LOADING"), done, total))
            f.load.fill:SetWidth(math.max(1, (LIST_W - 40) * done / math.max(total, 1)))
            f.load:Show()
        else
            f.load:Hide()
        end
        local list = Mail.ReadInbox()
        local busy = Mail.busy
        local takeable = 0
        local view = Mail.view
        for i, m in ipairs(list) do local m = m
            local row = Row(i)
            row.mail = m
            row.inboxIndex = m.hasItem and m.i or nil
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f.scroll.child, "TOPLEFT", 0, -((i - 1) * (ROW_H + ROW_GAP)))
            row:SetWidth(RowWidth(f.scroll, 250))
            if m.itemTex then
                row.icon:SetTexture(m.itemTex)
            elseif m.money > 0 then
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
            else
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
            end
            row.l1:SetText(m.subject ~= "" and Mail.ColorSubject(m.subject) or m.sender)
            local parts = {}
            if m.hasItem then parts[#parts + 1] = (m.itemName or "?") .. ((m.itemCount or 1) > 1 and (" x" .. m.itemCount) or "") end
            if m.money > 0 then parts[#parts + 1] = Mail.Money(m.money) end
            local text
            if m.cod > 0 then
                text = "|cffff7060" .. string.format(T("MAIL_ROW_COD"), Mail.Money(m.cod)) .. "|r"
            elseif #parts == 0 then
                text = m.sender
            else
                text = table.concat(parts, "  +  ")
            end
            row.l2:SetText(text)
            row.days:SetText(m.days and string.format(T("MAIL_ROW_DAYS"), math.floor(m.days)) or "")
            row.ret:SetLabel(f.retConfirm == m.key and "?" or "<")
            row.ret:SetButtonEnabled(Mail.Returnable(m) and not busy and Mail.open)
            row.cb:SetShown(m.take)
            row:SetAlpha(m.take and 1 or 0.75)
            row.cb:Refresh()
            UI.SetBorderColor(row, (view and view.key == m.key) and "gold" or "bronze")
            if m.take then takeable = takeable + 1 end
            row:Show()
        end
        for i = #list + 1, #rows do rows[i].mail = nil rows[i]:Hide() end
        f.empty:SetShown(#list == 0)
        f.scroll:SetContentHeight(#list * (ROW_H + ROW_GAP) + 4)
        f.info:SetText(string.format(T("MAIL_INBOX_COUNT"), #list))
        RefreshDetail(list)

        local sel = Mail:SelectedCount()
        f.open:SetLabel(sel > 0 and string.format(T("MAIL_OPEN_SELECTED"), sel) or T("MAIL_OPEN_ALL"))
        f.open:SetButtonEnabled(Mail.open and not busy and (sel > 0 or #list > 0))
        f.stop:SetShown(busy ~= nil)
        f.all:SetButtonEnabled(not busy and takeable > 0)
        f.none:SetButtonEnabled(not busy and sel > 0)
    end

    return f
end

------------------------------------------------------------------------
-- Reiter: Senden
------------------------------------------------------------------------

local function BuildSend(parent)
    local f = CreateFrame("Frame", nil, parent)
    local rows = {}
    local cod = false

    Heading(f, T("MAIL_TO"), 0, 0)
    local toBox, toEdit = MakeEdit(f, 300, nil, 24)
    toBox:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -20)
    local dd
    dd = UI.CreateDropdown(f, 170, 26, {
        allText = T("MAIL_TO_RECENT"),
        getOptions = function()
            local o = {}
            for _, n in ipairs(Mail:Recipients()) do o[#o + 1] = { value = n, text = n } end
            return o
        end,
        onChange = function(v)
            if v then toBox:Set(v) end
            dd:SetValue(nil)
        end,
    })
    dd:SetPoint("LEFT", toBox, "RIGHT", 8, 0)

    Heading(f, T("MAIL_SUBJECT"), 0, -54)
    local subjBox = MakeEdit(f, 616, nil, 64)   -- genauso breit wie das Textfeld (dessen Rollbalken nimmt 12 ab)
    subjBox:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -74)

    Heading(f, T("MAIL_BODY"), 0, -108)
    local body = UI.CreateTextArea(f, 628, 64)
    body:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -128)

    -- Items
    Heading(f, T("MAIL_ITEMS"), 0, -202)
    local addBtn = UI.CreateButton(f, T("MAIL_ITEMS_ADD"), 170, 24, nil, "default")
    addBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 120, -198)
    local itemScroll = UI.CreateScrollFrame(f)
    itemScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -228)
    itemScroll:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -228)
    itemScroll:SetHeight(104)
    local itemsEmpty = UI.CreateLabel(itemScroll.child, T("MAIL_ITEMS_NONE"), { size = 12, color = "textDim" })
    itemsEmpty:SetPoint("TOPLEFT", itemScroll.child, "TOPLEFT", 4, -6)
    itemsEmpty:SetPoint("TOPRIGHT", itemScroll.child, "TOPRIGHT", -16, -6)
    itemsEmpty:SetJustifyH("LEFT")
    itemsEmpty:SetWordWrap(true)

    -- Gold und Nachnahme
    local goldBox = MakeEdit(f, 90, T("MAIL_GOLD"), 7, true)
    goldBox:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -344)
    local silverBox = MakeEdit(f, 70, T("MAIL_SILVER"), 2, true)
    silverBox:SetPoint("LEFT", goldBox, "RIGHT", 8, 0)
    local copperBox = MakeEdit(f, 70, T("MAIL_COPPER"), 2, true)
    copperBox:SetPoint("LEFT", silverBox, "RIGHT", 8, 0)
    local codBox = UI.CreateCheckbox(f, T("MAIL_COD"), function() return cod end, function(v) cod = v and true or false end)
    codBox:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -376)
    codBox:SetWidth(620)

    local status = UI.CreateLabel(f, "", { size = 12, color = "textDim", justify = "LEFT" })
    status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 6)
    status:SetPoint("RIGHT", f, "RIGHT", -160, 0)
    status:SetWordWrap(false)
    local send = UI.CreateButton(f, T("MAIL_SEND"), 150, 30, nil, "primary")
    send:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    -- Brett-Brief: sichtbare Vorbereitung im eigenen Fenster (verdeckt das Formular, solange der Auftrag den Brief fuellt)
    local bl = UI.CreatePanel(f, "bgDeep", "gold")
    bl:SetPoint("TOPLEFT", f, "TOPLEFT", -8, 8)
    bl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 8, -8)
    bl:SetFrameLevel(f:GetFrameLevel() + 30)
    bl:EnableMouse(true)
    bl:Hide()
    local blTitle = UI.CreateLabel(bl, T("MAIL_BOARD_TITLE"), { font = "heading", size = 15, color = "goldLight" })
    blTitle:SetPoint("TOPLEFT", bl, "TOPLEFT", 16, -14)
    bl.lines = {}
    for i = 1, 6 do
        local l = UI.CreateLabel(bl, "", { size = 12 })
        l:SetPoint("TOPLEFT", bl, "TOPLEFT", 16, -48 - (i - 1) * 24)
        l:SetPoint("TOPRIGHT", bl, "TOPRIGHT", -16, -48 - (i - 1) * 24)
        l:SetWordWrap(false)
        bl.lines[i] = l
    end
    bl.status = UI.CreateLabel(bl, "", { size = 12, color = "goldLight", justifyV = "TOP" })
    bl.status:SetPoint("TOPLEFT", bl, "TOPLEFT", 16, -208)
    bl.status:SetPoint("TOPRIGHT", bl, "TOPRIGHT", -16, -208)
    bl.status:SetHeight(48)
    bl.status:SetWordWrap(true)
    bl.add = UI.CreateButton(bl, T("MAIL_BOARD_ADD"), 180, 28, function()
        if FW.Creator and FW.Creator.MailAdd then pcall(FW.Creator.MailAdd) end
        if f.Refresh then f.Refresh() end
    end, "default")
    bl.add:SetPoint("BOTTOMLEFT", bl, "BOTTOMLEFT", 16, 16)
    bl.now = UI.CreateButton(bl, T("MAIL_BOARD_SEND"), 160, 28, function()
        Mail:BoardSend()
        if f.Refresh then f.Refresh() end
    end, "primary")
    bl.now:SetPoint("BOTTOMRIGHT", bl, "BOTTOMRIGHT", -16, 16)

    local function BoardRefresh()
        local b = Mail.BoardLetter()
        if not b then bl:Hide() return false end
        bl:Show()
        for i, l in ipairs(bl.lines) do
            local c = b.list[i]
            l:SetText(c and ((c.ok and "|cff6cc070[x] " or "|cffff7060[ ] ") .. c.text .. "|r") or "")
        end
        local auto = Mail.db.settings.boardAuto
        if b.state == "locked" then bl.status:SetText("|cffff7060" .. T("MAIL_BOARD_LOCKED") .. "|r")
        elseif b.state == "armed" then bl.status:SetText(auto and T("MAIL_BOARD_READY_AUTO") or T("MAIL_BOARD_READY_MANUAL"))
        else bl.status:SetText(T("MAIL_BOARD_FILLING")) end
        bl.now:SetShown(b.state == "armed" and b.all)
        bl.add:SetShown(b.state == "filling" and not b.all)
        Mail:BoardAuto()
        return true
    end

    local function Copper()
        return (tonumber(goldBox.edit:GetText()) or 0) * 10000 + (tonumber(silverBox.edit:GetText()) or 0) * 100 + (tonumber(copperBox.edit:GetText()) or 0)
    end

    local function Form()
        return { to = toEdit:GetText(), subject = subjBox.edit:GetText(), body = body.edit:GetText(), picks = picks, money = Copper(), cod = cod }
    end

    local function SetStatus(text, colorKey)
        status:SetText(text or "")
        status:SetTextColor(UI.Color(colorKey or "textDim"))
    end

    function f.Prefill(to, subject)
        toBox:Set(to or "")
        subjBox:Set(subject or "")
        f.Refresh()
    end

    function f.Refresh()
        if BoardRefresh() then return end
        for i, pk in ipairs(picks) do local pk, i = pk, i
            local row = rows[i]
            if not row then
                row = ItemRow(itemScroll.child, 30)
                row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
                row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
                row.name:SetPoint("RIGHT", row, "RIGHT", -40, 0)
                row.remove = UI.CreateButton(row, "X", 26, 22, nil, "danger")
                row.remove:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", itemScroll.child, "TOPLEFT", 0, -((i - 1) * 34))
            row:SetWidth(RowWidth(itemScroll))
            FillItem(row, pk.id, pk.count)
            row.remove:SetScript("OnClick", function()
                table.remove(picks, i)
                f.Refresh()
            end)
            row:Show()
        end
        for i = #picks + 1, #rows do rows[i]:Hide() end
        itemsEmpty:SetShown(#picks == 0)
        itemScroll:SetContentHeight(#picks * 34 + 4)
        codBox:Refresh()

        local busy = Mail.busy
        local boardBusy = Mail.BoardBusy()
        local jobs, err = Mail:BuildCompose(Form())
        if boardBusy then
            SetStatus(T("MAIL_BOARD_BUSY"), "goldLight")
        elseif busy then
            SetStatus(T("MAIL_BUSY"), "textDim")
        elseif jobs then
            SetStatus(#jobs == 1 and T("MAIL_SEND_COUNT1") or string.format(T("MAIL_SEND_COUNT"), #jobs), "textDim")
        elseif err == "to" then SetStatus(T("MAIL_SEND_NO_TO"), "textDim")
        elseif err == "self" then SetStatus(T("MAIL_SEND_SELF"), "danger")
        elseif err == "codItem" then SetStatus(T("MAIL_SEND_COD_NEEDS_ITEM"), "danger")
        else SetStatus(T("MAIL_SEND_NOTHING"), "textDim") end
        send:SetButtonEnabled(jobs ~= nil and Mail.open and not busy and not boardBusy)
    end

    for _, b in ipairs({ goldBox, silverBox, copperBox, subjBox }) do b.onChange = function() if f:IsShown() then f.Refresh() end end end
    toBox.onChange = function() if f:IsShown() then f.Refresh() end end
    addBtn:SetScript("OnClick", function() OpenPicker("send", nil, f.Refresh) end)
    send:SetScript("OnClick", function()
        local jobs = Mail:BuildCompose(Form())
        if not jobs then return f.Refresh() end
        local ok = Mail:StartSend(jobs)
        if ok then f.pendingClear = #jobs end
        f.Refresh()
    end)
    FW:On("MAIL_SENT_DONE", function(_, sent, total)
        if f.pendingClear and sent >= f.pendingClear then
            for i = #picks, 1, -1 do table.remove(picks, i) end
            subjBox:Set("")
            body.edit:SetText("")
            goldBox:Set("") silverBox:Set("") copperBox:Set("")
            cod = false
        end
        f.pendingClear = nil
        if f:IsShown() then f.Refresh() end
    end, OWNER)
    FW:On("MAIL_RECIPIENTS_CHANGED", function() end, OWNER)
    for _, target in ipairs({ itemScroll, itemScroll.scroll, itemScroll.child, itemsEmpty and itemScroll.child }) do
        MakeDropTarget(target, function(id) Drop.send(id) end)
    end

    -- Brett-Auftraege melden sich nicht bei uns; das Fenster fragt deshalb im Takt nach
    local acc = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc > 0.5 then
            acc = 0
            f.Refresh()
        end
    end)

    return f
end

------------------------------------------------------------------------
-- Reiter: Mailinglisten
------------------------------------------------------------------------

local LIST_ROW_H = 96

local function BuildLists(parent)
    local f = CreateFrame("Frame", nil, parent)
    local rows = {}

    local nameBox, nameEdit = MakeEdit(f, 220, T("MAIL_LISTS_NAME_BOX"), 24)
    nameBox:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local status = UI.CreateLabel(f, "", { size = 11, color = "textDim" })
    local function Add()
        local ok, why = Mail:AddList(nameEdit:GetText())
        if ok then
            nameBox:Set("")
            nameEdit:ClearFocus()
            status:SetText("")
        else
            status:SetText(why == "exists" and "Name exists." or (why == "full" and "List is full." or "Invalid name."))
        end
    end
    local addBtn = UI.CreateButton(f, T("MAIL_LISTS_ADD"), 110, 26, Add, "primary")
    addBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    nameEdit:SetScript("OnEnterPressed", Add)
    status:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
    local allBtn = UI.CreateButton(f, T("MAIL_LISTS_ALL_NOW"), 190, 26, function() Mail:SendLists(nil, false) end, "default")
    allBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

    local hint = UI.CreateLabel(f, T("MAIL_LISTS_HINT"), { size = 11, color = "textDim", justifyV = "TOP" })
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -34)
    hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -34)
    hint:SetHeight(28)
    hint:SetWordWrap(true)

    local reserved = UI.CreateLabel(f, "", { size = 11, color = "goldLight" })
    reserved:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 2)

    local scroll = UI.CreateScrollFrame(f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -66)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 24)
    local empty = UI.CreateLabel(scroll.child, T("MAIL_LISTS_EMPTY"), { size = 12, color = "textDim" })
    empty:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 4, -6)

    local function Row(i)
        local row = rows[i]
        if row then return row end
        row = UI.CreatePanel(scroll.child, "card", "bronze")
        row:SetHeight(LIST_ROW_H)
        MakeDropTarget(row, function(id)
            if row.entry and not Mail:HasListItem(row.entry, id) then Mail:ToggleListItem(row.entry, id) end
        end)
        row.name = UI.CreateLabel(row, "", { font = "heading", size = 14, color = "goldLight" })
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -12)
        row.name:SetWidth(170)
        row.name:SetWordWrap(false)
        row.items = UI.CreateButton(row, "", 130, 24, function()
            if row.entry then OpenPicker("list", row.entry, function() f.Refresh() end) end
        end, "default")
        row.items:SetPoint("TOPLEFT", row, "TOPLEFT", 190, -8)
        row.now = UI.CreateButton(row, T("MAIL_LISTS_NOW"), 120, 24, function()
            if row.entry then Mail:SendLists(row.entry, false) end
        end, "default")
        row.now:SetPoint("TOPLEFT", row, "TOPLEFT", 328, -8)
        row.remove = UI.CreateButton(row, "X", 26, 24, function()
            if row.entry then Mail:RemoveList(row.entry) end
        end, "danger")
        row.remove:SetPoint("TOPLEFT", row, "TOPLEFT", 456, -8)
        UI.AttachTooltip(row.remove, function() return T("MAIL_LISTS_REMOVE") end, "")
        row.selfNote = UI.CreateLabel(row, T("MAIL_LISTS_SELF"), { size = 11, color = "textDim" })
        row.selfNote:SetPoint("TOPLEFT", row, "TOPLEFT", 328, -13)

        row.auto = UI.CreateCheckbox(row, T("MAIL_LISTS_AUTO"), function() return row.entry and row.entry.auto end, function(v)
            if row.entry then row.entry.auto = v and true or false end
        end)
        row.auto:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -40)
        row.auto:SetWidth(420)
        row.gold = UI.CreateCheckbox(row, T("MAIL_LISTS_GOLD"), function() return row.entry and row.entry.gold end, function(v)
            if row.entry then row.entry.gold = v and true or false end
        end)
        row.gold:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -66)
        row.gold:SetWidth(170)
        row.keepBox = MakeEdit(row, 80, nil, 7, true)
        row.keepBox:SetPoint("TOPLEFT", row, "TOPLEFT", 186, -64)
        row.keepBox.onChange = function(text)
            if row.entry then row.entry.keep = math.max(0, math.floor(tonumber(text) or 0)) * 10000 end
        end
        row.keepLabel = UI.CreateLabel(row, T("MAIL_LISTS_GOLD_G"), { size = 12, color = "textDim" })
        row.keepLabel:SetPoint("LEFT", row.keepBox, "RIGHT", 8, 0)
        rows[i] = row
        return row
    end

    function f.Refresh()
        local lists = Mail.db.lists
        for i, e in ipairs(lists) do
            local row = Row(i)
            row.entry = e
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -((i - 1) * (LIST_ROW_H + ROW_GAP)))
            row:SetWidth(RowWidth(scroll, 495))
            row.name:SetText(e.name)
            row.items:SetLabel(string.format(T("MAIL_LISTS_ITEMS"), #e.ids))
            local me = Mail.IsSelf(e.name)
            row.now:SetShown(not me)
            row.selfNote:SetShown(me and true or false)
            row.now:SetButtonEnabled(Mail.open and not Mail.busy and not Mail.BoardBusy())
            row.auto:Refresh()
            row.gold:Refresh()
            row.keepBox:Set(tostring(math.floor((e.keep or 0) / 10000)))
            row:Show()
        end
        for i = #lists + 1, #rows do rows[i].entry = nil rows[i]:Hide() end
        empty:SetShown(#lists == 0)
        scroll:SetContentHeight(#lists * (LIST_ROW_H + ROW_GAP) + 4)
        allBtn:SetButtonEnabled(#lists > 0 and Mail.open and not Mail.busy and not Mail.BoardBusy())
        local _, n = Mail.Reserved()
        reserved:SetText(n > 0 and string.format(T("MAIL_LISTS_RESERVED"), n) or "")
    end

    return f
end

------------------------------------------------------------------------
-- Fenster
------------------------------------------------------------------------

local TAB_DEFS = {
    { id = "inbox", label = "MAIL_TAB_INBOX", build = BuildInbox },
    { id = "send", label = "MAIL_TAB_SEND", build = BuildSend },
    { id = "lists", label = "MAIL_TAB_LISTS", build = BuildLists },
}

function SelectTab(id)
    current = id
    for _, def in ipairs(TAB_DEFS) do
        local pane = panes[def.id]
        if pane then
            if def.id == id then pane:Show() pane.Refresh() else pane:Hide() end
        end
        if tabs[def.id] then tabs[def.id]:SetActive(def.id == id) end
    end
end

local function UpdateFooter()
    if not footer then return end
    local text = ""
    if Mail.busy == "inbox" and Mail.run then
        text = string.format(T("MAIL_RUN_PROGRESS"), Mail.run.items, Mail.run.money)
    elseif Mail.busy == "send" then
        local i, n, to = Mail:SendProgress()
        if i then text = string.format(T("MAIL_SEND_PROGRESS"), math.max(i, 1), n, to) end
    end
    footer:SetText(text)
end

local function SavePosition()
    local left, top = window:GetLeft(), window:GetTop()
    if left and top then Mail.db.settings.pos = { x = left, y = top } end
end

local function BuildWindow()
    local f = UI.CreatePanel(UIParent, "bgDeep", "gold")
    f:SetSize(W, H)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SavePosition() end)
    local pos = Mail.db.settings.pos
    f:ClearAllPoints()
    if pos and pos.x and pos.y then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", -120, 40)
    end
    window = f
    Mail.window = f

    local title = UI.CreateLabel(f, T("MAIL_WINDOW_TITLE"), { font = "heading", size = 16, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -12)
    local close = UI.CreateButton(f, "X", 26, 24, function()
        if CloseMail then pcall(CloseMail) end
        if _G.MailFrame and HideUIPanel and MailFrame:IsShown() then pcall(HideUIPanel, MailFrame) end
        f:Hide()
    end, "danger")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    UI.AttachTooltip(close, function() return T("MAIL_CLOSE") end, "")
    local arch = UI.CreateButton(f, T("MAIL_BTN_ARCHIVE"), 80, 24, function()
        if Mail.OpenArchive then Mail.OpenArchive(true) end
    end, "default")
    arch:SetPoint("TOPRIGHT", f, "TOPRIGHT", -42, -10)
    local div = UI.CreateDivider(f)
    div:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -40)
    div:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -40)

    tabs = {}
    local prev
    for _, def in ipairs(TAB_DEFS) do local def = def
        local b = UI.CreateTabButton(f, T(def.label))
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -44) end
        b:SetScript("OnClick", function() SelectTab(def.id) end)
        tabs[def.id] = b
        prev = b
    end

    content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -86)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 32)
    for _, def in ipairs(TAB_DEFS) do
        local pane = def.build(content)
        pane:SetAllPoints(content)
        pane:Hide()
        panes[def.id] = pane
    end

    footer = UI.CreateLabel(f, "", { size = 11, color = "textDim" })
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 10)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 10)
    footer:SetWordWrap(false)

    f:Hide()
    return f
end

-- Rechtsklick auf ein Item in den Taschen: wird dem Brief angehaengt (nur bei unserem Fenster; sonst waere es "benutzen")
local function StackKey(bag, slot)
    local seen = {}
    for _, s in ipairs(Mail.BagStacks()) do
        local base = s.id .. ":" .. s.count
        seen[base] = (seen[base] or 0) + 1
        if s.bag == bag and s.slot == slot and not s.locked then return s.id, s.count, base .. ":" .. seen[base] end
    end
end

-- Das Item am Mauszeiger liegt als gesperrter Stapel in der Tasche: dessen Schluessel suchen
local function CursorStack(id)
    local seen, fallback = {}, nil
    for _, s in ipairs(Mail.BagStacks()) do
        local base = s.id .. ":" .. s.count
        seen[base] = (seen[base] or 0) + 1
        if s.id == id then
            local pk = { id = id, count = s.count, key = base .. ":" .. seen[base] }
            if s.locked then return pk end
            fallback = fallback or pk
        end
    end
    return fallback
end

function Drop.send(id)
    if Mail.busy then return end
    local pk = CursorStack(id)
    if not pk then return end
    for _, p in ipairs(picks) do
        if p.key == pk.key then return end
    end
    picks[#picks + 1] = pk
    SelectTab("send")
end

local function Intercept(bag, slot)
    if not (Mail.open and Mail.Replacing() and window and window:IsShown()) then return false end
    if CursorHasItem and CursorHasItem() then return false end
    if Mail.busy then return true end
    local id, count, key = StackKey(tonumber(bag), tonumber(slot))
    if not id then return true end
    local found
    for k, pk in ipairs(picks) do
        if pk.key == key then found = k end
    end
    if found then table.remove(picks, found) else picks[#picks + 1] = { id = id, count = count, key = key } end
    SelectTab("send")
    if picker and picker:IsShown() then picker:Fill() end
    return true
end

local function WrapUse(owner, name)
    local orig = owner and owner[name]
    if type(orig) ~= "function" then return end
    owner[name] = function(bag, slot, ...)
        local ok, handled = pcall(Intercept, bag, slot)
        if ok and handled then return end
        return orig(bag, slot, ...)
    end
end
WrapUse(_G, "UseContainerItem")
if _G.C_Container then WrapUse(_G.C_Container, "UseContainerItem") end

local function RefreshCurrent()
    local pane = panes[current]
    if window and window:IsShown() and pane and pane.Refresh then pane.Refresh() end
    UpdateFooter()
end

local function ShowWindow()
    local ok, err = pcall(function()
        if not window then BuildWindow() end
        window:Show()
        SelectTab(current)
        UpdateFooter()
    end)
    if not ok then
        -- Fehler: das normale Fenster zurueckgeben, damit der Briefkasten benutzbar bleibt
        Mail.uiFailed = true
        Mail:ApplyReplace()
        Mail.Trace("Fenster-Fehler: " .. tostring(err))
        if FW.Print then FW:Print("Mail: " .. tostring(err)) end
    end
end

local function HideWindow()
    if window then
        if picker then picker:Hide() end
        window:Hide()
    end
end

FW:On("MAIL_WINDOW_SHOW", function() ShowWindow() end, OWNER)
FW:On("CREATOR_MAIL_PREPARING", function() if window and window:IsShown() then SelectTab("send") end end, OWNER)
FW:On("MAIL_WINDOW_HIDE", function() HideWindow() end, OWNER)
FW:On("MAIL_STATE", function() RefreshCurrent() end, OWNER)
FW:On("MAIL_INBOX_CHANGED", function() RefreshCurrent() end, OWNER)
FW:On("MAIL_SELECTION_CHANGED", function() RefreshCurrent() end, OWNER)
FW:On("MAIL_LISTS_CHANGED", function() RefreshCurrent() if picker and picker:IsShown() then picker:Fill() end end, OWNER)

------------------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------------------

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("mail", {
        category = "modules",
        order = 118,
        height = 220,
        build = function(parent)
            local f, stack = UI.CreateSection(parent, T("MAIL_SET_HEADER"))
            local boxes = {}
            local replace = UI.CreateCheckbox(f, T("MAIL_SET_REPLACE"), function()
                return Mail.db.settings.replace
            end, function(value)
                Mail:SetReplace(value)
            end)
            stack:Add(replace, { fit = true, gap = 4 })
            boxes[#boxes + 1] = replace
            local chat = UI.CreateCheckbox(f, T("MAIL_SET_CHAT"), function()
                return Mail.db.settings.chat
            end, function(value)
                Mail.db.settings.chat = value and true or false
            end)
            stack:Add(chat, { fit = true, gap = 4 })
            boxes[#boxes + 1] = chat
            local boardAuto = UI.CreateCheckbox(f, T("MAIL_SET_BOARDAUTO"), function()
                return Mail.db.settings.boardAuto
            end, function(value)
                Mail.db.settings.boardAuto = value and true or false
            end)
            stack:Add(boardAuto, { fit = true, gap = 4 })
            boxes[#boxes + 1] = boardAuto
            local cleanup = UI.CreateCheckbox(f, T("MAIL_SET_CLEANUP"), function()
                return Mail.db.settings.cleanup
            end, function(value)
                Mail.db.settings.cleanup = value and true or false
            end)
            stack:Add(cleanup, { fit = true, gap = 4 })
            boxes[#boxes + 1] = cleanup
            local dd
            dd = UI.CreateDropdown(f, 300, 24, {
                prefix = T("MAIL_SET_ARCHIVE_DAYS"),
                getOptions = function()
                    local o = {}
                    for _, days in ipairs({ 0, 7, 14, 30, 90 }) do
                        o[#o + 1] = { value = days, text = days == 0 and T("MAIL_SET_ARCHIVE_OFF") or string.format(T("MAIL_SET_ARCHIVE_N"), days) }
                    end
                    return o
                end,
                onChange = function(v)
                    if v ~= nil then
                        Mail.db.settings.archiveDays = v
                        Mail:Purge()
                        dd:SetValue(v)
                    end
                end,
            })
            stack:Add(dd, { gap = 8, height = 24 })
            local archBtn = UI.CreateButton(f, T("MAIL_SET_ARCHIVE_BTN"), 160, 26, function()
                if Mail.OpenArchive then Mail.OpenArchive(true) end
            end, "default")
            stack:Add(archBtn, { gap = 8, height = 26 })
            local note = UI.CreateLabel(f, T("MAIL_SET_NOTE"), { size = 11, color = "textDim", justifyV = "TOP" })
            stack:Add(note, { fit = true, gap = 10 })
            function f.Refresh()
                for _, cb in ipairs(boxes) do cb:Refresh() end
                dd:SetValue(Mail.db.settings.archiveDays or 0)
            end
            stack:Layout()
            return f
        end,
        refresh = function(frame)
            frame.Refresh()
        end,
    })
end

------------------------------------------------------------------------
-- Befehl
------------------------------------------------------------------------

SLASH_FREEWOODMAIL1 = "/fwmail"
SlashCmdList["FREEWOODMAIL"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "on" then
        Mail:SetReplace(true)
        FW:Print(T("MAIL_CMD_ON"))
    elseif msg == "archive" or msg == "archiv" then
        if Mail.OpenArchive then Mail.OpenArchive(true) end
    elseif msg == "off" then
        Mail:SetReplace(false)
        FW:Print(T("MAIL_CMD_OFF"))
    elseif Mail.open then
        if window and window:IsShown() then HideWindow() else ShowWindow() end
    else
        FW:Print(T("MAIL_CMD_CLOSED"))
    end
end
