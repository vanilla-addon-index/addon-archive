-- Freewood-OctoWoW-Loot: Tab "Beute" und Einstellungsabschnitt
-- Links die Blacklist, rechts Hinzufuegen, Zuletzt erhalten und das Protokoll der geloeschten Items.

local ADDON, NS = ...

local FW = _G.Freewood
local Loot = NS.Loot
if not FW or not Loot then
    return
end

local UI = FW.UI

local LIST_W = 380
local ROW_H, ROW_GAP = 38, 4
local SMALL_H = 30

local function ColoredName(name, quality, id)
    local text = name or ("#" .. tostring(id))
    return "|cff" .. UI.RarityHex(quality) .. text .. "|r"
end

local function ListRow(parent)
    local row = UI.CreatePanel(parent, "card", "bronze")
    row:SetHeight(ROW_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = UI.CreateLabel(row, "", { size = 12 })
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -112, 0)
    row.name:SetWordWrap(false)
    row.idLabel = UI.CreateLabel(row, "", { size = 10, color = "textDim", justify = "RIGHT" })
    row.idLabel:SetPoint("RIGHT", row, "RIGHT", -40, 0)
    row.remove = UI.CreateButton(row, "X", 26, 24, nil, "danger")
    row.remove:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    UI.AttachTooltip(row.remove, function() return FW.L.LOOT_REMOVE end, "")
    -- Tooltip des Items beim Darueberfahren
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

    local listRows, recentRows, logRows = {}, {}, {}

    ---------------- links: Blacklist ----------------
    local listTitle = UI.CreateLabel(f, L.LOOT_LIST_HEADER, { font = "heading", size = 14, color = "goldLight" })
    listTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local pendingLabel = UI.CreateLabel(f, "", { size = 11, color = "textDim", justify = "RIGHT" })
    pendingLabel:SetPoint("TOPRIGHT", f, "TOPLEFT", LIST_W, -4)
    local listDivider = UI.CreateDivider(f)
    listDivider:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -26)
    listDivider:SetWidth(LIST_W)

    local listScroll = UI.CreateScrollFrame(f)
    listScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -36)
    listScroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    listScroll:SetWidth(LIST_W)

    local listEmpty = UI.CreateLabel(listScroll.child, L.LOOT_LIST_EMPTY, { size = 12, color = "textDim", justifyV = "TOP" })
    listEmpty:SetPoint("TOPLEFT", listScroll.child, "TOPLEFT", 4, -6)
    listEmpty:SetPoint("TOPRIGHT", listScroll.child, "TOPRIGHT", -4, -6)
    listEmpty:SetWordWrap(true)

    local separator = f:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(UI.Color("bronze", 0.5))
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 10, 0)
    separator:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", LIST_W + 10, 0)

    ---------------- rechts ----------------
    local right = CreateFrame("Frame", nil, f)
    right:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 22, 0)
    right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    local addTitle = UI.CreateLabel(right, L.LOOT_ADD_HEADER, { font = "heading", size = 14, color = "goldLight" })
    addTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
    local addDivider = UI.CreateDivider(right)
    addDivider:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -26)
    addDivider:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -26)

    local status = UI.CreateLabel(right, "", { size = 11, color = "textDim" })
    local function SetStatus(text, colorKey)
        status:SetText(text or "")
        status:SetTextColor(UI.Color(colorKey or "textDim"))
    end
    local function TryAdd(input)
        local ok, result = Loot:Add(input)
        if ok then
            local info = FW.Util.GetItem and FW.Util.GetItem(result)
            SetStatus(string.format(FW.L.LOOT_ADD_OK, (info and info.name) or ("#" .. result)), "success")
            return true
        end
        if result == "already" then
            SetStatus(FW.L.LOOT_ADD_ALREADY, "goldLight")
        elseif result == "full" then
            SetStatus(FW.L.LOOT_ADD_FULL, "danger")
        else
            SetStatus(FW.L.LOOT_ADD_INVALID, "danger")
        end
        return false
    end

    -- Ablagefeld fuer Items aus der Tasche
    local drop = UI.CreateItemSlot(right, 44)
    drop:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -38)
    drop:EnableMouse(true)
    local function OnDrop()
        local kind, id = GetCursorInfo()
        if kind == "item" then
            ClearCursor()
            TryAdd(id)
        end
    end
    drop:SetScript("OnReceiveDrag", OnDrop)
    drop:SetScript("OnMouseUp", OnDrop)
    local dropLabel = UI.CreateLabel(right, L.LOOT_ADD_DROP, { size = 12, color = "textDim" })
    dropLabel:SetPoint("LEFT", drop, "RIGHT", 12, 0)

    -- Eingabefeld
    local box = UI.CreatePanel(right, "bgDeep", "bronze")
    box:SetHeight(26)
    box:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -92)
    box:SetPoint("TOPRIGHT", right, "TOPRIGHT", -118, -92)
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
    local function Submit()
        local text = edit:GetText()
        if text and text ~= "" and TryAdd(text) then
            edit:SetText("")
            edit:ClearFocus()
        end
    end
    edit:SetScript("OnEnterPressed", Submit)
    local boxHint = UI.CreateLabel(box, L.LOOT_ADD_BOX, { size = 12, color = "textDim" })
    boxHint:SetPoint("LEFT", box, "LEFT", 10, 0)
    edit:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" then boxHint:Show() else boxHint:Hide() end
    end)
    local addButton = UI.CreateButton(right, L.LOOT_ADD_BUTTON, 110, 26, Submit, "primary")
    addButton:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -92)

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

    local hint = UI.CreateLabel(right, L.LOOT_ADD_HINT, { size = 11, color = "textDim", justifyV = "TOP" })
    hint:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -126)
    hint:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -126)
    hint:SetHeight(28)
    hint:SetWordWrap(true)
    status:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -156)
    status:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -156)
    status:SetWordWrap(false)

    -- Zuletzt erhalten
    local recentTitle = UI.CreateLabel(right, L.LOOT_RECENT_HEADER, { font = "heading", size = 14, color = "goldLight" })
    recentTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -182)
    local recentDivider = UI.CreateDivider(right)
    recentDivider:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -206)
    recentDivider:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -206)
    local recentScroll = UI.CreateScrollFrame(right)
    recentScroll:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -214)
    recentScroll:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 164)
    local recentEmpty = UI.CreateLabel(recentScroll.child, L.LOOT_RECENT_EMPTY, { size = 12, color = "textDim" })
    recentEmpty:SetPoint("TOPLEFT", recentScroll.child, "TOPLEFT", 4, -6)

    -- Protokoll
    local logTitle = UI.CreateLabel(right, L.LOOT_LOG_HEADER, { font = "heading", size = 14, color = "goldLight" })
    logTitle:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 134)
    local logDivider = UI.CreateDivider(right)
    logDivider:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 128)
    logDivider:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 128)
    local logScroll = UI.CreateScrollFrame(right)
    logScroll:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
    logScroll:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)
    logScroll:SetHeight(120)
    local logEmpty = UI.CreateLabel(logScroll.child, L.LOOT_LOG_EMPTY, { size = 12, color = "textDim" })
    logEmpty:SetPoint("TOPLEFT", logScroll.child, "TOPLEFT", 4, -6)

    ---------------- Aktualisieren ----------------
    local function RefreshList()
        local list = Loot:List()
        for i, entry in ipairs(list) do local entry = entry
            local row = listRows[i]
            if not row then
                row = ListRow(listScroll.child)
                listRows[i] = row
            end
            row:ClearAllPoints()
            local y = (i - 1) * (ROW_H + ROW_GAP)
            row:SetPoint("TOPLEFT", listScroll.child, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", listScroll.child, "TOPRIGHT", 0, -y)
            FillItem(row, entry.id, entry.name)
            row.idLabel:SetText(tostring(entry.id))
            row.remove:SetScript("OnClick", function()
                Loot:Remove(entry.id)
            end)
            row:Show()
        end
        for i = #list + 1, #listRows do
            listRows[i]:Hide()
        end
        listEmpty:SetShown(#list == 0)
        listScroll:SetContentHeight(#list * (ROW_H + ROW_GAP))
        local pending = Loot:PendingCount()
        pendingLabel:SetText(pending > 0 and string.format(FW.L.LOOT_PENDING, pending) or "")
    end

    local function RefreshRecent()
        local recent = Loot.chardb.recent
        for i, entry in ipairs(recent) do local entry = entry
            local row = recentRows[i]
            if not row then
                row = UI.CreatePanel(recentScroll.child, "card", "bronze")
                row:SetHeight(SMALL_H)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(22, 22)
                row.icon:SetPoint("LEFT", row, "LEFT", 5, 0)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.name = UI.CreateLabel(row, "", { size = 12 })
                row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
                row.name:SetWordWrap(false)
                row.add = UI.CreateButton(row, FW.L.LOOT_RECENT_ADD, 84, 22, nil, "default")
                row.add:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                row.listed = UI.CreateLabel(row, FW.L.LOOT_RECENT_LISTED, { size = 10, color = "textDim", justify = "RIGHT" })
                row.listed:SetPoint("RIGHT", row, "RIGHT", -12, 0)
                row.name:SetPoint("RIGHT", row, "RIGHT", -96, 0)
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
                recentRows[i] = row
            end
            row:ClearAllPoints()
            local y = (i - 1) * (SMALL_H + 4)
            row:SetPoint("TOPLEFT", recentScroll.child, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", recentScroll.child, "TOPRIGHT", 0, -y)
            FillItem(row, entry.id)
            local listed = Loot:IsListed(entry.id)
            row.add:SetShown(not listed)
            row.listed:SetShown(listed)
            row.add:SetScript("OnClick", function()
                TryAdd(entry.id)
            end)
            row:Show()
        end
        for i = #recent + 1, #recentRows do
            recentRows[i]:Hide()
        end
        recentEmpty:SetShown(#recent == 0)
        recentScroll:SetContentHeight(#recent * (SMALL_H + 4))
    end

    local function RefreshLog()
        local log = Loot.chardb.log
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
            line:SetText(string.format(FW.L.LOOT_LOG_LINE, date("%H:%M", entry.t or 0), entry.name or "?", entry.count or 1))
            line:Show()
        end
        for i = #log + 1, #logRows do
            logRows[i]:Hide()
        end
        logEmpty:SetShown(#log == 0)
        logScroll:SetContentHeight(#log * 18 + 8)
    end

    function f.Refresh()
        RefreshList()
        RefreshRecent()
        RefreshLog()
    end

    local function IfShown(fn)
        return function()
            if f:IsShown() then
                fn()
            end
        end
    end
    FW:On("LOOT_LIST_CHANGED", IfShown(function() f.Refresh() end), f)
    FW:On("LOOT_PENDING_CHANGED", IfShown(RefreshList), f)
    FW:On("LOOT_RECENT_CHANGED", IfShown(RefreshRecent), f)
    FW:On("LOOT_LOG_CHANGED", IfShown(RefreshLog), f)

    return f
end

UI:RegisterTab("loot", {
    label = function()
        return FW.L.LOOT_TAB
    end,
    order = 70,
    build = Build,
    onShow = function(f)
        Loot:Scan()
        f.Refresh()
    end,
})

------------------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------------------

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("loot", {
        category = "modules",
        order = 110,
        height = 180,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.LOOT_SET_HEADER)

            local boxes = {}
            local defs = {
                { key = "enabled", label = L.LOOT_SET_ENABLED },
                { key = "autoLoot", label = L.LOOT_SET_AUTOLOOT },
                { key = "chat", label = L.LOOT_SET_CHAT },
            }
            for _, def in ipairs(defs) do local def = def
                local cb = UI.CreateCheckbox(f, def.label, function()
                    return Loot.db.settings[def.key]
                end, function(value)
                    Loot.db.settings[def.key] = value and true or false
                end)
                stack:Add(cb, { fit = true, gap = 4 })
                boxes[#boxes + 1] = cb
            end

            local note = UI.CreateLabel(f, L.LOOT_SET_NOTE, { size = 11, color = "textDim", justifyV = "TOP" })
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
-- Befehl
------------------------------------------------------------------------

SLASH_FREEWOODLOOT1 = "/fwloot"
SlashCmdList["FREEWOODLOOT"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "test" then
        Loot:RunTest()
    else
        UI:Toggle("loot")
    end
end
