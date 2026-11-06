-- Freewood-OctoWoW-Beasts: Abschnitt "Wildtier-Daten teilen" in den Einstellungen

local ADDON, NS = ...

local FW = _G.Freewood
local Beasts = NS.Beasts
local Sync = NS.Sync
if not FW or not Beasts or not Sync or not FW.UI or not FW.UI.RegisterSettingsSection then
    return
end

local UI = FW.UI

local ROWS = {
    { kind = "guild", label = "BEAST_SHARE_GUILD", tip = "BEAST_SHARE_GUILD_TIP" },
    { kind = "party", label = "BEAST_SHARE_PARTY", tip = "BEAST_SHARE_PARTY_TIP" },
    { kind = "raid", label = "BEAST_SHARE_RAID", tip = "BEAST_SHARE_RAID_TIP" },
    { kind = "global", label = "BEAST_SHARE_GLOBAL", tip = "BEAST_SHARE_GLOBAL_TIP" },
}


------------------------------------------------------------------------
-- Fenster "Personen": Liste von Battle.net-Freunden und Charakternamen
------------------------------------------------------------------------

local panel

local function BuildPanel()
    local L = FW.L
    local p = UI.CreatePanel(UIParent, "bg", "gold")
    p:SetSize(440, 430)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:EnableMouse(true)
    p:Hide()

    local title = UI.CreateLabel(p, L.BEAST_PEOPLE_TITLE, { font = "heading", size = 15, color = "goldLight" })
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -14)

    local close = UI.CreateButton(p, "X", 26, 24, function() p:Hide() end, "ghost")
    close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, -10)

    local divider = UI.CreateDivider(p)
    divider:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -44)
    divider:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -44)

    local note = UI.CreateLabel(p, L.BEAST_PEOPLE_NOTE, { size = 11, color = "textDim", justifyV = "TOP" })
    note:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -52)
    note:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -52)
    note:SetHeight(46)
    note:SetWordWrap(true)

    -- Liste
    local scroll = UI.CreateScrollFrame(p)
    scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -104)
    scroll:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -104)
    scroll:SetHeight(150)

    local emptyLabel = UI.CreateLabel(scroll.child, L.BEAST_PEOPLE_EMPTY, { size = 12, color = "textDim", justifyV = "TOP" })
    emptyLabel:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 4, -6)
    emptyLabel:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", -4, -6)
    emptyLabel:SetWordWrap(true)

    local rows = {}
    local function Rebuild()
        local list = Sync:GetPeople()
        for _, r in ipairs(rows) do r:Hide() end
        emptyLabel:SetShown(#list == 0)
        for i, person in ipairs(list) do
            local r = rows[i]
            if not r then
                r = CreateFrame("Frame", nil, scroll.child)
                r:SetHeight(26)
                r.bg = r:CreateTexture(nil, "BACKGROUND")
                r.bg:SetAllPoints()
                r.bg:SetColorTexture(UI.Color("card"))
                r.name = UI.CreateLabel(r, "", { size = 12 })
                r.name:SetPoint("LEFT", r, "LEFT", 8, 0)
                r.name:SetWordWrap(false)
                r.kind = UI.CreateLabel(r, "", { size = 10, color = "textDim", justify = "RIGHT" })
                r.remove = UI.CreateButton(r, "x", 22, 20, function(self)
                    Sync:RemovePerson(self:GetParent().index)
                end, "danger")
                r.remove:SetPoint("RIGHT", r, "RIGHT", -3, 0)
                r.kind:SetPoint("RIGHT", r.remove, "LEFT", -8, 0)
                r.name:SetPoint("RIGHT", r.kind, "LEFT", -8, 0)
                rows[i] = r
            end
            r.index = i
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -(i - 1) * 28)
            r:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, -(i - 1) * 28)
            if person.kind == "bnet" then
                r.name:SetText(person.label and person.label ~= "" and (person.label .. "  " .. (person.tag or "")) or (person.tag or ""))
                r.kind:SetText(L.BEAST_PEOPLE_BNET)
            else
                r.name:SetText(person.name or "")
                r.kind:SetText(L.BEAST_PEOPLE_CHAR)
            end
            r:Show()
        end
        scroll:SetContentHeight(math.max(#list * 28, 40))
    end

    -- Eingabefeld
    local addLabel = UI.CreateLabel(p, L.BEAST_PEOPLE_ADD, { size = 12, color = "goldLight" })
    addLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -270)

    local box = UI.CreatePanel(p, "bgDeep", "bronze")
    box:SetHeight(26)
    box:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -292)
    box:SetPoint("TOPRIGHT", p, "TOPRIGHT", -126, -292)
    local edit = CreateFrame("EditBox", nil, box)
    edit:SetAutoFocus(false)
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -2)
    edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 2)
    edit:SetMaxLetters(64)
    if not edit:SetFont(UI.GetFontPath("body"), 12, "") then
        edit:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    end
    edit:SetTextColor(UI.Color("text"))
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local status = UI.CreateLabel(p, "", { size = 11, color = "textDim", justifyV = "TOP" })
    status:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -324)
    status:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -324)
    status:SetHeight(28)
    status:SetWordWrap(true)

    local function Add(kind, value, label)
        local ok, err = Sync:AddPerson(kind, value, label)
        if ok then
            status:SetText("")
            edit:SetText("")
            edit:ClearFocus()
        elseif err == "exists" then
            status:SetText("|cff" .. UI.Hex("danger") .. L.BEAST_PEOPLE_EXISTS .. "|r")
        else
            status:SetText("|cff" .. UI.Hex("danger") .. L.BEAST_PEOPLE_INVALID .. "|r")
        end
    end

    local addButton = UI.CreateButton(p, L.BEAST_PEOPLE_ADD_BUTTON, 100, 26, function()
        Add("char", edit:GetText())
    end, "primary")
    addButton:SetPoint("LEFT", box, "RIGHT", 8, 0)
    edit:SetScript("OnEnterPressed", function(self)
        Add("char", self:GetText())
    end)

    -- Auswahl aus Battle.net-Freunden
    local friendsButton = UI.CreateButton(p, L.BEAST_PEOPLE_FRIENDS, 240, 26, nil, "default")
    friendsButton:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 16)

    local friendsPanel = UI.CreatePanel(p, "bgDeep", "gold")
    friendsPanel:SetPoint("BOTTOMLEFT", friendsButton, "TOPLEFT", 0, 4)
    friendsPanel:SetSize(408, 160)
    friendsPanel:SetFrameLevel((p:GetFrameLevel() or 1) + 20)
    friendsPanel:Hide()
    local fscroll = UI.CreateScrollFrame(friendsPanel)
    fscroll:SetPoint("TOPLEFT", friendsPanel, "TOPLEFT", 4, -4)
    fscroll:SetPoint("BOTTOMRIGHT", friendsPanel, "BOTTOMRIGHT", -4, 4)
    local frows = {}
    local function FillFriends()
        local list = Sync:BNFriends()
        for _, r in ipairs(frows) do r:Hide() end
        local n = 0
        for _, f in ipairs(list) do
            if f.tag then
                n = n + 1
                local r = frows[n]
                if not r then
                    r = CreateFrame("Button", nil, fscroll.child)
                    r:SetHeight(24)
                    r.bg = r:CreateTexture(nil, "BACKGROUND")
                    r.bg:SetAllPoints()
                    r.bg:SetColorTexture(UI.Color("card"))
                    r.text = UI.CreateLabel(r, "", { size = 12 })
                    r.text:SetPoint("LEFT", r, "LEFT", 8, 0)
                    r.text:SetPoint("RIGHT", r, "RIGHT", -8, 0)
                    r.text:SetWordWrap(false)
                    r:SetScript("OnEnter", function(self) self.bg:SetColorTexture(UI.Color("hover")) end)
                    r:SetScript("OnLeave", function(self) self.bg:SetColorTexture(UI.Color("card")) end)
                    r:SetScript("OnClick", function(self)
                        Add("bnet", self.tag, self.accountName)
                        friendsPanel:Hide()
                    end)
                    frows[n] = r
                end
                r.tag, r.accountName = f.tag, f.name
                local state = f.online and ("|cff" .. UI.Hex("success") .. "*|r ") or "   "
                local who = (f.name and f.name ~= "" and f.name or f.tag)
                local char = f.character and f.character ~= "" and ("  (" .. f.character .. ")") or ""
                r.text:SetText(state .. who .. "  " .. f.tag .. char)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", fscroll.child, "TOPLEFT", 0, -(n - 1) * 26)
                r:SetPoint("TOPRIGHT", fscroll.child, "TOPRIGHT", 0, -(n - 1) * 26)
                r:Show()
            end
        end
        fscroll:SetContentHeight(math.max(n * 26, 30))
        if n == 0 then
            status:SetText(Sync:BNAvailable() and L.BEAST_PEOPLE_NOFRIENDS or L.BEAST_PEOPLE_BN_OFF)
        end
        return n
    end
    friendsButton:SetScript("OnClick", function()
        if friendsPanel:IsShown() then
            friendsPanel:Hide()
        elseif FillFriends() > 0 then
            friendsPanel:Show()
        end
    end)

    local hint = UI.CreateLabel(p, "", { size = 10, color = "textDim" })
    hint:SetPoint("BOTTOMLEFT", friendsButton, "TOPLEFT", 0, 6)

    FW:On("BEASTS_SYNC_CHANGED", function() Rebuild() end, p)
    p:SetScript("OnShow", function()
        friendsPanel:Hide()
        Rebuild()
    end)
    return p
