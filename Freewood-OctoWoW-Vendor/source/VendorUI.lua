-- Freewood-OctoWoW-Vendor: Tab "Haendler", Einstellungen und der Verkaufsknopf am Haendlerfenster.
-- Links die beiden Listen ("Nie verkaufen" oben, "Immer verkaufen" unten), rechts Hinzufuegen, Taschen und Protokoll.

local ADDON, NS = ...

local FW = _G.Freewood
local Vendor = NS.Vendor
if not FW or not Vendor then
    return
end

local UI = FW.UI

local LIST_W = 380
local ROW_H, ROW_GAP = 34, 4
local SMALL_H = 30

local function ColoredName(name, quality, id)
    local text = name or ("#" .. tostring(id))
    return "|cff" .. UI.RarityHex(quality) .. text .. "|r"
end

local function ListRow(parent)
    local row = UI.CreatePanel(parent, "card", "bronze")
    row:SetHeight(ROW_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = UI.CreateLabel(row, "", { size = 12 })
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -112, 0)
    row.name:SetWordWrap(false)
    row.idLabel = UI.CreateLabel(row, "", { size = 10, color = "textDim", justify = "RIGHT" })
    row.idLabel:SetPoint("RIGHT", row, "RIGHT", -40, 0)
    row.remove = UI.CreateButton(row, "X", 26, 22, nil, "danger")
    row.remove:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    UI.AttachTooltip(row.remove, function() return FW.L.VENDOR_REMOVE end, "")
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if self.itemID and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    return row
end

-- Setzt Symbol und Name einer Zeile (die Item-Daten koennen verzoegert kommen)
local function FillItem(row, id, fallbackName)
    row.itemID = id
    row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    row.name:SetText(ColoredName(fallbackName, 1, id))
    FW.Util.RequestItem(id, function(info)
        if row.itemID ~= id or not info then
            return
        end
        row.icon:SetTexture(info.icon)
        row.name:SetText(ColoredName(info.name, info.quality, id))
    end)
end

------------------------------------------------------------------------
-- Tab
------------------------------------------------------------------------

