-- Freewood-OctoWoW-Mail: Archiv der entfernten Briefe (eigenes Fenster mit Suche nach Betreff und Absender).
-- Geoeffnet ueber den Knopf "Archiv" im Briefkasten-Fenster, in den Einstellungen oder mit /fwmail archive.
-- Eintraege: { t, sender, subject, body, money, items, char }. Loeschen nach X Tagen: Einstellung (Standard: nie).

local ADDON, NS = ...

local FW = _G.Freewood
local Mail = NS.Mail
if not FW or not Mail then
    return
end

local UI = FW.UI
local W, H = 720, 500
local LIST_W = 290
local ROW_H, ROW_GAP = 40, 4

local win
local rows = {}
local filter = ""
local selected      -- gewaehlter Eintrag (Tabelle)
local clearConfirm = false

local function T(key) return FW.L[key] or key end
local function Stamp(t) return date and date("%d.%m.%y %H:%M", t or 0) or "" end

local function Matches(e, q)
    if q == "" then return true end
    q = q:lower()
    return (tostring(e.subject or ""):lower():find(q, 1, true) or tostring(e.sender or ""):lower():find(q, 1, true)) and true or false
end

local function Build()
    local f = UI.CreatePanel(UIParent, "bgDeep", "gold")
    f:SetSize(W, H)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left, top = self:GetLeft(), self:GetTop()
        if left and top then Mail.db.settings.archivePos = { x = left, y = top } end
    end)
    local pos = Mail.db.settings.archivePos
    f:ClearAllPoints()
    if pos and pos.x and pos.y then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 60, 0)
    end

    local title = UI.CreateLabel(f, T("MAIL_ARCH_TITLE"), { font = "heading", size = 16, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -12)
    local close = UI.CreateButton(f, "X", 26, 24, function() f:Hide() end, "danger")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    local div = UI.CreateDivider(f)
    div:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -40)
    div:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -40)

    -- Suche
    local box = UI.CreatePanel(f, "bgDeep", "bronze")
    box:SetSize(LIST_W, 26)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -52)
    local edit = CreateFrame("EditBox", nil, box)
    edit:SetAutoFocus(false)
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -2)
    edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 2)
    edit:SetMaxLetters(60)
    if not edit:SetFont(UI.GetFontPath("body"), 12, "") then edit:SetFont("Fonts\\FRIZQT__.TTF", 12, "") end
    edit:SetTextColor(UI.Color("text"))
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local hint = UI.CreateLabel(box, T("MAIL_ARCH_SEARCH"), { size = 12, color = "textDim" })
    hint:SetPoint("LEFT", box, "LEFT", 10, 0)
    edit:SetScript("OnTextChanged", function(self)
        filter = self:GetText() or ""
        if filter == "" then hint:Show() else hint:Hide() end
        if f.Refresh then f.Refresh() end
    end)
    f.count = UI.CreateLabel(f, "", { size = 11, color = "textDim" })
    f.count:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -84)

    -- Liste
    f.scroll = UI.CreateScrollFrame(f)
    f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -102)
    f.scroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 16)
    f.scroll:SetWidth(LIST_W)
    f.empty = UI.CreateLabel(f.scroll.child, T("MAIL_ARCH_EMPTY"), { size = 12, color = "textDim" })
    f.empty:SetPoint("TOPLEFT", f.scroll.child, "TOPLEFT", 4, -6)

    -- Lesefenster
    local d = UI.CreatePanel(f, "card", "bronze")
    d:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 28, -52)
    d:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
    d.subj = UI.CreateLabel(d, "", { font = "heading", size = 14, color = "goldLight" })
    d.subj:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -10)
    d.subj:SetPoint("RIGHT", d, "RIGHT", -12, 0)
    d.subj:SetWordWrap(false)
    d.meta = UI.CreateLabel(d, "", { size = 11, color = "textDim" })
    d.meta:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -32)
    d.meta:SetPoint("RIGHT", d, "RIGHT", -12, 0)
    d.meta:SetWordWrap(false)
    d.taken = UI.CreateLabel(d, "", { size = 12 })
    d.taken:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -52)
    d.taken:SetPoint("RIGHT", d, "RIGHT", -12, 0)
    d.taken:SetWordWrap(false)
    d.bodyScroll = UI.CreateScrollFrame(d)
    d.bodyScroll:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -76)
    d.bodyScroll:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -12, 50)
    d.body = UI.CreateLabel(d.bodyScroll.child, "", { size = 12, justifyV = "TOP" })
    d.body:SetPoint("TOPLEFT", d.bodyScroll.child, "TOPLEFT", 2, -2)
    d.del = UI.CreateButton(d, T("MAIL_ARCH_DELETE"), 130, 26, function()
        if not selected then return end
        local a = Mail.db.archive
        for i, e in ipairs(a) do
            if e == selected then table.remove(a, i) break end
        end
        selected = nil
        f.Refresh()
    end, "danger")
    d.del:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 12, 12)
    d.clear = UI.CreateButton(d, T("MAIL_ARCH_CLEAR"), 210, 26, function()
        if not clearConfirm then
            clearConfirm = true
            f.Refresh()
            return
        end
        clearConfirm = false
        for i = #Mail.db.archive, 1, -1 do table.remove(Mail.db.archive, i) end
        selected = nil
        f.Refresh()
    end, "default")
    d.clear:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -12, 12)

    local function Row(i)
        local row = rows[i]
        if row then return row end
        row = UI.CreatePanel(f.scroll.child, "card", "bronze")
        row:SetHeight(ROW_H)
        row:EnableMouse(true)
        row.l1 = UI.CreateLabel(row, "", { size = 12 })
        row.l1:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -6)
        row.l1:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.l1:SetWordWrap(false)
        row.l2 = UI.CreateLabel(row, "", { size = 11, color = "textDim" })
        row.l2:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -22)
        row.l2:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.l2:SetWordWrap(false)
        row:SetScript("OnMouseUp", function()
            selected = row.entry
            clearConfirm = false
            f.Refresh()
        end)
        rows[i] = row
        return row
    end

    function f.Refresh()
        local all = Mail.db.archive
        local list = {}
        for _, e in ipairs(all) do
            if Matches(e, filter) then list[#list + 1] = e end
        end
        local w = math.max(200, (f.scroll:GetWidth() or 0) - 14)
        for i, e in ipairs(list) do
            local row = Row(i)
            row.entry = e
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f.scroll.child, "TOPLEFT", 0, -((i - 1) * (ROW_H + ROW_GAP)))
            row:SetWidth(w)
            row.l1:SetText(e.subject ~= "" and e.subject or T("MAIL_ARCH_NOSUBJECT"))
            row.l2:SetText(tostring(e.sender or "?") .. "   " .. Stamp(e.t))
            UI.SetBorderColor(row, e == selected and "gold" or "bronze")
            row:Show()
        end
        for i = #list + 1, #rows do rows[i].entry = nil rows[i]:Hide() end
        f.empty:SetShown(#list == 0)
        f.scroll:SetContentHeight(#list * (ROW_H + ROW_GAP) + 4)
        f.count:SetText(string.format(T("MAIL_ARCH_COUNT"), #list, #all))

        if selected then
            local e = selected
            d.subj:SetText(e.subject ~= "" and e.subject or T("MAIL_ARCH_NOSUBJECT"))
            d.meta:SetText(string.format(T("MAIL_DETAIL_FROM"), tostring(e.sender or "?")) .. "   " .. Stamp(e.t) ..
                (e.char and ("   " .. string.format(T("MAIL_ARCH_CHAR"), e.char)) or ""))
            local parts = {}
            if (e.money or 0) > 0 then parts[#parts + 1] = Mail.Money(e.money) end
            for _, it in ipairs(e.items or {}) do parts[#parts + 1] = it end
            d.taken:SetText(#parts > 0 and string.format(T("MAIL_ARCH_TAKEN"), table.concat(parts, ", ")) or "")
            local text = e.body or ""
            d.body:SetText(text ~= "" and text or "|cff8a8f9a" .. T("MAIL_DETAIL_NOTEXT") .. "|r")
            local bw = math.max(200, (d.bodyScroll:GetWidth() or 0) - 22)
            local h = UI.FitLabel(d.body, bw, 20)
            d.bodyScroll:SetContentHeight(h + 8)
        end
        for _, wdg in ipairs({ d.subj, d.meta, d.taken, d.bodyScroll, d.del }) do wdg:SetShown(selected ~= nil) end
        d.clear:SetLabel(clearConfirm and T("MAIL_ARCH_CLEAR_CONFIRM") or T("MAIL_ARCH_CLEAR"))
        d.clear:SetButtonEnabled(#all > 0)
    end

    f:SetScript("OnShow", function() f.Refresh() end)
    f:Hide()
    return f
end

function Mail.OpenArchive(toggle)
    if not win then
        local ok, err = pcall(function() win = Build() end)
        if not ok then
            if FW.Print then FW:Print("Mail archive: " .. tostring(err)) end
            return
        end
    end
    if toggle and win:IsShown() then
        win:Hide()
        return
    end
    pcall(Mail.Purge, Mail)
    win:Show()
    win:Raise()
    win.Refresh()
end

FW:On("MAIL_ARCHIVE_CHANGED", function()
    if win and win:IsShown() then win.Refresh() end
end, {})