end

local function OpenPeople()
    if not panel then
        panel = BuildPanel()
    end
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end

local function Build(parent)
    local L = FW.L
    local f, stack = UI.CreateSection(parent, L.BEAST_SHARE_HEADER)

    local note = UI.CreateLabel(f, L.BEAST_SHARE_NOTE, { size = 11, color = "textDim", justifyV = "TOP" })
    stack:Add(note, { fit = true, gap = 8 })

    local boxes = {}
    for i, row in ipairs(ROWS) do local row = row
        local box = UI.CreateCheckbox(f, L[row.label], function()
            return Sync:IsEnabled(row.kind)
        end, function(on)
            Sync:SetShare(row.kind, on)
        end)
        stack:Add(box, { fit = true, gap = i == 1 and 10 or 4 })
        UI.AttachTooltip(box, function() return L[row.label] end, function() return L[row.tip] end)
        boxes[#boxes + 1] = box
    end

    local peopleButton = UI.CreateButton(f, L.BEAST_PEOPLE_BUTTON, 240, 26, OpenPeople, "default")
    stack:Add(peopleButton, { height = 26, gap = 12 })

    local status = UI.CreateLabel(f, "", { size = 11, color = "textDim", justifyV = "TOP" })
    stack:Add(status, { fit = true, gap = 10, minHeight = 14 })

    function f.Refresh()
        for _, box in ipairs(boxes) do
            box:Refresh()
        end
        local st = Sync:Stats()
        local text = string.format(L.BEAST_SHARE_STATS, st.sent, st.received)
        if Sync:IsEnabled("global") then
            local key = "BEAST_SHARE_GLOBAL_" .. string.upper(st.global or "off")
            text = text .. "\n" .. (L[key] or L.BEAST_SHARE_GLOBAL_OFF)
        end
        if st.people and st.people > 0 then
            text = text .. "\n" .. string.format(L.BEAST_PEOPLE_COUNT, st.people)
        end
        status:SetText(text)
        stack:Layout()
    end

    FW:On("BEASTS_SYNC_CHANGED", function()
        if f:IsVisible() then
            f.Refresh()
        end
    end, f)

    return f
end

UI:RegisterSettingsSection("beasts-share", {
        category = "database",
    order = 100,
    height = 360,
    build = Build,
    refresh = function(frame)
        frame.Refresh()
    end,
})

NS.SyncUI = { OpenPeople = OpenPeople }
