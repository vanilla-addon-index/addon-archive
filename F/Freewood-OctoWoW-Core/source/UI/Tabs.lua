-- Freewood-OctoWoW-Core: die drei eigenen Tabs (Uebersicht, Austausch, Einstellungen)
-- Module registrieren ihre Tabs ueber Freewood.UI:RegisterTab(...), siehe MainWindow.lua.

local ADDON, FW = ...

local UI = FW.UI
local Export = FW.Export

------------------------------------------------------------------------
-- Uebersicht: geladene Module
------------------------------------------------------------------------

local function BuildOverview(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)

    local title = UI.CreateLabel(f, L.OVERVIEW_HEADER, { font = "heading", size = 16, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    local _, build, _, toc = GetBuildInfo()
    local gameVersion = (GetBuildInfo())
    local info = UI.CreateLabel(f,
        string.format(L.OVERVIEW_INFO, FW.version, tostring(gameVersion), tostring(build)),
        { size = 11, color = "textDim", justify = "RIGHT" })
    info:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)

    local divider = UI.CreateDivider(f)
    divider:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -30)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -30)

    local scroll = UI.CreateScrollFrame(f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -44)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    local empty = UI.CreateLabel(scroll.child, L.OVERVIEW_NONE, { size = 12, color = "textDim", justifyV = "TOP" })
    empty:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, 0)
    empty:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, 0)

    local ROW_H, GAP = 58, 8
    local rows = {}

    local function GetRow(i)
        local row = rows[i]
        if row then
            return row
        end
        row = UI.CreatePanel(scroll.child, "card", "bronze")
        row:SetHeight(ROW_H)

        row.name = UI.CreateLabel(row, "", { font = "heading", size = 14, color = "goldLight" })
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -10)

        row.version = UI.CreateLabel(row, "", { size = 11, color = "textDim" })
        row.version:SetPoint("LEFT", row.name, "RIGHT", 10, 0)

        row.desc = UI.CreateLabel(row, "", { size = 12, color = "text" })
        row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -6)

        row.status = UI.CreateLabel(row, "", { size = 12, justify = "RIGHT" })
        row.status:SetPoint("RIGHT", row, "RIGHT", -14, 0)

        rows[i] = row
        return row
    end

    function f.Refresh()
        local list = FW.moduleList
        if #list == 0 then
            empty:Show()
        else
            empty:Hide()
        end

        for i, mod in ipairs(list) do
            local row = GetRow(i)
            local y = (i - 1) * (ROW_H + GAP)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, -y)
            row.name:SetText(mod.title or mod.name)
            row.version:SetText(mod.version and ("v" .. mod.version) or "")
            row.desc:SetText(mod.description or "")
            if mod:IsEnabled() then
                row.status:SetText("|cff" .. UI.Hex("success") .. L.MODULE_ACTIVE .. "|r")
            else
                row.status:SetText("|cff" .. UI.Hex("textDim") .. L.MODULE_INACTIVE .. "|r")
            end
            row:Show()
        end
        for i = #list + 1, #rows do
            rows[i]:Hide()
        end

        scroll:SetContentHeight(math.max(#list * (ROW_H + GAP), 40))
    end

    f.Refresh()
    return f
end

------------------------------------------------------------------------
-- Austausch: Export und Import
------------------------------------------------------------------------

local function BuildExchange(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)
    f.selected = nil

    local intro = UI.CreateLabel(f, L.EXCHANGE_INTRO, { size = 12, color = "textDim", justifyV = "TOP" })
    intro:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    intro:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

    local kinds = CreateFrame("Frame", nil, f)
    kinds:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -46)
    kinds:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -46)
    kinds:SetHeight(28)

    local none = UI.CreateLabel(kinds, L.EXCHANGE_NO_HANDLERS, { size = 12, color = "textDim" })
    none:SetPoint("LEFT", kinds, "LEFT", 0, 0)

    local area = UI.CreateTextArea(f)
    area:SetPoint("TOPLEFT", kinds, "BOTTOMLEFT", 0, -12)
    area:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 46)

    local status = UI.CreateLabel(f, "", { size = 12 })
    status:SetWidth(520)

    local function SetStatus(message, colorKey)
        status:SetText("|cff" .. UI.Hex(colorKey or "text") .. message .. "|r")
    end

    local function ErrorText(key, extra)
        local text = L[key]
        if key == "ERR_NO_HANDLER" then
            text = string.format(text, tostring(extra))
        elseif key == "ERR_INVALID" and type(extra) == "string" then
            text = text .. " (" .. extra .. ")"
        end
        return text
    end

    local kindButtons = {}

    local function RefreshKindButtons()
        for _, b in ipairs(kindButtons) do
            b:SetStyle(b.kind == f.selected and "primary" or "default")
        end
    end

    local function RebuildKinds()
        for _, b in ipairs(kindButtons) do
            b:Hide()
        end
        local list = Export.handlerList
        if #list == 0 then
            none:Show()
            f.selected = nil
            return
        end
        none:Hide()

        local found = false
        for _, h in ipairs(list) do
            if h.kind == f.selected then
                found = true
            end
        end
        if not found then
            f.selected = list[1].kind
        end

        local x = 0
        for i, handler in ipairs(list) do
            local b = kindButtons[i]
            if not b then
                b = UI.CreateButton(kinds, "", 150, 28, function(self)
                    f.selected = self.kind
                    RefreshKindButtons()
                end)
                kindButtons[i] = b
            end
            b.kind = handler.kind
            local label = Export.GetLabel(handler)
            b:SetLabel(label)
            b:SetWidth(math.max(110, b.label:GetStringWidth() + 32))
            b:ClearAllPoints()
            b:SetPoint("LEFT", kinds, "LEFT", x, 0)
            b:Show()
            x = x + b:GetWidth() + 8
        end
        RefreshKindButtons()
    end

    local exportButton = UI.CreateButton(f, L.EXCHANGE_EXPORT, 130, 30, function()
        if not f.selected then
            return -- der Hinweis "kein Modul" steht schon ueber dem Textfeld
        end
        local code, err, extra = Export.ExportKind(f.selected)
        if code then
            area:SetText(code)
            area:SelectAll()
            SetStatus(string.format(L.EXCHANGE_EXPORTED, #code), "success")
        else
            SetStatus(ErrorText(err, extra), "danger")
        end
    end, "primary")
    exportButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)

    local importButton = UI.CreateButton(f, L.EXCHANGE_IMPORT, 130, 30, function()
        local text = area:GetText() or ""
        if not text:find("%S") then
            SetStatus(L.EXCHANGE_EMPTY, "danger")
            return
        end
        local ok, result, extra = Export.Import(text)
        if ok then
            local message = type(result) == "string" and result ~= "" and result or L.EXCHANGE_IMPORTED
            SetStatus(message, "success")
        else
            SetStatus(ErrorText(result, extra), "danger")
        end
    end)
    importButton:SetPoint("LEFT", exportButton, "RIGHT", 8, 0)

    local clearButton = UI.CreateButton(f, L.EXCHANGE_CLEAR, 100, 30, function()
        area:SetText("")
        status:SetText("")
    end, "ghost")
    clearButton:SetPoint("LEFT", importButton, "RIGHT", 8, 0)

    status:SetPoint("LEFT", clearButton, "RIGHT", 16, 0)

    function f.Refresh()
        RebuildKinds()
    end

    f.Refresh()
    return f
end

------------------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------------------

-- Module koennen eigene Abschnitte in den Einstellungen anmelden:
--   UI:RegisterSettingsSection(id, { order = 100, height = 260, build = function(parent) return frame end, refresh = function(frame) end })
-- def.category (optional) ordnet den Abschnitt einem Unter-Reiter zu: "general" (Standard, mit den allgemeinen Einstellungen
-- links), "database", "tooltips", "quest" oder "modules". Reiter ohne Abschnitte werden nicht gezeigt.
-- Die Abschnitte stehen in Spalten (allgemein: zwei Spalten rechts neben den allgemeinen Einstellungen). Die Hoehe eines Abschnitts
-- ist der Wert frame.flowH, wenn er ihn meldet (UI.CreateSection tut das), sonst def.height. Die ganze Seite
-- scrollt, wenn sie hoeher ist als das Fenster; die Breiten richten sich nach der Fensterbreite.
local settingsSections = {}
local settingsFrame, settingsBody, settingsScroll, settingsLeft
local vlines = {}
local catBar, catButtons = nil, {}
local currentCat
local CATS = { "general", "database", "tooltips", "quest", "modules" }
local CAT_LABEL = {
    general = "SETTINGS_CAT_GENERAL", database = "SETTINGS_CAT_DATABASE", tooltips = "SETTINGS_CAT_TOOLTIPS",
    quest = "SETTINGS_CAT_QUEST", modules = "SETTINGS_CAT_MODULES",
}
local function CatOf(def)
    return CAT_LABEL[def.category] and def.category or "general"
end
local function CountCats()
    local counts = {}
    for _, def in ipairs(settingsSections) do
        local c = CatOf(def)
        counts[c] = (counts[c] or 0) + 1
    end
    return counts
end
-- gewaehlter Unter-Reiter (gemerkt); ohne Abschnitte faellt er auf "general" zurueck
local function CurrentCat()
    if not currentCat then
        local c = FW.settings and FW.settings.settingsCat
        currentCat = CAT_LABEL[c] and c or "general"
    end
    if currentCat ~= "general" and not CountCats()[currentCat] then
        currentCat = "general"
    end
    return currentCat
end
local function UpdateCatBar()
    if not catBar then return end
    local cat, counts, x = CurrentCat(), CountCats(), 0
    for _, b in ipairs(catButtons) do
        if b.cat == "general" or counts[b.cat] then
            b:Show()
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", catBar, "TOPLEFT", x, 0)
            x = x + b:GetWidth() + 6
            b:SetStyle(b.cat == cat and "primary" or "default")
        else
            b:Hide()
        end
    end
end

-- Abschnitt mit Ueberschrift, Trennlinie und einem Stapel darunter: local f, stack = UI.CreateSection(parent, "Titel")
function UI.CreateSection(parent, titleText)
    local f = CreateFrame("Frame", nil, parent)
    local title = UI.CreateLabel(f, titleText, { font = "heading", size = 14, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local divider = UI.CreateDivider(f)
    divider:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -26)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -26)
    local stack = UI.CreateStack(f, { y = 30, gap = 6, pad = 0 })
    stack.onHeight = function(h)
        f.flowH = h + 14
        f:SetHeight(f.flowH)
        if f.onFlow then f.onFlow() end
    end
    f.stack = stack
    f.title = title
    return f, stack
end

local SECTION_GAP = 36    -- Abstand zwischen den beiden Spalten
local LEFT_GAP = 40       -- Abstand zwischen allgemeinen Einstellungen und Abschnitten

local function LeftWidth(W)
    return FW.Util.Clamp(math.floor(W * 0.28), 300, 420)
end

local layingOut, pendingLayout, layoutDepth = false, false, 0
local LayoutSections
local function DoLayout()
    local W = settingsBody:GetWidth() or 0
    if W < 200 then
        W = 1000
    end
    local cat = CurrentCat()
    local general = cat == "general"
    local leftW = LeftWidth(W)
    local x0 = general and (leftW + LEFT_GAP) or 0
    local ncol = general and 2 or FW.Util.Clamp(math.floor((W + SECTION_GAP) / (420 + SECTION_GAP)), 1, 3)
    local colW = math.max(200, math.floor((W - x0 - (ncol - 1) * SECTION_GAP) / ncol))
    local xs, ypos = {}, {}
    for i = 1, ncol do
        xs[i] = x0 + (i - 1) * (colW + SECTION_GAP)
        ypos[i] = 0
    end
    if general then settingsLeft:Show() else settingsLeft:Hide() end
    settingsLeft:SetWidth(leftW)
    for _, def in ipairs(settingsSections) do
        local frame = def.frame
        if CatOf(def) ~= cat then
            if frame then frame:Hide() end
        else
            local best = 1                                   -- jeweils in die kuerzeste Spalte
            for i = 2, ncol do
                if ypos[i] > ypos[best] then best = i end
            end
            local h = (frame and frame.flowH) or def.height or 260
            def.col, def.y = best, ypos[best]
            ypos[best] = ypos[best] - h - 10
            if frame then
                frame:Show()
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", settingsBody, "TOPLEFT", xs[best], def.y)
                local wChanged = frame.laidW ~= colW
                frame.laidW = colW
                frame:SetWidth(colW)
                frame:SetHeight(h)
                if wChanged and frame.stack and frame.stack.Layout then pcall(frame.stack.Layout, frame.stack) end
            end
        end
    end
    local contentH = general and (settingsLeft.flowH or 0) or 0
    for i = 1, ncol do
        contentH = math.max(contentH, -ypos[i])
    end
    contentH = contentH + 20
    settingsBody.contentH = contentH
    settingsBody:SetHeight(contentH)
    settingsScroll:SetContentHeight(contentH)
    local pos = {}
    if general then
        pos[1] = x0 - 20
        pos[2] = xs[2] - SECTION_GAP / 2
    else
        for i = 2, ncol do pos[#pos + 1] = xs[i] - SECTION_GAP / 2 end
    end
    for i, line in ipairs(vlines) do
        if pos[i] then
            line:Show()
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", settingsBody, "TOPLEFT", pos[i], 0)
            line:SetPoint("BOTTOMLEFT", settingsBody, "TOPLEFT", pos[i], -contentH)
        else
            line:Hide()
        end
    end
    UpdateCatBar()
end

LayoutSections = function()
    if not settingsBody then
        return
    end
    if layingOut then
        pendingLayout = true     -- eine Hoehe hat sich waehrend des Anordnens geaendert: danach noch einmal
        return
    end
    layingOut = true
    local ok, err = pcall(DoLayout)
    layingOut = false
    if not ok then
        pendingLayout = false
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Freewood: Fehler in den Einstellungen: " .. tostring(err) .. "|r")
        end
        return
    end
    if pendingLayout and layoutDepth < 4 then
        pendingLayout = false
        layoutDepth = layoutDepth + 1
        LayoutSections()
        layoutDepth = layoutDepth - 1
    end
    pendingLayout = false
end

local function SelectCategory(cat)
    currentCat = cat
    if FW.settings then FW.settings.settingsCat = cat end
    LayoutSections()
end

local function BuildSection(def)
    if def.frame or not settingsBody then
        return
    end
    local ok, frame = pcall(def.build, settingsBody)
    if ok and frame then
        def.frame = frame
        frame.onFlow = LayoutSections
        if def.refresh then
            pcall(def.refresh, frame)
        end
    end
end

function UI:RegisterSettingsSection(id, def)
    def.id = id
    def.order = def.order or 100
    settingsSections[#settingsSections + 1] = def
    table.sort(settingsSections, function(a, b)
        return a.order < b.order
    end)
    BuildSection(def)
    LayoutSections()
end

local function BuildSettings(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)

    local title = UI.CreateLabel(f, L.SETTINGS_HEADER, { font = "heading", size = 16, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    local divider = UI.CreateDivider(f)
    divider:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -30)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -30)

    -- Unter-Reiter (Kategorien)
    catBar = CreateFrame("Frame", nil, f)
    catBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -42)
    catBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -42)
    catBar:SetHeight(28)
    catButtons = {}
    for _, cat in ipairs(CATS) do
        local cat = cat                  -- Lua 5.0: Schleifenvariable fuer die Closure sichern
        local b = UI.CreateButton(catBar, L[CAT_LABEL[cat]], 160, 26, function() SelectCategory(cat) end)
        b.cat = cat
        catButtons[#catButtons + 1] = b
    end

    -- Alles darunter scrollt, wenn das Fenster zu niedrig ist
    local scroll = UI.CreateScrollFrame(f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -78)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    local body = scroll.child
    settingsScroll, settingsBody, settingsFrame = scroll, body, f

    -- allgemeine Einstellungen links (Stapel)
    local lf = CreateFrame("Frame", nil, body)
    lf:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    lf:SetWidth(400)
    settingsLeft = lf
    local stack = UI.CreateStack(lf, { y = 0, gap = 8 })
    stack.onHeight = function(h)
        lf.flowH = h
        lf:SetHeight(h)
    end

    local minimapBox = UI.CreateCheckbox(lf, L.SETTINGS_MINIMAP,
        function()
            return not FW.settings.minimap.hide
        end,
        function(value)
            FW.Minimap:SetHidden(not value)
        end)
    stack:Add(minimapBox, { fit = true })

    local debugBox = UI.CreateCheckbox(lf, L.SETTINGS_DEBUG,
        function()
            return FW.settings.debug and true or false
        end,
        function(value)
            FW.settings.debug = value and true or false
        end)
    stack:Add(debugBox, { fit = true })

    local wpBox = UI.CreateCheckbox(lf, L.SETTINGS_WHISPER_POPUP,
        function() return FW.settings.whisperPopup ~= false end,
        function(value) FW.settings.whisperPopup = value and true or false end)
    stack:Add(wpBox, { fit = true })

    local wpAlways = UI.CreateCheckbox(lf, L.SETTINGS_WHISPER_ALWAYS,
        function() return FW.settings.whisperPopupAlways == true end,
        function(value) FW.settings.whisperPopupAlways = value and true or false end)
    stack:Add(wpAlways, { fit = true })

    -- Fenstergroesse: Zeile mit - / Prozent / +
    local scaleLabel = UI.CreateLabel(lf, L.SETTINGS_SCALE, { size = 12 })
    stack:Add(scaleLabel, { height = 16, gap = 18 })
    local scaleRow = CreateFrame("Frame", nil, lf)
    scaleRow:SetHeight(26)
    stack:Add(scaleRow, { height = 26, gap = 4, stretch = true })
    local scaleValue = UI.CreateLabel(scaleRow, "", { size = 12, color = "goldLight", justify = "CENTER" })
    scaleValue:SetWidth(60)

    local function RefreshScale()
        scaleValue:SetText(string.format("%d%%", math.floor(UI:GetScale() * 100 + 0.5)))
    end
    UI:OnScaleChanged(function() RefreshScale() end)

    local minus = UI.CreateButton(scaleRow, "-", 28, 26, function()
        UI:SetScale(UI:GetScale() - 0.05)
    end)
    minus:SetPoint("LEFT", scaleRow, "LEFT", 0, 0)
    scaleValue:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    local plus = UI.CreateButton(scaleRow, "+", 28, 26, function()
        UI:SetScale(UI:GetScale() + 0.05)
    end)
    plus:SetPoint("LEFT", scaleValue, "RIGHT", 4, 0)

    -- Sprache: Beschriftung oben, drei Knoepfe gleich breit darunter
    local langLabel = UI.CreateLabel(lf, L.SETTINGS_LANGUAGE, { size = 12 })
    stack:Add(langLabel, { height = 16, gap = 18 })
    local langRow = CreateFrame("Frame", nil, lf)
    langRow:SetHeight(26)
    stack:Add(langRow, { height = 26, gap = 4, stretch = true })

    local langButtons = {}
    local function RefreshLang()
        for _, b in ipairs(langButtons) do
            b:SetStyle(FW.settings.locale == b.code and "primary" or "default")
        end
    end

    local options = {
        { code = "auto", text = L.LANG_AUTO },
        { code = "deDE", text = L.LANG_DE },
        { code = "enUS", text = L.LANG_EN },
    }
    for i, option in ipairs(options) do
        local b = UI.CreateButton(langRow, option.text, 110, 26, function(self)
            FW.settings.locale = self.code
            RefreshLang()
        end)
        b.code = option.code
        langButtons[#langButtons + 1] = b
    end
    local function LayoutLang(w)
        w = w or langRow:GetWidth() or 0
        if w < 60 then return end
        local bw = math.floor((w - 12) / 3)
        for i, b in ipairs(langButtons) do
            b:ClearAllPoints()
            b:SetWidth(bw)
            b:SetPoint("LEFT", langRow, "LEFT", (i - 1) * (bw + 6), 0)
        end
    end
    langRow:SetScript("OnSizeChanged", function(self) LayoutLang(self:GetWidth()) end)
    LayoutLang(stack:Width())

    local note = UI.CreateLabel(lf, L.SETTINGS_LANGUAGE_NOTE, { size = 11, color = "textDim", justifyV = "TOP" })
    stack:Add(note, { fit = true, gap = 8 })

    local reset = UI.CreateButton(lf, L.SETTINGS_RESET_POS, 220, 28, function()
        UI:ResetPosition()
    end)
    stack:Add(reset, { height = 28, gap = 16, stretch = true })

    function f.Refresh()
        minimapBox:Refresh()
        debugBox:Refresh()
        RefreshScale()
        RefreshLang()
        for _, def in ipairs(settingsSections) do
            if def.frame and def.refresh then
                pcall(def.refresh, def.frame)
            end
        end
        stack:Layout()
        LayoutSections()
    end

    -- senkrechte Trennstriche zwischen den Spalten
    local function VLine()
        local line = body:CreateTexture(nil, "ARTWORK")
        line:SetWidth(1)
        line:SetColorTexture(UI.Color("gold", 0.35))
        return line
    end
    vlines = { VLine(), VLine(), VLine() }

    body:SetScript("OnSizeChanged", function(self)
        local w = self:GetWidth()
        if type(w) == "number" and w > 0 then
            stack:Layout()
            LayoutSections()
        end
    end)
    for _, def in ipairs(settingsSections) do
        BuildSection(def)
    end
    stack:Layout()
    LayoutSections()

    f.Refresh()
    return f
end

------------------------------------------------------------------------
-- Anmelden
------------------------------------------------------------------------

UI:RegisterTab("overview", {
    label = function() return FW.L.TAB_OVERVIEW end,
    order = 10,
    build = BuildOverview,
    onShow = function(f) f.Refresh() end,
})

UI:RegisterTab("exchange", {
    label = function() return FW.L.TAB_EXCHANGE end,
    order = 110,
    build = BuildExchange,
    onShow = function(f) f.Refresh() end,
})

UI:RegisterTab("settings", {
    label = function() return FW.L.TAB_SETTINGS end,
    order = 20,
    build = BuildSettings,
    onShow = function(f) f.Refresh() end,
})
