-- Freewood-OctoWoW-Beasts: Tab "Wildtiere"
-- Links Suche, Filter und Liste, rechts Familienfaktoren, Nahrung, Fundorte und Faehigkeiten.

local ADDON, NS = ...

local FW = _G.Freewood
local Beasts = NS.Beasts
if not FW or not Beasts then
    return
end

local UI = FW.UI
local Pet = FW.Pet

local LIST_W = 300
local ROW_H, ROW_GAP = 50, 6
local CARD_W, CARD_H, CARD_GAP = 170, 48, 10
local ITEM_H = 24

local FAMILY_ICON = {
    bat = "Ability_Hunter_Pet_Bat", bear = "Ability_Hunter_Pet_Bear", boar = "Ability_Hunter_Pet_Boar",
    carrionbird = "Ability_Hunter_Pet_Vulture", cat = "Ability_Hunter_Pet_Cat", crab = "Ability_Hunter_Pet_Crab",
    crocolisk = "Ability_Hunter_Pet_Crocolisk", gorilla = "Ability_Hunter_Pet_Gorilla",
    hyena = "Ability_Hunter_Pet_Hyena", owl = "Ability_Hunter_Pet_Owl", raptor = "Ability_Hunter_Pet_Raptor",
    scorpid = "Ability_Hunter_Pet_Scorpid", spider = "Ability_Hunter_Pet_Spider",
    tallstrider = "Ability_Hunter_Pet_TallStrider", turtle = "Ability_Hunter_Pet_Turtle",
    windserpent = "Ability_Hunter_Pet_WindSerpent", wolf = "Ability_Hunter_Pet_Wolf",
}

local function FamilyIcon(fid)
    return "Interface\\Icons\\" .. (FAMILY_ICON[fid] or "Ability_Hunter_BeastTaming")
end

local STATUS_COLOR = { tamed = "success", lored = "goldLight", seen = "text", unknown = "textDim" }

local function StatusText(status)
    local L = FW.L
    if status == "tamed" then return L.BEAST_STATUS_TAMED end
    if status == "lored" then return L.BEAST_STATUS_LORED end
    if status == "seen" then return L.BEAST_STATUS_SEEN end
    return L.BEAST_STATUS_UNKNOWN
end

local function LevelText(s)
    local L = FW.L
    if not s.lvl1 then
        return nil
    end
    local range = (s.lvl2 and s.lvl2 ~= s.lvl1) and (s.lvl1 .. "-" .. s.lvl2) or tostring(s.lvl1)
    local text = string.format(L.BEAST_LEVEL, range)
    if s.c == "elite" then
        text = text .. " " .. L.BEAST_ELITE
    elseif s.c == "rare" then
        text = text .. " " .. L.BEAST_RARE
    elseif s.c == "rareelite" then
        text = text .. " " .. L.BEAST_RAREELITE
    elseif s.c == "worldboss" then
        text = text .. " " .. L.BEAST_BOSS
    elseif type(s.c) == "string" and s.c ~= "" then
        local key = string.lower(s.c)
        if key == "rare" then text = text .. " " .. L.BEAST_RARE end
    end
    return text
end