local function Build(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)
    local rowsBlack, rowsWhite, bagRows, logRows = {}, {}, {}, {}

    ---------------- links: zwei Listen ----------------
    local function MakeList(titleText, topAnchor, topOffset, bottomAnchor, bottomOffset, emptyText)
        local title = UI.CreateLabel(f, titleText, { font = "heading", size = 14, color = "goldLight" })
        title:SetPoint("TOPLEFT", f, topAnchor, 0, topOffset)
        local count = UI.CreateLabel(f, "", { size = 11, color = "textDim", justify = "RIGHT" })
        count:SetPoint("TOPRIGHT", f, topAnchor, LIST_W, topOffset - 4)
        local div = UI.CreateDivider(f)
        div:SetPoint("TOPLEFT", f, topAnchor, 0, topOffset - 26)
        div:SetWidth(LIST_W)
        local scroll = UI.CreateScrollFrame(f)
        scroll:SetPoint("TOPLEFT", f, topAnchor, 0, topOffset - 36)
        scroll:SetPoint("BOTTOMLEFT", f, bottomAnchor, 0, bottomOffset)
        scroll:SetWidth(LIST_W)
        local empty = UI.CreateLabel(scroll.child, emptyText, { size = 12, color = "textDim", justifyV = "TOP" })
        empty:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 4, -6)
        empty:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", -4, -6)
        empty:SetWordWrap(true)
        return { title = title, count = count, scroll = scroll, empty = empty }
    end
    local blackUI = MakeList(L.VENDOR_BLACK_HEADER, "TOPLEFT", 0, "LEFT", 8, L.VENDOR_BLACK_EMPTY)
    local whiteUI = MakeList(L.VENDOR_WHITE_HEADER, "LEFT", -4, "BOTTOMLEFT", 0, L.VENDOR_WHITE_EMPTY)

    local separator = f:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(UI.Color("bronze", 0.5))
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 10, 0)
    separator:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", LIST_W + 10, 0)

    ---------------- rechts ----------------
    local right = CreateFrame("Frame", nil, f)
    right:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 22, 0)
    right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    local addTitle = UI.CreateLabel(right, L.VENDOR_ADD_HEADER, { font = "heading", size = 14, color = "goldLight" })
    addTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
    local addDivider = UI.CreateDivider(right)
    addDivider:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -26)
    addDivider:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -26)

    local status = UI.CreateLabel(right, "", { size = 11, color = "textDim" })
    local function SetStatus(text, colorKey)
        status:SetText(text or "")
        status:SetTextColor(UI.Color(colorKey or "textDim"))
    end
    local function TryAdd(which, input)
        local ok, result = Vendor:Add(which, input)
        if ok then
            local info = FW.Util.GetItem and FW.Util.GetItem(result)
            local key = which == "black" and "VENDOR_ADD_OK_BLACK" or "VENDOR_ADD_OK_WHITE"
            SetStatus(string.format(FW.L[key], (info and info.name) or ("#" .. result)), "success")
            return true
        end
        if result == "already" then
            SetStatus(FW.L.VENDOR_ADD_ALREADY, "goldLight")
        elseif result == "full" then
            SetStatus(FW.L.VENDOR_ADD_FULL, "danger")
        elseif result == "black" then
            SetStatus(FW.L.VENDOR_ADD_ISBLACK, "danger")
        else
            SetStatus(FW.L.VENDOR_ADD_INVALID, "danger")
        end
        return false
    end

    -- Ablagefeld fuer Items aus der Tasche: es fragt nach der Liste
    local drop = UI.CreateItemSlot(right, 44)
    drop:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -38)
    drop:EnableMouse(true)
    local pendingDrop
    local function OnDrop()
        local kind, id = GetCursorInfo()
        if kind == "item" then
            ClearCursor()
            pendingDrop = id
            SetStatus(FW.L.VENDOR_ADD_PICK, "goldLight")
        end
    end
    drop:SetScript("OnReceiveDrag", OnDrop)
    drop:SetScript("OnMouseUp", OnDrop)
    local dropLabel = UI.CreateLabel(right, L.VENDOR_ADD_DROP, { size = 12, color = "textDim" })
    dropLabel:SetPoint("LEFT", drop, "RIGHT", 12, 0)

    -- Eingabefeld
    local box = UI.CreatePanel(right, "bgDeep", "bronze")
    box:SetHeight(26)
    box:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -92)
    box:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -92)
    local edit = CreateFrame("EditBox", nil, box)
    edit:SetAutoFocus(false)
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -2)
    edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 2)
    edit:SetMaxLetters(200)
    if not edit:SetFont(UI.GetFontPath("body"), 12, "") then
        edit:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    end
    edit:SetTextColor(UI.Color("text"))
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local boxHint = UI.CreateLabel(box, L.VENDOR_ADD_BOX, { size = 12, color = "textDim" })
    boxHint:SetPoint("LEFT", box, "LEFT", 10, 0)
    edit:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" then boxHint:Show() else boxHint:Hide() end
    end)

    -- Zwei Knoepfe: in welche Liste?
    local function Submit(which)
        local input = pendingDrop
        local text = edit:GetText()
        if text and text ~= "" then input = text end
        if not input then
            SetStatus(FW.L.VENDOR_ADD_INVALID, "danger")
            return
        end
        if TryAdd(which, input) then
            pendingDrop = nil
            edit:SetText("")
            edit:ClearFocus()
        end
    end
    local addBlack = UI.CreateButton(right, L.VENDOR_ADD_BLACK, 150, 26, function() Submit("black") end, "primary")
    addBlack:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -126)
    local addWhite = UI.CreateButton(right, L.VENDOR_ADD_WHITE, 150, 26, function() Submit("white") end, "default")
    addWhite:SetPoint("LEFT", addBlack, "RIGHT", 8, 0)
    edit:SetScript("OnEnterPressed", function() Submit("black") end)

    -- Shift-Klick auf Item-Links in unser Feld
    local function InsertLink(link)
        if type(link) == "string" and edit:HasFocus() then
            edit:Insert(link)
        end
    end
    if hooksecurefunc then
        if _G.ChatEdit_InsertLink then
            hooksecurefunc("ChatEdit_InsertLink", InsertLink)
        elseif _G.ChatFrameUtil and _G.ChatFrameUtil.InsertLink then
            hooksecurefunc(_G.ChatFrameUtil, "InsertLink", InsertLink)
        end
    end

    local hint = UI.CreateLabel(right, L.VENDOR_ADD_HINT, { size = 11, color = "textDim", justifyV = "TOP" })
    hint:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -160)
    hint:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -160)
    hint:SetHeight(42)
    hint:SetWordWrap(true)
    status:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -206)
    status:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -206)
    status:SetWordWrap(false)

    -- In deinen Taschen
    local bagTitle = UI.CreateLabel(right, L.VENDOR_BAGS_HEADER, { font = "heading", size = 14, color = "goldLight" })
    bagTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -230)
    local bagDivider = UI.CreateDivider(right)
    bagDivider:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -254)
    bagDivider:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -254)
    local bagScroll = UI.CreateScrollFrame(right)
    bagScroll:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -262)
    bagScroll:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 164)
    local bagEmpty = UI.CreateLabel(bagScroll.child, L.VENDOR_BAGS_EMPTY, { size = 12, color = "textDim" })
    bagEmpty:SetPoint("TOPLEFT", bagScroll.child, "TOPLEFT", 4, -6)

    -- Protokoll
    local logTitle = UI.CreateLabel(right, L.VENDOR_LOG_HEADER, { font = "heading", size = 14, color = "goldLight" })
    logTitle:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 134)
    local logDivider = UI.CreateDivider(right)
    logDivider:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 128)
    logDivider:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 128)
    local logScroll = UI.CreateScrollFrame(right)
    logScroll:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
    logScroll:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)
    logScroll:SetHeight(120)
    local logEmpty = UI.CreateLabel(logScroll.child, L.VENDOR_LOG_EMPTY, { size = 12, color = "textDim" })
    logEmpty:SetPoint("TOPLEFT", logScroll.child, "TOPLEFT", 4, -6)

    ---------------- Aktualisieren ----------------
    local function RefreshOne(which, ui, rows)
        local list = Vendor:List(which)
        for i, entry in ipairs(list) do local entry = entry
            local row = rows[i]
            if not row then
                row = ListRow(ui.scroll.child)
                rows[i] = row
            end
            row:ClearAllPoints()
            local y = (i - 1) * (ROW_H + ROW_GAP)
            row:SetPoint("TOPLEFT", ui.scroll.child, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", ui.scroll.child, "TOPRIGHT", 0, -y)
            FillItem(row, entry.id, entry.name)
            row.idLabel:SetText(tostring(entry.id))
            row.remove:SetScript("OnClick", function()
                Vendor:Remove(which, entry.id)
            end)
            row:Show()
        end
        for i = #list + 1, #rows do
            rows[i]:Hide()
        end
        ui.empty:SetShown(#list == 0)
        ui.scroll:SetContentHeight(#list * (ROW_H + ROW_GAP))
        ui.count:SetText(#list > 0 and tostring(#list) or "")
    end
    local function RefreshLists()
        RefreshOne("black", blackUI, rowsBlack)
        RefreshOne("white", whiteUI, rowsWhite)
    end

    local function RefreshBags()
        local items = Vendor:BagItems()
        table.sort(items, function(a, b) return a.id < b.id end)
        for i, entry in ipairs(items) do local entry = entry
            local row = bagRows[i]
            if not row then
                row = UI.CreatePanel(bagScroll.child, "card", "bronze")
                row:SetHeight(SMALL_H)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(22, 22)
                row.icon:SetPoint("LEFT", row, "LEFT", 5, 0)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.name = UI.CreateLabel(row, "", { size = 12 })
                row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
                row.name:SetPoint("RIGHT", row, "RIGHT", -150, 0)
                row.name:SetWordWrap(false)
                row.never = UI.CreateButton(row, FW.L.VENDOR_BAG_NEVER, 66, 22, nil, "default")
                row.never:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                row.always = UI.CreateButton(row, FW.L.VENDOR_BAG_ALWAYS, 72, 22, nil, "default")
                row.always:SetPoint("RIGHT", row.never, "LEFT", -4, 0)
                row.listed = UI.CreateLabel(row, "", { size = 10, color = "textDim", justify = "RIGHT" })
                row.listed:SetPoint("RIGHT", row, "RIGHT", -10, 0)
                row:EnableMouse(true)
                row:SetScript("OnEnter", function(self)
                    if self.itemID and GameTooltip then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
                        GameTooltip:Show()
                    end
                end)
                row:SetScript("OnLeave", function()
                    if GameTooltip then GameTooltip:Hide() end
                end)
                bagRows[i] = row
            end
            row:ClearAllPoints()
            local y = (i - 1) * (SMALL_H + 4)
            row:SetPoint("TOPLEFT", bagScroll.child, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", bagScroll.child, "TOPRIGHT", 0, -y)
            FillItem(row, entry.id)
            local isBlack, isWhite = Vendor:IsBlack(entry.id), Vendor:IsWhite(entry.id)
            row.never:SetShown(not isBlack and not isWhite)
            row.always:SetShown(not isBlack and not isWhite)
            row.listed:SetShown(isBlack or isWhite)
            row.listed:SetText(isBlack and FW.L.VENDOR_BAG_IS_NEVER or (isWhite and FW.L.VENDOR_BAG_IS_ALWAYS or ""))
            row.never:SetScript("OnClick", function() TryAdd("black", entry.id) end)
            row.always:SetScript("OnClick", function() TryAdd("white", entry.id) end)
            row:Show()
        end
        for i = #items + 1, #bagRows do
            bagRows[i]:Hide()
        end
        bagEmpty:SetShown(#items == 0)
        bagScroll:SetContentHeight(#items * (SMALL_H + 4))
    end

    local function RefreshLog()
        local log = Vendor.chardb.log
        for i, entry in ipairs(log) do
            local line = logRows[i]
            if not line then
                line = UI.CreateLabel(logScroll.child, "", { size = 11 })
                logRows[i] = line
            end
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", logScroll.child, "TOPLEFT", 4, -((i - 1) * 18 + 4))
            line:SetPoint("TOPRIGHT", logScroll.child, "TOPRIGHT", -4, -((i - 1) * 18 + 4))
            line:SetWordWrap(false)
            line:SetText(string.format(FW.L.VENDOR_LOG_LINE, date("%H:%M", entry.t or 0), entry.name or "?", entry.count or 1,
                Vendor.Money(entry.price or 0)))
            line:Show()
        end
        for i = #log + 1, #logRows do
            logRows[i]:Hide()
        end
        logEmpty:SetShown(#log == 0)
        logScroll:SetContentHeight(#log * 18 + 8)
    end

    function f.Refresh()
        RefreshLists()
        RefreshBags()
        RefreshLog()
    end

    local function IfShown(fn)
        return function()
            if f:IsShown() then
                fn()
            end
        end
    end
    FW:On("VENDOR_LIST_CHANGED", IfShown(function() f.Refresh() end), f)
    FW:On("VENDOR_LOG_CHANGED", IfShown(RefreshLog), f)
    FW:On("VENDOR_COUNT_CHANGED", IfShown(RefreshBags), f)

    return f
end

UI:RegisterTab("vendor", {
    label = function()
        return FW.L.VENDOR_TAB
    end,
    order = 80,
    build = Build,
    onShow = function(f)
        f.Refresh()
    end,
})

------------------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------------------

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("vendor", {
        category = "modules",
        order = 115,
        height = 190,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.VENDOR_SET_HEADER)
            local boxes = {}
            local defs = {
                { key = "gray", label = L.VENDOR_SET_GRAY },
                { key = "auto", label = L.VENDOR_SET_AUTO },
                { key = "chat", label = L.VENDOR_SET_CHAT },
            }
            for _, def in ipairs(defs) do local def = def
                local cb = UI.CreateCheckbox(f, def.label, function()
                    return Vendor.db.settings[def.key]
                end, function(value)
                    Vendor.db.settings[def.key] = value and true or false
                    Vendor:Recount()
                end)
                stack:Add(cb, { fit = true, gap = 4 })
                boxes[#boxes + 1] = cb
            end
            local note = UI.CreateLabel(f, L.VENDOR_SET_NOTE, { size = 11, color = "textDim", justifyV = "TOP" })
            stack:Add(note, { fit = true, gap = 10 })
            function f.Refresh()
                for _, cb in ipairs(boxes) do
                    cb:Refresh()
                end
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
-- Knopf am Haendlerfenster
------------------------------------------------------------------------

local sellButton
local function EnsureButton()
    if sellButton or not _G.MerchantFrame then
        return sellButton
    end
    local L = FW.L
    sellButton = UI.CreateButton(_G.MerchantFrame, L.VENDOR_BUTTON, 110, 20, function()
        Vendor:Start(true)
    end, "primary")
    sellButton:SetPoint("TOP", _G.MerchantFrame, "TOP", 22, -46)
    sellButton:SetFrameLevel((_G.MerchantFrame:GetFrameLevel() or 1) + 5)
    UI.AttachTooltip(sellButton, function() return FW.L.VENDOR_BUTTON_TIP_TITLE end, function()
        local lines = {
            FW.L.VENDOR_BUTTON_TIP_RULES,
            string.format(FW.L.VENDOR_BUTTON_TIP_COUNT, Vendor.sellable),
        }
        if Vendor.sellable > 0 then
            local _, total = Vendor:Collect()
            lines[#lines + 1] = string.format(FW.L.VENDOR_BUTTON_TIP_VALUE, Vendor.Money(total))
        end
        return lines
    end)
    return sellButton
end

local function UpdateButton()
    local b = EnsureButton()
    if not b then return end
    local n = Vendor.sellable or 0
    b:SetLabel(n > 0 and string.format(FW.L.VENDOR_BUTTON_N, n) or FW.L.VENDOR_BUTTON)
    b:SetButtonEnabled(n > 0 and not Vendor.run)
    if Vendor.merchant then b:Show() else b:Hide() end
end

FW:On("VENDOR_MERCHANT_CHANGED", function() UpdateButton() end, sellButton or {})
FW:On("VENDOR_COUNT_CHANGED", function() UpdateButton() end, sellButton or {})
FW:On("VENDOR_LOG_CHANGED", function() UpdateButton() end, sellButton or {})

------------------------------------------------------------------------
-- Befehl
------------------------------------------------------------------------

SLASH_FREEWOODSELL1 = "/fwsell"
SlashCmdList["FREEWOODSELL"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "test" then
        Vendor:RunTest()
    else
        UI:Toggle("vendor")
    end
end