local function Subtitle(s)
    local parts = { s.family or FW.L.BEAST_FAMILY_UNKNOWN }
    local lvl = LevelText(s)
    if lvl then
        parts[#parts + 1] = lvl
    end
    if s.zone then
        parts[#parts + 1] = s.zone
    end
    return table.concat(parts, "  -  ")
end

local function FoodList(codes)
    local out = {}
    if type(codes) == "string" then
        for i = 1, #codes do
            local c = codes:sub(i, i)
            out[#out + 1] = FW.L["BEAST_FOOD_" .. c] or c
        end
    end
    return out
end

local function SpellName(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and info.name then
            return info.name
        end
    end
    return "Spell " .. tostring(spellID)
end

local function SpellRank(spellID)
    if C_Spell and C_Spell.GetSpellSubtext then
        local ok, text = pcall(C_Spell.GetSpellSubtext, spellID)
        if ok and type(text) == "string" and text ~= "" then
            return text
        end
    end
    return nil
end

------------------------------------------------------------------------
-- Auswahlliste (Dropdown)
------------------------------------------------------------------------

local popup

local function ClosePopup()
    if popup then
        popup:Hide()
        popup.owner = nil
    end
end

local function GetPopup()
    if popup then
        return popup
    end
    popup = UI.CreatePanel(UIParent, "bgDeep", "gold")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup.scroll = UI.CreateScrollFrame(popup)
    popup.scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 3, -3)
    popup.scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -3, 3)
    popup.items = {}
    popup:Hide()
    return popup
end

local function OpenPopup(anchor, options, currentKey, onPick)
    local p = GetPopup()
    if p:IsShown() and p.owner == anchor then
        ClosePopup()
        return
    end
    p.owner = anchor
    for i, opt in ipairs(options) do
        local item = p.items[i]
        if not item then
            item = CreateFrame("Button", nil, p.scroll.child)
            item:SetHeight(ITEM_H)
            item.bg = item:CreateTexture(nil, "BACKGROUND")
            item.bg:SetAllPoints()
            item.label = UI.CreateLabel(item, "", { size = 12 })
            item.label:SetPoint("LEFT", item, "LEFT", 8, 0)
            item.label:SetPoint("RIGHT", item, "RIGHT", -8, 0)
            item.label:SetWordWrap(false)
            item:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(UI.Color("hover"))
            end)
            item:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(UI.Color(self.active and "card" or "bgDeep"))
            end)
            item:SetScript("OnClick", function(self)
                local cb = p.onPick
                ClosePopup()
                if cb then
                    cb(self.key)
                end
            end)
            p.items[i] = item
        end
        item.key = opt.key
        item.active = (opt.key == currentKey)
        item.bg:SetColorTexture(UI.Color(item.active and "card" or "bgDeep"))
        item.label:SetText(opt.text)
        item.label:SetTextColor(UI.Color(item.active and "goldLight" or "text"))
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", p.scroll.child, "TOPLEFT", 0, -(i - 1) * ITEM_H)
        item:SetPoint("TOPRIGHT", p.scroll.child, "TOPRIGHT", 0, -(i - 1) * ITEM_H)
        item:Show()
    end
    for i = #options + 1, #p.items do
        p.items[i]:Hide()
    end
    p.onPick = onPick
    p.scroll:SetContentHeight(#options * ITEM_H)
    p.scroll:ScrollToTop()

    p:SetScale((anchor:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1))
    p:SetSize(math.max(anchor:GetWidth() or 150, 190), math.min(#options * ITEM_H + 6, 270))
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    p:Show()
end

local function CreateSelect(parent, width, getOptions, getKey, onPick)
    local button
    button = UI.CreateButton(parent, "", width, 24, function()
        OpenPopup(button, getOptions(), getKey(), function(key)
            onPick(key)
        end)
    end, "default")
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", button, "LEFT", 8, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    button.label:SetJustifyH("LEFT")
    button.label:SetWordWrap(false)
    return button
end

------------------------------------------------------------------------
-- Suchfeld
------------------------------------------------------------------------

local function CreateSearchBox(parent, width, placeholder, onChange)
    local box = UI.CreatePanel(parent, "bgDeep", "bronze")
    box:SetSize(width, 26)
    local edit = CreateFrame("EditBox", nil, box)
    edit:SetAutoFocus(false)
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -2)
    edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 2)
    edit:SetMaxLetters(48)
    if not edit:SetFont(UI.GetFontPath("body"), 12, "") then
        edit:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    end
    edit:SetTextColor(UI.Color("text"))
    local hint = UI.CreateLabel(box, placeholder, { size = 12, color = "textDim" })
    hint:SetPoint("LEFT", box, "LEFT", 10, 0)
    local function Sync()
        if (edit:GetText() or "") == "" then
            hint:Show()
        else
            hint:Hide()
        end
    end
    edit:SetScript("OnTextChanged", function()
        Sync()
        onChange(edit:GetText() or "")
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    edit:SetScript("OnEditFocusGained", function()
        UI.SetBorderColor(box, "gold")
    end)
    edit:SetScript("OnEditFocusLost", function()
        UI.SetBorderColor(box, "bronze")
    end)
    box.edit = edit
    Sync()
    return box
end

------------------------------------------------------------------------
-- Listenzeile
------------------------------------------------------------------------

local function CreateListRow(parent, onSelect)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    UI.AddBorder(row, "bronze", 0.6)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(34, 34)
    row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = UI.CreateLabel(row, "", { font = "heading", size = 13, color = "goldLight" })
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 52, -10)
    row.name:SetWidth(LIST_W - 150)
    row.name:SetWordWrap(false)

    row.sub = UI.CreateLabel(row, "", { size = 11, color = "textDim" })
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -6)
    row.sub:SetWidth(LIST_W - 76)
    row.sub:SetWordWrap(false)

    row.chip = UI.CreateChip(row, "", "textDim")
    row.chip:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -9)

    local function Refresh()
        if row.selected then
            row.bg:SetColorTexture(UI.Color("hover"))
            UI.SetBorderColor(row, "gold")
        elseif row.hover then
            row.bg:SetColorTexture(UI.Color("hover", 0.7))
            UI.SetBorderColor(row, "bronze")
        else
            row.bg:SetColorTexture(UI.Color("card"))
            UI.SetBorderColor(row, "bronze", 0.6)
        end
    end
    function row:SetSelected(selected)
        self.selected = selected
        Refresh()
    end
    row:SetScript("OnEnter", function()
        row.hover = true
        Refresh()
    end)
    row:SetScript("OnLeave", function()
        row.hover = false
        Refresh()
    end)
    row:SetScript("OnClick", function()
        onSelect(row.id)
    end)
    Refresh()
    return row
end

------------------------------------------------------------------------
-- Stapel im Detailbereich (wiederverwendete Bausteine)
------------------------------------------------------------------------

local function NewStack(scroll)
    local s = { child = scroll.child, y = 0, pool = { label = {}, row = {}, chip = {} }, used = { label = 0, row = 0, chip = 0 } }

    local function take(kind, create)
        s.used[kind] = s.used[kind] + 1
        local item = s.pool[kind][s.used[kind]]
        if not item then
            item = create()
            s.pool[kind][s.used[kind]] = item
        end
        item:Show()
        return item
    end

    function s:Reset()
        for kind, list in pairs(self.pool) do
            for _, item in ipairs(list) do
                item:Hide()
            end
            self.used[kind] = 0
        end
        self.y = 0
    end

    function s:Gap(h)
        self.y = self.y + h
    end

    function s:Heading(text)
        local fs = take("label", function()
            return UI.CreateLabel(self.child, "", { size = 12 })
        end)
        UI.SetFont(fs, "heading", 14)
        fs:SetTextColor(UI.Color("goldLight"))
        fs:SetWordWrap(false)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -self.y)
        fs:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", 0, -self.y)
        fs:SetHeight(20)
        fs:SetText(text)
        self.y = self.y + 24
    end

    function s:Text(text, colorKey)
        local fs = take("label", function()
            return UI.CreateLabel(self.child, "", { size = 12 })
        end)
        UI.SetFont(fs, "body", 12)
        fs:SetTextColor(UI.Color(colorKey or "textDim"))
        fs:SetWordWrap(true)
        fs:SetJustifyV("TOP")
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -self.y)
        fs:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", 0, -self.y)
        local lines = math.max(1, math.ceil(#text / 75))
        fs:SetHeight(lines * 15)
        fs:SetText(text)
        self.y = self.y + lines * 15 + 4
    end

    -- Marken nebeneinander (einzeilig, bricht bei Bedarf um)
    function s:Chips(list, colorKey)
        local x, rowY = 0, self.y
        for _, text in ipairs(list) do
            local chip = take("chip", function()
                return UI.CreateChip(self.child, "", "bronze")
            end)
            chip:SetText(text, colorKey or "goldAntique")
            local w = chip:GetWidth() or 60
            if x > 0 and x + w > 500 then
                x = 0
                rowY = rowY + 26
            end
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", self.child, "TOPLEFT", x, -rowY)
            x = x + w + 6
        end
        self.y = rowY + 28
    end

    -- Zeile: links Text, rechts Text oder Marke; optional klickbar
    function s:Row(left, right, rightColor, onClick, selected)
        local row = take("row", function()
            local r = CreateFrame("Button", nil, self.child)
            r:SetHeight(26)
            r.bg = r:CreateTexture(nil, "BACKGROUND")
            r.bg:SetAllPoints()
            UI.AddBorder(r, "bronze", 0.6)
            r.left = UI.CreateLabel(r, "", { size = 12 })
            r.left:SetPoint("LEFT", r, "LEFT", 10, 0)
            r.left:SetWordWrap(false)
            r.right = UI.CreateLabel(r, "", { size = 11, color = "textDim", justify = "RIGHT" })
            r.right:SetPoint("RIGHT", r, "RIGHT", -10, 0)
            r.right:SetWordWrap(false)
            r.left:SetPoint("RIGHT", r.right, "LEFT", -8, 0)
            local function paint()
                if r.selected then
                    r.bg:SetColorTexture(UI.Color("hover"))
                    UI.SetBorderColor(r, "gold")
                elseif r.hover and r.clickable then
                    r.bg:SetColorTexture(UI.Color("hover", 0.7))
                    UI.SetBorderColor(r, "bronze")
                else
                    r.bg:SetColorTexture(UI.Color("card"))
                    UI.SetBorderColor(r, "bronze", 0.6)
                end
            end
            r.paint = paint
            r:SetScript("OnEnter", function()
                r.hover = true
                paint()
            end)
            r:SetScript("OnLeave", function()
                r.hover = false
                paint()
            end)
            r:SetScript("OnClick", function()
                if r.onClick then
                    r.onClick()
                end
            end)
            return r
        end)
        row.onClick = onClick
        row.clickable = onClick ~= nil
        row.selected = selected and true or false
        row.left:SetText(left or "")
        row.right:SetText(right or "")
        row.right:SetTextColor(UI.Color(rightColor or "textDim"))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -self.y)
        row:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", 0, -self.y)
        row.paint()
        self.y = self.y + 30
        return row
    end

    function s:Height()
        return self.y
    end

    return s
end

------------------------------------------------------------------------
-- Tab
------------------------------------------------------------------------

local function FactorColor(f)
    if f > 1.0001 then
        return "goldLight"
    elseif f < 0.9999 then
        return "danger"
    end
    return "text"
end

local function Build(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)

    local rows = {}
    local filter = { text = "", fid = nil, zone = nil, status = nil, ability = nil, rank = nil, rankMin = false }
    local selectedGroup

    ---------------- linke Spalte ----------------
    local title = UI.CreateLabel(f, L.BEAST_TITLE, { font = "heading", size = 14, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local countLabel = UI.CreateLabel(f, "", { size = 11, color = "textDim", justify = "RIGHT" })
    countLabel:SetPoint("TOPRIGHT", f, "TOPLEFT", LIST_W, 0)
    countLabel:SetWidth(LIST_W - 90)
    countLabel:SetWordWrap(false)

    local listDivider = UI.CreateDivider(f)
    listDivider:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -26)
    listDivider:SetWidth(LIST_W)

    local search = CreateSearchBox(f, LIST_W, L.BEAST_SEARCH, function(text)
        filter.text = text
        if f.Refresh then f.Refresh() end
    end)
    search:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -36)

    local familySelect, zoneSelect
    familySelect = CreateSelect(f, 146, function()
        local fams = Beasts:FilterChoices()
        local opts = { { key = false, text = FW.L.BEAST_ALL_FAMILIES } }
        for _, fam in ipairs(fams) do
            opts[#opts + 1] = { key = fam.id, text = fam.text }
        end
        return opts
    end, function()
        return filter.fid or false
    end, function(key)
        filter.fid = key or nil
        if f.Refresh then f.Refresh() end
    end)
    familySelect:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -68)

    zoneSelect = CreateSelect(f, 146, function()
        local _, zones = Beasts:FilterChoices()
        local opts = { { key = false, text = FW.L.BEAST_ALL_ZONES } }
        for _, z in ipairs(zones) do
            opts[#opts + 1] = { key = z, text = z }
        end
        return opts
    end, function()
        return filter.zone or false
    end, function(key)
        filter.zone = key or nil
        if f.Refresh then f.Refresh() end
    end)
    zoneSelect:SetPoint("TOPLEFT", f, "TOPLEFT", 154, -68)

    -- Faehigkeit, die das Zaehmen lehrt (und Rang)
    local abilitySelect, rankSelect
    abilitySelect = CreateSelect(f, 186, function()
        local opts = { { key = false, text = FW.L.BEAST_ALL_ABILITIES } }
        for _, name in ipairs(Beasts:AbilityChoices()) do
            opts[#opts + 1] = { key = name, text = name }
        end
        return opts
    end, function()
        return filter.ability or false
    end, function(key)
        filter.ability = key or nil
        filter.rank, filter.rankMin = nil, false
        if f.Refresh then f.Refresh() end
    end)
    abilitySelect:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -98)

    rankSelect = CreateSelect(f, 108, function()
        local opts = { { key = false, text = FW.L.BEAST_ALL_RANKS } }
        if filter.ability then
            local ranks = Beasts:AbilityRanks(filter.ability)
            for _, r in ipairs(ranks) do
                opts[#opts + 1] = { key = r, text = string.format(FW.L.BEAST_RANK_EXACT, r) }
            end
            for i, r in ipairs(ranks) do
                if i > 1 then
                    opts[#opts + 1] = { key = -r, text = string.format(FW.L.BEAST_RANK_MIN, r) }
                end
            end
        end
        return opts
    end, function()
        if not filter.rank then
            return false
        end
        return filter.rankMin and -filter.rank or filter.rank
    end, function(key)
        if key then
            filter.rank, filter.rankMin = math.abs(key), key < 0
        else
            filter.rank, filter.rankMin = nil, false
        end
        if f.Refresh then f.Refresh() end
    end)
    rankSelect:SetPoint("TOPLEFT", f, "TOPLEFT", 192, -98)

    -- Statusfilter
    local statusButtons = {}
    local statusDefs = {
        { key = false, text = function() return FW.L.BEAST_STATUS_ALL end, w = 44 },
        { key = "seen", text = function() return FW.L.BEAST_STATUS_SEEN end, w = 58 },
        { key = "lored", text = function() return FW.L.BEAST_STATUS_LORED end, w = 66 },
        { key = "tamed", text = function() return FW.L.BEAST_STATUS_TAMED end, w = 60 },
        { key = "unknown", text = function() return FW.L.BEAST_STATUS_UNKNOWN end, w = 60 },
    }
    local prev
    for _, def in ipairs(statusDefs) do local def = def
        local b = UI.CreateButton(f, def.text(), def.w, 22, function()
            filter.status = def.key or nil
            if f.Refresh then f.Refresh() end
        end, "ghost")
        UI.SetFont(b.label, "body", 11)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 3, 0)
        else
            b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -128)
        end
        b.def = def
        statusButtons[#statusButtons + 1] = b
        prev = b
    end

    local listScroll = UI.CreateScrollFrame(f)
    listScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -158)
    listScroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 62)
    listScroll:SetWidth(LIST_W)

    local emptyLabel = UI.CreateLabel(listScroll.child, "", { size = 12, color = "textDim", justifyV = "TOP" })
    emptyLabel:SetPoint("TOPLEFT", listScroll.child, "TOPLEFT", 4, -6)
    emptyLabel:SetPoint("TOPRIGHT", listScroll.child, "TOPRIGHT", -4, -6)
    emptyLabel:SetHeight(120)
    emptyLabel:SetWordWrap(true)

    -- Schalter: Startdaten anzeigen oder selbst erkunden
    local seedToggle = UI.CreateCheckbox(f, L.BEAST_SEED_TOGGLE, function()
        return Beasts:SeedEnabled()
    end, function(on)
        Beasts:SetSeedEnabled(on)
    end)
    seedToggle:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 4)
    UI.AttachTooltip(seedToggle, L.BEAST_SEED_TOGGLE, { L.BEAST_SEED_TIP1, L.BEAST_SEED_TIP2 })

    -- Auf Octo/1.12 zeichnet die Codex-Karte (dieselbe wie "Auf Karte zeigen" in der Datenbank);
    -- ohne Codex bleibt die alte Beasts-Ebene.
    local Overlay = NS.MapOverlay
    do
        local C = FW.Codex
        local M = C and C.Map
        if M and M.Show then
            local W = { _mode = nil, _single = nil, pts = nil }
            setmetatable(W, { __index = function(t, k)
                if k == "mode" or k == "singleID" then
                    if rawget(t, "pts") and M.points == rawget(t, "pts") then
                        return rawget(t, k == "mode" and "_mode" or "_single")
                    end
                    return nil
                end
            end })
            local function Put(ids, label, mode, single)
                local pts = Beasts:MapPoints(ids)
                if M:Show(pts, label) then
                    W.pts = M.points
                    W._mode, W._single = mode, single
                end
                FW:Fire("BEASTS_MAP_CHANGED")
            end
            function W:ShowSingle(id, name)
                Put({ [id] = true }, name, "single", id)
            end
            function W:ShowMany(ids, count)
                Put(ids, string.format(FW.L.BEAST_MAP_MANY, count), "many", nil)
            end
            function W:Clear()
                if M.points and M.points == rawget(W, "pts") then
                    M:Clear()
                end
                W.pts, W._mode, W._single = nil, nil, nil
                FW:Fire("BEASTS_MAP_CHANGED")
            end
            function W:Focus() end
            Overlay = W
        end
    end
    local mapToggle = UI.CreateCheckbox(f, L.BEAST_MAP_FILTERED, function()
        return Overlay and Overlay.mode == "many"
    end, function(on)
        if not Overlay then
            return
        end
        if on then
            f.ShowFilteredOnMap()
        else
            Overlay:Clear()
        end
    end)
    mapToggle:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 32)
    UI.AttachTooltip(mapToggle, L.BEAST_MAP_FILTERED, { L.BEAST_MAP_FILTERED_TIP })

    local separator = f:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(UI.Color("bronze", 0.4))
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 10, 0)
    separator:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", LIST_W + 10, 0)

    ---------------- rechte Spalte ----------------
    local detail = CreateFrame("Frame", nil, f)
    detail:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 22, 0)
    detail:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    local hint = UI.CreateLabel(f, L.BEAST_SELECT, { size = 12, color = "textDim", justifyV = "TOP" })
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 22, -4)
    hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -4)
    hint:SetWordWrap(true)

    -- Bild: 3D-Modell des Tiers (aus der NPC-Nummer), solange es nicht laedt das Familien-Symbol
    local portrait = UI.CreatePanel(detail, "bgDeep", "bronze")
    portrait:SetSize(64, 64)
    portrait:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
    local portraitIcon = portrait:CreateTexture(nil, "ARTWORK")
    portraitIcon:SetPoint("TOPLEFT", portrait, "TOPLEFT", 6, -6)
    portraitIcon:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", -6, 6)
    portraitIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local model = CreateFrame("PlayerModel", nil, portrait)
    model:SetPoint("TOPLEFT", portrait, "TOPLEFT", 2, -2)
    model:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", -2, 2)
    model:SetAlpha(0)
    -- 1.12 kennt OnModelLoaded nicht: dann bleibt das Modell unsichtbar und das Symbol steht
    pcall(model.SetScript, model, "OnModelLoaded", function(self)
        self:SetAlpha(1)
        portraitIcon:Hide()
    end)

    local nameLabel = UI.CreateLabel(detail, "", { font = "heading", size = 20, color = "goldLight" })
    nameLabel:SetPoint("TOPLEFT", detail, "TOPLEFT", 76, -2)
    nameLabel:SetWidth(330)
    nameLabel:SetWordWrap(false)

    local subLabel = UI.CreateLabel(detail, "", { size = 12, color = "textDim" })
    subLabel:SetPoint("TOPLEFT", detail, "TOPLEFT", 76, -32)
    subLabel:SetWidth(400)
    subLabel:SetWordWrap(false)

    local mapButton = UI.CreateButton(detail, L.BEAST_MAP_SHOW, 170, 22, function()
        local id = Beasts.selectedID
        if not (Overlay and id) then
            return
        end
        if Overlay.mode == "single" and Overlay.singleID == id then
            Overlay:Clear()
        else
            Overlay:ShowSingle(id, Beasts:Summary(id).name)
            Overlay:Focus(selectedGroup)
        end
    end, "primary")
    mapButton:SetPoint("TOPLEFT", detail, "TOPLEFT", 76, -46)

    local stateChip = UI.CreateChip(detail, "", "success")
    stateChip:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 0, -4)
    local sourceChip = UI.CreateChip(detail, "", "textDim")
    sourceChip:SetPoint("RIGHT", stateChip, "LEFT", -6, 0)

    local headDivider = UI.CreateDivider(detail)
    headDivider:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -76)
    headDivider:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 0, -76)

    -- Familienfaktoren
    local cards = {}
    local defs = {
        { key = "hp", label = L.PET_HEALTH },
        { key = "dmg", label = L.PET_DAMAGE },
        { key = "armor", label = L.PET_ARMOR },
    }
    for i, def in ipairs(defs) do
        local card = UI.CreateStatCard(detail, def.label, CARD_W, CARD_H)
        UI.SetFont(card.value, "heading", 15)
        card:SetPoint("TOPLEFT", detail, "TOPLEFT", (i - 1) * (CARD_W + CARD_GAP), -88)
        cards[def.key] = card
    end

    local coordsArea = UI.CreateTextArea(detail, 100, 64)
    coordsArea:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, 0)
    coordsArea:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", 0, 0)
    coordsArea:SetHeight(64)
    local coordsHint = UI.CreateLabel(detail, L.BEAST_COORDS_HINT, { size = 11, color = "textDim" })
    coordsHint:SetPoint("BOTTOMLEFT", coordsArea, "TOPLEFT", 0, 4)
    coordsHint:SetPoint("BOTTOMRIGHT", coordsArea, "TOPRIGHT", 0, 4)
    coordsHint:SetWordWrap(false)

    local sectionScroll = UI.CreateScrollFrame(detail)
    sectionScroll:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -146)
    sectionScroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", 0, 90)
    local stack = NewStack(sectionScroll)

    ---------------- Inhalt fuellen ----------------
    local function CoordsText(g)
        local lines = { g.name }
        local function add(tag, list)
            local limit = math.min(#list, 40)
            for i = 1, limit do
                local p = list[i]
                local times = (p[3] and p[3] > 1) and string.format("  (x%d)", p[3]) or ""
                lines[#lines + 1] = string.format("[%s] %.1f, %.1f%s", tag, p[1] / 10, p[2] / 10, times)
            end
            if #list > limit then
                lines[#lines + 1] = string.format("[%s] ... +%d", tag, #list - limit)
            end
        end
        add(FW.L.BEAST_TAG_OWN, g.own)
        add(FW.L.BEAST_TAG_IMPORT, g.imp)
        add(FW.L.BEAST_TAG_START, g.seed)
        return table.concat(lines, "\n")
    end

    local ShowDetail

    local function FillSections(s)
        local L2 = FW.L
        stack:Reset()

        -- Nahrung
        stack:Heading(L2.BEAST_FOOD)
        local foods = FoodList(s.diet)
        if #foods == 0 then
            stack:Text(L2.BEAST_FOOD_UNKNOWN, "textDim")
        else
            stack:Chips(foods, "goldAntique")
        end
        stack:Gap(6)

        -- Fundorte
        stack:Heading(L2.BEAST_LOCATIONS)
        local groups = Beasts:Locations(s)
        if #groups == 0 then
            stack:Text(L2.BEAST_LOCATIONS_NONE, "textDim")
            coordsArea:SetText("")
        else
            local keep
            for _, g in ipairs(groups) do
                if selectedGroup == g.mapID then
                    keep = g
                end
            end
            if not keep then
                keep = groups[1]
                selectedGroup = keep.mapID
            end
            for _, g in ipairs(groups) do local g = g
                local tags = {}
                if #g.own > 0 then tags[#tags + 1] = L2.BEAST_TAG_OWN .. " " .. #g.own end
                if #g.imp > 0 then tags[#tags + 1] = L2.BEAST_TAG_IMPORT .. " " .. #g.imp end
                if #g.seed > 0 then tags[#tags + 1] = L2.BEAST_TAG_START .. " " .. #g.seed end
                stack:Row(g.name, table.concat(tags, "  |  "), "textDim", function()
                    selectedGroup = g.mapID
                    FillSections(s)
                end, g.mapID == selectedGroup)
            end
            coordsArea:SetText(CoordsText(keep))
        end
        stack:Gap(6)

        -- Faehigkeiten durch Zaehmen (Startdaten)
        if s.seed and s.seed.t and #s.seed.t > 0 then
            stack:Heading(L2.BEAST_TEACHES)
            for _, spellID in ipairs(s.seed.t) do
                local name, rank = Beasts.SpellInfo(spellID)
                stack:Row(SpellName(spellID), SpellRank(spellID) or "", "goldLight", function()
                    if name then
                        filter.ability = name
                        filter.rank, filter.rankMin = (rank and rank > 0) and rank or nil, false
                        if f.Refresh then f.Refresh() end
                    end
                end)
            end
            stack:Gap(6)
        end

        -- Faehigkeiten des Begleiters, beim Zaehmen erfasst
        local pa = (s.own and s.own.petAbilities) or (s.imp and s.imp.petAbilities)
        if pa and #pa > 0 then
            stack:Heading(L2.BEAST_PETABIL)
            for _, a in ipairs(pa) do local a = a
                local right = a.rank and a.rank > 0 and (FW.L.PET_RANK and string.format(FW.L.PET_RANK, a.rank) or ("Rang " .. a.rank)) or ""
                if a.passive then
                    right = (right ~= "" and (right .. "  |  ") or "") .. L2.BEAST_PASSIVE
                end
                stack:Row(a.name, right, "goldLight", function()
                    if a.name then
                        filter.ability = a.name
                        filter.rank, filter.rankMin = (tonumber(a.rank) and tonumber(a.rank) > 0) and tonumber(a.rank) or nil, false
                        if f.Refresh then f.Refresh() end
                    end
                end)
            end
            stack:Gap(6)
        end

        -- Hinweise aus Wildtierkunde
        local extra = (s.own and s.own.extra) or (s.imp and s.imp.extra)
        if extra and #extra > 0 then
            stack:Heading(L2.BEAST_EXTRA)
            for _, line in ipairs(extra) do
                stack:Text(line, "text")
            end
        end

        sectionScroll:SetContentHeight(stack:Height() + 4)
    end

    function ShowDetail(id)
        local s = id and Beasts:Summary(id)
        if not s then
            detail:Hide()
            hint:Show()
            return
        end
        hint:Hide()
        detail:Show()

        nameLabel:SetText(s.name)
        subLabel:SetText(Subtitle(s))
        portraitIcon:SetTexture(FamilyIcon(s.fid))
        portraitIcon:Show()
        model:SetAlpha(0)
        pcall(function()
            model:ClearModel()
            model:SetCreature(s.id)
            if model.SetPortraitZoom then
                model:SetPortraitZoom(1)
            end
        end)
        local fileID = model.GetModelFileID and model:GetModelFileID()
        if type(fileID) == "number" and fileID > 0 then
            model:SetAlpha(1)
            portraitIcon:Hide()
        end
        f.UpdateMapButton()
        stateChip:SetText(StatusText(s.status), STATUS_COLOR[s.status])
        if s.own then
            sourceChip:SetText(FW.L.BEAST_TAG_OWN, "textDim")
            sourceChip:Show()
        elseif s.imp then
            sourceChip:SetText(FW.L.BEAST_TAG_IMPORT, "textDim")
            sourceChip:Show()
        elseif s.seed then
            sourceChip:SetText(FW.L.BEAST_TAG_START, "textDim")
            sourceChip:Show()
        else
            sourceChip:Hide()
        end

        local mods = s.fid and Pet.GetFamilyModsByID(s.fid) or nil
        for key, card in pairs(cards) do
            local v = mods and mods[key]
            if v then
                card:SetValue(string.format("x%.2f", v), FactorColor(v))
            else
                card:SetValue(FW.L.BEAST_FACTOR_UNKNOWN, "textDim")
            end
        end

        FillSections(s)
        sectionScroll:ScrollToTop()
    end

    function f.UpdateMapButton()
        local id = Beasts.selectedID
        if not (Overlay and id) then
            return
        end
        if Overlay.mode == "single" and Overlay.singleID == id then
            mapButton:SetLabel(FW.L.BEAST_MAP_HIDE)
        else
            mapButton:SetLabel(FW.L.BEAST_MAP_SHOW)
        end
    end

    function f.ShowFilteredOnMap()
        local ids, count = {}, 0
        for _, s in ipairs(Beasts:Filtered(filter)) do
            ids[s.id] = true
            count = count + 1
        end
        local wasMany = Overlay.mode == "many"
        Overlay:ShowMany(ids, count)
        if not wasMany then
            Overlay:Focus(nil)
        end
    end

    local function SelectBeast(id)
        if Beasts.selectedID ~= id then
            selectedGroup = nil
        end
        Beasts.selectedID = id
        for _, row in ipairs(rows) do
            row:SetSelected(row.id == id)
        end
        ShowDetail(id)
    end

    function f.Refresh()
        local L2 = FW.L
        local list, missing = Beasts:Filtered(filter)
        local total = #Beasts:Index()

        if filter.ability then
            countLabel:SetText(string.format(L2.BEAST_COUNT_NOABIL, #list, total, missing or 0))
        else
            countLabel:SetText(string.format(L2.BEAST_COUNT, #list, total))
        end
        abilitySelect:SetLabel(filter.ability or L2.BEAST_ALL_ABILITIES)
        local rankText = L2.BEAST_ALL_RANKS
        if filter.rank then
            rankText = string.format(filter.rankMin and L2.BEAST_RANK_MIN or L2.BEAST_RANK_EXACT, filter.rank)
        end
        rankSelect:SetLabel(rankText)
        rankSelect:SetButtonEnabled(filter.ability ~= nil)

        local famText, zoneText = L2.BEAST_ALL_FAMILIES, L2.BEAST_ALL_ZONES
        if filter.fid then famText = Beasts:FamilyText(filter.fid) end
        if filter.zone then zoneText = filter.zone end
        familySelect:SetLabel(famText)
        zoneSelect:SetLabel(zoneText)
        for _, b in ipairs(statusButtons) do
            local active = (b.def.key or nil) == filter.status
            b:SetStyle(active and "primary" or "ghost")
        end
        seedToggle:Refresh()
        if Beasts:HasSeed() then
            seedToggle:Show()
        else
            seedToggle:Hide()
        end

        local selectedStillListed = false
        for i, s in ipairs(list) do
            local row = rows[i]
            if not row then
                row = CreateListRow(listScroll.child, SelectBeast)
                rows[i] = row
            end
            row.id = s.id
            row.name:SetText(s.name)
            row.sub:SetText(Subtitle(s))
            row.icon:SetTexture(FamilyIcon(s.fid))
            row.icon:SetDesaturated(s.status == "unknown")
            row.chip:SetText(StatusText(s.status), STATUS_COLOR[s.status])
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", listScroll.child, "TOPLEFT", 0, -(i - 1) * (ROW_H + ROW_GAP))
            row:SetPoint("TOPRIGHT", listScroll.child, "TOPRIGHT", 0, -(i - 1) * (ROW_H + ROW_GAP))
            row:SetSelected(s.id == Beasts.selectedID)
            row:Show()
            if s.id == Beasts.selectedID then
                selectedStillListed = true
            end
        end
        for i = #list + 1, #rows do
            rows[i]:Hide()
        end
        listScroll:SetContentHeight(math.max(#list * (ROW_H + ROW_GAP), 130))

        if #list == 0 then
            emptyLabel:SetText((total == 0) and L2.BEAST_EMPTY_EXPLORE or L2.BEAST_EMPTY_FILTER)
            emptyLabel:Show()
        else
            emptyLabel:Hide()
        end

        if not selectedStillListed then
            Beasts.selectedID = list[1] and list[1].id or nil
            selectedGroup = nil
            for _, row in ipairs(rows) do
                row:SetSelected(row.id == Beasts.selectedID and row:IsShown())
            end
        end
        ShowDetail(Beasts.selectedID)
        if Overlay and Overlay.mode == "many" then
            f.ShowFilteredOnMap()
        end
        mapToggle:Refresh()
    end

    FW:On("BEASTS_MAP_CHANGED", function()
        mapToggle:Refresh()
        if f.UpdateMapButton then
            f.UpdateMapButton()
        end
    end)

    f:SetScript("OnHide", ClosePopup)

    FW:On("BEASTS_UPDATED", function()
        if f:IsVisible() then
            if f.Refresh then f.Refresh() end
        end
    end)
    FW:On("PET_UPDATED", function()
        if f:IsVisible() then
            if f.Refresh then f.Refresh() end
        end
    end)

    if f.Refresh then f.Refresh() end
    return f
end

UI:RegisterTab("beasts", {
    label = function()
        return FW.L.BEAST_TAB
    end,
    order = 50,
    build = Build,
    onShow = function(f)
        if f.Refresh then f.Refresh() end
    end,
})

SLASH_FREEWOODBEASTS1 = "/fwbeasts"
SlashCmdList["FREEWOODBEASTS"] = function(msg)
    msg = string.lower(strtrim(msg or ""))
    if msg == "map" or msg == "karte" then
        if NS.MapOverlay then
            NS.MapOverlay:Debug()
        end
    elseif string.sub(msg, 1, 7) == "mapsize" then
        local n = tonumber(string.match(msg, "(%d+)"))
        if n then
            Beasts.db.settings.mapMinSize = math.max(8, math.min(128, n))
            if NS.MapOverlay then
                NS.MapOverlay:Refresh()
            end
        end
        FW:Print(string.format(FW.L.BEAST_MAP_MINSIZE, Beasts.db.settings.mapMinSize or 32))
    elseif msg == "maptest" then
        if NS.MapOverlay then
            NS.MapOverlay:Test()
        end
    else
        UI:Toggle("beasts")
    end
end
